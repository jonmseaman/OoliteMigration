# Golden scenario `007-js-interface`

Stages the in-tree **JavaScript Interface Tests** test-oxp into a private addons root, runs **its
own test rig** inside a live game, and emits a canonical state dump whose `evidence` block carries
**the rig's own PASS/FAIL output**. Implemented by bead `oo-5k2` following scenario `001-launch-dock`
(bead `oo-jor`) on the storage policy from `oo-ss8` ([GOLDEN_STORAGE.md](../../GOLDEN_STORAGE.md)).

> **This directory is a STAGING AREA, not the golden's home.** See
> [Landing procedure](#landing-procedure-for-jon) at the bottom. `tools/guardrails.sh` refuses a
> brand-new file under `goldens/` *or* `tests/golden/scenarios/` without a re-bless approval, and
> an agent may not write that approval.

```bash
export PATH=/ucrt64/bin:$PATH      # else the loader kills oolite.exe with 3221225781, no log

# one run (~24-29 s warm)
python3 tests/golden/js_interface.py --no-snapshot --out /tmp/r1.json

# the offline falsifiability suite (no game, ~4 s, 41 tests)
python3 -m pytest tests/golden/test_js_interface.py -q

# does a dump prove the JavaScript really ran?
python3 tests/golden/check_js_interface_evidence.py tests/golden/staging/007-js-interface/state.json

# a fresh dump against the stored golden
python3 tests/golden/golden_diff.py tests/golden/staging/007-js-interface/state.json /tmp/r1.json

# multi-run stability, reporting MATCH/DIFFERS/REFUSED/BROKEN separately
bash tools/oo-5k2-stability.sh 6
```

## What is pinned

| knob | value | where |
|---|---|---|
| seed | `20260918` → `OO_RANDOM_SEED` | `spec.json`, exported by `console.py::_env` |
| system | ID `7` (Lave), **asserted** | `spec.json`, checked by `assert_system()` |
| ticks | `24` × `0.125 s` = 3.0 s of **game** time | `spec.json`, `run_ticks()` |
| quantisation | 3 decimals | policy; `golden_diff.py` refuses anything else |
| save | `Resources/Scenarios/oolite-standard.oolite-save` | `spec.json` |
| expansion | `upstream/oolite-tests/test-oxps/JSInterfaceTests/JavaScript Interface Tests.oxp` | `spec.json` |
| no-manifest errors | **exactly 2** | `spec.json`, `EXPECTED_NOMANIF_LINES` |

The tick budget is measured on `clock.absoluteSeconds` **inside the game**, never on the harness
clock, so the dump does not depend on how loaded this box is.

## The anti-vacuity problem, which is the whole point of this scenario

**A JS interface test that silently fails to RUN produces exactly the same clean log as one that
ran and passed every assertion.** No errors, a healthy `[startup.complete]`, a perfectly
reproducible world. Two runs of a dead scenario agree byte for byte. **Absence of errors proves
nothing here** — it is the default state of a game that did nothing.

So every evidence field is output **the test-oxp itself produced**:

| field | what it means | why a dead run cannot fake it |
|---|---|---|
| `js_completion_line` | the rig's terminal line, verbatim (`All 69 tests passed.`) | produced **only** by `completeTests()` in `oolite-script-test-rig.js`; the harness contains no such string, and a dead run leaves it **empty** |
| `js_tests_total` | the `N` from that line | same source |
| `js_pass_lines` / `js_fail_lines` | per-test results from `printResult()` | counted **independently** of the completion line; the two **must agree** |
| `js_test_names_sha256` | SHA-256 of the sorted test-name set | the names exist **only** inside the expansion's `$registerTest(...)` call sites — this file contains none of them. A dead run hashes the empty set, a different and explicitly rejected digest |
| `js_rig_loaded` | `typeof ooRunTests === "function"` before it is called | a run whose expansion failed to load never reaches the call |
| `oxp_nomanifest_errors` | exactly 2 | positive proof the expansion was parsed |

`js_pass_lines + js_fail_lines == js_tests_total` is a **real cross-check, not a restatement**: the
two numbers come from different functions in the rig. It caught a silent 68-of-69 result loss three
times during development, from three distinct causes (see below).

A blessed run records **`All 69 tests passed.`** — the expansion's own verdict, captured rather
than inferred from silence.

## The allow-list — two rules, each auditable

This is the **first gate in the tree to scan `Latest.log` for error lines at all** (scenario 001
does not), so it is the first to meet the ambient noise and it owns getting this right.
`classify_allowed()` is the whole implementation.

| # | rule | matched on | reason | evidence it is benign |
|---|---|---|---|---|
| 1 | `has no manifest.plist` | **message**, **exact count 2**, must **name our staged copy** | `JavaScript Interface Tests.oxp` is one of five legacy in-tree fixtures that predate the manifest format (bead `oo-kcrw`, state `NOMANIF`) | five *unrelated* fixtures each emit an identical count of exactly 2 — a fixture property, not five independent defects |
| 2 | channel `debugTCP.send.error` | **CHANNEL** | the debug-console **transport** failed to deliver a packet; not the game failing at anything | appears in bead `oo-kcrw`'s tier1 runs of three unrelated **PASSING** expansions (`DrNil.YAH`, `Griff_shipset_decals`, `Griff_alloys_and_wreckage`, each at line 40, `Request Connection`), all reaching `startup.complete` |

**Why rule 1 is an allow-list and not a staged manifest.** Staging a synthetic `manifest.plist`
would mean this golden measures a fixture **that does not exist in the tree**. The bead is
"exercise the JS interface test-oxp", not "exercise a repaired copy of it". And `oo-kcrw`'s
`NOMANIF` state is honest precisely because it is gated on positive proof of loading **and** on the
errors being exclusively that message at that exact count; reproducing that gate keeps the two
instruments saying the same thing about the same fixture.

**Why rule 2 is matched by channel.** The packet body carries the command text, an Oolite version
string and colour keys — all volatile — so a body-shaped rule would fragment into a family of
near-identical patterns.

### What the allow-list deliberately does **not** cover

`[debugTCP.connected]: Connected to debug console "..."` is the **sibling-hijack signature** from
bead `oo-het`: a stranger's console attached to a game on the shared port 8563 and quit it 4.7 s
in, while the run still exited `rc=0` with a log containing zero errors — a fully vacuous pass. A
rule matching `debugTCP` generally would have swallowed it. It stays **fatal**, asserted positively
by `assert_no_hijack()`.

The **real** defence there is the private port: the game *dials out* to the port named in the
`debugConfig.plist` this scenario writes into its own `OO_ADDITIONALADDONSDIRS` root
(`OODebugSupport.m:67-80`), reserved under a lock for the life of the run. `assert_no_hijack()`
proves that isolation held rather than assuming it.

### The teardown instance is fixed at the source, not excused

`console.close()` fires `quit();` and tears the socket down; the game races that and logs
`[debugTCP.send.error] ... message = "> quit();"`. Rather than allow-list our own teardown, the log
is **read before `close()`** — everything the expansion could have logged has already happened by
then. Rule 2 still exists because the **same channel also fires at connection time**, inside the
window. Widening the error predicate was considered and rejected: it is exactly the weakening
`oo-kcrw` was careful not to do, and it would swallow a real mid-run console failure.

## Three bugs this scenario hit, all with the identical symptom

All three produced `All 69 tests passed.` alongside **one** collected result line. Each is pinned
by a test, because the symptom is indistinguishable from a rig that emitted a single result.

1. **A function round-tripped through a native property is not callable.** `debugConsole` is a
   native `Console` object (`OOJSConsole.m:195`). Stashing the original `consoleMessage` on it and
   calling it back does not work; the original is held in a **closure** now.
2. **`debugConsole.script` round-trips by VALUE.** `…script.lines.push(m)` mutates a copy that is
   discarded, while a scalar assignment persists. The accumulator is a **string**, built by
   read-modify-write.
3. **A C0 separator does not survive the XML property list.** `U+001F` is preserved perfectly
   *inside* the game (a probe read back 70 correctly separated entries) but `plistlib` renders it
   as the six literal characters `\U001F`, so Python split on a character that was no longer there
   and saw the entire payload as one line. `OO5K2_SEP` is printable ASCII, and the split count is
   cross-checked **in the game** as well as in Python.

**A fourth, caught by the allow-list itself:** staging the expansion into `<artifact>/addons`
collides case-insensitively with the game's own `../AddOns` search root, so one staged copy was
enumerated **twice** and the log carried **4** no-manifest lines. A floor (`>= 2`) would have passed
that silently; the exact count did not. The directory is `oxp-under-test`.

## Stability

6 runs, this box, warm: **5 MATCH, 0 DIFFERS, 0 REFUSED, 0 BROKEN** (reference run excluded), all
`md5=95aff9d7537ec9df2a6b863086fd6bdf`, 1884 bytes, wall times 29/29/25/24/24/23 s.

**JS execution introduced no observable nondeterminism.** That was a real risk worth measuring —
iteration order, timer scheduling and garbage collection are all live during `ooRunTests()` — and
the answer on this platform is that none of it reaches the dump. Note *why* that is unsurprising
rather than treating it as proof of more than it is: the rig's tests are pure JS-interface
assertions that do not spawn entities, and the dump's measured content is the entity set, the
market, the player ledger and the evidence block. The claim is "this scenario is deterministic on
this box", not "the JS engine is deterministic".

`tools/oo-5k2-stability.sh` reports **REFUSED separately from DIFFERS**, the same `rc=2` vs `rc=1`
distinction `golden_diff.py` is built on: "I cannot tell you" must never be mistaken for "they
match".

## Proof the gate can fail

Every mutant below was run for real; each went RED naming the failure, and the unmutated scenario
is GREEN. Data mutants and checker mutants both, per bead `oo-jor`: *for every property the gate
defends, consider two mutants — one corrupting the DATA and one weakening the CHECKER — since a
validator nobody validates is a hole one refactor wide.*

| mutant | kind | verdict |
|---|---|---|
| `--skip-js` (**the JS never runs at all**) | data, live | RED: `js_completion_line is empty: the rig never reached completeTests()` |
| `--no-oxp` (expansion not staged) | data, live | RED: `typeof ooRunTests is 'undefined', not 'function'` |
| `--ticks 1` | data, live | RED `rc=1`: `evidence.ticks: 24 != 1`, `game_seconds_budget: 3.0 != 0.125` |
| `--seed 1` | data, live | RED `rc=1`: `evidence.seed: 20260918 != 1` |
| one quantised unit (`0.001`) on `entities[0].position[0]` | data, offline | RED `rc=1`: `entities[Coriolis Station].position[0]: -49474.32 != -49474.319` |
| a **third, different** error line | data, offline | RED: `1 error line(s) that NO allow-list rule covers` |
| no-manifest count `2 → 3` | data, offline | RED: `expected EXACTLY 2 … but the log has 3 … an exact count, not a floor` |
| `[debugTCP.connected]` from a stranger | data, offline | RED: `the sibling-hijack signature from bead oo-het … FATAL and deliberately not covered` |
| remove **each** of the 4 dead-JS defences, one at a time | **checker** | each mutated copy must **still** reject a dead run — pins the redundancy |
| exact count `!=` widened to a floor `<` | **checker** | the mutated copy must **accept** a count of 3, proving that clause is what rejects it |

Checker mutants run against a **copy** in a temp dir; the real checker is never modified, and
nothing outside `goldens/` is touched by any of this.

### An honest limitation of the `--ticks` and `--seed` mutants

Both were caught **only by the `evidence` block**, not by any world-state field. That is expected
and worth stating plainly rather than letting the table imply more than it shows: the player is
docked at Lave, the populators are suppressed and the system is cleared, so **the measured world
is static** — no entity moves between tick 1 and tick 24, and no RNG draw reaches the dump. The
scenario is genuinely pinned to `seed=20260918, ticks=24` and a change to either **is** detected,
but the detection rests on those knobs being recorded in the dump, not on them perturbing physics.

This is a deliberate trade. Bead `oo-jor` found the system populator keeps the world moving and
refused to bless a frame-dependent state on 3 of 8 runs; a scenario whose purpose is to exercise
**JavaScript** rather than **physics** is better served by a settled world, and the price is that
the world-state half of the dump does not independently witness the tick count.

## Build flags

`provenance.json` records `build_flags.verified: false` — the shared build was compiled without
`-ffp-contract=off` on all 242 translation units. That is a **known defect owned by bead
`oo-5ggu`**, not a fault of this scenario, and it is recorded honestly rather than papered over.
Scenario 001's golden carries the identical note.

## Landing procedure (for Jon)

`tools/guardrails.sh` refuses any new file under `goldens/` or `tests/golden/scenarios/` without a
matching line in `tools/rebless-approvals.txt`, and a change that edits **both** a protected path
and the approvals file is refused whatever it says. That is correct and this bead did not touch it.
**Verified in this worktree:** a single new file under `goldens/windows-x64/007-probe/` produced

```
guardrails: goldens: goldens/windows-x64/007-probe/state.json is under a protected golden path
and is changed and has no re-bless approval in tools/rebless-approvals.txt
guardrails: FAIL      (rc=1)
```

and the same for `tests/golden/scenarios/007-probe/`. With the artefacts in
`tests/golden/staging/` instead, `guardrails.sh` returns **rc=0**.

So the golden is staged here, complete and tested. Landing is **two commits, in this order**:

```bash
# COMMIT 1 (Jon, alone) — the approvals. Nothing else in this commit.
cat >> tools/rebless-approvals.txt <<'EOF'
goldens/windows-x64/007-js-interface/state.json        Jon <date>, bead oo-5k2: new scenario 007.
goldens/windows-x64/007-js-interface/provenance.json   Jon <date>, bead oo-5k2: new scenario 007.
tests/golden/scenarios/007-js-interface/spec.json      Jon <date>, bead oo-5k2: new scenario 007.
tests/golden/scenarios/007-js-interface/README.md      Jon <date>, bead oo-5k2: new scenario 007.
EOF
git commit -am "approve golden scenario 007-js-interface (bead oo-5k2)"

# COMMIT 2 — the move. A pure `git mv`; no file content changes.
mkdir -p goldens/windows-x64/007-js-interface tests/golden/scenarios/007-js-interface
git mv tests/golden/staging/007-js-interface/state.json      goldens/windows-x64/007-js-interface/
git mv tests/golden/staging/007-js-interface/provenance.json goldens/windows-x64/007-js-interface/
git mv tests/golden/staging/007-js-interface/spec.json       tests/golden/scenarios/007-js-interface/
git mv tests/golden/staging/007-js-interface/README.md       tests/golden/scenarios/007-js-interface/
bash tools/guardrails.sh            # must be rc=0 with the approvals on record
python3 -m pytest tests/golden/test_js_interface.py -q
git commit -am "bead oo-5k2: land golden scenario 007-js-interface"
```

**No code change is needed by the move.** `js_interface.py`, `test_js_interface.py` and the stored
acceptance block all search the blessed location **first** and fall back to staging
(`GOLDEN_CANDIDATES` / `SPEC_CANDIDATES`), so both trees work before and after. The one acceptance
line that names `tests/golden/staging/…/state.json` explicitly should be updated to
`goldens/windows-x64/007-js-interface/state.json` in the same commit.
