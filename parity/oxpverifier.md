# Parity findings: oxpverifier
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## OOAIStateMachineVerifierStage

<a id="ooaistatemachineverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOAIStateMachineVerifierStage.m` ↔ `Core/OXPVerifier/OOAIStateMachineVerifierStage.cpp` (201 / 219 lines)

**Status:** done — 7 rows: 5 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOAIStateMachineVerifierStage dealloc]` (44) | members (`_whitelist`, `_usedAIs` sorted vectors) — `Core/OXPVerifier/OOAIStateMachineVerifierStage.h` | ➖ |
| `-[OOAIStateMachineVerifierStage name]` (52) | `name` `Core/OXPVerifier/OOAIStateMachineVerifierStage.cpp:75` | ✅ |
| `-[OOAIStateMachineVerifierStage shouldRun]` (57) | `shouldRun` `…/OOAIStateMachineVerifierStage.cpp:79` | ✅ |
| `-[OOAIStateMachineVerifierStage run]` (62) | `run` `…/OOAIStateMachineVerifierStage.cpp:81` (whitelist from the same three keys; AIs sorted case-insensitively) | ✅ |
| `+[OOAIStateMachineVerifierStage nameForReverseDependencyForVerifier:]` (85) | `nameForReverseDependencyForVerifier` `…/OOAIStateMachineVerifierStage.cpp:106` | ✅ |
| `-[OOAIStateMachineVerifierStage stateMachineNamed:usedByShip:]` (90) | `stateMachineNamed` `…/OOAIStateMachineVerifierStage.cpp:111` (null scanner → warning, as nil-messaging NO) | ✅ |
| `-[OOAIStateMachineVerifierStage(Private) validateAI:]` (115) | `validateAI` `…/OOAIStateMachineVerifierStage.cpp:130` (+ `PListDictionaryFromFile` :46) | ❌ |

**Differences:**

- ❌ **low** — states and handlers are walked in `PList::Dict` byte order instead of `NSDictionary` hash order, so the `invalidFormat.state`/`.handler`/`.action` errors come out in a different order (still open) — upstream `Core/OXPVerifier/OOAIStateMachineVerifierStage.m:147,156` ↔ port `Core/OXPVerifier/OOAIStateMachineVerifierStage.cpp:155,165`
- ⚠️ **low** — an AI file that parses but is not a dictionary no longer logs `plist.wrongType` before `verifyOXP.validateAI.failed.notDictPlist`; port comment says so (still open) — upstream `Core/OOPListParsing.m:207-232` via `…/OOAIStateMachineVerifierStage.m:140` ↔ port `…/OOAIStateMachineVerifierStage.cpp:43-49,147`
- Subtle (same on both sides): the early returns in `validateAI` skip `OOLogOutdentIf`. Case-insensitive sorts are `std::stable_sort` (upstream unstable); differs only for names equal ignoring case. A missing OXP display name prints `(null)` as `%@` of nil did.

## OOCheckDemoShipsPListVerifierStage

<a id="oocheckdemoshipsplistverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.cpp` (114 / 99 lines)

**Status:** done — 4 rows: 4 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckDemoShipsPListVerifierStage name]` (42) | `name` `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.cpp:34` | ✅ |
| `-[OOCheckDemoShipsPListVerifierStage shouldRun]` (47) | `shouldRun` `…/OOCheckDemoShipsPListVerifierStage.cpp:38` (null scanner → false) | ✅ |
| `-[OOCheckDemoShipsPListVerifierStage run]` (58) | `run` `…/OOCheckDemoShipsPListVerifierStage.cpp:48` (same order: demoships, array check, shipdata, dict check) | ✅ |
| `-[OOCheckDemoShipsPListVerifierStage(OOPrivate) runCheckWithDemoShips:shipData:]` (101) | `runCheckWithDemoShips` `…/OOCheckDemoShipsPListVerifierStage.cpp:84` | ✅ |

**Differences:**

- None. Null-scanner guards reproduce nil-messaging. A non-string entry still warns `unknownShip` with the entry's description (`:89-94`).

## OOCheckEquipmentPListVerifierStage

<a id="oocheckequipmentplistverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.cpp` (158 / 181 lines)

**Status:** done — 4 rows: 4 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckEquipmentPListVerifierStage name]` (44) | `name` `Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.cpp:50` | ✅ |
| `-[OOCheckEquipmentPListVerifierStage shouldRun]` (49) | `shouldRun` `…/OOCheckEquipmentPListVerifierStage.cpp:54` | ✅ |
| `-[OOCheckEquipmentPListVerifierStage run]` (60) | `run` `…/OOCheckEquipmentPListVerifierStage.cpp:64` | ✅ |
| `-[OOCheckEquipmentPListVerifierStage(OOPrivate) runCheckWithEquipment:]` (88) | `runCheckWithEquipment` `…/OOCheckEquipmentPListVerifierStage.cpp:87` (+ `StringAt` :41) | ✅ |

**Differences:**

- None. Constants, check order, message texts and the `5 < elemCount` extra-info check match. `oo_longAtIndex:defaultValue:-1` ↔ `at<long>(i, -1)` (OOLongLongFromObject semantics, `oofnd/PListGet.hpp:548-563`); `oo_stringAtIndex:` (string or number) ↔ `StringAt`.

## OOCheckJSSyntaxVerifierStage

<a id="oocheckjssyntaxverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.cpp` (90 / 102 lines)

