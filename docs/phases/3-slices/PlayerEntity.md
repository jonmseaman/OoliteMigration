# Slice plan: PlayerEntity

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-9ht.154; the class is the frontier giant
oo-a70). Checked by `python3 tools/check-slice-plan.py docs/phases/3-slices/PlayerEntity.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/PlayerEntity.mm` (13,853 lines) + header (1,323 lines). One class,
  `PlayerEntity : ShipEntity`, whose ~480 methods are a single `@implementation` with no
  `#pragma mark` sections, so the slices follow the order of the file, which already groups
  related methods (cargo and coordinates, the commander dictionary, set-up, the per-frame
  updates, attitude and views, the dials, missiles and weapons, damage and death, witchspace, the
  GUI screens, equipment, the market, trumbles, the custom view, scripts, docking clearance and
  mission destinations). The other `PlayerEntity` categories have their own files and plans or
  beads (below).
- **The header is charged by use** (`header-names: by-use`, new in `tools/check-slice-plan.py`,
  bead oo-9ht.154, on top of oo-9ht.140's `header-decls: per-slice`). `PlayerEntity.h` is 1,323
  lines: 372 of method declarations (charged per slice), a 451-line ivar block, and ~340 lines of
  GUI-row enums, chart and market constants and macros above the `@interface`. Charged whole, the
  header and the 259-line preamble come to ~1,210 lines before a slice owns anything, and five
  methods (`cxx_setCommanderDataFromDictionary:` alone is 613 lines) fit in no slice under the
  1,500-line budget. With `header-names: by-use` a slice is charged the declarations its units
  name (an ivar, a `#define`, an enum with its enumerators, a typedef, a constant, an inline
  function) and the ones those name in turn; what declares nothing (imports, `#if` arms, the
  licence, blank lines) stays charged to every slice (~350 lines). Once slice 1 lands the ivars are
  members of `cxx::PlayerEntity`, and a story reads the members its bodies use.
- **Order:** after ShipEntity's class shell (oo-60fwo) and this pre-split. Slice 1 first; slices
  2-28 each wait on slice 1 and on the ShipEntity slices that hold the methods they override
  (table below), and are then independent of each other. Twenty-seven of them are fleet stories;
  slice 1 is frontier.
- **Verbatim:** the twenty plist / string / row helpers above the `@implementation`
  (`StringForKey()` … `OoliteInfoString()`) and `PrepareMarkedDestination()` / `SliderString()`
  inside it have no Objective-C and stay verbatim ([ADR-0012](../../decisions/0012-c-stays-c.md),
  CLAUDE.md rule 9). The market sorters (`marketSorterByName()` …) message the market, so they
  move with `cxx_applyMarketSorter:onMarket:` (slice 23); `InterfaceForKey()` messages the station,
  so it moves with `showInformationForSelectedInterface` (slice 21).

## Slice 1: the class shell (frontier)

Slice 1 is ShipEntity slice 1's pattern (oo-60fwo: [ADR-0056](../../decisions/0056-phase3-class-conversion-house-style.md)
amendments oo-bj8 and oo-60fwo) applied to the ship's player subclass. Its own units are five
(`+sharedPlayer`, `-init`, `-deferredInit`, `-dealloc`, `-suppressClangStuff`, ~260 lines), but it
moves the class.

1. **`cxx::PlayerEntity : cxx::ShipEntity`** in `PlayerEntity.h`: the ~280 ivar declarations
   become data members by the same names, every one zero-initialised (amendment oo-bj8 item 1).
   The ivar block is `@private`; its members are public while the class is half converted
   (amendment oo-60fwo item 2), marked `// private once PlayerEntity is converted (oo-a70)`. The
   macros, enums, constants and C declarations above the `@interface`, `OOGetPlayer()` / `PLAYER`
   and the `cxx_` string functions below it stay.
