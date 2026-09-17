"""Enumerate Oolite's JavaScript API over the debug console and emit a deterministic snapshot.

This is the engine behind tools/js-api-snapshot.sh. It launches the real game headless, drives it
over the debug console (transport: upstream/oolite/tests/component/console.py, ADR-0018), asks the
live SpiderMonkey runtime what globals and native classes exist, and writes the answer to
oxp-contract/js-api-1.93.json.

Five things here are deliberate and are the reason it looks like this:

* The port is not ours to choose. The GAME dials out to the console and reads console-port from
  debugConfig.plist (OODebugSupport.m:67-80, default kOOTCPConsolePort = 8563). A port becomes
  real by writing a plist the game merges, exposed through OO_ADDITIONALADDONSDIRS
  (OOOXZManager.m:286 -> ResourceManager userRootPaths), exactly as tests/launch_snapshot.py does.
  The stock Debug OXP leaves both keys commented out, so this always wins the merge.

* Readiness is measured on the GAME's clock, never on ours. A fixed sleep is spent while the game
  is still loading. DebugConsole.start() pings until Pong echoes the token; _wait_until_rendering
  then polls clock.absoluteSeconds (UNIVERSE's time, OOJSClock.m) until N seconds of GAME time
  have passed, so the universe and every native class are really installed before we look.

* `this` inside a console command is the console's own script object, not the global. Every helper
  therefore recovers the real global with `(function(){return this;})()` and stores its state on
  it; a bare `var` in a console command does not survive the command, an assignment to the global
  does. Measured: `Object.getOwnPropertyNames(this).length` is 35 for the console script and 121
  for the true global.

* Some native property getters are UNCATCHABLE. Reading a descriptor for, say,
  Dock.prototype.allowsDocking invokes the getter on the prototype, which has no private backing
  object; OOJSReportBadPropertySelector raises a SpiderMonkey error with no exception object, so
  try/catch cannot see it and the entire console command is terminated - the console simply never
  answers. Seven classes behave this way (Dock, ExhaustPlume, Flasher, Station, VisualEffect,
  Waypoint, Wormhole). _scan_members therefore records its progress on the global BEFORE touching
  each name, so a killed command can be resumed at the next index and the offending member is
  recorded as kind "native-opaque" rather than losing the whole class.

* The `typeof` of a SINGLETON's own data property is SESSION STATE, not API shape. `mission` and
  `system` are one live object each: mission.screenID is `null` with no mission screen up and a
  string with one, and system.mainStation is an object in a system and null in interstellar space.
  Recording those typeofs would make a regeneration diff against the savegame, not against the API,
  so _describe_global omits `type` from an object global's own_members. What that costs is bounded
  and measured, not assumed - see _strip_state_dependent_types, which states exactly how many
  entries lose a type that nothing else in the document carries, and js_api_check.py, which fails
  if that set ever grows beyond the pinned five.

Only shapes are recorded, never values: kind, arity, descriptor flags, and - where it is a property
of the class definition rather than of the session - the typeof of a data property. A regeneration
therefore diffs clean.
"""

import argparse
import json
import os
import plistlib
import shutil
import sys
import tempfile
import time

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(_HERE)
sys.path.insert(0, os.path.join(_REPO, "upstream", "oolite", "tests", "component"))

from console import ConsoleError, DebugConsole  # noqa: E402

DEFAULT_APP_DIR = os.path.join(_REPO, "upstream", "oolite", "build", "meson_test", "oolite.app")
DEFAULT_OUTPUT = os.path.join(_REPO, "oxp-contract", "js-api-1.93.json")
DEFAULT_PORT = 8563
SETTLE_GAME_SECONDS = 2.0
CHUNK = 3000

# A scan segment that has not answered in this long has hit an uncatchable native error and will
# never answer. A segment that succeeds answers in well under a second, so this is pure slack.
SCAN_TIMEOUT = 8

# Record separators inside the accumulator string. Printable ASCII on purpose: a control character
# survives neither the XML property list the console frames packets with nor the console's own
# line handling. Neither character can occur in a JS identifier, so no member name can forge one.
FIELD = "|"
RECORD = ";"

