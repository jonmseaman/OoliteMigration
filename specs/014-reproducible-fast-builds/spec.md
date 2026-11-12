# Feature Specification: Reproducible, fast builds

**Feature Branch**: `014-reproducible-fast-builds` (game work on `feature/reproducible-fast-builds`
in `oolite-dev`, cut from `develop`)

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description: "Make sure builds are reproducible and maximum speed.
https://stackoverflow.com/questions/47714284/how-do-i-speed-up-meson-build-when-many-targets-use-the-same-c-sources
I believe some of the sources do use date/time in the build, which would slow things down.
Investigate and make a plan to fix." Follow-ups from Jon in the same session: "I would like to
know the build speed difference with/without date-time in the builds. Also, if I instead always
build dev instead, I could turn off optimization for dev to save time. I often build the
deployment version." And: "There are other builds happening on this machine, so it might be
better to just count the differences in total number of compilations before/after."

## Purpose

The same commit, built twice, should give the same bytes. A build should do only the work its
changes require: a new commit should not recompile the game, a source should be compiled once per
flavour, and a build with nothing to do should do nothing. Today none of these holds, and the
biggest cost is not a date in the source but the version and commit date on every compile line.

## Context

The numbers and how they were taken are in [baseline/counts.md](baseline/counts.md); the scripts
are next to it. They were counted on a throwaway worktree of `develop` (3aa8d65e8) by configuring
each flavour twice with different versions and walking the build graph. The method predicts the
230 recompiles a real build measured.

### Where date and time come in

- **No source uses the compiler's date or time.** Nothing in `src/`, `tests/`, `tools/` or
  `subprojects/` uses `__DATE__`, `__TIME__` or `__TIMESTAMP__`.
- **The version and the commit date are on every compile line.** On `develop`, `meson.build`
  passes `OO_VERSION_FULL`, `OO_BUILD_DATE` and `OO_BUILDER` to every compile with
  `add_project_arguments`. `OO_BUILD_DATE` is the last commit's date, not the wall clock, so a new
  day changes nothing, but every new commit changes the version and, on most days, the date. A
  changed command line reruns the compile and misses any compiler cache. So **every commit
  recompiles 230 of the deployment build's 240 objects, and 796 of 806 in test and dev, where it
  also relinks all 214 test executables.**
- **A fix exists, off `develop`.** `oolite-dev` commit fa5e7e7e6 moves the three values into a
  generated header, `OOVersion.h`, included by five files. With it, a commit reruns 5 compiles in
  every flavour, but still relinks 66 core test executables in test and dev. Two of the five are
  `PlayerEntity.cpp` and `Universe.cpp`, the game's two slowest compiles (17.4 s and 15.1 s). The
  fix, and fa5e7e7e6's companion 56fa88a55 (ccache on by default when installed), are on
  `feature/double-wide-support` and `seriesb/026-migration-completion`, not on `develop`.
- **Wall-clock time does reach the outputs**, after compiling: each `oolite.exe` carries its link
  time in its PE header, `strip` stamps the copy it strips again, and every documentation PDF
  carries the build's time to the second. None of these slows the build. They stop two builds of
  one commit from matching.
- **The version is read only at configure time.** `get_version.sh` runs from `project()`, so a
  plain `meson compile` after a commit keeps the old version. `mk.sh build` hides this by
  reconfiguring on every run (17–20 s in Jon's logs). Each configure starts a PowerShell
  process to find its own parent (0.35–0.65 s), and `gitversion` after a new commit (2.7 s).

### The Stack Overflow case: one source, many targets

`src/oofnd/meson.build` hands `Exception.cpp` and `objc/OOAssert.cpp` to consumers as the
`sources:` of `oofnd_objc_dep`. Meson compiles a dependency's sources into every target that uses
it. So in test and dev each file is compiled 177 times: once for the game, once per test
executable. That is **352 of the 806 compiles**. The core unit tests already reuse the game's own
objects through `extract_objects`, so the rest of the game is compiled once.

### Other costs found

- **Unit-test links in the LTO flavours.** The test flavour builds with ThinLTO. Each of the 174
  core test executables links the game's objects, which are LLVM bitcode, so each link runs
  ThinLTO code generation over them again. Jon's logs put these links at about 90 s each (wall
  time on a busy machine). The game's own link (deployment 17–29 s) is the only one with a ThinLTO
  cache.
