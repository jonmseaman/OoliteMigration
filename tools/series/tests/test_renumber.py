import os
import tempfile
import unittest

from tools.series import renumber
from tools.series.tests.fixtures import commit_all, git, init, write

ROOT = "series/000-upstream-base"


class RenumberTest(unittest.TestCase):
    """A step hoisted to the front: the old 001 and 002 become 002 and 003, the new step is 001."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = init(os.path.join(self.tmp.name, "game"), "master")
        write(self.repo, "a", "a\n")
        commit_all(self.repo, "base", 0)
        git(self.repo, "branch", ROOT)
        for b, parent in (("series/001-first", ROOT), ("series/002-second", "series/001-first")):
            git(self.repo, "branch", b)
            git(self.repo, "config", f"git-town-branch.{b}.parent", parent)
            git(self.repo, "config", f"git-town-branch.{b}.branchtype", "prototype")
        self.sd = os.path.join(self.tmp.name, "series")
        for name in ("001-first", "002-second"):
            write(self.sd, f"pr/{name}.md", f"# {name}\n")
            write(self.sd, f"resolutions/{name[:3]}/index.json", f'"{name}"\n')
        self.m = {"steps": [
            {"n": 1, "branch": "series/001-hoisted", "parent": ROOT, "description": "series/pr/001-hoisted.md"},
            {"n": 2, "branch": "series/001-first", "parent": "series/001-hoisted", "description": "series/pr/001-first.md"},
            {"n": 3, "branch": "series/002-second", "parent": "series/001-first", "description": "series/pr/002-second.md"},
        ]}

    def tearDown(self):
        self.tmp.cleanup()

    def cfg(self, key):
        return git(self.repo, "config", "--get", key)

    def read(self, rel):
        with open(os.path.join(self.sd, rel), encoding="utf-8") as f:
            return f.read()

    def test_moves_list_only_misnumbered_steps(self):
        self.assertEqual([(old, new) for _, old, new in renumber.moves(self.m)],
                         [(1, "series/002-first"), (2, "series/003-second")])

    def test_moves_skip_a_dropped_steps_kept_number(self):
        # old 002 dropped, keeping its number: 003 stays 003, a misnumbered 002 moves past the gap
        m = {"steps": [{"n": 1, "branch": "series/001-first"}, {"n": 2, "branch": "series/003-third"},
                       {"n": 3, "branch": "series/003-fourth"}],
             "dropped": [{"old_step": 2, "old_branch": "series/002-second", "number": 2}]}
        self.assertEqual([(old, new) for _, old, new in renumber.moves(m)], [(3, "series/004-fourth")])

    def test_branches_files_and_lineage_follow_n(self):
        renumber.apply(self.repo, self.sd, self.m, ROOT)
        self.assertEqual([s["branch"] for s in self.m["steps"]],
                         ["series/001-hoisted", "series/002-first", "series/003-second"])
        self.assertEqual([s["parent"] for s in self.m["steps"]],
                         [ROOT, "series/001-hoisted", "series/002-first"])
        self.assertEqual(self.m["steps"][2]["description"], "series/pr/003-second.md")
        branches = git(self.repo, "branch", "--format=%(refname:short)").splitlines()
        self.assertEqual(sorted(b for b in branches if b.startswith("series/")),
                         [ROOT, "series/002-first", "series/003-second"])
        self.assertEqual(self.cfg("git-town-branch.series/003-second.parent"), "series/002-first")
        self.assertEqual(self.cfg("git-town-branch.series/002-first.branchtype"), "prototype")
        self.assertEqual(self.cfg("git-town-branch.series/002-first.parent"), "series/001-hoisted")
        with self.assertRaises(RuntimeError):  # the old name's config went with the branch
            git(self.repo, "config", "--get-regexp", "^git-town-branch\\.series/001-first\\.")
        self.assertEqual(self.read("pr/002-first.md"), "# 001-first\n")
        self.assertEqual(self.read("pr/003-second.md"), "# 002-second\n")
        self.assertFalse(os.path.exists(os.path.join(self.sd, "pr", "001-first.md")))
        self.assertEqual(self.read("resolutions/002/index.json"), '"001-first"\n')
        self.assertEqual(self.read("resolutions/003/index.json"), '"002-second"\n')
        self.assertFalse(os.path.exists(os.path.join(self.sd, "resolutions", "001")))

    def test_second_run_changes_nothing(self):
        renumber.apply(self.repo, self.sd, self.m, ROOT)
        self.assertEqual(renumber.moves(self.m), [])


if __name__ == "__main__":
    unittest.main()
