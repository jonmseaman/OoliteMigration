"""Run one golden scenario in one native game process; the half that needs a real language.

`tests/golden/run.sh` is the entry point and stages Mesa; this file does the isolation:

* PORT. The game DIALS OUT to the console and reads the port from `console-port` in
  debugConfig.plist (OODebugSupport.m:67-80, default kOOTCPConsolePort=8563), so a port is made
  real by writing a plist the game merges, not by listening elsewhere - see `_write_console_config`,
  which is upstream/oolite/tests/launch_snapshot.py's `_console_config_dir` trick. Ports are taken
  from a range under an exclusive lock file held for the life of the run, so N concurrent runs
  cannot land on the same port even between the moment one is chosen and the moment it is bound.

* PREFS ROOT. src/SDL/main.m:119 sets GNUSTEP_USERS_ROOT to the directory the executable lives in,
  so N processes sharing one oolite.app share (and race on) one GNUstep/Defaults/oolite.plist and
  one cache. Each run therefore gets its own staged app directory: directories are junctions and
  files are hard links, so staging 317 MB costs no bytes, while GNUstep/ and Logs/ are real copies
  the run may write to freely.

* READINESS. Never measured on this script's wall clock. console.py pings until Pong proves the run
  loop is servicing packets, and `_wait_until_rendering` then polls clock.absoluteSeconds (UNIVERSE
  time, which only advances while the run loop steps). A fixed sleep here is the proven way to
  snapshot the first frame ever drawn and get a black PNG.

Paths handed to native processes are native (C:/...); run.sh converts with `cygpath -m` before
calling us, because a native python reads an MSYS /c/... path as a relative C:/c/... and fails.
"""

import argparse
import json
import os
import plistlib
import shutil
import socket
import sys
import time
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
IS_WINDOWS = os.name == "nt"

# Deliberately above the component tier's 8563 so the two tiers never fight for a port.
PORT_BASE = int(os.environ.get("OO_GOLDEN_PORT_BASE", "8600"))
PORT_COUNT = int(os.environ.get("OO_GOLDEN_PORT_COUNT", "200"))

# Real copies rather than links: the game writes these, and sharing them is the collision
# (c) in the bead body describes.
PRIVATE_SUBDIRS = ("GNUstep", "Logs", "oolite-saves")

_held_locks = []


class GoldenError(RuntimeError):
    pass


# --- port reservation -------------------------------------------------------------------------

def reserve_port(run_root, wanted=None):
    """Take a port nobody else is using, and keep it until this process exits.

    Two gates, because either alone has a race: an exclusive lock file (so a concurrent runner that
    has chosen a port but not yet bound it still excludes us) and an actual bind (so a port held by
    something outside the harness is skipped).
    """
    lock_dir = os.path.join(run_root, ".ports")
    os.makedirs(lock_dir, exist_ok=True)
    candidates = [wanted] if wanted else range(PORT_BASE, PORT_BASE + PORT_COUNT)
    for port in candidates:
        lock = os.path.join(lock_dir, "%d.lock" % port)
        try:
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            if _lock_is_stale(lock):
                _release(lock)
            continue
        os.write(fd, ("%d\n" % os.getpid()).encode())
        os.close(fd)
        probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            probe.bind(("127.0.0.1", port))
        except OSError:
            _release(lock)
            continue
        finally:
            probe.close()
        _held_locks.append(lock)
        return port
    raise GoldenError("no free console port in %d..%d" % (PORT_BASE, PORT_BASE + PORT_COUNT))


def _lock_is_stale(lock):
    """A lock whose owner is gone. Cheap and conservative: only the pid is trusted."""
    try:
        with open(lock) as handle:
            pid = int(handle.read().strip() or "0")
    except (OSError, ValueError):
        return True
    if pid <= 0:
        return True
    try:
        os.kill(pid, 0)
    except OSError:
        return True
    except Exception:
        return False
    return False


def _release(lock):
    try:
        os.unlink(lock)
    except OSError:
        pass


def release_all():
    while _held_locks:
        _release(_held_locks.pop())


# --- per-run app directory --------------------------------------------------------------------

