# Slice plan: PlayerEntityControls

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-9ht.157; the file was the frontier bead
oo-e1d, now the umbrella over these slices). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/PlayerEntityControls.md`, which recounts the
file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/PlayerEntityControls.mm` (5,684 lines) + header (52 lines). One
  `PlayerEntity (Controls)` category: 46 methods (key definitions and key-press checks, the per-frame
  control poll, the application, flight, view, GUI-screen, market, options, mapper, docked,
  autopilot, mission and intro-screen keys, view switching) and two file-scope functions. The
  preamble (228 lines) is imports and the file-scope `static` key-latch flags that every poll
  method reads; they stay file-scope statics, so each slice reads them whole. The header is small,
  so neither `header-decls` nor `header-names` is needed.
- **Category slices** (ADR-0056 amendment oo-o89 item 4, as [KeyMapper](PlayerEntityKeyMapper.md)
  and [Contracts](PlayerEntityContracts.md)): each slice moves its methods into `cxx::PlayerEntity`
  as member functions defined in this file, leaves a forwarder on the façade for each selector still
  sent (the poll methods are messaged from `PlayerEntity.mm`'s update and from the GUI screens;
  `switchToThisView:` and friends from the JS bindings), and deletes `_cxxPlayer->` from the moved
  bodies. The file has no class shell of its own: `cxx::PlayerEntity` is PlayerEntity slice 1
  ([PlayerEntity.md](PlayerEntity.md), oo-jx5np), which every slice here waits on. Slice 1 of this
  plan carries nothing the others need; `tools/gen-stories.py` still makes slices 2-7 wait on it
  (the plans' stated order), which only orders them.
- **Two slices are one method each and over the 800-line own budget** (new plan key
  `one-unit-slices: frontier` in `tools/check-slice-plan.py`, bead oo-9ht.157):
  `pollFlightControls:` (903 lines, slice 3) and `pollGuiArrowKeyControls:` (1,105 lines, slice 4).
  No plan can cut one method, and splitting it into helper methods first would be redesign during
  conversion (CLAUDE.md "conservative translation"). Each still reads under 1,500 lines (~1,183 and
  ~1,385), so a frontier agent can convert it in one story: the body mostly stays as it is (sends
  to Objective-C objects stay sends, ADR-0056), and what is written is the member signature, the
  `self` sends, and the `_cxxPlayer->` deletions. Their beads are labelled frontier.
- **Verbatim:** `ExpandKeyWithArguments()` is plain C++ and stays verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9). `ClickedGUIRow()` messages the
  GUI and the game controller, so it moves with its only caller, `handleGUIUpDownArrowKeys` (slice 1).

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | control set-up, key definitions and key-press checks, the control poll, GUI up / down keys, target system, view-switch notes, the witchspace countdown | ~677 | ~957 |
| 2 | application keys, the custom and fixed view keys, the flight arrow keys | ~765 | ~1,045 |
| 3 | `pollFlightControls:` (frontier: one method) | ~903 | ~1,183 |
| 4 | `pollGuiArrowKeyControls:` (frontier: one method) | ~1,105 | ~1,385 |
| 5 | the market screen keys, the game-options screen keys | ~752 | ~1,032 |
| 6 | key-mapper, keyboard-layout and stick-mapper screen keys, GUI-screen function keys, game over, autopilot, docked and undock controls, mission screens | ~605 | ~885 |
| 7 | the intro and ship-library screens, switching views, autopilot on, the ident and target-missile buttons | ~641 | ~921 |
| verbatim | `ExpandKeyWithArguments()` | ~8 | not read |

**Order.** Every slice waits on PlayerEntity slice 1 (oo-jx5np, the class shell) and on the
PlayerEntity and ShipEntity slices whose methods its bodies send to `self` / `PLAYER`, so a converted
body can call them as members (found by matching each slice's sends against the units of
[PlayerEntity.md](PlayerEntity.md), [ShipEntity.md](ShipEntity.md) and
[ShipEntityAI.md](ShipEntityAI.md)). No method here overrides a ship's.

| Slice | Calls methods of |
|---|---|
| 1 | Player 3, 10, 21; Ship 8, 19, 34 |
| 2 | Player 10, 12, 17, 26, 27; Ship 21 |
| 3 | Player 8, 10, 12, 13, 14, 16, 17, 18, 19, 24, 26, 27; Ship 8, 10, 19, 20, 24, 34 |
| 4 | Player 2, 3, 10, 17, 18, 19, 20, 21, 22, 24, 27; Ship 8, 21, 34 |
| 5 | Player 19, 23, 24, 26, 28 |
| 6 | Player 8, 10, 17, 18, 19, 20, 21, 24, 27; Ship 10 |
| 7 | Player 8, 10, 12, 13, 15, 19, 21, 26, 28; Ship 19, 24, 33 |

