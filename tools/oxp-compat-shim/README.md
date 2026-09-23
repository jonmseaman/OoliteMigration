# Compatibility shim OXP (bead oo-864)

`CompatShim.oxp` polyfills the SpiderMonkey-only `Object.prototype.toSource()` /
`Array.prototype.toSource()` / `String.prototype.quote()` / global `uneval()`
for expansions whose authors are unreachable and cannot update their scripts
for QuickJS-ng — the "to-source" and "quote-method" removals documented in
[`docs/EXPANSION_MIGRATION.md`](../../docs/EXPANSION_MIGRATION.md). It is the
interim relief promised there and in
[`docs/architecture.md` §5.3](../../docs/architecture.md#53-what-expansion-authors-will-need-to-change-the-guide),
item 2.

## Layout

```
CompatShim.oxp/
├── manifest.plist                          identifier org.oolite.oolite.compat-shim
├── requires.plist                          required_oolite_version = 1.93
├── Config/world-scripts.plist              single entry: the shim script
└── Scripts/oolite-compat-shim.js           the polyfill
selftest.js                                 offline Node self-test (no game build needed)
```

## Why "loaded first" needs no load-order trick

`ResourceManager +loadScripts` evaluates every world script's top-level body —
which is where this shim installs its polyfills — before
`PlayerEntity -doWorldScriptEvent:` dispatches the first event (`startUp`) to
*any* world script (`upstream/oolite/src/Core/ResourceManager.m`,
`upstream/oolite/src/Core/Entities/PlayerEntity.m`). So the polyfills exist
before an abandoned expansion's own `startUp()` or any later handler can call
`toSource()`/`quote()`, regardless of where in the OXP scan order this shim's
folder happens to sit. `Config/world-scripts.plist` (a single script, no
implicit alphabetical neighbours) still makes the shim the obvious place to
look for these methods in a JS API trace.

Each polyfill checks `typeof ... !== "function"` before defining itself, so
installing this OXP is a no-op wherever the engine already provides a native
implementation (the legacy SpiderMonkey backend, or any future engine that
adds one) — it never shadows or races a native method.

The output is a readable best-effort serialization, not byte-identical to
SpiderMonkey's source reflection (that needs a full source-reflecting
serializer); it is sufficient for the debug-logging / cache-key use case the
corpus scan actually found (`Library_1.10.5.oxz`, 3 occurrences — see
`docs/EXPANSION_MIGRATION.md`). Authors who need exact round-tripping should
still migrate to `JSON.stringify()`.

## Verifying it

```sh
node tools/oxp-compat-shim/selftest.js
```

Loads `Scripts/oolite-compat-shim.js` into a Node `vm` context the same way
`OOJSScript` evaluates a world script's top-level body (as a function called
against a private script object), against the real `Object`/`Array`/`String`
builtins — so no mock JS engine is needed. Covers: polyfills installed and
producing SpiderMonkey-shaped output (plain object, array, nested, circular
reference, `quote()`, `uneval()`), and — the one that matters most — that
pre-existing native implementations of all three are left completely
untouched.

```sh
node tools/oxp-js-lint/lint.js scan tools/oxp-compat-shim/CompatShim.oxp/Scripts
```

Flags the shim's own use of `toSource()`/`uneval()` inside its polyfill
*definitions* (calling `.toSource` as an identifier is what defines the
method, not a use of a removed construct) — expected and harmless here, since
this file's job under QuickJS-ng is precisely to define those names. Real
callers elsewhere in the corpus are what `docs/EXPANSION_MIGRATION.md`
tracks.
