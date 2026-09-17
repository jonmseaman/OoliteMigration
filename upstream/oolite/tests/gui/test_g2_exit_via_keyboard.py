"""G2 - exit the game from the start screen with the KEYBOARD: ``Down`` x5, then ``Enter``.

docs/phases/0-gui-tier.md G2: "Launch -> ``Down``x5 -> ``Enter``", covering "the keyboard path
independently of mouse - a separate SDL3 code path from G1".

Written the way test_g1_exit_via_mouse.py is written and kept SHORT the way
test_g3_exit_via_window_close.py is: the desktop lock, the readiness gate, DPI awareness, the
pinned window, the process-table survivor check and the G9 hygiene asserts are all conftest.py's
and are reused verbatim. This file launches nothing of its own. What it adds is the keyboard
navigation, and the evidence that the keyboard is what did it.

THE EXIT CONTEXT CONVERGES WITH G1's. SAID PLAINLY.
---------------------------------------------------
G3's technique is to assert on an observable UNIQUELY attributable to the path under test - the
``@"SDL_QUIT event received"`` context string, unique among the tree's nine
``-exitAppWithContext:`` call sites. G2 has no such luck at the exit, and pretending otherwise
would be the exact dishonesty this tier exists to prevent:

    PlayerEntityControls.m:4980-4982
        else if (([gameView isDown:gvMouseDoubleClick] || [self checkKeyPress:n_key_gui_select])
                 && [gui selectedRow] == 6+row_zero)
        {
            [[UNIVERSE gameController] exitAppWithContext:@"Exit Game selected on start screen"];
        }

ONE expression, an ``||`` of the double-click and the select key, reaching ONE
``exitAppWithContext:``. G1 (mouse) and G2 (keyboard) therefore produce a byte-identical
``[exit.context]`` line. That string IS unique in the tree - verified by
``test_the_start_screen_exit_context_is_unique_in_the_tree`` - so asserting it proves the
START-SCREEN ``Exit Game`` row ran rather than one of the other eight exit sites, and it is
asserted here for that reason. It proves NOTHING about keyboard versus mouse, and this file does
not claim it does.

THE DISCRIMINATOR: FIVE SINGLE-ROW STEPS, WHICH ONLY AN ARROW KEY CAN PRODUCE
-----------------------------------------------------------------------------
The keyboard-only observable is upstream of the exit, in how the selection MOVED. Two facts,
both pinned by tree-wide greps in this file so they cannot rot:

* ``-[GuiDisplayGen setNextRow:]`` (GuiDisplayGen.m:517) - the only RELATIVE selection move in
  the game - has exactly TWO call sites in the whole tree, PlayerEntityControls.m:729 and :749,
  both inside ``-handleGUIUpDownArrowKeys`` and both gated on ``checkKeyPress:`` of
  ``n_key_gui_arrow_down`` / ``n_key_gui_arrow_up``. There is no mouse path to it and no script
  path to it.
* The mouse branches of that same method (:765-:787) call ``setSelectedRow:UNIVERSE->cursor_row``
  - an ABSOLUTE jump to whatever row the pointer is over. A mouse cannot step by one except by
  the coincidence of being parked one row down, and this test never moves the pointer at all.

Every one of those calls ends in ``-reportSelectedRow:`` (GuiDisplayGen.m:572), whose sole act is
to fire the ``guiSelectedRowChanged`` world-script event with the new row number. So the run's own
selection trace is readable from inside the game, and a trace of FIVE SUCCESSIVE +1 TRANSITIONS
from the first selectable row to ``Exit Game`` is producible only by five arrow-key presses. That
is this file's G3-equivalent: an observable attributable to the keyboard and to nothing else,
asserted from the live run.

The trace is read the way G5 reads ``guiScreen`` - over the debug console (tests/component/
console.py's protocol), installing a ``guiSelectedRowChanged`` handler on the console's own world
script (``console.script``, oolite-debug-console.js:721) so the events land in an array this test
can query. The console plumbing is a lean re-spelling of G5's for the same reason G5 gave for not
putting its own in conftest.py: concurrent beads against one conftest are a guaranteed conflict.

ROW ADDRESSING IS DERIVED, NOT COUNTED ON FINGERS
-------------------------------------------------
No literal 5, 22 or 27 appears in the navigation. ``start_screen_layout()`` reads
``-setupStartScreenGui`` (PlayerEntity.m) for its ``int initialRow`` and the number of
``oolite-start-option-N`` rows it lays out, and ``exit_row_dispatch()`` reads the start-screen
case of ``-pollDemoControls`` (PlayerEntityControls.m) for its ``int row_zero``, the ``N+row_zero``
offset of the branch that calls ``exitAppWithContext:``, AND the context string that branch
passes. The two derivations must agree on which row is ``Exit Game``, the number of Down presses
is their difference, and the expected context is the one the source actually contains. A layout
change fails this file loudly and by name instead of quietly selecting the wrong thing.

    python3 -m pytest upstream/oolite/tests/gui/test_g2_exit_via_keyboard.py -x -q

Needs the desktop: a real window, unlocked and logged in (ADR-0017). It takes tools/gui-lock for
the duration, via the ``game`` fixture.
"""

