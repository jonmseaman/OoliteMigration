# Use C++23 and the standard library directly

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 27/28.

## What this changes

- The game, oofnd and `tools/icosmesh` build as C++23 with `-Wold-style-cast`; `./mk.sh tidy` and
  CI run `.clang-tidy`, with `cppcoreguidelines-use-enum-class` and `google-readability-casting`
  as errors.
- Ownership: `malloc`'d buffers (streamed sound, OXZ reader, snapshots) become `std::vector`; the
  async work manager owns `std::jthread`s and joins them at quit (`oo::thread::detach` goes).
- oofnd stand-ins: `oo::Expected` becomes `std::expected` (`oofnd/Expected.hpp` deleted), standard
  headers replace `oofnd/StdLib.hpp`, Foundation integer aliases become standard types,
  `oo::Exception` is a `std::exception`, literal `oo::str::format` calls become `std::format`.
- Types: unscoped enums and constant-macro lists become `enum class` or typed constants; 10 of 11
  `.tbl` tables become headers; C-style casts become named casts; read-only C strings in entities,
  scripting, materials, SDL and debug code become `std::string_view`.

## Why

Standard types read as C++ and let the compiler and clang-tidy catch what the C and Objective-C
forms hide, such as the OXZ leak below.

## Behaviour changes

- Reading a Vorbis file inside an OXZ no longer leaks a copy of every read (`OOReadOXZVorbis`). Not
  pinned.
- Work threads are joined at quit, before preferences are written and the log closed (were
  detached). Pinned by `test_OOAsyncWorkManagerShutdown`.
- Otherwise none, pinned by tests added before the changes: `test_SaveEnumValues` (numbers saved
  games and by-name calls hold), `test_EnumNameFallbacks` (every enum's names),
  `test_FormatEquivalence` (each printf format against its `std::format` replacement).

## How to review

Read by commit: each makes one kind of change in one area; a follow-up names the commit it amends.
Start with `meson.build`, `src/meson.build`, `.clang-tidy`, `mk.sh`, the CI workflow and the three
tests above.

Test edits: ~110 files; most only rename what the test names (a type, enumerator or header replaced
by its standard equivalent). `test-ledger.md` gives each edit's reason.

## Test changes

Existing test files changed (ledger `test-ledger.md`):

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

## Verified

Not verified yet.
