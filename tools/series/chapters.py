"""The series plan of research R14 (option B): history chapters and the develop tail, as data.

History chapters are contiguous first-parent ranges of the migration history (OoliteMigration
commits, reachable in oolite-dev as refs/series/history). The tail groups develop's commits after
the squash by purpose; the Google-style reformat comes last.
"""

ANCHORS = {
    "upstream_base": "49a5eb9fc",
    "develop_target": "3aa8d65e8",
    "history_ref": "refs/series/history",
    "history_prefix": "upstream/oolite",
    "history_start": "4f089047c",
    "history_end": "refs/series/history^",
    "history_upstream": [{"from_history_commit": "4f089047c", "upstream_commit": "dc55e3e05"},
                         {"from_history_commit": "4c2bfae9f", "upstream_commit": "9ee8ff22f"}],
    "format": {"clang_format_version": "22.1.8", "style_file_from": "49a5eb9fc"},
}

# (slug, phase, title, work items, first, last)
HISTORY = [
    ("safety-net", "P0", "Add a test safety net: deterministic runs, GUI and component tests",
     ["0.1 iteration-order determinism", "0.4 seed and floating-point hooks for reproducible runs", "0.8 GUI tier",
      "0.13 component tier"],
     "7555b5d425", "8af7966e7d"),
    ("js-facade", "P1", "Put the game's JavaScript behind an engine façade, with a QuickJS-ng backend beside SpiderMonkey",
     ["1.1 define the façade", "1.2 retarget call sites", "1.3 QuickJS-ng backend"], "3ca73e5a13", "7bc686c0af"),
    ("objective-cxx", "P2", "Compile the game as Objective-C++",
     ["2.1 the .m -> .mm switch"], "c9c0525383", "c9c0525383"),
    ("quickjs-switch", "P1", "Run the game on QuickJS-ng and remove SpiderMonkey and NSPR",
     ["1.4 differential test", "1.5 delete SpiderMonkey"], "3b6aec8c6f", "a7e3ed1efc"),
    ("oofnd-core", "P2", "Add oofnd, a small Foundation replacement, and an Objective-C floor without Foundation",
     ["2.2 Ref/WeakRef/AutoreleaseScope", "2.2 PList", "2.2 FileSystem", "2.2 Defaults", "Objective-C floor"],
     "e31130fa0d", "916311e66d"),
    ("typed-accessors", "P2", "Move most oo_*ForKey dictionary accessors to typed PListView::get",
     ["2.2 typed accessors, first sweep"], "b73f2cd400", "bc9a02ca7b"),
    ("foundation-wave-1", "P2", "Move Foundation usage to oofnd, part 1",
     ["2.3 Foundation -> oofnd, per file"], "931bee60e9", "ecfafab479"),
    ("foundation-wave-2", "P2", "Move Foundation usage to oofnd, part 2",
     ["2.3 Foundation sweeps", "OOLog, NSAssert and NSUserDefaults gaps"], "5faa477a34", "fa9cbc6c24"),
    ("selector-families", "P2", "Retire the remaining Foundation selectors and their bridge callers",
     ["selector families", "bridge callers"], "b75b5d1bc6", "e0b9e24b22"),
    ("leaf-conversions", "P3", "Drop gnustep-base, then convert the first classes to C++: maths, leaf utilities, OXP verifier",
     ["2.4 delete libgnustep-base", "3.1 oomath", "3.2 OXPVerifier", "3.3 leaf utilities"], "66914fbbed", "67027c84d1"),
    ("module-conversions", "P3", "Convert scripting, entities, audio and materials classes to C++",
     ["3.4 Materials", "3.5 audio", "3.6 scripting bindings", "3.7 entities"], "1964f76209", "ab5dc6cd72"),
    ("first-slices", "P3", "Convert the large files in slices; delete the first Objective-C facades",
     ["slice plans", "slices", "facade deletions"], "ad82bd1efe", "0c01939de7"),
    ("shipentity-slices", "P3", "Convert ShipEntity to C++", ["3.7 ShipEntity slices"], "477a4919bc", "9a7a14fe2b"),
    ("universe-player-slices", "P3", "Convert Universe and PlayerEntity to C++",
     ["3.7 PlayerEntity slices", "3.8 Universe slices"], "4b272b165e", "33abe86219"),
    ("facade-deletions", "P3", "Delete the Objective-C facades", ["facade-deletion batches"], "d01d45e47c", "2c2aae1316"),
    ("entity-facade", "P3", "Delete the root Entity facade", ["the root Entity facade"], "d012b77f21", "473facf469"),
    ("objc-runtime-out", "P4", "Remove the Objective-C runtime and rename the sources to .cpp",
     ["4.1 deferred release", "4.2 runtime and rename"], "1248d43e1b", "af1f220542"),
    ("gcc-build", "P4", "Build with GCC as well as Clang", ["4.3 GCC"], "5fda5e404c", "903e52cbdd"),
    ("upstream-9ee8ff22f-port", "P4", "Port upstream changes #369 to #765 into the C++ code",
     ["upstream 9ee8ff22f pulled and ported"], "883d339f93", "6504faa3b9"),
]

# (slug, kind, title, develop commits, mechanical command)
TAIL = [
    ("develop-fixes", "hand-written", "Small fixes after the migration",
     ["935aedb20", "5346a1800", "66567dc26", "736572b67", "c971f1641"], None),
    ("source-hygiene", "hand-written", "Make comments describe the code; use #pragma once",
     ["2ceced1f8", "c9c225c78", "0b49abd31"], None),
    # before c-as-cxx: 448aa6d20 edits the component tests 51d05af43 brings and the .clangd 70c176921 adds
    ("tests-and-tooling", "hand-written", "Tests and developer tooling",
     ["51d05af43", "517abcfcd", "119e29325", "70c176921"], None),
    ("c-as-cxx", "hand-written", "Compile the remaining C sources as C++; upgrade QuickJS-ng",
     ["448aa6d20", "6e1654a6b"], None),
    # 35d0ef8a0 (the readme) follows develop's merge of upstream, which it edits after; 4ef61a09d
    # (mk.sh format) goes with the reformat it is the tool for.
    # ec2462f6f fixes the macOS C++ build that the #766 ports (ac193cfe7) make: it goes with them
    ("upstream-49a5eb9fc-ports", "hand-written", "Port upstream #766, #774 and #781",
     ["7912222ed", "f80c74210", "a1e2ce889", "ac193cfe7", "ec2462f6f", "35d0ef8a0"], None),
    ("google-style-format", "mechanical", "Reformat with Google-style clang-format (optional)",
     ["13eb19ee7", "266118a39", "4ef61a09d", "21c3048a2"],
     "take .clang-format from 3aa8d65e8 and add mk.sh format/format-check (4ef61a09d), then run clang-format 22 -i on every .h/.hpp/.c/.cpp under src/ and tests/"),
]

EXCLUSIONS = [
    {"path_glob": ".zed/**", "reason": "editor settings for the fork's own setup"},
    {"path_glob": ".vscode/**", "reason": "editor settings for the fork's own setup"},
    {"revert_commit": "3aa8d65e8", "reason": "the fork's CI filter (push builds only for master and develop)"},
]
