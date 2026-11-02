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

    def test_edit_of_a_merged_file_applies_while_the_merge_is_unchanged(self):
        trees.record_resolution(self.game, self.base, self.ours, self.theirs, self.res, "src/b.m", b"int b;\n")
        trees.record_resolution(self.game, self.base, self.ours, self.theirs, self.res, "src/a.m",
                                b"int a(void) { return 10; } /* fixed */\n", key_merged=True)
        tree, conflicts = trees.target_tree(self.game, self.base, self.ours, self.theirs, self.res)
        self.assertEqual(conflicts, [])
        self.assertIn("/* fixed */", self.show(tree, "src/a.m"))
        idx = os.path.join(self.res, "index.json")
        with open(idx, encoding="utf-8") as f:
            data = json.load(f)
        data["src/a.m"]["merged"] = "0" * 40  # the merge now gives a different file
        with open(idx, "w", encoding="utf-8") as f:
            json.dump(data, f)
        tree, conflicts = trees.target_tree(self.game, self.base, self.ours, self.theirs, self.res)
        self.assertEqual(conflicts, ["src/a.m"])
        self.assertIsNone(tree)

    def test_replay_carries_content_commits_and_a_reformat_commit_is_a_no_op(self):
        fx, g = self.fx, self.game
        cache = os.path.join(self.tmpdir.name, "cache.json")
        n = lambda c: normalise.normalise_tree(g, f"{c}^{{tree}}", fx["u0"], cache_path=cache)
        u0, u1, u2 = n(fx["u0"]), n(fx["u1"]), n(fx["u2"])
        self.assertEqual(u0, u1)  # U1 only reformats: in upstream's style it changes nothing
        # the series so far: the history's first a.m change on U0
        ours = n(git(g, "rev-parse", f"{fx['merges'][1]}:upstream/oolite"))
        tree, conflicts = trees.replay(g, ours, [("u1", u0, u1), ("u2", u1, u2)], self.res)
        self.assertEqual(conflicts, [])
        self.assertIn("return 10", self.show(tree, "src/a.m"))      # the series' own change kept
        self.assertIn("upstream edit", self.show(tree, "src/b.m"))  # the replayed content commit
        self.assertEqual(self.show(tree, "src/e.m") + "\n", E2)

    def test_replay_stops_at_the_commit_with_a_conflict(self):
        fx, g = self.fx, self.game
        cache = os.path.join(self.tmpdir.name, "cache.json")
        n = lambda c: normalise.normalise_tree(g, f"{c}^{{tree}}", fx["u0"], cache_path=cache)
        tree, conflicts = trees.replay(g, self.theirs, [("u2", n(fx["u1"]), n(fx["u2"]))], self.res)
        self.assertIsNone(tree)
        self.assertEqual(conflicts, ["u2: src/b.m"])  # the history changed b.m too

    def test_take_paths_matches_the_source_for_excluded_paths(self):
        g = self.game
        fx = self.fx
        tree = git(g, "rev-parse", f"{fx['u2']}^{{tree}}")
        source = git(g, "rev-parse", f"{fx['u0']}^{{tree}}")
        out = trees.take_paths(g, tree, source, ["src/e*"])
        self.assertNotIn("src/e.m", git(g, "ls-tree", "-r", "--name-only", out).splitlines())  # removed
        self.assertEqual(self.show(out, "src/b.m"), self.show(tree, "src/b.m"))  # others untouched
        self.assertEqual(trees.take_paths(g, tree, source, []), tree)


