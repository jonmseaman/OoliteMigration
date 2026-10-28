# Parity findings: Foundation replacements, logging, collections, async

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## NSBundle+Override

<a id="nsbundleoverride"></a>
Upstream `src/Core/NSBundle+Override.m` ↔ `oofnd/Defaults.hpp` (`applicationDomainName`, `Defaults::forProcess`), `oofnd/ResourcePaths.hpp` (`builtInResourcesDirectory`), and per-caller `OoliteInfoString` readers

**Status:** done — 1 rows: 0 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSBundle(Override) infoDictionary]` (20) | No NSBundle. The Info-gnustep.plist lookup (`<cwd>/Resources`, else `<cwd>/../share/oolite/Resources`) is `ResourcePaths::builtInResourcesDirectory` oofnd/ResourcePaths.hpp:224. The defaults domain comes from `Defaults::forProcess` oofnd/Defaults.hpp:432 + `applicationDomainName` :396. `CFBundleVersion` is read by `OoliteInfoString` (Entities/PlayerEntity.cpp:317, Debug/OODebugTCPConsoleClient.cpp:198, OOCacheManager.cpp:90) | ➖ |

**Differences:**

- ➖ **low** — When Info-gnustep.plist is missing, upstream `NSLog`s "[Oolite-Core] Warning: Failed to find info-gnustep.plist at calculated path: …" to stderr. The port is silent: `load()` returns an empty dict and the domain falls back to the process name. This is stderr only, not Latest.log — upstream `Core/NSBundle+Override.m:49` ↔ port `oofnd/Defaults.hpp:396`
- subtle — The fallback path uses `lexically_normal()` where upstream used `-stringByStandardizingPath`, which also expands `~` and, in GNUstep, resolves symlinks. Only a non-standard Linux layout would see this — upstream `Core/NSBundle+Override.m:34` ↔ port `oofnd/ResourcePaths.hpp:229`

## NSDataOOExtensions

<a id="nsdataooextensions"></a>
Upstream `src/Core/NSDataOOExtensions.m` ↔ `Core/OODataFromOXZFile.cpp` (declared in `oofnd/FileSystem.hpp:457`)

**Status:** done — 1 rows: 1 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[NSData(OOExtensions) oo_dataWithOXZFile:]` (37) | `OODataFromOXZFile` Core/OODataFromOXZFile.cpp:38 (statement for statement: the same .oxz component search, the same `files.notFound` log class and texts, the same unzip error paths; nil→`std::nullopt`) | ✅ |

**Differences:**

- subtle — The empty-file test uses `fs::fileSize`, i.e. `std::filesystem::file_size`, which follows symlinks. Upstream used `fileAttributesAtPath:traverseLink:NO`, which gives a symlink its own size. Only a symlinked plain file can tell the two apart — upstream `Core/NSDataOOExtensions.m:60` ↔ port `Core/OODataFromOXZFile.cpp:62`

## NSDictionaryOOExtensions

<a id="nsdictionaryooextensions"></a>
Upstream `src/Core/NSDictionaryOOExtensions.m` ↔ *(absorbed: value copies of `oo::PList::Dict` at the call sites)*

**Status:** done — 3 rows: 0 ✅ 0 ⚠️ 0 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSDictionary(OOExtensions) dictionaryByAddingObject:forKey:]` (32) | Callers copy the PList and assign the key, e.g. `AddingValue` Materials/OODefaultShaderSynthesizer.cpp:1003 and `dict[...] = …` Debug/OODebugTCPConsoleClient.cpp:693. Callers check for a missing value themselves (OODefaultShaderSynthesizer.cpp:1080) | ➖ |
| `-[NSDictionary(OOExtensions) dictionaryByRemovingObjectForKey:]` (46) | `erase` on a copy (e.g. Materials/OODefaultShaderSynthesizer.cpp:1083) | ➖ |
| `-[NSDictionary(OOExtensions) dictionaryByAddingEntriesFromDictionary:]` (60) | `AddEntries` on a copy (OOShipRegistry.cpp:816); OOLegacyScriptWhitelist alias merge | ➖ |

**Differences:**

- subtle — `AddingValue(spec, key, PList())` would insert a null entry, where upstream returned the dictionary unchanged for a nil object (`:35`). No caller passes null today — upstream `Core/NSDictionaryOOExtensions.m:35` ↔ port `Core/Materials/OODefaultShaderSynthesizer.cpp:1003`

## NSFileManagerOOExtensions

<a id="nsfilemanagerooextensions"></a>
Upstream `src/Core/NSFileManagerOOExtensions.m` ↔ `oofnd/FileSystem.hpp` (`oo::fs`), `oofnd/ResourcePaths.hpp`, `Core/OODataFromOXZFile.cpp`, and inlined call sites

**Status:** done — 16 rows: 9 ✅ 0 ⚠️ 1 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSFileManager(OOExtensions) commanderContentsOfPath:]` (39) | Inlined in the commander list, Entities/PlayerEntityLoadSave.cpp:935-947. The upstream per-entry filter `![… fileExistsAtPath:…] && pathIsDirectory` (`:51`) can never be true, so it only built full paths. The port builds the same paths and logs the same `savedGame.read.fail.fileNotFound` ERROR | ✅ |
| `-[NSFileManager(OOExtensions) defaultCommanderPath]` (79) | `GameController::playerFileDirectory` Core/GameController.cpp:811-828 (`ResourcePaths::saveDirectory` oofnd/ResourcePaths.hpp:169), equivalent; second copy in `takeSnapShot` Scripting/OOJSGlobal.cpp:940-953 without the logs | ❌ |
| `-[NSFileManager(OOExtensions) oo_directoryContentsAtPath:]` (113) | `#if OOLITE_MAC_OS_X`: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_createDirectoryAtPath:attributes:]` (118) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_fileAttributesAtPath:traverseLink:]` (123) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_fileSystemAttributesAtPath:]` (137) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_removeItemAtPath:]` (142) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_moveItemAtPath:toPath:]` (147) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_directoryContentsAtPath:]` (154) | `oo::fs::directoryContents` oofnd/FileSystem.hpp:264 (names, no `.`/`..`, OS order) | ✅ |
| `-[NSFileManager(OOExtensions) oo_createDirectoryAtPath:attributes:]` (159) | `oo::fs::createDirectories` oofnd/FileSystem.hpp:283 | ✅ |
| `-[NSFileManager(OOExtensions) oo_fileAttributesAtPath:traverseLink:]` (164) | `oo::fs::fileSize` :152 / `modificationTimeSince1970` :173 (both follow links) | ✅ |
| `-[NSFileManager(OOExtensions) oo_fileSystemAttributesAtPath:]` (169) | `oo::fs::freeSpace` oofnd/FileSystem.hpp:162 (the only key read was NSFileSystemFreeSize) | ✅ |
| `-[NSFileManager(OOExtensions) oo_removeItemAtPath:]` (174) | `oo::fs::removeItem` oofnd/FileSystem.hpp:297 (missing path is an error, as `removeFileAtPath:handler:`) | ✅ |
| `-[NSFileManager(OOExtensions) oo_moveItemAtPath:toPath:]` (179) | `oo::fs::moveItem` oofnd/FileSystem.hpp:309 (refuses an existing destination) | ✅ |
| `-[NSFileManager(OOExtensions) chdirToSnapshotPath]` (187) | Inlined in `MyOpenGLView::snapShot` SDL/MyOpenGLView.cpp:1156-1165 + `ResourcePaths::snapshotDirectory` oofnd/ResourcePaths.hpp:174. The same two log classes. The upstream BOOL was ignored by its only caller | ✅ |
| `-[NSFileManager(OOExtensions) oo_oxzFileExistsAtPath:]` (215) | `OOOxzFileExistsAtPath` Core/OODataFromOXZFile.cpp:147 | ✅ |

**Differences:**

- ❌ **low** — `takeSnapShot` re-implements `-defaultCommanderPath` inline without its two ERROR logs (`savedGame.defaultPath.create.failed`, `savedGame.defaultPath.notDirectory`). Upstream logged them whenever the JS call hit an uncreatable or non-directory save dir. The `GameController` copy does log — upstream `Core/NSFileManagerOOExtensions.m:97,104` (via `Core/Scripting/OOJSGlobal.m:711`) ↔ port `Core/Scripting/OOJSGlobal.cpp:940-953`
- subtle — `directoryContents` returns an error, so the whole listing is lost, if iteration fails part-way. GNUstep's `directoryContentsAtPath:` returned what it had read — upstream `Core/NSFileManagerOOExtensions.m:156` ↔ port `oofnd/FileSystem.hpp:264-277`
- subtle — `moveItem` is a bare `rename`. GNUstep's `movePath:toPath:handler:` falls back to copy+delete across volumes, so a cross-volume move now fails — upstream `Core/NSFileManagerOOExtensions.m:181` ↔ port `oofnd/FileSystem.hpp:309-321`

## NSMutableDictionaryOOExtensions

<a id="nsmutabledictionaryooextensions"></a>
Upstream `src/Core/NSMutableDictionaryOOExtensions.m` ↔ `Core/ResourceManager.cpp` (`MergeEntries`)

**Status:** done — 1 rows: 1 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSMutableDictionary(OOExtensions) mergeEntriesFromDictionary:]` (30) | `MergeEntries` Core/ResourceManager.cpp:258. It keeps the same rules: a missing key is added; unequal dicts merge recursively; unequal arrays concatenate; anything else is replaced. `-isEqual:` becomes `PListIsEqual` :188, where numbers compare by value | ✅ |

**Differences:**

- *none*

## NSNumberOOExtensions

<a id="nsnumberooextensions"></a>
Upstream `src/Core/NSNumberOOExtensions.m` ↔ *(absorbed: `oo::PList` node kinds)*

**Status:** done — 2 rows: 0 ✅ 0 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSNumber(OOExtensions) oo_isFloatingPointNumber]` (33) | `PList::isReal()` oofnd/PList.hpp:219 (the `d`/`f` objCType test becomes the Real kind; `isSinglePrecision()` :227 keeps `f`) | ➖ |
| `-[NSNumber(OOExtensions) oo_isBoolean]` (47) | `PList::isBool()` oofnd/PList.hpp:217 (the cached YES/NO identity test becomes the Bool kind) | ➖ |

**Differences:**

- *none* (the PList kind carries exactly what the objCType/identity tests recovered)

## NSObjectOOExtensions

<a id="nsobjectooextensions"></a>
Upstream `src/Core/NSObjectOOExtensions.m` ↔ *(absorbed: per-class `objectSize()` / `oo::EntityObjectSize`)*

**Status:** done — 2 rows: 0 ✅ 0 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[NSObject(OOExtensions) oo_instanceSize]` (38) | `sizeof *this` in each class's `objectSize()` | ➖ |
| `-[NSObject(OOExtensions) oo_objectSize]` (43) | virtual `objectSize()` (OODrawable.h:81, Materials/OOMaterial.h:72, OOMesh.h:146 …), `oo::EntityObjectSize` (Entities/EntityHelpers.cpp:104) | ➖ |

**Differences:**

- ➖ **low** — The debug monitor's memory figures and `gTotalEntityMemory` now use the C++ `sizeof`. Upstream used `class_getInstanceSize` (isa plus ivars), so the numbers in the debug-console memory report differ. They are diagnostic only — upstream `Core/NSObjectOOExtensions.m:40` ↔ port `Core/OODrawable.h:81`

## NSScannerOOExtensions

<a id="nsscannerooextensions"></a>
Upstream `src/Core/NSScannerOOExtensions.m` ↔ `oofnd/Scanner.hpp`

**Status:** done — 2 rows: 2 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSScanner(OOExtensions) ooliteScanCharactersFromSet:intoString:]` (29) | `Scanner::scanCharactersFromSetNoSkip` oofnd/Scanner.hpp:871 → `scanRun(set, true, false)` :895 | ✅ |
| `-[NSScanner(OOExtensions) ooliteScanUpToCharactersFromSet:intoString:]` (54) | `Scanner::scanUpToCharactersFromSetNoSkip` :872 → `scanRun(set, false, false)` | ✅ |

**Differences:**

- *none*. There is no skipping, the scan runs over UTF-16 units, and on an empty match it returns false with the location unchanged (upstream sets it to the same value).

## NSStringOOExtensions

<a id="nsstringooextensions"></a>
Upstream `src/Core/NSStringOOExtensions.m` ↔ `oofnd/String.hpp`, `oofnd/Encoding.hpp`

