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

    # --- the switch step: source type "target" (T047) -------------------------------------------

    def _build_replays(self):
        replay.add_rule(self.m["steps"][1], ["src/**"], "the fork's facade replaces #768's binding")
        for n in (1, 2, 3):
            self.compute(n)
            self.build(n)

    def _target(self, ledger_rows=("tests/t1.txt",)):
        """A target branch on develop: the binding changes src/js.c and a test; and its test ledger."""
        dev = git(self.repo, "rev-parse", "develop")
        t = tree_with(self.repo, git(self.repo, "rev-parse", f"{dev}^{{tree}}"),
                      {"src/js.c": "js-up\n", "tests/t1.txt": "t1-up\n"})
        c = commit(self.repo, t, [dev], "The binding")
        git(self.repo, "branch", "-f", "feature/binding", c)
        ledger = os.path.join(self.tmp.name, "test-changes.md")
        with open(ledger, "w", encoding="utf-8") as f:
            f.write("| path | what | why | assertions |\n|---|---|---|---|\n")
            for r in ledger_rows:
                f.write(f"| {r} | moved | engine API | none |\n")
        return c, ledger

    def _switch(self, ledger):
        self.m["additions"] = [{"path_glob": "tools/**", "from_pr": 768, "reason": "upstream's own tool"}]
        replay.set_target(self.repo, self.m, "feature/binding", "Move to the binding", "upstream-binding", ledger)
        return self.m["steps"][-1]

    def test_target_step_is_last_and_has_the_targets_tree(self):
        self._build_replays()
        c, ledger = self._target()
        s = self._switch(ledger)
        self.assertEqual((s["n"], s["branch"], s["parent"]), (4, "seriesb/004-upstream-binding", "seriesb/003-three"))
        self.assertEqual(s["source"]["type"], "target")
        self.assertEqual(s["source"]["commit"], c)
        tree, conflicts, _ = self.compute(4)
        self.assertEqual(conflicts, [])
        self.assertEqual(git(self.repo, "show", f"{tree}:src/js.c"), "js-up")
        self.assertEqual(git(self.repo, "show", f"{tree}:tests/t1.txt"), "t1-up")
        self.assertEqual(git(self.repo, "show", f"{tree}:tools/x.txt"), "x")  # an addition, as the parent has it
        self.assertEqual(git(self.repo, "ls-tree", "-r", "--name-only", tree, "--", ".zed"), "")  # an exclusion
        self.assertEqual(replay.differs(self.repo, self.m, s), [])
        self.assertEqual(seriesb.validate(self.m), [])

    def test_cut_again_keeps_a_recorded_take_old(self):
        replay.take_old(self.m["steps"][1], ["README"], "the old step's README")
        replay.cut(self.repo, self.m, self.old)
        self.assertEqual(self.m["steps"][1].get("take_old"), {"keep": ["README"], "reason": "the old step's README"})

    def test_cut_keeps_the_target_step_last(self):
        self._build_replays()
        _, ledger = self._target()
        self._switch(ledger)
        tree, _, _ = self.compute(4)
        replay.cut(self.repo, self.m, self.old)
        self.assertEqual([s["source"]["type"] for s in self.m["steps"]], ["replay"] * 3 + ["target"])
        self.assertEqual(self.m["steps"][3]["target_tree"], tree)
        # a new old step goes before it; the switch is renumbered and its tree recomputed
        old3 = git(self.repo, "rev-parse", OLD[2])
        t4 = tree_with(self.repo, git(self.repo, "rev-parse", f"{old3}^{{tree}}"), {"README": "r2\n"})
        git(self.repo, "branch", "series/004-four", commit(self.repo, t4, [old3], "Old 4"))
        self.old["steps"].append(dict(self.old["steps"][2], n=4, branch="series/004-four", title="Old step 4"))
        replay.cut(self.repo, self.m, self.old)
        last = self.m["steps"][-1]
        self.assertEqual((last["n"], last["branch"], last["parent"]),
                         (5, "seriesb/005-upstream-binding", "seriesb/004-four"))
        self.assertIsNone(last["target_tree"])
        self.assertEqual(seriesb.validate(self.m), [])

    def test_validate_wants_the_target_step_last(self):
        _, ledger = self._target()
        self._switch(ledger)
        steps = self.m["steps"]
        steps[2], steps[3] = steps[3], steps[2]
        for i, s in enumerate(steps, 1):
            s["n"] = i
            s["branch"] = f"seriesb/{i:03d}-" + s["branch"].split("-", 1)[1]
            s["parent"] = B if i == 1 else steps[i - 2]["branch"]
        self.assertTrue(any("target" in p for p in seriesb.validate(self.m)))

    def test_target_step_builds_and_checks_against_its_ledger(self):
        self._build_replays()
        c, ledger = self._target()
        s = self._switch(ledger)
        self.compute(4)
        self.assertEqual(self.build(4), "built")
        msg = git(self.repo, "log", "-1", "--format=%B", s["branch"])
        self.assertTrue(msg.startswith("Move to the binding\n"))
        self.assertIn("feature/binding", msg)
        self.m["anchors"]["develop_target"] = c
        for st in self.m["steps"]:
            st["verification"] = {"commit": st["build_commit"], "after_sync": 0, "checks": {"build_clang": "pass"}}
        self.assertEqual(seriesb.check(self.repo, self.m, set(seriesb.GROUPS), self.fx_baseline()), [])
        with open(ledger, "w", encoding="utf-8") as f:
            f.write("| path | what | why | assertions |\n")
        problems = seriesb.check(self.repo, self.m, {"tests"}, self.fx_baseline())
        self.assertEqual(len(problems), 1)
        self.assertIn("tests/t1.txt", problems[0])
        self.assertIn("ledger", problems[0])



