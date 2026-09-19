# Scenario 018 — expansion-closure-and-manifestless

> Two launches of the same build differing only in what is staged: an expansion with a non-empty
> `requires_oxps` loads with its transitive closure and is refused without it, and a manifest-less
> in-tree fixture loads while emitting exactly its two standards errors.

Filed by bead `oo-1bf.5`, specified in
[`docs/phases/scenario-catalogue.json`](../../../../docs/phases/scenario-catalogue.json) and argued
in [`docs/phases/0-scenarios-18-20.md`](../../../../docs/phases/0-scenarios-18-20.md).
Harness: [`tests/golden/expansion_closure.py`](../../expansion_closure.py).

## What this exercises that nothing else does

Scenarios 007–012 each load exactly **one** in-tree test-oxp, solo, and pin what its *content*
does. None stages a dependency **closure**, none carries a **negative control** in which the same
expansion is *refused*, and none pins the standards diagnostics of an expansion with no
`manifest.plist`. 001–006 stage no expansion at all; 013–017 load saves. The resource-path
**composition** layer — `ResourceManager`'s search-path assembly, manifest parsing, requirement
resolution and the standards-diagnostic channel — was unobserved by any golden.

## The shape: a differential, never an absence

Bead `oo-het` captured a real corpse: `exit 87`, a 1476-byte `Latest.log` carrying the version
banner and `[process.args]`, **zero lines matching ERROR**, and nothing loaded. And a separate run
was quit early by a *sibling worker's* console while still exiting `rc=0` with a clean log. So
"exit code 0" and "no errors in the log" are both satisfiable by a run that did nothing, and
neither may be evidence here.

This scenario therefore runs **two game processes** that differ only in staging:

| arm | staged | required outcome |
| --- | --- | --- |
| **closure** | `oolite.oxp.Svengali.GNN` + `oolite.oxp.Svengali.Library` + `RetroMissions.oxp` | primary **named** in `[searchPaths.dumpAll]`, no `[oxp.requirementMissing]` |
| **control** | `oolite.oxp.Svengali.GNN` alone + `RetroMissions.oxp` | primary **absent** from `[searchPaths.dumpAll]`, `[oxp.requirementMissing]` naming it |

Both arms must reach `[startup.complete]`, a marker emitted *after* expansion parsing that the
exit-87 corpse never reaches. The two arms' search-path blocks must **differ**: two identical
blocks mean the staging difference never reached the engine.

Measured, matching bead `oo-kcrw`'s causal result exactly:

```
closure search paths: Resources, AddOns, console-config, oxp-stage, Basic-debug.oxp,
                      RetroMissions.oxp, oolite.oxp.Svengali.GNN.oxz,
                      oolite.oxp.Svengali.Library.oxz
control search paths: Resources, AddOns, console-config, oxp-stage, Basic-debug.oxp,
                      RetroMissions.oxp
control log:          [oxp.requirementMissing]: OXP oolite.oxp.Svengali.GNN.oxz had unmet
                      requirements and was removed from the loading list
```

## The manifest-less arm, and why `.oxp` is load-bearing

`upstream/oolite-tests/test-oxps/RetroMissions/RetroMissions.oxp` ships no `manifest.plist`.
`ResourceManager.m:634-664` branches on the **file extension**:

* an `.oxz` with no manifest logs `oxp.noManifest` and **returns at :640** — never loaded;
* an `.oxp` emits `OOStandardsError` at `:646` and, with `OOEnforceStandards()` false, falls
  through to `:654` where a basic manifest (`__oolite.tmp.<path>`) is **synthesised** and the path
  **is** added to the search paths at `:663`.

So the fixture **loads** and its complaint is informational. The count is pinned at **exactly 2**
in *both* runs (bead `oo-kcrw`'s NOMANIF class; the tell that it is a fixture property rather than
five independent defects is that five unrelated fixtures each produce exactly 2). The spec gate
refuses any other value and refuses a `manifestless_oxp` knob pointing at an `.oxz`, because that
would silently convert the arm from "loads and complains" to "does not load at all".

Standards lines are attributed **per expansion** by `tools/oxp_deps.attribute_errors` (longest
token wins), so a complaint owned by the primary or its dependency cannot be absorbed into the
fixture's allowance, and any line **no staged expansion claims** fails the run on its own clause.
Scenario 012 measured **4** instead of 2 when its staging directory happened to be reachable by two
roots; that is why this harness stages into a directory called `oxp-stage` and never `addons`
(`<artifact>/addons` *is* `<artifact>/../AddOns` on a case-insensitive filesystem).

