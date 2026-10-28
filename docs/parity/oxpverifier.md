# Parity findings: OXP verifier

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## OOAIStateMachineVerifierStage

<a id="ooaistatemachineverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOAIStateMachineVerifierStage.m` ↔ `Core/OXPVerifier/OOAIStateMachineVerifierStage.cpp`

**Status:** done — 7 rows: 5 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOAIStateMachineVerifierStage dealloc]` (44) | members (`_whitelist`, `_usedAIs` vectors) — `Core/OXPVerifier/OOAIStateMachineVerifierStage.h` | ➖ |
| `-[OOAIStateMachineVerifierStage name]` (52) | `name` `Core/OXPVerifier/OOAIStateMachineVerifierStage.cpp:74` | ✅ |
| `-[OOAIStateMachineVerifierStage shouldRun]` (57) | `shouldRun` `…/OOAIStateMachineVerifierStage.cpp:79` | ✅ |
| `-[OOAIStateMachineVerifierStage run]` (62) | `run` `…/OOAIStateMachineVerifierStage.cpp:84` | ✅ |
| `+[OOAIStateMachineVerifierStage nameForReverseDependencyForVerifier:]` (85) | `nameForReverseDependencyForVerifier` `…/OOAIStateMachineVerifierStage.cpp:108` | ✅ |
| `-[OOAIStateMachineVerifierStage stateMachineNamed:usedByShip:]` (90) | `stateMachineNamed` `…/OOAIStateMachineVerifierStage.cpp:113` | ✅ |
| `-[OOAIStateMachineVerifierStage(Private) validateAI:]` (115) | `validateAI` `…/OOAIStateMachineVerifierStage.cpp:126` | ❌ |

**Differences:**

- ❌ **low** — states and handlers are walked in `std::map` byte order instead of `NSDictionary` hash order, so the `invalidFormat.state`/`.handler`/`.action` errors come out in a different order. Not commented in the port — upstream `Core/OXPVerifier/OOAIStateMachineVerifierStage.m:147,156` ↔ port `Core/OXPVerifier/OOAIStateMachineVerifierStage.cpp:150,157`
- ⚠️ **low** — an AI file that parses but is not a dictionary no longer logs `plist.wrongType` ("Property list is wrong type - expected …") before `verifyOXP.validateAI.failed.notDictPlist`. The port comment says this line is dropped on purpose — upstream `Core/OOPListParsing.m:207-232` via `Core/OXPVerifier/OOAIStateMachineVerifierStage.m:140` ↔ port `Core/OXPVerifier/OOAIStateMachineVerifierStage.cpp:40-47,143`
- Subtle (same on both sides): the early returns in `validateAI` (missing path, not a dictionary) skip `OOLogOutdentIf`. The indent imbalance is kept. The whitelist keeps only string elements; upstream added any object, but only strings are ever looked up.


## OOCheckDemoShipsPListVerifierStage

<a id="oocheckdemoshipsplistverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.cpp`

**Status:** done — 4 rows: 4 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckDemoShipsPListVerifierStage name]` (42) | `name` `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.cpp:34` | ✅ |
| `-[OOCheckDemoShipsPListVerifierStage shouldRun]` (47) | `shouldRun` `…/OOCheckDemoShipsPListVerifierStage.cpp:39` | ✅ |
| `-[OOCheckDemoShipsPListVerifierStage run]` (58) | `run` `…/OOCheckDemoShipsPListVerifierStage.cpp:47` | ✅ |
| `-[OOCheckDemoShipsPListVerifierStage(OOPrivate) runCheckWithDemoShips:shipData:]` (101) | `runCheckWithDemoShips` `…/OOCheckDemoShipsPListVerifierStage.cpp:82` | ✅ |

**Differences:**

- None. The null-scanner guards (`fileScanner == nullptr`) reproduce nil-messaging (`NO`/`nil`). A non-string demoships entry still gives the `unknownShip` warning and prints the entry's description, as upstream's `objectForKey:` miss did.


## OOCheckEquipmentPListVerifierStage

<a id="oocheckequipmentplistverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.cpp`

**Status:** done — 4 rows: 4 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckEquipmentPListVerifierStage name]` (44) | `name` `Core/OXPVerifier/OOCheckEquipmentPListVerifierStage.cpp:51` | ✅ |
| `-[OOCheckEquipmentPListVerifierStage shouldRun]` (49) | `shouldRun` `…/OOCheckEquipmentPListVerifierStage.cpp:56` | ✅ |
| `-[OOCheckEquipmentPListVerifierStage run]` (60) | `run` `…/OOCheckEquipmentPListVerifierStage.cpp:64` | ✅ |
| `-[OOCheckEquipmentPListVerifierStage(OOPrivate) runCheckWithEquipment:]` (88) | `runCheckWithEquipment` `…/OOCheckEquipmentPListVerifierStage.cpp:86` (+ `StringAt` :41 for `oo_stringAtIndex:`) | ✅ |

**Differences:**

- None. The constants, check order, message texts and the `5 < elemCount` extra-info check all match. `oo_longAtIndex:defaultValue:-1` maps to `at<long>(i, -1)`, and `oo_stringAtIndex:` (a string, or a number's string value) maps to `StringAt`.


## OOCheckJSSyntaxVerifierStage

<a id="oocheckjssyntaxverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.cpp`

