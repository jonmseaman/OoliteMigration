#!/usr/bin/env python3
"""Apply one named mutation to a COPY of the tree (cwd), for tests/fleet/prove_gate_lines.sh.

Each mutation breaks exactly the property one stored acceptance line protects.  Kept as a
separate file because embedding this in shell needs four levels of quoting and the fleet has
already lost a night to a mutation harness that never started.
"""

from __future__ import annotations

import glob
import json
import re
import sys

JSON_BLOCK = r"```json\n(.*?)\n```"


def _report():
    rs = sorted(glob.glob("docs/fleet/REPORT-*.md"))
    if not rs:
        sys.exit("no report to mutate in this copy")
    return rs[-1]


def _load():
    p = _report()
    t = open(p, encoding="utf-8").read()
    return p, t, json.loads(re.search(JSON_BLOCK, t, re.S).group(1))


def _save(p, t, payload):
    t = re.sub(JSON_BLOCK, "```json\n" + json.dumps(payload, indent=2) + "\n```", t, flags=re.S)
    open(p, "w", encoding="utf-8", newline="\n").write(t)


def drop_metric():
    p, t, pay = _load()
    v = pay["metrics"].pop(2)
    t = re.sub(rf"### {re.escape(v['id'])}\n.*?(?=\n### )", "", t, flags=re.S)
    _save(p, t, pay)
    print(f"mutated: dropped metric {v['id']}")


def drop_fork_figure():
    p, t, pay = _load()
    m = next(x for x in pay["metrics"] if x["id"].startswith("days-since-origin-main"))
    m["values"].pop("fork_migration_matched")
    _save(p, t, pay)
    print("mutated: removed fork_migration_matched")


def silent_zero():
    p, t, pay = _load()
    for m in pay["metrics"]:
        for k, v in list(m["values"].items()):
            if "not_computed" in v:
                t = re.sub(rf"`{re.escape(k)}` = NOT COMPUTED[^\n]*", f"`{k}` = 0", t)
                _save(p, t, pay)
                print(f"mutated: {m['id']}.{k} printed as 0 while the payload says NOT COMPUTED")
                return
    sys.exit("no NOT COMPUTED value to mutate")


def fake_count():
    p, t, pay = _load()
    a = next(m for m in pay["metrics"] if m["id"] == "proposed-adrs-awaiting-override")
    a["values"]["awaiting_override"]["value"] += 5
    _save(p, t, pay)
    print("mutated: inflated proposed-ADR count by 5")


def strip_write_guard():
    p = "tools/fleet_reporter.py"
    s = open(p, encoding="utf-8").read()
    s, n = re.subn(r"# BEGIN-ENFORCEMENT-WRITE.*?# END-ENFORCEMENT-WRITE",
                   "_WRITE_ENFORCED = False", s, flags=re.S)
    assert n == 1, f"expected one WRITE enforcement region, found {n}"
    open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("mutated: stripped the write enforcement from fleet_reporter.py")


MUTATIONS = {
    "drop-metric": drop_metric,
    "drop-fork-figure": drop_fork_figure,
    "silent-zero": silent_zero,
    "fake-count": fake_count,
    "strip-write-guard": strip_write_guard,
}

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in MUTATIONS:
        sys.exit(f"usage: mutate.py <{'|'.join(MUTATIONS)}>")
    MUTATIONS[sys.argv[1]]()
