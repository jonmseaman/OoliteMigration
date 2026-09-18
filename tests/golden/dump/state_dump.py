"""Shared glue for the oo-gla canonical dump: build the JS, run it, and spawn a deterministic
scenario to run it against.

Kept separate from dump_state.js on purpose: the JS is the thing under test (it runs inside the
game), this file is Python driving the console the same way tests/component/console.py and
tests/golden/golden_run.py already do (ADR-0018: console.py is the shared transport).
"""

import json
import os
import struct
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP_JS_PATH = os.path.join(HERE, "dump_state.js")

# STATUS_DLL_NOT_FOUND. Windows reports this as the process EXIT CODE when the image loader
# cannot resolve a static import before the program's entry point runs - so the game dies with
# no Latest.log at all, which is how this failure is told apart from a game that started and
# then failed (the latter always leaves a log). See ensure_launchable() for why it happens here.
STATUS_DLL_NOT_FOUND = 0xC0000135  # 3221225781


class LaunchEnvironmentError(RuntimeError):
    """The app dir cannot be launched at all, for a reason no amount of retrying will fix."""


def _pe_imports(path):
    """Return the DLL names in `path`'s PE import directory ([] if it has none / is not a PE).

    Stdlib only, deliberately: adding pefile as a test dependency to diagnose a launch failure
    would make the diagnosis itself another thing that can fail to import.
    """
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except OSError:
        return []
    if data[:2] != b"MZ":
        return []
    try:
        pe = struct.unpack_from("<I", data, 0x3C)[0]
        nsec = struct.unpack_from("<H", data, pe + 6)[0]
        opt_size = struct.unpack_from("<H", data, pe + 20)[0]
        magic = struct.unpack_from("<H", data, pe + 24)[0]
        dd = pe + 24 + (112 if magic == 0x20B else 96)
        import_rva = struct.unpack_from("<I", data, dd + 8)[0]
        if not import_rva:
            return []
        sections = []
        sec_off = pe + 24 + opt_size
        for i in range(nsec):
            base = sec_off + i * 40
            vsize, vaddr = struct.unpack_from("<II", data, base + 8)
            rsize, raw = struct.unpack_from("<II", data, base + 16)
            sections.append((vaddr, max(vsize, rsize), raw))

        def to_offset(rva):
            for vaddr, size, raw in sections:
                if vaddr <= rva < vaddr + size:
                    return raw + (rva - vaddr)
            return None

        out = []
        off = to_offset(import_rva)
        while off is not None:
            entry = data[off:off + 20]
            if len(entry) < 20 or entry == b"\0" * 20:
                break
            name_rva = struct.unpack_from("<I", entry, 12)[0]
            if name_rva:
                noff = to_offset(name_rva)
                if noff is None:
                    break
                out.append(data[noff:data.index(b"\0", noff)].decode("ascii", "replace"))
            off += 20
        return out
    except (struct.error, ValueError, IndexError):
        return []


def _search_dirs():
    """Directories the Windows image loader will search, in its own order, for this process."""
    dirs = [os.environ.get("SystemRoot", r"C:\Windows") + os.sep + "System32"]
    dirs += [d for d in os.environ.get("PATH", "").split(os.pathsep) if d]
    return dirs


def unresolved_imports(app_dir, roots=("oolite.exe", "libgallium_wgl.dll")):
    """Walk the transitive PE import graph from `roots` and report what the loader cannot find.

    Returns {missing_dll_name: set(of importers)}. api-ms-win-* / ext-ms-* are skipped: those are
    API-SET contract stubs the OS resolves virtually from an in-memory schema, so they are
    legitimately absent from disk and reporting them would bury the real answer in noise.

    libgallium_wgl.dll is walked as a root even though nothing statically imports it, because
    opengl32.dll (Mesa's, staged into the app dir by the component tier) LoadLibrary()s it at
    initGL time - it is therefore part of the launch's real dependency set.
    """
    search = _search_dirs()
    app_dir = os.path.abspath(app_dir)

    def locate(name):
        direct = os.path.join(app_dir, name)
        if os.path.isfile(direct):
            return direct
        for d in search:
            cand = os.path.join(d, name)
            if os.path.isfile(cand):
                return cand
        return None

    missing, seen = {}, set()
    queue = [r for r in roots if os.path.isfile(os.path.join(app_dir, r))]
    queue = [(r, os.path.join(app_dir, r)) for r in queue]
    while queue:
        name, path = queue.pop(0)
        if name.lower() in seen:
            continue
        seen.add(name.lower())
        for imp in _pe_imports(path):
            low = imp.lower()
            if low.startswith("api-ms-win-") or low.startswith("ext-ms-"):
                continue
            found = locate(imp)
            if found is None:
                missing.setdefault(imp, set()).add(name)
            else:
                queue.append((imp, found))
    return missing


