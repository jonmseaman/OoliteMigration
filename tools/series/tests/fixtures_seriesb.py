"""A small repository shaped like oolite-dev for the seriesb tool's tests.

    U         upstream master: src/a.c, src/js.c, tests/t1.txt, README
    series/   the old stack on U: 001 (a.c -> a2), 002 (js.c -> the fork's, + tests/t2.txt), 003 (a.c -> a3)
    develop   U + the old stack's end tree (the "squash"), then a commit to .zed/ (an exclusion)
    hob.git   "hobleyd": quickjs-poc = U + js.c -> js-poc; quickjs-default = poc + tools/x.txt, js.c -> js-def
    seriesb/  000a, 000b observed, tracking hobleyd/<their own names>; 001..003 replaying the old steps

Trees are made with plumbing, so no worktree or Git Town run is needed; the Git Town keys are set
directly, as `git town append` and `git town observe` would.
"""
import os

from tools.series.tests.fixtures import git, write

A = "seriesb/000a-upstream-767-quickjs-option"
B = "seriesb/000b-upstream-768-quickjs-only"
STEPS = ["seriesb/001-one", "seriesb/002-two", "seriesb/003-three"]
OLD = ["series/001-one", "series/002-two", "series/003-three"]


def tree_with(repo, base_tree, files):
    """`base_tree` with `files` ({path: text, or None to delete}) applied."""
    env_index = os.path.join(repo, ".git", "fixture-index")
    env = {"GIT_INDEX_FILE": env_index}
    import subprocess
    from tools.series.tests.fixtures import ENV
    run = lambda *a, inp=None: subprocess.run(["git", "-C", repo, *a], capture_output=True, text=True,
                                              encoding="utf-8", input=inp,
                                              env=dict(os.environ, **ENV, **env, GIT_CONFIG_GLOBAL=os.devnull),
                                              check=True).stdout.strip()
    run("read-tree", base_tree)
    for path, text in files.items():
        if text is None:
            run("rm", "--cached", "-q", "--", path)
        else:
            blob = run("hash-object", "-w", "--stdin", inp=text)
            run("update-index", "--add", "--cacheinfo", f"100644,{blob},{path}")
    t = run("write-tree")
    os.remove(env_index)
    return t


def commit(repo, tree, parents, msg):
    args = ["commit-tree", tree]
    for p in parents:
        args += ["-p", p]
    return git(repo, *args, "-m", msg)