**Status:** done — 3 rows: 2 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckJSSyntaxVerifierStage name]` (40) | `name` `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.cpp:46` | ✅ |
| `-[OOCheckJSSyntaxVerifierStage shouldRun]` (45) | `shouldRun` `…/OOCheckJSSyntaxVerifierStage.cpp:50` | ✅ |
| `-[OOCheckJSSyntaxVerifierStage run]` (53) | `run` `…/OOCheckJSSyntaxVerifierStage.cpp:64` → `OOJSScript::scriptWithPath` | ⚠️ |

**Differences:**

- ⚠️ **med** — stage logic is the same (nil-folder early exit ↔ `has_value()`, `.js`/`.es` lowercase extension test, `Config/script.js` last), but the scripts are compiled and run on QuickJS-ng instead of SpiderMonkey 1.8.5 (ADR-0002, `Core/Scripting/ooscript/README.md`). SpiderMonkey-only syntax fails, ES2015+ passes, and error text/locations differ (still open) — upstream `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.m:76,83` ↔ port `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.cpp:88,95`
- ❌ **low** — scripts in `Scripts/` are checked in `filesInFolder`'s byte order, not `-allValues` hash order; counted under OOFileScannerVerifierStage `filesInFolder` (still open) — upstream `:63,71` ↔ port `:74,84`

## OOCheckPListSyntaxVerifierStage

<a id="oocheckplistsyntaxverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.cpp` (91 / 106 lines)

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckPListSyntaxVerifierStage name]` (37) | `name` `Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.cpp:57` | ✅ |
| `-[OOCheckPListSyntaxVerifierStage shouldRun]` (42) | `shouldRun` `…/OOCheckPListSyntaxVerifierStage.cpp:61` | ✅ |
| `-[OOCheckPListSyntaxVerifierStage run]` (47) | `run` `…/OOCheckPListSyntaxVerifierStage.cpp:63` (+ `StringsForKey` :38) | ✅ |

**Differences:**

- None. Upstream's copy-paste message is kept: a dictionary plist missing from `ConfigDictionaries` still logs "should be an array but isn't." (upstream `:79` ↔ port `:95`). `knownFiles` arrays are read in plist order; only string elements are used (the only ones `containsObject:` could match).

## OOCheckRequiresPListVerifierStage

<a id="oocheckrequiresplistverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckRequiresPListVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.cpp` (143 / 200 lines)

**Status:** done — 3 rows: 2 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckRequiresPListVerifierStage name]` (37) | `name` `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.cpp:77` | ✅ |
| `-[OOCheckRequiresPListVerifierStage shouldRun]` (42) | `shouldRun` `…/OOCheckRequiresPListVerifierStage.cpp:81` | ✅ |
| `-[OOCheckRequiresPListVerifierStage run]` (53) | `run` `…/OOCheckRequiresPListVerifierStage.cpp:91` (+ `VersionStringForKey` :42, `OoliteInfoString` :58) | ❌ |

**Differences:**

- ❌ **low** — the unknown-keys list is joined in `PList::Dict` byte order, not `NSSet -allObjects` hash order; with two or more unknown keys the `verifyOXP.requiresPList.unknownKeys` text differs (still open) — upstream `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.m:81-87` ↔ port `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.cpp:121-132`
- Subtle: Oolite's own version is read from `Info-gnustep.plist` in the built-in resources folder instead of `[[NSBundle mainBundle] infoDictionary]`; same on a GNUstep layout — upstream `:108` ↔ port `:58-73,144-145`. Version checks, their order (newer, older, range) and texts match.

## OOCheckShipDataPListVerifierStage

<a id="oocheckshipdataplistverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckShipDataPListVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp` (363 / 394 lines)

**Status:** done — 14 rows: 12 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckShipDataPListVerifierStage name]` (58) | `name` `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp:85` | ✅ |
| `-[OOCheckShipDataPListVerifierStage dependents]` (63) | `dependents` `…/OOCheckShipDataPListVerifierStage.cpp:90` (super = `OOTextureHandlingStage` + model + AI stage names) | ✅ |
| `-[OOCheckShipDataPListVerifierStage shouldRun]` (71) | `shouldRun` `…/OOCheckShipDataPListVerifierStage.cpp:103` | ✅ |
| `-[OOCheckShipDataPListVerifierStage run]` (82) | `run` `…/OOCheckShipDataPListVerifierStage.cpp:113` (key sets: basic, station = basic+station, player = basic+player, all = union; ships sorted case-insensitively) | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) verifyShipInfo:withName:]` (163) | `verifyShipInfo` `…/OOCheckShipDataPListVerifierStage.cpp:204` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) message:]` (194) | `reportMessage` `…/OOCheckShipDataPListVerifierStage.cpp:237` (caller pre-formats with `formatRuntime` `%@`) | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) verboseMessage:]` (209) | `verboseMessage` `…/OOCheckShipDataPListVerifierStage.cpp:250` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) getRoles]` (227) | `getRoles` `…/OOCheckShipDataPListVerifierStage.cpp:264` | ❌ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) checkKeys]` (249) | `checkKeys` `…/OOCheckShipDataPListVerifierStage.cpp:292` | ❌ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) checkSchema]` (277) | `checkSchema` `…/OOCheckShipDataPListVerifierStage.cpp:321` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) checkModel]` (282) | `checkModel` `…/OOCheckShipDataPListVerifierStage.cpp:327` (null model stage → warning, as nil → NO) | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) rolesFromString:]` (308) | `rolesFromString` `…/OOCheckShipDataPListVerifierStage.cpp:352` (`oo::str::tokens`, cut at `(`) | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) verifier:withPropertyList:named:testProperty:atPath:againstType:error:]` (337) | `verifierTestProperty` `…/OOCheckShipDataPListVerifierStage.cpp:367` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) verifier:withPropertyList:named:failedForProperty:withError:expectedType:]` (349) | `verifierFailedForProperty` `…/OOCheckShipDataPListVerifierStage.cpp:378` (keyPath description + failure reason, `(null)` when absent) | ✅ |

**Differences:**

- ❌ **low** — a ship's keys are walked in `PList::Dict` byte order, not `-keyEnumerator` hash order, so "unknown key" / "does not apply to this category" warnings come out in a different order (still open) — upstream `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.m:262` ↔ port `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp:302`
- ❌ **low** — a `roles` value that is not a string is treated as absent (no roles, and `_isStation` true by the nil rule). Upstream sent string messages to it (`ScanTokensFromString`, `-rangeOfString:`), giving an exception caught by `performRun` or meaningless roles (still open) — upstream `:231-239,319` ↔ port `:267-279`
- Kept quirk (✅): a ship with no `roles` counts as a station (`[nil rangeOfString:]` location 0), commented at `:273-277`.
- Subtle: the ship list sort is `std::stable_sort` (upstream unstable); differs only for keys equal ignoring case. Non-dict `materials`/`shaders` are passed as a null PList where upstream passed nil.

## OOFileScannerVerifierStage

<a id="oofilescannerverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOFileScannerVerifierStage.m` ↔ `Core/OXPVerifier/OOFileScannerVerifierStage.cpp` (701 / 703 lines)