- **The bundle step.** After every game link, `post_build.sh` deletes and rebuilds every
  documentation PDF, strips the binary, walks its DLLs with `ldd` and copies resources (1–16 s per
  run in the logs). Its only declared output is a stamp file. So a change under `Resources/` or
  `Documentation/` does not reach the bundle until the game relinks. Its documentation goes to
  `build/documentation` in the source tree, which every flavour shares.
- **Header parsing.** Every game source preprocesses to 200,000–250,000 lines. `OOColor.cpp`
  spends 1.8 s of its 2.2 s compile parsing headers, and `PlayerEntity.cpp` 3.0 s of 10.4 s.

### What each everyday build reruns

| Change | deployment | dev | test |
|---|---|---|---|
| New commit (`develop`) | 230 compiles, LTO game link, bundle | 796 compiles, 214 test links, game link, bundle | as dev, every link LTO |
| New commit (fa5e7e7e6) | 5 compiles, LTO game link, bundle | 5 compiles, 66 test links, game link, bundle | as dev, every link LTO |
| Edit `OOColor.cpp` | 1 compile, LTO game link, bundle | 1 compile, 84 test links, game link, bundle | as dev, every link LTO |
| Edit `Universe.cpp` | 1 compile, LTO game link, bundle | 1 compile, 66 test links, game link, bundle | as dev, every link LTO |

### Optimisation level for dev

Jon asked whether building dev at `-O0` would save time. Measured on one compile at a time, `-O0`
saves 10% (`OOColor.cpp`) to 61% (`PlayerEntity.cpp`) of a compile's CPU time. The project pins
`-O2` on purpose: the top-level `meson.build` says a float result recorded at one optimisation
level is not comparable to a run at another. The debug flavour already builds at `-O0`. Dev's
extra cost over deployment is mostly not optimisation: its full build runs 566 more compiles
(unit tests, and the 352 copies above) and 214 more links. This feature removes most of that.
The default is in *Decisions taken by default*.

## User Scenarios & Testing *(mandatory)*

The users are the people and agents who build the game: Jon, who often builds deployment; the
agents running `./mk.sh build test` and the test suites; CI, which builds deployment, test and dev
on Windows and Linux; and packagers who need to know a binary came from a given commit.

### User Story 1 - A new commit doesn't recompile the game (Priority: P1)

Jon commits a change to one file, or switches to a branch a few commits away, and builds. Only the
changed sources recompile, plus at most one small unit that holds the version. The game relinks.
No unit-test executable relinks because the version changed.

**Why this priority**: It is what Jon suspected, and the biggest cost found: on `develop` every
commit recompiles 230 objects in deployment and 796 in test and dev.

**Independent Test**: Configure a flavour with one version and build it. Configure it with
another version and run the build tool's dry run, or `baseline/graph.py`: it lists at most one
compile, the game's link and the bundle step.

**Acceptance Scenarios**:

1. **Given** a built deployment tree, **When** the version and commit date change and nothing
   else does, **Then** the build runs at most one compile, the game link and the bundle step.
2. **Given** a built test or dev tree, **When** the version changes, **Then** the build runs at
   most one compile, the game link and the bundle step, and no unit-test link.
3. **Given** a commit, **When** the game is built with `mk.sh` or with the build tool directly,
   **Then** the game shows that commit's version and date, without a manual reconfigure.

---

### User Story 2 - The same commit gives the same bytes (Priority: P1)

A packager builds a commit's deployment bundle on Monday in one directory, and again on Tuesday in
another. Every file in the two bundles is byte-identical: the executable, the DLLs copied beside
it, the manifest, the resources and the PDFs.