def _link_dir(source, target):
    if IS_WINDOWS:
        import _winapi
        _winapi.CreateJunction(source, target)
    else:
        os.symlink(source, target)


def stage_app(app_dir, staged):
    """Build a private oolite.app whose GNUSTEP_USERS_ROOT is ours alone."""
    os.makedirs(staged, exist_ok=True)
    for name in sorted(os.listdir(app_dir)):
        source = os.path.join(app_dir, name)
        target = os.path.join(staged, name)
        if os.path.isdir(source):
            if name in PRIVATE_SUBDIRS:
                shutil.copytree(source, target, dirs_exist_ok=True)
            else:
                _link_dir(source, target)
        else:
            try:
                os.link(source, target)
            except OSError:
                shutil.copy2(source, target)
    for name in PRIVATE_SUBDIRS:
        os.makedirs(os.path.join(staged, name), exist_ok=True)
    return staged


def unstage_app(staged):
    """Remove a staged app without following its junctions into the real build.

    shutil.rmtree on a tree containing junctions is exactly how a harness deletes the build it was
    supposed to read, so links are removed as links and only real copies are recursed into.
    """
    if not os.path.isdir(staged):
        return
    for name in os.listdir(staged):
        path = os.path.join(staged, name)
        if os.path.isdir(path) and not os.path.islink(path):
            shutil.rmtree(path, ignore_errors=True)
        elif os.path.isdir(path):
            try:
                os.rmdir(path)
            except OSError:
                pass
        else:
            try:
                os.unlink(path)
            except OSError:
                pass
    try:
        os.rmdir(staged)
    except OSError:
        pass


def _write_console_config(root, host, port):
    """A throwaway resource root naming the console port, merged by the game.

    OO_ADDITIONALADDONSDIRS becomes a search root (OOOXZManager.m:286 -> userRootPaths) and a plain
    directory root needs no manifest.plist. The stock Debug OXP leaves console-host/console-port
    commented out, so this always wins the merge regardless of path order.
    """
    config = os.path.join(root, "Config")
    os.makedirs(config, exist_ok=True)
    path = os.path.join(config, "debugConfig.plist")
    with open(path, "wb") as handle:
        plistlib.dump({"console-host": host, "console-port": port}, handle, fmt=plistlib.FMT_XML)
    return path


# --- scenario ----------------------------------------------------------------------------------

def load_scenario(repo_root, name):
    path = os.path.join(repo_root, "tests", "golden", "scenarios", name, "scenario.json")
    spec = {"seed": 1, "settle_seconds": 2.0, "snapshot": True, "load_save": None, "js": []}
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as handle:
            spec.update(json.load(handle))
    spec["_path"] = path if os.path.isfile(path) else None
    return spec


def plan(args, run_root):
    port = reserve_port(run_root, args.port)
    stamp = time.strftime("%Y%m%dT%H%M%S", time.gmtime())
    run_id = "%s-p%d-%d-%s" % (stamp, port, os.getpid(), uuid.uuid4().hex[:6])
    artifact_dir = os.path.join(run_root, args.scenario, run_id)
    return {
        "scenario": args.scenario,
        "console_host": "127.0.0.1",
        "console_port": port,
        "artifact_dir": artifact_dir,
        "staged_app_dir": os.path.join(artifact_dir, "app"),
        "config_dir": os.path.join(artifact_dir, "console-config"),
        "source_app_dir": args.app_dir,
        "run_id": run_id,
    }


# --- the run -----------------------------------------------------------------------------------

def _wait_until_rendering(console, settle_seconds, timeout=180):
    """Gate on the GAME's clock, never on ours. See the module docstring."""
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + timeout
    while time.time() < deadline:
        elapsed = float(console.evaluate("clock.absoluteSeconds")) - start
        if elapsed >= settle_seconds:
            return elapsed
        time.sleep(0.5)
    raise GoldenError("game time did not advance %ss within %ss" % (settle_seconds, timeout))


