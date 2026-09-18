"""Perceptual frame hashes with a MEASURED tolerance.

A fuzzy image hash is only a test if the tolerance separates two measured populations:

* the NOISE FLOOR - the distance between two renders of the SAME scene, which is not zero
  because llvmpipe is only deterministic given identical inputs and a live game never has
  bit-identical inputs twice (frame timing, the game clock, the ship's own float integration);
* the SIGNAL - the distance between renders of DELIBERATELY DIFFERENT scenes.

A threshold picked out of the air is decoration: too loose and every frame passes, too tight and
legitimate driver noise flakes the gate. So the constant in this module is NOT written here. It is
DERIVED at import time from `calibration.json`, which records real measurements taken on this host
by `calibrate.py`, and `test_frame_hash.py` asserts the derivation agrees with the recorded data
(the derivation keeps the constant honest when the renderer changes; the recorded populations keep
the derivation honest).

THE HASH is a 64x64 average-pooled LUMINANCE GRID - 4096 bytes, compared with mean absolute
difference scaled to 0..1. Coarse enough that sub-pixel rasteriser jitter averages out, fine
enough to see an object a few hundred pixels across.

WHY NOT dHash. The obvious choice - a 16x16 difference hash compared by Hamming distance - was
implemented first and MEASURED. It fails on this content, and the measurement is recorded in
calibration.json under `rejected_dhash`:

    same-scene distances      0.191, 0.219, 0.230   (of 256 bits)
    different-scene distances 0.184 .. 0.453

The populations OVERLAP - the best different-scene pair scored BELOW the worst same-scene pair, so
no threshold exists. The cause is the content, not the renderer: an Oolite system view is ~99%
black sky, so most of a 16x16 grid is flat, every "is this cell brighter than its neighbour"
comparison there is decided by single-digit luminance noise, and half those bits are a coin flip
between two runs of the same scene. dHash's virtue - invariance to overall brightness - is
worthless here and its cost is fatal. A metric that keeps MAGNITUDE rather than reducing to a sign
does not have that problem: the same frames, under the L1 grid below, give a floor of 0.0024
against a weakest signal of 0.0076.

WHY NOT A CRYPTOGRAPHIC HASH. Measured on this host: 0 of 3 same-scene pairs were byte-identical
(calibration.json -> exact_match_rate), so sha256 of the PNG fails every time. That is the whole
reason this bead exists.
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
CALIBRATION_PATH = os.path.join(HERE, "calibration.json")

# Side of the average-pooled luminance grid. 64 measured indistinguishable from 128 and 240 on
# both populations (calibration.json -> grid_sweep), so the smallest of those is used.
GRID_SIDE = 64
GRID_CELLS = GRID_SIDE * GRID_SIDE

# The rasteriser this tolerance was measured against. Pinned, and asserted at capture time:
# a tolerance measured on llvmpipe says nothing about a hardware driver, and a frame hash that
# silently changed rasteriser would be comparing two different renderers' noise floors.
REQUIRED_GL_ENV = {"LIBGL_ALWAYS_SOFTWARE": "1", "GALLIUM_DRIVER": "llvmpipe"}


class FrameHashError(RuntimeError):
    pass


def wrong_grid_size_message(path, actual_bytes):
    """Return the refusal text for a grid file that is not GRID_CELLS bytes.

    WHY THIS LIVES HERE AND NOT IN EACH SCENARIO: every scenario's _read_grid() used to format
    this sentence by hand, and every copy referenced a GRID_SIZE attribute that has never
    existed - the attribute is GRID_SIDE. The typo sits INSIDE the error path, so it is invisible
    on every green run and only fires when the check is doing its job: a truncated or corrupt
    frame.grid crashed with AttributeError instead of being refused by name. The template was
    copied into four call sites across three scenarios before anyone hit it. Formatting the
    message in ONE place means the next scenario copied from the template cannot re-introduce it:
    there is no attribute name left at the call site to mistype.

    Callers raise their OWN scenario error type with this text, so a scenario failure still
    surfaces as that scenario's error rather than a frame_hash one.
    """
    return ("%s is %d bytes, not the %d-byte %dx%d luminance grid; any comparison against it "
            "would be meaningless"
            % (path, actual_bytes, GRID_CELLS, GRID_SIDE, GRID_SIDE))


def _load_calibration():
    """Read the recorded measurements. NEVER raises: import must not depend on the data.

    An earlier version computed the tolerance at module scope and raised when the populations
    overlapped. That made `import frame_hash` throw, which broke every consumer - including
    calibrate.py, the very tool whose job is to REPLACE the overlapping data. A module that cannot
    be imported while the data is bad cannot be used to fix the data. Import now only loads;
    whether a usable threshold exists is a VALUE the caller checks (`separated()`), and only the
    functions that genuinely need a number raise.
    """
    try:
        with open(CALIBRATION_PATH, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


CALIBRATION = _load_calibration()


def _require_calibration(calibration=None):
    cal = calibration if calibration is not None else CALIBRATION
    if not cal:
        raise FrameHashError(
            "no usable calibration at %s; the tolerance is measured, not guessed - run "
            "tests/golden/calibrate.py --write" % CALIBRATION_PATH
        )
    return cal


def separated(calibration=None):
    """Do the measured populations admit a threshold at all? A value, not an exception."""
    cal = calibration if calibration is not None else CALIBRATION
    if not cal or not cal.get("same_scene_distances") or not cal.get("different_scene_distances"):
        return False
    return max(cal["same_scene_distances"]) < min(cal["different_scene_distances"])


def derive_tolerance(calibration=None):
    """The tolerance, computed from the measured populations. Never a literal.

    Rule: sit at the geometric mean of the worst same-scene distance and the best
    different-scene distance. The geometric mean rather than the arithmetic one because these are
    ratios spanning an order of magnitude, and it places the threshold at an equal MULTIPLICATIVE
    margin from each population - so the reported margin is the same number in both directions,
    and a tolerance derived from a floor of 0.0024 against a signal of 0.030 is not dragged up
    next to the signal simply because the signal is large.

    Raises if the two populations overlap: there is then no threshold, and pretending otherwise
    is precisely the decoration this bead exists to avoid.
    """
    cal = _require_calibration(calibration)
    floor = max(cal["same_scene_distances"])
    signal = min(cal["different_scene_distances"])
    if floor >= signal:
        raise FrameHashError(
            "the measured populations OVERLAP: worst same-scene distance %.6f >= best "
            "different-scene distance %.6f, so no threshold separates them and a frame hash "
            "cannot discriminate these scenes on this renderer." % (floor, signal)
        )
    return (floor * signal) ** 0.5


def margin(calibration=None):
    """How many times the worst same-scene distance the tolerance sits at.

    Equal to how many times below the best different-scene distance it sits, by construction of
    the geometric mean - which is the point of using it.
    """
    cal = _require_calibration(calibration)
    return derive_tolerance(cal) / max(cal["same_scene_distances"])


def tolerance():
    """The threshold a gate should use, computed on demand.

    A FUNCTION, not a module-scope constant: computing it at import made `import frame_hash` raise
    whenever the recorded populations overlapped, which broke calibrate.py - the one tool able to
    replace that data. Callers that only want to know whether a threshold exists ask `separated()`.
    """
    return derive_tolerance()


# --- the hash ----------------------------------------------------------------------------------

def frame_grid(path, side=GRID_SIDE):
    """Average-pooled luminance grid of a rendered frame: `side*side` bytes.

    BOX resampling (a plain area average), not LANCZOS: a windowed-sinc filter rings, and ringing
    turns a one-pixel difference into a multi-cell difference, inflating the noise floor for no
    gain in discrimination.
    """
    from PIL import Image

    with Image.open(path) as image:
        small = image.convert("L").resize((side, side), Image.Resampling.BOX)
        try:
            return bytes(small.get_flattened_data())
        except AttributeError:  # Pillow < 12
            return bytes(small.getdata())


def frame_hash(path, side=GRID_SIDE):
    """The frame's perceptual hash: its luminance grid. `hex_digest` renders it printable."""
    return frame_grid(path, side)


