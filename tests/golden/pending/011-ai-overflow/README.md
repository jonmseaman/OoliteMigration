# Golden scenario 011 — `AI overflow test` test-OXP (bead oo-dto)

## What this scenario proves

The engine's **AI stack overflow** condition is **reached and handled**, in a game that really had
the expansion's content live. Not "the game started", not "the OXP is on the search path".

| evidence field | what it proves | how a dead/quiet run fails it |
|---|---|---|
| `oxp_ship_keys` | `Config/shipdata.plist` was MERGED into the running registry | nothing staged → empty |
| `oxp_ship_ai_type` | a PROPERTY was read off that merged entry (`ai_type`) | a bare key reads nothing |
| `ai_stack_overflow_events` | the engine logged `[ai.error.stackOverflow]` (AI.m:205-227) | a quiet world logs none |
| `ai_stack_overflow_signatures` | `<AI file>:<state>` — attributes the overflow to THIS expansion | ambient traffic signs differently |
| `ai_stack_overflow_max_stack_depth` | 32 preserved AI frames unwound = AI.m:40 `kStackLimiter` | a structural constant, not a timer |
| `ai_stack_overflow_squashed` / `overflow_handled` | the raise was CAUGHT (`Squashing exception OoliteException … in AI handler …`) | an escaped overflow leaves the counts unequal |
| `tick_budget_met` | the clock advanced 24 further ticks **after** the overflow was observed | a crashed run cannot |
| `oxp_standards_errors` | exactly 2 missing-manifest lines, and nothing else | 0 = never parsed, 4 = loaded twice |

The overflow ship is **removed before the dump** on purpose. The evidence lives in the evidence
block; keeping a thrusting ship in the entity list would make the golden a stopwatch reading
(`ShipEntity -velocity` is `[super velocity] + [self thrustVector]`, ShipEntity.m:12830-12833,
which no JS write can clear — bead oo-jor measured a scenario refusing to dump on exactly that).

## The briefed premise was wrong, and here is the measurement

This bead was briefed on the belief that `AI overflow test` **fails to load** on a missing
`manifest.plist` and is kept out of the loaded set entirely. Measured first, before anything was
designed. It **loads**:

```
[searchPaths.dumpAll]: Resource paths:
    ~/Resources
    <artifact>/console-config
    <artifact>/oxp-stage
    ~/AddOns
    <artifact>/oxp-stage/AI overflow test.oxp        <-- named in the loaded set
    ~/AddOns/Basic-debug.oxp

[oxp-standards.error]: OXP <artifact>/oxp-stage/AI overflow test.oxp has no manifest.plist
[oxp-standards.error]: OXP <artifact>/oxp-stage/AI overflow test.oxp has no manifest.plist
[startup.complete]: ========== Loading complete in 5.91 seconds. ==========
```

Exactly **two** missing-manifest lines and a normal load — bead oo-kcrw's **NOMANIF** class,
indistinguishable from RetroMissions. The engine source says why: `ResourceManager.m:642-664`
treats the missing manifest as fatal only for an `.oxz` (`:636-641`, `return`) or when
`OOEnforceStandards()` is on (`:647-651`). For a plain `.oxp` in relaxed mode it emits the
standards error, **synthesises** a basic manifest at `:654` and adds the path to `searchPaths` at
`:663`.

**Consequence:** no companion manifest had to be staged and **none was**. The missing manifest is
tolerated *exactly* — count pinned at 2, signature pinned verbatim — never muted.

## What is deliberately NOT asserted

That **this specific ship's** AI stack is the deep one is not observable in this tier.
`Ship.AIState` is permanently `GLOBAL` here, `AI -stackDepth` (AI.m:382) has no JS binding, and
`upstream/oolite/tests/component/steps/world_steps.py` exposes only role counts and liveness — no
per-ship identity, no generic property read. Those are the seam beads **oo-kbqw / oo-bdl0**.

Rather than invent an observable, attribution comes from the **AI file name carried in the
engine's own log signature** (`ahruman-stack-overflow-testAI.plist:GLOBAL`), a name only this
expansion can put there.

## Determinism

Reserved port + `debugConfig.plist` in a private `OO_ADDITIONALADDONSDIRS` (the game DIALS OUT to
the port named there, OODebugSupport.m:67-80 — on the shared 8563 a sibling's console captures and
quits the run while it still exits rc=0, bead oo-het); populator switched off at the source before
anything is measured; world asserted at rest under a **checked** `pauseGame()`; tick budget
measured on the game clock.

Staging directory is `oxp-stage`, **never** `addons`: `<artifact>/addons` **is**
`<artifact>/../AddOns` case-insensitively on Windows, which loads the expansion at two roots and
produces four missing-manifest lines (bead oo-3ya).

## Stability

10 consecutive runs, **10 DUMPED / 0 REFUSED / 0 DIFFERED**, all byte-identical at 2166 bytes,
md5 `e2e87932e32339ae750b3994d2ecd12f` — the same digest as the stored `state.json`. Wall 17-31 s
each. All 10 reached and handled the overflow, because `assert_ran()` refuses to dump otherwise.

