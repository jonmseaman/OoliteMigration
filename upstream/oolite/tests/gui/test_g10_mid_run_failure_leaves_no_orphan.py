"""A GUI test that fails MID-RUN, with the game up, must leave no orphaned oolite.exe.

Bead oo-njnw. The bead was filed as a defect: "conftest's shared ``game`` fixture does not take
the process down when a test fails while the game is up; an oolite.exe SURVIVES the run", with a
reviewer's report of an ``assert False`` injected into test_g1_exit_via_mouse.py on pristine main
leaving a survivor behind.

THAT DEFECT DOES NOT EXIST, and this file is the evidence that it does not, pinned so it cannot
come back. Measured by injecting exactly that failure - a scratch copy of
test_g1_exit_via_mouse.py with ``assert False`` placed after step 1's ``select_row``, i.e. with
the game demonstrably up - and recording the pid the run itself launched:

    current main 602219c    rc=1, "1 failed, 38 passed in 27.66s", launched pid 11144 -> GONE
    pristine     fd501c4    rc=1, "1 failed, 38 passed in 26.51s", launched pid  6384 -> GONE

fd501c4 is the very tree the bead was filed against, so this is not a leak some later bead fixed
by accident: the teardown was already correct. ``GameWindow.kill`` is byte-identical between the
two trees. The original sighting was a CONCURRENT AGENT'S oolite.exe - five agents share this
desktop - and a bare ``tasklist /FI "IMAGENAME eq oolite.exe"`` cannot tell that from a leak of
one's own. Recording the launched pid and asking about THAT pid is what distinguishes them, and it
is why every assertion below is pid-scoped.

WHY THE TEARDOWN IS SOUND, which is the property this file locks. ``game`` is a generator fixture
whose ``yield`` sits inside a ``try/finally``. When a test body raises, pytest throws that
exception INTO the generator at the yield point, so the ``finally: window.kill()`` runs during the
unwind - identically for a passing test and a failing one. There is no separate failure path to
leak down.

HOW THE MID-RUN FAILURE IS INJECTED HERE. This test does not take the ``game`` fixture; it takes
``game``'s own dependencies and drives the REAL fixture generator (``conftest.game``'s underlying
generator function) by hand, so that it can ``throw()`` into it at the yield - which is precisely
what pytest does to unwind a failed test. A test that merely took the fixture and failed could
not then assert anything, because its own assertions would never run. Nothing here re-implements
the teardown: the code under test is conftest's own, unmodified.

    python3 -m pytest upstream/oolite/tests/gui/test_g10_mid_run_failure_leaves_no_orphan.py -q

FALSIFIABILITY, measured rather than asserted. With ``GameWindow.kill``'s ``self.proc.kill()``
neutered in a scratch copy of conftest.py, this test goes RED and names the surviving pid:
"the game process this run launched (pid 24020) SURVIVED a mid-run test failure". The committed
conftest.py is untouched by this bead.

Needs the desktop: a real window, unlocked and logged in (ADR-0017). It takes tools/gui-lock via
the inherited ``desktop_lock`` fixture and launches nothing of its own.
"""

import time

import pytest

import conftest
from conftest import (
    assert_no_parked_runtime_files,
    assert_no_surviving_game_processes,
    surviving_game_processes,
)

# How long the process gets to actually be gone after the teardown returns. kill() already waits
# 10s on the Popen; this is slack for the OS to drop the entry from the process table.
ORPHAN_GRACE_SECONDS = 10.0

# The shape of the injected failure. A plain AssertionError, because that is what a failing
# assertion in a real GUI test raises, and pytest.fail's Failed (a BaseException) would take a
# different route through the generator's unwind than the everyday case this pins.
INJECTED = "oo-njnw: deliberate mid-run failure with the game UP"


def _game_fixture_generator(gui_runtime, app_dir, desktop_lock, tmp_path):
    """conftest's REAL ``game`` fixture body, as a generator we can throw into.

    ``__pytest_wrapped__.obj`` is the undecorated function pytest itself calls, so this is the
    shared fixture's own code and not a copy of it. Asserted rather than assumed: if a future
    refactor turns ``game`` into something other than a generator fixture, this test must fail
    loudly instead of quietly exercising nothing.
    """
    wrapped = getattr(conftest.game, "__pytest_wrapped__", None)
    assert wrapped is not None, (
        "conftest.game is no longer a pytest fixture wrapper, so this test cannot reach the "
        "shared teardown. Re-point it at the real fixture body rather than reimplementing it."
    )
    generator = wrapped.obj(gui_runtime, app_dir, desktop_lock, tmp_path)
    assert hasattr(generator, "throw"), (
        "conftest.game is not a generator fixture any more; a mid-run failure can no longer be "
        "injected at its yield, and the teardown path this test pins has changed shape"
    )
    return generator