**Status:** done — 26 rows: 20 ✅ 1 ⚠️ 3 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOFileScannerVerifierStage dealloc]` (83) | members — `Core/OXPVerifier/OOFileScannerVerifierStage.h` | ➖ |
| `-[OOFileScannerVerifierStage name]` (95) | `name` `Core/OXPVerifier/OOFileScannerVerifierStage.cpp:90` | ✅ |
| `-[OOFileScannerVerifierStage run]` (100) | `run` `…/OOFileScannerVerifierStage.cpp:94` | ✅ |
| `+[OOFileScannerVerifierStage nameForDependencyForVerifier:]` (118) | `nameForDependencyForVerifier` `…/OOFileScannerVerifierStage.cpp:111` (registerStage shares the new stage) | ✅ |
| `-[OOFileScannerVerifierStage fileExists:inFolder:referencedFrom:checkBuiltIn:]` (130) | `fileExists` `…/OOFileScannerVerifierStage.cpp:123` | ✅ |
| `-[OOFileScannerVerifierStage pathForFile:inFolder:referencedFrom:checkBuiltIn:]` (138) | `pathForFile` `…/OOFileScannerVerifierStage.cpp:130` (+ `realNameOf` :302); folder then root lookup, both caseMismatch checks, built-in fallback | ✅ |
| `-[OOFileScannerVerifierStage dataForFile:inFolder:referencedFrom:checkBuiltIn:]` (209) | `dataForFile` `…/OOFileScannerVerifierStage.cpp:208` | ✅ |
| `-[OOFileScannerVerifierStage plistNamed:inFolder:referencedFrom:checkBuiltIn:]` (223) | `plistNamed` `…/OOFileScannerVerifierStage.cpp:220` | ✅ |
| `-[OOFileScannerVerifierStage displayNameForFile:andFolder:]` (283) | `displayNameForFile` `…/OOFileScannerVerifierStage.cpp:279` | ✅ |
| `-[OOFileScannerVerifierStage filesInFolder:]` (290) | `filesInFolder` `…/OOFileScannerVerifierStage.cpp:287` | ❌ |
| `-[OOFileScannerVerifierStage(OOPrivate) scanForFiles]` (301) | `scanForFiles` `…/OOFileScannerVerifierStage.cpp:311` | ❌ |
| `-[OOFileScannerVerifierStage(OOPrivate) checkRootFolders]` (374) | `checkRootFolders` `…/OOFileScannerVerifierStage.cpp:399` (+ `StringsFromArray` :69) | ✅ |
| `-[OOFileScannerVerifierStage(OOPrivate) checkConfigFiles]` (398) | `checkConfigFiles` `…/OOFileScannerVerifierStage.cpp:418` (never called, on either side) | ✅ |
| `-[OOFileScannerVerifierStage(OOPrivate) checkKnownFiles]` (431) | `checkKnownFiles` `…/OOFileScannerVerifierStage.cpp:447` | ⚠️ |
| `-[OOFileScannerVerifierStage(OOPrivate) lowercaseMap:]` (474) | `lowercaseMap` `…/OOFileScannerVerifierStage.cpp:492` (never called, on either side) | ✅ |
| `-[OOFileScannerVerifierStage(OOPrivate) scanDirectory:]` (497) | `scanDirectory` `…/OOFileScannerVerifierStage.cpp:504` | ❌ |
| `-[OOFileScannerVerifierStage(OOPrivate) checkPListFormat:file:folder:]` (547) | `checkPListFormat` `…/OOFileScannerVerifierStage.cpp:562` | ✅ |
| `-[OOFileScannerVerifierStage(OOPrivate) constructReadMeNames]` (585) | `constructReadMeNames` `…/OOFileScannerVerifierStage.cpp:603` (string-or-number stems/extensions, lowercased) | ✅ |
| `-[OOListUnusedFilesStage name]` (624) | `OOListUnusedFilesStage::name` `…/OOFileScannerVerifierStage.cpp:637` | ✅ |
| `-[OOListUnusedFilesStage dependencies]` (629) | `OOListUnusedFilesStage::dependencies` `…/OOFileScannerVerifierStage.cpp:641` | ✅ |
| `-[OOListUnusedFilesStage run]` (634) | `OOListUnusedFilesStage::run` `…/OOFileScannerVerifierStage.cpp:645` | ✅ |
| `+[OOListUnusedFilesStage nameForReverseDependencyForVerifier:]` (639) | `OOListUnusedFilesStage::nameForReverseDependencyForVerifier` `…/OOFileScannerVerifierStage.cpp:651` | ✅ |
| `-[OOOXPVerifier(OOFileScannerVerifierStage) fileScannerStage]` (655) | inlined as `verifier()->stageWithName(OOFileScannerVerifierStage::kName)` at each call site (e.g. `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.cpp:41`) | ➖ |
| `-[OOFileHandlingVerifierStage dependencies]` (664) | `OOFileHandlingVerifierStage::dependencies` `…/OOFileScannerVerifierStage.cpp:666` | ✅ |
| `-[OOFileHandlingVerifierStage dependents]` (669) | `OOFileHandlingVerifierStage::dependents` `…/OOFileScannerVerifierStage.cpp:672` | ✅ |
| `CheckNameConflict` (676) | `CheckNameConflict` `…/OOFileScannerVerifierStage.cpp:679` | ✅ |

**Differences:**

- ❌ **low** — the `verifyOXP.scanFiles.nonStandardFile` warning no longer names the file type: upstream `"%@" is a non-standard file (%@), ignoring.` with the `NSFileType…` string; port `"…" is a non-standard file, ignoring.` (root and sub-folder) (still open) — upstream `Core/OXPVerifier/OOFileScannerVerifierStage.m:362,539` ↔ port `Core/OXPVerifier/OOFileScannerVerifierStage.cpp:386-387,552-554`
- ❌ **low** — `filesInFolder` returns names in byte order of their lowercase keys (`std::map`), not `-allValues` hash order; this reorders the JS syntax checks and the `Images/` texture checks and their log lines (still open) — upstream `:294` ↔ port `:291-297`
- ⚠️ **low** — `checkKnownFiles` walks the `knownFiles` folders in byte order (port comment "they were in dictionary order"); only the order of `caseMismatch` lines changes. A non-array folder entry is skipped where upstream's `foreach` would have thrown (still open) — upstream `:443-447` ↔ port `:452-460`
- Subtle (✅): `pathForFile` builds the full path one component at a time (`:193-196`), same result. `plistNamed` reads the file itself so an empty file is still parsed and reported (`:229-235`). Parse-error lines are split on `\n` with leading tabs → 4 spaces, as upstream. Directory enumeration is file-system order on both sides; junk/skip sets keep only strings, the only ones looked up.

## OOModelVerifierStage

<a id="oomodelverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOModelVerifierStage.m` ↔ `Core/OXPVerifier/OOModelVerifierStage.cpp` (191 / 105 lines)

