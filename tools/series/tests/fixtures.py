"""Small git repositories that mimic the real layout, for the series tool's unit tests.

game/       stands for OoliteProject/oolite:
  U0  "dc55" base: src/a.m, src/b.m, .clang-format, README
  U1  reformat of src/a.m (as #749 reformatted the tree)
  U2  a real upstream edit to src/b.m           -> master (stands for 49a5eb9fc)
super/      stands for OoliteMigration:
  S0  adds upstream/oolite/ = U0 (the subtree add)
  six bead merges into main (first-parent), subjects "bead oo-xxxN: merge into main"
  one subtree-pull commit taking upstream's U2 change into upstream/oolite/src/b.m
"""
import os
import subprocess

ENV = {
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
    "GIT_COMMITTER_EMAIL": "t@t", "GIT_CONFIG_NOSYSTEM": "1",
}
STYLE = "BasedOnStyle: LLVM\nColumnLimit: 100\nAllowShortFunctionsOnASingleLine: None\n"


def git(repo, *args, date=None):
    env = dict(os.environ, **ENV)
    env["GIT_CONFIG_GLOBAL"] = os.devnull
    if date:
        env["GIT_AUTHOR_DATE"] = env["GIT_COMMITTER_DATE"] = date
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, encoding="utf-8", env=env)
    if r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout.strip()


def write(root, rel, text):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def init(path, branch):
    os.makedirs(path, exist_ok=True)
    git(path, "init", "-q", "-b", branch)
    git(path, "config", "core.autocrlf", "false")
    return path


def commit_all(repo, msg, n):
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", msg, date=f"2026-09-{10 + n:02d}T12:00:00")
    return git(repo, "rev-parse", "HEAD")


A0 = "int a(void) { return 1; }\n"
A1 = "int a(void) {\n  return 1;\n}\n"  # upstream's reformat
B0 = "int b(void) { return 2; }\n"
B2 = "int b(void) { return 3; }  /* upstream edit */\n"
E2 = "int e(void) {\n  return 7;\n}\n"  # upstream-only new file


def make_history_repo(tmp):
    """Build game/ and super/ under tmp; return a dict of paths and commit ids."""
    game = init(os.path.join(tmp, "game"), "master")
    write(game, ".clang-format", STYLE)
    write(game, "README", "game\n")
    write(game, "src/a.m", A0)
    write(game, "src/b.m", B0)
    u0 = commit_all(game, "U0 base", 0)
    write(game, "src/a.m", A1)
    u1 = commit_all(game, "U1 clang-format code (#749)", 1)
    write(game, "src/b.m", B2)
    write(game, "src/e.m", E2)
    u2 = commit_all(game, "U2 upstream edit to b, new e", 2)

    sup = init(os.path.join(tmp, "super"), "main")
    write(sup, "README.md", "migration\n")
    git(sup, "add", "-A")
    git(sup, "commit", "-q", "-m", "plan", date="2026-09-01T12:00:00")
    # subtree add: copy U0's tree under upstream/oolite/
    git(sup, "fetch", "-q", game, "master")
    git(sup, "read-tree", "--prefix=upstream/oolite/", "-u", u0)
    git(sup, "commit", "-q", "-m", "Add upstream/oolite as a subtree at U0 (squashed)", date="2026-09-02T12:00:00")
    s0 = git(sup, "rev-parse", "HEAD")

    P = "upstream/oolite/"
    beads = [
        ("oo-aaa1", {P + "tests/test_seed.py": "def test_seed():\n    assert True\n"}),
        ("oo-1bf.3", {P + "src/a.m": "int a(void) { return 10; }\n"}),
        ("oo-1gc.2", {P + "src/c.cpp": "int c() { return 4; }\n"}),
        ("oo-3rb.7", {P + "src/b.m": "int b(void) { return 20; }\n"}),
        ("oo-9ht.4", {P + "src/c.cpp": "int c() {   return 5; }\n"}),
        ("oo-6e1.1", {P + "src/d.cpp": "int d() { return 6; }\n"}),
    ]
    merges = []
    for i, (bead, files) in enumerate(beads):
        git(sup, "checkout", "-q", "-b", f"bead/{bead}")
        for rel, text in files.items():
            write(sup, rel, text)
        commit_all(sup, f"bead {bead}: change", 3 + 2 * i)
        git(sup, "checkout", "-q", "main")
        git(sup, "merge", "-q", "--no-ff", "-m", f"bead {bead}: merge into main", f"bead/{bead}",
            date=f"2026-09-{14 + 2 * i:02d}T12:00:00")
        merges.append(git(sup, "rev-parse", "HEAD"))
    # subtree pull of U2: upstream's b.m change, resolved by keeping ours (as the real pull kept src)
    write(sup, P + "README", "game\n")
    write(sup, P + ".pulled", "U2\n")
    pull = commit_all(sup, "oo-we7mm: subtree pull upstream game U2 into upstream/oolite", 19)
    return {"game": game, "super": sup, "u0": u0, "u1": u1, "u2": u2, "s0": s0,
            "merges": merges, "pull": pull, "prefix": "upstream/oolite"}
