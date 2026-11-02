import unittest

from tools.series import selectors as sel

TABLE = sel.build_table([
    ("initWithColors::andSystemInfo:", "initWithColors:col2:andSystemInfo:"),
    ("getContainersOfCommodity::", "getContainersOfCommodity:how_much:"),
    ("doesHitLine::withPosition:andIJK:::", "doesHitLine:v1:withPosition:i:j:k:"),
    ("doesHitLine::", "doesHitLine:v1:"),
    ("setDimensionsAndCorridor:::", "setDimensionsAndCorridor:ddc:launching:"),
])


class RenameTest(unittest.TestCase):
    def r(self, text):
        return sel.rename_selectors(text, TABLE)

    def test_declaration_unnamed_parts_get_names(self):
        self.assertEqual(self.r("- (id)initWithColors:(OOColor*)col1:(OOColor*)col2 andSystemInfo:(const oo::PList&)i;"),
                         "- (id)initWithColors:(OOColor*)col1 col2:(OOColor*)col2 andSystemInfo:(const oo::PList&)i;")
        self.assertEqual(self.r("- (id) initWithColors:(OOColor *)col1 :(OOColor *)col2 andSystemInfo:(NSDictionary *)s;"),
                         "- (id) initWithColors:(OOColor *)col1 col2:(OOColor *)col2 andSystemInfo:(NSDictionary *)s;")

    def test_message_sends(self):
        self.assertEqual(self.r('x = [UNIVERSE getContainersOfCommodity:@"Narcotics":num];'),
                         'x = [UNIVERSE getContainersOfCommodity:@"Narcotics" how_much:num];')
        self.assertEqual(self.r("[u getContainersOfCommodity:oo::NSStringOrNil(c):adjustment]"),
                         "[u getContainersOfCommodity:oo::NSStringOrNil(c) how_much:adjustment]")
        self.assertEqual(self.r("[(DockEntity*)s setDimensionsAndCorridor:allow_docking:ddc:allow_launching];"),
                         "[(DockEntity*)s setDimensionsAndCorridor:allow_docking ddc:ddc launching:allow_launching];")
        self.assertEqual(self.r("thing = [[SkyEntity alloc] initWithColors:col1:col2 andSystemInfo:systeminfo];"),
                         "thing = [[SkyEntity alloc] initWithColors:col1 col2:col2 andSystemInfo:systeminfo];")

    def test_named_part_renamed(self):
        self.assertEqual(self.r("d = [s doesHitLine:a :b withPosition:o andIJK:x :y :z];"),
                         "d = [s doesHitLine:a v1:b withPosition:o i:x j:y k:z];")

    def test_already_upstream_names_unchanged(self):
        t = "[u getContainersOfCommodity:c how_much:n]; - (id)initWithColors:(C*)a col2:(C*)b andSystemInfo:(D*)s;"
        self.assertEqual(self.r(t), t)

    def test_ternary_and_nested_brackets_inside_args(self):
        self.assertEqual(self.r("[u getContainersOfCommodity:(flag ? a : b):[self count:x]]"),
                         "[u getContainersOfCommodity:(flag ? a : b) how_much:[self count:x]]")
        self.assertEqual(self.r("[u getContainersOfCommodity:flag ? a : b :n]"),
                         "[u getContainersOfCommodity:flag ? a : b how_much:n]")

    def test_selector_literal(self):
        self.assertEqual(self.r("@selector(getContainersOfCommodity::)"), "@selector(getContainersOfCommodity:how_much:)")

    def test_unrelated_and_strings_untouched(self):
        t = 'OOLog(@"x", @"getContainersOfCommodity:%@:%u", a, b); [x getContainersOfGoods:n scarce:YES legal:NO];'
        self.assertEqual(self.r(t), t)

    def test_cxx_prefixed_methods_untouched(self):
        t = "- (std::vector<int>)cxx_getContainersOfCommodity:(const std::string&)c:(OOCargoQuantity)n;"
        self.assertEqual(self.r(t), t)

    def test_include_rename_reaches_cxx_sources(self):
        # the history's sources become .cpp (step 17); #737's header rename applies to them too
        for path in ("src/Core/a.cpp", "src/Core/a.hpp", "src/Core/a.c", "src/Core/a.h", "src/Core/a.mm"):
            self.assertEqual(sel.upstream_renames(path, '#include "OOCocoa.h"\n'), '#include "OOFoundation.h"\n', path)
        self.assertEqual(sel.upstream_renames("src/a.py", '"OOCocoa.h"'), '"OOCocoa.h"')

    def test_selector_renames_stay_objc_only(self):
        t = "[u getContainersOfCommodity:c :n];\n"
        self.assertEqual(sel.upstream_renames("src/Core/a.cpp", t), t)
        self.assertNotEqual(sel.upstream_renames("src/Core/a.mm", t), t)

    def test_selectors_in_decls(self):
        self.assertEqual(sel.selectors_in_decls("- (GLfloat)doesHitLine:(HPVector)v0 :(HPVector)v1;\n"
                                                "+ (BOOL) getCloudTextureNameFor:(OOColor *)color :(GLfloat)impress :(GLfloat)bias\n"),
                         ["doesHitLine::", "getCloudTextureNameFor:::"])


if __name__ == "__main__":
    unittest.main()
