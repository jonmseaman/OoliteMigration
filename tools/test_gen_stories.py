#!/usr/bin/env python3
"""Unit tests for the tools/gen-stories.py classifier (bead oo-qnmv).

A .m file whose own header declares NS* types in a signature is NOT a mechanical rename: renaming
it to .c changes an interface used across the tree. It must be routed to the Foundation sweep
first, and its rename bead emitted only after that bead closes.

Run:  python3 tools/test_gen_stories.py
"""
import importlib.util, json, subprocess, sys, tempfile, unittest, warnings
from pathlib import Path

warnings.simplefilter("ignore", ResourceWarning)  # the generator reads files without closing them

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("gen_stories", TOOLS / "gen-stories.py")
gs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gs)

C_BODY = """#include "Thing.h"

BOOL ThingIsGood(int n)
{
	return n > 0;
}
"""


class ClassifierTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def write(self, stem, body, header):
        m = self.dir / (stem + ".m")
        m.write_text(body)
        if header is not None:
            (self.dir / (stem + ".h")).write_text(header)
        return m

    def test_header_with_nsstring_signature_is_not_a_rename(self):
        p = self.write("Thing", C_BODY, "NSString *ThingDescription(int n);\n")
        self.assertTrue(gs.body_is_c(p), "body alone is plain C")
        self.assertTrue(gs.header_declares_ns(p))
        self.assertNotEqual(gs.classify(p), "renames",
                            "header declares NSString*: not a mechanical rename")
        self.assertEqual(gs.classify(p), "foundation")

    def test_header_with_nssize_value_type_is_not_a_rename(self):
        p = self.write("Thing", C_BODY, "NSSize ThingSize(int n);\n")
        self.assertEqual(gs.classify(p), "foundation")

    def test_header_with_nsstring_parameter_is_not_a_rename(self):
        p = self.write("Thing", C_BODY, "BOOL ThingIsNumber(NSString *s, BOOL spaces);\n")
        self.assertEqual(gs.classify(p), "foundation")

    def test_plain_c_header_is_a_rename(self):
        p = self.write("Thing", C_BODY, "#include <stdbool.h>\nBOOL ThingIsGood(int n);\n")
        self.assertFalse(gs.header_declares_ns(p))
        self.assertEqual(gs.classify(p), "renames")

    def test_no_second_definition_of_the_rename_rule(self):
        """Bead oo-yg8p: the rename rule has exactly one definition, classify()'s 'renames' branch.

        is_c_file() was a dead second copy of it, reachable only from this file. Its removal is
        only safe while nothing reintroduces a parallel definition, so assert the module exposes
        no such helper and that the tests ask the live function.
        """
        self.assertFalse(hasattr(gs, "is_c_file"),
                         "is_c_file() is a second definition of classify()'s rename rule")
        # Spelled in two pieces so this scan does not match its own needle.
        needle = "gs.is_c_" + "file("
        src = (TOOLS / "test_gen_stories.py").read_text()
        self.assertNotIn(needle, src, "tests must exercise the live classifier")

    def test_ns_mentioned_only_in_a_comment_is_still_a_rename(self):
        p = self.write("Thing", C_BODY,
                       '// returns an NSString * description, e.g. @"(w + xi)"\n'
                       "/* NSRect is not used here */\n"
                       "BOOL ThingIsGood(int n);\n")
        self.assertFalse(gs.header_declares_ns(p), "comments are not declarations")
        self.assertEqual(gs.classify(p), "renames")

    def test_no_header_at_all_is_a_rename(self):
        p = self.write("Thing", C_BODY, None)
        self.assertFalse(gs.header_declares_ns(p))
        self.assertEqual(gs.classify(p), "renames")

    def test_objc_class_is_a_conversion(self):
        p = self.write("Thing", "@implementation Thing\n@end\n", "@interface Thing : NSObject\n@end\n")
        self.assertFalse(gs.body_is_c(p))
        self.assertEqual(gs.classify(p), "convert")


