# Parity fixes still open (2026-11-07)

Measured on `seriesb/027-ship-library-keys` (ac60522c9), 2026-11-07. **Waiting for Jon's in-depth
review**; nothing here is scheduled yet. Source: the parity audit in
[docs/parity/README.md](../docs/parity/README.md), re-checked against the series tip. Line numbers
are on 027.

Already fixed on 027: both High findings (subentity updates, JS `delete` on native-backed
properties) and the Low memory-safety one (`quantityInHold[IndexOfGood]`, now guarded at
`PlayerEntity.cpp:11593`).

## Behaviour parity with upstream 1.93 (open Mediums)

Each one gets a test that fails before the fix and passes after, per the parity README's follow-ups.

1. **Preference defaults** (cross-cutting): add `Defaults::get<T>(key, fallback)` with `oo_*ForKey:defaultValue:` semantics (including upstream `OOBooleanFromObject` bool parsing). Replace the 11 multi-line `isNull()` sites: `GameController.cpp:229,287`, `OOALSound.cpp:63`, `OOLogging.cpp:233-243`, `Universe.cpp:304,334,342,351`. The worst is `animation_timer_interval` → 0, which spins the loop at ~10 kHz.
2. **Narrowed catch sites → `std::terminate`**: widen the main loop (`GameController.cpp:401`), AI (`AI.cpp:505`) and legacy-script catches to log-and-continue on `std::exception`, **and** fix the throwers: `.at(0)` at `PlayerEntity.cpp:6192` and `PlayerEntityControls.cpp:1375`, and the negative `howMany` at `Universe.cpp:2940`.
3. **JS error classes**: map QuickJS error kinds onto the `javascript-errors.plist` classes, or document the new `script.javaScript.exception.<Name>` scheme in `EXPANSION_MIGRATION.md` and drop the plist. `notAnError` is already gone: `LogProblem` (`OOJavaScriptEngine.cpp:697`) logs `script.javaScript.exception.<Error.name>`, but the plist is never consulted. Related: the obsolete `tools/JSErrorMunger` is being deleted in the migration-complete branch.
4. **Data cache rebuilt every launch**: compute mod-times from a single clock reading (`oofnd/FileSystem.hpp:181-182`). This is cheap and affects startup time for every user.
5. **Symlinked `.oxp`**: follow symlinks in `ResourceManager.cpp:500-502`. This matters on Mac/Linux, where users symlink OXPs.
6. `laserColor` shader uniform: add a row in `EntityShaderBindings.cpp:100`.
7. `EntityShortDescription` (`EntityHelpers.cpp:151`): restore the class and ship name in the log text.
8. Missile ident on a wormhole (`PlayerEntity.cpp:12932`): use `WormholeEntity::identFromShip`.
9. `EquipmentInfo.provides` returns `[]` instead of `null` (`OOJSEquipmentInfo.cpp:408`); `OORoleSet::anyRole` uses sorted order (`OORoleSet.cpp:154`). Decide on each and record the decision in the 4p doc. Default: match upstream for `provides`; keep the sorted order for roles, but document it alongside the other ⚠️ hash-order divergences.
10. `ship.speed` is writable: record the decision (there's a rationale comment at `OOJSShip.cpp:1719`) in the 4p Decisions section.
11. **Unify the two `doubleValue` ports** (`Defaults.hpp:171` and `PListGet.hpp:277`), plus the wrappers `String.hpp:1075`, `OOStringExpander.cpp:563` and `PlayerEntityLegacyScriptEngine.cpp:258`. Pick the GNUstep-faithful one, with a unit test on long mantissas and huge exponents.
12. Low-severity items: the log-text drift list in the parity README's cross-cutting item 4. Batch them in one pass.

Suggested order: 4, 5, 2 first (real user-facing bugs), then the rest.
