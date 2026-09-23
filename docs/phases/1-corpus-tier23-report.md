# Phase 1: Tier 2 and Tier 3 OXP corpus on QuickJS-ng (bead oo-1gc.11)

Evidence for two Phase 1 exit-gate lines ([1-js-engine.md](1-js-engine.md)): "Tier-1 and Tier-2 OXP
corpus green on QuickJS-ng" and "Every Tier-3 regression triaged". Measured 2026-09-23 with the
runners from bead oo-4z6 ([TIER23.md](../../tools/oxp-corpus/TIER23.md)). No expansion content was
read to produce this report: every statement below comes from the game's own log lines as the runner
recorded them, from the committed lists, and from `tools/oxp-js-lint/corpus-report.json`.

## Short answer

- **Tier 2 is not green.** 150 expansions: 109 PASS, 9 ERRORS, 32 NOTLOADED_DEPS, 0 harness
  failures. Four of the nine are JavaScript failures still under triage (beads below); the other
  five come from the game's data loaders or from the expansion's own checks, not from the JS engine.
- **Tier 3: 45 of 813 fail** in each run, with identical counts (595 PASS, 42 ERRORS, 3 NOTLOADED,
  173 NOTLOADED_DEPS). Across both runs 47 distinct expansions fail. 35 of them fail for
  engine-independent reasons, each class a row in
  [EXPANSION_MIGRATION.md](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11).
  12 fail with a JavaScript exception that could be an engine regression. A 13th,
  Thargoid.Wildships, failed only in the Tier 2 run. All 13 are filed as four beads, oo-1gc.13 to
  oo-1gc.16, because the SpiderMonkey side cannot be measured any more (see below).
- **The Tier-1 comparison holds.** All 29 SpiderMonkey-era Tier-1 catalogue expansions that are in
  Tier 3 give the same result here, except where solo loading explains the difference (table below).
- The Tier 2 run is now a nightly check (`tests/nightly/checks.txt`, line `[oo-1gc.11]`). That line
  was run verbatim, as `tools/run-nightly-checks.sh` runs it (`timeout 1800 bash -o pipefail -c`),
  against the main-tree build: 150 checked, 8 failing (the Tier 2 set below), 558 s, and the lock
  was released afterwards. It stays red until the Tier 2 failures above are fixed or re-baselined.

## What was run

| run | build | engine |
|---|---|---|
| **A** | `.worktrees/oo-5pr/upstream/oolite/build/meson_test/oolite.app` (phase-1 tree, oo-7wx: SpiderMonkey removed) | QuickJS-ng |
| **B** | `upstream/oolite/build/meson_test/oolite.app` (main tree, 2026-09-22 23:37) | QuickJS-ng as well |

Run B was started as a SpiderMonkey baseline and turned out not to be one. Its `libnspr4.dll` is a
leftover. The binary has QuickJS-ng's parser messages (`expecting '%c'`) and none of SpiderMonkey
1.8.5's (`missing ; before statement`), and it reports the same QuickJS-ng `SyntaxError: expecting
';'` as run A. The same check finds no SpiderMonkey-linked `oolite.exe` anywhere on the host: oo-7wx
removed the backend, and oo-1gc.6's SpiderMonkey build was in a worktree that has since been
deleted. **So no Tier 2/3 SpiderMonkey baseline exists or can be produced without rebuilding a
deleted backend.** Run B is kept as a repeat run: two QuickJS-ng builds from different trees give
the same Tier 3 state counts. The per-expansion differences come from the random populator, not the
engine (see "Run-to-run variance").

The one SpiderMonkey baseline that exists is **Tier 1**, from oo-1gc.6's differential run 4: 36
groups, SpiderMonkey backend, 30 PASS / 5 NOMANIF / 1 ERRORS (Norby.Carriers, oo-1gc.7). It appears
below in the `SM Tier-1` column.

Each tier ran as parallel `--shard K/N` invocations of `tools/corpus.sh tier2|tier3 --app-dir <build>
--state <dir>`, all under one `tools/gui-lock` hold (heartbeated through `tools/desktop_lock.py`).
Every load opens a real game window, so the shards run under a single lock. They never contend with
each other: each gets its own state, runs and staging directories.

| tier | run | total | PASS | ERRORS | NOTLOADED | NOTLOADED_DEPS | HARNESS | STAGEFAIL | NOTCACHED | failing | time |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Tier 2 | A | 150 | 109 | 9 | 0 | 32 | 0 | 0 | 0 | 9 | 323s wall (4 shards), 1251s serial-equivalent |
| Tier 2 | B | 150 | 110 | 8 | 0 | 32 | 0 | 0 | 0 | 8 | 306s wall (4 shards), 1182s serial-equivalent |
| Tier 3 | A | 813 | 595 | 42 | 3 | 173 | 0 | 0 | 0 | 45 | 1372s wall (6 shards), 7995s serial-equivalent |
| Tier 3 | B | 813 | 595 | 42 | 3 | 173 | 0 | 0 | 0 | 45 | 1297s wall (6 shards), 7573s serial-equivalent |

HARNESS, STAGEFAIL and NOTCACHED are zero in all four runs, so every verdict below is a real game
verdict. Loads took about 7 to 10 s each. That is faster than oo-het's 13.5 s, and it is why 813
expansions finished in about 22 minutes on 6 shards.

Tier 2 and Tier 3 load each expansion **solo**. Tier 1 loads each one with its `requires_oxps`
closure. So NOTLOADED_DEPS (173 in Tier 3) is the known oo-kcrw finding, not a failure, and an
expansion that needs a companion can fail here but pass in Tier 1.

## Regressions: what counts, and how each was triaged

Without a Tier 2/3 SpiderMonkey baseline, "regression" cannot mean "fails here, passed there". The
triage therefore sorts every failure by **who emitted the first error line**:

- **Engine-independent (35 expansions).** The error comes from the ObjC loaders (`shipData.*`,
  `plist.parse.failed`, `script.load.notFound`, `PlayerEntity.switchHudTo.failed`,
  `oxp.versionMismatch`), from Oolite's own argument check inside a native method
  (`Ship.setCargoType: ... Can only be used on cargo pod carriers`), from the expansion's own log
  message (`[XenonUI]: ERROR! ...`), or from reading a property of an absent world script
  (`cannot read property '$x' of undefined`, the same `TypeError` on any engine). None of these
  code paths changed with the engine swap, so they are pre-existing content or composition defects.
  They are grouped into classes E1 to E7, one row each in
  [EXPANSION_MIGRATION.md](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11).
- **JavaScript candidates (13 expansions: 12 from Tier 3, plus Wildships from Tier 2).** A `SyntaxError`, `ReferenceError` or engine
  `TypeError` that SpiderMonkey 1.8.5 might have accepted. Each one gets a bead. Settling them needs
  the construct at the logged file:line, which only the sandboxed scan role may read (CLAUDE.md
  rule 6). `tools/oxp-js-lint` reports **zero** findings for all 13, so none is one of the eight
  Mozilla-only constructs it already detects.

<a id="js-candidates"></a>
### JavaScript candidates

| bead | expansions | first error (file:line from the log) | engine-side hypothesis |
|---|---|---|---|
| **oo-1gc.13** | Griff.Asteroids, amah.noshaders_accessories, amah.noshaders_accessories_chunky_explosions | `TypeError: not a constructor` @ `*_spawn_rock_chunk.js:10-11`, `noshaders_spawn_biggerrock_chunk.js:10` | `new` on a native or no-constructor class that QuickJS-ng refuses and SpiderMonkey 1.8.5 may have allowed. The wording is QuickJS-ng's own, not the facade's `ooscript: object is not a constructor`. |
| **oo-1gc.14** | Svengali.Snoopers (Tier 2) | `TypeError: could not delete property` @ `snoopers.js:66` | a property the facade makes non-configurable that SpiderMonkey left deletable |
| **oo-1gc.15** | UK_Eliter.InterstellarTweaks (Tier 2), Norby.Towbar (Tier 2), zzz.Montana05.BUS_MegaBat, RobertTodd.Taranis, Wildeblood.Untrumbled | `ReferenceError: novelSubScenario_multiplyByMember` / `$BUS_MegaBat_space_jockey_cargo_array` / `c` / `prop is not defined` | (a) bare-name resolution through the script object, which the facade handles differently (already noted in EXPANSION_MIGRATION.md); (b) undeclared loop variables under the script's own `"use strict"`, which SpiderMonkey rejected as well. The facade does not force strict mode (`OOJSScript.mm:801-809`). |
| **oo-1gc.16** | Thargoid.Wildships (Tier 2), Thargoid.Aquatics, zzz.Montana05.Kestrel_Falcon, Alnivel.RoutePlanner | `SyntaxError: expecting ';'` @ `wildShips_tembo.js:16`, `aquatics_congerPods.js:17`, `bweed-kestrelfalcon-*.js:14/16` (compilation failed); `TypeError: not an object` @ `route-planner-interface.js:14` | SpiderMonkey-only syntax that the linter does not detect, from three unrelated authors |

**Outcome (beads oo-1gc.13 to oo-1gc.16, 2026-09-23).** Each construct was identified with the
redacting `tools/oxp-js-lint/probe.js`, which prints a script line as keywords, punctuators, API
names and placeholders only:

| bead | construct (redacted) | verdict |
|---|---|---|
| oo-1gc.13 | `this.ship.velocity = new Vector3D.random(NUM + Math.random() * NUM)` | engine difference: SpiderMonkey 1.8.5 let `new` call any native. Facade fixed, module test. |
| oo-1gc.14 | strict `for (var ID in this) { if (ID !== "name" && ID !== "version") delete this[ID]; }` | content defect E8: deletes the permanent `oolite_manifest_identifier`, which threw on SpiderMonkey as well |
| oo-1gc.15 | BUS_MegaBat: `this.ID = [...]; ... ID[...]` in a ship script | engine difference in the facade's bare-name fallback (last-run object, not the handler's). Fixed, module test. |
| oo-1gc.15 | InterstellarTweaks: bare call of a method of `this.$obj`; Towbar, Taranis, Untrumbled: undeclared `for (ID in ...)` under `"use strict"` | content defects E9: the same `ReferenceError` on SpiderMonkey |
| oo-1gc.16 | `function () { for (...) yield this[ID]; }` iterated by `for (let ID in ...)` (Wildships, Aquatics, Kestrel_Falcon x2) | Mozilla-only legacy generator. New lint rule `legacy-generator`, which flags exactly these four files in the corpus. |
| oo-1gc.16 | RoutePlanner: strict `reduce(function (ID, ID) { return ID[map[ID]] = ID; }, {})` | content defect E10: a strict write to a string primitive. SpiderMonkey 1.8.5 ignored it, QuickJS-ng throws as ES5 requires. |

Every other failing expansion links to its class row (E1 to E7) in the tables below. The generator
asserts that no failing expansion is left untriaged.

### Known failures cited, not re-filed

- `oolite.oxp.Norby.Carriers` fails on both engines in Tier 1 (bead **oo-1gc.7**). Here it is
  NOTLOADED_DEPS because it is loaded solo.
- `oolite.oxp.z.phkb.XenonUI` passes in Tier 1 only because oo-kcrw pairs it with a resource pack.
  Loaded solo it logs its own `No Xenon UI Resource packs installed` (E6), as it did on
  SpiderMonkey in oo-het's first Tier-1 run.

## Comparison with the SpiderMonkey-era Tier-1 baseline

29 of Tier 1's 30 catalogue expansions appear in Tier 3. `CommonSenseOTB.ShieldEqualizer+Ca...` is
truncated in the Tier-1 log and cannot be matched. 22 have the same result: PASS on SpiderMonkey
(Tier 1, with closure) and PASS on QuickJS-ng (Tier 3, solo, both runs). The other seven differ
because of solo loading, not because of the engine:

| expansion | SM Tier-1 (closure) | QuickJS-ng Tier 3 A / B (solo) | why |
|---|---|---|---|
| `oolite.oxp.Svengali.GNN` | PASS | NOTLOADED_DEPS / NOTLOADED_DEPS | declares requires_oxps (oo-kcrw) |
| `oolite.oxp.Thargoid.Planetfall` | PASS | NOTLOADED_DEPS / NOTLOADED_DEPS | declares requires_oxps (oo-kcrw) |
| `oolite.oxp.Svengali.OXPConfig` | PASS | NOTLOADED_DEPS / NOTLOADED_DEPS | declares requires_oxps (oo-kcrw) |
| `oolite.oxp.Griff.Cobra_MkIII` | PASS | NOTLOADED_DEPS / NOTLOADED_DEPS | declares requires_oxps (oo-kcrw) |
| `oolite.oxp.Norby.Separated_Lasers` | PASS | NOTLOADED_DEPS / NOTLOADED_DEPS | declares requires_oxps (oo-kcrw) |
| `oolite.oxp.Norby.Carriers` | ERRORS | NOTLOADED_DEPS / NOTLOADED_DEPS | declares requires_oxps; red on both engines in Tier 1 (oo-1gc.7) |
| `oolite.oxp.z.phkb.XenonUI` | PASS | ERRORS / ERRORS | needs a companion resource pack (E6) |

With the same closures and pairing, all seven give the SpiderMonkey result on QuickJS-ng as well:
oo-1gc.6 found 0 corpus divergences over all 36 Tier-1 groups.

## Run-to-run variance (A vs B)

The two QuickJS-ng runs agree on every Tier 3 state count. Individual verdicts differ where the
failure only appears if the populator happens to spawn a particular ship. Its ship script is
compiled lazily, and `setCargoType` is only called on ships that get spawned:

| Tier 2 expansion | A | B |
|---|---|---|
| `oolite.oxp.Thargoid.Wildships` | ERRORS | PASS |

| Tier 3 expansion | A | B |
|---|---|---|
| `oolite.oxp.Shipbuilder.ChimeraGunship` | PASS | ERRORS |
| `oolite.oxp.Shipbuilder.Fireball` | PASS | ERRORS |
| `oolite.oxp.Thargoid.Aquatics` | ERRORS | PASS |
| `oolite.oxp.zzz.Montana05.BUS_MegaBat` | ERRORS | PASS |

So a single run can hide a failure. The triage above covers the union of both runs. Expect the
nightly Tier 2 line to flicker the same way on Wildships (in Tier 3 the flickering expansions were
ChimeraGunship, Fireball, Aquatics and BUS_MegaBat).

## Clusters (run A, normalised first error line)

### Tier 2

| cluster | n | normalised first error line | members |
|---:|---:|---|---|
| 1 | 1 | `[XenonUI]: ERROR! No <OXP> Resource packs installed. <OXP> cannot function without one resource pack installed.` | `oolite.oxp.z.phkb.XenonUI` |
| 2 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (<OXP> <N>): ReferenceError: c is not defined` | `oolite.oxp.Norby.Towbar` |
| 3 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (IST_masterScript <N>): ReferenceError: novelSubScenario_multiplyByMember is not defined` | `oolite.oxp.UK_Eliter.InterstellarTweaks` |
| 4 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (new_lasers <N>): TypeError: cannot read property '$customCrosshairs' of undefined` | `oolite.oxp.redspear.new_lasers` |
| 5 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (oolite-populator <N>-fleet): Error: Ship.setCargoType: Invalid arguments ("PIRATE_GOODS") -- expected Can o...` | `oolite.oxp.Shipbuilder.ArachnidMark1` |
| 6 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (oolite-populator <N>-fleet): Error: Ship.setCargoType: Invalid arguments ("SCARCE_GOODS") -- expected Can o...` | `oolite.oxp.Shipbuilder.ChimeraGunship` |
| 7 | 1 | `[script.javaScript.load.failed]: ***** Error loading JavaScript script <PATH> -- compilation failed` | `oolite.oxp.Thargoid.Wildships` |
| 8 | 1 | `[script.load.notFound]: ***** ERROR: Could not find script file serpent_script_trader.js.` | `oolite.oxp.Shipbuilder.SerpentClassCruiser` |
| 9 | 1 | `[shipData.load.error]: ***** ERROR: the shipdata.plist entry "<OXP>_gcnewsA1" specifies non-existent model "cabal_common_key.dat".` | `oolite.oxp.Svengali.Snoopers` |

### Tier 3