class RealTreeTest(unittest.TestCase):
    """The four files bead oo-qnmv named, as they stand in the upstream tree.

    When oo-qnmv wrote this, each of the four had a plain-C body and a header declaring an NS*
    signature, so the test pinned classify() == "foundation" for them. The Phase 2 Foundation sweep
    (ADR-0043: oo-dupk, oo-6283, oo-q6bf, oo-7zgv) then deliberately removed those NS* signatures,
    after which "renames" is the CORRECT class for them -- that flip is exactly the "rename bead
    emitted after the Foundation bead closes" that oo-qnmv designed. Bead oo-3rb.167 therefore split
    the old test in two so neither half depends on how far the sweep has got:
      * the exact real-world declarations oo-qnmv caught are kept as fixtures and must still be
        classed "foundation" (the detector's teeth, independent of the tree);
      * on the live tree, each file is "foundation" iff its header still names an NS* type, checked
        against an independent regex rather than against header_declares_ns() itself.
    """

    KNOWN = ["OOQuaternion.mm", "OOMatrix.mm", "OOMouseInteractionMode.mm", "OOIsNumberLiteral.mm"]  # .m before seam 2.1 (oo-x7o)

    # The NS* declaration each KNOWN header carried before the ADR-0043 sweep, verbatim from the
    # sweep commits (219eca63e, 77b4ffaf2, 2983f7128, 25ed6ac50).
    PRE_SWEEP_DECLARATIONS = {
        "OOQuaternion": 'NSString *QuaternionDescription(Quaternion quaternion);\t// @"(w + xi + yj + zk)"\n',
        "OOMatrix": 'NSString *OOMatrixDescription(OOMatrix matrix);\t\t// @"{{#, #, #, #}, {#, #, #, #}, {#, #, #, #}, {#, #, #, #}}"\n',
        "OOMouseInteractionMode": "NSString *OOStringFromMouseInteractionMode(OOMouseInteractionMode mode);\n",
        "OOIsNumberLiteral": "BOOL OOIsNumberLiteral(NSString *string, BOOL allowSpaces);\n",
    }

    # Independent of gs.text_declares_ns: any NS-prefixed identifier outside a comment.
    NS_IDENT = r"\bNS[A-Z][A-Za-z0-9_]*"

    def test_known_offenders_are_not_renames(self):
        """Kept name (oo-qnmv): the declarations that made these offenders are still not renames."""
        self.assertEqual({f"{s}.mm" for s in self.PRE_SWEEP_DECLARATIONS}, set(self.KNOWN))
        with tempfile.TemporaryDirectory() as d:
            for stem, decl in self.PRE_SWEEP_DECLARATIONS.items():
                m = Path(d) / f"{stem}.mm"
                m.write_text(C_BODY)
                (Path(d) / f"{stem}.h").write_text(f"#include <stdbool.h>\n{decl}")
                self.assertTrue(gs.body_is_c(m))
                self.assertEqual(gs.classify(m), "foundation",
                                 f"{stem}.h's pre-sweep declaration must not be a mechanical rename")

    def test_known_offenders_are_foundation_iff_header_still_names_ns(self):
        import re
        by_name = {p.name: p for p in gs.m_files()}
        seen = 0
        for name in self.KNOWN:
            p = by_name.get(name)
            if p is None:
                continue
            seen += 1
            h = gs.header_for(p)
            code = gs.strip_noncode(h.read_text(errors="replace")) if h else ""
            names_ns = re.search(self.NS_IDENT, code) is not None
            want = "foundation" if names_ns else "renames"
            self.assertEqual(gs.classify(p), want,
                             f"{name}: header {'still names' if names_ns else 'no longer names'} an NS* type")
        if seen == 0:
            self.skipTest("upstream tree not present")

    def test_no_rename_story_has_an_ns_header(self):
        by_name = {p.name: p for p in gs.m_files()}
        if not by_name:
            self.skipTest("upstream tree not present")
        for title, *_ in gs.sweep_renames():
            p = by_name[title.split(": ")[-1]]
            self.assertFalse(gs.header_declares_ns(p), f"{p.name} is in sweep_renames with an NS* header")

    def test_every_ns_header_c_file_has_a_foundation_story(self):
        by_name = {p.name: p for p in gs.m_files()}
        if not by_name:
            self.skipTest("upstream tree not present")
        titles = {t for t, *_ in gs.sweep_foundation()}
        for p in by_name.values():
            if gs.classify(p) == "foundation":
                self.assertIn(f"Migrate Foundation usage to oofnd: {p.name}", titles)


