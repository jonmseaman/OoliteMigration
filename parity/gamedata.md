# Parity findings: gamedata
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## AI

<a id="ai"></a>
Upstream `src/Core/AI.m` ↔ `Core/AI.cpp` (930 / 947 lines)

**Status:** done — 51 rows: 41 ✅ 6 ⚠️ 2 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[AI currentlyRunningAI]` (98) | `AI::currentlyRunningAI` Core/AI.cpp:171 | ✅ |
| `+[AI currentlyRunningAIDescription]` (103) | `AI::currentlyRunningAIDescription` Core/AI.cpp:173 | ✅ |
| `-[AI init]` (112) | `AI::AI` Core/AI.cpp:183 | ✅ |
| `-[AI initWithStateMachine:andState:]` (124) | `AI::initWithStateMachine` Core/AI.cpp:192 (+ `newWithStateMachine` :147) | ✅ |
| `-[AI dealloc]` (136) | `AI::~AI` Core/AI.cpp:200 | ✅ |
| `-[AI descriptionComponents]` (154) | `AI::descriptionComponents` Core/AI.cpp:208 | ✅ |
| `-[AI shortDescriptionComponents]` (159) | `AI::shortDescriptionComponents` Core/AI.cpp:214 (+ `JSScriptOf` :62) | ✅ |
| `-[AI owner]` (164) | `AI::owner` Core/AI.cpp:220 | ✅ |
| `-[AI setOwner:]` (175) | `AI::setOwner` Core/AI.cpp:230 | ✅ |
| `-[AI reportStackOverflow]` (182) | `AI::reportStackOverflow` Core/AI.cpp:235 | ❌ |
| `-[AI preserveCurrentStateMachine]` (204) | `AI::preserveCurrentStateMachine` Core/AI.cpp:261 | ✅ |
| `-[AI restorePreviousStateMachine]` (237) | `AI::restorePreviousStateMachine` Core/AI.cpp:287 | ✅ |
| `-[AI hasSuspendedStateMachines]` (263) | `AI::hasSuspendedStateMachines` Core/AI.cpp:313 | ✅ |
| `-[AI exitStateMachineWithMessage:]` (268) | `AI::exitStateMachineWithMessage` Core/AI.cpp:315 | ✅ |
| `-[AI setStateMachine:withJSScript:]` (278) | `AI::setStateMachine(smName, script)` Core/AI.cpp:323 | ✅ |
| `-[AI setState:]` (303) | `AI::setState(stateName)` Core/AI.cpp:349 | ✅ |
| `-[AI setStateMachine:afterDelay:]` (319) | `AI::setStateMachine(smName, delay)` Core/AI.cpp:366 | ⚠️ |
| `-[AI setState:afterDelay:]` (324) | `AI::setState(stateName, delay)` Core/AI.cpp:370 → `deferredSetState` :702 | ✅ |
| `-[AI name]` (329) | `AI::name` Core/AI.cpp:374 | ✅ |
| `-[AI associatedJS]` (334) | `AI::associatedJS` Core/AI.cpp:376 | ✅ |
| `-[AI state]` (339) | `AI::state` Core/AI.cpp:383 | ✅ |
| `-[AI stackDepth]` (344) | `AI::stackDepth` Core/AI.cpp:385 | ✅ |
| `-[AI reactToMessage:context:]` (363) | `AI::reactToMessage` Core/AI.cpp:401 | ❌ |
| `-[AI takeAction:]` (461) | `AI::takeAction` Core/AI.cpp:528 | ⚠️ |
| `-[AI think]` (514) | `AI::think` Core/AI.cpp:591 | ⚠️ |
| `-[AI message:]` (536) | `AI::message` Core/AI.cpp:609 (+ `PendingMessagesDescription` :68) | ⚠️ |
| `-[AI dropMessage:]` (552) | `AI::dropMessage` Core/AI.cpp:627 | ✅ |
| `-[AI pendingMessages]` (557) | `AI::getPendingMessages` Core/AI.cpp:629 | ✅ |
| `-[AI debugDumpPendingMessages]` (566) | `AI::debugDumpPendingMessages` Core/AI.cpp:631 | ✅ |
| `-[AI setNextThinkTime:]` (581) | `AI::setNextThinkTime` Core/AI.cpp:655 | ✅ |
| `-[AI nextThinkTime]` (586) | `AI::getNextThinkTime` Core/AI.cpp:657 | ✅ |
| `-[AI setThinkTimeInterval:]` (594) | `AI::setThinkTimeInterval` Core/AI.cpp:663 | ✅ |
| `-[AI thinkTimeInterval]` (599) | `AI::getThinkTimeInterval` Core/AI.cpp:665 | ✅ |
| `-[AI clearStack]` (604) | `AI::clearStack` Core/AI.cpp:667 | ✅ |
| `-[AI clearAllData]` (609) | `AI::clearAllData` Core/AI.cpp:669 | ✅ |
| `-[AI dumpState]` (617) | `AI::dumpState` Core/AI.cpp:676 | ✅ |
| `-[AI(OOPrivate) performDeferredCall:withObject:afterDelay:]` (635) | `AI::performDeferredCall` Core/AI.cpp:689 (`OOScheduleDeferredCall` lambda) | ✅ |
| `+[AI(OOPrivate) deferredCallTrampolineWithInfo:]` (654) | replaced by `FireAIDeferredCall` + `kDeferredAIMethods` Core/AI.cpp:104,84 | ➖ |
| `-[AI(OOPrivate) refreshOwnerDesc]` (669) | `AI::refreshOwnerDesc` Core/AI.cpp:704 | ✅ |
| `-[AI(OOPrivate) directSetStateMachine:name:]` (682) | `AI::directSetStateMachine` Core/AI.cpp:720 | ✅ |
| `-[AI(OOPrivate) directSetState:]` (694) | `AI::directSetState` Core/AI.cpp:726 | ✅ |
| `-[AI(OOPrivate) loadStateMachine:jsName:]` (702) | `AI::loadStateMachine` Core/AI.cpp:730 (+ `PListDictionaryFromFile` :55) | ⚠️ |
| `-[AI(OOPrivate) cleanHandlers:forState:stateMachine:]` (779) | `AI::cleanHandlers` Core/AI.cpp:805 | ⚠️ |
| `-[AI(OOPrivate) cleanActions:forHandler:state:stateMachine:]` (802) | `AI::cleanActions` Core/AI.cpp:829 | ✅ |
| `-[OOPreservedAIStateMachine initWithStateMachine:name:state:pendingMessages:jsScript:]` (877) | `OOPreservedAIStateMachine::OOPreservedAIStateMachine` Core/AI.cpp:921 | ✅ |
| `-[OOPreservedAIStateMachine dealloc]` (894) | none (value members; `oo::Object`) | ➖ |
| `-[OOPreservedAIStateMachine stateMachine]` (905) | `OOPreservedAIStateMachine::stateMachine` Core/AI.cpp:935 | ✅ |
| `-[OOPreservedAIStateMachine name]` (910) | `OOPreservedAIStateMachine::name` Core/AI.cpp:937 | ✅ |
| `-[OOPreservedAIStateMachine state]` (915) | `OOPreservedAIStateMachine::state` Core/AI.cpp:939 | ✅ |
| `-[OOPreservedAIStateMachine pendingMessages]` (920) | `OOPreservedAIStateMachine::pendingMessages` Core/AI.cpp:941 | ✅ |
| `-[OOPreservedAIStateMachine jsScript]` (925) | `OOPreservedAIStateMachine::jsScript` Core/AI.cpp:945 | ✅ |

**Differences:**

- ❌ **low** — `ai.error.stackOverflow.dump` lines lost the `%3zu` width (port `{}: `), and the debug-build `ai.error.recursion.stackTrace` lines lost `%4u` (port `{}  `). Log text only (still open) — upstream `Core/AI.m:196`, `:408` ↔ port `Core/AI.cpp:251`, `:454`
- ⚠️ **med** — `think` handles deferred messages in byte order (`std::set`) instead of `-[NSSet allObjects]` hash order; a message that changes state decides which handler sees the next one. Code comment + ADR-0043 (still open) — upstream `Core/AI.m:524-533` ↔ port `Core/AI.cpp:599-606`
- ⚠️ **low** — the "no handlers for this state" early return now unwinds the debug `sStack` frame (upstream left it dangling); debug builds only, commented (still open) — upstream `Core/AI.m:420-422` ↔ port `Core/AI.cpp:469-476`
- ⚠️ **low** — `reactToMessage` squashes only `OOException`s; others propagate as non-NSExceptions did. `kOOLogException` text unchanged (still open) — upstream `Core/AI.m:440-442` ↔ port `Core/AI.cpp:502-509`
- ⚠️ **low** — `takeAction`/`interpretAIMessage:` dispatch via `oo::EntityRespondsToName`/`oo::CallEntityByName` (ADR-0055, bead oo-9ht.39.7.1); a whitelisted method missing from the by-name table logs `ai.takeAction.badSelector` (still open) — upstream `Core/AI.m:447-449,488-496` ↔ port `Core/AI.cpp:515-516,561-571`
- ⚠️ **low** — `setStateMachine:afterDelay:` names `setStateMachine:`, which AI does not answer: upstream raised from the timer, port logs `callByName.unknownSelector` and does nothing (comment, bead oo-9ht.73) (still open) — upstream `Core/AI.m:319-322,662-665` ↔ port `Core/AI.cpp:74-86,104-116,366-368`
- ⚠️ **low** — `message:` overflow log prints pending messages in byte order (array description) instead of `NSSet` hash order (still open) — upstream `Core/AI.m:543` ↔ port `Core/AI.cpp:617-621`
- ⚠️ **low** — `loadStateMachine`/`cleanHandlers` visit states and handlers in key order, so `ai.invalidFormat.*`/`ai.unpermittedMethod` warnings come in a different order; a non-dictionary AI file no longer logs `plist.wrongType` (comments :52-54, ADR-0043) (still open) — upstream `Core/AI.m:728,742,786` ↔ port `Core/AI.cpp:52-58,773-786,810-824`
- ✅ subtle — `restorePreviousStateMachine` passes `""` where upstream passed nil for a missing `jsScript`, and guards a null owner; unreachable since `loadStateMachine` always stores `jsScript` — upstream `Core/AI.m:255` ↔ port `Core/AI.cpp:305-306`
- ✅ subtle — `cleanActions` cuts parameters at the first `' '` byte; whitelist keeps only string entries, alias string/array handling the same — upstream `Core/AI.m:814-866` ↔ port `Core/AI.cpp:837-915`

## AIGraphViz

<a id="aigraphviz"></a>
Upstream `src/Core/AIGraphViz.m` ↔ `Core/AIGraphViz.cpp` (233 / 309 lines)

**Status:** done — 6 rows: 4 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `GenerateGraphVizForAIStateMachine` (38) | `GenerateGraphVizForAIStateMachine` Core/AIGraphViz.cpp:228 | ⚠️ |
| `HandlerToken` (104) | `HandlerToken` Core/AIGraphViz.cpp:56 | ✅ |
| `HandleOneCommand` (124) | `HandleOneCommand` Core/AIGraphViz.cpp:152 (+ `CommandAt` :46) | ⚠️ |
| `AddSimpleSpecialNodeLink` (172) | `AddSimpleSpecialNodeLink` Core/AIGraphViz.cpp:71 | ✅ |
| `AddExitAINode` (181) | `AddExitAINode` Core/AIGraphViz.cpp:86 | ✅ |
| `AddChangeAINode` (197) | `AddChangeAINode` Core/AIGraphViz.cpp:105 | ✅ |

**Differences:**

- ⚠️ **low** — states/handlers written in key order and special nodes in sorted-string order instead of `NSDictionary`/`NSSet` hash order; same `.dot` content, different line order; debug dump only (file comment, ADR-0043, bead oo-ndxe) (still open) — upstream `Core/AIGraphViz.m:56,64,77,95` ↔ port `Core/AIGraphViz.cpp:36-39,246-302`
- ⚠️ **low** — an empty command (no tokens) is skipped where upstream raised from `-objectAtIndex:0` (code comment) (still open) — upstream `Core/AIGraphViz.m:130-131` ↔ port `Core/AIGraphViz.cpp:163-165`
- ✅ note — a non-dictionary state (the `jsScript` string) still gets a cluster with an implicit ENTER node, as `oo_dictionaryForKey:` nil did; the `tspecial_broken_` typo is kept — upstream `Core/AIGraphViz.m:62-72,229` ↔ port `Core/AIGraphViz.cpp:255-271,147`

## OOCharacter

<a id="oocharacter"></a>
Upstream `src/Core/OOCharacter.m` ↔ `Core/OOCharacter.cpp` (450 / 491 lines)

**Status:** done — 31 rows: 29 ✅ 1 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCharacter descriptionComponents]` (45) | `OOCharacter::descriptionComponents` Core/OOCharacter.cpp:63 | ✅ |
| `-[OOCharacter oo_jsClassName]` (50) | `OOCharacter::oo_jsClassName` Core/OOCharacter.cpp:73 | ✅ |
| `-[OOCharacter dealloc]` (55) | implicit destructor (RAII members) | ➖ |
| `-[OOCharacter initWithGenSeed:andOriginalSystem:]` (65) | `OOCharacter::OOCharacter(Random_Seed, OOSystemID)` Core/OOCharacter.cpp:87 | ✅ |
| `-[OOCharacter initWithRole:andOriginalSystem:]` (77) | `OOCharacter::OOCharacter(const std::string&, OOSystemID)` Core/OOCharacter.cpp:107 (+ `PseudoRandomSeed` :99) | ✅ |
| `+[OOCharacter characterWithRole:andOriginalSystem:]` (89) | `OOCharacter::characterWithRole` Core/OOCharacter.cpp:112 | ✅ |
| `+[OOCharacter randomCharacterWithRole:andOriginalSystem:]` (94) | `OOCharacter::randomCharacterWithRole` Core/OOCharacter.cpp:117 | ✅ |
| `+[OOCharacter characterWithDictionary:]` (111) | `OOCharacter::characterWithDictionary` Core/OOCharacter.cpp:135 | ✅ |
| `-[OOCharacter planetOfOrigin]` (119) | `OOCharacter::planetOfOrigin` Core/OOCharacter.cpp:144 | ✅ |
| `-[OOCharacter planetIDOfOrigin]` (126) | `OOCharacter::planetIDOfOrigin` Core/OOCharacter.cpp:156 | ✅ |
| `-[OOCharacter species]` (132) | `OOCharacter::species` Core/OOCharacter.cpp:161 | ✅ |
| `-[OOCharacter basicSetUp]` (149) | `OOCharacter::basicSetUp` Core/OOCharacter.cpp:184 | ✅ |
| `-[OOCharacter castInRole:]` (219) | `OOCharacter::castInRole` Core/OOCharacter.cpp:276 | ✅ |
| `-[OOCharacter name]` (297) | `OOCharacter::name` Core/OOCharacter.cpp:352 | ✅ |
| `-[OOCharacter shortDescription]` (302) | `OOCharacter::shortDescription` Core/OOCharacter.cpp:354 | ✅ |
| `-[OOCharacter genSeed]` (307) | `OOCharacter::genSeed` Core/OOCharacter.cpp:358 | ✅ |
| `-[OOCharacter legalStatus]` (312) | `OOCharacter::legalStatus` Core/OOCharacter.cpp:360 | ✅ |
| `-[OOCharacter insuranceCredits]` (317) | `OOCharacter::insuranceCredits` Core/OOCharacter.cpp:362 | ✅ |
| `-[OOCharacter legacyScript]` (322) | `OOCharacter::legacyScript` Core/OOCharacter.cpp:364 | ✅ |
| `-[OOCharacter infoForScripting]` (327) | `OOCharacter::infoForScripting` Core/OOCharacter.cpp:366 | ✅ |
| `-[OOCharacter setName:]` (339) | `OOCharacter::setName` Core/OOCharacter.cpp:388 | ✅ |
| `-[OOCharacter setShortDescription:]` (345) | `OOCharacter::setShortDescription` Core/OOCharacter.cpp:392 | ✅ |
| `-[OOCharacter setOriginSystem:]` (351) | `OOCharacter::setOriginSystem` Core/OOCharacter.cpp:396 | ✅ |
| `-[OOCharacter setGenSeed:]` (356) | `OOCharacter::setGenSeed` Core/OOCharacter.cpp:398 | ✅ |
| `-[OOCharacter setLegalStatus:]` (361) | `OOCharacter::setLegalStatus` Core/OOCharacter.cpp:400 | ✅ |
| `-[OOCharacter setInsuranceCredits:]` (366) | `OOCharacter::setInsuranceCredits` Core/OOCharacter.cpp:402 | ✅ |
| `-[OOCharacter setLegacyScript:]` (371) | `OOCharacter::setLegacyScript` Core/OOCharacter.cpp:406 | ✅ |
| `-[OOCharacter script]` (377) | `OOCharacter::script` Core/OOCharacter.cpp:410 | ✅ |
| `-[OOCharacter setCharacterScript:]` (382) | `OOCharacter::setCharacterScript` Core/OOCharacter.cpp:412 | ✅ |
| `-[OOCharacter doScriptEvent:]` (390) | `OOCharacter::doScriptEvent` Core/OOCharacter.cpp:421 | ✅ |
| `-[OOCharacter setCharacterFromDictionary:]` (397) | `OOCharacter::setCharacterFromDictionary` Core/OOCharacter.cpp:428 | ⚠️ |

**Differences:**

