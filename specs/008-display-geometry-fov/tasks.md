---

description: "Tasks for display geometry and field of view (spec 008)"
---

# Tasks: Display Geometry and Field of View (ultrawide and curved monitors)

**Input**: Design documents from `specs/008-display-geometry-fov/`

**Prerequisites**:

- [plan.md](plan.md) (milestones M1–M7)
- [spec.md](spec.md) (US1–US4, FR-001–FR-018, SC-001–SC-007)
- [research.md](research.md) (R1–R14, R8a)
- [data-model.md](data-model.md)
- [contracts/geometry.md](contracts/geometry.md) (G1–G16), [contracts/settings.md](contracts/settings.md)
  (C1–C5, the debug read), [contracts/hud-area.md](contracts/hud-area.md) (H1–H5, the new view
  members)
- [quickstart.md](quickstart.md)

**Tests**: Included. CLAUDE.md requires every task to have a command that exits nonzero before it
and zero after. Each task ends with its **Accept:** command; a test task lands before the code it
proves. "Unchanged when off" is proved by the projection pin C5 (research R8a), not by comparing
pictures.

**Organization**: by user story. All paths are in `oolite-dev/`, on the branch
`feature/double-wide-support`. Every phase also passes `tests/run.sh unit` and is clean at
`-Wall -Wextra` (docs/workflow.md, *Done, for one bead*). Run `clang-format` 22 on changed `src/`
files only, never on `tests/`. New interfaces are those quoted in the contracts; a task that needs
another one stops and the contract is extended first.

| Phase | Milestone | Story |
|---|---|---|
| 1 Setup | — | — (window-size option, projection pin, console steps) |
| 2 Foundational | M1, M3 | — (geometry module, legacy frustum, markers from the mapping) |
| 3 | M2, M4 (part) | US1 flat ultrawide (P1) 🎯 MVP |
| 4 | M4 (part), M5 | US2 curved (P1) |
| 5 | M4 (part), M7 | US3 custom angle and looks (P2) |
| 6 | M6 | US4 detection (P3) |
| 7 Polish | — | frame rate, hand check, docs |

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1–US4 from spec.md

---

## Phase 1: Setup

**Purpose**: the branch and the test tools later tasks need, with today's projection recorded
before anything changes.

- [X] T001 Create the branch `feature/double-wide-support` in `oolite-dev` with `git town append` on
  `seriesb/026-migration-completion` (Jon, 2026-11-12; first cut from `develop`, then recreated).
  (`branch.sh` would name it `epic/…`; create it by hand.) **Accept:**
  `git -C oolite-dev rev-parse --abbrev-ref HEAD | grep -qx feature/double-wide-support`
- [X] T002 [P] Add a `--window WxH` option to `tests/run.sh` for the `smoke` and `component` tiers,
  passed to the game as its window-size preference by `tests/launch_snapshot.py` and
  `tests/component/console.py` (research R8a). **Accept:** `tests/run.sh smoke --window 3840x1080`
  runs, and the snapshot it writes is 3840 pixels wide (a check added to the smoke tier; fails
  before the option exists)