import ast
import os
import plistlib
import re
import select
import socket
import struct
import tempfile
import time

import pytest

from conftest import (
    assert_clean_exit,
    assert_no_surviving_game_processes,
    assert_shutdown_path_completed,
)

HERE = os.path.dirname(os.path.abspath(__file__))
OOLITE_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC_DIR = os.path.join(OOLITE_ROOT, "src")
PLAYER_ENTITY = os.path.join(SRC_DIR, "Core", "Entities", "PlayerEntity.m")
PLAYER_CONTROLS = os.path.join(SRC_DIR, "Core", "Entities", "PlayerEntityControls.m")

# The start screen, the only screen this test is ever on. PlayerEntity.m's -setGuiToIntroFirstGo:
# leaves gui_screen here; G5 pins that this identifier is assigned in exactly one place.
START_SCREEN = "GUI_SCREEN_INTRO1"

# How long a Down is HELD. The game samples key state once per pollDemoControls frame
# (PlayerEntityControls.m:4943 -> :715), so a tap between two polls is simply never seen - the
# defect G5 measured with pyautogui.press() and space. Generous, because a missed press is the
# one flake that would make this test non-repeatable.
KEY_HOLD_SECONDS = 0.30
# And how long it is RELEASED afterwards, before the next press. -handleGUIUpDownArrowKeys latches
# ``upDownKeyPressed`` (PlayerEntityControls.m:795) so a held key cannot auto-repeat below
# KEY_REPEAT_INTERVAL (PlayerEntity.h:333, 0.20s); the latch clears on the first poll that sees
# the key up, which is what makes five presses five DISCRETE steps rather than one long repeat.
KEY_RELEASE_SECONDS = 0.30
# How long the game is given to report a selection move after a press.
STEP_TIMEOUT_SECONDS = 8
# The story's budget for the exit, the same one G1, G3 and G5 use.
EXIT_TIMEOUT_SECONDS = 10


# --- the rows, derived from the game's own definitions ------------------------------------------


def _read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def _method_body(source, signature):
    """The text of one Objective-C method, from its signature to its closing brace."""
    start = source.find(signature)
    assert start >= 0, f"{signature!r} is no longer in the source; G2's row derivation is broken"
    end = source.find("\n}\n", start)
    assert end > start, f"could not find the end of {signature!r}"
    return source[start:end]


def start_screen_layout():
    """``(first_row, option_count)`` as ``-setupStartScreenGui`` lays the menu out.

    PlayerEntity.m builds the start screen with a bare ``int initialRow = N;`` followed by one
    ``DESC(@"oolite-start-option-K")`` per row. There is no enum and no #define to import, so the
    numbers are READ FROM THE SOURCE rather than copied into this file, which is what makes the
    Down count a derivation instead of a magic 5.
    """
    body = _method_body(_read(PLAYER_ENTITY), "- (void) setupStartScreenGui")
    match = re.search(r"int\s+initialRow\s*=\s*(\d+)\s*;", body)
    assert match, (
        "-setupStartScreenGui no longer declares `int initialRow = N;`, so G2 cannot derive "
        "which row the start menu begins on and must not guess one"
    )
    options = sorted({int(n) for n in re.findall(r'oolite-start-option-(\d+)"', body)})
    assert options, "-setupStartScreenGui lays out no `oolite-start-option-N` rows at all"
    assert options == list(range(1, len(options) + 1)), (
        f"the start screen's option keys are not a contiguous 1..N run: {options}"
    )
    return int(match.group(1)), len(options)


def exit_row_dispatch():
    """``(exit_row, context)`` as the start screen's own dispatcher defines them.

    PlayerEntityControls.m's ``case GUI_SCREEN_INTRO1:`` declares a second bare
    ``int row_zero = N;`` and dispatches each menu row as ``[gui selectedRow] == K+row_zero``. The
    branch that calls ``-exitAppWithContext:`` gives us BOTH the ` Exit Game ` row and the exact
    context string the game will log, so neither is hardcoded here.
    """
    body = _method_body(_read(PLAYER_CONTROLS), "- (void) pollDemoControls:(double)delta_t")
    match = re.search(r"int\s+row_zero\s*=\s*(\d+)\s*;", body)
    assert match, (
        "the start-screen dispatcher no longer declares `int row_zero = N;`, so G2 cannot derive "
        "which row ` Exit Game ` is"
    )
    row_zero = int(match.group(1))
    branch = re.search(
        r"\[gui selectedRow\]\s*==\s*(\d+)\s*\+\s*row_zero\s*\)\s*\{\s*"
        r"\[\[UNIVERSE gameController\] exitAppWithContext:@\"([^\"]+)\"\]",
        body,
    )
    assert branch, (
        "no `[gui selectedRow] == K+row_zero` branch on the start screen calls "
        "-exitAppWithContext: any more; G2 has no ` Exit Game ` row to aim at"
    )
    return row_zero + int(branch.group(1)), branch.group(2)


