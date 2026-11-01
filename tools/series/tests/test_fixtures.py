import tempfile
import unittest

from tools.series.tests.fixtures import git, make_history_repo


class FixtureTest(unittest.TestCase):
    def test_builds_history_with_six_first_parent_merges(self):
        with tempfile.TemporaryDirectory() as tmp:
            fx = make_history_repo(tmp)
            out = git(fx["super"], "rev-list", "--first-parent", "--merges", f"{fx['s0']}..main")
            self.assertEqual(len(out.split()), 6)
            subjects = git(fx["super"], "log", "--first-parent", "--merges", "--format=%s", "main").splitlines()
            self.assertTrue(all(s.startswith("bead oo-") and s.endswith("merge into main") for s in subjects))
            self.assertEqual(git(fx["super"], "rev-parse", f"{fx['s0']}:upstream/oolite"),
                             git(fx["game"], "rev-parse", f"{fx['u0']}^{{tree}}"))
            self.assertIn("upstream edit", git(fx["game"], "show", "master:src/b.m"))


if __name__ == "__main__":
    unittest.main()
