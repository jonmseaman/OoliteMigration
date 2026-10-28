# Parity findings: SDL platform, input devices, debug support

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## OODebugMonitor

<a id="oodebugmonitor"></a>
Upstream `src/Core/Debug/OODebugMonitor.m` ↔ `Core/Debug/OODebugMonitor.cpp`

**Status:** done — 44 rows: 33 ✅ 3 ⚠️ 0 ❌ 8 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OODebugMonitor init]` (75) | `OODebugMonitor::init` `Core/Debug/OODebugMonitor.cpp:71` | ✅ |
| `-[OODebugMonitor dealloc]` (121) | — (never ran: singleton `-release` was a no-op; comment at `:101`, ADR-0056 amendment oo-kq7) | ➖ |
| `+[OODebugMonitor sharedDebugMonitor]` (139) | `OODebugMonitor::sharedDebugMonitor` `:105` | ✅ |
| `-[OODebugMonitor setDebugger:]` (149) | `OODebugMonitor::setDebugger` `:117` | ✅ |
| `-[OODebugMonitor performJSConsoleCommand:]` (181) | `OODebugMonitor::performJSConsoleCommand` `:150` | ✅ |
| `-[OODebugMonitor appendJSConsoleLine:colorKey:emphasisRange:]` (191) | `OODebugMonitor::appendJSConsoleLine(string, colorKey, range)` `:161` | ✅ |
| `-[OODebugMonitor appendJSConsoleLine:colorKey:]` (210) | `OODebugMonitor::appendJSConsoleLine(string, colorKey)` `:178` | ✅ |
| `-[OODebugMonitor clearJSConsole]` (218) | `OODebugMonitor::clearJSConsole` `:186` | ✅ |
| `-[OODebugMonitor showJSConsole]` (230) | `OODebugMonitor::showJSConsole` `:201` | ✅ |
| `-[OODebugMonitor configurationValueForKey:]` (242) | `OODebugMonitor::configurationValueForKey` `:216` | ✅ |
| `-[OODebugMonitor configurationValueForKey:class:defaultValue:]` (247) | folded into `configurationValueForKey` `:216` (only the `Nil`/`nil` path, the one the 1-arg form used; no other callers) | ➖ |
| `-[OODebugMonitor configurationIntValueForKey:defaultValue:]` (265) | `OODebugMonitor::configurationIntValueForKey` `:231` | ✅ |
| `-[OODebugMonitor setConfigurationValue:forKey:]` (281) | `OODebugMonitor::setConfigurationValue` `:251` | ✅ |
| `-[OODebugMonitor configurationKeys]` (311) | `OODebugMonitor::configurationKeys` `:287` | ✅ |
| `-[OODebugMonitor debuggerConnected]` (322) | `OODebugMonitor::debuggerConnected` `:303` | ✅ |
| `-[OODebugMonitor writeMemStat:]` (327) | `OODebugMonitor::writeMemStat` `:308` (takes a pre-formatted line) | ✅ |
| `SizeString()` (340) | `SizeString` `:316` | ✅ |
| `-[OODebugMonitor dumpEntity:withState:parentVisible:]` (380) | `OODebugMonitor::dumpEntity` `:358` | ⚠️ |
| `-[OODebugMonitor dumpMemoryStatistics]` (454) | `OODebugMonitor::dumpMemoryStatistics` `:429` | ⚠️ |
| `-[OODebugMonitor dumpJSMemoryStatistics]` (565) | `OODebugMonitor::dumpJSMemoryStatistics` `:535` | ⚠️ |
| `-[OODebugMonitor setTCPIgnoresDroppedPackets:]` (580) | `OODebugMonitor::setTCPIgnoresDroppedPackets` `:550` | ✅ |
| `-[OODebugMonitor TCPIgnoresDroppedPackets]` (589) | `OODebugMonitor::TCPIgnoresDroppedPackets` `:559` | ✅ |
| `-[OODebugMonitor setUsingPlugInController:]` (594) | `OODebugMonitor::setUsingPlugInController` `:564` | ✅ |
| `-[OODebugMonitor usingPlugInController]` (599) | `OODebugMonitor::usingPlugInController` `:569` | ✅ |
| `-[OODebugMonitor sourceCodeForFile:line:]` (604) | `OODebugMonitor::sourceCodeForFile` `:574` | ✅ |
| `-[OODebugMonitor disconnectDebugger:message:]` (626) | `OODebugMonitor::disconnectDebugger` `:594` | ✅ |
| `-[OODebugMonitor applicationWillTerminate]` (640) | `OODebugMonitor::applicationWillTerminate()` `:608` | ✅ |
| `-[OODebugMonitor applicationWillTerminate:]` (646) | `OODebugMonitor::applicationWillTerminate(notification)` `:614` | ✅ |
| `-[OODebugMonitor(Private) setUpDebugConsoleScript]` (659) | `OODebugMonitor::setUpDebugConsoleScript` `:623` | ✅ |
| `-[OODebugMonitor(Private) javaScriptEngineWillReset:]` (688) | `OODebugMonitor::javaScriptEngineWillReset` `:656` | ✅ |
| `-[OODebugMonitor(Private) disconnectDebuggerWithMessage:]` (696) | `OODebugMonitor::disconnectDebuggerWithMessage` `:664` | ✅ |
| `-[OODebugMonitor(Private) mergedConfiguration]` (710) | `OODebugMonitor::mergedConfiguration` `:679` | ✅ |
| `-[OODebugMonitor(Private) loadSourceFile:]` (723) | `OODebugMonitor::loadSourceFile` `:693` | ✅ |
| `-[OODebugMonitor(Private) normalizeConfigDictionary:]` (742) | `OODebugMonitor::normalizeConfigDictionary` `:707` | ✅ |
| `-[OODebugMonitor(Private) normalizeConfigValue:forKey:]` (761) | `OODebugMonitor::normalizeConfigValue` `:723` | ✅ |
| `-[OODebugMonitor(Private) jsEngine:context:error:stackSkip:showingLocation:withMessage:]` (779) | `OODebugMonitor::jsEngine(..., errorReport, ...)` `:747` | ✅ |
| `-[OODebugMonitor(Private) jsEngine:context:logMessage:ofClass:]` (858) | `OODebugMonitor::jsEngine(..., message, messageClass)` `:823` | ✅ |
| `-[OODebugMonitor(Private) oo_jsValueInContext:]` (869) | `OODebugMonitor::jsValueInContext` `:836` | ✅ |
| `+[OODebugMonitor(Singleton) allocWithZone:]` (897) | — (singleton made by `sharedDebugMonitor` and leaked; comment `:869`) | ➖ |
| `-[OODebugMonitor(Singleton) copyWithZone:]` (906) | — (as above) | ➖ |
| `-[OODebugMonitor(Singleton) retain]` (911) | — (as above) | ➖ |
| `-[OODebugMonitor(Singleton) retainCount]` (916) | — (as above) | ➖ |
| `-[OODebugMonitor(Singleton) release]` (921) | — (as above) | ➖ |
| `-[OODebugMonitor(Singleton) autorelease]` (925) | — (as above) | ➖ |

**Differences:**

- ⚠️ **low** — `-dealloc` (disconnect debugger, remove `_jsSelf` GC root) not translated; it could never run because the singleton's `-release` was a no-op (ADR-0056 amendment oo-kq7) — upstream `Core/Debug/OODebugMonitor.m:121` ↔ port `Core/Debug/OODebugMonitor.cpp:101`
- ⚠️ **low** — memory-stats sizes are C++ sizes: entity size from `oo::EntityObjectSize` (bead oo-dpyk8) and texture object size is `sizeof *tex` of the `OOTexture` root, not the concrete subclass's instance size (bead oo-9ht.99); ref counts are C++ ref counts. Diagnostic `debug.memStats` output differs in numbers — upstream `OODebugMonitor.m:388,516` ↔ port `OODebugMonitor.cpp:366,485`
- ⚠️ **low** — JS heap stats come from the QuickJS façade (`ooscript::getGCParameter`), so `JavaScript heap: … (limit …, N collections)` numbers differ by engine (ooscript README) — upstream `OODebugMonitor.m:570-572` ↔ port `OODebugMonitor.cpp:540-542`
- ➖ **low** — `configurationValueForKey:class:defaultValue:` dropped; only its `class:Nil defaultValue:nil` behaviour survives (override unless missing/null, else OXP value; `NSNull` reads as nil) — upstream `OODebugMonitor.m:247` ↔ port `OODebugMonitor.cpp:216`
- ✅ subtle — texture list in `dumpMemoryStatistics`: textures not in the age cache were appended in `NSSet` (hash) order, now in `OOTexture::allTextures()` vector order; output line order may differ — upstream `OODebugMonitor.m:502` ↔ port `OODebugMonitor.cpp:470`
- ✅ subtle — `setConfigurationValue` returns early for an empty key (upstream only for `nil`; `""` was a storable key) — upstream `OODebugMonitor.m:283` ↔ port `OODebugMonitor.cpp:253`
- ✅ subtle — `configurationKeys` uses a stable sort over byte-ordered keys; upstream sorted `NSSet` order with an unstable sort, so keys equal ignoring case may come out in a different order — upstream `OODebugMonitor.m:319` ↔ port `OODebugMonitor.cpp:299`
- ✅ subtle — the "ApplicationWillTerminate" and JS-engine reset observers are on `oo::NotificationCenter` (bead oo-3rb.40); same names, same handlers — upstream `OODebugMonitor.m:102-115` ↔ port `OODebugMonitor.cpp:87-97`


## OODebugStandards

<a id="oodebugstandards"></a>
Upstream `src/Core/Debug/OODebugStandards.m` ↔ `Core/Debug/OODebugStandards.cpp`

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| release-build stubs `OOStandardsDeprecated/Error`, `OOEnforceStandards`, `OOSetStandardsForOXPVerifierMode` (34-37) | same stubs `Core/Debug/OODebugStandards.cpp:38-41` | ✅ |
| `OOStandardsSetup()` (69) | `OOStandardsSetup` `Core/Debug/OODebugStandards.cpp:80` | ✅ |
| `OOStandardsInternal()` (85) | `OOStandardsInternal` (anonymous namespace) `:98` | ✅ |
| `OOStandardsDeprecated()` (100) | `cxx_OOStandardsDeprecated` `:115` | ✅ |
| `OOStandardsError()` (105) | `cxx_OOStandardsError` `:120` | ✅ |
| `OOEnforceStandards()` (110) | `OOEnforceStandards` `:125` | ✅ |
| `OOSetStandardsForOXPVerifierMode()` (116) | `OOSetStandardsForOXPVerifierMode` `:131` | ✅ |

**Differences:**

- ✅ subtle — neither version ever sets `sSetup` in `OOStandardsSetup`, so `enforce-oxp-standards` is re-read on every call until the verifier mode pins it; preserved — upstream `Core/Debug/OODebugStandards.m:69-82` ↔ port `Core/Debug/OODebugStandards.cpp:80-95`
- ✅ subtle — same defaults (`OFF` under `NDEBUG`, else `WARN`), same clamp to `[OFF, QUIT]`, same log classes `oxp-standards.deprecated` / `oxp-standards.error`.


## OODebugSupport

<a id="oodebugsupport"></a>
Upstream `src/Core/Debug/OODebugSupport.m` ↔ `Core/Debug/OODebugSupport.cpp`

**Status:** done — 2 rows: 1 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOInitDebugSupport()` (52) | `OOInitDebugSupport` `Core/Debug/OODebugSupport.cpp:40` | ✅ |
| `LoadDebugPlugIn()` (106) | — (Mac-only; on SDL it was `#define LoadDebugPlugIn() nil`; ADR-0056 amendment oo-9ht.91, comment `:55-57`) | ➖ |

