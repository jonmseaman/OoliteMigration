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
- [x] Decision 4 is `std::string` (ADR-0013). A benchmark story runs before the String seam lands: golden wall-clock before/after; > 5% regression escalates via the Reporter, otherwise proceed ([benchmark](2-string-benchmark.md), bead oo-lvj: +0.1%, confirmed)

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
- 2026-09-23 — Seam 2.5a (bead oo-lvj): decision-4 benchmark ([2-string-benchmark.md](2-string-benchmark.md), `tools/bench-string-copy.sh`). Value-semantics `std::string` copying where Objective-C copied: golden wall-clock +0.1% (paired median of 22 interleaved repetitions; noise floor ±15% per pair), 13 ms modelled CPU per golden pair. Deep copy on every `-retain`: +16.5% wall, so the String seam takes `string_view`/`const&`/moves where Objective-C retained. Decision 4 confirmed, not escalated.
- 2026-09-23 — Seam 2.5b (bead oo-dps): `oo::str` (`src/oofnd/String.hpp`, `Encoding.hpp`) reproduces GNUstep 1.31.1's string answers over UTF-8 `std::string` (case tables, composed-sequence matching, `-pathExtension`, libiconv transliteration to the five Windows code pages), pinned by digests of captured GNUstep output; exact `NSString` bridge `src/Core/OOStringBridge.h`; exemplar `src/Core/OOOXZManager.mm`; recipe in `src/oofnd/README.md` "Migrating NSString category calls" (proposed ADR-0034). `OOStringExpander`'s engine is a follow-up bead.
- 2026-09-23 — Seam 2.8 Logging (bead oo-qpb): `oo::log` (`src/oofnd/Log.hpp`) carries OOLogging's settings resolution, diagnostics, indentation and exact line layout, with a std::format `OO_LOG` front end; `src/Core/OOLogging.mm` is now its Objective-C shell; exemplar `src/SDL/OOSDLJoystickManager.mm`; recipe in `src/oofnd/README.md` "Migrating OOLog calls" (proposed ADR-0035). Latest.log of both blessed goldens byte-identical before/after (run-varying text masked).
- 2026-09-23 — oofnd components complete (seam 2.10, bead oo-rml): Ref/WeakRef/AutoreleaseScope (oo-qpa), PList value + old-style/XML parsers and writers (oo-075..oo-pig), PList::get + PListView bridge (oo-u77), strings/encoding (oo-dps), FileSystem/ResourcePaths/Data (oo-i9q), Defaults (oo-32f), Logging (oo-qpb), each with an exemplar consumer and a unit suite in tools/check-oofnd.sh. The Foundation sweep may fan out.
- 2026-09-23 — Foundation sweep recipe (beads oo-g7k5, oo-hi38, oo-ro7q): `src/oofnd/README.md` "Migrating Foundation usage (sweep:foundation)", proposed ADR-0043. C++ types inside a file; unique selectors take C++ types with nil-safe (zero-valid) method results; shared selectors keep `id` until a family bead (`tools/check-selector-types.py`); direct callers adapted at the call site via `OOFoundationBridge.h`; `oo::ObjCRef` for objects in std containers. Exemplars `OOVector` (oomath), `OORoleSet` (Core leaf), `OOBasicMaterial` (Materials); both blessed goldens verify.
- 2026-09-23 — Foundation sweep, batch 1 (48 beads: 16 done, 31 stops) -> ADR-0043 Amendment 1: transitional `cxx_`/`X+FoundationBridge` bridges for fan-out (exemplar OOColor, oo-tms0), Foundation categories and subclasses retire after their callers (dependencies recorded in beads), `oo::str::pointerDescription` and the path-component family (exemplar OOALSoundDecoder, oo-oz2y), NS typedefs count as NS types.
- 2026-09-23 — Foundation sweep, Materials/OXPVerifier/Debug batch (19 done, 20 stops) -> ADR-0043 Amendment 2: `oo::PList` carries mixed configurations exactly (Object nodes, single-precision reals); OOMaterialSpecifier (oo-hiis, bridged) and OOMultiTextureMaterial (oo-vpbt) as exemplars; Materials order; chunk beads for oo-vvxy; opaque C++ handles for OOTCPStreamDecoder's abstraction layer.
- 2026-09-23 — Foundation sweep, Core batch 2 -> ADR-0043 Amendment 2 items 15-18: floats written to disk are `PList::singleReal` (XML and defaults writers print `%0.7g`; oo-gj2i restores the joystick text); the saved-game writer moves to `oo::writeXMLPList`; Foundation enumerator subclasses become C++ iteration; OOLogging / OOCheckOpenGLErrors bridged; 12 oversized files split into chunk beads.
- 2026-09-23 — ADR-0043 Amendment 3: `oo::str::formatRuntime` formats DESC / plist-template format strings (%@, %p, positional) as GNUstep did, pinned against captured output; OOOXPVerifier (oo-hkvv) is its exemplar. GuiDisplayGen's last chunk split (5a oo-3rb.165, 5b oo-3rb.96 after PlayerEntity's cxx_markedDestinations, oo-3rb.164).
- 2026-09-23 — Entities wave (24 done, 9 stops) -> ADR-0043 Amendment 3 items 21-24: selectors called by name are shared (check-selector-types.py finds them); live containers through pointer accessors; error-log collection text may change; runtime DESC formats via formatRuntime (oo-3rb.171).