| cluster | n | normalised first error line | members |
|---:|---:|---|---|
| 1 | 2 | `[plist.parse.failed]: Failed to parse <PATH> as a property list.` | `oolite.oxp.Reval.Neutralizer`, `oolite.oxp.redspear.demand_driven_economy` |
| 2 | 2 | `[script.javaScript.load.failed]: ***** Error loading JavaScript script <PATH> -- compilation failed` | `oolite.oxp.Thargoid.Aquatics`, `oolite.oxp.zzz.Montana05.Kestrel_Falcon` |
| 3 | 2 | `[script.load.notFound]: ***** ERROR: Could not find script file griff_spawn_wreckage.js.` | `gsagostinho.TexturePack.FerDeLance`, `gsagostinho.TexturePack.Python` |
| 4 | 2 | `[shipData.load.error]: ***** ERROR: the shipdata.plist entry "guild_lodge_tetrahedron_station" has unresolved subentities sfep_gz2_dock, sfep_gz2_tetrafaceplate, sfep_gz2_tetraf...` | `oolite.oxp.Reval.Elite_Trader`, `oolite.oxp.Reval.Elite_Trader_Meta` |
| 5 | 1 | `[PlayerEntity.switchHudTo.failed]: HUD dictionary file GETter_HUD.plist to switch to not found or invalid.` | `oolite.oxp.Reval.GETTER_HUD` |
| 6 | 1 | `[XenonUI]: ERROR! No <OXP> Resource packs installed. <OXP> cannot function without one resource pack installed.` | `oolite.oxp.z.phkb.XenonUI` |
| 7 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (<OXP> <N>): ReferenceError: c is not defined` | `oolite.oxp.Norby.Towbar` |
| 8 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (<OXP> <N>): ReferenceError: prop is not defined` | `oolite.oxp.Wildeblood.Untrumbled` |
| 9 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (BUS_MegaBat_events <N>): ReferenceError: $BUS_MegaBat_space_jockey_cargo_array is not defined` | `oolite.oxp.zzz.Montana05.BUS_MegaBat` |
| 10 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (CargoTypeExtension-Auctions <N>): TypeError: cannot read property 'auctioneers' of undefined` | `oolite.oxp.cim.new-cargoes` |
| 11 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (CargoTypeExtension-Station-<OXP> <N>): ReferenceError: prop is not defined` | `oolite.oxp.RobertTodd.Taranis` |
| 12 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (IST_masterScript <N>): ReferenceError: novelSubScenario_multiplyByMember is not defined` | `oolite.oxp.UK_Eliter.InterstellarTweaks` |
| 13 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (RoutePlanner_Interface): TypeError: not an object` | `oolite.oxp.Alnivel.RoutePlanner` |
| 14 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (Spawn-sothis <N>): TypeError: cannot read property '$addMissionScreenException' of undefined` | `oolite.oxp.KillerWolf.SothisTC` |
| 15 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (alien_systems <N>): TypeError: cannot read property '$addMarketInterface' of undefined` | `oolite.oxp.redspear.alien_systems` |
| 16 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (griff_spawn_rockchunk <N>): TypeError: not a constructor` | `oolite.oxp.Griff.Asteroids` |
| 17 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (new_lasers <N>): TypeError: cannot read property '$customCrosshairs' of undefined` | `oolite.oxp.redspear.new_lasers` |
| 18 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (noshader_spawn_rockchunk <N>): TypeError: not a constructor` | `oolite.oxp.amah.noshaders_accessories` |
| 19 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (noshaders_spawn_biggerrock_chunk.js <N>): TypeError: not a constructor` | `oolite.oxp.amah.noshaders_accessories_chunky_explosions` |
| 20 | 1 | `[script.javaScript.exception.notAnError]: ***** JavaScript exception (oolite-populator <N>-fleet): Error: Ship.setCargoType: Invalid arguments ("PIRATE_GOODS") -- expected Can o...` | `oolite.oxp.Shipbuilder.ArachnidMark1` |
| 21 | 1 | `[script.load.notFound]: ***** ERROR: Could not find script file serpent_script_trader.js.` | `oolite.oxp.Shipbuilder.SerpentClassCruiser` |
| 22 | 1 | `[shipData.load.error]: ***** ERROR: the shipdata.plist entry "<OXP>_gcnewsA1" specifies non-existent model "cabal_common_key.dat".` | `oolite.oxp.Svengali.Snoopers` |
| 23 | 1 | `[shipData.load.error]: ***** ERROR: the shipdata.plist entry "FuelC-cob3-alternate" specifies non-existent model "cobra3_redux1.dat".` | `oolite.oxp.Frame.FuelCollector` |
| 24 | 1 | `[shipData.load.error]: ***** ERROR: the shipdata.plist entry "assassins_rebooted_ncc_sidewinder_local_patrol" has unresolved subentity ncc_nswx-seng.` | `oolite.oxp.LittleBear.AssassinsGuildRebooted` |
| 25 | 1 | `[shipData.load.error]: ***** ERROR: the shipdata.plist entry "classic_gecko-B" has unresolved subentities classicShipsEngine2, classicShipsGun.` | `oolite.oxp.smivs.classicVarietyPack` |
| 26 | 1 | `[shipData.load.error]: ***** ERROR: the shipdata.plist entry "sfep_noshaders_tetrahedron" has unresolved subentities noshaders_tetrafaceplate, noshaders_tetrafront, noshaders_te...` | `oolite.oxp.amah.noshaders_stations_for_sfep` |
| 27 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: GalTech_ufp_container_computers` | `oolite.oxp.zzz.Montana05.GalTech_constitution_class_heavy_cruiser_Fix` |
| 28 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: Zygoroid1_ALT, Zygoroid1Sparkle, Zygoroid2, Zygoroid2...` | `oolite.oxp.ZygoUgo.shadyAsteroids` |
| 29 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: chimera_alt, chimera_alt_team_01, GalTech_chimera_gun...` | `oolite.oxp.zzz.Montana05.GalTech_chimera_gunship_Fix` |
| 30 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: noshaders_Zygoroid1_ALT, noshaders_Zygoroid1_Sparkles...` | `oolite.oxp.ZygoUgo.noshaders_Asteroids` |
| 31 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: noshaders_griff_tradeoutpost, noshaders_icosahedron_m...` | `oolite.oxp.amah.noshaders_extra_stations_addon` |
| 32 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: yah_set_A_asteroid-billboard, yah_set_A_constore, yah...` | `oolite.oxp.DrNil.YAH-SetA` |
| 33 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: yah_set_B_asteroid-billboard, yah_set_B_constore, yah...` | `oolite.oxp.DrNil.YAH-SetB` |
| 34 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: yah_set_C_asteroid-billboard, yah_set_C_constore, yah...` | `oolite.oxp.DrNil.YAH-SetC` |
| 35 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: yah_set_D_asteroid-billboard, yah_set_D_constore, yah...` | `oolite.oxp.DrNil.YAH-SetD` |
| 36 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: yah_set_E_asteroid-billboard, yah_set_E_constore, yah...` | `oolite.oxp.DrNil.YAH-SetE` |
| 37 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: yah_set_F_asteroid-billboard, yah_set_F_constore, yah...` | `oolite.oxp.DrNil.YAH-SetF` |
| 38 | 1 | `[shipData.merge.failed]: ***** ERROR: one or more shipdata.plist entries have like_ship references that cannot be resolved: yah_set_G_asteroid-billboard, yah_set_G_constore, yah...` | `oolite.oxp.DrNil.YAH-SetG` |

## Tier 2: every expansion

"loaded" means the expansion was named in `[searchPaths.dumpAll]`. "ERROR lines" counts run A's
lines attributable to the expansion, as `oxp_load_check` judges them.

