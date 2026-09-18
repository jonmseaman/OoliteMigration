"""Assert the golden build flags are ACTUALLY IN EFFECT, by reading what the build system emits.

A policy document that says `-ffp-contract=off` while the build quietly contracts is worse than no
policy: it produces confident, wrong conclusions about why two platforms disagree. So this checker
never reads meson.build. It reads `compile_commands.json` - the exact command lines ninja will run
- and asserts, per translation unit:

  * `-ffp-contract=off` is present (no FMA fusion, so `a*b+c` rounds twice on every target);
  * the pinned optimisation level is present;
  * no flag that would defeat either appears (-ffast-math, -funsafe-math-optimizations,
    -ffp-contract=fast/on, -Ofast).

It reports the number of TUs it checked and REFUSES a build database with implausibly few, because
"0 of 0 translation units violate the policy" is the vacuous form of this check.

Usage:
  check_build_flags.py --build-dir <dir with compile_commands.json>
  check_build_flags.py --configure-from <meson source dir> [--build-dir <scratch>]
"""

import argparse
import collections
import json
import os
import re
import shlex
import subprocess
import sys

REQUIRED_FP = "-ffp-contract=off"
PINNED_O = "-O2"

# Anything here re-enables contraction or otherwise licenses the optimiser to reassociate float
# arithmetic; any one of them silently voids the policy even with REQUIRED_FP also on the line.
FORBIDDEN = (
    "-ffast-math",
    "-Ofast",
    "-funsafe-math-optimizations",
    "-fassociative-math",
    "-freciprocal-math",
    "-ffp-contract=fast",
    "-ffp-contract=on",
    "-ffp-contract=fast-honor-pragmas",
)

# Oolite is ~240 translation units. A database with a handful means the configure failed part way
# or somebody pointed this at the wrong directory; either way the verdict would be meaningless.
MIN_TUS = 100


def tokens(entry):
    if "arguments" in entry:
        return list(entry["arguments"])
    return shlex.split(entry["command"], posix=False)


def check_db(path):
    with open(path, "r", encoding="utf-8") as handle:
        db = json.load(handle)

    problems = []
    if len(db) < MIN_TUS:
        problems.append(
            "compile_commands.json has only %d translation unit(s); fewer than the %d minimum. "
            "A per-TU flag assertion over an almost-empty database passes vacuously."
            % (len(db), MIN_TUS))
        return db, problems, {}

    missing_fp, missing_o, forbidden_hits = [], [], []
    o_levels = collections.Counter()
    effective_levels = collections.Counter()
    for entry in db:
        toks = [t.strip('"') for t in tokens(entry)]
        src = entry.get("file", "?")
        if REQUIRED_FP not in toks:
            missing_fp.append(src)
        levels = [t for t in toks if re.fullmatch(r"-O[0-9sgz]", t)]
        # THE LAST -O ON THE COMMAND LINE WINS. This is not pedantry: meson's default buildtype
        # sets debug=true, and oolite's meson.build then appends -O0 AFTER the -O2 that
        # `optimization=2` supplies, so a naive "is -O2 somewhere on the line" test passes on a
        # build that actually compiles at -O0. Assert the EFFECTIVE level.
        effective = levels[-1] if levels else None
        for lv in levels:
            o_levels[lv] += 1
        effective_levels[effective] += 1
        if effective != PINNED_O:
            missing_o.append("%s (effective %r, all %r)" % (src, effective, levels))
        for bad in FORBIDDEN:
            if bad in toks:
                forbidden_hits.append("%s carries %s" % (src, bad))

    if missing_fp:
        problems.append(
            "%d of %d translation units do NOT carry %s (first: %s). Without it clang may fuse "
            "a*b+c into a single FMA, which rounds once instead of twice and changes the low "
            "bits of every float in the dump - exactly the cross-platform variation the golden "
            "policy exists to remove."
            % (len(missing_fp), len(db), REQUIRED_FP, missing_fp[0]))
    if missing_o:
        problems.append(
            "%d of %d translation units do NOT compile at the pinned %s (first: %s). The EFFECTIVE "
            "level is the LAST -O on the line, so a build that appends -O0 after -O2 compiles at "
            "-O0 no matter what the first flag says. A golden blessed at one optimisation level "
            "is not comparable to a run at another. Effective levels seen: %r"
            % (len(missing_o), len(db), PINNED_O, missing_o[0], dict(effective_levels)))
    if forbidden_hits:
        problems.append(
            "%d translation unit(s) carry a flag that voids the policy: %s"
            % (len(forbidden_hits), "; ".join(forbidden_hits[:5])))

    return db, problems, dict(effective_levels)


def configure(source_dir, build_dir):
    env = dict(os.environ)
    # mk.sh / get_version.sh branches on MINGW_PREFIX; unset, its fallback uses `ps -o`, which
    # MSYS2's ps does not have, and every configure is rejected with two EMPTY diagnostic values.
    env.setdefault("MINGW_PREFIX", "/ucrt64")
    env.setdefault("MSYSTEM", "UCRT64")
    cmd = ["meson", "setup", build_dir, source_dir]
    proc = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout[-4000:])
        sys.stderr.write(proc.stderr[-4000:])
        raise SystemExit("meson setup failed (rc=%d) for %s" % (proc.returncode, source_dir))


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--build-dir", default=None)
    parser.add_argument("--configure-from", default=None,
                        help="meson source dir to configure into --build-dir first")
    args = parser.parse_args(argv)

    build_dir = args.build_dir
    if args.configure_from:
        if not build_dir:
            raise SystemExit("--configure-from needs --build-dir")
        configure(args.configure_from, build_dir)
    if not build_dir:
        raise SystemExit("pass --build-dir")

    db_path = os.path.join(build_dir, "compile_commands.json")
    if not os.path.isfile(db_path):
        raise SystemExit("no compile_commands.json under %s; configure the build first" % build_dir)

    db, problems, o_levels = check_db(db_path)
    if problems:
        sys.stderr.write("FAIL: the configured build does not honour the golden flag policy:\n")
        for p in problems:
            sys.stderr.write("  - %s\n" % p)
        return 1
    print("PASS: %d/%d translation units carry %s and compile at the pinned %s (effective, i.e. "
          "last -O on the line); no contraction-enabling flag present. Effective -O levels: %s"
          % (len(db), len(db), REQUIRED_FP, PINNED_O, o_levels))
    return 0


if __name__ == "__main__":
    sys.exit(main())
