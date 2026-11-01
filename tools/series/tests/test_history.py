import tempfile
import unittest

from tools.series import history
from tools.series.tests.fixtures import git, make_history_repo


class HistoryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.fx = make_history_repo(cls.tmp.name)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_first_parent_lists_merges_and_the_pull_in_order(self):
        fx = self.fx
        rows = history.first_parent(fx["super"], fx["prefix"], fx["s0"], "main")
        self.assertEqual([r["commit"] for r in rows], fx["merges"] + [fx["pull"]])
        self.assertEqual([r["merge"] for r in rows], [True] * 6 + [False])
        self.assertEqual(rows[1]["bead"], "oo-1bf.3")
        self.assertEqual(rows[1]["phase"], "P0")
        self.assertEqual(rows[0]["phase"], "?")
        self.assertEqual(rows[-1]["bead"], "oo-we7mm")

    def test_snapshot_is_the_prefix_tree(self):
        fx = self.fx
        self.assertEqual(history.snapshot(fx["super"], fx["s0"], fx["prefix"]),
                         git(fx["game"], "rev-parse", f"{fx['u0']}^{{tree}}"))

    def test_upstream_under_switches_at_the_pull(self):
        fx = self.fx
        pulls = [(fx["pull"], "U2")]
        self.assertEqual(history.upstream_under(fx["super"], fx["merges"][-1], base="U0", pulls=pulls), "U0")
        self.assertEqual(history.upstream_under(fx["super"], fx["pull"], base="U0", pulls=pulls), "U2")

    def test_phase_of_bead(self):
        self.assertEqual(history.phase_of("oo-9ht.39.28"), "P3")
        self.assertEqual(history.phase_of("oo-6e1.2"), "P4")
        self.assertEqual(history.phase_of("oo-xu228"), "?")
        self.assertEqual(history.phase_of(None), "?")


if __name__ == "__main__":
    unittest.main()
