#!/usr/bin/env python3
"""Measurement probe for bead oo-qwk5 (component scenario S8).

S8 asserts that a destroyed ship leaves ``system.allShips``. Expressed with the existing step
catalogue that is a ROLE COUNT going to zero, and the hazard - measured, not assumed - is that
the system populator writes to the same population while the scenario runs, so a count that
reached zero can be refilled by traffic the scenario never spawned.

This probe answers, with numbers rather than argument, the two questions the scenario design
turns on:

1. WHICH ROLES DOES THE POPULATOR WRITE TO in an emptied, launched system?  It takes a full
   census of ``system.allShips`` (shipDataKey + primaryRole + the ship's whole roleSet as the
   engine sees it) every ``--interval`` seconds, so any role whose count ever rises without the
   probe having spawned it is disqualified as an S8 observable.

2. IS THE STIMULUS STRONG ENOUGH?  With ``--spawn`` it lays down a cast and reports when (or
   whether) the quarry left ``system.allShips``, so the killer count and the tick budget can be
   chosen from a distribution rather than from one lucky run.

It deliberately reuses the component tier's own transport (``console.py``) and its own spawn JS
shape, so what it measures is what the scenario will do.

Usage (from a checkout; the app dir must be a BUILT tree, which a worktree is not):

    export PATH="/ucrt64/bin:$PATH" MINGW_PREFIX=/ucrt64
    OO_APP_DIR=C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app \
      python3 tools/oo-qwk5-probe.py --seconds 160 --spawn 'police:1,pirate:8@1' \
      --quarry police --json out.json

``--spawn`` is a comma-separated list of ``role:count`` items; ``@km`` positions that batch within
that many km of the first spawn's locus, exactly as the ``within N km`` step does.
"""

import argparse
import json
import os
import sys
import time

# The tier's transport lives beside the scenarios; this tool is deliberately a CONSUMER of it
# rather than a second implementation, so a transport change cannot make the probe and the
# scenario disagree about what they measured.
_HERE = os.path.dirname(os.path.abspath(__file__))
_TIER = os.path.join(os.path.dirname(_HERE), "upstream", "oolite", "tests", "component")
if _TIER not in sys.path:
    sys.path.insert(0, _TIER)

from console import ConsoleError, DebugConsole  # noqa: E402

SCENARIO_SAVE = "Resources/Scenarios/oolite-standard.oolite-save"
LAUNCH_TIMEOUT_SECONDS = 60
SPAWN_RADIUS_M = 5000

# Same map as steps/world_steps.py: system.addShips gives every ship nullAI.plist, so a scenario
# about combat has to install the role's real AI or nothing ever thinks.
ROLE_AI = {
    "police": "oolite-policeAI.js",
    "pirate": "oolite-pirateAI.js",
    "trader": "oolite-traderAI.js",
    "shuttle": "oolite-shuttleAI.js",
}


def _js_string(value):
    return '"%s"' % str(value).replace("\\", "\\\\").replace('"', '\\"')


def _default_app_dir():
    root = os.path.dirname(_HERE)
    return os.path.join(root, "upstream", "oolite", "build", "meson_test", "oolite.app")


def parse_spawn(text):
    """'police:1,pirate:8@1' -> [('police', 1, None), ('pirate', 8, 1)]"""
    out = []
    for item in [t.strip() for t in (text or "").split(",") if t.strip()]:
        km = None
        if "@" in item:
            item, km_text = item.split("@", 1)
            km = int(km_text)
        role, count = item.split(":", 1)
        out.append((role.strip(), int(count), km))
    return out


def launch_and_empty(console):
    """Launch the player and clear the system, as the Given step does."""
    console.perform("player.ship.launch();")
    deadline = time.time() + LAUNCH_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(1)
        if console.evaluate("player.ship.docked").strip().lower() == "false":
            break
    else:
        raise ConsoleError("player never launched; nothing below this can mean anything")
    time.sleep(2)
    removed = console.evaluate_int(
        "(function(){"
        " var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer) { ships[i].remove(); n++; }"
        " }"
        " return n; })()"
    )
    remaining = console.evaluate_int("system.allShips.length")
    return removed, remaining


def spawn(console, role, count, km):
    ai = ROLE_AI.get(role)
    at_js = "debugConsole.__ooLocus" if km is not None else "player.ship.position"
    radius = (km * 1000) if km is not None else SPAWN_RADIUS_M
    js = (
        "(function(){"
        " var at = %s;"
        " var added = system.addShips(%s, %d, at, %d);"
        " if (!added) return 0;"
        " if (typeof debugConsole.__ooLocus === 'undefined' && added.length > 0)"
        "   debugConsole.__ooLocus = added[0].position;"
        " for (var i = 0; i < added.length; i++) {"
        "   %s"
        " }"
        " return added.length; })()"
        % (at_js, _js_string(role), count, radius,
           ("added[i].setAI(%s);" % _js_string(ai)) if ai else "")
    )
    return console.evaluate_int(js)


