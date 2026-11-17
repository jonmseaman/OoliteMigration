# Parity findings: foundation
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## NSBundle+Override

<a id="nsbundleoverride"></a>
Upstream `src/Core/NSBundle+Override.m` ↔ `oofnd/ResourcePaths.hpp` (`builtInResourcesDirectory`), `oofnd/Defaults.hpp` (`Defaults::forProcess`, `applicationDomainName`), and the per-caller `OoliteInfoString` readers

**Status:** done — 1 rows: 0 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSBundle(Override) infoDictionary]` (20) | No NSBundle. The `<cwd>/Resources`, else `<cwd>/../share/oolite/Resources` choice is `ResourcePaths::builtInResourcesDirectory` oofnd/ResourcePaths.hpp:235; the domain name is `Defaults::forProcess` oofnd/Defaults.hpp:451 + `applicationDomainName` :412 (CFBundleIdentifier, else process name); `CFBundleVersion` is read per caller (`OoliteInfoString` Core/OOCacheManager.cpp:84, Entities/PlayerEntity.cpp, Debug/OODebugTCPConsoleClient.cpp) | ➖ |

**Differences:**

- ➖ **low** (still open) — A missing Info-gnustep.plist no longer prints "[Oolite-Core] Warning: Failed to find info-gnustep.plist at calculated path: …" (NSLog, stderr only, not Latest.log); `Defaults::load` returns an empty dict silently — upstream `Core/NSBundle+Override.m:49` ↔ port `oofnd/Defaults.hpp:457-458,600-602`
- subtle (still open) — The fallback path is `lexically_normal()` where upstream used `-stringByStandardizingPath` (also expands `~`, resolves symlinks on GNUstep); only a non-standard Linux layout could tell — upstream `Core/NSBundle+Override.m:34` ↔ port `oofnd/ResourcePaths.hpp:238-240`
- subtle — Upstream re-read the plist on every `-infoDictionary` call; the port reads it once per `Defaults::forProcess` / per `OoliteInfoString` call. Not observable unless the file changes mid-run.

## NSDataOOExtensions

<a id="nsdataooextensions"></a>
Upstream `src/Core/NSDataOOExtensions.m` ↔ `Core/OODataFromOXZFile.cpp` (declared `oofnd/FileSystem.hpp:443`)

**Status:** done — 1 rows: 1 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[NSData(OOExtensions) oo_dataWithOXZFile:]` (37) | `OODataFromOXZFile` Core/OODataFromOXZFile.cpp:39 (statement for statement: the same .oxz component search, the same `files.notFound` texts for empty file / directory / unzip property, open, read and close failures, the same silent nil for an unopenable zip or missing member; nil → `std::nullopt`) | ✅ |

**Differences:**

- subtle (still open) — The empty-file test uses `fs::fileSize` (`std::filesystem::file_size`, follows symlinks) where upstream used `fileAttributesAtPath:traverseLink:NO` (a symlink's own size); only a symlinked plain file can tell — upstream `Core/NSDataOOExtensions.m:60` ↔ port `Core/OODataFromOXZFile.cpp:54`

## NSDictionaryOOExtensions

<a id="nsdictionaryooextensions"></a>
Upstream `src/Core/NSDictionaryOOExtensions.m` ↔ *(absorbed: value copies of `oo::PList::Dict` at the call sites)*

**Status:** done — 3 rows: 0 ✅ 0 ⚠️ 0 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSDictionary(OOExtensions) dictionaryByAddingObject:forKey:]` (32) | Callers copy the PList and assign, e.g. `AddingValue` Materials/OODefaultShaderSynthesizer.cpp:1100 (a non-dict specifier is returned unchanged) | ➖ |
| `-[NSDictionary(OOExtensions) dictionaryByRemovingObjectForKey:]` (46) | `erase` on a copy, e.g. Materials/OODefaultShaderSynthesizer.cpp:1177 | ➖ |
| `-[NSDictionary(OOExtensions) dictionaryByAddingEntriesFromDictionary:]` (60) | `AddEntries` (insert_or_assign over a copy; non-dict `from` adds nothing, as nil did) Core/OOShipRegistry.cpp:149 | ➖ |

**Differences:**

- subtle (still open) — `AddingValue(spec, key, PList())` would store a null entry where upstream returned the dictionary unchanged for a nil object (`:35`); every caller passes a non-null value — upstream `Core/NSDictionaryOOExtensions.m:35` ↔ port `Core/Materials/OODefaultShaderSynthesizer.cpp:1100-1104`

## NSFileManagerOOExtensions

<a id="nsfilemanagerooextensions"></a>
Upstream `src/Core/NSFileManagerOOExtensions.m` ↔ `oofnd/FileSystem.hpp` (`oo::fs`), `oofnd/ResourcePaths.hpp`, `Core/OODataFromOXZFile.cpp`, and inlined call sites

**Status:** done — 16 rows: 9 ✅ 0 ⚠️ 1 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSFileManager(OOExtensions) commanderContentsOfPath:]` (39) | Inlined in the commander listing, Entities/PlayerEntityLoadSave.cpp:1039-1050. Upstream's per-entry filter `!exists && isDirectory` (`:51`) never holds, so it only built full paths; the port builds the same paths and logs the same `savedGame.read.fail.fileNotFound` ERROR text | ✅ |
| `-[NSFileManager(OOExtensions) defaultCommanderPath]` (79) | `GameController::playerFileDirectory` Core/GameController.cpp:747-769 (`ResourcePaths::saveDirectory` oofnd/ResourcePaths.hpp:177), equivalent with both logs; second inline copy in `GlobalTakeSnapShot` Scripting/OOJSGlobal.cpp:847-859 without the logs | ❌ |
| `-[NSFileManager(OOExtensions) oo_directoryContentsAtPath:]` (113) | `#if OOLITE_MAC_OS_X`: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_createDirectoryAtPath:attributes:]` (118) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_fileAttributesAtPath:traverseLink:]` (123) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_fileSystemAttributesAtPath:]` (137) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_removeItemAtPath:]` (142) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_moveItemAtPath:toPath:]` (147) | Mac only: not built | ➖ |
| `-[NSFileManager(OOExtensions) oo_directoryContentsAtPath:]` (154) | `oo::fs::directoryContents` oofnd/FileSystem.hpp:261 (names only, no `.`/`..`, OS order) | ✅ |
| `-[NSFileManager(OOExtensions) oo_createDirectoryAtPath:attributes:]` (159) | `oo::fs::createDirectories` oofnd/FileSystem.hpp:278 (intermediate dirs; fails when a non-directory is in the way) | ✅ |
| `-[NSFileManager(OOExtensions) oo_fileAttributesAtPath:traverseLink:]` (164) | `oo::fs::fileSize` :158 / `modificationTimeSince1970` :177 (both follow links) | ✅ |
| `-[NSFileManager(OOExtensions) oo_fileSystemAttributesAtPath:]` (169) | `oo::fs::freeSpace` oofnd/FileSystem.hpp:167 (`space().available`; NSFileSystemFreeSize was the only key read) | ✅ |
| `-[NSFileManager(OOExtensions) oo_removeItemAtPath:]` (174) | `oo::fs::removeItem` oofnd/FileSystem.hpp:291 (missing path is an error, as `removeFileAtPath:handler:`; recursive) | ✅ |
| `-[NSFileManager(OOExtensions) oo_moveItemAtPath:toPath:]` (179) | `oo::fs::moveItem` oofnd/FileSystem.hpp:303 (refuses a missing source or existing destination, then `rename`) | ✅ |
| `-[NSFileManager(OOExtensions) chdirToSnapshotPath]` (187) | Inlined in `MyOpenGLView::snapShot` SDL/MyOpenGLView.cpp:1209-1225 + `ResourcePaths::snapshotDirectory` oofnd/ResourcePaths.hpp:182: chdir, else mkdir + chdir, the same two log classes and texts; the BOOL was ignored by its only caller | ✅ |
| `-[NSFileManager(OOExtensions) oo_oxzFileExistsAtPath:]` (215) | `OOOxzFileExistsAtPath` Core/OODataFromOXZFile.cpp:147 | ✅ |

**Differences:**

- ❌ **low** (still open) — `takeSnapShot` re-implements `-defaultCommanderPath` inline without its two ERROR logs (`savedGame.defaultPath.create.failed`, `savedGame.defaultPath.notDirectory`), which upstream printed whenever the JS call met an uncreatable or non-directory save dir; the `GameController` copy does log — upstream `Core/NSFileManagerOOExtensions.m:97,104` (via `Core/Scripting/OOJSGlobal.m:711`) ↔ port `Core/Scripting/OOJSGlobal.cpp:847-859`
- subtle (still open) — `directoryContents` returns an error, losing the whole listing, if iteration fails part-way; GNUstep's `directoryContentsAtPath:` returned what it had read — upstream `Core/NSFileManagerOOExtensions.m:156` ↔ port `oofnd/FileSystem.hpp:261-274`
- subtle (still open) — `moveItem` is a bare `rename`; GNUstep's `movePath:toPath:handler:` falls back to copy+delete across volumes — upstream `Core/NSFileManagerOOExtensions.m:181` ↔ port `oofnd/FileSystem.hpp:303-315`

## NSMutableDictionaryOOExtensions

<a id="nsmutabledictionaryooextensions"></a>
Upstream `src/Core/NSMutableDictionaryOOExtensions.m` ↔ `Core/ResourceManager.cpp` (`MergeEntries`)

**Status:** done — 1 rows: 1 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSMutableDictionary(OOExtensions) mergeEntriesFromDictionary:]` (30) | `MergeEntries` Core/ResourceManager.cpp:272: a missing key is added; two unequal dicts merge recursively into a copy; two unequal arrays concatenate; anything else is replaced. `-isEqual:` becomes `PListIsEqual` :198 (numbers by value across kinds, as NSNumber) | ✅ |

**Differences:**

- *none* (key iteration order is the map's, upstream's was hash order; each key is handled independently, so the result is the same)

## NSNumberOOExtensions

<a id="nsnumberooextensions"></a>
Upstream `src/Core/NSNumberOOExtensions.m` ↔ *(absorbed: `oo::PList` node kinds)*

**Status:** done — 2 rows: 0 ✅ 0 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSNumber(OOExtensions) oo_isFloatingPointNumber]` (33) | `PList::isReal()` oofnd/PList.hpp:205 (the `d`/`f` objCType test is the Real kind; `isSinglePrecision()` :215 keeps `f`) | ➖ |
| `-[NSNumber(OOExtensions) oo_isBoolean]` (47) | `PList::isBool()` oofnd/PList.hpp:203 (the YES/NO identity test is the Bool kind) | ➖ |

**Differences:**

- *none* (the PList kind carries exactly what the objCType/identity tests recovered)

## NSObjectOOExtensions

<a id="nsobjectooextensions"></a>
Upstream `src/Core/NSObjectOOExtensions.m` ↔ *(absorbed: per-class `objectSize()` and `oo::EntityObjectSize`)*

**Status:** done — 2 rows: 0 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[NSObject(OOExtensions) oo_instanceSize]` (38) | `sizeof *this` in each class's virtual `objectSize()` (Core/OODrawable.h:95, Materials/OOMaterial.h:83, Core/OOMesh.h:153) | ➖ |
| `-[NSObject(OOExtensions) oo_objectSize]` (43) | `objectSize()` as above for drawables/materials/meshes; for entities `oo::EntityObjectSize` Entities/EntityHelpers.h:71, which now returns a constant `3 * sizeof(void*)` (used by Entity.cpp:133, EntityHelpers.cpp:78,92, Debug/OODebugMonitor.cpp:389) | ❌ |

**Differences:**

- ❌ **low** (new) — `oo::EntityObjectSize` returns a fixed 24 bytes for every entity ("its object's size: three pointers") instead of the entity's instance size, so `gTotalEntityMemory`, the FPS-line "(N, X KiB, avg 24 bytes)" in `dial_objinfo` and the debug monitor's per-entity sizes no longer reflect entity size. Debug-monitor builds only, diagnostic — upstream `Core/NSObjectOOExtensions.m:43-46` (via `Core/Entities/Entity.m:91,109`, `Core/Entities/PlayerEntity.m:4399`) ↔ port `Core/Entities/EntityHelpers.h:68-71`, `Core/Entities/PlayerEntity.cpp:5118-5122`
- ➖ **low** (still open) — Non-entity sizes use C++ `sizeof` where upstream used `class_getInstanceSize` (isa + ivars); the debug-console memory report's numbers differ — upstream `Core/NSObjectOOExtensions.m:40` ↔ port `Core/OODrawable.h:95`

## NSScannerOOExtensions

<a id="nsscannerooextensions"></a>
Upstream `src/Core/NSScannerOOExtensions.m` ↔ `oofnd/Scanner.hpp`