- ⚠️ **low** — `origin` is accepted only as a number or string; upstream took any object answering `-intValue` non-zero (or `@"0"`). Port comment: no game object is one (bead oo-4aq6a.5); plist/JS input unaffected (still open) — upstream `Core/OOCharacter.m:403` ↔ port `Core/OOCharacter.cpp:433-438`
- ✅ subtle — the bounty, legal-index and insurance draws are sequenced left-to-right (clang's order); upstream's `gen_rnd_number() & gen_rnd_number()` was unspecified — upstream `Core/OOCharacter.m:186,192,201` ↔ port `Core/OOCharacter.cpp:236-258`
- ✅ subtle — generated name built given-name first, then family name, as clang evaluated the `stringWithFormat:` arguments — upstream `Core/OOCharacter.m:171,178` ↔ port `Core/OOCharacter.cpp:207-226`
- ✅ subtle — `infoForScripting` keeps the `dictionaryWithObjectsAndKeys:` truncation at the first nil (name → description → species), with `species()` always evaluated — upstream `Core/OOCharacter.m:329` ↔ port `Core/OOCharacter.cpp:369-385`
- ✅ subtle — `setCharacterScript`'s `character` property reaches JS as undefined; so did upstream, since `OOCharacter` has no `oo_jsValueInContext:` and NSObject's returns `JSVAL_VOID` (`Core/Scripting/OOJavaScriptEngine.m:1279`) — upstream `Core/OOCharacter.m:385` ↔ port `Core/OOCharacter.cpp:413-418`

## OOColor

<a id="oocolor"></a>
Upstream `src/Core/OOColor.m` ↔ `Core/OOColor.cpp` (497 / 524 lines)

**Status:** done — 49 rows: 47 ✅ 1 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOColor setRed:green:blue:alpha:]` (32) | `OOColor::setRed` Core/OOColor.cpp:76 | ✅ |
| `-[OOColor setHue:saturation:brightness:alpha:]` (40) | `OOColor::setHue` Core/OOColor.cpp:83 | ✅ |
| `-[OOColor copyWithZone:]` (94) | none: immutable, the same shared pointer is shared | ➖ |
| `+[OOColor colorWithHue:saturation:brightness:alpha:]` (100) | `OOColor::colorWithHue` Core/OOColor.cpp:135 | ✅ |
| `+[OOColor colorWithRed:green:blue:alpha:]` (107) | `OOColor::colorWithRed` Core/OOColor.cpp:142 | ✅ |
| `+[OOColor colorWithWhite:alpha:]` (114) | `OOColor::colorWithWhite` Core/OOColor.cpp:149 | ✅ |
| `+[OOColor colorWithRGBAComponents:]` (119) | `OOColor::colorWithRGBAComponents` Core/OOColor.cpp:153 | ✅ |
| `+[OOColor colorWithHSBAComponents:]` (127) | `OOColor::colorWithHSBAComponents` Core/OOColor.cpp:158 | ✅ |
| `+[OOColor colorWithDescription:]` (135) | `OOColor::colorWithDescription(description)` Core/OOColor.cpp:164 | ✅ |
| `+[OOColor colorWithDescription:saturationFactor:]` (140) | `OOColor::colorWithDescription(description, factor)` Core/OOColor.cpp:169 (+ `kNamedColors` :54) | ✅ |
| `+[OOColor brightColorWithDescription:]` (202) | `OOColor::brightColorWithDescription` Core/OOColor.cpp:242 | ✅ |
| `+[OOColor colorFromString:]` (211) | `OOColor::colorFromString` Core/OOColor.cpp:251 | ✅ |
| `+[OOColor blackColor]` (234) | `OOColor::blackColor` Core/OOColor.cpp:274 | ✅ |
| `+[OOColor darkGrayColor]` (239) | `OOColor::darkGrayColor` Core/OOColor.cpp:279 | ✅ |
| `+[OOColor lightGrayColor]` (244) | `OOColor::lightGrayColor` Core/OOColor.cpp:284 | ✅ |
| `+[OOColor whiteColor]` (249) | `OOColor::whiteColor` Core/OOColor.cpp:289 | ✅ |
| `+[OOColor grayColor]` (254) | `OOColor::grayColor` Core/OOColor.cpp:294 | ✅ |
| `+[OOColor redColor]` (259) | `OOColor::redColor` Core/OOColor.cpp:299 | ✅ |
| `+[OOColor greenColor]` (264) | `OOColor::greenColor` Core/OOColor.cpp:304 | ✅ |
| `+[OOColor blueColor]` (269) | `OOColor::blueColor` Core/OOColor.cpp:309 | ✅ |
| `+[OOColor cyanColor]` (274) | `OOColor::cyanColor` Core/OOColor.cpp:314 | ✅ |
| `+[OOColor yellowColor]` (279) | `OOColor::yellowColor` Core/OOColor.cpp:319 | ✅ |
| `+[OOColor magentaColor]` (284) | `OOColor::magentaColor` Core/OOColor.cpp:324 | ✅ |
| `+[OOColor orangeColor]` (289) | `OOColor::orangeColor` Core/OOColor.cpp:329 | ✅ |
| `+[OOColor purpleColor]` (294) | `OOColor::purpleColor` Core/OOColor.cpp:334 | ✅ |
| `+[OOColor brownColor]` (299) | `OOColor::brownColor` Core/OOColor.cpp:339 | ✅ |
| `+[OOColor clearColor]` (304) | `OOColor::clearColor` Core/OOColor.cpp:344 | ✅ |
| `-[OOColor blendedColorWithFraction:ofColor:]` (309) | `OOColor::blendedColorWithFraction` Core/OOColor.cpp:349 | ⚠️ |
| `-[OOColor descriptionComponents]` (323) | `OOColor::descriptionComponents` Core/OOColor.cpp:365 (+ `className`/`description` :370,:372) | ✅ |
| `-[OOColor redComponent]` (329) | `OOColor::redComponent` Core/OOColor.cpp:381 | ✅ |
| `-[OOColor greenComponent]` (334) | `OOColor::greenComponent` Core/OOColor.cpp:383 | ✅ |
| `-[OOColor blueComponent]` (339) | `OOColor::blueComponent` Core/OOColor.cpp:385 | ✅ |
| `-[OOColor getRed:green:blue:alpha:]` (344) | `OOColor::getRed` Core/OOColor.cpp:387 | ✅ |
| `-[OOColor rgbaComponents]` (354) | `OOColor::rgbaComponents` Core/OOColor.cpp:397 | ✅ |
| `-[OOColor isBlack]` (360) | `OOColor::isBlack` Core/OOColor.cpp:402 | ✅ |
| `-[OOColor isWhite]` (365) | `OOColor::isWhite` Core/OOColor.cpp:406 | ✅ |
| `-[OOColor hueComponent]` (371) | `OOColor::hueComponent` Core/OOColor.cpp:412 | ✅ |
| `-[OOColor saturationComponent]` (390) | `OOColor::saturationComponent` Core/OOColor.cpp:434 | ✅ |
| `-[OOColor brightnessComponent]` (397) | `OOColor::brightnessComponent` Core/OOColor.cpp:444 | ✅ |
| `-[OOColor getHue:saturation:brightness:alpha:]` (403) | `OOColor::getHue` Core/OOColor.cpp:451 | ✅ |
| `-[OOColor hsbaComponents]` (431) | `OOColor::hsbaComponents` Core/OOColor.cpp:480 | ✅ |
| `-[OOColor alphaComponent]` (442) | `OOColor::alphaComponent` Core/OOColor.cpp:487 | ✅ |
| `-[OOColor premultipliedColor]` (447) | `OOColor::premultipliedColor` Core/OOColor.cpp:489 | ✅ |
| `-[OOColor colorWithBrightnessFactor:]` (457) | `OOColor::colorWithBrightnessFactor` Core/OOColor.cpp:495 | ✅ |
| `-[OOColor normalizedArray]` (465) | `OOColor::normalizedArray` Core/OOColor.cpp:501 (`std::vector<float>`) | ✅ |
| `-[OOColor rgbaDescription]` (477) | `OOColor::rgbaDescription` Core/OOColor.cpp:507 | ✅ |
| `-[OOColor hsbaDescription]` (482) | `OOColor::hsbaDescription` Core/OOColor.cpp:511 | ✅ |
| `OORGBAComponentsDescription` (489) | `OORGBAComponentsDescription` Core/OOColor.cpp:515 | ✅ |
| `OOHSBAComponentsDescription` (494) | `OOHSBAComponentsDescription` Core/OOColor.cpp:520 | ✅ |

**Differences:**

- ⚠️ **low** — `blendedColorWithFraction:ofColor:nil` left `rgba1` indeterminate upstream (message to nil); the port blends with zeros (code comment) (still open) — upstream `Core/OOColor.m:311-312` ↔ port `Core/OOColor.cpp:351-355`
- ✅ subtle — the `+fooColor` selector lookup is an explicit table of the 15 named colours; an unmatched `...Color` string gives nil in both — upstream `Core/OOColor.m:151-155` ↔ port `Core/OOColor.cpp:54-70,180-187`
- ✅ subtle — array form skips null elements and joins `oo::DescriptionOf` of each with spaces; `colorFromString` uses `oo::str::Scanner::scanFloat` — upstream `Core/OOColor.m:161,214-219` ↔ port `Core/OOColor.cpp:192-204,254-259`
- ✅ subtle — dict form: HSB branch needs a non-null `hue`; an explicit null value (impossible from plist) would now take the RGB branch. `get<float>` defaults match `oo_floatForKey:` defaults — upstream `Core/OOColor.m:165-185` ↔ port `Core/OOColor.cpp:205-228`
- ✅ subtle — `{:g}`/`{:.3g}` of a float format its exact value, as `%g` of the promoted double did — upstream `Core/OOColor.m:325,491,496` ↔ port `Core/OOColor.cpp:366,516,521`

## OOCommodities

<a id="oocommodities"></a>
Upstream `src/Core/OOCommodities.m` ↔ `Core/OOCommodities.cpp` (540 / 681 lines)

**Status:** done — 23 rows: 16 ✅ 6 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOCommodities legacyCommodityType:]` (55) | `OOCommodities::legacyCommodityType` Core/OOCommodities.cpp:143 | ✅ |
| `-[OOCommodities init]` (97) | `OOCommodities::OOCommodities` Core/OOCommodities.cpp:184 | ✅ |
| `-[OOCommodities dealloc]` (122) | implicit destructor (`std::map` member, Core/OOCommodities.h:106) | ➖ |
| `-[OOCommodities generateManifestForPlayer]` (129) | `OOCommodities::generateManifestForPlayer` Core/OOCommodities.cpp:196 | ✅ |
| `-[OOCommodities generateBlankMarket]` (150) | `OOCommodities::generateBlankMarket` Core/OOCommodities.cpp:219 | ✅ |
| `-[OOCommodities createDefinitionFrom:price:andQuantity:forKey:atStation:inSystem:]` (169) | `OOCommodities::createDefinitionFrom` Core/OOCommodities.cpp:240 | ✅ |
| `-[OOCommodities modifyGood:withScript:atStation:inSystem:localMode:]` (196) | `OOCommodities::modifyGood` Core/OOCommodities.cpp:273 | ✅ |
| `-[OOCommodities generateMarketForSystemWithEconomy:andScript:]` (253) | `OOCommodities::generateMarketForSystemWithEconomy` Core/OOCommodities.cpp:343 | ⚠️ |
| `-[OOCommodities generateMarketForStation:]` (281) | `OOCommodities::generateMarketForStation` Core/OOCommodities.cpp:378 | ⚠️ |
| `-[OOCommodities count]` (339) | `OOCommodities::count` Core/OOCommodities.cpp:453 | ✅ |
| `-[OOCommodities goods]` (344) | `OOCommodities::goods` Core/OOCommodities.cpp:455 | ⚠️ |
| `-[OOCommodities goodDefined:]` (349) | `OOCommodities::goodDefined` Core/OOCommodities.cpp:463 | ✅ |
| `-[OOCommodities goodNamed:]` (354) | `OOCommodities::goodNamed` Core/OOCommodities.cpp:468 | ⚠️ |
| `-[OOCommodities getRandomCommodity]` (367) | `OOCommodities::getRandomCommodity` Core/OOCommodities.cpp:483 | ⚠️ |
| `-[OOCommodities massUnitForGood:]` (374) | `OOCommodities::massUnitForGood` Core/OOCommodities.cpp:491 | ⚠️ |
| `-[OOCommodities generateQuantityForGood:inEconomy:]` (383) | `OOCommodities::generateQuantityForGood` Core/OOCommodities.cpp:500 | ✅ |
| `-[OOCommodities generatePriceForGood:inEconomy:]` (398) | `OOCommodities::generatePriceForGood` Core/OOCommodities.cpp:520 | ✅ |
| `-[OOCommodities samplePriceForCommodity:inEconomy:withScript:inSystem:]` (413) | `OOCommodities::samplePriceForCommodity` Core/OOCommodities.cpp:540 | ✅ |
| `-[OOCommodities economicBiasForGood:inEconomy:]` (432) | `OOCommodities::economicBiasForGood` Core/OOCommodities.cpp:564 | ✅ |
| `-[OOCommodities firstModifierForGood:inClasses:fromList:]` (454) | `OOCommodities::firstModifierForGood` Core/OOCommodities.cpp:586 (+ `ContainsString` :131) | ✅ |
| `-[OOCommodities adjustPrice:byRule:]` (475) | `OOCommodities::adjustPrice` Core/OOCommodities.cpp:613 | ✅ |
| `-[OOCommodities adjustQuantity:byRule:]` (495) | `OOCommodities::adjustQuantity` Core/OOCommodities.cpp:634 | ✅ |
| `-[OOCommodities updateInfoFor:byRule:maxCapacity:]` (516) | `OOCommodities::updateInfoFor` Core/OOCommodities.cpp:656 | ✅ |

**Differences:**

- ⚠️ **med** — main-system goods are generated in `std::map` key order, not `NSDictionary` hash order (bead oo-3rb.154, commented per loop); each good draws `randf()` twice for quantity and twice for price, so per-good prices/quantities for a given seed differ from upstream and commodity scripts see calls in another order (still open) — upstream `Core/OOCommodities.m:261` ↔ port `Core/OOCommodities.cpp:353`
- ⚠️ **med** — secondary-station markets likewise: the `randf()` pairs in `adjustPrice`/`adjustQuantity` run per good in key order (still open) — upstream `Core/OOCommodities.m:297` ↔ port `Core/OOCommodities.cpp:400`
- ⚠️ **low** — `goods` returns key order (was `-allKeys`); `goodNamed:` returns the first match in key order, relevant only if two goods expand to one name (still open) — upstream `Core/OOCommodities.m:344,357` ↔ port `Core/OOCommodities.cpp:455,469`
- ⚠️ **low** — `getRandomCommodity`: the same `Ranrot() % count` indexes key order, so picks a different good (commented) (still open) — upstream `Core/OOCommodities.m:369-371` ↔ port `Core/OOCommodities.cpp:483-488`
- ⚠️ **low** — `massUnitForGood:` maps a `quantity_unit` above 2 to `UNITS_UNKNOWN` via `OOMassUnitFromNumber`; upstream returned the raw cast (ADR-0036) (still open) — upstream `Core/OOCommodities.m:380` ↔ port `Core/OOCommodities.cpp:496-497`
- ✅ subtle — the generate functions draw the two `randf()` values in explicit first-minus-second order; `adjustPrice`/`adjustQuantity` keep the unsequenced `(randf() - randf())` — port `Core/OOCommodities.cpp:508-511,528-531` vs `:625,:646`
- ✅ subtle — upstream `updateInfoFor:` bug (import legality written into `legality_export`) reproduced, commented "sic" — upstream `Core/OOCommodities.m:526` ↔ port `Core/OOCommodities.cpp:668-669`
- ✅ subtle (new) — a non-dictionary `trade-goods.plist` entry: upstream generate/createDefinition worked on `dictionaryWithDictionary:nil` (an empty dict gaining `price`/`quantity`/`capacity`/`key`); the port's `Set` is a no-op on a non-dict, and `OOCommodityMarket::setGood` stores an empty dict, so `key` (and the 127 capacity entry) is missing. Price/quantity are 0 either way; malformed data only — upstream `Core/OOCommodities.m:171-178,263` ↔ port `Core/OOCommodities.cpp:113-116,243-250,355`

## OOCommodityMarket

<a id="oocommoditymarket"></a>
Upstream `src/Core/OOCommodityMarket.m` ↔ `Core/OOCommodityMarket.cpp` (354 / 352 lines)

**Status:** done — 29 rows: 25 ✅ 3 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCommodityMarket init]` (34) | implicit default constructor (`_commodityList`, `_sortedKeys` empty) Core/OOCommodityMarket.h:104-106 | ✅ |
| `-[OOCommodityMarket dealloc]` (47) | implicit destructor | ➖ |
| `-[OOCommodityMarket count]` (54) | `OOCommodityMarket::count` Core/OOCommodityMarket.cpp:57 | ✅ |
| `-[OOCommodityMarket setGood:withInfo:]` (59) | `OOCommodityMarket::setGood` Core/OOCommodityMarket.cpp:59 | ✅ |
| `-[OOCommodityMarket goods]` (66) | `OOCommodityMarket::goods` → `sortedGoodKeys` Core/OOCommodityMarket.cpp:65,338 | ⚠️ |
| `-[OOCommodityMarket dictionaryForScripting]` (75) | `OOCommodityMarket::dictionaryForScripting` Core/OOCommodityMarket.cpp:67 | ✅ |
| `-[OOCommodityMarket setPrice:forGood:]` (80) | `OOCommodityMarket::setPrice` Core/OOCommodityMarket.cpp:72 | ✅ |
| `-[OOCommodityMarket setQuantity:forGood:]` (90) | `OOCommodityMarket::setQuantity` Core/OOCommodityMarket.cpp:83 | ✅ |
| `-[OOCommodityMarket addQuantity:forGood:]` (100) | `OOCommodityMarket::addQuantity` Core/OOCommodityMarket.cpp:94 | ✅ |
| `-[OOCommodityMarket removeQuantity:forGood:]` (110) | `OOCommodityMarket::removeQuantity` Core/OOCommodityMarket.cpp:104 | ✅ |
| `-[OOCommodityMarket removeAllGoods]` (120) | `OOCommodityMarket::removeAllGoods` Core/OOCommodityMarket.cpp:114 | ✅ |
| `-[OOCommodityMarket setComment:forGood:]` (128) | `OOCommodityMarket::setComment` Core/OOCommodityMarket.cpp:120 | ✅ |
| `-[OOCommodityMarket setShortComment:forGood:]` (138) | `OOCommodityMarket::setShortComment` Core/OOCommodityMarket.cpp:131 | ✅ |
| `-[OOCommodityMarket nameForGood:]` (148) | `OOCommodityMarket::nameForGood` Core/OOCommodityMarket.cpp:142 | ✅ |
| `-[OOCommodityMarket commentForGood:]` (157) | `OOCommodityMarket::commentForGood` Core/OOCommodityMarket.cpp:152 | ✅ |
| `-[OOCommodityMarket shortCommentForGood:]` (166) | `OOCommodityMarket::shortCommentForGood` Core/OOCommodityMarket.cpp:162 | ✅ |
| `-[OOCommodityMarket priceForGood:]` (175) | `OOCommodityMarket::priceForGood` Core/OOCommodityMarket.cpp:172 | ✅ |
| `-[OOCommodityMarket quantityForGood:]` (184) | `OOCommodityMarket::quantityForGood` Core/OOCommodityMarket.cpp:180 | ✅ |
| `-[OOCommodityMarket massUnitForGood:]` (193) | `OOCommodityMarket::massUnitForGood` Core/OOCommodityMarket.cpp:188 | ⚠️ |
| `-[OOCommodityMarket exportLegalityForGood:]` (202) | `OOCommodityMarket::exportLegalityForGood` Core/OOCommodityMarket.cpp:196 | ✅ |
| `-[OOCommodityMarket importLegalityForGood:]` (211) | `OOCommodityMarket::importLegalityForGood` Core/OOCommodityMarket.cpp:204 | ✅ |
| `-[OOCommodityMarket capacityForGood:]` (220) | `OOCommodityMarket::capacityForGood` Core/OOCommodityMarket.cpp:212 | ✅ |
| `-[OOCommodityMarket trumbleOpinionForGood:]` (231) | `OOCommodityMarket::trumbleOpinionForGood` Core/OOCommodityMarket.cpp:222 | ✅ |
| `-[OOCommodityMarket definitionForGood:]` (240) | `OOCommodityMarket::definitionForGood` Core/OOCommodityMarket.cpp:230 | ✅ |
| `-[OOCommodityMarket savePlayerAmounts]` (245) | `OOCommodityMarket::savePlayerAmounts` Core/OOCommodityMarket.cpp:235 | ✅ |
| `-[OOCommodityMarket loadPlayerAmounts:]` (255) | `OOCommodityMarket::loadPlayerAmounts` Core/OOCommodityMarket.cpp:244 (+ `SavedGoodKey` :48) | ✅ |
| `-[OOCommodityMarket saveStationAmounts]` (292) | `OOCommodityMarket::saveStationAmounts` Core/OOCommodityMarket.cpp:282 | ✅ |
| `-[OOCommodityMarket loadStationAmounts:]` (302) | `OOCommodityMarket::loadStationAmounts` Core/OOCommodityMarket.cpp:292 | ✅ |
| `goodsSorter` (341) | lambda in `OOCommodityMarket::sortedGoodKeys` Core/OOCommodityMarket.cpp:345 | ⚠️ |

**Differences:**

- ⚠️ **low** — goods with equal (or absent) `sort_order` are tie-broken by key bytes (`std::stable_sort` over map order); upstream sorted hash-ordered `-allKeys`. Commented at :336-337; changes market-screen order and saved `[key, qty(, price)]` array order for tied OXP goods (still open) — upstream `Core/OOCommodityMarket.m:66-73,341` ↔ port `Core/OOCommodityMarket.cpp:338-351`
- ⚠️ **low** — `massUnitForGood:` returns `UNITS_UNKNOWN` for `quantity_unit` above 2; upstream returned the raw cast (ADR-0036) (still open) — upstream `Core/OOCommodityMarket.m:199` ↔ port `Core/OOCommodityMarket.cpp:193`
- ✅ subtle — `setGood:` with a non-dictionary info stores an empty dictionary (upstream: `+dictionaryWithDictionary:` raised for a non-dict, empty for nil) — upstream `Core/OOCommodityMarket.m:61` ↔ port `Core/OOCommodityMarket.cpp:61`
- ✅ subtle — in `loadPlayerAmounts:`/`loadStationAmounts:` a nil good still logs as `(null)`; log classes and text unchanged — upstream `Core/OOCommodityMarket.m:287,334` ↔ port `Core/OOCommodityMarket.cpp:274-277,322-325`

## OOConstToString

<a id="ooconsttostring"></a>
Upstream `src/Core/OOConstToString.m` ↔ `Core/OOConstToString.cpp` (592 / 476 lines)

**Status:** done — 48 rows: 42 ✅ 0 ⚠️ 5 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOStringFromEntityStatus` (50) | `OOStringFromEntityStatus` Core/OOConstToString.cpp:38 (names: Core/Tables/OOEntityStatus.h:47) | ✅ |
| `OOStringFromBehaviour` (58) | `OOStringFromBehaviour` Core/OOConstToString.cpp:43 (Core/Tables/OOBehaviour.h:64) | ✅ |
| `OOStringFromCompassMode` (67) | `OOStringFromCompassMode` Core/OOConstToString.cpp:49 (Core/Tables/OOCompassMode.h:31) | ✅ |
| `OOStringFromLongRangeChartMode` (76) | `OOStringFromLongRangeChartMode` Core/OOConstToString.cpp:54 (Core/Tables/OOLongRangeChartMode.h:33) | ✅ |
| `OOStringFromGalacticHyperspaceBehaviour` (85) | `OOStringFromGalacticHyperspaceBehaviour` Core/OOConstToString.cpp:59 (Core/Tables/OOGalacticHyperspaceBehaviour.h:36) | ✅ |
| `OOStringFromGUIScreenID` (94) | `OOStringFromGUIScreenID` Core/OOConstToString.cpp:65 (Core/Tables/OOGUIScreenID.h:56) | ✅ |
| `OOStringFromScanClass` (103) | `OOStringFromScanClass` Core/OOConstToString.cpp:70 (Core/Tables/OOScanClass.h:42) | ✅ |
| `OOStringFromShipDamageType` (112) | `OOStringFromShipDamageType` Core/OOConstToString.cpp:75 (Core/Tables/OOShipDamageType.h:34) | ✅ |
| `OOStringFromLegalStatusReason` (121) | `OOStringFromLegalStatusReason` Core/OOConstToString.cpp:80 (Core/Tables/OOLegalStatusReason.h:43) | ✅ |
| `OOEntityStatusFromString` (140) | `OOEntityStatusFromString` Core/OOConstToString.cpp:85 | ✅ |
| `OOCompassModeFromString` (147) | `OOCompassModeFromString` Core/OOConstToString.cpp:89 | ✅ |
| `OOGalacticHyperspaceBehaviourFromString` (154) | `OOGalacticHyperspaceBehaviourFromString` Core/OOConstToString.cpp:93 | ✅ |
| `OOGUIScreenIDFromString` (168) | `OOGUIScreenIDFromString` Core/OOConstToString.cpp:109 | ✅ |
| `OOScanClassFromString` (175) | `OOScanClassFromString` Core/OOConstToString.cpp:113 | ✅ |
| `OOLongRangeChartModeFromString` (182) | `OOLongRangeChartModeFromString` Core/OOConstToString.cpp:117 | ✅ |
| `RouteTypeToString` (192) | `RouteTypeToString` Core/OOConstToString.cpp:122 (Core/OOTypes.h:54) | ✅ |
| `OODisplayStringFromGovernmentID` (203) | `OODisplayStringFromGovernmentID` Core/OOConstToString.cpp:141 | ❌ |
| `OODisplayStringFromEconomyID` (218) | `OODisplayStringFromEconomyID` Core/OOConstToString.cpp:156 | ❌ |
| `JSTypeToString` (233) | removed: no definition or caller in the port (upstream has no caller either) | ➖ |
| `OOStringFromWeaponType` (249) | `OOStringFromWeaponType` Core/OOConstToString.cpp:168 | ✅ |
| `OOWeaponTypeFromString` (258) | `OOWeaponTypeFromString` Core/OOConstToString.cpp:176 | ✅ |
| `OOEquipmentIdentifierFromWeaponType` (263) | `OOEquipmentIdentifierFromWeaponType` Core/OOConstToString.cpp:180 | ✅ |
| `OOWeaponTypeFromEquipmentIdentifierSloppy` (268) | `OOWeaponTypeFromEquipmentIdentifierSloppy` Core/OOConstToString.cpp:187 | ✅ |
| `OOWeaponTypeFromEquipmentIdentifierLegacy` (285) | `OOWeaponTypeFromEquipmentIdentifierLegacy` Core/OOConstToString.cpp:206 | ✅ |
| `OOWeaponTypeFromEquipmentIdentifierStrict` (306) | `OOWeaponTypeFromEquipmentIdentifierStrict` Core/OOConstToString.cpp:232 | ✅ |
| `CargoTypeToString` (312) | `CargoTypeToString` Core/OOConstToString.cpp:238 (Core/OOTypes.h:99) | ✅ |
| `StringToCargoType` (327) | `StringToCargoType` Core/OOConstToString.cpp:243 | ✅ |
| `EnergyUnitTypeToString` (345) | `EnergyUnitTypeToString` Core/OOConstToString.cpp:259 (Core/OOTypes.h:190) | ✅ |
| `StringToEnergyUnitType` (362) | `StringToEnergyUnitType` Core/OOConstToString.cpp:265 | ✅ |
| `OODisplayRatingStringFromKillCount` (373) | `OODisplayRatingStringFromKillCount` Core/OOConstToString.cpp:277 (+ `DescriptionStringAt` :132) | ❌ |
| `KillCountToRatingAndKillString` (399) | `KillCountToRatingAndKillString` Core/OOConstToString.cpp:294 | ✅ |
| `OODisplayStringFromLegalStatus` (404) | `OODisplayStringFromLegalStatus` Core/OOConstToString.cpp:302 | ❌ |
| `OODisplayStringFromAlertCondition` (424) | `OODisplayStringFromAlertCondition` Core/OOConstToString.cpp:320 | ❌ |
| `OODisplayStringFromShaderSetting` (430) | `OODisplayStringFromShaderSetting` Core/OOConstToString.cpp:329 | ✅ |
| `OOStringFromShaderSetting` (446) | `OOStringFromShaderSetting` Core/OOConstToString.cpp:347 (Core/OOOpenGL.h:57) | ✅ |
| `OOShaderSettingFromString` (458) | `OOShaderSettingFromString` Core/OOConstToString.cpp:352 | ✅ |
| `CommodityDisplayNameForSymbolicName` (468) | `CommodityDisplayNameForSymbolicName` Core/OOConstToString.cpp:363 | ✅ |
| `CommodityDisplayNameForCommodityArray` (474) | `CommodityDisplayNameForCommodityArray` Core/OOConstToString.cpp:375 | ✅ |
| `DisplayStringForMassUnit` (479) | `DisplayStringForMassUnit` Core/OOConstToString.cpp:381 | ✅ |
| `DisplayStringForMassUnitForCommodity` (493) | `DisplayStringForMassUnitForCommodity` Core/OOConstToString.cpp:398 | ✅ |
| `StringToRouteType` (498) | `StringToRouteType` Core/OOConstToString.cpp:408 | ✅ |
| `DockingClearanceStatusToString` (507) | `DockingClearanceStatusToString` Core/OOConstToString.cpp:418 (Core/OOTypes.h:227) | ✅ |
| `OOStringFromGraphicsDetail` (520) | `OOStringFromGraphicsDetail` Core/OOConstToString.cpp:425 (Core/OOTypes.h:327) | ✅ |
| `OOGraphicsDetailFromString` (532) | `OOGraphicsDetailFromString` Core/OOConstToString.cpp:430 | ✅ |
| `OOStringFromHDRToneMapper` (542) | `OOStringFromHDRToneMapper` Core/OOConstToString.cpp:441 (SDL/MyOpenGLView.h:191) | ✅ |
| `OOHDRToneMapperFromString` (555) | `OOHDRToneMapperFromString` Core/OOConstToString.cpp:447 | ✅ |
| `OOStringFromSDRToneMapper` (566) | `OOStringFromSDRToneMapper` Core/OOConstToString.cpp:459 (SDL/MyOpenGLView.h:226) | ✅ |
| `OOSDRToneMapperFromString` (581) | `OOSDRToneMapperFromString` Core/OOConstToString.cpp:465 | ✅ |

