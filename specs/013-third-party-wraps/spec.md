# Feature Specification: Third-party code by wrap

**Feature Branch**: `013-third-party-wraps` (game work on `feature/third-party-wraps` in
`oolite-dev`, cut from `develop`; branch phase 1 of 2)

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description: "Take the third-party code out of oolite-dev/src/ (MiniZip, miniz,
tinyexr, stb_image_write) and bring it in through meson wraps the way QuickJS-ng already comes in.
Branch phase 1 of 2 (feature/third-party-wraps); spec 005 Google Test is phase 2. Spec only."

## Purpose

Anyone reading the game's source can tell what the project wrote and what it took from someone
else. Today `subprojects/` already holds external code the way meson intends: QuickJS-ng is a
pinned `.wrap`, its source is fetched by hash, and Oolite's changes to it are patch files a reader
can open. Four libraries don't follow that pattern. They are copied into `src/`, reformatted and
edited in place, and nothing records what was changed. This feature brings each of them in the way
QuickJS-ng comes in, with every local change that matters kept as a readable patch, and leaves the
game behaving as it does now.

## Context

What is in the tree today (measured in `oolite-dev` at the time of writing):

| Library | Where | Version held | Built for | Used by |
|---|---|---|---|---|
| MiniZip (Gilles Vollant, zlib licence) | `src/Core/MiniZip/` (`ioapi.cpp`, `unzip.cpp`, headers, `MiniZip64_info.txt`) | MiniZip 1.1 (2010) | every platform | `OOOXZManager`, `OODataFromOXZFile`, `ResourceManager`, `OOALSoundDecoder`; three `core` test programs compile its sources by path |
| miniz (MIT) | `src/SDL/EXRSnapshotSupport/miniz.cpp`, `miniz.h`, `LICENSE.miniz` | 3.0.2 (`MZ_VERSION "11.0.2"`) | Windows only | tinyexr (`#include <miniz.h>`, `mz_compress`, `mz_uncompress`) |
| tinyexr (BSD-3-Clause) | `src/SDL/EXRSnapshotSupport/tinyexr.h`, `LICENSE.tinyexr` | a 2024 release (header says 2014–2021; imported 2024-08-31) | Windows only (`OOSaveEXRSnapshot.cpp` includes it under `WIN32`) | EXR snapshots |
| stb_image_write (public domain / MIT) | `src/SDL/stb_image_write.h` | v1.16 | every platform | Radiance `.hdr` snapshots (`MyOpenGLView.cpp` defines the implementation) |

Other facts the spec relies on:

- **How the copies are built.** `src/Core/MiniZip/meson.build` and
  `src/SDL/EXRSnapshotSupport/meson.build` add the sources to the game's own source list; miniz is
  added only when the host is Windows. Both directories carry a `.clang-tidy` that turns every
  check off, and the root `.clang-tidy` excludes their headers and `stb_image_write.h`.
  `tests/check_debug_monitor_guards.py` lists the three paths as vendored.
- **How QuickJS-ng is brought in (the exemplar).** `subprojects/quickjs-ng.wrap` names a release
  tarball by hash with a WrapDB fallback URL and applies four tracked patches from
  `subprojects/packagefiles/`. `src/meson/meson.build` asks for it with `dependency()` and
  `default_options` that include `default_library=static`, so nothing new is installed beside the
  game. The top-level `meson.build` sets `force_fallback_for=quickjs-ng`. `.gitignore` ignores
  `subprojects/*/` except `packagefiles/`, and ignores `subprojects/packagecache/`.
- **Upstream.** OoliteProject keeps the same four libraries in the same places in `src/`, compiles
  miniz only on Windows the same way, and has neither `subprojects/` nor `deps/` (it dropped its
  `deps/` submodules in April 2026). Moving the copies is a deliberate divergence from upstream's
  layout.
- **Licences.** `LICENSE.md` is rendered to `License.pdf`, which the Windows installer ships. It
  carries the MiniZip and TinyEXR notices and a closing paragraph naming QuickJS-ng's wrap and
  patches. It has no entry for miniz (whose MIT licence asks for its notice in copies) or for stb.
