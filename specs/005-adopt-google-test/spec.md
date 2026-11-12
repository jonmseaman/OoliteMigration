# Feature Specification: Adopt Google Test

**Feature Branch**: `005-adopt-google-test`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "Create a plan for adopting Google Test."

## Purpose

The game's unit tests move from the in-tree harness to Google Test, the C++ test framework most
contributors already know. Each failure shows the values that differed, one test can be run on
its own, and results come out in a standard format. None of the tests' coverage is lost on the
way.

## Context

How the unit tests work today:

- **One bespoke harness.** Every unit test program includes `tests/unit/oofnd/oo_test.hpp`, a
  111-line header with a test registry, `OO_TEST`, `OO_CHECK`, `OO_CHECK_EQ` and `OO_TEST_MAIN`.
  It was written because no third-party framework was in the tree.
- **Size.** About 215 test programs under `tests/unit` (`oofnd`, `core`, `expander`, `sysdesc`,
  the QuickJS engine test) define about 1,800 test cases and roughly 11,000 check sites. About
  1,900 of those sites go through file-local wrapper macros (`OO_CHECK_EVAL`, `OO_CHECK_LOG`,
  `OO_CHECK_TEXT` and others). Five programs supply their own `main`. In 19 places the code uses
  a check's result as a value (`bool ok = OO_CHECK(...)`).
- **What a failure looks like.** A failed check prints its file, line, case name and the source
  text of the expression. It does not print the values that differed.
- **What can't be done.** A developer can't run one case from a program: each program runs all
  its cases in order. Results are lines of text that only the harness's own format describes.
- **What the harness does well.** A program that registers no tests fails rather than passing
  vacuously. An `abort()` names the case that was running. Output is flushed per case, so a
  crash under a sanitizer still shows how far it got.
- **Where the tests run.** The unit suites are built and run only on Windows today. The test code
  uses Windows headers and LLP64 types; the harness is not the reason. The `oofnd` suite is also
  built under the deployment (NDEBUG) settings in a separate build.
- **Related work.** Spec 003 (headless game and scene) adds a `scenario` suite on the existing
  harness. Its tests are also unit-suite programs, so they are migrated with the rest.

## User Scenarios & Testing *(mandatory)*

The users are the people and agents who write, run and review the game's tests: Jon, the agents
working through Spec Kit tasks, and upstream Oolite maintainers reviewing the fork.

### User Story 1 - Write a new test on Google Test (Priority: P1)

A developer adds a test program for a class. They write it with Google Test and add it to the
build like any other unit test. `tests/run.sh unit` builds and runs it with the existing
programs, and its result counts toward the suite's pass or fail.

**Why this priority**: Everything else depends on Google Test being available in the build. On
its own it lets every new test from then on start on the new framework, which stops the old
harness from growing.

**Independent Test**: Add one Google Test program with one passing and one deliberately failing
case. `tests/run.sh unit` exits nonzero and names the failing case. Remove the failing case and it
exits zero. All existing harness programs still run and pass in the same invocation.

**Acceptance Scenarios**:

1. **Given** a clean checkout and a build machine with the documented setup, **When** the
   developer runs the build and `tests/run.sh unit`, **Then** Google Test is obtained at a pinned
   version without manual steps, and the Google Test programs run alongside the old-harness
   programs.
2. **Given** a Google Test program with a failing case, **When** the unit suite runs, **Then** the
   suite fails and the output names the program, the case and the values that differed.
3. **Given** a machine with no network access but a populated dependency cache, **When** the
   developer builds, **Then** the build succeeds as it does today for QuickJS.
4. **Given** the Clang build and the GCC build, **When** both are built with the project's warning
   flags, **Then** neither reports a new warning and no warning has been silenced.

---

### User Story 2 - Diagnose and isolate a failure (Priority: P2)

A test fails. The developer sees the expected and actual values in the failure message, reruns
just that one case by name, and gets results a CI system or script can read without a custom
parser.

