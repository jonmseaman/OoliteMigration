import copy
import tempfile
import unittest

from tools.series import seriesb
from tools.series.tests.fixtures import git
from tools.series.tests.fixtures_seriesb import A, B, STEPS, commit, make_seriesb_repo

GROUPS = ("manifest", "branches", "lineage", "baseline", "gates", "final-tree", "verified")


class SeriesbFixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.fx = make_seriesb_repo(cls.tmp.name)
        cls.repo = cls.fx["repo"]

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def setUp(self):
        self.m = copy.deepcopy(self.fx["m"])
        self.refs = git(self.repo, "for-each-ref", "--format=%(refname) %(objectname)")
        self.config = git(self.repo, "config", "--get-regexp", "^git-town")

    def tearDown(self):
        # put every ref and Git Town key back as the fixture made them
        for line in git(self.repo, "for-each-ref", "--format=%(refname)").splitlines():
            if line not in {l.split()[0] for l in self.refs.splitlines()}:
                git(self.repo, "update-ref", "-d", line)
        for line in self.refs.splitlines():
            ref, sha = line.split()
            git(self.repo, "update-ref", ref, sha)
        for line in git(self.repo, "config", "--get-regexp", "^git-town").splitlines():
            git(self.repo, "config", "--unset-all", line.split()[0])
        for line in self.config.splitlines():
            key, value = line.split(" ", 1)
            git(self.repo, "config", key, value)

    def problems(self, *groups):
        return seriesb.check(self.repo, self.m, set(groups or GROUPS), self.fx["baseline"])

    def assertRule(self, rule, problems):
        self.assertTrue(any(p.startswith(f"rule {rule}") for p in problems), problems)


class GoodStackTest(SeriesbFixture):
    def test_fixture_passes_every_rule(self):
        self.assertEqual(self.problems(), [])


class FileRulesTest(SeriesbFixture):
    def test_old_steps_must_increase(self):
        self.m["steps"][2]["source"]["old_step"] = 1
        self.assertRule("1", self.problems("manifest"))

    def test_fix_parent_needs_a_recorded_decision(self):
        self.m["parents"].append({"branch": "seriesb/000c-fix", "kind": "fix-parent", "parent": B})
        self.assertTrue(any("decision" in p for p in self.problems("manifest")))

    def test_upstream_master_parent_name_is_reserved(self):
        self.m["parents"].append({"branch": "seriesb/000c-x", "kind": "upstream-master", "parent": B})
        self.assertTrue(any("000m" in p for p in self.problems("manifest")))

    def test_dropped_step_needs_reason_and_pr(self):
        self.m["dropped"] = [{"old_step": 5, "old_branch": "series/005-x"}]
        self.assertTrue(any("dropped" in p for p in self.problems("manifest")))

    def test_bookkeeping_id_in_title(self):
        self.m["steps"][0]["title"] = "Fix oo-scnp"
        self.assertTrue(any("bead id" in p for p in self.problems("manifest")))