- **Where WrapDB stands** (checked 2026-11-12): `miniz` has 3.0.2-1, 3.1.0-1 and 3.1.2-1; MiniZip
  is there only as `minizip-ng`, a different API; `stb` and `tinyexr` are absent; `zlib` has
  1.3.2-1. zlib's own release tarballs still carry `contrib/minizip` (checked at tag v1.4).

### The local edits, and what becomes of each

Every copy was changed after import. The edits fall into three kinds: real fixes, which come back
as patches; changes needed only because the file was compiled as C++ or reformatted, which go away
with the pristine source; and warning fixes, which come back only if the pristine source still
warns (FR-006).

| Library | Edit (commit) | Kind | Fate |
|---|---|---|---|
| MiniZip | `unzGetCurrentFileInfo`: `tmu_date` assignment ended with `,` (5de272321, 2017) | fix | already fixed in zlib's MiniZip: dropped |
| MiniZip | `ioapi.c`: map `fopen64`/`ftello64`/`fseeko64` on Apple (2ac832246, 2013) | fix | zlib's `ioapi.c` handles `__APPLE__` itself: dropped |
| MiniZip | `unzOpenCurrentFile3`: on an unsupported compression method, free the read state and return `UNZ_BADZIPFILE` instead of carrying on (96f39f346, 2013) | fix (behaviour) | zlib's code still sets the error and returns `UNZ_OK`: **kept as a patch** |
| MiniZip | dead `lSeek` stores commented out (96f39f346); redundant parentheses (2ac832246); `unz_copyright` made `static` with `__attribute__((used))` (fcd1d21f5); K&R `fill_fopen_filefunc` given a prototype (upstream 78578063b) | warning fix | dropped; a patch only if the pristine source warns. zlib's `fill_fopen_filefunc` already has a prototype |
| MiniZip | `.c`→`.cpp`, `extern "C"` removed, clang-format, `nullptr`, `#pragma once`, comment edits (2026-09 to 2026-11) | C++ / format | dropped: built as C from the pristine source, whose headers carry their own `extern "C"` guards |
| miniz | `#define MINGW_HAS_SECURE_API 1` before `#include "miniz.h"` (upstream's) | build fix | kept if WrapDB miniz needs it on MinGW (FR-005); the plan checks |
| miniz | tentative definition of `s_tdefl_num_probes` replaced by its definition (41dfc42ea) | C++ only | dropped: built as C |
| tinyexr | clang-format (upstream #749, fork cbf5cb96b) | format | dropped |
| stb_image_write | `stbiw__write_hdr_scanline`: clamp negative linear components to 0 before encoding, so HDR snapshots are right when gamut expansion is on (upstream 7e65cc156, ee8bc5ce2, 2024) | fix (behaviour) | **kept as a patch** |
| stb_image_write | `#pragma once` (07c5762ec), clang-format | C++ / format | dropped: stb has its own include guard |

### Open points from spec 005's research R2, now checked

- **tinyexr against miniz 3.x.** It already builds against it: the copied miniz is 3.0.2, and
  tinyexr includes it as `<miniz.h>` and calls only `mz_compress` and `mz_uncompress`.
- **zlib's MiniZip keeps the `unz*` API.** Every name the game uses (`unzOpen64`, `unzLocateFile`
  with an `int` case-sensitivity flag, `unzGetCurrentFileInfo64` with `unz_file_info64`,
  `unzGoToFirstFile`, `unzGoToNextFile`, `unzOpenCurrentFile`, `unzReadCurrentFile`,
  `unzCloseCurrentFile`, `unzClose`, `unzFile`) has the same signature in zlib's current
  `contrib/minizip/unzip.c`. The plan confirms this against the pinned tarball.
- **Expansion content.** None was read. The OXZ code paths are exercised by the existing unit
  tests and by test-made archives (hard rule 4).

## User Scenarios & Testing *(mandatory)*

The users are the people and agents who read, build and review the game: Jon, the agents working
through Spec Kit tasks, upstream maintainers reading the fork, and packagers building it.

### User Story 1 - Tell external code from the project's own (Priority: P1)

A reviewer opens `oolite-dev`. Everything the project did not write is in `subprojects/`: one
`.wrap` per library naming its origin and pinned version, and, next to it, the patches Oolite
applies, each saying what it changes and why. `src/` holds only Oolite's own code.

**Why this priority**: It is the point of the feature. Each library's local changes also stop being
invisible, which is the risk today.

**Independent Test**: List `src/` for the four libraries' files: none are found. For each library,
the `.wrap` names a source URL and hash (or a commit), and every patch it applies is a tracked file
in `subprojects/packagefiles/` with a header saying what it changes.

**Acceptance Scenarios**:

1. **Given** the feature branch, **When** a reviewer searches `src/` for MiniZip, miniz, tinyexr or
   stb_image_write sources or licence files, **Then** nothing is found.
2. **Given** any of the four libraries, **When** the reviewer opens its `.wrap`, **Then** it names
   where the source comes from, the exact version or commit, and the hash the build checks.
3. **Given** a real fix from the edit table (the MiniZip compression-method fix, the stb clamp),
   **When** the reviewer looks for it, **Then** it is a patch file under `packagefiles/` whose
   header gives its origin commit and reason.

---

### User Story 2 - Build and play exactly as before (Priority: P1)

A developer runs the usual build and tests. The libraries are fetched at their pinned versions with
no manual step, or taken from the local cache with no network, and the game does what it did:
OXZ archives open, sounds load from archives, `.hdr` and `.exr` snapshots come out the same.

**Why this priority**: The move must not change the shipped game. Without this story the first
is not worth having.

**Independent Test**: On Windows with Clang and with GCC, a clean `./mk.sh build test` passes with
no new warnings. A second clean setup with network access off and the sources in
`subprojects/packagecache/` passes too. A snapshot comparison (FR-011) passes.

**Acceptance Scenarios**:

1. **Given** a clean checkout and the documented setup, **When** the developer builds, **Then** all
   four libraries come in at their pinned versions without any manual install or download step.
2. **Given** a machine with no network access and the library sources in the package cache,
   **When** the developer sets up and builds with downloads forbidden, **Then** the build succeeds.
3. **Given** the Clang build and the GCC build, **When** each builds with the project's warning
   flags, **Then** neither reports a warning that the build on `develop` does not, and no warning
   has been silenced.
4. **Given** the unit, component and smoke suites, **When** they run on the feature branch, **Then**
   every one that passes on `develop` passes.
5. **Given** a fixed image written through the `.hdr` and `.exr` snapshot paths, **When** it is
   written by the `develop` build and by the feature branch, **Then** the files are byte-identical.
6. **Given** the Windows installer built from the branch, **When** its file list is compared with
   one built from `develop`, **Then** no new library file (DLL) is installed.

---

### User Story 3 - Licences and provenance still ship (Priority: P2)

A player or packager reads the licence document that ships with the game and finds every
third-party library compiled into it, with its notice, and a line saying where its source comes
from and that Oolite's changes are the patches in `subprojects/packagefiles/`.

**Why this priority**: The code is still in the binary, so its notices must still ship. One notice
(miniz) is missing today.

**Independent Test**: `LICENSE.md` has a notice for MiniZip, miniz, tinyexr and stb_image_write,
and its closing paragraph names each wrap. The rendered `License.pdf` in the Windows installer
contains them.

**Acceptance Scenarios**:

1. **Given** `LICENSE.md` on the branch, **When** it is searched for each library, **Then** each has
   its licence notice and the closing paragraph names its wrap and patches.
2. **Given** the installer build, **When** `License.pdf` is produced, **Then** it carries the same
   notices.

---

### User Story 4 - Phase 2 stacks cleanly (Priority: P3)

Spec 005 (Google Test) is cut from this branch's tip and adds its own `gtest.wrap`. It adds one
file to `subprojects/` and one entry to `force_fallback_for` without touching any line this feature
wrote.

**Why this priority**: It only matters to the next branch, but getting it wrong costs a merge
conflict in the two places both phases touch.

**Independent Test**: Adding `subprojects/gtest.wrap` and a `gtest` entry to the list, on top of
this branch, is a pure addition in the diff.

**Acceptance Scenarios**:

1. **Given** the branch tip, **When** phase 2 adds `gtest` to `force_fallback_for`, **Then** the
   diff adds one line and changes none.
2. **Given** the branch tip, **When** phase 2 adds `gtest.wrap`, **Then** no file this feature
   created is changed.

### Edge Cases

- **A pristine source warns.** zlib's MiniZip, built as C, may warn where the edited copy did not.
  The warning is fixed by a patch in `packagefiles/`, or the work stops and reports it. The warning
  level is never lowered and no flag, pragma or attribute is added to quiet it (FR-006).
- **A library's own suppressions.** tinyexr's header already contains its author's
  `#pragma clang diagnostic` lines, and QuickJS-ng's own `meson.build` passes `-Wno-*` flags. These
  are the library's, unchanged from today; the feature adds none of its own.
- **A system copy is found first.** A developer's machine may have a system miniz, MiniZip or stb
  (Homebrew and Debian package them). The build still uses the pinned, patched copy unless the
  developer opts out on the command line (FR-008).
- **No network and no cache.** Setup fails with meson's message naming the missing source; it does
  not fall back to anything unpinned.
- **The fixed-image comparison on a host without EXR.** EXR snapshots exist only on Windows, as
  today; on other hosts only the `.hdr` path is compared.
- **A future zlib wrap.** If a zlib wrap is ever added, its directory must not collide with the
  directory the MiniZip wrap extracts to. The plan picks names that cannot clash.
- **A library that can't come in by wrap.** It goes in a tracked `subprojects/<name>/` with its own
  `meson.build`, its licence file and a `README` naming origin, version and local changes, and
  `.gitignore` gets an exception for that directory (FR-010). None of the four is expected to need
  it.
- **Stale references to the old paths.** `tests/check_debug_monitor_guards.py` lists the old paths
  as vendored. Paths that no longer exist exclude nothing, so the check behaves the same; the file
  is not edited (hard rule 1). If the check fails because of the move, the work stops and reports.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: MiniZip, miniz, tinyexr and stb_image_write MUST leave `src/`: their sources,
  headers, info and licence files. Oolite's own code that uses them (`OOSaveEXRSnapshot.cpp` and
  the callers) stays where it is.
