"""The seriesb manifest's rules (specs/002-seriesb-rebase-stack/data-model.md).

`validate(m)` checks the file alone; `check(repo, m, groups, baseline)` checks the manifest against
the repository: rules 1-7 of data-model.md, grouped as `series.py --series seriesb check --only`
selects them. Every problem starts with "rule N:".
"""
import fnmatch
import re
import subprocess

from tools.series import manifest as manifest_mod
from tools.series import profile

PARENT_RE = re.compile(r"^seriesb/000[a-z]-[a-z0-9]+(?:-[a-z0-9]+)*$")
STEP_RE = profile.step_branch_re("seriesb/")
PARENT_KINDS = ("upstream", "fix-parent", "upstream-master")
GATE_OK = ("pass", "waived")
GROUPS = ("manifest", "branches", "lineage", "baseline", "gates", "differs", "tests", "messages", "final-tree",
          "verified")
# a bead id or an ADR number (spec FR-013)
MESSAGE_RE = re.compile(r"\boo-[a-z0-9]{3,}\b|\bADR-?\d+")


def _git(repo, *args, ok=(0,)):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, encoding="utf-8")
    if r.returncode not in ok:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()[-400:]}")
    return r


def _out(repo, *args):
    return _git(repo, *args).stdout.strip()


def _sha(repo, ref):
    r = _git(repo, "rev-parse", "-q", "--verify", f"{ref}^{{commit}}", ok=(0, 1, 128))
    return r.stdout.strip() if r.returncode == 0 else None


def _ancestor(repo, a, b):
    return _git(repo, "merge-base", "--is-ancestor", a, b, ok=(0, 1)).returncode == 0


def live_parents(m):
    return profile.live_parents(m)


def root(m):
    live = live_parents(m)
    return live[-1]["branch"] if live else profile.SERIESB_DEFAULT_ROOT


def expected_parent(m, i):
    """The Git Town parent the i-th live parent should have: develop, the previous parent, or none."""
    live = live_parents(m)
    p = live[i]
    if p.get("kind") == "upstream-master":
        return None  # a perennial branch has no parent
    return "develop" if i == 0 else live[i - 1]["branch"]


# --- the file alone --------------------------------------------------------------------------------

def validate(m):
    out = []
    live = live_parents(m)
    for p in m.get("parents", []):
        b, kind = p.get("branch") or "", p.get("kind")
        if not PARENT_RE.match(b):
            out.append(f"rule 1: parent {b!r} is not seriesb/000x-slug")
        if kind not in PARENT_KINDS:
            out.append(f"rule 1: parent {b} kind {kind!r} not one of {PARENT_KINDS}")
        if kind == "upstream":
            for k in ("upstream_pr", "tracking", "head"):
                if not p.get(k):
                    out.append(f"rule 1: upstream parent {b} has no {k}")
        if kind == "fix-parent" and not str(p.get("decision") or "").strip():
            out.append(f"rule 1: fix parent {b} has no decision (the Notes entry naming Jon's choice, FR-003a)")
        if (kind == "upstream-master") != b.startswith("seriesb/000m-"):
            out.append(f"rule 1: parent {b}: seriesb/000m- is reserved for the upstream-master parent, and it for 000m")
    for i, p in enumerate(live):
        if p.get("kind") != "upstream-master" and p.get("parent") != expected_parent(m, i):
            out.append(f"rule 1: parent {p['branch']} has parent {p.get('parent')!r}, expected {expected_parent(m, i)!r}")
    steps = m.get("steps", [])
    last_old = 0
    for i, s in enumerate(steps):
        n = s.get("n")
        if n != i + 1:
            out.append(f"rule 1: step at position {i + 1} has n={n}")
        mt = STEP_RE.match(s.get("branch") or "")
        if not mt:
            out.append(f"rule 1: step {n} branch {s.get('branch')!r} is not seriesb/NNN-slug")
        elif int(mt.group(1)) != n:
            out.append(f"rule 1: step {n} branch {s['branch']} does not carry its number")
        want = root(m) if i == 0 else steps[i - 1].get("branch")
        if s.get("parent") != want:
            out.append(f"rule 1: step {n} parent {s.get('parent')!r}, expected {want!r}")
        if s.get("kind") not in manifest_mod.KINDS:
            out.append(f"rule 1: step {n} kind {s.get('kind')!r} not one of {manifest_mod.KINDS}")
        if (s.get("kind") == "mechanical") != bool(s.get("mechanical_command")):
            out.append(f"rule 1: step {n}: a mechanical step, and only one, has a mechanical_command")
        src = s.get("source") or {}
        if src.get("type") != "replay":
            out.append(f"rule 1: step {n} source is {src.get('type')!r}, not replay")
        old = src.get("old_step")
        if not isinstance(old, int) or old <= last_old:
            out.append(f"rule 1: step {n} old_step {old!r} does not increase (after {last_old})")
        else:
            last_old = old
        if manifest_mod.BOOKKEEPING_RE.search(s.get("title") or ""):
            out.append(f"rule 1: step {n} title carries a bead id or ADR number")
    for f in m.get("folded", []):
        if not f.get("old_steps") or not f.get("into_old_step") or not str(f.get("reason") or "").strip():
            out.append(f"rule 1: folded entry {f.get('old_steps')!r} -> {f.get('into_old_step')!r} lacks old steps, "
                       "a target or a reason")
    for d in m.get("dropped", []):
        missing = [k for k in ("old_step", "old_branch", "reason", "covered_by") if not d.get(k)]
        if missing:
            out.append(f"rule 1: dropped entry {d.get('old_branch') or d.get('old_step')!r} lacks {', '.join(missing)}")
    return out


