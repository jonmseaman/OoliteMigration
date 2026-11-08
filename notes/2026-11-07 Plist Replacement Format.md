# Choosing a modern format to sit beside property lists

**Status:** proposed, not started · **Written:** 2026-11-07 · **Target:**
[Phase 5b](../docs/phases/5b-data-formats.md) ("JSON5 beside plists")

A plan for later adoption, not current work. Nothing in `oolite-dev` has changed. Phase 5b already
assumes JSON5 and records "JSON5 vs JSON vs TOML vs YAML → JSON5" as a default with no reasoning
behind it. This note weighs the candidates against the game's real data, confirms the choice, and
lists what 5b has to settle before it starts.

**Recommendation: JSON5**, read by a small hand-written reader in `oofnd` that produces the same
`oo::PList` tree the OpenStep and XML readers produce. Because JSON5 is a superset of JSON, the same
reader also takes plain JSON and JSON-with-comments, so anything that emits JSON is a valid source.
**YAML is the runner-up** and loses on safety with untrusted expansions, how easily it breaks, and
the extra dependency. TOML can't express the data at all.

**Three findings 5b doesn't address yet:**

1. Typed scalars change what scripts see. OpenStep plists have no types: `max_cargo = 20;` is the
   string `"20"`, and JavaScript gets it as a string through `Ship.shipDataForKey` and friends. A
   JSON5 `max_cargo: 20` reaches JavaScript as a number. This holds for *every* typed format, not
   only JSON5. See [Typed scalars](#typed-scalars).
2. `oo::PList::Dict` is a `std::map`, so the node tree has neither key order nor comments. The
   converter that 5b says keeps key order and comments can't be built on the node tree. It has to
   work on the OpenStep token stream.
3. Plists aren't going away. At least 9 core files, `equipment.plist` among them, have an array at
   the top, and the 2.7 MB `planetinfo.plist` parses at every startup. Any new format has to
   handle both.

## What the data looks like (measured 2026-11-07, `oolite-dev/Resources`)

| Fact | Value | Why it matters |
|---|---|---|
| Plist files | 85: 84 OpenStep text, 1 XML (`Info-gnustep.plist`) | the OpenStep syntax is the one modders know |
| Total size | 3.6 MB; `planetinfo.plist` alone is 2.7 MB | parse speed counts; it's read at every startup and per expansion |
| Top level is an array | at least 9 files (e.g. `equipment.plist`, rows like `(1, 300, "Missile", "EQ_MISSILE", "…", { … })`) | rules out formats whose root must be a table |
| Positional mixed-type arrays | everywhere (`equipment`, colours `(0.75, 0.8, 1)`) | the format needs heterogeneous arrays |
| Arrays of dicts inside dicts | `keyconfig2.plist`, `keymappings_*.plist` (`key_view_forward = ({ key = "1"; }, { key = "f1"; });`) | deep nesting has to stay readable inline |
| Keys that aren't identifiers | `"0 0"` … `"7 255"` in `planetinfo`; 114 hyphenated keys in `shipdata` (`adder-player`) | bare keys can't cover everything; quoting must be cheap |
| Comments | 42 of 85 files, both `//` and `/* */`, including long header essays | comments are required, and the converter should carry them over |
| Boolean-ish scalars | 915 `yes`/`no`/`true`/`false` values | the typed getters read these; a format that guesses types will misread some |
| Text-heavy files | `descriptions.plist` (108 KB), `missiontext.plist` (56 KB); 72 values start with `[`, `%`, `@` etc.; 226 contain `": "`; 165 contain `\n` escapes | in YAML, each of these needs quoting |
| GNUstep `<*I…>` typed extensions, `<hex>` data | none in core files | the `$data`/`$date` escape hatch is for expansions and saves, not core data |

## Criteria

In priority order. The first three can rule a format out on their own.

1. **Fits the node model losslessly.** Dict, array, string, integer, real, boolean, data, date; any
   string as a key; an array at the root. One reader can feed `ResourceManager` without changing
   anything after it.
2. **Safe with untrusted input.** Expansions are untrusted (hard rule 4). No code execution, no
   reference expansion that can blow up memory, nothing that grows without bound, and fuzzable the
   way `tools/plist_fuzz.py` fuzzes the plist readers.
3. **Robust to editing by hand and pasting from forums.** A snippet pasted from the Oolite BB, with
   its indentation lost, should still parse or fail loudly, never turn silently into different
   data.
4. **Close to what modders write today.** A mechanical conversion should look familiar, so the
   learning cost is small and diffs are readable.
5. **Ecosystem.** Editor highlighting, formatters, linters, schema validation, libraries in other
   languages (expansion tools, the OXZ index).
6. **Implementation cost.** Small, no heavy dependency, GPL-compatible, builds on all three
   platforms with Clang and GCC under `-Wall -Wextra`.
7. **Speed** on a 2.7 MB file.
8. **Fits the scripting layer.** Expansion logic is JavaScript.

## Candidates

| | JSON5 | YAML 1.2 | TOML 1.0 | JSON / JSONC | HJSON | KDL 2 | NestedText | XML plist (today) |
|---|---|---|---|---|---|---|---|---|
| 1 Node model | ✓ | ✓ | ✗ no root array, poor nested arrays of tables | ✓ | ✓ | ~ needs a mapping convention | ~ strings only (as OpenStep) | ✓ |
| 2 Untrusted input | ✓ small grammar | ✗ anchors/aliases, tags, big grammar | ✓ | ✓ | ~ | ✓ | ✓ | ~ entity handling |
| 3 Hand-edit robustness | ✓ explicit brackets | ✗ indentation and implicit typing | ~ | JSON ✗ (no comments, no trailing comma); JSONC ~ | ~ quoteless strings are ambiguous | ✓ | ✗ indentation | ✓ but verbose |
| 4 Close to OpenStep | ✓ `(`→`[`, `=`→`:`, `;`→`,` | ✗ different shape | ✗ | ~ every key quoted | ✓ | ✗ | ~ | ✗ |
| 5 Ecosystem | ~ good editor support, schemas via JSON Schema | ✓ largest | ✓ | ✓ largest | ✗ small | ✗ small | ✗ tiny | ~ |
| 6 Cost | ✓ own reader ≈1k lines, like `PListOldStyle.hpp` (668) | ✗ vendor rapidyaml / yaml-cpp / libyaml | ~ vendor toml++ | ✓ (JSONC is a JSON5 subset) | ~ | ~ | ~ | ✓ already done |
| 7 Speed | ✓ | ~ depends on library | ✓ | ✓ | ✓ | ✓ | ✓ | ~ |
| 8 Scripting fit | ✓ reads like a JS object literal | ~ | ~ | ✓ | ~ | ✗ | ✗ | ✗ |

Dropped without a column: **Jsonnet, CUE, Pkl, Dhall** and other programmable configuration
languages. Executing an expansion's configuration is the wrong trust model (criterion 2), and the
game already has a scripting language. **RON** is tied to Rust's type system. **INI** can't nest.

### JSON5: recommended

- Closest to OpenStep. Comments, trailing commas, unquoted identifier keys, single-quoted
  strings, hex numbers. Converting the files is mostly punctuation, and modders recognise the result.
- Brackets carry the structure, so whitespace never matters. A mangled forum paste fails to parse;
  it doesn't silently turn into different data.
- A small grammar: one page of spec, a conformance suite to vendor, and the same shape as the
  readers `oofnd` already writes by hand and fuzzes. No new dependency.
- Takes JSON and JSONC for free, so a tool that only writes JSON (a web index, a Python script, an
  editor) makes valid files.
- It's what a JavaScript modder already writes. Scripts can `JSON.stringify` data and the reader
  takes it back.
- Weaknesses: bare keys must be ECMAScript identifiers, so the 114 hyphenated `shipdata` keys and
  the `planetinfo` coordinate keys stay quoted, as many already are. Long text has only
  backslash-newline continuation, no block strings; the text files already use `\n` escapes inside
  one-line strings, so nothing is lost. Editor schema support is patchier than for plain JSON.

### YAML 1.2: runner-up, rejected

- It wins on readability for big flat dictionaries, and its block scalars (`|`, `>`) would be nicer
  for `descriptions` and `missiontext`. That's two files out of 85.
- It loses on criterion 2. Anchors and aliases allow exponential expansion ("billion laughs") from a
  few hundred bytes, and tags invite custom types. Every expansion would need a parser with those
  features turned off or capped, and we would carry a large vendored dependency for it, because no
  small reader can be written by hand.
- It loses on criterion 3. Indentation carries the structure, so forum pastes break. Implicit
  typing guesses a scalar's type from how it looks (`1.10` → `1.1`; `no` is a boolean in YAML 1.1
  parsers and a string in 1.2), and libraries differ on which schema they apply. In the text files,
  72 values start with characters that begin YAML syntax, and 226 contain `": "`. Every one would
  need quoting, which removes the readability win in exactly the files that wanted it.