2. **The façade** `@interface PlayerEntity : ShipEntity` (the ship's façade) in
   `PlayerEntity+ObjCBridge.h/.mm`, imported as the last line of `PlayerEntity.h`: every method
   declaration of the old `@interface` copied exactly. The façade's `-init` makes
   `oo::ObjCEntity<cxx::PlayerEntity>` where it sent `[super initBypassForPlayer]`, and
   `-deferredInit` keeps sending `-cxx_initWithKey:definition:` to the ship part (amendment oo-60fwo
   item 4); `gOOPlayer`, `+sharedPlayer` and `-dealloc` stay in the façade (amendment oo-bj8
   item 7). `ProxyPlayerEntity` is not a `PlayerEntity` and is not touched.
3. **The unconverted methods keep their bodies and reach the members through a typed view**, as
   the ship's do: one `@public` borrowed alias `cxx::PlayerEntity *_cxxPlayer` on the façade, set
   beside `_cxxShip` by the initialiser and never owning (amendment oo-60fwo item 1). The rewrite
   is compiler-guided: with the ivars gone, insert `_cxxPlayer->` at every "use of undeclared
   identifier" error that names one, in `PlayerEntity.mm`'s unconverted methods and in the
   category files (`PlayerEntityContracts.mm`, `-Controls.mm`, `-KeyMapper.mm`,
   `-LegacyScriptEngine.mm`, `-LoadSave.mm`, `-ScriptMethods.mm`, `-Sound.mm`, `-StickMapper.mm`,
   `-StickProfile.mm` where it reads player state); then build once with poison ivars of the old
   names to prove no bare use bound to another declaration. Reuse oo-60fwo's codemod
   (`.agent-tmp/cc/60fwo/codemod.py`, after oo-bj8's `.agent-tmp/cc/bj8/codemod.py`). The edit is
   far over 400 written lines but has no judgement in it; each later slice deletes `_cxxPlayer->`
   from its own bodies to get them back verbatim. `-suppressClangStuff` (it names ~136 ivars to
   keep the analyser quiet) becomes a member, so it is the one place every member is named.
4. **Test first:** `tests/unit/core/test_PlayerEntity.mm` against the Objective-C API, run on the
   unconverted class, then ported (amendment oo-bj8 item 11's harness, as `test_ShipEntity`).
   Slice 1 files the "Delete PlayerEntity+ObjCBridge" bead (like oo-9ht.1), which waits on the
   umbrella oo-a70.

## Slices 2-28 (fleet)

Each slice moves its units into `cxx::PlayerEntity` as member functions, declares them in the
class, leaves a forwarder on the façade for each (the selectors are messaged from ~120 files, by
name from the debug console and the legacy scripts, ADR-0043 item 21), and deletes `_cxxPlayer->`
from the moved bodies. A method that overrides a `ShipEntity` method becomes `override` of the
ship's `virtual` member, which exists only once that ship slice has landed, so the slice waits on
it (table). Calls from a converted body to a method of a slice that has not landed stay sends to
`oo::ToObjC(this)`.

| Slice | Content | Own lines | Reads (header part + preamble + own) |
|---|---|---:|---:|
| 1 | class shell (frontier): the C++ class, the façade, the adapter, the `_cxxPlayer->` rewrite; `sharedPlayer`, `init`, `deferredInit`, `dealloc` | ~260 | ~1,076 |
| 2 | cargo pods, commodity data and credits, galaxy and chart coordinates, the current and previous system | ~520 | ~1,187 |
| 3 | target, next-hop and info systems, the wormhole, the commander data dictionary (save) | ~491 | ~1,174 |
| 4 | setting the commander data from a dictionary (load) | ~613 | ~1,342 |
| 5 | set-up and start-up, ship set-up from the dictionary, the session, warning about hostiles | ~517 | ~1,315 |
| 6 | sun glare, the atmosphere, `update:` | ~213 | ~830 |
| 7 | the bookkeeping tick (`doBookkeeping:`), movement flags | ~488 | ~1,188 |
| 8 | alert conditions, mass lock, fuel scoops, clocks, script and trumble ticks, the autopilot and docking requests | ~509 | ~1,205 |
| 9 | the autopilot AI, hyperspeed, in-flight / witchspace / launch / docking / dead updates, game over, the ship model view, targeting | ~514 | ~1,210 |
| 10 | attitude, view matrices and viewpoints, drawing, mass lock, the docked station, the HUD and its custom dials, shield levels | ~519 | ~1,249 |
| 11 | the dials, fuel leak, the comm log, player roles, system memory, the compass target | ~518 | ~1,246 |
| 12 | compass mode, missiles and pylons, special cargo, the multi-function displays, alert flags | ~513 | ~1,212 |
| 13 | alert condition, AI messages, mounting and firing missiles and mines, the cloak, ECM, energy units, the main weapons | ~482 | ~1,191 |
| 14 | hit testing, damage, the doppelganger, the escape capsule, dumping cargo, bounty | ~519 | ~1,142 |
| 15 | legal status, offences, bounties collected, internal damage, destruction, ending a scenario, docking and leaving dock | ~518 | ~1,201 |
| 16 | witchspace: start, end, checklist, jump type and distance, fuel, galactic and wormhole jumps | ~480 | ~1,165 |
| 17 | leaving witchspace, the status screen, the equipment list, primed and fast equipment, weapon types | ~520 | ~1,219 |
| 18 | scripting lists, the system data screen, marked destinations, the chart screens | ~504 | ~1,187 |
| 19 | the game options and load / save screens, equip-screen key highlight, available facings | ~434 | ~1,151 |
| 20 | the equip-ship screen and upgrade information | ~440 | ~1,106 |
| 21 | the interfaces screen, the start screen and intro, the OXZ manager, GUI and view change notes | ~497 | ~1,162 |
| 22 | buying equipment, script price adjustment, weapon mounts, passenger berths, removing missiles, trade-in | ~511 | ~1,180 |
| 23 | cargo quantities, the local market, market filters and sorters, market screen rows | ~375 | ~1,064 |
| 24 | the market screens, buying and selling commodities, mining and speech flags, adding equipment | ~503 | ~1,249 |
| 25 | equipment add / remove / custom activation, pylons, parcels and passengers, comms, fines, trade-in factor, renovation, view offsets, trumbles | ~517 | ~1,176 |
| 26 | trumble values, checksums, screen modes, target memory, missile ident, rotating and panning the custom view | ~514 | ~1,226 |
| 27 | custom view vectors and data, the mission overlay and background, world scripts and script events, galactic hyperspace, jump cause, names | ~511 | ~1,239 |
| 28 | docking clearance, scanned wormholes, mission destinations, the shipyard record, extra mission and GUI-screen keys, the state dump | ~404 | ~1,109 |
| verbatim | 20 plain-C helpers | ~190 | not read |

**Overrides.** Found by matching every method of each slice against the units of
[ShipEntity.md](ShipEntity.md), [ShipEntityAI.md](ShipEntityAI.md) and the two whole-file ship
categories; each slice depends on the ShipEntity (and ShipEntityAI) slices listed:

| Slice | Overrides methods of | Slice | Overrides methods of |
|---|---|---|---|
| 1 | Ship 1 | 15 | Ship 20, 22, 23, 31, 32 |
| 2 | Ship 17 | 16 | Ship 31 |
| 5 | Ship 3, 6 | 17 | Ship 9, 31 |
| 6 | Ship 6, 7, 27 | 18 | Ship 9, 20 |
| 8 | Ship 21, ShipEntityAI 3 | 22 | Ship 9, 10 |
| 9 | Ship 24 | 23 | Ship 20 |
| 10 | Ship 10, 16, 17 | 24 | Ship 9, 33 |
| 11 | Ship 23, 30 | 25 | Ship 8, 9, 10, 18, 33 |
| 12 | Ship 34 | 26 | Ship 23, 24, 30 |
| 13 | Ship 28, 29, 33, 34 | 27 | Ship 19, 34 |
| 14 | Ship 5, 20, 29, 31 | 28 | Ship 34 |

Slices 3, 4, 7, 19, 20 and 21 override nothing of the ship's.

## The category files and the other waiting beads

- **Category files** become members of `cxx::PlayerEntity` in their own beads (amendment oo-o89
  item 4), each after slice 1 (they were waiting on nothing that made the class C++):
  [KeyMapper](PlayerEntityKeyMapper.md) (oo-5uo7, oo-10jz, oo-mofd),
  [Contracts](PlayerEntityContracts.md) (oo-6e3h, oo-t2t5, oo-oo99),
  [LoadSave](PlayerEntityLoadSave.md) (oo-xmvt, oo-rczn),
  [LegacyScriptEngine](PlayerEntityLegacyScriptEngine.md) (oo-130j, oo-ng9h, oo-z1nv, oo-vn3o;
  its slice 2, oo-ng9h, overrides `commsMessage:` / `commsMessageByUnpiloted:` of ShipEntityAI
  slice 3, oo-wc9o3, and waits on it), and the whole-file beads `PlayerEntityScriptMethods.mm`
  (oo-50zg), `PlayerEntitySound.mm` (oo-xowh) and `PlayerEntityStickMapper.mm` (oo-ibm8).
  `PlayerEntityControls.mm` (5,684 lines) is still one frontier bead, oo-e1d, now after slice 1;
  its own pre-split is oo-9ht.157. `PlayerEntityStickProfile.mm`'s `StickProfileScreen` class is
  converted (oo-movn), but its `PlayerEntity (StickProfile)` category (three methods) is not:
  oo-9ht.156, after slice 1.
- **The façade-deletion beads** that waited on oo-a70 wait instead on slice 1 and the slices (and
  category beads) whose units name the façade's class, an accessor or member typed with it, or a
  selector only it declares; the list is in oo-a70's notes. Beads that need the Objective-C
  `PlayerEntity` itself gone (oo-9ht.15, oo-9ht.128, oo-9ht.44: a category of it, or `callObjC()`
  reaching it) and the phase review and gate keep waiting on the umbrella.
- **oo-dxxt** (`OOJSWorldScripts`) needs `cxx_worldScriptsByName` / `cxx_worldScriptNames` as C++:
  slice 27.
- **Slice beads** (filed by `tools/gen-stories.py --sweep slices`): 1 oo-jx5np, 2 oo-m4tfc, 3
  oo-7pa3t, 4 oo-qvnwb, 5 oo-mmcfq, 6 oo-vzjco, 7 oo-5c466, 8 oo-ijf0s, 9 oo-qyjcv, 10 oo-9u9w6, 11
  oo-zxg1h, 12 oo-rqcfz, 13 oo-30g73, 14 oo-m8x1y, 15 oo-2lpiu, 16 oo-vqjjb, 17 oo-6tuef, 18
  oo-3fzv5, 19 oo-4tqku, 20 oo-dycza, 21 oo-a602n, 22 oo-mv49m, 23 oo-wt5jv, 24 oo-bj7u8, 25
  oo-hu1xk, 26 oo-cpam5, 27 oo-u1e9m, 28 oo-zn1vy.
- **oo-a70 is the umbrella.** It depends on the 28 slices, the category beads above (oo-9ht.156
  and oo-e1d among them) and this pre-split. Its acceptance is every slice's `--slice-done` (this plan and the four category
  plans), no `@implementation` left in `PlayerEntity*.mm`, and the guardrails.

```slice-plan
source: upstream/oolite/src/Core/Entities/PlayerEntity.mm
header: upstream/oolite/src/Core/Entities/PlayerEntity.h
header-decls: per-slice
header-names: by-use

slice 1: class shell: the C++ class, the façade, the adapter and the _cxxPlayer-> rewrite; sharedPlayer, init, deferredInit, dealloc
  +[PlayerEntity sharedPlayer]
  -[PlayerEntity init]
  -[PlayerEntity deferredInit]
  -[PlayerEntity dealloc]
  -[PlayerEntity suppressClangStuff]

slice 2: cargo pods, commodity data and credits, galaxy and chart coordinates, the current and previous system
  -[PlayerEntity cxx_setName:]
  -[PlayerEntity baseMass]
  -[PlayerEntity unloadAllCargoPodsForType:toManifest:]
  -[PlayerEntity unloadCargoPodsForType:amount:]
  -[PlayerEntity unloadCargoPods]
  -[PlayerEntity createCargoPodWithType:andAmount:]
  -[PlayerEntity loadCargoPodsForType:fromManifest:]
  -[PlayerEntity loadCargoPodsForType:amount:]
  -[PlayerEntity loadCargoPods]
  -[PlayerEntity shipCommodityData]
  -[PlayerEntity deciCredits]
  -[PlayerEntity random_factor]
  -[PlayerEntity setRandom_factor:]
  -[PlayerEntity galaxyNumber]
  -[PlayerEntity galaxy_coordinates]
  -[PlayerEntity setGalaxyCoordinates:]
  -[PlayerEntity cursor_coordinates]
  -[PlayerEntity chart_centre_coordinates]
  -[PlayerEntity chart_zoom]
  -[PlayerEntity custom_chart_zoom]
  -[PlayerEntity setCustomChartZoom:]
  -[PlayerEntity custom_chart_centre_coordinates]
  -[PlayerEntity setCustomChartCentre:]
  -[PlayerEntity adjusted_chart_centre]
  -[PlayerEntity ANAMode]
  -[PlayerEntity systemID]
  -[PlayerEntity setSystemID:]
  -[PlayerEntity previousSystemID]
  -[PlayerEntity setPreviousSystemID:]

slice 3: target, next-hop and info systems, the wormhole, the commander data dictionary (save)
  -[PlayerEntity targetSystemID]
  -[PlayerEntity setTargetSystemID:]
  -[PlayerEntity nextHopTargetSystemID]
  -[PlayerEntity infoSystemID]
  -[PlayerEntity setInfoSystemID:moveChart:]
  -[PlayerEntity nextInfoSystem]
  -[PlayerEntity previousInfoSystem]
  -[PlayerEntity homeInfoSystem]
  -[PlayerEntity targetInfoSystem]
  -[PlayerEntity infoSystemOnRoute]
  -[PlayerEntity wormhole]
  -[PlayerEntity setWormhole:]
  -[PlayerEntity cxx_commanderDataDictionary]

slice 4: setting the commander data from a dictionary (load)
  -[PlayerEntity cxx_setCommanderDataFromDictionary:]

slice 5: set-up and start-up, ship set-up from the dictionary, the session, warning about hostiles
  -[PlayerEntity setUpAndConfirmOK:]
  -[PlayerEntity setUpAndConfirmOK:saveGame:]
  -[PlayerEntity completeSetUp]
  -[PlayerEntity completeSetUpAndSetTarget:]
  -[PlayerEntity startUpComplete]
  -[PlayerEntity setUpShipFromDictionary:]
  -[PlayerEntity sessionID]
  -[PlayerEntity warnAboutHostiles]
  -[PlayerEntity canCollide]

slice 6: sun glare, the atmosphere, update:
  -[PlayerEntity compareZeroDistance:]
  -[PlayerEntity validForAddToUniverse]
  -[PlayerEntity lookingAtSunWithThresholdAngleCos:]
  -[PlayerEntity insideAtmosphereFraction]
  -[PlayerEntity update:]

slice 7: the bookkeeping tick (doBookkeeping:), movement flags
  -[PlayerEntity doBookkeeping:]
  -[PlayerEntity updateMovementFlags]

slice 8: alert conditions, mass lock, fuel scoops, clocks, script and trumble ticks, the autopilot and docking requests
  -[PlayerEntity updateAlertConditionForNearbyEntities]
  -[PlayerEntity setMaxFlightPitch:]
  -[PlayerEntity setMaxFlightRoll:]
  -[PlayerEntity setMaxFlightYaw:]
  -[PlayerEntity checkEntityForMassLock:withScanClass:]
  -[PlayerEntity updateAlertCondition]
  -[PlayerEntity updateFuelScoops:]
  -[PlayerEntity updateClocks:]
  -[PlayerEntity checkScriptsIfAppropriate]
  -[PlayerEntity updateTrumbles:]
  -[PlayerEntity performAutopilotUpdates:]
  -[PlayerEntity performDockingRequest:]
  -[PlayerEntity requestDockingClearance:]
  -[PlayerEntity cancelDockingRequest:]
  -[PlayerEntity engageAutopilotToStation:]
  -[PlayerEntity disengageAutopilot]

slice 9: the autopilot AI, hyperspeed, in-flight / witchspace / launch / docking / dead updates, game over, the ship model view, targeting
  -[PlayerEntity resetAutopilotAI]
  -[PlayerEntity hyperspeedFactor]
  -[PlayerEntity injectorsEngaged]
  -[PlayerEntity hyperspeedEngaged]
  -[PlayerEntity performInFlightUpdates:]
  -[PlayerEntity performWitchspaceCountdownUpdates:]
  -[PlayerEntity performWitchspaceExitUpdates:]
  -[PlayerEntity performLaunchingUpdates:]
  -[PlayerEntity performDockingUpdates:]
  -[PlayerEntity performDeadUpdates:]
  -[PlayerEntity gameOverFadeToBW]
  -[PlayerEntity isValidTarget:]
  -[PlayerEntity showGameOver]
  -[PlayerEntity cxx_showShipModelWithKey:shipData:personality:factorX:factorY:factorZ:inContext:]
  -[PlayerEntity updateTargeting]

slice 10: attitude, view matrices and viewpoints, drawing, mass lock, the docked station, the HUD and its custom dials, shield levels
  -[PlayerEntity orientationChanged]
  -[PlayerEntity applyAttitudeChanges:]
  -[PlayerEntity applyRoll:andClimb:]
  -[PlayerEntity applyYaw:]
  -[PlayerEntity drawRotationMatrix]
  -[PlayerEntity drawTransformationMatrix]
  -[PlayerEntity normalOrientation]
  -[PlayerEntity setNormalOrientation:]
  -[PlayerEntity moveForward:]
  -[PlayerEntity breakPatternPosition]
  -[PlayerEntity viewpointOffset]
  -[PlayerEntity viewpointOffsetAft]
  -[PlayerEntity viewpointOffsetForward]
  -[PlayerEntity viewpointOffsetPort]
  -[PlayerEntity viewpointOffsetStarboard]
  -[PlayerEntity viewpointPosition]
  -[PlayerEntity drawImmediate:translucent:]
  -[PlayerEntity setMassLockable:]
  -[PlayerEntity massLockable]
  -[PlayerEntity massLocked]
  -[PlayerEntity atHyperspeed]
  -[PlayerEntity occlusionLevel]
  -[PlayerEntity setOcclusionLevel:]
  -[PlayerEntity setDockedAtMainStation]
  -[PlayerEntity dockedStation]
  -[PlayerEntity setDockedStation:]
  -[PlayerEntity setTargetDockStationTo:]
  -[PlayerEntity getTargetDockStation]
  -[PlayerEntity hud]
  -[PlayerEntity resetHud]
  -[PlayerEntity cxx_switchHudTo:]
  -[PlayerEntity cxx_dialCustomFloat:]
  -[PlayerEntity cxx_dialCustomString:]
  -[PlayerEntity cxx_dialCustomColor:]
  -[PlayerEntity cxx_setDialCustom:forKey:]
  -[PlayerEntity setShowDemoShips:]
  -[PlayerEntity showDemoShips]
  -[PlayerEntity maxForwardShieldLevel]
  -[PlayerEntity maxAftShieldLevel]
  -[PlayerEntity forwardShieldRechargeRate]
  -[PlayerEntity aftShieldRechargeRate]
  -[PlayerEntity setMaxForwardShieldLevel:]
  -[PlayerEntity setMaxAftShieldLevel:]
  -[PlayerEntity setForwardShieldRechargeRate:]
  -[PlayerEntity setAftShieldRechargeRate:]
  -[PlayerEntity forwardShieldLevel]
  -[PlayerEntity aftShieldLevel]
  -[PlayerEntity setForwardShieldLevel:]
  -[PlayerEntity setAftShieldLevel:]
  -[PlayerEntity cxx_keyConfig]
  -[PlayerEntity isMouseControlOn]
  -[PlayerEntity dialRoll]
  -[PlayerEntity dialPitch]
  -[PlayerEntity dialYaw]
  -[PlayerEntity dialSpeed]
  -[PlayerEntity dialHyperSpeed]
  -[PlayerEntity dialForwardShield]

slice 11: the dials (shields, energy, fuel, heat, altitude, clock, missiles, scoop), fuel leak, the comm log, player roles, system memory, the compass target
  -[PlayerEntity dialAftShield]
  -[PlayerEntity dialEnergy]
  -[PlayerEntity dialMaxEnergy]
  -[PlayerEntity dialFuel]
  -[PlayerEntity dialHyperRange]
  -[PlayerEntity laserHeatLevel]
  -[PlayerEntity laserHeatLevelAft]
  -[PlayerEntity laserHeatLevelForward]
  -[PlayerEntity laserHeatLevelPort]
  -[PlayerEntity laserHeatLevelStarboard]
  -[PlayerEntity dialAltitude]
  -[PlayerEntity clockTime]
  -[PlayerEntity clockTimeAdjusted]
  -[PlayerEntity clockAdjusting]
  -[PlayerEntity addToAdjustTime:]
  -[PlayerEntity escapePodRescueTime]
  -[PlayerEntity setEscapePodRescueTime:]
  -[PlayerEntity cxx_dial_clock]
  -[PlayerEntity cxx_dial_clock_adjusted]
  -[PlayerEntity cxx_dial_fpsinfo]
  -[PlayerEntity cxx_dial_objinfo]
  -[PlayerEntity countMissiles]
  -[PlayerEntity dialMissileStatus]
  -[PlayerEntity canScoop:]
  -[PlayerEntity dialFuelScoopStatus]
  -[PlayerEntity fuelLeakRate]
  -[PlayerEntity setFuelLeakRate:]
  -[PlayerEntity cxx_commLog]
  -[PlayerEntity cxx_roleWeights]
  -[PlayerEntity addRoleForAggression:]
  -[PlayerEntity addRoleForMining]
  -[PlayerEntity cxx_addRoleToPlayer:]
  -[PlayerEntity cxx_addRoleToPlayer:inSlot:]
  -[PlayerEntity clearRoleFromPlayer:]
  -[PlayerEntity clearRolesFromPlayer:]
  -[PlayerEntity maxPlayerRoles]
  -[PlayerEntity updateSystemMemory]
  -[PlayerEntity compassTarget]
  -[PlayerEntity setCompassTarget:]
  -[PlayerEntity validateCompassTarget]
  -[PlayerEntity cxx_compassTargetLabel]

slice 12: compass mode, missiles and pylons, special cargo, the multi-function displays, alert flags
  -[PlayerEntity compassMode]
  -[PlayerEntity setCompassMode:]
  -[PlayerEntity setPrevCompassMode]
  -[PlayerEntity setNextCompassMode]
  -[PlayerEntity activeMissile]
  -[PlayerEntity setActiveMissile:]
  -[PlayerEntity dialMaxMissiles]
  -[PlayerEntity dialIdentEngaged]
  -[PlayerEntity setDialIdentEngaged:]
  -[PlayerEntity cxx_specialCargo]
  -[PlayerEntity cxx_dialTargetName]
  -[PlayerEntity cxx_multiFunctionDisplayList]
  -[PlayerEntity cxx_multiFunctionText:]
  -[PlayerEntity cxx_setMultiFunctionText:forKey:]
  -[PlayerEntity cxx_setMultiFunctionDisplay:toKey:]
  -[PlayerEntity cycleNextMultiFunctionDisplay:]
  -[PlayerEntity cyclePreviousMultiFunctionDisplay:]
  -[PlayerEntity selectNextMultiFunctionDisplay]
  -[PlayerEntity selectPreviousMultiFunctionDisplay]
  -[PlayerEntity activeMFD]
  -[PlayerEntity missileForPylon:]
  -[PlayerEntity safeAllMissiles]
  -[PlayerEntity tidyMissilePylons]
  -[PlayerEntity selectNextMissile]
  -[PlayerEntity clearAlertFlags]
  -[PlayerEntity alertFlags]
  -[PlayerEntity setAlertFlag:to:]
  -[PlayerEntity realAlertCondition]

slice 13: alert condition, AI messages, mounting and firing missiles and mines, the cloak, ECM, energy units, the main weapons
  -[PlayerEntity alertCondition]
  -[PlayerEntity fleeingStatus]
  -[PlayerEntity interpretAIMessage:]
  -[PlayerEntity mountMissile:]
  -[PlayerEntity cxx_mountMissileWithRole:]
  -[PlayerEntity fireMissile]
  -[PlayerEntity launchMine:]
  -[PlayerEntity cxx_assignToActivePylon:]
  -[PlayerEntity activateCloakingDevice]
  -[PlayerEntity deactivateCloakingDevice]
  -[PlayerEntity scannerFuzziness]
  -[PlayerEntity noticeECM]
  -[PlayerEntity fireECM]
  -[PlayerEntity installedEnergyUnitType]
  -[PlayerEntity energyUnitType]
  -[PlayerEntity currentWeaponStats]
  -[PlayerEntity weaponsOnline]
  -[PlayerEntity setWeaponsOnline:]
  -[PlayerEntity cxx_currentLaserOffset]
  -[PlayerEntity fireMainWeapon]
  -[PlayerEntity weaponForFacing:]
  -[PlayerEntity currentWeapon]

slice 14: hit testing, damage, the doppelganger, the escape capsule, dumping cargo, bounty
  -[PlayerEntity doesHitLine:v0:v1:]
  -[PlayerEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]
  -[PlayerEntity takeScrapeDamage:from:]
  -[PlayerEntity takeHeatDamage:]
  -[PlayerEntity createDoppelganger]
  -[PlayerEntity launchEscapeCapsule]
  -[PlayerEntity dumpCargo]
  -[PlayerEntity rotateCargo]
  -[PlayerEntity setBounty:]
  -[PlayerEntity setBounty:withReason:]
  -[PlayerEntity setBounty:withReasonAsString:]

slice 15: legal status, offences, bounties collected, internal damage, destruction, ending a scenario, docking and leaving dock
  -[PlayerEntity bounty]
  -[PlayerEntity legalStatus]
  -[PlayerEntity markAsOffender:]
  -[PlayerEntity markAsOffender:withReason:]
  -[PlayerEntity collectBountyFor:]
  -[PlayerEntity takeInternalDamage]
  -[PlayerEntity getDestroyedBy:damageType:]
  -[PlayerEntity loseTargetStatus]
  -[PlayerEntity cxx_endScenario:]
  -[PlayerEntity enterDock:]
  -[PlayerEntity docked]
  -[PlayerEntity leaveDock:]

slice 16: witchspace: start, end, checklist, jump type and distance, fuel, galactic and wormhole jumps
  -[PlayerEntity witchStart]
  -[PlayerEntity witchEnd]
  -[PlayerEntity witchJumpChecklist:]
  -[PlayerEntity setJumpType:]
  -[PlayerEntity hyperspaceJumpDistance]
  -[PlayerEntity fuelRequiredForJump]
  -[PlayerEntity hasSufficientFuelForJump]
  -[PlayerEntity noteCompassLostTarget]
  -[PlayerEntity enterGalacticWitchspace]
  -[PlayerEntity enterWormhole:]
  -[PlayerEntity enterWitchspace]
  -[PlayerEntity witchJumpTo:misjump:]

slice 17: leaving witchspace, the status screen, the equipment list, primed and fast equipment, weapon types
  -[PlayerEntity leaveWitchspace]
  -[PlayerEntity setGuiToStatusScreen]
  -[PlayerEntity cxx_equipmentList]
  -[PlayerEntity primedEquipmentCount]
  -[PlayerEntity cxx_primedEquipmentName:]
  -[PlayerEntity cxx_currentPrimedEquipment]
  -[PlayerEntity cxx_setPrimedEquipment:showMessage:]
  -[PlayerEntity activatePrimableEquipment:withMode:]
  -[PlayerEntity cxx_fastEquipmentA]
  -[PlayerEntity cxx_fastEquipmentB]
  -[PlayerEntity cxx_setFastEquipmentA:]
  -[PlayerEntity cxx_setFastEquipmentB:]
  -[PlayerEntity weaponTypeForFacing:strict:]

slice 18: scripting lists (missiles, cargo, contracts), the system data screen, marked destinations, the chart screens
  -[PlayerEntity missilesList]
  -[PlayerEntity cxx_cargoList]
  -[PlayerEntity cargoListForScripting]
  -[PlayerEntity legalStatusOfCargoList]
  -[PlayerEntity contractsListForScriptingFromArray:forCargo:]
  -[PlayerEntity passengerListForScripting]
  -[PlayerEntity parcelListForScripting]
  -[PlayerEntity contractListForScripting]
  -[PlayerEntity setGuiToSystemDataScreen]
  -[PlayerEntity setGuiToSystemDataScreenRefreshBackground:]
  -[PlayerEntity cxx_markedDestinations]
  -[PlayerEntity setGuiToLongRangeChartScreen]
  -[PlayerEntity setGuiToShortRangeChartScreen]
  -[PlayerEntity setGuiToChartScreenFrom:]

slice 19: the game options and load / save screens, equip-screen key highlight, available facings
  -[PlayerEntity setGuiToGameOptionsScreen]
  -[PlayerEntity setGuiToLoadSaveScreen]
  -[PlayerEntity highlightEquipShipScreenKey:]
  -[PlayerEntity availableFacings]

slice 20: the equip-ship screen and upgrade information
  -[PlayerEntity cxx_setGuiToEquipShipScreen:selectingFacingFor:]
  -[PlayerEntity setGuiToEquipShipScreen:]
  -[PlayerEntity showInformationForSelectedUpgrade]
  -[PlayerEntity cxx_showInformationForSelectedUpgradeWithFormatString:]

slice 21: the interfaces screen, the start screen and intro, the OXZ manager, GUI and view change notes
  -[PlayerEntity setGuiToInterfacesScreen:]
  -[PlayerEntity showInformationForSelectedInterface]
  InterfaceForKey()
  -[PlayerEntity activateSelectedInterface]
  -[PlayerEntity setupStartScreenGui]
  -[PlayerEntity setGuiToIntroFirstGo:]
  -[PlayerEntity setGuiToOXZManager]
  -[PlayerEntity noteGUIWillChangeTo:]
  -[PlayerEntity noteGUIDidChangeFrom:to:]
  -[PlayerEntity noteGUIDidChangeFrom:to:refresh:]
  -[PlayerEntity noteViewDidChangeFrom:toView:]

slice 22: buying equipment, script price adjustment, weapon mounts, passenger berths, removing missiles, trade-in
  -[PlayerEntity buySelectedItem]
  -[PlayerEntity cxx_adjustPriceByScriptForEqKey:withCurrent:]
  -[PlayerEntity tryBuyingItem:]
  -[PlayerEntity setWeaponMount:toWeapon:]
  -[PlayerEntity cxx_setWeaponMount:toWeapon:inContext:]
  -[PlayerEntity changePassengerBerths:]
  -[PlayerEntity removeMissiles]
  -[PlayerEntity doTradeIn:forPriceFactor:]

slice 23: cargo quantities, the local market, market filters and sorters, market screen rows
  -[PlayerEntity cxx_cargoQuantityForType:]
  -[PlayerEntity cxx_setCargoQuantityForType:amount:]
  -[PlayerEntity calculateCurrentCargo]
  -[PlayerEntity cargoQuantityOnBoard]
  -[PlayerEntity localMarket]
  -[PlayerEntity cxx_applyMarketFilter:onMarket:]
  -[PlayerEntity cxx_applyMarketSorter:onMarket:]
  marketSorterByName()
  marketSorterByPrice()
  marketSorterByQuantity()
  marketSorterByMassUnit()
  -[PlayerEntity showMarketScreenHeaders]
  -[PlayerEntity showMarketScreenDataLine:forGood:inMarket:holdQuantity:]
  -[PlayerEntity marketScreenTitle]

slice 24: the market screens, buying and selling commodities, mining and speech flags, adding equipment
  -[PlayerEntity setGuiToMarketScreen]
  -[PlayerEntity setGuiToMarketInfoScreen]
  -[PlayerEntity showMarketCashAndLoadLine]
  -[PlayerEntity guiScreen]
  -[PlayerEntity cxx_tryBuyingCommodity:all:]
  -[PlayerEntity cxx_trySellingCommodity:all:]
  -[PlayerEntity isMining]
  -[PlayerEntity isSpeechOn]
  -[PlayerEntity canAddEquipment:inContext:]
  -[PlayerEntity addEquipmentItem:inContext:]

slice 25: adding / removing / custom-activated equipment, pylons, parcels and passengers, comms, fines, trade-in factor, renovation, view offsets, trumbles
  -[PlayerEntity addEquipmentItem:withValidation:inContext:]
  -[PlayerEntity cxx_customEquipmentActivation]
  -[PlayerEntity addEquipmentWithScriptToCustomKeyArray:]
  -[PlayerEntity validateCustomEquipActivationArray]
  -[PlayerEntity removeEquipmentItem:]
  -[PlayerEntity addEquipmentFromCollection:]
  -[PlayerEntity hasOneEquipmentItem:includeMissiles:]
  -[PlayerEntity hasPrimaryWeapon:]
  -[PlayerEntity removeExternalStore:]
  -[PlayerEntity removeFromPylon:]
  -[PlayerEntity parcelCount]
  -[PlayerEntity passengerCount]
  -[PlayerEntity passengerCapacity]
  -[PlayerEntity hasHostileTarget]
  -[PlayerEntity receiveCommsMessage:from:]
  -[PlayerEntity getFined]
  -[PlayerEntity adjustTradeInFactorBy:]
  -[PlayerEntity tradeInFactor]
  -[PlayerEntity renovationCosts]
  -[PlayerEntity renovationFactor]
  -[PlayerEntity setDefaultViewOffsets]
  -[PlayerEntity setDefaultCustomViews]
  -[PlayerEntity weaponViewOffset]
  -[PlayerEntity setUpTrumbles]
  -[PlayerEntity addTrumble:]
  -[PlayerEntity removeTrumble:]
  -[PlayerEntity trumbleArray]
  -[PlayerEntity trumbleCount]

slice 26: trumble values, checksums, screen modes, target memory, missile ident, rotating and panning the custom view
  -[PlayerEntity trumbleValue]
  -[PlayerEntity setTrumbleValueFrom:]
  -[PlayerEntity trumbleAppetiteAccumulator]
  -[PlayerEntity setTrumbleAppetiteAccumulator:]
  -[PlayerEntity mungChecksumWithString:]
  -[PlayerEntity cxx_screenModeStringForWidth:height:refreshRate:]
  -[PlayerEntity suppressTargetLost]
  -[PlayerEntity setScoopsActive]
  -[PlayerEntity setFoundTarget:]
  -[PlayerEntity addTarget:]
  -[PlayerEntity clearTargetMemory]
  -[PlayerEntity cxx_targetMemory]
  -[PlayerEntity moveTargetMemoryBy:]
  -[PlayerEntity printIdentLockedOnForMissile:]
  -[PlayerEntity customViewQuaternion]
  -[PlayerEntity setCustomViewQuaternion:]
  -[PlayerEntity customViewMatrix]
  -[PlayerEntity customViewOffset]
  -[PlayerEntity setCustomViewOffset:]
  -[PlayerEntity customViewRotationCenter]
  -[PlayerEntity setCustomViewRotationCenter:]
  -[PlayerEntity customViewZoomIn:]
  -[PlayerEntity customViewZoomOut:]
  -[PlayerEntity customViewRotateLeft:]
  -[PlayerEntity customViewRotateRight:]
  -[PlayerEntity customViewRotateUp:]
  -[PlayerEntity customViewRotateDown:]
  -[PlayerEntity customViewRollRight:]
  -[PlayerEntity customViewRollLeft:]
  -[PlayerEntity customViewPanUp:]
  -[PlayerEntity customViewPanDown:]

slice 27: custom view vectors and data, the mission overlay and background, world scripts and script events, galactic hyperspace, jump cause, commander and save names
  -[PlayerEntity customViewPanLeft:]
  -[PlayerEntity customViewPanRight:]
  -[PlayerEntity customViewForwardVector]
  -[PlayerEntity customViewUpVector]
  -[PlayerEntity customViewRightVector]
  -[PlayerEntity cxx_customViewDescription]
  -[PlayerEntity resetCustomView]
  -[PlayerEntity setCustomViewData]
  -[PlayerEntity cxx_setCustomViewDataFromDictionary:withScaling:]
  -[PlayerEntity showInfoFlag]
  -[PlayerEntity cxx_missionOverlayDescriptor]
  -[PlayerEntity cxx_missionOverlayDescriptorOrDefault]
  -[PlayerEntity cxx_setMissionOverlayDescriptor:]
  -[PlayerEntity cxx_missionBackgroundDescriptor]
  -[PlayerEntity cxx_missionBackgroundDescriptorOrDefault]
  -[PlayerEntity cxx_setMissionBackgroundDescriptor:]
  -[PlayerEntity missionBackgroundSpecial]
  -[PlayerEntity cxx_setMissionBackgroundSpecial:]
  -[PlayerEntity setMissionExitScreen:]
  -[PlayerEntity missionExitScreen]
  -[PlayerEntity cxx_equipScreenBackgroundDescriptor]
  -[PlayerEntity cxx_setEquipScreenBackgroundDescriptor:]
  -[PlayerEntity scriptsLoaded]
  -[PlayerEntity cxx_worldScriptNames]
  -[PlayerEntity cxx_worldScriptsByName]
  -[PlayerEntity cxx_commodityScriptNamed:]
  -[PlayerEntity doScriptEvent:inContext:withArguments:count:]
  -[PlayerEntity doWorldEventUntilMissionScreen:]
  -[PlayerEntity doWorldScriptEvent:inContext:withArguments:count:timeLimit:]
  -[PlayerEntity setGalacticHyperspaceBehaviour:]
  -[PlayerEntity galacticHyperspaceBehaviour]
  -[PlayerEntity setGalacticHyperspaceFixedCoords:]
  -[PlayerEntity setGalacticHyperspaceFixedCoordsX:y:]
  -[PlayerEntity galacticHyperspaceFixedCoords]
  -[PlayerEntity setWitchspaceCountdown:]
  -[PlayerEntity longRangeChartMode]
  -[PlayerEntity setLongRangeChartMode:]
  -[PlayerEntity scoopOverride]
  -[PlayerEntity setScoopOverride:]
  -[PlayerEntity fuelChargeRate]
  -[PlayerEntity setDockTarget:]
  -[PlayerEntity cxx_jumpCause]
  -[PlayerEntity cxx_setJumpCause:]
  -[PlayerEntity cxx_commanderName]
  -[PlayerEntity cxx_lastsaveName]
  -[PlayerEntity cxx_setCommanderName:]
  -[PlayerEntity cxx_setLastsaveName:]

slice 28: docking clearance, scanned wormholes, mission destinations, the shipyard record, extra mission and GUI-screen keys, the state dump
  -[PlayerEntity isDocked]
  -[PlayerEntity clearedToDock]
  -[PlayerEntity setDockingClearanceStatus:]
  -[PlayerEntity getDockingClearanceStatus]
  -[PlayerEntity penaltyForUnauthorizedDocking]
  -[PlayerEntity addScannedWormhole:]
  -[PlayerEntity updateWormholes]
  -[PlayerEntity cxx_scannedWormholes]
  -[PlayerEntity initialiseMissionDestinations:andLegacy:]
  -[PlayerEntity markerKey:]
  -[PlayerEntity cxx_addMissionDestinationMarker:]
  -[PlayerEntity cxx_removeMissionDestinationMarker:]
  -[PlayerEntity cxx_getMissionDestinations]
  -[PlayerEntity cxx_shipyardRecord]
  -[PlayerEntity cxx_setLastShot:]
  -[PlayerEntity clearExtraMissionKeys]
  -[PlayerEntity cxx_setExtraMissionKeys:]
  -[PlayerEntity cxx_clearExtraGuiScreenKeys:key:]
  -[PlayerEntity setExtraGuiScreenKeys:definition:]
  -[PlayerEntity dumpSelfState]

verbatim: plain C, no Objective-C
  StringForKey()
  PointFromCoordinates()
  QuaternionForKey()
  ValueForKey()
  StringAt()
  CoordinateTokens()
  CoordinateAt()
  ExpandKeyWithSeed()
  TextArg()
  IndexOfGood()
  CustomViewsFrom()
  RoleFlagCount()
  SystemListPList()
  RowOf()
  EquipmentRow()
  RowKeyField()
  OptionalKeyPList()
  OoliteInfoString()
  PrepareMarkedDestination()
  SliderString()
```
