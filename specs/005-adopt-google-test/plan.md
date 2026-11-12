# Implementation Plan: Adopt Google Test

**Branch**: `feature/adopt-google-test` (in `oolite-dev`; phase 2, see *Branch phases*) |
**Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-adopt-google-test/spec.md`

## Summary

Bring Google Test in as a pinned meson wrap beside QuickJS-ng, give every converted program one
shared `main` that keeps what `oo_test.hpp` does well (zero tests fails, source order, the
running case named on an abort), and register converted programs with meson's `gtest` protocol
so per-case results and a JUnit report come for free. Then convert the 223 programs in batches
(`oofnd`, then `core` by family) with a script, each batch proved by `parity.py` (same cases, same
check sites, nothing that passed now fails), and delete `oo_test.hpp`.

Jon's question about a `vendor/` directory is answered in [research.md R2](research.md): in this
repo, `subprojects/` is that directory, and Google Test goes there. The four libraries copied into
`src/` (MiniZip, miniz, tinyexr, stb_image_write) are the unclear part. Moving them changes the
shipped game, so it is a separate spec, not this one.

## Technical Context

**Language/Version**: C++20 (tests and game), Python 3 (standard library only) for the
conversion and parity scripts.

**Primary Dependencies**: googletest v1.17.0 through WrapDB `gtest` 1.17.0-4 (R1); meson 1.12.1
(project minimum 1.4.0; `protocol: 'gtest'` needs 0.55).

**Storage**: N/A.

**Testing**: the `oofnd` and `core` meson suites, `tests/run.sh unit`; `parity.py static` and
`parity.py run` per batch; the deployment `oofnd` build (`-Ddeployment_unit_tests=true`); a
sanitized build with `tests/unit/asan-suppressions.txt`; both Clang and GCC (`--native-file=gcc.ini`).

**Target Platform**: Windows x64, MSYS2 UCRT64 (where the unit tests run). The pinned Google Test
must also build on macOS arm64 and Linux x64 later; it does (upstream CI covers both).

**Project Type**: desktop game; this feature touches only its test tree and build files.

**Performance Goals**: clean build of the test programs at most 15% slower, full unit run at most
10% slower (SC-005), against a baseline recorded before M1 (R8).

**Constraints**: CLAUDE.md hard rules. Never change an expectation (FR-013). Every check stays
non-fatal. No warning silenced: no `include_type: 'system'` on the dependency, no subproject
`warning_level` override, no pragmas. Google Test is never fetched or linked by a build without
the unit tests (FR-003).

**Scale/Scope**: 223 programs, 1,835 cases, about 11,200 check sites; one wrap file, one shared
`main`, one small header, two scripts, edits to two `meson.build` files and `tests/run.sh`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the blank template, so the gates are CLAUDE.md's hard
rules and `docs/workflow.md`'s definition of done, as in specs 008 and 009.

| Gate | Plan | Status |
|---|---|---|
| 1. No test changed to make it pass | US1 and US2 add tests only. US3 edits every test file: no existing exception covers that, so US3 waits for Jon's signed line in `CLAUDE.md` and keeps `test-ledger.md` (R11). No expectation changes; a regression stops the batch (FR-013). | **pass for US1–US2; US3 gated** |
| 2. No warning silenced | Google Test must build clean at `-Wall` on Clang and GCC; a warning in a converted test is fixed in the test (ledger) or stops the batch (FR-002, R6). | pass |
| 3. Never touch `develop`/`master`/`main`; no force-push | Game work on `feature/adopt-google-test`, stacked on phase 1's `feature/third-party-wraps` and updated by merging `develop`, never rebased (*Branch phases*); spec docs on the planning repo's current branch; Jon merges. | pass |
| 4. Never read expansion content | Nothing here reads expansion files. | pass |
| 5. Tools judge correctness | `parity.py` decides each batch; the suites, sanitizers and both compilers decide the rest. | pass |
| 6. No `libgnustep-base` or SpiderMonkey | Nothing added. | pass |
| 7. No rewriting C for its own sake | No C touched; the `src/` third-party copies are left where they are (R2). | pass |
| 8. Never wait for Jon | Every open choice has a default (*Notes*). The US3 gate is recorded as a task for Jon; US1, US2 and the scripts go ahead without it. | pass |
| 9. No writes outside the repo | Scratch in `.agent-tmp/`; the WrapDB download goes to `subprojects/packagecache/`, which is inside `oolite-dev` and git-ignored. | pass |
| 10. clang-format 22, changed files only, never `tests/` | `oo_gtest_main.cpp` and `oo_gtest.hpp` live under `tests/`, so they are written by hand in the tests' layout and not formatted; the converter changes only the tokens it maps. | pass |
| Every task has a failing-then-passing command | Each milestone's command is in [quickstart.md](quickstart.md). | pass |
| Style from the exemplar | Meson wiring follows `quickjs-ng.wrap` and the existing `oofnd`/`core` loops; scripts follow spec 009's `check.sh` and `external-values-gen.py` (kept in the spec directory). | pass |

**Re-check after Phase 1:** pass, with the US3 gate unchanged. The design adds one thing to
*Complexity Tracking*: a second harness for the length of the migration.

## Project Structure

### Documentation (this feature)

```text
specs/005-adopt-google-test/
├── spec.md
├── plan.md                # this file
├── research.md            # Phase 0: R1–R13, including the vendor/ question (R2)
├── data-model.md          # Phase 1: programs, cases, check sites, batches, reports
├── quickstart.md          # Phase 1: how to verify each milestone
├── contracts/
│   ├── check-mapping.md   # old macro → new macro, value sites, wrappers, known differences
│   └── runner.md          # shared main, meson registration, run.sh -k, reports, exit codes
├── parity.py              # created in M2 (R9)
├── convert.py             # created in M3 (R10)
├── baselines.md           # created in M0 (R8)
├── test-ledger.md         # created in M3: hand edits beyond the mapping (R11)
├── checklists/requirements.md
└── tasks.md               # /speckit-tasks
```

### Source Code (`oolite-dev`)

```text
subprojects/gtest.wrap                 # NEW (M1): WrapDB gtest 1.17.0-4
meson.build                            # M1: 'gtest' in force_fallback_for; gtest_dep inside the unit-test branches
tests/unit/oo_gtest_main.cpp           # NEW (M1): the shared main (contracts/runner.md)
tests/unit/oo_gtest.hpp                # NEW (M1): OO_EXPECT_V, OO_EXPECT_EQ_V (contracts/check-mapping.md)
tests/unit/meson.build                 # NEW (M1): builds oo_gtest_main as a static library, declares oo_gtest_dep
tests/unit/oofnd/meson.build           # M1 example program; M3 harness field per entry; M6 field removed
tests/unit/core/meson.build            # M5 harness field; M6 removed
tests/unit/oofnd/test_gtest_harness.cpp  # NEW (M1): the harness's own tests (runner.md R1–R6)
tests/unit/oofnd/*.cpp, core/*.cpp     # M3, M5: converted
tests/unit/oofnd/oo_test.hpp           # M6: deleted
tests/run.sh                           # M2: `unit -k <filter>`
```

Planning repo: `CLAUDE.md` (exemplar row, US3 exception line by Jon), `docs/workflow.md` and
`docs/current-state.md` (FR-018), one-line notes in spec 003 (FR-019).

**Structure Decision**: no new top-level directories. Google Test enters through `subprojects/`
like QuickJS-ng. The shared harness files sit at `tests/unit/`, above the suites that use them,
because both `oofnd` and `core` link them (today's `oo_test.hpp` sits in `oofnd/` and `core`
reaches it with an extra include path).

## Branch phases

Jon's order (2026-11-12): two branches, each one PR into `develop`.

| Phase | Branch (in `oolite-dev`) | Spec | Contents |
|---|---|---|---|
| 1 | `feature/third-party-wraps`, from `develop` | its own spec (the R2 follow-up) | MiniZip, miniz, tinyexr and stb_image_write leave `src/` and come in by wrap |
| 2 | `feature/adopt-google-test` | this one | M0–M6 below: Google Test's wrap, the shared `main`, the conversion, the old harness's removal |

Phase 2 is cut from phase 1's branch tip, so it can start before Jon merges phase 1 (hard rule
8). Both touch `subprojects/` and the `force_fallback_for` list in the top-level `meson.build`, so
stacking avoids a conflict there. When phase 1 lands in `develop`, phase 2 merges `develop` in
(never a rebase or force-push, hard rule 3) and its PR then shows only its own commits. If phase 1
is abandoned, phase 2 is cut again from `develop`; nothing in it depends on phase 1's content.

This replaces the spec's assumption that the work goes upstream as a series of small PRs (Story 1,
then each batch, then retirement): phase 2 is one PR. Its milestones stay separate commit series
inside it, so it can still be reviewed and bisected batch by batch.

## Milestones

Each milestone builds, passes `tests/run.sh unit` on Clang and GCC, and has its command in
[quickstart.md](quickstart.md).

| M | What | Stories / FRs | Proof |
|---|---|---|---|
| M0 | Baselines: clean test-program build time and full unit run time, three runs each; old-harness pass list from `meson-logs/testlog.txt` | SC-005; FR-013 input | `baselines.md` exists with numbers |
| M1 | Wrap, `gtest_dep`, `oo_gtest_main`, `oo_gtest.hpp`, `test_gtest_harness` (tests first: a deliberately failing case, a zero-test program, an abort, a value site) | US1; FR-001–006, 010 | runner.md R1–R6 |
| M2 | `meson test` with `protocol: 'gtest'`; `tests/run.sh unit -k`; JUnit report; `parity.py` with its own fixtures | US2; FR-007–009, 012 | runner.md R7–R9; parity fixtures |
| M3 | Convert `oofnd` (40 programs) with `convert.py`; ledger; NDEBUG build; re-measure build time | US3; FR-011, 013, 014, 016 | `parity.py static` + `run`; deployment `oofnd` |
| M4 | Docs: exemplar row, `workflow.md`, `current-state.md`, header comments, spec 003 note | FR-018, 019 | grep checks in quickstart |
| M5 | Convert `core` in families (verifier stages, materials and shaders, sound, JS bindings `test_OOJS*`, entities, the rest), one commit series each; sanitized run once per family | US3; FR-015, 016 | `parity.py` per family; sanitized `core` |
| M6 | Delete `oo_test.hpp`; drop the harness field; docs stop mentioning it | US4; FR-017 | SC-006 grep; a probe file using `OO_CHECK` fails to build |

M3 and M5 also wait on the US3 gate (Constitution Check, gate 1).

## Notes (defaults taken without asking)

- **No `vendor/` directory in this feature** (R2). `subprojects/` is the externally owned
  directory; QuickJS-ng is not vendored (only its wrap and patches are in git). The `src/`
  copies are left for a separate spec whose default is a wrap per library (WrapDB `miniz`;
  custom wraps for MiniZip from zlib's tarball, tinyexr and stb), with a tracked local
  `subprojects/<name>/` as the fallback for any that cannot come in that way.
- **Pin 1.17.0-4, not 1.18.0-1** (R1): the newer has only its first wrap revision and adds
  nothing this feature needs.
- **US3 waits for a hard-rule-1 exception** signed by Jon in `CLAUDE.md` (R11). Until then, M0–M2
  and M4's US1 part go ahead, and new tests are written on Google Test.
- **`expander` and `sysdesc` are out** (R13): unbuilt, not on the harness. Whether to restore or
  delete them is left to Jon; not blocking.
- **Uncaught exceptions fail the case, not the program** (R4). The program still fails;
  `--gtest_catch_exceptions=0` gives back today's behaviour for debugging.
- **The value-printing helpers stay** (`EvalShown`, `LogShown`); after conversion they duplicate
  Google Test's own message, but deleting them would rewrite tests for no gain.
- **Case names keep their underscores** (R5); the suite name is the file stem less `test_`.
- **Sign-compare fixes** in converted tests (about seven sites) are a literal suffix, ledgered
  (R6), never a pragma or `-Wno-sign-compare`.
- **Precompiled header only if needed** (R8): added before `core` only if `oofnd` shows the
  build-time budget will be exceeded.
- `oolite-dev` currently has another session's uncommitted files on `feature/double-wide-support`.
  The first task branches `feature/adopt-google-test` from phase 1's tip only once that tree is clean,
  and never stashes or discards someone else's work.

## Complexity Tracking

| Addition | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Two harnesses at once, for M1–M5 | Batches must be reviewable one at a time (FR-016), and US1 must land before US3 can start | A single big-bang conversion of 223 programs can't be reviewed or bisected, and needs the US3 gate before anything lands |
| A shared `main` library instead of `gtest_main` | `gtest_main` passes zero-test programs and names no case on an abort (FR-006, edge cases) | Setting the flag on each command line would rely on every caller remembering it |
| Two expression macros in `oo_gtest.hpp` | 19 sites use a check's result as a value; `EXPECT_*` are statements | Rewriting those sites into `if` blocks changes the tests' structure, which is more than the ledger should hold |
