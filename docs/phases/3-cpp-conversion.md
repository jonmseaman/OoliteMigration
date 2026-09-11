# Phase 3 — Objective-C → C++20 conversion

**Status:** not started · **Est.:** 12–24 eng-months · **Depends on:** [Phase 1](1-js-engine.md) and [Phase 2](2-oofnd.md)
**Runs in parallel with:** partly with itself (independent modules), under the freeze policy.

## Goal

The long grind: ~500 files, leaves inward, one module per PR, goldens green at every step.
Conservative **C++20** only ([ADR-0001](../decisions/0001-bridge-then-convert.md),
[ADR-0011](../decisions/0011-cpp20-then-cpp23.md)); the C++23 upgrade is Phase 6; intrusive refcounting
only ([ADR-0003](../decisions/0003-intrusive-refcount.md)); modernisation waits for Phase 6. This is
the largest fan-out phase and the least seam-bound, and it is the phase the meta-experiment
([I4 metrics](../infra/4-metrics.md)) is really about.

## Entry gate

- [ ] Phase 1 and Phase 2 exit gates green
- [ ] **Exemplars exist:** `oomath` and `Core/OXPVerifier` converted by hand with a frontier model. They set the house style every generated story references. **Do not fan out before this.** Fanning out first yields 200 files in 200 styles and a review burden larger than the original work.
- [ ] Tier A measured < 30 s on a converted leaf file
- [ ] Freeze policy per module in force ([architecture §6.3](../architecture.md) item 5); `docs/UPSTREAM_DELTA.md` exists

## Exit gate

- [ ] Zero `@implementation` in `src/` (`grep -rc '@implementation' src` is 0)
- [ ] All goldens reproduce; Tier-1 corpus green; ASan/UBSan clean; Linux (WSL2) and Windows clean at `-Wall -Wextra`
- [ ] The six giant files converted (frontier + human; tracked individually in the status log)

## Seams

| Seam | Produces (exemplar path) | Owner |
|---|---|---|
| `oomath` conversion (near-pure C; establishes house style) | `src/oomath/` | Jon + frontier, days |
| `Core/OXPVerifier` conversion (real class hierarchy pilot, 27 files, own test data) | `src/oxp/verifier/` | Jon + frontier |
| Per-module pattern for each of: `Materials`, `ooaudio`, `ooscript` bindings, `ooentity` base | one converted file per module | Jon + frontier |
| The six giant files (`ShipEntity` 14,945 · `PlayerEntity` 13,718 · `Universe` 11,297 · `PlayerEntityControls` 5,690 · `HeadUpDisplay` 4,497 · `OOJSShip` 4,399) | themselves | **Frontier + Jon, weeks each.** 200k+ token closures; not fleet work. |
| Pre-splitting files > 400 lines into story-sized slices (category files already do this for `PlayerEntity`) | a slice plan per file | frontier |

## Sweeps

| Sweep | Unit | Inventory command | Exemplar | Est. stories | Ordering |
|---|---|---|---|---:|---|
| Leaf files ≤ 400 lines | one file | `find src -name '*.m' -size -20k` | `oomath` / `OXPVerifier` files | ~138 at 1 each | module order below |
| Files 400–1,500 lines | one pre-split slice | slice plans | per-module exemplar | ~62 × 1.5 + 30 × 3 | after the module's pattern seam |
| Files 1,500–4,000 lines (19 files, 22% of lines) | frontier, one at a time | Appendix A | — | ~11 × 7 | real design content in each |

Total ≈ 400 stories, inside the 240–960 band from the effort estimate.

## Work items (module order)

Suggested order (dependency-driven, and it front-loads the pattern-setting work):

1. `oomath` — `OOVector`, `OOHPVector`, `OOMatrix`, `OOQuaternion`, `OOTriangle`, `Octree`.
   Near-pure C already; converts in days and establishes house style.
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

## Commands

From Phase 0. Every story's acceptance includes `tools/tier-a.sh <file>`; the wrapper runs Tier B.

## Open decisions

- **3** — how much modern C++ in translated code. Decided: conservative C++20 first ([ADR-0001](../decisions/0001-bridge-then-convert.md)).
- **6** — legacy AI and plist scripting (contract C4): port faithfully. Recommended faithful; deprecation breaks the long tail the compatibility promise is built on.
- **7** — Windows toolchain, MinGW-clang vs clang-cl. C++20 coverage is fine on both; deferred to the Phase 6 C++23 upgrade.

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 3) and AI_EXECUTION_PLAN §1, §6, §15.
