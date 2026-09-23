"""Golden scenario 007-js-interface: stage the in-tree `JavaScript Interface Tests` test-oxp,
run ITS OWN test rig inside a live game, and emit a canonical state dump carrying the rig's own
PASS/FAIL output as evidence.

Follows tests/golden/launch_dock.py (scenario 001, bead oo-jor) in every structural respect:
fixed seed, fixed system, fixed tick count, a private console port, a canonical quantised dump,
and an evidence block stored INSIDE the dump so every future comparison re-checks it.

THE ANTI-VACUITY PROBLEM IS SHARPER HERE THAN ANYWHERE ELSE IN THE SUITE
-----------------------------------------------------------------------
A JS interface test that silently fails to RUN produces exactly the same clean log as one that
ran and passed every assertion. Absence of errors proves nothing. `[startup.complete]` proves the
GAME booted, not that a single line of the expansion's JavaScript ever executed.

So this scenario asserts on OUTPUT THE TEST-OXP ITSELF PRODUCES, and on nothing else:

  * `upstream/oolite-tests/.../oolite-script-test-rig.js` renders every result through
    `printResult()`, which calls `consoleMessage("command-result", "Pass: " + name)` on success
    and `consoleMessage("error", "FAIL: " + name + " -- " + error)` on failure, and finishes in
    `completeTests()` with either `All <N> tests passed.` or `***** <F> of <N> tests FAILED`.
  * `install_collector()` wraps `debugConsole.consoleMessage` so those strings are recorded in
    the game, in an array this harness never writes to. The wrapper only records lines with the
    rig's own prefixes (`Pass: `, `FAIL: `, `All `, `***** `), so the console's own marker traffic
    (console.py's evaluate() also goes through consoleMessage) cannot inflate the counts.
  * `evidence.js_completion_line` is the rig's terminal line, VERBATIM. A run in which the JS
    never executed has an EMPTY completion line and the run refuses to write a dump at all.
  * `evidence.js_test_names_sha256` is the SHA-256 of the sorted, newline-joined set of test
    names the rig reported. It is a dump field that CANNOT EXIST unless the rig's scripts ran:
    the names live only inside the expansion's `$registerTest(...)` call sites, and this file
    contains none of them. A dead run hashes the empty set, which is a different digest and is
    rejected by name.

WHY THE COUNTS ARE STORED AS WELL AS THE DIGEST. The digest pins WHICH tests ran; `js_pass_lines`
and `js_fail_lines` pin HOW THEY WENT. A regression that makes `Vector3D.cross` start failing
keeps the digest identical and moves `js_fail_lines` from 0 to 1, which `golden_diff.py` reports
by name. A regression that DROPS a test keeps the pass count plausible and moves the digest.
Neither alone is sufficient.

NO MANIFEST, AND CONSOLE NOISE: A TWO-RULE ALLOW-LIST, AUDITABLE LINE BY LINE
------------------------------------------------------------------------------
This scenario is the first gate in the tree to scan `Latest.log` for error lines at all - scenario
001 does not - so it is the first to meet the ambient noise, and it owns getting the allow-list
right. The allow-list is EXACTLY TWO RULES and `classify_allowed()` is its whole implementation:

  | rule                              | matched on | reason                                       |
  |-----------------------------------|------------|----------------------------------------------|
  | `has no manifest.plist`           | message    | the fixture is one of five legacy in-tree     |
  |                                   |            | test-oxps that predate the manifest format    |
  |                                   |            | (bead oo-kcrw, `NOMANIF`). EXACT count of 2,  |
  |                                   |            | and each line must NAME our staged copy.      |
  | channel `debugTCP.send.error`     | CHANNEL    | debug-console TRANSPORT failed to deliver a   |
  |                                   |            | packet. Observed on PASSING runs of three     |
  |                                   |            | unrelated expansions in oo-kcrw's tier1       |
  |                                   |            | corpus (each at line 40, `Request            |
  |                                   |            | Connection`), all reaching startup.complete.  |

`JavaScript Interface Tests.oxp` ships no `manifest.plist` and emits EXACTLY 2 such lines per
load. THE DECISION TAKEN HERE IS TO ALLOW-LIST THEM BY EXACT MESSAGE AND EXACT COUNT, and NOT to
stage a synthetic manifest. Reasons, in order:

  1. Staging a manifest would mean this golden measures a fixture that DOES NOT EXIST IN THE
     TREE. The bead is "exercise the JS interface test-oxp", not "exercise a repaired copy of
     it", and a golden of an artefact nobody ships is a golden of nothing.
  2. oo-kcrw's `NOMANIF` state is honest precisely because it is gated on positive proof of
     loading AND on the errors being exclusively that message at that exact count. Reproducing
     that gate here keeps the two instruments saying the same thing about the same fixture.
  3. The allow-list is narrower than a suppression in four checkable ways, all enforced by
     `assert_log()`: loading is proven FIRST so a dead run can never reach an allow-list branch;
     the no-manifest count must be EXACTLY `EXPECTED_NOMANIF_LINES` (a third line fails); every
     allow-listed no-manifest line must NAME OUR STAGED COPY; and every OTHER error line is fatal
     with the line quoted. The count is stored in the dump as `evidence.oxp_nomanifest_errors`,
     so the golden pins it and a run with 1 or 3 fails the ordinary diff as well as the checker.

THE SECOND RULE IS MATCHED BY CHANNEL, NOT BY PACKET BODY, because the body carries the command
text, an Oolite version string and colour keys - all volatile - and a body-shaped rule would
fragment into a family of near-identical patterns. It is ALSO deliberately narrow: it names
`debugTCP.send.error` and nothing wider. `[debugTCP.connected]: Connected to debug console "..."`
is the SIBLING-HIJACK signature from bead oo-het and stays FATAL, asserted positively by
`assert_no_hijack()`; a rule matching `debugTCP` generally would have swallowed it.

AND THE TEARDOWN INSTANCE IS FIXED AT THE SOURCE RATHER THAN EXCUSED: the log is read BEFORE
`console.close()` fires `quit();`, so the `> quit();` undeliverable-packet line never falls inside
the scanned window at all. The channel rule covers the CONNECTION-time instance, which does.

PORT / LAUNCH ISOLATION, AND THE STAGED EXPANSION
-------------------------------------------------
Reuses `golden_run.py` wholesale (reserved port, staged app dir, a debugConfig.plist in a private
OO_ADDITIONALADDONSDIRS root) because the game DIALS OUT to the port named in that plist
(OODebugSupport.m:67-80); a run on the shared 8563 can be captured and quit by a sibling worker's
console four seconds in while still exiting rc=0 (bead oo-het). The expansion under test is copied
into a SECOND private addons root, so the shared build's AddOns is never touched and two
concurrent runs cannot see each other's staging.

THE STAGING DIRECTORY MUST NOT BE CALLED `addons`, AND THAT COST A RUN TO LEARN
------------------------------------------------------------------------------
The game's search paths always include the RELATIVE root `../AddOns`, resolved against the staged
app directory - i.e. `<artifact_dir>/AddOns`. The first version of this file staged the expansion
into `<artifact_dir>/addons`, and WINDOWS FILESYSTEMS ARE CASE-INSENSITIVE, so those are the same
directory. The game therefore enumerated one staged copy TWICE, under two different path
spellings, and the run failed its own exact-count allow-list with

    expected EXACTLY 2 'has no manifest.plist' line(s) ... but the log has 4
      ... /addons/JavaScript Interface Tests.oxp has no manifest.plist
      ... ../AddOns/JavaScript Interface Tests.oxp has no manifest.plist   (x2 each)

That is the exact-count guard doing its job: a floor (`>= 2`) would have passed silently while the
scenario measured a doubly-loaded expansion. The directory is named `oxp-under-test` for that
reason - anything that collides with `AddOns` case-insensitively re-opens the bug.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DUMP_DIR = os.path.join(HERE, "dump")

sys.path.insert(0, HERE)
sys.path.insert(0, DUMP_DIR)
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))

import golden_run  # noqa: E402

# NO DESKTOP LOCK, deliberately: this is a golden-harness scenario driver, exempt from tools/gui-lock
# on golden_run.py's terms (see its module docstring and tools/check-desktop-lock.sh). It launches
# through golden_run's per-run isolation - a reserved port, a staged private app dir, a private
# artifact dir - which exists so that golden runs can share one machine AT ONCE (stability sweeps,
# tier-b/tier-c golden stages, and several fleet worktrees' acceptance lines side by side). The
# desktop mutex is exclusive, so taking it here would serialise all of them into a queue of one.
# The run never needs the FOREGROUND: no synthetic input, no window click, readiness over the
# console socket, and every frame is rendered game-side from the game's own framebuffer. If this
# scenario ever starts to need the foreground it stops being exempt and must take the lock.
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "007-js-interface"

# The spec and the golden live under tests/golden/staging/ until Jon lands them (goldens/ and
# tests/golden/scenarios/ are both guarded by tools/guardrails.sh, which refuses a brand-new file
# under either without a re-bless approval). BOTH locations are searched, blessed-first, so the
# landing is a pure `git mv` with no edit to this file. See
# tests/golden/staging/007-js-interface/LANDING.md.
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "staging", SCENARIO, "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "staging", SCENARIO, "state.json"),
)

OXP_SOURCE = os.path.join(REPO_ROOT, "upstream", "oolite-tests", "test-oxps", "JSInterfaceTests",
                          "JavaScript Interface Tests.oxp")
OXP_DIRNAME = "JavaScript Interface Tests.oxp"

RIG_SCRIPT_NAME = "oolite-script-test-rig"
RIG_RUN_TIMEOUT_SECONDS = 180
TICK_WALL_BUDGET_SECONDS = 300

#: The legacy in-tree fixtures emit EXACTLY this many `has no manifest.plist` lines per load.
#: Measured by bead oo-kcrw across five unrelated fixtures; an EXACT count, not a floor, so a
#: third line of the same message is a failure rather than a silently wider allow-list.
EXPECTED_NOMANIF_LINES = 2
NOMANIF_RE = re.compile(r"has no manifest\.plist\s*$")

#: THE CONSOLE-TRANSPORT ALLOW-LIST, MATCHED BY CHANNEL AND BY CHANNEL ONLY.
#:
#: `[debugTCP.send.error]: The following packet could not be sent: {...}` is the debug-console
#: TRANSPORT failing to deliver a packet. It is NOT the game failing at anything, and this
#: scenario is the first gate in the tree to meet it because scenario 001 does not scan
#: Latest.log for error lines at all - the log-error predicate is this bead's addition.
#:
#: EVIDENCE THAT IT IS BENIGN, gathered from runs that are not this scenario's: bead oo-kcrw's
#: tier1 corpus runs of three unrelated, PASSING expansions each carry this channel at line 40 -
#:   oolite_.DrNil.YAH/Logs/Latest.log:40          {"packet type" = "Request Connection"; ...}
#:   oolite_.Griff.Griff_shipset_decals/.../:40    (same)
#:   oolite_.Griff_alloys_and_wreckage/.../:40     (same)
#: all three reached [startup.complete] and were scored PASS. The instance this scenario produces
#: is the most benign variant of all: the undeliverable packet is the console echoing our OWN
#: `> quit();` teardown command into a socket that is closing because we asked it to.
#:
#: MATCHED BY CHANNEL, NOT BY BODY, and that is deliberate. The packet body carries the command
#: text, an Oolite version string and colour keys - all volatile - so a body-shaped rule would
#: fragment into a family of near-identical patterns, which is precisely the clustering failure
#: bead oo-4z6 documented. One channel, one rule, one reason.
#:
#: WHAT THIS DELIBERATELY DOES **NOT** COVER. The rule is anchored to the `.send.error` channel
#: and nothing wider. `[debugTCP.connected]: Connected to debug console "..."` is the
#: SIBLING-HIJACK signature from bead oo-het - a stranger's console attaching to the game and
#: quitting it 4.7 s in, leaving rc=0 and a log with zero errors and a fully vacuous pass. A rule
#: matching `debugTCP` generally would swallow it. It must stay fatal, and `assert_no_hijack()`
#: makes it fatal positively rather than relying on it not being allow-listed.
DEBUGTCP_SEND_ERROR_CHANNEL = "debugTCP.send.error"

#: The hijack signature, kept FATAL. The real defence is the private port + debugConfig.plist
#: (see the module docstring and `golden_run._write_console_config`): the game dials OUT to the
#: port named in that plist, so a sibling on 8563 cannot reach this run at all. This check is the
#: belt to that braces - it proves the isolation held rather than assuming it.
HIJACK_RE = re.compile(r"\[debugTCP\.connected\]")
OUR_CONSOLE_IDENTITY = "OoliteComponentTests"

# Error-line classification, copied verbatim in intent from tools/oxp_load_check.py:174-194 so
# the two instruments agree about what an error line is. A literal `grep ERROR` misses
# `[oxp-standards.error]` entirely, which is the very channel this scenario has to reason about.
ERROR_TOKEN_RE = re.compile(r"\bERROR\b")
ERROR_STARS_RE = re.compile(r"\*\*\*\*\*")
ERROR_CHANNEL_RE = re.compile(r"^\d\d:\d\d:\d\d\.\d+ \[([^\]]+)\]")
ERROR_CHANNEL_NAME_RE = re.compile(r"(\.error|\.failed|\.exception)(\.|$|:)", re.I)

# The rig's own output prefixes (oolite-script-test-rig.js printResult/completeTests). ONLY lines
# with these prefixes are recorded, so console.py's evaluate() marker traffic - which also goes
# through consoleMessage - can never be mistaken for a test result.
#
# TWO SHAPES HERE WERE MEASURED, AND THE FIRST ONE SILENTLY LOST 68 OF 69 RESULTS.
#
# (1) THE ORIGINAL FUNCTION IS HELD IN A CLOSURE, NOT ON `debugConsole`. The first version did
#     `debugConsole.oo5k2Orig = debugConsole.consoleMessage` and then called it back through that
#     property. `debugConsole` is a NATIVE Console object (OOJSConsole.m:195, sConsoleClass) with
#     its own get/set hooks, and a function round-tripped through one does not come back
#     callable. A closure variable has no such hook.
# (2) THE ACCUMULATOR IS A STRING, NOT AN ARRAY, and that is not a style choice. Scratch state
#     lives on `debugConsole.script` (the console's scratch object, used the same way by
#     world_steps.py:135 / OODebugMonitor.m:761), but the property round trip is by VALUE:
#     `debugConsole.script.lines.push(m)` mutates a copy that is thrown away, while
#     `debugConsole.script.done = m` (a scalar assignment) persists. Measured consequence of
#     getting this wrong: the rig reported `All 69 tests passed.` - so the wrapper was demonstrably
#     alive at the very last line - while the array held exactly 1 entry. A scalar read-modify-
#     write (`s = s + SEP + m`) persists because every step is a scalar.
#
#     THE CROSS-CHECK IN `assert_ran` IS WHAT CAUGHT THIS, twice. A gate that only counted
#     "some results arrived" would have blessed a golden recording 1 of 69 results, and the dump
#     would have been perfectly reproducible. Requiring the completion line's N to EQUAL the
#     number of per-test result lines is the clause that made a silent 68-result loss loud.
#
# (3) THE SEPARATOR MUST BE PRINTABLE ASCII, AND THIS IS THE THIRD TIME THE SAME SYMPTOM HAD A
#     DIFFERENT CAUSE. The first separator was an ASCII unit separator (U+001F), chosen because
#     no test name can contain one. It is preserved perfectly INSIDE the game - a probe read back
#     70 correctly separated entries - but the debug-console protocol carries the value in an XML
#     PROPERTY LIST, and plistlib renders a C0 control character as the six literal characters
#     `\U001F`. Python then split on a real U+001F that was no longer there, found none, and saw
#     the whole 69-result payload as ONE line. Same "1 of 69" symptom as (1) and (2), third
#     distinct cause - which is why each was measured rather than guessed at.
#
#     `OO5K2_SEP` is therefore printable, and long and odd enough that no test name in the
#     expansion can contain it. `assert_ran` additionally cross-checks the split count against
#     the completion line, so a separator collision would be loud rather than silent.
OO5K2_SEP = "<|oo5k2|>"

COLLECT_JS = """(function(){
  var SEP = %(sep)s;
  debugConsole.script.oo5k2Lines = "";
  debugConsole.script.oo5k2Done = "";
  var orig = console.consoleMessage;
  console.consoleMessage = function (colorCode, message) {
    var m = String(message);
    if (m.indexOf("Pass: ") === 0 || m.indexOf("FAIL: ") === 0 ||
        m.indexOf("All ") === 0 || m.indexOf("***** ") === 0) {
      debugConsole.script.oo5k2Lines =
        String(debugConsole.script.oo5k2Lines || "") + m + SEP;
      if (m.indexOf("All ") === 0 || m.indexOf("***** ") === 0) {
        debugConsole.script.oo5k2Done = m;
      }
    }
    return orig.apply(console, arguments);
  };
  return "INSTALLED";
})()""" % {"sep": json.dumps(OO5K2_SEP)}

READ_LINES_JS = "(function(){ return String(debugConsole.script.oo5k2Lines || ''); })()"
READ_DONE_JS = "(function(){ return String(debugConsole.script.oo5k2Done || ''); })()"
#: Counted IN THE GAME as well as in Python. The two must agree, which is what turns a transport
#: mangling of the separator (see (3) above) from a silent truncation into a named failure.
READ_COUNT_JS = ("(function(){ var s = String(debugConsole.script.oo5k2Lines || '');"
                 " return String(s ? s.split(%s).length - 1 : 0); })()" % json.dumps(OO5K2_SEP))


class ScenarioError(RuntimeError):
    pass


def _first_existing(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise ScenarioError("no %s found; looked at %s" % (what, ", ".join(candidates)))


def spec_path():
    return _first_existing(SPEC_CANDIDATES, "spec.json for scenario %s" % SCENARIO)


def golden_path():
    return _first_existing(GOLDEN_CANDIDATES, "stored golden for scenario %s" % SCENARIO)


def load_spec(path=None):
    with open(path or spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def canonical(obj):
    """The one serialisation used for the golden, for a fresh run, and for the hash."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def stage_expansion(addons_root, source=OXP_SOURCE, dirname=OXP_DIRNAME):
    """Copy the expansion under test into a PRIVATE addons root, and prove the copy landed.

    An unchecked copy in a staging loop surfaces twenty lines later as a bogus 'the expansion is
    missing' verdict and sends the next reader hunting the wrong thing (bead oo-het). So the copy
    is verified by re-reading the world-scripts manifest out of the destination: that is the file
    whose absence would make the rig silently not exist, which is precisely the vacuous shape this
    scenario is built to detect.
    """
    if not os.path.isdir(source):
        raise ScenarioError("the expansion under test is not in the tree at %s" % source)
    os.makedirs(addons_root, exist_ok=True)
    target = os.path.join(addons_root, dirname)
    shutil.copytree(source, target, dirs_exist_ok=True)
    manifest = os.path.join(target, "Config", "world-scripts.plist")
    if not os.path.isfile(manifest):
        raise ScenarioError(
            "staged %s but %s is absent, so the game would load the expansion and register no "
            "world scripts at all - the rig would not exist and every evidence counter would be "
            "zero for a reason unrelated to the JS interface" % (target, manifest))
    scripts = [n for n in sorted(os.listdir(os.path.join(target, "Scripts")))
               if n.endswith(".js")]
    if not scripts:
        raise ScenarioError("staged %s but its Scripts/ directory holds no .js files" % target)
    return target, scripts


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d; a "
            "golden taken in a different system is not comparable with the stored one"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name", "?"), got))
    return got


