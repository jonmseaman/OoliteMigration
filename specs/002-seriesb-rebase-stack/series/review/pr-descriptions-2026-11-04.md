# Review of series/pr/*.md for the rebuilt (no-façade) seriesb stack, 2026-11-04

Step numbers have shifted. The prose in 004–024 still uses the OLD master-series numbers: old N = new N−2 for N≥6 (old 6 = new 4,
old 26 = new 24). The commands also use the old branches `series/0NN-…`, which reviewers do not have.

## Per description

### 001-random-seed-env: KEEP AS IS
(1) Nothing stale. The Verified table says "6 inherited from the parent"; the (gen) rerun will set the new figure.

### 002-safety-net: LIGHT EDIT
(1) Nothing about the façade.
(2) False: "On the game side the step adds an `OO_RANDOM_SEED` environment variable". Step 001 adds it; 001..002 only adds the shuffle
    hook to GameController.m. The first Behaviour-changes bullet repeats the claim. Also stale: "Despite the title, no goldens or JS API
    snapshot files are added here", but the title does not mention goldens. Two behaviour changes have no pinning test: `-ffp-contract=off`
    and the writable `ship.speed` ("No test in this step exercises it"). The text admits this honestly, but they are still unpinned: add a
    test or flag them for Jon. Cut the mentions of `tools/gui-lock`, `tests/golden/` and "design documents" that are not in the tree.

### 003-objcpp-switch: REWRITE (every hand section is wrong)
(1) It describes the façade throughout:
    - What this changes: "replaces the scripting layer … with the fork's own: `src/Core/Scripting/ooscript/JSEngine.hpp`" and
      "#768's proof-of-concept tree (`poc/`), `oolite-quickjs-compat.js` and its QuickJS-ng patch are removed". All three are kept: the
      patch is in the wrap, and `poc/` is renamed to .mm. Also false: "squashes three steps … (the façade, Objective-C++, and the engine switch)".
    - Why: "Putting the façade back here … Step 25 then moves the finished C++ game onto #768's binding".
    - Behaviour changes: "the differences are the ones step 25 reverses … `[object Vector3D]`-style tags". This should be "None" against 002.
    - How to review: `ooscript/README.md`, `JSEngine_quickjs.cpp` and `git grep … ':!src/Core/Scripting/ooscript'` refer to files that do not
      exist, and the command uses the old branch `seriesb/003-quickjs-switch`.
    - "207 renames": actually 247 R + 37 M = 284 files, +1672/−1304.
    - The rewrite should say: .m→.mm; the 729 hunks Objective-C++ needs, made on upstream's code; `this`→`thisObj` in #768's code;
      the `poc/meson.build` change; nothing reverts #742/#748/#749/#780.
(2) The Differences (gen) rows cite "spec D1", "research R5" and "the end tree is develop". These are bookkeeping ids, and the claim is false.
    Verified (gen) says "0 warnings"; there are now 7, inherited from the parent.

### 004-oofnd-core: LIGHT EDIT
(1) False: "This step comes after the engine switch so that the JavaScript layer underneath is already final". There is no engine switch.
    Wrong number: "bulk adoption comes in steps 7 to 9" should be 5 to 7. Not stated anywhere: the façade-only work (watchdog,
    MOZ_TRACE, dumpNamedRoots) was dropped, and the Foundation changes were redone on #768's code. The Differences section should say so.

### 005-typed-accessors: LIGHT EDIT
(1) Wrong numbers: "OOObject from step 6" (should be 4), "They come after step 6" (4), "bulk Foundation steps (7 and 8)" (6 and 7),
    "The step-1 tiers" (2). The review command `series/007-typed-accessors^ series/007-typed-accessors` should be
    `seriesb/004-oofnd-core seriesb/005-typed-accessors`. Not stated: the step now also posts the reset notification from `-shutDown`
    on `oo::NotificationCenter`; without it OOJSValue/OOJSTimer leaked.

