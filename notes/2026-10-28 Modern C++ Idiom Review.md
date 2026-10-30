# Oolite C++ idiom review: where the code is not idiomatic modern C++

## Context

Review of `oolite-dev/src/{Core,SDL,oofnd}`: 518 first-party files, about 286k lines (vendored MiniZip, miniz/tinyexr and stb excluded). It was prompted by four things Jon had already noticed: `typedef enum`, macros used as constants, scattered platform `#ifdef`s, and the `oofnd` compatibility library. All four are confirmed and quantified below, and the review turns up more.

Counts come from ripgrep line counts, with a comment-and-string-stripping scanner for the preprocessor numbers. Some compiler numbers come from a `clang++ -fsyntax-only` pass over every game translation unit with extra warnings enabled. Treat regex counts as ±10–20%. I spot-checked the build standard, the `UNIVERSE`/`PLAYER`/`MIN` macros, the `OO_LOG` macro, and the two `SDL/main.cpp` defects against the tree; the rest is as reported by the review passes and not re-read line by line. Nothing in the repo was modified.

**Headline: the build is `gnu++20`, not C++23** (`src/meson.build:53`; `src/oofnd/meson.build:19` uses `c++20`). `oofnd/Expected.hpp` (1,262 lines) is a `std::expected` polyfill waiting on that upgrade, and `.clang-format` claims C++23. Several findings below (`std::expected`, `std::print`, `std::to_underlying`, `std::unreachable`, `std::byteswap`) depend on moving the standard first.

The newer layers (`oofnd/*.hpp`, `Core/Scripting/ooscript/`) are mostly idiomatic: `std::optional`, `std::variant`, `std::format` logging, `constexpr`, `override` discipline (0 `-Wsuggest-override` hits). The ported game code (Universe, PlayerEntity, ShipEntity, HeadUpDisplay, textures, meshes, Octree, OOCache) still reads as C plus Objective-C.

---

## Decisions (Jon, chat 2026-10-28)

Scope, from the inline comments above:
- **In:** 1.1, 1.2, 1.3, 1.4 (all), 2.2 (all: no `malloc`/`calloc`/`realloc`/`free`; `unique_ptr`/`shared_ptr`/std containers), 2.3 (most: no C strings; address out-parameters; leave `goto` unless the refactor is simple; leave the control-state globals in `PlayerEntityControls.cpp` because they match upstream), 2.4 (use the standard library wherever possible), 2.5 (bugs), 2.6 (tooling).
- **Out:** 2.1 (class design stays close to upstream to keep merges easy). Also out: `EntityFilterPredicate` (the `void*` callback). Everything else Jon named stays in, including `UNIVERSE`/`PLAYER`, `oo::Ref`, `OOCache`.
- **Self-containment:** `oolite-dev` must not reference the planning repo. Tests run through `./mk.sh test test` and `tests/run.sh`. The outer desktop-lock lookup is **dropped** from `oolite-dev` tests (not replaced).
- **Structure:** two epics. Epic A (Phase 4p): self-containment, the 2.5 bugs, tooling, warnings already at zero hits. Epic B (Phase 6, gated on the 4p exit): the sweeps and structural work.
- **Bead size:** no per-bead file or line caps (dropped globally the same day). A bead is one tick's work, sized by pattern (tree-wide, tool-driven) or by area. About 126 beads in total; the list is in the epics outline.
- **Open:** `.clang-tidy` and `.editorconfig` contents (to discuss).

---

## 1. Your four areas, quantified

### 1.1 Enums and typedefs

> Jon: Fully address section 1.1

