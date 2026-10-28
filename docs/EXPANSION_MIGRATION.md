# Expansion (OXP/OXZ) migration guide: SpiderMonkey 1.8.5 → QuickJS-ng

**Audience:** anyone updating an expansion's JavaScript for the C++ Oolite: an author, or a
maintainer working through the [per-expansion notes](expansions/README.md). **Status:** Phase 1
deliverable ([ADR-0002](decisions/0002-quickjs-ng.md)). Rewritten 2026-10-27 from the expansion
compatibility scan ([ADR-0069](decisions/0069-expansion-compatibility-scan.md),
[report](phases/1-expansion-scan-report.md)).

Oolite's C++ port replaces the patched SpiderMonkey 1.8.5 engine (Firefox 4, 2011) with QuickJS-ng
(ES2023) behind a façade (`ooscript/JSEngine.hpp`). The goldens and the OXP corpus hold contracts
C1, C2, C4, C5 and C6 constant: save format, script discovery, the world-model API, rendering and
sound. **What changes is C3, the JavaScript language level.** It changes in three ways, and each
rule below says which applies:

1. **The script does not compile.** This is SpiderMonkey-only syntax. The game logs "compilation
   failed" and the whole script file is missing: every handler in it, not just one line.
2. **A line throws, or reads `undefined`.** This is a SpiderMonkey-only API.
3. **It runs with a different result.** Examples are output text, error wording, or a write that
   used to throw.

Every statement about QuickJS-ng below was checked against the game's own pinned engine
(quickjs-0.16.2) by `tools/oxp-js-parse/engine-probe.c`, not assumed.

## Where the catalogue stands (2026-10-27)

All 818 catalogued expansions (1,997 `.js` files) were checked. The full table is in
[docs/expansions/README.md](expansions/README.md), with one page per expansion that has a finding.

| | Expansions |
|---|---:|
| A script no longer compiles (legacy generators): Wildships, Aquatics, Kestrel_Falcon | 3 |
| A script never compiled on any engine (grammar errors): Defence_Rider_Drones, Neutralizer, Hints | 3 |
| Runs with a different result: Library, redspear.equipment_by_ship_class, Stealth, TCAT | 4 |
| Worth a look, no visible change: GalCopMissions, Cag.station_options, Telescope | 3 |
| No finding | 614 |
| No JavaScript | 191 |

## How to check and fix an expansion

1. **Unpack it.** An `.oxz` is a zip.
2. **Does every script compile?**

   ```sh
   bash tools/oxp-js-parse/build.sh
   node tools/oxp-js-parse/run.js scan path/to/Expansion/Scripts
   ```

   This compiles each file with the game's own QuickJS-ng, the way the game loads it. A line
   marked `plain` means the script does not exist in the game: fix it first. A `strict-only` line
   breaks only when standards enforcement is on.
3. **Does anything run differently?**

   ```sh
   node tools/oxp-js-lint/compat.js scan path/to/Expansion/Scripts
   node tools/oxp-js-lint/lint.js scan path/to/Expansion/Scripts
   ```

   Each finding names a rule. Find the rule's section below.
4. **Fix**, using the rule's **Replacement**. For a catalogued expansion, its page in
   [docs/expansions/](expansions/README.md) lists every finding as a checklist.
5. **Load it in the game.** Copy it into `AddOns/`, start the game, and look in `Latest.log` for
   `compilation failed`, `TypeError` and `ReferenceError`. For a catalogued expansion,
   `tools/corpus.sh tier3 --only <name> --app-dir <build>` does the same load and judges the log.
6. **Bump the version** in `manifest.plist`. If the code now relies on QuickJS-ng behaviour, raise
   `required_oolite_version` too.

The checkers mask comments, strings and regular expressions first, so a construct that is only
mentioned there is never flagged.

## Severity