- **FR-002**: Each library MUST come in as one `.wrap` in `subprojects/` that pins an exact
  version or commit and checks the source's hash, following `quickjs-ng.wrap`:
  - miniz: WrapDB `miniz` 3.0.2-1, the version shipped today.
  - MiniZip: a custom wrap of a zlib release tarball (default 1.3.2) with a `packagefiles/`
    overlay that builds `contrib/minizip/ioapi.c` and `unzip.c` against the zlib dependency the game
    already uses, and declares the `minizip` dependency.
  - tinyexr: a custom wrap of the GitHub release tarball whose header matches today's copy, with an
    include-only overlay.
  - stb_image_write: a custom wrap of a GitHub archive of a pinned stb commit carrying v1.16, with an
    include-only overlay.
- **FR-003**: Every edit in the table above marked *kept as a patch* MUST be applied by the wrap as
  a tracked patch file in `subprojects/packagefiles/`, whose header names the origin commit and why
  the change is needed. No other local change MAY be carried, except the warning patches FR-006
  allows.
- **FR-004**: The sources MUST be built as the language their authors wrote them in (C for MiniZip
  and miniz). The fork's C++ conversions of these files are not carried over.
- **FR-005**: The miniz build MUST work under MSYS2 UCRT64 with Clang and GCC. If it needs
  `MINGW_HAS_SECURE_API`, that comes back as a patch or as a compile definition in the dependency
  request, recorded with its reason.
