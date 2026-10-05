# ADR-0058: A GUI click activates the row under the pointer at click time

- Status: Accepted (delegated 2026-10-05: Jon delegated the human-assigned beads to the orchestrator's best judgement; ratified as proposed, bead oo-f4rft; record in [delegated-2026-10-05.md](delegated-2026-10-05.md))
- Date: 2026-09-30
- Beads: oo-3rb.348 (this ADR, the fix and its unit test); found from oo-3rb.333 (GUI G5 flake)

## Context

A mouse click on a GUI screen activates a row (`PlayerEntityControls -handleGUIUpDownArrowKeys`).
It activated `UNIVERSE->cursor_row`, which only `-[GuiDisplayGen drawGUI:drawCursor:YES]`
recomputes, i.e. the row under the pointer at the **last render**. SDL motion events update the
virtual-joystick position in `-pollControls`, in the same tick as the click. After a stall longer
than the GUI tier's 1 s settle, the motion and the click arrive together and the click activates a
row the pointer only crossed: G5 aimed at start-screen row 26 and activated row 22 (NEWGAME)
(`.agent-tmp/p2exit/gui-diag.log`). Not reproduced on demand; the mechanism is read from the code.

The fix needs the row maths outside the render, which is a new `GuiDisplayGen` method: a new
interface, so recorded here rather than stretched into a fleet story.

## Decision

- `GuiDisplayGen` gains `- (int) rowAtVirtualJoystickPosition:(NSPoint)vjpos`, the y half of the
  cursor maths `-drawGUI:drawCursor:` used inline (clamp to half the GUI height, then the row).
  `-drawGUI:drawCursor:` calls it, so render and click share one formula.
- On an interactive GUI screen (`MOUSE_MODE_UI_SCREEN_WITH_INTERACTION`) a click or double-click
  activates `[gui rowAtVirtualJoystickPosition:[gameView virtualJoystickPosition]]`; in every
  other mode it keeps `UNIVERSE->cursor_row` as before.
- `tests/unit/core/test_GuiDisplayGen.mm` pins the method's maths without a render.

## Consequences

- In the steady state (pointer settled, a frame rendered) the two rows are equal, so behaviour is
  unchanged; only a click handled before the render that follows pointer motion changes, and it
  now activates what the pointer is on.
- When GuiDisplayGen is converted in Phase 3 the method converts with it, as a member.

## History

- 2026-09-30: proposed with the fix (oo-3rb.348).
