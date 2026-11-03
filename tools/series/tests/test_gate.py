import os
import tempfile
import unittest

from tools.series import gate
from tools.series.tests.fixtures import git
from tools.series.tests.fixtures_seriesb import A, B, make_seriesb_repo

WORKFLOW_767 = """
jobs:
  build-windows:
    strategy:
      matrix:
        js_engine: [spidermonkey, quickjs]
    name: windows (${{ matrix.js_engine }})
    runs-on: windows-latest
    steps:
      - name: Build Oolite
        shell: msys2 {0}
        run: |
          ./mk.sh build deployment --setup-flags="-Djs_engine=${{ matrix.js_engine }}"
      - name: Test Oolite
        shell: msys2 {0}
        run: |
          if ./mk.sh test deployment --setup-flags="-Djs_engine=${{ matrix.js_engine }}"; then
            echo ok
          fi
  build-macos:
    strategy:
      matrix:
        js_engine: [spidermonkey, quickjs]
    steps:
      - run: ./mk.sh build deployment --setup-flags="-Djs_engine=${{ matrix.js_engine }}"
"""

WORKFLOW_768 = """
jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - name: Build Oolite
        run: |
          ./mk.sh build deployment
      - name: Test Oolite
        run: |
          if ./mk.sh test deployment; then
            echo ok
          fi
  build-linux:
    steps:
      - run: ./mk.sh build deployment
"""


class PlanTest(unittest.TestCase):
    def test_matrix_variants_from_the_windows_job(self):
        self.assertEqual(gate.variants(WORKFLOW_767), [
            ("spidermonkey", ['./mk.sh build deployment --setup-flags="-Djs_engine=spidermonkey"',
                              './mk.sh test deployment --setup-flags="-Djs_engine=spidermonkey"']),
            ("quickjs", ['./mk.sh build deployment --setup-flags="-Djs_engine=quickjs"',
                         './mk.sh test deployment --setup-flags="-Djs_engine=quickjs"'])])

    def test_single_variant_without_a_matrix(self):
        self.assertEqual(gate.variants(WORKFLOW_768),
                         [("default", ["./mk.sh build deployment", "./mk.sh test deployment"])])

    def test_no_workflow_falls_back_to_build_and_test(self):
        self.assertEqual(gate.variants(None), [("default", ["./mk.sh build deployment", "./mk.sh test deployment"])])


class GateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.fx = make_seriesb_repo(self.tmp.name)
        self.repo, self.m = self.fx["repo"], self.fx["m"]
        self.wt = os.path.join(self.tmp.name, "gate-wt")
        self.addCleanup(lambda: git(self.repo, "worktree", "remove", "--force", self.wt) if os.path.isdir(self.wt) else None)
        self.logs = os.path.join(self.tmp.name, "logs")
        self.ran = []

    def runner(self, fail_on=()):
        def run(era, worktree, body, log):
            self.ran.append(body)
            os.makedirs(os.path.dirname(log), exist_ok=True)
            with open(log, "a", encoding="utf-8") as f:
                f.write("src/x.m:1:2: warning: something\n" if "build" in body else "ok\n")
            return 1 if any(word in body for word in fail_on) else 0
        return run

    def parent(self, branch):
        return next(p for p in self.m["parents"] if p["branch"] == branch)

    def test_pass(self):
        p = gate.run(self.repo, self.parent(B), worktree=self.wt, log_dir=self.logs, runner=self.runner())
        self.assertEqual(p["gate"], "pass")
        self.assertNotIn("flag", p)
        v = p["verification"]
        self.assertEqual(v["commit"], git(self.repo, "rev-parse", B))
        self.assertTrue(all(r.startswith("pass") for r in v["checks"].values()), v["checks"])
        self.assertIn("build_test", v["checks"])
        self.assertTrue(any("./mk.sh test deployment" in c for c in v["commands"]))

    def test_failure_flags_the_parent_with_the_failing_checks(self):
        p = gate.run(self.repo, self.parent(A), worktree=self.wt, log_dir=self.logs,
                     runner=self.runner(fail_on=("test deployment",)))
        self.assertEqual(p["gate"], "flagged")
        self.assertIn("test_default", p["flag"])
        self.assertTrue(p["verification"]["checks"]["test_default"].startswith("fail"))

    def test_rerun_after_a_fix_passes_and_clears_the_flag(self):
        p = self.parent(A)
        gate.run(self.repo, p, worktree=self.wt, log_dir=self.logs, runner=self.runner(fail_on=("build deployment",)))
        self.assertEqual(p["gate"], "flagged")
        gate.run(self.repo, p, worktree=self.wt, log_dir=self.logs, runner=self.runner())
        self.assertEqual(p["gate"], "pass")
        self.assertNotIn("flag", p)

    def test_a_waived_gate_is_not_overwritten_by_a_failure(self):
        p = self.parent(A)
        p["gate"], p["waived"] = "waived", "plan.md Notes, 2026-11-02"
        gate.run(self.repo, p, worktree=self.wt, log_dir=self.logs, runner=self.runner(fail_on=("build",)))
        self.assertEqual(p["gate"], "waived")


if __name__ == "__main__":
    unittest.main()