**Why this priority**: It is half of what Jon asked for. It also lets anyone check a published
binary against its commit, and it keeps compiler-cache hits honest.

**Independent Test**: A check script builds a flavour twice from one commit, in two directories,
with the clock moved on between them. It compares the two bundles file by file and exits nonzero
on any difference, naming the files. It fails on `develop` (PE header times, `strip` times, PDF
dates) and passes once the feature is in.

**Acceptance Scenarios**:

1. **Given** a clean checkout of one commit, **When** the deployment flavour is built twice at
   different times, **Then** the two bundles are byte-identical.
2. **Given** the same commit checked out in two different directories, **When** each builds the
   deployment, test and dev flavours, **Then** each flavour's bundles are byte-identical.
3. **Given** the GCC native file, **When** the deployment flavour is built twice, **Then** the
   bundles are byte-identical.
4. **Given** a source that uses the compiler's date or time macros, **When** the game is built,
   **Then** the build's warning gate fails and names the file.

---

### User Story 3 - Each source is compiled once (Priority: P2)

An agent runs `./mk.sh build test`. Each source file is compiled once for the flavour.
`Exception.cpp` and `OOAssert.cpp` are no longer compiled for every test executable.

**Why this priority**: It is the Stack Overflow case. It removes 352 of the 806 compiles in test
and dev, on every clean build and every compiler upgrade.

**Independent Test**: Count the compile steps in a configured test or dev tree (`graph.py`
reports the sources compiled more than once). No source appears twice unless its compiles use
different flags, and each of those is listed with its reason.

**Acceptance Scenarios**:

1. **Given** a configured test or dev tree, **When** its compile steps are counted, **Then**
   there are at most 456 (806 today), and `Exception.cpp` and `OOAssert.cpp` appear once each,
   or twice where game and tests need different flags.
2. **Given** the unit suites, **When** they run, **Then** the same tests pass as on `develop`.

---

### User Story 4 - Unit tests link quickly in the LTO flavours (Priority: P2)

An agent edits one game source and runs `./mk.sh build test`. The core test executables that
relink do not each run link-time code generation over the whole game.

