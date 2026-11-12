---

description: "Tasks for display geometry and field of view (spec 008)"
---

# Tasks: Display Geometry and Field of View (ultrawide and curved monitors)

**Input**: Design documents from `specs/008-display-geometry-fov/`

**Prerequisites**:

- [plan.md](plan.md) (milestones M1–M7)
- [spec.md](spec.md) (US1–US4, FR-001–FR-018, SC-001–SC-007)
- [research.md](research.md) (R1–R13)
- [data-model.md](data-model.md)
- [contracts/geometry.md](contracts/geometry.md) (G1–G12), [contracts/settings.md](contracts/settings.md)
  (C1–C4), [contracts/hud-area.md](contracts/hud-area.md) (H1–H4)
- [quickstart.md](quickstart.md)

**Tests**: Included. CLAUDE.md requires every task to have a command that exits nonzero before it
and zero after. Each task ends with its **Accept:** command; a test task lands before the code it
proves.

**Organization**: by user story. All paths are in `oolite-dev/`, on the branch
`epic/display-geometry-fov`. Every task also passes `tests/run.sh unit` and is clean at
`-Wall -Wextra` (docs/workflow.md, *Done, for one bead*). Run `clang-format` 22 on changed `src/`
files only, never on `tests/`.

| Phase | Milestone | Story |
|---|---|---|
| 1 Setup | — | — |
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

**Purpose**: the branch and the test steps later tasks need.

- [ ] T001 Create the branch `epic/display-geometry-fov` from `develop` in `oolite-dev` (with
  `.claude/skills/beads-worker/scripts/branch.sh` if the work runs as beads). **Accept:**
  `git -C oolite-dev rev-parse --abbrev-ref HEAD | grep -qx epic/display-geometry-fov`
- [ ] T002 [P] Add two component steps to the step definitions under `tests/component/` (find the
  file that defines `Given a universe seeded with`): "When I set preference "<key>" to <value>"
  (calls `oo::Defaults` through the debug console the way existing steps call `perform`) and
  "Then the game setting "<name>" is about <n>" (evaluates `oolite.gameSettings.<name>` with
  `evaluate`, tolerance 0.5). Add `tests/component/features/s9_screen_matching.feature` with
  scenario C1 only: screen matching is off by default and `fovValue` equals the `fov-value`
  preference. **Accept:** `tests/run.sh component -k screen` (fails before the steps exist)

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the geometry module every story uses, and the renderer and HUD reading it with
nothing visible changed. ⚠️ No story starts until this phase is done.

- [ ] T003 Write `tests/unit/core/test_OODisplayGeometry.cpp` (style of
  `tests/unit/core/test_OOVector.cpp`, `OO_TEST`/`OO_CHECK`) with tests G1–G12 exactly as the
  table in `specs/008-display-geometry-fov/contracts/geometry.md` gives them (numbers, tolerances,
  window sizes), and register `'test_OODisplayGeometry': ['Core/OODisplayGeometry.cpp']` in the
  `core_tests` dict of `tests/unit/core/meson.build`. Measure shape and size from the local
  Jacobian at the edge and line bend as deviation from a great circle (research R8). Add a
  header-only stub `src/Core/OODisplayGeometry.h` with the contract's declarations so the test
  compiles and fails. **Accept:** `meson test -C build test_OODisplayGeometry` fails (expected)
- [ ] T004 Implement `src/Core/OODisplayGeometry.h/.cpp` to the contract in
  `specs/008-display-geometry-fov/contracts/geometry.md` (style of `src/Core/OOColor.*`; a value
  type, no `oo::Ref`, no GL or SDL). Clamp inputs to the data-model limits verbatim: diagonal
  "254–3048 (10"–120")" mm, aspect "custom 1.0–4.0", curvature "800–4000 (800R–4000R)", distance
  "200–3000" mm, custom horizontal "20–170" degrees. `legacy()` must reproduce the frustum at
  `src/Core/Universe.cpp:5329-5340` exactly (both the 4:3-or-wider and the narrower branch, the
  `distanceFactor` excluded). **Accept:** `meson test -C build test_OODisplayGeometry`
