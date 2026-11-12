# Research: Adopt Google Test

Phase 0 for [plan.md](plan.md). Each entry: decision, rationale, alternatives. Facts were read from
`oolite-dev` at `feature/double-wide-support` (2026-11-12) and from the Meson WrapDB and Google
Test release pages on the same day.

## What is there today (measured)

| Fact | Value | How measured |
|---|---|---|
| Programs on `oo_test.hpp` | 222 (40 `oofnd`, 182 `core`) | `grep -l oo_test.hpp` |
| `OO_TEST` cases | 1,835 | `grep -o 'OO_TEST('` |
| `OO_CHECK` / `OO_CHECK_EQ` sites | about 11,200, 1,750 of them through `OO_CHECK_EVAL` | `grep -o` |
| Check results used as values | 19 (`bool ok = OO_CHECK(...)`, `if (OO_CHECK_EQ(...)) return`) | `grep` for `=`, `if (`, `return`, `&&` before the macro |
| File-local wrapper macros | `OO_CHECK_EVAL` (28 files), `OO_CHECK_LOG` (3), `OO_CHECK_TEXT`, `OO_CHECK_PAGE`, `OO_CHECK_CALLS` | `grep '#define OO_CHECK_'` |
| Programs with their own `main` | `oofnd/test_plist_hdr_brightness_index.cpp` (registers its cases by hand), `core/test_OoliteEquipmentControlScript.cpp` (its own `CHECK`/`CHECK_JS`, no `oo_test.hpp`) | `grep '^int main'` |
| Case names with an underscore | 67 (e.g. `parse_http_urls`) | `grep` |
| Tests that capture output | 4, all by `std::cout`/`std::cerr` `rdbuf()` swap | `grep rdbuf` |
| Warning flags | `warning_level=1` (`-Wall`) in every build directory; no `werror` | `meson introspect --buildoptions` |
| Meson | 1.12.1 (project needs >= 1.4.0) | `meson --version` |

**Corrections to the spec's Context** (recorded here, spec text not rewritten): `tests/unit/expander`
and `tests/unit/sysdesc` are not built by meson and do not use `oo_test.hpp`: each describes
itself as built by a script against `.mm` sources that no longer exist. There is no separate
"QuickJS engine test" program; the engine's tests are `core` programs (`test_OOJavaScriptEngine`
and the `test_OOJS*` family). So the programs to migrate are the 222 above plus
`test_OoliteEquipmentControlScript`. See R13.

## R1. Where Google Test comes from

**Decision**: a WrapDB wrap, `oolite-dev/subprojects/gtest.wrap`, pinned at **1.17.0-4**
(googletest v1.17.0, wrap revision 4). Add `gtest` to `force_fallback_for` in the top-level
`project()` beside `quickjs-ng`, so an MSYS2 or Homebrew system package is never picked
instead. The wrap provides `gtest`, `gtest_main`, `gmock` and `gmock_main`; we use `gtest` and
`gmock` only (our own `main`, R4).

**Rationale**: it is the mechanism QuickJS-ng already uses (spec FR-001, Assumptions): a pinned
source hash, fetched by `meson setup`, cached in `subprojects/packagecache/` so a populated tree
builds offline (`--wrap-mode=nodownload`). The existing `subprojects/.gitignore` already tracks
only `*.wrap` and `packagefiles/`, so nothing else needs changing. v1.17.0 needs C++17 (we build
C++20, C++23 planned) and adds `--gtest_fail_if_no_test_linked` (R4). Revision 4 of its wrap has
had three fixes since its first release.

**Alternatives**: 1.18.0-1 (the newest, August 2026; only its first wrap revision, and nothing in
it is needed here; moving up later is a one-line change). Vendoring the source into the tree
(see R2). A git submodule (a second fetch mechanism beside meson's, and a full copy of the
history).

## R2. Third-party code layout: should there be a `vendor/` directory?

The question (Jon, 2026-11-12): other repos keep externally owned code in `vendor/`, so it is
clear what is not theirs. Here MiniZip sits in `src/Core/MiniZip/`, and `subprojects/` holds
QuickJS-ng, which replaced SpiderMonkey (formerly an OoliteProject repository).

