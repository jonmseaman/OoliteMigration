"""Run tests/golden/dump/dump_state.js against a live game and print the JSON to stdout / a file.

Deliberately NOT tests/golden/golden_run.py: that harness exists to run N scenarios CONCURRENTLY
and stages a whole oolite.app per run for that reason. This script runs ONE game at a time (the
two-run determinism proof is sequential, not concurrent - the whole point is diffing two dumps
from the SAME build, one after another), so it talks to tests/component/console.py directly, the
same transport, with no concurrency-only machinery. See the module docstring in
tests/golden/golden_run.py for why THAT file is exempt from tools/gui-lock; the same reasoning
applies here even more directly - single game, no synthetic input, no window click, artifacts are
read over the console socket. (Confirmed by comparison, not assumption: world_steps.py's `world`
fixture takes tools/gui-lock only because console.py deliberately does not - see console.py's
module docstring - and this script has the identical "no synthetic input, no window click"
profile golden_run.py's docstring gives as the reason it is exempt too.)
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
COMPONENT_DIR = os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component")

sys.path.insert(0, COMPONENT_DIR)
sys.path.insert(0, HERE)

from console import DebugConsole  # noqa: E402
from state_dump import (  # noqa: E402
    dump_state,
    ensure_launchable,
    spawn_deterministic,
    start_with_retry,
)

SCENARIO_SAVE = "Resources/Scenarios/oolite-standard.oolite-save"


def default_app_dir():
    return os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test", "oolite.app")


def clear_system(console):
    """Remove every non-player, non-station ship.

    Stations (and other isStation entities) are themselves members of system.allShips - removing
    the main station undocks the player mid-scenario, which is exactly the divergence source this
    hit during development: an early version removed it, and the player's docked/undocked state
    became a second, unintended RNG-shaped source of run-to-run difference.
    """
    removed = console.evaluate_int(
        "(function(){"
        " var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) { ships[i].remove(); n++; }"
        " }"
        " return n; })()"
    )
    remaining = console.evaluate_int(
        "(function(){"
        " var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) n++;"
        " }"
        " return n; })()"
    )
    if remaining > 0:
        raise SystemExit(
            "cleared %d ships but %d non-station ship(s) remain; scenario would measure "
            "the ambient population rather than what it spawned" % (removed, remaining)
        )


RAW_ORDER_JS = (
    "(function(){"
    " var ships = system.allShips, ids = [];"
    " for (var i = 0; i < ships.length; i++) {"
    "   if (!ships[i].isPlayer) ids.push(ships[i].shipUniqueName || ships[i].name);"
    " }"
    " return JSON.stringify(ids); })()"
)


def run_once(app_dir, port, seed, output_dir, perturb=None, spawn_order=("police", "pirate"),
             raw_order=False):
    """Launch, spawn a fixed scenario, and dump - `ticks` is not needed: see below.

    No frame-stepping is needed to make two runs identical: item 0.4's determinism requirement
    (docs/decisions/0018-component-test-tier.md:102) is explicitly NOT fixed-delta-t stepping,
    because pauseGame() already forces delta_t to 0 (GameController.m:401-402) - the simulation
    never advances between spawn and dump, so there is nothing for a frame-stepper to step.
    """
    console = start_with_retry(
        lambda: DebugConsole(app_dir, port, seed=seed, output_dir=output_dir, load_save=SCENARIO_SAVE)
    )
    try:
        # Pause before touching the world: delta_t is forced to 0 while paused
        # (GameController.m:401-402), which is what makes two dumps of the SAME spawn byte-
        # identical - unpaused, ship AI/physics integrate real wall-clock time between the two
        # processes' launches and no float quantisation can absorb that much drift.
        console.evaluate("pauseGame()")
        clear_system(console)
        # Two roles, deterministically named (state_dump.spawn_deterministic), so a stable-order
        # sort by id reproduces the identical dump twice regardless of allShips iteration order.
        # radius_m=0: no addShips scatter-radius RNG draw, which is otherwise a second source of
        # divergence on top of physics (both are removed by pausing + a fixed seed + zero radius).
        #
        # `spawn_order` is a knob, not decoration: spawning the SAME two roles in the OPPOSITE
        # order changes the order system.allShips hands them back, while leaving the set of ships
        # and every one of their field values identical. That is the perturbation
        # run_order_proof.sh uses to prove ents.sort() is load-bearing - a dump that is not sorted
        # by a stable key reorders under it, a sorted one does not.
        for role in spawn_order:
            spawn_deterministic(console, role, 2, radius_m=0, ai=None)

        if raw_order:
            # Positive control for the order proof: the UNSORTED allShips id sequence. If this is
            # identical across both spawn orders then the perturbation did not actually change
            # iteration order and the proof would be vacuous, so run_order_proof.sh asserts it
            # DIFFERS before it asserts the dumps MATCH.
            return console.evaluate(RAW_ORDER_JS)

        if perturb is not None:
            # Mutant hook for the quantisation-epsilon proof (see run_epsilon_proof.sh): nudge one
            # ship's x coordinate by `perturb` metres just before the dump, so the caller can
            # compare a sub-epsilon nudge (absorbed) against a super-epsilon one (visible).
            console.perform(
                "(function(){ var s = system.allShips[0];"
                " if (s) s.position = Vector3D(s.position.x + (%r), s.position.y, s.position.z);"
                " })();" % float(perturb)
            )

        return dump_state(console)
    finally:
        console.close()


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-dir", default=os.environ.get("OO_APP_DIR", default_app_dir()))
    parser.add_argument("--port", type=int, default=int(os.environ.get("OO_CONSOLE_PORT", "8563")))
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--out", default=None, help="write the dump JSON here instead of stdout")
    parser.add_argument("--output-dir", default=None, help="Latest.log / snapshot dir (tmp if unset)")
    parser.add_argument("--perturb", type=float, default=None,
                         help="metres to nudge allShips[0].position.x before dumping")
    parser.add_argument("--spawn-order", default="police,pirate",
                         help="comma-separated roles to spawn, in order; reversing this changes "
                              "system.allShips iteration order without changing the ship set")
    parser.add_argument("--raw-order", action="store_true",
                         help="emit the UNSORTED allShips id sequence instead of the dump "
                              "(positive control for run_order_proof.sh)")
    args = parser.parse_args(argv)

    spawn_order = tuple(r for r in args.spawn_order.split(",") if r)
    if not spawn_order:
        raise SystemExit("--spawn-order must name at least one role")

    if not os.path.isdir(args.app_dir):
        raise SystemExit("no Oolite build at %s; build it first or pass --app-dir" % args.app_dir)

    # PREFLIGHT, before anything is spawned. A shell without the UCRT64 runtime directory on PATH
    # cannot launch this build at all: Mesa's libgallium_wgl.dll needs libLLVM-22.dll,
    # libSPIRV-Tools.dll and libsystre-0.dll, which live only there, and the loader kills the
    # process with 3221225781 (STATUS_DLL_NOT_FOUND) before main() - no window, no Latest.log, and
    # eight retries of ~116s that cannot possibly succeed. This repairs PATH when it can and fails
    # immediately, naming the missing DLLs, when it cannot. It does NOT weaken the gate: a build
    # that is genuinely broken still fails, just with the real reason instead of a bare exit code.
    ensure_launchable(args.app_dir)

    output_dir = args.output_dir
    if output_dir is None:
        import tempfile
        output_dir = tempfile.mkdtemp(prefix="oo_gla_dump_")
    os.makedirs(output_dir, exist_ok=True)

    text = run_once(args.app_dir, args.port, args.seed, output_dir, perturb=args.perturb,
                    spawn_order=spawn_order, raw_order=args.raw_order)
    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
    else:
        sys.stdout.write(text)
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
