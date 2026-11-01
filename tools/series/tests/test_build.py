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


if __name__ == "__main__":
    unittest.main()
