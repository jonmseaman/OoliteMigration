"""Phase 11 (spec 002 User Story 7, FR-017): no façade in any step, #767's harness carried through,
and a replayed step's test ledger section."""
import os
import tempfile
import unittest

from tools.series import replay, verify
from tools.series.tests.fixtures import git
from tools.series.tests.test_verify import tree_of

POC_LINUX_ONLY_MESON = ("if host_os == 'windows' or host_os == 'cygwin'\n"
                        "    error('The QuickJS proof-of-concept harness currently supports Linux only.')\n"
                        "endif\n")


class RepoTest(unittest.TestCase):
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


class NoFacadeTest(RepoTest):
    def test_binding_on_upstream_api_passes(self):
        tree = self.t({"src/Core/Scripting/OOJSShip.cpp": "static JSValue ShipX(OOJS_NATIVE_ARGS);\n",
                       "tests/unit/core/test_OOJSShip.cpp": "JS_NewRuntime();\n"})
        self.assertEqual(verify.check_no_facade(self.repo, tree), "pass")

    def test_facade_call_in_src_fails(self):
        tree = self.t({"src/Core/Scripting/OOJSShip.cpp": "static bool X(ooscript::Context c);\n"})
        result = verify.check_no_facade(self.repo, tree)
        self.assertTrue(result.startswith("fail: 1 files"), result)
        self.assertIn("src/Core/Scripting/OOJSShip.cpp", result)

    def test_facade_header_in_tests_fails(self):
        tree = self.t({"tests/unit/test_engine.cpp": '#include "JSEngine.hpp"\n'})
        self.assertTrue(verify.check_no_facade(self.repo, tree).startswith("fail"))

    def test_mention_outside_src_and_tests_is_ignored(self):
        tree = self.t({"docs/history.md": "the ooscript façade was removed\n", "src/a.cpp": "int a;\n"})
        self.assertEqual(verify.check_no_facade(self.repo, tree), "pass")


class PocPlanTest(RepoTest):
    def test_no_harness_is_not_applicable(self):
        self.assertTrue(verify.poc_plan(self.repo, self.t({"src/a.cpp": ""})).startswith("n/a"))

    def test_gnustep_harness_is_not_applicable(self):
        tree = self.t({verify.POC_MESON: POC_LINUX_ONLY_MESON})
        self.assertTrue(verify.poc_plan(self.repo, tree).startswith("n/a: the harness needs GNUstep"))

    def test_cxx_harness_runs(self):
        tree = self.t({verify.POC_MESON: "poc_bin = executable('oojs-quickjs-poc', poc_sources)\n"})
        self.assertEqual(verify.poc_plan(self.repo, tree), "run")


class LedgerTest(RepoTest):
    LEDGER = ("# Test changes\n\n"
              "## Step 005: typed accessors\n\n"
              "| Path | What | Why |\n|---|---|---|\n"
              "| `tests/unit/core/test_OOJSShip.cpp` | engine API | façade gone |\n\n"
              "## Step 006\n\n"
              "| Path | What | Why |\n|---|---|---|\n"
              "| `tests/unit/core/test_OOJSStation.cpp` | engine API | façade gone |\n")

    def setUp(self):
        super().setUp()
        self.ledger = os.path.join(self.repo, "ledger.md")
        with open(self.ledger, "w", encoding="utf-8", newline="\n") as f:
            f.write(self.LEDGER)

    def step(self, n):
        return {"n": n, "source": {"type": "replay", "test_ledger": self.ledger}}

    def test_section_lists_only_its_step(self):
        step = self.step(5)
        paths = replay.ledger_paths(step, replay.ledger_section(step))
        self.assertIn("tests/unit/core/test_OOJSShip.cpp", paths)
        self.assertNotIn("tests/unit/core/test_OOJSStation.cpp", paths)

    def test_without_section_lists_every_row(self):
        paths = replay.ledger_paths(self.step(5))
        self.assertIn("tests/unit/core/test_OOJSStation.cpp", paths)

    def test_listed_test_may_differ(self):
        src = self.t({"tests/unit/core/test_OOJSShip.cpp": "ooscript::Value v;\n"})
        step = self.t({"tests/unit/core/test_OOJSShip.cpp": "JSValue v;\n"})
        self.assertTrue(verify.check_tests_untouched(self.repo, step, src, src, []).startswith("fail"))
        self.assertEqual(verify.check_tests_untouched(self.repo, step, src, src, [],
                                                      allowed={"tests/unit/core/test_OOJSShip.cpp"}), "pass")
        self.assertEqual(verify.check_tests_untouched(self.repo, step, src, src, [],
                                                      allowed={"test_OOJSShip.cpp"}), "pass")

    def test_unlisted_test_still_fails(self):
        src = self.t({"tests/a.py": "1\n", "tests/b.py": "1\n"})
        step = self.t({"tests/a.py": "2\n", "tests/b.py": "2\n"})
        result = verify.check_tests_untouched(self.repo, step, src, src, [], allowed={"tests/a.py"})
        self.assertEqual(result, "fail: tests/b.py")


if __name__ == "__main__":
    unittest.main()