- `typedef enum` 56, `typedef struct` 63, all `typedef` ~200 (vs 93 `using X =`).
- 175 unscoped `enum` definitions vs 31 `enum class` (17 of those have no explicit underlying type). 29 single-line `enum { kFoo = N }` constant bundles.
- Nearly all `enum class` is in oofnd and ooscript. The core is C-style: `OOTypes.h:43,51,110,129,204`, `OOEntityEnums.h:39,63,87`, `PlayerEntity.h:83,216,235`, `ShipEntity.h:175`, `OOOpenGLStateManager.cpp:58`.
- Three naming styles coexist: ALL_CAPS (~1,176), `kFoo` (~781), CamelCase (~696). `kFoo` is also used on `constexpr` constants.
- Enums used as bitmasks with raw integer `|`: `OODebugFlags.h:5`, `PlayerEntity.h:211` (`ALERT_FLAG_*` stored in `uint16_t`), `OOWeaponFacing` stored in `uint8_t`, `OOTextureFlags`, `OOUniformConvertOptions`; `OOJavaScriptEngine.cpp:731` carries a `NOLINT` for it. The `JSEngine.hpp` bitmask enums are the correct pattern.
- Sentinels inside enums (`_COUNT`, `_MAX` 58, `_END` 27, `_LAST`): `PlayerEntity.h:153,258,269`, `OOOpenGLMatrixManager.h:52`.
- Parallel `const char*[]` tables indexed by enum: `OOOpenGLMatrixManager.cpp:34`, `OOShaderUniformMethodType.cpp:53`.
- Function-pointer typedefs (14), anonymous `typedef struct {}` (28), a raw tagged `union` at `OOShaderUniform.h:145`.
- **Fix:** `enum class Foo : std::uint8_t`, one bitmask-operator template, `using`, `std::array<std::string_view, N>`.

### 1.2 Macros instead of constants

> Jon: Fully address section 1.2

- 1,360 first-party `#define`s: 953 object-like, 407 function-like.
- **606 constant-valued defines are never tested by `#if`** (475 numeric, 118 string, 7 bool, 6 expression) and can become `inline constexpr` today.
- Biggest clusters: `HeadUpDisplay.h` 156 (`:51`, `:65`, `:190`), `ShipEntity.h` 66, `PlayerEntity.h` 55, `OOFoundation.h` 29, `Universe.h` 27, `OODebugTCPConsoleProtocol.h` 23, `MyOpenGLView.h` 21, `PlayerEntityKeyMapper.h:41-62` (row ids), `ShipEntityLoadRestore.cpp:40-60` (string keys).
- Bitmasks as macros: `OOVoxel.h:39-44`, `OODebugFlags.h:20`, `OOJoystickManager.h:136-146`, `OOJSEngineCore.h:545-567`.
- Macros that hide expressions or state:
  - `UNIVERSE` (`Universe.h:996`, 2,373 uses in 94 files) and `PLAYER` (`PlayerEntity.h:2029`, 429 uses) expand to global accessors.
  - `HYPERSPEED_FACTOR` calls through `PLAYER`; `SHIP_ENERGY_DAMAGE_TO_HEAT_FACTOR` reads a member named `mass`.
  - `STAGE_TRACKING_BEGIN`/`END` expand to `{` and `}` (`PlayerEntity.cpp:342-365`).
  - `SYSTEM_REPOPULATION_INTERVAL 20.0f;` has a trailing semicolon (`Universe.h:201`).
- Function-like macros that should be functions:
  - `MIN`/`MAX`/`ABS` are defined twice (`OOMaths.h:105-137` as GNU `({})` statement-expressions, and `OOFoundation.h:104-125`). About 206 uses, and they trigger ~460 `-Wgnu-statement-expression` hits (`ShipEntity.cpp` 82, `PlayerEntity.cpp` 72). `std::min/max/clamp` is used 7 times.
  - `OOINLINE` is `#define OOINLINE inline`, used 344 times.
  - `EXPECT`/`EXPECT_NOT` over `__builtin_expect`: ~579 uses, with 0 `[[likely]]`.
  - `OOJSSTR`/`OOJSID` are statement-expression macros (236 uses) with non-thread-safe function-local statics.
  - `OO_LOG` (1,224 call sites) and `OOCAssert` (218) pass `__FILE__`/`__LINE__` by hand; `std::source_location` is used 0 times.
  - 61 `do {} while(0)` wrappers, 53 empty no-op stubs, and `OOJSEngineNativeWrappers.h:80-161` and `OOJSEngineCore.h:576-631`, which wrap `try`/`catch` and braces in macros.
  - `OOStringExpander.h` has a 62-argument preprocessor `MAP` (78 macros), used 135 times. It stringifies variable names into dictionary keys, so it needs a small design decision rather than a mechanical swap.
  - `OOFunctionAttributes.h:13-21` redefines the reserved names `__has_feature`, `__has_attribute` and `__has_extension`.