- **FR-006**: No warning MAY be silenced (hard rule 2): no `-Wno-*`, no diagnostic pragma, no
  unused-attribute, no lowered `warning_level` and no `is_system` include directory in anything
  this feature writes. Each overlay builds its library at no lower a warning level than the game's
  own sources build at today. A warning from a pristine source is fixed by a patch under FR-003's
  rules, or the work stops and names it.
- **FR-007**: Each library MUST be linked statically into the game, as today: no new shared
  library is built, installed or shipped.
- **FR-008**: The build MUST always use the pinned wrap for all four libraries by default, through
  the top-level `force_fallback_for` list, as for QuickJS-ng. The list MUST be written one entry
  per line so phase 2 can add `gtest` as a one-line addition. A developer who overrides the list on
  the command line gets an unpatched system copy and is not supported; the comment beside the list
  says so.
- **FR-009**: Platform conditions MUST stay as they are: miniz and tinyexr are requested only when
  the host is Windows; MiniZip and stb_image_write on every host.
- **FR-010**: If any library cannot come in by wrap, it MUST go in a tracked `subprojects/<name>/`
  with its own `meson.build`, licence file and a `README` naming its origin, version and local
  changes, with a matching `.gitignore` exception. The plan records why the wrap was not possible.
- **FR-011**: The game's behaviour MUST be unchanged: the unit, component and smoke suites that
  pass on `develop` pass, on Clang and GCC; and a new test writes a fixed image through the `.hdr`
  path (and on Windows the `.exr` path) and the output is byte-identical between `develop` and the
  branch. The OXZ paths are covered by the existing tests and test-made archives only.
