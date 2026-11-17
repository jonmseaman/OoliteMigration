# Parity fix plan for `seriesb/028-upstream-772-tests`

**Status: plan only. Nothing has been changed on 028 yet.** Source: the 2026-11-16 audit in [README.md](README.md). Every line number is for `bf01f1b49`. The fixes are commits on `seriesb/028-upstream-772-tests` itself, with no new branches.

**Why 028:** it already carries the upstream PR #772 JS tests, `tests/oolite_harness.py`, `tests/run_js_tests.py` and the `tools/js-parity` probe. Together with `tests/unit/{core,oofnd}`, that is enough to write a test that fails before each fix and passes after it.

**Rules for every commit:**
- one concern per commit;
- the test lands in the same commit;
- the area-file bullet changes to `(fixed on 028, <commit>)` when the next audit runs;
- golden output that changes is called out in the commit message.

Suggested order: 1, 2, 3 first (user-facing bugs), then 4–7. 8 is documentation only and can go anywhere.

## 1. Resources: stop rebuilding the data cache, and find symlinked OXPs

Closes:
- **med:** data cache rebuilt on most launches;
- **med:** symlinked `.oxp` folders not found;
- **low (new):** symlinked `.oxz` resolved to its target, and one unreadable folder ending the scan.

All in [gamedata.md#resourcemanager](gamedata.md#resourcemanager).

Changes:
- `oofnd/FileSystem.hpp:183-187` `modificationTimeSince1970`: convert `file_clock` to `system_clock` with one fixed offset, or with `clock_cast` where available, instead of two `now()` readings.
- `oofnd/FileSystem.hpp:197-249` `RecursiveDirectoryEnumerator`:
  - follow a symlink whose target is a directory, as `-fileExistsAtPath:isDirectory:` did;
  - keep the link's own path, not `relative()`'s resolved one;
  - use `directory_options::skip_permission_denied`, and skip a failing entry instead of ending the walk.
- The caller is `Core/ResourceManager.cpp:509-528`, which shouldn't need changes beyond the enumerator.

Tests:
- `tests/unit/oofnd/test_filesystem.cpp`:
  - two `modificationTimeSince1970` calls on one file are equal;
  - a symlinked directory is enumerated under the link's path;
  - an unreadable subfolder doesn't stop the walk.
  - Symlinks need Developer Mode on Windows, so skip with `GTEST_SKIP` when `create_directory_symlink` fails.
- `tests/unit/core/test_ResourceManager.cpp`: with an unchanged AddOns folder, a second load doesn't log `dataCache.rebuild.datesChanged`.

Risk: low. This doesn't touch goldens. Startup gets faster.

## 2. Exceptions: log and continue, and remove the throwers

Closes:
- **med:** standard-library exceptions are fatal ([cpp-only.md#exception](cpp-only.md#exception), [universe.md#gamecontroller](universe.md#gamecontroller));
- **low:** the `.at(0)` throwers ([entities-player.md#playerentity](entities-player.md#playerentity)).

Changes:
- Make the `.at(0)` calls return `kZeroVector` on an empty list, as upstream's nil-messaging did:
  - `PlayerEntity.cpp:6225` (`fireMainWeapon` overheat);
  - `PlayerEntityControls.cpp:1403` (laser-hit sound).
- Add a `catch (const std::exception&)` that logs under the same class as the `oo::Exception` arm and carries on, as `@catch (id)` did:
  - `GameController.cpp:404-417` (`doPerformGameTick`; the `updateScreen` rethrow);
  - `AI.cpp:502`;
  - `PlayerEntityControls.cpp:771,1202,2173,2760,5321`;
  - `PlayerEntityLegacyScriptEngine.cpp:464,489,519`;
  - `SDL/main.cpp:311`.
- Replace the comment "the game throws only oo::Exception" with a citation (this commit).

Tests:
- `tests/unit/core/test_PlayerEntity.cpp`: firing with an empty laser-offset list doesn't throw.
- `tests/unit/core/test_GameController.cpp`: a `std::out_of_range` thrown from a tick is logged, and the next tick runs.

Risk: low. Log output changes only on paths that used to crash.

## 3. Preference defaults with `oo_*ForKey:defaultValue:` semantics

Closes:
- **med:** cross-cutting item 1: about 16 sites, including `animation_timer_interval` → a 10 kHz loop;
- **low:** the `logging-show-*`, `ecoqos` and `volume_control` sites;
- **low:** the two `doubleValue` ports.

All in [foundation.md#oocollectionextractors](foundation.md#oocollectionextractors).

Changes:
- Add `oo::Defaults::get<T>(key, fallback)` (`oofnd/Defaults.hpp`). It converts through the same rules as `PListGet.hpp`'s `oo_*ForKey` equivalents: `OOBooleanFromObject` for bools, the fallback for a wrong kind or an unparsable string.
- Replace every `object(k).isNull() ? d : xForKey(k)` site:
  - `GameController.cpp:235-238,291-293`;
  - `Universe.cpp:307-361`;
  - `OOALSound.cpp:65-68`;
  - `OOLogging.cpp:228-243`.
- Make `Defaults.hpp:172` (`from_chars`) call the GNUstep-faithful `plist_get::scanDoubleAt` (`PListGet.hpp:166`), so there is one `doubleValue`.

Tests:
- `tests/unit/oofnd/test_defaults.cpp`:
  - for each type, the fallback for "on", ".5", "fast", an array and a dict;
  - `doubleValue` on long mantissas and huge exponents, with the expected values taken from GNUstep 1.31.1.

Risk: medium. It touches start-up for every user, but only changes behaviour for malformed preferences.

## 4. JavaScript-visible fixes

| Item | Change | Test |
|---|---|---|
| **med** `EquipmentInfo.provides` gives `[]`, not null ([scripting.md#oojsequipmentinfo](scripting.md#oojsequipmentinfo)) | `OOJSEquipmentInfo.cpp:423-427`: return `null` when the type has no extra-info dict (`OOEquipmentType.cpp:302-308,582`) | `tests/unit/core/test_OOJSEquipmentInfo.cpp`, plus a `tests/js` case through `run_js_tests.py` |
| **med** time limit enforced exactly ([scripting.md#oojsenginetimemanagement](scripting.md#oojsenginetimemanagement)) | `OOJavaScriptEngine.cpp:702-718`: kill only once the limit has passed *and* a watchdog-period boundary (1 s release, 0.2 s debug) has been crossed, as upstream's sampling did. Or decide to keep exact enforcement and move it to ⚠️ with a note in `EXPANSION_MIGRATION.md`. **Needs Jon's call.** | `tests/unit/core/test_OOJSTimeLimiter.cpp`: a 1.5 s script with a 1 s limit survives (or is killed, per the decision) |
| low: native setters return `undefined`, not the callee (`setBounty`, `setPlayerRole`, `setEscapePodDestination`, `VisualEffect.scale`) | Return `this`/the callee as upstream did | the `js-parity` probe baseline (`tools/js-parity/expected-differences.txt` shrinks) |
| low: `system.filteredEntities` predicate exceptions are uncatchable | Let the pending exception reach the caller (`OOJavaScriptEngine.cpp:1638-1644`, `OOJSSystem.cpp:1091`) | `tests/js` try/catch case |

Risk: low. These change JS-visible results, so rerun `tools/js-parity/compare.sh` and update the expected differences.

## 5. Rendering

| Item | Change | Test |
|---|---|---|
| **med** `laserColor` uniform can't be bound ([graphics.md#ooshaderuniform](graphics.md#ooshaderuniform)) | Add a `laserColor` row to `kEntityShaderBindings` (`EntityShaderBindings.cpp:~150`) returning `ShipEntity::laserColor()` as a vec4, and fix the stale comment at `:98` | `tests/unit/core/test_EntityShaderBindings.cpp`: every whitelisted uniform name (87) has a row |
| low: shader logs print the class as `Entity` (`OOShaderUniform.cpp:245,381-387`, `OOShaderMaterial.cpp:332-335`) | Print the real class name | same test file, log capture |
| *shared upstream bug:* `OOMatrixForRotation` third row `t*x*y` → `t*x*z` (`OOMatrix.cpp:56-59`, upstream `OOMatrix.m:52`) | This is a deliberate departure from upstream. **Jon's call;** if yes, tell upstream | `tests/unit/core/test_OOMatrix.cpp` `aRotationAndItsOppositeCancel` with axis `(1,1,0)` |

## 6. Entities and log text

| Item | Change | Test |
|---|---|---|
| **med** missile ident on a wormhole shows no name ([entities-player.md#playerentity](entities-player.md#playerentity)) | `PlayerEntity::printIdentLockedOnForMissile` (`PlayerEntity.cpp:13048`): ask the raw target for `identFromShip`, wormholes included | `test_PlayerEntity.cpp` |
| **med** `EntityShortDescription` loses the class and name ([cpp-only.md#entityhelpers](cpp-only.md#entityhelpers)) | `EntityHelpers.cpp:122-126`: format `<Class 0x… name>` like upstream `-shortDescription` | a unit test on the string; check the goldens that contain `ai.error.stackOverflow`/`entity.invalidSession` |
| low *(memory safety)*: `quantityInHold[IndexOfGood]` | `PlayerEntity.cpp:11924-11928`: skip a container whose good is `kNotFound` | `test_PlayerEntity.cpp` with a cargo pod of an unknown commodity |
| low: crashes where upstream's nil message did nothing | Add null guards: `behaviour_attack_slow_dogfight` (`ShipEntity.cpp:4577-4580`), `resetCommsLogColor` (`Universe.cpp:10361`), `drawTargetTextureIntoDefaultFramebuffer` (`:11677`), `shipRestoredFromDictionary` (`ShipEntityLoadRestore.cpp:245-250`), `drawTrumbles` (`HeadUpDisplay.cpp:3591`) | one test per guard, where a stand-in exists |
| low: log text drift (cross-cutting item 4) | Restore `-[Class method]`-style names where goldens match on them, the `nonStandardFile` "(type)" and the `%3zu`/`%4u` widths in `AI.cpp:251,454` | golden diff |
| low (new): `[x\|precision:N]` with a negative N throws; `StringFromRandomSeed` prints signed bytes | Clamp the precision as `%.*f` did (`OOStringExpander.cpp:601-605`); cast to `unsigned` (`OOStringParsing.cpp:204-209`) | `tests/unit/expander` |

## 7. macOS log folder

⚠️ med, new ([foundation.md#oologoutputhandler](foundation.md#oologoutputhandler)): `OOLogOutputHandler.cpp:307-320` has only Linux and Windows arms, so macOS logs go to `./Logs`. Add an `OOLITE_MACOS` arm for `~/Library/Logs/Oolite`, as upstream's Cocoa build used. Test: unit-test `OOLogHandlerGetLogBasePath` with a fake home directory. It can only be checked on a macOS runner.

## 8. Decisions to record (documentation only)

Record each one in the Decisions section of `docs/phases/4p-upstream-polish.md`, or as an ADR. The 028 tree has no `ADR-0043` file, although the code cites it.
- `ship.speed` writable: keep, citing the rationale at `OOJSShip.cpp:1766-1770`, or make it read-only again.
- `OORoleSet::anyRole` and the other hash → sorted orders: keep sorted, and list them with the ADR-0043 divergences. Hash order can't be reproduced anyway.
- QuickJS-ng error texts and the missing SpiderMonkey extensions: list them in `EXPANSION_MIGRATION.md` (only the read-only text is there now).
- Script-local top-level declarations, and `callObjC` reaching only entities.
- `OOProbabilitySet` `PList ==` (1 vs 1.0): the bead citation was lost, so restore it or fix it.

## Knock-on for the rest of the stack

After these commits land on 028, `git town sync` rebases 029–033 on top. Branch churn since 028:

| Branch | Commits | src files | Notes |
|---|---|---|---|
| 029-cpp-component-tests | 60 | 27 | touches the test trees these commits add to |
| 030-json5-data-files | 10 | 9 | ResourceManager / plist loading: may conflict with commit 1 |
| 031-third-party | 2 | 24 | low risk |
| 032-cleanup | 160 | 493 | the biggest risk: broad edits across PlayerEntity, Universe, AI, GameController |
| 033-drop-oo-prefix | 12 | 512 (306 renames) | renames most files touched here (e.g. `OOALSound.cpp`, `OOLogging.cpp`, `OORoleSet.cpp`, `OOStringExpander.cpp`, `OOMatrix.cpp`, `OOEquipmentType.cpp`); git's rename detection should carry the edits, but check each conflict |

Most likely conflicts: `PlayerEntity.cpp` (3,883 lines changed 028→033), `Universe.cpp` (3,114), `PlayerEntityControls.cpp` (1,663), `PlayerEntityLegacyScriptEngine.cpp` (1,149) and `GameController.cpp` (441). Keep commits 2, 3 and 6 small and mechanical to make the rebase easier. Rerun the unit tests on each branch after the sync.
