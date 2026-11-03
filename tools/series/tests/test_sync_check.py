import os
import subprocess
import tempfile
import unittest

from tools.series import parents, seriesb, sync
from tools.series.tests.fixtures import ENV, git
from tools.series.tests.fixtures_seriesb import A, B, STEPS, commit, make_seriesb_repo, tree_with


def town(repo, *args):
    env = dict(os.environ, **ENV, GIT_CONFIG_GLOBAL=os.devnull)
    return subprocess.run(["git", "town", *args], cwd=repo, capture_output=True, text=True, encoding="utf-8", env=env)


class SyncTest(unittest.TestCase):
    """A sync as Jon or an agent runs it: refresh the parents, `git town sync --stack --detached
    --no-push`, then `sync-record` (research R2, R9)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        fx = self.fx = make_seriesb_repo(self.tmp.name)
        self.repo, self.hob, self.m = fx["repo"], fx["hob"], fx["m"]
        self.remote = {"name": "hobleyd", "url": self.hob}
        # an origin, as oolite-dev has (Git Town's dev remote); nothing may be pushed to it
        self.origin = os.path.join(self.tmp.name, "origin.git")
        git(self.tmp.name, "init", "-q", "--bare", self.origin)
        git(self.repo, "remote", "add", "origin", self.origin)
        git(self.repo, "push", "-q", "origin", "develop")
        git(self.repo, "config", "git-town.dev-remote", "origin")
        git(self.repo, "config", "user.name", "t")
        git(self.repo, "config", "user.email", "t@t")
        self.baseline = fx["baseline"]

    def upstream_adds_a_commit(self):
        """A new commit on #767's branch, merged into #768's (as the PR author does)."""
        poc_t = git(self.repo, "rev-parse", f"{self.fx['poc']}^{{tree}}")
        poc2 = commit(self.repo, tree_with(self.repo, poc_t, {"README": "r, now with QuickJS\n"}), [self.fx["poc"]], "poc 2")
        dft_t = git(self.repo, "rev-parse", f"{self.fx['default']}^{{tree}}")
        merged = commit(self.repo, tree_with(self.repo, dft_t, {"README": "r, now with QuickJS\n"}),
                        [self.fx["default"], poc2], "Merge quickjs-poc")
        for branch, sha in (("quickjs-poc", poc2), ("quickjs-default", merged)):
            git(self.repo, "branch", "-f", "fixture-tmp", sha)
            git(self.hob, "fetch", "-q", self.repo, f"+fixture-tmp:{branch}")
        git(self.repo, "branch", "-D", "fixture-tmp")
        return poc2, merged

    def sync(self):
        parents.refresh(self.repo, self.m, self.remote)
        git(self.repo, "checkout", "-q", STEPS[-1])
        r = town(self.repo, "sync", "--stack", "--detached", "--no-push")
        git(self.repo, "checkout", "-q", "develop")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_sync_brings_the_new_commits_down_and_records_it(self):
        origin_before = git(self.repo, "ls-remote", self.origin)
        poc2, merged = self.upstream_adds_a_commit()
        self.sync()
        sync.record(self.repo, self.m, "git town sync --stack --detached --no-push",
                    [(2, "src/js.c", "nothing really; a test of the record")])
        self.assertEqual(git(self.repo, "rev-parse", A), poc2)
        self.assertEqual(git(self.repo, "rev-parse", B), merged)
        for b in STEPS:
            contained = subprocess.run(["git", "-C", self.repo, "merge-base", "--is-ancestor", merged, b]).returncode
            self.assertEqual(contained, 0, f"{b} lacks #768's new head")
        rec = self.m["syncs"][-1]
        self.assertEqual(rec["parent_heads_after"][B], merged)
        self.assertNotEqual(rec["parent_heads_before"][B], merged)
        self.assertEqual(rec["conflicts"], [{"step": 2, "path": "src/js.c", "reason": "nothing really; a test of the record"}])
        self.assertTrue(all(s["state"] == "stale" for s in self.m["steps"]))
        groups = {"lineage", "branches", "baseline", "final-tree"}
        self.assertEqual(seriesb.check(self.repo, self.m, groups, self.baseline), [])
        stale = seriesb.check(self.repo, self.m, {"verified"}, self.baseline)
        for n in (1, 2, 3):  # every step must be verified again after the sync
            self.assertTrue(any(p.startswith(f"rule 7: step {n}") for p in stale), stale)
        self.assertEqual(git(self.repo, "ls-remote", self.origin), origin_before)  # nothing pushed

    def test_sync_record_without_a_refresh_still_records_the_heads(self):
        sync.record(self.repo, self.m, "git town sync --stack --detached --no-push", [])
        rec = self.m["syncs"][-1]
        self.assertEqual(rec["parent_heads_before"], rec["parent_heads_after"])

    def test_a_merge_of_develop_fails_rule_4(self):
        tip = git(self.repo, "rev-parse", STEPS[1])
        c = commit(self.repo, git(self.repo, "rev-parse", f"{tip}^{{tree}}"), [tip, self.fx["develop_only"]], "Merge develop")
        git(self.repo, "update-ref", f"refs/heads/{STEPS[1]}", c)
        self.assertTrue(any(p.startswith("rule 4") for p in seriesb.check(self.repo, self.m, {"branches"}, self.baseline)))

    def test_a_plain_commit_after_the_build_fails_rule_3(self):
        tip = git(self.repo, "rev-parse", STEPS[0])
        c = commit(self.repo, git(self.repo, "rev-parse", f"{tip}^{{tree}}"), [tip], "edit")
        git(self.repo, "update-ref", f"refs/heads/{STEPS[0]}", c)
        self.assertTrue(any(p.startswith("rule 3") for p in seriesb.check(self.repo, self.m, {"branches"}, self.baseline)))


