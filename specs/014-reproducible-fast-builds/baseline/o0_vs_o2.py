"""CPU time of single game compiles at -O2 and at -O0 (nothing else changed).

usage: python -I o0_vs_o2.py <compile_commands.json> <out_dir> <source basename>...

CPU time (GetProcessTimes), not wall time, so other builds on the machine move it little.
clang's driver runs cc1 in-process on Windows, so the process's times are the compile's.
"""
import ctypes
import ctypes.wintypes as wt
import json
import os
import shlex
import subprocess
import sys

cc_path, out_dir, names = sys.argv[1], os.path.abspath(sys.argv[2]), sys.argv[3:]
os.makedirs(out_dir, exist_ok=True)
k32 = ctypes.windll.kernel32


def cpu_seconds(handle):
    c, e, k, u = (wt.FILETIME() for _ in range(4))
    k32.GetProcessTimes(handle, ctypes.byref(c), ctypes.byref(e), ctypes.byref(k), ctypes.byref(u))
    ft = lambda f: (f.dwHighDateTime << 32 | f.dwLowDateTime) / 1e7
    return ft(k) + ft(u)


def run(args, cwd):
    p = subprocess.Popen(args, cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    p.wait()
    t = cpu_seconds(int(p._handle))
    return p.returncode, t


entries = json.load(open(cc_path, encoding="utf-8"))
for name in names:
    e = next(x for x in entries if "oolite.exe.p" in x["output"] and x["file"].endswith("/" + name))
    args = shlex.split(e["command"].replace("\\", "/"))
    clean = []
    skip = False
    for a in args:
        if skip:
            skip = False
            continue
        if a in ("-MD",):
            continue
        if a in ("-MQ", "-MF", "-o"):
            skip = True
            continue
        clean.append(a)
    times = {}
    for level in ("-O2", "-O0"):
        cmd = [level if a == "-O2" else a for a in clean]
        assert level in cmd, "no -O2 on the compile line"
        cmd += ["-o", os.path.join(out_dir, name + level + ".obj")]
        best = None
        for _ in range(2):
            rc, t = run(cmd, e["directory"])
            if rc != 0:
                sys.exit(f"{name} {level}: compile failed")
            best = t if best is None else min(best, t)
        times[level] = best
    print(f"{name:22s} -O2 {times['-O2']:6.1f}s cpu   -O0 {times['-O0']:6.1f}s cpu   "
          f"-O0/-O2 = {times['-O0'] / times['-O2']:.2f}")
