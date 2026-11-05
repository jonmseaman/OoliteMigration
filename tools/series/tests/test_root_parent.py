import copy
import unittest

from tools.series import seriesb
from tools.series.tests import test_replay
from tools.series.tests.fixtures import git
from tools.series.tests.fixtures_seriesb import A
from tools.series.tests.test_seriesb_manifest import SeriesbFixture


class RootParentTest(SeriesbFixture):
    """Jon, 2026-11-04: PRs inside the fork target upstream-master, the first parent's Git Town parent."""

    def test_default_root_is_develop(self):
        self.assertEqual(seriesb.root_parent(self.m), "develop")
        self.assertEqual(seriesb.check(self.repo, self.m, {"manifest", "lineage"}), [])

    def test_the_manifest_can_name_another_root(self):
        git(self.repo, "config", f"git-town-branch.{A}.parent", "upstream-master")
        self.assertTrue(any("expected 'develop'" in p for p in seriesb.check(self.repo, self.m, {"lineage"})))
        self.m["anchors"]["root_parent"] = "upstream-master"
        self.m["parents"][0]["parent"] = "upstream-master"
        self.assertEqual(seriesb.check(self.repo, self.m, {"manifest", "lineage"}), [])


class RootParentHandoverTest(unittest.TestCase):
    def test_a_root_other_than_develop_is_pushed_and_never_deleted(self):
        from tools.series import series
        m = copy.deepcopy(test_replay.DescribeReplayTest.M)
        m["anchors"]["root_parent"] = "upstream-master"
        text = series.render_handover_replay(m, {"upstream-master": "b" * 40})
        self.assertIn(f"--force-with-lease=refs/heads/upstream-master:{'b' * 40} origin upstream-master:refs/heads/upstream-master",
                      text)
        self.assertNotIn(":refs/heads/upstream-master\n", text.split("## Delete obsolete names on origin (Jon)")[1].replace(
            "upstream-master:refs", ""))
        plain = series.render_handover_replay(copy.deepcopy(test_replay.DescribeReplayTest.M), {})
        self.assertNotIn("refs/heads/upstream-master", plain)


del SeriesbFixture  # run its tests in their own module only

if __name__ == "__main__":
    unittest.main()
