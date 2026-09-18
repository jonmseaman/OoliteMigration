#!/usr/bin/env python3
"""oo-jor: prove each stored acceptance line can go RED.

Reads the STORED bytes (bd show --json), baselines EVERY line green first (bead oo-4vdc: an
already-red line registers as a kill for every mutant), then for each substantive line applies a
mutant that breaks exactly the property that line protects, runs THAT line, and restores.

Line 7 launches the game twice and is excluded from the mutant sweep by default (--with-line7 to
include it): its mutants are run separately and reported by hand, because each attempt costs ~70 s.
Its BASELINE is still taken, so no line is mutated without being proven green first.

Every mutation happens in the worktree and is restored from an in-memory copy of the original
bytes via a try/finally; goldens/ is never written - golden mutants are made in a throwaway temp
copy, exactly as the acceptance lines themselves do.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def stored_lines():
    out = subprocess.run(["bd", "show", "oo-jor", "--json"], capture_output=True, text=True,
                         cwd=ROOT).stdout
    start = out.index("[")
    return json.loads(out[start:])[0]["acceptance_criteria"].split("\n")


def run_line(line, timeout=900):
    t0 = time.time()
    p = subprocess.run(["bash", "-o", "pipefail", "-c", line], capture_output=True, text=True,
                       cwd=ROOT, timeout=timeout)
    return p.returncode, (p.stdout + p.stderr), round(time.time() - t0, 1)


class Mutate:
    """Replace `old` with `new` in a worktree file, restoring the original bytes afterwards."""

    def __init__(self, relpath, old, new):
        self.path = os.path.join(ROOT, relpath)
        self.old, self.new = old, new

    def __enter__(self):
        with open(self.path, "r", encoding="utf-8") as h:
            self.backup = h.read()
        if self.old not in self.backup:
            raise SystemExit("MUTANT TARGET NOT FOUND in %s: %r" % (self.path, self.old[:70]))
        with open(self.path, "w", encoding="utf-8", newline="\n") as h:
            h.write(self.backup.replace(self.old, self.new, 1))
        return self

    def __exit__(self, *exc):
        with open(self.path, "w", encoding="utf-8", newline="\n") as h:
            h.write(self.backup)
        return False


class MutateMany:
    """Apply several replacements to one worktree file, restoring the original bytes afterwards.

    Needed because a property defended in more than one place is not removed by breaking one of
    them - see the dock_events mutant below.
    """

    def __init__(self, relpath, pairs):
        self.path = os.path.join(ROOT, relpath)
        self.pairs = pairs

    def __enter__(self):
        with open(self.path, "r", encoding="utf-8") as h:
            self.backup = h.read()
        src = self.backup
        for old, new in self.pairs:
            if old not in src:
                raise SystemExit("MUTANT TARGET NOT FOUND in %s: %r" % (self.path, old[:70]))
            src = src.replace(old, new, 1)
        with open(self.path, "w", encoding="utf-8", newline="\n") as h:
            h.write(src)
        return self

    def __exit__(self, *exc):
        with open(self.path, "w", encoding="utf-8", newline="\n") as h:
            h.write(self.backup)
        return False


# (line index 0-based, human label, mutation)
MUTANTS = [
    (0, "delete the scenario spec (line 1 asserts the artefacts exist)",
     ("rename", "tests/golden/scenarios/001-launch-dock/spec.json")),
    (1, "change the pinned quantisation in spec.json from 3 to 1 (coarser rounding)",
     Mutate("tests/golden/scenarios/001-launch-dock/spec.json",
            '"quant_decimals": 3', '"quant_decimals": 1')),
    (1, "cut the tick count to 0 (the flight never runs)",
     Mutate("tests/golden/scenarios/001-launch-dock/spec.json", '"ticks": 24', '"ticks": 0')),
    (2, "stop passing the seed to the game (OO_RANDOM_SEED no longer set)",
     Mutate("tests/golden/launch_dock.py", "seed=seed,", "seed=None,")),
    (2, "use the shared console port instead of reserving a private one",
     Mutate("tests/golden/launch_dock.py", "port = golden_run.reserve_port(run_root)",
            "port = 8563  # mutant")),
    (3, "break the pause check (pauseGame()'s refusal goes unnoticed)",
     Mutate("tests/golden/launch_dock.py",
            'if console.evaluate("pauseGame()").strip().lower() != "true":',
            'if False:  # mutant')),
    # MUTATE DEEP ENOUGH TO ACTUALLY REMOVE THE PROPERTY. The first version of this mutant only
    # dropped dock_events from REQUIRED_POSITIVE and line 4 stayed GREEN - which looked like a
    # hole in the gate and was not: the checker defends dock_events TWICE (the generic
    # REQUIRED_POSITIVE loop AND a dedicated clause that names the engine event), so removing one
    # defence leaves the property intact and the mutant is EQUIVALENT. Verified by hand: the
    # singly-mutated checker still rejects dock_events=0 with rc=1.
    # This is the fleet's "when a mutant survives, check you removed the behaviour before
    # concluding the gate is blind" - and its converse from oo-vwd: mutate at the narrowest point
    # that removes ONLY the behaviour under test. Both clauses go, and line 4 goes red.
    (3, "make the evidence checker accept a zero dock_events counter (BOTH defences removed)",
     MutateMany("tests/golden/check_launch_dock_evidence.py", [
         ('REQUIRED_POSITIVE = ("launch_events", "dock_events", "ticks")',
          'REQUIRED_POSITIVE = ("ticks",)  # mutant'),
         ('    if ev.get("dock_events", 0) < 1:', '    if False:  # mutant'),
     ])),
    (4, "zero the dock evidence in a THROWAWAY copy of the golden",
     ("golden", "dock_events")),
    (5, "collapse the golden's entity list in a THROWAWAY copy",
     ("golden", "entities")),
]


def golden_mutant_line(line, what):
    """Run `line` against a temp directory holding a mutated COPY of the golden.

    goldens/ is never touched. The line references the golden by its repo path, so the copy is
    swapped in by pointing the line at a scratch tree - done by mutating the path in the line
    itself, which is honest: the line under test is unchanged in what it ASSERTS.
    """
    src = os.path.join(ROOT, "goldens", "windows-x64", "001-launch-dock")
    tmp = tempfile.mkdtemp(prefix="oo_jor_gm_")
    dst = os.path.join(tmp, "g")
    shutil.copytree(src, dst)
    with open(os.path.join(dst, "state.json"), encoding="utf-8") as h:
        data = json.load(h)
    if what == "dock_events":
        data["evidence"]["dock_events"] = 0
    else:
        data["entities"] = []
    with open(os.path.join(dst, "state.json"), "w", encoding="utf-8", newline="\n") as h:
        json.dump(data, h, sort_keys=True, separators=(",", ":"))
    patched = line.replace("goldens/windows-x64/001-launch-dock/state.json",
                           dst.replace("\\", "/") + "/state.json")
    try:
        return run_line(patched)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    include7 = "--with-line7" in sys.argv
    lines = stored_lines()
    print("STORED LINES: %d\n" % len(lines))

    print("=== BASELINE: every stored line must be GREEN before any mutant ===")
    baseline_ok = True
    for i, line in enumerate(lines, 1):
        if i == 7 and not include7:
            rc, out, wall = run_line(line)
        else:
            rc, out, wall = run_line(line)
        print("line %d: rc=%d wall=%.1fs %s" % (i, rc, wall, "GREEN" if rc == 0 else "*** RED ***"))
        if rc != 0:
            baseline_ok = False
            print(out[-1500:])
    if not baseline_ok:
        print("\nABORT: a line is already red at baseline; mutants would manufacture false kills.")
        return 1

    print("\n=== MUTANTS ===")
    kills = 0
    for idx, label, mut in MUTANTS:
        if idx == 6 and not include7:
            continue
        line = lines[idx]
        print("\n--- line %d vs mutant: %s" % (idx + 1, label))
        if isinstance(mut, tuple) and mut[0] == "golden":
            rc, out, wall = golden_mutant_line(line, mut[1])
        elif isinstance(mut, tuple) and mut[0] == "rename":
            p = os.path.join(ROOT, mut[1])
            os.rename(p, p + ".mutant")
            try:
                rc, out, wall = run_line(line)
            finally:
                os.rename(p + ".mutant", p)
        else:
            with mut:
                rc, out, wall = run_line(line)
        verdict = "RED (killed)" if rc != 0 else "*** GREEN - THE LINE DOES NOT DISCRIMINATE ***"
        kills += 1 if rc != 0 else 0
        print("    rc=%d wall=%.1fs -> %s" % (rc, wall, verdict))
        for l in [x for x in out.strip().splitlines() if x.strip()][-6:]:
            print("    | %s" % l[:180])

    print("\n=== RESTORED: re-run every line to prove the tree is clean again ===")
    for i, line in enumerate(lines, 1):
        rc, out, wall = run_line(line)
        print("line %d: rc=%d wall=%.1fs %s" % (i, rc, wall, "GREEN" if rc == 0 else "*** RED ***"))
        if rc:
            print(out[-800:])
    print("\nKILLS: %d/%d mutants went red" % (kills, len([m for m in MUTANTS
                                                          if m[0] != 6 or include7])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
