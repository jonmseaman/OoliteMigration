# Parity findings: Scripting (JS engine, OOJS*, legacy scripts, JS console)

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## OOJSConsole

<a id="oojsconsole"></a>
Upstream `src/Core/Debug/OOJSConsole.m` ↔ `Core/Debug/OOJSConsole.cpp`

**Status:** done — 31 rows: 24 ✅ 5 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sConsoleClass` / `sConsoleProperties` / `sConsoleMethods` / `sConsoleSettingsClass` tables (98–222) | same names `Core/Debug/OOJSConsole.cpp:110-240` (same names, IDs, flags, min-args, `#if` guards) | ✅ |
| `InitOOJSConsole()` (224) | `InitOOJSConsole` `Core/Debug/OOJSConsole.cpp:242` (`ConsoleConverter` :298 replaces `OOJSBasicPrivateObjectConverter`) | ✅ |
| `OOJSConsoleDestroy()` (233) | `OOJSConsoleDestroy` `Core/Debug/OOJSConsole.cpp:251` | ✅ |
| `DebugMonitorToJSConsole()` (238) | `DebugMonitorToJSConsole` `Core/Debug/OOJSConsole.cpp:308` (+ `SetMonitorPrivate` :262) | ⚠️ |
| `ConsoleGetProperty()` (287) | `ConsoleGetProperty` `Core/Debug/OOJSConsole.cpp:354` | ✅ |
| `ConsoleSetProperty()` (382) | `ConsoleSetProperty` `Core/Debug/OOJSConsole.cpp:451` | ✅ |
| `DoWeDefineAllDebugFlags()` (461) | `DoWeDefineAllDebugFlags` `Core/Debug/OOJSConsole.cpp:534` | ✅ |
| `ConsoleFinalize()` (489) | `ConsoleFinalize` `Core/Debug/OOJSConsole.cpp:564` | ✅ |
| `ConsoleSettingsDeleteProperty()` (499) | `ConsoleSettingsDeleteProperty` `Core/Debug/OOJSConsole.cpp:578` (+ `MonitorFromJSObject` :274) | ✅ |
| `ConsoleSettingsGetProperty()` (523) | `ConsoleSettingsGetProperty` `Core/Debug/OOJSConsole.cpp:603` | ✅ |
| `ConsoleSettingsSetProperty()` (553) | `ConsoleSettingsSetProperty` `Core/Debug/OOJSConsole.cpp:632` | ✅ |
| `ConsoleConsoleMessage()` (594) | `ConsoleConsoleMessage` `Core/Debug/OOJSConsole.cpp:673` | ✅ |
| `ConsoleClearConsole()` (648) | `ConsoleClearConsole` `Core/Debug/OOJSConsole.cpp:728` (+ `ReportNotTheMonitor` :287) | ❌ |
| `ConsoleScriptStack()` (667) | `ConsoleScriptStack` `Core/Debug/OOJSConsole.cpp:747` | ✅ |
| `ConsoleInspectEntity()` (677) | `ConsoleInspectEntity` `Core/Debug/OOJSConsole.cpp:761` | ⚠️ |
| `ConsoleCallObjCMethod()` (698) | `ConsoleCallObjCMethod` `Core/Debug/OOJSConsole.cpp:913` (+ `kMonitorMethods` :809, `CallMonitorMethod` :826) | ❌ |
| `ConsoleSetUpCallObjC()` (724) | `ConsoleSetUpCallObjC` `Core/Debug/OOJSConsole.cpp:956` | ✅ |
| `ConsoleIsExecutableJavaScript()` (742) | `ConsoleIsExecutableJavaScript` `Core/Debug/OOJSConsole.cpp:974` | ✅ |
| `ConsoleDisplayMessagesInClass()` (769) | `ConsoleDisplayMessagesInClass` `Core/Debug/OOJSConsole.cpp:1000` | ✅ |
| `ConsoleSetDisplayMessagesInClass()` (782) | `ConsoleSetDisplayMessagesInClass` `Core/Debug/OOJSConsole.cpp:1013` | ✅ |
| `ConsoleWriteLogMarker()` (799) | `ConsoleWriteLogMarker` `Core/Debug/OOJSConsole.cpp:1030` | ✅ |
| `ConsoleWriteMemoryStats()` (810) | `ConsoleWriteMemoryStats` `Core/Debug/OOJSConsole.cpp:1041` | ✅ |
| `ConsoleWriteJSMemoryStats()` (824) | `ConsoleWriteJSMemoryStats` `Core/Debug/OOJSConsole.cpp:1055` | ✅ |
| `ConsoleGarbageCollect()` (838) | `ConsoleGarbageCollect` `Core/Debug/OOJSConsole.cpp:1069` | ⚠️ |
| `DumpCallback()` (858) | `DumpCallback` `Core/Debug/OOJSConsole.cpp:1089` | ✅ |
| `ConsoleDumpNamedRoots()` (880) | `ConsoleDumpNamedRoots` `Core/Debug/OOJSConsole.cpp:1111` | ⚠️ |
| `ConsoleDumpHeap()` (905) | `ConsoleDumpHeap` `Core/Debug/OOJSConsole.cpp:1136` | ⚠️ |
| `ConsoleProfile()` (926) | `ConsoleProfile` `Core/Debug/OOJSConsole.cpp:1158` | ✅ |
| `ConsoleGetProfile()` (950) | `ConsoleGetProfile` `Core/Debug/OOJSConsole.cpp:1184` | ✅ |
| `ConsoleTrace()` (974) | `ConsoleTrace` `Core/Debug/OOJSConsole.cpp:1210` | ✅ |
| `PerformProfiling()` (997) | `PerformProfiling` `Core/Debug/OOJSConsole.cpp:1236` | ✅ |

**Differences:**

- ❌ **low** — `callObjC()` on a console object: error texts begin `.callObjC(): …` (port `className` is `""`); upstream passed `[monitor oo_jsClassName]`, which is `nil` for OODebugMonitor (NSObject default, `Core/Scripting/OOJavaScriptEngine.m:1284`), so upstream's text began `(null).callObjC(): …`. Debug builds only — upstream `Core/Debug/OOJSConsole.m:714`, `Core/Scripting/OOJSCall.m:79,102,159,168` ↔ port `Core/Debug/OOJSConsole.cpp:828-901`
- ❌ **low** — "Expected OODebugMonitor, got %s" internal error when `clearConsole` is called with a foreign `this` (`clearConsole.call(x)`): port prints `Entity` for any entity and `(null)` for every other object; upstream printed the class of the object its registered converter returned (e.g. `ShipEntity`, `PlayerEntity`, `OOJSScript`), and `(null)` only for objects without a converter — upstream `Core/Debug/OOJSConsole.m:654-657` ↔ port `Core/Debug/OOJSConsole.cpp:287-294, 734-737`
- ⚠️ **low** — `callObjC()` is no longer a generic selector call: console objects answer only the fixed `kMonitorMethods` table, entities go through the entity name table (`OOJSCallEntityMethod`), and any other converter-backed object (scripts, sounds, timers, equipment info…) now gets "Attempt to call __callObjCMethod() for non-Objective-C object" where upstream called its ObjC method (beads oo-9ht.74, oo-9ht.44, oo-4aq6a.5; proposed ADR-0056 amendment oo-9ht.74, code comments). Debug builds only — upstream `Core/Debug/OOJSConsole.m:698-721` ↔ port `Core/Debug/OOJSConsole.cpp:779-953`
- ⚠️ **low** — console and settings objects hold a strong retain of the monitor (released in `ConsoleFinalize`) instead of `[monitor weakRetain]`; the monitor is a never-released singleton, so no observable lifetime change (code comment, bead oo-9ht.74). `JS_EnterLocalRootScope`/`Leave` and its `NSCAssert` are gone (the QuickJS façade has no local root scopes) — upstream `Core/Debug/OOJSConsole.m:247-279` ↔ port `Core/Debug/OOJSConsole.cpp:256-271, 308-352`
- ⚠️ **low** — `inspectEntity()` calls `oo::InspectEntity()` (virtual, no-op unless overridden) instead of `-inspect` added by the Mac Debug OXP's category; on non-Mac upstream it was already a no-op (code comment, bead oo-dpyk8) — upstream `Core/Debug/OOJSConsole.m:683-689` ↔ port `Core/Debug/OOJSConsole.cpp:767-771`
- ⚠️ **low** — engine replacement (SpiderMonkey → QuickJS-ng, `ooscript/README.md`): `garbageCollect()` keeps the text `Bytes before: %u Bytes after: %u` but the numbers are QuickJS `malloc_size`; `dumpNamedRoots()` writes an empty `js-roots.txt` and still returns `true` (`ooscript::dumpNamedRoots` is a stub; its result is ignored, as upstream ignored `JS_DumpNamedRoots`'s); `dumpHeap()` writes `JS_DumpMemoryUsage` output instead of a heap dump — upstream `Core/Debug/OOJSConsole.m:842-846, 894, 913` ↔ port `Core/Debug/OOJSConsole.cpp:1073-1077, 1125, 1145`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3824-3828, 4103-4110`
- Message protocol unchanged: `consoleMessage(colour, message [, start, length])` reads args in the same order; emphasis only with argc > 3 and both numbers convertible; the one-argument form becomes colour `command-result`; the zero-argument form warns `Console.consoleMessage() called with no parameters.`; the time limiter is paused/resumed on every path as upstream.
- Settings object: get answers `undefined` for a missing key; set with `null`/`undefined` deletes the key; unconvertible values warn `debugConsole.settings: could not convert %s to native object.` with `(null)` for a nil string as `%@` printed; delete answers `true`. Values now pass through `oo::PList` instead of arbitrary ObjC objects.
- `isExecutableJavaScript()` now depends on `ooscript::bufferIsCompilableUnit` (QuickJS compile-only eval, "ended early" check); the binding is identical but the engines may disagree on edge inputs — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3967`
- Debug-flag constants, `pedanticMode` (maps to `ContextOption::Strict`), `detailLevel` (nil/unknown string → `DETAIL_LEVEL_MINIMUM` on both sides) and the `UNIVERSE == nullptr` guards match upstream's nil-messaging results.

## PlayerEntityLegacyScriptEngine

<a id="playerentitylegacyscriptengine"></a>
Upstream `src/Core/Entities/PlayerEntityLegacyScriptEngine.m` ↔ `Core/Entities/PlayerEntityLegacyScriptEngine.cpp`

**Status:** done — 153 rows: 146 ✅ 6 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| Log-class constants `kOOLog*` (56–91) | `kOOLog*` `Core/Entities/PlayerEntityLegacyScriptEngine.cpp:65-100` (all 32 strings identical) | ✅ |
| `ACTIONS_TEMP_PREFIX`, `sMissionStringValue`, `sCurrentMissionKey`, `scriptTarget`, `sRunningScript`, `shipsFound` (93–98, 244, 835) | same names `PlayerEntityLegacyScriptEngine.cpp:102-113, 379, 971` (nil → `std::nullopt`) | ✅ |
| `CurrentScriptNameOr()` (112) | `CurrentScriptNameOr` `PlayerEntityLegacyScriptEngine.cpp:116` | ✅ |
| `CurrentScriptDesc()` (120) | `CurrentScriptDescription` `PlayerEntityLegacyScriptEngine.cpp:124` | ✅ |
| `PerformScriptActions()` (130) | `PerformScriptActions` `PlayerEntityLegacyScriptEngine.cpp:259` | ✅ |
| `PerformConditionalStatment()` (142) | `PerformConditionalStatment` `PlayerEntityLegacyScriptEngine.cpp:273` | ✅ |
| `PerformActionStatment()` (165) | `PerformActionStatment` `PlayerEntityLegacyScriptEngine.cpp:291` | ⚠️ |
| `TestScriptConditions()` (209) | `TestScriptConditions` `PlayerEntityLegacyScriptEngine.cpp:338` | ✅ |
| `-[PlayerEntity(Scripting) setScriptTarget:]` (223) | `PlayerEntity::setScriptTarget` `PlayerEntityLegacyScriptEngine.cpp:353` (plus port-only `setScriptTargetToSelf` :358) | ✅ |
| `-[PlayerEntity(Scripting) scriptTarget]` (228) | `PlayerEntity::scriptTarget` `PlayerEntityLegacyScriptEngine.cpp:363` | ✅ |
| `RecursiveRemapStatus()` (233) | `RecursiveRemapStatus` `PlayerEntityLegacyScriptEngine.cpp:368` | ✅ |
| `-[PlayerEntity(Scripting) worldScriptsRequiringTickle]` (247) | `PlayerEntity::getWorldScriptsRequiringTickle` `PlayerEntityLegacyScriptEngine.cpp:382` | ⚠️ |
| `-[PlayerEntity(Scripting) checkScript]` (266) | `PlayerEntity::checkScript` `PlayerEntityLegacyScriptEngine.cpp:399` | ⚠️ |
| `-[PlayerEntity(Scripting) runScriptActions:withContextName:forTarget:]` (321) | `PlayerEntity::runScriptActions` `PlayerEntityLegacyScriptEngine.cpp:460` | ✅ |
| `-[PlayerEntity(Scripting) runUnsanitizedScriptActions:allowingAIMethods:withContextName:forTarget:]` (349) | `PlayerEntity::runUnsanitizedScriptActions` `PlayerEntityLegacyScriptEngine.cpp:488` | ✅ |
| `-[PlayerEntity(Scripting) scriptTestConditions:]` (356) | `PlayerEntity::scriptTestConditions` `PlayerEntityLegacyScriptEngine.cpp:493` | ✅ |
| `-[PlayerEntity(Scripting) scriptTestCondition:]` (374) | `PlayerEntity::scriptTestCondition` `PlayerEntityLegacyScriptEngine.cpp:513` | ⚠️ |
| `-[PlayerEntity(Scripting) expandScriptRightHandSide:]` (542) | `PlayerEntity::expandScriptRightHandSide` `PlayerEntityLegacyScriptEngine.cpp:676` | ✅ |
| `-[PlayerEntity(Scripting) missionVariables]` (574) | `PlayerEntity::missionVariables` `PlayerEntityLegacyScriptEngine.cpp:709` | ✅ |
| `-[PlayerEntity(Scripting) missionVariableForKey:]` (579) | `PlayerEntity::missionVariableForKey` `PlayerEntityLegacyScriptEngine.cpp:714` | ✅ |
| `-[PlayerEntity(Scripting) setMissionVariable:forKey:]` (587) | `PlayerEntity::setMissionVariable` `PlayerEntityLegacyScriptEngine.cpp:721` | ✅ |
| `-[PlayerEntity(Scripting) localVariablesForMission:]` (597) | `PlayerEntity::localVariablesForMission` `PlayerEntityLegacyScriptEngine.cpp:736` | ⚠️ |
| `-[PlayerEntity(Scripting) localVariableForKey:andMission:]` (613) | `PlayerEntity::localVariableForKey` `PlayerEntityLegacyScriptEngine.cpp:748` | ✅ |
| `-[PlayerEntity(Scripting) setLocalVariable:forKey:andMission:]` (618) | `PlayerEntity::setLocalVariable` `PlayerEntityLegacyScriptEngine.cpp:759` | ✅ |
| `-[PlayerEntity(Scripting) missionsList]` (632) | `PlayerEntity::missionsList` `PlayerEntityLegacyScriptEngine.cpp:773` | ⚠️ |
| `-[PlayerEntity(Scripting) replaceVariablesInString:]` (691) | `PlayerEntity::replaceVariablesInString` `PlayerEntityLegacyScriptEngine.cpp:829` | ✅ |
| `-[PlayerEntity(Scripting) setMissionDescription:]` (724) | `PlayerEntity::setMissionDescription(textKey)` `PlayerEntityLegacyScriptEngine.cpp:866` | ✅ |
| `-[PlayerEntity(Scripting) setMissionDescription:forMission:]` (729) | `PlayerEntity::setMissionDescription(textKey, key)` `PlayerEntityLegacyScriptEngine.cpp:871` | ✅ |
| `-[PlayerEntity(Scripting) setMissionInstructions:forMission:]` (742) | `PlayerEntity::setMissionInstructions` `PlayerEntityLegacyScriptEngine.cpp:884` | ✅ |
| `-[PlayerEntity(Scripting) setMissionInstructionsList:forMission:]` (755) | `PlayerEntity::setMissionInstructionsList` `PlayerEntityLegacyScriptEngine.cpp:895` | ✅ |
| `-[PlayerEntity(Scripting) clearMissionDescription]` (777) | `PlayerEntity::clearMissionDescription` `PlayerEntityLegacyScriptEngine.cpp:915` | ✅ |
| `-[PlayerEntity(Scripting) clearMissionDescriptionForMission:]` (782) | `PlayerEntity::clearMissionDescriptionForMission` `PlayerEntityLegacyScriptEngine.cpp:925` | ✅ |
| `-[PlayerEntity(Scripting) mission_string]` (795) | `PlayerEntity::mission_string` `PlayerEntityLegacyScriptEngine.cpp:931` | ✅ |
| `-[PlayerEntity(Scripting) status_string]` (800) | `PlayerEntity::status_string` `PlayerEntityLegacyScriptEngine.cpp:936` | ✅ |
| `-[PlayerEntity(Scripting) gui_screen_string]` (805) | `PlayerEntity::gui_screen_string` `PlayerEntityLegacyScriptEngine.cpp:941` | ✅ |
| `-[PlayerEntity(Scripting) galaxy_number]` (810) | `PlayerEntity::getGalaxy_number` `PlayerEntityLegacyScriptEngine.cpp:946` (by-name table maps `"galaxy_number"` to it, `OOEntityCalledByNameTable.h:2819`) | ✅ |
| `-[PlayerEntity(Scripting) planet_number]` (815) | `PlayerEntity::planet_number` `PlayerEntityLegacyScriptEngine.cpp:951` | ✅ |
| `-[PlayerEntity(Scripting) score_number]` (820) | `PlayerEntity::score_number` `PlayerEntityLegacyScriptEngine.cpp:956` | ✅ |
| `-[PlayerEntity(Scripting) credits_number]` (825) | `PlayerEntity::credits_number` `PlayerEntityLegacyScriptEngine.cpp:961` | ✅ |
| `-[PlayerEntity(Scripting) scriptTimer_number]` (830) | `PlayerEntity::scriptTimer_number` `PlayerEntityLegacyScriptEngine.cpp:966` | ✅ |
| `-[PlayerEntity(Scripting) shipsFound_number]` (836) | `PlayerEntity::shipsFound_number` `PlayerEntityLegacyScriptEngine.cpp:972` | ✅ |
| `-[PlayerEntity(Scripting) commanderLegalStatus_number]` (841) | `PlayerEntity::commanderLegalStatus_number` `PlayerEntityLegacyScriptEngine.cpp:977` | ✅ |
| `-[PlayerEntity(Scripting) setLegalStatus:]` (846) | `PlayerEntity::setLegalStatus` `PlayerEntityLegacyScriptEngine.cpp:982` | ✅ |
| `-[PlayerEntity(Scripting) commanderLegalStatus_string]` (851) | `PlayerEntity::commanderLegalStatus_string` `PlayerEntityLegacyScriptEngine.cpp:987` | ✅ |
| `-[PlayerEntity(Scripting) d100_number]` (856) | `PlayerEntity::d100_number` `PlayerEntityLegacyScriptEngine.cpp:992` | ✅ |
| `-[PlayerEntity(Scripting) pseudoFixedD100_number]` (862) | `PlayerEntity::pseudoFixedD100_number` `PlayerEntityLegacyScriptEngine.cpp:998` | ✅ |
| `-[PlayerEntity(Scripting) d256_number]` (867) | `PlayerEntity::d256_number` `PlayerEntityLegacyScriptEngine.cpp:1003` | ✅ |
| `-[PlayerEntity(Scripting) pseudoFixedD256_number]` (873) | `PlayerEntity::pseudoFixedD256_number` `PlayerEntityLegacyScriptEngine.cpp:1009` | ✅ |
| `-[PlayerEntity(Scripting) clock_number]` (878) | `PlayerEntity::clock_number` `PlayerEntityLegacyScriptEngine.cpp:1014` | ✅ |
| `-[PlayerEntity(Scripting) clock_secs_number]` (883) | `PlayerEntity::clock_secs_number` `PlayerEntityLegacyScriptEngine.cpp:1019` | ✅ |
| `-[PlayerEntity(Scripting) clock_mins_number]` (888) | `PlayerEntity::clock_mins_number` `PlayerEntityLegacyScriptEngine.cpp:1024` | ✅ |
| `-[PlayerEntity(Scripting) clock_hours_number]` (893) | `PlayerEntity::clock_hours_number` `PlayerEntityLegacyScriptEngine.cpp:1029` | ✅ |
| `-[PlayerEntity(Scripting) clock_days_number]` (898) | `PlayerEntity::clock_days_number` `PlayerEntityLegacyScriptEngine.cpp:1034` | ✅ |
| `-[PlayerEntity(Scripting) fuelLevel_number]` (903) | `PlayerEntity::fuelLevel_number` `PlayerEntityLegacyScriptEngine.cpp:1039` | ✅ |
| `-[PlayerEntity(Scripting) dockedAtMainStation_bool]` (908) | `PlayerEntity::dockedAtMainStation_bool` `PlayerEntityLegacyScriptEngine.cpp:1044` | ✅ |
| `-[PlayerEntity(Scripting) foundEquipment_bool]` (916) | `PlayerEntity::foundEquipment_bool` `PlayerEntityLegacyScriptEngine.cpp:1052` | ✅ |
| `-[PlayerEntity(Scripting) sunWillGoNova_bool]` (921) | `PlayerEntity::sunWillGoNova_bool` `PlayerEntityLegacyScriptEngine.cpp:1057` | ✅ |
| `-[PlayerEntity(Scripting) sunGoneNova_bool]` (926) | `PlayerEntity::sunGoneNova_bool` `PlayerEntityLegacyScriptEngine.cpp:1062` | ✅ |
| `-[PlayerEntity(Scripting) missionChoice_string]` (931) | `PlayerEntity::missionChoice_string` `PlayerEntityLegacyScriptEngine.cpp:1067` | ✅ |
| `-[PlayerEntity(Scripting) missionKeyPress_string]` (936) | `PlayerEntity::missionKeyPress_string` `PlayerEntityLegacyScriptEngine.cpp:1072` | ✅ |
| `-[PlayerEntity(Scripting) dockedTechLevel_number]` (941) | `PlayerEntity::dockedTechLevel_number` `PlayerEntityLegacyScriptEngine.cpp:1077` | ✅ |
| `-[PlayerEntity(Scripting) dockedStationName_string]` (950) | `PlayerEntity::dockedStationName_string` `PlayerEntityLegacyScriptEngine.cpp:1086` | ✅ |
| `-[PlayerEntity(Scripting) systemGovernment_string]` (962) | `PlayerEntity::systemGovernment_string` `PlayerEntityLegacyScriptEngine.cpp:1094` | ✅ |
| `-[PlayerEntity(Scripting) systemGovernment_number]` (972) | `PlayerEntity::systemGovernment_number` `PlayerEntityLegacyScriptEngine.cpp:1100` | ✅ |
| `-[PlayerEntity(Scripting) systemEconomy_string]` (978) | `PlayerEntity::systemEconomy_string` `PlayerEntityLegacyScriptEngine.cpp:1105` | ✅ |
| `-[PlayerEntity(Scripting) systemEconomy_number]` (988) | `PlayerEntity::systemEconomy_number` `PlayerEntityLegacyScriptEngine.cpp:1111` | ✅ |
| `-[PlayerEntity(Scripting) systemTechLevel_number]` (994) | `PlayerEntity::systemTechLevel_number` `PlayerEntityLegacyScriptEngine.cpp:1116` | ✅ |
| `-[PlayerEntity(Scripting) systemPopulation_number]` (1000) | `PlayerEntity::systemPopulation_number` `PlayerEntityLegacyScriptEngine.cpp:1121` | ✅ |
| `-[PlayerEntity(Scripting) systemProductivity_number]` (1006) | `PlayerEntity::systemProductivity_number` `PlayerEntityLegacyScriptEngine.cpp:1126` | ✅ |
| `-[PlayerEntity(Scripting) commanderName_string]` (1012) | `PlayerEntity::commanderName_string` `PlayerEntityLegacyScriptEngine.cpp:1131` | ✅ |
| `-[PlayerEntity(Scripting) commanderRank_string]` (1017) | `PlayerEntity::commanderRank_string` `PlayerEntityLegacyScriptEngine.cpp:1136` | ✅ |
| `-[PlayerEntity(Scripting) commanderShip_string]` (1022) | `PlayerEntity::commanderShip_string` `PlayerEntityLegacyScriptEngine.cpp:1141` | ✅ |
| `-[PlayerEntity(Scripting) commanderShipDisplayName_string]` (1027) | `PlayerEntity::commanderShipDisplayName_string` `PlayerEntityLegacyScriptEngine.cpp:1146` | ✅ |
| `-[PlayerEntity(Scripting) expandMessage:]` (1034) | `PlayerEntity::expandMessage` `PlayerEntityLegacyScriptEngine.cpp:1153` | ✅ |
| `-[PlayerEntity(Scripting) commsMessage:]` (1048) | `PlayerEntity::commsMessage` `PlayerEntityLegacyScriptEngine.cpp:1166` | ✅ |
| `-[PlayerEntity(Scripting) commsMessageByUnpiloted:]` (1056) | `PlayerEntity::commsMessageByUnpiloted` `PlayerEntityLegacyScriptEngine.cpp:1175` | ✅ |
| `-[PlayerEntity(Scripting) consoleMessage3s:]` (1061) | `PlayerEntity::consoleMessage3s` `PlayerEntityLegacyScriptEngine.cpp:1180` | ✅ |
| `-[PlayerEntity(Scripting) consoleMessage6s:]` (1066) | `PlayerEntity::consoleMessage6s` `PlayerEntityLegacyScriptEngine.cpp:1186` | ✅ |
| `-[PlayerEntity(Scripting) awardCredits:]` (1071) | `PlayerEntity::awardCredits` `PlayerEntityLegacyScriptEngine.cpp:1192` | ✅ |
| `-[PlayerEntity(Scripting) awardShipKills:]` (1088) | `PlayerEntity::awardShipKills` `PlayerEntityLegacyScriptEngine.cpp:1209` | ✅ |
| `-[PlayerEntity(Scripting) awardEquipment:]` (1098) | `PlayerEntity::awardEquipment` `PlayerEntityLegacyScriptEngine.cpp:1219` | ✅ |
| `-[PlayerEntity(Scripting) removeEquipment:]` (1120) | `PlayerEntity::removeEquipment` `PlayerEntityLegacyScriptEngine.cpp:1244` | ✅ |
| `-[PlayerEntity(Scripting) setPlanetinfo:]` (1140) | `PlayerEntity::setPlanetinfo` `PlayerEntityLegacyScriptEngine.cpp:1265` | ✅ |
| `-[PlayerEntity(Scripting) setSpecificPlanetInfo:]` (1160) | `PlayerEntity::setSpecificPlanetInfo` `PlayerEntityLegacyScriptEngine.cpp:1285` | ✅ |
| `-[PlayerEntity(Scripting) awardCargo:]` (1180) | `PlayerEntity::awardCargo` `PlayerEntityLegacyScriptEngine.cpp:1306` | ✅ |
| `-[PlayerEntity(Scripting) removeAllCargo]` (1216) | `PlayerEntity::removeAllCargo()` `PlayerEntityLegacyScriptEngine.cpp:1343` | ✅ |
| `-[PlayerEntity(Scripting) removeAllCargo:]` (1221) | `PlayerEntity::removeAllCargo(bool)` `PlayerEntityLegacyScriptEngine.cpp:1348` | ✅ |
| `-[PlayerEntity(Scripting) useSpecialCargo:]` (1259) | `PlayerEntity::useSpecialCargo` `PlayerEntityLegacyScriptEngine.cpp:1385` | ✅ |
| `-[PlayerEntity(Scripting) testForEquipment:]` (1269) | `PlayerEntity::testForEquipment` `PlayerEntityLegacyScriptEngine.cpp:1396` | ✅ |
| `-[PlayerEntity(Scripting) awardFuel:]` (1274) | `PlayerEntity::awardFuel` `PlayerEntityLegacyScriptEngine.cpp:1401` | ✅ |
| `-[PlayerEntity(Scripting) messageShipAIs:]` (1286) | `PlayerEntity::messageShipAIs` `PlayerEntityLegacyScriptEngine.cpp:1415` | ✅ |
| `-[PlayerEntity(Scripting) ejectItem:]` (1312) | `PlayerEntity::ejectItem` `PlayerEntityLegacyScriptEngine.cpp:1434` | ✅ |
| `-[PlayerEntity(Scripting) addShips:]` (1319) | `PlayerEntity::addShips` `PlayerEntityLegacyScriptEngine.cpp:1442` | ✅ |
| `-[PlayerEntity(Scripting) addSystemShips:]` (1345) | `PlayerEntity::addSystemShips` `PlayerEntityLegacyScriptEngine.cpp:1467` | ✅ |
| `-[PlayerEntity(Scripting) addShipsAt:]` (1374) | `PlayerEntity::addShipsAt` `PlayerEntityLegacyScriptEngine.cpp:1493` | ✅ |
| `-[PlayerEntity(Scripting) addShipsAtPrecisely:]` (1412) | `PlayerEntity::addShipsAtPrecisely` `PlayerEntityLegacyScriptEngine.cpp:1521` | ✅ |
| `-[PlayerEntity(Scripting) addShipsWithinRadius:]` (1450) | `PlayerEntity::addShipsWithinRadius` `PlayerEntityLegacyScriptEngine.cpp:1549` | ✅ |
| `-[PlayerEntity(Scripting) spawnShip:]` (1480) | `PlayerEntity::spawnShip` `PlayerEntityLegacyScriptEngine.cpp:1580` | ✅ |
| `-[PlayerEntity(Scripting) set:]` (1489) | `PlayerEntity::set` `PlayerEntityLegacyScriptEngine.cpp:1589` | ✅ |
| `-[PlayerEntity(Scripting) reset:]` (1522) | `PlayerEntity::reset` `PlayerEntityLegacyScriptEngine.cpp:1622` | ✅ |
| `-[PlayerEntity(Scripting) increment:]` (1539) | `PlayerEntity::increment` `PlayerEntityLegacyScriptEngine.cpp:1639` | ✅ |
| `-[PlayerEntity(Scripting) decrement:]` (1560) | `PlayerEntity::decrement` `PlayerEntityLegacyScriptEngine.cpp:1661` | ✅ |
| `-[PlayerEntity(Scripting) add:]` (1581) | `PlayerEntity::add` `PlayerEntityLegacyScriptEngine.cpp:1683` | ✅ |
| `-[PlayerEntity(Scripting) subtract:]` (1614) | `PlayerEntity::subtract` `PlayerEntityLegacyScriptEngine.cpp:1716` | ✅ |
| `-[PlayerEntity(Scripting) checkForShips:]` (1647) | `PlayerEntity::checkForShips` `PlayerEntityLegacyScriptEngine.cpp:1749` | ✅ |
| `-[PlayerEntity(Scripting) resetScriptTimer]` (1652) | `PlayerEntity::resetScriptTimer` `PlayerEntityLegacyScriptEngine.cpp:1754` | ✅ |
| `-[PlayerEntity(Scripting) addMissionText:]` (1659) | `PlayerEntity::addMissionText` `PlayerEntityLegacyScriptEngine.cpp:1761` | ✅ |
| `-[PlayerEntity(Scripting) addLiteralMissionText:]` (1678) | `PlayerEntity::addLiteralMissionText` `PlayerEntityLegacyScriptEngine.cpp:1780` | ✅ |
| `-[PlayerEntity(Scripting) setMissionChoiceByTextEntry:]` (1690) | `PlayerEntity::setMissionChoiceByTextEntry` `PlayerEntityLegacyScriptEngine.cpp:1789` | ✅ |
| `-[PlayerEntity(Scripting) setMissionChoices:]` (1697) | `PlayerEntity::setMissionChoices` `PlayerEntityLegacyScriptEngine.cpp:1797` | ✅ |
| `-[PlayerEntity(Scripting) setMissionChoicesDictionary:]` (1706) | `PlayerEntity::setMissionChoicesDictionary` `PlayerEntityLegacyScriptEngine.cpp:1808` | ❌ |
| `-[PlayerEntity(Scripting) resetMissionChoice]` (1828) | `PlayerEntity::resetMissionChoice` `PlayerEntityLegacyScriptEngine.cpp:1923` | ✅ |
| `-[PlayerEntity(Scripting) clearMissionScreen]` (1833) | `PlayerEntity::clearMissionScreen` `PlayerEntityLegacyScriptEngine.cpp:1928` | ✅ |
| `-[PlayerEntity(Scripting) addMissionDestination:]` (1843) | `PlayerEntity::addMissionDestination` `PlayerEntityLegacyScriptEngine.cpp:1938` | ✅ |
| `-[PlayerEntity(Scripting) removeMissionDestination:]` (1858) | `PlayerEntity::removeMissionDestination` `PlayerEntityLegacyScriptEngine.cpp:1949` | ✅ |
| `-[PlayerEntity(Scripting) showShipModel:]` (1873) | `PlayerEntity::showShipModel` `PlayerEntityLegacyScriptEngine.cpp:1960` | ✅ |
| `-[PlayerEntity(Scripting) setMissionMusic:]` (1884) | `PlayerEntity::setMissionMusic` `PlayerEntityLegacyScriptEngine.cpp:1973` | ✅ |
| `-[PlayerEntity(Scripting) missionTitle]` (1892) | `PlayerEntity::missionTitle` `PlayerEntityLegacyScriptEngine.cpp:1979` | ✅ |
| `-[PlayerEntity(Scripting) setMissionTitle:]` (1897) | `PlayerEntity::setMissionTitle` `PlayerEntityLegacyScriptEngine.cpp:1984` | ✅ |
| `-[PlayerEntity(Scripting) setMissionImage:]` (1905) | `PlayerEntity::setMissionImage` `PlayerEntityLegacyScriptEngine.cpp:1991` | ✅ |
| `-[PlayerEntity(Scripting) setMissionBackground:]` (1914) | `PlayerEntity::setMissionBackground` `PlayerEntityLegacyScriptEngine.cpp:2002` | ✅ |
| `-[PlayerEntity(Scripting) setFuelLeak:]` (1923) | `PlayerEntity::setFuelLeak` `PlayerEntityLegacyScriptEngine.cpp:2012` | ✅ |
| `-[PlayerEntity(Scripting) fuelLeakRate_number]` (1938) | `PlayerEntity::fuelLeakRate_number` `PlayerEntityLegacyScriptEngine.cpp:2029` | ✅ |
| `-[PlayerEntity(Scripting) setSunNovaIn:]` (1943) | `PlayerEntity::setSunNovaIn` `PlayerEntityLegacyScriptEngine.cpp:2034` | ✅ |
| `-[PlayerEntity(Scripting) launchFromStation]` (1949) | `PlayerEntity::launchFromStation` `PlayerEntityLegacyScriptEngine.cpp:2041` | ✅ |
| `-[PlayerEntity(Scripting) blowUpStation]` (1959) | `PlayerEntity::blowUpStation` `PlayerEntityLegacyScriptEngine.cpp:2053` | ✅ |
| `-[PlayerEntity(Scripting) sendAllShipsAway]` (1970) | `PlayerEntity::sendAllShipsAway` `PlayerEntityLegacyScriptEngine.cpp:2066` | ✅ |
| `-[PlayerEntity(Scripting) addPlanet:]` (2005) | `PlayerEntity::addPlanet` :2106 (by-name, void) + `PlayerEntity::addPlanetEntity` `PlayerEntityLegacyScriptEngine.cpp:2111` | ✅ |
| `-[PlayerEntity(Scripting) addMoon:]` (2049) | `PlayerEntity::addMoon` :2170 + `PlayerEntity::addMoonEntity` `PlayerEntityLegacyScriptEngine.cpp:2175` | ✅ |
| `-[PlayerEntity(Scripting) debugOn]` (2091) | `PlayerEntity::debugOn` `PlayerEntityLegacyScriptEngine.cpp:2234` | ✅ |
| `-[PlayerEntity(Scripting) debugOff]` (2097) | `PlayerEntity::debugOff` `PlayerEntityLegacyScriptEngine.cpp:2240` | ✅ |
| `-[PlayerEntity(Scripting) debugMessage:]` (2103) | `PlayerEntity::debugMessage` `PlayerEntityLegacyScriptEngine.cpp:2246` | ✅ |
| `-[PlayerEntity(Scripting) playSound:]` (2108) | `PlayerEntity::playSound` `PlayerEntityLegacyScriptEngine.cpp:2251` | ✅ |
| `-[PlayerEntity(Scripting) doMissionCallback]` (2115) | `PlayerEntity::doMissionCallback` `PlayerEntityLegacyScriptEngine.cpp:2258` | ✅ |
| `-[PlayerEntity(Scripting) clearMissionScreenID]` (2122) | `PlayerEntity::clearMissionScreenID` `PlayerEntityLegacyScriptEngine.cpp:2265` | ✅ |
| `-[PlayerEntity(Scripting) setMissionScreenID:]` (2128) | `PlayerEntity::setMissionScreenID` `PlayerEntityLegacyScriptEngine.cpp:2270` | ✅ |
| `-[PlayerEntity(Scripting) missionScreenID]` (2133) | `PlayerEntity::missionScreenID` `PlayerEntityLegacyScriptEngine.cpp:2275` | ✅ |
| `-[PlayerEntity(Scripting) endMissionScreenAndNoteOpportunity]` (2138) | `PlayerEntity::endMissionScreenAndNoteOpportunity` `PlayerEntityLegacyScriptEngine.cpp:2280` | ✅ |
| `-[PlayerEntity(Scripting) setGuiToMissionScreen]` (2149) | `PlayerEntity::setGuiToMissionScreen` `PlayerEntityLegacyScriptEngine.cpp:2292` | ✅ |
| `-[PlayerEntity(Scripting) refreshMissionScreenTextEntry]` (2160) | `PlayerEntity::refreshMissionScreenTextEntry` `PlayerEntityLegacyScriptEngine.cpp:2303` | ✅ |
| `-[PlayerEntity(Scripting) setGuiToMissionScreenWithCallback:]` (2176) | `PlayerEntity::setGuiToMissionScreenWithCallback` `PlayerEntityLegacyScriptEngine.cpp:2321` | ✅ |
| `-[PlayerEntity(Scripting) setBackgroundFromDescriptionsKey:]` (2228) | `PlayerEntity::setBackgroundFromDescriptionsKey` `PlayerEntityLegacyScriptEngine.cpp:2370` | ✅ |
| `-[PlayerEntity(Scripting) addScene:atOffset:]` (2240) | `PlayerEntity::addScene` `PlayerEntityLegacyScriptEngine.cpp:2383` | ✅ |
| `-[PlayerEntity(Scripting) processSceneDictionary:atOffset:]` (2259) | `PlayerEntity::processSceneDictionary` `PlayerEntityLegacyScriptEngine.cpp:2400` | ✅ |
| `-[PlayerEntity(Scripting) processSceneString:atOffset:]` (2292) | `PlayerEntity::processSceneString` `PlayerEntityLegacyScriptEngine.cpp:2434` | ✅ |
| `-[PlayerEntity(Scripting) addEqScriptForKey:]` (2483) | `PlayerEntity::addEqScriptForKey` `PlayerEntityLegacyScriptEngine.cpp:2647` | ✅ |
| `-[PlayerEntity(Scripting) removeEqScriptForKey:]` (2520) | `PlayerEntity::removeEqScriptForKey` `PlayerEntityLegacyScriptEngine.cpp:2677` | ✅ |
| `-[PlayerEntity(Scripting) eqScriptIndexForKey:]` (2545) | `PlayerEntity::eqScriptIndexForKey` `PlayerEntityLegacyScriptEngine.cpp:2698` | ✅ |
| `-[PlayerEntity(Scripting) targetNearestHostile]` (2560) | `PlayerEntity::targetNearestHostile` `PlayerEntityLegacyScriptEngine.cpp:2710` | ✅ |
| `-[PlayerEntity(Scripting) targetNearestIncomingMissile]` (2571) | `PlayerEntity::targetNearestIncomingMissile` `PlayerEntityLegacyScriptEngine.cpp:2721` | ✅ |
| `-[PlayerEntity(Scripting) setGalacticHyperspaceBehaviourTo:]` (2582) | `PlayerEntity::setGalacticHyperspaceBehaviourTo` `PlayerEntityLegacyScriptEngine.cpp:2732` | ✅ |
| `-[PlayerEntity(Scripting) setGalacticHyperspaceFixedCoordsTo:]` (2592) | `PlayerEntity::setGalacticHyperspaceFixedCoordsTo` `PlayerEntityLegacyScriptEngine.cpp:2742` | ✅ |
| `OOComparisonTypeToString()` (2608) | `cxx_OOComparisonTypeToString` `PlayerEntityLegacyScriptEngine.cpp:2755` | ✅ |

**Differences:**

- ❌ **low** — when every mission choice is blank, the fallback row is set to `" "` (one space); upstream sets `@"  "` (two spaces). Visibly blank either way; row text differs (GUI snapshot/row-text comparisons) — upstream `Core/Entities/PlayerEntityLegacyScriptEngine.m:1817` ↔ port `Core/Entities/PlayerEntityLegacyScriptEngine.cpp:1912`
- ⚠️ **low** — choice keys sorted with `std::stable_sort` over the Dict's byte-ordered keys; upstream `-sortedArrayUsingSelector:caseInsensitiveCompare:` (unstable, from hash order). Only case-insensitively equal keys can order differently. Upstream's non-string-key check and `test.script.error` log gone (a Dict cannot hold non-string keys; code comment) — upstream `PlayerEntityLegacyScriptEngine.m:1728-1742` ↔ port `PlayerEntityLegacyScriptEngine.cpp:1828-1836`
- ⚠️ **low** — `checkScript` runs tickle scripts in load order; upstream `-allValues` hash order (code comment "ORDER-SENSITIVE (decision D)"). Tickle cache is a vector of (name, script) instead of an NSDictionary. Only OOException is caught; other C++ exceptions rethrow — upstream `PlayerEntityLegacyScriptEngine.m:247-319` ↔ port `PlayerEntityLegacyScriptEngine.cpp:382-458`
- ⚠️ **low** — `missionsList` walks world scripts in load order (`worldScriptNames()`); upstream `-keyEnumerator` hash order (decision D). Changes the order of mission-description lines on the manifest screen. Header merging (`removeObject:` then append) matches via `std::erase` — upstream `PlayerEntityLegacyScriptEngine.m:661-687` ↔ port `PlayerEntityLegacyScriptEngine.cpp:798-824`
- ⚠️ **low** — "unhandled condition" internal-error log prints the condition via `oo::writeOldStylePList` (decision C, code comment) instead of `%@` NSArray `-description`; number formatting may differ in this never-expected path. Class and other text unchanged — upstream `PlayerEntityLegacyScriptEngine.m:538` ↔ port `PlayerEntityLegacyScriptEngine.cpp:667-672`
- ⚠️ **low** — actions and condition queries dispatch through the by-name table (`oo::EntityRespondsToName`/`oo::CallEntityByName`, ADR-0055 item 5, bead oo-9ht.39.7.1) instead of `respondsToSelector:`/`performSelector:`. Fallback to the player when the target lacks the method matches. Equivalent only if the table covers every whitelisted selector (table completeness not audited here) — upstream `PlayerEntityLegacyScriptEngine.m:191-206, 440, 477, 517, 563, 708-709` ↔ port `PlayerEntityLegacyScriptEngine.cpp:316-334, 577, 611, 647, 696, 851-852`
- ⚠️ **low** — `localVariablesForMission` returns a snapshot and no longer creates and stores an empty table on read; `setLocalVariable` writes the table back (code comment). Upstream never saved `localVariables` (`PlayerEntity.m:1761,2166` only reset it), so nothing observable changes — upstream `PlayerEntityLegacyScriptEngine.m:597-611` ↔ port `PlayerEntityLegacyScriptEngine.cpp:736-771`
- Condition evaluation checked operator by operator and equivalent, including nil: string `undefined` true only for nil; `equal` false and `notequal` true for nil; `<`/`>` via `DOUBLEVAL` (nil → 0); string `oneof` splits on `,` and trims whitespace-without-newlines, nil matches nothing; number `oneof` splits on `,` without trimming, items read with `doubleValue`; bool `== "YES"` on both sides; `script.error.unexpectedOperator` text and `OOComparisonTypeToString` names identical.
- A non-string mission/local variable (e.g. an array) now compares or substitutes as its description (`ConditionString`); upstream sent it `-isEqualToString:`/`-intValue` and raised, which `script.error.exception` caught and which aborted the action list. JS mission variables are always stored as strings (`OOJSMissionVariables.m:139-143`), so practically unreachable — upstream `PlayerEntityLegacyScriptEngine.m:426-430, 702-705, 1548` ↔ port `PlayerEntityLegacyScriptEngine.cpp:235-242, 560-566, 845-847, 1649`
- All action log messages compared character by character and identical in class and text, including upstream's typos (`in %@,* CANNOT addShipsAtPrecisely`, `SCRIPT ERROR :in`, double space in `WARNING in %@  Tried`). Covers set/reset/increment/decrement/add/subtract, addShips*/spawnShip, awardCargo/awardEquipment/removeEquipment, setPlanetinfo/setSpecificPlanetInfo, messageShipAIs, removeAllCargo/useSpecialCargo, setFuelLeak, debugOn/Off/Message, showShipModel, addPlanet/addMoon, the processSceneString logs, the missionDescription errors and EXPANSION. `%d`/`%i`/`%u`/`%.3f`/`%.2f` became `{}`/`{:.3f}`/`{:.2f}` with the same casts; `set`/`add`/`subtract` store `"%d"`/`"%f"` strings as upstream — port `PlayerEntityLegacyScriptEngine.cpp:1415-1747`
- Subtle (nil messaging, practically unreachable): `addLiteralMissionText`, `refreshMissionScreenTextEntry`, `setGuiToMissionScreenWithCallback` and `setMissionChoicesDictionary` call `gui->` without a null check, and `setBackgroundFromDescriptionsKey` and the `scene` branch dereference `UNIVERSE->descriptions()`; upstream messaged nil and carried on (and guards `if (gui)` at `.m:2211`) — port `PlayerEntityLegacyScriptEngine.cpp:1785, 1844, 2314, 2332, 2372, 2470`
- Subtle edge cases where upstream raised and the port carries on: an all-whitespace `processSceneString` returns NO (upstream raised on `objectAtIndex:0`); non-array `addScene`/`scene` items are ignored (upstream raised on `-count`); a non-string planet `orientation` is ignored (upstream passed it to `ScanQuaternionFromString`) — upstream `PlayerEntityLegacyScriptEngine.m:2299-2302, 2244-2247, 2022` ↔ port `PlayerEntityLegacyScriptEngine.cpp:2440-2441, 2385-2387, 2139`
- `setGalacticHyperspaceFixedCoordsTo` with fewer than 2 tokens sets 0x60, then overwrites it with `(0,0)` from the missing elements; the port keeps this upstream bug — upstream `PlayerEntityLegacyScriptEngine.m:2595-2603` ↔ port `PlayerEntityLegacyScriptEngine.cpp:2745-2752`

## EntityOOJavaScriptExtensions

<a id="entityoojavascriptextensions"></a>
Upstream `src/Core/Scripting/EntityOOJavaScriptExtensions.m` ↔ `Core/Scripting/EntityOOJavaScriptExtensions.cpp`

**Status:** done — 10 rows: 9 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[Entity(OOJavaScriptExtensions) isVisibleToScripts]` (39) | `EntityJSIsVisibleToScripts` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:50`, via virtual `Entity::isVisibleToScripts` `Core/Entities/Entity.cpp:1126` | ✅ |
| `-[Entity(OOJavaScriptExtensions) oo_jsClassName]` (44) | `EntityJSClassName` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:55`, via `Entity::jsClassName` `Core/Entities/Entity.cpp:1121` | ✅ |
| `-[Entity(OOJavaScriptExtensions) oo_jsValueInContext:]` (49) | `EntityJSValueInContext` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:100`, via `Entity::jsValueInContext` `Core/Entities/Entity.cpp:1133` | ✅ |
| `-[Entity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (81) | `EntityJSGetJSClass` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:131`, via `Entity::getJSClass` `Core/Entities/Entity.cpp:1116` | ✅ |
| `-[Entity(OOJavaScriptExtensions) deleteJSSelf]` (87) | `EntityJSDeleteJSSelf` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:137`, via `Entity::deleteJSSelf` `Core/Entities/Entity.cpp:1149` | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) isVisibleToScripts]` (105) | `ShipEntityJSIsVisibleToScripts` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:170`, via `ShipEntity::isVisibleToScripts` `Core/Entities/ShipEntity.cpp:6927` | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (110) | `ShipEntityJSGetJSClass` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:175`, via `Core/Entities/ShipEntity.cpp:6917` | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) oo_jsClassName]` (116) | `ShipEntityJSClassName` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:181`, via `ShipEntity::jsClassName` `Core/Entities/ShipEntity.cpp:6920` | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) subEntitiesForScript]` (121) | `ShipEntityJSSubEntitiesForScript` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:186` (over `ShipEntity::shipSubEntities` `Core/Entities/ShipEntity.cpp:1512`, `EntityIsShip` filter) | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) setTargetForScript:]` (126) | `ShipEntityJSSetTargetForScript` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:195` | ❌ |

**Differences:**

- ❌ **low** — When the owner walk for `target` reaches a non-ship owner, upstream casts it to `ShipEntity*` and calls `addTarget:` with it. The port's `oo::ToShip()` turns that owner into `nullptr`, so the call takes the `else` branch and `removeTarget(primaryTarget())` clears the current target instead. The `me` walk is equivalent: both return early. Nearly unreachable, since a ship subentity's owner is always a ship — upstream `Core/Scripting/EntityOOJavaScriptExtensions.m:136-146` ↔ port `Core/Scripting/EntityOOJavaScriptExtensions.cpp:205-218`
- ✅ subtle — `oo_jsValueInContext:` stores an `OOJSEntityHolder` (weak; `oo::makeRef` plus an `OOJSSetCxxPrivate` retain) instead of `[self weakRetain]`. The GC root name "Entity jsSelf" and the reset-notification observer are kept (bead oo-9ht.39.3). `deleteJSSelf` keeps upstream's order: it nulls `_jsSelf`, then removes the root — upstream `:87-98` ↔ port `:137-148`
- ✅ subtle — The port adds `EntityJSDescription` (`:155`), which holds the body of upstream `OOObject -oo_jsDescription` (`OOJavaScriptEngine.m:1289-1306`). It returns the same "[<jsClassName> <components>]" or "[object <jsClassName>]".

## OOConstToJSString

<a id="ooconsttojsstring"></a>
Upstream `src/Core/Scripting/OOConstToJSString.m` ↔ `Core/Scripting/OOConstToJSString.cpp`

**Status:** done — 9 rows: 9 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOConstToJSStringInit()` (129) | `OOConstToJSStringInit` OOConstToJSString.cpp:133 | ✅ |
| `OOConstToJSStringDestroy()` (149) | `OOConstToJSStringDestroy` OOConstToJSString.cpp:155 | ✅ |
| `CompareEntries()` (156) | `CompareEntries` OOConstToJSString.cpp:164 | ✅ |
| `InitTable()` (168) | `InitTable` OOConstToJSString.cpp:176 | ✅ |
| `OOJSStringFromConstantPRIVATE()` (182) | `OOJSStringFromConstantPRIVATE` OOConstToJSString.cpp:190 | ✅ |
| `OOConstantFromJSStringPRIVATE()` (206) | `OOConstantFromJSStringPRIVATE` OOConstToJSString.cpp:214 | ✅ |
| `OOConstantFromJSValuePRIVATE()` (233) | `OOConstantFromJSValuePRIVATE` OOConstToJSString.cpp:241 | ✅ |
| *(added)* nine `s…TableEntries[]` tables from `Core/Tables/*.tbl` + `ENTRY` macros (71–107) | same tables OOConstToJSString.cpp:79–113; all nine `.tbl` files byte-identical (diffed) | ✅ |
| *(added)* header inlines `OOJSStringFrom…/…FromJSString/…FromJSValue` + default values (`OOConstToJSString.h`) | `OOConstToJSString.h`: bodies and per-type defaults identical after signature renaming (diffed) | ✅ |

**Differences:**

- ✅ **low** — The binary search has the same latent bug on both sides. When `value` is below the smallest entry, `max = mid - 1` underflows `NSUInteger` and the loop continues, so this was kept, not introduced — upstream `OOConstToJSString.m:189-201` ↔ port `OOConstToJSString.cpp:197-209`
- ✅ **low** — `sInited` exists only under `!NDEBUG` in the port. It is only read by asserts, so there is no release-build effect — upstream `OOConstToJSString.m:60` ↔ port `OOConstToJSString.cpp:62-64`

## OOJSCall

<a id="oojscall"></a>
Upstream `src/Core/Scripting/OOJSCall.m` ↔ `Core/Scripting/OOJSCall.cpp`

**Status:** done — 7 rows: 1 ✅ 1 ⚠️ 0 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `MethodExpectsParameter()` (64) *(added: inline, missed by extractor)* | `MethodExpectsParameter()` `Core/Scripting/OOJSCall.cpp:73` | ✅ |
| `OOJSCallObjCObjectMethod()` (66) | `CallMethod()` `Core/Scripting/OOJSCall.cpp:150`, entry `OOJSCallEntityMethod()` `Core/Scripting/OOJSCall.cpp:328` | ⚠️ |
| `SignatureMatch()` (186) | — (signatures precomputed in the generated table `kOOJSCallEntityMethods`, `OOJSCallEntityMethods.h`) | ➖ |
| `GetMethodType()` (194) | `MethodTypeOfRow()` `Core/Scripting/OOJSCall.cpp:124` (reads the table row's form/encoding) | ➖ |
| `-[OOJSCallMethodSignatureTemplateClass voidVoidMethod]` (214) | — (template class deleted; `OOJSCallEntityMethodForm::VoidVoid`) | ➖ |
| `-[OOJSCallMethodSignatureTemplateClass voidObjectMethod:]` (218) | — (`OOJSCallEntityMethodForm::VoidString`) | ➖ |
| `-[OOJSCallMethodSignatureTemplateClass objectObjectMethod:]` (222) | — (`OOJSCallEntityMethodForm::PListString`) | ➖ |

**Differences:**

- ⚠️ **med** — `callObjC()` now reaches only entities. Upstream it reached any native object that `OOJSNativeObjectFromJSObject` returned (scripts, timers, sounds, system info and so on). A non-entity `this` now reports "`<class>.callObjC(): (null) does not respond to method X.`". Bead oo-4aq6a.5 (comment at OOJSCall.cpp:146-148). — upstream `Debug/OOJSConsole.m:705`, `Core/Scripting/OOJSCall.m:97` ↔ port `Core/Scripting/OOJSCall.cpp:313-319`, `Core/Debug/OOJSConsole.cpp:946`
- ⚠️ **low** — Methods are looked up in a generated name table (bead oo-9ht.44) plus `oo::EntityRespondsToName`, not with `respondsToSelector:`. Any entity selector missing from the table now reports "does not respond". — upstream `Core/Scripting/OOJSCall.m:97` ↔ port `Core/Scripting/OOJSCall.cpp:199`
- ❌ **low** — Parameter join: upstream `concatenationOfStringsFromJavaScriptValues` left the parameter nil when the first argument's `toString` failed, and raised (`appendString:nil`) when a later one failed. The port substitutes `""` and carries on. — upstream `Core/Scripting/OOJavaScriptEngine.m:1648-1655` ↔ port `Core/Scripting/OOJSCall.cpp:179-183`
- ⚠️ **low** — In `OO_DEBUG` builds the player statistics methods (`report/clearJSVector/QuaternionStatistics`) are dispatched first, through `kPlayerMethods`, and skip the signature check. All four take no argument, so the result is the same (ADR-0056 amendment oo-9ht.15). — port `Core/Scripting/OOJSCall.cpp:86-106,187-197`
- Subtle, ✅: a method returning a colour used to be `kMethodTypeObjectVoid` with an `OOColor` JS value; it is now `kMethodTypeColorVoid` with `OOColorObjectNode`, and the `_bool` suffix still gives `false`. Integer and float results are still widened through signed/unsigned 64-bit and double. Error texts match, as does the `setScriptTarget:` side effect before the selector is converted. — port `Core/Scripting/OOJSCall.cpp:161-170,239-244,271-288`

## OOJSClock

<a id="oojsclock"></a>
Upstream `src/Core/Scripting/OOJSClock.m` ↔ `Core/Scripting/OOJSClock.cpp`

**Status:** done — 8 rows: 8 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sClockClass` JSClass (42) | `sClockClass` ClassDef `Core/Scripting/OOJSClock.cpp:86` (HasPrivate; getProperty only) | ✅ |
| enum + `sClockProperties[]` (57, 74) | enum `:105`, `sClockPropertiesFacade[]` `:150` (13 names, all Permanent\|Enumerate\|ReadOnly\|Shared = READONLY_CB); reporter mirror `sClockProperties[]` `:126` | ✅ |
| `sClockMethods[]` (92) | `sClockMethods[]` `Core/Scripting/OOJSClock.cpp:170` (toString 0, clockStringForTime 1, addSeconds 1) | ✅ |
| `InitOOJSClock()` (100) | `InitOOJSClock` `Core/Scripting/OOJSClock.cpp:183` (`clock` object Permanent\|Enumerate\|ReadOnly) | ✅ |
| `ClockGetProperty()` (106) | `ClockGetProperty` `Core/Scripting/OOJSClock.cpp:190` | ✅ |
| `JSClockToString()` (175) | `JSClockToString` `Core/Scripting/OOJSClock.cpp:263` | ✅ |
| `ClockClockStringForTime()` (185) | `ClockClockStringForTime` `Core/Scripting/OOJSClock.cpp:276` | ✅ |
| `ClockAddSeconds()` (205) | `ClockAddSeconds` `Core/Scripting/OOJSClock.cpp:298` | ✅ |

**Differences:**

- ✅ **low** — the clock units and types match case by case:
  - `absoluteSeconds` = `Universe getTime`.
  - `seconds` = `PlayerEntity::clockTime` (game seconds, a double).
  - `adjustedSeconds` = `clockTimeAdjusted` (a double).
  - `minutes` and `hours` = `floor(t/60)` and `floor(t/3600)`, as doubles.
  - The `*Component` properties and `days` are int32 values from the same `fmod`/`floor` expressions, truncated by the implicit double→`int32_t` conversion (`INT_TO_JSVAL` ↔ `int32Value(std::int32_t)`, `ooscript/JSEngine.hpp:81`). So `secondsComponent` is an integer in both, despite its "double" comment.
  - `days` and `daysComponent` share one case.
  - `legacy_scriptTimer` logs the same deprecation text.

  upstream `Core/Scripting/OOJSClock.m:116-162` ↔ port `Core/Scripting/OOJSClock.cpp:203-248`
- ✅ **low** — `clockStringForTime` and `addSeconds` report bad arguments the same way (`Clock`, `"number"`, the argument or undefined). `addSeconds` returns false for values above 30 days, below 1 s or not finite, and otherwise calls `addToAdjustTime` and returns true. When there is no player, the port's `clockString`/`toString()` answer `""` where upstream's nil message gave null; `OOPlayerForScripting()` is never nil while scripts run — upstream `Core/Scripting/OOJSClock.m:150`, `:179`, `:191-226` ↔ port `Core/Scripting/OOJSClock.cpp:236`, `:268`, `:282-320`

## OOJSDock

<a id="oojsdock"></a>
Upstream `src/Core/Scripting/OOJSDock.m` ↔ `Core/Scripting/OOJSDock.cpp`

**Status:** done — 11 rows: 11 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sDockClass` JSClass (42) | `sDockClass` ClassDef `Core/Scripting/OOJSDock.cpp:93` | ✅ |
| `sDockProperties` JSPropertySpec table (66) | `sDockProperties` `Core/Scripting/OOJSDock.cpp:122` (+ `sDockPropertiesRaw` :137) | ✅ |
| `sDockMethods` JSFunctionSpec table (76) | `sDockMethods` `Core/Scripting/OOJSDock.cpp:148` | ✅ |
| `InitOOJSDock()` (82) | `InitOOJSDock` `Core/Scripting/OOJSDock.cpp:155` | ✅ |
| `JSDockGetDockEntity()` (89) | `JSDockGetDockEntity` `Core/Scripting/OOJSDock.cpp:164` | ✅ |
| `JSDockGetShipEntity()` (113) | `JSDockGetShipEntity` `Core/Scripting/OOJSDock.cpp:193` | ✅ |
| `-[DockEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (139) | `OOJSDockGetJSClass` `Core/Scripting/OOJSDock.cpp:220` | ✅ |
| `-[DockEntity(OOJavaScriptExtensions) oo_jsClassName]` (145) | `OOJSDockJSClassName` `Core/Scripting/OOJSDock.cpp:226` | ✅ |
| `DockGetProperty()` (152) | `DockGetProperty` `Core/Scripting/OOJSDock.cpp:232` | ✅ |
| `DockSetProperty()` (195) | `DockSetProperty` `Core/Scripting/OOJSDock.cpp:281` | ✅ |
| `DockIsQueued()` (246) | `DockIsQueued` `Core/Scripting/OOJSDock.cpp:340` | ✅ |

**Differences:**

- ✅ subtle — `isQueued(x)` with a non-object `x` (a number, say): upstream applies `JSVAL_TO_OBJECT` to a primitive, which is undefined behaviour (a garbage pointer passed to the entity getter). The port's `ooscript::toObject` returns nullptr, so `ship` stays nil and the call returns `false`. Well-formed calls behave the same — upstream `Core/Scripting/OOJSDock.m:259` ↔ port `Core/Scripting/OOJSDock.cpp:354`
- ✅ subtle — `JSDockGetDockEntity` uses `oo::ToDock` where upstream used `-isKindOfClass:[DockEntity class]`. A stale (nil) entity still fails the lookup and returns false, so the `entity == nil` branch is unreachable in both — upstream `Core/Scripting/OOJSDock.m:104` ↔ port `Core/Scripting/OOJSDock.cpp:181`
- ✅ subtle — The property table matches upstream: 5 entries, same names, same tinyid order, same flags. The method table has `isQueued` with min-args 1 in both. The error text (`"Dock"`, `"isQueued"`, `"ship"`) is identical — upstream `Core/Scripting/OOJSDock.m:66-80,255` ↔ port `Core/Scripting/OOJSDock.cpp:122-152,350`

## OOJSEngineDebuggerHelpers

<a id="oojsenginedebuggerhelpers"></a>
Upstream `src/Core/Scripting/OOJSEngineDebuggerHelpers.m` ↔ `Core/Scripting/OOJSEngineDebuggerHelpers.cpp`

**Status:** done — 8 rows: 6 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `JSValueToStrDbg()` (85) | `JSValueToStrDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:122` | ✅ |
| `JSObjectToStrDbg()` (94) | `JSObjectToStrDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:132` | ✅ |
| `JSStringToStrDbg()` (101) | `JSStringToStrDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:139` | ✅ |
| `JSValueTypeDbg()` (108) | `JSValueTypeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:146` | ⚠️ |
| `JSValueToStrSafeDbg()` (155) | `JSValueToStrSafeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:169` | ✅ |
| `JSObjectToStrSafeDbg()` (187) | `JSObjectToStrSafeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:201` | ✅ |
| `JSStringToStrSafeDbg()` (194) | `JSStringToStrSafeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:208` | ✅ |
| `JSIDToStrSafeDbg()` (201) | `JSIDToStrSafeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:215` | ⚠️ |

**Differences:**

- ⚠️ **low** — The magic-value switch ("magic (array hole)" etc.) is gone: such values cannot be expressed through the façade and fall to "unknown". Documented in the port's file comment (beads oo-4kf, oo-1gc.3). — upstream `Core/Scripting/OOJSEngineDebuggerHelpers.m:123-145` ↔ port `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:94-100,165`
- ⚠️ **low** — `JSValueTypeDbg` names objects through `OOJSGetClass` → `getObjectClass` (`Core/Scripting/OOJSEngineCore.h:234`), so engine built-ins report QuickJS-ng's class names instead of SpiderMonkey's. The port comment says such objects report "object", but that is stale: the fallback applies only when the descriptor is null. — upstream `Core/Scripting/OOJSEngineDebuggerHelpers.m:148` ↔ port `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:160-163`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:2812`
- ⚠️ **low** — `JSIDToStrSafeDbg`: the empty/zero/object/default-XML-namespace id kinds and the raw-bits `unknown <0x%llX>` collapse to "unknown", and symbol ids also fall into "unknown". The bug text changes from `*** uninterned string in jsid! ***` to `*** uninterned string in ooscript::PropertyId! ***`. — upstream `Core/Scripting/OOJSEngineDebuggerHelpers.m:206-232` ↔ port `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:221-236`
- Subtle — The "Safe" variants no longer avoid the engine. `getStringLength`, `getInternedStringChars` and `idToString` use the backend's `gDefaultCtx` and build cached UTF-16 buffers, and `idToString` creates a `JSString` from the atom that goes into the arena and the interned set. — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:2572-2580,3394-3431`
- Subtle — Results come from one shared static `std::string` (`DebuggerCString`), not autoreleased strings, so the next `*Dbg` call invalidates the previous result. This matters only when used from a debugger. — port `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:114-119`

## OOJSEngineTimeManagement

<a id="oojsenginetimemanagement"></a>
Upstream `src/Core/Scripting/OOJSEngineTimeManagement.m` ↔ `Core/Scripting/OOJSEngineTimeManagement.cpp`

**Status:** done — 59 rows: 49 ✅ 7 ⚠️ 1 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| statics + `OOJS_TIME_LIMIT` (0.2 s debug / 1 s) (54-73) *(added)* | same statics, `Core/Scripting/OOJSEngineTimeManagement.cpp:59-80` | ✅ |
| `OOJSStartTimeLimiterWithTimeLimit_()` (80) *(added)* | `OOJSStartTimeLimiterWithTimeLimit_` `Core/Scripting/OOJSEngineTimeManagement.cpp:87` | ✅ |
| `OOJSStopTimeLimiter_()` (105) *(added)* | `OOJSStopTimeLimiter_` `Core/Scripting/OOJSEngineTimeManagement.cpp:112` | ✅ |
| `OOJSPauseTimeLimiter()` (129) | `OOJSPauseTimeLimiter` `Core/Scripting/OOJSEngineTimeManagement.cpp:136` | ✅ |
| `OOJSResumeTimeLimiter()` (137) | `OOJSResumeTimeLimiter` `Core/Scripting/OOJSEngineTimeManagement.cpp:144` | ✅ |
| `OOJSCopyTimeLimiterNominalStartTime()` (151) | `OOJSCopyTimeLimiterNominalStartTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:158` | ✅ |
| `OOJSResetTimeLimiter()` (156) | `OOJSResetTimeLimiter` `Core/Scripting/OOJSEngineTimeManagement.cpp:163` | ✅ |
| `OOJSGetTimeLimiterLimit()` (164) | `OOJSGetTimeLimiterLimit` `Core/Scripting/OOJSEngineTimeManagement.cpp:171` | ✅ |
| `OOJSSetTimeLimiterLimit()` (169) | `OOJSSetTimeLimiterLimit` `Core/Scripting/OOJSEngineTimeManagement.cpp:176` | ✅ |
| `-[OOJavaScriptEngine(WatchdogTimer) watchdogTimerThread]` (177) | `WatchdogTimerThread` `Core/Scripting/OOJSEngineTimeManagement.cpp:186` (+ `triggerAllOperationCallbacks` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3895`) | ❌ |
| `OperationCallback()` (204) | `OperationCallback` `Core/Scripting/OOJSEngineTimeManagement.cpp:212` (+ `InterruptTramp` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:2375`) | ✅ |
| `ContextCallback()` (228) | `ContextCallback` `Core/Scripting/OOJSEngineTimeManagement.cpp:237` | ✅ |
| `OOJSTimeManagementInit()` (240) | `OOJSTimeManagementInit` `Core/Scripting/OOJSEngineTimeManagement.cpp:249` | ✅ |
| `OOJSBeginProfiling()` (293) | `OOJSBeginProfiling` `Core/Scripting/OOJSEngineTimeManagement.cpp:297` | ✅ |
| `OOJSEndProfiling()` (313) | `OOJSEndProfiling` `Core/Scripting/OOJSEngineTimeManagement.cpp:320` | ✅ |
| `OOJSIsProfiling()` (354) | `OOJSIsProfiling` `Core/Scripting/OOJSEngineTimeManagement.cpp:367` | ✅ |
| `CleanUpJSFrame()` (366) | `CleanUpJSFrame` `Core/Scripting/OOJSEngineTimeManagement.cpp:381` (never compiled) | ⚠️ |
| `TraceEnterJSFunction()` (371) | `TraceEnterJSFunction` `Core/Scripting/OOJSEngineTimeManagement.cpp:386` (never compiled) | ⚠️ |
| `FunctionCallback()` (430) | `FunctionCallback` `Core/Scripting/OOJSEngineTimeManagement.cpp:447` (never compiled) | ⚠️ |
| `OOJSProfileEnter()` (490) | `OOJSProfileEnter` `Core/Scripting/OOJSEngineTimeManagement.cpp:505` | ✅ |
| `OOJSProfileExit()` (510) | `OOJSProfileExit` `Core/Scripting/OOJSEngineTimeManagement.cpp:527` | ✅ |
| `UpdateProfileForFrame()` (553) | `UpdateProfileForFrame` `Core/Scripting/OOJSEngineTimeManagement.cpp:570` | ✅ |
| `-[OOTimeProfile dealloc]` (581) | implicit (`std::vector<oo::Ref<…>>` member) `Core/Scripting/OOJSEngineTimeManagement.h` | ➖ |
| `-[OOTimeProfile description]` (588) | `OOTimeProfile::description` `Core/Scripting/OOJSEngineTimeManagement.cpp:597` | ✅ |
| `-[OOTimeProfile totalTime]` (624) | `OOTimeProfile::totalTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:633` | ✅ |
| `-[OOTimeProfile setTotalTime:]` (629) | `OOTimeProfile::setTotalTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:638` | ✅ |
| `-[OOTimeProfile javaScriptTime]` (634) | `OOTimeProfile::javaScriptTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:643` | ⚠️ |
| `-[OOTimeProfile setJavaScriptTime:]` (644) | `OOTimeProfile::setJavaScriptTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:653` (never compiled) | ⚠️ |
| `-[OOTimeProfile nativeTime]` (650) | `OOTimeProfile::nativeTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:659` | ✅ |
| `-[OOTimeProfile setNativeTime:]` (655) | `OOTimeProfile::setNativeTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:664` | ✅ |
| `-[OOTimeProfile extensionTime]` (660) | `OOTimeProfile::extensionTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:669` | ✅ |
| `-[OOTimeProfile setExtensionTime:]` (665) | `OOTimeProfile::setExtensionTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:674` | ✅ |
| `-[OOTimeProfile nonExtensionTime]` (670) | `OOTimeProfile::nonExtensionTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:679` | ✅ |
| `-[OOTimeProfile profilerOverhead]` (675) | `OOTimeProfile::profilerOverhead` `Core/Scripting/OOJSEngineTimeManagement.cpp:684` | ✅ |
| `-[OOTimeProfile setProfilerOverhead:]` (680) | `OOTimeProfile::setProfilerOverhead` `Core/Scripting/OOJSEngineTimeManagement.cpp:689` | ✅ |
| `-[OOTimeProfile profileEntries]` (685) | `OOTimeProfile::profileEntries` `Core/Scripting/OOJSEngineTimeManagement.cpp:694` | ✅ |
| `-[OOTimeProfile setProfileEntries:]` (690) | `OOTimeProfile::setProfileEntries` `Core/Scripting/OOJSEngineTimeManagement.cpp:699` | ✅ |
| `-[OOTimeProfile oo_jsValueInContext:]` (698) | `OOTimeProfile::oo_jsValueInContext` `Core/Scripting/OOJSEngineTimeManagement.cpp:704` | ✅ |
| `-[OOTimeProfile propertyListRepresentation]` (703) | `OOTimeProfile::propertyListRepresentation` `Core/Scripting/OOJSEngineTimeManagement.cpp:709` | ✅ |
| `-[OOTimeProfileEntry initWithCName:]` (727) | `OOTimeProfileEntry::OOTimeProfileEntry(const char*)` `Core/Scripting/OOJSEngineTimeManagement.cpp:728` | ✅ |
| `-[OOTimeProfileEntry initWithJSFunction:context:]` (741) | `OOTimeProfileEntry::OOTimeProfileEntry(Function, Context)` `Core/Scripting/OOJSEngineTimeManagement.cpp:740` (never compiled) | ⚠️ |
| `-[OOTimeProfileEntry dealloc]` (776) | implicit (`std::optional<std::string>` member) `Core/Scripting/OOJSEngineTimeManagement.h` | ➖ |
| `-[OOTimeProfileEntry addSampleWithTotalTime:selfTime:]` (783) | `OOTimeProfileEntry::addSampleWithTotalTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:774` | ✅ |
| `-[OOTimeProfileEntry description]` (792) | `OOTimeProfileEntry::description` `Core/Scripting/OOJSEngineTimeManagement.cpp:783` | ✅ |
| `-[OOTimeProfileEntry function]` (818) | `OOTimeProfileEntry::function` `Core/Scripting/OOJSEngineTimeManagement.cpp:810` | ✅ |
| `-[OOTimeProfileEntry hitCount]` (823) | `OOTimeProfileEntry::hitCount` `Core/Scripting/OOJSEngineTimeManagement.cpp:815` | ✅ |
| `-[OOTimeProfileEntry totalTimeSum]` (828) | `OOTimeProfileEntry::totalTimeSum` `Core/Scripting/OOJSEngineTimeManagement.cpp:820` | ✅ |
| `-[OOTimeProfileEntry selfTimeSum]` (833) | `OOTimeProfileEntry::selfTimeSum` `Core/Scripting/OOJSEngineTimeManagement.cpp:825` | ✅ |
| `-[OOTimeProfileEntry totalTimeAverage]` (838) | `OOTimeProfileEntry::totalTimeAverage` `Core/Scripting/OOJSEngineTimeManagement.cpp:830` | ✅ |
| `-[OOTimeProfileEntry selfTimeAverage]` (843) | `OOTimeProfileEntry::selfTimeAverage` `Core/Scripting/OOJSEngineTimeManagement.cpp:835` | ✅ |
| `-[OOTimeProfileEntry totalTimeMax]` (848) | `OOTimeProfileEntry::totalTimeMax` `Core/Scripting/OOJSEngineTimeManagement.cpp:840` | ✅ |
| `-[OOTimeProfileEntry selfTimeMax]` (853) | `OOTimeProfileEntry::selfTimeMax` `Core/Scripting/OOJSEngineTimeManagement.cpp:845` | ✅ |
| `-[OOTimeProfileEntry isJavaScriptFrame]` (858) | `OOTimeProfileEntry::isJavaScriptFrame` `Core/Scripting/OOJSEngineTimeManagement.cpp:850` | ⚠️ |
| `-[OOTimeProfileEntry compareByTotalTime:]` (867) | `OOTimeProfileEntry::compareByTotalTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:859` | ✅ |
| `-[OOTimeProfileEntry compareByTotalTimeReverse:]` (872) | `OOTimeProfileEntry::compareByTotalTimeReverse` `Core/Scripting/OOJSEngineTimeManagement.cpp:864` | ✅ |
| `-[OOTimeProfileEntry compareBySelfTime:]` (884) | `OOTimeProfileEntry::compareBySelfTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:876` | ✅ |
| `-[OOTimeProfileEntry compareBySelfTimeReverse:]` (889) | `OOTimeProfileEntry::compareBySelfTimeReverse` `Core/Scripting/OOJSEngineTimeManagement.cpp:881` | ✅ |
| `-[OOTimeProfileEntry oo_jsValueInContext:]` (901) | `OOTimeProfileEntry::oo_jsValueInContext` `Core/Scripting/OOJSEngineTimeManagement.cpp:893` | ✅ |
| `-[OOTimeProfileEntry propertyListRepresentation]` (906) | `OOTimeProfileEntry::propertyListRepresentation` `Core/Scripting/OOJSEngineTimeManagement.cpp:898` | ✅ |

**Differences:**

- ❌ **low** — The watchdog thread's `triggerAllOperationCallbacks` walks `rs->contexts` (a `std::vector`) without a lock, whereas SpiderMonkey's TriggerAllOperationCallbacks took the GC lock. On the main thread `newContext`/`destroyContext` push to and erase from that vector (e.g. `OOJavaScriptEngine::reset` → `createMainThreadContext`). That is a data race, with a possible use-after-free, if the limiter fires during an engine reset. — upstream `Core/Scripting/OOJSEngineTimeManagement.m:197` ↔ port `Core/Scripting/OOJSEngineTimeManagement.cpp:206`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3895-3900,3687,3704`
- Subtle (✅) — Limiter parity:
  - The constants match (`OOJS_TIME_LIMIT` 0.2 s debug / 1 s; `kOOJSLongTimeLimit` 5.0).
  - Start and pause nesting, the pause extension of `sLimiterTimeLimit` and the profiler-overhead extension are line-for-line the same.
  - The kill message keeps class `script.javaScript.timeLimit` and the text "Script \"%@\" ran for %g seconds and has been terminated." (`{:g}` ≡ `%g`; a nil name prints "(null)").
  - The abort is uncatchable: `InterruptTramp` returns 1, QuickJS-ng throws its uncatchable "interrupted", and `finish()` frees it without reporting. The caller sees "false, nothing pending", as with SpiderMonkey's callback returning false.
  - — port `Core/Scripting/OOJSEngineTimeManagement.cpp:212-235`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:883-897,2375-2388`
- Subtle — Polling granularity differs. SpiderMonkey ran the triggered callback at the next backedge or call. QuickJS-ng runs the interrupt handler only when its interrupt counter expires (about every 10k ops), and the façade calls Oolite's callback only if that context's atomic `triggered` flag is set (`exchange(false)`). The worst-case delay is negligible against the 1 s watchdog sleep. — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:2375-2388,3620`
- ⚠️ **low** — JavaScript-function profiling and call tracing are gone:
  - Upstream meson defines `MOZ_TRACE_JSCALLS=1` by default (`meson.build:99-100`, `meson.options:12`). The port never defines it, and `ooscript::setFunctionCallback` returns false on QuickJS-ng.
  - `FunctionCallback`, `TraceEnterJSFunction`, `CleanUpJSFrame`, `initWithJSFunction:` and `setJavaScriptTime:` are compiled out.
  - Profiles and traces in profiling (debug) builds now show only native `[ON]` entries; `javaScriptTime` = `totalTime − nativeTime`; `isJavaScriptFrame` is always false.
  - Intentional per the port comment (bead oo-99txa).
  - — upstream `Core/Scripting/OOJSEngineTimeManagement.m:233-235,365-488,636-647,858-864` ↔ port `Core/Scripting/OOJSEngineTimeManagement.cpp:242-244,268-271,643-650,850-857`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:4095`
- Subtle — `OOJSDumpStack` called from the time-limit kill path (under `OO_DEBUG_MONITOR_ENABLED`) now gets file/line frames only, because the backend's `frameThis`, `frameScopeChain` and `getScopeVariables` return nothing (ADR-0022). — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:4086-4091`
- Subtle — Profile entries come from `std::unordered_map` iteration followed by a descending `std::stable_sort` on self time. Upstream sorted `NSMapTable` values with `sortedArrayUsingSelector:`. Both leave ties in arbitrary order. — upstream `Core/Scripting/OOJSEngineTimeManagement.m:336` ↔ port `Core/Scripting/OOJSEngineTimeManagement.cpp:343-348`
- Subtle — `OOTimeProfile::propertyListRepresentation` stores each entry's property list under `"profiles"`. Upstream stored the raw entry objects, which converted themselves through `oo_jsValueInContext:`, so the JS result is the same. Keys now come out of a `std::map` (alphabetical) rather than NSDictionary hash order, so the JS property enumeration order of the profile object may differ. — upstream `Core/Scripting/OOJSEngineTimeManagement.m:712-720,908-918` ↔ port `Core/Scripting/OOJSEngineTimeManagement.cpp:709-726,898-914`, `oofnd/PList.hpp:136`
- ➖ — `dealloc` methods are replaced by RAII members (`std::vector<oo::Ref<>>`, `std::optional<std::string>`). — port `Core/Scripting/OOJSEngineTimeManagement.h`

## OOJSEntity

<a id="oojsentity"></a>
Upstream `src/Core/Scripting/OOJSEntity.m` ↔ `Core/Scripting/OOJSEntity.cpp`

**Status:** done — 14 rows: 14 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `gOOEntityJSClass` JSClass "Entity" (44) | `sEntityClass` `Core/Scripting/OOJSEntity.cpp:95` (finalize `OOJSCxxObjectWrapperFinalize`; slot holds `OOJSEntityHolder`) | ✅ |
| `sEntityProperties[]` (88): 25 props; read-write: energy, maxEnergy, orientation, position, scanClass (all `_CB`) | `sEntityProperties` `Core/Scripting/OOJSEntity.cpp:149`: same names, order, tinyids (enum `:119` identical) and flags | ✅ |
| `sEntityMethods[]` (118): `toString` 0, `dumpState` 0 (debug monitor) | `sEntityMethods` `Core/Scripting/OOJSEntity.cpp:181`: `toString`→`OOJSEntityToString`, `dumpState` 0 | ✅ |
| `InitOOJSEntity()` (127) | `InitOOJSEntity` `Core/Scripting/OOJSEntity.cpp:191` (converter `OOJSEntityObjectConverter` `:224`: entity node or null, as the weak-ref converter gave) | ✅ |
| `JSValueToEntity()` (133) | `JSValueToEntity` `Core/Scripting/OOJSEntity.cpp:256` (`isObjectOrNull` = SM `JSVAL_IS_OBJECT`) | ✅ |
| `EntityFromArgumentList()` (142) | `EntityFromArgumentList` `Core/Scripting/OOJSEntity.cpp:265`: same "%s.%s(): expected entity, got %s." text with "(desc)"; a nil class keeps the fall-through success quirk | ✅ |
| `EntityGetProperty()` (171) | `EntityGetProperty` `Core/Scripting/OOJSEntity.cpp:297` | ✅ |
| `EntitySetProperty()` (296) | `EntitySetProperty` `Core/Scripting/OOJSEntity.cpp:429` | ✅ |
| `EntityDumpState()` (376) | `EntityDumpState` `Core/Scripting/OOJSEntity.cpp:517` | ✅ |
| `OOJSEntityGetEntity` (DEFINE_JS_OBJECT_GETTER, `OOJSEntity.h:40`) | `OOJSEntityGetEntity`/`OOJSEntityGetEntityOfClass` `Core/Scripting/OOJSEntity.h:65,74` → `OOJSGetCxxPrivateImpl` `Core/Scripting/OOJSPrivateObject.cpp:60` ("Native method expected %s, got %s.") | ✅ |
| `JSEntityClass()` / `JSEntityPrototype()` (`OOJSEntity.h:42-43`) | `JSEntityClass` `Core/Scripting/OOJSEntity.cpp:114`; `JSEntityPrototype` `Core/Scripting/OOJSEntity.h:102` | ✅ |
| `OOIsPlayerStale()` (`OOJSEntity.h:63`) | `OOIsPlayerStale` `Core/Scripting/OOJSEntity.h:132` | ✅ |
| `OOIsStaleEntity()` (`OOJSEntity.h:69`) | `OOIsStaleEntity` `Core/Scripting/OOJSEntity.h:139` (adds a `gOOJSPlayerIfStale != nullptr` guard; same result for a non-null entity) | ✅ |
| `toString` → `OOJSObjectWrapperToString` (`OOJavaScriptEngine.m:1840`) | `OOJSEntityToString` → `OOJSCxxObjectWrapperToString` `Core/Scripting/OOJSPrivateObject.cpp:97` (jsDescription, else "[object <class>]") | ✅ |

**Differences:**

- ✅ subtle — For a stale entity, the getter gives `false` for `isValid` and `undefined` for every other property, and the setter returns true silently. This matches upstream — upstream `Core/Scripting/OOJSEntity.m:183-190,310-311` ↔ port `Core/Scripting/OOJSEntity.cpp:312-319,446-447`
- ✅ subtle — The `owner` getter gives null when the owner is the entity itself or is not visible to scripts (port: `ownerEntity()` + `OOJSValueFromCxxObject`). The `default` case keeps upstream's quirk: it reports the bad selector, then still writes `null` and returns true — upstream `:216-220,286-291` ↔ port `:347-351,417-422`
- ✅ subtle — All setter error texts match exactly: "entity.maxEnergy must be positive.", "entity.scanClass cannot be set to that value." and "entity.scanClass is read-only except on NPC ships.". The set of forbidden scan classes is the same, and energy is still clamped to [0, maxEnergy] — upstream `:332-363` ↔ port `:471-502`
- ✅ subtle — When `JSValueToEntity(null)` passes a null object to the getter, the port hits `OOCParameterAssert(object != NULL)`. Upstream hit `NSCParameterAssert`, or `JS_GetClass(NULL)` in release, so nothing regresses — upstream `OOJavaScriptEngine.m:1999` ↔ port `Core/Scripting/OOJSPrivateObject.cpp:64`

## OOJSEquipmentInfo

<a id="oojsequipmentinfo"></a>
Upstream `src/Core/Scripting/OOJSEquipmentInfo.m` ↔ `Core/Scripting/OOJSEquipmentInfo.cpp`

**Status:** done — 17 rows: 15 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| *(added)* `sEquipmentInfoProperties[]` (83): 38 props, `displayColor`/`effectiveTechLevel` RW_CB, rest RO_CB | `sEquipmentInfoProperties` OOJSEquipmentInfo.cpp:187: same 38 names, IDs and order; RW = Permanent\|Enumerate\|Shared, RO adds ReadOnly | ✅ |
| *(added)* `sEquipmentInfoStaticProperties[]` (126): `allEquipment` RO_CB | OOJSEquipmentInfo.cpp:232 | ✅ |
| *(added)* `sEquipmentInfoMethods[]` (131): `toString`/0 | OOJSEquipmentInfo.cpp:243 (`EquipmentInfoToString` → `OOJSCxxObjectWrapperToString`) | ✅ |
| *(added)* `sEquipmentInfoStaticMethods[]` (137): `infoForKey`/0 | OOJSEquipmentInfo.cpp:251 | ✅ |
| *(added)* `sEquipmentInfoClass` (143) | `sEquipmentInfoClass` OOJSEquipmentInfo.cpp:259 | ✅ |
| `InitOOJSEquipmentInfo()` (162) | `InitOOJSEquipmentInfo` OOJSEquipmentInfo.cpp:297 (converter `EquipmentInfoConverter` :288 gives the type as an Object node) | ✅ |
| `JSValueToEquipmentType()` (169) | `JSValueToEquipmentType` OOJSEquipmentInfo.cpp:305 | ✅ |
| `JSValueToEquipmentKey()` (188) | `JSValueToEquipmentKey` OOJSEquipmentInfo.cpp:324 | ✅ |
| `JSValueToEquipmentKeyRelaxed()` (193) | `JSValueToEquipmentKeyRelaxed` OOJSEquipmentInfo.cpp:329 | ✅ |
| `EquipmentInfoGetProperty()` (224), all cases except the following two rows | `EquipmentInfoGetProperty` OOJSEquipmentInfo.cpp:362 | ✅ |
| `EquipmentInfoGetProperty()`, `provides` case (301) | OOJSEquipmentInfo.cpp:445 | ❌ |
| `EquipmentInfoGetProperty()`, `requiresEquipment`/`requiresAnyEquipment`/`incompatibleEquipment` cases (373–383) | OOJSEquipmentInfo.cpp:518–528 via `KeyArrayOrNull` :113 | ⚠️ |
| `EquipmentInfoSetProperty()` (414) | `EquipmentInfoSetProperty` OOJSEquipmentInfo.cpp:558 | ✅ |
| `EquipmentInfoGetAllEqipment()` (471) | `EquipmentInfoGetAllEqipment` OOJSEquipmentInfo.cpp:621 | ✅ |
| `-[OOEquipmentType(OOJavaScriptExtensions) oo_jsValueInContext:]` (483) | `OOEquipmentType::jsValueInContext` OOJSEquipmentInfo.cpp:636 | ✅ |
| `-[OOEquipmentType(OOJavaScriptExtensions) oo_jsClassName]` (496) | `OOJSEquipmentInfoJSClassName` OOJSEquipmentInfo.cpp:666 (+ `jsDescription` :657, same format as the inherited `oo_jsDescriptionWithClassName:`) | ✅ |
| `-[OOEquipmentType(OOJavaScriptExtensions) oo_clearJSSelf:]` (501) | `OOEquipmentType::clearJSSelf` OOJSEquipmentInfo.cpp:649 | ✅ |
| `EquipmentInfoStaticInfoForKey()` (512) | `EquipmentInfoStaticInfoForKey` OOJSEquipmentInfo.cpp:675 | ✅ |

**Differences:**

- ❌ **med** — `EquipmentInfo.provides` returns `[]` instead of `null` for equipment with no extra-info dictionary (`equipment.plist` entries with only the required fields). Upstream sets `_provides` only inside `if (extra != nil)`, so `[nil copy]` gives JS `null`. The port's `providesForScripting()` returns a `std::vector`, so the result is always an array. Scripts that test `eq.provides` for truthiness or `=== null` take the other branch — upstream `OOJSEquipmentInfo.m:301-303`, `OOEquipmentType.m:214-240,629-632` ↔ port `OOJSEquipmentInfo.cpp:445-447`, `OOEquipmentType.cpp:263-268,603-606`
- ⚠️ **low** — `requiresEquipment`, `requiresAnyEquipment` and `incompatibleEquipment` come back as sorted key arrays instead of `NSSet -allObjects` hash order. The membership is the same and only the array order changes (port comment at :111-112) — upstream `OOJSEquipmentInfo.m:373-383` ↔ port `OOJSEquipmentInfo.cpp:113-118,518-528`
- ✅ note — `effectiveTechLevel` setter: the deprecation text, the `(null)` for a nil identifier, the 0..15 clamp that keeps 99, the `%u` mission-variable format and the warning text all match. `calculatedPrice` keeps the same EQ_FUEL formula, `(70 - fuel) * price * fuelChargeRate`, and the same `EQ_RENOVATION` branch. `installationTime` keeps its `price + 600` fallback. `scriptInfo`, `weaponInfo` and `scriptName` keep the `{}`/`""` fallbacks for nil.

## OOJSExhaustPlume

<a id="oojsexhaustplume"></a>
Upstream `src/Core/Scripting/OOJSExhaustPlume.m` ↔ `Core/Scripting/OOJSExhaustPlume.cpp`

**Status:** done — 10 rows: 10 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sExhaustPlumeProperties[]` (61): `size` (tinyid 0) READWRITE_CB | `sExhaustPlumeProperties` `Core/Scripting/OOJSExhaustPlume.cpp:131` (+ `sExhaustPlumePropertiesRaw` :123) | ✅ |
| `sExhaustPlumeMethods[]` (67): `remove` 0 | `sExhaustPlumeMethods` `Core/Scripting/OOJSExhaustPlume.cpp:139` | ✅ |
| `InitOOJSExhaustPlume()` (74) | `InitOOJSExhaustPlume` `Core/Scripting/OOJSExhaustPlume.cpp:147` | ✅ |
| `JSExhaustPlumeGetExhaustPlumeEntity()` (81) | `JSExhaustPlumeGetExhaustPlumeEntity` `Core/Scripting/OOJSExhaustPlume.cpp:156` (`dynamic_cast` for `-isKindOfClass:`) | ✅ |
| `-[OOExhaustPlumeEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (107) | `OOJSExhaustPlumeGetJSClass` `Core/Scripting/OOJSExhaustPlume.cpp:186` | ✅ |
| `-[OOExhaustPlumeEntity(OOJavaScriptExtensions) oo_jsClassName]` (113) | `OOJSExhaustPlumeJSClassName` `Core/Scripting/OOJSExhaustPlume.cpp:192` ("ExhaustPlume") | ✅ |
| `-[OOExhaustPlumeEntity(OOJavaScriptExtensions) isVisibleToScripts]` (118) | `OOJSExhaustPlumeIsVisibleToScripts` `Core/Scripting/OOJSExhaustPlume.cpp:197` | ✅ |
| `ExhaustPlumeGetProperty()` (125) | `ExhaustPlumeGetProperty` `Core/Scripting/OOJSExhaustPlume.cpp:203` | ✅ |
| `ExhaustPlumeSetProperty()` (157) | `ExhaustPlumeSetProperty` `Core/Scripting/OOJSExhaustPlume.cpp:240` | ✅ |
| `ExhaustPlumeRemove()` (201) | `ExhaustPlumeRemove` `Core/Scripting/OOJSExhaustPlume.cpp:290` | ✅ |

**Differences:**

- ✅ subtle — The `size` getter returns a Vector from `scale()`. The setter takes a `JSValueToVector` value, and anything else goes to `OOJSReportBadPropertyValue` with false. The unreachable `entity == nil` → `undefined` branch is kept — upstream `:137-149,172-186` ↔ port `:218-230,259-273`
- ✅ subtle — In `remove()`, upstream messages `[thisEnt owner]` statically typed as `ShipEntity*`; the port uses `oo::ToShip(owner())` with a null guard. A nil owner is a no-op in both. A non-ship owner, which never occurs, would have raised an unrecognized-selector exception upstream and is a silent no-op in the port — upstream `:208-209` ↔ port `:298-300`

## OOJSFlasher

<a id="oojsflasher"></a>
Upstream `src/Core/Scripting/OOJSFlasher.m` ↔ `Core/Scripting/OOJSFlasher.cpp`

**Status:** done — 10 rows: 10 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sFlasherProperties[]` (67): active, color, fraction, frequency, phase, size (tinyids 0-5), all READWRITE_CB | `sFlasherProperties` `Core/Scripting/OOJSFlasher.cpp:138` (+ `sFlasherPropertiesRaw` :153) | ✅ |
| `sFlasherMethods[]` (78): `remove` 0 | `sFlasherMethods` `Core/Scripting/OOJSFlasher.cpp:166` | ✅ |
| `InitOOJSFlasher()` (85) | `InitOOJSFlasher` `Core/Scripting/OOJSFlasher.cpp:174` | ✅ |
| `JSFlasherGetFlasherEntity()` (92) | `JSFlasherGetFlasherEntity` `Core/Scripting/OOJSFlasher.cpp:183` (`dynamic_cast` for `-isKindOfClass:`) | ✅ |
| `-[OOFlasherEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (118) | `OOJSFlasherGetJSClass` `Core/Scripting/OOJSFlasher.cpp:213` | ✅ |
| `-[OOFlasherEntity(OOJavaScriptExtensions) oo_jsClassName]` (124) | `OOJSFlasherJSClassName` `Core/Scripting/OOJSFlasher.cpp:219` ("Flasher") | ✅ |
| `-[OOFlasherEntity(OOJavaScriptExtensions) isVisibleToScripts]` (129) | `OOJSFlasherIsVisibleToScripts` `Core/Scripting/OOJSFlasher.cpp:224` | ✅ |
| `FlasherGetProperty()` (136) | `FlasherGetProperty` `Core/Scripting/OOJSFlasher.cpp:230` | ✅ |
| `FlasherSetProperty()` (185) | `FlasherSetProperty` `Core/Scripting/OOJSFlasher.cpp:285` | ✅ |
| `FlasherRemove()` (273) | `FlasherRemove` `Core/Scripting/OOJSFlasher.cpp:379` | ✅ |

**Differences:**

- ✅ subtle — The getter types match:
  - `active` is a boolean.
  - `color` is the `normalizedArray` of 4 floats, or null for no colour; the port uses `NormalizedColorComponents` with `singleReal`.
  - `frequency`, `fraction` and `phase` are numbers, and `size` is `diameter()`.

  upstream `:154-172` ↔ port `:252-270`
- ✅ subtle — The setter validation is the same:
  - `frequency` must be `>= 0`.
  - `fraction` must satisfy `0 < f <= 1`.
  - `size` must be `> 0`.
  - `phase` takes any number.
  - `color` takes an `OOColor` description, or `null` to clear it.

  NaN fails every range test, and failure goes to `OOJSReportBadPropertyValue` and returns false — upstream `:203-258` ↔ port `:307-362`
- ✅ subtle — `remove()`: for a ship owner the port calls `removeFlasher`. Otherwise it calls `removeSubEntity` on `oo::ToEffect(owner)`, guarded against null. A nil owner is a no-op in both (upstream `[nil removeSubEntity:]`). An owner that is neither a ship nor an effect, which never occurs, is a no-op in the port where upstream would have sent an unrecognized selector — upstream `:280-285` ↔ port `:386-393`

## OOJSFont

<a id="oojsfont"></a>
Upstream `src/Core/Scripting/OOJSFont.m` ↔ `Core/Scripting/OOJSFont.cpp`

**Status:** done — 2 rows: 2 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitOOJSFont()` (36) | `InitOOJSFont` OOJSFont.cpp:69 (`defaultFont` READONLY, `measureString`/1 METHOD_READONLY) | ✅ |
| `FontMeasureString()` (44) | `FontMeasureString` OOJSFont.cpp:78 | ✅ |

**Differences:**

- ✅ note — `measureString(null)` measures `""` in the port. Upstream measures a nil string. Both report the same bad-argument text, with an `undefined` argv, when the argument is undefined or missing.

## OOJSFrameCallbacks

<a id="oojsframecallbacks"></a>
Upstream `src/Core/Scripting/OOJSFrameCallbacks.m` ↔ `Core/Scripting/OOJSFrameCallbacks.cpp`

**Status:** done — 13 rows: 13 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitOOJSFrameCallbacks()` (113) | `InitOOJSFrameCallbacks` OOJSFrameCallbacks.cpp:141 | ✅ |
| `OOJSFrameCallbacksInvoke()` (127) | `OOJSFrameCallbacksInvoke` OOJSFrameCallbacks.cpp:155 | ✅ |
| `OOJSFrameCallbacksRemoveAll()` (165) | `OOJSFrameCallbacksRemoveAll` OOJSFrameCallbacks.cpp:194 | ✅ |
| `GlobalAddFrameCallback()` (180) | `GlobalAddFrameCallback` OOJSFrameCallbacks.cpp:209 | ✅ |
| `GlobalRemoveFrameCallback()` (214) | `GlobalRemoveFrameCallback` OOJSFrameCallbacks.cpp:243 | ✅ |
| `GlobalIsValidFrameCallback()` (242) | `GlobalIsValidFrameCallback` OOJSFrameCallbacks.cpp:271 | ✅ |
| `AddCallback()` (265) | `AddCallback` OOJSFrameCallbacks.cpp:295 | ✅ |
| `GrowCallbackList()` (296) | `GrowCallbackList` OOJSFrameCallbacks.cpp:328 | ✅ |
| `GetIndexForTrackingID()` (343) | `GetIndexForTrackingID` OOJSFrameCallbacks.cpp:377 | ✅ |
| `RemoveCallbackWithTrackingID()` (363) | `RemoveCallbackWithTrackingID` OOJSFrameCallbacks.cpp:399 | ✅ |
| `RemoveCallbackAtIndex()` (377) | `RemoveCallbackAtIndex` OOJSFrameCallbacks.cpp:414 | ✅ |
| `QueueDeferredOperation()` (398) | `QueueDeferredOperation` OOJSFrameCallbacks.cpp:436 (a `std::vector<DeferredOperation>` instead of an array of dicts) | ✅ |
| `RunDeferredOperations()` (411) | `RunDeferredOperations` OOJSFrameCallbacks.cpp:446 | ✅ |

**Differences:**

- ✅ note (ordering) — The ID scramble constants are unchanged (`0x2315EB16`, `992699`), and the ID is still seeded from `timeIntervalSinceReferenceDate`. Callbacks run in slot order `0..sCount-1`. Removal swaps the last entry into the removed slot, so ordering after a removal is the same as upstream — upstream `:147-151,386-388` ↔ port `:175-179,423-425`
- ✅ note (mutation during iteration) — While running, add and remove are queued in call order and replayed after the loop. A deferred remove of an unknown ID is still silent (no warning), and a failed deferred add logs `script.frameCallback.deferredAdd.failed` with the same text. Upstream round-trips the ID through `NSNumber numberWithInt` and `oo_intForKey`; the port stores the `uint32_t` directly, which is lossless both ways — upstream `:398-432` ↔ port `:436-465`
- ✅ note — `addFrameCallback` returns `INT_TO_JSVAL`/`int32Value` of a `uint32` on both sides, so IDs ≥ 2³¹ come back negative in both. Argument-error texts are identical ("function", "frame callback tracking ID"), and so is `"removeFrameCallback(): invalid tracking ID."`.

## OOJSFunction

<a id="oojsfunction"></a>
Upstream `src/Core/Scripting/OOJSFunction.m` ↔ `Core/Scripting/OOJSFunction.cpp`

**Status:** done — 12 rows: 8 ✅ 0 ⚠️ 1 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJSFunction initWithFunction:context:]` (32) | `OOJSFunction::initWithFunction()` `Core/Scripting/OOJSFunction.cpp:39` + ctor `Core/Scripting/OOJSFunction.cpp:50` | ✅ |
| `-[OOJSFunction initWithName:]` (55) | `OOJSFunction::initWithName()` `Core/Scripting/OOJSFunction.cpp:63` → `ooscript::compileUCFunction` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3935` | ❌ |
| `-[OOJSFunction deleteJSValue]` (114) | `OOJSFunction::deleteJSValue()` `Core/Scripting/OOJSFunction.cpp:122` | ✅ |
| `-[OOJSFunction dealloc]` (128) | `OOJSFunction::~OOJSFunction()` `Core/Scripting/OOJSFunction.cpp:135` | ✅ |
| `-[OOJSFunction descriptionComponents]` (136) | `OOJSFunction::descriptionComponents()` `Core/Scripting/OOJSFunction.cpp:140` | ✅ |
| `-[OOJSFunction name]` (144) | `OOJSFunction::name()` `Core/Scripting/OOJSFunction.cpp:145` | ✅ |
| `-[OOJSFunction function]` (149) | `OOJSFunction::function()` `Core/Scripting/OOJSFunction.cpp:150` | ✅ |
| `-[OOJSFunction functionValue]` (154) | `OOJSFunction::functionValue()` `Core/Scripting/OOJSFunction.cpp:155` | ✅ |
| `-[OOJSFunction evaluateWithContext:]` (163) | `OOJSFunction::evaluateWithContext()` `Core/Scripting/OOJSFunction.cpp:164` → `ooscript::callFunction` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3962` | ✅ |
| `-[OOJSFunction evaluateWithContext:]` (179) | — removed, bead oo-4aq6a.6.2 (`Core/Scripting/OOJSFunction.cpp:179-180`) | ➖ |
| `-[OOJSFunction evaluateWithContext:]` (211) | — removed, bead oo-4aq6a.6.2 | ➖ |
| `-[OOJSFunction evaluatePredicateWithContext:]` (226) | — removed, bead oo-4aq6a.6.2 (no game caller; the AI scan predicate goes through `JSFunctionPredicate` in OOJavaScriptEngine) | ➖ |

**Differences:**

- ❌ **low** — The named function is no longer defined on the scope. SpiderMonkey's `CompileUCFunction` defines `name` as an enumerable property of the scope object. Both callers pass a NULL scope (the global), so upstream the global gained `_oo_AIScanPredicate` / `matchesRegExp`. The port evaluates a named function expression and defines nothing. — upstream `Core/Scripting/OOJSFunction.m:95` (SpiderMonkey `jsapi.cpp:4880-4884`) ↔ port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3935-3957`
- ❌ **low** — Line numbers shift. The port wraps the body as `"(function name(args) {\n" + body + "\n})"` and evaluates it at line `lineno-1`, clamped to 1. For `lineNumber` 0 (ShipEntityAI's `_oo_AIScanPredicate`) or 1, body errors are reported at line 2 instead of 0/1. — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3953-3954`, `Core/Entities/ShipEntityAI.cpp:2249-2256`
- ❌ **low** — "Compile" now evaluates text. The body is spliced into source and the wrapper expression is run, so a body with an unbalanced `}` can close the wrapper and run code in global scope at compile time, or return a non-function. An example is an AI-plist scan predicate, which is wrapped in `"return " + expr + ";"`. Upstream `compileFunctionBody` parsed the body alone and ran nothing. — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3940-3956`
- **low** — Scope chain and error reporting:
  - SpiderMonkey parents the function to `scope`, so free identifiers resolve through it. The port's function closes over the global plus the filename-based scope fallback. No visible effect today, since both callers pass NULL (the global).
  - A syntax error reaches the reporter as a pending exception (`ReportFlag::Exception` via `finish`/`reportPendingImpl`) with QuickJS-ng wording, not as SpiderMonkey's compile-error report.
  - — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:886-936,2329-2350`
- Subtle, ✅:
  - `_name` is read from the function's `name` property (`getFunctionId` `JSEngine_quickjs.cpp:3121`); an empty name becomes null and prints `<anonymous>`. Upstream used the compile atom, with the same result.
  - `_function` is rooted by address in the handle arena, as SpiderMonkey's named root was.
  - A NULL `this` in `callFunction` becomes the global for a non-strict function in both engines.
  - Code is converted with `utf8ToUtf16`, matching `getCharacters:`.
  - — port `Core/Scripting/OOJSFunction.cpp:54-55,92,172`

## OOJSGlobal

<a id="oojsglobal"></a>
Upstream `src/Core/Scripting/OOJSGlobal.m` ↔ `Core/Scripting/OOJSGlobal.cpp`

**Status:** done — 26 rows: 24 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sGlobalClass` (85) | `sGlobalClass` `Core/Scripting/OOJSGlobal.cpp:190` | ✅ |
| `sGlobalProperties` (114) | `sGlobalProperties` `Core/Scripting/OOJSGlobal.cpp:229` (+ `sGlobalPropertiesRaw` :245 for error reporters) | ✅ |
| `sGlobalMethods` (124) | `sGlobalMethods` `Core/Scripting/OOJSGlobal.cpp:257` | ✅ |
| `CreateOOJSGlobal()` (151) | `CreateOOJSGlobal` `Core/Scripting/OOJSGlobal.cpp:289` | ✅ |
| `SetUpOOJSGlobal()` (161) | `SetUpOOJSGlobal` `Core/Scripting/OOJSGlobal.cpp:302` | ✅ |
| `GlobalGetProperty()` (167) | `GlobalGetProperty` `Core/Scripting/OOJSGlobal.cpp:311` | ✅ |
| `GlobalSetProperty()` (199) | `GlobalSetProperty` `Core/Scripting/OOJSGlobal.cpp:348` | ✅ |
| `GlobalLog()` (230) | `GlobalLog` `Core/Scripting/OOJSGlobal.cpp:385` | ❌ |
| `GlobalExpandDescription()` (269) | `GlobalExpandDescription` `Core/Scripting/OOJSGlobal.cpp:432` | ✅ |
| `GlobalKeyBindingDescription()` (295) | `GlobalKeyBindingDescription` `Core/Scripting/OOJSGlobal.cpp:461` | ✅ |
| `GlobalExpandMissionText()` (319) | `GlobalExpandMissionText` `Core/Scripting/OOJSGlobal.cpp:488` | ✅ |
| `GlobalDisplayNameForCommodity()` (345) | `GlobalDisplayNameForCommodity` `Core/Scripting/OOJSGlobal.cpp:519` | ✅ |
| `GlobalRandomName()` (363) | `GlobalRandomName` `Core/Scripting/OOJSGlobal.cpp:540` | ✅ |
| `GlobalRandomInhabitantsDescription()` (384) | `GlobalRandomInhabitantsDescription` `Core/Scripting/OOJSGlobal.cpp:564` | ✅ |
| `GlobalClearExtraGuiScreenKeys()` (404) | `GlobalClearExtraGuiScreenKeys` `Core/Scripting/OOJSGlobal.cpp:587` | ✅ |
| `GlobalSetExtraGuiScreenKeys()` (436) | `GlobalSetExtraGuiScreenKeys` `Core/Scripting/OOJSGlobal.cpp:623` | ✅ |
| `GlobalSetScreenBackground()` (517) | `GlobalSetScreenBackground` `Core/Scripting/OOJSGlobal.cpp:714` | ✅ |
| `GlobalGetScreenBackgroundForKey()` (547) | `GlobalGetScreenBackgroundForKey` `Core/Scripting/OOJSGlobal.cpp:749` | ✅ |
| `GlobalSetScreenBackgroundForKey()` (568) | `GlobalSetScreenBackgroundForKey` `Core/Scripting/OOJSGlobal.cpp:771` | ✅ |
| `GlobalSetScreenOverlay()` (598) | `GlobalSetScreenOverlay` `Core/Scripting/OOJSGlobal.cpp:805` | ✅ |
| `GlobalGetGuiColorSettingForKey()` (624) | `GlobalGetGuiColorSettingForKey` `Core/Scripting/OOJSGlobal.cpp:834` | ✅ |
| `GlobalSetGuiColorSettingForKey()` (651) | `GlobalSetGuiColorSettingForKey` `Core/Scripting/OOJSGlobal.cpp:869` | ✅ |
| `GlobalTakeSnapShot()` (693) | `GlobalTakeSnapShot` `Core/Scripting/OOJSGlobal.cpp:914` | ❌ |
| `GlobalAutoAIForRole()` (734) | `GlobalAutoAIForRole` `Core/Scripting/OOJSGlobal.cpp:978` | ✅ |
| `GlobalPauseGame()` (756) | `GlobalPauseGame` `Core/Scripting/OOJSGlobal.cpp:1003` | ✅ |
| `GlobalQuitGame()` (778) | `GlobalQuitGame` `Core/Scripting/OOJSGlobal.cpp:1029` | ✅ |

**Differences:**

- ❌ **low** — takeSnapShot(): the port copies `-defaultCommanderPath` inline but drops its two error logs, `savedGame.defaultPath.create.failed` and `savedGame.defaultPath.notDirectory`. `GameController.cpp:820,824` still has them. The fallback path is the same; only the log lines are missing (debug-monitor builds only). — upstream `Core/NSFileManagerOOExtensions.m:97,104` (via `Core/Scripting/OOJSGlobal.m:711`) ↔ port `Core/Scripting/OOJSGlobal.cpp:940-953`
- ❌ **low** — log(class, a, b, …): this only differs when an argument's `toString()` throws. Upstream `+concatenationOfStringsFromJavaScriptValues:` skips a nil first element without adding a separator. A nil later element raises NSInvalidArgumentException on `appendString:nil`, so the error goes to JS and no log line is written. The port turns any nil into `""`, always adds `", "`, and still logs. — upstream `Core/Scripting/OOJavaScriptEngine.m:1647-1655` (via `Core/Scripting/OOJSGlobal.m:250`) ↔ port `Core/Scripting/OOJSGlobal.cpp:407-413`
- ✅ **low** — note: these all match upstream:
  - The property flags: `galaxyNumber` and `guiScreen` are READONLY_CB; `timeAccelerationFactor` is READWRITE_CB (debug only); `global` is READONLY.
  - Function arg counts.
  - All warning and bad-argument texts, including upstream's "idenfifier" typo and clearExtraGuiScreenKeys reporting as "setExtraGuiScreenKeys" when argc < 2. The only change is the format specifier, `%@` to `%s`.
  - The rules for which GUI screens are excluded.
  - The pauseGame screen conditions. — upstream `Core/Scripting/OOJSGlobal.m:114-149,412,469,766` ↔ port `Core/Scripting/OOJSGlobal.cpp:225-282,596,661,1014`
- ✅ **low** — note: setting timeAccelerationFactor clamps the same way: a value outside [MIN, MAX] becomes DEFAULT, in `Universe` in both. expandMissionText with a missing key returns null in both: upstream passes nil to OOExpandDescriptionString, which returns nil; the port skips the call. — upstream `Core/Universe.m:6666`, `Core/OOStringExpander.m:162` ↔ port `Core/Universe.cpp:7101`, `Core/Scripting/OOJSGlobal.cpp:508`

## OOJSGuiScreenKeyDefinition

<a id="oojsguiscreenkeydefinition"></a>
Upstream `src/Core/Scripting/OOJSGuiScreenKeyDefinition.m` ↔ `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp`

**Status:** done — 13 rows: 13 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJSGuiScreenKeyDefinition init]` (31) | constructor OOJSGuiScreenKeyDefinition.cpp:64 | ✅ |
| `-[OOJSGuiScreenKeyDefinition deleteJSPointers]` (47) | `deleteJSPointers` OOJSGuiScreenKeyDefinition.cpp:76 | ✅ |
| `-[OOJSGuiScreenKeyDefinition dealloc]` (63) | destructor OOJSGuiScreenKeyDefinition.cpp:91 | ✅ |
| `-[OOJSGuiScreenKeyDefinition name]` (72) | `name` OOJSGuiScreenKeyDefinition.cpp:98 | ✅ |
| `-[OOJSGuiScreenKeyDefinition setName:]` (77) | `setName` OOJSGuiScreenKeyDefinition.cpp:103 | ✅ |
| `-[OOJSGuiScreenKeyDefinition registerKeys]` (83) | `registerKeys` OOJSGuiScreenKeyDefinition.cpp:108 | ✅ |
| `-[OOJSGuiScreenKeyDefinition setRegisterKeys:]` (88) | `setRegisterKeys` OOJSGuiScreenKeyDefinition.cpp:113 (value copy = `-copy`) | ✅ |
| `-[OOJSGuiScreenKeyDefinition callback]` (94) | `callback` OOJSGuiScreenKeyDefinition.cpp:118 | ✅ |
| `-[OOJSGuiScreenKeyDefinition setCallback:]` (99) | `setCallback` OOJSGuiScreenKeyDefinition.cpp:123 | ✅ |
| `-[OOJSGuiScreenKeyDefinition callbackThis]` (108) | `callbackThis` OOJSGuiScreenKeyDefinition.cpp:132 | ✅ |
| `-[OOJSGuiScreenKeyDefinition setCallbackThis:]` (113) | `setCallbackThis` OOJSGuiScreenKeyDefinition.cpp:137 | ✅ |
| `-[OOJSGuiScreenKeyDefinition runCallback:]` (122) | `runCallback` OOJSGuiScreenKeyDefinition.cpp:146 | ✅ |
| `-[OOJSGuiScreenKeyDefinition interfaceCompare:]` (145) | `interfaceCompare` OOJSGuiScreenKeyDefinition.cpp:164 | ✅ |

**Differences:**

- ✅ note — `interfaceCompare` with a nil `_name` returns `OOOrderedSame`, which models a message to nil. A nil other name compares as `""`. The case-folding rules are those of `oo::str::caseInsensitiveCompare` (audited with foundation) — upstream `:145-148` ↔ port `:164-172`

## OOJSInterfaceDefinition

<a id="oojsinterfacedefinition"></a>
Upstream `src/Core/Scripting/OOJSInterfaceDefinition.m` ↔ `Core/Scripting/OOJSInterfaceDefinition.cpp`

**Status:** done — 15 rows: 15 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJSInterfaceDefinition init]` (31) | constructor OOJSInterfaceDefinition.cpp:60 | ✅ |
| `-[OOJSInterfaceDefinition deleteJSPointers]` (47) | `deleteJSPointers` OOJSInterfaceDefinition.cpp:72 | ✅ |
| `-[OOJSInterfaceDefinition dealloc]` (63) | destructor OOJSInterfaceDefinition.cpp:87 | ✅ |
| `-[OOJSInterfaceDefinition title]` (72) | `title` OOJSInterfaceDefinition.cpp:94 | ✅ |
| `-[OOJSInterfaceDefinition setTitle:]` (77) | `setTitle` OOJSInterfaceDefinition.cpp:99 | ✅ |
| `-[OOJSInterfaceDefinition category]` (83) | `category` OOJSInterfaceDefinition.cpp:104 | ✅ |
| `-[OOJSInterfaceDefinition setCategory:]` (88) | `setCategory` OOJSInterfaceDefinition.cpp:109 (non-optional; the only caller, `Station.setInterface`, never passes nil) | ✅ |
| `-[OOJSInterfaceDefinition summary]` (94) | `summary` OOJSInterfaceDefinition.cpp:114 | ✅ |
| `-[OOJSInterfaceDefinition setSummary:]` (99) | `setSummary` OOJSInterfaceDefinition.cpp:119 (same as above) | ✅ |
| `-[OOJSInterfaceDefinition callback]` (105) | `callback` OOJSInterfaceDefinition.cpp:124 | ✅ |
| `-[OOJSInterfaceDefinition setCallback:]` (110) | `setCallback` OOJSInterfaceDefinition.cpp:129 | ✅ |
| `-[OOJSInterfaceDefinition callbackThis]` (119) | `callbackThis` OOJSInterfaceDefinition.cpp:138 | ✅ |
| `-[OOJSInterfaceDefinition setCallbackThis:]` (124) | `setCallbackThis` OOJSInterfaceDefinition.cpp:143 | ✅ |
| `-[OOJSInterfaceDefinition runCallback:]` (133) | `runCallback` OOJSInterfaceDefinition.cpp:152 | ✅ |
| `-[OOJSInterfaceDefinition interfaceCompare:]` (156) | `interfaceCompare` OOJSInterfaceDefinition.cpp:170 + `CaseInsensitiveCompare` :46 | ✅ |

**Differences:**

- ✅ note — The nil branches of `CaseInsensitiveCompare` cannot be reached. `Station.setInterface` always supplies a non-empty title, and a non-empty category (defaulting to `interfaces-category-uncategorised`) — upstream `OOJSStation.m:763-808` ↔ port `OOJSStation.cpp:1022-1069`

## OOJSManifest

<a id="oojsmanifest"></a>
Upstream `src/Core/Scripting/OOJSManifest.m` ↔ `Core/Scripting/OOJSManifest.cpp`

**Status:** done — 14 rows: 10 ✅ 0 ⚠️ 1 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sManifestClass` JSClass (47) | `sManifestClass` ClassDef `Core/Scripting/OOJSManifest.cpp:102` (HasPrivate; del/get/set hooks; finalize `OOJSObjectWrapperFinalize`) | ✅ |
| enum + `sManifestProperties[]` (62, 66) | enum `:121`, `sManifestProperties[]` `:126` (`list`, ReadOnly\|Permanent\|Enumerate\|Shared = READONLY_CB) | ✅ |
| `sManifestMethods[]` (72) | `sManifestMethods[]` `Core/Scripting/OOJSManifest.cpp:134` (shortComment 1, setShortComment 2, comment 1, setComment 2) | ✅ |
| `-[OOManifest dealloc]` (87) | — removed (port comment `Core/Scripting/OOJSManifest.cpp:144`) | ➖ |
| `-[OOManifest oo_jsClassName]` (92) | — removed | ➖ |
| `-[OOManifest oo_jsValueInContext:]` (97) | — removed | ➖ |
| `InitOOJSManifest()` (115) | `InitOOJSManifest` `Core/Scripting/OOJSManifest.cpp:148` | ✅ |
| `ManifestDeleteProperty()` (129) | `ManifestDeleteProperty` `Core/Scripting/OOJSManifest.cpp:162` (body equal; the engine calls it less often) | ❌ |
| `ManifestGetProperty()` (135) | `ManifestGetProperty` `Core/Scripting/OOJSManifest.cpp:170` | ✅ |
| `ManifestSetProperty()` (172) | `ManifestSetProperty` `Core/Scripting/OOJSManifest.cpp:213` | ✅ |
| `ManifestComment()` (202) | `ManifestComment` `Core/Scripting/OOJSManifest.cpp:254` | ✅ |
| `ManifestSetComment()` (224) | `ManifestSetComment` `Core/Scripting/OOJSManifest.cpp:282` | ✅ |
| `ManifestShortComment()` (248) | `ManifestShortComment` `Core/Scripting/OOJSManifest.cpp:311` | ✅ |
| `ManifestSetShortComment()` (270) | `ManifestSetShortComment` `Core/Scripting/OOJSManifest.cpp:339` | ✅ |

**Differences:**

- ❌ **low** — `delete manifest.<commodity>` reaches the delProperty hook only if that name was assigned on the same object first; this is the QuickJS `ExDeleteProperty` own-slot gate (see OOJSMissionVariables). Upstream always ran the hook, which calls `ManifestSetProperty(undefined)`: `JS_ValueToInt32(undefined)` fails and the bad-value report fires, so the cargo is unchanged. The port returns `true` silently. The cargo outcome is the same; only the error report differs — upstream `Core/Scripting/OOJSManifest.m:129-133`, `:189-195` ↔ port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:1599-1606`
- ➖ **low** — `OOManifest` is gone. Upstream never instantiated it (no reference outside `OOJSManifest.m`), and both Manifest objects carry a NULL private, so nothing changes in behaviour — upstream `Core/Scripting/OOJSManifest.m:82-113` ↔ port `Core/Scripting/OOJSManifest.cpp:144-146`
- ✅ **low** — init:
  - The port no longer registers `OOJSBasicPrivateObjectConverter` for the class. Upstream's converter answered nil for the NULL private, and an unregistered class makes `cxx_OOJSPListFromJSObject` answer a null PList (`OOJavaScriptEngine.cpp:2072-2076`), so any conversion of a Manifest object, including as a Timer's `this`, gives the same nothing.
  - `player.ship.manifest` (private explicitly set to NULL) and the global `manifest` are both defined READONLY, as before.

  upstream `Core/Scripting/OOJSManifest.m:115-127` ↔ port `Core/Scripting/OOJSManifest.cpp:148-159`
- ✅ **low** — get, set and the comment methods:
  - **Get:** `list` is `cargoListForScripting`. A defined commodity name gives an int32 quantity; any other string leaves the value untouched (undefined or the stored slot).
  - **Set, special cargo:** with special cargo aboard, a tonnage good warns "PlayerShip.manifest['foo'] - cannot modify cargo tonnage when Special Cargo is in use.". `getSpecialCargo().has_value()` is the test where upstream tested for a non-nil NSString, and a nil market defaults to `UNITS_TONS` (0), as before.
  - **Set, value:** the value is rounded and validated by `ValueToInt32`, clamped at 0, and stored for any string key. A failure triggers the bad-value report.
  - **Comments:** `comment`/`shortComment` return the string or null; `setComment`/`setShortComment` return the bool, false without a player market. The bad-argument texts and the `MIN(argc, n)` counts are identical.

  upstream `Core/Scripting/OOJSManifest.m:135-291` ↔ port `Core/Scripting/OOJSManifest.cpp:170-363`

## OOJSMission

<a id="oojsmission"></a>
Upstream `src/Core/Scripting/OOJSMission.m` ↔ `Core/Scripting/OOJSMission.cpp`

**Status:** done — 18 rows: 17 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sMissionClass` (60) | `sMissionClass` `Core/Scripting/OOJSMission.cpp:135` | ✅ |
| `sMissionProperties` (80) | `sMissionProperties` `Core/Scripting/OOJSMission.cpp:163` | ✅ |
| `sMissionMethods` (88) | `sMissionMethods` `Core/Scripting/OOJSMission.cpp:173` | ✅ |
| `InitOOJSMission()` (100) | `InitOOJSMission` `Core/Scripting/OOJSMission.cpp:186` | ✅ |
| `MissionRunCallback()` (113) | `MissionRunCallback` `Core/Scripting/OOJSMission.cpp:199` | ✅ |
| `MissionGetProperty()` (176) | `MissionGetProperty` `Core/Scripting/OOJSMission.cpp:263` | ⚠️ |
| `MissionSetProperty()` (213) | `MissionSetProperty` `Core/Scripting/OOJSMission.cpp:313` | ✅ |
| `MissionMarkSystem()` (242) | `MissionMarkSystem` `Core/Scripting/OOJSMission.cpp:347` | ✅ |
| `MissionUnmarkSystem()` (283) | `MissionUnmarkSystem` `Core/Scripting/OOJSMission.cpp:393` | ✅ |
| `MissionAddMessageText()` (330) | `MissionAddMessageText` `Core/Scripting/OOJSMission.cpp:443` | ✅ |
| `MissionSetInstructionsKey()` (352) | `MissionSetInstructionsKey` `Core/Scripting/OOJSMission.cpp:471` | ✅ |
| `MissionSetInstructions()` (358) | `MissionSetInstructions` `Core/Scripting/OOJSMission.cpp:479` | ✅ |
| `MissionSetInstructionsInternal()` (363) | `MissionSetInstructionsInternal` `Core/Scripting/OOJSMission.cpp:486` | ✅ |
| `GetParameterDictionary()` (406) | `GetParameterDictionary` `Core/Scripting/OOJSMission.cpp:541` | ✅ |
| `GetParameterString()` (417) | `GetParameterString` `Core/Scripting/OOJSMission.cpp:554` | ✅ |
| `GetParameterImageDescriptor()` (426) | `GetParameterImageDescriptor` `Core/Scripting/OOJSMission.cpp:574` | ✅ |
| `MissionRunScreen()` (437) | `MissionRunScreen` `Core/Scripting/OOJSMission.cpp:587` | ✅ |
| `MissionRunShipLibrary()` (652) | `MissionRunShipLibrary` `Core/Scripting/OOJSMission.cpp:840` | ✅ |

**Differences:**

- ⚠️ **low** — mission.markedSystems: the port returns the marker values in the destinations Dict's key order. Upstream `-allValues` gave NSDictionary hash order. The port comment says so ("-allValues gave hash order"). Scripts that index the array can see a different order. — upstream `Core/Scripting/OOJSMission.m:188-191` ↔ port `Core/Scripting/OOJSMission.cpp:277-288`
- ✅ **low** — note: setInstructions/setInstructionsKey with null or no text and no missionKey (no running script). Upstream `clearMissionDescriptionForMission:nil` logged `kOOLogScriptMissionDescNoKey` "in %@, mission key not set". The port gets the same log by calling `setMissionInstructions("", nullopt)`. With a key, `clearMissionDescriptionForMission` is called directly, as before. — upstream `Core/Scripting/OOJSMission.m:398`, `Core/Entities/PlayerEntityLegacyScriptEngine.m:784-786` ↔ port `Core/Scripting/OOJSMission.cpp:525-531`, `Core/Entities/PlayerEntityLegacyScriptEngine.cpp:886-888`
- ✅ **low** — note on runScreen:
  - The keys read, and their order, are the same: title / titleKey (title wins whenever it is not undefined, even if null), music, overlay, background, backgroundSpecial, customChartZoom/Centre/CentreInLY, model / spinModel / modelPersonality, allowInterrupt (forced on in flight), exitScreen (default STATUS), screenID, registerKeys, textEntry, then message / messageKey, choices / choicesKey (skipped when textEntry is on), and initialChoicesKey.
  - Where upstream passed nil for backgroundSpecial, choicesKey and the closing setMissionMusic, the port passes `""`; the callees treat `""` as nil.
  - The model role nil becomes `""` before `newShipWithRole`.
  - Neither version has an "already running" check.
  - The warning texts match. — upstream `Core/Scripting/OOJSMission.m:487-643` ↔ port `Core/Scripting/OOJSMission.cpp:640-829`, `Core/Entities/PlayerEntity.cpp:11792`, `Core/Entities/PlayerEntityLegacyScriptEngine.cpp:1975`
- ✅ **low** — note on MissionRunCallback: the order is unchanged:
  1. Copy the callback statics to rooted locals.
  2. Clear the statics.
  3. Read the choice and key-press strings.
  4. Reset the choice silently.
  5. Push the script and call the function.
  6. Pop the script, release it and unroot.

  Upstream caught only NSException; the port catches only OOException, logs the same text, and rethrows anything else. — upstream `Core/Scripting/OOJSMission.m:130-173` ↔ port `Core/Scripting/OOJSMission.cpp:216-259`
- ✅ **low** — note on markSystem/unmarkSystem: the façade's `valueToInt32` copies SpiderMonkey's old non-ECMA JS_ValueToInt32. It rounds to nearest and raises "can't convert … to an integer" for NaN and out-of-range values. So object arguments still take the marker-dict path, and null still means system 0. `marker.get<int>("system", -1)` on a null marker gives 0, the same as messaging nil. — upstream `Core/Scripting/OOJSMission.m:251-275` ↔ port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:2435-2458`, `Core/Scripting/OOJSMission.cpp:357-383`

## OOJSMissionVariables

<a id="oojsmissionvariables"></a>
Upstream `src/Core/Scripting/OOJSMissionVariables.m` ↔ `Core/Scripting/OOJSMissionVariables.cpp`

**Status:** done — 8 rows: 6 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `KeyForPropertyID()` (34) | `KeyForPropertyID` `Core/Scripting/OOJSMissionVariables.cpp:71` (`"_"` prefix → nullopt; else `"mission_" + key`) | ✅ |
| `sMissionVariablesClass` JSClass (53) | `sMissionVariablesClass` ClassDef `Core/Scripting/OOJSMissionVariables.cpp:109` (NewEnumerate; del/get/set hooks; enumerate in `newEnumerate`) | ✅ |
| `InitOOJSMissionVariables()` (67) | `InitOOJSMissionVariables` `Core/Scripting/OOJSMissionVariables.cpp:128` | ✅ |
| `MissionVariablesConverter()` (78) | `MissionVariablesConverter` `Core/Scripting/OOJSMissionVariables.cpp:140` (debug-monitor only; answers a PList copy of the dictionary) | ✅ |
| `MissionVariablesDeleteProperty()` (84) | `MissionVariablesDeleteProperty` `Core/Scripting/OOJSMissionVariables.cpp:150` (body equal; the engine calls it less often) | ❌ |
| `MissionVariablesGetProperty()` (99) | `MissionVariablesGetProperty` `Core/Scripting/OOJSMissionVariables.cpp:176` | ✅ |
| `MissionVariablesSetProperty()` (126) | `MissionVariablesSetProperty` `Core/Scripting/OOJSMissionVariables.cpp:211` | ✅ |
| `MissionVariablesEnumerate()` (150) | `MissionVariablesEnumerate` `Core/Scripting/OOJSMissionVariables.cpp:245` (state struct `:83` replaces the retained NSEnumerator) | ⚠️ |

**Differences:**

- ❌ **high** — `delete missionVariables.foo` no longer clears the variable unless `foo` was assigned through this JS object since the context was created. That rules out variables loaded from a saved game, set by a legacy plist script or set before an engine reset. In SpiderMonkey, delete on a missing or non-own property still called the class delProperty hook (`upstream/spidermonkey-ff4/js/src/jsobj.cpp:5880`), so the hook ran `setMissionVariable:nil`. The QuickJS `ExDeleteProperty` returns true without calling the hook when there is no own slot; a get creates no slot (`ExGetProperty` `:1343`), only an assignment does (`ExSetProperty` `:1531-1544`). The variable silently survives and is written to the next save. The unit tests cover only the "assigned first" case (`tests/unit/core/test_OOJSMissionVariables.cpp:333-336`) — upstream `Core/Scripting/OOJSMissionVariables.m:84-97` ↔ port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:1599-1620`
- ⚠️ **low** — `for…in`/`Object.keys(missionVariables)` lists names in sorted key order (PList::Dict) instead of NSDictionary `-allKeys` hash order. The port comment says so ("In key order (-allKeys gave them in hash order)"). The INIT count still includes the non-`mission_` keys that NEXT skips, as upstream did — upstream `Core/Scripting/OOJSMissionVariables.m:161` ↔ port `Core/Scripting/OOJSMissionVariables.cpp:259-266`
- ✅ **low** — the type coercion round-trip is unchanged:
  - **Set** stores `ToString(value)` for anything except null/undefined, so a number becomes its JS string and a boolean becomes `"true"`/`"false"`. `cxx_OOStringFromJSValue` returns nullopt for null/undefined, which removes the key, as nil did.
  - **Get** returns a JS number when the stored string passes `OOIsNumberLiteral(s, allowSpaces=YES)`, converted with `-doubleValue` (`oo::str::doubleValue`). Any other stored value goes through the PList/native conversion. An unset variable is **null**, not undefined (`OOJSValueFromPList(Null)` `OOJavaScriptEngine.cpp:1224`).
  - A `_`-prefixed name returns undefined on get (the hook leaves the value alone), is a no-op on delete, and on set raises `Invalid mission variable name "%s".` with the JS-escaped name. The setter's dropped `NSNull` test could never match a string — upstream `Core/Scripting/OOJSMissionVariables.m:99-148` ↔ port `Core/Scripting/OOJSMissionVariables.cpp:176-241`
- ✅ **low** — the debug-monitor converter now answers a copy (`PLAYER->missionVariables()`) instead of the live `NSMutableDictionary`. Upstream needed the live dictionary so that `callObjC` could reach it; the port's `callObjC` (`Core/Scripting/OOJSCall.cpp`) dispatches only entity methods, so nothing can mutate through it — upstream `Core/Scripting/OOJSMissionVariables.m:78-81` ↔ port `Core/Scripting/OOJSMissionVariables.cpp:140-145`

## OOJSOolite

<a id="oojsoolite"></a>
Upstream `src/Core/Scripting/OOJSOolite.m` ↔ `Core/Scripting/OOJSOolite.cpp`

**Status:** done — 9 rows: 8 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sOoliteClass` JSClass (44) | `sOoliteClass` ClassDef `Core/Scripting/OOJSOolite.cpp:109` (flags None; get/set hooks; stubs → nullptr) | ✅ |
| `sOoliteProperties[]` + enum (59, 76) | enum `:128`, `sOoliteProperties[]` `:151` (RO = Permanent\|Enumerate\|ReadOnly\|Shared, RW = Permanent\|Enumerate\|Shared; same 10 names + debug `timeAccelerationFactor`), reporter mirror `sOolitePropertiesRaw[]` `:173` | ✅ |
| `sOoliteMethods[]` (94) | `sOoliteMethods[]` `Core/Scripting/OOJSOolite.cpp:193` (compareVersion, 1) | ✅ |
| `InitOOJSOolite()` (100) | `InitOOJSOolite` `Core/Scripting/OOJSOolite.cpp:204` (`oolite` object Permanent\|Enumerate\|ReadOnly = OOJS_PROP_READONLY) | ✅ |
| `OoliteGetProperty()` (106) | `OoliteGetProperty` `Core/Scripting/OOJSOolite.cpp:211` | ❌ |
| `OoliteSetProperty()` (185) | `OoliteSetProperty` `Core/Scripting/OOJSOolite.cpp:311` | ✅ |
| `VersionString()` (262) | `VersionString` `Core/Scripting/OOJSOolite.cpp:399` → `OoliteInfoString("CFBundleVersion")` `:46` | ✅ |
| `VersionComponents()` (267) | `VersionComponents` `Core/Scripting/OOJSOolite.cpp:406` (`oo::str::versionComponents`) | ✅ |
| `OoliteCompareVersion()` (279) | `OoliteCompareVersion` `Core/Scripting/OOJSOolite.cpp:433` (+ `UnsignedIntValue` `:415` for `-unsignedIntValue`) | ✅ |

**Differences:**

- ❌ **low** — `oolite.gameSettings` is a `PList::Dict`, so its keys enumerate in sorted order. Upstream's `[UNIVERSE gameSettings]` NSDictionary enumerated in hash order. This shows in `for…in`, `Object.keys` and `JSON.stringify` of the object; the values are the same — upstream `Core/Scripting/OOJSOolite.m:134` ↔ port `Core/Scripting/OOJSOolite.cpp:251`
- ✅ **low** — the version is read from `Info-gnustep.plist` in the built-in resources directory, and the file is read again on every `version`/`versionString`/`compareVersion` access. Upstream used `[[NSBundle mainBundle] infoDictionary]`, which GNUstep caches. The value is the same; if the file is missing or unparsable, `versionString` is null and `version` is `[]`, as `ComponentsFromVersionString(nil)` gave. Other ported files use the same helper (`Core/Entities/PlayerEntity.cpp:317`) — upstream `Core/Scripting/OOJSOolite.m:264` ↔ port `Core/Scripting/OOJSOolite.cpp:46-58`
- ✅ **low** — `jsVersion` and `jsVersionString` still answer 185 and `"ECMAv5"`. The façade emulates `JS_GetVersion`/`JS_VersionToString`, and init still sets `OOJSENGINE_JSVERSION` — upstream `Core/Scripting/OOJSOolite.m:126-130`, `OOJavaScriptEngine.m:307` ↔ port `Core/Scripting/OOJSOolite.cpp:243-248`, `ooscript/JSEngine.hpp:531-539`, `ooscript/JSEngine_quickjs.cpp:3793-3811`
- ✅ **low** — `compareVersion`:
  - With no argument, it returns undefined.
  - An array counts only if every element is a number. Bool counts as a number in both (`isNumber` / `isKindOfClass:NSNumber`), and each element goes through a C cast to unsigned.
  - A string goes through version-string parsing.
  - Anything else returns undefined.
  - The `(int32_t)CompareVersions` result is the same.

  Setters: `postFX` clamps with `MAX(iValue, 0)`; the tone mappers reject non-strings with a bad-value report. The HDR warning is Windows-only, and the warning texts are identical — upstream `Core/Scripting/OOJSOolite.m:198-257`, `:287-308` ↔ port `Core/Scripting/OOJSOolite.cpp:327-394`, `:440-465`

## OOJSPlanet

<a id="oojsplanet"></a>
Upstream `src/Core/Scripting/OOJSPlanet.m` ↔ `Core/Scripting/OOJSPlanet.cpp`

**Status:** done — 8 rows: 8 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sPlanetProperties[]` (68): 12 props; read-only: hasAtmosphere, isMainPlanet, radius; the rest READWRITE_CB; no method table | `sPlanetProperties` `Core/Scripting/OOJSPlanet.cpp:137` (+ `sPlanetPropertiesRaw` :158); `initClass` methods `nullptr` | ✅ |
| `DEFINE_JS_OBJECT_GETTER(JSPlanetGetPlanetEntity, …)` (85) | `JSPlanetGetPlanetEntity` `Core/Scripting/OOJSPlanet.cpp:182` (`OOJSEntityGetEntityOfClass` + `dynamic_cast`) | ✅ |
| `InitOOJSPlanet()` (87) | `InitOOJSPlanet` `Core/Scripting/OOJSPlanet.cpp:192` | ✅ |
| `-[OOPlanetEntity(OOJavaScriptExtensions) isVisibleToScripts]` (96) | `OOJSPlanetIsVisibleToScripts` `Core/Scripting/OOJSPlanet.cpp:203` | ✅ |
| `-[OOPlanetEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (102) | `OOJSPlanetGetJSClass` `Core/Scripting/OOJSPlanet.cpp:209` | ✅ |
| `-[OOPlanetEntity(OOJavaScriptExtensions) oo_jsClassName]` (108) | `OOJSPlanetJSClassName` `Core/Scripting/OOJSPlanet.cpp:215` ("Planet"/"Moon"/"Unknown") | ✅ |
| `PlanetGetProperty()` (122) | `PlanetGetProperty` `Core/Scripting/OOJSPlanet.cpp:228` | ✅ |
| `PlanetSetProperty()` (184) | `PlanetSetProperty` `Core/Scripting/OOJSPlanet.cpp:303` | ✅ |

**Differences:**

- ✅ subtle — Unlike the other entity classes, the Planet getter has no `entity == nil → undefined` branch. A stale planet therefore gives the values a message to nil gives: null colours, texture and name; 0 for the numbers; zero vector and quaternion; `false` for `hasAtmosphere`; and `isMainPlanet` = `nil == [UNIVERSE planet]`. The port reproduces each one with explicit null guards — upstream `:129-175` ↔ port `:239-291`
- ✅ subtle — The `orientation` getter: upstream `[planet normalOrientation]`, which `OOPlanetEntity.m` does not override; the port calls `Entity::normalOrientation()` qualified. The setter normalises the quaternion and then calls `OOPlanetEntity::setOrientation`, which upstream overrides at `OOPlanetEntity.m:482` — upstream `:167-168,262-268` ↔ port `:281-285,391-400`
- ✅ subtle — The `texture` setter warnings are identical: "Expected texture string. Value not set." and "Cannot find texture \"%s\". Value not set." (`%@`→`%s`). It is wrapped in pause/resume of the time limiter and always returns true. `-isKindOfClass:` became `planet != nullptr` (false only for nil in both) — upstream `:237-260` ↔ port `:365-389`
- ✅ subtle — The `name` setter accepts any value: `OOStringFromJSValue`, where nil/nullopt clears the name, and it never reports a bad value. The colour setters accept a description, or `null` to clear — upstream `:202-235` ↔ port `:325-363`

## OOJSPlayer

<a id="oojsplayer"></a>
Upstream `src/Core/Scripting/OOJSPlayer.m` ↔ `Core/Scripting/OOJSPlayer.cpp`

**Status:** done — 25 rows: 25 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sPlayerClass` JSClass "Player" (63) | `sPlayerClass` `Core/Scripting/OOJSPlayer.cpp:119` (finalize `OOJSObjectWrapperFinalize`) | ✅ |
| `sPlayerProperties[]` (104): 22 props; read-write: bounty, credits, escapePodRescueTime, name, score | `sPlayerProperties` `Core/Scripting/OOJSPlayer.cpp:165` (+ `sPlayerPropertiesRaw` `:199`): same names, order, tinyids (enum `:138`) and flags | ✅ |
| `sPlayerMethods[]` (131): 15 methods | `sPlayerMethods` `Core/Scripting/OOJSPlayer.cpp:228`: same names and min-args (1,1,1,1,0,0,0,1,0,0,0,1,1,1,0) | ✅ |
| `InitOOJSPlayer()` (151) | `InitOOJSPlayer` `Core/Scripting/OOJSPlayer.cpp:251` (global `player`, `OOJS_PROP_READONLY`; `OOJSBasicPrivateObjectConverter`; the private is never set in either) | ✅ |
| `JSPlayerClass()` (160) | `JSPlayerClass` `Core/Scripting/OOJSPlayer.cpp:264` | ✅ |
| `JSPlayerPrototype()` (165) | `JSPlayerPrototype` `Core/Scripting/OOJSPlayer.cpp:269` | ✅ |
| `JSPlayerObject()` (170) | `JSPlayerObject` `Core/Scripting/OOJSPlayer.cpp:274` | ✅ |
| `OOPlayerForScripting()` (175) | `OOPlayerForScripting` `Core/Scripting/OOJSPlayer.cpp:279` (`setScriptTargetToSelf` = `setScriptTarget(this)`, `Core/Entities/PlayerEntityLegacyScriptEngine.cpp:358`) | ✅ |
| `PlayerGetProperty()` (183) | `PlayerGetProperty` `Core/Scripting/OOJSPlayer.cpp:289` | ✅ |
| `PlayerSetProperty()` (288) | `PlayerSetProperty` `Core/Scripting/OOJSPlayer.cpp:404` | ✅ |
| `PlayerCommsMessage()` (354) | `PlayerCommsMessage` `Core/Scripting/OOJSPlayer.cpp:485` | ✅ |
| `PlayerConsoleMessage()` (379) | `PlayerConsoleMessage` `Core/Scripting/OOJSPlayer.cpp:515` | ✅ |
| `PlayerEndScenario()` (403) | `PlayerEndScenario` `Core/Scripting/OOJSPlayer.cpp:543` | ✅ |
| `PlayerIncreaseContractReputation()` (422) | `PlayerIncreaseContractReputation` `Core/Scripting/OOJSPlayer.cpp:565` | ✅ |
| `PlayerDecreaseContractReputation()` (433) | `PlayerDecreaseContractReputation` `Core/Scripting/OOJSPlayer.cpp:580` | ✅ |
| `PlayerIncreaseParcelReputation()` (444) | `PlayerIncreaseParcelReputation` `Core/Scripting/OOJSPlayer.cpp:595` | ✅ |
| `PlayerDecreaseParcelReputation()` (455) | `PlayerDecreaseParcelReputation` `Core/Scripting/OOJSPlayer.cpp:610` | ✅ |
| `PlayerIncreasePassengerReputation()` (466) | `PlayerIncreasePassengerReputation` `Core/Scripting/OOJSPlayer.cpp:625` | ✅ |
| `PlayerDecreasePassengerReputation()` (477) | `PlayerDecreasePassengerReputation` `Core/Scripting/OOJSPlayer.cpp:640` | ✅ |
| `PlayerAddMessageToArrivalReport()` (488) | `PlayerAddMessageToArrivalReport` `Core/Scripting/OOJSPlayer.cpp:655` | ✅ |
| `PlayerAudioMessage()` (508) | `PlayerAudioMessage` `Core/Scripting/OOJSPlayer.cpp:679` | ✅ |
| `PlayerReplaceShip()` (530) | `PlayerReplaceShip` `Core/Scripting/OOJSPlayer.cpp:706` | ✅ |
| `PlayerSetEscapePodDestination()` (571) | `PlayerSetEscapePodDestination` `Core/Scripting/OOJSPlayer.cpp:757` | ✅ |
| `PlayerSetPlayerRole()` (648) | `PlayerSetPlayerRole` `Core/Scripting/OOJSPlayer.cpp:848` | ✅ |
| `PlayerStopAudioMessage()` (675) | `PlayerStopAudioMessage` `Core/Scripting/OOJSPlayer.cpp:882` | ✅ |

**Differences:**

- ✅ subtle — The getter types match:
  - `score`, `alertCondition` and `bounty` are int32 (`INT_TO_JSVAL` → `int32Value`).
  - The three reputations are `(int)((float)x/10.0)`; the `*Precise` variants are `(float)x/10.0`.
  - `name`, `rank` and `legalStatus` are strings, or null when nil.
  - `dockingClearanceStatus` falls back to "DOCKING_CLEARANCE_STATUS_UNKNOWN".
  - `roleWeights` is an array of strings.

  upstream `Core/Scripting/OOJSPlayer.m:193-283` ↔ port `Core/Scripting/OOJSPlayer.cpp:301-397`
- ✅ subtle — The setters match:
  - `score` and `bounty` use ValueToInt32, clamp at 0, and use `kOOLegalStatusReasonByScript`.
  - `credits` and `escapePodRescueTime` use ValueToNumber.
  - A non-string `name` goes to `OOJSReportBadPropertyValue`.

  upstream `:300-345` ↔ port `:418-474`
- ✅ subtle — The bad-argument texts all match:
  - "message and optional duration"
  - "scenario key"
  - "string (arrival message)", with argc capped at `MIN(argc,1)`
  - "audiomessage (string)"
  - "string (shipyard key)"
  - "a valid station, null, or 'NEARBY_SYSTEM'"
  - "string (role) [, number (index)]"

  The errors "Player.replaceShip() only works while the player is docked." and "Player.setEscapePodDestination() only works while the escape pod is in flight." also match.
- ✅ subtle — Some calls are qualified and skip virtual dispatch: `PlayerEntity::score`, `setBounty`, `setTargetSystemID`, `addRoleToPlayer` and `ShipEntity::doScriptEvent` (bead oo-9ht.177). The vector overload of `ShipEntity::doScriptEvent` still dispatches virtually to `PlayerEntity::doScriptEvent(...context...)` (`Core/Entities/ShipEntity.cpp:13551`, `Core/Entities/PlayerEntity.h:861`). World scripts therefore still get `commsMessageReceived`, `playerReplacedShip` and `playerBoughtNewShip(player, 0)` — upstream `:372,560-562` ↔ port `:506,743-746`
- ✅ subtle — `setEscapePodDestination` behaves the same:
  - `undefined`/`null` (and a stale entity) count as nil and are accepted.
  - A station (`ToShip` && `getIsStation`) is accepted.
  - The string "NEARBY_SYSTEM" removes nova systems from the end down to index 1 and adds the time adjustment `(.2+d²)*3600+5400*(ranrot&127)`. It keeps upstream's quirk of calling `setTargetSystemID(i)` with the list index.
  - Any other value is accepted only if it is falsy.

  upstream `:584-642` ↔ port `:771-840`

## OOJSPlayerShip

<a id="oojsplayership"></a>
Upstream `src/Core/Scripting/OOJSPlayerShip.m` ↔ `Core/Scripting/OOJSPlayerShip.cpp`

**Status:** done — 40 rows: 38 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sPlayerShipClass` JSClass (84) | `sPlayerShipClass` ClassDef `Core/Scripting/OOJSPlayerShip.cpp:236` | ✅ |
| `enum kPlayerShip_*` + `sPlayerShipProperties[]` (99, 167): 64 props | `enum` + `sPlayerShipProperties[]` / `sPlayerShipPropertiesRaw[]` `Core/Scripting/OOJSPlayerShip.cpp:255,324,400` | ✅ |
| `sPlayerShipMethods[]` (237): 27 methods | `sPlayerShipMethods[]` `Core/Scripting/OOJSPlayerShip.cpp:472` | ✅ |
| `InitOOJSPlayerShip()` (269) | `InitOOJSPlayerShip` `Core/Scripting/OOJSPlayerShip.cpp:505` | ⚠️ |
| `JSPlayerShipClass()` (284) | `JSPlayerShipClass` `Core/Scripting/OOJSPlayerShip.cpp:523` | ✅ |
| `JSPlayerShipPrototype()` (289) | `JSPlayerShipPrototype` `Core/Scripting/OOJSPlayerShip.cpp:528` | ✅ |
| `JSPlayerShipObject()` (294) | `JSPlayerShipObject` `Core/Scripting/OOJSPlayerShip.cpp:533` | ✅ |
| `-[PlayerEntity(OOJavaScriptExtensions) oo_jsClassName]` (301) | `OOJSPlayerShipJSClassName` `Core/Scripting/OOJSPlayerShip.cpp:541` | ✅ |
| `-[PlayerEntity(OOJavaScriptExtensions) setJSSelf:context:]` (306) | `OOJSPlayerShipSetJSSelf` `Core/Scripting/OOJSPlayerShip.cpp:546` | ✅ |
| `-[PlayerEntity(OOJavaScriptExtensions) javaScriptEngineWillReset:]` (317) | `OOJSPlayerShipJavaScriptEngineWillReset` `Core/Scripting/OOJSPlayerShip.cpp:556` | ✅ |
| `PlayerShipGetProperty()` (334) | `PlayerShipGetProperty` `Core/Scripting/OOJSPlayerShip.cpp:571` | ✅ |
| `PlayerShipSetProperty()` (606) | `PlayerShipSetProperty` `Core/Scripting/OOJSPlayerShip.cpp:853` | ✅ |
| `PlayerShipLaunch()` (1003) | `PlayerShipLaunch` `Core/Scripting/OOJSPlayerShip.cpp:1295` | ✅ |
| `PlayerShipRemoveAllCargo()` (1017) | `PlayerShipRemoveAllCargo` `Core/Scripting/OOJSPlayerShip.cpp:1313` | ✅ |
| `PlayerShipUseSpecialCargo()` (1038) | `PlayerShipUseSpecialCargo` `Core/Scripting/OOJSPlayerShip.cpp:1338` | ✅ |
| `PlayerShipEngageAutopilotToStation()` (1062) | `PlayerShipEngageAutopilotToStation` `Core/Scripting/OOJSPlayerShip.cpp:1366` | ✅ |
| `PlayerShipDisengageAutopilot()` (1085) | `PlayerShipDisengageAutopilot` `Core/Scripting/OOJSPlayerShip.cpp:1392` | ✅ |
| `PlayerShipRequestDockingClearance()` (1098) | `PlayerShipRequestDockingClearance` `Core/Scripting/OOJSPlayerShip.cpp:1409` | ✅ |
| `PlayerShipCancelDockingRequest()` (1121) | `PlayerShipCancelDockingRequest` `Core/Scripting/OOJSPlayerShip.cpp:1436` | ✅ |
| `PlayerShipAwardEquipmentToCurrentPylon()` (1145) | `PlayerShipAwardEquipmentToCurrentPylon` `Core/Scripting/OOJSPlayerShip.cpp:1464` | ✅ |
| `PlayerShipAddPassenger()` (1171) | `PlayerShipAddPassenger` `Core/Scripting/OOJSPlayerShip.cpp:1493` | ✅ |
| `PlayerShipRemovePassenger()` (1206) | `PlayerShipRemovePassenger` `Core/Scripting/OOJSPlayerShip.cpp:1531` | ✅ |
| `PlayerShipAddParcel()` (1231) | `PlayerShipAddParcel` `Core/Scripting/OOJSPlayerShip.cpp:1559` | ✅ |
| `PlayerShipRemoveParcel()` (1264) | `PlayerShipRemoveParcel` `Core/Scripting/OOJSPlayerShip.cpp:1595` | ✅ |
| `PlayerShipAwardContract()` (1289) | `PlayerShipAwardContract` `Core/Scripting/OOJSPlayerShip.cpp:1623` | ✅ |
| `PlayerShipRemoveContract()` (1325) | `PlayerShipRemoveContract` `Core/Scripting/OOJSPlayerShip.cpp:1662` | ✅ |
| `PlayerShipSetCustomView()` (1357) | `PlayerShipSetCustomView` `Core/Scripting/OOJSPlayerShip.cpp:1697` | ✅ |
| `PlayerShipResetCustomView()` (1411) | `PlayerShipResetCustomView` `Core/Scripting/OOJSPlayerShip.cpp:1756` | ✅ |
| `PlayerShipResetScannerZoom()` (1431) | `PlayerShipResetScannerZoom` `Core/Scripting/OOJSPlayerShip.cpp:1781` | ✅ |
| `PlayerShipTakeInternalDamage()` (1444) | `PlayerShipTakeInternalDamage` `Core/Scripting/OOJSPlayerShip.cpp:1798` | ✅ |
| `PlayerShipBeginHyperspaceCountdown()` (1457) | `PlayerShipBeginHyperspaceCountdown` `Core/Scripting/OOJSPlayerShip.cpp:1814` | ✅ |
| `PlayerShipCancelHyperspaceCountdown()` (1491) | `PlayerShipCancelHyperspaceCountdown` `Core/Scripting/OOJSPlayerShip.cpp:1852` | ✅ |
| `PlayerShipBeginGalacticHyperspaceCountdown()` (1508) | `PlayerShipBeginGalacticHyperspaceCountdown` `Core/Scripting/OOJSPlayerShip.cpp:1874` | ✅ |
| `PlayerShipSetMultiFunctionDisplay()` (1542) | `PlayerShipSetMultiFunctionDisplay` `Core/Scripting/OOJSPlayerShip.cpp:1916` | ✅ |
| `PlayerShipSetMultiFunctionText()` (1570) | `PlayerShipSetMultiFunctionText` `Core/Scripting/OOJSPlayerShip.cpp:1947` | ✅ |
| `PlayerShipSetPrimedEquipment()` (1608) | `PlayerShipSetPrimedEquipment` `Core/Scripting/OOJSPlayerShip.cpp:1989` | ✅ |
| `PlayerShipSetCustomHUDDial()` (1634) | `PlayerShipSetCustomHUDDial` `Core/Scripting/OOJSPlayerShip.cpp:2018` | ❌ |
| `PlayerShipHideHUDSelector()` (1662) | `PlayerShipHideHUDSelector` `Core/Scripting/OOJSPlayerShip.cpp:2050` | ✅ |
| `PlayerShipShowHUDSelector()` (1683) | `PlayerShipShowHUDSelector` `Core/Scripting/OOJSPlayerShip.cpp:2075` | ✅ |
| `ValidateContracts()` (1704) | `ValidateContracts` `Core/Scripting/OOJSPlayerShip.cpp:2100` | ✅ |

**Differences:**

- ❌ **low** — `setCustomHUDDial(key, null|undefined)`: upstream converts the value to `nil`, and `-setDialCustom:forKey:` then does `[customDialSettings setObject:nil …]`, which raises NSInvalidArgumentException; the native wrapper turns that into a JS exception. The port stores a null PList entry without error, so the dial is silently set to null where upstream threw — upstream `Core/Scripting/OOJSPlayerShip.m:1650`, `Core/Entities/PlayerEntity.m:4129` ↔ port `Core/Scripting/OOJSPlayerShip.cpp:2035`, `Core/Entities/PlayerEntity.cpp:4450`
- ⚠️ **low** — In Init, the `player.ship` private slot holds `oo::makeRef<OOJSEntityHolder>(player)` instead of `[player weakRetain]`, and the converter is `OOJSEntityObjectConverter` instead of `OOJSBasicPrivateObjectConverter` (bead oo-9ht.39.3, cited in the code comment). Scripts see the same object, the same `ship` property (`OOJS_PROP_READONLY`) and the same prototype chain — upstream `Core/Scripting/OOJSPlayerShip.m:271-279` ↔ port `Core/Scripting/OOJSPlayerShip.cpp:509-520`
- ✅ note (low, nil-messaging) — In the getter and setter, `messageGuiTextColor` and `messageGuiTextCommsColor` call `UNIVERSE->messageGUI()->…` with no null guard; upstream messaging nil gave null or a no-op. Every other player/HUD access is null-guarded through `AskHud`/`HudOf`. Reachable only if `UNIVERSE` or the message GUI is missing — upstream `Core/Scripting/OOJSPlayerShip.m:589,955` ↔ port `Core/Scripting/OOJSPlayerShip.cpp:834,1245`
- ✅ note (low, nil-messaging) — `setMultiFunctionText(key, text, true)` with a null `UNIVERSE->getGui()` dereferences null in the port. Upstream `[nil reflowTextForMFD:]` gave nil, which cleared the MFD text. Unreachable in practice — upstream `Core/Scripting/OOJSPlayerShip.m:1597-1599` ↔ port `Core/Scripting/OOJSPlayerShip.cpp:1976-1978`
- ✅ note — These upstream quirks are kept verbatim:
  - The getter's `default:` reports a bad selector, then still returns null with `true`.
  - In the setter, `serviceLevel` falls through into `currentWeapon` when number conversion fails, and `targetSystem` falls through into `infoSystem` when int conversion fails.
  - `showHUDSelector` reports bad arguments under the name "hideHUDSelector".
  - The `setMultiFunctionText` reflow error uses class "setMultiFunctionText", method "reflow".
  - The `engageAutopilotToStation` error names "engageAutopilot".
  - The typos "orientiation", "hightlight" and `"string (key), value]"` are kept.
- ✅ note — All error and warning texts match exactly:
  - the `removeAllCargo` docked check;
  - `setCustomView`/`resetCustomView` "…only works when custom view is active.";
  - `targetSystem` "read-only unless called when docked.";
  - the compass type and compass target errors, and the advanced-compass warning;
  - the crosshair warning (`%@`→`%s`).
- ✅ note — `setCustomView` with a non-string third argument: the port raises `OOInvalidArgumentException` "Tried to add nil value for key 'weapon_facing' to dictionary", matching the exception upstream's `-setObject:forKey:` raised.
- ✅ note — `crosshairs = null` with a HUD that has no name: the port skips `switchHudTo`. Upstream called `switchHudTo:nil`, which returns NO at once (`Core/Entities/PlayerEntity.m:4061`), so the behaviour is the same.

## OOJSPopulatorDefinition

<a id="oojspopulatordefinition"></a>
Upstream `src/Core/Scripting/OOJSPopulatorDefinition.m` ↔ `Core/Scripting/OOJSPopulatorDefinition.cpp`

**Status:** done — 8 rows: 8 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJSPopulatorDefinition init]` (33) | constructor OOJSPopulatorDefinition.cpp:61 | ✅ |
| `-[OOJSPopulatorDefinition deleteJSPointers]` (49) | `deleteJSPointers` OOJSPopulatorDefinition.cpp:73 | ✅ |
| `-[OOJSPopulatorDefinition dealloc]` (65) | destructor OOJSPopulatorDefinition.cpp:88 | ✅ |
| `-[OOJSPopulatorDefinition callback]` (74) | `callback` OOJSPopulatorDefinition.cpp:95 | ✅ |
| `-[OOJSPopulatorDefinition setCallback:]` (79) | `setCallback` OOJSPopulatorDefinition.cpp:100 | ✅ |
| `-[OOJSPopulatorDefinition callbackThis]` (88) | `callbackThis` OOJSPopulatorDefinition.cpp:109 | ✅ |
| `-[OOJSPopulatorDefinition setCallbackThis:]` (93) | `setCallbackThis` OOJSPopulatorDefinition.cpp:114 | ✅ |
| `-[OOJSPopulatorDefinition runCallback:]` (102) | `runPopulatorCallback` OOJSPopulatorDefinition.cpp:123 (renamed; same body: `HPVectorToVector` → `VectorToJSValue`, push/pop owner) | ✅ |

**Differences:**

- ✅ note — The port adds `OOJSPopulatorDefinitionToPList`/`…In` (:157, :164) so that a definition can travel inside a `PList` where upstream put the object itself in an `NSDictionary`. These add no behaviour of their own.

## OOJSQuaternion

<a id="oojsquaternion"></a>
Upstream `src/Core/Scripting/OOJSQuaternion.m` ↔ `Core/Scripting/OOJSQuaternion.cpp`

**Status:** done — 32 rows: 32 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sQuaternionClass` / `sQuaternionProperties` / `sQuaternionMethods` / `sQuaternionStaticMethods` tables (66–181) | same names `Core/Scripting/OOJSQuaternion.cpp:99-164` (w/x/y/z `Permanent \| Enumerate \| Shared` = `OOJS_PROP_READWRITE_CB`; same method names, min-args, order) | ✅ |
| `InitOOJSQuaternion()` (185) | `InitOOJSQuaternion` `Core/Scripting/OOJSQuaternion.cpp:168` (ctor nargs 4) | ✅ |
| `JSQuaternionWithQuaternion()` (190) | `JSQuaternionWithQuaternion` `Core/Scripting/OOJSQuaternion.cpp:176` | ✅ |
| `QuaternionToJSValue()` (218) | `QuaternionToJSValue` `Core/Scripting/OOJSQuaternion.cpp:203` | ✅ |
| `JSValueToQuaternion()` (236) | `JSValueToQuaternion` `Core/Scripting/OOJSQuaternion.cpp:221` | ✅ |
| `-[PlayerEntity(JSQuaternionStatistics) reportJSQuaternionStatistics]` (262) | `reportJSQuaternionStatistics` `Core/Scripting/OOJSQuaternion.cpp:246` (free function, bead oo-9ht.15) | ✅ |
| `-[PlayerEntity(JSQuaternionStatistics) clearJSQuaternionStatistics]` (286) | `clearJSQuaternionStatistics` `Core/Scripting/OOJSQuaternion.cpp:270` | ✅ |
| `JSObjectGetQuaternion()` (306) | `JSObjectGetQuaternion` `Core/Scripting/OOJSQuaternion.cpp:288` | ✅ |
| `GetThisQuaternion()` (384) | `GetThisQuaternion` `Core/Scripting/OOJSQuaternion.cpp:368` | ✅ |
| `JSQuaternionSetQuaternion()` (394) | `JSQuaternionSetQuaternion` `Core/Scripting/OOJSQuaternion.cpp:379` | ✅ |
| `QuaternionFromArgumentListNoErrorInternal()` (420) | `QuaternionFromArgumentListNoErrorInternal` `Core/Scripting/OOJSQuaternion.cpp:408` | ✅ |
| `QuaternionFromArgumentList()` (470) | `QuaternionFromArgumentList` `Core/Scripting/OOJSQuaternion.cpp:460` | ✅ |
| `QuaternionFromArgumentListNoError()` (482) | `QuaternionFromArgumentListNoError` `Core/Scripting/OOJSQuaternion.cpp:472` | ✅ |
| `QuaternionGetProperty()` (489) | `QuaternionGetProperty` `Core/Scripting/OOJSQuaternion.cpp:480` | ✅ |
| `QuaternionSetProperty()` (529) | `QuaternionSetProperty` `Core/Scripting/OOJSQuaternion.cpp:525` | ✅ |
| `QuaternionFinalize()` (573) | `QuaternionFinalize` `Core/Scripting/OOJSQuaternion.cpp:574` | ✅ |
| `QuaternionConstruct()` (584) | `QuaternionConstruct` `Core/Scripting/OOJSQuaternion.cpp:590` | ✅ |
| `QuaternionToString()` (626) | `QuaternionToString` `Core/Scripting/OOJSQuaternion.cpp:636` | ✅ |
| `QuaternionToSource()` (641) | `QuaternionToSource` `Core/Scripting/OOJSQuaternion.cpp:654` | ✅ |
| `QuaternionMultiply()` (657) | `QuaternionMultiply` `Core/Scripting/OOJSQuaternion.cpp:672` | ✅ |
| `QuaternionDot()` (676) | `QuaternionDot` `Core/Scripting/OOJSQuaternion.cpp:694` | ✅ |
| `QuaternionRotate()` (696) | `QuaternionRotate` `Core/Scripting/OOJSQuaternion.cpp:717` | ✅ |
| `QuaternionRotateX()` (725) | `QuaternionRotateX` `Core/Scripting/OOJSQuaternion.cpp:750` | ✅ |
| `QuaternionRotateY()` (745) | `QuaternionRotateY` `Core/Scripting/OOJSQuaternion.cpp:773` | ✅ |
| `QuaternionRotateZ()` (765) | `QuaternionRotateZ` `Core/Scripting/OOJSQuaternion.cpp:796` | ✅ |
| `QuaternionNormalize()` (785) | `QuaternionNormalize` `Core/Scripting/OOJSQuaternion.cpp:819` | ✅ |
| `QuaternionConjugate()` (802) | `QuaternionConjugate` `Core/Scripting/OOJSQuaternion.cpp:839` | ✅ |
| `QuaternionVectorForward()` (819) | `QuaternionVectorForward` `Core/Scripting/OOJSQuaternion.cpp:859` | ✅ |
| `QuaternionVectorUp()` (837) | `QuaternionVectorUp` `Core/Scripting/OOJSQuaternion.cpp:880` | ✅ |
| `QuaternionVectorRight()` (855) | `QuaternionVectorRight` `Core/Scripting/OOJSQuaternion.cpp:901` | ✅ |
| `QuaternionToArray()` (873) | `QuaternionToArray` `Core/Scripting/OOJSQuaternion.cpp:922` | ✅ |
| `QuaternionStaticRandom()` (918) | `QuaternionStaticRandom` `Core/Scripting/OOJSQuaternion.cpp:971` | ✅ |

**Differences:**

- No behaviour differences found. Constructor forms match: no args → identity; a Quaternion; an entity (its orientation; a dead/absent entity → all-zero quaternion, as the message to nil, `OOJSEntityOrientationOfJSObject` `Core/Scripting/OOJSEntity.cpp:238-243`); a 4-element array `[w,x,y,z]` (each element through `valueToNumber`, no NaN check); `Quaternion.prototype` → zero quaternion; or four numbers, each rejected if NaN. Error texts identical, including the constructor's "Quaternion, Entity or array of four numbers" vs the argument list's "Quaternion, Entity or four numbers".
- `toString()` uses the shared `QuaternionDescription` `(%g %c %gi %c %gj %c %gk)` with signs from `>= 0.0f` and `fabsf` magnitudes, byte-identical to upstream (`Core/OOQuaternion.m:361-375` ↔ `Core/OOQuaternion.cpp:365-379`); `toSource()` is `Quaternion(%g, %g, %g, %g)`. Property getters return the component through a `GLfloat` as upstream.
- Maths: `multiply`, `dot`, `rotate` (axis via `VectorFromArgumentList`; angle optional, value passed through unchanged when absent), `rotateX/Y/Z`, `normalize`, `conjugate`, `vectorForward/Up/Right`, `random` call the same `OOQuaternion` functions; `OOQuaternion.cpp`/`.h` differ from upstream only in the description's string type (checked by diff).
- Subtle, kept from upstream: `reportJSQuaternionStatistics` has no `sum == 0` guard (unlike the Vector one), so percentages print `nan` on an empty count; `toArray()` ignores `setElement` failures exactly as upstream — upstream `Core/Scripting/OOJSQuaternion.m:266-267, 890-905` ↔ port `Core/Scripting/OOJSQuaternion.cpp:250-251, 941-956`
- The constructor now frees its buffer when `newObject` fails (upstream leaked); not observable — port `Core/Scripting/OOJSQuaternion.cpp:604-606`

## OOJSScript

<a id="oojsscript"></a>
Upstream `src/Core/Scripting/OOJSScript.m` ↔ `Core/Scripting/OOJSScript.cpp`

**Status:** done — 35 rows: 29 ✅ 4 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOJSScript scriptWithPath:properties:]` (104) | `OOJSScript::scriptWithPath` `Core/Scripting/OOJSScript.cpp:200` (a failed init drops the Ref, as `DESTROY(self)` did) | ✅ |
| `-[OOJSScript initWithPath:properties:]` (109) | `OOJSScript::initWithPath` `Core/Scripting/OOJSScript.cpp:208` | ⚠️ |
| `-[OOJSScript dealloc]` (256) | `OOJSScript::~OOJSScript` `Core/Scripting/OOJSScript.cpp:347` | ✅ |
| `-[OOJSScript oo_jsClassName]` (281) | `OOJSScript::jsClassName` `Core/Scripting/OOJSScript.cpp:362` | ✅ |
| `-[OOJSScript descriptionComponents]` (286) | `OOJSScript::descriptionComponents` `Core/Scripting/OOJSScript.cpp:367` | ✅ |
| `-[OOJSScript javaScriptEngineWillReset:]` (294) | `OOJSScript::javaScriptEngineWillReset` `Core/Scripting/OOJSScript.cpp:375` (nulls `_jsSelf` before unrooting, as upstream; roots are keyed by address) | ✅ |
| `+[OOJSScript currentlyRunningScript]` (305) | `OOJSScript::currentlyRunningScript` `Core/Scripting/OOJSScript.cpp:386` | ✅ |
| `+[OOJSScript scriptStack]` (312) | `OOJSScript::scriptStack` `Core/Scripting/OOJSScript.cpp:393` | ✅ |
| `-[OOJSScript weakRetain]` (321) | — `oo::WeakRef<OOJSScript>` in `RunningStack` / `ScriptPrivate` (bead oo-9ht.133), `Core/Scripting/OOJSScript.cpp:103-155` | ➖ |
| `-[OOJSScript weakRefDied:]` (328) | — same (`oo::WeakRef` clears itself) | ➖ |
| `-[OOJSScript name]` (334) | `OOJSScript::name` `Core/Scripting/OOJSScript.cpp:401` | ✅ |
| `-[OOJSScript scriptDescription]` (343) | `OOJSScript::scriptDescription` `Core/Scripting/OOJSScript.cpp:411` | ✅ |
| `-[OOJSScript version]` (348) | `OOJSScript::version` `Core/Scripting/OOJSScript.cpp:416` | ✅ |
| `-[OOJSScript runWithTarget:]` (353) | `OOJSScript::runWithTarget` `Core/Scripting/OOJSScript.cpp:421` | ✅ |
| `-[OOJSScript callMethod:]` (357) | `OOJSScript::callMethod` `Core/Scripting/OOJSScript.cpp:425` → `callFunctionValue` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3152` | ✅ |
| `-[OOJSScript propertyWithID:inContext:]` (417) | `OOJSScript::propertyWithID` `Core/Scripting/OOJSScript.cpp:484` | ✅ |
| `-[OOJSScript setProperty:withID:inContext:]` (430) | `OOJSScript::setProperty(PList, PropertyId, Context)` `Core/Scripting/OOJSScript.cpp:497` → `setByAtom` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:2905` | ⚠️ |
| `-[OOJSScript defineProperty:withID:inContext:]` (440) | `OOJSScript::defineProperty(PList, PropertyId, Context)` `Core/Scripting/OOJSScript.cpp:507` (`kScriptDefinePropertyFlags` ≡ `OOJS_PROP_READONLY`) | ✅ |
| `-[OOJSScript propertyNamed:]` (450) | `OOJSScript::propertyNamed` `Core/Scripting/OOJSScript.cpp:517` | ✅ |
| `-[OOJSScript setProperty:named:]` (464) | `OOJSScript::setProperty(PList, string)` `Core/Scripting/OOJSScript.cpp:529` | ✅ |
| `-[OOJSScript defineProperty:named:]` (478) | `OOJSScript::defineProperty(PList, string)` `Core/Scripting/OOJSScript.cpp:543` | ✅ |
| `-[OOJSScript oo_jsValueInContext:]` (492) | `OOJSScript::jsValueInContext` `Core/Scripting/OOJSScript.cpp:557` | ✅ |
| `+[OOJSScript pushScript:]` (499) | `OOJSScript::pushScript(OOJSScript*)` / `pushScript(const WeakRef&)` `Core/Scripting/OOJSScript.cpp:574,586` | ✅ |
| `+[OOJSScript popScript:]` (512) | `OOJSScript::popScript` `Core/Scripting/OOJSScript.cpp:597` | ✅ |
| `-[OOJSScript(OOPrivate) scriptNameFromPath:]` (541) | `OOJSScript::scriptNameFromPath` `Core/Scripting/OOJSScript.cpp:623` | ✅ |
| `-[OOJSScript(OOPrivate) defaultPropertiesFromPath:]` (573) | `OOJSScript::defaultPropertiesFromPath` `Core/Scripting/OOJSScript.cpp:658` | ⚠️ |
| `-[OOScript(JavaScriptEvents) callMethod:]` (603) | `OOScript::callMethod` `Core/Scripting/OOScript.cpp:297` (always false) | ✅ |
| `InitOOJSScript()` (614) | `InitOOJSScript` `Core/Scripting/OOJSScript.cpp:686` (converter `ScriptConverter` :696: the slot's weak script, null once gone, as `OOJSBasicPrivateObjectConverter` gave nil) | ✅ |
| `ScriptAddProperty()` (620) | `ScriptAddProperty` `Core/Scripting/OOJSScript.cpp:724` | ✅ |
| `AddStackToArrayReversed()` (635) | `AddStackToArrayReversed` `Core/Scripting/OOJSScript.cpp:745` | ✅ |
| `LoadScriptWithName()` (643) | `LoadScriptWithName` `Core/Scripting/OOJSScript.cpp:759` → `compileUCScript`/`executeScript` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3198,3231` | ⚠️ |
| `CompiledScriptData()` (707) | `CompiledScriptData` `Core/Scripting/OOJSScript.cpp:827` → `serializeScript` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3259` | ✅ |
| `ScriptWithCompiledData()` (728) | `ScriptWithCompiledData` `Core/Scripting/OOJSScript.cpp:840` → `deserializeScript` | ✅ |
| `StrippedName()` (754) | `StrippedName` `Core/Scripting/OOJSScript.cpp:851` | ✅ |
| `sScriptMethods` `toString` → `OOJSObjectWrapperToString` (85-93) *(added)* | `ScriptToString` `Core/Scripting/OOJSScript.cpp:704` ("[Script <components>]", else "[object Script]" for the prototype / a dead script; another class's `this` → `OOJSObjectWrapperToString`) | ✅ |

**Differences:**

- ⚠️ **med** — Name resolution for script code is reversed and assignment escapes. SpiderMonkey runs the script with `_jsSelf` at the head of the scope chain, so a bare identifier resolves against the script object (and its `Script.prototype`/`Object.prototype` chain) before the global, in top-level code and in every closure. QuickJS-ng global code has only the global scope, so the backend puts a "scope fallback" exotic object on the global's prototype, consulted only when the global lacks the name. This has three consequences:
  - A global of the same name now shadows the script's property.
  - Assigning to a bare name that exists only on the script object creates a global, and that global is shared by every script.
  - Console-evaluated code gets no fallback.
  - Documented as DIVERGENCE (beads oo-1gc.4, oo-1gc.15).
  - — upstream `Core/Scripting/OOJSScript.m:205` (SpiderMonkey `jsinterp.cpp:971`) ↔ port `Core/Scripting/OOJSScript.cpp:296`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:2201-2219,2329-2338,3231-3236`
- Note — The backend banner claims SpiderMonkey put top-level `var`/function declarations on the scope object. That is not true for Oolite: upstream sets `JSOPTION_VAROBJFIX` (`OOJavaScriptEngine.m:86`), so `initialVarObj = chain->getGlobal()` (SpiderMonkey `jsinterp.cpp:971`) and declarations landed on the global in both engines. That part is equivalent; only the lookup order and assignment above diverge. — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:87-90`
- ⚠️ **low** — Manifest default properties (`version`, `author`, `license`, the local-manifest identifier) and caller `properties` are now defined in `std::map` key order, not NSDictionary hash order. The only effect is the JS enumeration order (`for…in`, `Object.keys`) of a script object's own properties. Stated in the port comments. — upstream `Core/Scripting/OOJSScript.m:168-191` ↔ port `Core/Scripting/OOJSScript.cpp:262-282`
- ⚠️ **low** — `defaultPropertiesFromPath`: a `manifest.plist` that is not a dictionary no longer logs `OODictionaryFromFile`'s `plist.wrongType` line (stated in the comment). A nil path now short-circuits to "no manifest". The `setObject:nil` raise for a non-string/number manifest value is kept (`ValueForKey`). — upstream `Core/Scripting/OOJSScript.m:576-577` ↔ port `Core/Scripting/OOJSScript.cpp:661-663,883-888`
- ⚠️ **low** — `setProperty:withID:` now reports failure differently. The façade's `setByAtom` calls the QuickJS-ng set, which throws a TypeError on a read-only property, where SpiderMonkey's non-strict `JS_SetPropertyById` silently succeeded (backend DIVERGENCE). A `setProperty` onto a property that `properties` or the manifest identifier defined read-only (e.g. the initial `name` set at :291 if a caller passes `name`) now returns false and leaves a TypeError pending. That error is then reported by the next `reportPendingException` (load failure or `callMethod`). — upstream `Core/Scripting/OOJSScript.m:437` ↔ port `Core/Scripting/OOJSScript.cpp:504`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:2905-2910`
- ⚠️ **low** — Compile and execute are split differently. `compileUCScript` compiles bytecode only to report syntax errors. Because `executeScript` with `obj != global` re-evaluates the kept *source* with `this = _jsSelf`, every script is parsed twice, and the compiled-script cache effectively caches source. The cache blob is the backend's own format (magic `OOQJSX1`), so caches written by a SpiderMonkey build are rejected and recompiled. Filename (`path` UTF-8), first line 1, `this` = script object and the debug-only `"use strict"` prepend (and its +1 line shift) are unchanged. — upstream `Core/Scripting/OOJSScript.m:687-698` ↔ port `Core/Scripting/OOJSScript.cpp:807-818`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3198-3245,2371`
- Subtle — Strict mode: QuickJS-ng honours `"use strict"` natively, with ES5 strict semantics as in SpiderMonkey 1.8.5. `JSOPTION_STRICT` (extra warnings) was never set. ✅ — port `Core/Scripting/OOJSScript.cpp:793-800`
- Subtle — Load-failure reporting order is unchanged.
  - Compile error: reported (and cleared) inside `compileUCScript` when no script is running (the façade's LAST_FRAME_CHECKS), then `script.javaScript.load.failed` is logged.
  - Nested load (a ship script spawned from inside a JS call): the exception stays pending, `load.failed` is logged, then `reportPendingException` reports it.
  - Both match SpiderMonkey. Log class and text differences are under OOJavaScriptEngine `ReportJSError`.
  - — port `Core/Scripting/OOJSScript.cpp:294-334`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:886-901`
- Subtle — `callMethod`:
  - It keeps the push/pop of the running-script stack around the call, the time limiter, the `isExceptionPending` → report → `OK = false` path, and the debug `script.javaScript.call` "Calling [%@].%@()" log with indent.
  - A non-function handler (e.g. `this.startUp = 5`) still fails, but QuickJS-ng's text is "not a function", not SpiderMonkey's decompiled "5 is not a function".
  - — port `Core/Scripting/OOJSScript.cpp:443-481`
- Subtle — `name`/`version`/`description` go through `DescriptionOrNil` (`oo::DescriptionOf`, pinned to GNUstep's `-description`): a string is itself, a number uses `%0.16g`, a bool prints 1/0, and a dictionary uses `{k = v; }`, matching `[[obj description] copy]`. ✅ — port `Core/Scripting/OOJSScript.cpp:863-871`, `oofnd/PListDescription.hpp:7-20`

## OOJSShip

<a id="oojsship"></a>
Upstream `src/Core/Scripting/OOJSShip.m` ↔ `Core/Scripting/OOJSShip.cpp`

**Status:** done — 100 rows: 95 ✅ 2 ⚠️ 3 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sShipClass` JSClass (153) | `sShipClass` ooscript::ClassDef `Core/Scripting/OOJSShip.cpp:204` | ✅ |
| `enum kShip_*` property IDs from -128 (177) | `enum kShip_*` `Core/Scripting/OOJSShip.cpp:231` | ✅ |
| `sShipProperties[]` JSPropertySpec (325) | `sShipProperties[]` `Core/Scripting/OOJSShip.cpp:379` | ⚠️ |
| `sShipMethods[]` JSFunctionSpec (476) | `sShipMethods[]` `Core/Scripting/OOJSShip.cpp:530` | ✅ |
| `sShipStaticMethods[]` (562) | `sShipStaticMethods[]` `Core/Scripting/OOJSShip.cpp:616` | ✅ |
| `JSShipGetShipEntity` (DEFINE_JS_OBJECT_GETTER, 573) | `JSShipGetShipEntity()` `Core/Scripting/OOJSShip.cpp:634` | ✅ |
| `GET_THIS_SHIP` macro (1823) | `GET_THIS_SHIP` `Core/Scripting/OOJSShip.cpp:2034` | ✅ |
| `InitOOJSShip()` (575) | `InitOOJSShip()` `Core/Scripting/OOJSShip.cpp:645` | ✅ |
| `JSShipClass()` (582) | `JSShipClass()` `Core/Scripting/OOJSShip.cpp:652` | ✅ |
| `JSShipPrototype()` (587) | `JSShipPrototype()` `Core/Scripting/OOJSShip.cpp:657` | ✅ |
| `ShipGetProperty()` (592) | `ShipGetProperty()` `Core/Scripting/OOJSShip.cpp:733` | ✅ |
| `ShipSetProperty()` (1177) | `ShipSetProperty()` `Core/Scripting/OOJSShip.cpp:1337` | ⚠️ |
| `ShipSetScript()` (1832) | `ShipSetScript()` `Core/Scripting/OOJSShip.cpp:2043` | ✅ |
| `ShipSetAI()` (1858) | `ShipSetAI()` `Core/Scripting/OOJSShip.cpp:2070` | ✅ |
| `ShipSwitchAI()` (1884) | `ShipSwitchAI()` `Core/Scripting/OOJSShip.cpp:2097` | ✅ |
| `ShipExitAI()` (1910) | `ShipExitAI()` `Core/Scripting/OOJSShip.cpp:2124` | ✅ |
| `ShipReactToAIMessage()` (1941) | `ShipReactToAIMessage()` `Core/Scripting/OOJSShip.cpp:2157` | ✅ |
| `ShipSendAIMessage()` (1967) | `ShipSendAIMessage()` `Core/Scripting/OOJSShip.cpp:2184` | ✅ |
| `ShipDeployEscorts()` (1993) | `ShipDeployEscorts()` `Core/Scripting/OOJSShip.cpp:2211` | ✅ |
| `ShipDockEscorts()` (2008) | `ShipDockEscorts()` `Core/Scripting/OOJSShip.cpp:2227` | ✅ |
| `ShipHasEquipmentProviding()` (2023) | `ShipHasEquipmentProviding()` `Core/Scripting/OOJSShip.cpp:2243` | ✅ |
| `ShipHasRole()` (2045) | `ShipHasRole()` `Core/Scripting/OOJSShip.cpp:2266` | ✅ |
| `ShipEjectItem()` (2067) | `ShipEjectItem()` `Core/Scripting/OOJSShip.cpp:2289` | ✅ |
| `ShipAddCargoEntity()` (2089) | `ShipAddCargoEntity()` `Core/Scripting/OOJSShip.cpp:2312` | ✅ |
| `ShipEjectSpecificItem()` (2135) | `ShipEjectSpecificItem()` `Core/Scripting/OOJSShip.cpp:2360` | ✅ |
| `ShipDumpCargo()` (2157) | `ShipDumpCargo()` `Core/Scripting/OOJSShip.cpp:2383` | ✅ |
| `ShipSpawn()` (2197) | `ShipSpawn()` `Core/Scripting/OOJSShip.cpp:2425` | ✅ |
| `ShipDealEnergyDamage()` (2228) | `ShipDealEnergyDamage()` `Core/Scripting/OOJSShip.cpp:2457` | ✅ |
| `ShipExplode()` (2272) | `ShipExplode()` `Core/Scripting/OOJSShip.cpp:2502` | ✅ |
| `ShipRemove()` (2282) | `ShipRemove()` `Core/Scripting/OOJSShip.cpp:2512` | ✅ |
| `ShipRunLegacyScriptActions()` (2312) | `ShipRunLegacyScriptActions()` `Core/Scripting/OOJSShip.cpp:2543` | ✅ |
| `ShipCommsMessage()` (2346) | `ShipCommsMessage()` `Core/Scripting/OOJSShip.cpp:2577` | ✅ |
| `ShipFireECM()` (2375) | `ShipFireECM()` `Core/Scripting/OOJSShip.cpp:2607` | ✅ |
| `ShipAbandonShip()` (2395) | `ShipAbandonShip()` `Core/Scripting/OOJSShip.cpp:2630` | ✅ |
| `ShipCanAwardEquipment()` (2408) | `ShipCanAwardEquipment()` `Core/Scripting/OOJSShip.cpp:2644` | ✅ |
| `ShipAwardEquipment()` (2454) | `ShipAwardEquipment()` `Core/Scripting/OOJSShip.cpp:2691` | ✅ |
| `ShipRemoveEquipment()` (2523) | `ShipRemoveEquipment()` `Core/Scripting/OOJSShip.cpp:2762` | ✅ |
| `ShipRestoreSubEntities()` (2574) | `ShipRestoreSubEntities()` `Core/Scripting/OOJSShip.cpp:2814` | ✅ |
| `ShipSetEquipmentStatus()` (2603) | `ShipSetEquipmentStatus()` `Core/Scripting/OOJSShip.cpp:2845` | ✅ |
| `ShipEquipmentStatus()` (2683) | `ShipEquipmentStatus()` `Core/Scripting/OOJSShip.cpp:2927` | ✅ |
| `ShipSelectNewMissile()` (2742) | `ShipSelectNewMissile()` `Core/Scripting/OOJSShip.cpp:2987` | ✅ |
| `ShipFireMissile()` (2761) | `ShipFireMissile()` `Core/Scripting/OOJSShip.cpp:3006` | ✅ |
| `ShipFindNearestStation()` (2781) | `ShipFindNearestStation()` `Core/Scripting/OOJSShip.cpp:3027` | ✅ |
| `ShipSetBounty()` (2808) | `ShipSetBounty()` `Core/Scripting/OOJSShip.cpp:3056` | ✅ |
| `ShipSetCargo()` (2836) | `ShipSetCargo()` `Core/Scripting/OOJSShip.cpp:3085` | ✅ |
| `ShipSetCrew()` (2866) | `ShipSetCrew()` `Core/Scripting/OOJSShip.cpp:3117` | ❌ |
| `ShipSetCargoType()` (2902) | `ShipSetCargoType()` `Core/Scripting/OOJSShip.cpp:3155` | ✅ |
| `ShipSetMaterials()` (2941) | `ShipSetMaterials()` `Core/Scripting/OOJSShip.cpp:3195` | ✅ |
| `ShipSetShaders()` (2960) | `ShipSetShaders()` `Core/Scripting/OOJSShip.cpp:3214` | ✅ |
| `ShipSetMaterialsInternal()` (2985) | `ShipSetMaterialsInternal()` `Core/Scripting/OOJSShip.cpp:3240` | ✅ |
| `ShipExitSystem()` (3049) | `ShipExitSystem()` `Core/Scripting/OOJSShip.cpp:3309` | ✅ |
| `ShipUpdateEscortFormation()` (3077) | `ShipUpdateEscortFormation()` `Core/Scripting/OOJSShip.cpp:3338` | ✅ |
| `RemoveOrExplodeShip()` (3090) | `RemoveOrExplodeShip()` `Core/Scripting/OOJSShip.cpp:3353` | ✅ |
| `ShipClearDefenseTargets()` (3133) | `ShipClearDefenseTargets()` `Core/Scripting/OOJSShip.cpp:3400` | ✅ |
| `ShipAddDefenseTarget()` (3146) | `ShipAddDefenseTarget()` `Core/Scripting/OOJSShip.cpp:3414` | ✅ |
| `ShipRemoveDefenseTarget()` (3166) | `ShipRemoveDefenseTarget()` `Core/Scripting/OOJSShip.cpp:3435` | ✅ |
| `ShipAddCollisionException()` (3186) | `ShipAddCollisionException()` `Core/Scripting/OOJSShip.cpp:3456` | ✅ |
| `ShipRemoveCollisionException()` (3210) | `ShipRemoveCollisionException()` `Core/Scripting/OOJSShip.cpp:3482` | ✅ |
| `ShipGetMaterials()` (3233) | `ShipGetMaterials()` `Core/Scripting/OOJSShip.cpp:3507` | ✅ |
| `ShipGetShaders()` (3251) | `ShipGetShaders()` `Core/Scripting/OOJSShip.cpp:3525` | ✅ |
| `ShipBroadcastCascadeImminent()` (3268) | `ShipBroadcastCascadeImminent()` `Core/Scripting/OOJSShip.cpp:3542` | ✅ |
| `ShipBecomeCascadeExplosion()` (3281) | `ShipBecomeCascadeExplosion()` `Core/Scripting/OOJSShip.cpp:3556` | ✅ |
| `ShipOfferToEscort()` (3294) | `ShipOfferToEscort()` `Core/Scripting/OOJSShip.cpp:3570` | ✅ |
| `ShipRequestHelpFromGroup()` (3314) | `ShipRequestHelpFromGroup()` `Core/Scripting/OOJSShip.cpp:3591` | ✅ |
| `ShipPatrolReportIn()` (3329) | `ShipPatrolReportIn()` `Core/Scripting/OOJSShip.cpp:3607` | ✅ |
| `ShipMarkTargetForFines()` (3351) | `ShipMarkTargetForFines()` `Core/Scripting/OOJSShip.cpp:3630` | ✅ |
| `ShipEnterWormhole()` (3370) | `ShipEnterWormhole()` `Core/Scripting/OOJSShip.cpp:3649` | ✅ |
| `ShipNotifyGroupOfWormhole()` (3399) | `ShipNotifyGroupOfWormhole()` `Core/Scripting/OOJSShip.cpp:3680` | ✅ |
| `ShipThrowSpark()` (3413) | `ShipThrowSpark()` `Core/Scripting/OOJSShip.cpp:3695` | ✅ |
| `ShipPerformAttack()` (3426) | `ShipPerformAttack()` `Core/Scripting/OOJSShip.cpp:3709` | ✅ |
| `ShipPerformCollect()` (3439) | `ShipPerformCollect()` `Core/Scripting/OOJSShip.cpp:3723` | ✅ |
| `ShipPerformEscort()` (3452) | `ShipPerformEscort()` `Core/Scripting/OOJSShip.cpp:3737` | ✅ |
| `ShipPerformFaceDestination()` (3465) | `ShipPerformFaceDestination()` `Core/Scripting/OOJSShip.cpp:3751` | ✅ |
| `ShipPerformFlee()` (3478) | `ShipPerformFlee()` `Core/Scripting/OOJSShip.cpp:3765` | ✅ |
| `ShipPerformFlyToRangeFromDestination()` (3491) | `ShipPerformFlyToRangeFromDestination()` `Core/Scripting/OOJSShip.cpp:3779` | ✅ |
| `ShipPerformHold()` (3504) | `ShipPerformHold()` `Core/Scripting/OOJSShip.cpp:3793` | ✅ |
| `ShipPerformIdle()` (3517) | `ShipPerformIdle()` `Core/Scripting/OOJSShip.cpp:3807` | ✅ |
| `ShipPerformIntercept()` (3530) | `ShipPerformIntercept()` `Core/Scripting/OOJSShip.cpp:3821` | ✅ |
| `ShipPerformLandOnPlanet()` (3543) | `ShipPerformLandOnPlanet()` `Core/Scripting/OOJSShip.cpp:3835` | ✅ |
| `ShipPerformMining()` (3556) | `ShipPerformMining()` `Core/Scripting/OOJSShip.cpp:3849` | ✅ |
| `ShipPerformScriptedAI()` (3569) | `ShipPerformScriptedAI()` `Core/Scripting/OOJSShip.cpp:3863` | ✅ |
| `ShipPerformScriptedAttackAI()` (3582) | `ShipPerformScriptedAttackAI()` `Core/Scripting/OOJSShip.cpp:3877` | ✅ |
| `ShipPerformStop()` (3595) | `ShipPerformStop()` `Core/Scripting/OOJSShip.cpp:3891` | ✅ |
| `ShipPerformTumble()` (3608) | `ShipPerformTumble()` `Core/Scripting/OOJSShip.cpp:3905` | ✅ |
| `ShipRequestDockingInstructions()` (3621) | `ShipRequestDockingInstructions()` `Core/Scripting/OOJSShip.cpp:3919` | ✅ |
| `ShipRecallDockingInstructions()` (3639) | `ShipRecallDockingInstructions()` `Core/Scripting/OOJSShip.cpp:3933` | ✅ |
| `ShipBroadcastDistressMessage()` (3657) | `ShipBroadcastDistressMessage()` `Core/Scripting/OOJSShip.cpp:3947` | ✅ |
| `ShipCheckCourseToDestination()` (3670) | `ShipCheckCourseToDestination()` `Core/Scripting/OOJSShip.cpp:3961` | ✅ |
| `ShipGetSafeCourseToDestination()` (3684) | `ShipGetSafeCourseToDestination()` `Core/Scripting/OOJSShip.cpp:3976` | ✅ |
| `ShipCheckScanner()` (3698) | `ShipCheckScanner()` `Core/Scripting/OOJSShip.cpp:3991` | ✅ |
| `ShipAdjustCargo()` (3728) | `ShipAdjustCargo()` `Core/Scripting/OOJSShip.cpp:4023` | ✅ |
| `ShipDamageAssessment()` (3770) | `ShipDamageAssessment()` `Core/Scripting/OOJSShip.cpp:4065` | ✅ |
| `ShipThreatAssessment()` (3797) | `ShipThreatAssessment()` `Core/Scripting/OOJSShip.cpp:4093` | ✅ |
| `ShipThreatAssessmentWeapon()` (3918) | `ShipThreatAssessmentWeapon()` `Core/Scripting/OOJSShip.cpp:4215` | ✅ |
| `ShipStaticKeys()` (3928) | `ShipStaticKeys()` `Core/Scripting/OOJSShip.cpp:4225` | ❌ |
| `ShipStaticKeysForRole()` (3939) | `ShipStaticKeysForRole()` `Core/Scripting/OOJSShip.cpp:4235` | ✅ |
| `ShipStaticRoleIsInCategory()` (3956) | `ShipStaticRoleIsInCategory()` `Core/Scripting/OOJSShip.cpp:4254` | ✅ |
| `ShipStaticRoles()` (3973) | `ShipStaticRoles()` `Core/Scripting/OOJSShip.cpp:4271` | ❌ |
| `ShipStaticShipDataForKey()` (3984) | `ShipStaticShipDataForKey()` `Core/Scripting/OOJSShip.cpp:4281` | ✅ |
| `ShipStaticSetShipDataForKey()` (4000) | `ShipStaticSetShipDataForKey()` `Core/Scripting/OOJSShip.cpp:4298` | ✅ |

**Differences:**

- ⚠️ **med** — The `speed` property is now `OOJS_PROP_READWRITE_CB` (upstream `OOJS_PROP_READONLY_CB`), and `ShipSetProperty` gains a `kShip_speed` case that calls `setSpeed()`. Upstream ignored writes silently (a TypeError in strict mode). In the port an NPC write takes effect. `player.ship.speed = x` throws "player.ship.speed is read-only.", and a negative or NaN value throws "ship.speed must be a number >= 0.". A long code comment justifies the change, but no ADR or bead id is cited. It is the only change in the property table: name, tinyid and flags match for every other entry — upstream `Core/Scripting/OOJSShip.m:450` ↔ port `Core/Scripting/OOJSShip.cpp:504`, `:1693-1734`
- ❌ **low** — `setCrew()`: when `OOCharacter characterWithDictionary` answers nil, upstream `[NSArray arrayWithObject:nil]` raises, and the JS caller gets an exception. The port skips the nil character and sets an empty crew, so the ship becomes unpiloted and the call returns `true` — upstream `Core/Scripting/OOJSShip.m:2889-2890` ↔ port `Core/Scripting/OOJSShip.cpp:3139-3143`
- ❌ **low** — `Ship.keys()` and `Ship.roles()` return array order from `std::map` (sorted ascending, `OOShipRegistry::shipKeys()/shipRoles()`). Upstream used NSDictionary `-allKeys` hash order. The contents are the same but scripts can see the new order. (The order change comes from OOShipRegistry, not this file.) — upstream `Core/Scripting/OOJSShip.m:3933,3978` ↔ port `Core/Scripting/OOJSShip.cpp:4230,4276`
- ✅ note (dict key order) — Getter `roleWeights` and `equipmentStatus(…, true)` build `oo::PList::Dict` (`std::map`). JS object keys therefore enumerate sorted (`EQUIPMENT_DAMAGED` before `EQUIPMENT_OK`), not in NSDictionary order. The values are the same — port `Core/Scripting/OOJSShip.cpp:781-785`, `:2971-2973`
- ✅ note (ShipGetProperty) — I checked all 144 cases. Every case returns the same type, and null vs undefined matches upstream. A stale entity gives `undefined`. A nil object result gives `null` (`StringOrNull`, `EntityObjectNode`, a null PList). `scriptInfo` is `{}`, never null (`ShipEntity::getScriptInfo()`). `crew` is null when the ship is unpiloted. `commodity` is null when the amount is 0. The AI getters give null/false with no AI — port `Core/Scripting/OOJSShip.cpp:733-1335`
- ✅ note (ShipSetProperty) — Validation and error text match case by case. This covers the entityPersonality range, scriptedMisjumpRange and sunGlareFilter messages, max* "cannot be negative", the injectorSpeedFactor bounds, maxEscorts, and "player.ship.%s is read-only.". Two upstream quirks are kept: `kShip_entityPersonality` falls through to `hyperspaceSpinTime` when int conversion fails, and the sunGlareFilter message says "> 0.0 and < 1.0" while the check is inclusive — port `Core/Scripting/OOJSShip.cpp:1489-1498`, `:1819-1829`
- ✅ note (copy-paste quirks kept) — `patrolReportIn()` reports bad arguments as `addDefenseTarget`. `keysForRole` reports as `shipKeysForRole`. `setShipDataForKey` reports as `setShipInfoForKey`. The property table still lists `homeSystem` twice. `setBounty()` returns true without setting rval — port `Core/Scripting/OOJSShip.cpp:3616`, `:4247`, `:4307`, `:435/439`, `:3079`
- ✅ note (nil args) — Where upstream sent nil to a Foundation API, the port passes `""`: `setShipDataForKey` with a non-string key, `adjustCargo` with a nil commodity. `setShipDataForKey` with a non-object second argument uses `toObject` where upstream used raw `JSVAL_TO_OBJECT`. `checkScanner` skips null entries, where upstream `addObject:nil` would raise. Only degenerate inputs reach any of these — port `Core/Scripting/OOJSShip.cpp:4304`, `:4053-4056`, `:4015`
- ✅ note — `InitOOJSShip` registers `OOJSEntityObjectConverter` in place of `OOJSBasicPrivateObjectConverter`, and the class finalizer is `OOJSCxxObjectWrapperFinalize`. Both are documented as the entity-holder replacement (bead oo-9ht.39.3), and the converted value is still the entity's object or null when stale — port `Core/Scripting/OOJSShip.cpp:216`, `:648`

## OOJSShipGroup

<a id="oojsshipgroup"></a>
Upstream `src/Core/Scripting/OOJSShipGroup.m` ↔ `Core/Scripting/OOJSShipGroup.cpp`

**Status:** done — 13 rows: 13 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| *(added)* `sShipGroupClass` (41) | `sShipGroupClass` OOJSShipGroup.cpp:109 | ✅ |
| *(added)* `sShipGroupProperties[]` (64): `count` RO, `leader` RW, `name` RW, `ships` RO (all _CB) | `sShipGroupProperties` OOJSShipGroup.cpp:137 (+ identical raw mirror :152 for error reporters) | ✅ |
| *(added)* `sShipGroupMethods[]` (73): `toString`/0, `addShip`/1, `containsShip`/1, `removeShip`/1 | `sShipGroupMethods` OOJSShipGroup.cpp:163 | ✅ |
| `InitOOJSShipGroup()` (84) | `InitOOJSShipGroup` OOJSShipGroup.cpp:190 (converter :179 gives the group as an Object node) | ✅ |
| `ShipGroupGetProperty()` (90) | `ShipGroupGetProperty` OOJSShipGroup.cpp:200 | ✅ |
| `ShipGroupSetProperty()` (134) | `ShipGroupSetProperty` OOJSShipGroup.cpp:248 | ✅ |
| `ShipGroupConstruct()` (173) | `ShipGroupConstruct` OOJSShipGroup.cpp:297 | ✅ |
| `-[OOShipGroup(OOJavaScriptExtensions) oo_jsValueInContext:]` (208) | `OOShipGroup::jsValueInContext` OOJSShipGroup.cpp:337 | ✅ |
| `-[OOShipGroup(OOJavaScriptExtensions) oo_clearJSSelf:]` (226) | `OOShipGroup::clearJSSelf` OOJSShipGroup.cpp:355 | ✅ |
| *(added)* inherited `oo_jsDescription` (class name `OOShipGroup`, no `oo_jsClassName`) | `OOShipGroup::jsDescription` OOJSShipGroup.cpp:363 + `ShipGroupToString` :375 | ✅ |
| `ShipGroupAddShip()` (237) | `ShipGroupAddShip` OOJSShipGroup.cpp:383 | ✅ |
| `ShipGroupRemoveShip()` (298) | `ShipGroupRemoveShip` OOJSShipGroup.cpp:454 | ✅ |
| `ShipGroupContainsShip()` (324) | `ShipGroupContainsShip` OOJSShipGroup.cpp:484 | ✅ |

**Differences:**

- ✅ note — The escort-group branch of `addShip` is the same. "Already escorting" logs a warning and returns `false`. When an unescorted leader whose escort group is its own group gets a new escort, the port makes a new `"ship group"` group and leaks it at +1, as upstream's `alloc/init` did. The text of the escort-group warning matches, but `%@` of the ship becomes `oo::EntityDescription(ship)` (audited with entities) — upstream `:258-291` ↔ port `:409-446`

## OOJSSound

<a id="oojssound"></a>
Upstream `src/Core/Scripting/OOJSSound.m` ↔ `Core/Scripting/OOJSSound.cpp`

**Status:** done — 15 rows: 14 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| *(added)* `sSoundClass` (43; setProperty `JS_StrictPropertyStub`) | `sSoundClass` OOJSSound.cpp:118 (setProperty default stub) | ✅ |
| *(added)* `sSoundProperties[]` (63): `name` RO_CB | OOJSSound.cpp:143 | ✅ |
| *(added)* `sSoundMethods[]` (69): `toString`/0 | OOJSSound.cpp:151 (`SoundToString` :304) | ✅ |
| *(added)* `sSoundStaticMethods[]` (79): `load`/1, `musicSoundSource`/0, `playMusic`/1, `stopMusic`/0 | OOJSSound.cpp:164 | ✅ |
| `InitOOJSSound()` (108) | `InitOOJSSound` OOJSSound.cpp:219; converter `SoundConverter` :211 returns null | ⚠️ |
| `SoundFromJSValue()` (114) | `SoundFromJSValue` OOJSSound.cpp:228 (keeps the upstream pause-without-resume of the time limiter) | ✅ |
| `SoundGetProperty()` (131) | `SoundGetProperty` OOJSSound.cpp:254 | ✅ |
| `GetNamedSound()` (156) | `GetNamedSound` OOJSSound.cpp:286 | ✅ |
| `SoundStaticLoad()` (172) | `SoundStaticLoad` OOJSSound.cpp:314 | ✅ |
| `SoundStaticMusicSoundSource()` (195) | `SoundStaticMusicSoundSource` OOJSSound.cpp:339 | ✅ |
| `SoundStaticPlayMusic()` (207) | `SoundStaticPlayMusic` OOJSSound.cpp:354 | ✅ |
| `SoundStaticStopMusic()` (245) | `SoundStaticStopMusic` OOJSSound.cpp:394 | ✅ |
| `-[OOSound(OOJavaScriptExtentions) oo_jsValueInContext:]` (273) | `OOJSSoundJSValueInContext` OOJSSound.cpp:424 (new wrapper per call, as upstream) | ✅ |
| `-[OOSound(OOJavaScriptExtentions) oo_jsDescription]` (289) | `OOJSSoundJSDescription` OOJSSound.cpp:444 (`[Sound "name"]`, `(null)` for nil name) | ✅ |
| `-[OOSound(OOJavaScriptExtentions) oo_jsClassName]` (294) | `OOJSSoundJSClassName` OOJSSound.cpp:449 | ✅ |

**Differences:**

- ⚠️ **low** — The object converter registered for `Sound` returns null instead of the native `OOSound` that `OOJSBasicPrivateObjectConverter` returned. A generic JS→native or plist conversion of a `Sound` object therefore gives null. The sound's own callers use `SoundFromJSValue()`, which reads the slot directly (bead oo-9ht.68, comment at :207-209) — upstream `OOJSSound.m:111` ↔ port `OOJSSound.cpp:211-214,225`
- ✅ note — The texts and arities of the `playMusic` argument errors match, including upstream's second report with count 1 after `OOJSArgumentListGetNumber` fails. The `stopMusic` text `"string or no argument"` matches too.

## OOJSSoundSource

<a id="oojssoundsource"></a>
Upstream `src/Core/Scripting/OOJSSoundSource.m` ↔ `Core/Scripting/OOJSSoundSource.cpp`

**Status:** done — 13 rows: 12 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| *(added)* `sSoundSourceClass` (42) | `sSoundSourceClass` OOJSSoundSource.cpp:105 | ✅ |
| *(added)* `sSoundSourceProperties[]` (68): `isPlaying` RO, `loop`/`position`/`positional`/`repeatCount`/`sound`/`volume` RW (all _CB) | OOJSSoundSource.cpp:136 | ✅ |
| *(added)* `sSoundSourceMethods[]` (80): `toString`/0, `play`/0, `playOrRepeat`/0, `stop`/0 | OOJSSoundSource.cpp:150 | ✅ |
| `InitOOJSSoundSource()` (110) | `InitOOJSSoundSource` OOJSSoundSource.cpp:202; converter `SoundSourceConverter` :194 returns null | ⚠️ |
| `SoundSourceConstruct()` (116) | `SoundSourceConstruct` OOJSSoundSource.cpp:210 | ✅ |
| `SoundSourceGetProperty()` (132) | `SoundSourceGetProperty` OOJSSoundSource.cpp:230 | ✅ |
| `SoundSourceSetProperty()` (179) | `SoundSourceSetProperty` OOJSSoundSource.cpp:283 (keeps the dead `if (100 < 1)` and the 0..1 volume clamp) | ✅ |
| `SoundSourcePlay()` (255) | `SoundSourcePlay` OOJSSoundSource.cpp:378 | ✅ |
| `SoundSourceStop()` (285) | `SoundSourceStop` OOJSSoundSource.cpp:412 | ✅ |
| `SoundSourcePlayOrRepeat()` (304) | `SoundSourcePlayOrRepeat` OOJSSoundSource.cpp:435 | ✅ |
| `-[OOSoundSource(OOJavaScriptExtentions) oo_jsValueInContext:]` (324) | `OOJSSoundSourceJSValueInContext` OOJSSoundSource.cpp:460 | ✅ |
| `-[OOSoundSource(OOJavaScriptExtentions) oo_jsClassName]` (340) | `OOJSSoundSourceJSClassName` OOJSSoundSource.cpp:480 | ✅ |
| *(added)* inherited `oo_jsDescription` → `[SoundSource <components>]` | `OOJSSoundSourceHolder::jsDescription` OOJSSoundSource.cpp:171 + `SoundSourceToString` :370 | ✅ |

**Differences:**

- ⚠️ **low** — The `SoundSource` object converter returns null instead of the native `OOSoundSource` (bead oo-9ht.88, comment at :191-193). A generic JS→native conversion of a `SoundSource` gives null — upstream `OOJSSoundSource.m:113` ↔ port `OOJSSoundSource.cpp:194-197,206`

## OOJSSpecialFunctions

<a id="oojsspecialfunctions"></a>
Upstream `src/Core/Scripting/OOJSSpecialFunctions.m` ↔ `Core/Scripting/OOJSSpecialFunctions.cpp`

**Status:** done — 5 rows: 5 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| *(added)* `sSpecialFunctionsMethods[]` (33): `jsWarning`/1, `markConsoleEntryPoint`/0 (if `OO_DEBUG_MONITOR_ENABLED`) | OOJSSpecialFunctions.cpp:37 (macro comes from `meson.build` command line, so unaffected by `OO_PLAIN_CPP_UNIT`) | ✅ |
| `InitOOJSSpecialFunctions()` (43) | `InitOOJSSpecialFunctions` OOJSSpecialFunctions.cpp:46 (empty) | ✅ |
| `JSSpecialFunctionsObjectWrapper()` (47) | `JSSpecialFunctionsObjectWrapper` OOJSSpecialFunctions.cpp:50 | ✅ |
| `SpecialJSWarning()` (70) | `SpecialJSWarning` OOJSSpecialFunctions.cpp:73 | ✅ |
| `SpecialMarkConsoleEntryPoint()` (90) | `SpecialMarkConsoleEntryPoint` OOJSSpecialFunctions.cpp:93 | ✅ |

**Differences:**

- *none*

## OOJSStation

<a id="oojsstation"></a>
Upstream `src/Core/Scripting/OOJSStation.m` ↔ `Core/Scripting/OOJSStation.cpp`

**Status:** done — 31 rows: 29 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sStationClass` JSClass (66) | `sStationClass` ClassDef `Core/Scripting/OOJSStation.cpp:210` | ✅ |
| `sStationProperties` JSPropertySpec table (103) | `sStationProperties` `Core/Scripting/OOJSStation.cpp:252` (+ `sStationPropertiesRaw` :281 for the error reporters) | ✅ |
| `sStationMethods` JSFunctionSpec table (126) | `sStationMethods` `Core/Scripting/OOJSStation.cpp:306` | ✅ |
| `InitOOJSStation()` (151) | `InitOOJSStation` `Core/Scripting/OOJSStation.cpp:332` | ✅ |
| `JSStationGetStationEntity()` (158) | `JSStationGetStationEntity` `Core/Scripting/OOJSStation.cpp:341` | ✅ |
| `JSStationGetShipEntity()` (182) | `JSStationGetShipEntity` `Core/Scripting/OOJSStation.cpp:370` | ✅ |
| `-[StationEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (208) | `OOJSStationGetJSClass` `Core/Scripting/OOJSStation.cpp:397` | ✅ |
| `-[StationEntity(OOJavaScriptExtensions) oo_jsClassName]` (214) | `OOJSStationJSClassName` `Core/Scripting/OOJSStation.cpp:403` | ✅ |
| `StationGetProperty()` (221) | `StationGetProperty` `Core/Scripting/OOJSStation.cpp:409` | ✅ |
| `StationSetProperty()` (330) | `StationSetProperty` `Core/Scripting/OOJSStation.cpp:525` | ✅ |
| `StationAbortAllDockings()` (434) | `StationAbortAllDockings` `Core/Scripting/OOJSStation.cpp:644` | ✅ |
| `StationAbortDockingForShip()` (447) | `StationAbortDockingForShip` `Core/Scripting/OOJSStation.cpp:660` | ✅ |
| `StationCanDockShip()` (472) | `StationCanDockShip` `Core/Scripting/OOJSStation.cpp:688` | ✅ |
| `StationDockPlayer()` (503) | `StationDockPlayer` `Core/Scripting/OOJSStation.cpp:723` | ✅ |
| `StationIncreaseAlertLevel()` (531) | `StationIncreaseAlertLevel` `Core/Scripting/OOJSStation.cpp:759` | ✅ |
| `StationDecreaseAlertLevel()` (548) | `StationDecreaseAlertLevel` `Core/Scripting/OOJSStation.cpp:780` | ✅ |
| `StationLaunchShipWithRole()` (566) | `StationLaunchShipWithRole` `Core/Scripting/OOJSStation.cpp:802` | ✅ |
| `StationLaunchDefenseShip()` (598) | `StationLaunchDefenseShip` `Core/Scripting/OOJSStation.cpp:838` | ✅ |
| `StationLaunchEscort()` (615) | `StationLaunchEscort` `Core/Scripting/OOJSStation.cpp:857` | ✅ |
| `StationLaunchScavenger()` (632) | `StationLaunchScavenger` `Core/Scripting/OOJSStation.cpp:876` | ✅ |
| `StationLaunchMiner()` (649) | `StationLaunchMiner` `Core/Scripting/OOJSStation.cpp:895` | ✅ |
| `StationLaunchPirateShip()` (665) | `StationLaunchPirateShip` `Core/Scripting/OOJSStation.cpp:913` | ✅ |
| `StationLaunchShuttle()` (682) | `StationLaunchShuttle` `Core/Scripting/OOJSStation.cpp:932` | ✅ |
| `StationLaunchPatrol()` (698) | `StationLaunchPatrol` `Core/Scripting/OOJSStation.cpp:950` | ✅ |
| `StationLaunchPolice()` (714) | `StationLaunchPolice` `Core/Scripting/OOJSStation.cpp:968` | ✅ |
| `StationSetInterface()` (730) | `StationSetInterface` `Core/Scripting/OOJSStation.cpp:988` | ❌ |
| `StationSetMarketPrice()` (827) | `StationSetMarketPrice` `Core/Scripting/OOJSStation.cpp:1089` | ✅ |
| `StationSetMarketQuantity()` (864) | `StationSetMarketQuantity` `Core/Scripting/OOJSStation.cpp:1132` | ✅ |
| `StationAddShipToShipyard()` (901) | `StationAddShipToShipyard` `Core/Scripting/OOJSStation.cpp:1188` (+ port helpers `StringForKey`/`StringAtIndex`/`RaiseNilValueForKey`/`ValueForKey` :169-199, `WeaponThreatAssessment` :1179) | ❌ |
| `StationRemoveShipFromShipyard()` (1048) | `StationRemoveShipFromShipyard` `Core/Scripting/OOJSStation.cpp:1354` | ✅ |

**Differences:**

- ❌ **low** — `setInterface(key, def)` with a null/undefined `key`: upstream's `OOStringFromJSValue` gives nil, so `setObject:definition forKey:nil` raises and the script gets "Native exception: …". On the removal path, `removeObjectForKey:nil` is warned about and ignored by GNUstep. The port uses `key.value_or("")`, so it silently stores the definition under `""` (or erases `""`) and returns undefined with no error — upstream `Core/Scripting/OOJSStation.m:742,745,818` ↔ port `Core/Scripting/OOJSStation.cpp:1000,1004,1080`
- ❌ **low** — `addShipToShipyard()` given a JS array, or any object that does not convert to a dictionary: upstream sends `-objectForKey:` to that object and raises an NSException, so the script sees "Native exception: <unrecognized-selector reason>". The port reports the fixed text "Unidentified native exception" instead. Its comment claims to reproduce the raise, but `OOJSReportWrappedException` gives that text only for non-NSException objects — upstream `Core/Scripting/OOJSStation.m:935` + `OOJavaScriptEngine.m:976-979` ↔ port `Core/Scripting/OOJSStation.cpp:1226-1228`
- ✅ subtle — `addShipToShipyard()`: the port drops the "Invalid shipdata_key provided." warning, rightly, since it can never fire: `+dictionaryWithDictionary:nil` gives an empty dictionary, never nil. An unknown key therefore falls through the `roles` test (a nil receiver gives `location` 0) to "No shipyard information found for shipdata_key.", and the port matches that path — upstream `Core/Scripting/OOJSStation.m:947-961` ↔ port `Core/Scripting/OOJSStation.cpp:1242-1258`
- ✅ subtle — `addShipToShipyard()` without `personality`: upstream `setObject:0 forKey:` raises on the nil value, and the port raises the same way through `RaiseNilValueForKey`, with GNUstep's text. The side-effect order matches: `Ranrot()` has already been consumed in both — upstream `Core/Scripting/OOJSStation.m:969,989` ↔ port `Core/Scripting/OOJSStation.cpp:1266,1286`
- ✅ subtle — `addShipToShipyard()` with no shipyard reports its warning under the method name `removeShipFromShipyard`. This upstream copy-paste slip is kept as is — upstream `Core/Scripting/OOJSStation.m:917` ↔ port `Core/Scripting/OOJSStation.cpp:1204`
- ✅ subtle — The `market` getter: upstream converts an `NSDictionary` (`localMarketForScripting`), so `for…in` order follows the hash order. The port converts an `oo::PList` dict, whose iteration order may differ. This belongs to the shared converter, not to this file — upstream `Core/Scripting/OOJSStation.m:317` ↔ port `Core/Scripting/OOJSStation.cpp:511`
- ✅ subtle — The `roll` getter and `increase/decreaseAlertLevel` call `ShipEntity::getFlightRoll()` and `ShipEntity::alertCondition()` qualified, which skips virtual dispatch. Upstream `StationEntity.m` overrides neither, so the result is the same — upstream `Core/Scripting/OOJSStation.m:266,540,557` ↔ port `Core/Scripting/OOJSStation.cpp:458,768,789`
- ✅ subtle — The property table matches upstream: 18 entries, same names, same tinyid order, same READWRITE_CB/READONLY_CB flags. The method table matches too: 20 entries with the same names and min-args — upstream `Core/Scripting/OOJSStation.m:103-149` ↔ port `Core/Scripting/OOJSStation.cpp:252-329`

## OOJSSun

<a id="oojssun"></a>
Upstream `src/Core/Scripting/OOJSSun.m` ↔ `Core/Scripting/OOJSSun.cpp`

**Status:** done — 10 rows: 10 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sSunClass` (38; setProperty `JS_StrictPropertyStub`) + `sSunProperties[]` (61): hasGoneNova, isGoingNova, name, radius, all READONLY_CB | `sSunClass` `Core/Scripting/OOJSSun.cpp:75` (setProperty `nullptr`) + `sSunProperties` :103 | ✅ |
| `sSunMethods[]` (70): `cancelNova` 0, `goNova` 1 | `sSunMethods` `Core/Scripting/OOJSSun.cpp:114` | ✅ |
| `DEFINE_JS_OBJECT_GETTER(JSSunGetSunEntity, …)` (77) | `JSSunGetSunEntity` `Core/Scripting/OOJSSun.cpp:128` (`OOJSEntityGetEntityOfClass` + `dynamic_cast`) | ✅ |
| `InitOOJSSun()` (79) | `InitOOJSSun` `Core/Scripting/OOJSSun.cpp:138` | ✅ |
| `-[OOSunEntity(OOJavaScriptExtensions) isVisibleToScripts]` (88) | `OOJSSunIsVisibleToScripts` `Core/Scripting/OOJSSun.cpp:149` | ✅ |
| `-[OOSunEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (93) | `OOJSSunGetJSClass` `Core/Scripting/OOJSSun.cpp:154` | ✅ |
| `-[OOSunEntity(OOJavaScriptExtensions) oo_jsClassName]` (99) | `OOJSSunJSClassName` `Core/Scripting/OOJSSun.cpp:160` ("Sun") | ✅ |
| `SunGetProperty()` (106) | `SunGetProperty` `Core/Scripting/OOJSSun.cpp:166` | ✅ |
| `SunGoNova()` (145) | `SunGoNova` `Core/Scripting/OOJSSun.cpp:212` | ✅ |
| `SunCancelNova()` (164) | `SunCancelNova` `Core/Scripting/OOJSSun.cpp:235` | ✅ |

**Differences:**

- ✅ subtle — Like Planet, the getter has no stale→`undefined` branch. A stale sun gives radius 0, a null name and `false` for both nova flags. `isGoingNova` = `willGoNova && !goneNova` — upstream `:118-137` ↔ port `:181-202`
- ✅ subtle — `goNova([delay])`: when `argc > 0` and number conversion fails, it returns false with no extra report. Otherwise it calls `setGoingNova(true, delay)` with a default delay of 0 and returns undefined. `cancelNova()` only acts when `willGoNova && !goneNova`. A stale sun is a no-op in both — upstream `:145-179` ↔ port `:212-252`

## OOJSSystem

<a id="oojssystem"></a>
Upstream `src/Core/Scripting/OOJSSystem.m` ↔ `Core/Scripting/OOJSSystem.cpp`

**Status:** done — 42 rows: 40 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sSystemClass` JSClass (93) | `sSystemClass` ClassDef `Core/Scripting/OOJSSystem.cpp:208` | ✅ |
| property-ID enum `kSystem_*` (107) | enum `kSystem_*` `Core/Scripting/OOJSSystem.cpp:227` | ✅ |
| `sSystemProperties[]` JSPropertySpec (141) | `sSystemProperties[]` `Core/Scripting/OOJSSystem.cpp:267` (+ error-reporter mirror `sSystemPropertiesRaw[]` `:308`) | ✅ |
| `sSystemMethods[]` JSFunctionSpec (175) | `sSystemMethods[]` `Core/Scripting/OOJSSystem.cpp:344` | ✅ |
| `sSystemStaticMethods[]` (207) | `sSystemStaticMethods[]` `Core/Scripting/OOJSSystem.cpp:378` | ✅ |
| `InitOOJSSystem()` (214) | `InitOOJSSystem` `Core/Scripting/OOJSSystem.cpp:386` | ✅ |
| `SystemGetProperty()` (222) | `SystemGetProperty` `Core/Scripting/OOJSSystem.cpp:396` | ❌ |
| `SystemSetProperty()` (439) | `SystemSetProperty` `Core/Scripting/OOJSSystem.cpp:628` | ✅ |
| `SystemToString()` (571) | `SystemToString` `Core/Scripting/OOJSSystem.cpp:782` | ✅ |
| `SystemAddPlanet()` (585) | `SystemAddPlanet` `Core/Scripting/OOJSSystem.cpp:801` | ✅ |
| `SystemAddMoon()` (610) | `SystemAddMoon` `Core/Scripting/OOJSSystem.cpp:829` | ✅ |
| `SystemSendAllShipsAway()` (635) | `SystemSendAllShipsAway` `Core/Scripting/OOJSSystem.cpp:857` | ✅ |
| `SystemCountShipsWithPrimaryRole()` (648) | `SystemCountShipsWithPrimaryRole` `Core/Scripting/OOJSSystem.cpp:874` | ✅ |
| `SystemCountShipsWithRole()` (680) | `SystemCountShipsWithRole` `Core/Scripting/OOJSSystem.cpp:909` | ✅ |
| `SystemShipsWithPrimaryRole()` (712) | `SystemShipsWithPrimaryRole` `Core/Scripting/OOJSSystem.cpp:944` | ✅ |
| `SystemShipsWithRole()` (745) | `SystemShipsWithRole` `Core/Scripting/OOJSSystem.cpp:980` | ✅ |
| `SystemCountEntitiesWithScanClass()` (778) | `SystemCountEntitiesWithScanClass` `Core/Scripting/OOJSSystem.cpp:1016` | ✅ |
| `SystemEntitiesWithScanClass()` (810) | `SystemEntitiesWithScanClass` `Core/Scripting/OOJSSystem.cpp:1051` | ✅ |
| `SystemFilteredEntities()` (843) | `SystemFilteredEntities` `Core/Scripting/OOJSSystem.cpp:1087` | ✅ |
| `SystemLocationFromCode()` (881) | `SystemLocationFromCode` `Core/Scripting/OOJSSystem.cpp:1128` | ✅ |
| `SystemAddShips()` (908) | `SystemAddShips` `Core/Scripting/OOJSSystem.cpp:1158` | ✅ |
| `SystemAddGroup()` (914) | `SystemAddGroup` `Core/Scripting/OOJSSystem.cpp:1166` | ✅ |
| `SystemAddShipsToRoute()` (920) | `SystemAddShipsToRoute` `Core/Scripting/OOJSSystem.cpp:1174` | ✅ |
| `SystemAddGroupToRoute()` (926) | `SystemAddGroupToRoute` `Core/Scripting/OOJSSystem.cpp:1182` | ✅ |
| `SystemLegacyAddShips()` (932) | `SystemLegacyAddShips` `Core/Scripting/OOJSSystem.cpp:1190` | ✅ |
| `SystemLegacyAddSystemShips()` (958) | `SystemLegacyAddSystemShips` `Core/Scripting/OOJSSystem.cpp:1221` | ✅ |
| `SystemLegacyAddShipsAt()` (985) | `SystemLegacyAddShipsAt` `Core/Scripting/OOJSSystem.cpp:1253` | ✅ |
| `SystemLegacyAddShipsAtPrecisely()` (1016) | `SystemLegacyAddShipsAtPrecisely` `Core/Scripting/OOJSSystem.cpp:1288` | ✅ |
| `SystemLegacyAddShipsWithinRadius()` (1047) | `SystemLegacyAddShipsWithinRadius` `Core/Scripting/OOJSSystem.cpp:1323` | ✅ |
| `SystemLegacySpawnShip()` (1081) | `SystemLegacySpawnShip` `Core/Scripting/OOJSSystem.cpp:1361` | ✅ |
| `SystemStaticSystemNameForID()` (1108) | `SystemStaticSystemNameForID` `Core/Scripting/OOJSSystem.cpp:1392` | ✅ |
| `SystemStaticSystemIDForName()` (1129) | `SystemStaticSystemIDForName` `Core/Scripting/OOJSSystem.cpp:1416` | ✅ |
| `SystemStaticInfoForSystem()` (1155) | `SystemStaticInfoForSystem` `Core/Scripting/OOJSSystem.cpp:1445` | ✅ |
| `SystemAddVisualEffect()` (1182) | `SystemAddVisualEffect` `Core/Scripting/OOJSSystem.cpp:1475` | ✅ |
| `SystemSetPopulator()` (1216) | `SystemSetPopulator` `Core/Scripting/OOJSSystem.cpp:1512` | ✅ |
| `SystemSetWaypoint()` (1273) | `SystemSetWaypoint` `Core/Scripting/OOJSSystem.cpp:1578` | ❌ |
| `SystemAddShipsOrGroup()` (1324) | `SystemAddShipsOrGroup` `Core/Scripting/OOJSSystem.cpp:1637` | ✅ |
| `SystemAddShipsOrGroupToRoute()` (1383) | `SystemAddShipsOrGroupToRoute` `Core/Scripting/OOJSSystem.cpp:1704` | ✅ |
| `GetRelativeToAndRange()` (1445) | `GetRelativeToAndRange` `Core/Scripting/OOJSSystem.cpp:1772` | ✅ |
| `FindJSVisibleEntities()` (1477) | `FindJSVisibleEntities` `Core/Scripting/OOJSSystem.cpp:1808` | ✅ |
| `FindShips()` (1502) | `FindShips` `Core/Scripting/OOJSSystem.cpp:1833` | ✅ |
| `CompareEntitiesByDistance()` (1515) | `CompareEntitiesByDistance` `Core/Scripting/OOJSSystem.cpp:1848` | ✅ |

**Differences:**

- ❌ **low** — `system.waypoints` and `system.populatorSettings` are now built from `oo::PList::Dict` (a `std::map`), so the JS object's keys enumerate in sorted order. Upstream converted an `NSDictionary`, which enumerates in GNUstep hash order. This shows in `for…in`/`Object.keys` order. The port also skips null waypoint holds (upstream's dictionary could hold no nil) — upstream `Core/Scripting/OOJSSystem.m:271` ↔ port `Core/Scripting/OOJSSystem.cpp:455`; upstream `Core/Scripting/OOJSSystem.m:324` ↔ port `Core/Scripting/OOJSSystem.cpp:515`
- ❌ **low** — `setWaypoint(key, pos, ori, def)` where `def` is a JS array (or another non-dictionary convertible object): upstream `-mutableCopy` gives an NSMutableArray, `-setObject:forKey:` throws, and `OOJS_NATIVE_EXIT` turns that into a JS exception. The port's `getIf<Dict>()` is null, so it skips the position/orientation keys and calls `defineWaypoint(<array>, key)` without raising — upstream `Core/Scripting/OOJSSystem.m:1309` ↔ port `Core/Scripting/OOJSSystem.cpp:1616`
- ✅ **low** — the property, method and static tables match upstream entry for entry: 29 properties with the same IDs and `READONLY_CB`/`READWRITE_CB` (`kSystemPropertyFlagsRO/RW` expand to the same Permanent|Enumerate|[ReadOnly]|Shared); 25 methods and 3 statics with the same arities. `info` is read-only in both, although its enum comment says read/write. The port keeps a second copy, `sSystemPropertiesRaw`, for the bad-property reporters; it is currently identical but must be kept in sync by hand — upstream `Core/Scripting/OOJSSystem.m:141` ↔ port `Core/Scripting/OOJSSystem.cpp:267`, `:308`
- ✅ **low** — upstream's copy-paste mistakes in error-message function names are kept exactly: `shipsWithPrimaryRole` reports `countShipsWithRole`, `entitiesWithScanClass` reports `countEntitiesWithScanClass`, `addShipsToRoute`/`addGroupToRoute` report `addShips`/`addGroup`, and `legacy_addShipsWithinRadius` reports `legacy_addShipWithinRadius` — upstream `Core/Scripting/OOJSSystem.m:724`, `:822`, `:1394`, `:1066` ↔ port `Core/Scripting/OOJSSystem.cpp:957`, `:1064`, `:1718`, `:1343`
- ✅ **low** — ship spawning matches: the count must be 1–64 via `ValueToInt32`, and a missing vector means the witchpoint with `SCANNER_MAX_RANGE` radius. The `NSNotFound` sentinel radius/route fraction is still passed as `GLfloat`/`double` and matches Universe's sentinel checks (`Core/Universe.cpp:3008`, `:10031`). The route fraction must be finite and in [0,1]; the route is lower-cased and must be one of `wp pw ws sw sp ps`, default `st`. Return shape is unchanged: an empty spawn gives null, and for groups the first ship's group (or null). This file makes no RNG calls; the randomisation lives in `Universe::addShipsAt`/`addShipsToRoute`/`addShipAt` — upstream `Core/Scripting/OOJSSystem.m:1324-1443` ↔ port `Core/Scripting/OOJSSystem.cpp:1637-1768`
- ✅ **low** — the distance sort only runs when `relativeTo` is a non-player entity, in both. The port uses `std::stable_sort` with the same float `HPdistance2` comparison. Upstream used GNUstep `-sortUsingFunction:context:` (the port's comment says that is timsort, which is stable; Apple Foundation builds may differ). Order can differ only for entities at exactly equal float distance — upstream `Core/Scripting/OOJSSystem.m:1492` ↔ port `Core/Scripting/OOJSSystem.cpp:1820`
- ✅ **low** — the search predicate parameters changed type to match the C++ predicates: `entitiesWithScanClass` passes an `OOScanClass*` instead of an `NSNumber`, and the role searches pass a `std::string*` instead of an `NSString`. `HasScanClassPredicate`/`HasRolePredicate`/`HasPrimaryRolePredicate` (`Core/OOEntityFilterPredicate.cpp:111-160`) read those types, so the filtering is the same — upstream `Core/Scripting/OOJSSystem.m:834` ↔ port `Core/Scripting/OOJSSystem.cpp:1076`
- ✅ **low** — `systemIDForName` still stores the `OOSystemID` in an `unsigned` and returns it through `int32Value`, so "not found" still comes back as -1. `toString` still prints the system with `%u` (4294967295 in interstellar space) and a missing name as `(null)` (`oo::describe`) — upstream `Core/Scripting/OOJSSystem.m:1134-1149`, `:578` ↔ port `Core/Scripting/OOJSSystem.cpp:1422-1437`, `:792`

## OOJSSystemInfo

<a id="oojssysteminfo"></a>
Upstream `src/Core/Scripting/OOJSSystemInfo.m` ↔ `Core/Scripting/OOJSSystemInfo.cpp`

**Status:** done — 35 rows: 30 ✅ 1 ⚠️ 2 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sSystemInfoClass` JSClass (54) | `sSystemInfoClass` ClassDef — `Core/Scripting/OOJSSystemInfo.cpp:170` (HasPrivate\|NewEnumerate; stubs → nullptr engine defaults; enumerate in `newEnumerate` slot) | ✅ |
| property-ID enum + `sSystemInfoProperties` (69, 77) | enum + `sSystemInfoProperties` — `Core/Scripting/OOJSSystemInfo.cpp:189`, `:198` (Permanent\|Enumerate\|ReadOnly\|Shared = OOJS_PROP_READONLY_CB; raw mirror for the bad-selector reporter `:213`) | ✅ |
| `sSystemInfoMethods` (86) | `sSystemInfoMethods` — `Core/Scripting/OOJSSystemInfo.cpp:224` (toString 0, distanceToSystem 1, routeToSystem 1, samplePrice 1, setProperty 3; toString → `SystemInfoToString` `:500` → `OOJSCxxObjectWrapperToString`) | ✅ |
| `sSystemInfoStaticMethods` (96) | `sSystemInfoStaticMethods` — `Core/Scripting/OOJSSystemInfo.cpp:236` (filteredSystems 2, setInterstellarProperty 4) | ✅ |
| statics `sSystemInfoPrototype`/`sCachedSystemInfo`/`sCachedGalaxy`/`sCachedSystem` (35–38) | same names — `Core/Scripting/OOJSSystemInfo.cpp:109–119` | ✅ |
| `DEFINE_JS_OBJECT_GETTER(JSSystemInfoGetSystemInfo…)` (124) | `JSSystemInfoGetSystemInfo` → `OOJSGetCxxPrivate` — `Core/Scripting/OOJSSystemInfo.cpp:280` (same "Native method expected %s, got %s." check, `Core/Scripting/OOJSPrivateObject.cpp:60`); `SystemInfoOfJSObject` `:287` for OOJSNativeObjectOfClassFromJSObject | ✅ |
| `-[OOSystemInfo init]` (128) | — (no default constructor; only private `OOSystemInfo(galaxy, system)` `Core/Scripting/OOJSSystemInfo.cpp:297`) | ➖ |
| `-[OOSystemInfo initWithGalaxy:system:]` (134) | `OOSystemInfo::initWithGalaxy` factory — `Core/Scripting/OOJSSystemInfo.cpp:304` (same range checks, null instead of nil; `_planetKey` "%u %i") | ✅ |
| `-[OOSystemInfo dealloc]` (149) | — (`std::string _planetKey` RAII) | ➖ |
| `-[OOSystemInfo descriptionComponents]` (156) | `OOSystemInfo::descriptionComponents` — `Core/Scripting/OOJSSystemInfo.cpp:313` | ✅ |
| `-[OOSystemInfo shortDescriptionComponents]` (161) | `OOSystemInfo::shortDescriptionComponents` — `Core/Scripting/OOJSSystemInfo.cpp:318` | ✅ |
| `-[OOSystemInfo oo_jsClassName]` (166) | `OOSystemInfo::oo_jsClassName` — `Core/Scripting/OOJSSystemInfo.cpp:323` | ✅ |
| `-[OOSystemInfo isEqual:]` (171) | `OOSystemInfo::isEqual` — `Core/Scripting/OOJSSystemInfo.cpp:328` | ✅ |
| `-[OOSystemInfo hash]` (176) | `OOSystemInfo::hash` — `Core/Scripting/OOJSSystemInfo.cpp:333` | ✅ |
| `-[OOSystemInfo valueForKey:]` (184) | `OOSystemInfo::valueForKey` — `Core/Scripting/OOJSSystemInfo.cpp:341` (interstellar && -1 → currentSystemData lookup; else `Universe::systemDataForGalaxy` → `getProperty(key, s, g)` cache read, `Core/Universe.cpp:7939`) | ✅ |
| `-[OOSystemInfo setValue:forKey:]` (192) | `OOSystemInfo::setValue` — `Core/Scripting/OOJSSystemInfo.cpp:352` (running script's manifest, `OO_LAYER_OXP_DYNAMIC`) | ✅ |
| `-[OOSystemInfo allKeys]` (199) | `OOSystemInfo::allKeys` — `Core/Scripting/OOJSSystemInfo.cpp:361` | ⚠️ |
| `-[OOSystemInfo galaxy]` (207) | `OOSystemInfo::galaxy` — `Core/Scripting/OOJSSystemInfo.cpp:377` | ✅ |
| `-[OOSystemInfo system]` (212) | `OOSystemInfo::system` — `Core/Scripting/OOJSSystemInfo.cpp:382` | ✅ |
| `-[OOSystemInfo coordinates]` (223) | `OOSystemInfo::coordinates` — `Core/Scripting/OOJSSystemInfo.cpp:393` (interstellar && -1 → player galaxy_coordinates) | ✅ |
| `-[OOSystemInfo oo_jsValueInContext:]` (231) | `OOSystemInfo::jsValueInContext` — `Core/Scripting/OOJSSystemInfo.cpp:401` (new object every call; `_jsSelf` only recorded) | ✅ |
| (inherited) `-description` / `-oo_jsDescription` | `OOSystemInfo::className`/`description`/`jsDescription` — `Core/Scripting/OOJSSystemInfo.cpp:428`, `:433`, `:439` | ❌ |
| `InitOOJSSystemInfo()` (249) | `InitOOJSSystemInfo` — `Core/Scripting/OOJSSystemInfo.cpp:460` (converter `SystemInfoConverter` `:451` = OOJSBasicPrivateObjectConverter) | ✅ |
| `GetJSSystemInfoForSystem()` (255) | `GetJSSystemInfoForSystem` — `Core/Scripting/OOJSSystemInfo.cpp:467` | ✅ |
| `SystemInfoFinalize()` (287) | `SystemInfoFinalize` — `Core/Scripting/OOJSSystemInfo.cpp:507` (→ `OOJSCxxObjectWrapperFinalize`, then cache clear) | ✅ |
| `SystemInfoEnumerate()` (301) | `SystemInfoEnumerate` — `Core/Scripting/OOJSSystemInfo.cpp:524` | ✅ |
| `SystemInfoDeleteProperty()` (350) | `SystemInfoDeleteProperty` — `Core/Scripting/OOJSSystemInfo.cpp:575` (body equal; engine calls it less often) | ❌ |
| `SystemInfoGetProperty()` (360) | `SystemInfoGetProperty` — `Core/Scripting/OOJSSystemInfo.cpp:587` | ✅ |
| `SystemInfoSetProperty()` (435) | `SystemInfoSetProperty` — `Core/Scripting/OOJSSystemInfo.cpp:670` | ✅ |
| `SystemInfoDistanceToSystem()` (456) | `SystemInfoDistanceToSystem` — `Core/Scripting/OOJSSystemInfo.cpp:698` | ✅ |
| `SystemInfoRouteToSystem()` (486) | `SystemInfoRouteToSystem` — `Core/Scripting/OOJSSystemInfo.cpp:731` | ✅ |
| `SystemInfoSamplePrice()` (523) | `SystemInfoSamplePrice` — `Core/Scripting/OOJSSystemInfo.cpp:771` | ✅ |
| `SystemInfoSetPropertyMethod()` (550) | `SystemInfoSetPropertyMethod` — `Core/Scripting/OOJSSystemInfo.cpp:804` | ✅ |
| `SystemInfoStaticFilteredSystems()` (597) | `SystemInfoStaticFilteredSystems` — `Core/Scripting/OOJSSystemInfo.cpp:855` | ✅ |
| `SystemInfoStaticSetInterstellarProperty()` (662) | `SystemInfoStaticSetInterstellarProperty` — `Core/Scripting/OOJSSystemInfo.cpp:929` | ✅ |

**Differences:**

- ❌ **med** — `delete info.<prop>` no longer clears the scripted (OXP_DYNAMIC) override unless that name was first assigned on the same JS object. SpiderMonkey called the class delProperty hook for any missing or non-own property (`upstream/spidermonkey-ff4/js/src/jsobj.cpp:5880`), so delete → SetProperty(undefined) → `setValue:nil` cleared the layer. The QuickJS `ExDeleteProperty` returns true without calling the hook when there is no own slot. It also answers `true` for `delete info.coordinates`, where SpiderMonkey answered `false` (shared-permanent) — upstream `Core/Scripting/OOJSSystemInfo.m:350` ↔ port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:1604`
- ⚠️ **low** — `for…in` / `Object.keys` over a SystemInfo lists keys in byte order (PList::Dict) instead of NSDictionary `-allKeys` hash order, for both the interstellar `currentSystemData` path and the `systemDataKeysForGalaxy` path. The port's comments say this on purpose ("in key order (-allKeys gave hash order)", "Byte order of the key") — upstream `Core/Scripting/OOJSSystemInfo.m:202`, `Core/Universe.m:7494` ↔ port `Core/Scripting/OOJSSystemInfo.cpp:364`, `Core/Universe.cpp:7926`
- ❌ **low** — `OOSystemInfo::description()` gives `<OOSystemInfo>{galaxy g, system s}` without the `0x…` address that the inherited NSObject `-description` printed (`<OOSystemInfo 0x…>{…}`, the oofnd README convention). It shows only in logs that print a PList holding a SystemInfo; JS `toString()` (`jsDescription`) matches upstream exactly — upstream `Core/Scripting/OOJSSystemInfo.m:156` ↔ port `Core/Scripting/OOJSSystemInfo.cpp:433`
- ✅ **low** — subtle: the manifest argument (running script's `kLocalManifestProperty`) and samplePrice's `commodity_script` go through `ManifestString`, which keeps only strings. A non-string value becomes "none" (no scripted-change save, no price script), where upstream passed the object on as-is. Normal paths (string manifest, string script) are identical — upstream `Core/Scripting/OOJSSystemInfo.m:194`, `:543`, `:586`, `:728` ↔ port `Core/Scripting/OOJSSystemInfo.cpp:253`, `:794`
- ✅ **low** — subtle: routeToSystem returns the same dict as upstream: `route`, `distance`, `time` (doubles) and `jumps` (int); null for interstellar or no route. Route type parsing is the same: NONE/JUMPS/TIME, otherwise `kOORouteTypeDefault`; a missing argument becomes `""` instead of nil, with the same result. The JS object's key order follows PList::Dict (distance, jumps, route, time) instead of NSDictionary hash order — upstream `Core/Universe.m:7876`, `Core/OOConstToString.m:498` ↔ port `Core/Universe.cpp:8364`, `Core/OOConstToString.cpp:527`
- ✅ — the layer semantics match. The string-key get reads the merged cache through `getProperty(key, system, galaxy)` (with the same "invalid system key" log for system -1 outside interstellar space). The setter and the delete hook write `OO_LAYER_OXP_DYNAMIC`. `setProperty(layer,…)` checks `0 ≤ layer < OO_SYSTEM_LAYERS` with the same messages. `setInterstellarProperty` builds the key `"interstellar: %u %u %u"` and calls `OOSystemDescriptionManager::setProperty` with the same 4-token save rule — upstream `Core/OOSystemDescriptionManager.m:158`, `:325` ↔ port `Core/OOSystemDescriptionManager.cpp:173`, `:345`
- ✅ — the number-literal coercion in GetProperty is preserved. `PList::isNumber()` counts Bool, as NSNumber did (`oofnd/PList.hpp:220`). `DescriptionOf` of a string is the string itself, and string → double goes through `plist_get::doubleValue` — upstream `Core/Scripting/OOJSSystemInfo.m:419` ↔ port `Core/Scripting/OOJSSystemInfo.cpp:649`
- ✅ — the cache and filteredSystems object identity match. The cache stores null on a failed create (`toObject(nullValue)` = nullptr) and is cleared in finalize. `jsValueInContext` always makes a new JS object (`Core/Scripting/OOJSPrivateObject.cpp:39`), so filteredSystems' result elements are new objects, not the ones passed to the predicate, as upstream did — upstream `Core/Scripting/OOJSSystemInfo.m:231`, `:649` ↔ port `Core/Scripting/OOJSSystemInfo.cpp:401`, `:915`
- ✅ — error, warning and bad-argument texts and counts match verbatim. This includes setInterstellarProperty's `MIN(argc, 3U)` and its "setProperty(galaxy, fromsystem, tosystem, layer, property, value [,manifest])" text, filteredSystems' unclamped argc, and the "Cannot read systemInfo values for %s." / "…in other galaxies." messages. The nil-messaging defaults (0 galaxy/system, zero point, null) are kept by `GalaxyOf`/`SystemOf`/`CoordinatesOf`/`ValueForKey` — port `Core/Scripting/OOJSSystemInfo.cpp:262–265`

## OOJSTimer

<a id="oojstimer"></a>
Upstream `src/Core/Scripting/OOJSTimer.m` ↔ `Core/Scripting/OOJSTimer.cpp`

**Status:** done — 19 rows: 17 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sTimerClass` JSClass (187) | `sTimerClass` ClassDef `Core/Scripting/OOJSTimer.cpp:115` (HasPrivate; get/set; finalize = `OOJSCxxObjectWrapperFinalize`) | ✅ |
| enum + `sTimerProperties[]` (202, 209) | enum `:134`, `sTimerProperties[]` `:142` (interval RW, isRunning RO, nextTime RW; all Permanent\|Enumerate\|Shared); reporter mirror `sTimerPropertiesRaw[]` `:155` | ✅ |
| `sTimerMethods[]` (217) | `sTimerMethods[]` `Core/Scripting/OOJSTimer.cpp:164` (toString → `TimerToString` `:541` → `OOJSCxxObjectWrapperToString`; start 0; stop 0) | ✅ |
| `DEFINE_JS_OBJECT_GETTER(JSTimerGetTimer…)` (225) | `JSTimerGetTimer` → `OOJSGetCxxPrivate` `Core/Scripting/OOJSTimer.cpp:176` (null for the prototype) | ✅ |
| `-[OOJSTimer initWithDelay:…]` (48) | `OOJSTimer::timerWithDelay` `:182` + `initWithDelay` `Core/Scripting/OOJSTimer.cpp:190` | ✅ |
| `-[OOJSTimer deleteJSPointers]` (85) | `OOJSTimer::deleteJSPointers` `Core/Scripting/OOJSTimer.cpp:223` | ✅ |
| `-[OOJSTimer dealloc]` (104) | `OOJSTimer::~OOJSTimer` `Core/Scripting/OOJSTimer.cpp:241` | ✅ |
| `-[OOJSTimer descriptionComponents]` (113) | `OOJSTimer::descriptionComponents` `Core/Scripting/OOJSTimer.cpp:248` | ❌ |
| `-[OOJSTimer oo_jsClassName]` (133) | `OOJSTimer::oo_jsClassName` `Core/Scripting/OOJSTimer.cpp:268` | ✅ |
| `-[OOJSTimer timerFired]` (138) | `OOJSTimer::timerFired` `Core/Scripting/OOJSTimer.cpp:273` | ✅ |
| `-[OOJSTimer oo_jsValueInContext:]` (171) | `OOJSTimer::jsValueInContext` `Core/Scripting/OOJSTimer.cpp:306` | ✅ |
| (inherited) `-oo_jsDescription` | `OOJSTimer::jsDescription` `Core/Scripting/OOJSTimer.cpp:325` (`"[Timer <components>]"`, else `"[object Timer]"`) | ✅ |
| `InitOOJSTimer()` (227) | `InitOOJSTimer` `Core/Scripting/OOJSTimer.cpp:346` (converter `TimerConverter` `:337`: timer as a PList Object node, null for the prototype) | ✅ |
| `TimerGetProperty()` (233) | `TimerGetProperty` `Core/Scripting/OOJSTimer.cpp:354` | ✅ |
| `TimerSetProperty()` (264) | `TimerSetProperty` `Core/Scripting/OOJSTimer.cpp:390` | ✅ |
| `TimerFinalize()` (305) | `OOJSTimer::clearJSSelf` `Core/Scripting/OOJSTimer.cpp:312` (via `OOJSCxxObjectWrapperFinalize`) | ⚠️ |
| `TimerConstruct()` (324) | `TimerConstruct` `Core/Scripting/OOJSTimer.cpp:438` | ✅ |
| `TimerStart()` (391) | `TimerStart` `Core/Scripting/OOJSTimer.cpp:503` | ✅ |
| `TimerStop()` (406) | `TimerStop` `Core/Scripting/OOJSTimer.cpp:521` | ✅ |

**Differences:**

- ❌ **low** — the function name in the timer's description comes from QuickJS `fn.name` (`getFunctionId`, which treats `""` as anonymous). ES2015 infers that name for `var f = function () {}` and for object-literal methods, where SpiderMonkey 1.8.5 `JS_GetFunctionId` returned NULL and the description said "anonymous". It shows in `Timer.toString()` and in the "Ignoring attempt to change next fire time for running timer %s." warning — upstream `Core/Scripting/OOJSTimer.m:123-128` ↔ port `Core/Scripting/OOJSTimer.cpp:258-263`, `ooscript/JSEngine_quickjs.cpp:3121-3137`
- ⚠️ **low** — the warning for a timer collected while still running ("Timer %s is being garbage-collected while still running…", class `script.javaScript.unrootedTimer`) now describes the timer with the base components only, without `, function: <name>`, because reading the name during GC corrupted the heap (port comment, bead oo-r1ci7). It also clears `_jsSelf`, where upstream left it dangling — upstream `Core/Scripting/OOJSTimer.m:312-318` ↔ port `Core/Scripting/OOJSTimer.cpp:312-321`
- ✅ **low** — interval at or below 0, and the construct path:
  - The constructor's interval defaults to -1, or to -1 if the fourth argument is not a number. An interval in (0, 0.25) is raised to `kMinInterval` 0.25. An interval ≤ 0 becomes -1, a one-shot (`OOScriptTimer::initWithNextTime`); `timer.interval = x` does the same (`setInterval`).
  - A negative delay on a one-shot timer fails init. The native then returns false with no exception set, which is SpiderMonkey's uncatchable abort; the façade emulates it (`ooscript/JSEngine_quickjs.cpp:744`).
  - A negative delay on a repeating timer creates it stopped. `delay >= 0` schedules it.
  - The texts match: the bad-argument text "Invalid arguments in constructor" / "(object, function, number [, number])", and the "Timer() cannot be called as a function…" error.

  upstream `Core/Scripting/OOJSTimer.m:328-383` ↔ port `Core/Scripting/OOJSTimer.cpp:443-493`
- ✅ **low** — the firing test is preserved. The timer stops itself, without calling the function, when `this` converts to nothing. That covers a dead entity (the `OOJSEntityHolder` weak ref, `OOJSEntity.cpp:224-228`) and also `this` = null, so `new Timer(null, f, 1)` never fires in either version (`OOJSNativeObjectFromJSObject(NULL)` = nil ↔ `cxx_OOJSPListFromJSObject` null, `OOJavaScriptEngine.cpp:2066`). Otherwise the call is wrapped in push/pop of the owning script, as upstream did — upstream `Core/Scripting/OOJSTimer.m:147-166` ↔ port `Core/Scripting/OOJSTimer.cpp:282-301`
- ✅ **low** — the property semantics match. On the prototype, nextTime/interval read 0 and isRunning reads false. Setting nextTime on a running timer warns and leaves the value (`%@` description ↔ `description()`, which is `<OOJSTimer 0x…>{…}`). A non-number triggers the bad-value report and returns false. `start()` returns `scheduleTimer()`; `stop()` returns undefined — upstream `Core/Scripting/OOJSTimer.m:233-303`, `:391-418` ↔ port `Core/Scripting/OOJSTimer.cpp:354-433`, `:503-536`

## OOJSVector

<a id="oojsvector"></a>
Upstream `src/Core/Scripting/OOJSVector.m` ↔ `Core/Scripting/OOJSVector.cpp`

**Status:** done — 45 rows: 42 ✅ 3 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sVectorClass` / `sVectorProperties` / `sVectorMethods` / `sVectorStaticMethods` tables (74–227) | same names `Core/Scripting/OOJSVector.cpp:177-248` (x/y/z `Permanent \| Enumerate \| Shared` = `OOJS_PROP_READWRITE_CB`; same method names, min-args, order) | ✅ |
| `InitOOJSVector()` (231) | `InitOOJSVector` `Core/Scripting/OOJSVector.cpp:252` | ✅ |
| `JSVectorWithVector()` (236) | `JSVectorWithVector` `Core/Scripting/OOJSVector.cpp:260` | ✅ |
| `VectorToJSValue()` (264) | `VectorToJSValue` `Core/Scripting/OOJSVector.cpp:287` | ✅ |
| `JSVectorWithHPVector()` (282) | `JSVectorWithHPVector` `Core/Scripting/OOJSVector.cpp:305` | ✅ |
| `HPVectorToJSValue()` (310) | `HPVectorToJSValue` `Core/Scripting/OOJSVector.cpp:332` | ✅ |
| `NSPointToVectorJSValue()` (328) | `NSPointToVectorJSValue` `Core/Scripting/OOJSVector.cpp:350` | ✅ |
| `JSValueToHPVector()` (333) | `JSValueToHPVector` `Core/Scripting/OOJSVector.cpp:355` | ✅ |
| `JSValueToVector()` (341) | `JSValueToVector` `Core/Scripting/OOJSVector.cpp:363` | ✅ |
| `-[PlayerEntity(JSVectorStatistics) reportJSVectorStatistics]` (369) | `reportJSVectorStatistics` `Core/Scripting/OOJSVector.cpp:390` (free function, bead oo-9ht.15) | ✅ |
| `-[PlayerEntity(JSVectorStatistics) clearJSVectorStatistics]` (395) | `clearJSVectorStatistics` `Core/Scripting/OOJSVector.cpp:416` | ✅ |
| `JSObjectGetVector()` (415) | `JSObjectGetVector` `Core/Scripting/OOJSVector.cpp:434` | ✅ |
| `GetThisVector()` (483) | `GetThisVector` `Core/Scripting/OOJSVector.cpp:504` | ✅ |
| `JSVectorSetVector()` (493) | `JSVectorSetVector` `Core/Scripting/OOJSVector.cpp:515` | ✅ |
| `JSVectorSetHPVector()` (498) | `JSVectorSetHPVector` `Core/Scripting/OOJSVector.cpp:520` | ✅ |
| `VectorFromArgumentListNoErrorInternal()` (525) | `VectorFromArgumentListNoErrorInternal` `Core/Scripting/OOJSVector.cpp:550` | ✅ |
| `VectorFromArgumentList()` (573) | `VectorFromArgumentList` `Core/Scripting/OOJSVector.cpp:600` | ✅ |
| `VectorFromArgumentListNoError()` (585) | `VectorFromArgumentListNoError` `Core/Scripting/OOJSVector.cpp:612` | ✅ |
| `VectorGetProperty()` (592) | `VectorGetProperty` `Core/Scripting/OOJSVector.cpp:620` | ✅ |
| `VectorSetProperty()` (628) | `VectorSetProperty` `Core/Scripting/OOJSVector.cpp:661` | ✅ |
| `VectorFinalize()` (668) | `VectorFinalize` `Core/Scripting/OOJSVector.cpp:706` | ✅ |
| `VectorConstruct()` (683) | `VectorConstruct` `Core/Scripting/OOJSVector.cpp:722` | ✅ |
| `VectorToString()` (725) | `VectorToString` `Core/Scripting/OOJSVector.cpp:768` | ✅ |
| `VectorToSource()` (740) | `VectorToSource` `Core/Scripting/OOJSVector.cpp:786` | ✅ |
| `VectorAdd()` (756) | `VectorAdd` `Core/Scripting/OOJSVector.cpp:804` | ✅ |
| `VectorSubtract()` (775) | `VectorSubtract` `Core/Scripting/OOJSVector.cpp:826` | ✅ |
| `VectorDistanceTo()` (794) | `VectorDistanceTo` `Core/Scripting/OOJSVector.cpp:848` | ✅ |
| `VectorSquaredDistanceTo()` (814) | `VectorSquaredDistanceTo` `Core/Scripting/OOJSVector.cpp:871` | ✅ |
| `VectorMultiply()` (834) | `VectorMultiply` `Core/Scripting/OOJSVector.cpp:894` | ✅ |
| `VectorDot()` (854) | `VectorDot` `Core/Scripting/OOJSVector.cpp:917` | ✅ |
| `VectorAngleTo()` (874) | `VectorAngleTo` `Core/Scripting/OOJSVector.cpp:940` | ✅ |
| `VectorCross()` (901) | `VectorCross` `Core/Scripting/OOJSVector.cpp:970` | ✅ |
| `VectorTripleProduct()` (920) | `VectorTripleProduct` `Core/Scripting/OOJSVector.cpp:992` | ✅ |
| `VectorDirection()` (946) | `VectorDirection` `Core/Scripting/OOJSVector.cpp:1022` | ✅ |
| `VectorMagnitude()` (963) | `VectorMagnitude` `Core/Scripting/OOJSVector.cpp:1042` | ✅ |
| `VectorSquaredMagnitude()` (981) | `VectorSquaredMagnitude` `Core/Scripting/OOJSVector.cpp:1063` | ✅ |
| `VectorRotationTo()` (999) | `VectorRotationTo` `Core/Scripting/OOJSVector.cpp:1084` | ✅ |
| `VectorRotateBy()` (1036) | `VectorRotateBy` `Core/Scripting/OOJSVector.cpp:1125` | ✅ |
| `VectorToArray()` (1056) | `VectorToArray` `Core/Scripting/OOJSVector.cpp:1148` | ✅ |
| `VectorToCoordinateSystem()` (1085) | `VectorToCoordinateSystem` `Core/Scripting/OOJSVector.cpp:1181` | ✅ |
| `VectorFromCoordinateSystem()` (1111) | `VectorFromCoordinateSystem` `Core/Scripting/OOJSVector.cpp:1212` | ✅ |
| `VectorStaticInterpolate()` (1140) | `VectorStaticInterpolate` `Core/Scripting/OOJSVector.cpp:1246` | ✅ |
| `VectorStaticRandom()` (1183) | `VectorStaticRandom` `Core/Scripting/OOJSVector.cpp:1293` | ⚠️ |
| `VectorStaticRandomDirection()` (1198) | `VectorStaticRandomDirection` `Core/Scripting/OOJSVector.cpp:1311` | ⚠️ |
| `VectorStaticRandomDirectionAndLength()` (1213) | `VectorStaticRandomDirectionAndLength` `Core/Scripting/OOJSVector.cpp:1329` | ⚠️ |

**Differences:**

- ⚠️ **low** — `Vector3D.random()`, `randomDirection()`, `randomDirectionAndLength()`: the bindings are identical, but the helpers they call (`OOHPVectorRandomSpatial`, `OORandomUnitHPVector`, `OOHPVectorRandomRadial`) now draw `randf()` on separate lines in Clang's left-to-right order (x, y, z; direction before length) per ADR-0063 item 5. Upstream drew them inside one call's argument list (unspecified order), so a GCC-built upstream can consume the RNG in a different order and give different vectors from the same seed — upstream `Core/OOHPVector.m:68, 81, 90` ↔ port `Core/OOHPVector.cpp:66-69, 82-85, 94-96`
- Constructor forms match: no args → `(0, 0, 0)`; a Vector3D; an entity (its position; a dead/absent entity → zero, as the message to nil, `OOJSEntityPositionOfJSObject` `Core/Scripting/OOJSEntity.cpp:231-236`); an array of exactly 3 elements (each through `valueToNumber`, no NaN check); `Vector3D.prototype` → zero; or three numbers, each rejected if NaN. `null` counts as an object and then fails, as upstream (`isObjectOrNull` = SM 1.8.5 `JSVAL_IS_OBJECT`). Error texts and argument counts identical: `Invalid target object`, `Could not construct vector from parameters` / `Vector, Entity or array of three numbers`, `Insufficient parameters` / `vector expression, vector expression and number`.
- `toString()` is `(%g, %g, %g)` (`cxx_HPVectorDescription`, `Core/OOHPVector.cpp:39-42`), `toSource()` is `Vector3D(%g, %g, %g)`; both via `vsnprintf`, whose `%g` matches GNUstep (the ADR-0034 differences listed at `oofnd/String.hpp:568-573` do not include `%g`). `fromCoordinateSystem` builds `"%s %f %f %f"`; `%f` of magnitudes above ~1e22 is where GNUstep dropped digits (ADR-0034), not reachable with real coordinates.
- Maths: `add`, `subtract`, `distanceTo`, `squaredDistanceTo`, `multiply`, `dot`, `angleTo` (clamped to ±1 before `acos`), `cross` (`HPtrue_cross_product`), `tripleProduct`, `direction`, `magnitude`, `squaredMagnitude`, `rotationTo` (optional limit → `quaternion_limited_rotation_between`, on single-precision vectors as upstream), `rotateBy`, `interpolate` call the same functions; `OOHPVector.h`/`OOQuaternion.h` inline maths are unchanged (checked by diff). `random*` default to 1.0 when the argument is missing or not a number.
- `toCoordinateSystem`/`fromCoordinateSystem` return `(0,0,0)` when `UNIVERSE` is null, matching upstream's struct return from a nil message — port `Core/Scripting/OOJSVector.cpp:1201, 1233`
- The constructor now frees its buffer when `newObject` fails (upstream leaked); not observable — port `Core/Scripting/OOJSVector.cpp:736-739`

## OOJSVisualEffect

<a id="oojsvisualeffect"></a>
Upstream `src/Core/Scripting/OOJSVisualEffect.m` ↔ `Core/Scripting/OOJSVisualEffect.cpp`

**Status:** done — 18 rows: 18 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sVisualEffectProperties[]` (92): 22 props; read-only: dataKey, script, scriptInfo, subEntities, vectorForward/Right/Up; the rest READWRITE_CB (enum order of tinyids identical) | `sVisualEffectProperties` `Core/Scripting/OOJSVisualEffect.cpp:178` (+ `sVisualEffectPropertiesRaw` :209; enum :151) | ✅ |
| `sVisualEffectMethods[]` (119): getMaterials 0, getShaders 0, remove 0, restoreSubEntities 0, scale 1, setMaterials 1, setShaders 2 | `sVisualEffectMethods` `Core/Scripting/OOJSVisualEffect.cpp:238` | ✅ |
| `InitOOJSVisualEffect()` (132) | `InitOOJSVisualEffect` `Core/Scripting/OOJSVisualEffect.cpp:252` | ✅ |
| `JSVisualEffectGetVisualEffectEntity()` (139) | `JSVisualEffectGetVisualEffectEntity` `Core/Scripting/OOJSVisualEffect.cpp:261` (`oo::ToEffect` for `-isKindOfClass:`) | ✅ |
| `-[OOVisualEffectEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (165) | `OOJSVisualEffectGetJSClass` `Core/Scripting/OOJSVisualEffect.cpp:290` | ✅ |
| `-[OOVisualEffectEntity(OOJavaScriptExtensions) oo_jsClassName]` (171) | `OOJSVisualEffectJSClassName` `Core/Scripting/OOJSVisualEffect.cpp:296` ("VisualEffect") | ✅ |
| `-[OOVisualEffectEntity(OOJavaScriptExtensions) isVisibleToScripts]` (176) | `OOJSVisualEffectIsVisibleToScripts` `Core/Scripting/OOJSVisualEffect.cpp:301` | ✅ |
| `-[OOVisualEffectEntity(OOJavaScriptExtensions) subEntitiesForScript]` (181) | `OOJSVisualEffectSubEntitiesForScript` `Core/Scripting/OOJSVisualEffect.cpp:306` (over `visualEffectSubEntityEnumerator` `Core/Entities/OOVisualEffectEntity.cpp:385`) | ✅ |
| `VisualEffectGetProperty()` (188) | `VisualEffectGetProperty` `Core/Scripting/OOJSVisualEffect.cpp:320` | ✅ |
| `VisualEffectSetProperty()` (297) | `VisualEffectSetProperty` `Core/Scripting/OOJSVisualEffect.cpp:439` | ✅ |
| `VisualEffectRemove()` (467) | `VisualEffectRemove` `Core/Scripting/OOJSVisualEffect.cpp:651` | ✅ |
| `VisualEffectGetMaterials()` (487) | `VisualEffectGetMaterials` `Core/Scripting/OOJSVisualEffect.cpp:677` (+ helper `MeshMaterials` :629) | ✅ |
| `VisualEffectGetShaders()` (505) | `VisualEffectGetShaders` `Core/Scripting/OOJSVisualEffect.cpp:699` (+ helper `MeshShaders` :635) | ✅ |
| `VisualEffectSetMaterials()` (523) | `VisualEffectSetMaterials` `Core/Scripting/OOJSVisualEffect.cpp:721` | ✅ |
| `VisualEffectSetShaders()` (542) | `VisualEffectSetShaders` `Core/Scripting/OOJSVisualEffect.cpp:744` | ✅ |
| `VisualEffectSetMaterialsInternal()` (569) | `VisualEffectSetMaterialsInternal` `Core/Scripting/OOJSVisualEffect.cpp:775` | ✅ |
| `VisualEffectScale()` (632) | `VisualEffectScale` `Core/Scripting/OOJSVisualEffect.cpp:851` | ✅ |
| `VisualEffectRestoreSubEntities()` (662) | `VisualEffectRestoreSubEntities` `Core/Scripting/OOJSVisualEffect.cpp:888` | ✅ |

**Differences:**

- ✅ subtle — The getter types match:
  - `beaconCode`, `beaconLabel` and `dataKey` are strings, or null.
  - `isBreakPattern` is a boolean.
  - The scales, `hullHeatLevel` and `shaderFloat*` are numbers; `shaderInt*` are int32.
  - The vectors are Vectors.
  - The scanner colours are 4-float arrays, or null.
  - `subEntities` is null before the first subentity (a nil `subEntities` array), otherwise an array.
  - `script` is the script object, or null.
  - `scriptInfo` falls back to an empty dict (`OOVisualEffectEntity.m:651` ↔ `Core/Entities/OOVisualEffectEntity.cpp:771`).

  upstream `:205-289` ↔ port `:341-429`
- ✅ subtle — The setter validation is the same:
  - The scales must be `> 0`.
  - `hullHeatLevel` and `shaderFloat*` take any number; `shaderInt*` use ValueToInt32.
  - `beaconLabel` must be a non-nil string.
  - An empty or nil `beaconCode` clears the beacon, and sets the compass to planet mode if it was the player's next beacon. A new code on a non-beacon also calls `setNextBeacon`.

  upstream `:318-451` ↔ port `:464-617`
- ✅ subtle — The warning texts are identical ("VisualEffect.%s: expected %s instead of '%s'.", with "setShaders"/"setMaterials" and "object"/"object as second parameter"), as are the bad-argument texts "parameter object", "scale factor needed" and "scale factor must be positive". Order is preserved: `setShaders` gets `this` before checking argc, `setMaterials` after. `OOJS_ARGV[1] = OOJS_ARGV[0]` is safe because the trampoline pads argv to the declared nargs of 2 (`Core/Scripting/ooscript/JSEngine_quickjs.cpp:1827-1828`) — upstream `:529-591` ↔ port `:729-797`
- ✅ subtle — `scale(n)` returns `true` without setting an rval in both, so the JS result is the callee (see the header note). `restoreSubEntities()` keeps the unsigned `count - subCount > 0` test, which is true whenever the count changed in either direction: `NSUInteger` = `uintptr_t` (`oofnd/objc/OOFoundationTypes.h:64`) — upstream `:653-679` ↔ port `:874-911`
- ✅ subtle — In `setMaterials`/`setShaders`, the mesh is built from `oo_stringForKey:@"model"`. The port takes it only when the value is a string or number, else the empty string where upstream passed nil; whether `""` and nil fail alike is down to the OOMesh audit. `smooth` uses `get<bool>` (documented as `oo_boolForKey`, `oofnd/PListGet.hpp:14`), and the macros come from `ship-prefix-macros` read as a dictionary. `remove()` uses `oo::LiveOwner` for `[thisEnt owner]` — upstream `:609-625,474-479` ↔ port `:815-842,660-667`

## OOJSWaypoint

<a id="oojswaypoint"></a>
Upstream `src/Core/Scripting/OOJSWaypoint.m` ↔ `Core/Scripting/OOJSWaypoint.cpp`

**Status:** done — 9 rows: 9 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sWaypointProperties[]` (62): beaconCode, beaconLabel, orientation, size (tinyids 0-3), all READWRITE_CB | `sWaypointProperties` `Core/Scripting/OOJSWaypoint.cpp:119` (+ `sWaypointPropertiesRaw` :134) | ✅ |
| `sWaypointMethods[]` (71): empty | `sWaypointMethods` `Core/Scripting/OOJSWaypoint.cpp:145` | ✅ |
| `InitOOJSWaypoint()` (77) | `InitOOJSWaypoint` `Core/Scripting/OOJSWaypoint.cpp:152` | ✅ |
| `JSWaypointGetWaypointEntity()` (84) | `JSWaypointGetWaypointEntity` `Core/Scripting/OOJSWaypoint.cpp:161` (`dynamic_cast` for `-isKindOfClass:`) | ✅ |
| `-[OOWaypointEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (110) | `OOJSWaypointGetJSClass` `Core/Scripting/OOJSWaypoint.cpp:192` | ✅ |
| `-[OOWaypointEntity(OOJavaScriptExtensions) oo_jsClassName]` (116) | `OOJSWaypointJSClassName` `Core/Scripting/OOJSWaypoint.cpp:198` ("Waypoint") | ✅ |
| `-[OOWaypointEntity(OOJavaScriptExtensions) isVisibleToScripts]` (121) | `OOJSWaypointIsVisibleToScripts` `Core/Scripting/OOJSWaypoint.cpp:203` | ✅ |
| `WaypointGetProperty()` (128) | `WaypointGetProperty` `Core/Scripting/OOJSWaypoint.cpp:209` | ✅ |
| `WaypointSetProperty()` (176) | `WaypointSetProperty` `Core/Scripting/OOJSWaypoint.cpp:264` | ✅ |

**Differences:**

- ✅ subtle — The port drops the getter's `entity == nil → undefined` and the setter's `entity == nil → true` branches. Both are unreachable: `JSWaypointGetWaypointEntity` already returns false for nil in both versions (`[nil isKindOfClass:]` is NO; `dynamic_cast` of null) — upstream `:99-100,141-144,190-191` ↔ port `:178-180,225-226,280-281`
- ✅ subtle — The `orientation` getter gives `kZeroQuaternion` when the waypoint is unoriented. The setter calls `Entity::setNormalOrientation` qualified, which still dispatches virtually to the `OOWaypointEntity::setOrientation` override that sets `oriented` (`Core/Entities/Entity.cpp:737-740`, upstream `OOWaypointEntity.m:80-89`). `size` must be `> 0`; a nil `beaconLabel` is reported as a bad value; `beaconCode` follows the same clear/set logic as VisualEffect — upstream `:155-237` ↔ port `:241-331`

## OOJSWorldScripts

<a id="oojsworldscripts"></a>
Upstream `src/Core/Scripting/OOJSWorldScripts.m` ↔ `Core/Scripting/OOJSWorldScripts.cpp`

**Status:** done — 4 rows: 3 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sWorldScriptsClass` JSClass (34) | `sWorldScriptsClass` ClassDef `Core/Scripting/OOJSWorldScripts.cpp:67` (flags None; getProperty + enumerate) | ✅ |
| `InitOOJSWorldScripts()` (48) | `InitOOJSWorldScripts` `Core/Scripting/OOJSWorldScripts.cpp:86` (no prototype; ReadOnly\|Enumerate\|Permanent = OOJS_PROP_READONLY) | ✅ |
| `WorldScriptsGetProperty()` (53) | `WorldScriptsGetProperty` `Core/Scripting/OOJSWorldScripts.cpp:92` | ✅ |
| `WorldScriptsEnumerate()` (84) | `WorldScriptsEnumerate` `Core/Scripting/OOJSWorldScripts.cpp:136` (defines each name with null + the getter, ReadOnly\|Shared\|Permanent\|Enumerate = READONLY_CB) | ⚠️ |

**Differences:**

- ⚠️ **low** — `for (name in worldScripts)` lists scripts in load order, the order `ResourceManager::loadScripts` first saw each name (port comment "in the order each name was first loaded"). Upstream listed `[worldScripts allKeys]`, NSDictionary hash order — upstream `Core/Entities/PlayerEntity.m:11284`, `Core/ResourceManager.m:1860` ↔ port `Core/Entities/PlayerEntity.cpp:11866-11873`, `Core/ResourceManager.cpp:1990-2014`
- ✅ **low** — the getter now scans a `vector<pair<name, script>>` and takes "the last of a name". `loadScripts` replaces a duplicate name in place, so names are unique and the result is what `-objectForKey:` returned. A JS script gives its Script object, another `OOScript` gives null, and an unknown name gives undefined, as upstream did — upstream `Core/Scripting/OOJSWorldScripts.m:65-76` ↔ port `Core/Scripting/OOJSWorldScripts.cpp:109-126`, `Core/ResourceManager.cpp:2010-2014`

## OOJSWormhole

<a id="oojswormhole"></a>
Upstream `src/Core/Scripting/OOJSWormhole.m` ↔ `Core/Scripting/OOJSWormhole.cpp`

**Status:** done — 9 rows: 9 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sWormholeProperties[]` (62): arrivalTime, destination, expiryTime, origin (tinyids 0-3), all READONLY_CB | `sWormholeProperties` `Core/Scripting/OOJSWormhole.cpp:111` (+ `sWormholePropertiesRaw` :124) | ✅ |
| `sWormholeMethods[]` (71): empty | `sWormholeMethods` `Core/Scripting/OOJSWormhole.cpp:135` | ✅ |
| `InitOOJSWormhole()` (77) | `InitOOJSWormhole` `Core/Scripting/OOJSWormhole.cpp:142` | ✅ |
| `JSWormholeGetWormholeEntity()` (84) | `JSWormholeGetWormholeEntity` `Core/Scripting/OOJSWormhole.cpp:151` (`dynamic_cast`; returns false for nil/other as `-isKindOfClass:` did) | ✅ |
| `-[WormholeEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (110) | `OOJSWormholeGetJSClass` `Core/Scripting/OOJSWormhole.cpp:177` | ✅ |
| `-[WormholeEntity(OOJavaScriptExtensions) oo_jsClassName]` (116) | `OOJSWormholeJSClassName` `Core/Scripting/OOJSWormhole.cpp:183` ("Wormhole") | ✅ |
| `-[WormholeEntity(OOJavaScriptExtensions) isVisibleToScripts]` (121) | `OOJSWormholeIsVisibleToScripts` `Core/Scripting/OOJSWormhole.cpp:188` | ✅ |
| `WormholeGetProperty()` (128) | `WormholeGetProperty` `Core/Scripting/OOJSWormhole.cpp:194` | ✅ |
| `WormholeSetProperty()` (169) | `WormholeSetProperty` `Core/Scripting/OOJSWormhole.cpp:240` | ✅ |

**Differences:**

- ✅ subtle — All four getters return numbers: `arrivalTime()`, `getDestination()`, `expiryTime()` and `getOrigin()`. The setter has only the `default:` bad-selector path. The unreachable trailing `OOJSValueFromNativeObject(nil)` became `nullValue()` — upstream `:145-191` ↔ port `:214-266`

## OOJavaScriptEngine

<a id="oojavascriptengine"></a>
Upstream `src/Core/Scripting/OOJavaScriptEngine.m` ↔ `Core/Scripting/OOJavaScriptEngine.cpp`

**Status:** done — 118 rows: 89 ✅ 11 ⚠️ 5 ❌ 13 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `ReportJSError()` (135) | `ReportJSError` `Core/Scripting/OOJavaScriptEngine.cpp:164` ← `invokeReporter` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:844` | ❌ |
| `+[OOJavaScriptEngine sharedEngine]` (237) | `OOJavaScriptEngine::sharedEngine` `Core/Scripting/OOJavaScriptEngine.cpp:266` | ✅ |
| `-[OOJavaScriptEngine runMissionCallback]` (245) | `OOJavaScriptEngine::runMissionCallback` `Core/Scripting/OOJavaScriptEngine.cpp:280` | ✅ |
| `-[OOJavaScriptEngine init]` (250) | `OOJavaScriptEngine::init` `Core/Scripting/OOJavaScriptEngine.cpp:285` | ✅ |
| `-[OOJavaScriptEngine createMainThreadContext]` (291) | `OOJavaScriptEngine::createMainThreadContext` `Core/Scripting/OOJavaScriptEngine.cpp:322` | ❌ |
| `-[OOJavaScriptEngine destroyMainThreadContext]` (378) | `OOJavaScriptEngine::destroyMainThreadContext` `Core/Scripting/OOJavaScriptEngine.cpp:409` | ⚠️ |
| `-[OOJavaScriptEngine reset]` (403) | `OOJavaScriptEngine::reset` `Core/Scripting/OOJavaScriptEngine.cpp:434` | ⚠️ |
| `-[OOJavaScriptEngine dealloc]` (450) | `OOJavaScriptEngine::~OOJavaScriptEngine` `Core/Scripting/OOJavaScriptEngine.cpp:481` (never runs: the shared engine is leaked, amendment oo-r7m0) | ✅ |
| `-[OOJavaScriptEngine globalObject]` (462) | `OOJavaScriptEngine::globalObject` `Core/Scripting/OOJavaScriptEngine.cpp:541` | ✅ |
| `-[OOJavaScriptEngine callJSFunction:]` (467) | `OOJavaScriptEngine::callJSFunction` `Core/Scripting/OOJavaScriptEngine.cpp:546` | ✅ |
| `-[OOJavaScriptEngine removeGCObjectRoot:]` (490) | `OOJavaScriptEngine::removeGCObjectRoot` `Core/Scripting/OOJavaScriptEngine.cpp:565` | ✅ |
| `-[OOJavaScriptEngine removeGCValueRoot:]` (497) | `OOJavaScriptEngine::removeGCValueRoot` `Core/Scripting/OOJavaScriptEngine.cpp:572` | ✅ |
| `-[OOJavaScriptEngine garbageCollectionOpportunity:]` (504) | `OOJavaScriptEngine::garbageCollectionOpportunity` `Core/Scripting/OOJavaScriptEngine.cpp:579` → `gc`/`maybeGC` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3855,3865` | ⚠️ |
| `-[OOJavaScriptEngine showErrorLocations]` (515) | `OOJavaScriptEngine::showErrorLocations` `Core/Scripting/OOJavaScriptEngine.cpp:590` | ✅ |
| `-[OOJavaScriptEngine setShowErrorLocations:]` (520) | `OOJavaScriptEngine::setShowErrorLocations` `Core/Scripting/OOJavaScriptEngine.cpp:595` | ✅ |
| `-[OOJavaScriptEngine objectClass]` (525) | `OOJavaScriptEngine::objectClass` `Core/Scripting/OOJavaScriptEngine.cpp:600` | ✅ |
| `-[OOJavaScriptEngine stringClass]` (530) | `OOJavaScriptEngine::stringClass` `Core/Scripting/OOJavaScriptEngine.cpp:605` | ✅ |
| `-[OOJavaScriptEngine arrayClass]` (535) | `OOJavaScriptEngine::arrayClass` `Core/Scripting/OOJavaScriptEngine.cpp:610` | ✅ |
| `-[OOJavaScriptEngine numberClass]` (540) | `OOJavaScriptEngine::numberClass` `Core/Scripting/OOJavaScriptEngine.cpp:615` | ✅ |
| `-[OOJavaScriptEngine booleanClass]` (545) | `OOJavaScriptEngine::booleanClass` `Core/Scripting/OOJavaScriptEngine.cpp:620` | ✅ |
| `-[OOJavaScriptEngine lookUpStandardClassPointers]` (550) | `OOJavaScriptEngine::lookUpStandardClassPointers` `Core/Scripting/OOJavaScriptEngine.cpp:491` (built-in classes are `getObjectClass`'s stable descriptors) | ✅ |
| `-[OOJavaScriptEngine registerStandardObjectConverters]` (579) | `OOJavaScriptEngine::registerStandardObjectConverters` `Core/Scripting/OOJavaScriptEngine.cpp:532` (+ new `JSPlainObjectConverter` :2202) | ⚠️ |
| `DebuggerHook()` (589) | `DebuggerHook` `Core/Scripting/OOJavaScriptEngine.cpp:628` (never called: `setDebuggerHandler` no-op, `JSEngine_quickjs.cpp:4094`) | ⚠️ |
| `-[OOJavaScriptEngine dumpStackForErrors]` (601) | `OOJavaScriptEngine::dumpStackForErrors` `Core/Scripting/OOJavaScriptEngine.cpp:640` | ✅ |
| `-[OOJavaScriptEngine setDumpStackForErrors:]` (606) | `OOJavaScriptEngine::setDumpStackForErrors` `Core/Scripting/OOJavaScriptEngine.cpp:645` | ✅ |
| `-[OOJavaScriptEngine dumpStackForWarnings]` (611) | `OOJavaScriptEngine::dumpStackForWarnings` `Core/Scripting/OOJavaScriptEngine.cpp:650` | ✅ |
| `-[OOJavaScriptEngine setDumpStackForWarnings:]` (616) | `OOJavaScriptEngine::setDumpStackForWarnings` `Core/Scripting/OOJavaScriptEngine.cpp:655` | ✅ |
| `-[OOJavaScriptEngine enableDebuggerStatement]` (621) | `OOJavaScriptEngine::enableDebuggerStatement` `Core/Scripting/OOJavaScriptEngine.cpp:660` | ⚠️ |
| `-[OOJavaScriptEngine(OOMonitorSupport) setMonitor:]` (633) | `OOJavaScriptEngine::setMonitor` `Core/Scripting/OOJavaScriptEngine.cpp:668` (borrowed pointer, documented at `OOJavaScriptEngine.h:134`) | ✅ |
| `-[OOJavaScriptEngine(OOMonitorSupportInternal) sendMonitorError:]` (643) | `OOJavaScriptEngine::sendMonitorError` `Core/Scripting/OOJavaScriptEngine.cpp:673` | ✅ |
| `-[OOJavaScriptEngine(OOMonitorSupportInternal) sendMonitorLogMessage:]` (652) | `OOJavaScriptEngine::sendMonitorLogMessage` `Core/Scripting/OOJavaScriptEngine.cpp:680` | ✅ |
| `DumpVariable()` (667) | `DumpVariable` `Core/Scripting/OOJavaScriptEngine.cpp:692` | ✅ |
| `OOJSDumpStack()` (694) | `OOJSDumpStack` `Core/Scripting/OOJavaScriptEngine.cpp:730` → frame API `Core/Scripting/ooscript/JSEngine_quickjs.cpp:4045-4091` | ⚠️ |
| `GetLocationNameAndLine()` (804) | `GetLocationNameAndLine` `Core/Scripting/OOJavaScriptEngine.cpp:852` (the `name != NULL` slip is kept) | ✅ |
| `OOJSDescribeLocation()` (823) | `OOJSDescribeLocation` `Core/Scripting/OOJavaScriptEngine.cpp:871` | ✅ |
| `OOJSMarkConsoleEvalLocation()` (851) | `OOJSMarkConsoleEvalLocation` `Core/Scripting/OOJavaScriptEngine.cpp:896` (pointer compare still works: `frameScript` hands out one token per filename) | ✅ |
| `OOJSInitJSIDCachePRIVATE()` (857) | `OOJSInitJSIDCachePRIVATE` `Core/Scripting/OOJavaScriptEngine.cpp:902` | ✅ |
| `OOJSIDFromString()` (873) | `cxx_OOJSIDFromString` `Core/Scripting/OOJavaScriptEngine.cpp:921` | ✅ |
| `OOStringFromJSID()` (906) | `cxx_OOStringFromJSID` `Core/Scripting/OOJavaScriptEngine.cpp:938` | ✅ |
| `CallerPrefix()` (921) | `CallerPrefix` `Core/Scripting/OOJavaScriptEngine.cpp:954` | ✅ |
| `OOJSReportError()` (930) | `cxx_OOJSReportError` `Core/Scripting/OOJavaScriptEngine.cpp:964` | ✅ |
| `OOJSReportErrorForCaller()` (939) | `cxx_OOJSReportErrorForCaller` `Core/Scripting/OOJavaScriptEngine.cpp:973` | ✅ |
| `OOJSReportErrorWithArguments()` (957) | `cxx_OOJSReportErrorWithArguments` `Core/Scripting/OOJavaScriptEngine.cpp:989` → `reportErrorImpl` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:871` | ❌ |
| `OOJSReportWrappedException()` (973) | moved to `OOJSReportCurrentException` `Core/Scripting/OOJSEngineNativeWrappers.cpp:44` (same texts; also catches `std::exception`) | ➖ |
| `OOJSUnreachable()` (986) | `OOJSUnreachable` `Core/Scripting/OOJavaScriptEngine.cpp:1006` | ✅ |
| `OOJSReportWarning()` (994) | `cxx_OOJSReportWarning` `Core/Scripting/OOJavaScriptEngine.cpp:1014` | ✅ |
| `OOJSReportWarningForCaller()` (1003) | `cxx_OOJSReportWarningForCaller` `Core/Scripting/OOJavaScriptEngine.cpp:1023` | ✅ |
| `OOJSReportWarningWithArguments()` (1021) | `cxx_OOJSReportWarningWithArguments` `Core/Scripting/OOJavaScriptEngine.cpp:1039` → `reportWarning` `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3499` | ❌ |
| `OOJSReportBadPropertySelector()` (1035) | `OOJSReportBadPropertySelector` `Core/Scripting/OOJavaScriptEngine.cpp:1050` | ✅ |
| `OOJSReportBadPropertyValue()` (1043) | `OOJSReportBadPropertyValue` `Core/Scripting/OOJavaScriptEngine.cpp:1059` | ✅ |
| `OOJSReportBadArguments()` (1052) | `cxx_OOJSReportBadArguments` `Core/Scripting/OOJavaScriptEngine.cpp:1068` | ✅ |
| `OOJSSetWarningOrErrorStackSkip()` (1068) | `OOJSSetWarningOrErrorStackSkip` `Core/Scripting/OOJavaScriptEngine.cpp:1084` | ✅ |
| `OOJSArgumentListGetNumber()` (1073) | `cxx_OOJSArgumentListGetNumber` `Core/Scripting/OOJavaScriptEngine.cpp:1089` | ✅ |
| `OOJSArgumentListGetNumberNoError()` (1084) | `OOJSArgumentListGetNumberNoError` `Core/Scripting/OOJavaScriptEngine.cpp:1100` (argv padded to nargs with undefined by the trampoline, as SpiderMonkey did) | ✅ |
| `JSArrayFromNSArray()` (1108) | `JSArrayValueFromPList` `Core/Scripting/OOJavaScriptEngine.cpp:1130` | ✅ |
| `JSNewNSArrayValue()` (1147) | `JSArrayValueFromPList` `Core/Scripting/OOJavaScriptEngine.cpp:1130` (`RootedValue` replaces the local root scope) | ✅ |
| `JSObjectFromNSDictionary()` (1179) | `JSObjectValueFromPList` `Core/Scripting/OOJavaScriptEngine.cpp:1172` | ⚠️ |
| `JSNewNSDictionaryValue()` (1249) | `JSObjectValueFromPList` `Core/Scripting/OOJavaScriptEngine.cpp:1172` | ✅ |
| `-[NSObject(OOJavaScriptConversion) oo_jsValueInContext:]` (1279) | — gone with the root's JS glue, bead oo-4aq6a.6.2 (`Core/Scripting/OOJavaScriptEngine.cpp:1124-1126`); `OOJSValueFromPList` Object case `:1270` answers undefined for a node with no glue | ➖ |
| `-[NSObject(OOJavaScriptConversion) oo_jsClassName]` (1284) | — per-class `jsClassName()` (e.g. `OOJSScript.cpp:362`) | ➖ |
| `-[NSObject(OOJavaScriptConversion) oo_jsDescription]` (1289) | — per-class `jsDescription()` (e.g. `OOJSScript.cpp:565`) | ➖ |
| `-[NSObject(OOJavaScriptConversion) oo_jsDescriptionWithClassName:]` (1294) | — folded into `jsDescription()` (same "[%@ %@]" / "[object %@]" forms) | ➖ |
| `-[NSObject(OOJavaScriptConversion) oo_clearJSSelf:]` (1316) | — `clearJSSelf` via `OOJSCxxObjectWrapperFinalize` `Core/Scripting/OOJSPrivateObject.cpp:81` | ➖ |
| `OOJSObjectFromNativeObject()` (1322) | — removed, bead oo-4aq6a.6.2 (`Core/Scripting/OOJavaScriptEngine.cpp:1302`) | ➖ |
| `+[OOJSValue valueWithJSValue:inContext:]` (1333) | `OOJSValue::valueWithJSValue` `Core/Scripting/OOJavaScriptEngine.cpp:1304` | ✅ |
| `+[OOJSValue valueWithJSObject:inContext:]` (1342) | `OOJSValue::valueWithJSObject` `Core/Scripting/OOJavaScriptEngine.cpp:1315` | ✅ |
| `-[OOJSValue initWithJSValue:inContext:]` (1351) | `OOJSValue::initWithJSValue` `Core/Scripting/OOJavaScriptEngine.cpp:1326` | ✅ |
| `-[OOJSValue initWithJSObject:inContext:]` (1381) | `OOJSValue::initWithJSObject` `Core/Scripting/OOJavaScriptEngine.cpp:1356` | ✅ |
| `-[OOJSValue deleteJSValue]` (1386) | `OOJSValue::deleteJSValue` `Core/Scripting/OOJavaScriptEngine.cpp:1361` | ✅ |
| `-[OOJSValue dealloc]` (1400) | `OOJSValue::~OOJSValue` `Core/Scripting/OOJavaScriptEngine.cpp:1374` | ✅ |
| `-[OOJSValue oo_jsValueInContext:]` (1406) | `OOJSValue::jsValueInContext` `Core/Scripting/OOJavaScriptEngine.cpp:1379` | ✅ |
| `OOJSStrLiteralCachePRIVATE()` (1413) | `OOJSStrLiteralCachePRIVATE` `Core/Scripting/OOJavaScriptEngine.cpp:1394` (upstream's `string == NULL` test slip kept) | ✅ |
| `OOStringFromJSString()` (1430) | `cxx_OOStringFromJSString` `Core/Scripting/OOJavaScriptEngine.cpp:1411` | ✅ |
| `OOStringFromJSValueEvenIfNull()` (1449) | `cxx_OOStringFromJSValueEvenIfNull` `Core/Scripting/OOJavaScriptEngine.cpp:1430` → `valueToString` `JSEngine_quickjs.cpp:2475` | ✅ |
| `OOStringFromJSValue()` (1461) | `cxx_OOStringFromJSValue` `Core/Scripting/OOJavaScriptEngine.cpp:1442` | ✅ |
| `OOStringFromJSPropertyIDAndSpec()` (1473) | `cxx_OOStringFromJSPropertyIDAndSpec` `Core/Scripting/OOJavaScriptEngine.cpp:1454` | ✅ |
| `DescribeValue()` (1493) | `DescribeValue` `Core/Scripting/OOJavaScriptEngine.cpp:1475` | ✅ |
| `OOJSDescribeValue()` (1578) | `cxx_OOJSDescribeValue` `Core/Scripting/OOJavaScriptEngine.cpp:1564` | ✅ |
| `+[NSString(OOJavaScriptExtensions) stringWithJavaScriptParameters:count:inContext:]` (1585) | `cxx_OOJSStringWithJavaScriptParameters` `Core/Scripting/OOJavaScriptEngine.cpp:1569` | ✅ |
| `-[NSString(OOJavaScriptExtensions) oo_jsValueInContext:]` (1607) | `OOJSValueFromPList` String case `Core/Scripting/OOJavaScriptEngine.cpp:1252` | ✅ |
| `+[NSString(OOJavaScriptExtensions) concatenationOfStringsFromJavaScriptValues:count:separator:inContext:]` (1634) | `cxx_OOJSConcatenationOfStringsFromJavaScriptValues` `Core/Scripting/OOJavaScriptEngine.cpp:1591` | ❌ |
| `-[NSString(OOJavaScriptExtensions) escapedForJavaScriptLiteral]` (1663) | `cxx_OOJSEscapedForJavaScriptLiteral` `Core/Scripting/OOJavaScriptEngine.cpp:1619` (byte-wise over UTF-8; every escape is ASCII) | ✅ |
| `-[NSString(OOJavaScriptExtensions) oo_jsClassName]` (1726) | — no Foundation strings remain | ➖ |
| `-[NSArray(OOJavaScriptConversion) oo_jsValueInContext:]` (1735) | `OOJSValueFromPList` Array case `Core/Scripting/OOJavaScriptEngine.cpp:1264` | ✅ |
| `-[OONativeVector(OOJavaScriptConversion) oo_jsValueInContext:]` (1746) | `OONativeVectorJSValueInContext` `Core/Scripting/OOJavaScriptEngine.cpp:1673` | ✅ |
| `-[NSDictionary(OOJavaScriptConversion) oo_jsValueInContext:]` (1757) | `OOJSValueFromPList` Dict case `Core/Scripting/OOJavaScriptEngine.cpp:1267` | ⚠️ |
| `-[NSNumber(OOJavaScriptConversion) oo_jsValueInContext:]` (1768) | `OOJSValueFromPList` Bool/Integer/Real cases `Core/Scripting/OOJavaScriptEngine.cpp:1227-1250` | ✅ |
| `-[NSNumber(OOJavaScriptConversion) oo_jsClassName]` (1797) | — no Foundation numbers remain | ➖ |
| `-[NSNull(OOJavaScriptConversion) oo_jsValueInContext:]` (1806) | `OONull::jsValueInContext` `Core/Scripting/OOJavaScriptEngine.cpp:1700` | ✅ |
| `OOJSUnconstructableConstruct()` (1813) | `OOJSUnconstructableConstruct` `Core/Scripting/OOJavaScriptEngine.cpp:1705` | ✅ |
| `OOJSObjectWrapperFinalize()` (1826) | `OOJSObjectWrapperFinalize` `Core/Scripting/OOJavaScriptEngine.cpp:1721` → `OOJSCxxObjectWrapperFinalize` `Core/Scripting/OOJSPrivateObject.cpp:81` | ✅ |
| `OOJSObjectWrapperToString()` (1840) | `OOJSObjectWrapperToString` `Core/Scripting/OOJavaScriptEngine.cpp:1729` | ⚠️ |
| `JSFunctionPredicate()` (1868) | `JSFunctionPredicate` `Core/Scripting/OOJavaScriptEngine.cpp:1748` | ✅ |
| `JSEntityIsJavaScriptVisiblePredicate()` (1908) | `JSEntityIsJavaScriptVisiblePredicate` `Core/Scripting/OOJavaScriptEngine.cpp:1825` | ✅ |
| `JSEntityIsJavaScriptSearchablePredicate()` (1917) | `JSEntityIsJavaScriptSearchablePredicate` `Core/Scripting/OOJavaScriptEngine.cpp:1834` (the `STELLAR_TYPE_ATMOSPHERE` case was `!NEW_PLANETS` only) | ✅ |
| `JSEntityIsDemoShipPredicate()` (1949) | `JSEntityIsDemoShipPredicate` `Core/Scripting/OOJavaScriptEngine.cpp:1864` | ✅ |
| `OOJSRegisterSubclass()` (1956) | `OOJSRegisterSubclass` `Core/Scripting/OOJavaScriptEngine.cpp:1874` | ✅ |
| `UnregisterSubclasses()` (1969) | `UnregisterSubclasses` `Core/Scripting/OOJavaScriptEngine.cpp:1888` | ✅ |
| `OOJSIsSubclass()` (1975) | `OOJSIsSubclass` `Core/Scripting/OOJavaScriptEngine.cpp:1895` | ✅ |
| `OOJSDictionaryFromJSValue()` (2039) | `OOJSDictionaryFromJSValue` `Core/Scripting/OOJavaScriptEngine.cpp:1911` | ✅ |
| `OOJSDictionaryFromJSObject()` (2052) | `cxx_OOJSDictionaryFromJSObject` `Core/Scripting/OOJavaScriptEngine.cpp:1924` | ⚠️ |
| `OOJSDictionaryFromStringTable()` (2103) | `OOJSDictionaryFromStringTable` `Core/Scripting/OOJavaScriptEngine.cpp:1970` | ✅ |
| `OOJSNativeObjectFromJSValue()` (2155) | `cxx_OOJSPListFromJSValue` `Core/Scripting/OOJavaScriptEngine.cpp:2024` | ✅ |
| `OOJSNativeObjectFromJSObject()` (2182) | `cxx_OOJSPListFromJSObject` `Core/Scripting/OOJavaScriptEngine.cpp:2059` | ✅ |
| `OOJSNativeObjectOfClassFromJSValue()` (2207) | — deleted, bead oo-4aq6a.6 (`Core/Scripting/OOJSEngineCore.h:221-226`) | ➖ |
| `OOJSNativeObjectOfClassFromJSObject()` (2215) | — deleted, bead oo-4aq6a.6 | ➖ |
| `OOJSBasicPrivateObjectConverter()` (2223) | `OOJSBasicPrivateObjectConverter` `Core/Scripting/OOJavaScriptEngine.cpp:2086` (a node of the slot's `PListForeign`, else null) | ✅ |
| `OOJSRegisterObjectConverter()` (2235) | `OOJSRegisterObjectConverter` `Core/Scripting/OOJavaScriptEngine.cpp:2094` | ✅ |
| `UnregisterObjectConverters()` (2254) | `UnregisterObjectConverters` `Core/Scripting/OOJavaScriptEngine.cpp:2109` | ✅ |
| `JSArrayConverter()` (2259) | `JSArrayConverter`/`PListFromJSArray` `Core/Scripting/OOJavaScriptEngine.cpp:2117,2145` | ✅ |
| `JSStringConverter()` (2296) | `JSStringConverter` `Core/Scripting/OOJavaScriptEngine.cpp:2158` | ✅ |
| `JSNumberConverter()` (2301) | `JSNumberConverter` `Core/Scripting/OOJavaScriptEngine.cpp:2174` | ✅ |
| `JSBooleanConverter()` (2310) | `JSBooleanConverter` `Core/Scripting/OOJavaScriptEngine.cpp:2195` | ✅ |
| `OOJSObjectGetterImplPRIVATE()` (1990) *(added)* | replaced by the C++ slot getter `Core/Scripting/OOJSPrivateObject.cpp:58` (same class check and error text) | ➖ |
| `OOJSAcquireContext()` / `OOJSRelinquishContext()` (`.h` 116/125) *(added)* | `Core/Scripting/OOJSEngineCore.h:55,64` (requests are bookkeeping on QuickJS-ng) | ✅ |
| `OOJSValueFromNativeObject()` (`.h` 229) *(added)* | replaced by `OOJSValueFromPList` `Core/Scripting/OOJavaScriptEngine.cpp:1219` | ➖ |
| `OOJSGetClass()` (`.h` 346) *(added)* | `OOJSGetClass` → `getObjectClass` `Core/Scripting/OOJSEngineCore.h:234` | ✅ |
| `OOJSValueIsFunction()` / `OOJSValueIsArray()` (`.h` 361/374) *(added)* | `Core/Scripting/OOJSEngineCore.h:245,257` | ✅ |

**Differences:**

- ❌ **med** — Every reported error, warning and exception now has `errorNumber` 0, so the log message class is always `script.javaScript.<severity>.notAnError`. The cause: `invokeReporter` defaults `errorNumber = 0` and none of its four callers passes another value, and `javascript-errors.plist` maps `"0"` to `notAnError`. Upstream classes carried the SpiderMonkey message number:
  - `OOJSReportError`/`OOJSReportWarning` → `…ooliteDefined` (206, `JSMSG_USER_DEFINED_ERROR`, SpiderMonkey `jscntxt.cpp:1439`).
  - Engine errors keep their own name: `…notDefined` (1), `…notFunction` (22), `…undefinedProp` (162), `…unexpectedType` (222).
  - A thrown non-Error → `…uncaughtException` (147).
  - The class appears in every log line and in log filtering. — upstream `Core/Scripting/OOJavaScriptEngine.m:179-186` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:213-218`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:844-857,878,936,3507`
- Subtle — A thrown non-Error value (`throw "x"`) is reported with `ReportFlag::Exception`, so the log reads "JavaScript exception" with message "uncaught exception: x". SpiderMonkey reported it through `JS_ReportErrorNumber(JSMSG_UNCAUGHT_EXCEPTION)`, whose `ReportError` sets `JSREPORT_EXCEPTION` for that number, so severity matches; only the class differs (see above). For Error objects thrown by user code SpiderMonkey zeroed the report (errorNumber 0, i.e. `notAnError`), which matches the port. — SpiderMonkey `jsexn.cpp:1250-1290` ↔ port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:904-938`
- ❌ **low** — The source line is never shown. The QuickJS backend always passes `linebuf = nullptr`, so the location line for compile errors becomes "      file, line N." where upstream printed "      file, line N: <offending source line>". — upstream `Core/Scripting/OOJavaScriptEngine.m:174-176,202-206` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:207-210,233-237`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:856`
- ❌ **med** — Message texts that reach the log are QuickJS-ng's, not SpiderMonkey 1.8.5's. For example `foo.bar` on undefined gives SpiderMonkey "TypeError: foo is undefined" and QuickJS-ng "cannot read property 'bar' of undefined", and syntax-error wording differs throughout. The façade's own replacements of SpiderMonkey's decompiler-based messages use `ToString(value)` instead of the source expression: `valueToFunction` "X is not a function" and `valueToInt32` "can't convert X to an integer". Locations come from parsing `Error.stack` (`errorLocation`/`parseLocation`), so they are the construction point of the Error, as before. — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:758-829,2435-2458,2486-2500`
- ❌ **med** — `createMainThreadContext`: `setOptions` (VAROBJFIX/RELIMIT/ANONFUNFIX/JIT) and `setVersion(ECMA5)` are only stored, and QuickJS-ng parses ES2023. SpiderMonkey 1.8.5 language extensions that OXPs may use no longer compile or exist: `for each (… in …)`, expression closures, `toSource`/`uneval`, Array/String generics (`Array.forEach(a, f)`), `watch`/`unwatch`, `__iterator__`, E4X. Legacy `const`, block-level function statements and `Function.prototype.toString` (decompiled vs original text) behave differently. Not recorded among the backend's DIVERGENCE notes. No built-in script uses the extensions (grep of upstream `Resources/Scripts`, `DebugOXP`); impact is on expansions. — upstream `Core/Scripting/OOJavaScriptEngine.m:80-86,306-307` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:113-119,337-338`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3767-3795`
- ⚠️ **low** — `createMainThreadContext`: the GC zeal block is reached only when `gcZealSupported()`, which is always false (upstream compiled it only under `JS_GC_ZEAL`). The `js-gc-zeal` default is ignored. — port `Core/Scripting/OOJavaScriptEngine.cpp:340-348`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3874-3875`
- ⚠️ **low** — `destroyMainThreadContext`'s `clearScope` leaves non-configurable (permanent) properties in place, where SpiderMonkey's ClearScope emptied the scope (backend DIVERGENCE). The QuickJS-ng global is also the context's fixed global, not a fresh object of Oolite's global class (banner DIVERGENCE). The context is destroyed straight after, so no observable effect is expected. — port `Core/Scripting/OOJavaScriptEngine.cpp:413`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:110-113,2649-2652`
- ⚠️ **low** — `reset`: upstream built SpiderMonkey with `JS_THREADSAFE` on Mac/Linux debug builds (`Doc/SpidermonkeyChanges.txt:7`). In those builds it refused a reset made inside a request (`script.javascript.init.error`) and logged `script.javascript.init` "JavaScript reset successful." on every reset. `isThreadsafeBuild()` is always false on QuickJS-ng, so the port behaves like an upstream release build: no check and no log line. — upstream `Core/Scripting/OOJavaScriptEngine.m:423-433` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:454-464`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3763`
- ⚠️ **low** — `garbageCollectionOpportunity` (GC rooting vs refcounting):
  - `gc()`/`maybeGC()` release the façade's handle arena (re-referencing every registered root address first). `gc()` then runs QuickJS-ng's cycle collector; `maybeGC()` does not and leaves cycles to QuickJS-ng's allocation-driven GC.
  - The flush is allowed at request depth ≤ 1 (backend DIVERGENCE), so a caller holding an unrooted `Value` across `gc()` inside its own request is exposed.
  - Acyclic garbage is freed immediately and finalizers (e.g. `OOJSCxxObjectWrapperFinalize`) run at different times than under SpiderMonkey's lazy GC.
  - `JS_SetMemoryLimit(256 MiB)` counts all engine allocations (bytecode, strings, shapes), whereas `JS_NewRuntime(maxbytes)` capped the GC heap only.
  - — port `Core/Scripting/OOJavaScriptEngine.cpp:579-588`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:22-38,706-715,3609-3620,3855-3871`
- ⚠️ **low** — `registerStandardObjectConverters` / `OOJSDictionaryFromJSObject`: integer-like JS keys become decimal-string keys. Upstream made `NSNumber` keys that native code could not look up (proposed ADR-0051, comment at :1945-1949). Result dictionaries are `std::map` (sorted), not NSDictionary hash order. — upstream `Core/Scripting/OOJavaScriptEngine.m:2074-2080` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1944-1951,2202-2205`
- ⚠️ **low** — `JSObjectFromNSDictionary` / NSDictionary → JS: properties are now set in sorted key order, not NSDictionary hash order (the port comment says "key order"), which changes `for…in`/`Object.keys`/`JSON.stringify` order of objects built from plists. Separately, QuickJS-ng enumerates integer-like keys first and in ascending order (ES2015 OrdinaryOwnPropertyKeys), where SpiderMonkey 1.8.5 used insertion order for non-array objects. Upstream's `NSNumber`-key branch (`0 < index` → `JS_SetElement`) has no counterpart, because PList keys are strings. — upstream `Core/Scripting/OOJavaScriptEngine.m:1195-1229` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1185-1195`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3094-3110`
- ⚠️ **low** — Debugger and stack dumps (ADR-0022: the backend answers with less):
  - `enableDebuggerStatement` installs a handler QuickJS-ng never calls, so a JS `debugger;` statement no longer logs `script.javaScript.debugger` "debugger invoked during …" or dumps the stack.
  - `OOJSDumpStack` gets a snapshot of `new Error().stack`: file/line only, `frameFunction` null (every frame prints "<not a function frame>" instead of `name()`/`new name()`), and no `this`, arguments or locals.
  - — port `Core/Scripting/OOJavaScriptEngine.cpp:628-663,730-842`, `Core/Scripting/ooscript/JSEngine_quickjs.cpp:3990-4095`
- ⚠️ **low** — `OOJSObjectWrapperToString` no longer asks the native object for `oo_jsDescription`/`description` and always answers "[object <JSClass>]". Classes whose slot holds a C++ object describe themselves through `OOJSCxxObjectWrapperToString` (`Core/Scripting/OOJSPrivateObject.cpp:97`) or their own `toString` (e.g. `ScriptToString`). This wrapper remains only the fallback for a foreign `this` (bead oo-4aq6a.6, comment at :1726-1728). — upstream `Core/Scripting/OOJavaScriptEngine.m:1848-1853` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1729-1746`
- ❌ **low** — `concatenationOfStringsFromJavaScriptValues`: when an element after the first fails `ToString`, upstream `appendString:nil` raised an `NSInvalidArgumentException`, which the native wrapper reported as "Native exception: …". The port appends the separator and skips the element. A failing first element is skipped in both. — upstream `Core/Scripting/OOJavaScriptEngine.m:1647-1656` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1603-1612`
- **low** (value conversions behind the façade):
  - `valueToInt32` (non-ECMA `JS_ValueToInt32`) errors on `d > 2147483647.0 || d < -2147483648.0`. SpiderMonkey errored only on `d <= -2147483649.0 || d >= 2147483648.0` and rounded with `floor(d + 0.5)`, so values in (2147483647, 2147483648) and (-2147483649, -2147483648) now fail.
  - `ToNumber` of strings follows ES2015+ (e.g. `"0b101"`, `"0o17"` convert; NaN in 1.8.5).
  - Unchanged: `ToBoolean`, `ToECMAInt32`/`Uint32`, `ToObject(null/undefined)` → null without error, `ToString` of numbers, and `numberValue`'s int32 canonicalisation (−0 stays double, NaN canonicalised).
  - — SpiderMonkey `jsnum.cpp:1360-1365` ↔ port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:204-221,2400-2483`
- Subtle — Warnings: `reportWarning` never becomes an exception and takes its filename/line from a fresh `Error().stack` when a script is running, otherwise none, so the second log line is suppressed as in SpiderMonkey's `PopulateReportBlame`. `reportError` throws an `Error(message)` while a script frame is active and calls the reporter directly otherwise, matching SpiderMonkey's `ReportError` → `js_ErrorToException` split. "Script running" is approximated by probing up to 16 stack levels with `JS_GetScriptOrModuleName`. — port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:719-731,871-879,3499-3509`
- Subtle — `ReportJSError` itself (severity words, highlight `*****`/`-----`, "<unidentified script>", the `showLocation && stackSkip == 0 && filename` gate, the monitor call bracketed by save/restore of the exception state, the pause/resume of the time limiter) is line-for-line equivalent; the differences above all come from the report the backend builds. ✅ — port `Core/Scripting/OOJavaScriptEngine.cpp:164-259`
- Subtle — `OOJSValueFromPList` reproduces `NSNumber -oo_jsValueInContext:`: bool → int32 1/0, integers in int32 range → int32, else double via `numberValue` (which canonicalises integral doubles back to int32, as `JS_NewNumberValue` did), and single-precision reals widened from `float`. An empty string → `emptyStringValue`; data and date → undefined (the root class's glue). ✅ — port `Core/Scripting/OOJavaScriptEngine.cpp:1219-1300`

## OOLegacyScriptWhitelist

<a id="oolegacyscriptwhitelist"></a>
Upstream `src/Core/Scripting/OOLegacyScriptWhitelist.m` ↔ `Core/Scripting/OOLegacyScriptWhitelist.cpp`

**Status:** done — 16 rows: 14 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| *(added)* `Resources/Config/whitelist.plist` (all 12 tables: `action_methods`, `ai_methods`, `ai_and_action_methods`, `query_methods`, `*_aliases`, …) and `+[ResourceManager whitelistDictionary]` | same file, byte-identical (diffed); `ResourceManager::whitelistDictionary` ResourceManager.cpp:1641 (loaded once, missing cached) | ✅ |
| `OOSanitizeLegacyScript()` (58) | `OOSanitizeLegacyScript` OOLegacyScriptWhitelist.cpp:66 | ✅ |
| `OOSanitizeLegacyScriptInternal()` (65) | `OOSanitizeLegacyScriptInternal` OOLegacyScriptWhitelist.cpp:73 | ❌ |
| `OOSanitizeLegacyScriptConditions()` (101) | `OOSanitizeLegacyScriptConditions` OOLegacyScriptWhitelist.cpp:107 | ✅ |
| `OOSanitizeLegacyScriptConditionsInternal()` (110) | `OOSanitizeLegacyScriptConditionsInternal` OOLegacyScriptWhitelist.cpp:114 | ❌ |
| `OOLegacyConditionsAreSanitized()` (149) | `OOLegacyConditionsAreSanitized` OOLegacyScriptWhitelist.cpp:155 | ✅ |
| `SanitizeCondition()` (156) | `SanitizeCondition` OOLegacyScriptWhitelist.cpp:164 | ✅ |
| `SanitizeConditionalStatement()` (290) | `SanitizeConditionalStatement` OOLegacyScriptWhitelist.cpp:292 | ✅ |
| `SanitizeActionStatement()` (336) | `SanitizeActionStatement` OOLegacyScriptWhitelist.cpp:346 | ✅ |
| `ClassifyLHSConditionSelector()` (375) | `ClassifyLHSConditionSelector` OOLegacyScriptWhitelist.cpp:397 (unused `stack` param dropped) | ✅ |
| `SanitizeQueryMethod()` (406) | `SanitizeQueryMethod` OOLegacyScriptWhitelist.cpp:467 (+ `WhitelistSet` :433, `WhitelistDictionary` :449, `AliasFor` :456) | ✅ |
| `SanitizeActionMethod()` (427) | `SanitizeActionMethod` OOLegacyScriptWhitelist.cpp:486 | ✅ |
| `AlwaysFalseConditions()` (476) | `AlwaysFalseConditions` OOLegacyScriptWhitelist.cpp:539 (upstream inverted-cache bug kept: always returns null) | ✅ |
| `IsAlwaysFalseConditions()` (487) | `IsAlwaysFalseConditions` OOLegacyScriptWhitelist.cpp:555 | ✅ |
| `StringFromStackInternal()` (492) | `StringFromStackInternal` OOLegacyScriptWhitelist.cpp:565 | ✅ |
| `StringFromStack()` (512) | `StringFromStack` OOLegacyScriptWhitelist.cpp:583 | ✅ |

**Differences:**

- ❌ **low** — `script.syntax.statement.invalidType` names the offending statement's type with the PList type name (`integer`, `array`, `bool` …) instead of its Objective-C class (`[statement class]`, e.g. `GSMutableArray`). The log text differs for malformed scripts only — upstream `OOLegacyScriptWhitelist.m:86` ↔ port `OOLegacyScriptWhitelist.cpp:93`
- ❌ **low** — `script.syntax.condition.notString` has the same class-name→type-name change in its log text — upstream `OOLegacyScriptWhitelist.m:129` ↔ port `OOLegacyScriptWhitelist.cpp:133`
- ✅ note (whitelist tables, entry by entry) — `whitelist.plist` is byte-identical. The sets are built the same way:
  - query = `query_methods`.
  - action = `action_methods` ∪ `ai_and_action_methods`.
  - action+AI = `ai_methods` ∪ action.
  - AI aliases = `ai_method_aliases` overlaid by `action_method_aliases` (action wins, as `dictionaryByAddingEntriesFromDictionary:`).

  Aliases are resolved before the membership test, and LHS type is classified by the suffix of the un-aliased selector. Both sides cache the tables for the life of the process — upstream `:406-473` ↔ port `:467-534`
- ✅ note — `AlwaysFalseConditions()` returns nil/null on both sides because of the upstream `!= nil` bug, so a conditions array that fails sanitising drops its whole conditional statement. This is kept on purpose (port comment :541-544, proposed ADR-0043). The comparator table (`morethan`→GREATERTHAN), the rejection of OP_NUMBER+`undefined` and OP_BOOL with anything but equal/notequal, the RHS coalescing, the join and `[credits_number]` rewrite of action arguments, and the 2-element array for actions with no argument all match.

## OOPListScript

<a id="ooplistscript"></a>
Upstream `src/Core/Scripting/OOPListScript.m` ↔ `Core/Scripting/OOPListScript.cpp`

**Status:** done — 10 rows: 4 ✅ 4 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOPListScript scriptsInPListFile:]` (50) | `OOPListScript::scriptsInPListFile()` `Core/Scripting/OOPListScript.cpp:49` | ⚠️ |
| `-[OOPListScript dealloc]` (63) | — (implicit: `_script`/`_metadata` are `oo::PList` members) | ➖ |
| `-[OOPListScript name]` (71) | `OOPListScript::name()` `Core/Scripting/OOPListScript.cpp:65` | ✅ |
| `-[OOPListScript scriptDescription]` (76) | `OOPListScript::scriptDescription()` `Core/Scripting/OOPListScript.cpp:73` | ⚠️ |
| `-[OOPListScript version]` (81) | `OOPListScript::version()` `Core/Scripting/OOPListScript.cpp:84` | ❌ |
| `-[OOPListScript requiresTickle]` (86) | `OOPListScript::requiresTickle()` `Core/Scripting/OOPListScript.cpp:94` | ✅ |
| `-[OOPListScript runWithTarget:]` (91) | `OOPListScript::runWithTarget()` `Core/Scripting/OOPListScript.cpp:99` | ✅ |
| `+[OOPListScript(SetUp) scriptsFromDictionaryOfScripts:filePath:]` (112) | `OOPListScript::scriptsFromDictionaryOfScripts()` `Core/Scripting/OOPListScript.cpp:115` | ⚠️ |
| `+[OOPListScript(SetUp) loadCachedScripts:]` (152) | `OOPListScript::loadCachedScripts()` `Core/Scripting/OOPListScript.cpp:153` | ⚠️ |
| `-[OOPListScript(SetUp) initWithName:scriptArray:metadata:]` (173) | ctor `OOPListScript::OOPListScript()` `Core/Scripting/OOPListScript.cpp:174` | ✅ |

**Differences:**

- ⚠️ **med** — The scripts in one plist now come out in sorted key order (`oo::PList::Dict` is a `std::map`), not NSDictionary hash order. This changes the order of world scripts from a `script.plist`, and with it their tickle/run order and log order. Stated in the port comments at OOPListScript.cpp:125 and :162. — upstream `Core/Scripting/OOPListScript.m:129,158` ↔ port `Core/Scripting/OOPListScript.cpp:126,163`
- ❌ **low** — A non-string metadata `version` is dropped. Upstream `-version` returned any object and `-displayName` formatted it with `%@`, so an XML `<real>1.2</real>` gave "name 1.2". The port returns nullopt, so `script.legacy.run` and every other `displayName` user print just "name". The port comment's "-length" rationale does not match upstream `displayName`. — upstream `Core/Scripting/OOPListScript.m:81-84`, `Core/Scripting/OOScript.m:253-254` ↔ port `Core/Scripting/OOPListScript.cpp:84-92`
- ⚠️ **low** — A non-string `description` → nullopt. The comment cites bead oo-3rb.266: nothing calls it. — port `Core/Scripting/OOPListScript.cpp:73-82`
- ⚠️ **low** — A `script.plist` that is not a dictionary no longer logs `plist.wrongType` ("Property list is wrong type - expected NSDictionary…"); the port comment at :58 says so. — upstream `Core/OOPListParsing.m:226-232` ↔ port `Core/Scripting/OOPListScript.cpp:56-60`
- Subtle, ✅:
  - Metadata keys (`name`, `description`, `version`, `!metadata!`, `script`) and the cache name "sanitized legacy scripts" match.
  - A cache entry leaves out metadata when it is nil, as `dictionaryWithObjectsAndKeys:` did.
  - Sanitization goes through `OOSanitizeLegacyScript(…, key, false)`.
  - The `script.legacy.run.badTarget` and `script.legacy.run` log classes and texts match.
  - A missing `PLAYER` is guarded where upstream relied on a nil message.
  - A cached entry with no script array gets an empty `PList` where upstream had a nil array.
  - — port `Core/Scripting/OOPListScript.cpp:32-38,99-113,137-141,167`

## OOScript

<a id="ooscript"></a>
Upstream `src/Core/Scripting/OOScript.m` ↔ `Core/Scripting/OOScript.cpp`

**Status:** done — 13 rows: 12 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOScript worldScriptsAtPath:]` (43) | `OOScript::worldScriptsAtPath()` `Core/Scripting/OOScript.cpp:76` | ⚠️ |
| `+[OOScript scriptsFromFileNamed:]` (117) | `OOScript::scriptsFromFileNamed()` `Core/Scripting/OOScript.cpp:146` | ✅ |
| `+[OOScript scriptsFromList:]` (132) | `OOScript::scriptsFromList()` `Core/Scripting/OOScript.cpp:161` | ✅ |
| `+[OOScript scriptsFromFileAtPath:]` (149) | `OOScript::scriptsFromFileAtPath()` `Core/Scripting/OOScript.cpp:176` | ✅ |
| `+[OOScript jsScriptFromFileNamed:properties:]` (175) | `OOScript::jsScriptFromFileNamed()` `Core/Scripting/OOScript.cpp:202` | ✅ |
| `+[OOScript jsAIScriptFromFileNamed:properties:]` (200) | `OOScript::jsAIScriptFromFileNamed()` `Core/Scripting/OOScript.cpp:227` | ✅ |
| `-[OOScript descriptionComponents]` (225) | `OOScript::descriptionComponents()` `Core/Scripting/OOScript.cpp:252` | ✅ |
| `-[OOScript name]` (230) | `OOScript::name()` `Core/Scripting/OOScript.cpp:257` | ✅ |
| `-[OOScript scriptDescription]` (236) | `OOScript::scriptDescription()` `Core/Scripting/OOScript.cpp:263` | ✅ |
| `-[OOScript version]` (242) | `OOScript::version()` `Core/Scripting/OOScript.cpp:269` | ✅ |
| `-[OOScript displayName]` (248) | `OOScript::displayName()` `Core/Scripting/OOScript.cpp:275` | ✅ |
| `-[OOScript requiresTickle]` (261) | `OOScript::requiresTickle()` `Core/Scripting/OOScript.cpp:286` | ✅ |
| `-[OOScript runWithTarget:]` (266) | `OOScript::runWithTarget()` `Core/Scripting/OOScript.cpp:291` | ✅ |

**Differences:**

- ⚠️ **low** — `world-scripts.plist` is read through `StringsFromArrayFile`. A file that is not an array no longer logs `plist.wrongType` (stated in the comment at OOScript.cpp:45-47). Non-string entries are skipped silently, where upstream passed them to `scriptsFromFileNamed:`, which logs "Could not find script file …" or raises. — upstream `Core/Scripting/OOScript.m:57`, `Core/OOPListParsing.m:219-232` ↔ port `Core/Scripting/OOScript.cpp:48-60,86`
- Subtle, ✅:
  - Load order is the same: `world-scripts.plist`, then `script.js`, then `script.es`, then `script.plist`, with plist scripts skipped when standards are enforced.
  - Log classes (`script.load.javaScript`, `.pList`, `.parseOK`, `.parseError`, `.none`, `.notFound`, `.badName`), their texts and the indent/outdent match.
  - An empty `scriptsFromList` result stops the search, as before.
  - `displayName`/`descriptionComponents` print "(null)" exactly where `%@` printed nil.
  - — port `Core/Scripting/OOScript.cpp:83-143,252-284`
- Note: the port adds `callMethod` (always false), `className`, `description`, `jsValueInContext` and `clearJSSelf` from the deleted facade (`Core/Scripting/OOScript.cpp:297-329`). `callMethod` is upstream's `-[OOScript(JavaScriptEvents) callMethod:]` (`OOJSScript.m:603`), audited in the OOJSScript section.

## OOScriptTimer

<a id="ooscripttimer"></a>
Upstream `src/Core/Scripting/OOScriptTimer.m` ↔ `Core/Scripting/OOScriptTimer.cpp`

**Status:** done — 18 rows: 18 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| statics `sTimers`/`sUpdating`/`sDeferredTimers` (31–35) | same names `Core/Scripting/OOScriptTimer.cpp:41-45` (+ comparator adapter `CompareByNextFireTime` `:35`) | ✅ |
| `-[OOScriptTimer initWithNextTime:]` (39) | `OOScriptTimer::initWithNextTime` `Core/Scripting/OOScriptTimer.cpp:65` (+ factory `timerWithNextTime` `:49`) | ✅ |
| `-[OOScriptTimer initOneShotTimerWithDelay:]` (66) | `OOScriptTimer::initOneShotTimerWithDelay` `Core/Scripting/OOScriptTimer.cpp:90` (+ factory `:57`) | ✅ |
| `-[OOScriptTimer dealloc]` (71) | `OOScriptTimer::~OOScriptTimer` `Core/Scripting/OOScriptTimer.cpp:95` | ✅ |
| (inherited) `-description` | `OOScriptTimer::description` / `descriptionWithComponents` `Core/Scripting/OOScriptTimer.cpp:101`, `:108` (`<Class 0x…>{components}`) | ✅ |
| `-[OOScriptTimer descriptionComponents]` (79) | `OOScriptTimer::descriptionComponents` `Core/Scripting/OOScriptTimer.cpp:116` | ✅ |
| `-[OOScriptTimer nextTime]` (91) | `OOScriptTimer::nextTime` `Core/Scripting/OOScriptTimer.cpp:128` | ✅ |
| `-[OOScriptTimer setNextTime:]` (96) | `OOScriptTimer::setNextTime` `Core/Scripting/OOScriptTimer.cpp:133` | ✅ |
| `-[OOScriptTimer interval]` (105) | `OOScriptTimer::interval` `Core/Scripting/OOScriptTimer.cpp:142` | ✅ |
| `-[OOScriptTimer setInterval:]` (110) | `OOScriptTimer::setInterval` `Core/Scripting/OOScriptTimer.cpp:147` | ✅ |
| `-[OOScriptTimer timerFired]` (117) | `OOScriptTimer::timerFired` `Core/Scripting/OOScriptTimer.cpp:154` | ✅ |
| `-[OOScriptTimer scheduleTimer]` (122) | `OOScriptTimer::scheduleTimer` `Core/Scripting/OOScriptTimer.cpp:159` | ✅ |
| `-[OOScriptTimer unscheduleTimer]` (143) | `OOScriptTimer::unscheduleTimer` `Core/Scripting/OOScriptTimer.cpp:180` | ✅ |
| `-[OOScriptTimer isScheduled]` (150) | `OOScriptTimer::isScheduled` `Core/Scripting/OOScriptTimer.cpp:190` | ✅ |
| `+[OOScriptTimer updateTimers]` (155) | `OOScriptTimer::updateTimers` `Core/Scripting/OOScriptTimer.cpp:195` | ✅ |
| `+[OOScriptTimer noteGameReset]` (189) | `OOScriptTimer::noteGameReset` `Core/Scripting/OOScriptTimer.cpp:233` | ✅ |
| `-[OOScriptTimer isValidForScheduling]` (201) | `OOScriptTimer::isValidForScheduling` `Core/Scripting/OOScriptTimer.cpp:242` | ✅ |
| `-[OOScriptTimer compareByNextFireTime:]` (224) | `OOScriptTimer::compareByNextFireTime` `Core/Scripting/OOScriptTimer.cpp:265` | ✅ |

**Differences:**

- ✅ **low** — scheduling order is unchanged:
  - `updateTimers` peeks and pops while `now >= nextTime`, fires the timer, sets `_hasBeenRun`, and reschedules only if the callback did not stop the timer. Reschedules and new timers created during the update go to `sDeferredTimers` and are appended in order afterwards, so a repeating timer fires at most once per update.
  - `OOPriorityQueueOf` is the same binary heap: the same child/parent indexing, the same strict `< 0` tests in bubble-up and bubble-down, and the same last-into-hole removal. So timers with equal `nextTime` pop in the same order, and `removeExactObject` keeps upstream's skip-after-removal loop.

  upstream `Core/Scripting/OOScriptTimer.m:155-187`, `Core/OOPriorityQueue.m:292-490` ↔ port `Core/Scripting/OOScriptTimer.cpp:195-231`, `Core/OOPriorityQueue.h:70-160`
- ✅ **low** — interval at or below 0 is handled as upstream did:
  - Init and `setInterval` map an interval ≤ 0 to -1.
  - A negative `nextTime` becomes `now + interval`.
  - `nextTime < now` with a negative interval fails init (nil ↔ false/nullptr).
  - `isValidForScheduling` refuses an expired one-shot only after it has run. Otherwise it does the same `ceil((now - next)/interval)` advance; for an unrun one-shot that is a division by -1 giving -0, so `nextTime` stays put. The extra `+= interval` applies when it is still not in the future.

  upstream `Core/Scripting/OOScriptTimer.m:39-63`, `:110-115`, `:201-222` ↔ port `Core/Scripting/OOScriptTimer.cpp:65-87`, `:147-152`, `:242-263`
- ✅ **low** — lifetime and nil-safety:
  - The queue holds `oo::Ref`s (`OOPriorityQueue.h:74`), as the NSObject queue retained.
  - `updateTimers` holds the popped timer in a `Ref` while it fires (`:209`), as `-removeNextObject`'s autorelease did.
  - `unscheduleTimer` null-checks `sTimers`, where upstream messaged nil.
  - The `@try` around `[other nextTime]` in `compareByNextFireTime` is gone: the getter cannot throw, and it logged only on an exception.