**Status:** done — 2 rows: 2 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSScanner(OOExtensions) ooliteScanCharactersFromSet:intoString:]` (29) | `Scanner::scanCharactersFromSetNoSkip` oofnd/Scanner.hpp:524 → `scanRun(set, true, false)` :552 | ✅ |
| `-[NSScanner(OOExtensions) ooliteScanUpToCharactersFromSet:intoString:]` (54) | `Scanner::scanUpToCharactersFromSetNoSkip` :528 → `scanRun(set, false, false)` | ✅ |

**Differences:**

- *none* (no skipping, UTF-16 units, an empty match returns false with the location unchanged; upstream set it to the same value)

## NSStringOOExtensions

<a id="nsstringooextensions"></a>
Upstream `src/Core/NSStringOOExtensions.m` ↔ `oofnd/String.hpp`, `oofnd/Encoding.hpp`

**Status:** done — 13 rows: 8 ✅ 1 ⚠️ 1 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[NSString(OOExtensions) stringWithContentsOfUnicodeFile:]` (31) | The game decodes with `oo::str::decodeUnicodeText` oofnd/Encoding.hpp:1347 over `OODataFromOXZFile` bytes (ResourceManager.cpp:2212, Scripting/OOJSScript.cpp:712, Scripting/OOJavaScriptEngine.cpp:549, Debug/OODebugMonitor.cpp:751). A second decoder, `oo::str::decodeUnicodeFile` oofnd/String.hpp:429, is the one pinned against GNUstep 1.31.1 (tests/unit/oofnd/test_unicode_file_decode.cpp) but has no game caller; the two differ on repeated BOMs | ❌ |
| `+[NSString(OOExtensions) stringWithUTF16String:]` (86) | `oo::utf16ToUtf8` (its only caller, the SpiderMonkey error reporter, went with QuickJS) | ➖ |
| `-[NSString(OOExtensions) utf16DataWithBOM:]` (102) | `oo::str::utf16Data` oofnd/String.hpp:354 (little-endian units, optional leading U+FEFF) | ✅ |
| `-[NSString(OOExtensions) oo_hash]` (133) | `oo::str::ooHash` oofnd/String.hpp:346 (5381, `((h<<5)+h) ^ unit` over UTF-16 units) | ✅ |
| `-[NSString(OOExtensions) stringByTrimmingLeadingCharactersInSet:]` (143) | `oo::str::trimLeading` oofnd/String.hpp:316 (all members → "") | ✅ |
| `-[NSString(OOExtensions) stringByTrimmingLeadingWhitespaceAndNewlineCharacters]` (152) | `trimLeadingWhitespaceAndNewlines` oofnd/String.hpp:331 | ✅ |
| `-[NSString(OOExtensions) stringByTrimmingTrailingCharactersInSet:]` (157) | `oo::str::trimTrailing` oofnd/String.hpp:324 | ✅ |
| `-[NSString(OOExtensions) stringByTrimmingTrailingWhitespaceAndNewlineCharacters]` (166) | `trimTrailingWhitespaceAndNewlines` oofnd/String.hpp:334 | ✅ |
| `-[NSMutableString(OOExtensions) appendLine:]` (175) | `oo::str::appendLine` oofnd/String.hpp:474 (line + "\n"; a null line cannot occur) | ✅ |
| `-[NSMutableString(OOExtensions) appendFormatLine:]` (180) | callers append `std::format(…)` + `"\n"` | ➖ |
| `-[NSMutableString(OOExtensions) appendFormatLine:arguments:]` (188) | as above | ➖ |
| `-[NSMutableString(OOExtensions) deleteCharacterAtIndex:]` (195) | `oo::str::deleteUnitAt` oofnd/String.hpp:482 (one UTF-16 unit; past the end ignored, comment :479-481) | ⚠️ |
| `OOTabString` (202) | `oo::str::tabString` oofnd/String.hpp:469 (`count` tabs; upstream's static table + recursion gives the same string) | ✅ |

**Differences:**

- ❌ **low** (new) — The game's `decodeUnicodeText` applies `-initWithCharacters:`'s mark handling once (`applyInitWithCharactersBOM`, oofnd/PList.hpp:561) and drops one leading UTF-8 BOM after the skipped one, but the GNUstep 1.31.1 probe (pinned on `decodeUnicodeFile`) shows the mark handling applied twice in the UTF-16 path and up to two further U+FEFF dropped in the UTF-8 path. A file starting FF FE FF FE FF FE … or with three UTF-8 BOMs keeps a stray U+FEFF in the port. The tested decoder is unused by the game — upstream `Core/NSStringOOExtensions.m:52-73` ↔ port `oofnd/Encoding.hpp:1347-1377` vs `oofnd/String.hpp:429-459`
- ⚠️ **low** (still open) — After a UTF-8 BOM upstream decoded `length + 3` bytes (six past the buffer, heap junk could flip the result to Latin-1); both port decoders use the file's own bytes, documented in the `oofnd/Encoding.hpp` banner ("One deliberate difference") and String.hpp:425-427 — upstream `Core/NSStringOOExtensions.m:67` ↔ port `oofnd/Encoding.hpp:50-56,1369-1370`
- ⚠️ **low** (still open) — `deleteCharacterAtIndex:` past the end raised NSRangeException; `deleteUnitAt` ignores it ("oofnd does not throw") — upstream `Core/NSStringOOExtensions.m:197` ↔ port `oofnd/String.hpp:479-487`
- ⚠️ **low** (still open) — Case mapping (`-uppercaseString` etc.) uses ICU simple case mapping, not GNUstep 1.31.1's table; agrees on U+0000–U+017F (decision `specs/015-icu-string-tables`). Not a row of this file; recorded for continuity.
- subtle (still open) — A big-endian (FE FF) UTF-16 file is read as little-endian units (byte-swapped text) in both, deliberately — upstream `Core/NSStringOOExtensions.m:52-58` ↔ port `oofnd/Encoding.hpp:1351-1360`

## NSThreadOOExtensions

<a id="nsthreadooextensions"></a>
Upstream `src/Core/NSThreadOOExtensions.m` ↔ `oofnd/Thread.hpp`

**Status:** done — 1 rows: 1 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[NSThread(OOExtensions) ooSetCurrentThreadName:]` (36) | `oo::thread::setCurrentName` oofnd/Thread.hpp:71 (SetThreadDescription on Windows, what GNUstep's `-setName:` calls; pthread elsewhere). Callers keep the names "OOAsyncWorkManager thread N" (Core/OOAsyncWorkManager.cpp:214) and the logger thread (oofnd/LogFile.hpp:225) | ✅ |

**Differences:**

- *none* (Linux truncates to 15 bytes, a platform limit; Windows is the target)

## NSUserDefaults+Override

<a id="nsuserdefaultsoverride"></a>
Upstream `src/Core/NSUserDefaults+Override.m` ↔ `oofnd/Defaults.hpp` (`Defaults::synchronize`, `writeOpenStepPList`)

**Status:** done — 1 rows: 0 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSUserDefaults(Override) writeDictionary:toFile:]` (36) | `Defaults::synchronize` oofnd/Defaults.hpp:562: an emptied domain → `fs::removeItem`; otherwise OpenStep text from `writeOpenStepPList`, written by `fs::writeFile` (default atomic) after `createDirectories` | ❌ |

**Differences:**

- ❌ **low** (still open) — The failure logs are gone: upstream logged `NSUserDefaultsOverride` "Failed to serialize defaults database for writing: …", "Failed to write defaults database to file: …" and the empty-filename message; `synchronize()` only returns `false`, so a failed preferences save is invisible in Latest.log — upstream `Core/NSUserDefaults+Override.m:39-40,54,56` ↔ port `oofnd/Defaults.hpp:573-588`

## OOAsyncQueue

<a id="ooasyncqueue"></a>
Upstream `src/Core/OOAsyncQueue.m` ↔ `Core/OOAsyncWorkManager.cpp` (`TaskQueue`, anonymous namespace). The log writer's queue moved to `oofnd/LogFile.hpp` (audited under OOLogOutputHandler).

**Status:** done — 14 rows: 4 ✅ 0 ⚠️ 0 ❌ 10 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `AllocElement` (62) | `std::deque` storage | ➖ |
| `FreeElement` (67) | `std::deque` storage | ➖ |
| `-[OOAsyncQueue init]` (82) | `TaskQueue` implicit ctor Core/OOAsyncWorkManager.cpp:55 (mutex + `condition_variable_any`) | ➖ |
| `-[OOAsyncQueue dealloc]` (97) | implicit dtor (the managers are never destroyed; the `asyncQueue.nonEmpty` WARN path was unreachable) | ➖ |
| `-[OOAsyncQueue description]` (121) | none | ➖ |
| `-[OOAsyncQueue enqueue:]` (127) | `TaskQueue::enqueue` Core/OOAsyncWorkManager.cpp:57 (null → false; holds a `shared_ptr` via `oo::share`; FIFO; notify one) | ✅ |
| `-[OOAsyncQueue dequeue]` (175) | `TaskQueue::dequeue()` :69 (blocks until non-empty); a stop-token overload :79 serves the work threads | ✅ |
| `-[OOAsyncQueue tryDequeue]` (181) | `TaskQueue::tryDequeue` :88 (null when empty) | ✅ |
| `-[OOAsyncQueue empty]` (202) | none (no caller; upstream's answer was inverted, `_head != NULL`) | ➖ |
| `-[OOAsyncQueue count]` (207) | none (no caller) | ➖ |
| `-[OOAsyncQueue emptyQueue]` (212) | none (no caller) | ➖ |
| `-[OOAsyncQueue(OOPrivate) doEmptyQueueWithAcquiredLock]` (225) | none | ➖ |
| `-[OOAsyncQueue(OOPrivate) doDequeAndUnlockWithAcquiredLock]` (246) | folded into `dequeue`/`tryDequeue` :69-96 (returns a `shared_ptr` where upstream autoreleased) | ✅ |
| `-[OOAsyncQueue(OOPrivate) recycleElementWithAcquiredLock:]` (280) | `std::deque` storage | ➖ |

**Differences:**

- subtle (still open) — Upstream's `doDequeAndUnlockWithAcquiredLock` could return nil when the head was NULL despite the condition ("can happen if you enter debugger"); the port's `dequeue` loops until a task is there — upstream `Core/OOAsyncQueue.m:251-254` ↔ port `Core/OOAsyncWorkManager.cpp:72`
- subtle (new) — `dequeue(stop_token)` returns null when a stop is requested, which the work threads use to exit (see OOAsyncWorkManager `shutdown`); upstream's queue had no stop path — port `Core/OOAsyncWorkManager.cpp:79-86`

## OOAsyncWorkManager

<a id="ooasyncworkmanager"></a>
Upstream `src/Core/OOAsyncWorkManager.m` ↔ `Core/OOAsyncWorkManager.cpp` (423 / 503 lines)

**Status:** done — 24 rows: 14 ✅ 5 ⚠️ 0 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitAsyncWorkManager` (95) | `MakeAsyncWorkManager` Core/OOAsyncWorkManager.cpp:239 (operation-queue manager if `canBeUsed`, else manual dispatch; the same FATAL `asyncWorkManager.setUpDispatcher.failed` path and `asyncWorkManager.dispatchMethod` "Selected async work manager: <class>" line) | ✅ |
| `+[OOAsyncWorkManager initialize]` (121) | the function-local static's thread-safe initialisation in `sharedAsyncWorkManager` :273 (replaces the NSLock) | ✅ |
| `+[OOAsyncWorkManager sharedAsyncWorkManager]` (130) | `OOAsyncWorkManager::sharedAsyncWorkManager` Core/OOAsyncWorkManager.cpp:270 | ✅ |
| `+[OOAsyncWorkManager allocWithZone:]` (148) | — (the manager is made once and its holder leaked, :244-257) | ➖ |
| `-[OOAsyncWorkManager dealloc]` (157) | `~OOAsyncWorkManager` → `abort()` Core/OOAsyncWorkManager.cpp:278 | ✅ |
| `-[OOAsyncWorkManager release]` (163) | — (never destroyed) | ➖ |
| `-[OOAsyncWorkManager retain]` (167) | — (never destroyed) | ➖ |
| `-[OOAsyncWorkManager retainCount]` (172) | — (never destroyed) | ➖ |
| `-[OOAsyncWorkManager addTask:priority:]` (177) | `OOAsyncWorkManager::addTask` :280 (subclass-responsibility log, false) | ✅ |
| `-[OOAsyncWorkManager completePendingTasks]` (183) | `OOAsyncWorkManager::completePendingTasks` :286 | ✅ |
| `-[OOAsyncWorkManager waitForTaskToComplete:]` (188) | `OOAsyncWorkManager::waitForTaskToComplete` :290 (log + OOInternalInconsistencyException "%s called.") | ✅ |
| `-[OOAsyncWorkManagerInternal init]` (198) | `OOAsyncWorkManagerInternal()` :298 (queue, set and lock are members; the nil branch is gone) | ✅ |
| `-[OOAsyncWorkManagerInternal completePendingTasks]` (220) | `OOAsyncWorkManagerInternal::completePendingTasks` :312 (same drain under the pending lock) | ✅ |
| `-[OOAsyncWorkManagerInternal waitForTaskToComplete:]` (236) | `OOAsyncWorkManagerInternal::waitForTaskToComplete` :326 (same membership test, then dequeue+complete until the task comes back) | ✅ |
| `-[OOAsyncWorkManagerInternal queueResult:]` (268) | `queueResult` :356 (`hasCompleteAsyncTask()` for `respondsToSelector:`) | ✅ |
| `-[OOAsyncWorkManagerInternal noteTaskQueued:]` (275) | `noteTaskQueued` :362 (vector used as an identity set, added once) | ✅ |
| `-[OOManualDispatchAsyncWorkManager init]` (293) | `OOManualDispatchAsyncWorkManager()` :372 + `WorkThreadCount` :182 + `StartWorkThreads` :198 (owned `std::jthread`s, numbered from 1) | ⚠️ |
| `-[OOManualDispatchAsyncWorkManager addTask:priority:]` (318) | `OOManualDispatchAsyncWorkManager::addTask` :383 (null → false; note, then enqueue; priority ignored) | ✅ |
| `-[OOManualDispatchAsyncWorkManager queueTask:]` (329) | `queueTask` :393 + `SetUpWorkThread` :212 (priority 0.5, name "OOAsyncWorkManager thread N") | ⚠️ |
| `+[OOOperationQueueAsyncWorkManager canBeUsed]` (363) | `canBeUsed` :423 (only `disable-operation-queue-work-manager`) | ⚠️ |
| `-[OOOperationQueueAsyncWorkManager init]` (371) | `OOOperationQueueAsyncWorkManager()` :428 (a member `OOPrioritizedTaskQueue` served by `WorkThreadCount()` work threads) | ⚠️ |
| `-[OOOperationQueueAsyncWorkManager dealloc]` (385) | `~OOOperationQueueAsyncWorkManager` :163 calls `shutdown()` (never reached: never destroyed) | ➖ |
| `-[OOOperationQueueAsyncWorkManager addTask:priority:]` (392) | `OOOperationQueueAsyncWorkManager::addTask` :436 (null → false; low/high/else-medium bucket; queue then `noteTaskQueued`, upstream's order) | ✅ |
| `-[OOOperationQueueAsyncWorkManager dispatchTask:]` (413) | `dispatchTask` :494 + `workThread` :456 (high → low, FIFO within a priority) | ⚠️ |

**Differences:**

- ⚠️ **low** (still open) — Task exceptions: upstream `@catch (id)` swallowed everything; the port catches only the game's exceptions (`oo::CurrentOOException()`) and rethrows others on the work thread (→ `std::terminate`), as its comment says ("the game's exceptions only") — upstream `Core/OOAsyncWorkManager.m:342-346,415-419` ↔ port `Core/OOAsyncWorkManager.cpp:405-409,495-499`
- ⚠️ **low** (still open) — NSOperationQueue is replaced by min(OOCPUCount(), 8) (8 in OO_DEBUG) own threads, high→low then FIFO (comment :411-417). Concurrency and completion order of async tasks (texture loads, cache write) can differ; no log text changes — upstream `Core/OOAsyncWorkManager.m:371-411` ↔ port `Core/OOAsyncWorkManager.cpp:428-500`
- ⚠️ **low** (still open) — `canBeUsed` no longer checks that `NSInvocationOperation` exists; on GNUstep 1.31 both pick the operation-queue manager — upstream `Core/OOAsyncWorkManager.m:363-368` ↔ port `Core/OOAsyncWorkManager.cpp:423-426`
- ⚠️ **low** (new) — The work threads are now owned `std::jthread`s and `GameController::exitAppWithContext` calls `shutdown()` before saving defaults: waiting workers stop, but a worker in the middle of a task (texture load, data-cache write) is joined, so exit waits for it, where upstream's detached threads were killed by `exit(0)`. Queued-but-unstarted tasks are dropped in both. Documented in the comments (commit 3616632fa) — upstream `Core/OOAsyncWorkManager.m:310-312`, `Core/GameController.m` exit path ↔ port `Core/OOAsyncWorkManager.cpp:303-310`, `Core/GameController.cpp:696-698`
- subtle (✅, still open) — the dispatch-method line prints the class name as a literal, matching `%@` of `[sSingleton class]` — upstream `Core/OOAsyncWorkManager.m:115` ↔ port `Core/OOAsyncWorkManager.cpp:266-267`
- subtle (✅, still open) — the base `waitForTaskToComplete` exception text uses C++ `__PRETTY_FUNCTION__`; reached only on a subclass-responsibility bug — upstream `Core/OOAsyncWorkManager.m:191` ↔ port `Core/OOAsyncWorkManager.cpp:293`

## OOCPUInfo

<a id="oocpuinfo"></a>
Upstream `src/Core/OOCPUInfo.m` ↔ `Core/OOCPUInfo.cpp` (226 / 235 lines)

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOCPUInfoInit` (60) | `OOCPUInfoInit` Core/OOCPUInfo.cpp:64 (same endian checks and `cpuInfo.endianTest.failed` texts, `std::bit_cast` for the pointer pun; GetSystemInfo CPU count) | ✅ |
| `OOCPUCount` (99) | `OOCPUCount` Core/OOCPUInfo.cpp:103 (0 → 1) | ✅ |
| `OOCPUID` (115) *(added: inline asm function the extractor missed)* | `OOCPUID` Core/OOCPUInfo.cpp:115 (same asm) | ✅ |
| `OOCPUDescription` (132) | `OOCPUDescription` Core/OOCPUInfo.cpp:131 | ✅ |
| `OOSystemMemoryStatus` (154) | `OOSystemMemoryStatus` Core/OOCPUInfo.cpp:152 (MiB, GlobalMemoryStatusEx) | ✅ |
| `operatingSystemFullVersion` (181) | `operatingSystemFullVersion` Core/OOCPUInfo.cpp:180 ("maj.min.build[.UBR] <CSD>", `%S` converted UTF-16→UTF-8) | ✅ |
| `is64BitSystem` (210) | `is64BitSystem` Core/OOCPUInfo.cpp:218 | ✅ |

**Differences:**

- ✅ subtle (still open) — `operatingSystemFullVersion`'s service-pack string is converted explicitly and printed with `{}`, as `-stringWithFormat:`'s `%S` did; it feeds the log header's Windows line — upstream `Core/OOCPUInfo.m:202-203` ↔ port `Core/OOCPUInfo.cpp:202-212`
- subtle (changed since 2026-10-27) — `CPUBrandString` is now zero-initialised (`std::array<char,0x40>{}`), so a CPU reporting fewer than 0x80000004 extended leaves gives "" where upstream read uninitialised stack (garbage); a 48-byte brand without NUL now ends at 48 bytes. The previous audit recorded "same UB both sides" — upstream `Core/OOCPUInfo.m:136,150` ↔ port `Core/OOCPUInfo.cpp:135,148`

## OOCache

<a id="oocache"></a>
Upstream `src/Core/OOCache.m` ↔ `Core/OOCache.cpp` (1048 / 975 lines)

**Status:** done — 48 rows: 44 ✅ 3 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCache dealloc]` (185) | `~OOCache` Core/OOCache.cpp:181 | ✅ |
| `-[OOCache description]` (193) | `OOCache::descriptionComponents` Core/OOCache.cpp:188 (same text; nil name "(null)") | ✅ |
| `-[OOCache init]` (198) | `OOCache::cacheWithPList(oo::PList())` Core/OOCache.cpp:195 | ✅ |
| `-[OOCache initWithPList:]` (203) | `OOCache::initWithPList` Core/OOCache.cpp:201 (non-array → failure, nullptr) | ✅ |
| `-[OOCache pListRepresentation]` (235) | `OOCache::pListRepresentation` Core/OOCache.cpp:221 | ✅ |
| `-[OOCache objectForKey:]` (242) | `OOCache::pListForKey` Core/OOCache.cpp:225 (a copy of the value; null when absent) | ✅ |
| `-[OOCache setObject:forKey:]` (256) | `OOCache::setPList` Core/OOCache.cpp:239 | ✅ |
| `-[OOCache removeObjectForKey:]` (269) | `OOCache::removePListForKey` Core/OOCache.cpp:250 | ✅ |
| `-[OOCache setPruneThreshold:]` (279) | `OOCache::setPruneThreshold` Core/OOCache.cpp:258 (MAX with the minimum) | ✅ |
| `-[OOCache pruneThreshold]` (289) | `OOCache::pruneThreshold` Core/OOCache.cpp:267 | ✅ |
| `-[OOCache setAutoPrune:]` (294) | `OOCache::setAutoPrune` Core/OOCache.cpp:269 | ✅ |
| `-[OOCache autoPrune]` (303) | `OOCache::autoPrune` Core/OOCache.cpp:277 | ✅ |
| `-[OOCache prune]` (308) | `OOCache::prune` Core/OOCache.cpp:279 (4/5 rounding, no-prune and count tests in the same order, same log class/text, indent/outdent) | ✅ |
| `-[OOCache dirty]` (335) | `OOCache::dirty` Core/OOCache.cpp:307 | ✅ |
| `-[OOCache markClean]` (340) | `OOCache::markClean` Core/OOCache.cpp:309 | ✅ |
| `-[OOCache name]` (345) | `OOCache::name` Core/OOCache.cpp:311 | ✅ |
| `-[OOCache setName:]` (350) | `OOCache::setName` Core/OOCache.cpp:313 | ✅ |
| `-[OOCache objectsByAge]` (355) | `OOCache::pListsByAge` Core/OOCache.cpp:317 | ⚠️ |
| `-[OOCache(Private) loadFromArray:]` (364) | `OOCache::loadFromArray` Core/OOCache.cpp:323 (dict entries with a string `key` and a `value`) | ✅ |
| `CacheAllocate` (414) | `CacheAllocate` Core/OOCache.cpp:372 (value-initialised) | ✅ |
| `CacheFree` (419) | `CacheFree` Core/OOCache.cpp:377 | ✅ |
| `CacheInsert` (429) | `CacheInsert` Core/OOCache.cpp:384 (null value → false) | ✅ |
| `CacheRemove` (444) | `CacheRemove` Core/OOCache.cpp:398 | ✅ |
| `CacheRemoveOldest` (471) | `CacheRemoveOldest` Core/OOCache.cpp:425 (same per-entry prune log) | ✅ |
| `CacheRetrieve` (481) | `CacheRetrieve` Core/OOCache.cpp:436 | ✅ |
| `CacheArrayOfContentsByAge` (497) | `CacheArrayOfContentsByAge` Core/OOCache.cpp:454 (youngest first) | ⚠️ |
| `CacheArrayOfNodesByAge` (513) | `CacheArrayOfNodesByAge` Core/OOCache.cpp:470 (oldest first; null for empty, as nil) | ✅ |
| `CacheGetName` (529) | `CacheGetName` Core/OOCache.cpp:487 | ✅ |
| `CacheSetName` (534) | `CacheSetName` Core/OOCache.cpp:491 | ✅ |
| `CacheGetCount` (540) | `CacheGetCount` Core/OOCache.cpp:497 | ✅ |
| `CacheCheckIntegrity` (547) | `CacheCheckIntegrity` (compiled out, `OOCACHE_PERFORM_INTEGRITY_CHECKS 0`) Core/OOCache.cpp:501 | ✅ |
| `CacheNodeAllocate` (569) | `CacheNodeAllocate` Core/OOCache.cpp:526 | ✅ |
| `CacheNodeFree` (586) | `CacheNodeFree` Core/OOCache.cpp:536 (age-list removal first, then children) | ✅ |
| `CacheNodeGetValue` (610) | `CacheNodeGetValue` Core/OOCache.cpp:548 | ✅ |
| `CacheNodeSetValue` (619) | `CacheNodeSetValue` Core/OOCache.cpp:556 | ✅ |
| `CacheNodeGetDescription` (631) | `CacheNodeGetDescription` (compiled out) Core/OOCache.cpp:565 | ✅ |
| `TreeSplay` (649) | `TreeSplay` Core/OOCache.cpp:582 (same top-down splay; `std::string::compare`) | ⚠️ |
| `TreeInsert` (721) | `TreeInsert` Core/OOCache.cpp:646 (same left/right insertion; same `dataCache.inconsistency` text) | ✅ |
| `TreeCountNodes` (774) | `TreeCountNodes` (compiled out) Core/OOCache.cpp:699 | ✅ |
| `TreeCheckIntegrity` (782) | `TreeCheckIntegrity` (compiled out) Core/OOCache.cpp:707 | ✅ |
| `AgeListMakeYoungest` (835) | `AgeListMakeYoungest` Core/OOCache.cpp:771 | ✅ |
| `AgeListRemove` (850) | `AgeListRemove` Core/OOCache.cpp:783 | ✅ |
| `AgeListCheckIntegrity` (877) | `AgeListCheckIntegrity` (compiled out) Core/OOCache.cpp:804 | ✅ |
| `-[OOCache(DebugGraphViz) appendNodesFromSubTree:toString:]` (959) | `OOCache::appendNodesFromSubTree` (DEBUG_GRAPHVIZ) Core/OOCache.cpp:892 | ✅ |
| `-[OOCache(DebugGraphViz) generateGraphVizBodyWithRootNamed:]` (973) | `OOCache::generateGraphVizBodyWithRootNamed` Core/OOCache.cpp:912 | ✅ |
| `-[OOCache(DebugGraphViz) generateGraphViz]` (1008) | `OOCache::generateGraphViz` Core/OOCache.cpp:952 | ✅ |
| `-[OOCache(DebugGraphViz) writeGraphVizToURL:]` (1029) | folded into `writeGraphVizToPath` (comment :968) | ➖ |
| `-[OOCache(DebugGraphViz) writeGraphVizToPath:]` (1042) | `OOCache::writeGraphVizToPath` Core/OOCache.cpp:969 (atomic write) | ✅ |

**Differences:**

- ⚠️ **low** (still open) — Keys are `std::string` ordered by `std::string::compare` (UTF-8 bytes) instead of `-[NSString compare:]` (UTF-16 units); only the splay-tree shape changes for keys mixing supplementary and U+E000–U+FFFF characters; lookups, age order and `pListRepresentation` are unaffected (documented at the node struct, Core/OOCache.cpp:136) — upstream `Core/OOCache.m:669-691` ↔ port `Core/OOCache.cpp:597-628`
- ⚠️ **low** (still open) — `objectsByAge` of an empty cache returns an empty vector, not nil (documented :453) — upstream `Core/OOCache.m:502-503` ↔ port `Core/OOCache.cpp:459`
- ✅ subtle (still open) — prune logging unchanged: class `dataCache.prune.<name>` (nil → "(null)"), "Pruning cache \"…\" - removing N entries" then per entry "Pruning cache \"…\": removing <key>" — upstream `Core/OOCache.m:325-332,477` ↔ port `Core/OOCache.cpp:296-304,430-431`
- ✅ subtle (still open) — loading from a plist leaves the cache dirty and unpruned (threshold/autoPrune set after `loadFromArray`) in both — upstream `Core/OOCache.m:216-225` ↔ port `Core/OOCache.cpp:210-217`
- ✅ subtle (still open) — the debug-only `node->key is NULL` log in `TreeSplay` is gone (a `std::string` key cannot be nil) — upstream `Core/OOCache.m:665-667` ↔ port `Core/OOCache.cpp:592-596`

## OOCacheManager

<a id="oocachemanager"></a>
Upstream `src/Core/OOCacheManager.m` ↔ `Core/OOCacheManager.cpp` (668 / 565 lines)

**Status:** done — 36 rows: 27 ✅ 2 ⚠️ 0 ❌ 7 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCacheManager init]` (112) | `OOCacheManager::init` Core/OOCacheManager.cpp:103 | ✅ |
| `-[OOCacheManager dealloc]` (122) | `~OOCacheManager` Core/OOCacheManager.cpp:108 | ✅ |
| `-[OOCacheManager description]` (129) | `OOCacheManager::descriptionComponents` Core/OOCacheManager.cpp:113 | ✅ |
| `+[OOCacheManager sharedCache]` (134) | `OOCacheManager::sharedCache` Core/OOCacheManager.cpp:117 (singleton recorded before `init()` runs, as allocWithZone: did) | ✅ |
| `-[OOCacheManager objectForKey:inCache:]` (144) | `OOCacheManager::pListForKey` Core/OOCacheManager.cpp:132 (OO_DEBUG-only logs, same texts) | ✅ |
| `-[OOCacheManager setObject:forKey:inCache:]` (166) | `OOCacheManager::setPList` Core/OOCacheManager.cpp:163 (no-op before load; missing cache created) | ✅ |
| `-[OOCacheManager removeObjectForKey:inCache:]` (190) | `OOCacheManager::removeObjectForKey` Core/OOCacheManager.cpp:179 | ✅ |
| `-[OOCacheManager clearCache:]` (210) | `OOCacheManager::clearCache` Core/OOCacheManager.cpp:205 | ✅ |
| `-[OOCacheManager clearAllCaches]` (223) | `OOCacheManager::clearAllCaches` Core/OOCacheManager.cpp:220 | ✅ |
| `-[OOCacheManager reloadAllCaches]` (230) | `OOCacheManager::reloadAllCaches` Core/OOCacheManager.cpp:226 | ✅ |
| `-[OOCacheManager flush]` (236) | `OOCacheManager::flush` Core/OOCacheManager.cpp:231 | ✅ |
| `-[OOCacheManager finishOngoingFlush]` (244) | `OOCacheManager::finishOngoingFlush` Core/OOCacheManager.cpp:238 | ✅ |
| `-[OOCacheManager setAllowCacheWrites:]` (251) | `OOCacheManager::setAllowCacheWrites` Core/OOCacheManager.cpp:245 | ✅ |
| `-[OOCacheManager cacheDirectoryPathCreatingIfNecessary:]` (256) | `OOCacheManager::cacheDirectoryPathCreatingIfNecessary` Core/OOCacheManager.cpp:250 (`ResourcePaths::cachesDirectory` oofnd/ResourcePaths.hpp:201; removes the old one-level-up `Oolite-cache.plist`) | ✅ |
| `-[OOCacheManager(Private) loadCache]` (285) | `OOCacheManager::loadCache` Core/OOCacheManager.cpp:272 (+ `OoliteInfoString` :84; same `dataCache.found/rebuild/notFound` texts and order) | ✅ |
| `-[OOCacheManager(Private) write]` (348) | `OOCacheManager::write` Core/OOCacheManager.cpp:354 (`dataCache.willWrite`, `dataCache.cantWrite`, format version stored as unsigned) | ✅ |
| `-[OOCacheManager(Private) clear]` (417) | `OOCacheManager::clear` Core/OOCacheManager.cpp:422 | ✅ |
| `-[OOCacheManager(Private) dirty]` (423) | `OOCacheManager::dirty` Core/OOCacheManager.cpp:424 | ✅ |
| `-[OOCacheManager(Private) markClean]` (428) | `OOCacheManager::markClean` Core/OOCacheManager.cpp:426 | ✅ |
| `-[OOCacheManager(Private) loadDict]` (433) | `OOCacheManager::loadDict` Core/OOCacheManager.cpp:428 (`oo::parsePropertyListData`; no binary support) | ⚠️ |
| `-[OOCacheManager(Private) writeDict:]` (472) | `OOCacheManager::writeDict` Core/OOCacheManager.cpp:447 (XML via `oo::writeXMLPList`, non-atomic write as `atomically:NO`) | ⚠️ |
| `-[OOCacheManager(Private) buildCachesFromDictionary:]` (513) | `OOCacheManager::buildCachesFromDictionary` Core/OOCacheManager.cpp:487 (dict-valued caches only, as `oo_dictionaryForKey:`) | ✅ |
| `-[OOCacheManager(Private) dictionaryOfCaches]` (537) | `OOCacheManager::dictionaryOfCaches` Core/OOCacheManager.cpp:507 (value copy for `OODeepCopy`) | ✅ |
| `-[OOCacheManager(Private) directoryExists:create:]` (542) | `OOCacheManager::directoryExists` Core/OOCacheManager.cpp:517 (same two `dataCache.write.buildPath.failed` texts) | ✅ |
| `-[OOCacheManager(Private) cachePathCreatingIfNecessary:]` (567) | Mac variant ("Data Cache.plist"): no port counterpart, not built | ➖ |
| `-[OOCacheManager(Private) cachePathCreatingIfNecessary:]` (575) | `OOCacheManager::cachePathCreatingIfNecessary` Core/OOCacheManager.cpp:539 ("Oolite-cache.plist"; nullopt for nil directory) | ✅ |
| `+[OOCacheManager(Singleton) allocWithZone:]` (594) | — (singleton holder leaked once, :119-126) | ➖ |
| `-[OOCacheManager(Singleton) copyWithZone:]` (603) | — | ➖ |
| `-[OOCacheManager(Singleton) retain]` (608) | — | ➖ |
| `-[OOCacheManager(Singleton) retainCount]` (613) | — | ➖ |
| `-[OOCacheManager(Singleton) release]` (618) | — | ➖ |
| `-[OOCacheManager(Singleton) autorelease]` (622) | — | ➖ |
| `-[OOAsyncCacheWriter initWithCacheContents:]` (632) | `OOAsyncCacheWriter::writerWithCacheContents` Core/OOCacheManager.cpp:547 (null contents → nullptr) | ✅ |
| `-[OOAsyncCacheWriter dealloc]` (645) | implicit `~OOAsyncCacheWriter` Core/OOCacheManager.h:130 | ✅ |
| `-[OOAsyncCacheWriter performAsyncTask]` (652) | `OOAsyncCacheWriter::performAsyncTask` Core/OOCacheManager.cpp:554 (same success/failure log lines; contents released) | ✅ |
| `-[OOAsyncCacheWriter completeAsyncTask]` (662) | `OOAsyncCacheWriter::completeAsyncTask` Core/OOCacheManager.cpp:563 (+ `hasCompleteAsyncTask` → true, h:137) | ✅ |

**Differences:**

- ⚠️ **low** (still open) — The cache file is written as XML instead of GNUstep binary (comment Core/OOCacheManager.cpp:33-37, "oofnd does not parse GNUstep's binary format"); an existing GNUstep-binary `Oolite-cache.plist` cannot be read, so the first run logs `dataCache.badData` "Could not read data cache: …" and rebuilds, where upstream logged `dataCache.found` — upstream `Core/OOCacheManager.m:37-39,449-464,486` ↔ port `Core/OOCacheManager.cpp:435-442,457`
- ⚠️ **low** (still open) — `dataCache.badData` / `dataCache.write.serialize.failed` carry oofnd's parser/writer error text instead of GNUstep's `errorDescription` — upstream `Core/OOCacheManager.m:460,491` ↔ port `Core/OOCacheManager.cpp:438-439,459-461`
- ✅ subtle (still open) — the Oolite version compared against the cache is `CFBundleVersion` from `<builtInResources>/Info-gnustep.plist` (`OoliteInfoString`); a missing or non-string version on either side mismatches and prints "(null)" — upstream `Core/OOCacheManager.m:295,306-309` ↔ port `Core/OOCacheManager.cpp:84-100,286-301`
- ✅ subtle (still open) — `writeDict` failing at `cachePathCreatingIfNecessary` returns before clearing `_scheduledWrite` in both, so later flushes are skipped for the session (faithful) — upstream `Core/OOCacheManager.m:478-480,508` ↔ port `Core/OOCacheManager.cpp:448-449,480-482`
- subtle (new) — Because the work threads are now joined at exit (see OOAsyncWorkManager), a data-cache write already running when the player quits completes before the process exits; upstream's `exit(0)` could cut the non-atomic write short and leave a truncated cache, which the next run rebuilt — port `Core/GameController.cpp:696-698`, `Core/OOCacheManager.cpp:470-471`

## OOCollectionExtractors

<a id="oocollectionextractors"></a>
Upstream `src/Core/OOCollectionExtractors.m` (+ `.h` inlines) ↔ `oofnd/PListGet.hpp` (`PList::get<T>` / `at<T>`, `PListGet<T>`, `plist_get::*`), `Core/OOPListGameTypes.{h,cpp}` (Vector, HPVector, Quaternion, fuzzy boolean), and the NSUserDefaults call sites (`oo::Defaults` in `oofnd/Defaults.hpp`)

**Status:** done — 203 rows: 120 ✅ 2 ⚠️ 5 ❌ 76 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSArray(OOExtractor) oo_charAtIndex:defaultValue:]` (41) | `PList::at<T>(i, d)` oofnd/PListGet.hpp:662 → `PListGet<char>::from` :552 (clamp branch) | ✅ |
| `-[NSArray(OOExtractor) oo_shortAtIndex:defaultValue:]` (46) | `PList::at<T>(i, d)` :662 → `PListGet<short>::from` :552 | ✅ |
| `-[NSArray(OOExtractor) oo_intAtIndex:defaultValue:]` (51) | `PList::at<T>(i, d)` :662 → `PListGet<int>::from` :552 | ✅ |
| `-[NSArray(OOExtractor) oo_longAtIndex:defaultValue:]` (56) | `PList::at<T>(i, d)` :662 → `PListGet<long>::from` :552 (32-bit long clamps, LLP64) | ✅ |
| `-[NSArray(OOExtractor) oo_longLongAtIndex:defaultValue:]` (61) | `PList::at<T>(i, d)` :662 → `PListGet<long long>::from` → `longLongFrom` :333 | ✅ |
| `-[NSArray(OOExtractor) oo_integerAtIndex:defaultValue:]` (66) | `PList::at<T>(i, d)` :662 → `PListGet<long long>` (NSInteger is 64-bit) | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedCharAtIndex:defaultValue:]` (71) | `PList::at<T>(i, d)` :662 → `PListGet<unsigned char>::from` :552 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedShortAtIndex:defaultValue:]` (76) | `PList::at<T>(i, d)` :662 → `PListGet<unsigned short>::from` :552 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedIntAtIndex:defaultValue:]` (81) | `PList::at<T>(i, d)` :662 → `PListGet<unsigned int>::from` :552 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedLongAtIndex:defaultValue:]` (86) | `PList::at<T>(i, d)` :662 → `PListGet<unsigned long>::from` :552 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedLongLongAtIndex:defaultValue:]` (91) | `PList::at<T>(i, d)` :662 → `PListGet<unsigned long long>` → `unsignedLongLongFrom` :343 | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedIntegerAtIndex:defaultValue:]` (96) | `PList::at<T>(i, d)` :662 → `PListGet<unsigned long long>` | ✅ |
| `-[NSArray(OOExtractor) oo_boolAtIndex:defaultValue:]` (101) | `PList::at<T>(i, d)` :662 → `PListGet<bool>` :574 → `boolFrom` :357 | ✅ |
| `-[NSArray(OOExtractor) oo_fuzzyBooleanAtIndex:defaultValue:]` (107) | no `at<>` form (no caller); `OOFuzzyBooleanFromPList` Core/OOPListGameTypes.cpp:141 | ➖ |
| `-[NSArray(OOExtractor) oo_floatAtIndex:defaultValue:]` (113) | `PList::at<T>(i, d)` :662 → `PListGet<float>` :585 → `realFrom` :386 | ✅ |
| `-[NSArray(OOExtractor) oo_doubleAtIndex:defaultValue:]` (118) | `PList::at<T>(i, d)` :662 → `PListGet<double>` :585 | ✅ |
| `-[NSArray(OOExtractor) oo_nonNegativeFloatAtIndex:defaultValue:]` (123) | `PList::at<T>(i, d)` :662 → `PListGet<NonNegative<float>>` :595 → `nonNegativeRealFrom` :403 | ✅ |
| `-[NSArray(OOExtractor) oo_nonNegativeDoubleAtIndex:defaultValue:]` (128) | `PList::at<T>(i, d)` :662 → `PListGet<NonNegative<double>>` :595 | ✅ |
| `-[NSArray(OOExtractor) oo_objectAtIndex:defaultValue:]` (133) | `PList::at<T>` T=`PList` → `PListGet<PList>` :622 | ✅ |
| `-[NSArray(OOExtractor) oo_objectOfClass:atIndex:defaultValue:]` (146) | none: a runtime `Class` has no PList form; callers test the node kind or `dynamic_cast` the Object node | ➖ |
| `-[NSArray(OOExtractor) oo_stringAtIndex:defaultValue:]` (159) | `PList::at<T>` → `PListGet<std::string>` :608 (string, or a number's `-stringValue` via `numberStringValue` :517) | ✅ |
| `-[NSArray(OOExtractor) oo_arrayAtIndex:defaultValue:]` (164) | `PList::at<T>` T=`PList::Array` → `PListGet<K>` :637 | ✅ |
| `-[NSArray(OOExtractor) oo_setAtIndex:defaultValue:]` (169) | none: PList has no set; callers read the array (e.g. Core/ResourceManager.cpp:125) | ➖ |
| `-[NSArray(OOExtractor) oo_dictionaryAtIndex:defaultValue:]` (174) | `PList::at<T>` T=`PList::Dict` → :637 | ✅ |
| `-[NSArray(OOExtractor) oo_dataAtIndex:defaultValue:]` (179) | `PList::at<T>` T=`PList::Data` → :637 | ✅ |
| `-[NSArray(OOExtractor) oo_vectorAtIndex:defaultValue:]` (185) | `PList::at<T>` → `PListGet<Vector>` Core/OOPListGameTypes.h:68 → `OOVectorFromPList` Core/OOPListGameTypes.cpp:45 | ✅ |
| `-[NSArray(OOExtractor) oo_quaternionAtIndex:defaultValue:]` (190) | `PList::at<T>` → `PListGet<Quaternion>` h:88 → `OOQuaternionFromPList` cpp:102 | ✅ |
| `-[NSArray(OOExtractor) oo_charAtIndex:]` (196) | `PList::at<T>(i)` oofnd/PListGet.hpp:669 (default 0) → `PListGet<char>::from` :552 | ✅ |
| `-[NSArray(OOExtractor) oo_shortAtIndex:]` (201) | `PList::at<T>(i)` :669 → `PListGet<short>` | ✅ |
| `-[NSArray(OOExtractor) oo_intAtIndex:]` (206) | `PList::at<T>(i)` :669 → `PListGet<int>` | ✅ |
| `-[NSArray(OOExtractor) oo_longAtIndex:]` (211) | `PList::at<T>(i)` :669 → `PListGet<long>` | ✅ |
| `-[NSArray(OOExtractor) oo_longLongAtIndex:]` (216) | `PList::at<T>(i)` :669 → `PListGet<long long>` | ✅ |
| `-[NSArray(OOExtractor) oo_integerAtIndex:]` (221) | `PList::at<T>(i)` :669 → `PListGet<long long>` | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedCharAtIndex:]` (226) | `PList::at<T>(i)` :669 → `PListGet<unsigned char>` | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedShortAtIndex:]` (231) | `PList::at<T>(i)` :669 → `PListGet<unsigned short>` | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedIntAtIndex:]` (236) | `PList::at<T>(i)` :669 → `PListGet<unsigned int>` | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedLongAtIndex:]` (241) | `PList::at<T>(i)` :669 → `PListGet<unsigned long>` | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedLongLongAtIndex:]` (246) | `PList::at<T>(i)` :669 → `PListGet<unsigned long long>` | ✅ |
| `-[NSArray(OOExtractor) oo_unsignedIntegerAtIndex:]` (251) | `PList::at<T>(i)` :669 → `PListGet<unsigned long long>` | ✅ |
| `-[NSArray(OOExtractor) oo_boolAtIndex:]` (256) | `PList::at<T>(i)` :669 → `PListGet<bool>` :574 (default NO) | ✅ |
| `-[NSArray(OOExtractor) oo_fuzzyBooleanAtIndex:]` (262) | no `at<>` form (no caller); `OOFuzzyBooleanFromPList` Core/OOPListGameTypes.cpp:141 | ➖ |
| `-[NSArray(OOExtractor) oo_floatAtIndex:]` (268) | `PList::at<T>(i)` :669 → `PListGet<float>` :585 | ✅ |
| `-[NSArray(OOExtractor) oo_doubleAtIndex:]` (273) | `PList::at<T>(i)` :669 → `PListGet<double>` :585 | ✅ |
| `-[NSArray(OOExtractor) oo_nonNegativeFloatAtIndex:]` (278) | `PList::at<T>(i)` :669 → `PListGet<NonNegative<float>>` :595 | ✅ |
| `-[NSArray(OOExtractor) oo_nonNegativeDoubleAtIndex:]` (283) | `PList::at<T>(i)` :669 → `PListGet<NonNegative<double>>` :595 | ✅ |
| `-[NSArray(OOExtractor) oo_objectAtIndex:]` (288) | `PList::at(index)` oofnd/PList.hpp:243 (nullptr past the end, as the category's bounds check gave nil) | ✅ |
| `-[NSArray(OOExtractor) oo_objectOfClass:atIndex:]` (296) | none: a runtime `Class` has no PList form | ➖ |
| `-[NSArray(OOExtractor) oo_stringAtIndex:]` (301) | `PList::at<T>(i)` with fallback `""` oofnd/PListGet.hpp:612 (nil not representable; comment :604-606) | ⚠️ |
| `-[NSArray(OOExtractor) oo_arrayAtIndex:]` (306) | `PList::at<T>` T=`PList::Array` → :637 | ✅ |
| `-[NSArray(OOExtractor) oo_setAtIndex:]` (311) | none: PList has no set | ➖ |
| `-[NSArray(OOExtractor) oo_dictionaryAtIndex:]` (316) | `PList::at<T>` T=`PList::Dict` → :637 | ✅ |
| `-[NSArray(OOExtractor) oo_dataAtIndex:]` (321) | `PList::at<T>` T=`PList::Data` → :637 | ✅ |
| `-[NSArray(OOExtractor) oo_vectorAtIndex:]` (327) | `PList::at<T>` → `PListGet<Vector>` (default kZeroVector, OOPListGameTypes.h:71) | ✅ |
| `-[NSArray(OOExtractor) oo_quaternionAtIndex:]` (332) | `PList::at<T>` → `PListGet<Quaternion>` (default kIdentityQuaternion, h:91) | ✅ |
| `-[NSDictionary(OOExtractor) oo_charForKey:defaultValue:]` (342) | `PList::get<T>(k, d)` oofnd/PListGet.hpp:650 → `PListGet<char>::from` :552 | ✅ |
| `-[NSDictionary(OOExtractor) oo_shortForKey:defaultValue:]` (347) | `PList::get<T>(k, d)` :650 → `PListGet<short>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_intForKey:defaultValue:]` (352) | `PList::get<T>(k, d)` :650 → `PListGet<int>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_longForKey:defaultValue:]` (357) | `PList::get<T>(k, d)` :650 → `PListGet<long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_longLongForKey:defaultValue:]` (362) | `PList::get<T>(k, d)` :650 → `PListGet<long long>` → `longLongFrom` :333 | ✅ |
| `-[NSDictionary(OOExtractor) oo_integerForKey:defaultValue:]` (367) | `PList::get<T>(k, d)` :650 → `PListGet<long long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedCharForKey:defaultValue:]` (372) | `PList::get<T>(k, d)` :650 → `PListGet<unsigned char>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedShortForKey:defaultValue:]` (377) | `PList::get<T>(k, d)` :650 → `PListGet<unsigned short>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedIntForKey:defaultValue:]` (382) | `PList::get<T>(k, d)` :650 → `PListGet<unsigned int>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedLongForKey:defaultValue:]` (387) | `PList::get<T>(k, d)` :650 → `PListGet<unsigned long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedLongLongForKey:defaultValue:]` (392) | `PList::get<T>(k, d)` :650 → `PListGet<unsigned long long>` → `unsignedLongLongFrom` :343 | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedIntegerForKey:defaultValue:]` (397) | `PList::get<T>(k, d)` :650 → `PListGet<unsigned long long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_boolForKey:defaultValue:]` (402) | `PList::get<T>(k, d)` :650 → `PListGet<bool>` :574 → `boolFrom` :357 | ✅ |
| `-[NSDictionary(OOExtractor) oo_fuzzyBooleanForKey:defaultValue:]` (408) | `OOFuzzyBooleanFromPList(dict.find(k), d)` Core/OOPListGameTypes.cpp:141 (via `FuzzyBooleanForKey` Entities/ShipEntity.cpp:234; Entities/StationEntity.cpp:1031,1035) | ✅ |
| `-[NSDictionary(OOExtractor) oo_floatForKey:defaultValue:]` (414) | `PList::get<T>(k, d)` :650 → `PListGet<float>` :585 → `realFrom` :386 | ✅ |
| `-[NSDictionary(OOExtractor) oo_doubleForKey:defaultValue:]` (419) | `PList::get<T>(k, d)` :650 → `PListGet<double>` :585 | ✅ |
| `-[NSDictionary(OOExtractor) oo_nonNegativeFloatForKey:defaultValue:]` (424) | `PList::get<T>(k, d)` :650 → `PListGet<NonNegative<float>>` :595 | ✅ |
| `-[NSDictionary(OOExtractor) oo_nonNegativeDoubleForKey:defaultValue:]` (429) | `PList::get<T>(k, d)` :650 → `PListGet<NonNegative<double>>` :595 | ✅ |
| `-[NSDictionary(OOExtractor) oo_objectForKey:defaultValue:]` (434) | `PList::get<T>` T=`PList` → `PListGet<PList>` :622 | ✅ |
| `-[NSDictionary(OOExtractor) oo_objectOfClass:forKey:defaultValue:]` (447) | none: a runtime `Class` has no PList form; callers test the node kind or `dynamic_cast` | ➖ |
| `-[NSDictionary(OOExtractor) oo_stringForKey:defaultValue:]` (460) | `PList::get<T>` → `PListGet<std::string>` :608 | ✅ |
| `-[NSDictionary(OOExtractor) oo_arrayForKey:defaultValue:]` (465) | `PList::get<T>` T=`PList::Array` → :637 | ✅ |
| `-[NSDictionary(OOExtractor) oo_setForKey:defaultValue:]` (470) | none: PList has no set; callers read the array (e.g. Core/ResourceManager.cpp:125,138) | ➖ |
| `-[NSDictionary(OOExtractor) oo_dictionaryForKey:defaultValue:]` (475) | `PList::get<T>` T=`PList::Dict` → :637 | ✅ |
| `-[NSDictionary(OOExtractor) oo_mutableDictionaryForKey:defaultValue:]` (480) | none: no mutable/immutable split; callers mutate their own node (e.g. Core/OOCommodityMarket.cpp:78) | ➖ |
| `-[NSDictionary(OOExtractor) oo_dataForKey:defaultValue:]` (485) | `PList::get<T>` T=`PList::Data` → :637 | ✅ |
| `-[NSDictionary(OOExtractor) oo_vectorForKey:defaultValue:]` (491) | `PList::get<T>` → `PListGet<Vector>` Core/OOPListGameTypes.h:68 → `OOVectorFromPList` cpp:45 | ✅ |
| `-[NSDictionary(OOExtractor) oo_hpvectorForKey:defaultValue:]` (496) | `PList::get<T>` → `PListGet<HPVector>` h:78 → `OOHPVectorFromPList` cpp:78 | ✅ |
| `-[NSDictionary(OOExtractor) oo_quaternionForKey:defaultValue:]` (501) | `PList::get<T>` → `PListGet<Quaternion>` h:88 → `OOQuaternionFromPList` cpp:102 | ✅ |
| `-[NSDictionary(OOExtractor) oo_charForKey:]` (507) | `PList::get<T>(k)` oofnd/PListGet.hpp:657 (default 0) → `PListGet<char>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_shortForKey:]` (512) | `PList::get<T>(k)` :657 → `PListGet<short>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_intForKey:]` (517) | `PList::get<T>(k)` :657 → `PListGet<int>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_longForKey:]` (522) | `PList::get<T>(k)` :657 → `PListGet<long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_longLongForKey:]` (527) | `PList::get<T>(k)` :657 → `PListGet<long long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_integerForKey:]` (532) | `PList::get<T>(k)` :657 → `PListGet<long long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedCharForKey:]` (537) | `PList::get<T>(k)` :657 → `PListGet<unsigned char>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedShortForKey:]` (542) | `PList::get<T>(k)` :657 → `PListGet<unsigned short>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedIntForKey:]` (547) | `PList::get<T>(k)` :657 → `PListGet<unsigned int>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedLongForKey:]` (552) | `PList::get<T>(k)` :657 → `PListGet<unsigned long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedIntegerForKey:]` (557) | `PList::get<T>(k)` :657 → `PListGet<unsigned long long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_unsignedLongLongForKey:]` (562) | `PList::get<T>(k)` :657 → `PListGet<unsigned long long>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_boolForKey:]` (567) | `PList::get<T>(k)` :657 → `PListGet<bool>` (default NO) | ✅ |
| `-[NSDictionary(OOExtractor) oo_fuzzyBooleanForKey:]` (573) | `FuzzyBooleanForKey(dict, k)` (fallback 0.0f) Entities/ShipEntity.cpp:234 → `OOFuzzyBooleanFromPList` | ✅ |
| `-[NSDictionary(OOExtractor) oo_floatForKey:]` (579) | `PList::get<T>(k)` :657 → `PListGet<float>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_doubleForKey:]` (584) | `PList::get<T>(k)` :657 → `PListGet<double>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_nonNegativeFloatForKey:]` (589) | `PList::get<T>(k)` :657 → `PListGet<NonNegative<float>>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_nonNegativeDoubleForKey:]` (594) | `PList::get<T>(k)` :657 → `PListGet<NonNegative<double>>` | ✅ |
| `-[NSDictionary(OOExtractor) oo_objectOfClass:forKey:]` (599) | none: a runtime `Class` has no PList form | ➖ |
| `-[NSDictionary(OOExtractor) oo_stringForKey:]` (604) | `PList::get<T>(k)` with fallback `""` oofnd/PListGet.hpp:612 (nil not representable; comment :604-606) | ⚠️ |
| `-[NSDictionary(OOExtractor) oo_arrayForKey:]` (609) | `PList::get<T>` T=`PList::Array` → :637 | ✅ |
| `-[NSDictionary(OOExtractor) oo_setForKey:]` (614) | none: PList has no set | ➖ |
| `-[NSDictionary(OOExtractor) oo_dictionaryForKey:]` (619) | `PList::get<T>` T=`PList::Dict` → :637 | ✅ |
| `-[NSDictionary(OOExtractor) oo_mutableDictionaryForKey:]` (624) | none: no mutable/immutable split | ➖ |
| `-[NSDictionary(OOExtractor) oo_dataForKey:]` (629) | `PList::get<T>` T=`PList::Data` → :637 | ✅ |
| `-[NSDictionary(OOExtractor) oo_vectorForKey:]` (635) | `PList::get<T>` → `PListGet<Vector>` (default kZeroVector, OOPListGameTypes.h:71) | ✅ |
| `-[NSDictionary(OOExtractor) oo_hpvectorForKey:]` (640) | `PList::get<T>` → `PListGet<HPVector>` (default kZeroHPVector, h:81) | ✅ |
| `-[NSDictionary(OOExtractor) oo_quaternionForKey:]` (645) | `PList::get<T>` → `PListGet<Quaternion>` (default kIdentityQuaternion, h:91) | ✅ |
| `-[NSUserDefaults(OOExtractor) oo_charForKey:defaultValue:]` (655) | no caller; a site would use `PListGet<T>::from(defaults.object(k), d)` | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_shortForKey:defaultValue:]` (660) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_intForKey:defaultValue:]` (665) | `detailLevel` via an `object(k).isNull()` test + `Defaults::integerForKey` (Core/Universe.cpp:310-315); `jsruntime-size-mib` and `enforce-oxp-standards` via `PListGet<int>::from` (Scripting/OOJavaScriptEngine.cpp:170-173, Debug/OODebugStandards.cpp:85-88) | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_longForKey:defaultValue:]` (670) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_longLongForKey:defaultValue:]` (675) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_integerForKey:defaultValue:]` (680) | `sky-color-correction` (default 0) via `Defaults::integerForKey` (Core/OOSkyDrawable.cpp:507-508) | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedCharForKey:defaultValue:]` (685) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedShortForKey:defaultValue:]` (690) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedIntForKey:defaultValue:]` (695) | `max-texture-size`: `PListGet<unsigned int>::from(…, 0x80000000)` (Materials/OOTextureLoader.cpp:310-313), equivalent | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedLongForKey:defaultValue:]` (700) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedLongLongForKey:defaultValue:]` (705) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedIntegerForKey:defaultValue:]` (710) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_boolForKey:defaultValue:]` (715) | `Defaults::boolForKey`, with an `object(k).isNull()` test where the default is YES, at Core/Universe.cpp:327,340,341,343-345,347,360-362, Core/OOLogging.cpp:230-242, Core/GameController.cpp:290-292; `PListGet<bool>::from` (equivalent) at SDL/MyOpenGLView.cpp:169,384-394, Materials/OOTexture.cpp:537-539, OXPVerifier/OOOXPVerifier.cpp:794-796 | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_fuzzyBooleanForKey:defaultValue:]` (721) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_floatForKey:defaultValue:]` (727) | `Defaults::floatForKey` behind `object(k).isNull()` for `fov-value` (Core/Universe.cpp:350-353) and the volume (Core/OOALSound.cpp:66-68); `PListGet<float>::from` (equivalent) at Entities/OOSunEntity.cpp:131-136, Entities/PlayerEntity.cpp:2745-2750,4306-4309, SDL/MyOpenGLView.cpp:309-316,488-492, Materials/OOTexture.cpp:516-519, Materials/OOPlanetTextureGenerator.cpp:452-454 | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_doubleForKey:defaultValue:]` (732) | `Defaults::doubleForKey` behind `object(k).isNull()` for `animation_timer_interval` (Core/GameController.cpp:235-238); `PListGet<double>::from` for `flight-arrow-key-precision-factor` (Entities/PlayerEntityControls.cpp:4845-4848) | ❌ |
| `-[NSUserDefaults(OOExtractor) oo_nonNegativeFloatForKey:defaultValue:]` (737) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_nonNegativeDoubleForKey:defaultValue:]` (742) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_objectForKey:defaultValue:]` (747) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_objectOfClass:forKey:defaultValue:]` (760) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_stringForKey:defaultValue:]` (773) | `PListGet<std::string>::from` at each site (SDL/MyOpenGLView.cpp:67 `DefaultsString`, Entities/PlayerEntityKeyMapper.cpp:85 `KeyboardCode`, Entities/PlayerEntityControls.cpp:318-320, SDL/MyOpenGLView+Input.cpp:50-52), equivalent | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_arrayForKey:defaultValue:]` (778) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_setForKey:defaultValue:]` (783) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_dictionaryForKey:defaultValue:]` (788) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_dataForKey:defaultValue:]` (793) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_charForKey:]` (798) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_shortForKey:]` (803) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_intForKey:]` (808) | no caller (the `detailLevel` site has a default; see :665) | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_longForKey:]` (813) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_longLongForKey:]` (818) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedCharForKey:]` (823) | its one caller, `js-gc-zeal` (SpiderMonkey GC zeal), is gone with QuickJS | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedShortForKey:]` (828) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedIntForKey:]` (833) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedLongForKey:]` (838) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_unsignedLongLongForKey:]` (843) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_fuzzyBooleanForKey:]` (849) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_doubleForKey:]` (855) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_nonNegativeFloatForKey:]` (860) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_nonNegativeDoubleForKey:]` (865) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_objectOfClass:forKey:]` (870) | no caller | ➖ |
| `-[NSUserDefaults(OOExtractor) oo_setForKey:]` (875) | no caller | ➖ |
| `-[NSMutableArray(OOInserter) oo_addInteger:]` (884) | callers store `PList::signedInteger` / `PList(int64)` oofnd/PList.hpp:183,165 | ➖ |
| `-[NSMutableArray(OOInserter) oo_addUnsignedInteger:]` (889) | callers store `PList::unsignedInteger` oofnd/PList.hpp:186 | ➖ |
| `-[NSMutableArray(OOInserter) oo_addFloat:]` (894) | callers store `oo::PList(double)` oofnd/PList.hpp:169 (+numberWithDouble:) | ➖ |
| `-[NSMutableArray(OOInserter) oo_addBool:]` (899) | callers store `oo::PList(bool)` oofnd/PList.hpp:160 | ➖ |
| `-[NSMutableArray(OOInserter) oo_addVector:]` (905) | callers store `OOPListFromVector(v)` Core/OOPListGameTypes.cpp:127 | ➖ |
| `-[NSMutableArray(OOInserter) oo_addQuaternion:]` (910) | callers store `OOPListFromQuaternion(q)` Core/OOPListGameTypes.cpp:136 | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertInteger:atIndex:]` (916) | callers insert `PList::signedInteger` | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertUnsignedInteger:atIndex:]` (921) | callers insert `PList::unsignedInteger` | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertFloat:atIndex:]` (926) | callers insert `oo::PList(double)` | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertBool:atIndex:]` (931) | callers insert `oo::PList(bool)` | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertVector:atIndex:]` (937) | callers insert `OOPListFromVector(v)` | ➖ |
| `-[NSMutableArray(OOInserter) oo_insertQuaternion:atIndex:]` (942) | callers insert `OOPListFromQuaternion(q)` | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setInteger:forKey:]` (952) | callers assign `PList::signedInteger` / `PList(int64)` | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setUnsignedInteger:forKey:]` (957) | callers assign `PList::unsignedInteger` | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setLongLong:forKey:]` (962) | callers assign `PList::signedInteger` | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setUnsignedLongLong:forKey:]` (967) | callers assign `PList::unsignedInteger` | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setFloat:forKey:]` (972) | callers assign `oo::PList(double)` | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setBool:forKey:]` (977) | callers assign `oo::PList(bool)` | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setVector:forKey:]` (983) | callers assign `OOPListFromVector(v)` (single-precision reals) | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setHPVector:forKey:]` (988) | callers assign `OOPListFromHPVector(v)` Core/OOPListGameTypes.cpp:131 | ➖ |
| `-[NSMutableDictionary(OOInserter) oo_setQuaternion:forKey:]` (993) | callers assign `OOPListFromQuaternion(q)` | ➖ |
| `-[NSMutableSet(OOInserter) oo_addInteger:]` (1003) | no PList set kind; no NSMutableSet of numbers in the port | ➖ |
| `-[NSMutableSet(OOInserter) oo_addUnsignedInteger:]` (1008) | as above | ➖ |
| `-[NSMutableSet(OOInserter) oo_addFloat:]` (1013) | as above | ➖ |
| `-[NSMutableSet(OOInserter) oo_addBool:]` (1018) | as above | ➖ |
| `-[NSMutableSet(OOInserter) oo_addVector:]` (1024) | as above | ➖ |
| `-[NSMutableSet(OOInserter) oo_addQuaternion:]` (1029) | as above | ➖ |
| `OOLongLongFromObject` (1037) *(added: missed by the extractor)* | `plist_get::longLongFrom` oofnd/PListGet.hpp:333 (bool → 0/1, integer bits, real via cvttsd2si `realToSigned` :315, string via GSString `longLongValue` :156, else default) | ✅ |
| `OOUnsignedLongLongFromObject` (1053) *(added)* | `plist_get::unsignedLongLongFrom` :343 (a string reads through `-intValue`, reproduced) | ✅ |
| `IsSpaceOrTab` (1071) | inlined in `plist_get::isZeroString` :294 | ✅ |
| `IsZeroString` (1076) | `plist_get::isZeroString` :292 (the `' '`-for-`-` slip reproduced) | ✅ |
| `BooleanFromString` (1098) | `plist_get::boolFrom` string branch :359-370 | ✅ |
| `FuzzyBooleanProbabilityFromString` (1111) | `plist_get::fuzzyProbabilityFrom` :507-513 | ✅ |
| `OOBooleanFromObject` (1124) | `plist_get::boolFrom` :357 | ✅ |
| `OOFuzzyBooleanFromObject` (1143) | `OOFuzzyBooleanFromPList` Core/OOPListGameTypes.cpp:141 + `fuzzyProbabilityFrom` oofnd/PListGet.hpp:500 (`randf() < p`) | ✅ |
| `OOFloatFromObject` (1167) | `plist_get::realFrom<float>` :386 | ✅ |
| `OODoubleFromObject` (1185) | `plist_get::realFrom<double>` :386 | ✅ |
| `OONonNegativeFloatFromObject` (1203) | `plist_get::nonNegativeRealFrom<float>` :403 | ✅ |
| `OONonNegativeDoubleFromObject` (1219) | `plist_get::nonNegativeRealFrom<double>` :403 | ✅ |
| `OOVectorFromObject` (1236) | `OOVectorFromPList` Core/OOPListGameTypes.cpp:45 + `tupleFrom` oofnd/PListGet.hpp:444 (native vector, string scan, 3-array, x/y/z dict with 0 for missing) | ✅ |
| `OOHPVectorFromObject` (1266) | `OOHPVectorFromPList` Core/OOPListGameTypes.cpp:78 + `tupleFrom` | ✅ |
| `OOQuaternionFromObject` (1294) | `OOQuaternionFromPList` Core/OOPListGameTypes.cpp:102 + `tupleFrom` (w x y z) | ✅ |
| `OOPropertyListFromVector` (1325) | `OOPListFromVector` Core/OOPListGameTypes.cpp:127 + `tuplePList` oofnd/PListGet.hpp:482 (single reals) | ✅ |
| `OOPropertyListFromHPVector` (1334) | `OOPListFromHPVector` Core/OOPListGameTypes.cpp:131 (doubles) | ✅ |
| `OOPropertyListFromQuaternion` (1343) | `OOPListFromQuaternion` Core/OOPListGameTypes.cpp:136 | ✅ |
| `SetForObject` (1354) | none (no PList set kind) | ➖ |
| `StringForObject` (1364) | `PListGet<std::string>::from` oofnd/PListGet.hpp:612 + `numberStringValue` :517 | ✅ |
| `OOClampInteger` (OOCollectionExtractors.h:386) *(added: header inline)* | the clamp in `PListGet<integral>::from` oofnd/PListGet.hpp:563-570 (same `(min < v) ? ((v < max) ? v : max) : min`) | ✅ |
| `OOCharFromObject` / `OOUnsignedCharFromObject` / `OOShortFromObject` / `OOUnsignedShortFromObject` (h:417-418, `OO_DEFINE_CLAMP_PAIR`) *(added)* | `PListGet<integral>::from` narrow branch :561-570 (default passed through `longLongFrom` then clamped, as upstream) | ✅ |
| `OOIntFromObject` / `OOUnsignedIntFromObject` / `OOLongFromObject` / `OOUnsignedLongFromObject` (h:440,446; LLP64: clamped) *(added)* | `PListGet<integral>::from` narrow branch (sizeof(long) == 4 on Windows) | ✅ |
| `OOIntegerFromObject` / `OOUIntegerFromObject` (h:450-457, OOLITE_64_BIT) *(added)* | `PListGet<long long>` / `<unsigned long long>` :553-559 | ✅ |

