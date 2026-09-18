"""Run tests/golden/dump/run_dump.py against a PRIVATE console port and a PRIVATE staged app.

WHY THIS EXISTS (bead oo-5ggu). run_dump.py talks to the game on port 8563 and launches the
binary straight out of the app dir it is given. Both are fine for one agent alone on the box and
wrong for a live fleet:

  * THE GAME DIALS OUT. It reads `console-port` from debugConfig.plist (OODebugSupport.m:67-80,
    default kOOTCPConsolePort=8563), so run_dump.py's --port only changes what WE listen on. On a
    shared machine a sibling's console can accept our game (console.py:_accept takes whoever
    connects) and quit it seconds in, and the run still exits rc=0 - a fully vacuous pass
    (fleet learnings oo-gla, oo-het). A port is made real only by writing the plist the game
    merges, which is what tests/golden/golden_run.py does and what this script reuses.
  * THE PREFS ROOT IS THE APP DIR. src/SDL/main.m:119 points GNUSTEP_USERS_ROOT at the directory
    the executable lives in, so two processes sharing one oolite.app race on one
    Defaults/oolite.plist. golden_run.stage_app builds a private app from junctions + hard links
    with GNUstep/, Logs/ and oolite-saves/ as real copies; that costs no build time and leaves the
    source app dir untouched - which is what makes it safe to dump from the SHARED build while
    four siblings are launching it.

Nothing about the dump itself changes: run_dump.py is imported and its run_once() is called, so
the scenario, the pause, the clear, the spawn and the quantisation are byte-for-byte the same
code path the stored golden came from.
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GOLDEN_DIR = os.path.abspath(os.path.join(HERE, ".."))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))

sys.path.insert(0, GOLDEN_DIR)
sys.path.insert(0, HERE)

import golden_run  # noqa: E402
import run_dump  # noqa: E402
from state_dump import ensure_launchable  # noqa: E402


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-dir", required=True,
                        help="the SOURCE oolite.app; it is only read (staged by link/hardlink)")
    parser.add_argument("--work-dir", required=True,
                        help="scratch root: staged app, console config and logs land here")
    parser.add_argument("--out", required=True)
    parser.add_argument("--port", type=int, default=None,
                        help="default: reserved from golden_run's range, lock held for this run")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--quant-decimals", type=int, default=None)
    parser.add_argument("--keep-staged", action="store_true")
    args = parser.parse_args(argv)

    app_dir = golden_run.to_native(args.app_dir, "app dir")
    work = golden_run.to_native(args.work_dir, "work dir")
    if not os.path.isdir(app_dir):
        raise SystemExit("no Oolite build at %s" % app_dir)
    os.makedirs(work, exist_ok=True)

    ensure_launchable(app_dir)

    port = golden_run.reserve_port(work, args.port)
    staged = os.path.join(work, "app")
    config = os.path.join(work, "console-config")
    logs = os.path.join(work, "logs")
    for d in (config, logs):
        os.makedirs(d, exist_ok=True)

    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config, "127.0.0.1", port)

    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = (
        "%s,%s" % (config, previous) if previous else config)
    try:
        text = run_dump.run_once(staged, port, args.seed, logs,
                                 quant_decimals=args.quant_decimals)
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not args.keep_staged:
            golden_run.unstage_app(staged)

    with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    sys.stderr.write("dumped %d bytes to %s (port %d, app %s)\n"
                     % (len(text), args.out, port, app_dir))
    return 0


if __name__ == "__main__":
    sys.exit(main())
