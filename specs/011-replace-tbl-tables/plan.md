# Implementation Plan: Replace the last `.tbl` table

**Branch**: commits on `seriesb/027-modern-cpp` (in `oolite-dev`, worktree `.agent-tmp/wt-tbl`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Delete `src/Core/Tables/OOOpenGLStates.tbl`. The state manager gets one `constexpr` table of its
30 state items, each built by a function template for its kind that takes the item's field and
functions. Read, compare, log and write loop over that table, and a `static_assert` checks it
field for field against the state record. A new test pins the verifier's log lines first.

## Technical Context

**Language/Version**: C++23 (`src/meson.build`). Clang (MSYS2 UCRT64, 23.1) and GCC 15.2
(`--native-file=gcc.ini`); clang-format 22.

**Testing**:
- `test_OOOpenGLStateManager`, unchanged.
- `test_OOOpenGLStateVerifier`, new, written and passing on the base first (research R3).
- `tests/run.sh unit`, `component`, `smoke`.
- `-Wall -Wextra` clean on Clang and GCC.

**Constraints**: no observable change; CLAUDE.md's hard rules; one source file changes.

**Scale/Scope**: 1 file deleted (59 lines), 1 file reworked, 1 test added.

## Constitution Check

`.specify/memory/constitution.md` is the blank template; the gates are CLAUDE.md's hard rules.

| Gate | Plan | Status |
|---|---|---|
| 1. No test changed to make it pass | None changed; one added | pass |
| 2. No warning silenced | None | pass |
| 3. Never touch `develop`/`master`/`main`/`upstream-master` | Commits on `seriesb/027-modern-cpp` (Jon, spec Notes 2) | pass |
| 4. No expansion content | None read | pass |
| 5. Tools judge | `static_assert`, the two tests, the suites, two compilers | pass |
| 6. No `libgnustep-base`/SpiderMonkey | Nothing added | pass |
| 7. No rewriting C | No C involved | pass |
| 9. No writes outside the repo | Worktree and scratch under `.agent-tmp/` | pass |
| 10. clang-format 22, never `tests/` | The `.cpp` only | pass |

## Order of work

1. The base builds and its unit suites pass; note its warnings for `OOOpenGLStateManager.cpp`.
2. `test_OOOpenGLStateVerifier` passes on the base.
3. The item table, per [contracts/gl-state-items.md](contracts/gl-state-items.md); the `.tbl` deleted.
4. Both tests and the suites pass; Clang and GCC show no new warnings; the SC-002 trials.
5. Docs (FR-007).

## Notes and decisions

1. **New warnings (FR-005)** can only come from the two files that change, because no header
   changes. The check is therefore the warnings Clang and GCC report for
   `OOOpenGLStateManager.cpp` and `test_OOOpenGLStateVerifier.cpp`, against the base's.
2. **Not pushed.** Local `seriesb/027-modern-cpp` and `origin/seriesb/027-modern-cpp` have diverged
   (277 ahead, 530 behind on 2026-11-13), so a push would need a force, which the rules allow only
   through `git town sync`. Jon pushes.
3. **`seriesb/028-upstream-772-tests`** was restacked onto these commits on 2026-11-13, at Jon's
   request. Its two commits were rebased onto `seriesb/027-modern-cpp` with
   `git rebase --onto seriesb/027-modern-cpp 3732f6126` in `.agent-tmp/wt-772`; the old tip was
   `bc70a6e90`, the new one is `eb9e7d86d`. `git town sync` was not used: with the rebase strategy,
   it would also have rebased local `seriesb/027-modern-cpp` onto its diverged `origin` copy. On
   the new tip, the unit run matches 027's: 229 pass, plus the two failures of Notes 4.
4. **Two tests are already broken on the base**, before any change here, and are not this
   feature's to fix (an edit to make them pass would break hard rule 1):
   - `test_EnumNameFallbacks` does not link (`gDebugFlags` is undefined: it is defined in
     `src/SDL/main.cpp`, which `['*']` tests leave out). So `./mk.sh build test` stops there, and
     the build was finished with `ninja -k 0`.
   - `test_SaveEnumValues` aborts (`0xc0000409`) in its case `savedChartAndSpeechNumbers`.

   The unit runs below are every test except the unlinkable one.
5. **Verifier test expectation.** On the base, a switch of the active texture unit also makes the
   verifier report `GL_TEXTURE_2D`, because `glIsEnabled(GL_TEXTURE_2D)` is read for the active
   unit. The test expects that line, since it is what the base prints.
6. **Formatting.** Only clang-format 23.1.4 is installed here. The changed file was laid out by
   hand until `clang-format --dry-run` (23) reported nothing; it was never formatted with 23.
   CI's clang-format 22 check is the authority. The base file also passes 23's dry run.

**Results**:
- Base (`3732f6126`):
  - Unit: 228 pass; `test_SaveEnumValues` fails (Notes 4).
  - `test_OOOpenGLStateVerifier`: passes.
  - Clang warnings in `OOOpenGLStateManager.cpp`: one, `-Wtautological-pointer-compare` (`GetCurrentOpenGLState`'s assert).
  - GCC warnings in it: one, `-Wclass-memaccess` (its `memset`).
- SC-002 trials:
  - OpenGL record field without an item — result: build fails, `static assertion failed due to requirement 'AggregateFieldCount<OOOpenGLState>() == 1 + std::size(kStateItems) + 2'`.
  - OpenGL item without a setter — result: build fails, `no matching function for call to 'IntItem'`.
- After:
  - Clang warnings over the whole build: a subset of the base's; the same one in `OOOpenGLStateManager.cpp`.
  - GCC: the same one warning in `OOOpenGLStateManager.cpp`, and none in the new test.
  - `NDEBUG` syntax check of `OOOpenGLStateManager.cpp` (Clang): clean.
  - Unit: 229 pass (the base's 228 plus `test_OOOpenGLStateVerifier`); `test_SaveEnumValues` fails as on the base.
  - Component: 20 passed.
  - Smoke: passed.