| # | expansion | category | loaded | ERROR lines (A) | verdict A | verdict B | SM Tier-1 | triage |
|---:|---|---|---|---:|---|---|---|---|
| 1 | `oolite.oxp.CaptMurphy.ExplorersClub` | Activities | yes | 0 | PASS | PASS | PASS |  |
| 2 | `oolite.oxp.Norby.EscortDeck` | Activities | yes | 0 | PASS | PASS | PASS |  |
| 3 | `oolite.oxp.Norby.Towbar` | Activities | yes | 2 | **ERRORS** | **ERRORS** |  | [oo-1gc.15](#js-candidates) |
| 4 | `oolite.oxp.spara.additional_planets_sr_pack_redux` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 5 | `oolite.oxp.cim.combat-simulator` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 6 | `oolite.oxp.Norby.ShipVersion` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 7 | `oolite.oxp.astrobe.spacecrowds` | Activities | yes | 0 | PASS | PASS |  |  |
| 8 | `oolite.oxp.DrNil.YAH` | Ambience | yes | 0 | PASS | PASS | PASS |  |
| 9 | `oolite.oxp.spara.additional_planets_sr_base` | Ambience | yes | 0 | PASS | PASS | PASS |  |
| 10 | `oolite.oxp.z.phkb.XenonUI` | Ambience | yes | 1 | **ERRORS** | **ERRORS** | PASS | [E6](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 11 | `oolite.oxp.Svengali.GNN` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 12 | `oolite.oxp.phkb.TionislaOrbitalGraveyard` | Ambience | yes | 0 | PASS | PASS | PASS |  |
| 13 | `oolite.oxp.Norby.HDBG` | Ambience | yes | 0 | PASS | PASS | PASS |  |
| 14 | `oolite.oxp.Svengali.Snoopers` | Ambience | yes | 12 | **ERRORS** | **ERRORS** |  | [oo-1gc.14](#js-candidates) |
| 15 | `oolite.oxp.Svengali.BGS` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 16 | `oolite.oxp.Wildeblood.Display_Reputation` | Ambience | yes | 0 | PASS | PASS |  |  |
| 17 | `oolite.oxp.Norby.Ambience_Collection` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 18 | `oolite.oxp.Norby.FreighterConvoys` | Ambience | yes | 0 | PASS | PASS |  |  |
| 19 | `oolite.oxp.hoqllnq.missile-beep` | Ambience | yes | 0 | PASS | PASS |  |  |
| 20 | `oolite.oxp.Norby.Trails` | Ambience | yes | 0 | PASS | PASS |  |  |
| 21 | `oolite.oxp.stranger.PlanetarySystems` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 22 | `oolite.oxp.Layne.DockingFees` | Ambience | yes | 0 | PASS | PASS |  |  |
| 23 | `oolite.oxp.stranger.SunGear` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 24 | `oolite.oxp.Rorschachhamster.Satellites` | Ambience | yes | 0 | PASS | PASS |  |  |
| 25 | `oolite.oxp.redspear.additional_planets_sr_others_gas_giants` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 26 | `oolite.oxp.Norby.HDBG-A` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 27 | `oolite.oxp.phkb.PlanetRotationCosmetics` | Ambience | yes | 0 | PASS | PASS |  |  |
| 28 | `oolite.oxp.spara.start_advice` | Ambience | yes | 0 | PASS | PASS |  |  |
| 29 | `oolite.oxp.phkb.PlanetForestsAndOceans` | Ambience | yes | 0 | PASS | PASS |  |  |
| 30 | `oolite.oxp.Norby.Headlights` | Ambience | yes | 0 | PASS | PASS |  |  |
| 31 | `oolite.oxp.Wildeblood.Distant_Realms` | Ambience | yes | 0 | PASS | PASS |  |  |
| 32 | `oolite.oxp.cim.systemfeatures.sunspots` | Ambience | yes | 0 | PASS | PASS |  |  |
| 33 | `oolite.oxp.Wildeblood.Distant_Locales` | Ambience | yes | 0 | PASS | PASS |  |  |
| 34 | `oolite.oxp.Wildeblood.SEX_Drive` | Cheats | yes | 0 | PASS | PASS |  |  |
| 35 | `oolite.oxp.Thargoid.LaveAcademy` | Dockables | yes | 0 | PASS | PASS |  |  |
| 36 | `oolite.oxp.spara.stations_for_extra_planets` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 37 | `oolite.oxp.EricWalch.DeepSpaceDredger` | Dockables | yes | 0 | PASS | PASS |  |  |
| 38 | `oolite.oxp.phkb.LinersMarkets` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 39 | `oolite.oxp.Pagroove.Superhub` | Dockables | yes | 0 | PASS | PASS |  |  |
| 40 | `oolite.oxp.Thargoid.Wildships` | Dockables | yes | 6 | **ERRORS** | PASS |  | [oo-1gc.16](#js-candidates) |
| 41 | `oolite.oxp.Murgh.HoOpyCasino` | Dockables | yes | 0 | PASS | PASS |  |  |
| 42 | `oolite.oxp.spara.behemoth` | Dockables | yes | 0 | PASS | PASS |  |  |
| 43 | `oolite.oxp.cim.ships-library` | Equipment | yes | 0 | PASS | PASS | PASS |  |
| 44 | `oolite.oxp.Thargoid.PlanetaryCompass` | Equipment | yes | 0 | PASS | PASS | PASS |  |
| 45 | `oolite.oxp.CommonSenseOTB.SniperLock` | Equipment | yes | 0 | PASS | PASS | PASS |  |
| 46 | `oolite.oxp.spara.market_observer` | Equipment | yes | 0 | PASS | PASS |  |  |
| 47 | `oolite.oxp.Thargoid.IronHide` | Equipment | yes | 0 | PASS | PASS |  |  |
| 48 | `oolite.oxp.CommonSenseOTB.ShieldEqualizer+Capacitors` | Equipment | yes | 0 | PASS | PASS |  |  |
| 49 | `oolite.oxp.Thargoid.PlanetaryCompassPackC` | Equipment | yes | 0 | PASS | PASS |  |  |
| 50 | `oolite.oxp.Thargoid.PlanetaryCompassPackD` | Equipment | yes | 0 | PASS | PASS |  |  |
| 51 | `oolite.oxp.Thargoid.PlanetaryCompassPackB` | Equipment | yes | 0 | PASS | PASS |  |  |
| 52 | `oolite.oxp.Thargoid.PlanetaryCompassPackA` | Equipment | yes | 0 | PASS | PASS |  |  |
| 53 | `oolite.oxp.EricWalch.MissileAnalyser` | Equipment | yes | 0 | PASS | PASS |  |  |
| 54 | `oolite.oxp.Lone_Wolf.NavalGridNext` | Equipment | yes | 0 | PASS | PASS |  |  |
| 55 | `oolite.oxp.Wildeblood.AutoCrosshairs` | Equipment | yes | 0 | PASS | PASS |  |  |
| 56 | `oolite.oxp.Thargoid.RepairBots` | Equipment | yes | 0 | PASS | PASS |  |  |
| 57 | `oolite.oxp.Lone_Wolf.ShieldCyclerNext` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 58 | `oolite.oxp.phkb.LMSS` | Equipment | yes | 0 | PASS | PASS |  |  |
| 59 | `oolite.oxp.Norby.Telescope` | Equipment | yes | 0 | PASS | PASS |  |  |
| 60 | `oolite.oxp.Okti.CargoScanner` | Equipment | yes | 0 | PASS | PASS |  |  |
| 61 | `oolite.oxp.Thargoid.Neo-Docklights` | Equipment | yes | 0 | PASS | PASS |  |  |
| 62 | `oolite.oxp.cim.camera-drones` | Equipment | yes | 0 | PASS | PASS |  |  |
| 63 | `oolite.oxp.CaptMurphy.BreakableTorusDrive` | Equipment | yes | 0 | PASS | PASS |  |  |
| 64 | `oolite.oxp.Norby.CombatMFD` | HUDs | yes | 0 | PASS | PASS | PASS |  |
| 65 | `oolite.oxp.Norby.HUDSelector` | HUDs | yes | 0 | PASS | PASS | PASS |  |
| 66 | `oolite.oxp.phkb.BroadcastCommsMFD` | HUDs | yes | 0 | PASS | PASS | PASS |  |
| 67 | `oolite.oxp.CommonSenseOTB.NumericHUD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 68 | `oolite.oxp.spara.manifest_mfd` | HUDs | yes | 0 | PASS | PASS |  |  |
| 69 | `oolite.oxp.spara.navigation_mfd` | HUDs | yes | 0 | PASS | PASS |  |  |
| 70 | `oolite.oxp.phkb.CommsLogMFD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 71 | `oolite.oxp.Gnievmir.VimanaHUD` | HUDs | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 72 | `oolite.hud.data.Wildeblood.ShipName` | HUDs | yes | 0 | PASS | PASS |  |  |
| 73 | `oolite.oxp.Thargoid.Bigships` | Mechanics | yes | 0 | PASS | PASS | PASS |  |
| 74 | `oolite.oxp.Ngalo.NPC_Equipment_Damage` | Mechanics | yes | 0 | PASS | PASS | PASS |  |
| 75 | `oolite.oxp.Ngalo.N-Shields` | Mechanics | yes | 0 | PASS | PASS | PASS |  |
| 76 | `oolite.oxp.cim.escort-formations` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 77 | `oolite.oxp.Norby.Convoys` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 78 | `oolite.oxp.spara.start_choices` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 79 | `oolite.oxp.phkb.BlackMarket` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 80 | `oolite.oxp.phkb.BountySystem` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 81 | `oolite.oxp.UK_Eliter.InterstellarTweaks` | Mechanics | yes | 2 | **ERRORS** | **ERRORS** |  | [oo-1gc.15](#js-candidates) |
| 82 | `oolite.oxp.phkb.ShipConfiguration` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 83 | `oolite.oxp.ByronArn.AutoRefuel` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 84 | `oolite.oxp.dybal.NPC_Energy_Units` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 85 | `oolite.oxp.Norby.VariableMasslock` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 86 | `oolite.oxp.Commander_McLane.Total_patrol` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 87 | `oolite.oxp.Norby.TorusToSun` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 88 | `oolite.oxp.phkb.ExternalDockSystem` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 89 | `oolite.oxp.Griff.Griff_shipset_decals` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 90 | `oolite.oxp.Svengali.Library` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 91 | `oolite.oxp.phkb.MarketScriptInterface` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 92 | `oolite.oxp.CaptMurphy.ShipStorageHelper` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 93 | `oolite.oxp.zzz.Montana05.resource_pack_01` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 94 | `oolite.oxp.Svengali.OXPConfig` | Miscellaneous | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 95 | `oolite.oxp.Svengali.CCL` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 96 | `oolite.oxp.phkb.BulletinBoardSystem` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 97 | `oolite.oxp.phkb.SystemDataConfig` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 98 | `oolite.oxp.spara.random_hits` | Missions | yes | 0 | PASS | PASS |  |  |
| 99 | `oolite.oxp.Thargoid.StellarSerpents` | Missions | yes | 0 | PASS | PASS |  |  |
| 100 | `oolite.oxp.Griff.Santa` | Missions | yes | 0 | PASS | PASS |  |  |
| 101 | `oolite.oxp.Norby.TheCollector` | Missions | yes | 0 | PASS | PASS |  |  |
| 102 | `oolite.oxp.Thargoid.Stealth` | Missions | yes | 0 | PASS | PASS |  |  |
| 103 | `oolite.oxp.DrNil.Oo-Haul` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 104 | `oolite.oxp.EricWalch.TionislaReporter` | Missions | yes | 0 | PASS | PASS |  |  |
| 105 | `oolite.oxp.Ramirez.TridentDown` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 106 | `oolite.oxp.Griff_alloys_and_wreckage` | Retextures | yes | 0 | PASS | PASS | PASS |  |
| 107 | `oolite.oxp.Griff.Cobra_MkIII` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 108 | `oolite.oxp.smivs.better Buoys` | Retextures | yes | 0 | PASS | PASS |  |  |
| 109 | `oolite.oxp.Griff.Missiles` | Retextures | yes | 0 | PASS | PASS |  |  |
| 110 | `oolite.oxp.Griff.Station_Bundle` | Retextures | yes | 0 | PASS | PASS |  |  |
| 111 | `oolite.oxp.smivs.classicShipyard` | Retextures | yes | 0 | PASS | PASS |  |  |
| 112 | `oolite.oxp.Griff.Viper` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 113 | `oolite.oxp.Griff.Constrictor` | Retextures | yes | 0 | PASS | PASS |  |  |
| 114 | `oolite.oxp.Griff.Mamba_alt_texture` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 115 | `oolite.oxp.Griff.Cobra_MkI` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 116 | `oolite.oxp.Griff.Adder` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 117 | `oolite.oxp.Griff.Escape_Capsule` | Retextures | yes | 0 | PASS | PASS |  |  |
| 118 | `oolite.oxp.Griff.Boa_MkII` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 119 | `oolite.oxp.Norby.Carriers` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | ERRORS |  |
| 120 | `oolite.oxp.UK_Eliter.Ferdelance_3G` | Ships | yes | 0 | PASS | PASS |  |  |
| 121 | `oolite.oxp.UK_Eliter.ExtraThargoids` | Ships | yes | 0 | PASS | PASS |  |  |
| 122 | `oolite.oxp.captain_beatnik.Pitviper2` | Ships | yes | 0 | PASS | PASS |  |  |
| 123 | `oolite.oxp.Draco_Caeles.GenerationShips` | Ships | yes | 0 | PASS | PASS |  |  |
| 124 | `oolite.oxp.smivs.Clippers` | Ships | yes | 0 | PASS | PASS |  |  |
| 125 | `oolite.oxp.Norby.EscortPack` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 126 | `oolite.oxp.smivs.Liners` | Ships | yes | 0 | PASS | PASS |  |  |
| 127 | `oolie.oxp.redspear.janes_galactic_shipset` | Ships | yes | 0 | PASS | PASS |  |  |
| 128 | `oolite.oxp.Gnievmir.VimanaShipOverrides` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 129 | `oolite.oxp.UK_Eliter.SuperSidewinder` | Ships | yes | 0 | PASS | PASS |  |  |
| 130 | `oolite.oxp.Ramirez.SalezaAeronautics` | Ships | yes | 0 | PASS | PASS |  |  |
| 131 | `oolite.oxp.Shipbuilder.CylonRaiderMk1` | Ships | yes | 0 | PASS | PASS |  |  |
| 132 | `oolite.oxp.Robin.Sonoran` | Ships | yes | 0 | PASS | PASS |  |  |
| 133 | `oolite.oxp.Shipbuilder.SerpentClassCruiser` | Ships | yes | 9 | **ERRORS** | **ERRORS** |  | [E2](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 134 | `oolite.oxp.Shipbuilder.ChimeraGunship` | Ships | yes | 6 | **ERRORS** | **ERRORS** |  | [E2](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 135 | `oolite.oxp.Norby.MinerCobra` | Ships | yes | 0 | PASS | PASS |  |  |
| 136 | `oolite.oxp.Shipbuilder.ArachnidMark1` | Ships | yes | 4 | **ERRORS** | **ERRORS** |  | [E2](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 137 | `oolite.oxp.smivs.yellooCabs` | Ships | yes | 0 | PASS | PASS |  |  |
| 138 | `oolite.oxp.Ramirez.ExecutiveSpaceWays` | Ships | yes | 0 | PASS | PASS |  |  |
| 139 | `oolite.oxp.smivs.contractor` | Ships | yes | 0 | PASS | PASS |  |  |
| 140 | `oolite.oxp.Thargoid.Planetfall` | Systems | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 141 | `oolite.oxp.Ramirez.FeudalStates` | Systems | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 142 | `oolite.oxp.Commander_McLane.Anarchies` | Systems | yes | 0 | PASS | PASS |  |  |
| 143 | `oolite.oxp.DrNil.Commies` | Systems | yes | 0 | PASS | PASS |  |  |
| 144 | `oolite.oxp.Ramirez.Dictators` | Systems | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 145 | `oolite.oxp.Norby.Separated_Lasers` | Weapons | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 146 | `oolite.oxp.Norby.Sniper_Gun` | Weapons | yes | 0 | PASS | PASS |  |  |
| 147 | `oolite.oxp.redspear.new_lasers` | Weapons | yes | 2 | **ERRORS** | **ERRORS** |  | [E1](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 148 | `oolite.oxp.cim.energy-bomb` | Weapons | yes | 0 | PASS | PASS |  |  |
| 149 | `oolite.oxp.Norby.Eco_Lasers` | Weapons | yes | 0 | PASS | PASS |  |  |
| 150 | `oolite.oxp.Norby.Multiple_Lasers` | Weapons | yes | 0 | PASS | PASS |  |  |

## Tier 3: every expansion

<details><summary>813 rows (click to expand)</summary>

| # | expansion | category | loaded | ERROR lines (A) | verdict A | verdict B | SM Tier-1 | triage |
|---:|---|---|---|---:|---|---|---|---|
| 1 | `DTT.Atlas 1.1.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 2 | `DTT.Cyclops 1.0.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 3 | `DTT.Galaxy_Liner 1.0.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 4 | `DTT.Heart_of_Gold 1.0.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 5 | `DTT.Heavy_Metal.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 6 | `DTT.Kraken.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 7 | `DTT.MK-1 1.0.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 8 | `DTT.Manta.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 9 | `DTT.Planet_Express 1.1.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 10 | `DTT.Snake Charmer 1.1.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 11 | `DTT.Snake Charmer Pinup 1.1.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 12 | `DTT.Space Zeppelin 1.0.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 13 | `DTT.Tomahawk.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 14 | `DTT.War_Lance.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 15 | `DTT.Wraith.Paradox` | Ships | yes | 0 | PASS | PASS |  |  |
| 16 | `Oolite.oxp.redspear.cargo_scoop_as_standard` | Equipment | yes | 0 | PASS | PASS |  |  |
| 17 | `cim.gsagostinho.systemfeatures.rings` | Ambience | yes | 0 | PASS | PASS |  |  |
| 18 | `gsagostinho.CobraMkIV` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 19 | `gsagostinho.DangerousHUD.BlueVariant` | HUDs | yes | 0 | PASS | PASS |  |  |
| 20 | `gsagostinho.DangerousHUD.GreenVariant` | HUDs | yes | 0 | PASS | PASS |  |  |
| 21 | `gsagostinho.DangerousHUD.OrangeVariant` | HUDs | yes | 0 | PASS | PASS |  |  |
| 22 | `gsagostinho.DangerousHUD.PinkVariant` | HUDs | yes | 0 | PASS | PASS |  |  |
| 23 | `gsagostinho.DangerousHUD.PurpleVariant` | HUDs | yes | 0 | PASS | PASS |  |  |
| 24 | `gsagostinho.DangerousHUD.WhiteVariant` | HUDs | yes | 0 | PASS | PASS |  |  |
| 25 | `gsagostinho.DangerousKeyconfig` | Miscellaneous | no | 0 | **NOTLOADED** | **NOTLOADED** |  | [E5](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 26 | `gsagostinho.TexturePack.Adder` | Retextures | yes | 0 | PASS | PASS |  |  |
| 27 | `gsagostinho.TexturePack.AspMkII` | Retextures | yes | 0 | PASS | PASS |  |  |
| 28 | `gsagostinho.TexturePack.CobraMkIII` | Retextures | yes | 0 | PASS | PASS |  |  |
| 29 | `gsagostinho.TexturePack.FerDeLance` | Retextures | yes | 6 | **ERRORS** | **ERRORS** |  | [E3](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 30 | `gsagostinho.TexturePack.Python` | Retextures | yes | 3 | **ERRORS** | **ERRORS** |  | [E3](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 31 | `olite.oxp.smivs.ClassicOoniverse` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 32 | `oolie.oxp.redspear.janes_galactic_shipset` | Ships | yes | 0 | PASS | PASS |  |  |
| 33 | `oolite.hud.data.Wildeblood.Docked_HUDs` | HUDs | yes | 0 | PASS | PASS |  |  |
| 34 | `oolite.hud.data.Wildeblood.ShipName` | HUDs | yes | 0 | PASS | PASS |  |  |
| 35 | `oolite.oxp.Aegidean.CompactHUD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 36 | `oolite.oxp.Alnivel.InterfaceReordering` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 37 | `oolite.oxp.Alnivel.RoutePlanner` | Mechanics | yes | 4 | **ERRORS** | **ERRORS** |  | [oo-1gc.16](#js-candidates) |
| 38 | `oolite.oxp.AndreyBelov.BountyInformer` | Equipment | yes | 0 | PASS | PASS |  |  |
| 39 | `oolite.oxp.AndreyBelov.DuplexFuelTank` | Equipment | yes | 0 | PASS | PASS |  |  |
| 40 | `oolite.oxp.AndreyBelov.Targeter` | Equipment | yes | 0 | PASS | PASS |  |  |
| 41 | `oolite.oxp.ArexackHeretic.CargoWreck` | Ambience | yes | 0 | PASS | PASS |  |  |
| 42 | `oolite.oxp.ArexackHeretic.ThargornThreat` | Ships | yes | 0 | PASS | PASS |  |  |
| 43 | `oolite.oxp.ArexackHeretic.att1` | Ships | yes | 0 | PASS | PASS |  |  |
| 44 | `oolite.oxp.Arquebus.ContextualJukebox` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 45 | `oolite.oxp.Astrobe.ShakyDrive` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 46 | `oolite.oxp.Astrobe.adder-start.oxz` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 47 | `oolite.oxp.Astrobe.luckycharm` | Equipment | yes | 0 | PASS | PASS |  |  |
| 48 | `oolite.oxp.Astrobe.sc-serpent.oxz` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 49 | `oolite.oxp.Astrobe.smallships` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 50 | `oolite.oxp.Astrobe.sunkyota` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 51 | `oolite.oxp.Astrobe.surjectors` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 52 | `oolite.oxp.BeeTLeBeTHLeHeM.Life-In-The-Frontier-Revival` | Activities | yes | 0 | PASS | PASS |  |  |
| 53 | `oolite.oxp.BeeTLeBeTHLeHeM.LifeInTheFrontier` | Activities | yes | 0 | PASS | PASS |  |  |
| 54 | `oolite.oxp.ByronArn.AutoRefuel` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 55 | `oolite.oxp.CaptMurphy.BreakableEnergyUnit` | Equipment | yes | 0 | PASS | PASS |  |  |
| 56 | `oolite.oxp.CaptMurphy.BreakableEngines` | Equipment | yes | 0 | PASS | PASS |  |  |
| 57 | `oolite.oxp.CaptMurphy.BreakableHUDIFFScanner` | Equipment | yes | 0 | PASS | PASS |  |  |
| 58 | `oolite.oxp.CaptMurphy.BreakableShieldGenerators` | Equipment | yes | 0 | PASS | PASS |  |  |
| 59 | `oolite.oxp.CaptMurphy.BreakableTorusDrive` | Equipment | yes | 0 | PASS | PASS |  |  |
| 60 | `oolite.oxp.CaptMurphy.BreakableWitchDrive` | Equipment | yes | 0 | PASS | PASS |  |  |
| 61 | `oolite.oxp.CaptMurphy.EscortContracts` | Missions | yes | 0 | PASS | PASS |  |  |
| 62 | `oolite.oxp.CaptMurphy.ExplorersClub` | Activities | yes | 0 | PASS | PASS | PASS |  |
| 63 | `oolite.oxp.CaptMurphy.PoliceIFFScanner` | Equipment | yes | 0 | PASS | PASS |  |  |
| 64 | `oolite.oxp.CaptMurphy.ShipStorageHelper` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 65 | `oolite.oxp.CaptSolo.Cobra_Mk3-XT` | Ships | yes | 0 | PASS | PASS |  |  |
| 66 | `oolite.oxp.Cholmondeley.Lore_Collection_(Classic_Elite)` | Systems | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 67 | `oolite.oxp.Cholmondely.BroadcastComms_Digebiti_Variations` | HUDs | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 68 | `oolite.oxp.Cholmondely.Hints` | Activities | yes | 0 | PASS | PASS |  |  |
| 69 | `oolite.oxp.Chris.MincePie` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 70 | `oolite.oxp.ClymAngus.Kirin` | Ships | yes | 0 | PASS | PASS |  |  |
| 71 | `oolite.oxp.ClymAngus.KirinSport` | Ships | yes | 0 | PASS | PASS |  |  |
| 72 | `oolite.oxp.ClymAngus.NeoCaduceus` | Ships | yes | 0 | PASS | PASS |  |  |
| 73 | `oolite.oxp.CmdCheyd.DH_AdvancedNavigationComputer` | Equipment | yes | 0 | PASS | PASS |  |  |
| 74 | `oolite.oxp.CmdCheyd.DH_EmergencyWitchspaceInitiator` | Equipment | yes | 0 | PASS | PASS |  |  |
| 75 | `oolite.oxp.CmdrWombat.Deposed` | Missions | yes | 0 | PASS | PASS |  |  |
| 76 | `oolite.oxp.CmdrWombat.ThargoidWars` | Missions | yes | 0 | PASS | PASS |  |  |
| 77 | `oolite.oxp.Commander_McLane.Anarchies` | Systems | yes | 0 | PASS | PASS |  |  |
| 78 | `oolite.oxp.Commander_McLane.Auto_Eject` | Equipment | yes | 0 | PASS | PASS |  |  |
| 79 | `oolite.oxp.Commander_McLane.Cataclysm` | Missions | yes | 0 | PASS | PASS |  |  |
| 80 | `oolite.oxp.Commander_McLane.Display_reputation` | Ambience | yes | 0 | PASS | PASS |  |  |
| 81 | `oolite.oxp.Commander_McLane.Fireworks` | Ambience | yes | 0 | PASS | PASS |  |  |
| 82 | `oolite.oxp.Commander_McLane.FlyingDutchman` | Missions | yes | 0 | PASS | PASS |  |  |
| 83 | `oolite.oxp.Commander_McLane.Interstellar_Help` | Activities | yes | 0 | PASS | PASS |  |  |
| 84 | `oolite.oxp.Commander_McLane.Randomshipnames` | Ambience | yes | 0 | PASS | PASS |  |  |
| 85 | `oolite.oxp.Commander_McLane.Sell_Equipment` | Equipment | yes | 0 | PASS | PASS |  |  |
| 86 | `oolite.oxp.Commander_McLane.Total_patrol` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 87 | `oolite.oxp.Commander_McLane.Wormhole_Restoration` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 88 | `oolite.oxp.CommonSenseOTB.CustomShields` | Ambience | yes | 0 | PASS | PASS |  |  |
| 89 | `oolite.oxp.CommonSenseOTB.NumericHUD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 90 | `oolite.oxp.CommonSenseOTB.Q-Charger` | Equipment | yes | 0 | PASS | PASS |  |  |
| 91 | `oolite.oxp.CommonSenseOTB.ShieldEqualizer+Capacitors` | Equipment | yes | 0 | PASS | PASS |  |  |
| 92 | `oolite.oxp.CommonSenseOTB.SniperLock` | Equipment | yes | 0 | PASS | PASS | PASS |  |
| 93 | `oolite.oxp.Day.Diplomacy` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 94 | `oolite.oxp.Diagoras.MiningContracts` | Activities | yes | 0 | PASS | PASS |  |  |
| 95 | `oolite.oxp.Disembodied.FreeTradeZone` | Dockables | yes | 0 | PASS | PASS |  |  |
| 96 | `oolite.oxp.Diziet.Q-Bomb-Detector` | Equipment | yes | 0 | PASS | PASS |  |  |
| 97 | `oolite.oxp.Diziet.hyperradioCATACLYSM` | Ambience | yes | 0 | PASS | PASS |  |  |
| 98 | `oolite.oxp.DrNil.Commies` | Systems | yes | 0 | PASS | PASS |  |  |
| 99 | `oolite.oxp.DrNil.Oo-Haul` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 100 | `oolite.oxp.DrNil.YAH` | Ambience | yes | 0 | PASS | PASS | PASS |  |
| 101 | `oolite.oxp.DrNil.YAH-SetA` | Ambience | yes | 10 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 102 | `oolite.oxp.DrNil.YAH-SetB` | Ambience | yes | 10 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 103 | `oolite.oxp.DrNil.YAH-SetC` | Ambience | yes | 10 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 104 | `oolite.oxp.DrNil.YAH-SetD` | Ambience | yes | 10 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 105 | `oolite.oxp.DrNil.YAH-SetE` | Ambience | yes | 10 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 106 | `oolite.oxp.DrNil.YAH-SetF` | Ambience | yes | 10 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 107 | `oolite.oxp.DrNil.YAH-SetG` | Ambience | yes | 10 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 108 | `oolite.oxp.Draco_Caeles.GenerationShips` | Ships | yes | 0 | PASS | PASS |  |  |
| 109 | `oolite.oxp.DrewWagar.TianvePulsar` | Ambience | yes | 0 | PASS | PASS |  |  |
| 110 | `oolite.oxp.EricWalch.DeepSpaceDredger` | Dockables | yes | 0 | PASS | PASS |  |  |
| 111 | `oolite.oxp.EricWalch.DeepSpacePirates` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 112 | `oolite.oxp.EricWalch.MisjumpAnalyser` | Equipment | yes | 0 | PASS | PASS |  |  |
| 113 | `oolite.oxp.EricWalch.MissileAnalyser` | Equipment | yes | 0 | PASS | PASS |  |  |
| 114 | `oolite.oxp.EricWalch.PirateCove` | Ambience | yes | 0 | PASS | PASS |  |  |
| 115 | `oolite.oxp.EricWalch.TionislaReporter` | Missions | yes | 0 | PASS | PASS |  |  |
| 116 | `oolite.oxp.EricWalch.UPSCourier` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 117 | `oolite.oxp.Frame.FuelCollector` | Equipment | yes | 2 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 118 | `oolite.oxp.FritzG.Navigation_Flashers` | Ambience | yes | 0 | PASS | PASS |  |  |
| 119 | `oolite.oxp.FritzG.Synchronised_Torus` | Equipment | yes | 0 | PASS | PASS |  |  |
| 120 | `oolite.oxp.Galileo.Ionics` | Missions | yes | 0 | PASS | PASS |  |  |
| 121 | `oolite.oxp.Gilhad.EquipmentExpensiveItemColor` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 122 | `oolite.oxp.Gnievmir.VimanaHUD` | HUDs | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 123 | `oolite.oxp.Gnievmir.VimanaShipOverrides` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 124 | `oolite.oxp.Griff.Adder` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 125 | `oolite.oxp.Griff.Anaconda` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 126 | `oolite.oxp.Griff.Asp` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 127 | `oolite.oxp.Griff.Asteroids` | Retextures | yes | 20 | **ERRORS** | **ERRORS** |  | [oo-1gc.13](#js-candidates) |
| 128 | `oolite.oxp.Griff.Boa` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 129 | `oolite.oxp.Griff.Boa_MkII` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 130 | `oolite.oxp.Griff.Bug_(Elite2)` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 131 | `oolite.oxp.Griff.Cargopod` | Retextures | yes | 0 | PASS | PASS |  |  |
| 132 | `oolite.oxp.Griff.Cobra_MKIII_Alt` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 133 | `oolite.oxp.Griff.Cobra_MkI` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 134 | `oolite.oxp.Griff.Cobra_MkIII` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 135 | `oolite.oxp.Griff.Cobra_MkIII.SubentMissiles` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 136 | `oolite.oxp.Griff.Constrictor` | Retextures | yes | 0 | PASS | PASS |  |  |
| 137 | `oolite.oxp.Griff.Escape_Capsule` | Retextures | yes | 0 | PASS | PASS |  |  |
| 138 | `oolite.oxp.Griff.Ferdelance` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 139 | `oolite.oxp.Griff.Gecko` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 140 | `oolite.oxp.Griff.Gnat_(Elite2)` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 141 | `oolite.oxp.Griff.Griff_shipset_decals` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 142 | `oolite.oxp.Griff.Griffin1_(Elite2)` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 143 | `oolite.oxp.Griff.Hognose` | Ships | yes | 0 | PASS | PASS |  |  |
| 144 | `oolite.oxp.Griff.Krait` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 145 | `oolite.oxp.Griff.Mamba` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 146 | `oolite.oxp.Griff.Mamba_alt_texture` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 147 | `oolite.oxp.Griff.Missiles` | Retextures | yes | 0 | PASS | PASS |  |  |
| 148 | `oolite.oxp.Griff.Moray` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 149 | `oolite.oxp.Griff.Ophidian_(EliteA)` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 150 | `oolite.oxp.Griff.Prototype_Boa` | Ships | yes | 0 | PASS | PASS |  |  |
| 151 | `oolite.oxp.Griff.Python` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 152 | `oolite.oxp.Griff.Santa` | Missions | yes | 0 | PASS | PASS |  |  |
| 153 | `oolite.oxp.Griff.Shuttle` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 154 | `oolite.oxp.Griff.Sidewinder` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 155 | `oolite.oxp.Griff.SpecGloss_Sidewinder` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 156 | `oolite.oxp.Griff.StartinGriffCobraIII` | Miscellaneous | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 157 | `oolite.oxp.Griff.Station_Bundle` | Retextures | yes | 0 | PASS | PASS |  |  |
| 158 | `oolite.oxp.Griff.Thargoids` | Retextures | yes | 0 | PASS | PASS |  |  |
| 159 | `oolite.oxp.Griff.TradeOutpost` | Dockables | yes | 0 | PASS | PASS |  |  |
| 160 | `oolite.oxp.Griff.Transporter` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 161 | `oolite.oxp.Griff.Viper` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 162 | `oolite.oxp.Griff.Viper_Interceptor_exp` | Ships | yes | 0 | PASS | PASS |  |  |
| 163 | `oolite.oxp.Griff.Viper_exp` | Ships | yes | 0 | PASS | PASS |  |  |
| 164 | `oolite.oxp.Griff.Wolf_Mk_II` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 165 | `oolite.oxp.Griff.Worm` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 166 | `oolite.oxp.Griff_alloys_and_wreckage` | Retextures | yes | 0 | PASS | PASS | PASS |  |
| 167 | `oolite.oxp.IronFist.Draven` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 168 | `oolite.oxp.JohnSmith.LoveCats` | Missions | yes | 0 | PASS | PASS |  |  |
| 169 | `oolite.oxp.Kaks.FontTty` | Ambience | yes | 0 | PASS | PASS |  |  |
| 170 | `oolite.oxp.KillerWolf.KingCobra` | Ships | yes | 0 | PASS | PASS |  |  |
| 171 | `oolite.oxp.KillerWolf.SothisTC` | Dockables | yes | 2 | **ERRORS** | **ERRORS** |  | [E1](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 172 | `oolite.oxp.Killer_Wolf.Adder_Mark_III` | Ships | yes | 0 | PASS | PASS |  |  |
| 173 | `oolite.oxp.Killer_Wolf.Steampunk_hud` | HUDs | yes | 0 | PASS | PASS |  |  |
| 174 | `oolite.oxp.Layne.DockingFees` | Ambience | yes | 0 | PASS | PASS |  |  |
| 175 | `oolite.oxp.LittleBear.AssassinsGuildRebooted` | Missions | yes | 12 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 176 | `oolite.oxp.LittleBear.AsteroidStorm` | Ambience | yes | 0 | PASS | PASS |  |  |
| 177 | `oolite.oxp.LittleBear.GalacticAlmanac` | Ambience | yes | 0 | PASS | PASS |  |  |
| 178 | `oolite.oxp.LittleBear.RandomStationNames` | Ambience | yes | 0 | PASS | PASS |  |  |
| 179 | `oolite.oxp.Lone_Wolf.ETTHomingBeacon` | Equipment | yes | 0 | PASS | PASS |  |  |
| 180 | `oolite.oxp.Lone_Wolf.Missile_Spoof` | Equipment | yes | 0 | PASS | PASS |  |  |
| 181 | `oolite.oxp.Lone_Wolf.NavalGridNext` | Equipment | yes | 0 | PASS | PASS |  |  |
| 182 | `oolite.oxp.Lone_Wolf.ReduceWeaponDamage` | Mechanics | no | 0 | **NOTLOADED** | **NOTLOADED** |  | [E5](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 183 | `oolite.oxp.Lone_Wolf.ShieldCycler` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 184 | `oolite.oxp.Lone_Wolf.ShieldCyclerNext` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 185 | `oolite.oxp.Murgh.HoOpyCasino` | Dockables | yes | 0 | PASS | PASS |  |  |
| 186 | `oolite.oxp.Murgh.MilitaryFiasco` | Missions | yes | 0 | PASS | PASS |  |  |
| 187 | `oolite.oxp.Murgh.NuVipers` | Ships | yes | 0 | PASS | PASS |  |  |
| 188 | `oolite.oxp.Neelix.VacuumPump` | Equipment | yes | 0 | PASS | PASS |  |  |
| 189 | `oolite.oxp.Neelix.WaypointHere` | Equipment | yes | 0 | PASS | PASS |  |  |
| 190 | `oolite.oxp.NewtSoup.MiningIFFScannerUpgrade` | Equipment | yes | 0 | PASS | PASS |  |  |
| 191 | `oolite.oxp.Ngalo.N-Shields` | Mechanics | yes | 0 | PASS | PASS | PASS |  |
| 192 | `oolite.oxp.Ngalo.NPC_Equipment_Damage` | Mechanics | yes | 0 | PASS | PASS | PASS |  |
| 193 | `oolite.oxp.Norby.Addons_for_Beginners` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 194 | `oolite.oxp.Norby.Ambience_Collection` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 195 | `oolite.oxp.Norby.Ambiences_recommended_by_Norby` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 196 | `oolite.oxp.Norby.Andromeda` | Ships | yes | 0 | PASS | PASS |  |  |
| 197 | `oolite.oxp.Norby.Carriers` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | ERRORS |  |
| 198 | `oolite.oxp.Norby.Carriers_with_turrets` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 199 | `oolite.oxp.Norby.CombatMFD` | HUDs | yes | 0 | PASS | PASS | PASS |  |
| 200 | `oolite.oxp.Norby.Convoys` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 201 | `oolite.oxp.Norby.ConvoysB` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 202 | `oolite.oxp.Norby.Eco_Lasers` | Weapons | yes | 0 | PASS | PASS |  |  |
| 203 | `oolite.oxp.Norby.Engine_Sound` | Ambience | yes | 0 | PASS | PASS |  |  |
| 204 | `oolite.oxp.Norby.EscortDeck` | Activities | yes | 0 | PASS | PASS | PASS |  |
| 205 | `oolite.oxp.Norby.EscortPack` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 206 | `oolite.oxp.Norby.Fighters` | Weapons | yes | 0 | PASS | PASS |  |  |
| 207 | `oolite.oxp.Norby.FreighterConvoys` | Ambience | yes | 0 | PASS | PASS |  |  |
| 208 | `oolite.oxp.Norby.Gallery` | Activities | yes | 0 | PASS | PASS |  |  |
| 209 | `oolite.oxp.Norby.Gatling_Laser` | Equipment | yes | 0 | PASS | PASS |  |  |
| 210 | `oolite.oxp.Norby.HDBG` | Ambience | yes | 0 | PASS | PASS | PASS |  |
| 211 | `oolite.oxp.Norby.HDBG-A` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 212 | `oolite.oxp.Norby.HUDSelector` | HUDs | yes | 0 | PASS | PASS | PASS |  |
| 213 | `oolite.oxp.Norby.HardShips` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 214 | `oolite.oxp.Norby.Headlights` | Ambience | yes | 0 | PASS | PASS |  |  |
| 215 | `oolite.oxp.Norby.ILS` | Equipment | yes | 0 | PASS | PASS |  |  |
| 216 | `oolite.oxp.Norby.LaserCannons` | Weapons | yes | 0 | PASS | PASS |  |  |
| 217 | `oolite.oxp.Norby.Laser_Cooler` | Equipment | yes | 0 | PASS | PASS |  |  |
| 218 | `oolite.oxp.Norby.LogEvents` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 219 | `oolite.oxp.Norby.MinerCobra` | Ships | yes | 0 | PASS | PASS |  |  |
| 220 | `oolite.oxp.Norby.Multiple_Lasers` | Weapons | yes | 0 | PASS | PASS |  |  |
| 221 | `oolite.oxp.Norby.Planetfall_Markets` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 222 | `oolite.oxp.Norby.ReverseControl` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 223 | `oolite.oxp.Norby.ReverseYControl` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 224 | `oolite.oxp.Norby.SafetyCatch` | Equipment | yes | 0 | PASS | PASS |  |  |
| 225 | `oolite.oxp.Norby.SellAll` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 226 | `oolite.oxp.Norby.Separated_Lasers` | Weapons | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 227 | `oolite.oxp.Norby.ShipVersion` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 228 | `oolite.oxp.Norby.Sniper_Gun` | Weapons | yes | 0 | PASS | PASS |  |  |
| 229 | `oolite.oxp.Norby.Superhub_for_Extra_Planets` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 230 | `oolite.oxp.Norby.Telescope` | Equipment | yes | 0 | PASS | PASS |  |  |
| 231 | `oolite.oxp.Norby.Telescope_Extender` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 232 | `oolite.oxp.Norby.TheCollector` | Missions | yes | 0 | PASS | PASS |  |  |
| 233 | `oolite.oxp.Norby.TimeControl` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 234 | `oolite.oxp.Norby.TorusToSun` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 235 | `oolite.oxp.Norby.Towbar` | Activities | yes | 2 | **ERRORS** | **ERRORS** |  | [oo-1gc.15](#js-candidates) |
| 236 | `oolite.oxp.Norby.Trail_Detector` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 237 | `oolite.oxp.Norby.Trails` | Ambience | yes | 0 | PASS | PASS |  |  |
| 238 | `oolite.oxp.Norby.VariableMasslock` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 239 | `oolite.oxp.Norby.cag.Telescope` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 240 | `oolite.oxp.Norby.cag.Telescope_Extender` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 241 | `oolite.oxp.Norby.missile_booster` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 242 | `oolite.oxp.Okti.CargoScanner` | Equipment | yes | 0 | PASS | PASS |  |  |
| 243 | `oolite.oxp.Okti.Coyotes_Run` | Missions | yes | 0 | PASS | PASS |  |  |
| 244 | `oolite.oxp.Pagroove.Superhub` | Dockables | yes | 0 | PASS | PASS |  |  |
| 245 | `oolite.oxp.Pleb.TaxiGalactica` | Missions | yes | 0 | PASS | PASS |  |  |
| 246 | `oolite.oxp.QCS.QTHI_AntiZap` | Equipment | yes | 0 | PASS | PASS |  |  |
| 247 | `oolite.oxp.QCS.QTHI_AuxEnergyGenerators` | Equipment | yes | 0 | PASS | PASS |  |  |
| 248 | `oolite.oxp.Ramen.Hyperspace_Hangar` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 249 | `oolite.oxp.Ramen.Mutabilis-Ships_Library` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 250 | `oolite.oxp.Ramen.Planner` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 251 | `oolite.oxp.Ramen.Status_Quo-Ship's_Library` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 252 | `oolite.oxp.Ramirez.BlOombergMarkets` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 253 | `oolite.oxp.Ramirez.Dictators` | Systems | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 254 | `oolite.oxp.Ramirez.ExecutiveSpaceWays` | Ships | yes | 0 | PASS | PASS |  |  |
| 255 | `oolite.oxp.Ramirez.FeudalStates` | Systems | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 256 | `oolite.oxp.Ramirez.FuelTank` | Equipment | yes | 0 | PASS | PASS |  |  |
| 257 | `oolite.oxp.Ramirez.IronRaven` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 258 | `oolite.oxp.Ramirez.MissilesandBombs` | Weapons | yes | 0 | PASS | PASS |  |  |
| 259 | `oolite.oxp.Ramirez.ResistanceCommander` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 260 | `oolite.oxp.Ramirez.SalezaAeronautics` | Ships | yes | 0 | PASS | PASS |  |  |
| 261 | `oolite.oxp.Ramirez.TridentDown` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 262 | `oolite.oxp.Ranthe.MedicalAnaconda` | Ships | yes | 0 | PASS | PASS |  |  |
| 263 | `oolite.oxp.Reval.Auto_SOS` | Equipment | yes | 0 | PASS | PASS |  |  |
| 264 | `oolite.oxp.Reval.Auxiliary_Pylon` | Equipment | yes | 0 | PASS | PASS |  |  |
| 265 | `oolite.oxp.Reval.Cargo_Pods` | Equipment | yes | 0 | PASS | PASS |  |  |
| 266 | `oolite.oxp.Reval.Cargo_Space_Refit` | Equipment | yes | 0 | PASS | PASS |  |  |
| 267 | `oolite.oxp.Reval.Defence_Rider_Drones` | Weapons | yes | 0 | PASS | PASS |  |  |
| 268 | `oolite.oxp.Reval.Elite_Trader` | Mechanics | yes | 3 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 269 | `oolite.oxp.Reval.Elite_Trader_Meta` | Mechanics | yes | 2 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 270 | `oolite.oxp.Reval.FE_Ships` | Ships | yes | 0 | PASS | PASS |  |  |
| 271 | `oolite.oxp.Reval.FE_Ships_Player` | Ships | yes | 0 | PASS | PASS |  |  |
| 272 | `oolite.oxp.Reval.GETTER_HUD` | HUDs | yes | 1 | **ERRORS** | **ERRORS** |  | [E3](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 273 | `oolite.oxp.Reval.Goods_Containers` | Equipment | yes | 0 | PASS | PASS |  |  |
| 274 | `oolite.oxp.Reval.Merchanters_Zeal` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 275 | `oolite.oxp.Reval.More_Moolah` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 276 | `oolite.oxp.Reval.Neutralizer` | Weapons | yes | 1 | **ERRORS** | **ERRORS** |  | [E4](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 277 | `oolite.oxp.Reval.Overdrive` | Equipment | yes | 0 | PASS | PASS |  |  |
| 278 | `oolite.oxp.Reval.PT-BVR-Missile` | Weapons | yes | 0 | PASS | PASS |  |  |
| 279 | `oolite.oxp.Reval.Partner_Trader` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 280 | `oolite.oxp.Reval.Small_Ships` | Ships | yes | 0 | PASS | PASS |  |  |
| 281 | `oolite.oxp.Reval.Teleportation_Drive` | Equipment | yes | 0 | PASS | PASS |  |  |
| 282 | `oolite.oxp.Reval.Tractor-Tow` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 283 | `oolite.oxp.Reval.Witch-Charger` | Equipment | yes | 0 | PASS | PASS |  |  |
| 284 | `oolite.oxp.RobertTodd.Taranis` | Missions | yes | 2 | **ERRORS** | **ERRORS** |  | [oo-1gc.15](#js-candidates) |
| 285 | `oolite.oxp.Robin.Sonoran` | Ships | yes | 0 | PASS | PASS |  |  |
| 286 | `oolite.oxp.Rorschachhamster.Satellites` | Ambience | yes | 0 | PASS | PASS |  |  |
| 287 | `oolite.oxp.Rustem.DistantStar` | Ambience | yes | 0 | PASS | PASS |  |  |
| 288 | `oolite.oxp.Rustem.MilitaryShields_Ships` | Ships | yes | 0 | PASS | PASS |  |  |
| 289 | `oolite.oxp.Rustem.Q_bomb_AI` | Weapons | yes | 0 | PASS | PASS |  |  |
| 290 | `oolite.oxp.Rustem.Sniper_Gun_rebalancer` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 291 | `oolite.oxp.Rxke.BlackBaron` | Missions | yes | 0 | PASS | PASS |  |  |
| 292 | `oolite.oxp.SMax.AsteroidRandomizer` | Ambience | yes | 0 | PASS | PASS |  |  |
| 293 | `oolite.oxp.SMax.AsteroidRemover` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 294 | `oolite.oxp.SMax.FuelGenerator` | Equipment | yes | 0 | PASS | PASS |  |  |
| 295 | `oolite.oxp.SMax.MFDRestoreAfterLoad` | HUDs | yes | 0 | PASS | PASS |  |  |
| 296 | `oolite.oxp.SMax.PlanetFallMarketSaver` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 297 | `oolite.oxp.SMax.RRSBlackBoxHC` | HUDs | yes | 0 | PASS | PASS |  |  |
| 298 | `oolite.oxp.SMax.ZeroMap` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 299 | `oolite.oxp.Selezen.SpyHunter` | Missions | yes | 0 | PASS | PASS |  |  |
| 300 | `oolite.oxp.Selezen.impcourier2` | Ships | yes | 0 | PASS | PASS |  |  |
| 301 | `oolite.oxp.Shipbuilder.ArachnidMark1` | Ships | yes | 6 | **ERRORS** | **ERRORS** |  | [E2](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 302 | `oolite.oxp.Shipbuilder.ChimeraGunship` | Ships | yes | 0 | PASS | **ERRORS** |  | [E2](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 303 | `oolite.oxp.Shipbuilder.ConstitutionClassHeavyCruiser` | Ships | yes | 0 | PASS | PASS |  |  |
| 304 | `oolite.oxp.Shipbuilder.CylonRaiderMk1` | Ships | yes | 0 | PASS | PASS |  |  |
| 305 | `oolite.oxp.Shipbuilder.Fireball` | Ships | yes | 0 | PASS | **ERRORS** |  | [E2](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 306 | `oolite.oxp.Shipbuilder.GalTechEscapePods` | Ships | yes | 0 | PASS | PASS |  |  |
| 307 | `oolite.oxp.Shipbuilder.GalTechEscortFighter` | Ships | yes | 0 | PASS | PASS |  |  |
| 308 | `oolite.oxp.Shipbuilder.SerpentClassCruiser` | Ships | yes | 10 | **ERRORS** | **ERRORS** |  | [E2](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 309 | `oolite.oxp.Staer9.Icesteroids` | Ambience | yes | 0 | PASS | PASS |  |  |
| 310 | `oolite.oxp.Storm.TionislaChronicleArray` | Dockables | yes | 0 | PASS | PASS |  |  |
| 311 | `oolite.oxp.Stormrider.Stormbrewer` | Ships | yes | 0 | PASS | PASS |  |  |
| 312 | `oolite.oxp.Strato1.MoreEscapePods` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 313 | `oolite.oxp.Svengali.BGS` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 314 | `oolite.oxp.Svengali.CCL` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 315 | `oolite.oxp.Svengali.Eric.BuoyRepair` | Ambience | yes | 0 | PASS | PASS |  |  |
| 316 | `oolite.oxp.Svengali.FarstarMurderer` | Ships | yes | 0 | PASS | PASS |  |  |
| 317 | `oolite.oxp.Svengali.GNN` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 318 | `oolite.oxp.Svengali.HyperRadio2` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 319 | `oolite.oxp.Svengali.Hyperradio` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 320 | `oolite.oxp.Svengali.HyperradioAFC01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 321 | `oolite.oxp.Svengali.HyperradioHH01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 322 | `oolite.oxp.Svengali.HyperradioJFRG01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 323 | `oolite.oxp.Svengali.HyperradioPSY01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 324 | `oolite.oxp.Svengali.HyperradioST01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 325 | `oolite.oxp.Svengali.HyperradioST02` | Ambience | yes | 0 | PASS | PASS |  |  |
| 326 | `oolite.oxp.Svengali.HyperradioTN01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 327 | `oolite.oxp.Svengali.Library` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 328 | `oolite.oxp.Svengali.OXPConfig` | Miscellaneous | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 329 | `oolite.oxp.Svengali.Pagroove.BGSSoundset` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 330 | `oolite.oxp.Svengali.Snoopers` | Ambience | yes | 12 | **ERRORS** | **ERRORS** |  | [oo-1gc.14](#js-candidates) |
| 331 | `oolite.oxp.Switeck.Auto-ECM` | Equipment | yes | 0 | PASS | PASS |  |  |
| 332 | `oolite.oxp.Switeck.Cargo-Contract-Mod` | Activities | yes | 0 | PASS | PASS |  |  |
| 333 | `oolite.oxp.Thargoid.APRIL` | Equipment | yes | 0 | PASS | PASS |  |  |
| 334 | `oolite.oxp.Thargoid.Aquatics` | Ships | yes | 3 | **ERRORS** | PASS |  | [oo-1gc.16](#js-candidates) |
| 335 | `oolite.oxp.Thargoid.Armoury` | Weapons | yes | 0 | PASS | PASS |  |  |
| 336 | `oolite.oxp.Thargoid.Bigships` | Mechanics | yes | 0 | PASS | PASS | PASS |  |
| 337 | `oolite.oxp.Thargoid.CargoShepherd` | Equipment | yes | 0 | PASS | PASS |  |  |
| 338 | `oolite.oxp.Thargoid.CargoSpotter` | Equipment | yes | 0 | PASS | PASS |  |  |
| 339 | `oolite.oxp.Thargoid.CommandersLog` | Equipment | yes | 0 | PASS | PASS |  |  |
| 340 | `oolite.oxp.Thargoid.EnergyEquipment` | Equipment | yes | 0 | PASS | PASS |  |  |
| 341 | `oolite.oxp.Thargoid.EscapePodLocator` | Equipment | yes | 0 | PASS | PASS |  |  |
| 342 | `oolite.oxp.Thargoid.FlightLog` | Equipment | yes | 0 | PASS | PASS |  |  |
| 343 | `oolite.oxp.Thargoid.FuelStation` | Activities | yes | 0 | PASS | PASS |  |  |
| 344 | `oolite.oxp.Thargoid.Gates` | Activities | yes | 0 | PASS | PASS |  |  |
| 345 | `oolite.oxp.Thargoid.HiredGuns` | Weapons | yes | 0 | PASS | PASS |  |  |
| 346 | `oolite.oxp.Thargoid.HyperCargo` | Equipment | yes | 0 | PASS | PASS |  |  |
| 347 | `oolite.oxp.Thargoid.IronHide` | Equipment | yes | 0 | PASS | PASS |  |  |
| 348 | `oolite.oxp.Thargoid.LaserBooster` | Equipment | yes | 0 | PASS | PASS |  |  |
| 349 | `oolite.oxp.Thargoid.LaveAcademy` | Dockables | yes | 0 | PASS | PASS |  |  |
| 350 | `oolite.oxp.Thargoid.Lazarus` | Ships | yes | 0 | PASS | PASS |  |  |
| 351 | `oolite.oxp.Thargoid.MilFuelInj` | Equipment | yes | 0 | PASS | PASS |  |  |
| 352 | `oolite.oxp.Thargoid.Neo-Docklights` | Equipment | yes | 0 | PASS | PASS |  |  |
| 353 | `oolite.oxp.Thargoid.OoCheat` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 354 | `oolite.oxp.Thargoid.PlanetFall2_BlackMonks` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 355 | `oolite.oxp.Thargoid.PlanetFall2_HOopyCasino` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 356 | `oolite.oxp.Thargoid.PlanetFall2_Oo-Haul` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 357 | `oolite.oxp.Thargoid.PlanetaryCompass` | Equipment | yes | 0 | PASS | PASS | PASS |  |
| 358 | `oolite.oxp.Thargoid.PlanetaryCompassPackA` | Equipment | yes | 0 | PASS | PASS |  |  |
| 359 | `oolite.oxp.Thargoid.PlanetaryCompassPackB` | Equipment | yes | 0 | PASS | PASS |  |  |
| 360 | `oolite.oxp.Thargoid.PlanetaryCompassPackC` | Equipment | yes | 0 | PASS | PASS |  |  |
| 361 | `oolite.oxp.Thargoid.PlanetaryCompassPackD` | Equipment | yes | 0 | PASS | PASS |  |  |
| 362 | `oolite.oxp.Thargoid.Planetfall` | Systems | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS | PASS |  |
| 363 | `oolite.oxp.Thargoid.Pods` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 364 | `oolite.oxp.Thargoid.RealisticDamage` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 365 | `oolite.oxp.Thargoid.RepairBots` | Equipment | yes | 0 | PASS | PASS |  |  |
| 366 | `oolite.oxp.Thargoid.RetroRockets` | Equipment | yes | 0 | PASS | PASS |  |  |
| 367 | `oolite.oxp.Thargoid.RingRacer` | Activities | yes | 0 | PASS | PASS |  |  |
| 368 | `oolite.oxp.Thargoid.SecondWave` | Ships | yes | 0 | PASS | PASS |  |  |
| 369 | `oolite.oxp.Thargoid.Stealth` | Missions | yes | 0 | PASS | PASS |  |  |
| 370 | `oolite.oxp.Thargoid.StellarSerpents` | Missions | yes | 0 | PASS | PASS |  |  |
| 371 | `oolite.oxp.Thargoid.Swarm` | Ships | yes | 0 | PASS | PASS |  |  |
| 372 | `oolite.oxp.Thargoid.TAP` | Equipment | yes | 0 | PASS | PASS |  |  |
| 373 | `oolite.oxp.Thargoid.TCAT` | Missions | yes | 0 | PASS | PASS |  |  |
| 374 | `oolite.oxp.Thargoid.Tracker` | Equipment | yes | 0 | PASS | PASS |  |  |
| 375 | `oolite.oxp.Thargoid.TrackerCam` | Equipment | yes | 0 | PASS | PASS |  |  |
| 376 | `oolite.oxp.Thargoid.TrafficControl` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 377 | `oolite.oxp.Thargoid.Vortex` | Ships | yes | 0 | PASS | PASS |  |  |
| 378 | `oolite.oxp.Thargoid.WelcomeMat` | Equipment | yes | 0 | PASS | PASS |  |  |
| 379 | `oolite.oxp.Thargoid.Wildships` | Dockables | yes | 0 | PASS | PASS |  |  |
| 380 | `oolite.oxp.Thargoid.YAH-ConstoreRemover` | Ambience | yes | 0 | PASS | PASS |  |  |
| 381 | `oolite.oxp.Thargoid.YAH-Mobile` | Ambience | yes | 0 | PASS | PASS |  |  |
| 382 | `oolite.oxp.Thargoid.YAH-WitchpointOverride` | Ambience | yes | 0 | PASS | PASS |  |  |
| 383 | `oolite.oxp.ThetaSeven.TAURockhopper` | Ships | yes | 0 | PASS | PASS |  |  |
| 384 | `oolite.oxp.Tricky.Jaguar_Company` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 385 | `oolite.oxp.Turret_Toggler` | Equipment | yes | 0 | PASS | PASS |  |  |
| 386 | `oolite.oxp.UK_Eliter.ExtraThargoids` | Ships | yes | 0 | PASS | PASS |  |  |
| 387 | `oolite.oxp.UK_Eliter.Ferdelance_3G` | Ships | yes | 0 | PASS | PASS |  |  |
| 388 | `oolite.oxp.UK_Eliter.HarderHermits` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 389 | `oolite.oxp.UK_Eliter.InterstellarTweaks` | Mechanics | yes | 2 | **ERRORS** | **ERRORS** |  | [oo-1gc.15](#js-candidates) |
| 390 | `oolite.oxp.UK_Eliter.NexusMissile` | Weapons | yes | 0 | PASS | PASS |  |  |
| 391 | `oolite.oxp.UK_Eliter.SuperSidewinder` | Ships | yes | 0 | PASS | PASS |  |  |
| 392 | `oolite.oxp.Vincentz.3dFont` | Ambience | yes | 0 | PASS | PASS |  |  |
| 393 | `oolite.oxp.Vincentz.NovaLuxHUD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 394 | `oolite.oxp.Wildeblood.AutoCrosshairs` | Equipment | yes | 0 | PASS | PASS |  |  |
| 395 | `oolite.oxp.Wildeblood.BulletDrive` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 396 | `oolite.oxp.Wildeblood.Contracted_Goods_Reminder` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 397 | `oolite.oxp.Wildeblood.Display_Reputation` | Ambience | yes | 0 | PASS | PASS |  |  |
| 398 | `oolite.oxp.Wildeblood.DistantSpace` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 399 | `oolite.oxp.Wildeblood.Distant_Locales` | Ambience | yes | 0 | PASS | PASS |  |  |
| 400 | `oolite.oxp.Wildeblood.Distant_Realms` | Ambience | yes | 0 | PASS | PASS |  |  |
| 401 | `oolite.oxp.Wildeblood.Distant_Realms_US` | Ambience | yes | 0 | PASS | PASS |  |  |
| 402 | `oolite.oxp.Wildeblood.Distant_Space` | Ambience | yes | 0 | PASS | PASS |  |  |
| 403 | `oolite.oxp.Wildeblood.Distant_Thunder` | Ambience | yes | 0 | PASS | PASS |  |  |
| 404 | `oolite.oxp.Wildeblood.GalacticHyperdrive` | Equipment | yes | 0 | PASS | PASS |  |  |
| 405 | `oolite.oxp.Wildeblood.GlareClarifier` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 406 | `oolite.oxp.Wildeblood.LaserificCrosshairs` | HUDs | yes | 0 | PASS | PASS |  |  |
| 407 | `oolite.oxp.Wildeblood.SEX_Drive` | Cheats | yes | 0 | PASS | PASS |  |  |
| 408 | `oolite.oxp.Wildeblood.ShieldtasticCrosshairs` | HUDs | yes | 0 | PASS | PASS |  |  |
| 409 | `oolite.oxp.Wildeblood.Station_Self_Destruction` | Equipment | yes | 0 | PASS | PASS |  |  |
| 410 | `oolite.oxp.Wildeblood.UndocumentedLaunch` | Equipment | yes | 0 | PASS | PASS |  |  |
| 411 | `oolite.oxp.Wildeblood.Undocumented_Launch` | Equipment | yes | 0 | PASS | PASS |  |  |
| 412 | `oolite.oxp.Wildeblood.Untrumbled` | Mechanics | yes | 2 | **ERRORS** | **ERRORS** |  | [oo-1gc.15](#js-candidates) |
| 413 | `oolite.oxp.Wildeblood.alerting_crosshairs` | Equipment | yes | 0 | PASS | PASS |  |  |
| 414 | `oolite.oxp.Wildeblood.distant_suns` | Ambience | yes | 0 | PASS | PASS |  |  |
| 415 | `oolite.oxp.Wildeblood.galaxy_names` | Ambience | yes | 0 | PASS | PASS |  |  |
| 416 | `oolite.oxp.Wildeblood.interfaces_screen` | Ambience | yes | 0 | PASS | PASS |  |  |
| 417 | `oolite.oxp.Zafrusteria.ShrewsRights` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 418 | `oolite.oxp.Zireael.FontStandalone` | Ambience | yes | 0 | PASS | PASS |  |  |
| 419 | `oolite.oxp.ZygoUgo.Asteroids_resources` | Ambience | yes | 0 | PASS | PASS |  |  |
| 420 | `oolite.oxp.ZygoUgo.Buoy` | Ambience | yes | 0 | PASS | PASS |  |  |
| 421 | `oolite.oxp.ZygoUgo.Explosions` | Ambience | yes | 0 | PASS | PASS |  |  |
| 422 | `oolite.oxp.ZygoUgo.ZygoCinematicSkyNebulas` | Ambience | yes | 0 | PASS | PASS |  |  |
| 423 | `oolite.oxp.ZygoUgo.noshaders_Asteroids` | Ambience | yes | 2 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 424 | `oolite.oxp.ZygoUgo.shadyAsteroids` | Ambience | yes | 2 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 425 | `oolite.oxp.ace_56.Cruzer` | Ships | yes | 0 | PASS | PASS |  |  |
| 426 | `oolite.oxp.ace_56.Hornet` | Ships | yes | 0 | PASS | PASS |  |  |
| 427 | `oolite.oxp.ace_56.NightAdder` | Ships | yes | 0 | PASS | PASS |  |  |
| 428 | `oolite.oxp.aegidian.LongWayRound` | Missions | yes | 0 | PASS | PASS |  |  |
| 429 | `oolite.oxp.amah.noshaders_Mimoriarty_rl_ships` | Retextures | yes | 0 | PASS | PASS |  |  |
| 430 | `oolite.oxp.amah.noshaders_Mimoriarty_rl_yasenturret_upgrade` | Equipment | yes | 0 | PASS | PASS |  |  |
| 431 | `oolite.oxp.amah.noshaders_ZGrOovy_extraships` | Retextures | yes | 0 | PASS | PASS |  |  |
| 432 | `oolite.oxp.amah.noshaders_ZGrOovy_varietypacks` | Retextures | yes | 0 | PASS | PASS |  |  |
| 433 | `oolite.oxp.amah.noshaders_accessories` | Retextures | yes | 20 | **ERRORS** | **ERRORS** |  | [oo-1gc.13](#js-candidates) |
| 434 | `oolite.oxp.amah.noshaders_accessories_chunky_explosions` | Retextures | yes | 20 | **ERRORS** | **ERRORS** |  | [oo-1gc.13](#js-candidates) |
| 435 | `oolite.oxp.amah.noshaders_accessories_replace` | Retextures | yes | 0 | PASS | PASS |  |  |
| 436 | `oolite.oxp.amah.noshaders_alternateships` | Retextures | yes | 0 | PASS | PASS |  |  |
| 437 | `oolite.oxp.amah.noshaders_alternatestations` | Retextures | yes | 0 | PASS | PASS |  |  |
| 438 | `oolite.oxp.amah.noshaders_extra_stations_addon` | Retextures | yes | 2 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 439 | `oolite.oxp.amah.noshaders_extra_stations_resources` | Retextures | yes | 0 | PASS | PASS |  |  |
| 440 | `oolite.oxp.amah.noshaders_extraships` | Retextures | yes | 0 | PASS | PASS |  |  |
| 441 | `oolite.oxp.amah.noshaders_missingcoreships` | Retextures | yes | 0 | PASS | PASS |  |  |
| 442 | `oolite.oxp.amah.noshaders_staer9_chopped_cobra` | Ships | yes | 0 | PASS | PASS |  |  |
| 443 | `oolite.oxp.amah.noshaders_staer9_shipset` | Ships | yes | 0 | PASS | PASS |  |  |
| 444 | `oolite.oxp.amah.noshaders_stations_for_sfep` | Retextures | yes | 16 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 445 | `oolite.oxp.amah.noshaders_stations_fullsize-textures` | Retextures | yes | 0 | PASS | PASS |  |  |
| 446 | `oolite.oxp.another_commander.188NSGMaps` | Retextures | yes | 0 | PASS | PASS |  |  |
| 447 | `oolite.oxp.another_commander.DisoIsJupiter8k` | Ambience | yes | 0 | PASS | PASS |  |  |
| 448 | `oolite.oxp.another_commander.LaveIsEarth8k` | Ambience | yes | 0 | PASS | PASS |  |  |
| 449 | `oolite.oxp.another_commander.TionislaIsMars8k` | Ambience | yes | 0 | PASS | PASS |  |  |
| 450 | `oolite.oxp.another_commander.WOOT_Attack` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 451 | `oolite.oxp.another_commander.ZaonceIsVenus8k` | Ambience | yes | 0 | PASS | PASS |  |  |
| 452 | `oolite.oxp.astrobe.compassautoswitch` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 453 | `oolite.oxp.astrobe.missiles` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 454 | `oolite.oxp.astrobe.spacecrowds` | Activities | yes | 0 | PASS | PASS |  |  |
| 455 | `oolite.oxp.blackwolf.wanted_posters` | Ambience | yes | 0 | PASS | PASS |  |  |
| 456 | `oolite.oxp.cag.station_options` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 457 | `oolite.oxp.cag.telescope_StationOptions.oxp` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 458 | `oolite.oxp.capt_murphy.Illegal_Goods_Tweak` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 459 | `oolite.oxp.captain_beatnik.Pitviper` | Ships | yes | 0 | PASS | PASS |  |  |
| 460 | `oolite.oxp.captain_beatnik.Pitviper2` | Ships | yes | 0 | PASS | PASS |  |  |
| 461 | `oolite.oxp.captain_beatnik.Riredi` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 462 | `oolite.oxp.captain_beatnik.coluber_hud_ch01` | HUDs | yes | 0 | PASS | PASS |  |  |
| 463 | `oolite.oxp.captkev.fighter_hud2` | HUDs | yes | 0 | PASS | PASS |  |  |
| 464 | `oolite.oxp.captsolo.copperhead21.1` | Ships | yes | 0 | PASS | PASS |  |  |
| 465 | `oolite.oxp.captsolo.cougar_st1.5` | Ships | yes | 0 | PASS | PASS |  |  |
| 466 | `oolite.oxp.captsolo.i-missile1.15` | Equipment | yes | 0 | PASS | PASS |  |  |
| 467 | `oolite.oxp.captsolo.simonb's_ships1.0` | Ships | yes | 0 | PASS | PASS |  |  |
| 468 | `oolite.oxp.captsolo.solos-good-fortune` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 469 | `oolite.oxp.captsolo.tori2.02` | Dockables | yes | 0 | PASS | PASS |  |  |
| 470 | `oolite.oxp.cheyd.DHI_nav_buoy` | Retextures | yes | 0 | PASS | PASS |  |  |
| 471 | `oolite.oxp.cim.camera-drones` | Equipment | yes | 0 | PASS | PASS |  |  |
| 472 | `oolite.oxp.cim.combat-simulator` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 473 | `oolite.oxp.cim.comms-pack-a` | Ambience | yes | 0 | PASS | PASS |  |  |
| 474 | `oolite.oxp.cim.cotbs` | Missions | yes | 0 | PASS | PASS |  |  |
| 475 | `oolite.oxp.cim.energy-bomb` | Weapons | yes | 0 | PASS | PASS |  |  |
| 476 | `oolite.oxp.cim.escort-formations` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 477 | `oolite.oxp.cim.extracts-tre-clan` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 478 | `oolite.oxp.cim.new-cargoes` | Mechanics | yes | 2 | **ERRORS** | **ERRORS** |  | [E1](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 479 | `oolite.oxp.cim.ships-library` | Equipment | yes | 0 | PASS | PASS | PASS |  |
| 480 | `oolite.oxp.cim.shipset-compatibility` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 481 | `oolite.oxp.cim.skilled-npcs` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 482 | `oolite.oxp.cim.systemfeatures.sunspots` | Ambience | yes | 0 | PASS | PASS |  |  |
| 483 | `oolite.oxp.cody.green-gecko-xl` | Ships | yes | 0 | PASS | PASS |  |  |
| 484 | `oolite.oxp.davidkroc.Sidewinder-ng` | Ships | yes | 0 | PASS | PASS |  |  |
| 485 | `oolite.oxp.dertien.Z_GrOovY_SmallSystemStations` | Dockables | yes | 0 | PASS | PASS |  |  |
| 486 | `oolite.oxp.dybal.ArachnidMark1_Fix` | Ships | yes | 0 | PASS | PASS |  |  |
| 487 | `oolite.oxp.dybal.BarrelRoll` | Equipment | yes | 0 | PASS | PASS |  |  |
| 488 | `oolite.oxp.dybal.Fireball_Fix` | Ships | yes | 0 | PASS | PASS |  |  |
| 489 | `oolite.oxp.dybal.NPC_Energy_Units` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 490 | `oolite.oxp.dybal.SaveInFlight` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 491 | `oolite.oxp.dybal.SerpentClassCruiser_Fix` | Ships | yes | 0 | PASS | PASS |  |  |
| 492 | `oolite.oxp.dybal.SniperLockPlus` | Equipment | yes | 0 | PASS | PASS |  |  |
| 493 | `oolite.oxp.dybal.SniperLock_Fix` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 494 | `oolite.oxp.dybal.rockHermitBeacons` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 495 | `oolite.oxp.dybal.towbarPayout-Medium` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 496 | `oolite.oxp.edgepixel.FontDangerousSquare` | Ambience | yes | 0 | PASS | PASS |  |  |
| 497 | `oolite.oxp.edgepixel.FontDosis` | Ambience | yes | 0 | PASS | PASS |  |  |
| 498 | `oolite.oxp.hoqllnq.missile-beep` | Ambience | yes | 0 | PASS | PASS |  |  |
| 499 | `oolite.oxp.jh145.ScannerAlertingEnhancement` | Equipment | yes | 0 | PASS | PASS |  |  |
| 500 | `oolite.oxp.littlebear.blackmonks` | Activities | yes | 0 | PASS | PASS |  |  |
| 501 | `oolite.oxp.maik.beercooler` | Equipment | yes | 0 | PASS | PASS |  |  |
| 502 | `oolite.oxp.milo.derelicts_dont_count` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 503 | `oolite.oxp.mils32k.EnergyContainmentUnit` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 504 | `oolite.oxp.murgh.GlobeStation` | Dockables | yes | 0 | PASS | PASS |  |  |
| 505 | `oolite.oxp.murgh.Lave` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 506 | `oolite.oxp.nicholasmenchise.target-system-plugins` | Equipment | yes | 0 | PASS | PASS |  |  |
| 507 | `oolite.oxp.nicksta.primeable-equipment-mfd` | HUDs | yes | 0 | PASS | PASS |  |  |
| 508 | `oolite.oxp.ocz.InSystemTrader` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 509 | `oolite.oxp.ocz.SUWitchdrive` | Equipment | yes | 0 | PASS | PASS |  |  |
| 510 | `oolite.oxp.phkb.AnacondaCruiseLiners` | Ships | yes | 0 | PASS | PASS |  |  |
| 511 | `oolite.oxp.phkb.Anarchies_Facelift` | Systems | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 512 | `oolite.oxp.phkb.AutoDock` | Equipment | yes | 0 | PASS | PASS |  |  |
| 513 | `oolite.oxp.phkb.AutoPrimeEquipment` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 514 | `oolite.oxp.phkb.Behemoth_Facelift` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 515 | `oolite.oxp.phkb.BlackMarket` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 516 | `oolite.oxp.phkb.BountySystem` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 517 | `oolite.oxp.phkb.BroadcastCommsMFD` | HUDs | yes | 0 | PASS | PASS | PASS |  |
| 518 | `oolite.oxp.phkb.BulkCargoProcessor` | Equipment | yes | 0 | PASS | PASS |  |  |
| 519 | `oolite.oxp.phkb.BulletinBoardSystem` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 520 | `oolite.oxp.phkb.ChangeViewSound` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 521 | `oolite.oxp.phkb.CommsLogMFD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 522 | `oolite.oxp.phkb.CompressedF7Layout` | Miscellaneous | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 523 | `oolite.oxp.phkb.ConsoleLogMFD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 524 | `oolite.oxp.phkb.ContextualHelp` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 525 | `oolite.oxp.phkb.ContractsOnBB` | Miscellaneous | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 526 | `oolite.oxp.phkb.DamageReportMFD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 527 | `oolite.oxp.phkb.DeathComms` | Ambience | yes | 0 | PASS | PASS |  |  |
| 528 | `oolite.oxp.phkb.DeepSpaceDredgers_Facelift` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 529 | `oolite.oxp.phkb.DisplayCurrentCourse` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 530 | `oolite.oxp.phkb.EmailSystemDemo` | Missions | yes | 0 | PASS | PASS |  |  |
| 531 | `oolite.oxp.phkb.EnhancedPassengerContracts` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 532 | `oolite.oxp.phkb.EquipmentRemoveItemColor` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 533 | `oolite.oxp.phkb.EquipmentStorage` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 534 | `oolite.oxp.phkb.EscapePodTweaks` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 535 | `oolite.oxp.phkb.ExpandedWeaponInfo` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 536 | `oolite.oxp.phkb.ExternalDockSystem` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 537 | `oolite.oxp.phkb.ExtraRockHermits` | Dockables | yes | 0 | PASS | PASS |  |  |
| 538 | `oolite.oxp.phkb.FactoryPaintJobs_Adder` | Retextures | yes | 0 | PASS | PASS |  |  |
| 539 | `oolite.oxp.phkb.FactoryPaintJobs_Anaconda` | Retextures | yes | 0 | PASS | PASS |  |  |
| 540 | `oolite.oxp.phkb.FactoryPaintJobs_AspMk2` | Retextures | yes | 0 | PASS | PASS |  |  |
| 541 | `oolite.oxp.phkb.FactoryPaintJobs_Boa` | Retextures | yes | 0 | PASS | PASS |  |  |
| 542 | `oolite.oxp.phkb.FactoryPaintJobs_BoaMk2` | Retextures | yes | 0 | PASS | PASS |  |  |
| 543 | `oolite.oxp.phkb.FactoryPaintJobs_CobraMkI` | Retextures | yes | 0 | PASS | PASS |  |  |
| 544 | `oolite.oxp.phkb.FactoryPaintJobs_Ferdelance` | Retextures | yes | 0 | PASS | PASS |  |  |
| 545 | `oolite.oxp.phkb.FactoryPaintJobs_Gecko` | Retextures | yes | 0 | PASS | PASS |  |  |
| 546 | `oolite.oxp.phkb.FactoryPaintJobs_Krait` | Retextures | yes | 0 | PASS | PASS |  |  |
| 547 | `oolite.oxp.phkb.FactoryPaintJobs_Mamba` | Retextures | yes | 0 | PASS | PASS |  |  |
| 548 | `oolite.oxp.phkb.FactoryPaintJobs_Moray` | Retextures | yes | 0 | PASS | PASS |  |  |
| 549 | `oolite.oxp.phkb.FactoryPaintJobs_Python` | Retextures | yes | 0 | PASS | PASS |  |  |
| 550 | `oolite.oxp.phkb.FactoryPaintJobs_Sidewinder` | Retextures | yes | 0 | PASS | PASS |  |  |
| 551 | `oolite.oxp.phkb.FastTargetSelector` | Equipment | yes | 0 | PASS | PASS |  |  |
| 552 | `oolite.oxp.phkb.FeudalPlanetFall` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 553 | `oolite.oxp.phkb.FontDiscognate` | Ambience | yes | 0 | PASS | PASS |  |  |
| 554 | `oolite.oxp.phkb.FontNovaSquare` | Ambience | yes | 0 | PASS | PASS |  |  |
| 555 | `oolite.oxp.phkb.FontOCRAExtended` | Ambience | yes | 0 | PASS | PASS |  |  |
| 556 | `oolite.oxp.phkb.FontXolonium` | Ambience | yes | 0 | PASS | PASS |  |  |
| 557 | `oolite.oxp.phkb.FuelInjectionCruiseControl` | Equipment | yes | 0 | PASS | PASS |  |  |
| 558 | `oolite.oxp.phkb.FuelStation_Facelift` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 559 | `oolite.oxp.phkb.FuelTweaks` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 560 | `oolite.oxp.phkb.GalCopMissions` | Missions | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 561 | `oolite.oxp.phkb.GalacticRegistry` | Ambience | yes | 0 | PASS | PASS |  |  |
| 562 | `oolite.oxp.phkb.GriffClippers` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 563 | `oolite.oxp.phkb.HomeSystem` | Ambience | yes | 0 | PASS | PASS |  |  |
| 564 | `oolite.oxp.phkb.HyperradioCJ01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 565 | `oolite.oxp.phkb.HyperradioCLS01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 566 | `oolite.oxp.phkb.HyperradioLOFI01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 567 | `oolite.oxp.phkb.HyperradioROCK01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 568 | `oolite.oxp.phkb.HyperradioST03` | Ambience | yes | 0 | PASS | PASS |  |  |
| 569 | `oolite.oxp.phkb.HyperradioSYN01` | Ambience | yes | 0 | PASS | PASS |  |  |
| 570 | `oolite.oxp.phkb.IllicitUnlock` | Ships | yes | 0 | PASS | PASS |  |  |
| 571 | `oolite.oxp.phkb.LMSS` | Equipment | yes | 0 | PASS | PASS |  |  |
| 572 | `oolite.oxp.phkb.LaserArrangement` | Equipment | yes | 0 | PASS | PASS |  |  |
| 573 | `oolite.oxp.phkb.LaveInitialShipyard` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 574 | `oolite.oxp.phkb.LinersMarkets` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 575 | `oolite.oxp.phkb.LoadoutByCategory` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 576 | `oolite.oxp.phkb.LoadoutByCategory190` | Miscellaneous | no | 0 | **NOTLOADED** | **NOTLOADED** |  | [E5](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 577 | `oolite.oxp.phkb.MFDFastConfiguration` | HUDs | yes | 0 | PASS | PASS |  |  |
| 578 | `oolite.oxp.phkb.MaintenanceTuneUp` | Equipment | yes | 0 | PASS | PASS |  |  |
| 579 | `oolite.oxp.phkb.ManualWitchspaceAlignment` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 580 | `oolite.oxp.phkb.MarketScreenLegalColumn` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 581 | `oolite.oxp.phkb.MarketScriptInterface` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 582 | `oolite.oxp.phkb.MissileSummary` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 583 | `oolite.oxp.phkb.ModernStart` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 584 | `oolite.oxp.phkb.NavigationBeaconsMFD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 585 | `oolite.oxp.phkb.NightAdder_EscortDeck` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 586 | `oolite.oxp.phkb.NoMarketNotification` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 587 | `oolite.oxp.phkb.PitviperMarkII_Facelift` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 588 | `oolite.oxp.phkb.PlanetFall2_ResourcesA` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 589 | `oolite.oxp.phkb.PlanetFall2_ResourcesB` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 590 | `oolite.oxp.phkb.PlanetForestsAndOceans` | Ambience | yes | 0 | PASS | PASS |  |  |
| 591 | `oolite.oxp.phkb.PlanetRotationCosmetics` | Ambience | yes | 0 | PASS | PASS |  |  |
| 592 | `oolite.oxp.phkb.QMine_Facelift` | Retextures | yes | 0 | PASS | PASS |  |  |
| 593 | `oolite.oxp.phkb.QuickVisa` | Miscellaneous | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 594 | `oolite.oxp.phkb.QuiriumCascadeBomb` | Weapons | yes | 0 | PASS | PASS |  |  |
| 595 | `oolite.oxp.phkb.RemoveIndividualPylon` | Equipment | yes | 0 | PASS | PASS |  |  |
| 596 | `oolite.oxp.phkb.RiskyBusiness` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 597 | `oolite.oxp.phkb.RoughGuideToTheOoniverse` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 598 | `oolite.oxp.phkb.ShipComparison` | Ambience | yes | 0 | PASS | PASS |  |  |
| 599 | `oolite.oxp.phkb.ShipConfiguration` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 600 | `oolite.oxp.phkb.ShipRepurchase` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 601 | `oolite.oxp.phkb.ShipRespray` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 602 | `oolite.oxp.phkb.SiliconeSealant` | Equipment | yes | 0 | PASS | PASS |  |  |
| 603 | `oolite.oxp.phkb.Smugglers_TGU` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 604 | `oolite.oxp.phkb.SolarFlares` | Ambience | yes | 0 | PASS | PASS |  |  |
| 605 | `oolite.oxp.phkb.SpacebarFacelift` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 606 | `oolite.oxp.phkb.SuperSystem` | Dockables | yes | 0 | PASS | PASS |  |  |
| 607 | `oolite.oxp.phkb.SystemDataConfig` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 608 | `oolite.oxp.phkb.SystemMap` | Miscellaneous | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 609 | `oolite.oxp.phkb.TionislaOrbitalGraveyard` | Ambience | yes | 0 | PASS | PASS | PASS |  |
| 610 | `oolite.oxp.phkb.TionislaOrbitalGraveyard_Memorials` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 611 | `oolite.oxp.phkb.TionislaOrbitalGraveyard_Monuments` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 612 | `oolite.oxp.phkb.TionislaOrbitalGraveyard_Shipwrecks` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 613 | `oolite.oxp.phkb.VimanaX_HUD` | HUDs | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 614 | `oolite.oxp.phkb.WildShips_Facelift` | Retextures | yes | 0 | PASS | PASS |  |  |
| 615 | `oolite.oxp.phkb.WireframeShipImages` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 616 | `oolite.oxp.phkb.XenonHUD` | HUDs | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 617 | `oolite.oxp.phkb.ZGrOovy_VarietyPack` | Retextures | yes | 0 | PASS | PASS |  |  |
| 618 | `oolite.oxp.popsch.Stashes` | Activities | yes | 0 | PASS | PASS |  |  |
| 619 | `oolite.oxp.redspear.additional_planets_sr_demux_alien_pack` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 620 | `oolite.oxp.redspear.additional_planets_sr_demux_earthlike_pack` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 621 | `oolite.oxp.redspear.additional_planets_sr_demux_ocean_pack` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 622 | `oolite.oxp.redspear.additional_planets_sr_demux_volcanic` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 623 | `oolite.oxp.redspear.additional_planets_sr_others_gas_giants` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 624 | `oolite.oxp.redspear.alien_systems` | Systems | yes | 2 | **ERRORS** | **ERRORS** |  | [E1](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 625 | `oolite.oxp.redspear.demand_driven_economy` | Systems | yes | 3 | **ERRORS** | **ERRORS** |  | [E1](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 626 | `oolite.oxp.redspear.equipment_by_ship_class` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 627 | `oolite.oxp.redspear.equipment_by_ship_role` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 628 | `oolite.oxp.redspear.escape_pod_as_standard` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 629 | `oolite.oxp.redspear.fighter_explorers` | Ships | yes | 0 | PASS | PASS |  |  |
| 630 | `oolite.oxp.redspear.free_bitmaps_dusty` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 631 | `oolite.oxp.redspear.free_bitmaps_icy` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 632 | `oolite.oxp.redspear.free_bitmaps_rocky` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 633 | `oolite.oxp.redspear.galdrive_reimagined` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 634 | `oolite.oxp.redspear.hyperdrives` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 635 | `oolite.oxp.redspear.indestructible_injectors` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 636 | `oolite.oxp.redspear.lightspeeder` | Ships | yes | 0 | PASS | PASS |  |  |
| 637 | `oolite.oxp.redspear.masslock_compensator` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 638 | `oolite.oxp.redspear.masslock_reimagined` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 639 | `oolite.oxp.redspear.missile_combat_reimagined` | Equipment | yes | 0 | PASS | PASS |  |  |
| 640 | `oolite.oxp.redspear.new_lasers` | Weapons | yes | 2 | **ERRORS** | **ERRORS** |  | [E1](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 641 | `oolite.oxp.redspear.paddling_pool` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 642 | `oolite.oxp.redspear.power_to_engines` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 643 | `oolite.oxp.redspear.solos_alt_stations` | Dockables | yes | 0 | PASS | PASS |  |  |
| 644 | `oolite.oxp.redspear.star_fuel` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 645 | `oolite.oxp.redspear.tech_shuffle` | Equipment | yes | 0 | PASS | PASS |  |  |
| 646 | `oolite.oxp.redspear.traffic_redistributer` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 647 | `oolite.oxp.redspear.weapon_laws` | Equipment | yes | 0 | PASS | PASS |  |  |
| 648 | `oolite.oxp.rorschachhamster.Dragonships` | Ships | yes | 0 | PASS | PASS |  |  |
| 649 | `oolite.oxp.rustem.assassin_shipset_pack` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 650 | `oolite.oxp.sdrubble.Dark_Rainbow` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 651 | `oolite.oxp.sirarian.sks-plasma-mk-1` | Ships | yes | 0 | PASS | PASS |  |  |
| 652 | `oolite.oxp.smivs.BattleDamage` | Ambience | yes | 0 | PASS | PASS |  |  |
| 653 | `oolite.oxp.smivs.ClassicMussurana` | Ships | yes | 0 | PASS | PASS |  |  |
| 654 | `oolite.oxp.smivs.ClassicShips(Addition)` | Retextures | yes | 0 | PASS | PASS |  |  |
| 655 | `oolite.oxp.smivs.ClassicShips(Replace)` | Retextures | yes | 0 | PASS | PASS |  |  |
| 656 | `oolite.oxp.smivs.ClassicXShips` | Ships | yes | 0 | PASS | PASS |  |  |
| 657 | `oolite.oxp.smivs.Clippers` | Ships | yes | 0 | PASS | PASS |  |  |
| 658 | `oolite.oxp.smivs.CombatHUD_v3.0` | HUDs | yes | 0 | PASS | PASS |  |  |
| 659 | `oolite.oxp.smivs.Delightful Docking` | Ambience | yes | 0 | PASS | PASS |  |  |
| 660 | `oolite.oxp.smivs.Enigmas` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 661 | `oolite.oxp.smivs.ExtraFuelTanks` | Equipment | yes | 0 | PASS | PASS |  |  |
| 662 | `oolite.oxp.smivs.GalDrivePod` | Equipment | yes | 0 | PASS | PASS |  |  |
| 663 | `oolite.oxp.smivs.GiantSpacePizza` | Ambience | yes | 0 | PASS | PASS |  |  |
| 664 | `oolite.oxp.smivs.Liners` | Ships | yes | 0 | PASS | PASS |  |  |
| 665 | `oolite.oxp.smivs.SmartHUD` | HUDs | yes | 0 | PASS | PASS |  |  |
| 666 | `oolite.oxp.smivs.SmivsIndustries` | Equipment | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 667 | `oolite.oxp.smivs.Star-jelly` | Ambience | yes | 0 | PASS | PASS |  |  |
| 668 | `oolite.oxp.smivs.aliens` | Ambience | yes | 0 | PASS | PASS |  |  |
| 669 | `oolite.oxp.smivs.better Buoys` | Retextures | yes | 0 | PASS | PASS |  |  |
| 670 | `oolite.oxp.smivs.betterScreens` | Ambience | yes | 0 | PASS | PASS |  |  |
| 671 | `oolite.oxp.smivs.classicShipyard` | Retextures | yes | 0 | PASS | PASS |  |  |
| 672 | `oolite.oxp.smivs.classicSuperPythons` | Ships | yes | 0 | PASS | PASS |  |  |
| 673 | `oolite.oxp.smivs.classicVarietyPack` | Retextures | yes | 20 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 674 | `oolite.oxp.smivs.contractor` | Ships | yes | 0 | PASS | PASS |  |  |
| 675 | `oolite.oxp.smivs.cup_of_tea` | Ambience | yes | 0 | PASS | PASS |  |  |
| 676 | `oolite.oxp.smivs.teretrurus` | Ships | yes | 0 | PASS | PASS |  |  |
| 677 | `oolite.oxp.smivs.yellooCabs` | Ships | yes | 0 | PASS | PASS |  |  |
| 678 | `oolite.oxp.spara.ImperialAstrofactory` | Dockables | yes | 0 | PASS | PASS |  |  |
| 679 | `oolite.oxp.spara.TechnicalReferenceLibrary` | Equipment | yes | 0 | PASS | PASS |  |  |
| 680 | `oolite.oxp.spara.aad-hud` | HUDs | yes | 0 | PASS | PASS |  |  |
| 681 | `oolite.oxp.spara.additional_planets_sr_base` | Ambience | yes | 0 | PASS | PASS | PASS |  |
| 682 | `oolite.oxp.spara.additional_planets_sr_demux_gas_giants` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 683 | `oolite.oxp.spara.additional_planets_sr_pack_redux` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 684 | `oolite.oxp.spara.asteroid-tweaks` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 685 | `oolite.oxp.spara.audible_docking_clearance` | Equipment | yes | 0 | PASS | PASS |  |  |
| 686 | `oolite.oxp.spara.behemoth` | Dockables | yes | 0 | PASS | PASS |  |  |
| 687 | `oolite.oxp.spara.commodity_markets` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 688 | `oolite.oxp.spara.countdown_to_zero` | Ambience | yes | 0 | PASS | PASS |  |  |
| 689 | `oolite.oxp.spara.eq_aide` | Equipment | yes | 0 | PASS | PASS |  |  |
| 690 | `oolite.oxp.spara.glare_filter` | Equipment | yes | 0 | PASS | PASS |  |  |
| 691 | `oolite.oxp.spara.griff_normalmapped_ships_replace` | Retextures | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 692 | `oolite.oxp.spara.in-system_taxi` | Activities | yes | 0 | PASS | PASS |  |  |
| 693 | `oolite.oxp.spara.manifest_mfd` | HUDs | yes | 0 | PASS | PASS |  |  |
| 694 | `oolite.oxp.spara.market_ads` | Ambience | yes | 0 | PASS | PASS |  |  |
| 695 | `oolite.oxp.spara.market_cooldown` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 696 | `oolite.oxp.spara.market_inquirer` | Equipment | yes | 0 | PASS | PASS |  |  |
| 697 | `oolite.oxp.spara.market_observer` | Equipment | yes | 0 | PASS | PASS |  |  |
| 698 | `oolite.oxp.spara.mo_commodity_markets` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 699 | `oolite.oxp.spara.navigation_mfd` | HUDs | yes | 0 | PASS | PASS |  |  |
| 700 | `oolite.oxp.spara.ore_processor` | Equipment | yes | 0 | PASS | PASS |  |  |
| 701 | `oolite.oxp.spara.random_hits` | Missions | yes | 0 | PASS | PASS |  |  |
| 702 | `oolite.oxp.spara.random_hits_shipset` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 703 | `oolite.oxp.spara.random_player-ship_name` | Ambience | yes | 0 | PASS | PASS |  |  |
| 704 | `oolite.oxp.spara.rescue_stations` | Systems | yes | 0 | PASS | PASS |  |  |
| 705 | `oolite.oxp.spara.sb-faves` | Ships | yes | 0 | PASS | PASS |  |  |
| 706 | `oolite.oxp.spara.sfep_stations` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 707 | `oolite.oxp.spara.spicy_hermits` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 708 | `oolite.oxp.spara.start_advice` | Ambience | yes | 0 | PASS | PASS |  |  |
| 709 | `oolite.oxp.spara.start_choices` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 710 | `oolite.oxp.spara.station_ads` | Ambience | yes | 0 | PASS | PASS |  |  |
| 711 | `oolite.oxp.spara.station_validator` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 712 | `oolite.oxp.spara.stations_for_extra_planets` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 713 | `oolite.oxp.spara.trophy_collector` | Equipment | yes | 0 | PASS | PASS |  |  |
| 714 | `oolite.oxp.spara.yah_constores_only` | Ambience | yes | 0 | PASS | PASS |  |  |
| 715 | `oolite.oxp.spara.yah_fuel_station` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 716 | `oolite.oxp.spara.yah_gem_casino` | Activities | yes | 0 | PASS | PASS |  |  |
| 717 | `oolite.oxp.spara.yah_more` | Ambience | yes | 0 | PASS | PASS |  |  |
| 718 | `oolite.oxp.spud42.Eagle_Transporter` | Ships | yes | 0 | PASS | PASS |  |  |
| 719 | `oolite.oxp.staer9.StarDestroyer` | Ships | yes | 0 | PASS | PASS |  |  |
| 720 | `oolite.oxp.staer9.chopped_cobra` | Ships | yes | 0 | PASS | PASS |  |  |
| 721 | `oolite.oxp.staer9.staer9_shipset` | Ships | yes | 0 | PASS | PASS |  |  |
| 722 | `oolite.oxp.stormrider.Darkside_Moonshine_Distillery` | Dockables | yes | 0 | PASS | PASS |  |  |
| 723 | `oolite.oxp.stormrider.manifestScanner` | Equipment | yes | 0 | PASS | PASS |  |  |
| 724 | `oolite.oxp.stranger.ComboF7Layout` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 725 | `oolite.oxp.stranger.DarkRay` | Ambience | yes | 0 | PASS | PASS |  |  |
| 726 | `oolite.oxp.stranger.EnergyRebalance` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 727 | `oolite.oxp.stranger.EnergyRebalance_SCC` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 728 | `oolite.oxp.stranger.FPO_Lave` | Ambience | yes | 0 | PASS | PASS |  |  |
| 729 | `oolite.oxp.stranger.FPO_Zaonce` | Ambience | yes | 0 | PASS | PASS |  |  |
| 730 | `oolite.oxp.stranger.HabitableMainPlanets` | Ambience | yes | 0 | PASS | PASS |  |  |
| 731 | `oolite.oxp.stranger.HardEject` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 732 | `oolite.oxp.stranger.HardWay` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 733 | `oolite.oxp.stranger.HereBeDragons` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 734 | `oolite.oxp.stranger.InSystemCargoDelivery` | Activities | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 735 | `oolite.oxp.stranger.InternalFuelTank` | Equipment | yes | 0 | PASS | PASS |  |  |
| 736 | `oolite.oxp.stranger.LeestiIsMoon8k` | Ambience | yes | 0 | PASS | PASS |  |  |
| 737 | `oolite.oxp.stranger.LeestiIsMoonLSM8k` | Ambience | yes | 0 | PASS | PASS |  |  |
| 738 | `oolite.oxp.stranger.MineralStoreReset` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 739 | `oolite.oxp.stranger.Moons` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 740 | `oolite.oxp.stranger.MoonsTexturePack` | Ambience | yes | 0 | PASS | PASS |  |  |
| 741 | `oolite.oxp.stranger.OrbitalStations` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 742 | `oolite.oxp.stranger.PlanetarySystems` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 743 | `oolite.oxp.stranger.PlanetarySystemsTexturePack_A` | Ambience | yes | 0 | PASS | PASS |  |  |
| 744 | `oolite.oxp.stranger.PlanetarySystemsTexturePack_B` | Ambience | yes | 0 | PASS | PASS |  |  |
| 745 | `oolite.oxp.stranger.PlanetarySystemsTexturePack_C` | Ambience | yes | 0 | PASS | PASS |  |  |
| 746 | `oolite.oxp.stranger.PlanetarySystemsTexturePack_D` | Ambience | yes | 0 | PASS | PASS |  |  |
| 747 | `oolite.oxp.stranger.PlanetarySystemsTexturePack_E` | Ambience | yes | 0 | PASS | PASS |  |  |
| 748 | `oolite.oxp.stranger.PlanetarySystemsTexturePack_F` | Ambience | yes | 0 | PASS | PASS |  |  |
| 749 | `oolite.oxp.stranger.PlanetarySystemsTexturePack_G` | Ambience | yes | 0 | PASS | PASS |  |  |
| 750 | `oolite.oxp.stranger.PlanetarySystemsTexturePack_H` | Ambience | yes | 0 | PASS | PASS |  |  |
| 751 | `oolite.oxp.stranger.SW_Economy` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 752 | `oolite.oxp.stranger.SW_HUD_CAI` | HUDs | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 753 | `oolite.oxp.stranger.SW_HUD_DAI` | HUDs | yes | 0 | PASS | PASS |  |  |
| 754 | `oolite.oxp.stranger.SunGear` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 755 | `oolite.oxp.stranger.TrafficLights` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 756 | `oolite.oxp.stranger.start_choices_addenda` | Mechanics | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 757 | `oolite.oxp.superbatprime.Ship's_Cat` | Ambience | yes | 0 | PASS | PASS |  |  |
| 758 | `oolite.oxp.tsoj.chrysopelea_mk-i` | Ships | yes | 0 | PASS | PASS |  |  |
| 759 | `oolite.oxp.tsoj.himsn` | Miscellaneous | yes | 0 | PASS | PASS |  |  |
| 760 | `oolite.oxp.tsoj.secretarybird` | Ships | yes | 0 | PASS | PASS |  |  |
| 761 | `oolite.oxp.tsoj.tec_apep_mk_2` | Ships | yes | 0 | PASS | PASS |  |  |
| 762 | `oolite.oxp.wesfire.StarSystemLaneIndicator` | Equipment | yes | 0 | PASS | PASS |  |  |
| 763 | `oolite.oxp.z.phkb.MarketScreenLegalColumnMO` | Miscellaneous | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 764 | `oolite.oxp.z.phkb.XenonReduxUI` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 765 | `oolite.oxp.z.phkb.XenonReduxUIResources` | Ambience | yes | 0 | PASS | PASS |  |  |
| 766 | `oolite.oxp.z.phkb.XenonUI` | Ambience | yes | 1 | **ERRORS** | **ERRORS** | PASS | [E6](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 767 | `oolite.oxp.z.phkb.XenonUIResources` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 768 | `oolite.oxp.z.phkb.XenonUIResourcesB` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 769 | `oolite.oxp.z.phkb.XenonUIResourcesC` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 770 | `oolite.oxp.z.phkb.XenonUIResourcesD` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 771 | `oolite.oxp.z.phkb.XenonUIResourcesE` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 772 | `oolite.oxp.z.phkb.XenonUIResourcesF` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 773 | `oolite.oxp.z.phkb.XenonUIResourcesG` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 774 | `oolite.oxp.z.phkb.XenonUIResourcesH` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 775 | `oolite.oxp.z.phkb.XenonUIResourcesI` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 776 | `oolite.oxp.z.phkb.XenonUIResourcesJ` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 777 | `oolite.oxp.z.phkb.XenonUIResourcesK` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 778 | `oolite.oxp.z.phkb.XenonUIResourcesL` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 779 | `oolite.oxp.z.phkb.XenonUIResourcesM` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 780 | `oolite.oxp.z.phkb.XenonUIResourcesN` | Ambience | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 781 | `oolite.oxp.zirael.UsefulMFDs` | HUDs | yes | 0 | PASS | PASS |  |  |
| 782 | `oolite.oxp.zireael.laser-colors` | Ambience | yes | 0 | PASS | PASS |  |  |
| 783 | `oolite.oxp.zireael.oranged-hud` | HUDs | yes | 0 | PASS | PASS |  |  |
| 784 | `oolite.oxp.zzz.Montana05.Adder_Mark_II` | Ships | yes | 0 | PASS | PASS |  |  |
| 785 | `oolite.oxp.zzz.Montana05.BUS_MegaBat` | Ships | yes | 2 | **ERRORS** | PASS |  | [oo-1gc.15](#js-candidates) |
| 786 | `oolite.oxp.zzz.Montana05.BUS_gecko_dragon` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 787 | `oolite.oxp.zzz.Montana05.Far_Arms_Ships` | Ships | yes | 0 | PASS | PASS |  |  |
| 788 | `oolite.oxp.zzz.Montana05.FdL_enhanced_vipers` | Ships | yes | 0 | PASS | PASS |  |  |
| 789 | `oolite.oxp.zzz.Montana05.GalCop_military_missile_G1` | Weapons | yes | 0 | PASS | PASS |  |  |
| 790 | `oolite.oxp.zzz.Montana05.GalCop_military_missile_G2` | Weapons | yes | 0 | PASS | PASS |  |  |
| 791 | `oolite.oxp.zzz.Montana05.GalTech_chimera_gunship_Fix` | Ships | yes | 2 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 792 | `oolite.oxp.zzz.Montana05.GalTech_colonial_viper_mark_I_Restore` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 793 | `oolite.oxp.zzz.Montana05.GalTech_constitution_class_heavy_cruiser_Fix` | Ships | yes | 2 | **ERRORS** | **ERRORS** |  | [E7](../EXPANSION_MIGRATION.md#tier-2-and-tier-3-corpus-findings-bead-oo-1gc11) |
| 794 | `oolite.oxp.zzz.Montana05.GalTech_cylon_raider_Fix` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 795 | `oolite.oxp.zzz.Montana05.GalTech_escort_fighter_Fix` | Ships | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 796 | `oolite.oxp.zzz.Montana05.Kestrel_Falcon` | Ships | yes | 6 | **ERRORS** | **ERRORS** |  | [oo-1gc.16](#js-candidates) |
| 797 | `oolite.oxp.zzz.Montana05.KillerWolf.nuit_station` | Dockables | yes | 0 | PASS | PASS |  |  |
| 798 | `oolite.oxp.zzz.Montana05.MassTrans_FruitBat` | Ships | yes | 0 | PASS | PASS |  |  |
| 799 | `oolite.oxp.zzz.Montana05.SIRF` | Dockables | no | 0 | NOTLOADED_DEPS | NOTLOADED_DEPS |  |  |
| 800 | `oolite.oxp.zzz.Montana05.SIRF_compact` | Dockables | yes | 0 | PASS | PASS |  |  |
| 801 | `oolite.oxp.zzz.Montana05.Slartibartfast.adck_imperial_trader` | Ships | yes | 0 | PASS | PASS |  |  |
| 802 | `oolite.oxp.zzz.Montana05.ZPG_fer_de_pai` | Ships | yes | 0 | PASS | PASS |  |  |
| 803 | `oolite.oxp.zzz.Montana05.adck_bulk_haulers` | Ships | yes | 0 | PASS | PASS |  |  |
| 804 | `oolite.oxp.zzz.Montana05.adck_snark` | Ships | yes | 0 | PASS | PASS |  |  |
| 805 | `oolite.oxp.zzz.Montana05.adck_wyvern_explorer` | Ships | yes | 0 | PASS | PASS |  |  |
| 806 | `oolite.oxp.zzz.Montana05.griff.hognose` | Ships | yes | 0 | PASS | PASS |  |  |
| 807 | `oolite.oxp.zzz.Montana05.resource_pack_01` | Miscellaneous | yes | 0 | PASS | PASS | PASS |  |
| 808 | `oolite.oxp.zzz.Montana05.s9_firefly_class` | Ships | yes | 0 | PASS | PASS |  |  |
| 809 | `oolite.oxp.zzz.Montana05.thargoid_weaponry` | Weapons | yes | 0 | PASS | PASS |  |  |
| 810 | `oolite.oxp.zzz.Montana05_Griff_Glowroids` | Ambience | yes | 0 | PASS | PASS |  |  |
| 811 | `oolite.oxp.zzz.Montana05_HUD_toggle` | Mechanics | yes | 0 | PASS | PASS |  |  |
| 812 | `oolite.oxp.zzz.Montana05_Taranis_outrider` | Ships | yes | 0 | PASS | PASS |  |  |
| 813 | `tws_satnav` | Equipment | yes | 0 | PASS | PASS |  |  |

</details>

## Reproducing

```sh
# one shard of N; run them in parallel inside ONE gui-lock hold, or serially
bash tools/corpus.sh tier3 --app-dir <oolite.app> --state <dir>/shardK --shard K/N
# re-render a state dir
bash tools/corpus.sh report --results <dir>/shardK/results
```

`--state` may now be relative. The runner resolves it to an absolute path; see
`tools/oxp_tier_run.py`. Before this bead, a relative state dir made every load time out as
HARNESS, because the game resolves its log directory against the app dir.
