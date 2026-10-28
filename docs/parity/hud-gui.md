# Parity findings: HUD, GUI, crosshairs

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## GuiDisplayGen

<a id="guidisplaygen"></a>
Upstream `src/Core/GuiDisplayGen.m` ↔ `Core/GuiDisplayGen.cpp`

**Status:** done — 88 rows: 84 ✅ 2 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `RowInRange()` (42) | `RowInRange` `Core/GuiDisplayGen.cpp:49` | ✅ |
| `-[GuiDisplayGen init]` (65) | `GuiDisplayGen()` `Core/GuiDisplayGen.cpp:175` | ✅ |
| `-[GuiDisplayGen initWithPixelSize:]` (115) | `GuiDisplayGen(NSSize,…)` `Core/GuiDisplayGen.cpp:221` | ✅ |
| `-[GuiDisplayGen dealloc]` (160) | `~GuiDisplayGen() = default` `Core/GuiDisplayGen.cpp:261` (Refs release) | ✅ |
| `-[GuiDisplayGen resizeWithPixelSize:]` (175) | `resizeWithPixelSize` `Core/GuiDisplayGen.cpp:263` | ✅ |
| `-[GuiDisplayGen resizeTo:]` (200) | `resizeTo` `Core/GuiDisplayGen.cpp:288` | ✅ |
| `-[GuiDisplayGen size]` (244) | `size` `Core/GuiDisplayGen.cpp:332` | ✅ |
| `-[GuiDisplayGen columns]` (249) | `columns` `Core/GuiDisplayGen.cpp:337` | ✅ |
| `-[GuiDisplayGen rows]` (254) | `rows` `Core/GuiDisplayGen.cpp:342` | ✅ |
| `-[GuiDisplayGen rowHeight]` (259) | `rowHeight` `Core/GuiDisplayGen.cpp:347` | ✅ |
| `-[GuiDisplayGen rowStart]` (264) | `rowStart` `Core/GuiDisplayGen.cpp:352` | ✅ |
| `-[GuiDisplayGen title]` (269) | `getTitle` `Core/GuiDisplayGen.cpp:357` | ✅ |
| `-[GuiDisplayGen setTitle:]` (274) | `setTitle` + `TitleFrom` `Core/GuiDisplayGen.cpp:362`, `:69` | ✅ |
| `-[GuiDisplayGen setDrawPosition:]` (284) | `setDrawPosition` `Core/GuiDisplayGen.cpp:367` | ✅ |
| `-[GuiDisplayGen drawPosition]` (289) | `getDrawPosition` `Core/GuiDisplayGen.cpp:372` | ✅ |
| `-[GuiDisplayGen userSettings]` (294) | `userSettings` `Core/GuiDisplayGen.cpp:377` (by value) | ✅ |
| `-[GuiDisplayGen fadeOutFromTime:overDuration:]` (299) | `fadeOutFromTime` `Core/GuiDisplayGen.cpp:382` | ✅ |
| `-[GuiDisplayGen stopFadeOuts]` (310) | `stopFadeOuts` `Core/GuiDisplayGen.cpp:393` | ✅ |
| `-[GuiDisplayGen alpha]` (315) | `alpha` `Core/GuiDisplayGen.cpp:398` | ✅ |
| `-[GuiDisplayGen setAlpha:]` (320) | `setAlpha` `Core/GuiDisplayGen.cpp:403` | ✅ |
| `-[GuiDisplayGen setMaxAlpha:]` (325) | `setMaxAlpha` `Core/GuiDisplayGen.cpp:408` | ✅ |
| `-[GuiDisplayGen setBackgroundColor:]` (330) | `setBackgroundColor` `Core/GuiDisplayGen.cpp:413` | ✅ |
| `-[GuiDisplayGen textColor]` (336) | `getTextColor` `Core/GuiDisplayGen.cpp:418` | ✅ |
| `-[GuiDisplayGen setTextColor:]` (342) | `setTextColor` `Core/GuiDisplayGen.cpp:424` | ✅ |
| `-[GuiDisplayGen textCommsColor]` (350) | `getTextCommsColor` `Core/GuiDisplayGen.cpp:432` | ✅ |
| `-[GuiDisplayGen setTextCommsColor:]` (355) | `setTextCommsColor` `Core/GuiDisplayGen.cpp:437` | ✅ |
| `-[GuiDisplayGen colorFromSetting:defaultValue:]` (363) | `colorFromSetting` `Core/GuiDisplayGen.cpp:445` | ✅ |
| `-[GuiDisplayGen setGLColorFromSetting:defaultValue:alpha:]` (381) | `setGLColorFromSetting` `Core/GuiDisplayGen.cpp:464` | ✅ |
| `-[GuiDisplayGen setGuiColorSettingFromKey:color:]` (390) | `setGuiColorSettingFromKey` `Core/GuiDisplayGen.cpp:473` | ✅ |
| `-[GuiDisplayGen setCharacterSize:]` (403) | `setCharacterSize` `Core/GuiDisplayGen.cpp:486` | ✅ |
| `-[GuiDisplayGen setShowAdvancedNavArray:]` (408) | `setShowAdvancedNavArray` `Core/GuiDisplayGen.cpp:491` | ✅ |
| `-[GuiDisplayGen setColor:forRow:]` (413) | `setColor` `Core/GuiDisplayGen.cpp:496` | ✅ |
| `-[GuiDisplayGen objectForRow:]` (419) | `objectForRow` `Core/GuiDisplayGen.cpp:502` | ✅ |
| `-[GuiDisplayGen rowForKey:]` (427) | `rowForKey` `Core/GuiDisplayGen.cpp:510` | ✅ |
| `-[GuiDisplayGen keyForRow:]` (437) | `keyForRow` `Core/GuiDisplayGen.cpp:522` | ✅ |
| `-[GuiDisplayGen selectedRow]` (445) | `getSelectedRow` `Core/GuiDisplayGen.cpp:530` | ✅ |
| `-[GuiDisplayGen setSelectedRow:]` (453) | `setSelectedRow` + `IsSkipKey` `Core/GuiDisplayGen.cpp:538`, `:77` | ✅ |
| `-[GuiDisplayGen setNextRow:]` (468) | `setNextRow` `Core/GuiDisplayGen.cpp:553` | ✅ |
| `-[GuiDisplayGen setFirstSelectableRow]` (482) | `setFirstSelectableRow` `Core/GuiDisplayGen.cpp:567` | ✅ |
| `-[GuiDisplayGen setLastSelectableRow]` (497) | `setLastSelectableRow` `Core/GuiDisplayGen.cpp:582` | ✅ |
| `-[GuiDisplayGen reportSelectedRow:]` (512) | `reportSelectedRow` `Core/GuiDisplayGen.cpp:597` | ✅ |
| `-[GuiDisplayGen setNoSelectedRow]` (517) | `setNoSelectedRow` `Core/GuiDisplayGen.cpp:613` | ✅ |
| `-[GuiDisplayGen selectedRowText]` (522) | `selectedRowText` `Core/GuiDisplayGen.cpp:618` | ✅ |
| `-[GuiDisplayGen selectedRowKey]` (531) | `selectedRowKey` `Core/GuiDisplayGen.cpp:631` | ⚠️ |
| `-[GuiDisplayGen setShowTextCursor:]` (539) | `setShowTextCursor` `Core/GuiDisplayGen.cpp:640` | ✅ |
| `-[GuiDisplayGen setCurrentRow:]` (544) | `setCurrentRow` `Core/GuiDisplayGen.cpp:645` | ✅ |
| `-[GuiDisplayGen selectableRange]` (554) | `getSelectableRange` `Core/GuiDisplayGen.cpp:655` | ✅ |
| `-[GuiDisplayGen setSelectableRange:]` (559) | `setSelectableRange` `Core/GuiDisplayGen.cpp:660` | ✅ |
| `-[GuiDisplayGen setTabStops:]` (564) | `setTabStops` `Core/GuiDisplayGen.cpp:665` | ✅ |
| `-[GuiDisplayGen overrideTabs:from:length:]` (570) | `overrideTabs` `Core/GuiDisplayGen.cpp:671` | ✅ |
| `-[GuiDisplayGen clear]` (584) | `clear` `Core/GuiDisplayGen.cpp:685` | ✅ |
| `-[GuiDisplayGen clearAndKeepBackground:]` (589) | `clearAndKeepBackground` `Core/GuiDisplayGen.cpp:690` | ✅ |
| `-[GuiDisplayGen setKey:forRow:]` (607) | `setKey` `Core/GuiDisplayGen.cpp:708` | ✅ |
| `-[GuiDisplayGen setText:forRow:]` (613) | `setText(str,row)` `Core/GuiDisplayGen.cpp:714` | ✅ |
| `-[GuiDisplayGen setText:forRow:align:]` (620) | `setText(str,row,align)` `Core/GuiDisplayGen.cpp:721` | ✅ |
| `-[GuiDisplayGen addLongText:]` (628) | `addLongText` + `WordsJoinedBySpace` `Core/GuiDisplayGen.cpp:742`, `:57` | ✅ |
| `-[GuiDisplayGen reflowTextForMFD:]` (666) | `reflowTextForMFD` `Core/GuiDisplayGen.cpp:781` | ✅ |
| `-[GuiDisplayGen leaveLastLine]` (697) | `leaveLastLine` `Core/GuiDisplayGen.cpp:815` | ✅ |
| `-[GuiDisplayGen getLastLines]` (710) | `getLastLines` `Core/GuiDisplayGen.cpp:828` | ✅ |
| `-[GuiDisplayGen printLongText:]` (736) | `printLongText` `Core/GuiDisplayGen.cpp:864` | ✅ |
| `-[GuiDisplayGen printLineNoScroll:]` (797) | `printLineNoScroll` `Core/GuiDisplayGen.cpp:926` | ⚠️ |
| `-[GuiDisplayGen setArray:forRow:]` (814) | `setArray(vector<string>)` `Core/GuiDisplayGen.cpp:943` | ✅ |
| `-[GuiDisplayGen insertItemsFromArray:]` (820) | `insertItemsFromArray` `Core/GuiDisplayGen.cpp:953` | ❌ |
| `-[GuiDisplayGen scrollUp:]` (863) | `scrollUp` `Core/GuiDisplayGen.cpp:1003` | ✅ |
| `-[GuiDisplayGen clearBackground]` (882) | `clearBackground` `Core/GuiDisplayGen.cpp:1022` | ✅ |
| `TextureForGUITexture()` (888) | `TextureForGUITexture` + `DescriptorName` `Core/GuiDisplayGen.cpp:108`, `:100` | ✅ |
| `NewTextureSpriteWithDescriptor()` (912) | `NewTextureSpriteWithDescriptor` `Core/GuiDisplayGen.cpp:131` | ✅ |
| `-[GuiDisplayGen setBackgroundTextureSpecial:withBackground:]` (952) | `setBackgroundTextureSpecial` `Core/GuiDisplayGen.cpp:1028` | ✅ |
| `-[GuiDisplayGen setBackgroundTextureDescriptor:]` (1003) | `setBackgroundTextureDescriptor` `Core/GuiDisplayGen.cpp:1079` | ✅ |
| `-[GuiDisplayGen setForegroundTextureDescriptor:]` (1011) | `setForegroundTextureDescriptor` `Core/GuiDisplayGen.cpp:1086` | ✅ |
| `-[GuiDisplayGen setBackgroundTextureKey:]` (1020) | `setBackgroundTextureKey` `Core/GuiDisplayGen.cpp:1094` | ✅ |
| `-[GuiDisplayGen setForegroundTextureKey:]` (1025) | `setForegroundTextureKey` `Core/GuiDisplayGen.cpp:1099` | ✅ |
| `-[GuiDisplayGen preloadGUITexture:]` (1030) | `preloadGUITexture` `Core/GuiDisplayGen.cpp:1104` | ✅ |
| `-[GuiDisplayGen textureDescriptorFromJSValue:]` (1035) | `textureDescriptorFromJSValue` `Core/GuiDisplayGen.cpp:1109` | ✅ |
| `-[GuiDisplayGen setStatusPage:]` (1076) | `setStatusPage` `Core/GuiDisplayGen.cpp:1150` | ✅ |
| `-[GuiDisplayGen statusPage]` (1085) | `getStatusPage` `Core/GuiDisplayGen.cpp:1159` | ✅ |
| `-[GuiDisplayGen drawEquipmentList:z:]` (1090) | `drawEquipmentList` `Core/GuiDisplayGen.cpp:1164` | ✅ |
| `-[GuiDisplayGen drawGUIBackground]` (1209) | `drawGUIBackground` `Core/GuiDisplayGen.cpp:1291` | ✅ |
| `-[GuiDisplayGen refreshStarChart]` (1220) | `refreshStarChart` `Core/GuiDisplayGen.cpp:1302` | ✅ |
| `-[GuiDisplayGen drawGUI:drawCursor:]` (1225) | `drawGUI` (+ `rowAtVirtualJoystickPosition` :729) `Core/GuiDisplayGen.cpp:1307` | ✅ |
| `-[GuiDisplayGen drawGLDisplay:y:z:alpha:]` (1308) | `drawGLDisplay` + `TrimmedForHighlight` `Core/GuiDisplayGen.cpp:1392`, `:84` | ✅ |
| `-[GuiDisplayGen drawCrossHairsWithSize:x:y:z:]` (1517) | `drawCrossHairsWithSize` `Core/GuiDisplayGen.cpp:1602` | ✅ |
| `-[GuiDisplayGen setStarChartTitle]` (1531) | `setStarChartTitle` `Core/GuiDisplayGen.cpp:1616` | ❌ |
| `-[GuiDisplayGen drawStarChart:y:z:alpha:compact:]` (1550) | `drawStarChart` `Core/GuiDisplayGen.cpp:1899` | ✅ |
| `-[GuiDisplayGen drawSystemMarkers:atX:andY:andZ:withAlpha:andScale:]` (2060) | `drawSystemMarkers` `Core/GuiDisplayGen.cpp:1635` | ✅ |
| `-[GuiDisplayGen drawSystemMarker:atX:andY:andZ:withAlpha:andScale:]` (2068) | `drawSystemMarker` `Core/GuiDisplayGen.cpp:1645` | ✅ |
| `-[GuiDisplayGen targetNextFoundSystem:]` (2119) | `targetNextFoundSystem` `Core/GuiDisplayGen.cpp:1697` | ✅ |
| `-[GuiDisplayGen drawAdvancedNavArrayAtX:y:z:alpha:usingRoute:optimizedBy:zoom:]` (2164) | `drawAdvancedNavArrayAtX` `Core/GuiDisplayGen.cpp:1742` | ✅ |

