# oofnd unit tests: meson test -C build/meson_<type> --suite oofnd
#
# One executable per test_*.cpp, plain C++20 on the in-tree oo_test.hpp harness. Add a new test
# file's name here as well: tools/check-oofnd.sh fails when a test_*.cpp is missing from this list.

oofnd_tests = [
    'test_expected',
    'test_ref',
    'test_weakset',
    'test_data',
    'test_filesystem',
    'test_resourcepaths',
    'test_cocoa_macros',
]

foreach t : oofnd_tests
    exe = executable(
        'oofnd_' + t,
        t + '.cpp',
        dependencies: oofnd_dep,
        override_options: oofnd_override_options,
        install: false,
    )
    test(t, exe, suite: 'oofnd', timeout: 60)
endforeach