**Status:** done — 13 rows: 8 ✅ 2 ⚠️ 0 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[NSString(OOExtensions) stringWithContentsOfUnicodeFile:]` (31) | `oo::str::decodeUnicodeText` oofnd/Encoding.hpp:2096 over `OODataFromOXZFile` bytes (ResourceManager.cpp:1976, Scripting/OOJSScript.cpp:783, Debug/OODebugMonitor.cpp:696) | ⚠️ |
| `+[NSString(OOExtensions) stringWithUTF16String:]` (86) | `oo::utf16ToUtf8` (its only caller, the SpiderMonkey error reporter, is gone with QuickJS) | ➖ |
| `-[NSString(OOExtensions) utf16DataWithBOM:]` (102) | `oo::str::utf16Data` oofnd/String.hpp:444 (little-endian, optional U+FEFF) | ✅ |
| `-[NSString(OOExtensions) oo_hash]` (133) | `oo::str::ooHash` oofnd/String.hpp:435 (djb2-xor over UTF-16 units; Entities/PlayerEntityLoadSave.cpp:1241) | ✅ |
| `-[NSString(OOExtensions) stringByTrimmingLeadingCharactersInSet:]` (143) | `oo::str::trimLeading` oofnd/String.hpp:406 | ✅ |
| `-[NSString(OOExtensions) stringByTrimmingLeadingWhitespaceAndNewlineCharacters]` (152) | `trimLeadingWhitespaceAndNewlines` oofnd/String.hpp:425 (OOOXZManager.cpp:550-591) | ✅ |
| `-[NSString(OOExtensions) stringByTrimmingTrailingCharactersInSet:]` (157) | `oo::str::trimTrailing` oofnd/String.hpp:416 | ✅ |
| `-[NSString(OOExtensions) stringByTrimmingTrailingWhitespaceAndNewlineCharacters]` (166) | `trimTrailingWhitespaceAndNewlines` oofnd/String.hpp:426 | ✅ |
| `-[NSMutableString(OOExtensions) appendLine:]` (175) | `oo::str::appendLine` oofnd/String.hpp:551 | ✅ |
| `-[NSMutableString(OOExtensions) appendFormatLine:]` (180) | Callers append `oo::str::format(…)` + `"\n"` | ➖ |
| `-[NSMutableString(OOExtensions) appendFormatLine:arguments:]` (188) | as above | ➖ |
| `-[NSMutableString(OOExtensions) deleteCharacterAtIndex:]` (195) | `oo::str::deleteUnitAt` oofnd/String.hpp:559 (SDL/MyOpenGLView+Input.cpp:883) | ⚠️ |
| `OOTabString()` (202) | `oo::str::tabString` oofnd/String.hpp:548 | ✅ |

**Differences:**

- ⚠️ **low** — After a UTF-8 BOM, upstream decoded `length + 3` bytes, six bytes past the buffer. Those heap bytes could flip the result to Latin-1 or append junk. The port decodes the file's own bytes. Documented in the `oofnd/Encoding.hpp` banner ("One deliberate difference") — upstream `Core/NSStringOOExtensions.m:67` ↔ port `oofnd/Encoding.hpp:41-49,2113-2116`
- ⚠️ **low** — `deleteCharacterAtIndex:` past the end raised NSRangeException. `deleteUnitAt` ignores it, as its comment says ("oofnd does not throw") — upstream `Core/NSStringOOExtensions.m:197` ↔ port `oofnd/String.hpp:557-565`
- subtle — Both readers treat a big-endian (FE FF) UTF-16 file as machine-order (byte-swapped) text. The port reproduces this on purpose, and the captures pin it — upstream `Core/NSStringOOExtensions.m:52-58` ↔ port `oofnd/Encoding.hpp:2100-2110`

## NSThreadOOExtensions

<a id="nsthreadooextensions"></a>
Upstream `src/Core/NSThreadOOExtensions.m` ↔ `oofnd/Thread.hpp`

**Status:** done — 1 rows: 1 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[NSThread(OOExtensions) ooSetCurrentThreadName:]` (36) | `oo::thread::setCurrentName` oofnd/Thread.hpp:88 (SetThreadDescription on Windows, as GNUstep's `-setName:` measured). The callers keep the same names: "OOAsyncWorkManager thread N" (Core/OOAsyncWorkManager.cpp:202), "loggerThread" (oofnd/LogFile.hpp:203,242) | ✅ |

**Differences:**

- *none*

## NSUserDefaults+Override

<a id="nsuserdefaultsoverride"></a>
Upstream `src/Core/NSUserDefaults+Override.m` ↔ `oofnd/Defaults.hpp` (`Defaults::synchronize`, `writeOpenStepPList`)

**Status:** done — 1 rows: 0 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSUserDefaults(Override) writeDictionary:]` (36) | `Defaults::synchronize` oofnd/Defaults.hpp:539. Empty domain → `fs::removeItem`; otherwise OpenStep text via `writeOpenStepPList`, written atomically by `fs::writeFile` (default `WriteMode::atomic`, oofnd/FileSystem.hpp:398) | ❌ |

**Differences:**

- ❌ **low** — The failure logs are gone. Upstream logged `NSUserDefaultsOverride` "Failed to serialize defaults database for writing: …" and "Failed to write defaults database to file: …", plus the empty-filename message. `synchronize()` only returns `false`, so a failed preferences save no longer shows in Latest.log — upstream `Core/NSUserDefaults+Override.m:39-40,54,56` ↔ port `oofnd/Defaults.hpp:551-567`

## OOAsyncQueue

<a id="ooasyncqueue"></a>
Upstream `src/Core/OOAsyncQueue.m` ↔ `Core/OOAsyncWorkManager.cpp` (`TaskQueue`). The log writer's message queue moved to `oofnd/LogFile.hpp`, which the OOLogOutputHandler section audits.

**Status:** done — 14 rows: 4 ✅ 0 ⚠️ 0 ❌ 10 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `AllocElement()` (62) | `std::deque` storage | ➖ |
| `FreeElement()` (67) | `std::deque` storage | ➖ |
| `-[OOAsyncQueue init]` (82) | `TaskQueue` default ctor Core/OOAsyncWorkManager.cpp:63 (mutex + condition_variable) | ➖ |
| `-[OOAsyncQueue dealloc]` (97) | implicit dtor (the manager is an immortal singleton; the `asyncQueue.nonEmpty` WARN path was unreachable) | ➖ |
| `-[OOAsyncQueue description]` (121) | none | ➖ |
| `-[OOAsyncQueue enqueue:]` (127) | `TaskQueue::enqueue` Core/OOAsyncWorkManager.cpp:65 (nil→false, task retained by `oo::Ref`, FIFO) | ✅ |
| `-[OOAsyncQueue dequeue]` (175) | `TaskQueue::dequeue` :77 (blocks until non-empty) | ✅ |
| `-[OOAsyncQueue tryDequeue]` (181) | `TaskQueue::tryDequeue` :87 (null when empty) | ✅ |
| `-[OOAsyncQueue empty]` (202) | none (no caller; upstream's answer was inverted, `_head != NULL`) | ➖ |
| `-[OOAsyncQueue count]` (207) | none (no caller) | ➖ |
| `-[OOAsyncQueue emptyQueue]` (212) | none (no caller) | ➖ |
| `-[OOAsyncQueue(OOPrivate) doEmptyQueueWithAcquiredLock]` (225) | none | ➖ |
| `-[OOAsyncQueue(OOPrivate) doDequeAndUnlockWithAcquiredLock]` (246) | folded into `dequeue`/`tryDequeue` :77-95 (returns `oo::Ref` where upstream autoreleased) | ✅ |
| `-[OOAsyncQueue(OOPrivate) recycleElementWithAcquiredLock:]` (280) | `std::deque` storage | ➖ |

**Differences:**

- subtle — Upstream's `doDequeAndUnlockWithAcquiredLock` could return nil when the head was NULL despite the condition ("can happen if you enter debugger"). The port's `dequeue` waits in a loop until there is a task — upstream `Core/OOAsyncQueue.m:251-254` ↔ port `Core/OOAsyncWorkManager.cpp:80-81`

## OOAsyncWorkManager

<a id="ooasyncworkmanager"></a>
Upstream `src/Core/OOAsyncWorkManager.m` ↔ `Core/OOAsyncWorkManager.cpp`

**Status:** done — 24 rows: 15 ✅ 4 ⚠️ 0 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitAsyncWorkManager()` (95) | `InitAsyncWorkManager` `Core/OOAsyncWorkManager.cpp:228` | ✅ |
| `+[OOAsyncWorkManager initialize]` (121) | `sInitLock` (std::mutex, Windows only) `Core/OOAsyncWorkManager.cpp:222` | ✅ |
| `+[OOAsyncWorkManager sharedAsyncWorkManager]` (130) | `OOAsyncWorkManager::sharedAsyncWorkManager` `Core/OOAsyncWorkManager.cpp:250` | ✅ |
| `+[OOAsyncWorkManager allocWithZone:]` (148) | — (singleton made once and leaked, `Core/OOAsyncWorkManager.cpp:223-226`) | ➖ |
| `-[OOAsyncWorkManager dealloc]` (157) | `~OOAsyncWorkManager` (abort) `Core/OOAsyncWorkManager.cpp:268` | ✅ |
| `-[OOAsyncWorkManager release]` (163) | — (immortal singleton) | ➖ |
| `-[OOAsyncWorkManager retain]` (167) | — (immortal singleton) | ➖ |
| `-[OOAsyncWorkManager retainCount]` (172) | — (immortal singleton) | ➖ |
| `-[OOAsyncWorkManager addTask:priority:]` (177) | `OOAsyncWorkManager::addTask` `Core/OOAsyncWorkManager.cpp:273` | ✅ |
| `-[OOAsyncWorkManager completePendingTasks]` (183) | `OOAsyncWorkManager::completePendingTasks` `Core/OOAsyncWorkManager.cpp:279` | ✅ |
| `-[OOAsyncWorkManager waitForTaskToComplete:]` (188) | `OOAsyncWorkManager::waitForTaskToComplete` `Core/OOAsyncWorkManager.cpp:284` | ✅ |
| `-[OOAsyncWorkManagerInternal init]` (198) | `OOAsyncWorkManagerInternal()` `Core/OOAsyncWorkManager.cpp:292` | ✅ |
| `-[OOAsyncWorkManagerInternal completePendingTasks]` (220) | `OOAsyncWorkManagerInternal::completePendingTasks` `Core/OOAsyncWorkManager.cpp:297` | ✅ |
| `-[OOAsyncWorkManagerInternal waitForTaskToComplete:]` (236) | `OOAsyncWorkManagerInternal::waitForTaskToComplete` `Core/OOAsyncWorkManager.cpp:313` | ✅ |
| `-[OOAsyncWorkManagerInternal queueResult:]` (268) | `OOAsyncWorkManagerInternal::queueResult` (`hasCompleteAsyncTask()` for `respondsToSelector:`) `Core/OOAsyncWorkManager.cpp:345` | ✅ |
| `-[OOAsyncWorkManagerInternal noteTaskQueued:]` (275) | `OOAsyncWorkManagerInternal::noteTaskQueued` (identity set) `Core/OOAsyncWorkManager.cpp:352` | ✅ |
| `-[OOManualDispatchAsyncWorkManager init]` (293) | `OOManualDispatchAsyncWorkManager()` + `WorkThreadCount` `:172` + `StartWorkThreads` `:187` `Core/OOAsyncWorkManager.cpp:362` | ✅ |
| `-[OOManualDispatchAsyncWorkManager addTask:priority:]` (318) | `OOManualDispatchAsyncWorkManager::addTask` `Core/OOAsyncWorkManager.cpp:370` | ✅ |
| `-[OOManualDispatchAsyncWorkManager queueTask:]` (329) | `OOManualDispatchAsyncWorkManager::queueTask` + `SetUpWorkThread` `:199` `Core/OOAsyncWorkManager.cpp:381` | ⚠️ |
| `+[OOOperationQueueAsyncWorkManager canBeUsed]` (363) | `OOOperationQueueAsyncWorkManager::canBeUsed` `Core/OOAsyncWorkManager.cpp:409` | ⚠️ |
| `-[OOOperationQueueAsyncWorkManager init]` (371) | `OOOperationQueueAsyncWorkManager()` `Core/OOAsyncWorkManager.cpp:414` | ⚠️ |
| `-[OOOperationQueueAsyncWorkManager dealloc]` (385) | — (immortal singleton; queue never freed) | ➖ |
| `-[OOOperationQueueAsyncWorkManager addTask:priority:]` (392) | `OOOperationQueueAsyncWorkManager::addTask` `Core/OOAsyncWorkManager.cpp:420` | ✅ |
| `-[OOOperationQueueAsyncWorkManager dispatchTask:]` (413) | `OOOperationQueueAsyncWorkManager::dispatchTask` + `workThread` `:441` `Core/OOAsyncWorkManager.cpp:470` | ⚠️ |

**Differences:**

- ⚠️ **low** — task exceptions: upstream `@catch (id)` swallowed everything; port catches only game exceptions (`oo::CurrentOOException()`) and rethrows the rest on a detached thread (→ `std::terminate`). Cited bead oo-rskgl.1 — upstream `Core/OOAsyncWorkManager.m:342-346,415-419` ↔ port `Core/OOAsyncWorkManager.cpp:391-396,472-477`
- ⚠️ **low** — NSOperationQueue replaced by a fixed pool of `WorkThreadCount()` = min(OOCPUCount(), 8) (8 in OO_DEBUG) threads named "OOAsyncWorkManager thread N" at priority 0.5, high→low then FIFO (bead oo-3rb.6). Concurrency and completion order of async tasks (texture loads, cache write) can differ; no log text changes — upstream `Core/OOAsyncWorkManager.m:371-411` ↔ port `Core/OOAsyncWorkManager.cpp:409-468`
- ⚠️ **low** — `canBeUsed` no longer checks that `NSInvocationOperation` exists, only `disable-operation-queue-work-manager`. On GNUstep 1.31 (OO_HAVE_NSOPERATION=0, class present) both select the operation-queue manager — upstream `Core/OOAsyncWorkManager.m:363-368` ↔ port `Core/OOAsyncWorkManager.cpp:409-412`
- ✅ subtle — the `asyncWorkManager.dispatchMethod` line prints the class name as a literal ("OOOperationQueueAsyncWorkManager"), matching `%@` of `[sSingleton class]` — upstream `Core/OOAsyncWorkManager.m:115` ↔ port `Core/OOAsyncWorkManager.cpp:247`
- ✅ subtle — the base `waitForTaskToComplete` exception text uses C++ `__PRETTY_FUNCTION__` (not "-[OOAsyncWorkManager waitForTaskToComplete:]"); reached only on a subclass-responsibility bug — upstream `Core/OOAsyncWorkManager.m:191` ↔ port `Core/OOAsyncWorkManager.cpp:287`


## OOCPUInfo

<a id="oocpuinfo"></a>
Upstream `src/Core/OOCPUInfo.m` ↔ `Core/OOCPUInfo.cpp`

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOCPUInfoInit()` (60) | `OOCPUInfoInit` `Core/OOCPUInfo.cpp:63` | ✅ |
| `OOCPUCount()` (99) | `OOCPUCount` `Core/OOCPUInfo.cpp:102` | ✅ |
| `OOCPUID()` (115) | `OOCPUID` `Core/OOCPUInfo.cpp:114` | ✅ |
| `OOCPUDescription()` (132) | `OOCPUDescription` `Core/OOCPUInfo.cpp:131` | ✅ |
| `OOSystemMemoryStatus()` (154) | `OOSystemMemoryStatus` `Core/OOCPUInfo.cpp:153` | ✅ |
| `operatingSystemFullVersion()` (181) | `operatingSystemFullVersion` `Core/OOCPUInfo.cpp:180` | ✅ |
| `is64BitSystem()` (210) | `is64BitSystem` `Core/OOCPUInfo.cpp:212` | ✅ |

**Differences:**

- ✅ subtle — `operatingSystemFullVersion`'s `%S` service-pack string is converted UTF-16→UTF-8 explicitly and printed with `%s`, as `-stringWithFormat:` did; feeds the log header's "Windows <ver> 64-bit" line — upstream `Core/OOCPUInfo.m:202-203` ↔ port `Core/OOCPUInfo.cpp:201-205`
- ✅ subtle — `OOCPUDescription` keeps the original's uninitialised `CPUBrandString` when the CPU reports fewer than 0x80000004 extended leaves (same UB both sides); the endian-test log lines keep class `cpuInfo.endianTest.failed` — upstream `Core/OOCPUInfo.m:132-151` ↔ port `Core/OOCPUInfo.cpp:131-150`


## OOCache

<a id="oocache"></a>
Upstream `src/Core/OOCache.m` ↔ `Core/OOCache.cpp`

**Status:** done — 48 rows: 44 ✅ 3 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCache dealloc]` (185) | `~OOCache` `Core/OOCache.cpp:180` | ✅ |
| `-[OOCache description]` (193) | `OOCache::descriptionComponents` `Core/OOCache.cpp:188` | ✅ |
| `-[OOCache init]` (198) | `OOCache::cacheWithPList(oo::PList())` `Core/OOCache.cpp:193` | ✅ |
| `-[OOCache initWithPList:]` (203) | `OOCache::initWithPList` `Core/OOCache.cpp:201` | ✅ |
| `-[OOCache pListRepresentation]` (235) | `OOCache::pListRepresentation` `Core/OOCache.cpp:225` | ✅ |
| `-[OOCache objectForKey:]` (242) | `OOCache::pListForKey` `Core/OOCache.cpp:230` | ✅ |
| `-[OOCache setObject:forKey:]` (256) | `OOCache::setPList` `Core/OOCache.cpp:245` | ✅ |
| `-[OOCache removeObjectForKey:]` (269) | `OOCache::removePListForKey` `Core/OOCache.cpp:258` | ✅ |
| `-[OOCache setPruneThreshold:]` (279) | `OOCache::setPruneThreshold` `Core/OOCache.cpp:268` | ✅ |
| `-[OOCache pruneThreshold]` (289) | `OOCache::pruneThreshold` `Core/OOCache.cpp:278` | ✅ |
| `-[OOCache setAutoPrune:]` (294) | `OOCache::setAutoPrune` `Core/OOCache.cpp:283` | ✅ |
| `-[OOCache autoPrune]` (303) | `OOCache::autoPrune` `Core/OOCache.cpp:292` | ✅ |
| `-[OOCache prune]` (308) | `OOCache::prune` `Core/OOCache.cpp:297` | ✅ |
| `-[OOCache dirty]` (335) | `OOCache::dirty` `Core/OOCache.cpp:327` | ✅ |
| `-[OOCache markClean]` (340) | `OOCache::markClean` `Core/OOCache.cpp:332` | ✅ |
| `-[OOCache name]` (345) | `OOCache::name` `Core/OOCache.cpp:337` | ✅ |
| `-[OOCache setName:]` (350) | `OOCache::setName` `Core/OOCache.cpp:342` | ✅ |
| `-[OOCache objectsByAge]` (355) | `OOCache::pListsByAge` `Core/OOCache.cpp:347` | ⚠️ |
| `-[OOCache(Private) loadFromArray:]` (364) | `OOCache::loadFromArray` `Core/OOCache.cpp:354` | ✅ |
| `CacheAllocate()` (414) | `CacheAllocate` `Core/OOCache.cpp:399` | ✅ |
| `CacheFree()` (419) | `CacheFree` `Core/OOCache.cpp:404` | ✅ |
| `CacheInsert()` (429) | `CacheInsert` `Core/OOCache.cpp:413` | ✅ |
| `CacheRemove()` (444) | `CacheRemove` `Core/OOCache.cpp:428` | ✅ |
| `CacheRemoveOldest()` (471) | `CacheRemoveOldest` `Core/OOCache.cpp:456` | ✅ |
| `CacheRetrieve()` (481) | `CacheRetrieve` `Core/OOCache.cpp:468` | ✅ |
| `CacheArrayOfContentsByAge()` (497) | `CacheArrayOfContentsByAge` `Core/OOCache.cpp:487` | ⚠️ |
| `CacheArrayOfNodesByAge()` (513) | `CacheArrayOfNodesByAge` `Core/OOCache.cpp:504` | ✅ |
| `CacheGetName()` (529) | `CacheGetName` `Core/OOCache.cpp:523` | ✅ |
| `CacheSetName()` (534) | `CacheSetName` `Core/OOCache.cpp:528` | ✅ |
| `CacheGetCount()` (540) | `CacheGetCount` `Core/OOCache.cpp:535` | ✅ |
| `CacheCheckIntegrity()` (547) | `CacheCheckIntegrity` (compiled out) `Core/OOCache.cpp:542` | ✅ |
| `CacheNodeAllocate()` (569) | `CacheNodeAllocate` `Core/OOCache.cpp:564` | ✅ |
| `CacheNodeFree()` (586) | `CacheNodeFree` `Core/OOCache.cpp:574` | ✅ |
| `CacheNodeGetValue()` (610) | `CacheNodeGetValue` `Core/OOCache.cpp:588` | ✅ |
| `CacheNodeSetValue()` (619) | `CacheNodeSetValue` `Core/OOCache.cpp:597` | ✅ |
| `CacheNodeGetDescription()` (631) | `CacheNodeGetDescription` (compiled out) `Core/OOCache.cpp:607` | ✅ |
| `TreeSplay()` (649) | `TreeSplay` `Core/OOCache.cpp:625` | ⚠️ |
| `TreeInsert()` (721) | `TreeInsert` `Core/OOCache.cpp:695` | ✅ |
| `TreeCountNodes()` (774) | `TreeCountNodes` (compiled out) `Core/OOCache.cpp:748` | ✅ |
| `TreeCheckIntegrity()` (782) | `TreeCheckIntegrity` (compiled out) `Core/OOCache.cpp:756` | ✅ |
| `AgeListMakeYoungest()` (835) | `AgeListMakeYoungest` `Core/OOCache.cpp:804` | ✅ |
| `AgeListRemove()` (850) | `AgeListRemove` `Core/OOCache.cpp:819` | ✅ |
| `AgeListCheckIntegrity()` (877) | `AgeListCheckIntegrity` (compiled out) `Core/OOCache.cpp:846` | ✅ |
| `-[OOCache(DebugGraphViz) appendNodesFromSubTree:toString:]` (959) | `OOCache::appendNodesFromSubTree` `Core/OOCache.cpp:922` | ✅ |
| `-[OOCache(DebugGraphViz) generateGraphVizBodyWithRootNamed:]` (973) | `OOCache::generateGraphVizBodyWithRootNamed` `Core/OOCache.cpp:936` | ✅ |
| `-[OOCache(DebugGraphViz) generateGraphViz]` (1008) | `OOCache::generateGraphViz` `Core/OOCache.cpp:969` | ✅ |
| `-[OOCache(DebugGraphViz) writeGraphVizToURL:]` (1029) | folded into `writeGraphVizToPath` (bead oo-3rb.264) `Core/OOCache.cpp:988` | ➖ |
| `-[OOCache(DebugGraphViz) writeGraphVizToPath:]` (1042) | `OOCache::writeGraphVizToPath` `Core/OOCache.cpp:989` | ✅ |

**Differences:**