def distance(a, b):
    """Mean absolute luminance difference, scaled to 0.0 (identical) .. 1.0 (black vs white).

    Scaled rather than summed so the number means the same thing if GRID_SIDE ever changes, and
    so a tolerance reads as "a fraction of full scale" rather than as an unanchored integer.
    """
    if len(a) != len(b):
        raise FrameHashError("grid sizes differ: %d vs %d" % (len(a), len(b)))
    return sum(abs(x - y) for x, y in zip(a, b)) / (len(a) * 255.0)


def hex_digest(value, head=32):
    """A short, stable, human-comparable fingerprint of a grid, for logs and failure messages."""
    import hashlib

    return hashlib.sha256(bytes(value)).hexdigest()[:head]


# --- the comparison a gate actually makes --------------------------------------------------------

def compare(path_a, path_b, tol=None):
    """Compare two frames. Returns a dict; never raises on a mismatch - the caller decides."""
    tol = tolerance() if tol is None else tol
    ga, gb = frame_grid(path_a), frame_grid(path_b)
    d = distance(ga, gb)
    return {
        "a": path_a, "b": path_b,
        "hash_a": hex_digest(ga), "hash_b": hex_digest(gb),
        "distance": d, "tolerance": tol, "within": d <= tol,
        "ratio": (d / tol) if tol else float("inf"),
    }


def assert_within(path_a, path_b, tol=None, what="frames"):
    """The green direction: two renders of the same scene."""
    result = compare(path_a, path_b, tol)
    if not result["within"]:
        raise FrameHashError(
            "FRAME HASH MISMATCH: %s differ by %.6f, which EXCEEDS the measured tolerance %.6f "
            "(%.2fx over). %s=%s  %s=%s. Observed: the two frames are not the same scene within "
            "the noise floor measured on this renderer. Candidate causes, in the order worth "
            "checking: the camera pose was not applied identically; the scene contains something "
            "that moved between the two captures; the rasteriser is not llvmpipe (%s); a genuine "
            "rendering regression."
            % (what, result["distance"], result["tolerance"], result["ratio"],
               os.path.basename(path_a), result["hash_a"],
               os.path.basename(path_b), result["hash_b"],
               ", ".join("%s=%s" % kv for kv in sorted(REQUIRED_GL_ENV.items())))
        )
    return result


def assert_beyond(path_a, path_b, tol=None, what="frames"):
    """The red direction: a deliberately different scene MUST clear the tolerance.

    Without this half the gate is decoration - a tolerance loose enough to pass anything passes
    the same-scene check for ever.
    """
    result = compare(path_a, path_b, tol)
    if result["within"]:
        raise FrameHashError(
            "FRAME HASH NOT DISCRIMINATING: %s differ by only %.6f, which is WITHIN the tolerance "
            "%.6f (%.2fx of it) even though the scenes are deliberately different. %s=%s  %s=%s. "
            "Observed: the hash cannot tell these two scenes apart, so any gate built on it would "
            "pass a wrong frame. Candidate causes: the scene change was not applied; the change is "
            "too small to survive the %dx%d average pooling; the tolerance is too loose for this "
            "scene."
            % (what, result["distance"], result["tolerance"], result["ratio"],
               os.path.basename(path_a), result["hash_a"],
               os.path.basename(path_b), result["hash_b"], GRID_SIDE, GRID_SIDE)
        )
    return result
