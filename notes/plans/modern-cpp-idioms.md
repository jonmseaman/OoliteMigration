# Modern C++ idioms: what's left of the 2026-10-28 review

Status: **Prepare**. Replaces `2026-10-28 Modern C++ Idiom Review.md` and
`2026-10-28 Idiom Epics and Beads Outline.md` (Jon's comments: fully address §1.1, §1.2 and §1.4,
§2.2 and §2.4, most of §2.3, and §2.5 and §2.6; §2.1 out). Platform code (§1.3, B5) is in
[platform-layer.md](platform-layer.md).

## Why

The review and outline predate spec 009 (`specs/009-modern-cpp-std`, done), which did most of the
`oofnd` and ownership work. This plan records what is now done, and turns what is left into
workstreams with done checks, so the two notes can be deleted.

## Already done (counts in `src/`, 2026-11-15)

| Review item | Now |
|---|---|
| C++23 (B0) | `-std=c++23`; `Expected.hpp` gone, `std::expected` used |
| `typedef` → `using` | 2 left (0_AI_Tasks, done in `603decc60`) |
| Unscoped enums → `enum class`; one bitmask template | 0 unscoped, 117 `enum class`; `OOEnumFlags.h` |
| `.tbl` X-macro tables | `enum class` tables (spec 009 US5) |
| `OOINLINE` | 0 (0_AI_Tasks) |
| `MIN`/`MAX`/`ABS` | 4 left (2 files) |
| Dead Mac and SpiderMonkey code | gone (comments only) |
| `cxx_` prefix, `StdLib.hpp` umbrella, `.mm` mentions | 0 |
| `oo::Ref` → `std::shared_ptr`/`weak_ptr` | done (spec 009). `AutoreleaseScope`/`autorelease` stay as `oofnd` README "Surviving components" (pool rules pinned by `test_ref`) |
| `oo::Exception` derives from the standard hierarchy | `class Exception : public std::exception` |
| `NSInteger`/`NSUInteger` | 3 left |
| `OOStringExpander` `MAP` macro | 0 |
| `malloc`/`calloc`/`realloc`/`free` | 0 |
| C string functions, `printf` family | 0, except `oofnd`'s printf engine (FR-026) |
| C-style casts | `-Wold-style-cast` on; `google-readability-casting` is a clang-tidy error |
| §2.5 bugs (`main.cpp` `strcat`, `-load` argv read, 256-byte path buffer, `OOCPUInfo` `strcpy`, the octree `realloc` leak) | all fixed |
| §2.6 tooling: `.clang-tidy`, `.editorconfig`, root `compile_commands.json`, CI unit tests + clang-tidy guards, stale `.travis.yml` | all done |

**Stays by decision.** These are recorded in `oofnd/README.md` ("Surviving components") and spec 009.
Don't reopen them:
- `oo::Data`, `NSRange`, `NSPoint`/`NSSize`/`NSRect`, `Notification`, `Finally`, `Scanner`,
  `AutoreleaseScope`, `PrintfFormat`.
- `oo::str`'s GNUstep-named helpers (`hasPrefix`, `intValue` …), because their answers differ from
  the standard's (pinned).
- `formatRuntime`/`%@`, needed for formats that are data (`DESC` entries, plists).
- `OOCallByName`, already a generated table.
- `UNIVERSE`/`PLAYER`, class design (§2.1), `EntityFilterPredicate`, the control-state globals in
  `PlayerEntityControls.cpp`, `legacy_random`, and the `.h`→`.hpp` rename.

## Already on `0_AI_Tasks.md` (don't duplicate)

`using X = struct` → `struct X`; `static_assert` → `std::to_underlying`; the redundant `inline`;
redundant `static_cast`; unused includes; the cpplint `whitespace/braces`, `include_what_you_use`,
`readability/braces` and `runtime/int` tasks; `OOTypeEncodings.h`; `OOLITE_OPENAL`.

## Workstreams

Each is one commit (or one per area) on a `git town append` branch. Each needs `./mk.sh build dev`
with no new warnings and a passing `tests/run.sh unit`. Area order, where one is needed: Entities,
Scripting, Materials/OpenGL, SDL/Debug, the rest of Core, `oofnd`. Counts exclude
`src/Core/OOPlanetData.cpp` (generated).

