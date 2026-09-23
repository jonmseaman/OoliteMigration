# Expansion (OXP/OXZ) author migration guide: SpiderMonkey → QuickJS-ng

**Audience:** authors of OXP/OXZ expansions with JavaScript scripts. **Status:** Phase 1
deliverable per [ADR-0002](decisions/0002-quickjs-ng.md) and
[architecture.md §5.3](architecture.md#53-what-expansion-authors-will-need-to-change-the-guide).

Oolite's C++ port replaces the patched SpiderMonkey 1.8.5 engine (Firefox 4.0, 2011) with
QuickJS-ng (ES2023) behind a facade (`ooscript/JSEngine.hpp`). Contracts C1, C2, C4, C5 and C6
(save format, `.plist`/`.js` script discovery, world model API surface, rendering, sound) are held
constant and enforced by the goldens and the OXP corpus. **The only expansion-facing thing that
changes is C3, the JavaScript language level** — and only for scripts that used Mozilla-only
(SpiderMonkey-only) syntax that no other engine, including every modern browser, has supported in
over a decade.

This document lists every such construct, what to replace it with, and which automated tool
flags it so you can check your own OXP before shipping.

## How to check your own expansion

```sh
node tools/oxp-js-lint/lint.js scan path/to/your/Scripts
```

runs the same eight detectors below (masking comments/strings/regexes first, so quoting a banned
construct in a string or a comment is not flagged). See `tools/oxp-js-lint/README.md` for the
`corpus` mode, `eslint` integration, and known limits of the scan.

## Corpus scan results (bead oo-ctq, `tools/oxp-js-lint/corpus-report.json`)

The lint ran, offline, against the full cached catalogue of 818 expansions (1,997 `.js` members)
before this guide was published:

```
818 expansions (818 read, 0 not cached, 0 unreadable), 1997 .js members,
5 findings in 2 expansions, 10s
  to-source: 3        Library_1.10.5.oxz  (Lib_Main.js, lib_test.js)
  legacy-accessor: 2  GalCopMissions_0.15.oxz  (Resources/PhraseGen.js)
  catch-if 0, e4x 0, quote-method 0, uneval 0, let-block 0, expression-closure 0
```

Five hits across 2,000 files, verified against an independent unmasked-regex instrument
(`crosscheck.js`) that confirmed the extra candidates it found are all inside comments/JSDoc/prose
and not real occurrences (see `tools/oxp-js-lint/README.md` for detail). The blast radius of this
migration, measured against the entire catalogue, is two expansions.

## Removed — SpiderMonkey-only syntax (hard errors under QuickJS-ng)

Each entry below is one of the eight detectors implemented in
[`tools/oxp-js-lint/rules.js`](../tools/oxp-js-lint/rules.js) (`DETECTORS` object) and exercised by
the fixtures in `tools/oxp-js-lint/fixtures/`.

#### `catch-if` — conditional catch clause

`catch (e if cond) { ... }` (JS1.5). Removed from Firefox in version 59; never implemented in any
other engine.

- **Removed:** the whole `if` guard on a `catch` clause — this is *syntax*, not a runtime
  behaviour, so a QuickJS-ng parse fails before your script ever runs.
- **Replacement:** `catch (e) { if (cond) { ... } else { throw e; } }`
- **Lint rule:** [`catch-if`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/catch-if.js`)

#### `e4x` — E4X / ECMA-357 (XML literals, `..` descendant, `.@` attribute)

`var x = <manifest><name>Foo</name></manifest>; var n = x..name; var id = x.@identifier;`. Removed
from SpiderMonkey in Firefox 21 (2013); never implemented in V8, JSC, or QuickJS.

- **Removed:** XML literal syntax and the `..`/`.@` operators entirely.
- **Replacement:** none — rewrite as plain objects/arrays, or parse XML with a JS XML/DOM parser
  if you actually need to consume XML data.
- **Lint rule:** [`e4x`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/e4x.js`)

#### `quote-method` — `String.prototype.quote()`

A SpiderMonkey-only String method, removed in Firefox 37.

- **Removed:** `"foo".quote()` (returns a source-code-quoted string literal).
- **Replacement:** `JSON.stringify(s)` (not byte-identical output but the standard, portable
  equivalent for producing a quoted/escaped string).
- **Lint rule:** [`quote-method`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/quote-method.js`)

#### `to-source` — `Object.prototype.toSource()` / `Array.prototype.toSource()`

SpiderMonkey-only source reflection, removed in Firefox 74. **This is the construct actually found
in the corpus scan** (`Library_1.10.5.oxz`, 3 occurrences).

- **Removed:** `obj.toSource()`.
- **Replacement:** `JSON.stringify(obj)` for data objects. For debug logging specifically, build a
  small local helper instead of relying on engine-provided source reflection.
- **Lint rule:** [`to-source`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/to-source.js`)
- **Interim relief:** bead oo-864 (blocked by this bead) is a compatibility-shim OXP that
  polyfills `toSource`/`quote` for expansions whose authors are unreachable, loaded first.

#### `uneval` — the global `uneval()`

SpiderMonkey-only global, removed in Firefox 74.

- **Removed:** `uneval(value)`.
- **Replacement:** `JSON.stringify(value)`.
- **Lint rule:** [`uneval`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/uneval.js`)

#### `let-block` — `let` block / `let` expression (JS1.7)

`let (x = 1) { ... }` or `let (x = 1) x + 1`. SpiderMonkey-only syntax, removed in Firefox 44.

- **Removed:** the parenthesised `let (...)` block/expression form.
- **Replacement:** standard block-scoped `let`/`const`: `{ let x = 1; ... }`.
- **Lint rule:** [`let-block`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/let-block.js`)

#### `legacy-accessor` — `__defineGetter__` / `__defineSetter__` / `__lookupGetter__` / `__lookupSetter__`

A deprecated Mozilla extension. **The other construct found in the corpus scan**
(`GalCopMissions_0.15.oxz`, 2 occurrences).

- **Removed/deprecated:** the four `__*__` accessor methods.
- **Replacement:** `Object.defineProperty(obj, "prop", { get() {...}, set(v) {...} })` /
  `Object.getOwnPropertyDescriptor`.
- **Lint rule:** [`legacy-accessor`](../tools/oxp-js-lint/rules.js) in
  `tools/oxp-js-lint/rules.js` (fixture: `tools/oxp-js-lint/fixtures/legacy-accessor.js` — see
  also `fixtures/catch-if.js` et al. for the sibling fixtures)

#### `expression-closure` — expression closures (JS1.8)

`function (x) x * x;` — a function whose body is a bare expression instead of a `{ ... }` block.
SpiderMonkey-only, removed in Firefox 60.

- **Removed:** the expression-body function form (both named and anonymous, and the arrow-like
  single-expression shorthand it predates).
- **Replacement:** `function (x) { return x * x; }`, or, on ES2015+, a real arrow function:
  `(x) => x * x`.
- **Lint rule:** [`expression-closure`](../tools/oxp-js-lint/rules.js) in
  `tools/oxp-js-lint/rules.js` (fixture: `tools/oxp-js-lint/fixtures/expression-closure.js`)

## Not covered by the automated scan (rewrite by inspection)

These two constructs are documented in the migration plan and in
[architecture.md §5.3](architecture.md#53-what-expansion-authors-will-need-to-change-the-guide)
but, unlike the eight above, have **no dedicated `oxp-js-lint` rule** as of this writing — file a
bead if you want one added:

| Construct | Replacement |
|---|---|
| `for each (var x in obj)` (JS1.6, SpiderMonkey-only, removed Firefox 47) | `for (var k in obj) { var x = obj[k]; }`, or `for (var x of obj)` if `obj` is iterable |
| Conditional re-declaration of a `const` in a loop/branch (SpiderMonkey allowed this loosely) | Standard `const` semantics — QuickJS-ng **throws** `SyntaxError: redeclaration of const` |

## Newly strict (silent bugs become errors)

QuickJS-ng runs your script in a stricter, ES2015+-conformant mode than SpiderMonkey 1.8.5 did.
Behaviour that SpiderMonkey silently tolerated or coerced now throws at parse time or at runtime:

- Duplicate parameter names in a function signature (`function f(x, x) {}`) — parse error.
- Legacy octal literals (`var n = 0755;`) — parse error. Use `0o755`.
- `with` statements inside a strict-mode script — parse error.
- Assigning to an undeclared variable creates an accidental global under SpiderMonkey's sloppy
  mode; under strict mode (the OXP scripts already opt in via `"use strict";`, and QuickJS-ng
  enforces it more completely) this throws `ReferenceError`.
- `arguments.callee` — throws in strict mode. Name your function and call it by name, or use a
  named function expression, instead of self-referencing through `arguments.callee`.

None of these have a dedicated `oxp-js-lint` rule (they are standard ES strict-mode behaviour, not
Mozilla-specific), but the C++-side `tools/deny-list.txt` deny-list (consumed by
`tools/tier-a.sh` and `tools/guardrails.sh`) enforces the equivalent discipline on the engine's own
C/C++ call sites: no reintroduced `JS_*`/`JSRuntime`/`JSContext`/`jsval` symbol once a file is
migrated off the SpiderMonkey C API.

## Measured differences between the engines (Phase 1 differential, bead oo-1gc.6)

These came out of running the goldens, the 36-group Tier-1 corpus and the JS API snapshot on
both engines (`tools/tier-c-diff.sh`, `tools/js_api_surface_compare.py`). The golden dumps were
byte-identical, and Oolite's own API surface matches the 1.93 contract with no differences
(ADR-0024). What an expansion can still observe:

- **Kept built in** ([ADR-0023](decisions/0023-built-in-mozilla-compat-polyfills.md)):
  - `toSource()` / `quote()` / `uneval()`, in the CompatShim's best-effort form rather than
    SpiderMonkey's exact source reflection;
  - the Array and String "generics" (`Array.forEach(list, fn)`, `String.replace(s, ...)`).

  Migrate away from them anyway: `JSON.stringify()`, `list.forEach(fn)`.
- **Removed, not polyfilled:**
  - `Object.prototype.watch` / `unwatch`;
  - E4X (`XML`, `XMLList`, `Namespace`, `QName`, `isXMLName`);
  - `Iterator` / `StopIteration`;
  - the `RegExp.$1`...`$9` statics;
  - `Date.prototype.toLocaleFormat`;
  - the `arity` / `caller` / `arguments` properties of functions;
  - `fileName` / `lineNumber` on error objects.
- **Assignment to a read-only native property** (for example `clock.seconds = 5`) is ignored in
  both sloppy and strict code. SpiderMonkey threw a `TypeError` in strict code; a script that
  relied on that exception was already failing.
- **A bare name in a script's closure** that refers to a property of the script object (not
  `this.name`, just `name`) resolves through the object the script file last ran for. That
  matters only when one script file runs for several objects, such as a ship script, and code
  uses bare names rather than `this.`.
- **More standard globals exist.** Scripts that list the global object see more names: a check
  for "global namespace pollution" reports `Map`, `Promise`, `globalThis` and others as
  unexpected.

## Newly available (opt-in, worth advertising to authors)

QuickJS-ng is a modern ES2023 engine. Once the migration lands, expansion scripts may use anything
in the standard language up to ES2023, none of which SpiderMonkey 1.8.5 supported:

- `let` / `const` (block-scoped, unlike the legacy `let` block/expression form above)
- Arrow functions: `(x) => x * 2`
- Template literals: `` `Commander ${name}` ``
- Classes (`class Foo extends Bar { ... }`)
- Destructuring assignment and parameters
- `Map` / `Set` / `WeakMap` / `WeakSet`
- `Promise`, `async`/`await`
- Spread/rest syntax (`...args`, `{...obj}`)
- Optional chaining (`obj?.prop`) and nullish coalescing (`a ?? b`)
- `Array.prototype.at`, and the rest of the ES2015–ES2023 standard library

## Related tooling

| Tool | Role |
|---|---|
| [`tools/oxp-js-lint/`](../tools/oxp-js-lint/README.md) | ESLint config + standalone runner implementing the eight detectors above; also has a `corpus` mode over the cached OXZ catalogue |
| `tools/oxp-js-lint/rules.js` | the eight detectors and their messages (source of truth for rule names used above) |
| `tools/oxp-js-lint/corpus-report.json` | the full per-expansion corpus scan result this guide's numbers are drawn from |
| `tools/deny-list.txt` | the equivalent C/C++-side deny-list for the engine's own migration off the SpiderMonkey API — not for OXP authors, listed here for completeness |
| bead oo-864 | compatibility-shim OXP polyfilling `toSource`/`quote` for expansions whose authors cannot update them |