# ECMAScript / E4X globals SpiderMonkey provides on its own, so the snapshot can report how many
# globals Oolite itself adds without that number moving when the JS engine is replaced (ADR-0002
# swaps SpiderMonkey for QuickJS-ng; a standard builtin appearing or vanishing is not an Oolite
# API change).
ECMA_GLOBALS = frozenset([
    "Array", "ArrayBuffer", "Boolean", "DataView", "Date", "Error", "EvalError", "Float32Array",
    "Float64Array", "Function", "Infinity", "Int16Array", "Int32Array", "Int8Array",
    "InternalError", "Intl", "Iterator", "JSON", "Map", "Math", "NaN", "Namespace", "Number",
    "Object", "Promise", "Proxy", "QName", "RangeError", "Reflect", "ReferenceError", "RegExp",
    "Set", "StopIteration", "String", "Symbol", "SyntaxError", "TypeError", "URIError",
    "Uint16Array", "Uint32Array", "Uint8Array", "Uint8ClampedArray", "WeakMap", "WeakSet", "XML",
    "XMLList", "decodeURI", "decodeURIComponent", "encodeURI", "encodeURIComponent", "escape",
    "eval", "globalThis", "isFinite", "isNaN", "isXMLName", "parseFloat", "parseInt", "undefined",
    "unescape", "uneval",
])

# Globals that exist only because the Debug OXP is loaded (OOJSConsole.m and the OXP's own
# script). They are part of the live API but not of the shipped game's contract, so the summary
# counts them separately instead of letting a debug build inflate the API surface.
DEBUG_GLOBALS = frozenset(["Console", "ConsoleSettings", "console", "debugConsole"])

# Members the harness itself creates on the global. They must never reach the contract.
HARNESS_PREFIX = "__oo"

# Installed once per session with `perform`, assigned onto the real global (see the module
# docstring on `this`). Whitespace is collapsed before sending: the console treats a command as a
# single expression and multi-line text confuses its echo handling.
HELPERS_JS = r"""
this.__ooGlobal = (function () { return this; })();
this.__ooGlobal.__ooScan = function (target, from) {
  var g = (function () { return this; })();
  if (from === 0) { g.__ooAcc = ""; }
  var names;
  try { names = Object.getOwnPropertyNames(target); } catch (e) { names = []; }
  names.sort();
  for (var i = from; i < names.length; i++) {
    var n = names[i];
    /* Recorded before the descriptor is touched: an uncatchable native error kills this command
       outright, and this index is the only thing that tells the caller where to resume. */
    g.__ooIdx = i;
    var d = null;
    try { d = Object.getOwnPropertyDescriptor(target, n); } catch (err) { d = null; }
    var kind = "opaque", arity = "", type = "", flags = "";
    if (d) {
      flags = (d.enumerable ? "e" : "-") + (d.configurable ? "c" : "-");
      if (d.get || d.set) {
        kind = "accessor";
        flags += (d.get ? "r" : "-") + (d.set ? "w" : "-");
      } else if (typeof d.value === "function") {
        kind = "method";
        arity = String(d.value.length | 0);
        flags += "r" + (d.writable ? "w" : "-");
      } else {
        kind = "property";
        type = (d.value === null) ? "null" : typeof d.value;
        flags += "r" + (d.writable ? "w" : "-");
      }
    }
    g.__ooAcc += n + "|" + kind + "|" + arity + "|" + type + "|" + flags + ";";
  }
  g.__ooIdx = names.length;
  return names.length;
};
"""


def _console_config_dir(host, port):
    """Throwaway resource root telling the game which console host/port to dial.

    See the module docstring: this is the only way to move the console off 8563, because the game
    is the party that connects. The caller removes the directory.
    """
    root = tempfile.mkdtemp(prefix="oolite-jsapi-")
    config = os.path.join(root, "Config")
    os.makedirs(config, exist_ok=True)
    with open(os.path.join(config, "debugConfig.plist"), "wb") as handle:
        plistlib.dump({"console-host": host, "console-port": port}, handle, fmt=plistlib.FMT_XML)
    return root