- [X] T003 [P] Add the step definitions under `tests/component/` (find the file that defines
  `Given a universe seeded with`): implemented in a new `tests/component/steps/display_steps.py`
  as "Given the preference "<key>" is "<value>"" and "Given a window of <W>x<H>" (passed on the
  game's command line at launch, see `contracts/settings.md`), "Then the game setting "<name>" is
  about <n>" and the two projection steps. Add `tests/component/features/s9_screen_matching.feature`
  with scenario C1 from `specs/008-display-geometry-fov/contracts/settings.md`. **Accept:**
  `tests/run.sh component -k screen` (fails before the steps exist)
- [X] T004 Add the debug read `console.__displayProjection()` exactly as
  `specs/008-display-geometry-fov/contracts/settings.md` (*Debug read*) gives it, compiled only with
  `OO_DEBUG_MONITOR_ENABLED`, beside the existing debug-console methods; the frustum extents come
  from the values `drawUniverse` passed to `OOGLFrustum` in the last frame (store them in
  `Universe`). `windowDisplayZ` and `hudArea` read today's `display_z` and the whole window until
  T013 adds the real ones. Then add scenario C5 with the values it reports today, written into the
  feature file: at 1920×1080 every field; at 2560×1080 and 3840×1080 (`--window`) only the frustum
  extents, `windowDisplayZ` and `fovValue`, which FR-016 does not change. **Accept:**
  `tests/run.sh component -k screen` (fails before the read exists; C5 then pins today's
  projection for every later task)

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the geometry module every story uses, and the renderer and HUD reading it with
nothing visible changed. ⚠️ No story starts until this phase is done.

- [X] T005 Write `tests/unit/core/test_OODisplayGeometry.cpp` (style of
  `tests/unit/core/test_OOVector.cpp`, `OO_TEST`/`OO_CHECK`) with tests G1–G15 exactly as the
  table in `specs/008-display-geometry-fov/contracts/geometry.md` gives them (numbers, tolerances,
  window sizes), and register `'test_OODisplayGeometry': ['Core/OODisplayGeometry.cpp']` in the
  `core_tests` dict of `tests/unit/core/meson.build`. Measure shape and size from the local
  Jacobian at the edge and line bend as deviation from a great circle (research R8). Add a
  header-only stub `src/Core/OODisplayGeometry.h` with the contract's declarations so the test
  compiles. **Accept:** `meson test -C build test_OODisplayGeometry` exits nonzero (the stub has no
  behaviour); T006's acceptance is the same command exiting zero
- [X] T006 Implement `src/Core/OODisplayGeometry.h/.cpp` to the contract (style of
  `src/Core/OOColor.*`; a value type, no `oo::Ref`, no GL or SDL). Clamp inputs to the data-model
  limits verbatim: diagonal "254–3048 (10"–120")" mm, aspect "custom 1.0–4.0", curvature
  "800–4000 (800R–4000R)", distance "200–3000" mm, custom horizontal "20–170" degrees. `legacy()`
  must reproduce the frustum at `src/Core/Universe.cpp:5329-5340` exactly (both the 4:3-or-wider and
  the narrower branch, `distanceFactor` excluded). **Accept:**
  `meson test -C build test_OODisplayGeometry`
- [X] T007 Add the four `MyOpenGLView` members quoted in
  `specs/008-display-geometry-fov/contracts/hud-area.md` to `src/SDL/MyOpenGLView.h/.cpp`, for now
  with `hudArea()` = the whole window and `getWindowDisplay_z()` = `display_z`. The geometry is
  built with `legacy(fov(false), w, h)` in `updateGLSize` and in `setFov`, and `setFov` rebuilds and
  bumps the generation only when its value changes (research R14: `PlayerEntity` calls it every
  frame, `PlayerEntity.cpp:3495`). Log `display.geometry.rebuild` on each rebuild. No caller
  changes yet. **Accept:** `./mk.sh build test`, C5 (`tests/run.sh component -k screen`), and a
  smoke-tier check that `display.geometry.rebuild` appears at most three times in a run (fails if
  it is logged every frame)
- [X] T008 In `Universe::drawUniverse` (`src/Core/Universe.cpp:5321-5340`), take the four frustum
  extents from `gameView->displayGeometry().flatFrustum()` scaled by the near plane, and compute
  `distanceFactor` from those extents; keep the GUI branch (`displayGUI`, ratio 0.5) as it is.
  **Accept:** C5 still passes (`tests/run.sh component -k screen`) and `tests/run.sh smoke`
- [X] T009 **Moved to T021a** (see the note after this phase). Add scenario C3 to `tests/component/features/s9_screen_matching.feature` using the
  debug read's `reticle`, `reticleOld` and `crosshair` (add `reticle` = the new mapping's position,
  computed but not yet drawn): with matching off, a target at the centre and near each edge gives
  equal `reticle` and `reticleOld`; the crosshair is at the window centre. **Accept:**
  `tests/run.sh component -k screen` fails until T010
- [X] T010 **Moved to T021a** (see the note after this phase). In `src/Core/HeadUpDisplay.cpp`, draw object-tied markers from the mapping (research
  R13): `hudDrawReticleOnTarget` and `hudDrawWaypoint` (`:4104-4126` and their callers) map the
  object's eye-relative direction with `sceneToWindow` and draw at that window position with a
  full-window viewport; the reticle size (`:3818-3822`) uses `localPixelsPerRadian`; the scanner
  wedge (`:4652-4660`) uses `horizontalDeg()`/`verticalDeg()`. Keep
  `hudRotateViewpointForVirtualDepth` only where nothing else needs it. **Accept:**
  `tests/run.sh component -k screen` (C3, C5) and `tests/run.sh smoke`

**Checkpoint**: the geometry is the single source of the projection; nothing visible changed.

**Change while implementing (2026-11-12).** The HUD draws its object markers through the scene's
own field of view (`hudRotateViewpointForVirtualDepth` scales by `fov(true)`). With no warp — every
flat-screen setting, and every setting with shaders off — the projection is an ordinary
perspective, so making the view's stored field of view follow the geometry's horizontal angle
(`MyOpenGLView::_fov = tan(h)` while screen matching is on) keeps the existing frustum code, the
HUD markers and `fovValue` right with no new marker code. So: T008 uses `flatFrustum()` only when
screen matching is on and keeps today's expressions when it is off (exact by construction, C5);
T009–T010's marker-by-mapping path is needed only when `needsWarp()`, cannot be checked before
the warp exists, and moves to US2 as T021a. Known gap: a window narrower than 4:3 with screen
matching on keeps the HUD's 4:3 rule while the frustum follows the panel; recorded, not fixed.