### Maths and randomness (B1, B9)

- **I1. `M_PI` → `std::numbers`.** Done: oolite-dev 5ceffa8d4. 72 uses in 20 files; the defines are at `OOMathsBase.h:59-65`.
  `M_PI` → `std::numbers::pi`, `M_PI_2` → `std::numbers::pi / 2`, `M_PI_4` → `/ 4`, and
  `std::numbers::pi_v<float>` where a float is wanted. These are the same doubles.
  - The tests use `M_PI` 11 times (`test_DockEntity`, `test_MyOpenGLView`, `test_OOFlasherEntity`,
    `test_OOJSVector`, `test_OOMathsHeaders`, `test_ShipEntity`, `test_WormholeEntity`). Changing
    them is a std-equivalent edit (rule 1, third exception), so list each in this plan's ledger.
  - Done: `! git grep -qE '\bM_PI(_2|_4)?\b' -- src tests`.
- **I2. `OOClamp*` / `OOLerp*` → `std::clamp` / `std::lerp`.** Not started (worker, 2026-11-15): with `_GLIBCXX_ASSERTIONS` in dev builds, `std::clamp` aborts when `lo > hi`. Several `OOClamp_0_max_*` maxima are data-driven (`maxEnergy`, `maxThrust()`, `maxFlightSpeed`, shield maxima), and `OOClamp_0_max_f(v, m)` with `m < 0` gives 0 today, so they need `std::clamp(v, 0.0f, std::max(0.0f, m))`. `OOClampInteger(v, 1, pageCount)` likewise. Each `OOLerp` caller passing doubles also needs casts to keep the float arithmetic. That's a careful per-site pass. 124 + 9 uses in 39 files; the
  definitions are at `OOFastArithmetic.h:32-110`.
  - `OOClampInteger(v, lo, hi)` gives the same results as `std::clamp` when `lo <= hi`. Check each
    call site; `std::clamp` is undefined when `lo > hi`.
  - `OOClamp_0_1_f` etc. use `fmax(lo, fmin(v, hi))`. That matches `std::clamp` except for NaN: today
    NaN comes out as the upper bound, and with `std::clamp` it stays NaN.
  - `OOLerp(a, b, t)` is `a + t*(b - a)`. `std::lerp` can differ in the last bit; it is exact at
    t = 0 and 1, and monotonic.
  - `test_OOMathsHeaders.cpp:37` calls `OOClamp_0_1_f`, a std-equivalent edit for the ledger.
  - If a test with an exact comparison fails after the change, stop and report it. Don't edit it.
  - Done: `! git grep -qE '\bOOClamp\w*|\bOOLerpd?\b' -- src tests`.
- **I3. `rand()` → `<random>`.** Done: oolite-dev 93209e011. 18 calls: three identical blocks fill `very_random_seed` byte by
  byte (`ShipEntity.cpp:13433-13438`, `13525-13530`, `PlayerEntityLegacyScriptEngine.cpp:1251-1256`)
  and pass it to `seed_RNG_only_for_planet_description`.
  - Replace them with one `Random_Seed oo::RandomDescriptionSeed()` in `legacy_random.{h,cpp}`, beside
    `Random_Seed`. It draws the six bytes from a function-local
    `std::mt19937 engine{std::random_device{}()}` with `std::uniform_int_distribution<int>(0, 255)`.
    It is called on the game thread only; say so in its comment.
  - `legacy_random`'s own generators stay. They're needed for save compatibility.
  - Nothing in `tests/` names `rand` or `very_random_seed`.
  - Done: `! git grep -qE '\bs?rand\s*\(' -- src`.

### Macros (§1.2, B3, B10)