def _ensure_software_gl(app_dir):
    """Put Mesa's llvmpipe driver beside the binary, as tests/component/conftest.py does.

    Two DLLs, not one: Mesa's opengl32.dll loads libgallium_wgl.dll at runtime, and a missing one
    raises a MODAL Windows dialog, which hangs an unattended run for ever instead of failing it.
    """
    prefix = os.environ.get("MINGW_PREFIX")
    if not prefix:
        return
    for dll in ("opengl32.dll", "libgallium_wgl.dll"):
        source = os.path.join(prefix, "bin", dll)
        target = os.path.join(app_dir, dll)
        if os.path.isfile(source) and not os.path.isfile(target):
            shutil.copy2(source, target)


def _wait_until_rendering(con, settle=SETTLE_GAME_SECONDS, timeout=180):
    """Block until the game's own clock has advanced `settle` seconds.

    Answering a Ping proves the run loop is alive; it does not prove the universe is built. Native
    classes are installed as the game boots, so enumerating too early would under-report.
    """
    start = float(con.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + timeout
    while time.time() < deadline:
        if float(con.evaluate("clock.absoluteSeconds")) - start >= settle:
            return
        time.sleep(0.5)
    raise ConsoleError(f"game time did not advance {settle}s within {timeout}s")


def _fetch_string(con, expr, timeout=40):
    """Pull a possibly long JS string back one bounded chunk per packet.

    The expression is evaluated ONCE into __ooBuf and every chunk is sliced out of that buffer.
    Re-evaluating per chunk would be both slow and wrong: an expression whose value changes
    between chunks (or that is expensive) yields a torn or mismatched string.
    """
    total = int(float(con.evaluate(f"(__ooGlobal.__ooBuf = String({expr})).length",
                                   timeout=timeout)))
    parts = []
    for offset in range(0, total, CHUNK):
        parts.append(con.evaluate(f"__ooBuf.substr({offset},{CHUNK})", timeout=timeout))
    text = "".join(parts)
    if len(text) != total:
        raise ConsoleError(f"reassembled {len(text)} chars of {expr}, game reported {total}")
    return text


def _names_of(con, target):
    """Own property names of a JS object, sorted. Never invokes a getter, so always safe."""
    text = _fetch_string(con, f"Object.getOwnPropertyNames({target}).sort().join({RECORD!r})")
    return [n for n in text.split(RECORD) if n]


def _scan_members(con, target, names):
    """Describe every own member of `target`, surviving uncatchable native errors.

    A killed command leaves __ooIdx pointing at the member that killed it, so the scan is resumed
    one past it and that member is recorded as "native-opaque": known to exist, not safely
    describable from the prototype. See the module docstring.

    Harness-created members are dropped from the RESULT rather than from `names`: the resume index
    __ooIdx is an offset into the JS side's own unfiltered, sorted name list, so pre-filtering here
    would desynchronise it. `global` is a self-reference to the JS global object, so the
    accumulator and helper this module installs (__ooAcc, __ooBuf, __ooIdx, __ooScan) appear as its
    own members and would otherwise be recorded as part of Oolite's API.
    """
    if not names:
        # No round trip at all, and that is load-bearing, not an optimisation. __ooAcc is reset
        # JS-side by __ooScan when `from` is 0; with no names the loop below never calls it, so a
        # fetch here would return the PREVIOUS target's accumulator and record its members as this
        # target's own. That is exactly the corruption that put StopIteration, missionVariables and
        # worldScripts in an earlier snapshot holding Station.prototype's, Mission.prototype's and
        # Array.prototype's members. A target with no own names has no members, full stop.
        return {}

    found = {}
    start = 0
    opaque = []
    while start < len(names):
        try:
            con.evaluate(f"__ooScan({target},{start})", timeout=SCAN_TIMEOUT)
            break
        except ConsoleError:
            try:
                index = int(float(con.evaluate("__ooIdx", timeout=20)))
            except (ConsoleError, ValueError):
                index = start
            index = max(index, start)
            if index < len(names):
                opaque.append(names[index])
            start = index + 1

    accumulated = _fetch_string(con, "__ooAcc")
    for record in accumulated.split(RECORD):
        if not record:
            continue
        name, kind, arity, type_, flags = record.split(FIELD)
        entry = {"kind": kind}
        if kind == "method":
            entry["arity"] = int(arity)
        if kind == "property":
            entry["type"] = type_
        entry["enumerable"] = flags[0:1] == "e"
        entry["configurable"] = flags[1:2] == "c"
        entry["readable"] = flags[2:3] == "r"
        entry["writable"] = flags[3:4] == "w"
        found[name] = entry

    for name in names:
        if name not in found:
            # Either the member that killed a scan segment, or one never reached because a later
            # segment covered the rest. Both mean the same thing for the contract.
            found[name] = {"kind": "native-opaque"}
    for name in opaque:
        found[name] = {"kind": "native-opaque"}
    for name in [n for n in found if n.startswith(HARNESS_PREFIX)]:
        del found[name]
    return found


def _js_global(name):
    """A JS expression for a global by name, safe for any identifier."""
    return f"__ooGlobal[{json.dumps(name)}]"


def _strip_state_dependent_types(members):
    """Drop `type` from data properties of a live singleton.

    `typeof` of a live value answers what the session currently holds, not what the API declares:
    mission.screenID is null with no mission screen up and a string with one; system.mainStation is
    an object in a system and null in interstellar space. Keeping those would make a regeneration
    diff against the savegame. Kind, arity and descriptor flags stay - they are the shape.

    This is NOT free, and the earlier claim that it was ("every such member is also on the class
    prototype, so nothing is lost") was checked on four globals and is false in general. Measured
    over all 17 object globals in this build, most own data properties DO reappear on the class
    prototype (Mission.prototype, System.prototype, Clock.prototype, ...) or, for `global`, as a
    top-level global entry of their own, and for those the type really is recoverable from
    elsewhere in the document. Five do not:

        console.script, console.settings, debugConsole.script, debugConsole.settings, player.ship

    Those five are the honest cost of this decision, and they are also the members for which the
    dropped value is least informative: each is a slot holding a live object or null depending on
    what the session is doing, so the typeof we would record is precisely the session state this
    function exists to exclude. Recording a declared/nullable type instead would mean inventing a
    type the engine never declares - it publishes no type metadata for a JS property - so the
    choice is between a session value and nothing, and nothing is the reproducible one.

    js_api_check.py pins that set: if a sixth own-only data property ever appears, the check fails
    and this comment has to be re-derived rather than silently drifting out of date again.
    """
    for entry in members.values():
        entry.pop("type", None)
    return members


def _describe_global(con, name):
    """Shape of one global: its type, arity, class, and every member of it and its prototype.

    The header (type, class name, arity, has-prototype) is fetched in ONE evaluation: a console
    round trip costs a game frame, and four of them per global over 121 globals dominates the run.
    Reading .length and .prototype is safe on every global measured - only descriptor reads on a
    native prototype can raise the uncatchable error _scan_members handles.
    """
    ref = _js_global(name)
    header = con.evaluate(
        "(function(v){"
        "var t = (v === null) ? 'null' : typeof v;"
        "if (t !== 'function' && t !== 'object') { return t + '||||'; }"
        "var c = Object.prototype.toString.call(v).replace('[object ','').replace(']','');"
        "var a = '', p = '';"
        "if (t === 'function') { a = String(v.length | 0); p = v.prototype ? '1' : '0'; }"
        "else { p = Object.getPrototypeOf(v) ? '1' : '0'; }"
        f"return t + '|' + c + '|' + a + '|' + p;}})({ref})",
        timeout=25,
    )
    kind, class_name, arity, has_proto = (header.split(FIELD) + ["", "", "", ""])[:4]
    entry = {"type": kind}
    if kind not in ("function", "object"):
        return entry

    entry["class_name"] = class_name
    if kind == "function":
        entry["arity"] = int(arity or 0)
        entry["is_class"] = has_proto == "1"
        entry["statics"] = _scan_members(con, ref, _names_of(con, ref))
        if has_proto == "1":
            entry["prototype_members"] = _scan_members(
                con, f"{ref}.prototype", _names_of(con, f"{ref}.prototype")
            )
    else:
        # See the module docstring and _strip_state_dependent_types: a singleton's own
        # data-property values are session state, so their typeof is dropped. Most of them are
        # recoverable from the class prototype recorded just below; five in this build are not,
        # and that cost is documented there rather than glossed over.
        entry["own_members"] = _strip_state_dependent_types(
            _scan_members(con, ref, _names_of(con, ref))
        )
        if has_proto == "1":
            proto = f"Object.getPrototypeOf({ref})"
            entry["prototype_members"] = _scan_members(con, proto, _names_of(con, proto))
    return entry


def _is_native_class(entry):
    """True for a global that is really a native CLASS, not just a function.

    Every JS function owns a .prototype, so `is_class` (has-a-prototype) over-counts: the plain
    utility globals `consoleMessage`, `formatCredits` and `formatInteger` each own a prototype
    whose only member is `constructor`, and ConsoleSettings is a Debug-OXP constructor with the
    same empty shape. A native class installed by JS_InitClass carries real members on its
    prototype, so requiring more than the automatic `constructor` is what separates the two.
    """
    if entry.get("type") != "function" or not entry.get("is_class"):
        return False
    members = entry.get("prototype_members")
    if not isinstance(members, dict):
        return False
    return bool(set(members) - {"constructor"})


def _summarise(globals_map):
    names = sorted(globals_map)
    oolite = sorted(n for n in names if n not in ECMA_GLOBALS)
    shipped = [n for n in oolite if n not in DEBUG_GLOBALS]
    classes = sorted(n for n in oolite if _is_native_class(globals_map[n]))
    return {
        "global_count": len(names),
        "ecmascript_global_count": len(names) - len(oolite),
        "oolite_global_count": len(oolite),
        "oolite_global_count_without_debug_console": len(shipped),
        "class_count": len(classes),
        "classes": classes,
        "oolite_globals": oolite,
        "debug_console_globals": sorted(n for n in oolite if n in DEBUG_GLOBALS),
    }


def _open_session(app_dir, port, host, settle, ready_timeout):
    """Launch the game and bring one console session up to the point where scanning can start.

    Returned as a tuple rather than kept in `collect` inline because the session is DISPOSABLE:
    see _collect_globals, which throws one away and opens another when the transport dies.
    """
    con = DebugConsole(app_dir, port, seed=1, output_dir=None, host=host)
    con.start(ready_timeout=ready_timeout)
    _wait_until_rendering(con, settle)
    version = con.evaluate("oolite.versionString").strip()
    con.perform(" ".join(HELPERS_JS.split()))
    time.sleep(1.0)
    if con.evaluate("typeof __ooScan", timeout=20).strip() != "function":
        raise ConsoleError("the enumeration helpers did not install on the global")
    names = [n for n in _names_of(con, "__ooGlobal") if not n.startswith(HARNESS_PREFIX)]
    return con, version, names


# The console transport dies non-deterministically mid-run on Windows: the game's end of the
# socket is reset (ConnectionResetError / WinError 10054) part-way through a long enumeration,
# which killed two earlier full runs at 46/121 and 30/121 globals. Diagnosing that in the game is
# a separate job; what this tool owes is not to lose an hour of scanning to it. A dropped session
# is therefore replaced with a fresh one and the enumeration RESUMES at the global that died -
# globals are independent, so a restart costs only the boot time. Bounded, and loud if exhausted:
# silently emitting a short snapshot would be worse than failing.
MAX_SESSION_RESTARTS = 6


def _is_transport_death(exc):
    """True for an exception that means the socket died, not that the game answered badly.

    OSError covers ConnectionResetError / ConnectionAbortedError / BrokenPipeError. The console
    also reports a half-closed socket as its own ConsoleError from _recv returning None, which is
    the same event seen one layer up, so that specific message counts too. Everything else - a JS
    error, a timeout, a disagreeing global set - is a real finding and must not be retried away.
    """
    if isinstance(exc, (OSError, EOFError)):
        return True
    return isinstance(exc, ConsoleError) and "connection closed" in str(exc)


def _collect_globals(app_dir, port, host, settle, ready_timeout):
    """Describe every global, surviving a dropped console transport by relaunching and resuming."""
    result = {}
    version = None
    names = None
    restarts = 0
    while True:
        con = None
        try:
            con, version, session_names = _open_session(app_dir, port, host, settle, ready_timeout)
            if names is None:
                names = session_names
            elif session_names != names:
                # A restart that sees a different global set is not a resumption of the same
                # measurement, and splicing the two would produce a document describing no single
                # runtime. Start the whole snapshot over rather than emit a chimera.
                raise ConsoleError(
                    f"the relaunched game exposes {len(session_names)} globals, not {len(names)}; "
                    "the snapshot cannot be spliced across two different runtimes"
                )
            for index, name in enumerate(names, 1):
                if name in result:
                    continue
                result[name] = _describe_global(con, name)
                print(f"[*] {index:3d}/{len(names)} {name}", flush=True)
            return version, result
        except (OSError, EOFError, ConsoleError) as exc:
            if not _is_transport_death(exc):
                raise
            restarts += 1
            done = len(result)
            if restarts > MAX_SESSION_RESTARTS:
                raise ConsoleError(
                    f"the console transport died {restarts} times ({exc}); gave up after "
                    f"{done}/{len(names) if names else '?'} globals. The snapshot was NOT written."
                ) from exc
            print(f"[~] console transport died after {done} globals ({exc}); "
                  f"relaunching and resuming (restart {restarts}/{MAX_SESSION_RESTARTS})",
                  flush=True)
            time.sleep(2.0)
        finally:
            if con is not None:
                try:
                    con.close()
                except Exception:
                    pass


def collect(app_dir, port, host, settle, ready_timeout):
    _ensure_software_gl(app_dir)
    config_dir = _console_config_dir(host, port)
    output_dir = tempfile.mkdtemp(prefix="oolite-jsapi-out-")
    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = f"{config_dir},{previous}" if previous else config_dir
    os.environ["OO_SNAPSHOTSDIR"] = output_dir
    os.environ["OO_LOGSDIR"] = output_dir
    try:
        version, result = _collect_globals(app_dir, port, host, settle, ready_timeout)
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        shutil.rmtree(config_dir, ignore_errors=True)
        shutil.rmtree(output_dir, ignore_errors=True)

    return {
        "schema": "oolite-js-api/1",
        "oolite_version": version,
        "summary": _summarise(result),
        "globals": result,
    }


def write_snapshot(document, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    # sort_keys plus a fixed indent is the whole determinism contract: there is no timestamp, no
    # path, no port and no address anywhere in the document.
    text = json.dumps(document, sort_keys=True, indent=2, ensure_ascii=True) + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    return text


def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Regenerate the Oolite JS API conformance snapshot")
    p.add_argument("--app", default=os.environ.get("OO_APP_DIR") or DEFAULT_APP_DIR,
                   help="Path to oolite.app (default: $OO_APP_DIR, else the meson test build)")
    p.add_argument("--output", default=DEFAULT_OUTPUT, help="Snapshot file to write")
    p.add_argument("--port", type=int,
                   default=int(os.environ.get("OO_CONSOLE_PORT", DEFAULT_PORT)))
    p.add_argument("--host", default=os.environ.get("OO_CONSOLE_HOST", "127.0.0.1"))
    p.add_argument("--settle", type=float, default=SETTLE_GAME_SECONDS)
    p.add_argument("--ready-timeout", type=float,
                   default=float(os.environ.get("OO_READY_TIMEOUT", "240")))
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    if not os.path.isdir(args.app):
        print(f"[!] no Oolite build at {args.app}; build it first (tools/build-windows.sh test)")
        return 1
    document = collect(args.app, args.port, args.host, args.settle, args.ready_timeout)
    write_snapshot(document, args.output)
    s = document["summary"]
    print(f"[+] {args.output}: {s['global_count']} globals "
          f"({s['oolite_global_count']} Oolite, {s['ecmascript_global_count']} ECMAScript), "
          f"{s['class_count']} native classes, oolite {document['oolite_version']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
