# Phase 3 — Objective-C → C++20 conversion

**Status:** not started · **Est.:** 12–24 eng-months · **Depends on:** [Phase 1](1-js-engine.md) and [Phase 2](2-oofnd.md)
**Runs in parallel with:** partly with itself (independent modules), under the freeze policy.

## Goal

The long grind: ~500 files, leaves inward, one module per merge batch, goldens green at every step.
Conservative **C++20** only ([ADR-0001](../decisions/0001-bridge-then-convert.md),
[ADR-0011](../decisions/0011-cpp20-then-cpp23.md)); the C++23 upgrade is Phase 6; intrusive refcounting
only ([ADR-0003](../decisions/0003-intrusive-refcount.md)); modernisation waits for Phase 6. This is
the largest fan-out phase and the least seam-bound, and it is the phase the meta-experiment
([I4 metrics](../infra/4-metrics.md)) is really about.

## Entry gate

- [ ] Phase 1 and Phase 2 exit gates green
- [ ] **Exemplars exist:** `OOColor` and `Core/OXPVerifier` converted by a frontier agent in an interactive session. They set the house style every generated story references. **Do not fan out before this.** Fanning out first yields 200 files in 200 styles and a review burden larger than the original work. (`oomath` is not the exemplar: it has no classes, [ADR-0012](../decisions/0012-c-stays-c.md).)
- [ ] Tier A measured < 30 s on a converted leaf file
- [ ] Freeze policy per module in force ([architecture §6.3](../architecture.md) item 5); `docs/UPSTREAM_DELTA.md` exists

## Exit gate

- [ ] Zero `@implementation` in `src/` (`grep -rc '@implementation' src` is 0)
- [ ] Every `.m` file that had no `@implementation` is now `.c`, byte-for-byte the same code ([ADR-0012](../decisions/0012-c-stays-c.md))
- [ ] All goldens reproduce; Tier-1 corpus green; ASan clean; Windows clean at `-Wall -Wextra`
- [ ] The six giant files converted (frontier + human; tracked individually in the status log)

## Seams

| Seam | Produces (exemplar path) | Owner |
|---|---|---|
| `OOColor` conversion: the first class, establishes house style | `src/Core/OOColor.h/.mm` + `OOColor+ObjCBridge.h/.mm`, `tests/unit/core/test_OOColor.mm` ([ADR-0056](../decisions/0056-phase3-class-conversion-house-style.md); done, oo-11m) | Frontier agent, days |
| `Core/OXPVerifier` conversion (real class hierarchy pilot, 27 files, own test data) | `src/oxp/verifier/` | Frontier agent |
| Per-module pattern for each of: `Materials`, `ooaudio`, `ooscript` bindings, `ooentity` base | one converted file per module | Frontier agent |
| The six giant files (`ShipEntity` 14,945 · `PlayerEntity` 13,718 · `Universe` 11,297 · `PlayerEntityControls` 5,690 · `HeadUpDisplay` 4,497 · `OOJSShip` 4,399) | themselves | **Frontier agent, weeks each, category file by category file.** 200k+ token closures; not fleet work. |
| Pre-splitting files > 400 lines into story-sized slices (category files already do this for `PlayerEntity`) | a slice plan per file: `docs/phases/3-slices/<File>.md`, checked by `python3 tools/check-slice-plan.py <plan>` (every method/function in exactly one slice or verbatim; each slice reads < 1,500 lines) | frontier |

## Sweeps

| Sweep | Unit | Inventory command | Exemplar | Est. stories | Ordering |
|---|---|---|---|---:|---|
| `.m` → `.c` renames (no `@implementation`) | one file | `grep -L '@implementation' $(find src -name '*.m')` | — | ~10 | first; mechanical |
| Leaf files ≤ 400 lines | one file | `grep -l '@implementation' $(find src -name '*.m' -size -20k)` | `oomath` / `OXPVerifier` files | ~138 at 1 each | module order below |
| Files 400–1,500 lines | one pre-split slice | slice plans | per-module exemplar | ~62 × 1.5 + 30 × 3 | after the module's pattern seam |
| Files 1,500–4,000 lines (19 files, 22% of lines) | frontier, one at a time | Appendix A | — | ~11 × 7 | real design content in each |

Total ≈ 400 stories, inside the 240–960 band from the effort estimate.

## Work items (module order)

Suggested order (dependency-driven, and it front-loads the pattern-setting work):

1. `oomath` — `OOVector`, `OOHPVector`, `OOMatrix`, `OOQuaternion`, `OOTriangle`: **rename to
   `.c`, do not convert** ([ADR-0012](../decisions/0012-c-stays-c.md)). `Octree` is a real class
   and joins step 3. House style is set by `OOColor` then `OXPVerifier`.
