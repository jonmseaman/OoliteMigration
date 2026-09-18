"""What ship.speed does with an out-of-range, non-numeric or player write (bead oo-jou1).

Separate from motion_probe.py because it asks a different question. That file asks "does the
write STICK across frames"; this one asks "what happens when the write is wrong", which is the
half of a setter's contract that is easiest to leave unspecified and hardest to change later
once OXPs depend on it.

Each probe writes one value to one spawned ship and records what came back, so the committed
witness is a readable table of the seam's value policy rather than prose claiming one.
"""

import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))
sys.path.insert(0, os.path.join(REPO_ROOT, "tests", "golden", "dump"))
sys.path.insert(0, HERE)

from console import DebugConsole, ConsoleError  # noqa: E402
from state_dump import ensure_launchable, start_with_retry  # noqa: E402
from motion_probe import (  # noqa: E402
    app_dir_fingerprint, pick_port, spawn_named, stage_mesa_if_missing, write_console_config,
)

SCENARIO_SAVE = "Resources/Scenarios/oolite-standard.oolite-save"
PREFIX = "jou1-value-"

# (name, JS assignment, what the design says should happen)
CASES = (
    ("negative", "s.speed = -5;", "refused"),
    ("nan", "s.speed = 0/0;", "refused"),
    ("non-numeric", "s.speed = 'x';", "refused"),
    ("above-max", "s.speed = s.maxSpeed * 3;", "accepted"),
    ("zero", "s.speed = 0;", "accepted"),
)

FIND = ("(function(){var a=system.allShips;"
        " for(var i=0;i<a.length;i++){"
        "   if((a[i].shipUniqueName||'').indexOf(%r)===0) return a[i];"
        " } return null;})()" % PREFIX)


def probe(console, js):
    """Run one write and report the outcome WITH the resulting speed.

    Reporting the speed after a refusal is the point: a setter that reports an error and writes
    the value anyway is worse than one that does neither, and only reading the property back can
    tell those apart.
    """
    wrapped = (
        "(function(){ var s = %s; var before = s.speed;"
        " try { %s } catch (e) {"
        "   return JSON.stringify({outcome:'refused', error:String(e),"
        "                          before:before, after:s.speed, max:s.maxSpeed}); }"
        " return JSON.stringify({outcome:'accepted', error:null,"
        "                        before:before, after:s.speed, max:s.maxSpeed}); })()"
        % (FIND, js)
    )
    return json.loads(console.evaluate(wrapped))


def probe_player(console):
    wrapped = (
        "(function(){ try { player.ship.speed = 0;"
        "   return JSON.stringify({outcome:'accepted', error:null}); }"
        " catch (e) { return JSON.stringify({outcome:'refused', error:String(e)}); } })()"
    )
    return json.loads(console.evaluate(wrapped))


def run(app_dir, port, seed, output_dir):
    config_dir = os.path.join(output_dir, "console-config")
    write_console_config(config_dir, "127.0.0.1", port)
    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = (
        "%s,%s" % (config_dir, previous) if previous else config_dir
    )
    witness = {"binary": app_dir_fingerprint(app_dir), "port": port, "cases": []}
    try:
        console = start_with_retry(
            lambda: DebugConsole(app_dir, port, seed=seed, output_dir=output_dir,
                                 load_save=SCENARIO_SAVE)
        )
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
    try:
        spawn_named(console, "pirate", 1, PREFIX)
        time.sleep(1.0)  # let it start moving, so `before` is a real speed, not a spawn zero
        for name, js, expected in CASES:
            try:
                result = probe(console, js)
            except ConsoleError as exc:
                result = {"outcome": "console-error", "error": str(exc)}
            result.update({"case": name, "js": js, "expected": expected})
            witness["cases"].append(result)
        player = probe_player(console)
        player.update({"case": "player", "js": "player.ship.speed = 0;", "expected": "refused"})
        witness["cases"].append(player)
    finally:
        console.close()
    return witness


def main(argv=None):
    parser = argparse.ArgumentParser()
    default_app = os.environ.get(
        "OO_APP_DIR",
        os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test", "oolite.app"))
    parser.add_argument("--app-dir", default=default_app)
    parser.add_argument("--port", type=int, default=int(os.environ.get("OO_CONSOLE_PORT", "0")))
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--out", default=None)
    parser.add_argument("--output-dir", default=None)
    args = parser.parse_args(argv)

    if not os.path.isdir(args.app_dir):
        raise SystemExit("no Oolite build at %s; build it first or pass --app-dir" % args.app_dir)
    ensure_launchable(args.app_dir)
    stage_mesa_if_missing(args.app_dir)
    port = pick_port(args.port or None)

    output_dir = args.output_dir
    if output_dir is None:
        import tempfile
        output_dir = tempfile.mkdtemp(prefix="oo_jou1_value_")
    os.makedirs(output_dir, exist_ok=True)

    witness = run(args.app_dir, port, args.seed, output_dir)
    text = json.dumps(witness, indent=2, sort_keys=True)
    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text + "\n")
        print("wrote %s" % args.out)
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
