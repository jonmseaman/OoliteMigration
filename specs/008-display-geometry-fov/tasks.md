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

- [ ] T001 Create the branch `feature/double-wide-support` from `develop` in `oolite-dev`.
  (`branch.sh` would name it `epic/…`; create it by hand.) **Accept:**
  `git -C oolite-dev rev-parse --abbrev-ref HEAD | grep -qx feature/double-wide-support`
- [ ] T002 [P] Add a `--window WxH` option to `tests/run.sh` for the `smoke` and `component` tiers,
  passed to the game as its window-size preference by `tests/launch_snapshot.py` and
  `tests/component/console.py` (research R8a). **Accept:** `tests/run.sh smoke --window 3840x1080`
  runs, and the snapshot it writes is 3840 pixels wide (a check added to the smoke tier; fails
  before the option exists)
- [ ] T003 [P] Add the step definitions under `tests/component/` (find the file that defines
  `Given a universe seeded with`): "When I set preference "<key>" to <value>" (through the debug
  console, as existing steps use `perform`), "Then the game setting "<name>" is about <n>"
  (`evaluate` of `oolite.gameSettings.<name>`, tolerance 0.5) and "Then the projection is
  <values>" (compares the debug read below). Add `tests/component/features/s9_screen_matching.feature`
  with scenario C1 from `specs/008-display-geometry-fov/contracts/settings.md`. **Accept:**
  `tests/run.sh component -k screen` (fails before the steps exist)
- [ ] T004 Add the debug read `console.__displayProjection()` exactly as
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

- [ ] T005 Write `tests/unit/core/test_OODisplayGeometry.cpp` (style of
  `tests/unit/core/test_OOVector.cpp`, `OO_TEST`/`OO_CHECK`) with tests G1–G15 exactly as the
  table in `specs/008-display-geometry-fov/contracts/geometry.md` gives them (numbers, tolerances,
  window sizes), and register `'test_OODisplayGeometry': ['Core/OODisplayGeometry.cpp']` in the
  `core_tests` dict of `tests/unit/core/meson.build`. Measure shape and size from the local
  Jacobian at the edge and line bend as deviation from a great circle (research R8). Add a
  header-only stub `src/Core/OODisplayGeometry.h` with the contract's declarations so the test
  compiles. **Accept:** `meson test -C build test_OODisplayGeometry` exits nonzero (the stub has no
  behaviour); T006's acceptance is the same command exiting zero
- [ ] T006 Implement `src/Core/OODisplayGeometry.h/.cpp` to the contract (style of
  `src/Core/OOColor.*`; a value type, no `oo::Ref`, no GL or SDL). Clamp inputs to the data-model
  limits verbatim: diagonal "254–3048 (10"–120")" mm, aspect "custom 1.0–4.0", curvature
  "800–4000 (800R–4000R)", distance "200–3000" mm, custom horizontal "20–170" degrees. `legacy()`
  must reproduce the frustum at `src/Core/Universe.cpp:5329-5340` exactly (both the 4:3-or-wider and
  the narrower branch, `distanceFactor` excluded). **Accept:**
  `meson test -C build test_OODisplayGeometry`
- [ ] T007 Add the four `MyOpenGLView` members quoted in
  `specs/008-display-geometry-fov/contracts/hud-area.md` to `src/SDL/MyOpenGLView.h/.cpp`, for now
  with `hudArea()` = the whole window and `getWindowDisplay_z()` = `display_z`. The geometry is
  built with `legacy(fov(false), w, h)` in `updateGLSize` and in `setFov`, and `setFov` rebuilds and
  bumps the generation only when its value changes (research R14: `PlayerEntity` calls it every
  frame, `PlayerEntity.cpp:3495`). Log `display.geometry.rebuild` on each rebuild. No caller
  changes yet. **Accept:** `./mk.sh build test`, C5 (`tests/run.sh component -k screen`), and a
  smoke-tier check that `display.geometry.rebuild` appears at most three times in a run (fails if
  it is logged every frame)