**Why this priority**: This is the day-to-day payoff of the change. It shortens every red-test
investigation, which is the loop the agents spend most time in.

**Independent Test**: In a Google Test program, break one equality check. The failure output shows
both values. Running the unit suite with a filter for that case runs only that case, and a
machine-readable report lists it as failed.

**Acceptance Scenarios**:

1. **Given** a failing equality or comparison check, **When** it fails, **Then** the message shows
   both operands' values (or a readable rendering of them) as well as the source expression.
2. **Given** a test program with many cases, **When** the developer asks the unit runner for one
   case by name or pattern, **Then** only matching cases run, and the runner reports how many ran.
3. **Given** a unit suite run, **When** it finishes, **Then** a per-case result report exists in a
   standard machine-readable format, alongside the existing console output.
4. **Given** a case that aborts or crashes, **When** the program dies, **Then** the output still
   identifies the case that was running.

---

### User Story 3 - Migrate the existing tests without losing coverage (Priority: P3)

The existing programs are converted to Google Test in reviewable batches (one suite or directory
at a time). Each batch keeps every test case and every check, and the batch is shown to do so by
a tool, not by a reviewer's reading.

**Why this priority**: Until the old tests move, the project keeps two harnesses and two ways of
reading failures. But each batch is mechanical and can be done after Stories 1 and 2 are in use.

**Independent Test**: Convert one directory (start with `oofnd`). A parity check compares the
batch before and after and exits zero only if every program has the same named cases and the same
check sites. The converted programs pass where the originals passed.

**Acceptance Scenarios**:

1. **Given** a program before and after conversion, **When** the parity check runs, **Then** it
   confirms the same set of case names and, per file, the same number of check sites, each still
   checking the same expression, and fails otherwise.
2. **Given** a program whose code uses a check's result as a value, **When** it is converted,
   **Then** the program still computes and uses that result the same way, and the parity check
   still counts the site.
3. **Given** a program that supplies its own `main` (set-up before tests, a custom argument), **When**
   it is converted, **Then** its set-up still runs before any case, once.
4. **Given** a converted program that passed before conversion, **When** it fails after
   conversion, **Then** the conversion is wrong. The batch stops and the failure is reported. The
   test's expectations are not changed to make it pass.
5. **Given** the `oofnd` programs, **When** they are built under the deployment (NDEBUG) settings,
   **Then** they build and pass as they do today.

---

### User Story 4 - Retire the bespoke harness (Priority: P4)

Once no program uses it, `oo_test.hpp` is removed. The docs and the agent contract show one way to
write a unit test, and a reviewer reading any unit test sees a framework they already know.

**Why this priority**: It finishes the change, but it has value only when Story 3 is complete.

**Independent Test**: A search of the tree for the old harness's include and macros finds nothing;
the unit suite passes; the exemplar table and testing docs point at a Google Test program.

**Acceptance Scenarios**:

1. **Given** every program is converted, **When** the old harness is deleted, **Then** the build
   and all unit suites pass.
2. **Given** an agent reading the agent contract or testing docs, **When** they look for how to write
   a unit test, **Then** they find a Google Test exemplar and no mention of the old harness as current.
3. **Given** a developer who adds a test using the old harness's macros after retirement, **When**
   they build, **Then** the build fails.

### Edge Cases

- **A program that registers no tests.** It must fail, as it does today. Google Test's default is
  to pass with zero tests; the project keeps the stricter behaviour.
- **Order-dependent cases.** Today cases in a program run in source order in one process, and
  some may depend on state left by earlier ones. Converted programs run cases in the same order by
  default; random ordering is off unless a developer asks for it.
- **Checks outside test bodies.** Many checks sit in helper functions and in the file-local wrapper
  macros. They must keep reporting against the case that called them.
- **Fatal versus non-fatal checks.** Every existing check is non-fatal: the case continues after a
  failure. Conversion keeps them non-fatal. A converted check never starts ending the case early.
- **Sanitizer runs.** Programs run under the sanitizers with the existing suppressions file and
  produce no new sanitizer reports.
