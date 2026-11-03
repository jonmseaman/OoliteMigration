# Feature Specification: Performance tuning of the C++ conversion

**Feature Branch**: `006-cpp-performance-tuning`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "I would like to do performance tuning on the final c++ conversion of
this project to look for unecessary string copies or object copies or other areas where the
performance may have worsened after the objective c conversion. This specification should include
profiling and performance tests as well."

## Purpose

The C++ game should be at least as fast as the Objective-C game it replaced, and show it with
numbers. This feature measures the C++ build against the Objective-C build on the same machine,
uses profiling and a static scan to find where the conversion made things slower (unnecessary
string and object copies above all), fixes what matters, and adds a performance test tier so later
changes cannot quietly make it slower again.

## Context

What is known about performance today:

- **One measurement so far.** In Phase 4 a string benchmark compared `std::string` with a custom
  string type. The copy model chosen cost +0.1% of golden wall-clock time, inside a 5% threshold.
  Nothing has measured frame time, load time or memory of the finished C++ game against the
  Objective-C game.
- **Copies changed meaning in the conversion.** In Objective-C, `-copy` of an immutable `NSString`,
  `NSArray` or `NSDictionary` is a retain: it costs one counter increment. In the C++ code a
  `std::string` copy duplicates the characters, and an `oo::PList` copy duplicates the whole tree
  (`oofnd/PList.hpp` says so). Code that was cheap in Objective-C because it copied freely can be
  expensive now, with no visible change in the source.
- **Rough counts.** In `oolite-dev/src` headers, about 256 functions return a `PList`, `PList::Dict`
  or `PList::Array` by value and one returns a reference. About 100 local `PList` variables and 150
  local `std::string` variables are initialised by copy in `.cpp` files. A dozen `std::string`
  parameters and about 30 `PList`-family parameters are taken by value. Not every one is a
  problem: many are cold, small, or optimised away. These counts are a starting point, not
  findings.
- **Other places the conversion could cost time.** Reference counting through `oo::Ref` passed or
  copied where Objective-C used a plain pointer; `oo::AutoreleaseScope` pools; temporary strings
  made from literals at lookup sites; formatting log text that is then not shown; and conversions
  between JavaScript values and native strings at the script-engine façade. None of these is known
  to be slow; each is a hypothesis to measure.
- **Things that are not suspects.** `PList::Dict` already compares keys transparently, so a lookup
  with a literal does not build a temporary key. The `OOJS_PROFILE_*` macros compile to nothing (or
  a `try`) outside debug builds.
- **Fixed floating-point settings.** The build pins `-O2` and `-ffp-contract=off` so that
  simulation results are reproducible. Performance work keeps these settings.
- **Where the code is going.** The current phase (4p) keeps the converted classes in their
  Objective-C shape so upstream can compare them side by side; idiomatic rewrites are Phase 6.
  Spec 003 is building a headless, in-process game and scene for tests; Spec 005 adopts Google
  Test and a lint ratchet. The game builds only on Windows x64 today; macOS and Linux are Phase 5.

## User Scenarios & Testing *(mandatory)*

The users are Jon, the agents working through Spec Kit tasks, upstream Oolite maintainers deciding
whether to take the C++ port, and, at the end, the players whose frame rate and loading times this
work protects.

### User Story 1 - Measure the C++ game against the Objective-C game (Priority: P1)

A developer runs one command. It runs a fixed set of representative workloads on the C++ build,
and on the Objective-C build when asked, and writes a report: for each workload, how long it took,
how smooth the frames were, how much memory it used and how many allocations it made, side by
side with the Objective-C numbers and the difference between them.

**Why this priority**: Nothing else can be judged without it. It answers the user's question
("has performance worsened?") with numbers, and on its own it gives upstream maintainers evidence
that the port is not a regression.

**Independent Test**: Run the performance suite twice on the same build and machine. Both runs
complete, produce a report with every workload, and agree with each other within the stated noise
tolerance. Run it once against the Objective-C build and the report shows both builds with their
differences.

**Acceptance Scenarios**:

1. **Given** a built C++ game, **When** the developer runs the performance suite, **Then** every
   workload runs to completion without a person at the keyboard, and a human-readable report and a
   machine-readable result file are written.
2. **Given** an Objective-C build of upstream at the fork's base commit on the same machine, **When**
   the developer runs the suite in comparison mode, **Then** the report shows, per workload and
   metric, the Objective-C value, the C++ value and the percentage difference, and marks every
   metric where C++ is slower by more than the tolerance.
