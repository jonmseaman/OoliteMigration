# Golden scenario `012-retro-missions`

The in-tree test-OXP `RetroMissions` is staged into a private addons root, the game runs a **fixed
tick count** in a **fixed system** under a **fixed seed**, and the run emits a canonical state dump
whose `evidence` block proves the expansion's content actually **went live**. Implemented by bead
`oo-3ya` following scenario `001-launch-dock` (bead `oo-jor`) as the exemplar, on the storage
policy from `oo-ss8` ([GOLDEN_STORAGE.md](../../GOLDEN_STORAGE.md)).

> **This directory is `tests/golden/pending/`, not `tests/golden/scenarios/`, and the golden is
> here rather than under `goldens/`.** Both of those are guarded paths: `tools/guardrails.sh`
> refuses *any* change under them — including a brand-new file — without a matching line in
> `tools/rebless-approvals.txt`, which only Jon may add, in a separate commit. See
> [LANDING.md](LANDING.md) for the verdict that was measured and the exact procedure for landing
> these three files once an approval exists.

```bash
export PATH=/ucrt64/bin:$PATH      # else the loader kills oolite.exe with 3221225781, no log

# one run (~19 s warm)
python3 tests/golden/retro_missions.py --out /tmp/r1.json

# the offline falsifiability suite (no game, ~3 s)
python3 -m pytest tests/golden/test_retro_missions.py -q

# does a dump prove RetroMissions went live?
python3 tests/golden/check_retro_missions_evidence.py \
    tests/golden/pending/012-retro-missions/state.json

# a dump against the stored golden
python3 tests/golden/golden_diff.py \
    tests/golden/pending/012-retro-missions/state.json /tmp/r1.json
```

## What is pinned

| knob | value | where |
|---|---|---|
| seed | `20260918` → `OO_RANDOM_SEED` | `spec.json`, exported by `console.py::_env` |
| system | ID `7` (Lave), **asserted** | `spec.json`, checked by `assert_system()` |
| ticks | `24` × `0.125 s` = 3.0 s of **game** time | `spec.json`, `run_ticks()` |
| expansion | `upstream/oolite-tests/test-oxps/RetroMissions/RetroMissions.oxp` | `spec.json` |
| quantisation | 3 decimals | policy; `golden_diff.py` refuses anything else |
| save | `Resources/Scenarios/oolite-standard.oolite-save` | `spec.json` |

The tick budget is measured on `clock.absoluteSeconds` **inside the game**, never on the harness
clock, so the dump does not depend on how loaded this box is.

## Anti-vacuity: what is asserted, and why a dead run cannot satisfy it

A scenario that crashed in display init and dumped a near-empty world reproduces byte-for-byte
perfectly and proves nothing. **Being named in `[searchPaths.dumpAll]` is not evidence** — it
proves only that `ResourceManager` accepted a directory. So the evidence goes one step further in,
and it is stored **in the dump**, which means every future comparison re-checks it:

| field | what it means | why a dead run cannot fake it |
|---|---|---|
| `oxp_world_scripts` | the 6 world-script names present in the running game that a **stock** game lacks | requires `Config/world-scripts.plist` to have been merged into the engine's world-script list |
| `oxp_script_versions` | `worldScripts["ahruman-reaper"].version == "1"` | a **property read off a live JS object**: the script file had to be found, compiled and instantiated |
| `oxp_key_only_scripts` | the 5 legacy plist scripts that enumerate as keys only | measured engine behaviour, recorded rather than hidden (see below) |
| `oxp_standards_errors` / `..._signatures` | exactly 2 lines, all being the known missing-manifest message | zero means the expansion was never parsed; three or a different message is a finding |
| `tick_budget_met` / `ticks` | the game clock really advanced the budget | read from `clock.absoluteSeconds` inside the game |

**The stock baseline is measured, not assumed.** `spec.json`'s `stock_world_scripts` came from a
control run of this same script with `--no-oxp --probe-world-scripts`, which stages nothing: 16
world scripts. The staged run has 22. The difference is attributable to RetroMissions and to
nothing else.

### One of the six scripts is live; five are keys only — and that split *is* the evidence

Probed in a running game:

```
ahruman-reaper    typeof "object"     .name "ahruman-reaper"   .version "1"
cloaking-device   typeof "undefined"
constrictor_hunt  typeof "undefined"
nova              typeof "undefined"
thargoid_plans    typeof "undefined"
trumbles          typeof "undefined"
```

The five undefined ones come from `Scripts/oolite-legacy-scripts.plist` (the engine logs it as
deprecated) and enumerate as keys of `worldScripts` without being addressable as JS objects.
`ahruman-reaper` is the expansion's own `.js` world script and is a fully live object. Both halves
are stored and both are required, because they prove different things: the **names** prove the
world-scripts list was merged, the **version read** proves a script file was compiled and
instantiated. A checker that accepted key enumeration alone would pass on a merge with nothing
behind it.

### `golden_diff.py`'s refusals that apply here

All of `golden_diff`'s guards are reused unchanged, and three of them bite on this scenario:

* **self-comparison** — `assert_independent` (path plus `st_dev`/`st_ino`, so a hardlink is not a
  second run). Verified: rc=2.
* **collapsed / empty dump** — `assert_non_vacuous`, ≥ 40 leaf fields and ≥ 2 entities. This dump
  has **105 leaf fields**.