**Differences:**

- ❌ **low** — `setStarChartTitle` tests whether a title key exists with `descriptionForKey` (i.e. `chooseStringForKey`) instead of `[[UNIVERSE descriptions] valueForKey:]`. If the entry is an array, the port draws an extra `Ranrot()` (shifting the game RNG stream) on each call. If the entry is a non-string/non-array value or an empty array, upstream sets no title (nil), while the port falls back to the galaxy or default title. The stock `descriptions.plist` holds only strings, so the stock game is unaffected — upstream `Core/GuiDisplayGen.m:1538` ↔ port `Core/GuiDisplayGen.cpp:1623` (cf. `Core/Universe.m:9668`)
- ❌ **low** — `insertItemsFromArray`: when a row item is an array, the port keeps only its string elements. A number column is dropped and later columns move to earlier tab stops, whereas upstream kept the number and `drawGLDisplay` drew it via `oo_stringAtIndex:`. A non-string `item_keys` entry also becomes its string value. Neither tree has a caller, so this cannot be observed today — upstream `Core/GuiDisplayGen.m:852` ↔ port `Core/GuiDisplayGen.cpp:986`
- ⚠️ **low** — `selectedRowKey`: the bound is corrected from `> count` to `>= count` (comment at cpp:633). Upstream raised `NSRangeException` when `selectedRow == count`; the port returns nullopt — upstream `Core/GuiDisplayGen.m:533` ↔ port `Core/GuiDisplayGen.cpp:634`
- ⚠️ **low** — `printLineNoScroll` with a nil string: upstream's `[text_array addObject:nil]` raised; the port skips the append (comment at cpp:938) — upstream `Core/GuiDisplayGen.m:809` ↔ port `Core/GuiDisplayGen.cpp:938`
- ✅ (subtle) — `drawStarChart` chart text row: `+arrayWithObjects:` stopped at a nil `targetName`/`OOExpandKey` result and left the row empty. The port substitutes `""`, so the distance and time columns still draw. This only happens if `getSystemName:`/expansion return nil, which cannot happen for a valid target with stock descriptions — upstream `Core/GuiDisplayGen.m:2015-2034` ↔ port `Core/GuiDisplayGen.cpp:2359-2378`
- ✅ (subtle) — `setColor:forRow:` with a nil colour: upstream's `replaceObjectAtIndex:withObject:nil` raised, while the port stores null and `drawGLDisplay` draws it black (cpp:1485). No caller can pass nil (`textColor` and `colorFromSetting` are never nil) — upstream `Core/GuiDisplayGen.m:416` ↔ port `Core/GuiDisplayGen.cpp:499`
- ✅ (subtle) — `colorFromSetting` returns the shared colour, not a `-copy` (comment at cpp:461). `setGuiColorSettingFromKey` edits the dictionary in place rather than swapping in a new one. OOColor is immutable and `userSettings()` returns by value, so neither change is observable — port `Core/GuiDisplayGen.cpp:461`, `:476`
- ⚠️ (port-only) — `rowAtVirtualJoystickPosition` (bead oo-3rb.348) is the y half of `drawGUI`'s cursor maths, unchanged (same clamps, `1 + (float)floor(...)`), and `drawGUI` now gets its `cursor_row` from it, so the result is identical. `GuiDisplayGenUniverseUseShaders` is a one-line bridge for `[UNIVERSE useShaders]` — port `Core/GuiDisplayGen.cpp:729`, `:1364`, `:2404`
- ✅ (emphasis checks, all matched line by line):
  - **Layout:** default tab stops `{0,192,256,320,384,448}`; chart tabs `{0,96,288}` with the `chart_traveltime_tabs` override, clamped to `GUI_MAX_COLUMNS` and read as unsigned; `n_columns`/`n_rows`/`pixel_row_start` formulas in `resizeTo`; title size `1.75×/1.5×` the row height; 18×20 text on the main GUI.
  - **Text:** wrap/scroll in `addLongText`/`printLongText`/`reflowTextForMFD` (15-char MFD limit); 42→40+"..." equipment-name truncation in UTF-16 units.
  - **Rows:** `SKIP-ROW`/`OK` keys, first/last selectable row walk; highlight trim of `' '`/`'\037'` with the empty-trim → whole-text fallback.
  - **Textures:** sRGBA background; foreground sRGBA only with HDR; width/height aspect fallback; long-range fallback order `long_range_chart%d_mission` → `long_range_chart_mission` → `long_range_chart%d` → `long_range_chart`.
  - **Default colours:** title red; divider white 0.75; selected row bg red / fg black; text cursor red; range/crosshair green; chart cursor red; match box green; match label cyan; labels yellow; info marker blue; route short yellow / quick cyan; connection white 0.25; jump start/end white 0.25 α0.
  - **Star colours:** `govcol` table; economy `1−0.125·eco`; tech `0.6, 0.2+0.05·tec`; sun colour with α reset to 1; nova grey 0.3 or (1, 0.2, 0); no-data grey 0.7; blob `0.0017` factor with 0.5 floor; marker clamp 0.5–2 and ×1.4 for plus/diamond; all GUI setting key strings identical (`GuiDisplayGen.h`).