FIRST_SELECTABLE_ROW, START_OPTION_COUNT = start_screen_layout()
EXIT_GAME_ROW, EXPECTED_EXIT_CONTEXT = exit_row_dispatch()
# Selection starts on the first selectable row (``[gui setSelectedRow:initialRow]``), so reaching
# ` Exit Game ` costs exactly this many single-row steps. THE story's "Down x5", derived.
DOWN_PRESSES = EXIT_GAME_ROW - FIRST_SELECTABLE_ROW
# The rows the selection must visit, in order, one per press.
EXPECTED_ROW_TRACE = list(range(FIRST_SELECTABLE_ROW + 1, EXIT_GAME_ROW + 1))


# --- the selection trace, read out of the running game ------------------------------------------
#
# Protocol constants, spelled as tests/component/console.py and G5 spell them.
PACKET_TYPE_KEY = "packet type"
MESSAGE_KEY = "message"
REQUEST_CONNECTION = "Request Connection"
APPROVE_CONNECTION = "Approve Connection"
PERFORM_COMMAND = "Perform Command"
CONSOLE_OUTPUT = "Console Output"
CONSOLE_IDENTITY_KEY = "console identity"

# The world-script event -reportSelectedRow: fires (GuiDisplayGen.m:572). Its second argument is
# the new row number.
SELECTION_EVENT = "guiSelectedRowChanged"
# Where the handler installed below stashes the rows it is told about. A ``$``-prefixed name so it
# cannot collide with anything oolite-debug-console.js defines on itself.
TRACE_PROPERTY = "$g2SelectionTrace"


class SelectionWitnessError(AssertionError):
    """The console could not tell us how the selection moved."""