**Status:** done — 9 rows: 4 ✅ 0 ⚠️ 2 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOModelVerifierStage init]` (47) | member init; the `NSNULL` sentinel is replaced by `OOModelVerifierEntry` fields — `Core/OXPVerifier/OOModelVerifierStage.h` | ➖ |
| `-[OOModelVerifierStage dealloc]` (57) | members | ➖ |
| `+[OOModelVerifierStage nameForReverseDependencyForVerifier:]` (64) | `nameForReverseDependencyForVerifier` `Core/OXPVerifier/OOModelVerifierStage.cpp:39` | ✅ |
| `-[OOModelVerifierStage name]` (76) | `name` `…/OOModelVerifierStage.cpp:51` | ✅ |
| `-[OOModelVerifierStage shouldRun]` (81) | `shouldRun` `…/OOModelVerifierStage.cpp:53` | ✅ |
| `-[OOModelVerifierStage run]` (86) | `run` `…/OOModelVerifierStage.cpp:55` | ❌ |
| `-[OOModelVerifierStage modelNamed:usedForEntry:inFile:withMaterials:andShaders:]` (122) | `modelNamed` `…/OOModelVerifierStage.cpp:67` | ❌ |
| `-[OOModelVerifierStage(OOPrivate) checkModel:context:materials:shaders:]` (171) | `checkModel` `…/OOModelVerifierStage.cpp:97` | ✅ |
| `-[OOOXPVerifier(OOModelVerifierStage) modelVerifierStage]` (184) | inlined `verifier()->stageWithName(OOModelVerifierStage::kName)` `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp:334-335` | ➖ |

**Differences:**

- ❌ **low** — `modelNamed` returns `false` for an empty name before the lookup. Upstream returned NO only for `nil`, so `model = ""` went through `fileExists:` with `checkBuiltIn:YES` (ResourceManager lookup of the `Models` folder itself). Port goes straight to shipdata's "model "" could not be found" warning (still open) — upstream `Core/OXPVerifier/OOModelVerifierStage.m:132` ↔ port `Core/OXPVerifier/OOModelVerifierStage.cpp:74`
- ❌ **low** — models are checked in insertion order (de-duplicated vector), not `NSSet` hash order; only the verbose "Pretending to verify model" lines move (still open) — upstream `:97` ↔ port `:59`

## OOOXPVerifier

<a id="oooxpverifier"></a>
Upstream `src/Core/OXPVerifier/OOOXPVerifier.m` ↔ `Core/OXPVerifier/OOOXPVerifier.cpp` (690 / 824 lines)

**Status:** done — 23 rows: 15 ✅ 3 ⚠️ 4 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOOXPVerifier runVerificationIfRequested]` (95) | `runVerificationIfRequested` `Core/OXPVerifier/OOOXPVerifier.cpp:171` (+ `ExpandTildeInPath` :97) | ⚠️ |
| `-[OOOXPVerifier dealloc]` (147) | members (`std::shared_ptr`) | ➖ |
| `-[OOOXPVerifier registerStage:]` (158) | `registerStage` `…/OOOXPVerifier.cpp:223` | ⚠️ |
| `-[OOOXPVerifier oxpPath]` (198) | `oxpPath` `…/OOOXPVerifier.cpp:270` | ✅ |
| `-[OOOXPVerifier oxpDisplayName]` (203) | `oxpDisplayName` `…/OOOXPVerifier.cpp:272` | ✅ |
| `-[OOOXPVerifier stageWithName:]` (208) | `stageWithName` `…/OOOXPVerifier.cpp:276` | ✅ |
| `-[OOOXPVerifier configurationValueForKey:]` (216) | `configurationValueForKey` `…/OOOXPVerifier.cpp:281` | ✅ |
| `-[OOOXPVerifier configurationArrayForKey:]` (221) | `configurationArrayForKey` `…/OOOXPVerifier.cpp:286` | ✅ |
| `-[OOOXPVerifier configurationDictionaryForKey:]` (226) | `configurationDictionaryForKey` `…/OOOXPVerifier.cpp:291` | ✅ |
| `-[OOOXPVerifier configurationStringForKey:]` (231) | `configurationStringForKey` `…/OOOXPVerifier.cpp:296` (string or number) | ✅ |
| `-[OOOXPVerifier configurationSetForKey:]` (236) | `configurationSetForKey` `…/OOOXPVerifier.cpp:304` | ❌ |
| `-[OOOXPVerifier(OOPrivate) initWithPath:]` (246) | `createWithPath` :319 / `initWithPath` `…/OOOXPVerifier.cpp:327` | ⚠️ |
| `-[OOOXPVerifier(OOPrivate) run]` (275) | `run` `…/OOOXPVerifier.cpp:362` (same sequence: note, overrides, cache flush/no writes, no add-ons, switch log, stages, done, open log) | ✅ |
| `-[OOOXPVerifier(OOPrivate) setUpLogOverrides]` (305) | `setUpLogOverrides` `…/OOOXPVerifier.cpp:392` | ✅ |
| `-[OOOXPVerifier(OOPrivate) registerBaseStages]` (328) | `registerBaseStages` `…/OOOXPVerifier.cpp:418` (+ `kCxxStages` :124, `sTestStageMaker` :161) | ❌ |
| `-[OOOXPVerifier(OOPrivate) buildDependencyGraph]` (362) | `buildDependencyGraph` `…/OOOXPVerifier.cpp:462` | ❌ |
| `-[OOOXPVerifier(OOPrivate) runStages]` (467) | `runStages` `…/OOOXPVerifier.cpp:564` | ❌ |
| `-[OOOXPVerifier(OOPrivate) setUpDependencies:forStage:]` (533) | `setUpDependencies` `…/OOOXPVerifier.cpp:630` | ✅ |
| `-[OOOXPVerifier(OOPrivate) setUpDependents:forStage:]` (559) | `setUpDependents` `…/OOOXPVerifier.cpp:658` | ✅ |
| `-[OOOXPVerifier(OOPrivate) dumpDebugGraphviz]` (582) | `dumpDebugGraphviz` `…/OOOXPVerifier.cpp:685` (writes `OXPVerifierStageDependencies.dot` to the diagnostic location itself) | ✅ |
| `SwitchLogFile` (648) | `SwitchLogFile` `…/OOOXPVerifier.cpp:772` | ✅ |
| `NoteVerificationStage` (660) | `NoteVerificationStage` `…/OOOXPVerifier.cpp:784` | ✅ |
| `OpenLogFile` (665) | `OpenLogFile` `…/OOOXPVerifier.cpp:790` (Windows ShellExecute / Linux `cat`; the Mac Cocoa branch is gone with the dead Cocoa code) | ✅ |

