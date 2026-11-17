# Parity findings: platform
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## OODebugMonitor

<a id="oodebugmonitor"></a>
Upstream `src/Core/Debug/OODebugMonitor.m` ↔ `Core/Debug/OODebugMonitor.cpp` (933 / 900 lines)

**Status:** done — 44 rows: 32 ✅ 4 ⚠️ 0 ❌ 8 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OODebugMonitor init]` (75) | `OODebugMonitor::init` `Core/Debug/OODebugMonitor.cpp:81` (same three observers, monitor set, console script) | ✅ |
| `-[OODebugMonitor dealloc]` (121) | — (never ran: singleton `-release` was a no-op; comment `:118-120`) | ➖ |
| `+[OODebugMonitor sharedDebugMonitor]` (139) | `OODebugMonitor::sharedDebugMonitor` `:122` (singleton recorded before `init`, as `allocWithZone:` did) | ✅ |
| `-[OODebugMonitor setDebugger:]` (149) | `OODebugMonitor::setDebugger` `:138` | ✅ |
| `-[OODebugMonitor performJSConsoleCommand:]` (181) | `OODebugMonitor::performJSConsoleCommand` `:176` (now frees the arg value, as upstream #780) | ✅ |
| `-[OODebugMonitor appendJSConsoleLine:colorKey:emphasisRange:]` (192) | `appendJSConsoleLine(string, colorKey, range)` `:188` | ✅ |
| `-[OODebugMonitor appendJSConsoleLine:colorKey:]` (211) | `appendJSConsoleLine(string, colorKey)` `:206` | ✅ |
| `-[OODebugMonitor clearJSConsole]` (219) | `clearJSConsole` `:211` | ✅ |
| `-[OODebugMonitor showJSConsole]` (231) | `showJSConsole` `:225` | ✅ |
| `-[OODebugMonitor configurationValueForKey:]` (243) | `configurationValueForKey` `:239` | ✅ |
| `-[OODebugMonitor configurationValueForKey:class:defaultValue:]` (248) | folded into `configurationValueForKey` `:239` (only the `Nil`/`nil` path; no other callers) | ➖ |
| `-[OODebugMonitor configurationIntValueForKey:defaultValue:]` (266) | `configurationIntValueForKey` `:253` (string/bool/int/real → `longLongValue`, else default) | ✅ |
| `-[OODebugMonitor setConfigurationValue:forKey:]` (282) | `setConfigurationValue` `:276` | ✅ |
| `-[OODebugMonitor configurationKeys]` (312) | `configurationKeys` `:314` | ✅ |
| `-[OODebugMonitor debuggerConnected]` (323) | `debuggerConnected` `:331` | ✅ |
| `-[OODebugMonitor writeMemStat:]` (328) | `writeMemStat` `:333` (takes a formatted line) | ✅ |
| `SizeString` (341) | `SizeString` `:340` (same thresholds, float rounding, `%.2f`) | ✅ |
| `-[OODebugMonitor dumpEntity:withState:parentVisible:]` (381) | `dumpEntity` `:381` | ⚠️ |
| `-[OODebugMonitor dumpMemoryStatistics]` (455) | `dumpMemoryStatistics` `:460` | ⚠️ |
| `-[OODebugMonitor dumpJSMemoryStatistics]` (566) | `dumpJSMemoryStatistics` `:578` | ⚠️ |
| `-[OODebugMonitor setTCPIgnoresDroppedPackets:]` (581) | `setTCPIgnoresDroppedPackets` `:599` | ✅ |
| `-[OODebugMonitor TCPIgnoresDroppedPackets]` (590) | `TCPIgnoresDroppedPackets` `:608` | ✅ |
| `-[OODebugMonitor setUsingPlugInController:]` (595) | `setUsingPlugInController` `:612` | ✅ |
| `-[OODebugMonitor usingPlugInController]` (600) | `usingPlugInController` `:616` | ✅ |
| `-[OODebugMonitor sourceCodeForFile:line:]` (605) | `sourceCodeForFile` `:618` | ✅ |
| `-[OODebugMonitor disconnectDebugger:message:]` (627) | `disconnectDebugger` `:638` | ✅ |
| `-[OODebugMonitor applicationWillTerminate]` (641) | `applicationWillTerminate()` `:653` (`#if OOLITE_SDL`, as upstream now) | ✅ |
| `-[OODebugMonitor applicationWillTerminate:]` (647) | `applicationWillTerminate(notification)` `:659` | ✅ |
| `-[OODebugMonitor(Private) setUpDebugConsoleScript]` (660) | `setUpDebugConsoleScript` `:669` | ✅ |
| `-[OODebugMonitor(Private) javaScriptEngineWillReset:]` (689) | `javaScriptEngineWillReset` `:708` (no `OOJSConsoleDestroy`; console classes are re-made per context, `OOJSConsole.cpp:368`) | ✅ |
| `-[OODebugMonitor(Private) disconnectDebuggerWithMessage:]` (697) | `disconnectDebuggerWithMessage` `:717` | ✅ |
| `-[OODebugMonitor(Private) mergedConfiguration]` (711) | `mergedConfiguration` `:732` | ✅ |
| `-[OODebugMonitor(Private) loadSourceFile:]` (724) | `loadSourceFile` `:745` | ✅ |
| `-[OODebugMonitor(Private) normalizeConfigDictionary:]` (743) | `normalizeConfigDictionary` `:759` | ✅ |
| `-[OODebugMonitor(Private) normalizeConfigValue:forKey:]` (762) | `normalizeConfigValue` `:774` | ✅ |
| `-[OODebugMonitor(Private) jsEngine:context:error:stackSkip:showingLocation:withMessage:]` (780) | `jsEngine(..., severity, filePath, line, ...)` `:800` | ⚠️ |
| `-[OODebugMonitor(Private) jsEngine:context:logMessage:ofClass:]` (859) | `jsEngine(..., message, messageClass)` `:868` | ✅ |
| `-[OODebugMonitor(Private) oo_jsValueInContext:]` (870) | `jsValueInContext` `:880` (owned value instead of GC root) | ✅ |
| `+[OODebugMonitor(Singleton) allocWithZone:]` (898) | — (singleton made by `sharedDebugMonitor` and leaked; comment `:897`) | ➖ |
| `-[OODebugMonitor(Singleton) copyWithZone:]` (907) | — (as above) | ➖ |
| `-[OODebugMonitor(Singleton) retain]` (912) | — (as above) | ➖ |
| `-[OODebugMonitor(Singleton) retainCount]` (917) | — (as above) | ➖ |
| `-[OODebugMonitor(Singleton) release]` (922) | — (as above) | ➖ |
| `-[OODebugMonitor(Singleton) autorelease]` (926) | — (as above) | ➖ |

**Differences:**

- ⚠️ **low** — JS heap line text changed: port logs `JavaScript heap: X (N objects, next collection at Y)` where upstream logged `JavaScript heap: X (limit Y, N collections to date)`; QuickJS has no heap limit or GC count (port comment). Previous audit recorded only differing numbers, so the text change is (new) — upstream `Core/Debug/OODebugMonitor.m:566-579` ↔ port `Core/Debug/OODebugMonitor.cpp:578-597`
- ⚠️ **low** — JS error reports: only `Warning`/`Exception` prefixes and `warning`/`exception` colour keys; upstream's non-exception `Error` (`error` key) and ` (strict mode)` suffix cannot occur under QuickJS (port comment). Location/source line appended only when the file path is non-empty, as before (still open in substance; previous audit marked ✅) — upstream `OODebugMonitor.m:799-844` ↔ port `OODebugMonitor.cpp:816-852`
- ⚠️ **low** — memory-stats sizes are C++ sizes (`oo::EntityObjectSize`, `sizeof *tex` of the `OOTexture` root) and ref counts are `use_count`; `debug.memStats` numbers differ (beads oo-dpyk8, oo-9ht.99 per previous audit) (still open) — upstream `OODebugMonitor.m:389,467,517` ↔ port `OODebugMonitor.cpp:388,472,526`
- ➖ **low** — `-dealloc` (disconnect, drop GC root) not translated; it never ran (comment) (still open) — upstream `OODebugMonitor.m:121-137` ↔ port `OODebugMonitor.cpp:118-120`
- ➖ **low** — `configurationValueForKey:class:defaultValue:` folded into the 1-arg form (override unless missing/null, else OXP value; `NSNull` → nil) (still open) — upstream `OODebugMonitor.m:248-264` ↔ port `OODebugMonitor.cpp:239-251`
- ✅ subtle — texture list order for textures not in the age cache follows `allTextures()` vector order instead of `NSSet` order; `configurationKeys` stable sort over byte-ordered keys; `setConfigurationValue` also rejects `""` keys — upstream `OODebugMonitor.m:284,320,503` ↔ port `OODebugMonitor.cpp:278,324,511`
- ✅ subtle — the planet atmosphere branch is the `NEW_PLANETS` FIXME no-op in both builds (port drops the old-planets branch) — upstream `OODebugMonitor.m:435-444` ↔ port `OODebugMonitor.cpp:440-442`