class SelectionWitness:
    """Reads the game's own ``guiSelectedRowChanged`` trace over the debug console.

    It is the GAME that dials US (OODebugSupport.m:67-80), so the socket must be listening BEFORE
    the game starts - hence the fixture below is built ahead of ``game``. The port is private to
    this session and handed over by writing debugConfig.plist into a throwaway resource root, the
    way tests/launch_snapshot.py and G5 both do; a fixed 8563 would collide with a component-tier
    run on this shared machine.
    """

    def __init__(self):
        self._server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._server.bind(("127.0.0.1", 0))
        self.port = self._server.getsockname()[1]
        self._server.listen(1)
        self._server.setblocking(False)
        self._conn = None
        self.config_root = self._write_config_root()

    def _write_config_root(self):
        root = tempfile.mkdtemp(prefix=f"oolite-g2-console-{self.port}-")
        config = os.path.join(root, "Config")
        os.makedirs(config, exist_ok=True)
        with open(os.path.join(config, "debugConfig.plist"), "wb") as handle:
            plistlib.dump(
                {"console-host": "127.0.0.1", "console-port": self.port},
                handle,
                fmt=plistlib.FMT_XML,
            )
        return root

    def accept(self, timeout=60):
        deadline = time.time() + timeout
        while time.time() < deadline:
            readable, _, _ = select.select([self._server], [], [], 1)
            if readable:
                self._conn, _ = self._server.accept()
                # An accepted socket INHERITS the listener's non-blocking mode on Windows, so
                # _recv_exactly would raise WinError 10035 instead of waiting for the rest of a
                # packet (oo-8yp). Every read is deadline-guarded by select(), so blocking is safe.
                self._conn.setblocking(True)
                self._handshake()
                return self
        raise SelectionWitnessError(
            f"the game never dialled the debug console on 127.0.0.1:{self.port} within "
            f"{timeout}s. G2 proves the KEYBOARD moved the selection by reading the game's own "
            f"{SELECTION_EVENT} trace, so without this connection it cannot tell a keyboard "
            "walk from a mouse jump and must not pass. Check that Basic-debug.oxp is present in "
            "the build's AddOns directory."
        )

    def _handshake(self):
        packet = self._recv()
        if packet is None or packet.get(PACKET_TYPE_KEY) != REQUEST_CONNECTION:
            raise SelectionWitnessError(f"unexpected first console packet: {packet!r}")
        self._send({PACKET_TYPE_KEY: APPROVE_CONNECTION, CONSOLE_IDENTITY_KEY: "oolite G2"})

    # --- the two things this witness can be asked ---------------------------------------------

    def evaluate(self, expression):
        """Evaluate a JS expression in the game and return its value as a string."""
        # The console echoes the command text back before the answer, so a marker that appears
        # literally in the command would match its own echo. Split in the source and joined at
        # runtime, the same trick console.py::evaluate and G5 use.
        head = f"@@g2-{os.getpid()}-{self.port}"
        tail = f"{int(time.time() * 1000) % 1000000}@@"
        marker = head + tail
        self._send({
            PACKET_TYPE_KEY: PERFORM_COMMAND,
            MESSAGE_KEY: (
                'debugConsole.consoleMessage("command-result", '
                f'"{head}" + "{tail}" + String({expression}) + "{head}" + "{tail}");'
            ),
        })
        deadline = time.time() + 15
        while time.time() < deadline:
            readable, _, _ = select.select([self._conn], [], [], 1)
            if not readable:
                continue
            packet = self._recv()
            if packet is None:
                raise SelectionWitnessError("the console connection closed mid-query")
            if packet.get(PACKET_TYPE_KEY) != CONSOLE_OUTPUT:
                continue
            text = str(packet.get(MESSAGE_KEY, ""))
            if text.count(marker) >= 2:
                return text.split(marker)[1]
        raise SelectionWitnessError(f"no answer to {expression!r} within 15s")

    def arm(self):
        """Install the ``guiSelectedRowChanged`` handler and clear the trace.

        ``console.script`` is the debug console's own world script object
        (oolite-debug-console.js:721), and PlayerEntity.m:12889-12892 dispatches every player
        script event to every world script - so defining the handler there is enough for
        -reportSelectedRow: to reach it. Called AFTER the game has settled, so the selection
        moves it records are only the ones this test caused.
        """
        self.evaluate(
            f"(function(){{ var s = console.script;"
            f" s.{TRACE_PROPERTY} = [];"
            f" s.{SELECTION_EVENT} = function(key, row, text)"
            f" {{ s.{TRACE_PROPERTY}.push(row); }};"
            f" return s.{TRACE_PROPERTY}.length; }})()"
        )
        installed = self.evaluate(f"typeof console.script.{SELECTION_EVENT}")
        if installed != "function":
            raise SelectionWitnessError(
                f"the {SELECTION_EVENT} handler did not install (typeof is {installed!r}), so "
                "the selection trace would be empty however the selection moved - which would "
                "turn G2's keyboard evidence into a check that cannot fail"
            )
        return self.trace()

    def trace(self):
        """The rows the game has reported selecting since ``arm()``, in order."""
        answer = self.evaluate(f"console.script.{TRACE_PROPERTY}.join(',')")
        answer = answer.strip()
        if not answer:
            return []
        return [int(part) for part in answer.split(",")]

    def await_trace_length(self, length, timeout=STEP_TIMEOUT_SECONDS):
        deadline = time.time() + timeout
        seen = self.trace()
        while len(seen) < length and time.time() < deadline:
            time.sleep(0.2)
            seen = self.trace()
        return seen

    def close(self):
        import shutil

        for sock in (self._conn, self._server):
            try:
                if sock is not None:
                    sock.close()
            except OSError:
                pass
        shutil.rmtree(self.config_root, ignore_errors=True)

    # --- framing ------------------------------------------------------------------------------

    def _send(self, packet):
        data = plistlib.dumps(packet, fmt=plistlib.FMT_XML)
        self._conn.sendall(struct.pack(">I", len(data)) + data)

    def _recv_exactly(self, count):
        buffer = b""
        while len(buffer) < count:
            chunk = self._conn.recv(count - len(buffer))
            if not chunk:
                return None
            buffer += chunk
        return buffer

    def _recv(self):
        header = self._recv_exactly(4)
        if header is None:
            return None
        body = self._recv_exactly(struct.unpack(">I", header)[0])
        return plistlib.loads(body) if body else None


@pytest.fixture
def selection_witness():
    """Listen for the game's console connection, and tell the game where to dial.

    Named FIRST in the test's signature so pytest builds it BEFORE ``game``: the game dials out
    during startup, so a socket that starts listening afterwards is never connected to. The
    environment variable is set here rather than in a launcher because ``GameWindow._env`` copies
    ``os.environ``, which is how this file adds a resource root without adding a launcher.
    """
    witness = SelectionWitness()
    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    roots = [witness.config_root.replace("\\", "/")]
    if previous:
        roots.append(previous)
    os.environ["OO_ADDITIONALADDONSDIRS"] = ",".join(roots)
    try:
        yield witness
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        witness.close()


