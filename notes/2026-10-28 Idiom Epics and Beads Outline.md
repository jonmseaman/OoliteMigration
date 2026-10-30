# Idiom review: epics and beads outline (draft for review)

Source: [[2026-10-28 Modern C++ Idiom Review]] (scope and decisions are recorded there). Worker changes: [[2026-10-28 Epic Branch Worker Contract]]. Nothing here is created in `bd` yet.

## 1. Decisions so far (Jon, 2026-10-28)

- **Two epics, one branch each (`epic/<slug>`), each merged locally by Jon at the end** (two merges in total). No pull requests, no pushes by the worker: Jon merges and pushes himself. **Each bead is exactly one commit** on its epic branch. No guard shim; no merging `develop` into the epic branch (all the work happens on this machine, so there is no drift).
- **No per-bead size caps.** The "≤ 8 files, ≤ ~400 lines written, ≤ ~1,500 lines read" guidance is dropped (globally, in the docs and the worker). A bead is sized by what one worker can finish and prove in one tick: one coherent change with a command that fails before and passes after. That turns the earlier ~600-bead estimate into about **126 beads**.
- Google enumerator naming (`kFoo`, `Type::kFoo`).
- `oo::Ref` is re-implemented over `std::shared_ptr` with the same names; the `autorelease`/`leakRef`/`adopt` call sites then go (fallback: an `intrusive_ptr`-style pointer if the design bead finds many raw-pointer-to-`Ref` conversions).
- `UNIVERSE`/`PLAYER` stay as globals (no dependency injection, matching upstream). §2.1 (class design) and `EntityFilterPredicate` stay out too.
- `oolite-dev` references nothing outside itself; its tests run through `./mk.sh test test` and `tests/run.sh`. The outer desktop lock is dropped, not replaced.
- Both epics are created in full, at once, when ready.

## 2. Mechanics

- **Bead grain.** Safe, tool-driven sweeps are **one bead per pattern across the tree** (the worker runs a clang-tidy check with `--fix` over `compile_commands.json`, or a short script, rather than reading 125 files). Judgement-heavy changes (enums, memory, strings, casts, out-parameters) are **one bead per area** (Entities, Scripting, Materials/OpenGL, SDL/Debug, Core-top, `oofnd`), so one worker can hold the area in view.
- **Design beads** (labelled `design`) introduce an interface or a convention (the bitmask template, `platform::`, the new `Ref`, the `MAP` macro replacement). They are done in an interactive session, not the loop, per `docs/workflow.md`. Their fan-out beads are blocked by them. The `design` label is added to `BEADS_WORKER_EXCLUDE` so the loop skips them.
- **Acceptance** is a command that fails before and passes after. For sweeps it is a negated search over the whole tree plus a build and tests, for example:
  ```bash
  cd oolite-dev && ! rg -q '\bNULL\b' src --glob '!{MiniZip,EXRSnapshotSupport}/**'
  cd oolite-dev && ./mk.sh build test && tests/run.sh unit
  ```
  One consequence: the per-block acceptance budget (`BEADS_ACCEPT_BUDGET`, 300 s) cannot hold a full build plus the unit suite on a 286k-line tree. Proposed: an optional per-bead `accept_budget` metadata (default 300, ceiling 1,800), set by whoever writes the bead. See [[2026-10-28 Epic Branch Worker Contract]] §3.
- **Tests.** Epic A's test edits (outer references, desktop lock) are authorised by Jon (hard rule 1). Epic B beads must not touch tests; a bead whose change forces a test edit parks with the reason.
- **Windows-only verification.** Linux-only branches are moved verbatim; Phase 5 builds them.
- **No new suppressions**, including clang-tidy `NOLINT`; remove `OOJavaScriptEngine.cpp:731`'s existing one in the enum bead.

## 3. Epic A — Phase 4p: self-contained `oolite-dev`, real bugs, tooling (9 beads)

Exit gate: `./mk.sh build test`, `./mk.sh test test`, `tests/run.sh unit` green; `rg 'OoliteMigration|tools/(gui-lock|desktop_lock|check-|asan-)|tests/golden|goldens/|docs/(phases|stories|decisions)' oolite-dev --glob '!subprojects'` finds nothing.