class RepoRulesTest(SeriesbFixture):
    def test_rule1_broken_chain(self):
        git(self.repo, "config", f"git-town-branch.{STEPS[1]}.parent", B)
        self.assertRule("1", self.problems("lineage"))

    def test_rule2_parent_not_at_its_tracking_head(self):
        git(self.repo, "update-ref", f"refs/heads/{B}", self.fx["poc"])
        self.assertRule("2", self.problems("branches"))

    def test_rule2_tracking_moved_without_a_refresh(self):
        git(self.repo, "update-ref", f"refs/remotes/hobleyd/{B}", self.fx["poc"])
        self.assertRule("2", self.problems("branches"))

    def test_rule3_plain_commit_after_the_build(self):
        tip = git(self.repo, "rev-parse", STEPS[1])
        c = commit(self.repo, git(self.repo, "rev-parse", f"{tip}^{{tree}}"), [tip], "a stray edit")
        git(self.repo, "update-ref", f"refs/heads/{STEPS[1]}", c)
        self.assertRule("3", self.problems("branches"))

    def test_rule3_sync_merge_is_accepted(self):
        # a sync merge: the step's tip and its parent's tip, as `git town sync` makes
        for i, branch in enumerate(STEPS):
            parent = B if i == 0 else STEPS[i - 1]
            tip, ptip = git(self.repo, "rev-parse", branch), git(self.repo, "rev-parse", parent)
            if git(self.repo, "merge-base", tip, ptip) == ptip:
                continue
            c = commit(self.repo, git(self.repo, "rev-parse", f"{tip}^{{tree}}"), [tip, ptip], "Merge")
            git(self.repo, "update-ref", f"refs/heads/{branch}", c)
        self.assertEqual([p for p in self.problems("branches") if p.startswith("rule 3")], [])

    def test_rule4_develop_commit_in_a_step(self):
        tip = git(self.repo, "rev-parse", STEPS[2])
        c = commit(self.repo, git(self.repo, "rev-parse", f"{tip}^{{tree}}"),
                   [tip, self.fx["develop_only"]], "Merge develop")
        git(self.repo, "update-ref", f"refs/heads/{STEPS[2]}", c)
        self.assertRule("4", self.problems("branches"))

    def test_rule5_moved_series_branch(self):
        git(self.repo, "update-ref", "refs/heads/series/002-two", self.fx["u"])
        self.assertRule("5", self.problems("baseline"))

    def test_rule6_unlisted_difference_from_develop(self):
        self.m["additions"] = []
        self.assertRule("6", self.problems("final-tree"))

    def test_rule6_addition_needs_a_reason(self):
        self.m["additions"] = [{"path_glob": "tools/**", "from_pr": 768}]
        self.assertRule("6", self.problems("final-tree"))

    def test_rule7_verification_older_than_the_latest_sync(self):
        self.m["syncs"] = [{"date": "2026-11-03", "conflicts": []}]
        self.assertRule("7", self.problems("verified"))

    def test_rule7_flagged_gate(self):
        self.m["parents"][1]["gate"] = "flagged"
        self.assertRule("7", self.problems("gates"))


class TestsAndMessagesTest(SeriesbFixture):
    def replace_tip(self, branch, files=None, message=None):
        from tools.series.tests.fixtures_seriesb import tree_with
        tip = git(self.repo, "rev-parse", branch)
        tree = git(self.repo, "rev-parse", f"{tip}^{{tree}}")
        if files:
            tree = tree_with(self.repo, tree, files)
        msg = message or git(self.repo, "log", "-1", "--format=%B", tip)
        c = commit(self.repo, tree, [git(self.repo, "rev-parse", f"{tip}^")], msg)
        git(self.repo, "update-ref", f"refs/heads/{branch}", c)

    def test_fixture_passes_tests_and_messages(self):
        self.assertEqual(self.problems("tests", "messages"), [])

    def test_a_step_that_edits_an_existing_test_the_old_step_did_not(self):
        self.replace_tip(STEPS[2], files={"tests/t1.txt": "t1, edited\n"})
        self.assertTrue(any("tests/t1.txt" in p for p in self.problems("tests")), self.problems("tests"))

    def test_a_step_that_deletes_an_existing_test(self):
        self.replace_tip(STEPS[2], files={"tests/t2.txt": None})
        self.assertTrue(any("tests/t2.txt" in p for p in self.problems("tests")))

    def test_a_bead_id_in_a_step_commit_message(self):
        self.replace_tip(STEPS[0], message="Step 1\n\nCloses oo-abc12.\n")
        self.assertTrue(any("oo-abc12" in p for p in self.problems("messages")), self.problems("messages"))

    def test_an_adr_number_in_a_step_commit_message(self):
        self.replace_tip(STEPS[1], message="Step 2\n\nPer ADR-0066.\n")
        self.assertTrue(any("ADR-0066" in p for p in self.problems("messages")))


if __name__ == "__main__":
    unittest.main()