2. `Core/OXPVerifier` — 27 files, standalone, has its own test data. The ideal pilot for a *real*
   class hierarchy.
3. Leaf utilities — `OOColor`, `OOCache`, `OORoleSet`, `OOProbabilitySet`, `OOPriorityQueue`,
   `OOCommodities`, `OOEquipmentType`, `OOCharacter`.
4. `Materials` / `oorender` (47 files) — self-contained behind `OODrawable`/`OOMaterial`.
5. `ooaudio` — the `OOAL*` family; already a thin OpenAL wrapper.
6. `ooscript` — the ~45 JS binding classes. Voluminous but repetitive; the façade from Phase 1
   already isolates the engine.
7. `ooentity` — `Entity` → `OOEntityWithDrawable` → `ShipEntity` → `StationEntity`/`PlayerEntity`.
   **`ShipEntity` (14,945 lines, 186 ivars, 565 methods) and `PlayerEntity` (13,718 lines) are the
   hardest artefacts in the project.** Budget real time. The existing category split
   (`PlayerEntityControls`, `PlayerEntityContracts`, `PlayerEntityLoadSave`, …) translates directly
   to member functions defined across multiple `.cpp` files, so the file decomposition survives.
8. `Universe` (11,297 lines, 122 ivars, 302 methods) — last. Everything points at it.

### Per-file recipe

| Objective-C | C++20 |
|---|---|
| `@interface X : Y` + ivar block | `class X : public Y { … }` |
| `@interface X (Private)` in the `.m` | private member functions |
| `@interface X (Feature)` in its own file | member functions defined in `XFeature.cpp` |
| `@interface NSString (OOFoo)` | free functions in `namespace oo::str` |
| `- (T) foo` / `+ (T) foo` | member / `static` member function |
| `[obj msg:a with:b]` | `obj->msg(a, b)` |
| `[[X alloc] init…]` | `oo::make<X>(…)` returning `Ref<X>` |
| `[x retain]` / `[x release]` | `Ref<T>` assignment (usually just deleted) |
| `[x autorelease]` | return `Ref<T>` by value |
| `@protocol P` | abstract base class, or a concept where no dynamic dispatch is needed |
| `id<P>` | `P*` / `Ref<P>` |
| `[x isKindOfClass:[Y class]]` | `dynamic_cast<Y*>(x)` — **but review each: many want a virtual or a type tag** |
| `@try/@catch/@throw` | `try/catch/throw` |
| `NSAutoreleasePool` | scope exit / `Ref` |
| `@selector(foo)` + `performSelector:` | `&X::foo` or `std::function` |
| `NSSelectorFromString(s)` | explicit `unordered_map<string, handler>` — the 10 sites need individual design |
| `nil` / `NO` / `YES` | `nullptr` / `false` / `true` |
| `NSLog` / `OOLog` | `oo::log` (`std::format`-based) |

Files are `.mm` throughout this phase; `.mm` → `.cpp` is Phase 4.

### Converting a class: the house style ([ADR-0056](../decisions/0056-phase3-class-conversion-house-style.md))

Exemplar: `src/Core/OOColor.h` / `OOColor.mm` (the class), `OOColor+ObjCBridge.h` / `.mm` (its
façade), `tests/unit/core/test_OOColor.mm` (its test). Open them and do what they do.

1. **Files.** Keep `X.h` / `X.mm`: the C++ class is declared in `X.h`, defined in `X.mm`.
2. **Shell.** `class X : public oo::RefCounted` (or the converted superclass). Ivars become
   private members with the same names, `= {}`. Private-category methods become private members.
3. **Names.** Member = the selector's first keyword (`colorWithRed:green:blue:alpha:` →
   `colorWithRed(r, g, b, a)`); a shared first keyword → overloads; drop `cxx_`. Class methods →
   `static`.
4. **Types.** `X *` result → `oo::Ref<X>`; `X *` parameter → `X *`; `BOOL` → `bool`; Phase 2's
   C++ types stay exactly (`std::optional<std::string>` included). No `const` except
   `descriptionComponents() const`.
5. **Bodies verbatim** but for message syntax. `[[X alloc] init]` → `oo::makeRef<X>()`;
   `[[self retain] autorelease]` → `oo::Ref<X>(this)`. A message to something that may be nil →
   a null-guarded call doing what nil did. An out-parameter nil left unwritten → zero-initialised.
   `OOAssert`/`OOParameterAssert` → `OOCAssert`/`OOCParameterAssert`. A selector called by name →
   an explicit table (`kNamedColors`). `-cxx_descriptionComponents` →
   `descriptionComponents() const`.
