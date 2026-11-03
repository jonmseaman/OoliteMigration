"""Renumbering: after a step is inserted or removed, make every `NNN` equal its step's `n` again.

The manifest's `n` and `parent` are already right (`hoist` sets them); the branches, their Git Town
lineage, the description files and the resolution directories still carry the old numbers. Moves go
through temporary names, so a step can take a number another step is giving up.
"""
import os
import re

BRANCH_RE = re.compile(r"^series/(\d{3})-(.+)$")
TMP = "series/renumbering/"


def _git(repo, *args, ok=(0,)):
    from tools.series import stack
    return stack._run(["git", "-C", repo, *args], ok=ok)


def moves(m):
    """[(step, old number, new branch)] for every step whose branch does not carry its `n`."""
    out = []
    for s in m.get("steps", []):
        mt = BRANCH_RE.match(s["branch"])
        if not mt:
            raise ValueError(f"step {s['n']}: branch {s['branch']!r} is not {_prefix()}NNN-slug")
        if int(mt.group(1)) != s["n"]:
            out.append((s, int(mt.group(1)), f"{_prefix()}{s['n']:03d}-{mt.group(2)}"))
    return out


def _prefix():
    from tools.series import stack
    return stack.PREFIX


def _town_config(repo, branch):
    r = _git(repo, "config", "--get-regexp", f"^git-town-branch\\.{re.escape(branch)}\\.", ok=(0, 1))
    return [line.split(" ", 1) for line in r.stdout.splitlines() if line]


def _move_branch(repo, old, new):
    if _git(repo, "rev-parse", "-q", "--verify", f"refs/heads/{old}", ok=(0, 1)).returncode != 0:
        return
    _git(repo, "branch", "-m", old, new)
    prefix = f"git-town-branch.{old}."
    for key, value in _town_config(repo, old):
        _git(repo, "config", f"git-town-branch.{new}.{key[len(prefix):]}", value)
        _git(repo, "config", "--unset", key)


def _move_path(old, new):
    if os.path.exists(old):
        os.makedirs(os.path.dirname(new), exist_ok=True)
        os.rename(old, new)


def apply(repo, series_dir, m, root_branch):
    """Rename branches (with their Git Town config), descriptions and resolution directories, rewrite
    the manifest's `branch`, `description` and `parent`, and set every step's Git Town parent."""
    todo = moves(m)
    pr = lambda name: os.path.join(series_dir, "pr", name + ".md")
    res = lambda num: os.path.join(series_dir, "resolutions", f"{num:03d}")
    tmp_res = lambda num: os.path.join(series_dir, "resolutions", f"renumbering-{num:03d}")
    staged = []
    for s, old_num, new_branch in todo:
        old_branch, slug = s["branch"], s["branch"].split("-", 1)[1]
        tmp = TMP + f"{old_num:03d}-{slug}"
        _move_branch(repo, old_branch, tmp)
        _move_path(pr(f"{old_num:03d}-{slug}"), pr(f"renumbering-{old_num:03d}-{slug}"))
        _move_path(res(old_num), tmp_res(old_num))
        staged.append((s, old_num, slug, tmp, new_branch))
    for s, old_num, slug, tmp, new_branch in staged:
        _move_branch(repo, tmp, new_branch)
        _move_path(pr(f"renumbering-{old_num:03d}-{slug}"), pr(f"{s['n']:03d}-{slug}"))
        _move_path(tmp_res(old_num), res(s["n"]))
        s["branch"] = new_branch
        s["description"] = f"series/pr/{s['n']:03d}-{slug}.md"
    steps = m.get("steps", [])
    for i, s in enumerate(steps):
        s["parent"] = root_branch if i == 0 else steps[i - 1]["branch"]
        if _git(repo, "rev-parse", "-q", "--verify", f"refs/heads/{s['branch']}", ok=(0, 1)).returncode == 0:
            _git(repo, "config", f"git-town-branch.{s['branch']}.parent", s["parent"])
    return [(old_num, s["branch"]) for s, old_num, _ in todo]