- Attributes are barely used: `[[nodiscard]]` 4, `[[noreturn]]` 2, `[[maybe_unused]]` 1 (vs 20 `GCC_ATTR((unused))`), `[[fallthrough]]` 0, `[[deprecated]]` 0.
- Keep: the 11 X-macro `.tbl` tables are a defensible pattern.
- **Fix:** `inline constexpr` in namespaces; `enum class` for row-id and key tables; inline functions for `UNIVERSE`/`PLAYER`; `std::min/max/clamp/abs`; standard attributes.

### 1.3 Platform-specific macros

> Jon: Fully address section 1.3

- 1,235 conditional directives in 241 files. **201 are OS/toolkit/compiler platform tests in 53 files**, and ~123 of ~230 platform/feature directives sit inside function bodies.
- Counts: `OOLITE_WINDOWS` 63, `OOLITE_MAC_OS_X` 60, `_WIN32` 29, `OOLITE_SDL` 18, `OOLITE_LINUX` 16, endian macros 27.
- Feature switches are heavier than platform ones: `OO_DEBUG_MONITOR_ENABLED` has 186 directives in 86 files, and it is tested by `#ifdef` 173 times and by `defined()` 11 times while siblings are tested by value.
- Worst files: `GameController.cpp` (23 OS directives; 33 total), `Universe.cpp` (62 total), `OOLogHeader.cpp` (36), `OOOpenGLExtensionManager.cpp`, `OOFoundation.h`, `OOLogOutputHandler.cpp`, `OOCPUInfo.cpp`, `PlayerEntityControls.cpp`, `MyOpenGLView.cpp`.
- Body-level examples:
  - `PlayerEntityKeyMapper.cpp:147-155` (keymap file name by OS)
  - `ResourceManager.cpp:670-674` (`USERPROFILE` vs `HOME`)
  - `OOCPUInfo.cpp:91-122` (CPU count by OS, plus inline asm; `std::thread::hardware_concurrency()` is already used in `oofnd/Process.hpp:111`)
  - `OOOpenGLExtensionManager.cpp:581,646,669`
  - `OOJSOolite.cpp:290,373` (a feature gated by platform)
  - `main.cpp:89-156`
  - `Debug/OODebugTCPConsoleClient.cpp:426,597` (Winsock start-up)
  - oofnd itself: `Process.hpp`, `Thread.hpp`, `Http.hpp`, with `_WIN32` inside inline function bodies. `Http.hpp:366` has no non-Windows implementation.
- Build structure: every platform compiles the identical source list. `src/meson/{windows,linux}/meson.build` only add `-D` flags and libraries. `-DGNUSTEP_BASE_LIBRARY=1` is passed globally, so `OOLITE_MAC_OS_X` is always 0, and **about 787 lines of Mac code (43 blocks) are dead**, for example `GameController.cpp` (354 lines), `OOLogHeader.cpp` (155) and `OOLogOutputHandler.cpp` (145). `MOZ_TRACE_JSCALLS` branches (SpiderMonkey) are dead too.
- Win32 prototypes are hand-declared to avoid `<windows.h>` (`Process.hpp:50-58`, `Defaults.hpp:84-87`, `Thread.hpp:54-67`, `ResourcePaths.hpp:80`, `Http.hpp:73`), which accounts for most of the first-party `extern "C"`.
- Windows ANSI APIs are used without the `W` form (`main.cpp:95,106,145`, `OOCPUInfo.cpp:198`), so non-ASCII install paths will break.
- Already abstracted: SDL3 for window and input (only 30 `SDL_` lines in 8 Core files), OpenAL, and `oo::fs/process/env/thread/ResourcePaths/Defaults`, though those wrappers use `#if` inside the functions.
- **Fix:**
  - A `platform::` interface (`cpu_count`, `os_name`, `keymap_file`, `user_dir`, `message_box`, `socket_init`, `gl_proc_address`), with one source file per OS chosen in `src/meson/<os>/meson.build`.
  - A generated `config.hpp` of `inline constexpr bool`s with `if constexpr`.
  - `std::endian` instead of the endian macros.
  - Delete the Mac and SpiderMonkey dead code.

### 1.4 `oofnd`

> Jon: Make the recommended corrections in section 1.4.

