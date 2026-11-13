# Current state of the code

What Oolite is **now**, after Phases 0–4. For how it got here, see
`notes/Phase 4 Writeup.md`; the old phase docs and ADRs are in git under the tag
`archive/phase-0-4-docs` and are history, not rules.

## In one paragraph

Oolite builds and runs as a plain C++20 program on Windows x64 and on macOS (Apple Silicon), and
builds on Linux x64 in CI. There is no Objective-C (no `.m`, no libobjc, no `-fobjc-*`), no GNUstep
(`libgnustep-base` is replaced by `oofnd`), and no SpiderMonkey (replaced by QuickJS-ng behind a
small façade). On Windows it builds with Clang and with GCC, and both pass the unit suites. On
macOS and Linux only the platform-independent `tools` suite runs so far: the other suites still
assume Windows (LLP64); see
[notes/2026-11-07 Cross-Platform Correctness](../notes/2026-11-07%20Cross-Platform%20Correctness.md).

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

QuickJS-ng is a meson subproject pinned in `oolite-dev/subprojects/quickjs-ng.wrap` (v0.17.0).

## Style of the converted code

- Classes keep their Objective-C shape: same names, same methods, same ivars, so each file can be
  compared side by side with `upstream/oolite/src`. It reads as "Objective-C written in C++"; making
  it idiomatic is Phase 6 work, not cleanup to do in passing.
- Ownership is `oo::Ref<T>` / `oo::WeakRef<T>` (intrusive), not `shared_ptr`.
- `oo::AutoreleaseScope` / `oo::autorelease` are kept on purpose as the C++ deferred-release pool.
  Removing them changes object lifetimes; it is a separate, deliberate change.
- Plain C stays plain C. A file or function that is already C is not rewritten.
- From `seriesb/027-modern-cpp` on there are no `.tbl` X-macro files.
  - Each named enum is one header in `src/Core/Tables` (`OOScanClass.h`, …) that holds its
    members, names and pinned numbers.
  - The OpenGL state manager's tracked items are the `kStateItems` table in
    `src/Core/OOOpenGLStateManager.cpp`, which a `static_assert` checks against the state record.
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

## Display: screen matching, the warp pass and the HUD area

- **HUD area.** On a window wider than 16:9 the HUD and every GUI screen are laid out in the
  centred 16:9 rectangle (`OOHudAreaForWindow`), at full height; the space view, the sun's glare
  and the markers over objects keep the whole window.
- **Screen matching** (Game Options → Field Of View → Enter; off by default). The player gives the
  screen's size, aspect, curvature and their viewing distance, or the size is detected from the
  display (EDID on Windows, Core Graphics on macOS, nothing on Linux; `src/SDL/OODisplaySize*`).
  `OODisplayGeometry` (`src/Core/OODisplayGeometry.*`, pure maths) works out the horizontal and
  vertical field of view and the four mappings between window points, eye directions and scene
  directions. The field of view is "Physical" or a custom horizontal angle; above the physical
  angle the look is Panini (default), even spacing or classic flat. With matching off nothing
  changes. The settings are the `screen-*`, `viewer-distance-mm` and `fov-*` preferences.
- **Warp pass.** A curved screen, or a Panini or even-spacing look, draws the space view into a
  flat render (in up to three slices, each with its own yaw, for very wide angles) and warps it
  into the window through a mesh from `OODisplayGeometry::warpMesh`, before the glare and the HUD
  (`Universe` drawing, `oolite-warp` shaders). Markers over objects are placed with
  `sceneToWindow`. Without shaders the view falls back to classic flat at the same angle. Mouse
  picking and a future mouse-look camera must map window points with
  `OODisplayGeometry::windowToScene`.
- **Debug reads** (debug builds): `console.__displayProjection()` returns the projection in use,
  and `console.__setDisplayPreference(key, value)` changes a display setting at once, as the
  settings screen does; the spec 008 scenarios use both.

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
  [parity/](parity/README.md): 170 suspected differences, 2 high (both fixed) and ~12 medium. The
  open ones are listed in [notes/2026-11-07 Parity Fixes](../notes/2026-11-07%20Parity%20Fixes.md).
- **Platform features.** HDR output, `wglGetProcAddress` extension loading, display-mode changes
  (`ChangeDisplaySettingsEx`), EcoQoS and OXZ file unlocking are Windows-only, as upstream's were.
  The iTunes integration (upstream's Cocoa build) does nothing.

## Leftovers, owned by later phases

- Names kept from the Objective-C era, because changing them touches tests or installed files:
  `src/oofnd/objc/` (49 test files include from it), `Resources/Info-gnustep.plist` (read by the
  game, written by about 20 tests), the `OO_GNUSTEPDEFAULTSDIR` launcher variable, and the
  `GNUstep/Defaults` and `GNUstep/Library` folders the game keeps its data in, so existing installs
  keep their preferences, caches and managed OXZs.
- The by-name tables (`OOEntityCalledByNameTable.h`, `OOEntityObjectNamesTable.h`,
  `OOJSCallEntityMethods.h`, `OOTypeEncodings.h`) carry the Objective-C type encodings measured on
  the last Objective-C++ build and are maintained by hand; a typed registry is Phase 6.
- Legacy OpenGL (not 3.3 Core) and C++20 (not C++23) → Phase 6.
