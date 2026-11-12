# Implementation Plan: Modern C++ on the standard library

**Branch**: `seriesb/027-modern-cpp` (in `oolite-dev`) | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/009-modern-cpp-std/spec.md`

## Summary

Move the game's first-party C++ onto the standard library directly: C allocation becomes
containers and smart pointers; the Objective-C-style ownership library becomes
`std::shared_ptr`/`std::weak_ptr`/`std::unique_ptr` on a small `oofnd` core; the one detached
thread gets an owner; `oofnd` components with an identical standard equivalent go; and unscoped
enums, constant macro lists and ten `.tbl` tables become `enum class` with `kPascalCase`
enumerators. Nothing observable changes. The research ([research.md](research.md)) found where
the standard types cannot reproduce today's behaviour (deferred release, the weak set, weak
references during disposal, `oo::Data`, `NSRange`) and the spec was adjusted to keep those (R15).

The approach: switch to C++23 first; add clang-tidy guards to a new CI step, made fatal category
by category; convert by ownership chain or enum group, each step building and passing; reach the
standard ownership types through a transitional bridge (`oo::Ref` reimplemented over
`std::shared_ptr`), then remove the bridge; pin every external name and number before renaming.

## Technical Context

**Language/Version**: C++23 (from C++20; R1). Clang 22 is the CI formatter; the builds use
whatever clang CI's images ship (libstdc++ on Windows and Linux, libc++ on macOS). Locally:
Homebrew clang 22.1.8 and 23.1.4, Apple clang 21, g++-16.

**Primary Dependencies**: QuickJS-ng (script engine; its `JS_*` API is allowed), SDL3, OpenAL,
libpng, libcurl, vendored MiniZip, stb and tinyexr (not edited).

**Storage**: saved games (XML property lists), preferences (OpenStep property list), caches. All
must read and write the same bytes for the same state (SC-006).

**Testing**: meson unit suites `oofnd`, `oofnd-plist`, `core`, `headers` (Windows only,
`meson.build:130-148`; run by CI's `unit-tests-windows` on every push); `tests/run.sh component`,
`gui`, `smoke`; clang-tidy 22 (the guards, R3); ASan and TSan (R11); the expansion corpus
(`bash tools/corpus.sh tier1`, run by hand) and the JS API contract in `oxp-contract/`.

**Target Platform**: Windows x64 (MSYS2 UCRT64 clang), macOS arm64 (Apple clang, libc++, no
deployment target set, must stay ≥ 13.3 if one is set), Linux x64 (CI: Arch, Ubuntu 26.04,
Fedora).

**Project Type**: desktop game (one executable) plus its foundation library `oofnd`.

**Performance Goals**: frame rate in a busy scene and start-up time no worse than the base beyond
the measurement's run-to-run spread (SC-008, R10).

**Constraints**: no observable behaviour change (FR-001); CLAUDE.md's hard rules (below); `-O2`
and `-ffp-contract=off` stay; vendored code and the script engine's C API unchanged.

**Scale/Scope**: about 286k lines in about 520 first-party files. Converted: about 128 C
allocation lines in 37 files; about 1,900 ownership lines in about 260 files (plus about 2,000 in
165 test files); 5 thread call sites; `oofnd` components over about 1,700 game lines (most of it
545 format calls and 1,125 integer-alias lines); 176 unscoped enums (about 8,760 references, about
1,400 more in 96 test files).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the blank template, so the gates are CLAUDE.md's hard
rules and `docs/workflow.md`'s definition of done, as in spec 003's plan.

| Gate | Plan | Status |
|---|---|---|
| 1. No test changed to make it pass | Test edits only under rule 1's third exception (Jon, 2026-11-11), each in [test-ledger.md](data-model.md#test-change-ledger) in the same commit. Edits the exception does not plainly cover (one assertion whose meaning changes, construction-form changes, renames of existing `enum class` enumerators) are *needs sign-off* rows, and the work that needs them waits behind the work that doesn't. No test is deleted; `test_stdlib`'s fate is reported to Jon. | pass |
| 2. No warning silenced | No `-Wno-*`, `#pragma … diagnostic`, `NOLINT` or clang-tidy `IgnoredRegexp`. A check becomes fatal only when its category is at zero. `-Wformat-signedness` is used to find format sites in a local build and committed only when clean. | pass |
| 3. Never touch `develop`/`master`/`main`; no force-push | Game work commits on `seriesb/027-modern-cpp` and is pushed (fast-forward only) so CI runs the Windows unit suites. Spec docs commit on the planning repo's current branch. Jon merges. | pass |
| 4. Never read expansion content | The corpus is run through `tools/corpus.sh`, whose results are read, not its inputs. No converter needs an expansion file. | pass |
| 5. Tools judge correctness | Every step is accepted by the suites, the guards, sanitizers and `-Wall -Wextra`; external names and numbers by `static_assert`s and save round-trip tests. | pass |
| 6. No `libgnustep-base` or SpiderMonkey | Nothing added. QuickJS-ng's `JS_*` API is used only where it is now (the script slot). | pass |
| 7. No rewriting C for its own sake | No first-party `.c` files exist; vendored C (MiniZip, stb, tinyexr, QuickJS) is untouched. `abi::__cxa_demangle`'s `free` stays, as one listed exception. | pass |
| 8. Never wait for Jon | Every open choice has a default (*Notes* below). The two sign-off items block only their own steps; the milestone order puts everything else first. | pass |
| 9. No writes outside the repo | Scratch goes in `.agent-tmp/`. | pass |
| 10. clang-format 22 only, on changed files, never `tests/` | `/opt/homebrew/opt/llvm@22/bin/clang-format` on changed `src/` files. Test edits are made by hand in the tests' layout. | pass |
| Every bead has a failing-then-passing command | Each step's acceptance is a negated search for its pattern (fails before, passes after) plus the build and the guard; see [quickstart.md](quickstart.md). Design steps D1–D5 are labelled `design`. | pass |
| "Ownership is `oo::Ref<T>`, not `shared_ptr`; no redesign unless the spec asks for it" | The spec asks for it (FR-006). CLAUDE.md's line changes when the bridge is deleted (M5), not before. Spec 003's plan row is amended at the same time. | pass, justified |