### TOML 1.0: ruled out

The root must be a table, so `equipment.plist` and the other files with an array at the top can't
be expressed. Arrays of tables nested inside tables (`keyconfig2`) become `[[default.key_view_forward]]`
headers far from their parent, or one-line inline tables. It's a good format for flat settings,
like a future `oolite.toml` for user preferences, and that is a different problem.

### JSON / JSONC: subsumed

Strict JSON has no comments or trailing commas, and 42 of the 85 files have comments, so it fails
criterion 3. JSONC (JSON with comments, as VS Code uses) is acceptable, and the JSON5 reader
already takes it. There's no reason to pick the narrower format.

### HJSON, KDL, NestedText: not enough to justify them

HJSON's quoteless strings make it look like JSON5 while parsing less predictably, and few tools
know it. KDL is a node language (`node arg key=value { children }`), so it would need an
Oolite-specific mapping onto dict and array before it could serve as a plist stand-in. NestedText
keeps every value a string, which matches OpenStep exactly and would avoid the typing problem below,
but it depends on indentation and almost no tools support it.

## Typed scalars

This is the one real design question, and it applies whichever format is chosen.

Today every OpenStep scalar is a string. C++ readers go through the typed getters, which parse the
string. JavaScript gets the string as it is. A JSON5 file has real numbers and booleans:

- **C++:** no visible change, as long as the getters accept a typed node wherever they accept a
  string. 5b assumes they do; the mapping-rule tests (5b.1) must prove it, getter by getter.
- **JavaScript:** a visible change. `shipDataForKey("adder").max_cargo` would be `20` instead of
  `"20"`, so `+ 1` gives `21` instead of `"201"`, and `=== "20"` stops matching.

Expansions that ship JSON5 opt into this, so nothing existing breaks. The risk is converting core
data or someone else's expansion: a script that relies on getting strings back would change
behaviour.

**Default (conservative):** values keep their types all the way to JavaScript. The core
`Resources/` stays plist, as 5b's own default already says. `plist2json5` gets a `--strings` mode
that writes every scalar as a quoted string, so a converted file is guaranteed to look the same to
scripts, and a `--typed` mode for authors who want the modern form and accept the change. Before
5b.6 (core migration) can start, it needs a scan of the expansion corpus for scripts that read core
data as strings.

## Plan

This refines 5b's work items rather than replacing them.

1. **Record the choice in 5b.** Change the open-decisions row "JSON5 vs JSON vs TOML vs YAML" to
   link this note. Add two rows: "Typed scalars reaching JS: typed; converter has `--strings`" and
   "Converter works on tokens, not the node tree". Done when the 5b doc links here.
2. **5b.1 JSON5 reader.** Add `src/oofnd/PListJSON5.hpp`, modelled on `PListOldStyle.hpp`: strict
   UTF-8, line and column in errors, a depth limit at least as strict as the OpenStep reader's.
   Tests: the vendored JSON5 conformance inputs, one test per mapping rule, and one per typed
   getter showing that `"20"` and `20` read the same. Add a JSON5 mode to `tools/plist_fuzz.py`.
   Exit check: `tests/run.sh unit` fails before (missing test) and passes after.
3. **Converter design.** `tools/plist2json5` reads OpenStep **tokens**, so it keeps comments and key
   order, and writes JSON5. `--check` reparses the output through both readers and compares the
   node trees. It has `--strings` and `--typed`. Exit check: `--check` passes on all 85 core files
   in both modes.
4. **5b.3 lookup and merge.** As in 5b, with one addition: a test expansion with a top-level-array
   `equipment.json5` merges with core `equipment.plist`.
5. **Speed check.** A benchmark (not a gate) that parses `planetinfo.plist` and its JSON5 version.
   The JSON5 reader must be no slower than the OpenStep reader, give or take noise; if it is
   slower, fix that before 5b.3.
6. **5b.4–5b.6** unchanged, except that 5b.6 now waits on the expansion-corpus scan from
   [Typed scalars](#typed-scalars).

## Risks

- **Choosing again later.** If YAML demand appears, for example from authors of long mission text,
  the node model means a second reader can still be added. The safety argument against YAML
  doesn't change, though.
- **Upstream divergence.** Upstream Oolite reads no JSON5. 5b already has the OXP verifier warning.
- **"JSON5" drift.** Some libraries and editors call JSONC "JSON5". The reader follows the JSON5
  1.0.0 spec and its conformance suite, nothing looser.

## Decisions and defaults

| Question | Default | Reason |
|---|---|---|
| Format | JSON5 | the only candidate that passes criteria 1–4 and needs no dependency |
| Also accept JSON / JSONC | yes, for free | they are subsets |
| YAML | no | untrusted-input surface, indentation, implicit typing, dependency |
| TOML | no for data files; possible later for user preferences | no root arrays |
| Typed scalars reach JS | yes, for JSON5 files authors write | opt-in; nothing existing changes |
| Converter default mode | `--strings` for core or third-party files, `--typed` on request | keeps what scripts see unless an author chooses otherwise |
| Saved games | stay XML plist (as 5b) | they must load in older builds |