## HeadUpDisplay

<a id="headupdisplay"></a>
Upstream `src/Core/HeadUpDisplay.m` ↔ `Core/HeadUpDisplay.cpp`

**Status:** done — 139 rows: 133 ✅ 0 ⚠️ 2 ❌ 4 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `useDefined()` (80) | `useDefined` `Core/HeadUpDisplay.cpp:224` | ✅ |
| `GLColorWithOverallAlpha()` (203) | `GLColorWithOverallAlpha` `Core/HeadUpDisplay.cpp:283` | ✅ |
| `-[HeadUpDisplay initWithDictionary:]` (209) | folded into `HeadUpDisplay::initWithDictionary(info, nullopt)` `Core/HeadUpDisplay.cpp:301` | ➖ |
| `-[HeadUpDisplay initWithDictionary:inFile:]` (214) | `HeadUpDisplay::initWithDictionary` `Core/HeadUpDisplay.cpp:301` | ✅ |
| `-[HeadUpDisplay dealloc]` (323) | `HeadUpDisplay::~HeadUpDisplay` `Core/HeadUpDisplay.cpp:294` | ✅ |
| `-[HeadUpDisplay resetGui:withInfo:]` (342) | `HeadUpDisplay::resetGui` `Core/HeadUpDisplay.cpp:430` | ✅ |
| `-[HeadUpDisplay resetGuiPosition:withInfo:]` (366) | `HeadUpDisplay::resetGuiPosition` `Core/HeadUpDisplay.cpp:454` | ✅ |
| `-[HeadUpDisplay resetGuis:]` (383) | `HeadUpDisplay::resetGuis` `Core/HeadUpDisplay.cpp:465` | ✅ |
| `-[HeadUpDisplay hudName]` (505) | `HeadUpDisplay::getHudName` `Core/HeadUpDisplay.cpp:592` | ✅ |
| `-[HeadUpDisplay setHudName:]` (510) | `HeadUpDisplay::setHudName` `Core/HeadUpDisplay.cpp:597` | ✅ |
| `-[HeadUpDisplay reticleColorForIndex:]` (518) | `HeadUpDisplay::reticleColorForIndex` `Core/HeadUpDisplay.cpp:604` | ✅ |
| `-[HeadUpDisplay setReticleColorForIndex:toColor:]` (526) | `HeadUpDisplay::setReticleColorForIndex` `Core/HeadUpDisplay.cpp:612` | ✅ |
| `-[HeadUpDisplay scannerZoom]` (535) | `HeadUpDisplay::scannerZoom` `Core/HeadUpDisplay.cpp:621` | ✅ |
| `-[HeadUpDisplay setScannerZoom:]` (540) | `HeadUpDisplay::setScannerZoom` `Core/HeadUpDisplay.cpp:626` | ✅ |
| `-[HeadUpDisplay overallAlpha]` (545) | `HeadUpDisplay::getOverallAlpha` `Core/HeadUpDisplay.cpp:631` | ✅ |
| `-[HeadUpDisplay setOverallAlpha:]` (550) | `HeadUpDisplay::setOverallAlpha` `Core/HeadUpDisplay.cpp:636` | ✅ |
| `-[HeadUpDisplay reticleTargetSensitive]` (555) | `HeadUpDisplay::getReticleTargetSensitive` `Core/HeadUpDisplay.cpp:641` | ✅ |
| `-[HeadUpDisplay setReticleTargetSensitive:]` (560) | `HeadUpDisplay::setReticleTargetSensitive` `Core/HeadUpDisplay.cpp:646` | ✅ |
| `-[HeadUpDisplay propertiesReticleTargetSensitive]` (565) | `HeadUpDisplay::getPropertiesReticleTargetSensitive` `Core/HeadUpDisplay.cpp:651` | ✅ |
| `-[HeadUpDisplay isHidden]` (570) | `HeadUpDisplay::isHidden` `Core/HeadUpDisplay.cpp:656` | ✅ |
| `-[HeadUpDisplay setHidden:]` (575) | `HeadUpDisplay::setHidden` `Core/HeadUpDisplay.cpp:661` | ✅ |
| `-[HeadUpDisplay allowBigGui]` (580) | `HeadUpDisplay::getAllowBigGui` `Core/HeadUpDisplay.cpp:666` | ✅ |
| `-[HeadUpDisplay hasHidden:]` (585) | `HeadUpDisplay::hasHidden` `Core/HeadUpDisplay.cpp:671` | ✅ |
| `-[HeadUpDisplay setHiddenSelector:hidden:]` (593) | `HeadUpDisplay::setHiddenSelector` `Core/HeadUpDisplay.cpp:679` | ✅ |
| `-[HeadUpDisplay clearHiddenSelectors]` (602) | `HeadUpDisplay::clearHiddenSelectors` `Core/HeadUpDisplay.cpp:688` | ✅ |
| `-[HeadUpDisplay isCompassActive]` (607) | `HeadUpDisplay::isCompassActive` `Core/HeadUpDisplay.cpp:693` | ✅ |
| `-[HeadUpDisplay setCompassActive:]` (612) | `HeadUpDisplay::setCompassActive` `Core/HeadUpDisplay.cpp:698` | ✅ |
| `-[HeadUpDisplay isUpdating]` (617) | `HeadUpDisplay::isUpdating` `Core/HeadUpDisplay.cpp:703` | ✅ |
| `-[HeadUpDisplay setDeferredHudName:]` (622) | `HeadUpDisplay::setDeferredHudName` `Core/HeadUpDisplay.cpp:708` | ✅ |
| `-[HeadUpDisplay deferredHudName]` (628) | `HeadUpDisplay::getDeferredHudName` `Core/HeadUpDisplay.cpp:713` | ✅ |
| `-[HeadUpDisplay addLegend:]` (633) | `HeadUpDisplay::addLegend` `Core/HeadUpDisplay.cpp:718` | ✅ |
| `-[HeadUpDisplay addDial:]` (675) | `HeadUpDisplay::addDial` `Core/HeadUpDisplay.cpp:756` (+ `kDials`/`DialNamed` :121/:165) | ✅ |
| `-[HeadUpDisplay addMFD:]` (712) | `HeadUpDisplay::addMFD` `Core/HeadUpDisplay.cpp:799` | ✅ |
| `-[HeadUpDisplay mfdCount]` (719) | `HeadUpDisplay::mfdCount` `Core/HeadUpDisplay.cpp:806` | ✅ |
| `-[HeadUpDisplay renderHUD]` (751) | `HeadUpDisplay::renderHUD` `Core/HeadUpDisplay.cpp:916` | ✅ |
| `-[HeadUpDisplay drawLegends]` (776) | `HeadUpDisplay::drawLegends` `Core/HeadUpDisplay.cpp:941` | ✅ |
| `-[HeadUpDisplay drawDials]` (789) | `HeadUpDisplay::drawDials` `Core/HeadUpDisplay.cpp:954` | ✅ |
| `-[HeadUpDisplay drawMFDs]` (810) | `HeadUpDisplay::drawMFDs` `Core/HeadUpDisplay.cpp:976` | ✅ |
| `-[HeadUpDisplay drawCrosshairs]` (823) | `HeadUpDisplay::drawCrosshairs` `Core/HeadUpDisplay.cpp:989` | ✅ |
| `-[HeadUpDisplay crosshairDefinition]` (858) | `HeadUpDisplay::getCrosshairDefinition` `Core/HeadUpDisplay.cpp:811` | ✅ |
| `-[HeadUpDisplay setCrosshairDefinition:]` (863) | `HeadUpDisplay::setCrosshairDefinition` `Core/HeadUpDisplay.cpp:1020` | ✅ |
| `-[HeadUpDisplay crosshairDefinitionForWeaponType:]` (885) | `HeadUpDisplay::crosshairDefinitionForWeaponType` `Core/HeadUpDisplay.cpp:1035` | ✅ |
| `-[HeadUpDisplay drawLegend:]` (926) | `HeadUpDisplay::drawLegend` `Core/HeadUpDisplay.cpp:1073` | ✅ |
| `-[HeadUpDisplay drawHUDItem:]` (989) | `HeadUpDisplay::drawHUDItem` `Core/HeadUpDisplay.cpp:1136` | ✅ |
| `-[HeadUpDisplay checkPlayerInFlight]` (1025) | `HeadUpDisplay::checkPlayerInFlight` `Core/HeadUpDisplay.cpp:816` | ✅ |
| `-[HeadUpDisplay checkPlayerInSystemFlight]` (1030) | `HeadUpDisplay::checkPlayerInSystemFlight` `Core/HeadUpDisplay.cpp:821` | ✅ |
| `prefetchData()` (1040) | `prefetchData` `Core/HeadUpDisplay.cpp:3122` | ✅ |
| `-[HeadUpDisplay drawScanner:]` (1053) | `HeadUpDisplay::drawScanner` `Core/HeadUpDisplay.cpp:1289` | ✅ |
| `-[HeadUpDisplay minimalisticScanner]` (1358) | `HeadUpDisplay::minimalisticScanner` `Core/HeadUpDisplay.cpp:831` | ✅ |
| `-[HeadUpDisplay setMinimalisticScanner:]` (1363) | `HeadUpDisplay::setMinimalisticScanner` `Core/HeadUpDisplay.cpp:836` | ✅ |
| `+[HeadUpDisplay nonlinearScannerScale:Zoom:Scale:]` (1368) | `HeadUpDisplay::nonlinearScannerScale` `Core/HeadUpDisplay.cpp:841` | ✅ |
| `-[HeadUpDisplay nonlinearScanner]` (1375) | `HeadUpDisplay::nonlinearScanner` `Core/HeadUpDisplay.cpp:848` | ✅ |
| `-[HeadUpDisplay setNonlinearScanner:]` (1380) | `HeadUpDisplay::setNonlinearScanner` `Core/HeadUpDisplay.cpp:853` | ✅ |
| `-[HeadUpDisplay scannerUltraZoom]` (1385) | `HeadUpDisplay::scannerUltraZoom` `Core/HeadUpDisplay.cpp:858` | ✅ |
| `-[HeadUpDisplay setScannerUltraZoom:]` (1390) | `HeadUpDisplay::setScannerUltraZoom` `Core/HeadUpDisplay.cpp:863` | ✅ |
| `-[HeadUpDisplay refreshLastTransmitter]` (1395) | `HeadUpDisplay::refreshLastTransmitter` `Core/HeadUpDisplay.cpp:868` | ✅ |
| `-[HeadUpDisplay drawScannerZoomIndicator:]` (1405) | `HeadUpDisplay::drawScannerZoomIndicator` `Core/HeadUpDisplay.cpp:1588` | ✅ |
| `-[HeadUpDisplay drawCompass:]` (1452) | `HeadUpDisplay::drawCompass` `Core/HeadUpDisplay.cpp:1636` | ✅ |
| `SetCompassBlipColor()` (1552) | `SetCompassBlipColor` `Core/HeadUpDisplay.cpp:3135` | ✅ |
| `-[HeadUpDisplay drawCompassPlanetBlipAt:Size:Alpha:]` (1561) | `HeadUpDisplay::drawCompassPlanetBlipAt` `Core/HeadUpDisplay.cpp:3144` | ✅ |
| `-[HeadUpDisplay drawCompassStationBlipAt:Size:Alpha:]` (1574) | `HeadUpDisplay::drawCompassStationBlipAt` `Core/HeadUpDisplay.cpp:3157` | ✅ |
| `-[HeadUpDisplay drawCompassSunBlipAt:Size:Alpha:]` (1586) | `HeadUpDisplay::drawCompassSunBlipAt` `Core/HeadUpDisplay.cpp:3169` | ✅ |
| `-[HeadUpDisplay drawCompassTargetBlipAt:Size:Alpha:]` (1596) | `HeadUpDisplay::drawCompassTargetBlipAt` `Core/HeadUpDisplay.cpp:3179` | ✅ |
| `-[HeadUpDisplay drawCompassBeaconBlipAt:Size:Alpha:]` (1610) | `HeadUpDisplay::drawCompassBeaconBlipAt` `Core/HeadUpDisplay.cpp:3193` | ✅ |
| `-[HeadUpDisplay drawAegis:]` (1638) | `HeadUpDisplay::drawAegis` `Core/HeadUpDisplay.cpp:1738` | ✅ |
| `-[HeadUpDisplay drawCustomBar:]` (1688) | `HeadUpDisplay::drawCustomBar` `Core/HeadUpDisplay.cpp:1844` | ✅ |
| `-[HeadUpDisplay drawCustomText:]` (1724) | `HeadUpDisplay::drawCustomText` `Core/HeadUpDisplay.cpp:1880` | ✅ |
| `-[HeadUpDisplay drawCustomIndicator:]` (1750) | `HeadUpDisplay::drawCustomIndicator` `Core/HeadUpDisplay.cpp:1906` | ✅ |
| `-[HeadUpDisplay drawCustomLight:]` (1779) | `HeadUpDisplay::drawCustomLight` `Core/HeadUpDisplay.cpp:1935` | ✅ |
| `-[HeadUpDisplay drawCustomImage:]` (1813) | `HeadUpDisplay::drawCustomImage` `Core/HeadUpDisplay.cpp:1972` | ✅ |
| `-[HeadUpDisplay drawSpeedBar:]` (1856) | `HeadUpDisplay::drawSpeedBar` `Core/HeadUpDisplay.cpp:2015` | ✅ |
| `-[HeadUpDisplay drawRollBar:]` (1892) | `HeadUpDisplay::drawRollBar` `Core/HeadUpDisplay.cpp:2051` | ✅ |
| `-[HeadUpDisplay drawPitchBar:]` (1919) | `HeadUpDisplay::drawPitchBar` `Core/HeadUpDisplay.cpp:2078` | ✅ |
| `-[HeadUpDisplay drawYawBar:]` (1946) | `HeadUpDisplay::drawYawBar` `Core/HeadUpDisplay.cpp:2105` | ✅ |
| `-[HeadUpDisplay drawEnergyGauge:]` (1974) | `HeadUpDisplay::drawEnergyGauge` `Core/HeadUpDisplay.cpp:2133` | ✅ |
| `-[HeadUpDisplay drawForwardShieldBar:]` (2045) | `HeadUpDisplay::drawForwardShieldBar` `Core/HeadUpDisplay.cpp:2204` | ✅ |
| `-[HeadUpDisplay drawAftShieldBar:]` (2079) | `HeadUpDisplay::drawAftShieldBar` `Core/HeadUpDisplay.cpp:2238` | ✅ |
| `-[HeadUpDisplay drawFuelBar:]` (2113) | `HeadUpDisplay::drawFuelBar` `Core/HeadUpDisplay.cpp:2272` | ✅ |
| `-[HeadUpDisplay drawWitchspaceDestination:]` (2154) | `HeadUpDisplay::drawWitchspaceDestination` `Core/HeadUpDisplay.cpp:2313` | ✅ |
| `-[HeadUpDisplay drawCabinTempBar:]` (2188) | `HeadUpDisplay::drawCabinTempBar` `Core/HeadUpDisplay.cpp:2347` | ✅ |
| `-[HeadUpDisplay drawWeaponTempBar:]` (2229) | `HeadUpDisplay::drawWeaponTempBar` `Core/HeadUpDisplay.cpp:2388` | ✅ |
| `-[HeadUpDisplay drawAltitudeBar:]` (2262) | `HeadUpDisplay::drawAltitudeBar` `Core/HeadUpDisplay.cpp:2421` | ✅ |
| `IconForMissileRole()` (2308) | `IconForMissileRole` `Core/HeadUpDisplay.cpp:2478` (+ `MissileIconDefinition` :2472) | ✅ |
| `-[HeadUpDisplay drawIconForMissile:]` (2348) | `HeadUpDisplay::drawIconForMissile` `Core/HeadUpDisplay.cpp:2521` | ✅ |
| `-[HeadUpDisplay drawIconForEmptyPylonAtX:y:]` (2401) | `HeadUpDisplay::drawIconForEmptyPylonAtX` `Core/HeadUpDisplay.cpp:2570` | ✅ |
| `-[HeadUpDisplay drawMissileDisplay:]` (2417) | `HeadUpDisplay::drawMissileDisplay` `Core/HeadUpDisplay.cpp:2584` | ✅ |
| `-[HeadUpDisplay drawTargetReticle:]` (2486) | `HeadUpDisplay::drawTargetReticle` `Core/HeadUpDisplay.cpp:1788` | ✅ |
| `-[HeadUpDisplay drawSecondaryTargetReticle:]` (2500) | `HeadUpDisplay::drawSecondaryTargetReticle` `Core/HeadUpDisplay.cpp:1802` | ✅ |
| `-[HeadUpDisplay drawWaypoints:]` (2529) | `HeadUpDisplay::drawWaypoints` `Core/HeadUpDisplay.cpp:1831` | ❌ |
| `-[HeadUpDisplay drawStatusLight:]` (2542) | `HeadUpDisplay::drawStatusLight` `Core/HeadUpDisplay.cpp:2648` | ✅ |
| `-[HeadUpDisplay drawDirectionCue:]` (2596) | `HeadUpDisplay::drawDirectionCue` `Core/HeadUpDisplay.cpp:2702` | ✅ |
| `-[HeadUpDisplay drawClock:]` (2682) | `HeadUpDisplay::drawClock` `Core/HeadUpDisplay.cpp:2788` | ✅ |
| `-[HeadUpDisplay drawPrimedEquipment:]` (2703) | `HeadUpDisplay::drawPrimedEquipment` `Core/HeadUpDisplay.cpp:2809` | ✅ |
| `-[HeadUpDisplay drawASCTarget:]` (2754) | `HeadUpDisplay::drawASCTarget` `Core/HeadUpDisplay.cpp:2860` | ✅ |
| `-[HeadUpDisplay drawWeaponsOfflineText:]` (2786) | `HeadUpDisplay::drawWeaponsOfflineText` `Core/HeadUpDisplay.cpp:2892` | ✅ |
| `-[HeadUpDisplay drawFPSInfoCounter:]` (2818) | `HeadUpDisplay::drawFPSInfoCounter` `Core/HeadUpDisplay.cpp:2923` | ✅ |
| `-[HeadUpDisplay drawScoopStatus:]` (2857) | `HeadUpDisplay::drawScoopStatus` `Core/HeadUpDisplay.cpp:2961` | ✅ |
| `-[HeadUpDisplay drawStickSensitivityIndicator:]` (2958) | `HeadUpDisplay::drawStickSensitivityIndicator` `Core/HeadUpDisplay.cpp:3062` | ✅ |
| `-[HeadUpDisplay drawSurroundInternal:color:]` (3005) | `HeadUpDisplay::drawSurroundInternal` `Core/HeadUpDisplay.cpp:1173` | ✅ |
| `-[HeadUpDisplay drawSurround:]` (3029) | `HeadUpDisplay::drawSurround` `Core/HeadUpDisplay.cpp:1197` | ✅ |
| `-[HeadUpDisplay drawGreenSurround:]` (3045) | `HeadUpDisplay::drawGreenSurround` `Core/HeadUpDisplay.cpp:1213` | ✅ |
| `-[HeadUpDisplay drawYellowSurround:]` (3050) | `HeadUpDisplay::drawYellowSurround` `Core/HeadUpDisplay.cpp:1218` | ✅ |
| `-[HeadUpDisplay drawTrumbles:]` (3055) | `HeadUpDisplay::drawTrumbles` `Core/HeadUpDisplay.cpp:3110` | ❌ |
| `-[HeadUpDisplay drawMultiFunctionDisplay:withText:asIndex:]` (3065) | `HeadUpDisplay::drawMultiFunctionDisplay` `Core/HeadUpDisplay.cpp:1223` | ✅ |
| `hudDrawIndicatorAt()` (3132) | `hudDrawIndicatorAt` `Core/HeadUpDisplay.cpp:3223` | ✅ |
| `hudDrawMarkerAt()` (3155) | `hudDrawMarkerAt` `Core/HeadUpDisplay.cpp:3246` | ✅ |
| `hudDrawBarAt()` (3178) | `hudDrawBarAt` `Core/HeadUpDisplay.cpp:3269` | ✅ |
| `hudDrawSurroundAt()` (3203) | `hudDrawSurroundAt` `Core/HeadUpDisplay.cpp:3294` | ✅ |
| `hudDrawStatusIconAt()` (3216) | `hudDrawStatusIconAt` `Core/HeadUpDisplay.cpp:3307` | ✅ |
| `hudDrawReticleOnTarget()` (3233) *(added; multi-line signature)* | `hudDrawReticleOnTarget` `Core/HeadUpDisplay.cpp:3326` | ✅ |
| `hudDrawWaypoint()` (3427) | `hudDrawWaypoint` `Core/HeadUpDisplay.cpp:3522` | ✅ |
| `hudRotateViewpointForVirtualDepth()` (3492) | `hudRotateViewpointForVirtualDepth` `Core/HeadUpDisplay.cpp:3589` | ✅ |
| `InitTextEngine()` (3561) | `InitTextEngine` `Core/HeadUpDisplay.cpp:3658` | ✅ |
| `OOHUDResetTextEngine()` (3593) | `OOHUDResetTextEngine` `Core/HeadUpDisplay.cpp:3702` | ✅ |
| `drawCharacterQuad()` (3599) | `drawCharacterQuad` `Core/HeadUpDisplay.cpp:3712` | ✅ |
| `OORectFromString()` (3621) | `cxx_OORectFromString` `Core/HeadUpDisplay.cpp:3734` (+ `ConvertedString` :3693) | ✅ |
| `OOStringWidthInEm()` (3639) | `cxx_OOStringWidthInEm` `Core/HeadUpDisplay.cpp:3752` | ✅ |
| `drawHighlight()` (3644) | `drawHighlight` `Core/HeadUpDisplay.cpp:3757` | ✅ |
| `OODrawString()` (3673) | `cxx_OODrawString` `Core/HeadUpDisplay.cpp:3786` | ✅ |
| `OODrawStringAligned()` (3678) | `cxx_OODrawStringAligned` `Core/HeadUpDisplay.cpp:3791` | ✅ |
| `OOStartDrawingStrings()` (3685) | `OOStartDrawingStrings` `Core/HeadUpDisplay.cpp:3798` | ✅ |
| `OODrawStringQuadsAligned()` (3694) | `cxx_OODrawStringQuadsAligned` `Core/HeadUpDisplay.cpp:3808` | ✅ |
| `OOStopDrawingStrings()` (3714) | `OOStopDrawingStrings` `Core/HeadUpDisplay.cpp:3828` | ✅ |
| `OODrawHilightedString()` (3724) | `cxx_OODrawHilightedString` `Core/HeadUpDisplay.cpp:3838` | ✅ |
| `OODrawPlanetInfo()` (3746) | `OODrawPlanetInfo` `Core/HeadUpDisplay.cpp:3860` | ✅ |
| `OODrawHilightedPlanetInfo()` (3799) | `OODrawHilightedPlanetInfo` `Core/HeadUpDisplay.cpp:3914` | ✅ |
| `GLDrawNonlinearCascadeWeapon()` (3831) | `GLDrawNonlinearCascadeWeapon` `Core/HeadUpDisplay.cpp:3946` | ✅ |
| `nonlinearScannerFunc()` (3898) | `nonlinearScannerFunc` `Core/HeadUpDisplay.cpp:4013` | ✅ |
| `drawScannerGrid()` (3911) | `drawScannerGrid` `Core/HeadUpDisplay.cpp:4026` | ✅ |
| `DrawSpecialOval()` (4047) | `DrawSpecialOval` `Core/HeadUpDisplay.cpp:4162` | ✅ |
| `-[HeadUpDisplay setLineWidth:]` (4066) | `HeadUpDisplay::setLineWidth` `Core/HeadUpDisplay.cpp:879` | ✅ |
| `-[HeadUpDisplay lineWidth]` (4071) | `HeadUpDisplay::getLineWidth` `Core/HeadUpDisplay.cpp:884` | ✅ |
| `-[NSString(OODisplayEncoding) cStringUsingOoliteEncoding]` (4080) | — (no counterpart; no upstream caller outside this file) | ➖ |
| `-[NSString(OODisplayEncoding) cStringUsingOoliteEncodingAndRemapping]` (4089) | — (no counterpart; no upstream caller outside this file) | ➖ |
| `-[OOPolygonSprite(OOHUDBeaconIcon) oo_drawHUDBeaconIconAt:size:alpha:z:]` (4102) | `OOPolygonSprite::drawHUDBeaconIconAt` → `OOPolygonSpriteDrawHUDBeaconIcon` `Core/HeadUpDisplay.cpp:4186`/`:4191` | ✅ |
| `-[NSString(OOHUDBeaconIcon) oo_drawHUDBeaconIconAt:size:alpha:z:]` (4125) | replaced by `OOHUDBeaconCodeIcon::drawHUDBeaconIconAt` `Core/HeadUpDisplay.cpp:4215` (built by `ShipEntity::beaconDrawable` `Core/Entities/ShipEntity.cpp:1790`) | ➖ |
| `SetGLColourFromInfo()` (4132) | `SetGLColourFromInfo` `Core/HeadUpDisplay.cpp:4222` | ✅ |
| `GetRGBAArrayFromInfo()` (4149) | `GetRGBAArrayFromInfo` `Core/HeadUpDisplay.cpp:4238` | ✅ |
| colour table + layout `#define`s (183–190; `HeadUpDisplay.h`) *(added)* | `Core/HeadUpDisplay.cpp:261-268`; `Core/HeadUpDisplay.h` | ✅ |