---

## Phase 3: User Story 1 — correct proportions on a flat ultrawide (Priority: P1) 🎯 MVP

**Goal**: a player with a flat 21:9 or 32:9 screen enters size, aspect and distance, turns screen
matching on and sees the physical angles; the HUD and menus sit in a centred 16:9 area.

**Independent test**: 27" 16:9 flat at 60 cm reports 53.0° × 31.3° (G2, C2 flat); round objects
stay round at the edge (G5); menus on a 32:9 window fit the 16:9 area (H2, H3).

- [X] T011 [P] [US1] Add G16 (`OOHudAreaForWindow` for H1's window sizes, and
  `OOPlausibleDisplaySize`) as new `OO_TEST` cases in `tests/unit/core/test_OODisplayGeometry.cpp`.
  **Accept:** `meson test -C build test_OODisplayGeometry` fails (functions not implemented)
- [X] T012 [US1] Implement `OOHudAreaForWindow` and `OOPlausibleDisplaySize` in
  `src/Core/OODisplayGeometry.cpp` as the contract declares them. **Accept:**
  `meson test -C build test_OODisplayGeometry`
- [X] T013 [US1] In `MyOpenGLView::updateGLSize` (`src/SDL/MyOpenGLView.cpp:585-606`) compute
  `display_z`, `x_offset` and `y_offset` from `OOHudAreaForWindow`; keep today's window-based value
  for `getWindowDisplay_z()`; `hudArea()` returns the area. Make the sun and star glare
  (`src/Core/Entities/OOSunEntity.cpp`, both `getDisplay_z()` reads) use `getWindowDisplay_z()`
  (research R12, *Exception*). Add check H5 to `s9_screen_matching.feature` as a new scenario:
  at 3840×1080, `hudArea` is `[960, 0, 1920, 1080]` and `displayZ` is `480·16/9`. **Accept:**
  `tests/run.sh component -k screen` (H5 fails before; C5 passes unchanged) and
  `tests/run.sh smoke`
- [X] T014 [US1] Set the viewport to `hudArea()` for HUD and GUI drawing in
  `src/Core/Universe.cpp` (HUD from about `:5652`, GUI and message GUIs about `:5806-5816`), restore
  the full window for object-tied markers (T010) and the scene; on GUI screens draw the 3D
  background and demo ships in the HUD area and clear the side bars to black (research R12). Add
  check H3 to the smoke tier. **Accept:** `tests/run.sh smoke --window 3840x1080` (H3, fails before)
  and `tests/run.sh smoke` at the default size