## OODebugStandards

<a id="oodebugstandards"></a>
Upstream `src/Core/Debug/OODebugStandards.m` ↔ `Core/Debug/OODebugStandards.cpp` (122 / 133 lines)

**Status:** done — 10 rows: 10 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOStandardsDeprecated` (37) | release stub `Core/Debug/OODebugStandards.cpp:39` | ✅ |
| `OOStandardsError` (38) | release stub `:40` | ✅ |
| `OOEnforceStandards` (39) (stub, missed by extractor) | release stub `:41` (returns false) | ✅ |
| `OOSetStandardsForOXPVerifierMode` (40) | release stub `:42` | ✅ |
| `OOStandardsSetup` (69) | `OOStandardsSetup` `:80` (`enforce-oxp-standards`, default OFF under NDEBUG else WARN, clamp [OFF, QUIT]) | ✅ |
| `OOStandardsInternal` (85) | `OOStandardsInternal` (anonymous namespace) `:99` | ✅ |
| `OOStandardsDeprecated` (100) | `OOStandardsDeprecated` `:115` (`oxp-standards.deprecated`) | ✅ |
| `OOStandardsError` (105) | `OOStandardsError` `:119` (`oxp-standards.error`) | ✅ |
| `OOEnforceStandards` (110) | `OOEnforceStandards` `:123` | ✅ |
| `OOSetStandardsForOXPVerifierMode` (116) | `OOSetStandardsForOXPVerifierMode` `:128` | ✅ |

**Differences:**

- ✅ subtle — the stubs/real split is now keyed on `OO_DEBUG_MONITOR_ENABLED` in both (upstream #756); neither sets `sSetup` in `OOStandardsSetup`, so the preference is re-read each call until verifier mode pins it — upstream `Core/Debug/OODebugStandards.m:35-82` ↔ port `Core/Debug/OODebugStandards.cpp:37-93`
- ✅ subtle — the enforcement value is read via `PListGet<int>` (same clamping as `oo_intForKey:defaultValue:`); a null/missing key takes the default — port `OODebugStandards.cpp:84-87`

## OODebugSupport

<a id="oodebugsupport"></a>
Upstream `src/Core/Debug/OODebugSupport.m` ↔ `Core/Debug/OODebugSupport.cpp` (135 / 90 lines)

**Status:** done — 2 rows: 1 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOInitDebugSupport` (52) | `OOInitDebugSupport` `Core/Debug/OODebugSupport.cpp:37` | ✅ |
| `LoadDebugPlugIn` (106) | — (only under `OOLITE_MAC_COCOA_UI`; elsewhere `#define LoadDebugPlugIn() nil`; port comment `:47-49`) | ➖ |

**Differences:**