6. **Façade, while any file outside the bead still messages `X`.** The class is `cxx::X`.
   - `X+ObjCBridge.h` holds the old `@interface` copied exactly, with one ivar
     `oo::Ref<cxx::X>`. Each method forwards in one line.
   - Crossings go through `oo::ToObjC(cxx::X *)` / `oo::ToCxx(X *)`. They keep one façade per
     object through `oo::ObjCPeers`, and the façade's `-dealloc` forgets it.
   - Import the bridge as the last line of `X.h`. Add `'X+ObjCBridge.mm'` after `'X.mm'` in
     `meson.build`.
   - File the deletion bead:
     `bd create "Delete X+ObjCBridge" -l fleet,phase:3,sweep:objc-bridge`. It removes the bridge
     files and moves `cxx::X` to the global namespace.
   - With no outside caller, there is no façade and the class is global.
   - **Object needs the game graph** (ADR-0056 amendment oo-44gg; exemplar
     `src/Core/CollisionRegion.*`): the test's meson entry is `['*']` (every game object but
     `main.mm`'s) and the test defines `gDebugFlags`. A second argumentless initialiser takes a
     tag struct (`CollisionRegion(AsUniverse)`); an initialiser that returned nil on failure
     raises; a file-static function reading private ivars becomes a private static member.
   - **Superclass still Objective-C** (ADR-0056 amendment oo-o89; exemplar
     `src/SDL/OOSDLJoystickManager.*`): the façade keeps the old superclass, makes and owns the
     C++ object in `-init`, and forwards the overrides too. The C++ class reaches superclass
     methods with `[oo::ToObjC(this) …]`, and `ToObjC` never makes a new façade. The deletion bead
     depends on the superclass's conversion. A category of an unconverted class converts with that
     class. SDL/GL calls stay verbatim, and an SDL class's test simulates its device.
7. **Callers you convert later** hold `oo::Ref<cxx::X>` (not `X *` or `oo::ObjCRef<X *>`), call
   with `->`, and cross with `ToObjC`/`ToCxx` only where they call unconverted code.
8. **Test.** Write `tests/unit/core/test_X.mm` and add one entry in `tests/unit/core/meson.build`
   (the game objects it links). Pin the pre-conversion answers: write them against the
   Objective-C API first, and run them on the unconverted class.
9. **Check.**
   - `! grep -nE '@implementation|@interface|@selector|@protocol' X.mm X.h`
   - `tools/build-windows.sh test`, with no new warning
   - `OOLITE_TIER_A_BUDGET=120 tools/tier-a.sh` on `X.mm` and `X+ObjCBridge.mm`
   - `bash tools/check-core-tests.sh`
   - `bash tools/tier-c.sh --only goldens` (`2 blessed verified`)
   - `bash tools/guardrails.sh`

## Commands

From Phase 0. Every story's acceptance includes `tools/tier-a.sh <file>`; the wrapper runs Tier B.

## Open decisions

- **3** — how much modern C++ in translated code. Decided: conservative C++20 first ([ADR-0001](../decisions/0001-bridge-then-convert.md)).
- **6** — decided: faithful port of legacy AI and plist scripting (ADR-0013).
- **7** — decided: MinGW-clang (ADR-0013).

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 3) and AI_EXECUTION_PLAN §1, §6, §15.
- 2026-09-29 — Slice-plan format and checker landed (`tools/check-slice-plan.py`, bead oo-4plo); first plan `3-slices/OOPListSchemaVerifier.md`. Plain-C free functions go in a checked `verbatim:` group and are never read by a slice (ADR-0012).
- 2026-09-29 — `OOColor` converted as the house-style exemplar (bead oo-11m, proposed ADR-0056):
  C++ `cxx::OOColor` in `OOColor.h/.mm`, Objective-C façade `OOColor+ObjCBridge.h/.mm` with
  identity kept by `oo::ObjCPeers`, unit test `tests/unit/core/test_OOColor.mm`
  (`tools/check-core-tests.sh`). No caller changed. Goldens: 2 blessed verified.
- 2026-09-29 — `tools/gen-stories.py` sweep `slices` (bead oo-k7u5): one fleet story per slice of every checked plan, titled `Convert to C++20: <File>.mm, slice <id>`, depending on the module's pattern seam, the pre-split bead and (after the first) the plan's first slice. Acceptance is `tools/check-slice-plan.py --slice-done <id> <plan>` (nonzero while any of the slice's units is still Objective-C) + `tools/tier-a.sh` + guardrails. `--dry-run --phase 3 --sweep slices` lists them; a landed slice is not re-filed.
