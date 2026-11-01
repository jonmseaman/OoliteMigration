"""The formatting normaliser N (research R3).

`normalise_tree` formats every source file under src/ and tests/ with clang-format 22 and the
`.clang-format` of a given commit, and returns the resulting tree id. Works on git objects only
(a temporary index, no checkout). Formatted blobs are cached per (clang-format version, style,
input blob).
"""
import json
import os
import subprocess
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLANG_FORMAT = os.path.join(ROOT, ".agent-tmp", "series-venv", "Scripts", "clang-format.exe")
DEFAULT_CACHE = os.path.join(ROOT, ".agent-tmp", "series-cache", "normalise.json")
SOURCE_EXT = (".h", ".hpp", ".m", ".mm", ".c", ".cpp")
SOURCE_TOPS = ("src/", "tests/")


def _git(repo, *args, inp=None, env=None):
    r = subprocess.run(["git", "-C", repo, *args], input=inp, capture_output=True,
                       env=dict(os.environ, **(env or {})))
    if r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.decode('utf-8', 'replace').strip()}")
    return r.stdout


def is_source(path):
    return path.startswith(SOURCE_TOPS) and path.endswith(SOURCE_EXT)


def _version(clang_format):
    return subprocess.run([clang_format, "--version"], capture_output=True, text=True).stdout.strip()


def normalise_tree(repo, tree, style_from, clang_format=CLANG_FORMAT, cache_path=DEFAULT_CACHE, jobs=8):
    style_blob = _git(repo, "rev-parse", f"{style_from}:.clang-format").decode().strip()
    key_prefix = f"{_version(clang_format)}|{style_blob}|"
    cache = {}
    if os.path.exists(cache_path):
        with open(cache_path, encoding="utf-8") as f:
            cache = json.load(f)
    lock = threading.Lock()

    entries = []
    for line in _git(repo, "ls-tree", "-r", "-z", tree).split(b"\0"):
        if not line:
            continue
        meta, path = line.split(b"\t", 1)
        mode, typ, sha = meta.decode().split()
        path = path.decode("utf-8")
        if typ == "blob" and is_source(path):
            entries.append((mode, sha, path))

    with tempfile.TemporaryDirectory() as tmp:
        style_file = os.path.join(tmp, ".clang-format")
        with open(style_file, "wb") as f:
            f.write(_git(repo, "cat-file", "blob", style_blob))

        def fmt(entry):
            mode, sha, path = entry
            key = key_prefix + sha
            with lock:
                hit = cache.get(key)
            if hit:
                return mode, hit, path
            data = _git(repo, "cat-file", "blob", sha)
            r = subprocess.run([clang_format, f"--style=file:{style_file}", f"--assume-filename={path}"],
                               input=data, capture_output=True)
            if r.returncode:
                raise RuntimeError(f"clang-format {path}: {r.stderr.decode('utf-8', 'replace')[:300]}")
            new = _git(repo, "hash-object", "-w", "--stdin", inp=r.stdout).decode().strip()
            with lock:
                cache[key] = new
            return mode, new, path

        with ThreadPoolExecutor(jobs) as ex:
            results = list(ex.map(fmt, entries))

        changed = [(m, s, p) for (m, s, p), (_, old, _) in zip(results, entries) if s != old]
        index = os.path.join(tmp, "index")
        env = {"GIT_INDEX_FILE": index}
        _git(repo, "read-tree", tree, env=env)
        if changed:
            info = "".join(f"{m} {s}\t{p}\0" for m, s, p in changed).encode("utf-8")
            _git(repo, "update-index", "-z", "--index-info", inp=info, env=env)
        out = _git(repo, "write-tree", env=env).decode().strip()

    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    with open(cache_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(cache, f)
    return out