## Mutation results — and the hole the first round found

Two mutants per defended property: one corrupting the **data**, one weakening the **checker**.
Every mutant applied to a throwaway copy or reverted immediately; all 7 stored lines re-verified
green afterwards.

**Round 1: 13 data mutants killed, 7 checker mutants SURVIVED the entire stored block.**

That survival was the most useful result of the bead. The cause was structural, not a missing
assertion: the offline suite tested the **shape of the source** (does this call appear, in this
order) rather than **driving the gates with bad input**. So weakening a gate's logic changed
nothing any test looked at. Diagnosed by reading the code — a blind gate, not equivalent mutants
and not deliberate redundancy.

The fix was to give `gate_spec` an injectable `prov_path` and `gate_isolation` an injectable
`src_path`, then add 10 tests that feed each gate a deliberately broken input and require a
refusal. `gate_isolation` also gained a **reachability** check, because the `if False:` mutant
left `await_overflow` present in the source and both the presence check and the ordering check
passed it.

**Round 2: 20 of 20 killed.**

| # | mutant | killed by | message |
|---|---|---|---|
| D1 | `state.json` one market price +0.001 (one quantised unit) | line 7 | `DIFFERENCES (1) … market.<good>.price` |
| D2 | `ai_stack_overflow_events` 1 → 0 | line 5 | names the field and both values |
| D3 | `max_stack_depth` 32 → 31 | line 5 | `unwinding 31 preserved AI frames` |
| D4 | `ai_stack_overflow_squashed` 1 → 0 | line 5 | overflow escaped its handler |
| D5 | overflow signed by `route1traderAI.plist` | line 5 | wrong AI file — not this expansion |
| D6 | `oxp_standards_errors` 2 → 4 | line 5 | the two-roots signature |
| D7 | `spec.seed` 20260918 → 31337 | line 2 | **the bead oo-3ya survivor**, killed by the provenance comparison |
| D8 | `spec.ticks` 24 → 0 | line 2 | ticks must be a positive int |
| D9 | `allowed_oxp_standards_errors` 2 → 4 | line 2 | widening the NOMANIF pin is a suppression |
| D10 | `expected_max_stack_depth` 32 → 16 | line 2 | `kStackLimiter=32` is structural |
| D11 | delete `scenario_knobs` from provenance | line 2 | the blessed seed is unrecorded |
| C1 | checker accepts zero overflow events | line 4 | — |
| C2 | checker accepts any unwind depth | line 4 | — |
| C3 | checker accepts any oxp-standards count | line 4 | — |
| C4 | drop `overflow_handled` from `REQUIRED_TRUE` | line 4 | — |
| C5 | `await_overflow` never reached (`if False:`) | lines **3 and 4** | reachability check |
| C6 | `assert_ran` stops checking the overflow count | line 4 | — |
| C7 | `gate_spec` stops comparing against provenance | line 4 | — |
| C8 | `gate_isolation` stops requiring port/plist/seed | line 4 | — |
| E1 | `--empty-stage` (OXP removed from staging) | line 7 rc=1 | `oxp_ship_keys is empty … The OXP being on the search path is not the same as its content being live.` |
| E2 | `--no-spawn` | line 7 rc=1 | `overflow_ships_spawned is 0 … the overflow condition is never reached` |
| E3 | `--ticks 0` | line 7 | dumps, then differs: `evidence.ticks: 24 != 0`, `game_seconds_budget: 3.0 != 0.0` |
| E4 | `--seed 31337` on a live run | line 7 | fresh-run-vs-golden rc=1 |

**Answering the knob question directly** — *if someone changed this, which line goes red?*

| knob | changed how | goes red |
|---|---|---|
| `seed` | in spec only | line 2 (provenance drift) |
| `seed` | on a live run | line 7 (dump differs) |
| `ticks` | in spec | line 2 |
| `ticks` | on a live run | line 7 |
| `quant_decimals` | any value but 3 | line 2, and `golden_diff` policy check on line 6 |
| `expected_max_stack_depth` | any value but 32 | line 2 |
| `allowed_oxp_standards_errors` | widened | line 2 |
| `overflow_ship_role` | wrong role | line 7 (nothing spawns) |

No knob is decoration.


## Files

| file | role |
|---|---|
| `tests/golden/ai_overflow.py` | the scenario: stage, spawn, await the overflow, run ticks, dump |
| `tests/golden/check_ai_overflow_evidence.py` | offline evidence checker (rc 0 / 1 / 2) |
| `tests/golden/test_ai_overflow.py` | 40 offline falsifiability tests; two mutants per property |
| `spec.json` | the determinism knobs and the measured pins |
| `state.json` | the golden dump |
| `provenance.json` | commit, compiler, build flags, blessed knobs, stability |
| `LANDING.md` | the tested procedure for moving these into the guarded paths |