def run_scenario(spec, p, timeout):
    sys.path.insert(0, os.path.join(p["repo_root"], "upstream", "oolite", "tests", "component"))
    from console import DebugConsole  # noqa: E402  (path is only valid once set above)

    os.makedirs(p["artifact_dir"], exist_ok=True)
    stage_app(p["source_app_dir"], p["staged_app_dir"])
    _write_console_config(p["config_dir"], p["console_host"], p["console_port"])

    # console.py builds the child environment from os.environ, so the search root is exported here
    # rather than passed; it is restored afterwards so a caller's value survives.
    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = (
        "%s,%s" % (p["config_dir"], previous) if previous else p["config_dir"]
    )
    result = dict(p, ok=False)
    started = time.time()
    try:
        console = DebugConsole(
            p["staged_app_dir"], p["console_port"], seed=spec["seed"],
            output_dir=p["artifact_dir"], host=p["console_host"],
            load_save=spec["load_save"],
        )
        console.start(ready_timeout=min(timeout, 180))
        with console:
            result["game_seconds"] = _wait_until_rendering(console, spec["settle_seconds"])
            result["gui_screen"] = console.evaluate("guiScreen")
            for js in spec.get("js") or []:
                console.perform(js)
            if spec.get("snapshot", True):
                before = set(_pngs(p["artifact_dir"]))
                console.perform("takeSnapShot();")
                result["snapshot"] = _await_png(p["artifact_dir"], before)
        result["ok"] = True
    finally:
        result["wall_seconds"] = round(time.time() - started, 1)
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        with open(os.path.join(p["artifact_dir"], "run.json"), "w", encoding="utf-8") as handle:
            json.dump(result, handle, indent=2, sort_keys=True)
    return result


def _pngs(directory):
    return [f for f in os.listdir(directory) if f.endswith(".png")]


def _await_png(directory, before, timeout=60):
    deadline = time.time() + timeout
    while time.time() < deadline:
        new = [f for f in _pngs(directory) if f not in before]
        if new:
            path = os.path.join(directory, sorted(new)[0])
            size = -1
            while size != os.path.getsize(path):  # the game is still writing it
                size = os.path.getsize(path)
                time.sleep(0.3)
            return path
        time.sleep(0.3)
    raise GoldenError("no snapshot appeared in %s within %ss" % (directory, timeout))


def parse_args(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/run.sh", add_help=True)
    parser.add_argument("scenario")
    parser.add_argument("--repo-root", default=os.path.abspath(os.path.join(HERE, "..", "..")))
    parser.add_argument("--app-dir", default=os.environ.get("OO_APP_DIR", ""))
    parser.add_argument("--run-dir", default=os.environ.get("OO_GOLDEN_RUNDIR", ""))
    parser.add_argument("--port", type=int, default=int(os.environ.get("OO_CONSOLE_PORT", "0")) or None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--plan-count", type=int, default=1,
                        help="with --dry-run: emit N plans at once; all N ports are held "
                             "simultaneously, so they are distinct for the same reason N "
                             "concurrent runs are")
    parser.add_argument("--keep", action="store_true", help="keep the staged app directory")
    parser.add_argument("--timeout", type=float, default=600.0)
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    run_root = args.run_dir or os.path.join(args.repo_root, "tests", "golden", "artifacts")
    os.makedirs(run_root, exist_ok=True)
    spec = load_scenario(args.repo_root, args.scenario)

    plans = []
    try:
        for _ in range(max(1, args.plan_count)):
            p = plan(args, run_root)
            p["repo_root"] = args.repo_root
            p["seed"] = spec["seed"]
            plans.append(p)

        if args.dry_run:
            json.dump(plans if args.plan_count > 1 else plans[0], sys.stdout, indent=2,
                      sort_keys=True)
            sys.stdout.write("\n")
            return 0

        p = plans[0]
        if not os.path.isdir(p["source_app_dir"]):
            raise GoldenError(
                "no Oolite build at %s; build it first or pass --app-dir" % p["source_app_dir"]
            )
        result = run_scenario(spec, p, args.timeout)
        print("[+] %s ok on port %d -> %s" % (args.scenario, p["console_port"], p["artifact_dir"]))
        return 0 if result["ok"] else 1
    except GoldenError as exc:
        print("[!] %s" % exc, file=sys.stderr)
        return 1
    finally:
        if not args.dry_run and not args.keep:
            for p in plans:
                unstage_app(p["staged_app_dir"])
        release_all()


if __name__ == "__main__":
    sys.exit(main())