**Differences:**

- ❌ **low** — Waypoints are drawn in `std::map` key order (sorted by waypoint key) instead of `NSDictionary -allValues` hash order; only the overdraw order of overlapping translucent waypoint markers can differ — upstream `Core/HeadUpDisplay.m:2537` ↔ port `Core/HeadUpDisplay.cpp:1838`
- ❌ **low** — `drawTrumbles` dereferences `PLAYER` with no null check (`player->trumbleArray()`, `player->getTrumbleCount()`), where upstream messaged nil and drew nothing. This crashes only if the HUD renders with no player — upstream `Core/HeadUpDisplay.m:3057` ↔ port `Core/HeadUpDisplay.cpp:3112-3115`
- ➖ **low** — `NSString(OODisplayEncoding)` (`cStringUsingOoliteEncoding`, `…AndRemapping`) has no port; upstream had no caller outside HeadUpDisplay, so nothing observable is lost — upstream `Core/HeadUpDisplay.m:4080-4096`
- ➖ **low** — The `NSString(OOHUDBeaconIcon)` category is replaced by the `OOHUDBeaconCodeIcon` class. The text, position (`x-2.5w`, `y-3h`) and 2× size are identical, and `ShipEntity::beaconDrawable` builds it in the same cases (first UTF-16 unit, or "") — upstream `Core/HeadUpDisplay.m:4125` ↔ port `Core/HeadUpDisplay.cpp:4215`
- ➖ **low** — `-initWithDictionary:` (one argument) is gone; callers pass `nullopt` to the two-argument form, which behaves the same as `inFile:nil` — upstream `Core/HeadUpDisplay.m:209` ↔ port `Core/HeadUpDisplay.cpp:301`
- ✅ **low** (subtle, verified) — The dial dispatch table `kDials` omits `drawDirectionCue:` and `drawSecondaryTargetReticle:`, which upstream's `-respondsToSelector:` would have accepted. Neither appears in `Resources/Config/whitelist.plist` `hud_dial_methods`, and all 36 whitelisted names are in `kDials`, so dial acceptance and the "not in whitelist"/"not implemented" logs are unchanged — upstream `Core/HeadUpDisplay.m:689-702` ↔ port `Core/HeadUpDisplay.cpp:121-172,777-790`
- ✅ **low** (subtle, verified) — The reticle colour list still stops at the first colour that fails to parse, as `+arrayWithObjects:` did. A short list still raises `NSRangeException`-style text on an out-of-range index (`ReticleColorAt`), and a `drawTargetReticle:` dial still suppresses the green/red/cyan fallback — upstream `Core/HeadUpDisplay.m:245-257,2659,3283` ↔ port `Core/HeadUpDisplay.cpp:334-361,214-220`
- ✅ **low** (subtle, verified) — An MFD entry that is not a dictionary still raises "Index 1 is out of range 0" when it is drawn (`GetCurrentCachedInfo`), as the empty tuple array did — upstream `Core/HeadUpDisplay.m:716,3012` ↔ port `Core/HeadUpDisplay.cpp:104-115`
- ✅ **low** (subtle) — Custom dials with no `data_source` key now pass `""` to `PlayerEntity::dialCustom*` where upstream passed nil (`objectForKey:nil` → default). They differ only if a script registered a custom dial under the empty key — upstream `Core/HeadUpDisplay.m:1694,1729,1756,1797,1826` ↔ port `Core/HeadUpDisplay.cpp:1850,1885,1912,1953,1985`
- ✅ (checked) — hud.plist keys and defaults match upstream: `overall_alpha` 0.75, `reticle_target_sensitive` NO, `cloak_indicator_on_status_light` YES, `allow_big_gui` NO, `crosshair_color` greenColor, `crosshair_scale` 32, `crosshair_width` 1.5, `scanner_minimalistic`/`scanner_non_linear`/`scanner_ultra_zoom` NO, and `target_rgba`/`target_sensitive_rgba`/`wormhole_rgba` green/red/cyan. `message_gui` (`permanent` NO, `background_automatic` YES, `text_comms_color` green) and `comm_log_gui` (`automatic` YES, `permanent` NO) match, as do their empty-dict resets (row 8/9, positions, sizes, colours). All 156 `#define`s in `HeadUpDisplay.h` match apart from `@""`→`""` (the `Z1` macro now null-guards).
- ✅ (checked) — The scanner, compass, aegis, zoom-indicator, nonlinear-scanner and scanner-grid maths, dial colour thresholds (speed .80/.25; shields .25/.80; cabin temp .80/.90 flash/.25; altitude .25/.10 flash/.75; custom bar .75/.25) and alpha handling (`cached.alpha` from `oo_nonNegativeFloatForKey` default 1; scoop default 0.75; scanner `emptyDial` when `alpha` is missing or 0; FPS counter forced to alpha 1) are copied verbatim.
- ✅ (checked) — The energy gauge minimum (`n_bars` from max energy/64, at least 1, labels off above 8, `"E%x"` labels), the legend defaults (14×8, `align`==1 right-aligned), missile `spacing` and primed equipment `n_bars` default 1 all match.
- ✅ (checked) — Font metrics match: `oolite-font.plist` `texture` default `oolite-font.png`, `f6KernGovernment` 1.0, `f6KernTechLevel` 2.0, widths ×0.13 capped at 256 glyphs, the baseline +⅛·height for glyphs above 32, and the 31/32 non-printing glyphs.
- ✅ (checked) — The drawing order matches: crosshairs (if `crosshairWidth*lineWidth>0`), then legends (if `lineWidth>0`, ascending), then dials (ascending), then MFDs. Within the scanner, the grid is drawn first, then the lollipops in sorted-entity order.

