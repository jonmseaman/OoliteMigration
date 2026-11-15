# TypeScript for Oolite scripting: assessment

Status: assessment only, not scheduled. Paths are relative to `oolite-dev`.

## Recommendation

- **Don't make the engine run `.ts` files.** Let authors write TypeScript and ship JavaScript: publish a `.d.ts` for the Oolite JS API and have `tsc` compile `.ts` to ES2015 `.js`, which the game already loads. Most of what TypeScript offers (completion, type errors against the API) comes from the typings, not the engine.
- **Effort:** about 1–2 weeks, mostly typing about 40 `OOJS*` classes. Engine changes: none.
- **Don't convert the built-in scripts.** The 55 files in `Resources/Scripts` and `Resources/AIs` (about 20k lines) stay `.js`. Type-check them in place with `checkJs`. Converting them would be churn: legacy `with(this)` scoping, and the files must stay at parity with upstream.

## How scripts load now

- **Engine:** QuickJS-ng v0.17.0 (`third_party/quickjs-0.17.0`). It cannot parse TypeScript.
- **Loading:** `OOJSScript::RunScriptWithName()` (`src/Core/Scripting/OOJSScript.cpp:699`) runs these steps in order:
  1. Reads the file. This also works inside `.oxz` archives.
  2. Runs `RewriteLegacyConst()` on scripts without `"use oolite modern"`.
  3. Wraps the source, as `with(this)` or as a modern closure.
  4. Compiles with `JS_Eval(COMPILE_ONLY)`.
  5. Caches the bytecode. The cache key is a hash of the wrapped source, plus the engine version and format.
- **Names:** script names must end in `.js` or `.es` (`OOScript.cpp:206`). World scripts are `script.js` or `script.es` (`OOScript.cpp:88-93`). Only AI names get `.js` appended (`ShipEntityAI.cpp:130-141`).
- **Existing typings:** none (no `.d.ts`, no `tsconfig`, no JSDoc).
- **Node:** used only for `tools/oxp-upgrade` (its own CI job in `.github/workflows/build-all.yaml:73-89`) and eslint (ES2015, `es-x`).

## Why the engine shouldn't run `.ts`

- **Engine:** QuickJS-ng would need a transpiler embedded alongside it, such as Sucrase or a type-stripper running inside QuickJS, or a hand-written C++ stripper. That adds a dependency, a new kind of load error, and a TypeScript dialect fixed in the game.
- **Upstream:** it only exists in the fork, while the current work is polishing the fork for upstream.
- **Who benefits:** no existing OXP. Expansions would still ship `.js`.
- **Cost:** about 1–2 weeks to make it work, plus maintenance after that.

## Plan if scheduled (authoring-time TypeScript)

Run it as a Spec Kit feature, e.g. `specs/016-ts-typings`.

1. **Skeleton generator.** A Python script in `tools/typings/` reads the property and function tables in `src/Core/Scripting/OOJS*.cpp`. It emits an interface per class with every member typed `any`. The tables are the source of truth, which keeps the typings from drifting.
2. **Hand typing.** Write `oolite.d.ts` with:
   - the globals (`player`, `system`, `missionVariables`, `worldScripts`, `log`, `expandDescription`, …);
   - the classes (Ship, Station, Player, PlayerShip, System, SystemInfo, Mission, Vector3D, Quaternion, Timer, Sound, …);
   - the world-script and ship-script event handlers (`startUp`, `shipWillLaunchFromStation`, …);
   - a `this` type for scripts.
3. **Template.** A `tsconfig.json` (`target`/`lib` ES2015) and a small example OXP written in `.ts` that compiles to `Scripts/script.js`.
4. **New tests.**
   - `tsc --noEmit` with `checkJs` over `Resources/Scripts/*.js` and the example. It fails without the typings and passes with them.
   - A component test (e.g. `tests/component-cpp/test_js_typings_drift.cpp`) that lists each runtime prototype's own properties through QuickJS and diffs them against the names in the `.d.ts`. It fails when the API gains a member the typings lack.
5. **CI.** A Node job next to `oxp-upgrade`, with `typescript` pinned in `tools/typings/package.json`.
6. **Later, optional.** `tools/oxp-upgrade` emits JSDoc types, or a `--to-ts` mode.

The plan doesn't touch `OOJSScript.cpp`, `OOScript.cpp` or `ResourceManager.cpp`.

### Verification

- `npx tsc -p tools/typings/check --noEmit` fails before the typings exist and passes after.
- The drift test passes, and fails if a property is removed from the `.d.ts`.
- The example OXP, compiled with `tsc`, loads in a smoke run and logs from `startUp`.
- `tests/run.sh unit` and `tests/run.sh component` are unchanged.

## If the engine must run `.ts` after all

- Accept `.ts` in `OOScript.cpp:206`, and `script.ts` in `worldScriptsAtPath`.
- In `RunScriptWithName`, strip the types before `RewriteLegacyConst` and wrapping. Use a stripper that keeps positions (blanking types to whitespace) so error line numbers stay right.
- The bytecode cache absorbs the transpile cost after the first load.
- Ship the stripper as a JS resource that runs inside QuickJS, the way `oolite-quickjs-compat.js` does.