- ⚠️ **low** — keys are `std::string` ordered by `std::string::compare` (UTF-8 bytes) instead of `-[NSString compare:]` (UTF-16 units, non-literal). Only the splay-tree shape changes for keys mixing supplementary and U+E000–U+FFFF characters; lookups, age order and `pListRepresentation` (age order) are unaffected. Documented `Core/OOCache.cpp:139` — upstream `Core/OOCache.m:669-691` ↔ port `Core/OOCache.cpp:643-665`
- ⚠️ **low** — `objectsByAge` of an empty cache returns an empty vector, not nil (documented `Core/OOCache.cpp:486`) — upstream `Core/OOCache.m:502-503` ↔ port `Core/OOCache.cpp:492-493`
- ✅ subtle — prune logging unchanged: class `dataCache.prune.<name>` (nil name → "(null)"), "Pruning cache \"%@\" - removing %u entries", per-entry "Pruning cache \"%@\": removing %@", indented under `indentIf`/`outdentIf` — upstream `Core/OOCache.m:325-332,477` ↔ port `Core/OOCache.cpp:317-324,462`
- ✅ subtle — loading from a plist leaves the cache dirty and unpruned (prune threshold 0 / autoPrune off until after `loadFromArray`) in both — upstream `Core/OOCache.m:216-225` ↔ port `Core/OOCache.cpp:211-220`, `Core/OOCache.h:109-112`
- ✅ subtle — `pListForKey` returns a copy of the stored `oo::PList` where `-objectForKey:` returned the same retained object; values are immutable plist data, so no observable effect — upstream `Core/OOCache.m:253` ↔ port `Core/OOCache.cpp:236-237`
- ✅ subtle — the debug-only `node->key is NULL` check in `TreeSplay` and the nil-key check in `TreeCheckIntegrity` are gone (a `std::string` key cannot be nil) — upstream `Core/OOCache.m:665-667,790-793` ↔ port `Core/OOCache.cpp:638-642,764`


## OOCacheManager

<a id="oocachemanager"></a>
Upstream `src/Core/OOCacheManager.m` ↔ `Core/OOCacheManager.cpp`