**Differences:**

- ❌ **low** — the government, economy, rating, legal-status and alert-condition display lookups dereference `UNIVERSE->descriptions()` with no null check; upstream `[[UNIVERSE descriptions] …]` returned nil before the Universe existed. `CommodityDisplayNameForSymbolicName` and `DisplayStringForMassUnitForCommodity` do guard `UNIVERSE`. Only reachable before Universe init (still open) — upstream `Core/OOConstToString.m:208,223,390,415,426` ↔ port `Core/OOConstToString.cpp:145,157,284,309,323`
- ➖ **low** (new) — `JSTypeToString` is gone (the previous audit had a `cxx_JSTypeToString`). Upstream declares it (`OOConstToString.h:85`) but nothing calls it, so no behaviour is lost — upstream `Core/OOConstToString.m:233-247` ↔ port (none)
- ✅ checked (new structure) — the `.tbl` include tables are replaced by per-enum `OOEnumName` switches and `oo::MakeEnumTable` reverse tables (`Core/OOEnumTable.h`). All names were compared with the upstream `.tbl` files and CASE lists (entity status, behaviour [39 names], compass, LRC, galactic hyperspace, GUI screen incl. the commented-out CONTRACTS, scan class, damage type, legal status reason, cargo, energy unit, docking, graphics detail, shader, route, HDR/SDR tone mappers): identical. The `kOO*Default` fallbacks match, the old energy-unit values 15/20 still have no name ("Unsupported energy unit"), `CARGO_CARRIED` and `BEHAVIOR_` aliases are kept — port `Core/Tables/*.h`, `Core/OOTypes.h:54-240`, `Core/OOOpenGL.h:57`, `SDL/MyOpenGLView.h:191,226`
- ✅ subtle — government/economy lookups accept only string elements (as `isKindOfClass:[NSString class]`); rating/legal-status/condition keep `oo_stringAtIndex:` semantics (string or number) via `DescriptionStringAt`; `KillCountToRatingAndKillString` prints `(null)` for a nil rating — upstream `Core/OOConstToString.m:209-212,393,401` ↔ port `Core/OOConstToString.cpp:148-150,132-138,298-299`
- ✅ subtle — `DisplayStringForMassUnit` has an explicit `kUnknown` case falling through to `"??"`, same as upstream's default; no market reads as `UNITS_TONS`, as nil-messaging did — upstream `Core/OOConstToString.m:479-496` ↔ port `Core/OOConstToString.cpp:381-406`

## OOConvertSystemDescriptions

<a id="ooconvertsystemdescriptions"></a>
Upstream `src/Core/OOConvertSystemDescriptions.m` ↔ `Core/OOConvertSystemDescriptions.cpp` (352 / 344 lines)

**Status:** done — 11 rows: 8 ✅ 3 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `CompileSystemDescriptions` (45) | `CompileSystemDescriptions` Core/OOConvertSystemDescriptions.cpp:184 (+ `WriteSystemDescriptions` :177) | ✅ |
| `ExportSystemDescriptions` (94) | `ExportSystemDescriptions` Core/OOConvertSystemDescriptions.cpp:223 | ✅ |
| `OOConvertSystemDescriptionsToArrayFormat` (135) | `OOConvertSystemDescriptionsToArrayFormat` Core/OOConvertSystemDescriptions.cpp:261 | ⚠️ |
| `OOConvertSystemDescriptionsToDictionaryFormat` (177) | `OOConvertSystemDescriptionsToDictionaryFormat` Core/OOConvertSystemDescriptions.cpp:297 | ✅ |
| `OOStringifySystemDescriptionLine` (200) | `OOStringifySystemDescriptionLine` Core/OOConvertSystemDescriptions.cpp:311 (+ `NextBrackets` :103) | ⚠️ |
| `InitKeyToIndexDict` (232) | `InitKeyToIndexDict` Core/OOConvertSystemDescriptions.cpp:55 | ✅ |
| `IndexToKey` (256) | `IndexToKey` Core/OOConvertSystemDescriptions.cpp:68 | ✅ |
| `ConvertIndicesToKeys` (265) | `ConvertIndicesToKeys` Core/OOConvertSystemDescriptions.cpp:150 | ✅ |
| `KeyToIndex` (279) | `KeyToIndex` Core/OOConvertSystemDescriptions.cpp:79 | ✅ |
| `ConvertKeysToIndices` (300) | `ConvertKeysToIndices` Core/OOConvertSystemDescriptions.cpp:114 (+ `NextBrackets` :103) | ⚠️ |
| `HighestIndex` (337) | `HighestIndex` Core/OOConvertSystemDescriptions.cpp:165 | ✅ |

**Differences:**

- ⚠️ **low** — dictionaries are visited in byte-sorted key order instead of hash order, which changes which free slot an unknown key gets and the order of the `sysdesc.compile.unknownKey` lines. Declared in the file-header comment (ADR-0043, bead oo-xh1g) (still open) — upstream `Core/OOConvertSystemDescriptions.m:155,244` ↔ port `Core/OOConvertSystemDescriptions.cpp:41-49,273-283`
- ⚠️ **low** — a malformed line (`[` with no `]` after it, or `]` before `[`) raised NSRangeException upstream; the port stops scanning and keeps the line (header comment) (still open) — upstream `Core/OOConvertSystemDescriptions.m:210-216,314-320` ↔ port `Core/OOConvertSystemDescriptions.cpp:103-112`
- ✅ subtle — `HighestIndex` still returns the highest index (not +1), so the last entry is dropped; upstream bug preserved and commented — upstream `Core/OOConvertSystemDescriptions.m:337-350` ↔ port `Core/OOConvertSystemDescriptions.cpp:162-174`
- ✅ subtle — the unreachable `sysdesc.compile.failed.conversion` branch is gone (the converter never returned nil) — upstream `Core/OOConvertSystemDescriptions.m:67-70` ↔ port `Core/OOConvertSystemDescriptions.cpp:198-199`
- ✅ subtle — `InitKeyToIndexDict` maps only string values, and `IndexToKey` only returns string values (else fallback); the index is still marked used. Lines are scanned in UTF-16 units as `-rangeOfString:` did — upstream `Core/OOConvertSystemDescriptions.m:248,258` ↔ port `Core/OOConvertSystemDescriptions.cpp:61-63,71-74`

## OOEntityFilterPredicate

<a id="ooentityfilterpredicate"></a>
Upstream `src/Core/OOEntityFilterPredicate.m` ↔ `Core/OOEntityFilterPredicate.cpp` (169 / 180 lines)

**Status:** done — 20 rows: 19 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `YESPredicate` (34) | `YESPredicate` Core/OOEntityFilterPredicate.cpp:35 | ✅ |
| `NOPredicate` (39) | `NOPredicate` Core/OOEntityFilterPredicate.cpp:37 | ✅ |
| `NOTPredicate` (44) | `NOTPredicate` Core/OOEntityFilterPredicate.cpp:39 | ✅ |
| `ANDPredicate` (53) | `ANDPredicate` Core/OOEntityFilterPredicate.cpp:47 | ✅ |
| `ORPredicate` (64) | `ORPredicate` Core/OOEntityFilterPredicate.cpp:56 | ✅ |
| `NORPredicate` (75) | `NORPredicate` Core/OOEntityFilterPredicate.cpp:65 | ✅ |
| `XORPredicate` (86) | `XORPredicate` Core/OOEntityFilterPredicate.cpp:74 | ✅ |
| `NANDPredicate` (97) | `NANDPredicate` Core/OOEntityFilterPredicate.cpp:85 | ✅ |
| `HasScanClassPredicate` (108) | `HasScanClassPredicate` Core/OOEntityFilterPredicate.cpp:98 (param is now `OOScanClass*`, not NSNumber) | ✅ |
| `HasClassPredicate` (113) | none (its only caller, `OOEnvironmentCubeMap.m:104`, was not ported) | ➖ |
| `IsShipPredicate` (118) | `IsShipPredicate` Core/OOEntityFilterPredicate.cpp:105 | ✅ |
| `IsStationPredicate` (123) | `IsStationPredicate` Core/OOEntityFilterPredicate.cpp:109 | ✅ |
| `IsPlanetPredicate` (128) | `IsPlanetPredicate` Core/OOEntityFilterPredicate.cpp:113 | ✅ |
| `IsSunPredicate` (136) | `IsSunPredicate` Core/OOEntityFilterPredicate.cpp:120 | ✅ |
| `IsVisualEffectPredicate` (141) | `IsVisualEffectPredicate` Core/OOEntityFilterPredicate.cpp:124 | ✅ |
| `HasRolePredicate` (146) | `HasRolePredicate` Core/OOEntityFilterPredicate.cpp:129 | ✅ |
| `HasPrimaryRolePredicate` (151) | `HasPrimaryRolePredicate` Core/OOEntityFilterPredicate.cpp:137 | ✅ |
| `HasRoleInSetPredicate` (156) | `HasRoleInSetPredicate` Core/OOEntityFilterPredicate.cpp:150 | ✅ |
| `HasPrimaryRoleInSetPredicate` (161) | `HasPrimaryRoleInSetPredicate` Core/OOEntityFilterPredicate.cpp:162 | ✅ |
| `IsHostileAgainstTargetPredicate` (166) | `IsHostileAgainstTargetPredicate` Core/OOEntityFilterPredicate.cpp:174 | ✅ |

**Differences:**

- ➖ **low** — `HasClassPredicate` is removed; its only upstream user (sky lookup, `OOEnvironmentCubeMap.m:104`) has no port counterpart (still open) — upstream `Core/OOEntityFilterPredicate.m:113` ↔ port (none)
- ✅ subtle — `HasRoleInSetPredicate` dereferences `oo::ToShip(ship)` without a null check; upstream's `-roleSet` raised for a non-ship, so both fail there. The role set test is `hasRole` over a `std::vector<std::string>`, equal to `-intersectsSet:` — upstream `Core/OOEntityFilterPredicate.m:158` ↔ port `Core/OOEntityFilterPredicate.cpp:153-159`
- ✅ subtle — `HasPrimaryRolePredicate` with a null role still calls `getPrimaryRole()` for its side effect and returns false, as `[nil isEqual:]`; `HasRolePredicate`/`IsHostile…` on a non-ship return false where upstream raised (unrecognised selector) — upstream `Core/OOEntityFilterPredicate.m:148-168` ↔ port `Core/OOEntityFilterPredicate.cpp:129-179`

## OOEquipmentType

<a id="ooequipmenttype"></a>
Upstream `src/Core/OOEquipmentType.m` ↔ `Core/OOEquipmentType.cpp` (748 / 677 lines)

