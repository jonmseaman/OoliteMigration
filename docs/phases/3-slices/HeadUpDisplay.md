# Slice plan: HeadUpDisplay

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-9ht.138; umbrella oo-xjm). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/HeadUpDisplay.md`, which recounts the
file every time, so the numbers below are only a snapshot.

- **File:** `Core/HeadUpDisplay.mm` (4,620 lines) + header (428 lines). One class,
  `HeadUpDisplay : OOObject` (~145 units: ~110 methods, the rest file-scope functions), the
  immediate-mode GL HUD: hud.plist parsing into legend / dial / MFD widget lists, ~45 dials
  called by name (`OOCallByName`, ADR-0055 item 5; whitelisted in `hud_dial_methods`), the
  scanner and compass, reticles and waypoints, and the HUD's text engine (`cxx_OODrawString` and
  friends, used by `GuiDisplayGen` and others). Also in the file: the `OOHUDBeaconIcon` protocol's
  two implementers, the category `OOPolygonSprite (OOHUDBeaconIcon)` (on a converted class's
  façade) and the small class `OOHUDBeaconCodeIcon`, both declared in the header. The header
  (428 lines) and preamble (268 lines: includes, the `OOHUDWidget` struct, forward declarations,
  the `HeadUpDisplay (Private)` interface) are charged to every slice, so no slice may own much
  more than ~800 lines.
- **Shape:** six slices. (1) the class shell: `cxx_initWithDictionary:inFile:`, `dealloc`,
  `resetGui*`, every accessor, the widget builders `addLegend:` / `addDial:` / `addMFD:`, the
  scanner flags and `refreshLastTransmitter` (`@HeadUpDisplay` claims every method no later slice
  names); (2) the frame: `renderHUD`, the legend / dial / MFD loops, `drawHUDItem:` (the by-name
  dispatch), crosshairs, legends, MFDs, surrounds, the text engine's Objective-C functions and the
  colour helpers; (3) the scanner with its grid and cascade-weapon drawing; (4) the compass with
  its blips and the beacon icons, aegis, reticles and waypoints; (5) the bars, gauges and custom
  dials; (6) missiles, the status light, the direction cue and the text / indicator dials. GL
  calls are C and stay verbatim inside the converted members (ADR-0012, CLAUDE.md rule 9); the
  27 plain-C helpers (the bar / marker primitives, the string-quad drawing, `DrawSpecialOval`,
  the configuration lookups) are `verbatim:` and no slice reads them.
- **Slice 1 carries the façade.** ~30 files reach the HUD through `[PLAYER hud]`, so slice 1 makes
  `cxx::HeadUpDisplay` (the `@interface` ivars become members; the widget vectors, `oo::PList`
  state and `oo::Ref<OOCrosshairs>` move as they are) and a façade under the old name that copies
  the whole old `@interface` (house style, [ADR-0056](../../decisions/0056-phase3-class-conversion-house-style.md)
  item 5). The units of slices 2-6 stay Objective-C until their own story, as categories of the
  façade that read the state through `oo::ToCxx(self)->` (the class-shell rule of amendment
  oo-pni4, and in-place per-slice categories as amendment oo-dnbf item 2 does for `OOMesh`).
- **Dials are called by name.** `drawHUDItem:` sends the dial's whitelisted selector with
  `OOCallByName`, and `addDial:` checks `respondsToSelector:`. Recommended default: the façade
  keeps answering every dial selector until the façade is deleted. Slice 2 converts
  `drawHUDItem` to call `OOCallByName(oo::ToObjC(this), selector, info)`; each dial slice turns
  its dials into `cxx::HeadUpDisplay` members and leaves a one-line forwarder per dial in
  `HeadUpDisplay+ObjCBridge.mm`. Replacing the by-name dispatch with a C++ table of member
  pointers is the "Delete HeadUpDisplay+ObjCBridge" bead's work, not a slice's (no redesign
  during conversion).
- **Free functions that message unconverted classes.** `--slice-done` exempts converted members
  but not free functions, and 15 of the file's file-scope functions send messages:
  `GetCurrentCachedInfo` / `ReticleColorAt` raise (`OORaiseException`, amendment oo-dqxj item 1);
  the colour helpers, text engine and missile icons message converted `OOColor` / `OOTexture` / `OOPolygonSprite` and the cascade weapon `+[HeadUpDisplay nonlinearScannerScale:…]`, which slice 1 makes `cxx::` (`oo::ToCxx`); and
  `hudDrawReticleOnTarget`, `hudDrawWaypoint`, `hudRotateViewpointForVirtualDepth`,
  `MissileIconDefinition`, `drawScannerGrid`, `OODrawPlanetInfo` message the player, the universe
  and ships. Those sends go behind one-line functions in `HeadUpDisplay+ObjCBridge.mm`
  (ADR-0056 amendment oo-9ht.139, filed with the `OOJSShip` plan), so the HUD's slices wait for
  none of `Universe`, `PlayerEntity` or `ShipEntity`; the façade's deletion bead then waits for
  them.
- **The beacon icons** (slice 4): `OOPolygonSprite (OOHUDBeaconIcon)` is a category on a
  converted class's façade, so its body becomes a free function and the category stays as a
  one-line forwarder in the bridge (amendments oo-6ia4 item 3, oo-9fwb). `OOHUDBeaconCodeIcon`
  and the `OOHUDBeaconIcon` protocol are held by the entities' beacon drawables (`ShipEntity`,
  `OOWaypointEntity`, `OOVisualEffectEntity`): follow amendments oo-jpd8 and oo-4nhg (a protocol
  declared with the class; a class another class holds by its protocol).
- **Tests:** `tests/unit/core/test_HeadUpDisplay.mm`, written by slice 1 against the Objective-C
  API and run on the unconverted class first: construction from a dictionary, the accessors,
  hidden selectors, reticle colours, crosshair definitions and the dial whitelist (stand-ins for
  the player, universe and resource manager, amendment oo-z1s4 item 4; GL drawing is not
  pinned in a unit test, amendment oo-z1s4 on GL tests). Later slices extend it where they have
  observable non-GL behaviour; the goldens pin the drawing.
- **Order:** after the module pattern seam and the entity seam (oo-bj8, as oo-xjm had). Slice 1
  first; slices 2-6 are then independent of each other. oo-xjm ("Convert HeadUpDisplay") is the
  umbrella: it depends on the six slices; its acceptance is every slice's `--slice-done` plus
  guardrails. The "Delete HeadUpDisplay+ObjCBridge" bead (filed by slice 1, as oo-9ht.1 was for
  `OOColor`) waits on the callers' conversions (`PlayerEntity`, oo-a70, among them).

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell: init / `dealloc` / `resetGuis`, accessors, hidden selectors, reticle colours, widget builders, scanner flags; the façade | ~695 | ~1,390 |
| 2 | the frame: `renderHUD`, legend / dial / MFD loops, `drawHUDItem:`, crosshairs, legends, MFDs, surrounds, text engine, colour helpers | ~615 | ~1,310 |
| 3 | scanner, zoom indicator, scanner grid, cascade weapon | ~570 | ~1,265 |
| 4 | compass and blips, beacon icons, aegis, target reticles and waypoints | ~680 | ~1,375 |
| 5 | speed / roll / pitch / yaw bars, energy and shield gauges, fuel, temperatures, altitude, custom dials | ~700 | ~1,395 |
| 6 | missile display and icons, status light, direction cue, clock, primed equipment, ASC, FPS, scoop, stick sensitivity, trumbles | ~680 | ~1,375 |
| verbatim | plain-C helpers and string-drawing primitives | — | not read |

```slice-plan
source: upstream/oolite/src/Core/HeadUpDisplay.mm
header: upstream/oolite/src/Core/HeadUpDisplay.h

