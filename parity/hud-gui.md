# Parity findings: hud-gui
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## GuiDisplayGen

<a id="guidisplaygen"></a>
Upstream `src/Core/GuiDisplayGen.m` ↔ `Core/GuiDisplayGen.cpp` (2318 / 2673 lines)

**Status:** done — 88 rows: 84 ✅ 2 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `RowInRange` (42) | `RowInRange` `Core/GuiDisplayGen.cpp:53` | ✅ |
| `-[GuiDisplayGen init]` (65) | `GuiDisplayGen()` `Core/GuiDisplayGen.cpp:174` (stops, 0.9×row text, "%d" keys, yellow rows, title "") | ✅ |
| `-[GuiDisplayGen initWithPixelSize:columns:rows:rowHeight:rowStart:title:]` (115) | `GuiDisplayGen(NSSize,…)` `Core/GuiDisplayGen.cpp:226` (green rows, title as given) | ✅ |
| `-[GuiDisplayGen dealloc]` (160) | `~GuiDisplayGen() = default` `Core/GuiDisplayGen.cpp:264` | ✅ |
| `-[GuiDisplayGen resizeWithPixelSize:columns:rows:rowHeight:rowStart:title:]` (175) | `resizeWithPixelSize` `Core/GuiDisplayGen.cpp:266` | ✅ |
| `-[GuiDisplayGen resizeTo:characterHeight:title:]` (200) | `resizeTo` `Core/GuiDisplayGen.cpp:288` (2.75/1 row-start formula, `gui.reset` log) | ✅ |
| `-[GuiDisplayGen size]` (244) | `size` `Core/GuiDisplayGen.cpp:333` | ✅ |
| `-[GuiDisplayGen columns]` (249) | `columns` `Core/GuiDisplayGen.cpp:335` | ✅ |
| `-[GuiDisplayGen rows]` (254) | `rows` `Core/GuiDisplayGen.cpp:337` | ✅ |
| `-[GuiDisplayGen rowHeight]` (259) | `rowHeight` `Core/GuiDisplayGen.cpp:339` | ✅ |
| `-[GuiDisplayGen rowStart]` (264) | `rowStart` `Core/GuiDisplayGen.cpp:341` | ✅ |
| `-[GuiDisplayGen title]` (269) | `getTitle` `Core/GuiDisplayGen.cpp:343` | ✅ |
| `-[GuiDisplayGen setTitle:]` (274) | `setTitle` + `TitleFrom` `Core/GuiDisplayGen.cpp:345`, `:72` (empty → none) | ✅ |
| `-[GuiDisplayGen setDrawPosition:]` (284) | `setDrawPosition` `Core/GuiDisplayGen.cpp:349` | ✅ |
| `-[GuiDisplayGen drawPosition]` (289) | `getDrawPosition` `Core/GuiDisplayGen.cpp:351` | ✅ |
| `-[GuiDisplayGen userSettings]` (294) | `userSettings` `Core/GuiDisplayGen.cpp:353` (by value) | ✅ |
| `-[GuiDisplayGen fadeOutFromTime:overDuration:]` (299) | `fadeOutFromTime` `Core/GuiDisplayGen.cpp:355` (-1000 for zero duration) | ✅ |
| `-[GuiDisplayGen stopFadeOuts]` (310) | `stopFadeOuts` `Core/GuiDisplayGen.cpp:366` | ✅ |
| `-[GuiDisplayGen alpha]` (315) | `alpha` `Core/GuiDisplayGen.cpp:368` | ✅ |
| `-[GuiDisplayGen setAlpha:]` (320) | `setAlpha` `Core/GuiDisplayGen.cpp:370` | ✅ |
| `-[GuiDisplayGen setMaxAlpha:]` (325) | `setMaxAlpha` `Core/GuiDisplayGen.cpp:374` | ✅ |
| `-[GuiDisplayGen setBackgroundColor:]` (330) | `setBackgroundColor` `Core/GuiDisplayGen.cpp:376` | ✅ |
| `-[GuiDisplayGen textColor]` (336) | `getTextColor` `Core/GuiDisplayGen.cpp:380` | ✅ |
| `-[GuiDisplayGen setTextColor:]` (342) | `setTextColor` `Core/GuiDisplayGen.cpp:383` (nil → yellow) | ✅ |
| `-[GuiDisplayGen textCommsColor]` (350) | `getTextCommsColor` `Core/GuiDisplayGen.cpp:390` | ✅ |
| `-[GuiDisplayGen setTextCommsColor:]` (355) | `setTextCommsColor` `Core/GuiDisplayGen.cpp:392` | ✅ |
| `-[GuiDisplayGen colorFromSetting:defaultValue:]` (363) | `colorFromSetting` `Core/GuiDisplayGen.cpp:399` (setting → def → textColor) | ✅ |
| `-[GuiDisplayGen setGLColorFromSetting:defaultValue:alpha:]` (381) | `setGLColorFromSetting` `Core/GuiDisplayGen.cpp:418` | ✅ |
| `-[GuiDisplayGen setGuiColorSettingFromKey:color:]` (390) | `setGuiColorSettingFromKey` `Core/GuiDisplayGen.cpp:427` | ✅ |
| `-[GuiDisplayGen setCharacterSize:]` (403) | `setCharacterSize` `Core/GuiDisplayGen.cpp:439` | ✅ |
| `-[GuiDisplayGen setShowAdvancedNavArray:]` (408) | `setShowAdvancedNavArray` `Core/GuiDisplayGen.cpp:443` | ✅ |
| `-[GuiDisplayGen setColor:forRow:]` (413) | `setColor` `Core/GuiDisplayGen.cpp:447` | ✅ |
| `-[GuiDisplayGen objectForRow:]` (419) | `objectForRow` `Core/GuiDisplayGen.cpp:451` | ✅ |
| `-[GuiDisplayGen rowForKey:]` (427) | `rowForKey` `Core/GuiDisplayGen.cpp:458` (nil key → -1) | ✅ |
| `-[GuiDisplayGen keyForRow:]` (437) | `keyForRow` `Core/GuiDisplayGen.cpp:468` | ✅ |
| `-[GuiDisplayGen selectedRow]` (445) | `getSelectedRow` `Core/GuiDisplayGen.cpp:475` | ✅ |
| `-[GuiDisplayGen setSelectedRow:]` (453) | `setSelectedRow` + `IsSkipKey` `Core/GuiDisplayGen.cpp:482`, `:78` | ✅ |
| `-[GuiDisplayGen setNextRow:]` (468) | `setNextRow` `Core/GuiDisplayGen.cpp:496` | ✅ |
| `-[GuiDisplayGen setFirstSelectableRow]` (482) | `setFirstSelectableRow` `Core/GuiDisplayGen.cpp:509` (unsigned row, as `NSUInteger`) | ✅ |
| `-[GuiDisplayGen setLastSelectableRow]` (497) | `setLastSelectableRow` `Core/GuiDisplayGen.cpp:523` (same unsigned wrap) | ✅ |
| `-[GuiDisplayGen reportSelectedRow:]` (512) | `reportSelectedRow` `Core/GuiDisplayGen.cpp:537` (args stop at first nil) | ✅ |
| `-[GuiDisplayGen setNoSelectedRow]` (517) | `setNoSelectedRow` `Core/GuiDisplayGen.cpp:552` | ✅ |
| `-[GuiDisplayGen selectedRowText]` (522) | `selectedRowText` `Core/GuiDisplayGen.cpp:554` | ✅ |
| `-[GuiDisplayGen selectedRowKey]` (531) | `selectedRowKey` `Core/GuiDisplayGen.cpp:565` | ⚠️ |
| `-[GuiDisplayGen setShowTextCursor:]` (539) | `setShowTextCursor` `Core/GuiDisplayGen.cpp:575` | ✅ |
| `-[GuiDisplayGen setCurrentRow:]` (544) | `setCurrentRow` `Core/GuiDisplayGen.cpp:577` | ✅ |
| `-[GuiDisplayGen selectableRange]` (554) | `getSelectableRange` `Core/GuiDisplayGen.cpp:586` | ✅ |
| `-[GuiDisplayGen setSelectableRange:]` (559) | `setSelectableRange` `Core/GuiDisplayGen.cpp:588` | ✅ |
| `-[GuiDisplayGen setTabStops:]` (564) | `setTabStops` `Core/GuiDisplayGen.cpp:592` | ✅ |
| `-[GuiDisplayGen overrideTabs:from:length:]` (570) | `overrideTabs` `Core/GuiDisplayGen.cpp:596` (clamp to `GUI_MAX_COLUMNS`, unsigned read) | ✅ |
| `-[GuiDisplayGen clear]` (584) | `clear` `Core/GuiDisplayGen.cpp:611` | ✅ |
| `-[GuiDisplayGen clearAndKeepBackground:]` (589) | `clearAndKeepBackground` `Core/GuiDisplayGen.cpp:613` | ✅ |
| `-[GuiDisplayGen setKey:forRow:]` (607) | `setKey` `Core/GuiDisplayGen.cpp:629` | ✅ |
| `-[GuiDisplayGen setText:forRow:]` (613) | `setText(str,row)` `Core/GuiDisplayGen.cpp:633` | ✅ |
| `-[GuiDisplayGen setText:forRow:align:]` (620) | `setText(str,row,align)` `Core/GuiDisplayGen.cpp:639` | ✅ |
| `-[GuiDisplayGen addLongText:startingAtRow:align:]` (628) | `addLongText` + `WordsJoinedBySpace` `Core/GuiDisplayGen.cpp:661`, `:61` (same word-fit loop) | ✅ |
| `-[GuiDisplayGen reflowTextForMFD:]` (666) | `reflowTextForMFD` `Core/GuiDisplayGen.cpp:699` (15-char limit, trim on break) | ✅ |
| `-[GuiDisplayGen leaveLastLine]` (697) | `leaveLastLine` `Core/GuiDisplayGen.cpp:736` (last row fade 0.4) | ✅ |
| `-[GuiDisplayGen getLastLines]` (710) | `getLastLines` `Core/GuiDisplayGen.cpp:748` (`%.3g` → `{:.3g}`, stops at nil text) | ✅ |
| `-[GuiDisplayGen printLongText:align:color:fadeTime:key:addToArray:]` (736) | `printLongText` `Core/GuiDisplayGen.cpp:790` | ✅ |
| `-[GuiDisplayGen printLineNoScroll:align:color:fadeTime:key:addToArray:]` (797) | `printLineNoScroll` `Core/GuiDisplayGen.cpp:845` | ⚠️ |
| `-[GuiDisplayGen setArray:forRow:]` (814) | `setArray(vector<string>)` `Core/GuiDisplayGen.cpp:858` | ✅ |
| `-[GuiDisplayGen insertItemsFromArray:withKeys:intoRow:color:]` (820) | `insertItemsFromArray` `Core/GuiDisplayGen.cpp:867` | ❌ |
| `-[GuiDisplayGen scrollUp:]` (863) | `scrollUp` `Core/GuiDisplayGen.cpp:918` | ✅ |
| `-[GuiDisplayGen clearBackground]` (882) | `clearBackground` `Core/GuiDisplayGen.cpp:936` | ✅ |
| `TextureForGUITexture` (888) | `TextureForGUITexture` + `DescriptorName` `Core/GuiDisplayGen.cpp:104`, `:97` | ✅ |
| `NewTextureSpriteWithDescriptor` (912) | `NewTextureSpriteWithDescriptor` `Core/GuiDisplayGen.cpp:129` (aspect fallbacks) | ✅ |
| `-[GuiDisplayGen setBackgroundTextureSpecial:withBackground:]` (952) | `setBackgroundTextureSpecial` `Core/GuiDisplayGen.cpp:941` (same key fallback chains) | ✅ |
| `-[GuiDisplayGen setBackgroundTextureDescriptor:]` (1003) | `setBackgroundTextureDescriptor` `Core/GuiDisplayGen.cpp:1022` | ✅ |
| `-[GuiDisplayGen setForegroundTextureDescriptor:]` (1011) | `setForegroundTextureDescriptor` `Core/GuiDisplayGen.cpp:1030` (sRGBA only with HDR) | ✅ |
| `-[GuiDisplayGen setBackgroundTextureKey:]` (1020) | `setBackgroundTextureKey` `Core/GuiDisplayGen.cpp:1044` | ✅ |
| `-[GuiDisplayGen setForegroundTextureKey:]` (1025) | `setForegroundTextureKey` `Core/GuiDisplayGen.cpp:1052` | ✅ |
| `-[GuiDisplayGen preloadGUITexture:]` (1030) | `preloadGUITexture` `Core/GuiDisplayGen.cpp:1060` | ✅ |
| `-[GuiDisplayGen textureDescriptorFromJSValue:inContext:callerDescription:]` (1035) | `textureDescriptorFromJSValue` `Core/GuiDisplayGen.cpp:1065` (null → {}, "" → {name:""}, same warning text) | ✅ |
| `-[GuiDisplayGen setStatusPage:]` (1076) | `setStatusPage` `Core/GuiDisplayGen.cpp:1108` | ✅ |
| `-[GuiDisplayGen statusPage]` (1085) | `getStatusPage` `Core/GuiDisplayGen.cpp:1117` | ✅ |
| `-[GuiDisplayGen drawEquipmentList:z:]` (1090) | `drawEquipmentList` `Core/GuiDisplayGen.cpp:1119` (paging maths, 42→40+"..." UTF-16) | ✅ |
| `-[GuiDisplayGen drawGUIBackground]` (1209) | `drawGUIBackground` `Core/GuiDisplayGen.cpp:1269` | ✅ |
| `-[GuiDisplayGen refreshStarChart]` (1220) | `refreshStarChart` `Core/GuiDisplayGen.cpp:1281` | ✅ |
| `-[GuiDisplayGen drawGUI:drawCursor:]` (1225) | `drawGUI` (+ `rowAtVirtualJoystickPosition` :647) `Core/GuiDisplayGen.cpp:1283` | ✅ |
| `-[GuiDisplayGen drawGLDisplay:y:z:alpha:]` (1308) | `drawGLDisplay` + `TrimmedForHighlight` `Core/GuiDisplayGen.cpp:1403`, `:83` | ✅ |
| `-[GuiDisplayGen drawCrossHairsWithSize:x:y:z:]` (1517) | `drawCrossHairsWithSize` `Core/GuiDisplayGen.cpp:1669` | ✅ |
| `-[GuiDisplayGen setStarChartTitle]` (1531) | `setStarChartTitle` `Core/GuiDisplayGen.cpp:1683` | ❌ |
| `-[GuiDisplayGen drawStarChart:y:z:alpha:compact:]` (1550) | `drawStarChart` `Core/GuiDisplayGen.cpp:2019` (scales, clip rect, cache, colours, labels) | ✅ |
| `-[GuiDisplayGen drawSystemMarkers:atX:andY:andZ:withAlpha:andScale:]` (2060) | `drawSystemMarkers` `Core/GuiDisplayGen.cpp:1717` | ✅ |
| `-[GuiDisplayGen drawSystemMarker:atX:andY:andZ:withAlpha:andScale:]` (2068) | `drawSystemMarker` `Core/GuiDisplayGen.cpp:1727` (clamp 0.5–2, ×1.4) | ✅ |
| `-[GuiDisplayGen targetNextFoundSystem:]` (2119) | `targetNextFoundSystem` `Core/GuiDisplayGen.cpp:1785` | ✅ |
| `-[GuiDisplayGen drawAdvancedNavArrayAtX:y:z:alpha:usingRoute:optimizedBy:zoom:]` (2164) | `drawAdvancedNavArrayAtX` `Core/GuiDisplayGen.cpp:1833` (`link_color` keys, route hops `count-1` unsigned) | ✅ |