3. **Given** the same build measured five times in a row, **When** the runs are compared, **Then**
   each timed metric varies by no more than its stated tolerance, and allocation counts are
   identical.
4. **Given** a workload that crashes, hangs or fails to reach its end state, **When** the suite
   runs, **Then** that workload is reported as failed (not as fast), the other workloads still
   run, and the suite exits nonzero.

---

### User Story 2 - Find where the time and the copies go (Priority: P2)

A developer profiles any workload with one command and gets a report of where CPU time and
allocations are spent, by function and call path. A static scan lists the copy patterns in the
source (values copied where a reference or a move would do, containers grown one element at a
time, temporaries made in loops). The profile and the scan are combined into one ranked list of
findings, hottest first.

**Why this priority**: It turns a number ("C++ is 8% slower entering a system") into a place to
fix. It needs Story 1's workloads to profile.

**Independent Test**: Plant a deliberate deep copy of a large property list inside a function
called every frame. The profile of the busy-scene workload shows that function among the top
allocation sites, the static scan flags the line, and the ranked list puts it near the top.
Remove the plant and it disappears from all three.

**Acceptance Scenarios**:

1. **Given** any workload from the suite, **When** the developer profiles it, **Then** a report
   shows CPU time and allocation counts and bytes per function, with call paths, and names the
   source file and line where symbols allow.
2. **Given** the game source, **When** the static scan runs, **Then** it lists each copy pattern
   with file, line, pattern kind and a suggested change, and exits nonzero if it finds a pattern
   in a category the project has already brought to zero.
3. **Given** a profile and a scan, **When** findings are ranked, **Then** each finding records the
   workload and metric it affects, its measured or estimated share of that metric, and whether
   the same code existed in the Objective-C original (a conversion regression) or not
   (pre-existing).
4. **Given** the ranked findings, **When** they are triaged, **Then** every finding above the
   significance threshold is either scheduled for a fix or closed with a written reason.

---

### User Story 3 - Fix the regressions that matter (Priority: P3)

The findings that measurably slow a workload are fixed one at a time. Each fix shows a before and
after measurement of the workload it targets, changes no behaviour (every test tier stays green and
simulation results are identical), and keeps the converted code recognisable against the
Objective-C original unless a structural change is justified by its measurement.

**Why this priority**: This is where players gain, but only after Stories 1 and 2 show where to
work. Fixing by guesswork risks making the code harder to compare with upstream for no benefit.

**Independent Test**: Take the top finding. Before the fix, the targeted workload's metric is at
its recorded value and the matching performance check fails against the new, tighter budget. After
the fix, the metric is better by more than the noise tolerance, the check passes, and
`tests/run.sh all` passes on Clang and GCC.

**Acceptance Scenarios**:

1. **Given** a finding scheduled for a fix, **When** the fix is made, **Then** the commit records
   the workload, the metric before and after, and the number of runs measured.
2. **Given** a fix, **When** every existing test tier runs, **Then** all pass unchanged, and
   deterministic simulation output (fixed-seed state dumps, golden replays where blessed) is
   identical before and after.
3. **Given** a fix that does not improve its target metric beyond the noise tolerance, **When** it
   is measured, **Then** it is not kept, and the finding is closed as "not worth it" with the
   numbers.
4. **Given** a fix that would change a type's copying behaviour or a widely used interface (for
   example making property-list trees shared instead of copied), **When** it is proposed, **Then**
   it is recorded as a decision with its measurements and reviewed on its own, separate from local
   fixes such as passing by reference or moving instead of copying.

---

### User Story 4 - Keep it from getting slower again (Priority: P4)

The performance checks become a test tier. Allocation budgets, which do not vary between runs,
fail the tier the moment a change adds allocations to a measured workload. Timing checks run with
a tolerance and repeats so that noise does not fail them, and still catch a real slowdown.

**Why this priority**: Without a guard the gains from Story 3 erode with the next change. It
builds on the workloads from Story 1 and the budgets set while fixing in Story 3, but can start as
soon as Story 1 exists, with budgets at current values.

**Independent Test**: Plant one extra copy of a string inside a per-frame function. The
performance tier fails, naming the workload and the budget exceeded. Remove it and the tier passes.
Make an unrelated change that does not touch performance and the tier passes on five consecutive
runs.

**Acceptance Scenarios**:

