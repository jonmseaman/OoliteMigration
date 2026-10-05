# Slice plan: ShipEntity

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-9ht.140; the class is the frontier giant
oo-k8a). Checked by `python3 tools/check-slice-plan.py docs/phases/3-slices/ShipEntity.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/ShipEntity.mm` (15,093 lines) + header (1,334 lines). One class,
  `ShipEntity : OOEntityWithDrawable <OOSubEntity, OOBeaconEntity>`, whose ~640 methods are a
  single `@implementation` with no `#pragma mark` sections, so "category by category" does not
  apply inside the file: the slices follow the order of the file, which already groups related
  methods (set-up, subentities, beacons and escorts, equipment, the `behaviour_*` family, drawing,
  roles, aegis and fuel, cargo, flight controls, damage and explosions, targets and tracking,
  weapons, missiles, collisions and scooping, docking and witchspace, comms, script events). Two
  small categories sit at the end, `Entity (SubEntityRelationship)` and
  `ShipEntity (SubEntityRelationship)`. The other `ShipEntity` categories have their own files and
  plans or beads (below).
- **The header is charged per slice** (`header-decls: per-slice`, new in
  `tools/check-slice-plan.py`, bead oo-9ht.140). The header alone is 1,334 lines, so charging it
  whole to every slice (header + preamble is already 1,551) leaves no slice under the budget. A
  slice needs the header's macros, types and ivar block (~710 lines) and the declarations of its
  own methods; the other ~620 lines are the other slices' method declarations. The checker
  charges exactly that, matching each declaration to its unit by `-[Class selector]`. Slice 1
  moves the method declarations into the façade header verbatim (a cut and paste, read by no one).
- **Order:** after the `ooentity` pattern seam (oo-bj8, landed) and this pre-split. Slice 1 first;
  slices 2-34 each wait on slice 1 and are then independent of each other. Thirty-three of them
  are fleet stories; slice 1 is frontier.
- **Verbatim:** the plist and string helpers above the `@implementation` (`KeysPList()` …
  `NamesInArrayForKey()`, `ShipGroupCursorBatch()`) and the two comparators inside it
  (`IsBehaviourHostile()`, `ComparePlanetsBySurfaceDistance()`) have no Objective-C and stay
  verbatim ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9).
  `calcFuelChargeRate()` sends messages, so it moves with `fuelChargeRate` (slice 19), and the
  shader and weapon-range helpers at the end of the file with slice 34.

## Slice 1: the class shell (frontier)

Slice 1 is the `Entity` pattern ([ADR-0056](../../decisions/0056-phase3-class-conversion-house-style.md)
amendment oo-bj8) applied to the biggest class, and it is the only slice that is not story-sized:
its *own* units are four (`init`, `initBypassForPlayer`, `cxx_initWithKey:definition:`,
`dealloc`, ~145 lines with the two `SubEntityRelationship` categories), but it moves the class.

1. **`cxx::ShipEntity : cxx::OOEntityWithDrawable`** in `ShipEntity.h`, global as amendment oo-bj8
   item 12 says for a leaf: the 186 ivars become data members by the same names, every one
   zero-initialised (item 1). The `@public` and `@protected` ones are public (item 1). The ~40
   `@private` ones are public too while the class is half converted, because the façade's
   unconverted methods read them and an Objective-C class cannot be a C++ friend; they are marked
   `// private once ShipEntity is converted (oo-k8a)`, and the façade's deletion bead makes them
   private again. The macros, enums and C declarations above the `@interface` stay.
2. **The façade** `@interface ShipEntity : OOEntityWithDrawable <OOSubEntity, OOBeaconEntity>` in
   `ShipEntity+ObjCBridge.h/.mm`, imported as the last line of `ShipEntity.h`: every method
   declaration of the old `@interface` and of `ShipEntity (Debug)` copied exactly, and the
   `Entity (SubEntityRelationship)` category moved there (item 12: a category of `Entity` in the
   file moves to `X+ObjCBridge.mm`). The `ShipScriptEvent` macros stay with the declarations.
   The façade's `-init` makes `oo::ObjCEntity<cxx::ShipEntity>` (item 5) for the four Objective-C
   subclasses (`StationEntity`, `DockEntity`, `PlayerEntity`, `ProxyPlayerEntity`), and
   `oo::NewEntityFacade`'s chain gains its line. `-dealloc` stays in the façade (item 7).
3. **The unconverted methods keep their bodies and reach the members through a typed view.** The
   root's `_cxxEntity` is a `cxx::Entity`, so the ship's members need a `cxx::ShipEntity *`.
   Recommended default (slice 1 records it as an ADR-0056 amendment): the façade has one `@public`
   ivar `cxx::ShipEntity *_cxxShip`, a borrowed, typed alias of `_cxxEntity` set by the
   initialiser beside it, never owning. The rewrite is item 2's, compiler-guided: with the ivars
   gone, insert `_cxxShip->` at every "use of undeclared identifier" / "no member named" error that
   names one (in `ShipEntity.mm`'s ~630 unconverted methods, the categories `ShipEntityAI.mm`,
   `ShipEntityScriptMethods.mm`, `ShipEntityLoadRestore.mm`, the subclasses), and `ship->_cxxShip->x`
   where other files read `ship->x` (the HUD, `Universe`, `OOJSShip`, the AI). Then build once with
   poison ivars of the old names to prove no bare use bound to another declaration. oo-bj8's
   codemod is `.agent-tmp/cc/bj8/codemod.py`. The edit is far over 400 written lines but has no
   judgement in it; each later slice deletes `_cxxShip->` from its own bodies to get them back
   verbatim. `SHIP_ENERGY_DAMAGE_TO_HEAT_FACTOR` already reads `_cxxEntity->mass` and is unchanged.
