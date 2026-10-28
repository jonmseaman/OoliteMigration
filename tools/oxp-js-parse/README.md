# oxp-js-parse: does the game's QuickJS-ng parse it? (ADR-0069, layer 1)

This tool compiles every `.js` file of every catalogued expansion with the **game's own pinned
QuickJS-ng** (`oolite-dev/subprojects/quickjs-ng.wrap`). It uses the flags the game's script loader
uses: `JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_COMPILE_ONLY`, from line 1 (`compileUCScript` in
`JSEngine_quickjs.cpp`). Nothing is executed.

A syntax incompatibility is therefore a fact, not a regex guess. Every construct shows up, whether
or not a lint rule exists for it.

Each file is compiled twice:

| mode | what | a failure means |
|---|---|---|
| `plain` | the bytes as the game loads them by default | the game logs "compilation failed" and the script does not exist: **BREAKS** |
| `strict` | with the `"use strict";\n` prefix the game adds when standards enforcement is on (`OOJSScript.cpp`, `OOEnforceStandards()`; off unless a player or the verifier turns it on) | reported as `strict-only`, and only when `plain` parses |

A failure gets the rule id of the `oxp-js-lint` detector that fires on the same line. A failure no
detector explains is `syntax-other`: a gap in the guide, never a pass. The report holds file
names, positions, rule ids and QuickJS-ng's own message, truncated by the host. It never holds
expansion source (CLAUDE.md rule 6).

## Usage

```sh
bash tools/oxp-js-parse/build.sh [--quickjs-src DIR]   # -> .agent-tmp/oxp-js-parse/oxp-js-parse.exe
node tools/oxp-js-parse/selftest.js                     # fixtures/expected.json, CRLF, exit codes
node tools/oxp-js-parse/run.js scan <dir|file.js> ...   # an unpacked expansion; exit 1 if it breaks
node tools/oxp-js-parse/run.js corpus                   # all 818 -> parse-report.json (~15 s)
```

`build.sh` refuses a QuickJS-ng source whose directory differs from the wrap's. In a worktree
whose `oolite-dev` submodule is not initialised, it falls back to the main checkout's copy. You can
also pass `--quickjs-src`.

## Fixtures

`fixtures/` holds one synthetic file per syntax difference, plus a clean file that mentions every
banned construct inside strings, comments and a regex. `expected.json` pins the mode and line of
each. Seven fail as shipped:

- `for each`
- expression closure
- `catch if`
- `let` block
- legacy generator
- E4X
- `const` redeclaration

Two fail only under the strict prefix:

- legacy octal `0755`
- duplicate parameter names

## Corpus result (2026-10-27, quickjs-0.16.2)

818 expansions, 1,997 `.js` members, 13.6 s. **7 files in 6 expansions fail to compile as
shipped.** 0 fail only under `"use strict"`.

| expansion | file:line | rule | diagnosis |
|---|---|---|---|
| Wild_ships 1.11.4 | `Scripts/wildShips_tembo.js:16` | legacy-generator | SpiderMonkey-only syntax (known, oo-1gc.16) |
| Aquatics 2.30 | `Scripts/aquatics_congerPods.js:17` | legacy-generator | same |
| Montana05 Kestrel_Falcon | `Scripts/bweed-kestrelfalcon-falcon.js:16`, `...-kestrel.js:14` | legacy-generator | same |
| Reval.Defence_Rider_Drones 1.9 | `Scripts/police_call_AI.js:195` | syntax-other | **fails on any engine.** The `)` at 195:3 closes a `{` opened at 7:29, so a `}` is missing. The script never loaded on SpiderMonkey either. |
| Reval.Neutralizer 1.3 | `Scripts/npc-npb.js:112` | syntax-other | **fails on any engine.** The `if (` at 112:6 is never closed. |
| Cholmondely.Hints 0.0.94 | `Scripts/Hints_GNN.js:71` | syntax-other | **fails on any engine.** It assigns to a string literal (`"…" = "…";`), an early error on every engine. |

The three `syntax-other` rows were diagnosed without reading the scripts:

- the bracket balance was computed by code over `rules.js`'s masked text, which printed only positions and bracket characters;
- `tools/oxp-js-lint/probe.js` gave the redacted token shape of the failing line.

The other lint findings (`to-source` in Library, `legacy-accessor` in GalCopMissions) are runtime
API uses that parse fine. They belong to layer 2, not here.
