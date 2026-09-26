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

runs the same nine detectors below (masking comments/strings/regexes first, so quoting a banned
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

Each entry below is one of the nine detectors implemented in
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

#### `legacy-generator` — legacy (JS1.7) generators: `yield` in a plain `function`

```js
subs.each = function () { for (var i = 0; i < this.length; i++) yield this[i]; };
for (var sub in subs.each()) { sub.script.owner = this.ship; }
```

SpiderMonkey 1.8.5 made any function whose body contains `yield` a generator (Oolite ran it at
`JSVERSION_ECMA_5`, which is above the JS1.7 level that turns `yield` on), and `for (x in gen)`
over one iterated the *yielded values*. Removed from Firefox in version 58; no other engine has
either form. QuickJS-ng rejects the whole file (`SyntaxError: expecting ';'`), so the script never
runs. Found by the Tier-2/3 corpus run (beads oo-1gc.11, oo-1gc.16) in four ship scripts:
Thargoid.Wildships (`wildShips_tembo.js`), Thargoid.Aquatics (`aquatics_congerPods.js`) and
zzz.Montana05.Kestrel_Falcon (`bweed-kestrelfalcon-falcon.js`, `bweed-kestrelfalcon-kestrel.js`).
Those are the only files in the 818-expansion corpus that use it.

- **Removed:** generator semantics for a function not declared `function*`, and value iteration by
  `for...in` over a generator.
- **Replacement:** for a list, no generator at all:
  `this.ship.subEntities.forEach(function (sub) { ... }, this)` or
  `for (var i = 0; i < subs.length; i++) { var sub = subs[i]; ... }`. If you do want a generator,
  declare it `function* () { ... yield x; }` **and** iterate it with `for (var x of gen())`:
  `for...in` over a standard generator runs zero times, silently.
- **Lint rule:** [`legacy-generator`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/legacy-generator.js`)

## Not covered by the automated scan (rewrite by inspection)

These two constructs are documented in the migration plan and in
[architecture.md §5.3](architecture.md#53-what-expansion-authors-will-need-to-change-the-guide)
but, unlike the nine above, have **no dedicated `oxp-js-lint` rule** as of this writing — file a
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
- Creating a property on a primitive in strict code (`"use strict"; var s = "a"; s.x = 1;`) throws
  `TypeError: not an object`. SpiderMonkey 1.8.5 wrote it to a throwaway wrapper object and carried
  on, so the line did nothing. The usual cause is a `reduce()` callback that returns the value it
  assigned instead of the accumulator: write `m[k] = v; return m;`, not `return m[k] = v;`.

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
  `this.name`, just `name`) resolves through the script object of the handler call that is running,
  which for Oolite's own calls (event handlers, timers, the script's first run) is the object the
  closure was made for. Bead oo-1gc.15 fixed the case where one ship script file runs for several
  ships: before it, the name resolved through whichever ship ran the file last. It can still differ
  from SpiderMonkey when one ship's function is called directly from another ship's handler. Use
  `this.name` and it never matters.
- **More standard globals exist.** Scripts that list the global object see more names: a check
  for "global namespace pollution" reports `Map`, `Promise`, `globalThis` and others as
  unexpected.

## Tier 2 and Tier 3 corpus findings (bead oo-1gc.11)

The section above covers Tier 1 only. Bead oo-1gc.11 then loaded all 813 catalogue expansions
(Tier 3), plus the 150-expansion nightly Tier 2 subset, on the QuickJS-ng build. Each expansion was
loaded **solo**, twice, on two QuickJS-ng builds. Per-expansion results are in
[docs/phases/1-corpus-tier23-report.md](phases/1-corpus-tier23-report.md). No SpiderMonkey build is
left to compare against. So a failure counts as engine-independent only when its first error line
comes from code the engine swap did not touch: the ObjC data loaders, Oolite's own argument checks,
or the expansion's own message. Those failures are the rows below. They would fail the same way on
1.93 with SpiderMonkey, and nothing about them is specific to QuickJS-ng. Authors should still fix
them.

| class | what the log says | what the author changes | expansions (Tier 3 unless marked) |
|---|---|---|---|
| E1 | `TypeError: cannot read property '$addMarketInterface'` / `'$customCrosshairs'` / `'$addMissionScreenException'` / `'auctioneers' of undefined` | A world script is read from another expansion that is not installed. Declare it in `requires_oxps`, or guard the lookup: `if (worldScripts.x) ...`. | redspear.demand_driven_economy, redspear.alien_systems, redspear.new_lasers (Tier 2), KillerWolf.SothisTC, cim.new-cargoes |
| E2 | `Ship.setCargoType: Invalid arguments ... Can only be used on cargo pod carriers, not cargo pods (<ship>)`, thrown in `oolite-populator.js` | A ship given a trader or pirate role is defined as a cargo pod, so the populator's `setCargoType` call is rejected. Fix the `shipdata.plist` definition. The error only shows up when the ship happens to spawn. | Shipbuilder.ArachnidMark1 (Tier 2), .ChimeraGunship (Tier 2), .SerpentClassCruiser (Tier 2), .Fireball |
| E3 | `script.load.notFound` (`griff_spawn_wreckage.js`), `PlayerEntity.switchHudTo.failed` (`GETter_HUD.plist`) | A file named in the data does not exist in the expansion. Ship the file, or declare the expansion that provides it. | gsagostinho.TexturePack.FerDeLance, gsagostinho.TexturePack.Python, Reval.GETTER_HUD |
| E4 | `plist.parse.failed` (`missiontext.plist` and others) | Fix the property-list syntax. `plutil -lint` finds it. | Reval.Neutralizer, redspear.demand_driven_economy |
| E5 | `oxp.versionMismatch: ... is incompatible with version 1.93 of Oolite`, then NOTLOADED | The manifest's `maximum_oolite_version` (or `required_oolite_version`) excludes 1.93. Widen it after testing. | gsagostinho.DangerousKeyconfig, Lone_Wolf.ReduceWeaponDamage, phkb.LoadoutByCategory190 |
| E6 | `[XenonUI]: ERROR! No Xenon UI Resource packs installed` | Nothing: the expansion correctly reports a missing companion. Tier 1 pairs it with Pack A and it passes on both engines. | z.phkb.XenonUI (Tier 2) |
| E7 | `shipData.merge.failed` (unresolved `like_ship`), `shipData.load.error` (unresolved subentity, non-existent model), `oxp-standards.error: Likely missing a dependency` | Ship data refers to entries or models from an expansion that is not declared. Declare it in `requires_oxps`, or mark the entry `is_external_dependency`. Not the Norby.Carriers mechanism, which turned out to be E11. | DrNil.YAH-SetA to SetG (7), zzz.Montana05.GalTech_chimera_gunship_Fix, zzz.Montana05.GalTech_constitution_class_heavy_cruiser_Fix, ZygoUgo.noshaders_Asteroids, ZygoUgo.shadyAsteroids, amah.noshaders_extra_stations_addon, amah.noshaders_stations_for_sfep, smivs.classicVarietyPack, LittleBear.AssassinsGuildRebooted, Reval.Elite_Trader, Reval.Elite_Trader_Meta, Frame.FuelCollector, Svengali.Snoopers (Tier 2; its JS error is E8) |
| E8 | `TypeError: could not delete property`, from a strict-mode `for (var k in this) ... delete this[k]` that spares only `name` and `version` | A world script object carries `oolite_manifest_identifier`, which Oolite defines read-only and permanent, on SpiderMonkey as well. A strict `delete` of it threw there too. Skip it in the loop, as RobertTodd.Taranis and Wildeblood.Untrumbled do. The loop runs on the missing-dependency path, so the error appears when the expansion is installed without its companions. (bead oo-1gc.14) | Svengali.Snoopers (Tier 2) |
| E9 | `ReferenceError: X is not defined` for a name nothing declares, in strict code | The name was never a variable on any engine. UK_Eliter.InterstellarTweaks calls a method of one of its own `this.$...` objects without the object (`method(...)` for `this.$obj.method(...)`). The other three use an undeclared `for (k in obj)` loop variable in a `"use strict"` file or function (Taranis and Untrumbled on their missing-dependency path). Add the object, or declare the variable with `var`. (bead oo-1gc.15) | UK_Eliter.InterstellarTweaks (Tier 2), Norby.Towbar (Tier 2), RobertTodd.Taranis, Wildeblood.Untrumbled |
| E10 | `TypeError: not an object` at the top level of a world script, which is then dropped | Strict code creates a property on a string: a `reduce()` callback returns the key instead of the accumulator. SpiderMonkey 1.8.5 ignored the write silently, so the result was already wrong there. See "Newly strict". (bead oo-1gc.16) | Alnivel.RoutePlanner |
| E11 | `shipData.load.error: the shipdata.plist entry "<x>-carrier" has unresolved subentities <ship keys>`, each followed by `oxp-standards.error: Bad subentity definition found`, although every named key exists in core `shipdata.plist` | A **visual effect** (`effectdata.plist`) names **ship** keys as subentities. The loader resolves an effect's subentities only among effects, so the effect is dropped. The message says "shipdata.plist" because one routine serves both passes. Turning on `effectData.load.progress` shows which pass logged it. Define the entry in `shipdata.plist` if it needs ship subentities, or name only effect keys. Identical on SpiderMonkey 1.93. Tier 1 reports it as KNOWN through `tools/oxp-corpus/known-content-failures.json` ([ADR-0047](decisions/0047-corpus-known-content-failures.md), bead oo-1gc.7). | Norby.Carriers (Tier 1) |

The other 13 failures were JavaScript exceptions that might have been engine differences. Beads
oo-1gc.13 to oo-1gc.16 settled each one without reading expansion content, using the redacting
`tools/oxp-js-lint/probe.js`:

- **Engine differences, fixed in the facade (no author change):** `new Vector3D.random(n)` in the
  rock-chunk spawn scripts of Griff.Asteroids and two amah.noshaders ports (`TypeError: not a
  constructor`; SpiderMonkey let `new` call any native, oo-1gc.13), and a ship script reading a
  bare name for its own `this.` property (`ReferenceError`, zzz.Montana05.BUS_MegaBat, oo-1gc.15;
  see the bare-name bullet above).
- **Mozilla-only syntax:** legacy generators in Thargoid.Wildships, Thargoid.Aquatics and
  zzz.Montana05.Kestrel_Falcon, now the lint rule `legacy-generator` above (oo-1gc.16).
- **Content defects:** rows E8 to E10.

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
| [`tools/oxp-js-lint/`](../tools/oxp-js-lint/README.md) | ESLint config + standalone runner implementing the nine detectors above; also has a `corpus` mode over the cached OXZ catalogue |
| `tools/oxp-js-lint/rules.js` | the nine detectors and their messages (source of truth for rule names used above) |
| `tools/oxp-js-lint/corpus-report.json` | the full per-expansion corpus scan result this guide's numbers are drawn from |
| `tools/deny-list.txt` | the equivalent C/C++-side deny-list for the engine's own migration off the SpiderMonkey API — not for OXP authors, listed here for completeness |
| bead oo-864 | compatibility-shim OXP polyfilling `toSource`/`quote` for expansions whose authors cannot update them |
