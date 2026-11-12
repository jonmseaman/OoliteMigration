# Research: Modern C++ on the standard library

Phase 0 of [plan.md](plan.md). Four read-only surveys of `oolite-dev` at `seriesb/027-modern-cpp`
(`518520d43`), 2026-11-11: ownership, enums, `oofnd` and threads, and toolchains, guards and tests.
Paths are under `oolite-dev/` unless they start with `specs/` or `notes/`. Counts are from `rg`
over code with comments stripped, ±5–10%. "Inferred" marks what was reasoned, not read.

## R1. Toolchains and C++23

**Decision:** switch `cpp_std` to `c++23` first, with no source change, as its own commit.

- CI (`.github/workflows/build-all.yaml`, the only workflow) builds with clang against libstdc++
  on Arch, Ubuntu 26.04 and Fedora; with MSYS2 UCRT64 clang against libstdc++ on Windows (build
  and unit tests); and with the runner's Apple clang against libc++ on macOS. There is no GCC and
  no MSVC job. Versions are not pinned (inferred: clang 21–22, libstdc++ 15–16).
- This Mac: Homebrew clang 22.1.8 (`/opt/homebrew/opt/llvm@22`), clang 23.1.4 on `PATH` (the
  existing `build/meson_*` were configured with it), Apple clang 21, g++-16.
- `std::expected` (with the monadic operations), `std::to_underlying`, `std::byteswap`,
  `std::format`, `std::print`, `std::jthread`/`std::stop_token` and `std::unreachable` compile at
  `-std=c++23` on all four local compilers.
- libc++ marks floating-point `std::to_chars` (and so `std::format` of floats) as needing macOS
  13.3. No deployment target is set, so today's default (26) is fine; any future lowering must stay
  at 13.3 or above. Don't gate on `__cpp_lib_to_chars` or `__cpp_lib_format` (libc++ leaves them
  low).
- Places to change: `src/meson.build:25` (and its comment at `:21`), `src/oofnd/meson.build:18`
  (comment at `:3`), `tools/icosmesh/meson.build:9`. Tests inherit through
  `oofnd_override_options` and `oolite_override_options`. `.clang-format` is already
  `Standard: Latest`; `.clangd` reads `compile_commands.json`. About 28 comments and docs say
  "C++20" (oofnd README `:3,8,50`, header banners, `oo_test.hpp:3`).

**Alternatives:** C++26 (`std::scope_exit` would still be absent; toolchain support uneven).
Staying on C++20 and keeping `oo::Expected` (contradicts FR-013).

## R2. Where the tests can run

**Decision:** each milestone's gate is: a local macOS build plus `./mk.sh test test` (smoke); the
clang-tidy guards locally; then a push of `seriesb/027-modern-cpp`, after which CI's Windows
unit-test job and the Linux and macOS builds decide. Component and GUI tiers run on a Windows
machine when one is available; the plan does not depend on them per step.

- `meson.build:130-148` builds the unit suites and `headers` only on Windows, so `tests/run.sh
  unit` runs nothing on macOS or Linux. CI's `unit-tests-windows` job is the only automatic unit
  run. CI runs on every push.
- Known base failures (spec FR-002): `test_http` (6 checks, `file:` URLs) and `test_OOOXZManager`
  (35 checks), Windows.
- Lifting the Windows-only gate is Phase 5 work, not this feature's. Consequence recorded as a
  risk: LP64 behaviour (macOS, Linux) of anything the unit tests pin is not tested by this feature.

- **Found while implementing (2026-11-12):** a single unit test can be built and run on macOS by
  compiling it with a game source's flags from `compile_commands.json` and linking it against the
  test build's own objects (`.agent-tmp/link_run.py`), which is what the meson entry does on
  Windows. T027 and T028 used it. It also showed a test that only holds on Windows and Linux:
  `test_thread.cpp`'s `setCurrentNameIsReadBack` expects Linux's 15-byte name truncation in its
  non-Windows branch, and macOS keeps the whole name (reported to Jon; not edited).
  More such tests, all failing identically on the C++20 base when run on macOS (2026-11-12):
  `test_plist_get` (149 checks), `test_string` (4), `test_defaults` (1, Windows paths) and
  `test_foundation_types` (asserts `long long`, LLP64 only). They are LP64 and path differences
  the Windows-only gate hides; Phase 5 meets them when it lifts the gate.

**Alternatives:** lift the gate here (out of scope, and it would surface unrelated LP64 failures
first). Run unit tests only on Windows by hand (slower than CI and not available from this Mac).

## R3. Guards for converted categories (FR-021)

**Decision:** clang-tidy 22 is the guard. Add the guard checks to `.clang-tidy`'s `Checks` and,
category by category as each reaches zero, to `WarningsAsErrors` (the existing ratchet). Add
`./mk.sh tidy` running `run-clang-tidy` over `src/(Core|SDL|oofnd)` with the root
`compile_commands.json`, and a CI step after the Arch build that runs it. Removed types need no
check: deleting their headers makes any reintroduction a compile error.

| Category | Check | Fatal when |
|---|---|---|
| C allocation | `cppcoreguidelines-no-malloc` (defaults cover `malloc`, `calloc`, `realloc`, `free`) | end of US1 |
| Unscoped enums | `cppcoreguidelines-use-enum-class` (`IgnoreUnscopedEnumsInClasses=false`) | end of US5 |
| Enumerator naming | `readability-identifier-naming` with `ScopedEnumConstantCase: CamelCase`, `ScopedEnumConstantPrefix: k` | end of US5 |

