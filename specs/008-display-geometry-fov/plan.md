# Implementation Plan: Display Geometry and Field of View (ultrawide and curved monitors)

**Branch**: `epic/display-geometry-fov` (in `oolite-dev`) | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/008-display-geometry-fov/spec.md`

## Summary

Let the player describe their monitor (size, aspect, flat or curved) and where they sit, and draw
the space view so it has the right proportions from that seat, across the whole screen. Curved
screens are drawn as one flat render plus a final warp; wider-than-physical angles use the chosen
look (Panini by default). The HUD and menus sit in a centred 16:9 area on wider windows.

The approach ([research.md](research.md)): one pure C++ module, `OODisplayGeometry`, holds all the
geometry and is unit-tested against every number in the spec before anything is drawn (R2, R8).
The renderer gets its frustum from it (R5), a new `warp` pass draws a C++-built mesh between the
scene and the HUD (R1, R2), and the HUD's object markers and the GUI mouse use the same mapping
(R12, R13). With screen-matching off, the module reproduces today's frustum exactly and no warp
runs, so nothing observable changes (SC-003).

## Technical Context

**Language/Version**: C++23 (per spec 009's switch; nothing here needs more than C++20), GLSL as
the existing post-processing shaders use it.

**Primary Dependencies**: SDL3 (window, displays; no physical-size API), OpenGL (existing
framebuffer and shader set-up in `Universe.cpp`), SetupAPI on Windows and CoreGraphics on macOS
for the screen size (R7).

**Storage**: preferences through `oo::Defaults` (new keys in [data-model.md](data-model.md)).

**Testing**: `core` meson suite (new `test_OODisplayGeometry`, HUD-area rule); component scenarios
over the debug console (two new steps); `tests/run.sh gui` and `smoke`; a hand check and frame-rate
measurement on the reference machine (R9).

**Target Platform**: Windows x64 (reference), macOS arm64, Linux x64 (no size detection).

**Project Type**: desktop game.

**Performance Goals**: frame rate with screen-matching on within 5% of off on the reference
machine (FR-014, SC-005). The warp adds one full-window textured draw; the flat render is about
1.2× the window's pixels at the G9's physical angle.

**Constraints**: CLAUDE.md hard rules (below). Off by default and bit-for-bit today's frustum when
off. No GLSL copy of the mapping (R2).

**Scale/Scope**: one new module (about 600 lines) and its tests; edits in `Universe.cpp` (frustum,
framebuffers, the pass), `MyOpenGLView.*` (HUD area, geometry ownership), `HeadUpDisplay.cpp`
(markers, reticle size, scanner wedge), `MyOpenGLView+Input.cpp` (GUI mouse), the game-options
screen, `descriptions.plist`, two new shader files, one platform file.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the blank template, so the gates are CLAUDE.md's hard
rules and `docs/workflow.md`'s definition of done, as in specs 003 and 009.

| Gate | Plan | Status |
|---|---|---|
| 1. No test changed to make it pass | Only new tests (G, H, C ids). Existing GUI and smoke tests must pass unchanged (SC-003, H4). | pass |
| 2. No warning silenced | None needed; platform calls are plain C APIs. | pass |
| 3. Never touch `develop`/`master`/`main`; no force-push | Game work on `epic/display-geometry-fov`; spec docs on the planning repo's current branch; Jon merges. | pass |
| 4. Never read expansion content | Nothing here reads expansion files. Expansion HUDs are a risk (they place items with `x_offset`), covered by the HUD area keeping the same virtual units; not tested against expansion content. | pass |
| 5. Tools judge correctness | Every spec number is a unit test; rendering is judged by the existing suites plus C/H tests; the hand check is Jon's. | pass |
| 6. No `libgnustep-base` or SpiderMonkey | Nothing added. | pass |
| 7. No rewriting C for its own sake | No C touched. | pass |
| 8. Never wait for Jon | Every open choice has a default (*Notes*). | pass |
| 9. No writes outside the repo | Scratch in `.agent-tmp/`. | pass |
| 10. clang-format 22, changed files only, never `tests/` | As stated; the new test file is written by hand in the tests' layout. | pass |
| Every bead has a failing-then-passing command | Each milestone's command is in [quickstart.md](quickstart.md); tests land before the code they prove. The warp pass's proof needs the hand check for the visual part: its bead's command is G7 + the smoke run, and the visual check is a separate `design`-labelled bead for Jon. | pass |
| Style from the exemplar | `OOColor.*` for the module; `test_OOVector.cpp` for the unit test; `s1_police_kills_pirate.feature` and `test_g1_exit_via_mouse.py` for the scenarios. `OODisplayGeometry` is a value type, so no ownership type is involved. | pass |

**Re-check after Phase 1:** pass. Two additions need a line in *Complexity Tracking*: the extra
render pass and buffer, and a platform function per OS.

## Project Structure

### Documentation (this feature)

```text
specs/008-display-geometry-fov/
├── spec.md
├── plan.md               # this file
├── research.md           # Phase 0: R1–R13
├── data-model.md         # Phase 1: records, limits, preferences
├── quickstart.md         # Phase 1: how to verify each milestone
├── contracts/
│   ├── geometry.md       # OODisplayGeometry interface, definitions, unit tests G1–G12
│   ├── settings.md       # Game Options rows, preferences, script value, scenarios C1–C4
│   └── hud-area.md       # the 16:9 rule and what uses it, checks H1–H4
├── baselines.md          # created in M5: frame-rate medians
├── checklists/requirements.md
└── tasks.md              # /speckit-tasks
```

### Source Code (`oolite-dev`)

```text
src/Core/
├── OODisplayGeometry.h/.cpp      # NEW (M1): the geometry, mappings, warp mesh
├── OODisplaySize.h               # NEW (M6): OOQueryDisplayPhysicalSize
├── Universe.cpp                  # M3 frustum from the module; M5 flat-render buffer, warp pass, fovValue
├── HeadUpDisplay.cpp             # M3 markers via sceneToWindow, reticle size, scanner wedge
└── Entities/PlayerEntity.cpp, PlayerEntityControls.cpp, PlayerEntity.h   # M4 settings rows
src/SDL/
├── MyOpenGLView.h/.cpp           # M2 hudArea(); M3 owns the current OODisplayGeometry
├── MyOpenGLView+Input.cpp        # M2 GUI mouse in the HUD area
└── OODisplaySizeWindows.cpp      # NEW (M6); OODisplaySizeMac.cpp (M6); Linux returns nothing
Resources/Shaders/oolite-warp.vertex, oolite-warp.fragment   # NEW (M5)
Resources/Config/descriptions.plist                         # M4 row strings
tests/unit/core/test_OODisplayGeometry.cpp, test_OOHudArea.cpp   # NEW (M1, M2)
tests/unit/core/meson.build                                 # register them
tests/component/features/s9_screen_matching.feature        # NEW (M3, M4) + two console steps
tests/gui/test_g?_wide_window_menu_click.py                # NEW (M2), next free g-number
```

**Structure Decision**: no new directories. The module sits in `src/Core` beside the other maths
(`OOVector`, `OOMatrix`); the platform size query sits in `src/SDL` with the other platform code.

## Milestones

Each milestone builds, passes `tests/run.sh unit` and `smoke`, and is one or more beads with the
command in [quickstart.md](quickstart.md). Order is by dependency, not by the spec's priorities:
M1 serves every story.

| M | What | Stories / FRs | Proof |
|---|---|---|---|
| M1 | `OODisplayGeometry` + tests G1–G12 (tests first) | all numbers in Stories 1–3; FR-005, 005a, 007a/b, 011, 013 | `meson test test_OODisplayGeometry` |
| M2 | HUD area in `updateGLSize`; HUD and GUI viewports; GUI mouse; GUI 3D content in the area | FR-016, SC-007 | H1–H4 |
| M3 | Frustum from the module (legacy when off); markers, reticle size and scanner wedge from the mapping | FR-002, FR-012, SC-003 | G1, C1, C3, unchanged snapshots |
| M4 | Preferences, Game Options row and sub-screen, live rebuild, `fovValue` | FR-001, 003–005a, 007, 008, 010, 011, 013, 015, 017 notice | C2, C4 |
| M5 | Flat-render buffer sized by R3 (MSAA included); `warp` pass and shaders; HUD into the warped buffer; second pass reads it | FR-006, 006a–d, 014, 017 fallback; Stories 1–3 visually; SC-005, SC-006 | G7 + smoke; hand check and frame-rate bead (Jon) |
| M6 | Screen-size detection (Windows, macOS) and the plausibility check | FR-009, Story 4 | unit test of the plausibility rule + hand check |
| M7 | Slices for very wide angles | FR-018 | G10 + smoke at 160° |

### The `warp` pass (M5)

- New buffers, created and resized beside the existing ones in `initTargetFramebufferWithViewSize`
  / `resizeTargetFramebufferWithViewSize`: the flat-render colour + depth (and its MSAA twin) at
  `flatRenderWidthPx × flatRenderHeightPx × sliceCount`, and the window-sized `warped` buffer
  (RGBA16F, as `targetTexture` is today).
- When `needsWarp()` is false, the flat render is the window-sized target buffer it is today and
  the pass is skipped (R4).
- The pass: resolve MSAA, bind `warped`, draw the warp mesh (VBO rebuilt when the geometry's
  generation changes) with `oolite-warp` (texture lookup only), then bind `warped` for the HUD in
  the HUD-in-the-scene mode; `drawTargetTextureIntoDefaultFramebuffer` reads `warped` instead of
  `targetTexture`.
- Outside the panel (a window point with no eye direction, possible only at extreme custom
  settings) the pass writes black.

## Notes (defaults taken without asking)

- The plan supersedes the spec's "the settings live with the existing Game Options" open point:
  a sub-screen under Game Options (R10); spec 007 is not a dependency.
- GUI screens' 3D content goes into the 16:9 area with black bars (R12). Jon may prefer the
  starfield behind the bars; that is a one-line change of what the bars are cleared with.
- Linux gets no size detection in this feature (R7).
- The reference machine is Jon's Windows machine with the G9 (R9).
- Custom horizontal angle range 20°–170° (data model), matching the spec's 170° limit.
- `fovValue` stays the only script-visible value; no new script properties (spec FR-013).
- Spec 004 (mouse-look) is not built; when it is, it must use `windowToScene` (FR-012). Recorded in
  the contract so spec 004's plan picks it up.

## Complexity Tracking

| Addition | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| A render pass and a window-sized buffer | The warp must run on the scene before the HUD and before bloom and post-effects (R1) | Warping inside the final shader would also warp the HUD in the HUD-in-the-scene mode |
| A platform function per OS for screen size | SDL3 has no physical-size API (R7) | Asking every player to type their size fails SC-004 |