**Differences:**

- ❌ **low** (still open) — **NSUserDefaults `oo_boolForKey:defaultValue:` at 11 sites is `Defaults::boolForKey`**, i.e. GNUstep's `-[NSString boolValue]` (first non-space/`0`/sign char is y/Y/t/T/1-9), not `OOBooleanFromObject`. `"on"` was YES and is NO; `".5"`/`"0.5"` was YES and is NO; an unrecognised word (`"maybe"`) was the default (YES for `ecoqos`, `logging-show-time`, `logging-show-class`, `procedurally-textured-planets`, `ecm-visual-fx`) and is NO; `" yes"` was the default and is YES. Values the game writes itself read the same; needs a hand-edited plist or `-key value` argument — upstream `Core/OOCollectionExtractors.m:715-718,1098-1108,1124-1140` (callers `Core/Universe.m:737-759`, `Core/OOLogging.m:654-657`, `Core/GameController.m:142`) ↔ port `oofnd/Defaults.hpp:101-111,495-500` (callers `Core/Universe.cpp:327-362`, `Core/OOLogging.cpp:230-242`, `Core/GameController.cpp:290-292`)
- ❌ **low** (still open) — **NSUserDefaults `oo_floatForKey:` / `oo_doubleForKey:` with a default are `Defaults::floatForKey` / `doubleForKey`.** An unparseable string such as `"abc"` gave the default (`OOFloatFromObject`'s IsZeroString test) and now gives 0: `fov-value` 57.2 → 0 then MIN_FOV; volume 0.5 → 0 (silent); `animation_timer_interval` MINIMUM_ANIMATION_TICK → 0 — upstream `Core/OOCollectionExtractors.m:727-735,1167-1201` (callers `Core/Universe.m:755`, `Core/OOALSound.m:53`, `Core/GameController.m:89`) ↔ port `oofnd/Defaults.hpp:509-517` (callers `Core/Universe.cpp:350-353`, `Core/OOALSound.cpp:66-68`, `Core/GameController.cpp:235-238`)
- ❌ **low** (still open) — **Two `-[NSString doubleValue]` ports that disagree.** `plist_get::scanDoubleAt` ports NSScanner (18 significant digits, exponent > 511 → no number), used by every `OO*FromObject` path, `oo::str` and the scanner; `defaults_detail::stringDoubleValue` uses `std::from_chars` (correctly rounded, unlimited digits, overflow → inf) and serves the Defaults getters above. At most one matches GNUstep 1.31.1 for long mantissas and huge exponents (e.g. `"9223372036854775807"`, `"1e600"`); `test_defaults.cpp` pins only bool and integer coercions — port `oofnd/PListGet.hpp:166-289` ↔ port `oofnd/Defaults.hpp:172-200`
- ❌ **low** (still open) — **`oo_intForKey:` (`detailLevel`) and `oo_integerForKey:` (`sky-color-correction`) use `Defaults::integerForKey`**, which has no 20-character `intBuf` limit (`"000000000000000000001"` reads 1, upstream 0), reinterprets positive overflow as -1 instead of saturating, and for `detailLevel` truncates the int64 to `unsigned` instead of clamping to INT range first. Ordinary values read the same — upstream `Core/OOCollectionExtractors.m:1037-1050` + h:440 (callers `Core/Universe.m:726`, `Core/OOSkyDrawable.m:510`) ↔ port `oofnd/Defaults.hpp:114-130,501-508` (callers `Core/Universe.cpp:310-315`, `Core/OOSkyDrawable.cpp:507-508`)
- ⚠️ **low** (still open) — The no-default `oo_stringForKey:` / `oo_stringAtIndex:` returned nil for a missing or non-string value; `get<std::string>(k)` returns `""`, as documented ("use get<PList> to test presence"). A converted caller that tested for nil sees an empty string — upstream `Core/OOCollectionExtractors.m:301,604` ↔ port `oofnd/PListGet.hpp:604-618`
- subtle (✅, still open) — `get`/`at` on a **null** PList return `Result{}` (0, NO, `""`, nullptr, zero Vector/Quaternion), not the fallback: the translation of messaging nil, including a zeroed (not identity) Quaternion — port `oofnd/PListGet.hpp:652,665`
- subtle (low, still open) — `get<T>` on a non-dict, or `at<T>` on a non-array, returns the fallback; upstream sent `oo_*ForKey:` to a non-dictionary and raised "unrecognized selector" — port `oofnd/PList.hpp:232-246`
- subtle (✅, still open) — LLP64 exact (ADR-0017): `long`/`unsigned long` are 32-bit and clamp, as `OO_DEFINE_CLAMP_PAIR(long…)` did — port `oofnd/PListGet.hpp:552-571`
- subtle (✅, still open) — the `IsZeroString` slip, the redundant `doubleValue != 0` in the fuzzy path, `fmax`'s NaN/-0 → +0 with the default left unclamped, and the unsigned-from-string via `-intValue` are reproduced and pinned by tests/unit/oofnd/test_plist_get.cpp — upstream `Core/OOCollectionExtractors.m:1091,1111-1120,1203-1233,1053-1068` ↔ port `oofnd/PListGet.hpp:292-296,500-514,403-420,350-355`
- subtle (✅, still open) — `tupleFrom` skips null array elements and dict values; the dict path uses 0 for missing components, as upstream — upstream `Core/OOCollectionExtractors.m:1236-1322` ↔ port `oofnd/PListGet.hpp:444-478`
- note (still open) — the `oo_addInteger:` / `oo_setInteger:forKey:` family stored `+numberWithLong:` (32-bit on Windows); port callers store `PList::signedInteger(int64)`, so a value over 2^31 is now kept whole. Not audited per caller — upstream `Core/OOCollectionExtractors.m:884-998`

## OODeepCopy

<a id="oodeepcopy"></a>
Upstream `src/Core/OODeepCopy.m` ↔ *(absorbed: `oo::PList` value copies at the former call sites)*

**Status:** done — 7 rows: 0 ✅ 0 ⚠️ 1 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OODeepCopy` (30) | PList copy at the former call sites: Core/OOShipRegistry.cpp:258,393,431 (`_shipData` / `_effectData`), Core/OOCacheManager.cpp:507 (`dictionaryOfCaches`), Scripting/OOLegacyScriptWhitelist.cpp:96,145 | ➖ |
| `-[NSObject(OODeepCopy) ooDeepCopyWithSharedObjects:]` (50) | PList copy (Object nodes share the `shared_ptr`, as `-retain` for non-NSCopying) | ➖ |
| `-[NSString(OODeepCopy) ooDeepCopyWithSharedObjects:]` (63) | `std::string` copy (no interning; not observable) | ➖ |
| `-[NSValue(OODeepCopy) ooDeepCopyWithSharedObjects:]` (85) | PList copy keeps each number's own kind (no uniquing) | ❌ |
| `-[NSArray(OODeepCopy) ooDeepCopyWithSharedObjects:]` (101) | `std::vector<PList>` copy | ➖ |
| `-[NSSet(OODeepCopy) ooDeepCopyWithSharedObjects:]` (152) | none (no PList set) | ➖ |
| `-[NSDictionary(OODeepCopy) ooDeepCopyWithSharedObjects:]` (205) | `std::map` copy | ➖ |

**Differences:**

- ❌ **low** (suspected, still open) — Upstream uniqued NSNumbers through `[objects member:self]` (`-hash`/`-isEqual:`); GNUstep's NSNumber compares by value across types, so within one deep copy a later `<true/>` could become an earlier integer `1`, or `1.0` become `1`, changing the kind JS later sees (boolean vs number) and the single/double flag. The PList copy keeps every node's kind. Only XML plists carry typed numbers, so shipdata/effectdata from XML OXPs is the exposure — upstream `Core/OODeepCopy.m:87-95` (callers `Core/OOShipRegistry.m:198,337,377`) ↔ port `Core/OOShipRegistry.cpp:258,393,431`

## OOEncodingConverter

<a id="ooencodingconverter"></a>
Upstream `src/Core/OOEncodingConverter.m` ↔ `Core/OOEncodingConverter.cpp` (242 / 213 lines)

**Status:** done — 10 rows: 8 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOEncodingConverter initWithEncoding:substitutions:]` (66) | `OOEncodingConverter(encoding, substitutions)` Core/OOEncodingConverter.cpp:70 (OOCache named "Text encoding", threshold `kCachePruneThreshold`; substitutions copied in key order) | ⚠️ |
| `-[OOEncodingConverter initWithFontPList:]` (87) | `OOEncodingConverter(fontPList)` + `FontSubstitutions` :62 Core/OOEncodingConverter.cpp:101 (`encoding` string, `substitutions` dict) | ✅ |
| `-[OOEncodingConverter dealloc]` (92) | `~OOEncodingConverter` Core/OOEncodingConverter.cpp:106 | ✅ |
| `-[OOEncodingConverter descriptionComponents]` (108) | `OOEncodingConverter::descriptionComponents` Core/OOEncodingConverter.cpp:118 ("encoding: N"; unknown → 4294967295, `%u` of NSNotFound) | ✅ |
| `-[OOEncodingConverter convertString:]` (113) | `OOEncodingConverter::convertString` Core/OOEncodingConverter.cpp:124 (cache lookup, convert, cache non-nil result) | ✅ |
| `-[OOEncodingConverter encoding]` (141) | `OOEncodingConverter::encoding` (nullopt = NSNotFound) Core/OOEncodingConverter.cpp:167 | ✅ |
| `-[OOEncodingConverter(Private) performConversionForString:]` (150) | `performConversionForString` Core/OOEncodingConverter.cpp:171 → `oo::str::convertForFont` oofnd/Encoding.hpp:1336 (each substitution with `replaceOccurrences`, then the lossy conversion) | ✅ |
| `-[OOEncodingConverter(Private) profileFire:]` (178) | `profileFire` (compiled out, `PROFILE_ENCODING_CONVERTER`) Core/OOEncodingConverter.cpp:186 | ⚠️ |
| `StringFromEncoding` (206) | `StringFromEncoding` Core/OOEncodingConverter.cpp:211 → `oo::str::encodingName` oofnd/Encoding.hpp:95 | ✅ |
| `EncodingFromString` (229) | `oo::str::encodingFromName` oofnd/Encoding.hpp:113 (same five names; unknown → nullopt for NSNotFound) | ✅ |

**Differences:**

- ⚠️ **low** (still open) — Substitutions are applied in key (byte) order instead of NSDictionary hash order; results differ only when one key occurs in another's key or replacement (not the case for the stock `oolite-font.plist`). A non-string replacement substitutes "" where upstream sent `-length` to a non-string. Documented in the constructor comment — upstream `Core/OOEncodingConverter.m:158-163` ↔ port `Core/OOEncodingConverter.cpp:77-88`
- ⚠️ **low** (still open) — PROFILE_ENCODING_CONVERTER's repeating NSTimer became a deadline checked on each conversion; compiled out — upstream `Core/OOEncodingConverter.m:78-81` ↔ port `Core/OOEncodingConverter.cpp:92-97,147-157`
- ✅ subtle (still open) — an unknown encoding gave a nil conversion that was returned and not cached; the port returns empty `oo::Data` and caches nothing (same zero-length HUD result) — upstream `Core/OOEncodingConverter.m:127-130,166` ↔ port `Core/OOEncodingConverter.cpp:130-136,173-174`
- ✅ subtle (still open) — encoding numeric values are kept (CP1251=11 … CP1250=15) and the cache's prune log class is still `dataCache.prune.Text encoding` — upstream `Core/OOEncodingConverter.m:70-72` ↔ port `oofnd/Encoding.hpp:86-91`, `Core/OOEncodingConverter.cpp:72-74`

## OOExcludeObjectEnumerator

<a id="ooexcludeobjectenumerator"></a>
Upstream `src/Core/OOExcludeObjectEnumerator.m` ↔ *(absorbed: its one caller, `ShipEntity::escorts`)*

**Status:** done — 5 rows: 0 ✅ 0 ⚠️ 0 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOExcludeObjectEnumerator initWithEnumerator:excludingObject:]` (30) | `ShipEntity::escorts()` Entities/ShipEntity.cpp:6832-6843: a snapshot of `_escortGroup->memberArray()` with `member == this` skipped | ➖ |
| `-[OOExcludeObjectEnumerator dealloc]` (41) | — | ➖ |
| `+[OOExcludeObjectEnumerator enumeratorWithEnumerator:excludingObject:]` (49) | (as above; upstream passed `self`, never nil) | ➖ |
| `-[OOExcludeObjectEnumerator nextObject]` (60) | the `continue` at Entities/ShipEntity.cpp:6839 | ➖ |
| `-[NSEnumerator(OOExcludingObject) ooExcludingObject:]` (74) | (as above; upstream `[[_escortGroup mutationSafeEnumerator] ooExcludingObject:self]`, ShipEntity.m:6039) | ➖ |

**Differences:**

- *none* (same order and exclusion; upstream's enumerator was also over a snapshot)

## OOFilteringEnumerator

<a id="oofilteringenumerator"></a>
Upstream `src/Core/OOFilteringEnumerator.m` ↔ *(absorbed: typed filter loops returning `std::vector<oo::EntityHold>` at each caller)*

**Status:** done — 19 rows: 0 ✅ 0 ⚠️ 0 ❌ 19 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOFilteringEnumerator filterEnumerator:withSelector:]` (36) | typed loops: `ShipEntity::shipSubEntities` Core/Entities/ShipEntity.cpp:1554 (`isShip`), `flasherEnumerator` :1562, `exhausts` :1571, `OOVisualEffectEntity::visualEffectSubEntityEnumerator`/`effectSubEntityEnumerator`/`flasherEnumerator` Core/Entities/OOVisualEffectEntity.cpp:388,405,409, dock filter Core/Entities/StationEntity.cpp:987, `system.planets` Core/Scripting/OOJSSystem.cpp:336-343 | ➖ |
| `+[OOFilteringEnumerator filterEnumerator:withSelector:andArgument:]` (48) | none (no upstream caller passed an argument) | ➖ |
| `-[OOFilteringEnumerator initWithUnderlyingEnumerator:withSelector:takingArgument:argumentValue:]` (60) | none | ➖ |
| `-[OOFilteringEnumerator dealloc]` (77) | none | ➖ |
| `-[OOFilteringEnumerator descriptionComponents]` (85) | none | ➖ |
| `-[OOFilteringEnumerator shortDescriptionComponents]` (95) | none | ➖ |
| `-[OOFilteringEnumerator nextObject]` (100) | the per-element test in each loop (`oo::EntityIsShip`, `dynamic_cast<OOFlasherEntity*>`, `->isDock()`, `OOJSEntityIsVisibleToScripts`) | ➖ |
| `-[NSEnumerator(OOFilteringEnumerator) filteredWithSelector:]` (141) | (as above) | ➖ |
| `-[NSEnumerator(OOFilteringEnumerator) filteredWithSelector:andArgument:]` (146) | none | ➖ |
| `-[NSArray(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:]` (155) | (as above; every upstream caller used the NSArray form) | ➖ |
| `-[NSArray(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:andArgument:]` (160) | none | ➖ |
| `-[NSSet(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:]` (169) | none (no caller) | ➖ |
| `-[NSSet(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:andArgument:]` (174) | none | ➖ |
| `-[NSDictionary(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:]` (183) | none | ➖ |
| `-[NSDictionary(OOFilteringEnumerator) objectEnumeratorFilteredWithSelector:andArgument:]` (188) | none | ➖ |
| `-[NSDictionary(OOFilteringEnumerator) keyEnumeratorFilteredWithSelector:]` (193) | none | ➖ |
| `-[NSDictionary(OOFilteringEnumerator) keyEnumeratorFilteredWithSelector:andArgument:]` (198) | none | ➖ |
| `-[NSEnumerator(OOMakeObjectsPerformSelector) makeObjectsPerformSelector:]` (207) | range-for at callers | ➖ |
| `-[NSEnumerator(OOMakeObjectsPerformSelector) makeObjectsPerformSelector:withObject:]` (217) | range-for at callers | ➖ |