**Differences:**

- ❌ **low** (still open) — `setStarChartTitle` tests the title keys with `descriptionForKey` (= `chooseStringForKey`, port `Core/Universe.cpp:8334`) instead of `[[UNIVERSE descriptions] valueForKey:]`. An array entry draws an extra random pick per call (RNG stream shift); a non-string/empty-array entry falls back to the galaxy/default title where upstream set no title. Stock `descriptions.plist` is unaffected — upstream `Core/GuiDisplayGen.m:1538` ↔ port `Core/GuiDisplayGen.cpp:1699-1714`
- ❌ **low** (still open) — `insertItemsFromArray`: for an array row item the port keeps only string columns (`setArray(vector<string>)`), so a number column is dropped and later columns shift tab stops; upstream kept it and drew it via `oo_stringAtIndex:`. No caller in either tree — upstream `Core/GuiDisplayGen.m:852` ↔ port `Core/GuiDisplayGen.cpp:900-907`
- ⚠️ **low** (still open) — `selectedRowKey` bound corrected from `> count` to `>= count` (comment cpp:566); upstream raised at `selectedRow == count` — upstream `Core/GuiDisplayGen.m:533` ↔ port `Core/GuiDisplayGen.cpp:568-569`
- ⚠️ **low** (still open) — `printLineNoScroll` with nil string skips the `text_array` append where upstream's `addObject:nil` raised (comment cpp:853) — upstream `Core/GuiDisplayGen.m:809` ↔ port `Core/GuiDisplayGen.cpp:853`
- ✅ (subtle) — `selectedRowText` on an array row whose first column is not a string returns nullopt; upstream returned that object. Port `setArray` only stores strings, so not reachable — upstream `Core/GuiDisplayGen.m:526` ↔ port `Core/GuiDisplayGen.cpp:557-561`
- ✅ (subtle) — `drawStarChart` chart text row: nil `targetName`/`OOExpandKey` result becomes `""` instead of truncating `+arrayWithObjects:`; not reachable for valid targets — upstream `Core/GuiDisplayGen.m:2015-2034` ↔ port `Core/GuiDisplayGen.cpp:2596-2627`
- ✅ (subtle) — `colorFromSetting` returns the shared colour, not a `-copy`; `setGuiColorSettingFromKey` edits the dictionary in place. OOColor is immutable and `userSettings()` returns by value — port `Core/GuiDisplayGen.cpp:415`, `:427-437`
- ⚠️ (port-only) — `rowAtVirtualJoystickPosition` is the y-half of `drawGUI`'s cursor maths with the same clamps and `1 + (float)floor(...)`; `GuiDisplayGenUniverseUseShaders` bridges `[UNIVERSE useShaders]` — port `Core/GuiDisplayGen.cpp:647`, `:1364`, `:2671`
- ✅ (checked) — default tab stops `{0,192,256,320,384,448}`; chart tabs `{0,96,288}` + `chart_traveltime_tabs`; `govcol` table; economy `1−0.125·eco`; tech `0.6, 0.2+0.05·tec`; nova 0.3 / (1,0.2,0); no-data 0.7; blob 0.0017 with 0.5 floor; `chart_economy_%zu_color`/`chart_government_%zu_color` keys; all default GUI colours as upstream.