# --- the repository -------------------------------------------------------------------------------

def _town(repo, branch, key):
    r = _git(repo, "config", "--get", f"git-town-branch.{branch}.{key}", ok=(0, 1))
    return r.stdout.strip() or None


def _perennials(repo):
    r = _git(repo, "config", "--get-all", "git-town.perennial-branches", ok=(0, 1))
    return set(r.stdout.split())


def check_lineage(repo, m, wanted):
    out = []
    live = live_parents(m)
    for i, p in enumerate(live):
        b = p["branch"]
        if not _sha(repo, f"refs/heads/{b}"):
            out.append(f"rule 1: parent branch {b} does not exist")
            continue
        want = expected_parent(m, i)
        if p.get("kind") == "upstream-master":
            if b not in _perennials(repo):
                out.append(f"rule 1: {b} is not a Git Town perennial branch")
            continue
        if _town(repo, b, "parent") != want:
            out.append(f"rule 1: {b} Git Town parent is {_town(repo, b, 'parent')!r}, expected {want!r}")
        want_type = "observed" if p.get("kind") == "upstream" else "prototype"
        if _town(repo, b, "branchtype") != want_type:
            out.append(f"rule 1: {b} Git Town type is {_town(repo, b, 'branchtype')!r}, expected {want_type}")
    for s in m.get("steps", []):
        if s["n"] not in wanted:
            continue
        b = s["branch"]
        if not _sha(repo, f"refs/heads/{b}"):
            out.append(f"rule 1: step {s['n']} branch {b} does not exist")
            continue
        if _town(repo, b, "parent") != s["parent"]:
            out.append(f"rule 1: step {s['n']} Git Town parent is {_town(repo, b, 'parent')!r}, expected {s['parent']!r}")
        if _town(repo, b, "branchtype") != "prototype":
            out.append(f"rule 1: step {s['n']} Git Town type is {_town(repo, b, 'branchtype')!r}, expected prototype")
    return out


