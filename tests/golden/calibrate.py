"""Measure the frame-hash tolerance instead of guessing it, and write calibration.json.

The tolerance is the whole design risk of this bead. Too loose and the hash passes against any
frame, which makes the gate decoration; too tight and it flakes on legitimate driver noise. Neither
failure is visible by reading the constant, so the constant is not written by hand: this script
measures two populations on THIS host against THIS rasteriser and records them.

  NOISE FLOOR   distance between two renders of the SAME scene, each from its own game process.
                Per-process, deliberately: a floor measured by hashing one PNG twice is zero and
                proves nothing. Every source of run-to-run variation the real gate will face -
                process start, frame timing, the game clock at the moment of capture - is inside
                this measurement.
  SIGNAL        distance between renders of DELIBERATELY DIFFERENT scenes: a translated camera,
                a rotated camera, and an unchanged camera with a ship added in front of it. Three
                kinds, because a tolerance that separates a 400 km jump might still be blind to a
                single added ship, and the bead's DoD names the moved ship specifically.

The threshold then falls out of the data (frame_hash.derive_tolerance) and the margin is reported.
If the populations overlap, that is printed as a finding and the file records it; it is a real
result about this renderer and this scene, not a script failure. That is not hypothetical here: the
first metric tried, a 16x16 dHash, DID overlap on these frames, and this script re-measures it every
run (`rejected_dhash`) so the rejection stays evidence rather than a story in a comment.

Also recorded: exact_match_rate, the fraction of same-scene pairs that are BYTE-identical. If that
were 1.0 the correct instrument would be sha256 and this whole module would be unnecessary. And
grid_sweep, the same two populations under several grid sizes, which is why GRID_SIDE is 64.
"""

import argparse
import hashlib
import itertools
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import frame_capture  # noqa: E402
import frame_hash  # noqa: E402

# Repeats of the reference pose. Three gives three same-scene PAIRS from three launches, which is
# enough to see whether the floor is a constant or a distribution while keeping the run near two
# minutes at the measured ~22 s per warm launch.
SAME_SCENE_REPEATS = 3
DIFFERENT_POSES = ("moved", "turned", "ref-with-ship")
GRID_SWEEP = (16, 32, 64, 128, 240)
# Extra poses captured only to chart how small an object the instrument can still see. They are
# NOT part of the signal population: a range the hash provably cannot resolve would drag the
# tolerance down to the noise floor and make the gate flaky, so the limit is documented instead of
# being absorbed into the threshold.
SENSITIVITY_POSES = tuple("ship-%dm" % r for r in frame_capture.SENSITIVITY_RANGES)