slice 1: class shell: lifecycle, configuration, widgets, state and accessors
  @HeadUpDisplay
  GetCurrentCachedInfo()
  ReticleColorAt()

slice 2: the frame: render dispatch, legends, crosshairs, MFDs, surrounds, text engine, colours
  -[HeadUpDisplay renderHUD]
  -[HeadUpDisplay drawLegends]
  -[HeadUpDisplay drawDials]
  -[HeadUpDisplay drawMFDs]
  -[HeadUpDisplay drawHUDItem:]
  -[HeadUpDisplay drawCrosshairs]
  -[HeadUpDisplay cxx_setCrosshairDefinition:]
  -[HeadUpDisplay crosshairDefinitionForWeaponType:]
  -[HeadUpDisplay drawLegend:]
  -[HeadUpDisplay drawMultiFunctionDisplay:withText:asIndex:]
  -[HeadUpDisplay drawSurround*]
  -[HeadUpDisplay drawGreenSurround:]
  -[HeadUpDisplay drawYellowSurround:]
  InitTextEngine()
  OOStartDrawingStrings()
  OOStopDrawingStrings()
  OODrawPlanetInfo()
  SetGLColourFromInfo()
  GetRGBAArrayFromInfo()

slice 3: scanner
  -[HeadUpDisplay drawScanner:]
  -[HeadUpDisplay drawScannerZoomIndicator:]
  drawScannerGrid()
  GLDrawNonlinearCascadeWeapon()

