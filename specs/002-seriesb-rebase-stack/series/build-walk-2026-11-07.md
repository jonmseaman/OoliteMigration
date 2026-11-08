# Build walk of the seriesb stack, 2026-11-07

Each branch was checked out in turn and run with `./mk.sh build debug` (Clang), `meson test -C build/meson_debug` (all unit suites) and `./mk.sh test debug` (smoke). MSYS2 UCRT64 on Windows 11. The full component and GUI suites were not run. Logs: `.agent-tmp/walk-debug/` (not committed). Build times are for an incremental build in one shared build directory.

| Branch | PR | Commit | Build | Unit | Smoke | Notes |
|---|---|---|---|---|---|---|
| `seriesb/000a-upstream-767-quickjs-option` | – | `3758f8a09` | FAIL(16s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/000b-upstream-768-quickjs-only` | – | `db4920103` | FAIL(27s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/001-random-seed-env` | #5 | `8c400595a` | FAIL(14s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/002-safety-net` | #6 | `688ee5a49` | FAIL(17s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/003-objcpp-switch` | #7 | `ca9c93b01` | FAIL(19s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/004-oofnd-core` | #8 | `1626d2982` | FAIL(18s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/005-typed-accessors` | #9 | `c70f90e1b` | FAIL(18s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/006-foundation-wave-1` | #10 | `5dcbdb243` | FAIL(18s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/007-foundation-wave-2` | #11 | `a8e3430ac` | FAIL(21s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/008-selector-families` | #12 | `8a6face44` | FAIL(20s) | skip | not run | compile error in GNUstep's `Foundation/NSBackgroundActivityScheduler.h`: `'__block' is not allowed on an Objective-C instance variable` |
| `seriesb/009-leaf-conversions` | #13 | `96938db03` | FAIL(111s) | skip | not run | unit-test executables fail to link (`undefined symbol: OOGLNoteCurrentFunction`, `cxx_OOCheckOpenGLErrors`) in the debug build; `dev` build passed all three on 009–012 |
| `seriesb/010-module-conversions` | #14 | `a5e43acf4` | FAIL(165s) | skip | not run | unit-test executables fail to link (`undefined symbol: OOGLNoteCurrentFunction`, `cxx_OOCheckOpenGLErrors`) in the debug build; `dev` build passed all three on 009–012 |
| `seriesb/011-first-slices` | #15 | `e32ae7043` | FAIL(171s) | skip | not run | unit-test executables fail to link (`undefined symbol: OOGLNoteCurrentFunction`, `cxx_OOCheckOpenGLErrors`) in the debug build; `dev` build passed all three on 009–012 |
| `seriesb/012-shipentity-slices` | #16 | `2271ef556` | FAIL(170s) | skip | not run | unit-test executables fail to link (`undefined symbol: OOGLNoteCurrentFunction`, `cxx_OOCheckOpenGLErrors`) in the debug build; `dev` build passed all three on 009–012 |
| `seriesb/013-universe-player-slices` | #17 | `39ba47530` | FAIL(168s) | skip | not run | unit-test executables fail to link (`undefined symbol: OOGLNoteCurrentFunction`, `cxx_OOCheckOpenGLErrors`) in the debug build; `dev` build passed all three on 009–012 |
| `seriesb/014-facade-deletions` | #18 | `c0bcaf6e4` | FAIL(169s) | skip | not run | unit-test executables fail to link (`undefined symbol: OOGLNoteCurrentFunction`, `cxx_OOCheckOpenGLErrors`) in the debug build; `dev` build passed all three on 009–012 |
| `seriesb/015-entity-facade` | #19 | `359a58a9b` | pass(175s) | pass | pass |  |
| `seriesb/016-objc-runtime-out` | #20 | `6a7809596` | pass(166s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409) |
| `seriesb/017-gcc-build` | #21 | `c9f2ccf46` | pass(165s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409) |
| `seriesb/018-develop-fixes` | #22 | `c9cc0a9e3` | pass(162s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409) |
| `seriesb/019-source-hygiene` | #23 | `184f5dbcb` | pass(164s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409) |
| `seriesb/020-tests-and-tooling` | #24 | `e8680b544` | pass(153s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409) |
| `seriesb/021-c-as-cxx` | #25 | `8b0f70e42` | pass(154s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409) |
| `seriesb/022-upstream-28ceaaba0-ports` | #26 | `a553c5b00` | pass(157s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409) |
| `seriesb/023-google-style-format` | #27 | `a283df36b` | FAIL(40s) | skip | not run | `src/Core/OOProfilingStopwatch.cpp` fails: `mmsyscom.h: unknown type name 'UINT'` (Windows header order) |
| `seriesb/024-post-conversion-fixes` | #28 | `d33b0eecb` | pass(151s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409) |
| `seriesb/025-libcurl-http` | – | `336c64c8a` | pass(153s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409); `test_http` and `test_OOOXZManager` fail |
| `seriesb/026-dev-container` | – | `d934a20c9` | pass(155s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409); `test_http` and `test_OOOXZManager` fail |
| `seriesb/027-ship-library-keys` | – | `ac60522c9` | pass(141s) | FAIL | pass | `test_EntityScriptEvents` aborts (0xc0000409); `test_http` and `test_OOOXZManager` fail |

## Reading the table

- **000a–008 (and so 003, the branch that prompted this):** do not compile here. These steps still use GNUstep's Objective-C Foundation, and this MSYS2's GNUstep headers reject `__block` on an ivar. This is a toolchain/header version problem, not a change in the stack; it hits upstream's #767 and #768 heads too (000a, 000b).
- **009–014:** the debug build fails to link some unit-test executables on `OOGLNoteCurrentFunction`. A `dev` build of 009–012 passed build, unit and smoke before the walk was restarted in debug mode; 013 and 014 in `dev` were not completed.
- **015:** the first branch where build, unit and smoke all pass in debug.
- **016–022, 024–027:** build and smoke pass; unit has one failure, `test_EntityScriptEvents` (abort). 025–027 add `test_http` and `test_OOOXZManager` failures.
- **023:** does not compile (`UINT` unknown in `mmsyscom.h`); 024 builds again.

Nothing was fixed here; these are observations for Jon.
