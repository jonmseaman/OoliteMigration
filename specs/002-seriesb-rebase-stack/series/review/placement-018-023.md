# Placement of old steps 018 and 023 (analysis only, 2026-11-04)

Inputs: `archive/seriesb-facade/017..018` (177 hunks, `git diff --text -U3`) and `/022..023`
(605 hunks); rebuilt `seriesb/003-objcpp-switch` .. `seriesb/009-leaf-conversions` (`1912db791`);
end target `655583067`. The scripts and raw data are in `.agent-tmp/s018/`:
- `analyze.py` blames each hunk across the archive tags `002..base`. It also checks whether each
  hunk's old and new form (with one context line either side, whitespace ignored) is present in
  every archive tag and every new branch.
- `classify.py` detects formatting-only hunks.
- `table.py` writes the tables below.
- The raw data is in `hunks018c.json` and `hunks023c.json`.

Columns:
- **blame/form-from**: the old step that last wrote the hunk's removed lines (from blame;
  `<=002` means upstream or 002 code), then the first old step from which the 017 (or 022) form
  is continuously present.
- **new stack**: whether the hunk's old form (`O`) or new form (`N`) is in new 003-009. A hand
  check overrides this where the files differ in language.
- **target**: the step the hunk folds into. That is the earliest step whose tree contains the
  code the hunk touches: the step that wrote that code, or converted it from upstream's form.
  - `tail`: not in the range and owned by no step; stays in the late step with #783.
  - `drop`: not needed.
  - `n/a`: façade-only, or already absent.


## Summary (a = old 018 hunk, b = old 023 hunk; full tables below)

Every upstream port in old 018/023 repairs code an earlier old step rewrote from upstream's form
(mostly the C++ conversions 010–016) or wrote in the fork's older idiom (`#ifndef NDEBUG` for
debug-monitor code, `OOCocoa.h` in comments, `OOLITE_MAC_OS_X` for the AppKit UI). Each hunk folds
into that step; nothing from the range stays in 018 or 023.