**Status:** done — 72 rows: 59 ✅ 1 ⚠️ 6 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOEquipmentType loadEquipment]` (50) | `OOEquipmentType::loadEquipment` Core/OOEquipmentType.cpp:112 (+ `EquipmentItems` :78) | ✅ |
| `+[OOEquipmentType addEquipmentWithInfo:]` (104) | `OOEquipmentType::addEquipmentWithInfo` Core/OOEquipmentType.cpp:158 | ✅ |
| `+[OOEquipmentType getMissileRegistryRoleForShip:]` (127) | `OOEquipmentType::getMissileRegistryRoleForShip` Core/OOEquipmentType.cpp:167 | ✅ |
| `+[OOEquipmentType setMissileRegistryRole:forShip:]` (132) | `OOEquipmentType::setMissileRegistryRole` Core/OOEquipmentType.cpp:174 | ✅ |
| `+[OOEquipmentType allEquipmentTypes]` (143) | `OOEquipmentType::allEquipmentTypes` Core/OOEquipmentType.cpp:183 | ✅ |
| `+[OOEquipmentType equipmentEnumerator]` (148) | replaced by iterating `allEquipmentTypes` Core/OOEquipmentType.cpp:183 | ➖ |
| `+[OOEquipmentType reverseEquipmentEnumerator]` (153) | replaced: caller iterates `allEquipmentTypes()` with `rbegin` Core/Entities/PlayerEntity.cpp:8231-8233 | ➖ |
| `+[OOEquipmentType equipmentEnumeratorOutfitting]` (158) | replaced by `allEquipmentTypesOutfitting` Core/OOEquipmentType.cpp:188 | ➖ |
| `+[OOEquipmentType equipmentTypeWithIdentifier:]` (163) | `OOEquipmentType::equipmentTypeWithIdentifier` Core/OOEquipmentType.cpp:193 | ✅ |
| `-[OOEquipmentType initWithInfo:]` (168) | `OOEquipmentType::createWithInfo` / `initWithInfo` Core/OOEquipmentType.cpp:201, :208 (+ `EquipmentKeysFrom` :86) | ⚠️ |
| `-[OOEquipmentType dealloc]` (370) | members are RAII (shared pointers, `std::optional`, `oo::PList`) | ➖ |
| `-[OOEquipmentType copyWithZone:]` (391) | immutable; shared by shared pointer | ➖ |
| `-[OOEquipmentType descriptionComponents]` (397) | `OOEquipmentType::descriptionComponents` Core/OOEquipmentType.cpp:433 | ✅ |
| `-[OOEquipmentType identifier]` (402) | `OOEquipmentType::identifier` Core/OOEquipmentType.cpp:447 | ✅ |
| `-[OOEquipmentType damagedIdentifier]` (407) | `OOEquipmentType::damagedIdentifier` Core/OOEquipmentType.cpp:449 | ✅ |
| `-[OOEquipmentType name]` (412) | `OOEquipmentType::name` Core/OOEquipmentType.cpp:453 | ✅ |
| `-[OOEquipmentType descriptiveText]` (417) | `OOEquipmentType::descriptiveText` Core/OOEquipmentType.cpp:455 | ✅ |
| `-[OOEquipmentType techLevel]` (422) | `OOEquipmentType::techLevel` Core/OOEquipmentType.cpp:459 | ✅ |
| `-[OOEquipmentType price]` (427) | `OOEquipmentType::price` Core/OOEquipmentType.cpp:461 | ✅ |
| `-[OOEquipmentType isAvailableToAll]` (432) | `OOEquipmentType::isAvailableToAll` Core/OOEquipmentType.cpp:463 | ✅ |
| `-[OOEquipmentType requiresEmptyPylon]` (437) | `OOEquipmentType::requiresEmptyPylon` Core/OOEquipmentType.cpp:465 | ✅ |
| `-[OOEquipmentType requiresMountedPylon]` (442) | `OOEquipmentType::requiresMountedPylon` Core/OOEquipmentType.cpp:467 | ✅ |
| `-[OOEquipmentType requiresCleanLegalRecord]` (447) | `OOEquipmentType::requiresCleanLegalRecord` Core/OOEquipmentType.cpp:469 | ✅ |
| `-[OOEquipmentType requiresNonCleanLegalRecord]` (452) | `OOEquipmentType::requiresNonCleanLegalRecord` Core/OOEquipmentType.cpp:471 | ✅ |
| `-[OOEquipmentType requiresFreePassengerBerth]` (457) | `OOEquipmentType::requiresFreePassengerBerth` Core/OOEquipmentType.cpp:475 | ✅ |
| `-[OOEquipmentType requiresFullFuel]` (462) | `OOEquipmentType::requiresFullFuel` Core/OOEquipmentType.cpp:479 | ✅ |
| `-[OOEquipmentType requiresNonFullFuel]` (467) | `OOEquipmentType::requiresNonFullFuel` Core/OOEquipmentType.cpp:481 | ✅ |
| `-[OOEquipmentType isPrimaryWeapon]` (472) | `OOEquipmentType::isPrimaryWeapon` Core/OOEquipmentType.cpp:483 | ✅ |
| `-[OOEquipmentType isMissileOrMine]` (477) | `OOEquipmentType::isMissileOrMine` Core/OOEquipmentType.cpp:487 | ✅ |
| `-[OOEquipmentType isPortableBetweenShips]` (482) | `OOEquipmentType::isPortableBetweenShips` Core/OOEquipmentType.cpp:489 | ✅ |
| `-[OOEquipmentType canCarryMultiple]` (487) | `OOEquipmentType::canCarryMultiple` Core/OOEquipmentType.cpp:491 | ✅ |
| `-[OOEquipmentType damageProbability]` (504) | `OOEquipmentType::damageProbability` Core/OOEquipmentType.cpp:504 | ✅ |
| `-[OOEquipmentType canBeDamaged]` (512) | `OOEquipmentType::canBeDamaged` Core/OOEquipmentType.cpp:510 | ✅ |
| `-[OOEquipmentType isVisible]` (524) | `OOEquipmentType::isVisible` Core/OOEquipmentType.cpp:520 | ✅ |
| `-[OOEquipmentType hideValues]` (529) | `OOEquipmentType::hideValues` Core/OOEquipmentType.cpp:522 | ✅ |
| `-[OOEquipmentType isAvailableToPlayer]` (534) | `OOEquipmentType::isAvailableToPlayer` Core/OOEquipmentType.cpp:524 | ✅ |
| `-[OOEquipmentType isAvailableToNPCs]` (539) | `OOEquipmentType::isAvailableToNPCs` Core/OOEquipmentType.cpp:526 | ✅ |
| `-[OOEquipmentType requiredCargoSpace]` (544) | `OOEquipmentType::requiredCargoSpace` Core/OOEquipmentType.cpp:528 | ✅ |
| `-[OOEquipmentType requiresEquipment]` (549) | `OOEquipmentType::requiresEquipment` Core/OOEquipmentType.cpp:532 | ✅ |
| `-[OOEquipmentType requiresAnyEquipment]` (554) | `OOEquipmentType::requiresAnyEquipment` Core/OOEquipmentType.cpp:536 | ✅ |
| `-[OOEquipmentType incompatibleEquipment]` (559) | `OOEquipmentType::incompatibleEquipment` Core/OOEquipmentType.cpp:541 | ✅ |
| `-[OOEquipmentType displayColor]` (564) | `OOEquipmentType::displayColor` Core/OOEquipmentType.cpp:546 | ✅ |
| `-[OOEquipmentType setDisplayColor:]` (569) | `OOEquipmentType::setDisplayColor` Core/OOEquipmentType.cpp:550 | ✅ |
| `-[OOEquipmentType conditions]` (575) | `OOEquipmentType::conditions` Core/OOEquipmentType.cpp:554 | ✅ |
| `-[OOEquipmentType conditionScript]` (580) | `OOEquipmentType::conditionScript` Core/OOEquipmentType.cpp:556 | ✅ |
| `-[OOEquipmentType scriptInfo]` (585) | `OOEquipmentType::scriptInfo` Core/OOEquipmentType.cpp:560 | ✅ |
| `-[OOEquipmentType scriptName]` (590) | `OOEquipmentType::scriptName` Core/OOEquipmentType.cpp:562 | ✅ |
| `-[OOEquipmentType fastAffinityDefensive]` (595) | `OOEquipmentType::fastAffinityDefensive` Core/OOEquipmentType.cpp:564 | ✅ |
| `-[OOEquipmentType fastAffinityOffensive]` (600) | `OOEquipmentType::fastAffinityOffensive` Core/OOEquipmentType.cpp:566 | ✅ |
| `-[OOEquipmentType defaultActivateKey]` (605) | `OOEquipmentType::defaultActivateKey` Core/OOEquipmentType.cpp:568 | ✅ |
| `-[OOEquipmentType defaultModeKey]` (610) | `OOEquipmentType::defaultModeKey` Core/OOEquipmentType.cpp:570 | ✅ |
| `-[OOEquipmentType installTime]` (615) | `OOEquipmentType::installTime` Core/OOEquipmentType.cpp:572 | ✅ |
| `-[OOEquipmentType repairTime]` (620) | `OOEquipmentType::repairTime` Core/OOEquipmentType.cpp:574 | ✅ |
| `-[OOEquipmentType providesForScripting]` (629) | `OOEquipmentType::providesForScripting` Core/OOEquipmentType.cpp:582 | ❌ |
| `-[OOEquipmentType provides:]` (634) | `OOEquipmentType::provides` Core/OOEquipmentType.cpp:586 | ✅ |
| `-[OOEquipmentType isTurretLaser]` (640) | `OOEquipmentType::isTurretLaser` Core/OOEquipmentType.cpp:591 | ✅ |
| `-[OOEquipmentType isMiningLaser]` (645) | `OOEquipmentType::isMiningLaser` Core/OOEquipmentType.cpp:595 | ✅ |
| `-[OOEquipmentType weaponInfo]` (650) | `OOEquipmentType::weaponInfo` Core/OOEquipmentType.cpp:599 | ✅ |
| `-[OOEquipmentType weaponRange]` (655) | `OOEquipmentType::weaponRange` Core/OOEquipmentType.cpp:601 | ✅ |
| `-[OOEquipmentType weaponEnergyUse]` (660) | `OOEquipmentType::weaponEnergyUse` Core/OOEquipmentType.cpp:605 | ✅ |
| `-[OOEquipmentType weaponDamage]` (665) | `OOEquipmentType::weaponDamage` Core/OOEquipmentType.cpp:609 | ✅ |
| `-[OOEquipmentType weaponRechargeRate]` (670) | `OOEquipmentType::weaponRechargeRate` Core/OOEquipmentType.cpp:613 | ✅ |
| `-[OOEquipmentType weaponShotTemperature]` (675) | `OOEquipmentType::weaponShotTemperature` Core/OOEquipmentType.cpp:617 | ✅ |
| `-[OOEquipmentType weaponThreatAssessment]` (680) | `OOEquipmentType::weaponThreatAssessment` Core/OOEquipmentType.cpp:621 | ✅ |
| `-[OOEquipmentType weaponColor]` (685) | `OOEquipmentType::weaponColor` Core/OOEquipmentType.cpp:625 | ✅ |
| `-[OOEquipmentType fxShotMissName]` (690) | `OOEquipmentType::fxShotMissName` Core/OOEquipmentType.cpp:632 | ❌ |
| `-[OOEquipmentType fxShotHitName]` (695) | `OOEquipmentType::fxShotHitName` Core/OOEquipmentType.cpp:636 | ❌ |
| `-[OOEquipmentType fxShieldHitName]` (700) | `OOEquipmentType::fxShieldHitName` Core/OOEquipmentType.cpp:640 | ❌ |
| `-[OOEquipmentType fxUnshieldedHitName]` (705) | `OOEquipmentType::fxUnshieldedHitName` Core/OOEquipmentType.cpp:645 | ❌ |
| `-[OOEquipmentType fxWeaponLaunchedName]` (710) | `OOEquipmentType::fxWeaponLaunchedName` Core/OOEquipmentType.cpp:650 | ❌ |
| `-[OOEquipmentType suppressClangStuff]` (720) | not needed (analyzer workaround; JS self kept as a weak reference, Core/OOEquipmentType.h:214-215) | ➖ |
| `-[OOEquipmentType(Conveniences) effectiveTechLevel]` (731) | `OOEquipmentType::effectiveTechLevel` Core/OOEquipmentType.cpp:657 | ✅ |

**Differences:**

- ❌ **low** — the `fx*Name` getters lose nil-messaging for an entry without an extra-info dictionary: upstream `_weaponInfo` stays nil, so `oo_stringForKey:defaultValue:` sent to nil returns nil; the port's `_weaponInfo` is a null PList (header comment says "empty by default", but there is no initialiser) and `StringFor` returns the fallback when `find` fails, giving `[player-laser-miss]`, `[missile-launched]` etc. where upstream gave nil (still open) — upstream `Core/OOEquipmentType.m:214,245,690-713` ↔ port `Core/OOEquipmentType.cpp:59-66,632-655`, `Core/OOEquipmentType.h:211`
- ❌ **low** — `providesForScripting` with no extra dict returns nil upstream (JS `provides` is null); the port always returns a vector and the JS getter builds `[]`. Non-string `provides` elements, which upstream passed through, are dropped at load (still open) — upstream `Core/OOEquipmentType.m:240,629-632` ↔ port `Core/OOEquipmentType.cpp:302-308,582`, `Core/Scripting/OOJSEquipmentInfo.cpp:423-427`
- ⚠️ **low** — `requires_equipment`, `requires_any_equipment` and `incompatible_with_equipment` became a sorted, de-duplicated `std::vector<std::string>` instead of `NSSet` (commented "was a set"); non-string elements dropped, JS-visible order lexical rather than hash order; containment unchanged (still open) — upstream `Core/OOEquipmentType.m:249-274` ↔ port `Core/OOEquipmentType.cpp:55-109,323-328`
- ✅ checked — the `weapon*` numeric and `is*Laser` getters keep nil semantics: `get<T>` on a null PList returns the zero of T, not the fallback (`oofnd/PListGet.hpp:38-39`), as `[nil oo_floatForKey:…]` did; `weaponColor` on nil gives nil — upstream `Core/OOEquipmentType.m:640-688` ↔ port `Core/OOEquipmentType.cpp:591-630`
- ✅ subtle — `loadEquipment`: upstream's outfitting loop wrote into an already-copied `equipmentTypesByIdentifier` (a no-op), and the port drops it; condition scripts keep first-seen order and the last duplicate identifier wins — upstream `Core/OOEquipmentType.m:94-100` ↔ port `Core/OOEquipmentType.cpp:146-155`
- ✅ subtle — the `default_activate_key`/`default_mode_key` checks and log texts are unchanged, including the trailing "." on the mode message only — upstream `Core/OOEquipmentType.m:322-358` ↔ port `Core/OOEquipmentType.cpp:385-425`

## OOOXZManager

<a id="oooxzmanager"></a>
Upstream `src/Core/OOOXZManager.m` ↔ `Core/OOOXZManager.cpp` (2066 / 2579 lines)

**Status:** done — 72 rows: 62 ✅ 4 ⚠️ 3 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| URL / filename constants `kOOOXZDataURL`… (51) (added) | anon-namespace constants `Core/OOOXZManager.cpp:85` (same URL, config key, cache/tmp names) | ✅ |
| filter constants `kOOOXZFilterAll`… (66) (added) | `constexpr std::string_view` `Core/OOOXZManager.cpp:103` | ✅ |
| `OXZ_GUI_ROW_*` enum (88) (added) | `constexpr int` rows `Core/OOOXZManager.cpp:115` (values match) | ✅ |
| `+[OOOXZManager sharedManager]` (176) | `OOOXZManager::sharedManager` `Core/OOOXZManager.cpp:313` | ✅ |
| `-[OOOXZManager init]` (184) | `OOOXZManager::init` `Core/OOOXZManager.cpp:327` (same field defaults, filter "*") | ✅ |
| `-[OOOXZManager dealloc]` (204) | `OOOXZManager::~OOOXZManager` `Core/OOOXZManager.cpp:344` | ✅ |
| `-[OOOXZManager installPath]` (220) | `installPath` → `oo::ResourcePaths::managedAddOnsDirectory` `Core/OOOXZManager.cpp:353` | ➖ |
| `-[OOOXZManager extractAddOnsPath]` (246) | `extractAddOnsPath` → `oo::ResourcePaths::extractAddOnsDirectory` `Core/OOOXZManager.cpp:363` | ➖ |
| `-[OOOXZManager additionalAddOnsPaths]` (266) | `additionalAddOnsPaths` → `oo::ResourcePaths::additionalAddOnsDirectories` `Core/OOOXZManager.cpp:372` | ➖ |
| `-[OOOXZManager extractionBasePathForIdentifier:andVersion:]` (277) | `extractionBasePathForIdentifier` `Core/OOOXZManager.cpp:381` (same blacklist; nil basePath → nullopt) | ✅ |
| `-[OOOXZManager ensureInstallPath]` (286) | `ensureInstallPath` `Core/OOOXZManager.cpp:397` (same two logs) | ✅ |
| `-[OOOXZManager manifestPath]` (308) | `manifestPath` `Core/OOOXZManager.cpp:419` | ✅ |
| `-[OOOXZManager downloadPath]` (316) | `downloadPath` `Core/OOOXZManager.cpp:430` | ✅ |
| `-[OOOXZManager dataURL]` (325) | `dataURL` `Core/OOOXZManager.cpp:442` | ✅ |
| `-[OOOXZManager humanSize:]` (335) | `humanSize` `Core/OOOXZManager.cpp:452` (same thresholds, `%.2f` float) | ✅ |
| `-[OOOXZManager setOXZList:]` (348) | `setOXZList` `Core/OOOXZManager.cpp:466` | ✅ |
| `-[OOOXZManager setFilteredList:]` (358) | `setFilteredList` `Core/OOOXZManager.cpp:479` | ✅ |
| `-[OOOXZManager setFilter:]` (364) | `setFilter` `Core/OOOXZManager.cpp:483` | ✅ |
| `-[OOOXZManager setOXPURL:]` (370) | `setOXPURL` `Core/OOOXZManager.cpp:487` | ✅ |
| `-[OOOXZManager applyCurrentFilter:]` (376) | `applyCurrentFilter` (member-function pointers for NSInvocation) `Core/OOOXZManager.cpp:493` | ✅ |
| `-[OOOXZManager applyFilterByNoFilter:]` (425) | `applyFilterByNoFilter` `Core/OOOXZManager.cpp:544` | ✅ |
| `-[OOOXZManager applyFilterByUpdateRequired:]` (430) | `applyFilterByUpdateRequired` `Core/OOOXZManager.cpp:546` | ✅ |
| `-[OOOXZManager applyFilterByInstallable:]` (435) | `applyFilterByInstallable` `Core/OOOXZManager.cpp:551` | ✅ |
| `-[OOOXZManager applyFilterByKeyword:keyword:]` (440) | `applyFilterByKeyword` + `FoundIgnoringCase` `Core/OOOXZManager.cpp:556` (nil haystack matches, as upstream) | ✅ |
| `-[OOOXZManager applyFilterByAuthor:author:]` (464) | `applyFilterByAuthor` `Core/OOOXZManager.cpp:574` | ✅ |
| `-[OOOXZManager applyFilterByDays:days:]` (473) | `applyFilterByDays` `Core/OOOXZManager.cpp:583` (same 86400·i unsigned sum) | ✅ |
| `-[OOOXZManager applyFilterByTag:tag:]` (485) | `applyFilterByTag` → `TagFoundIgnoringCase` `Core/OOOXZManager.cpp:598` | ✅ |
| `-[OOOXZManager applyFilterByCategory:category:]` (502) | `applyFilterByCategory` `Core/OOOXZManager.cpp:605` | ✅ |
| `-[OOOXZManager validateFilter:]` (513) | `validateFilter` `Core/OOOXZManager.cpp:617` | ✅ |
| `-[OOOXZManager setCurrentDownload:withLabel:]` (531) | `setCurrentDownload` `Core/OOOXZManager.cpp:639` | ✅ |
| `-[OOOXZManager setProgressStatus:]` (541) | `setProgressStatus` `Core/OOOXZManager.cpp:647` | ✅ |
| `-[OOOXZManager updateManifests]` (547) | `updateManifests` `Core/OOOXZManager.cpp:651` | ✅ |
| `-[OOOXZManager beginDownload:]` (560) | `beginDownload` `Core/OOOXZManager.cpp:663` | ❌ |
| (NSURLConnection run-loop delegate delivery) (added) | `processDownloadEvents` `Core/OOOXZManager.cpp:690` | ⚠️ |
| `-[OOOXZManager cancelUpdate]` (588) | `cancelUpdate` `Core/OOOXZManager.cpp:716` | ✅ |
| `-[OOOXZManager manifests]` (610) | `manifests` `Core/OOOXZManager.cpp:741` | ✅ |
| `-[OOOXZManager managedOXZs]` (615) | `managedOXZs` `Core/OOOXZManager.cpp:743` | ⚠️ |
| `-[OOOXZManager processDownloadedManifests]` (660) | `processDownloadedManifests` `Core/OOOXZManager.cpp:808` | ✅ |
| `-[OOOXZManager processDownloadedOXZ]` (686) | `processDownloadedOXZ` `Core/OOOXZManager.cpp:841` | ⚠️ |
| `-[OOOXZManager installedManifestForIdentifier:]` (885) | `installedManifestForIdentifier` `Core/OOOXZManager.cpp:1105` | ✅ |
| `-[OOOXZManager installableState:]` (897) | `installableState` `Core/OOOXZManager.cpp:1119` (same check order and states) | ✅ |
| `-[OOOXZManager colorForManifest:]` (951) | `colorForManifest` `Core/OOOXZManager.cpp:1204` | ✅ |
| `-[OOOXZManager installStatusForManifest:]` (974) | `installStatusForManifest` `Core/OOOXZManager.cpp:1227` | ✅ |
| `-[OOOXZManager gui]` (997) | `gui` `Core/OOOXZManager.cpp:1356` (null-guarded; rows/keys/startRow same) | ✅ |
| `-[OOOXZManager isRestarting]` (1195) | `isRestarting` `Core/OOOXZManager.cpp:1250` | ✅ |
| `-[OOOXZManager processSelection]` (1211) | `processSelection` `Core/OOOXZManager.cpp:1672` | ✅ |
| `-[OOOXZManager isAcceptingTextInput]` (1301) | `isAcceptingTextInput` `Core/OOOXZManager.cpp:1764` | ✅ |
| `-[OOOXZManager isAcceptingGUIInput]` (1306) | `isAcceptingGUIInput` `Core/OOOXZManager.cpp:1768` | ✅ |
| `-[OOOXZManager processTextInput:]` (1311) | `processTextInput` `Core/OOOXZManager.cpp:1770` | ✅ |
| `-[OOOXZManager refreshTextInput:]` (1323) | `refreshTextInput` `Core/OOOXZManager.cpp:1781` | ✅ |
| `-[OOOXZManager processFilterKey]` (1334) | `processFilterKey` `Core/OOOXZManager.cpp:1796` | ✅ |
| `-[OOOXZManager processShowInfoKey]` (1347) | `processShowInfoKey` `Core/OOOXZManager.cpp:1812` | ✅ |
| `-[OOOXZManager processCopyUrlKey]` (1417) | `processCopyUrlKey` `Core/OOOXZManager.cpp:1904` | ✅ |
| `-[OOOXZManager processExtractKey]` (1443) | `processExtractKey` `Core/OOOXZManager.cpp:1937` | ✅ |
| `-[OOOXZManager installOXZ:]` (1462) | `installOXZ` `Core/OOOXZManager.cpp:1265` | ❌ |
| `-[OOOXZManager updateAllOXZ]` (1493) | `updateAllOXZ` `Core/OOOXZManager.cpp:1299` | ⚠️ |
| `-[OOOXZManager installOptions]` (1519) | `installOptions` `Core/OOOXZManager.cpp:1958` | ✅ |
| `-[OOOXZManager showInstallOptions]` (1533) | `showInstallOptions` `Core/OOOXZManager.cpp:1972` (tab stops, columns, local-path re-read same) | ✅ |
| `-[OOOXZManager removeOXZ:]` (1679) | `removeOXZ` `Core/OOOXZManager.cpp:1331` | ✅ |
| `-[OOOXZManager removeOptions]` (1703) | `removeOptions` `Core/OOOXZManager.cpp:2182` | ✅ |
| `-[OOOXZManager showRemoveOptions]` (1721) | `showRemoveOptions` `Core/OOOXZManager.cpp:2199` (keeps managedOXZs-count quirk) | ✅ |
| `-[OOOXZManager showOptionsUpdate]` (1815) | `showOptionsUpdate` `Core/OOOXZManager.cpp:2317` | ✅ |
| `-[OOOXZManager showOptionsPrev]` (1831) | `showOptionsPrev` `Core/OOOXZManager.cpp:2331` | ✅ |
| `-[OOOXZManager processOptionsPrev]` (1841) | `processOptionsPrev` `Core/OOOXZManager.cpp:2342` | ✅ |
| `-[OOOXZManager processOptionsNext]` (1851) | `processOptionsNext` `Core/OOOXZManager.cpp:2351` | ✅ |
| `-[OOOXZManager showOptionsNext]` (1860) | `showOptionsNext` `Core/OOOXZManager.cpp:2359` | ✅ |
| `-[OOOXZManager extractOXZ:]` (1870) | `extractOXZ` `Core/OOOXZManager.cpp:2370` | ❌ |
| `-[OOOXZManager connection:didReceiveResponse:]` (1979) | `downloadDidReceiveResponse` `Core/OOOXZManager.cpp:2490` | ✅ |
| `-[OOOXZManager connection:didReceiveData:]` (1995) | `downloadDidReceiveData` `Core/OOOXZManager.cpp:2510` | ✅ |
| `-[OOOXZManager connectionDidFinishLoading:]` (2022) | `downloadDidFinishLoading` `Core/OOOXZManager.cpp:2543` | ✅ |
| `-[OOOXZManager connection:didFailWithError:]` (2044) | `downloadDidFailWithError` `Core/OOOXZManager.cpp:2570` | ✅ |
| `oxzSort` (2056) | `OXZOrderedBefore` (predicate for `std::stable_sort`) `Core/OOOXZManager.cpp:198` | ✅ |

**Differences:**

- ❌ **low** — `beginDownload` can no longer fail. Upstream returned NO, logged `oxz.manager.error` "Unable to start downloading file at …" and set `OXZ_DOWNLOAD_ERROR` when `NSURLConnection` could not be created. The port always builds `oo::http::Download` and returns true, so the failure arrives later as "Error downloading file: …" (still open) — upstream `Core/OOOXZManager.m:565-585` ↔ port `Core/OOOXZManager.cpp:670-687`
- ❌ **low** — `installOXZ` with a non-string `download_url`: upstream `+[NSURL URLWithString:]` gave a nil URL and the request failed to start. The port turns it into `""` and starts a download that fails through the event path (still open) — upstream `Core/OOOXZManager.m:1477-1490` ↔ port `Core/OOOXZManager.cpp:1279-1296`
- ❌ **low** — `extractOXZ` builds its directory with `identifier.value_or("")`/`version.value_or("")` (giving `-.off`), while `gui()`'s EXTRACT screen uses `"(null)"` as upstream's `%@` did in both places. A manifest missing either field extracts somewhere other than the path shown. With no user root path the port also returns "main-unmakeable" without upstream's "Path (null) could not be created" log (still open) — upstream `Core/OOOXZManager.m:1875-1909` ↔ port `Core/OOOXZManager.cpp:2377-2401` (vs `:1588`)
- ⚠️ **med** — `_dependencyStack` is an insertion-ordered `std::vector` read with `front()`, not an `NSMutableSet` read with `-anyObject`. Which unmet dependency is offered or downloaded first, and which OXZ "update all" starts with, can differ from upstream hash order. Justified only by a comment ("order-sensitive — named in commit"), no ADR or bead (still open) — upstream `Core/OOOXZManager.m:799`, `:1506` ↔ port `Core/OOOXZManager.cpp:993-995`, `:1311-1317`
- ⚠️ **low** — `managedOXZs`: an index entry with no `version`/`download_url` made upstream's `-setObject:nil forKey:` raise; the port skips the key, with a comment (still open) — upstream `Core/OOOXZManager.m:641-642` ↔ port `Core/OOOXZManager.cpp:778-789`
- ⚠️ **low** — Download delivery: `GameController` polls `processDownloadEvents()` in place of the NSURLConnection delegates, with the download on its own thread (proposed ADR-0044); the Windows `limitDateForMode:` call becomes `GameController::fireDueTimers()` (proposed ADR-0033). Callback order is the same (still open) — upstream `Core/OOOXZManager.m:1979-2051` ↔ port `Core/OOOXZManager.cpp:690-714`, `:2539`
- ➖ — `installPath`, `extractAddOnsPath`, `additionalAddOnsPaths` moved into `oo::ResourcePaths` (env vars and platform defaults; covered by the oofnd audit) (still open) — upstream `Core/OOOXZManager.m:220-275` ↔ port `Core/OOOXZManager.cpp:353-379`
- ✅ **low** (note, new) — `processDownloadedOXZ` reads the downloaded `manifest.plist` with `OOPropertyListFromFile`, not `OODictionaryFromFile`. A non-dictionary manifest is reported as "does not have the same identifer and version" instead of "does not contain a manifest.plist"; it fails either way — upstream `Core/OOOXZManager.m:692-699` ↔ port `Core/OOOXZManager.cpp:847-852`
- ✅ **low** (note) — Sorting uses `std::stable_sort` + `oo::str::localizedCompare`; same keys, `"zz"`/`"0"` defaults and descending version. Only full ties can order differently — upstream `Core/OOOXZManager.m:2056-2066` ↔ port `Core/OOOXZManager.cpp:198-213`
- ✅ **low** (note) — Case-insensitive filters fold UTF-16 units with `oo::str::toLower` rather than `NSCaseInsensitiveSearch`; non-ASCII special cases (e.g. ß) may differ. The nil-haystack-matches quirk is kept — upstream `Core/OOOXZManager.m:449`, `:470` ↔ port `Core/OOOXZManager.cpp:156-163`

## OOProbabilitySet

<a id="ooprobabilityset"></a>
Upstream `src/Core/OOProbabilitySet.m` ↔ `Core/OOProbabilitySet.cpp` (957 / 723 lines)

**Status:** done — 81 rows: 53 ✅ 0 ⚠️ 3 ❌ 25 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOProbabilitySet probabilitySet]` (121) | `OOProbabilitySet::probabilitySet` `Core/OOProbabilitySet.cpp:200` | ✅ |
| `+[OOProbabilitySet probabilitySetWithObjects:weights:count:]` (126) | `OOProbabilitySet::probabilitySetWithObjects` `Core/OOProbabilitySet.cpp:204` | ✅ |
| `+[OOProbabilitySet probabilitySetWithPropertyListRepresentation:]` (131) | `OOProbabilitySet::probabilitySetWithPropertyListRepresentation` `Core/OOProbabilitySet.cpp:235` | ✅ |
| `-[OOProbabilitySet init]` (136) | folded into `probabilitySet` `Core/OOProbabilitySet.cpp:200` | ✅ |
| `-[OOProbabilitySet initWithObjects:weights:count:]` (142) | folded into `probabilitySetWithObjects` `Core/OOProbabilitySet.cpp:204` (0 → empty, NULL raise, 1 → single, else concrete) | ✅ |
| `-[OOProbabilitySet initWithPropertyListRepresentation:]` (164) | folded into `probabilitySetWithPropertyListRepresentation` `Core/OOProbabilitySet.cpp:235` (array checks, `fmax(w,0)`) | ✅ |
| `-[OOProbabilitySet initPriv]` (212) | — (C++ constructors) | ➖ |
| `-[OOProbabilitySet descriptionComponents]` (217) | `OOProbabilitySet::descriptionComponents` `Core/OOProbabilitySet.cpp:274` | ✅ |
| `-[OOProbabilitySet propertyListRepresentation]` (222) | pure virtual `Core/OOProbabilitySet.h:82` | ➖ |
| `-[OOProbabilitySet randomObject]` (227) | pure virtual `Core/OOProbabilitySet.h:85` | ➖ |
| `-[OOProbabilitySet weightForObject:]` (232) | pure virtual `Core/OOProbabilitySet.h:88` | ➖ |
| `-[OOProbabilitySet sumOfWeights]` (237) | pure virtual `Core/OOProbabilitySet.h:90` | ➖ |
| `-[OOProbabilitySet count]` (242) | pure virtual `Core/OOProbabilitySet.h:84` | ➖ |
| `-[OOProbabilitySet allObjects]` (247) | pure virtual `allElements` `Core/OOProbabilitySet.h:91` | ➖ |
| `-[OOProbabilitySet copyWithZone:]` (252) | `OOProbabilitySet::copy` `Core/OOProbabilitySet.cpp:280` | ✅ |
| `-[OOProbabilitySet mutableCopyWithZone:]` (261) | `OOProbabilitySet::mutableCopy` `Core/OOProbabilitySet.cpp:286` | ✅ |
| `-[OOProbabilitySet(OOExtendedProbabilitySet) containsObject:]` (270) | `containsObject` `Core/OOProbabilitySet.cpp:293` | ✅ |
| `-[OOProbabilitySet(OOExtendedProbabilitySet) objectEnumerator]` (275) | — replaced by `allElements()` `Core/OOProbabilitySet.h:91` | ➖ |
| `-[OOProbabilitySet(OOExtendedProbabilitySet) probabilityForObject:]` (280) | `probabilityForObject` `Core/OOProbabilitySet.cpp:297` | ✅ |
| `+[OOEmptyProbabilitySet singleton]` (295) | `OOEmptyProbabilitySet::singleton` `Core/OOProbabilitySet.cpp:309` | ✅ |
| `-[OOEmptyProbabilitySet propertyListRepresentation]` (304) | `OOEmptyProbabilitySet::propertyListRepresentation` `Core/OOProbabilitySet.cpp:324` | ✅ |
| `-[OOEmptyProbabilitySet randomObject]` (310) | `OOEmptyProbabilitySet::randomObject` `Core/OOProbabilitySet.cpp:328` | ✅ |
| `-[OOEmptyProbabilitySet weightForObject:]` (315) | `OOEmptyProbabilitySet::weightForObject` `Core/OOProbabilitySet.cpp:330` | ✅ |
| `-[OOEmptyProbabilitySet sumOfWeights]` (320) | `OOEmptyProbabilitySet::sumOfWeights` `Core/OOProbabilitySet.cpp:334` | ✅ |
| `-[OOEmptyProbabilitySet count]` (325) | `OOEmptyProbabilitySet::count` `Core/OOProbabilitySet.cpp:336` | ✅ |
| `-[OOEmptyProbabilitySet allObjects]` (330) | `OOEmptyProbabilitySet::allElements` `Core/OOProbabilitySet.cpp:338` | ✅ |
| `-[OOEmptyProbabilitySet mutableCopyWithZone:]` (335) | `OOEmptyProbabilitySet::mutableCopy` `Core/OOProbabilitySet.cpp:342` | ✅ |
| `+[OOEmptyProbabilitySet(Singleton) allocWithZone:]` (352) | — immortal heap singleton `Core/OOProbabilitySet.cpp:309-322` | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) copyWithZone:]` (361) | — base `copy` returns `this` `Core/OOProbabilitySet.cpp:280` | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) retain]` (366) | — (shared_ptr never deleted) | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) retainCount]` (371) | — | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) release]` (376) | — | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) autorelease]` (380) | — | ➖ |
| `-[OOSingleObjectProbabilitySet initWithObject:weight:]` (389) | `OOSingleObjectProbabilitySet::initWithObject` `Core/OOProbabilitySet.cpp:348` | ✅ |
| `-[OOSingleObjectProbabilitySet dealloc]` (404) | — (implicit destructor) | ➖ |
| `-[OOSingleObjectProbabilitySet propertyListRepresentation]` (411) | `propertyListRepresentation` `Core/OOProbabilitySet.cpp:360` | ✅ |
| `-[OOSingleObjectProbabilitySet randomObject]` (419) | `randomObject` `Core/OOProbabilitySet.cpp:364` | ✅ |
| `-[OOSingleObjectProbabilitySet weightForObject:]` (424) | `weightForObject` `Core/OOProbabilitySet.cpp:366` (PList `==`, see bullet) | ✅ |
| `-[OOSingleObjectProbabilitySet sumOfWeights]` (432) | `sumOfWeights` `Core/OOProbabilitySet.cpp:373` | ✅ |
| `-[OOSingleObjectProbabilitySet count]` (437) | `count` `Core/OOProbabilitySet.cpp:375` | ✅ |
| `-[OOSingleObjectProbabilitySet allObjects]` (442) | `allElements` `Core/OOProbabilitySet.cpp:377` | ✅ |
| `-[OOSingleObjectProbabilitySet mutableCopyWithZone:]` (447) | `mutableCopy` `Core/OOProbabilitySet.cpp:381` | ✅ |
| `-[OOConcreteProbabilitySet initWithObjects:weights:count:]` (456) | `OOConcreteProbabilitySet::initWithObjects` `Core/OOProbabilitySet.cpp:386` (float cumulative sum, same order) | ✅ |
| `-[OOConcreteProbabilitySet dealloc]` (485) | `~OOConcreteProbabilitySet` `Core/OOProbabilitySet.cpp:416` | ✅ |
| `-[OOConcreteProbabilitySet propertyListRepresentation]` (505) | `propertyListRepresentation` `Core/OOProbabilitySet.cpp:418` | ✅ |
| `-[OOConcreteProbabilitySet count]` (526) | `count` `Core/OOProbabilitySet.cpp:433` | ✅ |
| `-[OOConcreteProbabilitySet privObjectForWeight:]` (531) | `privObjectForWeight` `Core/OOProbabilitySet.cpp:435` (verbatim binary search) | ✅ |
| `-[OOConcreteProbabilitySet randomObject]` (568) | `randomObject` `Core/OOProbabilitySet.cpp:467` | ✅ |
| `-[OOConcreteProbabilitySet weightForObject:]` (575) | `weightForObject` `Core/OOProbabilitySet.cpp:472` | ❌ |
| `-[OOConcreteProbabilitySet sumOfWeights]` (595) | `sumOfWeights` `Core/OOProbabilitySet.cpp:491` | ✅ |
| `-[OOConcreteProbabilitySet allObjects]` (600) | `allElements` `Core/OOProbabilitySet.cpp:493` | ✅ |
| `-[OOConcreteProbabilitySet objectEnumerator]` (605) | — replaced by `allElements()` | ➖ |
| `-[OOConcreteProbabilitySet privObjectAtIndex:]` (610) | — (enumerator gone) | ➖ |
| `-[OOConcreteProbabilitySet mutableCopyWithZone:]` (615) | `mutableCopy` `Core/OOProbabilitySet.cpp:497` | ✅ |
| `+[OOMutableProbabilitySet probabilitySet]` (643) | `OOMutableProbabilitySet::probabilitySet` `Core/OOProbabilitySet.cpp:518` | ✅ |
| `-[OOMutableProbabilitySet init]` (648) | folded into `OOMutableProbabilitySet::probabilitySet` `Core/OOProbabilitySet.cpp:518` | ✅ |
| `-[OOMutableProbabilitySet initWithObjects:weights:count:]` (655) | `OOMutableProbabilitySet::probabilitySetWithObjects` `Core/OOProbabilitySet.cpp:523` | ✅ |
| `-[OOMutableProbabilitySet initWithPropertyListRepresentation:]` (662) | `OOMutableProbabilitySet::probabilitySetWithPropertyListRepresentation` `Core/OOProbabilitySet.cpp:530` | ✅ |
| `-[OOMutableProbabilitySet copyWithZone:]` (669) | `OOMutableProbabilitySet::copy` `Core/OOProbabilitySet.cpp:539` | ✅ |
| `-[OOMutableProbabilitySet setWeight:forObject:]` (674) | pure virtual `Core/OOProbabilitySet.h:119` | ➖ |
| `-[OOMutableProbabilitySet removeObject:]` (679) | pure virtual `Core/OOProbabilitySet.h:123` | ➖ |
| `-[OOConcreteMutableProbabilitySet initPriv]` (688) | default member initialisers `Core/OOProbabilitySet.cpp:183-185` | ✅ |
| `-[OOConcreteMutableProbabilitySet initPrivWithObjectArray:weightsArray:sum:]` (699) | `initPrivWithObjectArray` `Core/OOProbabilitySet.cpp:547` | ✅ |
| `-[OOConcreteMutableProbabilitySet initWithObjects:weights:count:]` (712) | `initWithObjects` `Core/OOProbabilitySet.cpp:557` | ✅ |
| `-[OOConcreteMutableProbabilitySet initWithPropertyListRepresentation:]` (732) | `initWithPropertyListRepresentation` `Core/OOProbabilitySet.cpp:578` | ✅ |
| `-[OOConcreteMutableProbabilitySet dealloc]` (768) | — (implicit destructor) | ➖ |
| `-[OOConcreteMutableProbabilitySet propertyListRepresentation]` (776) | `propertyListRepresentation` `Core/OOProbabilitySet.cpp:609` | ✅ |
| `-[OOConcreteMutableProbabilitySet count]` (784) | `count` `Core/OOProbabilitySet.cpp:614` | ✅ |
| `-[OOConcreteMutableProbabilitySet randomObject]` (789) | `randomObject` `Core/OOProbabilitySet.cpp:616` | ❌ |
| `-[OOConcreteMutableProbabilitySet weightForObject:]` (810) | `weightForObject` `Core/OOProbabilitySet.cpp:638` | ❌ |
| `-[OOConcreteMutableProbabilitySet sumOfWeights]` (825) | `sumOfWeights` `Core/OOProbabilitySet.cpp:652` | ✅ |
| `-[OOConcreteMutableProbabilitySet allObjects]` (839) | `allElements` `Core/OOProbabilitySet.cpp:665` | ✅ |
| `-[OOConcreteMutableProbabilitySet objectEnumerator]` (844) | — replaced by `allElements()` | ➖ |
| `-[OOConcreteMutableProbabilitySet setWeight:forObject:]` (849) | `setWeight` `Core/OOProbabilitySet.cpp:669` | ✅ |
| `-[OOConcreteMutableProbabilitySet removeObject:]` (869) | `removeObject` `Core/OOProbabilitySet.cpp:691` | ✅ |
| `-[OOConcreteMutableProbabilitySet copyWithZone:]` (882) | `copy` `Core/OOProbabilitySet.cpp:704` | ✅ |
| `-[OOConcreteMutableProbabilitySet mutableCopyWithZone:]` (913) | `mutableCopy` `Core/OOProbabilitySet.cpp:714` | ✅ |
| `-[OOProbabilitySetEnumerator initWithEnumerable:]` (924) | — enumerator class removed | ➖ |
| `-[OOProbabilitySetEnumerator dealloc]` (933) | — | ➖ |
| `-[OOProbabilitySetEnumerator nextObject]` (940) | — | ➖ |
| `ThrowAbstractionViolationException` (953) | — abstract methods are pure virtual | ➖ |

**Differences:**

- ❌ **low** — the `probabilitySet.broken` log prints `__PRETTY_FUNCTION__`, now the C++ signature rather than `-[OOConcreteMutableProbabilitySet randomObject]`. Only the text of an internal-error log differs (still open) — upstream `Core/OOProbabilitySet.m:806` ↔ port `Core/OOProbabilitySet.cpp:630-634`
- ❌ **low** — element equality is defaulted `oo::PList ==` (`Core/oofnd/PList.hpp:306`), not `-isEqual:`. It compares the real `single_` flag and `Integer::isUnsigned`, so numeric elements NSNumber treated as equal (`1` vs `1.0`, float vs double) no longer match in `weightForObject`/`setWeight`/`removeObject`/`containsObject` (all three set kinds). Game callers store ship-key strings. The previous run rated this ⚠️ citing bead oo-4aq6a.5; that citation is no longer in the code (the comment at :84-91 only claims `-isEqual:` semantics), so it is re-rated ❌ (still open) — upstream `Core/OOProbabilitySet.m:426,585,815` ↔ port `Core/OOProbabilitySet.cpp:86-98`
- ✅ checked (RNG) — both `randomObject`s call `randf()` once; the mutable set draws before its empty/zero-sum check and the concrete set after, as upstream. Binary search verbatim — upstream `Core/OOProbabilitySet.m:539-572,795` ↔ port `Core/OOProbabilitySet.cpp:442-469,621`
- ✅ subtle — the mutable `weightForObject` subtracts `_weights[index-1]` though `_weights` holds plain weights; this upstream bug is preserved — upstream `Core/OOProbabilitySet.m:817-819` ↔ port `Core/OOProbabilitySet.cpp:645-646`
- ✅ subtle — immutable `copy()` always returns `this`; upstream's other-zone plist rebuild has no C++ equivalent (comment at :281) — upstream `Core/OOProbabilitySet.m:252-259` ↔ port `Core/OOProbabilitySet.cpp:280-284`

## OORoleSet

<a id="ooroleset"></a>
Upstream `src/Core/OORoleSet.m` ↔ `Core/OORoleSet.cpp` (331 / 278 lines)

**Status:** done — 22 rows: 14 ✅ 4 ⚠️ 1 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OORoleSet roleSetWithString:]` (42) | `OORoleSet::roleSetWithString` `Core/OORoleSet.cpp:35` | ✅ |
| `+[OORoleSet roleSetWithRole:probability:]` (47) | `OORoleSet::roleSetWithRole` `Core/OORoleSet.cpp:42` | ✅ |
| `-[OORoleSet initWithRoleString:]` (52) | `OORoleSet::initWithRoleString` `Core/OORoleSet.cpp:56` (empty parse → nil dict) | ✅ |
| `-[OORoleSet initWithRole:probability:]` (60) | `OORoleSet::initWithRole` `Core/OORoleSet.cpp:61` | ⚠️ |
| `-[OORoleSet dealloc]` (70) | — (implicit destructor) | ➖ |
| `-[OORoleSet description]` (79) | `OORoleSet::descriptionComponents` `Core/OORoleSet.cpp:72` (wrapped by `oo::DescriptionOf`) | ✅ |
| `-[OORoleSet isEqual:]` (84) | `OORoleSet::isEqual` `Core/OORoleSet.cpp:79` | ✅ |
| `-[OORoleSet hash]` (92) | `OORoleSet::hash` `Core/OORoleSet.cpp:86` (dictionary count, as GNUstep) | ✅ |
| `-[OORoleSet copyWithZone:]` (97) | — immutable; callers share via `oo::share(this)` `Core/OORoleSet.cpp:182` | ➖ |
| `-[OORoleSet roleString]` (103) | `OORoleSet::roleString` `Core/OORoleSet.cpp:91` (`%g` → `{:g}`, omitted at 1.0f) | ✅ |
| `-[OORoleSet hasRole:]` (135) | `OORoleSet::hasRole` `Core/OORoleSet.cpp:117` | ✅ |
| `-[OORoleSet probabilityForRole:]` (140) | `OORoleSet::probabilityForRole` `Core/OORoleSet.cpp:121` | ✅ |
| `-[OORoleSet intersectsSet:]` (145) | — removed; `HasRoleInSetPredicate` uses `hasRole` (`Core/OORoleSet.h:60-61`) | ➖ |
| `-[OORoleSet roles]` (155) | `OORoleSet::roles` `Core/OORoleSet.cpp:126` | ⚠️ |
| `-[OORoleSet sortedRoles]` (163) | `OORoleSet::sortedRoles` `Core/OORoleSet.cpp:134` | ✅ |
| `-[OORoleSet rolesAndProbabilities]` (168) | `OORoleSet::rolesAndProbabilities` `Core/OORoleSet.cpp:143` | ✅ |
| `-[OORoleSet anyRole]` (173) | `OORoleSet::anyRole` `Core/OORoleSet.cpp:147` | ❌ |
| `-[OORoleSet roleSetWithAddedRoleIfNotSet:probability:]` (197) | `OORoleSet::roleSetWithAddedRoleIfNotSet` `Core/OORoleSet.cpp:177` | ⚠️ |
| `-[OORoleSet roleSetWithAddedRole:probability:]` (210) | `OORoleSet::roleSetWithAddedRole` `Core/OORoleSet.cpp:190` | ⚠️ |
| `-[OORoleSet roleSetWithRemovedRole:]` (223) | `OORoleSet::roleSetWithRemovedRole` `Core/OORoleSet.cpp:202` | ✅ |
| `-[OORoleSet(OOPrivate) initWithRolesAndProbabilities:]` (239) | `OORoleSet::initWithRolesAndProbabilities` `Core/OORoleSet.cpp:212` (thargon rewrite, `_totalProb` over the original dict) | ✅ |
| `OOParseRolesFromString` (286) | `OOParseRolesFromString` `Core/OORoleSet.cpp:250` | ✅ |

