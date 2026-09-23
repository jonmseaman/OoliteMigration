#!/usr/bin/env python3
"""Decision-4 benchmark runner (bead oo-lvj): golden wall-clock and game CPU, interleaved A/B.

Driven by tools/bench-string-copy.sh, which builds the two binaries this needs:

    --a0 EXE   the tree as it is (phase-2), no benchmark code at all
    --b  EXE   the same tree plus tools/bench/string-copy/OOBenchStringCopy.mm, run in three modes
               selected by OO_BENCH_STRING_MODE: off (control), copy, all (see that file)

Each repetition runs every variant once, in a freshly SHUFFLED order (the machine is shared and
its load drifts; interleaving makes drift land on every variant equally), and for each variant
runs every blessed golden scenario exactly the way tools/tier-c.sh's goldens stage does
(launch_dock.py for 001-launch-dock, dump/run_dump.py with a private debugConfig.plist otherwise),
then diffs the dump against the blessed golden. A variant that changes a golden is a failure:
the shadow copies must not change behaviour.

Measured per run: harness wall-clock per scenario (time.perf_counter around the scenario process)
and, for the B binary, the game process's own user+kernel CPU time, written at exit by the hook.

Nothing under goldens/ is written. The app directory's oolite.exe is swapped per variant and the
A0 binary is put back at the end.
"""