## Determinism

| knob | value |
| --- | --- |
| seed | `20260918` |
| system | 7 (Lave) |
| ticks × tick_seconds | 8 × 0.125 s |
| quantisation | 3 decimals |
| save | `Resources/Scenarios/oolite-standard.oolite-save` |
| flight | **none** — docked throughout |

No flight, so the thrust-velocity problem (`ShipEntity.m:12830-12833`) is out of scope by
construction. The populator is switched off at the source (`system.setPopulator(key, null)`) before
anything is measured, the world is cleared of non-station ships, the game is paused under a
**checked** `pauseGame()`, and the clock is asserted not to advance across the pause.

**Stability: 10 consecutive runs, all 10 DUMPED, all byte-identical** (3377 bytes, one sha256),
0 REFUSED, 0 ERRORED, wall 14–15 s each (each run is two game processes).
`ps -W | grep -ci oolite` read 0 before every launch.

## The frame

`frame.grid` (4096-byte 64×64 luminance grid) and `frame.png` are stored. The grid carries a
**liveness** assertion only — distance from an all-black grid ≥ 0.02:

```
blessed frame vs black            0.032179
every real frame vs black         0.032124 .. 0.032196
largest same-scene pair (10 runs) 0.001853     <- 10.8x below the floor
all-white vs blessed              0.967821
```

The byte digest is **never** a gate predicate: llvmpipe is not bit-reproducible and this
scenario's own sweep produced **10 distinct grid digests over 1 dump digest**. Deterministic
artifacts get a digest; renderer output gets a measured floor. A frame-vs-reference *tolerance*
assertion was measured (same-scene pairs sit at 0.31×–0.42× the calibrated tolerance, so it would
pass) and deliberately **not** adopted: the staged expansions have no visual consequence from a
docked camera, so such an assertion would measure the renderer rather than anything this scenario
is about.

## What goes RED, and what it means

| symptom | meaning |
| --- | --- |
| the control run names the primary in `[searchPaths.dumpAll]` | requirement resolution (`filterSearchPathsForRequirements`, `ResourceManager.m:949-975`) stopped enforcing `requires_oxps` — expansions now load with unmet dependencies, which is how an OXP breaks silently for every user |
| `[oxp.requirementMissing]` absent from the control run | the diagnostic channel died or the refusal moved earlier; corpus verdicts become unattributable |
| standards-error count for the fixture ≠ 2 | manifest parsing or the standards channel changed; above 2 means new complaints, below means complaints were lost |
| either run lacks `[startup.complete]` | a dead launch; every other signal in that run is void |
| a recomputed closure differing from the stored one | the identifier index or the dependency walk changed; the run measured a different composition |
| the two search-path blocks identical | the staging difference never reached the engine |
| frame liveness below 0.02 | nothing was rendered |

## Falsifiability

Two **live** mutant arms on the harness, both measured, both writing no artifact when they fail:

```
--break-closure     rc=1  8s  "the CLOSURE run staged ['oolite.oxp.Svengali.GNN'] yet
                              oolite.oxp.Svengali.GNN.oxz is ABSENT from [searchPaths.dumpAll]"
--no-manifestless   rc=1 14s  "the closure run attributed 0 [oxp-standards.error] line(s) ...
                              but exactly 2 is the pinned count"
```

and 27 offline arms in [`tests/golden/test_expansion_closure.py`](../../test_expansion_closure.py),
each pinning a property **twice**: a DATA mutant proving the unmutated checker refuses a corrupted
dump, and a CHECKER mutant proving that weakening *that one clause* makes the checker accept it.
The second assertion is what shows the kill belongs to that clause and not a neighbour; a mutant
that fails to flip the verdict is reported as a **MISKILL** rather than banked as a fake kill.
Every mutant is a throwaway copy under `tmp_path`; nothing in the repository is written to.

## Files

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus the `evidence` block |
| `frame.grid` | 4096-byte luminance grid of the blessed frame |
| `frame.png` | the blessed frame itself, for a human to look at |
| `spec.json` | every determinism knob the run reads |
| `provenance.json` | how the golden was produced, the knobs it was blessed with, the 10-run sweep, the frame measurements, and the `state.json` digest that witnesses it from outside |
| `LANDING.md` | the rehearsed procedure for moving these into `goldens/` (Jon's call) |

## No expansion content is read

The corpus blobs are staged **by path** and never opened by this scenario; only manifest
**metadata** (`identifier`, `version`, `requires_oxps`) is consulted, through `tools/oxp_deps.py`,
and only the game's own log output is judged.