def check_branches(repo, m, wanted):
    """Rules 2 (parents mirror their PRs), 3 (steps descend from their parents; later commits are
    sync merges) and 4 (no develop commit in any seriesb branch)."""
    out = []
    for p in live_parents(m):
        if p.get("kind") != "upstream":
            continue
        b = p["branch"]
        tip, track = _sha(repo, f"refs/heads/{b}"), _sha(repo, f"refs/remotes/{p['tracking']}")
        if tip is None:
            continue  # rule 1 reports it
        if track is None:
            out.append(f"rule 2: parent {b} has no tracking ref refs/remotes/{p['tracking']}")
        elif tip != track:
            out.append(f"rule 2: parent {b} is at {tip[:10]}, its PR at {track[:10]}: run `parents --refresh`")
        if p.get("head") and tip != _sha(repo, p["head"]):
            out.append(f"rule 2: parent {b} is at {tip[:10]}, the manifest records {p['head'][:10]}")
    for s in m.get("steps", []):
        if s["n"] not in wanted:
            continue
        tip, ptip = _sha(repo, f"refs/heads/{s['branch']}"), _sha(repo, f"refs/heads/{s['parent']}")
        if tip is None or ptip is None:
            continue
        n = s["n"]
        if not _ancestor(repo, ptip, tip):
            out.append(f"rule 3: step {n} does not contain its parent {s['parent']}'s tip")
        bc = s.get("build_commit")
        if not bc or not _sha(repo, bc) or not _ancestor(repo, bc, tip):
            out.append(f"rule 3: step {n} does not contain its build commit {str(bc)[:10]}")
            continue
        own = _out(repo, "rev-list", "--parents", tip, f"^{bc}", f"^{ptip}").splitlines()
        for line in own:
            c, *parents = line.split()
            if len(parents) != 2 or not _ancestor(repo, parents[1], ptip):
                out.append(f"rule 3: step {n} commit {c[:10]} after its build is not a sync merge from {s['parent']}")
    out += check_develop_leak(repo, m, wanted)
    return out


def check_develop_leak(repo, m, wanted):
    a = m["anchors"]
    develop = a.get("develop_target")
    base = a.get("upstream_master")
    own_develop = set(_out(repo, "rev-list", develop, f"^{base}").split())
    out = []
    branches = [p["branch"] for p in live_parents(m)] + [s["branch"] for s in m.get("steps", []) if s["n"] in wanted]
    for b in branches:
        if not _sha(repo, f"refs/heads/{b}"):
            continue
        leaked = own_develop & set(_out(repo, "rev-list", b, f"^{base}").split())
        if leaked:
            out.append(f"rule 4: {b} contains {len(leaked)} develop commit(s), e.g. {sorted(leaked)[0][:10]}")
    return out


def check_baseline(repo, baseline):
    out = []
    for b, sha in sorted((baseline or {}).get("branches", {}).items()):
        now = _sha(repo, f"refs/heads/{b}")
        if now != sha:
            out.append(f"rule 5: {b} is at {str(now)[:10]}, the baseline records {sha[:10]}")
    return out


def _globs(m):
    return [e["path_glob"] for e in m.get("exclusions", []) + m.get("additions", []) if e.get("path_glob")]


def check_final_tree(repo, m):
    from tools.series import trees
    out = [f"rule 6: {what} {e.get('path_glob') or e.get('revert_commit')!r} has no reason"
           for what, lst in (("exclusion", m.get("exclusions", [])), ("addition", m.get("additions", [])))
           for e in lst if not str(e.get("reason") or "").strip()]
    steps = m.get("steps", [])
    if not steps or not _sha(repo, f"refs/heads/{steps[-1]['branch']}"):
        return out
    target = _out(repo, "rev-parse", f"{m['anchors']['develop_target']}^{{tree}}")
    for e in m.get("exclusions", []):
        if e.get("revert_commit"):
            target = trees.revert(repo, target, e["revert_commit"])
    tip = _out(repo, "rev-parse", f"refs/heads/{steps[-1]['branch']}^{{tree}}")
    globs = _globs(m)
    # paths upstream's PRs changed after the stack was built (recorded by sync-record) differ by
    # design: develop does not have upstream's newer work
    upstream = {p for s in m.get("syncs", []) for p in s.get("upstream_paths", [])}
    diff = [p for p in _out(repo, "diff", "--name-only", "--no-renames", tip, target).splitlines()
            if not any(fnmatch.fnmatchcase(p, g) for g in globs) and p not in upstream]
    out += [f"rule 6: the last step differs from develop at {p}" for p in diff[:20]]
    if len(diff) > 20:
        out.append(f"rule 6: ... and {len(diff) - 20} more paths")
    return out


def check_gates(m):
    return [f"rule 7: parent {p['branch']} gate is {p.get('gate')!r}" + (f": {p['flag']}" if p.get("flag") else "")
            for p in live_parents(m) if p.get("gate") not in GATE_OK]


def record_passes(v):
    checks = (v or {}).get("checks") or {}
    return bool(checks) and all(str(r).startswith(("pass", "n/a")) for r in checks.values())


