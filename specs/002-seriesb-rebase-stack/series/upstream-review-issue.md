# Review: the C++ migration as a stack of 25 branches

The fork `jonmseaman/oolite` moves Oolite from Objective-C/GNUstep to C++20. It no longer depends on `gnustep-base` or the Objective-C runtime, and it builds with Clang and GCC. Scripting uses upstream's QuickJS-ng binding (#767, #768).

To make review incremental, the work is split into 25 stacked branches. Each one is a single commit on top of the one before. The stack starts from #768's head, so it assumes #767 and #768 land first.

**How to review:** go top to bottom. Each **Diff** link shows only that step's change against its parent. Each step's description (to follow as a PR, or attached here) covers what changes, why it's at that point in the order, any behaviour changes and the test that pins each one, and how to review it. Mechanical steps (5, 20, 22, 24) are easiest to check by rerunning the transformation on the parent and comparing the results.

| # | Diff | Step | Files | + / − |
|--:|---|---|--:|--:|
| 1 | [`001-random-seed-env`](https://github.com/jonmseaman/oolite/compare/db49201034e5ab3857342fb4dca199d5f17b93fb...seriesb/001-random-seed-env) | Let OO_RANDOM_SEED pin the random seed | 1 | +10 / −1 |
| 2 | [`002-safety-net`](https://github.com/jonmseaman/oolite/compare/seriesb/001-random-seed-env...seriesb/002-safety-net) | Add a test safety net: deterministic runs, GUI and component tests | 51 | +14088 / −56 |
| 3 | [`003-quickjs-switch`](https://github.com/jonmseaman/oolite/compare/seriesb/002-safety-net...seriesb/003-quickjs-switch) | Put the game's JavaScript behind an engine façade on QuickJS-ng, replacing the PRs' binding; compile as Objective-C++ | 407 | +34314 / −25740 |
| 4 | [`004-oofnd-core`](https://github.com/jonmseaman/oolite/compare/seriesb/003-quickjs-switch...seriesb/004-oofnd-core) | Add oofnd, a small Foundation replacement, and an Objective-C floor without Foundation | 111 | +15674 / −1205 |
| 5 | [`005-typed-accessors`](https://github.com/jonmseaman/oolite/compare/seriesb/004-oofnd-core...seriesb/005-typed-accessors) | Move most oo_*ForKey dictionary accessors to typed PListView::get | 237 | +10166 / −3014 |
| 6 | [`006-foundation-wave-1`](https://github.com/jonmseaman/oolite/compare/seriesb/005-typed-accessors...seriesb/006-foundation-wave-1) | Move Foundation usage to oofnd, part 1 | 383 | +22283 / −14220 |
| 7 | [`007-foundation-wave-2`](https://github.com/jonmseaman/oolite/compare/seriesb/006-foundation-wave-1...seriesb/007-foundation-wave-2) | Move Foundation usage to oofnd, part 2 | 406 | +30968 / −21853 |
| 8 | [`008-selector-families`](https://github.com/jonmseaman/oolite/compare/seriesb/007-foundation-wave-2...seriesb/008-selector-families) | Retire the remaining Foundation selectors and their bridge callers | 397 | +11266 / −18975 |
| 9 | [`009-leaf-conversions`](https://github.com/jonmseaman/oolite/compare/seriesb/008-selector-families...seriesb/009-leaf-conversions) | Drop gnustep-base, then convert the first classes to C++: maths, leaf utilities, OXP verifier | 481 | +36876 / −11236 |
| 10 | [`010-module-conversions`](https://github.com/jonmseaman/oolite/compare/seriesb/009-leaf-conversions...seriesb/010-module-conversions) | Convert scripting, entities, audio and materials classes to C++ | 526 | +67516 / −14560 |
| 11 | [`011-first-slices`](https://github.com/jonmseaman/oolite/compare/seriesb/010-module-conversions...seriesb/011-first-slices) | Convert the large files in slices; delete the first Objective-C facades | 357 | +25649 / −18519 |
| 12 | [`012-shipentity-slices`](https://github.com/jonmseaman/oolite/compare/seriesb/011-first-slices...seriesb/012-shipentity-slices) | Convert ShipEntity to C++ | 97 | +25603 / −10561 |
| 13 | [`013-universe-player-slices`](https://github.com/jonmseaman/oolite/compare/seriesb/012-shipentity-slices...seriesb/013-universe-player-slices) | Convert Universe and PlayerEntity to C++ | 161 | +13313 / −9088 |
| 14 | [`014-facade-deletions`](https://github.com/jonmseaman/oolite/compare/seriesb/013-universe-player-slices...seriesb/014-facade-deletions) | Delete the Objective-C facades | 555 | +44638 / −53685 |
| 15 | [`015-entity-facade`](https://github.com/jonmseaman/oolite/compare/seriesb/014-facade-deletions...seriesb/015-entity-facade) | Delete the root Entity facade | 492 | +29871 / −34797 |
| 16 | [`016-objc-runtime-out`](https://github.com/jonmseaman/oolite/compare/seriesb/015-entity-facade...seriesb/016-objc-runtime-out) | Remove the Objective-C runtime and rename the sources to .cpp | 713 | +9263 / −17877 |
| 17 | [`017-gcc-build`](https://github.com/jonmseaman/oolite/compare/seriesb/016-objc-runtime-out...seriesb/017-gcc-build) | Build with GCC as well as Clang | 206 | +1011 / −887 |
| 18 | [`018-upstream-9ee8ff22f-port`](https://github.com/jonmseaman/oolite/compare/seriesb/017-gcc-build...seriesb/018-upstream-9ee8ff22f-port) | Port upstream changes #369 to #765 into the C++ code | 126 | +4959 / −7781 |
| 19 | [`019-develop-fixes`](https://github.com/jonmseaman/oolite/compare/seriesb/018-upstream-9ee8ff22f-port...seriesb/019-develop-fixes) | Small fixes after the migration | 38 | +806 / −422 |
| 20 | [`020-source-hygiene`](https://github.com/jonmseaman/oolite/compare/seriesb/019-develop-fixes...seriesb/020-source-hygiene) | Make comments describe the code; use #pragma once | 734 | +114550 / −95461 |
| 21 | [`021-tests-and-tooling`](https://github.com/jonmseaman/oolite/compare/seriesb/020-source-hygiene...seriesb/021-tests-and-tooling) | Tests and developer tooling | 21 | +1059 / −83 |
| 22 | [`022-c-as-cxx`](https://github.com/jonmseaman/oolite/compare/seriesb/021-tests-and-tooling...seriesb/022-c-as-cxx) | Compile the remaining C sources as C++; upgrade QuickJS-ng | 516 | +9970 / −9936 |
| 23 | [`023-upstream-49a5eb9fc-ports`](https://github.com/jonmseaman/oolite/compare/seriesb/022-c-as-cxx...seriesb/023-upstream-49a5eb9fc-ports) | Port upstream #766, #774 and #781 | 60 | +3918 / −2638 |
| 24 | [`024-google-style-format`](https://github.com/jonmseaman/oolite/compare/seriesb/023-upstream-49a5eb9fc-ports...seriesb/024-google-style-format) | Reformat with Google-style clang-format (optional) | 511 | +201011 / −230913 |
| 25 | [`025-upstream-quickjs-binding`](https://github.com/jonmseaman/oolite/compare/seriesb/024-google-style-format...seriesb/025-upstream-quickjs-binding) | Move the scripting layer to upstream's QuickJS-ng binding | 229 | +18526 / −27964 |

**Whole stack:** [`#768` → `seriesb/025-upstream-quickjs-binding`](https://github.com/jonmseaman/oolite/compare/db49201034e5ab3857342fb4dca199d5f17b93fb...seriesb/025-upstream-quickjs-binding): 1149 files, +363997 / −250233.

### Compare each branch with its parent (Sublime Merge search)

Paste a line into Sublime Merge's search to show only that step's commits. Step 18 is dropped, so step 19 compares with step 17.

```text
branch:seriesb/000b-upstream-768-quickjs-only and not branch:seriesb/000a-upstream-767-quickjs-option
branch:seriesb/001-random-seed-env and not branch:seriesb/000b-upstream-768-quickjs-only
branch:seriesb/002-safety-net and not branch:seriesb/001-random-seed-env
branch:seriesb/003-objcpp-switch and not branch:seriesb/002-safety-net
branch:seriesb/004-oofnd-core and not branch:seriesb/003-objcpp-switch
branch:seriesb/005-typed-accessors and not branch:seriesb/004-oofnd-core
branch:seriesb/006-foundation-wave-1 and not branch:seriesb/005-typed-accessors
branch:seriesb/007-foundation-wave-2 and not branch:seriesb/006-foundation-wave-1
branch:seriesb/008-selector-families and not branch:seriesb/007-foundation-wave-2
branch:seriesb/009-leaf-conversions and not branch:seriesb/008-selector-families
branch:seriesb/010-module-conversions and not branch:seriesb/009-leaf-conversions
branch:seriesb/011-first-slices and not branch:seriesb/010-module-conversions
branch:seriesb/012-shipentity-slices and not branch:seriesb/011-first-slices
branch:seriesb/013-universe-player-slices and not branch:seriesb/012-shipentity-slices
branch:seriesb/014-facade-deletions and not branch:seriesb/013-universe-player-slices
branch:seriesb/015-entity-facade and not branch:seriesb/014-facade-deletions
branch:seriesb/016-objc-runtime-out and not branch:seriesb/015-entity-facade
branch:seriesb/017-gcc-build and not branch:seriesb/016-objc-runtime-out
branch:seriesb/019-develop-fixes and not branch:seriesb/017-gcc-build
branch:seriesb/020-source-hygiene and not branch:seriesb/019-develop-fixes
branch:seriesb/021-tests-and-tooling and not branch:seriesb/020-source-hygiene
branch:seriesb/022-c-as-cxx and not branch:seriesb/021-tests-and-tooling
branch:seriesb/023-upstream-49a5eb9fc-ports and not branch:seriesb/022-c-as-cxx
branch:seriesb/024-google-style-format and not branch:seriesb/023-upstream-49a5eb9fc-ports
branch:seriesb/025-upstream-quickjs-binding and not branch:seriesb/024-google-style-format
```

### Notes

- **Step 24** (Google-style clang-format) is formatting only, and it touches every source file. It's offered as optional. Step 25 is built on top of it, so dropping it means rebasing step 25.
- **Steps 18 and 23** port upstream changes (#369–#765, and #766/#774/#781) into the converted C++. The diffs show how each one was carried over.
- Built and tested on Windows (MSYS2 UCRT64) only. macOS and Linux have **not** been verified.
