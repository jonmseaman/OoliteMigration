"""The seriesb parents: local mirrors of upstream's QuickJS PRs (research R1, R2).

Each parent is a Git Town observed branch tracking its PR branch in the `hobleyd` remote. Git Town
observes a branch only if `<remote>/<local name>` exists, so the remote's fetch refspecs map each PR
branch onto the parent's own name. Git Town's sync fetches only `origin`, and its observed-branch
rebase replays upstream's dropped commits after a force-push, so `refresh` fetches `hobleyd` and
resets each parent to its tracking ref before every sync. Never pushes; never touches develop.
"""
import subprocess

REMOTE = {"name": "hobleyd", "url": "https://github.com/hobleyd/oolite.git"}
# (parent branch, PR branch in the remote, PR number); the order is the stack's
PARENTS = (
    ("seriesb/000a-upstream-767-quickjs-option", "quickjs-poc", 767),
    ("seriesb/000b-upstream-768-quickjs-only", "quickjs-default", 768),
)


def _git(repo, *args, ok=(0,)):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, encoding="utf-8")
    if r.returncode not in ok:
        raise SystemExit(f"git {' '.join(args)}: {(r.stderr or r.stdout).strip()[-600:]}")
    return r


def _out(repo, *args):
    return _git(repo, *args).stdout.strip()


def _sha(repo, ref):
    r = _git(repo, "rev-parse", "-q", "--verify", f"{ref}^{{commit}}", ok=(0, 1, 128))
    return r.stdout.strip() if r.returncode == 0 else None


def refspecs(remote):
    return [f"+refs/heads/{pr_branch}:refs/remotes/{remote['name']}/{branch}" for branch, pr_branch, _ in PARENTS]


def _configure_remote(repo, remote):
    name = remote["name"]
    if _git(repo, "remote", "get-url", name, ok=(0, 2)).returncode != 0:
        _git(repo, "remote", "add", "--no-fetch", name, remote["url"])
    elif _out(repo, "remote", "get-url", name) != remote["url"]:
        _git(repo, "remote", "set-url", name, remote["url"])
    want = refspecs(remote)
    have = _git(repo, "config", "--get-all", f"remote.{name}.fetch", ok=(0, 1)).stdout.split()
    if sorted(have) != sorted(want):
        _git(repo, "config", "--unset-all", f"remote.{name}.fetch", ok=(0, 5))
        for spec in want:
            _git(repo, "config", "--add", f"remote.{name}.fetch", spec)
    # never let a default push go to the PR author's repository
    if _git(repo, "config", "--get", f"remote.{name}.pushurl", ok=(0, 1)).stdout.strip() != "no-push":
        _git(repo, "config", f"remote.{name}.pushurl", "no-push")


def _fetch(repo, remote):
    _git(repo, "fetch", "-q", remote["name"])


def _checked_out(repo):
    """Branches checked out in any worktree of `repo`."""
    out = set()
    for line in _out(repo, "worktree", "list", "--porcelain").splitlines():
        if line.startswith("branch refs/heads/"):
            out.add(line[len("branch refs/heads/"):])
    return out


def _config(repo, key, value):
    if _git(repo, "config", "--get", key, ok=(0, 1)).stdout.strip() != value:
        _git(repo, "config", key, value)


def _record(m, branch, **fields):
    entries = m.setdefault("parents", [])
    for p in entries:
        if p["branch"] == branch:
            p.update(fields)
            return p
    p = dict(branch=branch, **fields)
    entries.append(p)
    return p


def setup(repo, m, remote=REMOTE, anchors=None):
    """Create or repair the parents: remote, branches at their PR heads, tracking, lineage, observed
    type, and their manifest entries. Idempotent. `anchors` fills the manifest's anchors if absent."""
    _configure_remote(repo, remote)
    _fetch(repo, remote)
    busy = _checked_out(repo)
    from tools.series import seriesb
    prev = seriesb.root_parent(m)
    for branch, pr_branch, pr in PARENTS:
        tracking = f"{remote['name']}/{branch}"
        head = _sha(repo, f"refs/remotes/{tracking}")
        if head is None:
            raise SystemExit(f"parents: {remote['name']} has no branch {pr_branch}")
        tip = _sha(repo, f"refs/heads/{branch}")
        if tip is None:
            _git(repo, "branch", "--no-track", branch, head)
        elif tip != head:
            if branch in busy:
                raise SystemExit(f"parents: {branch} is checked out; switch away and rerun")
            _git(repo, "update-ref", f"refs/heads/{branch}", head, tip)
        _config(repo, f"branch.{branch}.remote", remote["name"])
        _config(repo, f"branch.{branch}.merge", f"refs/heads/{pr_branch}")  # mapped by the refspec
        _config(repo, f"git-town-branch.{branch}.parent", prev)
        if _git(repo, "config", "--get", f"git-town-branch.{branch}.branchtype", ok=(0, 1)).stdout.strip() != "observed":
            r = subprocess.run(["git", "town", "observe", branch], cwd=repo, capture_output=True, text=True,
                               encoding="utf-8")
            if r.returncode != 0:
                raise SystemExit(f"git town observe {branch}: {(r.stderr or r.stdout).strip()[-400:]}")
        entry = _record(m, branch, kind="upstream", upstream_pr=pr, tracking=tracking, head=head, parent=prev,
                        git_town_type="observed")
        entry.setdefault("gate", "pending")
        entry.setdefault("verification", None)
        prev = branch
    if anchors:
        a = m.setdefault("anchors", {})
        for k, v in anchors.items():
            a.setdefault(k, v)
    return m