def test_a_mid_run_failure_leaves_no_orphaned_game(gui_runtime, app_dir, desktop_lock, tmp_path):
    """Launch through the shared fixture, die mid-run with the game up, assert THAT pid is gone.

    Every check is scoped to the pid this test launched. A bare "is any oolite.exe running?"
    would be a false positive against a concurrent sibling GUI run on this shared desktop - and
    that false positive is exactly what filed this bead, so this test is not allowed to repeat it.
    """
    generator = _game_fixture_generator(gui_runtime, app_dir, desktop_lock, tmp_path)

    window = next(generator)  # runs GameWindow.start(): a real window, pinned and focused
    pid = window.proc.pid

    # The game must genuinely be UP at the moment of failure, or this test pins nothing: a
    # teardown that "leaves no orphan" after the game already exited is trivially true.
    assert window.proc.poll() is None, (
        f"the game (pid {pid}) had already exited before the failure could be injected, so this "
        "test would assert nothing about a mid-run failure"
    )
    assert surviving_game_processes(pid), (
        f"the OS process table does not show the game this run launched (pid {pid}) as alive, so "
        "the 'no orphan' assertion below could not fail even if the teardown leaked"
    )

    # Inject the failure the bead is about. Throwing into the generator at its yield is what
    # pytest does when a test body raises, so this drives conftest's own
    # ``finally: window.kill()`` down its real unwind path.
    with pytest.raises(AssertionError) as caught:
        generator.throw(AssertionError(INJECTED))
    assert INJECTED in str(caught.value), (
        "the fixture teardown swallowed or replaced the test's failure; a mid-run failure must "
        f"propagate, not be masked. Got: {caught.value!r}"
    )

    # THE PROPERTY. Pid-scoped, asked of the operating system's process table - the only witness
    # that can say "no" - and not of Popen.returncode, which kill() has already stored and which
    # would therefore be true by construction.
    deadline = time.time() + ORPHAN_GRACE_SECONDS
    survivors = surviving_game_processes(pid)
    while survivors and time.time() < deadline:
        time.sleep(0.25)
        survivors = surviving_game_processes(pid)
    assert not survivors, (
        f"the game process this run launched (pid {pid}) SURVIVED a mid-run test failure: "
        + ", ".join(f"{name} (pid {survived})" for survived, name in survivors)
        + f" still alive {ORPHAN_GRACE_SECONDS}s after the shared ``game`` fixture's teardown "
        "returned. A leaked window is parked by _pin_window at exactly (0,0) at the same client "
        "size, so it covers the NEXT test's click point pixel for pixel and silently eats its "
        "clicks - the root cause of bug oo-0p8f, and five agents share this desktop (oo-njnw)."
    )

    # The tier's own shared post-exit helpers, over the same pid and the same window, so this
    # test is held to the tier's baseline rather than to a private one.
    assert_no_surviving_game_processes(pid)
    assert_no_parked_runtime_files(window)


@pytest.mark.offline
def test_the_shared_teardown_kills_on_the_failure_path_and_not_only_on_success():
    """The fixture's kill must be in a ``finally``, reached however the test ended.

    The structural half of the claim above, checkable with no desktop: if a future edit moved
    ``window.kill()`` out of the finalizer and into the body after the yield, the launching test
    would still pass on a green run and leak on every red one - the exact defect this bead was
    filed for. So the SHAPE is pinned too, from the AST rather than from a substring: a comment
    or a docstring naming kill() must not hold this green.
    """
    import ast
    import inspect

    source = inspect.getsource(conftest)
    tree = ast.parse(source)
    fixture = next(
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef) and node.name == "game"
    )
    tries = [node for node in ast.walk(fixture) if isinstance(node, ast.Try)]
    assert tries, "the game fixture no longer wraps its yield in try/finally"

    in_finally = {
        sub.func.attr
        for node in tries
        for stmt in node.finalbody
        for sub in ast.walk(stmt)
        if isinstance(sub, ast.Call) and isinstance(sub.func, ast.Attribute)
    }
    assert "kill" in in_finally, (
        "the game fixture's teardown does not call .kill() from its ``finally`` handler. In the "
        "body after the yield it would be skipped by exactly the failed runs most likely to have "
        "left a game on the desktop, which is the leak bead oo-njnw investigated (and disproved "
        "on both fd501c4 and 602219c precisely because the call is in the finalizer)."
    )

    # And the yield really is inside that try, i.e. a failure in the test body unwinds through it.
    assert any(
        isinstance(sub, ast.Yield)
        for node in tries
        for stmt in node.body
        for sub in ast.walk(stmt)
    ), (
        "the game fixture's ``yield`` is not inside the try whose finally kills the game, so a "
        "test-body failure would not unwind through the teardown at all"
    )
