# Feature Specification: Adopt cpplint

**Feature Branch**: `005-adopt-cpplint`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "Create a plan for adopting Google's cpplint into this project. The
objective would be to improve code quality."

## Purpose

**The goal is code quality that holds over time.** cpplint is Google's style checker for C++. It
finds things the compiler, clang-format and clang-tidy don't: headers that use `std::string`
without including `<string>`, constructors that convert implicitly, calls to functions that are
not thread-safe (`localtime`, `strtok`), files with no licence notice, and style that breaks the
Google guide the project already follows.

The adoption must stop the code getting worse from the first day, and then make it better one
category at a time. It must never fight the tools the project already uses, and it must not break
Phase 4p's promise to upstream that the C++ fork can still be compared with upstream line by
line.

## Context

The game already follows Google style in part. A survey of `oolite-dev` on 2026-11-02 found:

- **clang-format** with `BasedOnStyle: Google` (`.clang-format`). `./mk.sh format` and
  `./mk.sh format-check` run it, and so does the `clang-format-check` CI job, which every build
  job depends on. It owns layout.
- **clang-tidy** (`.clang-tidy`) with the bugprone, performance and some modernize and readability
  checks. Its `WarningsAsErrors` list is a ratchet: a check fails a run only once its findings
  have been cleared. This feature copies that idea.
- **No cpplint.** Nothing in the tree runs it or configures it.

A baseline run of cpplint 2.0.2, with its default settings, over the 522 game source files that
git tracks under `src/` (`*.h`, `*.hpp`, `*.cpp`; there are no `*.c` files) took 24 s. MiniZip
and `stb_image_write.h` were left out. The run reported **9,461 findings in 36 categories, in
456 files**:

- **About 5,400 are in code the project doesn't write by hand.** Three generated tables
  (`OOEntityCalledByNameTable.h`, `OOJSCallEntityMethods.h`, `OOTypeEncodings.h`, each written by
  a `tools/gen-*.py` script whose `--check` mode keeps it in sync) account for about 4,900. The
  vendored `src/SDL/EXRSnapshotSupport/miniz.*` and `tinyexr.h` account for the rest.
- **About 4,050 are in hand-written code.** The largest categories are `readability/casting` 712
  (C-style casts), `whitespace/braces` 703, `build/include_what_you_use` 683, `whitespace/tab`
  418, `readability/braces` 379, `runtime/int` 357 (`long`, `short`), `whitespace/comments` 180,
  `legal/copyright` 155 and `whitespace/indent_namespace` 151. Twenty-six smaller categories hold
  the remaining few hundred: `runtime/explicit` 40, `runtime/threadsafe_fn` 18,
  `build/header_guard` 5, and others.

Some of these findings are real defects or hygiene gaps. Some are style rules that conflict with
clang-format's output (clang-format already passes in CI, so any layout finding in formatted code
is a disagreement between the two tools). And some are style rewrites that touch hundreds of
lines, which Phase 4p puts off until Phase 6.

## User Scenarios & Testing *(mandatory)*

The users are the people who change and review the game code: Jon, agents working on beads, and
the upstream Oolite maintainers.

### User Story 1 - A developer can lint the game's own code with one command (Priority: P1)

A developer runs one command from `oolite-dev` and gets cpplint's findings for every hand-written
source file, in the usual `file:line: message [category]` form. Every run uses the same pinned
cpplint version and one checked-in configuration. That configuration leaves out generated and
vendored files, treats `.hpp` as a header, and matches clang-format's line length. It turns off
each category that contradicts clang-format or the project's chosen conventions, and records why
next to it. If cpplint is not installed, the command says how to install it and exits nonzero.

**Why this priority**: Nothing else can be measured until everyone gets the same report.

**Independent Test**: Run the command on the current tree. It prints findings only for
hand-written files and exits zero (reporting is not gating). Run it with cpplint missing from the
path; it exits nonzero and prints the install hint.

**Acceptance Scenarios**:

1. **Given** the current tree, **When** the lint command runs, **Then** no finding names a
   generated table, MiniZip, `stb_image_write.h` or the EXR snapshot's vendored files.
2. **Given** a tree just formatted by `./mk.sh format`, **When** the lint command runs, **Then**
   it reports no finding in any category the configuration marks as owned by clang-format.
