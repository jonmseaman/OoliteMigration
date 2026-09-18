"""A wrong-sized frame.grid must be REFUSED BY NAME, never crash the harness.

WHY THIS FILE EXISTS (bead oo-s6qs): every scenario's `_read_grid()` refuses a grid file whose
length is not `frame_hash.GRID_CELLS`. That refusal formatted the expected shape by hand and
spelled the side-length attribute `GRID_SIZE`, which frame_hash has never defined - the name is
`GRID_SIDE`. Because the typo sat INSIDE the error path it was invisible on every green run: it
only fired when the check was doing its job, turning a deliberate, named rejection into an
AttributeError traceback. The template was copied before anyone hit it, so four call sites across
three scenarios were all wrong the same way.

The structural fix is `frame_hash.wrong_grid_size_message()`: the sentence is formatted in one
place, so a call site has no attribute name left to mistype. These tests are the guard that the
fix stays fixed - they are NEGATIVE CONTROLS, i.e. they exercise the failure path on purpose,
which is exactly the path a green run never reaches.

Offline: no game launch, no goldens, nothing but a temp file of the wrong length.
"""

import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import frame_hash  # noqa: E402

SCENARIO_MODULES = ["trumbles_load", "cloaking_load", "nova_load"]

# Deliberately wrong lengths: far too short, nearly right (off by one), and far too long. The
# off-by-one matters most - a truncated capture is the realistic corruption, and it is the case a
# sloppy `len(blob) < N` check would wave through.
WRONG_SIZES = [0, 1, 100, frame_hash.GRID_CELLS - 1, frame_hash.GRID_CELLS + 1]


def _load(name):
    module = pytest.importorskip(name)
    if not hasattr(module, "_read_grid"):
        pytest.skip("%s has no _read_grid()" % name)
    return module


def _write(tmp_path, nbytes):
    path = os.path.join(str(tmp_path), "frame.grid")
    with open(path, "wb") as handle:
        handle.write(b"\x00" * nbytes)
    return path


def test_the_attribute_the_refusal_needs_is_named_grid_side():
    """The exact confusion that caused the bug, asserted directly."""
    assert frame_hash.GRID_SIDE == 64
    assert frame_hash.GRID_CELLS == 64 * 64
    assert not hasattr(frame_hash, "GRID_SIZE"), (
        "frame_hash grew a GRID_SIZE attribute; the refusal path must still use GRID_SIDE")


def test_shared_refusal_message_names_both_sizes():
    message = frame_hash.wrong_grid_size_message("/tmp/frame.grid", 100)
    assert "/tmp/frame.grid" in message
    assert "100" in message            # what was actually read
    assert "4096" in message           # how many bytes were required
    assert "64x64" in message          # the shape a reader can act on


@pytest.mark.parametrize("module_name", SCENARIO_MODULES)
@pytest.mark.parametrize("nbytes", WRONG_SIZES)
def test_a_wrong_sized_grid_is_refused_by_name_not_by_crash(tmp_path, module_name, nbytes):
    module = _load(module_name)
    path = _write(tmp_path, nbytes)

    with pytest.raises(module.ScenarioError) as caught:
        module._read_grid(path)

    message = str(caught.value)
    assert str(nbytes) in message, (
        "refusal must name the actual byte count, got: %s" % message)
    assert str(frame_hash.GRID_CELLS) in message, (
        "refusal must name the required byte count, got: %s" % message)
    assert "64x64" in message, (
        "refusal must name the expected 64x64 shape, got: %s" % message)


@pytest.mark.parametrize("module_name", SCENARIO_MODULES)
def test_the_refusal_path_raises_no_attributeerror(tmp_path, module_name):
    """The regression itself: an AttributeError here means the typo is back.

    ScenarioError subclasses Exception, not AttributeError, so catching AttributeError separately
    distinguishes 'refused as designed' from 'crashed while trying to refuse'.
    """
    module = _load(module_name)
    path = _write(tmp_path, 100)
    try:
        module._read_grid(path)
    except AttributeError as exc:  # pragma: no cover - only reached when the bug returns
        pytest.fail("refusal path crashed instead of refusing: %s" % exc)
    except module.ScenarioError:
        pass
    else:
        pytest.fail("a 100-byte grid was accepted as a %d-byte grid" % frame_hash.GRID_CELLS)


@pytest.mark.parametrize("module_name", SCENARIO_MODULES)
def test_a_correctly_sized_grid_is_still_accepted(tmp_path, module_name):
    """Positive control: the guard rejects the wrong size, and ONLY the wrong size."""
    module = _load(module_name)
    path = _write(tmp_path, frame_hash.GRID_CELLS)
    assert len(module._read_grid(path)) == frame_hash.GRID_CELLS
