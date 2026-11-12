# Feature Specification: JSON5 data files beside property lists

**Feature Branch**: `feature/json5-data-files` (in `oolite-dev`, worktree
`.agent-tmp/wt-json5`), based on `seriesb/027-modern-cpp` at `b692feb4e`; spec directory
`010-json5-data-files`

**Created**: 2026-11-12

**Status**: Implemented on `feature/json5-data-files` (`c492a87a2`, pushed); awaiting Jon's review

**Input**: User description: "Is the plan for json5 ready for implementation? I would be good
with creating a worktree, implementing it, then I can review it later. Make sure to base the thing
off the most recent commits (modern c++ migration commits)"

Background: [Phase 5b](../../docs/phases/5b-data-formats.md) and the format comparison in
[notes/2026-11-07 Plist Replacement Format.md](../../notes/2026-11-07%20Plist%20Replacement%20Format.md).
This spec covers 5b.1–5b.3 and the converter. 5b.4 (component scenarios over a converted tree),
5b.5 (docs) and 5b.6 (migrating core `Resources/`) are out of scope.

## Purpose

Expansion authors can write any data file the game loads as a property list as JSON5 instead,
under the same name with a `.json5` extension, with the same meaning and the same merge rules. A
converter turns existing plists into JSON5 and proves the result reads back the same. Plists keep
working unchanged, and the core game's own files stay plists.

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
- **FR-009** No existing test changes. No `-Wno-*`. clang-format 22 on changed `src/` files only.

## Success Criteria *(mandatory)*

- **SC-001** `test_plist_json5` passes (Clang on macOS by direct compile; Windows CI through
  `tests/run.sh unit`).
- **SC-002** `meson test -C build/meson_debug --suite plist2json5` passes: all 85 core plists
  round-trip in `--strings` mode with strict equality and in `--typed` mode with getter
  equivalence.
- **SC-003** The existing plist tests and the game build are unchanged.

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
