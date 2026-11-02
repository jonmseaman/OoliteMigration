import tempfile
import unittest

from tools.series import hoist, history, trees
from tools.series.tests.fixtures import git, make_history_repo


def steps(*kinds):
    out = []
    for i, k in enumerate(kinds, 1):
        out.append({"n": i, "branch": f"series/{i:03d}-s{i}", "kind": k, "parent": None,
                    "target_tree": f"t{i}", "merge_tree": f"t{i}"})
    return {"steps": out}


class HoistTreeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.h = make_history_repo(self.tmp.name)
        self.repo = self.h["super"]
        self.snap = lambda c: history.snapshot(self.repo, c, self.h["prefix"])
        self.base = git(self.repo, "rev-parse", f"{self.h['u2']}^{{tree}}")

    def tearDown(self):
        self.tmp.cleanup()

    def blob(self, tree, path):
        r = trees._git(self.repo, "rev-parse", "-q", "--verify", f"{tree}:{path}", ok=(0, 1, 128))
        return r.stdout.decode().strip() and git(self.repo, "cat-file", "blob", f"{tree}:{path}")

    def test_clean_change_lands_on_the_base_and_nothing_else_moves(self):
        d = self.h["merges"][5]  # oo-6e1.1 adds src/d.cpp
        tree = hoist.hoisted_tree(self.repo, self.base, [d], self.snap)
        self.assertEqual(self.blob(tree, "src/d.cpp"), "int d() { return 6; }")
        changed = git(self.repo, "diff", "--name-only", self.base, tree).splitlines()
        self.assertEqual(changed, ["src/d.cpp"])

    def test_change_upstream_also_made_does_not_apply(self):
        b = self.h["merges"][3]  # oo-3rb.7 edits src/b.m, which upstream's U2 edited too
        with self.assertRaises(hoist.DoesNotApply) as e:
            hoist.hoisted_tree(self.repo, self.base, [b], self.snap)
        self.assertIn("src/b.m", str(e.exception))

    def test_commits_stack_in_order(self):
        c1, c2 = self.h["merges"][2], self.h["merges"][4]  # c.cpp added, then edited
        tree = hoist.hoisted_tree(self.repo, self.base, [c1, c2], self.snap)
        self.assertEqual(self.blob(tree, "src/c.cpp"), "int c() {   return 5; }")


class InsertTest(unittest.TestCase):
    def test_goes_after_existing_independent_steps_and_shifts_the_rest(self):
        m = steps("independent", "hand-written", "mechanical")
        new = hoist.insert(m, ["abc"], "seed", "Seed the RNG from OO_RANDOM_SEED", "tX", "series/000-upstream-base",
                           "objc-spidermonkey")
        self.assertEqual(new["n"], 2)
        self.assertEqual(new["branch"], "series/002-seed")
        self.assertEqual([s["n"] for s in m["steps"]], [1, 2, 3, 4])
        self.assertEqual([s["kind"] for s in m["steps"]], ["independent", "independent", "hand-written", "mechanical"])
        self.assertEqual(m["steps"][0]["parent"], "series/000-upstream-base")
        self.assertEqual(m["steps"][2]["parent"], "series/002-seed")
        self.assertEqual(m["steps"][2]["branch"], "series/002-s2")  # renamed by `renumber`, not here

    def test_series_base_is_the_last_independent_tree(self):
        self.assertEqual(hoist.series_base(steps("hand-written"), "up"), "up")
        self.assertEqual(hoist.series_base(steps("independent", "independent", "hand-written"), "up"), "t2")


if __name__ == "__main__":
    unittest.main()
