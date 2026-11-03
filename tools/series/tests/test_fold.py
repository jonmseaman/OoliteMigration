import os
import tempfile
import unittest

from tools.series import parents, replay, seriesb
from tools.series.tests.fixtures import git
from tools.series.tests.fixtures_seriesb import B, OLD, make_seriesb_repo

KEEP = ["tools/**"]


class FoldTest(unittest.TestCase):
    """Old steps 2 and 3 folded into one seriesb step that takes old step 3's tree whole, keeping the
    parent's tools/ (the shape of seriesb's step 3: old 003-005, research R4)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        fx = self.fx = make_seriesb_repo(self.tmp.name, seriesb=False)
        self.repo = fx["repo"]
        self.m = {"exclusions": [{"path_glob": ".zed/**", "reason": "editor settings"}],
                  "additions": [{"path_glob": "tools/**", "from_pr": 768, "reason": "upstream's own tool"}],
                  "steps": [], "dropped": [], "syncs": [], "ledger": []}
        parents.setup(self.repo, self.m, {"name": "hobleyd", "url": fx["hob"]},
                      anchors={"develop_target": fx["develop_only"], "upstream_master": fx["u"]})
        for p in self.m["parents"]:
            p["gate"] = "pass"
        self.old = {"steps": [{"n": i, "branch": b, "title": f"Old step {i}", "kind": "hand-written",
                               "mechanical_command": None, "chapter": None, "era": "objc-spidermonkey",
                               "description": "x"} for i, b in enumerate(OLD, 1)]}
        self.dir = os.path.join(self.tmp.name, "series")
        replay.fold(self.repo, self.m, self.old, 2, 3, "Steps two and three, on the parent", "they only make sense together")

    def test_fold_makes_one_step_from_the_range(self):
        steps = self.m["steps"]
        self.assertEqual([s["n"] for s in steps], [1, 2])
        s = steps[1]
        self.assertEqual(s["branch"], "seriesb/002-three")
        self.assertEqual(s["title"], "Steps two and three, on the parent")
        self.assertEqual(s["source"]["old_step"], 3)
        self.assertEqual(s["source"]["old_steps"], [2, 3])
        self.assertEqual(self.m["folded"], [{"old_steps": [2], "into_old_step": 3,
                                             "reason": "they only make sense together"}])
        self.assertEqual(seriesb.validate(self.m), [])

    def test_folded_step_merges_from_the_first_old_steps_parent(self):
        replay.compute(self.repo, self.m, self.m["steps"][0], self.dir)
        base, _ours, theirs = replay.inputs(self.repo, self.m, self.m["steps"][1])
        self.assertEqual(base, git(self.repo, "rev-parse", f"{OLD[0]}^{{tree}}"))
        self.assertEqual(theirs, git(self.repo, "rev-parse", f"{OLD[2]}^{{tree}}"))

    def test_take_old_is_the_old_tree_with_the_kept_paths_from_the_parent(self):
        replay.compute(self.repo, self.m, self.m["steps"][0], self.dir)
        s = self.m["steps"][1]
        replay.take_old(s, KEEP, "the end tree is develop (spec D1)")
        tree, conflicts, _ = replay.compute(self.repo, self.m, s, self.dir)
        self.assertEqual(conflicts, [])
        old3 = git(self.repo, "rev-parse", f"{OLD[2]}^{{tree}}")
        diff = git(self.repo, "diff", "--name-only", old3, tree).split()
        self.assertEqual(diff, ["tools/x.txt"])
        d = replay.differs(self.repo, self.m, s)
        self.assertTrue(d and all(x["reason"] for x in d), d)
        self.assertTrue(any("old step's tree" in x["reason"] for x in d), d)

    def test_folded_entry_needs_a_reason(self):
        self.m["folded"][0]["reason"] = ""
        self.assertTrue(any("folded" in p for p in seriesb.validate(self.m)))


if __name__ == "__main__":
    unittest.main()