1. **Given** a change that adds allocations to a measured workload, **When** the performance tier
   runs, **Then** it exits nonzero and reports the workload, the budget and the measured count.
2. **Given** a change that slows a timed workload beyond its tolerance, **When** the tier runs,
   **Then** it fails and reports the measured and the allowed values.
3. **Given** a fix that lowers a workload's allocation count or time, **When** the change is
   committed, **Then** the budget is lowered to the new value, so the gain cannot be given back
   unnoticed.
4. **Given** a budget that a change exceeds, **When** a developer or agent wants the tier to pass,
   **Then** they may not raise the budget; only Jon may, with a recorded reason.
5. **Given** the test runner, **When** a developer asks for the performance tier, **Then** it runs
   on its own, separately from the unit, component, smoke and GUI tiers.

### Edge Cases

- **Timing noise.** Background processes, CPU frequency scaling and thermal throttling move
  timings by several percent. Timed checks repeat, use medians and stated tolerances, and record
  the machine's state (power plan, core count, clock) with each result. Allocation counts are the
  primary gate because they do not depend on the machine's load.
- **Two toolchains, two standard libraries.** The Clang and GCC builds use different standard
  libraries, so their allocation counts differ. Each toolchain has its own budgets.
- **Per-machine timings.** Timings from one machine mean nothing on another. Timed baselines and
  budgets are kept per machine; a machine with no baseline records one on first run and gates
  nothing until it has one.
- **The GPU.** Frame time with rendering depends on the GPU and driver. Workloads report CPU-side
  simulation time separately from the time to render, so a driver change does not look like a code
  regression. Frame pacing and vsync are turned off for measurement.
- **The Objective-C baseline is hard to build.** The Objective-C game needs the old GNUstep
  toolchain on Windows. If it cannot be built on the measuring machine, the comparison uses the
  last Objective-C numbers recorded on that machine, and the report says so.
- **Not the same work.** Some differences are intended (QuickJS-ng instead of SpiderMonkey, the
  data cache written as XML) and make a workload do different work in each build. The report names
  these, so a difference caused by them is not filed as a copy regression.
- **Determinism.** Workloads use fixed seeds and fixed game data so that each run does the same
  work. A fix that changes simulation output, even slightly, is a behaviour change and is not
  accepted as a performance fix.
- **Sanitizer and debug builds.** Measurements are taken on the optimised build only. Sanitizer
  and debug builds still build and pass their tests but are not measured.
- **Expansions.** A workload that loads published expansions runs them through the existing corpus
  tooling. Agents do not read expansion content (hard rule 4); they only see timings and logs.
- **Memory.** A fix that trades time for memory (caching, pooling) must report peak memory before
  and after, and must not raise it beyond tolerance.
- **Cold code.** A copy in code that runs once at start-up or on a menu is not worth changing
  unless a workload shows it. The static scan reports it; triage closes it.

## Requirements *(mandatory)*

### Functional Requirements

**Measurement**

- **FR-001**: The project MUST have a performance suite of named, deterministic workloads that run
  without user input. At minimum:
  - start-up to the main menu, with and without a warm data cache;
  - loading a saved game and arriving at the main station;
  - a hyperspace jump into a populated system, through to the system being fully set up;
  - a busy scene in flight (many ships with AI, combat, missiles, a station) held for a fixed
    number of simulation ticks;
  - docking and opening the trade, equipment and shipyard screens;
  - start-up with the curated tier of published expansions loaded.
- **FR-002**: Each workload MUST report wall-clock time; per-frame CPU simulation time and render
  time (median, 95th and 99th percentile, worst); peak memory; and the number and total size of
  heap allocations, overall and per frame for the in-flight workloads.
- **FR-003**: The suite MUST write a human-readable report and a machine-readable result file per
  run. Each result MUST record the build (commit, toolchain, flags), the machine, and the run
  count.
- **FR-004**: The suite MUST be able to run the same workloads against an Objective-C build of
  upstream at the fork's base commit, on the same machine and at the same optimisation level, and
  report the difference per workload and metric.
- **FR-005**: The Objective-C baseline results MUST be recorded in the repository, per machine, so
  that the comparison can be repeated without rebuilding the Objective-C game.
- **FR-006**: Each timed metric MUST have a stated noise tolerance measured on the reference
  machine. Allocation counts MUST be identical between runs of the same build.
- **FR-007**: Workloads that can run in-process without a window MUST be able to use the headless
  game or scene from spec 003 once it exists. Until then they MUST run the real game, driven
  through the existing debug-console mechanism.