**Differences:**

- ❌ **low** — stage execution order: upstream picked the first runnable stage from an `NSMutableSet` (pointer-hash order); the port's `_waitingStages` is filled from the `std::map` `_stagesByName`, so runnable stages run in byte order of their names, and the "could not be run" list too. Whole log sections come out in a different (now deterministic) order (still open) — upstream `Core/OXPVerifier/OOOXPVerifier.m:389,413,441,457,480,522` ↔ port `Core/OXPVerifier/OOOXPVerifier.cpp:505,537,552-553,572,622`
- ❌ **low** — `configurationSetForKey` returns a sorted vector of only the string elements, not an `NSSet` of everything; membership is unchanged for callers, but `registerBaseStages` registers (and logs "unknown class") in sorted order (still open) — upstream `:236-240,340-346` ↔ port `:304-315,421-432`
- ⚠️ **low** — `registerBaseStages` resolves names only through `kCxxStages` (plus a test hook); a non-stage ObjC class name used to log "…is not a subclass of OOOXPVerifierStage", now "unknown class". Comments at `:230-232,452-453` (still open) — upstream `:167-170,348-355` ↔ port `:433-457`
- ⚠️ **low** — `_displayName` is always `lastPathComponent` (comment `:348-349`, GNUstep's `-displayNameAtPath:`); feeds the log file name and "Verifying %@" (still open) — upstream `:256-258` ↔ port `:348`
- ⚠️ **low** — `-stringByExpandingTildeInPath` is reimplemented (comment `:89-96`): `~user` not expanded, separators normalised to `/` and empty components dropped (still open) — upstream `:118` ↔ port `:97-112,190`
- Subtle: `runStages`/`performRun` catch only `OOException` and rethrow anything else (`:601-603`); upstream's `@catch (NSException*)` logged any Foundation exception and carried on. `buildDependencyGraph` takes waiting stages FIFO instead of `-anyObject`.

## OOOXPVerifierStage

<a id="oooxpverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOOXPVerifierStage.m` ↔ `Core/OXPVerifier/OOOXPVerifierStage.cpp` (211 / 212 lines)

**Status:** done — 21 rows: 18 ✅ 1 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOOXPVerifierStage init]` (43) | member defaults (`_canRun = false`, empty vectors) — `Core/OXPVerifier/OOOXPVerifierStage.h` | ➖ |
| `-[OOOXPVerifierStage dealloc]` (57) | members | ➖ |
| `-[OOOXPVerifierStage description]` (66) | `description` `Core/OXPVerifier/OOOXPVerifierStage.cpp:69` (+ `descriptionComponents` :62, `className` :76): `<Class 0x…>{"name"}` | ✅ |
| `-[OOOXPVerifierStage verifier]` (71) | `verifier` `…/OOOXPVerifierStage.cpp:84` (borrowed) | ✅ |
| `-[OOOXPVerifierStage completed]` (76) | `completed` `…/OOOXPVerifierStage.cpp:86` | ✅ |
| `-[OOOXPVerifierStage name]` (81) | `name` `…/OOOXPVerifierStage.cpp:88` | ✅ |
| `-[OOOXPVerifierStage dependencies]` (87) | `dependencies` `…/OOOXPVerifierStage.cpp:93` | ✅ |
| `-[OOOXPVerifierStage dependents]` (92) | `dependents` `…/OOOXPVerifierStage.cpp:97` | ✅ |
| `-[OOOXPVerifierStage shouldRun]` (97) | `shouldRun` `…/OOOXPVerifierStage.cpp:101` | ✅ |
| `-[OOOXPVerifierStage run]` (102) | `run` `…/OOOXPVerifierStage.cpp:103` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) setVerifier:]` (111) | `setVerifier` `…/OOOXPVerifierStage.cpp:107` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) isDependentOf:]` (116) | `isDependentOf` `…/OOOXPVerifierStage.cpp:111` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) registerDependency:]` (136) | `registerDependency` `…/OOOXPVerifierStage.cpp:128` (+ `AddStage` :48) | ✅ |
| `-[OOOXPVerifierStage(OOInternal) canRun]` (144) | `canRun` `…/OOOXPVerifierStage.cpp:135` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) performRun]` (149) | `performRun` `…/OOOXPVerifierStage.cpp:137` | ⚠️ |
| `-[OOOXPVerifierStage(OOInternal) noteSkipped]` (167) | `noteSkipped` `…/OOOXPVerifierStage.cpp:163` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) dependencyRegistrationComplete]` (176) | `dependencyRegistrationComplete` `…/OOOXPVerifierStage.cpp:171` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) resolvedDependencies]` (181) | `resolvedDependencies` `…/OOOXPVerifierStage.cpp:176` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) resolvedDependents]` (186) | `resolvedDependents` `…/OOOXPVerifierStage.cpp:181` | ✅ |
| `-[OOOXPVerifierStage(OOPrivate) registerDepedent:]` (195) | `registerDepedent` `…/OOOXPVerifierStage.cpp:187` | ✅ |
| `-[OOOXPVerifierStage(OOPrivate) dependencyCompleted:]` (202) | `dependencyCompleted` `…/OOOXPVerifierStage.cpp:193` (+ `notifyDependents` :204) | ✅ |

