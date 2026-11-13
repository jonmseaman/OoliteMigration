import copy
import unittest

from tools.series.tests import test_replay


class HandoverPushTest(unittest.TestCase):
    """The handover's pushes are leased on origin's branches, and origin's obsolete names are deleted (T057)."""

    def render(self, remote):
        from tools.series import series
        return series.render_handover_replay(copy.deepcopy(test_replay.DescribeReplayTest.M), remote)

    def test_each_push_is_leased_on_origins_commit_or_on_absence(self):
        text = self.render({"seriesb/001-a": "e" * 40})
        self.assertIn(f"push --set-upstream --force-with-lease=refs/heads/seriesb/001-a:{'e' * 40} origin "
                      "seriesb/001-a:refs/heads/seriesb/001-a", text)
        self.assertIn("--force-with-lease=refs/heads/seriesb/002-b: origin seriesb/002-b:refs/heads/seriesb/002-b", text)

    def test_origins_names_that_are_no_step_or_parent_are_deleted(self):
        text = self.render({"seriesb/001-a": "e" * 40, "seriesb/003-old-name": "f" * 40,
                            "seriesb/000b-upstream-768-quickjs-only": "a" * 40})
        deletes = text.split("## Delete obsolete names on origin (Jon)")[1].split("## Git Town")[0]
        self.assertIn(f"--force-with-lease=refs/heads/seriesb/003-old-name:{'f' * 40} origin :refs/heads/seriesb/003-old-name",
                      deletes)
        self.assertNotIn(":refs/heads/seriesb/001-a", deletes)
        self.assertNotIn("000b", deletes)

    def test_nothing_to_delete_says_so(self):
        text = self.render({})
        self.assertIn("None: every seriesb branch on `origin` is a step or a parent.", text)
        self.assertNotRegex(text, r"<[a-z-]+>|…")


class DescriptionStateTest(unittest.TestCase):
    """Generated parts describe the branch as it is (T057)."""

    def test_a_record_for_another_commit_is_not_shown_as_verified(self):
        from tools.series import series
        m = copy.deepcopy(test_replay.DescribeReplayTest.M)
        text = series.render_description_replay(m, m["steps"][0], {}, tip="d" * 40)
        verified = text.split("## Verified")[1]
        self.assertIn(f"Not verified at `{'d' * 10}`", verified)
        self.assertNotIn("| build_clang | pass |", verified)
        current = series.render_description_replay(m, m["steps"][0], {}, tip="c" * 40)
        self.assertIn("| build_clang | pass |", current)

    def test_a_replayed_step_with_no_recorded_differences_has_no_differences_section(self):
        from tools.series import series
        m = copy.deepcopy(test_replay.DescribeReplayTest.M)
        text = series.render_description_replay(m, m["steps"][0], {})
        self.assertNotIn("Differences from the old step", text)
        self.assertNotIn("the same change as", text)

    def test_the_last_step_lists_the_existing_tests_it_changes(self):
        from tools.series import series
        m = copy.deepcopy(test_replay.DescribeReplayTest.M)
        m["steps"][1]["source"] = {"type": "target", "ref": "feature/x", "commit": "d" * 40,
                                   "test_ledger": "specs/x/series/test-changes.md"}
        text = series.render_description_replay(m, m["steps"][1], {}, tests_changed=["tests/unit/core/t.cpp"])
        self.assertIn("- `tests/unit/core/t.cpp`", text)
        self.assertNotIn("specs/x", text)
        self.assertNotIn("Switch:", text)
        none = series.render_description_replay(m, m["steps"][1], {}, tests_changed=[])
        self.assertNotIn("## Test changes", none)


if __name__ == "__main__":
    unittest.main()
