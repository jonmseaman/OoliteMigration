import os
import tempfile
import unittest

from tools.series import parents, replay, seriesb
from tools.series.tests.fixtures import git
from tools.series.tests.fixtures_seriesb import B, OLD, commit, make_seriesb_repo, tree_with


class ReplayTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        fx = self.fx = make_seriesb_repo(self.tmp.name, seriesb=False)
        self.repo = fx["repo"]
        git(self.repo, "config", "git-town.perennial-branches", "series/000-upstream-base")
        self.m = {"exclusions": [{"path_glob": ".zed/**", "reason": "editor settings"}], "additions": [],
                  "steps": [], "dropped": [], "syncs": [], "ledger": []}
        parents.setup(self.repo, self.m, {"name": "hobleyd", "url": fx["hob"]},
                      anchors={"develop_target": fx["develop_only"], "upstream_master": fx["u"]})
        for p in self.m["parents"]:
            p["gate"] = "pass"
        self.old = {"steps": [
            {"n": i, "branch": b, "title": f"Old step {i}", "kind": "hand-written", "mechanical_command": None,
             "chapter": {"phase": "P1", "work_items": [f"1.{i} item"], "first": "f", "last": "l", "merges": 1},
             "era": "objc-spidermonkey", "description": f"series/pr/{i:03d}-x.md"}
            for i, b in enumerate(OLD, 1)]}
        self.series_dir = os.path.join(self.tmp.name, "series")
        self.wt = os.path.join(self.tmp.name, "stack-wt")
        self.addCleanup(lambda: git(self.repo, "worktree", "remove", "--force", self.wt) if os.path.isdir(self.wt) else None)
        replay.cut(self.repo, self.m, self.old)

    def compute(self, n):
        return replay.compute(self.repo, self.m, self.m["steps"][n - 1], self.series_dir)

    def build(self, n, **kw):
        return replay.build(self.repo, self.m, self.m["steps"][n - 1], self.series_dir, self.wt, **kw)

    def test_cut_writes_one_planned_step_per_old_step(self):
        steps = self.m["steps"]
        self.assertEqual([s["n"] for s in steps], [1, 2, 3])
        self.assertEqual([s["branch"] for s in steps], ["seriesb/001-one", "seriesb/002-two", "seriesb/003-three"])
        self.assertEqual(steps[0]["parent"], B)
        self.assertEqual(steps[1]["parent"], "seriesb/001-one")
        for i, s in enumerate(steps, 1):
            self.assertEqual(s["source"]["type"], "replay")
            self.assertEqual(s["source"]["old_step"], i)
            self.assertEqual(s["source"]["old_commit"], git(self.repo, "rev-parse", OLD[i - 1]))
            self.assertEqual(s["title"], f"Old step {i}")
            self.assertEqual(s["state"], "planned")
        self.assertEqual(seriesb.validate(self.m), [])

    def test_clean_replay_and_a_conflict(self):
        tree, conflicts, _ = self.compute(1)
        self.assertEqual(conflicts, [])
        self.assertEqual(git(self.repo, "show", f"{tree}:src/a.c"), "a2")
        self.assertEqual(git(self.repo, "show", f"{tree}:src/js.c"), "js-def")  # #768's side, untouched by step 1
        tree2, conflicts2, _ = self.compute(2)
        self.assertIsNone(tree2)
        self.assertEqual(conflicts2, ["src/js.c"])

    def test_theirs_rule_resolves_only_matching_conflicts_and_is_reported(self):
        self.compute(1)
        replay.add_rule(self.m["steps"][1], ["src/**"], "the fork's facade replaces #768's binding")
        tree, conflicts, report = self.compute(2)
        self.assertEqual(conflicts, [])
        self.assertEqual(git(self.repo, "show", f"{tree}:src/js.c"), "js-fork")
        self.assertIn(("src/js.c", "theirs-rule"), report)
        res = {r["path"]: r for r in self.m["steps"][1]["resolutions"]}
        self.assertEqual(res["src/js.c"]["how"], "theirs-rule")
        self.assertIn("facade", res["src/js.c"]["reason"])

    def test_rule_outside_the_conflict_does_not_resolve_it(self):
        self.compute(1)
        replay.add_rule(self.m["steps"][1], ["docs/**"], "unrelated")
        _, conflicts, _ = self.compute(2)
        self.assertEqual(conflicts, ["src/js.c"])

    def test_differs_from_old_lists_exactly_the_changed_changes(self):
        self.compute(1)
        self.assertEqual(replay.differs(self.repo, self.m, self.m["steps"][0]), [])
        replay.add_rule(self.m["steps"][1], ["src/**"], "the fork's facade replaces #768's binding")
        self.compute(2)
        d = replay.differs(self.repo, self.m, self.m["steps"][1])
        self.assertEqual([x["path"] for x in d], ["src/js.c"])
        self.assertIn("theirs-rule", d[0]["reason"])

    def test_build_refuses_while_a_gate_is_not_pass(self):
        self.m["parents"][1]["gate"] = "flagged"
        self.compute(1)
        with self.assertRaises(SystemExit):
            self.build(1)

    def test_build_makes_the_chain_and_check_passes(self):
        replay.add_rule(self.m["steps"][1], ["src/**"], "the fork's facade replaces #768's binding")
        for n in (1, 2, 3):
            self.compute(n)
            self.assertEqual(self.build(n), "built")
        self.m["additions"] = [{"path_glob": "tools/**", "from_pr": 768, "reason": "upstream's own tool"}]
        for s in self.m["steps"]:
            s["verification"] = {"commit": s["build_commit"], "after_sync": 0, "checks": {"build_clang": "pass"}}
        self.assertEqual(seriesb.check(self.repo, self.m, set(seriesb.GROUPS), self.fx_baseline()), [])
        self.assertEqual(self.build(2), "unchanged")
        msg = git(self.repo, "log", "-1", "--format=%B", "seriesb/002-two")
        self.assertTrue(msg.startswith("Old step 2\n"))
        self.assertIn("series/002-two", msg)

    def fx_baseline(self):
        return {"branches": {b: git(self.repo, "rev-parse", b) for b in OLD + ["develop"]}}

    def test_build_refuses_to_reset_a_synced_step(self):
        self.compute(1)
        self.build(1)
        tip = git(self.repo, "rev-parse", "seriesb/001-one")
        ptip = git(self.repo, "rev-parse", B)
        merge = commit(self.repo, git(self.repo, "rev-parse", f"{tip}^{{tree}}"), [tip, ptip], "Merge")
        git(self.repo, "update-ref", "refs/heads/seriesb/001-one", merge)
        self.m["steps"][0]["target_tree"] = None  # force a rebuild
        with self.assertRaises(SystemExit):
            self.build(1)
        self.assertEqual(self.build(1, reset=True), "built")

    def test_drop_refuses_a_step_that_changes_something(self):
        self.compute(1)
        with self.assertRaises(SystemExit):
            replay.drop(self.repo, self.m, 1, 768, "not really covered", self.series_dir)

    def test_drop_a_step_the_parent_already_covers(self):
        # an old step 4 that only adds what #768 adds
        old3 = git(self.repo, "rev-parse", OLD[2])
        t4 = tree_with(self.repo, git(self.repo, "rev-parse", f"{old3}^{{tree}}"), {"tools/x.txt": "x\n"})
        git(self.repo, "branch", "series/004-four", commit(self.repo, t4, [old3], "Old 4"))
        self.old["steps"].append(dict(self.old["steps"][2], n=4, branch="series/004-four", title="Old step 4"))
        self.m["steps"] = []
        replay.cut(self.repo, self.m, self.old)
        replay.add_rule(self.m["steps"][1], ["src/**"], "facade")
        for n in (1, 2, 3, 4):
            self.compute(n)
        replay.drop(self.repo, self.m, 4, 768, "#768 adds tools/x.txt itself", self.series_dir)
        self.assertEqual(len(self.m["steps"]), 3)
        d = self.m["dropped"][0]
        self.assertEqual((d["old_step"], d["old_branch"], d["covered_by"]), (4, "series/004-four", 768))
        self.assertEqual(seriesb.validate(self.m), [])


if __name__ == "__main__":
    unittest.main()