- A 13.4k-line header-first Foundation replacement (namespace `oo`) used by 337 of 494 other files (68%).
- Usage: `oo::PList` 7,120 uses, `oo::Ref` family 1,552, `oo::str::*` 1,465, `OO_LOG*` 1,222, `oo::str::format` 546, `oo::fs` 263, `oo::Defaults` 124, `oo::Exception` 103.
- The parts that are genuinely Objective-C-shaped, with the standard replacement:

| oofnd piece | What it mimics | Modern replacement |
|---|---|---|
| `Ref.hpp` | `retain`/`release`/`autorelease`, `AutoreleaseScope` (51 uses), `adopt`/`leakRef` (87 calls) | `std::shared_ptr`/`weak_ptr` or a plain intrusive pointer; drop autorelease |
| `objc/OOFoundationTypes.h` | `NSInteger`/`NSUInteger` (~1,160 lines), `NSPoint`/`NSSize`/`NSRect` (~540–620), `NSRange` (~151), `NSNotFound` | `std::size_t`/`std::ptrdiff_t`, project `Point`/`Size`/`Rect` structs, `std::optional` index |
| `Expected.hpp` | C++20 polyfill | `std::expected` after the C++23 switch |
| `String.hpp` | `NSString` method names (`hasPrefix`, `lastPathComponent`, `intValue`) | `starts_with`, `std::filesystem::path`, `from_chars`, `std::format` |
| `Date.hpp` | `NSDate`, hand-written civil-date maths (`:80-106`) | `std::chrono` |
| `Notification.hpp` | `NSNotificationCenter`, `const void*` object keys | typed signals or `std::function` |
| `Data.hpp` | `NSData` | `std::vector<std::byte>` plus `std::span` |
| `Exception.hpp` | `OOException` deliberately not a `std::exception`; `@finally` via `oo::Finally`; `OORaiseException` with printf-style formats | derive from `std::runtime_error`; `std::format` |
| `StdLib.hpp` | umbrella over ~20 standard headers, "do not include standard headers directly" (132 includers) | include what you use |
| `PrintfFormat.h`, `oo::str::format` | `vsnprintf` with `__attribute__((format))` (546 calls) | `std::format` |
| `Core/OOCallByName.h` | `performSelector` emulation by type encoding | a name-to-function map or a switch |
| `%@` emulation (`formatRuntime`, `DescriptionOf`) | `NSString stringWithFormat:` | typed `std::formatter`s |

- Keep as genuinely new code: the PList/XML/old-style parsers and writers, `Encoding.hpp`, `Http.hpp` (but add a non-Windows backend), `Defaults.hpp`.
- Migration residue: the `cxx_` identifier prefix appears 2,340 times in 181 files; the README and many comments still describe `.mm` files; the `oofnd` meson file declares 28 `.hpp` + 1 `.h`.

---

## 2. Further findings beyond your list

> Jon: SKIP SECTION 2.1. I'm worried that it will make it hard to merge in changes from the upstream. There are still changes and it is nice that these class designs are similar to the upstream for now.