## HeadUpDisplay

<a id="headupdisplay"></a>
Upstream `src/Core/HeadUpDisplay.m` ↔ `Core/HeadUpDisplay.cpp` (4175 / 4936 lines)

**Status:** done — 138 rows: 132 ✅ 0 ⚠️ 2 ❌ 4 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `useDefined` (80) | `useDefined` `Core/HeadUpDisplay.cpp:240` | ✅ |
| `GLColorWithOverallAlpha` (204) | `GLColorWithOverallAlpha` `Core/HeadUpDisplay.cpp:327` | ✅ |
| `-[HeadUpDisplay initWithDictionary:]` (210) | folded into `HeadUpDisplay::initWithDictionary(info, nullopt)` `Core/HeadUpDisplay.cpp:342` | ➖ |
| `-[HeadUpDisplay initWithDictionary:inFile:]` (215) | `HeadUpDisplay::initWithDictionary` `Core/HeadUpDisplay.cpp:342` (all hud.plist defaults, reticle colours stop at first nil) | ✅ |
| `-[HeadUpDisplay dealloc]` (326) | `HeadUpDisplay::~HeadUpDisplay` `Core/HeadUpDisplay.cpp:336` | ✅ |
| `-[HeadUpDisplay resetGui:withInfo:]` (345) | `HeadUpDisplay::resetGui` `Core/HeadUpDisplay.cpp:483` | ✅ |
| `-[HeadUpDisplay resetGuiPosition:withInfo:]` (369) | `HeadUpDisplay::resetGuiPosition` `Core/HeadUpDisplay.cpp:508` | ✅ |
| `-[HeadUpDisplay resetGuis:]` (386) | `HeadUpDisplay::resetGuis` `Core/HeadUpDisplay.cpp:527` (line1 nil → true; empty-dict resets; nil-gui guards) | ✅ |
| `-[HeadUpDisplay hudName]` (508) | `HeadUpDisplay::getHudName` `Core/HeadUpDisplay.cpp:667` | ✅ |
| `-[HeadUpDisplay setHudName:]` (513) | `HeadUpDisplay::setHudName` `Core/HeadUpDisplay.cpp:669` | ✅ |
| `-[HeadUpDisplay reticleColorForIndex:]` (521) | `HeadUpDisplay::reticleColorForIndex` `Core/HeadUpDisplay.cpp:675` | ✅ |
| `-[HeadUpDisplay setReticleColorForIndex:toColor:]` (529) | `HeadUpDisplay::setReticleColorForIndex` `Core/HeadUpDisplay.cpp:682` | ✅ |
| `-[HeadUpDisplay scannerZoom]` (538) | `HeadUpDisplay::scannerZoom` `Core/HeadUpDisplay.cpp:691` | ✅ |
| `-[HeadUpDisplay setScannerZoom:]` (543) | `HeadUpDisplay::setScannerZoom` `Core/HeadUpDisplay.cpp:693` | ✅ |
| `-[HeadUpDisplay overallAlpha]` (548) | `HeadUpDisplay::getOverallAlpha` `Core/HeadUpDisplay.cpp:695` | ✅ |
| `-[HeadUpDisplay setOverallAlpha:]` (553) | `HeadUpDisplay::setOverallAlpha` `Core/HeadUpDisplay.cpp:697` (clamp 0–1) | ✅ |
| `-[HeadUpDisplay reticleTargetSensitive]` (558) | `HeadUpDisplay::getReticleTargetSensitive` `Core/HeadUpDisplay.cpp:701` | ✅ |
| `-[HeadUpDisplay setReticleTargetSensitive:]` (563) | `HeadUpDisplay::setReticleTargetSensitive` `Core/HeadUpDisplay.cpp:705` | ✅ |
| `-[HeadUpDisplay propertiesReticleTargetSensitive]` (568) | `HeadUpDisplay::getPropertiesReticleTargetSensitive` `Core/HeadUpDisplay.cpp:711` | ✅ |
| `-[HeadUpDisplay isHidden]` (573) | `HeadUpDisplay::isHidden` `Core/HeadUpDisplay.cpp:715` | ✅ |
| `-[HeadUpDisplay setHidden:]` (578) | `HeadUpDisplay::setHidden` `Core/HeadUpDisplay.cpp:717` | ✅ |
| `-[HeadUpDisplay allowBigGui]` (583) | `HeadUpDisplay::getAllowBigGui` `Core/HeadUpDisplay.cpp:721` | ✅ |
| `-[HeadUpDisplay hasHidden:]` (588) | `HeadUpDisplay::hasHidden` `Core/HeadUpDisplay.cpp:723` | ✅ |
| `-[HeadUpDisplay setHiddenSelector:hidden:]` (596) | `HeadUpDisplay::setHiddenSelector` `Core/HeadUpDisplay.cpp:730` | ✅ |
| `-[HeadUpDisplay clearHiddenSelectors]` (605) | `HeadUpDisplay::clearHiddenSelectors` `Core/HeadUpDisplay.cpp:739` | ✅ |
| `-[HeadUpDisplay isCompassActive]` (610) | `HeadUpDisplay::isCompassActive` `Core/HeadUpDisplay.cpp:741` | ✅ |
| `-[HeadUpDisplay setCompassActive:]` (615) | `HeadUpDisplay::setCompassActive` `Core/HeadUpDisplay.cpp:743` | ✅ |
| `-[HeadUpDisplay isUpdating]` (620) | `HeadUpDisplay::isUpdating` `Core/HeadUpDisplay.cpp:747` | ✅ |
| `-[HeadUpDisplay setDeferredHudName:]` (625) | `HeadUpDisplay::setDeferredHudName` `Core/HeadUpDisplay.cpp:749` | ✅ |
| `-[HeadUpDisplay deferredHudName]` (631) | `HeadUpDisplay::getDeferredHudName` `Core/HeadUpDisplay.cpp:754` | ✅ |
| `-[HeadUpDisplay addLegend:]` (636) | `HeadUpDisplay::addLegend` `Core/HeadUpDisplay.cpp:758` (sprite held by widget; same log) | ✅ |
| `-[HeadUpDisplay addDial:]` (678) | `HeadUpDisplay::addDial` + `kDials`/`DialNamed` `Core/HeadUpDisplay.cpp:796`, `:137`, `:182` | ✅ |
| `-[HeadUpDisplay addMFD:]` (715) | `HeadUpDisplay::addMFD` + `AddHUDWidget` `Core/HeadUpDisplay.cpp:851`, `:127` | ✅ |
| `-[HeadUpDisplay mfdCount]` (722) | `HeadUpDisplay::mfdCount` `Core/HeadUpDisplay.cpp:857` | ✅ |
| `-[HeadUpDisplay renderHUD]` (754) | `HeadUpDisplay::renderHUD` `Core/HeadUpDisplay.cpp:941` | ✅ |
| `-[HeadUpDisplay drawLegends]` (779) | `HeadUpDisplay::drawLegends` `Core/HeadUpDisplay.cpp:965` | ✅ |
| `-[HeadUpDisplay drawDials]` (792) | `HeadUpDisplay::drawDials` `Core/HeadUpDisplay.cpp:979` (`compassTargetChanged` [null, mode]) | ✅ |
| `-[HeadUpDisplay drawMFDs]` (813) | `HeadUpDisplay::drawMFDs` `Core/HeadUpDisplay.cpp:1009` | ✅ |
| `-[HeadUpDisplay drawCrosshairs]` (826) | `HeadUpDisplay::drawCrosshairs` `Core/HeadUpDisplay.cpp:1022` | ✅ |
| `-[HeadUpDisplay crosshairDefinition]` (861) | `HeadUpDisplay::getCrosshairDefinition` `Core/HeadUpDisplay.cpp:859` | ✅ |
| `-[HeadUpDisplay setCrosshairDefinition:]` (866) | `HeadUpDisplay::setCrosshairDefinition` `Core/HeadUpDisplay.cpp:1061` | ✅ |
| `-[HeadUpDisplay crosshairDefinitionForWeaponType:]` (888) | `HeadUpDisplay::crosshairDefinitionForWeaponType` `Core/HeadUpDisplay.cpp:1078` (same 6-step search) | ✅ |
| `-[HeadUpDisplay drawLegend:]` (929) | `HeadUpDisplay::drawLegend` `Core/HeadUpDisplay.cpp:1116` | ✅ |
| `-[HeadUpDisplay drawHUDItem:]` (992) | `HeadUpDisplay::drawHUDItem` `Core/HeadUpDisplay.cpp:1193` | ✅ |
| `-[HeadUpDisplay checkPlayerInFlight]` (1028) | `HeadUpDisplay::checkPlayerInFlight` `Core/HeadUpDisplay.cpp:863` | ✅ |
| `-[HeadUpDisplay checkPlayerInSystemFlight]` (1033) | `HeadUpDisplay::checkPlayerInSystemFlight` `Core/HeadUpDisplay.cpp:869` | ✅ |
| `prefetchData` (1043) | `prefetchData` `Core/HeadUpDisplay.cpp:3601` | ✅ |
| `-[HeadUpDisplay drawScanner:]` (1056) | `HeadUpDisplay::drawScanner` `Core/HeadUpDisplay.cpp:1369` (entities held via `EntityHold`) | ✅ |
| `-[HeadUpDisplay minimalisticScanner]` (1361) | `HeadUpDisplay::minimalisticScanner` `Core/HeadUpDisplay.cpp:879` | ✅ |
| `-[HeadUpDisplay setMinimalisticScanner:]` (1366) | `HeadUpDisplay::setMinimalisticScanner` `Core/HeadUpDisplay.cpp:881` | ✅ |
| `+[HeadUpDisplay nonlinearScannerScale:Zoom:Scale:]` (1371) | `HeadUpDisplay::nonlinearScannerScale` (static) `Core/HeadUpDisplay.cpp:885` | ✅ |
| `-[HeadUpDisplay nonlinearScanner]` (1378) | `HeadUpDisplay::nonlinearScanner` `Core/HeadUpDisplay.cpp:892` | ✅ |
| `-[HeadUpDisplay setNonlinearScanner:]` (1383) | `HeadUpDisplay::setNonlinearScanner` `Core/HeadUpDisplay.cpp:894` | ✅ |
| `-[HeadUpDisplay scannerUltraZoom]` (1388) | `HeadUpDisplay::scannerUltraZoom` `Core/HeadUpDisplay.cpp:898` | ✅ |
| `-[HeadUpDisplay setScannerUltraZoom:]` (1393) | `HeadUpDisplay::setScannerUltraZoom` `Core/HeadUpDisplay.cpp:900` | ✅ |
| `-[HeadUpDisplay refreshLastTransmitter]` (1398) | `HeadUpDisplay::refreshLastTransmitter` `Core/HeadUpDisplay.cpp:904` | ✅ |
| `-[HeadUpDisplay drawScannerZoomIndicator:]` (1408) | `HeadUpDisplay::drawScannerZoomIndicator` `Core/HeadUpDisplay.cpp:1726` (`zl` renamed `zoomLevel`) | ✅ |
| `-[HeadUpDisplay drawCompass:]` (1455) | `HeadUpDisplay::drawCompass` `Core/HeadUpDisplay.cpp:1778` | ✅ |
| `SetCompassBlipColor` (1555) | `SetCompassBlipColor` `Core/HeadUpDisplay.cpp:3613` | ✅ |
| `-[HeadUpDisplay drawCompassPlanetBlipAt:Size:Alpha:]` (1564) | `HeadUpDisplay::drawCompassPlanetBlipAt` `Core/HeadUpDisplay.cpp:3621` | ✅ |
| `-[HeadUpDisplay drawCompassStationBlipAt:Size:Alpha:]` (1577) | `HeadUpDisplay::drawCompassStationBlipAt` `Core/HeadUpDisplay.cpp:3634` | ✅ |
| `-[HeadUpDisplay drawCompassSunBlipAt:Size:Alpha:]` (1589) | `HeadUpDisplay::drawCompassSunBlipAt` `Core/HeadUpDisplay.cpp:3650` | ✅ |
| `-[HeadUpDisplay drawCompassTargetBlipAt:Size:Alpha:]` (1599) | `HeadUpDisplay::drawCompassTargetBlipAt` `Core/HeadUpDisplay.cpp:3660` | ✅ |
| `-[HeadUpDisplay drawCompassBeaconBlipAt:Size:Alpha:]` (1613) | `HeadUpDisplay::drawCompassBeaconBlipAt` `Core/HeadUpDisplay.cpp:3674` | ✅ |
| `-[HeadUpDisplay drawAegis:]` (1641) | `HeadUpDisplay::drawAegis` `Core/HeadUpDisplay.cpp:1903` | ✅ |
| `-[HeadUpDisplay drawCustomBar:]` (1691) | `HeadUpDisplay::drawCustomBar` `Core/HeadUpDisplay.cpp:2046` | ✅ |
| `-[HeadUpDisplay drawCustomText:]` (1727) | `HeadUpDisplay::drawCustomText` `Core/HeadUpDisplay.cpp:2093` | ✅ |
| `-[HeadUpDisplay drawCustomIndicator:]` (1753) | `HeadUpDisplay::drawCustomIndicator` `Core/HeadUpDisplay.cpp:2130` | ✅ |
| `-[HeadUpDisplay drawCustomLight:]` (1782) | `HeadUpDisplay::drawCustomLight` `Core/HeadUpDisplay.cpp:2170` | ✅ |
| `-[HeadUpDisplay drawCustomImage:]` (1816) | `HeadUpDisplay::drawCustomImage` `Core/HeadUpDisplay.cpp:2216` | ✅ |
| `-[HeadUpDisplay drawSpeedBar:]` (1859) | `HeadUpDisplay::drawSpeedBar` `Core/HeadUpDisplay.cpp:2272` (.80/.25) | ✅ |
| `-[HeadUpDisplay drawRollBar:]` (1895) | `HeadUpDisplay::drawRollBar` `Core/HeadUpDisplay.cpp:2315` | ✅ |
| `-[HeadUpDisplay drawPitchBar:]` (1922) | `HeadUpDisplay::drawPitchBar` `Core/HeadUpDisplay.cpp:2350` | ✅ |
| `-[HeadUpDisplay drawYawBar:]` (1949) | `HeadUpDisplay::drawYawBar` `Core/HeadUpDisplay.cpp:2385` | ✅ |
| `-[HeadUpDisplay drawEnergyGauge:]` (1977) | `HeadUpDisplay::drawEnergyGauge` `Core/HeadUpDisplay.cpp:2421` (`E%x` → `E{:x}`) | ✅ |
| `-[HeadUpDisplay drawForwardShieldBar:]` (2048) | `HeadUpDisplay::drawForwardShieldBar` `Core/HeadUpDisplay.cpp:2500` | ✅ |
| `-[HeadUpDisplay drawAftShieldBar:]` (2082) | `HeadUpDisplay::drawAftShieldBar` `Core/HeadUpDisplay.cpp:2542` | ✅ |
| `-[HeadUpDisplay drawFuelBar:]` (2116) | `HeadUpDisplay::drawFuelBar` `Core/HeadUpDisplay.cpp:2584` | ✅ |
| `-[HeadUpDisplay drawWitchspaceDestination:]` (2157) | `HeadUpDisplay::drawWitchspaceDestination` `Core/HeadUpDisplay.cpp:2632` | ✅ |
| `-[HeadUpDisplay drawCabinTempBar:]` (2191) | `HeadUpDisplay::drawCabinTempBar` `Core/HeadUpDisplay.cpp:2684` | ✅ |
| `-[HeadUpDisplay drawWeaponTempBar:]` (2232) | `HeadUpDisplay::drawWeaponTempBar` `Core/HeadUpDisplay.cpp:2733` | ✅ |
| `-[HeadUpDisplay drawAltitudeBar:]` (2265) | `HeadUpDisplay::drawAltitudeBar` `Core/HeadUpDisplay.cpp:2773` | ✅ |
| `IconForMissileRole` (2311) | `IconForMissileRole` + `MissileIconDefinition` `Core/HeadUpDisplay.cpp:2838`, `:2833` | ✅ |
| `-[HeadUpDisplay drawIconForMissile:selected:status:x:y:width:height:alpha:]` (2351) | `HeadUpDisplay::drawIconForMissile` `Core/HeadUpDisplay.cpp:2880` | ✅ |
| `-[HeadUpDisplay drawIconForEmptyPylonAtX:y:width:height:alpha:]` (2404) | `HeadUpDisplay::drawIconForEmptyPylonAtX` `Core/HeadUpDisplay.cpp:2936` | ✅ |
| `-[HeadUpDisplay drawMissileDisplay:]` (2420) | `HeadUpDisplay::drawMissileDisplay` `Core/HeadUpDisplay.cpp:2949` | ✅ |
| `-[HeadUpDisplay drawTargetReticle:]` (2489) | `HeadUpDisplay::drawTargetReticle` `Core/HeadUpDisplay.cpp:1969` | ✅ |
| `-[HeadUpDisplay drawSecondaryTargetReticle:]` (2503) | `HeadUpDisplay::drawSecondaryTargetReticle` `Core/HeadUpDisplay.cpp:1990` (weak-ref slots) | ✅ |
| `-[HeadUpDisplay drawWaypoints:]` (2532) | `HeadUpDisplay::drawWaypoints` `Core/HeadUpDisplay.cpp:2028` | ❌ |
| `-[HeadUpDisplay drawStatusLight:]` (2545) | `HeadUpDisplay::drawStatusLight` `Core/HeadUpDisplay.cpp:3027` | ✅ |
| `-[HeadUpDisplay drawDirectionCue:]` (2599) | `HeadUpDisplay::drawDirectionCue` `Core/HeadUpDisplay.cpp:3093` | ✅ |
| `-[HeadUpDisplay drawClock:]` (2685) | `HeadUpDisplay::drawClock` `Core/HeadUpDisplay.cpp:3184` | ✅ |
| `-[HeadUpDisplay drawPrimedEquipment:]` (2706) | `HeadUpDisplay::drawPrimedEquipment` `Core/HeadUpDisplay.cpp:3213` | ✅ |
| `-[HeadUpDisplay drawASCTarget:]` (2757) | `HeadUpDisplay::drawASCTarget` `Core/HeadUpDisplay.cpp:3279` | ✅ |
| `-[HeadUpDisplay drawWeaponsOfflineText:]` (2789) | `HeadUpDisplay::drawWeaponsOfflineText` `Core/HeadUpDisplay.cpp:3324` | ✅ |
| `-[HeadUpDisplay drawFPSInfoCounter:]` (2821) | `HeadUpDisplay::drawFPSInfoCounter` `Core/HeadUpDisplay.cpp:3368` (`%.2f`→`{:.2f}`) | ✅ |
| `-[HeadUpDisplay drawScoopStatus:]` (2860) | `HeadUpDisplay::drawScoopStatus` `Core/HeadUpDisplay.cpp:3422` (alpha default 0.75) | ✅ |
| `-[HeadUpDisplay drawStickSensitivityIndicator:]` (2961) | `HeadUpDisplay::drawStickSensitivityIndicator` `Core/HeadUpDisplay.cpp:3531` | ✅ |
| `-[HeadUpDisplay drawSurroundInternal:color:]` (3008) | `HeadUpDisplay::drawSurroundInternal` `Core/HeadUpDisplay.cpp:1237` | ✅ |
| `-[HeadUpDisplay drawSurround:]` (3032) | `HeadUpDisplay::drawSurround` `Core/HeadUpDisplay.cpp:1270` | ✅ |
| `-[HeadUpDisplay drawGreenSurround:]` (3048) | `HeadUpDisplay::drawGreenSurround` `Core/HeadUpDisplay.cpp:1285` | ✅ |
| `-[HeadUpDisplay drawYellowSurround:]` (3053) | `HeadUpDisplay::drawYellowSurround` `Core/HeadUpDisplay.cpp:1289` | ✅ |
| `-[HeadUpDisplay drawTrumbles:]` (3058) | `HeadUpDisplay::drawTrumbles` `Core/HeadUpDisplay.cpp:3590` | ❌ |
| `-[HeadUpDisplay drawMultiFunctionDisplay:withText:asIndex:]` (3068) | `HeadUpDisplay::drawMultiFunctionDisplay` `Core/HeadUpDisplay.cpp:1293` | ✅ |
| `hudDrawIndicatorAt` (3135) | `hudDrawIndicatorAt` `Core/HeadUpDisplay.cpp:3707` | ✅ |
| `hudDrawMarkerAt` (3158) | `hudDrawMarkerAt` `Core/HeadUpDisplay.cpp:3730` | ✅ |
| `hudDrawBarAt` (3181) | `hudDrawBarAt` `Core/HeadUpDisplay.cpp:3753` | ✅ |
| `hudDrawSurroundAt` (3206) | `hudDrawSurroundAt` `Core/HeadUpDisplay.cpp:3778` | ✅ |
| `hudDrawStatusIconAt` (3219) | `hudDrawStatusIconAt` `Core/HeadUpDisplay.cpp:3790` | ✅ |
| `hudDrawReticleOnTarget` (3236) *(added; multi-line signature)* | `hudDrawReticleOnTarget` `Core/HeadUpDisplay.cpp:3808` (accuracy probability, `%0.3f`, wormhole fall-through) | ✅ |
| `hudDrawWaypoint` (3430) | `hudDrawWaypoint` `Core/HeadUpDisplay.cpp:4053` | ✅ |
| `hudRotateViewpointForVirtualDepth` (3495) | `hudRotateViewpointForVirtualDepth` `Core/HeadUpDisplay.cpp:4125` | ✅ |
| `InitTextEngine` (3564) | `InitTextEngine` `Core/HeadUpDisplay.cpp:4201` | ✅ |
| `OOHUDResetTextEngine` (3596) | `OOHUDResetTextEngine` `Core/HeadUpDisplay.cpp:4239` | ✅ |
| `drawCharacterQuad` (3602) | `drawCharacterQuad` `Core/HeadUpDisplay.cpp:4247` | ✅ |
| `OORectFromString` (3624) | `OORectFromString` + `ConvertedString` `Core/HeadUpDisplay.cpp:4271`, `:4232` | ✅ |
| `OOStringWidthInEm` (3642) | `OOStringWidthInEm` `Core/HeadUpDisplay.cpp:4289` | ✅ |
| `drawHighlight` (3647) | `drawHighlight` `Core/HeadUpDisplay.cpp:4295` | ✅ |
| `OODrawString` (3676) | `OODrawString` `Core/HeadUpDisplay.cpp:4323` | ✅ |
| `OODrawStringAligned` (3681) | `OODrawStringAligned` `Core/HeadUpDisplay.cpp:4328` | ✅ |
| `OOStartDrawingStrings` (3688) | `OOStartDrawingStrings` `Core/HeadUpDisplay.cpp:4335` | ✅ |
| `OODrawStringQuadsAligned` (3697) | `OODrawStringQuadsAligned` `Core/HeadUpDisplay.cpp:4344` | ✅ |
| `OOStopDrawingStrings` (3717) | `OOStopDrawingStrings` `Core/HeadUpDisplay.cpp:4364` | ✅ |
| `OODrawHilightedString` (3727) | `OODrawHilightedString` `Core/HeadUpDisplay.cpp:4373` | ✅ |
| `OODrawPlanetInfo` (3749) | `OODrawPlanetInfo` `Core/HeadUpDisplay.cpp:4396` (via `HeadUpDisplayUniverseGUISetGLColorFromSetting` :4820) | ✅ |
| `OODrawHilightedPlanetInfo` (3802) | `OODrawHilightedPlanetInfo` `Core/HeadUpDisplay.cpp:4451` | ✅ |
| `GLDrawNonlinearCascadeWeapon` (3834) | `GLDrawNonlinearCascadeWeapon` `Core/HeadUpDisplay.cpp:4483` (`std::array` buffers) | ✅ |
| `nonlinearScannerFunc` (3901) | `nonlinearScannerFunc` `Core/HeadUpDisplay.cpp:4556` | ✅ |
| `drawScannerGrid` (3914) | `drawScannerGrid` `Core/HeadUpDisplay.cpp:4567` | ✅ |
| `DrawSpecialOval` (4050) | `DrawSpecialOval` `Core/HeadUpDisplay.cpp:4718` | ✅ |
| `-[HeadUpDisplay setLineWidth:]` (4069) | `HeadUpDisplay::setLineWidth` `Core/HeadUpDisplay.cpp:914` | ✅ |
| `-[HeadUpDisplay lineWidth]` (4074) | `HeadUpDisplay::getLineWidth` `Core/HeadUpDisplay.cpp:916` | ✅ |
| `-[NSString(OODisplayEncoding) cStringUsingOoliteEncoding]` (4083) | — (no counterpart; no caller in either tree) | ➖ |
| `-[NSString(OODisplayEncoding) cStringUsingOoliteEncodingAndRemapping]` (4092) | — (no counterpart; no caller in either tree) | ➖ |
| `-[OOPolygonSprite(OOHUDBeaconIcon) oo_drawHUDBeaconIconAt:size:alpha:z:]` (4105) | `OOPolygonSprite::drawHUDBeaconIconAt` → `OOPolygonSpriteDrawHUDBeaconIcon` `Core/HeadUpDisplay.cpp:4741`, `:4746` | ✅ |
| `-[NSString(OOHUDBeaconIcon) oo_drawHUDBeaconIconAt:size:alpha:z:]` (4128) | replaced by `OOHUDBeaconCodeIcon::drawHUDBeaconIconAt` `Core/HeadUpDisplay.cpp:4769` | ➖ |
| `SetGLColourFromInfo` (4135) | `SetGLColourFromInfo` `Core/HeadUpDisplay.cpp:4777` | ✅ |
| `GetRGBAArrayFromInfo` (4152) | `GetRGBAArrayFromInfo` `Core/HeadUpDisplay.cpp:4793` | ✅ |

