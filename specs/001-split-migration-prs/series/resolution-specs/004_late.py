# (appended to 004.py's CHANGES by the line at the end of 004.py)
# QuickJS-ng 0.16.2's own sources and link lines warn under Clang 23:
#  - four void functions return a void expression (-Wpedantic, the subproject's warning_level=3):
#    a wrap patch drops the `return` keyword, as develop's quickjs-ng-void-return.patch does for 0.17.0
#  - its threads dependency puts -pthread on link lines, which the MinGW Clang driver reports as
#    unused: on Windows the dependency is the compile flag only (the history's fix)
ADD = {"subprojects/packagefiles/quickjs-ng-void-return.patch": "004_files/quickjs-ng-void-return.patch"}
CHANGES_LATE = {
    "subprojects/quickjs-ng.wrap": [("wrapdb_version = 0.16.2-1\n",
                                     "wrapdb_version = 0.16.2-1\ndiff_files = quickjs-ng-void-return.patch\n")],
    "src/meson.build": [(
        "quickjs_ng_proj = subproject('quickjs-ng',",
        "# QuickJS-ng adds dependency('threads') (-pthread) to its link line, and every target\n"
        "# that links it. The MinGW clang driver does not use -pthread when linking (cutils.h takes Win32\n"
        "# threads under _WIN32), so each link printed \"argument unused during compilation: '-pthread'\".\n"
        "# On Windows the threads dependency is the same compile flag without the unused link flag, so the\n"
        "# objects and the links are unchanged and the driver has nothing to report.\n"
        "if host_machine.system() == 'windows'\n"
        "    meson.override_dependency('threads', declare_dependency(compile_args: ['-pthread']))\n"
        "endif\n"
        "quickjs_ng_proj = subproject('quickjs-ng',")],
}