- [X] T015 [US1] Map GUI mouse positions through the HUD area in
  `src/SDL/MyOpenGLView+Input.cpp:342-350` (normalise by the area's size, offset by its origin).
  Add `tests/gui/test_g<next>_wide_window_menu_click.py` (style of
  `tests/gui/test_g1_exit_via_mouse.py`): at 3840×1080 windowed, clicking a menu row's centre
  selects it (H2). **Accept:** `tests/run.sh gui` (run alone; H2 new, H4 existing unchanged)
- [X] T016 [US1] Add the preferences of `specs/008-display-geometry-fov/data-model.md`
  (*Preferences*) read and written with `oo::Defaults::standard()` beside `fov-value`
  (`src/Core/Universe.cpp:342-349`, `src/Core/Entities/PlayerEntityControls.cpp:3995`):
  `screen-matching` (default false), `screen-diagonal-mm`, `screen-aspect`, `screen-curvature-mm`
  ("absent or 0 = flat"), `screen-size-source` (`entered`/`detected`), `viewer-distance-mm`,
  `fov-mode`, `fov-custom-horizontal`, `fov-wide-look`. When `screen-matching` is true,
  `MyOpenGLView` builds the geometry with the full constructor (window fraction from the window
  and display sizes, `shadersAvailable` from `Universe::useShaders()`) and ignores `setFov` from
  the player (research R14); `oolite.gameSettings.fovValue` (`src/Core/Universe.cpp:4980`) returns
  `scriptFovValue()`. Add scenario C2 for the flat case (27" 16:9 at 600 mm ⇒ `fovValue` about
  53.0, no restart). **Accept:** `tests/run.sh component -k screen`
- [X] T017 [US1] Add the "Screen Matching: Off/On" row under the Field Of View row and the
  sub-screen rows Screen size, Aspect, Shape (Flat only usable until US2), Viewing distance, Units,
  Field of view (Physical), Horizontal and Vertical angle (read-only), Back, per
  `specs/008-display-geometry-fov/contracts/settings.md`, in `src/Core/Entities/PlayerEntity.h`
  (row enum), `PlayerEntity.cpp` (`setGuiToGameOptionsScreen`, `:9105`),
  `PlayerEntityControls.cpp` (`handleGameOptionsScreenKeys`, `:3580`) and
  `Resources/Config/descriptions.plist` (`gameoptions-screen-…` keys). Every change rebuilds the
  geometry at once (FR-015); clamped input shows the clamped value (FR-011); with matching on, the
  Field Of View row shows the angle in use read-only. **Accept:** a GUI test in the style of
  `tests/gui/test_g1_exit_via_mouse.py` that opens Game Options, turns matching on, reads the angle
  rows, changes the viewing distance and sees the angles change before leaving the screen
  (`tests/run.sh gui`)

**Checkpoint**: US1 works on its own: a flat ultrawide player gets physical angles and a 16:9 HUD.

---

## Phase 4: User Story 2 — correct proportions on a curved monitor (Priority: P1)

**Goal**: curved screens are drawn as one flat render plus a final warp (FR-006a–d).

**Independent test**: G3, G4, G12–G14 (numbers, straight lines, windowed, eye behind the curve);
with a curved screen set, the smoke run shows the warp pass and the hand check on the G9 (T031)
passes.

- [X] T018 [US2] Enable Shape = Curved and the Curvature row (800R–4000R in 100R steps) in the
  sub-screen (files of T017), and add scenario C2 for the G9 (49", 32:9, 1000 mm curvature,
  800 mm ⇒ `fovValue` about 84.0, no restart) to `s9_screen_matching.feature`. **Accept:**
  `tests/run.sh component -k screen`
- [X] T019 [P] [US2] Add `Resources/Shaders/oolite-warp.vertex` and `oolite-warp.fragment`
  (copy `oolite-texture.vertex/.fragment`: position and texture coordinate per vertex, one texture
  lookup, no mapping maths, research R2), and create the program beside `textureProgram`
  (`src/Core/Universe.cpp:11523-11545`). **Accept:** `./mk.sh build test` and `tests/run.sh smoke`
  with a check that the log has no shader link error for `oolite-warp` (fails before the files
  exist, since the program is requested)
- [X] T020 [US2] Add the flat-render buffers in `initTargetFramebufferWithViewSize` /
  `resizeTargetFramebufferWithViewSize` (`src/Core/Universe.cpp:11351`, `:11604`): colour and depth
  at `flatRenderWidthPx() × flatRenderHeightPx()` (and an MSAA twin when `msaa()` is on), plus the
  window-sized `warped` RGBA16F buffer; recreate them when `displayGeometryGeneration()` changes.
  When `needsWarp()` is false, use today's target buffer and create nothing new (research R4).
  **Accept:** C5 (matching off, unchanged) and `tests/run.sh smoke` with the G9 preferences set,
  with a check for no "framebuffer not complete" or GL error lines in the log
- [X] T021 [US2] Add the `warp` pass to `drawUniverse` between the glare (`:5622`) and the HUD
  (research R1): draw the scene and glare into the flat render with its own viewport; resolve MSAA;
  bind `warped`; draw the mesh from `warpMesh()` (VBO rebuilt on generation change) with
  `oolite-warp`; write black where a window point has no eye direction. Then draw the HUD into
  `warped` in the HUD-in-the-scene mode, and make `drawTargetTextureIntoDefaultFramebuffer`
  (`:11659`) read `warped` instead of `targetTextureID`. Log `universe.profile.warp` once per
  frame when the pass runs. **Accept:** `tests/run.sh smoke` with the G9 preferences set has the
  `universe.profile.warp` line, and with matching off has none and C5 passes
- [X] T021a [US2] Object markers through the mapping when `needsWarp()` (research R13; moved from
  T009–T010): `hudDrawReticleOnTarget` and `hudDrawWaypoint` in `src/Core/HeadUpDisplay.cpp` map
  the target's eye-relative direction with `sceneToWindow`, place the marker at that window point
  in the HUD's virtual units (a full-window viewport, so a marker outside the HUD area stays on
  its target), and size the reticle with `localPixelsPerRadian`; the scanner wedge uses
  `horizontalDeg()`/`verticalDeg()`. With no warp the existing path stays. Add C3 to
  `s9_screen_matching.feature` with the debug read's `reticle` field: with the G9 settings, a
  target placed near the right edge has its reticle within 2 px of `sceneToWindow` of its
  direction, and the crosshair at the window centre. **Accept:** `tests/run.sh component -k screen`
- [X] T022 [US2] Fall back without shaders (FR-017): `shadersAvailable=false` gives classic flat,
  and the sub-screen shows "Curved drawing needs shaders" when shaders are off and a curved or
  Panini/even setting is chosen; the geometry is rebuilt when the detail level changes. **Accept:**
  `meson test -C build test_OODisplayGeometry` (G11) and a scenario in `s9_screen_matching.feature`
  that lowers the detail level with the G9 settings and finds no `universe.profile.warp` line and
  `fovValue` about 84.0

**Checkpoint**: US1 and US2 both work; curved screens are exact at the physical angle.

---