**Differences:**

- subtle (still open) — upstream filtered lazily over the array's enumerator and sent the predicate selector (an object without it was skipped); the port returns a snapshot vector and uses a C++ type test (`dynamic_cast` for flasher/exhaust instead of `-isFlasher`/`-isExhaust`). Same results unless a subclass overrode those predicates — upstream `Core/OOFilteringEnumerator.m:100-136`, `Core/Entities/ShipEntity.m:1219-1232` ↔ port `Core/Entities/ShipEntity.cpp:1554-1577`

## OOFoundation

<a id="oofoundation"></a>
Upstream `src/Core/OOFoundation.m` ↔ `Core/OOFoundation.cpp` (92 / 30 lines)

**Status:** done — 6 rows: 0 ✅ 0 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSObject(OODescriptionComponents) descriptionComponents]` (35) | per-class `std::optional<std::string> descriptionComponents() const` (e.g. `Core/OOCache.h:106`, `Core/AI.h:90`, virtual in `Core/Entities/EntityVirtualMembers.h:132`); no root default; convention in `Core/OODescription.h:9-13` | ➖ |
| `-[NSObject(OODescriptionComponents) description]` (44) | no shared wrapper; "<Class 0x…>{…}" built per call site with `oo::str::pointerDescription` `oofnd/String.hpp:997`; plists via `oo::DescriptionOf` `Core/OODescription.h:63` | ➖ |
| `-[NSObject(OODescriptionComponents) shortDescription]` (59) | per-class (e.g. `ShipEntity::shortDescriptionComponents` `Core/Entities/ShipEntity.h:276`) | ➖ |
| `-[NSObject(OODescriptionComponents) shortDescriptionComponents]` (71) | per-class, no root default | ➖ |
| `-[NSEnumerator(OOForEachSupport) objectEnumerator]` (80) | none (no NSEnumerator; range-for) | ➖ |
| `OOConsumeReference` (88) | none (debug-only no-op for ObjC ownership annotations; `Core/OOFoundation.cpp` is now only an include) | ➖ |

**Differences:**

- ➖ **low** (still open) — no NSObject description category: upstream printed "<Class %p>{components}" or "<Class %p>" (no braces) when components was nil for every object; the port documents the rule (`Core/OODescription.h:9-13`) but has no shared helper, so each call site must reproduce the nil→no-braces rule and GNUstep's low-32-bit `%p` itself. Drift risk for `%@` log lines — upstream `Core/OOFoundation.m:44-69` ↔ port `Core/OODescription.h:9-13`, `oofnd/String.hpp:997-1003`

## OOIsNumberLiteral

<a id="ooisnumberliteral"></a>
Upstream `src/Core/OOIsNumberLiteral.m` ↔ `Core/OOIsNumberLiteral.cpp` (135 / 126 lines)

**Status:** done — 1 rows: 1 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOIsNumberLiteral` (40) | `OOIsNumberLiteral(const std::string&, bool)` `Core/OOIsNumberLiteral.cpp:44` | ✅ |