**Status:** done — 3 rows: 2 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckJSSyntaxVerifierStage name]` (40) | `name` `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.cpp:49` | ✅ |
| `-[OOCheckJSSyntaxVerifierStage shouldRun]` (45) | `shouldRun` `…/OOCheckJSSyntaxVerifierStage.cpp:54` | ✅ |
| `-[OOCheckJSSyntaxVerifierStage run]` (53) | `run` `…/OOCheckJSSyntaxVerifierStage.cpp:64` → `OOJSScript::scriptWithPath` `Core/Scripting/OOJSScript.cpp:200` | ⚠️ |

**Differences:**

- ⚠️ **med** — the stage logic is the same, but the script engine is not. Each `.js`/`.es` file is loaded with `OOJSScript::scriptWithPath`, which compiles **and runs** it (`LoadScriptWithName` + `executeScript`), now on QuickJS-ng instead of SpiderMonkey 1.8.5 (`Core/Scripting/ooscript/README.md`, ADR-0002, bead oo-7wx). SpiderMonkey-only syntax (`for each`, E4X, expression closures, `catch (e if …)`, old-style `let` blocks) now fails to compile. ES2015+ syntax that 1.8.5 rejected now passes. Error text and locations differ too (frames are file/line only, ADR-0022). The same OXP can get a different verdict and different log text — upstream `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.m:76,83`, `Core/Scripting/OOJSScript.m:643-690` ↔ port `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.cpp:86,91`, `Core/Scripting/OOJSScript.cpp:759-820`
- ❌ **low** — the scripts in `Scripts/` are checked in byte order of their lowercased names (`filesInFolder` iterates a `std::map`), not in `-allValues` hash order, so per-script errors are logged in a different order — upstream `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.m:63,71` ↔ port `Core/OXPVerifier/OOCheckJSSyntaxVerifierStage.cpp:75,83`, `Core/OXPVerifier/OOFileScannerVerifierStage.cpp:272-284`. (Counted under OOFileScannerVerifierStage `filesInFolder`.)
- Subtle: the `"use strict"` deprecation check and its prepend are the same, under `OO_DEBUG_MONITOR_ENABLED`. Cache writes are disabled by the verifier in both, so neither run writes compiled scripts to the cache.


## OOCheckPListSyntaxVerifierStage

<a id="oocheckplistsyntaxverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.cpp`

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckPListSyntaxVerifierStage name]` (37) | `name` `Core/OXPVerifier/OOCheckPListSyntaxVerifierStage.cpp:56` | ✅ |
| `-[OOCheckPListSyntaxVerifierStage shouldRun]` (42) | `shouldRun` `…/OOCheckPListSyntaxVerifierStage.cpp:61` | ✅ |
| `-[OOCheckPListSyntaxVerifierStage run]` (47) | `run` `…/OOCheckPListSyntaxVerifierStage.cpp:66` | ✅ |

**Differences:**

- None. Upstream's copy-paste bug is kept: a dictionary plist missing from `ConfigDictionaries` still logs "should be an array but isn't." (upstream `:79` ↔ port `:92`). The `knownFiles` arrays are read in plist order on both sides, and only their string elements are used.


## OOCheckRequiresPListVerifierStage

<a id="oocheckrequiresplistverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckRequiresPListVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.cpp`

**Status:** done — 3 rows: 2 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckRequiresPListVerifierStage name]` (37) | `name` `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.cpp:75` | ✅ |
| `-[OOCheckRequiresPListVerifierStage shouldRun]` (42) | `shouldRun` `…/OOCheckRequiresPListVerifierStage.cpp:80` | ✅ |
| `-[OOCheckRequiresPListVerifierStage run]` (53) | `run` `…/OOCheckRequiresPListVerifierStage.cpp:88` (+ `VersionStringForKey` :43, `OoliteInfoString` :59) | ❌ |

**Differences:**

- ❌ **low** — the unknown-keys list is joined in `PList::Dict` byte order, not `NSSet -allObjects` hash order. With two or more unknown keys the `verifyOXP.requiresPList.unknownKeys` text differs — upstream `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.m:81-87` ↔ port `Core/OXPVerifier/OOCheckRequiresPListVerifierStage.cpp:114-125`
- Subtle: Oolite's own version now comes from reading `Info-gnustep.plist` in the built-in resources folder, where upstream used `[[NSBundle mainBundle] infoDictionary]`. This is equivalent on a GNUstep layout; it would differ on macOS (`Info.plist`) — upstream `:108` ↔ port `:59-71,133`. The version-compare checks and their order (newer, then older, then range) are the same.


## OOCheckShipDataPListVerifierStage

<a id="oocheckshipdataplistverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOCheckShipDataPListVerifierStage.m` ↔ `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp`

**Status:** done — 14 rows: 12 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCheckShipDataPListVerifierStage name]` (58) | `name` `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp:87` | ✅ |
| `-[OOCheckShipDataPListVerifierStage dependents]` (63) | `dependents` `…/OOCheckShipDataPListVerifierStage.cpp:92` | ✅ |
| `-[OOCheckShipDataPListVerifierStage shouldRun]` (71) | `shouldRun` `…/OOCheckShipDataPListVerifierStage.cpp:103` | ✅ |
| `-[OOCheckShipDataPListVerifierStage run]` (82) | `run` `…/OOCheckShipDataPListVerifierStage.cpp:111` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) verifyShipInfo:withName:]` (163) | `verifyShipInfo` `…/OOCheckShipDataPListVerifierStage.cpp:188` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) message:]` (194) | `reportMessage` `…/OOCheckShipDataPListVerifierStage.cpp:220` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) verboseMessage:]` (209) | `verboseMessage` `…/OOCheckShipDataPListVerifierStage.cpp:233` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) getRoles]` (227) | `getRoles` `…/OOCheckShipDataPListVerifierStage.cpp:247` | ❌ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) checkKeys]` (249) | `checkKeys` `…/OOCheckShipDataPListVerifierStage.cpp:268` | ❌ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) checkSchema]` (277) | `checkSchema` `…/OOCheckShipDataPListVerifierStage.cpp:294` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) checkModel]` (282) | `checkModel` `…/OOCheckShipDataPListVerifierStage.cpp:300` | ✅ |
| `-[OOCheckShipDataPListVerifierStage(OOPrivate) rolesFromString:]` (308) | `rolesFromString` `…/OOCheckShipDataPListVerifierStage.cpp:320` | ✅ |
| `-[… verifier:withPropertyList:named:testProperty:atPath:againstType:error:]` (337) | `verifierTestProperty` `…/OOCheckShipDataPListVerifierStage.cpp:335` | ✅ |
| `-[… verifier:withPropertyList:named:failedForProperty:withError:expectedType:]` (349) | `verifierFailedForProperty` `…/OOCheckShipDataPListVerifierStage.cpp:347` | ✅ |

**Differences:**

