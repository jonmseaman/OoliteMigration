# Expansion compatibility scan: results ([ADR-0069](../decisions/0069-expansion-compatibility-scan.md))

This is the record of the first pass over all 818 catalogued expansions. Jon asked for it on
2026-10-27: scan the code for QuickJS-ng incompatibilities, write notes per expansion, then write
the migration guide. Expansion updates come later and are Jon's call. Every statement here comes
from the game's own engine, from code reading the cached archives, or from
`tools/oxp-js-lint/probe.js`'s redacted view. No agent read expansion source (CLAUDE.md rule 6).

| Layer | Tool | Status |
|---|---|---|
| 1. Parse with the game's QuickJS-ng | `tools/oxp-js-parse` | **done 2026-10-27** (below) |
| Engine API ground truth | `tools/oxp-js-parse/engine-probe.c` | **done 2026-10-27** (below) |
| 2. Rules for code that parses but behaves differently | `tools/oxp-js-lint` compat set | in progress |
| 3. Sandboxed model review | `tools/oxp-scan` | not started (needs the cost spike first) |
| Notes per expansion, migration guide | `tools/oxp-scan/notes.py`, `docs/EXPANSION_MIGRATION.md` | not started |

## Layer 1: what fails to compile (2026-10-27, quickjs-0.16.2)

**Command:** `bash tools/oxp-js-parse/build.sh && node tools/oxp-js-parse/run.js corpus`, output in
`tools/oxp-js-parse/parse-report.json`. Each file is compiled the way the game's loader does it
(`JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_COMPILE_ONLY`, line 1): once as shipped, and once with the
`"use strict";` prefix that standards enforcement adds.

**Corpus:** 818 expansions, all read from the cache, 1,997 `.js` members, 13.6 s.

**Result:** 7 files in 6 expansions fail to compile as shipped. In the game such a script does not
exist: the loader logs "compilation failed". No file fails only under the strict prefix.

| Expansion | File:line | Cause | Fails on SpiderMonkey 1.93 too? |
|---|---|---|---|
| Wild_ships 1.11.4 | `Scripts/wildShips_tembo.js:16` | legacy generator (`yield` in a plain `function`) | no: SpiderMonkey-only syntax (oo-1gc.16) |
| Aquatics 2.30 | `Scripts/aquatics_congerPods.js:17` | legacy generator | no |
| Montana05 Kestrel_Falcon | `Scripts/bweed-kestrelfalcon-falcon.js:16`, `Scripts/bweed-kestrelfalcon-kestrel.js:14` | legacy generator | no |
| Reval.Defence_Rider_Drones 1.9 | `Scripts/police_call_AI.js:195` | bracket imbalance: the `)` at 195:3 closes a `{` opened at 7:29 | **yes:** the script never loaded |
| Reval.Neutralizer 1.3 | `Scripts/npc-npb.js:112` | bracket imbalance: the `if (` at 112:6 is never closed | **yes** |
| Cholmondely.Hints 0.0.94 | `Scripts/Hints_GNN.js:71` | assignment to a string literal (`"…" = "…";`) | **yes:** an early error on every engine |

So the engine swap breaks **four** script files outright (three expansions). The other three were
already broken. The old regex lint found the four legacy generators and missed the three
grammar errors. Those were diagnosed by code that walked `rules.js`'s masked text and printed only
bracket positions, and by `probe.js`'s redacted token view of the failing line.

The fixtures (`tools/oxp-js-parse/fixtures/`, checked by `selftest.js`) confirm what the parser
rejects as shipped:

- `for each`
- expression closures
- `catch (e if …)`
- `let (…)` blocks
- legacy generators
- E4X
- `const` redeclaration

Legacy octal (`0755`) and duplicate parameter names fail only under `"use strict"`. No corpus
file uses any of these apart from the generators above.

## Engine API ground truth (2026-10-27, quickjs-0.16.2)

**Command:** `bash tools/oxp-js-parse/build.sh && .agent-tmp/oxp-js-parse/engine-probe.exe`.

Each case is evaluated in a **bare** QuickJS-ng context: no Oolite globals, and none of the
`oolite-global-prefix.js` polyfills the game installs (ADR-0023). This replaces what
`docs/EXPANSION_MIGRATION.md` assumed with what the engine does.

| SpiderMonkey 1.8.5 feature | QuickJS-ng 0.16.2 (bare) | In the game | Guide status |
|---|---|---|---|
| `Object.prototype.watch` / `unwatch` | `undefined` | calling it throws `TypeError` | removed, as documented |
| `Iterator(obj)` (legacy iterator) | `Iterator` **exists** (the ES2025 abstract class); `Iterator({a:1})` throws `TypeError: constructor requires 'new'` | throws; a `typeof Iterator` feature test now passes and takes the wrong branch | **new finding:** the guide says "removed" but the name exists with different meaning |
| `StopIteration` | `undefined` | `ReferenceError` | removed, as documented |
| `RegExp.$1`…`$9`, `RegExp.lastMatch` | `undefined` after a successful `exec` | silently `undefined` | removed, as documented |
| `Date.prototype.toLocaleFormat` | `undefined` | `TypeError` | removed, as documented |
| `fn.arity` | `undefined` | silently `undefined` | removed, as documented |
| `fn.caller` (sloppy code) | `typeof g.caller` is `"undefined"` (SpiderMonkey gave the calling function) | silently `undefined` | removed, as documented |
| `fn.caller` (strict code) | `TypeError` | `TypeError` | as documented |
| `err.fileName` / `err.lineNumber` | `undefined` / `undefined` | silently `undefined` | removed, as documented |
| `obj.__count__`, `obj.__parent__` | `undefined` | silently `undefined` | removed |
| `__noSuchMethod__` | not honoured: calling a missing method throws `TypeError` | throws | removed |
| `__iterator__` | not honoured: `for-in` lists `__iterator__` itself as a key | iteration silently changes | removed; behaviour **changes**, it does not throw |
| `__defineGetter__` / `__lookupGetter__` (and setters) | **present** (Annex B) | **works** | **guide correction:** listed as removed/deprecated; it works, so the `legacy-accessor` findings (GalCopMissions) are INFO, not BREAKS |
| `Array.forEach(list, fn)`, `String.replace(s, …)` generics | `undefined` | **present**, polyfilled by `oolite-global-prefix.js` | as documented (ADR-0023) |
| `toSource()`, `uneval()`, `String.prototype.quote()` | `undefined` | **present**, best-effort polyfill whose output text differs from SpiderMonkey's | as documented (ADR-0023) |
| `Function#toString` | returns the original source text (`function sq(a){ return a*2 }`) | same | SpiderMonkey 1.8.5 returned decompiled, reformatted source. Code that compares or parses it changes. |
| `arguments.callee` | works in sloppy code; `TypeError` in strict code | same | as documented |
| Property write on a primitive (sloppy) | ignored, no error | same | as documented (strict code throws) |
| Error message text | `cannot read property 'x' of null`, `undefinedName is not defined` | same | wording is engine-specific; code that matches on `e.message` may change |
| Standard globals | `BigInt`, `Iterator`, `Map`, `Promise`, `Proxy`, `Reflect`, `Set`, `Symbol`, `WeakMap`, `globalThis` all present | same | SpiderMonkey 1.8.5 lacked most of these, and its `Iterator` and `Proxy` had different APIs. Code that lists or feature-tests globals sees a different set. |

These rows set the severities of the layer-2 `removed-api`, `polyfill-approx`, `fn-tostring`,
`error-message` and `global-enum` rules. They also fix two places where the guide was wrong
(`Iterator`, legacy accessors). The guide is corrected in the migration-guide step.
