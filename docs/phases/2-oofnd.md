# Phase 2 — `oofnd` (Foundation replacement)

**Status:** not started · **Est.:** 6–10 eng-months · **Depends on:** [Phase 0](0-safety-net.md) exit
**Runs in parallel with:** [Phase 1](1-js-engine.md). **This is where GNUstep dies.**

## Goal

Switch the build to Objective-C++, build a C++20 Foundation replacement bottom-up with unit tests,
migrate every Foundation usage site onto it while the classes are still Objective-C, and delete
`libgnustep-base` from every platform. Only the Objective-C *runtime* remains. Design:
[architecture §3.4](../architecture.md); memory model: [ADR-0003](../decisions/0003-intrusive-refcount.md).

## Entry gate

- [ ] Phase 0 exit gate green
- [ ] Decision 4 is `std::string` (ADR-0013). A benchmark story runs before the String seam lands: golden wall-clock before/after; > 5% regression escalates via the Reporter, otherwise proceed

## Exit gate

- [ ] All goldens reproduce
- [ ] `libgnustep-base` absent from the link line; deny-list enforces it
- [ ] `oofnd` old-style **and** XML plist parser/writer fuzzed against GNUstep with zero divergences on the corpus (contract C1) — evidence: [2-plist-fuzz-report.md](2-plist-fuzz-report.md)
- [ ] Every `oofnd` component has its own unit-test suite green under `meson test`
- [ ] Zero `oo_*ForKey:` call sites remain (`OOCollectionExtractors` retired)

## Seams

| Seam | Produces (exemplar path) | Owner |
|---|---|---|
| The `.m` → `.mm` switch: one atomic, behaviour-free commit (`.m` files with no `@implementation` become `.c`, per [ADR-0012](../decisions/0012-c-stays-c.md)) | the commit itself | Frontier agent; compiler-driven loop for the mechanical fixes |
| `Ref` / `WeakRef` / `RefCounted` / `AutoreleaseScope` | `src/oofnd/Ref.hpp` + tests | Frontier agent |
| `PList` + old-style and XML parser/writer | `src/oofnd/PList.hpp` + tests | Frontier agent |
| Typed accessor `PList::get<T>` and one fully migrated consumer | one file with zero `oo_*ForKey:` left | Frontier agent |
| String utilities, `FileSystem`, `Defaults`, `Logging`, `Data` | one migrated consumer each | Frontier agent |

The `PList` component as originally written scores 2/7 on the sizing rule: too big and unverifiable.
It must be split into stories with test-file acceptance (e.g. "old-style scanner: quoted strings and
`\U` escapes; `test_plist_oldstyle_strings.cpp` cases 1–14 go green") before any of it is dispatched.

## Sweeps

| Sweep | Unit | Inventory command | Exemplar | Est. stories | Ordering |
|---|---|---|---|---:|---|
| `OOCollectionExtractors` retirement | one file | `grep -rl 'oo_[a-zA-Z]*ForKey' src` | the migrated consumer | ~150 | after `PList::get` seam |
| Foundation → `oofnd` | one file | `grep -rl 'NSString\|NSDictionary\|NSArray' src` | per component | ~250–400 | in the order below |

Order for the Foundation sweep: `oomath` → `Core` leaf utilities → `Materials` → `oxp` →
`Scripting` → `Entities` → `Universe`.

## Work items

1. **Switch the build to Objective-C++.** Rename `.m` → `.mm`, `-x objective-c++`, `-std=c++20` ([ADR-0011](../decisions/0011-cpp20-then-cpp23.md)).
   Expect a few hundred mechanical fixes (`nil` vs `nullptr`, `class`/`new`/`delete`/`template` used
   as identifiers or selector parts, `id` in C++ contexts, `BOOL` conflicts, stricter enum/`void*`
   conversions). Do this as one atomic, reviewable commit — it must change no behaviour.
2. **Build `oofnd` bottom-up**, each piece landed with its own unit tests:
   - `Ref`/`WeakRef`/`RefCounted`/`AutoreleaseScope` (replaces `OOWeakReference`, `OOWeakSet`)
   - `PList` + old-style **and** XML plist parser/writer (replaces `OOPListParsing`,
     `OldSchoolPropertyListWriting`, `NSPropertyListSerialization`)
   - Typed accessors (retires `OOCollectionExtractors` — ~1,800 sites)
   - String utilities (retires the `NSString` categories, `OOStringParsing`, `OOStringExpander`,
     `OOEncodingConverter`)
   - `FileSystem`, `ResourcePaths`, `Data` (retires `NSFileManager`/`NSBundle`/`NSData` usage)
   - `Defaults` (retires `NSUserDefaults` + the two `Override` categories)
   - `Logging` (retires `OOLogging` — already mostly C-shaped)
3. **Migrate usage sites** from Foundation to `oofnd`, still inside Objective-C classes. Order:
   `oomath` → `Core` leaf utilities → `Materials` → `oxp` → `Scripting` → `Entities` → `Universe`.
4. **Delete `libgnustep-base`** from the dependency list. `libobjc2` (runtime only) stays.

The `.m` → `.mm` mechanical fixes are a compiler-driven loop (fix, rebuild, repeat), which a cheap
model does well because the compiler is the oracle. `oofnd` itself is frontier design work.
`OOCollectionExtractors` → `PList::get` retires ~1,800 call sites in one stroke: the highest-leverage
single change in the project, and pure design, not volume.

## Commands

From Phase 0. `meson test -C build --suite oofnd` for the library.

## Open decisions

- **4** — decided: `std::string`, with the threshold-gated benchmark story above (ADR-0013).

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §7.
- 2026-09-23 — Seam 2.4 (bead oo-u77): `oo::PList::get<T>`/`at<T>` (`src/oofnd/PListGet.hpp`) with OOCollectionExtractors' exact GNUstep conversions; sweeps bridge through `oo::PListView` (`src/Core/OOPListView.h`); exemplar `src/Core/Entities/OOWaypointEntity.mm`; recipe in `src/oofnd/README.md` "Migrating oo_*ForKey" (proposed ADR-0031).
