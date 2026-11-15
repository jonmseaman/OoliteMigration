# Instructions for Task Executor:

You are a task worker responsible for completing all the tasks in this file in the "Tasks" section or lower. You should not complete tasks in the "Prepare" section as those are not ready.

When you are done with each task or commit, make sure `./mk.sh build dev` pass and the unit tests.
Then, check the task off when you are ready and commit your oolite-dev changes.
Move a checked-off task (with its sub-bullets) to the "Done" section at the bottom of this file.

I will sometimes add tasks to this file, so don't be surprised if there are new tasks.
Plans in the "Prepare" section aren't ready for work, but plans in the "Tasks" sections are.

# Instructions for Task Planner:

You turn Jon's requests into tasks in this file. You do not change code in `oolite-dev`.

- **Adding a task:** if Jon tells you to add a task, add it under "Tasks" straight away, so it
  survives if the agent dies. Look at the code first, so the task can name the files, the
  `file:line` and the size (for example "326 uses in 34 files").
- **Planning:** if Jon tells you to plan, write the plan in `notes/plans/<short-name>.md` and link
  it from a one-line task. A new plan goes under "Prepare". Move it to "Tasks" only when Jon says it
  is ready.
- **Every task and plan needs a done check:** a command, run from `oolite-dev`, that exits nonzero
  before the work and zero after. It usually comes on top of `./mk.sh build dev` and
  `tests/run.sh unit`. If you can't write one, say so in the task.
- **Look at the code, not just the request.** Work out who uses the thing, what upstream
  (`upstream/oolite`) does, and which tests pin the behaviour. A task should state what is dead,
  frozen or duplicated, with evidence. Don't guess.
- **Tests:** if the work would edit a test, check the hard rules in `CLAUDE.md`. Where no
  exception covers the edit, say so and ask Jon to sign off. Once he has, record the date in the
  task and add a test-change ledger to the plan: file, edit, and whether each assertion's meaning
  is kept.
- **Defaults:** take the conservative option, so behaviour stays the same and the tests pass
  unedited. Record it under "Decisions" in the plan, with the reason.
- **Order:** if two tasks touch the same lines, put the dependency in the later task ("do X first").
- **Naming new code:** new types, functions and files go in the `oo` namespace with no `OO` prefix
  (`oo::SpeechSynthesizer` in `SpeechSynthesizer.h`, not `OOSpeechSynthesizer`). Existing `OO`
  names stay unless a task renames them.
- **What a plan contains:**
  - why the work is needed;
  - the done check;
  - the design: each consumer and what changes there;
  - the steps;
  - the test-change ledger, if there is one;
  - the decisions taken and their defaults;
  - what is out of scope, with a follow-up if it's worth doing.

  Keep it to what the executor needs, and don't add history.
- **Commits:** commit nothing in `oolite-dev`. Edits to `notes/` stay uncommitted unless Jon asks.

# Prepare
- [ ] Replace the three hand-kept by-name tables (`OOEntityCalledByNameTable.h`, `OOJSCallEntityMethods.h`, `OOEntityObjectNamesTable.h`, about 4,850 lines) with one table of `oo::Call<&Class::member>("name")` rows that work out their types from the member pointer. Two test edits signed off 2026-11-15. [plan](plans/by-name-table.md)
- [ ] Platform layer in `src/platform/` (outside `oofnd`, which is being retired): `Platform.hpp`, per-OS `*_win32.cpp`/`*_posix.cpp` chosen by Meson, in-body `#if`s out of `oofnd` and Core/SDL, `OOLITE_SDL`, `std::endian`, feature switches via `config.hpp`, and a CI guard. [plan](plans/platform-layer.md)

# Tasks
- [x] (oolite-dev 40c688712) Encapsulate espeak-ng in an `oo::SpeechSynthesizer` class (`src/Core/SpeechSynthesizer.{h,cpp}`): espeak's API and `<espeak-ng/speak_lib.h>` leave `Universe.h`, `MyOpenGLView.cpp` and `PlayerEntityControls.cpp`, and `Universe` keeps its speech methods as forwarders. One test edit (`slice24Voices`), signed off 2026-11-15. [plan](plans/speech-synthesizer-class.md)

