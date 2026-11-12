# Use C++23 and the standard library directly

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 27 of 28, stacked on upstream #768's branch, so not independent of #767 and #768.

## What this changes

The game, oofnd and `tools/icosmesh` build as C++23. Code written in C or Objective-C idioms, or
against an oofnd stand-in, uses the standard library instead:

- `malloc`'d buffers in the streamed sound, the OXZ reader and the snapshots become `std::vector`;
- the async work manager owns its threads as `std::jthread` and joins them at quit;
  `oo::thread::detach` goes;
- `oo::Expected` becomes `std::expected` (`oofnd/Expected.hpp` is deleted), game code includes the
  standard headers it uses instead of `oofnd/StdLib.hpp`, Foundation's integer aliases become the
  standard types, and `oo::Exception` is a `std::exception`;
- literal `oo::str::format` calls become `std::format`;
- every unscoped enum and list of constant macros becomes an `enum class` or a typed constant, and
  ten of the eleven `.tbl` tables become headers;
- C-style casts become named casts, and read-only C strings in the entities, scripting, materials,
  SDL and debug code become `std::string_view`.

`./mk.sh tidy` runs `.clang-tidy`, and CI runs it. `cppcoreguidelines-use-enum-class` and
`google-readability-casting` are errors, and the game builds with `-Wold-style-cast`.

## Why

The game is C++, but much of it still read as C and Objective-C. With the standard types a C++
reader meets what they already know, and the compiler and clang-tidy catch mistakes the old forms
hide, such as the OXZ leak below.

## Behaviour changes

- Reading a Vorbis file inside an OXZ no longer leaks a copy of every read (`OOReadOXZVorbis`). Not
  pinned by a test.
- The work threads are joined at quit, before the preferences are written and the log is closed,
  where they were detached. Pinned by `test_OOAsyncWorkManagerShutdown`.
- Otherwise none. Tests added before the changes pin what must stay the same:
  `test_SaveEnumValues` (the numbers saved games and by-name calls hold), `test_EnumNameFallbacks`
  (every enum's names) and `test_FormatEquivalence` (each printf format against its `std::format`
  replacement).

## How to review

Read it by commit: each makes one kind of change in one area, and a follow-up names the commit it
amends. Start with the build and tooling (`meson.build`, `src/meson.build`, `.clang-tidy`, `mk.sh`,
the CI workflow) and the three tests above. Most edits to existing tests only rename what the test
names; the test ledger gives each edit's reason.

## Test changes

Existing test files this step changes (test ledger: `test-ledger.md`):

- `tests/unit/core/meson.build`
- `tests/unit/core/test_AI.cpp`
- `tests/unit/core/test_DockEntity.cpp`
- `tests/unit/core/test_DustEntity.cpp`
- `tests/unit/core/test_Entity.cpp`
- `tests/unit/core/test_EntityScriptEvents.cpp`
- `tests/unit/core/test_EntityShaderBindings.cpp`
- `tests/unit/core/test_GameController.cpp`
- `tests/unit/core/test_GuiDisplayGen.cpp`
- `tests/unit/core/test_MyOpenGLView.cpp`
- `tests/unit/core/test_OOAsyncWorkManager.cpp`
- `tests/unit/core/test_OOBreakPatternEntity.cpp`
- `tests/unit/core/test_OOCheckShipDataPListVerifierStage.cpp`
- `tests/unit/core/test_OOCombinedEmissionMapGenerator.cpp`
- `tests/unit/core/test_OOCommodities.cpp`
- `tests/unit/core/test_OOCommodityMarket.cpp`
- `tests/unit/core/test_OOConcreteTexture.cpp`
- `tests/unit/core/test_OOConstToString.cpp`
- `tests/unit/core/test_OODebugMonitor.cpp`
- `tests/unit/core/test_OODebugSupport.cpp`
- ... and 90 more: `git diff --name-only --diff-filter=MD seriesb/026-migration-completion seriesb/027-modern-cpp -- tests/`

## Verified **(gen)**

Not verified yet.
