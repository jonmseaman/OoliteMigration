import os
import tempfile
import unittest

from tools.series import verify
from tools.series.tests.fixtures import git


def tree_of(repo, files):
    """Commit `files` ({path: text}) on an orphan branch and return its tree."""
    for p, text in files.items():
        full = os.path.join(repo, p)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "t", "--allow-empty")
    tree = git(repo, "rev-parse", "HEAD^{tree}")
    git(repo, "rm", "-q", "-r", "--cached", ".")
    for p in files:
        os.remove(os.path.join(repo, p))
    return tree


class EraTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = self.tmp.name
        git(self.repo, "init", "-q")
        git(self.repo, "config", "user.email", "t@example.com")
        git(self.repo, "config", "user.name", "t")

    def tearDown(self):
        self.tmp.cleanup()

    def test_objc_with_spidermonkey(self):
        t = tree_of(self.repo, {"src/Core/A.m": "", "src/meson.build": "deps = [dependency('nspr')]\n",
                                "src/meson/windows/meson.build": "win_js_suffix = ''\n"})
        self.assertEqual(verify.era(self.repo, t), "objc-spidermonkey")

    def test_objcxx_with_spidermonkey(self):
        t = tree_of(self.repo, {"src/Core/A.mm": "", "src/meson/windows/meson.build": "'js' + win_js_suffix,\n"})
        self.assertEqual(verify.era(self.repo, t), "objc-spidermonkey")

    def test_objc_on_quickjs(self):
        t = tree_of(self.repo, {"src/Core/A.mm": "", "src/meson.build": "# SpiderMonkey was removed\n"})
        self.assertEqual(verify.era(self.repo, t), "objc-quickjs")

    def test_macos_meson_does_not_decide_the_era(self):
        t = tree_of(self.repo, {"src/Core/A.mm": "", "src/meson/darwin/meson.build": "js_name = 'js_static'\n",
                                "src/meson/windows/meson.build": "# QuickJS\n"})
        self.assertEqual(verify.era(self.repo, t), "objc-quickjs")

    def test_cxx(self):
        t = tree_of(self.repo, {"src/Core/A.cpp": "", "src/meson.build": "deps = [dependency('sdl3')]\n"})
        self.assertEqual(verify.era(self.repo, t), "cxx")

    def test_objc_outside_src_does_not_count(self):
        t = tree_of(self.repo, {"tools/x.m": "", "src/Core/A.cpp": ""})
        self.assertEqual(verify.era(self.repo, t), "cxx")


class GccRuleTest(unittest.TestCase):
    def test_gcc_required_iff_parent_built_with_gcc(self):
        self.assertTrue(verify.gcc_required({"checks": {"build_gcc": "pass"}}))
        self.assertFalse(verify.gcc_required({"checks": {"build_gcc": "n/a: parent does not build with GCC"}}))
        self.assertFalse(verify.gcc_required({"checks": {"build_gcc": "fail"}}))
        self.assertFalse(verify.gcc_required(None))

    def test_gcc_attempted_from_cxx_era(self):
        self.assertTrue(verify.gcc_attempted("cxx", None))
        self.assertFalse(verify.gcc_attempted("objc-quickjs", None))
        self.assertTrue(verify.gcc_attempted("objc-quickjs", {"checks": {"build_gcc": "pass"}}))


class WarningCountTest(unittest.TestCase):
    def test_counts_distinct_compiler_warnings(self):
        log = ("[1/3] Compiling C++ object a.o\n"
               "../src/a.cpp:10:5: warning: unused variable 'x' [-Wunused-variable]\n"
               "../src/a.cpp:10:5: warning: unused variable 'x' [-Wunused-variable]\n"
               "In file included from ../src/b.cpp:1:\n"
               "../src/b.h:3:1: warning: extra ';' [-Wextra-semi]\n"
               "2 warnings generated.\n"
               "ld.lld: warning: duplicate symbol\n")
        self.assertEqual(verify.warning_count(log), 3)

    def test_no_warnings(self):
        self.assertEqual(verify.warning_count("[1/1] Linking target oolite.exe\n1 warning generated? no\n"), 0)

    def test_driver_warnings_count(self):
        log = ("clang++: warning: argument unused during compilation: '-pthread' [-Wunused-command-line-argument]\n"
               "clang: warning: argument unused during compilation: '-pthread' [-Wunused-command-line-argument]\n"
               "g++: warning: switch '-fobjc-exceptions' is no longer supported\n")
        self.assertEqual(verify.warning_count(log), 3)

    def test_meson_warnings_are_not_compiler_warnings(self):
        self.assertEqual(verify.warning_count("WARNING: Project targets '>=1.1' but uses feature ...\n"), 0)