**Differences:**

- ❌ **low** (still open) — waypoints are iterated in `std::map` key order (sorted waypoint keys) instead of `NSDictionary -allValues` hash order; only the overdraw order of overlapping translucent waypoint markers can differ — upstream `Core/HeadUpDisplay.m:2540` ↔ port `Core/HeadUpDisplay.cpp:2036-2043`
- ❌ **low** (still open) — `drawTrumbles` dereferences `PLAYER` unchecked (`player->trumbleArray()`, `player->getTrumbleCount()`); upstream messaged nil and drew nothing. Crashes only if a HUD renders with no player — upstream `Core/HeadUpDisplay.m:3060-3062` ↔ port `Core/HeadUpDisplay.cpp:3591-3595`
- ➖ **low** (still open) — `NSString(OODisplayEncoding)` (`cStringUsingOoliteEncoding`, `…AndRemapping`) has no port; no caller existed outside this file — upstream `Core/HeadUpDisplay.m:4083-4099`
- ➖ **low** (still open) — `NSString(OOHUDBeaconIcon)` replaced by class `OOHUDBeaconCodeIcon`; same offset (`x-2.5w`, `y-3h`), 2× size; built from the first UTF-16 unit or "" by `ShipEntity`/`OOWaypointEntity`/`OOVisualEffectEntity` (`Core/Entities/ShipEntity.cpp:1825`) — upstream `Core/HeadUpDisplay.m:4128` ↔ port `Core/HeadUpDisplay.cpp:4769`
- ➖ **low** (still open) — one-argument `-initWithDictionary:` folded into the two-argument form with `nullopt` (= `inFile:nil`) — upstream `Core/HeadUpDisplay.m:210` ↔ port `Core/HeadUpDisplay.cpp:342`
- ✅ (subtle) — `OODrawPlanetInfo` colours go through `HeadUpDisplayUniverseGUISetGLColorFromSetting`, which dereferences `UNIVERSE->getGui()` unchecked where upstream messaged a possibly-nil `[UNIVERSE gui]`. Only caller is `GuiDisplayGen::drawStarChart`, reached when `this == UNIVERSE->getGui()`, so not reachable with a null GUI — upstream `Core/HeadUpDisplay.m:3771` ↔ port `Core/HeadUpDisplay.cpp:4823`
- ✅ (subtle) — `kDials` omits `drawDirectionCue:`/`drawSecondaryTargetReticle:` (upstream `respondsToSelector:` accepted them); neither is in `whitelist.plist` `hud_dial_methods`, so acceptance and the "not in whitelist"/"not implemented" logs are unchanged — upstream `Core/HeadUpDisplay.m:692-705` ↔ port `Core/HeadUpDisplay.cpp:137-187`, `:820-842`
- ✅ (subtle) — reticle colours stop at the first unparseable colour (as `+arrayWithObjects:`); `ReticleColorAt` raises the same range text past the end, so the `!reticleDisplayColor` fallbacks stay unreachable as upstream — port `Core/HeadUpDisplay.cpp:227-236`, `:387-396`, `:3951-3958`
- ✅ (subtle) — non-dictionary MFD entry still raises "Index 1 is out of range 0" on draw via `GetCurrentCachedInfo` (empty tuple in upstream) — port `Core/HeadUpDisplay.cpp:119-125`, `:131`
- ✅ (subtle) — custom dials with no `data_source` pass `""` to `dialCustom*` where upstream passed nil; differs only for a script dial registered under "" — port `Core/HeadUpDisplay.cpp:2054`, `:2100`, `:2138`, `:2198`, `:2239`
- ✅ (checked) — all 156 `#define`s in `HeadUpDisplay.h` match (only `YES`→`true`, `@""`→`""`, and the null-guarded `Z1`); hud.plist defaults (`overall_alpha` 0.75, `crosshair_scale` 32, `crosshair_width` 1.5, `cloak_indicator_on_status_light` YES, reticle green/red/cyan), message/comm-log GUI resets, font metrics (×0.13, ≤256 glyphs, ⅛ baseline, 31/32 non-printing) and draw order (crosshairs → legends → dials → MFDs) re-read and unchanged. `cxx_` prefixes dropped since the previous run (T107), no behaviour change.

