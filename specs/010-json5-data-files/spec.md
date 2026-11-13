# Feature Specification: JSON5 data files beside property lists

**Feature Branch**: `seriesb/030-json5-data-files` (in `oolite-dev`; git town parent
`seriesb/027-modern-cpp` until `seriesb/029` exists, then that), which holds the three commits of
`feature/json5-data-files` (based on `seriesb/027-modern-cpp` at `b692feb4e`) and the core data
migration on top; spec directory `010-json5-data-files`

**Created**: 2026-11-12

**Status**: Implemented on `seriesb/030-json5-data-files`; awaiting Jon's review

**Input**: User description: "Is the plan for json5 ready for implementation? I would be good
with creating a worktree, implementing it, then I can review it later. Make sure to base the thing
off the most recent commits (modern c++ migration commits)"

Background: [Phase 5b](../../docs/phases/5b-data-formats.md) and the format comparison in
[notes/2026-11-07 Plist Replacement Format.md](../../notes/2026-11-07%20Plist%20Replacement%20Format.md).
This spec covers 5b.1–5b.3, the converter and, since 2026-11-13 at Jon's request ("add json5
support to this project (and convert most plist to json5)"), 5b.6: the core `Resources/` data files
are JSON5. That also gives 5b.4 for free: the component scenarios run over the converted tree,
because it is the shipped tree. 5b.5 (docs for expansion authors) is out of scope.

## Purpose

Expansion authors can write any data file the game loads as a property list as JSON5 instead,
under the same name with a `.json5` extension, with the same meaning and the same merge rules. A
converter turns existing plists into JSON5 and proves the result reads back the same. Plists keep
working unchanged. The core game's own data files are JSON5, except the three listed in D15.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The game reads JSON5 (Priority: P1)

`oo::parseJSON5PList` reads a JSON5 1.0.0 document into the same `oo::PList` tree the other readers
produce, and rejects anything else with a line and column.

**Independent test**: `tests/unit/oofnd/test_plist_json5.cpp` (suite `oofnd-plist`).

**Acceptance scenarios**:

1. **Given** `{a: 1, 'b': [true, 2.5, "x",], /* c */ c: {}}`, **When** parsed, **Then** the tree is
   a dict of integer 1, an array of bool, real and string, and an empty dict.
2. **Given** `{$data: "AAEC"}` or `{$date: "2001-01-01T00:00:00Z"}`, **Then** the value is data
   `00 01 02` or the reference date.
3. **Given** a syntax error on line 3, **Then** the error says "line 3" and the column.
4. **Given** nesting deeper than the limit, or `null`, **Then** the parse fails with a message, and
   nothing crashes.

### User Story 2 - A `.json5` file stands in for its `.plist` (Priority: P2)

Wherever the game loads `<name>.plist` from a directory or an OXZ, it reads `<name>.json5` from the
same place if there is one. If both are there, it reads the JSON5 one and logs a warning.

**Independent test**: `test_plist_json5.cpp` cases for `oo::loadPListFile` with a fake reader.

### User Story 3 - Converting a plist (Priority: P3)

`plist2json5 [--strings|--typed] [--check] <file-or-directory>...` writes `<name>.json5` beside each
`<name>.plist` (or, with `--check`, writes nothing and verifies). OpenStep input keeps its comments,
key order and layout; XML input is written from the node tree.

**Independent test**: `meson test --suite plist2json5` runs `--check` in both modes over every
`.plist` under `Resources/` and over small fixtures.

### User Story 4 - The core game's data is JSON5 (Priority: P4)

The files under `Resources/AIs`, `Resources/Config` and `Resources/Schemata` are `.json5`, written
by `plist2json5 --strings` from the plists they replace, with the same comments, key order and
layout. The game, its expansions and its scripts see the same data: names in code, in data and in
scripts stay `<name>.plist` (`nullAI.plist`, `hud.plist`), and the loader reads the `.json5`.

