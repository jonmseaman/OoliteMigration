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


if __name__ == "__main__":
    unittest.main()