**Why this priority**: These links are the largest cost in the test flavour (174 links, about 90 s
each in Jon's logs), and every agent session builds that flavour.

**Independent Test**: In a built test tree, touch one game source, rebuild, and measure the CPU
time of one whole-game core test link. Compare it with the same link before the change.

**Acceptance Scenarios**:

1. **Given** a built test tree, **When** one game source changes, **Then** each rerun core test
   link spends at most 5 s of CPU time, and the game's own link is still optimised as now.
2. **Given** the core unit tests, **When** they run in the test flavour, **Then** they still
   exercise the game's objects built with the flavour's compile flags, and the same tests pass as
   on `develop`.

---

### User Story 5 - Nothing to do means nothing done (Priority: P2)

Jon runs `./mk.sh build deployment` twice in a row. The second run does no compile, link, bundle
step or configure.

**Why this priority**: Every `mk.sh build` reconfigures today, which costs seconds and starts
PowerShell, and it hides the version going stale.

**Independent Test**: Build, then build again with no change. The second run's output reports no
build step, and the configure step does not run.

**Acceptance Scenarios**:

1. **Given** an up-to-date tree, **When** `./mk.sh build <flavour>` runs, **Then** no compile,
   link, bundle step or configure runs.
2. **Given** an up-to-date tree, **When** a build file such as a `meson.build` changes, **Then**
   the build reconfigures by itself, as it does today.

---

### User Story 6 - The bundle step does only what changed (Priority: P3)

Jon edits a source and builds. The game relinks, but no documentation PDF is rebuilt. He edits a
file under `Resources/` and builds: the bundle gets the new file without a compile or a link.

**Why this priority**: Rebuilding every PDF on every link is wasted time, and a resource edit that
never reaches the bundle is an incremental-build bug.

**Independent Test**: Touch a game source and rebuild: no PDF changes its time. Edit one resource
file and rebuild: the bundle's copy matches, and no compile or link ran.

**Acceptance Scenarios**:

1. **Given** a built tree, **When** a game source changes, **Then** no documentation PDF is
   rebuilt.
2. **Given** a built tree, **When** a documentation source changes, **Then** only the PDFs built
   from it are rebuilt.
3. **Given** a built tree, **When** a file under `Resources/` changes, **Then** the next build
   copies it into the bundle without a compile or link.
4. **Given** two flavours building at once, **When** both build documentation, **Then** neither
   writes into the other's output.

---

### User Story 7 - Less time parsing headers (Priority: P3)

A clean build spends less time parsing the same headers in every source.

**Why this priority**: Header parsing is most of a small file's compile, and it is paid 240 times
per flavour. The win has to be measured before it is taken.

**Independent Test**: Measure the total compile CPU time of a clean game build with and without a
precompiled header, compile by compile with `baseline/o0_vs_o2.py`'s method.

**Acceptance Scenarios**:

1. **Given** the measurement, **When** a precompiled header cuts the clean game build's compile
   CPU time by at least 25%, keeps the bundle reproducible and passes the same tests, **Then** it
   is adopted. Otherwise the plan records the numbers that ruled it out.

---

### Edge Cases

- **Uncommitted changes.** The version shows the dirty suffix as now, and the build date stays the
  last commit's. Reproducibility is claimed only for a clean tree.
- **No git, or a shallow clone.** CI checks out shallow, and a source tarball has no `.git`. The
  version falls back the way it does today, and the build still succeeds.
- **No `gitversion`.** It is required today when the commit has no exact tag. That does not change,
  but it runs at most once per commit.
- **Switching back to an earlier commit.** With the compiler cache, the objects come back from the
  cache. Only the version unit is new.
- **The debug flavour.** Its debug information names the build directory. Two debug builds in the
  same directory must match. Across directories, they must match unless the toolchain cannot map
  the paths, and the plan says which.
- **`deployment_unit_tests`.** The separate non-LTO build directory that tests oofnd under
  deployment macros keeps working.
- **GCC.** Its linker and `strip` stamp PE headers by their own rules, and both compilers must
  give reproducible bundles.
- **Linux and macOS.** ELF has no link time, but the PDFs and the version unit apply on every
  platform. CI's Linux builds must not regress. macOS is checked when a Mac is available.
- **A test that prints or checks the version.** A test executable gets a fixed version, so the
  version unit never makes it relink. If a test asserts the real version string, the plan
  reports it and stops (hard rule 1).
- **The compiler cache across checkouts.** Worktrees in different directories should share cache
  entries. Debug builds hash the working directory unless the cache is told the base directory.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The version, commit date and builder MUST reach the game through one translation
  unit that holds only those values. Every other unit gets them through a declaration, so a
  version change recompiles that one unit and nothing else. Today it recompiles 230 (deployment)
  or 796 (test, dev); with fa5e7e7e6, 5.
- **FR-002**: A version change MUST NOT relink any unit-test executable. Test executables link a
  fixed stand-in for the version unit, unless a test needs the real value (edge case above).
- **FR-003**: The version MUST be computed when the game is built, not only at configure time.
  The game shows the version and date of the commit it was built from, whether the build ran
  through `mk.sh` or the build tool directly. If the values have not changed, the version unit's
  source is left untouched, so it does not recompile.
- **FR-004**: The build date MUST stay the last commit's time, as now, and never the wall clock.
  Every other fixed timestamp the build writes (executable headers, PDFs) MUST come from that same
  commit time, or be zero where the format allows.
- **FR-005**: No compile command line MAY carry a value that changes per commit, per day or per
  checkout directory. A clean build of one commit in two directories MUST produce the same
  compile command lines, apart from paths the build tool itself makes absolute, each listed by
  the plan.
- **FR-006**: A use of `__DATE__`, `__TIME__` or `__TIMESTAMP__` in the project's own sources
  MUST fail the warning gate. This adds a diagnostic; it silences nothing (hard rule 2).
- **FR-007**: The Windows executables and DLLs the build makes MUST carry a fixed link timestamp
  (FR-004), from the link and again after `strip`, with Clang and with GCC.
- **FR-008**: Every documentation PDF MUST carry the fixed creation and modification time of
  FR-004.
- **FR-009**: Two builds of one clean commit, on one machine with one toolchain, at different
  times and in different checkout directories, MUST give byte-identical bundles. This holds for
  deployment, test and dev with Clang, and for deployment with GCC. The debug flavour is held to
  the edge case above.
- **FR-010**: A check MUST build a flavour twice in two directories and compare the bundles file
  by file. It exits nonzero and names each differing file. It fails on `develop` today and passes
  with the feature. The plan decides whether CI runs it.
- **FR-011**: Each source MUST be compiled once per flavour, unless two of its compiles need
  different flags. Those are listed with their reason. `Exception.cpp` and `OOAssert.cpp` stop
  being compiled into every consumer.
- **FR-012**: In the LTO flavours, a core test link MUST NOT run link-time code generation over
  the whole game once per executable. The game's own link stays LTO-optimised. The plan picks the
  means and states any change in what the core tests exercise.
- **FR-013**: When nothing has changed, `./mk.sh build <flavour>` MUST run no compile, link,
  bundle step or configure. The build still reconfigures itself when a build file changes.
- **FR-014**: The version script MUST NOT start a separate shell or process just to find out who
  called it. It MUST run `gitversion` at most once per commit and tree state, as its cache
  intends.
- **FR-015**: The bundle step MUST rebuild documentation only when documentation sources change.
  It MUST copy a changed resource on the next build without a compile or link, and MUST keep
  each build directory's documentation separate from every other's.
- **FR-016**: The compiler cache MUST be used by default when it is installed, and skipped
  cleanly when it is not, as in 56fa88a55. `--no-ccache` still turns it off. A clean rebuild of
  an already-built commit, including from a second checkout directory, MUST be served from the
  cache (SC-008).
- **FR-017**: The plan MUST measure a precompiled header for the game's sources (User Story 7). It
  is adopted only if it meets that story's bar, and the measurement is recorded either way.
- **FR-018**: The game's behaviour MUST NOT change. The unit, component and smoke suites that
  pass on `develop` pass on the branch. For the same commit, the version, build date and builder
  the game shows are the same text as on `develop`.
- **FR-019**: The flavours keep their meaning: deployment, test and dev stay at the pinned `-O2`,
  test and deployment keep LTO, and CI keeps calling `./mk.sh build <flavour>` (see *Decisions
  taken by default* on dev and `-O0`).
- **FR-020**: Changes under `tests/` MUST be build wiring only (`meson.build`, the stand-in
  version unit). No test source, assertion or expected value changes (hard rule 1). Each wiring
  change is listed in the plan.
- **FR-021**: `docs/current-state.md` MUST say how the version reaches the game, what is
  reproducible and with which check, and which paths stay in a bundle (the toolchain's own).

### Key Entities

- **Version stamp**: the version string, the commit date and the builder. It comes from git and
  `gitversion`, is cached per commit and tree state, and is shown in the log header, the window
  title, the watermark and `--version`.
- **Version unit**: the one translation unit that defines the version stamp for the game, with a
  fixed stand-in for test executables.
- **Flavour**: deployment, test, dev or debug. Each is one build directory with its own compile
  flags, LTO setting and set of targets.
- **Bundle**: `build/meson_<flavour>/oolite.app`, the game, its DLLs, resources, manifest and
  PDFs. It is what FR-009 compares.
- **Build step**: one compile, link, archive or custom command in the build graph. The counts in
  this spec are counts of these.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a version change, a built deployment tree reruns at most 1 compile (230 today),
  the game link and the bundle step. A built test or dev tree reruns at most 1 compile and 0
  unit-test links (796 compiles and 214 test links today).
- **SC-002**: A full test or dev build runs at most 456 compiles (806 today), and no source is
  compiled more than once without a listed reason.
- **SC-003**: The reproducibility check (FR-010) passes for deployment, test and dev with Clang,
  and for deployment with GCC: zero differing files between two builds made at different times
  in different directories. On `develop` it reports at least the executable and the PDFs.
- **SC-004**: A second `./mk.sh build <flavour>` with nothing changed runs 0 build steps and no
  configure.
- **SC-005**: After a new commit, the game's `--version` output and log header show that commit's
  version and date, whether it was built with `mk.sh` or with the build tool directly.
- **SC-006**: In the test flavour, a core test link after a one-source change takes at most 5 s of
  CPU time. The plan's first task measures the baseline, about 90 s of wall time in Jon's logs.
- **SC-007**: After a one-source change, no PDF is rebuilt. After a one-resource change, the
  bundle is updated with 0 compiles and 0 links.
- **SC-008**: With the compiler cache on, a clean rebuild of an already-built commit gets cache
  hits on at least 95% of its compiles, both in the same directory and in a second checkout.
- **SC-009**: Every unit, component and smoke test that passes on `develop` passes on the branch,
  and the Clang and GCC builds pass the warning gate.
- **SC-010**: A precompiled header is adopted with at least a 25% cut in a clean game build's
  compile CPU time, or the plan records the measurement that ruled it out.

## Assumptions

- The work is in `oolite-dev`'s build files: `meson.build`, `mk.sh`, `ShellScripts/common/*`,
  the `meson.build` files under `src/` and `tests/unit/`, and the five sources that print the
  version. These are upstream's build scripts, so changes stay small and upstreamable, and
  `./mk.sh build <flavour>` keeps its meaning for CI.
- The build-infrastructure reading of the checklist holds, as for specs 009, 011 and 013. The
  users are the people who build the game, and the build files, flavours and tools named here are
  the subject of the request, not implementation choices. The plan chooses the mechanisms.
- Counting build steps is the comparison that matters (Jon, 2026-11-12: the machine runs other
  builds). Times appear only as indicative, or as CPU time of one process (SC-006, SC-010).
- "One machine with one toolchain" includes where the toolchain is installed. The libstdc++
  assertion messages name the toolchain's own headers by absolute path, and those paths are part
  of the toolchain, not the build.
- Expansion content is not read and not needed (hard rule 4).

### Decisions taken by default

- **Dev stays at `-O2`.** Jon asked about building dev at `-O0`. Default: no. The pinned `-O2`
  exists so float results compare across builds, and the debug flavour already gives `-O0`.
  Measured, `-O0` saves 10–61% of a compile's CPU time. Dev's extra cost over deployment is
  mostly unit-test work this feature removes. After this feature, a one-source edit in dev costs
  1 compile, a non-LTO game link and the bundle step, plus its unit-test links. That should
  undercut deployment's LTO link (17–29 s). Jon can override: `-O0` for dev is a one-line change,
  at the cost of float results that no longer match deployment's.
- **No game-only dev option.** Dev keeps building the unit tests. A switch to skip them is easy
  to add later, if the counts after FR-011 and FR-012 still show the test links dominating.
- **One executable per core test.** Merging the 174 core tests into one runner would remove most
  links, but changes the test names that `tests/run.sh` and the logs use. It is not done.
- **Built on fa5e7e7e6 and 56fa88a55.** The branch takes those two commits first, then shrinks the
  version header to one unit (FR-001), so `feature/double-wide-support` merges into `develop`
  with the least conflict. Their `src/SDL/main.cpp` hunk conflicts with `develop` and is ported
  by hand.
- **Installers are out of scope.** The NSIS installer, AppImage, Flatpak and DMG are packaging
  steps after the bundle, with their own timestamps. A reproducible installer is a follow-up once
  the bundle is reproducible.
- **Reproducibility is claimed for clean trees.** A tree with uncommitted changes is not a commit,
  so its bundle is not expected to match anything.
- **`.specify/feature.json` is not repointed.** It names spec 012, which other sessions use, as
  spec 013 also left it. `/speckit-plan` for this feature must be given
  `specs/014-reproducible-fast-builds`.
