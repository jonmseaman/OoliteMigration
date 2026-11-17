# Parity findings: scripting
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## OOJSConsole

<a id="oojsconsole"></a>
Upstream `src/Core/Debug/OOJSConsole.m` ↔ `Core/Debug/OOJSConsole.cpp` (1053 / 1448 lines)

**Status:** done — 34 rows: 18 ✅ 8 ⚠️ 5 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sConsoleClass` / `sConsoleSettingsClass` (98, 209) | `sConsoleClass` `Core/Debug/OOJSConsole.cpp:142`, `sConsoleSettingsClass` :295 (exotic methods :287) | ⚠️ |
| `sConsoleProperties` (146) | `sConsoleProperties` `Core/Debug/OOJSConsole.cpp:204` | ✅ |
| `sConsoleMethods` (181) | `sConsoleMethods` `Core/Debug/OOJSConsole.cpp:259` | ⚠️ |
| `InitOOJSConsole` (224) | `InitOOJSConsole` `Core/Debug/OOJSConsole.cpp:301` | ✅ |
| `OOJSConsoleDestroy` (233) | — (prototype now looked up per context with `JS_GetClassProto`, `Core/Debug/OOJSConsole.cpp:369-377`) | ➖ |
| `DebugMonitorToJSConsole` (238) | `DebugMonitorToJSConsole` `Core/Debug/OOJSConsole.cpp:365` | ⚠️ |
| `ConsoleGetProperty` (287) | `ConsoleGetProperty` `Core/Debug/OOJSConsole.cpp:420` | ❌ |
| `ConsoleSetProperty` (382) | `ConsoleSetProperty` `Core/Debug/OOJSConsole.cpp:510` | ⚠️ |
| `DoWeDefineAllDebugFlags` (461) | `DoWeDefineAllDebugFlags` `Core/Debug/OOJSConsole.cpp:577` | ✅ |
| `ConsoleFinalize` (489) | `OOJSCxxObjectWrapperFinalize` (class def `Core/Debug/OOJSConsole.cpp:144,297`) | ✅ |
| `ConsoleSettingsDeleteProperty` (499) | `ConsoleSettingsDeleteProperty` `Core/Debug/OOJSConsole.cpp:723` | ✅ |
| `ConsoleSettingsGetProperty` (523) | `ConsoleSettingsGetProperty` `Core/Debug/OOJSConsole.cpp:643` (+ `ConsoleSettingsGetOwnProperty` :637) | ❌ |
| `ConsoleSettingsSetProperty` (553) | `ConsoleSettingsSetProperty` `Core/Debug/OOJSConsole.cpp:697` → `SetSetting` :668 (+ `ConsoleSettingsDefineOwnProperty` :709) | ✅ |
| `ConsoleConsoleMessage` (594) | `ConsoleConsoleMessage` `Core/Debug/OOJSConsole.cpp:745` | ✅ |
| `ConsoleClearConsole` (648) | `ConsoleClearConsole` `Core/Debug/OOJSConsole.cpp:799` (+ `ReportNotTheMonitor` :334) | ❌ |
| `ConsoleScriptStack` (667) | `ConsoleScriptStack` `Core/Debug/OOJSConsole.cpp:813` | ✅ |
| `ConsoleInspectEntity` (677) | `ConsoleInspectEntity` `Core/Debug/OOJSConsole.cpp:827` | ⚠️ |
| `ConsoleCallObjCMethod` (698) | `ConsoleCallObjCMethod` `Core/Debug/OOJSConsole.cpp:1021` (+ `kMonitorMethods` :872, `CallMonitorMethod` :925) | ❌ |
| `ConsoleSetUpCallObjC` (724) | `ConsoleSetUpCallObjC` `Core/Debug/OOJSConsole.cpp:1072` | ✅ |
| `ConsoleIsExecutableJavaScript` (742) | `ConsoleIsExecutableJavaScript` `Core/Debug/OOJSConsole.cpp:1138` (+ `IsIncompleteSyntaxError` :1099) | ⚠️ |
| `ConsoleDisplayMessagesInClass` (769) | `ConsoleDisplayMessagesInClass` `Core/Debug/OOJSConsole.cpp:1174` | ✅ |
| `ConsoleSetDisplayMessagesInClass` (782) | `ConsoleSetDisplayMessagesInClass` `Core/Debug/OOJSConsole.cpp:1187` | ❌ |
| `ConsoleWriteLogMarker` (799) | `ConsoleWriteLogMarker` `Core/Debug/OOJSConsole.cpp:1203` | ✅ |
| `ConsoleWriteMemoryStats` (810) | `ConsoleWriteMemoryStats` `Core/Debug/OOJSConsole.cpp:1213` | ✅ |
| `ConsoleWriteJSMemoryStats` (824) | `ConsoleWriteJSMemoryStats` `Core/Debug/OOJSConsole.cpp:1226` | ✅ |
| `ConsoleGarbageCollect` (838) | `ConsoleGarbageCollect` `Core/Debug/OOJSConsole.cpp:1245` (+ `JSHeapSize` :1238) | ⚠️ |
| `DumpCallback` (858) | — (gone with `dumpNamedRoots`) | ➖ |
| `ConsoleDumpNamedRoots` (880) | — removed; file comment `Core/Debug/OOJSConsole.cpp:70`, `Core/Scripting/README.md:136` | ➖ |
| `ConsoleDumpHeap` (905) | `ConsoleDumpHeap` `Core/Debug/OOJSConsole.cpp:1260` | ⚠️ |
| `ConsoleProfile` (926) | `ConsoleProfile` `Core/Debug/OOJSConsole.cpp:1290` | ✅ |
| `ConsoleGetProfile` (950) | `ConsoleGetProfile` `Core/Debug/OOJSConsole.cpp:1323` | ✅ |
| `ConsoleTrace` (974) | `ConsoleTrace` `Core/Debug/OOJSConsole.cpp:1353` | ✅ |
| `PerformProfiling` (997) | `PerformProfiling` `Core/Debug/OOJSConsole.cpp:1386` | ✅ |
| `MonitorFromJSObject` / `MonitorForConsoleObject` (port helpers for `OOJSNativeObjectFromJSObject` + `isKindOfClass:`) | `Core/Debug/OOJSConsole.cpp:320,348` | ✅ |

**Differences:**

- ❌ **low** — `debugFlags` getter: upstream `INT_TO_JSVAL((uint32_t)gDebugFlags)` yields an int32, so with bit 31 set (e.g. after `debugFlags = -1`, or `kAll` 0xffffffff) it reads back negative; the port uses `JS_NewUint32` and reads 4294967295 (new) — upstream `Core/Debug/OOJSConsole.m:297` ↔ port `Core/Debug/OOJSConsole.cpp:427`
- ❌ **low** — `setDisplayMessagesInClass(cls)` with one argument: upstream's padded `argv[1]` is `undefined`, `JS_ValueToBoolean` succeeds with false, so the class is switched off; the port requires `argc > 1` and does nothing (new) — upstream `Core/Debug/OOJSConsole.m:789-792` ↔ port `Core/Debug/OOJSConsole.cpp:1192-1196`
- ❌ **low** — ConsoleSettings enumeration/`in`: upstream assignment went through SpiderMonkey's default add path (stub `addProperty`, class setter), leaving an ordinary enumerable own property, so `for..in`/`'k' in settings` saw keys set this session; the port's `get_own_property` always answers false and nothing is stored, so they see nothing. File comment claims "as before" (new) — upstream `Core/Debug/OOJSConsole.m:209-222` ↔ port `Core/Debug/OOJSConsole.cpp:74-75,637-641`
- ❌ **low** — "Expected OODebugMonitor, got %s" for a foreign `this` (`clearConsole.call(x)`, settings hooks): port prints `Entity` for any entity and `(null)` otherwise; upstream printed the converted object's class (`ShipEntity`, `OOJSScript`…) (still open) — upstream `Core/Debug/OOJSConsole.m:654-657` ↔ port `Core/Debug/OOJSConsole.cpp:334-344,802-804`
- ❌ **low** — `callObjC()` on a console object: error texts begin `.callObjC(): …` (empty `className`); upstream passed `[monitor oo_jsClassName]` (nil), giving `(null).callObjC(): …`. Debug builds only (still open) — upstream `Core/Debug/OOJSConsole.m:714` ↔ port `Core/Debug/OOJSConsole.cpp:927-958`
- ⚠️ **low** — `callObjC()` is not a generic selector call: console objects answer only `kMonitorMethods`, entities go through `OOJSCallEntityMethod`, any other native object (scripts, timers, sounds…) gets "Attempt to call __callObjCMethod() for non-Objective-C object" (code comments :847-853, :1039-1041; still open) — upstream `Core/Debug/OOJSConsole.m:698-721` ↔ port `Core/Debug/OOJSConsole.cpp:1021-1069`
- ⚠️ **low** — `pedanticMode` is a stored flag (`sPedanticMode`, default true) with no engine effect; upstream toggled `JSOPTION_STRICT` on the context (file comment :68-69, `Core/Scripting/README.md:135`) — upstream `Core/Debug/OOJSConsole.m:317-320,414-424` ↔ port `Core/Debug/OOJSConsole.cpp:446-447,539-541`
- ⚠️ **low** — `dumpNamedRoots()` no longer exists (calling it now throws TypeError instead of writing `js-roots.txt`); `dumpHeap()` writes `JS_DumpMemoryUsage`; `garbageCollect()` keeps `Bytes before: %u Bytes after: %u` text but numbers are QuickJS `malloc_size` (file comment :70-71; changed since 2026-10-27, when `dumpNamedRoots` was a stub returning true) — upstream `Core/Debug/OOJSConsole.m:838-920` ↔ port `Core/Debug/OOJSConsole.cpp:1238-1283`
- ⚠️ **low** — `isExecutableJavaScript` reimplements `JS_BufferIsCompilableUnit` with a QuickJS compile-only eval plus a message/location heuristic; the target object is ignored, and a primitive `argv[0]` (which upstream `JS_ValueToObject` boxed) now returns false — upstream `Core/Debug/OOJSConsole.m:749-759` ↔ port `Core/Debug/OOJSConsole.cpp:1099-1171`
- ⚠️ **low** — console/settings objects hold a strong `oo::share(monitor)` instead of `weakRetain`; the monitor is a never-released singleton (comment :137-141). `inspectEntity` calls `oo::InspectEntity` (comment :64-65) (still open) — port `Core/Debug/OOJSConsole.cpp:387,403,834`
- Subtle: the settings prototype (no monitor) now reads through to `Object.prototype` and ignores writes; upstream reported "Expected OODebugMonitor, got (null)". Integer-keyed `delete settings[0]` returns false where upstream's hook returned NO without an exception (silent script abort) — port `Core/Debug/OOJSConsole.cpp:616-618,727`
- Subtle ✅: property flags match (`OOJS_PROP_*_CB` → enumerable/non-configurable, hidden → not enumerable), method arg counts match; `callObjC` defined non-enumerable, read-only, permanent as `OOJS_METHOD_READONLY`. `PerformProfiling` with no argument passes argc 0 to the bad-arguments report where upstream passed 1 with an `undefined` argv.

## PlayerEntityLegacyScriptEngine

<a id="playerentitylegacyscriptengine"></a>
Upstream `src/Core/Entities/PlayerEntityLegacyScriptEngine.m` ↔ `Core/Entities/PlayerEntityLegacyScriptEngine.cpp` (2625 / 3175 lines)

**Status:** done — 151 rows: 144 ✅ 6 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `CurrentScriptNameOr` (112) | `CurrentScriptNameOr` `PlayerEntityLegacyScriptEngine.cpp:143` | ✅ |
| `CurrentScriptDesc` (120) | `CurrentScriptDescription` `PlayerEntityLegacyScriptEngine.cpp:151` | ✅ |
| `PerformScriptActions` (130) | `PerformScriptActions` `PlayerEntityLegacyScriptEngine.cpp:277` | ✅ |
| `PerformConditionalStatment` (142) | `PerformConditionalStatment` `PlayerEntityLegacyScriptEngine.cpp:289` | ✅ |
| `PerformActionStatment` (165) | `PerformActionStatment` `PlayerEntityLegacyScriptEngine.cpp:306` | ⚠️ |
| `TestScriptConditions` (209) | `TestScriptConditions` `PlayerEntityLegacyScriptEngine.cpp:358` | ✅ |
| `-[PlayerEntity(Scripting) setScriptTarget:]` (223) | `PlayerEntity::setScriptTarget` `PlayerEntityLegacyScriptEngine.cpp:374` | ✅ |
| `-[PlayerEntity(Scripting) scriptTarget]` (228) | `PlayerEntity::scriptTarget` `PlayerEntityLegacyScriptEngine.cpp:380` | ✅ |
| `RecursiveRemapStatus` (233) | `RecursiveRemapStatus` `PlayerEntityLegacyScriptEngine.cpp:382` | ✅ |
| `-[PlayerEntity(Scripting) worldScriptsRequiringTickle]` (247) | `PlayerEntity::getWorldScriptsRequiringTickle` `PlayerEntityLegacyScriptEngine.cpp:400` | ⚠️ |
| `-[PlayerEntity(Scripting) checkScript]` (266) | `PlayerEntity::checkScript` `PlayerEntityLegacyScriptEngine.cpp:416` | ⚠️ |
| `-[PlayerEntity(Scripting) runScriptActions:withContextName:forTarget:]` (321) | `PlayerEntity::runScriptActions` `PlayerEntityLegacyScriptEngine.cpp:476` | ✅ |
| `-[PlayerEntity(Scripting) runUnsanitizedScriptActions:allowingAIMethods:withContextName:forTarget:]` (349) | `PlayerEntity::runUnsanitizedScriptActions` `PlayerEntityLegacyScriptEngine.cpp:507` | ✅ |
| `-[PlayerEntity(Scripting) scriptTestConditions:]` (356) | `PlayerEntity::scriptTestConditions` `PlayerEntityLegacyScriptEngine.cpp:514` | ✅ |
| `-[PlayerEntity(Scripting) scriptTestCondition:]` (374) | `PlayerEntity::scriptTestCondition` `PlayerEntityLegacyScriptEngine.cpp:531` | ⚠️ |
| `-[PlayerEntity(Scripting) expandScriptRightHandSide:]` (542) | `PlayerEntity::expandScriptRightHandSide` `PlayerEntityLegacyScriptEngine.cpp:711` | ✅ |
| `-[PlayerEntity(Scripting) missionVariables]` (574) | `PlayerEntity::missionVariables` `PlayerEntityLegacyScriptEngine.cpp:744` | ✅ |
| `-[PlayerEntity(Scripting) missionVariableForKey:]` (579) | `PlayerEntity::missionVariableForKey` `PlayerEntityLegacyScriptEngine.cpp:748` | ✅ |
| `-[PlayerEntity(Scripting) setMissionVariable:forKey:]` (587) | `PlayerEntity::setMissionVariable` `PlayerEntityLegacyScriptEngine.cpp:755` | ✅ |
| `-[PlayerEntity(Scripting) localVariablesForMission:]` (597) | `PlayerEntity::localVariablesForMission` `PlayerEntityLegacyScriptEngine.cpp:770` | ⚠️ |
| `-[PlayerEntity(Scripting) localVariableForKey:andMission:]` (613) | `PlayerEntity::localVariableForKey` `PlayerEntityLegacyScriptEngine.cpp:781` | ✅ |
| `-[PlayerEntity(Scripting) setLocalVariable:forKey:andMission:]` (618) | `PlayerEntity::setLocalVariable` `PlayerEntityLegacyScriptEngine.cpp:791` | ✅ |
| `-[PlayerEntity(Scripting) missionsList]` (632) | `PlayerEntity::missionsList` `PlayerEntityLegacyScriptEngine.cpp:806` | ⚠️ |
| `-[PlayerEntity(Scripting) replaceVariablesInString:]` (691) | `PlayerEntity::replaceVariablesInString` `PlayerEntityLegacyScriptEngine.cpp:865` | ✅ |
| `-[PlayerEntity(Scripting) setMissionDescription:]` (724) | `PlayerEntity::setMissionDescription(textKey)` `PlayerEntityLegacyScriptEngine.cpp:914` | ✅ |
| `-[PlayerEntity(Scripting) setMissionDescription:forMission:]` (729) | `PlayerEntity::setMissionDescription(textKey, key)` `PlayerEntityLegacyScriptEngine.cpp:920` | ✅ |
| `-[PlayerEntity(Scripting) setMissionInstructions:forMission:]` (742) | `PlayerEntity::setMissionInstructions` `PlayerEntityLegacyScriptEngine.cpp:940` | ✅ |
| `-[PlayerEntity(Scripting) setMissionInstructionsList:forMission:]` (755) | `PlayerEntity::setMissionInstructionsList` `PlayerEntityLegacyScriptEngine.cpp:954` | ✅ |
| `-[PlayerEntity(Scripting) clearMissionDescription]` (777) | `PlayerEntity::clearMissionDescription` `PlayerEntityLegacyScriptEngine.cpp:976` | ✅ |
| `-[PlayerEntity(Scripting) clearMissionDescriptionForMission:]` (782) | `PlayerEntity::clearMissionDescriptionForMission` `PlayerEntityLegacyScriptEngine.cpp:986` | ✅ |
| `-[PlayerEntity(Scripting) mission_string]` (795) | `PlayerEntity::mission_string` `PlayerEntityLegacyScriptEngine.cpp:994` | ✅ |
| `-[PlayerEntity(Scripting) status_string]` (800) | `PlayerEntity::status_string` `PlayerEntityLegacyScriptEngine.cpp:998` | ✅ |
| `-[PlayerEntity(Scripting) gui_screen_string]` (805) | `PlayerEntity::gui_screen_string` `PlayerEntityLegacyScriptEngine.cpp:1003` | ✅ |
| `-[PlayerEntity(Scripting) galaxy_number]` (810) | `PlayerEntity::getGalaxy_number` `PlayerEntityLegacyScriptEngine.cpp:1008` | ✅ |
| `-[PlayerEntity(Scripting) planet_number]` (815) | `PlayerEntity::planet_number` `PlayerEntityLegacyScriptEngine.cpp:1013` | ✅ |
| `-[PlayerEntity(Scripting) score_number]` (820) | `PlayerEntity::score_number` `PlayerEntityLegacyScriptEngine.cpp:1018` | ✅ |
| `-[PlayerEntity(Scripting) credits_number]` (825) | `PlayerEntity::credits_number` `PlayerEntityLegacyScriptEngine.cpp:1023` | ✅ |
| `-[PlayerEntity(Scripting) scriptTimer_number]` (830) | `PlayerEntity::scriptTimer_number` `PlayerEntityLegacyScriptEngine.cpp:1028` | ✅ |
| `-[PlayerEntity(Scripting) shipsFound_number]` (836) | `PlayerEntity::shipsFound_number` `PlayerEntityLegacyScriptEngine.cpp:1034` | ✅ |
| `-[PlayerEntity(Scripting) commanderLegalStatus_number]` (841) | `PlayerEntity::commanderLegalStatus_number` `PlayerEntityLegacyScriptEngine.cpp:1039` | ✅ |
| `-[PlayerEntity(Scripting) setLegalStatus:]` (846) | `PlayerEntity::setLegalStatus` `PlayerEntityLegacyScriptEngine.cpp:1044` | ✅ |
| `-[PlayerEntity(Scripting) commanderLegalStatus_string]` (851) | `PlayerEntity::commanderLegalStatus_string` `PlayerEntityLegacyScriptEngine.cpp:1050` | ✅ |
| `-[PlayerEntity(Scripting) d100_number]` (856) | `PlayerEntity::d100_number` `PlayerEntityLegacyScriptEngine.cpp:1055` | ✅ |
| `-[PlayerEntity(Scripting) pseudoFixedD100_number]` (862) | `PlayerEntity::pseudoFixedD100_number` `PlayerEntityLegacyScriptEngine.cpp:1061` | ✅ |
| `-[PlayerEntity(Scripting) d256_number]` (867) | `PlayerEntity::d256_number` `PlayerEntityLegacyScriptEngine.cpp:1066` | ✅ |
| `-[PlayerEntity(Scripting) pseudoFixedD256_number]` (873) | `PlayerEntity::pseudoFixedD256_number` `PlayerEntityLegacyScriptEngine.cpp:1072` | ✅ |
| `-[PlayerEntity(Scripting) clock_number]` (878) | `PlayerEntity::clock_number` `PlayerEntityLegacyScriptEngine.cpp:1077` | ✅ |
| `-[PlayerEntity(Scripting) clock_secs_number]` (883) | `PlayerEntity::clock_secs_number` `PlayerEntityLegacyScriptEngine.cpp:1083` | ✅ |
| `-[PlayerEntity(Scripting) clock_mins_number]` (888) | `PlayerEntity::clock_mins_number` `PlayerEntityLegacyScriptEngine.cpp:1090` | ✅ |
| `-[PlayerEntity(Scripting) clock_hours_number]` (893) | `PlayerEntity::clock_hours_number` `PlayerEntityLegacyScriptEngine.cpp:1097` | ✅ |
| `-[PlayerEntity(Scripting) clock_days_number]` (898) | `PlayerEntity::clock_days_number` `PlayerEntityLegacyScriptEngine.cpp:1104` | ✅ |
| `-[PlayerEntity(Scripting) fuelLevel_number]` (903) | `PlayerEntity::fuelLevel_number` `PlayerEntityLegacyScriptEngine.cpp:1111` | ✅ |
| `-[PlayerEntity(Scripting) dockedAtMainStation_bool]` (908) | `PlayerEntity::dockedAtMainStation_bool` `PlayerEntityLegacyScriptEngine.cpp:1117` | ✅ |
| `-[PlayerEntity(Scripting) foundEquipment_bool]` (916) | `PlayerEntity::foundEquipment_bool` `PlayerEntityLegacyScriptEngine.cpp:1125` | ✅ |
| `-[PlayerEntity(Scripting) sunWillGoNova_bool]` (921) | `PlayerEntity::sunWillGoNova_bool` `PlayerEntityLegacyScriptEngine.cpp:1130` | ✅ |
| `-[PlayerEntity(Scripting) sunGoneNova_bool]` (926) | `PlayerEntity::sunGoneNova_bool` `PlayerEntityLegacyScriptEngine.cpp:1141` | ✅ |
| `-[PlayerEntity(Scripting) missionChoice_string]` (931) | `PlayerEntity::missionChoice_string` `PlayerEntityLegacyScriptEngine.cpp:1153` | ✅ |
| `-[PlayerEntity(Scripting) missionKeyPress_string]` (936) | `PlayerEntity::missionKeyPress_string` `PlayerEntityLegacyScriptEngine.cpp:1159` | ✅ |
| `-[PlayerEntity(Scripting) dockedTechLevel_number]` (941) | `PlayerEntity::dockedTechLevel_number` `PlayerEntityLegacyScriptEngine.cpp:1164` | ✅ |
| `-[PlayerEntity(Scripting) dockedStationName_string]` (950) | `PlayerEntity::dockedStationName_string` `PlayerEntityLegacyScriptEngine.cpp:1175` | ✅ |
| `-[PlayerEntity(Scripting) systemGovernment_string]` (962) | `PlayerEntity::systemGovernment_string` `PlayerEntityLegacyScriptEngine.cpp:1185` | ✅ |
| `-[PlayerEntity(Scripting) systemGovernment_number]` (972) | `PlayerEntity::systemGovernment_number` `PlayerEntityLegacyScriptEngine.cpp:1193` | ✅ |
| `-[PlayerEntity(Scripting) systemEconomy_string]` (978) | `PlayerEntity::systemEconomy_string` `PlayerEntityLegacyScriptEngine.cpp:1198` | ✅ |
| `-[PlayerEntity(Scripting) systemEconomy_number]` (988) | `PlayerEntity::systemEconomy_number` `PlayerEntityLegacyScriptEngine.cpp:1206` | ✅ |
| `-[PlayerEntity(Scripting) systemTechLevel_number]` (994) | `PlayerEntity::systemTechLevel_number` `PlayerEntityLegacyScriptEngine.cpp:1211` | ✅ |
| `-[PlayerEntity(Scripting) systemPopulation_number]` (1000) | `PlayerEntity::systemPopulation_number` `PlayerEntityLegacyScriptEngine.cpp:1216` | ✅ |
| `-[PlayerEntity(Scripting) systemProductivity_number]` (1006) | `PlayerEntity::systemProductivity_number` `PlayerEntityLegacyScriptEngine.cpp:1221` | ✅ |
| `-[PlayerEntity(Scripting) commanderName_string]` (1012) | `PlayerEntity::commanderName_string` `PlayerEntityLegacyScriptEngine.cpp:1226` | ✅ |
| `-[PlayerEntity(Scripting) commanderRank_string]` (1017) | `PlayerEntity::commanderRank_string` `PlayerEntityLegacyScriptEngine.cpp:1231` | ✅ |
| `-[PlayerEntity(Scripting) commanderShip_string]` (1022) | `PlayerEntity::commanderShip_string` `PlayerEntityLegacyScriptEngine.cpp:1236` | ✅ |
| `-[PlayerEntity(Scripting) commanderShipDisplayName_string]` (1027) | `PlayerEntity::commanderShipDisplayName_string` `PlayerEntityLegacyScriptEngine.cpp:1241` | ✅ |
| `-[PlayerEntity(Scripting) expandMessage:]` (1034) | `PlayerEntity::expandMessage` `PlayerEntityLegacyScriptEngine.cpp:1248` | ✅ |
| `-[PlayerEntity(Scripting) commsMessage:]` (1048) | `PlayerEntity::commsMessage` `PlayerEntityLegacyScriptEngine.cpp:1262` | ✅ |
| `-[PlayerEntity(Scripting) commsMessageByUnpiloted:]` (1056) | `PlayerEntity::commsMessageByUnpiloted` `PlayerEntityLegacyScriptEngine.cpp:1273` | ✅ |
| `-[PlayerEntity(Scripting) consoleMessage3s:]` (1061) | `PlayerEntity::consoleMessage3s` `PlayerEntityLegacyScriptEngine.cpp:1279` | ✅ |
| `-[PlayerEntity(Scripting) consoleMessage6s:]` (1066) | `PlayerEntity::consoleMessage6s` `PlayerEntityLegacyScriptEngine.cpp:1285` | ✅ |
| `-[PlayerEntity(Scripting) awardCredits:]` (1071) | `PlayerEntity::awardCredits` `PlayerEntityLegacyScriptEngine.cpp:1291` | ✅ |
| `-[PlayerEntity(Scripting) awardShipKills:]` (1088) | `PlayerEntity::awardShipKills` `PlayerEntityLegacyScriptEngine.cpp:1308` | ✅ |
| `-[PlayerEntity(Scripting) awardEquipment:]` (1098) | `PlayerEntity::awardEquipment` `PlayerEntityLegacyScriptEngine.cpp:1317` | ✅ |
| `-[PlayerEntity(Scripting) removeEquipment:]` (1120) | `PlayerEntity::removeEquipment` `PlayerEntityLegacyScriptEngine.cpp:1353` | ✅ |
| `-[PlayerEntity(Scripting) setPlanetinfo:]` (1140) | `PlayerEntity::setPlanetinfo` `PlayerEntityLegacyScriptEngine.cpp:1378` | ✅ |
| `-[PlayerEntity(Scripting) setSpecificPlanetInfo:]` (1160) | `PlayerEntity::setSpecificPlanetInfo` `PlayerEntityLegacyScriptEngine.cpp:1404` | ✅ |
| `-[PlayerEntity(Scripting) awardCargo:]` (1180) | `PlayerEntity::awardCargo` `PlayerEntityLegacyScriptEngine.cpp:1432` | ✅ |
| `-[PlayerEntity(Scripting) removeAllCargo]` (1216) | `PlayerEntity::removeAllCargo()` `PlayerEntityLegacyScriptEngine.cpp:1482` | ✅ |
| `-[PlayerEntity(Scripting) removeAllCargo:]` (1221) | `PlayerEntity::removeAllCargo(bool)` `PlayerEntityLegacyScriptEngine.cpp:1484` | ✅ |
| `-[PlayerEntity(Scripting) useSpecialCargo:]` (1259) | `PlayerEntity::useSpecialCargo` `PlayerEntityLegacyScriptEngine.cpp:1526` | ✅ |
| `-[PlayerEntity(Scripting) testForEquipment:]` (1269) | `PlayerEntity::testForEquipment` `PlayerEntityLegacyScriptEngine.cpp:1538` | ✅ |
| `-[PlayerEntity(Scripting) awardFuel:]` (1274) | `PlayerEntity::awardFuel` `PlayerEntityLegacyScriptEngine.cpp:1544` | ✅ |
| `-[PlayerEntity(Scripting) messageShipAIs:]` (1286) | `PlayerEntity::messageShipAIs` `PlayerEntityLegacyScriptEngine.cpp:1561` | ✅ |
| `-[PlayerEntity(Scripting) ejectItem:]` (1312) | `PlayerEntity::ejectItem` `PlayerEntityLegacyScriptEngine.cpp:1591` | ✅ |
| `-[PlayerEntity(Scripting) addShips:]` (1319) | `PlayerEntity::addShips` `PlayerEntityLegacyScriptEngine.cpp:1597` | ✅ |
| `-[PlayerEntity(Scripting) addSystemShips:]` (1345) | `PlayerEntity::addSystemShips` `PlayerEntityLegacyScriptEngine.cpp:1629` | ✅ |
| `-[PlayerEntity(Scripting) addShipsAt:]` (1374) | `PlayerEntity::addShipsAt` `PlayerEntityLegacyScriptEngine.cpp:1664` | ✅ |
| `-[PlayerEntity(Scripting) addShipsAtPrecisely:]` (1412) | `PlayerEntity::addShipsAtPrecisely` `PlayerEntityLegacyScriptEngine.cpp:1709` | ✅ |
| `-[PlayerEntity(Scripting) addShipsWithinRadius:]` (1450) | `PlayerEntity::addShipsWithinRadius` `PlayerEntityLegacyScriptEngine.cpp:1754` | ✅ |
| `-[PlayerEntity(Scripting) spawnShip:]` (1480) | `PlayerEntity::spawnShip` `PlayerEntityLegacyScriptEngine.cpp:1801` | ✅ |
| `-[PlayerEntity(Scripting) set:]` (1489) | `PlayerEntity::set` `PlayerEntityLegacyScriptEngine.cpp:1814` | ✅ |
| `-[PlayerEntity(Scripting) reset:]` (1522) | `PlayerEntity::reset` `PlayerEntityLegacyScriptEngine.cpp:1855` | ✅ |
| `-[PlayerEntity(Scripting) increment:]` (1539) | `PlayerEntity::increment` `PlayerEntityLegacyScriptEngine.cpp:1875` | ✅ |
| `-[PlayerEntity(Scripting) decrement:]` (1560) | `PlayerEntity::decrement` `PlayerEntityLegacyScriptEngine.cpp:1907` | ✅ |
| `-[PlayerEntity(Scripting) add:]` (1581) | `PlayerEntity::add` `PlayerEntityLegacyScriptEngine.cpp:1939` | ✅ |
| `-[PlayerEntity(Scripting) subtract:]` (1614) | `PlayerEntity::subtract` `PlayerEntityLegacyScriptEngine.cpp:1983` | ✅ |
| `-[PlayerEntity(Scripting) checkForShips:]` (1647) | `PlayerEntity::checkForShips` `PlayerEntityLegacyScriptEngine.cpp:2028` | ✅ |
| `-[PlayerEntity(Scripting) resetScriptTimer]` (1652) | `PlayerEntity::resetScriptTimer` `PlayerEntityLegacyScriptEngine.cpp:2036` | ✅ |
| `-[PlayerEntity(Scripting) addMissionText:]` (1659) | `PlayerEntity::addMissionText` `PlayerEntityLegacyScriptEngine.cpp:2042` | ✅ |
| `-[PlayerEntity(Scripting) addLiteralMissionText:]` (1678) | `PlayerEntity::addLiteralMissionText` `PlayerEntityLegacyScriptEngine.cpp:2063` | ✅ |
| `-[PlayerEntity(Scripting) setMissionChoiceByTextEntry:]` (1690) | `PlayerEntity::setMissionChoiceByTextEntry` `PlayerEntityLegacyScriptEngine.cpp:2074` | ✅ |
| `-[PlayerEntity(Scripting) setMissionChoices:]` (1697) | `PlayerEntity::setMissionChoices` `PlayerEntityLegacyScriptEngine.cpp:2081` | ✅ |
| `-[PlayerEntity(Scripting) setMissionChoicesDictionary:]` (1706) | `PlayerEntity::setMissionChoicesDictionary` `PlayerEntityLegacyScriptEngine.cpp:2097` | ❌ |
| `-[PlayerEntity(Scripting) resetMissionChoice]` (1828) | `PlayerEntity::resetMissionChoice` `PlayerEntityLegacyScriptEngine.cpp:2227` | ✅ |
| `-[PlayerEntity(Scripting) clearMissionScreen]` (1833) | `PlayerEntity::clearMissionScreen` `PlayerEntityLegacyScriptEngine.cpp:2229` | ✅ |
| `-[PlayerEntity(Scripting) addMissionDestination:]` (1843) | `PlayerEntity::addMissionDestination` `PlayerEntityLegacyScriptEngine.cpp:2238` | ✅ |
| `-[PlayerEntity(Scripting) removeMissionDestination:]` (1858) | `PlayerEntity::removeMissionDestination` `PlayerEntityLegacyScriptEngine.cpp:2249` | ✅ |
| `-[PlayerEntity(Scripting) showShipModel:]` (1873) | `PlayerEntity::showShipModel` `PlayerEntityLegacyScriptEngine.cpp:2260` | ✅ |
| `-[PlayerEntity(Scripting) setMissionMusic:]` (1884) | `PlayerEntity::setMissionMusic` `PlayerEntityLegacyScriptEngine.cpp:2277` | ✅ |
| `-[PlayerEntity(Scripting) missionTitle]` (1892) | `PlayerEntity::missionTitle` `PlayerEntityLegacyScriptEngine.cpp:2284` | ✅ |
| `-[PlayerEntity(Scripting) setMissionTitle:]` (1897) | `PlayerEntity::setMissionTitle` `PlayerEntityLegacyScriptEngine.cpp:2288` | ✅ |
| `-[PlayerEntity(Scripting) setMissionImage:]` (1905) | `PlayerEntity::setMissionImage` `PlayerEntityLegacyScriptEngine.cpp:2295` | ✅ |
| `-[PlayerEntity(Scripting) setMissionBackground:]` (1914) | `PlayerEntity::setMissionBackground` `PlayerEntityLegacyScriptEngine.cpp:2306` | ✅ |
| `-[PlayerEntity(Scripting) setFuelLeak:]` (1923) | `PlayerEntity::setFuelLeak` `PlayerEntityLegacyScriptEngine.cpp:2316` | ✅ |
| `-[PlayerEntity(Scripting) fuelLeakRate_number]` (1938) | `PlayerEntity::fuelLeakRate_number` `PlayerEntityLegacyScriptEngine.cpp:2332` | ✅ |
| `-[PlayerEntity(Scripting) setSunNovaIn:]` (1943) | `PlayerEntity::setSunNovaIn` `PlayerEntityLegacyScriptEngine.cpp:2337` | ✅ |
| `-[PlayerEntity(Scripting) launchFromStation]` (1949) | `PlayerEntity::launchFromStation` `PlayerEntityLegacyScriptEngine.cpp:2345` | ✅ |
| `-[PlayerEntity(Scripting) blowUpStation]` (1959) | `PlayerEntity::blowUpStation` `PlayerEntityLegacyScriptEngine.cpp:2356` | ✅ |
| `-[PlayerEntity(Scripting) sendAllShipsAway]` (1970) | `PlayerEntity::sendAllShipsAway` `PlayerEntityLegacyScriptEngine.cpp:2369` | ✅ |
| `-[PlayerEntity(Scripting) addPlanet:]` (2005) | `PlayerEntity::addPlanet (+ addPlanetEntity :2429)` `PlayerEntityLegacyScriptEngine.cpp:2424` | ✅ |
| `-[PlayerEntity(Scripting) addMoon:]` (2049) | `PlayerEntity::addMoon (+ addMoonEntity :2522)` `PlayerEntityLegacyScriptEngine.cpp:2517` | ✅ |
| `-[PlayerEntity(Scripting) debugOn]` (2091) | `PlayerEntity::debugOn` `PlayerEntityLegacyScriptEngine.cpp:2610` | ✅ |
| `-[PlayerEntity(Scripting) debugOff]` (2097) | `PlayerEntity::debugOff` `PlayerEntityLegacyScriptEngine.cpp:2615` | ✅ |
| `-[PlayerEntity(Scripting) debugMessage:]` (2103) | `PlayerEntity::debugMessage` `PlayerEntityLegacyScriptEngine.cpp:2620` | ✅ |
| `-[PlayerEntity(Scripting) playSound:]` (2108) | `PlayerEntity::playSound` `PlayerEntityLegacyScriptEngine.cpp:2625` | ✅ |
| `-[PlayerEntity(Scripting) doMissionCallback]` (2115) | `PlayerEntity::doMissionCallback` `PlayerEntityLegacyScriptEngine.cpp:2632` | ✅ |
| `-[PlayerEntity(Scripting) clearMissionScreenID]` (2122) | `PlayerEntity::clearMissionScreenID` `PlayerEntityLegacyScriptEngine.cpp:2638` | ✅ |
| `-[PlayerEntity(Scripting) setMissionScreenID:]` (2128) | `PlayerEntity::setMissionScreenID` `PlayerEntityLegacyScriptEngine.cpp:2640` | ✅ |
| `-[PlayerEntity(Scripting) missionScreenID]` (2133) | `PlayerEntity::missionScreenID` `PlayerEntityLegacyScriptEngine.cpp:2644` | ✅ |
| `-[PlayerEntity(Scripting) endMissionScreenAndNoteOpportunity]` (2138) | `PlayerEntity::endMissionScreenAndNoteOpportunity` `PlayerEntityLegacyScriptEngine.cpp:2648` | ✅ |
| `-[PlayerEntity(Scripting) setGuiToMissionScreen]` (2149) | `PlayerEntity::setGuiToMissionScreen` `PlayerEntityLegacyScriptEngine.cpp:2660` | ✅ |
| `-[PlayerEntity(Scripting) refreshMissionScreenTextEntry]` (2160) | `PlayerEntity::refreshMissionScreenTextEntry` `PlayerEntityLegacyScriptEngine.cpp:2670` | ✅ |
| `-[PlayerEntity(Scripting) setGuiToMissionScreenWithCallback:]` (2176) | `PlayerEntity::setGuiToMissionScreenWithCallback` `PlayerEntityLegacyScriptEngine.cpp:2694` | ✅ |
| `-[PlayerEntity(Scripting) setBackgroundFromDescriptionsKey:]` (2228) | `PlayerEntity::setBackgroundFromDescriptionsKey` `PlayerEntityLegacyScriptEngine.cpp:2742` | ✅ |
| `-[PlayerEntity(Scripting) addScene:atOffset:]` (2240) | `PlayerEntity::addScene` `PlayerEntityLegacyScriptEngine.cpp:2753` | ✅ |
| `-[PlayerEntity(Scripting) processSceneDictionary:atOffset:]` (2259) | `PlayerEntity::processSceneDictionary` `PlayerEntityLegacyScriptEngine.cpp:2768` | ✅ |
| `-[PlayerEntity(Scripting) processSceneString:atOffset:]` (2292) | `PlayerEntity::processSceneString` `PlayerEntityLegacyScriptEngine.cpp:2807` | ✅ |
| `-[PlayerEntity(Scripting) addEqScriptForKey:]` (2483) | `PlayerEntity::addEqScriptForKey` `PlayerEntityLegacyScriptEngine.cpp:3031` | ✅ |
| `-[PlayerEntity(Scripting) removeEqScriptForKey:]` (2520) | `PlayerEntity::removeEqScriptForKey` `PlayerEntityLegacyScriptEngine.cpp:3067` | ✅ |
| `-[PlayerEntity(Scripting) eqScriptIndexForKey:]` (2545) | `PlayerEntity::eqScriptIndexForKey` `PlayerEntityLegacyScriptEngine.cpp:3097` | ✅ |
| `-[PlayerEntity(Scripting) targetNearestHostile]` (2560) | `PlayerEntity::targetNearestHostile` `PlayerEntityLegacyScriptEngine.cpp:3107` | ✅ |
| `-[PlayerEntity(Scripting) targetNearestIncomingMissile]` (2571) | `PlayerEntity::targetNearestIncomingMissile` `PlayerEntityLegacyScriptEngine.cpp:3117` | ✅ |
| `-[PlayerEntity(Scripting) setGalacticHyperspaceBehaviourTo:]` (2582) | `PlayerEntity::setGalacticHyperspaceBehaviourTo` `PlayerEntityLegacyScriptEngine.cpp:3127` | ✅ |
| `-[PlayerEntity(Scripting) setGalacticHyperspaceFixedCoordsTo:]` (2592) | `PlayerEntity::setGalacticHyperspaceFixedCoordsTo` `PlayerEntityLegacyScriptEngine.cpp:3142` | ✅ |
| `OOComparisonTypeToString` (2608) | `OOComparisonTypeToString` `PlayerEntityLegacyScriptEngine.cpp:3159` | ✅ |

**Differences:**

- ❌ **low** — all-blank mission choices: the fallback row is set to `" "` (one space); upstream `@"  "` (two spaces). Visibly blank either way; row text differs for GUI row comparisons (still open) — upstream `Core/Entities/PlayerEntityLegacyScriptEngine.m:1817` ↔ port `Core/Entities/PlayerEntityLegacyScriptEngine.cpp:2215`
- ⚠️ **low** — choice keys `std::stable_sort` with `caseInsensitiveCompare` over the Dict's byte-ordered keys; upstream unstable sort from hash order; non-string-key check and `test.script.error` log gone (code comment :2116-2118; still open) — upstream `.m:1728-1742` ↔ port `.cpp:2119-2126`
- ⚠️ **low** — `checkScript` runs tickle scripts in load order (code comment "ORDER-SENSITIVE (decision D)"); upstream `-allValues` hash order. Tickle cache is a vector of pairs. `checkScript`, `runScriptActions`, `scriptTestConditions` catch only `OOException` and rethrow other C++ exceptions (comments "as before") (still open) — upstream `.m:247-319,333-343,360-369` ↔ port `.cpp:400-474,487-501,517-526`
- ⚠️ **low** — `missionsList` walks world scripts in load order (`worldScriptNames()`, decision D); upstream `-keyEnumerator` hash order; changes manifest-screen mission line order (still open) — upstream `.m:661-687` ↔ port `.cpp:829-860`
- ⚠️ **low** — "unhandled condition" internal-error log prints the condition with `oo::writeOldStylePList` (decision C, comment :696-697) instead of NSArray `-description` (still open) — upstream `.m:538` ↔ port `.cpp:698-707`
- ⚠️ **low** — actions and condition queries dispatch through the by-name table (`oo::EntityRespondsToName`/`oo::CallEntityByName`, comment :327-328) instead of `respondsToSelector:`/`performSelector:`; equivalent only if the table covers every whitelisted selector (table not audited here) (still open) — upstream `.m:191-206,440,477,517,563,708-709` ↔ port `.cpp:329-355,597,630,671,732,896-898`
- ⚠️ **low** — `localVariablesForMission` returns a snapshot and no longer creates and stores an empty table on read; `setLocalVariable` writes the table back (comment :765-769). Upstream never saved locals, so nothing observable (still open) — upstream `.m:597-611` ↔ port `.cpp:770-804`
- Subtle: a non-string mission/local variable compares or substitutes as its description (`ConditionString`, comment :251-255); upstream raised inside `isEqualToString:`/`replaceOccurrencesOfString:` and the exception aborted the action list. JS mission variables are always strings — upstream `.m:426-430,702-705` ↔ port `.cpp:256-260,883-890`
- Subtle (nil messaging, practically unreachable): `addLiteralMissionText`, `setMissionChoicesDictionary`, `refreshMissionScreenTextEntry`, `setGuiToMissionScreenWithCallback` call `gui->` without a null check, and `setBackgroundFromDescriptionsKey`/the `scene` branch dereference `UNIVERSE->descriptions()` — port `.cpp:2070,2138,2683,2704,2743,2844`
- Subtle: an all-whitespace `processSceneString` returns false (upstream raised on `objectAtIndex:0`); a non-string planet `orientation` is ignored (upstream passed it to `ScanQuaternionFromString`) — port `.cpp:2812-2814,2466-2472`
- ✅ checked: every log class and text (including upstream typos `in %@,* CANNOT addShipsAtPrecisely`, `SCRIPT ERROR :in`, `WARNING in %@  Tried`), `%d`/`%f`/`%.3f`/`%.2f` → `{}`/`{:f}`/`{:.3f}`/`{:.2f}`, the condition operators and nil cases, `awardCredits`/`awardFuel` integer math, `removeEqScriptForKey`'s stale-count loop, and `setGalacticHyperspaceFixedCoordsTo`'s kept upstream bug (0x60 then overwritten with 0,0).

## EntityOOJavaScriptExtensions

<a id="entityoojavascriptextensions"></a>
Upstream `src/Core/Scripting/EntityOOJavaScriptExtensions.m` ↔ `Core/Scripting/EntityOOJavaScriptExtensions.cpp` (149 / 182 lines)

**Status:** done — 10 rows: 9 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[Entity(OOJavaScriptExtensions) isVisibleToScripts]` (39) | `EntityJSIsVisibleToScripts` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:43` (+ `OOJSEntityIsVisibleToScripts` :59) | ✅ |
| `-[Entity(OOJavaScriptExtensions) oo_jsClassName]` (44) | `EntityJSClassName` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:45` | ✅ |
| `-[Entity(OOJavaScriptExtensions) oo_jsValueInContext:]` (49) | `EntityJSValueInContext` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:77` | ✅ |
| `-[Entity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (81) | `EntityJSClassID` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:106` | ✅ |
| `-[Entity(OOJavaScriptExtensions) deleteJSSelf]` (87) | `EntityJSDeleteJSSelf` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:108` | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) isVisibleToScripts]` (105) | `ShipEntityJSIsVisibleToScripts` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:141` | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (110) | `ShipEntityJSClassID` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:143` | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) oo_jsClassName]` (116) | `ShipEntityJSClassName` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:145` | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) subEntitiesForScript]` (121) | `ShipEntityJSSubEntitiesForScript` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:149` | ✅ |
| `-[ShipEntity(OOJavaScriptExtensions) setTargetForScript:]` (126) | `ShipEntityJSSetTargetForScript` `Core/Scripting/EntityOOJavaScriptExtensions.cpp:158` | ❌ |

**Differences:**

- ❌ **low** — owner walk for `target`: when a subentity's owner is not a ship, upstream casts it to `ShipEntity*` and passes it to `addTarget:`; the port's `oo::ToShip()` yields `nullptr`, so the `else` branch clears the current target instead. Nearly unreachable (a ship subentity's owner is always a ship). The `me` walk is equivalent (both return) (still open) — upstream `Core/Scripting/EntityOOJavaScriptExtensions.m:136-146` ↔ port `Core/Scripting/EntityOOJavaScriptExtensions.cpp:168-181`
- ✅ subtle — the JS object is held by the entity's own `_jsSelf` reference (QuickJS refcount) instead of a named GC root; private slot is an `OOJSEntityHolder` (weak) instead of `[self weakRetain]`; the reset observer is kept. `deleteJSSelf` drops the reference then removes the observer, as upstream. A failed `JS_NewObjectClass` clears its exception and returns null, as upstream's NULL `_jsSelf` — port `:77-104,108-121`
- ✅ subtle — `EntityJSDescription` (:127) carries upstream `OOObject -oo_jsDescription` (`OOJavaScriptEngine.m:1289-1306`), same "[<class> <components>]" / "[object <class>]".

## OOConstToJSString

<a id="ooconsttojsstring"></a>
Upstream `src/Core/Scripting/OOConstToJSString.m` ↔ `Core/Scripting/OOConstToJSString.cpp` (240 / 257 lines)

**Status:** done — 8 rows: 7 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `s*TableEntries` / `TABLE()` from `.tbl` files (73-119) | `EntriesFrom` + `s*TableEntries` `Core/Scripting/OOConstToJSString.cpp:70,96-139` (rows from the `Tables` enum headers; their contents are audited with those headers) | ✅ |
| `OOConstToJSStringInit` (129) | `OOConstToJSStringInit` `Core/Scripting/OOConstToJSString.cpp:151` | ✅ |
| `OOConstToJSStringDestroy` (149) | `OOConstToJSStringDestroy` `Core/Scripting/OOConstToJSString.cpp:175` | ✅ |
| `CompareEntries` (156) | `CompareEntries` `Core/Scripting/OOConstToJSString.cpp:181` | ✅ |
| `InitTable` (168) | `InitTable` `Core/Scripting/OOConstToJSString.cpp:190` | ✅ |
| `OOJSStringFromConstantPRIVATE` (182) | `OOJSValueFromConstantPRIVATE` `Core/Scripting/OOConstToJSString.cpp:203` | ⚠️ |
| `OOConstantFromJSStringPRIVATE` (206) | folded into `OOConstantFromJSValuePRIVATE` `Core/Scripting/OOConstToJSString.cpp:229` (atom comparison) | ✅ |
| `OOConstantFromJSValuePRIVATE` (233) | `OOConstantFromJSValuePRIVATE` `Core/Scripting/OOConstToJSString.cpp:229` | ✅ |

**Differences:**

- ⚠️ **low** — binary search now uses signed bounds: a value below the smallest table entry returns `"UNDEFINED"`; upstream's `NSUInteger max = mid - 1` underflowed and the loop read past the table (undefined behaviour, garbage string or crash). Code comment :210-211 says so; changed since 2026-10-27 (the previous audit saw the bug kept on both sides) — upstream `Core/Scripting/OOConstToJSString.m:189-201` ↔ port `Core/Scripting/OOConstToJSString.cpp:210-224`
- ✅ subtle — strings are runtime atoms interned once per process (`sAtomsInterned`), not per-context interned JSStrings; lookups compare atoms, which is equivalent to upstream's pointer pass plus `JS_CompareStrings` pass. Numeric-looking names become integer atoms on both the table and lookup sides, so they still match. A failed `JS_ValueToAtom` clears its exception and returns the default — port `:155-170,236-256`

## OOJSCall

<a id="oojscall"></a>
Upstream `src/Core/Scripting/OOJSCall.m` ↔ `Core/Scripting/OOJSCall.cpp` (229 / 327 lines)

**Status:** done — 8 rows: 1 ✅ 1 ⚠️ 1 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOJSCallObjCObjectMethod` (66) | `CallMethod` `Core/Scripting/OOJSCall.cpp:120`, entry `OOJSCallEntityMethod` :320 | ⚠️ |
| `OOJSCallObjCObjectMethod` parameter join via `+concatenationOfStringsFromJavaScriptValues:` (89-92) | inline join `Core/Scripting/OOJSCall.cpp:150-162` | ❌ |
| `MethodExpectsParameter` (64) | `MethodExpectsParameter` `Core/Scripting/OOJSCall.cpp:77` | ✅ |
| `SignatureMatch` (186) | — (signatures precomputed in generated `kOOJSCallEntityMethods`, `OOJSCallEntityMethods.h`) | ➖ |
| `GetMethodType` (194) | `MethodTypeOfRow` `Core/Scripting/OOJSCall.cpp:95` (reads the table row's form/encoding) | ➖ |
| `-[OOJSCallMethodSignatureTemplateClass voidVoidMethod]` (214) | — (`OOJSCallEntityMethodForm::kVoidVoid`) | ➖ |
| `-[OOJSCallMethodSignatureTemplateClass voidObjectMethod:]` (218) | — (`OOJSCallEntityMethodForm::kVoidString`) | ➖ |
| `-[OOJSCallMethodSignatureTemplateClass objectObjectMethod:]` (222) | — (`OOJSCallEntityMethodForm::kPListString`) | ➖ |

**Differences:**

- ⚠️ **med** — `callObjC()` now reaches only entities (and the console's own monitor table): a name must be in the generated `kOOJSCallEntityMethods` table and answered by `oo::EntityRespondsToName`; any selector missing from the table reports "does not respond". Upstream reached any native object and any selector (comment :112-119; still open) — upstream `Core/Scripting/OOJSCall.m:97` ↔ port `Core/Scripting/OOJSCall.cpp:164-166`
- ❌ **low** — parameter join: upstream left the parameter nil when the first argument's `toString` failed and raised (`appendString:nil`) when a later one failed; the port substitutes `""` and carries on (still open) — upstream `Core/Scripting/OOJavaScriptEngine.m:1648-1655` ↔ port `Core/Scripting/OOJSCall.cpp:156-160`
- ✅ subtle — the `OO_DEBUG` `kPlayerMethods` statistics pre-dispatch noted on 2026-10-27 is gone together with the vector/quaternion statistics (`Core/Scripting/README.md` "Known behaviour differences"), so those names now report "does not respond" (changed since 2026-10-27).
- ✅ subtle — colour results (`kMethodTypeColorVoid`, `_bool` → false), integer widening through signed/unsigned 64-bit, float via double, error texts and the `setScriptTarget:` side effect before the selector is read all match upstream — port `Core/Scripting/OOJSCall.cpp:130-145,201-299`

## OOJSClock

<a id="oojsclock"></a>
Upstream `src/Core/Scripting/OOJSClock.m` ↔ `Core/Scripting/OOJSClock.cpp` (229 / 255 lines)

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sClockProperties` (75) | `sClockProperties` `Core/Scripting/OOJSClock.cpp:75` (13 entries, all `OOJS_PROPERTY_RO`, same order) | ✅ |
| `sClockMethods` (92) | `sClockMethods` `Core/Scripting/OOJSClock.cpp:101` (`toString` 0, `clockStringForTime` 1, `addSeconds` 1) | ✅ |
| `InitOOJSClock` (100) | `InitOOJSClock` `Core/Scripting/OOJSClock.cpp:109` | ✅ |
| `ClockGetProperty` (106) | `ClockGetProperty` `Core/Scripting/OOJSClock.cpp:122` | ✅ |
| `JSClockToString` (175) | `JSClockToString` `Core/Scripting/OOJSClock.cpp:196` | ✅ |
| `ClockClockStringForTime` (185) | `ClockClockStringForTime` `Core/Scripting/OOJSClock.cpp:207` | ✅ |
| `ClockAddSeconds` (205) | `ClockAddSeconds` `Core/Scripting/OOJSClock.cpp:229` | ✅ |

**Differences:**

- ✅ subtle — units and types match case by case: `absoluteSeconds` = `Universe getTime`; `seconds`/`adjustedSeconds` doubles; `minutes`/`hours` `floor()` doubles; `*Component` and `days` truncated to int32 through `JS_NewInt32(double)` as `INT_TO_JSVAL` did (comment :129-131); `days` and `daysComponent` share one case; `legacy_scriptTimer` keeps the deprecation text. The global `clock` is non-writable, non-configurable, enumerable as `OOJS_PROP_READONLY` — port `Core/Scripting/OOJSClock.cpp:109-191`
- ✅ subtle — bad arguments report `Clock`/`"number"` with the argument or `undefined`; a throwing `ToNumber` has its exception cleared before the report (upstream's `JS_ValueToNumber` failure also led to the report). `addSeconds` limits (>30 days, <1 s, non-finite → false) unchanged. With no player the port answers `""` where upstream's nil message gave null; `OOPlayerForScripting()` is never nil while scripts run — port `:196-254`

## OOJSDock

<a id="oojsdock"></a>
Upstream `src/Core/Scripting/OOJSDock.m` ↔ `Core/Scripting/OOJSDock.cpp` (267 / 273 lines)

**Status:** done — 10 rows: 9 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sDockProperties` (66) | `sDockProperties` `Core/Scripting/OOJSDock.cpp:62` (3 RW + 2 RO, same order) | ✅ |
| `sDockMethods` (76) | `sDockMethods` `Core/Scripting/OOJSDock.cpp:76` (`isQueued`, 1) | ✅ |
| `InitOOJSDock` (82) | `InitOOJSDock` `Core/Scripting/OOJSDock.cpp:81` | ✅ |
| `JSDockGetDockEntity` (89) | `JSDockGetDockEntity` `Core/Scripting/OOJSDock.cpp:103` | ✅ |
| `JSDockGetShipEntity` (113) | `JSDockGetShipEntity` `Core/Scripting/OOJSDock.cpp:126` | ✅ |
| `-[DockEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (139) | `DockEntity::jsClassID` `Core/Entities/DockEntity.cpp:218` → `JSDockClassID` `Core/Scripting/OOJSDock.cpp:97` | ✅ |
| `-[DockEntity(OOJavaScriptExtensions) oo_jsClassName]` (145) | `OOJSDockJSClassName` `Core/Scripting/OOJSDock.cpp:149` (via `Core/Entities/DockEntity.cpp:225`) | ✅ |
| `DockGetProperty` (152) | `DockGetProperty` `Core/Scripting/OOJSDock.cpp:151` | ✅ |
| `DockSetProperty` (195) | `DockSetProperty` `Core/Scripting/OOJSDock.cpp:195` | ✅ |
| `DockIsQueued` (246) | `DockIsQueued` `Core/Scripting/OOJSDock.cpp:244` | ⚠️ |

**Differences:**

- ⚠️ **low** — `isQueued()` with a non-Dock `this` or a non-entity object argument: upstream ignored the error `OOJSEntityGetEntity` left pending and returned `false`; the port returns `JS_EXCEPTION` at once (comment :250-251 "SpiderMonkey tolerated returning normally with an error pending; QuickJS does not"). A non-object argument is now treated as no ship (upstream applied `JSVAL_TO_OBJECT` to a primitive, undefined behaviour) (comment :258-259) — upstream `Core/Scripting/OOJSDock.m:252-262` ↔ port `Core/Scripting/OOJSDock.cpp:250-264`
- ✅ subtle — `oo::ToDock`/`oo::ToShip` replace `isKindOfClass:`; a stale entity still fails the lookup. Converter is `OOJSEntityObjectConverter` (entity node) instead of `OOJSBasicPrivateObjectConverter`; both yield the entity. Error texts (`"Dock"`, `"isQueued"`, `"ship"`) identical; bad setter values cannot occur (`JS_ToBool` only fails on exception).

## OOJSEngineDebuggerHelpers

<a id="oojsenginedebuggerhelpers"></a>
Upstream `src/Core/Scripting/OOJSEngineDebuggerHelpers.m` ↔ `Core/Scripting/OOJSEngineDebuggerHelpers.cpp` (235 / 229 lines)

**Status:** done — 8 rows: 5 ✅ 3 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `JSValueToStrDbg` (85) | `JSValueToStrDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:110` | ✅ |
| `JSObjectToStrDbg` (94) | `JSObjectToStrDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:120` | ✅ |
| `JSStringToStrDbg` (101) | `JSStringToStrDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:122` | ✅ |
| `JSValueTypeDbg` (108) | `JSValueTypeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:124` | ⚠️ |
| `JSValueToStrSafeDbg` (155) | `JSValueToStrSafeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:163` | ⚠️ |
| `JSObjectToStrSafeDbg` (187) | `JSObjectToStrSafeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:205` | ✅ |
| `JSStringToStrSafeDbg` (194) | `JSStringToStrSafeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:209` | ✅ |
| `JSIDToStrSafeDbg` (201) | `JSIDToStrSafeDbg` `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:213` | ⚠️ |

**Differences:** (debugger-only helpers; file rewritten directly on QuickJS since 2026-10-27, documented in the file comment "Changes from the SpiderMonkey version")

- ⚠️ **low** — `JSValueTypeDbg`: SpiderMonkey magic values replaced by QuickJS tags (`magic (uninitialized)`, `symbol`, `bigint`…); objects report the Oolite-registered class name, else `"object"` (upstream gave SpiderMonkey's class name for built-ins too, e.g. `Array`) — upstream `Core/Scripting/OOJSEngineDebuggerHelpers.m:108-152` ↔ port `Core/Scripting/OOJSEngineDebuggerHelpers.cpp:124-160`
- ⚠️ **low** — `JSValueToStrSafeDbg` acquires a context and reads every string (`JS_ToCStringLen`); upstream showed only interned strings and otherwise `string [%zu chars]`, never touching the engine. Unreadable strings now read `string [unreadable]` — upstream `.m:155-184` ↔ port `.cpp:163-202`
- ⚠️ **low** — `JSIDToStrSafeDbg`: SpiderMonkey's empty/zero/object/XML-namespace id kinds and `*** uninterned string in jsid! ***` are gone; atoms are printed with `JS_AtomToCString` (int atoms as digits), `JS_ATOM_NULL` → `void`, failure → `unknown <0x%X>` of the atom — upstream `.m:201-232` ↔ port `.cpp:213-228`
- Subtle — all results come from one static `std::string` (`DebuggerCString`, :103-108), so each call invalidates the previous result; the Object/String variants no longer special-case a NULL pointer (a `JS_NULL` value prints `null` anyway).

## OOJSEngineTimeManagement

<a id="oojsenginetimemanagement"></a>
Upstream `src/Core/Scripting/OOJSEngineTimeManagement.m` ↔ `Core/Scripting/OOJSEngineTimeManagement.cpp` (923 / 460 lines)

**Status:** done — 58 rows: 42 ✅ 5 ⚠️ 1 ❌ 10 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOJSStartTimeLimiterWithTimeLimit_` / `OOJSStartTimeLimiterWithTimeLimit` (80-102) | `OOJSStartTimeLimiterWithTimeLimit` `Core/Scripting/OOJavaScriptEngine.cpp:651` | ⚠️ |
| `OOJSStopTimeLimiter_` / `OOJSStopTimeLimiter` (105-127) | `OOJSStopTimeLimiter` `Core/Scripting/OOJavaScriptEngine.cpp:660` | ⚠️ |
| `OOJSPauseTimeLimiter` (129) | `OOJSPauseTimeLimiter` `Core/Scripting/OOJavaScriptEngine.cpp:671` | ✅ |
| `OOJSResumeTimeLimiter` (137) | `OOJSResumeTimeLimiter` `Core/Scripting/OOJavaScriptEngine.cpp:675` | ✅ |
| `OOJSCopyTimeLimiterNominalStartTime` (151) | — (no caller upstream or in the port) | ➖ |
| `OOJSResetTimeLimiter` (156) | `OOJSResetTimeLimiter` `Core/Scripting/OOJavaScriptEngine.cpp:681` (no `sStop` to clear) | ✅ |
| `OOJSGetTimeLimiterLimit` (164) | `OOJSGetTimeLimiterLimit` `Core/Scripting/OOJavaScriptEngine.cpp:683` | ✅ |
| `OOJSSetTimeLimiterLimit` (169) | `OOJSSetTimeLimiterLimit` `Core/Scripting/OOJavaScriptEngine.cpp:685` | ✅ |
| `-[OOJavaScriptEngine(WatchdogTimer) watchdogTimerThread]` (177) | — removed; QuickJS interrupt handler polled on the JS thread (comment `Core/Scripting/OOJSEngineTimeManagement.cpp:46-57`, `.h:72-79`) | ➖ |
| `OperationCallback` (204) | `InterruptHandler` `Core/Scripting/OOJavaScriptEngine.cpp:702` (installed :176) | ❌ |
| `ContextCallback` (228) | — (no per-context callback; handler is per runtime) | ➖ |
| `OOJSTimeManagementInit` (240) | `OOJSTimeManagementInit` `Core/Scripting/OOJSEngineTimeManagement.cpp:59` (empty) | ⚠️ |
| `OOJSBeginProfiling` (293) | `OOJSBeginProfiling` `Core/Scripting/OOJSEngineTimeManagement.cpp:86` | ✅ |
| `OOJSEndProfiling` (313) | `OOJSEndProfiling` `Core/Scripting/OOJSEngineTimeManagement.cpp:106` | ✅ |
| `OOJSIsProfiling` (354) | `OOJSIsProfiling` `Core/Scripting/OOJSEngineTimeManagement.cpp:153` | ✅ |
| `CleanUpJSFrame` (366) | — removed (no `MOZ_TRACE_JSCALLS` support) | ➖ |
| `TraceEnterJSFunction` (371) | — removed (no `MOZ_TRACE_JSCALLS` support) | ➖ |
| `FunctionCallback` (430) | — removed (QuickJS has no function call hook, `.h` comment) | ➖ |
| `OOJSProfileEnter` (490) | `OOJSProfileEnter` `Core/Scripting/OOJSEngineTimeManagement.cpp:160` | ✅ |
| `OOJSProfileExit` (510) | `OOJSProfileExit` `Core/Scripting/OOJSEngineTimeManagement.cpp:178` (+ `OOJSExcludeTimeFromLimiter` `Core/Scripting/OOJavaScriptEngine.cpp:689`) | ✅ |
| `UpdateProfileForFrame` (553) | `UpdateProfileForFrame` `Core/Scripting/OOJSEngineTimeManagement.cpp:214` | ✅ |
| `-[OOTimeProfile dealloc]` (581) | implicit (`std::vector<std::shared_ptr<…>>` member, `Core/Scripting/OOJSEngineTimeManagement.h:154`) | ➖ |
| `-[OOTimeProfile description]` (588) | `OOTimeProfile::description` `Core/Scripting/OOJSEngineTimeManagement.cpp:237` | ✅ |
| `-[OOTimeProfile totalTime]` (624) | `OOTimeProfile::totalTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:273` | ✅ |
| `-[OOTimeProfile setTotalTime:]` (629) | `OOTimeProfile::setTotalTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:275` | ✅ |
| `-[OOTimeProfile javaScriptTime]` (634) | `OOTimeProfile::javaScriptTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:277` | ⚠️ |
| `-[OOTimeProfile setJavaScriptTime:]` (644) | — removed (MOZ_TRACE_JSCALLS only) | ➖ |
| `-[OOTimeProfile nativeTime]` (650) | `OOTimeProfile::nativeTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:279` | ✅ |
| `-[OOTimeProfile setNativeTime:]` (655) | `OOTimeProfile::setNativeTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:281` | ✅ |
| `-[OOTimeProfile extensionTime]` (660) | `OOTimeProfile::extensionTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:283` | ✅ |
| `-[OOTimeProfile setExtensionTime:]` (665) | `OOTimeProfile::setExtensionTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:285` | ✅ |
| `-[OOTimeProfile nonExtensionTime]` (670) | `OOTimeProfile::nonExtensionTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:287` | ✅ |
| `-[OOTimeProfile profilerOverhead]` (675) | `OOTimeProfile::profilerOverhead` `Core/Scripting/OOJSEngineTimeManagement.cpp:289` | ✅ |
| `-[OOTimeProfile setProfilerOverhead:]` (680) | `OOTimeProfile::setProfilerOverhead` `Core/Scripting/OOJSEngineTimeManagement.cpp:291` | ✅ |
| `-[OOTimeProfile profileEntries]` (685) | `OOTimeProfile::profileEntries` `Core/Scripting/OOJSEngineTimeManagement.cpp:295` | ✅ |
| `-[OOTimeProfile setProfileEntries:]` (690) | `OOTimeProfile::setProfileEntries` `Core/Scripting/OOJSEngineTimeManagement.cpp:300` | ✅ |
| `-[OOTimeProfile oo_jsValueInContext:]` (698) | `OOTimeProfile::oo_jsValueInContext` `Core/Scripting/OOJSEngineTimeManagement.cpp:305` | ✅ |
| `-[OOTimeProfile propertyListRepresentation]` (703) | `OOTimeProfile::propertyListRepresentation` `Core/Scripting/OOJSEngineTimeManagement.cpp:309` | ✅ |
| `-[OOTimeProfileEntry initWithCName:]` (727) | `OOTimeProfileEntry::OOTimeProfileEntry(const char*)` `Core/Scripting/OOJSEngineTimeManagement.cpp:327` | ✅ |
| `-[OOTimeProfileEntry initWithJSFunction:context:]` (741) | — removed (MOZ_TRACE_JSCALLS only) | ➖ |
| `-[OOTimeProfileEntry dealloc]` (776) | implicit (`std::optional<std::string>` member, `Core/Scripting/OOJSEngineTimeManagement.h:188`) | ➖ |
| `-[OOTimeProfileEntry addSampleWithTotalTime:selfTime:]` (783) | `OOTimeProfileEntry::addSampleWithTotalTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:337` | ✅ |
| `-[OOTimeProfileEntry description]` (792) | `OOTimeProfileEntry::description` `Core/Scripting/OOJSEngineTimeManagement.cpp:346` | ✅ |
| `-[OOTimeProfileEntry function]` (818) | `OOTimeProfileEntry::function` `Core/Scripting/OOJSEngineTimeManagement.cpp:381` | ✅ |
| `-[OOTimeProfileEntry hitCount]` (823) | `OOTimeProfileEntry::hitCount` `Core/Scripting/OOJSEngineTimeManagement.cpp:383` | ✅ |
| `-[OOTimeProfileEntry totalTimeSum]` (828) | `OOTimeProfileEntry::totalTimeSum` `Core/Scripting/OOJSEngineTimeManagement.cpp:385` | ✅ |
| `-[OOTimeProfileEntry selfTimeSum]` (833) | `OOTimeProfileEntry::selfTimeSum` `Core/Scripting/OOJSEngineTimeManagement.cpp:387` | ✅ |
| `-[OOTimeProfileEntry totalTimeAverage]` (838) | `OOTimeProfileEntry::totalTimeAverage` `Core/Scripting/OOJSEngineTimeManagement.cpp:389` | ✅ |
| `-[OOTimeProfileEntry selfTimeAverage]` (843) | `OOTimeProfileEntry::selfTimeAverage` `Core/Scripting/OOJSEngineTimeManagement.cpp:393` | ✅ |
| `-[OOTimeProfileEntry totalTimeMax]` (848) | `OOTimeProfileEntry::totalTimeMax` `Core/Scripting/OOJSEngineTimeManagement.cpp:397` | ✅ |
| `-[OOTimeProfileEntry selfTimeMax]` (853) | `OOTimeProfileEntry::selfTimeMax` `Core/Scripting/OOJSEngineTimeManagement.cpp:399` | ✅ |
| `-[OOTimeProfileEntry isJavaScriptFrame]` (858) | `OOTimeProfileEntry::isJavaScriptFrame` `Core/Scripting/OOJSEngineTimeManagement.cpp:401` | ⚠️ |
| `-[OOTimeProfileEntry compareByTotalTime:]` (867) | `OOTimeProfileEntry::compareByTotalTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:403` | ✅ |
| `-[OOTimeProfileEntry compareByTotalTimeReverse:]` (872) | `OOTimeProfileEntry::compareByTotalTimeReverse` `Core/Scripting/OOJSEngineTimeManagement.cpp:409` | ✅ |
| `-[OOTimeProfileEntry compareBySelfTime:]` (884) | `OOTimeProfileEntry::compareBySelfTime` `Core/Scripting/OOJSEngineTimeManagement.cpp:420` | ✅ |
| `-[OOTimeProfileEntry compareBySelfTimeReverse:]` (889) | `OOTimeProfileEntry::compareBySelfTimeReverse` `Core/Scripting/OOJSEngineTimeManagement.cpp:426` | ✅ |
| `-[OOTimeProfileEntry oo_jsValueInContext:]` (901) | `OOTimeProfileEntry::oo_jsValueInContext` `Core/Scripting/OOJSEngineTimeManagement.cpp:437` | ✅ |
| `-[OOTimeProfileEntry propertyListRepresentation]` (906) | `OOTimeProfileEntry::propertyListRepresentation` `Core/Scripting/OOJSEngineTimeManagement.cpp:441` | ✅ |

**Differences:**

- ❌ **med** — the limit is now enforced exactly: QuickJS calls `InterruptHandler` about every 10k ops and it kills as soon as `elapsed > sLimiterTimeLimit`. Upstream only checked when the watchdog woke, once every `OOJS_TIME_LIMIT` (1 s release, 0.2 s debug) regardless of the script's own limit, so a 1 s script could run up to ~2 s and a frame callback (limit 0.1 s, `OOJSFrameCallbacks.cpp:192`) was killed only if a tick landed while it ran. Slow scripts and heavy frame callbacks that survived upstream are now terminated (new; the 2026-10-27 audit compared only QuickJS polling granularity) — upstream `Core/Scripting/OOJSEngineTimeManagement.m:177-226` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:702-718`
- ✅ **fixed since 2026-10-27** — the watchdog-thread data race on `rs->contexts` (`triggerAllOperationCallbacks` without a lock during engine reset) is gone: there is no watchdog thread any more; the handler runs on the JS thread — port `Core/Scripting/OOJSEngineTimeManagement.cpp:46-62`, `Core/Scripting/OOJavaScriptEngine.cpp:176,698-718`
- ⚠️ **low** — debug builds: the file/line bookkeeping and the `script.javaScript.timeLimit.debug` "Limiter starting/ending" logs (`OO_DEBUG`) are gone; the `bug.javaScript.limiterDepth` text loses its "(Last start: …)" tail. Release builds now also guard an unbalanced stop (upstream underflowed `sLimiterStartDepth`) (header comment `.h:81-84`) — upstream `.m:80-127` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:651-669`
- ✅ subtle — kill log keeps class `script.javaScript.timeLimit` and the text "Script \"%@\" ran for %g seconds and has been terminated." (`{:g}`; nil name → `(null)`); the abort is uncatchable (handler returns 1) as SpiderMonkey's callback returning false. `OOJSDumpStack` is given the main-thread context instead of the running context — port `Core/Scripting/OOJavaScriptEngine.cpp:708-717`
- ⚠️ **low** — JavaScript-function profiling and tracing are gone (no `MOZ_TRACE_JSCALLS`, which upstream meson enabled by default per the 2026-10-27 audit): profiles/traces show only native `[ON]` entries, `javaScriptTime` = total − native, `isJavaScriptFrame` always false, and `FunctionCallback`/`TraceEnterJSFunction`/`CleanUpJSFrame`/`initWithJSFunction:`/`setJavaScriptTime:` are now deleted rather than compiled out (comment `.cpp:55-56`, `.h` "only natives are profiled") (still open) — upstream `.m:365-488,634-648,740-774,858-865` ↔ port `.cpp:277,401`
- ✅ subtle — `OOJSProfileExit` ignores a frame not on the profile stack (entered before profiling began); upstream would have popped until an assert. `OOJSExcludeTimeFromLimiter` keeps the pause-depth rule. Entries come from `std::unordered_map` then a stable descending sort on self time (ties arbitrary in both). `description` formats `%60s`/`%7lu`/`%8.2f`/`%5.1f` as `{:>60}`/`{:7}`/`{:8.2f}`/`{:5.1f}` — port `.cpp:178-211,125-134,237-271`
- Subtle — `OOTimeProfile::propertyListRepresentation` builds `"profiles"` from each entry's plist (upstream stored the raw entries, converted later: same JS result); keys come out of the `oo::PList::Dict` order rather than NSDictionary hash order, so JS property enumeration order of the profile object may differ (still open) — upstream `.m:703-721` ↔ port `.cpp:309-325`

## OOJSEntity

<a id="oojsentity"></a>
Upstream `src/Core/Scripting/OOJSEntity.m` ↔ `Core/Scripting/OOJSEntity.cpp` (388 / 471 lines)

**Status:** done — 8 rows: 8 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sEntityProperties` (89) | `sEntityProperties` `Core/Scripting/OOJSEntity.cpp:95` (25 entries; same names, order, RO/RW flags) | ✅ |
| `sEntityMethods` (117) | `sEntityMethods` `Core/Scripting/OOJSEntity.cpp:138` (`toString` 0 → `OOJSEntityToString` :173; `dumpState` 0 under `OO_DEBUG_MONITOR_ENABLED`) | ✅ |
| `InitOOJSEntity` (127) | `InitOOJSEntity` `Core/Scripting/OOJSEntity.cpp:148` (converter `OOJSEntityObjectConverter` :188) | ✅ |
| `JSValueToEntity` (133) | `JSValueToEntity` `Core/Scripting/OOJSEntity.cpp:214` | ✅ |
| `EntityFromArgumentList` (142) | `EntityFromArgumentList` `Core/Scripting/OOJSEntity.cpp:223` | ✅ |
| `EntityGetProperty` (171) | `EntityGetProperty` `Core/Scripting/OOJSEntity.cpp:259` | ✅ |
| `EntitySetProperty` (296) | `EntitySetProperty` `Core/Scripting/OOJSEntity.cpp:370` | ✅ |
| `EntityDumpState` (376) | `EntityDumpState` `Core/Scripting/OOJSEntity.cpp:460` | ✅ |

**Differences:**

- ✅ subtle — stale entity: getter answers `false` for `isValid`, `undefined` otherwise; setter returns silently, as upstream — upstream `Core/Scripting/OOJSEntity.m:183-190,310-311` ↔ port `Core/Scripting/OOJSEntity.cpp:267-272,380`
- ✅ subtle — `owner` gives null for self-owned or script-invisible owners (`ownerEntity()` + `OOJSValueFromCxxObject`). The unreachable `default:` case now throws after reporting the bad selector; upstream reported and then returned `null` with success (changed since 2026-10-27; magic IDs come only from the table, so not observable) — upstream `:216-220,286-291` ↔ port `:300-304,357-365`
- ✅ subtle — setter error texts identical ("entity.maxEnergy must be positive.", "entity.scanClass cannot be set to that value.", "entity.scanClass is read-only except on NPC ships."); same forbidden scan classes; energy clamped to [0, maxEnergy]; a throwing `ToNumber` is cleared and reported as a bad value as upstream's failed `JS_ValueToNumber` was — port `:405-445`
- ✅ subtle — `EntityFromArgumentList` keeps upstream's fall-through: without a class/function name a failed conversion still returns true with `*outConsumed = 1`; the warning text uses `OOJSDescribeValue` wrapped in parentheses as `+stringWithJavaScriptParameters:count:1` did — port `:238-254`

## OOJSEquipmentInfo

<a id="oojsequipmentinfo"></a>
Upstream `src/Core/Scripting/OOJSEquipmentInfo.m` ↔ `Core/Scripting/OOJSEquipmentInfo.cpp` (528 / 686 lines)

**Status:** done — 17 rows: 15 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sEquipmentInfoProperties` (85) | `sEquipmentInfoProperties` `Core/Scripting/OOJSEquipmentInfo.cpp:141` (38 entries; `displayColor`/`effectiveTechLevel` RW, rest RO; same order) | ✅ |
| `sEquipmentInfoStaticProperties` (126) | `allEquipment` RO entry in `sEquipmentInfoStaticMethods` `Core/Scripting/OOJSEquipmentInfo.cpp:230` | ✅ |
| `sEquipmentInfoMethods` (131) | `sEquipmentInfoMethods` `Core/Scripting/OOJSEquipmentInfo.cpp:223` (`toString` 0 → `EquipmentInfoToString` :683) | ✅ |
| `sEquipmentInfoStaticMethods` (137) | `sEquipmentInfoStaticMethods` `Core/Scripting/OOJSEquipmentInfo.cpp:228` (`infoForKey` 0) | ✅ |
| `InitOOJSEquipmentInfo` (162) | `InitOOJSEquipmentInfo` `Core/Scripting/OOJSEquipmentInfo.cpp:255` (converter `EquipmentInfoConverter` :246) | ✅ |
| `JSValueToEquipmentType` (169) | `JSValueToEquipmentType` `Core/Scripting/OOJSEquipmentInfo.cpp:266` | ✅ |
| `JSValueToEquipmentKey` (188) | `JSValueToEquipmentKey` `Core/Scripting/OOJSEquipmentInfo.cpp:287` | ✅ |
| `JSValueToEquipmentKeyRelaxed` (193) | `JSValueToEquipmentKeyRelaxed` `Core/Scripting/OOJSEquipmentInfo.cpp:293` | ✅ |
| `EquipmentInfoGetProperty` (224) | `EquipmentInfoGetProperty` `Core/Scripting/OOJSEquipmentInfo.cpp:326` | ✅ |
| `EquipmentInfoGetProperty`, `provides` case (301) | `Core/Scripting/OOJSEquipmentInfo.cpp:423-427` | ❌ |
| `EquipmentInfoGetProperty`, `requiresEquipment`/`requiresAnyEquipment`/`incompatibleEquipment` (373-383) | `Core/Scripting/OOJSEquipmentInfo.cpp:491-503` via `KeyArrayOrNull` :78 | ⚠️ |
| `EquipmentInfoSetProperty` (414) | `EquipmentInfoSetProperty` `Core/Scripting/OOJSEquipmentInfo.cpp:534` | ✅ |
| `EquipmentInfoGetAllEqipment` (471) | `EquipmentInfoGetAllEqipment` `Core/Scripting/OOJSEquipmentInfo.cpp:605` | ✅ |
| `-[OOEquipmentType(OOJavaScriptExtensions) oo_jsValueInContext:]` (483) | `OOEquipmentType::jsValueInContext` `Core/Scripting/OOJSEquipmentInfo.cpp:621` | ✅ |
| `-[OOEquipmentType(OOJavaScriptExtensions) oo_jsClassName]` (496) | `OOJSEquipmentInfoJSClassName` `Core/Scripting/OOJSEquipmentInfo.cpp:657` | ✅ |
| `-[OOEquipmentType(OOJavaScriptExtensions) oo_clearJSSelf:]` (501) | `OOEquipmentType::clearJSSelf` `Core/Scripting/OOJSEquipmentInfo.cpp:642` | ✅ |
| `EquipmentInfoStaticInfoForKey` (512) | `EquipmentInfoStaticInfoForKey` `Core/Scripting/OOJSEquipmentInfo.cpp:664` | ✅ |

**Differences:**

- ❌ **med** — `EquipmentInfo.provides` returns `[]` instead of `null` for equipment without the optional extra-info entry: upstream set `_provides` only inside `if (extra != nil)` so `[nil copy]` gave JS `null`; the port's `providesForScripting()` returns a `std::vector`, always an array. Scripts testing `eq.provides` for `null`/truthiness of the array behave differently (still open) — upstream `Core/Scripting/OOJSEquipmentInfo.m:301-303`, `Core/OOEquipmentType.m:240,629-632` ↔ port `Core/Scripting/OOJSEquipmentInfo.cpp:423-427`, `Core/OOEquipmentType.cpp:582-584`
- ⚠️ **low** — `requiresEquipment`, `requiresAnyEquipment`, `incompatibleEquipment` come back as sorted key arrays instead of `NSSet -allObjects` hash order; membership unchanged (comment :75-77; still open) — upstream `.m:373-383` ↔ port `.cpp:78-81,491-503`
- ✅ note — `effectiveTechLevel` setter: deprecation text, `(null)` for a nil identifier, SpiderMonkey-style `JS_ValueToInt32` rounding/error via `OOJSValueToInt32`, the 0..15 clamp keeping 99, `%u` mission-variable format and the warning text match. `calculatedPrice` keeps `(PLAYER_MAX_FUEL - fuel) * price * fuelChargeRate` and the `EQ_RENOVATION` branch; `installationTime` keeps `price + 600`; `scriptInfo`/`weaponInfo`/`scriptName` keep `{}`/`""` fallbacks. The prototype (null type) answers what nil messaging gave (`Ask`, :63-68).

## OOJSExhaustPlume

<a id="oojsexhaustplume"></a>
Upstream `src/Core/Scripting/OOJSExhaustPlume.m` ↔ `Core/Scripting/OOJSExhaustPlume.cpp` (214 / 201 lines)

**Status:** done — 10 rows: 10 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sExhaustPlumeProperties` (61) | `sExhaustPlumeProperties` `Core/Scripting/OOJSExhaustPlume.cpp:58` (`size` RW) | ✅ |
| `sExhaustPlumeMethods` (67) | `sExhaustPlumeMethods` `Core/Scripting/OOJSExhaustPlume.cpp:64` (`remove` 0) | ✅ |
| `InitOOJSExhaustPlume` (74) | `InitOOJSExhaustPlume` `Core/Scripting/OOJSExhaustPlume.cpp:69` | ✅ |
| `JSExhaustPlumeGetExhaustPlumeEntity` (81) | `JSExhaustPlumeGetExhaustPlumeEntity` `Core/Scripting/OOJSExhaustPlume.cpp:87` | ✅ |
| `-[OOExhaustPlumeEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (107) | `JSExhaustPlumeClassID` `Core/Scripting/OOJSExhaustPlume.cpp:85` (via `Core/Entities/OOExhaustPlumeEntity.cpp:677`) | ✅ |
| `-[OOExhaustPlumeEntity(OOJavaScriptExtensions) oo_jsClassName]` (113) | `OOJSExhaustPlumeJSClassName` `Core/Scripting/OOJSExhaustPlume.cpp:112` | ✅ |
| `-[OOExhaustPlumeEntity(OOJavaScriptExtensions) isVisibleToScripts]` (118) | `OOJSExhaustPlumeIsVisibleToScripts` `Core/Scripting/OOJSExhaustPlume.cpp:116` | ✅ |
| `ExhaustPlumeGetProperty` (125) | `ExhaustPlumeGetProperty` `Core/Scripting/OOJSExhaustPlume.cpp:118` | ✅ |
| `ExhaustPlumeSetProperty` (157) | `ExhaustPlumeSetProperty` `Core/Scripting/OOJSExhaustPlume.cpp:146` | ✅ |
| `ExhaustPlumeRemove` (201) | `ExhaustPlumeRemove` `Core/Scripting/OOJSExhaustPlume.cpp:189` | ✅ |

**Differences:**

- ✅ subtle — a wrong-class `this` returns false with no exception on both sides; the port's `OOJSNativeFailure` then throws an uncatchable error, matching SpiderMonkey's silent abort on a false return (`Core/Scripting/OOJavaScriptEngine.cpp:923-930`). `size` getter/setter use `scale()`/`setScale` with `JSValueToVector`, bad values reported — port `:118-185`
- ✅ subtle — `remove()`: upstream messaged `[thisEnt owner]` typed as `ShipEntity*`; the port uses `oo::ToShip(owner())` with a null guard; a nil owner is a no-op in both, and a non-ship owner (never happens) would have raised upstream — upstream `:208-209` ↔ port `:195-196`

## OOJSFlasher

<a id="oojsflasher"></a>
Upstream `src/Core/Scripting/OOJSFlasher.m` ↔ `Core/Scripting/OOJSFlasher.cpp` (290 / 297 lines)

**Status:** done — 10 rows: 10 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sFlasherProperties` (66) | `sFlasherProperties` `Core/Scripting/OOJSFlasher.cpp:78` (6 RW, same order) | ✅ |
| `sFlasherMethods` (77) | `sFlasherMethods` `Core/Scripting/OOJSFlasher.cpp:94` (`remove` 0) | ✅ |
| `InitOOJSFlasher` (85) | `InitOOJSFlasher` `Core/Scripting/OOJSFlasher.cpp:99` | ✅ |
| `JSFlasherGetFlasherEntity` (92) | `JSFlasherGetFlasherEntity` `Core/Scripting/OOJSFlasher.cpp:117` | ✅ |
| `-[OOFlasherEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (118) | `JSFlasherClassID` `Core/Scripting/OOJSFlasher.cpp:115` (via `Core/Entities/OOFlasherEntity.cpp:169`) | ✅ |
| `-[OOFlasherEntity(OOJavaScriptExtensions) oo_jsClassName]` (124) | `OOJSFlasherJSClassName` `Core/Scripting/OOJSFlasher.cpp:142` | ✅ |
| `-[OOFlasherEntity(OOJavaScriptExtensions) isVisibleToScripts]` (129) | `OOJSFlasherIsVisibleToScripts` `Core/Scripting/OOJSFlasher.cpp:146` | ✅ |
| `FlasherGetProperty` (136) | `FlasherGetProperty` `Core/Scripting/OOJSFlasher.cpp:148` | ✅ |
| `FlasherSetProperty` (185) | `FlasherSetProperty` `Core/Scripting/OOJSFlasher.cpp:192` | ✅ |
| `FlasherRemove` (273) | `FlasherRemove` `Core/Scripting/OOJSFlasher.cpp:279` | ✅ |

**Differences:**

- ✅ subtle — getter types match (`active` boolean; `color` normalized 4-float array or null; `frequency`/`fraction`/`phase` numbers; `size` = `diameter()`); setter ranges match (`frequency >= 0`, `0 < fraction <= 1`, `size > 0`, any `phase`, colour description or `null`); NaN fails each range test and goes to `OOJSReportBadPropertyValue` — port `Core/Scripting/OOJSFlasher.cpp:148-275`
- ✅ subtle — `remove()`: ship owner → `removeFlasher`; otherwise `removeSubEntity` on `oo::ToEffect(owner)` with a null guard; nil owner a no-op in both, a non-ship non-effect owner (never happens) a no-op instead of an unrecognised selector — port `:285-292`

## OOJSFont

<a id="oojsfont"></a>
Upstream `src/Core/Scripting/OOJSFont.m` ↔ `Core/Scripting/OOJSFont.cpp` (57 / 70 lines)

**Status:** done — 2 rows: 2 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitOOJSFont` (36) | `InitOOJSFont` `Core/Scripting/OOJSFont.cpp:42` (`defaultFont` `OOJS_PROP_READONLY`; `measureString` arity 1, `OOJS_METHOD_READONLY`) | ✅ |
| `FontMeasureString` (44) | `FontMeasureString` `Core/Scripting/OOJSFont.cpp:54` | ✅ |

**Differences:**

- ✅ note — `measureString(null)` measures `""` where upstream passed a nil string (width 0 either way); missing/undefined argument reports the same bad-argument text with an `undefined` argv.

## OOJSFrameCallbacks

<a id="oojsframecallbacks"></a>
Upstream `src/Core/Scripting/OOJSFrameCallbacks.m` ↔ `Core/Scripting/OOJSFrameCallbacks.cpp` (435 / 480 lines)

**Status:** done — 13 rows: 13 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitOOJSFrameCallbacks` (113) | `InitOOJSFrameCallbacks` `Core/Scripting/OOJSFrameCallbacks.cpp:157` (+ `sFrameCallbackMethods` :144: three functions, arity 1, `OOJS_METHOD_READONLY`) | ✅ |
| `OOJSFrameCallbacksInvoke` (127) | `OOJSFrameCallbacksInvoke` `Core/Scripting/OOJSFrameCallbacks.cpp:169` | ✅ |
| `OOJSFrameCallbacksRemoveAll` (165) | `OOJSFrameCallbacksRemoveAll` `Core/Scripting/OOJSFrameCallbacks.cpp:219` | ✅ |
| `GlobalAddFrameCallback` (180) | `GlobalAddFrameCallback` `Core/Scripting/OOJSFrameCallbacks.cpp:234` | ✅ |
| `GlobalRemoveFrameCallback` (214) | `GlobalRemoveFrameCallback` `Core/Scripting/OOJSFrameCallbacks.cpp:273` | ✅ |
| `GlobalIsValidFrameCallback` (242) | `GlobalIsValidFrameCallback` `Core/Scripting/OOJSFrameCallbacks.cpp:307` | ✅ |
| `AddCallback` (265) | `AddCallback` `Core/Scripting/OOJSFrameCallbacks.cpp:333` (owned reference instead of a GC root) | ✅ |
| `GrowCallbackList` (296) | `GrowCallbackList` `Core/Scripting/OOJSFrameCallbacks.cpp:357` (`std::vector::reserve`) | ✅ |
| `GetIndexForTrackingID` (343) | `GetIndexForTrackingID` `Core/Scripting/OOJSFrameCallbacks.cpp:375` | ✅ |
| `RemoveCallbackWithTrackingID` (363) | `RemoveCallbackWithTrackingID` `Core/Scripting/OOJSFrameCallbacks.cpp:396` | ✅ |
| `RemoveCallbackAtIndex` (377) | `RemoveCallbackAtIndex` `Core/Scripting/OOJSFrameCallbacks.cpp:412` | ✅ |
| `QueueDeferredOperation` (398) | `QueueDeferredOperation` `Core/Scripting/OOJSFrameCallbacks.cpp:438` | ✅ |
| `RunDeferredOperations` (411) | `RunDeferredOperations` `Core/Scripting/OOJSFrameCallbacks.cpp:451` | ✅ |

**Differences:**

- ✅ note (ordering) — ID scramble constants unchanged (`0x2315EB16`, `992699`), seed from `timeIntervalSinceReferenceDate`; callbacks run in slot order and removal swaps the last entry into the hole, as upstream; callbacks get the global as `this` (upstream's NULL `this`) — port `:79-83,165,194-202,423-425`
- ✅ note (mutation during iteration) — adds/removes while running are queued in order and replayed; an unknown deferred remove is silent; a failed deferred add logs `script.frameCallback.deferredAdd.failed` with the same text. The tracking ID is kept as `uint32_t` rather than round-tripped through `numberWithInt`/`oo_intForKey`, lossless both ways — port `:438-480`
- ✅ note — `addFrameCallback` returns `JS_NewInt32` of the `uint32` as `INT_TO_JSVAL` did (IDs ≥ 2³¹ negative in both); error texts ("function", "frame callback tracking ID", "removeFrameCallback(): invalid tracking ID.") identical. Out-of-memory growth now reports "Failed to allocate space for frame callback." where upstream reported `(null)`.
- See OOJSEngineTimeManagement: the 0.1 s limit set here (:192) is now enforced exactly, where upstream's watchdog rarely caught it.

## OOJSFunction

<a id="oojsfunction"></a>
Upstream `src/Core/Scripting/OOJSFunction.m` ↔ `Core/Scripting/OOJSFunction.cpp` (241 / 217 lines)

**Status:** done — 12 rows: 8 ✅ 0 ⚠️ 1 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJSFunction initWithFunction:context:]` (32) | `OOJSFunction::initWithFunction` `Core/Scripting/OOJSFunction.cpp:41` + ctor :53 | ✅ |
| `-[OOJSFunction initWithName:scope:code:argumentCount:argumentNames:fileName:lineNumber:context:]` (55) | `OOJSFunction::initWithName` `Core/Scripting/OOJSFunction.cpp:74` | ❌ |
| `-[OOJSFunction deleteJSValue]` (114) | `OOJSFunction::deleteJSValue` `Core/Scripting/OOJSFunction.cpp:147` | ✅ |
| `-[OOJSFunction dealloc]` (128) | `OOJSFunction::~OOJSFunction` `Core/Scripting/OOJSFunction.cpp:161` | ✅ |
| `-[OOJSFunction descriptionComponents]` (136) | `OOJSFunction::descriptionComponents` `Core/Scripting/OOJSFunction.cpp:163` | ✅ |
| `-[OOJSFunction name]` (144) | `OOJSFunction::name` `Core/Scripting/OOJSFunction.cpp:167` | ✅ |
| `-[OOJSFunction function]` (149) | `OOJSFunction::function` `Core/Scripting/OOJSFunction.cpp:174` | ✅ |
| `-[OOJSFunction functionValue]` (154) | `OOJSFunction::functionValue` `Core/Scripting/OOJSFunction.cpp:178` | ✅ |
| `-[OOJSFunction evaluateWithContext:scope:argc:argv:result:]` (163) | `OOJSFunction::evaluateWithContext` `Core/Scripting/OOJSFunction.cpp:186` | ✅ |
| `-[OOJSFunction evaluateWithContext:scope:arguments:result:]` (179) | — removed (not declared in `Core/Scripting/OOJSFunction.h`; no caller) | ➖ |
| `-[OOJSFunction evaluateWithContext:scope:arguments:]` (211) | — removed (no caller) | ➖ |
| `-[OOJSFunction evaluatePredicateWithContext:scope:arguments:]` (226) | — removed (the AI scan predicate calls `evaluateWithContext` directly, `Core/Entities/ShipEntityAI.cpp:2453ff`) | ➖ |

**Differences:**

- ❌ **low** — "compile" now evaluates text: the body is spliced into `"(function(args){" + code + "\n})"` and run with `JS_Eval2`, so a body with an unbalanced `}` can close the wrapper and execute code at global scope at compile time (e.g. an AI-plist scan predicate, wrapped as `"return " + expr + ";"`); upstream `JS_CompileUCFunction` parsed the body alone and ran nothing (still open) — upstream `Core/Scripting/OOJSFunction.m:95` ↔ port `Core/Scripting/OOJSFunction.cpp:96-117`, `Core/Entities/ShipEntityAI.cpp:2439-2442`
- ❌ **low** — the named function is no longer defined on the scope: SpiderMonkey's `CompileUCFunction` defined `name` as an enumerable property of the scope object (callers pass NULL → the global), so upstream the global gained `_oo_AIScanPredicate`; the port only sets the function's own `name` property (still open) — upstream `.m:95` ↔ port `.cpp:119-125`
- ✅ **fixed since 2026-10-27** — line numbers: the wrapper now stays on the body's first line and `line_num` is `lineNumber` itself (comment :97-99), so body lines are reported unchanged (the previous `lineno-1` clamp put lines 0/1 at line 2) — port `.cpp:96-108`
- Subtle — the `scope` argument is ignored (comment :84-89, header :62-63); a syntax error is reported through `OOJSReportPendingException` (exception report, QuickJS wording) rather than SpiderMonkey's compile-error report; `_name` comes from the function's `name` property (empty → nullopt → `<anonymous>`); `evaluateWithContext` with a non-object `this` uses the global as `JS_CallFunction(NULL)` did, and now fails cleanly after an engine reset where upstream called a NULL function — port `.cpp:58-66,186-216`

## OOJSGlobal

<a id="oojsglobal"></a>
Upstream `src/Core/Scripting/OOJSGlobal.m` ↔ `Core/Scripting/OOJSGlobal.cpp` (789 / 956 lines)

**Status:** done — 26 rows: 22 ✅ 2 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sGlobalClass` (85) | ordinary QuickJS global; tinyid getter/setter become accessors (comment `Core/Scripting/OOJSGlobal.cpp:82-85`) | ✅ |
| `sGlobalProperties` (111) | `sGlobalProperties` `Core/Scripting/OOJSGlobal.cpp:101` (`galaxyNumber`/`guiScreen` RO, debug `timeAccelerationFactor` RW) | ✅ |
| `sGlobalMethods` (121) | `sGlobalMethods` `Core/Scripting/OOJSGlobal.cpp:115` (same names, arg counts, debug-only `takeSnapShot`/`quitGame`) | ✅ |
| `CreateOOJSGlobal` (151) | `OOJavaScriptEngine` constructor `Core/Scripting/OOJavaScriptEngine.cpp:194-198` (`global` property `OOJS_PROP_READONLY`) | ✅ |
| `SetUpOOJSGlobal` (161) | `SetUpOOJSGlobal` `Core/Scripting/OOJSGlobal.cpp:145` | ✅ |
| `GlobalGetProperty` (167) | `GlobalGetProperty` `Core/Scripting/OOJSGlobal.cpp:152` | ✅ |
| `GlobalSetProperty` (199) | `GlobalSetProperty` `Core/Scripting/OOJSGlobal.cpp:188` | ✅ |
| `GlobalLog` (230) | `GlobalLog` `Core/Scripting/OOJSGlobal.cpp:220` | ❌ |
| `GlobalExpandDescription` (269) | `GlobalExpandDescription` `Core/Scripting/OOJSGlobal.cpp:267` | ✅ |
| `GlobalKeyBindingDescription` (295) | `GlobalKeyBindingDescription` `Core/Scripting/OOJSGlobal.cpp:294` | ✅ |
| `GlobalExpandMissionText` (319) | `GlobalExpandMissionText` `Core/Scripting/OOJSGlobal.cpp:319` (+ `StringFromPList` :49) | ✅ |
| `GlobalDisplayNameForCommodity` (345) | `GlobalDisplayNameForCommodity` `Core/Scripting/OOJSGlobal.cpp:350` | ✅ |
| `GlobalRandomName` (363) | `GlobalRandomName` `Core/Scripting/OOJSGlobal.cpp:367` | ✅ |
| `GlobalRandomInhabitantsDescription` (384) | `GlobalRandomInhabitantsDescription` `Core/Scripting/OOJSGlobal.cpp:389` | ✅ |
| `GlobalClearExtraGuiScreenKeys` (404) | `GlobalClearExtraGuiScreenKeys` `Core/Scripting/OOJSGlobal.cpp:414` | ✅ |
| `GlobalSetExtraGuiScreenKeys` (436) | `GlobalSetExtraGuiScreenKeys` `Core/Scripting/OOJSGlobal.cpp:464` (+ `GetParam` :454) | ⚠️ |
| `GlobalSetScreenBackground` (517) | `GlobalSetScreenBackground` `Core/Scripting/OOJSGlobal.cpp:611` | ✅ |
| `GlobalGetScreenBackgroundForKey` (547) | `GlobalGetScreenBackgroundForKey` `Core/Scripting/OOJSGlobal.cpp:650` | ✅ |
| `GlobalSetScreenBackgroundForKey` (568) | `GlobalSetScreenBackgroundForKey` `Core/Scripting/OOJSGlobal.cpp:673` | ✅ |
| `GlobalSetScreenOverlay` (598) | `GlobalSetScreenOverlay` `Core/Scripting/OOJSGlobal.cpp:708` | ✅ |
| `GlobalGetGuiColorSettingForKey` (624) | `GlobalGetGuiColorSettingForKey` `Core/Scripting/OOJSGlobal.cpp:740` | ✅ |
| `GlobalSetGuiColorSettingForKey` (651) | `GlobalSetGuiColorSettingForKey` `Core/Scripting/OOJSGlobal.cpp:775` | ✅ |
| `GlobalTakeSnapShot` (693) | `GlobalTakeSnapShot` `Core/Scripting/OOJSGlobal.cpp:820` | ❌ |
| `GlobalAutoAIForRole` (734) | `GlobalAutoAIForRole` `Core/Scripting/OOJSGlobal.cpp:888` | ✅ |
| `GlobalPauseGame` (756) | `GlobalPauseGame` `Core/Scripting/OOJSGlobal.cpp:910` | ✅ |
| `GlobalQuitGame` (778) | `GlobalQuitGame` `Core/Scripting/OOJSGlobal.cpp:937` | ⚠️ |

**Differences:**

- ❌ **low** — `log(class, a, b, …)` when an argument's `toString()` throws: upstream `concatenationOfStringsFromJavaScriptValues` skipped a nil first element without a separator and raised on a later nil (no log line, error to JS); the port substitutes `""`, always adds `", "`, and logs (still open) — upstream `Core/Scripting/OOJavaScriptEngine.m:1647-1655` (via `Core/Scripting/OOJSGlobal.m:250`) ↔ port `Core/Scripting/OOJSGlobal.cpp:242-248`
- ❌ **low** — `takeSnapShot()`: the port inlines `-defaultCommanderPath` but drops its two error logs (`savedGame.defaultPath.create.failed`, `savedGame.defaultPath.notDirectory`); fallback path otherwise the same. Debug-monitor builds only (still open) — upstream `Core/NSFileManagerOOExtensions.m:97,104` (via `Core/Scripting/OOJSGlobal.m:711`) ↔ port `Core/Scripting/OOJSGlobal.cpp:847-860`
- ⚠️ **low** — `quitGame()` now schedules the quit (`OOScheduleDeferredCall`, 0 s) so the calling script finishes first; upstream quit immediately inside the call. Code after `quitGame()` and later frame work now run before exit (comment :943-945; new). Debug-monitor builds only — upstream `.m:778-786` ↔ port `.cpp:937-955`
- ⚠️ **low** — `setExtraGuiScreenKeys`: `null`/`undefined` definitions are reported as "definition is not a valid dictionary." (upstream's `JS_ValueToObject` succeeded with a NULL object, then `JS_GetProperty(NULL)`); bad-argument reports describe `MIN(argc-1, 2)` arguments instead of always 2 (reading past argv); a throwing getter is reported and treated as a missing property (comments :448-453, :475-477, :487-488; still as before) — upstream `.m:452-505` ↔ port `.cpp:454-608`
- ✅ note — flags and arg counts match; all warning and bad-argument texts match (including "idenfifier" and `clearExtraGuiScreenKeys` reporting as `setExtraGuiScreenKeys` when argc < 2); excluded GUI screens and `pauseGame` screen conditions match; `expandMissionText` with a missing key returns null; `cbThis: null` leaves no callback `this` as upstream's NULL.

## OOJSGuiScreenKeyDefinition

<a id="oojsguiscreenkeydefinition"></a>
Upstream `src/Core/Scripting/OOJSGuiScreenKeyDefinition.m` ↔ `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp` (150 / 150 lines)

**Status:** done — 13 rows: 13 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJSGuiScreenKeyDefinition init]` (31) | `OOJSGuiScreenKeyDefinition::OOJSGuiScreenKeyDefinition` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:35` | ✅ |
| `-[OOJSGuiScreenKeyDefinition deleteJSPointers]` (47) | `OOJSGuiScreenKeyDefinition::deleteJSPointers` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:49` | ✅ |
| `-[OOJSGuiScreenKeyDefinition dealloc]` (63) | `OOJSGuiScreenKeyDefinition::~OOJSGuiScreenKeyDefinition` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:58` | ✅ |
| `-[OOJSGuiScreenKeyDefinition name]` (72) | `OOJSGuiScreenKeyDefinition::name` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:68` | ✅ |
| `-[OOJSGuiScreenKeyDefinition setName:]` (77) | `OOJSGuiScreenKeyDefinition::setName` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:70` | ✅ |
| `-[OOJSGuiScreenKeyDefinition registerKeys]` (83) | `OOJSGuiScreenKeyDefinition::registerKeys` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:75` | ✅ |
| `-[OOJSGuiScreenKeyDefinition setRegisterKeys:]` (88) | `OOJSGuiScreenKeyDefinition::setRegisterKeys` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:77` | ✅ |
| `-[OOJSGuiScreenKeyDefinition callback]` (94) | `OOJSGuiScreenKeyDefinition::callback` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:82` | ✅ |
| `-[OOJSGuiScreenKeyDefinition setCallback:]` (99) | `OOJSGuiScreenKeyDefinition::setCallback` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:86` | ✅ |
| `-[OOJSGuiScreenKeyDefinition callbackThis]` (108) | `OOJSGuiScreenKeyDefinition::callbackThis` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:94` | ✅ |
| `-[OOJSGuiScreenKeyDefinition setCallbackThis:]` (113) | `OOJSGuiScreenKeyDefinition::setCallbackThis` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:98` | ✅ |
| `-[OOJSGuiScreenKeyDefinition runCallback:]` (122) | `OOJSGuiScreenKeyDefinition::runCallback` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:106` | ✅ |
| `-[OOJSGuiScreenKeyDefinition interfaceCompare:]` (145) | `OOJSGuiScreenKeyDefinition::interfaceCompare` `Core/Scripting/OOJSGuiScreenKeyDefinition.cpp:138` | ✅ |

**Differences:**

- ✅ note — `interfaceCompare` with a nil `_name` answers `kSame` (message to nil); a nil other name compares as `""` — port `:138-150`
- ✅ subtle — GC roots become owned references; the owning script is held weakly as `weakRetain` did; the reset observer stays registered until destruction (comment :43-44) instead of being removed on the first reset; `runCallback` returns early when a reset has released the callback, where upstream called `callJSFunction` with `undefined`; it holds its own references during the call — port `:35-136`

## OOJSInterfaceDefinition

<a id="oojsinterfacedefinition"></a>
Upstream `src/Core/Scripting/OOJSInterfaceDefinition.m` ↔ `Core/Scripting/OOJSInterfaceDefinition.cpp` (166 / 169 lines)

**Status:** done — 15 rows: 15 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJSInterfaceDefinition init]` (31) | `OOJSInterfaceDefinition::OOJSInterfaceDefinition` `Core/Scripting/OOJSInterfaceDefinition.cpp:47` | ✅ |
| `-[OOJSInterfaceDefinition deleteJSPointers]` (47) | `OOJSInterfaceDefinition::deleteJSPointers` `Core/Scripting/OOJSInterfaceDefinition.cpp:61` | ✅ |
| `-[OOJSInterfaceDefinition dealloc]` (63) | `OOJSInterfaceDefinition::~OOJSInterfaceDefinition` `Core/Scripting/OOJSInterfaceDefinition.cpp:70` | ✅ |
| `-[OOJSInterfaceDefinition title]` (72) | `OOJSInterfaceDefinition::title` `Core/Scripting/OOJSInterfaceDefinition.cpp:80` | ✅ |
| `-[OOJSInterfaceDefinition setTitle:]` (77) | `OOJSInterfaceDefinition::setTitle` `Core/Scripting/OOJSInterfaceDefinition.cpp:82` | ✅ |
| `-[OOJSInterfaceDefinition category]` (83) | `OOJSInterfaceDefinition::category` `Core/Scripting/OOJSInterfaceDefinition.cpp:87` | ✅ |
| `-[OOJSInterfaceDefinition setCategory:]` (88) | `OOJSInterfaceDefinition::setCategory` `Core/Scripting/OOJSInterfaceDefinition.cpp:91` | ✅ |
| `-[OOJSInterfaceDefinition summary]` (94) | `OOJSInterfaceDefinition::summary` `Core/Scripting/OOJSInterfaceDefinition.cpp:95` | ✅ |
| `-[OOJSInterfaceDefinition setSummary:]` (99) | `OOJSInterfaceDefinition::setSummary` `Core/Scripting/OOJSInterfaceDefinition.cpp:99` | ✅ |
| `-[OOJSInterfaceDefinition callback]` (105) | `OOJSInterfaceDefinition::callback` `Core/Scripting/OOJSInterfaceDefinition.cpp:103` | ✅ |
| `-[OOJSInterfaceDefinition setCallback:]` (110) | `OOJSInterfaceDefinition::setCallback` `Core/Scripting/OOJSInterfaceDefinition.cpp:107` | ✅ |
| `-[OOJSInterfaceDefinition callbackThis]` (119) | `OOJSInterfaceDefinition::callbackThis` `Core/Scripting/OOJSInterfaceDefinition.cpp:115` | ✅ |
| `-[OOJSInterfaceDefinition setCallbackThis:]` (124) | `OOJSInterfaceDefinition::setCallbackThis` `Core/Scripting/OOJSInterfaceDefinition.cpp:119` | ✅ |
| `-[OOJSInterfaceDefinition runCallback:]` (133) | `OOJSInterfaceDefinition::runCallback` `Core/Scripting/OOJSInterfaceDefinition.cpp:127` | ✅ |
| `-[OOJSInterfaceDefinition interfaceCompare:]` (156) | `OOJSInterfaceDefinition::interfaceCompare` `Core/Scripting/OOJSInterfaceDefinition.cpp:159` (+ `CaseInsensitiveCompare` :36) | ✅ |

**Differences:**

- ✅ note — category-then-title comparison keeps nil-receiver → `kSame` and nil-argument → `""` semantics; the nil branches are unreachable because `Station.setInterface` always supplies a title and category — port `:36-45,159-169`
- ✅ subtle — same lifetime changes as `OOJSGuiScreenKeyDefinition` (owned references, weak owning script, observer kept until destruction, early return after a reset) — port `:47-157`

## OOJSManifest

<a id="oojsmanifest"></a>
Upstream `src/Core/Scripting/OOJSManifest.m` ↔ `Core/Scripting/OOJSManifest.cpp` (292 / 441 lines)

**Status:** done — 14 rows: 10 ✅ 0 ⚠️ 1 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sManifestClass` JSClass (47) | `sManifestClass` + `sManifestExoticMethods` `Core/Scripting/OOJSManifest.cpp:62-74` (get_own/names/delete/set exotic hooks; finalizer `OOJSObjectWrapperFinalize`) | ✅ |
| `sManifestProperties[]` (66) | `sManifestProperties[]` `Core/Scripting/OOJSManifest.cpp:85` (`list` `OOJS_PROPERTY_RO`) | ✅ |
| `sManifestMethods[]` (72) | `sManifestMethods[]` `Core/Scripting/OOJSManifest.cpp:90` (shortComment 1, setShortComment 2, comment 1, setComment 2) | ✅ |
| `-[OOManifest dealloc]` (87) | — removed (comment `Core/Scripting/OOJSManifest.cpp:101`) | ➖ |
| `-[OOManifest oo_jsClassName]` (92) | — removed | ➖ |
| `-[OOManifest oo_jsValueInContext:]` (97) | — removed; never instantiated upstream | ➖ |
| `InitOOJSManifest` (115) | `InitOOJSManifest` `Core/Scripting/OOJSManifest.cpp:103` | ✅ |
| `ManifestDeleteProperty` (129) | `ManifestDeleteProperty` `Core/Scripting/OOJSManifest.cpp:318` | ❌ |
| `ManifestGetProperty` (135) | `ManifestGetProperty` `:151` (list) + `ManifestGetOwnProperty` `:178` (commodities) `Core/Scripting/OOJSManifest.cpp` | ✅ |
| `ManifestSetProperty` (172) | `ManifestSetProperty` `:215` + `ManifestSetPropertyExotic` `:258` `Core/Scripting/OOJSManifest.cpp` | ✅ |
| `ManifestComment` (202) | `ManifestComment` `Core/Scripting/OOJSManifest.cpp:331` | ✅ |
| `ManifestSetComment` (224) | `ManifestSetComment` `Core/Scripting/OOJSManifest.cpp:358` | ✅ |
| `ManifestShortComment` (248) | `ManifestShortComment` `Core/Scripting/OOJSManifest.cpp:387` | ✅ |
| `ManifestSetShortComment` (270) | `ManifestSetShortComment` `Core/Scripting/OOJSManifest.cpp:414` | ✅ |

**Differences:**

- ❌ **low** — delete gate (fixed since 2026-10-27 for the commodity case; reversed form new): the class's own QuickJS `delete_property` hook now runs when the object has no own slot of that name (test `deleteReachesTheClassHookWithNoOwnProperty`, `tests/unit/core/test_OOJavaScriptEngine.cpp:797`), so `delete manifest.food` reports the bad-value error as upstream. But a non-commodity name that a script assigned earlier is stored as an own property (`:308`), and QuickJS deletes an own slot without calling the hook, so `delete manifest.foo` is silent where upstream's delProperty hook always ran and reported "Cannot set property … to invalid value undefined" — upstream `Core/Scripting/OOJSManifest.m:129-133,189-195` ↔ port `Core/Scripting/OOJSManifest.cpp:299-311,318-325`
- ➖ **low** — `OOManifest` is gone; upstream never instantiated it and both Manifest objects carry a NULL private (still the case) — upstream `Core/Scripting/OOJSManifest.m:82-113` ↔ port `Core/Scripting/OOJSManifest.cpp:101`
- ✅ subtle — commodity names are served by `get_own_property` as C_W_E own properties but not listed by `get_own_property_names` (only the shared-permanent `list`), so `for…in` still skips commodities; a non-commodity read returns the stored slot or undefined, as upstream's get hook left `*value` untouched — port `Core/Scripting/OOJSManifest.cpp:178-212`
- ✅ subtle — assigning to `list` is silent in sloppy code and throws "Cannot set read-only property list of instance of Manifest." only with `JS_PROP_THROW` (strict), as SpiderMonkey's readonly shared property — port `Core/Scripting/OOJSManifest.cpp:269-295`
- ✅ subtle — the special-cargo warning text, the `iValue < 0 → 0` clamp, the `MIN(argc, n)` counts and the bad-argument texts are identical; a nil market still defaults to `OOMassUnit::kTons` — port `Core/Scripting/OOJSManifest.cpp:220-255`

## OOJSMission

<a id="oojsmission"></a>
Upstream `src/Core/Scripting/OOJSMission.m` ↔ `Core/Scripting/OOJSMission.cpp` (668 / 938 lines)

**Status:** done — 18 rows: 17 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sMissionClass` JSClass (60) | `sMissionClass` `Core/Scripting/OOJSMission.cpp:76` (no hooks; accessors carry get/set) | ✅ |
| `sMissionProperties[]` (80) | `sMissionProperties[]` `Core/Scripting/OOJSMission.cpp:90` (markedSystems RO, screenID RO, exitScreen RW) | ✅ |
| `sMissionMethods[]` (88) | `sMissionMethods[]` `Core/Scripting/OOJSMission.cpp:101` (7 entries, same names and min args 1,1,1,1,1,1,0) | ✅ |
| `InitOOJSMission` (100) | `InitOOJSMission` `Core/Scripting/OOJSMission.cpp:145` | ✅ |
| `MissionRunCallback` (113) | `MissionRunCallback` `Core/Scripting/OOJSMission.cpp:172` | ✅ |
| `MissionGetProperty` (176) | `MissionGetProperty` `Core/Scripting/OOJSMission.cpp:250` | ⚠️ |
| `MissionSetProperty` (213) | `MissionSetProperty` `Core/Scripting/OOJSMission.cpp:297` | ✅ |
| `MissionMarkSystem` (242) | `MissionMarkSystem` + `MarkerFromJSObject` `Core/Scripting/OOJSMission.cpp:339,118` | ✅ |
| `MissionUnmarkSystem` (283) | `MissionUnmarkSystem` `Core/Scripting/OOJSMission.cpp:384` | ✅ |
| `MissionAddMessageText` (330) | `MissionAddMessageText` `Core/Scripting/OOJSMission.cpp:436` | ✅ |
| `MissionSetInstructionsKey` (352) | `MissionSetInstructionsKey` `Core/Scripting/OOJSMission.cpp:460` | ✅ |
| `MissionSetInstructions` (358) | `MissionSetInstructions` `Core/Scripting/OOJSMission.cpp:465` | ✅ |
| `MissionSetInstructionsInternal` (363) | `MissionSetInstructionsInternal` `Core/Scripting/OOJSMission.cpp:469` | ✅ |
| `GetParameterDictionary` (406) | `GetParameterDictionary` (+ `GetParameter`) `Core/Scripting/OOJSMission.cpp:545,535` | ✅ |
| `GetParameterString` (417) | `GetParameterString` `Core/Scripting/OOJSMission.cpp:556` | ✅ |
| `GetParameterImageDescriptor` (426) | `GetParameterImageDescriptor` `Core/Scripting/OOJSMission.cpp:573` | ✅ |
| `MissionRunScreen` (437) | `MissionRunScreen` `Core/Scripting/OOJSMission.cpp:604` | ✅ |
| `MissionRunShipLibrary` (652) | `MissionRunShipLibrary` `Core/Scripting/OOJSMission.cpp:922` | ✅ |

**Differences:**

- ⚠️ **low** — (still open) `mission.markedSystems` lists the marker values in the destinations Dict's sorted key order; upstream `-allValues` gave NSDictionary hash order. Stated in the comment "-allValues gave hash order" — upstream `Core/Scripting/OOJSMission.m:187-191` ↔ port `Core/Scripting/OOJSMission.cpp:258-272`
- ✅ **med** — (fixed since 2026-10-27, commit 10504da05) `markSystem`/`unmarkSystem` with an array or string marker now raise `NSInvalidArgumentException` (native exception to the script), where upstream's `-oo_intForKey:defaultValue:` to a non-dictionary raised; test `tests/component/test_dictionary_arguments_reject_arrays.py` — port `Core/Scripting/OOJSMission.cpp:118-126,370-371,418-419`
- ✅ subtle — `setInstructions` with null/no text and no mission key still logs "mission key not set" via `setMissionInstructions("", nullopt)`; with a key `clearMissionDescriptionForMission` is called directly — port `Core/Scripting/OOJSMission.cpp:514-521`
- ✅ subtle — `runScreen` order of side effects is unchanged (title/titleKey, music, overlay, background, backgroundSpecial, chart zoom/centre, removeDemoShips, model/spinModel/modelPersonality, displayModel set/delete, allowInterrupt, exitScreen, screenID, registerKeys, textEntry, start screen, message/messageKey, choices/choicesKey, initialChoicesKey, cleanup). Null/undefined params are rejected with the same "parameter object" report (upstream crashed). A getter that throws is reported and treated as undefined. `setMissionMusic("")` and `setMissionBackgroundSpecial("")` clear as nil did (`PlayerEntityLegacyScriptEngine.cpp:2277-2282`, `PlayerEntity.cpp:13359-13361`) — port `Core/Scripting/OOJSMission.cpp:604-920`
- ✅ subtle — `MissionRunCallback`: copies the callback and `this`, clears the statics, converts choice/keypress, resets the choice silently, push/call/pop, and squashes only OOExceptions with the same `kOOLogException` text; null/undefined `this` becomes the global, as `JS_ValueToObject` → NULL did — port `Core/Scripting/OOJSMission.cpp:172-248`
- ✅ subtle — `MissionSetProperty` default reports only the bad selector (upstream then also reported a bad value). Unreachable: `exitScreen` is the only writable property — port `Core/Scripting/OOJSMission.cpp:310-314`

## OOJSMissionVariables

<a id="oojsmissionvariables"></a>
Upstream `src/Core/Scripting/OOJSMissionVariables.m` ↔ `Core/Scripting/OOJSMissionVariables.cpp` (205 / 348 lines)

**Status:** done — 8 rows: 6 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `KeyForPropertyID` (34) | `NameForPropertyID` + `KeyForPropertyName` `Core/Scripting/OOJSMissionVariables.cpp:48,61` | ✅ |
| `sMissionVariablesClass` JSClass (53) | `sMissionVariablesClass` + `sMissionVariablesExoticMethods` `Core/Scripting/OOJSMissionVariables.cpp:93-106` (get_own, names, delete, define_own, get, set) | ✅ |
| `InitOOJSMissionVariables` (67) | `InitOOJSMissionVariables` `Core/Scripting/OOJSMissionVariables.cpp:108` (prototype Object.prototype, READONLY on global) | ✅ |
| `MissionVariablesConverter` (78) | `MissionVariablesConverter` `Core/Scripting/OOJSMissionVariables.cpp:129` (debug monitor; a PList copy) | ✅ |
| `MissionVariablesDeleteProperty` (84) | `MissionVariablesDeleteProperty` `Core/Scripting/OOJSMissionVariables.cpp:233` | ✅ |
| `MissionVariablesGetProperty` (99) | `MissionVariablesGetProperty` + `ValueForMissionVariable` + `MissionVariablesGetOwnProperty` `Core/Scripting/OOJSMissionVariables.cpp:252,136,157` | ❌ |
| `MissionVariablesSetProperty` (126) | `MissionVariablesSetProperty` + `SetMissionVariable` (+ `MissionVariablesDefineOwnProperty`) `Core/Scripting/OOJSMissionVariables.cpp:314,290,325` | ✅ |
| `MissionVariablesEnumerate` (150) | `MissionVariablesGetOwnPropertyNames` `Core/Scripting/OOJSMissionVariables.cpp:183` | ⚠️ |

**Differences:**

- ✅ **high** — (fixed since 2026-10-27) `delete missionVariables.foo` now always clears the variable: the object never holds own slots (set and define go to the player), so QuickJS's `delete` falls through to the class `delete_property` hook; covered by `deleteReachesTheClassHookWithNoOwnProperty` (`tests/unit/core/test_OOJavaScriptEngine.cpp:797`) — port `Core/Scripting/OOJSMissionVariables.cpp:233-250`
- ❌ **low** — (new) lookup precedence for variables that have no SpiderMonkey slot (loaded from a save, set by a legacy script, or set before an engine reset): upstream found a same-named `Object.prototype` member first (`missionVariables.toString` / `valueOf` / `constructor` gave the function), and `"foo" in missionVariables` / `hasOwnProperty("foo")` were false because no own slot or resolve hook existed. The port's `get_property` returns the mission variable first and `get_own_property` reports every variable as an own C_W_E property, so both give the variable/true. Variables assigned through JS this session behaved as the port does in both — upstream `Core/Scripting/OOJSMissionVariables.m:53-65,99-124` ↔ port `Core/Scripting/OOJSMissionVariables.cpp:157-181,252-288`
- ⚠️ **low** — (still open) `for…in`/`Object.keys(missionVariables)` lists names in sorted PList key order instead of `-allKeys` hash order; stated in the comment "In key order (-allKeys gave them in hash order)" — upstream `Core/Scripting/OOJSMissionVariables.m:161` ↔ port `Core/Scripting/OOJSMissionVariables.cpp:188-197`
- ✅ subtle — coercion unchanged: set stores `ToString(value)` (null/undefined clear the variable); get gives a number when `OOIsNumberLiteral(s, true)` (via `oo::str::doubleValue`), otherwise the PList conversion; a missing name reads as null; a `_`-prefixed name reads from the prototype (undefined), is a no-op on delete and errors on set with `Invalid mission variable name "%s".` — port `Core/Scripting/OOJSMissionVariables.cpp:136-155,290-312`
- ✅ subtle — `Object.defineProperty(missionVariables, …)` with an accessor reports the invalid-name error, with a value stores like an assignment; upstream SpiderMonkey routed define through addProperty/setProperty stubs. Not reachable from normal OXP code — port `Core/Scripting/OOJSMissionVariables.cpp:325-348`

## OOJSOolite

<a id="oojsoolite"></a>
Upstream `src/Core/Scripting/OOJSOolite.m` ↔ `Core/Scripting/OOJSOolite.cpp` (311 / 402 lines)

**Status:** done — 10 rows: 8 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sOoliteClass` JSClass (44) | `sOoliteClass` `Core/Scripting/OOJSOolite.cpp:79` | ✅ |
| `sOoliteProperties[]` (76) | `sOoliteProperties[]` `Core/Scripting/OOJSOolite.cpp:107` (same 10 (+1 debug) names, order and RO/RW flags) | ✅ |
| `sOoliteMethods[]` (94) | `sOoliteMethods[]` `Core/Scripting/OOJSOolite.cpp:136` (compareVersion, 1) | ✅ |
| `InitOOJSOolite` (100) | `InitOOJSOolite` `Core/Scripting/OOJSOolite.cpp:142` | ✅ |
| `OoliteGetProperty` (106) | `OoliteGetProperty` `Core/Scripting/OOJSOolite.cpp:155` | ❌ |
| `OoliteGetProperty` case `kOolite_jsVersionString` (129) | case `kJsVersionString` `Core/Scripting/OOJSOolite.cpp:183` | ⚠️ |
| `OoliteSetProperty` (185) | `OoliteSetProperty` `Core/Scripting/OOJSOolite.cpp:253` | ✅ |
| `VersionString` (262) | `VersionString` + `OoliteInfoString` `Core/Scripting/OOJSOolite.cpp:339,46` | ✅ |
| `VersionComponents` (267) | `VersionComponents` `Core/Scripting/OOJSOolite.cpp:343` | ✅ |
| `OoliteCompareVersion` (279) | `OoliteCompareVersion` + `UnsignedIntValue` `Core/Scripting/OOJSOolite.cpp:366,352` | ✅ |

**Differences:**

- ❌ **low** — (still open) `oolite.gameSettings` is converted from a `PList::Dict`, so `for…in`/`Object.keys`/`JSON.stringify` see sorted key order instead of the NSDictionary hash order; values are the same — upstream `Core/Scripting/OOJSOolite.m:133-135` ↔ port `Core/Scripting/OOJSOolite.cpp:187-189`
- ⚠️ **low** — (new; regression from the previous audit's ✅) `oolite.jsVersionString` is now `"QuickJS-ng " + JS_GetVersion()` (e.g. "QuickJS-ng 0.17.0"); upstream `JS_VersionToString(JS_GetVersion())` gave `"ECMAv5"` (`upstream/spidermonkey-ff4/js/src/jsapi.cpp:1084`). The port comment states the change ("it now names the engine") but wrongly says the old value was "1.8.5". `jsVersion` stays 185. Introduced by 74a2dd118. — upstream `Core/Scripting/OOJSOolite.m:129-131` ↔ port `Core/Scripting/OOJSOolite.cpp:71-76,183-185`
- ✅ subtle — the version comes from `Info-gnustep.plist` in the built-in resources directory, re-read on every access; missing or unparsable → `versionString` null, `version` `[]`. `compareVersion` accepts an all-number array (bool/int/double via C conversion, as `-unsignedIntValue`) or a string, else returns undefined — port `Core/Scripting/OOJSOolite.cpp:46-61,339-402`
- ✅ subtle — setters: `colorSaturation` adjusts by the delta, `postFX` clamps at 0, tone mappers accept strings only with the same two warning texts, and a failed conversion clears the pending exception and reports the bad value as upstream — port `Core/Scripting/OOJSOolite.cpp:253-337`

## OOJSPlanet

<a id="oojsplanet"></a>
Upstream `src/Core/Scripting/OOJSPlanet.m` ↔ `Core/Scripting/OOJSPlanet.cpp` (293 / 360 lines)

**Status:** done — 9 rows: 9 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sPlanetClass` JSClass (37) | `sPlanetClass` `Core/Scripting/OOJSPlanet.cpp:54` (finalizer `OOJSCxxObjectWrapperFinalize`, entity holder) | ✅ |
| `sPlanetProperties[]` (68) | `sPlanetProperties[]` `Core/Scripting/OOJSPlanet.cpp:80` (12 entries, same names, order and RO/RW) | ✅ |
| `JSPlanetGetPlanetEntity` DEFINE_JS_OBJECT_GETTER (85) | `JSPlanetGetPlanetEntity` `Core/Scripting/OOJSPlanet.cpp:113` | ✅ |
| `InitOOJSPlanet` (87) | `InitOOJSPlanet` `Core/Scripting/OOJSPlanet.cpp:122` (parent Entity prototype; `OOJSEntityObjectConverter`, bead oo-9ht.39.3) | ✅ |
| `-[OOPlanetEntity(OOJavaScriptExtensions) isVisibleToScripts]` (96) | `OOJSPlanetIsVisibleToScripts` `Core/Scripting/OOJSPlanet.cpp:141` | ✅ |
| `-[OOPlanetEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (102) | `OOPlanetEntity::jsClassID` `Core/Entities/OOPlanetEntity.cpp:1266` → `JSPlanetClassID` `Core/Scripting/OOJSPlanet.cpp:137` | ✅ |
| `-[OOPlanetEntity(OOJavaScriptExtensions) oo_jsClassName]` (108) | `OOJSPlanetJSClassName` `Core/Scripting/OOJSPlanet.cpp:149` | ✅ |
| `PlanetGetProperty` (122) | `PlanetGetProperty` `Core/Scripting/OOJSPlanet.cpp:161` | ✅ |
| `PlanetSetProperty` (184) | `PlanetSetProperty` `Core/Scripting/OOJSPlanet.cpp:243` | ✅ |

**Differences:**

- ✅ subtle — as upstream, the getter has no stale-entity → undefined branch: a stale planet gives null colours/texture/name, 0 numbers, zero vector/quaternion, `hasAtmosphere` false and `isMainPlanet` = `nil == [UNIVERSE planet]`; reproduced with explicit null guards — port `Core/Scripting/OOJSPlanet.cpp:161-241`
- ✅ subtle — colours: `normalizedArray` floats as single reals; setters accept a description or `null` (`setAirColor(nullptr)` is a no-op in both, `OOPlanetEntity.cpp:1020-1024`). `orientation` reads `Entity::normalOrientation()` and sets via `OOPlanetEntity::setOrientation` after `quaternion_normalize`. Texture warnings "Expected texture string. Value not set." / "Cannot find texture \"%s\". Value not set." match and the setter always succeeds — port `Core/Scripting/OOJSPlanet.cpp:258-347`

## OOJSPlayer

<a id="oojsplayer"></a>
Upstream `src/Core/Scripting/OOJSPlayer.m` ↔ `Core/Scripting/OOJSPlayer.cpp` (683 / 842 lines)

**Status:** done — 25 rows: 22 ✅ 0 ⚠️ 2 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sPlayerClass` JSClass (63) | `sPlayerClass` `Core/Scripting/OOJSPlayer.cpp:54` (finalizer `OOJSObjectWrapperFinalize`; no private, as before) | ✅ |
| `sPlayerProperties[]` (104) | `sPlayerProperties[]` `Core/Scripting/OOJSPlayer.cpp:116` (22 entries, same names, order, RO/RW) | ✅ |
| `sPlayerMethods[]` (131) | `sPlayerMethods[]` `Core/Scripting/OOJSPlayer.cpp:163` (15 entries, same names and min args) | ✅ |
| `InitOOJSPlayer` (151) | `InitOOJSPlayer` `Core/Scripting/OOJSPlayer.cpp:189` | ✅ |
| `JSPlayerClass` (160) | `JSPlayerClassID` `Core/Scripting/OOJSPlayer.cpp:209` | ✅ |
| `JSPlayerPrototype` (165) | `JS_GetClassProto(JSPlayerClassID())` (no accessor) | ➖ |
| `JSPlayerObject` (170) | `JSPlayerObject` `Core/Scripting/OOJSPlayer.cpp:211` | ✅ |
| `OOPlayerForScripting` (175) | `OOPlayerForScripting` `Core/Scripting/OOJSPlayer.cpp:222` | ✅ |
| `PlayerGetProperty` (183) | `PlayerGetProperty` `Core/Scripting/OOJSPlayer.cpp:229` | ✅ |
| `PlayerSetProperty` (288) | `PlayerSetProperty` `Core/Scripting/OOJSPlayer.cpp:396` | ✅ |
| `PlayerCommsMessage` (354) | `PlayerCommsMessage` `Core/Scripting/OOJSPlayer.cpp:465` | ✅ |
| `PlayerConsoleMessage` (379) | `PlayerConsoleMessage` `Core/Scripting/OOJSPlayer.cpp:493` | ✅ |
| `PlayerEndScenario` (403) | `PlayerEndScenario` `Core/Scripting/OOJSPlayer.cpp:515` | ✅ |
| `PlayerIncreaseContractReputation` (422) | `PlayerIncreaseContractReputation` `Core/Scripting/OOJSPlayer.cpp:534` | ✅ |
| `PlayerDecreaseContractReputation` (433) | `PlayerDecreaseContractReputation` `Core/Scripting/OOJSPlayer.cpp:545` | ✅ |
| `PlayerIncreaseParcelReputation` (444) | `PlayerIncreaseParcelReputation` `Core/Scripting/OOJSPlayer.cpp:556` | ✅ |
| `PlayerDecreaseParcelReputation` (455) | `PlayerDecreaseParcelReputation` `Core/Scripting/OOJSPlayer.cpp:567` | ✅ |
| `PlayerIncreasePassengerReputation` (466) | `PlayerIncreasePassengerReputation` `Core/Scripting/OOJSPlayer.cpp:578` | ✅ |
| `PlayerDecreasePassengerReputation` (477) | `PlayerDecreasePassengerReputation` `Core/Scripting/OOJSPlayer.cpp:589` | ✅ |
| `PlayerAddMessageToArrivalReport` (488) | `PlayerAddMessageToArrivalReport` `Core/Scripting/OOJSPlayer.cpp:600` | ✅ |
| `PlayerAudioMessage` (508) | `PlayerAudioMessage` `Core/Scripting/OOJSPlayer.cpp:620` | ✅ |
| `PlayerReplaceShip` (530) | `PlayerReplaceShip` `Core/Scripting/OOJSPlayer.cpp:643` | ✅ |
| `PlayerSetEscapePodDestination` (571) | `PlayerSetEscapePodDestination` `Core/Scripting/OOJSPlayer.cpp:701` | ❌ |
| `PlayerSetPlayerRole` (648) | `PlayerSetPlayerRole` `Core/Scripting/OOJSPlayer.cpp:799` | ❌ |
| `PlayerStopAudioMessage` (675) | `PlayerStopAudioMessage` `Core/Scripting/OOJSPlayer.cpp:834` | ✅ |

**Differences:**

- ❌ **low** — (new) return value when the native succeeds without setting rval: upstream `setPlayerRole()` (both paths) and a successful `setEscapePodDestination()` `return YES`/`return OK` without `JS_SET_RVAL`, and SpiderMonkey 1.8.5 leaves `vp[0]` (the callee) as the result (`upstream/spidermonkey-ff4/js/src/jscntxtinlines.h:695-707`), so the call evaluated to the function object itself. The port returns `undefined`. Only visible if a script uses the result — upstream `Core/Scripting/OOJSPlayer.m:642,666-670` ↔ port `Core/Scripting/OOJSPlayer.cpp:793,820,829`
- ➖ **low** — `JSPlayerPrototype()` has no port accessor; the prototype is the class proto registered by `OOJSInitClass` and callers use `JS_GetClassProto` — port `Core/Scripting/OOJSPlayer.cpp:191-194`
- ✅ subtle — getter types and texts match: reputations keep the `(int)((float)r / 10.0)` truncation and the float-precise forms; `bounty` is `legalStatus`; alert flags via `OOAlertFlagIsOn`; score/bounty setters use ValueToInt32 with clamp at 0 and `kByScript`; all bad-argument texts and `MIN(argc, 1)` counts match — port `Core/Scripting/OOJSPlayer.cpp:229-460,465-832`
- ✅ subtle — `replaceShip`: an unconvertible personality stays 0 and its conversion error is cleared (upstream ignored the JS_ValueToInt32 result); `playerReplacedShip` then `playerBoughtNewShip(player, 0)` in that order — port `Core/Scripting/OOJSPlayer.cpp:667-693`
- ✅ subtle — `setEscapePodDestination('NEARBY_SYSTEM')` keeps upstream's backwards loop that never examines index 0 for `nova`, the `ranrot_rand() % nDests` pick, and the `(.2 + d²)·3600 + 5400·(ranrot_rand() & 127)` adjust time; `setTargetSystemID(i)` receives the array index, as upstream did — port `Core/Scripting/OOJSPlayer.cpp:745-775`

## OOJSPlayerShip

<a id="oojsplayership"></a>
Upstream `src/Core/Scripting/OOJSPlayerShip.m` ↔ `Core/Scripting/OOJSPlayerShip.cpp` (1751 / 2219 lines)

**Status:** done — 40 rows: 36 ✅ 2 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sPlayerShipClass` JSClass (85) | `sPlayerShipClass` `Core/Scripting/OOJSPlayerShip.cpp:63` | ✅ |
| `sPlayerShipProperties[]` (167) | `sPlayerShipProperties[]` `Core/Scripting/OOJSPlayerShip.cpp:255` (64 entries, same names, order and RO/RW, incl. RW `aftShieldRechargeRate`/`maxAftShield`) | ✅ |
| `sPlayerShipMethods[]` (237) | `sPlayerShipMethods[]` `Core/Scripting/OOJSPlayerShip.cpp:407` (27 entries, same names and min args) | ✅ |
| `InitOOJSPlayerShip` (269) | `InitOOJSPlayerShip` `Core/Scripting/OOJSPlayerShip.cpp:445` | ⚠️ |
| `JSPlayerShipClass` (284) | `JSPlayerShipClassID` `Core/Scripting/OOJSPlayerShip.cpp:487` | ✅ |
| `JSPlayerShipPrototype` (289) | — no accessor; `JS_GetClassProto(JSPlayerShipClassID())` | ➖ |
| `JSPlayerShipObject` (294) | `JSPlayerShipObject` `Core/Scripting/OOJSPlayerShip.cpp:489` (looks up `player.ship`) | ✅ |
| `-[PlayerEntity(OOJavaScriptExtensions) oo_jsClassName]` (301) | `OOJSPlayerShipJSClassName` `Core/Scripting/OOJSPlayerShip.cpp:501` | ✅ |
| `-[PlayerEntity(OOJavaScriptExtensions) setJSSelf:context:]` (306) | `OOJSPlayerShipSetJSSelf` `Core/Scripting/OOJSPlayerShip.cpp:505` | ✅ |
| `-[PlayerEntity(OOJavaScriptExtensions) javaScriptEngineWillReset:]` (317) | reset observer lambda → `PlayerEntity::deleteJSSelf` `Core/Scripting/OOJSPlayerShip.cpp:513-516` | ✅ |
| `PlayerShipGetProperty` (334) | `PlayerShipGetProperty` `Core/Scripting/OOJSPlayerShip.cpp:519` | ✅ |
| `PlayerShipSetProperty` (606) | `PlayerShipSetProperty` `Core/Scripting/OOJSPlayerShip.cpp:868` | ⚠️ |
| `PlayerShipLaunch` (1003) | `PlayerShipLaunch` `Core/Scripting/OOJSPlayerShip.cpp:1360` | ✅ |
| `PlayerShipRemoveAllCargo` (1017) | `PlayerShipRemoveAllCargo` `Core/Scripting/OOJSPlayerShip.cpp:1373` | ✅ |
| `PlayerShipUseSpecialCargo` (1038) | `PlayerShipUseSpecialCargo` `Core/Scripting/OOJSPlayerShip.cpp:1393` | ✅ |
| `PlayerShipEngageAutopilotToStation` (1062) | `PlayerShipEngageAutopilotToStation` `Core/Scripting/OOJSPlayerShip.cpp:1418` | ✅ |
| `PlayerShipDisengageAutopilot` (1085) | `PlayerShipDisengageAutopilot` `Core/Scripting/OOJSPlayerShip.cpp:1443` | ✅ |
| `PlayerShipRequestDockingClearance` (1098) | `PlayerShipRequestDockingClearance` `Core/Scripting/OOJSPlayerShip.cpp:1455` | ✅ |
| `PlayerShipCancelDockingRequest` (1121) | `PlayerShipCancelDockingRequest` `Core/Scripting/OOJSPlayerShip.cpp:1478` | ✅ |
| `PlayerShipAwardEquipmentToCurrentPylon` (1145) | `PlayerShipAwardEquipmentToCurrentPylon` `Core/Scripting/OOJSPlayerShip.cpp:1502` | ✅ |
| `PlayerShipAddPassenger` (1171) | `PlayerShipAddPassenger` `Core/Scripting/OOJSPlayerShip.cpp:1531` | ✅ |
| `PlayerShipRemovePassenger` (1206) | `PlayerShipRemovePassenger` `Core/Scripting/OOJSPlayerShip.cpp:1574` | ✅ |
| `PlayerShipAddParcel` (1231) | `PlayerShipAddParcel` `Core/Scripting/OOJSPlayerShip.cpp:1600` | ✅ |
| `PlayerShipRemoveParcel` (1264) | `PlayerShipRemoveParcel` `Core/Scripting/OOJSPlayerShip.cpp:1639` | ✅ |
| `PlayerShipAwardContract` (1289) | `PlayerShipAwardContract` `Core/Scripting/OOJSPlayerShip.cpp:1664` | ✅ |
| `PlayerShipRemoveContract` (1325) | `PlayerShipRemoveContract` `Core/Scripting/OOJSPlayerShip.cpp:1710` | ✅ |
| `PlayerShipSetCustomView` (1357) | `PlayerShipSetCustomView` `Core/Scripting/OOJSPlayerShip.cpp:1749` | ✅ |
| `PlayerShipResetCustomView` (1411) | `PlayerShipResetCustomView` `Core/Scripting/OOJSPlayerShip.cpp:1820` | ✅ |
| `PlayerShipResetScannerZoom` (1431) | `PlayerShipResetScannerZoom` `Core/Scripting/OOJSPlayerShip.cpp:1843` | ✅ |
| `PlayerShipTakeInternalDamage` (1444) | `PlayerShipTakeInternalDamage` `Core/Scripting/OOJSPlayerShip.cpp:1855` | ✅ |
| `PlayerShipBeginHyperspaceCountdown` (1457) | `PlayerShipBeginHyperspaceCountdown` `Core/Scripting/OOJSPlayerShip.cpp:1867` | ✅ |
| `PlayerShipCancelHyperspaceCountdown` (1491) | `PlayerShipCancelHyperspaceCountdown` `Core/Scripting/OOJSPlayerShip.cpp:1907` | ✅ |
| `PlayerShipBeginGalacticHyperspaceCountdown` (1508) | `PlayerShipBeginGalacticHyperspaceCountdown` `Core/Scripting/OOJSPlayerShip.cpp:1925` | ✅ |
| `PlayerShipSetMultiFunctionDisplay` (1542) | `PlayerShipSetMultiFunctionDisplay` `Core/Scripting/OOJSPlayerShip.cpp:1969` | ✅ |
| `PlayerShipSetMultiFunctionText` (1570) | `PlayerShipSetMultiFunctionText` `Core/Scripting/OOJSPlayerShip.cpp:1999` | ✅ |
| `PlayerShipSetPrimedEquipment` (1608) | `PlayerShipSetPrimedEquipment` `Core/Scripting/OOJSPlayerShip.cpp:2039` | ✅ |
| `PlayerShipSetCustomHUDDial` (1634) | `PlayerShipSetCustomHUDDial` `Core/Scripting/OOJSPlayerShip.cpp:2072` | ❌ |
| `PlayerShipHideHUDSelector` (1662) | `PlayerShipHideHUDSelector` `Core/Scripting/OOJSPlayerShip.cpp:2101` | ✅ |
| `PlayerShipShowHUDSelector` (1683) | `PlayerShipShowHUDSelector` `Core/Scripting/OOJSPlayerShip.cpp:2124` | ✅ |
| `ValidateContracts` (1704) | `ValidateContracts` `Core/Scripting/OOJSPlayerShip.cpp:2147` | ✅ |

**Differences:**

- ❌ **low** — (still open) `setCustomHUDDial(key, null|undefined)`: upstream `-setDialCustom:forKey:` did `[customDialSettings setObject:nil …]`, which raised and reached the script as a native exception; the port stores a null PList entry silently (its comment: "null is a null entry (it raised before)") — upstream `Core/Scripting/OOJSPlayerShip.m:1649-1655`, `Core/Entities/PlayerEntity.m:4127-4130` ↔ port `Core/Scripting/OOJSPlayerShip.cpp:2088-2094`, `Core/Entities/PlayerEntity.cpp:4917-4922`
- ⚠️ **low** — (new; the previous audit recorded the quirk as kept) `serviceLevel` setter whose number conversion throws: upstream fell through into the `currentWeapon` case and replaced the current weapon (with the exception pending); the port reports the bad value instead. Stated in the port comment ("The SpiderMonkey version fell through to currentWeapon here… Report the bad value instead.") — upstream `Core/Scripting/OOJSPlayerShip.m:895-910` ↔ port `Core/Scripting/OOJSPlayerShip.cpp:1208-1221`
- ⚠️ **low** — (still open) Init: the `player.ship` slot holds `oo::makeShared<OOJSEntityHolder>(player)` instead of `[player weakRetain]`, with `OOJSEntityObjectConverter` (bead oo-9ht.39.3); same object, READONLY `ship` property and prototype chain — upstream `Core/Scripting/OOJSPlayerShip.m:269-282` ↔ port `Core/Scripting/OOJSPlayerShip.cpp:445-485`
- ➖ **low** — `JSPlayerShipPrototype()` has no port accessor; callers use the class proto — port `Core/Scripting/OOJSPlayerShip.cpp:451`
- ✅ subtle — `targetSystem` with an unconvertible value: upstream fell through to `infoSystem`, failed again and reported the bad value; the port breaks straight to the same report (comment at `:1266-1269`). The getter's unreachable `default:` now fails instead of returning null — port `Core/Scripting/OOJSPlayerShip.cpp:856-860,1258-1270`
- ✅ note (nil-messaging, still open) — `messageGuiTextColor`/`messageGuiTextCommsColor` getter and setter call `UNIVERSE->messageGUI()` unguarded, and `setMultiFunctionText(key, text, true)` calls `gui->reflowTextForMFD` on a possibly null GUI, where upstream messaged nil. Unreachable in practice — port `Core/Scripting/OOJSPlayerShip.cpp:846-854,1289-1305,2028-2030`
- ✅ note — the "return NO without an error" paths (compassTarget not found, primedEquipment failure, reticle colour failure, targetSystem out of range) use `OOJSNativeFailure`, an uncatchable error that stops the script without a report, as SpiderMonkey did (`Core/Scripting/OOJavaScriptEngine.cpp:923-930`). Upstream typos and copy-paste names ("orientiation", "hightlight", `showHUDSelector` reporting "hideHUDSelector", `engageAutopilot`) are kept — port `Core/Scripting/OOJSPlayerShip.cpp:994-999,1051-1053,2134`
- ✅ note — `setCustomView` with a non-string third argument raises `OOInvalidArgumentException` "Tried to add nil value for key 'weapon_facing' to dictionary", matching upstream's `-setObject:forKey:` raise; the position/orientation strings use `{:f}` (= `%f`) — port `Core/Scripting/OOJSPlayerShip.cpp:1780-1806`

## OOJSPopulatorDefinition

<a id="oojspopulatordefinition"></a>
Upstream `src/Core/Scripting/OOJSPopulatorDefinition.m` ↔ `Core/Scripting/OOJSPopulatorDefinition.cpp` (125 / 159 lines)

**Status:** done — 8 rows: 8 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJSPopulatorDefinition init]` (33) | `OOJSPopulatorDefinition::OOJSPopulatorDefinition` `Core/Scripting/OOJSPopulatorDefinition.cpp:36` | ✅ |
| `-[OOJSPopulatorDefinition deleteJSPointers]` (49) | `OOJSPopulatorDefinition::deleteJSPointers` `Core/Scripting/OOJSPopulatorDefinition.cpp:50` | ✅ |
| `-[OOJSPopulatorDefinition dealloc]` (65) | `OOJSPopulatorDefinition::~OOJSPopulatorDefinition` `Core/Scripting/OOJSPopulatorDefinition.cpp:59` | ✅ |
| `-[OOJSPopulatorDefinition callback]` (74) | `OOJSPopulatorDefinition::callback` `Core/Scripting/OOJSPopulatorDefinition.cpp:69` | ✅ |
| `-[OOJSPopulatorDefinition setCallback:]` (79) | `OOJSPopulatorDefinition::setCallback` `Core/Scripting/OOJSPopulatorDefinition.cpp:73` | ✅ |
| `-[OOJSPopulatorDefinition callbackThis]` (88) | `OOJSPopulatorDefinition::callbackThis` `Core/Scripting/OOJSPopulatorDefinition.cpp:81` | ✅ |
| `-[OOJSPopulatorDefinition setCallbackThis:]` (93) | `OOJSPopulatorDefinition::setCallbackThis` `Core/Scripting/OOJSPopulatorDefinition.cpp:85` | ✅ |
| `-[OOJSPopulatorDefinition runCallback:]` (102) | `OOJSPopulatorDefinition::runPopulatorCallback` `Core/Scripting/OOJSPopulatorDefinition.cpp:93` | ✅ |

**Differences:**

- ✅ subtle — `runPopulatorCallback` returns silently when the callback is no longer a function (released by an engine reset); upstream called `callJSFunction` with `JSVAL_VOID`, which reports a "not a function" error. A definition only outlives a reset if the populator runs against stale settings, which the reset path rebuilds — port `Core/Scripting/OOJSPopulatorDefinition.cpp:98-102`
- ✅ subtle — the reset observer stays registered until destruction (upstream removed it in `deleteJSPointers`), so values set after a reset are freed on the next one; `callback()`/`callbackThis()` now return owned (duplicated) values; `this` that is not an object is passed as undefined (global), as upstream's NULL `_callbackThis` — port `Core/Scripting/OOJSPopulatorDefinition.cpp:42-47,69-91,111-115`
- ✅ note — `OOJSPopulatorDefinitionToPList`/`OOJSPopulatorDefinitionIn` (`:145`, `:152`) let a definition travel inside a PList where upstream stored the object in an NSDictionary; no behaviour of their own.

## OOJSQuaternion

<a id="oojsquaternion"></a>
Upstream `src/Core/Scripting/OOJSQuaternion.m` ↔ `Core/Scripting/OOJSQuaternion.cpp` (925 / 773 lines)

**Status:** done — 35 rows: 32 ✅ 2 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sQuaternionClass` JSClass (66) | `sQuaternionClass` `Core/Scripting/OOJSQuaternion.cpp:76` (finalizer `QuaternionFinalize`) | ✅ |
| `sQuaternionProperties[]` (89) | `sQuaternionProperties[]` `Core/Scripting/OOJSQuaternion.cpp:93` (w, x, y, z, READWRITE_CB) | ✅ |
| `sQuaternionMethods[]` (98) | `sQuaternionMethods[]` `Core/Scripting/OOJSQuaternion.cpp:109` (14 entries, same names and arities, e.g. rotate 2, dot 1) | ✅ |
| `sQuaternionStaticMethods[]` (173) | `sQuaternionStaticMethods[]` `Core/Scripting/OOJSQuaternion.cpp:127` (random, 0) | ✅ |
| `InitOOJSQuaternion` (185) | `InitOOJSQuaternion` `Core/Scripting/OOJSQuaternion.cpp:134` | ✅ |
| `JSQuaternionWithQuaternion` (190) | `JSQuaternionWithQuaternion` `Core/Scripting/OOJSQuaternion.cpp:146` | ✅ |
| `QuaternionToJSValue` (218) | `QuaternionToJSValue` `Core/Scripting/OOJSQuaternion.cpp:162` | ✅ |
| `JSValueToQuaternion` (236) | `JSValueToQuaternion` `Core/Scripting/OOJSQuaternion.cpp:178` | ✅ |
| `-[PlayerEntity(JSQuaternionStatistics) reportJSQuaternionStatistics]` (262) | — removed (commit 2c31444b1 "as upstream #768 did") | ⚠️ |
| `-[PlayerEntity(JSQuaternionStatistics) clearJSQuaternionStatistics]` (286) | — removed (commit 2c31444b1) | ⚠️ |
| `JSObjectGetQuaternion` (306) | `JSObjectGetQuaternion` + `GetArrayElementNumber` `Core/Scripting/OOJSQuaternion.cpp:194,185` | ✅ |
| `GetThisQuaternion` (384) | `GetThisQuaternion` `Core/Scripting/OOJSQuaternion.cpp:265` | ✅ |
| `JSQuaternionSetQuaternion` (394) | `JSQuaternionSetQuaternion` `Core/Scripting/OOJSQuaternion.cpp:276` | ✅ |
| `QuaternionFromArgumentListNoErrorInternal` (420) | `QuaternionFromArgumentListNoErrorInternal` `Core/Scripting/OOJSQuaternion.cpp:300` | ✅ |
| `QuaternionFromArgumentList` (470) | `QuaternionFromArgumentList` `Core/Scripting/OOJSQuaternion.cpp:347` | ✅ |
| `QuaternionFromArgumentListNoError` (482) | `QuaternionFromArgumentListNoError` `Core/Scripting/OOJSQuaternion.cpp:363` | ✅ |
| `QuaternionGetProperty` (489) | `QuaternionGetProperty` `Core/Scripting/OOJSQuaternion.cpp:373` | ❌ |
| `QuaternionSetProperty` (529) | `QuaternionSetProperty` `Core/Scripting/OOJSQuaternion.cpp:413` | ✅ |
| `QuaternionFinalize` (573) | `QuaternionFinalize` `Core/Scripting/OOJSQuaternion.cpp:460` | ✅ |
| `QuaternionConstruct` (584) | `QuaternionConstruct` `Core/Scripting/OOJSQuaternion.cpp:468` | ✅ |
| `QuaternionToString` (626) | `QuaternionToString` `Core/Scripting/OOJSQuaternion.cpp:492` | ✅ |
| `QuaternionToSource` (641) | `QuaternionToSource` `Core/Scripting/OOJSQuaternion.cpp:506` | ✅ |
| `QuaternionMultiply` (657) | `QuaternionMultiply` `Core/Scripting/OOJSQuaternion.cpp:521` | ✅ |
| `QuaternionDot` (676) | `QuaternionDot` `Core/Scripting/OOJSQuaternion.cpp:540` | ✅ |
| `QuaternionRotate` (696) | `QuaternionRotate` `Core/Scripting/OOJSQuaternion.cpp:560` | ✅ |
| `QuaternionRotateX` (725) | `QuaternionRotateX` `Core/Scripting/OOJSQuaternion.cpp:591` | ✅ |
| `QuaternionRotateY` (745) | `QuaternionRotateY` `Core/Scripting/OOJSQuaternion.cpp:611` | ✅ |
| `QuaternionRotateZ` (765) | `QuaternionRotateZ` `Core/Scripting/OOJSQuaternion.cpp:631` | ✅ |
| `QuaternionNormalize` (785) | `QuaternionNormalize` `Core/Scripting/OOJSQuaternion.cpp:651` | ✅ |
| `QuaternionConjugate` (802) | `QuaternionConjugate` `Core/Scripting/OOJSQuaternion.cpp:667` | ✅ |
| `QuaternionVectorForward` (819) | `QuaternionVectorForward` `Core/Scripting/OOJSQuaternion.cpp:683` | ✅ |
| `QuaternionVectorUp` (837) | `QuaternionVectorUp` `Core/Scripting/OOJSQuaternion.cpp:701` | ✅ |
| `QuaternionVectorRight` (855) | `QuaternionVectorRight` `Core/Scripting/OOJSQuaternion.cpp:718` | ✅ |
| `QuaternionToArray` (873) | `QuaternionToArray` `Core/Scripting/OOJSQuaternion.cpp:735` | ✅ |
| `QuaternionStaticRandom` (918) | `QuaternionStaticRandom` `Core/Scripting/OOJSQuaternion.cpp:767` | ✅ |

**Differences:**

- ❌ **low** — (new) a `w`/`x`/`y`/`z` read or write whose `this` is not convertible to a quaternion (e.g. `Object.create(Quaternion.prototype).w`, or a getter applied to another object): upstream `return NO` with no report, which stopped the script silently; the port returns `undefined` (and the setter silently ignores the write). Quaternion instances and `Quaternion.prototype` (zero) behave the same — upstream `Core/Scripting/OOJSQuaternion.m:499-500,539-540` ↔ port `Core/Scripting/OOJSQuaternion.cpp:380-381,420-421`
- ⚠️ **low** — (new) `reportJSQuaternionStatistics`/`clearJSQuaternionStatistics` (debug builds, reached via `callObjC`) and their conversion counters are gone, "as upstream #768 did" (commit 2c31444b1). The previous audit's note about the missing `sum == 0` guard no longer applies — upstream `Core/Scripting/OOJSQuaternion.m:244-304`
- ✅ subtle — array conversion reads elements with `JS_GetPropertyUint32` (getters run) where upstream used `JS_LookupElement`; same values for plain arrays. No NaN check on array elements, as upstream; the four-number constructor form still rejects NaN — port `Core/Scripting/OOJSQuaternion.cpp:185-236,326-333`
- ✅ subtle — `toString()` uses the shared `QuaternionDescription`; `toSource()` is `Quaternion({:g}, …)` (= `%g`); the constructor no longer leaks its buffer on failure; private data is `new`/`delete` (commit 483b4dd22), not observable — port `Core/Scripting/OOJSQuaternion.cpp:146-160,460-487,492-518`

## OOJSScript

<a id="oojsscript"></a>
Upstream `src/Core/Scripting/OOJSScript.m` ↔ `Core/Scripting/OOJSScript.cpp` (761 / 1081 lines)

**Status:** done — 36 rows: 27 ✅ 7 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sScriptClass` JSClass (71) | `sScriptClass` `Core/Scripting/OOJSScript.cpp:126` (no addProperty hook; finalizer `OOJSCxxObjectWrapperFinalize`) | ✅ |
| `sScriptMethods[]` (85) | `sScriptMethods[]` + `ScriptToString` `Core/Scripting/OOJSScript.cpp:131,662` (toString, 0) | ✅ |
| `+[OOJSScript scriptWithPath:properties:]` (104) | `OOJSScript::scriptWithPath` `Core/Scripting/OOJSScript.cpp:137` | ✅ |
| `-[OOJSScript initWithPath:properties:]` (109) | `OOJSScript::initWithPath` `Core/Scripting/OOJSScript.cpp:144` | ⚠️ |
| `-[OOJSScript dealloc]` (256) | `OOJSScript::~OOJSScript` `Core/Scripting/OOJSScript.cpp:285` | ✅ |
| `-[OOJSScript oo_jsClassName]` (281) | `OOJSScript::jsClassName` `Core/Scripting/OOJSScript.cpp:303` | ✅ |
| `-[OOJSScript descriptionComponents]` (286) | `OOJSScript::descriptionComponents` `Core/Scripting/OOJSScript.cpp:307` | ✅ |
| `-[OOJSScript javaScriptEngineWillReset:]` (294) | `OOJSScript::javaScriptEngineWillReset` `Core/Scripting/OOJSScript.cpp:314` | ✅ |
| `+[OOJSScript currentlyRunningScript]` (305) | `OOJSScript::currentlyRunningScript` `Core/Scripting/OOJSScript.cpp:322` | ✅ |
| `+[OOJSScript scriptStack]` (312) | `OOJSScript::scriptStack` `Core/Scripting/OOJSScript.cpp:327` | ✅ |
| `-[OOJSScript weakRetain]` (321) | — replaced by `std::weak_ptr` (`ScriptPrivate` `Core/Scripting/OOJSScript.cpp:107`, `oo::share`) | ➖ |
| `-[OOJSScript weakRefDied:]` (328) | — replaced by `std::weak_ptr` expiry | ➖ |
| `-[OOJSScript name]` (334) | `OOJSScript::name` `Core/Scripting/OOJSScript.cpp:334` | ✅ |
| `-[OOJSScript scriptDescription]` (343) | `OOJSScript::scriptDescription` `Core/Scripting/OOJSScript.cpp:343` | ✅ |
| `-[OOJSScript version]` (348) | `OOJSScript::version` `Core/Scripting/OOJSScript.cpp:347` | ✅ |
| `-[OOJSScript runWithTarget:]` (353) | `OOJSScript::runWithTarget` `Core/Scripting/OOJSScript.cpp:349` | ✅ |
| `-[OOJSScript callMethod:inContext:withArguments:count:result:]` (357) | `OOJSScript::callMethod` `Core/Scripting/OOJSScript.cpp:351` | ✅ |
| `-[OOJSScript propertyWithID:inContext:]` (417) | `OOJSScript::propertyWithID` `Core/Scripting/OOJSScript.cpp:416` | ✅ |
| `-[OOJSScript setProperty:withID:inContext:]` (430) | `OOJSScript::setProperty(value, JSAtom, context)` `Core/Scripting/OOJSScript.cpp:431` | ⚠️ |
| `-[OOJSScript defineProperty:withID:inContext:]` (440) | `OOJSScript::defineProperty(value, JSAtom, context)` `Core/Scripting/OOJSScript.cpp:441` | ✅ |
| `-[OOJSScript propertyNamed:]` (450) | `OOJSScript::propertyNamed` `Core/Scripting/OOJSScript.cpp:452` | ✅ |
| `-[OOJSScript setProperty:named:]` (464) | `OOJSScript::setProperty(value, name)` `Core/Scripting/OOJSScript.cpp:462` | ✅ |
| `-[OOJSScript defineProperty:named:]` (478) | `OOJSScript::defineProperty(value, name)` `Core/Scripting/OOJSScript.cpp:474` | ✅ |
| `-[OOJSScript oo_jsValueInContext:]` (492) | `OOJSScript::jsValueInContext` `Core/Scripting/OOJSScript.cpp:486` | ✅ |
| `+[OOJSScript pushScript:]` (499) | `OOJSScript::pushScript` (raw and weak overloads) `Core/Scripting/OOJSScript.cpp:501,511` | ✅ |
| `+[OOJSScript popScript:]` (512) | `OOJSScript::popScript` `Core/Scripting/OOJSScript.cpp:520` | ✅ |
| `-[OOJSScript(OOPrivate) scriptNameFromPath:]` (541) | `OOJSScript::scriptNameFromPath` `Core/Scripting/OOJSScript.cpp:546` | ✅ |
| `-[OOJSScript(OOPrivate) defaultPropertiesFromPath:]` (573) | `OOJSScript::defaultPropertiesFromPath` + `StringForKey` + `ValueForKey` `Core/Scripting/OOJSScript.cpp:582,1064,1074` | ⚠️ |
| `-[OOScript(JavaScriptEvents) callMethod:inContext:withArguments:count:result:]` (603) | `OOScript::callMethod` `Core/Scripting/OOScript.cpp:306` (returns false) | ✅ |
| `InitOOJSScript` (614) | `InitOOJSScript` + `ScriptConverter` `Core/Scripting/OOJSScript.cpp:643,654` | ✅ |
| `ScriptAddProperty` (620) | `OOJSScript::checkForTickle` `Core/Scripting/OOJSScript.cpp:630` (checked once after the top level runs) | ⚠️ |
| `AddStackToArrayReversed` (635) | `AddStackToArrayReversed` `Core/Scripting/OOJSScript.cpp:683` | ✅ |
| `LoadScriptWithName` (643) | `RunScriptWithName` + `RewriteLegacyConst` + `HasModernScopeDirective` `Core/Scripting/OOJSScript.cpp:700,1013,920`; `OOJSWrapScriptSource` `Core/Scripting/OOJavaScriptEngine.cpp:591` | ⚠️ |
| `CompiledScriptData` (707) | `CacheCompiledScript` `Core/Scripting/OOJSScript.cpp:886` (QuickJS bytecode, cache "compiled QuickJS scripts") | ⚠️ |
| `ScriptWithCompiledData` (728) | `CachedCompiledScript` `Core/Scripting/OOJSScript.cpp:840` (hash/engine/format checked) | ⚠️ |
| `StrippedName` (754) | `StrippedName` `Core/Scripting/OOJSScript.cpp:1043` | ✅ |

**Differences:**

- ⚠️ **med** — (new) top-level `var` and function declarations of a script are now local to the script: the source runs as `(function(){with(this){(function(){<source>}).call(this)}})`, so `var foo`/`function foo(){}` at a script's top level no longer create globals visible to other scripts and the console. Upstream set `JSOPTION_VAROBJFIX`, so declarations went on the global object. Stated in the `OOJSWrapScriptSource` comment ("Top-level var declarations become local … No known OXP depends on that"). Scripts carrying the "use oolite modern" directive skip the `with` and the const rewrite but stay function-wrapped — upstream `Core/Scripting/OOJSScript.m:687,205` ↔ port `Core/Scripting/OOJSScript.cpp:740-752`, `Core/Scripting/OOJSEngineCore.h:140-156`, `Core/Scripting/OOJavaScriptEngine.cpp:591-596`
- ✅ **med** — (fixed since 2026-10-27) name resolution: the `with(this)` wrapper puts the script object (and its `Script.prototype`/`Object.prototype` chain) ahead of the global for bare identifiers in top-level code and closures, and assignment to a name found on the script object writes it there, as SpiderMonkey's scope chain did. The previous "scope fallback" global-prototype object is gone — port `Core/Scripting/OOJavaScriptEngine.cpp:591-596`
- ⚠️ **low** — (new) `const` is rewritten to `var` by the compatibility script's rewriter (cached per source text) to restore SpiderMonkey 1.8.5's function-scoped `const`; stated in the comment at `Core/Scripting/OOJSScript.cpp:1003-1012`. Restores parity for code that read a `const` before its declaration or redeclared it; a rewriter failure is reported and the unrewritten source is used — port `Core/Scripting/OOJSScript.cpp:1013-1039`
- ⚠️ **low** — (still open, reworded) the compiled-script cache is QuickJS bytecode under "compiled QuickJS scripts", keyed by path and validated by source hash, engine version and format; SpiderMonkey XDR caches are not read. Compilation is now done once (the previous double parse is gone) — upstream `Core/Scripting/OOJSScript.m:655-700,707-751` ↔ port `Core/Scripting/OOJSScript.cpp:760-779,840-912`
- ⚠️ **low** — (still open) manifest default properties and caller `properties` are set in sorted key order, not NSDictionary hash order (port comments at `:187-188`, `:201`); only the `for…in` order of a script object's own properties changes — upstream `Core/Scripting/OOJSScript.m:168-191` ↔ port `Core/Scripting/OOJSScript.cpp:186-209`
- ⚠️ **low** — (still open) `defaultPropertiesFromPath`: a non-dictionary `manifest.plist` no longer logs `plist.wrongType` (comment at `:592-595`); the nil-value raise for a non-string/number manifest value is kept (`ValueForKey`) — upstream `Core/Scripting/OOJSScript.m:576-596` ↔ port `Core/Scripting/OOJSScript.cpp:582-623,1074-1081`
- ⚠️ **low** — (still open) `setProperty:withID:` onto a read-only property: `JS_SetProperty` throws a TypeError where SpiderMonkey's non-strict `JS_SetPropertyById` silently did nothing; the port returns false and leaves the TypeError pending for the next report — upstream `Core/Scripting/OOJSScript.m:436-437` ↔ port `Core/Scripting/OOJSScript.cpp:437-438`
- ⚠️ **low** — the `tickle` warning ("Script %s appears to use the tickle() event handler, which is no longer supported.") is checked once after the top level has run; upstream's addProperty hook also fired for a `tickle` property added later (e.g. in `startUp`). Stated in the comment at `Core/Scripting/OOJSScript.cpp:625-629` — upstream `Core/Scripting/OOJSScript.m:620-633` ↔ port `Core/Scripting/OOJSScript.cpp:630-641`
- ❌ **low** — (new) log indentation of compile errors: upstream compiled the script before `OOLogIndentIf("script.javaScript.willLoad")`, so syntax-error reports were not indented; the port indents first and compiles inside `RunScriptWithName`, so with that log class enabled the compile error lines are indented one level. Also the manifest defaults are now set before the "About to load JavaScript" line rather than after compiling, so a manifest value that raises does so before that line — upstream `Core/Scripting/OOJSScript.m:160-180` ↔ port `Core/Scripting/OOJSScript.cpp:186-232`
- ✅ subtle — `callMethod`: a getter that throws while fetching the handler is now reported (upstream left it pending and returned NO); push/pop, time limiter, `script.javaScript.call` log and indent are unchanged; a non-function handler reports QuickJS's "not a function" text — port `Core/Scripting/OOJSScript.cpp:351-414`
- ✅ subtle — `name`/`version`/`description` go through `DescriptionOrNil` (`oo::DescriptionOf`, GNUstep `-description` form); `StrippedName` trims "_", space, tab, LF, CR, VT at both ends — port `Core/Scripting/OOJSScript.cpp:1043-1060`

## OOJSShip

<a id="oojsship"></a>
Upstream `src/Core/Scripting/OOJSShip.m` ↔ `Core/Scripting/OOJSShip.cpp` (4015 / 4541 lines)

**Status:** done — 99 rows: 92 ✅ 2 ⚠️ 4 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sShipClass` JSClass (166) | `sShipClass` `Core/Scripting/OOJSShip.cpp:188` (finalizer `OOJSCxxObjectWrapperFinalize`) | ✅ |
| `sShipProperties[]` (325) | `sShipProperties[]` `Core/Scripting/OOJSShip.cpp:375` (145 entries, same names and order incl. the duplicate `homeSystem`; only `speed` differs, RW instead of RO) | ⚠️ |
| `sShipMethods[]` (476) | `sShipMethods[]` `Core/Scripting/OOJSShip.cpp:632` (79 entries, same names and min args) | ✅ |
| `sShipStaticMethods[]` (562) | `sShipStaticMethods[]` `Core/Scripting/OOJSShip.cpp:721` (6 entries, same arities) | ✅ |
| `JSShipGetShipEntity` DEFINE_JS_OBJECT_GETTER (573) | `JSShipGetShipEntity` `Core/Scripting/OOJSShip.cpp:737` | ✅ |
| `GET_THIS_SHIP` macro (1823) | `GET_THIS_SHIP` `Core/Scripting/OOJSShip.cpp:2142` (failure → `OOJSNativeFailure`, stale → undefined) | ✅ |
| `InitOOJSShip` (575) | `InitOOJSShip` `Core/Scripting/OOJSShip.cpp:749` (`OOJSEntityObjectConverter`, bead oo-9ht.39.3) | ✅ |
| `JSShipClass` (582) | `JSShipClassID` `Core/Scripting/OOJSShip.cpp:764` | ✅ |
| `JSShipPrototype` (587) | — no accessor; `JS_GetClassProto(JSShipClassID())` (e.g. `Core/Scripting/OOJSPlayerShip.cpp:448`) | ➖ |
| `ShipGetProperty` (592) | `ShipGetProperty` `Core/Scripting/OOJSShip.cpp:826` | ✅ |
| `ShipSetProperty` (1177) | `ShipSetProperty` `Core/Scripting/OOJSShip.cpp:1414` (adds a `kSpeed` case `:1766`) | ⚠️ |
| `ShipSetScript` (1832) | `ShipSetScript` `Core/Scripting/OOJSShip.cpp:2150` | ✅ |
| `ShipSetAI` (1858) | `ShipSetAI` `Core/Scripting/OOJSShip.cpp:2177` | ✅ |
| `ShipSwitchAI` (1884) | `ShipSwitchAI` `Core/Scripting/OOJSShip.cpp:2204` | ✅ |
| `ShipExitAI` (1910) | `ShipExitAI` `Core/Scripting/OOJSShip.cpp:2231` | ✅ |
| `ShipReactToAIMessage` (1941) | `ShipReactToAIMessage` `Core/Scripting/OOJSShip.cpp:2268` | ✅ |
| `ShipSendAIMessage` (1967) | `ShipSendAIMessage` `Core/Scripting/OOJSShip.cpp:2295` | ✅ |
| `ShipDeployEscorts` (1993) | `ShipDeployEscorts` `Core/Scripting/OOJSShip.cpp:2322` | ✅ |
| `ShipDockEscorts` (2008) | `ShipDockEscorts` `Core/Scripting/OOJSShip.cpp:2337` | ✅ |
| `ShipHasEquipmentProviding` (2023) | `ShipHasEquipmentProviding` `Core/Scripting/OOJSShip.cpp:2352` | ✅ |
| `ShipHasRole` (2045) | `ShipHasRole` `Core/Scripting/OOJSShip.cpp:2375` | ✅ |
| `ShipEjectItem` (2067) | `ShipEjectItem` `Core/Scripting/OOJSShip.cpp:2397` | ✅ |
| `ShipAddCargoEntity` (2089) | `ShipAddCargoEntity` `Core/Scripting/OOJSShip.cpp:2420` | ✅ |
| `ShipEjectSpecificItem` (2135) | `ShipEjectSpecificItem` `Core/Scripting/OOJSShip.cpp:2485` | ✅ |
| `ShipDumpCargo` (2157) | `ShipDumpCargo` `Core/Scripting/OOJSShip.cpp:2508` | ✅ |
| `ShipSpawn` (2197) | `ShipSpawn` `Core/Scripting/OOJSShip.cpp:2561` | ✅ |
| `ShipDealEnergyDamage` (2228) | `ShipDealEnergyDamage` `Core/Scripting/OOJSShip.cpp:2592` | ✅ |
| `ShipExplode` (2272) | `ShipExplode` `Core/Scripting/OOJSShip.cpp:2643` | ✅ |
| `ShipRemove` (2282) | `ShipRemove` `Core/Scripting/OOJSShip.cpp:2652` | ✅ |
| `ShipRunLegacyScriptActions` (2312) | `ShipRunLegacyScriptActions` `Core/Scripting/OOJSShip.cpp:2685` | ✅ |
| `ShipCommsMessage` (2346) | `ShipCommsMessage` `Core/Scripting/OOJSShip.cpp:2724` | ✅ |
| `ShipFireECM` (2375) | `ShipFireECM` `Core/Scripting/OOJSShip.cpp:2757` | ✅ |
| `ShipAbandonShip` (2395) | `ShipAbandonShip` `Core/Scripting/OOJSShip.cpp:2783` | ✅ |
| `ShipCanAwardEquipment` (2408) | `ShipCanAwardEquipment` `Core/Scripting/OOJSShip.cpp:2796` | ✅ |
| `ShipAwardEquipment` (2454) | `ShipAwardEquipment` `Core/Scripting/OOJSShip.cpp:2845` | ✅ |
| `ShipRemoveEquipment` (2523) | `ShipRemoveEquipment` `Core/Scripting/OOJSShip.cpp:2921` | ✅ |
| `ShipRestoreSubEntities` (2574) | `ShipRestoreSubEntities` `Core/Scripting/OOJSShip.cpp:2975` | ✅ |
| `ShipSetEquipmentStatus` (2603) | `ShipSetEquipmentStatus` `Core/Scripting/OOJSShip.cpp:3008` | ✅ |
| `ShipEquipmentStatus` (2683) | `ShipEquipmentStatus` `Core/Scripting/OOJSShip.cpp:3102` | ✅ |
| `ShipSelectNewMissile` (2742) | `ShipSelectNewMissile` `Core/Scripting/OOJSShip.cpp:3148` | ✅ |
| `ShipFireMissile` (2761) | `ShipFireMissile` `Core/Scripting/OOJSShip.cpp:3168` | ✅ |
| `ShipFindNearestStation` (2781) | `ShipFindNearestStation` `Core/Scripting/OOJSShip.cpp:3190` | ✅ |
| `ShipSetBounty` (2808) | `ShipSetBounty` `Core/Scripting/OOJSShip.cpp:3224` | ❌ |
| `ShipSetCargo` (2836) | `ShipSetCargo` `Core/Scripting/OOJSShip.cpp:3251` | ✅ |
| `ShipSetCrew` (2866) | `ShipSetCrew` `Core/Scripting/OOJSShip.cpp:3286` | ❌ |
| `ShipSetCargoType` (2902) | `ShipSetCargoType` `Core/Scripting/OOJSShip.cpp:3328` | ✅ |
| `ShipSetMaterials` (2941) | `ShipSetMaterials` `Core/Scripting/OOJSShip.cpp:3372` | ✅ |
| `ShipSetShaders` (2960) | `ShipSetShaders` `Core/Scripting/OOJSShip.cpp:3392` | ✅ |
| `ShipSetMaterialsInternal` (2985) | `ShipSetMaterialsInternal` `Core/Scripting/OOJSShip.cpp:3426` | ✅ |
| `ShipExitSystem` (3049) | `ShipExitSystem` `Core/Scripting/OOJSShip.cpp:3507` | ✅ |
| `ShipUpdateEscortFormation` (3077) | `ShipUpdateEscortFormation` `Core/Scripting/OOJSShip.cpp:3539` | ✅ |
| `RemoveOrExplodeShip` (3090) | `RemoveOrExplodeShip` `Core/Scripting/OOJSShip.cpp:3553` | ✅ |
| `ShipClearDefenseTargets` (3133) | `ShipClearDefenseTargets` `Core/Scripting/OOJSShip.cpp:3602` | ✅ |
| `ShipAddDefenseTarget` (3146) | `ShipAddDefenseTarget` `Core/Scripting/OOJSShip.cpp:3615` | ✅ |
| `ShipRemoveDefenseTarget` (3166) | `ShipRemoveDefenseTarget` `Core/Scripting/OOJSShip.cpp:3639` | ✅ |
| `ShipAddCollisionException` (3186) | `ShipAddCollisionException` `Core/Scripting/OOJSShip.cpp:3663` | ✅ |
| `ShipRemoveCollisionException` (3210) | `ShipRemoveCollisionException` `Core/Scripting/OOJSShip.cpp:3693` | ✅ |
| `ShipGetMaterials` (3233) | `ShipGetMaterials` `Core/Scripting/OOJSShip.cpp:3722` | ✅ |
| `ShipGetShaders` (3251) | `ShipGetShaders` `Core/Scripting/OOJSShip.cpp:3739` | ✅ |
| `ShipBroadcastCascadeImminent` (3268) | `ShipBroadcastCascadeImminent` `Core/Scripting/OOJSShip.cpp:3755` | ✅ |
| `ShipBecomeCascadeExplosion` (3281) | `ShipBecomeCascadeExplosion` `Core/Scripting/OOJSShip.cpp:3768` | ✅ |
| `ShipOfferToEscort` (3294) | `ShipOfferToEscort` `Core/Scripting/OOJSShip.cpp:3781` | ✅ |
| `ShipRequestHelpFromGroup` (3314) | `ShipRequestHelpFromGroup` `Core/Scripting/OOJSShip.cpp:3805` | ✅ |
| `ShipPatrolReportIn` (3329) | `ShipPatrolReportIn` `Core/Scripting/OOJSShip.cpp:3820` | ✅ |
| `ShipMarkTargetForFines` (3351) | `ShipMarkTargetForFines` `Core/Scripting/OOJSShip.cpp:3847` | ✅ |
| `ShipEnterWormhole` (3370) | `ShipEnterWormhole` `Core/Scripting/OOJSShip.cpp:3866` | ✅ |
| `ShipNotifyGroupOfWormhole` (3399) | `ShipNotifyGroupOfWormhole` `Core/Scripting/OOJSShip.cpp:3905` | ✅ |
| `ShipThrowSpark` (3413) | `ShipThrowSpark` `Core/Scripting/OOJSShip.cpp:3919` | ✅ |
| `ShipPerformAttack` (3426) | `ShipPerformAttack` `Core/Scripting/OOJSShip.cpp:3932` | ✅ |
| `ShipPerformCollect` (3439) | `ShipPerformCollect` `Core/Scripting/OOJSShip.cpp:3945` | ✅ |
| `ShipPerformEscort` (3452) | `ShipPerformEscort` `Core/Scripting/OOJSShip.cpp:3958` | ✅ |
| `ShipPerformFaceDestination` (3465) | `ShipPerformFaceDestination` `Core/Scripting/OOJSShip.cpp:3971` | ✅ |
| `ShipPerformFlee` (3478) | `ShipPerformFlee` `Core/Scripting/OOJSShip.cpp:3984` | ✅ |
| `ShipPerformFlyToRangeFromDestination` (3491) | `ShipPerformFlyToRangeFromDestination` `Core/Scripting/OOJSShip.cpp:3997` | ✅ |
| `ShipPerformHold` (3504) | `ShipPerformHold` `Core/Scripting/OOJSShip.cpp:4010` | ✅ |
| `ShipPerformIdle` (3517) | `ShipPerformIdle` `Core/Scripting/OOJSShip.cpp:4023` | ✅ |
| `ShipPerformIntercept` (3530) | `ShipPerformIntercept` `Core/Scripting/OOJSShip.cpp:4036` | ✅ |
| `ShipPerformLandOnPlanet` (3543) | `ShipPerformLandOnPlanet` `Core/Scripting/OOJSShip.cpp:4049` | ✅ |
| `ShipPerformMining` (3556) | `ShipPerformMining` `Core/Scripting/OOJSShip.cpp:4062` | ✅ |
| `ShipPerformScriptedAI` (3569) | `ShipPerformScriptedAI` `Core/Scripting/OOJSShip.cpp:4075` | ✅ |
| `ShipPerformScriptedAttackAI` (3582) | `ShipPerformScriptedAttackAI` `Core/Scripting/OOJSShip.cpp:4088` | ✅ |
| `ShipPerformStop` (3595) | `ShipPerformStop` `Core/Scripting/OOJSShip.cpp:4101` | ✅ |
| `ShipPerformTumble` (3608) | `ShipPerformTumble` `Core/Scripting/OOJSShip.cpp:4114` | ✅ |
| `ShipRequestDockingInstructions` (3621) | `ShipRequestDockingInstructions` `Core/Scripting/OOJSShip.cpp:4127` | ✅ |
| `ShipRecallDockingInstructions` (3639) | `ShipRecallDockingInstructions` `Core/Scripting/OOJSShip.cpp:4140` | ✅ |
| `ShipBroadcastDistressMessage` (3657) | `ShipBroadcastDistressMessage` `Core/Scripting/OOJSShip.cpp:4153` | ✅ |
| `ShipCheckCourseToDestination` (3670) | `ShipCheckCourseToDestination` `Core/Scripting/OOJSShip.cpp:4166` | ✅ |
| `ShipGetSafeCourseToDestination` (3684) | `ShipGetSafeCourseToDestination` `Core/Scripting/OOJSShip.cpp:4184` | ✅ |
| `ShipCheckScanner` (3698) | `ShipCheckScanner` `Core/Scripting/OOJSShip.cpp:4201` | ✅ |
| `ShipAdjustCargo` (3728) | `ShipAdjustCargo` `Core/Scripting/OOJSShip.cpp:4235` | ✅ |
| `ShipDamageAssessment` (3770) | `ShipDamageAssessment` `Core/Scripting/OOJSShip.cpp:4283` | ✅ |
| `ShipThreatAssessment` (3797) | `ShipThreatAssessment` `Core/Scripting/OOJSShip.cpp:4310` | ✅ |
| `ShipThreatAssessmentWeapon` (3918) | `ShipThreatAssessmentWeapon` `Core/Scripting/OOJSShip.cpp:4439` | ✅ |
| `ShipStaticKeys` (3928) | `ShipStaticKeys` `Core/Scripting/OOJSShip.cpp:4448` | ❌ |
| `ShipStaticKeysForRole` (3939) | `ShipStaticKeysForRole` `Core/Scripting/OOJSShip.cpp:4457` | ✅ |
| `ShipStaticRoleIsInCategory` (3956) | `ShipStaticRoleIsInCategory` `Core/Scripting/OOJSShip.cpp:4478` | ✅ |
| `ShipStaticRoles` (3973) | `ShipStaticRoles` `Core/Scripting/OOJSShip.cpp:4500` | ❌ |
| `ShipStaticShipDataForKey` (3984) | `ShipStaticShipDataForKey` `Core/Scripting/OOJSShip.cpp:4509` | ✅ |
| `ShipStaticSetShipDataForKey` (4000) | `ShipStaticSetShipDataForKey` `Core/Scripting/OOJSShip.cpp:4526` | ✅ |

**Differences:**

- ⚠️ **med** — (still open) `ship.speed` is writable: the property is `OOJS_PROPERTY_RW` and `ShipSetProperty` has a `kSpeed` case that calls `setSpeed()`, refuses negative/NaN with "ship.speed must be a number >= 0." and reports "player.ship.speed is read-only." for the player. Upstream's property was `OOJS_PROP_READONLY_CB` and writes were ignored (TypeError in strict code). The port comment explains the intent — upstream `Core/Scripting/OOJSShip.m:450,870-871` ↔ port `Core/Scripting/OOJSShip.cpp:586-587,1766-1800`
- ❌ **low** — (still open) `setCrew(def)` when `OOCharacter::characterWithDictionary` answers nil: upstream `[NSArray arrayWithObject:nil]` raised (native exception to the script); the port skips the nil character, sets an empty crew and returns `true` (comment at `:3313-3315`) — upstream `Core/Scripting/OOJSShip.m:2888-2890` ↔ port `Core/Scripting/OOJSShip.cpp:3309-3316`
- ❌ **low** — (still open) `Ship.keys()` and `Ship.roles()` return the registry's `std::map` order (sorted), not NSDictionary `-allKeys` hash order; contents are the same. The order comes from `OOShipRegistry`, not this file — upstream `Core/Scripting/OOJSShip.m:3933,3978` ↔ port `Core/Scripting/OOJSShip.cpp:4452,4504`
- ❌ **low** — (new; the previous audit read this as "returns true") `setBounty(amount, reason)` upstream ends with a bare `return YES;` without setting rval, so under SpiderMonkey 1.8.5 the call evaluates to the callee (the `setBounty` function object, `upstream/spidermonkey-ff4/js/src/jscntxtinlines.h:695-707`); the port returns `undefined`. Only visible if a script uses the result — upstream `Core/Scripting/OOJSShip.m:2828-2830` ↔ port `Core/Scripting/OOJSShip.cpp:3243-3245`
- ✅ note — Init registers `OOJSEntityObjectConverter` and the class finalizer is `OOJSCxxObjectWrapperFinalize` (entity-holder replacement, bead oo-9ht.39.3); the converted value is still the entity or null when stale — upstream `Core/Scripting/OOJSShip.m:575-580` ↔ port `Core/Scripting/OOJSShip.cpp:188-191,749-762`
- ✅ note (dict key order) — `roleWeights` (floats) and `equipmentStatus(…, true)` build `PList::Dict`s, so keys enumerate sorted (`EQUIPMENT_DAMAGED` before `EQUIPMENT_OK`); values unchanged — port `Core/Scripting/OOJSShip.cpp:867-879,3129-3135`
- ✅ note — getter, setter and every method re-read on this commit: types, null vs undefined, stale → undefined, validation and error texts match; the token diff from 48cbd7abf to HEAD shows only mechanical changes (enum class, named casts, `std::format`, split string literals). Upstream quirks are kept: `entityPersonality` falls through to `hyperspaceSpinTime` on a failed int conversion, `patrolReportIn` reports as `addDefenseTarget`, `keysForRole` as `shipKeysForRole`, `setShipDataForKey` as `setShipInfoForKey`, and the property table lists `homeSystem` twice — port `Core/Scripting/OOJSShip.cpp:1559-1575,3831,4470,4536`
- ✅ note (nil arguments) — `checkScanner` skips null entries (upstream `addObject:nil` would raise); `setCrew` with a primitive argument now reports bad arguments where upstream cast a non-object (undefined behaviour); `dumpCargo(n)` schedules the extra drops with `oo::ScheduleEntityCall` at 0.75 s steps, as `performSelector:afterDelay:` did — port `Core/Scripting/OOJSShip.cpp:2542-2551,3296-3302,4225-4229`

## OOJSShipGroup

<a id="oojsshipgroup"></a>
Upstream `src/Core/Scripting/OOJSShipGroup.m` ↔ `Core/Scripting/OOJSShipGroup.cpp` (347 / 454 lines)

**Status:** done — 13 rows: 13 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sShipGroupClass` JSClass (41) | `sShipGroupClass` `Core/Scripting/OOJSShipGroup.cpp:57` (finalizer `OOJSCxxObjectWrapperFinalize`; the slot retains the group) | ✅ |
| `sShipGroupProperties[]` (64) | `sShipGroupProperties[]` `Core/Scripting/OOJSShipGroup.cpp:74` (count RO, leader RW, name RW, ships RO) | ✅ |
| `sShipGroupMethods[]` (73) | `sShipGroupMethods[]` + `ShipGroupToString` `Core/Scripting/OOJSShipGroup.cpp:84,298` (toString 0, addShip 1, containsShip 1, removeShip 1) | ✅ |
| `JSShipGroupGetShipGroup` DEFINE_JS_OBJECT_GETTER (82) | `OOJSGetCxxPrivate(context, value, sShipGroupClassID, &group)` (comment `Core/Scripting/OOJSShipGroup.cpp:92-94`) | ✅ |
| `InitOOJSShipGroup` (84) | `InitOOJSShipGroup` + `ShipGroupConverter` `Core/Scripting/OOJSShipGroup.cpp:108,98` | ✅ |
| `ShipGroupGetProperty` (90) | `ShipGroupGetProperty` `Core/Scripting/OOJSShipGroup.cpp:117` | ✅ |
| `ShipGroupSetProperty` (134) | `ShipGroupSetProperty` `Core/Scripting/OOJSShipGroup.cpp:166` | ✅ |
| `ShipGroupConstruct` (173) | `ShipGroupConstruct` `Core/Scripting/OOJSShipGroup.cpp:210` | ✅ |
| `-[OOShipGroup(OOJavaScriptExtensions) oo_jsValueInContext:]` (208) | `OOShipGroup::jsValueInContext` `Core/Scripting/OOJSShipGroup.cpp:258` | ✅ |
| `-[OOShipGroup(OOJavaScriptExtensions) oo_clearJSSelf:]` (226) | `OOShipGroup::clearJSSelf` `Core/Scripting/OOJSShipGroup.cpp:279` | ✅ |
| `ShipGroupAddShip` (237) | `ShipGroupAddShip` `Core/Scripting/OOJSShipGroup.cpp:303` | ✅ |
| `ShipGroupRemoveShip` (298) | `ShipGroupRemoveShip` `Core/Scripting/OOJSShipGroup.cpp:403` | ✅ |
| `ShipGroupContainsShip` (324) | `ShipGroupContainsShip` `Core/Scripting/OOJSShipGroup.cpp:430` | ✅ |

**Differences:**

- ✅ note — the escort-group branch of `addShip` is unchanged: "Ship %s cannot be assigned to two escort groups, ignoring." (the ship now printed through `oo::EntityDescription`), `acceptAsEscort`, and a new `"ship group"` group leaked at +1 for a default unescorted leader, as upstream's `alloc/init` did — upstream `Core/Scripting/OOJSShipGroup.m:258-292` ↔ port `Core/Scripting/OOJSShipGroup.cpp:328-397`
- ✅ note — the prototype (no private) answers what a message to nil did: `ships` `[]`, `leader` null, `name` null (an `OONull` node), `count` 0; setters do nothing. `name` accepts any value through `OOStringFromJSValueEvenIfNull` ("null"/"undefined" strings) — port `Core/Scripting/OOJSShipGroup.cpp:117-207`
- ✅ note — `ShipGroup()` without `new` reports "ShipGroup() cannot be called as a function, it must be used as a constructor (as in new ShipGroup(...))." using `OOJS_IS_CONSTRUCTING` (QuickJS has no `JS_IsConstructing`) — port `Core/Scripting/OOJSShipGroup.cpp:213-222`

## OOJSSound

<a id="oojssound"></a>
Upstream `src/Core/Scripting/OOJSSound.m` ↔ `Core/Scripting/OOJSSound.cpp` (299 / 341 lines)

**Status:** done — 15 rows: 13 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sSoundClass` JSClass (43) | `sSoundClass` `Core/Scripting/OOJSSound.cpp:71` (finalizer `OOJSCxxObjectWrapperFinalize`) | ✅ |
| `sSoundProperties[]` (63) | `sSoundProperties[]` `Core/Scripting/OOJSSound.cpp:85` (`name` RO) | ✅ |
| `sSoundMethods[]` (69) | `sSoundMethods[]` + `SoundToString` `Core/Scripting/OOJSSound.cpp:90,205` (toString 0) | ✅ |
| `sSoundStaticMethods[]` (79) | `sSoundStaticMethods[]` `Core/Scripting/OOJSSound.cpp:95` (load 1, musicSoundSource 0, playMusic 1, stopMusic 0) | ✅ |
| `InitOOJSSound` (108) | `InitOOJSSound` + `SoundConverter` `Core/Scripting/OOJSSound.cpp:122,116` | ⚠️ |
| `SoundFromJSValue` (114) | `SoundFromJSValue` `Core/Scripting/OOJSSound.cpp:132` | ⚠️ |
| `SoundGetProperty` (131) | `SoundGetProperty` + `JSSoundGetSound` `Core/Scripting/OOJSSound.cpp:163,106` | ✅ |
| `GetNamedSound` (156) | `GetNamedSound` `Core/Scripting/OOJSSound.cpp:190` | ✅ |
| `SoundStaticLoad` (172) | `SoundStaticLoad` `Core/Scripting/OOJSSound.cpp:212` | ✅ |
| `SoundStaticMusicSoundSource` (195) | `SoundStaticMusicSoundSource` `Core/Scripting/OOJSSound.cpp:234` | ✅ |
| `SoundStaticPlayMusic` (207) | `SoundStaticPlayMusic` `Core/Scripting/OOJSSound.cpp:245` | ✅ |
| `SoundStaticStopMusic` (245) | `SoundStaticStopMusic` `Core/Scripting/OOJSSound.cpp:288` | ✅ |
| `-[OOSound(OOJavaScriptExtentions) oo_jsValueInContext:]` (273) | `OOJSSoundJSValueInContext` `Core/Scripting/OOJSSound.cpp:315` (new wrapper per call, slot holds an `OOJSSoundHolder`) | ✅ |
| `-[OOSound(OOJavaScriptExtentions) oo_jsDescription]` (289) | `OOJSSoundJSDescription` `Core/Scripting/OOJSSound.cpp:333` | ✅ |
| `-[OOSound(OOJavaScriptExtentions) oo_jsClassName]` (294) | `OOJSSoundJSClassName` `Core/Scripting/OOJSSound.cpp:339` | ✅ |

**Differences:**

- ⚠️ **low** — (new; the previous audit recorded the unbalanced pause as kept) `SoundFromJSValue` now resumes the time limiter it paused. Upstream returned from inside the pause, so after a sound was looked up by name (e.g. `soundSource.sound = "x.ogg"`) the limiter stayed paused until the next outermost `OOJSStartTimeLimiter` reset the depth, and the rest of that script call could not time out. The port enforces the limit there. Stated in the comment ("The SpiderMonkey version returned before resuming the time limiter, leaving it paused; the pause is balanced here.") — upstream `Core/Scripting/OOJSSound.m:118-124`, `OOJSEngineTimeManagement.m:88-92` ↔ port `Core/Scripting/OOJSSound.cpp:137-156`
- ⚠️ **low** — (still open) the converter registered for `Sound` returns null instead of the native `OOSound` (`OOJSBasicPrivateObjectConverter`); generic JS→native/plist conversion of a Sound gives null. Its own callers use `SoundFromJSValue`, which reads the slot (comment at `:114-115`) — upstream `Core/Scripting/OOJSSound.m:111` ↔ port `Core/Scripting/OOJSSound.cpp:114-118,129`
- ✅ note — `playMusic` argument errors and arities match, including upstream's second report with count 1 after `OOJSArgumentListGetNumber` fails; `stopMusic` text "string or no argument" matches; `Sound.prototype.name` is null, as a message to nil — port `Core/Scripting/OOJSSound.cpp:163-188,245-312`

## OOJSSoundSource

<a id="oojssoundsource"></a>
Upstream `src/Core/Scripting/OOJSSoundSource.m` ↔ `Core/Scripting/OOJSSoundSource.cpp` (345 / 387 lines)

**Status:** done — 13 rows: 12 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sSoundSourceClass` JSClass (42) | `sSoundSourceClass` `Core/Scripting/OOJSSoundSource.cpp:53` (finalizer `OOJSCxxObjectWrapperFinalize`) | ✅ |
| `sSoundSourceProperties[]` (68) | `sSoundSourceProperties[]` `Core/Scripting/OOJSSoundSource.cpp:73` (isPlaying RO; loop, position, positional, repeatCount, sound, volume RW) | ✅ |
| `sSoundSourceMethods[]` (80) | `sSoundSourceMethods[]` + `SoundSourceToString` `Core/Scripting/OOJSSoundSource.cpp:91,293` (toString 0, play 0, playOrRepeat 0, stop 0) | ✅ |
| inherited `oo_jsDescription` (NSObject) | `OOJSSoundSourceHolder::jsDescription` `Core/Scripting/OOJSSoundSource.cpp:111` (`[SoundSource <components>]`) | ✅ |
| `InitOOJSSoundSource` (110) | `InitOOJSSoundSource` + `SoundSourceConverter` `Core/Scripting/OOJSSoundSource.cpp:139,133` | ⚠️ |
| `SoundSourceConstruct` (116) | `SoundSourceConstruct` `Core/Scripting/OOJSSoundSource.cpp:148` | ✅ |
| `SoundSourceGetProperty` (132) | `SoundSourceGetProperty` + `JSSoundSourceGetSoundSource` `Core/Scripting/OOJSSoundSource.cpp:168,122` | ✅ |
| `SoundSourceSetProperty` (179) | `SoundSourceSetProperty` `Core/Scripting/OOJSSoundSource.cpp:218` | ✅ |
| `SoundSourcePlay` (255) | `SoundSourcePlay` `Core/Scripting/OOJSSoundSource.cpp:298` | ✅ |
| `SoundSourceStop` (285) | `SoundSourceStop` `Core/Scripting/OOJSSoundSource.cpp:328` | ✅ |
| `SoundSourcePlayOrRepeat` (304) | `SoundSourcePlayOrRepeat` `Core/Scripting/OOJSSoundSource.cpp:346` | ✅ |
| `-[OOSoundSource(OOJavaScriptExtentions) oo_jsValueInContext:]` (324) | `OOJSSoundSourceJSValueInContext` `Core/Scripting/OOJSSoundSource.cpp:365` | ✅ |
| `-[OOSoundSource(OOJavaScriptExtentions) oo_jsClassName]` (340) | `OOJSSoundSourceJSClassName` `Core/Scripting/OOJSSoundSource.cpp:385` | ✅ |

**Differences:**

- ⚠️ **low** — (still open) the `SoundSource` converter returns null instead of the native `OOSoundSource` (comment "there is no object to hand over, and nothing asks for one") — upstream `Core/Scripting/OOJSSoundSource.m:113` ↔ port `Core/Scripting/OOJSSoundSource.cpp:131-135,145`
- ✅ note — setters keep upstream's dead `if (100 < 1)` and the 0..1 volume clamp; `play(n)` caps at 100 and treats `undefined` as no argument; `SoundSource()` without `new` reports the same text via `OOJS_IS_CONSTRUCTING`; the prototype answers what a message to nil did — port `Core/Scripting/OOJSSoundSource.cpp:148-164,218-325`
- ✅ note — the `sound` setter goes through `SoundFromJSValue`, which now balances its time-limiter pause (see OOJSSound) — port `Core/Scripting/OOJSSoundSource.cpp:232-235`

## OOJSSpecialFunctions

<a id="oojsspecialfunctions"></a>
Upstream `src/Core/Scripting/OOJSSpecialFunctions.m` ↔ `Core/Scripting/OOJSSpecialFunctions.cpp` (101 / 100 lines)

**Status:** done — 5 rows: 4 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sSpecialFunctionsMethods[]` (33) | `sSpecialFunctionsMethods[]` `Core/Scripting/OOJSSpecialFunctions.cpp:35` (jsWarning 1; markConsoleEntryPoint 0 under `OO_DEBUG_MONITOR_ENABLED`) | ✅ |
| `InitOOJSSpecialFunctions` (43) | `InitOOJSSpecialFunctions` `Core/Scripting/OOJSSpecialFunctions.cpp:44` | ✅ |
| `JSSpecialFunctionsObjectWrapper` (47) | `JSSpecialFunctionsObjectWrapper` `Core/Scripting/OOJSSpecialFunctions.cpp:47` (returns an owned, frozen object instead of an `OOJSValue`) | ✅ |
| `SpecialJSWarning` (70) | `SpecialJSWarning` `Core/Scripting/OOJSSpecialFunctions.cpp:69` | ✅ |
| `SpecialMarkConsoleEntryPoint` (90) | `SpecialMarkConsoleEntryPoint` `Core/Scripting/OOJSSpecialFunctions.cpp:90` | ⚠️ |

**Differences:**

- ⚠️ **low** — (new; the previous audit had this row ✅) `special.markConsoleEntryPoint()` (debug-monitor builds only) now does nothing. Upstream recorded the calling stack frame with `OOJSMarkConsoleEvalLocation()` so that locations in console-evaluated code were described specially in error/warning reports; the port comment says QuickJS has no stack-frame API and console code locations are reported like any other — upstream `Core/Scripting/OOJSSpecialFunctions.m:89-101` ↔ port `Core/Scripting/OOJSSpecialFunctions.cpp:89-100`
- ✅ note — `jsWarning(text)` sets the stack skip to 1 around the warning and prints a nil string as "(null)", as `%@` did; fewer than one argument reports bad arguments under "special"/"jsWarning" — port `Core/Scripting/OOJSSpecialFunctions.cpp:69-87`

## OOJSStation

<a id="oojsstation"></a>
Upstream `src/Core/Scripting/OOJSStation.m` ↔ `Core/Scripting/OOJSStation.cpp` (1085 / 1433 lines)

**Status:** done — 31 rows: 29 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sStationClass` JSClass (66) | `sStationClass` `Core/Scripting/OOJSStation.cpp:87` | ✅ |
| `sStationProperties[]` (103) | `sStationProperties[]` `Core/Scripting/OOJSStation.cpp:118` (18 entries, same names, order and RO/RW) | ✅ |
| `sStationMethods[]` (126) | `sStationMethods[]` `Core/Scripting/OOJSStation.cpp:159` (20 entries, same names and min args) | ✅ |
| stale-`this` idiom `if (!JSStationGetStationEntity(...)) OOJS_RETURN_VOID;` (535…) | `GET_THIS_STATION` `Core/Scripting/OOJSStation.cpp:255` (returns the pending exception when `this` is not an Entity) | ✅ |
| `InitOOJSStation` (151) | `InitOOJSStation` `Core/Scripting/OOJSStation.cpp:183` (`OOJSEntityObjectConverter`, bead oo-9ht.39.3) | ✅ |
| `JSStationGetStationEntity` (158) | `JSStationGetStationEntity` `Core/Scripting/OOJSStation.cpp:205` | ✅ |
| `JSStationGetShipEntity` (182) | `JSStationGetShipEntity` `Core/Scripting/OOJSStation.cpp:229` | ✅ |
| `-[StationEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (208) | `StationEntity::jsClassID` `Core/Entities/StationEntity.cpp:806` → `JSStationClassID` `Core/Scripting/OOJSStation.cpp:199` | ✅ |
| `-[StationEntity(OOJavaScriptExtensions) oo_jsClassName]` (214) | `OOJSStationJSClassName` `Core/Scripting/OOJSStation.cpp:265` | ✅ |
| `StationGetProperty` (221) | `StationGetProperty` `Core/Scripting/OOJSStation.cpp:269` | ✅ |
| `StationSetProperty` (330) | `StationSetProperty` `Core/Scripting/OOJSStation.cpp:396` | ✅ |
| `StationAbortAllDockings` (434) | `StationAbortAllDockings` `Core/Scripting/OOJSStation.cpp:501` | ✅ |
| `StationAbortDockingForShip` (447) | `StationAbortDockingForShip` `Core/Scripting/OOJSStation.cpp:516` | ✅ |
| `StationCanDockShip` (472) | `StationCanDockShip` `Core/Scripting/OOJSStation.cpp:546` | ✅ |
| `StationDockPlayer` (503) | `StationDockPlayer` `Core/Scripting/OOJSStation.cpp:578` | ✅ |
| `StationIncreaseAlertLevel` (531) | `StationIncreaseAlertLevel` `Core/Scripting/OOJSStation.cpp:621` | ✅ |
| `StationDecreaseAlertLevel` (548) | `StationDecreaseAlertLevel` `Core/Scripting/OOJSStation.cpp:641` | ✅ |
| `StationLaunchShipWithRole` (566) | `StationLaunchShipWithRole` `Core/Scripting/OOJSStation.cpp:662` | ✅ |
| `StationLaunchDefenseShip` (598) | `StationLaunchDefenseShip` `Core/Scripting/OOJSStation.cpp:696` | ✅ |
| `StationLaunchEscort` (615) | `StationLaunchEscort` `Core/Scripting/OOJSStation.cpp:713` | ✅ |
| `StationLaunchScavenger` (632) | `StationLaunchScavenger` `Core/Scripting/OOJSStation.cpp:730` | ✅ |
| `StationLaunchMiner` (649) | `StationLaunchMiner` `Core/Scripting/OOJSStation.cpp:747` | ✅ |
| `StationLaunchPirateShip` (665) | `StationLaunchPirateShip` `Core/Scripting/OOJSStation.cpp:763` | ✅ |
| `StationLaunchShuttle` (682) | `StationLaunchShuttle` `Core/Scripting/OOJSStation.cpp:780` | ✅ |
| `StationLaunchPatrol` (698) | `StationLaunchPatrol` `Core/Scripting/OOJSStation.cpp:796` | ✅ |
| `StationLaunchPolice` (714) | `StationLaunchPolice` `Core/Scripting/OOJSStation.cpp:812` | ✅ |
| `StationSetInterface` (730) | `StationSetInterface` + `GetParam` `Core/Scripting/OOJSStation.cpp:841,831` | ❌ |
| `StationSetMarketPrice` (827) | `StationSetMarketPrice` `Core/Scripting/OOJSStation.cpp:993` | ✅ |
| `StationSetMarketQuantity` (864) | `StationSetMarketQuantity` `Core/Scripting/OOJSStation.cpp:1045` | ✅ |
| `StationAddShipToShipyard` (901) | `StationAddShipToShipyard` + `StringForKey`/`StringAtIndex`/`ValueForKey` `Core/Scripting/OOJSStation.cpp:1148,1109-1140` | ❌ |
| `StationRemoveShipFromShipyard` (1048) | `StationRemoveShipFromShipyard` `Core/Scripting/OOJSStation.cpp:1382` | ✅ |

**Differences:**

- ❌ **low** — (still open) `setInterface(key, def)` with a null/undefined `key`: upstream's nil key made `setObject:definition forKey:nil` raise (native exception to the script; removal with a nil key was a warned no-op in GNUstep). The port uses `key.value_or("")`, so it silently stores (or erases) the definition under `""` — upstream `Core/Scripting/OOJSStation.m:742-747,818` ↔ port `Core/Scripting/OOJSStation.cpp:852-857,977-978`
- ❌ **low** — (still open) `addShipToShipyard(def)` with a JS array (any object that converts to a non-dictionary): upstream sent `-objectForKey:` to the converted NSArray and the script saw "Native exception: <unrecognized selector reason>"; the port reports the fixed text "Unidentified native exception". Commit 10504da05 raised `OOInvalidArgumentException` for the analogous Mission marker case, not here — upstream `Core/Scripting/OOJSStation.m:929-935` ↔ port `Core/Scripting/OOJSStation.cpp:1194-1200`
- ✅ subtle — `addShipToShipyard`: the unreachable "Invalid shipdata_key provided." warning is dropped (`-dictionaryWithDictionary:nil` was never nil); a missing `roles` string passes the player-role test as `[nil rangeOfString:]` (location 0) did; a missing `personality` value raises the GNUstep nil-value text through `ValueForKey`; `Ranrot()` is consumed before any price failure; the shipyard warning still names `removeShipFromShipyard` — upstream `Core/Scripting/OOJSStation.m:916-1043` ↔ port `Core/Scripting/OOJSStation.cpp:1166-1377`
- ✅ subtle — a stale or non-station `this` stops the script silently in the getter/setter (upstream's `![nil isKindOfClass:]` path returned NO; the `entity == nil → undefined` branch is unreachable in both); methods treat it as a no-op. `abortDockingForShip(null)`/`canDockShip(null)` now fail silently where upstream passed a NULL object to the getter (assert/crash) — port `Core/Scripting/OOJSStation.cpp:201-261,269-278,528-531`
- ✅ subtle — `market` converts a `PList` dict (sorted key order, a converter property); `roll` and `increase/decreaseAlertLevel` call `ShipEntity::` members qualified, which upstream's StationEntity does not override — port `Core/Scripting/OOJSStation.cpp:313-319,381-385,628-655`

## OOJSSun

<a id="oojssun"></a>
Upstream `src/Core/Scripting/OOJSSun.m` ↔ `Core/Scripting/OOJSSun.cpp` (179 / 183 lines)

**Status:** done — 11 rows: 11 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sSunClass` JSClass (38) | `sSunClass` `Core/Scripting/OOJSSun.cpp:38` | ✅ |
| `sSunProperties[]` (61) | `sSunProperties[]` `Core/Scripting/OOJSSun.cpp:56` (4 entries RO: hasGoneNova, isGoingNova, name, radius) | ✅ |
| `sSunMethods[]` (70) | `sSunMethods[]` `Core/Scripting/OOJSSun.cpp:64` (cancelNova 0, goNova 0) | ✅ |
| `JSSunGetSunEntity` DEFINE_JS_OBJECT_GETTER (77) | `JSSunGetSunEntity` `Core/Scripting/OOJSSun.cpp:74` | ✅ |
| `InitOOJSSun` (79) | `InitOOJSSun` `Core/Scripting/OOJSSun.cpp:84` (`OOJSEntityObjectConverter`, bead oo-9ht.39.3) | ✅ |
| `-[OOSunEntity(OOJavaScriptExtensions) isVisibleToScripts]` (88) | `OOJSSunIsVisibleToScripts` `Core/Scripting/OOJSSun.cpp:103` | ✅ |
| `-[OOSunEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (93) | `OOSunEntity::jsClassID` `Core/Entities/OOSunEntity.cpp:768` → `JSSunClassID` `Core/Scripting/OOJSSun.cpp:100` | ✅ |
| `-[OOSunEntity(OOJavaScriptExtensions) oo_jsClassName]` (99) | `OOJSSunJSClassName` `Core/Scripting/OOJSSun.cpp:105` | ✅ |
| `SunGetProperty` (106) | `SunGetProperty` `Core/Scripting/OOJSSun.cpp:107` | ✅ |
| `SunGoNova` (145) | `SunGoNova` `Core/Scripting/OOJSSun.cpp:148` | ✅ |
| `SunCancelNova` (164) | `SunCancelNova` `Core/Scripting/OOJSSun.cpp:168` | ✅ |

**Differences:**

- ✅ subtle — as upstream, the getter has no stale → undefined branch: a stale sun gives radius 0, null name and `false` for both nova flags; `isGoingNova` = `willGoNova && !goneNova` — upstream `Core/Scripting/OOJSSun.m:106-139` ↔ port `Core/Scripting/OOJSSun.cpp:107-138`
- ✅ subtle — `goNova([delay])` returns failure (with the conversion exception) when the number conversion throws, else `setGoingNova(true, delay)` with default 0; `cancelNova()` acts only when `willGoNova && !goneNova`; a stale sun is a no-op — port `Core/Scripting/OOJSSun.cpp:148-183`

## OOJSSystem

<a id="oojssystem"></a>
Upstream `src/Core/Scripting/OOJSSystem.m` ↔ `Core/Scripting/OOJSSystem.cpp` (1535 / 1920 lines)

**Status:** done — 41 rows: 38 ✅ 0 ⚠️ 3 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `sSystemClass` JSClass (93) | `sSystemClass` `Core/Scripting/OOJSSystem.cpp:136` | ✅ |
| `sSystemProperties[]` (141) | `sSystemProperties[]` `Core/Scripting/OOJSSystem.cpp:183` (29 entries, same names, order and RO/RW) | ✅ |
| `sSystemMethods[]` (175) | `sSystemMethods[]` `Core/Scripting/OOJSSystem.cpp:240` (25 entries, same names and min args) | ✅ |
| `sSystemStaticMethods[]` (207) | `sSystemStaticMethods[]` `Core/Scripting/OOJSSystem.cpp:275` (infoForSystem, systemIDForName, systemNameForID) | ✅ |
| `InitOOJSSystem` (214) | `InitOOJSSystem` `Core/Scripting/OOJSSystem.cpp:282` | ✅ |
| `SystemGetProperty` (222) | `SystemGetProperty` `Core/Scripting/OOJSSystem.cpp:297` | ❌ |
| `SystemSetProperty` (439) | `SystemSetProperty` `Core/Scripting/OOJSSystem.cpp:568` | ✅ |
| `SystemToString` (571) | `SystemToString` `Core/Scripting/OOJSSystem.cpp:733` | ✅ |
| `SystemAddPlanet` (585) | `SystemAddPlanet` `Core/Scripting/OOJSSystem.cpp:755` | ✅ |
| `SystemAddMoon` (610) | `SystemAddMoon` `Core/Scripting/OOJSSystem.cpp:781` | ✅ |
| `SystemSendAllShipsAway` (635) | `SystemSendAllShipsAway` `Core/Scripting/OOJSSystem.cpp:807` | ✅ |
| `SystemCountShipsWithPrimaryRole` (648) | `SystemCountShipsWithPrimaryRole` `Core/Scripting/OOJSSystem.cpp:820` | ✅ |
| `SystemCountShipsWithRole` (680) | `SystemCountShipsWithRole` `Core/Scripting/OOJSSystem.cpp:856` | ✅ |
| `SystemShipsWithPrimaryRole` (712) | `SystemShipsWithPrimaryRole` `Core/Scripting/OOJSSystem.cpp:892` | ✅ |
| `SystemShipsWithRole` (745) | `SystemShipsWithRole` `Core/Scripting/OOJSSystem.cpp:927` | ✅ |
| `SystemCountEntitiesWithScanClass` (778) | `SystemCountEntitiesWithScanClass` `Core/Scripting/OOJSSystem.cpp:961` | ✅ |
| `SystemEntitiesWithScanClass` (810) | `SystemEntitiesWithScanClass` `Core/Scripting/OOJSSystem.cpp:997` | ✅ |
| `SystemFilteredEntities` (843) | `SystemFilteredEntities` `Core/Scripting/OOJSSystem.cpp:1033` | ✅ |
| `SystemLocationFromCode` (881) | `SystemLocationFromCode` `Core/Scripting/OOJSSystem.cpp:1099` | ✅ |
| `SystemAddShips` (908) | `SystemAddShips` `Core/Scripting/OOJSSystem.cpp:1131` | ✅ |
| `SystemAddGroup` (914) | `SystemAddGroup` `Core/Scripting/OOJSSystem.cpp:1137` | ✅ |
| `SystemAddShipsToRoute` (920) | `SystemAddShipsToRoute` `Core/Scripting/OOJSSystem.cpp:1143` | ✅ |
| `SystemAddGroupToRoute` (926) | `SystemAddGroupToRoute` `Core/Scripting/OOJSSystem.cpp:1149` | ✅ |
| `SystemLegacyAddShips` (932) | `SystemLegacyAddShips` `Core/Scripting/OOJSSystem.cpp:1159` | ✅ |
| `SystemLegacyAddSystemShips` (958) | `SystemLegacyAddSystemShips` `Core/Scripting/OOJSSystem.cpp:1188` | ✅ |
| `SystemLegacyAddShipsAt` (985) | `SystemLegacyAddShipsAt` `Core/Scripting/OOJSSystem.cpp:1221` | ✅ |
| `SystemLegacyAddShipsAtPrecisely` (1016) | `SystemLegacyAddShipsAtPrecisely` `Core/Scripting/OOJSSystem.cpp:1260` | ✅ |
| `SystemLegacyAddShipsWithinRadius` (1047) | `SystemLegacyAddShipsWithinRadius` `Core/Scripting/OOJSSystem.cpp:1299` | ✅ |
| `SystemLegacySpawnShip` (1081) | `SystemLegacySpawnShip` `Core/Scripting/OOJSSystem.cpp:1340` | ✅ |
| `SystemStaticSystemNameForID` (1108) | `SystemStaticSystemNameForID` `Core/Scripting/OOJSSystem.cpp:1366` | ✅ |
| `SystemStaticSystemIDForName` (1129) | `SystemStaticSystemIDForName` `Core/Scripting/OOJSSystem.cpp:1390` | ✅ |
| `SystemStaticInfoForSystem` (1155) | `SystemStaticInfoForSystem` `Core/Scripting/OOJSSystem.cpp:1417` | ✅ |
| `SystemAddVisualEffect` (1182) | `SystemAddVisualEffect` `Core/Scripting/OOJSSystem.cpp:1452` | ✅ |
| `SystemSetPopulator` (1216) | `SystemSetPopulator` + `GetParam` `Core/Scripting/OOJSSystem.cpp:1501,1491` | ❌ |
| `SystemSetWaypoint` (1273) | `SystemSetWaypoint` `Core/Scripting/OOJSSystem.cpp:1594` | ❌ |
| `SystemAddShipsOrGroup` (1324) | `SystemAddShipsOrGroup` `Core/Scripting/OOJSSystem.cpp:1663` | ✅ |
| `SystemAddShipsOrGroupToRoute` (1383) | `SystemAddShipsOrGroupToRoute` `Core/Scripting/OOJSSystem.cpp:1740` | ✅ |
| `GetRelativeToAndRange` (1445) | `GetRelativeToAndRange` `Core/Scripting/OOJSSystem.cpp:1821` | ✅ |
| `FindJSVisibleEntities` (1477) | `FindJSVisibleEntities` `Core/Scripting/OOJSSystem.cpp:1860` | ✅ |
| `FindShips` (1502) | `FindShips` `Core/Scripting/OOJSSystem.cpp:1888` | ✅ |
| `CompareEntitiesByDistance` (1515) | `CompareEntitiesByDistance` `Core/Scripting/OOJSSystem.cpp:1900` | ✅ |

**Differences:**

- ❌ **low** — (still open) `system.waypoints` and `system.populatorSettings` are built from a `PList::Dict`, so their keys enumerate in sorted order. Upstream's NSDictionary gave hash order (`for…in` order differs, but values match) — upstream `Core/Scripting/OOJSSystem.m:271-272,324-325` ↔ port `Core/Scripting/OOJSSystem.cpp:356-370,442-445`
- ❌ **low** — (still open) `setWaypoint(key, pos, ori, def)` and `setPopulator(key, def)` with a JS array (or another object that converts to a non-dictionary) as the definition: upstream sent `-setObject:forKey:` to the NSArray copy, and the script saw a native exception. The port's `getIf<Dict>` skips the inserts and silently passes the array on to `defineWaypoint`/`setPopulatorSetting` — upstream `Core/Scripting/OOJSSystem.m:1251-1252,1307-1311` ↔ port `Core/Scripting/OOJSSystem.cpp:1557-1562,1639-1652`
- ✅ note — `addShips`/`addGroup` return null when no ships were added, as `-addShipsAt:` returned nil for an empty array (`Universe.m:2720-2721`). Distance sorting uses a stable sort. Route-code validation and the upstream copy-paste error names (`countShipsWithRole` reported by `shipsWithPrimaryRole`, `countEntitiesWithScanClass` by `entitiesWithScanClass`, `legacy_addShipWithinRadius`) are kept — port `Core/Scripting/OOJSSystem.cpp:892-1029,1321,1663-1900`
- ✅ note — `filteredEntities(this, …)` with null/undefined `this` passes the global object, as SpiderMonkey's null `this` did. Primitives are boxed. A predicate exception stops the script after it is reported. The time limiter is resumed on a C++ throw — port `Core/Scripting/OOJSSystem.cpp:1033-1096`
- ✅ note — `systemIDForName` reinterprets the unsigned not-found result as -1, as `INT_TO_JSVAL` did. The legacy methods still read argv before checking argc; this is safe because QuickJS pads argv up to the declared arity — port `Core/Scripting/OOJSSystem.cpp:1153-1156,1409-1411`

## OOJSSystemInfo

<a id="oojssysteminfo"></a>
Upstream `src/Core/Scripting/OOJSSystemInfo.m` ↔ `Core/Scripting/OOJSSystemInfo.cpp` (738 / 1326 lines)

**Status:** done — 32 rows: 25 ✅ 3 ⚠️ 2 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSystemInfo init]` (128) | none (no default constructor; only `initWithGalaxy`) | ➖ |
| `-[OOSystemInfo initWithGalaxy:system:]` (134) | `OOSystemInfo::initWithGalaxy` Core/Scripting/OOJSSystemInfo.cpp:272 (+ constructor :267) | ✅ |
| `-[OOSystemInfo dealloc]` (149) | implicit destructor | ➖ |
| `-[OOSystemInfo descriptionComponents]` (156) | `OOSystemInfo::descriptionComponents` Core/Scripting/OOJSSystemInfo.cpp:295 | ✅ |
| `-[OOSystemInfo shortDescriptionComponents]` (161) | `OOSystemInfo::shortDescriptionComponents` Core/Scripting/OOJSSystemInfo.cpp:299 | ✅ |
| `-[OOSystemInfo oo_jsClassName]` (166) | `OOSystemInfo::oo_jsClassName` Core/Scripting/OOJSSystemInfo.cpp:303 | ✅ |
| `-[OOSystemInfo isEqual:]` (171) | `OOSystemInfo::isEqual` Core/Scripting/OOJSSystemInfo.cpp:307 | ✅ |
| `-[OOSystemInfo hash]` (176) | `OOSystemInfo::hash` Core/Scripting/OOJSSystemInfo.cpp:312 | ✅ |
| `-[OOSystemInfo valueForKey:]` (184) | `OOSystemInfo::valueForKey` Core/Scripting/OOJSSystemInfo.cpp:319 | ✅ |
| `-[OOSystemInfo setValue:forKey:]` (192) | `OOSystemInfo::setValue` Core/Scripting/OOJSSystemInfo.cpp:333 | ✅ |
| `-[OOSystemInfo allKeys]` (199) | `OOSystemInfo::allKeys` Core/Scripting/OOJSSystemInfo.cpp:343 | ⚠️ |
| `-[OOSystemInfo galaxy]` (207) | `OOSystemInfo::galaxy` Core/Scripting/OOJSSystemInfo.cpp:363 | ✅ |
| `-[OOSystemInfo system]` (212) | `OOSystemInfo::system` Core/Scripting/OOJSSystemInfo.cpp:365 | ✅ |
| `-[OOSystemInfo coordinates]` (223) | `OOSystemInfo::coordinates` Core/Scripting/OOJSSystemInfo.cpp:374 | ✅ |
| `-[OOSystemInfo oo_jsValueInContext:]` (231) | `OOSystemInfo::jsValueInContext` Core/Scripting/OOJSSystemInfo.cpp:386 | ✅ |
| `InitOOJSSystemInfo` (249) | `InitOOJSSystemInfo` Core/Scripting/OOJSSystemInfo.cpp:437 | ✅ |
| `GetJSSystemInfoForSystem` (255) | `GetJSSystemInfoForSystem` Core/Scripting/OOJSSystemInfo.cpp:457 | ⚠️ |
| `SystemInfoFinalize` (287) | `SystemInfoFinalize` Core/Scripting/OOJSSystemInfo.cpp:505 | ✅ |
| `SystemInfoEnumerate` (301) | `SystemInfoExoticGetOwnPropertyNames` Core/Scripting/OOJSSystemInfo.cpp:712 (+ `SystemInfoExoticHasProperty` :773) | ⚠️ |
| `SystemInfoDeleteProperty` (350) | `SystemInfoExoticDeleteProperty` Core/Scripting/OOJSSystemInfo.cpp:758 | ❌ |
| `SystemInfoGetProperty` (360) | `SystemInfoGetProperty` Core/Scripting/OOJSSystemInfo.cpp:889 (fixed) + `SystemInfoExoticGetProperty` :802 / `SystemInfoGetSystemDataValue` :551 (string keys) | ✅ |
| `SystemInfoSetProperty` (435) | `SystemInfoExoticSetProperty` Core/Scripting/OOJSSystemInfo.cpp:856 (+ `SystemInfoSetOnPrototypeChain` :592) | ✅ |
| `SystemInfoDistanceToSystem` (456) | `SystemInfoDistanceToSystem` Core/Scripting/OOJSSystemInfo.cpp:954 | ✅ |
| `SystemInfoRouteToSystem` (486) | `SystemInfoRouteToSystem` Core/Scripting/OOJSSystemInfo.cpp:990 | ✅ |
| `SystemInfoSamplePrice` (523) | `SystemInfoSamplePrice` Core/Scripting/OOJSSystemInfo.cpp:1033 | ✅ |
| `SystemInfoSetPropertyMethod` (550) | `SystemInfoSetPropertyMethod` Core/Scripting/OOJSSystemInfo.cpp:1082 | ✅ |
| `SystemInfoStaticFilteredSystems` (597) | `SystemInfoStaticFilteredSystems` Core/Scripting/OOJSSystemInfo.cpp:1138 | ✅ |
| `SystemInfoStaticSetInterstellarProperty` (662) | `SystemInfoStaticSetInterstellarProperty` Core/Scripting/OOJSSystemInfo.cpp:1219 | ✅ |
| `-[OOSystemInfo description]` (inherited NSObject) | `OOSystemInfo::description` Core/Scripting/OOJSSystemInfo.cpp:409 | ❌ |
| `sSystemInfoProperties` (77) | `sSystemInfoProperties` Core/Scripting/OOJSSystemInfo.cpp:178 (hidden: the enumerate hook never listed them) | ✅ |
| `sSystemInfoMethods` (86) | `sSystemInfoMethods` Core/Scripting/OOJSSystemInfo.cpp:195 (toString → `SystemInfoToString` :499) | ✅ |
| `sSystemInfoStaticMethods` (96) | `sSystemInfoStaticMethods` Core/Scripting/OOJSSystemInfo.cpp:204 | ✅ |

**Differences:**

- ❌ **low** — previous med finding partly fixed since 2026-10-27: the class now has a real QuickJS `delete_property` exotic hook, which QuickJS calls for any name without an own slot, so `delete info.foo` clears the OXP_DYNAMIC override again (as SpiderMonkey's delProperty → SetProperty(undefined) → `setValue:nil`). Still open: `delete info.coordinates` (or galaxyID/systemID/internalCoordinates) answers true and clears a same-named system-data key, where SpiderMonkey answered false for a shared-permanent prototype property without calling the hook — upstream `Core/Scripting/OOJSSystemInfo.m:350-357` ↔ port `Core/Scripting/OOJSSystemInfo.cpp:758-771`
- ❌ **low** — `OOSystemInfo::description()` gives `<OOSystemInfo>{galaxy g, system s}` without the `0x…` address the inherited NSObject `-description` printed. Only in logs that print a PList holding a SystemInfo; JS `toString()` (`jsDescription`) matches (still open) — upstream `Core/Scripting/OOJSSystemInfo.m:156` ↔ port `Core/Scripting/OOJSSystemInfo.cpp:409-412`
- ⚠️ **low** — `for…in` / `Object.keys` list keys in byte order (`PList::Dict`) instead of `-allKeys` hash order, for both the interstellar and the `systemDataKeysForGalaxy` path; port comment "in key order (-allKeys gave hash order)" (still open) — upstream `Core/Scripting/OOJSSystemInfo.m:199-205` ↔ port `Core/Scripting/OOJSSystemInfo.cpp:343-361`
- ⚠️ **low** — `"key" in info` is true for a system-data key, where SpiderMonkey answered false (no resolve hook); needed because QuickJS-ng's for…in drops keys `has_property` denies. Documented in the header comment (new: the old façade's behaviour was not recorded) — port `Core/Scripting/OOJSSystemInfo.cpp:69-74,773-800`
- ⚠️ **low** — the single-entry cache now holds a strong reference (released on the next system or engine reset) instead of SpiderMonkey's weak pointer cleared in finalize, so repeated `system.info` reads always give the same object; port comment :108-115 — port `Core/Scripting/OOJSSystemInfo.cpp:457-497`
- ✅ — string-key reads go through `getProperty(key, system, galaxy)` (or `valueForKey` for system -1), numbers and number literals become JS numbers, other values via `OOJSValueFromPList`. Setting stores `ToString(value)` (null for null/undefined) in OXP_DYNAMIC; a key assigned null reads back null (emulating the SpiderMonkey own slot). Writable inherited names (e.g. `toString`) are stored too, read-only accessors ignored, as before — port `Core/Scripting/OOJSSystemInfo.cpp:551-584,856-885`
- ✅ — error, warning and bad-argument texts and counts match verbatim (including `MIN(argc, 3)` in setInterstellarProperty, the unclamped argc in filteredSystems, "Cannot read systemInfo values for %s."). `filteredSystems` passes `this` unboxed (comment :1141-1145) and propagates a predicate exception; `samplePrice` keeps only a string `commodity_script` (`ManifestString`) — port `Core/Scripting/OOJSSystemInfo.cpp:889-1326`

## OOJSTimer

<a id="oojstimer"></a>
Upstream `src/Core/Scripting/OOJSTimer.m` ↔ `Core/Scripting/OOJSTimer.cpp` (419 / 535 lines)

**Status:** done — 16 rows: 14 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJSTimer initWithDelay:interval:context:function:this:]` (48) | `OOJSTimer::initWithDelay` Core/Scripting/OOJSTimer.cpp:87 (+ `timerWithDelay` :75) | ✅ |
| `-[OOJSTimer deleteJSPointers]` (85) | `OOJSTimer::deleteJSPointers` / `releaseJSValues` Core/Scripting/OOJSTimer.cpp:140, :148 | ✅ |
| `-[OOJSTimer dealloc]` (104) | `OOJSTimer::~OOJSTimer` Core/Scripting/OOJSTimer.cpp:169 | ✅ |
| `-[OOJSTimer descriptionComponents]` (113) | `OOJSTimer::descriptionComponents` Core/Scripting/OOJSTimer.cpp:179 (name cached at :105) | ❌ |
| `-[OOJSTimer oo_jsClassName]` (133) | `OOJSTimer::oo_jsClassName` Core/Scripting/OOJSTimer.cpp:189 | ✅ |
| `-[OOJSTimer timerFired]` (138) | `OOJSTimer::timerFired` Core/Scripting/OOJSTimer.cpp:193 | ✅ |
| `-[OOJSTimer oo_jsValueInContext:]` (171) | `OOJSTimer::jsValueInContext` Core/Scripting/OOJSTimer.cpp:236 | ✅ |
| `InitOOJSTimer` (227) | `InitOOJSTimer` Core/Scripting/OOJSTimer.cpp:343 | ✅ |
| `TimerGetProperty` (233) | `TimerGetProperty` Core/Scripting/OOJSTimer.cpp:351 | ✅ |
| `TimerSetProperty` (264) | `TimerSetProperty` Core/Scripting/OOJSTimer.cpp:379 | ✅ |
| `TimerFinalize` (305) | `OOJSTimer::clearJSSelf` Core/Scripting/OOJSTimer.cpp:247 via `OOJSCxxObjectWrapperFinalize` | ⚠️ |
| `TimerConstruct` (324) | `TimerConstruct` Core/Scripting/OOJSTimer.cpp:427 | ✅ |
| `TimerStart` (391) | `TimerStart` Core/Scripting/OOJSTimer.cpp:504 | ✅ |
| `TimerStop` (406) | `TimerStop` Core/Scripting/OOJSTimer.cpp:518 | ✅ |
| `sTimerProperties` (209) | `sTimerProperties` Core/Scripting/OOJSTimer.cpp:309 | ✅ |
| `sTimerMethods` (217) | `sTimerMethods` Core/Scripting/OOJSTimer.cpp:319 (toString → `TimerToString` :533) | ✅ |

**Differences:**

- ❌ **low** — the function name in the description is read from QuickJS `fn.name` at construction. ES2015 infers names for `var f = function(){}` and object-literal methods, where SpiderMonkey 1.8.5 `JS_GetFunctionId` gave NULL → "anonymous". Shows in `Timer.toString()` and the "Ignoring attempt to change next fire time…" warning (still open) — upstream `Core/Scripting/OOJSTimer.m:123-128` ↔ port `Core/Scripting/OOJSTimer.cpp:105-111,179-187`
- ⚠️ **low** — `script.javaScript.unrootedTimer` warning: the previous finding (no `, function: <name>`) is fixed since 2026-10-27, because the name is now cached at init and `description()` includes it. New: the warning is suppressed when a one-shot timer is collected from inside its own callback (`willNotFireAgain`, port comment :270-275 on QuickJS refcounting). It also clears `_jsSelf` (new) — upstream `Core/Scripting/OOJSTimer.m:312-318` ↔ port `Core/Scripting/OOJSTimer.cpp:247-260,275`
- ✅ **low** — subtle: `jsValueInContext` answers null after the JS object is finalized, where upstream returned the dangling pointer (UB) — port `Core/Scripting/OOJSTimer.cpp:236-243`
- ✅ **low** — subtle: on `Timer.prototype` the getters read 0/0/false and the setters warn with "(null)", matching nil messaging; `start()` → false, `stop()` → undefined; `toString()` is `[Timer <components>]` as `oo_jsDescriptionWithClassName` — port `Core/Scripting/OOJSTimer.cpp:351-423,503-535`

## OOJSVector

<a id="oojsvector"></a>
Upstream `src/Core/Scripting/OOJSVector.m` ↔ `Core/Scripting/OOJSVector.cpp` (1225 / 1032 lines)

**Status:** done — 47 rows: 40 ✅ 3 ⚠️ 2 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitOOJSVector` (231) | `InitOOJSVector` Core/Scripting/OOJSVector.cpp:158 | ✅ |
| `JSVectorWithVector` (236) | `JSVectorWithVector` Core/Scripting/OOJSVector.cpp:169 | ✅ |
| `VectorToJSValue` (264) | `VectorToJSValue` Core/Scripting/OOJSVector.cpp:173 | ✅ |
| `JSVectorWithHPVector` (282) | `JSVectorWithHPVector` Core/Scripting/OOJSVector.cpp:177 | ✅ |
| `HPVectorToJSValue` (310) | `HPVectorToJSValue` Core/Scripting/OOJSVector.cpp:193 | ✅ |
| `NSPointToVectorJSValue` (328) | `NSPointToVectorJSValue` Core/Scripting/OOJSVector.cpp:208 | ✅ |
| `JSValueToHPVector` (333) | `JSValueToHPVector` Core/Scripting/OOJSVector.cpp:213 | ✅ |
| `JSValueToVector` (341) | `JSValueToVector` Core/Scripting/OOJSVector.cpp:220 | ✅ |
| `-[PlayerEntity(JSVectorStatistics) reportJSVectorStatistics]` (369) | none (OO_DEBUG-only conversion statistics not ported) | ➖ |
| `-[PlayerEntity(JSVectorStatistics) clearJSVectorStatistics]` (395) | none (OO_DEBUG-only) | ➖ |
| `JSObjectGetVector` (415) | `JSObjectGetVector` Core/Scripting/OOJSVector.cpp:240 | ✅ |
| `GetThisVector` (483) | `GetThisVector` Core/Scripting/OOJSVector.cpp:302 | ✅ |
| `JSVectorSetVector` (493) | `JSVectorSetVector` Core/Scripting/OOJSVector.cpp:311 | ✅ |
| `JSVectorSetHPVector` (498) | `JSVectorSetHPVector` Core/Scripting/OOJSVector.cpp:316 | ✅ |
| `VectorFromArgumentListNoErrorInternal` (525) | `VectorFromArgumentListNoErrorInternal` Core/Scripting/OOJSVector.cpp:341 | ✅ |
| `VectorFromArgumentList` (573) | `VectorFromArgumentList` Core/Scripting/OOJSVector.cpp:388 | ✅ |
| `VectorFromArgumentListNoError` (585) | `VectorFromArgumentListNoError` Core/Scripting/OOJSVector.cpp:403 | ✅ |
| `VectorGetProperty` (592) | `VectorGetProperty` Core/Scripting/OOJSVector.cpp:412 | ❌ |
| `VectorSetProperty` (628) | `VectorSetProperty` Core/Scripting/OOJSVector.cpp:447 | ❌ |
| `VectorFinalize` (668) | `VectorFinalize` Core/Scripting/OOJSVector.cpp:489 | ✅ |
| `VectorConstruct` (683) | `VectorConstruct` Core/Scripting/OOJSVector.cpp:497 | ✅ |
| `VectorToString` (725) | `VectorToString` Core/Scripting/OOJSVector.cpp:521 | ✅ |
| `VectorToSource` (740) | `VectorToSource` Core/Scripting/OOJSVector.cpp:535 | ✅ |
| `VectorAdd` (756) | `VectorAdd` Core/Scripting/OOJSVector.cpp:550 | ✅ |
| `VectorSubtract` (775) | `VectorSubtract` Core/Scripting/OOJSVector.cpp:569 | ✅ |
| `VectorDistanceTo` (794) | `VectorDistanceTo` Core/Scripting/OOJSVector.cpp:588 | ✅ |
| `VectorSquaredDistanceTo` (814) | `VectorSquaredDistanceTo` Core/Scripting/OOJSVector.cpp:608 | ✅ |
| `VectorMultiply` (834) | `VectorMultiply` Core/Scripting/OOJSVector.cpp:630 | ✅ |
| `VectorDot` (854) | `VectorDot` Core/Scripting/OOJSVector.cpp:650 | ✅ |
| `VectorAngleTo` (874) | `VectorAngleTo` Core/Scripting/OOJSVector.cpp:670 | ✅ |
| `VectorCross` (901) | `VectorCross` Core/Scripting/OOJSVector.cpp:695 | ✅ |
| `VectorTripleProduct` (920) | `VectorTripleProduct` Core/Scripting/OOJSVector.cpp:714 | ✅ |
| `VectorDirection` (946) | `VectorDirection` Core/Scripting/OOJSVector.cpp:741 | ✅ |
| `VectorMagnitude` (963) | `VectorMagnitude` Core/Scripting/OOJSVector.cpp:757 | ✅ |
| `VectorSquaredMagnitude` (981) | `VectorSquaredMagnitude` Core/Scripting/OOJSVector.cpp:774 | ✅ |
| `VectorRotationTo` (999) | `VectorRotationTo` Core/Scripting/OOJSVector.cpp:792 | ✅ |
| `VectorRotateBy` (1036) | `VectorRotateBy` Core/Scripting/OOJSVector.cpp:832 | ✅ |
| `VectorToArray` (1056) | `VectorToArray` Core/Scripting/OOJSVector.cpp:852 | ✅ |
| `VectorToCoordinateSystem` (1085) | `VectorToCoordinateSystem` Core/Scripting/OOJSVector.cpp:970 | ✅ |
| `VectorFromCoordinateSystem` (1111) | `VectorFromCoordinateSystem` Core/Scripting/OOJSVector.cpp:1001 | ✅ |
| `VectorStaticInterpolate` (1140) | `VectorStaticInterpolate` Core/Scripting/OOJSVector.cpp:882 | ✅ |
| `VectorStaticRandom` (1183) | `VectorStaticRandom` Core/Scripting/OOJSVector.cpp:924 | ⚠️ |
| `VectorStaticRandomDirection` (1198) | `VectorStaticRandomDirection` Core/Scripting/OOJSVector.cpp:939 | ⚠️ |
| `VectorStaticRandomDirectionAndLength` (1213) | `VectorStaticRandomDirectionAndLength` Core/Scripting/OOJSVector.cpp:954 | ⚠️ |
| `sVectorProperties` (96) | `sVectorProperties` Core/Scripting/OOJSVector.cpp:107 | ✅ |
| `sVectorMethods` (104) | `sVectorMethods` Core/Scripting/OOJSVector.cpp:120 (same 19 names and arities; order differs only for `fromCoordinateSystem`) | ✅ |
| `sVectorStaticMethods` (204) | `sVectorStaticMethods` Core/Scripting/OOJSVector.cpp:147 | ✅ |

**Differences:**

- ❌ **low** (new) — `x`/`y`/`z` read or written on an object that is not a vector (e.g. `Object.create(Vector3D.prototype).x`) now gives `undefined` / does nothing. Upstream's getter and setter returned NO with no error, which in SpiderMonkey stops the script silently — upstream `Core/Scripting/OOJSVector.m:602-603,638-639` ↔ port `Core/Scripting/OOJSVector.cpp:419-420,454-455`
- ⚠️ **low** — `Vector3D.random()`, `randomDirection()`, `randomDirectionAndLength()`: the bindings are the same, but the helpers draw `randf()` in a fixed left-to-right order (ADR-0063 item 5), where upstream's single-expression argument order was unspecified (still open) — upstream `Core/OOHPVector.m:68,81,90` ↔ port `Core/Scripting/OOJSVector.cpp:924-966`
- ➖ **low** — the `OO_DEBUG` vector conversion statistics (`PS.callObjC("reportJSVectorStatistics")`) are gone; debug builds only — upstream `Core/Scripting/OOJSVector.m:351-413`
- ✅ subtle — constructor forms and messages match (no args → zero; Vector/entity/3-element array/prototype; or three non-NaN numbers; "Could not construct vector from parameters"), `null` fails as an object. `toString`/`toSource` use `%g`-equivalent `{:g}`, `fromCoordinateSystem` `{:f}`; getters return doubles via `JS_NewFloat64` (indistinguishable from SpiderMonkey's int canonicalisation in JS) — port `Core/Scripting/OOJSVector.cpp:240-300,497-547,1001-1031`
- ✅ subtle — array elements are read with `JS_GetPropertyUint32` (proto lookup, getters), upstream `JS_LookupElement`; a hole gives undefined → NaN in both. Error paths `return JS_EXCEPTION` after a reported error, the same as upstream's `return NO` — port `Core/Scripting/OOJSVector.cpp:231-238`

## OOJSVisualEffect

<a id="oojsvisualeffect"></a>
Upstream `src/Core/Scripting/OOJSVisualEffect.m` ↔ `Core/Scripting/OOJSVisualEffect.cpp` (682 / 832 lines)

**Status:** done — 18 rows: 17 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitOOJSVisualEffect` (132) | `InitOOJSVisualEffect` Core/Scripting/OOJSVisualEffect.cpp:196 | ✅ |
| `JSVisualEffectGetVisualEffectEntity` (139) | `JSVisualEffectGetVisualEffectEntity` Core/Scripting/OOJSVisualEffect.cpp:214 | ✅ |
| `-[OOVisualEffectEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (165) | `OOVisualEffectEntity::jsClassID` Core/Entities/OOVisualEffectEntity.cpp:899 → `JSVisualEffectClassID` Core/Scripting/OOJSVisualEffect.cpp:212 | ✅ |
| `-[OOVisualEffectEntity(OOJavaScriptExtensions) oo_jsClassName]` (171) | `OOJSVisualEffectJSClassName` Core/Scripting/OOJSVisualEffect.cpp:238 | ✅ |
| `-[OOVisualEffectEntity(OOJavaScriptExtensions) isVisibleToScripts]` (176) | `OOJSVisualEffectIsVisibleToScripts` Core/Scripting/OOJSVisualEffect.cpp:242 | ✅ |
| `-[OOVisualEffectEntity(OOJavaScriptExtensions) subEntitiesForScript]` (181) | `OOJSVisualEffectSubEntitiesForScript` Core/Scripting/OOJSVisualEffect.cpp:244 | ✅ |
| `VisualEffectGetProperty` (188) | `VisualEffectGetProperty` Core/Scripting/OOJSVisualEffect.cpp:256 | ✅ |
| `VisualEffectSetProperty` (297) | `VisualEffectSetProperty` Core/Scripting/OOJSVisualEffect.cpp:390 | ✅ |
| `VisualEffectRemove` (467) | `VisualEffectRemove` Core/Scripting/OOJSVisualEffect.cpp:585 | ✅ |
| `VisualEffectGetMaterials` (487) | `VisualEffectGetMaterials` Core/Scripting/OOJSVisualEffect.cpp:604 | ✅ |
| `VisualEffectGetShaders` (505) | `VisualEffectGetShaders` Core/Scripting/OOJSVisualEffect.cpp:621 | ✅ |
| `VisualEffectSetMaterials` (523) | `VisualEffectSetMaterials` Core/Scripting/OOJSVisualEffect.cpp:639 | ✅ |
| `VisualEffectSetShaders` (542) | `VisualEffectSetShaders` Core/Scripting/OOJSVisualEffect.cpp:659 | ✅ |
| `VisualEffectSetMaterialsInternal` (569) | `VisualEffectSetMaterialsInternal` Core/Scripting/OOJSVisualEffect.cpp:696 | ✅ |
| `VisualEffectScale` (632) | `VisualEffectScale` Core/Scripting/OOJSVisualEffect.cpp:780 | ❌ |
| `VisualEffectRestoreSubEntities` (662) | `VisualEffectRestoreSubEntities` Core/Scripting/OOJSVisualEffect.cpp:811 | ✅ |
| `sVisualEffectProperties` (92) | `sVisualEffectProperties` Core/Scripting/OOJSVisualEffect.cpp:125 (RO/RW flags match) | ✅ |
| `sVisualEffectMethods` (119) | `sVisualEffectMethods` Core/Scripting/OOJSVisualEffect.cpp:185 (same names and arities) | ✅ |

**Differences:**

- ❌ **low** (new; the previous audit called it equivalent) — `scale(n)` ends with `return YES` and no rval in upstream, so SpiderMonkey 1.8.5 returned `vp[0]`, the callee: `effect.scale(2)` gave the `scale` function (truthy). The port returns `undefined` (falsy). Only scripts that test or chain the result see it — upstream `Core/Scripting/OOJSVisualEffect.m:657` ↔ port `Core/Scripting/OOJSVisualEffect.cpp:806`
- ✅ subtle — getter types match (floats via `JS_NewNumber`, `shaderInt*` int32, colours as `normalizedArray` floats or null, `subEntities` null before the first subentity, `scriptInfo` an empty dict when unset (`OOVisualEffectEntity.cpp:744-746`)); setter validation (`> 0` scales, null colour allowed, `OOJSValueToInt32` for ints) is the same — port `Core/Scripting/OOJSVisualEffect.cpp:256-557`
- ✅ subtle — warning and bad-argument texts and their order match: `setShaders` gets `this` before checking argc, `setMaterials` after. `setShaders` now passes a two-element copy of argv instead of writing `OOJS_ARGV[1]`, same effect. `restoreSubEntities()` keeps the unsigned `count - subCount > 0` test (true when the count changed either way) — port `Core/Scripting/OOJSVisualEffect.cpp:639-692,811-832`
- ✅ subtle — the mesh is built from `model` only when it is a string or number (else `""` where upstream passed nil) and `ship-prefix-macros` only when a dictionary; `remove()` uses `oo::LiveOwner` for `[thisEnt owner]` — port `Core/Scripting/OOJSVisualEffect.cpp:585-601,748-773`

## OOJSWaypoint

<a id="oojswaypoint"></a>
Upstream `src/Core/Scripting/OOJSWaypoint.m` ↔ `Core/Scripting/OOJSWaypoint.cpp` (250 / 258 lines)

**Status:** done — 9 rows: 9 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitOOJSWaypoint` (77) | `InitOOJSWaypoint` Core/Scripting/OOJSWaypoint.cpp:83 | ✅ |
| `JSWaypointGetWaypointEntity` (84) | `JSWaypointGetWaypointEntity` Core/Scripting/OOJSWaypoint.cpp:100 | ✅ |
| `-[OOWaypointEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (110) | `OOWaypointEntity::jsClassID` Core/Entities/OOWaypointEntity.cpp:267 → `JSWaypointClassID` Core/Scripting/OOJSWaypoint.cpp:98 | ✅ |
| `-[OOWaypointEntity(OOJavaScriptExtensions) oo_jsClassName]` (116) | `OOJSWaypointJSClassName` Core/Scripting/OOJSWaypoint.cpp:127 (via `OOWaypointEntity::jsClassName` Core/Entities/OOWaypointEntity.cpp:268) | ✅ |
| `-[OOWaypointEntity(OOJavaScriptExtensions) isVisibleToScripts]` (121) | `OOJSWaypointIsVisibleToScripts` Core/Scripting/OOJSWaypoint.cpp:131 | ✅ |
| `WaypointGetProperty` (128) | `WaypointGetProperty` Core/Scripting/OOJSWaypoint.cpp:133 | ✅ |
| `WaypointSetProperty` (176) | `WaypointSetProperty` Core/Scripting/OOJSWaypoint.cpp:179 | ✅ |
| `sWaypointProperties` (62) | `sWaypointProperties` Core/Scripting/OOJSWaypoint.cpp:69 | ✅ |
| `sWaypointMethods` (71) | none (empty table; "No Waypoint methods" Core/Scripting/OOJSWaypoint.cpp:81) | ✅ |

**Differences:**

- ✅ subtle — the `entity == nil` branches of getter/setter are dropped; unreachable because `JSWaypointGetWaypointEntity` already fails for nil (`[nil isKindOfClass:]` NO ↔ `dynamic_cast` of null) — upstream `Core/Scripting/OOJSWaypoint.m:141-144,190-191` ↔ port `Core/Scripting/OOJSWaypoint.cpp:116-117,141-142`
- ✅ subtle — orientation gives `kZeroQuaternion` when unoriented; `beaconCode` clear/set logic, `size > 0`, nil `beaconLabel` → bad value are unchanged; the converter is now `OOJSEntityObjectConverter` (the entity's holder) instead of `OOJSBasicPrivateObjectConverter` — port `Core/Scripting/OOJSWaypoint.cpp:94,156-244`

## OOJSWorldScripts

<a id="oojsworldscripts"></a>
Upstream `src/Core/Scripting/OOJSWorldScripts.m` ↔ `Core/Scripting/OOJSWorldScripts.cpp` (110 / 167 lines)

**Status:** done — 4 rows: 2 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitOOJSWorldScripts` (48) | `InitOOJSWorldScripts` Core/Scripting/OOJSWorldScripts.cpp:58 | ✅ |
| `WorldScriptsGetProperty` (53) | `WorldScriptsGetOwnProperty` Core/Scripting/OOJSWorldScripts.cpp:84 (exotic `get_own_property`) | ❌ |
| `WorldScriptsEnumerate` (84) | `WorldScriptsGetOwnPropertyNames` Core/Scripting/OOJSWorldScripts.cpp:132 | ⚠️ |
| `sWorldScriptsClass` (32) | `sWorldScriptsClass` + `sWorldScriptsExoticMethods` Core/Scripting/OOJSWorldScripts.cpp:47-56 | ✅ |

**Differences:**

- ❌ **low** (new) — world scripts are now real own properties at all times, so `"name" in worldScripts` and `worldScripts.hasOwnProperty("name")` are true for a loaded script. Upstream had only a getProperty hook and `JS_ResolveStub`, so these were false until a `for…in` had run the enumerate hook, which defined the names. `worldScripts.name` reads are the same — upstream `Core/Scripting/OOJSWorldScripts.m:33-50,84-109` ↔ port `Core/Scripting/OOJSWorldScripts.cpp:84-129`
- ⚠️ **low** — `for (name in worldScripts)` lists scripts in load order (`PlayerEntity::worldScriptNames` walks the vector), where upstream used `[worldScripts allKeys]` hash order (still open; port comment in ResourceManager) — upstream `Core/Entities/PlayerEntity.m:11284` ↔ port `Core/Entities/PlayerEntity.cpp:13426-13431`
- ✅ **low** — the getter takes the last entry of a name; a JS script gives its Script object, another `OOScript` gives undefined (`OOScript::jsValueInContext`, as NSObject's `JSVAL_VOID`; upstream's comment said null), an unknown name is not an own property (undefined) — port `Core/Scripting/OOJSWorldScripts.cpp:93-120`

## OOJSWormhole

<a id="oojswormhole"></a>
Upstream `src/Core/Scripting/OOJSWormhole.m` ↔ `Core/Scripting/OOJSWormhole.cpp` (196 / 165 lines)

**Status:** done — 9 rows: 8 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitOOJSWormhole` (77) | `InitOOJSWormhole` Core/Scripting/OOJSWormhole.cpp:80 | ✅ |
| `JSWormholeGetWormholeEntity` (84) | `JSWormholeGetWormholeEntity` Core/Scripting/OOJSWormhole.cpp:97 | ✅ |
| `-[WormholeEntity(OOJavaScriptExtensions) getJSClass:andPrototype:]` (110) | `WormholeEntity::jsClassID` Core/Entities/WormholeEntity.cpp:908 → `JSWormholeClassID` Core/Scripting/OOJSWormhole.cpp:95 | ✅ |
| `-[WormholeEntity(OOJavaScriptExtensions) oo_jsClassName]` (116) | `OOJSWormholeJSClassName` Core/Scripting/OOJSWormhole.cpp:119 | ✅ |
| `-[WormholeEntity(OOJavaScriptExtensions) isVisibleToScripts]` (121) | `OOJSWormholeIsVisibleToScripts` Core/Scripting/OOJSWormhole.cpp:123 | ✅ |
| `WormholeGetProperty` (128) | `WormholeGetProperty` Core/Scripting/OOJSWormhole.cpp:125 | ✅ |
| `WormholeSetProperty` (169) | none (all properties read-only; comment Core/Scripting/OOJSWormhole.cpp:62-66) | ➖ |
| `sWormholeProperties` (64) | `sWormholeProperties` Core/Scripting/OOJSWormhole.cpp:67 (all `OOJS_PROPERTY_RO`) | ✅ |
| `sWormholeMethods` (72) | none (empty table; "No Wormhole methods" Core/Scripting/OOJSWormhole.cpp:78) | ✅ |

**Differences:**

- ➖ **low** — `WormholeSetProperty` is not ported. It only reported a bad selector, and every property is read-only, so SpiderMonkey never called it (port comment) — upstream `Core/Scripting/OOJSWormhole.m:169-191` ↔ port `Core/Scripting/OOJSWormhole.cpp:62-66`
- ✅ subtle — the four getters return numbers (`arrivalTime`, `getDestination`, `expiryTime`, `getOrigin`); the unreachable trailing nil value became `JS_NULL` — port `Core/Scripting/OOJSWormhole.cpp:125-165`

## OOJavaScriptEngine

<a id="oojavascriptengine"></a>
Upstream `src/Core/Scripting/OOJavaScriptEngine.m` ↔ `Core/Scripting/OOJavaScriptEngine.cpp` (2322 / 2009 lines)

**Status:** done — 114 rows: 74 ✅ 12 ⚠️ 9 ❌ 19 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `ReportJSError` (135) | `LogProblem` Core/Scripting/OOJavaScriptEngine.cpp:798 + `OOJSReportPendingException` :840 | ❌ |
| `+[OOJavaScriptEngine sharedEngine]` (237) | `OOJavaScriptEngine::sharedEngine` Core/Scripting/OOJavaScriptEngine.cpp:125 | ✅ |
| `-[OOJavaScriptEngine runMissionCallback]` (245) | `OOJavaScriptEngine::runMissionCallback` Core/Scripting/OOJavaScriptEngine.cpp:142 | ✅ |
| `-[OOJavaScriptEngine init]` (250) | `OOJavaScriptEngine::init` Core/Scripting/OOJavaScriptEngine.cpp:144 | ❌ |
| `-[OOJavaScriptEngine createMainThreadContext]` (291) | `OOJavaScriptEngine::createMainThreadContext` Core/Scripting/OOJavaScriptEngine.cpp:181 | ❌ |
| `-[OOJavaScriptEngine destroyMainThreadContext]` (378) | `OOJavaScriptEngine::destroyMainThreadContext` Core/Scripting/OOJavaScriptEngine.cpp:254 | ⚠️ |
| `-[OOJavaScriptEngine reset]` (403) | `OOJavaScriptEngine::reset` Core/Scripting/OOJavaScriptEngine.cpp:292 | ❌ |
| `-[OOJavaScriptEngine dealloc]` (450) | `OOJavaScriptEngine::~OOJavaScriptEngine` Core/Scripting/OOJavaScriptEngine.cpp:370 + `shutDown` :327 | ⚠️ |
| `-[OOJavaScriptEngine globalObject]` (462) | `OOJavaScriptEngine::globalObject` Core/Scripting/OOJavaScriptEngine.cpp:377 | ✅ |
| `-[OOJavaScriptEngine callJSFunction:forObject:argc:argv:result:]` (467) | `OOJavaScriptEngine::callJSFunction` Core/Scripting/OOJavaScriptEngine.cpp:379 | ✅ |
| `-[OOJavaScriptEngine removeGCObjectRoot:]` (490) | none (reference counting: no GC roots) | ➖ |
| `-[OOJavaScriptEngine removeGCValueRoot:]` (497) | none (reference counting: no GC roots) | ➖ |
| `-[OOJavaScriptEngine garbageCollectionOpportunity:]` (504) | `OOJavaScriptEngine::garbageCollectionOpportunity` Core/Scripting/OOJavaScriptEngine.cpp:402 | ⚠️ |
| `-[OOJavaScriptEngine showErrorLocations]` (515) | `OOJavaScriptEngine::showErrorLocations` Core/Scripting/OOJavaScriptEngine.cpp:410 | ✅ |
| `-[OOJavaScriptEngine setShowErrorLocations:]` (520) | `OOJavaScriptEngine::setShowErrorLocations` Core/Scripting/OOJavaScriptEngine.cpp:412 | ✅ |
| `-[OOJavaScriptEngine objectClass]` (525) | `gOOJSObjectClassID` Core/Scripting/OOJavaScriptEngine.cpp:1809 (global, not a method) | ➖ |
| `-[OOJavaScriptEngine stringClass]` (530) | `gOOJSStringClassID` Core/Scripting/OOJavaScriptEngine.cpp:1809 | ➖ |
| `-[OOJavaScriptEngine arrayClass]` (535) | `gOOJSArrayClassID` Core/Scripting/OOJavaScriptEngine.cpp:1809 | ➖ |
| `-[OOJavaScriptEngine numberClass]` (540) | `gOOJSNumberClassID` Core/Scripting/OOJavaScriptEngine.cpp:1810 | ➖ |
| `-[OOJavaScriptEngine booleanClass]` (545) | `gOOJSBooleanClassID` Core/Scripting/OOJavaScriptEngine.cpp:1810 | ➖ |
| `-[OOJavaScriptEngine lookUpStandardClassPointers]` (550) | `RegisterStandardObjectConverters` Core/Scripting/OOJavaScriptEngine.cpp:1985 (template eval) | ✅ |
| `-[OOJavaScriptEngine registerStandardObjectConverters]` (579) | `RegisterStandardObjectConverters` Core/Scripting/OOJavaScriptEngine.cpp:2004 | ⚠️ |
| `DebuggerHook` (589) | none (QuickJS has no debugger hook; README "Known behaviour differences") | ⚠️ |
| `-[OOJavaScriptEngine dumpStackForErrors]` (601) | `OOJavaScriptEngine::dumpStackForErrors` Core/Scripting/OOJavaScriptEngine.cpp:417 | ✅ |
| `-[OOJavaScriptEngine setDumpStackForErrors:]` (606) | `OOJavaScriptEngine::setDumpStackForErrors` Core/Scripting/OOJavaScriptEngine.cpp:419 | ✅ |
| `-[OOJavaScriptEngine dumpStackForWarnings]` (611) | `OOJavaScriptEngine::dumpStackForWarnings` Core/Scripting/OOJavaScriptEngine.cpp:423 | ✅ |
| `-[OOJavaScriptEngine setDumpStackForWarnings:]` (616) | `OOJavaScriptEngine::setDumpStackForWarnings` Core/Scripting/OOJavaScriptEngine.cpp:427 | ✅ |
| `-[OOJavaScriptEngine enableDebuggerStatement]` (621) | `OOJavaScriptEngine::enableDebuggerStatement` Core/Scripting/OOJavaScriptEngine.cpp:431 (no-op) | ⚠️ |
| `-[OOJavaScriptEngine(OOMonitorSupport) setMonitor:]` (633) | `OOJavaScriptEngine::setMonitor` Core/Scripting/OOJavaScriptEngine.cpp:438 | ✅ |
| `-[OOJavaScriptEngine(OOMonitorSupportInternal) sendMonitorError:withMessage:inContext:]` (643) | `OOJavaScriptEngine::sendMonitorProblem` Core/Scripting/OOJavaScriptEngine.cpp:442 | ✅ |
| `-[OOJavaScriptEngine(OOMonitorSupportInternal) sendMonitorLogMessage:withMessageClass:inContext:]` (652) | `OOJavaScriptEngine::sendMonitorLogMessage` Core/Scripting/OOJavaScriptEngine.cpp:451 | ✅ |
| `DumpVariable` (667) | none (no frame variables in QuickJS; README "Not yet done") | ⚠️ |
| `OOJSDumpStack` (694) | `OOJSDumpStack` Core/Scripting/OOJavaScriptEngine.cpp:1032 | ⚠️ |
| `GetLocationNameAndLine` (804) | `GetLocationFromStack` Core/Scripting/OOJavaScriptEngine.cpp:736 (parses `Error.stack`) | ✅ |
| `OOJSDescribeLocation` (823) | none (locations come from `Error.stack`) | ➖ |
| `OOJSMarkConsoleEvalLocation` (851) | none (comment Core/Scripting/OOJSSpecialFunctions.cpp:92-95) | ⚠️ |
| `OOJSInitJSIDCachePRIVATE` (857) | `OOJSInternAtomPRIVATE` Core/Scripting/OOJavaScriptEngine.cpp:1082 | ✅ |
| `OOJSIDFromString` (873) | `OOJSIDFromString` Core/Scripting/OOJavaScriptEngine.cpp:1093 | ✅ |
| `OOStringFromJSID` (906) | `OOStringFromJSID` Core/Scripting/OOJavaScriptEngine.cpp:1113 | ✅ |
| `CallerPrefix` (921) | `CallerPrefix` Core/Scripting/OOJavaScriptEngine.cpp:876 | ✅ |
| `OOJSReportError` (930) | `OOJSReportError` Core/Scripting/OOJavaScriptEngine.cpp:883 | ✅ |
| `OOJSReportErrorForCaller` (939) | `OOJSReportErrorForCaller` Core/Scripting/OOJavaScriptEngine.cpp:891 | ✅ |
| `OOJSReportErrorWithArguments` (957) | `OOJSReportErrorWithArguments` Core/Scripting/OOJavaScriptEngine.cpp:910 | ⚠️ |
| `OOJSReportWrappedException` (973) | `OOJSReportCurrentException` Core/Scripting/OOJSEngineNativeWrappers.cpp:40 | ✅ |
| `OOJSUnreachable` (986) | none (no caller in the port) | ➖ |
| `OOJSReportWarning` (994) | `OOJSReportWarning` Core/Scripting/OOJavaScriptEngine.cpp:932 | ✅ |
| `OOJSReportWarningForCaller` (1003) | `OOJSReportWarningForCaller` Core/Scripting/OOJavaScriptEngine.cpp:940 | ✅ |
| `OOJSReportWarningWithArguments` (1021) | `OOJSReportWarningWithArguments` Core/Scripting/OOJavaScriptEngine.cpp:959 | ✅ |
| `OOJSReportBadPropertySelector` (1035) | `OOJSReportBadPropertySelector` Core/Scripting/OOJavaScriptEngine.cpp:984 | ✅ |
| `OOJSReportBadPropertyValue` (1043) | `OOJSReportBadPropertyValue` Core/Scripting/OOJavaScriptEngine.cpp:994 | ✅ |
| `OOJSReportBadArguments` (1052) | `OOJSReportBadArguments` Core/Scripting/OOJavaScriptEngine.cpp:1006 | ✅ |
| `OOJSSetWarningOrErrorStackSkip` (1068) | `OOJSSetWarningOrErrorStackSkip` Core/Scripting/OOJavaScriptEngine.cpp:1027 | ✅ |
| `OOJSArgumentListGetNumber` (1073) | `OOJSArgumentListGetNumber` Core/Scripting/OOJavaScriptEngine.cpp:1038 | ✅ |
| `OOJSArgumentListGetNumberNoError` (1084) | `OOJSArgumentListGetNumberNoError` Core/Scripting/OOJavaScriptEngine.cpp:1053 | ✅ |
| `JSArrayFromNSArray` (1108) | `JSArrayValueFromPList` Core/Scripting/OOJavaScriptEngine.cpp:1128 | ✅ |
| `JSNewNSArrayValue` (1147) | `JSArrayValueFromPList` Core/Scripting/OOJavaScriptEngine.cpp:1128 (folded) | ✅ |
| `JSObjectFromNSDictionary` (1179) | `JSObjectValueFromPList` Core/Scripting/OOJavaScriptEngine.cpp:1156 | ⚠️ |
| `JSNewNSDictionaryValue` (1249) | `JSObjectValueFromPList` Core/Scripting/OOJavaScriptEngine.cpp:1156 (folded) | ✅ |
| `-[NSObject(OOJavaScriptConversion) oo_jsValueInContext:]` (1279) | `OOJSValueFromPList` Core/Scripting/OOJavaScriptEngine.cpp:1181 (data/date/unknown → undefined :1221-1260) | ✅ |
| `-[NSObject(OOJavaScriptConversion) oo_jsClassName]` (1284) | per-class `oo_jsClassName` of `OOJSPrivateObject`s (default none) | ✅ |
| `-[NSObject(OOJavaScriptConversion) oo_jsDescription]` (1289) | `OOJSPrivateObject::jsDescription` Core/Scripting/OOJSPrivateObject.h:64 | ✅ |
| `-[NSObject(OOJavaScriptConversion) oo_jsDescriptionWithClassName:]` (1294) | per-class `jsDescription` (e.g. Core/Scripting/OOJSTimer.cpp:263, OOJSSystemInfo.cpp:414) | ✅ |
| `-[NSObject(OOJavaScriptConversion) oo_clearJSSelf:]` (1316) | `OOJSPrivateObject::clearJSSelf` Core/Scripting/OOJSPrivateObject.h:60 | ✅ |
| `OOJSObjectFromNativeObject` (1322) | none (no caller) | ➖ |
| `+[OOJSValue valueWithJSValue:inContext:]` (1333) | `OOJSValue::valueWithJSValue` Core/Scripting/OOJavaScriptEngine.cpp:1266 | ✅ |
| `+[OOJSValue valueWithJSObject:inContext:]` (1342) | none (folded into `valueWithJSValue`) | ➖ |
| `-[OOJSValue initWithJSValue:inContext:]` (1351) | `OOJSValue::initWithJSValue` Core/Scripting/OOJavaScriptEngine.cpp:1273 | ✅ |
| `-[OOJSValue initWithJSObject:inContext:]` (1381) | none (folded) | ➖ |
| `-[OOJSValue deleteJSValue]` (1386) | `OOJSValue::deleteJSValue` Core/Scripting/OOJavaScriptEngine.cpp:1288 | ✅ |
| `-[OOJSValue dealloc]` (1400) | `OOJSValue::~OOJSValue` Core/Scripting/OOJavaScriptEngine.cpp:1298 | ✅ |
| `-[OOJSValue oo_jsValueInContext:]` (1406) | `OOJSValue::jsValueInContext` Core/Scripting/OOJavaScriptEngine.cpp:1300 | ✅ |
| `OOJSStrLiteralCachePRIVATE` (1413) | `OOJSSTR` macro (atoms) Core/Scripting/OOJSEngineCore.h:279 | ✅ |
| `OOStringFromJSString` (1430) | none (no JSString type; `OOStringFromJSValue`) | ➖ |
| `OOStringFromJSValueEvenIfNull` (1449) | `OOStringFromJSValueEvenIfNull` Core/Scripting/OOJavaScriptEngine.cpp:1314 | ✅ |
| `OOStringFromJSValue` (1461) | `OOStringFromJSValue` Core/Scripting/OOJavaScriptEngine.cpp:1329 | ✅ |
| `OOStringFromJSPropertyIDAndSpec` (1473) | `OOStringFromJSPropertyMagic` Core/Scripting/OOJavaScriptEngine.cpp:974 | ✅ |
| `DescribeValue` (1493) | `DescribeValue` Core/Scripting/OOJavaScriptEngine.cpp:1360 | ❌ |
| `OOJSDescribeValue` (1578) | `OOJSDescribeValue` Core/Scripting/OOJavaScriptEngine.cpp:1443 | ✅ |
| `+[NSString(OOJavaScriptExtensions) stringWithJavaScriptParameters:count:inContext:]` (1585) | `OOJSStringWithJavaScriptParameters` Core/Scripting/OOJavaScriptEngine.cpp:1448 | ✅ |
| `-[NSString(OOJavaScriptExtensions) oo_jsValueInContext:]` (1607) | `OOJSValueFromPList` Core/Scripting/OOJavaScriptEngine.cpp:1216 (string case) | ✅ |
| `+[NSString(OOJavaScriptExtensions) concatenationOfStringsFromJavaScriptValues:count:separator:inContext:]` (1634) | `OOJSConcatenationOfStringsFromJavaScriptValues` Core/Scripting/OOJavaScriptEngine.cpp:1464 | ❌ |
| `-[NSString(OOJavaScriptExtensions) escapedForJavaScriptLiteral]` (1663) | `OOJSEscapedForJavaScriptLiteral` Core/Scripting/OOJavaScriptEngine.cpp:1488 | ✅ |
| `-[NSString(OOJavaScriptExtensions) oo_jsClassName]` (1726) | none (strings are PList values, not JS-glue objects) | ➖ |
| `-[NSArray(OOJavaScriptConversion) oo_jsValueInContext:]` (1735) | `OOJSValueFromPList` Core/Scripting/OOJavaScriptEngine.cpp:1225 (array case) | ✅ |
| `-[OONativeVector(OOJavaScriptConversion) oo_jsValueInContext:]` (1746) | `OONativeVectorJSValueInContext` Core/Scripting/OOJavaScriptEngine.cpp:1540 | ✅ |
| `-[NSDictionary(OOJavaScriptConversion) oo_jsValueInContext:]` (1757) | `OOJSValueFromPList` Core/Scripting/OOJavaScriptEngine.cpp:1228 (dict case) | ✅ |
| `-[NSNumber(OOJavaScriptConversion) oo_jsValueInContext:]` (1768) | `OOJSValueFromPList` Core/Scripting/OOJavaScriptEngine.cpp:1186 (bool/integer/real cases) | ✅ |
| `-[NSNumber(OOJavaScriptConversion) oo_jsClassName]` (1797) | none (numbers are PList values) | ➖ |
| `-[NSNull(OOJavaScriptConversion) oo_jsValueInContext:]` (1806) | `OONull::jsValueInContext` Core/Scripting/OOJavaScriptEngine.cpp:1563 | ✅ |
| `OOJSUnconstructableConstruct` (1813) | `OOJSUnconstructableConstruct` Core/Scripting/OOJavaScriptEngine.cpp:1569 | ❌ |
| `OOJSObjectWrapperFinalize` (1826) | `OOJSObjectWrapperFinalize` Core/Scripting/OOJavaScriptEngine.cpp:1588 → `OOJSCxxObjectWrapperFinalize` Core/Scripting/OOJSPrivateObject.cpp:91 | ✅ |
| `OOJSObjectWrapperToString` (1840) | `OOJSObjectWrapperToString` Core/Scripting/OOJavaScriptEngine.cpp:1593 (+ `OOJSCxxObjectWrapperToString` OOJSPrivateObject.cpp:112) | ⚠️ |
| `JSFunctionPredicate` (1868) | `JSFunctionPredicate` Core/Scripting/OOJavaScriptEngine.cpp:1614 | ❌ |
| `JSEntityIsJavaScriptVisiblePredicate` (1908) | `JSEntityIsJavaScriptVisiblePredicate` Core/Scripting/OOJavaScriptEngine.cpp:1675 | ✅ |
| `JSEntityIsJavaScriptSearchablePredicate` (1917) | `JSEntityIsJavaScriptSearchablePredicate` Core/Scripting/OOJavaScriptEngine.cpp:1679 | ✅ |
| `JSEntityIsDemoShipPredicate` (1949) | `JSEntityIsDemoShipPredicate` Core/Scripting/OOJavaScriptEngine.cpp:1703 | ✅ |
| `OOJSRegisterSubclass` (1956) | `OOJSRegisterSubclass` Core/Scripting/OOJSClasses.cpp:95 | ✅ |
| `UnregisterSubclasses` (1969) | none (class IDs and the table live for the process) | ➖ |
| `OOJSIsSubclass` (1975) | `OOJSIsSubclass` Core/Scripting/OOJSClasses.cpp:105 | ✅ |
| `OOJSDictionaryFromJSValue` (2039) | `OOJSDictionaryFromJSValue` Core/Scripting/OOJavaScriptEngine.cpp:1720 | ✅ |
| `OOJSDictionaryFromJSObject` (2052) | `OOJSDictionaryFromJSObject` Core/Scripting/OOJavaScriptEngine.cpp:1727 | ❌ |
| `OOJSDictionaryFromStringTable` (2103) | `OOJSDictionaryFromStringTable` Core/Scripting/OOJavaScriptEngine.cpp:1760 | ✅ |
| `OOJSNativeObjectFromJSValue` (2155) | `OOJSPListFromJSValue` Core/Scripting/OOJavaScriptEngine.cpp:1812 | ✅ |
| `OOJSNativeObjectFromJSObject` (2182) | `OOJSPListFromJSObject` Core/Scripting/OOJavaScriptEngine.cpp:1854 | ✅ |
| `OOJSNativeObjectOfClassFromJSValue` (2207) | none (callers test the node, e.g. Core/Scripting/OOJSSound.cpp:146) | ➖ |
| `OOJSNativeObjectOfClassFromJSObject` (2215) | none (callers read the opaque slot of their class directly) | ➖ |
| `OOJSBasicPrivateObjectConverter` (2223) | `OOJSBasicPrivateObjectConverter` Core/Scripting/OOJavaScriptEngine.cpp:1869 | ✅ |
| `OOJSRegisterObjectConverter` (2235) | `OOJSRegisterObjectConverter` Core/Scripting/OOJavaScriptEngine.cpp:1879 | ✅ |
| `UnregisterObjectConverters` (2254) | none (converter table indexed by class ID, process lifetime) | ➖ |
| `JSArrayConverter` (2259) | `JSArrayConverter` Core/Scripting/OOJavaScriptEngine.cpp:1917 / `PListFromJSArray` :1885 | ✅ |
| `JSStringConverter` (2296) | `JSStringConverter` Core/Scripting/OOJavaScriptEngine.cpp:1927 | ✅ |
| `JSNumberConverter` (2301) | `JSNumberConverter` Core/Scripting/OOJavaScriptEngine.cpp:1941 | ✅ |
| `JSBooleanConverter` (2310) | `JSBooleanConverter` Core/Scripting/OOJavaScriptEngine.cpp:1959 | ✅ |
| `OOJSObjectGetterImplPRIVATE` (1990) | `OOJSGetCxxPrivateImpl` Core/Scripting/OOJSPrivateObject.cpp:59 | ✅ |

**Differences:**

- ⚠️ **med** — log message classes: the previous med finding (every report `…notAnError`) no longer holds, because the error-number lookup is gone. Warnings use `script.javaScript.warning.ooliteDefined`, as SpiderMonkey's 206 did (fixed since 2026-10-27). Errors and exceptions are now `script.javaScript.exception.<Error.name>` (`TypeError`, `ReferenceError`, `Error` for `OOJSReportError`, `exception` for a thrown non-Error), where upstream used `javascript-errors.plist` names (`notDefined`, `notFunction`, `undefinedProp`, `ooliteDefined`, `uncaughtException`, `notAnError`). The README lists this as a known difference ("Exception log message classes are named after the error type"), so it is now intentional. `javascript-errors.plist` is no longer read — upstream `Core/Scripting/OOJavaScriptEngine.m:179-186` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:798-802,851-869,966`, `Core/Scripting/README.md:153-155`
- ❌ **low** — the source line is never shown: the location line is always "      file, line N.", where upstream printed "      file, line N: <offending source line>" for compile errors (still open) — upstream `Core/Scripting/OOJavaScriptEngine.m:174-176,202-206` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:820-825`
- ❌ **med** — message texts that reach the log are QuickJS-ng's, not SpiderMonkey 1.8.5's (e.g. "cannot read property 'bar' of undefined" for "foo is undefined"; syntax-error wording throughout). Only the read-only assignment text is in the README (still open) — port `Core/Scripting/OOJavaScriptEngine.cpp:840-874`, `Core/Scripting/README.md:145-146`
- ❌ **med** — language: QuickJS-ng parses ES2023, not JS 1.8.5 with VAROBJFIX/ANONFUNFIX. Partly fixed since 2026-10-27: `toSource`/`uneval` come from `oolite-quickjs-compat.js`, legacy `const` is rewritten to `var`, `new` on natives and properties on primitives are patched, and post-1.8.5 globals are removed. Still missing, and not in the README's difference list: `for each (… in …)`, expression closures, Array/String generics (`Array.forEach(a, f)`), `watch`/`unwatch`, `__iterator__`, E4X, block-level function statement semantics. Impact is on expansions; no built-in script uses them — upstream `Core/Scripting/OOJavaScriptEngine.m:80-86,306-307` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:181-252,468-589`
- ❌ **low** (new; the previous audit said no line was logged) — `reset()` always logs `script.javascript.init` "JavaScript reset successful.". Upstream logged it only in `JS_THREADSAFE` builds (Mac/Linux debug) and had the in-request refusal there; release builds printed nothing — upstream `Core/Scripting/OOJavaScriptEngine.m:423-433` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:309`
- ❌ **low** (new) — `JSFunctionPredicate`: a predicate that throws is reported at once (`OOJSReportPendingException`), and the caller (`system.filteredEntities`) then returns `OOJSNativeFailure`, an uncatchable stop. Upstream left the exception pending and returned NO, so it propagated to the calling script, where a `try/catch` around `filteredEntities` could catch it — upstream `Core/Scripting/OOJavaScriptEngine.m:1888-1901`, `Core/Scripting/OOJSSystem.m:872` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1638-1644`, `Core/Scripting/OOJSSystem.cpp:1091`
- ❌ **low** (new) — `OOJSUnconstructableConstruct` takes the name from `this`/new.target. Called without `new` (`Ship()`), `this` is undefined, so the message is "(null) cannot be used as a constructor." where upstream named the callee ("Ship cannot …") — upstream `Core/Scripting/OOJavaScriptEngine.m:1817-1820` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1569-1584`, `Core/Scripting/OOJSClasses.cpp:234-235`
- ❌ **low** (new) — `DescribeValue` (bad-argument and bad-value messages) names functions from `fn.name`, which ES2015 infers for `var f = function(){}`, so "function f" where SpiderMonkey's `JS_GetFunctionId` gave "function" (same root cause as the OOJSTimer finding) — upstream `Core/Scripting/OOJavaScriptEngine.m:1499-1505` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1362-1374`
- ❌ **low** (new) — `OOJSDictionaryFromJSObject` reads each own enumerable property with `JS_GetProperty`, which runs getters. Upstream used `JS_LookupPropertyById`, which only peeked at slots and gave `true` for an accessor property, so `{get x() {…}}` passed to a native converts differently — upstream `Core/Scripting/OOJavaScriptEngine.m:2086` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1743`
- ⚠️ **low** — integer-like JS keys become decimal-string keys (upstream made `NSNumber` keys native code could not look up; port comment :1739-1741), and dictionaries are sorted `std::map`s (still open) — upstream `Core/Scripting/OOJavaScriptEngine.m:2074-2080` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1738-1752`
- ⚠️ **low** — native dictionary → JS object sets properties in sorted key order (comment "key order"), not NSDictionary hash order; QuickJS also lists integer-like keys first (README). Upstream's `NSNumber`-key branch has no counterpart (still open) — upstream `Core/Scripting/OOJavaScriptEngine.m:1195-1229` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1153-1178`
- ❌ **low** — `concatenationOfStringsFromJavaScriptValues`: when an element after the first fails `ToString`, upstream's `appendString:nil` raised ("Native exception: …"); the port appends the separator and skips the element (still open) — upstream `Core/Scripting/OOJavaScriptEngine.m:1647-1656` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:1473-1483`
- ❌ **low** (new) — `init`: the fatal runtime-creation line no longer says the size ("…failed to create JavaScript runtime." vs "…with size %uMiB."); fatal path only — upstream `Core/Scripting/OOJavaScriptEngine.m:279` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:165-166`
- ⚠️ **low** — debugger and stack dumps (README "Not yet done" and "Known behaviour differences"): `debugger;` logs nothing (`enableDebuggerStatement` is a no-op, no `DebuggerHook`); `OOJSDumpStack` logs the raw `Error().stack` as one `script.javaScript.stackTrace` line, with no frame indices, `this`, arguments or locals, and ignores `sErrorHandlerStackSkip`; console code is no longer reported as `<console input>` (still open) — port `Core/Scripting/OOJavaScriptEngine.cpp:431-433,1032-1035`
- ⚠️ **low** — `OOJSReportErrorWithArguments` always throws an `Error`; there is no direct-report path when no script is running, so the "JavaScript error" severity never appears (README: "QuickJS reports every error as an exception") (new wording; the previous run described a running-script split that is gone) — port `Core/Scripting/OOJavaScriptEngine.cpp:910-919`
- ⚠️ **low** — `garbageCollectionOpportunity(NO)` does nothing (reference counting plus QuickJS's threshold GC; comment :403-406); GC roots are gone. `destroyMainThreadContext` now frees the context outright (no `JS_ClearScope`) and debug builds log `script.javaScript.reset.liveObjects`; the destructor runs `shutDown` with a leak check and `script.javaScript.shutDown` lines (README "Testing"). The `js-gc-zeal` default is ignored (still open) — port `Core/Scripting/OOJavaScriptEngine.cpp:254-290,327-368,402-408`
- ⚠️ **low** — `OOJSObjectWrapperToString` always answers "[object <JSClass>]"; classes whose slot holds a C++ object describe themselves through `OOJSCxxObjectWrapperToString` and `jsDescription()` (still open) — port `Core/Scripting/OOJavaScriptEngine.cpp:1593-1608`, `Core/Scripting/OOJSPrivateObject.cpp:112-134`
- ⚠️ **low** — the plain-object converter returns null for the global object (port comment :1967-1972: QuickJS's global is a plain object and would recurse) — port `Core/Scripting/OOJavaScriptEngine.cpp:1965-1979`
- ✅ **low** — value conversions: `OOJSValueToInt32` now rounds with `floor(d + 0.5)` and then range-checks, so the earlier façade's narrower range rejection is fixed since 2026-10-27 ("can't convert %s to an integer" kept). Still open: string → number follows ES2015+ (`"0b101"` converts), a QuickJS behaviour — port `Core/Scripting/OOJavaScriptEngine.cpp:607-624`
- ✅ — `LogProblem` keeps the upstream first line ("%@ JavaScript %@ (%@): %@", `*****`/`-----`, "<unidentified script>"), the `showLocation && stackSkip == 0 && file` gate, the warning `willDisplay` skip and the monitor call. `OOJSReportBadArguments`/`BadPropertySelector`/`BadPropertyValue`/`ReportErrorForCaller` texts match; `OOJSReportCurrentException` keeps "Native exception: %s" / "Unidentified native exception" — port `Core/Scripting/OOJavaScriptEngine.cpp:798-1025`, `Core/Scripting/OOJSEngineNativeWrappers.cpp:40-57`
- ✅ — `OOJSValueFromPList` reproduces the NSNumber/NSString/NSArray/NSDictionary glue (bool → int32 1/0, in-range integers → int32, reals as doubles, single precision widened from float, data/date → undefined, empty keys and undefined values skipped). `JSEntityIsJavaScriptSearchablePredicate` drops the atmosphere case, which upstream compiled only under `!NEW_PLANETS` (`NEW_PLANETS` is 1, `Core/Entities/OOStellarBody.h:35`) — port `Core/Scripting/OOJavaScriptEngine.cpp:1181-1264,1679-1701`

## OOLegacyScriptWhitelist

<a id="oolegacyscriptwhitelist"></a>
Upstream `src/Core/Scripting/OOLegacyScriptWhitelist.m` ↔ `Core/Scripting/OOLegacyScriptWhitelist.cpp` (515 / 672 lines)

**Status:** done — 15 rows: 13 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOSanitizeLegacyScript` (58) | `OOSanitizeLegacyScript` Core/Scripting/OOLegacyScriptWhitelist.cpp:90 | ✅ |
| `OOSanitizeLegacyScriptInternal` (65) | `OOSanitizeLegacyScriptInternal` Core/Scripting/OOLegacyScriptWhitelist.cpp:100 | ❌ |
| `OOSanitizeLegacyScriptConditions` (101) | `OOSanitizeLegacyScriptConditions` Core/Scripting/OOLegacyScriptWhitelist.cpp:138 | ✅ |
| `OOSanitizeLegacyScriptConditionsInternal` (110) | `OOSanitizeLegacyScriptConditionsInternal` Core/Scripting/OOLegacyScriptWhitelist.cpp:149 | ❌ |
| `OOLegacyConditionsAreSanitized` (149) | `OOLegacyConditionsAreSanitized` Core/Scripting/OOLegacyScriptWhitelist.cpp:192 | ✅ |
| `SanitizeCondition` (156) | `SanitizeCondition` Core/Scripting/OOLegacyScriptWhitelist.cpp:199 | ✅ |
| `SanitizeConditionalStatement` (290) | `SanitizeConditionalStatement` Core/Scripting/OOLegacyScriptWhitelist.cpp:352 | ✅ |
| `SanitizeActionStatement` (336) | `SanitizeActionStatement` Core/Scripting/OOLegacyScriptWhitelist.cpp:411 | ✅ |
| `ClassifyLHSConditionSelector` (375) | `ClassifyLHSConditionSelector` Core/Scripting/OOLegacyScriptWhitelist.cpp:464 | ✅ |
| `SanitizeQueryMethod` (406) | `SanitizeQueryMethod` Core/Scripting/OOLegacyScriptWhitelist.cpp:541 (+ `WhitelistSet`/`WhitelistDictionary`/`AliasFor` :505-536) | ✅ |
| `SanitizeActionMethod` (427) | `SanitizeActionMethod` Core/Scripting/OOLegacyScriptWhitelist.cpp:562 | ✅ |
| `AlwaysFalseConditions` (476) | `AlwaysFalseConditions` Core/Scripting/OOLegacyScriptWhitelist.cpp:621 | ✅ |
| `IsAlwaysFalseConditions` (487) | `IsAlwaysFalseConditions` Core/Scripting/OOLegacyScriptWhitelist.cpp:639 | ✅ |
| `StringFromStackInternal` (492) | `StringFromStackInternal` Core/Scripting/OOLegacyScriptWhitelist.cpp:651 | ✅ |
| `StringFromStack` (512) | `StringFromStack` Core/Scripting/OOLegacyScriptWhitelist.cpp:669 | ✅ |

**Differences:**

- ❌ **low** — `script.syntax.statement.invalidType` names the bad statement with the PList type name (`integer`, `array`, `bool` …) instead of its Objective-C class (`[statement class]`, e.g. `GSMutableArray`, `NSCFNumber`). Log text of malformed scripts only (still open) — upstream `Core/Scripting/OOLegacyScriptWhitelist.m:86` ↔ port `Core/Scripting/OOLegacyScriptWhitelist.cpp:121-124`
- ❌ **low** — `script.syntax.condition.notString` has the same class-name → type-name change (still open) — upstream `Core/Scripting/OOLegacyScriptWhitelist.m:129` ↔ port `Core/Scripting/OOLegacyScriptWhitelist.cpp:167-170`
- ✅ subtle — `AlwaysFalseConditions()` keeps the upstream `!= nil` bug and always returns null, so a failing conditions array drops its whole conditional statement (port comment :622-626). Comparator table (`morethan` → greater-than), number+`undefined` and bool+non-equality rejections, RHS coalescing, argument join with `[credits_number]` rewrite, the 2-element action for no argument and the alias precedence (action aliases override AI aliases) all match — port `Core/Scripting/OOLegacyScriptWhitelist.cpp:199-616`
- ✅ subtle — `IsAlwaysFalseConditions` reads 0 for an empty/odd array as `[nil oo_unsignedIntAtIndex:]` did; the root stack element with no context prints "0" in both — port `Core/Scripting/OOLegacyScriptWhitelist.cpp:639-671`

## OOPListScript

<a id="ooplistscript"></a>
Upstream `src/Core/Scripting/OOPListScript.m` ↔ `Core/Scripting/OOPListScript.cpp` (193 / 194 lines)

**Status:** done — 10 rows: 4 ✅ 4 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOPListScript scriptsInPListFile:]` (50) | `OOPListScript::scriptsInPListFile` Core/Scripting/OOPListScript.cpp:50 | ⚠️ |
| `-[OOPListScript dealloc]` (63) | implicit destructor (`_script`/`_metadata` are values) | ➖ |
| `-[OOPListScript name]` (71) | `OOPListScript::name` Core/Scripting/OOPListScript.cpp:68 | ✅ |
| `-[OOPListScript scriptDescription]` (76) | `OOPListScript::scriptDescription` Core/Scripting/OOPListScript.cpp:77 | ⚠️ |
| `-[OOPListScript version]` (81) | `OOPListScript::version` Core/Scripting/OOPListScript.cpp:84 | ❌ |
| `-[OOPListScript requiresTickle]` (86) | `OOPListScript::requiresTickle` Core/Scripting/OOPListScript.cpp:93 | ✅ |
| `-[OOPListScript runWithTarget:]` (91) | `OOPListScript::runWithTarget` Core/Scripting/OOPListScript.cpp:95 | ✅ |
| `+[OOPListScript(SetUp) scriptsFromDictionaryOfScripts:filePath:]` (112) | `OOPListScript::scriptsFromDictionaryOfScripts` Core/Scripting/OOPListScript.cpp:114 | ⚠️ |
| `+[OOPListScript(SetUp) loadCachedScripts:]` (152) | `OOPListScript::loadCachedScripts` Core/Scripting/OOPListScript.cpp:156 | ⚠️ |
| `-[OOPListScript(SetUp) initWithName:scriptArray:metadata:]` (173) | `OOPListScript::OOPListScript` Core/Scripting/OOPListScript.cpp:182 | ✅ |

**Differences:**

- ⚠️ **med** — the scripts of one `script.plist` come out in sorted key order (`oo::PList::Dict` is a `std::map`), not NSDictionary hash order, both on first load and from the cache. This sets world-script tickle/run order and log order. Stated in the port comments (still open) — upstream `Core/Scripting/OOPListScript.m:129,158` ↔ port `Core/Scripting/OOPListScript.cpp:126-128,163-165`
- ❌ **low** — a non-string metadata `version` is dropped. Upstream `-version` returned any object and `-displayName` formatted it with `%@`, so `<real>1.2</real>` gave "name 1.2"; the port gives just "name" in `script.legacy.run` and every other `displayName` use. The port comment's "-length" rationale doesn't match upstream `displayName` (still open) — upstream `Core/Scripting/OOPListScript.m:81-84`, `Core/Scripting/OOScript.m:248-257` ↔ port `Core/Scripting/OOPListScript.cpp:84-91`
- ⚠️ **low** — a non-string `description` becomes nullopt (port comment; bead oo-3rb.266 says nothing calls it) (still open) — port `Core/Scripting/OOPListScript.cpp:77-82`
- ⚠️ **low** — a `script.plist` that is not a dictionary no longer logs `plist.wrongType`; the port comment says so (still open) — upstream `Core/OOPListParsing.m:226-232` ↔ port `Core/Scripting/OOPListScript.cpp:57-61`
- ✅ subtle — the metadata is a dictionary or nothing, the `!metadata!` key is skipped, the cache entry omits metadata when absent (as `dictionaryWithObjectsAndKeys:` stopped at nil), and `name` always overrides the metadata's name — port `Core/Scripting/OOPListScript.cpp:114-194`

## OOScript

<a id="ooscript"></a>
Upstream `src/Core/Scripting/OOScript.m` ↔ `Core/Scripting/OOScript.cpp` (271 / 340 lines)

**Status:** done — 13 rows: 12 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOScript worldScriptsAtPath:]` (43) | `OOScript::worldScriptsAtPath` Core/Scripting/OOScript.cpp:69 | ⚠️ |
| `+[OOScript scriptsFromFileNamed:]` (117) | `OOScript::scriptsFromFileNamed` Core/Scripting/OOScript.cpp:146 | ✅ |
| `+[OOScript scriptsFromList:]` (132) | `OOScript::scriptsFromList` Core/Scripting/OOScript.cpp:162 | ✅ |
| `+[OOScript scriptsFromFileAtPath:]` (149) | `OOScript::scriptsFromFileAtPath` Core/Scripting/OOScript.cpp:179 | ✅ |
| `+[OOScript jsScriptFromFileNamed:properties:]` (175) | `OOScript::jsScriptFromFileNamed` Core/Scripting/OOScript.cpp:206 | ✅ |
| `+[OOScript jsAIScriptFromFileNamed:properties:]` (200) | `OOScript::jsAIScriptFromFileNamed` Core/Scripting/OOScript.cpp:235 | ✅ |
| `-[OOScript descriptionComponents]` (225) | `OOScript::descriptionComponents` Core/Scripting/OOScript.cpp:264 | ✅ |
| `-[OOScript name]` (230) | `OOScript::name` Core/Scripting/OOScript.cpp:269 | ✅ |
| `-[OOScript scriptDescription]` (236) | `OOScript::scriptDescription` Core/Scripting/OOScript.cpp:275 | ✅ |
| `-[OOScript version]` (242) | `OOScript::version` Core/Scripting/OOScript.cpp:281 | ✅ |
| `-[OOScript displayName]` (248) | `OOScript::displayName` Core/Scripting/OOScript.cpp:287 | ✅ |
| `-[OOScript requiresTickle]` (261) | `OOScript::requiresTickle` Core/Scripting/OOScript.cpp:297 | ✅ |
| `-[OOScript runWithTarget:]` (266) | `OOScript::runWithTarget` Core/Scripting/OOScript.cpp:299 | ✅ |

**Differences:**

- ⚠️ **low** — `world-scripts.plist` is read through `StringsFromArrayFile`: a non-array file no longer logs `plist.wrongType`, and non-string entries are skipped silently, where upstream passed them on to `scriptsFromFileNamed:` ("Could not find script file …" or an exception). Stated in the comment (still open) — upstream `Core/Scripting/OOScript.m:57`, `Core/OOPListParsing.m:219-232` ↔ port `Core/Scripting/OOScript.cpp:44-58,78-83`
- ✅ subtle — log classes and texts (`script.load.javaScript`, `.parseOK`, `.parseError`, `.pList`, `.none`, `.notFound`, `.badName`), the `.js`/`.es` → `.plist` fallback, `OOEnforceStandards` gates and the empty-list case (an empty array stops the search) match. `descriptionComponents`/`displayName` print "(null)" for a nil name/version, as `%@` did — port `Core/Scripting/OOScript.cpp:69-295`
- Note: the port adds `callMethod` (always false), `className`, `description`, `jsValueInContext` (undefined, as NSObject's `JSVAL_VOID`) and `clearJSSelf` here — port `Core/Scripting/OOScript.cpp:304-331`

## OOScriptTimer

<a id="ooscripttimer"></a>
Upstream `src/Core/Scripting/OOScriptTimer.m` ↔ `Core/Scripting/OOScriptTimer.cpp` (244 / 256 lines)

**Status:** done — 16 rows: 16 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOScriptTimer initWithNextTime:interval:]` (39) | `OOScriptTimer::initWithNextTime` Core/Scripting/OOScriptTimer.cpp:67 | ✅ |
| `-[OOScriptTimer initOneShotTimerWithDelay:]` (66) | `OOScriptTimer::initOneShotTimerWithDelay` Core/Scripting/OOScriptTimer.cpp:90 | ✅ |
| `-[OOScriptTimer dealloc]` (71) | `OOScriptTimer::~OOScriptTimer` Core/Scripting/OOScriptTimer.cpp:95 | ✅ |
| `-[OOScriptTimer descriptionComponents]` (79) | `OOScriptTimer::descriptionComponents` Core/Scripting/OOScriptTimer.cpp:113 | ✅ |
| `-[OOScriptTimer nextTime]` (91) | `OOScriptTimer::nextTime` Core/Scripting/OOScriptTimer.cpp:125 | ✅ |
| `-[OOScriptTimer setNextTime:]` (96) | `OOScriptTimer::setNextTime` Core/Scripting/OOScriptTimer.cpp:127 | ✅ |
| `-[OOScriptTimer interval]` (105) | `OOScriptTimer::interval` Core/Scripting/OOScriptTimer.cpp:134 | ✅ |
| `-[OOScriptTimer setInterval:]` (110) | `OOScriptTimer::setInterval` Core/Scripting/OOScriptTimer.cpp:136 | ✅ |
| `-[OOScriptTimer timerFired]` (117) | `OOScriptTimer::timerFired` Core/Scripting/OOScriptTimer.cpp:141 | ✅ |
| `-[OOScriptTimer scheduleTimer]` (122) | `OOScriptTimer::scheduleTimer` Core/Scripting/OOScriptTimer.cpp:143 | ✅ |
| `-[OOScriptTimer unscheduleTimer]` (143) | `OOScriptTimer::unscheduleTimer` Core/Scripting/OOScriptTimer.cpp:161 | ✅ |
| `-[OOScriptTimer isScheduled]` (150) | `OOScriptTimer::isScheduled` Core/Scripting/OOScriptTimer.cpp:169 | ✅ |
| `+[OOScriptTimer updateTimers]` (155) | `OOScriptTimer::updateTimers` Core/Scripting/OOScriptTimer.cpp:171 | ✅ |
| `+[OOScriptTimer noteGameReset]` (189) | `OOScriptTimer::noteGameReset` Core/Scripting/OOScriptTimer.cpp:208 | ✅ |
| `-[OOScriptTimer isValidForScheduling]` (201) | `OOScriptTimer::isValidForScheduling` Core/Scripting/OOScriptTimer.cpp:219 | ✅ |
| `-[OOScriptTimer compareByNextFireTime:]` (224) | `OOScriptTimer::compareByNextFireTime` Core/Scripting/OOScriptTimer.cpp:242 | ✅ |

**Differences:**

- ✅ **low** — subtle: `descriptionComponents` uses `std::format("{:g}")`, which matches printf `%g` (precision 6). `description()` keeps the `<Class 0x…>{…}` NSObject form with the C++ class name (`OOJSTimer`/`OOScriptTimer`) — port `Core/Scripting/OOScriptTimer.cpp:99-123`, `Core/Scripting/OOJSTimer.h:56`
- ✅ **low** — subtle: deferred timers are added after the loop in order, and are dropped if the queue was never created, as `[nil addObjects:]` was. `compareByNextFireTime` no longer has the try/catch; the getter cannot throw (port comment :245-247) — port `Core/Scripting/OOScriptTimer.cpp:197-203,242-256`

