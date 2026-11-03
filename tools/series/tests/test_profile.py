import os
import unittest

from tools.series import manifest, profile, renumber, series, stack, verify

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


class ProfileTest(unittest.TestCase):
    def setUp(self):
        self.addCleanup(profile.activate, "series")

    def test_series_profile_is_feature_001(self):
        p = profile.get("series")
        self.assertEqual(p["prefix"], "series/")
        self.assertEqual(os.path.normpath(p["dir"]),
                         os.path.normpath(os.path.join(ROOT, "specs", "001-split-migration-prs", "series")))
        self.assertEqual(p["root"], "series/000-upstream-base")

    def test_seriesb_profile_root_is_the_last_parent(self):
        p = profile.get("seriesb", {})
        self.assertEqual(p["prefix"], "seriesb/")
        self.assertEqual(os.path.normpath(p["dir"]),
                         os.path.normpath(os.path.join(ROOT, "specs", "002-seriesb-rebase-stack", "series")))
        self.assertEqual(p["root"], "seriesb/000b-upstream-768-quickjs-only")
        m = {"parents": [{"branch": "seriesb/000a-upstream-767-quickjs-option", "kind": "upstream"},
                         {"branch": "seriesb/000b-upstream-768-quickjs-only", "kind": "upstream"},
                         {"branch": "seriesb/000c-fix-thing", "kind": "fix-parent"}]}
        self.assertEqual(profile.get("seriesb", m)["root"], "seriesb/000c-fix-thing")

    def test_retired_parents_are_skipped(self):
        m = {"parents": [{"branch": "seriesb/000a-x", "kind": "upstream", "state": "retired"},
                         {"branch": "seriesb/000m-upstream-master", "kind": "upstream-master"},
                         {"branch": "seriesb/000b-y", "kind": "upstream", "state": "retired"}]}
        self.assertEqual(profile.get("seriesb", m)["root"], "seriesb/000m-upstream-master")

    def test_unknown_profile(self):
        with self.assertRaises(KeyError):
            profile.get("seriesc")

    def test_seriesb_make_step_refuses_other_branches(self):
        profile.activate("seriesb", {})
        for branch in ("develop", "master", "main", "series/001-x", "other/001-x"):
            with self.assertRaises(ValueError, msg=branch):
                stack.make_step("unused-repo", "unused-wt", branch, "seriesb/000b-x", "0" * 40, "m\n")

    def test_series_make_step_refuses_seriesb_branches(self):
        profile.activate("series")
        with self.assertRaises(ValueError):
            stack.make_step("unused-repo", "unused-wt", "seriesb/001-x", stack.ROOT_BRANCH, "0" * 40, "m\n")

    def test_seriesb_branch_pattern(self):
        profile.activate("seriesb", {})
        self.assertTrue(manifest.BRANCH_RE.match("seriesb/001-a-b"))
        self.assertIsNone(manifest.BRANCH_RE.match("seriesb/1-a"))
        self.assertIsNone(manifest.BRANCH_RE.match("seriesb/000a-x"))
        self.assertIsNone(manifest.BRANCH_RE.match("series/001-a"))
        self.assertTrue(renumber.BRANCH_RE.match("seriesb/004-objective-cxx"))

    def test_activation_rebinds_and_restores_module_names(self):
        before = (series.SERIES_DIR, series.MANIFEST, series.HANDOVER, stack.ROOT_BRANCH, manifest.ROOT_BRANCH,
                  manifest.BRANCH_RE.pattern, renumber.BRANCH_RE.pattern, verify.TEST_WARNINGS)
        profile.activate("seriesb", {})
        self.assertIn("002-seriesb-rebase-stack", series.SERIES_DIR)
        self.assertTrue(series.MANIFEST.startswith(series.SERIES_DIR))
        self.assertTrue(series.HANDOVER.startswith(series.SERIES_DIR))
        self.assertEqual(stack.ROOT_BRANCH, "seriesb/000b-upstream-768-quickjs-only")
        self.assertEqual(manifest.ROOT_BRANCH, stack.ROOT_BRANCH)
        self.assertTrue(verify.TEST_WARNINGS.startswith(series.SERIES_DIR))
        self.assertNotEqual(series.STACK_WORKTREE, profile.get("series")["stack_worktree"])
        profile.activate("series")
        after = (series.SERIES_DIR, series.MANIFEST, series.HANDOVER, stack.ROOT_BRANCH, manifest.ROOT_BRANCH,
                 manifest.BRANCH_RE.pattern, renumber.BRANCH_RE.pattern, verify.TEST_WARNINGS)
        self.assertEqual(before, after)

    def test_cli_accepts_the_series_option(self):
        args = series.parser().parse_args(["--series", "seriesb", "check", "--only", "manifest"])
        self.assertEqual(args.series, "seriesb")
        self.assertEqual(series.parser().parse_args(["check"]).series, "series")


if __name__ == "__main__":
    unittest.main()
