"""Offline evidence checker for golden 020 (hud-render-modes).

WHAT THIS FILE IS FOR
=====================
`hud_render_modes.py --check-evidence` re-applies the HARNESS's own `assert_ran` to a stored
dump. That is necessary and not sufficient: `assert_ran` is the code that WROTE the dump, so it
and the dump can drift together, and a weakened clause is invisible to a gate whose only judge is
the thing being judged (bead oo-jor: "mutate the checker, not only the data"). This file is an
INDEPENDENT reader. It does not import the harness. It re-derives every claim it can from the
dump's own numbers and from the stored per-mode grids, and it refuses when the dump does not
carry what the claim needs.

THE THREE CLASSES OF CHECK HERE
===============================
1. STRUCTURAL - the evidence block exists, carries every required field, and the modes it names
   are the modes the spec declares. A dump with no evidence compares equal to any other
   evidence-free dump.
2. RE-DERIVED - the claimed separation is recomputed from the `between_mode_distances` list
   rather than read out of `best_between_mode_distance`, and the separation ratio is recomputed
   from its two operands. An edited summary that disagrees with its own detail fails BY NAME.
3. RE-MEASURED - when the per-mode grids are on disk beside the dump, the between-mode distances
   are recomputed FROM THE PIXELS. This is the only check in the file that a doctored dump cannot
   satisfy at all, because the grids are separate files.

WHY A REFUSAL IS NOT A PASS
===========================
rc=2 (REFUSED) means "I could not perform the comparison soundly" and is never "they match"
(the repo-wide rc convention, bead oo-jor). A checker that returns 0 when it could not actually
check is the most dangerous failure mode a gate can have, so every path that cannot complete
exits 2 with the reason.
"""

import argparse
import hashlib
import itertools
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "020-hud-render-modes"

# Guarded location first, staged location second - the identical resolution order every other
# scenario uses, so this file keeps working unchanged after Jon's `git mv` (bead oo-8ij).
SPEC_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "spec.json"),
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)

GUI_SCREEN_MAIN = "GUI_SCREEN_MAIN"
GRID_CELLS = 4096

REQUIRED_FIELDS = (
    "scenario", "seed", "ticks", "system_id", "launched_from_dock", "in_flight", "gui_screens",
    "modes", "primary_mode", "hud_readbacks", "hud_readback_ok", "hidden_readbacks",
    "hud_refusal_requested", "hud_refusal_before", "hud_refusal_after",
    "hud_refused_unknown_plist", "pose_applied", "pose_readbacks", "frame_bytes",
    "frame_liveness", "mode_grid_digests", "distinct_mode_grid_digests",
    "between_mode_distances", "best_between_mode_distance", "best_between_mode_pair",
    "within_mode_pair", "worst_within_mode_distance", "within_mode_tolerance",
    "separation_ratio", "shared_calibration_tolerance", "tick_budget_met",
    "clock_frozen_across_dump", "ships_in_frame", "ships_at_each_capture",
    "world_reached_fixed_point",
)


class CheckFailed(RuntimeError):
    """A real defect in the stored evidence (rc=1)."""


class CheckRefused(RuntimeError):
    """The comparison could not be made soundly; no verdict (rc=2)."""