def _candidate_runtime_dirs():
    """Where the MSYS2/UCRT64 runtime DLLs plausibly live, most authoritative first."""
    cands = []
    explicit = os.environ.get("OO_RUNTIME_DLL_DIR")
    if explicit:
        cands.append(explicit)
    prefix = os.environ.get("MSYSTEM_PREFIX")
    if prefix:
        cands.append(os.path.join(prefix, "bin"))
    # The interpreter running this script is itself normally /ucrt64/bin/python3.exe, so its own
    # directory is the single most reliable pointer to the matching runtime - it cannot be stale
    # the way a hardcoded path can, and it is right by construction whenever the acceptance line's
    # `command -v python3` fallback chain resolved to the UCRT64 python.
    cands.append(os.path.dirname(os.path.abspath(sys.executable)))
    cands += [
        r"C:\Users\jon\scoop\apps\msys2\current\ucrt64\bin",
        r"C:\msys64\ucrt64\bin",
    ]
    out, seen = [], set()
    for c in cands:
        c = os.path.abspath(c)
        if c.lower() not in seen and os.path.isdir(c):
            seen.add(c.lower())
            out.append(c)
    return out


def ensure_launchable(app_dir, verbose=True):
    """Make the app dir launchable BEFORE spawning the game, or fail with the real reason.

    THE BUG THIS EXISTS FOR, measured rather than guessed. When the shell running the acceptance
    line does not have the UCRT64 runtime directory on PATH, the game dies with exit code
    3221225781 (STATUS_DLL_NOT_FOUND) before its entry point, writing NO Latest.log. The console
    harness then reports 'Oolite exited with 3221225781 before connecting to the console', and
    start_with_retry burns all 8 attempts (~116s) because a missing PATH entry is not a race and
    retrying cannot fix it.

    The dependency is TRANSITIVE, which is why a direct-import check clears the binary and the
    failure looks mysterious: all 32 of oolite.exe's own imports resolve. It is Mesa's
    libgallium_wgl.dll - loaded by the staged opengl32.dll - that needs libLLVM-22.dll,
    libSPIRV-Tools.dll and libsystre-0.dll, and those exist ONLY in the UCRT64 runtime directory.

    This is a property of the invoking SHELL, not of the machine, the clock or the app dir, which
    is why the failure looked intermittent 'in time': the same paths succeed from a shell that has
    the directory and fail from one that does not.

    Repairs os.environ["PATH"] (inherited by console.py's Popen through its env.copy()) when a
    directory supplying the missing DLLs can be found, and raises LaunchEnvironmentError naming
    the exact DLLs otherwise - a loud, specific failure instead of two minutes of silent retries.
    """
    missing = unresolved_imports(app_dir)
    if not missing:
        return []

    added = []
    for cand in _candidate_runtime_dirs():
        names = {n.lower() for n in os.listdir(cand)}
        if not any(m.lower() in names for m in missing):
            continue
        os.environ["PATH"] = cand + os.pathsep + os.environ.get("PATH", "")
        added.append(cand)
        missing = unresolved_imports(app_dir)
        if not missing:
            if verbose:
                sys.stderr.write(
                    "preflight: added %s to PATH to resolve the game's transitive runtime "
                    "imports (would otherwise exit %d/STATUS_DLL_NOT_FOUND with no log)\n"
                    % (os.pathsep.join(added), STATUS_DLL_NOT_FOUND)
                )
            return added

    raise LaunchEnvironmentError(
        "the Oolite build at %s cannot be launched: the image loader cannot resolve %s.\n"
        "Needed by: %s\n"
        "Searched: %s\n"
        "This is an ENVIRONMENT fault, not a flake - the game would exit %d "
        "(STATUS_DLL_NOT_FOUND) before writing any log, and no retry can fix it. Put the UCRT64 "
        "runtime directory on PATH (export PATH=\"/ucrt64/bin:$PATH\") or set OO_RUNTIME_DLL_DIR."
        % (
            app_dir,
            ", ".join(sorted(missing)),
            "; ".join("%s <- %s" % (k, ",".join(sorted(v))) for k, v in sorted(missing.items())),
            os.pathsep.join(_candidate_runtime_dirs()) or "(no candidate directory exists)",
            STATUS_DLL_NOT_FOUND,
        )
    )