### 006-foundation-wave-1: LIGHT EDIT
(1) Wrong numbers: "added in step 6" (4), "steps 9 and 10 delete them" (7 and 8), "(steps 11–15)" (9–13), "right after step 7" (5).
    False under the no-revert rule: "upstream's `builtInPath` under `OOLITE_MAC_COCOA_UI` (#766) is not in this step … Step 25 restores it".
    `builtInPath` is present at 006 (9 files), so say it is kept, or drop the bullet. Not stated: the auto-merge silently deleted #768 code,
    and those files were rebuilt (belongs in Differences).
(2) Recheck "adds 25 of these bridges" on the rebuilt tree.

### 007-foundation-wave-2: LIGHT EDIT
(1) Wrong numbers: "step 8's recipe" ×2 (6), "Step 10 can only delete" (8), "deleted in step 10" (8).
    False: "The fix is a patch on the wrap's `meson.build` (`subprojects/packagefiles/quickjs-ng-o2.patch`)". The rebuilt step sets
    `buildtype=debugoptimized`, `optimization=2` and `b_ndebug=true` in the `default_options` of #768's `dependency('quickjs-ng')`
    (src/meson/meson.build); no patch file exists. Not stated: the Windows `threads` override, which takes the warnings from 7 to 4 from
    this step on, and `quitGame()` through `OOScheduleDeferredCall`.
(2) The sysdesc and expander tests are "not registered in meson", so the behaviour they "pin" is in practice unpinned. Say so plainly.
    Aside (in the code, not the description): the comment on the winhttp line says "(proposed ADR-0044)".

### 008-selector-families: LIGHT EDIT
(1) Wrong numbers: "Steps 8 and 9 left these" (6 and 7), "(steps 8–9)" (6–7), "removed in step 11's first part" (9). Not stated: the
    11 bridges that #768's code still used, and moving the script cache, class registry and console syntax check off them.
(2) "Most of the 397 files": the step now changes 398.

### 009-leaf-conversions: LIGHT EDIT (larger)
(1) Wrong numbers: "steps 8–10 prepared" (6–8), "steps 12–15 follow" (10–13), "(from step 6)" (4). "36 of them here" is now 34
    `+ObjCBridge` pairs, because ee0a23aca deleted two. Missing from the description:
    - Behaviour change in OO_DEBUG builds: the Vector3D/Quaternion statistics are removed, as #768 did (`reportJSVectorStatistics` is
      gone; the cases are in the ledger).
    - The harness (`poc/`) is off GNUstep and builds and runs on Windows, with `primitive_property.js` (23/23).
    - The `OOProfilingStopwatch` signed-difference fix and its test.
    - `OOSDLJoystickManager` on #742's layout.
    - The 13 ledgered test changes.
(2) "Objective-C facade", meaning `+ObjCBridge`, will now read as the removed scripting façade. Say "bridge" throughout 009–016.
    The `\x7F` expander change is pinned only by an unregistered test.

### 010-module-conversions: LIGHT EDIT
(1) Wrong numbers: "house style of step 11", plus three more "step 11" (9); "steps 13–15" (11–13). False under the no-revert rule:
    "#766 … Cocoa-UI branches … are not in this step … Step 25 restores them". They must be kept. The JS bindings now convert #768's
    files, so the exemplar notes should name #768's patterns.

### 011-first-slices: LIGHT EDIT
(1) Wrong numbers: "in step 14" (12), "steps 11–12" ×2 (9–10), "steps 14–15" (12–13), "step 11's classes" (9). Two false claims:
    "#774 … is not in this step … Step 25 ports #774", and "#766 front-buffer screenshot … Step 25 restores it". Both must be kept.
    Recheck the note on the rename-detection pairing. The #747 copy-URL paragraph contradicts 018, which claims to port #747.

### 012-shipentity-slices: LIGHT EDIT
(1) "steps 16 and 17 delete them" (14 and 15). The command uses the old `series/013-first-slices series/014-shipentity-slices`.

### 013-universe-player-slices: LIGHT EDIT
(1) Wrong numbers: "shell came in step 14" (12), "wait for step 14" (12), "follow in step 16" (14). The commands use `series/014…`
    and `series/015…`. Doubtful: "adds `OOJSPrivateObject`". #768 already has it (kept, reduced), so recheck what this step adds.

### 014-facade-deletions: LIGHT EDIT
(1) Wrong numbers: "goes in step 18" (16), "waits for step 17" (15), "as in step 14" (12). The commands use `series/015…` and
    `series/016…`. Recheck the counts ("about sixty", "123 files", "about twenty-five remain").