def check_verified(repo, m, wanted):
    out = check_gates(m)
    syncs = len(m.get("syncs", []))
    for s in m.get("steps", []):
        if s["n"] not in wanted:
            continue
        v = s.get("verification")
        if not record_passes(v):
            out.append(f"rule 7: step {s['n']} is not verified")
            continue
        tip = _sha(repo, f"refs/heads/{s['branch']}")
        if v.get("commit") != tip:
            out.append(f"rule 7: step {s['n']}'s verification is for {str(v.get('commit'))[:10]}, the branch is at {str(tip)[:10]}")
        if v.get("after_sync", -1) < syncs:
            out.append(f"rule 7: step {s['n']}'s verification is older than sync {syncs} (re-verify after a sync)")
    return out


def check_differs(m, wanted):
    """SC-006: every path where a step's change differs from its old step's has a reason."""
    out = []
    for s in m.get("steps", []):
        if s["n"] not in wanted or not s.get("target_tree"):
            continue
        if s.get("differs_from_old") is None:
            out.append(f"rule 1: step {s['n']} has a tree but no differs_from_old (run `tree {s['n']}`)")
            continue
        for d in s["differs_from_old"]:
            if not str(d.get("reason") or "").strip():
                out.append(f"rule 1: step {s['n']} differs from {s['source']['old_branch']} at {d['path']} with no reason")
    return out


def _name_status(repo, a, b, path):
    """{path: (status, after blob)} between trees a and b under `path`."""
    out = {}
    for line in _out(repo, "diff", "--name-status", "--no-renames", a, b, "--", path).splitlines():
        status, p = line.split("\t", 1)
        out[p] = (status, _sha(repo, f"{b}:{p}") if status != "D" else None)
    return out


def check_tests(repo, m, wanted):
    """Hard rule 1: a step modifies or deletes an existing test only where its old step did the same
    (same resulting text, or deleted in both)."""
    out = []
    for s in m.get("steps", []):
        if s["n"] not in wanted or not _sha(repo, f"refs/heads/{s['branch']}"):
            continue
        tree = _out(repo, "rev-parse", f"refs/heads/{s['branch']}^{{tree}}")
        parent = _out(repo, "rev-parse", f"refs/heads/{s['parent']}^{{tree}}")
        old = s["source"]["old_commit"]
        first = s["source"].get("old_from_commit") or old
        old_changes = _name_status(repo, _out(repo, "rev-parse", f"{first}~1^{{tree}}"),
                                   _out(repo, "rev-parse", f"{old}^{{tree}}"), "tests/")
        for p, (status, after) in _name_status(repo, parent, tree, "tests/").items():
            if status == "A":
                continue
            o = old_changes.get(p)
            if o is None or o[0] == "A" or o[1] != after:
                what = "deletes" if status == "D" else "modifies"
                out.append(f"rule 1: step {s['n']} {what} the existing test {p}, which {s['source']['old_branch']} does not")
    return out


def check_messages(repo, m, wanted):
    """Spec FR-013: no bead id or ADR number in a step's own commits (those not in its parent)."""
    out = []
    for s in m.get("steps", []):
        if s["n"] not in wanted or not _sha(repo, f"refs/heads/{s['branch']}"):
            continue
        log = _out(repo, "log", "--format=%H%x00%B%x01", s["branch"], f"^{s['parent']}")
        for entry in log.split("\x01"):
            if not entry.strip():
                continue
            c, _, body = entry.strip().partition("\x00")
            hit = MESSAGE_RE.search(body)
            if hit:
                out.append(f"rule 1: step {s['n']} commit {c[:10]} message carries {hit.group(0)!r}")
    return out


def check(repo, m, groups, baseline=None, wanted=None):
    wanted = wanted if wanted is not None else {s["n"] for s in m.get("steps", [])}
    out = []
    if "manifest" in groups:
        out += validate(m)
    if "lineage" in groups:
        out += check_lineage(repo, m, wanted)
    if "branches" in groups:
        out += check_branches(repo, m, wanted)
    if "baseline" in groups:
        out += check_baseline(repo, baseline)
    if "differs" in groups:
        out += check_differs(m, wanted)
    if "tests" in groups:
        out += check_tests(repo, m, wanted)
    if "messages" in groups:
        out += check_messages(repo, m, wanted)
    if "final-tree" in groups:
        out += check_final_tree(repo, m)
    if "verified" in groups:
        out += check_verified(repo, m, wanted)
    elif "gates" in groups:
        out += check_gates(m)
    return out