| # | Bead | Acceptance (before → after) |
|---|---|---|
| A1 | `SDL/main.cpp`: no `strcat` into the `LOCALAPPDATA` buffer, bound `argv[i]` after `-load`, null-check `PATH`, `std::string`/`std::filesystem::path` instead of the 256-byte buffer | `! rg -q 'strcat\(SDL_getenv' src/SDL/main.cpp`; `tests/run.sh smoke` |
| A2 | `OOCPUInfo.cpp:202-203` unchecked `strcpy`/`strcat` → `std::string` | `! rg -q '\bstr(cpy\|cat)\(' src/Core/OOCPUInfo.cpp`; unit |
| A3 | `OOMeshToOctreeConverter.cpp` leak on `realloc` failure → `std::vector` | `! rg -q '\brealloc\(' …`; core unit tests |
| A4 | Self-contained build files: scrub outward references in `meson.build`, `meson.options`, `src/meson.build`, `src/oofnd/meson.build`, `tests/unit/*/meson.build`; add `tests/unit/asan-suppressions.txt` and point the core suite at it | negated `rg` for `tools/(check-\|asan-)\|tests/golden\|goldens/\|docs/`; `./mk.sh build test` |
| A5 | Self-contained tests: remove the outer desktop-lock lookup from `tests/launch_snapshot.py`, the component tier and the GUI tier, and scrub outward comments in the 26 files | negated `rg` for `desktop_lock\|gui-lock\|tests/golden\|docs/`; `tests/run.sh smoke` and `component`; `tests/run.sh gui` collects |
| A6 | Tooling files: `.clang-tidy` (agreed draft), `.editorconfig`, `./mk.sh build` writes a git-ignored root `compile_commands.json`, fix `.clangd` | `clang-tidy --dump-config` exits 0; `test -f compile_commands.json` after a build |
| A7 | Warnings already at zero hits: `-Wextra -Wpedantic -Wunused -Wsign-compare` | `./mk.sh build test` warning-free |
| A8 | Header-aware clang-tidy baseline written to `notes/` (the first pass skipped headers) | report exists with per-check counts |
| A9 | `asan` build type in `mk.sh` | build succeeds; the unit suite runs under it |

Worker-contract changes (the shim cleanup, `epic-finish.sh`, `land.sh`) are in the other note; the stand-alone `NOLINT` prohibition goes into CLAUDE.md and the story template with them.

## 4. Epic B — Phase 6: idiomatic C++ (about 117 beads)

Gated on the Epic A exit and on upstream having seen the faithful port (4p doc). Every non-design bead after the first of its group is blocked by that group's design/exemplar bead. The tool-driven sweeps are also blocked by A6 (they need `compile_commands.json` and `.clang-tidy`). Counts are estimates from the hit survey (areas are directories: Entities, Scripting, Materials/OpenGL, SDL/Debug, Core-top, `oofnd`).

| Group | Beads | Count |
|---|---|---:|
| **B0 C++23** | toolchain minimums report (Clang, GCC) · flip `-std=c++23` in `src/meson.build`, `src/oofnd/meson.build`, `.clang-format` · `oo::Expected` → `std::expected`, delete `Expected.hpp` (19 uses, 14 files) | 3 |
| **B1 Safe sweeps**, one bead per pattern, tree-wide | `NULL`→`nullptr` (1,213 hits/125 files) · `f(void)` params · `typedef`→`using` · `OOINLINE`→`inline` · `EXPECT`→`[[likely]]` · `MIN/MAX/ABS`→`std::` · `M_PI`→`std::numbers` · `OOClamp/OOLerp`→`std::clamp/lerp` · `<x.h>`→`<cx>` · destructor `override` + enable `-Wsuggest-destructor-override` · `-Wundef` fixes + enable | 11 |
| **B2 Dead code** | `OOLITE_MAC_OS_X` blocks (~787 lines) · `MOZ_TRACE_JSCALLS` and leftover Objective-C comments/`.mm` references | 2 |
| **B3 Constants** (606 `#define`s → `inline constexpr`) | `HeadUpDisplay.h` (156) · `ShipEntity.h` · `PlayerEntity*.h` · remaining Core headers · `.cpp`-local defines (Entities/Scripting/Materials) · `SDL` + `Debug` · const `extern`s → `inline constexpr` | 7 |
| **B4 Enums** | **design:** bitmask operator template + `OODebugFlags` exemplar (interactive) · `OOTypes`/`OOEntityEnums` · `PlayerEntity` · `ShipEntity` + Entities · Scripting `OOJS*` · Materials/OpenGL/Textures · SDL input/joystick/keys · Debug/OXP/other Core · `oofnd` · enum-indexed string tables → `std::array<std::string_view>` · bitmask macros → bitmask enums (`OOVoxel`, `OOJoystickManager`, `OOJS_PROP_*`) | 11 |
| **B5 Platform layer** | **design:** `platform::` interface + `config.hpp`, `OOCPUInfo` exemplar (interactive) · `config.hpp` for feature switches · in-body `#if` out of: GameController + `main.cpp`; Universe + PlayerEntity*; Log/CPU/Profiling/Process; OpenGL ext manager/textures/GL debug; `oofnd` `Process/Thread/Http/Defaults/ResourcePaths` (incl. Win32 prototypes → `<windows.h>`, `W` APIs, Linux HTTP backend gap noted); Debug TCP/Winsock · `OO_DEBUG_MONITOR_ENABLED` (186 directives/86 files) ×2 · `std::endian` · keymap/resource paths | 12 |
| **B6 `oofnd` residue** | `NSInteger/NSUInteger`→`std::size_t`/`ptrdiff_t` · `NSPoint/NSSize/NSRect` → project structs · `NSRange/NSNotFound` → `std::optional` index · `cxx_` prefix removal (2,043 hits/146 files) · `StdLib.hpp` umbrella → include-what-you-use · `oo::str::format`→`std::format` ×2 · `OORaiseException` printf → `std::format` + `PrintfFormat.h` · `oo::Exception` : `std::runtime_error` · `Date`→`<chrono>` · `Data`→`vector<byte>`/`span` · `Notification`→`std::function` · `OOCallByName` → table · `%@`→`std::formatter` · **`Ref` design/exemplar (interactive)** · `Ref` reimplemented over `std::shared_ptr` · `autorelease`/`leakRef`/`adopt` call sites ×3 areas | 19 |
| **B7 Memory** (2.2) | `malloc/calloc/realloc/free` → `vector`/`unique_ptr` by area: Textures · Meshes/Octree/CollisionRegion · Sound · JS bindings · SDL/HUD/rest (5) · raw `new`/`delete` · leaked singletons → function-local statics/`unique_ptr` · owning pointer members ×2 · `OOCache` → std containers · `OOPriorityQueue` → `std::priority_queue` · `memcpy`→`std::bit_cast` · C arrays → `std::array`: HUD, Universe + Entities, rest (3) | 16 |
| **B8 Strings, casts, out-params** (2.3) | C strings → `std::string`/`string_view` by area ×6 · C-style casts → `static_cast` by area (PlayerEntity, ShipEntity, Universe + rest of Core, OpenGL/Textures, Scripting, SDL/Debug) ×6 · out-parameters → `optional`/`expected`/struct by family (JS `getJSClass`, sound decoder, shader uniform, PList schema verifier, Universe finders, JS Vector/Quaternion, misc) ×7 · simple `goto`s · narrowing (`-Wconversion`, non-fatal first) ×2 | 22 |
| **B9 Standard library** (2.4) | `fopen`→streams · lock/unlock → `lock_guard` · `<chrono>` stopwatch · `rand()`→`<random>` (not `legacy_random`) · `std::span` · index loops → ranges ×2 | 7 |
| **B10 Macros** | `OOStringExpander` `MAP` replacement **design (interactive)** + apply · `OOJSSTR/OOJSID` → inline functions · reserved-name `__has_*` shims · `OO_LOG`/`OOCAssert` use `std::source_location` inside the function (macro stays, to avoid evaluating arguments) | 5 |
| **B11 Close-out** | enable `-Wold-style-cast`, `-Wconversion` fatal once clean · turn the now-clean clang-tidy checks into errors | 2 |

