import os
import tempfile
import unittest

from tools.series import parents
from tools.series.tests.fixtures import git
from tools.series.tests.fixtures_seriesb import A, B, commit, make_seriesb_repo, tree_with


class ParentsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.fx = make_seriesb_repo(self.tmp.name, seriesb=False)
        self.repo, self.hob = self.fx["repo"], self.fx["hob"]
        self.remote = {"name": "hobleyd", "url": self.hob}
        self.m = {}

    def setup_parents(self):
        return parents.setup(self.repo, self.m, self.remote, anchors={"develop_target": self.fx["develop_only"],
                                                                     "upstream_master": self.fx["u"]})

    def push_to_hob(self, branch, sha, force=False):
        git(self.repo, "branch", "-f", "fixture-tmp", sha)
        git(self.hob, "fetch", "-q", self.repo, ("+" if force else "") + f"fixture-tmp:{branch}")
        git(self.repo, "branch", "-D", "fixture-tmp")

    def test_setup_creates_mirrors_lineage_and_records(self):
        self.setup_parents()
        fetch = git(self.repo, "config", "--get-all", "remote.hobleyd.fetch").splitlines()
        self.assertEqual(sorted(fetch), sorted([f"+refs/heads/quickjs-poc:refs/remotes/hobleyd/{A}",
                                                f"+refs/heads/quickjs-default:refs/remotes/hobleyd/{B}"]))
        self.assertEqual(git(self.repo, "rev-parse", A), self.fx["poc"])
        self.assertEqual(git(self.repo, "rev-parse", B), self.fx["default"])
        self.assertEqual(git(self.repo, "config", f"git-town-branch.{A}.parent"), "develop")
        self.assertEqual(git(self.repo, "config", f"git-town-branch.{B}.parent"), A)
        for b in (A, B):
            self.assertEqual(git(self.repo, "config", f"git-town-branch.{b}.branchtype"), "observed")
            self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", f"{b}@{{upstream}}"), f"hobleyd/{b}")
        recorded = {p["branch"]: p for p in self.m["parents"]}
        self.assertEqual(recorded[A]["head"], self.fx["poc"])
        self.assertEqual(recorded[B]["head"], self.fx["default"])
        self.assertEqual(recorded[B]["upstream_pr"], 768)
        self.assertEqual(recorded[A]["parent"], "develop")
        self.assertEqual(self.m["anchors"]["upstream_master"], self.fx["u"])
        self.assertEqual(parents.status(self.repo, self.m), [])
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD"), "develop")

    def test_second_setup_changes_nothing(self):
        self.setup_parents()
        refs = git(self.repo, "for-each-ref")
        config = git(self.repo, "config", "--list", "--local")
        before = repr(self.m)
        self.setup_parents()
        self.assertEqual(git(self.repo, "for-each-ref"), refs)
        self.assertEqual(git(self.repo, "config", "--list", "--local"), config)
        self.assertEqual(repr(self.m), before)

    def test_status_reports_a_parent_off_its_tracking_head(self):
        self.setup_parents()
        git(self.repo, "update-ref", f"refs/heads/{B}", self.fx["poc"])
        self.assertTrue(any(B in p for p in parents.status(self.repo, self.m)))

    def test_refresh_follows_a_new_commit_and_a_force_push(self):
        self.setup_parents()
        poc_t = git(self.repo, "rev-parse", f"{self.fx['poc']}^{{tree}}")
        new_default = commit(self.repo, tree_with(self.repo, git(self.repo, "rev-parse", f"{self.fx['default']}^{{tree}}"),
                                                  {"src/js.c": "js-def2\n"}), [self.fx["default"]], "more")
        self.push_to_hob("quickjs-default", new_default)
        parents.refresh(self.repo, self.m, self.remote)
        self.assertEqual(git(self.repo, "rev-parse", B), new_default)
        self.assertEqual({p["branch"]: p["head"] for p in self.m["parents"]}[B], new_default)
        rewritten = commit(self.repo, tree_with(self.repo, poc_t, {"src/js.c": "js-rewritten\n"}), [self.fx["poc"]], "rewritten")
        self.push_to_hob("quickjs-default", rewritten, force=True)
        parents.refresh(self.repo, self.m, self.remote)
        self.assertEqual(git(self.repo, "rev-parse", B), rewritten)
        self.assertEqual(parents.status(self.repo, self.m), [])

    def test_refresh_refuses_a_checked_out_parent(self):
        self.setup_parents()
        git(self.repo, "checkout", "-q", B)
        self.addCleanup(git, self.repo, "checkout", "-q", "develop")
        with self.assertRaises(SystemExit):
            parents.refresh(self.repo, self.m, self.remote)


if __name__ == "__main__":
    unittest.main()