- ❌ **low** — a ship's keys are walked in `PList::Dict` byte order, not `-keyEnumerator` hash order, so the "unknown key" / "does not apply to this category" warnings are logged in a different order. The schema pass has the same reordering (see OOPListSchemaVerifier `Verify_Dictionary`) — upstream `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.m:262` ↔ port `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp:279`
- ❌ **low** — a `roles` value that is not a string (number or array) is now treated as absent: no roles, and `_isStation` is set by the nil rule below. Upstream sent string messages to it (`ScanTokensFromString`, `-rangeOfString:`), which gave either an exception (caught by `performRun`, ending the stage) or meaningless roles — upstream `:231-239,319` ↔ port `:251-258`
- Kept quirk (✅): a ship with **no** `roles` counts as a station, because upstream's `[nil rangeOfString:]` returns `{0,0}`, i.e. "found". The port reproduces this on purpose (`!rolesString.has_value()`, commented at `:257`).
- Subtle: the ship list sort is now stable (`std::stable_sort`) where upstream's was unstable. They differ only for keys that compare equal case-insensitively. `message:`'s display check is the same as `OOLogWithFunctionFileAndLineAndArguments`'s internal `OOLogWillDisplayMessagesInClass` check (`Core/OOLogging.m:394`).


## OOFileScannerVerifierStage

<a id="oofilescannerverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOFileScannerVerifierStage.m` ↔ `Core/OXPVerifier/OOFileScannerVerifierStage.cpp`

**Status:** done — 26 rows: 20 ✅ 1 ⚠️ 3 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOFileScannerVerifierStage dealloc]` (83) | members — `Core/OXPVerifier/OOFileScannerVerifierStage.h` | ➖ |
| `-[OOFileScannerVerifierStage name]` (95) | `name` `Core/OXPVerifier/OOFileScannerVerifierStage.cpp:88` | ✅ |
| `-[OOFileScannerVerifierStage run]` (100) | `run` `…/OOFileScannerVerifierStage.cpp:93` | ✅ |
| `+[OOFileScannerVerifierStage nameForDependencyForVerifier:]` (118) | `nameForDependencyForVerifier` `…/OOFileScannerVerifierStage.cpp:111` | ✅ |
| `-[OOFileScannerVerifierStage fileExists:]` (130) | `fileExists` `…/OOFileScannerVerifierStage.cpp:122` | ✅ |
| `-[OOFileScannerVerifierStage pathForFile:]` (138) | `pathForFile` `…/OOFileScannerVerifierStage.cpp:127` (+ `realNameOf` :288) | ✅ |
| `-[OOFileScannerVerifierStage dataForFile:]` (209) | `dataForFile` `…/OOFileScannerVerifierStage.cpp:199` | ✅ |
| `-[OOFileScannerVerifierStage plistNamed:]` (223) | `plistNamed` `…/OOFileScannerVerifierStage.cpp:209` | ✅ |
| `-[OOFileScannerVerifierStage displayNameForFile:andFolder:]` (283) | `displayNameForFile` `…/OOFileScannerVerifierStage.cpp:265` | ✅ |
| `-[OOFileScannerVerifierStage filesInFolder:]` (290) | `filesInFolder` `…/OOFileScannerVerifierStage.cpp:272` | ❌ |
| `-[OOFileScannerVerifierStage(OOPrivate) scanForFiles]` (301) | `scanForFiles` `…/OOFileScannerVerifierStage.cpp:299` | ❌ |
| `-[OOFileScannerVerifierStage(OOPrivate) checkRootFolders]` (374) | `checkRootFolders` `…/OOFileScannerVerifierStage.cpp:372` | ✅ |
| `-[OOFileScannerVerifierStage(OOPrivate) checkConfigFiles]` (398) | `checkConfigFiles` `…/OOFileScannerVerifierStage.cpp:389` (never called, on either side) | ✅ |
| `-[OOFileScannerVerifierStage(OOPrivate) checkKnownFiles]` (431) | `checkKnownFiles` `…/OOFileScannerVerifierStage.cpp:416` | ⚠️ |
| `-[OOFileScannerVerifierStage(OOPrivate) lowercaseMap:]` (474) | `lowercaseMap` `…/OOFileScannerVerifierStage.cpp:461` (never called, on either side) | ✅ |
| `-[OOFileScannerVerifierStage(OOPrivate) scanDirectory:]` (497) | `scanDirectory` `…/OOFileScannerVerifierStage.cpp:472` | ❌ |
| `-[OOFileScannerVerifierStage(OOPrivate) checkPListFormat:file:folder:]` (547) | `checkPListFormat` `…/OOFileScannerVerifierStage.cpp:522` | ✅ |
| `-[OOFileScannerVerifierStage(OOPrivate) constructReadMeNames]` (585) | `constructReadMeNames` `…/OOFileScannerVerifierStage.cpp:560` | ✅ |
| `-[OOListUnusedFilesStage name]` (624) | `OOListUnusedFilesStage::name` `…/OOFileScannerVerifierStage.cpp:596` | ✅ |
| `-[OOListUnusedFilesStage dependencies]` (629) | `OOListUnusedFilesStage::dependencies` `…/OOFileScannerVerifierStage.cpp:601` | ✅ |
| `-[OOListUnusedFilesStage run]` (634) | `OOListUnusedFilesStage::run` `…/OOFileScannerVerifierStage.cpp:606` | ✅ |
| `+[OOListUnusedFilesStage nameForReverseDependencyForVerifier:]` (639) | `OOListUnusedFilesStage::nameForReverseDependencyForVerifier` `…/OOFileScannerVerifierStage.cpp:612` | ✅ |
| `-[OOOXPVerifier(OOFileScannerVerifierStage) fileScannerStage]` (655) | inlined as `verifier()->stageWithName(OOFileScannerVerifierStage::kName)` at each call site (e.g. `Core/OXPVerifier/OOCheckDemoShipsPListVerifierStage.cpp:43`) | ➖ |
| `-[OOFileHandlingVerifierStage dependencies]` (664) | `OOFileHandlingVerifierStage::dependencies` `…/OOFileScannerVerifierStage.cpp:625` | ✅ |
| `-[OOFileHandlingVerifierStage dependents]` (669) | `OOFileHandlingVerifierStage::dependents` `…/OOFileScannerVerifierStage.cpp:630` | ✅ |
| `CheckNameConflict()` (676) | `CheckNameConflict` `…/OOFileScannerVerifierStage.cpp:637` | ✅ |

**Differences:**

- ❌ **low** — the `verifyOXP.scanFiles.nonStandardFile` warning no longer names the file type. Upstream: `"%@" is a non-standard file (%@), ignoring.`, with the `NSFileType…` string. Port: `"…" is a non-standard file, ignoring.` (both root and sub-folder) — upstream `Core/OXPVerifier/OOFileScannerVerifierStage.m:362,539` ↔ port `Core/OXPVerifier/OOFileScannerVerifierStage.cpp:360,514`
- ❌ **low** — `filesInFolder` returns names in byte order of their lowercase keys (`std::map`), not `-allValues` hash order. This changes the order of the JS syntax checks and the `Images/` texture checks, and so their log lines — upstream `:294` ↔ port `:272-284`
- ⚠️ **low** — `checkKnownFiles` walks the `knownFiles` folders in byte order of their names. The port comment says so ("they were in dictionary order"). Only the order of `caseMismatch` lines changes. A non-array folder entry is skipped, where upstream's `foreach` would have thrown — upstream `:443-447` ↔ port `:423-432`
- Subtle (✅): `pathForFile` builds the full path one component at a time instead of appending `"Dir/file"` (`:184-188`). Same result. `plistNamed` reads the file itself, so an empty file is still parsed and reported, as `NSData` length 0 was (`:217-224`). Parse-error text comes from `oo::PListError::description()`, which `oofnd/PList.hpp:371` says carries GNUstep's own message. The format detection (`PListParsing.hpp:50-63`, `PListOldStyle.hpp:727`) uses the GNUstep enum values (1/100/200/1000/1001), so "unknown format (%i)" would print the same numbers.
- Subtle (✅): directory enumeration order is file-system order on both sides (`NSDirectoryEnumerator` ↔ `std::filesystem::recursive_directory_iterator`, `oofnd/FileSystem.hpp:188`). The junk and skip sets keep only string elements, which are the only ones looked up.


## OOModelVerifierStage

<a id="oomodelverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOModelVerifierStage.m` ↔ `Core/OXPVerifier/OOModelVerifierStage.cpp`