**Status:** done — 36 rows: 28 ✅ 2 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCacheManager init]` (112) | `OOCacheManager::init` `Core/OOCacheManager.cpp:107` | ✅ |
| `-[OOCacheManager dealloc]` (122) | `~OOCacheManager` `Core/OOCacheManager.cpp:113` | ✅ |
| `-[OOCacheManager description]` (129) | `OOCacheManager::descriptionComponents` `Core/OOCacheManager.cpp:120` | ✅ |
| `+[OOCacheManager sharedCache]` (134) | `OOCacheManager::sharedCache` `Core/OOCacheManager.cpp:125` | ✅ |
| `-[OOCacheManager objectForKey:inCache:]` (144) | `OOCacheManager::pListForKey` `Core/OOCacheManager.cpp:137` | ✅ |
| `-[OOCacheManager setObject:forKey:inCache:]` (166) | `OOCacheManager::setPList` `Core/OOCacheManager.cpp:164` | ✅ |
| `-[OOCacheManager removeObjectForKey:inCache:]` (190) | `OOCacheManager::removeObjectForKey` `Core/OOCacheManager.cpp:179` | ✅ |
| `-[OOCacheManager clearCache:]` (210) | `OOCacheManager::clearCache` `Core/OOCacheManager.cpp:200` | ✅ |
| `-[OOCacheManager clearAllCaches]` (223) | `OOCacheManager::clearAllCaches` `Core/OOCacheManager.cpp:215` | ✅ |
| `-[OOCacheManager reloadAllCaches]` (230) | `OOCacheManager::reloadAllCaches` `Core/OOCacheManager.cpp:222` | ✅ |
| `-[OOCacheManager flush]` (236) | `OOCacheManager::flush` `Core/OOCacheManager.cpp:228` | ✅ |
| `-[OOCacheManager finishOngoingFlush]` (244) | `OOCacheManager::finishOngoingFlush` `Core/OOCacheManager.cpp:236` | ✅ |
| `-[OOCacheManager setAllowCacheWrites:]` (251) | `OOCacheManager::setAllowCacheWrites` `Core/OOCacheManager.cpp:243` | ✅ |
| `-[OOCacheManager cacheDirectoryPathCreatingIfNecessary:]` (256) | `OOCacheManager::cacheDirectoryPathCreatingIfNecessary` (`ResourcePaths::cachesDirectory()`, `oofnd/ResourcePaths.hpp:188`) `Core/OOCacheManager.cpp:248` | ✅ |
| `-[OOCacheManager(Private) loadCache]` (285) | `OOCacheManager::loadCache` (+ `OoliteInfoString` `:91`) `Core/OOCacheManager.cpp:273` | ✅ |
| `-[OOCacheManager(Private) write]` (348) | `OOCacheManager::write` `Core/OOCacheManager.cpp:334` | ✅ |
| `-[OOCacheManager(Private) clear]` (417) | `OOCacheManager::clear` `Core/OOCacheManager.cpp:394` | ✅ |
| `-[OOCacheManager(Private) dirty]` (423) | `OOCacheManager::dirty` `Core/OOCacheManager.cpp:399` | ✅ |
| `-[OOCacheManager(Private) markClean]` (428) | `OOCacheManager::markClean` `Core/OOCacheManager.cpp:404` | ✅ |
| `-[OOCacheManager(Private) loadDict]` (433) | `OOCacheManager::loadDict` `Core/OOCacheManager.cpp:409` | ⚠️ |
| `-[OOCacheManager(Private) writeDict:]` (472) | `OOCacheManager::writeDict` `Core/OOCacheManager.cpp:430` | ⚠️ |
| `-[OOCacheManager(Private) buildCachesFromDictionary:]` (513) | `OOCacheManager::buildCachesFromDictionary` `Core/OOCacheManager.cpp:464` | ✅ |
| `-[OOCacheManager(Private) dictionaryOfCaches]` (537) | `OOCacheManager::dictionaryOfCaches` `Core/OOCacheManager.cpp:485` | ✅ |
| `-[OOCacheManager(Private) directoryExists:create:]` (542) | `OOCacheManager::directoryExists` `Core/OOCacheManager.cpp:497` | ✅ |
| `-[OOCacheManager(Private) cachePathCreatingIfNecessary:]` (567) | `OOCacheManager::cachePathCreatingIfNecessary` (Mac) `Core/OOCacheManager.cpp:521` | ✅ |
| `-[OOCacheManager(Private) cachePathCreatingIfNecessary:]` (575) | `OOCacheManager::cachePathCreatingIfNecessary` `Core/OOCacheManager.cpp:531` | ✅ |
| `+[OOCacheManager(Singleton) allocWithZone:]` (594) | — (singleton leaked once, `Core/OOCacheManager.cpp:129-131`) | ➖ |
| `-[OOCacheManager(Singleton) copyWithZone:]` (603) | — | ➖ |
| `-[OOCacheManager(Singleton) retain]` (608) | — | ➖ |
| `-[OOCacheManager(Singleton) retainCount]` (613) | — | ➖ |
| `-[OOCacheManager(Singleton) release]` (618) | — | ➖ |
| `-[OOCacheManager(Singleton) autorelease]` (622) | — | ➖ |
| `-[OOAsyncCacheWriter initWithCacheContents:]` (632) | `OOAsyncCacheWriter::writerWithCacheContents` `Core/OOCacheManager.cpp:541` | ✅ |
| `-[OOAsyncCacheWriter dealloc]` (645) | implicit `~OOAsyncCacheWriter` `Core/OOCacheManager.h:106` | ✅ |
| `-[OOAsyncCacheWriter performAsyncTask]` (652) | `OOAsyncCacheWriter::performAsyncTask` `Core/OOCacheManager.cpp:548` | ✅ |
| `-[OOAsyncCacheWriter completeAsyncTask]` (662) | `OOAsyncCacheWriter::completeAsyncTask` (+ `hasCompleteAsyncTask` → true, `Core/OOCacheManager.h:112`) `Core/OOCacheManager.cpp:558` | ✅ |

**Differences:**

- ⚠️ **low** — the cache file is written as XML (`oo::writeXMLPList`) instead of GNUstep binary; an existing GNUstep-binary `Oolite-cache.plist` is unreadable, so the first run logs `dataCache.badData` "Could not read data cache: binary property lists are not supported by oofnd" and rebuilds, where upstream logged `dataCache.found` "Found data cache." (ADR-0027 item 3, comment `Core/OOCacheManager.cpp:43-45`) — upstream `Core/OOCacheManager.m:449-464,486` ↔ port `Core/OOCacheManager.cpp:419-423,440`
- ⚠️ **low** — `dataCache.badData` / `dataCache.write.serialize.failed` carry oofnd's parser/writer error text instead of GNUstep's `errorDescription` — upstream `Core/OOCacheManager.m:460,491` ↔ port `Core/OOCacheManager.cpp:421,442`
- ✅ subtle — the Oolite version compared against the cache is `CFBundleVersion` read from `Info-gnustep.plist` in the built-in resources instead of `[[NSBundle mainBundle] infoDictionary]`; a missing version still mismatches and prints "(null)" — upstream `Core/OOCacheManager.m:295,306-309` ↔ port `Core/OOCacheManager.cpp:278,291-294`
- ✅ subtle — `writeDict` failing at `cachePathCreatingIfNecessary` returns before clearing `_scheduledWrite` in both, so later flushes are skipped for the session (faithful) — upstream `Core/OOCacheManager.m:478-480,508` ↔ port `Core/OOCacheManager.cpp:432-434,459`
- ✅ subtle — the `dataCache.retrieve/set/remove/clear.*` lines are OO_DEBUG-only in both (`OODebugLog`) — upstream `Core/OOCacheManager.m:155-217` ↔ port `Core/OOCacheManager.cpp:147-211`


## OOCollectionExtractors

<a id="oocollectionextractors"></a>
Upstream `src/Core/OOCollectionExtractors.m` (+ `.h` inlines) ↔ `oofnd/PListGet.hpp` (`PList::get<T>` / `at<T>`, `PListGet<T>`, `plist_get::*`), `Core/OOPListGameTypes.{h,cpp}` (Vector/HPVector/Quaternion/fuzzy boolean), and the NSUserDefaults call sites

**Status:** done — 203 rows: 120 ✅ 2 ⚠️ 5 ❌ 76 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSArray(OOExtractor) oo_charAtIndex:defaultValue:]` (41) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<char>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_shortAtIndex:defaultValue:]` (46) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<short>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_intAtIndex:defaultValue:]` (51) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<int>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_longAtIndex:defaultValue:]` (56) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_longLongAtIndex:defaultValue:]` (61) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_integerAtIndex:defaultValue:]` (66) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedCharAtIndex:defaultValue:]` (71) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<unsigned char>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedShortAtIndex:defaultValue:]` (76) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<unsigned short>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedIntAtIndex:defaultValue:]` (81) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<unsigned int>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedLongAtIndex:defaultValue:]` (86) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<unsigned long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedLongLongAtIndex:defaultValue:]` (91) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<unsigned long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedIntegerAtIndex:defaultValue:]` (96) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<unsigned long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_boolAtIndex:defaultValue:]` (101) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<bool>` oofnd/PListGet.hpp:577 | ✅ |
| `-[NSArray(OOExtractor) oo_fuzzyBooleanAtIndex:defaultValue:]` (107) | no `at<>` form (no caller); `OOFuzzyBooleanFromPList` Core/OOPListGameTypes.cpp:135 | ➖ |
| `-[NSArray(OOExtractor) oo_floatAtIndex:defaultValue:]` (113) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<float>` oofnd/PListGet.hpp:586 | ✅ |
| `-[NSArray(OOExtractor) oo_doubleAtIndex:defaultValue:]` (118) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<double>` oofnd/PListGet.hpp:586 | ✅ |
| `-[NSArray(OOExtractor) oo_nonNegativeFloatAtIndex:defaultValue:]` (123) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<NonNegative<float>>` oofnd/PListGet.hpp:594 | ✅ |
| `-[NSArray(OOExtractor) oo_nonNegativeDoubleAtIndex:defaultValue:]` (128) | `PList::at<T>` oofnd/PListGet.hpp:661 → `PListGet<NonNegative<double>>` oofnd/PListGet.hpp:594 | ✅ |
| `-[NSArray(OOExtractor) oo_objectAtIndex:defaultValue:]` (133) | `PList::at<T>` with T=`PList` → `PListGet<PList>` oofnd/PListGet.hpp:622 | ✅ |
| `-[NSArray(OOExtractor) oo_objectOfClass:atIndex:defaultValue:]` (146) | none: a runtime `Class` has no PList form; callers test the node kind / `dynamic_cast` (e.g. Entities/PlanetEntity texture object) | ➖ |
| `-[NSArray(OOExtractor) oo_stringAtIndex:defaultValue:]` (159) | `PList::at<T>` → `PListGet<std::string>` oofnd/PListGet.hpp:604 | ✅ |
| `-[NSArray(OOExtractor) oo_arrayAtIndex:defaultValue:]` (164) | `PList::at<T>` T=`PList::Array` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSArray(OOExtractor) oo_setAtIndex:defaultValue:]` (169) | none: PList has no set; callers read the array (e.g. Core/ResourceManager.cpp:126 `get<PList::Array>`) | ➖ |
| `-[NSArray(OOExtractor) oo_dictionaryAtIndex:defaultValue:]` (174) | `PList::at<T>` T=`PList::Dict` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSArray(OOExtractor) oo_dataAtIndex:defaultValue:]` (179) | `PList::at<T>` T=`PList::Data` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSArray(OOExtractor) oo_vectorAtIndex:defaultValue:]` (185) | `PList::at<T>` → `PListGet<Vector>` Core/OOPListGameTypes.h:59 → `OOVectorFromPList` Core/OOPListGameTypes.cpp:40 | ✅ |
| `-[NSArray(OOExtractor) oo_quaternionAtIndex:defaultValue:]` (190) | `PList::at<T>` → `PListGet<Quaternion>` Core/OOPListGameTypes.h:75 → `OOQuaternionFromPList` Core/OOPListGameTypes.cpp:95 | ✅ |
| `-[NSArray(OOExtractor) oo_charAtIndex:]` (196) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<char>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_shortAtIndex:]` (201) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<short>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_intAtIndex:]` (206) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<int>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_longAtIndex:]` (211) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_longLongAtIndex:]` (216) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_integerAtIndex:]` (221) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedCharAtIndex:]` (226) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<unsigned char>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedShortAtIndex:]` (231) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<unsigned short>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedIntAtIndex:]` (236) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<unsigned int>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedLongAtIndex:]` (241) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<unsigned long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedLongLongAtIndex:]` (246) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<unsigned long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedIntegerAtIndex:]` (251) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<unsigned long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSArray(OOExtractor) oo_boolAtIndex:]` (256) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<bool>` oofnd/PListGet.hpp:577 | ✅ |
| `-[NSArray(OOExtractor) oo_fuzzyBooleanAtIndex:]` (262) | no `at<>` form (no caller); `OOFuzzyBooleanFromPList` Core/OOPListGameTypes.cpp:135 | ➖ |
| `-[NSArray(OOExtractor) oo_floatAtIndex:]` (268) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<float>` oofnd/PListGet.hpp:586 | ✅ |
| `-[NSArray(OOExtractor) oo_doubleAtIndex:]` (273) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<double>` oofnd/PListGet.hpp:586 | ✅ |
| `-[NSArray(OOExtractor) oo_nonNegativeFloatAtIndex:]` (278) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<NonNegative<float>>` oofnd/PListGet.hpp:594 | ✅ |
| `-[NSArray(OOExtractor) oo_nonNegativeDoubleAtIndex:]` (283) | `PList::at<T>` oofnd/PListGet.hpp:669 → `PListGet<NonNegative<double>>` oofnd/PListGet.hpp:594 | ✅ |
| `-[NSArray(OOExtractor) oo_objectAtIndex:]` (288) | `PList::at(index)` oofnd/PList.hpp:258 (nullptr past the end) | ✅ |
| `-[NSArray(OOExtractor) oo_objectOfClass:atIndex:]` (296) | none: a runtime `Class` has no PList form; callers test the node kind / `dynamic_cast` (e.g. Entities/PlanetEntity texture object) | ➖ |
| `-[NSArray(OOExtractor) oo_stringAtIndex:]` (301) | `PList::at<T>` with fallback `""` oofnd/PListGet.hpp:607 (nil is not representable) | ⚠️ |
| `-[NSArray(OOExtractor) oo_arrayAtIndex:]` (306) | `PList::at<T>` T=`PList::Array` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSArray(OOExtractor) oo_setAtIndex:]` (311) | none: PList has no set; callers read the array (e.g. Core/ResourceManager.cpp:126 `get<PList::Array>`) | ➖ |
| `-[NSArray(OOExtractor) oo_dictionaryAtIndex:]` (316) | `PList::at<T>` T=`PList::Dict` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSArray(OOExtractor) oo_dataAtIndex:]` (321) | `PList::at<T>` T=`PList::Data` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSArray(OOExtractor) oo_vectorAtIndex:]` (327) | `PList::at<T>` → `PListGet<Vector>` Core/OOPListGameTypes.h:59 → `OOVectorFromPList` Core/OOPListGameTypes.cpp:40 (default kZeroVector, h:62) | ✅ |
| `-[NSArray(OOExtractor) oo_quaternionAtIndex:]` (332) | `PList::at<T>` → `PListGet<Quaternion>` Core/OOPListGameTypes.h:75 → `OOQuaternionFromPList` Core/OOPListGameTypes.cpp:95 (default kIdentityQuaternion, h:78) | ✅ |
| `-[NSDictionary(OOExtractor) oo_charForKey:defaultValue:]` (342) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<char>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_shortForKey:defaultValue:]` (347) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<short>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_intForKey:defaultValue:]` (352) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<int>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_longForKey:defaultValue:]` (357) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_longLongForKey:defaultValue:]` (362) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_integerForKey:defaultValue:]` (367) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedCharForKey:defaultValue:]` (372) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<unsigned char>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedShortForKey:defaultValue:]` (377) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<unsigned short>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedIntForKey:defaultValue:]` (382) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<unsigned int>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedLongForKey:defaultValue:]` (387) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<unsigned long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedLongLongForKey:defaultValue:]` (392) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<unsigned long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedIntegerForKey:defaultValue:]` (397) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<unsigned long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_boolForKey:defaultValue:]` (402) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<bool>` oofnd/PListGet.hpp:577 | ✅ |
| `-[NSDictionary(OOExtractor) oo_fuzzyBooleanForKey:defaultValue:]` (408) | `OOFuzzyBooleanFromPList(dict.find(k), d)` Core/OOPListGameTypes.cpp:135 (via `FuzzyBooleanForKey` Entities/ShipEntity.cpp:232, Entities/StationEntity.cpp:977) | ✅ |
| `-[NSDictionary(OOExtractor) oo_floatForKey:defaultValue:]` (414) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<float>` oofnd/PListGet.hpp:586 | ✅ |
| `-[NSDictionary(OOExtractor) oo_doubleForKey:defaultValue:]` (419) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<double>` oofnd/PListGet.hpp:586 | ✅ |
| `-[NSDictionary(OOExtractor) oo_nonNegativeFloatForKey:defaultValue:]` (424) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<NonNegative<float>>` oofnd/PListGet.hpp:594 | ✅ |
| `-[NSDictionary(OOExtractor) oo_nonNegativeDoubleForKey:defaultValue:]` (429) | `PList::get<T>` oofnd/PListGet.hpp:647 → `PListGet<NonNegative<double>>` oofnd/PListGet.hpp:594 | ✅ |
| `-[NSDictionary(OOExtractor) oo_objectForKey:defaultValue:]` (434) | `PList::get<T>` with T=`PList` → `PListGet<PList>` oofnd/PListGet.hpp:622 | ✅ |
| `-[NSDictionary(OOExtractor) oo_objectOfClass:forKey:defaultValue:]` (447) | none: a runtime `Class` has no PList form; callers test the node kind / `dynamic_cast` (e.g. Entities/PlanetEntity texture object) | ➖ |
| `-[NSDictionary(OOExtractor) oo_stringForKey:defaultValue:]` (460) | `PList::get<T>` → `PListGet<std::string>` oofnd/PListGet.hpp:604 | ✅ |
| `-[NSDictionary(OOExtractor) oo_arrayForKey:defaultValue:]` (465) | `PList::get<T>` T=`PList::Array` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSDictionary(OOExtractor) oo_setForKey:defaultValue:]` (470) | none: PList has no set; callers read the array (e.g. Core/ResourceManager.cpp:126 `get<PList::Array>`) | ➖ |
| `-[NSDictionary(OOExtractor) oo_dictionaryForKey:defaultValue:]` (475) | `PList::get<T>` T=`PList::Dict` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSDictionary(OOExtractor) oo_mutableDictionaryForKey:defaultValue:]` (480) | none: PList has no mutable/immutable split; callers look up their own map (e.g. Core/OOCommodityMarket.cpp:332) | ➖ |
| `-[NSDictionary(OOExtractor) oo_dataForKey:defaultValue:]` (485) | `PList::get<T>` T=`PList::Data` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSDictionary(OOExtractor) oo_vectorForKey:defaultValue:]` (491) | `PList::get<T>` → `PListGet<Vector>` Core/OOPListGameTypes.h:59 → `OOVectorFromPList` Core/OOPListGameTypes.cpp:40 | ✅ |
| `-[NSDictionary(OOExtractor) oo_hpvectorForKey:defaultValue:]` (496) | `PList::get<T>` → `PListGet<HPVector>` Core/OOPListGameTypes.h:67 → `OOHPVectorFromPList` Core/OOPListGameTypes.cpp:71 | ✅ |
| `-[NSDictionary(OOExtractor) oo_quaternionForKey:defaultValue:]` (501) | `PList::get<T>` → `PListGet<Quaternion>` Core/OOPListGameTypes.h:75 → `OOQuaternionFromPList` Core/OOPListGameTypes.cpp:95 | ✅ |
| `-[NSDictionary(OOExtractor) oo_charForKey:]` (507) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<char>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_shortForKey:]` (512) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<short>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_intForKey:]` (517) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<int>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_longForKey:]` (522) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_longLongForKey:]` (527) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_integerForKey:]` (532) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedCharForKey:]` (537) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<unsigned char>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedShortForKey:]` (542) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<unsigned short>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedIntForKey:]` (547) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<unsigned int>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedLongForKey:]` (552) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<unsigned long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedIntegerForKey:]` (557) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<unsigned long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedLongLongForKey:]` (562) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<unsigned long long>::from` oofnd/PListGet.hpp:556 | ✅ |
| `-[NSDictionary(OOExtractor) oo_boolForKey:]` (567) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<bool>` oofnd/PListGet.hpp:577 | ✅ |
| `-[NSDictionary(OOExtractor) oo_fuzzyBooleanForKey:]` (573) | `OOFuzzyBooleanFromPList(dict.find(k), d)` Core/OOPListGameTypes.cpp:135 (via `FuzzyBooleanForKey` Entities/ShipEntity.cpp:232, Entities/StationEntity.cpp:977) | ✅ |
| `-[NSDictionary(OOExtractor) oo_floatForKey:]` (579) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<float>` oofnd/PListGet.hpp:586 | ✅ |
| `-[NSDictionary(OOExtractor) oo_doubleForKey:]` (584) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<double>` oofnd/PListGet.hpp:586 | ✅ |
| `-[NSDictionary(OOExtractor) oo_nonNegativeFloatForKey:]` (589) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<NonNegative<float>>` oofnd/PListGet.hpp:594 | ✅ |
| `-[NSDictionary(OOExtractor) oo_nonNegativeDoubleForKey:]` (594) | `PList::get<T>` oofnd/PListGet.hpp:655 → `PListGet<NonNegative<double>>` oofnd/PListGet.hpp:594 | ✅ |
| `-[NSDictionary(OOExtractor) oo_objectOfClass:forKey:]` (599) | none: a runtime `Class` has no PList form; callers test the node kind / `dynamic_cast` (e.g. Entities/PlanetEntity texture object) | ➖ |
| `-[NSDictionary(OOExtractor) oo_stringForKey:]` (604) | `PList::get<T>` with fallback `""` oofnd/PListGet.hpp:607 (nil is not representable) | ⚠️ |
| `-[NSDictionary(OOExtractor) oo_arrayForKey:]` (609) | `PList::get<T>` T=`PList::Array` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSDictionary(OOExtractor) oo_setForKey:]` (614) | none: PList has no set; callers read the array (e.g. Core/ResourceManager.cpp:126 `get<PList::Array>`) | ➖ |
| `-[NSDictionary(OOExtractor) oo_dictionaryForKey:]` (619) | `PList::get<T>` T=`PList::Dict` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSDictionary(OOExtractor) oo_mutableDictionaryForKey:]` (624) | none: PList has no mutable/immutable split; callers look up their own map (e.g. Core/OOCommodityMarket.cpp:332) | ➖ |
| `-[NSDictionary(OOExtractor) oo_dataForKey:]` (629) | `PList::get<T>` T=`PList::Data` → oofnd/PListGet.hpp:634 | ✅ |
| `-[NSDictionary(OOExtractor) oo_vectorForKey:]` (635) | `PList::get<T>` → `PListGet<Vector>` Core/OOPListGameTypes.h:59 → `OOVectorFromPList` Core/OOPListGameTypes.cpp:40 (default kZeroVector, h:62) | ✅ |
| `-[NSDictionary(OOExtractor) oo_hpvectorForKey:]` (640) | `PList::get<T>` → `PListGet<HPVector>` Core/OOPListGameTypes.h:67 → `OOHPVectorFromPList` Core/OOPListGameTypes.cpp:71 (default kZeroHPVector, h:70) | ✅ |
| `-[NSDictionary(OOExtractor) oo_quaternionForKey:]` (645) | `PList::get<T>` → `PListGet<Quaternion>` Core/OOPListGameTypes.h:75 → `OOQuaternionFromPList` Core/OOPListGameTypes.cpp:95 (default kIdentityQuaternion, h:78) | ✅ |
| `-[NSUserDefaults(OOExtractor) oo_charForKey:defaultValue:]` (655) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_shortForKey:defaultValue:]` (660) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_intForKey:defaultValue:]` (665) | call sites: `detailLevel` via `Defaults::integerForKey` (Core/Universe.cpp:308); `jsruntime-size-mib`, `enforce-oxp-standards` via `PListGet<int>::from` (Scripting/OOJavaScriptEngine.cpp:306, Debug/OODebugStandards.cpp:86) | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_longForKey:defaultValue:]` (670) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_longLongForKey:defaultValue:]` (675) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_integerForKey:defaultValue:]` (680) | call site `sky-color-correction` via `Defaults::integerForKey` (Core/OOSkyDrawable.cpp:500) | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedCharForKey:defaultValue:]` (685) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedShortForKey:defaultValue:]` (690) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedIntForKey:defaultValue:]` (695) | call site `max-texture-size`: `PListGet<unsigned int>::from` (Materials/OOTextureLoader.cpp:319) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedLongForKey:defaultValue:]` (700) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedLongLongForKey:defaultValue:]` (705) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedIntegerForKey:defaultValue:]` (710) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_boolForKey:defaultValue:]` (715) | call sites: `Defaults::boolForKey` behind an `object(k).isNull()` test (Core/Universe.cpp:318-344, Core/OOLogging.cpp:264-267, Core/GameController.cpp:303,1159); `PListGet<bool>::from` elsewhere (SDL/MyOpenGLView.cpp:167,315-319, Core/Materials/OOTexture.cpp:571, OXPVerifier/OOOXPVerifier.cpp:706) | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_fuzzyBooleanForKey:defaultValue:]` (721) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_floatForKey:defaultValue:]` (727) | call sites: `Defaults::floatForKey` for `fov-value` (Core/Universe.cpp:338) and the volume (Core/OOALSound.cpp:62); `PListGet<float>::from` elsewhere (Entities/OOSunEntity.cpp:125, Entities/PlayerEntity.cpp:2382,3852, SDL/MyOpenGLView.cpp:260-262,406, Materials/OOTexture.cpp:554, Materials/OOPlanetTextureGenerator.cpp:425) | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_doubleForKey:defaultValue:]` (732) | call sites: `Defaults::doubleForKey` for `animation_timer_interval` (Core/GameController.cpp:235); `PListGet<double>::from` for `flight-arrow-key-precision-factor` (Entities/PlayerEntityControls.cpp:3843) | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_nonNegativeFloatForKey:defaultValue:]` (737) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_nonNegativeDoubleForKey:defaultValue:]` (742) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_objectForKey:defaultValue:]` (747) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_objectOfClass:forKey:defaultValue:]` (760) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_stringForKey:defaultValue:]` (773) | call sites: `PListGet<std::string>::from` (SDL/MyOpenGLView.cpp:65 `DefaultsString`, Entities/PlayerEntityKeyMapper.cpp:76 `KeyboardCode`, Entities/PlayerEntityControls.cpp:293) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_arrayForKey:defaultValue:]` (778) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_setForKey:defaultValue:]` (783) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_dictionaryForKey:defaultValue:]` (788) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_dataForKey:defaultValue:]` (793) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_charForKey:]` (798) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_shortForKey:]` (803) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_intForKey:]` (808) | call site `detailLevel` (see the defaultValue: row; Core/Universe.cpp:308) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_longForKey:]` (813) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_longLongForKey:]` (818) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedCharForKey:]` (823) | call site `js-gc-zeal`: `PListGet<unsigned char>::from(v, 0)` (Scripting/OOJavaScriptEngine.cpp:342) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedShortForKey:]` (828) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedIntForKey:]` (833) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedLongForKey:]` (838) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedLongLongForKey:]` (843) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_fuzzyBooleanForKey:]` (849) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_doubleForKey:]` (855) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_nonNegativeFloatForKey:]` (860) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_nonNegativeDoubleForKey:]` (865) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_objectOfClass:forKey:]` (870) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_setForKey:]` (875) | no caller; a call site would use `PListGet<T>::from(defaults.object(k), d)` (oofnd/Defaults.hpp:446) | ➖ |
| `-[NSMutableArray(OOInserter) oo_addInteger:]` (884) | callers store `PList::signedInteger` / `PList(int64)` oofnd/PList.hpp:202 | ➖ |
| `-[NSMutableArray(OOInserter) oo_addUnsignedInteger:]` (889) | callers store `PList::unsignedInteger` oofnd/PList.hpp:203 | ➖ |
| `-[NSMutableArray(OOInserter) oo_addFloat:]` (894) | callers store `oo::PList(double)` oofnd/PList.hpp:160 (+numberWithDouble:) | ➖ |
| `-[NSMutableArray(OOInserter) oo_addBool:]` (899) | callers store `oo::PList(bool)` oofnd/PList.hpp:146 | ➖ |
| `-[NSMutableArray(OOInserter) oo_addVector:]` (905) | callers store `OOPListFromVector(v)` Core/OOPListGameTypes.cpp:120 (single-precision reals) | ➖ |
| `-[NSMutableArray(OOInserter) oo_addQuaternion:]` (910) | callers store `OOPListFromQuaternion(q)` Core/OOPListGameTypes.cpp:130 | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertInteger:atIndex:]` (916) | callers store `PList::signedInteger` / `PList(int64)` oofnd/PList.hpp:202 | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertUnsignedInteger:atIndex:]` (921) | callers store `PList::unsignedInteger` oofnd/PList.hpp:203 | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertFloat:atIndex:]` (926) | callers store `oo::PList(double)` oofnd/PList.hpp:160 (+numberWithDouble:) | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertBool:atIndex:]` (931) | callers store `oo::PList(bool)` oofnd/PList.hpp:146 | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertVector:atIndex:]` (937) | callers store `OOPListFromVector(v)` Core/OOPListGameTypes.cpp:120 (single-precision reals) | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertQuaternion:atIndex:]` (942) | callers store `OOPListFromQuaternion(q)` Core/OOPListGameTypes.cpp:130 | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setInteger:forKey:]` (952) | callers store `PList::signedInteger` / `PList(int64)` oofnd/PList.hpp:202 | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setUnsignedInteger:forKey:]` (957) | callers store `PList::unsignedInteger` oofnd/PList.hpp:203 | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setLongLong:forKey:]` (962) | callers store `PList::signedInteger` / `PList(int64)` oofnd/PList.hpp:202 | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setUnsignedLongLong:forKey:]` (967) | callers store `PList::unsignedInteger` oofnd/PList.hpp:203 | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setFloat:forKey:]` (972) | callers store `oo::PList(double)` oofnd/PList.hpp:160 (+numberWithDouble:) | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setBool:forKey:]` (977) | callers store `oo::PList(bool)` oofnd/PList.hpp:146 | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setVector:forKey:]` (983) | callers store `OOPListFromVector(v)` Core/OOPListGameTypes.cpp:120 (single-precision reals) | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setHPVector:forKey:]` (988) | callers store `OOPListFromHPVector(v)` Core/OOPListGameTypes.cpp:125 | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setQuaternion:forKey:]` (993) | callers store `OOPListFromQuaternion(q)` Core/OOPListGameTypes.cpp:130 | ➖ |
| `-[NSMutableSet(OOInserter) oo_addInteger:]` (1003) | no NSMutableSet of numbers in the port (no PList set); callers store `PList::signedInteger` / `PList(int64)` oofnd/PList.hpp:202 | ➖ |
| `-[NSMutableSet(OOInserter) oo_addUnsignedInteger:]` (1008) | no NSMutableSet of numbers in the port (no PList set); callers store `PList::unsignedInteger` oofnd/PList.hpp:203 | ➖ |
| `-[NSMutableSet(OOInserter) oo_addFloat:]` (1013) | no NSMutableSet of numbers in the port (no PList set); callers store `oo::PList(double)` oofnd/PList.hpp:160 (+numberWithDouble:) | ➖ |
| `-[NSMutableSet(OOInserter) oo_addBool:]` (1018) | no NSMutableSet of numbers in the port (no PList set); callers store `oo::PList(bool)` oofnd/PList.hpp:146 | ➖ |
| `-[NSMutableSet(OOInserter) oo_addVector:]` (1024) | no NSMutableSet of numbers in the port (no PList set); callers store `OOPListFromVector(v)` Core/OOPListGameTypes.cpp:120 (single-precision reals) | ➖ |
| `-[NSMutableSet(OOInserter) oo_addQuaternion:]` (1029) | no NSMutableSet of numbers in the port (no PList set); callers store `OOPListFromQuaternion(q)` Core/OOPListGameTypes.cpp:130 | ➖ |
| `OOLongLongFromObject()` (1037) | `plist_get::longLongFrom` oofnd/PListGet.hpp:325 | ✅ |
| `OOUnsignedLongLongFromObject()` (1053) | `plist_get::unsignedLongLongFrom` oofnd/PListGet.hpp:340 | ✅ |
| `IsSpaceOrTab()` (1071) | inlined in `plist_get::isZeroString` oofnd/PListGet.hpp:284 | ✅ |
| `IsZeroString()` (1076) | `plist_get::isZeroString` oofnd/PListGet.hpp:281 (the `' '`-for-`-` slip reproduced) | ✅ |
| `BooleanFromString()` (1098) | `plist_get::boolFrom` string branch oofnd/PListGet.hpp:360-368 | ✅ |
| `FuzzyBooleanProbabilityFromString()` (1111) | `plist_get::fuzzyProbabilityFrom` oofnd/PListGet.hpp:513-517 | ✅ |
| `OOBooleanFromObject()` (1124) | `plist_get::boolFrom` oofnd/PListGet.hpp:356 | ✅ |
| `OOFuzzyBooleanFromObject()` (1143) | `OOFuzzyBooleanFromPList` Core/OOPListGameTypes.cpp:135 + `fuzzyProbabilityFrom` oofnd/PListGet.hpp:503 | ✅ |
| `OOFloatFromObject()` (1167) | `plist_get::realFrom<float>` oofnd/PListGet.hpp:385 | ✅ |
| `OODoubleFromObject()` (1185) | `plist_get::realFrom<double>` oofnd/PListGet.hpp:385 | ✅ |
| `OONonNegativeFloatFromObject()` (1203) | `plist_get::nonNegativeRealFrom<float>` oofnd/PListGet.hpp:404 | ✅ |
| `OONonNegativeDoubleFromObject()` (1219) | `plist_get::nonNegativeRealFrom<double>` oofnd/PListGet.hpp:404 | ✅ |
| `OOVectorFromObject()` (1236) | `OOVectorFromPList` Core/OOPListGameTypes.cpp:40 + `tupleFrom` oofnd/PListGet.hpp:440 | ✅ |
| `OOHPVectorFromObject()` (1266) | `OOHPVectorFromPList` Core/OOPListGameTypes.cpp:71 + `tupleFrom` oofnd/PListGet.hpp:440 | ✅ |
| `OOQuaternionFromObject()` (1294) | `OOQuaternionFromPList` Core/OOPListGameTypes.cpp:95 + `tupleFrom` oofnd/PListGet.hpp:440 | ✅ |
| `OOPropertyListFromVector()` (1325) | `OOPListFromVector` Core/OOPListGameTypes.cpp:120 + `tuplePList` oofnd/PListGet.hpp:486 | ✅ |
| `OOPropertyListFromHPVector()` (1334) | `OOPListFromHPVector` Core/OOPListGameTypes.cpp:125 | ✅ |
| `OOPropertyListFromQuaternion()` (1343) | `OOPListFromQuaternion` Core/OOPListGameTypes.cpp:130 | ✅ |
| `SetForObject()` (1354) | none (no PList set kind) | ➖ |
| `StringForObject()` (1364) | `PListGet<std::string>::from` oofnd/PListGet.hpp:608 + `numberStringValue` oofnd/PListGet.hpp:521 | ✅ |
| `OOClampInteger()` (OOCollectionExtractors.h:386) | clamp in `PListGet<integral>::from` oofnd/PListGet.hpp:568-571 | ✅ |
| `OOCharFromObject()` / `OOUnsignedCharFromObject()` / `OOShortFromObject()` / `OOUnsignedShortFromObject()` (h:417-418, `OO_DEFINE_CLAMP_PAIR`) | `PListGet<integral>::from` narrow branch oofnd/PListGet.hpp:566-572 | ✅ |
| `OOIntFromObject()` / `OOUnsignedIntFromObject()` / `OOLongFromObject()` / `OOUnsignedLongFromObject()` (h:440, 446; LLP64: clamped) | `PListGet<integral>::from` narrow branch oofnd/PListGet.hpp:566-572 (sizeof(long)==4 on Windows) | ✅ |
| `OOIntegerFromObject()` / `OOUIntegerFromObject()` (h:450-457, OOLITE_64_BIT) | `PListGet<long long>` / `<unsigned long long>` oofnd/PListGet.hpp:562-565 | ✅ |