**Differences:**

- ⚠️ **low** — the exception line in `performRun` spells out GNUstep's `%@`-of-exception layout as `<OOException: 0x…> NAME:… REASON:…` (comment `:146-148`); upstream printed `<NSException: 0x…> …`, so the class name in the `verifyOXP.exception` text differs. Non-`OOException` exceptions are rethrown (`:145`) (still open) — upstream `Core/OXPVerifier/OOOXPVerifierStage.m:154-159` ↔ port `Core/OXPVerifier/OOOXPVerifierStage.cpp:141-155`
- Subtle (✅): dependency/dependent sets are vectors in registration order, not `NSMutableSet` hash order; `dependencyCompleted` only removes an entry, so notification order has no effect, only the graphviz arc order changes.

## OOPListSchemaVerifier

<a id="ooplistschemaverifier"></a>
Upstream `src/Core/OXPVerifier/OOPListSchemaVerifier.m` ↔ `Core/OXPVerifier/OOPListSchemaVerifier.cpp` (1393 / 1707 lines)

**Status:** done — 51 rows: 39 ✅ 5 ⚠️ 1 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| error domain / userInfo key constants (97–111) *(added row)* | constants `Core/OXPVerifier/OOPListSchemaVerifier.cpp:109-136` (same strings; + `kUnderlyingErrorErrorKey` = `"NSUnderlyingError"`) | ✅ |
| `BackLink` (137) | `BackLink` `…/OOPListSchemaVerifier.cpp:169` | ✅ |
| `BackLinkIndex` (143) | `BackLinkIndex` `…/OOPListSchemaVerifier.cpp:174` | ✅ |
| `BackLinkRoot` (149) | `BackLinkRoot` `…/OOPListSchemaVerifier.cpp:179` | ✅ |
| `+[OOPListSchemaVerifier verifierWithSchema:]` (229) | `verifierWithSchema` `…/OOPListSchemaVerifier.cpp:296` | ✅ |
| `-[OOPListSchemaVerifier initWithSchema:]` (234) | ctor :300 + `initWithSchema` `…/OOPListSchemaVerifier.cpp:312` (null schema → nullptr) | ✅ |
| `-[OOPListSchemaVerifier dealloc]` (253) | members | ➖ |
| `-[OOPListSchemaVerifier setDelegate:]` (261) | `setDelegate` `…/OOPListSchemaVerifier.cpp:324` | ✅ |
| `-[OOPListSchemaVerifier delegate]` (269) | `delegate` `…/OOPListSchemaVerifier.cpp:332` | ✅ |
| `-[OOPListSchemaVerifier verifyPropertyList:named:]` (274) | `verifyPropertyList` `…/OOPListSchemaVerifier.cpp:336` | ✅ |
| `+[OOPListSchemaVerifier descriptionForKeyPath:]` (291) | `descriptionForKeyPath` `…/OOPListSchemaVerifier.cpp:347` (`[n]` for numbers, `.` joins, "root" for empty, nil for other kinds) | ✅ |
| `-[OOPListSchemaVerifier(OOPrivate) delegateVerifierWithPropertyList:named:testProperty:atPath:againstType:error:]` (323) | `delegateVerifierWithPropertyList` (testProperty) `…/OOPListSchemaVerifier.cpp:374` | ⚠️ |
| `-[OOPListSchemaVerifier(OOPrivate) delegateVerifierWithPropertyList:named:failedForProperty:withError:expectedType:]` (367) | `delegateVerifierWithPropertyList` (failed) `…/OOPListSchemaVerifier.cpp:428` (+ `KeyPathDescriptionOfError` :246) | ⚠️ |
| `-[OOPListSchemaVerifier(OOPrivate) verifyPList:named:subProperty:againstSchemaType:atPath:tentative:error:stop:]` (395) | `verifyPList` `…/OOPListSchemaVerifier.cpp:460` | ⚠️ |
| `-[OOPListSchemaVerifier(OOPrivate) resolveSchemaType:atPath:error:]` (476) | `resolveSchemaType` `…/OOPListSchemaVerifier.cpp:534` | ❌ |
| `StringToSchemaType` (525) | `StringToSchemaType` `…/OOPListSchemaVerifier.cpp:589` (same 14 names, same two error texts) | ✅ |
| `ApplyStringFilter` (562) | `ApplyStringFilter` `…/OOPListSchemaVerifier.cpp:663` (+ `FindSubString` :633, `SubstringToIndex` :652) | ✅ |
| `ApplyStringTest` (623) | `ApplyStringTest` `…/OOPListSchemaVerifier.cpp:751` | ✅ |
| `KeyPathToArray` (660) | `KeyPathToArray` `…/OOPListSchemaVerifier.cpp:790` | ✅ |
| `KeyPathToString` (674) | `KeyPathToString` `…/OOPListSchemaVerifier.cpp:806` | ✅ |
| `StringForErrorReport` (679) | `StringForErrorReport` `…/OOPListSchemaVerifier.cpp:815` (replacement range limited to original length, as upstream) | ✅ |
| `ArrayForErrorReport` (700) | `ArrayForErrorReport` `…/OOPListSchemaVerifier.cpp:857` (+ `ElementDescription` :851) | ✅ |
| `SetForErrorReport` (731) | `SetForErrorReport` `…/OOPListSchemaVerifier.cpp:882` | ✅ |
| `StringOrArrayForErrorReport` (736) | `StringOrArrayForErrorReport` `…/OOPListSchemaVerifier.cpp:896` (no set branch: plists have no sets) | ✅ |
| `Verify_String` (764) | `Verify_String` `…/OOPListSchemaVerifier.cpp:924` | ✅ |
| `Verify_Array` (825) | `Verify_Array` `…/OOPListSchemaVerifier.cpp:1026` | ✅ |
| `Verify_Dictionary` (879) | `Verify_Dictionary` `…/OOPListSchemaVerifier.cpp:1083` | ⚠️ |
| `Verify_Integer` (983) | `Verify_Integer` `…/OOPListSchemaVerifier.cpp:1205` | ✅ |
| `Verify_PositiveInteger` (1011) | `Verify_PositiveInteger` `…/OOPListSchemaVerifier.cpp:1246` | ✅ |
| `Verify_Float` (1039) | `Verify_Float` `…/OOPListSchemaVerifier.cpp:1286` | ✅ |
| `Verify_PositiveFloat` (1067) | `Verify_PositiveFloat` `…/OOPListSchemaVerifier.cpp:1327` | ✅ |
| `Verify_OneOf` (1099) | `Verify_OneOf` `…/OOPListSchemaVerifier.cpp:1373` | ✅ |
| `Verify_Enumeration` (1143) | `Verify_Enumeration` `…/OOPListSchemaVerifier.cpp:1421` | ✅ |
| `Verify_Boolean` (1171) | `Verify_Boolean` `…/OOPListSchemaVerifier.cpp:1467` | ✅ |
| `Verify_FuzzyBoolean` (1182) | `Verify_FuzzyBoolean` `…/OOPListSchemaVerifier.cpp:1487` | ✅ |
| `Verify_Vector` (1195) | `Verify_Vector` `…/OOPListSchemaVerifier.cpp:1509` | ✅ |
| `Verify_Quaternion` (1206) | `Verify_Quaternion` `…/OOPListSchemaVerifier.cpp:1530` | ✅ |
| `Verify_DelegatedType` (1217) | `Verify_DelegatedType` `…/OOPListSchemaVerifier.cpp:1551` | ✅ |
| `-[NSString(OOPListSchemaVerifierHelpers) ooPListVerifierHasSubString:]` (1253) | `HasSubString` `…/OOPListSchemaVerifier.cpp:644` | ✅ |
| `-[NSError(OOPListSchemaVerifierConveniences) plistKeyPath]` (1262) | inlined `error.userInfo.find(kPListKeyPathErrorKey)` (`:248`, `OOCheckShipDataPListVerifierStage.cpp:387-388`) | ➖ |
| `-[NSError(OOPListSchemaVerifierConveniences) plistKeyPathDescription]` (1267) | `KeyPathDescriptionOfError` `…/OOPListSchemaVerifier.cpp:246` | ➖ |
| `-[NSError(OOPListSchemaVerifierConveniences) missingRequiredKeys]` (1272) | gone (no callers) | ➖ |
| `-[NSError(OOPListSchemaVerifierConveniences) expectedClass]` (1277) | gone; `kExpectedClassErrorKey` no longer recorded (comment `:1652-1654`) | ➖ |
| `-[NSError(OOPListSchemaVerifierConveniences) expectedClassName]` (1282) | gone (the `kExpectedClassNameErrorKey` value is still recorded, `:1655`) | ➖ |
| `Error` (1292) | `Error` `…/OOPListSchemaVerifier.cpp:1583` | ✅ |
| `ErrorWithProperty` (1304) | `ErrorWithProperty` `…/OOPListSchemaVerifier.cpp:1597` | ✅ |
| `ErrorWithDictionary` (1320) | `ErrorWithDictionary` `…/OOPListSchemaVerifier.cpp:1616` | ✅ |
| `ErrorWithDictionaryAndArguments` (1332) | `ErrorWithDictionaryAndArguments` `…/OOPListSchemaVerifier.cpp:1630` (failure reason in a field, key path in userInfo) | ✅ |
| `ErrorTypeMismatch` (1350) | `ErrorTypeMismatch` `…/OOPListSchemaVerifier.cpp:1646` | ⚠️ |
| `ErrorFailureAlreadyReported` (1383) | `ErrorFailureAlreadyReported` `…/OOPListSchemaVerifier.cpp:1692` | ✅ |
| `IsFailureAlreadyReportedError` (1388) | `IsFailureAlreadyReportedError` `…/OOPListSchemaVerifier.cpp:1699` | ✅ |