- **Windows-only test code.** Converted programs stay Windows-only where the originals are, so that
  making the unit tests portable remains a separate change. Google Test itself must not be the
  thing that stops them building on macOS or Linux later.
- **Programs that capture stdout or stderr.** Some tests check log output. Google Test's own output
  must not get into what those tests capture, and the capture must not hide Google Test's failure
  messages.
- **Debug-console and timing tests.** Programs with timeouts keep their current meson timeouts;
  the framework's own start-up must not push a program over its limit.
- **Running only part of a suite.** A filter that matches nothing in a program is not a failure of
  that program.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The build MUST obtain Google Test at one pinned version through the project's existing
  dependency mechanism, with no manual install step. A build with a populated cache MUST work
  offline.
- **FR-002**: Google Test MUST build with both the Clang and GCC toolchains under the project's
  warning flags, without any warning suppression (no `-Wno-*`, no diagnostic pragmas, no attributes
  to quiet warnings). If it cannot, the work stops and reports which warnings, rather than
  suppressing them.
- **FR-003**: Google Test MUST NOT be linked into, or change, the shipped game. It is a test-only
  dependency.
- **FR-004**: A Google Test program MUST be added to the unit suites the same way an existing test
  program is. `tests/run.sh unit` and `meson test --suite <name>` MUST run it and count its result.
- **FR-005**: Programs on the old harness and on Google Test MUST be able to coexist in every suite
  until migration is complete.
- **FR-006**: A program that registers no test cases MUST exit with failure.
- **FR-007**: A failed equality or comparison check MUST report both operands' values, the source
  expression, the file and the line.
- **FR-008**: The unit runner MUST let a developer run a subset of cases by name or pattern, across
  one program or a whole suite.
- **FR-009**: Each unit run MUST be able to produce a per-case machine-readable result report in a
  standard format.
- **FR-010**: Cases within a program MUST run in source order by default.
- **FR-011**: A converted program MUST keep every test case name of the original and, per file,
  every check site, each checking the same expression with the same strictness. Non-fatal stays
  non-fatal.
- **FR-012**: A parity check MUST compare a batch before and after conversion and exit nonzero on
  any lost, added or changed case or check site. Each migration batch MUST pass it.
- **FR-013**: A converted program that fails where its original passed MUST stop its batch. Hard
  rule 1 applies: the expectation is never edited to make the program pass.
- **FR-014**: The deployment (NDEBUG) build of the `oofnd` suite MUST keep building and passing.
- **FR-015**: Tests MUST keep running under the existing sanitizer configuration with no new
  reports.
- **FR-016**: Migration MUST proceed in batches of one suite or directory, each its own reviewable
  commit series, in this order: `oofnd`, then `expander`, `sysdesc` and the QuickJS engine test,
  then `core` (split by subdirectory or class family), then `scenario` if spec 003 has added it.
- **FR-017**: When no program uses the old harness, it MUST be removed. After removal, a use of its
  macros MUST fail the build.
- **FR-018**: The agent contract's exemplar table, the testing docs (`docs/current-state.md`,
  `docs/workflow.md`) and the header comments that describe the old harness MUST describe Google
  Test as the way to write a unit test, once Story 1 is done. They MUST state that the old harness
  is being migrated away while Story 3 runs, and stop mentioning it after Story 4.
- **FR-019**: Specs and plans already written (notably spec 003) that name the old harness MUST
  get a one-line note pointing at this spec. Their requirements are not rewritten.

### Key Entities

- **Test program**: one executable built from one test source file, in one suite. It has named
  cases and runs them all, or a filtered subset.
- **Test case**: a named unit of checks within a program. Its name survives migration unchanged
  so results can be compared before and after.
- **Check site**: one place in source that asserts something. It is fatal or non-fatal and has an
  expression. The parity check counts these per file.
- **Migration batch**: a set of programs converted together. It has a before and after parity
  report and passes or stops.