import argparse
import json
import os
import random
import shutil
import socket
import statistics
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
PLATFORM = "windows-x64"
VARIANTS = ["A0", "off", "copy", "all"]


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def run_scenario(name, app_dir, run_root, env):
    out = os.path.join(run_root, name + ".json")
    log = os.path.join(run_root, name + ".log")
    if name == "001-launch-dock":
        cmd = [sys.executable, os.path.join(REPO, "tests", "golden", "launch_dock.py"),
               "--app-dir", app_dir, "--out", out, "--run-root", os.path.join(run_root, "ld")]
    else:
        port = free_port()
        cfg = os.path.join(run_root, "cfg", "Config")
        os.makedirs(cfg, exist_ok=True)
        import plistlib
        with open(os.path.join(cfg, "debugConfig.plist"), "wb") as f:
            plistlib.dump({"console-host": "127.0.0.1", "console-port": port}, f, fmt=plistlib.FMT_XML)
        env = dict(env, OO_ADDITIONALADDONSDIRS=os.path.join(run_root, "cfg"))
        cmd = [sys.executable, os.path.join(REPO, "tests", "golden", "dump", "run_dump.py"),
               "--app-dir", app_dir, "--port", str(port), "--out", out,
               "--output-dir", os.path.join(run_root, "out")]
    t0 = time.perf_counter()
    with open(log, "w") as f:
        rc = subprocess.call(cmd, cwd=REPO, env=env, stdout=f, stderr=subprocess.STDOUT)
    wall = time.perf_counter() - t0
    if rc != 0 or not os.path.exists(out) or os.path.getsize(out) == 0:
        raise SystemExit(f"scenario {name} failed (rc={rc}); see {log}")
    golden = os.path.join(REPO, "goldens", PLATFORM, name, "state.json")
    drc = subprocess.call([sys.executable, os.path.join(REPO, "tests", "golden", "golden_diff.py"), golden, out],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if drc != 0:
        raise SystemExit(f"scenario {name} DIFFERS from its blessed golden (rc={drc}) under {env.get('OO_BENCH_STRING_MODE')}")
    return wall


def read_reports(path):
    rows = []
    if os.path.exists(path):
        for line in open(path):
            rows.append(dict(kv.split("=", 1) for kv in line.split()))
    return rows


def summary(values):
    return {"n": len(values), "median": statistics.median(values), "min": min(values), "max": max(values),
            "stdev": statistics.stdev(values) if len(values) > 1 else 0.0}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app-dir", required=True)
    ap.add_argument("--a0", required=True)
    ap.add_argument("--b", required=True)
    ap.add_argument("--reps", type=int, default=5)
    ap.add_argument("--out", required=True, help="results JSON")
    ap.add_argument("--seed", type=int, default=4)
    args = ap.parse_args()

    gdir = os.path.join(REPO, "goldens", PLATFORM)
    scenarios = sorted(d for d in os.listdir(gdir) if os.path.isfile(os.path.join(gdir, d, "state.json")))
    if len(scenarios) < 2:
        raise SystemExit(f"only {len(scenarios)} blessed scenario(s); expected >= 2")
    exe = os.path.join(args.app_dir, "oolite.exe")
    rng = random.Random(args.seed)
    root = tempfile.mkdtemp(prefix="bench-string-")
    runs = []
    try:
        for rep in range(args.reps):
            order = VARIANTS[:]
            rng.shuffle(order)
            for variant in order:
                shutil.copyfile(args.a0 if variant == "A0" else args.b, exe)
                run_root = os.path.join(root, f"r{rep}-{variant}")
                os.makedirs(run_root)
                report = os.path.join(run_root, "cpu.txt")
                env = dict(os.environ, OO_BENCH_STRING_REPORT=report,
                           OO_BENCH_STRING_MODE="off" if variant == "A0" else variant)
                walls = {s: run_scenario(s, args.app_dir, run_root, env) for s in scenarios}
                cpu = read_reports(report)
                row = {"rep": rep, "variant": variant, "wall": walls, "total_wall": sum(walls.values()),
                       "cpu_ms": sum(int(r["user_ms"]) + int(r["kernel_ms"]) for r in cpu) if cpu else None,
                       "shadow": sum(int(r["shadow"]) for r in cpu) if cpu else None,
                       "heap": sum(int(r["heap"]) for r in cpu) if cpu else None,
                       "bytes": sum(int(r["bytes"]) for r in cpu) if cpu else None,
                       "processes": len(cpu)}
                runs.append(row)
                print(json.dumps(row), flush=True)
    finally:
        shutil.copyfile(args.a0, exe)
        shutil.rmtree(root, ignore_errors=True)

    result = {"scenarios": scenarios, "reps": args.reps, "runs": runs, "summary": {}}
    for v in VARIANTS:
        rows = [r for r in runs if r["variant"] == v]
        s = {"total_wall": summary([r["total_wall"] for r in rows])}
        for sc in scenarios:
            s["wall:" + sc] = summary([r["wall"][sc] for r in rows])
        if all(r["cpu_ms"] is not None for r in rows):
            s["cpu_ms"] = summary([r["cpu_ms"] for r in rows])
            s["shadow"] = summary([r["shadow"] for r in rows])
            s["heap"] = summary([r["heap"] for r in rows])
            s["bytes"] = summary([r["bytes"] for r in rows])
        result["summary"][v] = s
    base_wall = result["summary"]["A0"]["total_wall"]["median"]
    base_cpu = result["summary"]["off"].get("cpu_ms", {}).get("median")
    for v in VARIANTS:
        s = result["summary"][v]
        s["wall_vs_A0_pct"] = 100.0 * (s["total_wall"]["median"] - base_wall) / base_wall
        if base_cpu and "cpu_ms" in s:
            s["cpu_vs_off_pct"] = 100.0 * (s["cpu_ms"]["median"] - base_cpu) / base_cpu
    # Paired: each repetition ran every variant back to back, so the per-repetition ratio to that
    # repetition's own B-off run cancels most of the machine's drift. This is the headline figure.
    by_rep = {}
    for r in runs:
        by_rep.setdefault(r["rep"], {})[r["variant"]] = r
    for v in VARIANTS:
        if v == "off":
            continue
        s = result["summary"][v]
        wall = [100.0 * (by_rep[k][v]["total_wall"] / by_rep[k]["off"]["total_wall"] - 1) for k in sorted(by_rep)]
        s["paired_wall_vs_off_pct"] = summary(wall)
        if len(wall) >= 2:
            q = statistics.quantiles(wall, n=4)
            s["paired_wall_vs_off_pct"]["iqr"] = [q[0], q[2]]
        if v != "A0":
            cpu = [100.0 * (by_rep[k][v]["cpu_ms"] / by_rep[k]["off"]["cpu_ms"] - 1) for k in sorted(by_rep)]
            s["paired_cpu_vs_off_pct"] = summary(cpu)
            if len(cpu) >= 2:
                q = statistics.quantiles(cpu, n=4)
                s["paired_cpu_vs_off_pct"]["iqr"] = [q[0], q[2]]
    with open(args.out, "w") as f:
        json.dump(result, f, indent=2)
    for v in VARIANTS:
        s = result["summary"][v]
        print(f"{v:5s} wall median {s['total_wall']['median']:7.2f}s [{s['total_wall']['min']:.2f}..{s['total_wall']['max']:.2f}]"
              f"  {s['wall_vs_A0_pct']:+6.2f}% vs A0"
              + (f"  cpu median {s['cpu_ms']['median']:.0f}ms [{s['cpu_ms']['min']:.0f}..{s['cpu_ms']['max']:.0f}]"
                 f"  {s.get('cpu_vs_off_pct', 0):+6.2f}% vs off  shadow {s['shadow']['median']:.0f}" if "cpu_ms" in s else ""))
    for v in VARIANTS:
        s = result["summary"][v]
        for key in ("paired_wall_vs_off_pct", "paired_cpu_vs_off_pct"):
            if key in s:
                p = s[key]
                iqr = p.get("iqr", [p["min"], p["max"]])
                print(f"{v:5s} {key}: median {p['median']:+.2f}%  IQR [{iqr[0]:+.2f}, {iqr[1]:+.2f}]  range [{p['min']:+.2f}, {p['max']:+.2f}]")


if __name__ == "__main__":
    main()
