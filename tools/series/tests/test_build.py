import os
import re
import unittest

from tools.series import series

BOOKKEEPING = re.compile(r"\boo-[a-z0-9]{2,5}\b|\bADR[- ]?\d|docs/phases|OoliteMigration|\bbead")


class CommitMessageTest(unittest.TestCase):
    def test_history_step_names_phase_and_work_items_only(self):
        step = {"title": "Compile the game as Objective-C++", "source": {"type": "history"},
                "chapter": {"phase": "P2", "work_items": ["2.1 the .m -> .mm switch"], "first": "a" * 40,
                            "last": "b" * 40, "merges": 1}}
        msg = series.commit_message(step)
        self.assertEqual(msg, "Compile the game as Objective-C++\n\nMigration phase 2: 2.1 the .m -> .mm switch.\n")
        self.assertNotIn("a" * 10, msg)  # history commits are not reachable for reviewers

    def test_tail_step_lists_develop_commits(self):
        step = {"title": "Small fixes", "chapter": None, "source": {"type": "develop", "commits": ["c" * 40, "d" * 40]}}
        self.assertIn("cccccccccc, dddddddddd", series.commit_message(step))

    def test_no_bookkeeping_ids_in_any_planned_message(self):
        m = series.load_manifest()
        for step in m.get("steps", []):
            self.assertIsNone(BOOKKEEPING.search(series.commit_message(step)), step["branch"])


class DescriptionCheckTest(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory()
        os.makedirs(os.path.join(self.tmp.name, "pr"))
        self.old = series.SERIES_DIR
        series.SERIES_DIR = self.tmp.name
        self.step = {"n": 3, "title": "Do a thing", "description": "series/pr/003-thing.md"}

    def tearDown(self):
        series.SERIES_DIR = self.old
        self.tmp.cleanup()

    def write(self, sections, extra=""):
        body = "".join(f"## {h}\n\n{t}\n\n" for h, t in sections.items())
        with open(os.path.join(self.tmp.name, "pr", "003-thing.md"), "w", encoding="utf-8") as f:
            f.write(f"# Do a thing\n\n{extra}\n\n{body}## Verified **(gen)**\n\nNot verified yet.\n")

    def test_written_description_passes(self):
        self.write({h: "Text." for h in series.HAND_SECTIONS})
        self.assertEqual(series.check_descriptions({}, self.step), [])

    def test_unwritten_and_missing_sections_fail(self):
        self.write({"What this changes": "Text.", "Why": series.TODO})
        problems = series.check_descriptions({}, self.step)
        self.assertTrue(any("'Why' is not written" in p for p in problems))
        self.assertTrue(any("lacks '## How to review'" in p for p in problems))

    def test_bookkeeping_id_fails(self):
        self.write({h: "Text." for h in series.HAND_SECTIONS}, extra="Closes oo-scnp.")
        self.assertTrue(any(p.startswith("rule 9") for p in series.check_descriptions({}, self.step)))

    def test_missing_file_fails(self):
        self.assertTrue(series.check_descriptions({}, self.step)[0].startswith("rule 8"))


class FinalTreeTest(unittest.TestCase):
    """Rule 7: the last step is develop_target with the exclusions applied, and each has a reason."""

    def setUp(self):
        import tempfile
        from tools.series.tests.fixtures import commit_all, git, init, write
        self.tmp = tempfile.TemporaryDirectory()
        g = init(os.path.join(self.tmp.name, "game"), "master")
        write(g, "src/a.cpp", "a\n")
        write(g, "ci.yaml", "on: push\n")
        commit_all(g, "base", 0)
        write(g, "ci.yaml", "on: push\nbranches: [develop]\n")
        self.filter = commit_all(g, "CI filter", 1)
        write(g, "src/a.cpp", "a2\n")
        write(g, ".zed/settings.json", "{}\n")
        self.target = commit_all(g, "fix", 2)
        git(g, "checkout", "-q", "-b", "series/last")
        git(g, "revert", "--no-edit", self.filter)
        self.git, self.repo = git, g
        self.old = series.GAME
        series.GAME = g
        self.m = {"anchors": {"develop_target": self.target},
                  "exclusions": [{"path_glob": ".zed/**", "reason": "editor settings"},
                                 {"revert_commit": self.filter, "reason": "the fork's CI filter"}]}
        self.step = {"branch": "series/last"}

    def tearDown(self):
        series.GAME = self.old
        self.tmp.cleanup()

    def test_reverted_commit_is_not_a_difference(self):
        self.assertEqual(series.check_final_tree(self.m, self.step), [])

    def test_other_difference_fails(self):
        from tools.series.tests.fixtures import commit_all, write
        write(self.repo, "src/a.cpp", "a3\n")
        commit_all(self.repo, "drift", 3)
        self.assertEqual(series.check_final_tree(self.m, self.step),
                         ["rule 7: last step differs from develop_target at src/a.cpp"])

    def test_exclusion_without_reason_fails(self):
        self.m["exclusions"][0]["reason"] = " "
        self.assertEqual(series.check_final_tree(self.m, self.step),
                         ["rule 7: exclusion '.zed/**' has no reason"])


if __name__ == "__main__":
    unittest.main()
