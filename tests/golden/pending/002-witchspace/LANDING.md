# Landing 002-witchspace into `goldens/`

These artifacts are STAGED, not blessed. `goldens/` is a guarded path: `tools/guardrails.sh`
refuses CREATE as well as MODIFY under it, and blessing is Jon's decision alone. This file is the
procedure for making that decision executable, and it has been REHEARSED END TO END in a scratch
worktree — the moves below were performed for real and both gates were re-run AFTER them, because a
sibling bead's landing procedure moved `spec.json` somewhere its own gate could not find it.

## What is staged

| file | what it is |
|---|---|
| `spec.json` | every determinism knob, pinned |
| `state.json` | the canonical dump (2018 bytes), identical on 10/10 runs |
| `frame.grid` | the 64x64 luminance grid; liveness-checked, never byte-compared |
| `provenance.json` | the witness that lives OUTSIDE `state.json` |

## The moves

```sh
git mv tests/golden/pending/002-witchspace goldens/windows-x64/002-witchspace
```

That is the whole move: the directory goes across intact, with all four files together. Both gates
resolve the artifact directory through a two-element candidate list — `goldens/windows-x64/<id>`
FIRST, `tests/golden/pending/<id>` second — so they need no edit afterwards, and they keep working
while the artifacts are still staged. The gates themselves stay in `tests/golden/`; they are code,
not artifacts, and nothing moves them.

## Replay after the move — REQUIRED, and rehearsed

```sh
python3 tests/golden/gate_002_spec.py        # knobs pinned, read where they act, agree w/ provenance
python3 tests/golden/gate_002_evidence.py    # the dump proves a jump happened
```

Rehearsed in a detached scratch worktree with the `git mv` applied: both exit 0 from the new
location, with the spec gate reporting `goldens/windows-x64/002-witchspace` as the directory it
checked against. If either gate exits 2 after the move, the artifacts were split up — that is the
failure this rehearsal exists to catch, and the fix is to move the directory as a unit, not to edit
the gate.

## Re-blessing (when an intended engine change moves the dump)

Do NOT edit `state.json` by hand: `provenance.json` pins its sha256 AND its byte size, so a hand
edit is caught by `gate_002_evidence.py` (mutant 8 below). Re-bless by regenerating both together:

```sh
python3 tests/golden/witchspace_jump.py --stability 10   # must report one distinct dump digest
# then copy run01.json -> state.json, run01.grid -> frame.grid, and regenerate provenance.json
# from the sweep so the knobs, the jump record and the artifact digests are all re-derived at once.
```

A re-bless that updates `state.json` without `provenance.json` fails immediately; that is the
intended behaviour, not an obstacle.

## What was measured, so the next reader does not re-derive it

- **10/10 runs, one distinct dump digest** (`040344bb…`), 0 refused, 0 errored.
- **10 distinct FRAME digests over those same 10 runs.** llvmpipe is not bit-reproducible. This is
  why `frame_digest_asserted` is `false` with a recorded reason, and why the frame is pinned for
  LIVENESS (spread 0.4549, floor 0.2275) instead.
- **The commodity market is projected out by value.** Before the projection, 8 consecutive runs
  agreed on every field EXCEPT `market.*`, which differed in 26–30 fields each time: arriving in a
  system regenerates the market with `randf()` draws (OOCommodities.m:423,442,544,567) whose
  position in the RANROT stream depends on elapsed frames, not on the seed. The market is not
  deleted — its good count and sorted good names are still compared, so an arrival with NO market
  still fails.
- **Pausing IN FLIGHT wedges the debug console.** `-setGamePaused:` calls `setEcoQoS:YES`
  (GameController.m:155–197), which drops the process to IDLE priority with power throttling; on a
  loaded fleet box it then stops answering the debug socket. The scenario docks at the destination
  first (as scenario 001 does) and restores the process priority after pausing.

## Non-vacuity: 9 mutants, all RED, baseline green

Every mutation was applied to THROWAWAY copies in a detached scratch worktree, never in place.

| # | mutation | gate | caught by |
|---|---|---|---|
| 1 | live run with the countdown skipped | live scenario | destination system is still the origin |
| 2 | `system_id_after := system_id_before` | evidence | "THE SHIP NEVER LEFT" |
| 3 | `witchspace_enter_events := 0` | evidence | engine never dispatched the event: a teleport |
| 4 | `fuel_consumed_tenths := 0` | evidence | a jump that costs no fuel is not a jump |
| 5 | `spec.seed` drifts from provenance | spec | blessed-vs-spec knob disagreement |
| 6 | `quant_decimals := 1` | spec | coarsened quantisation makes everything pass |
| 7 | `destination_system_id := origin` | spec | the central predicate becomes unsatisfiable |
| 8 | one byte appended to `state.json` | evidence | sha256 and byte size both disagree |
| 9 | `frame.grid` zeroed (never drawn) | evidence | luminance spread 0.0 < floor 0.2275 |

## The live line can lose the console to a sibling — retry, do not re-bless

MEASURED during acceptance replay: the live line (6) failed once with
`ConnectionResetError: [WinError 10054]`, rc=3 after 28 s, with **1 orphaned oolite.exe** on the
box; the identical line on the identical tree then passed in 50 s with 0 orphans, jump confirmed
and the dump byte-identical to the golden. An rc=3 from this harness is an UNEXPECTED EXCEPTION —
console contention, a sibling worker's game holding port 8563, or an orphan — and is an INSTRUMENT
FAILURE, not a verdict on the scenario. Before reporting the live line as a defect:

```sh
ps -W | grep -i oolite | awk '{print $4}' | while read p; do /c/Windows/System32/taskkill.exe /PID $p /F; done
```

then re-run unchanged. A long wall time with a timeout or reset message is the tell.

**The mutant line (7) refuses rc=3 explicitly and matches the destination refusal text**, because
it originally accepted ANY nonzero rc — and a crashed run (rc=3) therefore satisfied it. A mutant
arm that passes when the game crashes proves nothing: it must go red BECAUSE the ship stayed in
Lave, so it now asserts `SCENARIO FAILED: ... pins the destination system to ID 129 but the game
reports 7` appears in the output.
