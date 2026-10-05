# Slice plan: OOJSShip

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-9ht.139; umbrella oo-e4i). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOJSShip.md`, which recounts the file
every time, so the numbers below are only a snapshot.

- **File:** `Core/Scripting/OOJSShip.mm` (4,495 lines) + header (43 lines). No class of its own:
  the JavaScript `Ship` object, as file-scope `ooscript` callbacks: a ~610-line property getter,
  a ~770-line property setter, ~85 methods (`ship.setAI()`, `ship.awardEquipment()`,
  `ship.performAttack()`, …) and six static methods on `Ship` (`Ship.keys()`, …). The preamble
  (~605 lines: the property and method tables, declarations, the `GET_THIS_SHIP` macro) is charged
  to every slice. The file has **no category**: `ShipEntity (OOJavaScriptExtensions)`, which makes
  a ship's JS object, lives in `EntityOOJavaScriptExtensions.mm` (its bridge's deletion is
  oo-9ht.128), so this binding gets no `OOJSShip+ObjCBridge` façade forwarders (amendments
  oo-ppc item 3, oo-ykoy) and slice 1 is not a class shell: it is the getter and the file's
  Objective-C helpers, which every later slice reads as preamble neighbours.
- **Mechanical split (this bead, behaviour-neutral, its own commit):** the `injectorSpeedFactor`
  arm of the setter opened an `else if {` in each `#if OO_VARIABLE_TORUS_SPEED` arm and closed it
  once after `#endif`; each arm now closes its own block, so the plan's lexer (which counts braces
  in both arms) sees the 88 units after the setter. Either preprocessed translation unit is
  token-for-token the same.
- **Shape:** a callback that sends Objective-C messages is converted in a slice; the eight that
  do not (`InitOOJSShip` and the getter macro, `JSShipClass` / `JSShipPrototype`, `StringOrNull`,
  `StringArray`, `ShipExplode`, `ShipSetMaterials`, `ShipSetShaders`) stay verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9; the checker proves which is
  which). The getter and the setter are kept whole, one slice each, as for `OOJSPlayerShip`:
  splitting a `switch` over property ids across stories buys nothing. The methods split by
  feature into four slices.
- **What "converted" means here.** A binding converts in place (amendment oo-ppc items 2-5):
  `BOOL` to `bool`, exceptions already mapped by `OOJSEngineNativeWrappers.h`, converted classes
  reached as `cxx::` through `oo::ToCxx` with nil guards (amendment oo-6ia4 item 2). But
  `--slice-done` counts every message send in a free function, so a native is done only when it
  sends none. About 410 of the file's sends go to the `ShipEntity` it wraps (`entity`,
  `thisEnt`, `target`): **every slice waits for `ShipEntity` to be C++** (the frontier giant
  oo-k8a, being pre-split; each slice depends on oo-k8a until its slice beads exist, then on the
  `ShipEntity` slices that own the members it calls). The other sends go to classes whose own
  conversion waits for this binding (`Universe`, oo-pas, depends on oo-e4i) or comes much later
  (`PlayerEntity`, oo-a70): those go behind one-line functions in `OOJSShip+ObjCBridge.mm`
  ([ADR-0056](../../decisions/0056-phase3-class-conversion-house-style.md) amendment
  oo-9ht.139). Per slice: 2 `UNIVERSE`, `PLAYER`, `ShipEntity` class methods, `OOShipGroup`,
  `OOColor`; 3 `UNIVERSE`; 4 `UNIVERSE`, `OOCharacter`, `ResourceManager`, `OOMesh`; 5
  `UNIVERSE`, `PLAYER`; 6 `UNIVERSE`, `PLAYER`, `OOShipRegistry` (its own slices, oo-3bgz…).