# A census rather than a count: shipDataKey names the ship TYPE the populator chose, primaryRole
# names what it was spawned as, and the roleSet is what countShipsWithRole actually matches
# against (ShipEntity.m:7250 hasRole: -> roleSet OR primaryRole OR shipDataKeyAutoRole). Only a
# census can tell "a role rose" from "a different ship type that happens to carry that role
# arrived".
CENSUS_JS = (
    "(function(){"
    " var out = [];"
    " system.allShips.forEach(function(s){"
    "   if (s.isPlayer) return;"
    "   out.push(s.dataKey + '|' + s.primaryRole);"
    " });"
    " return out.join(';'); })()"
)

# Whether the cast is actually FIGHTING, which no role count can show: a scenario whose quarry
# survives because nobody ever engaged it is a different defect from one whose quarry survives
# because the killers are too weak, and only this tells them apart. bounty and scanClass are read
# because policeAI picks its target by offence, so a clean cast never fights at all.
ENGAGE_JS = (
    "(function(){"
    " var out = [];"
    " system.allShips.forEach(function(s){"
    "   if (s.isPlayer) return;"
    "   out.push([s.dataKey, s.primaryRole, s.AIState,"
    "             (s.hasHostileTarget ? 'H' : '-'),"
    "             (s.target ? s.target.primaryRole : 'none'),"
    "             s.bounty, s.scanClass].join(','));"
    " });"
    " return out.join(';'); })()"
)


def census(console):
    text = console.evaluate(CENSUS_JS, timeout=45).strip()
    if not text:
        return []
    return [tuple(item.split("|", 1)) for item in text.split(";") if item]


def engagement(console):
    text = console.evaluate(ENGAGE_JS, timeout=45).strip()
    if not text:
        return []
    return [item.split(",") for item in text.split(";") if item]


