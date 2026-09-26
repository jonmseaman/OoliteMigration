# ADR-0046 — Members of an exempt harness inherit its desktop-lock exemption

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-hub0, 2026-09-23;
ADR-0013, CLAUDE.md rule 10). Made under Jon's 2026-09-23 authorisation to resolve `human` beads
by best judgement. Jon may override.
**Date:** 2026-09-23
**Refines** the desktop-lock rule in CLAUDE.md ("Repo conventions") and its guard,
`tools/check-desktop-lock.sh` (bug oo-ccy9).

## Context

`tools/check-desktop-lock.sh` sorts every file that spawns the game into LOCKED (takes
`tools/gui-lock`) or EXEMPT (says in its own text why it must not). Since it learned to detect a
launcher by its spawn rather than by one spelling, it has failed on every branch with 26
unclassified launchers (oo-hub0): 24 golden-tier files under `tests/golden/`,
`tools/oo-qwk5-probe.py`, and the corpus runner `tools/oxp_load_check.py`. No gate ran it, so
nothing was red — and a guard that is always red protects nothing.

21 of the golden files are scenario drivers (`combat.py`, `launch_dock.py`, ...). Each is its own
main program but launches its game *through* `tests/golden/golden_run.py` — `reserve_port`,
`stage_app`, the private `debugConfig.plist` — the harness CLAUDE.md exempts because it runs N
games at once. Listing each driver by hand would be 21 lines that go stale with every new
scenario; locking them would serialise the harness they are members of.

## Decision

1. **A third classification: MEMBER of an exempt harness.** `EXEMPT_HARNESSES` names exempt
   launchers that are harnesses (today only `tests/golden/golden_run.py`). A spawner is a member —
   and inherits the exemption — only if it lives in the harness's own directory tree AND its code
   imports the harness module (an `ast` import; a comment, string, docstring or
   `importlib.import_module("...")` does not count). Membership is derived by
   `tools/launcher_scan.py --members-of`, never listed.
2. **A member must not take the lock** (check 3), for the same reason the harness must not.
3. **`tests/golden/dump/run_dump.py` is EXEMPT by name**, with its reason in its own docstring:
   it is the golden stages' dump runner (tier-b/tier-c goldens, blessing), part of the same golden
   harness, and does not import `golden_run.py` (it is deliberately single-game).
4. **One-off probes take the lock.** `tools/oo-qwk5-probe.py`,
   `tests/golden/motion/motion_probe.py` and `value_probe.py` are run by hand, one game, outside
   any fan-out, so they are LOCKED launchers: `main()` holds `desktop_lock()` and refuses to launch
   without it.
5. **Anti-vacuity is extended, not relaxed.** `tools/desktop-lock-rogue-proof` gains rogues 36-40:
   a golden-tree launcher naming `golden_run` only in prose, a `tools/` launcher importing it, a
   string-only import, a member that locks (all must fail) and a genuine new scenario driver (must
   pass). Every earlier rogue is unchanged.

`tools/oxp_load_check.py` is out of scope here: a separate session is making the corpus runner
take `gui-lock`. Until it lands the guard reports that one file and nothing else.

## Consequences

- A new golden scenario that follows the house pattern (import `golden_run`, launch through it) is
  classified automatically; one that does not is a named failure.
- The golden harness still does not take the lock, so a golden run can still take the foreground
  from a concurrent GUI test — the trade-off CLAUDE.md already accepted for `golden_run.py`, now
  stated for its members too. If the golden tier ever needs the foreground, the harness and its
  members stop being exempt together.
- The rogue-proof runs the full guard ~45 times (about 1-7 min on the fleet box), so its full run
  is a nightly line (ADR-0021); a bead's acceptance runs the guard itself.

## History

- 2026-09-23: proposed with the change (bead oo-hub0).