| Severity | Meaning |
|---|---|
| **BREAKS** | The script does not compile, or the line throws. Players see the expansion fail. |
| **CHANGED** | It runs, but the result differs from SpiderMonkey's. |
| **INFO** | Worth a look. It breaks only in a mode players do not run by default, or the checker cannot tell (for example, a field that happens to share a removed API's name). |

## Syntax that no longer compiles (BREAKS)

The game's QuickJS-ng rejects the whole file. Nine detectors live in
[`tools/oxp-js-lint/rules.js`](../tools/oxp-js-lint/rules.js) (`DETECTORS`), and the compat
detectors live in [`tools/oxp-js-lint/compat-rules.js`](../tools/oxp-js-lint/compat-rules.js)
(`COMPAT_DETECTORS`). The compile itself is `tools/oxp-js-parse`.

<a id="rule-for-each"></a>
#### `for-each` — `for each (var x in obj)` (JS1.6)

Value iteration over an object's properties. SpiderMonkey-only; removed from Firefox in version 47.
QuickJS-ng: `SyntaxError: Unexpected identifier 'each'`.

- **Replacement:** `for (var k in obj) { var x = obj[k]; ... }`, or `for (var x of list)` for an
  array.
- **Lint rule:** [`for-each`](../tools/oxp-js-lint/compat-rules.js) in
  `tools/oxp-js-lint/compat-rules.js` (fixture: `tools/oxp-js-lint/fixtures-compat/for-each.js`)
- **Corpus:** none.

<a id="rule-catch-if"></a>
#### `catch-if` — conditional catch clause

`catch (e if cond) { ... }` (JS1.5). Removed from Firefox in version 59. No other engine ever
implemented it.

- **Removed:** the `if` guard on a `catch` clause. This is syntax, so the parse fails before the
  script runs.
- **Replacement:** `catch (e) { if (cond) { ... } else { throw e; } }`
- **Lint rule:** [`catch-if`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/catch-if.js`)

<a id="rule-e4x"></a>
#### `e4x` — E4X / ECMA-357 (XML literals, `..` descendant, `.@` attribute)

`var x = <ship><name>Cobra</name></ship>; var n = x..name;`. Removed from SpiderMonkey in Firefox
21. Never implemented in V8, JSC or QuickJS.

- **Removed:** XML literal syntax and the `..` / `.@` operators.
- **Replacement:** plain objects and arrays.
- **Lint rule:** [`e4x`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/e4x.js`)

<a id="rule-let-block"></a>
#### `let-block` — `let` block / `let` expression (JS1.7)

`let (x = 1) { ... }`. Removed from Firefox in version 44.

- **Removed:** the parenthesised `let (...)` form.
- **Replacement:** a block with a standard `let`: `{ let x = 1; ... }`.
- **Lint rule:** [`let-block`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/let-block.js`)

<a id="rule-expression-closure"></a>
#### `expression-closure` — expression closures (JS1.8)

`function (x) x * x`: a function whose body is a bare expression. Removed from Firefox in
version 60.

- **Removed:** the expression-body function form.
- **Replacement:** `function (x) { return x * x; }`, or an arrow function `(x) => x * x`.
- **Lint rule:** [`expression-closure`](../tools/oxp-js-lint/rules.js) in
  `tools/oxp-js-lint/rules.js` (fixture: `tools/oxp-js-lint/fixtures/expression-closure.js`)

<a id="rule-legacy-generator"></a>
#### `legacy-generator` — `yield` in a plain `function` (JS1.7)

```js
subs.each = function () { for (var i = 0; i < this.length; i++) yield this[i]; };
for (var sub in subs.each()) { sub.script.owner = this.ship; }
```

SpiderMonkey 1.8.5 made any function containing `yield` a generator. A `for...in` over it iterated
the yielded values. Removed from Firefox in version 58. QuickJS-ng: `SyntaxError: expecting ';'`.
**Found in the corpus:** Thargoid.Wildships (`wildShips_tembo.js`), Thargoid.Aquatics
(`aquatics_congerPods.js`) and zzz.Montana05.Kestrel_Falcon (`bweed-kestrelfalcon-falcon.js`,
`bweed-kestrelfalcon-kestrel.js`). These are the only expansions this migration breaks outright.

- **Removed:** generator semantics for a function not declared `function*`, and value iteration by
  `for...in` over a generator.
- **Replacement:** iterate the list directly:
  `this.ship.subEntities.forEach(function (sub) { ... }, this)`. If you want a generator, declare
  `function* () { ... }` **and** iterate it with `for (var x of gen())`. A `for...in` over a
  standard generator runs zero times, silently.
- **Lint rule:** [`legacy-generator`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/legacy-generator.js`)

<a id="rule-syntax-other"></a>
#### `syntax-other` — a compile error no rule names

The parse layer reports any file the game's QuickJS-ng cannot compile. A failure that no detector
explains is `syntax-other`. There are two kinds:

- **`const` redeclaration** (`const A = 1; const A = 2;`). SpiderMonkey tolerated it; QuickJS-ng
  gives `SyntaxError: invalid redefinition of lexical identifier`. **Replacement:** declare it once,
  or use `var`. No corpus file does this.
- **Plain grammar errors** that fail on every engine: an unbalanced bracket, or an assignment to a
  literal. They are not migration regressions: the script never loaded on SpiderMonkey either.
  **Found in the corpus:** Reval.Defence_Rider_Drones (`police_call_AI.js:195`), Reval.Neutralizer
  (`npc-npb.js:112`), Cholmondely.Hints (`Hints_GNN.js:71`). Their pages give the diagnosis.

- **Replacement:** fix the error at the reported line. The engine message names the problem.
- **Lint rule:** none. This is the parse layer, `tools/oxp-js-parse/run.js` (fixture:
  `tools/oxp-js-parse/fixtures/const-redeclare.js`).

## APIs that are gone

<a id="rule-removed-api"></a>
#### `removed-api` — SpiderMonkey-only objects and properties

Each name was checked against the game's bare QuickJS-ng:

| Name | On QuickJS-ng | Severity | Replacement |
|---|---|---|---|
| `obj.watch(prop, fn)` / `unwatch` | `undefined`: calling it throws `TypeError` | BREAKS | a setter (`Object.defineProperty`), or check the value where it is used |
| `Iterator(obj)` | **the name exists**, as the ES2025 `Iterator` class. Calling it throws `TypeError: constructor requires 'new'`, and a `typeof Iterator` test now passes and takes the wrong branch | BREAKS | `Object.keys(obj)` with `for...of`, or `for (var k in obj)` |
| `StopIteration` | not defined: `ReferenceError` | BREAKS | the iterator's `done` flag |
| `date.toLocaleFormat(fmt)` | `undefined`: `TypeError` | BREAKS | build the string from `getFullYear()` and friends |
| `__noSuchMethod__` | not honoured: calling a missing method throws `TypeError` | BREAKS | check `typeof obj.m === "function"` before calling |
| `RegExp.$1`…`$9`, `RegExp.lastMatch` and the other statics | `undefined` | CHANGED | use the array `exec()` or `match()` returns |
| `fn.caller` | `undefined` in sloppy code (SpiderMonkey returned the calling function); `TypeError` in strict code | CHANGED on a known function, else INFO | pass what you need as an argument |
| `fn.arity` | `undefined` | CHANGED on a known function, else INFO | `fn.length` |
| `err.fileName`, `err.lineNumber` | `undefined` | CHANGED on a caught error, else INFO | `err.stack` carries file and line |
| `obj.__count__`, `obj.__parent__` | `undefined` | CHANGED | `Object.keys(obj).length`; no replacement for `__parent__` |
| `__iterator__` | not honoured: `for...in` lists `__iterator__` itself as a key | CHANGED | an explicit list, or a `function*` with `for...of` |

`caller`, `arity`, `fileName` and `lineNumber` are also common names for an expansion's own fields.
The checker therefore reports them as CHANGED only on a declared function, `arguments.callee`, or a
caught error, and as INFO elsewhere. **Found in the corpus:** `caller` in Library (its own option
field: no change), and in the debug stack-walkers of Cag.station_options and Telescope (debug output
only).

- **Replacement:** see the table.
- **Lint rule:** [`removed-api`](../tools/oxp-js-lint/compat-rules.js) in
  `tools/oxp-js-lint/compat-rules.js` (fixtures: `tools/oxp-js-lint/fixtures-compat/removed-api.js`,
  `removed-api-ambiguous.js`)

## Kept through the game's polyfills (CHANGED)

[ADR-0023](decisions/0023-built-in-mozilla-compat-polyfills.md) has `oolite-global-prefix.js`
install these before any script runs. **They work**, but their output is the polyfill's
best-effort text, not SpiderMonkey's exact source reflection. Code that only logs the result is
fine. Code that compares or parses it may change.

<a id="rule-to-source"></a>
#### `to-source` — `Object.prototype.toSource()` / `Array.prototype.toSource()`

SpiderMonkey-only source reflection, removed from Firefox in version 74. A bare QuickJS-ng does
not have it; the game polyfills it. **Found in the corpus:** Library (`Lib_Main.js`, `lib_test.js`).

- **Replacement:** `JSON.stringify(obj)` for data objects.
- **Lint rule:** [`to-source`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/to-source.js`). The compat set reports it as
  `polyfill-approx`.

<a id="rule-uneval"></a>
#### `uneval` — the global `uneval()`

SpiderMonkey-only, removed from Firefox in version 74. The game polyfills it.

- **Replacement:** `JSON.stringify(value)`.
- **Lint rule:** [`uneval`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/uneval.js`)

<a id="rule-quote-method"></a>
#### `quote-method` — `String.prototype.quote()`

SpiderMonkey-only, removed from Firefox in version 37. The game polyfills it.

- **Replacement:** `JSON.stringify(s)`, which is the standard quoted, escaped string.
- **Lint rule:** [`quote-method`](../tools/oxp-js-lint/rules.js) in `tools/oxp-js-lint/rules.js`
  (fixture: `tools/oxp-js-lint/fixtures/quote-method.js`)

<a id="rule-polyfill-approx"></a>
#### `polyfill-approx` — any of the above, plus the Array/String generics

The compat set's single rule for everything the game polyfills: `toSource()`, `uneval()`,
`.quote()`, and the SpiderMonkey "generics" `Array.forEach(list, fn)` and `String.replace(s, …)`.
The generics are reported as INFO, because their polyfill behaves like the original.

- **Replacement:** `JSON.stringify(...)`; `list.forEach(fn)`; `s.replace(...)`.
- **Lint rule:** [`polyfill-approx`](../tools/oxp-js-lint/compat-rules.js) in
  `tools/oxp-js-lint/compat-rules.js` (fixture: `tools/oxp-js-lint/fixtures-compat/polyfill-approx.js`)

## Still works

<a id="rule-legacy-accessor"></a>
#### `legacy-accessor` — `__defineGetter__` / `__defineSetter__` / `__lookupGetter__` / `__lookupSetter__`

**Correction (2026-10-27):** earlier versions of this guide listed these as removed. QuickJS-ng
implements them (ECMAScript Annex B), and they behave as on SpiderMonkey. **Found in the corpus:**
GalCopMissions (`Resources/PhraseGen.js`), with no change.

- **Removed/deprecated:** deprecated, not removed.
- **Replacement (optional):** `Object.defineProperty(obj, "prop", { get: ..., set: ... })` /
  `Object.getOwnPropertyDescriptor`.
- **Lint rule:** [`legacy-accessor`](../tools/oxp-js-lint/rules.js) in
  `tools/oxp-js-lint/rules.js` (fixture: `tools/oxp-js-lint/fixtures/legacy-accessor.js`)

## Behaviour that changed

<a id="rule-readonly-native-write"></a>
#### `readonly-native-write` — assigning a read-only Oolite property

`player.ship.fuelChargeRate = 2;`, `this.ship.alertCondition = 3;`. The
[1.93 API contract](../oxp-contract/js-api-1.93.json) marks these read-only, so **the write never
took effect on either engine**. What changed is what happens next. In strict code SpiderMonkey threw
`TypeError`, which aborted the event handler at that line. QuickJS-ng ignores the write, even in
strict code, and the handler carries on. **Found in the corpus:** redspear.equipment_by_ship_class
(35 writes to `extraCargo`, `fuelChargeRate`, `renovationMultiplier`), Thargoid.Stealth and
Thargoid.TCAT (`this.ship.alertCondition`). All of them are in strict code.

The checker only fires through a receiver whose class it knows: `player`, `player.ship`,
`this.ship`, `system`, `system.mainStation`/`mainPlanet`/`sun`, and `clock`. Names such as `count`
or `price` are read-only on Oolite classes but common as expansions' own fields.

- **Replacement:** delete the write, since it never did anything. Use the API that really changes
  the value, if there is one (for example, equipment rather than a ship property).
- **Lint rule:** [`readonly-native-write`](../tools/oxp-js-lint/compat-rules.js) in
  `tools/oxp-js-lint/compat-rules.js` (fixture: `tools/oxp-js-lint/fixtures-compat/readonly-native-write.js`)

<a id="rule-strict-only"></a>
#### `strict-only` — constructs that fail only in strict code

Checked on the game's engine:

| Construct | Sloppy code | Strict code |
|---|---|---|
| `arguments.callee` | works | `TypeError` |
| legacy octal `0755` | works | does not compile |
| duplicate parameters `function (a, a)` | works | does not compile |
| `with (obj) { ... }` | works | does not compile |
| property write on a primitive, `s.x = 1` | ignored | `TypeError: not an object` (E10) |
| assignment to an undeclared name | creates a global | `ReferenceError` (E9) |

In a file that starts with `"use strict"`, the checker reports BREAKS. Elsewhere it reports INFO:
the code breaks only if the game's standards enforcement prepends `"use strict"`
(`OOEnforceStandards()`, off by default). **Corpus:** none.

- **Replacement:** name the function and call it by name; write octal as `0o755`; rename the
  duplicate parameter; replace `with` by explicit property access.
- **Lint rule:** [`strict-only`](../tools/oxp-js-lint/compat-rules.js) in
  `tools/oxp-js-lint/compat-rules.js` (fixtures: `tools/oxp-js-lint/fixtures-compat/strict-only.js`,
  `strict-only-sloppy.js`)

<a id="rule-fn-tostring"></a>
#### `fn-tostring` — reading a function's source text

`handler.toString()` or `String(handler)`. SpiderMonkey 1.8.5 returned **decompiled, reformatted**
source. QuickJS-ng returns the **original text**. A hash, cache key or comparison built from it
changes. **Corpus:** none.

- **Replacement:** do not depend on a function's text. Key by a name you choose.
- **Lint rule:** [`fn-tostring`](../tools/oxp-js-lint/compat-rules.js) in
  `tools/oxp-js-lint/compat-rules.js` (fixture: `tools/oxp-js-lint/fixtures-compat/fn-tostring.js`)

<a id="rule-error-message"></a>
#### `error-message` — matching on an error's message text

The wording is engine-specific. For example, QuickJS-ng says `cannot read property 'x' of null`.
Code that compares or searches `e.message` takes a different branch. **Corpus:** none.

- **Replacement:** test the type, not the wording: `e instanceof TypeError`, `e.name === "TypeError"`.
- **Lint rule:** [`error-message`](../tools/oxp-js-lint/compat-rules.js) in
  `tools/oxp-js-lint/compat-rules.js` (fixture: `tools/oxp-js-lint/fixtures-compat/error-message.js`)

<a id="rule-global-enum"></a>
#### `global-enum` — listing the global object

QuickJS-ng's global object also holds `BigInt`, `Iterator`, `Map`, `Promise`, `Proxy`, `Reflect`,
`Set`, `Symbol`, `WeakMap`, `globalThis` and more. A "global namespace pollution" check reports them
as unexpected. **Found in the corpus:** Library (`Lib_Main.js`), INFO.

- **Replacement:** compare against a baseline taken at startup, not a fixed list.
- **Lint rule:** [`global-enum`](../tools/oxp-js-lint/compat-rules.js) in
  `tools/oxp-js-lint/compat-rules.js` (fixture: `tools/oxp-js-lint/fixtures-compat/global-enum.js`)

## Other differences no rule detects

- **A bare name in a script's closure** that refers to a property of the script object (`name`, not
  `this.name`) resolves through the script object of the handler call that is running. Bead
  oo-1gc.15 made this match SpiderMonkey for Oolite's own calls. It can still differ when one ship's
  function is called directly from another ship's handler. Use `this.name` and it never matters.