### 2.1 Class design (Objective-C shape)
- Two-phase construction: ~300 `initWith*` in 115 files, 130 static `...With/From` factories, and 28 static functions literally named `init*` that return `oo::Ref` (`Octree.h:53,86`, `OOALSound.h:54`). Failure is signalled by null or by a throwing `malloc` wrapper (`OOShipGroup.h:48`, `CollisionRegion.cpp:67`). **Fix:** real constructors with `oo::makeRef<T>(...)`.
- Names carried over from selectors: 405 `get*` declarations, 353 `...ForKey`/`...WithDictionary`/`...AtIndex`, snake_case mixed in (`PlayerEntity.h:403-409`).
- No encapsulation in the central classes: `Universe` has a single `public:` and ~100 data members; `Entity.h:266-324` has ~27 public data members.
- Singleton and global coupling: `UNIVERSE` / `PLAYER` macros and 317 `shared*()` accessors.
- God classes: `PlayerEntity` is 31.5k lines across 10 `.cpp` files (header 2,052 lines, ~90 data members); `ShipEntity` 17.4k lines across 4 files; `Universe.cpp` 11.8k lines.
- Test seams that distort the design: an X-macro `UniverseVirtualMembers.h` expanded by both the real class and a stand-in, and `virtual` methods added to `PlayerEntity` only for tests (`PlayerEntity.h:405-416`). **Fix:** extract abstract interfaces.
- `const` correctness is poor: ~96% of zero-argument member declarations in game headers are non-const (2,308 non-const vs 92 const), e.g. `OOColor.h:105-134`. clang-tidy adds 545 more `.cpp` candidates (`ShipEntity.cpp` 115, `Universe.cpp` 76, `HeadUpDisplay.cpp` 56) and 243 that could be `static`.
- `[[nodiscard]]` 0 in the game, `noexcept` 35 (vs 321 in oofnd), `explicit` 44, `static_assert` 2.
- `override` discipline is good (779 uses, 0 suggest-override hits). The 10 destructors that lack `override` are `Universe.h:223`, `GameController.h:72`, `OOOXZManager.h:94`, `OOGraphicsResetManager.h:55`, `OOOpenGLExtensionManager.h:56`, `OOVisualEffectEntity.h:72`, `OOJavaScriptEngine.h:59`, `OODebugTCPConsoleClient.h:86`, `OOJSEngineCore.h:444`, `OOSkyDrawable.cpp:87`.
- 25 `OOLogGenericSubclassResponsibility()` runtime stubs where pure virtuals belong (`OOALSound.cpp:135`, `OOAsyncWorkManager.cpp:268`), and `~OOAsyncWorkManager() { abort(); }` (`:262`).
- Members: 124 uninitialised members (`HeadUpDisplay.cpp` 37), 49 `prefer-member-initializer`, 22 `-Wshadow` sites.

### 2.2 Memory and ownership

> Jon: Fully modernize according to the recommendations in this section 2.2. I don't want to use malloc, calloc, realloc, free, I would want to use std::unique_ptr, shared pointers, etc.

- 157 `malloc/calloc/realloc/free` calls in 48 files. Worst: `MyOpenGLView.cpp`, `OOJSVector.cpp`, `OOPlanetTextureGenerator.cpp`, `OOProbabilisticTextureManager.cpp` (four parallel arrays), `OOTextureScaling.cpp`, `Octree.cpp`, `CollisionRegion.cpp:67,202`, `OOMeshToOctreeConverter.cpp:812-820` (a comment admits a leak on `realloc` failure).
- 270 raw `new` and 42 `delete`; leaked singletons (`Notification.hpp:86`, `Defaults.hpp:452`, `OOShaderProgram.cpp:93`, `OOMaterial.cpp:46`); 277 `owning-memory` hits. `unique_ptr` 12, `shared_ptr` 4, `make_unique` 2.
- Three ownership styles are mixed: raw `Entity*` (~4,900 mentions), `oo::Ref` (1,517), `oo::EntityHold` (338) and `oo::WeakRef`.
- 41 raw owning pointer members in headers, freed by hand in destructors.
- `void*`: 295 uses. Callback-plus-`void*` APIs survive in `OOTCPStreamDecoder.h:36-54`, `OOALSoundDecoder.cpp:42-83`, `OOConcreteTexture.h:120`. **`EntityFilterPredicate(Entity*, void* parameter)` is typedef'd three times** (`Universe.h:77`, `ShipEntity.h:60`, `UniverseVirtualMembers.h:56`), with 12 predicates (`OOEntityFilterPredicate.cpp:38-172`) and `const_cast<std::string*>` to satisfy it (`ShipEntityAI.cpp:2278-2327`). **Fix:** `std::function` or a template parameter taking a lambda.
- Hand-rolled structures: `OOCache` (splay tree plus an age list behind a raw `OOCacheImpl*`, `OOCache.cpp:121-144`), `OOPriorityQueueOf` (`OOPriorityQueue.h:55-140`; use `std::priority_queue`).
- Type-punning with `memcpy` that should be `std::bit_cast` (`OOPlanetTextureGenerator.cpp:809`, `OOStandaloneAtmosphereGenerator.cpp:438`, `JSEngine_quickjs.cpp:260,298,453`); eight near-identical colour `memcpy`s (`OOBasicMaterial.cpp:187-221`). 396 C arrays (`HeadUpDisplay.cpp` 42); `sizeof x / sizeof *x` in 13 places.

### 2.3 C strings, casts, integers, globals