4. **Test first:** `tests/unit/core/test_ShipEntity.mm` against the Objective-C API, run on the
   unconverted class, then ported (amendment oo-bj8 item 11's harness). Slice 1 files the
   "Delete ShipEntity+ObjCBridge" bead (like oo-9ht.1), which waits on the umbrella oo-k8a.

## Slices 2-34 (fleet)

Each slice moves its units into `cxx::ShipEntity` as member functions, declares them in the class,
leaves a forwarder on the façade for each (the selectors are messaged from ~100 files and called
by name from AI plists, ADR-0043 item 21), and deletes `_cxxShip->` from the moved bodies. A method
that a subclass overrides (the dependency table below) becomes `virtual` and gets its adapter line
in the same slice. Calls from a converted body to a method of a slice that has not landed stay
sends to `oo::ToObjC(this)`.

| Slice | Content | Own lines | Reads (header part + preamble + own) |
|---|---|---:|---:|
| 1 | class shell (frontier): the C++ class, the façade, the adapter, the `_cxxShip->` rewrite; `init`, `dealloc`, `SubEntityRelationship` | ~145 | ~1,079 |
| 2 | set-up from the ship dictionary (`cxx_setUpFromDictionary:`) | ~276 | ~1,206 |
| 3 | `setUpShipFromDictionary:`, subentity serialisation and set-up | ~407 | ~1,345 |
| 4 | standard subentities and cargo pods; descriptions, mesh, vectors, misjump, subentity lists, AI scripts | ~421 | ~1,386 |
| 5 | bounding boxes, octree hit tests, universe add / remove, beacons, boulders, escort set-up | ~449 | ~1,390 |
| 6 | escort creation, ship data key, weapon offsets, octree collision checks, subentity geometry, escape-pod launch | ~449 | ~1,391 |
| 7 | `update:` | ~474 | ~1,403 |
| 8 | behaviour dispatch, attack response, equipment queries | ~434 | ~1,379 |
| 9 | equipment validity and adding, weapon mounts, scripting lists | ~438 | ~1,384 |
| 10 | equipment removal, missile selection, capacities and has-equipment predicates, shields | ~449 | ~1,414 |
| 11 | thrust and afterburner; behaviours: idle, tumble, tractored, track, intercept, break off, dogfight, evasive | ~464 | ~1,410 |
| 12 | behaviours: attack target, broadside, close with target | ~478 | ~1,414 |
| 13 | behaviours: sniper, fly to target six, mining target, attack fly to target | ~432 | ~1,365 |
| 14 | behaviours: fly from target, running defence, flee, range from destination, face destination, land on planet, formation | ~380 | ~1,316 |
| 15 | behaviours: fly to / from destination, avoid collision, turret, navpoints, scripted AI; reaction time | ~464 | ~1,402 |
| 16 | tracking curve, drawing, scanner colours, cloaking, subentities and owner, thrust | ~465 | ~1,411 |
| 17 | attitude, collision avoidance, messages, groups and escort accessors, proximity alert, names and descriptions | ~441 | ~1,405 |
| 18 | roles, ship-type predicates, hostility, weapon data, scanner range, aegis transition, nearest planet | ~413 | ~1,385 |
| 19 | aegis, home and destination systems, status, crew, AI and ship script, fuel | ~451 | ~1,411 |
| 20 | sticks, bounty and legal status, commodities and cargo, speed | ~452 | ~1,418 |
| 21 | flight controls and limits, temperature, dealing damage, hulks, damage notes | ~438 | ~1,412 |
| 22 | destruction, rescaling, cargo debris, explosions, energy blast | ~476 | ~1,412 |
| 23 | subentity death, alignment offsets, large explosion, laser heat, personality, scanner, remembered ships | ~462 | ~1,417 |
| 24 | target memory and validity, behaviour and destination accessors, distances, leading the target | ~434 | ~1,389 |
| 25 | evasive jink, primary and side target tracking | ~420 | ~1,353 |
| 26 | missile and destination tracking, collision exceptions, defence targets, ranges | ~457 | ~1,409 |
| 27 | aim tolerance, sun glare, main weapons and turret fire, laser colours | ~443 | ~1,392 |
| 28 | laser shots, missed shots, sparks, missile launch decision | ~448 | ~1,388 |
| 29 | missile firing, ECM, cloak, cascade mine, escape capsule, cargo dumping | ~457 | ~1,400 |
| 30 | collisions, velocity, tractoring and scooping | ~444 | ~1,384 |
| 31 | cascades, energy / scrape / heat damage, abandoning ship, docks, wormholes, witchspace | ~469 | ~1,408 |
| 32 | witchspace effects, offences, lights, escort formation and deployment, nearest stations | ~456 | ~1,405 |
| 33 | landing, docking abort, broadcasts and comms, fines, AI messages, spawning, close contacts, salvage | ~460 | ~1,412 |
| 34 | salvage pilot, debug dump, script info, demo ship, script events and AI reactions, alert condition, shader helpers | ~423 | ~1,381 |
| verbatim | 18 plain-C helpers | — | not read |

## The category files, the subclasses and the other waiting beads

- **Category files** become members of `cxx::ShipEntity` in their own beads (amendment oo-o89
  item 4), each after slice 1: the four `ShipEntityAI.mm` slices
  ([plan](ShipEntityAI.md); oo-iebuz, oo-xurzn, oo-wc9o3, oo-lqyhf; AI slice 1 also waits on
  `StationEntity` slice 1, oo-64ako, for `StationEntity (OOAIPrivate)`),
  `ShipEntityScriptMethods.mm` (oo-42dr) and `ShipEntityLoadRestore.mm` (oo-kw44). None of them
  overrides a method of `ShipEntity.mm`.
- **Subclasses** wait on slice 1 and on each slice that holds a method they override (an override
  of a method that is still Objective-C cannot be a C++ `override`). Found by matching every
  method of the subclass files against this plan's units:

| Bead | Overrides `ShipEntity.mm` methods of slices |
|---|---|
| `StationEntity.mm` slice 1 (oo-64ako) | 1, 3, 4, 18, 34 |
| `StationEntity.mm` slice 2 (oo-9j462) | 7 (`update:`) |
| `StationEntity.mm` slice 3 (oo-hjzwk) | 18, 22, 23, 30, 31 |
| `StationEntity.mm` slice 4 (oo-tqem7) | none (waits on its slice 1) |
| `DockEntity.mm` (oo-ao2d) | 1, 3, 7, 16, 21, 31 |
| `ProxyPlayerEntity.mm` (oo-amwj) | 1, 34 |
| `PlayerEntity` (frontier oo-a70) | 25 of the 34: it waits on the umbrella oo-k8a |

- **`OOShipLibraryDescriptions.mm` (oo-xjgf)** turns its ten sends to `ShipEntity *demo_ship` into
  member calls, so it waits on the slices that hold them: 4 (`totalBoundingBox`), 8
  (`hasHyperspaceMotor`), 9 (`weaponFacings`), 10 (`missileCapacity`), 17 (`turretCount`), 18
  (`energyRechargeRate`), 20 (`maxAvailableCargoSpace`) and 21 (`maxFlightSpeed`,
  `maxFlightRoll`, `maxFlightPitch`), and slice 1.
- **The bridge-deletion beads** that waited on oo-k8a (`OOWeakSet`, `OOShipGroup`, `Octree`,
  `OOCharacter`, the effects and others whose façades `ShipEntity.mm` messages) keep waiting on the
  umbrella: they need every slice landed.
- **oo-k8a is the umbrella.** It depends on the 34 slices, the four AI slices, oo-42dr and oo-kw44.
  Its acceptance is every slice's `--slice-done` (this plan and `ShipEntityAI.md`), no
  `@implementation` left in the four `ShipEntity*.mm` files, and the guardrails.

```slice-plan
source: upstream/oolite/src/Core/Entities/ShipEntity.mm
header: upstream/oolite/src/Core/Entities/ShipEntity.h
header-decls: per-slice

slice 1: class shell: the C++ class, the façade, the adapter and the _cxxShip-> rewrite; init, dealloc, SubEntityRelationship
  @ShipEntity
  -[ShipEntity init]
  -[ShipEntity initBypassForPlayer]
  -[ShipEntity cxx_initWithKey:definition:]
  -[ShipEntity dealloc]
  @Entity(SubEntityRelationship)
  @ShipEntity(SubEntityRelationship)

slice 2: set-up from the ship dictionary (cxx_setUpFromDictionary:)
  -[ShipEntity cxx_setUpFromDictionary:]

slice 3: setUpShipFromDictionary:, subentity serialisation and set-up
  -[ShipEntity setUpShipFromDictionary:]
  -[ShipEntity setSubIdx:]
  -[ShipEntity subIdx]
  -[ShipEntity maxShipSubEntities]
  -[ShipEntity cxx_serializeShipSubEntities]
  -[ShipEntity cxx_deserializeShipSubEntitiesFrom:]
  -[ShipEntity setUpSubEntities]
  -[ShipEntity frustumRadius]
  -[ShipEntity setUpOneSubentity:]
  -[ShipEntity setUpOneFlasher:]

slice 4: standard subentities and cargo pods; descriptions, mesh, vectors, misjump, subentity lists, AI scripts
  -[ShipEntity cxx_setUpOneStandardSubentity:asTurret:]
  -[ShipEntity isTemplateCargoPod]
  -[ShipEntity setUpCargoType:]
  -[ShipEntity removeScript]
  -[ShipEntity clearSubEntities]
  -[ShipEntity subEntityRotationalVelocity]
  -[ShipEntity setSubEntityRotationalVelocity:]
  -[ShipEntity cxx_descriptionComponents]
  -[ShipEntity cxx_shortDescriptionComponents]
  -[ShipEntity sunGlareFilter]
  -[ShipEntity setSunGlareFilter:]
  -[ShipEntity accuracy]
  -[ShipEntity setAccuracy:]
  -[ShipEntity mesh]
  -[ShipEntity setMesh:]
  -[ShipEntity totalBoundingBox]
  -[ShipEntity forwardVector]
  -[ShipEntity upVector]
  -[ShipEntity rightVector]
  -[ShipEntity scriptedMisjump]
  -[ShipEntity setScriptedMisjump:]
  -[ShipEntity scriptedMisjumpRange]
  -[ShipEntity setScriptedMisjumpRange:]
  -[ShipEntity subEntities]
  -[ShipEntity subEntityCount]
  -[ShipEntity hasSubEntity:]
  -[ShipEntity subEntityEnumerator]
  -[ShipEntity cxx_shipSubEntities]
  -[ShipEntity flasherEnumerator]
  -[ShipEntity cxx_exhausts]
  -[ShipEntity subEntityTakingDamage]
  -[ShipEntity setSubEntityTakingDamage:]
  -[ShipEntity shipScript]
  -[ShipEntity shipAIScript]
  -[ShipEntity shipAIScriptWakeTime]
  -[ShipEntity setAIScriptWakeTime:]

slice 5: bounding boxes, octree hit tests, universe add / remove, beacons, boulders, escort set-up
  -[ShipEntity findBoundingBoxRelativeToPosition:InVectors:_i:_j:]
  -[ShipEntity octree]
  -[ShipEntity volume]
  -[ShipEntity doesHitLine:v0:]
  -[ShipEntity doesHitLine:v0:v1:]
  -[ShipEntity doesHitLine:v0:withPosition:andIJK:i:j:]
  -[ShipEntity wasAddedToUniverse]
  -[ShipEntity wasRemovedFromUniverse]
  -[ShipEntity absoluteTractorPosition]
  -[ShipEntity beaconCode]
  -[ShipEntity setBeaconCode:]
  -[ShipEntity beaconLabel]
  -[ShipEntity setBeaconLabel:]
  -[ShipEntity isVisible]
  -[ShipEntity isBeacon]
  -[ShipEntity beaconDrawable]
  -[ShipEntity prevBeacon]
  -[ShipEntity nextBeacon]
  -[ShipEntity setPrevBeacon:]
  -[ShipEntity setNextBeacon:]
  -[ShipEntity setIsBoulder:]
  -[ShipEntity isBoulder]
  -[ShipEntity isMinable]
  -[ShipEntity countsAsKill]
  -[ShipEntity setUpEscorts]
  -[ShipEntity setUpMixedEscorts]

slice 6: escort creation, ship data key, weapon offsets, octree collision checks, subentity geometry, escape-pod launch
  -[ShipEntity setUpOneEscort:inGroup:withRole:atPosition:andCount:]
  -[ShipEntity cxx_shipDataKey]
  -[ShipEntity cxx_shipDataKeyAutoRole]
  -[ShipEntity cxx_setShipDataKey:]
  -[ShipEntity cxx_shipInfoDictionary]
  -[ShipEntity cxx_weaponOffsetsFrom:withKey:inMode:]
  -[ShipEntity cxx_aftWeaponOffset]
  -[ShipEntity cxx_forwardWeaponOffset]
  -[ShipEntity cxx_portWeaponOffset]
  -[ShipEntity cxx_starboardWeaponOffset]
  -[ShipEntity isFrangible]
  -[ShipEntity suppressFlightNotifications]
  -[ShipEntity scanClass]
  -[ShipEntity canCollide]
  doOctreesCollide()
  -[ShipEntity checkCloseCollisionWith:]
  -[ShipEntity findSubentityBoundingBox]
  -[ShipEntity absoluteIJKForSubentity]
  -[ShipEntity addSubentityToCollisionRadius:]
  -[ShipEntity launchPodWithCrew:]
  -[ShipEntity validForAddToUniverse]

slice 7: update:
  -[ShipEntity update:]

slice 8: behaviour dispatch, attack response, equipment queries
  -[ShipEntity processBehaviour:]
  -[ShipEntity noteFrustration:]
  -[ShipEntity respondToAttackFrom:becauseOf:]
  -[ShipEntity cxx_hasOneEquipmentItem:includeWeapons:whileLoading:]
  -[ShipEntity cxx_hasOneEquipmentItem:includeMissiles:whileLoading:]
  -[ShipEntity hasPrimaryWeapon:]
  -[ShipEntity cxx_countEquipmentItem:]
  -[ShipEntity hasEquipmentItem:includeWeapons:whileLoading:]
  -[ShipEntity hasEquipmentItem:]
  -[ShipEntity cxx_hasEquipmentItemProviding:]
  -[ShipEntity cxx_equipmentItemProviding:]
  -[ShipEntity hasAllEquipment:includeWeapons:whileLoading:]
  -[ShipEntity hasAllEquipment:]
  -[ShipEntity hasHyperspaceMotor]
  -[ShipEntity hyperspaceSpinTime]
  -[ShipEntity setHyperspaceSpinTime:]

slice 9: equipment validity and adding, weapon mounts, scripting lists
  -[ShipEntity canAddEquipment:inContext:]
  -[ShipEntity weaponFacings]
  -[ShipEntity weaponTypeIDForFacing:strict:]
  -[ShipEntity weaponTypeForFacing:strict:]
  -[ShipEntity missilesList]
  -[ShipEntity passengerListForScripting]
  -[ShipEntity parcelListForScripting]
  -[ShipEntity contractListForScripting]
  -[ShipEntity generateMissileEquipmentTypeFrom:]
  -[ShipEntity cxx_equipmentListForScripting]
  -[ShipEntity cxx_equipmentValidToAdd:inContext:]
  -[ShipEntity cxx_equipmentValidToAdd:whileLoading:inContext:]
  -[ShipEntity setWeaponMount:toWeapon:]
  -[ShipEntity addEquipmentItem:inContext:]
  -[ShipEntity addEquipmentItem:withValidation:inContext:]
  -[ShipEntity cxx_equipmentKeys]
  -[ShipEntity equipmentCount]

slice 10: equipment removal, missile selection, capacities and has-equipment predicates, shields
  -[ShipEntity removeEquipmentItem:]
  -[ShipEntity removeExternalStore:]
  -[ShipEntity verifiedMissileTypeFromRole:]
  -[ShipEntity selectMissile]
  -[ShipEntity removeAllEquipment]
  -[ShipEntity removeMissiles]
  -[ShipEntity parcelCount]
  -[ShipEntity passengerCount]
  -[ShipEntity passengerCapacity]
  -[ShipEntity missileCount]
  -[ShipEntity missileCapacity]
  -[ShipEntity extraCargo]
  -[ShipEntity hasScoop]
  -[ShipEntity hasFuelScoop]
  -[ShipEntity hasCargoScoop]
  -[ShipEntity hasECM]
  -[ShipEntity hasCloakingDevice]
  -[ShipEntity hasMilitaryScannerFilter]
  -[ShipEntity hasMilitaryJammer]
  -[ShipEntity hasExpandedCargoBay]
  -[ShipEntity hasShieldBooster]
  -[ShipEntity hasMilitaryShieldEnhancer]
  -[ShipEntity hasHeatShield]
  -[ShipEntity hasFuelInjection]
  -[ShipEntity hasCascadeMine]
  -[ShipEntity hasEscapePod]
  -[ShipEntity hasDockingComputer]
  -[ShipEntity hasGalacticHyperdrive]
  -[ShipEntity shieldBoostFactor]
  -[ShipEntity maxForwardShieldLevel]
  -[ShipEntity maxAftShieldLevel]
  -[ShipEntity shieldRechargeRate]
  -[ShipEntity maxHyperspaceDistance]

slice 11: thrust and afterburner; behaviours: idle, tumble, tractored, track, intercept, break off, dogfight, evasive
  -[ShipEntity afterburnerFactor]
  -[ShipEntity afterburnerRate]
  -[ShipEntity setAfterburnerFactor:]
  -[ShipEntity setAfterburnerRate:]
  -[ShipEntity maxThrust]
  -[ShipEntity setMaxThrust:]
  -[ShipEntity thrust]
  -[ShipEntity behaviour_stop_still:]
  -[ShipEntity behaviour_idle:]
  -[ShipEntity behaviour_tumble:]
  -[ShipEntity behaviour_tractored:]
  -[ShipEntity behaviour_track_target:]
  -[ShipEntity behaviour_intercept_target:]
  -[ShipEntity behaviour_attack_break_off_target:]
  -[ShipEntity behaviour_attack_slow_dogfight:]
  -[ShipEntity behaviour_evasive_action:]

slice 12: behaviours: attack target, broadside, close with target
  -[ShipEntity behaviour_attack_target:]
  -[ShipEntity behaviour_attack_broadside:]
  -[ShipEntity behaviour_attack_broadside_left:]
  -[ShipEntity behaviour_attack_broadside_right:]
  -[ShipEntity behaviour_attack_broadside_target:leftside:]
  -[ShipEntity behaviour_close_to_broadside_range:]
  -[ShipEntity behaviour_close_with_target:]

slice 13: behaviours: sniper, fly to target six, mining target, attack fly to target
  -[ShipEntity behaviour_attack_sniper:]
  -[ShipEntity behaviour_fly_to_target_six:]
  -[ShipEntity behaviour_attack_mining_target:]
  -[ShipEntity behaviour_attack_fly_to_target:]

slice 14: behaviours: fly from target, running defence, flee, range from destination, face destination, land on planet, formation
  -[ShipEntity behaviour_attack_fly_from_target:]
  -[ShipEntity behaviour_running_defense:]
  -[ShipEntity behaviour_flee_target:]
  -[ShipEntity behaviour_fly_range_from_destination:]
  -[ShipEntity behaviour_face_destination:]
  -[ShipEntity behaviour_land_on_planet:]
  -[ShipEntity behaviour_formation_form_up:]

slice 15: behaviours: fly to / from destination, avoid collision, turret, navpoints, scripted AI; reaction time
  -[ShipEntity behaviour_fly_to_destination:]
  -[ShipEntity behaviour_fly_from_destination:]
  -[ShipEntity behaviour_avoid_collision:]
  -[ShipEntity behaviour_track_as_turret:]
  -[ShipEntity behaviour_fly_thru_navpoints:]
  -[ShipEntity behaviour_scripted_ai:]
  -[ShipEntity reactionTime]
  -[ShipEntity setReactionTime:]
  -[ShipEntity calculateTargetPosition]

slice 16: tracking curve, drawing, scanner colours, cloaking, subentities and owner, thrust
  -[ShipEntity startTrackingCurve]
  -[ShipEntity updateTrackingCurve]
  -[ShipEntity calculateTrackingCurve]
  -[ShipEntity drawImmediate:translucent:]
  -[ShipEntity drawDebugStuff]
  -[ShipEntity drawSubEntityImmediate:translucent:]
  -[ShipEntity scannerDisplayColorForShip:otherShip:isHostile:flash:scannerDisplayColor1:scannerDisplayColor2:scannerDisplayColorH1:]
  -[ShipEntity setScannerDisplayColor1:]
  -[ShipEntity setScannerDisplayColor2:]
  -[ShipEntity scannerDisplayColor1]
  -[ShipEntity scannerDisplayColor2]
  -[ShipEntity setScannerDisplayColorHostile1:]
  -[ShipEntity setScannerDisplayColorHostile2:]
  -[ShipEntity scannerDisplayColorHostile1]
  -[ShipEntity scannerDisplayColorHostile2]
  -[ShipEntity isCloaked]
  -[ShipEntity cloakPassive]
  -[ShipEntity setCloaked:]
  -[ShipEntity hasAutoCloak]
  -[ShipEntity setAutoCloak:]
  -[ShipEntity isJammingScanning]
  -[ShipEntity addSubEntity:]
  -[ShipEntity setOwner:]
  -[ShipEntity applyThrust:]
  -[ShipEntity orientationChanged]

slice 17: attitude, collision avoidance, messages, groups and escort accessors, proximity alert, names and descriptions
  -[ShipEntity applyRoll:andClimb:]
  -[ShipEntity applyRoll:climb:andYaw:]
  -[ShipEntity applyAttitudeChanges:]
  -[ShipEntity avoidCollision]
  -[ShipEntity resumePostProximityAlert]
  -[ShipEntity messageTime]
  -[ShipEntity setMessageTime:]
  -[ShipEntity group]
  -[ShipEntity setGroup:]
  -[ShipEntity escortGroup]
  -[ShipEntity setEscortGroup:]
  -[ShipEntity rawEscortGroup]
  -[ShipEntity stationGroup]
  -[ShipEntity hasEscorts]
  -[ShipEntity cxx_escorts]
  -[ShipEntity escortArray]
  -[ShipEntity escortCount]
  -[ShipEntity pendingEscortCount]
  -[ShipEntity setPendingEscortCount:]
  -[ShipEntity maxEscortCount]
  -[ShipEntity setMaxEscortCount:]
  -[ShipEntity turretCount]
  -[ShipEntity proximityAlert]
  -[ShipEntity setProximityAlert:]
  -[ShipEntity cxx_name]
  -[ShipEntity cxx_shipUniqueName]
  -[ShipEntity cxx_shipClassName]
  -[ShipEntity displayName]
  -[ShipEntity cxx_scanDescriptionForScripting]
  -[ShipEntity cxx_scanDescription]
  -[ShipEntity cxx_setName:]
  -[ShipEntity cxx_setShipUniqueName:]
  -[ShipEntity cxx_setShipClassName:]
  -[ShipEntity cxx_setDisplayName:]
  -[ShipEntity cxx_setScanDescription:]

slice 18: roles, ship-type predicates, hostility, weapon data, scanner range, aegis transition, nearest planet
  -[ShipEntity identFromShip:]
  -[ShipEntity hasRole:]
  -[ShipEntity roleSet]
  -[ShipEntity addRole:]
  -[ShipEntity cxx_addRole:withProbability:]
  -[ShipEntity cxx_removeRole:]
  -[ShipEntity cxx_primaryRole]
  -[ShipEntity setPrimaryRole:]
  -[ShipEntity cxx_hasPrimaryRole:]
  -[ShipEntity isPolice]
  -[ShipEntity isThargoid]
  -[ShipEntity isTrader]
  -[ShipEntity isPirate]
  -[ShipEntity isMissile]
  -[ShipEntity isMine]
  -[ShipEntity isWeapon]
  -[ShipEntity isEscort]
  -[ShipEntity isShuttle]
  -[ShipEntity isTurret]
  -[ShipEntity isPirateVictim]
  -[ShipEntity isExplicitlyUnpiloted]
  -[ShipEntity isUnpiloted]
  -[ShipEntity hasHostileTarget]
  -[ShipEntity isHostileTo:]
  -[ShipEntity weaponRange]
  -[ShipEntity setWeaponRange:]
  -[ShipEntity setWeaponDataFromType:]
  -[ShipEntity energyRechargeRate]
  -[ShipEntity setEnergyRechargeRate:]
  -[ShipEntity weaponRechargeRate]
  -[ShipEntity setWeaponRechargeRate:]
  -[ShipEntity setWeaponEnergy:]
  -[ShipEntity currentWeaponFacing]
  -[ShipEntity scannerRange]
  -[ShipEntity setScannerRange:]
  -[ShipEntity reference]
  -[ShipEntity setReference:]
  -[ShipEntity reportAIMessages]
  -[ShipEntity setReportAIMessages:]
  -[ShipEntity transitionToAegisNone]
  SurfaceDistanceSqaredV()
  SurfaceDistanceSqared()
  -[ShipEntity findNearestPlanet]
  -[ShipEntity findNearestStellarBody]
  -[ShipEntity findNearestPlanetExcludingMoons]

slice 19: aegis, home and destination systems, status, crew, AI and ship script, fuel
  -[ShipEntity checkForAegis]
  -[ShipEntity forceAegisCheck]
  -[ShipEntity withinStationAegis]
  -[ShipEntity lastAegisLock]
  -[ShipEntity setLastAegisLock:]
  -[ShipEntity homeSystem]
  -[ShipEntity destinationSystem]
  -[ShipEntity setHomeSystem:]
  -[ShipEntity setDestinationSystem:]
  -[ShipEntity setStatus:]
  -[ShipEntity setLaunchDelay:]
  -[ShipEntity cxx_crew]
  -[ShipEntity cxx_setCrew:]
  -[ShipEntity cxx_setSingleCrewWithRole:]
  -[ShipEntity cxx_crewForScripting]
  -[ShipEntity setStateMachine:]
  -[ShipEntity setAI:]
  -[ShipEntity getAI]
  -[ShipEntity hasAutoAI]
  -[ShipEntity hasNewAI]
  -[ShipEntity hasAutoWeapons]
  -[ShipEntity cxx_setShipScript:]
  -[ShipEntity frustration]
  -[ShipEntity fuel]
  -[ShipEntity setFuel:]
  -[ShipEntity fuelCapacity]
  calcFuelChargeRate()
  -[ShipEntity fuelChargeRate]

slice 20: sticks, bounty and legal status, commodities and cargo, speed
  -[ShipEntity applySticks:]
  -[ShipEntity setRoll:]
  -[ShipEntity setRawRoll:]
  -[ShipEntity setPitch:]
  -[ShipEntity setYaw:]
  -[ShipEntity setThrust:]
  -[ShipEntity setThrustForDemo:]
  -[ShipEntity setBounty:]
  -[ShipEntity setBounty:withReason:]
  -[ShipEntity setBounty:withReasonAsString:]
  -[ShipEntity bounty]
  -[ShipEntity legalStatus]
  -[ShipEntity cxx_setCommodity:andAmount:]
  -[ShipEntity cxx_setCommodityForPod:andAmount:]
  -[ShipEntity cxx_commodityType]
  -[ShipEntity commodityAmount]
  -[ShipEntity maxAvailableCargoSpace]
  -[ShipEntity setMaxAvailableCargoSpace:]
  -[ShipEntity availableCargoSpace]
  -[ShipEntity cargoQuantityOnBoard]
  -[ShipEntity cargoType]
  -[ShipEntity cxx_cargo]
  -[ShipEntity cxx_cargoCount]
  -[ShipEntity cargoListForScripting]
  -[ShipEntity setCargo:]
  -[ShipEntity cxx_addCargo:]
  -[ShipEntity cxx_removeCargo:amount:]
  -[ShipEntity showScoopMessage]
  -[ShipEntity cargoFlag]
  -[ShipEntity setCargoFlag:]
  -[ShipEntity setSpeed:]
  -[ShipEntity setDesiredSpeed:]
  -[ShipEntity desiredSpeed]

slice 21: flight controls and limits, temperature, dealing damage, hulks, damage notes
  -[ShipEntity desiredRange]
  -[ShipEntity setDesiredRange:]
  -[ShipEntity cruiseSpeed]
  -[ShipEntity increase_flight_speed:]
  -[ShipEntity decrease_flight_speed:]
  -[ShipEntity increase_flight_roll:]
  -[ShipEntity decrease_flight_roll:]
  -[ShipEntity increase_flight_pitch:]
  -[ShipEntity decrease_flight_pitch:]
  -[ShipEntity increase_flight_yaw:]
  -[ShipEntity decrease_flight_yaw:]
  -[ShipEntity flightRoll]
  -[ShipEntity flightPitch]
  -[ShipEntity flightYaw]
  -[ShipEntity flightSpeed]
  -[ShipEntity maxFlightPitch]
  -[ShipEntity maxFlightSpeed]
  -[ShipEntity maxFlightRoll]
  -[ShipEntity maxFlightYaw]
  -[ShipEntity setMaxFlightPitch:]
  -[ShipEntity setMaxFlightSpeed:]
  -[ShipEntity setMaxFlightRoll:]
  -[ShipEntity setMaxFlightYaw:]
  -[ShipEntity speedFactor]
  -[ShipEntity temperature]
  -[ShipEntity setTemperature:]
  -[ShipEntity randomEjectaTemperature]
  -[ShipEntity randomEjectaTemperatureWithMaxFactor:]
  -[ShipEntity heatInsulation]
  -[ShipEntity setHeatInsulation:]
  -[ShipEntity damage]
  -[ShipEntity dealEnergyDamage:atRange:withBias:]
  -[ShipEntity dealEnergyDamageWithinDesiredRange]
  -[ShipEntity dealMomentumWithinDesiredRange:]
  -[ShipEntity isHulk]
  -[ShipEntity setHulk:]
  -[ShipEntity noteTakingDamage:from:type:]
  -[ShipEntity noteKilledBy:damageType:]

slice 22: destruction, rescaling, cargo debris, explosions, energy blast
  -[ShipEntity getDestroyedBy:damageType:]
  -[ShipEntity rescaleBy:]
  -[ShipEntity rescaleBy:writeToCache:]
  -[ShipEntity releaseCargoPodsDebris]
  -[ShipEntity setIsWreckage:]
  -[ShipEntity showDamage]
  -[ShipEntity becomeExplosion]
  -[ShipEntity becomeEnergyBlast]
  -[ShipEntity broadcastEnergyBlastImminent]
  -[ShipEntity removeExhaust:]

slice 23: subentity death, alignment offsets, large explosion, laser heat, personality, scanner, remembered ships
  -[ShipEntity removeFlasher:]
  -[ShipEntity subEntityDied:]
  -[ShipEntity subEntityReallyDied:]
  -[ShipEntity positionOffsetForAlignment:]
  cxx_positionOffsetForShipInRotationToAlignment()
  -[ShipEntity becomeLargeExplosion:]
  -[ShipEntity collectBountyFor:]
  -[ShipEntity compareBeaconCodeWith:]
  -[ShipEntity weaponRecoveryTime]
  -[ShipEntity laserHeatLevel]
  -[ShipEntity laserHeatLevelAft]
  -[ShipEntity laserHeatLevelForward]
  -[ShipEntity laserHeatLevelPort]
  -[ShipEntity laserHeatLevelStarboard]
  -[ShipEntity hullHeatLevel]
  -[ShipEntity entityPersonality]
  -[ShipEntity entityPersonalityInt]
  -[ShipEntity randomSeedForShaders]
  -[ShipEntity setEntityPersonalityInt:]
  -[ShipEntity setSuppressExplosion:]
  -[ShipEntity resetExhaustPlumes]
  -[ShipEntity checkScanner]
  -[ShipEntity checkScannerIgnoringUnpowered]
  -[ShipEntity scannedShips]
  -[ShipEntity numberOfScannedShips]
  -[ShipEntity foundTarget]
  -[ShipEntity setFoundTarget:]
  -[ShipEntity primaryAggressor]
  -[ShipEntity setPrimaryAggressor:]
  -[ShipEntity lastEscortTarget]
  -[ShipEntity setLastEscortTarget:]

slice 24: target memory and validity, behaviour and destination accessors, distances, leading the target
  -[ShipEntity thankedShip]
  -[ShipEntity setThankedShip:]
  -[ShipEntity rememberedShip]
  -[ShipEntity setRememberedShip:]
  -[ShipEntity targetStation]
  -[ShipEntity setTargetStation:]
  -[ShipEntity isValidTarget:]
  -[ShipEntity addTarget:]
  -[ShipEntity removeTarget:]
  -[ShipEntity canStillTrackPrimaryTarget]
  -[ShipEntity primaryTarget]
  -[ShipEntity primaryTargetWithoutValidityCheck]
  -[ShipEntity isFriendlyTo:]
  -[ShipEntity shipHitByLaser]
  -[ShipEntity setShipHitByLaser:]
  -[ShipEntity noteLostTarget]
  -[ShipEntity noteLostTargetAndGoIdle]
  -[ShipEntity noteTargetDestroyed:]
  -[ShipEntity behaviour]
  -[ShipEntity setBehaviour:]
  -[ShipEntity destination]
  -[ShipEntity coordinates]
  -[ShipEntity setCoordinate:]
  -[ShipEntity distance_six:]
  -[ShipEntity distance_twelve:withOffset:]
  -[ShipEntity trackOntoTarget:withDForward:]
  -[ShipEntity ballTrackLeadingTarget:atTarget:]

slice 25: evasive jink, primary and side target tracking
  -[ShipEntity setEvasiveJink:]
  -[ShipEntity evasiveAction:]
  -[ShipEntity trackPrimaryTarget:delta_t:]
  -[ShipEntity trackSideTarget:delta_t:]

slice 26: missile and destination tracking, collision exceptions, defence targets, ranges
  -[ShipEntity missileTrackPrimaryTarget:]
  -[ShipEntity trackDestination:delta_t:]
  -[ShipEntity rollToMatchUp:rotating:]
  -[ShipEntity rangeToDestination]
  -[ShipEntity cxx_collisionExceptions]
  -[ShipEntity addCollisionException:]
  -[ShipEntity removeCollisionException:]
  -[ShipEntity collisionExceptedFor:]
  -[ShipEntity defenseTargetCount]
  -[ShipEntity allDefenseTargets]
  -[ShipEntity cxx_defenseTargets]
  -[ShipEntity addDefenseTarget:]
  -[ShipEntity validateDefenseTargets]
  -[ShipEntity isDefenseTarget:]
  -[ShipEntity removeAllDefenseTargets]
  -[ShipEntity removeDefenseTarget:]
  -[ShipEntity rangeToPrimaryTarget]
  -[ShipEntity rangeToSecondaryTarget:]
  -[ShipEntity approachAspectToPrimaryTarget]
  -[ShipEntity hasProximityAlertIgnoringTarget:]

slice 27: aim tolerance, sun glare, main weapons and turret fire, laser colours
  -[ShipEntity currentAimTolerance]
  -[ShipEntity lookingAtSunWithThresholdAngleCos:]
  -[ShipEntity onTarget:withWeapon:]
  -[ShipEntity fireWeapon:direction:range:]
  -[ShipEntity fireMainWeapon:]
  -[ShipEntity fireAftWeapon:]
  -[ShipEntity firePortWeapon:]
  -[ShipEntity fireStarboardWeapon:]
  -[ShipEntity shotTime]
  -[ShipEntity resetShotTime]
  -[ShipEntity fireTurretCannon:]
  -[ShipEntity setLaserColor:]
  -[ShipEntity setExhaustEmissiveColor:]
  -[ShipEntity laserColor]
  -[ShipEntity exhaustEmissiveColor]

slice 28: laser shots, missed shots, sparks, missile launch decision
  -[ShipEntity fireSubentityLaserShot:]
  -[ShipEntity fireDirectLaserShot:]
  -[ShipEntity fireDirectLaserDefensiveShot]
  -[ShipEntity fireDirectLaserShotAt:]
  -[ShipEntity cxx_laserPortOffset:]
  -[ShipEntity cxx_fireLaserShotInDirection:weaponIdentifier:]
  -[ShipEntity adjustMissedShots:]
  -[ShipEntity missedShots]
  -[ShipEntity throwSparks]
  -[ShipEntity considerFiringMissile:]
  -[ShipEntity missileLaunchPosition]
  -[ShipEntity fireMissile]

slice 29: missile firing, ECM, cloak, cascade mine, escape capsule, cargo dumping
  -[ShipEntity cxx_fireMissileWithIdentifier:andTarget:]
  -[ShipEntity isMissileFlagSet]
  -[ShipEntity setIsMissileFlag:]
  -[ShipEntity missileLoadTime]
  -[ShipEntity setMissileLoadTime:]
  -[ShipEntity noticeECM]
  -[ShipEntity fireECM]
  -[ShipEntity activateCloakingDevice]
  -[ShipEntity deactivateCloakingDevice]
  -[ShipEntity launchCascadeMine]
  -[ShipEntity launchEscapeCapsule]
  -[ShipEntity dumpCargo]
  -[ShipEntity cxx_dumpCargoItem:]
  -[ShipEntity dumpItem:]

slice 30: collisions, velocity, tractoring and scooping
  -[ShipEntity manageCollisions]
  -[ShipEntity collideWithShip:]
  -[ShipEntity thrustVector]
  -[ShipEntity velocity]
  -[ShipEntity setTotalVelocity:]
  -[ShipEntity adjustVelocity:]
  -[ShipEntity addImpactMoment:fraction:]
  -[ShipEntity canScoop:]
  -[ShipEntity getTractoredBy:]
  -[ShipEntity scoopIn:]
  -[ShipEntity suppressTargetLost]
  -[ShipEntity scoopUp:]
  -[ShipEntity scoopUpProcess:processEvents:processMessages:]

slice 31: cascades, energy / scrape / heat damage, abandoning ship, docks, wormholes, witchspace
  -[ShipEntity cascadeIfAppropriateWithDamageAmount:cascadeOwner:]
  -[ShipEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]
  -[ShipEntity abandonShip]
  -[ShipEntity takeScrapeDamage:from:]
  -[ShipEntity takeHeatDamage:]
  -[ShipEntity enterDock:]
  -[ShipEntity leaveDock:]
  -[ShipEntity enterWormhole:]
  -[ShipEntity enterWormhole:replacing:]
  -[ShipEntity enterWitchspace]
  -[ShipEntity leaveWitchspace]

slice 32: witchspace effects, offences, lights, escort formation and deployment, nearest stations
  -[ShipEntity witchspaceLeavingEffects]
  -[ShipEntity markAsOffender:]
  -[ShipEntity markAsOffender:withReason:]
  -[ShipEntity switchLightsOn]
  -[ShipEntity switchLightsOff]
  -[ShipEntity lightsActive]
  -[ShipEntity setDestination:]
  -[ShipEntity setEscortDestination:]
  -[ShipEntity canAcceptEscort:]
  -[ShipEntity acceptAsEscort:]
  -[ShipEntity updateEscortFormation]
  -[ShipEntity refreshEscortPositions]
  -[ShipEntity coordinatesForEscortPosition:]
  -[ShipEntity deployEscorts]
  -[ShipEntity dockEscorts]
  -[ShipEntity setTargetToNearestStationIncludingHostiles:]
  -[ShipEntity setTargetToNearestFriendlyStation]
  -[ShipEntity setTargetToNearestStation]
  -[ShipEntity setTargetToSystemStation]

slice 33: landing, docking abort, broadcasts and comms, fines, AI messages, spawning, close contacts, salvage
  -[ShipEntity landOnPlanet:]
  -[ShipEntity abortDocking]
  -[ShipEntity cxx_dockingInstructions]
  -[ShipEntity broadcastThargoidDestroyed]
  AuthorityPredicate()
  -[ShipEntity broadcastHitByLaserFrom:]
  -[ShipEntity cxx_sendMessage:toShip:withUnpilotedOverride:]
  -[ShipEntity cxx_sendExpandedMessage:toShip:]
  -[ShipEntity broadcastAIMessage:]
  -[ShipEntity broadcastMessage:withUnpilotedOverride:]
  -[ShipEntity setCommsMessageColor]
  -[ShipEntity receiveCommsMessage:from:]
  -[ShipEntity cxx_commsMessage:withUnpilotedOverride:]
  -[ShipEntity markedForFines]
  -[ShipEntity markForFines]
  -[ShipEntity isMining]
  -[ShipEntity interpretAIMessage:]
  -[ShipEntity findBoundingBoxRelativeTo:InVectors:_i:_j:]
  -[ShipEntity spawn:]
  -[ShipEntity checkShipsInVicinityForWitchJumpExit]
  -[ShipEntity trackCloseContacts]
  -[ShipEntity setTrackCloseContacts:]
  -[ShipEntity claimAsSalvage]
  -[ShipEntity sendCoordinatesToPilot]

slice 34: salvage pilot, debug dump, script info, demo ship, script events and AI reactions, alert condition, shader helpers
  -[ShipEntity pilotArrived]
  -[ShipEntity dumpSelfState]
  -[ShipEntity script]
  -[ShipEntity scriptInfo]
  -[ShipEntity overrideScriptInfo:]
  -[ShipEntity entityForShaderProperties]
  -[ShipEntity setDemoShip:]
  -[ShipEntity isDemoShip]
  -[ShipEntity setDemoStartTime:]
  -[ShipEntity getDemoStartTime]
  -[ShipEntity doScriptEvent:]
  -[ShipEntity doScriptEvent:withArgument:]
  -[ShipEntity doScriptEvent:withArgument:andArgument:]
  -[ShipEntity cxx_doScriptEvent:withPListArguments:]
  -[ShipEntity doScriptEvent:withArguments:count:]
  -[ShipEntity doScriptEvent:inContext:withArguments:count:]
  -[ShipEntity cxx_reactToAIMessage:context:]
  -[ShipEntity sendAIMessage:]
  -[ShipEntity cxx_doScriptEvent:andReactToAIMessage:]
  -[ShipEntity cxx_doScriptEvent:withArgument:andReactToAIMessage:]
  -[ShipEntity alertCondition]
  -[ShipEntity realAlertCondition]
  -[ShipEntity doNothing]
  -[ShipEntity descriptionForObjDump]
  OODefaultShipShaderMacros()
  OOUniformBindingPermitted()
  getWeaponRangeFromType()
  isWeaponNone()

verbatim: plain C/C++ helpers, no Objective-C (checked)
  IsBehaviourHostile()
  ComparePlanetsBySurfaceDistance()
  *
```