def _sha256(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


# --- the metric that was measured and REJECTED -------------------------------------------------

def _dhash(path, side=16):
    """The 16x16 difference hash this bead tried first. Kept so its failure stays measurable."""
    from PIL import Image

    with Image.open(path) as image:
        small = image.convert("L").resize((side + 1, side), Image.Resampling.BOX)
        try:
            pixels = list(small.get_flattened_data())
        except AttributeError:
            pixels = list(small.getdata())
    bits = 0
    for y in range(side):
        row = pixels[y * (side + 1):(y + 1) * (side + 1)]
        for x in range(side):
            bits = (bits << 1) | (1 if row[x] > row[x + 1] else 0)
    return bits, side * side


def _dhash_distance(a, b):
    (ha, n), (hb, _) = a, b
    return bin(ha ^ hb).count("1") / float(n)


def _populations(refs, others, dist):
    same = [dist(a["png"], b["png"]) for a, b in itertools.combinations(refs, 2)]
    diff = [dist(r["png"], o["png"]) for r in refs for o in others]
    return same, diff


def measure(out_dir, app_dir=None, repeats=SAME_SCENE_REPEATS, different=DIFFERENT_POSES):
    started = time.time()

    refs = []
    for i in range(repeats):
        shot = frame_capture.capture("ref" if i == 0 else "ref-again", out_dir, app_dir)
        shot["label"] = "ref#%d" % i
        refs.append(shot)
        print("[.] %-14s %s  %ss" % (shot["label"], shot["hash"], shot["wall_seconds"]), flush=True)

    others = []
    for pose in different:
        shot = frame_capture.capture(pose, out_dir, app_dir)
        shot["label"] = pose
        others.append(shot)
        print("[.] %-14s %s  %ss" % (shot["label"], shot["hash"], shot["wall_seconds"]), flush=True)

    def grid_dist(pa, pb, side=frame_hash.GRID_SIDE):
        return frame_hash.distance(frame_hash.frame_grid(pa, side),
                                   frame_hash.frame_grid(pb, side))

    same, diff = _populations(refs, others, grid_dist)

    same_pairs, exact = [], 0
    for (a, b), d in zip(itertools.combinations(refs, 2), same):
        identical = _sha256(a["png"]) == _sha256(b["png"])
        exact += 1 if identical else 0
        same_pairs.append({"a": a["label"], "b": b["label"], "distance": d,
                           "bytes_identical": identical})
    diff_pairs = [{"a": r["label"], "b": o["label"], "distance": d}
                  for (r, o), d in zip(((r, o) for r in refs for o in others), diff)]

    # The rejected metric, re-measured on the SAME frames every run.
    d_same, d_diff = _populations(
        refs, others, lambda pa, pb: _dhash_distance(_dhash(pa), _dhash(pb)))
    rejected = {
        "kind": "dhash", "side": 16, "bits": 256,
        "same_scene_distances": d_same, "different_scene_distances": d_diff,
        "noise_floor": max(d_same), "weakest_signal": min(d_diff),
        "separated": max(d_same) < min(d_diff),
        "margin": (((max(d_same) * min(d_diff)) ** 0.5) / max(d_same)
                   if max(d_same) < min(d_diff) else None),
        "why": ("an Oolite system view is ~99% black sky, so most cells of a 16x16 grid are flat "
                "and every brighter-than-the-next-cell bit there is decided by single-digit "
                "luminance noise - roughly half those bits coin-flip between two runs of the same "
                "scene, which puts the noise floor above the weakest real signal."),
    }

    sweep = {}
    for side in GRID_SWEEP:
        s, f = _populations(refs, others, lambda pa, pb, n=side: grid_dist(pa, pb, n))
        sweep[str(side)] = {"noise_floor": max(s), "weakest_signal": min(f),
                            "separated": max(s) < min(f)}

    # How small an object can this instrument still see? Measured, not assumed.
    #
    # The bar is the TOLERANCE, not the raw noise floor. A distance a hair above the floor is not
    # detectable by the gate: the gate passes anything at or below the tolerance, which sits above
    # the floor by design. Scoring against the floor would report a ship as "visible" that the
    # gate would wave straight through.
    provisional_tol = (max(same) * min(diff)) ** 0.5 if max(same) < min(diff) else None
    sensitivity = {}
    for pose in SENSITIVITY_POSES:
        shot = frame_capture.capture(pose, out_dir, app_dir)
        d = min(grid_dist(r["png"], shot["png"]) for r in refs)
        detectable = provisional_tol is not None and d > provisional_tol
        sensitivity[pose] = {"distance": d, "detectable": detectable,
                             "above_noise_floor": d > max(same)}
        print("[.] %-14s %s  %ss  ship distance=%.6f %s"
              % (pose, shot["hash"], shot["wall_seconds"], d,
                 "DETECTABLE" if detectable else "below the tolerance - the gate cannot see it"),
              flush=True)

    cal = {
        "measured_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "rasteriser": dict(frame_hash.REQUIRED_GL_ENV),
        "hash": {"kind": "l1-luminance-grid", "side": frame_hash.GRID_SIDE,
                 "cells": frame_hash.GRID_CELLS},
        "surface": "960x720 windowed (SDL; the offscreen driver is unusable here - no EGL)",
        "same_scene_distances": same,
        "different_scene_distances": diff,
        "exact_match_rate": (exact / len(same_pairs)) if same_pairs else None,
        "rejected_dhash": rejected,
        "grid_sweep": sweep,
        "sensitivity": sensitivity,
        "ship_range_m": frame_capture.SHIP_RANGE_M,
        "samples": {
            "same_scene_pairs": same_pairs,
            "different_scene_pairs": diff_pairs,
            "frames": [{k: s[k] for k in ("label", "pose", "hash", "wall_seconds")}
                       for s in refs + others],
        },
        "measure_seconds": round(time.time() - started, 1),
    }

    floor, signal = max(same), min(diff)
    cal["noise_floor"] = floor
    cal["weakest_signal"] = signal
    cal["separated"] = floor < signal
    if cal["separated"]:
        cal["tolerance"] = frame_hash.derive_tolerance(cal)
        cal["margin"] = frame_hash.margin(cal)
    else:
        cal["tolerance"] = None
        cal["margin"] = None
        cal["finding"] = (
            "POPULATIONS OVERLAP: the worst same-scene distance (%.6f) is not below the best "
            "different-scene distance (%.6f), so no threshold separates them on this renderer "
            "and a frame hash cannot discriminate these scenes." % (floor, signal)
        )
    return cal


def report(cal):
    print()
    print("same-scene distances     : %s" % ["%.6f" % d for d in cal["same_scene_distances"]])
    for p in cal["samples"]["different_scene_pairs"]:
        print("   %-8s vs %-14s %.6f" % (p["a"], p["b"], p["distance"]))
    print("noise floor (worst same)  : %.6f" % cal["noise_floor"])
    print("weakest signal (best diff): %.6f" % cal["weakest_signal"])
    print("byte-identical same-scene pairs: %.0f%%  (sha256 would be %s)"
          % (100 * (cal["exact_match_rate"] or 0),
             "sufficient" if cal["exact_match_rate"] == 1.0 else "USELESS here"))
    r = cal["rejected_dhash"]
    print("rejected dhash            : floor %.6f vs signal %.6f -> margin %.2fx (this metric "
          "%.2fx)" % (r["noise_floor"], r["weakest_signal"], r["margin"] or 0.0,
                      cal["margin"] or 0.0))
    print("sensitivity (ship ahead)  : %s"
          % ", ".join("%s %.6f%s" % (k, v["distance"], "" if v["detectable"] else " (BLIND)")
                      for k, v in sorted(cal["sensitivity"].items())))
    if cal["separated"]:
        print("TOLERANCE = %.6f   margin = %.2fx the noise floor, and %.2fx below the signal"
              % (cal["tolerance"], cal["margin"], cal["weakest_signal"] / cal["tolerance"]))
    else:
        print("!! %s" % cal["finding"])


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/calibrate.py")
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--app-dir", default="")
    parser.add_argument("--repeats", type=int, default=SAME_SCENE_REPEATS)
    parser.add_argument("--write", action="store_true",
                        help="overwrite tests/golden/calibration.json with the measurement")
    args = parser.parse_args(argv)
    cal = measure(args.out_dir, args.app_dir or None, args.repeats)
    report(cal)
    if args.write:
        with open(frame_hash.CALIBRATION_PATH, "w", encoding="utf-8") as handle:
            json.dump(cal, handle, indent=2, sort_keys=True)
            handle.write("\n")
        print("wrote %s" % frame_hash.CALIBRATION_PATH)
    return 0 if cal["separated"] else 2


if __name__ == "__main__":
    sys.exit(main())