**What the tree has now:**

| Code | Where | How it is held | Changed locally? |
|---|---|---|---|
| QuickJS-ng 0.17.0 | `subprojects/quickjs-ng.wrap` + `packagefiles/` | **Not vendored.** Wrap + four patches tracked; source fetched by hash at setup, ignored by git | Yes, by the four tracked patches |
| MiniZip 1.1 (Gilles Vollant, zlib licence) | `src/Core/MiniZip/` | Copied into `src/` | Yes: `.c` renamed `.cpp`, clang-formatted, `nullptr`, warning fixes |
| miniz, tinyexr | `src/SDL/EXRSnapshotSupport/` | Copied into `src/` | Yes: `miniz.c` compiled as `miniz.cpp`, reformatted. Upstream keeps `LICENSE.miniz` and `LICENSE.tinyexr` beside them |
| stb_image_write | `src/SDL/stb_image_write.h` | Copied into `src/` | Reformatted |
| SDL3, OpenAL, libpng, zlib, Vorbis, espeak-ng, libcurl | system (`dependency()`) | Not in the tree | No |

So `subprojects/` is already the "externally owned" directory, in meson's own convention: what
is in it is pinned and fetched, and the local changes are patch files you can read. What is not
clear is the four libraries copied into `src/`, which also carry local edits with no record of
what changed.

**Decision for this feature**: Google Test goes in `subprojects/` (R1). No `vendor/` directory is
created by this feature, and the `src/` copies are not moved.