- **Sort stability, `for...in` order over dictionaries the game hands over** (they now arrive in
  key order, [ADR-0051](decisions/0051-js-native-values-as-plist.md)), **`Math.random` sequences and
  `Date` string formats** may differ. No text rule can see whether a script depends on them. The
  behavioural differential (the next pass in ADR-0069) measures them.

## Load-time content defects (bead oo-1gc.11)

Bead oo-1gc.11 loaded all 813 catalogue expansions on QuickJS-ng, each one solo
([report](phases/1-corpus-tier23-report.md)). The failures below come from code the engine swap did
not touch: the data loaders, Oolite's own argument checks, or the expansion's own messages. They
fail the same way on 1.93 with SpiderMonkey. Authors should still fix them.

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
| E10 | `TypeError: not an object` at the top level of a world script, which is then dropped | Strict code creates a property on a string: a `reduce()` callback returns the key instead of the accumulator. SpiderMonkey 1.8.5 ignored the write silently, so the result was already wrong there. See [`strict-only`](#rule-strict-only). (bead oo-1gc.16) | Alnivel.RoutePlanner |
| E11 | `shipData.load.error: the shipdata.plist entry "<x>-carrier" has unresolved subentities <ship keys>`, each followed by `oxp-standards.error: Bad subentity definition found`, although every named key exists in core `shipdata.plist` | A **visual effect** (`effectdata.plist`) names **ship** keys as subentities. The loader resolves an effect's subentities only among effects, so the effect is dropped. The message says "shipdata.plist" because one routine serves both passes. Turning on `effectData.load.progress` shows which pass logged it. Define the entry in `shipdata.plist` if it needs ship subentities, or name only effect keys. Identical on SpiderMonkey 1.93. Tier 1 reports it as KNOWN through `tools/oxp-corpus/known-content-failures.json` ([ADR-0047](decisions/0047-corpus-known-content-failures.md), bead oo-1gc.7). | Norby.Carriers (Tier 1) |

Beads oo-1gc.13 to oo-1gc.16 settled 13 further JavaScript exceptions from that run without reading
expansion content:

- Two were engine differences, **fixed in the façade**:
  - `new` on a native function (`new Vector3D.random(n)`) in Griff.Asteroids and two
    amah.noshaders ports, fixed by oo-1gc.13;
  - a bare-name read in zzz.Montana05.BUS_MegaBat, fixed by oo-1gc.15.
- The legacy generators were **Mozilla-only syntax** ([`legacy-generator`](#rule-legacy-generator)).
- The rest were **content defects**, rows E8 to E10.

## Newly available

QuickJS-ng implements ES2023. Expansion scripts may use any of it, none of which SpiderMonkey 1.8.5
had:

- `let` / `const`
- arrow functions
- template literals
- classes
- destructuring
- `Map` / `Set` / `WeakMap` / `WeakSet`
- `Promise` and `async`/`await`
- spread and rest
- optional chaining (`a?.b`) and nullish coalescing (`a ?? b`)
- the ES2015–ES2023 standard library

An expansion that uses them needs this engine, so raise its `required_oolite_version`.

## Related tooling

| Tool | Role |
|---|---|
| [`tools/oxp-js-parse/`](../tools/oxp-js-parse/README.md) | compiles scripts with the game's own QuickJS-ng (`scan`, `corpus`), plus `engine-probe.c`, the API ground truth behind the tables above |
| [`tools/oxp-js-lint/`](../tools/oxp-js-lint/README.md) | `rules.js` (the nine Mozilla-only detectors, `lint.js`) and `compat-rules.js` (the compat set, `compat.js`), both with fixtures and self-tests |
| [`tools/oxp-scan/`](../tools/oxp-scan/notes.py) | `notes.py` builds the [per-expansion notes](expansions/README.md) from the reports; `diagnoses.json` holds the reviewed diagnoses |
| `tools/oxp-js-lint/probe.js` | a redacted view of one line of a corpus script, for triage without reading it |
| `tools/oxp-compat-shim/` | the standalone shim OXP, now redundant with the built-in polyfills (ADR-0023) |
| `tools/deny-list.txt` | the C/C++ deny-list for the engine's own code. It is not for authors. |