def assert_rig_loaded(console):
    """The expansion's driver script must EXIST as a live world script before anything else.

    This is the single most important check in the file. `ooRunTests` is installed on the JS
    global by oolite-script-test-rig.js; if the expansion did not load, or loaded without its
    world scripts, the global is `undefined` and `perform("ooRunTests();")` would silently do
    nothing while the run went on to produce a perfectly clean log and a perfectly reproducible
    dump of a world in which no test ever ran.
    """
    kind = console.evaluate("typeof ooRunTests").strip()
    if kind != "function":
        raise ScenarioError(
            "typeof ooRunTests is %r, not 'function': the expansion's test rig "
            "(%s.js) is not loaded, so calling it would do nothing and every evidence counter "
            "would be zero. That is the vacuous-pass shape this scenario exists to detect - it is "
            "NOT a clean run." % (kind, RIG_SCRIPT_NAME))
    present = console.evaluate(
        "(function(){ return (worldScripts[%r] !== undefined) ? 'yes' : 'no'; })()"
        % RIG_SCRIPT_NAME).strip()
    if present != "yes":
        raise ScenarioError(
            "worldScripts[%r] is absent even though ooRunTests is a function; the rig's own "
            "registration seam is not what this scenario thinks it is" % RIG_SCRIPT_NAME)
    return console.evaluate(
        "(function(){ var n = 0; for (var k in worldScripts) n++; return String(n); })()").strip()


