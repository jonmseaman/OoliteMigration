import os
import tempfile
import unittest

from tools.series import stack
from tools.series.tests.fixtures import git, make_history_repo


class StackTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        fx = make_history_repo(self.tmpdir.name)
        self.repo = g = fx["game"]
        self.fx = fx
        git(g, "config", "git-town.main-branch", "master")
        git(g, "branch", stack.ROOT_BRANCH, fx["u2"])
        git(g, "config", "git-town.perennial-branches", stack.ROOT_BRANCH)
        self.wt = os.path.join(self.tmpdir.name, "stack-wt")

    def tearDown(self):
        git(self.repo, "worktree", "remove", "--force", self.wt) if os.path.isdir(self.wt) else None
        self.tmpdir.cleanup()

    def step(self, branch, parent, tree, msg):
        return stack.make_step(self.repo, self.wt, branch, parent, tree, msg)

    def test_steps_chain_with_single_commits_and_lineage(self):
        t1 = git(self.repo, "rev-parse", f"{self.fx['u0']}^{{tree}}")
        t2 = git(self.repo, "rev-parse", f"{self.fx['u1']}^{{tree}}")
        c1 = self.step("series/001-one", stack.ROOT_BRANCH, t1, "Step one\n")
        c2 = self.step("series/002-two", "series/001-one", t2, "Step two\n")
        self.assertEqual(git(self.repo, "rev-parse", "series/001-one"), c1)
        self.assertEqual(git(self.repo, "rev-parse", f"{c1}^"), git(self.repo, "rev-parse", stack.ROOT_BRANCH))
        self.assertEqual(git(self.repo, "rev-parse", f"{c2}^"), c1)
        self.assertEqual(git(self.repo, "rev-parse", f"{c2}^{{tree}}"), t2)
        self.assertEqual(stack.lineage(self.repo, "series/002-two"), "series/001-one")
        self.assertEqual(stack.lineage(self.repo, "series/001-one"), stack.ROOT_BRANCH)
        self.assertEqual(git(self.repo, "config", "--get", "git-town-branch.series/002-two.branchtype"), "prototype")
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD"), "master")  # main checkout untouched

    def test_rebuilding_a_step_resets_it_to_one_commit_on_the_new_parent_tip(self):
        t1 = git(self.repo, "rev-parse", f"{self.fx['u0']}^{{tree}}")
        t2 = git(self.repo, "rev-parse", f"{self.fx['u1']}^{{tree}}")
        self.step("series/001-one", stack.ROOT_BRANCH, t1, "one\n")
        self.step("series/002-two", "series/001-one", t2, "two\n")
        c1b = self.step("series/001-one", stack.ROOT_BRANCH, t2, "one again\n")
        c2b = self.step("series/002-two", "series/001-one", t2, "two again\n")
        self.assertEqual(git(self.repo, "rev-parse", f"{c2b}^"), c1b)
        self.assertEqual(git(self.repo, "rev-list", "--count", f"{stack.ROOT_BRANCH}..series/002-two"), "2")

    def test_wrong_lineage_is_repaired(self):
        t1 = git(self.repo, "rev-parse", f"{self.fx['u0']}^{{tree}}")
        self.step("series/001-one", stack.ROOT_BRANCH, t1, "one\n")
        self.step("series/002-two", "series/001-one", t1, "two\n")
        git(self.repo, "config", "git-town-branch.series/002-two.parent", stack.ROOT_BRANCH)
        self.step("series/002-two", "series/001-one", t1, "two\n")
        self.assertEqual(stack.lineage(self.repo, "series/002-two"), "series/001-one")


if __name__ == "__main__":
    unittest.main()