- [ ] T005 Make `MyOpenGLView` own the current geometry: a member `OODisplayGeometry` built with
  `legacy(fov(false), w, h)` in `updateGLSize` and whenever `setFov` is called, a generation
  counter bumped on every rebuild, and `const OODisplayGeometry& displayGeometry() const` in
  `src/SDL/MyOpenGLView.h/.cpp`. No caller changes yet. **Accept:** `./mk.sh build test` and
  `meson test -C build test_OODisplayGeometry`
- [ ] T006 In `Universe::drawUniverse` (`src/Core/Universe.cpp:5321-5340`), take the four frustum
  extents from `gameView->displayGeometry().flatFrustum()` scaled by the near plane, and compute
  `distanceFactor` from those extents; keep the GUI branch (`displayGUI`, ratio 0.5) as it is.
  **Accept:** `tests/run.sh smoke` snapshots compare equal to the base (SC-003) and
  `tests/run.sh unit`
- [ ] T007 Add scenario C3 to `tests/component/features/s9_screen_matching.feature`: with screen
  matching off, a target at the centre and near each edge has the same reticle window position by
  the old projection and by `sceneToWindow` (expose the two positions through a debug-console
  evaluation only in debug builds, next to the existing debug console hooks). **Accept:**
  `tests/run.sh component -k screen` fails (no new path yet)
- [ ] T008 In `src/Core/HeadUpDisplay.cpp`, draw object-tied markers from the mapping (research
  R13): `hudDrawReticleOnTarget` and `hudDrawWaypoint` (`:4104-4126` and their callers) map the
  object's eye-relative direction with `sceneToWindow` and draw at that window position with a
  full-window viewport; the reticle size (`:3818-3822`) uses `localPixelsPerRadian`; the scanner
  wedge (`:4652-4660`) uses `horizontalDeg()`/`verticalDeg()`. Keep
  `hudRotateViewpointForVirtualDepth` only where nothing else needs it. **Accept:**
  `tests/run.sh component -k screen` (C3) and `tests/run.sh smoke`

**Checkpoint**: the geometry is the single source of the projection; nothing visible changed.

---

## Phase 3: User Story 1 — correct proportions on a flat ultrawide (Priority: P1) 🎯 MVP

**Goal**: a player with a flat 21:9 or 32:9 screen enters size, aspect and distance, turns screen
matching on and sees the physical angles; the HUD and menus sit in a centred 16:9 area.

**Independent test**: 27" 16:9 flat at 60 cm reports 53.0° × 31.3° (G2, C2 variant); round objects
stay round at the edge (G5); menus on a 32:9 window fit the 16:9 area (H2, H3).

- [ ] T009 [P] [US1] Write `tests/unit/core/test_OOHudArea.cpp` (style of `test_OOVector.cpp`) for
  rule H1 in `specs/008-display-geometry-fov/contracts/hud-area.md` (1920×1080, 2560×1080,
  3440×1440, 5120×1440, 1280×1024), against a free function `OOHudAreaForWindow(int w, int h)`
  declared in `src/Core/OODisplayGeometry.h`; register it in `tests/unit/core/meson.build`.
  **Accept:** `meson test -C build test_OOHudArea` fails (expected)
- [ ] T010 [US1] Implement `OOHudAreaForWindow` in `src/Core/OODisplayGeometry.cpp` and use it in
  `MyOpenGLView::updateGLSize` (`src/SDL/MyOpenGLView.cpp:585-606`): `display_z`, `x_offset`,
  `y_offset` come from the HUD area; add `NSRect hudArea() const`. **Accept:**
  `meson test -C build test_OOHudArea` and `tests/run.sh smoke`
- [ ] T011 [US1] Set the viewport to `hudArea()` for HUD and GUI drawing in
  `src/Core/Universe.cpp` (HUD from about `:5652`, GUI and message GUIs about `:5806-5816`), restore
  the full window for object-tied markers (T008) and the scene; on GUI screens draw the 3D
  background and demo ships in the HUD area and clear the side bars to black (research R12).
  **Accept:** smoke snapshot check H3 at 3840×1080 (add the window-size option to the smoke run if
  it has none) and `tests/run.sh smoke` at the default size unchanged