**Differences:**

- ➖ **low** — the plug-in-controller branch (`setUpDebugger`, `setUsingPlugInController:YES`) is gone; on SDL it was dead because `LoadDebugPlugIn()` was `nil` — upstream `Core/Debug/OODebugSupport.m:41,71,77-78` ↔ port `Core/Debug/OODebugSupport.cpp:55-57`
- ✅ subtle — `console-host` keeps `oo_stringForKey` semantics (string, or a number's string value, else nil); `console-port` and `always-load-debug-console` read through `PListGet` (same clamping as `OO*FromObject`) — upstream `OODebugSupport.m:73-74,94` ↔ port `OODebugSupport.cpp:60-64,77`
- ✅ subtle — the TCP client is made by `OODebugTCPConsoleClient::clientWithAddress`, null on failure, as `initWithAddress:port:` answered nil — upstream `OODebugSupport.m:84` ↔ port `OODebugSupport.cpp:69`


## OODebugTCPConsoleClient

<a id="oodebugtcpconsoleclient"></a>
Upstream `src/Core/Debug/OODebugTCPConsoleClient.m` ↔ `Core/Debug/OODebugTCPConsoleClient.cpp`

**Status:** done — 34 rows: 28 ✅ 4 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `StatusIsSendable()` (60) | `StatusIsSendable` `Core/Debug/OODebugTCPConsoleClient.cpp:75` | ✅ |
| `-[OODebugTCPConsoleClient init]` (99) | — (no caller; `clientWithAddress(nullopt, 0)` is the same thing) | ➖ |
| `-[OODebugTCPConsoleClient initWithAddress:port:]` (104) | `clientWithAddress` `:216` + `initWithAddress` `:224` + `openSocketToHost` `:397` | ⚠️ |
| `-[OODebugTCPConsoleClient dealloc]` (175) | `~OODebugTCPConsoleClient` `:279` | ⚠️ |
| `-[OODebugTCPConsoleClient connectDebugMonitor:errorMessage:]` (192) | `connectDebugMonitor` `:296` | ✅ |
| `-[OODebugTCPConsoleClient disconnectDebugMonitor:message:]` (211) | `disconnectDebugMonitor` `:315` | ✅ |
| `-[OODebugTCPConsoleClient debugMonitor:jsConsoleOutput:colorKey:emphasisRange:]` (218) | `debugMonitor(monitor, output, colorKey, range)` `:322` | ✅ |
| `-[OODebugTCPConsoleClient debugMonitorClearConsole:]` (241) | `debugMonitorClearConsole` `:346` | ✅ |
| `-[OODebugTCPConsoleClient debugMonitorShowConsole:]` (247) | `debugMonitorShowConsole` `:352` | ✅ |
| `-[OODebugTCPConsoleClient debugMonitor:noteConfiguration:]` (253) | `debugMonitor(monitor, configuration)` `:358` | ✅ |
| `-[OODebugTCPConsoleClient debugMonitor:noteChangedConfigrationValue:forKey:]` (261) | `debugMonitor(monitor, newValue, key)` `:366` | ✅ |
| `-[OODebugTCPConsoleClient stream:handleEvent:]` (276) | `handleWaitResultRead` `:519`, `handleErrorEvent` `:552`, `OODebugTCPConsoleServiceInput` `:912` | ⚠️ |
| `-[OODebugTCPConsoleClient(OOPrivate) closeConnection]` (295) | `closeConnection` `:383` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) sendBytes:count:]` (311) | `sendBytes` `:584` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) sendDictionary:]` (330) | `sendDictionary` `:620` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) sendPacket:withParameters:]` (398) | `sendPacket(type, parameters)` `:685` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) sendPacket:withValue:forParameter:]` (415) | `sendPacket(type, value, paramKey)` `:698` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) readData]` (430) | `readData` `:712` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) dispatchPacket:ofType:]` (446) | `dispatchPacket` `:731` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleApproveConnectionPacket:]` (472) | `handleApproveConnectionPacket` `:758` | ❌ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleRejectConnectionPacket:]` (499) | `handleRejectConnectionPacket` `:781` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleCloseConnectionPacket:]` (515) | `handleCloseConnectionPacket` `:792` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleNoteConfigurationChangePacket:]` (528) | `handleNoteConfigurationChangePacket` `:800` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handlePerformCommandPacket:]` (554) | `handlePerformCommandPacket` `:825` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handleRequestConfigurationValuePacket:]` (563) | `handleRequestConfigurationValuePacket` `:832` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handlePingPacket:]` (577) | `handlePingPacket` `:843` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) handlePongPacket:]` (587) | `handlePongPacket` `:851` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) disconnectFromServerWithMessage:]` (592) | `disconnectFromServerWithMessage` `:856` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) breakConnectionWithMessage:]` (604) | `breakConnectionWithMessage` `:869` | ✅ |
| `-[OODebugTCPConsoleClient(OOPrivate) breakConnectionWithBadStream:]` (624) | `breakConnectionWithStreamError` `:890` | ⚠️ |
| `DecoderPacket()` (642) | `OODebugTCPConsoleClient::DecoderPacket` `:964` | ✅ |
| `DecoderError()` (647) | `OODebugTCPConsoleClient::DecoderError` `:974` | ✅ |
| `LogOOTCPStreamDecoderPacket()` (653) | `LogOOTCPStreamDecoderPacket` `:982` | ✅ |
| `LogSendPacket()` (663) | `LogSendPacket` `:990` | ✅ |

**Differences:**