- **FR-012**: With every library source present in `subprojects/packagecache/`, a clean setup with
  downloads forbidden (`--wrap-mode=nodownload`) MUST succeed. The quickstart gives the command
  that fills the cache.
- **FR-013**: `LICENSE.md` MUST carry a notice for each of the four libraries (adding miniz and
  stb_image_write, which are missing), and its closing paragraph MUST name each library's wrap and
  its patches the way it names QuickJS-ng's. `License.pdf` in the installer follows from it.
- **FR-014**: The build wiring under `tests/` that compiles MiniZip's sources by path
  (`tests/unit/core/meson.build`, three programs) MUST link the `minizip` dependency instead. No
  test source, assertion or test program list changes. Each edit to a file under `tests/` is listed
  in the feature's test-change ledger.
- **FR-015**: Tooling that names the old paths and is not a test MUST be updated: the root
  `.clang-tidy` exclusion stops naming paths that no longer exist, and `src/Core/MiniZip/.clang-tidy`
  goes with its directory. `src/SDL/EXRSnapshotSupport/.clang-tidy` stays, because Oolite's
  `OOSaveEXRSnapshot.cpp` stays in that directory and tidying it is out of scope.
- **FR-016**: The feature MUST NOT change the test framework or add a test framework dependency.
  `subprojects/` and `force_fallback_for` are left so that phase 2's `gtest.wrap` is a pure
  addition.
- **FR-017**: The directory MUST keep meson's name, `subprojects/`. It is not renamed to
  `third_party/`.
- **FR-018**: The docs that describe where external code lives MUST describe the wraps:
  `docs/current-state.md` in this repo (the *Source layout* row "`Core/MiniZip/`, other vendored
  C", and the sentence that the warning gate skips `src/Core/MiniZip/` and
  `src/SDL/stb_image_write.h`, which no longer exist, so the gate has no exceptions left), and any
  comment in `oolite-dev` that calls these files vendored. The patch headers are the record of
  local changes.

### Key Entities

- **Wrap**: one `.wrap` file. It names a library's source (URL or commit), its hash, an optional
  fallback URL, an overlay and patches, and the dependency it provides.
- **Overlay**: a `packagefiles/<name>/` directory with a `meson.build` for a library that ships
  none, applied over the extracted source.
- **Patch**: one tracked diff in `packagefiles/` with a header naming its origin commit and reason.
- **Local edit**: one change in the edit table. It is a fix, a C++/format change or a warning fix,
  and its fate is recorded.
- **Package cache**: `subprojects/packagecache/`, git-ignored, holding downloaded source archives
  for offline setup.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero third-party source, header or licence files remain under `oolite-dev/src/`
  (today: 11 files in three places).
- **SC-002**: Four new `.wrap` files, each with a pinned version or commit and a hash; every local
  change they apply is one of the two real fixes in the edit table, a MinGW build fix (FR-005) or a
  warning patch (FR-006), each with a header.
- **SC-003**: The Clang and GCC builds, including the four libraries' own compiles, report no
  warning that `develop` does not, with zero suppressions added: a search of the feature's added
  lines for `-Wno-`, `diagnostic`, `is_system`, `maybe_unused` and `__attribute__((unused))` finds
  none, and any `warning_level` it sets is no lower than the game's.
- **SC-004**: Every unit, component and smoke test that passes on `develop` passes on the branch,
  on both compilers.