> Jon: Address most of section 2.3.
> Don't use C strings.
> You can use the goto code for now, unless it is a simpler refactor.
> There is a lot of global state for controls, but that is in upstream, so I don't want to change it for now.
> Do address the Out-parameters.

- `const char*` 783, `char name[N]` 96, `snprintf` 30, `strcmp` 12 (exception names compared with `strcmp` in `Universe.cpp:4496,4562,4602,10451`), `strlen` 5, `strcat` 4. `OORaiseException` has 58 call sites.
- `const std::string&` ~1,900–2,100 vs `std::string_view` ~430. `std::optional<std::string>` const-ref (626) emulates a nil `NSString*`.
- C-style casts: 630 arithmetic plus 388 pointer; 1,595 `-Wold-style-cast` hits vs 935 `static_cast`. Worst: `PlayerEntity.cpp` (169), `ShipEntity.cpp` (144), `OOOpenGLExtensionManager.cpp` (131), `Universe.cpp` (99). A double cast is at `MyOpenGLView.cpp:594-595`.
- `(Entity*)nullptr` in 152 ternaries; `NULL` 1,112 vs `nullptr` 12,312; 299 `f(void)` prototypes; 12 `register`.
- Narrowing: `-Wimplicit-float-conversion` 1,421 (`ShipEntity.cpp` 298, `HeadUpDisplay.cpp` 223), `-Wsign-conversion` 870, 38 double-literals assigned to float, 52 float array initialisers with double literals.
- `NSUInteger`/`NSInteger` are `intptr_t` typedefs (~1,160 uses); `GLfloat` 1,842 uses and `typedef GLfloat OOScalar` (`OOMaths.h:71`).
- `M_PI` hand-defined (`OOMaths.h:78-98`, ~71–82 uses); `std::numbers` 0. `rand()` fills `very_random_seed` (`ShipEntity.cpp:13371-13376`, `PlayerEntityLegacyScriptEngine.cpp:1242-1247`). `std::clamp` 0, with ~125 custom `OOClamp_*`/`OOLerp` calls. `legacy_random` is deliberate for save compatibility and not flagged.
- `goto` 38 in 9 files (`OOJSShip.cpp` 17, `OOPolygonSprite.cpp` 5, `PlayerEntityControls.cpp` `goto abort`, and macro-hidden `goto END` in the two planet texture generators). The libpng `setjmp` in `OOPNGTextureLoader.cpp` is forced by the C library.
- Mutable global state: `PlayerEntityControls.cpp:86-99` has ~84 file-scope `static bool …_pressed` flags; 241 non-const file-scope statics; 127 `extern` globals in headers (`gOOPlayer`, `gDebugFlags`, `gLiveEntityCount`, 69 GL function-pointer externs). Const externs that should be `inline constexpr`: `OOMatrix.h:43`, `OOBoundingBox.h:43`, `legacy_random.h:54`.
- Out-parameters: ~536 `outFoo` lines, e.g. `getJSClass(ClassDef** outClass, …)` repeated across entities, `readCreatingBuffer(char** outBuffer, size_t* outSize)`. **Fix:** `std::optional`, `oo::Expected` or struct returns.

### 2.4 Standard-library features unused or reimplemented

> Jon: Use the std library where possible.

- `<chrono>`: 54 uses, but `OOProfilingStopwatch.h:92-126` keeps four platform branches.
- Raw `fopen/fclose` in 21 places (`OOJSConsole.cpp:1290,1316`, `OOOXZManager.cpp:2486,2503`, `OOShipRegistry.cpp:1672`); manual lock/unlock pairs (`OOAsyncWorkManager.cpp:253-258,292-343`, `OOLogOutputHandler.cpp:558-562`, `OOOpenGLExtensionManager.cpp:396-402`); one `pthread_once`.
- Manual `OOLog` indent/outdent pairs (19 each); `oo::Finally` used in only 7 places.
- Unused: `<random>`, `<bit>` (44 hand-written endian macro hits), `<numbers>`, `<source_location>`, `std::print`, `std::to_underlying`, `std::bit_cast`; `std::span` 10 uses (92 `const std::vector<>&` parameters and 15 pointer+length pairs could use it); `std::variant` only inside `PList`.
- Loops: 347 index-based loops vs 439 range-for; 57 loop to `.size()`; `erase(remove(...))` ×3 (`OOOXZManager.cpp:256`, `OOShipRegistry.cpp:463`, `ResourceManager.cpp:148`); `.size() == 0` ×29; 117 `use-emplace` and 93 `use-ranges` clang-tidy hits.
- `-Wundef` would flag 54 sites.