**Status:** done — 9 rows: 4 ✅ 0 ⚠️ 2 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOModelVerifierStage init]` (47) | member init; the `NSNULL` sentinel is replaced by `OOModelVerifierEntry` fields — `Core/OXPVerifier/OOModelVerifierStage.h` | ➖ |
| `-[OOModelVerifierStage dealloc]` (57) | members | ➖ |
| `+[OOModelVerifierStage nameForReverseDependencyForVerifier:]` (64) | `nameForReverseDependencyForVerifier` `Core/OXPVerifier/OOModelVerifierStage.cpp:39` | ✅ |
| `-[OOModelVerifierStage name]` (76) | `name` `…/OOModelVerifierStage.cpp:50` | ✅ |
| `-[OOModelVerifierStage shouldRun]` (81) | `shouldRun` `…/OOModelVerifierStage.cpp:55` | ✅ |
| `-[OOModelVerifierStage run]` (86) | `run` `…/OOModelVerifierStage.cpp:60` | ❌ |
| `-[OOModelVerifierStage modelNamed:]` (122) | `modelNamed` `…/OOModelVerifierStage.cpp:75` | ❌ |
| `-[OOModelVerifierStage(OOPrivate) checkModel:]` (171) | `checkModel` `…/OOModelVerifierStage.cpp:105` | ✅ |
| `-[OOOXPVerifier(OOModelVerifierStage) modelVerifierStage]` (184) | inlined `verifier()->stageWithName(OOModelVerifierStage::kName)` `Core/OXPVerifier/OOCheckShipDataPListVerifierStage.cpp:308` | ➖ |

**Differences:**

- ❌ **low** — `modelNamed` returns `false` for an empty name before looking it up. Upstream returned NO only for `nil`, so `model = ""` went through `fileExists:` with `checkBuiltIn:YES`, where `ResourceManager` appends `""` to the `Models` folder path (`Core/ResourceManager.m:1719-1726`). The port goes straight to shipdata's "model "" could not be found" warning — upstream `Core/OXPVerifier/OOModelVerifierStage.m:132` ↔ port `Core/OXPVerifier/OOModelVerifierStage.cpp:84`
- ❌ **low** — models are checked in insertion order (a de-duplicated vector), not `NSSet` hash order. Only the verbose "Pretending to verify model" lines move — upstream `:97` ↔ port `:64`


## OOOXPVerifier

<a id="oooxpverifier"></a>
Upstream `src/Core/OXPVerifier/OOOXPVerifier.m` ↔ `Core/OXPVerifier/OOOXPVerifier.cpp`

**Status:** done — 23 rows: 15 ✅ 3 ⚠️ 4 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOOXPVerifier runVerificationIfRequested]` (95) | `runVerificationIfRequested` `Core/OXPVerifier/OOOXPVerifier.cpp:150` (+ `ExpandTildeInPath` :97) | ⚠️ |
| `-[OOOXPVerifier dealloc]` (147) | members (`oo::Ref`) | ➖ |
| `-[OOOXPVerifier registerStage:]` (158) | `registerStage` `…/OOOXPVerifier.cpp:196` | ⚠️ |
| `-[OOOXPVerifier oxpPath]` (198) | `oxpPath` `…/OOOXPVerifier.cpp:236` | ✅ |
| `-[OOOXPVerifier oxpDisplayName]` (203) | `oxpDisplayName` `…/OOOXPVerifier.cpp:241` | ✅ |
| `-[OOOXPVerifier stageWithName:]` (208) | `stageWithName` `…/OOOXPVerifier.cpp:246` | ✅ |
| `-[OOOXPVerifier configurationValueForKey:]` (216) | `configurationValueForKey` `…/OOOXPVerifier.cpp:252` | ✅ |
| `-[OOOXPVerifier configurationArrayForKey:]` (221) | `configurationArrayForKey` `…/OOOXPVerifier.cpp:258` | ✅ |
| `-[OOOXPVerifier configurationDictionaryForKey:]` (226) | `configurationDictionaryForKey` `…/OOOXPVerifier.cpp:264` | ✅ |
| `-[OOOXPVerifier configurationStringForKey:]` (231) | `configurationStringForKey` `…/OOOXPVerifier.cpp:270` | ✅ |
| `-[OOOXPVerifier configurationSetForKey:]` (236) | `configurationSetForKey` `…/OOOXPVerifier.cpp:278` | ❌ |
| `-[OOOXPVerifier(OOPrivate) initWithPath:]` (246) | `createWithPath` :294 / `initWithPath` `…/OOOXPVerifier.cpp:302` | ⚠️ |
| `-[OOOXPVerifier(OOPrivate) run]` (275) | `run` `…/OOOXPVerifier.cpp:331` | ✅ |
| `-[OOOXPVerifier(OOPrivate) setUpLogOverrides]` (305) | `setUpLogOverrides` `…/OOOXPVerifier.cpp:361` | ✅ |
| `-[OOOXPVerifier(OOPrivate) registerBaseStages]` (328) | `registerBaseStages` `…/OOOXPVerifier.cpp:383` (+ `kCxxStages` :128) | ❌ |
| `-[OOOXPVerifier(OOPrivate) buildDependencyGraph]` (362) | `buildDependencyGraph` `…/OOOXPVerifier.cpp:416` | ❌ |
| `-[OOOXPVerifier(OOPrivate) runStages]` (467) | `runStages` `…/OOOXPVerifier.cpp:513` | ❌ |
| `-[OOOXPVerifier(OOPrivate) setUpDependencies:]` (533) | `setUpDependencies` `…/OOOXPVerifier.cpp:571` | ✅ |
| `-[OOOXPVerifier(OOPrivate) setUpDependents:]` (559) | `setUpDependents` `…/OOOXPVerifier.cpp:595` | ✅ |
| `-[OOOXPVerifier(OOPrivate) dumpDebugGraphviz]` (582) | `dumpDebugGraphviz` `…/OOOXPVerifier.cpp:616` | ✅ |
| `SwitchLogFile()` (648) | `SwitchLogFile` `…/OOOXPVerifier.cpp:684` | ✅ |
| `NoteVerificationStage()` (660) | `NoteVerificationStage` `…/OOOXPVerifier.cpp:696` | ✅ |
| `OpenLogFile()` (665) | `OpenLogFile` `…/OOOXPVerifier.cpp:701` | ✅ |