## OOCrosshairs

<a id="oocrosshairs"></a>
Upstream `src/Core/OOCrosshairs.m` ↔ `Core/OOCrosshairs.cpp` (188 / 153 lines)

**Status:** done — 5 rows: 5 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCrosshairs initWithPoints:scale:color:overallAlpha:]` (53) | `OOCrosshairs::OOCrosshairs` `Core/OOCrosshairs.cpp:36` (same alpha/colour-alpha gate) | ✅ |
| `-[OOCrosshairs dealloc]` (67) | `~OOCrosshairs() = default` `Core/OOCrosshairs.cpp:43` (`_data` is now `std::vector`) | ✅ |
| `-[OOCrosshairs render]` (74) | `OOCrosshairs::render` `Core/OOCrosshairs.cpp:45` (same GL state, stride 6, `_count*2` lines) | ✅ |
| `-[OOCrosshairs setUpDataWithPoints:scale:color:overallAlpha:]` (105) | `OOCrosshairs::setUpDataWithPoints` `Core/OOCrosshairs.cpp:79` | ✅ |
| `-[OOCrosshairs setUpDataForOnePoint:scale:colorComps:overallAlpha:data:]` (133) | `OOCrosshairs::setUpDataForOnePoint` `Core/OOCrosshairs.cpp:103` (same double clamp, red-point fallback) | ✅ |

**Differences:**

- ✅ (subtle) — nil `color` kept default green in upstream (nil `getRed:` no-op); port guards `color != nullptr`. A non-array point (`oo_arrayAtIndex:` nil) gives the red centre point via `pointInfo != nullptr`. `_data` moved from `malloc` to a zero-filled `std::vector` (T023), `_count` is `std::size_t` — upstream `Core/OOCrosshairs.m:119`, `:142` ↔ port `Core/OOCrosshairs.cpp:90`, `:109`
- ✅ (subtle) — `render` reads `display_z` through a null-guarded `UNIVERSE->getGameView()` (0 when absent, as nil messaging gave) — upstream `Core/OOCrosshairs.m:84` ↔ port `Core/OOCrosshairs.cpp:54-58`

## OOMouseInteractionMode

<a id="oomouseinteractionmode"></a>
Upstream `src/Core/OOMouseInteractionMode.m` ↔ `Core/OOMouseInteractionMode.cpp` (74 / 75 lines)

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOStringFromMouseInteractionMode` (28) | `OOStringFromMouseInteractionMode` `Core/OOMouseInteractionMode.cpp:32` (same 4 names, `<unknown mode %u>` fallback) | ✅ |
| `OOMouseInteractionModeIsUIScreen` (44) | `OOMouseInteractionModeIsUIScreen` `Core/OOMouseInteractionMode.cpp:47` | ✅ |
| `OOMouseInteractionModeIsFlightMode` (60) | `OOMouseInteractionModeIsFlightMode` `Core/OOMouseInteractionMode.cpp:62` | ✅ |

**Differences:**

- ✅ (subtle) — returns `std::string` instead of `NSString*`; enum is now `enum class` (T067) and the fallback formats `static_cast<unsigned int>(mode)` with `std::format`, same text as `%u` — upstream `Core/OOMouseInteractionMode.m:41` ↔ port `Core/OOMouseInteractionMode.cpp:44`