def install_collector(console):
    """Record the rig's OWN output lines inside the game. This harness never writes to them."""
    got = console.evaluate(COLLECT_JS).strip()
    if got != "INSTALLED":
        raise ScenarioError("could not install the console-message collector: %r" % got)
    return got


def run_js_tests(console, timeout=RIG_RUN_TIMEOUT_SECONDS):
    """Call the expansion's own entry point and WAIT FOR ITS OWN TERMINAL LINE.

    `ooRunTests()` is fire-and-forget as far as the console is concerned: several tests defer
    (Timer, SoundSource) via `$deferResult()`, so `completeTests()` - and with it the terminal
    `All N tests passed.` / `***** F of N tests FAILED` line - lands seconds after the call
    returns. Polling for OUR OWN marker would be circular; polling for THE RIG'S line is not,
    because nothing in this file can produce that string.
    """
    console.perform("ooRunTests();")
    deadline = time.time() + timeout
    while time.time() < deadline:
        done = console.evaluate(READ_DONE_JS).strip()
        if done:
            return done
        time.sleep(0.5)
    seen = console.evaluate(READ_COUNT_JS).strip()
    raise ScenarioError(
        "the test rig never emitted its completion line within %ss (it had emitted %s result "
        "line(s) by then). completeTests() in oolite-script-test-rig.js is the only producer of "
        "that string, so its absence means the rig did not finish - a dump taken now would record "
        "a world in which the JS interface was only partly exercised." % (timeout, seen))