- **I4. Constant `#define`s → `inline constexpr`.** 414 numeric and 112 string defines that no `#if`
  tests. Worst: `HeadUpDisplay.h` 156, `ShipEntity.h` 66, `PlayerEntity.h` 54, `Universe.h` 26,
  `OOFoundation.h` 22, `MyOpenGLView.h` 21. One commit per header, then the `.cpp`-local defines by
  area, then the const `extern`s (`OOMatrix.h`, `OOBoundingBox.h`, `legacy_random.h`).
  - Keep each name and type: an unsuffixed `1.0` stays `double`, `1.0f` stays `float`, and a string
    becomes `std::string_view`, unless a caller needs `const char*` or concatenates literals.
  - A define tested by `#if` stays (it's a switch; see `platform-layer.md` P6).
  - Fix the trailing `;` in `SYSTEM_REPOPULATION_INTERVAL` on the way.
  - Done: `git grep -cE '^\s*#\s*define\s+[A-Z_][A-Z0-9_]*\s+(\(?-?[0-9.]+[fFuUlL]*\)?|")' -- src`
    is 0, apart from listed exceptions such as values a `#if` reads.
- **I5. `EXPECT`/`EXPECT_NOT` → `[[likely]]`/`[[unlikely]]`.** Done: oolite-dev f6c15da0f. 544 uses in 88 files.
  - `if (EXPECT(x))` becomes `if (x) [[likely]]`. Where the macro is used outside an `if`, drop the
    hint.
  - Delete the macros.
  - Done: `! git grep -qE '\bEXPECT(_NOT)?\(' -- src`.
- **I6. `OOJSSTR`/`OOJSID` → inline functions.** 246 uses in 29 files. They are statement-expression
  macros with function-local statics.
  - Write a `constexpr`-keyed inline function that returns the interned atom, with thread-safe
    static initialisation.
  - Done: `! git grep -qE '\bOOJS(STR|ID)\(' -- src` (or the macros reduced to one-line forwards, if
    a caller needs a macro for stringising; record which).
- **I7. `OO_LOG` and `OOCAssert` use `std::source_location`.** The macros stay, so arguments aren't
  evaluated when logging is off, but they stop passing `__FILE__`/`__LINE__`/`__func__`.
  - Done: `! git grep -qE '__FILE__|__LINE__' -- src/oofnd/Log.hpp src/oofnd/objc/OOAssert.h src/Core/OOLogging.h src/Core/OOLoggingExtended.h`,
    and the log line text is unchanged (`test_log` pins it).
- **I8. Small macro fixes:** Partly done: oolite-dev c4c3406b6 (the `__has_*` fallbacks and the five dead macros that used them, `[[maybe_unused]]`, `ABS`). Left: `STAGE_TRACKING_BEGIN`/`END`, because the catch logs the in-flight exception's name and reason, which a destructor can't read during unwinding, so a scope object would change the log line. A lambda wrapper would keep it; the default taken is to leave them. The `do { } while (0)` review isn't done yet.
  - Delete the reserved-name `__has_feature`/`__has_attribute`/`__has_extension` redefinitions
    (`OOFunctionAttributes.h`, 3).
  - `GCC_ATTR((unused))` → `[[maybe_unused]]` (1).
  - `STAGE_TRACKING_BEGIN`/`END` (14 uses, `PlayerEntity.cpp:342-368`; they expand to `{`/`}`) → an
    RAII scope object.
  - The last 4 `MIN`/`MAX`/`ABS` → `std::min`/`max`/`abs`.
  - Look at each of the 97 `do { } while (0)` macro wrappers. Turn one into an inline function where
    it takes no statement arguments; leave the rest.
  - Done: `! git grep -qE 'define\s+__has_(feature|attribute|extension)|GCC_ATTR\(\(unused|STAGE_TRACKING_|\b(MIN|MAX|ABS)\(' -- src`.

### Enums and types (§1.1, B4)

- **I9. The rest of §1.1:** done (oolite-dev b9a6f792f, 2e5e0057b, f4ad5bfeb).
  - The NOLINT was in `ShipEntityAI.cpp` (two `randf()` draws), now two named draws; `src/` has
    no NOLINT.
  - `OOShaderUniform`'s union is a `std::variant`; the GL upload takes the array's `data()`.
  - `ooliteStandardMatrixUniforms` and `kSpiderMonkeyGlobals` are `std::array<std::string_view>`.
    `ShipEntityAI.cpp`'s `argNames` stays a `const char*[]`: `OOJSFunction::initWithName` takes
    `const char**`.
  - Sentinels: the `GUI_ROW_MARKET_*` and `OOLITE_GL_MATRIX_*` values are already `inline
    constexpr int`, not enumerators. Renaming `OOLITE_GL_MATRIX_END` to `kCount` would edit
    `test_OOOpenGLMatrixManager.cpp`, which no exception covers, so it stays.
  - Enum sentinels. `GUI_ROW_MARKET_LAST`/`END` (`PlayerEntity.h:161-162`) and
    `OOLITE_GL_MATRIX_END` (`OOOpenGLMatrixManager.h:80`) become `kCount` constants beside their
    enum.
  - Enum-indexed `const char*[]` tables (`OOOpenGLMatrixManager.cpp:33`, and any other
    `git grep -nE 'const char\s*\*\s*\w+\[\]\s*=' -- src` finds) → `std::array<std::string_view, N>`
    with a `static_assert` on the size.
  - The raw tagged `union` in `OOShaderUniform.h:163` → `std::variant`, if that keeps the layout
    rules the GL upload code relies on. If it doesn't, leave it and record why.
  - The one `NOLINT` (`OOJavaScriptEngine.cpp`): fix the finding and remove it.
  - Done: `! git grep -qE 'NOLINT' -- src`, plus the three sites converted or recorded.

### Memory and ownership (§2.2, B7)

- **I10. Raw `new`/`delete`.** 119 `new` and 29 `delete` in 69/22 files.
  - Partly done (oolite-dev dd056a3fa, 56428113f): the OXZ download, the profiler table, the
    deferred frame-callback operations and timers are `std::unique_ptr`; `stopAll()` takes the
    playing set into one.
  - Decision: leaked singletons (`new std::shared_ptr<X>(…)`, `*new T`) stay. Google style forbids
    statics with non-trivial destructors, and exit-time destruction would run GL/AL/JS teardown
    after those libraries have gone. This overrides the "function-local statics" bullet below.
  - The `delete`s left, and why: `OOTCPStreamDecoderAbstractionLayer.cpp` (`OOALRelease`,
    `OOALDestroyAutoreleasePool`: the C decoder's create/release API), `OOJSQuaternion.cpp` and
    `OOJSVector.cpp` (QuickJS finalizers of opaque pointers), `oofnd/Object.hpp` (`oo::Dispose`
    itself), `GameController.cpp:190` (the call leaks on purpose when its handler throws),
    `OOJSScript.cpp:533` (the running stack mixes stack and heap elements), `OOCache.cpp` (I11
    replaces it; another session has it checked out).
  - `new` is fine when a smart pointer owns the result at once (spec 009's rule). Otherwise use
    `oo::makeShared`/`std::make_unique`.
  - Leaked singletons → function-local statics or `std::unique_ptr` (`Notification.hpp`,
    `Defaults.hpp`, `OOShaderProgram.cpp`, `OOMaterial.cpp` in the review; recheck).
  - Owning raw pointer members freed in destructors → `std::unique_ptr`.
  - Done: `! git grep -nE '\bdelete(\s*\[\])?\s+[a-zA-Z_]' -- src` finds nothing, and every
    remaining `new` is a smart pointer's argument (list the exceptions).
- **I11. Hand-rolled containers.**
  - `OOCache` (51 uses, 7 files) → standard containers with the same eviction rule (age list plus
    size limit) and the same on-disk cache format.
  - `OOPriorityQueue` (9 uses, 3 files) → `std::priority_queue`, keeping the ordering, including
    ties.
  - Done: `! git grep -qE '\bOOCache\b|OOPriorityQueue' -- src`. Then `tests/run.sh component --cpp`
    and a smoke run. The cache files must still load: run the game once with an existing cache.
- **I12. Type punning and C arrays.**
  - `memcpy` used for punning → `std::bit_cast` (`OOPlanetTextureGenerator.cpp`,
    `OOStandaloneAtmosphereGenerator.cpp`, `JSEngine_quickjs.cpp`; 28 `memcpy` in total, so check
    each).
  - The eight colour `memcpy`s in `OOBasicMaterial.cpp` → one helper.
  - `sizeof x / sizeof x[0]` (12) → `std::size`. Done: oolite-dev 208df5e56.
  - C arrays (about 233) → `std::array` by area, starting with `HeadUpDisplay.cpp`. Leave arrays
    passed to C or GL APIs whose layout must stay, or use `.data()`.
  - Done: `! git grep -qE 'sizeof\s*\(?\s*\w+\s*\)?\s*/\s*sizeof' -- src`, and the punning `memcpy`s
    are listed as converted.
- **I13. `void*` callbacks.** The `void*` + callback APIs in `OOTCPStreamDecoder.h`,
  `OOALSoundDecoder.cpp` and `OOConcreteTexture.h` → `std::function` or a lambda template.
  `EntityFilterPredicate` stays (decision). Leave `void*` at C interfaces (QuickJS, OpenAL, libpng,
  GL).
  - Done: each of the three APIs takes no `void*` context parameter.

### Strings, nulls, out-parameters (§2.3, B8)

- **I14. `NULL` → `nullptr` and `f(void)` → `f()`.** Done: oolite-dev dfa85c8ba (five asserts on nonnull parameters went, as clang then called them tautological). 85 `NULL`s in code and 146 `(void)`
  parameter lists. Run clang-tidy `modernize-use-nullptr` and `modernize-redundant-void-arg` with
  `--fix`, then add both to `.clang-tidy`'s `WarningsAsErrors`.
  - Done: `run-clang-tidy -p . -checks='-*,modernize-use-nullptr,modernize-redundant-void-arg' 'src/(Core|SDL|oofnd)/.*\.cpp'`
    reports nothing, and both are errors.
- **I15. C strings.** 541 `const char*` and 9 `char buf[N]` (spec 009 FR-027).
  - Owned text → `std::string`, borrowed text → `std::string_view`.
  - `const char*` stays only as a literal's type or at a C interface (list each kind once).
  - Do it by area.
  - Done: the remaining `const char*` lines are all literal types or C-interface calls, with the
    list recorded in this plan.
- **I16. Out-parameters.** About 679 `outFoo` lines in 94 files. Convert by family to
  `std::optional`, `std::expected` or a returned struct:
  - JS `getJSClass(ClassDef**, …)`;
  - the sound decoder's `readCreatingBuffer`;
  - the shader-uniform getters;
  - the PList schema verifier;
  - the `Universe` finders;
  - JS `Vector`/`Quaternion`;
  - the rest.

  Don't change a signature that JS or the by-name tables expose by name unless they're updated in
  the same commit.
  - Done per family: no `out[A-Z]` parameter left in its files.
- **I17. `goto`.** 42 in 11 files (`OOJSShip.cpp` 17). Replace only where a simple early return or
  RAII scope does it. Leave the rest, and libpng's `setjmp`.
  - Done: each remaining `goto` is listed with why it stays.
  - Done (oolite-dev 118cb1b6a): 39 of 42 went. Each label's code is a lambda the old `goto`s now
    `return` through, or the code nests in an `if`; `OOPolygonSprite`'s tesselator is a
    `std::unique_ptr` and its SVG dump ends in an `oo::Finally`. The 3 left are in
    `OOPNGTextureLoader.cpp:88,94,105`: they share the `FAIL` label with libpng's `setjmp` error
    path, and an RAII object in a frame that `longjmp`s past is undefined behaviour.
- **I18. Narrowing.** Turn on `-Wconversion` (with `-Wimplicit-float-conversion` and
  `-Wsign-conversion`) once its count is 0. Fix by area first, starting with `ShipEntity.cpp` and
  `HeadUpDisplay.cpp`, using a local build with the flag added, uncommitted, just to count. Commit
  the flag only once the build is clean (rule 2: never `-Wno-*`).
  - Done: `src/meson.build` has `-Wconversion`, and `./mk.sh build dev` is warning-free.

### Standard library (§2.4, B9)

- **I19. Standard-library swaps:**
  - `fopen`/`fclose` (13, 7 files) → `std::ifstream`/`std::ofstream` on `std::filesystem::path`.
  - Manual `.lock()`/`.unlock()` pairs (37, 18 files) → `std::lock_guard`/`std::scoped_lock`.
  - `OOLogIndent`/`Outdent` pairs (30) → an RAII indent scope.
  - `erase(std::remove(…))` (3) → `std::erase`/`std::erase_if`. Done: oolite-dev 208df5e56.
  - `.size() == 0` (4) → `.empty()`. Done: oolite-dev 208df5e56.
  - Index loops over `.size()` (35) → range-for, or `std::views::enumerate` where the index is used.
  - `const std::vector<T>&` parameters that are only read, and pointer-plus-length pairs →
    `std::span`.
  - Done: `! git grep -qE '\bf(open|close)\(|erase\(\s*std::remove|\.size\(\)\s*==\s*0' -- src`, and
    the lock and indent pairs are converted.
  - Worker, 2026-11-15:
    - `fopen`: the ship registry's strings dump is a `std::ofstream` (ca1149b63). The rest stay,
      each at a C interface: `OOJSConsole.cpp:1298` (`JS_DumpMemoryUsage` takes a `FILE*`),
      `OOALSoundDecoder.cpp:178` (`ov_open_callbacks`), the OXZ manager's `_fileWriter` (made by
      `oo::fs::openFile`, flushed by `oo::fs::synchronizeFile`, both `FILE*`), and `oofnd/` (being
      retired; no changes there). So the done grep cannot reach zero.
    - Lock pairs: the five in `OOAsyncWorkManager.cpp` and `OOOpenGLExtensionManager.cpp` are
      `std::lock_guard` (ab992e2f2); no other manual pairs are left.
    - Indent pairs: `oo::LogIndentScope` (`src/Core/LogIndentScope.h`, tested) replaces the 17 pairs
      that bracket one block (a75ae2803). Left as calls, because the indent and outdent sit under
      separate conditions or in different functions: `AI.cpp:540`, `Entity.cpp:792`,
      `ShipEntity.cpp:13686`, `OOCheckShipDataPListVerifierStage.cpp:244,259`,
      `OOOXPVerifier.cpp:601`, `OOJSEngineTimeManagement.cpp:106,170`.
    - Not started: index loops to range-for, and `std::span` parameters.
- **I20. `std::print`.** Where code writes text to `stdout`/`stderr` directly (not through
  `OO_LOG`), use `std::print`/`std::println`.
  - Done: `! git grep -qE '\b(std::)?(puts|fputs)\(|std::cout|std::cerr' -- src` (list any that
    must stay).
  - Blocked (worker, 2026-11-15): on MSYS2 UCRT64, libstdc++ keeps `std::print`'s terminal
    support in `libstdc++exp`, so `std::print` fails to link (`std::__open_terminal`,
    `std::__write_to_terminal`) without `-lstdc++exp`. Adding that link flag is a toolchain change
    for Jon. Only three sites exist: `legacy_random.cpp:134` (could use `std::print`), and
    `OOLogOutputHandler.cpp:163,165`, which must stay `fputs`: `oo::log::consoleBytes` has already
    converted the line to the console's encoding, and `std::print` would treat it as UTF-8 and
    convert it again on a Windows console.

### Warnings and tooling (§2.6, B11)

- **I21. Warnings.** Partly done (worker, 2026-11-15): `-Wunused` and `-Wsign-compare` are on (oolite-dev f3ef09dd4; 0 warnings). Measured over every `src/` translation unit with `-fsyntax-only`: `-Wextra` adds 297 (259 `-Wunused-parameter`, 38 missing field initialisers), and `-Wpedantic` adds 267 (261 GNU statement expressions from `OOJSSTR`/`OOJSID`, so I6 comes first; 4 zero-argument variadic macros; 2 C99 extensions in `OOBreakPatternEntity.cpp`). The game builds with `-Wall` only (Meson's warning level 1), not `-Wall -Wextra`.
  - Worker, 2026-11-15, second pass: `-Wimplicit-fallthrough` (69c709c36), `-Wsuggest-destructor-override`
    (ffe6978ee), `-Wshadow` (e1dc69d27) and `-Wunused-parameter` (cf8367dbe) are on; dev and debug build
    warning-free. Natives that ignore `this` or `argc` spell out `OOJS_NATIVE_ARGS` with the names
    commented out, since `[[maybe_unused]]` counts as silencing under rule 2.
  - Left: `-Wextra`'s other half, 38 `-Wmissing-(designated-)field-initializers`: 36 are QuickJS
    `JSClassDef`/`JSClassExoticMethods` tables that name only the fields they set. Fixing means
    writing every other field as `nullptr` in each table, which would churn whenever QuickJS-ng
    adds a field. Default taken: not done; Jon to decide whether that noise is worth `-Wextra`.
  - Left: `-Wundef` (49): the feature switches (`OO_FOV_INFLIGHT_CONTROL_ENABLED`,
    `OOJS_POC_HARNESS`, `DEBUG`, `OO_DEBUG`, `INSTRUMENT_TEXTURE_LOADING`, …) are defined only in some
    build types, and `OOLITE_LINUX`/`OO_DEBUG` are tested before `OOFoundation.h` defines them. Each
    needs a default in one header that everything includes first: the platform-layer plan's
    `config.hpp` (Prepare). Default taken: wait for that plan.
  - Enable `-Wextra`, `-Wpedantic`, `-Wunused` and `-Wsign-compare` in `src/meson.build` (the review
    measured 0 hits).
  - Then fix and enable `-Wundef` (54 in the review), `-Wsuggest-destructor-override` (10),
    `-Wshadow` (22) and `-Wimplicit-fallthrough` (13), one flag per commit.
  - `-Wpedantic` will flag GNU extensions such as compound literals `(Vector){…}`. The
    `readability/braces` task removes those, so do that task first.
  - Done: each flag is in `src/meson.build` and `./mk.sh build dev` is warning-free.
- **I22. Sanitizer build.** Add an `asan` build type to `mk.sh` (`-Db_sanitize=address,undefined`,
  no LTO) and a suppressions file under `tests/` for the known third-party report (see
  `tests/component/console.py:133`).
  - Done: `./mk.sh build asan` builds and `BUILD_TYPE=asan tests/run.sh unit` runs. Report failures
    rather than suppressing game findings.
- **I23. Close-out.** Move the clang-tidy checks that are now clean into `WarningsAsErrors`.
  - Done: `.clang-tidy` lists them, and CI's clang-tidy job passes.

## Test-change ledger

Std-equivalent edits only (rule 1, third exception). Fill in the commit for each.

| File | Edit | Assertion meaning |
|---|---|---|
| `tests/unit/core/test_DockEntity.cpp:186`, `test_MyOpenGLView.cpp:195,199`, `test_OOFlasherEntity.cpp:213`, `test_OOJSVector.cpp:348`, `test_OOMathsHeaders.cpp:38`, `test_ShipEntity.cpp:1476,1784,1789`, `test_WormholeEntity.cpp:208,329` | `M_PI`/`M_PI_2` → `std::numbers::pi` (`/ 2`) | same (oolite-dev 5ceffa8d4; also `test_ShipEntity.cpp:1476`'s `M_PI / 2.0` inside a cast, and `test_WormholeEntity`'s two) |
| `tests/unit/core/test_OOMathsHeaders.cpp:37` | `OOClamp_0_1_f(2.0f)` → `std::clamp(2.0f, 0.0f, 1.0f)` | same |

## Decisions (defaults taken)

- **NaN in clamps (I2).** Jon asked for `std::clamp`, so the clamps convert, and a NaN now passes
  through instead of clamping to the upper bound. A NaN reaching these clamps is already a bug
  upstream.
- **`rand()` seeding (I3).** Upstream calls `rand()` without seeding (no `srand` anywhere), so the
  comms chatter seed follows the C runtime's fixed sequence, which differs between C libraries. The
  replacement seeds from `std::random_device`, which is what the name `very_random_seed` means. No
  saved or tested value depends on it.
- **`NSPoint`/`NSSize`/`NSRect` keep their names.** The review suggested project `Point`/`Size`/
  `Rect` structs, but they are already the project's own structs (`oofnd/objc/OOFoundationTypes.h`),
  and renaming 512 uses would make every upstream merge conflict. Spec 009 and the `oofnd` README
  keep them.
- **No Spec Kit spec.** Each workstream is one `0_AI_Tasks` item. Promote one to `specs/` if it
  turns out to need design. I6, I11 and I16 are the likeliest.

## Worker notes

- Branch: the workstreams are committed on `seriesb/032-cleanup`, not a `git town append` branch per
  workstream. Another session had uncommitted edits in the same `oolite-dev` checkout, and
  switching branches would carry them along. Default taken; split the branch later if wanted.
