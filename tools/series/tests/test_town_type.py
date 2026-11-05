import unittest

from tools.series import seriesb
from tools.series.tests.fixtures import git
from tools.series.tests.fixtures_seriesb import STEPS
from tools.series.tests.test_seriesb_manifest import SeriesbFixture


class StepTownTypeTest(SeriesbFixture):
    """Jon, 2026-11-04: steps are feature branches so git town sync pushes them."""

    def lineage(self):
        return seriesb.check(self.repo, self.m, {"lineage"})

    def test_feature_steps_pass(self):
        self.assertEqual(self.lineage(), [])

    def test_a_prototype_step_is_reported(self):
        git(self.repo, "config", f"git-town-branch.{STEPS[1]}.branchtype", "prototype")
        problems = self.lineage()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("expected feature", problems[0])


del SeriesbFixture  # run its tests in their own module only

if __name__ == "__main__":
    unittest.main()
