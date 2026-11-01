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


class AutoMergeTest(unittest.TestCase):
    base = ["#ifndef NDEBUG\n", "void dump(JSContext *c);\n", "#endif\n", "int x;\n"]

    def test_adjacent_changes_on_different_lines_merge(self):
        ours = ["#ifdef OO_DEBUG_MONITOR_ENABLED\n"] + self.base[1:]
        theirs = self.base[:1] + ["extern \"C\" void dump(JSContext *c);\n"] + self.base[2:]
        self.assertEqual(trees.auto_merge_text(self.base, ours, theirs),
                         ["#ifdef OO_DEBUG_MONITOR_ENABLED\n", "extern \"C\" void dump(JSContext *c);\n",
                          "#endif\n", "int x;\n"])

    def test_same_change_both_sides_merges_once(self):
        side = self.base[:3] + ["int y;\n"]
        self.assertEqual(trees.auto_merge_text(self.base, side, side), side)

    def test_overlapping_different_changes_conflict(self):
        ours = ["#if OOLITE_DEBUG\n"] + self.base[1:]
        theirs = ["#if defined(OO_DEBUG)\n"] + self.base[1:]
        self.assertIsNone(trees.auto_merge_text(self.base, ours, theirs))

    def test_different_insertions_at_one_point_conflict(self):
        ours = self.base[:2] + ["int a;\n"] + self.base[2:]
        theirs = self.base[:2] + ["int b;\n"] + self.base[2:]
        self.assertIsNone(trees.auto_merge_text(self.base, ours, theirs))

    def test_changes_far_apart_merge(self):
        ours = ["// head\n"] + self.base
        theirs = self.base[:3] + ["int z;\n"]
        self.assertEqual(trees.auto_merge_text(self.base, ours, theirs), ["// head\n"] + self.base[:3] + ["int z;\n"])


class TransplantTest(unittest.TestCase):
    base = ["static JSBool Get(JSContext *c);\n", "#ifndef NDEBUG\n", "static JSBool Dump(JSContext *c);\n",
            "#endif\n", "\n", "int other;\n", "#ifndef NDEBUG\n", "int debug_only;\n", "#endif\n"]
    # upstream: only the first guard becomes the debug-monitor guard
    ours = base[:1] + ["#ifdef OO_DEBUG_MONITOR_ENABLED\n"] + base[2:]
    # history: rewrote the declarations around the first guard, kept both guards
    theirs = ["namespace {\n", "static bool Get(Context c);\n", "} // namespace\n", "#ifndef NDEBUG\n",
              "namespace {\n", "static bool Dump(Context c);\n", "} // namespace\n", "#endif\n", "\n",
              "int other;\n", "#ifndef NDEBUG\n", "int debug_only;\n", "#endif\n"]

    def test_guard_substitution_lands_on_the_matching_guard_only(self):
        out = trees.transplant(self.base, self.ours, self.theirs)
        self.assertIsNotNone(out)
        self.assertEqual(out[3], "#ifdef OO_DEBUG_MONITOR_ENABLED\n")
        self.assertEqual(out[10], "#ifndef NDEBUG\n")  # the other guard is untouched
        self.assertEqual(len(out), len(self.theirs))

    def test_guard_whose_neighbours_were_all_rewritten_needs_context(self):
        # theirs rewrote both neighbours of the guard on the same line as ours' change:
        # auto-merge refuses (overlap), transplant places it by context
        base = ["// one\n", "int a;\n", "#ifndef NDEBUG\n", "int dump();\n", "#endif\n", "// two\n"]
        ours = base[:2] + ["#ifdef OO_DEBUG_MONITOR_ENABLED\n"] + base[3:]
        theirs = ["// one\n", "long a;\n", "#ifndef NDEBUG\n", "bool dump();\n", "#endif\n", "// two\n"]
        self.assertEqual(trees.transplant(base, ours, theirs)[2], "#ifdef OO_DEBUG_MONITOR_ENABLED\n")

    def test_guard_without_matching_context_is_refused(self):
        base = ["p\n", "#ifndef NDEBUG\n", "q\n"]
        ours = ["p\n", "#ifdef OO_DEBUG_MONITOR_ENABLED\n", "q\n"]
        theirs = ["#ifndef NDEBUG\n", "r\n", "#ifndef NDEBUG\n"]
        self.assertIsNone(trees.transplant(base, ours, theirs))


if __name__ == "__main__":
    unittest.main()
