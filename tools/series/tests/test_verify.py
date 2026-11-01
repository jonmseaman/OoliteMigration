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

    def test_meson_warnings_are_not_compiler_warnings(self):
        self.assertEqual(verify.warning_count("WARNING: Project targets '>=1.1' but uses feature ...\n"), 0)


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
