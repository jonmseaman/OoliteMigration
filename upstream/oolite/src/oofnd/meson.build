# oofnd — the Foundation replacement (Phase 2, docs/architecture.md §3.4).
#
# Header-first C++20: every component so far is header-only, so oofnd is an include path and
# nothing more. Consumers write #include "oofnd/Expected.hpp" and depend on oofnd_dep. When a
# component needs a .cpp, add it here as a static library and fold it into oofnd_dep, e.g.
#
#     oofnd_lib = static_library('oofnd', files('PList.cpp'),
#                                include_directories: oofnd_inc,
#                                override_options: oofnd_override_options)
#     oofnd_dep = declare_dependency(include_directories: oofnd_inc, link_with: oofnd_lib)
#
# The unit tests are tests/unit/oofnd (meson test --suite oofnd); tools/check-oofnd.sh is the
# build-dir-free acceptance that compiles the same files directly.

oofnd_inc = include_directories('..')
oofnd_override_options = ['cpp_std=c++20', 'warning_level=2', 'werror=true']
# ICU: oo::str::localizedCompare (String.hpp) collates with it, as GNUstep's -localizedCompare:
# does (bead oo-r4d6). GNUstep-base already links the same ICU, so the game gains no new DLL.
oofnd_icu_dep = dependency('icu-i18n', required: true)
oofnd_dep = declare_dependency(include_directories: oofnd_inc, dependencies: oofnd_icu_dep)

# The Objective-C floor (bead oo-3rb.1, proposed ADR-0029) on libobjc2 alone. Its OOObject root class
# and OOConstantString (the class behind @"..." literals) went with bead oo-4aq6a.8: no game class or
# test is rooted on OOObject and no literal is compiled, so -fconstant-string-class goes too (a stray
# @"..." would now fail to link). Test consumers (tests/unit/oofnd/test_objc_*.mm) compile with these.
oofnd_objc_args = ['-fno-constant-cfstrings']
oofnd_objc_dep = declare_dependency(
    include_directories: oofnd_inc,
    sources: files('Exception.cpp', 'objc/OOAssert.mm'),
    dependencies: cc.find_library('objc', required: true),
)
