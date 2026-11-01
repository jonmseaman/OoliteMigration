import json
import os
import tempfile
import unittest

from tools.series import manifest


def step(n, kind="hand-written", source="history", **kw):
    s = {
        "n": n,
        "branch": f"series/{n:03d}-step-{n}",
        "parent": "series/000-upstream-base" if n == 1 else f"series/{n - 1:03d}-step-{n - 1}",
        "title": f"Step {n}",
        "kind": kind,
        "source": {"type": source},
        "chapter": {"phase": "P2", "work_items": ["x"], "first": f"f{n}", "last": f"l{n}"} if source == "history" else None,
        "mechanical_command": "clang-format -i" if kind == "mechanical" else None,
        "description": f"series/pr/{n:03d}-step-{n}.md",
    }
    s.update(kw)
    return s


def good():
    return {"steps": [step(1), step(2), step(3, kind="mechanical", source="develop")], "ledger": [], "exclusions": []}


class ManifestTest(unittest.TestCase):
    def test_good_manifest_has_no_violations(self):
        self.assertEqual(manifest.validate(good()), [])

    def test_round_trip_is_stable_and_lf(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = os.path.join(tmp, "m.json")
            manifest.save(p, good())
            self.assertEqual(manifest.load(p), good())
            raw = open(p, "rb").read()
            self.assertNotIn(b"\r\n", raw)
            self.assertEqual(json.loads(raw), good())

    # rule 1: n contiguous from 1; branch series/NNN-slug with NNN = n; parent chain
    def test_rule1_gap_in_numbering(self):
        m = good(); m["steps"][1]["n"] = 5
        self.assertTrue(any(v.startswith("rule 1") for v in manifest.validate(m)))

    def test_rule1_branch_number_must_match_n(self):
        m = good(); m["steps"][1]["branch"] = "series/007-step-2"
        self.assertTrue(any(v.startswith("rule 1") for v in manifest.validate(m)))

    def test_rule1_branch_pattern(self):
        m = good(); m["steps"][0]["branch"] = "series/1-Step"
        self.assertTrue(any(v.startswith("rule 1") for v in manifest.validate(m)))

    def test_rule1_parent_chain(self):
        m = good(); m["steps"][2]["parent"] = "series/001-step-1"
        self.assertTrue(any(v.startswith("rule 1") for v in manifest.validate(m)))

    # rule 4: chapter iff history; chapters contiguous; mechanical_command iff mechanical
    def test_rule4_history_needs_chapter(self):
        m = good(); m["steps"][0]["chapter"] = None
        self.assertTrue(any(v.startswith("rule 4") for v in manifest.validate(m)))

    def test_rule4_non_history_has_no_chapter(self):
        m = good(); m["steps"][2]["chapter"] = {"phase": "P0", "work_items": [], "first": "a", "last": "b"}
        self.assertTrue(any(v.startswith("rule 4") for v in manifest.validate(m)))

    def test_rule4_chapters_contiguous_against_inventory_order(self):
        order = {"f1": 0, "l1": 4, "f2": 5, "l2": 9}
        self.assertEqual(manifest.validate(good(), order=order), [])
        order["f2"] = 7
        self.assertTrue(any(v.startswith("rule 4") for v in manifest.validate(good(), order=order)))

    def test_rule4_mechanical_needs_command(self):
        m = good(); m["steps"][2]["mechanical_command"] = None
        self.assertTrue(any(v.startswith("rule 4") for v in manifest.validate(m)))
        m = good(); m["steps"][0]["mechanical_command"] = "x"
        self.assertTrue(any(v.startswith("rule 4") for v in manifest.validate(m)))

    # rule 5: independent steps before all others
    def test_rule5_independent_first(self):
        m = good(); m["steps"][1]["kind"] = "independent"
        self.assertTrue(any(v.startswith("rule 5") for v in manifest.validate(m)))
        m = good(); m["steps"][0]["kind"] = "independent"
        self.assertEqual(manifest.validate(m), [])

    # rule 6: ledger balances
    def test_rule6_ledger(self):
        m = good(); m["ledger"] = [{"id": "bridge", "added_in": 1, "removed_in": 2}]
        self.assertEqual(manifest.validate(m), [])
        m["ledger"] = [{"id": "bridge", "added_in": 2, "removed_in": None}]
        self.assertTrue(any(v.startswith("rule 6") for v in manifest.validate(m)))
        m["ledger"] = [{"id": "bridge", "added_in": 2, "removed_in": 2}]
        self.assertTrue(any(v.startswith("rule 6") for v in manifest.validate(m)))

    # rule 9: no bookkeeping ids in titles
    def test_rule9_bookkeeping_ids(self):
        for title in ("ADR-0056 house style", "bead oo-9ht.39 Entity", "fix oo-abc"):
            m = good(); m["steps"][0]["title"] = title
            self.assertTrue(any(v.startswith("rule 9") for v in manifest.validate(m)), title)
        m = good(); m["steps"][0]["title"] = "Convert to C++: the oofnd core"
        self.assertEqual(manifest.validate(m), [])


if __name__ == "__main__":
    unittest.main()