class DescribeReplayTest(unittest.TestCase):
    """Descriptions and the handover for seriesb (T031)."""

    M = {"anchors": {"develop_target": "3aa8d65e8" + "0" * 31, "upstream_master": "7437f22a5" + "0" * 31},
         "parents": [
             {"branch": "seriesb/000a-upstream-767-quickjs-option", "kind": "upstream", "upstream_pr": 767,
              "head": "3758f8a09" + "0" * 31, "gate": "pass", "tracking": "hobleyd/x", "parent": "develop"},
             {"branch": "seriesb/000b-upstream-768-quickjs-only", "kind": "upstream", "upstream_pr": 768,
              "head": "db4920103" + "0" * 31, "gate": "pass", "tracking": "hobleyd/y",
              "parent": "seriesb/000a-upstream-767-quickjs-option"}],
         "exclusions": [{"path_glob": ".zed/**", "reason": "editor settings"}],
         "additions": [{"path_glob": "tools/js-parity/**", "from_pr": 767, "reason": "upstream's tool"}],
         "folded": [{"old_steps": [3, 4], "into_old_step": 5, "reason": "SpiderMonkey would come back"}],
         "dropped": [], "syncs": [], "ledger": [],
         "steps": [{"n": 1, "branch": "seriesb/001-a", "parent": "seriesb/000b-upstream-768-quickjs-only",
                    "title": "Fix the seed", "kind": "independent", "description": "series/pr/001-a.md",
                    "source": {"type": "replay", "old_step": 1, "old_branch": "series/001-a"},
                    "differs_from_old": [], "size": {"src": 11, "tests": 0, "other": 0, "deleted_files": 0},
                    "verification": {"date": "2026-11-02", "commit": "c" * 40,
                                     "checks": {"build_clang": "pass", "unit": "n/a: none"}}},
                   {"n": 2, "branch": "seriesb/002-b", "parent": "seriesb/001-a", "title": "Facade, folded",
                    "kind": "hand-written", "description": "series/pr/002-b.md",
                    "source": {"type": "replay", "old_step": 5, "old_branch": "series/005-b", "old_steps": [3, 4, 5]},
                    "differs_from_old": [{"path": "src/js.c", "reason": "the step takes the old step's tree whole: D1"}],
                    "size": None, "verification": None}]}

    def test_handover_lists_parents_and_pushes_000b_to_the_fork_only_with_a_refspec(self):
        from tools.series import series
        text = series.render_handover_replay(self.M)
        self.assertIn("#768", text)
        self.assertIn("db4920103", text)
        self.assertIn("seriesb/000b-upstream-768-quickjs-only:refs/heads/seriesb/000b-upstream-768-quickjs-only", text)
        self.assertIn("--base seriesb/000b-upstream-768-quickjs-only --head seriesb/001-a", text)
        self.assertIn("--base seriesb/001-a --head seriesb/002-b", text)
        self.assertIn("tools/js-parity/**", text)
        self.assertIn("old 3, 4, 5", text)
        self.assertIn("docs/series-sync.md", text)
        self.assertNotRegex(text, r"<[a-z-]+>|…")

    def test_upstream_section_waits_while_the_prs_are_open(self):
        from tools.series import series
        text = series.render_handover_replay(self.M)
        upstream = text.split("## Upstream, one at a time (Jon)")[1]
        self.assertIn("wait", upstream.lower())
        self.assertNotIn("gh pr create -R OoliteProject/oolite", upstream)

    def test_upstream_commands_after_retire(self):
        import copy
        from tools.series import series
        m = copy.deepcopy(self.M)
        for p in m["parents"]:
            p["state"] = "retired"
        m["parents"].append({"branch": "seriesb/000m-upstream-master", "kind": "upstream-master", "gate": "pass",
                             "head": "a" * 40, "parent": None})
        m["steps"][0]["parent"] = "seriesb/000m-upstream-master"
        upstream = series.render_handover_replay(m).split("## Upstream, one at a time (Jon)")[1]
        self.assertIn("gh pr create -R OoliteProject/oolite --base master --head jonmseaman:seriesb/001-a", upstream)

    def test_description_names_the_old_step_and_its_differences(self):
        from tools.series import series
        text = series.render_description_replay(self.M, self.M["steps"][1], {})
        self.assertTrue(text.startswith("# Facade, folded\n"))
        self.assertIn("series/005-b", text)
        self.assertIn("old 3, 4, 5", text)
        self.assertIn("src/js.c", text)
        self.assertNotIn("#768", text)
        first = series.render_description_replay(self.M, self.M["steps"][0], {})
        self.assertIn("#768", first)
        self.assertIn("#767 and #768 merged first", first)

    def test_the_switch_step_is_described_as_the_switch(self):
        import copy
        from tools.series import series
        m = copy.deepcopy(self.M)
        m["steps"].append({"n": 3, "branch": "seriesb/003-binding", "parent": "seriesb/002-b",
                           "title": "Move to the binding", "kind": "hand-written", "description": "series/pr/003-binding.md",
                           "source": {"type": "target", "ref": "feature/upstream-quickjs-binding", "commit": "d" * 40,
                                      "test_ledger": "specs/x/series/test-changes.md"},
                           "differs_from_old": [], "size": None, "verification": None})
        text = series.render_description_replay(m, m["steps"][2], {}, tests_changed=["tests/t.cpp"])
        self.assertIn("feature/upstream-quickjs-binding", text)
        self.assertIn("test-changes.md", text)
        self.assertNotIn("Replays:", text)
        handover = series.render_handover_replay(m)
        self.assertIn("`feature/upstream-quickjs-binding` (the switch)", handover)


if __name__ == "__main__":
    unittest.main()