def read_results(console):
    """Pull the recorded lines back and reduce them to counts, names and a digest.

    The IN-GAME split count is read as well, and the two must agree. That is the guard against
    cause (3) in the COLLECT_JS comment: the transport mangling the separator turns a 69-result
    payload into one unsplittable string, and without this cross-check it looks exactly like a
    rig that emitted a single result.
    """
    raw = console.evaluate(READ_LINES_JS)
    in_game = int(console.evaluate(READ_COUNT_JS).strip() or "0")
    lines = [l for l in raw.split(OO5K2_SEP) if l.strip()]
    if len(lines) != in_game:
        raise ScenarioError(
            "the game counted %d recorded result line(s) but only %d survived the console "
            "transport intact. The separator %r did not come back as it went out - a C0 control "
            "character is rendered by the XML property list as a literal escape, which silently "
            "collapses every result into one string. Raw head: %r"
            % (in_game, len(lines), OO5K2_SEP, raw[:120]))
    passes = [l[len("Pass: "):] for l in lines if l.startswith("Pass: ")]
    fails = [l[len("FAIL: "):].split(" -- ")[0] for l in lines if l.startswith("FAIL: ")]
    names = sorted(set(passes) | set(fails))
    digest = hashlib.sha256("\n".join(names).encode("utf-8")).hexdigest()
    return lines, passes, fails, names, digest


