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


if __name__ == "__main__":
    sys.exit(0 if unittest.main(exit=False, verbosity=2).result.wasSuccessful() else 1)