- Two checks were considered and rejected. `cppcoreguidelines-owning-memory` (277 hits) flags
  the intended ownership crossings (the script slot's heap `shared_ptr`, the never-deleted singletons)
  unless they are annotated with `gsl::owner`, which the project does not use; FR-005 is checked
  by the exceptions list and review instead. `modernize-macro-to-enum` flags any run of adjacent
  integer macros, including the hundreds of plain numeric constants (`HeadUpDisplay.h` alone has
  156) that are not enumerations and are out of scope; the about 10 macro sets are listed in
  data-model.md with a search each instead. Those searches, and the `.tbl` file count, run only by
  hand through the planning repo's `check.sh`, which CI does not run, so FR-021 does not count
  them as guards (decided 2026-11-11, `/speckit-analyze` finding G2).
- The three checks used, and the two rejected, all exist in clang-tidy 22.1.8 (604 checks). Nothing runs clang-tidy today: not CI,
  not `mk.sh` (only a comment at `:92`), not `tests/run.sh`. So the CI step is new; it is the
  first thing that makes `WarningsAsErrors` mean anything.
- No `NOLINT`, no `IgnoredRegexp` options (FR-003). One `NOLINT` already exists
  (`ShipEntityAI.cpp:1428`); it is not this feature's.
- Spec 005 (cpplint) plans its own ratchet "copying `.clang-tidy`'s WarningsAsErrors approach";
  this is compatible and does not depend on it.

- CI's clang-tidy is whatever Arch ships (22 or 23); a newer version can report findings 22 does
  not. The CI step pins nothing; a new finding from a version change is fixed or recorded, never
  suppressed.

- **Found while implementing T006 (2026-11-11).** clang-tidy 22 reports 27 distinct
  `bugprone-exception-escape` findings on this tree, the same under C++20 and C++23 (most reach
  libc++'s `bad_array_new_length`), although `.clang-tidy`'s comment says `WarningsAsErrors` held
  only checks with no findings. Following that file's own convention, the check joined the `-name`
  list (still enabled, still printing every finding). Homebrew's clang-tidy also needs the macOS
  SDK as `-isysroot`, and the vendored directories must be left out of `run-clang-tidy`'s file
  pattern, because their `.clang-tidy` enables no check and clang-tidy then exits nonzero.

**Alternatives:** a Python source scanner in `tests/` (Jon deleted `tests/idiom_check.py` on
2026-11-10, `8ec7631d3`, as a retired migration-era check; a new one would repeat it). A meson
test wrapping clang-tidy (it would need a compile database inside the build; `mk.sh` already writes
one at the root).

## R4. C allocation (US1)

**Decision:** convert by ownership chain, not by file. About 128 call lines in 37 files; none in
`oofnd`; no `strdup`, `alloca` or `posix_memalign`.

| Chain | Sites | Replacement |
|---|---|---|
| Demangled names | `std::free(demangled)` after `abi::__cxa_demangle` in 8 files (`OOALSound:169`, `OODrawable:67`, `OOMaterial:70`, `OOTexture:388`, `OOTextureLoader:234`, `OOOXPVerifierStage:81`, `OOScript:69`, `EntityHelpers:130`) | one helper returning `std::string`, freeing through `std::unique_ptr<char, decltype(&std::free)>`. The C++ ABI requires `free` here: **exceptions-list entry** (the helper's one `free` reference). |
| Sound buffers | `OOALSoundDecoder:316,351,443`, `OOALStreamedSound:35,62`, `OOALBufferedSound:35` | `std::vector<char>`; fixes the leak below |
| Zip reads | `OODataFromOXZFile:124,138` | `std::vector<char>` |
| Pixel buffers | `OOPixMap:76,85,110`, `OOTextureScaling:283,355-360,1684`, `OOPixMapChannelOperations:122,125`, `OOTextureLoader:201,349,364,381,398`, `OOConcreteTexture:137,478,568`, `OOPNGTextureLoader:88,136-160`, the planet and atmosphere generators (`FREE` macro, about 12 sites) | one owning pixel buffer in `OOPixMap`, converted as a unit (the buffer passes between loader, scaler and texture) |
| Snapshots | `MyOpenGLView:1289-1516` | `std::vector` (SDL and stb copy) |
| JS opaque data | `OOJSVector:177,184,495`, `OOJSQuaternion:143,150,461` | `new`/`delete` under the finaliser (our own); hot path, measure |
| Static tables | `OOJSClasses:71,122-123` | `std::array`/`std::vector` with static lifetime |
| Growable arrays | `Octree:84,113,809-917`, `CollisionRegion:67,98,202`, `OOPolygonSprite:187-622`, `OOSkyDrawable:522-608`, `OOCrosshairs:44,89`, `HeadUpDisplay:4470-4533`, `OOShaderProgram:559-580`, `OOShaderMaterial:301,707`, `OOProbabilitySet:391-514`, `OOProbabilisticTextureManager:93-169`, `OOSoundSourcePool:62,76`, `OOJSFrameCallbacks:366,377`, `ShipEntity:13807,13823` | `std::vector` |
| Opaque handle | `OOTCPStreamDecoder:72,98` | `std::unique_ptr` |

- Already correct: `js_malloc`/`js_free` (QuickJS owns those tables) and `SDL_free` are other
  APIs, not the C allocator, and the check does not match them.
- **Bug found:** `OOALSoundDecoder.cpp:442`, `OOReadOXZVorbis` mallocs `buf` on every read and
  never frees it: a leak per OXZ Vorbis read. The vector conversion fixes it (spec FR-001's "fixes
  a recorded bug").
- **Spec correction:** the `OOMeshToOctreeConverter` `realloc` leak the spec's Context mentions was
  already fixed (`272aac108`, `std::vector<Triangle> heap`).
- `tests/unit` has 8 files that use `malloc`/`free`; tests are not first-party C++ for FR-004 and
  are not touched.

## R5. Ownership design (US2)

**Decision:** standard ownership with a small `oofnd` core, reached through a transitional bridge.

1. **`oo::Object`** replaces `oo::RefCounted`: `std::enable_shared_from_this<oo::Object>` plus a
   virtual destructor. Every reference-counted class has exactly one `RefCounted` root today, so
   one common base works, and a `std::weak_ptr<oo::Object>` can watch any of them (the shader
   uniform target, `OOShaderUniform.h:158`). `PList::Object` (`Ref<PListForeign>`, `PList.hpp:142`)
   becomes `std::shared_ptr<PListForeign>`.
2. **`oo::share(p)`** = null-safe `std::static_pointer_cast<T>(p->shared_from_this())`, for the
   about 300 places that make an owning reference from a raw pointer (about 120 temporaries and
   188 named constructions; about 18 from `this`: `OORoleSet.cpp:180,192,202`, `OOColor.cpp:476`,
   `AI.cpp:697`, `OOJSTimer.cpp:114,141,217`, `OOSoundSource.cpp:136,170,271` …). Setters move to
   taking `std::shared_ptr` where that is local; `share` covers the rest.
3. **`oo::AutoreleaseScope` stays, rebuilt on `std::shared_ptr`.** It drains once per tick
   (`GameController.cpp:373`), once per frame-loop pass (`:463`), once per worker task
   (`OOAsyncWorkManager.cpp:185,364,369,443`), at start-up and in about 10 local scopes; not per JS
   call. It is the only owner of new entities until they are added (`MadeEntity`), it destroys dead
   entities at the drain in LIFO order (`AutoreleaseAll(entitiesDeadThisUpdate)`), and it keeps an
   AI, script, drawable or material alive while it is being replaced mid-call
   (`ShipEntity.cpp:963,1439,7577,7604`, `ShipEntityAI.cpp:123`, `PlayerEntity.cpp:2837`, …).
   Removing it would change destruction order and leave raw pointers dangling. It becomes a
   per-thread stack of `std::vector<std::shared_ptr<const void>>` with the same nesting, newest-first
   draining and cascade. The name stays, so the 316 test uses of the scope itself need no edit.
   **Spec change:** FR-006 and US2 said the scope goes; see R15.
4. **`oo::WeakSet<T>` stays, rebuilt on `std::weak_ptr`.** There is no standard zeroing weak set,
   and its contract (identity uniquing, insertion order, a retained snapshot for `forEach` so the
   callback may mutate the set) is used by `ShipEntity.h:1542,1545` and `StationEntity.h:209`.
   **Spec change** (R15).
5. **Entities:** `std::shared_ptr<Entity>` made with a disposing deleter (`willDispose()`, then
   `delete`), never `std::make_shared`. `EntityHold` becomes an alias of `std::shared_ptr<Entity>`
   plus `oo::Hold(e)` (`e && e->hasObject() ? share(e) : nullptr`). The +1 creators
   (`newShipWithRole` 52 calls, `newShipWithName` 27, …) return `std::shared_ptr`.
6. **Script-engine slot:** `OOJSSetCxxPrivate` stores a heap `std::shared_ptr<oo::Object>*` in the
   opaque slot. The finaliser takes the slot, nulls it, calls `clearJSSelf`, then deletes the
   holder (today's order, `OOJSPrivateObject.cpp:88-102`). The observing holders
   (`OOJSEntityHolder`, `ScriptPrivate`) keep a `std::weak_ptr`.
7. **Never-deleted singletons:** about 25 are `makeRef(...).leakRef()` and must never be destroyed (no
   work at exit). They become never-deleted function-local statics written in plain std at each
   site, no helper (Jon, 2026-11-11): `static const auto& s = *new std::shared_ptr<T>(...)` where
   other objects also hold them shared (so `shared_from_this` works), `static auto& s = *new T()`
   where nothing does. Each is on the exceptions list. **Spec change** to FR-005's "owner or function-local static" (R15).
8. **Exclusive owners** become `std::unique_ptr` or values: `HeadUpDisplay::_crosshairs`
   (`HeadUpDisplay.h:412`), `OOJoystickSplineSegment`, `OOSkyQuadSet`, `RouteElement`,
   `OOPreservedAIStateMachine`, `OOOpenGLMatrixStack`, `OOTimeProfileEntry`, the JS holders; likely
   Universe's GUI objects (`Universe.h:318-320`) and the player's `hud` (inferred). Colours, role
   sets, textures, materials, meshes, octrees, scripts, groups, sounds, async tasks and entities
   are genuinely shared.

**The transitional bridge.** Ref and shared ownership cannot coexist on one object, and about 260
files and 165 test files use `oo::Ref`. So the first step changes the inside, not the callers:
`oo::RefCounted` derives from `oo::Object`; `oo::Ref<T>` wraps a `std::shared_ptr<T>`; `adopt(new
T)` makes the `shared_ptr` with the class's deleter; `Ref<T>(T*)` is `share`; `WeakRef<T>` wraps a
`std::weak_ptr<T>`. Manual `retain()`/`release()` (the `MadeEntityRetained` bare retain, 42
`RetainEntity`, 72 `ReleaseEntity`) and `leakRef`/`adopt` pairs map to a manual-hold counter
inside `oo::Object` that keeps one `std::shared_ptr` to itself while the count is above zero.
Everything builds and passes on the bridge; callers then move area by area to the standard types,
and the bridge is deleted last. This is the 2026-10-28 plan ("`Ref` over `shared_ptr` with the
same names") as a waypoint, not the end state.

**Behaviour the standard types cannot reproduce, and what replaces it:**

- **Weak references during disposal.** Today `dispose()` keeps weak references live while
  `willDispose()` runs and zeroes them before the destructor (`Ref.hpp:175-182`; pinned by
  `test_ref.cpp:514`). A `std::weak_ptr` has expired before any deleter runs, and an expired
  `weak_ptr` cannot even yield its address for comparison. Code reached from `willDispose()` that
  reads a weak reference to the dying entity changes behaviour: known cases are
  `ensureEntityReallyRemoved` → `clearBeacon` comparing `firstBeacon() == beacon`, and the
  Player/Station/Dock `willDealloc` paths (`Entity.cpp:96-137`). Design step D2 inventories every
  such reader, adds a test for each on the bridge (where it passes, FR-016), then fixes each by
  doing the work while the entity is still owned (the Universe's removal path) or by keeping the
  identity pointer next to the `weak_ptr` in that field. Not yet checked: whether any script event
  is sent from `willDispose()`; if one is, a script reading `this` would see an invalid entity.
  D2 answers it. **Spec change** to FR-007 (R15).
- **Stack and static instances.** `shared_from_this` on an object that no `shared_ptr` owns throws
  `std::bad_weak_ptr`, and `weak_from_this` is empty. None exist in `src`. Tests have them:
  `test_OOShaderMaterial.cpp:309,501,588` (a stack `TestTarget : Entity` bound to a weak
  reference), `test_OODebugMonitor.cpp:780` (`static PlayerEntity sStandInPlayer`), and
  `test_ref.cpp:35` (copying a `RefCounted`). Each needs a construction change in the test
  (ledger, R12).
- **Size and cost.** A `std::shared_ptr` is two pointers (`oo::Ref` is one) and entity creation
  allocates no extra control block only if made with `make_shared`, which the disposing deleter
  rules out. Both counts are atomic already (`Ref.hpp:132-136,197`), and references do cross
  threads (async tasks, `OOAsyncWorkManager.cpp:425-446`), so atomicity is required, not a new
  cost. Measured at the end of US2 (R13).

**Alternatives rejected:** keep `oo::RefCounted` for `Entity` only (the smallest risk, but two
ownership systems side by side, and `Entity` is the biggest user). A raw owning pointer in the JS
slot (breaks objects JS shares with C++). `std::make_shared` for entities (cannot run the
disposal hook). Converting call sites first without a bridge (no intermediate state builds).

**Order:** bridge in `oofnd` (with `test_ref` and `test_weakset` ported) → leaf types in
Core-other and Materials and the never-deleted singletons → the script slot → D2 readers and their tests →
Entities, `EntityHold`, the creators and `Universe` → SDL → delete the bridge.

Counts by area (lines): `oo::Ref<` Entities 381, Scripting 138, Materials 262, Core-other 732, SDL
2, oofnd 6, tests 1,197; `oo::WeakRef<` 68/14/1/14/0/4, tests 48; `makeRef` 52/21/16/101/3/1,
tests 582; `EntityHold` 232/63/0/102/0/0, tests 132; the entity retain/release helpers about 197
in src and 227 in tests; 88 `retainCount()` assertions in tests.

## R6. Threads (US3)

**Decision:** `OOAsyncWorkManager`'s workers become `std::vector<std::jthread>` owned by its
internal object, waiting with `std::condition_variable_any::wait(lock, stop_token, pred)`. The
manager gets an explicit `shutdown()` called before `exit(0)` (`GameController.cpp:706`), because
the singleton is never deleted (its destructor calls `abort()`, `OOAsyncWorkManager.cpp:245`) and so a
`jthread` would never be joined. `oo::thread::detach` (one call, `OOAsyncWorkManager.cpp:183`) is
deleted.

- `isMainThread` (4 calls: `OORegExpMatcher.cpp:43,90`, `GameController.cpp:143`,
  `OOAsyncWorkManager.cpp:304`) becomes a comparison of `std::this_thread::get_id()` with one
  main-thread id captured at static initialisation. `OOLogOutputHandler.cpp:100,107,238` has its
  own copy, merged into the same one.
- `setCurrentName` and `setCurrentPriority` stay as the two helpers FR-011 allows
  (`OOAsyncWorkManager.cpp:193-194`, `LogFile.hpp:225`).
- Already owned and joined: the log writer (`LogFile.hpp:165`, `stop()` joins; closed by
  `atexit`) and the HTTP download (`Http.hpp:257`, `~Download` cancels then joins; the progress
  callback aborts within about 1 s). Moving them to `jthread` is cosmetic and optional.
- Shutdown cost: an idle worker wakes on the stop request; a busy one finishes its current task
  (finite: a texture load or planet generation). An HTTP join could wait out a synchronous DNS
  lookup (inferred); that is unchanged from today.
- The work queues are already `std::mutex`/`std::condition_variable`/`std::deque`; the singleton
  is created through `pthread_once` on POSIX, which becomes a function-local static.
- `tinyexr`'s worker pools are vendored and stay.

## R7. `oofnd` components (US4)

| Component | Game use | Verdict | Why |
|---|---|---|---|
| `Expected.hpp` (1,262 lines) | 18 names in 10 files, plus oofnd's own headers | **Replace** with `std::expected` | Same API; only `what()` text differs, and the test checks only that it is non-empty |
| `StdLib.hpp` | included by 164 files | **Delete**; include what you use | The true/false macro guard it existed for is gone (no `#define true` anywhere); game code already includes about 300 standard headers directly |
| `Exception.hpp` | `OORaiseException` 49, `CurrentOOException` 44 | **Keep**, derive `oo::Exception` from `std::exception` | The only standard handler (`OOJSEngineNativeWrappers.cpp:47`) comes after the `oo::Exception` one, so deriving changes nothing today |
| `oo::Finally` | 4 sites | **Keep** | `std::scope_exit` is not in C++23 |
| `OOFoundationTypes.h` integer aliases | `NSInteger`/`NSUInteger` 1,125 lines, `NSTimeInterval` 24, `CGFloat` 14 | **Replace** with `std::ptrdiff_t`, `std::size_t`, `double` | Identical types on MinGW x64, macOS and Linux 64-bit (`intptr_t`/`uintptr_t`), so overloads, the JS boundary and saves see no change |
| `NSNotFound` | 77 | **Replace** with `oo::kNotFound`, same value (`INTPTR_MAX`) | The value is load-bearing: passed to JS as a double (`OOJSSystem.cpp:1636,1717`), cast to `int` → −1 (`PlayerEntityControls.cpp:3632`), save defaults (`ShipEntityLoadRestore.cpp:294,314`), a log (`OOEncodingConverter.cpp:118`). Not `npos` |
| `NSRange`, `NSMakeRange` | 17, 37 | **Keep** with `NSPoint`/`NSSize`/`NSRect` | No standard equivalent; spec change (R15) |
| `Data.hpp` | 166 mentions; a `PList` variant alternative | **Keep** | Not identical: `bytes()` is never null when empty (`vector::data()` may be), and `append(self)` is safe (self-insert into a vector is not). Remove the unused `subdata`. Don't search-and-replace "oo::Data": `OOTypeEncodings.h` and `OOEntityObjectNamesTable.h` hold about 90 frozen log strings that contain it. Spec change (R15) |
| `Date.hpp` | `monotonicSeconds` 12, `timeIntervalSince1970` 4, `description` 4, … | **Partial**: replace the hand-written civil-date algorithm with `std::chrono::year_month_day` and `std::format("{:%F %T}", floor<seconds>(…))` | Same for years 0000–9999 (negative years differ, `-0001` vs `-001`; not reachable). Keep the 2001 reference-date constant, `localUTCOffsetMinutes` (no trusted time-zone database on MinGW, inferred) and the double-seconds helpers |
| `FileSystem.hpp` | 23 functions | **Partial**: callers of `fileExists`, `isDirectory`, `fileSize`, `freeSpace`, `currentDirectory`, `setCurrentDirectory` use `std::filesystem` (`error_code` forms) | The rest keep GNUstep semantics: `removeItem` errors on a missing path, `moveItem` never overwrites, `createDirectories` reports a file in the way, atomic `writeFile`, `/` separators, non-following enumeration, names-only listing |
| `oo::str::format` (545 calls, 534 literal) | — | **Partial, by hand**: literal formats become `std::format` after a `-Wformat-signedness` pass; `vformat`, `formatRuntime` and data formats (`DESC` strings: `OOShipLibraryDescriptions.cpp:154,161,171`, `OOJSPlayerShip.cpp:1928`) stay printf | Output text changes otherwise: `%u` of −1 (pinned in `test_string.cpp`), `%x` of negatives, `%g` must be `{:g}` not `{}`, `%60s` must be `{:>60}`, `%c` of an `int`, null `%s`, `%.4X`, `%.*f`, and 15 literals containing braces. Text reaches saves, logs and the UI |
| `PrintfFormat.h` | 2 game files | **Keep** while printf-style functions remain | |
| `String.hpp` helpers | about 1,460 lines | **Keep** | GNUstep answers: an empty prefix is false for `hasPrefix` (true for `starts_with`, and variable prefixes can be empty: `Universe.cpp:8903`, `OOPListSchemaVerifier.cpp:938,956`), UTF-16 matching and ordering, case tables, `length` in UTF-16 units, GNUstep whitespace, `intValue` through `long`, the 18-digit `doubleValue` scanner, path rules, 32-bit `pointerDescription`, ICU `localizedCompare`. `split`, literal `replaceOccurrences` and `appendingPathExtension` match the standard but are kept for one spelling |
| `Thread.hpp` | | **Partial**: R6 | |
| `Ref.hpp`, `WeakSet.hpp` | | R5 | |
| Notification, Scanner, Process, Log, LogFile, Http, Defaults, ResourcePaths, Encoding, PList*, `OOAssert` | | **Keep** | No standard equivalent, or GNUstep-exact output pinned by tests |

- **Found while implementing T030 (2026-11-12):** clang-tidy's `bugprone-unused-return-value`
  treats `std::expected` as a checked return type, which `oo::Expected` was not, so the nine `oo::fs`
  results the game discards on purpose with `(void)` became errors. `.clang-tidy` now sets
  `AllowCastToVoid: true`: an explicit `(void)` discard is accepted, a silent one is still an
  error. `test_defaults`'s `defaultsDirectoryIsHomeGNUstepDefaults` fails on macOS on the C++20
  base too (Windows paths fed to the macOS filesystem library); it runs only on Windows in CI.
- **Found while implementing T037–T039 (2026-11-12):** clang-tidy 22's `modernize-use-std-format`,
  pointed at `::oo::str::format` with `StrictMode` (casts where printf would read the other
  signedness), converts most literal calls exactly; it skips arguments it cannot cast (`%d` of a
  `uint16_t`/`uint32_t` typedef), `PRIu64` macros and code the build does not compile, which are
  converted by hand. One real flaw: it writes `%.4X` as `{:.4X}`, which `std::format` rejects;
  `{:04X}` is the equivalent. The debug dump code under `DUMP_*` switches has bitrot of its own at
  HEAD (`DumpMipMap`'s callers, two pointer conversions in the planet generator).
- `-fno-exceptions` is not used anywhere in the build, and the game throws (49 raise sites, 75
  `catch (...)`). The README's "headers must compile with `-fno-exceptions`" rule and its "C++20
  only" rule are out of date and are rewritten (FR-023).
- **Lines removable:** `Expected.hpp` 1,262, `StdLib.hpp` 33, Date about 35, FileSystem about 50,
  Thread about 5, format about 30, and `Ref.hpp` + `WeakSet.hpp` net of their replacements about
  450: about 1,850 lines. SC-004's 2,000 is not reachable once `Data` stays (R15).

## R8. Enums (US5)

**Decision:** convert in ten steps (P1–P10 below), each building and passing, with explicit name
strings written before any rename and every externally visible number pinned by `static_assert`.

**Inventory:** 176 unscoped enums (66 named, 110 anonymous), about 1,406 enumerators; 20 existing
`enum class` (16 in oofnd, 4 in Core). Only 5 unscoped enums state an underlying type. By area:
Entities 35 (20 named, including the five `OOEntityEnums.h` tables and `OOBehaviour`), Scripting
33 (27 are JS property-ID enums, 456 enumerators), Debug 9, Materials/OpenGL/Textures 34, SDL/input
9, Core-other about 56 (`OOTypes.h:43-219` has 13).

**External visibility** (must stay byte-identical):

| Mechanism | Enums |
|---|---|
| `#label` in `.tbl` | the ten table enums (`OOConstToString.cpp:39-48,122-127`, `OOConstToJSString.cpp:76-82`) |
| `CASE`/`REVERSE_CASE #foo` | `OOCargoType` (shipdata `cargo_type`), `OORouteType` (JS), `OOEnergyUnitType` (log), `OODockingClearanceStatus` (JS), `OOGraphicsDetail` (console), the HDR/SDR tone mappers (preferences, JS), `OOShaderSetting` (GPU config) |
| `#x` | `console.DEBUG_*` property names (`OOJSConsole.cpp:222-223`) |
| hand-written switch | `WORMHOLE_SCANINFO` (`WormholeEntity.cpp:854-866`) |
| numbers by type encoding `"i"` | 23 types (`OOTypeEncodings.h:83-127`) |
| numbers in shaders | missile, fuel-scoop, compass and alert status (`EntityShaderBindings.cpp:611-661`) |
| numbers in saves | `chart_ana_mode`, `chart_colour_mode`, `speech_on` (`PlayerEntity.cpp:1202-1204,1404`), legacy `energy_unit` (`:1760`), behaviour (`ShipEntity.cpp:6726`) |
| numbers in preferences | joystick `AXIS_*`/`BUTTON_*` ordinals as keys (`OOJoystickManager.h:186`), which shift with `#if OO_FOV_INFLIGHT_CONTROL_ENABLED`; `detailLevel`; key codes |
| numbers in description keys | `gameoptions-detaillevel-[…]`, `oolite-market-filter-/sorter-[…]` (`PlayerEntity.cpp:9390,11722,11731`) |
| numbers through JS properties | alert condition, `oolite.postFX`, `weaponFacings`, `console.debugFlags`, alert flags |
| numbers in data, wire and cache | `weapon_facings` bits, the debug TCP protocol (`OODebugTCPConsoleProtocol.h`), texture options in a `%X` cache key (`OODefaultShaderSynthesizer.cpp:353`) |

**What `enum class` breaks:** about 1,630 `case` labels (about 1,000 in 54 `switch (magic)` blocks
over an `int`); 345 subscripts (233 in `PlayerEntityControls.cpp`, `joyButtonState[BUTTON_*]`);
about 223 bit operations; about 209 relational comparisons (mixed int/enum ones break, e.g.
`alertFlags > ALERT_FLAG_YELLOW_LIMIT`, `PlayerEntity.cpp:5870`); about 110 arithmetic uses,
including ordinal stepping (`PlayerEntityControls.cpp:2237,2971,2977,3755,3762`,
`Universe.cpp:11280,11286`) and `GUI_ROW()` (111); about 25 sentinels; 56 C-style casts to enum
types; narrow storage (`OOWeaponFacingSet` `uint8_t`, `OOAlertFlags` `uint16_t`, `_normalMode : 2`
bit-field, `OOMesh.h:163`). `cxx_OOCastParam` (`OOStringExpander.h:380-385`) needs an implicit
conversion, so its four call sites fail to compile: the safe failure.

**Design:**

- `src/Core/OOEnumFlags.h`: `oo::ToUnderlying` (until every caller can use `std::to_underlying`),
  an opt-in `FlagEnum` concept (an ADL-found `OOEnableFlagOperators(E)` returning `std::true_type`),
  and `|`, `&`, `^`, `~`, `|=`, `&=`, `^=` plus `oo::Any(e)`, declared at global scope and
  constrained by the concept. No bitmask template exists today.
- `src/Core/OOEnumTable.h`: each named enum's header has `constexpr std::string_view
  OOEnumName(E)` as a `switch` with the external spelling written out, and the reverse lookup built
  from it by `oo::MakeEnumTable`, following `notes/2026-11-07 Enum Tables from tbl X-Macros.md`.
  Types listed in `OOTypeEncodings` get `std::int32_t`.
- Enumerators are `kPascalCase` (`OOScanClass::kNeutral`). External strings come from the name
  switch, never from the identifier.
- Anonymous enums that hold one constant (about 50) become `inline constexpr` typed constants:
  they are not enumerations (spec change, R15).
- JS property-ID enums (27): `enum class … : std::int16_t` (QuickJS's `magic` is `int16`), cast in
  the `OOJS_PROPERTY_*` macros, `using enum` inside each getter's `switch`. `OOJS_PROP_*` flags are
  QuickJS's own `uint8_t` property flags and stay: **exceptions list**.
- `OODebugTCPConsoleProtocol.h` is the wire format shared with the external debug console: its
  numbers stay as they are, typed (`enum class` with a fixed underlying type and `static_assert`s)
  where nothing outside reads the header as C; design step D5 decides.
- GUI rows: `GUI_ROW(GROUP, ITEM)` token-pastes enumerator names (`PlayerEntity.h:68-72`) and
  `#if GUI_FIRST_ROW() < 0` (`PlayerEntity.h:165,199`) is always false (the preprocessor reads the
  enumerator as 0): both become `constexpr` functions and `static_assert`s.
- `GameViewKeys` (compared with characters and `OOKeyCode`) and `OOPixMapFormat` (a component
  count used in arithmetic): D5 decides between `enum class` with helpers and typed constants; the
  default is typed `inline constexpr` constants in a namespace, on the exceptions list as values of
  a C-defined code space.
- Test stand-ins that redeclare production enums (`test_OOJSStation.cpp:44-57`,
  `test_OOJSPlayer.cpp:35-58`, `test_OOJSOolite.cpp:28-46`, `test_OOJSSound.cpp:33-39`,
  `test_OOOXZManager.cpp:707`) must change in the same commit as the production enum: a stale
  stand-in still links (an ODR mismatch nobody sees).

**Order (P1–P10):** P1 infrastructure (`OOEnumFlags.h`, `OOEnumTable.h`, the naming check
non-fatal); P2 file-local named enums in `.cpp` files (about 12, no tests); P3 single-constant
anonymous enums → `inline constexpr`; P4 internal header enums, 4–6 per commit; P5 bitmasks, one
per commit, `OOTexture` last (275 src and 95 test references); P6 number-visible enums (alert,
fuel scoop, missile, fleeing, speech, market filter/sorter, graphics detail, shader setting) with
`static_assert`s; P7 the eight `CASE` string enums; P8 the ten `.tbl` enums in the 2026-11-07
note's order; P9 the int-natured groups (JS property IDs, GUI rows, `AXIS`/`BUTTON`, key codes);
P10 the 20 existing `enum class` definitions renamed to `kPascalCase`, then the naming check made
fatal.

**P10 and hard rule 1.** Renaming an existing `enum class`'s enumerators is not "replacing [a
name] by its standard equivalent", so the amended rule 1 does not plainly cover the test edits it
forces (`PList::Type::Null` and others appear in the PList tests). P10 is ordered last and its
ledger entries are marked *needs sign-off*; it starts only when Jon has signed them. Until then
the naming check stays non-fatal. Recorded in plan.md *Notes*.

Rename volume: about 8,760 references in `src` (the table enums 1,345, JS property IDs 1,637) and
about 1,400 in 96 test files. Stringification ties identifiers to external text in four places
(`.tbl` `#label`, `CASE #foo`, `DEBUG_FLAG_DECL #x`, `GALACTIC_HYPERSPACE_##label`); each gets
explicit strings before its rename.

**Corrections to the 2026-11-07 note:** the `tests/idiom_check.py` and
`check_headers_standalone.py` gates it cites were deleted (`8ec7631d3`); the `gen-*.py` banners now
say "maintained by hand"; `switch (v_dir)` is now `HeadUpDisplay.cpp:4658` and `mode + 1` is now
`PlayerEntityControls.cpp:2237`.

## R9. Tests and the ledger (FR-015)

**Decision:** two files in this spec's directory, `exceptions.md` and `test-ledger.md`
([data-model.md](data-model.md)). A test edit is made in the same commit as the production change
that forces it, and its ledger row in the same commit.

Test files naming the replaced names: `oo::Ref<` 165 files (1,202 uses), `oo::makeRef` 149 (586),
`AutoreleaseScope` 32 (316, unchanged by R5.3), `oo::WeakRef` 14 (52), `oo::Expected` 6 (41),
`NSUInteger` 21 (81), `NSInteger` 3 (16), `oo::thread::` 1 (21), `oo::RefCounted` 42; enumerators
in 96 files (about 1,400), enum types in 48 (280). `oo::Data` stays (R7), so its 35 test files are
not touched.

Tests of components that change shape:

| Test | Plan | Rule 1 coverage |
|---|---|---|
| `test_ref` | ported to `oo::Object`, `oo::share`, `std::shared_ptr`/`weak_ptr` and the rebuilt `AutoreleaseScope`. The `willDisposeRunsOnceWithTheObjectWhole` case (`:514`) asserts that weak references are live during `willDispose()`, which no `std::weak_ptr` design can keep (R5), and the bridge commit is where it would start failing. Its new expectation (weak references empty from the start of disposal) changes an assertion's meaning, which rule 1 does not allow, so it is a *needs sign-off* row and **US2's bridge commit waits for Jon's sign-off** (plan.md *Milestones*) | edits covered; `:514` needs sign-off |
| `test_weakset` | ported to the `std::weak_ptr` `WeakSet` | covered |
| `test_thread` | the `detach`/`isMainThread` cases ported to `std::jthread` and the id comparison | covered |
| `test_expected` | ported to `std::expected` (it then pins the standard library's behaviour, which keeps its assertions) | covered |
| `test_stdlib` | tests a header that is deleted; nothing to port to | **reported to Jon**, kept building until he decides (the header stays, unused by the game, until then) |
| `test_foundation_types` | pins `NSInteger` as `long long` (LLP64 only) | ported to assert `std::ptrdiff_t`/`std::size_t` identities where the aliases were; reported to Jon if any assertion has no counterpart |
| `test_date`, `test_filesystem`, `test_string` | unchanged: the oofnd functions they test stay | — |
| stack/static instances (`test_OOShaderMaterial.cpp:309,501,588`, `test_OODebugMonitor.cpp:780`, `test_ref.cpp:35`) | construction becomes `oo::makeShared` or a never-deleted static | construction form: **marked borderline** in the ledger for Jon's sign-off |
| `tests/unit/core/EntityStandIn.h` | mirrors `Entity`'s bases; follows the base change | covered |
| enum renames of existing `enum class` (P10) | as R8 | **needs sign-off** |

## R10. Performance (SC-008)

**Decision:** measure with the method in `notes/2026-11-10 Frame Rate Comparison.md` (a JS frame
callback over the debug console, driven through `tests/launch_snapshot.py`) at three points: the
base, the end of US2 and the end of the feature, same machine, five runs each, median. The pass bar
is the spec's: not slower beyond the measurement's own run-to-run spread. `launch_snapshot.py:257`
gives start-up time.

- Spec 006's performance tier does not exist yet (spec and checklist only). Its scratch scripts
  (`.agent-tmp/hudrepro/fps_bench.py` and others) are git-ignored and not relied on; the method is
  rewritten as `tools/` script only if the measurement is needed more than three times.
- **Measured 2026-11-12:** the absolute numbers move by about a third between sessions (machine
  state), far more than the spread within one, so every later comparison re-measures the C++20
  base in the same session from a `git worktree` of `518520d43` (baselines.md *Same-session
  comparison*). C++23 plus T014–T019 showed no difference beyond the spread.
- Suspects: `shared_ptr` is twice `Ref`'s size, entities need a separate control block (no
  `make_shared` with the disposing deleter), and `share()` is a `weak_ptr` lock. Atomic counting
  is not new (R5).

## R11. Sanitizers

**Decision:** ASan through `--setup-flags=-Db_sanitize=address` on a build directory of its own:
the unit suites under ASan on Windows (where they run), the smoke run under ASan on macOS. Leaks:
`/usr/bin/leaks --atExit` on macOS (Xcode's toolchain has no LSan; Homebrew LLVM's LSan on arm64
is unreliable, inferred), LSan in a Linux CI job if one is added. TSan for US3 with Homebrew LLVM
on macOS over the smoke run.

- No sanitizer build type or option exists (`mk.sh` has deployment, test, dev, debug).
  `tests/unit/asan-suppressions.txt` holds three Windows third-party `interceptor_via_lib` entries
  and is not edited.

## R12. Overlaps and docs (FR-023)

- **Spec 003** (encapsulate global state) is planned only: no branch, no tasks. Its plan's gate
  row "Services are `oo::Ref<oo::RefCounted>`. There is no `shared_ptr`" (`plan.md:99`) conflicts;
  it is amended to `std::shared_ptr<oo::Object>`.
- **CLAUDE.md** says "Ownership is `oo::Ref<T>`, not `shared_ptr`". It changes when US2's bridge is
  deleted, not before (agents working on other branches meanwhile still see `oo::Ref`).
- Also updated: the 4p doc's "out of scope here (Phase 6)" paragraph, the Phase 6 doc's exit gate
  (the items this feature does), the idiom review's two `.tbl` "keep" lines and its `Ref` decision,
  `oofnd/README.md` (rules, the remaining components and their reasons), and the 2026-11-07 note's
  stale gates.
- `seriesb/027-ship-library-keys` exists on `origin`, built on `026-dev-container`; it is not an
  ancestor of this branch and is not affected.
- Whether `seriesb/027-modern-cpp` joins spec 002's series manifest is Jon's call; this feature
  does not add it.

## R13. Upstream merges

Not researched further: Jon decided on 2026-10-28 that class design stays close to upstream and
on 2026-11-07 that enumerators become `kPascalCase` anyway. The enum renames (about 8,800
references) are the change that most affects porting upstream fixes; `tools/upstream-delta.sh` and
`docs/UPSTREAM_DELTA.md` are the existing route for that, and US5 goes last to keep the window
short.

## R14. Bugs found while researching

- `OOALSoundDecoder.cpp:442`: a buffer leak on every OXZ Vorbis read (fixed by US1).
- `PlayerEntity.h:165,199`: `#if GUI_FIRST_ROW() < 0` is always false (fixed by P9, no behaviour
  change).

## R15. Changes this research makes to the spec

Made in [spec.md](spec.md) on 2026-11-11, each because the standard library cannot do what the
spec required without changing behaviour:

1. **FR-006 / US2:** `oo::AutoreleaseScope` and `oo::WeakSet` stay, rebuilt on the standard
   pointers (R5.3, R5.4).
2. **FR-005:** never-deleted singletons, written in plain std at each site, on the exceptions list (R5.7).
3. **FR-007:** disposal keeps its effects; non-owning references read empty from the start of
   disposal, and code that read them during disposal is rewritten under tests (R5).
4. **FR-013 / US4:** `oo::Data` and `NSRange` stay (R7).
5. **FR-017:** single constants become typed constants, not enums (R8).
6. **SC-004:** at least 1,500 lines (R7).
7. **Context:** the `realloc` leak is already fixed; the Vorbis leak is new (R4).

## R16. C-style casts (US6, M5)

**Decision:** convert area by area after the enums (M4), starting each area with clang-tidy's
`google-readability-casting` fix-its and finishing by hand; then make the check fatal and turn on
`-Wold-style-cast` for the game in the same commit.

- **Size.** About 690 lines cast to a built-in type the C way (regex, 2026-11-11); the idiom
  review's compiler pass counted about 1,595 `-Wold-style-cast` warnings including pointer casts,
  against about 935 `static_cast`s. Worst files then: `PlayerEntity.cpp` (169), `ShipEntity.cpp`
  (144), `OOOpenGLExtensionManager.cpp` (131), `Universe.cpp` (99). M0 records the exact baseline:
  the check's finding count from `./mk.sh tidy`.
- **Why after M4:** converting to `enum class` already rewrites the 56 C-style casts to enum types
  and the 18 enum-to-int casts (R8); doing casts first would touch them twice.
- **What each becomes:** arithmetic and enum conversions `static_cast`; removing `const`
  `const_cast`; pointer reinterpretation `reinterpret_cast`; `void*` from a C callback back to its
  type `static_cast`; byte reinterpretation through `memcpy` (`OOPlanetTextureGenerator.cpp:809`,
  `OOStandaloneAtmosphereGenerator.cpp:438`) `std::bit_cast`. The 152 `(Entity*)nullptr` ternary
  arms become `static_cast<Entity*>(nullptr)`. Casts to `void` are not C-style casts for the check
  and stay.
- **Same conversion, always.** A C-style cast that compiled as `reinterpret_cast` or dropped
  `const` must be spelled as that, not "fixed"; a fix is a separate, recorded bug. Float-to-integer
  truncation is identical under `static_cast`, and `-ffp-contract=off` is untouched, so simulation
  results do not move.
- **Macros.** Casts inside our own macros are rewritten in the macro. Casts that come from
  expanding third-party macros (GL, SDL, QuickJS) are reported only if those headers are not
  treated as system headers; M0's baseline shows whether any are, and each is an exceptions-list
  row.
- **Guard:** `google-readability-casting` (flags every C-style cast in C++) into
  `WarningsAsErrors` once at zero; `-Wold-style-cast` added to the game's warning flags in
  `src/meson.build` in the same commit (GCC and Clang both have it), so it adds no warnings.
- Tests are not first-party C++ for this story and are not touched.

**Alternatives:** `cppcoreguidelines-pro-type-cstyle-cast` (flags only casts that act as
`reinterpret_cast`, `const_cast` or a downcast, so most arithmetic casts would remain); converting
before the enums (double work); a script rewrite (cannot tell which C++ cast a C cast performs).

## R17. C strings (US7, M6)

**Decision:** convert by area (the six of the epics outline: Entities, Scripting,
Materials/OpenGL/Textures, SDL/Debug, Core-top, `oofnd`), signatures first, with the boundary rules
in [contracts/strings.md](contracts/strings.md); the C string functions and `printf` family then go
behind `bugprone-unsafe-functions`.

- **Size (2026-11-11):** 717 `const char*` lines, 99 `char name[N]` buffers, 36
  `snprintf`/`sprintf`/`vsnprintf`, 22 C string-function calls, 6 `atoi`/`atof`/`strtol`/`strtod`.
- **Legitimate `const char*`:** string literals and the C interfaces that need a null-terminated
  pointer: QuickJS (`JS_NewAtom`, `JS_NewString`, `JS_GetPropertyStr` and kin), SDL, OpenGL (shader
  sources, uniform names), OpenAL, libpng (error callbacks), libcurl (`curl_easy_setopt`),
  `getenv`, `main`'s `argv`. These stay, as literal types or exceptions-list rows.
- **Signatures:** text a function only reads becomes `std::string_view`; text it keeps or returns
  becomes `std::string`; `std::optional` of either where null meant "no text". Functions that
  return a literal return `std::string_view` (or stay `const char*` where every caller passes the
  result to C, as a listed exception). Tables of literals (`static const char* names[]`) become
  `constexpr std::array<std::string_view, N>`; the enum name tables are already this after M4.
- **The `std::string_view` trap:** it is not null-terminated, so its `data()` must never reach a
  C call; and it must not outlive the string it views. Contract rules: no `string_view` member
  except over a literal; every C call takes `c_str()` of a `std::string` or a literal. ASan judges
  the lifetime part.
- **Formatting:** the 36 `printf`-family calls become `std::format` by the method R7 settles for
  `oo::str::format` (by hand, `-Wformat-signedness` first, output compared). `char` buffers that
  existed only to format into go with them.
- **Comparison and search:** `strcmp` and friends become `std::string_view` operators and members;
  the exception-name comparisons (`Universe.cpp:4496,4562,4602,10451`) become `==` on
  `std::string_view`.
- **Parsing:** `std::from_chars` only where it gives today's answer for every input the tests use;
  it differs from `strtol`/`atoi` on leading whitespace, a leading `+`, overflow and the width of
  `long` (R7's `intValue` note). Those parses keep (or move to) an `oofnd/String.hpp` helper.
- **Buffers C fills** (OS paths, GL info logs, `OOCPUInfo`) stay as `std::array<char, N>` or a
  sized `std::string` at that call.
- **Guard:** `bugprone-unsafe-functions` is already fatal through `bugprone-*`, with its default
  list. Its `CustomFunctions` option takes the extra names (`strcpy`, `strncpy`, `strcat`,
  `strncat`, `strcmp`, `strncmp`, `strcasecmp`, `strlen`, `strdup`, `strchr`, `strrchr`,
  `strstr`, `strtok`, `sprintf`, `snprintf`, `atoi`, `atof`; not `vsnprintf`, which `oofnd`'s
  printf engine keeps for printf-syntax data formats, FR-026), each with its
  replacement as the message (checked with clang-tidy 22 on a sample). Because the check is
  already fatal, the option is added in the commit that brings the count to zero, not before.
  `const char*` itself has no clean check: it is tracked by a search and the exceptions list.
- Tests are not touched (src only). `oofnd` stays C++: its `String.hpp` helpers already take
  `std::string`/`std::string_view`.

**Alternatives:** `std::string` everywhere (copies at every call and a conversion at every C
boundary); `const char*` → `std::string_view` by script (cannot see the C-boundary and
null-termination cases); a separate spec (Jon chose this one, 2026-11-11).
