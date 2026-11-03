"""Step branches and their Git Town lineage (research R8).

Each step is one commit on its parent's tip. A new step branch is created with
`git town append <branch> --prototype --no-sync --no-push` from its parent, so Git Town records the
order. That runs in a dedicated worktree, so the repository's main checkout (develop) never moves.
Never pushes, never syncs, never proposes.
"""
import os
import subprocess

ROOT_BRANCH = "series/000-upstream-base"
PREFIX = "series/"  # the active profile's branch prefix (profile.activate)


def _run(args, cwd=None, inp=None, ok=(0,)):
    r = subprocess.run(args, cwd=cwd, input=inp, capture_output=True, text=True, encoding="utf-8")
    if r.returncode not in ok:
        raise RuntimeError(f"{' '.join(args)}: {(r.stderr or r.stdout).strip()[-600:]}")
    return r


def git(repo, *args, inp=None, ok=(0,)):
    return _run(["git", "-C", repo, *args], inp=inp, ok=ok).stdout.strip()


def exists(repo, branch):
    return _run(["git", "-C", repo, "rev-parse", "-q", "--verify", f"refs/heads/{branch}"], ok=(0, 1)).returncode == 0


def lineage(repo, branch):
    r = _run(["git", "-C", repo, "config", "--get", f"git-town-branch.{branch}.parent"], ok=(0, 1))
    return r.stdout.strip() or None


def ensure_worktree(repo, worktree):
    if not os.path.isdir(worktree):
        git(repo, "worktree", "add", "-q", "--detach", worktree, ROOT_BRANCH)
    return worktree


def _town(worktree, *args):
    return _run(["git", "town", *args, "--non-interactive"], cwd=worktree)


def make_step(repo, worktree, branch, parent, tree, message):
    """Create or reset `branch` to one commit with `tree` on `parent`'s tip; set its lineage. Returns the commit."""
    if branch in ("develop", "master", "main") or not branch.startswith(PREFIX):
        raise ValueError(f"refusing to write branch {branch!r}")
    ensure_worktree(repo, worktree)
    parent_tip = git(repo, "rev-parse", f"refs/heads/{parent}")
    commit = git(repo, "commit-tree", tree, "-p", parent_tip, "-F", "-", inp=message)
    if not exists(repo, branch):
        git(worktree, "checkout", "-q", parent)
        _town(worktree, "append", branch, "--prototype", "--no-sync", "--no-push")
        git(worktree, "checkout", "-q", "--detach")
    elif lineage(repo, branch) != parent:
        git(worktree, "checkout", "-q", branch)
        _town(worktree, "set-parent", parent)
        git(worktree, "checkout", "-q", "--detach")
    git(repo, "branch", "-f", branch, commit)
    return commit