**Differences:**

- ❌ **low** — **NSUserDefaults `oo_boolForKey:defaultValue:` at 12 call sites is now `Defaults::boolForKey`.** That is GNUstep's `-[NSString boolValue]` (the first non-space/`0`/sign char is y/Y/t/T/1-9), not `OOBooleanFromObject`. Examples:
  - a prefs or argument value of `"on"` was YES and is now NO;
  - `".5"` / `"0.5"` was YES (non-zero `-doubleValue`) and is now NO;
  - an unrecognised word (`"maybe"`) was the default (YES for `ecoqos`, `logging-show-time`, `logging-show-class`, `procedurally-textured-planets`, `ecm-visual-fx`) and is now NO; `" yes"` was the default and is now YES.

  Values the game writes itself (setBool → YES/NO/1/0) read the same, so this needs a hand-edited plist or a `-key value` argument — upstream `Core/OOCollectionExtractors.m:715-718,1098-1108,1124-1140` (callers `Core/Universe.m:718-740`, `Core/OOLogging.m:654-657`, `Core/GameController.m:142,895`) ↔ port `oofnd/Defaults.hpp:90-101,474-479` (callers `Core/Universe.cpp:318-344`, `Core/OOLogging.cpp:264-267`, `Core/GameController.cpp:303,1159`)
- ❌ **low** — **NSUserDefaults `oo_floatForKey:` / `oo_doubleForKey:` with a default are now `Defaults::floatForKey` / `doubleForKey`.** An unparseable string such as `"abc"` gave the default (`OOFloatFromObject`'s IsZeroString test) and now gives 0:
  - `fov-value` 57.2 → 0, then clamped up to MIN_FOV;
  - volume 0.5 → 0 (silent);
  - `animation_timer_interval` MINIMUM_ANIMATION_TICK → 0.

  Upstream `Core/OOCollectionExtractors.m:727-735,1167-1201`, callers `Core/Universe.m:736`, `Core/OOALSound.m:53`, `Core/GameController.m:89` ↔ port `oofnd/Defaults.hpp:490-497`, callers `Core/Universe.cpp:338`, `Core/OOALSound.cpp:62`, `Core/GameController.cpp:235`
- ❌ **low** — **The port has two `-[NSString doubleValue]` implementations, and they disagree.** `plist_get::scanDoubleAt` ports NSScanner and keeps 18 digits, so `"9223372036854775807"` → 9.2233720368547758e17 and an exponent over 511 is no number. `defaults_detail::stringDoubleValue` uses `from_chars`, which rounds correctly, takes unlimited digits and turns overflow into inf. At most one can match GNUstep 1.31.1 for long mantissas and huge exponents. The Defaults call sites in the bullet above go through the second one; everything that used `OO*FromObject` goes through the first — port `oofnd/PListGet.hpp:149-263` ↔ port `oofnd/Defaults.hpp:163-191`
- ❌ **low** — **NSUserDefaults `oo_intForKey:` (`detailLevel`) and `oo_integerForKey:` (`sky-color-correction`) now use `Defaults::integerForKey`.** That has no 20-character `intBuf` limit, so `"000000000000000000001"` now reads 1 (upstream 0), and on positive overflow it reinterprets as -1 instead of saturating then clamping to INT_MAX. Ordinary values read the same — upstream `Core/OOCollectionExtractors.m:1037-1050` + h:440, callers `Core/Universe.m:707`, `Core/OOSkyDrawable.m:510` ↔ port `oofnd/Defaults.hpp:106-124,481-488`, callers `Core/Universe.cpp:308`, `Core/OOSkyDrawable.cpp:500`
- ⚠️ **low** — The no-default `oo_stringForKey:` / `oo_stringAtIndex:` returned nil for a missing or non-string value. `get<std::string>(k)` returns `""`, as documented in PListGet.hpp ("use get<PList> to test presence"). A converted caller that tested for nil now sees an empty string — upstream `Core/OOCollectionExtractors.m:301,604` ↔ port `oofnd/PListGet.hpp:601-618`
- subtle (✅) — `PList::get` / `at` on a **null** PList return `Result{}` (0, NO, `""`, nullptr, zero Vector/Quaternion), not the fallback. That is the faithful translation of messaging nil, including a zeroed (not identity) Quaternion — port `oofnd/PListGet.hpp:649-650,663-664`
- subtle (low) — `get<T>` on a non-dict, or `at<T>` on a non-array, returns the fallback. Upstream sent `oo_*ForKey:` to an NSArray/NSString and raised "unrecognized selector". Only reachable when a caller skipped the `get<PList::Dict>` kind check that upstream's `oo_dictionaryForKey:` forced — port `oofnd/PList.hpp:244-262`
- subtle (✅) — Exact on LLP64 Windows (ADR-0017): `long`/`unsigned long` are 32-bit and clamp through `OOLongLongFromObject`, as `OO_DEFINE_CLAMP_PAIR(long…)` did. PListGet.hpp notes that on LP64 upstream's `unsigned long` aliased the *signed* reading, and the port's size dispatch would read unsigned there. That is a Phase 5 concern — port `oofnd/PListGet.hpp:53-57,560-573`
- subtle (✅) — These conversions are replicated byte for byte and pinned by tests/unit/oofnd/test_plist_get.cpp:
  - the `IsZeroString` slip that tests `' '` instead of `'-'` (`"-0"` is not a zero string);
  - the redundant `doubleValue != 0` in `FuzzyBooleanProbabilityFromString` (`"1e-50"` → probability 1);
  - `fmax`'s NaN/-0 → +0 in the non-negative readers, with the default left unclamped;
  - the unsigned 64-bit reading of a string through `-intValue` (`"5000000000"` → 2147483647).

  Upstream `Core/OOCollectionExtractors.m:1091,1111-1120,1203-1233,1053-1068` ↔ port `oofnd/PListGet.hpp:281-287,503-518,404-420,350-352`
- subtle (✅) — `tupleFrom` skips null array elements and dict values ("as oo::ObjectFromPList dropped them"). Upstream never saw NSNull in plists, so this is equivalent. The dict path uses 0 for missing components, not the default's, as upstream did — upstream `Core/OOCollectionExtractors.m:1236-1322` ↔ port `oofnd/PListGet.hpp:439-481`
- note — The NSMutableArray/Dictionary `oo_addInteger:` / `oo_setInteger:forKey:` family stored `+numberWithLong:`, which is 32-bit on Windows, so a 64-bit value was truncated. Port callers build `PList::signedInteger(int64)` directly. Not audited per caller; any caller that passed a value over 2^31 now stores it whole — upstream `Core/OOCollectionExtractors.m:884-998`

## OODeepCopy

<a id="oodeepcopy"></a>
Upstream `src/Core/OODeepCopy.m` ↔ *(absorbed: `oo::PList` value copies)*

**Status:** done — 7 rows: 0 ✅ 0 ⚠️ 1 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OODeepCopy()` (30) | PList copy-construction at the former call sites: OOShipRegistry.cpp:233, OOCacheManager.cpp:484, Scripting/OOLegacyScriptWhitelist.cpp:69,110 | ➖ |
| `-[NSObject(OODeepCopy) ooDeepCopyWithSharedObjects:]` (50) | PList copy (Object nodes share the `oo::Ref`, as `-retain` for non-NSCopying) | ➖ |
| `-[NSString(OODeepCopy) ooDeepCopyWithSharedObjects:]` (63) | `std::string` copy (no interning; not observable) | ➖ |
| `-[NSValue(OODeepCopy) ooDeepCopyWithSharedObjects:]` (85) | PList copy keeps each number's own kind | ❌ |
| `-[NSArray(OODeepCopy) ooDeepCopyWithSharedObjects:]` (101) | `std::vector<PList>` copy | ➖ |
| `-[NSSet(OODeepCopy) ooDeepCopyWithSharedObjects:]` (152) | none (no PList set) | ➖ |
| `-[NSDictionary(OODeepCopy) ooDeepCopyWithSharedObjects:]` (205) | `std::map` copy | ➖ |

**Differences:**

- ❌ **low** (suspected) — Upstream uniqued NSNumbers through `[objects member:self]`, which uses `-hash`/`-isEqual:`. GNUstep's NSNumber compares by value across types, so in one deep copy a later `<true/>` could be replaced by an earlier integer `1`, or `1.0` by `1`. That changes the kind JS later sees (boolean vs number) and the single/double flag. The PList copy keeps every node's kind. Only XML plists carry typed numbers (old-style plists hold strings), so shipdata/effectdata from XML OXPs is the exposure — upstream `Core/OODeepCopy.m:87-95` ↔ port `Core/OOShipRegistry.cpp:233`

## OOEncodingConverter

<a id="ooencodingconverter"></a>
Upstream `src/Core/OOEncodingConverter.m` ↔ `Core/OOEncodingConverter.cpp`

**Status:** done — 10 rows: 8 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOEncodingConverter initWithEncoding:substitutions:]` (66) | `OOEncodingConverter(encoding, substitutions)` `Core/OOEncodingConverter.cpp:74` | ⚠️ |
| `-[OOEncodingConverter initWithFontPList:]` (87) | `OOEncodingConverter(fontPList)` + `FontSubstitutions` `:66` `Core/OOEncodingConverter.cpp:101` | ✅ |
| `-[OOEncodingConverter dealloc]` (92) | `~OOEncodingConverter` `Core/OOEncodingConverter.cpp:106` | ✅ |
| `-[OOEncodingConverter descriptionComponents]` (108) | `OOEncodingConverter::descriptionComponents` `Core/OOEncodingConverter.cpp:118` | ✅ |
| `-[OOEncodingConverter convertString:]` (113) | `OOEncodingConverter::convertString` `Core/OOEncodingConverter.cpp:124` | ✅ |
| `-[OOEncodingConverter encoding]` (141) | `OOEncodingConverter::encoding` (nullopt = NSNotFound) `Core/OOEncodingConverter.cpp:167` | ✅ |
| `-[OOEncodingConverter(Private) performConversionForString:]` (150) | `OOEncodingConverter::performConversionForString` → `oo::str::convertForFont` (`oofnd/Encoding.hpp:2086`) `Core/OOEncodingConverter.cpp:172` | ✅ |
| `-[OOEncodingConverter(Private) profileFire:]` (178) | `OOEncodingConverter::profileFire` (compiled out) `Core/OOEncodingConverter.cpp:189` | ⚠️ |
| `StringFromEncoding()` (206) | `StringFromEncoding` → `oo::str::encodingName` (`oofnd/Encoding.hpp:90`) `Core/OOEncodingConverter.cpp:211` | ✅ |
| `EncodingFromString()` (229) | `oo::str::encodingFromName` `oofnd/Encoding.hpp:108` | ✅ |

**Differences:**

- ⚠️ **low** — substitutions are applied in the dictionary's key (byte) order instead of NSDictionary hash order; results differ only when one key occurs in another's key or replacement (not the case for the stock `oolite-font.plist`). A non-string replacement substitutes "" where upstream sent `-length` to a non-string (bead oo-qps.51, comment `:78-84`) — upstream `Core/OOEncodingConverter.m:158-163` ↔ port `Core/OOEncodingConverter.cpp:77-87`
- ⚠️ **low** — PROFILE_ENCODING_CONVERTER's repeating NSTimer became a deadline checked on each conversion (proposed ADR-0033); compiled out (`PROFILE_ENCODING_CONVERTER 0`) — upstream `Core/OOEncodingConverter.m:78-81` ↔ port `Core/OOEncodingConverter.cpp:94-98,148-158`
- ✅ subtle — an unknown encoding (NSNotFound) gave a nil conversion that was returned and not cached; the port returns empty `oo::Data` and caches nothing — same zero-length result for the HUD; `descriptionComponents` prints 4294967295 as `%u` of NSNotFound did — upstream `Core/OOEncodingConverter.m:110,127-130,166` ↔ port `Core/OOEncodingConverter.cpp:121,130-136,175-176`
- ✅ subtle — encoding numeric values are kept (CP1251=11 … CP1250=15, `oofnd/Encoding.hpp:81-86`) and the lossy conversion reproduces GNUstep/iconv transliteration per the captured tables in `oofnd/Encoding.hpp` (banner :18-28); the converter's OOCache is named "Text encoding" with threshold 200, so its prune log class is still `dataCache.prune.Text encoding` — upstream `Core/OOEncodingConverter.m:70-72` ↔ port `Core/OOEncodingConverter.cpp:76-78`


## OOExcludeObjectEnumerator

<a id="ooexcludeobjectenumerator"></a>
Upstream `src/Core/OOExcludeObjectEnumerator.m` ↔ *(absorbed: its one caller, `ShipEntity::escorts`)*

**Status:** done — 5 rows: 0 ✅ 0 ⚠️ 0 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOExcludeObjectEnumerator initWithEnumerator:]` (30) | `ShipEntity::escorts()` Entities/ShipEntity.cpp:6522-6534: a snapshot of `_escortGroup->memberArray()` with `member == this` skipped | ➖ |
| `-[OOExcludeObjectEnumerator dealloc]` (41) | — | ➖ |
| `+[OOExcludeObjectEnumerator enumeratorWithEnumerator:]` (49) | (as above; upstream passed `self`, never nil) | ➖ |
| `-[OOExcludeObjectEnumerator nextObject]` (60) | the `continue` at Entities/ShipEntity.cpp:6531 | ➖ |
| `-[NSEnumerator(OOExcludingObject) ooExcludingObject:]` (74) | (as above; upstream `[[_escortGroup mutationSafeEnumerator] ooExcludingObject:self]`, ShipEntity.m:6034) | ➖ |

**Differences:**

- *none* (the same order and exclusion; upstream's enumerator was also over a snapshot)

## OOFilteringEnumerator

<a id="oofilteringenumerator"></a>
Upstream `src/Core/OOFilteringEnumerator.m` ↔ *(absorbed: typed filter loops at each caller)*

**Status:** done — 19 rows: 0 ✅ 0 ⚠️ 0 ❌ 19 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOFilteringEnumerator filterEnumerator:withSelector:]` (36) | Typed loops that return `std::vector<oo::EntityHold>`: e.g. `ShipEntity::shipSubEntities` Entities/ShipEntity.cpp:1512 (`isShip`), flasher/exhaust/visual-effect/dock forms, `system.planets` Scripting/OOJSSystem.cpp:438-441 (`isVisibleToScripts`) | ➖ |
| `+[OOFilteringEnumerator filterEnumerator:withSelector:andArgument:]` (48) | none (no caller used an argument) | ➖ |
| `-[OOFilteringEnumerator initWithUnderlyingEnumerator:]` (60) | — | ➖ |
| `-[OOFilteringEnumerator dealloc]` (77) | — | ➖ |
| `-[OOFilteringEnumerator descriptionComponents]` (85) | — | ➖ |
| `-[OOFilteringEnumerator shortDescriptionComponents]` (95) | — | ➖ |
| `-[OOFilteringEnumerator nextObject]` (100) | the `if (oo::EntityIsShip(sub)) push_back` test in each loop | ➖ |
| `-[NSEnumerator(OOFilteringEnumerator) filteredWithSelector:]` (141) | (as above) | ➖ |
| `-[NSEnumerator(OOFilteringEnumerator) filteredWithSelector:andArgument:]` (146) | none | ➖ |
| `-[NSArray(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:]` (155) | (as above) | ➖ |
| `-[NSArray(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:andArgument:]` (160) | none | ➖ |
| `-[NSSet(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:]` (169) | none | ➖ |
| `-[NSSet(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:andArgument:]` (174) | none | ➖ |
| `-[NSDictionary(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:]` (183) | none | ➖ |
| `-[NSDictionary(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:andArgument:]` (188) | none | ➖ |
| `-[NSDictionary(OOFilteringEnumerator) keyEnumeratorFilteredWithSelector:]` (193) | none | ➖ |
| `-[NSDictionary(OOFilteringEnumerator) keyEnumeratorFilteredWithSelector:andArgument:]` (198) | none | ➖ |
| `-[NSEnumerator(OOMakeObjectsPerformSelector) makeObjectsPerformSelector:]` (207) | range-for at callers | ➖ |
| `-[NSEnumerator(OOMakeObjectsPerformSelector) makeObjectsPerformSelector:withObject:]` (217) | range-for at callers | ➖ |

