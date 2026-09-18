"""The acceptance gate's checks, one per subcommand.

accept.sh runs each stored acceptance line in its OWN `bash -o pipefail -c`, so every line must be
a single line. Embedding multi-line Python in a shell line is how that rule gets broken silently,
so the logic lives here and the gate calls subcommands. It is also directly runnable by a human,
which a `python -c` one-liner is not.

Each check prints what it OBSERVED, not just "ok": a gate line whose output is a bare exit code is
indistinguishable from a line that never ran (rc=127 looks identical to rc=0 in a summary table).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import frame_hash  # noqa: E402

SAMPLES = os.path.join(HERE, "samples")


def _s(name):
    return os.path.join(SAMPLES, name)


def import_is_safe():
    """The module must import on ANY data, including data with no usable threshold."""
    import ast
    import inspect

    tree = ast.parse(inspect.getsource(frame_hash))
    for node in tree.body:
        if isinstance(node, (ast.Assign, ast.AnnAssign)):
            call = getattr(node, "value", None)
            if isinstance(call, ast.Call) and isinstance(call.func, ast.Name):
                assert call.func.id not in ("derive_tolerance", "margin", "tolerance"), (
                    "frame_hash.py calls %s() at module scope; on overlapping measurements the "
                    "import itself raises and every consumer breaks, calibrate.py included"
                    % call.func.id
                )
    assert frame_hash.separated({"same_scene_distances": [0.03],
                                 "different_scene_distances": [0.02]}) is False
    assert frame_hash.separated({"same_scene_distances": [0.001],
                                 "different_scene_distances": [0.01]}) is True
    print("import is data-independent: overlap is a value (separated()), not an import-time raise")


def calibration_is_real():
    cal = frame_hash.CALIBRATION
    assert not cal.get("_provisional"), "calibration.json is still the placeholder"
    assert len(cal["same_scene_distances"]) >= 3, "too few same-scene measurements"
    assert len(cal["different_scene_distances"]) >= 3, "too few different-scene measurements"
    assert all(d > 0 for d in cal["same_scene_distances"]), (
        "a same-scene distance of exactly 0 means a frame was compared with itself; the noise "
        "floor must come from two independent game processes"
    )
    assert cal["rasteriser"] == frame_hash.REQUIRED_GL_ENV, (
        "calibration measured against %r, module requires %r" % (cal["rasteriser"],
                                                                 frame_hash.REQUIRED_GL_ENV)
    )
    assert cal["exact_match_rate"] < 1.0, (
        "same-scene renders are byte-identical; sha256 would be the right instrument and a "
        "tolerance would be unnecessary"
    )
    print("calibration: %d same-scene and %d different-scene measurements, %.0f%% byte-identical"
          % (len(cal["same_scene_distances"]), len(cal["different_scene_distances"]),
             100 * cal["exact_match_rate"]))


def tolerance_is_derived():
    cal = frame_hash.CALIBRATION
    floor, signal = max(cal["same_scene_distances"]), min(cal["different_scene_distances"])
    assert floor < frame_hash.tolerance() < signal, (
        "tolerance %.6f is not strictly between the measured noise floor %.6f and the weakest "
        "measured signal %.6f" % (frame_hash.tolerance(), floor, signal)
    )
    assert abs(frame_hash.tolerance() - (floor * signal) ** 0.5) < 1e-12, (
        "tolerance is not the geometric mean of the measured populations - it was written down "
        "rather than derived"
    )
    assert frame_hash.margin() >= 1.5, (
        "margin is only %.2fx the noise floor; the populations nearly touch and the gate would "
        "flake" % frame_hash.margin()
    )
    print("TOLERANCE=%.6f  floor=%.6f  signal=%.6f  margin=%.2fx in each direction"
          % (frame_hash.tolerance(), floor, signal, frame_hash.margin()))


def overlap_is_refused():
    """A negative result must be reachable, or 'the populations separated' is not a finding."""
    try:
        frame_hash.derive_tolerance({"same_scene_distances": [0.30],
                                     "different_scene_distances": [0.20]})
    except frame_hash.FrameHashError as exc:
        assert "OVERLAP" in str(exc), exc
        print("overlapping populations are refused: %s" % str(exc).split(".")[0])
        return
    raise AssertionError(
        "derive_tolerance ACCEPTED an overlapping pair; it would invent a threshold where none "
        "exists and the gate would be decoration"
    )


def positive_control():
    """Two renders of the SAME scene pass, so a green run is not vacuous."""
    r = frame_hash.assert_within(_s("ref-a.png"), _s("ref-b.png"),
                                 what="two independent renders of the reference pose")
    print("POSITIVE CONTROL: same scene, distance=%.6f = %.2fx of the tolerance %.6f -> WITHIN"
          % (r["distance"], r["ratio"], r["tolerance"]))


def discriminates():
    """Every deliberately different scene must clear the tolerance."""
    for name, why in (("moved.png", "camera translated 400 km"),
                      ("turned.png", "camera yawed 90 degrees in place"),
                      ("with-ship.png", "same camera, a trader parked ahead")):
        r = frame_hash.assert_beyond(_s("ref-a.png"), _s(name), what=why)
        print("DISCRIMINATES %-14s distance=%.6f = %.2fx the tolerance  (%s)"
              % (name, r["distance"], r["ratio"], why))


def red_proof():
    """Feed the comparator a frame from a DIFFERENT CAMERA POSITION and require it to fail."""
    try:
        frame_hash.assert_within(_s("ref-a.png"), _s("moved.png"))
    except frame_hash.FrameHashError as exc:
        text = str(exc)
        for needle in ("FRAME HASH MISMATCH", "EXCEEDS the measured tolerance", "llvmpipe"):
            assert needle in text, "failure message does not name %r: %s" % (needle, text)
        print("RED PROOF: %s" % text.split(". ")[0])
        return
    raise AssertionError(
        "assert_within PASSED a frame taken from a different camera position. The gate cannot "
        "fail, so it proves nothing about any frame it ever accepts."
    )


def online_sanity():
    """ONE end-to-end check: two fresh renders of the fixed reference pose agree.

    Deliberately two launches, not the full online suite's five. accept.sh replays in a fresh
    detached checkout where a launch costs 26-31 s and the shared app dir is contended by sibling
    workers, so a gate needing five of them is fragile. The offline lines already pin the metric,
    the derivation and both comparison directions against the committed calibration and sample
    frames; this line exists to prove the whole pipeline - launch, pose, render, hash - still runs.
    """
    import tempfile

    import frame_capture

    out = tempfile.mkdtemp(prefix="ae9-gate-")
    a = frame_capture.capture("ref", out)
    b = frame_capture.capture("ref-again", out)
    for shot in (a, b):
        assert shot["wall_seconds"] >= 5.0, (
            "%s completed in %ss, far below the measured cost of launching this game (26-31 s). "
            "The capture probably attached to an already-running process rather than the one it "
            "spawned, so this line proved nothing." % (shot["pose"], shot["wall_seconds"])
        )
        assert shot["position"] == [0.0, 0.0, 0.0], (
            "%s rendered from %r, not the declared reference pose" % (shot["pose"],
                                                                     shot["position"])
        )
    r = frame_hash.assert_within(a["png"], b["png"], what="two live renders of the reference pose")
    assert r["distance"] > 0, (
        "two independent renders measured EXACTLY identical, which never happened in calibration; "
        "suspect both captures returned the same file"
    )
    print("ONLINE: two live renders of the fixed reference pose (%ss, %ss) differ by %.6f, "
          "WITHIN the tolerance %.6f (%.2fx of it)"
          % (a["wall_seconds"], b["wall_seconds"], r["distance"], r["tolerance"], r["ratio"]))


COMMANDS = {
    "import-is-safe": import_is_safe,
    "calibration-is-real": calibration_is_real,
    "tolerance-is-derived": tolerance_is_derived,
    "overlap-is-refused": overlap_is_refused,
    "positive-control": positive_control,
    "discriminates": discriminates,
    "red-proof": red_proof,
    "online-sanity": online_sanity,
}


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) != 1 or argv[0] not in COMMANDS:
        print("usage: gate_checks.py {%s}" % "|".join(sorted(COMMANDS)), file=sys.stderr)
        return 2
    try:
        COMMANDS[argv[0]]()
    except AssertionError as exc:
        print("[!] %s: %s" % (argv[0], exc), file=sys.stderr)
        return 1
    except frame_hash.FrameHashError as exc:
        print("[!] %s: %s" % (argv[0], exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