def status(repo, m):
    """Problems with the parents: a missing branch, or a tip that is not its tracking head."""
    out = []
    for p in m.get("parents", []):
        if p.get("kind") != "upstream" or p.get("state") == "retired":
            continue
        tip, track = _sha(repo, f"refs/heads/{p['branch']}"), _sha(repo, f"refs/remotes/{p['tracking']}")
        if tip is None:
            out.append(f"{p['branch']}: no such branch (run `parents --setup`)")
        elif tip != track:
            out.append(f"{p['branch']}: at {tip[:10]}, its PR at {str(track)[:10]} (run `parents --refresh`)")
    return out


def refresh(repo, m, remote=REMOTE):
    """Fetch the remote and reset each parent to its tracking ref (a force-push included); record heads."""
    _fetch(repo, remote)
    busy = _checked_out(repo)
    live = [p for p in m.get("parents", []) if p.get("kind") == "upstream" and p.get("state") != "retired"]
    # the heads before this refresh, for the next `sync-record` (only the first refresh of a sync counts)
    m.setdefault("pending_sync", {"before": {p["branch"]: _sha(repo, f"refs/heads/{p['branch']}") for p in live}})
    held = sorted(p["branch"] for p in live if p["branch"] in busy)
    if held:
        raise SystemExit(f"parents: {', '.join(held)} checked out; switch away first (a parent is never worked on)")
    for p in live:
        head = _sha(repo, f"refs/remotes/{p['tracking']}")
        tip = _sha(repo, f"refs/heads/{p['branch']}")
        if head is None:
            raise SystemExit(f"parents: no tracking ref {p['tracking']}")
        if tip != head:
            _git(repo, "update-ref", f"refs/heads/{p['branch']}", head)
        if p.get("head") != head:
            p["head"] = head
    return m


UPSTREAM_MASTER_BRANCH = "seriesb/000m-upstream-master"


def retire(repo, m, upstream_ref="refs/remotes/upstream/master"):
    """FR-011a: once every upstream parent's head is in upstream master, add the perennial
    seriesb/000m-upstream-master at master, move step 1 onto it, and mark the parents retired. Deletes
    nothing; Jon deletes the old parents when he wants to."""
    master = _sha(repo, upstream_ref)
    if master is None:
        raise SystemExit(f"parents --retire: no {upstream_ref}; fetch upstream first")
    live = [p for p in m.get("parents", []) if p.get("kind") == "upstream" and p.get("state") != "retired"]
    if not live:
        raise SystemExit("parents --retire: no upstream parents to retire")
    unmerged = [p["branch"] for p in live
                if _git(repo, "merge-base", "--is-ancestor", p["head"], master, ok=(0, 1)).returncode != 0]
    if unmerged:
        raise SystemExit(f"parents --retire: not in upstream master yet: {', '.join(unmerged)}")
    if _sha(repo, f"refs/heads/{UPSTREAM_MASTER_BRANCH}") is None:
        _git(repo, "branch", "--no-track", UPSTREAM_MASTER_BRANCH, master)
    perennial = _git(repo, "config", "--get-all", "git-town.perennial-branches", ok=(0, 1)).stdout.split()
    if UPSTREAM_MASTER_BRANCH not in perennial:
        _git(repo, "config", "--replace-all", "git-town.perennial-branches", " ".join(perennial + [UPSTREAM_MASTER_BRANCH]))
    for p in live:
        p["state"] = "retired"
    entry = _record(m, UPSTREAM_MASTER_BRANCH, kind="upstream-master", head=master, parent=None,
                    git_town_type="perennial", tracking=upstream_ref.replace("refs/remotes/", "", 1))
    entry.setdefault("gate", "pending")
    entry.setdefault("verification", None)
    steps = m.get("steps", [])
    if steps:
        steps[0]["parent"] = UPSTREAM_MASTER_BRANCH
        _git(repo, "config", f"git-town-branch.{steps[0]['branch']}.parent", UPSTREAM_MASTER_BRANCH)
    return m