class ListedTestWarningsTest(unittest.TestCase):
    TABLE = ("# Warnings\n\n| Steps | File | Warning | Why it stays | Gone from |\n|---|---|---|---|---|\n"
             "| 11–16 | `tests/unit/core/test_a.mm` | `variable 'sFinalized' set but not used` | the history's test | 17 |\n"
             "| 12 | `tests/unit/core/test_b.mm` | `unused variable 'x'` | the history's test | 13 |\n")
    LOG = ("../../tests/unit/core/test_a.mm:132:5: warning: variable 'sFinalized' set but not used [-Wunused-but-set-global]\n"
           "../../tests/unit/core/test_b.mm:9:5: warning: unused variable 'x' [-Wunused-variable]\n")

    def listed(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "test-warnings.md")
            with open(path, "w", encoding="utf-8") as f:
                f.write(self.TABLE)
            return verify.listed_test_warnings(path)

    def test_table_is_read(self):
        self.assertEqual(self.listed(), [
            (11, 16, "tests/unit/core/test_a.mm", "variable 'sFinalized' set but not used"),
            (12, 12, "tests/unit/core/test_b.mm", "unused variable 'x'")])

    def test_no_warnings_pass(self):
        self.assertEqual(verify.warnings_verdict("", 11, self.listed()), "pass: 0 warnings")

    def test_listed_warnings_within_their_steps_pass_and_are_counted(self):
        self.assertEqual(verify.warnings_verdict(self.LOG, 12, self.listed()),
                         "pass: 0 warnings outside the history's tests (2 listed in test-warnings.md)")

    def test_listed_warning_outside_its_steps_fails(self):
        self.assertEqual(verify.warnings_verdict(self.LOG, 11, self.listed()),
                         "fail: 1 warnings (and 1 listed in test-warnings.md)")

    def test_source_warnings_are_never_listed(self):
        listed = [(1, 99, "src/a.mm", "unused variable 'x'")]
        self.assertEqual(verify.warnings_verdict("../../src/a.mm:1:1: warning: unused variable 'x'\n", 5, listed),
                         "fail: 1 warnings")


class TouchedScenariosTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = self.tmp.name
        git(self.repo, "init", "-q")
        git(self.repo, "config", "user.email", "t@example.com")
        git(self.repo, "config", "user.name", "t")

    def tearDown(self):
        self.tmp.cleanup()

    def test_changed_and_added_feature_files(self):
        a = tree_of(self.repo, {"tests/component/features/s1_police.feature": "Feature: a\n",
                                "tests/component/features/s2_dock.feature": "Feature: b\n", "src/x.cpp": ""})
        b = tree_of(self.repo, {"tests/component/features/s1_police.feature": "Feature: a2\n",
                                "tests/component/features/s2_dock.feature": "Feature: b\n",
                                "tests/component/features/s3_new.feature": "Feature: c\n", "src/x.cpp": "y"})
        self.assertEqual(verify.touched_scenarios(self.repo, a, b), ["s1_police", "s3_new"])

    def test_step_files_touch_every_scenario(self):
        a = tree_of(self.repo, {"tests/component/features/s1_police.feature": "Feature: a\n",
                                "tests/component/steps/common.py": "x = 1\n"})
        b = tree_of(self.repo, {"tests/component/features/s1_police.feature": "Feature: a\n",
                                "tests/component/steps/common.py": "x = 2\n"})
        self.assertEqual(verify.touched_scenarios(self.repo, a, b), ["s1_police"])

    def test_none_without_component_tier(self):
        a = tree_of(self.repo, {"src/x.cpp": ""})
        b = tree_of(self.repo, {"src/x.cpp": "y"})
        self.assertEqual(verify.touched_scenarios(self.repo, a, b), [])


class IntegrityTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = self.tmp.name
        git(self.repo, "init", "-q")
        git(self.repo, "config", "user.email", "t@example.com")
        git(self.repo, "config", "user.name", "t")

    def tearDown(self):
        self.tmp.cleanup()

    def t(self, files):
        return tree_of(self.repo, files)

    # (a) tests_untouched
    def test_tests_equal_to_source_pass(self):
        src = self.t({"tests/a.py": "1\n", "src/x.c": "a\n"})
        step = self.t({"tests/a.py": "1\n", "src/x.c": "b\n"})
        self.assertEqual(verify.check_tests_untouched(self.repo, step, src, src, []), "pass")

    def test_tests_from_upstream_side_pass(self):
        src = self.t({"tests/a.py": "1\n"})
        ours = self.t({"tests/a.py": "1\n", "tests/run_test_fn.sh": "up\n"})
        step = self.t({"tests/a.py": "1\n", "tests/run_test_fn.sh": "up\n"})
        self.assertEqual(verify.check_tests_untouched(self.repo, step, src, ours, []), "pass")

    def test_test_edited_by_construction_fails(self):
        src = self.t({"tests/a.py": "1\n"})
        step = self.t({"tests/a.py": "2\n"})
        self.assertTrue(verify.check_tests_untouched(self.repo, step, src, src, []).startswith("fail: tests/a.py"))

    def test_resolution_on_a_test_fails(self):
        src = self.t({"tests/a.py": "1\n"})
        self.assertTrue(verify.check_tests_untouched(self.repo, src, src, src, ["tests/a.py"]).startswith("fail"))

    # (b) no_new_suppressions
    def test_suppression_from_source_passes(self):
        parent = self.t({"meson.build": "x\n"})
        src = self.t({"meson.build": "x\nargs += '-Wno-deprecated'\n"})
        step = self.t({"meson.build": "x\nargs += '-Wno-deprecated'\n"})
        self.assertEqual(verify.check_no_new_suppressions(self.repo, parent, step, src), "pass")

    def test_added_suppression_fails(self):
        parent = self.t({"src/a.cpp": "int a;\n"})
        step = self.t({"src/a.cpp": "#pragma clang diagnostic ignored \"-Wfoo\"\nint a;\n"})
        self.assertTrue(verify.check_no_new_suppressions(self.repo, parent, step, parent).startswith("fail: src/a.cpp"))

    # (d) no_new_spidermonkey_or_gnustep
    def test_legacy_reference_removed_passes(self):
        parent = self.t({"src/a.mm": "#include <jsapi.h>\n"})
        step = self.t({"src/a.mm": "#include \"quickjs.h\"\n"})
        self.assertEqual(verify.check_no_new_legacy(self.repo, parent, step), "pass")

    def test_legacy_reference_added_fails(self):
        parent = self.t({"src/meson.build": "deps = []\n"})
        step = self.t({"src/meson.build": "deps = [dependency('gnustep-base')]\n"})
        self.assertEqual(verify.check_no_new_legacy(self.repo, parent, step), "fail: gnustep-base 0->1")

    def test_legacy_mention_in_a_comment_passes(self):
        parent = self.t({"src/meson.build": "deps = []\n"})
        step = self.t({"src/meson.build": "deps = []  # gnustep-base still owns @\"...\"\n# was 'gnustep-base'\n"})
        self.assertEqual(verify.check_no_new_legacy(self.repo, parent, step), "pass")

    def test_macos_build_file_is_ignored(self):
        parent = self.t({"src/meson/darwin/meson.build": "x = 1\n"})
        step = self.t({"src/meson/darwin/meson.build": "js_name = 'js_static'\n"})
        self.assertEqual(verify.check_no_new_legacy(self.repo, parent, step), "pass")

    def test_clean_merge_of_a_test_passes_and_a_hand_edit_fails(self):
        base = self.t({"tests/a.py": "1\n2\n3\n4\n5\n"})
        ours = self.t({"tests/a.py": "1 upstream\n2\n3\n4\n5\n"})
        src = self.t({"tests/a.py": "1\n2\n3\n4\n5 history\n"})
        merged = self.t({"tests/a.py": "1 upstream\n2\n3\n4\n5 history\n"})
        edited = self.t({"tests/a.py": "1 upstream\n2\n3 edited\n4\n5 history\n"})
        self.assertEqual(verify.check_tests_untouched(self.repo, merged, src, ours, [], base), "pass")
        self.assertTrue(verify.check_tests_untouched(self.repo, edited, src, ours, [], base).startswith("fail"))

    def test_suppression_moved_by_a_rename_passes(self):
        parent = self.t({"src/OOFoundation.mm": "int a;\n"})
        src = self.t({"src/OOCocoa.mm": "#pragma clang diagnostic push\nint a;\n"})
        step = self.t({"src/OOFoundation.mm": "#pragma clang diagnostic push\nint a;\n"})
        self.assertEqual(verify.check_no_new_suppressions(self.repo, parent, step, src), "pass")

    # (c) clang_format
    def test_unformatted_source_fails_and_objc_is_not_checked(self):
        step = self.t({"src/a.cpp": "int  a;\n", "src/b.mm": "int  b;\n", "src/c.h": "int c;\n"})
        formatted = self.t({"src/a.cpp": "int a;\n", "src/b.mm": "int b;\n", "src/c.h": "int c;\n"})
        self.assertEqual(verify.check_clang_format(self.repo, step, formatted), "fail: 1 files not formatted: src/a.cpp")
        self.assertEqual(verify.check_clang_format(self.repo, formatted, formatted), "pass")


class PlanTest(unittest.TestCase):
    def test_matrix_for_each_era(self):
        p = verify.plan("objc-spidermonkey", None, has_unit=False, has_smoke=True, scenarios=[])
        self.assertEqual([c for c, _ in p], ["build_clang", "warnings_clang", "build_gcc", "unit", "smoke", "component"])
        d = dict(p)
        self.assertTrue(d["build_gcc"].startswith("n/a"))
        self.assertTrue(d["unit"].startswith("n/a"))
        self.assertTrue(d["component"].startswith("n/a"))
        d = dict(verify.plan("cxx", {"checks": {"build_gcc": "pass"}}, has_unit=True, has_smoke=True, scenarios=["s1"]))
        self.assertEqual(d["build_gcc"], "run")
        self.assertEqual(d["component"], "run")


if __name__ == "__main__":
    unittest.main()