class RetireTest(unittest.TestCase):
    """FR-011a: once #767/#768 are in upstream master, step 1 moves onto a perennial copy of master."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        fx = self.fx = make_seriesb_repo(self.tmp.name)
        self.repo, self.m = fx["repo"], fx["m"]
        self.upstream_ref = "refs/remotes/upstream/master"

    def test_refused_while_the_prs_are_not_merged(self):
        git(self.repo, "update-ref", self.upstream_ref, self.fx["u"])
        with self.assertRaises(SystemExit):
            parents.retire(self.repo, self.m, self.upstream_ref)

    def test_retire_moves_step_1_onto_upstream_master(self):
        dft_t = git(self.repo, "rev-parse", f"{self.fx['default']}^{{tree}}")
        master = commit(self.repo, dft_t, [self.fx["u"], self.fx["default"]], "Merge #767 and #768")
        git(self.repo, "update-ref", self.upstream_ref, master)
        parents.retire(self.repo, self.m, self.upstream_ref)
        new = "seriesb/000m-upstream-master"
        self.assertEqual(git(self.repo, "rev-parse", new), master)
        self.assertIn(new, git(self.repo, "config", "--get-all", "git-town.perennial-branches").split())
        self.assertEqual(git(self.repo, "config", f"git-town-branch.{STEPS[0]}.parent"), new)
        self.assertEqual(self.m["steps"][0]["parent"], new)
        self.assertEqual([p["state"] for p in self.m["parents"] if p["kind"] == "upstream"], ["retired", "retired"])
        self.assertEqual(seriesb.root(self.m), new)
        for b in (A, B):  # deleting is Jon's
            self.assertTrue(git(self.repo, "rev-parse", "--verify", b))
        self.assertEqual(seriesb.validate(self.m), [])
        self.assertEqual([p for p in seriesb.check(self.repo, self.m, {"lineage"}) if "000m" in p], [])


if __name__ == "__main__":
    unittest.main()