# --- the keystrokes -----------------------------------------------------------------------------


def hold_key(game, key, seconds=KEY_HOLD_SECONDS):
    """Press and release ``key``, holding it long enough for one poll to sample it."""
    import pyautogui

    # Re-takes the foreground if something transiently stole it, then asserts (oo-0p8f). Synthetic
    # KEYBOARD input goes to the focused window, so unlike a click it does not depend on Z-order
    # and assert_click_point_is_ours has nothing to say about it.
    game.assert_focused()
    pyautogui.keyDown(key)
    time.sleep(seconds)
    pyautogui.keyUp(key)
    time.sleep(KEY_RELEASE_SECONDS)


def step_down_once(game, witness, expected_row, already):
    """One ``Down``, and the proof that the game moved the selection by exactly one row.

    Returns the new trace. A press the poll loop never sampled produces NO event at all, so it is
    retried once - the retry cannot double-step, because a second event would make the trace
    longer than ``already + 1`` and the assertion below names that.
    """
    for _ in range(2):
        hold_key(game, "down")
        seen = witness.await_trace_length(already + 1)
        if len(seen) > already:
            break
    assert len(seen) == already + 1, (
        f"pressing Down to reach row {expected_row} moved the selection "
        f"{len(seen) - already} time(s), not once. The game reported {seen!r}; "
        f"-handleGUIUpDownArrowKeys (PlayerEntityControls.m:715-798) is supposed to advance one "
        "selectable row per discrete press."
    )
    assert seen[-1] == expected_row, (
        f"Down moved the selection to row {seen[-1]}, not {expected_row}. The full trace is "
        f"{seen!r} against the expected {EXPECTED_ROW_TRACE!r}, derived from "
        f"-setupStartScreenGui's initialRow ({FIRST_SELECTABLE_ROW}) and the start-screen "
        f"dispatcher's ` Exit Game ` row ({EXIT_GAME_ROW})."
    )
    return seen


# --- the test -----------------------------------------------------------------------------------


def test_g2_exit_via_keyboard(selection_witness, game):
    """Walk to ` Exit Game ` with five Downs, press Enter, and assert a clean exit.

    The pointer is never moved and no button is ever pressed: every input in this test is a key.
    What is asserted, in order:

    1. the game is on the START SCREEN before anything is pressed, so a layout change fails here
       rather than selecting whatever now sits at the derived row;
    2. each Down moves the selection by EXACTLY ONE ROW, to the next row in the derived sequence
       - the observable only ``-setNextRow:`` can produce and only an arrow key can reach;
    3. the selection lands on ` Exit Game ` and the game is still running, because navigating is
       not activating;
    4. Enter exits it, within the budget, with status 0;
    5. nothing of ours survives in the OS process table, the G9 hygiene evidence holds, and the
       shutdown trace names the START-SCREEN exit context (shared with G1's mouse path by
       construction - see this module's docstring - so it is asserted as proof of WHICH ROW ran,
       not of which input device ran it).
    """
    witness = selection_witness.accept()
    assert game.proc.poll() is None, "the game exited before the test could press anything"
    # Synthetic key input is delivered to the FOCUSED window, so this is the precondition for
    # every press below. assert_focused() self-heals a transiently stolen foreground (oo-0p8f).
    game.assert_focused()

    # 1. On the start screen, per the game's own guiScreen - the same observable G5 uses, and the
    #    "assert which screen you are on before pressing" that row derivation calls for.
    screen = witness.evaluate("guiScreen")
    assert screen == START_SCREEN, (
        f"the game is on {screen}, not {START_SCREEN}, so the rows derived from "
        "-setupStartScreenGui do not describe what is on the screen and pressing Down would "
        "navigate an unknown menu"
    )
    assert witness.arm() == [], "the selection trace was not empty after arming"

    # 2. Five Downs, each proved to be one step. DOWN_PRESSES is derived, not typed.
    trace = []
    for expected_row in EXPECTED_ROW_TRACE:
        trace = step_down_once(game, witness, expected_row, len(trace))
    assert trace == EXPECTED_ROW_TRACE, (
        f"the selection walked {trace!r}, not {EXPECTED_ROW_TRACE!r}"
    )

    # 3. Navigation is not activation: the game is still running, on the start screen, with
    #    ` Exit Game ` merely selected.
    assert game.proc.poll() is None, (
        f"the game exited during navigation, before Enter was pressed. {DOWN_PRESSES} Down "
        "presses are supposed to move the selection and nothing else."
    )
    screen = witness.evaluate("guiScreen")
    assert screen == START_SCREEN, (
        f"navigating left the game on {screen}; Down is supposed to move the selection within "
        f"{START_SCREEN}, not change screen"
    )

    # 4. Enter. PlayerEntityControls.m's start-screen dispatcher activates the selected row on
    #    ``[self checkKeyPress:n_key_gui_select]``, which is what Enter is bound to.
    hold_key(game, "enter")
    try:
        returncode = game.proc.wait(timeout=EXIT_TIMEOUT_SECONDS)
    except Exception:
        pytest.fail(
            f"the game was still running {EXIT_TIMEOUT_SECONDS}s after Enter was pressed on row "
            f"{EXIT_GAME_ROW} (` Exit Game `), which the selection trace {trace!r} shows was "
            "selected. The keyboard activation path did not take the game down."
        )
    assert returncode == 0, f"the game exited with {returncode}, not 0"

    # 5. No orphaned process. Asked of the OS process table, not of proc.poll(): wait() above has
    #    already reaped and stored that returncode, so re-reading it is true by construction
    #    (oo-5rsa). Scoped to the tree we launched so a concurrent sibling's oolite.exe is not
    #    mistaken for our leak.
    assert_no_surviving_game_processes(game.proc.pid)

    # 6. G9 hygiene: no dump, no ERROR, a defaults file THIS run wrote and which re-parses. The
    #    fixture is passed rather than a directory so the launch-time mark travels with it.
    assert_clean_exit(game)

    # 7. The shutdown ran to its last line, and it ran for the START-SCREEN ` Exit Game ` row
    #    rather than for any of the other eight exit sites in the tree.
    assert_shutdown_path_completed(game, expected_context=EXPECTED_EXIT_CONTEXT)


