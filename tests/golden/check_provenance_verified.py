"""oo-5ggu: assert the STORED provenance records a VERIFIED compliant build.

Separate from test_golden_storage.py on purpose: this is the acceptance gate's own assertion and
it must be runnable as a bare command with a readable failure, not buried in a pytest summary.

It asserts what a re-bless against a compliant build DOES, not what the policy wishes for:

  * verified is exactly True (not truthy, not "true")
  * detail is the checker's own compliant verdict, so a hand-written "looks fine" cannot pass
  * translation_units is above check_build_flags' own vacuity floor, so "0 of 0 TUs are
    non-compliant" cannot satisfy it
  * EVERY effective -O level recorded is the pinned one, and they account for every TU
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import check_build_flags as cbf  # noqa: E402
import golden_diff as gd  # noqa: E402


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    scenario = argv[0] if argv else "001"
    platform = argv[1] if len(argv) > 1 else "windows-x64"
    path = os.path.join(REPO_ROOT, "goldens", platform, scenario, "provenance.json")
    if not os.path.isfile(path):
        sys.stderr.write("no provenance at %s\n" % path)
        return 1
    prov = json.load(open(path, encoding="utf-8"))
    flags = prov.get("build_flags", {})
    problems = []

    if prov.get("quant_decimals") != gd.POLICY_QUANT_DECIMALS:
        problems.append("quant_decimals is %r, policy is %d"
                        % (prov.get("quant_decimals"), gd.POLICY_QUANT_DECIMALS))
    if flags.get("policy_fp_contract") != cbf.REQUIRED_FP:
        problems.append("policy_fp_contract is %r" % flags.get("policy_fp_contract"))
    if flags.get("policy_optimization") != cbf.PINNED_O:
        problems.append("policy_optimization is %r" % flags.get("policy_optimization"))

    if flags.get("verified") is not True:
        problems.append(
            "build_flags.verified is %r, not True. The golden was blessed from a build whose "
            "compile_commands.json did not satisfy the flag policy; detail: %r"
            % (flags.get("verified"), flags.get("detail")))
    if flags.get("detail") != "compliant":
        problems.append("build_flags.detail is %r, not the checker's 'compliant' verdict"
                        % (flags.get("detail"),))

    tus = flags.get("translation_units")
    if not isinstance(tus, int) or tus < cbf.MIN_TUS:
        problems.append(
            "translation_units is %r; below check_build_flags' %d vacuity floor, so 'every TU "
            "carries the flag' would be an almost-empty claim" % (tus, cbf.MIN_TUS))

    levels = flags.get("effective_optimization_levels")
    if not isinstance(levels, dict) or not levels:
        problems.append("effective_optimization_levels is %r" % (levels,))
    else:
        if set(levels) != {cbf.PINNED_O}:
            problems.append(
                "effective -O levels recorded are %r; the EFFECTIVE level is the LAST -O on the "
                "line, so anything other than {%r: n} means some TU really compiled elsewhere"
                % (levels, cbf.PINNED_O))
        elif isinstance(tus, int) and sum(levels.values()) != tus:
            problems.append("effective -O levels cover %d TUs but %d were checked"
                            % (sum(levels.values()), tus))

    if problems:
        sys.stderr.write("FAIL: %s does not record a verified compliant build:\n" % path)
        for p in problems:
            sys.stderr.write("  - %s\n" % p)
        return 1
    print("PASS: %s/%s provenance records a VERIFIED build: %d translation units, all carrying "
          "%s at effective %s, quantised to %d decimals"
          % (platform, scenario, tus, cbf.REQUIRED_FP, cbf.PINNED_O, prov["quant_decimals"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