**Profiling and finding**

- **FR-008**: A developer MUST be able to profile any workload with one command and get CPU time
  and allocation counts and bytes per function, with call paths and source locations.
- **FR-009**: A static scan MUST report copy patterns in `oolite-dev/src`, excluding vendored C:
  values copied where a reference or a move would do (parameters, locals, loop variables, returns
  of stored members), strings and property lists built repeatedly in loops, and containers grown
  without reserving space when their size is known. Each report MUST give file, line, pattern kind
  and a suggested change.
- **FR-010**: Findings from profiling and the scan MUST be kept in one ranked list. Each finding
  MUST record the workload and metric it affects, its share of that metric, whether the
  Objective-C original had the same cost, and its status (open, scheduled, fixed, closed with a
  reason).
- **FR-011**: Every finding responsible for at least 1% of a workload's headline metric MUST be
  fixed or closed with a written reason before this feature is done.

**Fixing**

- **FR-012**: Each fix MUST be its own commit (or small series) that names its finding and records
  the targeted metric before and after, measured on the same machine with the stated run count.
- **FR-013**: A fix MUST improve its targeted metric by more than the noise tolerance, or it is
  not kept.
- **FR-014**: A fix MUST NOT change behaviour. Every test tier MUST pass unchanged, and fixed-seed
  simulation output MUST be byte-identical before and after. Hard rule 1 applies: no test is
  changed to make a fix pass.
- **FR-015**: A fix MUST NOT change the floating-point settings, the pinned optimisation level or
  the warning flags, and MUST NOT silence a warning (hard rule 2).
- **FR-016**: Local fixes (taking by reference, moving instead of copying, reserving space, hoisting
  a temporary out of a loop, avoiding work for log messages that are not shown) MUST keep the
  converted class recognisable against the Objective-C original. A structural change (changing a
  type's copy behaviour, sharing immutable data, string interning, changing a widely used
  interface) MUST be recorded as a decision with its measurements before it is made, and MUST be
  its own commit series.
- **FR-017**: A fix MUST NOT raise peak memory of any workload by more than its tolerance.

**Guarding**

- **FR-018**: The test runner MUST have a performance tier, run on its own (`tests/run.sh perf` or
  equivalent), and not part of the default `all` run until its run time and stability allow it.
- **FR-019**: The performance tier MUST fail when any workload exceeds its allocation budget, and
  when a timed metric exceeds its budget by more than its tolerance.
- **FR-020**: Budgets MUST be kept in the repository per toolchain (allocations) and per machine
  and toolchain (timings). When a change lowers a measured value, its budget MUST be lowered with
  it. A budget MUST NOT be raised to make the tier pass, except by Jon with a recorded reason.
- **FR-021**: The performance tier and the static scan MUST each have a self-test: a planted extra
  copy in a per-frame path makes the tier fail and the scan report it, as the existing tiers prove
  that they cannot pass vacuously.
- **FR-022**: The performance tooling MUST NOT be linked into, or change the behaviour of, the
  shipped game. Any counting or timing hook in the game MUST compile away in the release build, or
  be shown to cost less than the noise tolerance.
- **FR-023**: `docs/current-state.md` and `docs/workflow.md` MUST describe how to run the suite,
  profile a workload, read a report and update a budget. The final comparison against Objective-C
  MUST go into the Phase 4 write-up's results.

### Key Entities

- **Workload**: a named, deterministic piece of game activity (start-up, system entry, busy
  scene). It has a fixed seed, fixed inputs, a defined end state and the metrics it reports.
- **Measurement run**: one or more executions of a workload on one build and machine. It records
  the build, machine, run count and each metric's values.
- **Baseline**: the recorded results of a reference build (Objective-C upstream, or the C++ build
  before a fix) on a given machine, against which runs are compared.
- **Budget**: the allowed value of one metric for one workload, per toolchain (and per machine for
  timings), with its tolerance. It only moves down, except by Jon's decision.
- **Finding**: one place in the source that costs measurable time, memory or allocations. It links
  to its evidence (profile, scan line), its affected workload and metric, its share, whether it is
  a conversion regression, and its status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For every workload, the C++ game is no more than 5% slower than the Objective-C game
  on median frame time, 99th-percentile frame time and total time, measured on the same machine.
  Any workload over 5% has a recorded cause that is an intended difference (FR-010), not an
  unfixed copy regression.