- [ ] Modern C++ idioms: what's left of the 2026-10-28 idiom review and its epics outline. 23 workstreams: `M_PI`→`std::numbers`, `OOClamp`/`OOLerp`→`std::clamp`/`lerp`, `rand()`→`<random>`, constant `#define`s, `EXPECT`→`[[likely]]`, `OOJSSTR`, `source_location`, memory, strings, out-parameters, warnings, asan … [plan](plans/modern-cpp-idioms.md)
  - Status (worker, 2026-11-15; details per workstream in the plan): done: I1, I3, I5, I6, I9, I13, I14, I17, I18 (`-Wconversion`, `-Wimplicit-float-conversion`, `-Wsign-conversion` on, dev and debug warning-free), the I8 do/while review. Mostly done: I4 (all constant, alias and expression defines and three const externs converted; left: `#if` switches, concatenated literals, `kZeroMatrix`, and the files another session has checked out), I21 (8 flags added; `-Wundef` and `-Wextra`'s field initialisers left, see below), I23 (7 more clang-tidy checks are errors). Partly done: I2 (`std::lerp`, `OOClampInteger`; the float `OOClamp_*` stay because `test_OOJSEntity` pins NaN → upper bound), I10, I12 (memcpy part, 18 index-only arrays; the GL colour arrays left), I15 (one family; 161 lines audited), I19 (fopen, locks, `oo::LogIndentScope`). Blocked, with reasons: I7 (`oofnd` macros, log text), I11 (OOCache checked out by another session; `OOPriorityQueue` removal deletes a test), I20 (`std::print` needs `-lstdc++exp`), I22 (no sanitizer runtime on this box), `-Wundef` (needs the platform-layer `config.hpp`), I16 for the signatures tests call (no test-edit exception), I19 index loops (101, each needs a mutation review). Partly done: I16 (six test-free families return values; the JS entity getter and the schema verifier stay). Not started: `std::span` parameters.

- [x] (oolite-dev 5ae4cb9e0) Delete `src/Core/OOTypeEncodings.h`; carry return types as a compile-time `oo::ValueType` enum (test edits signed off 2026-11-15): [plan](plans/retire-type-encodings.md)
- [x] Resolve Possibly unused #include directive for all obviously unused includes. If there is platform specific code in the file, please make sure it is not used on any platform. (oolite-dev dada1cea0: 1,324 standard includes from 112 headers; 7da885e84: 22 project includes from 17 headers)
  - How: `clang-include-cleaner` on each header as its own main file (clang-tidy's `misc-include-cleaner`, already an error, only checks .cpp files, and reports nothing there). A standard include went only if none of its names appears anywhere in the file, inactive `#if` branches included (61 kept for that). A project include went only if the header needs no include added, isn't an umbrella (`OOEntityEnums.h`, `OOLogging.h`), and still defines every macro some `#if` in src/ or tests/ tests.
  - Left alone on purpose: ~250 project includes in ~140 headers that include-cleaner calls unused but that dependents rely on transitively (it wants an umbrella swapped for the specific header) or that carry `#if` macros (`OOFoundation.h` is most of them). Clearing those means adding direct includes to the dependents first, which is the cpplint `build/include_what_you_use` task's job. `OOAssert.h` keeps `OOException.h` because `tests/unit/oofnd/test_objc_assert.cpp` gets `oo::` through it.
  - Not touched: the 13 files with another session's uncommitted edits (`OOCache.*`, `OOCommodityMarket.h`, `OOConstToString.h`, `OOCrosshairs.h`, `OOEncodingConverter.h`, `OOGraphicsResetManager.h`, `OOProbabilitySet.h`, `OORoleSet.h`, `OOShipLibraryDescriptions.h`, `OOStringWidth.h`, `OOTypeEncodings.h`, `oofnd/objc/OOObject.h`); those edits are this same kind of removal.
- [x] Complete the cpplint tasks below. (all four done; see each task)
- [ ] New `seriesb` branch: drop the `OO` prefix from names in `src/` except `src/Core/Scripting/` (`OOColor` → `oo::Color`, files too). Not yet: Jon wants it eventually. Tests are renamed with the source (signed off 2026-11-15). [plan](plans/drop-oo-prefix.md) (Do the cpplint tasks before this one. also do the Modern C++ idioms task first. This should be a final task since it goes onto a new branch.)
- [x] (oolite-dev 2ed726560; `<math.h>` went too: only 2 files needed `<cmath>`) Clean up `src/Core/OOFoundation.h` (163 lines, 22 `#define`s, included by 134 files). Remove what is dead or duplicated; leave the OS and speech macros to the platform-layer and espeak plans.
  - Delete `OOLITE_GCC_VERSION` (0 uses) and `NS_BLOCK_ASSERTIONS` (only named in comments: `HeadUpDisplay.cpp:835`, `oofnd/objc/OOAssert.h:9`; update both comments).
  - Replace `OOLITE_HAVE_CLANG` with `__clang__` at its 3 uses (`OOCPUInfo.cpp:35,41`, `SDL/main.cpp:289`) and delete it.
  - `OOLITE_64_BIT` (uses at `OOFastArithmetic.h:61`, `OOMesh.cpp:117`): every target is 64-bit. Keep the 64-bit branch, delete the other, add `static_assert(sizeof(void*) == 8)` in `OOFoundation.h`, and delete the macro.
  - `OOLITE_DEBUG` (`!NDEBUG`, 13 uses) and `OO_DEBUG` (Meson's debug builds, 28 uses) mean different things. Keep both, and give each a one-line comment saying which builds set it. Don't merge them.
  - Move `<math.h>` and `<stdbool.h>` out: C++ needs no `<stdbool.h>`. Replace `<math.h>` with `<cmath>` in the files that use maths functions, rather than exporting it to all 134 includers. If that turns out to be wide, stop after `<stdbool.h>` and record the count.
  - Done when `! git grep -qwE 'OOLITE_GCC_VERSION|NS_BLOCK_ASSERTIONS|OOLITE_HAVE_CLANG|OOLITE_64_BIT' -- src` and `! grep -q 'stdbool.h' src/Core/OOFoundation.h`, with `./mk.sh build dev` and `tests/run.sh unit` passing.
- [x] (oolite-dev 071035ed4; kept the line everywhere outside Core/Scripting except `DockEntity::initDockDefaults`, since telling which functions JS reaches was not certain; the debug build needed two includes in `OOJSConsole.cpp`) Profiling macros (`OOJS_PROFILE_ENTER`/`OOJS_PROFILE_EXIT`/`OOJS_PROFILE_EXIT_VOID`, `Scripting/OOJSEngineNativeWrappers.h:120-179`). They feed the debug console's `profile()`/`getProfile()`/`trace()` and are empty outside `OOLITE_DEBUG` builds. There are 168 pairs, 36 of them outside `Core/Scripting/` (`Universe.cpp` 12, `OOMesh.cpp` 11, `ShipEntity.cpp` 5 …).
  - Replace each brace pair with one RAII line, `OOJS_PROFILE_SCOPE();`: a macro that declares an `OOJSProfileScope` named after `__FUNCTION__` when `OOJS_PROFILE` is on, and nothing otherwise. Delete `OOJS_PROFILE_ENTER_NAMED`, `OOJS_PROFILE_EXIT` and `OOJS_PROFILE_EXIT_VOID`.
  - Outside `Core/Scripting/`, drop the line from any function that JavaScript never calls (for example `DockEntity::initDockDefaults`). Keep it where a JS native calls the function, so the console profile stays the same. If you can't tell, keep it.
  - `OOJS_NATIVE_ENTER`/`OOJS_NATIVE_EXIT` (286 uses) stay: they turn C++ exceptions into JS errors.
  - Done when `! git grep -qE 'OOJS_PROFILE_(ENTER|EXIT)' -- src`, `./mk.sh build dev` and `tests/run.sh unit` pass, and a debug build (`./mk.sh build debug`, which defines `OOLITE_DEBUG`) also compiles.
## cpplint tasks
cpplint 2.0.2 is installed at `.agent-tmp/cpplint-venv` (repo root); results are in `notes/cpplint/2026-11-15-summary.md`. To check one category, run from `oolite-dev`:
`L() { ../.agent-tmp/cpplint-venv/Scripts/cpplint.exe --recursive --quiet --filter=-,+$1 src 2>&1 | grep -F "[$1]" | grep -vE 'OOEntityCalledByNameTable\.h|OOJSCallEntityMethods\.h|OOTypeEncodings\.h'; }`.
The three excluded headers are hand-laid tables (`clang-format off`) or are being deleted. Don't use `NOLINT` to clear a finding. If one is a false positive, list it under the task with the reason, and the done check allows exactly those. Run clang-format 22 on every file you touch.

- [x] (oolite-dev 7af15de0f) cpplint `whitespace/braces`: about 670 × "`{` should almost always be at the end of the previous line" outside the tables (worst: `ShipEntity.cpp` 97, `PlayerEntityLegacyScriptEngine.cpp` 91, `PlayerEntityControls.cpp` 62, `PlayerEntity.cpp` 61, `Universe.cpp` 52, `ShipEntityAI.cpp` 52). The usual cause is a trailing `//` comment on the `if`/function line, which stops clang-format moving the `{` up:
  `if (virtual_dock)  // can't be damaged` then `{` on the next line (`DockEntity.cpp:280`). Fix: move the comment onto its own line above the statement, or inside the block, without changing its text. Then let clang-format join the `{`. Do this before the `readability/braces` task, because it also clears some of that task's false positives. Done when `L whitespace/braces` prints nothing (apart from listed false positives) and `./mk.sh build dev` and `tests/run.sh unit` pass.
  - False positives (2): `OOJSEngineNativeWrappers.h:132` and `:184`, the second `{` of `OOJS_PROFILE_ENTER_NAMED` and `OOJS_BEGIN_FULL_NATIVE`. Each opens a nested scope after the scope object's declaration on purpose; there is no statement for it to attach to.
  - Each moved comment is now the first line inside its block. Two long ones (`ShipEntity.cpp`, the 2013-01-13 note; `MyOpenGLView.cpp`, "Occurs on some systems") were re-wrapped by clang-format at 80 columns: same words, different line break.
- [x] (oolite-dev 27222e717) cpplint `build/include_what_you_use`: 536 missing standard includes, mostly `<string>` (166), `<memory>` (161) and `<vector>` (71), spread thinly across files (at most 7 per file). Add the `#include` each finding names, in the file it names, in the right include group. Skip any finding where the name is not the std one (e.g. a member or `oo::` function called `min`, `swap` or `move`), and list it as a false positive. Done when `L build/include_what_you_use` prints only listed false positives and the build and unit tests pass.
  - False positive (1): `OOTCPStreamDecoder.cpp:233`, where `string` is a local `OOALStringRef`, not `std::string` (clang-tidy's include-cleaner calls `<string>` unused there, which is an error).
- [x] (oolite-dev 855de3670, 5d3c510eb) cpplint `readability/braces` (347 outside the tables). Do it after the `whitespace/braces` task.
  - 275 × "If an else has a brace on one side, it should have it on both": `if (x) a; else { … }` → `if (x) { a; } else { … }`. Worst: `PlayerEntityControls.cpp` 63, `PlayerEntity.cpp` 33, `ShipEntity.cpp` 28, `Universe.cpp` 21.
  - 85 × "If/else bodies with multiple statements require braces". Some are the comment-before-`{` case and clear with the `whitespace/braces` task. Add braces to the rest.
  - 23 × "You don't need a ; after a }": C99 compound literals such as `return (Vector){c.x, …};` (`OOPlanetEntity.cpp:409`), which C++ accepts only as a GNU extension. Write `Vector{…}`. Also convert any other `(Type){…}` compound literal in src/ that `git grep -nE '\((Vector|HPVector|Quaternion|NSPoint|NSRect|NSSize|OO\w+)\)\{' -- src` finds.
  - 1 × "Ambiguous nested if/else" at `ResourceManager.cpp:1736`. Add braces so the `else` binds to the `if` the indentation shows. If the indentation and the parse disagree, keep the current parse (the behaviour) and record that under this task.
  - Done when `L readability/braces` prints only listed false positives, the compound-literal grep finds nothing, and the build and unit tests pass.
  - False positives (30 lines, all left as they are):
    - An `else` split from its `}` by `#if`/`#else`/`#endif`, braced on both sides: `DustEntity.cpp:322,343,391`, `OOPlanetEntity.cpp:317,881`, `PlayerEntity.cpp:9427`, `PlayerEntityControls.cpp:937,2220,2224,4160`, `ShipEntity.cpp:648,656`, `GameController.cpp:499`, `OOConcreteTexture.cpp:290,306,479,486`, `OOOpenGLExtensionManager.cpp:339`, `OOJSShip.cpp:1983,1991`, `MyOpenGLView.cpp:666`. Some lines get both messages.
    - The `PACKET_CASE` macro's else-if chain: `OODebugTCPConsoleClient.cpp:771,785`.
    - A braced `else if constexpr` whose condition spans two lines: `OOEntityCalledByName.cpp:132`.
  - `ResourceManager.cpp:1736`: the `if` and the parse agreed (the `else if` chain is inside the `for`); bracing the `if` kept that parse.
  - Compound literals: besides the grep's 24, `(NSRange)`, `(FloatRGB)`, `(FloatRGBA)`, `(BoundingBox)`, `(Triangle)` and `(RNG_Seed)` were converted too.
- [x] (oolite-dev 63eb2d769) cpplint `runtime/int`: replace every `long long`, `long` and `short` with a fixed-width type (Jon, 2026-11-15: all of them, not only where the width matters). There are 354 findings: 216 `long long`, 100 plain `long`/`unsigned long`, 38 `short`/`unsigned short`. Each finding with its source line is in `notes/cpplint/2026-11-15-runtime-int.txt`. The reason is portability: `long` is 32 bits on Windows and 64 on Linux/macOS, the next targets. Check `specs/009-modern-cpp-std` first, and don't redo anything it owns.
  - **Plain `long` (100; worst: `PlayerEntity.cpp` 14, `oofnd/PList.hpp` 7, `Universe.cpp` 6):**
    - A cast to `long` on the way into a 64-bit API is a needless 32-bit step on Windows. For example, `oo::PList::signedInteger(static_cast<long>(missiles))` (`PlayerEntity.cpp:1317`; `signedInteger` takes `std::int64_t`) becomes `static_cast<std::int64_t>(…)`, or no cast where the conversion is implicit and warning-free. Same for `unsignedInteger` and `std::uint64_t`.
    - A cast to `unsigned long` only to feed a `{}` format argument (e.g. `OOJSConsole.cpp:1131`, `OOTCPStreamDecoder.cpp:170`): drop the cast if `oo::str::format` takes the type, else use `std::size_t`/`std::uint64_t`.
    - Anything else: use the fixed-width type for the value's real range.
  - **`long long` (216; worst: `Universe.cpp` 26, `oofnd/PListGet.hpp` 17, `oofnd/String.hpp` 16, `OOPListSchemaVerifier.cpp` 12):** `long long` becomes `std::int64_t` and `unsigned long long` becomes `std::uint64_t`. API names such as `longLongValue` can keep their names; only the types change.
    - Watch the by-name, `callObjC` and shader-binding tables. They pick a result's handling by its exact type (today via `kOOTypeEncoding<T>`, later via `oo::ValueType`; see the `OOTypeEncodings.h` task). On Linux/macOS `std::uint64_t` is `unsigned long`, so a typedef such as `OOCreditsQuantity` changing from `unsigned long long` to `std::uint64_t` would move its rows from "not a uniform type" to UnsignedLong there. Keep those rows' handling the same, and say how in the commit.
  - **`short` (38; `DockEntity.cpp` 14):** use the game's named type where the value is one. For example, `std::map<unsigned short, …>` of ship IDs in `DockEntity.cpp:49-51,310,344,403` becomes `OOUniversalID` (`uint16_t`, `OOTypes.h:253`), and a system number becomes `OOSystemID`. Otherwise use `std::uint16_t`/`std::int16_t`; for example, the TCP `consolePort` in `OODebugSupport.cpp:41,66` becomes `std::uint16_t`.
  - **Leave alone, because changing them would break the build or the behaviour; these are expected findings:**
    - Overload sets that must name every fundamental type (`FormatArg(long)`/`(long long)`/`(unsigned long)` in `oofnd/String.hpp:1012-1015`). `std::int64_t` is `long` on Linux and `long long` on Windows, so a rewrite would duplicate one overload and lose the other.
    - C struct fields and C APIs typed `long` (`timeval::tv_sec`/`tv_usec` in `OODebugTCPConsoleClient.cpp:989-990`): use `decltype(limit.tv_sec)` to drop the word.
    - `signed long`/`unsigned long` in `Materials/OOShaderUniformMethodType.*` (they name the uniform types Long and UnsignedLong).
    - The `long`-width number parsing that spec 009 FR-028 keeps on purpose.
    - Anything in `OOTypeEncodings.h` (being deleted).
  - Don't change a value's width where it is saved, sent over the debug protocol or exposed to JS, unless the old and new type hold the same range on Windows. If they don't, record the site under this task and leave it.
  - Done when every line `L runtime/int` reports is one of the leave-alone cases (list any new one under this task, with its reason), and `./mk.sh build dev` (no new warnings) and `tests/run.sh unit` pass. To list what's left, run from `oolite-dev`: `L runtime/int | tr '\134' '/' | sed -E 's/:([0-9]+):.*/ \1/' | while read -r f n; do printf '%s:%s: ' "$f" "$n"; sed -n "${n}p" "$f"; done`.
  - Left (27 lines), each a leave-alone case:
    - `ValueType.h:103-117` (6): `oo::ValueTypeOf` must name every fundamental type, like the `FormatArg` overloads.
    - `String.hpp:1013-1017` (4, `FormatArg`) and `:1366,1383` (the printf engine's `%h` casts to `short`/`unsigned short`).
    - `Http.hpp:495,498`: curl's options take a `long`.
    - The Windows API declarations: `Process.hpp:51,53,57`, `ResourcePaths.hpp:85,87`, `Thread.hpp:41,44`.
    - `PListGet.hpp:161`: the `long`-width parse spec 009 FR-028 keeps.
    - New: `OOALSoundDecoder.{h,cpp}` `sampleRate()` (4 lines) stays `long`. `tests/unit/core/test_OOSound.cpp:108` and `test_OOMusic.cpp:70` define `OOALSoundDecoder::sampleRate()` with that return type, and those tests aren't in a ledger. Its two `framesRead` locals are `std::int64_t`.
  - Saved values: the `static_cast<long>` casts into `oo::PList::signedInteger` in `PlayerEntity::commanderDataDictionary` are `std::int64_t` now, as the task's example says. The values are 32-bit or narrower ints, so none of them changes on Windows. The PList integer is 64-bit either way.
  - Printf-style range errors (`HeadUpDisplay`, `OOStringExpander`, `ResourceManager`, `Universe`) used `%lu`; they use `%zu` with `std::size_t` now, so the text is the same.
# Done
- [x] Delete the PyAutoGUI GUI tier, oolite-dev/tests/gui (Jon asked 2026-11-15): [plan](plans/remove-gui-tests.md) (oolite-dev c2be52677; outer docs edited, left uncommitted as the plan says)
- [x] Fix all clang tidy redundant conversion notifications in the oolite-dev/src directory (oolite-dev 73d99d167)
- [x] Rename GameController+SDLFullScreen.cpp to GameController.cpp (oolite-dev 796b9556d)
- [x] GameController.cpp should be alongside it's header too. I'm not sure why it's in the SDL folder. (oolite-dev 1ad3e3e3e: merged into src/Core/GameController.cpp, under OOLITE_SDL)
- [x] Clang-Tidy: Use 'using' instead of 'typedef' Fix all of these in the src/ directory. (oolite-dev 603decc60; check now an error)
- [x] Fix all of these Redundant 'inline' specifier on a global static function in the src/directory (oolite-dev 86b9c9e72; check now an error, StrictMode)
- [x] Replace the `OOINLINE` macro (`src/Core/OOFunctionAttributes.h:24`, `#define OOINLINE inline`) with plain `inline` at every use (326 uses in 34 files, all under src/; tests/ has none), then delete the `#define`. Do the 'Redundant inline' task above first, or drop `inline` where clang-tidy calls it redundant. Done when `git grep -q OOINLINE -- src tests` exits nonzero. (oolite-dev 236b7430c)
- [x] Remove the `OOLITE_OPENAL` macro. It is always 1 (`src/Core/OOSound.h:48`, unconditional `#define`; nothing else sets it). In `OOSound.h` and `OOSoundInternal.h`, unwrap the `#if OOLITE_OPENAL` blocks and delete the dead `#else #warning …` branches. In `src/Core/OOLogHeader.cpp:101`, keep `"OpenAL"` in the feature list without the `#if`. Done when `git grep -q OOLITE_OPENAL -- src tests` exits nonzero. (oolite-dev f5257e466)
- [x] (oolite-dev 357b8e112; OOSoundInternal.h deleted too, it held only the macros) Delete the no-op `OOSoundAcquireLock()`/`OOSoundReleaseLock()` macros (`src/Core/OOSoundInternal.h:8-13`) and their 7 call sites in `src/Core/OOSoundSource.cpp` (`play` :126/:150, `stop` :161/:179, the channel-finished delegate :268/:280/:283). Each expands to `do { } while (0)`, an empty statement that runs once and exits, so they lock nothing and never block. They are left over from upstream's CoreAudio backend, whose audio thread needed a lock; upstream's OpenAL build has the same empty bodies. With OpenAL, everything that reaches `OOSoundSource` runs on the game thread: `GameController.cpp:402` → `OOSound::update()` → `OOSoundMixer::update()` → `OOSoundChannel::update()` → the delegate. So no `std::mutex` replaces them. Don't add one: there's no second thread to guard against. In the delegate, the early `OOSoundReleaseLock(); return;` becomes a plain `return;`. Done when `git grep -q 'OOSound\(Acquire\|Release\)Lock' -- src tests` exits nonzero, and `./mk.sh build dev` and `tests/run.sh unit` pass.
- [x] Resolve all the redundant static_cast tidies in the src/ directory. (oolite-dev df5869f9d)
  - Kept, as a false positive: `static_cast<int>(recv(...))` in `OODebugTCPConsoleClient.cpp` (`receive`). It is redundant only on Windows, where `recv` returns `int`; POSIX `recv` returns `ssize_t`. So `readability-redundant-casting` is not made an error.
- [x] (oolite-dev 3c4ea3b73) Declare structs, unions and enums directly instead of aliasing them with `using` (what clang-tidy's typedef→using fix left behind: 59 lines in src/, 22 of them anonymous). Do the 'using instead of typedef' task first, since these lines come from it.
  - `using X = struct X { … };` → `struct X { … };`
  - `using X = struct { … };` (anonymous, e.g. `ChainedEntityPredicateParameter`, `BinaryOperationPredicateParameter` in `OOEntityFilterPredicate.h`) → `struct X { … };`. Same for `union`/`enum`.
  - `using X = struct X;` (forward declaration, e.g. `AI.cpp:388`) → `struct X;`
  - `using XRef = struct X*;` (e.g. `OOTCPStreamDecoder.h:35`, `OOTCPStreamDecoderAbstractionLayer.h:22-25`) → `struct X;` once, then `using XRef = X*;`
  - Leave plain type aliases alone (`using OOMeshSmoothGroup = uint16_t;` and the like). Those are what `using` is for.
  - Done when `git grep -qE 'using \w+ = (const )?(struct|union|enum)\b' -- src` exits nonzero.
- [x] (oolite-dev 1259040ad) In `static_assert`s that pin an enumerator's value, replace `static_cast<T>(E::kX)` with C++23's `std::to_underlying(E::kX)` and add `#include <utility>`. Example: `static_assert(std::to_underlying(OOGUIAlignment::kRight) == 1);`. There are 79 single-line sites in 11 files under src/, plus some static_asserts that clang-format wrapped (19 `static_assert(` lines end the line; check each). tests/ has none.
  - Only where the operand is a scoped-enum enumerator. Leave casts of plain constants alone (e.g. `static_cast<int>(kOOShaderUniformTypeColor)`).
  - Where `T` is not the enum's underlying type (e.g. `static_cast<std::ptrdiff_t>(OOComparisonResult::…)` in `OOFoundation.h:151-155`), `to_underlying` changes the compared type. That's fine as long as it builds without a new `-Wsign-compare` warning; if one appears, keep that cast.
  - Done when `git grep -qE 'static_assert\(static_cast<[^>]+>\([A-Za-z_][A-Za-z0-9_:]*::k\w+\)' -- src` exits nonzero, the wrapped ones are converted too, and `./mk.sh build dev` has no new warnings.
  - Complete the cpplint tasks below
- [x] (oolite-dev af2290a03) `mk.sh`: keep the root `compile_commands.json` current after every build step, not only after `setup`. Today `meson_setup` (`mk.sh:91-95`) copies `build/meson_<type>/compile_commands.json` to the root, so `./mk.sh build dev` already refreshes it, since `build` runs `setup` (a `--reconfigure`) before `compile`. Two gaps remain:
  - `./mk.sh compile <type>` and `./mk.sh configure <type>` never copy, yet Meson rewrites the build directory's database whenever a `meson.build` change triggers a reconfigure inside `meson compile`. Fix: move the copy into a `copy_compile_commands "<build_dir>"` helper and call it at the end of `meson_setup`, `meson_compile` and `meson_configure`.
  - The clang-tidy target's fallback (`mk.sh:459-461`) runs `./mk.sh build test` when there's no database. That breaks the build-dev rule (`.claude/rules/build-dev.md`): `test` turns on LTO. Make it `./mk.sh build dev`.
  - Done when, from `oolite-dev`, `touch meson.build && ./mk.sh compile dev && test compile_commands.json -nt meson.build && cmp -s compile_commands.json build/meson_dev/compile_commands.json` exits 0 (it exits nonzero today), and `grep -q 'mk.sh" build dev' mk.sh` exits 0.
- [x] (oolite-dev 7d7f09873, 3c4a488f6) Blank line between function definitions. Add `SeparateDefinitionBlocks: Always` to `oolite-dev/.clang-format`, then reformat **all of `src/`** once with clang-format 22. That breaks the usual "only files you changed" rule; Jon OK'd it on 2026-11-15 because CI's `clang-format-check` would otherwise fail on every untouched file. Never format `tests/`.
  - Do it as its own commit with no other change, so it's easy to review and to add to `.git-blame-ignore-revs` (create that file with the commit id).
  - Leave the `// clang-format off` tables alone; clang-format already skips them.
  - Done when `clang-format --dry-run --Werror` over `src/**/*.{cpp,h,hpp}` (excluding `third_party/`) exits 0 with the new option, and `./mk.sh build dev` and `tests/run.sh unit` pass. Before the change, the same command exits nonzero on files such as the review's `int func1() {}` / `int func2() {}` example.
  - Done (worker, 2026-11-15) with clang-format 22.1.8 from PyPI in `.agent-tmp/cf22-venv` (the MSYS toolchain has only 23): oolite-dev 7d7f09873 is the formatting-only commit, 3c4a488f6 adds `.git-blame-ignore-revs` with it. It also fixed ~30 files whose earlier formatting had been done with 23.
  - The done check passes for every file except the 30 headers clang-format guesses are Objective-C, because they name `NSPoint`/`NSSize`/`NSRect` (`PlayerEntity.h`, `Universe.h`, `HeadUpDisplay.h`, `GuiDisplayGen.h`, `MyOpenGLView.h`, `OOJoystickProfile.h` …). By name, clang-format refuses them with "Configuration file(s) do(es) not support Objective-C", with or without the new option, and so does CI's `clang-format-check`. They were formatted as C++ (through stdin with `--assume-filename=<name>.hpp`). An ObjC section in `.clang-format` would format them very differently (422 changed lines in `PlayerEntity.h` alone), so it wasn't added. The real fix is renaming those types (the platform-layer or OO-prefix work).
