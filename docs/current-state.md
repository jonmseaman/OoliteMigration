# Current state of the code

What Oolite is **now**, after Phases 0–4. For how it got here, see
`notes/Phase 4 Writeup.md`; the old phase docs and ADRs are in git under the tag
`archive/phase-0-4-docs` and are history, not rules.

## In one paragraph

Oolite builds and runs as a plain C++20 program on Windows x64. There is no Objective-C (no `.m`,
no libobjc, no `-fobjc-*`), no GNUstep (`libgnustep-base` is replaced by `oofnd`), and no
SpiderMonkey (replaced by QuickJS-ng behind a small façade). It builds with Clang and with GCC;
both pass the unit suites and replay the blessed goldens. macOS and Linux do not build yet
(Phase 5).

## Repositories

| Path | What | Branch |
|---|---|---|
| `.` (this repo) | plan, tools, goldens, tests that drive the game | `main` |
| `oolite-dev/` | submodule: the game being changed (`jonmseaman/oolite`) | `develop` |
| `oolite-main/` | submodule: the same fork's `master`, for reference | `master` |
| `upstream/*` | OoliteProject's own repos, unmodified, reference only | — |

Work reaches `oolite-dev`'s `develop` through pull requests Jon merges. `bash tools/sync-dev.sh`
records the merged `oolite-dev` commit here; `bash tools/phase-pr.sh` opens `develop → master`.

## Source layout (`oolite-dev/src`)

| Directory | What |
|---|---|
| `oofnd/` | The Foundation replacement: `Ref`/`WeakRef` (intrusive refcount), `AutoreleaseScope`, `String` helpers (UTF-8 `std::string`), `PList` with old-style and XML parsers/writers and typed `PListGet`, `Defaults`, `FileSystem`, `Log`/`LogFile`, `Http`, `Scanner`, `Expected`. `oofnd/objc/` holds C-only leftovers (`OOAssert`, `OOException.h`, type aliases). |
| `Core/` | The game, converted class by class from Objective-C. Shape is deliberately close to the original (see "Style" below). |
| `Core/Scripting/ooscript/` | `JSEngine.hpp`, the JS façade; `JSEngine_quickjs.cpp` is the only file that touches QuickJS-ng. |
| `Core/MiniZip/`, other vendored C | Kept as C, not rewritten. |
| `SDL/` | Platform layer: window, input, Windows resources. |
| `meson/` | Per-platform meson fragments. |

QuickJS-ng is a meson subproject pinned in `oolite-dev/subprojects/quickjs-ng.wrap` (v0.16.2).

## Style of the converted code

- Classes keep their Objective-C shape: same names, same methods, same ivars, so each file can be
  compared side by side with `upstream/oolite/src`. It reads as "Objective-C written in C++"; making
  it idiomatic is Phase 6 work, not cleanup to do in passing.
- Ownership is `oo::Ref<T>` / `oo::WeakRef<T>` (intrusive), not `shared_ptr`.
- `oo::AutoreleaseScope` / `oo::autorelease` are kept on purpose as the C++ deferred-release pool.
  Removing them changes object lifetimes; it is a separate, deliberate change.
- Plain C stays plain C. A file or function that is already C is not rewritten.
- `OOColor` (`src/Core/OOColor.*`) is the reference for how a converted class looks.

## Builds

| Flavour | Command | Notes |
|---|---|---|
| Clang (MSYS2 UCRT64) | `tools/build-windows.sh test` | the primary build; ASan via Tier C |
| GCC (UCRT64 g++) | `tools/build-windows.sh --gcc test` | must stay green beside Clang |
| Upstream-style | `cd oolite-dev && ./mk.sh build test` | |

`-ffp-contract=off` and a pinned `-O` keep floating point reproducible for the goldens.
`-Wall -Wextra` is clean. The gate skips exactly two vendored paths, `src/Core/MiniZip/` and
`src/SDL/stb_image_write.h`; their warnings still print, and no other path may be added.

## Tests

| Kind | Where | What it decides |
|---|---|---|
| Unit | `oolite-dev/tests/unit/` (core ~175 files, `oofnd` ~40) | class behaviour; `oofnd` also under ASan |
| Goldens | `tests/golden/`, blessed outputs in `goldens/windows-x64/` | a seeded headless run dumps canonical JSON state; any diff fails. Only `001` and `001-launch-dock` are blessed; 002–020 are built and waiting for Jon (`tests/golden/pending/`) |
| Component (BDD) | `oolite-dev/tests/component/` | pytest-bdd scenarios drive a real game over the debug console; tolerant invariants |
| GUI | `oolite-dev/tests/gui/` | PyAutoGUI drives the real window (G1–G11). Takes `tools/gui-lock` |
| JS API snapshot | `tools/js-api-snapshot.sh` | the 1.93 scripting surface; drift fails |
| Expansion corpus | `tools/oxp_tier1.py`, `tools/oxp_tier23.py` | load-tests published expansions; known content failures in `tools/oxp-corpus/known-content-failures.json` |
| Guardrails | `tools/guardrails.sh` | hard rules (goldens untouched, no silenced warnings, deny-list, …) |

The tiers that bundle these are in [workflow.md](workflow.md).

## Known differences from upstream 1.93

- **JavaScript engine.** QuickJS-ng is stricter than SpiderMonkey 1.8.5: legacy generators, `for
  each`, E4X and other Mozilla-only syntax no longer parse; some strict-mode bugs now throw.
  `toSource`, `uneval`, `String.prototype.quote` and the Array/String generics are polyfilled
  best-effort. Full list and fixes: [EXPANSION_MIGRATION.md](EXPANSION_MIGRATION.md); per-expansion
  findings: [expansions/](expansions/README.md).
- **Plists.** `oofnd` reproduces GNUstep's parsing, with a small set of intentional differences
  (the ⚠️ rows of the parity audit's [foundation.md](parity/foundation.md); e.g. the data cache is
  written as XML, not GNUstep binary).
- **Behaviour parity.** A method-by-method audit against `upstream/oolite/src` is in
  [parity/](parity/README.md): 170 suspected differences, 2 high and ~12 medium. Fixing these is
  part of the current phase.

## Leftovers, owned by later phases

- Mac-only Objective-C under `#if OOLITE_MAC_OS_X` and `GameController+FullScreen.mm` → Phase 5.
- `tools/cross/aarch64-apple-darwin.ini` still names `objc` compilers → Phase 5.
- Legacy OpenGL (not 3.3 Core) and C++20 (not C++23) → Phase 6.
- Dead GNUstep-era macros, bead/ADR references in source comments, WebKit-style `.clang-format`
  → the current phase ([4p-upstream-polish](phases/4p-upstream-polish.md)).
