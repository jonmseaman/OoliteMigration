"""Carry the history onto the series base by 3-way merges (research R4, R15).

target_tree(repo, base, ours, theirs, res_dir) merges with git merge-tree, then resolves each
conflict by a stored whole-file resolution whose input blobs match, or else by auto_merge_text when
the two sides change different (possibly adjacent) lines. A resolution made against other inputs
(after a re-anchor, say) is reported again instead of being applied silently.

res_dir layout: index.json {path: {base, ours, theirs, deleted}} and files/<path>.
"""
import difflib
import json
import os
import subprocess
import tempfile

IDENT = {"GIT_AUTHOR_NAME": "series", "GIT_AUTHOR_EMAIL": "series@localhost",
         "GIT_COMMITTER_NAME": "series", "GIT_COMMITTER_EMAIL": "series@localhost",
         "GIT_AUTHOR_DATE": "2026-11-01T00:00:00Z", "GIT_COMMITTER_DATE": "2026-11-01T00:00:00Z"}
RENAME_THRESHOLD = "30%"  # the history renamed .m -> .mm while rewriting 40-60% of a file
NUL = chr(0)
TAB = chr(9)


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
    if r.returncode != 0:
        return None
    return r.stdout.decode().strip() or None


def _mode(repo, tree, path):
    out = _git(repo, "ls-tree", tree, "--", path).stdout.decode().strip()
    return out.split()[0] if out else None


def _load_index(res_dir):
    p = os.path.join(res_dir, "index.json")
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    return {}


def merge(repo, base, ours, theirs, renames=RENAME_THRESHOLD):
    """Return (merged tree id, {path: {"base", "ours", "theirs"}: blob id or None}).

    The blob ids come from merge-tree's conflicted stage entries (1 base, 2 ours, 3 theirs), so they
    are right for renamed files too.
    """
    cb, co, ct = _commit(repo, base), _commit(repo, ours), _commit(repo, theirs)
    r = _git(repo, "merge-tree", "--write-tree", "-z", "-X", f"find-renames={renames}",
             f"--merge-base={cb}", co, ct, ok=(0, 1))
    parts = r.stdout.decode("utf-8").split(NUL)
    tree = parts[0]
    conflicts = {}
    if r.returncode == 1:
        names = {"1": "base", "2": "ours", "3": "theirs"}
        for entry in parts[1:]:
            if entry == "":
                break
            meta, path = entry.split(TAB, 1)
            _mode_, oid, stage = meta.split()
            rec = conflicts.setdefault(path, {"base": None, "ours": None, "theirs": None})
            rec[names[stage]] = oid
    return tree, conflicts


def _lines(repo, oid):
    return _git(repo, "cat-file", "blob", oid).stdout.decode("utf-8", "surrogateescape").splitlines(keepends=True)


def auto_merge_text(base, ours, theirs, flags=None):
    """Line-level 3-way merge that accepts changes to different (even adjacent) base lines.

    base, ours, theirs: lists of lines. Returns the merged list, or None when the sides change
    overlapping base lines differently or insert different text at the same point. One overlap is
    accepted: ours (upstream) deleting a block wholly containing theirs' edits drops the block; then
    "upstream-deleted" is added to `flags` (a set) if given.
    """
    def changes(side):
        sm = difflib.SequenceMatcher(None, base, side, autojunk=False)
        return [(i1, i2, side[j1:j2]) for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag != "equal"]

    a, b = changes(ours), changes(theirs)
    merged, i, ia, ib = [], 0, 0, 0
    while ia < len(a) or ib < len(b):
        ca = a[ia] if ia < len(a) else None
        cb = b[ib] if ib < len(b) else None
        if ca and cb and not ca[2] and ca[0] < ca[1] and ca[0] <= cb[0] and cb[1] <= ca[1] and ca != cb:
            # upstream deleted a block; drop theirs' edits that lie inside it
            jb = ib
            while jb < len(b) and ca[0] <= b[jb][0] and b[jb][1] <= ca[1]:
                jb += 1
            if jb < len(b) and b[jb][0] < ca[1]:  # an edit straddles the block's end
                return None
            if flags is not None:
                flags.add("upstream-deleted")
            pick, ia, ib = ca, ia + 1, jb
        elif ca and cb:
            if ca == cb:  # the same change on both sides
                pick, ia, ib = ca, ia + 1, ib + 1
            else:
                overlap = ca[0] < cb[1] and cb[0] < ca[1]
                same_point = ca[0] == cb[0] and (ca[0] == ca[1] or cb[0] == cb[1])
                inside = (ca[0] == ca[1] and cb[0] < ca[0] < cb[1]) or (cb[0] == cb[1] and ca[0] < cb[0] < ca[1])
                if overlap or same_point or inside:
                    return None
                if ca[0] < cb[0]:
                    pick, ia = ca, ia + 1
                else:
                    pick, ib = cb, ib + 1
        elif ca:
            pick, ia = ca, ia + 1
        else:
            pick, ib = cb, ib + 1
        i1, i2, repl = pick
        merged.extend(base[i:i1])
        merged.extend(repl)
        i = i2
    merged.extend(base[i:])
    return merged


