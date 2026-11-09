# Review: the C++ migration as a stack of 24 branches

The fork `jonmseaman/oolite` moves Oolite from Objective-C/GNUstep to C++20. It no longer depends on `gnustep-base` or the Objective-C runtime. Scripting is upstream's QuickJS-ng binding from #767 and #768 throughout: every step keeps it and converts it to C++ along with the rest of the game; there is no separate scripting layer of the fork's own anymore.

To make review incremental, the work is split into 24 stacked branches on top of #768's head, so the stack assumes #767 and #768 land first.

**How to review:** go top to bottom. Each **Diff** link shows only that step's **wip** change against its parent.
When #767 and #768 are merged, and my changes are ready, I'll open pull requests to OoliteProject/oolite.
Until then, each **PR** link is a draft pull request inside the fork, against the step's parent, with that step's description.

| # | PR | Diff | Step | Files | + / − |
|--:|---|---|---|--:|--:|
| 1 | [#5](https://github.com/jonmseaman/oolite/pull/5) | [`001-random-seed-env`](https://github.com/jonmseaman/oolite/compare/db49201034e5ab3857342fb4dca199d5f17b93fb...seriesb/001-random-seed-env) | Let OO_RANDOM_SEED pin the random seed | 1 | +10 / −1 |
| 2 | [#6](https://github.com/jonmseaman/oolite/pull/6) | [`002-safety-net`](https://github.com/jonmseaman/oolite/compare/seriesb/001-random-seed-env...seriesb/002-safety-net) | Add a test safety net: deterministic runs, GUI and component tests | 51 | +14088 / −56 |
| 3 | [#7](https://github.com/jonmseaman/oolite/pull/7) | [`003-objcpp-switch`](https://github.com/jonmseaman/oolite/compare/seriesb/002-safety-net...seriesb/003-objcpp-switch) | Compile the game as Objective-C++, keeping #768's QuickJS-ng binding | 285 | +1695 / −1306 |
| 4 | [#8](https://github.com/jonmseaman/oolite/pull/8) | [`004-oofnd-core`](https://github.com/jonmseaman/oolite/compare/seriesb/003-objcpp-switch...seriesb/004-oofnd-core) | Add oofnd, a small Foundation replacement, and an Objective-C floor without Foundation | 110 | +15541 / −1069 |
| 5 | [#9](https://github.com/jonmseaman/oolite/pull/9) | [`005-typed-accessors`](https://github.com/jonmseaman/oolite/compare/seriesb/004-oofnd-core...seriesb/005-typed-accessors) | Move most oo_*ForKey dictionary accessors to typed PListView::get | 233 | +10047 / −2990 |
| 6 | [#10](https://github.com/jonmseaman/oolite/pull/10) | [`006-foundation-wave-1`](https://github.com/jonmseaman/oolite/compare/seriesb/005-typed-accessors...seriesb/006-foundation-wave-1) | Move Foundation usage to oofnd, part 1 | 383 | +22073 / −13985 |
| 7 | [#11](https://github.com/jonmseaman/oolite/pull/11) | [`007-foundation-wave-2`](https://github.com/jonmseaman/oolite/compare/seriesb/006-foundation-wave-1...seriesb/007-foundation-wave-2) | Move Foundation usage to oofnd, part 2 | 406 | +31019 / −21749 |
| 8 | [#12](https://github.com/jonmseaman/oolite/pull/12) | [`008-selector-families`](https://github.com/jonmseaman/oolite/compare/seriesb/007-foundation-wave-2...seriesb/008-selector-families) | Retire the remaining Foundation selectors and their bridge callers | 398 | +11222 / −18810 |
| 9 | [#13](https://github.com/jonmseaman/oolite/pull/13) | [`009-leaf-conversions`](https://github.com/jonmseaman/oolite/compare/seriesb/008-selector-families...seriesb/009-leaf-conversions) | Drop gnustep-base, then convert the first classes to C++: maths, leaf utilities, OXP verifier | 493 | +37788 / −11811 |
| 10 | [#14](https://github.com/jonmseaman/oolite/pull/14) | [`010-module-conversions`](https://github.com/jonmseaman/oolite/compare/seriesb/009-leaf-conversions...seriesb/010-module-conversions) | Convert scripting, entities, audio and materials classes to C++ | 530 | +68715 / −14436 |
| 11 | [#15](https://github.com/jonmseaman/oolite/pull/15) | [`011-first-slices`](https://github.com/jonmseaman/oolite/compare/seriesb/010-module-conversions...seriesb/011-first-slices) | Convert the large files in slices; delete the first Objective-C bridges | 360 | +25538 / −18357 |
| 12 | [#16](https://github.com/jonmseaman/oolite/pull/16) | [`012-shipentity-slices`](https://github.com/jonmseaman/oolite/compare/seriesb/011-first-slices...seriesb/012-shipentity-slices) | Convert ShipEntity to C++ | 97 | +25579 / −10515 |
| 13 | [#17](https://github.com/jonmseaman/oolite/pull/17) | [`013-universe-player-slices`](https://github.com/jonmseaman/oolite/compare/seriesb/012-shipentity-slices...seriesb/013-universe-player-slices) | Convert Universe and PlayerEntity to C++ | 161 | +13352 / −9112 |
| 14 | [#18](https://github.com/jonmseaman/oolite/pull/18) | [`014-facade-deletions`](https://github.com/jonmseaman/oolite/compare/seriesb/013-universe-player-slices...seriesb/014-facade-deletions) | Delete the Objective-C bridges | 549 | +44179 / −53425 |
| 15 | [#19](https://github.com/jonmseaman/oolite/pull/19) | [`015-entity-facade`](https://github.com/jonmseaman/oolite/compare/seriesb/014-facade-deletions...seriesb/015-entity-facade) | Delete the Entity bridge and the last Objective-C bridges | 491 | +26932 / −34722 |
| 16 | [#20](https://github.com/jonmseaman/oolite/pull/20) | [`016-objc-runtime-out`](https://github.com/jonmseaman/oolite/compare/seriesb/015-entity-facade...seriesb/016-objc-runtime-out) | Remove the Objective-C runtime and rename the sources to .cpp | 727 | +9941 / −18348 |
| 17 | [#21](https://github.com/jonmseaman/oolite/pull/21) | [`017-gcc-build`](https://github.com/jonmseaman/oolite/compare/seriesb/016-objc-runtime-out...seriesb/017-gcc-build) | Fix code that GCC warns about or evaluates differently | 225 | +1044 / −901 |
| 18 | [#22](https://github.com/jonmseaman/oolite/pull/22) | [`018-develop-fixes`](https://github.com/jonmseaman/oolite/compare/seriesb/017-gcc-build...seriesb/018-develop-fixes) | Small fixes after the migration | 36 | +457 / −183 |
| 19 | [#23](https://github.com/jonmseaman/oolite/pull/23) | [`019-source-hygiene`](https://github.com/jonmseaman/oolite/compare/seriesb/018-develop-fixes...seriesb/019-source-hygiene) | Make comments describe the code; use #pragma once | 714 | +49189 / −46161 |
| 20 | [#24](https://github.com/jonmseaman/oolite/pull/24) | [`020-tests-and-tooling`](https://github.com/jonmseaman/oolite/compare/seriesb/019-source-hygiene...seriesb/020-tests-and-tooling) | Tests and developer tooling | 20 | +1113 / −76 |
| 21 | [#25](https://github.com/jonmseaman/oolite/pull/25) | [`021-c-as-cxx`](https://github.com/jonmseaman/oolite/compare/seriesb/020-tests-and-tooling...seriesb/021-c-as-cxx) | Compile the remaining C sources as C++; build QuickJS-ng with the fork's patches | 480 | +9771 / −9344 |
| 22 | [#26](https://github.com/jonmseaman/oolite/pull/26) | [`022-upstream-28ceaaba0-ports`](https://github.com/jonmseaman/oolite/compare/seriesb/021-c-as-cxx...seriesb/022-upstream-28ceaaba0-ports) | Port upstream #783 (joystick control of GUI screens); build the macOS bundle without Foundation | 21 | +565 / −147 |
| 23 | [#27](https://github.com/jonmseaman/oolite/pull/27) | [`023-google-style-format`](https://github.com/jonmseaman/oolite/compare/seriesb/022-upstream-28ceaaba0-ports...seriesb/023-google-style-format) | Reformat with Google-style clang-format (optional) | 570 | +212358 / −229698 |
| 24 | [#28](https://github.com/jonmseaman/oolite/pull/28) | [`024-post-conversion-fixes`](https://github.com/jonmseaman/oolite/compare/seriesb/023-google-style-format...seriesb/024-post-conversion-fixes) | Small fixes after the conversion; Mozilla polyfills for expansions | 7 | +165 / −8 |

**Whole stack:** [`#768` → `seriesb/024-post-conversion-fixes`](https://github.com/jonmseaman/oolite/compare/db49201034e5ab3857342fb4dca199d5f17b93fb...seriesb/024-post-conversion-fixes): 1149 files, +362518 / −249419.

### Compare each branch with its parent

Each line opens your difftool on the step's whole tree against its parent's (`git difftool --dir-diff <parent> <branch>`).

```sh
git difftool --dir-diff seriesb/000a-upstream-767-quickjs-option seriesb/000b-upstream-768-quickjs-only
git difftool --dir-diff seriesb/000b-upstream-768-quickjs-only seriesb/001-random-seed-env
git difftool --dir-diff seriesb/001-random-seed-env seriesb/002-safety-net
git difftool --dir-diff seriesb/002-safety-net seriesb/003-objcpp-switch
git difftool --dir-diff seriesb/003-objcpp-switch seriesb/004-oofnd-core
git difftool --dir-diff seriesb/004-oofnd-core seriesb/005-typed-accessors
git difftool --dir-diff seriesb/005-typed-accessors seriesb/006-foundation-wave-1
git difftool --dir-diff seriesb/006-foundation-wave-1 seriesb/007-foundation-wave-2
git difftool --dir-diff seriesb/007-foundation-wave-2 seriesb/008-selector-families
git difftool --dir-diff seriesb/008-selector-families seriesb/009-leaf-conversions
git difftool --dir-diff seriesb/009-leaf-conversions seriesb/010-module-conversions
git difftool --dir-diff seriesb/010-module-conversions seriesb/011-first-slices
git difftool --dir-diff seriesb/011-first-slices seriesb/012-shipentity-slices
git difftool --dir-diff seriesb/012-shipentity-slices seriesb/013-universe-player-slices
git difftool --dir-diff seriesb/013-universe-player-slices seriesb/014-facade-deletions
git difftool --dir-diff seriesb/014-facade-deletions seriesb/015-entity-facade
git difftool --dir-diff seriesb/015-entity-facade seriesb/016-objc-runtime-out
git difftool --dir-diff seriesb/016-objc-runtime-out seriesb/017-gcc-build
git difftool --dir-diff seriesb/017-gcc-build seriesb/018-develop-fixes
git difftool --dir-diff seriesb/018-develop-fixes seriesb/019-source-hygiene
git difftool --dir-diff seriesb/019-source-hygiene seriesb/020-tests-and-tooling
git difftool --dir-diff seriesb/020-tests-and-tooling seriesb/021-c-as-cxx
git difftool --dir-diff seriesb/021-c-as-cxx seriesb/022-upstream-28ceaaba0-ports
git difftool --dir-diff seriesb/022-upstream-28ceaaba0-ports seriesb/023-google-style-format
git difftool --dir-diff seriesb/023-google-style-format seriesb/024-post-conversion-fixes
git difftool --dir-diff seriesb/024-post-conversion-fixes seriesb/025-libcurl-http
```

### Notes

- **Upstream's recent PRs** (#740 to #783) are kept in every step: each lands in the step that converts or writes the code it touches, so no step reverts upstream's work. #783 (joystick control of GUI screens) is ported in step 22, with a fix to its `clearMappings` that upstream may want too.
- **Step 23** (Google-style clang-format) is formatting only and touches most source files. It is offered as optional; step 24 is built on top of it, so dropping it means rebasing step 24.
- **Step 24** holds small fixes found after the conversion (each pinned by a test) and the Mozilla `quote()` and Array/String generics polyfills for expansions.
- **GCC:** step 17 fixes code that GCC warns about or evaluates differently, but the stack is built and tested with Clang only (`mk.sh`'s default `clang.ini`), and CI adds no GCC job. GCC is not verified: with GCC's LTO two core unit tests fail to link.
- Built and tested on Windows (MSYS2 UCRT64) only; #768's scripting harness (`poc/`) runs there from step 9. macOS and Linux have **not** been verified.