(2) Apply the bridge/façade wording (title and text).

### 015-entity-facade: LIGHT EDIT
(1) Wrong numbers: "(steps 14 to 16)" (12–14), "step 18" (16), "same pattern as step 16" (14). The commands use `series/016…` and `series/017…`.
(2) "The generator is not part of this tree": a 6,000-line generated table cannot be reproduced without it. Ship the generator or describe it.

### 016-objc-runtime-out: LIGHT EDIT
(1) "after steps 16 and 17" (14 and 15). The commands use `series/017…` and `series/018…`. Recheck "381 renames". Not stated: `poc/`,
    Objective-C++ since 003, must be converted and renamed here too.

### 017-gcc-build: REWRITE (title, What, Why)
(1) GCC is no longer required (Jon). These all overclaim: the title "Build with GCC as well as Clang", "The game and its unit tests now build
    with GCC", "To build with GCC: `./mk.sh build test --native-file=gcc.ini`", and "a GCC build now draws in that order too". The core
    tests fail to link under GCC LTO (`oo::EntityDescription`) even at the end target, and seriesb no longer verifies GCC. Also: "after step 18"
    ×2 should be 16, and the command uses `series/018…/019…`. Retitle, e.g. "Fix code that GCC warns about".
(2) Keep the random-draw-order part. It is the real content, and the unchanged tests pin it.

### 018-upstream-9ee8ff22f-port: REWRITE or DROP
(1) Under the rule that no step reverts `dc55e3e05..7437f22a5`, these ports now land in earlier steps. False claims:
    - "those steps took it as upstream wrote it (in places still Objective-C) and kept the migration's older `!NDEBUG` guards";
    - "#742's move of the joystick event decoders into `OOSDLJoystickManager` is not taken". It has been taken since 005;
    - "#766's macOS changes … come back, dormant, in step 25" and "#774 … also in step 25";
    - "after the code is C++ and builds with both compilers";
    - the #748 note. #748's maths headers now take upstream's form, with `OOMathsBase.h`.
    Only the fork's own riders can stay (OOAssert live in every build, unit-test flavours, ICU, packaging), and they overlap 019.
    The command uses `series/019…` and `series/020…`.
(2) The OOAssert behaviour change and `test_objc_assert_ndebug.cpp` appear in both 018 and 019. "a later step in the series removes it"
    (the AppImage) needs the step named.

### 019-develop-fixes: LIGHT EDIT
(1) False: "The maths family … takes the fork's form here … in place of the guard-free form upstream's #748 gave them". The end target
    uses upstream's form plus `OOMathsBase.h` and `test_OOMathsHeaders.cpp`. "the last step of the series relies on" should name step 24.
    The assertion fix is duplicated with 018; one step must own it.
(2) Cut "the gap between the squash and the history's last state". It is fork history that a reviewer cannot use.

### 020-source-hygiene: KEEP (light)
(1) Nothing is stale. The counts will move.

### 021-tests-and-tooling: LIGHT EDIT
(1) False: the delete-hook fix is said to be in "`JSEngine_quickjs.cpp`", pinned by "the delete test in `tests/unit/test_jsengine_quickjs.cpp`".
    Both are façade files that no longer exist. On #768 the fix is in the exotic delete hooks (MissionVariables, SystemInfo, console),
    and its test is in the moved suite.

### 022-c-as-cxx: LIGHT EDIT
(1) False: "QuickJS-ng 0.17.0 (was 0.16.2), with the patch for its void returns moved". #768's wrap is already v0.17.0 from 003, so there is
    no upgrade. Drop "upgrade QuickJS-ng" from the title. Check whether the void-return patch still exists, and state that the
    primitive-property patch is kept.

### 023-upstream-49a5eb9fc-ports: REWRITE (becomes the #783 port)
(1) #766, #774 and #781 are inside `dc55e3e05..7437f22a5`, so they are already in every step and this step does not port them. Also false:
    "The fork merged upstream `49a5eb9fc`, the base of this series". The base is #768's head. Missing:
    - #783 (joystick_gui);
    - the named deviation, `clearMappings` resetting `guibuttonmap`, with the suggestion that upstream take it, pinned by the #783 tests
      and `savesAndLoadsSettings`;
    - #742's SDL decode and `test_OOJoystickDecoding.cpp`, with the moved cases ledgered, if they land here.
    "upstream's SpiderMonkey build script for macOS and its patch go" is probably a no-op now.