# --- offline guards: the uniqueness proofs this file rests on -----------------------------------


def _objc_sources():
    sources = []
    for root, _dirs, files in os.walk(SRC_DIR):
        for name in files:
            if name.endswith((".m", ".mm", ".c", ".h")):
                sources.append(os.path.join(root, name))
    assert sources, f"no Objective-C sources under {SRC_DIR}"
    return sources


def _grep(pattern):
    """``[(relative_path, line_number, line), ...]`` over the whole source tree."""
    regex = re.compile(pattern)
    hits = []
    for path in _objc_sources():
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for number, line in enumerate(handle, 1):
                if regex.search(line):
                    hits.append((os.path.relpath(path, OOLITE_ROOT), number, line.strip()))
    return hits


@pytest.mark.offline
def test_the_start_screen_exit_context_is_unique_in_the_tree():
    """The context string this test asserts on must name exactly ONE call site.

    THE TREE-WIDE GREP, G3's technique. -exitAppWithContext: is reached from several places and
    every one of them synchronizes defaults, closes the log and exits 0, so the context line is
    the only runtime evidence of WHICH one ran. A second site passing the same string would make
    step 7 of the launching test a weaker claim than its message says.
    """
    hits = _grep(r'exitAppWithContext:@"' + re.escape(EXPECTED_EXIT_CONTEXT) + r'"')
    assert len(hits) == 1, (
        f"{EXPECTED_EXIT_CONTEXT!r} is passed to -exitAppWithContext: from {len(hits)} places, "
        f"not 1: {hits}. G2 asserts that string to prove the start-screen ` Exit Game ` row ran."
    )
    # And it must be genuinely distinct from every OTHER context in the tree, or "in" matching
    # would let a different path satisfy it.
    others = {
        match
        for _path, _number, line in _grep(r'exitAppWithContext:@"')
        for match in re.findall(r'exitAppWithContext:@"([^"]+)"', line)
    } - {EXPECTED_EXIT_CONTEXT}
    assert others, "no other exit contexts found at all; this guard is not reading the tree"
    for other in others:
        assert EXPECTED_EXIT_CONTEXT not in other, (
            f"{other!r} contains {EXPECTED_EXIT_CONTEXT!r}, so a substring match cannot tell them "
            "apart and assert_shutdown_path_completed's `in` test would accept the wrong path"
        )


@pytest.mark.offline
def test_the_keyboard_and_mouse_exit_paths_converge_on_one_call_site():
    """STATED PLAINLY, AND PINNED: the exit context does NOT discriminate keyboard from mouse.

    This is not a lament, it is the guard that keeps the module docstring honest. The branch that
    exits is one ``||`` of the double-click and the select key, so G1 and G2 log the identical
    context. If a future edit ever split them, this test goes RED and whoever sees it gets to
    replace G2's selection-trace evidence with the far simpler context assertion.
    """
    body = _method_body(_read(PLAYER_CONTROLS), "- (void) pollDemoControls:(double)delta_t")
    branch = re.search(
        r"(\([^\n]*\)[^\n]*\[gui selectedRow\]\s*==\s*\d+\s*\+\s*row_zero\s*\))\s*\{\s*"
        r"\[\[UNIVERSE gameController\] exitAppWithContext:",
        body,
    )
    assert branch, "the start screen's exit branch is no longer recognisable"
    condition = branch.group(1)
    assert "gvMouseDoubleClick" in condition and "n_key_gui_select" in condition, (
        "the start-screen ` Exit Game ` branch no longer tests BOTH gvMouseDoubleClick and "
        f"n_key_gui_select: {condition!r}. G2's docstring claims the mouse and keyboard exits "
        "converge on this one call site and therefore share a context string; that claim must be "
        "re-derived."
    )


