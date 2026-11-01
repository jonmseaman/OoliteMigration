import json
import os
import tempfile
import unittest

from tools.series import normalise, trees
from tools.series.tests.fixtures import E2, git, make_history_repo


@unittest.skipUnless(os.path.exists(normalise.CLANG_FORMAT), "clang-format 22 venv missing (T002)")
class TreesTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        tmp = self.tmpdir.name
        self.fx = fx = make_history_repo(tmp)
        game = fx["game"]
        # bring the history's snapshot into the game repo (as refs/series/history does for oolite-dev)
        git(game, "fetch", "-q", fx["super"], "main:refs/series/history")
        cache = os.path.join(tmp, "cache.json")
        n = lambda t: normalise.normalise_tree(game, t, fx["u0"], cache_path=cache)
        self.base = n(f"{fx['u0']}^{{tree}}")
        self.ours = git(game, "rev-parse", "master^{tree}")
        self.theirs = n(git(game, "rev-parse", f"{fx['merges'][-1]}:upstream/oolite"))
        self.res = os.path.join(tmp, "resolutions", "002")
        self.game = game

    def tearDown(self):
        self.tmpdir.cleanup()

    def show(self, tree, path):
        return git(self.game, "show", f"{tree}:{path}")

    def test_history_only_and_upstream_only_changes_survive_and_both_sides_conflict(self):
        tree, conflicts = trees.target_tree(self.game, self.base, self.ours, self.theirs, self.res)
        self.assertEqual(conflicts, ["src/b.m"])
        self.assertIsNone(tree)

    def test_resolution_is_applied_when_its_inputs_match(self):
        _, conflicts = trees.target_tree(self.game, self.base, self.ours, self.theirs, self.res)
        trees.record_resolution(self.game, self.base, self.ours, self.theirs, self.res, "src/b.m",
                                b"int b(void) { return 20; } /* upstream edit kept */\n")
        tree, conflicts = trees.target_tree(self.game, self.base, self.ours, self.theirs, self.res)
        self.assertEqual(conflicts, [])
        self.assertIn("return 10", self.show(tree, "src/a.m"))          # history-only change
        self.assertEqual(self.show(tree, "src/e.m") + "\n", E2)          # upstream-only change
        self.assertIn("return 5", self.show(tree, "src/c.cpp"))         # history-added file
        self.assertIn("upstream edit kept", self.show(tree, "src/b.m"))  # resolution

    def test_stale_resolution_is_reported_not_applied(self):
        trees.record_resolution(self.game, self.base, self.ours, self.theirs, self.res, "src/b.m", b"x\n")
        # pretend the resolution was made against a different upstream blob
        idx = os.path.join(self.res, "index.json")
        with open(idx, encoding="utf-8") as f:
            data = json.load(f)
        data["src/b.m"]["ours"] = "0" * 40
        with open(idx, "w", encoding="utf-8") as f:
            json.dump(data, f)
        tree, conflicts = trees.target_tree(self.game, self.base, self.ours, self.theirs, self.res)
        self.assertEqual(conflicts, ["src/b.m"])
        self.assertIsNone(tree)


if __name__ == "__main__":
    unittest.main()