def _main_unlocked(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app-dir", default=os.environ.get("OO_APP_DIR") or _default_app_dir())
    ap.add_argument("--port", type=int, default=int(os.environ.get("OO_CONSOLE_PORT", "8563")))
    ap.add_argument("--seed", type=int, default=20260910)
    ap.add_argument("--seconds", type=float, default=160.0, help="observation window")
    ap.add_argument("--interval", type=float, default=4.0, help="seconds between censuses")
    ap.add_argument("--spawn", default="", help="role:count[@km],... spawned before observing")
    ap.add_argument("--quarry", default="", help="role whose disappearance is being timed")
    ap.add_argument("--roles", default="police,pirate,trader,hunter,shuttle,escort,miner",
                    help="roles to report counts for (via countShipsWithRole)")
    ap.add_argument("--json", default="", help="write the full record here")
    ap.add_argument("--engage", action="store_true",
                    help="also sample per-ship AIState/target/bounty, to tell 'nobody engaged' "
                         "apart from 'the killers were too weak'")
    ap.add_argument("--bounty", type=int, default=0,
                    help="set this bounty on every ship of --bounty-role after spawning")
    ap.add_argument("--bounty-role", default="",
                    help="role whose ships get --bounty (policeAI only attacks offenders)")
    ap.add_argument("--output-dir", default=os.environ.get("TEMP", "."),
                    help="where the game writes its log")
    args = ap.parse_args(argv)

    if not os.path.isdir(args.app_dir):
        print(f"no Oolite build at {args.app_dir}", file=sys.stderr)
        return 2

    roles = [r.strip() for r in args.roles.split(",") if r.strip()]
    record = {
        "app_dir": args.app_dir, "seed": args.seed, "seconds": args.seconds,
        "spawn": args.spawn, "quarry": args.quarry, "samples": [],
        "quarry_dead_at": None, "error": None,
    }
    console = DebugConsole(args.app_dir, args.port, seed=args.seed,
                           output_dir=args.output_dir, load_save=SCENARIO_SAVE)
    started = time.time()
    try:
        console.start()
        removed, remaining = launch_and_empty(console)
        record["cleared"] = {"removed": removed, "remaining": remaining}
        print(f"cleared {removed} ships, {remaining} remain")

        record["spawned"] = {}
        for role, count, km in parse_spawn(args.spawn):
            got = spawn(console, role, count, km)
            record["spawned"][role] = record["spawned"].get(role, 0) + got
            print(f"spawned {got}/{count} {role!r}" + (f" within {km} km" if km else ""))

        # The facts that decide whether police will EVER attack the quarry, and which no role
        # count can show. Universe.m:4026 gives a ship spawned under the literal role "pirate" a
        # bounty of 20 + randf()*50, i.e. 20..70 - a DRAW, not a constant. policeAI attacks a
        # scanned ship only when its bounty exceeds fineThreshold(), which is
        # 50 - government*6 (oolite-priorityai.js:845). So in a low-government system a
        # legitimately-spawned pirate is often BELOW the threshold and is never attacked at all,
        # which is a second, independent source of flakiness from combat duration.
        facts = console.evaluate(
            "(function(){ return [system.name, system.info.government,"
            " 50 - system.info.government * 6].join('|'); })()", timeout=45)
        record["system_facts"] = facts
        print(f"system|government|fineThreshold = {facts}")
        bounties = console.evaluate(
            "(function(){ var out = [];"
            " system.allShips.forEach(function(s){"
            "   if (!s.isPlayer) out.push(s.primaryRole + '=' + s.bounty);"
            " }); return out.join(' '); })()", timeout=45)
        record["bounties"] = bounties
        print(f"bounties: {bounties}")

        if args.bounty and args.bounty_role:
            # policeAI only attacks OFFENDERS: oolite-policeAI.js scans for offenders/fugitives,
            # so a spawned pirate with bounty 0 is a clean ship the police will never engage.
            marked = console.evaluate_int(
                "(function(){ var n = 0;"
                " system.allShips.forEach(function(s){"
                "   if (!s.isPlayer && s.primaryRole == %s) { s.bounty = %d; n++; }"
                " }); return n; })()" % (_js_string(args.bounty_role), args.bounty)
            )
            record["bounty_marked"] = marked
            print(f"set bounty={args.bounty} on {marked} {args.bounty_role!r}")

        t0 = time.time()
        deadline = t0 + args.seconds
        while time.time() < deadline:
            t = round(time.time() - t0, 1)
            ships = census(console)
            counts = {r: console.evaluate_int(
                "system.countShipsWithRole(%s)" % _js_string(r), timeout=45) for r in roles}
            sample = {"t": t, "n": len(ships), "counts": counts,
                      "ships": sorted(set(ships))}
            if args.engage:
                sample["engage"] = engagement(console)
            record["samples"].append(sample)
            if args.quarry and record["quarry_dead_at"] is None \
                    and counts.get(args.quarry) == 0:
                record["quarry_dead_at"] = t
            print(f"t={t:7.1f} allShips={len(ships):3d} " +
                  " ".join(f"{r}={counts[r]}" for r in roles))
            if args.engage:
                for row in sample["engage"]:
                    print("        " + " ".join(f"{c:<14}" for c in row))
            time.sleep(max(0.0, args.interval))
    except Exception as exc:  # a probe that dies must say so, not report a short clean run
        record["error"] = f"{type(exc).__name__}: {exc}"
        print(f"PROBE ERROR {record['error']}", file=sys.stderr)
    finally:
        record["wall"] = round(time.time() - started, 1)
        try:
            console.close()
        except Exception:
            pass

    # Derived: every ship TYPE seen, and the first time it appeared. A type that appears after
    # t=0 and was never spawned is populator traffic.
    first_seen = {}
    for sample in record["samples"]:
        for key, primary in (tuple(s) for s in sample["ships"]):
            first_seen.setdefault(f"{key}|{primary}", sample["t"])
    record["first_seen"] = first_seen
    print("\nfirst seen (dataKey|primaryRole -> t):")
    for key in sorted(first_seen, key=lambda k: (first_seen[k], k)):
        print(f"  {first_seen[key]:7.1f}  {key}")
    if args.quarry:
        print(f"\nquarry {args.quarry!r} dead_at={record['quarry_dead_at']}")
    print(f"wall={record['wall']}s error={record['error']}")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as handle:
            json.dump(record, handle, indent=1, sort_keys=True)
        print(f"wrote {args.json}")
    return 1 if record["error"] else 0


def main(argv=None):
    """Run the probe holding tools/gui-lock (bead oo-hub0).

    The probe launches the game on the interactive desktop, one game, by hand - not as a member
    of the golden harness's concurrent fan-out - so CLAUDE.md's desktop-lock rule applies and
    tools/check-desktop-lock.sh lists it as a LOCKED launcher. No lock, no launch.
    """
    sys.path.insert(0, os.path.join(os.path.dirname(_HERE), "tools"))
    from desktop_lock import DesktopLockError, desktop_lock  # noqa: E402  - tools/desktop_lock.py

    try:
        with desktop_lock('qwk5-probe', start=__file__, stream=sys.stderr):
            return _main_unlocked(argv)
    except DesktopLockError as exc:
        print("qwk5-probe: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