**Fold into the replays still to come**
- 010: a11,24-26,28,48,51,59,65,70,95,98 (#756); a96,102,110,150 (#737); a69,105 (comments);
  a167-168 (test lines, ledger); b198,200,201,205-211 (#766 COCOA_UI); b267,274,287,290 + tests
  b603-604 (#766 GLSL 330→120 translator); b416 (`OOLITE_MACOS` defined).
- 011: a52,88-90 (#756); a124-126 (#744) + a166 (test line, ledger); a169 (#747 `copyUrlKey`
  test); b585,591 (#774); b587-589 (#766).
- 012: a44-47 (#756); b199,202-204,212-215,552,553 (#766 COCOA_UI).
- 013: a118-119 (#756); b554-557 (#766 MSAA renderbuffer).
- 014: a29-32,41,42 (#740) + a171-172 (`lastsaveNameIsRememberedInTheDefaults`); a31,43,94 (#756);
  a33-40 (#749/#751 AnyKeyPressed).
- 015: a12-16,18,19,22,23 (#756); a20,21,106,107 (generated tables: clang-format off, #740/#756
  rows); a54,60 (comments); b42,558-560.
- 016: a58,62,63,68,71,116,123 (#748 include order); a100-101 (OOTypeEncodings.h table); a134
  (#737); b439 (#766); b381,420-429,581-584,592,594 (`OOLITE_MACOS` on upstream code, dormant);
  b1-4,6,7 (macOS CI and README).
- 017: include-what-you-use and GCC-only fixes (a10,17,27,49,55,56,64,66,72,74,76,81,83,87,91,93,
  104,115,122,127,130; a75,120,121,128; b48,388,595).
- 020: b18,41,196,197,216,418,517,527,528,580,586. 022: b413-415. 024: layout-only b hunks.

**Follow-up commits needed on rebuilt 004–009** (reverts of upstream forms or deployment-build
breaks; none shows in the Windows test-flavour gates those steps passed)
- 004: `meson.build` adds `tests/unit/oofnd` unconditionally (a5: not in deployment, Windows only);
  #737 comments (25 files name `OOCocoa.h`).
- 005: #737 comments.
- 006: `AI.mm -cxx_reactToMessage:` logs `debugContext` under `OO_DEBUG_MONITOR_ENABLED` but defines
  it under `!NDEBUG` — the deployment build does not compile (a7, a8); `OOTexture+FoundationBridge.h`
  `cachedTexturesByAge` under NDEBUG where #756 uses `OO_DEBUG_MONITOR_ENABLED`.
- 007: `OOAssert.h` compiles OOAssert/OOCAssert out under NDEBUG, so from 008 PlayerEntity
  `-deferredInit` skips ship set-up in a deployment build (a162,163,6,174,175; new test a176
  `test_objc_assert_ndebug`); `GameController.mm` console import/wait under NDEBUG (a50,53);
  `Universe+FoundationBridge.h` `entityList` under NDEBUG; Universe verification constants
  unguarded (a117); ICU missing from `install_deps.sh` and `icu-uc` from `oofnd/meson.build`
  (a2,161); `PlayerEntityKeyMapper.mm` `KeyMappingsFileName` on `OOLITE_MAC_OS_X` instead of
  `OOLITE_MAC_COCOA_UI` (b125); #737 comments.
- 008: `NSObjectOOExtensions.h/.mm` NDEBUG instead of #756's `OO_DEBUG_MONITOR_ENABLED`; #737
  comments; optional a29.
- 009: `allTextures()`/`totalSize` declared under NDEBUG but defined under
  `OO_DEBUG_MONITOR_ENABLED` (a57,61,67 and the matching `+ObjCBridge` files); core-suite meson gate
  (a5); GNUstep.conf optional in `post_build.sh`/`run_oolite.sh` (a1,a4); add
  `test_OoliteEquipmentControlScript` (#369) on QuickJS-ng's API (a165,170; ledger); expander
  digests (a173; ledger, Jon approved 2026-10-25); comments a78,80,92,b417.

**Already satisfied in rebuilt 003–009**: #742; #744; #740's macros absent; #747's source; #748's
maths/GL headers; #749/#751 key reads; every #766/#774/#781 hunk except b125 and b417 (009 still
has upstream's Objective-C COCOA_UI, GLSL translator, MSAA renderbuffer, front-buffer read).

**Tests arriving at other steps**: `test_objc_assert_ndebug` 007; `test_OoliteEquipmentControlScript`
009; `test_OOShaderProgram` GLSL cases 010; `copyUrlKey` 011; `lastsaveNameIsRememberedInTheDefaults`
014; `test_OOMathsHeaders` with the headers suite (old 019). Ledger rows: a166 (011), a167-168
(010), a173 (009).

**What remains**: old 018 nothing — dropped (a3/b10 cancel; a9 is 003's trim; a0 `llvm` package
goes with any `ar = 'llvm-ar'` line, which new 003–009 lack). Old 023 keeps no #766/#774/#781 code:
only #783 (T051a) plus fork-only tail items no step owns: version 1.95 (b5,b8), InfoPlist.strings
as UTF-8 (b0,b9), Info-gnustep.plist (b11), macOS packaging/meson/harness files for the
Foundation-free tree (b13-15,17,596-602). ~490 of 023's 605 hunks are formatting only (024
reformats; T055's final-tree check catches residue).

**Defaults taken by the analysis**: macOS code stays upstream's Objective-C through 009 and each
conversion step (010, 011, 013, 016) converts its macOS blocks rather than dropping them;
`OOLITE_MACOS` defined at 010, swaps at 016; macOS CI jobs dropped at 016 (see T058: for Jon);
`<cstring>`/GCC-only fixes at 017 (upstream's Linux CI on 009 might need some; unverified). None of
the deployment-break findings is verified by a build: they come from reading the guards.

| # | file:line (017) | upstream PR / kind | blame/form-from | new stack 003-009 | target | test |
|---|---|---|---|---|---|---|
| 0 | ShellScripts/Linux/install_package_fn.sh:24 | fork (llvm-ar) | <=002/<=002 | not in new 003-009 (clang.ini has no llvm-ar) | with clang.ini `ar = 'llvm-ar'` |  |
| 1 | ShellScripts/Linux/run_oolite.sh:180 | fork (no GNUstep.conf after gnustep-base) | <=002/<=002 | FOLLOW-UP: new 009 post_build/run_oolite still require GNUstep.conf.orig | 009 |  |
| 2 | ShellScripts/Windows/install_deps.sh:40 | fork (ICU for oofnd) | <=002/<=002 | FOLLOW-UP: new 007 adds icu-i18n; install_deps lacks icu | 007 |  |
| 3 | ShellScripts/common/post_build.sh:52 | fork | <=002/<=002 | net zero: 023 hunk 10 removes it again; END lacks it | drop |  |
| 4 | ShellScripts/common/post_build.sh:170 | fork (no GNUstep.conf after gnustep-base) | <=002/<=002 | FOLLOW-UP: new 009 post_build/run_oolite still require GNUstep.conf.orig | 009 |  |
| 5 | meson.build:135 | fork (#756 CI builds deployment; Windows-only unit tests) | 004,009/009 | FOLLOW-UP: new 004/009 meson.build add the suites unconditionally | 004 (oofnd part), 009 (core part) |  |
| 6 | meson.options:43 | fork (OOAssert live: deployment_unit_tests, test_objc_assert skipped under NDEBUG) | <=002/<=002 | FOLLOW-UP (with 162/163) | 007 |  |
| 7 | C/AI.cpp:451 | #756 (deployment compile) | <=002/<=002 | FOLLOW-UP: new 006-009 AI.mm reads debugContext under OO_DEBUG_MONITOR_ENABLED but defines it only under !NDEBUG | 006 |  |
| 8 | C/AI.cpp:460 | #756 (deployment compile) | 006/007 | FOLLOW-UP: new 006-009 AI.mm reads debugContext under OO_DEBUG_MONITOR_ENABLED but defines it only under !NDEBUG | 006 |  |
| 9 | C/Debug/OODebugStandards.cpp:73 | fork (style: anonymous namespace) | <=002/<=002 | as new 003's trim rule (not needed) | drop |  |
| 10 | C/Entities/DustEntity.cpp:42 | fork (include what you use) | 006/016 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 11 | C/Entities/DustEntity.h:75 | #756 | 010/014 | not yet reached; code absent in new 003-009 | 010 |  |
| 12 | C/Entities/Entity.cpp:131 | #756 | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 13 | C/Entities/EntityHelpers.cpp:37 | #756 | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 14 | C/Entities/EntityHelpers.cpp:99 | #756 | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 15 | C/Entities/EntityHelpers.cpp:115 | #756 | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 16 | C/Entities/EntityVirtualMembers.h:69 | #756 | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 17 | C/Entities/OOBreakPatternEntity.cpp:29 | fork (include what you use) | 016,<=002/016 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 18 | C/Entities/OOEntityCalledByName.cpp:650 | #756 | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 19 | C/Entities/OOEntityCalledByName.cpp:658 | #756 | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 20 | C/Entities/OOEntityCalledByNameTable.h:1 | #749/#751 (clang-format off) + #740 rows + #756 rows | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 21 | C/Entities/OOEntityCalledByNameTable.h:25 | #749/#751 (clang-format off) + #740 rows + #756 rows | 015,016/016 | not yet reached; code absent in new 003-009 | 015 |  |
| 22 | C/Entities/OOEntityObjectNamesTable.h:50 | #749/#751 (clang-format off) + #740 rows + #756 rows | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 23 | C/Entities/OOEntityObjectNamesTable.h:62 | #749/#751 (clang-format off) + #740 rows + #756 rows | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 24 | C/Entities/OOEntityWithDrawable.h:43 | #756 | 010/015 | not yet reached; code absent in new 003-009 | 010 |  |
| 25 | C/Entities/OOLightParticleEntity.h:65 | #756 | 010/015 | not yet reached; code absent in new 003-009 | 010 |  |
| 26 | C/Entities/OOParticleSystem.h:55 | #756 | 010/015 | not yet reached; code absent in new 003-009 | 010 |  |
| 27 | C/Entities/OOSunEntity.cpp:44 | fork (include what you use) | 006,008/014 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 28 | C/Entities/OOSunEntity.h:91 | #756 | 010/010 | not yet reached; code absent in new 003-009 | 010 |  |
| 29 | C/Entities/PlayerEntity.cpp:2222 | #740 | 007,014/014 | equivalent in new 007/008 (object().getIf<string>, setter); optional follow-up 008: assign as upstream | 014 | test_PlayerEntity lastsaveNameIsRememberedInTheDefaults (172) at 014 |
| 30 | C/Entities/PlayerEntity.h:113 | #740 | 014/014 | satisfied: new 003-009 PlayerEntity.h has upstream's (no load/save macros) | 014 |  |
| 31 | C/Entities/PlayerEntity.h:914 | #756 | 014/014 | not yet reached; code absent in new 003-009 | 014 |  |
| 32 | C/Entities/PlayerEntity.h:1394 | #740 | 014/014 | satisfied: new 009 has no OO_USE_CUSTOM_LOAD_SAVE | 014 |  |
| 33 | C/Entities/PlayerEntityControls.cpp:70 | #749/#751 (AnyKeyPressed helper) + <cstring> | 008,<=002/008 | new 009 PlayerEntityControls.mm keeps upstream's `|` (all keys read) | 014 |  |
| 34 | C/Entities/PlayerEntityControls.cpp:2417 | #749/#751 (all keys read) | 014/015 | satisfied in new 009 (upstream `|`); 014's conversion must keep it | 014 |  |
| 35 | C/Entities/PlayerEntityControls.cpp:2458 | #749/#751 (all keys read) | 014/015 | satisfied in new 009 (upstream `|`); 014's conversion must keep it | 014 |  |
| 36 | C/Entities/PlayerEntityControls.cpp:2552 | #749/#751 (all keys read) | 014/015 | satisfied in new 009 (upstream `|`); 014's conversion must keep it | 014 |  |
| 37 | C/Entities/PlayerEntityControls.cpp:2600 | #749/#751 (all keys read) | 014/015 | satisfied in new 009 (upstream `|`); 014's conversion must keep it | 014 |  |
| 38 | C/Entities/PlayerEntityControls.cpp:2645 | #749/#751 (all keys read) | 014/014 | satisfied in new 009 (upstream `|`); 014's conversion must keep it | 014 |  |
| 39 | C/Entities/PlayerEntityControls.cpp:4443 | #749/#751 (all keys read) | 014/014 | satisfied in new 009 (upstream `|`); 014's conversion must keep it | 014 |  |
| 40 | C/Entities/PlayerEntityControls.cpp:4488 | #749/#751 (all keys read) | 014/014 | satisfied in new 009 (upstream `|`); 014's conversion must keep it | 014 |  |
| 41 | C/Entities/PlayerEntityLoadSave.cpp:117 | #740 | 014,<=002/014 | satisfied: new 009 has no OO_USE_CUSTOM_LOAD_SAVE | 014 |  |
| 42 | C/Entities/PlayerEntityLoadSave.cpp:1229 | #740 | 014,<=002/014 | satisfied: new 009 has no OO_USE_CUSTOM_LOAD_SAVE | 014 |  |
| 43 | C/Entities/ShipEntity.cpp:13281 | #756 | 014/014 | not yet reached; code absent in new 003-009 | 014 |  |
| 44 | C/Entities/ShipEntity.h:473 | #756 | 012/012 | not yet reached; code absent in new 003-009 | 012 |  |
| 45 | C/Entities/ShipEntity.h:509 | #756 | 012/012 | not yet reached; code absent in new 003-009 | 012 |  |
| 46 | C/Entities/ShipEntity.h:916 | #756 | 012/012 | not yet reached; code absent in new 003-009 | 012 |  |
| 47 | C/Entities/ShipEntity.h:940 | #756 | 012/012 | not yet reached; code absent in new 003-009 | 012 |  |
| 48 | C/Entities/SkyEntity.h:53 | #756 | 010/010 | not yet reached; code absent in new 003-009 | 010 |  |
| 49 | C/GameController.cpp:26 | fork (include what you use) | 016/016 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 50 | C/GameController.cpp:41 | #756 | 007/016 | FOLLOW-UP: new 007 GameController.mm has `#ifndef NDEBUG` (console client import, console wait) | 007 |  |
| 51 | C/GameController.cpp:66 | #756 | 010/016 | not yet reached; code absent in new 003-009 | 010 |  |
| 52 | C/GameController.cpp:289 | #756 | 011/011 | not yet reached; code absent in new 003-009 | 011 |  |
| 53 | C/GameController.cpp:504 | #756 | 007/014 | FOLLOW-UP: new 007 GameController.mm has `#ifndef NDEBUG` (console client import, console wait) | 007 |  |
| 54 | C/GameController.h:61 | #737 (comment) | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 55 | C/GuiDisplayGen.cpp:43 | fork (include what you use) | 006,007/007 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 56 | C/Materials/OOBasicMaterial.cpp:32 | fork (include what you use) | 009,<=002/016 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 57 | C/Materials/OOBasicMaterial.h:79 | #756 | 009/015 | FOLLOW-UP: new 009 headers guard allTextures by NDEBUG, .mm definitions by OO_DEBUG_MONITOR_ENABLED (deployment build breaks) | 009 |  |
| 58 | C/Materials/OOConcreteTexture.h:34 | #748 (include order) | 010,016/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 59 | C/Materials/OOConcreteTexture.h:71 | #756 | 010/010 | not yet reached; code absent in new 003-009 | 010 |  |
| 60 | C/Materials/OOMaterialState.h:4 | #748 (include order) | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 61 | C/Materials/OOMultiTextureMaterial.h:61 | #756 | 009/015 | FOLLOW-UP: new 009 headers guard allTextures by NDEBUG, .mm definitions by OO_DEBUG_MONITOR_ENABLED (deployment build breaks) | 009 |  |
| 62 | C/Materials/OOPNGTextureLoader.cpp:26 | #748 (include order) | 016/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 63 | C/Materials/OOPNGTextureLoader.h:30 | #748 (include order) | 016/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 64 | C/Materials/OOPixMap.cpp:26 | fork (include what you use) | 006,016/016 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 65 | C/Materials/OOShaderMaterial.h:173 | #756 | 010/015 | not yet reached; code absent in new 003-009 | 010 |  |
| 66 | C/Materials/OOShaderUniformMethodType.cpp:51 | fork (include what you use) | 016/014 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 67 | C/Materials/OOSingleTextureMaterial.h:73 | #756 | 009/015 | FOLLOW-UP: new 009 headers guard allTextures by NDEBUG, .mm definitions by OO_DEBUG_MONITOR_ENABLED (deployment build breaks) | 009 |  |
| 68 | C/Materials/OOTexture.cpp:25 | #748 (include order) | 016/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 69 | C/Materials/OOTexture.cpp:101 | fork (comment) | 010/010 | not yet reached; code absent in new 003-009 | 010 |  |
| 70 | C/Materials/OOTexture.h:258 | #756 | 010/010 | not yet reached; code absent in new 003-009 | 010 |  |
| 71 | C/Materials/OOTextureLoader.cpp:25 | #748 (include order) | 016/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 72 | C/OOALSoundDecoder.cpp:29 | fork (include what you use) | 016/016 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 73 | C/OOAsyncWorkManager.cpp:30 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/015 | FOLLOW-UP (comment): code absent in new 003-009 | 004 |  |
| 74 | C/OOCPUInfo.cpp:25 | fork (include what you use) | 006,<=002/006 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 75 | C/OOCPUInfo.cpp:106 | fork (C++: gnu_inline) | <=002/<=002 | not yet reached; old form in new 003-009 | 017 |  |
| 76 | C/OOCacheManager.cpp:55 | fork (include what you use) | 007,<=002/007 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 77 | C/OODescription.h:69 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 008/008 | FOLLOW-UP (comment): old form in new 008-009 | 008 |  |
| 78 | C/OOFoundation.h:70 | #748 (keep winsock2 before windows.h under sorting; comment) | 009/009 | FOLLOW-UP (comment): new 009 OOFoundation.h has the bare blank line | 009 |  |
| 79 | C/OOFoundation.h:128 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 80 | C/OOIsNumberLiteral.h:32 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 009/009 | FOLLOW-UP (comment): old form in new 009-009 | 009 |  |
| 81 | C/OOJoystickManager.cpp:30 | fork (include what you use) | 007,<=002/015 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 82 | C/OOJoystickManager.h:142 | #742 | 003/003 | satisfied: new 003-009 have upstream's single STICK_DEADZONE (old 003 had reverted it) | n/a |  |
| 83 | C/OOLogOutputHandler.cpp:40 | fork (include what you use) | 005,007/007 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 84 | C/OOLogging.h:35 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 007/007 | FOLLOW-UP (comment): old form in new 007-009 | 007 |  |
| 85 | C/OOMaths.h:105 | #748 maths headers (fork variant) | <=002/<=002 | satisfied: new 003-009 have upstream's headers; superseded by end target 21c8c1df0 (OOMathsBase.h, test_OOMathsHeaders) which lands where the headers suite arrives (old 019) | drop |  |
| 86 | C/OOMatrix.h:24 | #748 maths headers (fork variant) | <=002/<=002 | satisfied: new 003-009 have upstream's headers; superseded by end target 21c8c1df0 (OOMathsBase.h, test_OOMathsHeaders) which lands where the headers suite arrives (old 019) | drop |  |
| 87 | C/OOMesh.cpp:58 | fork (include what you use) | 008,<=002/008 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 88 | C/OOMesh.cpp:1493 | #756 | 011/011 | not yet reached; code absent in new 003-009 | 011 |  |
| 89 | C/OOMesh.h:139 | #756 | 011/011 | not yet reached; code absent in new 003-009 | 011 |  |
| 90 | C/OOMesh.h:258 | #756 | 011/011 | not yet reached; code absent in new 003-009 | 011 |  |
| 91 | C/OOMeshToOctreeConverter.cpp:77 | fork (include what you use) | 007,<=002/007 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 92 | C/OOMouseInteractionMode.h:28 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 009/009 | FOLLOW-UP (comment): old form in new 009-009 | 009 |  |
| 93 | C/OOOpenGLStateManager.cpp:33 | fork (include what you use) | 007,<=002/007 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 94 | C/OOPlanetDrawable.h:77 | #756 | 014/014 | not yet reached; code absent in new 003-009 | 014 |  |
| 95 | C/OOPlanetDrawable.h:85 | #756 | 010/015 | not yet reached; code absent in new 003-009 | 010 |  |
| 96 | C/OOProfilingStopwatch.h:36 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 010/010 | not yet reached; code absent in new 003-009 | 010 |  |
| 97 | C/OOQuaternion.h:24 | #748 maths headers (fork variant) | <=002/<=002 | satisfied: new 003-009 have upstream's headers; superseded by end target 21c8c1df0 (OOMathsBase.h, test_OOMathsHeaders) which lands where the headers suite arrives (old 019) | drop |  |
| 98 | C/OOSkyDrawable.h:63 | #756 | 010/015 | not yet reached; code absent in new 003-009 | 010 |  |
| 99 | C/OOTriangle.h:24 | #748 maths headers (fork variant) | <=002/<=002 | satisfied: new 003-009 have upstream's headers; superseded by end target 21c8c1df0 (OOMathsBase.h, test_OOMathsHeaders) which lands where the headers suite arrives (old 019) | drop |  |
| 100 | C/OOTypeEncodings.h:1 | #749/#751 (clang-format off) + #756 | 016/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 101 | C/OOTypeEncodings.h:19 | #749/#751 (clang-format off) + #756 | 016/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 102 | C/OOTypes.h:33 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 010/010 | not yet reached; code absent in new 003-009 | 010 |  |
| 103 | C/OOVoxel.h:26 | #748 maths headers (fork variant) | <=002/<=002 | satisfied: new 003-009 have upstream's headers; superseded by end target 21c8c1df0 (OOMathsBase.h, test_OOMathsHeaders) which lands where the headers suite arrives (old 019) | drop |  |
| 104 | C/Octree.cpp:31 | fork (include what you use) | 007,<=002/007 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 105 | C/Scripting/OOConstToJSString.cpp:59 | fork (comment: OOAssert live) | <=002/<=002 | not yet reached; old form in new 003-009 | 010 |  |
| 106 | C/Scripting/OOJSCallEntityMethods.h:1 | #749/#751 (clang-format off) + #740 rows + #756 rows | 015/015 | not yet reached; code absent in new 003-009 | 015 |  |
| 107 | C/Scripting/OOJSCallEntityMethods.h:18 | #749/#751 (clang-format off) + #740 rows + #756 rows | 015,016/016 | not yet reached; code absent in new 003-009 | 015 |  |
| 108 | C/Scripting/OOJSEngineCore.h:63 | #756 | 010/010 | facade header (OOJSEngineCore.h); #768's OOJavaScriptEngine.h in new stack | n/a |  |
| 109 | C/Scripting/OOJSEngineCore.h:416 | #756 | 010/010 | facade header (OOJSEngineCore.h); #768's OOJavaScriptEngine.h in new stack | n/a |  |
| 110 | C/Scripting/OOJSEngineNativeWrappers.h:48 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 010/010 | not yet reached; code absent in new 003-009 | 010 |  |
| 111 | C/Scripting/OOJSGlobal.cpp:223 | #756 | 003/003 | facade property tables; new 009 OOJSGlobal.mm/OOJSOolite.mm are #768's, already OO_DEBUG_MONITOR_ENABLED | n/a |  |
| 112 | C/Scripting/OOJSOolite.cpp:160 | #756 | 003/003 | facade property tables; new 009 OOJSGlobal.mm/OOJSOolite.mm are #768's, already OO_DEBUG_MONITOR_ENABLED | n/a |  |
| 113 | C/Scripting/OOJSShipGroup.h:30 | fork (duplicate facade include) | 010,016/016 | facade include; new stack has #768's OOJSShipGroup.h | n/a |  |
| 114 | C/Scripting/OOJSSystem.cpp:388 | format | <=002/003 | facade-era blank line | n/a |  |
| 115 | C/Scripting/OOJavaScriptEngine.cpp:23 | fork (include what you use) | 016/016 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 116 | C/Universe.cpp:100 | #748 (include order) | 016,<=002/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 117 | C/Universe.cpp:125 | fork (deployment warning after 007's NDEBUG-guarded log calls) | 007/007 | FOLLOW-UP: new 007-009 Universe.mm has the guarded uses, unguarded constants | 007 |  |
| 118 | C/Universe.cpp:10847 | #756 | 013/013 | not yet reached; code absent in new 003-009 | 013 |  |
| 119 | C/Universe.h:252 | #756 | 013/013 | not yet reached; code absent in new 003-009 | 013 |  |
| 120 | C/legacy_random.c:217 | fork (deployment/GCC warnings on upstream code) | <=002/<=002 | not yet reached; old form in new 003-009 | 017 |  |
| 121 | C/legacy_random.c:232 | fork (deployment/GCC warnings on upstream code) | <=002/<=002 | not yet reached; old form in new 003-009 | 017 |  |
| 122 | src/SDL/EXRSnapshotSupport/OOSaveEXRSnapshot.cpp:1 | fork (include what you use) | <=002/<=002 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 123 | src/SDL/MyOpenGLView+Input.cpp:6 | #748 (include order) | 016/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 124 | src/SDL/MyOpenGLView.cpp:57 | #744 | 011,<=002/011 | satisfied: new 009 MyOpenGLView.mm has no dark-mode code | 011 |  |
| 125 | src/SDL/MyOpenGLView.cpp:932 | #744 | 011,015,<=002/015 | satisfied: new 009 MyOpenGLView.mm has no dark-mode code | 011 |  |
| 126 | src/SDL/MyOpenGLView.h:208 | #744 | 011/011 | satisfied: new 009 MyOpenGLView.mm has no dark-mode code | 011 |  |
| 127 | src/SDL/main.cpp:40 | fork (include what you use) | <=002/<=002 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 128 | src/SDL/main.cpp:163 | fork (deployment/GCC warnings on upstream code) | <=002/<=002 | not yet reached; old form in new 003-009 | 017 |  |
| 129 | oofnd/Data.hpp:36 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 130 | oofnd/Data.hpp:46 | fork (include what you use) | 004/004 | not needed by the Clang/Windows builds of new 003-009 (they pass) | 017 |  |
| 131 | oofnd/Date.hpp:30 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 005/005 | FOLLOW-UP (comment): old form in new 005-009 | 005 |  |
| 132 | oofnd/Defaults.hpp:43 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 133 | oofnd/Encoding.hpp:55 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 005/005 | FOLLOW-UP (comment): old form in new 005-009 | 005 |  |
| 134 | oofnd/Exception.hpp:44 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 016/016 | not yet reached; code absent in new 003-009 | 016 |  |
| 135 | oofnd/FileSystem.hpp:57 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 136 | oofnd/Http.hpp:43 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 007/007 | FOLLOW-UP (comment): old form in new 007-009 | 007 |  |
| 137 | oofnd/Log.hpp:32 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 005/005 | FOLLOW-UP (comment): old form in new 005-009 | 005 |  |
| 138 | oofnd/LogFile.hpp:37 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 007/007 | FOLLOW-UP (comment): old form in new 007-009 | 007 |  |
| 139 | oofnd/Notification.hpp:42 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 005/005 | FOLLOW-UP (comment): old form in new 005-009 | 005 |  |
| 140 | oofnd/PList.hpp:61 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 141 | oofnd/PListDescription.hpp:34 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 008/008 | FOLLOW-UP (comment): old form in new 008-009 | 008 |  |
| 142 | oofnd/PListGet.hpp:60 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 143 | oofnd/PListOldStyle.hpp:39 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 144 | oofnd/PListParsing.hpp:21 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 145 | oofnd/PListWriting.hpp:38 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 146 | oofnd/PListXML.hpp:37 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 147 | oofnd/Process.hpp:33 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 148 | oofnd/README.md:36 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 005/005 | FOLLOW-UP (comment): old form in new 005-009 | 005 |  |
| 149 | oofnd/README.md:55 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 150 | oofnd/README.md:264 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 005,010/016 | not yet reached; code absent in new 003-009 | 010 |  |
| 151 | oofnd/README.md:342 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 007/007 | FOLLOW-UP (comment): old form in new 007-009 | 007 |  |
| 152 | oofnd/README.md:439 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 006/006 | FOLLOW-UP (comment): old form in new 006-009 | 006 |  |
| 153 | oofnd/README.md:516 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 008/008 | FOLLOW-UP (comment): old form in new 008-009 | 008 |  |
| 154 | oofnd/README.md:533 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 008/008 | FOLLOW-UP (comment): old form in new 008-009 | 008 |  |
| 155 | oofnd/README.md:595 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 156 | oofnd/ResourcePaths.hpp:57 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 157 | oofnd/Scanner.hpp:50 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 007/007 | FOLLOW-UP (comment): old form in new 007-009 | 007 |  |
| 158 | oofnd/StdLib.hpp:2 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 005/005 | FOLLOW-UP (comment): old form in new 005-009 | 005 |  |
| 159 | oofnd/String.hpp:54 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 005/005 | FOLLOW-UP (comment): old form in new 005-009 | 005 |  |
| 160 | oofnd/Thread.hpp:40 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 161 | oofnd/meson.build:20 | fork (icu-uc for Linux shared link) | 007/007 | FOLLOW-UP: new 007-009 oofnd/meson.build names only icu-i18n | 007 |  |
| 162 | oofnd/objc/OOAssert.h:11 | fork (OOAssert live in every flavour, as Foundation's NSAssert was) | 007/007 | FOLLOW-UP: new 007 OOAssert.h blocks under NDEBUG; new 008 PlayerEntity deferredInit's side-effect OOAssert then skips in deployment | 007 | test_objc_assert_ndebug.cpp (176) at 007 |
| 163 | oofnd/objc/OOAssert.h:50 | fork (OOAssert live in every flavour, as Foundation's NSAssert was) | 007/016 | FOLLOW-UP: new 007 OOAssert.h blocks under NDEBUG; new 008 PlayerEntity deferredInit's side-effect OOAssert then skips in deployment | 007 | test_objc_assert_ndebug.cpp (176) at 007 |
| 164 | oofnd/objc/OOFoundationTypes.h:24 | #737 (OOCocoa.h -> OOFoundation.h in comments) | 004/004 | FOLLOW-UP (comment): old form in new 004-009 | 004 |  |
| 165 | tests/unit/core/meson.build:15 | #369 (test) | 016/016 | test written on the facade; in the new stack on QuickJS-ng's API (FR-015 ledger) | 009 | test_OoliteEquipmentControlScript (new) at 009 |
| 166 | tests/unit/core/test_MyOpenGLView.cpp:235 | #744 (test line) | 015/015 | test change: new 011's test_MyOpenGLView must not call isDarkModeOn (ledger row) | 011 |  |
| 167 | tests/unit/core/test_OOJSShipGroup.cpp:249 | fork (unused test variable) | 010/010 | facade test; new stack's test is on #768's API (ledger) | 010 |  |
| 168 | tests/unit/core/test_OOJSShipGroup.cpp:303 | fork (unused test variable) | 010/016 | facade test; new stack's test is on #768's API (ledger) | 010 |  |
| 169 | tests/unit/core/test_OOOXZManager.cpp:1785 | #747 (test) | 011/015 | src satisfied: new 009 OOOXZManager.mm has #747 | 011 | test_OOOXZManager copyUrlKey at 011 |
| 170 | tests/unit/core/test_OoliteEquipmentControlScript.cpp:0 | #369 (test) | -/None | test written on the facade; in the new stack on QuickJS-ng's API (FR-015 ledger) | 009 | test_OoliteEquipmentControlScript (new) at 009 |
| 171 | tests/unit/core/test_PlayerEntity.cpp:42 | #740 (test) | 013/011 | code absent in new 003-009 | 014 | test_PlayerEntity lastsaveNameIsRememberedInTheDefaults at 014 |
| 172 | tests/unit/core/test_PlayerEntity.cpp:1683 | #740 (test) | 013/011 | code absent in new 003-009 | 014 | test_PlayerEntity lastsaveNameIsRememberedInTheDefaults at 014 |
| 173 | tests/unit/expander/test_string_expander.cpp:441 | #747 (test digest; Jon approved 2026-10-25) | 016/009 | test change: new 009's (unbuilt) expander test keeps the pre-#747 digests; ledger row | 009 |  |
| 174 | tests/unit/oofnd/meson.build:95 | fork (OOAssert live: deployment_unit_tests, test_objc_assert skipped under NDEBUG) | 007,016/016 | FOLLOW-UP (with 162/163) | 007 |  |
| 175 | tests/unit/oofnd/meson.build:103 | fork (OOAssert live: deployment_unit_tests, test_objc_assert skipped under NDEBUG) | 004/004 | FOLLOW-UP (with 162/163) | 007 |  |
| 176 | tests/unit/oofnd/test_objc_assert_ndebug.cpp:0 | fork (test) | -/None | new test | 007 | adds test_objc_assert_ndebug at 007 |
| # | file:line (022) | upstream PR / kind | blame/form-from | new stack 003-009 | target | test |
|---|---|---|---|---|---|---|
| 0 | .gitattributes:1 | fork (InfoPlist.strings as UTF-8) | <=002/<=002 | old form in new 003-009 | tail |  |
| 1 | .github/workflows/build-all.yaml:173 | fork (macOS CI jobs / README, macOS deferred) | 003,<=002/003 | new 003-009 keep #768's macOS CI (consistent); drop where the macOS build must break | 016 |  |
| 2 | .github/workflows/build-all.yaml:240 | fork (macOS CI jobs / README, macOS deferred) | <=002/<=002 | new 003-009 keep #768's macOS CI (consistent); drop where the macOS build must break | 016 |  |
| 3 | .github/workflows/build-all.yaml:291 | fork (macOS CI jobs / README, macOS deferred) | <=002/<=002 | new 003-009 keep #768's macOS CI (consistent); drop where the macOS build must break | 016 |  |
| 4 | .github/workflows/test_builds.yaml:191 | fork (macOS CI jobs / README, macOS deferred) | 003,<=002/003 | new 003-009 keep #768's macOS CI (consistent); drop where the macOS build must break | 016 |  |
| 5 | DebugOXP/Debug.oxp/manifest.plist:2 | fork (version 1.95) | <=002/<=002 | upstream is 1.93 at 7437f22a5 | tail |  |
| 6 | README.md:198 | fork (macOS CI jobs / README, macOS deferred) | 003,<=002/003 | new 003-009 keep #768's macOS CI (consistent); drop where the macOS build must break | 016 |  |
| 7 | README.md:245 | fork (macOS CI jobs / README, macOS deferred) | <=002/<=002 | new 003-009 keep #768's macOS CI (consistent); drop where the macOS build must break | 016 |  |
| 8 | Resources/Info-gnustep.plist:80 | fork (version 1.95) | <=002/<=002 | upstream is 1.93 at 7437f22a5 | tail |  |
| 9 | Resources/InfoPlist.strings:1 | fork (InfoPlist.strings as UTF-8) | <=002/<=002 | old form in new 003-009 | tail |  |
| 10 | ShellScripts/common/post_build.sh:52 | undo of 018 hunk 3 | 018/018 | net zero with 018 hunk 3 | drop |  |
| 11 | ShellScripts/common/post_build.sh:155 | fork (Info-gnustep.plist kept) | <=002/<=002 | old form in new 003-009 | tail |  |
| 12 | ShellScripts/macOS/build_mozilla_js.sh:1 | SpiderMonkey macOS script/patch (rule 6) | 003/003 | already absent in new stack (#768) | n/a |  |
| 13 | ShellScripts/macOS/create_app_bundle_fn.sh:51 | fork (macOS build without Foundation/SpiderMonkey; ICU) | <=002/<=002 | dormant macOS build files; new stack keeps #768's | tail |  |
| 14 | ShellScripts/macOS/create_app_bundle_fn.sh:59 | fork (macOS build without Foundation/SpiderMonkey; ICU) | <=002/<=002 | dormant macOS build files; new stack keeps #768's | tail |  |
| 15 | ShellScripts/macOS/install_packages.sh:13 | fork (macOS build without Foundation/SpiderMonkey; ICU) | 003/003 | dormant macOS build files; new stack keeps #768's | tail |  |
| 16 | ShellScripts/macOS/mozilla_js_arm64.patch:1 | SpiderMonkey macOS script/patch (rule 6) | 003/003 | already absent in new stack (#768) | n/a |  |
| 17 | darwin.ini:1 | fork (macOS build without Foundation/SpiderMonkey; ICU) | <=002/<=002 | dormant macOS build files; new stack keeps #768's | tail |  |
| 18 | meson.build:1 | fork (020's comments/includes) | 020/020 | code absent in new 003-009 | 020 |  |
| 41 | C/Debug/OODebuggerInterface.h:33 | fork (020's comments/includes) | <=002/020 | code absent in new 003-009 | 020 |  |
| 42 | C/Entities/EntityVirtualMembers.h:56 | fork (VirtualMembers macros: clang-format off, includes) | 015,020/020 | code absent in new 003-009 | 015 |  |
| 48 | C/Entities/PlayerEntity.cpp:11444 | fork (PRIu64 for uint64 on macOS) | 020/020 | portability | 017 |  |
| 49 | C/Entities/PlayerEntityContracts.cpp:23 | fork (include order / layout) | 016/016 | format-like | 024 |  |
| 50 | C/Entities/PlayerEntityContracts.cpp:41 | fork (include order / layout) | 007,<=002/016 | format-like | 024 |  |
| 79 | C/Entities/PlayerEntityContracts.cpp:1048 | fork (include order / layout) | 008,014/014 | format-like | 024 |  |
| 125 | C/Entities/PlayerEntityKeyMapper.cpp:151 | #766 (OOLITE_MAC_COCOA_UI) | 007/007 | FOLLOW-UP: new 007-009 PlayerEntityKeyMapper.mm KeyMappingsFileName uses OOLITE_MAC_OS_X | 007 |  |
| 196 | C/Entities/ShipEntity.h:608 | fork (020's comments/includes) | 020/020 | code absent in new 003-009 | 020 |  |
| 197 | C/Entities/ShipEntity.h:794 | fork (020's comments/includes) | 020/020 | code absent in new 003-009 | 020 |  |
| 198 | C/GameController.cpp:63 | #766 (OOLITE_MAC_COCOA_UI) | 010/020 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 199 | C/GameController.cpp:81 | #766 (OOLITE_MAC_COCOA_UI) | 012/020 | satisfied: new 009 has upstream's | 012 |  |
| 200 | C/GameController.cpp:275 | #766 (OOLITE_MAC_COCOA_UI) | 010/010 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 201 | C/GameController.cpp:419 | #766 (OOLITE_MAC_COCOA_UI) | 020/020 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 202 | C/GameController.cpp:609 | #766 (OOLITE_MAC_COCOA_UI) | 012/010 | satisfied: new 009 has upstream's | 012 |  |
| 203 | C/GameController.cpp:665 | #766 (OOLITE_MAC_COCOA_UI) | 012/016 | satisfied: new 009 has upstream's | 012 |  |
| 204 | C/GameController.cpp:692 | #766 (OOLITE_MAC_COCOA_UI) | 012/012 | satisfied: new 009 has upstream's | 012 |  |
| 205 | C/GameController.cpp:717 | #766 (OOLITE_MAC_COCOA_UI) | 010/020 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 206 | C/GameController.cpp:726 | #766 (OOLITE_MAC_COCOA_UI) | 010/010 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 207 | C/GameController.cpp:737 | #766 (OOLITE_MAC_COCOA_UI) | 020/020 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 208 | C/GameController.cpp:784 | #766 (OOLITE_MAC_COCOA_UI) | 010/010 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 209 | C/GameController.cpp:822 | #766 (OOLITE_MAC_COCOA_UI) | 010/010 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 210 | C/GameController.cpp:911 | #766 (OOLITE_MAC_COCOA_UI) | 010/020 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 211 | C/GameController.cpp:923 | #766 (OOLITE_MAC_COCOA_UI) | 010/020 | satisfied: new 009 GameController.mm has upstream's | 010 |  |
| 212 | C/GameController.h:40 | #766 (OOLITE_MAC_COCOA_UI) | 012/020 | satisfied: new 009 has upstream's | 012 |  |
| 213 | C/GameController.h:101 | #766 (OOLITE_MAC_COCOA_UI) | 012/020 | satisfied: new 009 has upstream's | 012 |  |
| 214 | C/GameController.h:171 | #766 (OOLITE_MAC_COCOA_UI) | 012/020 | satisfied: new 009 has upstream's | 012 |  |
| 215 | C/GameController.h:238 | #766 (OOLITE_MAC_COCOA_UI) | 012/020 | satisfied: new 009 has upstream's | 012 |  |
| 216 | C/Materials/OOConcreteTexture.h:30 | fork (020's comments/includes) | 010,<=002/020 | code absent in new 003-009 | 020 |  |
| 217 | C/Materials/OOPlanetTextureGenerator.cpp:30 | fork (include order / layout) | 016,017,<=002/017 | format-like | 024 |  |
| 218 | C/Materials/OOPlanetTextureGenerator.cpp:62 | fork (include order / layout) | <=002/<=002 | format-like | 024 |  |
| 253 | C/Materials/OOPlanetTextureGenerator.cpp:865 | fork (include order / layout) | <=002/<=002 | format-like | 024 |  |
| 267 | C/Materials/OOShaderProgram.cpp:29 | #766 (GLSL 330->120 translator, macOS) | 016,<=002/016 | satisfied: new 009 OOShaderProgram.mm has upstream's translator; old 010 dropped it | 010 | test_OOShaderProgram cases (603/604) at 010 |
| 274 | C/Materials/OOShaderProgram.cpp:164 | #766 (GLSL 330->120 translator, macOS) | 010/010 | satisfied: new 009 OOShaderProgram.mm has upstream's translator; old 010 dropped it | 010 | test_OOShaderProgram cases (603/604) at 010 |
| 287 | C/Materials/OOShaderProgram.cpp:555 | #766 (GLSL 330->120 translator, macOS) | <=002/006 | satisfied: new 009 OOShaderProgram.mm has upstream's translator; old 010 dropped it | 010 | test_OOShaderProgram cases (603/604) at 010 |
| 290 | C/Materials/OOShaderProgram.h:94 | #766 (GLSL 330->120 translator, macOS) | 010,<=002/014 | satisfied: new 009 OOShaderProgram.mm has upstream's translator; old 010 dropped it | 010 | test_OOShaderProgram cases (603/604) at 010 |
| 291 | C/Materials/OOStandaloneAtmosphereGenerator.cpp:30 | fork (include order / layout) | 016,<=002/017 | format-like | 024 |  |
| 292 | C/Materials/OOStandaloneAtmosphereGenerator.cpp:60 | fork (include order / layout) | 007,<=002/022 | format-like | 024 |  |
| 313 | C/Materials/OOStandaloneAtmosphereGenerator.cpp:533 | fork (include order / layout) | <=002/<=002 | format-like | 024 |  |
| 381 | C/OOCPUInfo.cpp:23 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | 018,<=002/018 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 388 | C/OOCharacter.cpp:47 | fork (PRIu64 for uint64 on macOS) | 009/009 | portability | 017 |  |
| 413 | C/OOFoundation.h:30 | fork (OOFoundation.h include order / <inttypes.h>) | <=002/009 | old form in new 009-009 | 022 |  |
| 414 | C/OOFoundation.h:60 | fork (OOFoundation.h include order / <inttypes.h>) | 020/022 | code absent in new 003-009 | 022 |  |
| 415 | C/OOFoundation.h:76 | fork (OOFoundation.h include order / <inttypes.h>) | <=002/022 | code absent in new 003-009 | 022 |  |
| 416 | C/OOFoundation.h:127 | fork (OOLITE_MACOS: macOS without Foundation) | <=002/<=002 | first needed by 010's macOS translator; dormant | 010 |  |
| 417 | C/OOFullScreenController.h:56 | #766 (macro name in comment) | 020/020 | FOLLOW-UP (comment): new 009 OOFullScreenController.h says OOLITE_MAC_OS_X | 009 |  |
| 418 | C/OOJoystickProfile.h:37 | fork (020's comments/includes) | <=002/020 | code absent in new 003-009 | 020 |  |
| 420 | C/OOLogHeader.cpp:79 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | <=002/<=002 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 421 | C/OOLogHeader.cpp:151 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | 006,<=002/006 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 424 | C/OOLogHeader.cpp:191 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | <=002/006 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 425 | C/OOLogHeader.cpp:201 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | <=002/<=002 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 426 | C/OOLogHeader.cpp:218 | fork (macOS/C++ printf widths, alloca cast) | 006/006 | dormant (Mac blocks) / C++ cast | 016 |  |
| 427 | C/OOLogHeader.cpp:307 | fork (macOS/C++ printf widths, alloca cast) | 006/006 | dormant (Mac blocks) / C++ cast | 016 |  |
| 428 | C/OOLogHeader.cpp:329 | fork (macOS/C++ printf widths, alloca cast) | <=002/006 | dormant (Mac blocks) / C++ cast | 016 |  |
| 429 | C/OOLogHeader.cpp:364 | fork (macOS/C++ printf widths, alloca cast) | 006/006 | dormant (Mac blocks) / C++ cast | 016 |  |
| 439 | C/OOOpenGLExtensionManager.cpp:236 | #766 (2.1 legacy context check, macOS) | 020,<=002/020 | satisfied: new 009 .mm has upstream's | 016 |  |
| 440 | C/OOOpenGLOnly.h:25 | #748/#766 OOOpenGLOnly.h (fork variant) | <=002/<=002 | satisfied: new 003-009 have upstream's; superseded by end target 8fb30e6ee | drop |  |
| 441 | C/OOOpenGLOnly.h:65 | #748/#766 OOOpenGLOnly.h (fork variant) | <=002/<=002 | satisfied: new 003-009 have upstream's; superseded by end target 8fb30e6ee | drop |  |
| 452 | C/OOPlanetDrawable.cpp:363 | fork (include order / layout) | 015,<=002/015 | format-like | 024 |  |
| 454 | C/OOSystemDescriptionManager.cpp:39 | fork (include order / layout) | 006/006 | format-like | 024 |  |
| 457 | C/OOSystemDescriptionManager.cpp:86 | fork (include order / layout) | 005/014 | format-like | 024 |  |
| 517 | C/Scripting/OOJSEntity.h:24 | fork (020's comments/includes) | <=002/016 | code absent in new 003-009 | 020 |  |
| 527 | C/Scripting/OOScript.h:44 | fork (020's comments/includes) | 010,016/020 | code absent in new 003-009 | 020 |  |
| 528 | C/Scripting/OOScript.h:51 | fork (020's comments/includes) | 006,010,014,<=002/020 | code absent in new 003-009 | 020 |  |
| 552 | C/Universe.cpp:365 | #766 (OOLITE_MAC_COCOA_UI) | 012/020 | satisfied: new 009 has upstream's | 012 |  |
| 553 | C/Universe.cpp:516 | #766 (OOLITE_MAC_COCOA_UI) | 012/012 | satisfied: new 009 has upstream's | 012 |  |
| 554 | C/Universe.cpp:11551 | #766 (MSAA renderbuffer, macOS) | 013/013 | satisfied: new 009 Universe.mm has upstream's; old 013 dropped it | 013 |  |
| 555 | C/Universe.cpp:11559 | #766 (MSAA renderbuffer, macOS) | 020,<=002/020 | satisfied: new 009 Universe.mm has upstream's; old 013 dropped it | 013 |  |
| 556 | C/Universe.cpp:11744 | #766 (MSAA renderbuffer, macOS) | 013,<=002/013 | satisfied: new 009 Universe.mm has upstream's; old 013 dropped it | 013 |  |
| 557 | C/Universe.cpp:11766 | #766 (MSAA renderbuffer, macOS) | 013/020 | satisfied: new 009 Universe.mm has upstream's; old 013 dropped it | 013 |  |
| 558 | C/UniverseVirtualMembers.h:33 | fork (VirtualMembers macros: clang-format off, includes) | 015,016/020 | code absent in new 003-009 | 015 |  |
| 559 | C/UniverseVirtualMembers.h:41 | fork (VirtualMembers macros: clang-format off, includes) | 015/016 | code absent in new 003-009 | 015 |  |
| 560 | C/UniverseVirtualMembers.h:56 | fork (VirtualMembers macros: clang-format off, includes) | 015,020/020 | code absent in new 003-009 | 015 |  |
| 580 | src/SDL/MyOpenGLView.cpp:45 | fork (020's comments/includes) | 016/020 | code absent in new 003-009 | 020 |  |
| 581 | src/SDL/MyOpenGLView.cpp:251 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | <=002/020 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 582 | src/SDL/MyOpenGLView.cpp:288 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | <=002/020 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 583 | src/SDL/MyOpenGLView.cpp:323 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | <=002/020 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 584 | src/SDL/MyOpenGLView.cpp:355 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | <=002/<=002 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 585 | src/SDL/MyOpenGLView.cpp:525 | #774 line (BOOL->bool) | <=002/<=002 | upstream line; type follows the C++ conversion | 011 |  |
| 586 | src/SDL/MyOpenGLView.cpp:546 | fork (comment) | 020/020 | code absent in new 003-009 | 020 |  |
| 587 | src/SDL/MyOpenGLView.cpp:1238 | #766 (front-buffer snapshot, no window surface, macOS) | 011/011 | satisfied: new 009 MyOpenGLView.mm has upstream's; old 011 dropped it | 011 |  |
| 588 | src/SDL/MyOpenGLView.cpp:1295 | #766 (front-buffer snapshot, no window surface, macOS) | 011/020 | satisfied: new 009 MyOpenGLView.mm has upstream's; old 011 dropped it | 011 |  |
| 589 | src/SDL/MyOpenGLView.cpp:1367 | #766 (front-buffer snapshot, no window surface, macOS) | 011/011 | satisfied: new 009 MyOpenGLView.mm has upstream's; old 011 dropped it | 011 |  |
| 591 | src/SDL/MyOpenGLView.h:365 | #774 (no splash window member) | 011/011 | satisfied: new 009 has upstream's #774 | 011 |  |
| 592 | src/SDL/main.cpp:50 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | <=002/<=002 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 593 | src/SDL/main.cpp:68 | fork (STRINGIFY, was from GNUstep) | <=002/<=002 | new 009 already defines both forms (ON) | 009 |  |
| 594 | src/SDL/main.cpp:172 | fork (OOLITE_MAC_OS_X->OOLITE_MACOS on upstream code) | <=002/018 | new 009 has upstream's OOLITE_MAC_OS_X (correct while Foundation/ObjC remain); dormant | 016 |  |
| 595 | src/SDL/main.cpp:184 | fork (unchecked chdir in #766's Mac branch) | <=002/<=002 | warning fix on upstream code | 017 |  |
| 596 | src/meson/darwin/meson.build:1 | fork (macOS build without Foundation/SpiderMonkey; ICU) | 003,<=002/003 | dormant macOS build files; new stack keeps #768's | tail |  |
| 597 | tests/component/console.py:104 | #766-related test harness (macOS bundle) | <=002/<=002 | new 009 has upstream's #766 harness lines; these are fork's macOS additions | tail |  |
| 598 | tests/component/console.py:122 | #766-related test harness (macOS bundle) | <=002/<=002 | new 009 has upstream's #766 harness lines; these are fork's macOS additions | tail |  |
| 599 | tests/launch_snapshot.py:368 | #766-related test harness (macOS bundle) | <=002/<=002 | new 009 has upstream's #766 harness lines; these are fork's macOS additions | tail |  |
| 600 | tests/launch_snapshot.py:385 | #766-related test harness (macOS bundle) | <=002/<=002 | new 009 has upstream's #766 harness lines; these are fork's macOS additions | tail |  |
| 601 | tests/launch_snapshot.py:475 | #766-related test harness (macOS bundle) | <=002/<=002 | new 009 has upstream's #766 harness lines; these are fork's macOS additions | tail |  |
| 602 | tests/launch_snapshot.py:1289 | #766-related test harness (macOS bundle) | <=002/<=002 | new 009 has upstream's #766 harness lines; these are fork's macOS additions | tail |  |
| 603 | tests/unit/core/test_OOShaderProgram.cpp:14 | #766 (test) | 010/020 | new test cases | 010 | test_OOShaderProgram at 010 |
| 604 | tests/unit/core/test_OOShaderProgram.cpp:316 | #766 (test) | 010/010 | new test cases | 010 | test_OOShaderProgram at 010 |

Formatting-only hunks (whitespace, line and comment wrapping, include order), no placement: step 024's clang-format decides the layout.

- `src/Core/CollisionRegion.cpp`: 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40
- `src/Core/Entities/OOFlasherEntity.cpp`: 43, 44, 45, 46, 47
- `src/Core/Entities/PlayerEntityContracts.cpp`: 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117
- `src/Core/Entities/PlayerEntityKeyMapper.cpp`: 118, 119, 120, 121, 122, 123, 124, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195
- `src/Core/Materials/OOPlanetTextureGenerator.cpp`: 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266
- `src/Core/Materials/OOShaderProgram.cpp`: 268, 269, 270, 271, 272, 273, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286
- `src/Core/Materials/OOShaderProgram.h`: 288, 289
- `src/Core/Materials/OOStandaloneAtmosphereGenerator.cpp`: 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 314, 315, 316, 317, 318, 319, 320
- `src/Core/MiniZip/unzip.cpp`: 321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360, 361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 379, 380
- `src/Core/OOCPUInfo.cpp`: 382, 383, 384, 385
- `src/Core/OOCharacter.cpp`: 386, 387, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399, 400, 401, 402
- `src/Core/OODataFromOXZFile.cpp`: 403, 404, 405, 406, 407, 408, 409, 410, 411, 412
- `src/Core/OOLogHeader.cpp`: 419, 422, 423
- `src/Core/OOOpenGL.h`: 430, 431, 432, 433, 434, 435, 436, 437, 438
- `src/Core/OOPlanetDrawable.cpp`: 442, 443, 444, 445, 446, 447, 448, 449, 450, 451
- `src/Core/OOSystemDescriptionManager.cpp`: 453, 455, 456, 458, 459, 460, 461, 462, 463, 464, 465, 466, 467, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477, 478, 479
- `src/Core/OXPVerifier/OOFileScannerVerifierStage.h`: 480, 481, 482
- `src/Core/Scripting/OOJSEngineTimeManagement.cpp`: 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 511, 512, 513, 514, 515, 516
- `src/Core/Scripting/OOJSEntity.h`: 518, 519, 520, 521
- `src/Core/Scripting/OOJSSound.h`: 522, 523, 524
- `src/Core/Scripting/OOJSWaypoint.h`: 525, 526
- `src/Core/Scripting/OOScript.h`: 529, 530
- `src/Core/Scripting/ooscript/JSEngine.hpp`: 531, 532, 533, 534, 535, 536, 537, 538, 539, 540, 541, 542, 543, 544, 545, 546, 547, 548, 549, 550, 551
- `src/SDL/MyOpenGLView+Input.cpp`: 561, 562, 563, 564, 565, 566, 567, 568, 569, 570, 571, 572, 573, 574, 575, 576, 577, 578, 579
- `src/SDL/MyOpenGLView.h`: 590