@pytest.mark.offline
def test_a_single_row_step_is_reachable_only_from_the_arrow_keys():
    """THE KEYBOARD DISCRIMINATOR'S UNIQUENESS PROOF.

    G2 claims that a trace of successive +1 selection moves can only have come from arrow-key
    presses. That rests on ``-setNextRow:`` - the game's only RELATIVE selection move - being
    called from nowhere but the two arrow branches of -handleGUIUpDownArrowKeys, and on the mouse
    branches of that same method jumping ABSOLUTELY to the cursor's row instead. Both are checked
    here over the whole tree, so a future call site added anywhere silently weakens nothing.
    """
    calls = [hit for hit in _grep(r"\[\s*gui\s+setNextRow:") if not hit[0].endswith(".h")]
    assert len(calls) == 2, (
        f"-setNextRow: is called from {len(calls)} places, not 2: {calls}. G2 reads a +1 "
        "selection step as proof that an arrow key was pressed; a third call site would have to "
        "be shown to be unreachable from the mouse before that claim could stand."
    )
    assert {path for path, _number, _line in calls} == {
        os.path.relpath(PLAYER_CONTROLS, OOLITE_ROOT)
    }, f"-setNextRow: is now called from outside PlayerEntityControls.m: {calls}"

    body = _method_body(_read(PLAYER_CONTROLS), "- (BOOL) handleGUIUpDownArrowKeys")
    assert body.count("[gui setNextRow:") == 2, (
        "-handleGUIUpDownArrowKeys no longer contains both -setNextRow: calls, so the two the "
        "tree-wide grep found are somewhere else entirely"
    )
    # Each one is guarded by an arrow key read, and by nothing else.
    for direction, key in ((r"\+1", "n_key_gui_arrow_down"), (r"-1", "n_key_gui_arrow_up")):
        guard = re.search(
            r"BOOL\s+(\w+)\s*=\s*\[self checkKeyPress:" + key + r"\]", body
        )
        assert guard, f"-handleGUIUpDownArrowKeys no longer reads {key}"
        block = re.search(
            r"if\s*\(\s*" + guard.group(1) + r"\s*\)(.*?)\[gui setNextRow:\s*" + direction,
            body,
            re.S,
        )
        assert block, (
            f"the -setNextRow:{direction} call is no longer inside the `if ({guard.group(1)})` "
            f"block, so a +/-1 selection step no longer proves {key} was down"
        )

    # And the mouse cannot step: its branches set an ABSOLUTE row from the cursor.
    for mouse in ("mouse_click", "mouse_dbl_click"):
        block = re.search(r"if\s*\(\s*" + mouse + r"\s*\)\s*\{(.*?)\n\t\}", body, re.S)
        assert block, f"-handleGUIUpDownArrowKeys no longer has an `if ({mouse})` branch"
        assert "setSelectedRow:click_row" in block.group(1), (
            f"the {mouse} branch no longer jumps to the cursor's row absolutely: "
            f"{block.group(1)!r}"
        )
        assert "setNextRow" not in block.group(1), (
            f"the {mouse} branch now calls -setNextRow:, so a +1 selection step no longer proves "
            "a keyboard press and G2's central claim is false"
        )


@pytest.mark.offline
def test_the_selection_event_is_fired_from_every_selection_move():
    """``guiSelectedRowChanged`` must be what -reportSelectedRow: fires, or the trace is blind.

    A rename here would leave the handler installed on a name nothing ever calls: the trace would
    be empty, every press would look missed, and the failure would read as "the keyboard does not
    work" rather than "the test is listening to the wrong event".
    """
    hits = _grep(r'doScriptEvent:OOJSID\("' + SELECTION_EVENT + r'"\)')
    assert len(hits) == 1, (
        f"{SELECTION_EVENT} is fired from {len(hits)} places, not 1: {hits}"
    )
    gui = _read(os.path.join(SRC_DIR, "Core", "GuiDisplayGen.m"))
    body = _method_body(gui, "- (void) reportSelectedRow:")
    assert SELECTION_EVENT in body, (
        f"-reportSelectedRow: no longer fires {SELECTION_EVENT}, so nothing reports a selection "
        "move and G2's trace would be empty however the selection moved"
    )
    # Every selection setter must report, or a step could happen unobserved and the trace would
    # be short by one while the navigation was perfectly correct.
    for setter in ("setSelectedRow:", "setNextRow:", "setFirstSelectableRow", "setLastSelectableRow"):
        setter_body = _method_body(gui, "- (BOOL) " + setter)
        assert "reportSelectedRow:" in setter_body, (
            f"-{setter} changes the selection without calling -reportSelectedRow:, so a move it "
            "makes is invisible to G2's trace"
        )