(2) "The tests pass under the GL test context" is vague.

### 024-google-style-format: LIGHT EDIT
(1) "the series ends on the fork exactly": with 025 dropped, state what it ends on (`feature/upstream-quickjs-poc-cxx`, not develop).
    "88 files" will change.
(2) Mention clang-format 22 against the local 23 (wrapped enum initialisers); CI is the authority.

### 025-upstream-quickjs-binding: DROP (or rewrite to what remains)
(1) The whole description is the façade switch: "The fork's `ooscript` façade … is deleted", "The unit tests move from the façade",
    "steps 4 to 24 were built and tested on the façade". Also false: "Not applied: #768's QuickJS-ng patch". Jon took it (`fce807b50`).
    Its behaviour list moves elsewhere. Against #768 these are #768's own behaviour, but the fork's additions must be named where they
    land: the SystemInfo `has_property` hook, the two use-after-free fixes, the jump cause `""`, the console holding the monitor strongly,
    and the timeGetTime fix (009).
(2) Bookkeeping to remove: "(Jon, 2026-11-02)", "(spec FR-015)", "FR-015" in Verified, the `specs/002-…` path. Its "Switch:" line
    replaces "Replays:", which the contract does not allow.

## Cross-cutting
- Fix the step count in every Series line ("step N of 25"); 025, and maybe 018, go. Base and next are (gen), but the hand prose of
  004–024 has the old numbers listed above. Fix all of them in one pass.
- Every `series/0NN-…` command becomes `seriesb/<parent> seriesb/<step>` (005, 012–018).
- "Replays:" line: keep and regenerate. Its stats are the OLD step's (003: "30.6k src … 21.6k lines in deleted files" against an actual
  +1672/−1304). Say the step is re-expressed on #768's code. "Differences from the old step" should list the real re-expressions
  (façade-only code dropped, #768 hunks kept, mismerge repairs), not "None: the same change".
- "Based on:" line: keep it as it is; it is correct.
- The series tool writes the Differences reason text ("spec D1", "research R5", "the end tree is develop"). Fix it in the tool.
- Rerun all Verified (gen) sections. The inherited-warning baseline is 7 for 001–006 and 4 from 007. `build_gcc` should read
  "n/a: not required by the series". Add the `poc` harness check from 009 on.
- Say "bridge" for `X+ObjCBridge` everywhere.
- Steps that add or remove bridges (006–016) have no "Temporary code" (gen) section.
- Steps with ledgered test changes (007, 009, the #742 moves) should name their ledger rows, not just "the spec".

## upstream-review-issue.md
- "it builds with Clang and GCC": drop GCC.
- "25 stacked branches", "Each one is a single commit": both false. 009 has three commits (dbb0c371c, ee0a23aca, 1912db791), and the
  count changes once 025 and 018 go.
- Row 3: `003-quickjs-switch`, titled "Put the game's JavaScript behind an engine façade … replacing the PRs' binding", becomes
  `seriesb/003-objcpp-switch`, "Compile the game as Objective-C++, keeping #768's QuickJS-ng binding", 284 files +1672/−1304. Row 4's
  compare link also uses `003-quickjs-switch`.
- Rows 4–9: the stats are stale (004: 110 files +15533/−1069, not 111 +15674/−1205; 009: 489 files +37593/−11809). Regenerate them all.
- Notes: "Step 25 is built on top of it" and "Steps 18 and 23 port upstream changes (#369–#765, and #766/#774/#781)" are stale. Say
  instead that recent upstream PRs are kept in every step and #783 is ported in 023.
- "Mechanical steps (5, 20, 22, 24)": 005 adds new oofnd components, so it is not purely mechanical; recheck 022.
- The whole-stack link ends at `seriesb/025-…`.
- Keep "macOS and Linux have not been verified". Add that the harness runs on Windows from step 9.
