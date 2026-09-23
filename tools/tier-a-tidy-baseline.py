#!/usr/bin/env python3
"""Baseline-relative clang-tidy verdict for tools/tier-a.sh step 2 (beads oo-utqt, oo-3rb.60).

    python tools/tier-a-tidy-baseline.py <source> <baseline-copy> <tidy-output> <repo-root> <base-ref>

<baseline-copy> is <source> as it was at the merge base (empty for a new file). A finding is
pre-existing when the text of the line it points at (whitespace-trimmed) also occurs in the
baseline copy OF THE FILE THE FINDING NAMES: the change under test did not write that line. Any
finding on a line the change wrote or edited is new and fails. Exit 0 = only pre-existing
findings, 1 = at least one new finding, 2 = the tidy output held no parseable finding (so a crash
is never read as a pass) or the arguments are wrong.

Findings are keyed by (path, line), never by line alone (bead oo-3rb.60). Some checks report in
a header even under -header-filter='$^' (misc-header-include-cycle reports at the #include inside
the header), and judging "OOLogging.h:31" against line 31 of the .mm under test reported a
pre-existing header finding as new whenever the change happened to edit that .mm line -- and,
symmetrically, could have hidden a new header finding behind an unchanged .mm line. So:

  * a finding in <source> is judged against <baseline-copy>, as before;
  * a finding in another file inside <repo-root> is judged against THAT file's current text and
    its own copy at <base-ref> (`git show <base-ref>:<rel>`; absent there = new file = empty
    baseline, so every finding in it is new);
  * a finding in a file outside <repo-root> (a system or toolchain header) is on no line this
    change can have written, so it is pre-existing.
"""
import os
import re
import subprocess
import sys
from collections import Counter

FINDING = re.compile(r"^(?P<path>.+?):(?P<line>\d+):(?P<col>\d+): (?:error|warning): (?P<msg>.*?) \[(?P<check>[^\]]+)\]\s*$")


def norm(s):
    return " ".join(s.split())


def key(path):
    """Comparable form of a path as clang-tidy or the caller spells it (C:/x vs C:\\x vs c:/x)."""
    return os.path.normcase(os.path.abspath(path))


def read_lines(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def git_baseline(root, base, rel):
    """Lines of <rel> at <base>, or [] when it did not exist there. None = git itself failed."""
    exists = subprocess.run(["git", "-C", root, "cat-file", "-e", f"{base}:{rel}"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if exists.returncode != 0:
        return []
    shown = subprocess.run(["git", "-C", root, "show", f"{base}:{rel}"], capture_output=True)
    if shown.returncode != 0:
        return None
    return shown.stdout.decode("utf-8", errors="replace").splitlines()


class Files:
    """(current lines, baseline line counter) per file a finding names, loaded once each."""

    OUTSIDE = "outside"

    def __init__(self, source, baseline, root, base):
        self.root, self.base = root, base
        self.cache = {key(source): (read_lines(source), Counter(norm(l) for l in read_lines(baseline)))}

    def get(self, path):
        k = key(path)
        if k not in self.cache:
            rel = os.path.relpath(k, key(self.root))
            if rel == os.pardir or rel.startswith(os.pardir + os.sep) or os.path.isabs(rel):
                self.cache[k] = self.OUTSIDE
            else:
                base_lines = git_baseline(self.root, self.base, rel.replace(os.sep, "/"))
                if base_lines is None:
                    raise RuntimeError(f"cannot read {rel} at {self.base}")
                try:
                    lines = read_lines(k)
                except OSError:
                    lines = []
                self.cache[k] = (lines, Counter(norm(l) for l in base_lines))
        return self.cache[k]


def main(argv):
    if len(argv) != 6:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    source, baseline, tidy_out, root, base = argv[1:6]
    out = read_lines(tidy_out)

    findings = [m for m in map(FINDING.match, out) if m]
    if not findings:
        print("tier-a: clang-tidy failed without a parseable finding", file=sys.stderr)
        return 2
    files = Files(source, baseline, root, base)
    new, old, outside = [], 0, 0
    for m in findings:
        try:
            entry = files.get(m["path"])
        except RuntimeError as e:
            print(f"tier-a: {e}", file=sys.stderr)
            return 2
        if entry is Files.OUTSIDE:
            outside += 1
            continue
        lines, base_lines = entry
        n = int(m["line"])
        text = norm(lines[n - 1]) if 0 < n <= len(lines) else None
        if text is not None and base_lines[text] > 0:
            old += 1
        else:
            new.append(m.group(0))
    print(f"    clang-tidy: {old} pre-existing finding(s) on unchanged lines, "
          f"{outside} outside the repo, {len(new)} new")
    for n in new:
        print(f"    NEW {n}", file=sys.stderr)
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
