#!/usr/bin/env python3
"""Unit tests for the tools/gen-stories.py classifier (bead oo-qnmv).

A .m file whose own header declares NS* types in a signature is NOT a mechanical rename: renaming
it to .c changes an interface used across the tree. It must be routed to the Foundation sweep
first, and its rename bead emitted only after that bead closes.

Run:  python3 tools/test_gen_stories.py
"""
import importlib.util, sys, tempfile, unittest, warnings
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
        self.assertFalse(gs.is_c_file(p), "header declares NSString*: not a mechanical rename")
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
        self.assertTrue(gs.is_c_file(p))
        self.assertEqual(gs.classify(p), "renames")

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
    """The four files bead oo-qnmv named, as they stand in the upstream tree."""

    KNOWN = ["OOQuaternion.m", "OOMatrix.m", "OOMouseInteractionMode.m", "OOIsNumberLiteral.m"]

    def test_known_offenders_are_not_renames(self):
        by_name = {p.name: p for p in gs.m_files()}
        seen = 0
        for name in self.KNOWN:
            p = by_name.get(name)
            if p is None:
                continue
            seen += 1
            self.assertEqual(gs.classify(p), "foundation", f"{name} must not be a mechanical rename")
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
        self.assertFalse(gs.is_c_file(m), "a split NS* header signature is not a mechanical rename")
        self.assertEqual(gs.classify(m), "foundation")

    def test_strip_noncode_preserves_line_count(self):
        """Blanking must not shift line numbers: the stripper replaces text, not lines."""
        src = 'int a;\n/* two\n   lines */\nint b;  // tail\nNSString *c;\n'
        self.assertEqual(len(gs.strip_noncode(src).splitlines()), len(src.splitlines()))


if __name__ == "__main__":
    sys.exit(0 if unittest.main(exit=False, verbosity=2).result.wasSuccessful() else 1)