**Differences:**

- subtle — Upstream filtered lazily: an entity added to `subEntities` during the enumeration could be seen. The port's loops return a snapshot vector. The callers were not mutating during iteration — upstream `Core/OOFilteringEnumerator.m:100-138` ↔ port `Core/Entities/ShipEntity.cpp:1512-1520`

## OOFoundation

<a id="oofoundation"></a>
Upstream `src/Core/OOFoundation.m` ↔ `Core/OOFoundation.cpp`

**Status:** done — 6 rows: 0 ✅ 0 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSObject(OODescriptionComponents) descriptionComponents]` (35) | per-class `descriptionComponents()` returning `std::optional<std::string>` (e.g. `Core/OOCache.h:92`); no root default (`Core/OODescription.h:82-87`) | ➖ |
| `-[NSObject(OODescriptionComponents) description]` (44) | no central wrapper; "<Class 0x…>{…}" is assembled per call site with `oo::str::pointerDescription` (`Core/OODescription.h:17-18`); plists via `oo::DescriptionOf(const oo::PList&)` `Core/OODescription.h:90` | ➖ |
| `-[NSObject(OODescriptionComponents) shortDescription]` (59) | per-class/per-site (e.g. `Core/Entities/EntityHelpers.h:49`) | ➖ |
| `-[NSObject(OODescriptionComponents) shortDescriptionComponents]` (71) | per-class (no root default) | ➖ |
| `-[NSEnumerator(OOForEachSupport) objectEnumerator]` (80) | — (no NSEnumerator; range-for) | ➖ |
| `OOConsumeReference()` (88) | — (went with libobjc2, bead oo-dbz; `Core/OOFoundation.cpp:35`) | ➖ |

**Differences:**

- ➖ **low** — the NSObject description category is gone: upstream printed "<Class %p>{components}" or, when components was nil, "<Class %p>" (no braces) for every object; the port has no shared wrapper, so each call site must reproduce the nil→no-braces rule and the GNUstep `%p` (low 32 bits) itself. Not a defect in this file, but a drift risk for any log line that prints an object with `%@` — upstream `Core/OOFoundation.m:44-56` ↔ port `Core/OODescription.h:9-18,82-87`


## OOIsNumberLiteral

<a id="ooisnumberliteral"></a>
Upstream `src/Core/OOIsNumberLiteral.m` ↔ `Core/OOIsNumberLiteral.cpp`

**Status:** done — 1 rows: 1 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOIsNumberLiteral()` (40) | `OOIsNumberLiteral(const std::string&, BOOL)` `Core/OOIsNumberLiteral.cpp:42` | ✅ |

**Differences:**

- ✅ subtle — scans UTF-8 bytes instead of UTF-16 units; every non-ASCII unit/byte hits `default:` → NO in both, so results match. The nil check is gone (the argument is a reference); the debug FAIL variant (NSLog → `OO_LOG("unclassified")`) is compiled out in both — upstream `Core/OOIsNumberLiteral.m:27-37,52-56` ↔ port `Core/OOIsNumberLiteral.cpp:28-40,53-55`


## OOLogHeader

<a id="oologheader"></a>
Upstream `src/Core/OOLogHeader.m` ↔ `Core/OOLogHeader.cpp`

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOPrintLogHeader()` (57) | `OOPrintLogHeader` `Core/OOLogHeader.cpp:61` | ✅ |
| `OOPlatformDescription()` (183) | `OOPlatformDescription` (std::string) `Core/OOLogHeader.cpp:192` | ✅ |
| `AdditionalLogHeaderInfo()` (202) | `AdditionalLogHeaderInfo` (Mac) `Core/OOLogHeader.cpp:212` | ✅ |
| `GetCPUDescription()` (229) | `GetCPUDescription` (Mac) `Core/OOLogHeader.cpp:241` | ✅ |
| `GetSysCtlString()` (309) | `GetSysCtlString` (Mac) `Core/OOLogHeader.cpp:322` | ✅ |
| `GetSysCtlInt()` (325) | `GetSysCtlInt` (Mac) `Core/OOLogHeader.cpp:338` | ✅ |
| `AdditionalLogHeaderInfo()` (347) | `AdditionalLogHeaderInfo` `Core/OOLogHeader.cpp:361` | ✅ |

**Differences:**

- ✅ subtle — header text is literal-for-literal: "Opening log for Oolite %@ by %@ (<cpu><variant>) under %@ at %@.\n", the "<cpu> N processor(s) detected. System RAM: … MB (free: … MB)." line, "\nBuild options: %@.\n", the logcontrol note, and the whole logged once as `log.header` with format "%@\n" (trailing blank line kept) — upstream `Core/OOLogHeader.m:169-180,353` ↔ port `Core/OOLogHeader.cpp:171-187,367`
- ✅ subtle — "new planets" is now unconditional; upstream gated it on NEW_PLANETS, which `OOStellarBody.h:35` always defines to 1 — upstream `Core/OOLogHeader.m:108-110` ↔ port `Core/OOLogHeader.cpp:112`
- ✅ subtle — the date is `oo::date::description()` (NSDate `-description` "YYYY-MM-DD HH:MM:SS +hhmm", local zone, `oofnd/Date.hpp:85-139`) and the non-Windows OS string is `oo::process::operatingSystemVersionString()` (uname release, `oofnd/Process.hpp:125-135`) — upstream `Core/OOLogHeader.m:153,169` ↔ port `Core/OOLogHeader.cpp:155,171`
- ✅ subtle — the header is printed before `LoadExplicitSettings`, so it carries no time/class prefix and every class shows (Options default all-false, `_default` YES), as upstream (sShowTime/sShowClass start NO) — upstream `Core/OOLogging.m:83-87,555-557` ↔ port `oofnd/Log.hpp:78-83,448`, `Core/OOLogging.cpp:202-204`


## OOLogOutputHandler

<a id="oologoutputhandler"></a>
Upstream `src/Core/OOLogOutputHandler.m` ↔ `Core/OOLogOutputHandler.cpp`

**Status:** done — 24 rows: 17 ✅ 2 ⚠️ 4 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOLogOutputHandlerInit()` (111) | `OOLogOutputHandlerInit` `Core/OOLogOutputHandler.cpp:132` | ✅ |
| `OOLogOutputHandlerClose()` (147) | `OOLogOutputHandlerClose` `Core/OOLogOutputHandler.cpp:181` | ✅ |
| `OOLogOutputHandlerStartLoggingToStdout()` (170) | `OOLogOutputHandlerStartLoggingToStdout` `Core/OOLogOutputHandler.cpp:200` | ✅ |
| `OOLogOutputHandlerStopLoggingToStdout()` (174) | `OOLogOutputHandlerStopLoggingToStdout` `Core/OOLogOutputHandler.cpp:204` | ✅ |
| `OOLogOutputHandlerPrint()` (179) | `OOLogOutputHandlerPrintLine` (+ `oo::log::consoleBytes`, `oofnd/LogFile.hpp:111`) `Core/OOLogOutputHandler.cpp:220` | ✅ |
| `OOLogHandlerGetLogPath()` (203) | `cxx_OOLogHandlerGetLogPath` / `LogPath` `:512` `Core/OOLogOutputHandler.cpp:244` | ✅ |
| `OOLogOutputHandlerChangeLogFile()` (208) | `cxx_OOLogOutputHandlerChangeLogFile` `Core/OOLogOutputHandler.cpp:249` | ❌ |
| `-[OOAsyncLogger init]` (223) | `StartLogger` + `oo::log::rotateToPrevious` (`oofnd/LogFile.hpp:133`) `Core/OOLogOutputHandler.cpp:271` | ❌ |
| `-[OOAsyncLogger dealloc]` (260) | `FileWriter::~FileWriter` `oofnd/LogFile.hpp:157` | ✅ |
| `-[OOAsyncLogger startLogging]` (270) | `FileWriter::start` `oofnd/LogFile.hpp:161` | ✅ |
| `-[OOAsyncLogger endLogging]` (330) | `FileWriter::end` (`oofnd/LogFile.hpp:194`) + `Postamble` `Core/OOLogOutputHandler.cpp:167` | ✅ |
| `-[OOAsyncLogger changeFile]` (346) | folded into `cxx_OOLogOutputHandlerChangeLogFile` `Core/OOLogOutputHandler.cpp:253-261` | ✅ |
| `-[OOAsyncLogger asyncLogMessage:]` (353) | `AsyncLogMessage` (+ `FileWriter::write`, `logFileBytes` `oofnd/LogFile.hpp:82,180`) `Core/OOLogOutputHandler.cpp:297` | ⚠️ |
| `-[OOAsyncLogger flushLog]` (377) | `OOLogOutputHandlerFlushIfDue` (+ `FileWriter::flush` `oofnd/LogFile.hpp:191`) `Core/OOLogOutputHandler.cpp:209` | ⚠️ |
| `-[OOAsyncLogger loggerThread]` (383) | `FileWriter::run` `oofnd/LogFile.hpp:240` | ✅ |
| `LoadLogCStringFunctions()` (463) | `LoadLogCStringFunctions` (Mac) `Core/OOLogOutputHandler.cpp:339` | ✅ |
| `OONSLogCStringFunction()` (481) | `OONSLogCStringFunction` (Mac) `Core/OOLogOutputHandler.cpp:357` | ✅ |
| `OONSLogPrintfHandler()` (490) | — (no gnustep-base: nothing to capture) | ➖ |
| `DirectoryExistCreatingIfNecessary()` (499) | `DirectoryExistCreatingIfNecessary` `Core/OOLogOutputHandler.cpp:368` | ❌ |
| `ExcludeFromTimeMachine()` (521) | `ExcludeFromTimeMachine` (Mac) `Core/OOLogOutputHandler.cpp:389` | ✅ |
| `GetAppName()` (533) | `GetAppName` (Mac) `Core/OOLogOutputHandler.cpp:401` | ❌ |
| `OOLogHandlerGetLogBasePath()` (552) | `LogBasePath` / `cxx_OOLogHandlerGetLogBasePath` `:505` (+ `AppendPathComponent` `:434`) `Core/OOLogOutputHandler.cpp:458` | ✅ |
| `InitCrashReporterInfo()` (606) | `InitCrashReporterInfo` (Mac debug) `Core/OOLogOutputHandler.cpp:529` | ✅ |
| `SetCrashReporterInfo()` (619) | `SetCrashReporterInfo` (Mac debug) `Core/OOLogOutputHandler.cpp:537` | ✅ |

**Differences:**

