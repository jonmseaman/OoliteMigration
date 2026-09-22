#!/usr/bin/env python3
"""Baseline-relative clang-tidy verdict for tools/tier-a.sh step 2 (bead oo-utqt).

    python tools/tier-a-tidy-baseline.py <source> <baseline-copy> <tidy-output>

<baseline-copy> is the file as it was at the merge base (empty for a new file). A finding is
pre-existing when the text of the line it points at (whitespace-trimmed) also occurs in the
baseline copy: the change under test did not write that line. Any finding on a line the change
wrote or edited is new and fails. Exit 0 = only pre-existing findings, 1 = at least one new
finding, 2 = the tidy output held no parseable finding (so a crash is never read as a pass).
"""
import re
import sys
from collections import Counter

FINDING = re.compile(r"^(?P<path>.+?):(?P<line>\d+):(?P<col>\d+): (?:error|warning): (?P<msg>.*?) \[(?P<check>[^\]]+)\]\s*$")


def norm(s):
    return " ".join(s.split())


def main(argv):
    source, baseline, tidy_out = argv[1:4]
    with open(source, encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
    with open(baseline, encoding="utf-8", errors="replace") as f:
        base_lines = Counter(norm(l) for l in f.read().splitlines())
    with open(tidy_out, encoding="utf-8", errors="replace") as f:
        out = f.read().splitlines()

    findings = [m for m in map(FINDING.match, out) if m]
    if not findings:
        print("tier-a: clang-tidy failed without a parseable finding", file=sys.stderr)
        return 2
    new, old = [], 0
    for m in findings:
        n = int(m["line"])
        text = norm(lines[n - 1]) if 0 < n <= len(lines) else None
        if text is not None and base_lines[text] > 0:
            old += 1
        else:
            new.append(m.group(0))
    print(f"    clang-tidy: {old} pre-existing finding(s) on unchanged lines, {len(new)} new")
    for n in new:
        print(f"    NEW {n}", file=sys.stderr)
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