**Differences:**

- ✅ subtle (still holds) — scans UTF-8 bytes instead of UTF-16 units; every non-ASCII unit or byte (and an embedded NUL) hits `default:` → NO in both. The nil check is gone (reference argument); the copy-pasted "Sign … in unpermitted position" text on the `.` case and the compiled-out FAIL logging are kept — upstream `Core/OOIsNumberLiteral.m:27-38,52-53,108` ↔ port `Core/OOIsNumberLiteral.cpp:29-42,50-52,102`

## OOLogHeader

<a id="oologheader"></a>
Upstream `src/Core/OOLogHeader.m` ↔ `Core/OOLogHeader.cpp` (355 / 366 lines)

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOPrintLogHeader` (57) | `OOPrintLogHeader` `Core/OOLogHeader.cpp:59` | ✅ |
| `OOPlatformDescription` (183) | `OOPlatformDescription` (std::string) `Core/OOLogHeader.cpp:187` | ✅ |
| `AdditionalLogHeaderInfo` (202) | `AdditionalLogHeaderInfo` (macOS) `Core/OOLogHeader.cpp:210` | ✅ |
| `GetCPUDescription` (229) | `GetCPUDescription` (macOS) `Core/OOLogHeader.cpp:240` | ✅ |
| `GetSysCtlString` (309) | `GetSysCtlString` (macOS, nullopt for nil) `Core/OOLogHeader.cpp:321` | ✅ |
| *(added)* `GetSysCtlInt` (325) | `GetSysCtlInt` (macOS) `Core/OOLogHeader.cpp:336` | ✅ |
| `AdditionalLogHeaderInfo` (347) | `AdditionalLogHeaderInfo` (non-Mac) `Core/OOLogHeader.cpp:354` | ✅ |

**Differences:**

- ✅ subtle (still holds) — header text is literal for literal: "Opening log for Oolite %@ by %@ (<cpu><variant>) under %@ at %@.\n", the "<cpu> N processor(s) detected. System RAM: … MB (free: … MB)." line, "\nBuild options: %@.\n" ("none" when empty), the logcontrol note, logged once as `log.header` with "%@\n" — upstream `Core/OOLogHeader.m:163-180,353` ↔ port `Core/OOLogHeader.cpp:163-182,359-363`
- ✅ subtle — "new planets" is unconditional (upstream gated on NEW_PLANETS, always 1); the Cocoa-only "Debug plug-in support" and the SpiderMonkey-only MOZ_TRACE_JSCALLS "JavaScript profiling" branch are gone, neither reachable in an SDL/QuickJS build; nil Mac sysctl strings print "(null)" as `%@` did — upstream `Core/OOLogHeader.m:108-110,118-122,137-143,213,301` ↔ port `Core/OOLogHeader.cpp:109,116-118,132-134,217-219,315-317`
- ✅ subtle — date is `oo::date::description()` (NSDate `-description`) and the non-Windows OS string is `oo::process::operatingSystemVersionString()` — upstream `Core/OOLogHeader.m:153,169` ↔ port `Core/OOLogHeader.cpp:144-146,166`

## OOLogOutputHandler

<a id="oologoutputhandler"></a>
Upstream `src/Core/OOLogOutputHandler.m` ↔ `Core/OOLogOutputHandler.cpp` (649 / 342 lines)

**Status:** done — 24 rows: 11 ✅ 3 ⚠️ 3 ❌ 7 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOLogOutputHandlerInit` (111) | `OOLogOutputHandlerInit` `Core/OOLogOutputHandler.cpp:102` | ✅ |
| `OOLogOutputHandlerClose` (147) | `OOLogOutputHandlerClose` `Core/OOLogOutputHandler.cpp:132` | ✅ |
| `OOLogOutputHandlerStartLoggingToStdout` (170) | `OOLogOutputHandlerStartLoggingToStdout` `Core/OOLogOutputHandler.cpp:142` | ✅ |
| `OOLogOutputHandlerStopLoggingToStdout` (174) | `OOLogOutputHandlerStopLoggingToStdout` `Core/OOLogOutputHandler.cpp:143` | ✅ |
| `OOLogOutputHandlerPrint` (179) | `OOLogOutputHandlerPrintLine` (+ `oo::log::consoleBytes` `oofnd/LogFile.hpp:113`) `Core/OOLogOutputHandler.cpp:155` | ✅ |
| `OOLogHandlerGetLogPath` (203) | `OOLogHandlerGetLogPath` / `LogPath` `:336` `Core/OOLogOutputHandler.cpp:169` | ✅ |
| `OOLogOutputHandlerChangeLogFile` (208) | `OOLogOutputHandlerChangeLogFile` `Core/OOLogOutputHandler.cpp:171` | ❌ |
| `-[OOAsyncLogger init]` (223) | `StartLogger` (+ `oo::log::rotateToPrevious` `oofnd/LogFile.hpp:134`) `Core/OOLogOutputHandler.cpp:197` | ❌ |
| `-[OOAsyncLogger dealloc]` (260) | `FileWriter::~FileWriter` `oofnd/LogFile.hpp:153` | ✅ |
| `-[OOAsyncLogger startLogging]` (270) | `FileWriter::start` `oofnd/LogFile.hpp:157` | ✅ |
| `-[OOAsyncLogger endLogging]` (330) | `FileWriter::end` (`oofnd/LogFile.hpp:185`) + `Postamble` `Core/OOLogOutputHandler.cpp:121` | ✅ |
| `-[OOAsyncLogger changeFile]` (346) | folded into `OOLogOutputHandlerChangeLogFile` `Core/OOLogOutputHandler.cpp:174-186` | ✅ |
| `-[OOAsyncLogger asyncLogMessage:]` (353) | `AsyncLogMessage` (+ `FileWriter::write` `oofnd/LogFile.hpp:173`, `logFileBytes` `:82`) `Core/OOLogOutputHandler.cpp:227` | ⚠️ |
| `-[OOAsyncLogger flushLog]` (377) | `OOLogOutputHandlerFlushIfDue` (+ `FileWriter::flush` `oofnd/LogFile.hpp:181`) `Core/OOLogOutputHandler.cpp:145` | ⚠️ |
| `-[OOAsyncLogger loggerThread]` (383) | `FileWriter::run` `oofnd/LogFile.hpp:224` | ✅ |
| `LoadLogCStringFunctions` (463) | none (Mac/Cocoa-only, `OOLITE_MAC_OS_X` code removed in 352a4772f) | ➖ |
| `OONSLogCStringFunction` (481) | none (as above) | ➖ |
| `OONSLogPrintfHandler` (490) | none (no gnustep-base: no NSLog output to capture) | ➖ |
| `DirectoryExistCreatingIfNecessary` (499) | `DirectoryExistCreatingIfNecessary` `Core/OOLogOutputHandler.cpp:249` | ❌ |
| `ExcludeFromTimeMachine` (521) | none (Mac-only, removed in 352a4772f) | ➖ |
| `GetAppName` (533) | none (Mac-only, removed in 352a4772f) | ➖ |
| `OOLogHandlerGetLogBasePath` (552) | `LogBasePath` `:297` / `OOLogHandlerGetLogBasePath` (+ `AppendPathComponent` `:277`) `Core/OOLogOutputHandler.cpp:330` | ⚠️ |
| `InitCrashReporterInfo` (606) | none (Mac debug-only, removed in 352a4772f) | ➖ |
| `SetCrashReporterInfo` (619) | none (as above) | ➖ |