## Phase 5: User Story 3 — a wider field of view with a chosen look (Priority: P2)

**Goal**: custom horizontal angle; Panini (default), even spacing or classic flat above physical.

**Independent test**: G6 (Story 3 numbers on the G9 at 120°); the looks switch live.

- [X] T023 [US3] Add the Field of view = Custom row, the Horizontal angle row ("20°–170° in 1°
  steps"), and the Wide-angle look row (Panini, Even spacing, Classic flat; "shown only when the
  custom angle is above physical") in the files of T017; Physical returns to the worked-out angle
  in one action (FR-008). Add a scenario to `s9_screen_matching.feature`: G9 at 800 mm, custom
  120° ⇒ `fovValue` about 120, look changes need no restart. **Accept:**
  `tests/run.sh component -k screen`
- [X] T024 [US3] Use the warp on flat screens too when `needsWarp()` says so (Panini or even
  spacing above physical, research R4) — the T020/T021 path keyed on `needsWarp()` alone, not on
  the screen being curved. **Accept:** `meson test -C build test_OODisplayGeometry` (G11) and
  `tests/run.sh smoke` with a flat screen at custom 120° Panini has the `universe.profile.warp`
  line
- [X] T025 [US3] In-flight field-of-view control with screen-matching on (research R14, spec edge
  case "Other camera features"): when `OO_FOV_INFLIGHT_CONTROL_ENABLED` is set, the angle the
  player pushes through `setFov` becomes an unsaved custom angle for the session; otherwise
  `setFov` from the player is ignored while matching is on. Code in `src/SDL/MyOpenGLView.cpp` and
  `src/Core/Entities/PlayerEntity.cpp:3495`. **Accept:** a scenario in `s9_screen_matching.feature`:
  with the G9 settings on, `fovValue` stays about 84.0 after 60 ticks of flight (fails if the
  per-frame push overrides it), plus a build with `-DOO_FOV_INFLIGHT_CONTROL_ENABLED=1`
  (`./mk.sh build` with that define) compiling cleanly
- [X] T026 [US3] Slices for very wide angles (FR-018, research R6): when `sliceCount() > 1`, draw
  each slice into its part of the flat render with the slice's yaw (`sliceYawDeg`) and its frustum
  (`flatFrustum(slice)`), and let `warpMesh()` split cells at slice seams. **Accept:**
  `meson test -C build test_OODisplayGeometry` (G10 with a small `maxTextureSizePx`) and
  `tests/run.sh smoke` at custom 160° on the G9 preferences with no GL errors in the log

**Checkpoint**: all three looks work, with no seams at any angle.

---

## Phase 6: User Story 4 — auto-detected screen size (Priority: P3)

**Goal**: size and aspect pre-filled from the display (FR-009, FR-010).

**Independent test**: G16 plausibility; on Windows with an EDID monitor the size row says
"(detected)"; C4.

- [X] T027 [P] [US4] Add `src/Core/OODisplaySize.h` exactly as
  `specs/008-display-geometry-fov/contracts/geometry.md` quotes it, with
  `src/SDL/OODisplaySizeWindows.cpp` (EDID via `SetupDiGetClassDevs(GUID_DEVCLASS_MONITOR)` +
  `SetupDiOpenDevRegKey(..., "EDID")`, matched to the SDL display by device name; first
  detailed-timing descriptor's mm, else bytes 21–22 in cm), `src/SDL/OODisplaySizeMac.cpp`
  (`CGDisplayScreenSize`) and a Linux version that returns nothing; wire them in `src/meson.build`
  per platform (link `setupapi` on Windows). Log the result once at start-up as
  `display.size.detected`. **Accept:** `./mk.sh build test` on Windows and the macOS CI build, and
  `tests/run.sh smoke` finds the `display.size.detected` line
- [X] T028 [US4] When screen matching is turned on and `screen-size-source` is absent or not
  `entered`, fill size and aspect from `OOQueryDisplayPhysicalSize` + `OOPlausibleDisplaySize`,
  store `screen-size-source = detected`, and show "(detected)" or "(enter your size)"; any edit sets
  `entered`, which detection never overwrites (FR-010). Add scenario C4 (both parts) to
  `s9_screen_matching.feature`. **Accept:** `tests/run.sh component -k screen`

**Checkpoint**: all stories work.

---

## Phase 7: Polish and cross-cutting concerns

- [X] T029 Write `specs/008-display-geometry-fov/check-fps.sh` (committed `100755` with a shebang):
  reads the frame-rate medians recorded in `specs/008-display-geometry-fov/baselines.md` and exits
  nonzero if any "on" median is more than 5% below its "off" median; it takes the file as an
  optional argument. Add two samples, `specs/008-display-geometry-fov/fps-samples/drop-6.md` and
  `drop-4.md`. **Accept:** the script exits nonzero on `drop-6.md` and zero on `drop-4.md`
- [X] T030 Frame rate (FR-014, SC-005) on the reference machine (research R9): 60 s in the smoke
  run's fixed scene, three runs each for matching off, flat 32:9 physical, G9 at 80 cm physical, and
  G9 at custom 120° Panini; medians in `specs/008-display-geometry-fov/baselines.md`. **Accept:**
  `specs/008-display-geometry-fov/check-fps.sh`
- [ ] T031 Hand check on the reference machine, labelled `design`, for Jon: the steps in
  `specs/008-display-geometry-fov/quickstart.md` *M5*, items 1–5. **Accept:** Jon's note in this
  file under *Notes*
- [X] T032 [P] Update `docs/current-state.md` with the screen-matching settings, the warp pass and
  the HUD area (describe the code as it is; no history), and add a line to the notes of
  `specs/004-mouse-look-camera/spec.md` that mouse-look must use
  `OODisplayGeometry::windowToScene` (FR-012). **Accept:**
  `grep -q OODisplayGeometry docs/current-state.md specs/004-mouse-look-camera/spec.md`
- [X] T033 Run `tests/run.sh all` once at the end. **Accept:** exit 0

---

## Dependencies and execution order

- **Setup (T001–T004)** first. T002 and T003 in parallel; T004 needs both (it uses `--window` and
  the projection step).
- **Foundational (T005–T010)** blocks every story. T005 → T006 → T007 → T008; T009 → T010 (T009
  after T007).
- **US1 (T011–T017)** after Foundational. T011 → T012 → T013 → T014 → T015; T016 → T017.
- **US2 (T018–T022)** after T016–T017. T019 is independent of T018; T020 → T021 → T022.
- **US3 (T023–T026)** after T021 (the warp pass). T023 → T024; T025 any time after T016; T026 after
  T024.
- **US4 (T027–T028)** after T012 and T016–T017; independent of US2 and US3. T027 → T028.
- **Polish**: T029 any time; T030 and T031 after T021 (and T024 for the 120° run); T032 any time
  after T021; T033 last.

## Parallel opportunities

- T002 alongside T003.
- T011 (new geometry tests) alongside T007–T010 once T006 is done.
- T019 (shaders) alongside T018.
- T025 (in-flight control) alongside US2.
- US4 (T027) alongside US2 and US3 once T012 is done.
- T029 and T032 alongside anything after their prerequisites.

## Independent tests per story

| Story | Test |
|---|---|
| US1 | G2, G5, G16; C2 (27" flat ⇒ 53.0°); H1–H5; GUI angle-update test |
| US2 | G3, G4, G12–G14; C2 (G9 ⇒ 84.0°); `universe.profile.warp` in smoke; hand check items 1–3 |
| US3 | G6, G10, G11, G15; custom-120° scenario; in-flight scenario; hand check item 4 |
| US4 | G16; C4; `display.size.detected` on a Windows EDID monitor |

## Implementation strategy

1. **MVP**: Setup + Foundational + US1. Flat ultrawide players get physical angles and a 16:9 HUD;
   nothing changes for anyone with matching off (C5).
2. **US2** adds the warp: the curved G9 is exact at the physical angle.
3. **US3** adds custom angles, looks, in-flight control and slices.
4. **US4** adds detection; it can run beside US2/US3.
5. **Polish**: frame rate, hand check, docs, the full run.

Each phase ends on a green `tests/run.sh unit`, `smoke` and C5, so the branch can be merged after
any checkpoint.

## Notes

- C5 records only values the feature must never change (every field at 16:9; the frustum, window
  `display_z` and `fovValue` on wider windows), so no later task edits it (hard rule 1). The values
  FR-016 changes on wider windows are checked by the new H5 instead.
- T002–T004 landed in `oolite-dev` `f36615a11`. C5's values (fov-value 57.2, matching off): at
  1920×1080 right 0.5452177, top 0.3066849, display_z 853.3333; at 2560×1080 top 0.2300137,
  window display_z 1137.7778; at 3840×1080 top 0.1533425, window display_z 1706.6666. The frustum
  varies by about 1e-7 between window sizes (float division), hence C5's 1e-6 tolerance.
- T011–T014 landed in `oolite-dev` `828938a2c`. G16's functions were written with the module
  (T006), so T011's tests passed on first run rather than failing first. H3 is weak: the start
  screen's sides were already black before the HUD area, so it cannot fail on the old code; the
  real evidence is H5 and the snapshots checked by eye (start screen and flight HUD at 3840×1080:
  HUD and menus inside 960–2880 px, the space view across all 3840). Object markers (reticle,
  waypoint) do not appear in console-driven runs with or without the change, so their placement
  in the whole window is argued from the code (MarkersInWholeWindow restores exactly the
  viewport and projection the HUD used before) and left to the hand check (T031).
- T015's H2 cannot fail as written: GUI rows are picked by the vertical position, which the HUD
  area does not change (its height is the window's), and the GUI tier pins a 960×720 window,
  narrower than 16:9. The mouse change only rescales the horizontal position, which matters for
  clicks such as the charts'. A test needs a horizontal click target in the GUI tier; open.
- One smoke run at 3840×1080 lost the game during OpenGL set-up (the log stops at
  `display.initGL`); two reruns passed and it did not recur. Recorded, not explained.
- T008 and T016 landed together in `oolite-dev` `ac04d230c`. C2 also uses a test-only preference,
  `screen-window-fraction` (both axes), because the window's share of the panel otherwise comes
  from the desktop mode and the answer would depend on the monitor the test runs on. With
  matching on, three geometry rebuilds happen at start (first size, preferences, window size),
  which is the smoke check's limit.
- T017 landed in `oolite-dev` `abc08a442`. Game Options on Windows has one free row (speech
  rows take the rest), not enough for the "Screen Matching" row plus a gap, so the sub-screen
  opens from the existing Field Of View row (Enter) instead; that row shows the angle in use and
  "(screen matching)" while matching is on, and its arrows do nothing then. The sub-screen has a
  Shape, Curvature, Field of view, Horizontal, Look and a shaders-off notice row from the start,
  so US2 and US3 add behaviour, not rows. G12 sends arrows with `GameWindow.press_key` (pyautogui
  arrives as keypad keys) and selects rows with a double click; Shift-steps are read with
  `isDown`, since `checkKeyPress` wants the exact Shift state.
- T007's acceptance counts a log line instead of a unit test because `MyOpenGLView` needs a GL
  context; the per-frame `setFov` push (research R14) is what it guards against.
- T018–T022 (US2) landed in `oolite-dev` `9322cb4fc`. The settings screen had Shape and Curvature working from T017, so T018 is the
  G9 scenario only (84.03°). The warp differs from T020/T021 as written, more simply: there is no
  separate `warped` buffer. When `needsWarp()` and shaders are on, the space view is drawn into
  the flat render (RGBA16F colour, DEPTH32F, plus a 4-sample twin when MSAA is on), made lazily
  on the first warped frame and remade when its size changes, and then warped into the
  window-sized target the game already had. The glare, the HUD and
  `drawTargetTextureIntoDefaultFramebuffer` then run as before. So the glare is drawn after the
  warp, in window space, an approximation against FR-006d, and the HUD is never warped. The log
  class is `display.warp.pass`, logged when the pass turns on or off, not per frame, and not
  `universe.profile.warp`, because `universe.profile` is off in `logcontrol.plist`. There is no
  black fill, because every window point has a scene direction. The program linking is
  shown by the warp scenario (`warpsThisFrame` needs the program).
- T021a: `hudRotateViewpointForVirtualDepth` reads the marker's eye-space position from the
  modelview. When the frame was warped, it moves the marker, at the same depth, to
  `sceneToWindow` of its direction, and scales it by `localPixelsPerRadian · 2·tan(h/2) · depth /
  (width · distance)`. The scanner wedge needed no change: with matching on `fov(true)` is
  already `tan(h/2)` of the angle in use. C3's expected point comes from the step's own
  cylinder model, not from `OODisplayGeometry`. The reticle dial needs
  `EQ_SCANNER_SHOW_MISSILE_TARGET` (`hud.plist`), which the scenario commander lacks, so the step
  awards it. This is also why earlier scripted snapshots showed no reticle.
- T022: `Universe::setDetailLevel` rebuilds the geometry when the level changes. The scenario
  lowers the level through `console.detailLevel` and checks that the last `display.warp.pass`
  line is "off" and the angle is still 84.0.
- T023–T028 (US3, US4) landed in `oolite-dev` `0de9ff56a`.
- T023–T026 (US3). The settings screen already handled the custom-angle, horizontal and look rows
  from T017. A live change is checked through a debug-only test aid,
  `console.__setDisplayPreference(key, value)`. It stores the value (as a number when it reads as
  one) and calls `reloadScreenMatchingPreferences`, the same path the screen's keys take. A key
  that a scenario changes live must not also be passed on the command line, because the
  argument domain wins on read. T024 needed no code: the warp was keyed on `needsWarp()` alone
  from T020. Its check is a component scenario rather than the smoke run, since the smoke run
  stops at the start screen, where nothing warps. T025: with `OO_FOV_INFLIGHT_CONTROL_ENABLED`, a
  change in the angle the player pushes (not the steady per-update push) becomes an unsaved custom
  angle for the session. The player's in-flight angle starts from `fov-value`, not from the
  matched angle, so the first key press jumps; this is left as it is. T026: the near and far
  passes run once per slice (`pass = slice * 2 + vdist`). Each slice gets its own viewport, its
  frustum and the eye turned by its yaw, and `drawCounter` moves on per slice, because an entity
  is otherwise drawn only once per frame. The near plane uses the widest slice's corner. The
  scenario turns on `rendering.opengl.error` through the console, since it is off by default.
- T027–T028 (US4). Windows matches the SDL display to its monitor through the device interface
  path. `MonitorFromPoint` at the display's centre gives the monitor; `GetMonitorInfo` and
  `EnumDisplayDevices(EDD_GET_DEVICE_INTERFACE_NAME)` give its path, which is matched against the
  SetupAPI monitor interfaces, and the EDID is read from the matching one. This avoids matching
  by name. macOS uses `CGGetDisplaysWithPoint` and `CGDisplayScreenSize`; it is not compiled here,
  so the macOS CI build is what checks it. The size is asked for once, at the first preference
  load, and logged (`display.size.detected`, a size or "not detected"); the smoke run checks
  that there is exactly one such line. The plausibility check compares with the display's
  desktop-mode pixels, read at the same time; the window is no help, because at the first load it
  is still its initial 768x768. A test preference, `screen-detected-size-mm` ("WxH" in mm,
  optionally "@PWxPH" for the display's pixels), stands in for the platform's answer in C4. On the
  reference machine the G9 reports 1193 x 336 mm.
  A component scenario that sets preferences runs a private staged `oolite.app` (the smoke run's
  `stage_app`, with an empty `GNUstep/`), because the game writes its preferences on exit and a
  live change or a detected size would otherwise stay in the build's saved preferences.
- Two bugs found by the live-change scenario (T023):
  - `OOOpenGLExtensionManager` loaded `glDeleteRenderbuffers` as `"glDeleteRenderbuffer"` (no
    `s`), so the pointer was null on Windows. Upstream 1.93 has the same typo
    (`OOOpenGLExtensionManager.m:649`). Resizing the flat render was the first code to call it,
    and the game crashed. The name is fixed; the fix is worth sending upstream.
  - After the slice passes, the glare and the HUD drew with the last slice's turned viewpoint,
    which shifted the HUD. The loop now rebuilds the plain flat viewpoint after the passes when
    there was more than one slice. This was checked by eye on a snapshot; no automated check
    covers HUD placement with slices.
- The build's own saved preferences (`build/meson_test/oolite.app/GNUstep/Defaults/oolite.plist`)
  had picked up `detailLevel = 0` and other display keys from scenario runs made before staging
  existed, which made later unstaged runs draw without shaders. Those keys were removed by hand.
- T025's second check: `meson setup build/meson_fovinflight -Ddebug=false -Dstrip_bin=false
  -Doo_fov_inflight_control_enabled=true --native-file clang.ini`, then `ninja src/oolite.exe`,
  which builds with no errors. A separate directory is used because `mk.sh`'s `--setup-flags` would
  reconfigure one of the existing build types. The one warning, in `OOOpenGLStateManager.cpp:471`,
  is in a file this branch does not change.
- T030: `baselines.md`. All four settings run at about 237.7 fps, the G9's 240 Hz cap, so the
  check passes (at most a 0.3% drop) but shows only that the warp stays at the cap on the
  reference machine, not its cost below it. The window was 5120 x 1440, the system GPU driver was
  used, and V-Sync was off in the game.
- T033: `tests/run.sh all` exits 0 on `oolite-dev` `0de9ff56a`: unit 40 + 183 + 1, component 37,
  smoke, GUI 154.
- T031 is Jon's (labelled design) and is still open: the quickstart M5 hand check, items 1-5, on
  the G9. Everything it depends on has landed. Its acceptance is Jon's note here.
- T015's H2 test is G13 (`tests/gui/test_g13_wide_window_chart_click.py`, `oolite-dev`
  `ba5bf5827`). Menu rows cannot show the bug, so G13 uses the short-range chart, where a
  click picks a system from both coordinates. It is differential: the same click offset from the
  HUD area's centre at 1920x1080 and at 3840x1080 must pick the same system. It also checks, at
  16:9, that half the horizontal offset picks a different system. Without that check the first
  version passed against the broken mapping too. With the old whole-window mapping put back,
  G13 fails (system 154 against 129); with the code as it is, it passes. A chart click must hold
  the button across frames, since a `pyautogui.click` can fall inside one frame and never be seen.
- Jon's hand check (2026-11-13, in flight, paused): no distortion seen. One bug: Back on the
  Screen Matching screen did not leave it from the keyboard. Back switches to Game Options with
  Field Of View selected, and the same Enter, still down on Game Options' first frame, reopened
  the screen. Fixed in `oolite-dev` `001213d3c` by clearing the keys before the switch. The test
  is G14 (`tests/gui/test_g14_screen_matching_back_with_enter.py`): it fails without the fix and
  passes with it, and G12 and G13 still pass. G14 runs from the start screen; paused in flight
  goes through the same handler (`pollGuiArrowKeyControls`, the paused branch of
  `pollFlightControls`), so no separate in-flight test was added. T031 stays open for Jon's
  sign-off.
