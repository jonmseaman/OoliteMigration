"""Compare two canonical dumps (or a fresh dump against a stored golden) and report field-level
differences by path, with both values.

WHY THIS IS NOT `diff`
----------------------
`diff -q` answers "are these two files the same bytes". That is a fine repeatability check and the
dump tier already uses it. It is NOT a golden comparison, for three reasons this tool addresses:

  1. A golden comparison must name the FIELD that moved, not the line number, because the reader is
     asking "what behaviour changed", not "what text changed".
  2. A zero-difference result is only meaningful if the things compared are non-trivial and really
     independent. `diff -q a a` is zero differences. Two empty files are zero differences. This
     tool refuses both (see --require-independent and the non-vacuity checks below).
  3. Quantisation is the mechanism that makes goldens portable, and quantisation is the easiest
     thing in the system to abuse: round to 0 decimals and every golden passes forever. This tool
     therefore reads the PROVENANCE beside a stored golden and REFUSES to compare at all if the
     recorded quantisation is not the policy value. Rounding harder is not a way to go green.

EXIT CODES
  0  no differences, and every guard was satisfied
  1  differences found (each printed as `path: <left> != <right>`)
  2  the comparison was REFUSED as unsound (vacuous, non-independent, or off-policy quantisation)

A refusal is deliberately a different code from a difference: "I cannot tell you" must never be
mistaken for "they match".
"""

import argparse
import json
import os
import sys

# The policy quantisation. This is duplicated from dump_state.js and check_canonical.py on
# purpose: the whole point of the guard is that it disagrees loudly if someone edits one of them.
POLICY_QUANT_DECIMALS = 3

# Non-vacuity floor. A dump of scenario 001 has 4 spawned ships, a full market and the player
# block; these numbers are well under that, so they catch "the dump collapsed" without pinning the
# scenario's exact content (which is the golden's job, not the diff tool's).
MIN_LEAF_FIELDS = 40
MIN_ENTITIES = 2


class Refusal(Exception):
    """The comparison cannot be trusted, so no verdict is given."""


def flatten(node, path="", out=None):
    """Flatten a dump to {json-path: scalar}. Entities are keyed by their id, not their index,
    so an inserted or removed ship reports as an added/removed entity rather than shifting every
    later index and drowning the real difference in noise."""
    if out is None:
        out = {}
    if isinstance(node, dict):
        for k in sorted(node):
            flatten(node[k], "%s.%s" % (path, k) if path else k, out)
    elif isinstance(node, list):
        keyed = all(isinstance(i, dict) and "id" in i for i in node) and bool(node)
        for i, item in enumerate(node):
            label = item["id"] if keyed else i
            flatten(item, "%s[%s]" % (path, label), out)
    else:
        out[path] = node
    return out


def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()
    if not text.strip():
        raise Refusal("%s is empty; an empty file compares equal to another empty file and that "
                      "is not evidence of anything" % path)
    try:
        return json.loads(text)
    except ValueError as exc:
        raise Refusal("%s is not valid JSON: %s" % (path, exc))


def assert_non_vacuous(data, path):
    leaves = flatten(data)
    if len(leaves) < MIN_LEAF_FIELDS:
        raise Refusal("%s has only %d leaf field(s), fewer than the %d a real scenario-001 dump "
                      "carries; comparing it would be vacuous"
                      % (path, len(leaves), MIN_LEAF_FIELDS))
    ents = data.get("entities")
    if not isinstance(ents, list) or len(ents) < MIN_ENTITIES:
        raise Refusal("%s has %r entities, fewer than the %d minimum; a dump with no world in it "
                      "compares equal to any other empty world"
                      % (path, len(ents) if isinstance(ents, list) else ents, MIN_ENTITIES))
    for required in ("entities", "market", "player"):
        if not data.get(required):
            raise Refusal("%s has no non-empty %r; it is not a world-state dump" % (path, required))
    return leaves