**Differences:**

- ⚠️ **low** (still open) — Latest.log flushing: the one-shot 2 s NSTimer became a steady-clock deadline that only fires when the frame loop calls `OOLogOutputHandlerFlushIfDue` (comment `:87-92`). The file is unbuffered (`_IONBF`, `oofnd/LogFile.hpp:161`), so a flush is only fsync/_commit; a first request off the main thread still disables flushing for good, as upstream — upstream `Core/OOLogOutputHandler.m:370-381` ↔ port `Core/OOLogOutputHandler.cpp:145-153,227-243`
- ❌ **low** (still open) — log-setup failures used `NSLog` (stderr with GNUstep's banner, or a `gnustep`-class line once the printf handler was installed); the port uses `OO_LOG("unclassified", …)` for "could not move or delete existing log", "could not open log", "expected … to be a folder", "could not create folder" — upstream `Core/OOLogOutputHandler.m:244,322,507,512` ↔ port `Core/OOLogOutputHandler.cpp:181,205,214,253,259`
- ❌ **low** (still open) — `ChangeLogFile` start failure: upstream logged "could not open log" only when creating the file failed, via NSLog; the port logs it as `unclassified` whenever `FileWriter::start` fails with a path — upstream `Core/OOLogOutputHandler.m:316-324,346-350` ↔ port `Core/OOLogOutputHandler.cpp:178-186`
- ⚠️ **med** (new; coordinator raised it from low: a macOS build writes logs to `./Logs` under the working directory) — the Mac-only log folder code is gone (commit 352a4772f: `OOLITE_MAC_OS_X` was always 0 in the port, "the gaps that exposes are listed in the migration repo's cross-platform note"). On macOS neither the Linux nor the Windows branch runs, so the folder is the relative "Logs" (cwd) instead of `~/Library/Logs/Oolite`, with no Time Machine exclusion. Replaces the previous `GetAppName` ❌, whose code no longer exists — upstream `Core/OOLogOutputHandler.m:562-594` ↔ port `Core/OOLogOutputHandler.cpp:306-320`
- ➖ **low** (still open) — GNUstep's own `NSLog` output (class `gnustep`) is no longer captured into Latest.log; there is no such output to capture — upstream `Core/OOLogOutputHandler.m:137-141,490-495` ↔ port (none)
- ✅ subtle (still holds) — file bytes match: line + "\n", "\n" → "\r\n" on Windows (not before a combining unit), lone-surrogate lines dropped, 1 GiB saturation notice and process-wide flag, postamble "\nClosing log at <date>.", rotation Latest.log → Previous.log. A write error stops further writes (upstream: the `@catch` ended the thread) — upstream `Core/OOLogOutputHandler.m:238-248,336-338,359-368,403-428` ↔ port `oofnd/LogFile.hpp:82-139,224-260`, `Core/OOLogOutputHandler.cpp:121-123`
- ✅ subtle (still holds) — `LogBasePath` retries after a failed mkdir (upstream kept an unretained string in its static); default paths `$OO_LOGSDIR`, `<home>/Logs`, `<home>/.Oolite/Logs` unchanged — upstream `Core/OOLogOutputHandler.m:552-597` ↔ port `Core/OOLogOutputHandler.cpp:297-326`

## OOLogging

<a id="oologging"></a>
Upstream `src/Core/OOLogging.m` ↔ `Core/OOLogging.cpp` (832 / 272 lines)

**Status:** done — 44 rows: 40 ✅ 2 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `CacheValue` (120) | `Logger::Value::on()/off()` `oofnd/Log.hpp:387-388` | ✅ |
| `Inited` (128) | `Logger::checkInitialized` `oofnd/Log.hpp:311` | ✅ |
| `OOLogWillDisplayMessagesInClass` (136) | `Logger::willDisplay` / `oo::log::willDisplay` `:481` `oofnd/Log.hpp:332` | ✅ |
| `OOLogSetDisplayMessagesInClass` (172) | `Logger::setDisplay` `oofnd/Log.hpp:318` | ✅ |
| `OOLogGetParentMessageClass` (194) | `oo::log::parentClass` `oofnd/Log.hpp:132` | ✅ |
| `OOLogIndentIf` (210) | `oo::log::indentIf` `oofnd/Log.hpp:497` | ✅ |
| `OOLogOutdentIf` (216) | `oo::log::outdentIf` `oofnd/Log.hpp:501` | ✅ |
| `GetIndentLevel` (238) | `oo::log::indentLevel` (thread_local `IndentState`) `oofnd/Log.hpp:206` | ✅ |
| `SetIndentLevel` (243) | `IndentState::level` writes in `indent`/`outdent`/`popIndent` `oofnd/Log.hpp:207-211,492` | ✅ |
| `OOLogPushIndent` (248) | `OOLogPushIndent` → `oo::log::pushIndent` `Core/OOLogging.cpp:86`, `oofnd/Log.hpp:212` | ✅ |
| `OOLogPopIndent` (264) | `OOLogPopIndent` → `oo::log::popIndent` `Core/OOLogging.cpp:88`, `oofnd/Log.hpp:485` | ✅ |
| `GetIndentLevel` (289) | (thread-dictionary variant) same `oofnd/Log.hpp:206` | ✅ |
| `SetIndentLevel` (295) | (thread-dictionary variant) same | ✅ |
| `OOLogPushIndent` (301) | (thread-dictionary variant) `oofnd/Log.hpp:212` | ✅ |
| `OOLogPopIndent` (323) | (thread-dictionary variant) `oofnd/Log.hpp:485` | ✅ |
| `OOLogIndent` (345) | `OOLogIndent` → `oo::log::indent` `Core/OOLogging.cpp:90`, `oofnd/Log.hpp:207` | ✅ |
| `OOLogOutdent` (354) | `OOLogOutdent` → `oo::log::outdent` `Core/OOLogging.cpp:92`, `oofnd/Log.hpp:208` | ✅ |
| `OOLogWithPrefix` (365) | `oo::log::messageWithPrefix` `oofnd/Log.hpp:517` | ✅ |
| `OOLogWithFunctionFileAndLine` (375) | `oo::log::message` `oofnd/Log.hpp:509` | ✅ |
| `OOLogWithFunctionFileAndLineAndArguments` (384) | `Logger::write` + `composeLine` `:172` + `timeStamp` `:152` `oofnd/Log.hpp:353` | ✅ |
| `OOLogGenericParameterErrorForFunction` (459) | `OOLogGenericParameterErrorForFunction` `Core/OOLogging.cpp:94` | ✅ |
| `OOLogGenericSubclassResponsibilityForFunction` (464) | `OOLogGenericSubclassResponsibilityForFunction` `Core/OOLogging.cpp:101` | ✅ |
| `OOLogShowFunction` (469) | `OOLogShowFunction` `Core/OOLogging.cpp:108` | ✅ |
| `OOLogSetShowFunction` (474) | `OOLogSetShowFunction` `Core/OOLogging.cpp:110` | ✅ |
| `OOLogShowFileAndLine` (484) | `OOLogShowFileAndLine` `Core/OOLogging.cpp:121` | ✅ |
| `OOLogSetShowFileAndLine` (489) | `OOLogSetShowFileAndLine` `Core/OOLogging.cpp:125` | ✅ |
| `OOLogShowTime` (499) | `OOLogShowTime` `Core/OOLogging.cpp:136` | ✅ |
| `OOLogSetShowTime` (504) | `OOLogSetShowTime` `Core/OOLogging.cpp:138` | ✅ |
| `OOLogShowMessageClass` (514) | `OOLogShowMessageClass` `Core/OOLogging.cpp:149` | ✅ |
| `OOLogSetShowMessageClass` (519) | `OOLogSetShowMessageClass` `Core/OOLogging.cpp:151` | ✅ |
| `OOLogSetShowMessageClassTemporary` (529) | `OOLogSetShowMessageClassTemporary` → `Logger::setShowClassTemporarily` `Core/OOLogging.cpp:162`, `oofnd/Log.hpp:247` | ✅ |
| `OOLoggingInit` (534) | `OOLoggingInit` (+ `LogSink` `:56`) `Core/OOLogging.cpp:166` | ✅ |
| `OOLoggingTerminate` (562) | `OOLoggingTerminate` `Core/OOLogging.cpp:181` | ✅ |
| `OOLoggingReloadSettings` (576) | `OOLoggingReloadSettings` `Core/OOLogging.cpp:193` | ✅ |
| `OOLogInsertMarker` (581) | `OOLogInsertMarker` → `Logger::insertMarker` `Core/OOLogging.cpp:195`, `oofnd/Log.hpp:364` | ✅ |
| `OOLogInternal_` (610) | `Logger::internal` `oofnd/Log.hpp:370` | ✅ |
| `LoadExplicitSettings` (650) | `LoadExplicitSettings` + `Logger::replaceSettings` (`oofnd/Log.hpp:260`) `Core/OOLogging.cpp:226` | ❌ |
| `LoadExplicitSettingsFromDictionary` (719) | `SettingsFromDictionary` (`Core/OOLogging.cpp:60`) + `Logger::replaceSettings` `oofnd/Log.hpp:260-293` | ⚠️ |
| `OOLogAbbreviatedFileName` (762) | `oo::log::abbreviatedFileName` (uncached) `oofnd/Log.hpp:140` | ✅ |
| `ResolveDisplaySetting` (783) | `Logger::resolve` `oofnd/Log.hpp:418` | ✅ |
| `ResolveMetaClassReference` (809) | `Logger::resolveMeta` `oofnd/Log.hpp:438` | ⚠️ |
| *(added)* `kOOLog*` message-class constants (595-604) | `kOOLog*` `Core/OOLogging.cpp:197-207` (the `cxx_` prefix dropped, 0d2f6072c) | ✅ |
| *(added)* `OOLOG_ERROR_PREFIX` / `OOLOG_WARNING_PREFIX` (`OOLogging.h:122-123`) | `kErrorPrefix` / `kWarningPrefix` `oofnd/Log.hpp:527-528` | ✅ |
| *(added)* `OOLog()` macro / `OOLOG_FUNCTION_NAME` (`OOLogging.h:39-47,84-89`) | `OO_LOG` (`__FUNCTION__`) `oofnd/Log.hpp:535-540` | ❌ |

**Differences:**

- ❌ **low** (still open) — `logging-show-function/-file-and-line/-time/-class` are read with `Defaults::boolForKey` (NSString `-boolValue`: leading Y/y/T/t or non-zero digit) when present, instead of `oo_boolForKey:defaultValue:` ("yes"/"true"/"on"/non-zero → YES, "no"/"false"/"off"/zero → NO, anything else → the default). A string "on" gives NO, and an unrecognised string gives NO instead of YES for time/class. Only hand-edited string values are affected — upstream `Core/OOLogging.m:653-657` ↔ port `Core/OOLogging.cpp:228-243`, `oofnd/Defaults.hpp:101-109,495-500`
- ❌ **low** (still open) — the function name in log lines is C++ `__FUNCTION__` (bare "prune") where ObjC's was "-[OOCache prune]"; visible only with `logging-show-function` on (default NO) — upstream `Core/OOLogging.h:41,87` ↔ port `oofnd/Log.hpp:177-186,538`
- ⚠️ **low** (still open) — a `$metaclass` cycle falls back to `_default` instead of recursing until the stack overflowed (upstream adds to `ioSeenMetaClasses` but never checks it); documented "the one deliberate difference" — upstream `Core/OOLogging.m:809-832` ↔ port `oofnd/Log.hpp:435-461`
- ⚠️ **low** (still open) — logcontrol dictionaries are walked in `oo::PList::Dict` key (byte) order instead of NSDictionary hash order (comment `Core/OOLogging.cpp:58-59`); only reorders the "Bad setting value" diagnostics, never the settings — upstream `Core/OOLogging.m:722-755` ↔ port `Core/OOLogging.cpp:60-80`, `oofnd/Log.hpp:268-293`
- ⚠️ **low** (still open) — the built-in logcontrol.plist pre-pass no longer logs `plist.wrongType` when that file's root is not a dictionary (comment `Core/OOLogging.cpp:259-263`) — upstream `Core/OOLogging.m:667-670` ↔ port `Core/OOLogging.cpp:252-266`
- ✅ subtle (still holds) — line layout unchanged: function/file:line → "[class] " or "[class]: " → "HH:MM:SS.mmm " (local, ms truncated) → 2 spaces per indent level capped at 64; internal diagnostics ("OOLogging internal - <fn>: …") and markers bypass prefixes and indentation; `_default` YES, `_override` sticky; show-* start all-false so the header has no prefixes — upstream `Core/OOLogging.m:83-89,404-448,591,623` ↔ port `oofnd/Log.hpp:83-88,172-201,364-372,467-469`
- ✅ subtle (still holds) — `Logger::write` does not re-test the class as upstream's `OOLogWithFunctionFileAndLineAndArguments` did under `!OOLOG_SHORT_CIRCUIT`; upstream defines it to 1 so its macros tested once too; `OO_LOG` tests at the call site — upstream `Core/OOLogging.h:62-63,84-89`, `Core/OOLogging.m:393-396` ↔ port `oofnd/Log.hpp:350-361,535-540`

## OOPListParsing

<a id="ooplistparsing"></a>
Upstream `src/Core/OOPListParsing.m` ↔ `Core/OOPListParsing.cpp` (233 / 75 lines)

**Status:** done — 9 rows: 3 ✅ 1 ⚠️ 0 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOPropertyListFromData` (48) | `OOPropertyListFromData` (+ `oo::parsePropertyList`, `oofnd/PListParsing.hpp:68`) `Core/OOPListParsing.cpp:32` | ⚠️ |
| `OOPropertyListFromFile` (83) | `OOPropertyListFromFile` `Core/OOPListParsing.cpp:63` | ✅ |
| `ChangeDTDIfApplicable` (103) | `oo::changeDTDIfApplicable` `oofnd/PListXML.hpp:73` | ✅ |
| `CopyDataFromFile` (173) | `OODataFromOXZFile` (`oofnd/FileSystem.hpp:443`) called at `Core/OOPListParsing.cpp:67` | ✅ |
| `OODictionaryFromData` (201) | none (callers test `isDict()` themselves) | ➖ |
| `OODictionaryFromFile` (207) | none (e.g. `Core/OOLogging.cpp:258-263`, `Core/Entities/PlayerEntityLoadSave.cpp:642`, `Core/AI.cpp:52-54`) | ➖ |
| `OOArrayFromData` (213) | none | ➖ |
| `OOArrayFromFile` (219) | none (e.g. `Core/OOOXZManager.cpp:65-67`) | ➖ |
| `ValueIfClass` (226) | none (`plist.wrongType` line dropped) | ➖ |

**Differences:**

- ⚠️ **low** (still open) — binary property lists (`bplist00`, GNUstep binary: first byte 0/1) always fail with "binary property lists are not supported by oofnd" (documented in the header, `oofnd/PListParsing.hpp:11`), logged as `plist.parse.failed`; for XML/old-style input the error text is oofnd's `PListError::description()`, so a golden that captures a parse failure depends on oofnd matching GNUstep's wording — upstream `Core/OOPListParsing.m:62-76` ↔ port `Core/OOPListParsing.cpp:41-57`, `oofnd/PListParsing.hpp:43-65`
- ➖ **low** (still open) — `plist.wrongType` ("Property list is wrong type - expected NSDictionary, got …") is no longer logged; every former `OODictionaryFromFile`/`OOArrayFromFile` caller silently treats a wrong-typed root as missing (comments at the call sites) — upstream `Core/OOPListParsing.m:226-232` ↔ port (none)
- ✅ subtle (still holds) — `plist.information` "Parsing %@ as a property list." only when `UNIVERSE` exists; "<data in memory>" default and "<no error message>" kept; a missing file is silent — upstream `Core/OOPListParsing.m:53-57,70-76,94` ↔ port `Core/OOPListParsing.cpp:36-39,51-56,72`

## OOPriorityQueue

<a id="oopriorityqueue"></a>
Upstream `src/Core/OOPriorityQueue.m` ↔ `Core/OOPriorityQueue.h` (640 / 167 lines; `OOPriorityQueueOf<T>` over `std::vector<std::shared_ptr<T>>`, header-only; sole user `Core/Scripting/OOScriptTimer.cpp`)

**Status:** done — 37 rows: 13 ✅ 1 ⚠️ 0 ❌ 23 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `PQLeftChild` (68) | `LeftChild` `Core/OOPriorityQueue.h:112` | ✅ |
| `PQRightChild` (73) | `RightChild` `:113` | ✅ |
| `PQParent` (78) | `Parent` `:114` | ✅ |
| `PQCompare` (85) | `_comparator(a, b)` function pointer (`CompareByNextFireTime`, `Core/Scripting/OOScriptTimer.cpp:38`) | ✅ |
| `+[OOPriorityQueue queueWithComparator:]` (127) | `new OOPriorityQueueOf<T>(cmp)` (`Core/Scripting/OOScriptTimer.cpp:149`) | ➖ |
| `-[OOPriorityQueue initWithComparator:]` (132) | ctor `:75` | ✅ |
| `-[OOPriorityQueue init]` (147) | none (upstream returned nil without a comparator) | ➖ |
| `-[OOPriorityQueue dealloc]` (152) | implicit dtor (vector of `std::shared_ptr`) | ➖ |
| `-[OOPriorityQueue description]` (160) | none | ➖ |
| `-[OOPriorityQueue debugDescription]` (166) | none | ➖ |
| `-[OOPriorityQueue isEqual:]` (184) | none (no caller) | ➖ |
| `-[OOPriorityQueue hash]` (215) | none | ➖ |
| `-[OOPriorityQueue copyWithZone:]` (222) | none | ➖ |
| `-[OOPriorityQueue addObject:]` (245) | `addObject` `:77` (`oo::share`, bubble up from the end) | ⚠️ |
| `-[OOPriorityQueue removeObject:]` (273) | none (comparator-equality removal had no caller) | ➖ |
| `-[OOPriorityQueue removeExactObject:]` (292) | `removeExactObject` `:84` (scan continues from i+1 past a match, as upstream) | ✅ |
| `-[OOPriorityQueue count]` (306) | `count` `:93` | ✅ |
| `-[OOPriorityQueue nextObject]` (311) | `removeNextObject` `:101` returns the element | ➖ |
| `-[OOPriorityQueue peekAtNextObject]` (318) | `peekAtNextObject` `:95` | ✅ |
| `-[OOPriorityQueue removeNextObject]` (326) | `removeNextObject` `:101` | ✅ |
| `-[OOPriorityQueue addObjects:]` (331) | loop of `addObject` over `sDeferredTimers` in order (`Core/Scripting/OOScriptTimer.cpp:197-203`) | ➖ |
| `-[OOPriorityQueue sortedObjects]` (344) | `sortedObjects` `:104` (drains the queue, as upstream's enumerator did) | ✅ |
| `-[OOPriorityQueue objectEnumerator]` (349) | none | ➖ |
| `-[OOPriorityQueue(Private) makeObjectsPerformSelector:]` (358) | none | ➖ |
| `-[OOPriorityQueue(Private) bubbleUpFrom:]` (370) | `bubbleUpFrom` `:116` | ✅ |
| `-[OOPriorityQueue(Private) bubbleDownFrom:]` (389) | `bubbleDownFrom` `:127` (same child choice `li == end or cmp(li,ri) < 0`; compares `_heap[i]`, which holds upstream's fixed `obj`) | ✅ |
| `-[OOPriorityQueue(Private) growBuffer]` (417) | `std::vector` growth | ➖ |
| `-[OOPriorityQueue(Private) shrinkBuffer]` (446) | `std::vector` (never shrinks) | ➖ |
| `-[OOPriorityQueue(Private) removeObjectAtIndex:]` (466) | `removeObjectAtIndex` `:149` (last element moved in, bubble down only) | ✅ |
| `-[OOPriorityQueue(Private) appendDebugDataToString:index:depth:]` (490) | none (OO_DEBUG only) | ➖ |
| `-[OOPriorityQueueEnumerator initWithPriorityQueue:]` (512) | none | ➖ |
| `-[OOPriorityQueueEnumerator dealloc]` (526) | none | ➖ |
| `-[OOPriorityQueueEnumerator nextObject]` (533) | (folded into `sortedObjects`) | ➖ |
| `EscapedString` (549) | none (DebugGraphViz) | ➖ |
| `-[OOPriorityQueue(DebugGraphViz) generateGraphViz]` (581) | none | ➖ |
| `-[OOPriorityQueue(DebugGraphViz) writeGraphVizToURL:]` (621) | none | ➖ |
| `-[OOPriorityQueue(DebugGraphViz) writeGraphVizToPath:]` (634) | none | ➖ |

**Differences:**

- ⚠️ **low** (still open) — `addObject(nullptr)` is ignored, as the comment at `:77` says; upstream raised NSInvalidArgumentException for nil and for an object without the comparator — upstream `Core/OOPriorityQueue.m:251-260` ↔ port `Core/OOPriorityQueue.h:77-82`
- subtle (new) — `addObject` now takes ownership with `oo::share(object)` (`shared_from_this`), which throws `std::bad_weak_ptr` for an object no `shared_ptr` owns; every timer is made through `std::shared_ptr<OOScriptTimer>(…, oo::Dispose{})`, so no current path reaches it — port `Core/OOPriorityQueue.h:80`, `oofnd/Object.hpp:55-61`, `Core/Scripting/OOScriptTimer.cpp:52-58`
- subtle (still holds) — a removed element was `-autorelease`d; now `removeExactObject` drops the `shared_ptr` at once, so the element can be destroyed inside the loop. A queued timer is held by the queue, so its own destructor never finds itself queued (comment `OOScriptTimer.cpp:161-163`) — upstream `Core/OOPriorityQueue.m:484` ↔ port `Core/OOPriorityQueue.h:84-91,149-163`

## OOProfilingStopwatch

<a id="ooprofilingstopwatch"></a>
Upstream `src/Core/OOProfilingStopwatch.m` ↔ `Core/OOProfilingStopwatch.cpp` (129 / 117 lines)

**Status:** done — 8 rows: 7 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOProfilingStopwatch init]` (35) | `OOProfilingStopwatch()` `Core/OOProfilingStopwatch.cpp:33` | ✅ |
| `+[OOProfilingStopwatch stopwatch]` (45) | `OOProfilingStopwatch::stopwatch` (`oo::makeShared`) `Core/OOProfilingStopwatch.cpp:39` | ✅ |
| `-[OOProfilingStopwatch dealloc]` (50) | `~OOProfilingStopwatch` `Core/OOProfilingStopwatch.cpp:43` | ✅ |
| `-[OOProfilingStopwatch start]` (58) | `OOProfilingStopwatch::start` `Core/OOProfilingStopwatch.cpp:48` | ✅ |
| `-[OOProfilingStopwatch stop]` (66) | `OOProfilingStopwatch::stop` `Core/OOProfilingStopwatch.cpp:55` | ✅ |
| `-[OOProfilingStopwatch currentTime]` (74) | `OOProfilingStopwatch::currentTime` `Core/OOProfilingStopwatch.cpp:62` | ✅ |
| `-[OOProfilingStopwatch reset]` (84) | `OOProfilingStopwatch::reset` `Core/OOProfilingStopwatch.cpp:71` | ✅ |
| `OOHighResTimeDeltaInSeconds` (102) | `OOHighResTimeDeltaInSeconds` `Core/OOProfilingStopwatch.cpp:86` | ⚠️ |

**Differences:**

- ⚠️ **low** (new; replaces the previous steady-clock bullet) — on Windows the non-standalone build used SpiderMonkey's `JS_Now()` (µs); the port now always uses `timeGetTime` (ms), as upstream's standalone build did. The JS_Now path was removed by the merged upstream commit c66ff5259 ("Remove the SpiderMonkey code paths (#580)"; it carried a "TODO (port): QuickJS has no JS_Now()" note). JS profiler totals and time-limiter overhead (`Core/Scripting/OOJSEngineTimeManagement.cpp:98-226`) and cache/mesh timings on Windows get 1 ms resolution — upstream `Core/OOProfilingStopwatch.h:62-87,113-123` ↔ port `Core/OOProfilingStopwatch.h:58-92`
- ⚠️ **low** (new) — the Windows delta casts the DWORD difference to `int32_t` (comment: a reversed pair gives a negative delta); upstream converted the unsigned difference, so a reversed pair gave about +4.29e6 s and an interval over 24.8 days now goes negative. Normal forward intervals, including across a rollover, are unchanged — upstream `Core/OOProfilingStopwatch.m:118-119` ↔ port `Core/OOProfilingStopwatch.cpp:104-107`
- ✅ subtle (still holds) — `stop` still disposes `_start` rather than `_end` (upstream quirk; values are plain integers). the port's macOS build takes the gettimeofday path (upstream's mach_absolute_time path was under `OOLITE_MAC_OS_X`, the Cocoa build; the port keeps its body in the .cpp but never selects it) — upstream `Core/OOProfilingStopwatch.m:66-72` ↔ port `Core/OOProfilingStopwatch.cpp:55-60`

