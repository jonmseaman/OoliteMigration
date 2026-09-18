"""Store a dump as the blessed golden for a platform + scenario, with provenance.

LAYOUT (decision 11):

    goldens/<platform>/<scenario>/state.json        the canonical dump
    goldens/<platform>/<scenario>/provenance.json   what produced it

`<platform>` is windows-x64 today; macos-arm64 and linux-x64 join at Phase 5
(docs/decisions/0009, docs/phases/5-apple-silicon.md). The platform is a DIRECTORY, not a suffix,
because the Phase 5 question is "does this platform agree with its own blessed golden", and a
per-platform directory makes a missing platform obvious (the directory is absent) instead of
silently comparing against another platform's numbers.

The provenance file is not decoration. A golden without provenance cannot be judged: nobody can
tell whether a disagreement means the code changed or the build flags did. It records the
quantisation, the pinned flags, the compiler and the commit - and golden_diff.py REFUSES to
compare against a golden whose recorded quantisation is off policy.

Blessing is deliberately a separate, explicit command. Nothing in the test tier re-blesses
automatically: a golden that updates itself when it fails is not a golden.
"""

import argparse
import json
import os
import platform as platform_mod
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

sys.path.insert(0, HERE)
from golden_diff import POLICY_QUANT_DECIMALS, assert_non_vacuous, load  # noqa: E402

REQUIRED_FP = "-ffp-contract=off"
PINNED_O = "-O2"


def detect_platform():
    """The platform key. Deliberately coarse: os + machine architecture, nothing else.

    Not the compiler version and not the OS build number - those go in provenance, where they
    inform a reader, rather than in the key, where they would fragment the golden set every time
    a toolchain updated and quietly leave every platform without a golden to compare against.
    """
    system = {"Windows": "windows", "Darwin": "macos", "Linux": "linux"}.get(
        platform_mod.system(), platform_mod.system().lower())
    machine = {"AMD64": "x64", "x86_64": "x64", "arm64": "arm64", "aarch64": "arm64"}.get(
        platform_mod.machine(), platform_mod.machine().lower())
    return "%s-%s" % (system, machine)


def git(*args):
    try:
        return subprocess.run(["git", "-C", REPO_ROOT.replace("\\", "/")] + list(args),
                              capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        return None


def compiler_version():
    for exe in ("clang", "cc"):
        try:
            out = subprocess.run([exe, "--version"], capture_output=True, text=True, check=True)
            return out.stdout.splitlines()[0].strip()
        except Exception:
            continue
    return None


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("dump", help="a canonical dump produced at the POLICY quantisation")
    parser.add_argument("--scenario", required=True, help="e.g. 001")
    parser.add_argument("--platform", default=None, help="default: detected from this host")
    parser.add_argument("--goldens-root", default=os.path.join(REPO_ROOT, "goldens"))
    parser.add_argument("--note", default="")
    parser.add_argument("--force", action="store_true",
                        help="overwrite an EXISTING golden value. Refused without this flag: "
                             "silently re-blessing a golden that a run disagreed with is how a "
                             "golden suite stops being evidence.")
    args = parser.parse_args(argv)

    data = load(args.dump)
    assert_non_vacuous(data, args.dump)

    plat = args.platform or detect_platform()
    target = os.path.join(args.goldens_root, plat, args.scenario)
    state = os.path.join(target, "state.json")

    if os.path.exists(state) and not args.force:
        raise SystemExit(
            "REFUSING to overwrite the existing golden %s. A golden that disagrees with a fresh "
            "run is a FINDING to investigate and report, not a file to rewrite. If a re-bless is "
            "genuinely correct (the behaviour changed on purpose), pass --force and record why "
            "in the commit message." % state)

    os.makedirs(target, exist_ok=True)
    text = json.dumps(data, sort_keys=True, separators=(",", ":"))
    with open(state, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text + "\n")

    provenance = {
        "scenario": args.scenario,
        "platform": plat,
        "quant_decimals": POLICY_QUANT_DECIMALS,
        "build_flags": {"fp_contract": REQUIRED_FP, "optimization": PINNED_O},
        "compiler": compiler_version(),
        "os": platform_mod.platform(),
        "commit": git("rev-parse", "HEAD"),
        "dump_tool": "tests/golden/dump/run_dump.py",
        "note": args.note,
    }
    with open(os.path.join(target, "provenance.json"), "w", encoding="utf-8",
              newline="\n") as handle:
        json.dump(provenance, handle, indent=2, sort_keys=True)
        handle.write("\n")

    print("blessed %s (%d bytes) + provenance.json" % (state, len(text) + 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