**Differences:**

- ⚠️ **low** — `Verify_Dictionary` visits members in byte order of the key, not `-keyEnumerator` hash order (comment `:1137-1138`); "Unpermitted key", type-mismatch and nested errors reach the delegate in a different order, and with `stop` or tentative mode which errors are reported before the early exit can differ (still open) — upstream `Core/OXPVerifier/OOPListSchemaVerifier.m:925-966` ↔ port `Core/OXPVerifier/OOPListSchemaVerifier.cpp:1139-1177`
- ❌ **low** — `resolveSchemaType` with a `$macro` whose definition is neither a string nor a dictionary: upstream sent `objectForKey:` to it and the exception became `kPListErrorInternal` "Uncaught exception … in plist verifier"; the port reports `kSchemaBadTypeSpecifier` "… (no type specified)". Only a broken built-in schema triggers it (still open) — upstream `:488-496` ↔ port `:543-572`
- ⚠️ **low** — the delegate is a C++ interface answering both callbacks; the `respondsToSelector:` fallbacks ("delegate does not handle delegated types" / `plistVerifier.failed`) fire only with no delegate at all (comment `:381-382`) (still open) — upstream `:333,375` ↔ port `:383,434`
- ⚠️ **low** — `verifyPList` and the delegate wrappers catch only `OOException` and rethrow anything else (`:388-390,439-441,509-511`); `SubstringToIndex` past the end raises `OORangeException` with GNUstep's reason (`:652-661`), so the `truncFront:`/`truncBack:` path still becomes "Uncaught exception …" (still open)
- ⚠️ **low** — `ErrorTypeMismatch` no longer stores `kExpectedClassErrorKey` (comment `:1652-1654`); "Expected %@, found %@." text and kind names unchanged, a PList bool counts as "number" (still open) — upstream `:1350-1381` ↔ port `:1646-1690`
- Subtle (✅): check order in `verifyPList` (resolve, map type, dispatch, report only if `!tentative && !alreadyReported`) is unchanged. `Verify_String` keeps upstream's quirk that a bad `filter` error surfaces only via a later failing prefix/suffix/substring test; lengths count UTF-16 units. `Verify_DelegatedType` still returns success when `baseType` fails. "too manu pairs" typo and the oneOf message for enumerations are kept. `%@` of the delegated type key uses `DescriptionOf`, which prints a top-level string as itself (`oofnd/PListDescription.hpp:8-11`).
- Subtle: non-string `requiredKeys` entries are dropped (`:1128-1132`); upstream kept them, so they were never removed and the missing-keys report then hit `caseInsensitiveCompare:` on a number. Bad-schema only.