3. **Given** a newly added source file under `src/`, **When** the lint command runs, **Then**
   that file is checked without anyone editing a file list.
4. **Given** a machine without the pinned cpplint, **When** the command runs, **Then** it exits
   nonzero with a message naming the version and how to install it.

---

### User Story 2 - A change that adds a finding fails the gate (Priority: P1)

A checked-in baseline records how many findings each hand-written file has in each enabled
category. The gate compares a run with the baseline. It fails when any file has more findings in a
category than its baseline allows. It also fails when a file has fewer, until the baseline is
lowered to match, so a cleared finding can't quietly come back. A category whose baseline is zero
everywhere is fully enforced. The gate runs locally (through `mk.sh` and `tests/run.sh`) and in CI
next to the clang-format check.

**Why this priority**: This is the part that improves quality over time. Without it, cpplint is
a report people stop reading.

**Independent Test**: In a scratch change, add an implicit single-argument constructor to a
header with no `runtime/explicit` findings; the gate exits nonzero and names the file, line and
category. Revert it, fix one existing finding without lowering the baseline; the gate exits
nonzero and says the baseline is stale. Lower the baseline; the gate exits zero.

**Acceptance Scenarios**:

1. **Given** the baseline matches the tree, **When** the gate runs, **Then** it exits zero.
2. **Given** a change that adds one finding in any enabled category, in any file, **When** the
   gate runs, **Then** it exits nonzero and names the file, line and category. This holds even
   when the same change fixes a finding of that category in another file.
3. **Given** a change that removes findings without updating the baseline, **When** the gate
   runs, **Then** it exits nonzero, naming the file and category whose baseline is now too high.
4. **Given** a file that is renamed or deleted, **When** the baseline still lists it under its
   old path, **Then** the gate exits nonzero until the baseline is updated.
5. **Given** a pull request to `develop`, **When** CI runs, **Then** the cpplint gate is a
   required job beside `clang-format-check`.

---

### User Story 3 - The categories that point at defects are cleared (Priority: P2)

Each enabled category is classified as one of three kinds, with a reason:

- **Fix now (Phase 4p).** Findings that point at a defect or a hygiene gap and need small,
  local edits. Examples: `runtime/explicit`, `runtime/threadsafe_fn`,
  `build/include_what_you_use`, `build/header_guard`, `build/include`, `legal/copyright`,
  `runtime/printf`, `runtime/string` and `build/namespaces`.
- **Deferred (Phase 6).** Style rewrites that touch hundreds of lines and would stop upstream
  comparing the fork line by line: `readability/casting` and `runtime/int`. They stay in the
  baseline, so they can't grow, and the Phase 6 doc lists them with their counts.
- **Off.** Categories that contradict clang-format's output, or a project convention that the
  configuration names (for example, the `TODO(name)` form). Each one has a reason in the
  configuration.

Each fix-now category is cleared in its own change, using the tool where possible, until its
baseline is zero. Each change passes the full unit suite and the warning gate.

**Why this priority**: This is where quality actually improves. It comes after Stories 1 and 2
because a cleared category is only worth something once the gate keeps it cleared.

**Independent Test**: For one fix-now category, the gate's baseline for it is zero everywhere,
`tests/run.sh unit` passes, and the build is clean at `-Wall -Wextra` on Clang and GCC.

**Acceptance Scenarios**:

1. **Given** the classification, **When** a reader looks up any enabled or disabled category,
   **Then** they find its kind and a one-line reason.
2. **Given** a fix-now category has been cleared, **When** the gate runs, **Then** that category
   is fully enforced and its baseline has no entries.
3. **Given** a change that clears a category, **When** the unit, component and smoke suites run,
   **Then** each gives the same result as on its parent.
4. **Given** the end of Phase 4p, **When** the phase exit gate is checked, **Then** every fix-now
   category has no findings.

---

### User Story 4 - Upstream maintainers can adopt or ignore it (Priority: P3)

An upstream maintainer can build, run and test the game without installing cpplint. Someone who
wants to lint can find in the developer docs how to run it, what the gate enforces, and how to
lower the baseline after a fix.

**Why this priority**: The fork is meant to be merged upstream. A new required tool would make
that harder.