def make_seriesb_repo(tmp):
    repo = os.path.join(tmp, "game")
    os.makedirs(repo)
    git(repo, "init", "-q", "-b", "develop")
    for rel, text in (("src/a.c", "a1\n"), ("src/js.c", "js1\n"), ("tests/t1.txt", "t1\n"), ("README", "r\n")):
        write(repo, rel, text)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "upstream master")
    u = git(repo, "rev-parse", "HEAD")
    ut = git(repo, "rev-parse", "HEAD^{tree}")

    # the old series on U
    git(repo, "branch", "series/000-upstream-base", u)
    old_trees = []
    t1 = tree_with(repo, ut, {"src/a.c": "a2\n"})
    t2 = tree_with(repo, t1, {"src/js.c": "js-fork\n", "tests/t2.txt": "t2\n"})
    t3 = tree_with(repo, t2, {"src/a.c": "a3\n"})
    parent, prev_branch = u, "series/000-upstream-base"
    for branch, t in zip(OLD, (t1, t2, t3)):
        c = commit(repo, t, [parent], f"Old {branch}")
        git(repo, "branch", branch, c)
        git(repo, "config", f"git-town-branch.{branch}.parent", prev_branch)
        old_trees.append(t)
        parent, prev_branch = c, branch

    # develop: the old end tree on U, then an excluded editor file
    squash = commit(repo, t3, [u], "Migrate")
    dev_only = commit(repo, tree_with(repo, t3, {".zed/settings.json": "{}\n"}), [squash], "Editor settings")
    git(repo, "update-ref", "refs/heads/develop", dev_only)
    git(repo, "reset", "-q", "--hard", "develop")
    git(repo, "config", "git-town.main-branch", "develop")

    # upstream's two stacked PRs, in a bare "hobleyd" repository
    poc = commit(repo, tree_with(repo, ut, {"src/js.c": "js-poc\n"}), [u], "QuickJS beside SpiderMonkey")
    dflt = commit(repo, tree_with(repo, git(repo, "rev-parse", f"{poc}^{{tree}}"),
                                  {"src/js.c": "js-def\n", "tools/x.txt": "x\n"}), [poc], "QuickJS only")
    hob = os.path.join(tmp, "hob.git")
    git(tmp, "init", "-q", "--bare", hob)
    git(repo, "branch", "fixture-poc", poc)
    git(repo, "branch", "fixture-default", dflt)
    git(hob, "fetch", "-q", repo, "fixture-poc:quickjs-poc", "fixture-default:quickjs-default")
    git(repo, "branch", "-D", "fixture-poc", "fixture-default")
    git(repo, "remote", "add", "hobleyd", hob)
    git(repo, "config", "--unset-all", "remote.hobleyd.fetch")
    git(repo, "config", "--add", "remote.hobleyd.fetch", f"+refs/heads/quickjs-poc:refs/remotes/hobleyd/{A}")
    git(repo, "config", "--add", "remote.hobleyd.fetch", f"+refs/heads/quickjs-default:refs/remotes/hobleyd/{B}")
    git(repo, "fetch", "-q", "hobleyd")
    for br in (A, B):
        git(repo, "branch", "-q", "--track", br, f"hobleyd/{br}")
        git(repo, "config", f"git-town-branch.{br}.branchtype", "observed")
    git(repo, "config", f"git-town-branch.{A}.parent", "develop")
    git(repo, "config", f"git-town-branch.{B}.parent", A)

    # seriesb: the old steps replayed on 000b (js.c takes the fork's side; tools/x.txt stays)
    dt = git(repo, "rev-parse", f"{dflt}^{{tree}}")
    b1 = tree_with(repo, dt, {"src/a.c": "a2\n"})
    b2 = tree_with(repo, b1, {"src/js.c": "js-fork\n", "tests/t2.txt": "t2\n"})
    b3 = tree_with(repo, b2, {"src/a.c": "a3\n"})
    parent, prev_branch, steps = dflt, B, []
    for i, (branch, t) in enumerate(zip(STEPS, (b1, b2, b3)), 1):
        c = commit(repo, t, [parent], f"Step {i}\n\nReplayed from {OLD[i - 1]}.")
        git(repo, "branch", branch, c)
        git(repo, "config", f"git-town-branch.{branch}.parent", prev_branch)
        git(repo, "config", f"git-town-branch.{branch}.branchtype", "prototype")
        steps.append({"n": i, "branch": branch, "parent": prev_branch, "title": f"Step {i}", "kind": "hand-written",
                      "description": f"series/pr/{i:03d}-{branch.split('-', 1)[1]}.md", "mechanical_command": None,
                      "source": {"type": "replay", "old_step": i, "old_branch": OLD[i - 1],
                                 "old_commit": git(repo, "rev-parse", OLD[i - 1])},
                      "build_commit": c, "target_tree": t, "resolutions": [], "differs_from_old": [],
                      "verification": {"commit": c, "tree": t, "after_sync": 0, "date": "2026-11-02",
                                       "checks": {"build_clang": "pass"}}})
        parent, prev_branch = c, branch

    parents = []
    for br, pr, track, head in ((A, 767, f"hobleyd/{A}", poc), (B, 768, f"hobleyd/{B}", dflt)):
        parents.append({"branch": br, "kind": "upstream", "upstream_pr": pr, "tracking": track, "head": head,
                        "parent": "develop" if br == A else A, "git_town_type": "observed", "gate": "pass",
                        "verification": {"commit": head, "checks": {"build_clang": "pass"}}})
    m = {"anchors": {"develop_target": dev_only, "upstream_master": u, "old_manifest": "unused"},
         "parents": parents, "steps": steps, "dropped": [],
         "exclusions": [{"path_glob": ".zed/**", "reason": "editor settings"}],
         "additions": [{"path_glob": "tools/**", "from_pr": 768, "reason": "upstream's own tool"}],
         "ledger": [], "syncs": []}
    baseline = {"branches": {b: git(repo, "rev-parse", b) for b in OLD + ["series/000-upstream-base", "develop"]}}
    return {"repo": repo, "hob": hob, "m": m, "baseline": baseline, "u": u, "poc": poc, "default": dflt,
            "develop_only": dev_only, "old_trees": old_trees}
