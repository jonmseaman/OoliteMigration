#!/usr/bin/env python3
"""Run a Tier 2 / Tier 3 corpus load sweep: resumable, shardable, honest (bead oo-4z6).

THE ARITHMETIC THAT DICTATES THIS DESIGN
----------------------------------------
oo-het MEASURED the cost of a solo expansion load on this host: 493s for 36
expansions, ~13.5s each, on a box shared with four other workers.  So

    Tier 2 (150 entries)  ~ 34 minutes
    Tier 3 (813 entries)  ~ 3 hours

A three-hour serialised sequence of game launches cannot be a stored acceptance
line and cannot be anyone's edit-loop feedback.  That is the engineering
problem, not an inconvenience, and it is why this runner is built the way it is:

  * RESUMABLE.  Every expansion's result is written to its own file in a state
    directory the moment it is judged.  A re-run reads the state directory and
    runs only what is missing, so a sweep killed at minute 90 costs 90 minutes
    once, not twice.  The resume is proven by acceptance line 4, which runs a
    real two-expansion sweep, re-runs it, and requires the second pass to skip
    everything AND to be measurably faster.
  * SHARDABLE.  --shard K/N partitions the list deterministically so a weekly
    Tier 3 can be spread over several nights (or several machines) and the
    shards' state directories simply union.  NOTE: sharding here multiplies
    LOCAL game launches, never remote requests - the corpus is read from the
    content-addressed cache and this tool NEVER touches the network.
  * OFFLINE-TESTABLE.  Selection (tools/oxp_tier23.py) and reporting
    (tools/oxp_report.py) contain all the logic worth arguing about, and both
    are exercised against committed fixtures with no game launch at all.  The
    launch path itself is validated on a small sample.

HONEST STATES.  Staging is checked at every step and a staging failure is
recorded as STAGEFAIL - never as a missing expansion, which is how an earlier
harness bug sent an agent hunting the corpus cache for twenty minutes.  A
cache miss is NOTCACHED.  Neither is ever green.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import oxp_corpus as oc          # noqa: E402
import oxp_load_check as olc     # noqa: E402
import oxp_report as rep         # noqa: E402

DEFAULT_APP_DIR = "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"


def cache_dir() -> Path:
    env = os.environ.get("OXP_CACHE_DIR")
    if env:
        return Path(env)
    local = os.environ.get("LOCALAPPDATA")
    if local:
        return Path(local) / "OoliteMigration" / "oxp-cache"
    return Path.home() / ".cache" / "oolite-migration" / "oxp-cache"


def safe_key(identifier: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", identifier)[:100]


def load_list(path: Path) -> list:
    d = json.loads(path.read_text(encoding="utf-8"))
    return d["entries"]


def select(entries, shard=None, limit=0, only=""):
    if only:
        entries = [e for e in entries if only.lower() in e["identifier"].lower()]
    if shard:
        k, n = shard
        entries = [e for i, e in enumerate(entries) if i % n == k]
    if limit:
        entries = entries[:limit]
    return entries


def real_runner(app_dir: Path, work: Path, timeout: float):
    """The production runner: stage into a private AddOns dir and launch the game."""
    def run(entry, staged_path: Path):
        return olc.run_one(app_dir, staged_path, work, timeout)
    return run


def stage_one(entry, blob: Path, staging: Path) -> tuple:
    """Copy a cached blob to a real .oxz filename. Returns (path, error_or_None).

    Oolite decides what is an expansion BY EXTENSION (ResourceManager.m:290-310)
    and the cache is content-addressed with no filename at all, so the blob MUST
    be given a name here.  Every step's failure is returned, never swallowed: an
    unchecked copy in a staging loop reappears twenty lines later as a false
    claim about the data.
    """
    dest = staging / (safe_key(entry["identifier"]) + ".oxz")
    try:
        staging.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(blob, dest)
    except OSError as exc:
        return None, "cp failed: %s -> %s: %s" % (blob, dest, exc)
    if not dest.exists():
        return None, "cp reported success but %s does not exist" % dest
    if dest.stat().st_size == 0:
        return None, "staged %s is EMPTY (0 bytes)" % dest
    return dest, None


def run_tier(entries, state_dir: Path, staging: Path, runner, cache: Path,
             verbose=True) -> list:
    """Judge every entry, skipping those already recorded in `state_dir`."""
    state_dir.mkdir(parents=True, exist_ok=True)
    todo, done = [], []
    for e in entries:
        f = state_dir / (safe_key(e["identifier"]) + ".json")
        if f.exists():
            try:
                done.append(json.loads(f.read_text(encoding="utf-8")))
                continue
            except ValueError:
                f.unlink()  # a truncated record from a killed run is not state
        todo.append(e)
    if verbose:
        print("resuming: %d already done, %d to run" % (len(done), len(todo)), flush=True)

    for e in todo:
        t0 = time.time()
        rec = {"identifier": e["identifier"], "title": e.get("title", ""),
               "category": e.get("category", ""), "requires": e.get("requires", []),
               "name": e["identifier"] + ".oxz", "errors": [], "wall_s": 0.0}
        blob = oc.blob_path(cache, e["url"])
        if not blob.exists():
            rec.update(verdict=rep.NOTCACHED,
                       detail="no cached blob at %s for %s; run "
                              "'python3 tools/oxp_corpus.py fetch'" % (blob, e["url"]))
        else:
            staged, err = stage_one(e, blob, staging)
            if err:
                rec.update(verdict=rep.STAGEFAIL, detail="HARNESS BUG: " + err)
            else:
                r = runner(e, staged)
                rec.update(r)
                rec["identifier"] = e["identifier"]
                rec["requires"] = e.get("requires", [])
                rec["category"] = e.get("category", "")
                try:
                    staged.unlink()
                except OSError:
                    pass
        rec["wall_s"] = rec.get("wall_s") or round(time.time() - t0, 2)
        (state_dir / (safe_key(e["identifier"]) + ".json")).write_text(
            json.dumps(rec, indent=2) + "\n", encoding="utf-8")
        done.append(rec)
        if verbose:
            print("%-14s %-46s %6.1fs  %s"
                  % (rep.classify(rec), e["identifier"][:46], rec["wall_s"],
                     (rec.get("detail") or "")[:120]), flush=True)
    return done


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", required=True, help="tier2.json / tier3.json")
    ap.add_argument("--state", default="", help="resumable state directory")
    ap.add_argument("--app-dir", default=os.environ.get("OO_APP_DIR", DEFAULT_APP_DIR))
    ap.add_argument("--shard", default="", help="K/N - run only shard K of N")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--only", default="")
    ap.add_argument("--timeout", type=float, default=180.0)
    ap.add_argument("--report-json", default="")
    args = ap.parse_args(argv)

    entries = load_list(Path(args.list))
    shard = None
    if args.shard:
        k, n = args.shard.split("/")
        shard = (int(k), int(n))
        if not 0 <= shard[0] < shard[1]:
            sys.stderr.write("--shard K/N needs 0 <= K < N\n")
            return 2
    entries = select(entries, shard, args.limit, args.only)
    if not entries:
        sys.stderr.write("selection is EMPTY - refusing to report success on zero checks\n")
        return 2

    app_dir = Path(args.app_dir)
    if not app_dir.is_dir():
        sys.stderr.write(
            "LAUNCH: no build at %s\n  Worktrees are source-only; point --app-dir or "
            "OO_APP_DIR at the shared build. The game cannot be launched, so NO "
            "conclusion about these expansions is possible.\n" % args.app_dir)
        return 3

    base = Path(args.state) if args.state else Path(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))) / "Temp" / "oo-4z6-state"
    # ABSOLUTE, always (bead oo-1gc.11). The game runs with cwd=app_dir and is handed the log and
    # AddOns directories through OO_LOGSDIR / OO_ADDITIONALADDONSDIRS, so a relative --state
    # (e.g. the nightly line's build/nightly/...) resolved against the APP dir: every load then
    # timed out at --timeout as HARNESS "produced NO log", 180 s per expansion.
    base = base.resolve()
    state_dir = base / "results"
    work = base / "runs"
    staging = base / "staging"
    work.mkdir(parents=True, exist_ok=True)

    print("%s: %d expansion(s)%s, app-dir=%s, state=%s"
          % (Path(args.list).stem, len(entries),
             "" if not shard else " (shard %d/%d)" % shard, app_dir, base), flush=True)
    records = run_tier(entries, state_dir, staging,
                       real_runner(app_dir, work, args.timeout), cache_dir())

    report = rep.build(records)
    print()
    print(rep.render(report))
    if args.report_json:
        Path(args.report_json).write_text(json.dumps(report, indent=2) + "\n",
                                          encoding="utf-8")
        print("\nreport json: %s" % args.report_json)
    return 1 if report["failing"] else 0


if __name__ == "__main__":
    sys.exit(main())