**Differences:**

- ❌ **med** — `anyRole` walks roles in `std::map` byte order instead of `NSDictionary` order. With the same single `randf()` draw (taken before the empty check in both), a multi-role set can return a different weighted role; the fallback is the first map key instead of `[[self roles] anyObject]`. Upstream caller: `ShipEntity -primaryRole` when no primary role is set (still open) — upstream `Core/OORoleSet.m:178-193` ↔ port `Core/OORoleSet.cpp:151-173`
- ⚠️ **low** — an empty role string means "no role": `initWithRole`, `roleSetWithAddedRole` and `roleSetWithAddedRoleIfNotSet` reject `""`, which upstream accepted as a real role. Documented in the header comment (`Core/OORoleSet.h:57-58`); the earlier ADR-0043/bead oo-hi38 citations are no longer in the header (still open) — upstream `Core/OORoleSet.m:64,201,214` ↔ port `Core/OORoleSet.cpp:64,179,192`
- ⚠️ **low** — `roles()` returns a byte-ordered vector instead of an `NSSet`, so callers that enumerate it see a different order. Documented at `Core/OORoleSet.h:76` (still open) — upstream `Core/OORoleSet.m:155-161` ↔ port `Core/OORoleSet.cpp:126-132`
- ✅ subtle — `sortedRoles` runs `std::stable_sort` + `caseInsensitiveCompare` over byte-ordered input; only roles that differ purely in case could order differently in `roleString` — upstream `Core/OORoleSet.m:165` ↔ port `Core/OORoleSet.cpp:136-139`
- ✅ checked (parsing) — tokens from `oo::str::tokens`; a leading `(` keeps the whole token as the role (as a failed `scanUpToString`); the probability comes from `scanDouble`, narrowed to float, defaulting to 1.0; negatives and `[`-prefixed tokens dropped; last duplicate wins — upstream `Core/OORoleSet.m:299-329` ↔ port `Core/OORoleSet.cpp:254-275`

## OOShipGroup

<a id="ooshipgroup"></a>
Upstream `src/Core/OOShipGroup.m` ↔ `Core/OOShipGroup.cpp` (481 / 416 lines)