**Re-check after Phase 1:** pass. The design adds three things that need justifying (*Complexity
Tracking*): the transitional bridge, `oo::Immortal`, and a new CI step. The contracts quote every
new interface verbatim, so fan-out beads add none (bead rule 3).

## Project Structure

### Documentation (this feature)

```text
specs/009-modern-cpp-std/
├── spec.md              # the feature (amended by research R15)
├── plan.md              # this file
├── research.md          # Phase 0: R1–R15
├── data-model.md        # Phase 1: categories, exceptions list, test-change ledger, external values
├── quickstart.md        # Phase 1: how to verify each milestone
├── contracts/
│   ├── ownership.md     # oo::Object, oo::share, oo::Immortal, AutoreleaseScope, WeakSet, entities, the JS slot
│   ├── enums.md         # OOEnumFlags.h, OOEnumTable.h, the enum header shape, external values
│   ├── threads.md       # OOAsyncWorkManager ownership and shutdown; the main-thread id
│   └── guards.md        # .clang-tidy entries, ./mk.sh tidy, the CI step
├── exceptions.md        # created in M0 (format in data-model.md)
├── test-ledger.md       # created in M0 (format in data-model.md)
├── baselines.md         # created in M0: start-up and frame-rate medians, the baseline save
├── external-values.md   # created at the start of M4 (format in data-model.md)
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (`oolite-dev`)

```text
meson.build, src/meson.build, src/oofnd/meson.build, tools/icosmesh/meson.build   # cpp_std=c++23 (M0)
.clang-tidy                                  # guard checks (M0), made fatal per category
mk.sh                                        # new `tidy` command (M0)
.github/workflows/build-all.yaml             # clang-tidy guard step after the Arch build (M0)

src/oofnd/
├── Object.hpp          # NEW (M5): oo::Object, oo::share, oo::Immortal
├── AutoreleaseScope.hpp# NEW (M5): the deferred-release scope on std::shared_ptr
├── Ref.hpp             # M5: becomes the bridge, then is deleted
├── WeakSet.hpp         # M5: rebuilt on std::weak_ptr
├── Thread.hpp          # M2: detach and isMainThread go; naming and priority stay
├── Expected.hpp        # M3: deleted
├── StdLib.hpp          # M3: unused by the game; deleted when Jon rules on test_stdlib
├── Date.hpp, FileSystem.hpp, Exception.hpp, objc/OOFoundationTypes.h   # M3: reduced
└── README.md           # M3/M6: rules and the surviving components

