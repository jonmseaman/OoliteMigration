# Clang Tidy Findings

Generated 2026-11-06 on `seriesb/024-post-conversion-fixes` (`e4de54bc1`) with clang-tidy 22.1.8 (Homebrew `llvm@22`), the repo's `.clang-tidy`, and `build/meson_test/compile_commands.json`.

Command: `run-clang-tidy -clang-tidy-binary /opt/homebrew/opt/llvm@22/bin/clang-tidy -p build/meson_test -quiet 'src/(Core|SDL|oofnd)/.*\.cpp'` (229 of 239 database entries match).

Files in this folder:

- `Clang Tidy Findings (list).txt`: every distinct finding, one line each, sorted by file.
- `Clang Tidy Findings (raw).txt.gz`: the complete unmodified tool output (35 MB uncompressed, with each header warning repeated per including file).

## Totals

- Raw warning lines: 73,774. Distinct findings in `src/` after deduplication by file, line, column and check: **4,627**.
- Findings reported as errors (checks in `WarningsAsErrors`): **40**. The run exited nonzero.
- Files with findings: 331.
- Findings in headers outside `src/` (SDL, quickjs, system) are excluded from the counts.

## By check

| Check | Findings | As errors |
|---|---:|---:|
| `bugprone-narrowing-conversions` | 1,707 | 0 |
| `modernize-use-nullptr` | 663 | 0 |
| `bugprone-easily-swappable-parameters` | 568 | 0 |
| `readability-make-member-function-const` | 430 | 0 |
| `modernize-redundant-void-arg` | 281 | 0 |
| `bugprone-branch-clone` | 221 | 0 |
| `bugprone-macro-parentheses` | 182 | 0 |
| `performance-enum-size` | 181 | 0 |
| `modernize-use-using` | 175 | 0 |
| `bugprone-assignment-in-if-condition` | 44 | 0 |
| `bugprone-implicit-widening-of-multiplication-result` | 42 | 0 |
| `bugprone-switch-missing-default-case` | 37 | 0 |
| `clang-diagnostic-error` | 32 | 32 |
| `bugprone-derived-method-shadowing-base-method` | 17 | 0 |
| `modernize-use-override` | 10 | 0 |
| `bugprone-integer-division` | 9 | 0 |
| `bugprone-infinite-loop,-warnings-as-errors` | 6 | 6 |
| `bugprone-reserved-identifier` | 6 | 0 |
| `bugprone-incorrect-roundings` | 4 | 0 |
| `bugprone-invalid-enum-default-initialization` | 3 | 0 |
| `bugprone-float-loop-counter` | 3 | 0 |
| `performance-no-int-to-ptr` | 2 | 0 |
| `bugprone-redundant-branch-condition` | 1 | 0 |
| `bugprone-empty-catch,-warnings-as-errors` | 1 | 1 |
| `performance-noexcept-move-constructor,-warnings-as-errors` | 1 | 1 |
| `bugprone-unhandled-self-assignment` | 1 | 0 |

## By directory

| Directory | Findings |
|---|---:|
| `src/Core` | 2,274 |
| `src/Core/Entities` | 1,146 |
| `src/Core/Scripting` | 591 |
| `src/Core/Materials` | 293 |
| `src/oofnd` | 95 |
| `src/SDL` | 81 |
| `src/Core/Debug` | 78 |
| `src/Core/OXPVerifier` | 51 |
| `src/oofnd/objc` | 18 |

## Top 25 files

| File | Findings |
|---|---:|
| `src/Core/HeadUpDisplay.cpp` | 473 |
| `src/Core/Entities/ShipEntity.cpp` | 354 |
| `src/Core/Universe.cpp` | 317 |
| `src/Core/GuiDisplayGen.cpp` | 201 |
| `src/Core/Entities/PlayerEntity.cpp` | 171 |
| `src/Core/OOTrumble.cpp` | 98 |
| `src/Core/OOCache.cpp` | 68 |
| `src/Core/OOMesh.cpp` | 67 |
| `src/Core/OOStringExpander.cpp` | 66 |
| `src/Core/Materials/OOPlanetTextureGenerator.cpp` | 60 |
| `src/Core/UniverseVirtualMembers.h` | 59 |
| `src/Core/Scripting/OOJSShip.cpp` | 56 |
| `src/Core/Scripting/OOJavaScriptEngine.cpp` | 54 |
| `src/SDL/MyOpenGLView.cpp` | 48 |
| `src/Core/Entities/EntityVirtualMembers.h` | 46 |
| `src/Core/OOTypes.h` | 45 |
| `src/Core/HeadUpDisplay.h` | 41 |
| `src/Core/Entities/PlayerEntityStickProfile.cpp` | 39 |
| `src/Core/Entities/Entity.cpp` | 38 |
| `src/Core/Entities/OOSunEntity.cpp` | 38 |
| `src/Core/Scripting/OOJSPlayerShip.cpp` | 38 |
| `src/Core/Entities/PlayerEntityContracts.cpp` | 36 |
| `src/Core/OOPolygonSprite.cpp` | 33 |
| `src/Core/Entities/PlayerEntityControls.cpp` | 32 |
| `src/Core/Scripting/OOJSEngineTimeManagement.cpp` | 32 |

## Caveats

- The 32 `clang-diagnostic-error` entries are not code defects. They are "`<optional>` file not found" style errors: Homebrew's clang-tidy 22 did not find the macOS SDK and libc++ headers. Files that hit them (for example `oofnd/PList.hpp`, `Exception.hpp`, `OOScript.h`) were analysed with incomplete type information, so their other findings may be undercounted. A rerun with `--extra-arg=-isysroot$(xcrun --show-sdk-path)` would fix this.
- The 6 `bugprone-infinite-loop` errors are real tool findings and are the reason the run exited nonzero: `src/Core/AI.cpp:253`, `src/Core/Debug/OOTCPStreamDecoder.cpp:127`, `src/Core/Entities/PlayerEntity.cpp:13786`, and three more in the list file. They have not been judged; per the contract only the tools verify, and Jon adjudicates.
- `.clang-tidy` marks checks that still have findings with `-name`, so most of the counts above are expected rather than regressions.