## OOCrosshairs

<a id="oocrosshairs"></a>
Upstream `src/Core/OOCrosshairs.m` ↔ `Core/OOCrosshairs.cpp`

**Status:** done — 5 rows: 5 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCrosshairs initWithPoints:]` (53) | `OOCrosshairs(points, scale, color, alpha)` `Core/OOCrosshairs.cpp:36` | ✅ |
| `-[OOCrosshairs dealloc]` (67) | `~OOCrosshairs` `Core/OOCrosshairs.cpp:43` | ✅ |
| `-[OOCrosshairs render]` (74) | `render` `Core/OOCrosshairs.cpp:48` | ✅ |
| `-[OOCrosshairs setUpDataWithPoints:]` (105) | `setUpDataWithPoints` `Core/OOCrosshairs.cpp:79` | ✅ |
| `-[OOCrosshairs setUpDataForOnePoint:]` (133) | `setUpDataForOnePoint` `Core/OOCrosshairs.cpp:101` | ✅ |

**Differences:**

- ✅ (subtle) — a nil `color` was a no-op `getRed:` in upstream, which left the default green `{0,1,0,1}`. The port's explicit `color != nullptr` guard does the same. A non-array point entry (`oo_arrayAtIndex:` nil → `[nil count]` 0) still writes the red centre point, via `pointInfo != nullptr`. The alpha clamping order, the 12-float stride and `_count` (`NSUInteger`) are all unchanged — upstream `Core/OOCrosshairs.m:119`, `:142` ↔ port `Core/OOCrosshairs.cpp:90`, `:106`
- ✅ (subtle) — `render` reads `display_z` through a null-guarded `UNIVERSE->getGameView()` (0 when absent, as nil messaging gave) — upstream `Core/OOCrosshairs.m:84` ↔ port `Core/OOCrosshairs.cpp:58`


## OOMouseInteractionMode

<a id="oomouseinteractionmode"></a>
Upstream `src/Core/OOMouseInteractionMode.m` ↔ `Core/OOMouseInteractionMode.cpp`

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOStringFromMouseInteractionMode()` (28) | `OOStringFromMouseInteractionMode` `Core/OOMouseInteractionMode.cpp:31` | ✅ |
| `OOMouseInteractionModeIsUIScreen()` (44) | `OOMouseInteractionModeIsUIScreen` `Core/OOMouseInteractionMode.cpp:47` | ✅ |
| `OOMouseInteractionModeIsFlightMode()` (60) | `OOMouseInteractionModeIsFlightMode` `Core/OOMouseInteractionMode.cpp:63` | ✅ |

**Differences:**

- ✅ (subtle) — `OOStringFromMouseInteractionMode` returns `std::string`, not `NSString*`. The four names and the `"<unknown mode %u>"` fallback are the same. Its one caller logs it under `input.mouseMode.changed` (port `Core/GameController.cpp:335`) — upstream `Core/OOMouseInteractionMode.m:28` ↔ port `Core/OOMouseInteractionMode.cpp:31`