def start_with_retry(make_console, attempts=8, ready_timeout=180):
    """Build and start a fresh DebugConsole, retrying a handful of times.

    `make_console` is a zero-arg factory (not a console instance): native process launch on this
    VM occasionally fails with WinError-class DLL-load races before the game ever reaches main()
    (observed: STATUS_DLL_NOT_FOUND, exit code 3221225781) - nothing to do with the dump itself,
    unrelated to determinism (also seen and documented independently on bead oo-16s's Mesa
    staging), but it can leave the failed DebugConsole's listening socket bound. A fresh instance
    per attempt avoids retrying start() on an already-bound port. Backoff grows because the
    underlying race has been observed to persist for tens of seconds on a loaded VM.

    NOTE ON STATUS_DLL_NOT_FOUND: the dominant cause of that exit code here is NOT a race but a
    PATH missing the UCRT64 runtime directory, which retrying cannot repair - see
    ensure_launchable(), which run_dump.py calls before the first attempt. If it still appears
    after the preflight passed, something changed the app dir mid-flight (a concurrent tier
    parking DLLs), so it stays retryable here; but the retry loop re-checks and gives up early
    with the real reason rather than silently burning 8 backoffs on an unfixable condition.
    """
    from console import ConsoleError

    last = None
    for attempt in range(attempts):
        console = make_console()
        try:
            console.start(ready_timeout=ready_timeout)
            return console
        except ConsoleError as exc:
            last = exc
            try:
                console.close()
            except Exception:
                pass
            # A launch that died of STATUS_DLL_NOT_FOUND is worth ONE re-check rather than eight
            # blind backoffs: if the dependency graph is genuinely broken, say so now with the
            # missing DLL named, instead of 116 seconds later with a bare exit code.
            if str(STATUS_DLL_NOT_FOUND) in str(exc):
                app_dir = getattr(console, "app_dir", None)
                if app_dir:
                    missing = unresolved_imports(app_dir)
                    if missing:
                        raise LaunchEnvironmentError(
                            "Oolite exited %d (STATUS_DLL_NOT_FOUND) and the image loader still "
                            "cannot resolve: %s. Retrying cannot fix a missing runtime directory; "
                            "put the UCRT64 bin directory on PATH or set OO_RUNTIME_DLL_DIR."
                            % (STATUS_DLL_NOT_FOUND, ", ".join(sorted(missing)))
                        )
            time.sleep(min(30, 3 * (attempt + 1)))
    raise last


def dump_js_source():
    with open(DUMP_JS_PATH, "r", encoding="utf-8") as handle:
        return handle.read()


def dump_state(console, timeout=30):
    """Run the dump inside the game and return the raw JSON text it printed.

    console.evaluate() already wraps the expression in String(...) and marker-delimits the
    reply (tests/component/console.py:210), so the dump script's JSON.stringify(...) result comes
    back as a Python str unmodified - JSON.stringify never emits the console's own marker
    characters, so no collision is possible.
    """
    return console.evaluate(dump_js_source(), timeout=timeout)


def dump_state_parsed(console, timeout=30):
    return json.loads(dump_state(console, timeout=timeout))


# --- deterministic scenario setup -------------------------------------------------------------
#
# Ship identity for sorting: shipUniqueName, zero-padded per role so a lexicographic sort is a
# spawn-order sort (tests/component/steps/world_steps.py already gives ships their role's real AI
# the same way; this only ADDS a deterministic name on top, addShips itself does not name ships).

_SPAWN_JS = (
    "(function(){"
    " var at = player.ship.position;"
    " var added = system.addShips(%(role)r, %(count)d, at, %(radius)d);"
    " if (!added) return 0;"
    " for (var i = 0; i < added.length; i++) {"
    "   added[i].shipUniqueName = %(role)r + '-' + ('000' + i).slice(-3);"
    "   %(ai)s"
    " }"
    " return added.length; })()"
)


def spawn_deterministic(console, role, count, radius_m=2000, ai=None):
    """Spawn `count` ships of `role`, named `<role>-000`, `<role>-001`, ... for a stable sort key.

    Mirrors tests/component/steps/world_steps.py::_spawn (ADR-0018's step catalogue) but adds the
    explicit name, which that step does not need because component-tier assertions never sort
    ships - this dump does, and iteration order over an unordered NSDictionary/JS-array-from-
    addShips is exactly the class of bug docs/fleet/LEARNINGS.md and bead oo-djn are about.
    """
    ai_js = ("added[i].setAI(%r);" % ai) if ai else ""
    js = _SPAWN_JS % {"role": role, "count": count, "radius": radius_m, "ai": ai_js}
    added = console.evaluate_int(js)
    if added != count:
        raise AssertionError("asked for %d %r, addShips returned %d" % (count, role, added))
    return added


def run_ticks(console, ticks, tick_seconds=0.125):
    """Advance the simulation for N AI-think ticks of GAME time (never the harness clock).

    NOT used by run_dump.py's default flow: run_once() pauses instead (see its docstring for why
    that is sufficient for decision 11's determinism requirement without fixed-delta-t stepping).
    Kept for a scenario that genuinely needs the AI to move, where the caller accepts that two
    dumps then differ unless the caller pins delta_t itself - out of scope for this bead.

    Uses clock.absoluteSeconds the same way tests/golden/golden_run.py::_wait_until_rendering
    does, rather than time.sleep, so the dump is reproducible independent of how slow the host
    happens to render any one run.
    """
    budget = ticks * tick_seconds
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline_wall = time.time() + max(60.0, budget * 4)
    while time.time() < deadline_wall:
        elapsed = float(console.evaluate("clock.absoluteSeconds")) - start
        if elapsed >= budget:
            return elapsed
        time.sleep(0.1)
    raise AssertionError("game time did not advance %ss within the wall budget" % budget)