## OORegExpMatcher

<a id="ooregexpmatcher"></a>
Upstream `src/Core/OORegExpMatcher.m` ↔ `Core/OORegExpMatcher.cpp` (140 / 156 lines)

**Status:** done — 6 rows: 4 ✅ 1 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OORegExpMatcher regExpMatcher]` (37) | `OORegExpMatcher::regExpMatcher` `Core/OORegExpMatcher.cpp:42` | ✅ |
| `-[OORegExpMatcher init]` (48) | `OORegExpMatcher::init` `Core/OORegExpMatcher.cpp:58` | ✅ |
| `-[OORegExpMatcher dealloc]` (76) | `~OORegExpMatcher` `Core/OORegExpMatcher.cpp:77` | ✅ |
| `-[OORegExpMatcher string:matchesExpression:]` (88) | `OORegExpMatcher::string(string, regExp)` `Core/OORegExpMatcher.cpp:84` | ✅ |
| `-[OORegExpMatcher string:matchesExpression:flags:]` (93) | `OORegExpMatcher::string(string, regExp, flags)` `Core/OORegExpMatcher.cpp:89` | ⚠️ |
| `-[NSString(OORegExpMatcher) oo_matchesRegularExpression:]` (135) | none (callers call `regExpMatcher()->string(...)`, `MatchesRegExp` `Core/OOOpenGLExtensionManager.cpp:829`, nil string → NO as before) | ➖ |

**Differences:**

- ⚠️ **low** (new) — the RegExp is built by calling the global `RegExp` constructor with a flag string ("i" for `kCaseInsensitive` 0x01, "m" for `kMultiLine` 0x04) instead of `JS_NewUCRegExpObjectNoStatics(…, flags)` (comment `:105-106`, QuickJS has no direct API). Pattern syntax and error text are QuickJS's; an invalid pattern is reported at construction and the cached object becomes null, so `regexp.test` then throws and the match is NO, as upstream's NULL object did. A script that replaced `RegExp` on the global would now be picked up. The malloc path upstream (which skipped `OOJSRelinquishContext`) is gone — upstream `Core/OORegExpMatcher.m:97-123` ↔ port `Core/OORegExpMatcher.cpp:94-129`
- ✅ subtle (still holds) — lifetime: the autoreleased pseudo-singleton becomes a `shared_ptr` whose last holder ends it; the only caller holds one matcher per pass (comment `Core/OOOpenGLExtensionManager.cpp:825-828`), so one tester is compiled per pass; a failed init answers null and `MatchesRegExp` answers NO — upstream `Core/OORegExpMatcher.m:37-46` ↔ port `Core/OORegExpMatcher.cpp:42-56`
- ✅ subtle (still holds) — cached per (pattern, flags); empty pattern (0 UTF-16 units) → NO before any JS; result through `JS_ToBool` as `-evaluatePredicateWithContext:` did; the tester's file name is now "OORegExpMatcher.cpp" with its own `__LINE__` (visible only in a JS error report) — upstream `Core/OORegExpMatcher.m:52-64,97-131` ↔ port `Core/OORegExpMatcher.cpp:59-68,94-101,134-151`

## OOWeakReference

<a id="ooweakreference"></a>
Upstream `src/Core/OOWeakReference.m` ↔ `std::weak_ptr<T>` over `oo::Object` (`oofnd/Object.hpp`; `oofnd/Ref.hpp` was deleted in c3d79d42f), plus the plist carrier `oo::EntityWeakPListForeign` (`Core/Entities/Entity.h:466`)

**Status:** done — 20 rows: 6 ✅ 2 ⚠️ 2 ❌ 10 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOWeakReference weakRefWithObject:]` (24) | `std::weak_ptr<T>(oo::share(obj))` at callers (`oo::share` `oofnd/Object.hpp:55`, null → empty), e.g. `Core/Entities/Entity.h:468-469`, `Core/Entities/PlayerEntity.cpp:12917-12918` | ✅ |
| `-[OOWeakReference dealloc]` (35) | `~weak_ptr` (control-block weak count replaces `-weakRefDied:`) | ✅ |
| `-[OOWeakReference description]` (42) | `EntityWeakPListForeign::description` `Core/Entities/Entity.cpp:534` | ❌ |
| `-[OOWeakReference weakRefUnderlyingObject]` (50) | `weak_ptr::lock().get()` (null once expired), e.g. `Core/Entities/Entity.h:470`, `oo::LiveEntity` `Core/Entities/EntityHelpers.h:75` | ✅ |
| `-[OOWeakReference weakRetain]` (55) | `weak_ptr` copy | ✅ |
| `-[OOWeakReference weakRefDrop]` (60) | automatic expiry when the last `shared_ptr` goes, before `oo::Dispose` runs `willDispose()` and `delete` (`oofnd/Object.hpp:31-45`) | ⚠️ |
| `-[OOWeakReference class]` (67) | `EntityWeakPListForeign::className` (always "OOWeakReference") `Core/Entities/Entity.h:471` | ❌ |
| `-[OOWeakReference isProxy]` (72) | none (no proxy) | ➖ |
| `-[OOWeakReference forwardInvocation:]` (77) | none: nil-safe forwarding becomes `if (auto t = w.lock())` at callers | ➖ |
| `-[OOWeakReference methodSignatureForSelector:]` (83) | none | ➖ |
| `-[OOWeakReference respondsToSelector:]` (102) | none | ➖ |
| `-[OOWeakReference forwardingTargetForSelector:]` (115) | none | ➖ |
| `-[NSObject(OOWeakReference) weakRefUnderlyingObject]` (124) | none (callers hold typed pointers) | ➖ |
| `-[OOWeakRefObject weakRetain]` (133) | `weak_from_this()` / `std::weak_ptr` from `oo::share(this)` (enable_shared_from_this base `oofnd/Object.hpp:18`) | ✅ |
| `-[OOWeakRefObject weakRefDied:]` (140) | control-block weak count (no per-object proxy to forget) | ✅ |
| `-[OOWeakRefObject dealloc]` (146) | `oo::Dispose::operator()` `oofnd/Object.hpp:41-44` (`willDispose`, then `delete`, weak refs already empty) | ⚠️ |
| `-[OOWeakRefObject weakSelf]` (152) | `std::weak_ptr<T>(oo::share(this))` at callers (e.g. `Core/Entities/PlayerEntity.cpp:12917`) | ➖ |
| `+[OOWeakReferenceTemplates weakRefDrop]` (162) | none | ➖ |
| `+[OOWeakReferenceTemplates weakRefUnderlyingObject]` (165) | none | ➖ |
| `+[OOWeakReferenceTemplates nilMethod]` (169) | none | ➖ |