### 2.5 Likely real bugs found while reading (verified against the source)

> Jon: Address bugs where possible.

- `src/SDL/main.cpp:139`: `strcat(SDL_getenv("LOCALAPPDATA"), "\\Oolite\\oolite.app")` appends into the environment's own buffer, which is undefined behaviour and a likely overflow. It is compiled only when `OO_GAME_DATA_TO_USER_FOLDER` is set.
- `src/SDL/main.cpp:~191-205`: after `-load`, `i++` can make `argv[i]` equal `argv[argc]` (NULL), and the following `strcmp("-help", argv[i])` dereferences it. The guard on the line above (`i < argc`) covers only the suffix check.
- `src/SDL/main.cpp:102-127`: a 256-byte `MAX_PATH_LEN` buffer for the exe path, and `strlen(systemPath)` with no null check if neither `Path` nor `PATH` is set.
- `OOCPUInfo.cpp:202-203`: `strcpy`/`strcat` into `outUBRString`. Buffer size not checked; verify.
- `OOMeshToOctreeConverter.cpp:820`: a known leak when `realloc` fails.

### 2.6 Build and tooling

> Jon: Sure, make improvements here.
> .clang-tidy is needed. We should discuss .clang-tidy and .editorconfig in chat in more detail.

- No `-Wextra`, `-Wpedantic` or `-Werror` for the game; only oofnd tests use `warning_level=2` and `werror` (clang only). Enabling `-Wextra -Wpedantic -Wunused -Wsign-compare` over the game produced **0 hits**, so it is free to turn on. Cheap next: `-Wundef` (54), `-Wsuggest-destructor-override` (10), `-Wshadow` (22), `-Wimplicit-fallthrough` (13). Add `-Wold-style-cast` and `-Wconversion` non-fatal first.
- No sanitizer options in the build files; no `.clang-tidy`, no `.editorconfig`. `.clang-format` is Google style.
- 263 `.h` files, at least 172 of which contain C++ (`class`/`template`/`namespace`), plus 28 `.hpp`. Pick one extension.
- CI runs clang-format and a launch smoke test. It does not run the unit tests, clang-tidy or sanitizers; `.travis.yml` is stale Xcode/Objective-C.
- **Revised 2026-10-28 (Jon): `oolite-dev` must not reference the planning repo at all.** The first draft called `tools/check-oofnd.sh`, `tools/check-core-tests.sh`, `tools/check-deployment-tests.sh`, `tools/asan-suppressions.txt` and `tests/golden/check_build_flags.py` "missing". They existed in the planning repo (`OoliteMigration/tools`, `OoliteMigration/tests/golden`) until the 2026-10-28 cleanup commit removed them, so these references now dangle outright. `oolite-dev` should be self-contained, and its tests run through `./mk.sh test test` and `tests/run.sh`. About 88 references in 26 files (meson files, `meson.options`, `tests/launch_snapshot.py`, `tests/gui/conftest.py`, `tests/component/{conftest,console}.py`) point outward. Most are comments (`tools/check-*.sh`, `tests/golden/...`, `docs/phases/...`, `docs/stories/...`). Two are functional: `tests/launch_snapshot.py` (~`:1265`) and `tests/component/conftest.py` (~`:22`) look for `tools/desktop_lock` and `tools/gui-lock` in the outer repository, and `tests/gui/conftest.py` (~`:1495`) does the same. `build/meson_debug/compile_commands.json` is stale (lists four deleted `.c` sources). There is no root `compile_commands.json`.
- `project(['c','cpp'])` is still C-enabled (needed for QuickJS). `tools/` still has 10 `.m`/`.c` files.
- Tests: 174 core + 40 oofnd unit tests on a bespoke 111-line harness (`oo_test.hpp`), built only on Windows; plus 31 pytest component/GUI tests.

---

## 3. Suggested remediation order