slice 4: compass and beacon icons, aegis, reticles, waypoints
  -[HeadUpDisplay drawCompass*]
  @OOPolygonSprite(OOHUDBeaconIcon)
  OOPolygonSpriteDrawHUDBeaconIcon()   # that category's body as a free function (amendments oo-6ia4 item 3, oo-9fwb)
  @OOHUDBeaconCodeIcon
  -[HeadUpDisplay drawAegis:]
  -[HeadUpDisplay drawTargetReticle:]
  -[HeadUpDisplay drawSecondaryTargetReticle:]
  -[HeadUpDisplay drawWaypoints:]
  hudDrawReticleOnTarget()
  hudDrawWaypoint()
  hudRotateViewpointForVirtualDepth()

slice 5: bars and gauges, custom dials
  -[HeadUpDisplay drawCustom*]
  -[HeadUpDisplay drawSpeedBar:]
  -[HeadUpDisplay drawRollBar:]
  -[HeadUpDisplay drawPitchBar:]
  -[HeadUpDisplay drawYawBar:]
  -[HeadUpDisplay drawEnergyGauge:]
  -[HeadUpDisplay drawForwardShieldBar:]
  -[HeadUpDisplay drawAftShieldBar:]
  -[HeadUpDisplay drawFuelBar:]
  -[HeadUpDisplay drawWitchspaceDestination:]
  -[HeadUpDisplay drawCabinTempBar:]
  -[HeadUpDisplay drawWeaponTempBar:]
  -[HeadUpDisplay drawAltitudeBar:]

slice 6: missiles, status light, direction cue, text and indicator dials
  MissileIconDefinition()
  IconForMissileRole()
  -[HeadUpDisplay drawIconForMissile:selected:status:x:y:width:height:alpha:]
  -[HeadUpDisplay drawIconForEmptyPylonAtX:y:width:height:alpha:]
  -[HeadUpDisplay drawMissileDisplay:]
  -[HeadUpDisplay drawStatusLight:]
  -[HeadUpDisplay drawDirectionCue:]
  -[HeadUpDisplay drawClock:]
  -[HeadUpDisplay drawPrimedEquipment:]
  -[HeadUpDisplay drawASCTarget:]
  -[HeadUpDisplay drawWeaponsOfflineText:]
  -[HeadUpDisplay drawFPSInfoCounter:]
  -[HeadUpDisplay drawScoopStatus:]
  -[HeadUpDisplay drawStickSensitivityIndicator:]
  -[HeadUpDisplay drawTrumbles:]

verbatim: plain C/C++ helpers and the string-drawing primitives, no Objective-C (checked)
  AddHUDWidget()
  ReleaseHUDWidgets()
  OptionalStringIn()
  PListForKeyIn()
  OptionalStringAt()
  useDefined()
  GLColorWithOverallAlpha()
  prefetchData()
  SetCompassBlipColor()
  hudDraw*At()
  ConvertedString()
  OOHUDResetTextEngine()
  drawCharacterQuad()
  cxx_OO*()
  drawHighlight()
  OODrawHilightedPlanetInfo()
  nonlinearScannerFunc()
  DrawSpecialOval()
```