**Differences:**

- ❌ **low** — **stage execution order.** Upstream picked the first runnable stage from an `NSMutableSet` built from `-allValues`, in pointer-hash order (address-dependent). The port's `_waitingStages` is filled from a `std::map` keyed by stage name, so runnable stages run in byte order of their display names ("Checking JS Script file syntax" before "Checking demoships.plist", since `J` < `d`). The order of whole log sections differs from upstream, though it is now deterministic — upstream `Core/OXPVerifier/OOOXPVerifier.m:389,413,441,457,480` ↔ port `Core/OXPVerifier/OOOXPVerifier.cpp:433-436,455,485,502-505,523`
- ❌ **low** — `configurationSetForKey` returns a sorted vector of only the string elements, not an `NSSet` of everything. Every caller looks up strings, so membership is unchanged. Only the order of `registerBaseStages` registrations (and so of the "unknown class" lines) changes — upstream `:236-240,340-346` ↔ port `:278-290,387-392`
- ⚠️ **low** — `registerBaseStages` resolves names only through `kCxxStages` (plus a test hook). An Objective-C class name that is not a stage used to log "…is not a subclass of OOOXPVerifierStage"; it now logs "unknown class". Port comment `:407-410` covers this, and `registerStage`'s `isKindOfClass:` check is gone for the same reason (comment `:205-206`) — upstream `:167-170,348-355` ↔ port `:393-411`
- ⚠️ **low** — `_displayName` is now always `lastPathComponent` (comment `:319`: GNUstep's `-displayNameAtPath:`). On macOS `-displayNameAtPath:` could hide the extension. This name feeds the log file name and "Verifying %@" — upstream `:256-258` ↔ port `:319`
- ⚠️ **low** — `-stringByExpandingTildeInPath` is reimplemented (comment `:91-96`). `~user` is not expanded, and separators are rewritten to `/` with empty components dropped — upstream `:118` ↔ port `:97-115,168`
- Subtle: `runStages` and `performRun` catch only `OOException` and rethrow anything else (port `:547-550`, `OOOXPVerifierStage.cpp:170-173`). Upstream's `@catch (NSException*)` logged any Foundation exception as `verifyOXP.exception` and carried on. A `std::exception` from a stage now ends the whole verification run.
- Subtle (✅): `buildDependencyGraph` takes waiting stages FIFO instead of `-anyObject`. Stages registered during `dependencies()` are still picked up. `dumpDebugGraphviz` writes `OXPVerifierStageDependencies.dot` itself, as `writeDiagnosticString:` did (comment `:671-672`).


## OOOXPVerifierStage

<a id="oooxpverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOOXPVerifierStage.m` ↔ `Core/OXPVerifier/OOOXPVerifierStage.cpp`

**Status:** done — 21 rows: 18 ✅ 1 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOOXPVerifierStage init]` (43) | member defaults (`_canRun = false`, empty vectors) — `Core/OXPVerifier/OOOXPVerifierStage.h` | ➖ |
| `-[OOOXPVerifierStage dealloc]` (57) | members | ➖ |
| `-[OOOXPVerifierStage description]` (66) | `description` `Core/OXPVerifier/OOOXPVerifierStage.cpp:69` (+ `descriptionComponents` :63, `className` :75) | ✅ |
| `-[OOOXPVerifierStage verifier]` (71) | `verifier` `…/OOOXPVerifierStage.cpp:88` | ✅ |
| `-[OOOXPVerifierStage completed]` (76) | `completed` `…/OOOXPVerifierStage.cpp:93` | ✅ |
| `-[OOOXPVerifierStage name]` (81) | `name` `…/OOOXPVerifierStage.cpp:98` | ✅ |
| `-[OOOXPVerifierStage dependencies]` (87) | `dependencies` `…/OOOXPVerifierStage.cpp:104` | ✅ |
| `-[OOOXPVerifierStage dependents]` (92) | `dependents` `…/OOOXPVerifierStage.cpp:109` | ✅ |
| `-[OOOXPVerifierStage shouldRun]` (97) | `shouldRun` `…/OOOXPVerifierStage.cpp:114` | ✅ |
| `-[OOOXPVerifierStage run]` (102) | `run` `…/OOOXPVerifierStage.cpp:119` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) setVerifier:]` (111) | `setVerifier` `…/OOOXPVerifierStage.cpp:126` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) isDependentOf:]` (116) | `isDependentOf` `…/OOOXPVerifierStage.cpp:131` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) registerDependency:]` (136) | `registerDependency` `…/OOOXPVerifierStage.cpp:149` (+ `AddStage` :51) | ✅ |
| `-[OOOXPVerifierStage(OOInternal) canRun]` (144) | `canRun` `…/OOOXPVerifierStage.cpp:158` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) performRun]` (149) | `performRun` `…/OOOXPVerifierStage.cpp:163` | ⚠️ |
| `-[OOOXPVerifierStage(OOInternal) noteSkipped]` (167) | `noteSkipped` `…/OOOXPVerifierStage.cpp:185` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) dependencyRegistrationComplete]` (176) | `dependencyRegistrationComplete` `…/OOOXPVerifierStage.cpp:194` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) resolvedDependencies]` (181) | `resolvedDependencies` `…/OOOXPVerifierStage.cpp:199` | ✅ |
| `-[OOOXPVerifierStage(OOInternal) resolvedDependents]` (186) | `resolvedDependents` `…/OOOXPVerifierStage.cpp:204` | ✅ |
| `-[OOOXPVerifierStage(OOPrivate) registerDepedent:]` (195) | `registerDepedent` `…/OOOXPVerifierStage.cpp:211` | ✅ |
| `-[OOOXPVerifierStage(OOPrivate) dependencyCompleted:]` (202) | `dependencyCompleted` `…/OOOXPVerifierStage.cpp:218` (+ `notifyDependents` :229) | ✅ |

**Differences:**

- ⚠️ **low** — the exception line in `performRun` spells out GNUstep's `%@`-of-exception layout as `<OOException: 0x…> NAME:… REASON:…`. Upstream printed `<NSException: 0x…> …`, so the class name in the `verifyOXP.exception` text differs (proposed ADR-0037, comment `:174-175`). Exceptions other than `OOException` are rethrown (`:172-173`) — upstream `Core/OXPVerifier/OOOXPVerifierStage.m:154-159` ↔ port `Core/OXPVerifier/OOOXPVerifierStage.cpp:168-177`
- Subtle (✅): the dependency and dependent sets are now vectors in registration order, not `NSMutableSet` hash order. `dependencyCompleted` only removes an entry, so the notification order has no effect. Only the arc order in the debug graphviz output changes. `verifier()` returns the verifier borrowed, where upstream retained and autoreleased it; the verifier outlives its stages.


## OOPListSchemaVerifier

<a id="ooplistschemaverifier"></a>
Upstream `src/Core/OXPVerifier/OOPListSchemaVerifier.m` ↔ `Core/OXPVerifier/OOPListSchemaVerifier.cpp`

**Status:** done — 51 rows: 39 ✅ 5 ⚠️ 1 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| error domain / userInfo key constants (97–111) *(added row)* | constants `Core/OXPVerifier/OOPListSchemaVerifier.cpp:102-117` (+ `kUnderlyingErrorErrorKey` = `"NSUnderlyingError"` for `NSUnderlyingErrorKey`) | ✅ |
| `BackLink()` (137) | `BackLink` `…/OOPListSchemaVerifier.cpp:150` | ✅ |
| `BackLinkIndex()` (143) | `BackLinkIndex` `…/OOPListSchemaVerifier.cpp:156` | ✅ |
| `BackLinkRoot()` (149) | `BackLinkRoot` `…/OOPListSchemaVerifier.cpp:162` | ✅ |
| `+[OOPListSchemaVerifier verifierWithSchema:]` (229) | `verifierWithSchema` `…/OOPListSchemaVerifier.cpp:249` | ✅ |
| `-[OOPListSchemaVerifier initWithSchema:]` (234) | ctor :254 + `initWithSchema` `…/OOPListSchemaVerifier.cpp:264` | ✅ |
| `-[OOPListSchemaVerifier dealloc]` (253) | members | ➖ |
| `-[OOPListSchemaVerifier setDelegate:]` (261) | `setDelegate` `…/OOPListSchemaVerifier.cpp:274` | ✅ |
| `-[OOPListSchemaVerifier delegate]` (269) | `delegate` `…/OOPListSchemaVerifier.cpp:282` | ✅ |
| `-[OOPListSchemaVerifier verifyPropertyList:named:]` (274) | `verifyPropertyList` `…/OOPListSchemaVerifier.cpp:287` | ✅ |
| `+[OOPListSchemaVerifier descriptionForKeyPath:]` (291) | `descriptionForKeyPath` `…/OOPListSchemaVerifier.cpp:304` | ✅ |
| `-[… delegateVerifierWithPropertyList:named:testProperty:atPath:againstType:error:]` (323) | `delegateVerifierWithPropertyList` (testProperty) `…/OOPListSchemaVerifier.cpp:331` | ⚠️ |
| `-[… delegateVerifierWithPropertyList:named:failedForProperty:withError:expectedType:]` (367) | `delegateVerifierWithPropertyList` (failed) `…/OOPListSchemaVerifier.cpp:379` | ⚠️ |
| `-[OOPListSchemaVerifier(OOPrivate) verifyPList:]` (395) | `verifyPList` `…/OOPListSchemaVerifier.cpp:410` | ⚠️ |
| `-[OOPListSchemaVerifier(OOPrivate) resolveSchemaType:]` (476) | `resolveSchemaType` `…/OOPListSchemaVerifier.cpp:486` | ❌ |
| `StringToSchemaType()` (525) | `StringToSchemaType` `…/OOPListSchemaVerifier.cpp:534` | ✅ |
| `ApplyStringFilter()` (562) | `ApplyStringFilter` `…/OOPListSchemaVerifier.cpp:597` (+ `SubstringToIndex` :589, `FindSubString` :570) | ✅ |
| `ApplyStringTest()` (623) | `ApplyStringTest` `…/OOPListSchemaVerifier.cpp:668` | ✅ |
| `KeyPathToArray()` (660) | `KeyPathToArray` `…/OOPListSchemaVerifier.cpp:702` | ✅ |
| `KeyPathToString()` (674) | `KeyPathToString` `…/OOPListSchemaVerifier.cpp:718` | ✅ |
| `StringForErrorReport()` (679) | `StringForErrorReport` `…/OOPListSchemaVerifier.cpp:727` | ✅ |
| `ArrayForErrorReport()` (700) | `ArrayForErrorReport` `…/OOPListSchemaVerifier.cpp:770` (+ `ElementDescription` :761) | ✅ |
| `SetForErrorReport()` (731) | `SetForErrorReport` `…/OOPListSchemaVerifier.cpp:797` | ✅ |
| `StringOrArrayForErrorReport()` (736) | `StringOrArrayForErrorReport` `…/OOPListSchemaVerifier.cpp:810` | ✅ |
| `Verify_String()` (764) | `Verify_String` `…/OOPListSchemaVerifier.cpp:839` | ✅ |
| `Verify_Array()` (825) | `Verify_Array` `…/OOPListSchemaVerifier.cpp:904` | ✅ |
| `Verify_Dictionary()` (879) | `Verify_Dictionary` `…/OOPListSchemaVerifier.cpp:953` | ⚠️ |
| `Verify_Integer()` (983) | `Verify_Integer` `…/OOPListSchemaVerifier.cpp:1053` | ✅ |
| `Verify_PositiveInteger()` (1011) | `Verify_PositiveInteger` `…/OOPListSchemaVerifier.cpp:1086` | ✅ |
| `Verify_Float()` (1039) | `Verify_Float` `…/OOPListSchemaVerifier.cpp:1118` | ✅ |
| `Verify_PositiveFloat()` (1067) | `Verify_PositiveFloat` `…/OOPListSchemaVerifier.cpp:1151` | ✅ |
| `Verify_OneOf()` (1099) | `Verify_OneOf` `…/OOPListSchemaVerifier.cpp:1188` | ✅ |
| `Verify_Enumeration()` (1143) | `Verify_Enumeration` `…/OOPListSchemaVerifier.cpp:1226` | ✅ |
| `Verify_Boolean()` (1171) | `Verify_Boolean` `…/OOPListSchemaVerifier.cpp:1261` | ✅ |
| `Verify_FuzzyBoolean()` (1182) | `Verify_FuzzyBoolean` `…/OOPListSchemaVerifier.cpp:1276` | ✅ |
| `Verify_Vector()` (1195) | `Verify_Vector` `…/OOPListSchemaVerifier.cpp:1291` | ✅ |
| `Verify_Quaternion()` (1206) | `Verify_Quaternion` `…/OOPListSchemaVerifier.cpp:1307` | ✅ |
| `Verify_DelegatedType()` (1217) | `Verify_DelegatedType` `…/OOPListSchemaVerifier.cpp:1323` | ✅ |
| `-[NSString(OOPListSchemaVerifierHelpers) ooPListVerifierHasSubString:]` (1253) | `HasSubString` `…/OOPListSchemaVerifier.cpp:582` | ✅ |
| `-[NSError(OOPListSchemaVerifierConveniences) plistKeyPath]` (1262) | inlined `error.userInfo.find(kPListKeyPathErrorKey)` (`:212`, `OOCheckShipDataPListVerifierStage.cpp:355`) | ➖ |
| `-[NSError(OOPListSchemaVerifierConveniences) plistKeyPathDescription]` (1267) | `KeyPathDescriptionOfError` `…/OOPListSchemaVerifier.cpp:210` | ➖ |
| `-[NSError(OOPListSchemaVerifierConveniences) missingRequiredKeys]` (1272) | gone (no callers) | ➖ |
| `-[NSError(OOPListSchemaVerifierConveniences) expectedClass]` (1277) | gone; `kExpectedClassErrorKey` no longer recorded (comment `:1408-1409`) | ➖ |
| `-[NSError(OOPListSchemaVerifierConveniences) expectedClassName]` (1282) | gone (the `kExpectedClassNameErrorKey` value is still recorded) | ➖ |
| `Error()` (1292) | `Error` `…/OOPListSchemaVerifier.cpp:1350` | ✅ |
| `ErrorWithProperty()` (1304) | `ErrorWithProperty` `…/OOPListSchemaVerifier.cpp:1362` | ✅ |
| `ErrorWithDictionary()` (1320) | `ErrorWithDictionary` `…/OOPListSchemaVerifier.cpp:1378` | ✅ |
| `ErrorWithDictionaryAndArguments()` (1332) | `ErrorWithDictionaryAndArguments` `…/OOPListSchemaVerifier.cpp:1390` | ✅ |
| `ErrorTypeMismatch()` (1350) | `ErrorTypeMismatch` `…/OOPListSchemaVerifier.cpp:1403` | ⚠️ |
| `ErrorFailureAlreadyReported()` (1383) | `ErrorFailureAlreadyReported` `…/OOPListSchemaVerifier.cpp:1444` | ✅ |
| `IsFailureAlreadyReportedError()` (1388) | `IsFailureAlreadyReportedError` `…/OOPListSchemaVerifier.cpp:1449` | ✅ |

**Differences:**

- ⚠️ **low** — `Verify_Dictionary` visits members in byte order of the key, not `-keyEnumerator` hash order (comment `:999`). Each "Unpermitted key", type-mismatch and nested error reaches the delegate (shipdata's "verification of ship … failed at …") in a different order. Where the delegate asks to stop (`stop`), or in tentative mode (first failure), which errors are reported before the early exit can differ too — upstream `Core/OXPVerifier/OOPListSchemaVerifier.m:925-966` ↔ port `Core/OXPVerifier/OOPListSchemaVerifier.cpp:999-1031`
- ❌ **low** — `resolveSchemaType` with a `$macro` whose definition is neither a string nor a dictionary (a number or array). Upstream sent `objectForKey:` to it; the NSInvalidArgumentException was caught by `verifyPList` and reported as `kPListErrorInternal` "Uncaught exception … in plist verifier for …". The port reports `kPListErrorSchemaBadTypeSpecifier` "Bad schema: invalid type specifier for path … (no type specified)". Only a broken built-in schema can trigger this — upstream `:488-496` ↔ port `:495-526`
- ⚠️ **low** — the delegate is a C++ interface whose implementations answer both callbacks. The `respondsToSelector:` fallbacks ("delegate does not handle delegated types" / `plistVerifier.failed`) now fire only when there is no delegate at all (comment `:341-342`) — upstream `:333,375` ↔ port `:343,387`
- ⚠️ **low** — `verifyPList` and the delegate wrappers catch only `OOException` and rethrow anything else (`:352-355,396-399,460-463`). The one exception the port deliberately reproduces, `SubstringToIndex` past the end for `truncFront:`/`truncBack:`, raises `OORangeException` with GNUstep's captured reason (`:589-595`). So that path still becomes "Uncaught exception …", as upstream did.
- ⚠️ **low** — `ErrorTypeMismatch` no longer stores `kExpectedClassErrorKey` (comment `:1408-1409`). The failure-reason text "Expected %@, found %@." is unchanged, and so are the kind names (nothing/string/number/array/dictionary/data/date). A PList bool counts as "number", as `NSNumber` did.
- Check order and messages (✅): `verifyPList` resolves the specifier, then maps the type string, then dispatches, then reports to the delegate only if `!tentative && !alreadyReported` — same as upstream. `resolveSchemaType`'s "no type specified" vs "not string or dictionary" choice follows the last `type` value seen, as upstream's `typeVal` did. `Verify_String` keeps upstream's quirk that a bad `filter` error surfaces only if a later prefix/suffix/substring test fails, and then replaces that test's own error (`:854-863`). It applies prefix, then suffix, then substring, then minLength, then maxLength, counting UTF-16 units. `Verify_Array`/`Verify_Dictionary` keep the same `(stop && !tentative) || (tentative && !OK)` exits, return missing-required-keys before setting `*outStop`, and keep the "too manu pairs" typo. `Verify_DelegatedType` still returns *success* when `baseType` fails (`:1336-1339` ↔ `:1228-1238`), so a failing base type still counts as a `oneOf` match. "no options specified for oneOf type." is still the enumeration message too. `%u`/`%zu`/`%lli`/`%g` formats are unchanged (printf `vformat`).
- String helpers (✅): `hasPrefix`/`hasSuffix` match GNUstep (an empty test never matches, `oofnd/String.hpp:958-972`). `FindSubString` finds `""` at 0 and stops at composed-sequence boundaries. `StringForErrorReport` reproduces the replacement range limited to the original length. Array elements print as `%@` would (string as is, number as `stringValue`, otherwise `DescriptionOf`). `Verify_OneOf` keys its per-option errors by `DescriptionOf(option)` (comment `:1209`); this lives only in userInfo and is never printed.


## OOTextureVerifierStage

<a id="ootextureverifierstage"></a>
Upstream `src/Core/OXPVerifier/OOTextureVerifierStage.m` ↔ `Core/OXPVerifier/OOTextureVerifierStage.cpp`

**Status:** done — 10 rows: 5 ✅ 0 ⚠️ 2 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOTextureVerifierStage init]` (44) | member init (`_usedTextures` sorted vector) — `Core/OXPVerifier/OOTextureVerifierStage.h` | ➖ |
| `-[OOTextureVerifierStage dealloc]` (53) | members | ➖ |
| `+[OOTextureVerifierStage nameForReverseDependencyForVerifier:]` (60) | `nameForReverseDependencyForVerifier` `Core/OXPVerifier/OOTextureVerifierStage.cpp:38` | ✅ |
| `-[OOTextureVerifierStage name]` (65) | `name` `…/OOTextureVerifierStage.cpp:43` | ✅ |
| `-[OOTextureVerifierStage shouldRun]` (70) | `shouldRun` `…/OOTextureVerifierStage.cpp:48` | ✅ |
| `-[OOTextureVerifierStage run]` (75) | `run` `…/OOTextureVerifierStage.cpp:54` | ❌ |
| `-[OOTextureVerifierStage textureNamed:usedInContext:]` (96) | `textureNamed` `…/OOTextureVerifierStage.cpp:72` | ❌ |
| `-[OOTextureVerifierStage(OOPrivate) checkTextureNamed:inFolder:]` (119) | `checkTextureNamed` `…/OOTextureVerifierStage.cpp:89` | ✅ |
| `-[OOTextureHandlingStage dependents]` (169) | `OOTextureHandlingStage::dependents` `…/OOTextureVerifierStage.cpp:134` | ✅ |
| `-[OOOXPVerifier(OOTextureVerifierStage) textureVerifierStage]` (180) | removed (header comment `Core/OXPVerifier/OOTextureVerifierStage.h:46`); callers use `stageWithName` | ➖ |

**Differences:**

- ❌ **low** — used textures are checked in byte order (sorted vector), not `NSSet` hash order, and `Images/` files in `filesInFolder`'s byte order. So the `notPOT`/`failed`/`OK` lines come out in a different order — upstream `Core/OXPVerifier/OOTextureVerifierStage.m:81,90-92` ↔ port `Core/OXPVerifier/OOTextureVerifierStage.cpp:56,67`
- ❌ **low** — `textureNamed` silently ignores an empty name. Upstream ignored only `nil`, so `""` was recorded and looked up with `checkBuiltIn:YES` (same `ResourceManager` path as the `modelNamed` note) — upstream `:100` ↔ port `:76`
- Subtle (✅): the loader options (including the duplicated `kOOTextureMinFilterNearest`), the power-of-two rounding (`(2*w)/3` rounded up) and all message texts are unchanged.