**Status:** done — 32 rows: 24 ✅ 1 ⚠️ 0 ❌ 7 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOShipGroup init]` (73) | — no public init; `groupWithName(std::nullopt)` | ➖ |
| `-[OOShipGroup initWithName:]` (78) | `OOShipGroup::initWithName` `Core/OOShipGroup.cpp:110` (capacity kMinSize=4) | ✅ |
| `+[OOShipGroup groupWithName:]` (94) | `OOShipGroup::groupWithName` `Core/OOShipGroup.cpp:119` | ✅ |
| `+[OOShipGroup groupWithName:leader:]` (99) | `OOShipGroup::groupWithName(name, leader)` `Core/OOShipGroup.cpp:126` | ✅ |
| `-[OOShipGroup dealloc]` (106) | `OOShipGroup::~OOShipGroup` `Core/OOShipGroup.cpp:143` | ✅ |
| `-[OOShipGroup descriptionComponents]` (119) | `OOShipGroup::descriptionComponents` `Core/OOShipGroup.cpp:149` (same three formats) | ✅ |
| `-[OOShipGroup name]` (131) | `OOShipGroup::name` `Core/OOShipGroup.cpp:163` | ✅ |
| `-[OOShipGroup setName:]` (136) | `OOShipGroup::setName` `Core/OOShipGroup.cpp:165` (bumps `_updateCount`) | ✅ |
| `-[OOShipGroup leader]` (146) | `OOShipGroup::leader` `Core/OOShipGroup.cpp:171` | ✅ |
| `-[OOShipGroup setLeader:]` (159) | `OOShipGroup::setLeader` `Core/OOShipGroup.cpp:180` | ✅ |
| `-[OOShipGroup objectEnumerator]` (170) | — replaced by `OOShipGroupCursor` `Core/OOShipGroup.h:139` | ➖ |
| `-[OOShipGroup mutationSafeEnumerator]` (175) | — replaced by `memberArray()` | ➖ |
| `-[OOShipGroup members]` (180) | — replaced by `memberArray()` | ➖ |
| `-[OOShipGroup membersExcludingLeader]` (185) | — replaced by `memberArrayExcludingLeader()` | ➖ |
| `-[OOShipGroup memberArray]` (190) | `OOShipGroup::memberArray` `Core/OOShipGroup.cpp:190` | ✅ |
| `-[OOShipGroup memberArrayExcludingLeader]` (210) | `OOShipGroup::memberArrayExcludingLeader` `Core/OOShipGroup.cpp:203` | ✅ |
| `-[OOShipGroup containsShip:]` (234) | `OOShipGroup::containsShip` `Core/OOShipGroup.cpp:220` (identity; nil → NO) | ✅ |
| `-[OOShipGroup addShip:]` (247) | `OOShipGroup::addShip` `Core/OOShipGroup.cpp:233` (same growth rule) | ✅ |
| `-[OOShipGroup removeShip:]` (268) | `OOShipGroup::removeShip` `Core/OOShipGroup.cpp:254` | ✅ |
| `-[OOShipGroup count]` (304) | `OOShipGroup::count` `Core/OOShipGroup.cpp:292` | ✅ |
| `-[OOShipGroup isEmpty]` (320) | `OOShipGroup::isEmpty` `Core/OOShipGroup.cpp:305` | ✅ |
| `-[OOShipGroup resizeTo:]` (328) | `OOShipGroup::resizeTo` `Core/OOShipGroup.cpp:311` | ✅ |
| `-[OOShipGroup cleanUp]` (344) | `OOShipGroup::cleanUp` `Core/OOShipGroup.cpp:319` (128 / power-of-2 / min 4) | ✅ |
| `-[OOShipGroup updateCount]` (364) | `OOShipGroup::updateCount` `Core/OOShipGroup.cpp:338` | ✅ |
| `ShipGroupIterate` (369) | `OOShipGroupCursor::next` `Core/OOShipGroup.cpp:340` (same raise text, compaction, cleanup rule) | ✅ |
| `-[OOShipGroup countByEnumeratingWithState:objects:count:]` (404) | `OOShipGroupMembers::FillBatch` `Core/OOShipGroup.cpp:381` + `Iterator` `Core/OOShipGroup.cpp:68` | ⚠️ |
| `-[OOShipGroup suppressClangStuff]` (437) | — | ➖ |
| `-[OOShipGroupEnumerator initWithShipGroup:]` (446) | `OOShipGroupCursor::OOShipGroupCursor` `Core/OOShipGroup.cpp:410` | ✅ |
| `-[OOShipGroupEnumerator dealloc]` (459) | — (shared_ptr member) | ➖ |
| `-[OOShipGroupEnumerator nextObject]` (466) | `OOShipGroupCursor::next` `Core/OOShipGroup.cpp:340` | ✅ |
| `-[OOShipGroupEnumerator index]` (471) | `OOShipGroupCursor::index` `Core/OOShipGroup.h:144` | ✅ |
| `-[OOShipGroupEnumerator setPerformCleanup:]` (476) | `OOShipGroupCursor::setPerformCleanup` `Core/OOShipGroup.h:145` | ✅ |

**Differences:**

- ⚠️ **low** — mutating a group inside a for-in loop raised upstream. The range-for replacement checks with `OOCAssert`, which is compiled out under `NDEBUG`, so release builds keep iterating silently (comment at port :57-58: "for-in raised; this asserts"). Batch size 16, dead-ref compaction and `cleanUp` points are unchanged (still open) — upstream `Core/OOShipGroup.m:404-430` ↔ port `Core/OOShipGroup.cpp:78-83,381-408`
- ✅ subtle — `removeShip` calls `ship->ShipEntity::setOwner(ship)` non-virtually; upstream has no `-setOwner:` override below ShipEntity, so dispatch is the same — upstream `Core/OOShipGroup.m:290` ↔ port `Core/OOShipGroup.cpp:276-278`
- ✅ subtle — `setLeader(nil)` still appends an empty weak slot via `addShip(nil)`, which the next iteration compacts, as the nil `weakRetain` did — upstream `Core/OOShipGroup.m:163-166,264` ↔ port `Core/OOShipGroup.cpp:183-186,249-250`

## OOShipLibraryDescriptions

<a id="ooshiplibrarydescriptions"></a>
Upstream `src/Core/OOShipLibraryDescriptions.m` ↔ `Core/OOShipLibraryDescriptions.cpp` (156 / 176 lines)

**Status:** done — 11 rows: 11 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOShipLibraryCategorySingular` (29) | `OOShipLibraryCategorySingular` `Core/OOShipLibraryDescriptions.cpp:48` (via `ExpandCategoryKey` :38) | ✅ |
| `OOShipLibraryCategoryPlural` (34) | `OOShipLibraryCategoryPlural` `Core/OOShipLibraryDescriptions.cpp:52` | ✅ |
| `OOShipLibrarySpeed` (39) | `OOShipLibrarySpeed` `Core/OOShipLibraryDescriptions.cpp:57` (1/150/250/325/425) | ✅ |
| `OOShipLibraryTurnRate` (59) | `OOShipLibraryTurnRate` `Core/OOShipLibraryDescriptions.cpp:76` (roll + 2·pitch; 2/2.75/4.5/6) | ✅ |
| `OOShipLibraryCargo` (77) | `OOShipLibraryCargo` `Core/OOShipLibraryDescriptions.cpp:95` | ✅ |
| `OOShipLibraryGenerator` (89) | `OOShipLibraryGenerator` `Core/OOShipLibraryDescriptions.cpp:107` (2.5/3.75) | ✅ |
| `OOShipLibraryShields` (103) | `OOShipLibraryShields` `Core/OOShipLibraryDescriptions.cpp:120` (128/192/256/320) | ✅ |
| `OOShipLibraryWitchspace` (122) | `OOShipLibraryWitchspace` `Core/OOShipLibraryDescriptions.cpp:138` | ✅ |
| `OOShipLibraryWeapons` (131) | `OOShipLibraryWeapons` `Core/OOShipLibraryDescriptions.cpp:146` (same facing-bit sum) | ✅ |
| `OOShipLibraryTurrets` (142) | `OOShipLibraryTurrets` `Core/OOShipLibraryDescriptions.cpp:159` | ✅ |
| `OOShipLibrarySize` (152) | `OOShipLibrarySize` `Core/OOShipLibraryDescriptions.cpp:169` (`(unsigned)` truncation) | ✅ |

**Differences:**

- ✅ **low** — nil messaging returning 0 is replaced by explicit `demo_ship ? … : 0` guards; results are the same for a null demo ship — upstream `Core/OOShipLibraryDescriptions.m:39-155` ↔ port `Core/OOShipLibraryDescriptions.cpp:57-176`
- ✅ **low** (subtle) — the `-u` format strings from descriptions.plist go through `oo::str::format` (vsnprintf) instead of `stringWithFormat:`. Core strings use only `%u`, so output matches; an overriding description containing `%@` would now be undefined rather than print an object — upstream `Core/OOShipLibraryDescriptions.m:84,139,146,155` ↔ port `Core/OOShipLibraryDescriptions.cpp:101,155,162,172`

## OOShipRegistry

<a id="ooshipregistry"></a>
Upstream `src/Core/OOShipRegistry.m` ↔ `Core/OOShipRegistry.cpp` (1628 / 1700 lines)

**Status:** done — 51 rows: 36 ✅ 7 ⚠️ 0 ❌ 8 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOShipRegistry sharedRegistry]` (119) | `OOShipRegistry::sharedRegistry` `Core/OOShipRegistry.cpp:174` | ✅ |
| `+[OOShipRegistry reload]` (128) | `OOShipRegistry::reload` `Core/OOShipRegistry.cpp:189` (old instance leaked, as upstream) | ✅ |
| `-[OOShipRegistry init]` (141) | `OOShipRegistry::init` `Core/OOShipRegistry.cpp:202` (same three load-failure raises) | ✅ |
| `-[OOShipRegistry dealloc]` (180) | — (value members; singleton never freed) | ➖ |
| `-[OOShipRegistry shipInfoForKey:]` (190) | `shipInfoForKey` `Core/OOShipRegistry.cpp:251` | ✅ |
| `-[OOShipRegistry setShipInfoForKey:with:]` (195) | `setShipInfoForKey` `Core/OOShipRegistry.cpp:256` (value copy for deep copy) | ✅ |
| `-[OOShipRegistry effectInfoForKey:]` (203) | `effectInfoForKey` `Core/OOShipRegistry.cpp:263` | ✅ |
| `-[OOShipRegistry shipyardInfoForKey:]` (208) | `shipyardInfoForKey` `Core/OOShipRegistry.cpp:268` | ✅ |
| `-[OOShipRegistry probabilitySetForRole:]` (213) | `probabilitySetForRole` `Core/OOShipRegistry.cpp:275` | ✅ |
| `-[OOShipRegistry demoShipKeys]` (220) | `demoShipKeys` `Core/OOShipRegistry.cpp:282` | ✅ |
| `-[OOShipRegistry playerShipKeys]` (228) | `playerShipKeys` `Core/OOShipRegistry.cpp:289` | ✅ |
| `-[OOShipRegistry(OOConveniences) shipKeys]` (237) | `shipKeys` `Core/OOShipRegistry.cpp:295` | ⚠️ |
| `-[OOShipRegistry(OOConveniences) shipRoles]` (242) | `shipRoles` `Core/OOShipRegistry.cpp:304` | ⚠️ |
| `-[OOShipRegistry(OOConveniences) shipKeysWithRole:]` (247) | `shipKeysWithRole` `Core/OOShipRegistry.cpp:313` | ✅ |
| `-[OOShipRegistry(OOConveniences) randomShipKeyForRole:]` (252) | `randomShipKeyForRole` `Core/OOShipRegistry.cpp:327` | ✅ |
| `-[OOShipRegistry(OODataLoader) loadShipData]` (271) | `loadShipData` `Core/OOShipRegistry.cpp:347` (same stage order and progress logs) | ✅ |
| `-[OOShipRegistry(OODataLoader) loadDemoShipConditions]` (383) | `loadDemoShipConditions` `Core/OOShipRegistry.cpp:438` | ✅ |
| `-[OOShipRegistry(OODataLoader) loadDemoShips]` (411) | `loadDemoShips` `Core/OOShipRegistry.cpp:470` | ⚠️ |
| `-[OOShipRegistry(OODataLoader) loadCachedRoleProbabilitySets]` (513) | `loadCachedRoleProbabilitySets` `Core/OOShipRegistry.cpp:607` | ✅ |
| `-[OOShipRegistry(OODataLoader) buildRoleProbabilitySets]` (532) | `buildRoleProbabilitySets` `Core/OOShipRegistry.cpp:625` | ⚠️ |
| `-[OOShipRegistry(OODataLoader) applyLikeShips:withKey:]` (580) | `applyLikeShips` `Core/OOShipRegistry.cpp:668` (order-independent result) | ✅ |
| `-[OOShipRegistry(OODataLoader) mergeShip:withParent:]` (644) | `mergeShip` `Core/OOShipRegistry.cpp:734` (five alias pairs; bools count as strings, as `oo_stringForKey`) | ✅ |
| `-[OOShipRegistry(OODataLoader) makeShipEntriesMutable:]` (698) | `makeShipEntriesMutable` `Core/OOShipRegistry.cpp:792` | ✅ |
| `-[OOShipRegistry(OODataLoader) loadAndApplyShipDataOverrides:]` (719) | `loadAndApplyShipDataOverrides` `Core/OOShipRegistry.cpp:810` | ✅ |
| `-[OOShipRegistry(OODataLoader) stripPrivateKeys:]` (747) | `stripPrivateKeys` `Core/OOShipRegistry.cpp:835` | ✅ |
| `-[OOShipRegistry(OODataLoader) loadAndMergeShipyard:]` (775) | `loadAndMergeShipyard` `Core/OOShipRegistry.cpp:852` | ⚠️ |
| `-[OOShipRegistry(OODataLoader) canonicalizeAndTagSubentities:]` (828) | `canonicalizeAndTagSubentities` `Core/OOShipRegistry.cpp:1085` | ✅ |
| `-[OOShipRegistry(OODataLoader) removeUnusableEntries:shipMode:]` (908) | `removeUnusableEntries` `Core/OOShipRegistry.cpp:906` | ✅ |
| `-[OOShipRegistry(OODataLoader) sanitizeConditions:]` (949) | `sanitizeConditions` `Core/OOShipRegistry.cpp:960` (keeps upstream's `hasShipyard` truthy `continue` quirk) | ⚠️ |
| `-[OOShipRegistry(OODataLoader) preloadShipMeshes:]` (1052) | — dead code (`#if PRELOAD` = 0 upstream); not ported | ➖ |
| `-[OOShipRegistry(OODataLoader) mergeShipRoles:forShipKey:intoProbabilityMap:]` (1097) | `mergeShipRoles` `Core/OOShipRegistry.cpp:1175` | ✅ |
| `-[OOShipRegistry(OODataLoader) canonicalizeSubentityDeclaration:forShip:shipData:fatalError:]` (1138) | `canonicalizeSubentityDeclaration` `Core/OOShipRegistry.cpp:1211` | ⚠️ |
| `-[OOShipRegistry(OODataLoader) translateOldStyleSubentityDeclaration:forShip:shipData:fatalError:]` (1180) | `translateOldStyleSubentityDeclaration` `Core/OOShipRegistry.cpp:1255` | ✅ |
| `-[OOShipRegistry(OODataLoader) translateOldStyleFlasherDeclaration:forShip:fatalError:]` (1217) | `translateOldStyleFlasherDeclaration` `Core/OOShipRegistry.cpp:1298` | ✅ |
| `-[OOShipRegistry(OODataLoader) translateOldStandardBasicSubentityDeclaration:forShip:shipData:fatalError:]` (1251) | `translateOldStandardBasicSubentityDeclaration` `Core/OOShipRegistry.cpp:1336` | ✅ |
| `-[OOShipRegistry(OODataLoader) validateNewStyleSubentityDeclaration:forShip:fatalError:]` (1299) | `validateNewStyleSubentityDeclaration` `Core/OOShipRegistry.cpp:1390` | ✅ |
| `-[OOShipRegistry(OODataLoader) validateNewStyleFlasherDeclaration:forShip:fatalError:]` (1320) | `validateNewStyleFlasherDeclaration` `Core/OOShipRegistry.cpp:1412` (defaults 8/0.5/2/0/YES, redColor) | ✅ |
| `-[OOShipRegistry(OODataLoader) validateNewStyleStandardSubentityDeclaration:forShip:fatalError:]` (1397) | `validateNewStyleStandardSubentityDeclaration` `Core/OOShipRegistry.cpp:1497` (turret clamps, dock defaults) | ✅ |
| `-[OOShipRegistry(OODataLoader) shipIsBallTurretForKey:inShipData:]` (1486) | `shipIsBallTurretForKey` `Core/OOShipRegistry.cpp:1597` | ✅ |
| `+[OOShipRegistry(Singleton) allocWithZone:]` (1519) | — ("Loading ship data." log moved into `sharedRegistry` `Core/OOShipRegistry.cpp:176`) | ➖ |
| `-[OOShipRegistry(Singleton) copyWithZone:]` (1529) | — (refcount boilerplate gone) | ➖ |
| `-[OOShipRegistry(Singleton) retain]` (1534) | — | ➖ |
| `-[OOShipRegistry(Singleton) retainCount]` (1539) | — | ➖ |
| `-[OOShipRegistry(Singleton) release]` (1544) | — (`reload` leaks, `Core/OOShipRegistry.cpp:194-196`) | ➖ |
| `-[OOShipRegistry(Singleton) autorelease]` (1548) | — | ➖ |
| `DumpStringAddrs` (1559) | `DumpStringAddrs` `Core/OOShipRegistry.cpp:1642` (early `return;` in both) | ✅ |
| `GatherStringAddrsDict` (1588) | `GatherStringAddrsDict` `Core/OOShipRegistry.cpp:1669` | ✅ |
| `GatherStringAddrsArray` (1599) | `GatherStringAddrsArray` `Core/OOShipRegistry.cpp:1679` | ✅ |
| `GatherStringAddrs` (1608) | `GatherStringAddrs` `Core/OOShipRegistry.cpp:1688` (+ `GatherStringAddr` :1663) | ✅ |
| `SortDemoShipsByName` (1620) | lambda in `loadDemoShips` `Core/OOShipRegistry.cpp:586-590` | ✅ |
| `SortDemoCategoriesByName` (1625) | lambda in `loadDemoShips` `Core/OOShipRegistry.cpp:596-603` | ✅ |

**Differences:**

- ⚠️ **med** — Role probability sets are built by adding ships to each role's set in `std::map` key order instead of `NSDictionary` hash order. `randomObject` searches cumulative weights in insertion order, so the same RNG draw can pick a different ship for a role (NPC spawns differ from upstream without a cache). Justified by the code comment "(ships in key order; was hash order)"; the ADR-0043 the previous run cited is not in this tree (still open) — upstream `Core/OOShipRegistry.m:545-550` ↔ port `Core/OOShipRegistry.cpp:629-635`
- ⚠️ **med** — `_playerShips` follows shipyard.plist key order, not hash order. `Universe` draws randoms while walking `playerShipKeys()` to build shipyards, so contents can differ for the same seed. Comment at :868-869 and header `Core/OOShipRegistry.h:88` (still open) — upstream `Core/OOShipRegistry.m:806-822` ↔ port `Core/OOShipRegistry.cpp:868-895`
- ⚠️ **low** — `shipKeys()`/`shipRoles()` (JS `Ship.keys()`/`Ship.roles()`) return keys in sorted order; upstream returned `allKeys` in hash order. Header comment `Core/OOShipRegistry.h:76-77` (still open) — upstream `Core/OOShipRegistry.m:237-245` ↔ port `Core/OOShipRegistry.cpp:295-311`
- ⚠️ **low** — Demo-ship fallback, when the library is empty and `coriolis-station` is missing, takes the first key in sorted order rather than `[[_shipData allKeys] objectAtIndex:0]` (comment at :546) (still open) — upstream `Core/OOShipRegistry.m:475` ↔ port `Core/OOShipRegistry.cpp:544-546`
- ⚠️ **low** — `shipData.load.error.badSubentity` prints the plist type name (`array`, `integer`) where upstream printed the ObjC class name (`GSMutableArray`…). Comment at :1237-1238; the bead oo-qps.50 citation is gone (still open) — upstream `Core/OOShipRegistry.m:1169` ↔ port `Core/OOShipRegistry.cpp:1239-1242`
- ⚠️ **low** — `sanitizeConditions`, `makeShipEntriesMutable`, `removeUnusableEntries`, `canonicalizeAndTagSubentities` and the overrides walk ships in key order, so the cached "ship conditions" script list and per-ship error/deprecation log lines come out in a different order. Data is the same (comment at :979) (still open) — upstream `Core/OOShipRegistry.m:962,1045` ↔ port `Core/OOShipRegistry.cpp:979-1080`
- ✅ **low** (subtle) — Demo-ship list: grouping and `compare:` sorts by `name` and then plural category match; `std::stable_sort` keeps shiplibrary order for equal names, where GNUstep's sort is not guaranteed stable — upstream `Core/OOShipRegistry.m:505-510,1620-1628` ↔ port `Core/OOShipRegistry.cpp:585-604`
- ✅ **low** (subtle) — Malformed data: a non-dictionary `shipyard.plist`/`shipyard-overrides` entry made upstream raise in `dictionaryByAddingEntriesFromDictionary:`; the port stores the entry or skips the merge. A cached role set whose plist no longer parses made `setObject:nil` raise; the port stores a null set (new) — upstream `Core/OOShipRegistry.m:526,812` ↔ port `Core/OOShipRegistry.cpp:616-618,876-881`
- ✅ **low** — Raises that upstream had are kept: demo ship with no `name`, subentity with no `subentity_key` string, `objectAtIndex:0` on empty tokens (`FirstToken`), and the three `OOShipRegistryLoadFailure`s — upstream `Core/OOShipRegistry.m:154-171,496,873,1191,1495` ↔ port `Core/OOShipRegistry.cpp:121-127,224-245,569-574,1126-1130`

## OOStringExpander

<a id="oostringexpander"></a>
Upstream `src/Core/OOStringExpander.m` ↔ `Core/OOStringExpander.cpp` (1191 / 1626 lines)