def _first_existing(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise CheckRefused("no %s found; searched: %s" % (what, ", ".join(candidates)))


def load_spec(path=None):
    with open(path or _first_existing(SPEC_CANDIDATES, "spec.json"), encoding="utf-8") as handle:
        return json.load(handle)


def _distance(a, b):
    if len(a) != len(b):
        raise CheckRefused("grid sizes differ: %d vs %d" % (len(a), len(b)))
    return sum(abs(x - y) for x, y in zip(a, b)) / (len(a) * 255.0)


def _read_grid(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    if len(blob) != GRID_CELLS:
        raise CheckRefused("%s is %d bytes, not the %d-byte 64x64 luminance grid; any comparison "
                           "against it would be meaningless" % (path, len(blob), GRID_CELLS))
    return blob


# --- 1. structural ------------------------------------------------------------------------------


def check_structure(evidence, spec):
    missing = [k for k in REQUIRED_FIELDS if k not in evidence]
    if missing:
        raise CheckRefused(
            "the evidence block is missing %s; a checker cannot judge a claim the dump does not "
            "make, and passing here would be a vacuous green" % missing)
    if evidence["scenario"] != SCENARIO:
        raise CheckRefused("this dump is for scenario %r, not %r"
                           % (evidence["scenario"], SCENARIO))

    declared = [entry["mode"] for entry in spec["hud_modes"]]
    if evidence["modes"] != declared:
        raise CheckFailed(
            "DEFECT [modes]: the dump records modes %r; spec.json declares %r. A scenario that "
            "silently drops a mode has fewer populations to separate and the margin it reports is "
            "not the margin the spec asked for." % (evidence["modes"], declared))
    if len(declared) < 3:
        raise CheckFailed(
            "DEFECT [modes]: %d mode(s) declared. With fewer than three there is no BETWEEN-mode "
            "population worth the name: one pair cannot distinguish 'the modes differ' from 'this "
            "particular pair differs'." % len(declared))
    if evidence["primary_mode"] != spec["primary_mode"]:
        raise CheckFailed(
            "DEFECT [primary_mode]: the dump blessed mode %r, the spec names %r - frame.grid and "
            "the mode it is supposed to be have drifted apart."
            % (evidence["primary_mode"], spec["primary_mode"]))


def check_ran_in_flight(evidence, spec):
    """The HUD is drawn over the 3-D view only. A docked run renders the same station screen
    three times and the whole differential collapses - and it would do so SILENTLY."""
    if evidence["launched_from_dock"] is not True:
        raise CheckFailed("DEFECT [in_flight]: the run never launched; it did not fly")
    if evidence["in_flight"] is not True:
        raise CheckFailed(
            "DEFECT [in_flight]: in_flight is %r. Every capture must be undocked at %s."
            % (evidence["in_flight"], GUI_SCREEN_MAIN))
    screens = evidence["gui_screens"]
    if screens != [GUI_SCREEN_MAIN] * len(evidence["modes"]):
        raise CheckFailed(
            "DEFECT [in_flight]: the captures were taken on screens %r, not %r at every one. On a "
            "station or chart screen all three modes render the same picture."
            % (screens, GUI_SCREEN_MAIN))
    per_capture = evidence["ships_at_each_capture"]
    if len(per_capture) != len(evidence["modes"]):
        raise CheckRefused(
            "ships_at_each_capture records %d entry/entries for %d mode(s); the per-capture "
            "counts cannot be judged against captures they do not cover"
            % (len(per_capture), len(evidence["modes"])))
    if per_capture != [0] * len(evidence["modes"]):
        raise CheckFailed(
            "DEFECT [quiet_world]: non-player ships were in frame at captures %r. Ambient traffic "
            "drifting through frame is a real difference between two captures of the SAME mode "
            "and would inflate the within-mode population, loosening the very tolerance this "
            "scenario measures. This is asserted PER CAPTURE rather than once at the end, because "
            "a run's final census cannot see traffic that was present for one capture and gone by "
            "the next - measured: a sweep found 3 ships 1.5 game-seconds after a clear that "
            "removed 4." % (per_capture,))
    if evidence["world_reached_fixed_point"] is not True:
        raise CheckFailed("DEFECT [quiet_world]: the world never reached a clean clear round")
    if evidence["tick_budget_met"] is not True:
        raise CheckFailed(
            "DEFECT [tick_budget]: the tick budget was not met. tick_budget_met is measured on "
            "clock.absoluteSeconds INSIDE the game, which only advances while the run loop steps, "
            "so it is the one field a photograph of tick 0 cannot satisfy.")
    if evidence["clock_frozen_across_dump"] is not True:
        raise CheckFailed(
            "DEFECT [frozen_dump]: the game clock advanced across the dump; the world is not "
            "frozen and the dump is a stopwatch reading")


def check_modes_applied(evidence, spec):
    """An unapplied HUD write is SILENT and yields renders of the same scene."""
    if evidence["hud_readback_ok"] is not True:
        raise CheckFailed(
            "DEFECT [hud_readback]: player.ship.hud did not read back the requested plist for "
            "every mode (%r). -switchHudTo: returns NO and merely DEFERS when the HUD is "
            "mid-render (PlayerEntity.m:4530-4535) and the JS setter discards that return, so an "
            "unapplied mode is silent - and renders of an unapplied mode are renders of the SAME "
            "scene, which pass a within-mode check while measuring nothing."
            % (evidence["hud_readbacks"],))
    want_plists = sorted({entry["hud"] for entry in spec["hud_modes"]})
    got_plists = sorted(set(evidence["hud_readbacks"].values()))
    if got_plists != want_plists:
        raise CheckFailed(
            "DEFECT [hud_readback]: the modes read back plists %r; the spec declares %r"
            % (got_plists, want_plists))
    want_hidden = [bool(entry["hidden"]) for entry in spec["hud_modes"]]
    if evidence["hidden_readbacks"] != want_hidden:
        raise CheckFailed(
            "DEFECT [hud_readback]: hudHidden read back %r across the modes; the spec declares %r"
            % (evidence["hidden_readbacks"], want_hidden))
    for mode, entry in zip(evidence["modes"], spec["hud_modes"]):
        got = evidence["hud_readbacks"].get(mode)
        if got != entry["hud"]:
            raise CheckFailed(
                "DEFECT [hud_readback]: mode %r read back %r but the spec pins %r; the per-mode "
                "mapping has drifted even though the SET of plists still matches - which is "
                "exactly what a swapped pair of modes looks like."
                % (mode, got, entry["hud"]))
    if evidence["pose_applied"] is not True:
        raise CheckFailed(
            "DEFECT [pose_applied]: the camera pose was not verified before every capture (%r). A "
            "drifting camera is a real difference between two frames and is indistinguishable "
            "from a HUD difference." % (evidence["pose_readbacks"],))


def check_engine_refusal(evidence, spec):
    """The POSITIVE clause a permissive stub cannot fake.

    `-switchHudTo:` (PlayerEntity.m:4537-4542) logs `PlayerEntity.switchHudTo.failed` and returns
    NO **without touching the HUD** when `dictionaryFromFilesNamed:` yields nil. So the read-back
    after writing an unknown plist must still be the PREVIOUS name. A model that stores whatever
    string it is handed reports the bogus name - and, unlike "no ERROR lines appeared", that is
    not something a corpse satisfies (bead oo-het's exit-87 process carried zero ERROR lines).
    """
    if evidence["hud_refusal_requested"] != spec["unknown_hud_plist"]:
        raise CheckFailed(
            "DEFECT [hud_refusal]: the run probed %r but the spec pins %r as the unknown plist; "
            "the refusal arm and the spec have drifted."
            % (evidence["hud_refusal_requested"], spec["unknown_hud_plist"]))
    if evidence["hud_refusal_after"] == spec["unknown_hud_plist"]:
        raise CheckFailed(
            "DEFECT [hud_refusal]: player.ship.hud reads back %r after an unknown plist was "
            "written - the engine ACCEPTED a HUD that does not exist. The validation branch in "
            "-switchHudTo: is gone, and a HUD name that means nothing makes every mode in this "
            "scenario unverifiable." % evidence["hud_refusal_after"])
    if evidence["hud_refusal_after"] != evidence["hud_refusal_before"]:
        raise CheckFailed(
            "DEFECT [hud_refusal]: the unknown plist was not accepted (good) but the HUD still "
            "CHANGED, from %r to %r. -switchHudTo: is documented to leave the HUD alone on "
            "failure; a HUD that moves to some third state on a bad write is a different defect "
            "and must not be read as a clean refusal."
            % (evidence["hud_refusal_before"], evidence["hud_refusal_after"]))
    if evidence["hud_refused_unknown_plist"] is not True:
        raise CheckFailed(
            "DEFECT [hud_refusal]: the run recorded hud_refused_unknown_plist=%r even though the "
            "read-backs above are consistent with a refusal. The boolean and the two names it "
            "summarises disagree, and the boolean is the one a lazy checker would trust."
            % evidence["hud_refused_unknown_plist"])


def check_frames_real(evidence, spec):
    floor_bytes = int(spec["min_png_bytes"])
    small = {m: n for m, n in evidence["frame_bytes"].items() if n < floor_bytes}
    if small:
        raise CheckFailed(
            "DEFECT [frame_bytes]: these captures are below the %d-byte floor: %r. A black frame "
            "compresses to ~5 KB while a real capture on this surface measures 224-243 KB, so an "
            "undersized PNG means nothing was drawn and every distance computed from it is noise."
            % (floor_bytes, small))
    live_floor = float(spec["frame_liveness_floor"])
    dead = {m: v for m, v in evidence["frame_liveness"].items() if v < live_floor}
    if dead:
        raise CheckFailed(
            "DEFECT [liveness]: these grids have luminance spread below the measured floor %.6f: "
            "%r. A (near-)uniform grid is what a run that never drew the scene produces."
            % (live_floor, dead))
    if sorted(evidence["frame_bytes"]) != sorted(evidence["modes"]):
        raise CheckFailed(
            "DEFECT [frame_bytes]: byte counts were recorded for %r but the run claims modes %r"
            % (sorted(evidence["frame_bytes"]), sorted(evidence["modes"])))


# --- 2. re-derived ------------------------------------------------------------------------------


def check_separation_rederived(evidence, spec):
    """Recompute the headline numbers from their own detail, never trust the summary.

    `best_between_mode_distance` is a SUMMARY of `between_mode_distances`, and `separation_ratio`
    is a summary of two other fields. Reading a summary and asserting on it is how a gate passes
    an edited dump: move the summary and the claim moves with it. Both are re-derived here.
    """
    pairs = evidence["between_mode_distances"]
    if not isinstance(pairs, list) or not pairs:
        raise CheckRefused("between_mode_distances is %r; with no pairs there is no separation to "
                           "judge" % (pairs,))
    modes = evidence["modes"]
    expected_pairs = len(list(itertools.combinations(modes, 2)))
    if len(pairs) != expected_pairs:
        raise CheckFailed(
            "DEFECT [separation]: %d between-mode pair(s) recorded for %d modes; every unordered "
            "pair must be present (%d of them) or the 'closest pair' is the closest of a SUBSET "
            "and the margin is overstated." % (len(pairs), len(modes), expected_pairs))
    seen = {tuple(sorted((p["a"], p["b"]))) for p in pairs}
    if seen != {tuple(sorted(c)) for c in itertools.combinations(modes, 2)}:
        raise CheckFailed(
            "DEFECT [separation]: the recorded pairs %r are not the unordered pairs of %r"
            % (sorted(seen), modes))

    derived_best = min(p["distance"] for p in pairs)
    if abs(derived_best - evidence["best_between_mode_distance"]) > 1e-12:
        raise CheckFailed(
            "DEFECT [separation]: the dump claims the closest different-mode pair is %.9f but the "
            "recorded pairs' minimum is %.9f. The summary disagrees with its own detail, which is "
            "what an edited margin looks like."
            % (evidence["best_between_mode_distance"], derived_best))

    tol = float(spec["within_mode_tolerance"])
    if abs(evidence["within_mode_tolerance"] - tol) > 1e-12:
        raise CheckFailed(
            "DEFECT [tolerance_drift]: the dump was blessed with tolerance %r; spec.json now pins "
            "%r. The spec and the golden must agree, or the stored margin is not the margin the "
            "spec asks for - and a re-bless with a NEW tolerance is a human decision, not a "
            "silent edit." % (evidence["within_mode_tolerance"], tol))

    worst_within = evidence["worst_within_mode_distance"]
    if worst_within > tol:
        raise CheckFailed(
            "DEFECT [within_mode]: two captures of the SAME mode (%s) differ by %.6f, beyond the "
            "measured tolerance %.6f. Either the HUD render became nondeterministic between "
            "captures or rasteriser noise outgrew the calibration - re-measure with --calibrate "
            "before touching the constant."
            % (evidence["within_mode_pair"], worst_within, tol))
    if derived_best <= tol:
        raise CheckFailed(
            "DEFECT [between_mode]: the closest pair of DIFFERENT HUD modes (%s) differ by only "
            "%.6f, WITHIN the tolerance %.6f. Switching the HUD no longer changes what is drawn: "
            "dial definitions are not loading, or the overlay pass was skipped. LOOSENING THE "
            "TOLERANCE TO MAKE THIS PASS IS FORBIDDEN."
            % (evidence["best_between_mode_pair"], derived_best, tol))
    if derived_best <= worst_within:
        raise CheckFailed(
            "DEFECT [overlap]: the populations OVERLAP - worst same-mode %.6f is not below best "
            "different-mode %.6f. No threshold separates them and a frame hash cannot "
            "discriminate these HUD modes on this renderer." % (worst_within, derived_best))

    if worst_within <= 0:
        raise CheckFailed(
            "DEFECT [within_mode]: the worst same-mode distance is %r. A ZERO within-mode "
            "distance means the two 'independent' captures are the same bytes, i.e. the second "
            "capture never happened - and a floor of zero makes any separation ratio infinite, "
            "which is how a vacuous margin is manufactured." % worst_within)
    derived_ratio = derived_best / worst_within
    if abs(derived_ratio - evidence["separation_ratio"]) > 1e-9:
        raise CheckFailed(
            "DEFECT [separation]: the dump claims a %.4fx margin but %.9f / %.9f = %.4fx"
            % (evidence["separation_ratio"], derived_best, worst_within, derived_ratio))
    floor_ratio = float(spec["min_separation_ratio"])
    if derived_ratio < floor_ratio:
        raise CheckFailed(
            "DEFECT [separation]: the measured margin is only %.2fx, under the spec's floor of "
            "%.2fx. A margin this thin means the stimulus has shrunk towards the noise and the "
            "next renderer change will flake the gate." % (derived_ratio, floor_ratio))
    return derived_best, worst_within, derived_ratio


def check_distinct_grids(evidence):
    """Digest identity is a CHEAPER and STRICTER statement than a distance: identical digests
    mean the same scene was rendered twice, which no tolerance can rescue."""
    digests = evidence["mode_grid_digests"]
    if sorted(digests) != sorted(evidence["modes"]):
        raise CheckFailed(
            "DEFECT [distinct_grids]: digests recorded for %r but the run claims modes %r"
            % (sorted(digests), sorted(evidence["modes"])))
    distinct = len(set(digests.values()))
    if distinct != len(evidence["modes"]):
        raise CheckFailed(
            "DEFECT [distinct_grids]: %d modes produced only %d distinct grid digest(s) %r. "
            "Identical grids mean the same scene was rendered more than once: the HUD mode did "
            "not change what was drawn." % (len(evidence["modes"]), distinct, digests))
    if evidence["distinct_mode_grid_digests"] != distinct:
        raise CheckFailed(
            "DEFECT [distinct_grids]: the dump claims %d distinct digests but the recorded "
            "digests contain %d" % (evidence["distinct_mode_grid_digests"], distinct))


# --- 3. re-measured from the stored pixels -------------------------------------------------------


def check_grids_on_disk(dump_path, evidence, spec):
    """Recompute the separation FROM THE STORED GRIDS - the one check a doctored dump fails.

    Every other check in this file reads numbers the dump itself supplies; consistent lies survive
    them all. The grids are SEPARATE FILES, so an edit to state.json does not move them and this
    check goes red. It is skipped (loudly, and reported in the output) only when the grids are not
    beside the dump, because the dump may legitimately be a fresh run's output in a scratch dir.
    """
    directory = os.path.dirname(os.path.abspath(dump_path))
    paths = {entry["mode"]: os.path.join(directory, "frame-%s.grid" % entry["mode"])
             for entry in spec["hud_modes"]}
    present = [m for m, p in paths.items() if os.path.isfile(p)]
    if not present:
        return {"re_measured": False,
                "why": "no frame-<mode>.grid beside %s; the separation was checked from the "
                       "dump's own numbers only" % directory}
    if sorted(present) != sorted(paths):
        raise CheckRefused(
            "only %r of the %d per-mode grids are present in %s. A PARTIAL set cannot produce the "
            "'closest pair' - the missing pair might be the close one - so this is a refusal, "
            "never a pass over the subset." % (sorted(present), len(paths), directory))
    grids = {mode: _read_grid(path) for mode, path in paths.items()}

    for mode, grid in grids.items():
        want = evidence["mode_grid_digests"][mode]
        got = hashlib.sha256(bytes(grid)).hexdigest()
        if got != want:
            raise CheckFailed(
                "DEFECT [grid_witness]: frame-%s.grid hashes to %s but the dump records %s for "
                "that mode. The stored frame and the dump that describes it are not from the same "
                "run." % (mode, got[:16], want[:16]))

    measured = {}
    for a, b in itertools.combinations(sorted(grids), 2):
        measured[(a, b)] = _distance(grids[a], grids[b])
    best_pair, best = min(measured.items(), key=lambda kv: kv[1])
    tol = float(spec["within_mode_tolerance"])
    if best <= tol:
        raise CheckFailed(
            "DEFECT [grid_witness]: RE-MEASURED from the stored grids, the closest different-mode "
            "pair (%s vs %s) differ by only %.6f, within the tolerance %.6f. Whatever the dump "
            "claims, the stored frames do not carry the separation."
            % (best_pair[0], best_pair[1], best, tol))

    for pair in evidence["between_mode_distances"]:
        key = tuple(sorted((pair["a"], pair["b"])))
        if abs(measured[key] - pair["distance"]) > 1e-9:
            raise CheckFailed(
                "DEFECT [grid_witness]: the dump records %s vs %s at %.9f but the stored grids "
                "measure %.9f. The numbers in the dump were not computed from these frames."
                % (pair["a"], pair["b"], pair["distance"], measured[key]))

    primary_path = os.path.join(directory, "frame.grid")
    primary_match = None
    if os.path.isfile(primary_path):
        primary_match = _distance(_read_grid(primary_path), grids[spec["primary_mode"]])
        if primary_match != 0.0:
            raise CheckFailed(
                "DEFECT [grid_witness]: frame.grid is not the %r-mode grid (distance %.6f); the "
                "blessed frame and the blessed mode have drifted apart."
                % (spec["primary_mode"], primary_match))
    return {"re_measured": True,
            "best_between_mode_distance": best,
            "best_between_mode_pair": "%s vs %s" % best_pair,
            "frame_grid_is_primary_mode": primary_match == 0.0 if primary_match is not None
            else None}


# --- the driver ---------------------------------------------------------------------------------


def check(dump_path, spec, label=None):
    label = label or dump_path
    if not os.path.isfile(dump_path):
        raise CheckRefused("no dump at %s" % dump_path)
    with open(dump_path, encoding="utf-8") as handle:
        state = json.load(handle)
    evidence = state.get("evidence")
    if not isinstance(evidence, dict):
        raise CheckRefused(
            "%s carries no evidence block; a dump with no evidence compares equal to any other "
            "evidence-free dump and proves nothing about the HUD" % label)

    check_structure(evidence, spec)
    check_ran_in_flight(evidence, spec)
    check_modes_applied(evidence, spec)
    check_engine_refusal(evidence, spec)
    check_frames_real(evidence, spec)
    check_distinct_grids(evidence)
    best, within, ratio = check_separation_rederived(evidence, spec)
    grids = check_grids_on_disk(dump_path, evidence, spec)

    print("%s evidence OK: %d HUD modes %s captured in flight at %s, %d distinct grid digests; "
          "closest different-mode pair (%s) %.6f vs worst same-mode pair (%s) %.6f = %.2fx "
          "separation against the MEASURED tolerance %.6f (shared 3-D calibration was %.6f); "
          "unknown plist %r REFUSED, hud stayed %r; %s"
          % (SCENARIO, len(evidence["modes"]), evidence["modes"], GUI_SCREEN_MAIN,
             evidence["distinct_mode_grid_digests"], evidence["best_between_mode_pair"], best,
             evidence["within_mode_pair"], within, ratio, evidence["within_mode_tolerance"],
             evidence["shared_calibration_tolerance"], evidence["hud_refusal_requested"],
             evidence["hud_refusal_after"],
             ("separation RE-MEASURED from the stored grids at %.6f (%s)"
              % (grids["best_between_mode_distance"], grids["best_between_mode_pair"]))
             if grids["re_measured"] else grids["why"]))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/check_hud_render_evidence.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("dump", nargs="?", default=None,
                        help="the stored dump; defaults to the blessed/staged state.json")
    parser.add_argument("--spec", default=None)
    parser.add_argument("--label", default=None)
    args = parser.parse_args(argv)
    try:
        spec = load_spec(args.spec)
        dump = args.dump or _first_existing(GOLDEN_CANDIDATES, "stored golden for " + SCENARIO)
        return check(dump, spec, args.label)
    except CheckRefused as exc:
        sys.stderr.write("REFUSED: %s\n" % exc)
        return 2
    except CheckFailed as exc:
        sys.stderr.write("FAIL: %s\n" % exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())
