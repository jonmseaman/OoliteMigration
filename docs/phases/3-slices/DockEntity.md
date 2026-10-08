# Slice plan: DockEntity

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-ao2d). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/DockEntity.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/DockEntity.mm` (1,337 lines) + header (126 lines). One class,
  `DockEntity : ShipEntity`, a station's dock (a subentity of the station), with 42 methods,
  and four file-scope helpers. The `OOPrivate` interface in the preamble only declares methods
  defined in the main `@implementation`.
- **Shape:** three feature groups: the class shell (initialiser, `dealloc`, set-up, the
  docking / launching flags, geometry, the ID locks, the overrides of the ship's `update:`,
  damage and drawing, the two queue counts), docking guidance (the approach queue, docking
  instructions, aborting dockings), and the corridor and launching (the corridor test, the
  launch queue, clearing the corridor). The four helpers in the anonymous namespace have no
  Objective-C and stay verbatim ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9).
- **Pattern:** the second Objective-C subclass of the half-converted `ShipEntity` to convert,
  after `StationEntity` ([ADR-0056](../../decisions/0056-phase3-class-conversion-house-style.md)
  amendment oo-64ako, whose item 2 names `DockEntity`): slice 1 makes `cxx::DockEntity :
  cxx::ShipEntity` with the dock's state, the façade `DockEntity+ObjCBridge.h/.mm` with its typed
  alias `_cxxDock`, and the adapter `oo::ObjCShipEntity<cxx::DockEntity>`; slices 2 and 3 move
  their units into `cxx::DockEntity` and drop `_cxxDock->` from them.
- **Order:** after `ShipEntity` (oo-k8a) and the StationEntity class shell (oo-64ako). Slice 1
  first; slices 2 and 3 are then independent. `StationEntity` messages its docks by selector,
  so no station file changes.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell: init / `dealloc` / set-up, flags, geometry, ID locks, `update:`, damage and drawing overrides, queue counts | ~260 | ~455 |
| 2 | docking guidance: approach queue, docking instructions, aborting dockings | ~520 | ~715 |
| 3 | the docking corridor and launching: corridor test, launch queue, clearing the corridor | ~450 | ~650 |
| verbatim | `ShipIDsIn()`, `DescriptionForLog()`, `DockingInstructions()`, `OptionalStringValue()` | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Entities/DockEntity.mm
header: upstream/oolite/src/Core/Entities/DockEntity.h

slice 1: class shell, flags, geometry and lifecycle
  @DockEntity

slice 2: docking guidance: the approach queue and docking instructions
  -[DockEntity pruneAndCountShipsOnApproach]
  -[DockEntity abortAllDockings]
  -[DockEntity autoDockShipsInQueue:]
  -[DockEntity autoDockShipsOnApproach]
  -[DockEntity canAcceptShipForDocking:]
  -[DockEntity dockingInstructionsForShip:]
  -[DockEntity addShipToShipsOnApproach:]
  -[DockEntity noteDockingForShip:]
  -[DockEntity abortDockingForShip:]
  -[DockEntity shipIsInDockingQueue:]
  -[DockEntity pullInShipIfPermitted:]

slice 3: the docking corridor and launching
  -[DockEntity shipIsInDockingCorridor:]
  -[DockEntity abortAllLaunches]
  -[DockEntity addShipToLaunchQueue:withPriority:]
  -[DockEntity launchShip:]
  -[DockEntity countOfShipsInLaunchQueueWithPrimaryRole:]
  -[DockEntity allowsLaunchingOf:]
  -[DockEntity dockingCorridorIsEmpty]
  -[DockEntity clearDockingCorridor]

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
