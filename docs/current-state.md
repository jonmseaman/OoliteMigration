# Current state of the code

What Oolite is **now**, after Phases 0–4. For how it got here, see
`notes/Phase 4 Writeup.md`; the old phase docs and ADRs are in git under the tag
`archive/phase-0-4-docs` and are history, not rules.

## In one paragraph

Oolite builds and runs as a plain C++20 program on Windows x64. There is no Objective-C (no `.m`,
no libobjc, no `-fobjc-*`), no GNUstep (`libgnustep-base` is replaced by `oofnd`), and no
SpiderMonkey (replaced by QuickJS-ng behind a small façade). It builds with Clang and with GCC;
both pass the unit suites. macOS and Linux do not build yet
(Phase 5).

## Repositories

| Path | What | Branch |
|---|---|---|
| `.` (this repo) | plan, notes, expansion corpus tooling, the beads skill | `main` |
| `oolite-dev/` | submodule: the game being changed (`jonmseaman/oolite`) | `develop` |
| `oolite-main/` | submodule: the same fork's `master`, for reference | `master` |
| `upstream/*` | OoliteProject's own repos, unmodified, reference only | — |

Work reaches `oolite-dev`'s `develop` through pull requests Jon merges. The merged `oolite-dev`
commit is recorded here at phase end (see the beads-worker skill), and `develop → master` is a
pull request on the fork.

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

Run from `oolite-dev`, in an MSYS2 UCRT64 shell (`tools/setup-windows.sh` installs it):

| Flavour | Command | Notes |
|---|---|---|
| Clang | `./mk.sh build test` | the primary build |
| GCC | `./mk.sh build test --native-file=gcc.ini` | must stay green beside Clang |

`-ffp-contract=off` and a pinned `-O` keep floating point reproducible. `-Wall -Wextra` is clean.
The warning gate skips exactly two vendored paths, `src/Core/MiniZip/` and
`src/SDL/stb_image_write.h`; their warnings still print, and no other path may be added.

## Tests

| Kind | Where | What it decides |
|---|---|---|
| Unit | `oolite-dev/tests/unit/` (core ~175 files, `oofnd` ~40) | class behaviour |
| Component (BDD) | `oolite-dev/tests/component/` | pytest-bdd scenarios drive a real game over the debug console; tolerant invariants |
| GUI | `oolite-dev/tests/gui/` | PyAutoGUI drives the real window (G1–G11) |
| Smoke | `oolite-dev/tests/launch_snapshot.py` | the game launches and renders |
| JS API contract | `oxp-contract/js-api-1.93.json` | the 1.93 scripting surface expansions are written against |
| Expansion corpus | `tools/corpus.sh`, `tools/oxp-corpus/` | load-tests published expansions; known content failures in `tools/oxp-corpus/known-content-failures.json` |

`oolite-dev/tests/run.sh` runs the first four. How to use them is in [workflow.md](workflow.md).

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