class SplitDeclarationTest(unittest.TestCase):
    """bead oo-mnzc: header_declares_ns scanned line-by-line, so an NS* type in a signature SPLIT
    ACROSS LINES escaped detection and the file was classed as a mechanical rename. Declarations
    are now matched per ';'-terminated declaration, as bead oo-qnmv's reviewer prescribed.

    Every case here is paired: a MUST-catch split declaration, a negative control that must stay
    unmatched, and for each control a BREAK TWIN with one detail changed that must flip to True.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)
        self.n = 0

    def hdr(self, header):
        """A plain-C .m with the given header; returns header_declares_ns for it."""
        self.n += 1
        d = self.dir / f"c{self.n}"
        d.mkdir()
        (d / "Thing.m").write_text(C_BODY)
        (d / "Thing.h").write_text(header)
        return gs.header_declares_ns(d / "Thing.m")

    # --- MUST CATCH: the defect this bead fixes -------------------------------------------
    def test_split_nsstring_pointer_return_is_caught(self):
        self.assertTrue(self.hdr("NSString *\nThingDescription(int n);\n"))

    def test_split_ns_value_struct_returns_are_caught(self):
        for ty in ("NSSize", "NSRect", "NSPoint", "NSRange"):
            with self.subTest(type=ty):
                self.assertTrue(self.hdr(f"{ty}\nThing{ty[2:]}(void);\n"),
                                f"{ty} on its own line is still a declaration")

    def test_split_parameter_on_its_own_line_is_caught(self):
        self.assertTrue(self.hdr("BOOL ThingIs(\n    NSString *s,\n    BOOL spaces);\n"))

    def test_split_declaration_inside_extern_c_is_caught(self):
        self.assertTrue(self.hdr('extern "C" {\nNSString *\nThingDesc(void);\n}\n'))

    # --- NEGATIVE CONTROLS: must stay unmatched ------------------------------------------
    def test_control_line_comment_mention_is_not_a_declaration(self):
        self.assertFalse(self.hdr("// returns an NSString * description\nBOOL T(int n);\n"))

    def test_control_block_comment_declaration_is_not_a_declaration(self):
        self.assertFalse(self.hdr("/* NSString *\n   TDesc(int n); */\nBOOL T(int n);\n"))

    def test_control_multiline_block_comment_is_not_a_declaration(self):
        self.assertFalse(self.hdr("/*\n * NSSize\n * TSize(void);\n */\nBOOL T(int n);\n"))

    def test_control_string_literal_is_not_a_declaration(self):
        self.assertFalse(self.hdr('const char *k = "NSString *TDesc(int n);";\nBOOL T(int);\n'),
                         "an NS* signature inside a string literal is not a declaration")

    def test_control_preprocessor_line_is_not_a_declaration(self):
        self.assertFalse(self.hdr("#define FOO NSString *\nBOOL T(int n);\n"))

    def test_control_plain_c_multiline_header_is_not_a_declaration(self):
        self.assertFalse(self.hdr("int\nThingCount(void);\n"))

    # --- BREAK TWINS: each control with one detail changed, must now MATCH ----------------
    def test_twin_comment_becomes_real_declaration(self):
        self.assertTrue(self.hdr("/* nothing */\nNSString *\nTDesc(int n);\n"),
                        "twin of the block-comment control: the declaration is now real code")

    def test_twin_closed_comment_then_real_split_declaration(self):
        self.assertTrue(self.hdr("/*\n * NSSize\n */\nNSSize\nTSize(void);\n"),
                        "twin of the multiline-comment control: same text, outside the comment")

    def test_twin_string_literal_becomes_real_declaration(self):
        self.assertTrue(self.hdr('const char *k = "hello";\nNSString *\nTDesc(int n);\n'),
                        "twin of the string control: the declaration moved out of the literal")

    def test_twin_preprocessor_becomes_real_declaration(self):
        self.assertTrue(self.hdr("#define FOO 1\nNSString *\nTDesc(int n);\n"),
                        "twin of the preprocessor control: NS* is now on a code line")

    def test_twin_plain_c_header_becomes_split_ns_declaration(self):
        self.assertTrue(self.hdr("#include <stdbool.h>\nNSSize\nThingIsGood(int n);\n"),
                        "twin of the plain-C control: the return type is now NSSize")

    # --- classification consequence ------------------------------------------------------
    def test_split_declaration_routes_to_foundation_not_renames(self):
        d = self.dir / "cls"
        d.mkdir()
        m = d / "Thing.m"
        m.write_text(C_BODY)
        (d / "Thing.h").write_text("NSString *\nThingDescription(int n);\n")
        self.assertTrue(gs.body_is_c(m), "the body alone is plain C")
        self.assertNotEqual(gs.classify(m), "renames",
                            "a split NS* header signature is not a mechanical rename")
        self.assertEqual(gs.classify(m), "foundation")

    def test_strip_noncode_preserves_line_count(self):
        """Blanking must not shift line numbers: the stripper replaces text, not lines."""
        src = 'int a;\n/* two\n   lines */\nint b;  // tail\nNSString *c;\n'
        self.assertEqual(len(gs.strip_noncode(src).splitlines()), len(src.splitlines()))


class ScenarioCatalogueSweepTest(unittest.TestCase):
    """bead oo-1bf.12: sweep_scenarios() hardcoded scenarios 002-017, so 018-020 were never
    emitted although docs/phases/scenario-catalogue.json has carried them since oo-9w5.

    The sweep now reads the catalogue the way sweep_component() reads COMPONENT. Two properties
    matter and each has its own test:

      1. EVERY non-landed catalogue entry is emitted, including ones the catalogue gains later.
         Keyed on `status == 'landed'` and nothing else - an allow-list of statuses would have
         silently dropped 020, whose status is the non-obvious 'buildable-pending-own-calibration'.
      2. The titles of 002-017 are BYTE-IDENTICAL to the ones the literal list produced, because
         the generator's only identity key is the title: one changed character re-files a
         duplicate of an existing bead. They are frozen below as literals, so a drift is a test
         failure rather than a duplicated queue.
    """

    # Verbatim from the literal list this bead replaced (tools/gen-stories.py before oo-1bf.12).
    FROZEN_TITLES = [
        "Golden scenario 002: witchspace jump",
        "Golden scenario 003: combat encounter",
        "Golden scenario 004: trade cycle",
        "Golden scenario 005: mission trigger",
        "Golden scenario 006: save/load round-trip",
        "Golden scenario 007: test-oxp: JS interface",
        "Golden scenario 008: test-oxp: materials",
        "Golden scenario 009: test-oxp: shaders",
        "Golden scenario 010: test-oxp: PNG",
        "Golden scenario 011: test-oxp: AI overflow",
        "Golden scenario 012: test-oxp: retro missions",
        "Golden scenario 013: load checklist save Constrictor",
        "Golden scenario 014: load checklist save Nova",
        "Golden scenario 015: load checklist save Trumbles",
        "Golden scenario 016: load checklist save CloakingDevice",
        "Golden scenario 017: load checklist save ThargoidPlans",
    ]

    def titles(self, items):
        return [t for t, *_ in items]

    def test_titles_002_017_are_byte_identical(self):
        got = self.titles(gs.sweep_scenarios())
        for want in self.FROZEN_TITLES:
            self.assertIn(want, got, "title drift re-files a duplicate of an existing bead")

    def test_every_non_landed_catalogue_entry_is_emitted(self):
        cat = gs.catalogue_scenarios()
        if not cat:
            self.skipTest("no scenario catalogue in this checkout")
        want = [s["id"] for s in cat if s.get("status") != "landed"]
        got = self.titles(gs.sweep_scenarios())
        self.assertEqual(len(got), len(want),
                         "one story per non-landed catalogue entry, no more and no fewer")
        for sid in want:
            self.assertTrue(any(t.startswith(f"Golden scenario {sid}:") for t in got),
                            f"catalogue entry {sid} is not emitted")

    def test_landed_scenarios_are_skipped(self):
        cat = gs.catalogue_scenarios()
        if not cat:
            self.skipTest("no scenario catalogue in this checkout")
        landed = [s["id"] for s in cat if s.get("status") == "landed"]
        self.assertTrue(landed, "the catalogue should record at least one landed scenario (001)")
        got = self.titles(gs.sweep_scenarios())
        for sid in landed:
            self.assertFalse(any(t.startswith(f"Golden scenario {sid}:") for t in got),
                             f"{sid} is landed; its golden is already in the tree")

    def test_018_020_are_emitted_with_the_catalogue_name(self):
        """The three beads the Phase 0 review filed by hand (oo-1bf.5/.6/.7) took their title
        suffix from the catalogue's `name`, so the generator must produce exactly that or it
        duplicates them."""
        cat = {s["id"]: s for s in gs.catalogue_scenarios()}
        if not cat:
            self.skipTest("no scenario catalogue in this checkout")
        got = self.titles(gs.sweep_scenarios())
        for sid in ("018", "019", "020"):
            self.assertIn(sid, cat, f"the catalogue must carry scenario {sid}")
            self.assertIn(f"Golden scenario {sid}: {cat[sid]['name']}", got)

    def test_a_future_catalogue_entry_needs_no_generator_change(self):
        """The point of the change: an entry the generator has never heard of is emitted, and a
        status string nobody anticipated does not suppress it (020's real status is
        'buildable-pending-own-calibration', not 'buildable')."""
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "cat.json"
            p.write_text(json.dumps({"scenarios": [
                {"id": "001", "name": "launch-dock", "status": "landed", "purpose": "p"},
                {"id": "021", "name": "brand-new-thing", "status": "some-status-nobody-planned-for",
                 "purpose": "A purpose sentence."},
            ]}), encoding="utf-8")
            items = gs.sweep_scenarios(catalogue_path=p)
        self.assertEqual(self.titles(items), ["Golden scenario 021: brand-new-thing"])
        self.assertIn("A purpose sentence.", items[0][1])
        self.assertEqual(items[0][2], ["tests/golden/scenarios/021/run.sh --check",
                                       "tests/golden/scenarios/021/run.sh --stability 10"])

    def test_missing_catalogue_yields_no_stories_rather_than_a_crash(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(gs.sweep_scenarios(catalogue_path=Path(tmp) / "nope.json"), [])

    def test_dry_run_prints_every_non_landed_scenario_title(self):
        """The acceptance line's shape: `gen-stories.py --dry-run` must PRINT 018-020 even though
        beads exist for them, because a dry run reports what the sweep covers. Running the real
        script (not just the function) is what pins the printing, which no unit-level call does.
        """
        cat = gs.catalogue_scenarios()
        if not cat:
            self.skipTest("no scenario catalogue in this checkout")
        p = subprocess.run([sys.executable, str(TOOLS / "gen-stories.py"), "--dry-run"],
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr[-2000:])
        printed = [ln for ln in p.stdout.splitlines() if "Golden scenario 0" in ln]
        expected = [s["id"] for s in cat if s.get("status") != "landed"]
        self.assertEqual(len(printed), len(expected),
                         "one printed line per non-landed catalogue entry")
        for sid in expected:
            self.assertTrue(any(f"Golden scenario {sid}:" in ln for ln in printed),
                            f"--dry-run does not print scenario {sid}")


if __name__ == "__main__":
    sys.exit(0 if unittest.main(exit=False, verbosity=2).result.wasSuccessful() else 1)