- **Tests:** `tests/unit/core/test_OOJSShip.mm`, added by slice 1 against the Objective-C binding
  and run there first (amendment oo-ppc item 6, oo-ykoy item 4: a `FakeUniverse` and stand-in
  ship answering only the selectors the slice's natives send); later slices extend it with their
  natives. Gate per slice: `--slice-done`, guardrails, and `bash tools/js-api-contract.sh` (the JS
  API snapshot must not change: oo-e4i's "done when").
- **Order:** after the scripting-bindings pattern seam (oo-ppc) and `ShipEntity` (oo-k8a). Slice 1
  first (gen-stories makes 2-6 depend on it); 2-6 are then independent. `OOJSPlayerShip`'s slices
  (whose prototype extends `Ship`) come after. oo-e4i ("Convert OOJSShip") is the umbrella: it
  depends on the six slices, and its acceptance is every slice's `--slice-done`, the JS API
  contract and guardrails.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | `ShipGetProperty`, `NativeVectorArray`, `NormalizedColorComponents` | ~635 | ~1,285 |
| 2 | `ShipSetProperty` | ~765 | ~1,415 |
| 3 | AI and script, escorts, roles, cargo ejection and dumping, spawn, damage, removal, legacy actions, comms, ECM, abandon | ~670 | ~1,320 |
| 4 | equipment (award / remove / status), missiles, nearest station, bounty, cargo, crew, materials and shaders | ~725 | ~1,375 |
| 5 | system exit, escort formation, defence targets, collision exceptions, cascades, group / escort / patrol, wormholes, docking instructions, distress, course | ~400 | ~1,050 |
| 6 | `perform*` AI behaviours, scanner, cargo adjustment, damage and threat assessment, `Ship.*` static methods | ~590 | ~1,240 |
| verbatim | callbacks and helpers with no Objective-C | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Scripting/OOJSShip.mm
header: upstream/oolite/src/Core/Scripting/OOJSShip.h

slice 1: property getter and the file's helpers
  NativeVectorArray()
  NormalizedColorComponents()
  ShipGetProperty()

slice 2: property setter
  ShipSetProperty()

slice 3: AI and script, escorts, roles, cargo ejection, spawn, damage, removal, comms
  ShipSetScript()
  ShipSetAI()
  ShipSwitchAI()
  ShipExitAI()
  ShipReactToAIMessage()
  ShipSendAIMessage()
  ShipDeployEscorts()
  ShipDockEscorts()
  ShipHasEquipmentProviding()
  ShipHasRole()
  ShipEjectItem()
  ShipAddCargoEntity()
  ShipEjectSpecificItem()
  ShipDumpCargo()
  ShipSpawn()
  ShipDealEnergyDamage()
  ShipRemove()
  RemoveOrExplodeShip()
  ShipRunLegacyScriptActions()
  ShipCommsMessage()
  ShipFireECM()
  ShipAbandonShip()

slice 4: equipment, missiles, bounty, cargo and crew, materials and shaders
  ShipCanAwardEquipment()
  ShipAwardEquipment()
  ShipRemoveEquipment()
  ShipRestoreSubEntities()
  ShipSetEquipmentStatus()
  ShipEquipmentStatus()
  ShipSelectNewMissile()
  ShipFireMissile()
  ShipFindNearestStation()
  ShipSetBounty()
  ShipSetCargo()
  ShipSetCrew()
  ShipSetCargoType()
  ShipSetMaterialsInternal()
  ShipGetMaterials()
  ShipGetShaders()

slice 5: system exit, escorts and groups, defence targets, collision exceptions, cascades, wormholes, docking, course
  ShipExitSystem()
  ShipUpdateEscortFormation()
  ShipClearDefenseTargets()
  ShipAddDefenseTarget()
  ShipRemoveDefenseTarget()
  ShipAddCollisionException()
  ShipRemoveCollisionException()
  ShipBroadcastCascadeImminent()
  ShipBecomeCascadeExplosion()
  ShipOfferToEscort()
  ShipRequestHelpFromGroup()
  ShipPatrolReportIn()
  ShipMarkTargetForFines()
  ShipEnterWormhole()
  ShipNotifyGroupOfWormhole()
  ShipThrowSpark()
  ShipRequestDockingInstructions()
  ShipRecallDockingInstructions()
  ShipBroadcastDistressMessage()
  ShipCheckCourseToDestination()
  ShipGetSafeCourseToDestination()

slice 6: AI behaviours (perform*), scanner, cargo adjustment, damage and threat assessment, static registry methods
  ShipPerform*()
  ShipCheckScanner()
  ShipAdjustCargo()
  ShipDamageAssessment()
  ShipThreatAssessment*()
  ShipStatic*()

verbatim: plain C/C++ callbacks and helpers, no Objective-C (checked)
  *
```