## OOTextureVerifierStage

<a id="ootextureverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOTextureVerifierStage.m` ↔ `Core/OXPVerifier/OOTextureVerifierStage.cpp` (187 / 162 lines)

**Status:** done — 10 rows: 5 ✅ 0 ⚠️ 2 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOTextureVerifierStage init]` (44) | member init (`_usedTextures` sorted vector) — `Core/OXPVerifier/OOTextureVerifierStage.h` | ➖ |
| `-[OOTextureVerifierStage dealloc]` (53) | members | ➖ |
| `+[OOTextureVerifierStage nameForReverseDependencyForVerifier:]` (60) | `nameForReverseDependencyForVerifier` `Core/OXPVerifier/OOTextureVerifierStage.cpp:37` (no registration, as upstream) | ✅ |
| `-[OOTextureVerifierStage name]` (65) | `name` `…/OOTextureVerifierStage.cpp:42` | ✅ |
| `-[OOTextureVerifierStage shouldRun]` (70) | `shouldRun` `…/OOTextureVerifierStage.cpp:44` | ✅ |
| `-[OOTextureVerifierStage run]` (75) | `run` `…/OOTextureVerifierStage.cpp:53` | ❌ |
| `-[OOTextureVerifierStage textureNamed:usedInContext:]` (96) | `textureNamed` `…/OOTextureVerifierStage.cpp:73` | ❌ |
| `-[OOTextureVerifierStage(OOPrivate) checkTextureNamed:inFolder:]` (119) | `checkTextureNamed` `…/OOTextureVerifierStage.cpp:94` (same loader flags incl. duplicated MinFilterNearest, `(2*w)/3` POT rounding, texts) | ✅ |
| `-[OOTextureHandlingStage dependents]` (169) | `OOTextureHandlingStage::dependents` `…/OOTextureVerifierStage.cpp:151` | ✅ |
| `-[OOOXPVerifier(OOTextureVerifierStage) textureVerifierStage]` (180) | removed; callers use `stageWithName` | ➖ |

**Differences:**

- ❌ **low** — used textures are checked in byte order (sorted vector), not `NSSet` hash order, and `Images/` files in `filesInFolder`'s byte order, so the `notPOT`/`failed`/`OK` lines come out in a different order (still open) — upstream `Core/OXPVerifier/OOTextureVerifierStage.m:81,90-92` ↔ port `Core/OXPVerifier/OOTextureVerifierStage.cpp:54,67`
- ❌ **low** — `textureNamed` silently ignores an empty name; upstream ignored only `nil`, so `""` was recorded and looked up with `checkBuiltIn:YES` (still open) — upstream `:100` ↔ port `:77`