**Independent Test**: On a machine without cpplint, `./mk.sh build test` succeeds. The docs name
the lint command, the gate command and the baseline-update command.

**Acceptance Scenarios**:

1. **Given** a machine without cpplint, **When** a developer builds and runs the unit suite,
   **Then** both succeed and neither mentions cpplint.
2. **Given** the developer docs, **When** a reader looks for how to lint, **Then** they find the
   three commands and the meaning of the three category kinds.

---

### Edge Cases

- **A different cpplint version** reports different findings. The gate checks the version and
  refuses to compare against the baseline with any other one. An upgrade is its own change that
  rebaselines.
- **Generated tables** are regenerated by their scripts. They are excluded from linting; their
  `--check` modes own them. If a generator is later made to produce lint-clean output, the
  exclusion for that file is removed.
- **Vendored code** (MiniZip, `stb_image_write.h`, the EXR snapshot's `miniz.*` and `tinyexr.h`)
  is never edited to satisfy cpplint. The exclusion list names these paths exactly. Code the
  project wrote itself in the same directory, such as `OOSaveEXRSnapshot.cpp`, is still linted.
- **A line that can't comply** in a fix-now category. Inline cpplint suppressions (`// NOLINT`,
  `// NOLINTNEXTLINE`) aren't added to hand-written code. If a category turns out to have a
  justified exception, the category moves to *deferred* or *off* with a recorded reason, and the
  gate goes on enforcing it everywhere else.
- **Existing clang-tidy `NOLINT` comments.** There are 12 in `src`, and each one names a
  clang-tidy check (for example `NOLINT(misc-use-internal-linkage)`). cpplint doesn't treat those
  as suppressing its own findings, so they are left alone. A bare `// NOLINT` would hide cpplint
  findings too, so it counts as a cpplint suppression under FR-012.
- **Line endings.** Windows checkouts may use CRLF. The gate gives the same result on a CRLF
  checkout and an LF checkout of the same commit.
- **Phase 5 platforms.** The command and gate behave the same on Windows (MSYS2 UCRT64), macOS
  and Linux, and need nothing beyond the pinned cpplint and the shell the build already uses.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST provide one command that runs cpplint over every git-tracked
  hand-written source file under `oolite-dev/src`, using the same file selection as
  `./mk.sh format` minus the exclusion list.
- **FR-002**: The project MUST pin one cpplint version and check it at run time. A mismatch MUST
  exit nonzero with the expected version.