def check_quantisation(data, path, provenance=None):
    """Two independent guards against 'fix the golden by rounding harder'.

    (a) If a provenance file records the quantisation used, it must be the policy value.
    (b) Regardless of provenance, the DATA itself must still carry fractional detail: if every
        float in the dump is a whole number, quantisation has erased the signal even if the
        recorded decimals look right.
    """
    if provenance is not None:
        recorded = provenance.get("quant_decimals")
        if recorded is None:
            raise Refusal("%s: provenance records no quant_decimals; an unlabelled golden cannot "
                          "be checked against the quantisation policy" % path)
        if recorded != POLICY_QUANT_DECIMALS:
            raise Refusal(
                "%s: provenance records quant_decimals=%r but the policy is %d. REFUSING to "
                "compare. Coarsening quantisation makes every golden pass and is the standard "
                "way a golden suite rots into decoration; if the policy must change, change it "
                "in dump_state.js, re-bless every golden, and say why in "
                "tests/golden/GOLDEN_STORAGE.md."
                % (path, recorded, POLICY_QUANT_DECIMALS))

    floats = [v for v in flatten(data).values() if isinstance(v, float)]
    if not floats:
        raise Refusal("%s contains no float values at all; whatever produced it is not the "
                      "quantised dump this policy is about" % path)
    fractional = [f for f in floats if f != int(f)]
    if not fractional:
        raise Refusal(
            "%s: every one of its %d float values is a whole number. That is what a dump looks "
            "like after quantisation has been coarsened to uselessness (toFixed(0)); it would "
            "compare equal to almost any other run. REFUSING to compare." % (path, len(floats)))
    return len(floats), len(fractional)


def read_provenance(dump_path):
    """A stored golden carries provenance.json beside it; a scratch dump does not."""
    candidate = os.path.join(os.path.dirname(os.path.abspath(dump_path)), "provenance.json")
    if not os.path.isfile(candidate):
        return None
    with open(candidate, "r", encoding="utf-8") as handle:
        return json.load(handle)


def assert_independent(left, right):
    """Two runs that are the same file are not two runs.

    Checks both the path and the filesystem identity (st_dev, st_ino catches a hardlink or a
    symlink that points the two names at one file, which a string comparison misses).
    """
    a, b = os.path.abspath(left), os.path.abspath(right)
    if a == b:
        raise Refusal("both sides are the same path (%s); a file always equals itself, so this "
                      "comparison could never fail" % a)
    sa, sb = os.stat(a), os.stat(b)
    if (sa.st_dev, sa.st_ino) == (sb.st_dev, sb.st_ino) and sa.st_ino != 0:
        raise Refusal("%s and %s are the same file on disk (dev=%s ino=%s); a link is not a "
                      "second run" % (a, b, sa.st_dev, sa.st_ino))


def diff(left_data, right_data):
    la, ra = flatten(left_data), flatten(right_data)
    problems = []
    for key in sorted(set(la) | set(ra)):
        if key not in la:
            problems.append("%s: <absent> != %r" % (key, ra[key]))
        elif key not in ra:
            problems.append("%s: %r != <absent>" % (key, la[key]))
        elif la[key] != ra[key]:
            problems.append("%s: %r != %r" % (key, la[key], ra[key]))
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("left")
    parser.add_argument("right")
    parser.add_argument("--label-left", default=None)
    parser.add_argument("--label-right", default=None)
    parser.add_argument("--allow-same-file", action="store_true",
                        help="skip the independence guard (only for testing the tool itself)")
    args = parser.parse_args(argv)

    left_label = args.label_left or args.left
    right_label = args.label_right or args.right

    try:
        if not args.allow_same_file:
            assert_independent(args.left, args.right)
        left, right = load(args.left), load(args.right)
        ln = assert_non_vacuous(left, left_label)
        rn = assert_non_vacuous(right, right_label)
        lf = check_quantisation(left, left_label, read_provenance(args.left))
        rf = check_quantisation(right, right_label, read_provenance(args.right))
    except Refusal as exc:
        sys.stderr.write("REFUSED: %s\n" % exc)
        return 2

    problems = diff(left, right)
    if problems:
        sys.stderr.write("DIFFERENCES (%d) between %s and %s:\n"
                         % (len(problems), left_label, right_label))
        for p in problems:
            sys.stderr.write("  %s\n" % p)
        return 1

    print("MATCH: %s == %s (%d leaf fields compared, %d/%d floats fractional on the left, "
          "%d/%d on the right; quantisation %d decimals)"
          % (left_label, right_label, len(ln), lf[1], lf[0], rf[1], rf[0],
             POLICY_QUANT_DECIMALS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