**The waiting beads.** oo-e1d is the umbrella: it depends on the seven slices and its acceptance is
each slice's `--slice-done`, no `@implementation` left in the file, and the guardrails; oo-a70
(PlayerEntity's umbrella) and oo-pas keep waiting on it. The façade-deletion beads that waited on
oo-e1d wait instead on the slices whose units name the façade's class, an accessor or member typed
with it, or a selector only it declares (the oo-9ht.154 heuristic; each bead's own readiness grep
stays the final check): OOMusicController oo-9ht.90 (3, 5, 6, 7), OOEquipmentType oo-9ht.28 (3, 4),
OOJSScript oo-9ht.137 (3), AI oo-9ht.73 (3), OOCommodities oo-9ht.25 (5), OOJSInterfaceDefinition
oo-9ht.61 (4), OOSunEntity oo-9ht.111 (6), OOJSGuiScreenKeyDefinition oo-9ht.62 (4),
OOCommodityMarket oo-9ht.21 (5), OOSound oo-9ht.68 (5), OOSystemDescriptionManager oo-9ht.32 (1,
4), HeadUpDisplay oo-mwd58 (2, 4, 7); OOPlanetEntity oo-9ht.129 names nothing here (an import
only) and no longer waits on this file.

**Slice beads** (filed by `tools/gen-stories.py --sweep slices`): 1 oo-hsilb, 2 oo-56tmj, 3
oo-4216h (frontier), 4 oo-n8wn2 (frontier), 5 oo-uq8px, 6 oo-fz3l8, 7 oo-lmdi8.

```slice-plan
source: upstream/oolite/src/Core/Entities/PlayerEntityControls.mm
header: upstream/oolite/src/Core/Entities/PlayerEntityControls.h
one-unit-slices: frontier

slice 1: control set-up, key definitions and key-press checks, the control poll, GUI up / down keys, target system, view-switch notes, the witchspace countdown
  -[PlayerEntity initControls]
  -[PlayerEntity initKeyConfigSettings]
  -[PlayerEntity cxx_processKeyCode:]
  -[PlayerEntity checkNavKeyPress:]
  -[PlayerEntity checkKeyPress:*]
  -[PlayerEntity getFirstKeyCode:]
  -[PlayerEntity pollControls:]
  ClickedGUIRow()
  -[PlayerEntity handleGUIUpDownArrowKeys]
  -[PlayerEntity targetNewSystem:*]
  -[PlayerEntity clearPlanetSearchString]
  -[PlayerEntity switchToMainView]
  -[PlayerEntity noteSwitchToView:fromView:]
  -[PlayerEntity beginWitchspaceCountdown*]
  -[PlayerEntity cancelWitchspaceCountdown]

slice 2: application keys (quit, snapshot, FPS, bloom, mouse control, HUD toggle), the custom and fixed view keys, the flight arrow keys
  -[PlayerEntity pollApplicationControls]
  -[PlayerEntity pollCustomViewControls]
  -[PlayerEntity pollViewControls]
  -[PlayerEntity pollFlightArrowKeyControls:]

slice 3: the flight controls (pollFlightControls:)
  -[PlayerEntity pollFlightControls:]

slice 4: the GUI-screen arrow keys (pollGuiArrowKeyControls:)
  -[PlayerEntity pollGuiArrowKeyControls:]

slice 5: the market screen keys, the game-options screen keys
  -[PlayerEntity pollMarketScreenControls]
  -[PlayerEntity handleGameOptionsScreenKeys]

slice 6: key-mapper, keyboard-layout and stick-mapper screen keys, the GUI-screen function keys, game over, autopilot, docked and undock controls, mission screens
  -[PlayerEntity handleKeyMapperScreenKeys]
  -[PlayerEntity handleKeyboardLayoutKeys]
  -[PlayerEntity handleStickMapperScreenKeys]
  -[PlayerEntity pollGuiScreenControls*]
  -[PlayerEntity pollGameOverControls:]
  -[PlayerEntity pollAutopilotControls:]
  -[PlayerEntity pollDockedControls:]
  -[PlayerEntity handleUndockControl]
  -[PlayerEntity pollMissionInterruptControls]
  -[PlayerEntity handleMissionCallback]
  -[PlayerEntity setGuiToMissionEndScreen]

slice 7: the intro and ship-library screens (pollDemoControls:), switching views, the autopilot on, the ident and target-missile buttons
  -[PlayerEntity pollDemoControls:]
  -[PlayerEntity switchToThisView:*]
  -[PlayerEntity handleAutopilotOn:]
  -[PlayerEntity handleButtonIdent]
  -[PlayerEntity handleButtonTargetMissile]

verbatim: plain C++, no Objective-C (checked)
  ExpandKeyWithArguments()
```