Out of scope by decision: §2.1 class design, `EntityFilterPredicate`, `UNIVERSE`/`PLAYER`, the control-state globals, `.h`→`.hpp` rename, replacing the test harness.

**Total: 9 (Epic A) + about 117 (Epic B) ≈ 126 beads**, of which 5 are interactive design beads.

## 5. Docs changed with the sizing decision (done 2026-10-28, applied globally, uncommitted)

`docs/workflow.md` (readiness test and `accept_budget`), `docs/templates/story.md` (no file/line lines; five-row readiness check), `CLAUDE.md` ("one tick's work", no cap) and `SKILL.md` step 7 and acceptance section. `accept.sh` reads the per-bead `accept_budget`.

## 6. What dropping the caps changes, and what it does not

**Changes**
- **Count:** about 600 beads become about 126. Epic B is hand-writable; a generator is only needed to paste per-area hit lists into bead descriptions.
- **New dependency edge:** the tool-driven sweeps (B1, and the mechanical parts of B3, B6, B7) need a compile database and the clang-tidy config, so they are blocked by A6 (`.clang-tidy`, root `compile_commands.json`).
- **Acceptance cost:** sweep beads run a build and the unit suite in their acceptance block, so each sets `accept_budget` (600 to 1,800 s). Put the fast negated-`rg` proof on the **first** acceptance line so a failed attempt fails in seconds, not after a 30-minute build.
- **Commit size:** one commit per bead means a 125-file sweep is one commit. It is reviewable by rule (the tool and the pattern) rather than line by line; bisect granularity inside a sweep is lost. A parked bead of that size reverts as one large commit, which is safe but heavy.
- **Epic A:** no change in content; the "read only the lock ranges" remark for the 2.7k-line GUI `conftest.py` is gone.

**Does not change**
- Scope, order, the five design beads, exemplar-first, Google naming, `Ref` over `shared_ptr`, two epics, one commit per bead, local merge by Jon.

**Could coarsen further (not done):** B3 constants 7 to 3 (by area), B4 enums 10 to 6, B8 strings and casts 12 to 6. Up to about 15 fewer beads. I kept them per area because each is a judgement-heavy change that one worker should hold in view; say if you want them merged.