- **FR-003**: All cpplint settings MUST live in one checked-in configuration. It sets the line
  length (matching clang-format's column limit), the header extensions, the exclusion list and
  the category filters. Each disabled category and each excluded path MUST carry a one-line
  reason.
- **FR-004**: Generated files (identified by their generator header) and vendored files MUST be
  excluded, by exact path.
- **FR-005**: Every category whose findings contradict clang-format's output MUST be disabled.
  After `./mk.sh format`, the lint command MUST report no finding in a category marked as owned by
  clang-format.
- **FR-006**: The project MUST keep a checked-in baseline of finding counts per file and per
  category, and a gate that fails when any count rises above, or falls below, its baseline.
- **FR-007**: The project MUST provide a command that rewrites the baseline from the current tree,
  for use after a fix. By default it MUST only lower counts: if any count would rise, it exits
  nonzero and names the files and categories. Raising counts MUST need an explicit option, meant
  only for a cpplint upgrade or a configuration change, and the command MUST print every count
  that rose.
- **FR-008**: The gate MUST run from `tests/run.sh` (as part of `unit`, or as its own suite that
  `all` includes) and as a CI job beside `clang-format-check`.
- **FR-009**: Each enabled category MUST be classified as *fix now*, *deferred* or *off*, with a
  reason, in the configuration or a document it points to.
- **FR-010**: Each fix-now category MUST be cleared to zero in its own change, and each change
  MUST pass `tests/run.sh unit` and be clean at `-Wall -Wextra` on Clang and GCC.
- **FR-011**: Deferred categories MUST be listed in the Phase 6 doc with their baseline counts.
- **FR-012**: No inline cpplint suppression comment MUST be added to hand-written code.
- **FR-013**: Building and running the game and its unit suite MUST NOT need cpplint.
- **FR-014**: The developer docs (`docs/workflow.md`, or the file it points to) MUST describe the
  lint, gate and baseline-update commands and the three category kinds.

### Key Entities

- **Configuration**: the single checked-in cpplint settings file: version, line length, header
  extensions, exclusions with reasons, category filters with reasons.
- **Category classification**: for each cpplint category, its kind (*fix now*, *deferred*,
  *off*), a reason, and for deferred categories the phase that takes them.
- **Baseline**: for each hand-written file and enabled category, the number of findings allowed.
  An absent entry means zero.
- **Exclusion list**: the exact paths of generated and vendored files, each with its reason.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The lint command and the gate each finish in under 60 s over the whole tree on the
  development machine (the default-settings baseline took 24 s for 522 files).
- **SC-002**: 100% of scratch changes that add a finding in an enabled category fail the gate. The
  test covers at least one category of each kind that is enabled.
- **SC-003**: At the end of Phase 4p every fix-now category has zero findings. Measured over the
  baseline categories named in Context, that clears at least the roughly 900 findings in
  `build/include_what_you_use`, `legal/copyright`, `runtime/explicit`, `runtime/threadsafe_fn`
  and `build/header_guard`.
- **SC-004**: The total finding count in the baseline never rises from one commit on `develop` to
  the next, except in a commit that upgrades cpplint or changes the configuration and says so.
- **SC-005**: Running `./mk.sh format` and then the lint command finds 0 findings in categories
  owned by clang-format.
- **SC-006**: 0 inline cpplint suppressions are added to hand-written code (checked by grep over
  the change).
- **SC-007**: A machine without cpplint builds the game and passes `tests/run.sh unit`.

## Assumptions

- **cpplint means the maintained fork** (`cpplint/cpplint` on PyPI, 2.0.2 at the time of the
  baseline), not the original `google/styleguide` script, which is no longer maintained. It
  accepts `#pragma once`, which 291 of the game's headers use.
- **Google style is already the target.** `.clang-format` is `BasedOnStyle: Google`. cpplint
  adds the checks clang-format can't make. It doesn't change the style, and where the two disagree
  on layout, clang-format wins.
- **cpplint is a developer tool, not a build dependency.** It is installed like the Python test
  tooling (`tests/` already needs Python), not through meson.
- **Scope is `oolite-dev/src`.** Tests, tools and the expansion-corpus tooling in this repo are
  out of scope for this feature. They can be added later with their own baseline.
- **Phase 4p's line-by-line promise holds.** Categories whose fixes would touch hundreds of lines
  across the tree (casts, integer types) are deferred to Phase 6, and are only kept from growing
  here.
- **The ratchet copies `.clang-tidy`'s WarningsAsErrors approach**: a check becomes an error once
  it's clean. The per-file baseline is stricter, because it also stops findings moving between
  files.

## Notes — decisions taken without Jon

Each is the conservative default; Jon may override any of them.

1. **Per-file baseline, not per-category totals.** A per-category total would let a fix in one
   file pay for a new finding in another. The per-file form fails on both, like spec 003's
   inventory check does.
2. **No inline suppressions.** Hard rule 2 bans silencing compiler warnings. The nearest
   equivalent for a linter is a per-line `NOLINT`, so this spec bans that too. Category-level
   choices in the configuration are allowed, because each one is a single reviewed decision with a
   reason, not a scattered exception.
3. **Casts and integer types are deferred to Phase 6.** Phase 4p rules out mechanical
   modernisation sweeps (`docs/phases/4p-upstream-polish.md`, "Out of scope"). `readability/casting`
   (712) and `runtime/int` (357) are exactly those sweeps.
4. **`readability/braces`, `whitespace/comments`, `whitespace/indent_namespace` and
   `whitespace/tab` are left for the plan to classify.** It runs the configured cpplint on a freshly
   formatted tree and decides from the result. If clang-format already enforces the rule, or
   contradicts it, the category is *off*. If the fixes are small and local, it is *fix now*. If
   they would touch hundreds of lines, it is *deferred*.
5. **This work belongs to Phase 4p, work item 5 (Tooling).** The plan adds it to that item and
   adds the "fix-now categories at zero" line to the phase exit gate.
