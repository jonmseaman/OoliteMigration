"""Carry a history snapshot onto the series base by a 3-way merge (research R4).

target_tree(repo, base, ours, theirs, res_dir):
  base   = N(upstream commit under the snapshot)   the merge base
  ours   = the series base (upstream 49a5eb9fc, plus hoisted fixes)
  theirs = N(history snapshot)
Files the history did not change take upstream's version; files only the history changed take the
history's; files both changed are conflicts. A conflict is resolved by a stored whole-file
resolution under res_dir, keyed by the three input blob ids, so a resolution made against other
inputs (after a re-anchor, say) is reported again instead of being applied silently.

res_dir layout: index.json {path: {base, ours, theirs, deleted}} and files/<path>.
"""
import json
import os
import subprocess
import tempfile

IDENT = {"GIT_AUTHOR_NAME": "series", "GIT_AUTHOR_EMAIL": "series@localhost",
         "GIT_COMMITTER_NAME": "series", "GIT_COMMITTER_EMAIL": "series@localhost",
         "GIT_AUTHOR_DATE": "2026-11-01T00:00:00Z", "GIT_COMMITTER_DATE": "2026-11-01T00:00:00Z"}


def _git(repo, *args, inp=None, env=None, ok=(0,)):
    r = subprocess.run(["git", "-C", repo, *args], input=inp, capture_output=True,
                       env=dict(os.environ, **IDENT, **(env or {})))
    if r.returncode not in ok:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.decode('utf-8', 'replace').strip()}")
    return r


def _commit(repo, tree):
    return _git(repo, "commit-tree", tree, "-m", "series merge input").stdout.decode().strip()


def _blob(repo, tree, path):
    r = _git(repo, "rev-parse", "-q", "--verify", f"{tree}:{path}", ok=(0, 1, 128))
    return r.stdout.decode().strip() or None if r.returncode == 0 else None


def _mode(repo, tree, path):
    out = _git(repo, "ls-tree", tree, "--", path).stdout.decode().strip()
    return out.split()[0] if out else None


def _load_index(res_dir):
    p = os.path.join(res_dir, "index.json")
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    return {}


RENAME_THRESHOLD = "30%"  # the history renamed .m -> .mm while rewriting 40-60% of a file


def merge(repo, base, ours, theirs, renames=RENAME_THRESHOLD):
    """Return (merged tree id, conflicted paths) from git merge-tree."""
    cb, co, ct = _commit(repo, base), _commit(repo, ours), _commit(repo, theirs)
    r = _git(repo, "merge-tree", "--write-tree", "-z", "--name-only", "-X", f"find-renames={renames}",
             f"--merge-base={cb}", co, ct, ok=(0, 1))
    parts = r.stdout.decode("utf-8").split("\0")
    tree = parts[0]
    conflicts = []
    if r.returncode == 1:
        for p in parts[1:]:
            if p == "":
                break
            if p not in conflicts:
                conflicts.append(p)
    return tree, conflicts


def target_tree(repo, base, ours, theirs, res_dir):
    """Return (tree, []) when every conflict has a matching resolution, else (None, unresolved paths)."""
    tree, conflicts = merge(repo, base, ours, theirs)
    if not conflicts:
        return tree, []
    index = _load_index(res_dir)
    apply, unresolved = [], []
    for path in conflicts:
        key = {"base": _blob(repo, base, path), "ours": _blob(repo, ours, path), "theirs": _blob(repo, theirs, path)}
        rec = index.get(path)
        if rec and all(rec.get(k) == v for k, v in key.items()):
            apply.append((path, rec))
        else:
            unresolved.append(path)
    if unresolved:
        return None, sorted(unresolved)
    with tempfile.TemporaryDirectory() as tmp:
        env = {"GIT_INDEX_FILE": os.path.join(tmp, "index")}
        _git(repo, "read-tree", tree, env=env)
        for path, rec in apply:
            if rec.get("deleted"):
                _git(repo, "update-index", "--force-remove", "--", path, env=env)
                continue
            with open(os.path.join(res_dir, "files", path), "rb") as f:
                sha = _git(repo, "hash-object", "-w", "--stdin", inp=f.read()).stdout.decode().strip()
            mode = _mode(repo, theirs, path) or _mode(repo, ours, path) or "100644"
            _git(repo, "update-index", "--add", "--cacheinfo", f"{mode},{sha},{path}", env=env)
        out = _git(repo, "write-tree", env=env).stdout.decode().strip()
    return out, []


def record_resolution(repo, base, ours, theirs, res_dir, path, content):
    """Store a resolution for `path` against these inputs. content=None means the path is deleted."""
    index = _load_index(res_dir)
    index[path] = {"base": _blob(repo, base, path), "ours": _blob(repo, ours, path),
                   "theirs": _blob(repo, theirs, path), "deleted": content is None}
    if content is not None:
        target = os.path.join(res_dir, "files", path)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as f:
            f.write(content)
    os.makedirs(res_dir, exist_ok=True)
    with open(os.path.join(res_dir, "index.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(index, f, indent=1, sort_keys=True)
        f.write("\n")