**Status:** done — 41 rows: 32 ✅ 5 ⚠️ 4 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OO_EXPANDER_RANDOM` macro (43) (added) | same macro `Core/OOStringExpander.cpp:78` | ✅ |
| `kStackAllocationLimit` / `kRecursionLimit` enum (45) (added) | `constexpr` `Core/OOStringExpander.cpp:92,98` (UINT16_MAX, 100) | ✅ |
| `OOExpandDescriptionString` (160) | `OOExpandDescriptionString` `Core/OOStringExpander.cpp:269` (same option flags, `%I` preseed, reseed save/restore) | ✅ |
| `OOGenerateSystemDescription` (220) | `OOGenerateSystemDescription` `Core/OOStringExpander.cpp:325` | ✅ |
| `OOStringExpanderDefaultRandomSeed` (226) | `OOStringExpanderDefaultRandomSeed` `Core/OOStringExpander.cpp:333` | ✅ |
| `Expand` (243) | `Expand` `Core/OOStringExpander.cpp:358` | ⚠️ |
| `ExpandKey` (349) | `ExpandKey` `Core/OOStringExpander.cpp:470` (bracket balance, first-bar, allDigits rule) | ✅ |
| `ApplyOperators` (410) | `ApplyOperators` `Core/OOStringExpander.cpp:537` | ✅ |
| `Operator_cr` (428) | `Operator_cr` `Core/OOStringExpander.cpp:581` | ✅ |
| `Operator_dcr` (433) | `Operator_dcr` `Core/OOStringExpander.cpp:586` | ✅ |
| `Operator_icr` (438) | `Operator_icr` `Core/OOStringExpander.cpp:591` | ✅ |
| `Operator_idcr` (443) | `Operator_idcr` `Core/OOStringExpander.cpp:596` | ✅ |
| `Operator_precision` (448) | `Operator_precision` `Core/OOStringExpander.cpp:601` | ❌ |
| `Operator_multiply` (453) | `Operator_multiply` `Core/OOStringExpander.cpp:607` (`%g` → `{:g}`) | ✅ |
| `Operator_add` (458) | `Operator_add` `Core/OOStringExpander.cpp:613` | ✅ |
| `ApplyOneOperator` (472) | `ApplyOneOperator` `Core/OOStringExpander.cpp:628` | ✅ |
| `ExpandDigitKey` (508) | `ExpandDigitKey` `Core/OOStringExpander.cpp:662` (Elite 5-way thresholds, `(rnd*count)/256`) | ✅ |
| `ExpandStringKey` (563) | `ExpandStringKey` `Core/OOStringExpander.cpp:740` (same priority; legacy-selector result discarded as upstream) | ✅ |
| `ExpandStringKeyOverride` (613) | `ExpandStringKeyOverride` `Core/OOStringExpander.cpp:794` (+ `ValueText` :986) | ⚠️ |
| `ExpandStringKeySpecial` (636) | `ExpandStringKeySpecial` `Core/OOStringExpander.cpp:822` | ✅ |
| `ExpandStringKeyKeyboardBinding` (659) | `ExpandStringKeyKeyboardBinding` `Core/OOStringExpander.cpp:855` (`substr(7)` quirk kept) | ✅ |
| `SpecialSubstitutionSelectors` (674) | `SpecialSubstitutionSelectors` `Core/OOStringExpander.cpp:872` (same 9 entries) | ✅ |
| `ExpandStringKeyFromDescriptions` (712) | `ExpandStringKeyFromDescriptions` `Core/OOStringExpander.cpp:907` | ⚠️ |
| `ExpandStringKeyMissionVariable` (738) | `ExpandStringKeyMissionVariable` `Core/OOStringExpander.cpp:946` | ⚠️ |
| `ExpandStringKeyLegacyLocalVariable` (753) | `ExpandStringKeyLegacyLocalVariable` `Core/OOStringExpander.cpp:970` | ✅ |
| `ExpandLegacyScriptSelectorKey` (764) | `ExpandLegacyScriptSelectorKey` `Core/OOStringExpander.cpp:1000` | ✅ |
| `LookUpLegacySelector` (782) | `LookUpLegacySelector` `Core/OOStringExpander.cpp:1023` | ✅ |
| `ReportWarningForUnknownKey` (834) | `ReportWarningForUnknownKey` `Core/OOStringExpander.cpp:1089` | ✅ |
| `ExpandPercentEscape` (864) | `ExpandPercentEscape` `Core/OOStringExpander.cpp:1124` | ⚠️ |
| `ExpandPercentR` (934) | `ExpandPercentR` `Core/OOStringExpander.cpp:1217` | ✅ |
| `ExpandSystemNameForGalaxyEscape` (967) | `ExpandSystemNameForGalaxyEscape` `Core/OOStringExpander.cpp:1264` | ✅ |
| `ExpandSystemNameEscape` (1014) | `ExpandSystemNameEscape` `Core/OOStringExpander.cpp:1328` | ✅ |
| `AppendCharacters` (1047) | `AppendCharacters` `Core/OOStringExpander.cpp:1373` (+ `UnitsWithCharacters` :1534) | ✅ |
| `GetSystemName` (1075) | `GetSystemName` `Core/OOStringExpander.cpp:1389` | ✅ |
| `GetSystemNameIan` (1085) | `GetSystemNameIan` `Core/OOStringExpander.cpp:1401` | ✅ |
| `GetRandomNameN` (1096) | `GetRandomNameN` `Core/OOStringExpander.cpp:1416` | ✅ |
| `GetRandomNameR` (1107) | `GetRandomNameR` `Core/OOStringExpander.cpp:1426` | ✅ |
| `GetSystemDescriptions` (1118) | `GetSystemDescriptions` `Core/OOStringExpander.cpp:1436` | ❌ |
| `OldRandomDigrams` (1134) | `OldRandomDigrams` `Core/OOStringExpander.cpp:1481` (+ `Digram` :1454, `Capitalized` :1473) | ❌ |
| `NewRandomDigrams` (1152) | `NewRandomDigrams` `Core/OOStringExpander.cpp:1504` | ❌ |
| `SyntaxIssue` (1168) | `SyntaxIssue` `Core/OOStringExpander.cpp:1588` (+ `ReportJavaScriptWarning` :1619) | ✅ |

**Differences:**

- ❌ **low** — `[x|precision:N]` with a negative `N`: upstream `%.*f` treats a negative precision as omitted (6 decimals). The port's `std::format("{:.{}f}", …)` throws `std::format_error` for a negative dynamic precision, and nothing in the expander catches it, so an OXP string like `[distance|precision:-1]` aborts the expansion with a C++ exception (new) — upstream `Core/OOStringExpander.m:448-451` ↔ port `Core/OOStringExpander.cpp:601-605`
- ❌ **low** — `UNIVERSE->descriptions()` is dereferenced without a null check in `ExpandStringKeyFromDescriptions`, `GetSystemDescriptions`, `OldRandomDigrams` and `NewRandomDigrams`. Upstream's `[[UNIVERSE descriptions] …]` gave nil (unknown key / empty digrams); other lookups in this file do guard `UNIVERSE`/`PLAYER`. An expansion before `Universe` exists would crash instead of degrading (still open) — upstream `Core/OOStringExpander.m:714,1123,1139,1157` ↔ port `Core/OOStringExpander.cpp:913,1442,1485,1509`
- ⚠️ **low** — `Expand`: a `"\x7F"` replacement at the very end of the string no longer eats a character past the end (upstream set `copyRangeStart > size` and failed `AppendCharacters`' assertion). Explained in the comment at :417-423; the bead oo-3rb.69 citation is gone (still open) — upstream `Core/OOStringExpander.m:304-307` ↔ port `Core/OOStringExpander.cpp:424-427`
- ⚠️ **low** — Unknown `%x` warning prints only the low byte of the escape character (upstream `%lc` of a unichar gave an undefined high byte on GNUstep; comment at :1186-1192). Debug-only text (still open) — upstream `Core/OOStringExpander.m:923` ↔ port `Core/OOStringExpander.cpp:1193-1206`
- ⚠️ **low** — `strings.expand.warning.invalidOverride` and `strings.expand.invalidData` print `oo::DescriptionOf(value)` instead of `-shortDescription` (`<ClassName 0x…>`); comments at :806-807 and :930-931 say so (still open) — upstream `Core/OOStringExpander.m:621,723` ↔ port `Core/OOStringExpander.cpp:801-808,926-931`
- ⚠️ **low** — A non-string mission variable (e.g. an array from legacy `set-list`) expands as unset; upstream returned the object, which the string append then rejected. Comment at :950-952 (still open) — upstream `Core/OOStringExpander.m:740-742` ↔ port `Core/OOStringExpander.cpp:949-958`
- ✅ (RNG order, re-checked) — digit keys look up `system_description` then draw once; descriptions arrays draw once `% count` only when non-empty; `%N` draws `%4`, `%5`, then one per digram; `%R` is deferred, `gen_rnd_number` once for `len` then `len+1` digrams; `%I` nests with `GoodRNG|DisallowPercentI|Key`; reseed state is restored after the `%R` pass — upstream `Core/OOStringExpander.m:43,180-213,533-551,717,934-960,1085-1166` ↔ port `Core/OOStringExpander.cpp:78,289-320,702-720,917,1217-1256,1401-1524`
- ✅ **low** (subtle) — `UnitsWithCharacters` reproduces GNUstep's leading-BOM handling and `FindUnits` its composed-sequence rule for `-rangeOfString:`; the Mac path had neither — upstream `Core/OOStringExpander.m:392,397,1066-1072` ↔ port `Core/OOStringExpander.cpp:1534-1574`
- ✅ **low** (subtle) — `SyntaxIssue` formats the message before checking `oo::log::willDisplay` (CPU cost only); JS path passes the text through `"%s"`; prefix `"----- WARNING: "` — upstream `Core/OOStringExpander.m:1168-1191` ↔ port `Core/OOStringExpander.cpp:250,1588-1615`

## OOStringParsing

<a id="oostringparsing"></a>
Upstream `src/Core/OOStringParsing.m` ↔ `Core/OOStringParsing.cpp` (528 / 405 lines)

**Status:** done — 24 rows: 20 ✅ 1 ⚠️ 3 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `ScanTokensFromString` (44) | `oo::str::tokens` `oofnd/String.hpp:747` (whitespace+newline set, UTF-16) | ✅ |
| `ScanVectorFromString` (70) | `ScanVectorFromString` `Core/OOStringParsing.cpp:39` (same error texts, log class) | ✅ |
| `ScanHPVectorFromString` (100) | `ScanHPVectorFromString` `Core/OOStringParsing.cpp:65` | ✅ |
| `ScanQuaternionFromString` (112) | `ScanQuaternionFromString` `Core/OOStringParsing.cpp:77` (normalised) | ✅ |
| `ScanVectorAndQuaternionFromString` (146) | `ScanVectorAndQuaternionFromString` `Core/OOStringParsing.cpp:107` (not normalised, as upstream) | ✅ |
| `VectorFromString` (183) | `VectorFromString` `Core/OOStringParsing.cpp:143` | ✅ |
| `QuaternionFromString` (191) | `QuaternionFromString` `Core/OOStringParsing.cpp:150` | ✅ |
| `StringFromPoint` (199) | `StringFromPoint` `Core/OOStringParsing.cpp:157` | ✅ |
| `PointFromString` (204) | `PointFromString` `Core/OOStringParsing.cpp:161` | ✅ |
| `RandomSeedFromString` (217) | `RandomSeedFromString` `Core/OOStringParsing.cpp:172` | ⚠️ |
| `StringFromRandomSeed` (248) | `StringFromRandomSeed` `Core/OOStringParsing.cpp:204` | ❌ |
| `OOPadStringToEms` (253) | `OOPadStringToEms` `Core/OOStringParsing.cpp:211` | ✅ |
| `OOStringFromDeciCredits` (270) | `OOStringFromDeciCredits` `Core/OOStringParsing.cpp:227` | ✅ |
| `OOStringFromIntCredits` (header 52) (added) | `OOStringFromIntCredits` `Core/OOStringParsing.h:84` | ✅ |
| `OOCredits` (header 57) (added) | `OOCredits` `Core/OOStringParsing.h:89` | ✅ |
| `OOIntCredits` (header 61) (added) | `OOIntCredits` `Core/OOStringParsing.h:92` | ✅ |
| `-[NSString(OOUtilities) pathHasExtension:]` (323) | `oo::str::pathHasExtension` `oofnd/String.hpp:657` | ❌ |
| `-[NSString(OOUtilities) pathHasExtensionInArray:]` (328) | `oo::str::pathHasExtensionIn` `oofnd/String.hpp:664` | ❌ |
| `ComponentsFromVersionString` (342) | `ComponentsFromVersionString` → `oo::str::versionComponents` `Core/OOStringParsing.cpp:280`, `oofnd/String.hpp:1092` | ✅ |
| `CompareVersions` (369) | `CompareVersions` → `oo::str::compareVersions` `Core/OOStringParsing.cpp:284`, `oofnd/String.hpp:1105` | ✅ |
| `ClockToString` (402) | `ClockToString` `Core/OOStringParsing.cpp:292` (int `floor` arithmetic, runtime DESC format) | ✅ |
| `EscapedGraphVizString` (424) | `EscapedGraphVizString` `Core/OOStringParsing.cpp:315` | ✅ |
| `GraphVizTokenString` (459) | `GraphVizTokenString` `Core/OOStringParsing.cpp:352` (keeps the never-incremented `uniqueID` loop) | ✅ |
| `NameIsTaken` (516) | `NameIsTaken` (anon namespace) `Core/OOStringParsing.cpp:339` | ✅ |

**Differences:**

- ❌ **low** — `StringFromRandomSeed` casts each `uint8_t` seed byte to `int8_t` before formatting, so bytes ≥ 128 print as negatives (`200` → `-56`). Upstream's `%d` received the bytes promoted to `int` (0–255). Introduced by commit b84241785 (T041, 2026-11-12) when `oo::str::format("%d…")` became `std::format`; there are no callers of `StringFromRandomSeed` in the port today, so nothing observable yet (new) — upstream `Core/OOStringParsing.m:248-251` ↔ port `Core/OOStringParsing.cpp:204-209`
- ❌ **low** — `pathHasExtension:`/`pathHasExtensionInArray:` compare with `equalsIgnoringCaseAscii` instead of the Unicode `-caseInsensitiveCompare:`; a non-ASCII extension differing only by case (`.Ä`/`.ä`) no longer matches (still open) — upstream `Core/OOStringParsing.m:325,333` ↔ port `oofnd/String.hpp:657-670`
- ⚠️ **low** — `RandomSeedFromString(nil)` scans an empty string (commented "a nil string scans as an empty one"; the proposed ADR-0039 is not cited in code). Both return `kNilRandomSeed`, but the logged reason changes from "could not scan a int value." to "found less than six int values." (still open) — upstream `Core/OOStringParsing.m:223-227` ↔ port `Core/OOStringParsing.cpp:178-185`
- ✅ subtle — `OOStringFromDeciCredits`: same reentrancy fallback `%0.1f`, same `%li` no-result fallback; JS context acquired before the reentrancy return and never released there, as upstream. On a thrown or missing `formatCredits` the port reports the exception via `OOJSReportPendingException` and uses the fallback, where upstream read an uninitialised `jsval` — upstream `Core/OOStringParsing.m:272-318` ↔ port `Core/OOStringParsing.cpp:229-277`

## OOSystemDescriptionManager

<a id="oosystemdescriptionmanager"></a>
Upstream `src/Core/OOSystemDescriptionManager.m` ↔ `Core/OOSystemDescriptionManager.cpp` (615 / 714 lines)

**Status:** done — 31 rows: 28 ✅ 1 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSystemDescriptionManager init]` (62) | `OOSystemDescriptionManager::OOSystemDescriptionManager` `Core/OOSystemDescriptionManager.cpp:95` | ✅ |
| `-[OOSystemDescriptionManager dealloc]` (82) | implicit destructor | ➖ |
| `-[OOSystemDescriptionManager buildRouteCache]` (96) | `buildRouteCache` `Core/OOSystemDescriptionManager.cpp:107` (same j<k pairing, `<= MAX_JUMP_RANGE`, no clear) | ✅ |
| `-[OOSystemDescriptionManager setUniversalProperties:]` (120) | `setUniversalProperties` `Core/OOSystemDescriptionManager.cpp:135` | ✅ |
| `-[OOSystemDescriptionManager setInterstellarProperties:]` (129) | `setInterstellarProperties` `Core/OOSystemDescriptionManager.cpp:149` | ✅ |
| `-[OOSystemDescriptionManager setProperties:forSystemKey:]` (134) | `setProperties(const oo::PList&, const std::string&)` `Core/OOSystemDescriptionManager.cpp:154` | ✅ |
| `-[OOSystemDescriptionManager setProperty:forSystemKey:andLayer:toValue:fromManifest:]` (158) | `setProperty` `Core/OOSystemDescriptionManager.cpp:185` (2-token cache update, 4-token interstellar save only) | ✅ |
| `-[OOSystemDescriptionManager saveScriptedChangeToProperty:forSystemKey:andLayer:toValue:fromManifest:]` (188) | `saveScriptedChangeToProperty` `Core/OOSystemDescriptionManager.cpp:223` (`~\|~` join, layer as int text) | ✅ |
| `-[OOSystemDescriptionManager importScriptedChanges:]` (206) | `importScriptedChanges` `Core/OOSystemDescriptionManager.cpp:250` (+ `OOSystemLayerFromNumber` :63) | ⚠️ |
| `-[OOSystemDescriptionManager importLegacyScriptedChanges:]` (235) | `importLegacyScriptedChanges` `Core/OOSystemDescriptionManager.cpp:282` | ✅ |
| `-[OOSystemDescriptionManager exportScriptedChanges]` (271) | `exportScriptedChanges` `Core/OOSystemDescriptionManager.cpp:313` | ✅ |
| `-[OOSystemDescriptionManager getPropertiesForCurrentSystem]` (276) | `getPropertiesForCurrentSystem` `Core/OOSystemDescriptionManager.cpp:317` | ✅ |
| `-[OOSystemDescriptionManager getPropertiesForSystemKey:]` (293) | `getPropertiesForSystemKey` `Core/OOSystemDescriptionManager.cpp:343` | ✅ |
| `-[OOSystemDescriptionManager getPropertiesForSystem:inGalaxy:]` (310) | `getPropertiesForSystem` `Core/OOSystemDescriptionManager.cpp:365` | ✅ |
| `-[OOSystemDescriptionManager getProperty:forSystemKey:]` (320) | `getProperty(property, key)` `Core/OOSystemDescriptionManager.cpp:378` | ✅ |
| `-[OOSystemDescriptionManager getProperty:forSystem:inGalaxy:]` (325) | `getProperty(property, s, g)` `Core/OOSystemDescriptionManager.cpp:383` | ✅ |
| `-[OOSystemDescriptionManager getProperty:forSystemKey:withUniversal:]` (339) | `getProperty(property, key, universal)` `Core/OOSystemDescriptionManager.cpp:403` (PRIORITY→DYNAMIC→STATIC→universal→CORE) | ✅ |
| `-[OOSystemDescriptionManager getProperty:orProperty:forSystemKey:withUniversal:]` (367) | `getProperty(property1, property2, key, universal)` `Core/OOSystemDescriptionManager.cpp:432` | ✅ |
| `-[OOSystemDescriptionManager setProperties:inDescription:]` (407) | `setProperties(const oo::PList&, OOSystemDescriptionEntry*)` `Core/OOSystemDescriptionManager.cpp:474` (default OXP_STATIC, clamp+log) | ✅ |
| `-[OOSystemDescriptionManager calculatePropertiesForSystemKey:]` (424) | `calculatePropertiesForSystemKey` `Core/OOSystemDescriptionManager.cpp:499` | ✅ |
| `-[OOSystemDescriptionManager updateCacheEntry:]` (448) | `updateCacheEntry(std::size_t)` `Core/OOSystemDescriptionManager.cpp:521` | ✅ |
| `-[OOSystemDescriptionManager updateCacheEntry:forProperty:]` (458) | `updateCacheEntry(std::size_t, const std::string&)` `Core/OOSystemDescriptionManager.cpp:531` | ✅ |
| `-[OOSystemDescriptionManager getCoordinatesForSystem:inGalaxy:]` (470) | `getCoordinatesForSystem` `Core/OOSystemDescriptionManager.cpp:548` | ✅ |
| `-[OOSystemDescriptionManager getNeighbourIDsForSystem:inGalaxy:]` (484) | `getNeighbourIDsForSystem` `Core/OOSystemDescriptionManager.cpp:568` | ✅ |
| `-[OOSystemDescriptionManager getRandomSeedForCurrentSystem]` (499) | `getRandomSeedForCurrentSystem` `Core/OOSystemDescriptionManager.cpp:589` | ✅ |
| `-[OOSystemDescriptionManager getRandomSeedForSystem:inGalaxy:]` (514) | `getRandomSeedForSystem` `Core/OOSystemDescriptionManager.cpp:613` | ✅ |
| `-[OOSystemDescriptionEntry init]` (536) | `OOSystemDescriptionEntry::OOSystemDescriptionEntry` `Core/OOSystemDescriptionManager.cpp:634` | ✅ |
| `-[OOSystemDescriptionEntry dealloc]` (547) | implicit destructor | ➖ |
| `-[OOSystemDescriptionEntry setProperty:forLayer:toValue:]` (555) | `OOSystemDescriptionEntry::setProperty` `Core/OOSystemDescriptionManager.cpp:640` | ✅ |
| `-[OOSystemDescriptionEntry getProperty:forLayer:]` (570) | `OOSystemDescriptionEntry::getProperty` `Core/OOSystemDescriptionManager.cpp:658` | ✅ |
| `-[OOSystemDescriptionEntry validateProperty:withValue:]` (580) | `OOSystemDescriptionEntry::validateProperty` `Core/OOSystemDescriptionManager.cpp:668` | ✅ |

**Differences:**

- ⚠️ **low** — `importScriptedChanges` clamps the saved layer: upstream cast the raw `oo_intAtIndex:3` to `OOSystemLayer`, so an out-of-range layer from a hand-edited save indexed past `layers[]`. The port maps anything over 3 (negatives too, via the unsigned cast) to OXP_PRIORITY; explained in the comment at :56-62 (bead oo-2eby no longer cited) (still open) — upstream `Core/OOSystemDescriptionManager.m:220` ↔ port `Core/OOSystemDescriptionManager.cpp:63-68,266-267`
- ⚠️ **low** — `importScriptedChanges` (and `importLegacyScriptedChanges`/`setProperties:inDescription:`) iterate in key order rather than hash order (comment at :254-255). Only matters when two saved keys hit the same system, property and layer from different manifests: the last one wins, so the winner may differ (still open) — upstream `Core/OOSystemDescriptionManager.m:211` ↔ port `Core/OOSystemDescriptionManager.cpp:256`
- ✅ subtle — upstream returned the live `propertyCache[i]` dictionary that `updateCacheEntry:` mutated in place; the port returns a copy and replaces the slot, so a caller holding the result has a snapshot — upstream `Core/OOSystemDescriptionManager.m:285,454-455` ↔ port `Core/OOSystemDescriptionManager.cpp:333,528`
- ✅ subtle — sun-radius legacy fix unchanged: `< 600000`, `+ 600000.0f` as a single real, layer OXP_DYNAMIC, manifest `org.oolite.oolite` — upstream `Core/OOSystemDescriptionManager.m:257-265` ↔ port `Core/OOSystemDescriptionManager.cpp:302-308`

## OOTrumble

<a id="ootrumble"></a>
Upstream `src/Core/OOTrumble.m` ↔ `Core/OOTrumble.cpp` (970 / 936 lines)