- ➖ **low** — the plug-in-controller branch (`setUpDebugger`, `setUsingPlugInController:YES`) is gone; on the SDL builds it was dead because `LoadDebugPlugIn()` is `nil` (now gated on `OOLITE_MAC_COCOA_UI`, the removed Cocoa UI) (still open) — upstream `Core/Debug/OODebugSupport.m:38-42,71-78,104-130` ↔ port `Core/Debug/OODebugSupport.cpp:47-49`
- ✅ subtle — `console-host` keeps `oo_stringForKey` semantics (string or number's string, else nil); `console-port` / `always-load-debug-console` via `PList::get` clamping; TCP client null on failure as `initWithAddress:port:` → nil — upstream `OODebugSupport.m:73-90,94-96` ↔ port `OODebugSupport.cpp:51-71`

## OODebugTCPConsoleClient

<a id="oodebugtcpconsoleclient"></a>
Upstream `src/Core/Debug/OODebugTCPConsoleClient.m` ↔ `Core/Debug/OODebugTCPConsoleClient.cpp` (768 / 1053 lines)

**Status:** done — 35 rows: 28 ✅ 4 ⚠️ 1 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `StatusIsSendable` (70) | `StatusIsSendable` `Core/Debug/OODebugTCPConsoleClient.cpp:86` | ✅ |
| `-[OODebugTCPConsoleClient init]` (109) | — (no caller; `clientWithAddress(nullopt, 0)` is the same) | ➖ |
| `-[OODebugTCPConsoleClient initWithAddress:port:]` (114) | `clientWithAddress` `:243` + `initWithAddress` `:253` + `openSocketToHost` `:427` | ⚠️ |
| `-[OODebugTCPConsoleClient dealloc]` (210) | `~OODebugTCPConsoleClient` `:318` | ⚠️ |
| `-[OODebugTCPConsoleClient connectDebugMonitor:errorMessage:]` (227) | `connectDebugMonitor` `:335` | ✅ |
| `-[OODebugTCPConsoleClient disconnectDebugMonitor:message:]` (246) | `disconnectDebugMonitor` `:351` | ✅ |
| `-[OODebugTCPConsoleClient debugMonitor:jsConsoleOutput:colorKey:emphasisRange:]` (253) | `debugMonitor(monitor, output, colorKey, range)` `:358` (`general` default, range only when length ≠ 0) | ✅ |
| `-[OODebugTCPConsoleClient debugMonitorClearConsole:]` (276) | `debugMonitorClearConsole` `:381` | ✅ |
| `-[OODebugTCPConsoleClient debugMonitorShowConsole:]` (282) | `debugMonitorShowConsole` `:386` | ✅ |
| `-[OODebugTCPConsoleClient debugMonitor:noteConfiguration:]` (288) | `debugMonitor(monitor, configuration)` `:391` | ✅ |
| `-[OODebugTCPConsoleClient debugMonitor:noteChangedConfigrationValue:forKey:]` (296) | `debugMonitor(monitor, newValue, key)` `:397` | ✅ |
| `-[OODebugTCPConsoleClient stream:handleEvent:]` (311) | `handleWaitResultRead` `:550`, `handleErrorEvent` `:583`, `OODebugTCPConsoleServiceInput` `:960` | ⚠️ |
| `-[OODebugTCPConsoleClient(OOPrivate) closeConnection]` (330) | `closeConnection` `:412` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) sendBytes:count:]` (346) | `sendBytes` `:617` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) sendDictionary:]` (365) | `sendDictionary` `:651` (same 8/16/8 ms retries, log texts) | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) sendPacket:withParameters:]` (433) | `sendPacket(type, parameters)` `:721` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) sendPacket:withValue:forParameter:]` (450) | `sendPacket(type, value, paramKey)` `:733` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) readData]` (465) | `readData` `:745` (the non-mac loop) | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) dispatchPacket:ofType:]` (492) | `dispatchPacket` `:764` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleApproveConnectionPacket:]` (518) | `handleApproveConnectionPacket` `:791` | ❌ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleRejectConnectionPacket:]` (549) | `handleRejectConnectionPacket` `:819` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleCloseConnectionPacket:]` (565) | `handleCloseConnectionPacket` `:833` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleNoteConfigurationChangePacket:]` (578) | `handleNoteConfigurationChangePacket` `:844` (removed-keys read from `configuration`, as upstream's bug) | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handlePerformCommandPacket:]` (604) | `handlePerformCommandPacket` `:873` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleRequestConfigurationValuePacket:]` (613) | `handleRequestConfigurationValuePacket` `:882` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handlePingPacket:]` (627) | `handlePingPacket` `:894` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handlePongPacket:]` (637) | `handlePongPacket` `:901` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) disconnectFromServerWithMessage:]` (642) | `disconnectFromServerWithMessage` `:905` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) breakConnectionWithMessage:]` (654) | `breakConnectionWithMessage` `:918` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) breakConnectionWithBadStream:]` (674) | `breakConnectionWithStreamError` `:941` | ⚠️ |
| `DecoderPacket` (692) | `OODebugTCPConsoleClient::DecoderPacket` `:1012` | ✅ |
| `DecoderError` (697) | `OODebugTCPConsoleClient::DecoderError` `:1024` | ✅ |
| `LogOOTCPStreamDecoderPacket` (703) | `LogOOTCPStreamDecoderPacket` `:1035` | ✅ |
| `LogSendPacket` (713) | `LogSendPacket` `:1044` | ✅ |
| `OOConnectTCPSocket` (728) | — (macOS-only, upstream 107f656c0; port's own non-blocking IPv4 connect is `openSocketToHost` `:427`, no timeout) | ➖ |

**Differences:**

- ❌ **low** — "Connected to debug console … at X": on GNUstep (Windows/Linux) upstream prints `[_host name]` (NSHost's resolved name, possibly the machine name for a numeric address); port prints the address as configured, which is what upstream's new macOS branch does (still open) — upstream `Core/Debug/OODebugTCPConsoleClient.m:534-541` ↔ port `Core/Debug/OODebugTCPConsoleClient.cpp:805-809`
- ⚠️ **med** — connect wait: upstream ran the run loop up to a 3 s `beforeDate:` (and macOS now hard-limits connect to 3 s in `OOConnectTCPSocket`); port waits on the socket with no limit (`OODebugTCPConsoleServiceInput(-1.0)`) until it opens or fails; port comment says the GNUstep wait never honoured 3 s either (bead oo-3rb.14 per previous audit) (still open) — upstream `OODebugTCPConsoleClient.m:170-177,751` ↔ port `OODebugTCPConsoleClient.cpp:267-275`
- ⚠️ **low** — `NSHost`/`NSStream` replaced by a non-blocking IPv4 socket; an unknown host logs `Host '…' not found …` in class `unclassified` (GNUstep's own NSLog) and gives no connection (still open) — upstream `OODebugTCPConsoleClient.m:150-157` ↔ port `OODebugTCPConsoleClient.cpp:427-485`
- ⚠️ **low** — `stream:handleEvent:` is driven by `select()`: bytes-available → `readData` when `_status <= Connected`, error → `breakConnectionWithStreamError`; end-of-stream ignored (upstream's second `ErrorOccurred` branch is dead) (still open) — upstream `OODebugTCPConsoleClient.m:311-324` ↔ port `OODebugTCPConsoleClient.cpp:550-587,960-1010`
- ⚠️ **low** — `breakConnectionWithBadStream:` text uses OS error text (`FormatMessageW` / `strerror`) and emulated stream statuses (0/1/2/3/5/7); port comment says measured against gnustep-base 1.31 (still open) — upstream `OODebugTCPConsoleClient.m:674-688` ↔ port `OODebugTCPConsoleClient.cpp:94-122,941-951`
- ⚠️ **low** — `~OODebugTCPConsoleClient` does not tell a still-set `_monitor` to disconnect (could not happen; port comment) (still open) — upstream `OODebugTCPConsoleClient.m:215-217` ↔ port `OODebugTCPConsoleClient.cpp:323-327`
- ✅ subtle — `readData` follows the GNUstep (non-macOS) loop; upstream's new macOS `hasBytesAvailable` loop is platform-only — upstream `OODebugTCPConsoleClient.m:473-489` ↔ port `OODebugTCPConsoleClient.cpp:745-762`
- ✅ subtle — `RequestConnection`'s `OoliteVersion` comes from `<Resources>/Info-gnustep.plist` (omitted when absent); `handleNoteConfigurationChangePacket` applies entries in byte order and skips non-string removed keys — upstream `OODebugTCPConsoleClient.m:187-192,589-601` ↔ port `OODebugTCPConsoleClient.cpp:223-238,288-298,844-871`

## OOTCPStreamDecoderAbstractionLayer

<a id="ootcpstreamdecoderabstractionlayer"></a>
Upstream `src/Core/Debug/OOTCPStreamDecoderAbstractionLayer.m` ↔ `Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp` (112 / 177 lines)

**Status:** done — 14 rows: 12 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOALGetConstantString` (15) | `OOALGetConstantString` `Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp:66` (one object per literal pointer) | ✅ |
| `OOALRelease` (37) | `OOALRelease` `:83` | ✅ |
| `OOTypeDescription` (42) | `OOTypeDescription` `:85` | ⚠️ |
| `OOALIsString` (47) | `OOALIsString` `:99` | ✅ |
| `OOALStringCreateWithFormatAndArguments` (52) | `OOALStringCreateWithFormatAndArguments` `:101` → `OOTCPStreamDecoderFormat::FormatWithArguments` | ✅ |
| `OOALIsDictionary` (57) | `OOALIsDictionary` `:108` | ✅ |
| `OOALDictionaryGetValue` (62) | `OOALDictionaryGetValue` `:110` (string keys only) | ✅ |
| `OOALIsData` (67) | `OOALIsData` `:123` | ✅ |
| `OOALDataCreateMutable` (72) | `OOALDataCreateMutable` `:125` | ✅ |
| `OOALMutableDataAppendBytes` (77) | `OOALMutableDataAppendBytes` `:130` | ✅ |
| `OOALDataGetBytePtr` (82) | `OOALDataGetBytePtr` `:135` | ✅ |
| `OOALDataGetLength` (87) | `OOALDataGetLength` `:139` | ✅ |
| `OOALCreateAutoreleasePool` (92) | `OOALCreateAutoreleasePool` `:143` (+ `OOALDestroyAutoreleasePool` `:149`, a header macro upstream) | ✅ |
| `OOALPropertyListFromData` (97) | `OOALPropertyListFromData` `:154` | ❌ |

**Differences:**

- ❌ **low** — malformed packet: the `Protocol error: packet is not property list (property list error: %@)` text carries the oofnd parser's error description, not GNUstep's `NSPropertyListSerialization` text, so the `debugTCP.disconnect` line differs; binary plists are rejected (ADR-0027 item 3 per previous audit) where GNUstep parsed them (still open) — upstream `Core/Debug/OOTCPStreamDecoderAbstractionLayer.m:97-110` ↔ port `Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp:154-173`
- ⚠️ **low** — `OOTypeDescription` answers the plist type name (`array`, `string`, …) where upstream answered the GNUstep class name (`GSArray`…), changing `Protocol error: packet is a %@, not a dictionary.`; documented in the port comment (still open) — upstream `OOTCPStreamDecoderAbstractionLayer.m:42-45` ↔ port `OOTCPStreamDecoderAbstractionLayer.cpp:85-97`
- ✅ subtle — parsed packets belong to the innermost OOAL pool, as the retained/autoreleased objects did; the formatter handles the `%u`/`%zu`/`%@`/`%%` the decoder uses — port `OOTCPStreamDecoderAbstractionLayer.cpp:101-106,168-171`

## OOFullScreenController

<a id="oofullscreencontroller"></a>
Upstream `src/Core/OOFullScreenController.m` ↔ `Core/OOFullScreenController.cpp` (95 / 77 lines)

**Status:** done — 11 rows: 9 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOFullScreenController initWithGameView:]` (31) | `OOFullScreenController::OOFullScreenController(MyOpenGLView*)` `Core/OOFullScreenController.cpp:30` | ✅ |
| `-[OOFullScreenController dealloc]` (39) | — (the `oo::Ref` member `_gameView` releases the view) | ➖ |
| `-[OOFullScreenController gameView]` (46) | `gameView` `:33` | ✅ |
| `-[OOFullScreenController inFullScreenMode]` (51) | `inFullScreenMode` `:35` | ✅ |
| `-[OOFullScreenController setFullScreenMode:]` (57) | `setFullScreenMode` `:40` | ✅ |
| `-[OOFullScreenController displayModes]` (62) | `displayModes` `:44` | ✅ |
| `-[OOFullScreenController currentDisplayMode]` (68) | `currentDisplayMode` `:49` | ❌ |
| `-[OOFullScreenController indexOfCurrentDisplayMode]` (73) | `indexOfCurrentDisplayMode` `:58` | ✅ |
| `-[OOFullScreenController setDisplayWidth:height:refreshRate:]` (79) | `setDisplayWidth` `:63` | ✅ |
| `-[OOFullScreenController findDisplayModeForWidth:height:refreshRate:]` (85) | `findDisplayModeForWidth` `:70` | ✅ |
| `-[OOFullScreenController noteMouseInteractionModeChangedFrom:to:]` (91) | `noteMouseInteractionModeChangedFrom` `:76` | ✅ |

**Differences:**

- ❌ **low** — `currentDisplayMode` with an out-of-range index on a non-empty mode list answers a null mode where upstream `objectAtIndex:` raised `NSRangeException`; with the base class's nil list both answer nil. The abstract base is never instantiated on SDL, so unreachable in practice (still open) — upstream `Core/OOFullScreenController.m:68-71` ↔ port `Core/OOFullScreenController.cpp:49-56`
- ✅ subtle — the abstract methods still log `OOLogGenericSubclassResponsibility()` and return `NO`/nil/`NSNotFound` (`oo::kNotFound`).

## OOJoystickManager

<a id="oojoystickmanager"></a>
Upstream `src/Core/OOJoystickManager.m` ↔ `Core/OOJoystickManager.cpp` (598 / 560 lines)

**Status:** done — 36 rows: 33 ✅ 3 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOJoystickManager sharedStickHandler]` (49) | `OOJoystickManager::sharedStickHandler` `Core/OOJoystickManager.cpp:45` | ✅ |
| `+[OOJoystickManager setStickHandlerClass:]` (59) | `OOJoystickManager::setStickHandlerFactory` `:61` (factory stands in for the class) | ✅ |
| `-[OOJoystickManager init]` (68) | `OOJoystickManager::init` `:70` (clearStickStates, loadStickSettings, then invertPitch/precisionMode false) | ✅ |
| `-[OOJoystickManager rollPitchAxis]` (88) | `rollPitchAxis` `:88` | ✅ |
| `-[OOJoystickManager viewAxis]` (93) | `viewAxis` `:92` | ✅ |
| `-[OOJoystickManager getButtonState:]` (98) | `getButtonState` `:96` | ✅ |
| `-[OOJoystickManager getAllButtonStates]` (103) | `getAllButtonStates` `:100` | ✅ |
| `-[OOJoystickManager isButtonDown:stick:]` (108) | `isButtonDown` `:102` | ✅ |
| `-[OOJoystickManager getAxisState:]` (113) | `getAxisState` `:106` (null profile → 0 as nil messaging) | ✅ |
| `-[OOJoystickManager getSensitivity]` (142) | `getSensitivity` `:145` | ✅ |
| `-[OOJoystickManager setProfile:forAxis:]` (147) | `setProfile` `:149` | ✅ |
| `-[OOJoystickManager getProfileForAxis:]` (168) | `getProfileForAxis` `:166` | ✅ |
| `-[OOJoystickManager saveProfileForAxis:]` (181) | `saveProfileForAxis` `:178` (same keys; control points as single reals) | ✅ |
| `-[OOJoystickManager loadProfileForAxis:]` (228) | `loadProfileForAxis` `:227` | ✅ |
| `-[OOJoystickManager listSticks]` (272) | `listSticks` `:273` | ✅ |
| `-[OOJoystickManager axisFunctions]` (283) | `axisFunctions` `:284` | ✅ |
| `-[OOJoystickManager buttonFunctions]` (305) | `buttonFunctions` `:303` | ✅ |
| `-[OOJoystickManager guiButtonFunctions]` (327) | `guiButtonFunctions` `:322` (same loop, keys `isAxis`/`stickNum`/`stickAxBt`) | ✅ |
| `-[OOJoystickManager setFunction:withDict:]` (349) | `setFunction` `:341` (GUI range `BUTTON_GUILEFT..BUTTON_GUISELECT` routed the same) | ✅ |
| `-[OOJoystickManager setFunctionForAxis:function:stick:]` (374) | `setFunctionForAxis` `:357` | ✅ |
| `-[OOJoystickManager setFunctionForButton:function:stick:]` (394) | `setFunctionForButton` `:375` | ✅ |
| `-[OOJoystickManager setGuiFunctionForButton:function:stick:]` (412) | `setGuiFunctionForButton` `:391` | ✅ |
| `-[OOJoystickManager unsetAxisFunction:]` (430) | `unsetAxisFunction` `:407` | ✅ |
| `-[OOJoystickManager unsetButtonFunction:]` (444) | `unsetButtonFunction` `:420` | ✅ |
| `-[OOJoystickManager unsetGuiButtonFunction:]` (457) | `unsetGuiButtonFunction` `:432` | ✅ |
| `-[OOJoystickManager setDefaultMapping]` (470) | `setDefaultMapping` `:444` | ✅ |
| `-[OOJoystickManager clearMappings]` (481) | `clearMappings` `:454` (also resets `guibuttonmap`) | ⚠️ |
| `-[OOJoystickManager clearStickStates]` (487) | `clearStickStates` `:464` | ✅ |
| `-[OOJoystickManager clearStickButtonState:]` (503) | `clearStickButtonState` `:479` | ✅ |
| `-[OOJoystickManager setCallback:object:hardware:]` (510) | `setCallback(StickCallback, hwflags)` `:485` | ⚠️ |
| `-[OOJoystickManager clearCallback]` (519) | `clearCallback` `:490` | ✅ |
| `-[OOJoystickManager saveStickSettings]` (525) | `saveStickSettings` `:495` (adds `GuiJoystickButs`) | ✅ |
| `-[OOJoystickManager loadStickSettings]` (541) | `loadStickSettings` `:507` | ⚠️ |
| `-[OOJoystickManager joystickCount]` (583) | `joystickCount` `:550` | ✅ |
| `-[OOJoystickManager nameOfJoystick:]` (588) | `nameOfJoystick` `:552` | ✅ |
| `-[OOJoystickManager getAxisWithStick:axis:]` (593) | `getAxisWithStick` `:557` | ✅ |

**Differences:**

- ⚠️ **med** — `clearMappings` also fills `guibuttonmap` with `STICK_NOFUNCTION`; upstream #783 never resets it, so its table stays all 0 (`BUTTON_INCTHRUST`): every unbound button press also drives `butstate[BUTTON_INCTHRUST]`, and `guiButtonFunctions` saves `"0"` bound to the last stick's last button, which on reload (via `setFunction`→`setFunctionForButton`) unbinds the player's increase-thrust button. Port comment calls this an upstream bug fix; no bead/ADR cited (new) — upstream `Core/OOJoystickManager.m:481-485` ↔ port `Core/OOJoystickManager.cpp:454-462`
- ⚠️ **low** — `loadStickSettings` visits `JoystickAxes`/`JoystickButs`/`GuiJoystickButs` keys in byte order instead of `NSDictionary` order; when two entries claim the same stick axis/button the winner can differ (port comment) (still open) — upstream `Core/OOJoystickManager.m:550-576` ↔ port `Core/OOJoystickManager.cpp:515-543`
- ⚠️ **low** — the capture callback is a `std::function` instead of unretained object + selector (header comment); cleared the same way (still open) — upstream `OOJoystickManager.m:510-523` ↔ port `OOJoystickManager.cpp:485-493`
- ✅ subtle — the `BUTTON_GUI*` enum values (after `BUTTON_TOGGLEHUD`) and `GUI_BUTTON_SETTINGS` = `GuiJoystickButs` match upstream; values pinned by `static_assert`s — port `Core/OOJoystickManager.h:166-174`
- ✅ subtle — the decode functions are no longer in the base class (previous audit placed them here); they live in `SDL/OOSDLJoystickManager.cpp:172-296` again (see that section).

## OOJoystickProfile

<a id="oojoystickprofile"></a>
Upstream `src/Core/OOJoystickProfile.m` ↔ `Core/OOJoystickProfile.cpp` (549 / 521 lines)

**Status:** done — 40 rows: 40 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJoystickAxisProfile init]` (84) | `OOJoystickAxisProfile::OOJoystickAxisProfile` `Core/OOJoystickProfile.cpp:86` | ✅ |
| `-[OOJoystickAxisProfile copyWithZone:]` (92) | `OOJoystickAxisProfile::copy` `:88` (deadzone not copied, as before) | ✅ |
| `-[OOJoystickAxisProfile rawValue:]` (98) | `OOJoystickAxisProfile::rawValue` `:96` | ✅ |
| `-[OOJoystickAxisProfile value:]` (103) | `OOJoystickAxisProfile::value` `:98` | ✅ |
| `-[OOJoystickAxisProfile deadzone]` (111) | `deadzone` `:106` | ✅ |
| `-[OOJoystickAxisProfile setDeadzone:]` (116) | `setDeadzone` `:108` | ✅ |
| `-[OOJoystickStandardAxisProfile init]` (125) | `OOJoystickStandardAxisProfile::OOJoystickStandardAxisProfile` `:112` | ✅ |
| `-[OOJoystickStandardAxisProfile copyWithZone:]` (134) | `OOJoystickStandardAxisProfile::copy` `:117` | ✅ |
| `-[OOJoystickStandardAxisProfile setPower:]` (142) | `setPower` `:125` | ✅ |
| `-[OOJoystickStandardAxisProfile power]` (154) | `power` `:136` | ✅ |
| `-[OOJoystickStandardAxisProfile setParameter:]` (159) | `setParameter` `:138` | ✅ |
| `-[OOJoystickStandardAxisProfile parameter]` (165) | `parameter` `:143` | ✅ |
| `-[OOJoystickStandardAxisProfile rawValue:]` (170) | `OOJoystickStandardAxisProfile::rawValue` `:145` | ✅ |
| `-[OOJoystickSplineSegment init]` (182) | `OOJoystickSplineSegment::OOJoystickSplineSegment` `:153` | ✅ |
| `-[OOJoystickSplineSegment copyWithZone:]` (195) | `OOJoystickSplineSegment::copy` `:162` | ✅ |
| `-[OOJoystickSplineSegment initWithData:right:]` (207) | `initWithData(left, right)` `:179` | ✅ |
| `-[OOJoystickSplineSegment initWithData:right:gradientleft:]` (224) | `initWithData(left, right, gl)` `:193` (same coefficients) | ✅ |
| `-[OOJoystickSplineSegment initWithData:right:gradientright:]` (240) | `initWithDataGradientRight` `:210` | ✅ |
| `-[OOJoystickSplineSegment initWithData:right:gradientleft:gradientright:]` (256) | `initWithData(left, right, gl, gr)` `:229` | ✅ |
| `+[OOJoystickSplineSegment segmentWithData:right:]` (273) | `segmentWithData(left, right)` `:257` | ✅ |
| `+[OOJoystickSplineSegment segmentWithData:right:gradientleft:]` (279) | `segmentWithData(left, right, gl)` `:265` | ✅ |
| `+[OOJoystickSplineSegment segmentWithData:right:gradientright:]` (285) | `segmentWithDataGradientRight` `:274` | ✅ |
| `+[OOJoystickSplineSegment segmentWithData:right:gradientleft:gradientright:]` (291) | `segmentWithData(left, right, gl, gr)` `:285` | ✅ |
| `-[OOJoystickSplineSegment start]` (297) | `start` `:295` | ✅ |
| `-[OOJoystickSplineSegment end]` (302) | `end` `:297` | ✅ |
| `-[OOJoystickSplineSegment value:]` (307) | `OOJoystickSplineSegment::value` `:299` | ✅ |
| `-[OOJoystickSplineSegment gradient:]` (312) | `OOJoystickSplineSegment::gradient` `:303` | ✅ |
| `-[OOJoystickSplineAxisProfile init]` (321) | `OOJoystickSplineAxisProfile::OOJoystickSplineAxisProfile` `:307` | ✅ |
| `-[OOJoystickSplineAxisProfile dealloc]` (331) | `~OOJoystickSplineAxisProfile` `:313` (members release) | ✅ |
| `-[OOJoystickSplineAxisProfile copyWithZone:]` (339) | `OOJoystickSplineAxisProfile::copy` `:315` | ✅ |
| `-[OOJoystickSplineAxisProfile addControl:]` (347) | `addControl` `:324` | ✅ |
| `-[OOJoystickSplineAxisProfile pointAtIndex:]` (382) | `pointAtIndex` `:359` | ✅ |
| `-[OOJoystickSplineAxisProfile countPoints]` (397) | `countPoints` `:373` | ✅ |
| `-[OOJoystickSplineAxisProfile controlPoints]` (402) | `controlPoints` `:375` (returns a copy) | ✅ |
| `-[OOJoystickSplineAxisProfile makeSegments]` (408) | `makeSegments` `:380` | ✅ |
| `-[OOJoystickSplineAxisProfile removeControl:]` (461) | `removeControl` `:436` | ✅ |
| `-[OOJoystickSplineAxisProfile clearControlPoints]` (470) | `clearControlPoints` `:445` | ✅ |
| `-[OOJoystickSplineAxisProfile moveControl:point:]` (476) | `moveControl` `:450` (index-0 `right.x = 0` quirk kept) | ✅ |
| `-[OOJoystickSplineAxisProfile rawValue:]` (515) | `OOJoystickSplineAxisProfile::rawValue` `:491` | ✅ |
| `-[OOJoystickSplineAxisProfile gradient:]` (536) | `OOJoystickSplineAxisProfile::gradient` `:511` | ✅ |

**Differences:**

- ✅ subtle — dead zone, standard curve, spline coefficients, `SPLINE_POINT_MIN_SPACING` checks and segment search (`end > x`) are verbatim — upstream `Core/OOJoystickProfile.m:103-176,207-271,515-547` ↔ port `Core/OOJoystickProfile.cpp:98-151,179-254,491-521`
- ✅ subtle — the failable `-initWithData:` became `bool` initialisers run after the default constructor; port comment `:174-178` explains the result is identical (`a[3]` stays 0 on the quadratic paths). A spline copy holds a mutable point list where upstream's copy held an immutable `NSArray` (editing it would have raised); no caller copies.

## GameController+SDLFullScreen

<a id="gamecontrollersdlfullscreen"></a>
Upstream `src/SDL/GameController+SDLFullScreen.m` ↔ `SDL/GameController+SDLFullScreen.cpp` (155 / 162 lines)

**Status:** done — 9 rows: 8 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[GameController(FullScreen) setUpDisplayModes]` (38) | `GameController::setUpDisplayModes` `SDL/GameController+SDLFullScreen.cpp:61` (same min/max filter, current-mode fallback to `currentScreenSize`) | ✅ |
| `-[GameController(FullScreen) setFullScreenMode:]` (69) | `GameController::setFullScreenMode` `:93` | ✅ |
| `-[GameController(FullScreen) exitFullScreenMode]` (74) | `GameController::exitFullScreenMode` `:95` | ✅ |
| `-[GameController(FullScreen) inFullScreenMode]` (80) | `GameController::inFullScreenMode` `:100` | ✅ |
| `-[GameController(FullScreen) setDisplayWidth:Height:Refresh:]` (85) | `GameController::setDisplayWidth` `:104` (same three defaults keys + synchronize) | ✅ |
| `-[GameController(FullScreen) findDisplayModeForWidth:Height:Refresh:]` (108) | `GameController::findDisplayModeForWidth` `:130` → `FindDisplayMode` `:40` | ✅ |
| `-[GameController(FullScreen) displayModes]` (128) | `GameController::getDisplayModes` `:139` | ✅ |
| `-[GameController(FullScreen) indexOfCurrentDisplayMode]` (133) | `GameController::indexOfCurrentDisplayMode` `:143` | ✅ |
| `-[GameController(FullScreen) pauseFullScreenModeToPerform:onTarget:]` (146) | `GameController::pauseFullScreenModeToPerform` `:155` | ⚠️ |

**Differences:**

- ⚠️ **low** — `pauseFullScreenModeToPerform` stores the selector by name (`std::string_view`) and the target as `oo::Object*` (bead oo-xu228.3 per previous audit); same state change `stayInFullScreenMode = NO` (still open) — upstream `SDL/GameController+SDLFullScreen.m:146-151` ↔ port `SDL/GameController+SDLFullScreen.cpp:155-160`
- ✅ subtle — `indexOfCurrentDisplayMode` returns the first match's position, which is what `indexOfObject:` (isEqual) of that first match gave; a null `_gameView` reads as nil messaging (empty list, 0×0, NO) — upstream `GameController+SDLFullScreen.m:133-144` ↔ port `GameController+SDLFullScreen.cpp:143-153`

## MyOpenGLView+Input

<a id="myopenglviewinput"></a>
Upstream `src/SDL/MyOpenGLView+Input.m` ↔ `SDL/MyOpenGLView+Input.cpp` (901 / 961 lines)

**Status:** done — 34 rows: 33 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[MyOpenGLView(Input) initKeyMappingData]` (30) | `MyOpenGLView::initKeyMappingData` `SDL/MyOpenGLView+Input.cpp:38` | ✅ |
| `-[MyOpenGLView(Input) autoShowMouse]` (48) | `autoShowMouse` `:62` | ✅ |
| `-[MyOpenGLView(Input) setStringInput:]` (59) | `setStringInput` `:70` | ✅ |
| `-[MyOpenGLView(Input) allowStringInput:]` (63) | `allowStringInput` `:73` | ✅ |
| `-[MyOpenGLView(Input) allowingStringInput]` (70) | `getAllowingStringInput` `:79` | ✅ |
| `-[MyOpenGLView(Input) typedString]` (74) | `getTypedString` `:82` | ✅ |
| `-[MyOpenGLView(Input) resetTypedString]` (78) | `resetTypedString` `:85` | ✅ |
| `-[MyOpenGLView(Input) setTypedString:]` (82) | `setTypedString` `:86` | ✅ |
| `-[MyOpenGLView(Input) noteMouseInteractionModeChangedFrom:to:]` (86) | `noteMouseInteractionModeChangedFrom` `:89` | ✅ |
| `-[MyOpenGLView(Input) setVirtualJoystick:vmy:]` (91) | `setVirtualJoystick` `:94` | ✅ |
| `-[MyOpenGLView(Input) virtualJoystickPosition]` (96) | `getVirtualJoystickPosition` `:98` | ✅ |
| `-[MyOpenGLView(Input) clearKeys]` (102) | `clearKeys` `:103` | ✅ |
| `-[MyOpenGLView(Input) clearMouse]` (109) | `clearMouse` `:108` | ✅ |
| `-[MyOpenGLView(Input) clearKey:]` (115) | `clearKey` `:113` | ✅ |
| `-[MyOpenGLView(Input) resetMouse]` (121) | `resetMouse` `:118` (warp divided by pixel density, as upstream 3193dfe80) | ✅ |
| `-[MyOpenGLView(Input) isAlphabetKeyDown]` (133) | `getIsAlphabetKeyDown` `:130` | ✅ |
| `-[MyOpenGLView(Input) suppressKeysUntilKeyUp]` (143) | `suppressKeysUntilKeyUp` `:139` | ✅ |
| `-[MyOpenGLView(Input) isDown:]` (152) | `isDown` `:147` | ✅ |
| `-[MyOpenGLView(Input) isOptDown]` (162) | `isOptDown` `:153` | ✅ |
| `-[MyOpenGLView(Input) isCtrlDown]` (166) | `isCtrlDown` `:154` | ✅ |
| `-[MyOpenGLView(Input) isCommandDown]` (170) | `isCommandDown` `:155` | ✅ |
| `-[MyOpenGLView(Input) isShiftDown]` (174) | `isShiftDown` `:156` | ✅ |
| `-[MyOpenGLView(Input) isCapsLockOn]` (178) | `isCapsLockOn` `:157` | ✅ |
| `-[MyOpenGLView(Input) lastKeyWasShifted]` (188) | `lastKeyWasShifted` `:166` | ✅ |
| `-[MyOpenGLView(Input) numKeys]` (192) | `numKeys` `:167` | ✅ |
| `-[MyOpenGLView(Input) mouseWheelState]` (196) | `mouseWheelState` `:168` | ✅ |
| `-[MyOpenGLView(Input) mouseWheelDelta]` (205) | `mouseWheelDelta` `:176` | ✅ |
| `-[MyOpenGLView(Input) setMouseWheelDelta:]` (209) | `setMouseWheelDelta` `:179` | ✅ |
| `-[MyOpenGLView(Input) isCommandQDown]` (213) | `isCommandQDown` `:182` | ✅ |
| `-[MyOpenGLView(Input) isCommandFDown]` (217) | `isCommandFDown` `:183` | ✅ |
| `-[MyOpenGLView(Input) clearCommandF]` (221) | `clearCommandF` `:184` | ✅ |
| `-[MyOpenGLView(Input) pollControls]` (225) | `pollControls` `:187` | ❌ |
| `-[MyOpenGLView(Input) handleStringInput:keyID:]` (862) | `handleStringInput` `:921` | ✅ |
| `-[MyOpenGLView(Input) setMouseInDeltaMode:]` (897) | `setMouseInDeltaMode` `:959` | ✅ |

**Differences:**

- ❌ **low** — key-array bound tightened from `key_id <= numKeys` to `< numKeys` on key-down and key-up. F12 maps to 327 = `NUM_KEYS`, so every F12 press now logs `keys.test` "Unhandled Keydown scancode/unicode: … 327" where upstream logged nothing (and wrote `keys[327]`, one past the end — UB). Coordinator note from the previous run: treat as a bug fix, not a regression (still open) — upstream `SDL/MyOpenGLView+Input.m:623,806` ↔ port `SDL/MyOpenGLView+Input.cpp:644,860`
- ❌ **low** (new) — the `input.keyMapping.keyPress.keyUp` line's `character = %c` is printed as `static_cast<char>(key_id)`: for codes ≥ 128 (incl. the `gv*` codes above 255, truncated to a byte) the port writes one raw byte where GNUstep's `%c` wrote the Latin-1 character as UTF-8 (the port's own `FormattedCharacter` does this for typed strings but is not used here). Only when that log class is on — upstream `MyOpenGLView+Input.m:660` ↔ port `MyOpenGLView+Input.cpp:683-688`
- ⚠️ **low** — double-click timing uses the button-up event's SDL timestamp (`timestamp / 1e9`) instead of `timeNow` sampled once per poll (port comment: a stalled poll split double-clicks; bugs oo-3rb.333/336 per previous audit); mouse-wheel timing uses `oo::date::monotonicSeconds()` (still open) — upstream `MyOpenGLView+Input.m:235,276-277` ↔ port `MyOpenGLView+Input.cpp:198-199,245-256`
- ✅ subtle — upstream 3193dfe80's high-DPI fixes are ported: `resetMouse` warps to `viewSize/2/pixelDensity`, absolute mouse motion multiplies event coords by `SDL_GetWindowPixelDensity` (≤ 0 → 1), and a resize saves `SDL_GetWindowSize` (points) instead of `viewSize` — upstream `MyOpenGLView+Input.m:126-129,356-360,849-855` ↔ port `MyOpenGLView+Input.cpp:123-126,342-345,908-914`
- ✅ subtle — key translation tables (keypad, Home/End/Insert/PgUp/PgDn, arrows, Pause, Backspace/Delete, F1-F12, Space/Return/Tab/Esc, Shift-Esc exit), ctrl/caps-lock remapping, modifier handling and the Windows focus `setEcoQoS` calls are case-for-case the same; `!allowingStringInput` → `== StringInput::kNo` — upstream `MyOpenGLView+Input.m:377-835` ↔ port `MyOpenGLView+Input.cpp:362-894`
- ✅ subtle — typed-string length counts UTF-16 units (cap 40) and `%c` of 32..255 appends the Latin-1 character as UTF-8 — upstream `MyOpenGLView+Input.m:862-896` ↔ port `MyOpenGLView+Input.cpp:921-958`

## MyOpenGLView

<a id="myopenglview"></a>
Upstream `src/SDL/MyOpenGLView.m` ↔ `SDL/MyOpenGLView.cpp` (1465 / 1507 lines)

**Status:** done — 65 rows: 62 ✅ 2 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[MyOpenGLView getDisplayId]` (59) | `MyOpenGLView::getDisplayId` `SDL/MyOpenGLView.cpp:91` | ✅ |
| `-[MyOpenGLView getNativeSize]` (77) | `getNativeSize` `:109` (1024×768 fallback, refresh integer 0) | ✅ |
| `-[MyOpenGLView getWindowCaption]` (100) | `getWindowCaption` `:138` | ✅ |
| `-[MyOpenGLView createWindowWithSize:]` (106) | `createWindowWithSize` `:143` (splash-replacement flags, context reuse + rebind from #774, icon skip on macOS from #781) | ❌ |
| `-[MyOpenGLView init]` (307) | `init` `:378` | ⚠️ |
| `-[MyOpenGLView endSplashScreen]` (425) | `endSplashScreen` `:511` (new-window replacement of the splash window, #774) | ✅ |
| `-[MyOpenGLView updateGLSize:]` (493) | `updateGLSize` `:586` | ✅ |
| `-[MyOpenGLView setUpBasicOpenGLStateWithSize]` (516) | `setUpBasicOpenGLStateWithSize` `:609` | ✅ |
| `-[MyOpenGLView initialiseGLWithSize:]` (553) | `initialiseGLWithSize` `:645` | ✅ |
| `-[MyOpenGLView dealloc]` (601) | `~MyOpenGLView` `:692` (window, context, `SDL_Quit`; members release; matrixManager after `SDL_Quit`) | ✅ |
| `-[MyOpenGLView bounds]` (632) | `getBounds` `:834` | ✅ |
| `-[MyOpenGLView viewSize]` (637) | `getViewSize` `:836` | ✅ |
| `-[MyOpenGLView backingViewSize]` (642) | `backingViewSize` `:838` | ✅ |
| `-[MyOpenGLView display_z]` (647) | `getDisplay_z` `:840` | ✅ |
| `-[MyOpenGLView x_offset]` (652) | `getX_offset` `:842` | ✅ |
| `-[MyOpenGLView y_offset]` (657) | `getY_offset` `:844` | ✅ |
| `-[MyOpenGLView gameController]` (662) | `getGameController` `:846` | ✅ |
| `-[MyOpenGLView setGameController:]` (667) | `setGameController` `:848` | ✅ |
| `-[MyOpenGLView inFullScreenMode]` (672) | `inFullScreenMode` `:852` | ✅ |
| `-[MyOpenGLView setFullScreenMode:]` (678) | `setFullScreenMode` `:855` | ✅ |
| `-[MyOpenGLView toggleScreenMode]` (689) | `toggleScreenMode` `:863` | ✅ |
| `-[MyOpenGLView setDisplayMode:fullScreen:]` (704) | `setDisplayMode` `:878` | ✅ |
| `-[MyOpenGLView setScreenSize:]` (712) | `setScreenSize` `:884` | ✅ |
| `-[MyOpenGLView getScreenSizeArray]` (719) | `getScreenSizeArray` `:889` (returns a copy) | ✅ |
| `-[MyOpenGLView modeAsSize:]` (724) | `modeAsSize` `:893` | ✅ |
| `-[MyOpenGLView updateScreen]` (733) | `updateScreen` `:706` | ✅ |
| `-[MyOpenGLView initSplashScreen]` (745) | `initSplashScreen` `:717` | ✅ |
| `-[MyOpenGLView getDisplayDimensions:height:]` (858) | `getDisplayDimensions` `:901` | ✅ |
| `-[MyOpenGLView isRunningOnPrimaryDisplayDevice]` (871) | `isRunningOnPrimaryDisplayDevice` `:911` | ✅ |
| `-[MyOpenGLView grabMouseInsideGameWindow:]` (883) | `grabMouseInsideGameWindow` `:922` | ✅ |
| `-[MyOpenGLView stringToClipboard:]` (889) | `stringToClipboard` `:927` | ✅ |
| `-[MyOpenGLView atDesktopResolution]` (901) | `getAtDesktopResolution` `:938` | ✅ |
| `-[MyOpenGLView hdrOutput]` (906) | `hdrOutput` (Windows) `:940` | ✅ |
| `-[MyOpenGLView isOutputDisplayHDREnabled]` (911) | `isOutputDisplayHDREnabled` (Windows) `:942` | ✅ |
| `-[MyOpenGLView hdrMaxBrightness]` (929) | `hdrMaxBrightness` `:966` | ✅ |
| `-[MyOpenGLView setHDRMaxBrightness:]` (934) | `setHDRMaxBrightness` `:968` | ✅ |
| `-[MyOpenGLView hdrPaperWhiteBrightness]` (945) | `hdrPaperWhiteBrightness` `:978` | ✅ |
| `-[MyOpenGLView setHDRPaperWhiteBrightness:]` (950) | `setHDRPaperWhiteBrightness` `:982` | ✅ |
| `-[MyOpenGLView hdrToneMapper]` (961) | `hdrToneMapper` `:993` | ✅ |
| `-[MyOpenGLView setHDRToneMapper:]` (966) | `setHDRToneMapper` `:995` | ✅ |
| `-[MyOpenGLView hdrOutput]` (977) | `hdrOutput` (non-Windows stub) `:1005` | ✅ |
| `-[MyOpenGLView isOutputDisplayHDREnabled]` (982) | `isOutputDisplayHDREnabled` (non-Windows stub) `:1007` | ✅ |
| `-[MyOpenGLView sdrToneMapper]` (989) | `sdrToneMapper` `:1011` | ✅ |
| `-[MyOpenGLView setSDRToneMapper:]` (994) | `setSDRToneMapper` `:1013` | ✅ |
| `-[MyOpenGLView colorSaturation]` (1003) | `colorSaturation` `:1021` | ✅ |
| `-[MyOpenGLView adjustColorSaturation:]` (1008) (missed by extractor: stray `;`) | `adjustColorSaturation` `:1023` | ✅ |
| `-[MyOpenGLView snapShot:]` (1014) | `snapShot` `:1197` | ✅ |
| `-[MyOpenGLView populateFullScreenModelist]` (1145) | `populateFullScreenModelist` `:1029` (+ `SameMode` `:76`) | ✅ |
| `-[MyOpenGLView saveWindowSize:]` (1183) | `saveWindowSize` `:1070` | ✅ |
| `-[MyOpenGLView loadWindowSize]` (1191) | `loadWindowSize` `:1077` | ✅ |
| `-[MyOpenGLView loadFullscreenSettings]` (1205) | `loadFullscreenSettings` `:1092` | ✅ |
| `-[MyOpenGLView findDisplayModeForWidth:Height:Refresh:]` (1240) | `indexOfDisplayModeForWidth` `:1124` | ✅ |
| `-[MyOpenGLView currentScreenSize]` (1264) | `currentScreenSize` `:1153` | ✅ |
| `-[MyOpenGLView currentScreenMode]` (1276) | `currentScreenMode` `:1164` | ✅ |
| `-[MyOpenGLView setFov:fromFraction:]` (1282) | `setFov` `:1168` | ✅ |
| `-[MyOpenGLView fov:]` (1287) | `fov` `:1172` | ✅ |
| `-[MyOpenGLView msaa]` (1292) | `msaa` `:1176` | ✅ |
| `-[MyOpenGLView setMsaa:]` (1297) | `setMsaa` `:1178` | ✅ |
| `-[MyOpenGLView getOpenGLMatrixManager]` (1302) | `getOpenGLMatrixManager` `:1180` | ✅ |
| `+[MyOpenGLView pollShiftKey]` (1307) | `pollShiftKey` `:1184` | ✅ |
| `-[MyOpenGLView dumpRGBAToFileNamed:bytes:width:height:rowBytes:]` (1319) | `dumpRGBAToFileNamed` `:1363` | ✅ |
| `-[MyOpenGLView dumpRGBToFileNamed:bytes:width:height:rowBytes:]` (1337) | `dumpRGBToFileNamed` `:1383` | ✅ |
| `-[MyOpenGLView dumpGrayToFileNamed:bytes:width:height:rowBytes:]` (1355) | `dumpGrayToFileNamed` `:1403` | ✅ |
| `-[MyOpenGLView dumpGrayAlphaToFileNamed:bytes:width:height:rowBytes:]` (1383) | `dumpGrayAlphaToFileNamed` `:1433` | ⚠️ |
| `-[MyOpenGLView dumpRGBAToRGBFileNamed:andGrayFileNamed:bytes:width:height:rowBytes:]` (1411) | `dumpRGBAToRGBFileNamed` `:1467` | ✅ |

**Differences:**

- ❌ **low** — window icon path: upstream loads `Images/WMicon.bmp` from `[[NSBundle mainBundle] resourcePath]` (GNUstep: `<executable dir>/Resources`), port from `ResourcePaths::builtInResourcesDirectory()` (cwd-relative); same file when main's chdir to the executable's directory succeeds (still open) — upstream `SDL/MyOpenGLView.m:236-237` ↔ port `SDL/MyOpenGLView.cpp:290-293`
- ⚠️ **low** — `init` failure (SDL_Init fails) returns `false` and the caller releases the view, where upstream `[self dealloc]; return nil` (port comment; ADR-0056 amendment oo-9ht.153 per previous audit) (still open) — upstream `MyOpenGLView.m:370-374` ↔ port `MyOpenGLView.cpp:444-449`
- ⚠️ **low** — `init` starts `timeIntervalAtLastClick` on `SDL_GetTicksNS()` and `timeSinceLastMouseWheel` on the monotonic clock (port comments; pairs with the event-timestamp double-click fix) (still open) — upstream `MyOpenGLView.m:418` ↔ port `MyOpenGLView.cpp:500-504`
- ⚠️ **low** — `dumpGrayAlphaToFileNamed` writes into its own `SDL_CreateSurface` instead of a surface wrapped round the caller's 2-byte buffer (upstream overran it); port comment, bead oo-5thb0 per previous audit; debug-only (still open) — upstream `MyOpenGLView.m:1396` ↔ port `MyOpenGLView.cpp:1448-1451`
- ✅ subtle — upstream #774 (splash window replaced by a fresh hidden, resizable window sharing the one GL context, `SDL_GL_MakeCurrent` after `SDL_GetWindowSurface` and after destroying the old window, `replaceSplashWindow` skipping the border/resize calls) is ported line for line, as are #781's macOS icon skip and 3193dfe80's macOS-only surface/vsync/snapshot branches (`OOLITE_MACOS`) — upstream `MyOpenGLView.m:138-217,442-471` ↔ port `MyOpenGLView.cpp:177-270,530-563`
- ✅ subtle — snapshot naming (snapshot dir chdir with the two failure logs, `%03d` counter, "already exists" log doubling the extension, HDR extension with optional leading dot via `replaceOccurrences`) unchanged; an empty `hdr-snapshot-format` falls back to the default where upstream's `substringToIndex:1` raised — upstream `MyOpenGLView.m:1014-1142` ↔ port `MyOpenGLView.cpp:1197-1360`
- ✅ subtle — mode list: slot 0 native usable bounds, then full-screen modes with refresh as a single real, de-duplicated by value (`SameMode` for `-isEqual:`); lookup compares width/height/integer refresh; `-fullscreen`/`-windowed` last wins, `-nosplash` beats `-splash`, `-novsync`, `-hdr` scans unchanged — upstream `MyOpenGLView.m:334-351,1145-1262` ↔ port `MyOpenGLView.cpp:407-423,1029-1151`

## OOSDLJoystickManager

<a id="oosdljoystickmanager"></a>
Upstream `src/SDL/OOSDLJoystickManager.m` ↔ `SDL/OOSDLJoystickManager.cpp` (295 / 298 lines)

**Status:** done — 13 rows: 11 ✅ 1 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSDLJoystickManager init]` (33) | `OOSDLJoystickManager::OOSDLJoystickManager` `SDL/OOSDLJoystickManager.cpp:32`, then `OOJoystickManager::init` from `sharedStickHandler` | ✅ |
| `-[OOSDLJoystickManager dealloc]` (67) | — (`joystickIdMap` is a `std::map` member) | ➖ |
| `-[OOSDLJoystickManager getJoystickIndexFromId:]` (73) | `getJoystickIndexFromId` `:65` (`"%d"` key of the id) | ✅ |
| `-[OOSDLJoystickManager joystickCount]` (82) | `joystickCount` `:75` | ✅ |
| `-[OOSDLJoystickManager nameOfJoystick:]` (87) | `nameOfJoystick` `:77` | ✅ |
| `-[OOSDLJoystickManager getAxisWithStick:axis:]` (94) | `getAxisWithStick` `:87` | ✅ |
| `-[OOSDLJoystickManager makeJoyAxisEvent:]` (99) | `makeJoyAxisEvent` `:92` | ✅ |
| `-[OOSDLJoystickManager makeJoyButtonEvent:]` (109) | `makeJoyButtonEvent` `:102` | ✅ |
| `-[OOSDLJoystickManager makeJoyHatEvent:]` (119) | `makeJoyHatEvent` `:112` | ✅ |
| `-[OOSDLJoystickManager decodeAxisEvent:]` (129) | `decodeAxisEvent` `:172` (thrust/normal-div constants, callback threshold, pitch invert identical) | ✅ |
| `-[OOSDLJoystickManager decodeButtonEvent:]` (191) | `decodeButtonEvent` `:237` (adds the GUI-map lookup as upstream) | ✅ |
| `-[OOSDLJoystickManager decodeHatEvent:]` (234) | `decodeHatEvent` `:280` | ✅ |
| `-[OOSDLJoystickManager handleSDLEvent:]` (254) | `handleSDLEvent` `:121` | ⚠️ |

**Differences:**

- ⚠️ **low** — `handleSDLEvent` tests the stick index (`getJoystickIndexFromId(...) >= 0`) instead of `joyEvt.which >= 0` on the unsigned `SDL_JoystickID` (always true upstream), so events from an unknown stick are dropped instead of indexing `axismap`/`buttonmap` at 0xFFFFFFFF; port comment, bead oo-9ht.3 per previous audit (still open) — upstream `SDL/OOSDLJoystickManager.m:261,273,282` ↔ port `SDL/OOSDLJoystickManager.cpp:130,144,155`
- ✅ subtle — `decodeButtonEvent` now also sets `butstate[guibuttonmap[which][button]]` when ≥ 0, matching upstream #783; because the port's `clearMappings` resets the GUI table (see OOJoystickManager), unbound buttons no longer drive `BUTTON_INCTHRUST` as upstream's do — upstream `OOSDLJoystickManager.m:212-231` ↔ port `OOSDLJoystickManager.cpp:257-277`
- ✅ subtle — callbacks: copied out, `cbHardware` cleared first and the callback cleared after, as `cbObject = nil` after `performSelector:` — upstream `OOSDLJoystickManager.m:136-147,196-205` ↔ port `OOSDLJoystickManager.cpp:178-191,241-251`

## main

<a id="main"></a>
Upstream `src/SDL/main.m` ↔ `SDL/main.cpp` (257 / 323 lines)

**Status:** done — 1 rows: 0 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `main` (76) | `main` `SDL/main.cpp:92` | ❌ |

**Differences:**

- ❌ **low** — a `.oolite-save` argument is taken as UTF-8 (SDL_main's argv); upstream built it with `+[NSString stringWithCString:]` (GNUstep's default C-string encoding), so a non-ASCII save path decodes differently (still open) — upstream `SDL/main.m:166` ↔ port `SDL/main.cpp:224-229`
- ✅ subtle (new) — `-load` as the last argument: upstream then passed `argv[argc]` (NULL) to `stringWithCString:` and `strcmp`; port reads it as `""` and goes on, so no NULL dereference — upstream `main.m:162-170` ↔ port `main.cpp:220-231`
- ✅ subtle (new) — Windows start-up no longer sets `GNUSTEP_PATH_HANDLING` / `GNUSTEP_{SYSTEM,LOCAL,NETWORK,USERS}_ROOT` (nothing reads them without gnustep-base; the defaults home next to oolite.exe is now `ResourcePaths::homeDirectory()`, `oofnd/Defaults.hpp:22-29`); PATH prepend, `HOMEPATH` (built in its own string instead of `strcat` into the `LOCALAPPDATA` buffer), chdir and `setlocale(LC_ALL, "C")` kept — upstream `main.m:98-138` ↔ port `main.cpp:107-157`
- ✅ subtle — the Linux `/proc/self/exe` chdir and the new macOS bundle chdir (upstream 3193dfe80) are reproduced; argv is captured by `oo::process::setArguments` first; `-help` text, `process.args` log and the root `OOException` handler (`kOOLogException`, `EXIT_FAILURE`) are the same; `[NSDate class]` workaround gone with Foundation — upstream `main.m:139-169,171-249` ↔ port `main.cpp:158-196,204-320`

