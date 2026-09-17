"""G1 - exit the game via mouse on the start screen.

The calibration exemplar for the GUI tier (docs/stories/G1-exit-via-mouse.md,
docs/phases/0-gui-tier.md). It is the baseline smoke test: the window opens, synthetic mouse
input reaches the game, and the menu shutdown path works. Everything else in this tier
(G2-G9) reuses conftest.py's ``game`` fixture and ``row_to_point`` and cites this file.

    python3 -m pytest upstream/oolite/tests/gui/test_g1_exit_via_mouse.py -x -q

Needs the desktop: a real window, unlocked and logged in (ADR-0017). It takes tools/gui-lock
for the duration.
"""

import time

import pytest

from conftest import (
    MAIN_GUI_PIXEL_HEIGHT,
    MAIN_GUI_ROW_HEIGHT,
    assert_clean_exit,
    assert_no_surviving_game_processes,
    point_to_row,
    row_to_point,
)

# PlayerEntity.m:9900-9960 - start-screen rows 22-27 are selectable and 27 is ` Exit Game `.
EXIT_GAME_ROW = 27
FIRST_SELECTABLE_ROW = 22

# The story's budget: a confirmed ` Exit Game ` that has not exited by now has not worked.
EXIT_TIMEOUT_SECONDS = 10


@pytest.mark.offline
@pytest.mark.parametrize("row", range(1, 28))
def test_row_to_point_is_its_own_inverse(row):
    """The grid maths, checked without a game.

    row_to_point aims at the centre of a row's band, so feeding its answer back through the
    chain the game itself walks (SDL motion -> virtualJoystickPosition -> cursor_row) must
    return the row we asked for. This is what makes "click row 27" a claim rather than a hope,
    and it is the part of the helper G2-G9 inherit unchanged.
    """
    for client_rect in ((0, 0, 960, 720), (37, 91, 1280, 720), (0, 0, 800, 600)):
        point = row_to_point(row, client_rect)
        assert point_to_row(point[0], point[1], client_rect) == row, (
            f"row {row} at {client_rect} round-tripped through {point}"
        )


@pytest.mark.offline
def test_unreachable_rows_are_refused_not_clamped():
    """Rows past the cursor's clamp must raise, never quietly resolve to a neighbour.

    GuiDisplayGen.m:1453-1456 clamps the cursor to the virtual half-height, so a point computed
    for row 29 selects row 28 instead. Returning that point would make a test click the wrong
    menu entry and still pass.
    """
    rect = (0, 0, 960, 720)
    for row in (29, 30, 40):
        with pytest.raises(ValueError):
            row_to_point(row, rect)
    # And the row this test actually needs is well inside.
    assert row_to_point(EXIT_GAME_ROW, rect)


@pytest.mark.offline
def test_row_points_are_distinct_and_ordered():
    """Adjacent rows must land on distinct points, increasing down the screen.

    A window small enough to collapse two rows onto the same pixel would make every menu test
    in this tier silently select the wrong thing, so the pinned size is checked, not assumed.
    """
    rect = (0, 0, 960, 720)
    ys = [row_to_point(row, rect)[1] for row in range(FIRST_SELECTABLE_ROW, EXIT_GAME_ROW + 1)]
    assert ys == sorted(ys)
    assert len(set(ys)) == len(ys)
    # One GUI row is MAIN_GUI_ROW_HEIGHT of 480 virtual pixels; at this window it must be worth
    # more than a couple of real ones.
    step = ys[1] - ys[0]
    assert step >= 2, f"rows are {step}px apart - the window is too small to click reliably"
    expected = MAIN_GUI_ROW_HEIGHT * 720 / MAIN_GUI_PIXEL_HEIGHT
    assert abs(step - expected) <= 1, f"row pitch {step}px, expected about {expected}px"


def test_g1_exit_via_mouse(game):
    """Launch, click ` Exit Game ` to select it, double-click to confirm, assert a clean exit.

    Two actions, not one. A single left click only calls setSelectedRow: on the row under the
    cursor (PlayerEntityControls.m:765-780); activation is Enter or a double-click. A test that
    single-clicks ` Exit Game ` and waits sits on the start screen until it times out.
    """
    assert game.proc.poll() is None, "the game exited before the test could click anything"

    # 1. Select. The click must not activate anything: the game is still running afterwards.
    x, y = game.select_row(EXIT_GAME_ROW)
    assert point_to_row(x, y, game.client_rect()) == EXIT_GAME_ROW
    time.sleep(0.5)
    assert game.proc.poll() is None, (
        "a single click activated a row; selection and activation are supposed to be distinct "
        "(PlayerEntityControls.m:765-780)"
    )

    # 2. Confirm.
    game.confirm_row(EXIT_GAME_ROW)

    # 3. Exits within the budget, with status 0.
    try:
        returncode = game.proc.wait(timeout=EXIT_TIMEOUT_SECONDS)
    except Exception:
        pytest.fail(
            f"the game was still running {EXIT_TIMEOUT_SECONDS}s after ` Exit Game ` was "
            f"confirmed at {(x, y)}"
        )
    assert returncode == 0, f"the game exited with {returncode}, not 0"

    # 4. No orphaned process. NOT `game.proc.poll() == 0` - wait() above already reaped and
    #    stored that returncode, so re-reading it is true by construction and checks nothing.
    #    Ask the OS process table instead, scoped to the tree we launched so a concurrent
    #    sibling GUI run's oolite.exe cannot be mistaken for our leak.
    assert_no_surviving_game_processes(game.proc.pid)

    # 5. G9 hygiene: no crash dump, no ERROR in the log, and a defaults file THIS RUN wrote and
    #    which re-parses. Passing the fixture itself rather than a directory is deliberate: the
    #    "written by this run" evidence is the launch-time mark GameWindow.start() recorded, and
    #    a call that could be spelled without it would be a check that cannot fail (oo-5rsa).
    assert_clean_exit(game)