- **Result report**: the per-case machine-readable output of a unit run.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After migration, the number of test cases and check sites in the unit suites equals
  the number before migration (about 1,800 cases, about 11,000 sites), confirmed by the parity
  check, with zero cases lost.
- **SC-002**: Every program that passed before migration passes after it, on both Clang and GCC
  builds and under the sanitizers.
- **SC-003**: From an already-built tree, a developer reruns exactly one named failing case with one
  command, and no other case in its program runs. Today the whole program reruns.
- **SC-004**: 100% of failed equality checks in converted programs show the differing values.
- **SC-005**: A clean build of all unit-test programs takes no more than 15% longer than before
  adoption, and a full `tests/run.sh unit` run takes no more than 10% longer, measured on the same
  machine with the same toolchain.
- **SC-006**: After Story 4, a search of `oolite-dev` for the old harness's header and macros
  returns zero matches outside git history.
- **SC-007**: The shipped game binary is the same with and without the test dependency present
  (no new linked library, no change in what is installed).

## Assumptions

- **Scope.** The whole of `oolite-dev/tests/unit`, including any `scenario` suite spec 003 adds
  before migration reaches it. Component (Gherkin), GUI (PyAutoGUI) and smoke tests are Python and
  out of scope.
- **Google Test only; no rewriting of test doubles.** The project's hand-written stand-ins and test
  doubles stay as they are. Google Mock comes with Google Test and may be used by new tests, but
  existing doubles are not converted to it.
- **Platforms.** The unit suites stay Windows-only, as today. Making them portable belongs to
  Phase 5. This feature only ensures Google Test is not an obstacle: the pinned version must
  support Windows (MSYS2 UCRT64, Clang and GCC), macOS on Apple Silicon and Linux x64.
- **Language level.** The pinned Google Test version supports the project's current C++20 and the
  planned C++23 move (Phase 6).
- **Distribution.** Google Test comes in through the same dependency mechanism as QuickJS-ng (a
  pinned, cached package), not vendored into `src/`. It ships no runtime code with the game, so the
  game's licence picture is unchanged. Its BSD-3-Clause licence goes in the dependency's own
  record.
- **Relation to the migration phases.** This is separate work, like spec 003. It branches from
  `develop` on its own feature branch and is not part of the faithful-port upstream series
  (`series/*`, `seriesb/*`). It is offered upstream as its own small series after the faithful
  port, in this order: Story 1 (dependency and one example), then each migration batch, then
  retirement. *Superseded (Jon, 2026-11-12): the work is one branch and one PR, the second of two
  phases after the third-party wraps spec; see the plan's Branch phases.*
- **Ordering with spec 003.** Neither blocks the other. If spec 003's scenario suite lands first,
  it is migrated as the last batch. If this feature's Story 1 lands first, new scenario tests are
  written on Google Test, and spec 003's note (FR-019) says so.
- **Conversion is mechanical.** Batches are converted by a script where possible, with hand edits
  only for the custom `main`s, the 19 value-returning sites and the file-local wrapper macros. The
  plan chooses how.

### Decisions taken by default

Hard rule 8 applies: no question was left open. These defaults are recorded with their reasons.
Jon can override any of them.

- **Migrate everything, then retire the old harness** rather than freeze it for old tests. Two
  harnesses would mean two failure formats and two exemplars for agents, indefinitely. The
  migration is mechanical and parity-checked, so its risk is low.
- **Keep the zero-tests-fails rule** although Google Test passes such programs by default. The
  current behaviour caught mis-registered suites and is the more conservative one.
- **Keep every check non-fatal.** Converting some to fatal assertions would change what a failing
  run reports, which is a change to the tests (hard rule 1).
- **Keep source order; no shuffling by default.** Hidden order dependencies are a real possibility
  in tests that share process-wide game state, and exposing them is not this feature's job.
- **Build-time budget of 15%.** About 215 programs each linking the framework is the main cost. The
  number is a conservative ceiling; if it is exceeded, the plan must address it (for example, a
  shared prebuilt framework library) before migrating `core`.