**Independent test**: `meson test --suite plist2json5` (`json5_resources_parse` reads every core
`.json5` with the game's reader); `tests/run.sh smoke` and `tests/run.sh component` run the game on
the converted data.

**Acceptance scenarios**:

1. **Given** a build of the converted tree, **When** the game starts, **Then** the log has no
   `plist.parse.failed` and no `plist.json5.shadowed` line, and matches the log of the plist build
   apart from the cache rebuild line.
2. **Given** `nullAI.plist` asked for by name, **When** only `AIs/nullAI.json5` exists, **Then**
   `ResourceManager::pathForFileNamed` answers the `.json5` path and the AI loads from it.
3. **Given** an old build directory holding `Config/shipdata.plist`, **When** the tree is rebuilt
   after the conversion, **Then** the build's copy of the plist is removed and its `.json5` is there.

### Edge Cases

- Keys that are not identifiers (`"0 0"`, `adder-player`) are quoted.
- A dict whose only key is `$data` or `$date` can't be written; the writer fails rather than
  producing a file that reads back differently.
- Repeated keys: the last wins, as in the OpenStep reader.
- Integers beyond `int64_t` up to `uint64_t` are unsigned integers; beyond that, reals.
- A string that isn't valid UTF-8 is an error; `\uD800` on its own is kept as WTF-8, as the
  OpenStep reader keeps lone surrogates.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** `src/oofnd/PListJSON5.hpp`: `parseJSON5PList(std::string_view) ->
  std::expected<PList, PListError>`, header-only like `PListOldStyle.hpp`.
- **FR-002** Mapping: object → dict, array → array, string → string, `true`/`false` → bool,
  integer literal (decimal or hex, no fraction or exponent) → integer, any other number (with `.`,
  an exponent, `Infinity`, `NaN`) → real. `null` is an error.
- **FR-003** `{"$data": "<base64>"}` → data; `{"$date": "<YYYY-MM-DDTHH:MM:SSZ>"}` → date. Only for
  an object with exactly that one key and a string value.
- **FR-004** Errors: `"JSON5 parse failed at line L, column C - <reason>"`, columns in bytes from 1.
- **FR-005** Depth limit 512 nested arrays/objects.
- **FR-006** `writeJSON5PList(const PList&) -> std::expected<Data, PListError>` in
  `PListWriting.hpp`; its output parses back to an equal tree for every tree without `Object`
  nodes or single-precision reals.
- **FR-007** `src/oofnd/PListFile.hpp`: `loadPListFile(path, read)` holds the `.json5`-beside-`.plist`
  rule; `cxx_OOPropertyListFromFile` uses it. A JSON5 parse failure is logged with
  `plist.parse.failed`, as a plist failure is; the both-present warning uses
  `plist.json5.shadowed`.
- **FR-008** `tools/plist2json5`, built on every platform (plain C++, like `tools/icosmesh`), with
  the modes and check described in User Story 3.
- **FR-010** A path ending in `.json5` given to `loadPListFile` (so to
  `cxx_OOPropertyListFromFile`) is read as JSON5.
- **FR-011** `oo::existingPListPath(path, exists)` answers the `.json5` beside a `.plist` path when
  it exists, else the path when it exists; `ResourceManager::pathForFileNamed` uses it, so a name
  ending in `.plist` is found as either file (AI state machines, script files by name).
  `OOScript::scriptsFromFileAtPath` takes a `.json5` path as a property list script.
- **FR-012** `oo::parsePListFile(path, read)` gives the tree from either format without logging;
  the three readers that parse a built-in file themselves use it (`whitelist.plist` and
  `shader-uniform-bindings.plist` in `ResourceManager`, `descriptions.plist` in `Universe`,
  `verifyOXP.plist` in `OOOXPVerifier`).
- **FR-013** `plist2json5 --parse <path>...` reads each `.json5` file (or every one under a
  directory) with the game's reader and exits 1 when any doesn't parse; suite `plist2json5`
  runs it over `Resources/`. The suite's `--check` tests run over the plists still in the tree
  (`Resources/`, `DebugOXP/`, `tools/`).
- **FR-014** `ShellScripts/common/post_build.sh` removes from the build's resources a `.plist`
  whose `.json5` is beside it and whose source no longer has the plist.
- **FR-009** No existing test changes. No `-Wno-*`. clang-format 22 on changed `src/` files only.

## Success Criteria *(mandatory)*

- **SC-001** `test_plist_json5` passes (Clang on macOS by direct compile; Windows CI through
  `tests/run.sh unit`).
- **SC-002** `meson test -C build/meson_debug --suite plist2json5` passes: all 85 core plists
  round-trip in `--strings` mode with strict equality and in `--typed` mode with getter
  equivalence.
- **SC-003** The existing plist tests and the game build are unchanged.
- **SC-004** 82 of the 85 core plists are JSON5; each parses to a tree equal (`==`) to its plist's.
- **SC-005** `tests/run.sh smoke` and `tests/run.sh component` pass on the converted tree.

## Decisions and notes

Each has the conservative default taken; Jon may override.

| # | Question | Default | Reason |
|---|---|---|---|
| D1 | Base | `b692feb4e`, the tip of local `seriesb/027-modern-cpp` (T050, not yet pushed) | the user asked for the newest modern C++ commits |
| D2 | Where the `.json5` rule lives | one place, `cxx_OOPropertyListFromFile`, through `oo::loadPListFile` | every loader (ResourceManager, AI, script lists, OXZ manifests) goes through it |
| D3 | Both files present | JSON5 wins, warning logged | 5b's default |
| D4 | `null` | parse error | a plist has no null; silently dropping keys changes data |
| D5 | Repeated keys | last wins | the OpenStep reader does the same |
| D6 | Non-ASCII bare keys | accepted when not whitespace or a line terminator | looser than ES5 IdentifierName, which needs Unicode tables oofnd lacks; strictness here protects nothing |
| D7 | Depth limit | 512 | deep enough for any real file (core data is under 10), shallow enough for an ASan stack on Windows |
| D8 | Converter default | `--strings` | keeps what scripts see; `--typed` is opt-in |
| D9 | `--typed` rules | only unquoted OpenStep tokens: `yes`/`no`/`true`/`false`/`YES`/`NO` → bool; `-?(0|[1-9][0-9]*)` in `int64_t` → integer; `-?(0|[1-9][0-9]*)\.[0-9]+([eE][+-]?[0-9]+)?` → real | narrow patterns; everything else stays a string |
| D10 | `--check` equality | `--strings`: `==` on the trees; `--typed`: where the JSON5 node is bool/integer/real and the plist node a string, equal when `get<bool>`/`get<long long>`/`get<double>` of the string gives that value | that is the C++ guarantee typing must keep |
| D11 | What isn't covered | code that checks a `.plist` exists, or lists `*.plist`, before loading | listed in tasks.md as follow-ups |
| D13 | Integer equality in `--check` | by value; the unsigned flag on a value that fits `int64_t` is not compared | the XML reader marks non-negative `<integer>`s unsigned; JSON5 has no way to say so, and the value is the same |
| D12 | Unit tests on macOS | compiled directly with `clang++ -std=c++23 -Wall -Wextra -Werror -I src -I tests/unit/oofnd`; meson builds them on Windows only | the tree's meson gates unit suites to Windows; changing that is `seriesb/026-dev-container`'s job |
| D14 | Mode for the core conversion | `--strings` | every tree is `==` to the plist's, so nothing a script or the game reads changes type; `--typed` is one command later if Jon wants numbers and booleans |
| D15 | Core files that stay plists | `Resources/Info-gnustep.plist`, `Config/descriptions.plist`, `Config/whitelist.plist` | the first is bundle information the build scripts and many unit tests read as a plist; the other two are the inputs `tests/unit/expander/test_string_expander.cpp` and `tests/unit/sysdesc/test_sysdesc_tools.cpp` take by path and parse as plists, and tests are not edited (rule 1). The game reads all three in either format |
| D16 | Names in code, data and scripts | stay `<name>.plist` | they are identifiers expansions and saved games already use (`ai_type`, `hud`, `switchAI`); only the file on disk changed |
| D17 | What `pathForFileNamed` answers | the file that exists (`.json5` first) | a path that names no file is a trap for the next caller; `cxx_OOPropertyListFromFile` reads a `.json5` path directly (FR-010) |
| D18 | Plists outside `Resources/` | unchanged (`DebugOXP/`, `tools/`) | the Debug OXP is an expansion in the old format and keeps the plist path exercised by every smoke and component run |
| D19 | `script.plist` (legacy world script found by existence) | not extended to `script.json5` | the format is deprecated; a legacy script named in `world-scripts` is found in either format through FR-011 |
| D20 | Branch | `seriesb/030-json5-data-files`, git town parent `seriesb/027-modern-cpp` | Jon, 2026-11-13: "I would call this seriesb/030"; 029 (component tests) will sit under it and does not exist yet |
| D21 | Running the game on the Mac | done: smoke and component tiers, debug build | the request was "get it working, building, and passing tests"; the GUI tier (Windows only) was not run |