**Differences:**

- ⚠️ **low** (still open, widened) — weak references are empty before any teardown code runs. Upstream's `-weakRefDrop` ran in `OOWeakRefObject -dealloc`, after every subclass `-dealloc` body, so weak refs still reached the object during those bodies. The previous audit noted that `willDispose` ran with weak refs live; with `std::shared_ptr` they now expire before the deleter, so `willDispose` and the destructor both see them empty (documented `oofnd/Object.hpp:31-33`). Teardown code that found itself through a weak ref (a group or owner lookup) now gets null — upstream `Core/OOWeakReference.m:146-150` ↔ port `oofnd/Object.hpp:31-45`
- ❌ **low** (new) — the dead description: upstream's `-description` formatted `[self class]`, which the proxy forwards to its now-nil object, giving "<Dead (null) 0x…>"; the port prints "<Dead OOWeakReference 0x…>". `className()` is always "OOWeakReference", where `[proxy class]` answered the live entity's class (e.g. in the old-style writer's "Class %@ does not support OldSchoolPropertyListWriting" text) — upstream `Core/OOWeakReference.m:42-48,67-70` ↔ port `Core/Entities/Entity.h:471-473`, `Core/Entities/Entity.cpp:534-540`, `oofnd/PListWriting.hpp:161`
- subtle (still open) — the proxy turned any message into a no-op returning 0/nil once dead; callers now `lock()` and must test for null, and a missed test is a null deref. Some sites return `lock().get()` raw (`Core/Entities/Entity.h:470`), safe only while another owner exists. A per-caller property — upstream `Core/OOWeakReference.m:77-81` ↔ port `Core/Entities/Entity.h:470`, `Core/Entities/EntityHelpers.h:75`

## OOWeakSet

<a id="ooweakset"></a>
Upstream `src/Core/OOWeakSet.m` ↔ `oofnd/WeakSet.hpp` (`oo::WeakSet<T>`: `std::vector<std::weak_ptr<T>>` in insertion order + an `owner_less` index)

**Status:** done — 24 rows: 15 ✅ 4 ⚠️ 0 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOWeakSet init]` (31) | `WeakSet()` `oofnd/WeakSet.hpp:57` | ✅ |
| `-[OOWeakSet initWithCapacity:]` (36) | `WeakSet(capacityHint)` `:58` | ✅ |
| `+[OOWeakSet set]` (48) | `WeakSet()` | ✅ |
| `+[OOWeakSet setWithCapacity:]` (53) | `WeakSet(capacityHint)` | ✅ |
| `-[OOWeakSet dealloc]` (58) | `~WeakSet` `:70` | ✅ |
| `-[OOWeakSet description]` (65) | none | ➖ |
| `-[OOWeakSet copyWithZone:]` (92) | copy ctor `:60` → `addLiveFrom` `:161` (live members only, as compact + add) | ✅ |
| `-[OOWeakSet mutableCopyWithZone:]` (100) | copy ctor / `operator=` `:62` | ✅ |
| `-[OOWeakSet isEqual:]` (105) | `operator==` `:132` (count, then membership) | ✅ |
| `-[OOWeakSet count]` (129) | `count` `:72` (compacts first) | ✅ |
| `-[OOWeakSet containsObject:]` (135) | `contains` `:79` (identity via `weak_from_this`; null → false) | ✅ |
| `-[OOWeakSet objectEnumerator]` (144) | `allObjects` `:115` / `forEach` `:128` | ⚠️ |
| `-[OOWeakSet addObject:]` (149) | `add` `:86` (null ignored, identity-uniqued) | ✅ |
| `-[OOWeakSet removeObject:]` (160) | `remove` `:95` | ✅ |
| `-[OOWeakSet addObjectsByEnumerating:]` (167) | `addAll` `:105` | ✅ |
| `-[OOWeakSet makeObjectsPerformSelector:]` (176) | `forEach` `:128` | ⚠️ |
| `-[OOWeakSet makeObjectsPerformSelector:withObject:]` (184) | `forEach` `:128` | ⚠️ |
| `-[OOWeakSet allObjects]` (192) | `allObjects` `:115` (live, owned) | ⚠️ |
| `-[OOWeakSet removeAllObjects]` (209) | `removeAll` `:109` | ✅ |
| `-[OOWeakSet compact]` (214) | `compact` `:152` | ✅ |
| `-[OOWeakRefUnpackingEnumerator initWithEnumerator:]` (242) | none (snapshot vector) | ➖ |
| `+[OOWeakRefUnpackingEnumerator enumeratorWithCollection:]` (256) | none | ➖ |
| `-[OOWeakRefUnpackingEnumerator dealloc]` (261) | none | ➖ |
| `-[OOWeakRefUnpackingEnumerator nextObject]` (268) | the live-member filter in `allObjects` `:118-121` | ➖ |

**Differences:**

- ⚠️ **low** (still open) — members are visited in insertion order; upstream used NSMutableSet order (pointer hashes, varying between runs). The banner calls this "One deliberate strengthening" — upstream `Core/OOWeakSet.m:176-206` ↔ port `oofnd/WeakSet.hpp:28-31,115-130`
- ⚠️ **low** (still open) — `forEach` iterates an owned snapshot, so a callback may mutate the set, and members stay alive for the whole loop; upstream's `foreach` over `_objects` raised on mutation and messaged dead members as nil. Documented in the banner — upstream `Core/OOWeakSet.m:176-190` ↔ port `oofnd/WeakSet.hpp:33-36,128-130`
- subtle (new) — `add` takes identity through `oo::share` (`shared_from_this`), which throws `std::bad_weak_ptr` for an object no `shared_ptr` owns (upstream accepted any `OOWeakReferenceSupport` object); `contains`/`remove` use `weak_from_this` and answer false/no-op for such an object instead — port `oofnd/WeakSet.hpp:89,145-147`, `oofnd/Object.hpp:55-61`

## OOXMLExtensions

<a id="ooxmlextensions"></a>
Upstream `src/Core/OOXMLExtensions.m` ↔ `Core/OOXMLExtensions.cpp` (55 / 50 lines)

**Status:** done — 1 rows: 0 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSDictionary(OOXMLExtensions) writeOOXMLToFile:atomically:errorDescription:]` (29) | `OOWriteXMLPListToFile` (+ `oo::writeXMLPList` `oofnd/PListWriting.hpp:532`) `Core/OOXMLExtensions.cpp:30` | ❌ |

**Differences:**

- ❌ **low** (still open) — serialisation-failure text: upstream passed `outErrorDesc` to the serializer but formatted its never-set local `errorDesc`, so the message was always "could not convert property list to XML: (null)"; the port appends oofnd's real error description. Visible only when a save game fails to serialise — upstream `Core/OOXMLExtensions.m:31-38` ↔ port `Core/OOXMLExtensions.cpp:32-38`
- ✅ subtle (still holds) — `atomically:` is ignored in both (always atomic, `WriteMode::kAtomic`); the "could not write data to %@." text is kept; the XML bytes come from `oo::writeXMLPList`, which claims GNUstep's XML writer byte for byte — this is the save-game writer — upstream `Core/OOXMLExtensions.m:43-48` ↔ port `Core/OOXMLExtensions.cpp:41-47`

## OldSchoolPropertyListWriting

<a id="oldschoolpropertylistwriting"></a>
Upstream `src/Core/OldSchoolPropertyListWriting.m` ↔ `oofnd/PListWriting.hpp` (`plist_detail::OldStyleWriter` :124, `oo::writeOldStylePList` :523)

**Status:** done — 8 rows: 5 ✅ 3 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSString(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (30) | `OldStyleWriter::formatString` `oofnd/PListWriting.hpp:180` (the bug that drops the text between two escaped characters is reproduced) | ⚠️ |
| `-[NSNumber(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (89) | `format` Bool/Integer/Real cases `:134-146` (true/false, signed/unsigned decimal, `%.8g` as `{:.8g}`) | ✅ |
| `-[NSData(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (121) | `formatData` `:244` | ⚠️ |
| `-[NSArray(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (169) | `formatArray` `:262` (same "non-plist object in dictionary" text) | ✅ |
| `-[NSDictionary(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (211) | `formatDict` `:298` + `caseInsensitiveLess` `:284` | ⚠️ |
| `-[NSObject(OldSchoolPropertyListWriting) oldSchoolPListFormatWithErrorDescription:]` (278) | `oo::writeOldStylePList` `:523` (appends "\n") | ✅ |
| `-[NSObject(OldSchoolPropertyListWriting) oldSchoolPListFormatWithIndentation:errorDescription:]` (286) | `format` Date/Object cases `:154-163` ("Class X does not support OldSchoolPropertyListWriting") | ✅ |
| `AppendNewLineAndIndent` (296) | `newLineAndIndent` `:173` | ✅ |

**Differences:**

- ⚠️ **low** (still open) — a non-ASCII alphanumeric string such as `Zürich`, which GNUstep's Unicode `alphanumericCharacterSet` left bare, is always quoted (comment `:190-192`; the ADR citation was dropped from comments in c3d79d42f). Saved games and caches written by the port quote such strings; both parse back the same — upstream `Core/OldSchoolPropertyListWriting.m:40-42` ↔ port `oofnd/PListWriting.hpp:190-198`
- ⚠️ **low** (still open) — upstream's NSData writer under-sized its buffer for 5-7 and 9+ bytes and looped forever at indentation 0 past 32 bytes (`while (--j)` with j=0); the port writes the intended form (comment `:240-243`) — upstream `Core/OldSchoolPropertyListWriting.m:132,149-151` ↔ port `oofnd/PListWriting.hpp:244-260`
- ⚠️ **low** (still open) — key order: keys equal but for case keep NSDictionary hash order upstream and UTF-16 unit order in the port; the fold is ASCII-only, where GNUstep's `caseInsensitiveCompare:` folds Unicode, so non-ASCII keys differing only in case may sort differently — upstream `Core/OldSchoolPropertyListWriting.m:220` ↔ port `oofnd/PListWriting.hpp:282-304`
- ✅ subtle — "Class %@" for a foreign object is the port's `className()`; for an entity weak reference that is always "OOWeakReference" where upstream's proxy forwarded `-className` to the entity (see OOWeakReference) — upstream `Core/OldSchoolPropertyListWriting.m:286-291` ↔ port `oofnd/PListWriting.hpp:159-163`

## ReleaseLockProxy

<a id="releaselockproxy"></a>
Upstream `src/Core/ReleaseLockProxy.m` ↔ *(removed: a debugging proxy with no user in upstream or the port)*

**Status:** done — 17 rows: 0 ✅ 0 ⚠️ 0 ❌ 17 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[ReleaseLockProxy proxyWithObject:name:]` (32) | none (no caller upstream: only `ReleaseLockProxy.h/.m` name it) | ➖ |
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

- *none* (dead code upstream: a grep of upstream `src/` finds no use outside the file; nothing in the port names it)

## Comparison

<a id="comparison"></a>
Upstream `src/SDL/Comparison.m` ↔ *(absorbed: `==` on `std::string` / `std::optional<std::string>` at the call sites)*

**Status:** done — 6 rows: 0 ✅ 0 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[NSObject(OLComparison) isEqualTo:]` (50) | `==` on identifiers: `ShipEntity::removeExternalStore` Core/Entities/ShipEntity.cpp:3958-3965, EQ_MISSILE `:11618`, route `Core/Universe.cpp:3464`, naval energy unit `:9655`; nil on either side → false, as `object != nil` and messaging nil did | ➖ |
| `-[NSObject(OLComparison) isGreaterThan:]` (55) | none (no caller) | ➖ |
| `-[NSObject(OLComparison) isGreaterThanOrEqualTo:]` (60) | none | ➖ |
| `-[NSObject(OLComparison) isLessThan:]` (65) | none | ➖ |
| `-[NSObject(OLComparison) isLessThanOrEqualTo:]` (70) | none | ➖ |
| `-[NSObject(OLComparison) isNotEqualTo:]` (75) | none | ➖ |

**Differences:**

- subtle (still open) — `isEqualTo:` used `-compare:`, which in GNUstep (no `NSLiteralSearch`) can treat precomposed and decomposed forms of a character as equal; port `==` compares bytes. Only non-ASCII equipment identifiers or routes in different normal forms could differ — upstream `SDL/Comparison.m:50-53` ↔ port `Core/Entities/ShipEntity.cpp:3958-3965`