Ordered by value over risk, and now organised as two epics ([[2026-10-28 Idiom Epics and Beads Outline]]): **Epic A = steps 1 and 2**, **Epic B = steps 3 to 8**, each on its own branch and merged locally by Jon. A bead is one tick's work with a command that fails before and passes after; there is no file or line cap. The "no `-Wno-*`" and "never modify tests" rules apply, so a warning flag is enabled only where its count is 0, and each epic ends with an end gate (`./mk.sh build test`, then `tests/run.sh` `unit`, `component`, `smoke`, `gui`). The Tier B/C scripts and goldens this section used to cite no longer exist.

1. **Tooling first (no behaviour change):** add `.clang-tidy` and `.editorconfig`; enable `-Wextra -Wpedantic -Wundef -Wsuggest-destructor-override` (all at 0 or near-0 hits); fix the dangling script references; run unit tests in CI; add a sanitizer build option. Decide whether to move to `-std=c++23` now.
2. **Fix the real defects:** the `SDL/main.cpp` `strcat` and `argv` bugs, then move the Windows start-up code to `W` APIs and `std::filesystem::path`.
3. **Mechanical, test-gated sweeps:** `NULL` → `nullptr` (1,112); drop `(void)` / `f(void)` / `register` / `OOINLINE`; `typedef` → `using`; add `override` to the 10 destructors; add `const`/`[[nodiscard]]`; replace `MIN`/`MAX`/`ABS` with `std::min/max/abs`; `M_PI` → `std::numbers`; `EXPECT` → `[[likely]]`. One bead per pattern across the whole tree, done with a clang-tidy fix or a short script.
4. **Constants:** turn the 606 untested object-like defines into `inline constexpr`, starting with `HeadUpDisplay.h`, `ShipEntity.h`, `PlayerEntity.h`; row-id and key tables become `enum class`.
5. **Enums:** convert `typedef enum` and unscoped enums to `enum class`, starting with bitmask enums (`OODebugFlags`, `OOWeaponFacing`, `ALERT_FLAG_*`, `OOTextureFlags`), and add one shared bitmask operator template. The `OOJS*.cpp` `enum : std::uint8_t` blocks come last.
6. **Platform layer:** introduce `platform::` with Windows and Linux source files, move the in-body `#if`s out (start with `GameController.cpp`, `OOCPUInfo.cpp`, `OOLogHeader.cpp`, `PlayerEntityKeyMapper.cpp`, `ResourceManager.cpp`), generate a `config.hpp` for the feature switches, and delete dead Mac and SpiderMonkey branches.
7. **oofnd retirement of Objective-C shape:** replace `NSUInteger`/`NSInteger`/`NSPoint` etc. with standard and project types; drop the `cxx_` prefix and the `StdLib.hpp` umbrella; migrate `oo::str::format` to `std::format`; make `oo::Exception` derive from `std::runtime_error`; swap `Expected.hpp` for `std::expected` once on C++23.
8. **Structural, last and largest:** `OOCache`/`OOPriorityQueue` → std containers; `malloc`/`realloc` arrays → `std::vector`; `Ref` over `std::shared_ptr`. **Dropped by decision (2026-10-28):** replacing the `UNIVERSE`/`PLAYER` macros (they stay global, as upstream), `initWith*` → constructors, the `EntityFilterPredicate` + `void*` callback, splitting `PlayerEntity`/`ShipEntity`/`Universe`, and the test-seam virtuals (all §2.1 or upstream-merge risk).

## 4. What not to change
- `legacy_random` (save-game compatibility), the `.tbl` X-macro tables, libpng's `setjmp`, and the C-API glue in `JSEngine_quickjs.cpp` (void* and C casts there are legitimate).
- `oofnd`'s PList, XML/old-style parsers, `Encoding.hpp` and `Defaults.hpp` are genuinely new library code, not Objective-C emulation.

## 5. Caveats
- Counts are regex-based; comment and licence-text matches are included unless noted. `nil` (1,195) and `BOOL/YES/NO` (321) appear only in comments, not in code.
- One clang-tidy pass covered `.cpp` files only; header-level findings (`explicit` constructors, header `const`) are from grep, not clang-tidy.
- Not reviewed: `tests/`, `tools/`, `subprojects/`, `Resources/` scripts.
- The generated files `OOPlanetData.cpp` (48k lines) and `OOEntityCalledByNameTable.h` (3k lines) inflate some size and `std::numbers` counts.
