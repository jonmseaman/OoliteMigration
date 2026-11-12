# Implementation Plan: Third-party code by wrap

**Branch**: `feature/third-party-wraps` (in `oolite-dev`, from `develop`; branch phase 1 of 2) |
**Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/013-third-party-wraps/spec.md`

## Summary

MiniZip, miniz, tinyexr and stb_image_write leave `oolite-dev/src/` and come in as four pinned
wraps in `subprojects/`, each at its latest release, requested beside QuickJS-ng in
`src/meson/meson.build`:

- **miniz**: WrapDB's own wrap.
- **MiniZip**: zlib 1.4's `contrib/minizip` with a small overlay and one behavioural patch.
- **tinyexr and stb**: header-only overlays.

Before anything moves, a new unit test pins what the snapshot writers produce, and the warning
lists of both compilers are recorded. After the move, the same test and the same warning lists
prove the game behaves as before. Licences, tooling exclusions and docs follow.

## Technical Context

**Language/Version**: C++20 for the game. MiniZip and miniz go back to C (C11/gnu11, as meson's C
compiler builds them), since they are no longer compiled as C++.

**Primary Dependencies**:
- miniz 3.1.2 (WrapDB 3.1.2-1);
- zlib 1.4 release tarball (`contrib/minizip`, built against the system zlib);
- tinyexr v3.4.0 (`tinyexr.h`, `exr_reader.hh`, `streamreader.hh`);
- stb at `48fb1c9` (stb_image_write v1.17);
- meson 1.12.1 (project minimum 1.4.0).

**Storage**: N/A.

**Testing**:
- the unit (`oofnd`, `core`, `headers`), component and smoke suites through `tests/run.sh`, on
  Clang and GCC (`--native-file=gcc.ini`);
- the new `test_OOSnapshotWriters` (R9);
- a warning-list comparison (R8);
- an offline setup with `--wrap-mode=nodownload`;
- `git grep` checks for SC-001 and SC-003.

**Target Platform**: Windows x64, MSYS2 UCRT64, where the game and tests are verified today. Each
chosen source also builds on macOS arm64 and Linux x64. MiniZip's Apple I/O is handled in zlib's
`ioapi.c`, and tinyexr and miniz are Windows-only in the game.

**Project Type**: desktop game; build files, four libraries' provenance, one new test.

**Performance Goals**: none. The game's run-time code paths are the same libraries.

**Constraints**:
- CLAUDE.md's hard rules.
- No suppression in anything the fork writes: no `-Wno-*`, pragma, unused-attribute,
  `warning_level` lowered below 1, `is_system` or `include_type: 'system'`.
- Libraries are linked statically: no new DLL.
- `subprojects/` keeps its name.
- No test-framework change.

**Scale/Scope**:
- 11 files leave `src/`, along with two `meson.build` and one `.clang-tidy`;
- 4 `.wrap` files, 3 overlay `meson.build` files and 1 patch are added;
- about 6 edited build or config files, one new test program and `LICENSE.md`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the blank template, so the gates are CLAUDE.md's hard
rules and `docs/workflow.md`'s definition of done, as in specs 005, 009 and 011.

| Gate | Plan | Status |
|---|---|---|
| 1. No test changed to make it pass | Only additions and build wiring under `tests/`. `test_OOSnapshotWriters` is new. `tests/unit/core/meson.build` loses two source paths from three entries because the files are gone (FR-014), and gains one entry. No test source or assertion changes. Each edit is in `test-ledger.md`. `check_debug_monitor_guards.py` is not touched. | pass |
| 2. No warning silenced | The overlays set no warning options and use plain include directories (R8). WrapDB's own miniz packaging adds `-Wno-deprecated-declarations` on Windows, which the fork's tree does not contain, the same standing as QuickJS-ng's own `-Wno-*` list (R2). Recorded for Jon, with the fallback of a fork-written overlay. | pass, with a recorded decision |
| 3. Never touch `develop`/`master`/`main`; no force-push | Game work on `feature/third-party-wraps`; spec docs on the planning repo's current branch; Jon merges. | pass |
| 4. Never read expansion content | The OXZ paths are covered by existing tests and test-made archives. | pass |
| 5. Tools judge correctness | The suites, the snapshot test, both compilers' warning lists and `meson setup --wrap-mode=nodownload` decide. | pass |
| 6. No `libgnustep-base` or SpiderMonkey | Nothing added. | pass |
| 7. No rewriting C for its own sake | The task is about this C code; the fork's C++ conversions are dropped for the pristine C. | pass |
| 8. Never wait for Jon | Every choice has a default (*Notes*). | pass |
| 9. No writes outside the repo | Downloads go to `oolite-dev/subprojects/packagecache/` (git-ignored); scratch in `.agent-tmp/`. | pass |
| 10. clang-format 22, changed files only, never `tests/` | No C or C++ under `src/` changes, apart from deleted files. The new test lives under `tests/` and is written in the tests' layout, not formatted. Meson files are not clang-formatted. | pass |
| Every task has a failing-then-passing command | Each milestone's command is in [quickstart.md](quickstart.md). | pass |
| Style from the exemplar | Wraps follow `quickjs-ng.wrap` (pinned URL, hash, fallback URL, `packagefiles/` patches with headers); requests follow `src/meson/meson.build`'s QuickJS-ng block; the test follows `tests/unit/core`'s programs. | pass |

**Re-check after Phase 1:** pass. Nothing in *Complexity Tracking*.

## Project Structure

### Documentation (this feature)

```text
specs/013-third-party-wraps/
├── spec.md
├── plan.md                 # this file
├── research.md             # Phase 0: R1–R10
├── data-model.md           # Phase 1: each wrap's fields, overlay, patch and request
├── quickstart.md           # Phase 1: commands per milestone
├── contracts/
│   ├── wraps.md            # what every wrap, overlay and patch must contain
│   └── snapshot-test.md    # test_OOSnapshotWriters: input, checks, failure rules
├── baselines/              # created in M0: warning lists, installed-file list
├── test-ledger.md          # created in M0: every edit under oolite-dev/tests/
├── checklists/requirements.md
└── tasks.md                # /speckit-tasks
```

### Source Code (`oolite-dev`)

```text
subprojects/miniz.wrap                              # NEW (M1): WrapDB 3.1.2-1, unchanged
subprojects/minizip.wrap                            # NEW (M1): zlib 1.4 tarball, nested (R3)
subprojects/tinyexr.wrap                            # NEW (M1): v3.4.0 tarball
subprojects/stb.wrap                                # NEW (M1): commit 48fb1c9 archive
subprojects/packagefiles/minizip/meson.build        # NEW (M1): static_library of ioapi.c, unzip.c
subprojects/packagefiles/minizip/0001-unzOpenCurrentFile3-reject-unsupported-method.patch  # NEW (M1)
subprojects/packagefiles/tinyexr/meson.build        # NEW (M1): header-only, needs miniz
subprojects/packagefiles/stb/meson.build            # NEW (M1): header-only
meson.build                                         # M2: force_fallback_for, one entry per line (R7)
src/meson/meson.build                               # M2: the four dependency() requests (R6)
src/Core/meson.build                                # M2: subdir('MiniZip') removed
src/Core/MiniZip/                                   # M2: deleted
src/SDL/EXRSnapshotSupport/{miniz.*,tinyexr.h,LICENSE.*}  # M2: deleted
src/SDL/EXRSnapshotSupport/meson.build              # M2: OOSaveEXRSnapshot.cpp only
src/SDL/stb_image_write.h                           # M2: deleted
tests/unit/core/test_OOSnapshotWriters.cpp          # NEW (M0)
tests/unit/core/meson.build                         # M0: new entry; M2: MiniZip paths dropped
.clang-tidy                                         # M3: exclusion trimmed
LICENSE.md                                          # M3: four notices, closing paragraph
```

Planning repo: `docs/current-state.md` (M3, FR-018).

**Structure Decision**: no new top-level directory. External code enters through `subprojects/`
like QuickJS-ng. Oolite's own `OOSaveEXRSnapshot.cpp` stays in `src/SDL/EXRSnapshotSupport/`,
where upstream has it.

## Branch phases

Jon's order (2026-11-12, recorded in spec 005's plan): this is phase 1 of 2, one branch and one PR.
Spec 005 (Google Test) is cut from this branch's tip. Its only contact with this work is
`subprojects/` (it adds `gtest.wrap`) and one line in `force_fallback_for`. M2 lays that list out
for a one-line addition. Spec 005's plan still names WrapDB `gtest` 1.17.0-4. WrapDB now also has
1.18.0-1, which is that spec's choice, not this one's.

## Milestones

Each milestone is its own commit series and builds clean on Clang and GCC. Its command is in
[quickstart.md](quickstart.md).

| M | What | FRs / SCs | Proof |
|---|---|---|---|
| M0 | Cut the branch. Record baselines: sorted `warning:` lines of a clean full build on each compiler; `meson introspect --installed` and the deployment folder's DLL list. Add `test_OOSnapshotWriters` and its entry, passing on the unmoved code. Start `test-ledger.md`. | FR-011; SC-003, SC-005, SC-007 inputs | the new test passes; `baselines/` exists |
| M1 | The four wraps, three overlays, one patch; `meson subprojects download` fills `packagecache`. Prove R3's nesting, R2's MinGW question and R4's header-only claim, each on a throwaway setup that requests the dependency alone. Nothing wired into the game yet. | FR-002–006, 010 | `meson subprojects download` and `meson subprojects foreach` show four sources at their pins; probe setups build |
| M2 | Wire: `force_fallback_for`, the four requests, delete the copies and their `meson.build` entries, trim the three test entries. Full build and all suites on both compilers; warning lists compared with M0. | FR-001, 007–009, 011, 014, 016, 017; SC-001–005 | `tests/run.sh all` on Clang and GCC; warning diff empty; SC-001 grep |
| M3 | `LICENSE.md`, `.clang-tidy`, comments in `oolite-dev` that call the files vendored; `docs/current-state.md` in the planning repo. | FR-013, 015, 018 | grep checks in quickstart |
| M4 | Offline setup with `--wrap-mode=nodownload`. Deployment build: installed-file and DLL lists against M0, and `License.pdf` names all four. SC-003 grep of the feature's added lines. Phase-2 probe: adding `'gtest',` to the list is a one-line diff. | FR-012; SC-003, 006–008 | quickstart M4 commands exit 0 |

## Notes (defaults taken without asking)

- **WrapDB miniz as published** (R2), although its packaging adds `-Wno-deprecated-declarations`
  on Windows. That flag is WrapDB's, downloaded rather than written by the fork, which is the
  standing QuickJS-ng's flags already have. If Jon reads hard rule 2 as covering downloaded
  packaging too, the switch is a fork-written `packagefiles/miniz/meson.build` over the same zip.
  That is one file, and any warnings it exposes are patched under FR-006.
- **MiniZip nested under `minizip-zlib-1.4/`** (R3), so a future zlib wrap cannot collide; fallback
  recorded there.
- **Snapshot expectations from the formats' rules, not stored output** (R9). The test's pass on the
  unmoved code is the reference. Only if old tinyexr's rounding differs are develop's decoded
  values written into the test, once, at M0.
- **`.hdr` tolerance 1/128 of the pixel's largest component**: one RGBE mantissa step. The spec's
  first wording said 1/256, which is half a step and would fail on correct output. The spec now
  says 1/128.
- **Hashes and stb's full commit hash are taken at M1** from the downloads and the publishers'
  pages. They are not guessed here.
- **The installer comparison uses the deployment install tree and its DLL list**, not a built
  `.exe` diff: the NSIS script packs that tree (`installers/win32/OOlite.nsi`), so the tree is what
  it ships. M4 also builds the installer once, to show `License.pdf` is produced.
- **`.specify/feature.json` still points at spec 012.** This plan was written by naming the
  directory explicitly; `/speckit-tasks` must do the same.

## Complexity Tracking

None.