class DedupeTest(unittest.TestCase):
    def test_second_pragma_once_and_a_repeated_include_run_go(self):
        text = ("/* licence */\n\n#pragma once\n\n#pragma once\n\n#ifndef X\n#else\n"
                "#include \"A.h\"\n#include \"B.h\"\n\n// Each header includes what it uses.\n"
                "#include \"A.h\"\n#include \"B.h\"\n\nint x;\n")
        self.assertEqual(trees.dedupe_header(text),
                         "/* licence */\n\n#pragma once\n\n#ifndef X\n#else\n"
                         "#include \"A.h\"\n#include \"B.h\"\n\nint x;\n")

    def test_a_repeated_include_line_goes_and_a_new_one_stays(self):
        text = ("#include \"A.h\"\n\n// Each header includes what it uses.\n#include \"A.h\"\n#include \"B.h\"\n\n"
                "#if X\n#include \"A.h\"\n#endif\n")
        self.assertEqual(trees.dedupe_header(text),
                         "#include \"A.h\"\n\n// Each header includes what it uses.\n#include \"B.h\"\n\n"
                         "#if X\n#include \"A.h\"\n#endif\n")  # under a conditional it is not a repeat
        text2 = "#include \"A.h\"\n\n// Each header includes what it uses.\n#include \"A.h\"\n\nint x;\n"
        self.assertEqual(trees.dedupe_header(text2), "#include \"A.h\"\n\nint x;\n")

    def test_different_include_runs_and_a_single_pragma_stay(self):
        text = "#pragma once\n\n#include \"A.h\"\n\n// more\n#include \"B.h\"\n"
        self.assertEqual(trees.dedupe_header(text), text)


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

    def test_upstream_block_deletion_drops_history_edits_inside_it(self):
        ours = self.base[3:]                                   # upstream deletes the debug block
        theirs = self.base[:1] + ["void dump(JSContext* c);\n"] + self.base[2:]  # the history edits a line in it
        flags = set()
        self.assertEqual(trees.auto_merge_text(self.base, ours, theirs, flags), ["int x;\n"])
        self.assertEqual(flags, {"upstream-deleted"})

    def test_history_insertion_inside_an_upstream_deleted_block_conflicts(self):
        # a reorder shows as a deletion; a line the history adds there must not vanish silently
        base = ["#import \"A.h\"\n", "#import \"B.h\"\n", "#import \"C.h\"\n", "int x;\n"]
        ours = ["int x;\n"]
        theirs = base[:1] + ["#include \"oofnd/Process.hpp\"\n"] + base[1:]
        self.assertIsNone(trees.auto_merge_text(base, ours, theirs))

    def test_history_insertion_at_the_edge_of_an_upstream_deleted_block_conflicts(self):
        base = ["#import \"A.h\"\n", "#import \"B.h\"\n", "int x;\n"]
        ours = ["int x;\n"]
        theirs = ["#include <vector>\n"] + base
        self.assertIsNone(trees.auto_merge_text(base, ours, theirs))


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


class HunkMergeTest(unittest.TestCase):
    def test_easy_hunks_resolve_and_hard_ones_remain(self):
        with tempfile.TemporaryDirectory() as tmp:
            fx = make_history_repo(tmp)
            g = fx["game"]
            blob = lambda text: trees._git(g, "hash-object", "-w", "--stdin", inp=text.encode()).stdout.decode().strip()
            base = "".join(f"line {i}\n" for i in range(30))
            ours = base.replace("line 3\n", "#ifdef OO_DEBUG_MONITOR_ENABLED\n").replace("line 20\n", "upstream 20\n")
            theirs = base.replace("line 4\n", "history 4\n").replace("line 20\n", "history 20\n")
            lines, n_auto, left = trees.merge_file_by_hunks(g, blob(base), blob(ours), blob(theirs))
            self.assertEqual(left, 1)          # line 20 changed differently on both sides
            self.assertEqual(n_auto, 1)        # lines 3/4: adjacent edits merge
            text = "".join(lines)
            self.assertIn("#ifdef OO_DEBUG_MONITOR_ENABLED\nhistory 4\n", text)
            self.assertIn("<<<<<<< ours\nupstream 20\n=======\nhistory 20\n>>>>>>> theirs\n", text)

    def test_hunk_whose_ours_side_only_relaid_takes_theirs(self):
        b = ["// a long comment\n", "// wrapped here\n", "#define M(x) \\\n", "  f(x)\n"]
        o = ["// a long comment wrapped\n", "// here\n", "#define M(x) f(x)\n"]  # the same text, laid out anew
        t = ["// a long comment\n", "#define M(x) \\\n", "  g(x)\n"]                # a real change
        self.assertEqual(trees.resolve_hunk(b, o, t), (t, "layout"))
        o2 = ["// a long comment wrapped\n", "// here, and more\n", "#define M(x) f(x)\n"]
        self.assertEqual(trees.resolve_hunk(b, o2, t), (None, None))  # ours changed words: a person decides
        both = ["// the same new comment\n", "// wrapped\n", "int x;\n"]
        both_relaid = ["// the same new comment wrapped\n", "int x;\n"]
        self.assertEqual(trees.resolve_hunk(["int y;\n"], both_relaid, both), (both, "layout"))