- **SC-002**: The busy-scene workload makes no more heap allocations per simulated frame than the
  Objective-C game makes for the same scene, counted the same way in both builds, or the gap is
  explained by named findings closed with reasons.
- **SC-003**: Five consecutive runs of the suite on the same build give identical allocation counts
  and timed medians within 3% of each other on the reference machine.
- **SC-004**: A planted extra string or property-list copy in a per-frame path is caught by the
  performance tier in 100% of the self-test runs, and the tier passes on five consecutive runs of
  an unchanged build.
- **SC-005**: Every finding above the 1% significance threshold is fixed or closed with a reason;
  every kept fix shows an improvement beyond its tolerance in its commit message.
- **SC-006**: All existing test tiers pass on Clang and GCC after every fix, and fixed-seed
  simulation output is identical to the output before the feature started.
- **SC-007**: The performance tier runs in under 15 minutes on the reference machine, and its
  allocation-only subset in under 3 minutes, so that it can be run before every merge.
- **SC-008**: Start-up to the main menu and arrival in a new system are no slower for a player than
  in the Objective-C game, as shown by the comparison report included in the upstream write-up.

## Assumptions

- **Scope.** The game source in `oolite-dev/src`, including `oofnd` and the script-engine façade.
  The JavaScript engine itself (QuickJS-ng) and vendored C are measured but not changed; a hotspot
  inside them is recorded as a finding and closed, or passed upstream to that project.
- **Reference machine.** Jon's Windows x64 machine, in the MSYS2 UCRT64 environment the project
  already uses. Timed budgets are recorded there. macOS and Linux get their own baselines in Phase
  5; the tooling must not assume Windows where a portable choice exists.
- **The Objective-C baseline.** Upstream at the fork's base commit (`49a5eb9fc`), built with the
  upstream GNUstep toolchain on the reference machine at the same optimisation level. If that build
  cannot be made to work, the official upstream Windows build of the nearest release is used
  instead, and the report says so.
- **Allocation counts, not wall time, are the main gate.** They are deterministic, so they make a
  task verifiable by a command that exits nonzero before and zero after (the project's rule for
  every task). Timings are reported and gated with tolerance.
- **Which tools.** The plan chooses the profiler, the allocation counter and the static scanner.
  The static scan may be the `performance-*` family of checks in the clang-tidy configuration the
  current phase introduces, plus project-specific checks where those miss a pattern.
- **Relation to other specs.** Measurement (Stories 1, 2 and 4) does not depend on spec 003; it uses
  the headless scene when available. The performance tier's self-tests are written on the unit
  framework in use when they land (spec 005). The static scan and spec 005's lint ratchet use the
  same ratchet idea: a category at zero stays at zero.
- **Branching and upstream.** This is separate work, like specs 003 and 005: its own feature branch
  from `develop`, not part of the faithful-port series (`series/*`, `seriesb/*`). The measurement
  tooling and the comparison report can go upstream with the write-up. Fixes are offered as their
  own series after upstream has seen the faithful port, so reviewers can still compare each class
  with the Objective-C original.

### Decisions taken by default

Hard rule 8 applies: no question was left open. These defaults are recorded with their reasons.
Jon can override any of them.

- **Compare against Objective-C on the same machine, not only against the C++ build's own past.**
  The user's question is whether the conversion made things worse; only a side-by-side answers it.
  Recording the Objective-C numbers once (FR-005) keeps the old toolchain out of the daily loop.
- **5% as the comparison ceiling.** It is the threshold Phase 4 already used for the string
  decision, so the project has one number for "acceptably close". A workload over it needs a named
  reason.
- **1% as the significance threshold for findings.** Below that, a change is unlikely to be
  measurable above noise and costs diff size against upstream for no visible benefit.
- **Local fixes first, structural changes only with a recorded decision.** The current phase keeps
  classes in their Objective-C shape for upstream review. Passing by reference or moving keeps that
  shape; making `PList` share immutable trees, or interning strings, does not. The first can be
  done freely once measured; the second is decided on its numbers (FR-016).
- **Budgets only go down, and only Jon raises one.** This applies hard rule 1's spirit to
  performance: the check is not weakened to make a change pass.
- **The performance tier stays out of `tests/run.sh all` at first.** It needs a quiet machine and
  takes longer than the other tiers. It joins `all` (at least its allocation-only subset) once
  SC-003 and SC-007 hold.
- **Measure the optimised build only.** Debug and sanitizer builds distort timings and allocation
  patterns and are not what players run.