@pytest.mark.offline
def test_the_rows_are_derived_from_the_game_and_agree_with_each_other():
    """The two independent derivations must describe the same menu - and no literal may creep in.

    ``-setupStartScreenGui`` says where the menu starts and how many rows it has;
    the start-screen dispatcher says which row exits. They are written in different files by
    different constants and this file trusts neither alone: they must AGREE, and the number of
    Down presses is their difference rather than a number anyone typed.
    """
    first, count = start_screen_layout()
    exit_row, context = exit_row_dispatch()
    assert first == FIRST_SELECTABLE_ROW and count == START_OPTION_COUNT
    assert exit_row == EXIT_GAME_ROW and context == EXPECTED_EXIT_CONTEXT
    assert exit_row == first + count - 1, (
        f"-setupStartScreenGui lays out {count} rows from {first} (so its last is "
        f"{first + count - 1}), but the dispatcher exits on row {exit_row}. The start menu and "
        "the code that reads it disagree; G2 would press Enter on the wrong row."
    )
    assert DOWN_PRESSES == exit_row - first
    assert EXPECTED_ROW_TRACE == list(range(first + 1, exit_row + 1))
    assert DOWN_PRESSES == 5, (
        f"the derivation now needs {DOWN_PRESSES} Down presses, not the 5 in "
        "docs/phases/0-gui-tier.md's G2 row. That is not necessarily a bug - the menu may have "
        "gained or lost an entry - but the story and this assertion must be updated together, "
        "deliberately, rather than the test silently pressing a different number of times."
    )


@pytest.mark.offline
def test_g2_presses_keys_and_never_touches_the_mouse():
    """THE ANTI-DECAY GUARD: G2 must remain a KEYBOARD test.

    Read from this file's own AST, not its text, so a docstring or a comment cannot hold it green
    (the sibling-bead defect G5 documents). A future edit that reached ` Exit Game ` with
    ``select_row``/``confirm_row`` - or that killed the process instead of pressing Enter - would
    leave every assertion in the launching test passing while the keyboard path could be deleted
    outright without anything going red.
    """
    with open(os.path.join(HERE, "test_g2_exit_via_keyboard.py"), "r", encoding="utf-8") as h:
        tree = ast.parse(h.read())
    functions = {node.name: node for node in tree.body if isinstance(node, ast.FunctionDef)}
    assert "test_g2_exit_via_keyboard" in functions, (
        "the G2 test function has been renamed; this guard must be renamed with it"
    )
    reachable = [functions["test_g2_exit_via_keyboard"]]
    for helper in ("step_down_once", "hold_key"):
        assert helper in functions, f"{helper} is gone; G2's key presses are not where they were"
        reachable.append(functions[helper])

    attribute_calls, name_calls = set(), set()
    for func in reachable:
        for node in ast.walk(func):
            if not isinstance(node, ast.Call):
                continue
            if isinstance(node.func, ast.Attribute):
                attribute_calls.add(node.func.attr)
            elif isinstance(node.func, ast.Name):
                name_calls.add(node.func.id)

    assert {"keyDown", "keyUp"} <= attribute_calls, (
        "G2 no longer presses keys with pyautogui.keyDown/keyUp; it is supposed to exercise the "
        "keyboard path, which is the only thing it covers that G1 does not"
    )
    for forbidden in ("select_row", "confirm_row", "click", "doubleClick", "moveTo", "mouseDown"):
        assert forbidden not in attribute_calls, (
            f"G2 calls {forbidden}(); that is G1's mouse path, and a G2 that uses it proves "
            "nothing about the keyboard"
        )
    for forbidden in ("terminate", "kill", "send_signal", "close_window"):
        assert forbidden not in attribute_calls, (
            f"G2 calls {forbidden}(); killing or closing the game proves the OS can end a "
            "process, not that Enter on ` Exit Game ` exits it cleanly"
        )
    # And the post-exit hygiene the tier requires of every launching test (G9's meta-guard) must
    # be present as real calls.
    for helper in ("assert_no_surviving_game_processes", "assert_clean_exit"):
        assert helper in name_calls, f"G2 never calls {helper}()"
