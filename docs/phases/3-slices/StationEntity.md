# Slice plan: StationEntity

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-y2ie). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/StationEntity.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/StationEntity.mm` (2,481 lines) + header (256 lines). One class,
  `StationEntity : ShipEntity`, with ~110 methods, and one string helper. The `OOPrivate`
  interface in the preamble only declares methods defined in the main `@implementation`.
- **Shape:** four feature groups: the class shell (construction, market, shipyard, flags and
  accessors), docking traffic control (approach queues, docking instructions, the corridor, the
  launch queue, `update:`), the docking-clearance protocol with alert levels and damage, and the
  NPC launchers (`launchPolice`, `launchDefenseShip`, …). `cxx_OOMakeDockingInstructions()` sits
  inside the `@implementation` and sends messages, so it moves with the docking slice. The one
  file-scope helper has no Objective-C and stays verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9).
- **Order:** after the `ooentity` pattern seam (oo-bj8) and once `ShipEntity` is a C++ class
  (frontier, oo-k8a). Slice 1 first: it
  converts the class shell and lifecycle that the other slices' member definitions attach to;
  slices 2-4 are then independent.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell: accessors, market, init / `dealloc` / `setUpShipFromDictionary:`, shipyard, flags, `dumpSelfState` | ~675 | ~1,010 |
| 2 | docking traffic: approach and hold queues, docking instructions, corridor, `update:`, dock selection, launch queue | ~750 | ~1,085 |
| 3 | docking-clearance protocol, collision and damage, allegiance and alert level, explosions | ~435 | ~770 |
| 4 | NPC launchers: independent, police, defence, scavenger, miner, pirate, shuttle, escort, patrol | ~565 | ~900 |
| verbatim | `OptionalStringValue()` | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Entities/StationEntity.mm
header: upstream/oolite/src/Core/Entities/StationEntity.h

slice 1: class shell, market and shipyard, flags and accessors
  @StationEntity

slice 2: docking traffic control and the launch queue
  -[StationEntity sanityCheckShipsOnApproach]
  -[StationEntity launchShip:]
  -[StationEntity abortAllDockings]
  -[StationEntity autoDockShipsOn*]
  -[StationEntity portUpVectorForShip:]
  cxx_OOMakeDockingInstructions()
  -[StationEntity dockingInstructionsForShip:]
  -[StationEntity holdPositionInstructionForShip:]
  -[StationEntity abortDockingForShip:]
  -[StationEntity shipIsInDockingCorridor:]
  -[StationEntity pullInShipIfPermitted:]
  -[StationEntity dockingCorridorIsEmpty]
  -[StationEntity clearDockingCorridor]
  -[StationEntity update:]
  -[StationEntity clear]
  -[StationEntity hasMultipleDocks]
  -[StationEntity hasClearDock]
  -[StationEntity hasEligibleDock]
  -[StationEntity hasLaunchDock]
  -[StationEntity selectDockForDocking]
  -[StationEntity addShipToLaunchQueue:withPriority:]
  -[StationEntity countOfShipsInLaunchQueueWithPrimaryRole:]
  -[StationEntity fitsInDock:*]
  -[StationEntity noteDockedShip:]
  -[StationEntity addShipToStationCount:]

slice 3: docking clearance, damage, allegiance and alert level
  -[StationEntity cxx_acceptDockingClearanceRequestFrom:]
  -[StationEntity currentlyIn*Queues]
  -[StationEntity collideWithShip:]
  -[StationEntity hasHostileTarget]
  -[StationEntity takeEnergyDamage:*]
  -[StationEntity adjustVelocity:]
  -[StationEntity takeScrapeDamage:from:]
  -[StationEntity takeHeatDamage:]
  -[StationEntity cxx_allegiance]
  -[StationEntity cxx_setAllegiance:]
  -[StationEntity alertLevel]
  -[StationEntity setAlertLevel:signallingScript:]
  -[StationEntity increaseAlertLevel]
  -[StationEntity decreaseAlertLevel]
  -[StationEntity become*]
  -[StationEntity acceptPatrolReportFrom:]

slice 4: NPC launchers
  -[StationEntity launch*]

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