- ⚠️ **low** — Latest.log flushing: the one-shot 2 s NSTimer on the run loop became a steady-clock deadline that only fires when the frame loop calls `OOLogOutputHandlerFlushIfDue` (proposed ADR-0033, comment `:117-122`). The file is unbuffered (`setvbuf _IONBF`, `oofnd/LogFile.hpp:168`), so a flush is only fsync/_commit: readers see every line as soon as the writer thread writes it; only durability across an OS crash depends on the call site. A first request off the main thread still disables flushing forever, as upstream did — upstream `Core/OOLogOutputHandler.m:370-381` ↔ port `Core/OOLogOutputHandler.cpp:209-218,305-311`
- ❌ **low** — log-setup failures used `NSLog` (stderr with GNUstep's "date process[pid:tid] " banner, or — once the printf handler was installed — a `gnustep`-class line in Latest.log); the port uses `OO_LOG("unclassified", …)`, so text/prefix and message class differ ("could not move or delete existing log", "could not open log", "expected … to be a folder", "could not create folder") — upstream `Core/OOLogOutputHandler.m:244,322,507,512` ↔ port `Core/OOLogOutputHandler.cpp:259,280,286,373,378`
- ❌ **low** — `ChangeLogFile` start failure: upstream logged "could not open log" only when creating the file failed (from `-startLogging`) and as class `gnustep` via the installed NSLog handler; the port logs it as `unclassified` and also when `LogPath()` is fine but `FileWriter::start` fails for another reason — upstream `Core/OOLogOutputHandler.m:316-324,349-350` ↔ port `Core/OOLogOutputHandler.cpp:255-261`
- ❌ **low** (Mac only) — `GetAppName` reads `CFBundleName` from `<built-in resources>/Info-gnustep.plist` instead of the main bundle's Info.plist, so on a Mac bundle without that file the log folder becomes `~/Library/Logs/<unknown application>` — upstream `Core/OOLogOutputHandler.m:539-544` ↔ port `Core/OOLogOutputHandler.cpp:406-420`
- ➖ **low** — GNUstep's own `NSLog` output (class `gnustep`) is no longer captured into Latest.log; with gnustep-base removed there is no such output to capture — upstream `Core/OOLogOutputHandler.m:137-141,490-495` ↔ port (none; `Core/OOLogOutputHandler.cpp:87-89`)
- ✅ subtle — file bytes match: line + "\n", every "\n" → "\r\n" on Windows (except before a combining unit, as GNUstep's non-literal split), lone-surrogate lines dropped, 1 GiB saturation notice text and process-wide flag, postamble "\nClosing log at <NSDate description>.", rotation Latest.log → Previous.log — upstream `Core/OOLogOutputHandler.m:238-248,336-338,359-368,403-416` ↔ port `oofnd/LogFile.hpp:82-141,180-276`, `Core/OOLogOutputHandler.cpp:167-170`
- ✅ subtle — `LogBasePath` retries after a failed mkdir where upstream kept an unretained autoreleased string in its static (dangling on the next call); the default paths (`$OO_LOGSDIR`, `<home>/Logs`, `<home>/.Oolite/Logs`) are unchanged — upstream `Core/OOLogOutputHandler.m:556-594` ↔ port `Core/OOLogOutputHandler.cpp:458-501`


## OOLogging

<a id="oologging"></a>
Upstream `src/Core/OOLogging.m` ↔ `Core/OOLogging.cpp`

**Status:** done — 44 rows: 40 ✅ 2 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `CacheValue()` (120) | `Logger::Value::on()/off()` `oofnd/Log.hpp:372-373` | ✅ |
| `Inited()` (128) | `Logger::checkInitialized` `oofnd/Log.hpp:290` | ✅ |
| `OOLogWillDisplayMessagesInClass()` (136) | `Logger::willDisplay` / `oo::log::willDisplay` `:463` `oofnd/Log.hpp:313` | ✅ |
| `OOLogSetDisplayMessagesInClass()` (172) | `Logger::setDisplay` `oofnd/Log.hpp:299` | ✅ |
| `OOLogGetParentMessageClass()` (194) | `oo::log::parentClass` `oofnd/Log.hpp:124` | ✅ |
| `OOLogIndentIf()` (210) | `oo::log::indentIf` `oofnd/Log.hpp:477` | ✅ |
| `OOLogOutdentIf()` (216) | `oo::log::outdentIf` `oofnd/Log.hpp:483` | ✅ |
| `GetIndentLevel()` (238) | `oo::log::indentLevel` (thread_local) `oofnd/Log.hpp:194` | ✅ |
| `SetIndentLevel()` (243) | `IndentState::level` writes in `indent`/`outdent`/`popIndent` `oofnd/Log.hpp:195-200,472` | ✅ |
| `OOLogPushIndent()` (248) | `OOLogPushIndent` → `oo::log::pushIndent` `Core/OOLogging.cpp:88`, `oofnd/Log.hpp:202` | ✅ |
| `OOLogPopIndent()` (264) | `OOLogPopIndent` → `oo::log::popIndent` `Core/OOLogging.cpp:93`, `oofnd/Log.hpp:465` | ✅ |
| `GetIndentLevel()` (289) | (thread-dictionary variant) same as above `oofnd/Log.hpp:194` | ✅ |
| `SetIndentLevel()` (295) | (thread-dictionary variant) same as above | ✅ |
| `OOLogPushIndent()` (301) | (thread-dictionary variant) `oofnd/Log.hpp:202` | ✅ |
| `OOLogPopIndent()` (323) | (thread-dictionary variant) `oofnd/Log.hpp:465` | ✅ |
| `OOLogIndent()` (345) | `OOLogIndent` → `oo::log::indent` `Core/OOLogging.cpp:98`, `oofnd/Log.hpp:195` | ✅ |
| `OOLogOutdent()` (354) | `OOLogOutdent` → `oo::log::outdent` `Core/OOLogging.cpp:103`, `oofnd/Log.hpp:196` | ✅ |
| `OOLogWithPrefix()` (365) | `oo::log::messageWithPrefix` `oofnd/Log.hpp:499` | ✅ |
| `OOLogWithFunctionFileAndLine()` (375) | `oo::log::message` `oofnd/Log.hpp:492` | ✅ |
| `OOLogWithFunctionFileAndLineAndArguments()` (384) | `Logger::write` + `composeLine` `:164` + `timeStamp` `:147` `oofnd/Log.hpp:337` | ✅ |
| `OOLogGenericParameterErrorForFunction()` (459) | `OOLogGenericParameterErrorForFunction` `Core/OOLogging.cpp:108` | ✅ |
| `OOLogGenericSubclassResponsibilityForFunction()` (464) | `OOLogGenericSubclassResponsibilityForFunction` `Core/OOLogging.cpp:113` | ✅ |
| `OOLogShowFunction()` (469) | `OOLogShowFunction` `Core/OOLogging.cpp:118` | ✅ |
| `OOLogSetShowFunction()` (474) | `OOLogSetShowFunction` `Core/OOLogging.cpp:123` | ✅ |
| `OOLogShowFileAndLine()` (484) | `OOLogShowFileAndLine` `Core/OOLogging.cpp:135` | ✅ |
| `OOLogSetShowFileAndLine()` (489) | `OOLogSetShowFileAndLine` `Core/OOLogging.cpp:140` | ✅ |
| `OOLogShowTime()` (499) | `OOLogShowTime` `Core/OOLogging.cpp:152` | ✅ |
| `OOLogSetShowTime()` (504) | `OOLogSetShowTime` `Core/OOLogging.cpp:157` | ✅ |
| `OOLogShowMessageClass()` (514) | `OOLogShowMessageClass` `Core/OOLogging.cpp:169` | ✅ |
| `OOLogSetShowMessageClass()` (519) | `OOLogSetShowMessageClass` `Core/OOLogging.cpp:174` | ✅ |
| `OOLogSetShowMessageClassTemporary()` (529) | `OOLogSetShowMessageClassTemporary` → `Logger::setShowClassTemporarily` `Core/OOLogging.cpp:186` | ✅ |
| `OOLoggingInit()` (534) | `OOLoggingInit` (+ `LogSink` `:56`) `Core/OOLogging.cpp:191` | ✅ |
| `OOLoggingTerminate()` (562) | `OOLoggingTerminate` `Core/OOLogging.cpp:208` | ✅ |
| `OOLoggingReloadSettings()` (576) | `OOLoggingReloadSettings` `Core/OOLogging.cpp:222` | ✅ |
| `OOLogInsertMarker()` (581) | `OOLogInsertMarker` → `Logger::insertMarker` `Core/OOLogging.cpp:227`, `oofnd/Log.hpp:345` | ✅ |
| `OOLogInternal_()` (610) | `Logger::internal` `oofnd/Log.hpp:352` | ✅ |
| `LoadExplicitSettings()` (650) | `LoadExplicitSettings` + `Logger::replaceSettings` (`oofnd/Log.hpp:246`) `Core/OOLogging.cpp:259` | ❌ |
| `LoadExplicitSettingsFromDictionary()` (719) | `SettingsFromDictionary` (`Core/OOLogging.cpp:63`) + `Logger::replaceSettings` `oofnd/Log.hpp:246` | ⚠️ |
| `OOLogAbbreviatedFileName()` (762) | `oo::log::abbreviatedFileName` (uncached) `oofnd/Log.hpp:134` | ✅ |
| `ResolveDisplaySetting()` (783) | `Logger::resolve` `oofnd/Log.hpp:403` | ✅ |
| `ResolveMetaClassReference()` (809) | `Logger::resolveMeta` `oofnd/Log.hpp:423` | ⚠️ |
| *(added)* `kOOLog*` message-class constants (595-604) | `cxx_kOOLog*` `Core/OOLogging.cpp:232-241` | ✅ |
| *(added)* `OOLOG_ERROR_PREFIX` / `OOLOG_WARNING_PREFIX` (`OOLogging.h:122-123`) | `kErrorPrefix` / `kWarningPrefix` `oofnd/Log.hpp:509-510` | ✅ |
| *(added)* `OOLog()` macro / `OOLOG_FUNCTION_NAME` (`OOLogging.h:39-47,84-89`) | `OO_LOG` (`__FUNCTION__`) `oofnd/Log.hpp:516-520` | ❌ |

**Differences:**

- ❌ **low** — `logging-show-function/-file-and-line/-time/-class` are read with `Defaults::boolForKey` (NSString `-boolValue`: leading Y/y/T/t or non-zero digit) when present, instead of `oo_boolForKey:defaultValue:` (`OOBooleanFromObject`: "yes"/"true"/"on"/non-zero number → YES, "no"/"false"/"off"/zero → NO, anything else → the default). A string "on" now gives NO, and an unrecognised string or non-number gives NO instead of the default (YES for time/class), dropping the time stamp / `[class]` prefix from every line. Only hand-edited or command-line string values are affected; values written by the game are booleans — upstream `Core/OOLogging.m:653-657`, `Core/OOCollectionExtractors.m:1099-1108,1124-1140` ↔ port `Core/OOLogging.cpp:262-267`, `oofnd/Defaults.hpp:90-101,474-480`
- ❌ **low** — the function name in log lines is C++ `__FUNCTION__` (bare "prune", "init") where ObjC's was "-[OOCache prune]"; visible only with `logging-show-function` on (default NO) — upstream `Core/OOLogging.h:41,87`, `Core/OOLogging.m:407,415` ↔ port `oofnd/Log.hpp:171,175,519`
- ⚠️ **low** — a `$metaclass` cycle now falls back to `_default` instead of recursing until the stack overflowed (documented "the one deliberate difference", `oofnd/Log.hpp:421-422`) — upstream `Core/OOLogging.m:809-832` ↔ port `oofnd/Log.hpp:423-442`
- ⚠️ **low** — logcontrol dictionaries are walked in `oo::PList::Dict` key (byte) order instead of NSDictionary hash order (comment `Core/OOLogging.cpp:61-62`); this only reorders the "OOLogging internal - LoadExplicitSettingsFromDictionary: Bad setting value …" diagnostics, never the resulting settings — upstream `Core/OOLogging.m:722-755` ↔ port `Core/OOLogging.cpp:63-82`, `oofnd/Log.hpp:252-273`
- ⚠️ **low** — the built-in logcontrol.plist pre-pass no longer logs `plist.wrongType` when that file's root is not a dictionary (comment `Core/OOLogging.cpp:283`) — upstream `Core/OOLogging.m:667-670` ↔ port `Core/OOLogging.cpp:277-285`
- ✅ subtle — line layout is unchanged: prefix order function/file:line → "[class] " or "[class]: " → time "HH:MM:SS.mmm " (local, ms truncated) → indentation of 2 spaces per level capped at 64 placed before the time; internal diagnostics ("OOLogging internal - <fn>: …") and markers ("\n\n========== [Marker N] ==========") bypass prefixes and indentation; `_default` YES, `_override` sticky once set, settings/display defaults load after the header — upstream `Core/OOLogging.m:85-89,404-448,591,623` ↔ port `oofnd/Log.hpp:164-190,345-355,446-450`
- ✅ subtle — internal diagnostics are collected under the lock and printed after it is released, in the same order and with the same function names (`Inited`, `LoadExplicitSettingsFromDictionary`, `LoadExplicitSettings`, `ResolveMetaClassReference`, `OOLogPopIndent`); the SETTING_SET/RETRIEVE diagnostics stay off (flags 0) — upstream `Core/OOLogging.m:58-65,132,275,692,705,742,748,815,826` ↔ port `oofnd/Log.hpp:265-286,294,330-331,469`
- ✅ subtle — the `@catch` around formatting is gone (std::format strings are checked at compile time); before `OOLoggingInit` lines go to a stderr sink as `OOLogOutputHandlerPrint` did before its init — upstream `Core/OOLogging.m:452-454` ↔ port `oofnd/Log.hpp:28-29,215-217,377-381`


## OOPListParsing

<a id="ooplistparsing"></a>
Upstream `src/Core/OOPListParsing.m` ↔ `Core/OOPListParsing.cpp`

**Status:** done — 9 rows: 3 ✅ 1 ⚠️ 0 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOPropertyListFromData()` (48) | `cxx_OOPropertyListFromData` (+ `oo::parsePropertyList`, `oofnd/PListParsing.hpp:70`) `Core/OOPListParsing.cpp:34` | ⚠️ |
| `OOPropertyListFromFile()` (83) | `cxx_OOPropertyListFromFile` `Core/OOPListParsing.cpp:61` | ✅ |
| `ChangeDTDIfApplicable()` (103) | `oo::changeDTDIfApplicable` `oofnd/PListXML.hpp:64` | ✅ |
| `CopyDataFromFile()` (173) | `OODataFromOXZFile` (`oofnd/FileSystem.hpp:24-25`) called at `Core/OOPListParsing.cpp:66` | ✅ |
| `OODictionaryFromData()` (201) | — (callers test `isDict()` themselves) | ➖ |
| `OODictionaryFromFile()` (207) | — (e.g. `Core/OOLogging.cpp:281-283`, `Core/ResourceManager.cpp:58-59`) | ➖ |
| `OOArrayFromData()` (213) | — | ➖ |
| `OOArrayFromFile()` (219) | — (e.g. `Core/Scripting/OOScript.cpp:46`) | ➖ |
| `ValueIfClass()` (226) | — (`plist.wrongType` line dropped) | ➖ |

**Differences:**

- ⚠️ **low** — binary property lists (Apple `bplist00`, GNUstep binary) now always fail with "binary property lists are not supported by oofnd", logged as `plist.parse.failed` "Failed to parse <path> as a property list.\n<error>" (ADR-0027 item 3, `oofnd/PListParsing.hpp:7`); for XML/old-style input the `<error>` text is oofnd's `PListError::description()`, so any golden that captures a parse failure depends on oofnd matching GNUstep's error wording — upstream `Core/OOPListParsing.m:66-79` ↔ port `Core/OOPListParsing.cpp:44-55`
- ➖ **low** — `plist.wrongType` ("Property list is wrong type - expected NSDictionary, got …") is no longer logged anywhere; every former `OODictionaryFromFile`/`OOArrayFromFile` caller silently treats a wrong-typed root as missing (comments at `Core/OOLogging.cpp:283`, `Core/ResourceManager.cpp:58-59`, `Core/Scripting/OOJSScript.cpp:663`) — upstream `Core/OOPListParsing.m:226-232` ↔ port (none)
- ✅ subtle — `plist.information` "Parsing %@ as a property list." still only when `UNIVERSE` exists; "<data in memory>" default and "<no error message>" for a nil-without-error result kept; a missing file is still silent — upstream `Core/OOPListParsing.m:53-57,73-76,94` ↔ port `Core/OOPListParsing.cpp:38-41,47-53,71`


## OOPriorityQueue

<a id="oopriorityqueue"></a>
Upstream `src/Core/OOPriorityQueue.m` ↔ `Core/OOPriorityQueue.h` (`OOPriorityQueueOf<T>`, header-only; the sole user is `Scripting/OOScriptTimer.cpp`)

**Status:** done — 37 rows: 13 ✅ 1 ⚠️ 0 ❌ 23 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `PQLeftChild()` (68) | `LeftChild` Core/OOPriorityQueue.h:107 | ✅ |
| `PQRightChild()` (73) | `RightChild` :108 | ✅ |
| `PQParent()` (78) | `Parent` :109 | ✅ |
| `PQCompare()` (85) | `_comparator(a, b)` function pointer (`CompareByNextFireTime`, Scripting/OOScriptTimer.cpp:168) | ✅ |
| `+[OOPriorityQueue queueWithComparator:]` (127) | `new OOPriorityQueueOf<T>(cmp)` (OOScriptTimer.cpp:168) | ➖ |
| `-[OOPriorityQueue initWithComparator:]` (132) | ctor :65 | ✅ |
| `-[OOPriorityQueue init]` (147) | none (upstream raised/returned nil without a comparator) | ➖ |
| `-[OOPriorityQueue dealloc]` (152) | implicit dtor (vector of `oo::Ref`) | ➖ |
| `-[OOPriorityQueue description]` (160) | none | ➖ |
| `-[OOPriorityQueue debugDescription]` (166) | none | ➖ |
| `-[OOPriorityQueue isEqual:]` (184) | none (no caller) | ➖ |
| `-[OOPriorityQueue hash]` (215) | none | ➖ |
| `-[OOPriorityQueue copyWithZone:]` (222) | none | ➖ |
| `-[OOPriorityQueue addObject:]` (245) | `addObject` :70 (bubble up from the end) | ⚠️ |
| `-[OOPriorityQueue removeObject:]` (273) | none (comparator-equality removal had no caller) | ➖ |
| `-[OOPriorityQueue removeExactObject:]` (292) | `removeExactObject` :78 (the scan continues past a match from i+1, as upstream) | ✅ |
| `-[OOPriorityQueue count]` (306) | `count` :88 | ✅ |
| `-[OOPriorityQueue nextObject]` (311) | `removeNextObject` :94 returns the element | ➖ |
| `-[OOPriorityQueue peekAtNextObject]` (318) | `peekAtNextObject` :90 | ✅ |
| `-[OOPriorityQueue removeNextObject]` (326) | `removeNextObject` :94 | ✅ |
| `-[OOPriorityQueue addObjects:]` (331) | loop of `addObject` over `sDeferredTimers` in order (OOScriptTimer.cpp:222-225) | ➖ |
| `-[OOPriorityQueue sortedObjects]` (344) | `sortedObjects` :97 (drains the queue, as upstream's enumerator did) | ✅ |
| `-[OOPriorityQueue objectEnumerator]` (349) | none | ➖ |
| `-[OOPriorityQueue(Private) makeObjectsPerformSelector:]` (358) | none | ➖ |
| `-[OOPriorityQueue(Private) bubbleUpFrom:]` (370) | `bubbleUpFrom` :111 | ✅ |
| `-[OOPriorityQueue(Private) bubbleDownFrom:]` (389) | `bubbleDownFrom` :123 (same child choice `li == end ‖ cmp(li,ri) < 0`) | ✅ |
| `-[OOPriorityQueue(Private) growBuffer]` (417) | `std::vector` growth | ➖ |
| `-[OOPriorityQueue(Private) shrinkBuffer]` (446) | `std::vector` (never shrinks) | ➖ |
| `-[OOPriorityQueue(Private) removeObjectAtIndex:]` (466) | `removeObjectAtIndex` :140 (last element moved in, bubble down only) | ✅ |
| `-[OOPriorityQueue(Private) appendDebugDataToString:index:depth:]` (490) | none (OO_DEBUG only) | ➖ |
| `-[OOPriorityQueueEnumerator initWithPriorityQueue:]` (512) | none | ➖ |
| `-[OOPriorityQueueEnumerator dealloc]` (526) | none | ➖ |
| `-[OOPriorityQueueEnumerator nextObject]` (533) | (folded into `sortedObjects`) | ➖ |
| `EscapedString()` (549) | none (DebugGraphViz) | ➖ |
| `-[OOPriorityQueue(DebugGraphViz) generateGraphViz]` (581) | none | ➖ |
| `-[OOPriorityQueue(DebugGraphViz) writeGraphVizToURL:]` (621) | none | ➖ |
| `-[OOPriorityQueue(DebugGraphViz) writeGraphVizToPath:]` (634) | none | ➖ |

**Differences:**

- ⚠️ **low** — `addObject(nullptr)` is ignored, as the comment at :70 says. Upstream raised NSInvalidArgumentException, both for nil and for an object without the comparator — upstream `Core/OOPriorityQueue.m:251-260` ↔ port `Core/OOPriorityQueue.h:70-73`
- subtle — A removed element was `-autorelease`d and lived until the pool drained. `removeObjectAtIndex` now returns an `oo::Ref`, and `removeExactObject` discards it, so the element can be destroyed inside the loop (the header says this is safe from the element's destructor). The timer's own `-dealloc` called `removeExactObject:`, so it was never the last reference there — upstream `Core/OOPriorityQueue.m:484` ↔ port `Core/OOPriorityQueue.h:82-85,140-156`

## OOProfilingStopwatch

<a id="ooprofilingstopwatch"></a>
Upstream `src/Core/OOProfilingStopwatch.m` ↔ `Core/OOProfilingStopwatch.cpp`

**Status:** done — 8 rows: 7 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOProfilingStopwatch init]` (35) | `OOProfilingStopwatch()` `Core/OOProfilingStopwatch.cpp:33` | ✅ |
| `+[OOProfilingStopwatch stopwatch]` (45) | `OOProfilingStopwatch::stopwatch` `Core/OOProfilingStopwatch.cpp:40` | ✅ |
| `-[OOProfilingStopwatch dealloc]` (50) | `~OOProfilingStopwatch` `Core/OOProfilingStopwatch.cpp:45` | ✅ |
| `-[OOProfilingStopwatch start]` (58) | `OOProfilingStopwatch::start` `Core/OOProfilingStopwatch.cpp:51` | ✅ |
| `-[OOProfilingStopwatch stop]` (66) | `OOProfilingStopwatch::stop` `Core/OOProfilingStopwatch.cpp:59` | ✅ |
| `-[OOProfilingStopwatch currentTime]` (74) | `OOProfilingStopwatch::currentTime` `Core/OOProfilingStopwatch.cpp:67` | ✅ |
| `-[OOProfilingStopwatch reset]` (84) | `OOProfilingStopwatch::reset` `Core/OOProfilingStopwatch.cpp:77` | ✅ |
| `OOHighResTimeDeltaInSeconds()` (102) | `OOHighResTimeDeltaInSeconds` `Core/OOProfilingStopwatch.cpp:93` | ⚠️ |

**Differences:**

- ⚠️ **low** — where upstream used SpiderMonkey's `JS_Now()` (wall-clock µs) the port uses `std::chrono::steady_clock` µs (header comment, following the JS engine swap); deltas have the same unit and differ only if the wall clock is adjusted mid-measurement. The mach / standalone-Windows `timeGetTime` / gettimeofday paths are unchanged — upstream `Core/OOProfilingStopwatch.h:81-121`, `Core/OOProfilingStopwatch.m:120-121` ↔ port `Core/OOProfilingStopwatch.h:98-142`, `Core/OOProfilingStopwatch.cpp:115-116`
- ✅ subtle — `stop` still disposes `_start` rather than `_end` (upstream quirk kept; values are plain integers so harmless) — upstream `Core/OOProfilingStopwatch.m:66-72` ↔ port `Core/OOProfilingStopwatch.cpp:59-65`


## OORegExpMatcher

<a id="ooregexpmatcher"></a>
Upstream `src/Core/OORegExpMatcher.m` ↔ `Core/OORegExpMatcher.cpp`

**Status:** done — 6 rows: 5 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OORegExpMatcher regExpMatcher]` (37) | `OORegExpMatcher::regExpMatcher` `Core/OORegExpMatcher.cpp:58` | ✅ |
| `-[OORegExpMatcher init]` (48) | `OORegExpMatcher::init` `Core/OORegExpMatcher.cpp:73` | ✅ |
| `-[OORegExpMatcher dealloc]` (76) | `~OORegExpMatcher` `Core/OORegExpMatcher.cpp:99` | ✅ |
| `-[OORegExpMatcher string:matchesExpression:]` (88) | `OORegExpMatcher::string(string, regExp)` `Core/OORegExpMatcher.cpp:108` | ✅ |
| `-[OORegExpMatcher string:matchesExpression:flags:]` (93) | `OORegExpMatcher::string(string, regExp, flags)` `Core/OORegExpMatcher.cpp:113` | ✅ |
| `-[NSString(OORegExpMatcher) oo_matchesRegularExpression:]` (135) | — (callers call `regExpMatcher()->string(...)`, e.g. `MatchesRegExp` `Core/OOOpenGLExtensionManager.cpp:664`) | ➖ |

**Differences:**

- ✅ subtle — lifetime: the autoreleased pseudo-singleton lived until the pool drained; the port's `Ref` dies with its last holder, and the only caller holds one matcher per pass (ADR-0056 amendment oo-ct7c item 3, `Core/OOOpenGLExtensionManager.cpp:660-673`), so one tester is compiled per pass as before; a null matcher answers NO as `[nil string:…]` did — upstream `Core/OORegExpMatcher.m:37-46` ↔ port `Core/OORegExpMatcher.cpp:58-71`
- ✅ subtle — pattern length is counted in UTF-16 units and the RegExp object is cached per (pattern, flags) as before; the result goes through the same to-boolean conversion as `-evaluatePredicateWithContext:` (`JS_ValueToBoolean`) — upstream `Core/OORegExpMatcher.m:97-131`, `Core/Scripting/OOJSFunction.m:226-239` ↔ port `Core/OORegExpMatcher.cpp:117-159`
- ✅ subtle — the tester's script file name is now "OORegExpMatcher.cpp" (was "OORegExpMatcher.m") with its own `__LINE__`; visible only in a JS error report from `regexp.test(string)` — upstream `Core/OORegExpMatcher.m:52-64` ↔ port `Core/OORegExpMatcher.cpp:76-87`
- ✅ subtle — the malloc-failure early return still skips `OOJSRelinquishContext` (upstream quirk kept) — upstream `Core/OORegExpMatcher.m:111-113` ↔ port `Core/OORegExpMatcher.cpp:128-130`


## OOWeakReference

<a id="ooweakreference"></a>
Upstream `src/Core/OOWeakReference.m` ↔ `oofnd/Ref.hpp` (`oo::WeakRef<T>`, `detail::WeakControl`, `RefCounted`)

**Status:** done — 20 rows: 6 ✅ 2 ⚠️ 0 ❌ 12 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOWeakReference weakRefWithObject:]` (24) | `WeakRef(T*)` oofnd/Ref.hpp:387 + lazy `WeakControl` (`RefCounted::weakControl` :184), one control block per object like the one `weakSelf` proxy | ✅ |
| `-[OOWeakReference dealloc]` (35) | `~WeakRef` :434 → `WeakControl::release` (the object's own count keeps the block, replacing `-weakRefDied:`) | ✅ |
| `-[OOWeakReference description]` (42) | none | ➖ |
| `-[OOWeakReference weakRefUnderlyingObject]` (50) | `WeakRef::get` :467 (nullptr once dead) | ✅ |
| `-[OOWeakReference weakRetain]` (55) | WeakRef copy ctor :402 | ✅ |
| `-[OOWeakReference weakRefDrop]` (60) | `RefCounted::dropWeakControl` :175 (from `dispose` :165 or `dropWeakReferences` :153) | ⚠️ |
| `-[OOWeakReference class]` (67) | none (no proxy; `lock()` :471 gives the real object) | ➖ |
| `-[OOWeakReference isProxy]` (72) | none | ➖ |
| `-[OOWeakReference forwardInvocation:]` (77) | none: nil-safe forwarding becomes `if (auto t = w.lock())` at callers | ➖ |
| `-[OOWeakReference methodSignatureForSelector:]` (83) | none | ➖ |
| `-[OOWeakReference respondsToSelector:]` (102) | none | ➖ |
| `-[OOWeakReference forwardingTargetForSelector:]` (115) | none | ➖ |
| `-[NSObject(OOWeakReference) weakRefUnderlyingObject]` (124) | none (callers hold typed pointers) | ➖ |
| `-[OOWeakRefObject weakRetain]` (133) | `WeakRef(this)` via `RefCounted::weakControl` :184 | ✅ |
| `-[OOWeakRefObject weakRefDied:]` (140) | `WeakControl` refcount (`release` deletes the block) | ✅ |
| `-[OOWeakRefObject dealloc]` (146) | `RefCounted::dispose` :165-173 (`willDispose`, then zero the weak refs, then `delete`) | ⚠️ |
| `-[OOWeakRefObject weakSelf]` (152) | `oo::WeakRef<T>(this)` at callers | ➖ |
| `+[OOWeakReferenceTemplates weakRefDrop]` (162) | none | ➖ |
| `+[OOWeakReferenceTemplates weakRefUnderlyingObject]` (165) | none | ➖ |
| `+[OOWeakReferenceTemplates nilMethod]` (169) | none | ➖ |

**Differences:**

- ⚠️ **low** — Weak references are zeroed *before* any destructor body runs. Upstream's `-weakRefDrop` ran inside `OOWeakRefObject -dealloc`, after the subclass `-dealloc` bodies, so a weak ref could still reach a half-dealloc'd object. The `Ref.hpp` banner documents this as "stricter than OOWeakReference" (ADR-0026). `willDispose` still runs with the weak refs live — upstream `Core/OOWeakReference.m:146-150` ↔ port `oofnd/Ref.hpp:165-173`
- subtle — The proxy forwarded any message to nil once dead, which returned 0/nil. Callers now `get()`/`lock()` and must check for null. A missed check is a null deref, not a no-op. This is a per-caller property, not one this section can audit — upstream `Core/OOWeakReference.m:77-81` ↔ port `oofnd/Ref.hpp:467-473`

## OOWeakSet

<a id="ooweakset"></a>
Upstream `src/Core/OOWeakSet.m` ↔ `oofnd/WeakSet.hpp`

**Status:** done — 24 rows: 15 ✅ 4 ⚠️ 0 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOWeakSet init]` (31) | `WeakSet()` oofnd/WeakSet.hpp:51 | ✅ |
| `-[OOWeakSet initWithCapacity:]` (36) | `WeakSet(capacityHint)` :52 | ✅ |
| `+[OOWeakSet set]` (48) | `WeakSet()` | ✅ |
| `+[OOWeakSet setWithCapacity:]` (53) | `WeakSet(capacityHint)` | ✅ |
| `-[OOWeakSet dealloc]` (58) | `~WeakSet` :69 | ✅ |
| `-[OOWeakSet description]` (65) | none | ➖ |
| `-[OOWeakSet copyWithZone:]` (92) | copy ctor :58 → `addLiveFrom` :169 (live members only, as compact + add) | ✅ |
| `-[OOWeakSet mutableCopyWithZone:]` (100) | copy ctor | ✅ |
| `-[OOWeakSet isEqual:]` (105) | `operator==` :143 (count, then membership) | ✅ |
| `-[OOWeakSet count]` (129) | `count` :71 (compacts first) | ✅ |
| `-[OOWeakSet containsObject:]` (135) | `contains` :79 (identity; nil → false) | ✅ |
| `-[OOWeakSet objectEnumerator]` (144) | `allObjects` :124 / `forEach` :137 | ⚠️ |
| `-[OOWeakSet addObject:]` (149) | `add` :88 (nil ignored, identity-uniqued) | ✅ |
| `-[OOWeakSet removeObject:]` (160) | `remove` :100 | ✅ |
| `-[OOWeakSet addObjectsByEnumerating:]` (167) | `addAll` :111 | ✅ |
| `-[OOWeakSet makeObjectsPerformSelector:]` (176) | `forEach` :137 | ⚠️ |
| `-[OOWeakSet makeObjectsPerformSelector:withObject:]` (184) | `forEach` :137 | ⚠️ |
| `-[OOWeakSet allObjects]` (192) | `allObjects` :124 (live, retained) | ⚠️ |
| `-[OOWeakSet removeAllObjects]` (209) | `removeAll` :117 | ✅ |
| `-[OOWeakSet compact]` (214) | `compact` :157 | ✅ |
| `-[OOWeakRefUnpackingEnumerator initWithEnumerator:]` (242) | none (snapshot vector) | ➖ |
| `+[OOWeakRefUnpackingEnumerator enumeratorWithCollection:]` (256) | none | ➖ |
| `-[OOWeakRefUnpackingEnumerator dealloc]` (261) | none | ➖ |
| `-[OOWeakRefUnpackingEnumerator nextObject]` (268) | the live-member filter in `allObjects` :127-129 | ➖ |

**Differences:**

- ⚠️ **low** — Members are now visited in insertion order. Upstream used NSMutableSet order, which follows pointer hashes and varies between runs. The banner calls this "One deliberate strengthening". Whatever iterates a WeakSet now runs in a fixed, different order — upstream `Core/OOWeakSet.m:176-206` ↔ port `oofnd/WeakSet.hpp:22-24,124-141`
- ⚠️ **low** — `forEach` iterates a retained snapshot, so a callback may mutate the set. Upstream's `foreach` over `_objects` raised on mutation, and members died mid-loop could be messaged as nil. Documented in the banner — upstream `Core/OOWeakSet.m:176-190` ↔ port `oofnd/WeakSet.hpp:26-28,137-141`

## OOXMLExtensions

<a id="ooxmlextensions"></a>
Upstream `src/Core/OOXMLExtensions.m` ↔ `Core/OOXMLExtensions.cpp`

**Status:** done — 1 rows: 0 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSDictionary(OOXMLExtensions) writeOOXMLToFile:atomically:errorDescription:]` (29) | `OOWriteXMLPListToFile` (+ `oo::writeXMLPList`, `oofnd/PListWriting.hpp`) `Core/OOXMLExtensions.cpp:30` | ❌ |

**Differences:**

- ❌ **low** — serialisation-failure text: upstream passed `outErrorDesc` to the serializer but formatted its never-set local `errorDesc`, so the message was always "could not convert property list to XML: (null)"; the port appends oofnd's real error description. Visible only when a save game fails to serialise (e.g. a lone surrogate) — upstream `Core/OOXMLExtensions.m:31-38` ↔ port `Core/OOXMLExtensions.cpp:32-37`
- ✅ subtle — the `atomically:` argument is ignored in both (always atomic); the XML bytes come from `oo::writeXMLPList`, which claims GNUstep's XML writer byte for byte (indentation, sorted keys, `%.16g` reals, escaping; `oofnd/PListWriting.hpp:26-34`) — this is the save-game writer, so its fidelity is worth a golden — upstream `Core/OOXMLExtensions.m:34,43` ↔ port `Core/OOXMLExtensions.cpp:32,40`


## OldSchoolPropertyListWriting

<a id="oldschoolpropertylistwriting"></a>
Upstream `src/Core/OldSchoolPropertyListWriting.m` ↔ `oofnd/PListWriting.hpp` (`plist_detail::OldStyleWriter`, `oo::writeOldStylePList`)

**Status:** done — 8 rows: 5 ✅ 3 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSString(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (30) | `OldStyleWriter::formatString` oofnd/PListWriting.hpp:181 (the bug that drops the text between two escaped characters is reproduced) | ⚠️ |
| `-[NSNumber(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (89) | `format` Bool/Integer/Real cases :131-148 (true/false, `%lld`/`%llu`, `%.8g`) | ✅ |
| `-[NSData(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (121) | `formatData` :238 | ⚠️ |
| `-[NSArray(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (169) | `formatArray` :258 (the same "non-plist object in dictionary" text) | ✅ |
| `-[NSDictionary(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (211) | `formatDict` :295 + `caseInsensitiveLess` :281 | ⚠️ |
| `-[NSObject(OldSchoolPropertyListWriting) oldSchoolPListFormatWithErrorDescription:]` (278) | `oo::writeOldStylePList` :522 (appends "\n") | ✅ |
| `-[NSObject(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (286) | `format` Date/Object cases :157-163 ("Class X does not support OldSchoolPropertyListWriting") | ✅ |
| `AppendNewLineAndIndent()` (296) | `newLineAndIndent` :173 | ✅ |

**Differences:**

- ⚠️ **low** — A non-ASCII alphanumeric string such as `Zürich`, which GNUstep's Unicode `alphanumericCharacterSet` left bare, is always quoted (ADR-0027 item 5, cited in the banner). Saved games and caches written by the port quote such strings where upstream did not. Both parse back the same — upstream `Core/OldSchoolPropertyListWriting.m:40` ↔ port `oofnd/PListWriting.hpp:188-195`
- ⚠️ **low** — Upstream's NSData writer under-sized its buffer for 5-7 and 9+ bytes (truncation, uninitialised bytes) and looped forever at indentation 0 past 32 bytes (`while (--j)` with j=0). The port writes the intended form (ADR-0027 item 4) — upstream `Core/OldSchoolPropertyListWriting.m:132,149` ↔ port `oofnd/PListWriting.hpp:238-256`
- ⚠️ **low** — Key order: two keys equal but for case keep NSDictionary hash order upstream and UTF-16 unit order in the port (banner, ADR-0027). The fold is also ASCII-only, where GNUstep's `caseInsensitiveCompare:` folds Unicode, so non-ASCII keys differing only in case (`Ä`/`ä`) may sort differently — upstream `Core/OldSchoolPropertyListWriting.m:220` ↔ port `oofnd/PListWriting.hpp:281-293`

## ReleaseLockProxy

<a id="releaselockproxy"></a>
Upstream `src/Core/ReleaseLockProxy.m` ↔ *(removed: a debugging proxy with no user in upstream or the port)*

**Status:** done — 17 rows: 0 ✅ 0 ⚠️ 0 ❌ 17 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[ReleaseLockProxy proxyWithObject:name:]` (32) | none (no caller upstream) | ➖ |
| `+[ReleaseLockProxy proxyWithRetainedObject:name:]` (37) | none | ➖ |
| `-[ReleaseLockProxy initWithObject:name:]` (42) | none | ➖ |
| `-[ReleaseLockProxy initWithRetainedObject:name:]` (47) | none | ➖ |
| `-[ReleaseLockProxy dealloc]` (64) | none | ➖ |
| `-[ReleaseLockProxy rlpAllowRelease]` (78) | none | ➖ |
| `-[ReleaseLockProxy rlpObjectDescription]` (83) | none | ➖ |
| `-[ReleaseLockProxy release]` (90) | none | ➖ |
| `-[ReleaseLockProxy autorelease]` (109) | none | ➖ |
| `-[ReleaseLockProxy forwardInvocation:]` (117) | none | ➖ |
| `-[ReleaseLockProxy methodSignatureForSelector:]` (122) | none | ➖ |
| `+[ReleaseLockProxy instancesRespondToSelector:]` (135) | none | ➖ |
| `-[ReleaseLockProxy respondsToSelector:]` (144) | none | ➖ |
| `+[ReleaseLockProxy_SignatureTemplateClass initWithObject:name:]` (153) | none | ➖ |
| `+[ReleaseLockProxy_SignatureTemplateClass initWithRetainedObject:name:]` (157) | none | ➖ |
| `+[ReleaseLockProxy_SignatureTemplateClass rlpAllowRelease]` (161) | none | ➖ |
| `+[ReleaseLockProxy_SignatureTemplateClass rlpObjectDescription]` (164) | none | ➖ |

**Differences:**

- *none* (dead code upstream: a grep of `src/` finds no use outside the file)

## Comparison

<a id="comparison"></a>
Upstream `src/SDL/Comparison.m` ↔ *(absorbed: `==` on `std::optional<std::string>` at the call sites)*

**Status:** done — 6 rows: 0 ✅ 0 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSObject(OLComparison) isEqualTo:]` (50) | `==` on identifiers: Entities/ShipEntity.cpp:3766-3770, :11335 (EQ_MISSILE), Core/Universe.cpp:3146 (route), :8854 (naval energy unit). nil on either side → false, as `object != nil` and messaging nil did | ➖ |
| `-[NSObject(OLComparison) isGreaterThan:]` (55) | none (no caller) | ➖ |
| `-[NSObject(OLComparison) isGreaterThanOrEqualTo:]` (60) | none | ➖ |
| `-[NSObject(OLComparison) isLessThan:]` (65) | none | ➖ |
| `-[NSObject(OLComparison) isLessThanOrEqualTo:]` (70) | none | ➖ |
| `-[NSObject(OLComparison) isNotEqualTo:]` (75) | none | ➖ |

**Differences:**

- subtle — `isEqualTo:` used `-compare:`, which in GNUstep (no `NSLiteralSearch`) can treat a precomposed and a decomposed form of the same character as equal. Port `==` compares bytes. Only non-ASCII equipment identifiers in different normal forms could differ — upstream `SDL/Comparison.m:52` ↔ port `Core/Entities/ShipEntity.cpp:3770`