- ⚠️ **med** — connect wait: upstream ran the run loop with a 3 s `beforeDate:`; port waits on the socket with no time limit (`OODebugTCPConsoleServiceInput(-1.0)`) until it opens or fails. Port comment says the run-loop wait never honoured the 3 s either (measured 21 s for a silent address); bead oo-3rb.14 / proposed ADR-0041 — upstream `Core/Debug/OODebugTCPConsoleClient.m:137-142` ↔ port `Core/Debug/OODebugTCPConsoleClient.cpp:237-244`
- ⚠️ **low** — `NSStream`/`NSHost` replaced by a non-blocking IPv4 socket (bead oo-3rb.14). An unknown host logs `Host '…' not found …` in class `unclassified` (stands in for GNUstep's own NSLog) and gives no connection, as `hostWithName:` → nil did — upstream `OODebugTCPConsoleClient.m:116-123` ↔ port `OODebugTCPConsoleClient.cpp:397-450`
- ⚠️ **low** — `stream:handleEvent:` is now driven by `select()` in `OODebugTCPConsoleServiceInput` / `handleWaitResultRead`: bytes-available → `readData` (when `_status <= Connected`), error → `breakConnectionWithStreamError`. Same gating; end-of-stream still ignored (upstream's second `ErrorOccurred` branch was dead) — upstream `OODebugTCPConsoleClient.m:276-289` ↔ port `OODebugTCPConsoleClient.cpp:519-558,912-962`
- ⚠️ **low** — `breakConnectionWithBadStream:` text: the error description is the OS text (`FormatMessageW` / `strerror`) where GNUstep gave `[NSError localizedDescription]`; port comment says this was measured to match gnustep-base 1.31. The `debugTCP.disconnect` line's stream-status numbers come from emulated statuses (0/1/2/3/5/7) — upstream `OODebugTCPConsoleClient.m:624-638` ↔ port `OODebugTCPConsoleClient.cpp:82-98,890-901`
- ⚠️ **low** — `-dealloc` no longer tells a still-set `_monitor` to disconnect (could not happen: the monitor retains the client while set; ADR-0056 amendment oo-kq7 item 3) — upstream `OODebugTCPConsoleClient.m:180-182` ↔ port `OODebugTCPConsoleClient.cpp:284-288`
- ❌ **low** — "Connected to debug console … at X": upstream printed `[_host name]` (NSHost's resolved name), port prints the address string as configured. For a numeric `console-host` the upstream could print a resolved host name, and for `127.0.0.1` NSHost may answer the machine name (so upstream could append " at <machine>" where port appends nothing) — upstream `OODebugTCPConsoleClient.m:488-491` ↔ port `OODebugTCPConsoleClient.cpp:770-773`
- ✅ subtle — the `RequestConnection` packet's `OoliteVersion` is read from `<Resources>/Info-gnustep.plist` instead of `[[NSBundle mainBundle] infoDictionary]`; omitted when absent, as the nil-terminated dictionary did — upstream `OODebugTCPConsoleClient.m:152-155` ↔ port `OODebugTCPConsoleClient.cpp:199-211,255-262`
- ✅ subtle — send retries wait 8/16/8 ms by servicing only the console sockets (`serviceSocketFor`), where `runUntilDate:` also ran any other run-loop sources — upstream `OODebugTCPConsoleClient.m:370,374,384` ↔ port `OODebugTCPConsoleClient.cpp:657,661,671`
- ✅ subtle — `handleNoteConfigurationChangePacket` keeps the upstream bug of reading `removed-keys` from the `configuration` dictionary rather than the packet; non-string removed keys are skipped (upstream passed them on); config entries are applied in byte order rather than `NSDictionary` order, so the echoed `NoteConfiguration` packets may come out in a different order — upstream `OODebugTCPConsoleClient.m:539-551` ↔ port `OODebugTCPConsoleClient.cpp:805-822`
- ✅ subtle — wire format: packets are serialised by `oo::writeXMLPList` (ADR-0043 item 15) with the same 4-byte big-endian length header; packet type/parameter keys and the type-only fallback for a nil value are unchanged — upstream `OODebugTCPConsoleClient.m:342-361,406-427` ↔ port `OODebugTCPConsoleClient.cpp:635-648,685-710`


## OOTCPStreamDecoderAbstractionLayer

<a id="ootcpstreamdecoderabstractionlayer"></a>
Upstream `src/Core/Debug/OOTCPStreamDecoderAbstractionLayer.m` ↔ `Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp`

**Status:** done — 14 rows: 12 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOALGetConstantString()` (15) | `OOALGetConstantString` `Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp:63` | ✅ |
| `OOALRelease()` (37) | `OOALRelease` `:80` | ✅ |
| `OOTypeDescription()` (42) | `OOTypeDescription` `:85` | ⚠️ |
| `OOALIsString()` (47) | `OOALIsString` `:98` | ✅ |
| `OOALStringCreateWithFormatAndArguments()` (52) | `OOALStringCreateWithFormatAndArguments` `:103` → `OOTCPStreamDecoderFormat::FormatWithArguments` `Core/Debug/OOTCPStreamDecoderFormat.hpp` | ✅ |
| `OOALIsDictionary()` (57) | `OOALIsDictionary` `:108` | ✅ |
| `OOALDictionaryGetValue()` (62) | `OOALDictionaryGetValue` `:113` | ✅ |
| `OOALIsData()` (67) | `OOALIsData` `:129` | ✅ |
| `OOALDataCreateMutable()` (72) | `OOALDataCreateMutable` `:134` | ✅ |
| `OOALMutableDataAppendBytes()` (77) | `OOALMutableDataAppendBytes` `:140` | ✅ |
| `OOALDataGetBytePtr()` (82) | `OOALDataGetBytePtr` `:145` | ✅ |
| `OOALDataGetLength()` (87) | `OOALDataGetLength` `:150` | ✅ |
| `OOALCreateAutoreleasePool()` (92) | `OOALCreateAutoreleasePool` `:155` (+ `OOALDestroyAutoreleasePool` `:162`, a header macro upstream) | ✅ |
| `OOALPropertyListFromData()` (97) | `OOALPropertyListFromData` `:169` | ❌ |

**Differences:**

- ❌ **low** — on a malformed packet the decoder logs `Protocol error: packet is not property list (property list error: %@)` with the oofnd parser's error text, not GNUstep's `NSPropertyListSerialization` text; the `debugTCP.disconnect` line differs. Binary plists are rejected outright (ADR-0027 item 3), where GNUstep parsed them; the Python console sends XML — upstream `Core/Debug/OOTCPStreamDecoderAbstractionLayer.m:97-110` ↔ port `Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp:169-185`
- ⚠️ **low** — `OOTypeDescription` answers the plist type name (`array`, `string`, …) where upstream answered the GNUstep class name (`GSArray`, `GSCInlineString`…), so `Protocol error: packet is a %@, not a dictionary.` reads differently; documented in the port comment — upstream `OOTCPStreamDecoderAbstractionLayer.m:42-45` ↔ port `OOTCPStreamDecoderAbstractionLayer.cpp:85-96`
- ✅ subtle — the formatter handles only `%u`, `%zu`, `%@`, `%%` (all `OOTCPStreamDecoder.c` uses), pinned by `tests/unit/oofnd/test_tcp_stream_format.cpp` against GNUstep 1.31.1 output — port `OOTCPStreamDecoderFormat.hpp:1-12`
- ✅ subtle — `OOALDictionaryGetValue` only looks up string keys (the decoder's keys are all `OOALSTR` constants); parsed packets belong to the innermost OOAL pool, as the retained/autoreleased objects did — port `OOTCPStreamDecoderAbstractionLayer.cpp:113-127,180-183`


## OOFullScreenController

<a id="oofullscreencontroller"></a>
Upstream `src/Core/OOFullScreenController.m` ↔ `Core/OOFullScreenController.cpp`

**Status:** done — 11 rows: 9 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOFullScreenController initWithGameView:]` (31) | `OOFullScreenController::OOFullScreenController(MyOpenGLView*)` `Core/OOFullScreenController.cpp:29` | ✅ |
| `-[OOFullScreenController dealloc]` (39) | — (the `oo::Ref` member `_gameView` releases the view) | ➖ |
| `-[OOFullScreenController gameView]` (46) | `gameView` `:34` | ✅ |
| `-[OOFullScreenController inFullScreenMode]` (51) | `inFullScreenMode` `:39` | ✅ |
| `-[OOFullScreenController setFullScreenMode:]` (57) | `setFullScreenMode` `:45` | ✅ |
| `-[OOFullScreenController displayModes]` (62) | `displayModes` `:50` | ✅ |
| `-[OOFullScreenController currentDisplayMode]` (68) | `currentDisplayMode` `:56` | ❌ |
| `-[OOFullScreenController indexOfCurrentDisplayMode]` (73) | `indexOfCurrentDisplayMode` `:68` | ✅ |
| `-[OOFullScreenController setDisplayWidth:height:refreshRate:]` (79) | `setDisplayWidth` `:74` | ✅ |
| `-[OOFullScreenController findDisplayModeForWidth:height:refreshRate:]` (85) | `findDisplayModeForWidth` `:80` | ✅ |
| `-[OOFullScreenController noteMouseInteractionModeChangedFrom:to:]` (91) | `noteMouseInteractionModeChangedFrom` `:86` | ✅ |

**Differences:**

- ❌ **low** — `currentDisplayMode` with an out-of-range index (e.g. `NSNotFound` from the abstract base) answers a null mode; upstream `objectAtIndex:` raised `NSRangeException`. The abstract base is never instantiated on SDL (no constructor call outside this file), so unreachable in practice — upstream `Core/OOFullScreenController.m:68-71` ↔ port `Core/OOFullScreenController.cpp:56-66`
- ✅ subtle — the abstract methods still log `OOLogGenericSubclassResponsibility()` and return `NO`/`nil`/`NSNotFound` as before.


## OOJoystickManager

<a id="oojoystickmanager"></a>
Upstream `src/Core/OOJoystickManager.m` ↔ `Core/OOJoystickManager.cpp`

**Status:** done — 33 rows: 31 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOJoystickManager sharedStickHandler]` (49) | `OOJoystickManager::sharedStickHandler` `Core/OOJoystickManager.cpp:45` | ✅ |
| `+[OOJoystickManager setStickHandlerClass:]` (59) | `OOJoystickManager::setStickHandlerFactory` `:55` (a factory function for the class; bead oo-9ht.69) | ✅ |
| `-[OOJoystickManager init]` (68) | `OOJoystickManager::init` `:63` | ✅ |
| `-[OOJoystickManager rollPitchAxis]` (88) | `rollPitchAxis` `:82` | ✅ |
| `-[OOJoystickManager viewAxis]` (93) | `viewAxis` `:87` | ✅ |
| `-[OOJoystickManager getButtonState:]` (98) | `getButtonState` `:92` | ✅ |
| `-[OOJoystickManager getAllButtonStates]` (103) | `getAllButtonStates` `:97` | ✅ |
| `-[OOJoystickManager isButtonDown:stick:]` (108) | `isButtonDown` `:102` | ✅ |
| `-[OOJoystickManager getAxisState:]` (113) | `getAxisState` `:107` | ✅ |
| `-[OOJoystickManager getSensitivity]` (142) | `getSensitivity` `:136` | ✅ |
| `-[OOJoystickManager setProfile:forAxis:]` (147) | `setProfile` `:141` | ✅ |
| `-[OOJoystickManager getProfileForAxis:]` (168) | `getProfileForAxis` `:159` | ✅ |
| `-[OOJoystickManager saveProfileForAxis:]` (181) | `saveProfileForAxis` `:172` | ✅ |
| `-[OOJoystickManager loadProfileForAxis:]` (228) | `loadProfileForAxis` `:220` | ✅ |
| `-[OOJoystickManager listSticks]` (272) | `listSticks` `:264` | ✅ |
| `-[OOJoystickManager axisFunctions]` (283) | `axisFunctions` `:275` | ✅ |
| `-[OOJoystickManager buttonFunctions]` (305) | `buttonFunctions` `:295` | ✅ |
| `-[OOJoystickManager setFunction:withDict:]` (327) | `setFunction` `:315` | ✅ |
| `-[OOJoystickManager setFunctionForAxis:function:stick:]` (344) | `setFunctionForAxis` `:332` | ✅ |
| `-[OOJoystickManager setFunctionForButton:function:stick:]` (364) | `setFunctionForButton` `:352` | ✅ |
| `-[OOJoystickManager unsetAxisFunction:]` (382) | `unsetAxisFunction` `:370` | ✅ |
| `-[OOJoystickManager unsetButtonFunction:]` (396) | `unsetButtonFunction` `:384` | ✅ |
| `-[OOJoystickManager setDefaultMapping]` (409) | `setDefaultMapping` `:397` | ✅ |
| `-[OOJoystickManager clearMappings]` (420) | `clearMappings` `:408` | ✅ |
| `-[OOJoystickManager clearStickStates]` (426) | `clearStickStates` `:414` | ✅ |
| `-[OOJoystickManager clearStickButtonState:]` (442) | `clearStickButtonState` `:430` | ✅ |
| `-[OOJoystickManager setCallback:object:hardware:]` (449) | `setCallback(StickCallback, hwflags)` `:437` | ⚠️ |
| `-[OOJoystickManager clearCallback]` (458) | `clearCallback` `:444` | ✅ |
| `-[OOJoystickManager saveStickSettings]` (464) | `saveStickSettings` `:575` | ✅ |
| `-[OOJoystickManager loadStickSettings]` (478) | `loadStickSettings` `:587` | ⚠️ |
| `-[OOJoystickManager joystickCount]` (510) | `joystickCount` `:570` | ✅ |
| `-[OOJoystickManager nameOfJoystick:]` (515) | `nameOfJoystick` `:621` | ✅ |
| `-[OOJoystickManager getAxisWithStick:axis:]` (520) | `getAxisWithStick` `:626` | ✅ |

**Differences:**

- ⚠️ **low** — `loadStickSettings` visits `JoystickAxes`/`JoystickButs` keys in byte order instead of `NSDictionary` order; when two functions claim the same stick axis/button, which one wins can differ (proposed ADR-0043, comment) — upstream `Core/OOJoystickManager.m:485-500` ↔ port `Core/OOJoystickManager.cpp:593-609`
- ⚠️ **low** — the axis/button-capture callback is a `std::function` instead of an unretained object + selector; it is still copied out, `cbHardware` cleared before the call and the callback cleared after it, so a callback that re-arms is still cancelled, as before (header comment "was a nil object") — upstream `OOJoystickManager.m:449-462`, `SDL/OOSDLJoystickManager.m:137-142` ↔ port `OOJoystickManager.cpp:437-448,457-468`
- ✅ subtle — the decode functions (`decodeAxisEvent`/`ButtonEvent`/`HatEvent`) now live here rather than in `OOSDLJoystickManager`; constants are unchanged: thrust `(65536 - (v + 32768)) / 65536`, roll/pitch/yaw/view `v / 32768` (`STICK_NORMALDIV`), other axes `v / 32768`, pitch inverted after, callback threshold `AXCBTHRESH` 20000, hats as buttons `MAX_REAL_BUTTONS + i + which*4` (upstream's ignoring of the hat index kept) — port `OOJoystickManager.cpp:450-568`
- ✅ subtle — dead zone and curves (`getAxisState` → profile `value`) unchanged: `STICK_DEADZONE` 0.05, max 0.1, precision divide by `STICK_PRECISIONFAC` 3; a missing profile answers 0 as nil messaging did — upstream `OOJoystickManager.m:113-140` ↔ port `OOJoystickManager.cpp:107-134`
- ✅ subtle — malformed stick defaults (a non-dictionary profile, a non-array control point, a non-dictionary function entry) are skipped; upstream would have raised on the unrecognised selector. Likewise a nameless stick lists as `""` in `listSticks` where `addObject:nil` raised — upstream `OOJoystickManager.m:245-269,278` ↔ port `OOJoystickManager.cpp:237-261,270`


## OOJoystickProfile

<a id="oojoystickprofile"></a>
Upstream `src/Core/OOJoystickProfile.m` ↔ `Core/OOJoystickProfile.cpp`

**Status:** done — 40 rows: 40 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOJoystickAxisProfile init]` (84) | `OOJoystickAxisProfile::OOJoystickAxisProfile` `Core/OOJoystickProfile.cpp:68` | ✅ |
| `-[OOJoystickAxisProfile copyWithZone:]` (92) | `OOJoystickAxisProfile::copy` `:73` | ✅ |
| `-[OOJoystickAxisProfile rawValue:]` (98) | `OOJoystickAxisProfile::rawValue` `:80` | ✅ |
| `-[OOJoystickAxisProfile value:]` (103) | `OOJoystickAxisProfile::value` `:85` | ✅ |
| `-[OOJoystickAxisProfile deadzone]` (111) | `deadzone` `:93` | ✅ |
| `-[OOJoystickAxisProfile setDeadzone:]` (116) | `setDeadzone` `:98` | ✅ |
| `-[OOJoystickStandardAxisProfile init]` (125) | `OOJoystickStandardAxisProfile::OOJoystickStandardAxisProfile` `:103` | ✅ |
| `-[OOJoystickStandardAxisProfile copyWithZone:]` (134) | `OOJoystickStandardAxisProfile::copy` `:109` | ✅ |
| `-[OOJoystickStandardAxisProfile setPower:]` (142) | `setPower` `:117` | ✅ |
| `-[OOJoystickStandardAxisProfile power]` (154) | `power` `:129` | ✅ |
| `-[OOJoystickStandardAxisProfile setParameter:]` (159) | `setParameter` `:134` | ✅ |
| `-[OOJoystickStandardAxisProfile parameter]` (165) | `parameter` `:140` | ✅ |
| `-[OOJoystickStandardAxisProfile rawValue:]` (170) | `OOJoystickStandardAxisProfile::rawValue` `:145` | ✅ |
| `-[OOJoystickSplineSegment init]` (182) | `OOJoystickSplineSegment::OOJoystickSplineSegment` `:153` | ✅ |
| `-[OOJoystickSplineSegment copyWithZone:]` (195) | `OOJoystickSplineSegment::copy` `:163` | ✅ |
| `-[OOJoystickSplineSegment initWithData:right:]` (207) | `initWithData(left, right)` `:179` | ✅ |
| `-[OOJoystickSplineSegment initWithData:right:gradientleft:]` (224) | `initWithData(left, right, gl)` `:194` | ✅ |
| `-[OOJoystickSplineSegment initWithData:right:gradientright:]` (240) | `initWithDataGradientRight` `:208` | ✅ |
| `-[OOJoystickSplineSegment initWithData:right:gradientleft:gradientright:]` (256) | `initWithData(left, right, gl, gr)` `:222` | ✅ |
| `+[OOJoystickSplineSegment segmentWithData:right:]` (273) | `segmentWithData(left, right)` `:237` | ✅ |
| `+[OOJoystickSplineSegment segmentWithData:right:gradientleft:]` (279) | `segmentWithData(left, right, gl)` `:245` | ✅ |
| `+[OOJoystickSplineSegment segmentWithData:right:gradientright:]` (285) | `segmentWithDataGradientRight` `:253` | ✅ |
| `+[OOJoystickSplineSegment segmentWithData:right:gradientleft:gradientright:]` (291) | `segmentWithData(left, right, gl, gr)` `:261` | ✅ |
| `-[OOJoystickSplineSegment start]` (297) | `start` `:269` | ✅ |
| `-[OOJoystickSplineSegment end]` (302) | `end` `:274` | ✅ |
| `-[OOJoystickSplineSegment value:]` (307) | `OOJoystickSplineSegment::value` `:279` | ✅ |
| `-[OOJoystickSplineSegment gradient:]` (312) | `OOJoystickSplineSegment::gradient` `:284` | ✅ |
| `-[OOJoystickSplineAxisProfile init]` (321) | `OOJoystickSplineAxisProfile::OOJoystickSplineAxisProfile` `:289` | ✅ |
| `-[OOJoystickSplineAxisProfile dealloc]` (331) | `~OOJoystickSplineAxisProfile` `:296` | ✅ |
| `-[OOJoystickSplineAxisProfile copyWithZone:]` (339) | `OOJoystickSplineAxisProfile::copy` `:301` | ✅ |
| `-[OOJoystickSplineAxisProfile addControl:]` (347) | `addControl` `:309` | ✅ |
| `-[OOJoystickSplineAxisProfile pointAtIndex:]` (382) | `pointAtIndex` `:344` | ✅ |
| `-[OOJoystickSplineAxisProfile countPoints]` (397) | `countPoints` `:359` | ✅ |
| `-[OOJoystickSplineAxisProfile controlPoints]` (402) | `controlPoints` `:364` | ✅ |
| `-[OOJoystickSplineAxisProfile makeSegments]` (408) | `makeSegments` `:370` | ✅ |
| `-[OOJoystickSplineAxisProfile removeControl:]` (461) | `removeControl` `:423` | ✅ |
| `-[OOJoystickSplineAxisProfile clearControlPoints]` (470) | `clearControlPoints` `:432` | ✅ |
| `-[OOJoystickSplineAxisProfile moveControl:point:]` (476) | `moveControl` `:438` | ✅ |
| `-[OOJoystickSplineAxisProfile rawValue:]` (515) | `OOJoystickSplineAxisProfile::rawValue` `:477` | ✅ |
| `-[OOJoystickSplineAxisProfile gradient:]` (536) | `OOJoystickSplineAxisProfile::gradient` `:498` | ✅ |

**Differences:**

- ✅ subtle — dead zone and curve maths are verbatim: `value` zeroes `|x| < deadzone` and rescales by `(|x| - dz) / (1 - dz)`; `setDeadzone` clamps to `[0, STICK_MAX_DEADZONE]`; standard curve `clamp01(p·|x|^power − (p−1)·|x|)`, `power` clamped to `[1, STICKPROFILE_MAX_POWER]`, parameter to `[0, 1]`; spline coefficients, `SPLINE_POINT_MIN_SPACING` 0.02 and segment search (`end > x`) identical — upstream `Core/OOJoystickProfile.m:103-176,207-271,515-547` ↔ port `Core/OOJoystickProfile.cpp:85-151,179-235,477-509`
- ✅ subtle — every `copy` still leaves `deadzone` at the default (`[[[self class] alloc] init]` never copied it). The spline copy now holds a mutable control-point list; upstream's `copyWithZone:` stored an immutable `NSArray`, so editing a copy would have raised. No caller copies a profile — upstream `OOJoystickProfile.m:92-96,339-345` ↔ port `OOJoystickProfile.cpp:73-78,301-307`
- ✅ subtle — the failable `-initWithData:…` became `bool` initialisers run after the default constructor; port comment `:175-178` explains why the resulting segment is identical (`a[3]` stays 0 on the quadratic paths).


## GameController+SDLFullScreen

<a id="gamecontrollersdlfullscreen"></a>
Upstream `src/SDL/GameController+SDLFullScreen.m` ↔ `SDL/GameController+SDLFullScreen.cpp`

**Status:** done — 9 rows: 8 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[GameController(FullScreen) setUpDisplayModes]` (38) | `GameController::setUpDisplayModes` `SDL/GameController+SDLFullScreen.cpp:59` | ✅ |
| `-[GameController(FullScreen) setFullScreenMode:]` (69) | `GameController::setFullScreenMode` `:87` | ✅ |
| `-[GameController(FullScreen) exitFullScreenMode]` (74) | `GameController::exitFullScreenMode` `:92` | ✅ |
| `-[GameController(FullScreen) inFullScreenMode]` (80) | `GameController::inFullScreenMode` `:98` | ✅ |
| `-[GameController(FullScreen) setDisplayWidth:Height:Refresh:]` (85) | `GameController::setDisplayWidth` `:103` | ✅ |
| `-[GameController(FullScreen) findDisplayModeForWidth:Height:Refresh:]` (108) | `GameController::findDisplayModeForWidth` `:126` → `FindDisplayMode` `:39` | ✅ |
| `-[GameController(FullScreen) displayModes]` (128) | `GameController::getDisplayModes` `:132` | ✅ |
| `-[GameController(FullScreen) indexOfCurrentDisplayMode]` (133) | `GameController::indexOfCurrentDisplayMode` `:137` | ✅ |
| `-[GameController(FullScreen) pauseFullScreenModeToPerform:onTarget:]` (146) | `GameController::pauseFullScreenModeToPerform` `:148` | ⚠️ |

**Differences:**

- ⚠️ **low** — `pauseFullScreenModeToPerform` stores the selector by name (`const char*`, bead oo-xu228.3) and the target as `oo::RefCounted*`; same state changes (`stayInFullScreenMode = NO`) — upstream `SDL/GameController+SDLFullScreen.m:146-151` ↔ port `SDL/GameController+SDLFullScreen.cpp:148-153`
- ✅ subtle — display-mode filter bounds (`DISPLAY_MIN/MAX_WIDTH/HEIGHT`), mode matching (width, height and integer refresh all equal), and the `display_width` / `display_height` / `display_refresh` defaults written plus `synchronize` are unchanged. `indexOfCurrentDisplayMode` returns the first match's position, which is what `indexOfObject:` of that first match gave — upstream `GameController+SDLFullScreen.m:38-143` ↔ port `GameController+SDLFullScreen.cpp:39-146`
- ✅ subtle — a null `_gameView` reads as nil messaging did (empty mode list, size 0×0, `inFullScreenMode` NO).


## MyOpenGLView+Input

<a id="myopenglviewinput"></a>
Upstream `src/SDL/MyOpenGLView+Input.m` ↔ `SDL/MyOpenGLView+Input.cpp`

**Status:** done — 34 rows: 33 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[MyOpenGLView(Input) initKeyMappingData]` (30) | `MyOpenGLView::initKeyMappingData` `SDL/MyOpenGLView+Input.cpp:39` | ✅ |
| `-[MyOpenGLView(Input) autoShowMouse]` (48) | `autoShowMouse` `:57` | ✅ |
| `-[MyOpenGLView(Input) setStringInput:]` (59) | `setStringInput` `:68` | ✅ |
| `-[MyOpenGLView(Input) allowStringInput:]` (63) | `allowStringInput` `:72` | ✅ |
| `-[MyOpenGLView(Input) allowingStringInput]` (70) | `getAllowingStringInput` `:79` | ✅ |
| `-[MyOpenGLView(Input) typedString]` (74) | `getTypedString` `:83` | ✅ |
| `-[MyOpenGLView(Input) resetTypedString]` (78) | `resetTypedString` `:87` | ✅ |
| `-[MyOpenGLView(Input) setTypedString:]` (82) | `setTypedString` `:91` | ✅ |
| `-[MyOpenGLView(Input) noteMouseInteractionModeChangedFrom:to:]` (86) | `noteMouseInteractionModeChangedFrom` `:95` | ✅ |
| `-[MyOpenGLView(Input) setVirtualJoystick:vmy:]` (91) | `setVirtualJoystick` `:100` | ✅ |
| `-[MyOpenGLView(Input) virtualJoystickPosition]` (96) | `getVirtualJoystickPosition` `:105` | ✅ |
| `-[MyOpenGLView(Input) clearKeys]` (102) | `clearKeys` `:111` | ✅ |
| `-[MyOpenGLView(Input) clearMouse]` (109) | `clearMouse` `:118` | ✅ |
| `-[MyOpenGLView(Input) clearKey:]` (115) | `clearKey` `:124` | ✅ |
| `-[MyOpenGLView(Input) resetMouse]` (121) | `resetMouse` `:130` | ✅ |
| `-[MyOpenGLView(Input) isAlphabetKeyDown]` (129) | `getIsAlphabetKeyDown` `:138` | ✅ |
| `-[MyOpenGLView(Input) suppressKeysUntilKeyUp]` (139) | `suppressKeysUntilKeyUp` `:148` | ✅ |
| `-[MyOpenGLView(Input) isDown:]` (148) | `isDown` `:157` | ✅ |
| `-[MyOpenGLView(Input) isOptDown]` (158) | `isOptDown` `:167` | ✅ |
| `-[MyOpenGLView(Input) isCtrlDown]` (162) | `isCtrlDown` `:171` | ✅ |
| `-[MyOpenGLView(Input) isCommandDown]` (166) | `isCommandDown` `:175` | ✅ |
| `-[MyOpenGLView(Input) isShiftDown]` (170) | `isShiftDown` `:179` | ✅ |
| `-[MyOpenGLView(Input) isCapsLockOn]` (174) | `isCapsLockOn` `:183` | ✅ |
| `-[MyOpenGLView(Input) lastKeyWasShifted]` (184) | `lastKeyWasShifted` `:193` | ✅ |
| `-[MyOpenGLView(Input) numKeys]` (188) | `numKeys` `:197` | ✅ |
| `-[MyOpenGLView(Input) mouseWheelState]` (192) | `mouseWheelState` `:201` | ✅ |
| `-[MyOpenGLView(Input) mouseWheelDelta]` (201) | `mouseWheelDelta` `:210` | ✅ |
| `-[MyOpenGLView(Input) setMouseWheelDelta:]` (205) | `setMouseWheelDelta` `:214` | ✅ |
| `-[MyOpenGLView(Input) isCommandQDown]` (209) | `isCommandQDown` `:218` | ✅ |
| `-[MyOpenGLView(Input) isCommandFDown]` (213) | `isCommandFDown` `:222` | ✅ |
| `-[MyOpenGLView(Input) clearCommandF]` (217) | `clearCommandF` `:226` | ✅ |
| `-[MyOpenGLView(Input) pollControls]` (221) | `pollControls` `:230` | ❌ |
| `-[MyOpenGLView(Input) handleStringInput:keyID:]` (850) | `handleStringInput` `:874` | ✅ |
| `-[MyOpenGLView(Input) setMouseInDeltaMode:]` (885) | `setMouseInDeltaMode` `:911` | ✅ |

**Differences:**

- ℹ️ *Coordinator note:* upstream `key_id <= [self numKeys]` wrote `keys[327]` past the end of `BOOL keys[NUM_KEYS=327]` (`MyOpenGLView.h:166`), which is undefined behaviour that clobbered the next ivar. The port's `<` removes the overflow. Nothing in either tree reads key 327, so the only observable change is the extra `keys.test` log line per F12 press. Treat this as a bug fix, not a regression.

- ❌ **low** — key-array bound tightened from `key_id <= NUM_KEYS` to `< NUM_KEYS` on key-down and key-up, with no cited bead. `NUM_KEYS` is 327 and F12 maps to key 327, so every F12 press now logs `keys.test` "Unhandled Keydown scancode/unicode: … 327" (class not in `logcontrol.plist`, so on via `_default = yes`) where upstream logged nothing and wrote `keys[327]` (one past the end; `isDown:` could never read it). F12's full-screen toggle is unaffected — upstream `SDL/MyOpenGLView+Input.m:615,798` ↔ port `SDL/MyOpenGLView+Input.cpp:636,819`
- ⚠️ **low** — double-click timing uses the button-up event's SDL timestamp (`timestamp / 1e9`) instead of the `timeNow` sampled once per poll, and `timeIntervalAtLastClick` starts on `SDL_GetTicksNS()`; this fixes double-clicks split by a stalled poll (bugs oo-3rb.333 / oo-3rb.336). Mouse-wheel timing uses `oo::date::monotonicSeconds()` in both `init` and `pollControls` — upstream `MyOpenGLView+Input.m:231,272-273` ↔ port `MyOpenGLView+Input.cpp:240,281-290`
- ✅ subtle — key translation tables identical case for case: keypad 0-9 / `.` `/` `*` `-` `+` `=` map to `gvNumberPadKey*` unless string input is on (then ASCII `'0'`…`'9'`, 46, 47, 42, 45, 43, 61), KP-Enter → `gvNumberPadKeyEnter`, Home/End/Insert/PgUp/PgDn/arrows/Pause/Backspace/Delete/F1-F11 → their `gv*` codes, F12 → 327 + `toggleScreenMode`, Space 32, Return 13, Tab 9, Esc 27 (Shift-Esc destroys the window and exits). Ctrl+letter control codes 1-26 → +64 with shift, +96 without; caps-lock branch the same; `scancode2Unicode[55] = gvPrintScreenKey` preload kept — upstream `MyOpenGLView+Input.m:369-620,656-796` ↔ port `MyOpenGLView+Input.cpp:387-641,677-817`
- ✅ subtle — modifiers: key-down sets `shift/ctrl/opt` from `SDL_KMOD_SHIFT/CTRL/ALT`, key-up from the event mod then clears the released side; modifier keys skip string input; `isCapsLockOn` tests `SDL_KMOD_CAPS`; `pollShiftKey` unchanged — upstream `MyOpenGLView+Input.m:379-381,627-651` ↔ port `MyOpenGLView+Input.cpp:399-401,648-672`
- ✅ subtle — mouse scaling identical: delta mode divides `SDL_GetRelativeMouseState` deltas by `viewSize × mouse-flight-sensitivity` (clamped [0.005, 1], default 0.95) and reverts a step past `MOUSEX/Y_MAXIMUM`; absolute mode divides by `w·MAIN_GUI_PIXEL_WIDTH/display_z` and `h` when `display_z > 640`, else by `MAIN_GUI_PIXEL_WIDTH·w/640` and `MAIN_GUI_PIXEL_HEIGHT·w/640`; warp events skipped via `mouseWarped` — upstream `MyOpenGLView+Input.m:317-366` ↔ port `MyOpenGLView+Input.cpp:335-384`
- ✅ subtle — typed-string length counts UTF-16 units (cap 40) and `%c` of 32..255 appends the Latin-1 character as UTF-8, as `NSMutableString` did (bead oo-3rb.113) — upstream `MyOpenGLView+Input.m:855-883` ↔ port `MyOpenGLView+Input.cpp:880-909`
- ✅ subtle — `scancode2Unicode[scan_code]` is indexed by raw scancode with no bound check in both (array size `NUM_KEYS` 327; SDL scancodes can exceed it) — upstream `MyOpenGLView+Input.m:607,632` ↔ port `MyOpenGLView+Input.cpp:628,653`


## MyOpenGLView

<a id="myopenglview"></a>
Upstream `src/SDL/MyOpenGLView.m` ↔ `SDL/MyOpenGLView.cpp`

**Status:** done — 65 rows: 62 ✅ 2 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[MyOpenGLView getDisplayId]` (59) | `MyOpenGLView::getDisplayId` `SDL/MyOpenGLView.cpp:91` | ✅ |
| `-[MyOpenGLView getNativeSize]` (77) | `getNativeSize` `:109` | ✅ |
| `-[MyOpenGLView getWindowCaption]` (100) | `getWindowCaption` `:132` | ✅ |
| `-[MyOpenGLView createWindowWithSize:]` (106) | `createWindowWithSize` `:137` | ❌ |
| `-[MyOpenGLView init]` (275) | `init` `:308` | ⚠️ |
| `-[MyOpenGLView endSplashScreen]` (393) | `endSplashScreen` `:423` | ✅ |
| `-[MyOpenGLView updateGLSize:]` (445) | `updateGLSize` `:476` | ✅ |
| `-[MyOpenGLView setUpBasicOpenGLStateWithSize]` (468) | `setUpBasicOpenGLStateWithSize` `:499` | ✅ |
| `-[MyOpenGLView initialiseGLWithSize:]` (505) | `initialiseGLWithSize` `:537` | ✅ |
| `-[MyOpenGLView dealloc]` (553) | `~MyOpenGLView` `:580` (members release themselves; `matrixManager` still after `SDL_Quit`) | ✅ |
| `-[MyOpenGLView bounds]` (584) | `getBounds` `:724` | ✅ |
| `-[MyOpenGLView viewSize]` (589) | `getViewSize` `:729` | ✅ |
| `-[MyOpenGLView backingViewSize]` (594) | `backingViewSize` `:734` | ✅ |
| `-[MyOpenGLView display_z]` (599) | `getDisplay_z` `:739` | ✅ |
| `-[MyOpenGLView x_offset]` (604) | `getX_offset` `:744` | ✅ |
| `-[MyOpenGLView y_offset]` (609) | `getY_offset` `:749` | ✅ |
| `-[MyOpenGLView gameController]` (614) | `getGameController` `:754` | ✅ |
| `-[MyOpenGLView setGameController:]` (619) | `setGameController` `:759` | ✅ |
| `-[MyOpenGLView inFullScreenMode]` (624) | `inFullScreenMode` `:764` | ✅ |
| `-[MyOpenGLView setFullScreenMode:]` (630) | `setFullScreenMode` `:770` | ✅ |
| `-[MyOpenGLView toggleScreenMode]` (641) | `toggleScreenMode` `:779` | ✅ |
| `-[MyOpenGLView setDisplayMode:fullScreen:]` (656) | `setDisplayMode` `:794` | ✅ |
| `-[MyOpenGLView setScreenSize:]` (664) | `setScreenSize` `:802` | ✅ |
| `-[MyOpenGLView getScreenSizeArray]` (671) | `getScreenSizeArray` `:809` (returns a copy) | ✅ |
| `-[MyOpenGLView modeAsSize:]` (676) | `modeAsSize` `:814` | ✅ |
| `-[MyOpenGLView updateScreen]` (685) | `updateScreen` `:595` | ✅ |
| `-[MyOpenGLView initSplashScreen]` (697) | `initSplashScreen` `:608` | ✅ |
| `-[MyOpenGLView getDisplayDimensions:height:]` (810) | `getDisplayDimensions` `:823` | ✅ |
| `-[MyOpenGLView isRunningOnPrimaryDisplayDevice]` (823) | `isRunningOnPrimaryDisplayDevice` `:836` | ✅ |
| `-[MyOpenGLView grabMouseInsideGameWindow:]` (835) | `grabMouseInsideGameWindow` `:848` | ✅ |
| `-[MyOpenGLView stringToClipboard:]` (841) | `stringToClipboard` `:854` | ✅ |
| `-[MyOpenGLView atDesktopResolution]` (853) | `getAtDesktopResolution` `:866` | ✅ |
| `-[MyOpenGLView hdrOutput]` (858) | `hdrOutput` (Windows) `:871` | ✅ |
| `-[MyOpenGLView isOutputDisplayHDREnabled]` (863) | `isOutputDisplayHDREnabled` (Windows) `:876` | ✅ |
| `-[MyOpenGLView hdrMaxBrightness]` (881) | `hdrMaxBrightness` `:894` | ✅ |
| `-[MyOpenGLView setHDRMaxBrightness:]` (886) | `setHDRMaxBrightness` `:899` | ✅ |
| `-[MyOpenGLView hdrPaperWhiteBrightness]` (897) | `hdrPaperWhiteBrightness` `:910` | ✅ |
| `-[MyOpenGLView setHDRPaperWhiteBrightness:]` (902) | `setHDRPaperWhiteBrightness` `:915` | ✅ |
| `-[MyOpenGLView hdrToneMapper]` (913) | `hdrToneMapper` `:926` | ✅ |
| `-[MyOpenGLView setHDRToneMapper:]` (918) | `setHDRToneMapper` `:931` | ✅ |
| `-[MyOpenGLView hdrOutput]` (929) | `hdrOutput` (Linux stub) `:942` | ✅ |
| `-[MyOpenGLView isOutputDisplayHDREnabled]` (934) | `isOutputDisplayHDREnabled` (Linux stub) `:947` | ✅ |
| `-[MyOpenGLView sdrToneMapper]` (941) | `sdrToneMapper` `:954` | ✅ |
| `-[MyOpenGLView setSDRToneMapper:]` (946) | `setSDRToneMapper` `:959` | ✅ |
| `-[MyOpenGLView colorSaturation]` (955) | `colorSaturation` `:968` | ✅ |
| `-[MyOpenGLView adjustColorSaturation:]` (960) | `adjustColorSaturation` `:973` | ✅ |
| `-[MyOpenGLView snapShot:]` (966) | `snapShot` `:1149` | ✅ |
| `-[MyOpenGLView populateFullScreenModelist]` (1077) | `populateFullScreenModelist` `:980` (+ `SameMode` `:73`) | ✅ |
| `-[MyOpenGLView saveWindowSize:]` (1115) | `saveWindowSize` `:1014` | ✅ |
| `-[MyOpenGLView loadWindowSize]` (1123) | `loadWindowSize` `:1022` | ✅ |
| `-[MyOpenGLView loadFullscreenSettings]` (1137) | `loadFullscreenSettings` `:1036` | ✅ |
| `-[MyOpenGLView findDisplayModeForWidth:Height:Refresh:]` (1172) | `indexOfDisplayModeForWidth` `:1071` | ✅ |
| `-[MyOpenGLView currentScreenSize]` (1196) | `currentScreenSize` `:1094` | ✅ |
| `-[MyOpenGLView currentScreenMode]` (1208) | `currentScreenMode` `:1106` | ✅ |
| `-[MyOpenGLView setFov:fromFraction:]` (1214) | `setFov` `:1111` | ✅ |
| `-[MyOpenGLView fov:]` (1219) | `fov` `:1116` | ✅ |
| `-[MyOpenGLView msaa]` (1224) | `msaa` `:1121` | ✅ |
| `-[MyOpenGLView setMsaa:]` (1229) | `setMsaa` `:1126` | ✅ |
| `-[MyOpenGLView getOpenGLMatrixManager]` (1234) | `getOpenGLMatrixManager` `:1131` | ✅ |
| `+[MyOpenGLView pollShiftKey]` (1239) | `pollShiftKey` `:1136` | ✅ |
| `-[MyOpenGLView dumpRGBAToFileNamed:…]` (1251) | `dumpRGBAToFileNamed` `:1270` | ✅ |
| `-[MyOpenGLView dumpRGBToFileNamed:…]` (1269) | `dumpRGBToFileNamed` `:1284` | ✅ |
| `-[MyOpenGLView dumpGrayToFileNamed:…]` (1287) | `dumpGrayToFileNamed` `:1298` | ✅ |
| `-[MyOpenGLView dumpGrayAlphaToFileNamed:…]` (1315) | `dumpGrayAlphaToFileNamed` `:1322` | ⚠️ |
| `-[MyOpenGLView dumpRGBAToRGBFileNamed:andGrayFileNamed:…]` (1343) | `dumpRGBAToRGBFileNamed` `:1346` | ✅ |

**Differences:**

- ✅ **line-count check** — port is 1387 lines vs upstream 1397; every method has a counterpart and the bodies are line-for-line transcriptions. The gap is the dropped `release` calls in `-dealloc` (now member destructors), the `adjustColorSaturation:` stray `;`, and explicit-retain idioms; no behaviour was dropped.
- ❌ **low** — window icon path: upstream loads `Images/WMicon.bmp` from `[[NSBundle mainBundle] resourcePath]` (GNUstep: `<executable dir>/Resources`), port from `ResourcePaths::builtInResourcesDirectory()` (`<cwd>/Resources`, else `<cwd>/../share/oolite/Resources`). Same file when cwd is the executable's directory (main chdirs there on Windows and Linux); differs if the chdir fails or the install uses the `share/` layout — upstream `SDL/MyOpenGLView.m:213-214` ↔ port `SDL/MyOpenGLView.cpp:245-246`
- ⚠️ **low** — `init` failure (SDL_Init fails): returns `false` and the caller releases the view and nulls `_gameView` (ADR-0056 amendment oo-9ht.153 item 2), where upstream `[self dealloc]; return nil` left `GameController`'s `gameView` dangling — upstream `MyOpenGLView.m:338-342`, `Core/GameController.m:304-307` ↔ port `MyOpenGLView.cpp:368-371`, `Core/GameController.cpp:650-658`
- ⚠️ **low** — `init` starts `timeIntervalAtLastClick` on `SDL_GetTicksNS()` and `timeSinceLastMouseWheel` on the monotonic clock, to match the event-timestamp double-click fix in `pollControls` (bugs oo-3rb.333/336) — upstream `MyOpenGLView.m:386` ↔ port `MyOpenGLView.cpp:415-416`
- ⚠️ **low** — `dumpGrayAlphaToFileNamed` writes into its own `SDL_CreateSurface` instead of a surface wrapped around the caller's 2-byte-per-pixel buffer (upstream overran the caller's buffer); bead oo-5thb0. Debug-only (`#ifndef NDEBUG`) — upstream `MyOpenGLView.m:1328` ↔ port `MyOpenGLView.cpp:1331`
- ✅ subtle — snapshot naming unchanged: cwd switched to `OO_SNAPSHOTSDIR` or `~/oolite-saves/snapshots` (created recursively, same two log lines on failure), `<name>.png` or `oolite-NNN.png` (`%03d`, static counter kept across calls when no name is given; a named shot that exists gets `-NNN` appended, and the "already exists" log still doubles the extension); HDR copy replaces `.png` with `hdr-snapshot-format` (default kept, leading dot optional). One edge: an empty `hdr-snapshot-format` falls back to the default where upstream's `substringToIndex:1` raised — upstream `MyOpenGLView.m:966-1074`, `Core/NSFileManagerOOExtensions.m:187-211` ↔ port `MyOpenGLView.cpp:1149-1267`
- ✅ subtle — resolution enumeration unchanged: slot 0 is the native usable bounds (refresh 0, 1024×768 fallback), then SDL full-screen modes with refresh stored as a single-precision real, de-duplicated by value equality (`SameMode` stands in for `-[NSDictionary isEqual:]`); mode lookup compares width, height and integer refresh. The "Found mode" / "Contents of list" logs print through `oo::DescriptionOf` — upstream `MyOpenGLView.m:1077-1194` ↔ port `MyOpenGLView.cpp:980-1092`
- ✅ subtle — full-screen toggling (`setFullScreenMode` writes `fullscreen` and synchronises; `toggleScreenMode` re-inits at the mode size or saved window size, Linux re-centres; F12 calls it from `pollControls`) and the `-fullscreen`/`-windowed` (last wins), `-nosplash`/`--nosplash` (beats `-splash`), `-novsync`/`--novsync` and `-hdr` argument scans are verbatim; the `GNUSTEP_BASE_LIBRARY` guard is still defined by `src/meson/meson.build:28` — upstream `MyOpenGLView.m:302-319,630-683,1158-1163` ↔ port `MyOpenGLView.cpp:331-349,769-821,1057-1062`


## OOSDLJoystickManager

<a id="oosdljoystickmanager"></a>
Upstream `src/SDL/OOSDLJoystickManager.m` ↔ `SDL/OOSDLJoystickManager.cpp`

**Status:** done — 13 rows: 11 ✅ 1 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSDLJoystickManager init]` (33) | `OOSDLJoystickManager::OOSDLJoystickManager` `SDL/OOSDLJoystickManager.cpp:30`, then `OOJoystickManager::init` from `sharedStickHandler` | ✅ |
| `-[OOSDLJoystickManager dealloc]` (67) | — (`joystickIdMap` is a `std::map` member) | ➖ |
| `-[OOSDLJoystickManager getJoystickIndexFromId:]` (73) | `getJoystickIndexFromId` `:63` | ✅ |
| `-[OOSDLJoystickManager joystickCount]` (82) | `joystickCount` `:147` | ✅ |
| `-[OOSDLJoystickManager nameOfJoystick:]` (87) | `nameOfJoystick` `:152` | ✅ |
| `-[OOSDLJoystickManager getAxisWithStick:axis:]` (94) | `getAxisWithStick` `:162` | ✅ |
| `-[OOSDLJoystickManager makeJoyAxisEvent:]` (99) | `makeJoyAxisEvent` `:72` | ✅ |
| `-[OOSDLJoystickManager makeJoyButtonEvent:]` (109) | `makeJoyButtonEvent` `:82` | ✅ |
| `-[OOSDLJoystickManager makeJoyHatEvent:]` (119) | `makeJoyHatEvent` `:92` | ✅ |
| `-[OOSDLJoystickManager decodeAxisEvent:]` (129) | `OOJoystickManager::decodeAxisEvent` `Core/OOJoystickManager.cpp:450` | ✅ |
| `-[OOSDLJoystickManager decodeButtonEvent:]` (191) | `OOJoystickManager::decodeButtonEvent` `Core/OOJoystickManager.cpp:512` | ✅ |
| `-[OOSDLJoystickManager decodeHatEvent:]` (229) | `OOJoystickManager::decodeHatEvent` `Core/OOJoystickManager.cpp:550` | ✅ |
| `-[OOSDLJoystickManager handleSDLEvent:]` (249) | `handleSDLEvent` `:102` | ⚠️ |

**Differences:**

- ⚠️ **low** — `handleSDLEvent` drops events from sticks not in the id map: upstream tested `joyEvt.which >= 0` on the unsigned `SDL_JoystickID`, which is always true, so an unknown stick's `-1` index (0xFFFFFFFF) went on to index `axismap`/`buttonmap` out of bounds (bead oo-9ht.3) — upstream `SDL/OOSDLJoystickManager.m:256,268,277` ↔ port `SDL/OOSDLJoystickManager.cpp:111,123,132`
- ✅ subtle — the decode functions moved to the base class with identical bodies (see OOJoystickManager); events are carried in `JoyAxisEvent`/`JoyButtonEvent`/`JoyHatEvent` with `int32_t which`, and button-down is still tested against `SDL_EVENT_JOYSTICK_BUTTON_DOWN` only (gamepad button-downs read as up, as before) — upstream `OOSDLJoystickManager.m:218` ↔ port `Core/OOJoystickManager.cpp:539`
- ✅ subtle — open sequence unchanged: clamp to `MAX_STICKS` with the same two `joystick.init` logs, map `"%d"` of the SDL id → index, `SDL_SetJoystickEventsEnabled(true)`, then the base `init` (clear states, load settings) runs last, as `return [super init]` did — upstream `OOSDLJoystickManager.m:33-64` ↔ port `OOSDLJoystickManager.cpp:30-61`, `Core/OOJoystickManager.cpp:45-53`


## main

<a id="main"></a>
Upstream `src/SDL/main.m` ↔ `SDL/main.cpp`

**Status:** done — 1 rows: 0 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `main()` (68) | `main` `SDL/main.cpp:82` | ❌ |

**Differences:**

- ❌ **low** — a `.oolite-save` argument is now taken as UTF-8 (SDL_main's argv); upstream built it with `+[NSString stringWithCString:]`, i.e. GNUstep's default C-string encoding, so a non-ASCII save path was decoded differently there — upstream `SDL/main.m:166` ↔ port `SDL/main.cpp:187`
- ✅ subtle — argument handling otherwise verbatim: `-load` skips to the next argument, any argument ending (case-insensitively) in `.oolite-save` is the file to load, `-help`/`--help` prints the same usage text (same `TABS*` per platform) via `MessageBox`/stdout, logs `process.args` and returns 0. `-load` as the last argument still reaches `strcmp` with `argv[argc]` (NULL) in both — upstream `main.m:162-216` ↔ port `main.cpp:182-232`
- ✅ subtle — Windows start-up (exe dir prepended to `Path`/`PATH`, `GNUSTEP_*` roots and `HOMEPATH` set, chdir, `setlocale(LC_ALL, "C")`) and the Linux `/proc/self/exe` chdir are verbatim; argv is captured by `oo::process::setArguments` first, which stands in for `NSProcessInfo -arguments` (`oofnd/Process.hpp:15-21`) — upstream `main.m:76-150` ↔ port `main.cpp:92-166`
- ✅ subtle — the root handler catches only `OOException` (rethrowing anything else), as `@catch (NSException*)` caught only Objective-C exceptions; same `kOOLogException` text and `EXIT_FAILURE`. `[NSDate class]` (GNUstep issue #202 workaround) is gone with Foundation — upstream `main.m:74,224-227` ↔ port `main.cpp:245-251`

