"""Scratch runner: apply hand resolutions for step N from .agent-tmp/res/NNN.py and record them.

NNN.py defines
  RES = {path: [spec, spec, ...]}   one spec per conflict hunk, in file order:
        "ours" | "theirs" | "both" (ours then theirs) | "theirs+ours" | literal text
  DELETE = [path, ...]              paths resolved by deleting them
Usage: python -I .agent-tmp/apply_res.py N [--dry]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.series import series as S, trees, history  # noqa: E402

n = int(sys.argv[1])
dry = "--dry" in sys.argv
spec_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "res", f"{n:03d}.py")
ns = {"__file__": spec_file}
with open(spec_file, encoding="utf-8") as f:
    exec(f.read(), ns)
RES, DELETE = ns.get("RES", {}), ns.get("DELETE", [])
FIX_LATE = {}

m = S.load_manifest()
st = S.step_by_n(m, n)
b, o, t = S.merge_inputs(m, st)
tree, conf = trees.merge(S.GAME, b, o, t)
HUNK = re.compile(r"^<<<<<<< [^\n]*\n(.*?)^=======\n(.*?)^>>>>>>> [^\n]*\n", re.S | re.M)
for path, specs in RES.items():
    if path not in conf:
        if all(sp == "theirs" for sp in specs):
            print(f"{path}: no longer a conflict (spec was the history's side); skipped")
            continue
        raise SystemExit(f"{path}: not a conflict in step {n}")
    k = conf[path]
    text = "".join(trees.merge_file_by_hunks(S.GAME, k["base"], k["ours"], k["theirs"], o, path)[0])
    hunks = list(HUNK.finditer(text))
    if len(hunks) != len(specs):
        raise SystemExit(f"{path}: {len(hunks)} hunks, {len(specs)} specs")
    out, pos = [], 0
    for mt, spec in zip(hunks, specs):
        ours, theirs = mt.group(1), mt.group(2)
        out.append(text[pos:mt.start()])
        if callable(spec):
            out.append(spec(ours, theirs))
        elif spec == "ours":
            out.append(ours)
        elif spec == "theirs":
            out.append(theirs)
        elif spec == "both":
            out.append(ours + theirs)
        elif spec == "theirs+ours":
            out.append(theirs + ours)
        else:
            out.append(spec if spec.endswith("\n") or spec == "" else spec + "\n")
        pos = mt.end()
    out.append(text[pos:])
    result = "".join(out)
    for old, new in ns.get("POST", {}).get(path, []):  # replacements on the resolved file
        if result.count(old) != 1:
            raise SystemExit(f"{path}: POST pattern found {result.count(old)} times: {old[:60]!r}")
        result = result.replace(old, new)
    if re.search(r"^(<<<<<<<|=======$|>>>>>>>)", result, re.M):
        raise SystemExit(f"{path}: markers left")
    print(f"{path}: {len(hunks)} hunks resolved")
    if not dry:
        trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path,
                                result.encode("utf-8", "surrogateescape"))
for path in DELETE:
    print(f"{path}: deleted")
    if not dry:
        trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path, None)
# WHOLE = {path: "theirs" | "ours"}: record that side's whole file (an extra if not a conflict path)
for path, side in ns.get("WHOLE", {}).items():
    fn = side if callable(side) else None
    tree_side = {"theirs": t, "ours": o}["theirs" if fn else side]
    data = trees._git(S.GAME, "cat-file", "-p", f"{tree_side}:{path}").stdout
    if fn:
        new = fn(data.decode("utf-8", "surrogateescape")).encode("utf-8", "surrogateescape")
        if new == data:
            raise SystemExit(f"{path}: the whole-file function changed nothing")
        data = new
    print(f"{path}: whole file from {'theirs (edited)' if fn else side}")
    if not dry:
        trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path, data)
# FIX = {path: fn(text) -> text}: an edit of a cleanly merged (non-conflict) file, keyed by the merged
# blob so it goes stale if the merge changes. For code the merge leaves uncompilable or warning.
for path, fn in ns.get("FIX", {}).items():
    if path in conf:
        raise SystemExit(f"{path}: a conflict in step {n}; use RES and POST")
    data = trees._git(S.GAME, "cat-file", "-p", f"{tree}:{path}").stdout.decode("utf-8", "surrogateescape")
    new = fn(data)
    if new == data:
        raise SystemExit(f"{path}: the fix changed nothing")
    print(f"{path}: fixed")
    if not dry:
        trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path,
                                new.encode("utf-8", "surrogateescape"), key_merged=True)
# EDIT = {path: fn(text) -> text}: for a conflict path the automatic rules resolve, edit that automatic
# result and store it as the resolution. The automatic result is recomputed without this path's stored
# resolution, so re-running is idempotent.
# CHANGES = {path: [(old, new), ...]}: exact replacements, each matching once; routed to FIX for a clean
# path and to EDIT for an automatically resolved conflict (a path in RES takes POST instead).
import json as _json


def _pairs(pairs):
    def fn(text):
        for pair in pairs:
            old, new, want = (tuple(pair) + (1,))[:3]
            if text.count(old) != want:
                raise SystemExit(f"replacement found {text.count(old)} times, not {want}: {old[:70]!r}")
            text = text.replace(old, new)
        return text
    return fn


def _automatic(path):
    auto_tree, unresolved = trees.target_tree(S.GAME, b, o, t, S.resolutions_dir(st), ignore={path})
    if path in (unresolved or []):
        raise SystemExit(f"{path}: not resolved automatically; use RES")
    if auto_tree is None:
        raise SystemExit(f"{path}: other conflicts are open in step {n} ({unresolved[:3]}); resolve them first")
    return trees._git(S.GAME, "cat-file", "-p", f"{auto_tree}:{path}").stdout.decode("utf-8", "surrogateescape")


EDIT = dict(ns.get("EDIT", {}))
for path, pairs in ns.get("CHANGES", {}).items():
    if path in RES:
        raise SystemExit(f"{path}: in RES; put its replacements in POST")
    (EDIT if path in conf else FIX_LATE).__setitem__(path, _pairs(pairs))
for path, fn in EDIT.items():
    if path not in conf:
        raise SystemExit(f"{path}: not a conflict in step {n}; use FIX")
    data = _automatic(path)
    new = fn(data)
    if new == data:
        raise SystemExit(f"{path}: the edit changed nothing")
    print(f"{path}: edited")
    if not dry:
        trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path, new.encode("utf-8", "surrogateescape"))
for path, fn in FIX_LATE.items():
    data = trees._git(S.GAME, "cat-file", "-p", f"{tree}:{path}").stdout.decode("utf-8", "surrogateescape")
    new = fn(data)
    print(f"{path}: fixed")
    if not dry:
        trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path,
                                new.encode("utf-8", "surrogateescape"), key_merged=True)
# ADD = {path: source file under the spec's directory}: a new file the step adds (not in the merge)
for path, src in ns.get("ADD", {}).items():
    if trees._blob_at(S.GAME, tree, path):
        raise SystemExit(f"{path}: already in the merge; use CHANGES")
    data = open(os.path.join(os.path.dirname(spec_file), src), "rb").read()
    print(f"{path}: added")
    if not dry:
        trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path, data)
# RENAMES = [(regex, replacement), ...]: applied to every file of the step's result that matches (a
# name the history keeps changing form across steps). Routed like CHANGES: POST for a path in RES,
# EDIT for an automatically resolved conflict, FIX for a clean path. Run after the sections above.
for _rx, _rep in ns.get("RENAMES", []):
    _pat = re.compile(_rx)
    _files = trees._git(S.GAME, "grep", "-l", "-P", "-e", _rx, tree, "--", "src", ok=(0, 1)).stdout.decode().split()
    for _f in _files:
        path = _f.split(":", 1)[1]
        if path in RES:
            print(f"{path}: in RES; its POST carries the rename (the build reports a miss)")
            continue
        if path in conf:
            data = _automatic(path)
        else:
            data = trees._git(S.GAME, "cat-file", "-p", f"{tree}:{path}").stdout.decode("utf-8", "surrogateescape")
        new, count = _pat.subn(_rep, data)
        if count == 0:
            continue
        print(f"{path}: renamed ({count})")
        if not dry:
            trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path, new.encode("utf-8", "surrogateescape"),
                                    key_merged=path not in conf)
