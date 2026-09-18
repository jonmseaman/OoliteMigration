#!/usr/bin/env python3
"""tools/tier_c_selftest.py -- the OFFLINE half of Tier C's own gate (bead oo-j4u).

Tier C takes 17-25 minutes to run (see the arithmetic at the top of tools/tier-c.sh), so it
cannot run inside its own stored acceptance block, and accept.sh replays every line of every bead.
This file is what makes that split honest: it exercises the parts of Tier C that are pure logic --
its COMPOSITION, its FLOORS, its ANTI-VACUITY GUARDS and its ASan SUPPRESSION SCOPE -- against the
real tools/tier-c.sh on disk, in about a second and with no build, no launch and no network.

It deliberately does NOT re-implement those rules. It reads them out of tier-c.sh and asserts the
properties that would make Tier C blind if they were quietly removed:

  * every stage the tier claims to have still exists, in order, with a runner;
  * every stage's runner really fails on its own emptiness;
  * no floor has been lowered to a value a dead run could satisfy;
  * no anti-vacuity guard has been deleted;
  * the ASan suppressions cannot match the module under test.

THE oo-9w5 LESSON IS THE POINT OF THIS FILE: a count floor is not a content check. oo-9w5 shipped a
gate whose count-floor check passed while the spec lost its hardest clause. So the checks below are
almost all CONTENT checks -- they name the specific string, guard or predicate whose absence would
turn a stage into a no-op -- and each one carries the reason it exists.

Exit codes follow the repo convention (bead oo-jor): 0 = verified, 1 = a real failure,
2 = REFUSED (could not be evaluated). A refusal is never a pass.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TIER_C = HERE / "tier-c.sh"
SUPPRESSIONS = HERE / "asan-suppressions.txt"
SNAPSHOT = HERE.parent / "oxp-contract" / "js-api-source.json"

# The composition Tier C is REQUIRED to have. This is the check that makes "someone quietly deleted
# the asan stage because it was slow" a red line rather than a faster gate. Order matters: tier-b
# first so a cheap failure is found before a 13-minute corpus run.
REQUIRED_STAGES = ["tier-b", "jsapi", "asan", "goldens", "corpus", "gui", "fleetdata"]

# Floors that must not be weakened. Each value is the MINIMUM the committed tier may declare; a
# smaller number means a dead run could satisfy it. Keyed by the shell variable's default.
FLOOR_MINIMA = {
    "GOLDEN_FLOOR": 2,
    "CORPUS_FLOOR": 36,
    "FLEET_TEST_FLOOR": 1,
    "GUI_TEST_FLOOR": 1,
}

# CONTENT checks: substrings whose presence in tier-c.sh is the anti-vacuity guard itself. Each
# entry is (label, needle, why-its-absence-would-be-a-blind-gate).
REQUIRED_GUARDS = [
    ("tier-b GREEN line",
     "tier-b: GREEN",
     "tier-b exiting 0 without running (an early --list, a swallowed invocation) would otherwise "
     "count as a pass; only its own GREEN line proves it completed"),
    ("tier-b stage-count guard",
     "announced only",
     "a tier-b that exits 0 having announced no stages must be caught; rc=0 alone is satisfiable "
     "by a dead run"),
    ("jsapi byte-comparison",
     "byte-identical to a fresh scrape",
     "without asserting the OK line, a --check that exited 0 without comparing anything would pass "
     "and the committed snapshot could silently drift from the engine (bead oo-4z6's STALE tier2)"),
    ("jsapi refusal is not a pass",
     "a refusal is not a pass",
     "rc=2 means the scrape could not be evaluated; treating it as success is exactly the vacuous "
     "green this tier exists to prevent"),
    ("asan probe fires",
     "heap-use-after-free",
     "the probe's rc=0 proves only that a compile and a run happened; only the report proves the "
     "sanitizer is live rather than present-and-inert"),
    ("asan instrumentation check",
     "does NOT import libclang_rt.asan_dynamic",
     "the worst failure mode of the stage is a build that quietly dropped -fsanitize=address and "
     "left a perfectly good UNSANITIZED binary that passes every other assertion"),
    ("asan symbolisation precondition",
     "could not resolve",
     "a stage that cannot attribute a frame to a module cannot distinguish an engine defect from a "
     "prebuilt DLL's allocator mismatch; it is a vacuous gate wearing a sanitiser costume"),
    ("asan startup precondition",
     "startup\\.complete",
     "a launch that died before loading writes a short log with ZERO ERROR lines, so neither the "
     "exit code nor the absence of errors discriminates (bead oo-het)"),
    ("asan attribution verdict",
     "attributable to oolite.exe",
     "the pass condition must be zero OUR-code reports, not zero reports; third-party findings are "
     "expected and must not mask ours"),
    ("asan private console port",
     "console-port",
     "on the shared default port 8563 a sibling's console can accept our game and quit it seconds "
     "in while the run still exits 0 with no ERROR lines (bead oo-het)"),
    ("asan DLL-not-found discrimination",
     "3221225781",
     "0xC0000135 after ~116s is a PATH problem, not a sanitizer finding; conflating the two "
     "produces a false report in one direction and a missed defect in the other"),
    ("goldens refusal is not a pass",
     "golden_diff rc=",
     "golden_diff returns 2 when it REFUSES to compare (empty, unreadable, self-comparison); that "
     "must not be read as equality"),
    ("goldens discovery not a hardcoded list",
     r'for dir in "\$gdir"/\*/',
     "scenarios must be discovered so one added tomorrow is gated tomorrow, and the floor catches "
     "one that disappears"),
    ("corpus checked-count floor",
     "fewer than the committed floor",
     "a corpus run that staged nothing reports '0 group(s) checked' and exits 0 (bead oo-het saw "
     "35 of 36 expansions silently never copied)"),
    ("corpus pass==checked",
     r"group\(s\) reported PASS",
     "a run where every group was checked and none passed must not be green"),
    ("fleetdata count floor",
     "collected",
     "a pytest node id that no longer resolves can deselect everything and still exit 0; the "
     "passed-count is the evidence"),
    ("gui skip-is-failure",
     r"a skip is a failure",
     "the GUI tier's whole anti-vacuity property is OO_GUI_REQUIRE=1 turning a platform skip into "
     "a failure; without asserting zero skipped, 'G1 passed' and 'G1 never ran' look identical"),
    ("gui desktop lock",
     r"gui-lock",
     "ADR-0017: the GUI tier takes the interactive desktop exclusively, and the ASan launch must "
     "not race it; CLAUDE.md's rule is enforced by tools/check-desktop-lock.sh"),
    ("empty selection is fatal",
     "passes vacuously",
     "--only with a typo must not yield 'GREEN, 0 stages', the purest vacuous pass"),
    ("plan/execution agreement",
     "the plan and the execution disagree",
     "if the tier runs a different set from the one it printed, no other check here would notice"),
]


def refuse(msg: str) -> None:
    print(f"tier-c-selftest: REFUSED: {msg}", file=sys.stderr)
    sys.exit(2)


def main() -> int:
    if not TIER_C.is_file():
        refuse(f"{TIER_C} does not exist; there is nothing to check")
    text = TIER_C.read_text(encoding="utf-8", errors="replace")
    if len(text) < 4000:
        refuse(f"{TIER_C} is only {len(text)} bytes; that is not the tier, and checking a stub "
               f"would report a meaningless green")

    failures: list[str] = []

    # --- 1. COMPOSITION. The declared stage table, the dispatch table and the required list must
    # all agree. Three independent places, because the realistic regression is someone removing a
    # stage from one of them and leaving the others intact.
    m = re.search(r'^STAGES="(.*?)"\s*$', text, re.M | re.S)
    if not m:
        refuse("cannot find the STAGES table in tier-c.sh; the composition cannot be checked")
    declared = [ln.split("\\t")[0].strip()
                for ln in m.group(1).split("\n") if ln.strip()]
    if declared != REQUIRED_STAGES:
        failures.append(
            f"COMPOSITION: the STAGES table declares {declared} but Tier C is defined as "
            f"{REQUIRED_STAGES}. A stage that is slow is not a stage that is optional; deleting one "
            f"silently narrows the merge gate.")

    # Every declared stage must have a runner in the dispatch case, and vice versa. A stage present
    # in the table but absent from the dispatch would die with the internal error; a runner with no
    # table entry can never be selected and is dead code pretending to be a defence.
    for st in REQUIRED_STAGES:
        fn = "stage_" + st.replace("-", "_")
        if f"{fn}()" not in text:
            failures.append(f"COMPOSITION: stage '{st}' is declared but has no {fn}() runner")
        if not re.search(rf"^\s*{re.escape(st)}\)\s*{fn}\s*;;", text, re.M):
            failures.append(
                f"COMPOSITION: stage '{st}' has no dispatch arm, so selecting it would abort "
                f"rather than run it")

    # Each stage's declared cost must be positive. A stage advertised as free is a stage someone
    # will assume is a no-op.
    for ln in m.group(1).split("\n"):
        if not ln.strip():
            continue
        parts = ln.split("\\t")
        if len(parts) < 3:
            failures.append(f"COMPOSITION: malformed STAGES row {ln!r}")
            continue
        try:
            cost = int(parts[1])
        except ValueError:
            failures.append(f"COMPOSITION: stage {parts[0]} has a non-numeric cost {parts[1]!r}")
            continue
        if cost <= 0:
            failures.append(f"COMPOSITION: stage {parts[0]} declares a cost of {cost}s")

    # --- 2. FLOORS. Not merely present: not WEAKENED. This is the check that catches the tempting
    # fix of dropping CORPUS_FLOOR to 3 to make a red gate green.
    for var, minimum in FLOOR_MINIMA.items():
        fm = re.search(rf'^{var}="\$\{{[A-Z_]+:-(\d+)\}}"', text, re.M)
        if not fm:
            failures.append(
                f"FLOOR: {var} is gone or no longer has a literal default; a floor that cannot be "
                f"read cannot be enforced")
            continue
        got = int(fm.group(1))
        if got < minimum:
            failures.append(
                f"FLOOR: {var} is {got}, below the committed minimum of {minimum}. Lowering a floor "
                f"to accommodate a shrinking corpus is how a gate stops gating.")

    # --- 3. CONTENT. The guards themselves.
    for label, needle, why in REQUIRED_GUARDS:
        if not re.search(needle, text):
            failures.append(f"GUARD MISSING [{label}]: {why}")

    # --- 4. ASAN SUPPRESSION SCOPE. A suppressions file that can match the module under test turns
    # the whole stage into an expensive no-op.
    if not SUPPRESSIONS.is_file():
        failures.append(
            "ASAN: tools/asan-suppressions.txt is missing; the stage would either fail on known "
            "third-party interceptor mismatches or be run wide open")
    else:
        stext = SUPPRESSIONS.read_text(encoding="utf-8", errors="replace")
        entries, reasons = [], 0
        for ln in stext.splitlines():
            s = ln.strip()
            if not s:
                continue
            if s.startswith("#"):
                reasons += 1
                continue
            entries.append(s)
        if not entries:
            failures.append(
                "ASAN: the suppressions file has no entries at all; either it is doing nothing "
                "(and the third-party reports will fail the stage) or it was emptied by accident")
        for e in entries:
            if "oolite" in e.lower():
                failures.append(
                    f"ASAN: suppression {e!r} mentions oolite -- a suppression that can match the "
                    f"module under test makes every engine defect invisible")
            if re.search(r"^\s*\*|:\s*\*\s*$|^interceptor_via_lib:\s*\*", e):
                failures.append(
                    f"ASAN: suppression {e!r} is a wildcard; suppressions must name a specific "
                    f"third-party module and carry a written reason")
        if reasons < len(entries):
            failures.append(
                f"ASAN: {len(entries)} suppression entr(ies) but only {reasons} comment line(s); "
                f"every entry must carry a written reason, as beads oo-5k2 and oo-kcrw required")

    # --- 5. THE SNAPSHOT IS REAL. Its content, not merely its existence: a snapshot reduced to an
    # empty object would still byte-compare equal to a fresh scrape of nothing.
    if not SNAPSHOT.is_file():
        failures.append(f"JSAPI: {SNAPSHOT} is missing; the jsapi stage has nothing to compare")
    else:
        import json
        try:
            doc = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            failures.append(f"JSAPI: the committed snapshot is not valid JSON: {exc}")
        else:
            s = doc.get("summary", {})
            if s.get("class_count", 0) < 28:
                failures.append(
                    f"JSAPI: the committed snapshot declares {s.get('class_count')} classes; the "
                    f"engine has at least 28, so this snapshot is truncated")
            if s.get("readonly_properties", 0) < 1 or s.get("readwrite_properties", 0) < 1:
                failures.append(
                    "JSAPI: the snapshot has no READONLY or no READWRITE properties; the access "
                    "distinction is the whole reason bead oo-jou1 exists (Ship.speed is READONLY) "
                    "and a snapshot that lost it cannot answer the question it is consulted for")
            # The specific, load-bearing fact another bead already relies on.
            ship = doc.get("classes", {}).get("Ship", {})
            props = ship.get("properties", {}) if isinstance(ship, dict) else {}
            if "speed" not in props:
                failures.append(
                    "JSAPI: Ship.speed is absent from the committed snapshot; bead oo-jou1 exists "
                    "precisely because it is READONLY, so its absence means the scrape broke")
            elif props["speed"].get("access") != "readonly":
                failures.append(
                    f"JSAPI: Ship.speed is recorded as {props['speed'].get('access')!r}, but the "
                    f"engine declares OOJS_PROP_READONLY_CB. Bead oo-jou1 depends on this.")

    # --- 6. THE TIER'S OWN RUNTIME OUTPUT MUST AGREE WITH ITS TABLE.
    #
    # This is not redundant with check 1, and a real bug proved it: the STAGES table declared all
    # six stages while `--list` and `--dry-run` emitted only five, because `while read` silently
    # discards a final line that has no trailing newline. Parsing the VARIABLE found nothing wrong;
    # only running the tier did. A gate whose printed plan omits a stage will also RUN without it.
    import subprocess
    for flag, pattern in (("--list", None), ("--dry-run", r"plan \((\d+) stage")):
        try:
            proc = subprocess.run(["bash", str(TIER_C), flag],
                                  capture_output=True, text=True, timeout=120)
        except Exception as exc:  # noqa: BLE001
            failures.append(f"RUNTIME: could not run tier-c.sh {flag}: {exc}")
            continue
        if proc.returncode != 0:
            failures.append(f"RUNTIME: tier-c.sh {flag} exited {proc.returncode}")
            continue
        out = proc.stdout
        missing = [s for s in REQUIRED_STAGES if s not in out]
        if missing:
            failures.append(
                f"RUNTIME: tier-c.sh {flag} does not mention stage(s) {missing}. The tier's printed "
                f"plan disagrees with its STAGES table, so it will run a narrower gate than it "
                f"claims -- this is exactly the 'while read drops the last line' bug.")
        if pattern:
            pm = re.search(pattern, out)
            if not pm:
                failures.append(f"RUNTIME: tier-c.sh {flag} printed no stage count")
            elif int(pm.group(1)) != len(REQUIRED_STAGES):
                failures.append(
                    f"RUNTIME: tier-c.sh {flag} plans {pm.group(1)} stage(s), not "
                    f"{len(REQUIRED_STAGES)}")

    # An --only naming a nonexistent stage must be FATAL, never an empty green run.
    try:
        proc = subprocess.run(["bash", str(TIER_C), "--only", "nosuchstage"],
                              capture_output=True, text=True, timeout=120)
        if proc.returncode == 0:
            failures.append(
                "RUNTIME: --only with an unknown stage exited 0; a typo in a selection must not "
                "produce a vacuous green")
    except Exception as exc:  # noqa: BLE001
        failures.append(f"RUNTIME: could not run the unknown-stage probe: {exc}")

    if failures:
        print(f"tier-c-selftest: FAIL -- {len(failures)} problem(s)\n", file=sys.stderr)
        for f in failures:
            print(f"  * {f}", file=sys.stderr)
        return 1

    print(f"tier-c-selftest: OK -- {len(REQUIRED_STAGES)} stage(s) "
          f"({', '.join(REQUIRED_STAGES)}), {len(FLOOR_MINIMA)} floor(s) at or above their minima, "
          f"{len(REQUIRED_GUARDS)} anti-vacuity guard(s) present, suppressions scoped to "
          f"third-party modules only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