- **SC-005**: The fixed-image snapshot outputs are byte-identical between `develop` and the branch.
- **SC-006**: A clean setup and build with downloads forbidden and a filled package cache succeeds.
- **SC-007**: The Windows installer's file list gains no library file, and `License.pdf` names all
  four libraries.
- **SC-008**: Phase 2's `gtest` entry and `gtest.wrap` apply on top of the branch as additions
  only.

## Assumptions

- **Scope.** The four libraries in `src/` only. System dependencies (SDL3, OpenAL, libpng, zlib,
  Vorbis, espeak-ng, libcurl, ICU) stay system dependencies. QuickJS-ng's wrap is not changed.
  `Documentation/docs/typst/vendor/cmarker` (documentation tooling, not compiled into the game) is
  out of scope.
- **Branch.** The game work is one branch, `feature/third-party-wraps`, cut from `develop` and sent
  as one PR that Jon merges. Spec 005's branch is cut from this branch's tip (spec 005's plan,
  *Branch phases*). The spec documents live on the planning repo's current branch.
- **Platforms.** The game builds on Windows today, and that is where the feature is verified. The
  wraps must not stop the macOS (Apple Silicon) and Linux builds that come next: each source chosen
  builds on all three, and zlib's MiniZip handles Apple's 64-bit I/O itself.
- **Upstream.** Upstream keeps these files in `src/`. The divergence is accepted: the fork already
  has `subprojects/` for QuickJS-ng, and a reviewer upstream sees one wrap per library instead of
  edited copies. Whether to offer the change upstream is not decided here.
- **Hard rule 7.** The task is about this code, so going back from the fork's C++ conversions to
  the pristine C sources is permitted.
- **Spec scripts that skip the old paths.** `specs/009-modern-cpp-std/check.sh` globs out
  `src/Core/MiniZip/**`, `src/SDL/EXRSnapshotSupport/**` and `stb_*`. Once the files are gone the
  globs match nothing and the script behaves the same; it is left alone.

### Decisions taken by default

Hard rule 8 applies: nothing was left open. Jon can override any of these.

- **One wrap per library** (research R2's default), not one combined "third-party" subproject: each
  has its own origin, version and licence.
- **miniz 3.0.2-1, not 3.1.2-1.** R2 named 3.1.2 as the newest in WrapDB. The shipped copy is 3.0.2
  and WrapDB carries it, so the move changes where miniz comes from without changing its version,
  and FR-011's byte-identical check stays meaningful. Moving to 3.1.2 is a one-line follow-up.
- **zlib 1.3.2 for MiniZip, not 1.4.** zlib 1.4 was released on 2026-11-04, eight days before this
  spec; 1.3.2 is the release WrapDB packages. Neither changes the `unz*` API. Moving to 1.4 is a
  later one-line change.
- **Same versions for tinyexr and stb.** The tinyexr tag and the stb commit are the ones whose
  files match today's copies apart from formatting and the edits in the table. The plan identifies
  them; if no tinyexr tag matches, the wrap pins the matching commit. No upgrade in this feature.
- **Keep the MiniZip compression-method fix as a patch.** zlib's code rejects such entries earlier
  in its header check, so the fix may be redundant, but it is a behaviour change made on purpose,
  and keeping it is the conservative choice.
- **Wrap always, not system first.** Two libraries carry behavioural patches that a system copy
  lacks; tinyexr and stb have no reliable system packages; and pinned versions on all three
  platforms keep builds reproducible. This matches QuickJS-ng.
- **Keep `subprojects/`.** Renaming it to `third_party/` through `subproject_dir` costs nothing
  against upstream, which has neither, but it moves QuickJS-ng's wrap and patches, breaks the
  `.gitignore` rules and spec 005's plan, and departs from the name meson's tooling and its users
  expect. A reader learns once that `subprojects/` is the external-code directory.
- **Fixed-image test is new.** No existing test writes a snapshot, so FR-011 adds one (adding a
  test is allowed). It runs the snapshot writers directly on a fixed buffer, not through the GUI.
- **Leave `tests/check_debug_monitor_guards.py` unchanged.** Its stale exclusions are harmless, and
  editing it is not needed for any test to pass.
- **`.specify/feature.json` not repointed.** It points at spec 012, which another session is
  writing; pointing it here would send that session's next Spec Kit command to the wrong spec. The
  plan step names this directory explicitly.