- [ ] T012 [US1] Map GUI mouse positions through the HUD area in
  `src/SDL/MyOpenGLView+Input.cpp:342-350` (normalise by the area's size, offset by its origin).
  Add `tests/gui/test_g<next>_wide_window_menu_click.py` (style of
  `tests/gui/test_g1_exit_via_mouse.py`): at 3840×1080 windowed, clicking a menu row's centre
  selects it (H2). **Accept:** `tests/run.sh gui` (run alone; H2 new, H4 existing unchanged)
- [ ] T013 [US1] Add the preferences of `specs/008-display-geometry-fov/data-model.md`
  (*Preferences*) read and written with `oo::Defaults::standard()` beside `fov-value`
  (`src/Core/Universe.cpp:342-349`, `src/Core/Entities/PlayerEntityControls.cpp:3995`):
  `screen-matching` (default false), `screen-diagonal-mm`, `screen-aspect`, `screen-curvature-mm`
  ("absent or 0 = flat"), `screen-size-source` (`entered`/`detected`), `viewer-distance-mm`,
  `fov-mode`, `fov-custom-horizontal`, `fov-wide-look`. When `screen-matching` is true,
  `MyOpenGLView` builds the geometry with the full constructor (window fraction from the window
  and display sizes, `shadersAvailable` from `Universe::useShaders()`); `oolite.gameSettings.fovValue`
  (`src/Core/Universe.cpp:4980`) returns `scriptFovValue()`. Add scenario C2 for the flat case
  (27" 16:9 at 600 mm ⇒ `fovValue` about 53.0, no restart). **Accept:**
  `tests/run.sh component -k screen`
- [ ] T014 [US1] Add the "Screen Matching: Off/On" row under the Field Of View row and the
  sub-screen rows Screen size, Aspect, Shape (Flat only usable until US2), Viewing distance, Units,
  Field of view (Physical), Horizontal and Vertical angle (read-only), Back, per
  `specs/008-display-geometry-fov/contracts/settings.md`, in `src/Core/Entities/PlayerEntity.h`
  (row enum), `PlayerEntity.cpp` (`setGuiToGameOptionsScreen`, `:9105`),
  `PlayerEntityControls.cpp` (`handleGameOptionsScreenKeys`, `:3580`) and
  `Resources/Config/descriptions.plist` (`gameoptions-screen-…` keys). Every change rebuilds the
  geometry at once (FR-015); clamped input shows the clamped value (FR-011); with matching on, the
  Field Of View row shows the angle in use read-only. **Accept:** a GUI test in the style of
  `tests/gui/test_g1_exit_via_mouse.py` that opens Game Options, turns matching on and reads the
  angle row (`tests/run.sh gui`)

**Checkpoint**: US1 works on its own: a flat ultrawide player gets physical angles and a 16:9 HUD.

---

## Phase 4: User Story 2 — correct proportions on a curved monitor (Priority: P1)

**Goal**: curved screens are drawn as one flat render plus a final warp (FR-006a–d).

**Independent test**: G3, G4, G12 (numbers and straight lines); with a curved screen set, the
smoke run shows the warp pass and the hand check on the G9 (T026) passes.

- [ ] T015 [US2] Enable Shape = Curved and the Curvature row (800R–4000R in 100R steps) in the
  sub-screen (files of T014), and add scenario C2 for the G9 (49", 32:9, 1000 mm curvature,
  800 mm ⇒ `fovValue` about 84.0, no restart) to `s9_screen_matching.feature`. **Accept:**
  `tests/run.sh component -k screen`
- [ ] T016 [P] [US2] Add `Resources/Shaders/oolite-warp.vertex` and `oolite-warp.fragment`
  (copy `oolite-texture.vertex/.fragment`: position and texture coordinate per vertex, one texture
  lookup, no mapping maths, research R2), and create the program beside `textureProgram`
  (`src/Core/Universe.cpp:11523-11545`). **Accept:** `./mk.sh build test` and `tests/run.sh smoke`
  (the program links; a link failure is logged and fails the smoke log check)
- [ ] T017 [US2] Add the flat-render buffers in `initTargetFramebufferWithViewSize` /
  `resizeTargetFramebufferWithViewSize` (`src/Core/Universe.cpp:11351`, `:11604`): colour and depth
  at `flatRenderWidthPx() × flatRenderHeightPx()` (and an MSAA twin when `msaa()` is on), plus the
  window-sized `warped` RGBA16F buffer; recreate them when the geometry's generation changes. When
  `needsWarp()` is false, use today's target buffer and create nothing new (research R4).
  **Accept:** `tests/run.sh smoke` with matching off (unchanged) and with a G9 preference set
  (no GL errors in the log)
- [ ] T018 [US2] Add the `warp` pass to `drawUniverse` between the glare (`:5622`) and the HUD
  (research R1): draw the scene and glare into the flat render with its own viewport; resolve MSAA;
  bind `warped`; draw the mesh from `warpMesh()` (VBO rebuilt on generation change) with
  `oolite-warp`; write black where a window point has no eye direction. Then draw the HUD into
  `warped` in the HUD-in-the-scene mode, and make `drawTargetTextureIntoDefaultFramebuffer`
  (`:11659`) read `warped` instead of `targetTextureID`. **Accept:** `tests/run.sh smoke` with the
  G9 preference set: the log shows the warp pass and the snapshot differs from the flat one, and
  with matching off the snapshots are unchanged
- [ ] T019 [US2] Fall back without shaders (FR-017): `shadersAvailable=false` gives classic flat,
  and the sub-screen shows "Curved drawing needs shaders" when shaders are off and a curved or
  Panini/even setting is chosen; the geometry is rebuilt when the detail level changes. **Accept:**
  `meson test -C build test_OODisplayGeometry` (G11) and a component scenario in
  `s9_screen_matching.feature` that lowers the detail level and reads `fovValue`

**Checkpoint**: US1 and US2 both work; curved screens are exact at the physical angle.

---

## Phase 5: User Story 3 — a wider field of view with a chosen look (Priority: P2)

**Goal**: custom horizontal angle; Panini (default), even spacing or classic flat above physical.

**Independent test**: G6 (Story 3 numbers on the G9 at 120°); the looks switch live.

- [ ] T020 [US3] Add the Field of view = Custom row, the Horizontal angle row ("20°–170° in 1°
  steps"), and the Wide-angle look row (Panini, Even spacing, Classic flat; "shown only when the
  custom angle is above physical") in the files of T014; Physical returns to the worked-out angle
  in one action (FR-008). Add a scenario to `s9_screen_matching.feature`: G9 at 800 mm, custom
  120° ⇒ `fovValue` about 120, look changes need no restart. **Accept:**
  `tests/run.sh component -k screen`
- [ ] T021 [US3] Use the warp on flat screens too when `needsWarp()` says so (Panini or even
  spacing above physical, research R4) — the T017/T018 path keyed on `needsWarp()` alone, not on
  the screen being curved. **Accept:** `meson test -C build test_OODisplayGeometry` (G11) and
  `tests/run.sh smoke` with a flat screen at custom 120° Panini (log shows the warp pass)
- [ ] T022 [US3] Slices for very wide angles (FR-018, research R6): when `sliceCount() > 1`, draw
  each slice into its part of the flat render with the slice's yaw (`sliceYawDeg`) and its frustum
  (`flatFrustum(slice)`), and let `warpMesh()` split cells at slice seams. **Accept:**
  `meson test -C build test_OODisplayGeometry` (G10 with a small `maxTextureSizePx`) and
  `tests/run.sh smoke` at custom 160° on the G9 preferences

**Checkpoint**: all three looks work, with no seams at any angle.

---

## Phase 6: User Story 4 — auto-detected screen size (Priority: P3)

**Goal**: size and aspect pre-filled from the display (FR-009, FR-010).

**Independent test**: plausibility unit test; on Windows with an EDID monitor the size row says
"(detected)".

- [ ] T023 [P] [US4] Write a unit test in `tests/unit/core/test_OODisplayGeometry.cpp` (new
  `OO_TEST` cases, not edits of existing ones) for a free function
  `OOPlausibleDisplaySize(widthMm, heightMm, pixelW, pixelH)`: diagonal 10"–120" and aspect within
  5% of the pixel aspect, otherwise "not detected" (spec edge case). Then implement it in
  `src/Core/OODisplayGeometry.cpp`. **Accept:** `meson test -C build test_OODisplayGeometry`
  (fails before the function exists)
- [ ] T024 [US4] Add `src/Core/OODisplaySize.h` declaring
  `std::optional<std::pair<double,double>> OOQueryDisplayPhysicalSize(int sdlDisplayIndex)`
  (millimetres), with `src/SDL/OODisplaySizeWindows.cpp` (EDID via
  `SetupDiGetClassDevs(GUID_DEVCLASS_MONITOR)` + `SetupDiOpenDevRegKey(..., "EDID")`, matched to
  the SDL display by device name; first detailed-timing descriptor's mm, else bytes 21–22 in cm),
  `src/SDL/OODisplaySizeMac.cpp` (`CGDisplayScreenSize`) and a Linux version that returns nothing;
  wire them in `src/meson.build` per platform (link `setupapi` on Windows). **Accept:**
  `./mk.sh build test` on Windows, and the macOS CI build
- [ ] T025 [US4] When screen matching is turned on and `screen-size-source` is absent or not
  `entered`, fill size and aspect from `OOQueryDisplayPhysicalSize` + `OOPlausibleDisplaySize`,
  store `screen-size-source = detected`, and show "(detected)" or "(enter your size)"; any edit sets
  `entered`, which detection never overwrites (FR-010). Add scenario C4 (entered size survives a
  restart) to `s9_screen_matching.feature`. **Accept:** `tests/run.sh component -k screen`

**Checkpoint**: all stories work.

---

## Phase 7: Polish and cross-cutting concerns

- [ ] T026 Hand check on the reference machine (research R9), labelled `design`, for Jon: the
  steps in `specs/008-display-geometry-fov/quickstart.md` *M5*, items 1–5. **Accept:** Jon's note
  in this file under *Notes*
- [ ] T027 Frame rate (FR-014, SC-005): 60 s in the smoke run's fixed scene, three runs each with
  matching off and on (G9, 80 cm, physical), medians recorded in
  `specs/008-display-geometry-fov/baselines.md`. **Accept:** the two medians differ by at most 5%
  (a script that reads the two logged medians and exits nonzero otherwise)
- [ ] T028 [P] Update `docs/current-state.md` with the screen-matching settings, the warp pass and
  the HUD area (describe the code as it is; no history), and add a line to spec 004's spec notes
  that mouse-look must use `OODisplayGeometry::windowToScene` (FR-012). **Accept:**
  `grep -q OODisplayGeometry docs/current-state.md specs/004-mouse-look-camera/spec.md`
- [ ] T029 Run `tests/run.sh all` once at the end. **Accept:** exit 0

---

## Dependencies and execution order

- **Setup (T001–T002)** first.
- **Foundational (T003–T008)** blocks every story. T003 → T004 → T005 → T006; T007 → T008.
- **US1 (T009–T014)** after Foundational. T009 → T010 → T011 → T012; T013 → T014.
- **US2 (T015–T019)** after T013–T014 (preferences and rows). T016 is independent of T015;
  T017 → T018 → T019.
- **US3 (T020–T022)** after T018 (the warp pass). T020 → T021 → T022.
- **US4 (T023–T025)** after T013–T014; independent of US2 and US3. T023 → T025; T024 → T025.
- **Polish (T026–T029)** after the stories it checks: T026 and T027 after T018; T028 any time
  after T018; T029 last.

## Parallel opportunities

- T002 alongside T003.
- T009 (HUD-area test) alongside T005–T008 once T004 is done.
- T016 (shaders) alongside T015.
- US4 (T023, T024) alongside US2 and US3 once T014 is done.
- T028 alongside T026–T027.

## Independent tests per story

| Story | Test |
|---|---|
| US1 | G2, G5; C2 (27" flat ⇒ 53.0°); H1–H4 |
| US2 | G3, G4, G12; C2 (G9 ⇒ 84.0°); smoke shows the warp; hand check items 1–3 |
| US3 | G6, G10, G11; custom-120° scenario; hand check item 4 |
| US4 | plausibility test; C4; detection on a Windows EDID monitor |

## Implementation strategy

1. **MVP**: Setup + Foundational + US1. Flat ultrawide players get physical angles and a 16:9 HUD;
   nothing changes for anyone with matching off.
2. **US2** adds the warp: the curved G9 is exact at the physical angle.
3. **US3** adds custom angles, looks and slices.
4. **US4** adds detection; it can run beside US2/US3.
5. **Polish**: frame rate, hand check, docs, the full run.

Each phase ends on a green `tests/run.sh unit` and `smoke`, so the branch can be merged after any
checkpoint.

## Notes

- T007 exposes two reticle positions to the debug console in debug builds only; if the console
  has no suitable hook, the default is a debug-only `console.__reticlePositions()` style property
  added next to the existing debug methods, removed by nothing (it is a test aid).
- T011: if the smoke run cannot set a window size, the task adds that option first; that is the
  conservative route rather than skipping H3.