def _similar(a, b):
    a, b = a.strip(), b.strip()
    if a == b:
        return 1.0
    return difflib.SequenceMatcher(None, a, b, autojunk=False).ratio()


def _context_score(base, i, theirs, j, k=3):
    """How much the lines around theirs[j] resemble those around base[i]: a sum of similarities."""
    score = 0.0
    for d in range(1, k + 1):
        if i - d >= 0 and j - d >= 0:
            score += _similar(base[i - d], theirs[j - d])
        if i + d < len(base) and j + d < len(theirs):
            score += _similar(base[i + d], theirs[j + d])
    return score


MIN_CONTEXT = 1.5   # a substituted line needs at least this much matching context
MIN_MARGIN = 0.75   # and must beat the next candidate by this much
SOLE_CONTEXT = 0.25  # the only candidate left (after order and alignment) needs this much


def transplant(base, ours, theirs):
    """Apply ours' changes (relative to base) onto theirs, for one side's small edits.

    A change of ours whose base lines theirs still has, in a run of at least two aligned lines, is
    applied there. A one-line substitution whose surroundings theirs rewrote goes to the line of
    theirs that equals the old line, keeps base order, isn't claimed by another change, and whose
    neighbours resemble the base context clearly better than any other candidate. Returns the merged
    lines, or None if any change cannot be placed unambiguously.
    """
    sm = difflib.SequenceMatcher(None, base, theirs, autojunk=False)
    to_theirs = {}
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal" and i2 - i1 >= 2:
            for d in range(i2 - i1):
                to_theirs[i1 + d] = j1 + d
    placed = {}   # base index of the change -> (j1, j2, replacement)
    pending = []  # one-line substitutions to place by context
    for tag, i1, i2, k1, k2 in difflib.SequenceMatcher(None, base, ours, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        repl = ours[k1:k2]
        if i1 < i2 and all(i in to_theirs for i in range(i1, i2)) and \
                to_theirs[i2 - 1] - to_theirs[i1] == i2 - i1 - 1:
            placed[i1] = (to_theirs[i1], to_theirs[i2 - 1] + 1, repl)
        elif i1 == i2 and (i1 - 1 in to_theirs or i1 in to_theirs):  # insertion next to aligned lines
            j = to_theirs[i1 - 1] + 1 if i1 - 1 in to_theirs else to_theirs[i1]
            placed[i1] = (j, j, repl)
        elif i2 - i1 == 1 and len(repl) == 1:
            pending.append((i1, repl))
        else:
            return None
    # lines of theirs aligned to some base line belong to that line, never to another
    claimed = set(to_theirs.values()) | {j for j1, j2, _ in placed.values() for j in range(j1, j2)}
    while pending:
        best = None  # (margin, score, i, j, repl): place the most confident substitution first
        for i, repl in pending:
            lo = max([v[1] for k, v in placed.items() if k < i] or [0])
            hi = min([v[0] for k, v in placed.items() if k > i] or [len(theirs)])
            cands = sorted(((_context_score(base, i, theirs, j), j) for j in range(lo, hi)
                            if theirs[j] == base[i] and j not in claimed), reverse=True)
            if not cands:
                return None
            if len(cands) == 1:  # the only line left in order that can be it
                ok, margin = cands[0][0] >= SOLE_CONTEXT, cands[0][0] + MIN_MARGIN
            else:
                margin = cands[0][0] - cands[1][0]
                ok = cands[0][0] >= MIN_CONTEXT and margin >= MIN_MARGIN
            if ok and (best is None or margin > best[0]):
                best = (margin, cands[0][0], i, cands[0][1], repl)
        if best is None:
            return None
        _, _, i, j, repl = best
        placed[i] = (j, j + 1, repl)
        claimed.add(j)
        pending = [p for p in pending if p[0] != i]
    edits = sorted(placed.values())
    for (a1, a2, _), (b1, b2, _) in zip(edits, edits[1:]):
        if b1 < a2 or (a1 == b1 and a1 == a2 and b1 == b2):
            return None
    out, j = [], 0
    for j1, j2, repl in edits:
        out.extend(theirs[j:j1])
        out.extend(repl)
        j = j2
    out.extend(theirs[j:])
    return out


def target_tree(repo, base, ours, theirs, res_dir, report=None):
    """Return (tree, []) when every conflict is resolved, else (None, unresolved paths).

    `report`, if a list, receives (path, "stored" | "auto") for each resolved conflict.
    """
    tree, conflicts = merge(repo, base, ours, theirs)
    if not conflicts:
        return tree, []
    index = _load_index(res_dir)
    apply, unresolved = [], []
    for path, key in conflicts.items():
        rec = index.get(path)
        if rec and not rec.get("extra") and all(rec.get(k) == v for k, v in key.items()):
            apply.append((path, "stored", rec, None))
            continue
        if key["base"] and key["ours"] is None and key["theirs"] == key["base"]:
            # upstream deleted the file; the history only renamed it
            apply.append((path, "upstream-deleted", {"deleted": True}, None))
            continue
        if all(key.values()):
            b, o, t = _lines(repo, key["base"]), _lines(repo, key["ours"]), _lines(repo, key["theirs"])
            flags = set()
            out = auto_merge_text(b, o, t, flags)
            how = "upstream-deleted" if flags else "auto"
            if out is None:
                out, how = transplant(b, o, t), "transplant"
            if out is not None:
                apply.append((path, how, None, "".join(out).encode("utf-8", "surrogateescape")))
                continue
        unresolved.append(path)
    if unresolved:
        return None, sorted(unresolved)
    # files a resolution adds outside the conflicted paths (e.g. a name both sides renamed differently)
    for path, rec in index.items():
        if rec.get("extra") and path not in conflicts:
            apply.append((path, "stored", rec, None))
    with tempfile.TemporaryDirectory() as tmp:
        env = {"GIT_INDEX_FILE": os.path.join(tmp, "index")}
        _git(repo, "read-tree", tree, env=env)
        for path, how, rec, content in apply:
            if report is not None:
                report.append((path, how))
            if rec is not None and rec.get("deleted"):
                _git(repo, "update-index", "--force-remove", "--", path, env=env)
                continue
            if content is None:
                with open(os.path.join(res_dir, "files", path), "rb") as f:
                    content = f.read()
            sha = _git(repo, "hash-object", "-w", "--stdin", inp=content).stdout.decode().strip()
            mode = _mode(repo, theirs, path) or _mode(repo, tree, path) or "100644"
            _git(repo, "update-index", "--add", "--cacheinfo", f"{mode},{sha},{path}", env=env)
        out = _git(repo, "write-tree", env=env).stdout.decode().strip()
    return out, []


def record_resolution(repo, base, ours, theirs, res_dir, path, content):
    """Store a resolution for `path` against these inputs. content=None means the path is deleted.

    A path that is not one of the merge's conflicts is stored as an `extra` file, added whenever
    the step's conflicts are all resolved.
    """
    _, conflicts = merge(repo, base, ours, theirs)
    index = _load_index(res_dir)
    if path in conflicts:
        index[path] = dict(conflicts[path], deleted=content is None)
    else:
        index[path] = {"extra": True, "deleted": content is None}
    if content is not None:
        target = os.path.join(res_dir, "files", path)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as f:
            f.write(content)
    os.makedirs(res_dir, exist_ok=True)
    with open(os.path.join(res_dir, "index.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(index, f, indent=1, sort_keys=True)
        f.write("\n")