**Rationale**: moving MiniZip, miniz, tinyexr and stb out of `src/` changes the shipped game's
build and diverges from upstream's layout (upstream keeps them in the same places). That is
not a test-framework change, so it would break spec FR-003 ("Google Test must not change the
shipped game"). It also needs decisions this spec has no basis for: whether to keep the C++
conversions or go back to pristine C (hard rule 7), and whether to take WrapDB packages
(`miniz` 3.1.2 is there; MiniZip only as `minizip-ng`, a different API; `stb` and `tinyexr`
are not).

**Follow-up (its own spec)**: "Mark third-party code". The default to take there is to move each
copy into `subprojects/<name>/` as a tracked local subproject with its own `meson.build`, its
licence file, and a `README` naming its origin, version and local changes. That makes one
directory hold everything not ours (meson's convention, so `force_fallback_for` and
`meson subprojects` keep working). The alternative is a top-level `vendor/` or `third_party/`,
which other repos use; it is one more convention beside `subprojects/` that meson does not know.
Proposed as a separate session, not part of this plan.

## R3. Coexistence of the two harnesses

**Decision**: every program is one executable, as now. A converted program links
`oo_gtest_main` (R4) and `gtest_dep`, and registers with `test(..., protocol: 'gtest')`; an
unconverted one stays as it is (`protocol` defaults to `exitcode`). The `oofnd` and `core`
`meson.build` loops get one extra field per entry saying which harness a program uses, and
lose it again at retirement (US4).

**Rationale**: no program needs both headers. Meson already mixes protocols within a suite. With
`protocol: 'gtest'`, meson passes `--gtest_output=xml:...` and reads per-case results into its
log and `meson-logs/testlog.junit.xml` (FR-009) with no parser of our own.

**Alternatives**: a bridge header that turns `OO_CHECK` into `EXPECT_TRUE` without editing the
tests (rejected: it keeps the old macros alive forever, and FR-017 says they go); one executable
per suite (rejected: changes link sets the `core` list sets up per program, and a crash in one
case would hide every other program's results).

## R4. The `main` every converted program uses

**Decision**: one shared `tests/unit/oo_gtest_main.cpp`, built once as a static library. It:

1. sets `GTEST_FLAG_SET(fail_if_no_test_linked, true)` **before** `InitGoogleTest`, so a program
   with no tests fails (FR-006) while the command line can still override it;
2. leaves `shuffle` off (Google Test's default; FR-010). Within one translation unit, Google Test
   runs cases in definition order, which is source order;
3. installs the same `SIGABRT` handler `oo_test.hpp` has, printing
   `oo_gtest: abort() in case <Suite.name>` from `UnitTest::GetInstance()->current_test_info()`
   (Edge case: aborts). Google Test already flushes stdout after every `[ RUN ]` line, so the
   case is named even without the handler;
4. knows nothing about any program's set-up. A program that needs one-time set-up before any
   case (the custom `main`s, R10) defines a `::testing::Environment` and registers it with
   `AddGlobalTestEnvironment` from a static initialiser; Google Test runs its `SetUp` once,
   before the first case;
5. returns `RUN_ALL_TESTS()`.

A filter that matches nothing exits 0 (Google Test's default; `fail_if_no_test_selected` is not
set), which is the spec's last edge case.

**Rationale**: `gtest_main` cannot do 1 or 3. A shared library compiles it once, not 223 times.

**Behaviour change noted, not avoided**: with `catch_exceptions` on (the default), an uncaught C++
exception or a Windows SEH fault inside a case fails that case and the program carries on. Today
it ends the program. The program still fails, and the other cases' results are now reported.
Turning it off (`--gtest_catch_exceptions=0`) keeps today's behaviour for a developer who wants a
debugger to stop there; `tests/run.sh` does not pass it.

## R5. Test and suite names

**Decision**: `OO_TEST(name)` becomes `TEST(<Suite>, name)`, where `<Suite>` is the file name less
`test_` and `.cpp` (`test_OOColor.cpp` → `OOColor`, `test_string_compare.cpp` →
`string_compare`). Case names are kept exactly, including the 67 with underscores.

**Rationale**: FR-011 keeps names unchanged. Google Test advises against underscores because
`TEST(a_b, c)` and `TEST(a, b_c)` make the same class name; with one suite per program, that
collision cannot happen, and the compiler would reject it if it did. Full names are
`OOColor.blendWorks`, so `--gtest_filter=OOColor.*` or `*.blendWorks` selects them.

## R6. Check mapping and the value-returning sites

**Decision**: the table in [contracts/check-mapping.md](contracts/check-mapping.md). In short:
`OO_CHECK(c)` → `EXPECT_TRUE(c)`, `OO_CHECK_EQ(a, b)` → `EXPECT_EQ(a, b)`, both non-fatal, and for
the 19 sites that use the result, two expression macros in a small `tests/unit/oo_gtest.hpp`,
`OO_EXPECT_V(c)` and `OO_EXPECT_EQ_V(a, b)`, which report through `ADD_FAILURE_AT(__FILE__,
__LINE__)` and return the `bool`. Each operand is evaluated once.

**Rationale**: `EXPECT_*` are statements, so they cannot stand where a value is used. Public API
only (`ADD_FAILURE_AT`, `testing::PrintToString`); no `testing::internal`. Fatal `ASSERT_*` is
never introduced (spec: keep every check non-fatal).

**Known differences, each handled in the contract**: `EXPECT_EQ` binds operands to `const T&`
(a bit-field operand does not compile: write `+field`); it compares through a template, so GCC's
`-Wsign-compare` (in `-Wall` for C++) can fire for `EXPECT_EQ(3, v.size())` where the plain
`(3) == (v.size())` did not (a constant is exempt only when compared directly). About seven sites
look like this. The fix is a matching literal (`3u`), which keeps the comparison's meaning; it is
a test edit and goes in the ledger (R11). Hard rule 2 rules out silencing it.

## R7. Running a subset (FR-008, SC-003)

**Decision**: `tests/run.sh unit -k <gtest-filter>` passes `--test-args=--gtest_filter=<filter>`
to `meson test`. One program: `meson test -C build/meson_debug test_OOColor
--test-args=--gtest_filter=OOColor.blendWorks`, or run the executable directly. Old-harness
programs ignore arguments (`main()` takes none), so a mixed suite still runs during migration.

**Rationale**: `-k` already means "select by name" for `tests/run.sh component`. No new runner.

## R8. Build-time budget (SC-005)

**Decision**: record the baseline before M1 (clean build of the test programs and a full
`tests/run.sh unit`, three runs each, on Jon's Windows machine, Clang, `meson_debug`) in
`baselines.md`. Measure again after `oofnd` (M3) and before `core` (M5). If the clean build is
more than 15% over, add a precompiled header for `<gtest/gtest.h>` to the test programs
(`cpp_pch`) before converting `core`.

**Rationale**: the gtest library is compiled once; the cost is parsing `gtest.h` in each of 223
programs. A precompiled header is the standard fix and changes no test.

## R9. The parity check (FR-012)

**Decision**: `specs/005-adopt-google-test/parity.py`, kept in the spec directory as spec 009 keeps
`check.sh`. Two modes:

- **static** `parity.py static <base-ref> <paths...>`: for each test file, in the base commit
  and in the working tree, list the case names and the check sites in order, each as
  (kind, normalised expression). It maps old kinds to new ones by the contract's table and
  exits nonzero on any case or site that is missing, added, renamed or of a different kind.
- **run** `parity.py run <before-log-dir> <after-junit>`: compares per-case pass/fail from the
  old harness's `ok`/`FAIL` lines (from `meson-logs/testlog.txt` of the base build) with meson's
  JUnit report of the converted build; exits nonzero if a case passed before and does not now
  (FR-013).

Python, run with `-I`, standard library only, balanced-parenthesis scan rather than regex (macro
arguments span lines). Normalisation collapses whitespace only, so a moved token is a change.

**Rationale**: parity has to be decided by a tool (hard rule 5), and both halves are needed: the
static half proves no site was lost; the run half proves no case regressed.

## R10. Conversion

**Decision**: `specs/005-adopt-google-test/convert.py <files...>` does the mechanical part of R5
and R6 (include, `OO_TEST`, the two macros, removing `OO_TEST_MAIN()`, the value-site macros where
the macro is not at the start of a statement) and the `meson.build` entry. Hand edits only for:
the wrapper macro definitions (their bodies change from `OO_CHECK_EQ` to `EXPECT_EQ`; their call
sites do not change), `test_plist_hdr_brightness_index` (its hand registration becomes `TEST`s in
the same order), and `test_OoliteEquipmentControlScript` (its `main`'s set-up becomes a
`::testing::Environment`, its `CHECK`/`CHECK_JS` become `EXPECT_TRUE`; the parity script learns
those two macro names). `EvalShown` and the other helpers that print a value stay as they are:
redundant now, but removing them is rewriting tests for no gain.

## R11. Hard rule 1 and the test-change ledger

**Decision**: Stories 1 and 2 add new tests only, and need no exception. Story 3 edits every test
file, and none of the three exceptions in `CLAUDE.md` covers it. The default taken (hard rule 8)
is to plan the work but make **Story 3 wait for a fourth exception**, in the form spec 009 used:
a line in `CLAUDE.md` signed by Jon, and a `test-ledger.md` in this directory that lists each
edit beyond the mechanical mapping (the sign-compare literals, bit-field `+`, the two custom
`main`s, the wrapper bodies). The mechanical mapping itself is proved by `parity.py`, not listed
line by line. A task for Jon to add the line comes before the first Story 3 task.

**Rationale**: Jon chose to keep Google Test (2026-11-12), but nothing on record signs off editing
11,000 test lines, and that is exactly what hard rule 1 protects.

## R12. Sanitizers, NDEBUG, output capture

- **Sanitizers**: Google Test is built with the same `b_sanitize` as the tests (meson applies the
  option to subprojects). The suppressions file is unchanged. A new report is a stop, not a
  suppression.
- **Deployment (NDEBUG) `oofnd` build**: `-Ddeployment_unit_tests=true` already builds the suite
  there; `dependency('gtest')` is called only where the unit tests are, so a plain deployment
  build (upstream's CI) never fetches Google Test (FR-003, SC-007).
- **Output capture**: the four capturing tests swap `std::cout`/`std::cerr` buffers. Google Test
  prints with `printf` to `stdout`, so its messages neither land in their captures nor get hidden
  by them.

## R13. What is out of the migration

`tests/unit/expander` and `tests/unit/sysdesc` are left alone: they are not built and do not use
the harness, so there is nothing to convert or prove. Story 4's search (SC-006) is for
`oo_test.hpp`, `OO_TEST`, `OO_CHECK` and `OO_TEST_MAIN`, which they do not contain. Whether they
should be built again or removed is not this feature's question; recorded in the plan's Notes.