* **off-policy quantisation** — `check_quantisation` reads the `provenance.json` beside the dump
  and refuses anything but 3 decimals, and separately refuses a dump whose floats are all whole
  numbers. This dump has 10 floats, 9 of them fractional.

## The missing `manifest.plist` is tolerated **exactly**, and no manifest is staged

RetroMissions is one of five in-tree legacy fixtures that predate the manifest format. Bead
`oo-kcrw` classified this as **NOMANIF**: it is a property of the fixture, not a defect, and the
classification is honest only because it is gated on positive proof of loading **and** on the
errors being **exclusively** that message at that **exact** count.

**This scenario chose to tolerate, not to stage a manifest.** Writing one would falsify the fixture
and would be editing expansion content (CLAUDE.md rule 6). The tolerance is a pin:

* the count must be **exactly 2** — not "at most", not "at least". Zero fails (the expansion was
  never parsed); three fails (a new problem);
* every signature must be in the allow-list, compared **verbatim** after the volatile staged path
  is replaced by the OXP basename (the staging root carries a timestamp, a port and a pid);
* `tests/golden/test_retro_missions.py::test_no_manifest_is_staged` asserts on the **AST** that no
  string constant outside a docstring names `manifest.plist`, that `stage_oxp` only copies the
  fixture tree, and that the fixture still has no manifest — so if upstream ever adds one, this pin
  goes red and demands re-measurement instead of silently drifting.

### The staging directory is called `oxp-stage`, and that is load-bearing

A first version staged into `<artifact>/addons`. The staged app lives at `<artifact>/app`, and the
game also searches `<app dir>/../AddOns` — which on a case-insensitive filesystem **is** that same
directory. The expansion was found at two roots and the run logged **four** missing-manifest lines
instead of two. **The exact-count guard is what caught it.** A guard that merely allowed "some
missing-manifest errors" would have blessed a golden taken with the expansion loaded twice.

## Two defences on the central field, and the proof they are both real

`evidence.oxp_world_scripts` is the field this whole scenario exists to assert on, so it is
guarded twice, by two structurally different checks:

| | clause | what it catches |
|---|---|---|
| 1a | `if not isinstance(live, list) or not live:` | absent, wrong type, **or empty** |
| 1b | `elif set(live) != EXPECTED_OXP_WORLD_SCRIPTS:` | wrong set — the empty set is one case of that |

`test_each_defence_alone_still_rejects_an_empty_script_list` removes **each alone** in a copy of
the checker and asserts the copy still returns rc=1;
`test_removing_both_world_script_defences_does_change_behaviour` removes **both** and asserts the
bad dump is then **accepted**. That pair is the point: the first shows the redundancy holds, the
second shows it is genuine redundancy rather than two spellings of one check, which is the
distinction bead `oo-jor` had to make between a blind gate, an equivalent mutant and a deliberate
defence.

A third test, `test_the_empty_script_mutant_does_not_leak_into_another_field`, asserts the bad
dump differs from the golden in **exactly one** evidence field. An earlier version of the
redundancy test emptied `oxp_script_versions` in the same mutant — a *different* field with its
own defence — so the checker would have gone red even with both `oxp_world_scripts` defences
deleted, and the test would have reported a kill it did not earn.

## Scratch discipline: a mutation harness must refuse an inherited dirty tree

The first run of this bead's mutation harness was killed at a tool timeout **between apply and
undo**, so its `finally: undo_fn()` never ran and it left the checker carrying the "accept an
empty expansion script list" mutant, with the pristine original sitting beside it as
`check_retro_missions_evidence.py.oo3ya-bak`. The next run then reported a red baseline and a
stale-mutation assertion, and the symptom looked like a refactor that had moved a line.

A self-scoped "I restored what I mutated" guard cannot see this (bead `oo-p2t`). The harness now
does two things instead: it **refuses to start** if any `*.oo3ya-bak` is already on disk, naming
each file and saying that the backup is the original; and it registers an `atexit` restore so the
mutation is undone even when the process dies rather than only when a loop iteration raises.

## Stability

10 consecutive runs on 2026-09-18, all 10 **DUMPED**, all byte-identical (1973 bytes, md5
`4c49d2295a33232f7ca477178b32eb1c`), **0 REFUSED**, **0 DIFFERED**; wall 17–21 s each. Quantisation
was not touched — there was nothing to hide, and coarsening a golden to make it pass is forbidden
and is refused by `golden_diff.py` anyway.

## What this golden does **not** pin

The scenario never launches the player, spawns no cast, and switches the system populator off at
the source (`system.setPopulator(key, null)`, 36 settings suppressed) before anything is measured —
for the reason bead `oo-jor` established: the populator adds traffic during the run and every ship
it adds consumes RANROT draws, so a fixed seed fixes the *sequence* but not how far a wall-clock
run has got through it. The world in the dump is the system's own fixed entities plus the player.
That is deliberate: the smallest world in which "did the expansion go live" can be asked.

## Build flags

`provenance.json` records `build_flags.verified: false` — the shared build was compiled without
`-ffp-contract=off` on all 242 translation units. That is a **known defect owned by bead
`oo-5ggu`**, not a fault of this scenario, and it is recorded honestly rather than papered over.