def parse_completion(line):
    """(total, failed) from the rig's terminal line, or a fatal error naming what was seen.

    Both spellings come from completeTests() in oolite-script-test-rig.js:
        All <N> tests passed.
        ***** <F> of <N> tests FAILED
    """
    m = re.match(r"^All (\d+) tests passed\.?$", line.strip())
    if m:
        return int(m.group(1)), 0
    m = re.match(r"^\*+ (\d+) of (\d+) tests FAILED$", line.strip())
    if m:
        return int(m.group(2)), int(m.group(1))
    raise ScenarioError(
        "the rig's completion line %r matches neither spelling completeTests() produces; this "
        "scenario's evidence parser and the expansion have drifted apart" % line)


def suppress_populators(console):
    """Switch the system populator off at the source; see launch_dock.py for the full argument."""
    keys = console.evaluate(
        "(function(){ var s = system.populatorSettings, out = [];"
        " for (var k in s) out.push(k);"
        " for (var i = 0; i < out.length; i++) system.setPopulator(out[i], null);"
        " return out.join(','); })()").strip()
    remaining = console.evaluate(
        "(function(){ var n = 0; for (var k in system.populatorSettings) n++;"
        " return String(n); })()").strip()
    if remaining not in ("0", ""):
        raise ScenarioError(
            "%s populator setting(s) survived suppression; the system will keep adding traffic "
            "during the run, consuming a per-run-variable number of RANROT draws" % remaining)
    return [k for k in keys.split(",") if k]