src/Core/
├── OODemangle.h        # NEW (M1): the one demangling helper (the listed `free`)
├── OOEnumFlags.h       # NEW (M4): flag operators, oo::ToUnderlying
├── OOEnumTable.h       # NEW (M4): name tables for named enums
├── OOPixMap.*          # M1: owning pixel buffer
├── OOAsyncWorkManager.*# M2: jthread workers, shutdown()
├── Tables/*.tbl        # M4: ten become headers (OOScanClass.h …); OOOpenGLStates.tbl stays
├── Entities/OOEntityHold.h, EntityHelpers.*, Entity.*   # M5: shared ownership with the disposing deleter
└── Scripting/OOJSPrivateObject.*                         # M5: the slot holds a heap std::shared_ptr
```

**Structure Decision**: no new directories. New headers sit beside the code they serve: the
ownership core and deferred release in `src/oofnd` (they replace `oofnd` parts), the enum helpers
and the demangling helper in `src/Core` (only the game uses them).

## Milestones

Each step builds on macOS, passes the smoke run and the guards locally, and is pushed so CI runs
the Windows unit suites and the Linux and macOS builds. Each milestone ends with the gate in
[quickstart.md](quickstart.md). Execution order is not the spec's priority order: US2 needs Jon's
sign-off on two ledger rows before its bridge commit, so the work that needs none goes first.

| # | Milestone | Story | Gate |
|---|---|---|---|
| M0 | **Groundwork.** `cpp_std=c++23` with no source change (R1). `./mk.sh tidy`, the guard checks non-fatal, the CI step (R3). `exceptions.md` and `test-ledger.md` created. Baselines recorded: smoke, frame rate and start-up (R10), a saved game written by the base. FR-016 tests that need only the base: save round-trip of every enum-valued entry, unknown-name fallbacks, shutdown with a background task. | — | Build and all CI jobs as on the base; the new tests pass on the base. |
| M1 | **C allocation** by chain (R4): demangling helper; sound (fixes the Vorbis leak); zip reads; the pixel-buffer chain as one unit; snapshots; JS vector and quaternion data; static tables; growable arrays; the TCP decoder handle. `cppcoreguidelines-no-malloc` fatal. | US1 | SC-001; the guard fails on a planted `malloc`. |
| M2 | **Threads** (R6, D4): `OOAsyncWorkManager` workers as `std::jthread` with `shutdown()` before `exit(0)`; `detach` removed; one main-thread id, merged with the log handler's copy. | US3 | Search finds no `oo::thread::detach`/`isMainThread`; quit-with-task test passes; TSan smoke run clean. |
| M3 | **`oofnd` → std** (R7): `std::expected`; `StdLib.hpp` out of the game; `oo::Exception : std::exception`; integer aliases → standard types and `oo::kNotFound`; Date's calendar; the identical FileSystem wrappers; literal formats → `std::format` by hand, area by area, after a local `-Wformat-signedness` pass; README rules. | US4 | US4 acceptance 1–4; every test tier as on the base. |
| M4 | **Enums P1–P9** (R8, D3, D5): helpers and the `OODebugFlags` exemplar; file-local enums; lone constants; internal header enums; bitmasks; number-visible enums; `CASE` string enums; the ten `.tbl` enums; the int-natured groups. Test stand-ins change with their production enum. | US5 | US5 acceptance 1–5 except the naming check, which stays non-fatal until M6; save round-trip identical. |
| M5 | **Ownership** (R5, D1, D2), after Jon has signed the `test_ref.cpp:514` and construction-form rows. D2's readers inventoried and tested on the base first. Then: the bridge; leaf types and immortals; the script slot; Entities, `EntityHold`, creators, `Universe`; SDL; callers off the bridge; the bridge deleted; frame-rate measurement; CLAUDE.md and spec 003's plan updated. | US2 | SC-002; disposal-order and script-finalisation tests pass; ASan clean; SC-008 measured. |
| M6 | **Close-out.** P10 (rename the 20 existing `enum class` enumerators) once Jon has signed those rows; the naming check fatal; docs (FR-023); final measurements; `tests/run.sh all` on a Windows machine; the corpus. | US5, all | SC-003 to SC-009. |

**Order and parallelism:**
- M0 first. M1, M2 and M3 touch disjoint code and may run in any order after M0 (one branch,
  one commit per bead, so never at the same time); M3's format steps touch many files and are
  sequenced by area.
- M4 after M1–M3 (it touches the same files as everything).
- M5 can move up to directly after M1 if Jon has signed by then (that matches the spec's
  priorities); otherwise after M4. It never runs beside M4: both rewrite `Core/Entities`.
- Inside M4 and M5, steps are sequential.

**Design steps** (interactive, label `design`): D1 the ownership core and the `OOColor` exemplar
(the CLAUDE.md converted-class exemplar), quoted in [contracts/ownership.md](contracts/ownership.md);
D2 the disposal-reader inventory; D3 the enum helpers and the `OODebugFlags` exemplar
([contracts/enums.md](contracts/enums.md)); D4 the work manager's shutdown
([contracts/threads.md](contracts/threads.md)); D5 the int-natured enum groups (JS property IDs,
GUI rows, joystick ids, key codes, pixel formats, the debug protocol).

## Complexity Tracking

| Exception | Why it is needed | Simpler alternative, and why it was rejected |
|---|---|---|
| The transitional bridge: `oo::Ref`/`WeakRef` reimplemented over `std::shared_ptr`/`weak_ptr` during M5 | Intrusive and standard ownership cannot coexist on one object, and about 2,000 src lines and 165 test files use `oo::Ref`. The bridge lets everything build while callers move area by area. | Converting every caller at once: one unreviewable change of about 4,000 lines with no intermediate state that builds. |
| `oo::Immortal<T>()` for about 25 never-destroyed singletons | They must not run destructors at exit (today's behaviour), and `shared_from_this` must work on them. | Function-local statics (run destructors at exit: a behaviour change). Raw leaked pointers (no owner visible in the declaration, and `share()` would throw). |
| `oo::AutoreleaseScope` and `oo::WeakSet` stay | The standard library has neither; destruction order and three member sets depend on them (R5). | Keeping objects alive with local `shared_ptr` copies instead: it changes when destructors run. |
| A new clang-tidy CI step | FR-021 needs a guard that runs; nothing runs clang-tidy today. | A Python scanner (Jon retired the last one on 2026-11-10). |

## Notes: decisions taken on defaults

Also recorded in research.md under the R item named.

- **Execution order differs from priority** (above): US2 waits for two sign-offs; the default is
  M5 after M4, moved up if Jon signs earlier.
- **The `test_ref.cpp:514` assertion** (weak references live during `willDispose()`) is a *needs
  sign-off* row: no standard design can keep it (R5). The bridge changes every reference-counted
  class's base at once, so there is no partial M5 without it. Default if Jon declines: M5 does not
  start, US2 is replanned, and M6 closes the feature without it.
- **Construction-form test edits** (stack and static instances made shared) are *borderline*
  rows for Jon's sign-off at merge (R9). They come with the bridge, so they are signed with the
  row above.
- **`test_stdlib`**: reported to Jon; `StdLib.hpp` stays, unused by the game, until he decides (R9).
- **Renaming existing `enum class` enumerators** (P10) waits for sign-off; until then the naming
  check is non-fatal and SC-003's naming part is open (R8).
- **`GameViewKeys` and `OOPixMapFormat`** default to typed constants on the exceptions list unless
  D5 finds a clean `enum class` (R8).
- **Performance** is measured with the frame-rate note's method, not a new tier (R10).
- **This branch is not added to spec 002's series manifest** (R12); Jon decides.
- **`oo::str::format` conversion is by hand**, never by script (R7). Data formats stay printf.

## Risks

- **Disposal readers missed by D2.** A weak reference read during `willDispose()` that no test
  covers silently stops resolving. Mitigation: D2 inventories every function reachable from
  `willDispose`/`willDealloc` (call graph from the compile database, not grep), and SC-005's
  component scenarios (kills, docking, jumps) run before and after.
- **Script events from disposal.** Not yet checked whether any script handler runs during
  `willDispose()` (R5). If one does, its `this` becomes invalid one step earlier. D2 answers it
  first; if it is so, the event is sent before release, and that is a design change to record.
- **The +1 raw protocol.** About 114 manual retain/release calls and 105 creator calls; one
  missed gives a leak or an early free. The bridge's manual-hold counter keeps them correct while
  they are converted; ASan and leak checks judge.
- **Unit tests only on Windows.** LP64 behaviour of what they pin (for example `intValue` through
  `long`, `test_foundation_types`'s `long long`) is untested by this feature; CI's macOS and Linux
  builds only compile. Phase 5 lifts the gate.
- **Format text drift.** Every literal format conversion can change output (R7). By hand, with
  `-Wformat-signedness`, area by area, and the save round-trip and log-capturing tests.
- **External enum names and numbers.** Four stringification mechanisms and build-config-dependent
  ordinals (joystick `AXIS`/`BUTTON` under `#if OO_FOV_INFLIGHT_CONTROL_ENABLED`). Explicit strings
  before any rename; `static_assert` on every visible number, in both configurations.
- **Upstream ports get harder** once enums are renamed (about 8,800 references). M4 is late and
  short; `tools/upstream-delta.sh` is the route.
- **clang-tidy version drift.** CI's clang-tidy is Arch's current one, not pinned; a newer
  version can add findings. They are fixed or recorded, never suppressed (R3).
- **CI cost.** A clang-tidy run over about 520 files on every push. If it exceeds the Arch job's
  budget, it runs only on the changed files' translation units plus a nightly full run.