- [ ] T008 In `Universe::drawUniverse` (`src/Core/Universe.cpp:5321-5340`), take the four frustum
  extents from `gameView->displayGeometry().flatFrustum()` scaled by the near plane, and compute
  `distanceFactor` from those extents; keep the GUI branch (`displayGUI`, ratio 0.5) as it is.
  **Accept:** C5 still passes (`tests/run.sh component -k screen`) and `tests/run.sh smoke`
- [ ] T009 Add scenario C3 to `tests/component/features/s9_screen_matching.feature` using the
  debug read's `reticle`, `reticleOld` and `crosshair` (add `reticle` = the new mapping's position,
  computed but not yet drawn): with matching off, a target at the centre and near each edge gives
  equal `reticle` and `reticleOld`; the crosshair is at the window centre. **Accept:**
  `tests/run.sh component -k screen` fails until T010
- [ ] T010 In `src/Core/HeadUpDisplay.cpp`, draw object-tied markers from the mapping (research
  R13): `hudDrawReticleOnTarget` and `hudDrawWaypoint` (`:4104-4126` and their callers) map the
  object's eye-relative direction with `sceneToWindow` and draw at that window position with a
  full-window viewport; the reticle size (`:3818-3822`) uses `localPixelsPerRadian`; the scanner
  wedge (`:4652-4660`) uses `horizontalDeg()`/`verticalDeg()`. Keep
  `hudRotateViewpointForVirtualDepth` only where nothing else needs it. **Accept:**
  `tests/run.sh component -k screen` (C3, C5) and `tests/run.sh smoke`

**Checkpoint**: the geometry is the single source of the projection; nothing visible changed.

---

## Phase 3: User Story 1 — correct proportions on a flat ultrawide (Priority: P1) 🎯 MVP

**Goal**: a player with a flat 21:9 or 32:9 screen enters size, aspect and distance, turns screen
matching on and sees the physical angles; the HUD and menus sit in a centred 16:9 area.

**Independent test**: 27" 16:9 flat at 60 cm reports 53.0° × 31.3° (G2, C2 flat); round objects
stay round at the edge (G5); menus on a 32:9 window fit the 16:9 area (H2, H3).

- [ ] T011 [P] [US1] Add G16 (`OOHudAreaForWindow` for H1's window sizes, and
  `OOPlausibleDisplaySize`) as new `OO_TEST` cases in `tests/unit/core/test_OODisplayGeometry.cpp`.
  **Accept:** `meson test -C build test_OODisplayGeometry` fails (functions not implemented)
- [ ] T012 [US1] Implement `OOHudAreaForWindow` and `OOPlausibleDisplaySize` in
  `src/Core/OODisplayGeometry.cpp` as the contract declares them. **Accept:**
  `meson test -C build test_OODisplayGeometry`
- [ ] T013 [US1] In `MyOpenGLView::updateGLSize` (`src/SDL/MyOpenGLView.cpp:585-606`) compute
  `display_z`, `x_offset` and `y_offset` from `OOHudAreaForWindow`; keep today's window-based value
  for `getWindowDisplay_z()`; `hudArea()` returns the area. Make the sun and star glare
  (`src/Core/Entities/OOSunEntity.cpp`, both `getDisplay_z()` reads) use `getWindowDisplay_z()`
  (research R12, *Exception*). Add check H5 to `s9_screen_matching.feature` as a new scenario:
  at 3840×1080, `hudArea` is `[960, 0, 1920, 1080]` and `displayZ` is `480·16/9`. **Accept:**
  `tests/run.sh component -k screen` (H5 fails before; C5 passes unchanged) and
  `tests/run.sh smoke`
- [ ] T014 [US1] Set the viewport to `hudArea()` for HUD and GUI drawing in
  `src/Core/Universe.cpp` (HUD from about `:5652`, GUI and message GUIs about `:5806-5816`), restore
  the full window for object-tied markers (T010) and the scene; on GUI screens draw the 3D
  background and demo ships in the HUD area and clear the side bars to black (research R12). Add
  check H3 to the smoke tier. **Accept:** `tests/run.sh smoke --window 3840x1080` (H3, fails before)
  and `tests/run.sh smoke` at the default size
