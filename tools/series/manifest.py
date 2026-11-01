"""The series manifest: load, save, and the file-only validation rules of data-model.md.

Rules that need the repository (2, 3, 7, 8, 10) are checked by `series.py check`.
"""
import json
import re

ROOT_BRANCH = "series/000-upstream-base"
BRANCH_RE = re.compile(r"^series/(\d{3})-[a-z0-9]+(?:-[a-z0-9]+)*$")
BOOKKEEPING_RE = re.compile(r"ADR-[0-9]{4}|\boo-[0-9a-z]{3,}\b")
KINDS = ("independent", "hand-written", "mechanical", "reconcile")


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save(path, m):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(m, f, indent=1, sort_keys=True, ensure_ascii=False)
        f.write("\n")


def validate(m, order=None):
    """Return a list of violations, each starting with 'rule N:'. `order` maps commit -> inventory index."""
    out = []
    steps = m.get("steps", [])

    # rule 1: n contiguous from 1; branch series/NNN-slug with NNN = n; parents chain
    for i, s in enumerate(steps):
        n = s.get("n")
        if n != i + 1:
            out.append(f"rule 1: step at position {i + 1} has n={n}")
        mt = BRANCH_RE.match(s.get("branch") or "")
        if not mt:
            out.append(f"rule 1: step {n} branch {s.get('branch')!r} is not series/NNN-slug")
        elif int(mt.group(1)) != n:
            out.append(f"rule 1: step {n} branch {s['branch']} does not carry its number")
        want = ROOT_BRANCH if i == 0 else steps[i - 1].get("branch")
        if s.get("parent") != want:
            out.append(f"rule 1: step {n} parent {s.get('parent')!r}, expected {want!r}")
        if s.get("kind") not in KINDS:
            out.append(f"rule 1: step {n} kind {s.get('kind')!r} not one of {KINDS}")

    # rule 4: chapter iff source is history; chapters contiguous; mechanical_command iff mechanical
    prev_last = None
    for s in steps:
        n = s.get("n")
        is_hist = (s.get("source") or {}).get("type") == "history"
        ch = s.get("chapter")
        if is_hist and not ch:
            out.append(f"rule 4: step {n} comes from history but has no chapter")
        if not is_hist and ch:
            out.append(f"rule 4: step {n} is not from history but has a chapter")
        if is_hist and ch and order is not None:
            first, last = order.get(ch.get("first")), order.get(ch.get("last"))
            if first is None or last is None:
                out.append(f"rule 4: step {n} chapter boundaries not in the inventory")
            else:
                if last < first:
                    out.append(f"rule 4: step {n} chapter ends before it starts")
                if prev_last is not None and first != prev_last + 1:
                    out.append(f"rule 4: step {n} chapter starts at {first}, expected {prev_last + 1}")
                prev_last = last
        mech = s.get("kind") == "mechanical"
        if mech and not s.get("mechanical_command"):
            out.append(f"rule 4: step {n} is mechanical but has no mechanical_command")
        if not mech and s.get("mechanical_command"):
            out.append(f"rule 4: step {n} has a mechanical_command but is {s.get('kind')}")

    # rule 5: independent steps come before all non-independent steps
    seen_other = False
    for s in steps:
        if s.get("kind") == "independent":
            if seen_other:
                out.append(f"rule 5: independent step {s.get('n')} comes after a non-independent step")
        else:
            seen_other = True

    # rule 6: the temporary-code ledger balances
    for e in m.get("ledger", []):
        a, r = e.get("added_in"), e.get("removed_in")
        if r is None:
            out.append(f"rule 6: temporary {e.get('id')!r} added in {a} is never removed")
        elif a is None or r <= a:
            out.append(f"rule 6: temporary {e.get('id')!r} removed in {r}, not after it is added in {a}")

    # rule 9: no bookkeeping ids in titles
    for s in steps:
        if BOOKKEEPING_RE.search(s.get("title") or ""):
            out.append(f"rule 9: step {s.get('n')} title carries a bead id or ADR number")
    return out