**Status:** done — 41 rows: 39 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOTrumble init]` (41) | `OOTrumble::OOTrumble()` `Core/OOTrumble.cpp:39` | ✅ |
| `-[OOTrumble initForPlayer:]` (54) | `OOTrumble::OOTrumble(PlayerEntity*)` `Core/OOTrumble.cpp:47` ("a1") | ✅ |
| `-[OOTrumble initForPlayer:digram:]` (63) | `OOTrumble::OOTrumble(PlayerEntity*, const std::string&)` `Core/OOTrumble.cpp:49` | ✅ |
| `-[OOTrumble setupForPlayer:digram:]` (72) | `OOTrumble::setupForPlayer` `Core/OOTrumble.cpp:53` | ❌ |
| `-[OOTrumble dealloc]` (210) | texture held by a shared_ptr member (`Core/OOTrumble.h`) | ➖ |
| `-[OOTrumble spawnFrom:]` (217) | `OOTrumble::spawnFrom` `Core/OOTrumble.cpp:194` (3×`ranrot_rand` & per mutation byte) | ✅ |
| `-[OOTrumble calcGrowthRate]` (252) | `OOTrumble::calcGrowthRate` `Core/OOTrumble.cpp:230` | ✅ |
| `-[OOTrumble digram]` (258) | `OOTrumble::getDigram` `Core/OOTrumble.cpp:235` | ✅ |
| `-[OOTrumble position]` (263) | `OOTrumble::getPosition` `Core/OOTrumble.cpp:237` | ✅ |
| `-[OOTrumble movement]` (268) | `OOTrumble::getMovement` `Core/OOTrumble.cpp:239` | ✅ |
| `-[OOTrumble rotation]` (273) | `OOTrumble::getRotation` `Core/OOTrumble.cpp:241` | ✅ |
| `-[OOTrumble size]` (278) | `OOTrumble::getSize` `Core/OOTrumble.cpp:243` | ✅ |
| `-[OOTrumble hunger]` (283) | `OOTrumble::getHunger` `Core/OOTrumble.cpp:245` | ✅ |
| `-[OOTrumble discomfort]` (288) | `OOTrumble::getDiscomfort` `Core/OOTrumble.cpp:247` | ✅ |
| `-[OOTrumble actionIdle]` (294) | `OOTrumble::actionIdle` `Core/OOTrumble.cpp:250` | ✅ |
| `-[OOTrumble actionBlink]` (300) | `OOTrumble::actionBlink` `Core/OOTrumble.cpp:255` | ✅ |
| `-[OOTrumble actionSnarl]` (306) | `OOTrumble::actionSnarl` `Core/OOTrumble.cpp:260` | ✅ |
| `-[OOTrumble actionProot]` (312) | `OOTrumble::actionProot` `Core/OOTrumble.cpp:265` | ✅ |
| `-[OOTrumble actionShudder]` (318) | `OOTrumble::actionShudder` `Core/OOTrumble.cpp:270` | ✅ |
| `-[OOTrumble actionStoned]` (324) | `OOTrumble::actionStoned` `Core/OOTrumble.cpp:275` | ✅ |
| `-[OOTrumble actionPop]` (330) | `OOTrumble::actionPop` `Core/OOTrumble.cpp:280` | ✅ |
| `-[OOTrumble actionSleep]` (336) | `OOTrumble::actionSleep` `Core/OOTrumble.cpp:285` | ✅ |
| `-[OOTrumble actionSpawn]` (342) | `OOTrumble::actionSpawn` `Core/OOTrumble.cpp:290` | ✅ |
| `-[OOTrumble randomizeMotionX]` (348) | `OOTrumble::randomizeMotionX` `Core/OOTrumble.cpp:295` | ✅ |
| `-[OOTrumble randomizeMotionY]` (355) | `OOTrumble::randomizeMotionY` `Core/OOTrumble.cpp:301` | ✅ |
| `-[OOTrumble drawTrumble:]` (362) | `OOTrumble::drawTrumble` `Core/OOTrumble.cpp:307` (same fan, tex coords, offsets) | ✅ |
| `-[OOTrumble updateTrumble:]` (490) | `OOTrumble::updateTrumble` `Core/OOTrumble.cpp:436` (one `randf()` per pod, bump limits 480/360) | ✅ |
| `-[OOTrumble updateIdle:]` (652) | `OOTrumble::updateIdle` `Core/OOTrumble.cpp:625` (same 7 draws in order) | ✅ |
| `-[OOTrumble updateBlink:]` (689) | `OOTrumble::updateBlink` `Core/OOTrumble.cpp:655` | ✅ |
| `-[OOTrumble updateSnarl:]` (706) | `OOTrumble::updateSnarl` `Core/OOTrumble.cpp:669` | ✅ |
| `-[OOTrumble updateProot:]` (742) | `OOTrumble::updateProot` `Core/OOTrumble.cpp:703` | ✅ |
| `-[OOTrumble updateShudder:]` (775) | `OOTrumble::updateShudder` `Core/OOTrumble.cpp:734` | ✅ |
| `-[OOTrumble updateStoned:]` (808) | `OOTrumble::updateStoned` `Core/OOTrumble.cpp:765` | ✅ |
| `-[OOTrumble updatePop:]` (812) | `OOTrumble::updatePop` `Core/OOTrumble.cpp:767` | ✅ |
| `-[OOTrumble updateSleep:]` (850) | `OOTrumble::updateSleep` `Core/OOTrumble.cpp:804` | ✅ |
| `-[OOTrumble updateSpawn:]` (880) | `OOTrumble::updateSpawn` `Core/OOTrumble.cpp:832` | ✅ |
| `-[OOTrumble dictionary]` (906) | `OOTrumble::dictionary` `Core/OOTrumble.cpp:857` (single reals, `%f %f` points) | ✅ |
| `-[OOTrumble setFromDictionary:]` (923) | `OOTrumble::setFromDictionary` `Core/OOTrumble.cpp:875` | ✅ |
| `InitTrumbleSounds` (943) | `InitTrumbleSounds` `Core/OOTrumble.cpp:895` | ✅ |
| `PlayTrumbleIdle` (952) | `PlayTrumbleIdle` `Core/OOTrumble.cpp:916` | ✅ |
| `PlayTrumbleSqueal` (962) | `PlayTrumbleSqueal` `Core/OOTrumble.cpp:926` | ✅ |

**Differences:**

- ❌ **low** — `setupForPlayer` with a one-character digram (e.g. a corrupt `digram` in a save): upstream `characterAtIndex:1` raised NSRangeException; the port reads 0 and carries on. A nil/missing digram reads 0,0 in both (still open) — upstream `Core/OOTrumble.m:76-77` ↔ port `Core/OOTrumble.cpp:58-60`
- ✅ checked — constants, the `ranrot_srand(r0 + r1*256)` seed, the monochrome-avoidance loop, and the order and count of `ranrot_rand()`/`randf()` calls are unchanged, including one `randf()` per cargo pod with a null market — upstream `Core/OOTrumble.m:110-196,581-589` ↔ port `Core/OOTrumble.cpp:96-182,533-550`
- ✅ subtle — `spawnFrom`/`dictionary` round-trip the UTF-16 digram through UTF-8; values stay below 0x100, so nothing is lost and GNUstep's BOM handling in `stringWithCharacters:` never triggers — upstream `Core/OOTrumble.m:221-228,909` ↔ port `Core/OOTrumble.cpp:197-207,862`
- ✅ subtle — eaten cargo is removed with `oo::EraseHold` (all equal entries, as `removeObject:`); sounds come from `OOSoundWithCustomSoundKey`, the same cache as `initWithCustomSoundKey:` — upstream `Core/OOTrumble.m:605,947-948` ↔ port `Core/OOTrumble.cpp:577,905-911`

## ResourceManager

<a id="resourcemanager"></a>
Upstream `src/Core/ResourceManager.m` ↔ `Core/ResourceManager.cpp` (1996 / 2382 lines)

**Status:** done — 71 rows: 57 ✅ 8 ⚠️ 4 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[ResourceManager reset]` (102) | `ResourceManager::reset` Core/ResourceManager.cpp:376 | ✅ |
| `+[ResourceManager resetManifestKnowledgeForOXZManager]` (114) | `resetManifestKnowledgeForOXZManager` Core/ResourceManager.cpp:387 | ✅ |
| `+[ResourceManager errors]` (123) | `errors` Core/ResourceManager.cpp:395 (`oo::str::formatRuntime`) | ✅ |
| `+[ResourceManager rootPaths]` (151) | `rootPaths` Core/ResourceManager.cpp:422 (oofnd/ResourcePaths.hpp:256) | ✅ |
| `+[ResourceManager userRootPaths]` (163) | `userRootPaths` Core/ResourceManager.cpp:439 (oofnd/ResourcePaths.hpp:245) | ✅ |
| `+[ResourceManager builtInPath]` (192) | `builtInPath` Core/ResourceManager.cpp:457 (oofnd/ResourcePaths.hpp:235) | ⚠️ |
| `+[ResourceManager pathsWithAddOns]` (212) | `pathsWithAddOns` Core/ResourceManager.cpp:464 (oofnd/FileSystem.hpp:193 `RecursiveDirectoryEnumerator`) | ❌ |
| `+[ResourceManager preloadFileLists]` (332) | `preloadFileLists` Core/ResourceManager.cpp:579 | ✅ |
| `+[ResourceManager preloadFileListFromOXZ:forFolders:]` (349) | `preloadFileListFromOXZ` Core/ResourceManager.cpp:596 | ✅ |
| `+[ResourceManager preloadFileListFromFolder:forFolders:]` (388) | `preloadFileListFromFolder` Core/ResourceManager.cpp:633 | ✅ |
| `+[ResourceManager preloadFilePathFor:inFolder:atPath:]` (406) | `preloadFilePathFor` Core/ResourceManager.cpp:650 | ✅ |
| `+[ResourceManager paths]` (418) | `paths` Core/ResourceManager.cpp:663 | ✅ |
| `+[ResourceManager maskUserNameInPathArray:]` (426) | `maskUserNameInPathArray` Core/ResourceManager.cpp:670 | ❌ |
| `+[ResourceManager maskUserName:inPath:]` (444) | `maskUserName` Core/ResourceManager.cpp:688 | ✅ |
| `+[ResourceManager useAddOns]` (455) | `useAddOns` Core/ResourceManager.cpp:694 | ✅ |
| `+[ResourceManager setUseAddOns:]` (460) | `setUseAddOns` Core/ResourceManager.cpp:696 | ✅ |
| `+[ResourceManager addExternalPath:]` (494) | `addExternalPath` Core/ResourceManager.cpp:727 | ✅ |
| `+[ResourceManager pathEnumerator]` (507) | none; callers iterate `paths()` | ➖ |
| `+[ResourceManager reversePathEnumerator]` (512) | none; callers iterate `paths()` with `rbegin()` | ➖ |
| `+[ResourceManager OXPsWithMessagesFound]` (517) | `OXPsWithMessagesFound` Core/ResourceManager.cpp:736 | ✅ |
| `+[ResourceManager manifestForIdentifier:]` (522) | `manifestForIdentifier` Core/ResourceManager.cpp:740 | ✅ |
| `+[ResourceManager checkOXPMessagesInPath:]` (527) | `checkOXPMessagesInPath` Core/ResourceManager.cpp:769 | ✅ |
| `+[ResourceManager checkPotentialPath:searchPaths:]` (546) | `checkPotentialPath` Core/ResourceManager.cpp:794 | ✅ |
| `+[ResourceManager validateManifest:forOXP:]` (590) | `validateManifest` Core/ResourceManager.cpp:859 | ✅ |
| `+[ResourceManager checkVersionCompatibility:forOXP:]` (647) | `checkVersionCompatibility` Core/ResourceManager.cpp:934 | ✅ |
| `+[ResourceManager areRequirementsFulfilled:forOXP:andFile:]` (659) | `areRequirementsFulfilled` Core/ResourceManager.cpp:953 | ⚠️ |
| `+[ResourceManager manifestHasConflicts:logErrors:]` (719) | `manifestHasConflicts` Core/ResourceManager.cpp:1026 | ✅ |
| `+[ResourceManager filterSearchPathsForConflicts:]` (749) | `filterSearchPathsForConflicts` Core/ResourceManager.cpp:1073 | ⚠️ |
| `+[ResourceManager manifestHasMissingDependencies:logErrors:]` (769) | `manifestHasMissingDependencies` Core/ResourceManager.cpp:1096 | ✅ |
| `+[ResourceManager manifest:HasUnmetDependency:logErrors:]` (787) | `ResourceManager::manifest(manifest, required, logErrors)` Core/ResourceManager.cpp:1112 | ✅ |
| `+[ResourceManager filterSearchPathsForRequirements:]` (828) | `filterSearchPathsForRequirements` Core/ResourceManager.cpp:1180 | ⚠️ |
| `+[ResourceManager matchVersions:withVersion:]` (853) | `matchVersions` Core/ResourceManager.cpp:1208 | ✅ |
| `+[ResourceManager filterSearchPathsToExcludeScenarioOnlyPaths:]` (877) | `filterSearchPathsToExcludeScenarioOnlyPaths` Core/ResourceManager.cpp:1234 | ✅ |
| `+[ResourceManager filterSearchPathsByScenario:]` (896) | `filterSearchPathsByScenario` Core/ResourceManager.cpp:1257 | ⚠️ |
| `+[ResourceManager manifestAllowedByScenario:]` (916) | `manifestAllowedByScenario(manifest)` Core/ResourceManager.cpp:1280 | ✅ |
| `+[ResourceManager manifestAllowedByScenario:withIdentifier:]` (947) | `manifestAllowedByScenario(manifest, identifier)` Core/ResourceManager.cpp:1317 | ✅ |
| `+[ResourceManager manifestAllowedByScenario:withTag:]` (962) | `manifestAllowedByScenarioWithTag` Core/ResourceManager.cpp:1334 | ✅ |
| `+[ResourceManager addErrorWithKey:param1:param2:]` (985) | `addErrorWithKey` Core/ResourceManager.cpp:1355 | ✅ |
| `+[ResourceManager checkCacheUpToDateForPaths:]` (994) | `checkCacheUpToDateForPaths` Core/ResourceManager.cpp:1363 (oofnd/FileSystem.hpp:177 `modificationTimeSince1970`) | ❌ |
| `+[ResourceManager corePlist:excludedAt:]` (1061) | `corePlist` Core/ResourceManager.cpp:1444 | ✅ |
| `+[ResourceManager dictionaryFromFilesNamed:inFolder:andMerge:]` (1081) | `dictionaryFromFilesNamed(…, bool)` Core/ResourceManager.cpp:1463 | ✅ |
| `+[ResourceManager dictionaryFromFilesNamed:inFolder:mergeMode:cache:]` (1088) | `dictionaryFromFilesNamed(…, OOResourceMergeMode, bool)` Core/ResourceManager.cpp:1472 | ✅ |
| `+[ResourceManager arrayFromFilesNamed:inFolder:andMerge:]` (1191) | `arrayFromFilesNamed(…, bool)` Core/ResourceManager.cpp:1567 | ✅ |
| `+[ResourceManager arrayFromFilesNamed:inFolder:andMerge:cache:]` (1196) | `arrayFromFilesNamed(…, bool, bool)` Core/ResourceManager.cpp:1573 | ✅ |
| `+[ResourceManager handleEquipmentListMerging:forLookupIndex:]` (1300) | `handleEquipmentListMerging` Core/ResourceManager.cpp:1675 | ✅ |
| `+[ResourceManager handleEquipmentOverrides:]` (1331) | `handleEquipmentOverrides` Core/ResourceManager.cpp:1713 | ❌ |
| `+[ResourceManager handleStarNebulaListMerging:]` (1414) | `handleStarNebulaListMerging` Core/ResourceManager.cpp:1799 (+ `TextureListKey` :301) | ✅ |
| `+[ResourceManager whitelistDictionary]` (1466) | `whitelistDictionary` Core/ResourceManager.cpp:1833 | ✅ |
| `LogClassKeyRoot` (1484) | `LogClassKeyRoot` Core/ResourceManager.cpp:323 | ✅ |
| `+[ResourceManager logControlDictionary]` (1494) | `logControlDictionary` Core/ResourceManager.cpp:1848 | ✅ |
| `+[ResourceManager roleCategoriesDictionary]` (1558) | `roleCategoriesDictionary` Core/ResourceManager.cpp:1916 | ✅ |
| `+[ResourceManager mergeRoleCategories:intoDictionary:]` (1589) | `mergeRoleCategories` Core/ResourceManager.cpp:1954 | ⚠️ |
| `+[ResourceManager systemDescriptionManager]` (1607) | `systemDescriptionManager` Core/ResourceManager.cpp:1984 | ✅ |
| `+[ResourceManager shaderBindingTypesDictionary]` (1646) | `shaderBindingTypesDictionary` Core/ResourceManager.cpp:2020 | ✅ |
| `+[ResourceManager pathForFileNamed:inFolder:]` (1687) | `pathForFileNamed(…)` Core/ResourceManager.cpp:2069 | ✅ |
| `+[ResourceManager pathForFileNamed:inFolder:cache:]` (1693) | `pathForFileNamed(…, bool)` Core/ResourceManager.cpp:2075 | ✅ |
| `+[ResourceManager retrieveFileNamed:inFolder:cache:key:class:usePathCache:]` (1743) | `retrieveFileNamed` Core/ResourceManager.cpp:2133 (class fixed to OOSound) | ✅ |
| `+[ResourceManager ooMusicNamed:inFolder:]` (1777) | `ooMusicNamed` Core/ResourceManager.cpp:2167 (inlines the uncached retrieve) | ✅ |
| `+[ResourceManager ooSoundNamed:inFolder:]` (1787) | `ooSoundNamed` Core/ResourceManager.cpp:2176 | ✅ |
| `+[ResourceManager stringFromFilesNamed:inFolder:]` (1797) | `stringFromFilesNamed(…)` Core/ResourceManager.cpp:2186 | ✅ |
| `+[ResourceManager stringFromFilesNamed:inFolder:cache:]` (1802) | `stringFromFilesNamed(…, bool)` Core/ResourceManager.cpp:2191 | ✅ |
| `+[ResourceManager loadScripts]` (1831) | `loadScripts` Core/ResourceManager.cpp:2222 | ⚠️ |
| `+[ResourceManager writeDiagnosticData:toFileNamed:]` (1898) | `writeDiagnosticData` Core/ResourceManager.cpp:2307 | ✅ |
| `+[ResourceManager writeDiagnosticString:toFileNamed:]` (1925) | `writeDiagnosticString` Core/ResourceManager.cpp:2336 | ✅ |
| `+[ResourceManager writeDiagnosticPList:toFileNamed:]` (1930) | `writeDiagnosticPList` Core/ResourceManager.cpp:2341 | ✅ |
| `+[ResourceManager materialDefaults]` (1941) | `materialDefaults` Core/ResourceManager.cpp:2352 | ✅ |
| `+[ResourceManager directoryExists:create:]` (1946) | `directoryExists` Core/ResourceManager.cpp:2357 | ✅ |
| `+[ResourceManager diagnosticFileLocation]` (1969) | `diagnosticFileLocation` Core/ResourceManager.cpp:2380 | ✅ |
| `+[ResourceManager logPaths]` (1974) | `logPaths` Core/ResourceManager.cpp:747 (+ `AbbreviatedWithTilde` :183) | ⚠️ |
| `+[ResourceManager clearCaches]` (1988) | `clearCaches` Core/ResourceManager.cpp:764 | ✅ |
| *(added)* `-[NSMutableDictionary(OOExtensions) mergeEntriesFromDictionary:]` (NSMutableDictionaryOOExtensions.m:30; used by MERGE_SMART) | `MergeEntries` Core/ResourceManager.cpp:272 (+ `PListIsEqual` :198 for `-isEqual:`) | ✅ |

**Differences:**

- ❌ **med** — Symlinked `.oxp` folders are still not found (still open). `RecursiveDirectoryEnumerator::next` types each entry with `symlink_status` (FileSystem.hpp:217,232-249), so a linked folder comes back `kSymbolicLink` and drops into the "not a directory" branch, which only accepts `oxz`. Upstream's `fileExistsAtPath:isDirectory:` followed the link and loaded the OXP. — upstream `Core/ResourceManager.m:263-269` ↔ port `Core/ResourceManager.cpp:509-528`
- ❌ **low** — The enumerator's relative path comes from `std::filesystem::relative`, which resolves symlinks (weakly_canonical) (new). The search path for a symlinked `.oxz` is therefore the link target's path (for example `root/../../elsewhere/x.oxz`), not `root/Link.oxz`. If the target's name does not end in `.oxz`, the link is skipped. A broken link named `*.oxz` is also passed to `checkPotentialPath` and logs `oxp.noManifest`, where upstream treated it as missing. — upstream `Core/ResourceManager.m:262-280` ↔ port `oofnd/FileSystem.hpp:217-220`, `Core/ResourceManager.cpp:507-527`
- ❌ **low** — The enumerator uses `directory_options::none`, and any `increment` error sets `ok_=false` and ends the whole walk (new). One unreadable subfolder under an AddOns root therefore hides every OXP after it in that root. GNUstep's NSDirectoryEnumerator skipped the folder and carried on. — upstream `Core/ResourceManager.m:260` ↔ port `oofnd/FileSystem.hpp:197-210`
- ❌ **med** — The data cache is still rebuilt on most launches (still open). `modificationTimeSince1970` converts with `ftime - file_clock::now() + system_clock::now()`, and the two `now()` readings are taken at different instants, so the stored double jitters on every call. The exact `PListIsEqual` against last run's dates then fails, logging `dataCache.rebuild.datesChanged` and clearing all caches. Upstream stored a stable `-timeIntervalSince1970`. — upstream `Core/ResourceManager.m:1028-1041` ↔ port `Core/ResourceManager.cpp:1402-1422` (cause: oofnd/FileSystem.hpp:183-187)
- ❌ **low** — `maskUserNameInPathArray` now passes the raw `SDL_getenv` result to `std::format("{}", …)` (new: the previous audit saw `oo::str::format("%s")`). If `USERPROFILE`/`HOME` is unset this is a null `const char*`, which is undefined behaviour (a strlen crash on MSVC). GNUstep printed "(null)" and went on. — upstream `Core/ResourceManager.m:430-436` ↔ port `Core/ResourceManager.cpp:674-681`
- ❌ **low** — `equipment-overrides.plist` (still open): within one entry, `name` and `short_description` write the same slot, as do `description` and `long_description`. The port walks the entry's keys in sorted `std::map` order, so `short_description` and `long_description` always win. Upstream used NSDictionary hash order. No comment marks this as intended. — upstream `Core/ResourceManager.m:1356-1369` ↔ port `Core/ResourceManager.cpp:1738-1751`
- ⚠️ **low** — Manifest filters iterate `sOXPManifests` in sorted-identifier order (commented "identifier order (was hash order)") (still open). This decides which of two mutually conflicting OXPs survives, the order of the `oxp.conflict` / `oxp.requirementMissing` lines and `sErrors`, and whether a by-tag `required_by` allowance sees a requirer that was already removed. — upstream `Core/ResourceManager.m:753,832,900,974` ↔ port `Core/ResourceManager.cpp:1075,1182,1259,1342`
- ⚠️ **low** — `mergeRoleCategories` holds each category as an array of unique roles in first-seen order, where upstream used an `NSMutableSet` (commented) (still open). Membership is the same; enumeration order differs. — upstream `Core/ResourceManager.m:1589-1605` ↔ port `Core/ResourceManager.cpp:1954-1982`
- ⚠️ **low** — `loadScripts` returns name→script pairs in first-load order; a later script with the same name replaces the earlier one in place (commented) (still open). Upstream returned an NSMutableDictionary in hash order. The `listAll` log is sorted and unaffected. — upstream `Core/ResourceManager.m:1843-1866` ↔ port `Core/ResourceManager.cpp:2224-2259`
- ⚠️ **low** — The `requirements.wrongType` log prints `oo::typeName(requirements.type())` ("dict") instead of the Foundation class name (commented at :981) (still open). — upstream `Core/ResourceManager.m:687,704` ↔ port `Core/ResourceManager.cpp:983-1008`
- ⚠️ **low** — `logPaths` drops `-stringByStandardizingPath` and keeps only the home→`~` abbreviation (commented at :179-182) (still open). The Windows extract root `../AddOns` (ResourcePaths.hpp:215) is not in fact standard, but GNUstep left a leading `..` alone anyway. — upstream `Core/ResourceManager.m:1982` ↔ port `Core/ResourceManager.cpp:747-762`
- ⚠️ **low** — `builtInPath` does not reproduce the macOS `[[NSBundle mainBundle] resourcePath]` branch ("The macOS (Cocoa) layout is not reproduced", ResourcePaths.hpp:48-49) (still open). The Windows/Linux rule is the same. — upstream `Core/ResourceManager.m:196-209` ↔ port `oofnd/ResourcePaths.hpp:235-241`
- ✅ **Merging (verified)** — The merge modes match: MERGE_NONE takes the last match in reverse order (folder before root, no `corePlist`); MERGE_BASIC is addEntries; MERGE_SMART is `MergeEntries`. The array merge runs the star/nebula and equipment handlers after each added file, against the just-added array. The cache keys are identical. — upstream `Core/ResourceManager.m:1088-1295` ↔ port `Core/ResourceManager.cpp:1472-1669`
- ✅ **low** (subtle) — `shaderBindingTypesDictionary` resolves `$inherit` in key order rather than hash order. Because the do/while loop repeats until nothing changes, chains end up the same either way. A missing file is cached as null, where upstream retried, but this is not observable. — upstream `Core/ResourceManager.m:1655-1679` ↔ port `Core/ResourceManager.cpp:2029-2063`
- ✅ **low** (subtle) — The `filterSearchPaths*` loops pass `manifest()` a copy of each manifest, where upstream passed the live dictionary. This only matters for an OXP that lists itself in `requires_oxps`. — upstream `Core/ResourceManager.m:839-841` ↔ port `Core/ResourceManager.cpp:1194-1195`