- [ ] T015 [US1] Map GUI mouse positions through the HUD area in
  `src/SDL/MyOpenGLView+Input.cpp:342-350` (normalise by the area's size, offset by its origin).
  Add `tests/gui/test_g<next>_wide_window_menu_click.py` (style of
  `tests/gui/test_g1_exit_via_mouse.py`): at 3840×1080 windowed, clicking a menu row's centre
  selects it (H2). **Accept:** `tests/run.sh gui` (run alone; H2 new, H4 existing unchanged)
- [ ] T016 [US1] Add the preferences of `specs/008-display-geometry-fov/data-model.md`
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
- [ ] T017 [US1] Add the "Screen Matching: Off/On" row under the Field Of View row and the
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

- [ ] T018 [US2] Enable Shape = Curved and the Curvature row (800R–4000R in 100R steps) in the
  sub-screen (files of T017), and add scenario C2 for the G9 (49", 32:9, 1000 mm curvature,
  800 mm ⇒ `fovValue` about 84.0, no restart) to `s9_screen_matching.feature`. **Accept:**
  `tests/run.sh component -k screen`
- [ ] T019 [P] [US2] Add `Resources/Shaders/oolite-warp.vertex` and `oolite-warp.fragment`
  (copy `oolite-texture.vertex/.fragment`: position and texture coordinate per vertex, one texture
  lookup, no mapping maths, research R2), and create the program beside `textureProgram`
  (`src/Core/Universe.cpp:11523-11545`). **Accept:** `./mk.sh build test` and `tests/run.sh smoke`
  with a check that the log has no shader link error for `oolite-warp` (fails before the files
  exist, since the program is requested)
- [ ] T020 [US2] Add the flat-render buffers in `initTargetFramebufferWithViewSize` /
  `resizeTargetFramebufferWithViewSize` (`src/Core/Universe.cpp:11351`, `:11604`): colour and depth
  at `flatRenderWidthPx() × flatRenderHeightPx()` (and an MSAA twin when `msaa()` is on), plus the
  window-sized `warped` RGBA16F buffer; recreate them when `displayGeometryGeneration()` changes.
  When `needsWarp()` is false, use today's target buffer and create nothing new (research R4).
  **Accept:** C5 (matching off, unchanged) and `tests/run.sh smoke` with the G9 preferences set,
  with a check for no "framebuffer not complete" or GL error lines in the log
- [ ] T021 [US2] Add the `warp` pass to `drawUniverse` between the glare (`:5622`) and the HUD
  (research R1): draw the scene and glare into the flat render with its own viewport; resolve MSAA;
  bind `warped`; draw the mesh from `warpMesh()` (VBO rebuilt on generation change) with
  `oolite-warp`; write black where a window point has no eye direction. Then draw the HUD into
  `warped` in the HUD-in-the-scene mode, and make `drawTargetTextureIntoDefaultFramebuffer`
  (`:11659`) read `warped` instead of `targetTextureID`. Log `universe.profile.warp` once per
  frame when the pass runs. **Accept:** `tests/run.sh smoke` with the G9 preferences set has the
  `universe.profile.warp` line, and with matching off has none and C5 passes
- [ ] T022 [US2] Fall back without shaders (FR-017): `shadersAvailable=false` gives classic flat,
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

- [ ] T023 [US3] Add the Field of view = Custom row, the Horizontal angle row ("20°–170° in 1°
  steps"), and the Wide-angle look row (Panini, Even spacing, Classic flat; "shown only when the
  custom angle is above physical") in the files of T017; Physical returns to the worked-out angle
  in one action (FR-008). Add a scenario to `s9_screen_matching.feature`: G9 at 800 mm, custom
  120° ⇒ `fovValue` about 120, look changes need no restart. **Accept:**
  `tests/run.sh component -k screen`
- [ ] T024 [US3] Use the warp on flat screens too when `needsWarp()` says so (Panini or even
  spacing above physical, research R4) — the T020/T021 path keyed on `needsWarp()` alone, not on
  the screen being curved. **Accept:** `meson test -C build test_OODisplayGeometry` (G11) and
  `tests/run.sh smoke` with a flat screen at custom 120° Panini has the `universe.profile.warp`
  line
- [ ] T025 [US3] In-flight field-of-view control with screen-matching on (research R14, spec edge
  case "Other camera features"): when `OO_FOV_INFLIGHT_CONTROL_ENABLED` is set, the angle the
  player pushes through `setFov` becomes an unsaved custom angle for the session; otherwise
  `setFov` from the player is ignored while matching is on. Code in `src/SDL/MyOpenGLView.cpp` and
  `src/Core/Entities/PlayerEntity.cpp:3495`. **Accept:** a scenario in `s9_screen_matching.feature`:
  with the G9 settings on, `fovValue` stays about 84.0 after 60 ticks of flight (fails if the
  per-frame push overrides it), plus a build with `-DOO_FOV_INFLIGHT_CONTROL_ENABLED=1`
  (`./mk.sh build` with that define) compiling cleanly
- [ ] T026 [US3] Slices for very wide angles (FR-018, research R6): when `sliceCount() > 1`, draw
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

- [ ] T027 [P] [US4] Add `src/Core/OODisplaySize.h` exactly as
  `specs/008-display-geometry-fov/contracts/geometry.md` quotes it, with
  `src/SDL/OODisplaySizeWindows.cpp` (EDID via `SetupDiGetClassDevs(GUID_DEVCLASS_MONITOR)` +
  `SetupDiOpenDevRegKey(..., "EDID")`, matched to the SDL display by device name; first
  detailed-timing descriptor's mm, else bytes 21–22 in cm), `src/SDL/OODisplaySizeMac.cpp`
  (`CGDisplayScreenSize`) and a Linux version that returns nothing; wire them in `src/meson.build`
  per platform (link `setupapi` on Windows). Log the result once at start-up as
  `display.size.detected`. **Accept:** `./mk.sh build test` on Windows and the macOS CI build, and
  `tests/run.sh smoke` finds the `display.size.detected` line
- [ ] T028 [US4] When screen matching is turned on and `screen-size-source` is absent or not
  `entered`, fill size and aspect from `OOQueryDisplayPhysicalSize` + `OOPlausibleDisplaySize`,
  store `screen-size-source = detected`, and show "(detected)" or "(enter your size)"; any edit sets
  `entered`, which detection never overwrites (FR-010). Add scenario C4 (both parts) to
  `s9_screen_matching.feature`. **Accept:** `tests/run.sh component -k screen`

**Checkpoint**: all stories work.

---

## Phase 7: Polish and cross-cutting concerns

- [ ] T029 Write `specs/008-display-geometry-fov/check-fps.sh` (committed `100755` with a shebang):
  reads the frame-rate medians recorded in `specs/008-display-geometry-fov/baselines.md` and exits
  nonzero if any "on" median is more than 5% below its "off" median; it takes the file as an
  optional argument. Add two samples, `specs/008-display-geometry-fov/fps-samples/drop-6.md` and
  `drop-4.md`. **Accept:** the script exits nonzero on `drop-6.md` and zero on `drop-4.md`
- [ ] T030 Frame rate (FR-014, SC-005) on the reference machine (research R9): 60 s in the smoke
  run's fixed scene, three runs each for matching off, flat 32:9 physical, G9 at 80 cm physical, and
  G9 at custom 120° Panini; medians in `specs/008-display-geometry-fov/baselines.md`. **Accept:**
  `specs/008-display-geometry-fov/check-fps.sh`
- [ ] T031 Hand check on the reference machine, labelled `design`, for Jon: the steps in
  `specs/008-display-geometry-fov/quickstart.md` *M5*, items 1–5. **Accept:** Jon's note in this
  file under *Notes*
- [ ] T032 [P] Update `docs/current-state.md` with the screen-matching settings, the warp pass and
  the HUD area (describe the code as it is; no history), and add a line to the notes of
  `specs/004-mouse-look-camera/spec.md` that mouse-look must use
  `OODisplayGeometry::windowToScene` (FR-012). **Accept:**
  `grep -q OODisplayGeometry docs/current-state.md specs/004-mouse-look-camera/spec.md`
- [ ] T033 Run `tests/run.sh all` once at the end. **Accept:** exit 0

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
- T007's acceptance counts a log line instead of a unit test because `MyOpenGLView` needs a GL
  context; the per-frame `setFov` push (research R14) is what it guards against.