def clear_system(console):
    """Remove every non-player, non-station ship (launch_dock.clear_system, same reasons)."""
    console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) { ships[i].remove(); n++; } }"
        " return n; })()")
    remaining = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) n++; }"
        " return n; })()")
    if remaining:
        raise ScenarioError("%d non-station ship(s) remain after clearing; the dump would measure "
                            "the ambient population instead of the scenario" % remaining)
    return remaining


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` AI ticks of GAME time; gated on clock.absoluteSeconds, never on sleep."""
    budget = ticks * tick_seconds
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + TICK_WALL_BUDGET_SECONDS
    while time.time() < deadline:
        elapsed = float(console.evaluate("clock.absoluteSeconds")) - start
        if elapsed >= budget:
            return elapsed
        time.sleep(0.1)
    raise ScenarioError("game time did not advance %ss within %ss of wall time"
                        % (budget, TICK_WALL_BUDGET_SECONDS))


# --- the log half of the evidence --------------------------------------------------------------

def _channel(line):
    m = ERROR_CHANNEL_RE.match(line.strip())
    return m.group(1) if m else None


def is_error_line(line):
    chan = _channel(line)
    if chan and ERROR_CHANNEL_NAME_RE.search(chan):
        return True
    if chan:
        return False
    return bool(ERROR_TOKEN_RE.search(line) or ERROR_STARS_RE.search(line))


def assert_no_hijack(log_text):
    """A stranger's debug console must not have attached to this run. FATAL, never allow-listed.

    Bead oo-het captured the failure this defends against: a sibling worker's console connected
    to a game on the shared port 8563 and quit it 4.7 s in, while the run still exited rc=0 with
    a log containing zero errors - a fully vacuous pass that every naive signal calls green.

    THE REAL DEFENCE IS THE PRIVATE PORT, NOT THIS CHECK. The game DIALS OUT to the port named in
    the debugConfig.plist this scenario writes into its own OO_ADDITIONALADDONSDIRS root
    (golden_run._write_console_config, OODebugSupport.m:67-80), and the port is reserved under a
    lock for the life of the run (golden_run.reserve_port). A sibling on 8563 therefore cannot
    reach this game at all. This function ASSERTS that isolation held rather than assuming it,
    which is the difference between a defence and a hope.
    """
    connects = [l for l in log_text.splitlines() if HIJACK_RE.search(l)]
    strangers = [l for l in connects if OUR_CONSOLE_IDENTITY not in l]
    if strangers:
        raise ScenarioError(
            "a debug console that is NOT ours connected to this run - the sibling-hijack "
            "signature from bead oo-het, in which a stranger's console quit the game 4.7s in "
            "while the run still exited rc=0 with an error-free log. This is FATAL and is "
            "deliberately not covered by the %r allow-list:\n  %s"
            % (DEBUGTCP_SEND_ERROR_CHANNEL, "\n  ".join(strangers[:10])))
    return len(connects)


def classify_allowed(line):
    """Return the allow-list rule that excuses `line`, or None if nothing does.

    THE ENTIRE ALLOW-LIST IS THESE TWO RULES. Each is anchored to one exact thing - a message for
    the first, a CHANNEL for the second - and each carries its reason in the constant above it.

      1. `has no manifest.plist`   the legacy in-tree fixture ships none; count pinned EXACTLY at
                                   EXPECTED_NOMANIF_LINES and the line must NAME our staged copy.
      2. channel `debugTCP.send.error`  debug-console TRANSPORT failing to deliver a packet;
                                   observed on PASSING runs of unrelated expansions in bead
                                   oo-kcrw's tier1 corpus. Matched by CHANNEL because the packet
                                   body is volatile (command text, version string, colour keys)
                                   and a body rule would fragment into a family of patterns.
    """
    if NOMANIF_RE.search(line):
        return "nomanifest"
    if _channel(line) == DEBUGTCP_SEND_ERROR_CHANNEL:
        return "console-transport"
    return None


def assert_log(log_text, staged_oxp_dirname=OXP_DIRNAME):
    """Positive proof the expansion LOADED, then a TWO-RULE allow-list and a hard failure on
    anything else.

    Returns (nomanif_count, named_in_log, transport_count). Order matters and is the point: the
    loading proof comes FIRST, exactly as oo-kcrw's NOMANIF state does, so a run that never
    loaded the expansion can never reach an allow-list branch and be excused by it.
    """
    lines = log_text.splitlines()
    named = any(staged_oxp_dirname in l for l in lines)
    if not named:
        raise ScenarioError(
            "Latest.log never names %r: the expansion was not staged into a search path the game "
            "read, so nothing it contains could have run. An absence of errors in this log says "
            "nothing at all." % staged_oxp_dirname)
    if not any("[startup.complete]" in l for l in lines):
        raise ScenarioError(
            "Latest.log has no [startup.complete] line: the game did not finish loading, so an "
            "error scan over this log is vacuous (bead oo-het's exit-87 corpse contains the "
            "version banner and [process.args] and no errors whatsoever)")

    assert_no_hijack(log_text)

    errors = [l for l in lines if is_error_line(l)]
    nomanif = [l for l in errors if classify_allowed(l) == "nomanifest"]
    transport = [l for l in errors if classify_allowed(l) == "console-transport"]
    others = [l for l in errors if classify_allowed(l) is None]
    if others:
        raise ScenarioError(
            "Latest.log carries %d error line(s) that NO allow-list rule covers. The allow-list "
            "is exactly two rules - the '%s' complaint for this legacy fixture, and the "
            "'%s' console-transport channel - and nothing else:\n  %s"
            % (len(others), "has no manifest.plist", DEBUGTCP_SEND_ERROR_CHANNEL,
               "\n  ".join(others[:10])))
    unattributed = [l for l in nomanif if staged_oxp_dirname not in l]
    if unattributed:
        raise ScenarioError(
            "%d no-manifest error line(s) do not name our staged copy %r, so they belong to some "
            "other expansion and must not be absorbed by this scenario's allow-list:\n  %s"
            % (len(unattributed), staged_oxp_dirname, "\n  ".join(unattributed[:10])))
    if len(nomanif) != EXPECTED_NOMANIF_LINES:
        raise ScenarioError(
            "expected EXACTLY %d '%s' line(s) for %r (bead oo-kcrw measured that count across "
            "five unrelated legacy fixtures) but the log has %d. The allow-list is an exact "
            "count, not a floor, so a different number is a finding and not something to widen "
            "the predicate over:\n  %s"
            % (EXPECTED_NOMANIF_LINES, "has no manifest.plist", staged_oxp_dirname, len(nomanif),
               "\n  ".join(nomanif[:10])))
    return len(nomanif), named, len(transport)


def assert_ran(evidence):
    """The anti-vacuity gate on the RUN, applied before anything is written.

    Every clause names a field the dump carries, so the same property is re-checked by every
    future diff against the stored golden rather than only at capture time.
    """
    if not evidence["js_rig_loaded"]:
        raise ScenarioError("evidence.js_rig_loaded is false: the expansion's test rig was never "
                            "a live world script, so no JS under test could have run")
    if not evidence["js_completion_line"]:
        raise ScenarioError(
            "evidence.js_completion_line is empty: the rig never reached completeTests(), so the "
            "JS interface was not exercised to completion. A clean log is NOT evidence here - a "
            "run in which the scripts never executed produces exactly the same clean log.")
    if evidence["js_tests_total"] < 1:
        raise ScenarioError(
            "evidence.js_tests_total is %d: the rig reported a completion line for ZERO tests, "
            "which is what a loaded-but-empty expansion looks like"
            % evidence["js_tests_total"])
    if evidence["js_pass_lines"] + evidence["js_fail_lines"] < 1:
        raise ScenarioError(
            "evidence.js_pass_lines + js_fail_lines is 0: the rig emitted no per-test result "
            "lines at all, so nothing was actually asserted inside the game")
    if evidence["js_pass_lines"] + evidence["js_fail_lines"] != evidence["js_tests_total"]:
        raise ScenarioError(
            "evidence: the rig reported %d test(s) in its completion line but emitted %d pass + "
            "%d fail result line(s). The two counters come from different places in the rig "
            "(printResult vs completeTests) and disagreeing means results were lost."
            % (evidence["js_tests_total"], evidence["js_pass_lines"], evidence["js_fail_lines"]))
    empty_digest = hashlib.sha256(b"").hexdigest()
    if evidence["js_test_names_sha256"] == empty_digest:
        raise ScenarioError(
            "evidence.js_test_names_sha256 is the digest of the EMPTY name set (%s): no test "
            "names were reported, so the rig's $registerTest call sites never ran"
            % empty_digest)
    if evidence["oxp_nomanifest_errors"] != EXPECTED_NOMANIF_LINES:
        raise ScenarioError(
            "evidence.oxp_nomanifest_errors is %d, not the pinned %d"
            % (evidence["oxp_nomanifest_errors"], EXPECTED_NOMANIF_LINES))
    if not evidence["tick_budget_met"]:
        raise ScenarioError(
            "evidence.tick_budget_met is false: the game clock advanced less than the scenario's "
            "budget of %.3f game seconds (%d ticks), so the simulation did not run"
            % (evidence["game_seconds_budget"], evidence["ticks"]))


def _read_log(artifact_dir):
    path = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(path):
        raise ScenarioError(
            "no Latest.log in %s: OO_LOGSDIR is set to the artifact dir by console.py::_env, so "
            "its absence means the game never wrote one" % artifact_dir)
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def run(app_dir, out_path, spec, run_root, keep=False, snapshot=False,
        skip_js=False, unstage_oxp=False, seed_override=None, ticks_override=None):
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s" % (SCENARIO, stamp)))
    staged = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))
    addons_dir = golden_run._slashes(os.path.join(artifact_dir, "oxp-under-test"))

    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)
    if unstage_oxp:
        # MUTANT: the expansion is deliberately NOT staged. The run must then fail on
        # assert_rig_loaded rather than produce a clean, reproducible, empty-evidence dump.
        os.makedirs(addons_dir, exist_ok=True)
        staged_scripts = []
    else:
        _, staged_scripts = stage_expansion(addons_dir)

    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    roots = [config_dir, addons_dir] + ([previous] if previous else [])
    os.environ["OO_ADDITIONALADDONSDIRS"] = ",".join(roots)
    started = time.time()
    try:
        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1",
            load_save=spec["load_save"]))
        with console:
            assert_system(console, spec)
            world_scripts = assert_rig_loaded(console)
            install_collector(console)
            suppress_populators_keys = suppress_populators(console)
            clear_system(console)

            if skip_js:
                # MUTANT: never call the expansion's entry point. The rig is loaded and the log is
                # clean; only the rig's OWN output is missing. This is the exact shape a silently
                # dead JS run takes, and the run must refuse to bless a dump.
                completion = console.evaluate(READ_DONE_JS).strip()
            else:
                completion = run_js_tests(console)

            lines, passes, fails, names, digest = read_results(console)
            total, failed_reported = (parse_completion(completion) if completion else (0, 0))
            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))

            # Pause LAST and CHECK THE RETURN VALUE - GlobalPauseGame (OOJSGlobal.m:831-856)
            # returns NO without pausing anything on the chart/mission/report/keyboard/save
            # screens, and an unchecked pause turns a deterministic scenario into a stopwatch
            # (measured by bead oo-jor across four runs).
            if console.evaluate("pauseGame()").strip().lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s). The "
                    "simulation would keep integrating through the dump and no two runs could "
                    "agree." % console.evaluate("guiScreen").strip())
            clock_before = float(console.evaluate("clock.absoluteSeconds"))
            clear_system(console)
            clock_after = float(console.evaluate("clock.absoluteSeconds"))
            if clock_after != clock_before:
                raise ScenarioError(
                    "the game clock advanced %.4fs (%.4f -> %.4f) after pauseGame() returned "
                    "true; the world is NOT frozen, so the dump is a stopwatch reading"
                    % (clock_after - clock_before, clock_before, clock_after))

            # `magnitude` IS A FUNCTION, NOT A PROPERTY (bead oo-jor: a bare property comparison
            # is always false and the guard passed on runs whose dumps differed by 12 fields).
            moving = console.evaluate(
                "(function(){ var s = system.allShips, bad = [];"
                " for (var i = 0; i < s.length; i++) {"
                "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
                "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
                "              s[i].velocity.magnitude().toFixed(4)); }"
                " return bad.join(', '); })()").strip()
            if moving:
                raise ScenarioError(
                    "the game clock is stopped but %d entity/entities still report motion: %s. "
                    "The world is still integrating, so the dump would carry frame-dependent "
                    "values no two runs can reproduce." % (moving.count("=") + 1, moving))

            state = json.loads(dump_state(console))

            # READ THE LOG WHILE THE GAME IS STILL UP, BEFORE console.close().
            #
            # MEASURED, not defensive, and this is the DELIBERATE CHOICE between fixing the noise
            # at its source and allow-listing it. close() fires `quit();` and then tears the
            # socket down, and the game races that: the first run of this scenario failed its own
            # error scan on exactly one line,
            #
            #   [debugTCP.send.error]: The following packet could not be sent: {... message =
            #   "> quit();" ...}
            #
            # which is the console echoing OUR OWN teardown command into a socket that is closing
            # because we asked it to quit.
            #
            # BOTH REMEDIES ARE APPLIED, AND THEY ARE NOT REDUNDANT. Scanning the log for the
            # window the scenario is actually about - which ends when the dump is taken - removes
            # the TEARDOWN instance at the source, which is strictly better than excusing it.
            # Everything the expansion could possibly have logged (loading, world-script
            # registration, every line the rig emitted) has already happened by here. But the
            # same channel ALSO fires during CONNECTION, inside the window: bead oo-kcrw's tier1
            # runs of three unrelated, passing expansions each carry it at line 40 with a
            # "Request Connection" packet. So the channel rule in `classify_allowed` is still
            # needed and is not a substitute for this - it covers a different instance.
            #
            # The rejected third option was to widen the error predicate. That is exactly the
            # weakening oo-kcrw's NOMANIF state was careful not to do, and it would also swallow
            # a real mid-run console failure.
            log_text = _read_log(artifact_dir)

        nomanif, named, transport = (0, False, 0) if unstage_oxp else assert_log(log_text)

        evidence = {
            "js_rig_loaded": True,
            "js_world_script_count": int(world_scripts),
            "js_staged_scripts": len(staged_scripts),
            "js_completion_line": completion,
            "js_tests_total": total,
            "js_pass_lines": len(passes),
            "js_fail_lines": len(fails),
            "js_failed_reported": failed_reported,
            "js_result_lines": len(lines),
            # The digest of the sorted test-name SET. The names exist only inside the
            # expansion's $registerTest(...) call sites; this file contains none of them, so a
            # run in which the scripts never executed cannot produce this value.
            "js_test_names_sha256": digest,
            "oxp_nomanifest_errors": nomanif,
            "oxp_named_in_log": bool(named),
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "system_id": int(spec["system_id"]),
            "populators_suppressed": len(suppress_populators_keys),
        }
        assert_ran(evidence)
        state["evidence"] = evidence
        text = canonical(state)
        if out_path:
            parent = os.path.dirname(os.path.abspath(out_path))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text)
        return {"ok": True, "out": out_path, "port": port, "bytes": len(text),
                "wall_seconds": round(time.time() - started, 1),
                "game_seconds_elapsed": round(elapsed, 3),
                # REPORTED, NOT STORED IN THE DUMP. The console-transport line count depends on
                # whether the connection handshake happened to lose a packet on this run, which
                # is a property of the socket and not of the simulation. Pinning it in the golden
                # would make the golden a stopwatch reading, for the same reason scenario 001
                # stores `tick_budget_met` as a boolean rather than the measured float. The
                # NOMANIF count, by contrast, IS stored: it is a deterministic property of the
                # fixture and of how many search roots name it.
                "console_transport_errors": transport,
                "test_names": names, "evidence": evidence}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
            shutil.rmtree(addons_dir, ignore_errors=True)
        golden_run.release_all()


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/js_interface.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--run-root", default=None, help="scratch root for staged apps/artifacts")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--no-snapshot", action="store_true",
                        help="accepted for symmetry with scenario 001; this scenario never "
                             "captures a frame (the dump alone is the artefact)")
    parser.add_argument("--seed", type=int, default=None, help="override the spec's seed")
    parser.add_argument("--ticks", type=int, default=None, help="override the spec's tick count")
    parser.add_argument("--skip-js", action="store_true",
                        help="MUTANT: load the expansion but never call ooRunTests(). The run "
                             "must FAIL its own evidence assertions; used to prove that a "
                             "silently dead JS run cannot be blessed.")
    parser.add_argument("--no-oxp", action="store_true",
                        help="MUTANT: do not stage the expansion at all. The run must FAIL on "
                             "assert_rig_loaded.")
    args = parser.parse_args(argv)

    spec = load_spec()
    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 1
    ensure_launchable(app_dir)

    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_5k2_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep,
                     snapshot=not args.no_snapshot, skip_js=args.skip_js,
                     unstage_oxp=args.no_oxp, seed_override=args.seed,
                     ticks_override=args.ticks)
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
