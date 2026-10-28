# Parity findings: Game data, resources, registries, AI, strings

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## AI

<a id="ai"></a>
Upstream `src/Core/AI.m` ↔ `Core/AI.cpp`

**Status:** done — 51 rows: 41 ✅ 6 ⚠️ 2 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[AI currentlyRunningAI]` (98) | `AI::currentlyRunningAI` Core/AI.cpp:181 | ✅ |
| `+[AI currentlyRunningAIDescription]` (103) | `AI::currentlyRunningAIDescription` Core/AI.cpp:186 | ✅ |
| `-[AI init]` (112) | `AI::AI` Core/AI.cpp:195 | ✅ |
| `-[AI initWithStateMachine:andState:]` (124) | `AI::initWithStateMachine` Core/AI.cpp:205 (+ `newWithStateMachine` :156) | ✅ |
| `-[AI dealloc]` (136) | `AI::~AI` Core/AI.cpp:215 | ✅ |
| `-[AI descriptionComponents]` (154) | `AI::descriptionComponents` Core/AI.cpp:224 | ✅ |
| `-[AI shortDescriptionComponents]` (159) | `AI::shortDescriptionComponents` Core/AI.cpp:229 | ✅ |
| `-[AI owner]` (164) | `AI::owner` Core/AI.cpp:234 | ✅ |
| `-[AI setOwner:]` (175) | `AI::setOwner` Core/AI.cpp:245 | ✅ |
| `-[AI reportStackOverflow]` (182) | `AI::reportStackOverflow` Core/AI.cpp:251 | ❌ |
| `-[AI preserveCurrentStateMachine]` (204) | `AI::preserveCurrentStateMachine` Core/AI.cpp:273 | ✅ |
| `-[AI restorePreviousStateMachine]` (237) | `AI::restorePreviousStateMachine` Core/AI.cpp:300 | ✅ |
| `-[AI hasSuspendedStateMachines]` (263) | `AI::hasSuspendedStateMachines` Core/AI.cpp:326 | ✅ |
| `-[AI exitStateMachineWithMessage:]` (268) | `AI::exitStateMachineWithMessage` Core/AI.cpp:331 | ✅ |
| `-[AI setStateMachine:withJSScript:]` (278) | `AI::setStateMachine(smName, script)` Core/AI.cpp:339 | ✅ |
| `-[AI setState:]` (303) | `AI::setState(stateName)` Core/AI.cpp:364 | ✅ |
| `-[AI setStateMachine:afterDelay:]` (319) | `AI::setStateMachine(smName, delay)` Core/AI.cpp:380 | ⚠️ |
| `-[AI setState:afterDelay:]` (324) | `AI::setState(stateName, delay)` Core/AI.cpp:385 → `deferredSetState` :716 | ✅ |
| `-[AI name]` (329) | `AI::name` Core/AI.cpp:390 | ✅ |
| `-[AI associatedJS]` (334) | `AI::associatedJS` Core/AI.cpp:395 | ✅ |
| `-[AI state]` (339) | `AI::state` Core/AI.cpp:403 | ✅ |
| `-[AI stackDepth]` (344) | `AI::stackDepth` Core/AI.cpp:408 | ✅ |
| `-[AI reactToMessage:context:]` (363) | `AI::reactToMessage` Core/AI.cpp:427 | ❌ |
| `-[AI takeAction:]` (461) | `AI::takeAction` Core/AI.cpp:536 | ⚠️ |
| `-[AI think]` (514) | `AI::think` Core/AI.cpp:595 | ⚠️ |
| `-[AI message:]` (536) | `AI::message` Core/AI.cpp:611 (+ `PendingMessagesDescription` :74) | ⚠️ |
| `-[AI dropMessage:]` (552) | `AI::dropMessage` Core/AI.cpp:624 | ✅ |
| `-[AI pendingMessages]` (557) | `AI::getPendingMessages` Core/AI.cpp:629 | ✅ |
| `-[AI debugDumpPendingMessages]` (566) | `AI::debugDumpPendingMessages` Core/AI.cpp:634 | ✅ |
| `-[AI setNextThinkTime:]` (581) | `AI::setNextThinkTime` Core/AI.cpp:657 | ✅ |
| `-[AI nextThinkTime]` (586) | `AI::getNextThinkTime` Core/AI.cpp:662 | ✅ |
| `-[AI setThinkTimeInterval:]` (594) | `AI::setThinkTimeInterval` Core/AI.cpp:670 | ✅ |
| `-[AI thinkTimeInterval]` (599) | `AI::getThinkTimeInterval` Core/AI.cpp:675 | ✅ |
| `-[AI clearStack]` (604) | `AI::clearStack` Core/AI.cpp:680 | ✅ |
| `-[AI clearAllData]` (609) | `AI::clearAllData` Core/AI.cpp:685 | ✅ |
| `-[AI dumpState]` (617) | `AI::dumpState` Core/AI.cpp:693 | ✅ |
| `-[AI(OOPrivate) performDeferredCall:withObject:afterDelay:]` (635) | `AI::performDeferredCall` Core/AI.cpp:707 (`OOScheduleDeferredCall` lambda) | ✅ |
| `+[AI(OOPrivate) deferredCallTrampolineWithInfo:]` (654) | `FireAIDeferredCall` + `kDeferredAIMethods` Core/AI.cpp:92,115 | ➖ |
| `-[AI(OOPrivate) refreshOwnerDesc]` (669) | `AI::refreshOwnerDesc` Core/AI.cpp:721 | ✅ |
| `-[AI(OOPrivate) directSetStateMachine:name:]` (682) | `AI::directSetStateMachine` Core/AI.cpp:733 | ✅ |
| `-[AI(OOPrivate) directSetState:]` (694) | `AI::directSetState` Core/AI.cpp:739 | ✅ |
| `-[AI(OOPrivate) loadStateMachine:jsName:]` (702) | `AI::loadStateMachine` Core/AI.cpp:744 (+ `PListDictionaryFromFile` :58) | ⚠️ |
| `-[AI(OOPrivate) cleanHandlers:forState:stateMachine:]` (779) | `AI::cleanHandlers` Core/AI.cpp:811 | ⚠️ |
| `-[AI(OOPrivate) cleanActions:forHandler:state:stateMachine:]` (802) | `AI::cleanActions` Core/AI.cpp:829 | ✅ |
| `-[OOPreservedAIStateMachine initWithStateMachine:]` (877) | `OOPreservedAIStateMachine::OOPreservedAIStateMachine` Core/AI.cpp:910 | ✅ |
| `-[OOPreservedAIStateMachine dealloc]` (894) | none (value members; `oo::RefCounted`) | ➖ |
| `-[OOPreservedAIStateMachine stateMachine]` (905) | `OOPreservedAIStateMachine::stateMachine` Core/AI.cpp:925 | ✅ |
| `-[OOPreservedAIStateMachine name]` (910) | `OOPreservedAIStateMachine::name` Core/AI.cpp:930 | ✅ |
| `-[OOPreservedAIStateMachine state]` (915) | `OOPreservedAIStateMachine::state` Core/AI.cpp:935 | ✅ |
| `-[OOPreservedAIStateMachine pendingMessages]` (920) | `OOPreservedAIStateMachine::pendingMessages` Core/AI.cpp:940 | ✅ |
| `-[OOPreservedAIStateMachine jsScript]` (925) | `OOPreservedAIStateMachine::jsScript` Core/AI.cpp:945 | ✅ |

**Differences:**

- ⚠️ **med** — `think` handles deferred messages in byte order of the message (`std::set`), where upstream used `-[NSSet allObjects]` hash order. One message can change state, so the order decides which state's handler sees the next message. AI behaviour, and with it goldens, can differ when two or more messages are pending in one tick. The code comment and ADR-0043 ("Reproduce GNUstep's hash order" rejected) cover this. — upstream `Core/AI.m:524-533` ↔ port `Core/AI.cpp:602-608`
- ❌ **low** — The `ai.error.stackOverflow.dump` lines lost upstream's `%3zu` width: the port writes `{}: ` instead of a right-aligned 3-wide index. The same happens in the debug-build `ai.error.recursion.stackTrace` lines, where `%4u  ` became `{}  `. Only log text is affected. — upstream `Core/AI.m:196`, `:408` ↔ port `Core/AI.cpp:265`, `:472`
- ⚠️ **low** — `reactToMessage` now unwinds the debug `sStack` frame on the "no handlers for this state" early return. Upstream left `sStack` pointing at a dead stack frame, so it could later print garbage or crash in `ai.error.recursion.stackTrace`. This applies to debug builds only, and the code comment says so. — upstream `Core/AI.m:420-422` ↔ port `Core/AI.cpp:484-492`
- ⚠️ **low** — `reactToMessage` catches only `OOException`; any other C++ exception propagates, as a non-NSException did upstream. The `kOOLogException` text is unchanged. — upstream `Core/AI.m:440-442` ↔ port `Core/AI.cpp:511-516`
- ⚠️ **low** — `takeAction` and `interpretAIMessage:` use `oo::EntityRespondsToName` / `oo::CallEntityByName` instead of `respondsToSelector:` / `performSelector:` (ADR-0055 item 5, bead oo-9ht.39.7.1). A whitelisted AI method that is missing from the by-name table now logs `ai.takeAction.badSelector`, where upstream dispatched it. Coverage of the table was not audited here. — upstream `Core/AI.m:447-449,488-496` ↔ port `Core/AI.cpp:522-524,570-577`
- ⚠️ **low** — `setStateMachine:afterDelay:` deferred `-setStateMachine:`, which AI does not implement. Upstream raised "does not recognize selector" from the timer. The port logs `callByName.unknownSelector` and does nothing (code comment, bead oo-9ht.73). The upstream trampoline also over-released `parameter`, which it never retained; that is gone. — upstream `Core/AI.m:319-322,662-665` ↔ port `Core/AI.cpp:82-94,115-125,380-383`
- ⚠️ **low** — `message:` overflow log: the pending-message list is printed in byte order (array description), where upstream printed the `NSSet` `%@` in hash order (code comment). — upstream `Core/AI.m:543` ↔ port `Core/AI.cpp:618`
- ⚠️ **low** — `loadStateMachine` / `cleanHandlers` visit states and handlers in key order, not hash order, so the `ai.invalidFormat.*` and `ai.unpermittedMethod` warnings come out in a different order. The resulting state machine is the same (code comments, ADR-0043). A non-dictionary AI file no longer emits OODictionaryFromFile's `plist.wrongType` line (comment at :55-57). — upstream `Core/AI.m:728,742,786` ↔ port `Core/AI.cpp:58-62,783-792,815-824`
- ✅ **low** (subtle) — `restorePreviousStateMachine` passes `""` to `setAIScript` where upstream passed nil for a missing `jsScript`. This is unreachable, because `loadStateMachine` always stores `jsScript`. — upstream `Core/AI.m:255` ↔ port `Core/AI.cpp:318-319`
- ✅ **low** (subtle) — In `cleanActions`, parameters are cut at the first `' '` byte (`std::string::find`) rather than with `-rangeOfString:@" "`. The whitelist is built from string entries only, and `containsObject:` only ever matched strings anyway. Alias handling, both string and pretokenized array, is the same. — upstream `Core/AI.m:814-866` ↔ port `Core/AI.cpp:835-905`

## AIGraphViz

<a id="aigraphviz"></a>
Upstream `src/Core/AIGraphViz.m` ↔ `Core/AIGraphViz.cpp`

**Status:** done — 6 rows: 4 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `GenerateGraphVizForAIStateMachine()` (38) | `GenerateGraphVizForAIStateMachine` Core/AIGraphViz.cpp:179 | ⚠️ |
| `HandlerToken()` (104) | `HandlerToken` Core/AIGraphViz.cpp:52 | ✅ |
| `HandleOneCommand()` (124) | `HandleOneCommand` Core/AIGraphViz.cpp:128 (+ `CommandAt` :43) | ⚠️ |
| `AddSimpleSpecialNodeLink()` (172) | `AddSimpleSpecialNodeLink` Core/AIGraphViz.cpp:67 | ✅ |
| `AddExitAINode()` (181) | `AddExitAINode` Core/AIGraphViz.cpp:76 | ✅ |
| `AddChangeAINode()` (197) | `AddChangeAINode` Core/AIGraphViz.cpp:92 | ✅ |

**Differences:**

- ⚠️ **low** — States and handlers are written in key order, and special nodes in sorted-string order, instead of `NSDictionary`/`NSSet` hash order. The `.dot` content is the same; only line order changes. This is a debug dump that is not part of the goldens (file comment, proposed ADR-0043, bead oo-ndxe). — upstream `Core/AIGraphViz.m:56,64,77,95` ↔ port `Core/AIGraphViz.cpp:32-36,195-236`
- ⚠️ **low** — An empty command string (no tokens) is skipped. Upstream raised from `-objectAtIndex:0` (code comment). — upstream `Core/AIGraphViz.m:130-131` ↔ port `Core/AIGraphViz.cpp:134-138`
- ✅ (note) — The `jsScript` entry, a string, still gets a `cluster_jsScript` subgraph with an implicit ENTER node, as `oo_dictionaryForKey:` returning nil did. The `tspecial_broken_` typo is kept. — upstream `Core/AIGraphViz.m:62-72,229` ↔ port `Core/AIGraphViz.cpp:201-211,124`

## OOCharacter

<a id="oocharacter"></a>
Upstream `src/Core/OOCharacter.m` ↔ `Core/OOCharacter.cpp`

**Status:** done — 31 rows: 29 ✅ 1 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCharacter descriptionComponents]` (45) | `OOCharacter::descriptionComponents` `Core/OOCharacter.cpp:49` | ✅ |
| `-[OOCharacter oo_jsClassName]` (50) | `OOCharacter::oo_jsClassName` `Core/OOCharacter.cpp:56` | ✅ |
| `-[OOCharacter dealloc]` (55) | implicit destructor (RAII members) | ➖ |
| `-[OOCharacter initWithGenSeed:andOriginalSystem:]` (65) | `OOCharacter::OOCharacter(Random_Seed, OOSystemID)` `Core/OOCharacter.cpp:75` | ✅ |
| `-[OOCharacter initWithRole:andOriginalSystem:]` (77) | `OOCharacter::OOCharacter(const std::string&, OOSystemID)` `Core/OOCharacter.cpp:96` (+ `PseudoRandomSeed` :87) | ✅ |
| `+[OOCharacter characterWithRole:andOriginalSystem:]` (89) | `OOCharacter::characterWithRole` `Core/OOCharacter.cpp:102` | ✅ |
| `+[OOCharacter randomCharacterWithRole:andOriginalSystem:]` (94) | `OOCharacter::randomCharacterWithRole` `Core/OOCharacter.cpp:107` | ✅ |
| `+[OOCharacter characterWithDictionary:]` (111) | `OOCharacter::characterWithDictionary` `Core/OOCharacter.cpp:124` (default ctor zeroes fields, `OOCharacter.h:47`) | ✅ |
| `-[OOCharacter planetOfOrigin]` (119) | `OOCharacter::planetOfOrigin` `Core/OOCharacter.cpp:133` | ✅ |
| `-[OOCharacter planetIDOfOrigin]` (126) | `OOCharacter::planetIDOfOrigin` `Core/OOCharacter.cpp:143` | ✅ |
| `-[OOCharacter species]` (132) | `OOCharacter::species` `Core/OOCharacter.cpp:149` | ✅ |
| `-[OOCharacter basicSetUp]` (149) | `OOCharacter::basicSetUp` `Core/OOCharacter.cpp:169` | ✅ |
| `-[OOCharacter castInRole:]` (219) | `OOCharacter::castInRole` `Core/OOCharacter.cpp:251` | ✅ |
| `-[OOCharacter name]` (297) | `OOCharacter::name` `Core/OOCharacter.cpp:329` | ✅ |
| `-[OOCharacter shortDescription]` (302) | `OOCharacter::shortDescription` `Core/OOCharacter.cpp:334` | ✅ |
| `-[OOCharacter genSeed]` (307) | `OOCharacter::genSeed` `Core/OOCharacter.cpp:339` | ✅ |
| `-[OOCharacter legalStatus]` (312) | `OOCharacter::legalStatus` `Core/OOCharacter.cpp:344` | ✅ |
| `-[OOCharacter insuranceCredits]` (317) | `OOCharacter::insuranceCredits` `Core/OOCharacter.cpp:349` | ✅ |
| `-[OOCharacter legacyScript]` (322) | `OOCharacter::legacyScript` `Core/OOCharacter.cpp:354` | ✅ |
| `-[OOCharacter infoForScripting]` (327) | `OOCharacter::infoForScripting` `Core/OOCharacter.cpp:359` | ✅ |
| `-[OOCharacter setName:]` (339) | `OOCharacter::setName` `Core/OOCharacter.cpp:380` | ✅ |
| `-[OOCharacter setShortDescription:]` (345) | `OOCharacter::setShortDescription` `Core/OOCharacter.cpp:385` | ✅ |
| `-[OOCharacter setOriginSystem:]` (351) | `OOCharacter::setOriginSystem` `Core/OOCharacter.cpp:390` | ✅ |
| `-[OOCharacter setGenSeed:]` (356) | `OOCharacter::setGenSeed` `Core/OOCharacter.cpp:395` | ✅ |
| `-[OOCharacter setLegalStatus:]` (361) | `OOCharacter::setLegalStatus` `Core/OOCharacter.cpp:400` | ✅ |
| `-[OOCharacter setInsuranceCredits:]` (366) | `OOCharacter::setInsuranceCredits` `Core/OOCharacter.cpp:405` | ✅ |
| `-[OOCharacter setLegacyScript:]` (371) | `OOCharacter::setLegacyScript` `Core/OOCharacter.cpp:410` | ✅ |
| `-[OOCharacter script]` (377) | `OOCharacter::script` `Core/OOCharacter.cpp:415` | ✅ |
| `-[OOCharacter setCharacterScript:]` (382) | `OOCharacter::setCharacterScript` `Core/OOCharacter.cpp:420` | ✅ |
| `-[OOCharacter doScriptEvent:]` (390) | `OOCharacter::doScriptEvent` `Core/OOCharacter.cpp:428` | ✅ |
| `-[OOCharacter setCharacterFromDictionary:]` (397) | `OOCharacter::setCharacterFromDictionary` `Core/OOCharacter.cpp:436` | ⚠️ |

**Differences:**

- ⚠️ **low** — the `origin` key is accepted only as a number or a string. Upstream took any object that answered `-intValue` non-zero or was `@"0"`. Port comment cites bead oo-4aq6a.5 ("no game object is one"); plist and JS input are unaffected — upstream `Core/OOCharacter.m:403` ↔ port `Core/OOCharacter.cpp:444-446`
- ✅ subtle — the `basicSetUp` bounty expression has unspecified evaluation order upstream (`criminalTendency * (gen_rnd_number() & 3) + (gen_rnd_number() & gen_rnd_number() & 0x7f)`). The port fixes it left-to-right (clang's order); a GCC-built upstream could have drawn differently — upstream `Core/OOCharacter.m:191` ↔ port `Core/OOCharacter.cpp:219-222`
- ✅ subtle — the generated name is likewise built left-to-right: given name (`%R`) first, then family name. Upstream's `stringWithFormat:` arguments had unspecified order — upstream `Core/OOCharacter.m:167,175` ↔ port `Core/OOCharacter.cpp:191-202`
- ✅ subtle — `infoForScripting` reproduces the `dictionaryWithObjectsAndKeys:` truncation at the first nil (name → description → species) — upstream `Core/OOCharacter.m:329` ↔ port `Core/OOCharacter.cpp:363-376`


## OOColor

<a id="oocolor"></a>
Upstream `src/Core/OOColor.m` ↔ `Core/OOColor.cpp`

**Status:** done — 49 rows: 47 ✅ 1 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOColor setRed:green:blue:alpha:]` (32) | `OOColor::setRed` `Core/OOColor.cpp:68` | ✅ |
| `-[OOColor setHue:saturation:brightness:alpha:]` (40) | `OOColor::setHue` `Core/OOColor.cpp:76` | ✅ |
| `-[OOColor copyWithZone:]` (94) | — immutable; the same `oo::Ref<OOColor>` is shared | ➖ |
| `+[OOColor colorWithHue:saturation:brightness:alpha:]` (100) | `OOColor::colorWithHue` `Core/OOColor.cpp:130` | ✅ |
| `+[OOColor colorWithRed:green:blue:alpha:]` (107) | `OOColor::colorWithRed` `Core/OOColor.cpp:137` | ✅ |
| `+[OOColor colorWithWhite:alpha:]` (114) | `OOColor::colorWithWhite` `Core/OOColor.cpp:144` | ✅ |
| `+[OOColor colorWithRGBAComponents:]` (119) | `OOColor::colorWithRGBAComponents` `Core/OOColor.cpp:149` | ✅ |
| `+[OOColor colorWithHSBAComponents:]` (127) | `OOColor::colorWithHSBAComponents` `Core/OOColor.cpp:157` | ✅ |
| `+[OOColor colorWithDescription:]` (135) | `OOColor::colorWithDescription(description)` `Core/OOColor.cpp:165` | ✅ |
| `+[OOColor colorWithDescription:saturationFactor:]` (140) | `OOColor::colorWithDescription(description, factor)` `Core/OOColor.cpp:170` (+ `kNamedColors` :47) | ✅ |
| `+[OOColor brightColorWithDescription:]` (202) | `OOColor::brightColorWithDescription` `Core/OOColor.cpp:246` | ✅ |
| `+[OOColor colorFromString:]` (211) | `OOColor::colorFromString` `Core/OOColor.cpp:255` | ✅ |
| `+[OOColor blackColor]` (234) | `OOColor::blackColor` `Core/OOColor.cpp:278` | ✅ |
| `+[OOColor darkGrayColor]` (239) | `OOColor::darkGrayColor` `Core/OOColor.cpp:283` | ✅ |
| `+[OOColor lightGrayColor]` (244) | `OOColor::lightGrayColor` `Core/OOColor.cpp:288` | ✅ |
| `+[OOColor whiteColor]` (249) | `OOColor::whiteColor` `Core/OOColor.cpp:293` | ✅ |
| `+[OOColor grayColor]` (254) | `OOColor::grayColor` `Core/OOColor.cpp:298` | ✅ |
| `+[OOColor redColor]` (259) | `OOColor::redColor` `Core/OOColor.cpp:303` | ✅ |
| `+[OOColor greenColor]` (264) | `OOColor::greenColor` `Core/OOColor.cpp:308` | ✅ |
| `+[OOColor blueColor]` (269) | `OOColor::blueColor` `Core/OOColor.cpp:313` | ✅ |
| `+[OOColor cyanColor]` (274) | `OOColor::cyanColor` `Core/OOColor.cpp:318` | ✅ |
| `+[OOColor yellowColor]` (279) | `OOColor::yellowColor` `Core/OOColor.cpp:323` | ✅ |
| `+[OOColor magentaColor]` (284) | `OOColor::magentaColor` `Core/OOColor.cpp:328` | ✅ |
| `+[OOColor orangeColor]` (289) | `OOColor::orangeColor` `Core/OOColor.cpp:333` | ✅ |
| `+[OOColor purpleColor]` (294) | `OOColor::purpleColor` `Core/OOColor.cpp:338` | ✅ |
| `+[OOColor brownColor]` (299) | `OOColor::brownColor` `Core/OOColor.cpp:343` | ✅ |
| `+[OOColor clearColor]` (304) | `OOColor::clearColor` `Core/OOColor.cpp:348` | ✅ |
| `-[OOColor blendedColorWithFraction:ofColor:]` (309) | `OOColor::blendedColorWithFraction` `Core/OOColor.cpp:353` | ⚠️ |
| `-[OOColor descriptionComponents]` (323) | `OOColor::descriptionComponents` `Core/OOColor.cpp:369` (+ `className`/`description` :374,:379) | ✅ |
| `-[OOColor redComponent]` (329) | `OOColor::redComponent` `Core/OOColor.cpp:389` | ✅ |
| `-[OOColor greenComponent]` (334) | `OOColor::greenComponent` `Core/OOColor.cpp:394` | ✅ |
| `-[OOColor blueComponent]` (339) | `OOColor::blueComponent` `Core/OOColor.cpp:399` | ✅ |
| `-[OOColor getRed:green:blue:alpha:]` (344) | `OOColor::getRed` `Core/OOColor.cpp:404` | ✅ |
| `-[OOColor rgbaComponents]` (354) | `OOColor::rgbaComponents` `Core/OOColor.cpp:414` | ✅ |
| `-[OOColor isBlack]` (360) | `OOColor::isBlack` `Core/OOColor.cpp:420` | ✅ |
| `-[OOColor isWhite]` (365) | `OOColor::isWhite` `Core/OOColor.cpp:425` | ✅ |
| `-[OOColor hueComponent]` (371) | `OOColor::hueComponent` `Core/OOColor.cpp:431` | ✅ |
| `-[OOColor saturationComponent]` (390) | `OOColor::saturationComponent` `Core/OOColor.cpp:450` | ✅ |
| `-[OOColor brightnessComponent]` (397) | `OOColor::brightnessComponent` `Core/OOColor.cpp:457` | ✅ |
| `-[OOColor getHue:saturation:brightness:alpha:]` (403) | `OOColor::getHue` `Core/OOColor.cpp:463` | ✅ |
| `-[OOColor hsbaComponents]` (431) | `OOColor::hsbaComponents` `Core/OOColor.cpp:491` | ✅ |
| `-[OOColor alphaComponent]` (442) | `OOColor::alphaComponent` `Core/OOColor.cpp:502` | ✅ |
| `-[OOColor premultipliedColor]` (447) | `OOColor::premultipliedColor` `Core/OOColor.cpp:507` | ✅ |
| `-[OOColor colorWithBrightnessFactor:]` (457) | `OOColor::colorWithBrightnessFactor` `Core/OOColor.cpp:517` | ✅ |
| `-[OOColor normalizedArray]` (465) | `OOColor::normalizedArray` `Core/OOColor.cpp:525` (`std::vector<float>`) | ✅ |
| `-[OOColor rgbaDescription]` (477) | `OOColor::rgbaDescription` `Core/OOColor.cpp:532` | ✅ |
| `-[OOColor hsbaDescription]` (482) | `OOColor::hsbaDescription` `Core/OOColor.cpp:537` | ✅ |
| `OORGBAComponentsDescription()` (489) | `OORGBAComponentsDescription` `Core/OOColor.cpp:542` | ✅ |
| `OOHSBAComponentsDescription()` (494) | `OOHSBAComponentsDescription` `Core/OOColor.cpp:547` | ✅ |

**Differences:**

- ⚠️ **low** — `blendedColorWithFraction:ofColor:nil` left `rgba1` uninitialised upstream (message to nil), so the result was indeterminate. The port blends with zeros; a code comment says so — upstream `Core/OOColor.m:311-312` ↔ port `Core/OOColor.cpp:355-358`
- ✅ subtle — the `+fooColor` selector lookup became an explicit table of the 15 named colours. A string ending in `Color` that matches none gives nil in both — upstream `Core/OOColor.m:151-155` ↔ port `Core/OOColor.cpp:47-63,182-189`
- ✅ subtle — the array form skips null elements before joining with spaces, so they never reach the scanner. Each element is joined using `oo::DescriptionOf`, which mirrors NSNumber's `%0.16g`/`%0.7g` descriptions. `colorFromString` uses `oo::str::Scanner::scanFloat`, a GNUstep `scanDouble` port narrowed to float — upstream `Core/OOColor.m:161,214-219` ↔ port `Core/OOColor.cpp:194-206,258-263`
- ✅ subtle — `setHue` calls `fmod`/`floor` with float arguments, which select the C++ float overloads; upstream used C double. Both are exact, so the stored components are bit-identical. `getHue` uses `fmax`/`fmin`, which are likewise exact — upstream `Core/OOColor.m:49,54,410-411` ↔ port `Core/OOColor.cpp:85,90,470-471`
- ✅ subtle — the dict form tests for a non-null `hue` (upstream: `objectForKey:` non-nil). The `get<float>` defaults match the `oo_floatForKey:` defaults (`saturation` 1, `brightness`→`value` 1, `alpha`→`opacity` 1) — upstream `Core/OOColor.m:165-185` ↔ port `Core/OOColor.cpp:208-229`


## OOCommodities

<a id="oocommodities"></a>
Upstream `src/Core/OOCommodities.m` ↔ `Core/OOCommodities.cpp`

**Status:** done — 23 rows: 16 ✅ 6 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOCommodities legacyCommodityType:]` (55) | `OOCommodities::legacyCommodityType` `Core/OOCommodities.cpp:127` | ✅ |
| `-[OOCommodities init]` (97) | `OOCommodities::OOCommodities` `Core/OOCommodities.cpp:169` | ✅ |
| `-[OOCommodities dealloc]` (122) | implicit destructor (`std::map` member, `Core/OOCommodities.h:88`) | ➖ |
| `-[OOCommodities generateManifestForPlayer]` (129) | `OOCommodities::generateManifestForPlayer` `Core/OOCommodities.cpp:179` | ✅ |
| `-[OOCommodities generateBlankMarket]` (150) | `OOCommodities::generateBlankMarket` `Core/OOCommodities.cpp:198` | ✅ |
| `-[OOCommodities createDefinitionFrom:price:andQuantity:forKey:atStation:inSystem:]` (169) | `OOCommodities::createDefinitionFrom` `Core/OOCommodities.cpp:215` | ✅ |
| `-[OOCommodities modifyGood:withScript:atStation:inSystem:localMode:]` (196) | `OOCommodities::modifyGood` `Core/OOCommodities.cpp:242` | ✅ |
| `-[OOCommodities generateMarketForSystemWithEconomy:andScript:]` (247) | `OOCommodities::generateMarketForSystemWithEconomy` `Core/OOCommodities.cpp:286` | ⚠️ |
| `-[OOCommodities generateMarketForStation:]` (275) | `OOCommodities::generateMarketForStation` `Core/OOCommodities.cpp:312` | ⚠️ |
| `-[OOCommodities count]` (333) | `OOCommodities::count` `Core/OOCommodities.cpp:368` | ✅ |
| `-[OOCommodities goods]` (338) | `OOCommodities::goods` `Core/OOCommodities.cpp:373` | ⚠️ |
| `-[OOCommodities goodDefined:]` (343) | `OOCommodities::goodDefined` `Core/OOCommodities.cpp:382` | ✅ |
| `-[OOCommodities goodNamed:]` (348) | `OOCommodities::goodNamed` `Core/OOCommodities.cpp:388` | ⚠️ |
| `-[OOCommodities getRandomCommodity]` (361) | `OOCommodities::getRandomCommodity` `Core/OOCommodities.cpp:401` | ⚠️ |
| `-[OOCommodities massUnitForGood:]` (368) | `OOCommodities::massUnitForGood` `Core/OOCommodities.cpp:410` | ⚠️ |
| `-[OOCommodities generateQuantityForGood:inEconomy:]` (377) | `OOCommodities::generateQuantityForGood` `Core/OOCommodities.cpp:419` | ✅ |
| `-[OOCommodities generatePriceForGood:inEconomy:]` (392) | `OOCommodities::generatePriceForGood` `Core/OOCommodities.cpp:437` | ✅ |
| `-[OOCommodities samplePriceForCommodity:inEconomy:withScript:inSystem:]` (407) | `OOCommodities::samplePriceForCommodity` `Core/OOCommodities.cpp:455` | ✅ |
| `-[OOCommodities economicBiasForGood:inEconomy:]` (426) | `OOCommodities::economicBiasForGood` `Core/OOCommodities.cpp:475` | ✅ |
| `-[OOCommodities firstModifierForGood:inClasses:fromList:]` (448) | `OOCommodities::firstModifierForGood` `Core/OOCommodities.cpp:497` | ✅ |
| `-[OOCommodities adjustPrice:byRule:]` (469) | `OOCommodities::adjustPrice` `Core/OOCommodities.cpp:518` | ✅ |
| `-[OOCommodities adjustQuantity:byRule:]` (489) | `OOCommodities::adjustQuantity` `Core/OOCommodities.cpp:538` | ✅ |
| `-[OOCommodities updateInfoFor:byRule:maxCapacity:]` (510) | `OOCommodities::updateInfoFor` `Core/OOCommodities.cpp:559` | ✅ |

**Differences:**

- ⚠️ **med** — goods are generated in `std::map` key order instead of `NSDictionary` hash order (bead oo-3rb.154, commented at each loop). Each good draws `randf()` twice for quantity and twice for price, so the seeded RNG stream is spread over the goods in a different order. The same system seed gives per-good prices and quantities different from upstream, and commodity scripts see `update*CommodityDefinition` calls in a different order — upstream `Core/OOCommodities.m:255` ↔ port `Core/OOCommodities.cpp:292`
- ⚠️ **med** — secondary-station markets are reordered the same way: the `randf()` pairs in `adjustPrice:`/`adjustQuantity:` run per good in key order (bead oo-3rb.154) — upstream `Core/OOCommodities.m:291` ↔ port `Core/OOCommodities.cpp:325`
- ⚠️ **low** — `goods` returns keys in key order (commented; was `-allKeys` hash order). `goodNamed:` returns the first match in key order, which only matters if two goods expand to the same name — upstream `Core/OOCommodities.m:338,348` ↔ port `Core/OOCommodities.cpp:373,388`
- ⚠️ **low** — `getRandomCommodity`: the same `Ranrot() % count` indexes key order instead of hash order, so it picks a different good (commented) — upstream `Core/OOCommodities.m:361` ↔ port `Core/OOCommodities.cpp:401`
- ⚠️ **low** — `massUnitForGood:` returns `UNITS_UNKNOWN` for a `quantity_unit` above 2; upstream returned the raw cast (ADR-0036, `Core/OOCommodities.h:44-49`) — upstream `Core/OOCommodities.m:374` ↔ port `Core/OOCommodities.cpp:416`
- ✅ subtle — the generate functions now draw the two `randf()` values in an explicit order (first minus second, matching clang's left-to-right). `adjustPrice:`/`adjustQuantity:` still use the unsequenced `(randf() - randf())` as upstream did, so their draw order depends on the compiler — port `Core/OOCommodities.cpp:426-428` vs `Core/OOCommodities.cpp:529,549`
- ✅ subtle — rounding is unchanged: float maths, a clamp below 0 to 0, then truncation through `(OOCargoQuantity)`/`(OOCreditsQuantity)`. `adjustPrice` floors the price at 1 decicredit (0 when `pm <= 0 && pa <= 0`). The station quantity scale stays integer `(q * localCapacity) / baseCapacity` — upstream `Core/OOCommodities.m:377-508` ↔ port `Core/OOCommodities.cpp:419-557`
- ✅ subtle — the upstream bug in `updateInfoFor:` (import legality written into `legality_export`) is reproduced deliberately (commented "sic") — upstream `Core/OOCommodities.m:520` ↔ port `Core/OOCommodities.cpp:569`


## OOCommodityMarket

<a id="oocommoditymarket"></a>
Upstream `src/Core/OOCommodityMarket.m` ↔ `Core/OOCommodityMarket.cpp`

**Status:** done — 29 rows: 25 ✅ 3 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCommodityMarket init]` (34) | implicit default constructor (`_commodityList`, `_sortedKeys` empty) `Core/OOCommodityMarket.h:88` | ✅ |
| `-[OOCommodityMarket dealloc]` (47) | implicit destructor | ➖ |
| `-[OOCommodityMarket count]` (54) | `OOCommodityMarket::count` `Core/OOCommodityMarket.cpp:55` | ✅ |
| `-[OOCommodityMarket setGood:withInfo:]` (59) | `OOCommodityMarket::setGood` `Core/OOCommodityMarket.cpp:60` | ✅ |
| `-[OOCommodityMarket goods]` (66) | `OOCommodityMarket::goods` → `sortedGoodKeys` `Core/OOCommodityMarket.cpp:67,338` | ⚠️ |
| `-[OOCommodityMarket dictionaryForScripting]` (75) | `OOCommodityMarket::dictionaryForScripting` `Core/OOCommodityMarket.cpp:72` | ✅ |
| `-[OOCommodityMarket setPrice:forGood:]` (80) | `OOCommodityMarket::setPrice` `Core/OOCommodityMarket.cpp:77` | ✅ |
| `-[OOCommodityMarket setQuantity:forGood:]` (90) | `OOCommodityMarket::setQuantity` `Core/OOCommodityMarket.cpp:87` | ✅ |
| `-[OOCommodityMarket addQuantity:forGood:]` (100) | `OOCommodityMarket::addQuantity` `Core/OOCommodityMarket.cpp:97` | ✅ |
| `-[OOCommodityMarket removeQuantity:forGood:]` (110) | `OOCommodityMarket::removeQuantity` `Core/OOCommodityMarket.cpp:107` | ✅ |
| `-[OOCommodityMarket removeAllGoods]` (120) | `OOCommodityMarket::removeAllGoods` `Core/OOCommodityMarket.cpp:117` | ✅ |
| `-[OOCommodityMarket setComment:forGood:]` (128) | `OOCommodityMarket::setComment` `Core/OOCommodityMarket.cpp:124` | ✅ |
| `-[OOCommodityMarket setShortComment:forGood:]` (138) | `OOCommodityMarket::setShortComment` `Core/OOCommodityMarket.cpp:134` | ✅ |
| `-[OOCommodityMarket nameForGood:]` (148) | `OOCommodityMarket::nameForGood` `Core/OOCommodityMarket.cpp:144` | ✅ |
| `-[OOCommodityMarket commentForGood:]` (157) | `OOCommodityMarket::commentForGood` `Core/OOCommodityMarket.cpp:153` | ✅ |
| `-[OOCommodityMarket shortCommentForGood:]` (166) | `OOCommodityMarket::shortCommentForGood` `Core/OOCommodityMarket.cpp:162` | ✅ |
| `-[OOCommodityMarket priceForGood:]` (175) | `OOCommodityMarket::priceForGood` `Core/OOCommodityMarket.cpp:171` | ✅ |
| `-[OOCommodityMarket quantityForGood:]` (184) | `OOCommodityMarket::quantityForGood` `Core/OOCommodityMarket.cpp:180` | ✅ |
| `-[OOCommodityMarket massUnitForGood:]` (193) | `OOCommodityMarket::massUnitForGood` `Core/OOCommodityMarket.cpp:189` | ⚠️ |
| `-[OOCommodityMarket exportLegalityForGood:]` (202) | `OOCommodityMarket::exportLegalityForGood` `Core/OOCommodityMarket.cpp:198` | ✅ |
| `-[OOCommodityMarket importLegalityForGood:]` (211) | `OOCommodityMarket::importLegalityForGood` `Core/OOCommodityMarket.cpp:207` | ✅ |
| `-[OOCommodityMarket capacityForGood:]` (220) | `OOCommodityMarket::capacityForGood` `Core/OOCommodityMarket.cpp:216` | ✅ |
| `-[OOCommodityMarket trumbleOpinionForGood:]` (231) | `OOCommodityMarket::trumbleOpinionForGood` `Core/OOCommodityMarket.cpp:227` | ✅ |
| `-[OOCommodityMarket definitionForGood:]` (240) | `OOCommodityMarket::definitionForGood` `Core/OOCommodityMarket.cpp:236` | ✅ |
| `-[OOCommodityMarket savePlayerAmounts]` (245) | `OOCommodityMarket::savePlayerAmounts` `Core/OOCommodityMarket.cpp:242` | ✅ |
| `-[OOCommodityMarket loadPlayerAmounts:]` (255) | `OOCommodityMarket::loadPlayerAmounts` `Core/OOCommodityMarket.cpp:251` | ✅ |
| `-[OOCommodityMarket saveStationAmounts]` (292) | `OOCommodityMarket::saveStationAmounts` `Core/OOCommodityMarket.cpp:286` | ✅ |
| `-[OOCommodityMarket loadStationAmounts:]` (302) | `OOCommodityMarket::loadStationAmounts` `Core/OOCommodityMarket.cpp:295` | ✅ |
| `goodsSorter()` (341) | lambda in `OOCommodityMarket::sortedGoodKeys` `Core/OOCommodityMarket.cpp:344` | ⚠️ |

**Differences:**

- ⚠️ **low** — goods with equal `sort_order` (or none, read as 0) are tie-broken by key bytes, via `std::stable_sort` over map order; upstream sorted the hash-ordered `-allKeys`. Commented at port :336-337. This changes the market-screen order and the element order of saved `[key, qty(, price)]` arrays for tied OXP goods — upstream `Core/OOCommodityMarket.m:66-73,341` ↔ port `Core/OOCommodityMarket.cpp:338-350`
- ⚠️ **low** — `massUnitForGood:` returns `UNITS_UNKNOWN` for a `quantity_unit` above 2; upstream returned the raw cast (ADR-0036) — upstream `Core/OOCommodityMarket.m:199` ↔ port `Core/OOCommodityMarket.cpp:195`
- ✅ subtle — `setGood:` given a non-dictionary info stores an empty dictionary, where upstream raised in `+dictionaryWithDictionary:`. Only the error path differs — upstream `Core/OOCommodityMarket.m:61` ↔ port `Core/OOCommodityMarket.cpp:63`
- ✅ subtle — in `loadPlayerAmounts:`/`loadStationAmounts:`, a nil good still logs as `(null)`. The log classes `setCommanderDataFromDictionary.warning.cargo` and `load.warning.cargo` and their text are unchanged — upstream `Core/OOCommodityMarket.m:287,334` ↔ port `Core/OOCommodityMarket.cpp:281,325`


## OOConstToString

<a id="ooconsttostring"></a>
Upstream `src/Core/OOConstToString.m` ↔ `Core/OOConstToString.cpp`

**Status:** done — 48 rows: 43 ✅ 0 ⚠️ 5 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOStringFromEntityStatus()` (50) | `cxx_OOStringFromEntityStatus` `Core/OOConstToString.cpp:51` | ✅ |
| `OOStringFromBehaviour()` (58) | `cxx_OOStringFromBehaviour` `Core/OOConstToString.cpp:59` | ✅ |
| `OOStringFromCompassMode()` (67) | `cxx_OOStringFromCompassMode` `Core/OOConstToString.cpp:68` | ✅ |
| `OOStringFromLongRangeChartMode()` (76) | `cxx_OOStringFromLongRangeChartMode` `Core/OOConstToString.cpp:77` | ✅ |
| `OOStringFromGalacticHyperspaceBehaviour()` (85) | `cxx_OOStringFromGalacticHyperspaceBehaviour` `Core/OOConstToString.cpp:86` | ✅ |
| `OOStringFromGUIScreenID()` (94) | `cxx_OOStringFromGUIScreenID` `Core/OOConstToString.cpp:95` | ✅ |
| `OOStringFromScanClass()` (103) | `cxx_OOStringFromScanClass` `Core/OOConstToString.cpp:104` | ✅ |
| `OOStringFromShipDamageType()` (112) | `cxx_OOStringFromShipDamageType` `Core/OOConstToString.cpp:113` | ✅ |
| `OOStringFromLegalStatusReason()` (121) | `cxx_OOStringFromLegalStatusReason` `Core/OOConstToString.cpp:122` | ✅ |
| `OOEntityStatusFromString()` (140) | `cxx_OOEntityStatusFromString` `Core/OOConstToString.cpp:141` | ✅ |
| `OOCompassModeFromString()` (147) | `cxx_OOCompassModeFromString` `Core/OOConstToString.cpp:148` | ✅ |
| `OOGalacticHyperspaceBehaviourFromString()` (154) | `cxx_OOGalacticHyperspaceBehaviourFromString` `Core/OOConstToString.cpp:155` | ✅ |
| `OOGUIScreenIDFromString()` (168) | `cxx_OOGUIScreenIDFromString` `Core/OOConstToString.cpp:167` | ✅ |
| `OOScanClassFromString()` (175) | `cxx_OOScanClassFromString` `Core/OOConstToString.cpp:174` | ✅ |
| `OOLongRangeChartModeFromString()` (182) | `cxx_OOLongRangeChartModeFromString` `Core/OOConstToString.cpp:181` | ✅ |
| `RouteTypeToString()` (192) | `cxx_RouteTypeToString` `Core/OOConstToString.cpp:191` | ✅ |
| `OODisplayStringFromGovernmentID()` (203) | `cxx_OODisplayStringFromGovernmentID` `Core/OOConstToString.cpp:214` | ❌ |
| `OODisplayStringFromEconomyID()` (218) | `cxx_OODisplayStringFromEconomyID` `Core/OOConstToString.cpp:227` | ❌ |
| `JSTypeToString()` (233) | `cxx_JSTypeToString` `Core/OOConstToString.cpp:239` | ✅ |
| `OOStringFromWeaponType()` (249) | `cxx_OOStringFromWeaponType` `Core/OOConstToString.cpp:265` | ✅ |
| `OOWeaponTypeFromString()` (258) | `cxx_OOWeaponTypeFromString` `Core/OOConstToString.cpp:274` | ✅ |
| `OOEquipmentIdentifierFromWeaponType()` (263) | `cxx_OOEquipmentIdentifierFromWeaponType` `Core/OOConstToString.cpp:279` | ✅ |
| `OOWeaponTypeFromEquipmentIdentifierSloppy()` (268) | `cxx_OOWeaponTypeFromEquipmentIdentifierSloppy` `Core/OOConstToString.cpp:286` | ✅ |
| `OOWeaponTypeFromEquipmentIdentifierLegacy()` (285) | `cxx_OOWeaponTypeFromEquipmentIdentifierLegacy` `Core/OOConstToString.cpp:304` | ✅ |
| `OOWeaponTypeFromEquipmentIdentifierStrict()` (306) | `cxx_OOWeaponTypeFromEquipmentIdentifierStrict` `Core/OOConstToString.cpp:325` | ✅ |
| `CargoTypeToString()` (312) | `cxx_CargoTypeToString` `Core/OOConstToString.cpp:331` | ✅ |
| `StringToCargoType()` (327) | `cxx_StringToCargoType` `Core/OOConstToString.cpp:346` | ✅ |
| `EnergyUnitTypeToString()` (345) | `cxx_EnergyUnitTypeToString` `Core/OOConstToString.cpp:364` | ✅ |
| `StringToEnergyUnitType()` (362) | `cxx_StringToEnergyUnitType` `Core/OOConstToString.cpp:381` | ✅ |
| `OODisplayRatingStringFromKillCount()` (373) | `cxx_OODisplayRatingStringFromKillCount` `Core/OOConstToString.cpp:392` (+ `DescriptionStringAt` :205) | ❌ |
| `KillCountToRatingAndKillString()` (399) | `cxx_KillCountToRatingAndKillString` `Core/OOConstToString.cpp:418` | ✅ |
| `OODisplayStringFromLegalStatus()` (404) | `cxx_OODisplayStringFromLegalStatus` `Core/OOConstToString.cpp:425` | ❌ |
| `OODisplayStringFromAlertCondition()` (424) | `cxx_OODisplayStringFromAlertCondition` `Core/OOConstToString.cpp:445` | ❌ |
| `OODisplayStringFromShaderSetting()` (430) | `cxx_OODisplayStringFromShaderSetting` `Core/OOConstToString.cpp:452` | ✅ |
| `OOStringFromShaderSetting()` (446) | `cxx_OOStringFromShaderSetting` `Core/OOConstToString.cpp:469` | ✅ |
| `OOShaderSettingFromString()` (458) | `cxx_OOShaderSettingFromString` `Core/OOConstToString.cpp:481` | ✅ |
| `CommodityDisplayNameForSymbolicName()` (468) | `cxx_CommodityDisplayNameForSymbolicName` `Core/OOConstToString.cpp:491` | ✅ |
| `CommodityDisplayNameForCommodityArray()` (474) | `cxx_CommodityDisplayNameForCommodityArray` `Core/OOConstToString.cpp:498` | ✅ |
| `DisplayStringForMassUnit()` (479) | `cxx_DisplayStringForMassUnit` `Core/OOConstToString.cpp:503` | ✅ |
| `DisplayStringForMassUnitForCommodity()` (493) | `cxx_DisplayStringForMassUnitForCommodity` `Core/OOConstToString.cpp:520` | ✅ |
| `StringToRouteType()` (498) | `cxx_StringToRouteType` `Core/OOConstToString.cpp:527` | ✅ |
| `DockingClearanceStatusToString()` (507) | `cxx_DockingClearanceStatusToString` `Core/OOConstToString.cpp:536` | ✅ |
| `OOStringFromGraphicsDetail()` (520) | `cxx_OOStringFromGraphicsDetail` `Core/OOConstToString.cpp:549` | ✅ |
| `OOGraphicsDetailFromString()` (532) | `cxx_OOGraphicsDetailFromString` `Core/OOConstToString.cpp:561` | ✅ |
| `OOStringFromHDRToneMapper()` (542) | `cxx_OOStringFromHDRToneMapper` `Core/OOConstToString.cpp:571` | ✅ |
| `OOHDRToneMapperFromString()` (555) | `cxx_OOHDRToneMapperFromString` `Core/OOConstToString.cpp:584` | ✅ |
| `OOStringFromSDRToneMapper()` (566) | `cxx_OOStringFromSDRToneMapper` `Core/OOConstToString.cpp:595` | ✅ |
| `OOSDRToneMapperFromString()` (581) | `cxx_OOSDRToneMapperFromString` `Core/OOConstToString.cpp:610` | ✅ |

**Differences:**

- ❌ **low** — the government, economy, rating, legal-status and alert-condition display lookups dereference `UNIVERSE->descriptions()` with no null check. Upstream `[[UNIVERSE descriptions] …]` was nil-safe and returned nil before the Universe existed. The neighbouring `CommodityDisplayNameForSymbolicName` and `DisplayStringForMassUnitForCommodity` ports do guard `UNIVERSE`. The difference is only reachable if these are called before Universe init — upstream `Core/OOConstToString.m:208,223,390,415,426` ↔ port `Core/OOConstToString.cpp:217,229,408,435,447`
- ✅ checked — all nine `.tbl` tables (`Core/Tables/*.tbl`) are identical to upstream apart from whitespace and comments, so the forward/reverse names and the `kOO*Default` fallbacks are unchanged — `Core/Tables/`
- ✅ subtle — `JSTypeToString` switches on `ooscript::Type` (enum Void…XML in JSType order, `Core/Scripting/ooscript/JSEngine.hpp:120`). `JSTYPE_LIMIT` is matched as `XML + 1`, so names and the `unknown (%u)` fallback match — upstream `Core/OOConstToString.m:233-247` ↔ port `Core/OOConstToString.cpp:239-263`
- ✅ subtle — the rating, legal-status and condition lookups keep `oo_stringAtIndex:` semantics: a string, or a number's `-stringValue`, else nil. `KillCountToRatingAndKillString` prints `(null)` for a nil rating, as `%@` did — upstream `Core/OOConstToString.m:393,401` ↔ port `Core/OOConstToString.cpp:205-211,422`
- ✅ subtle — `DisplayStringForMassUnit` gains an explicit `UNITS_UNKNOWN` case that falls through to `"??"`, which is the same output as upstream's default for an out-of-range unit. With no market, the port uses `UNITS_TONS`, which is what nil-messaging returned — upstream `Core/OOConstToString.m:479-496` ↔ port `Core/OOConstToString.cpp:503-525`


## OOConvertSystemDescriptions

<a id="ooconvertsystemdescriptions"></a>
Upstream `src/Core/OOConvertSystemDescriptions.m` ↔ `Core/OOConvertSystemDescriptions.cpp`

**Status:** done — 11 rows: 8 ✅ 3 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `CompileSystemDescriptions()` (45) | `CompileSystemDescriptions` `Core/OOConvertSystemDescriptions.cpp:177` | ✅ |
| `ExportSystemDescriptions()` (94) | `ExportSystemDescriptions` `Core/OOConvertSystemDescriptions.cpp:206` | ✅ |
| `OOConvertSystemDescriptionsToArrayFormat()` (135) | `OOConvertSystemDescriptionsToArrayFormat` `Core/OOConvertSystemDescriptions.cpp:234` | ⚠️ |
| `OOConvertSystemDescriptionsToDictionaryFormat()` (177) | `OOConvertSystemDescriptionsToDictionaryFormat` `Core/OOConvertSystemDescriptions.cpp:264` | ✅ |
| `OOStringifySystemDescriptionLine()` (200) | `OOStringifySystemDescriptionLine` `Core/OOConvertSystemDescriptions.cpp:276` (+ `NextBrackets` :98) | ⚠️ |
| `InitKeyToIndexDict()` (232) | `InitKeyToIndexDict` `Core/OOConvertSystemDescriptions.cpp:51` | ✅ |
| `IndexToKey()` (256) | `IndexToKey` `Core/OOConvertSystemDescriptions.cpp:64` | ✅ |
| `ConvertIndicesToKeys()` (265) | `ConvertIndicesToKeys` `Core/OOConvertSystemDescriptions.cpp:143` | ✅ |
| `KeyToIndex()` (279) | `KeyToIndex` `Core/OOConvertSystemDescriptions.cpp:75` | ✅ |
| `ConvertKeysToIndices()` (300) | `ConvertKeysToIndices` `Core/OOConvertSystemDescriptions.cpp:111` (+ `NextBrackets` :98) | ⚠️ |
| `HighestIndex()` (337) | `HighestIndex` `Core/OOConvertSystemDescriptions.cpp:156` | ✅ |

**Differences:**

- ⚠️ **low** — dictionaries are visited in byte-sorted key order instead of `NSDictionary` hash order. This changes which free slot an unknown key is assigned and the order of the `sysdesc.compile.unknownKey` "Assigning key" log lines. Declared in the file-header comment (proposed ADR-0043, bead oo-xh1g) — upstream `Core/OOConvertSystemDescriptions.m:155,244` ↔ port `Core/OOConvertSystemDescriptions.cpp:39-45,246`
- ⚠️ **low** — on a malformed line (`[` with no `]` after it, or `]` before `[`), upstream raised NSRangeException from `substringWithRange:`. The port stops scanning and keeps the line unchanged, as declared in the header comment — upstream `Core/OOConvertSystemDescriptions.m:210-216,314-320` ↔ port `Core/OOConvertSystemDescriptions.cpp:98-109`
- ✅ subtle — `HighestIndex` still returns the highest index rather than highest+1, so the last entry is dropped from the compiled array. This upstream bug is preserved and commented — upstream `Core/OOConvertSystemDescriptions.m:337-350` ↔ port `Core/OOConvertSystemDescriptions.cpp:154-167`
- ✅ subtle — the `sysdesc.compile.failed.conversion` branch is gone. It was unreachable upstream, since the converter never returns nil — upstream `Core/OOConvertSystemDescriptions.m:67-70` ↔ port `Core/OOConvertSystemDescriptions.cpp:188`
- ✅ subtle — `InitKeyToIndexDict` maps only string values of the key table (upstream accepted any object). The index is still marked used, so lookups by string name are unchanged — upstream `Core/OOConvertSystemDescriptions.m:248` ↔ port `Core/OOConvertSystemDescriptions.cpp:57-59`


## OOEntityFilterPredicate

<a id="ooentityfilterpredicate"></a>
Upstream `src/Core/OOEntityFilterPredicate.m` ↔ `Core/OOEntityFilterPredicate.cpp`

**Status:** done — 20 rows: 19 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `YESPredicate()` (34) | `YESPredicate` `Core/OOEntityFilterPredicate.cpp:34` | ✅ |
| `NOPredicate()` (39) | `NOPredicate` `Core/OOEntityFilterPredicate.cpp:39` | ✅ |
| `NOTPredicate()` (44) | `NOTPredicate` `Core/OOEntityFilterPredicate.cpp:44` | ✅ |
| `ANDPredicate()` (53) | `ANDPredicate` `Core/OOEntityFilterPredicate.cpp:53` | ✅ |
| `ORPredicate()` (64) | `ORPredicate` `Core/OOEntityFilterPredicate.cpp:64` | ✅ |
| `NORPredicate()` (75) | `NORPredicate` `Core/OOEntityFilterPredicate.cpp:75` | ✅ |
| `XORPredicate()` (86) | `XORPredicate` `Core/OOEntityFilterPredicate.cpp:86` | ✅ |
| `NANDPredicate()` (97) | `NANDPredicate` `Core/OOEntityFilterPredicate.cpp:97` | ✅ |
| `HasScanClassPredicate()` (108) | `HasScanClassPredicate` `Core/OOEntityFilterPredicate.cpp:111` (param is now `OOScanClass*`, not NSNumber) | ✅ |
| `HasClassPredicate()` (113) | — (only caller `OOEnvironmentCubeMap.m:104` was not ported) | ➖ |
| `IsShipPredicate()` (118) | `IsShipPredicate` `Core/OOEntityFilterPredicate.cpp:116` | ✅ |
| `IsStationPredicate()` (123) | `IsStationPredicate` `Core/OOEntityFilterPredicate.cpp:121` | ✅ |
| `IsPlanetPredicate()` (128) | `IsPlanetPredicate` `Core/OOEntityFilterPredicate.cpp:126` | ✅ |
| `IsSunPredicate()` (136) | `IsSunPredicate` `Core/OOEntityFilterPredicate.cpp:134` | ✅ |
| `IsVisualEffectPredicate()` (141) | `IsVisualEffectPredicate` `Core/OOEntityFilterPredicate.cpp:139` | ✅ |
| `HasRolePredicate()` (146) | `HasRolePredicate` `Core/OOEntityFilterPredicate.cpp:144` | ✅ |
| `HasPrimaryRolePredicate()` (151) | `HasPrimaryRolePredicate` `Core/OOEntityFilterPredicate.cpp:150` | ✅ |
| `HasRoleInSetPredicate()` (156) | `HasRoleInSetPredicate` `Core/OOEntityFilterPredicate.cpp:161` | ✅ |
| `HasPrimaryRoleInSetPredicate()` (161) | `HasPrimaryRoleInSetPredicate` `Core/OOEntityFilterPredicate.cpp:171` | ✅ |
| `IsHostileAgainstTargetPredicate()` (166) | `IsHostileAgainstTargetPredicate` `Core/OOEntityFilterPredicate.cpp:182` | ✅ |

**Differences:**

- ➖ **low** — `HasClassPredicate` is removed. Its only upstream user, the sky lookup at `OOEnvironmentCubeMap.m:104`, has no port counterpart — upstream `Core/OOEntityFilterPredicate.m:113` ↔ port (none)
- ✅ subtle — `HasRoleInSetPredicate` dereferences `oo::ToShip(ship)` without a null check. Upstream sent `-roleSet` to the entity, which raises for a non-ship, so both fail on non-ships. The role set is now a `std::vector<std::string>` checked with `hasRole`, equivalent to `-intersectsSet:` on `roles` — upstream `Core/OOEntityFilterPredicate.m:158` ↔ port `Core/OOEntityFilterPredicate.cpp:164-168`
- ✅ subtle — `HasPrimaryRolePredicate` with a null role still calls `getPrimaryRole()` for its side effect, then returns NO, matching `[nil isEqual:]` — upstream `Core/OOEntityFilterPredicate.m:153` ↔ port `Core/OOEntityFilterPredicate.cpp:153-157`


## OOEquipmentType

<a id="ooequipmenttype"></a>
Upstream `src/Core/OOEquipmentType.m` ↔ `Core/OOEquipmentType.cpp`

**Status:** done — 72 rows: 59 ✅ 1 ⚠️ 6 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOEquipmentType loadEquipment]` (50) | `OOEquipmentType::loadEquipment` `Core/OOEquipmentType.cpp:104` | ✅ |
| `+[OOEquipmentType addEquipmentWithInfo:]` (104) | `OOEquipmentType::addEquipmentWithInfo` `Core/OOEquipmentType.cpp:143` | ✅ |
| `+[OOEquipmentType getMissileRegistryRoleForShip:]` (127) | `OOEquipmentType::getMissileRegistryRoleForShip` `Core/OOEquipmentType.cpp:153` | ✅ |
| `+[OOEquipmentType setMissileRegistryRole:forShip:]` (132) | `OOEquipmentType::setMissileRegistryRole` `Core/OOEquipmentType.cpp:161` | ✅ |
| `+[OOEquipmentType allEquipmentTypes]` (143) | `OOEquipmentType::allEquipmentTypes` `Core/OOEquipmentType.cpp:169` | ✅ |
| `+[OOEquipmentType equipmentEnumerator]` (148) | replaced by `allEquipmentTypes` `Core/OOEquipmentType.cpp:169` | ➖ |
| `+[OOEquipmentType reverseEquipmentEnumerator]` (153) | replaced: caller iterates `allEquipmentTypes()` with `rbegin` `Core/Entities/PlayerEntity.cpp:7635` | ➖ |
| `+[OOEquipmentType equipmentEnumeratorOutfitting]` (158) | replaced by `allEquipmentTypesOutfitting` `Core/OOEquipmentType.cpp:174` | ➖ |
| `+[OOEquipmentType equipmentTypeWithIdentifier:]` (163) | `OOEquipmentType::equipmentTypeWithIdentifier` `Core/OOEquipmentType.cpp:179` | ✅ |
| `-[OOEquipmentType initWithInfo:]` (168) | `OOEquipmentType::createWithInfo` / `initWithInfo` `Core/OOEquipmentType.cpp:186`, `:194` | ⚠️ |
| `-[OOEquipmentType dealloc]` (370) | members are RAII (`oo::Ref`, `std::optional`, `oo::PList`) | ➖ |
| `-[OOEquipmentType copyWithZone:]` (391) | immutable; shared via `oo::Ref<OOEquipmentType>` | ➖ |
| `-[OOEquipmentType descriptionComponents]` (397) | `OOEquipmentType::descriptionComponents` `Core/OOEquipmentType.cpp:359` | ✅ |
| `-[OOEquipmentType identifier]` (402) | `OOEquipmentType::identifier` `Core/OOEquipmentType.cpp:378` | ✅ |
| `-[OOEquipmentType damagedIdentifier]` (407) | `OOEquipmentType::damagedIdentifier` `Core/OOEquipmentType.cpp:383` | ✅ |
| `-[OOEquipmentType name]` (412) | `OOEquipmentType::name` `Core/OOEquipmentType.cpp:388` | ✅ |
| `-[OOEquipmentType descriptiveText]` (417) | `OOEquipmentType::descriptiveText` `Core/OOEquipmentType.cpp:393` | ✅ |
| `-[OOEquipmentType techLevel]` (422) | `OOEquipmentType::techLevel` `Core/OOEquipmentType.cpp:398` | ✅ |
| `-[OOEquipmentType price]` (427) | `OOEquipmentType::price` `Core/OOEquipmentType.cpp:403` | ✅ |
| `-[OOEquipmentType isAvailableToAll]` (432) | `OOEquipmentType::isAvailableToAll` `Core/OOEquipmentType.cpp:408` | ✅ |
| `-[OOEquipmentType requiresEmptyPylon]` (437) | `OOEquipmentType::requiresEmptyPylon` `Core/OOEquipmentType.cpp:413` | ✅ |
| `-[OOEquipmentType requiresMountedPylon]` (442) | `OOEquipmentType::requiresMountedPylon` `Core/OOEquipmentType.cpp:418` | ✅ |
| `-[OOEquipmentType requiresCleanLegalRecord]` (447) | `OOEquipmentType::requiresCleanLegalRecord` `Core/OOEquipmentType.cpp:423` | ✅ |
| `-[OOEquipmentType requiresNonCleanLegalRecord]` (452) | `OOEquipmentType::requiresNonCleanLegalRecord` `Core/OOEquipmentType.cpp:428` | ✅ |
| `-[OOEquipmentType requiresFreePassengerBerth]` (457) | `OOEquipmentType::requiresFreePassengerBerth` `Core/OOEquipmentType.cpp:433` | ✅ |
| `-[OOEquipmentType requiresFullFuel]` (462) | `OOEquipmentType::requiresFullFuel` `Core/OOEquipmentType.cpp:438` | ✅ |
| `-[OOEquipmentType requiresNonFullFuel]` (467) | `OOEquipmentType::requiresNonFullFuel` `Core/OOEquipmentType.cpp:443` | ✅ |
| `-[OOEquipmentType isPrimaryWeapon]` (472) | `OOEquipmentType::isPrimaryWeapon` `Core/OOEquipmentType.cpp:448` | ✅ |
| `-[OOEquipmentType isMissileOrMine]` (477) | `OOEquipmentType::isMissileOrMine` `Core/OOEquipmentType.cpp:453` | ✅ |
| `-[OOEquipmentType isPortableBetweenShips]` (482) | `OOEquipmentType::isPortableBetweenShips` `Core/OOEquipmentType.cpp:458` | ✅ |
| `-[OOEquipmentType canCarryMultiple]` (487) | `OOEquipmentType::canCarryMultiple` `Core/OOEquipmentType.cpp:463` | ✅ |
| `-[OOEquipmentType damageProbability]` (504) | `OOEquipmentType::damageProbability` `Core/OOEquipmentType.cpp:479` | ✅ |
| `-[OOEquipmentType canBeDamaged]` (512) | `OOEquipmentType::canBeDamaged` `Core/OOEquipmentType.cpp:487` | ✅ |
| `-[OOEquipmentType isVisible]` (524) | `OOEquipmentType::isVisible` `Core/OOEquipmentType.cpp:499` | ✅ |
| `-[OOEquipmentType hideValues]` (529) | `OOEquipmentType::hideValues` `Core/OOEquipmentType.cpp:504` | ✅ |
| `-[OOEquipmentType isAvailableToPlayer]` (534) | `OOEquipmentType::isAvailableToPlayer` `Core/OOEquipmentType.cpp:509` | ✅ |
| `-[OOEquipmentType isAvailableToNPCs]` (539) | `OOEquipmentType::isAvailableToNPCs` `Core/OOEquipmentType.cpp:514` | ✅ |
| `-[OOEquipmentType requiredCargoSpace]` (544) | `OOEquipmentType::requiredCargoSpace` `Core/OOEquipmentType.cpp:519` | ✅ |
| `-[OOEquipmentType requiresEquipment]` (549) | `OOEquipmentType::requiresEquipment` `Core/OOEquipmentType.cpp:524` | ✅ |
| `-[OOEquipmentType requiresAnyEquipment]` (554) | `OOEquipmentType::requiresAnyEquipment` `Core/OOEquipmentType.cpp:529` | ✅ |
| `-[OOEquipmentType incompatibleEquipment]` (559) | `OOEquipmentType::incompatibleEquipment` `Core/OOEquipmentType.cpp:534` | ✅ |
| `-[OOEquipmentType displayColor]` (564) | `OOEquipmentType::displayColor` `Core/OOEquipmentType.cpp:539` | ✅ |
| `-[OOEquipmentType setDisplayColor:]` (569) | `OOEquipmentType::setDisplayColor` `Core/OOEquipmentType.cpp:544` | ✅ |
| `-[OOEquipmentType conditions]` (575) | `OOEquipmentType::conditions` `Core/OOEquipmentType.cpp:549` | ✅ |
| `-[OOEquipmentType conditionScript]` (580) | `OOEquipmentType::conditionScript` `Core/OOEquipmentType.cpp:554` | ✅ |
| `-[OOEquipmentType scriptInfo]` (585) | `OOEquipmentType::scriptInfo` `Core/OOEquipmentType.cpp:559` | ✅ |
| `-[OOEquipmentType scriptName]` (590) | `OOEquipmentType::scriptName` `Core/OOEquipmentType.cpp:564` | ✅ |
| `-[OOEquipmentType fastAffinityDefensive]` (595) | `OOEquipmentType::fastAffinityDefensive` `Core/OOEquipmentType.cpp:569` | ✅ |
| `-[OOEquipmentType fastAffinityOffensive]` (600) | `OOEquipmentType::fastAffinityOffensive` `Core/OOEquipmentType.cpp:574` | ✅ |
| `-[OOEquipmentType defaultActivateKey]` (605) | `OOEquipmentType::defaultActivateKey` `Core/OOEquipmentType.cpp:579` | ✅ |
| `-[OOEquipmentType defaultModeKey]` (610) | `OOEquipmentType::defaultModeKey` `Core/OOEquipmentType.cpp:584` | ✅ |
| `-[OOEquipmentType installTime]` (615) | `OOEquipmentType::installTime` `Core/OOEquipmentType.cpp:589` | ✅ |
| `-[OOEquipmentType repairTime]` (620) | `OOEquipmentType::repairTime` `Core/OOEquipmentType.cpp:594` | ✅ |
| `-[OOEquipmentType providesForScripting]` (629) | `OOEquipmentType::providesForScripting` `Core/OOEquipmentType.cpp:603` | ❌ |
| `-[OOEquipmentType provides:]` (634) | `OOEquipmentType::provides` `Core/OOEquipmentType.cpp:608` | ✅ |
| `-[OOEquipmentType isTurretLaser]` (640) | `OOEquipmentType::isTurretLaser` `Core/OOEquipmentType.cpp:614` | ✅ |
| `-[OOEquipmentType isMiningLaser]` (645) | `OOEquipmentType::isMiningLaser` `Core/OOEquipmentType.cpp:619` | ✅ |
| `-[OOEquipmentType weaponInfo]` (650) | `OOEquipmentType::weaponInfo` `Core/OOEquipmentType.cpp:624` | ✅ |
| `-[OOEquipmentType weaponRange]` (655) | `OOEquipmentType::weaponRange` `Core/OOEquipmentType.cpp:629` | ✅ |
| `-[OOEquipmentType weaponEnergyUse]` (660) | `OOEquipmentType::weaponEnergyUse` `Core/OOEquipmentType.cpp:634` | ✅ |
| `-[OOEquipmentType weaponDamage]` (665) | `OOEquipmentType::weaponDamage` `Core/OOEquipmentType.cpp:639` | ✅ |
| `-[OOEquipmentType weaponRechargeRate]` (670) | `OOEquipmentType::weaponRechargeRate` `Core/OOEquipmentType.cpp:644` | ✅ |
| `-[OOEquipmentType weaponShotTemperature]` (675) | `OOEquipmentType::weaponShotTemperature` `Core/OOEquipmentType.cpp:649` | ✅ |
| `-[OOEquipmentType weaponThreatAssessment]` (680) | `OOEquipmentType::weaponThreatAssessment` `Core/OOEquipmentType.cpp:654` | ✅ |
| `-[OOEquipmentType weaponColor]` (685) | `OOEquipmentType::weaponColor` `Core/OOEquipmentType.cpp:659` | ✅ |
| `-[OOEquipmentType fxShotMissName]` (690) | `OOEquipmentType::fxShotMissName` `Core/OOEquipmentType.cpp:665` | ❌ |
| `-[OOEquipmentType fxShotHitName]` (695) | `OOEquipmentType::fxShotHitName` `Core/OOEquipmentType.cpp:670` | ❌ |
| `-[OOEquipmentType fxShieldHitName]` (700) | `OOEquipmentType::fxShieldHitName` `Core/OOEquipmentType.cpp:675` | ❌ |
| `-[OOEquipmentType fxUnshieldedHitName]` (705) | `OOEquipmentType::fxUnshieldedHitName` `Core/OOEquipmentType.cpp:680` | ❌ |
| `-[OOEquipmentType fxWeaponLaunchedName]` (710) | `OOEquipmentType::fxWeaponLaunchedName` `Core/OOEquipmentType.cpp:685` | ❌ |
| `-[OOEquipmentType suppressClangStuff]` (720) | not needed (analyzer workaround; `_jsSelf` kept in `Core/OOEquipmentType.h:205`) | ➖ |
| `-[OOEquipmentType(Conveniences) effectiveTechLevel]` (731) | `OOEquipmentType::effectiveTechLevel` `Core/OOEquipmentType.cpp:690` | ✅ |

**Differences:**

- ❌ **low** — the `fx*Name` getters lose nil-messaging when an entry has no extra-info dictionary. Upstream `_weaponInfo` stays nil, so `oo_stringForKey:defaultValue:` sent to nil returns nil. The port's `_weaponInfo` is a null PList, and `StringFor` returns its fallback when `find` fails (`Core/OOEquipmentType.cpp:55-59`). The port therefore yields `[player-laser-miss]`, `[missile-launched]` and so on where upstream gave nil — upstream `Core/OOEquipmentType.m:214,245,690-713` ↔ port `Core/OOEquipmentType.cpp:274,665-688`
- ❌ **low** — `providesForScripting` with no extra dict returns nil upstream (JS `provides` is null); the port always returns a vector, so JS sees `[]`. Non-string `provides` elements, which upstream passed through, are now dropped at load — upstream `Core/OOEquipmentType.m:240,629-632` ↔ port `Core/OOEquipmentType.cpp:263-268,603`
- ⚠️ **low** — `requires_equipment`, `requires_any_equipment` and `incompatible_with_equipment` changed from `NSSet` to a sorted, de-duplicated `std::vector<std::string>` (commented: "sorted, de-duplicated: was a set"). Non-string elements are dropped, and JS-visible order is lexical rather than hash order; containment checks are unaffected — upstream `Core/OOEquipmentType.m:249-274` ↔ port `Core/OOEquipmentType.cpp:51-101,278-280`
- ✅ checked — the `weapon*` numeric getters keep nil semantics. `_weaponInfo` defaults to a null PList (`Core/OOEquipmentType.h:202`), and `get<float>` on a null PList returns 0 rather than the fallback (`oofnd/PListGet.hpp:33-34`), as `[nil oo_floatForKey:…]` did — upstream `Core/OOEquipmentType.m:655-683` ↔ port `Core/OOEquipmentType.cpp:629-657`
- ✅ subtle — `loadEquipment`: upstream's outfitting loop wrote into an `equipmentTypesByIdentifier` already copied into `sEquipmentTypesByIdentifier`, so that write was a no-op, and the port drops it. Condition scripts keep first-seen order, and the last entry wins for duplicate identifiers — upstream `Core/OOEquipmentType.m:94-100` ↔ port `Core/OOEquipmentType.cpp:134-140`
- ✅ subtle — the `default_activate_key`/`default_mode_key` log texts are unchanged, including the trailing "." on the mode message only — upstream `Core/OOEquipmentType.m:336,355` ↔ port `Core/OOEquipmentType.cpp:344,346`


## OOOXZManager

<a id="oooxzmanager"></a>
Upstream `src/Core/OOOXZManager.m` ↔ `Core/OOOXZManager.cpp`

**Status:** done — 72 rows: 61 ✅ 5 ⚠️ 3 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| URL / filename constants `kOOOXZDataURL`… (51) | anon-namespace `const char*` constants `Core/OOOXZManager.cpp:84` | ✅ |
| filter constants `kOOOXZFilterAll`… (66) | `constexpr std::string_view` `Core/OOOXZManager.cpp:99` | ✅ |
| `OXZInstallableState` enum (75) | `OXZInstallableState` `Core/OOOXZManager.h:81` | ✅ |
| `OXZ_GUI_ROW_*` enum (88) | same enum `Core/OOOXZManager.cpp:111` | ✅ |
| `+[OOOXZManager sharedManager]` (176) | `OOOXZManager::sharedManager` `Core/OOOXZManager.cpp:308` | ✅ |
| `-[OOOXZManager init]` (184) | `OOOXZManager::init` `Core/OOOXZManager.cpp:319` | ✅ |
| `-[OOOXZManager dealloc]` (204) | `OOOXZManager::~OOOXZManager` `Core/OOOXZManager.cpp:336` | ✅ |
| `-[OOOXZManager installPath]` (220) | `OOOXZManager::installPath` → `oo::ResourcePaths::managedAddOnsDirectory` `Core/OOOXZManager.cpp:347` | ➖ |
| `-[OOOXZManager extractAddOnsPath]` (246) | `OOOXZManager::extractAddOnsPath` → `oo::ResourcePaths::extractAddOnsDirectory` `Core/OOOXZManager.cpp:356` | ➖ |
| `-[OOOXZManager additionalAddOnsPaths]` (266) | `OOOXZManager::additionalAddOnsPaths` → `oo::ResourcePaths::additionalAddOnsDirectories` `Core/OOOXZManager.cpp:364` | ➖ |
| `-[OOOXZManager extractionBasePathForIdentifier:andVersion:]` (277) | `OOOXZManager::extractionBasePathForIdentifier` `Core/OOOXZManager.cpp:373` | ✅ |
| `-[OOOXZManager ensureInstallPath]` (286) | `OOOXZManager::ensureInstallPath` `Core/OOOXZManager.cpp:386` | ✅ |
| `-[OOOXZManager manifestPath]` (308) | `OOOXZManager::manifestPath` `Core/OOOXZManager.cpp:406` | ✅ |
| `-[OOOXZManager downloadPath]` (316) | `OOOXZManager::downloadPath` `Core/OOOXZManager.cpp:417` | ✅ |
| `-[OOOXZManager dataURL]` (325) | `OOOXZManager::dataURL` `Core/OOOXZManager.cpp:429` | ✅ |
| `-[OOOXZManager humanSize:]` (335) | `OOOXZManager::humanSize` `Core/OOOXZManager.cpp:439` | ✅ |
| `-[OOOXZManager setOXZList:]` (348) | `OOOXZManager::setOXZList` `Core/OOOXZManager.cpp:453` | ✅ |
| `-[OOOXZManager setFilteredList:]` (358) | `OOOXZManager::setFilteredList` `Core/OOOXZManager.cpp:466` | ✅ |
| `-[OOOXZManager setFilter:]` (364) | `OOOXZManager::setFilter` `Core/OOOXZManager.cpp:471` | ✅ |
| `-[OOOXZManager setOXPURL:]` (370) | `OOOXZManager::setOXPURL` `Core/OOOXZManager.cpp:476` | ✅ |
| `-[OOOXZManager applyCurrentFilter:]` (376) | `OOOXZManager::applyCurrentFilter` (member-function pointers replace NSInvocation) `Core/OOOXZManager.cpp:481` | ✅ |
| `-[OOOXZManager applyFilterByNoFilter:]` (425) | `applyFilterByNoFilter` `Core/OOOXZManager.cpp:532` | ✅ |
| `-[OOOXZManager applyFilterByUpdateRequired:]` (430) | `applyFilterByUpdateRequired` `Core/OOOXZManager.cpp:537` | ✅ |
| `-[OOOXZManager applyFilterByInstallable:]` (435) | `applyFilterByInstallable` `Core/OOOXZManager.cpp:542` | ✅ |
| `-[OOOXZManager applyFilterByKeyword:keyword:]` (440) | `applyFilterByKeyword` + `FoundIgnoringCase`/`TagFoundIgnoringCase` `Core/OOOXZManager.cpp:547` | ✅ |
| `-[OOOXZManager applyFilterByAuthor:author:]` (464) | `applyFilterByAuthor` `Core/OOOXZManager.cpp:562` | ✅ |
| `-[OOOXZManager applyFilterByDays:days:]` (473) | `applyFilterByDays` `Core/OOOXZManager.cpp:570` | ✅ |
| `-[OOOXZManager applyFilterByTag:tag:]` (485) | `applyFilterByTag` `Core/OOOXZManager.cpp:582` | ✅ |
| `-[OOOXZManager applyFilterByCategory:category:]` (502) | `applyFilterByCategory` `Core/OOOXZManager.cpp:588` | ✅ |
| `-[OOOXZManager validateFilter:]` (513) | `OOOXZManager::validateFilter` `Core/OOOXZManager.cpp:598` | ✅ |
| `-[OOOXZManager setCurrentDownload:withLabel:]` (531) | `OOOXZManager::setCurrentDownload` `Core/OOOXZManager.cpp:617` | ✅ |
| `-[OOOXZManager setProgressStatus:]` (541) | `OOOXZManager::setProgressStatus` `Core/OOOXZManager.cpp:625` | ✅ |
| `-[OOOXZManager updateManifests]` (547) | `OOOXZManager::updateManifests` `Core/OOOXZManager.cpp:630` | ✅ |
| `-[OOOXZManager beginDownload:]` (560) | `OOOXZManager::beginDownload` `Core/OOOXZManager.cpp:643` | ❌ |
| (NSURLConnection run-loop delegate delivery) | `OOOXZManager::processDownloadEvents` `Core/OOOXZManager.cpp:665`, polled from `Core/GameController.cpp:506` | ⚠️ |
| `-[OOOXZManager cancelUpdate]` (588) | `OOOXZManager::cancelUpdate` `Core/OOOXZManager.cpp:693` | ✅ |
| `-[OOOXZManager manifests]` (610) | `OOOXZManager::manifests` `Core/OOOXZManager.cpp:716` | ✅ |
| `-[OOOXZManager managedOXZs]` (615) | `OOOXZManager::managedOXZs` `Core/OOOXZManager.cpp:721` | ⚠️ |
| `-[OOOXZManager processDownloadedManifests]` (660) | `OOOXZManager::processDownloadedManifests` `Core/OOOXZManager.cpp:776` | ✅ |
| `-[OOOXZManager processDownloadedOXZ]` (686) | `OOOXZManager::processDownloadedOXZ` `Core/OOOXZManager.cpp:807` | ⚠️ |
| `-[OOOXZManager installedManifestForIdentifier:]` (885) | `OOOXZManager::installedManifestForIdentifier` `Core/OOOXZManager.cpp:999` | ✅ |
| `-[OOOXZManager installableState:]` (897) | `OOOXZManager::installableState` `Core/OOOXZManager.cpp:1012` | ✅ |
| `-[OOOXZManager colorForManifest:]` (951) | `OOOXZManager::colorForManifest` `Core/OOOXZManager.cpp:1073` | ✅ |
| `-[OOOXZManager installStatusForManifest:]` (974) | `OOOXZManager::installStatusForManifest` `Core/OOOXZManager.cpp:1096` | ✅ |
| `-[OOOXZManager gui]` (997) | `OOOXZManager::gui` `Core/OOOXZManager.cpp:1216` | ✅ |
| `-[OOOXZManager isRestarting]` (1195) | `OOOXZManager::isRestarting` `Core/OOOXZManager.cpp:1119` | ✅ |
| `-[OOOXZManager processSelection]` (1211) | `OOOXZManager::processSelection` `Core/OOOXZManager.cpp:1463` | ✅ |
| `-[OOOXZManager isAcceptingTextInput]` (1301) | `isAcceptingTextInput` `Core/OOOXZManager.cpp:1554` | ✅ |
| `-[OOOXZManager isAcceptingGUIInput]` (1306) | `isAcceptingGUIInput` `Core/OOOXZManager.cpp:1559` | ✅ |
| `-[OOOXZManager processTextInput:]` (1311) | `processTextInput` `Core/OOOXZManager.cpp:1564` | ✅ |
| `-[OOOXZManager refreshTextInput:]` (1323) | `refreshTextInput` `Core/OOOXZManager.cpp:1576` | ✅ |
| `-[OOOXZManager processFilterKey]` (1334) | `processFilterKey` `Core/OOOXZManager.cpp:1590` | ✅ |
| `-[OOOXZManager processShowInfoKey]` (1347) | `processShowInfoKey` `Core/OOOXZManager.cpp:1604` | ✅ |
| `-[OOOXZManager processCopyUrlKey]` (1417) | `processCopyUrlKey` `Core/OOOXZManager.cpp:1668` | ✅ |
| `-[OOOXZManager processExtractKey]` (1443) | `processExtractKey` `Core/OOOXZManager.cpp:1696` | ✅ |
| `-[OOOXZManager installOXZ:]` (1462) | `OOOXZManager::installOXZ` `Core/OOOXZManager.cpp:1136` | ❌ |
| `-[OOOXZManager updateAllOXZ]` (1493) | `OOOXZManager::updateAllOXZ` `Core/OOOXZManager.cpp:1166` | ⚠️ |
| `-[OOOXZManager installOptions]` (1519) | `OOOXZManager::installOptions` `Core/OOOXZManager.cpp:1715` | ✅ |
| `-[OOOXZManager showInstallOptions]` (1533) | `OOOXZManager::showInstallOptions` `Core/OOOXZManager.cpp:1730` | ✅ |
| `-[OOOXZManager removeOXZ:]` (1679) | `OOOXZManager::removeOXZ` `Core/OOOXZManager.cpp:1193` | ✅ |
| `-[OOOXZManager removeOptions]` (1703) | `OOOXZManager::removeOptions` `Core/OOOXZManager.cpp:1888` | ✅ |
| `-[OOOXZManager showRemoveOptions]` (1721) | `OOOXZManager::showRemoveOptions` `Core/OOOXZManager.cpp:1906` | ✅ |
| `-[OOOXZManager showOptionsUpdate]` (1815) | `showOptionsUpdate` `Core/OOOXZManager.cpp:2010` | ✅ |
| `-[OOOXZManager showOptionsPrev]` (1831) | `showOptionsPrev` `Core/OOOXZManager.cpp:2026` | ✅ |
| `-[OOOXZManager processOptionsPrev]` (1841) | `processOptionsPrev` `Core/OOOXZManager.cpp:2036` | ✅ |
| `-[OOOXZManager processOptionsNext]` (1851) | `processOptionsNext` `Core/OOOXZManager.cpp:2046` | ✅ |
| `-[OOOXZManager showOptionsNext]` (1860) | `showOptionsNext` `Core/OOOXZManager.cpp:2055` | ✅ |
| `-[OOOXZManager extractOXZ:]` (1870) | `OOOXZManager::extractOXZ` `Core/OOOXZManager.cpp:2065` | ❌ |
| `-[OOOXZManager connection:didReceiveResponse:]` (1979) | `downloadDidReceiveResponse` `Core/OOOXZManager.cpp:2168` | ✅ |
| `-[OOOXZManager connection:didReceiveData:]` (1995) | `downloadDidReceiveData` `Core/OOOXZManager.cpp:2187` | ✅ |
| `-[OOOXZManager connectionDidFinishLoading:]` (2022) | `downloadDidFinishLoading` `Core/OOOXZManager.cpp:2221` | ✅ |
| `-[OOOXZManager connection:didFailWithError:]` (2044) | `downloadDidFailWithError` `Core/OOOXZManager.cpp:2246` | ✅ |
| `oxzSort()` (2056) | `OXZOrderedBefore` (predicate for `std::stable_sort`) `Core/OOOXZManager.cpp:198` | ✅ |

**Differences:**

- ❌ **low** — `beginDownload` can no longer fail. Upstream returned NO, set `OXZ_DOWNLOAD_ERROR` and logged `oxz.manager.error` "Unable to start downloading file at …" when `NSURLConnection` could not be created (e.g. a malformed URL). The port always builds `oo::http::Download` and returns true, so a bad URL stays STARTED until it fails later with "Error downloading file: …". — upstream `Core/OOOXZManager.m:566-585` ↔ port `Core/OOOXZManager.cpp:648-662`
- ❌ **low** — `installOXZ` with a non-string `download_url`: upstream's `+[NSURL URLWithString:]` gave nil, so the download never started (see above). The port turns the value into `""` and starts a download that fails asynchronously (comment cites proposed ADR-0044). — upstream `Core/OOOXZManager.m:1477-1490` ↔ port `Core/OOOXZManager.cpp:1149-1163`
- ❌ **low** — `extractOXZ` builds its target directory from `identifier.value_or("")` / `version.value_or("")`, giving `-.off`. The EXTRACT screen in `gui()` uses `"(null)"`, as upstream's `%@` did in both places. When a manifest has no identifier or version, the port therefore extracts somewhere other than the path it showed. Also, with no user root paths the port returns "main-unmakeable" without upstream's "Path (null) could not be created" log. — upstream `Core/OOOXZManager.m:1875-1909` ↔ port `Core/OOOXZManager.cpp:2069-2092` (vs `:1389`)
- ⚠️ **med** — `_dependencyStack` changed from an `NSMutableSet` read with `-anyObject` to an insertion-ordered `std::vector` read with `front()`. When several dependencies are unmet, the first one offered or downloaded can differ from upstream's hash order, which was effectively undefined. The same applies to the first OXZ that "update all" picks. Justified only by a comment ("order-sensitive — named in commit"); there is no ADR or bead. — upstream `Core/OOOXZManager.m:799`, `:1506` ↔ port `Core/OOOXZManager.cpp:923`, `:1178-1181`
- ⚠️ **low** — `managedOXZs`: a stored index entry missing `version` or `download_url` made upstream's `-setObject:nil forKey:` raise. The port skips that key; a comment documents this. — upstream `Core/OOOXZManager.m:641-642` ↔ port `Core/OOOXZManager.cpp:752-758`
- ⚠️ **low** — Download delivery: `GameController` now polls `processDownloadEvents()` in place of the NSURLConnection run-loop delegates, with the download on its own thread (proposed ADR-0044). The Windows `limitDateForMode:` workaround becomes `GameController::fireDueTimers()` (proposed ADR-0033). Callbacks are handled in the same order. — upstream `Core/OOOXZManager.m:1979-2051` ↔ port `Core/OOOXZManager.cpp:665-691`, `:2217`
- ➖ — `installPath`, `extractAddOnsPath` and `additionalAddOnsPaths` moved into `oo::ResourcePaths`. That covers the env vars `OO_MANAGEDADDONSDIR`, `OO_ADDONSEXTRACTDIR`, `OO_ADDITIONALADDONSDIRS` and the platform defaults. Not audited here (oofnd audit). — upstream `Core/OOOXZManager.m:220-275` ↔ port `Core/OOOXZManager.cpp:347-371`
- ✅ **low** (note) — Sorting uses `std::stable_sort` with `oo::str::localizedCompare` instead of GNUstep `sortedArrayUsingFunction:`, whose stability is not guaranteed. The keys, the `"zz"`/`"0"` defaults and the descending version order are the same. Only manifests that tie on category, title and version could come out in a different order. — upstream `Core/OOOXZManager.m:2056-2066` ↔ port `Core/OOOXZManager.cpp:198-208`
- ✅ **low** (note) — The case-insensitive filters fold each UTF-16 unit with `oo::str::toLower` instead of using `NSCaseInsensitiveSearch`. Non-ASCII special cases (e.g. ß) may match differently. Upstream's quirk, where a missing field (nil haystack) matches any search, is kept on purpose. — upstream `Core/OOOXZManager.m:449`, `:470` ↔ port `Core/OOOXZManager.cpp:152-162`
- ✅ **low** (note) — The `init` debug log prints `oo::DescriptionOf(_oxzList)` rather than the NSArray `%@` description, so the format may differ (`oxz.manager.debug` only). — upstream `Core/OOOXZManager.m:191` ↔ port `Core/OOOXZManager.cpp:324`
- ✅ (note) — `gui()`, the `show*Options()` methods and `processSelection` guard `gui`, `UNIVERSE` and `PLAYER` against null, standing in for ObjC nil messaging. With a GUI present, the rows, keys, colours and selectable range match. That includes upstream's quirk in `showRemoveOptions`, which compares "next page" against the `managedOXZs` count instead of the filtered count. — upstream `Core/OOOXZManager.m:1754` ↔ port `Core/OOOXZManager.cpp:1943`

## OOProbabilitySet

<a id="ooprobabilityset"></a>
Upstream `src/Core/OOProbabilitySet.m` ↔ `Core/OOProbabilitySet.cpp`

**Status:** done — 81 rows: 53 ✅ 2 ⚠️ 1 ❌ 25 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOProbabilitySet probabilitySet]` (121) | `OOProbabilitySet::probabilitySet` `Core/OOProbabilitySet.cpp:190` | ✅ |
| `+[OOProbabilitySet probabilitySetWithObjects:weights:count:]` (126) | `OOProbabilitySet::probabilitySetWithObjects` `Core/OOProbabilitySet.cpp:195` | ✅ |
| `+[OOProbabilitySet probabilitySetWithPropertyListRepresentation:]` (131) | `OOProbabilitySet::probabilitySetWithPropertyListRepresentation` `Core/OOProbabilitySet.cpp:222` | ✅ |
| `-[OOProbabilitySet init]` (136) | folded into `OOProbabilitySet::probabilitySet` `Core/OOProbabilitySet.cpp:190` | ✅ |
| `-[OOProbabilitySet initWithObjects:weights:count:]` (142) | folded into `OOProbabilitySet::probabilitySetWithObjects` `Core/OOProbabilitySet.cpp:195` | ✅ |
| `-[OOProbabilitySet initWithPropertyListRepresentation:]` (164) | folded into `OOProbabilitySet::probabilitySetWithPropertyListRepresentation` `Core/OOProbabilitySet.cpp:222` | ✅ |
| `-[OOProbabilitySet initPriv]` (212) | — (C++ constructors) | ➖ |
| `-[OOProbabilitySet descriptionComponents]` (217) | `OOProbabilitySet::descriptionComponents` `Core/OOProbabilitySet.cpp:259` | ✅ |
| `-[OOProbabilitySet propertyListRepresentation]` (222) | pure virtual `Core/OOProbabilitySet.h:66` | ➖ |
| `-[OOProbabilitySet randomObject]` (227) | pure virtual `Core/OOProbabilitySet.h:69` | ➖ |
| `-[OOProbabilitySet weightForObject:]` (232) | pure virtual `Core/OOProbabilitySet.h:71` | ➖ |
| `-[OOProbabilitySet sumOfWeights]` (237) | pure virtual `Core/OOProbabilitySet.h:72` | ➖ |
| `-[OOProbabilitySet count]` (242) | pure virtual `Core/OOProbabilitySet.h:68` | ➖ |
| `-[OOProbabilitySet allObjects]` (247) | pure virtual `allElements` `Core/OOProbabilitySet.h:73` | ➖ |
| `-[OOProbabilitySet copyWithZone:]` (252) | `OOProbabilitySet::copy` `Core/OOProbabilitySet.cpp:265` | ✅ |
| `-[OOProbabilitySet mutableCopyWithZone:]` (261) | `OOProbabilitySet::mutableCopy` `Core/OOProbabilitySet.cpp:272` | ✅ |
| `-[OOProbabilitySet(OOExtendedProbabilitySet) containsObject:]` (270) | `OOProbabilitySet::containsObject` `Core/OOProbabilitySet.cpp:279` | ✅ |
| `-[OOProbabilitySet(OOExtendedProbabilitySet) objectEnumerator]` (275) | — replaced by `allElements()` `Core/OOProbabilitySet.h:73` | ➖ |
| `-[OOProbabilitySet(OOExtendedProbabilitySet) probabilityForObject:]` (280) | `OOProbabilitySet::probabilityForObject` `Core/OOProbabilitySet.cpp:284` | ✅ |
| `+[OOEmptyProbabilitySet singleton]` (295) | `OOEmptyProbabilitySet::singleton` `Core/OOProbabilitySet.cpp:297` | ✅ |
| `-[OOEmptyProbabilitySet propertyListRepresentation]` (304) | `OOEmptyProbabilitySet::propertyListRepresentation` `Core/OOProbabilitySet.cpp:306` | ✅ |
| `-[OOEmptyProbabilitySet randomObject]` (310) | `OOEmptyProbabilitySet::randomObject` `Core/OOProbabilitySet.cpp:311` | ✅ |
| `-[OOEmptyProbabilitySet weightForObject:]` (315) | `OOEmptyProbabilitySet::weightForObject` `Core/OOProbabilitySet.cpp:316` | ✅ |
| `-[OOEmptyProbabilitySet sumOfWeights]` (320) | `OOEmptyProbabilitySet::sumOfWeights` `Core/OOProbabilitySet.cpp:321` | ✅ |
| `-[OOEmptyProbabilitySet count]` (325) | `OOEmptyProbabilitySet::count` `Core/OOProbabilitySet.cpp:326` | ✅ |
| `-[OOEmptyProbabilitySet allObjects]` (330) | `OOEmptyProbabilitySet::allElements` `Core/OOProbabilitySet.cpp:331` | ✅ |
| `-[OOEmptyProbabilitySet mutableCopyWithZone:]` (335) | `OOEmptyProbabilitySet::mutableCopy` `Core/OOProbabilitySet.cpp:336` | ✅ |
| `+[OOEmptyProbabilitySet(Singleton) allocWithZone:]` (352) | — immortal `new` singleton `Core/OOProbabilitySet.cpp:295` | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) copyWithZone:]` (361) | — base `copy` returns `this` `Core/OOProbabilitySet.cpp:265` | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) retain]` (366) | — (refcount starts at 1, never released) | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) retainCount]` (371) | — | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) release]` (376) | — | ➖ |
| `-[OOEmptyProbabilitySet(Singleton) autorelease]` (380) | — | ➖ |
| `-[OOSingleObjectProbabilitySet initWithObject:weight:]` (389) | `OOSingleObjectProbabilitySet::initWithObject` `Core/OOProbabilitySet.cpp:342` | ✅ |
| `-[OOSingleObjectProbabilitySet dealloc]` (404) | — (implicit destructor) | ➖ |
| `-[OOSingleObjectProbabilitySet propertyListRepresentation]` (411) | `OOSingleObjectProbabilitySet::propertyListRepresentation` `Core/OOProbabilitySet.cpp:354` | ✅ |
| `-[OOSingleObjectProbabilitySet randomObject]` (419) | `OOSingleObjectProbabilitySet::randomObject` `Core/OOProbabilitySet.cpp:359` | ✅ |
| `-[OOSingleObjectProbabilitySet weightForObject:]` (424) | `OOSingleObjectProbabilitySet::weightForObject` `Core/OOProbabilitySet.cpp:364` | ✅ |
| `-[OOSingleObjectProbabilitySet sumOfWeights]` (432) | `OOSingleObjectProbabilitySet::sumOfWeights` `Core/OOProbabilitySet.cpp:372` | ✅ |
| `-[OOSingleObjectProbabilitySet count]` (437) | `OOSingleObjectProbabilitySet::count` `Core/OOProbabilitySet.cpp:377` | ✅ |
| `-[OOSingleObjectProbabilitySet allObjects]` (442) | `OOSingleObjectProbabilitySet::allElements` `Core/OOProbabilitySet.cpp:382` | ✅ |
| `-[OOSingleObjectProbabilitySet mutableCopyWithZone:]` (447) | `OOSingleObjectProbabilitySet::mutableCopy` `Core/OOProbabilitySet.cpp:387` | ✅ |
| `-[OOConcreteProbabilitySet initWithObjects:weights:count:]` (456) | `OOConcreteProbabilitySet::initWithObjects` `Core/OOProbabilitySet.cpp:392` | ✅ |
| `-[OOConcreteProbabilitySet dealloc]` (485) | `OOConcreteProbabilitySet::~OOConcreteProbabilitySet` `Core/OOProbabilitySet.cpp:423` | ✅ |
| `-[OOConcreteProbabilitySet propertyListRepresentation]` (505) | `OOConcreteProbabilitySet::propertyListRepresentation` `Core/OOProbabilitySet.cpp:434` | ✅ |
| `-[OOConcreteProbabilitySet count]` (526) | `OOConcreteProbabilitySet::count` `Core/OOProbabilitySet.cpp:450` | ✅ |
| `-[OOConcreteProbabilitySet privObjectForWeight:]` (531) | `OOConcreteProbabilitySet::privObjectForWeight` `Core/OOProbabilitySet.cpp:455` | ✅ |
| `-[OOConcreteProbabilitySet randomObject]` (568) | `OOConcreteProbabilitySet::randomObject` `Core/OOProbabilitySet.cpp:491` | ✅ |
| `-[OOConcreteProbabilitySet weightForObject:]` (575) | `OOConcreteProbabilitySet::weightForObject` `Core/OOProbabilitySet.cpp:498` | ⚠️ |
| `-[OOConcreteProbabilitySet sumOfWeights]` (595) | `OOConcreteProbabilitySet::sumOfWeights` `Core/OOProbabilitySet.cpp:518` | ✅ |
| `-[OOConcreteProbabilitySet allObjects]` (600) | `OOConcreteProbabilitySet::allElements` `Core/OOProbabilitySet.cpp:523` | ✅ |
| `-[OOConcreteProbabilitySet objectEnumerator]` (605) | — replaced by `allElements()` | ➖ |
| `-[OOConcreteProbabilitySet privObjectAtIndex:]` (610) | — (enumerator gone) | ➖ |
| `-[OOConcreteProbabilitySet mutableCopyWithZone:]` (615) | `OOConcreteProbabilitySet::mutableCopy` `Core/OOProbabilitySet.cpp:528` | ✅ |
| `+[OOMutableProbabilitySet probabilitySet]` (643) | `OOMutableProbabilitySet::probabilitySet` `Core/OOProbabilitySet.cpp:554` | ✅ |
| `-[OOMutableProbabilitySet init]` (648) | folded into `OOMutableProbabilitySet::probabilitySet` `Core/OOProbabilitySet.cpp:554` | ✅ |
| `-[OOMutableProbabilitySet initWithObjects:weights:count:]` (655) | `OOMutableProbabilitySet::probabilitySetWithObjects` `Core/OOProbabilitySet.cpp:559` | ✅ |
| `-[OOMutableProbabilitySet initWithPropertyListRepresentation:]` (662) | `OOMutableProbabilitySet::probabilitySetWithPropertyListRepresentation` `Core/OOProbabilitySet.cpp:564` | ✅ |
| `-[OOMutableProbabilitySet copyWithZone:]` (669) | `OOMutableProbabilitySet::copy` `Core/OOProbabilitySet.cpp:572` | ✅ |
| `-[OOMutableProbabilitySet setWeight:forObject:]` (674) | pure virtual `Core/OOProbabilitySet.h:94` | ➖ |
| `-[OOMutableProbabilitySet removeObject:]` (679) | pure virtual `Core/OOProbabilitySet.h:95` | ➖ |
| `-[OOConcreteMutableProbabilitySet initPriv]` (688) | default member initialisers `Core/OOProbabilitySet.cpp:174` | ✅ |
| `-[OOConcreteMutableProbabilitySet initPrivWithObjectArray:weightsArray:sum:]` (699) | `OOConcreteMutableProbabilitySet::initPrivWithObjectArray` `Core/OOProbabilitySet.cpp:580` | ✅ |
| `-[OOConcreteMutableProbabilitySet initWithObjects:weights:count:]` (712) | `OOConcreteMutableProbabilitySet::initWithObjects` `Core/OOProbabilitySet.cpp:589` | ✅ |
| `-[OOConcreteMutableProbabilitySet initWithPropertyListRepresentation:]` (732) | `OOConcreteMutableProbabilitySet::initWithPropertyListRepresentation` `Core/OOProbabilitySet.cpp:605` | ✅ |
| `-[OOConcreteMutableProbabilitySet dealloc]` (768) | — (implicit destructor) | ➖ |
| `-[OOConcreteMutableProbabilitySet propertyListRepresentation]` (776) | `OOConcreteMutableProbabilitySet::propertyListRepresentation` `Core/OOProbabilitySet.cpp:636` | ✅ |
| `-[OOConcreteMutableProbabilitySet count]` (784) | `OOConcreteMutableProbabilitySet::count` `Core/OOProbabilitySet.cpp:641` | ✅ |
| `-[OOConcreteMutableProbabilitySet randomObject]` (789) | `OOConcreteMutableProbabilitySet::randomObject` `Core/OOProbabilitySet.cpp:646` | ❌ |
| `-[OOConcreteMutableProbabilitySet weightForObject:]` (810) | `OOConcreteMutableProbabilitySet::weightForObject` `Core/OOProbabilitySet.cpp:667` | ⚠️ |
| `-[OOConcreteMutableProbabilitySet sumOfWeights]` (825) | `OOConcreteMutableProbabilitySet::sumOfWeights` `Core/OOProbabilitySet.cpp:682` | ✅ |
| `-[OOConcreteMutableProbabilitySet allObjects]` (839) | `OOConcreteMutableProbabilitySet::allElements` `Core/OOProbabilitySet.cpp:696` | ✅ |
| `-[OOConcreteMutableProbabilitySet objectEnumerator]` (844) | — replaced by `allElements()` | ➖ |
| `-[OOConcreteMutableProbabilitySet setWeight:forObject:]` (849) | `OOConcreteMutableProbabilitySet::setWeight` `Core/OOProbabilitySet.cpp:701` | ✅ |
| `-[OOConcreteMutableProbabilitySet removeObject:]` (869) | `OOConcreteMutableProbabilitySet::removeObject` `Core/OOProbabilitySet.cpp:721` | ✅ |
| `-[OOConcreteMutableProbabilitySet copyWithZone:]` (882) | `OOConcreteMutableProbabilitySet::copy` `Core/OOProbabilitySet.cpp:734` | ✅ |
| `-[OOConcreteMutableProbabilitySet mutableCopyWithZone:]` (913) | `OOConcreteMutableProbabilitySet::mutableCopy` `Core/OOProbabilitySet.cpp:745` | ✅ |
| `-[OOProbabilitySetEnumerator initWithEnumerable:]` (924) | — enumerator class removed | ➖ |
| `-[OOProbabilitySetEnumerator dealloc]` (933) | — | ➖ |
| `-[OOProbabilitySetEnumerator nextObject]` (940) | — | ➖ |
| `ThrowAbstractionViolationException()` (953) | — abstract methods are pure virtual | ➖ |

**Differences:**

- ❌ **low** — the `probabilitySet.broken` log line prints `__PRETTY_FUNCTION__`, which is now the C++ signature (`virtual oo::PList {anonymous}::OOConcreteMutableProbabilitySet::randomObject()`), not `-[OOConcreteMutableProbabilitySet randomObject]`. The log text differs only on an internal-error path — upstream `Core/OOProbabilitySet.m:806` ↔ port `Core/OOProbabilitySet.cpp:663`
- ⚠️ **low** — element equality is `oo::PList ==` instead of `-isEqual:`. The defaulted variant compare includes the `single_` real flag and `Integer::isUnsigned`, so numeric elements NSNumber called equal (`1` vs `1.0`, float vs double) no longer match in `weightForObject`/`setWeight`/`removeObject`/`containsObject`. Game callers store strings (ship keys). Commented as deliberate (bead oo-4aq6a.5) — upstream `Core/OOProbabilitySet.m:426,585,815` ↔ port `Core/OOProbabilitySet.cpp:83-86`
- ✅ checked (RNG) — both immutable and mutable `randomObject` call `randf()` once: `(Ranrot() & 0xffff) * (1.0f/65536.0f)`, in float (`legacy_random.c:142`, identical). The draw comes before the empty/zero-sum check in the mutable set and after it in the concrete set, as upstream. Binary-search bounds, the `idx == 0` break and the leftmost-nonzero walk are verbatim — upstream `Core/OOProbabilitySet.m:539-572,795` ↔ port `Core/OOProbabilitySet.cpp:463-495,652`
- ✅ subtle — the mutable `weightForObject` subtracts `_weights[index-1]` even though `_weights` holds plain (not cumulative) weights. This upstream bug is preserved — upstream `Core/OOProbabilitySet.m:817-819` ↔ port `Core/OOProbabilitySet.cpp:674-676`
- ✅ subtle — `copy()` on an immutable set always returns `this`. Upstream's other-zone branch rebuilt the set via plist, and C++ has no zones (comment at port :267) — upstream `Core/OOProbabilitySet.m:252-259` ↔ port `Core/OOProbabilitySet.cpp:265`


## OORoleSet

<a id="ooroleset"></a>
Upstream `src/Core/OORoleSet.m` ↔ `Core/OORoleSet.cpp`

**Status:** done — 22 rows: 14 ✅ 4 ⚠️ 1 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OORoleSet roleSetWithString:]` (42) | `OORoleSet::roleSetWithString` `Core/OORoleSet.cpp:39` | ✅ |
| `+[OORoleSet roleSetWithRole:probability:]` (47) | `OORoleSet::roleSetWithRole` `Core/OORoleSet.cpp:47` | ✅ |
| `-[OORoleSet initWithRoleString:]` (52) | `OORoleSet::initWithRoleString` `Core/OORoleSet.cpp:63` | ✅ |
| `-[OORoleSet initWithRole:probability:]` (60) | `OORoleSet::initWithRole` `Core/OORoleSet.cpp:69` | ⚠️ |
| `-[OORoleSet dealloc]` (70) | — (implicit destructor) | ➖ |
| `-[OORoleSet description]` (79) | `OORoleSet::descriptionComponents` `Core/OORoleSet.cpp:81` (wrapped by `oo::DescriptionOf`) | ✅ |
| `-[OORoleSet isEqual:]` (84) | `OORoleSet::isEqual` `Core/OORoleSet.cpp:88` | ✅ |
| `-[OORoleSet hash]` (92) | `OORoleSet::hash` `Core/OORoleSet.cpp:96` | ✅ |
| `-[OORoleSet copyWithZone:]` (97) | — immutable; same `oo::Ref` shared (`Core/OORoleSet.cpp:189`) | ➖ |
| `-[OORoleSet roleString]` (103) | `OORoleSet::roleString` `Core/OORoleSet.cpp:101` | ✅ |
| `-[OORoleSet hasRole:]` (135) | `OORoleSet::hasRole` `Core/OORoleSet.cpp:127` | ✅ |
| `-[OORoleSet probabilityForRole:]` (140) | `OORoleSet::probabilityForRole` `Core/OORoleSet.cpp:132` | ✅ |
| `-[OORoleSet intersectsSet:]` (145) | — removed (bead oo-qps.53, `Core/OORoleSet.h:46`) | ➖ |
| `-[OORoleSet roles]` (155) | `OORoleSet::roles` `Core/OORoleSet.cpp:138` | ⚠️ |
| `-[OORoleSet sortedRoles]` (163) | `OORoleSet::sortedRoles` `Core/OORoleSet.cpp:147` | ✅ |
| `-[OORoleSet rolesAndProbabilities]` (168) | `OORoleSet::rolesAndProbabilities` `Core/OORoleSet.cpp:156` | ✅ |
| `-[OORoleSet anyRole]` (173) | `OORoleSet::anyRole` `Core/OORoleSet.cpp:161` | ❌ |
| `-[OORoleSet roleSetWithAddedRoleIfNotSet:probability:]` (197) | `OORoleSet::roleSetWithAddedRoleIfNotSet` `Core/OORoleSet.cpp:186` | ⚠️ |
| `-[OORoleSet roleSetWithAddedRole:probability:]` (210) | `OORoleSet::roleSetWithAddedRole` `Core/OORoleSet.cpp:197` | ⚠️ |
| `-[OORoleSet roleSetWithRemovedRole:]` (223) | `OORoleSet::roleSetWithRemovedRole` `Core/OORoleSet.cpp:208` | ✅ |
| `-[OORoleSet(OOPrivate) initWithRolesAndProbabilities:]` (239) | `OORoleSet::initWithRolesAndProbabilities` `Core/OORoleSet.cpp:218` | ✅ |
| `OOParseRolesFromString()` (286) | `OOParseRolesFromString` `Core/OORoleSet.cpp:253` | ✅ |

**Differences:**

- ❌ **med** — `anyRole` walks roles in `std::map` byte order rather than `NSDictionary` order. With the same single `randf()` draw, taken before the empty check in both, a multi-role set can return a different weighted role. The fallback when nothing is selected is also different: the first map key instead of `[[self roles] anyObject]`. The upstream caller is `ShipEntity -primaryRole` when no primary role is set (`ShipEntity.m:6303`) — upstream `Core/OORoleSet.m:184-192` ↔ port `Core/OORoleSet.cpp:172-181`
- ⚠️ **low** — an empty role string is treated as nil. `initWithRole`, `roleSetWithAddedRole` and `roleSetWithAddedRoleIfNotSet` reject `""`, where upstream accepted `@""` as a real role. Documented at `Core/OORoleSet.h:43-45` (proposed ADR-0043, bead oo-hi38) — upstream `Core/OORoleSet.m:64,201,214` ↔ port `Core/OORoleSet.cpp:73,188,199`
- ⚠️ **low** — `roles()` returns a byte-ordered vector instead of an `NSSet`, so callers that enumerate it see a different order. Documented at `Core/OORoleSet.h:59` — upstream `Core/OORoleSet.m:155-161` ↔ port `Core/OORoleSet.cpp:138-145`
- ✅ subtle — `sortedRoles` runs `std::stable_sort` with `caseInsensitiveCompare` over byte-ordered input, where upstream sorted dictionary-ordered keys. Only roles differing purely in case (`Pirate`/`pirate`) could change `roleString` order — upstream `Core/OORoleSet.m:165` ↔ port `Core/OORoleSet.cpp:150`
- ✅ checked (parsing) — tokens split on Unicode whitespace/newline (`oo::str::tokens` mirrors `ScanTokensFromString`). For a leading `(`, the whole token stays as the role, as when NSScanner's `scanUpToString` fails. The probability comes from the GNUstep-ported `scanDouble`, narrowed to float. A failed scan keeps 1.0; negative values and `[`-prefixed tokens are dropped; the last duplicate wins; an empty result gives a nil set — upstream `Core/OORoleSet.m:299-329` ↔ port `Core/OORoleSet.cpp:258-279`
- ✅ checked — `roleString` keeps `%g` on the float probability and omits it when it is `1.0f`. `hash` is still the dictionary count. The thargon→`EQ_THARGON` rewrite and the `_totalProb` sum are unchanged — upstream `Core/OORoleSet.m:94,124-125,259-279` ↔ port `Core/OORoleSet.cpp:98,116-117,230-248`


## OOShipGroup

<a id="ooshipgroup"></a>
Upstream `src/Core/OOShipGroup.m` ↔ `Core/OOShipGroup.cpp`

**Status:** done — 32 rows: 24 ✅ 1 ⚠️ 0 ❌ 7 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOShipGroup init]` (73) | — no public init; `groupWithName(std::nullopt)` | ➖ |
| `-[OOShipGroup initWithName:]` (78) | `OOShipGroup::initWithName` `Core/OOShipGroup.cpp:111` | ✅ |
| `+[OOShipGroup groupWithName:]` (94) | `OOShipGroup::groupWithName` `Core/OOShipGroup.cpp:121` | ✅ |
| `+[OOShipGroup groupWithName:leader:]` (99) | `OOShipGroup::groupWithName(name, leader)` `Core/OOShipGroup.cpp:129` | ✅ |
| `-[OOShipGroup dealloc]` (106) | `OOShipGroup::~OOShipGroup` `Core/OOShipGroup.cpp:151` | ✅ |
| `-[OOShipGroup descriptionComponents]` (119) | `OOShipGroup::descriptionComponents` `Core/OOShipGroup.cpp:158` | ✅ |
| `-[OOShipGroup name]` (131) | `OOShipGroup::name` `Core/OOShipGroup.cpp:172` | ✅ |
| `-[OOShipGroup setName:]` (136) | `OOShipGroup::setName` `Core/OOShipGroup.cpp:177` | ✅ |
| `-[OOShipGroup leader]` (146) | `OOShipGroup::leader` `Core/OOShipGroup.cpp:184` | ✅ |
| `-[OOShipGroup setLeader:]` (159) | `OOShipGroup::setLeader` `Core/OOShipGroup.cpp:195` | ✅ |
| `-[OOShipGroup objectEnumerator]` (170) | — replaced by `OOShipGroupCursor` `Core/OOShipGroup.h:120` | ➖ |
| `-[OOShipGroup mutationSafeEnumerator]` (175) | — replaced by `memberArray()` | ➖ |
| `-[OOShipGroup members]` (180) | — replaced by `memberArray()` | ➖ |
| `-[OOShipGroup membersExcludingLeader]` (185) | — replaced by `memberArrayExcludingLeader()` | ➖ |
| `-[OOShipGroup memberArray]` (190) | `OOShipGroup::memberArray` `Core/OOShipGroup.cpp:206` | ✅ |
| `-[OOShipGroup memberArrayExcludingLeader]` (210) | `OOShipGroup::memberArrayExcludingLeader` `Core/OOShipGroup.cpp:221` | ✅ |
| `-[OOShipGroup containsShip:]` (234) | `OOShipGroup::containsShip` `Core/OOShipGroup.cpp:240` | ✅ |
| `-[OOShipGroup addShip:]` (247) | `OOShipGroup::addShip` `Core/OOShipGroup.cpp:252` | ✅ |
| `-[OOShipGroup removeShip:]` (268) | `OOShipGroup::removeShip` `Core/OOShipGroup.cpp:273` | ✅ |
| `-[OOShipGroup count]` (304) | `OOShipGroup::count` `Core/OOShipGroup.cpp:311` | ✅ |
| `-[OOShipGroup isEmpty]` (320) | `OOShipGroup::isEmpty` `Core/OOShipGroup.cpp:326` | ✅ |
| `-[OOShipGroup resizeTo:]` (328) | `OOShipGroup::resizeTo` `Core/OOShipGroup.cpp:334` | ✅ |
| `-[OOShipGroup cleanUp]` (344) | `OOShipGroup::cleanUp` `Core/OOShipGroup.cpp:344` | ✅ |
| `-[OOShipGroup updateCount]` (364) | `OOShipGroup::updateCount` `Core/OOShipGroup.cpp:364` | ✅ |
| `ShipGroupIterate()` (369) | `OOShipGroupCursor::next` `Core/OOShipGroup.cpp:369` | ✅ |
| `-[OOShipGroup countByEnumeratingWithState:objects:count:]` (404) | `OOShipGroupMembers::FillBatch` `Core/OOShipGroup.cpp:407` + `Iterator` `Core/OOShipGroup.cpp:69` | ⚠️ |
| `-[OOShipGroup suppressClangStuff]` (437) | — | ➖ |
| `-[OOShipGroupEnumerator initWithShipGroup:]` (446) | `OOShipGroupCursor::OOShipGroupCursor` `Core/OOShipGroup.cpp:433` | ✅ |
| `-[OOShipGroupEnumerator dealloc]` (459) | — (`oo::Ref` member) | ➖ |
| `-[OOShipGroupEnumerator nextObject]` (466) | `OOShipGroupCursor::next` `Core/OOShipGroup.cpp:369` | ✅ |
| `-[OOShipGroupEnumerator index]` (471) | `OOShipGroupCursor::index` `Core/OOShipGroup.h:125` | ✅ |
| `-[OOShipGroupEnumerator setPerformCleanup:]` (476) | `OOShipGroupCursor::setPerformCleanup` `Core/OOShipGroup.h:126` | ✅ |

**Differences:**

- ⚠️ **low** — mutating a group inside a for-in loop raised upstream. The range-for replacement checks it with `OOCAssert`, which compiles to nothing under `NDEBUG`, so release builds keep iterating silently (comment at port :56: "for-in raised; this asserts"). The batch size (16), dead-ref compaction and `cleanUp` points are unchanged — upstream `Core/OOShipGroup.m:404-430` ↔ port `Core/OOShipGroup.cpp:79-85,407-431`
- ✅ subtle — `removeShip` calls `ship->ShipEntity::setOwner(ship)` non-virtually. Upstream has no `-setOwner:` override below ShipEntity, so dispatch is the same — upstream `Core/OOShipGroup.m:290` ↔ port `Core/OOShipGroup.cpp:297`
- ✅ subtle — `setLeader(nil)` still appends an empty weak-ref slot via `addShip(nil)`, and the next iteration compacts it, as the nil `weakRetain` did. The growth/shrink constants are unchanged (`kMinSize` 4, `kMaxFreeSpace` 128, power-of-2 rounding) — upstream `Core/OOShipGroup.m:163-166,247-266,344-362` ↔ port `Core/OOShipGroup.cpp:199-203,252-271,344-362`


## OOShipLibraryDescriptions

<a id="ooshiplibrarydescriptions"></a>
Upstream `src/Core/OOShipLibraryDescriptions.m` ↔ `Core/OOShipLibraryDescriptions.cpp`

**Status:** done — 11 rows: 11 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOShipLibraryCategorySingular()` (29) | `OOShipLibraryCategorySingular` `Core/OOShipLibraryDescriptions.cpp:45` (via `ExpandCategoryKey` :37) | ✅ |
| `OOShipLibraryCategoryPlural()` (34) | `OOShipLibraryCategoryPlural` `Core/OOShipLibraryDescriptions.cpp:50` | ✅ |
| `OOShipLibrarySpeed()` (39) | `OOShipLibrarySpeed` `Core/OOShipLibraryDescriptions.cpp:55` | ✅ |
| `OOShipLibraryTurnRate()` (59) | `OOShipLibraryTurnRate` `Core/OOShipLibraryDescriptions.cpp:75` | ✅ |
| `OOShipLibraryCargo()` (77) | `OOShipLibraryCargo` `Core/OOShipLibraryDescriptions.cpp:93` | ✅ |
| `OOShipLibraryGenerator()` (89) | `OOShipLibraryGenerator` `Core/OOShipLibraryDescriptions.cpp:105` | ✅ |
| `OOShipLibraryShields()` (103) | `OOShipLibraryShields` `Core/OOShipLibraryDescriptions.cpp:119` | ✅ |
| `OOShipLibraryWitchspace()` (122) | `OOShipLibraryWitchspace` `Core/OOShipLibraryDescriptions.cpp:138` | ✅ |
| `OOShipLibraryWeapons()` (131) | `OOShipLibraryWeapons` `Core/OOShipLibraryDescriptions.cpp:147` | ✅ |
| `OOShipLibraryTurrets()` (142) | `OOShipLibraryTurrets` `Core/OOShipLibraryDescriptions.cpp:158` | ✅ |
| `OOShipLibrarySize()` (152) | `OOShipLibrarySize` `Core/OOShipLibraryDescriptions.cpp:168` | ✅ |

**Differences:**

- ✅ **low** — The thresholds (1/150/250/325/425, 2/2.75/4.5/6, 2.5/3.75, 128/192/256/320), the facing-bit count and the `(unsigned)` size truncation are all the same. Upstream relied on nil messaging returning 0; the port's explicit `demo_ship ? … : 0` gives the same results. — upstream `Core/OOShipLibraryDescriptions.m:39-155` ↔ port `Core/OOShipLibraryDescriptions.cpp:55-173`
- ✅ **low** — `[category]` expansion: `cxx_OOExpand(pattern, category)` boxes the argument under its own name (`#ITEM` = "category"), as the ObjC `OOExpand` macro did. A nil/nullopt key becomes `""`, so the caller's `length == 0` check behaves the same. — upstream `Core/OOShipLibraryDescriptions.m:31` ↔ port `Core/OOShipLibraryDescriptions.cpp:37-41`, `Core/OOStringExpander.h:261-275`
- ✅ **low** (subtle) — The `-u` format strings come from descriptions.plist at runtime and are now passed to `oo::str::format` (vsnprintf), not `stringWithFormat:`. The core strings use only `%u`, so the output bytes match. An overriding description that contains `%@` would now be undefined instead of printing an object description. — upstream `Core/OOShipLibraryDescriptions.m:84,139,146,155` ↔ port `Core/OOShipLibraryDescriptions.cpp:100,155,162,173`

## OOShipRegistry

<a id="ooshipregistry"></a>
Upstream `src/Core/OOShipRegistry.m` ↔ `Core/OOShipRegistry.cpp`

**Status:** done — 51 rows: 36 ✅ 7 ⚠️ 0 ❌ 8 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOShipRegistry sharedRegistry]` (119) | `OOShipRegistry::sharedRegistry` `Core/OOShipRegistry.cpp:159` | ✅ |
| `+[OOShipRegistry reload]` (128) | `OOShipRegistry::reload` `Core/OOShipRegistry.cpp:170` | ✅ |
| `-[OOShipRegistry init]` (141) | `OOShipRegistry::init` `Core/OOShipRegistry.cpp:183` | ✅ |
| `-[OOShipRegistry dealloc]` (180) | — (value members; the singleton is leaked as before, `leakRef` :163) | ➖ |
| `-[OOShipRegistry shipInfoForKey:]` (190) | `OOShipRegistry::shipInfoForKey` `Core/OOShipRegistry.cpp:225` | ✅ |
| `-[OOShipRegistry setShipInfoForKey:with:]` (195) | `OOShipRegistry::setShipInfoForKey` `Core/OOShipRegistry.cpp:231` | ✅ |
| `-[OOShipRegistry effectInfoForKey:]` (203) | `OOShipRegistry::effectInfoForKey` `Core/OOShipRegistry.cpp:239` | ✅ |
| `-[OOShipRegistry shipyardInfoForKey:]` (208) | `OOShipRegistry::shipyardInfoForKey` `Core/OOShipRegistry.cpp:245` | ✅ |
| `-[OOShipRegistry probabilitySetForRole:]` (213) | `OOShipRegistry::probabilitySetForRole` `Core/OOShipRegistry.cpp:252` | ✅ |
| `-[OOShipRegistry demoShipKeys]` (220) | `OOShipRegistry::demoShipKeys` `Core/OOShipRegistry.cpp:260` | ✅ |
| `-[OOShipRegistry playerShipKeys]` (228) | `OOShipRegistry::playerShipKeys` `Core/OOShipRegistry.cpp:268` | ✅ |
| `-[OOShipRegistry(OOConveniences) shipKeys]` (237) | `OOShipRegistry::shipKeys` `Core/OOShipRegistry.cpp:275` | ⚠️ |
| `-[OOShipRegistry(OOConveniences) shipRoles]` (242) | `OOShipRegistry::shipRoles` `Core/OOShipRegistry.cpp:286` | ⚠️ |
| `-[OOShipRegistry(OOConveniences) shipKeysWithRole:]` (247) | `OOShipRegistry::shipKeysWithRole` `Core/OOShipRegistry.cpp:297` | ✅ |
| `-[OOShipRegistry(OOConveniences) randomShipKeyForRole:]` (252) | `OOShipRegistry::randomShipKeyForRole` `Core/OOShipRegistry.cpp:309` | ✅ |
| `-[OOShipRegistry(OODataLoader) loadShipData]` (271) | `OOShipRegistry::loadShipData` `Core/OOShipRegistry.cpp:331` | ✅ |
| `-[OOShipRegistry(OODataLoader) loadDemoShipConditions]` (383) | `OOShipRegistry::loadDemoShipConditions` `Core/OOShipRegistry.cpp:432` | ✅ |
| `-[OOShipRegistry(OODataLoader) loadDemoShips]` (411) | `OOShipRegistry::loadDemoShips` `Core/OOShipRegistry.cpp:460` | ⚠️ |
| `-[OOShipRegistry(OODataLoader) loadCachedRoleProbabilitySets]` (511) | `OOShipRegistry::loadCachedRoleProbabilitySets` `Core/OOShipRegistry.cpp:566` | ✅ |
| `-[OOShipRegistry(OODataLoader) buildRoleProbabilitySets]` (530) | `OOShipRegistry::buildRoleProbabilitySets` `Core/OOShipRegistry.cpp:582` | ⚠️ |
| `-[OOShipRegistry(OODataLoader) applyLikeShips:withKey:]` (578) | `OOShipRegistry::applyLikeShips` `Core/OOShipRegistry.cpp:621` | ✅ |
| `-[OOShipRegistry(OODataLoader) mergeShip:withParent:]` (642) | `OOShipRegistry::mergeShip` `Core/OOShipRegistry.cpp:679` | ✅ |
| `-[OOShipRegistry(OODataLoader) makeShipEntriesMutable:]` (696) | `OOShipRegistry::makeShipEntriesMutable` `Core/OOShipRegistry.cpp:736` | ✅ |
| `-[OOShipRegistry(OODataLoader) loadAndApplyShipDataOverrides:]` (717) | `OOShipRegistry::loadAndApplyShipDataOverrides` `Core/OOShipRegistry.cpp:752` | ✅ |
| `-[OOShipRegistry(OODataLoader) stripPrivateKeys:]` (745) | `OOShipRegistry::stripPrivateKeys` `Core/OOShipRegistry.cpp:773` | ✅ |
| `-[OOShipRegistry(OODataLoader) loadAndMergeShipyard:]` (773) | `OOShipRegistry::loadAndMergeShipyard` `Core/OOShipRegistry.cpp:791` | ⚠️ |
| `-[OOShipRegistry(OODataLoader) canonicalizeAndTagSubentities:]` (826) | `OOShipRegistry::canonicalizeAndTagSubentities` `Core/OOShipRegistry.cpp:974` | ✅ |
| `-[OOShipRegistry(OODataLoader) removeUnusableEntries:shipMode:]` (906) | `OOShipRegistry::removeUnusableEntries` `Core/OOShipRegistry.cpp:837` | ✅ |
| `-[OOShipRegistry(OODataLoader) sanitizeConditions:]` (947) | `OOShipRegistry::sanitizeConditions` `Core/OOShipRegistry.cpp:878` | ⚠️ |
| `-[OOShipRegistry(OODataLoader) preloadShipMeshes:]` (1050) | `OOShipRegistry::preloadShipMeshes` `Core/OOShipRegistry.cpp:1052` (`#if PRELOAD` = 0 in both) | ➖ |
| `-[OOShipRegistry(OODataLoader) mergeShipRoles:]` (1095) | `OOShipRegistry::mergeShipRoles` `Core/OOShipRegistry.cpp:1094` | ✅ |
| `-[OOShipRegistry(OODataLoader) canonicalizeSubentityDeclaration:]` (1136) | `OOShipRegistry::canonicalizeSubentityDeclaration` `Core/OOShipRegistry.cpp:1127` | ⚠️ |
| `-[OOShipRegistry(OODataLoader) translateOldStyleSubentityDeclaration:]` (1178) | `OOShipRegistry::translateOldStyleSubentityDeclaration` `Core/OOShipRegistry.cpp:1162` | ✅ |
| `-[OOShipRegistry(OODataLoader) translateOldStyleFlasherDeclaration:]` (1215) | `OOShipRegistry::translateOldStyleFlasherDeclaration` `Core/OOShipRegistry.cpp:1196` | ✅ |
| `-[OOShipRegistry(OODataLoader) translateOldStandardBasicSubentityDeclaration:]` (1249) | `OOShipRegistry::translateOldStandardBasicSubentityDeclaration` `Core/OOShipRegistry.cpp:1231` | ✅ |
| `-[OOShipRegistry(OODataLoader) validateNewStyleSubentityDeclaration:]` (1297) | `OOShipRegistry::validateNewStyleSubentityDeclaration` `Core/OOShipRegistry.cpp:1279` | ✅ |
| `-[OOShipRegistry(OODataLoader) validateNewStyleFlasherDeclaration:]` (1318) | `OOShipRegistry::validateNewStyleFlasherDeclaration` `Core/OOShipRegistry.cpp:1294` | ✅ |
| `-[OOShipRegistry(OODataLoader) validateNewStyleStandardSubentityDeclaration:]` (1395) | `OOShipRegistry::validateNewStyleStandardSubentityDeclaration` `Core/OOShipRegistry.cpp:1368` | ✅ |
| `-[OOShipRegistry(OODataLoader) shipIsBallTurretForKey:inShipData:]` (1484) | `OOShipRegistry::shipIsBallTurretForKey` `Core/OOShipRegistry.cpp:1452` | ✅ |
| `+[OOShipRegistry(Singleton) allocWithZone:]` (1517) | — (its "Loading ship data." log moved into `sharedRegistry` `Core/OOShipRegistry.cpp:162`) | ➖ |
| `-[OOShipRegistry(Singleton) copyWithZone:]` (1527) | — (refcount boilerplate gone) | ➖ |
| `-[OOShipRegistry(Singleton) retain]` (1532) | — | ➖ |
| `-[OOShipRegistry(Singleton) retainCount]` (1537) | — | ➖ |
| `-[OOShipRegistry(Singleton) release]` (1542) | — (`reload` deliberately leaks, `Core/OOShipRegistry.cpp:176`) | ➖ |
| `-[OOShipRegistry(Singleton) autorelease]` (1546) | — | ➖ |
| `DumpStringAddrs()` (1557) | `DumpStringAddrs` `Core/OOShipRegistry.cpp:1486` (early `return;` in both) | ✅ |
| `GatherStringAddrsDict()` (1586) | `GatherStringAddrsDict` `Core/OOShipRegistry.cpp:1513` | ✅ |
| `GatherStringAddrsArray()` (1597) | `GatherStringAddrsArray` `Core/OOShipRegistry.cpp:1522` | ✅ |
| `GatherStringAddrs()` (1606) | `GatherStringAddrs` `Core/OOShipRegistry.cpp:1530` (+ helper `GatherStringAddr` :1508) | ✅ |
| `SortDemoShipsByName()` (1618) | lambda in `loadDemoShips` `Core/OOShipRegistry.cpp:553-555` | ✅ |
| `SortDemoCategoriesByName()` (1623) | lambda in `loadDemoShips` `Core/OOShipRegistry.cpp:560-562` | ✅ |

**Differences:**

- ⚠️ **med** — **Role probability sets** are built by adding ships to each role's `OOMutableProbabilitySet` in `std::map` key order. Upstream added them in `NSDictionary` hash order. `randomObject` binary-searches cumulative weights in insertion order, so the same RNG draw can return a different ship key for a role. With no cache, NPC spawns will diverge from goldens recorded against upstream. Intentional: ADR-0043 §"Reproduce GNUstep's hash order"; the code comment reads "(ships in key order; was hash order)". — upstream `Core/OOShipRegistry.m:543-548` ↔ port `Core/OOShipRegistry.cpp:586-591`
- ⚠️ **med** — **Player ship order**: `_playerShips` follows shipyard.plist key order, not hash order. `Universe` draws randoms while iterating `playerShipKeys()` to build shipyards (`Core/Universe.cpp:8645`), so shipyard contents can differ from upstream for the same seed. Covered by ADR-0043 and the comment at :806-807. — upstream `Core/OOShipRegistry.m:804-820` ↔ port `Core/OOShipRegistry.cpp:808-828`
- ⚠️ **low** — `shipKeys()` and `shipRoles()` (JS `Ship.keys()` and `Ship.roles()`, `Core/Scripting/OOJSShip.cpp:4230,4276`) now return sorted keys; upstream returned `allKeys` in hash order. Covered by ADR-0043 and the header comment at `Core/OOShipRegistry.h:59`. — upstream `Core/OOShipRegistry.m:237-245` ↔ port `Core/OOShipRegistry.cpp:275-295`
- ⚠️ **low** — **Demo-ship fallback**: when the library is empty and `coriolis-station` is missing, the port picks the first ship key in sorted order, not `[[_shipData allKeys] objectAtIndex:0]` in hash order (comment at :518, ADR-0043). — upstream `Core/OOShipRegistry.m:473` ↔ port `Core/OOShipRegistry.cpp:518`
- ✅ **low** (subtle) — **Demo-ship list sort**: grouping and the literal `compare:` sort by `name`, then by plural category name, match upstream. The port uses `std::stable_sort`, so ships with equal names keep their shiplibrary.plist order. GNUstep's `sortUsingFunction:` is not guaranteed stable, so its order for tied names may have differed. — upstream `Core/OOShipRegistry.m:503-508,1618-1626` ↔ port `Core/OOShipRegistry.cpp:552-563`
- ✅ **low** — **like_ship inheritance** matches upstream:
  - iterative resolution against the live pending set;
  - a missing parent gives nil, which keeps the ship pending;
  - unresolved ships are removed, except those marked `is_external_dependency`;
  - the case-insensitively sorted `shipData.merge.failed` message and `OOStandardsError`.

  The outcome does not depend on order. As upstream, `mergeShip` erases `like_ship` even for `like_effect`. The rules that stop `display_name` and `is_template` being inherited, and the five alias-pair conflict resolutions, match line for line. A non-string `like_ship` never resolves in either. — upstream `Core/OOShipRegistry.m:578-694` ↔ port `Core/OOShipRegistry.cpp:621-734`
- ✅ **low** — **Role parsing (`mergeShipRoles`)**: the injected `[shipKey]` role has weight 1.0f, and `thargon`→`EQ_THARGON` is copied only if absent. The order roles are visited in does not matter, because each role has its own set. `OOParseRolesFromString` is in `Core/OORoleSet.cpp:253` and is audited there. — upstream `Core/OOShipRegistry.m:1111-1133` ↔ port `Core/OOShipRegistry.cpp:1104-1124`
- ⚠️ **low** — The `shipData.load.error.badSubentity` log prints the plist type name (`array`, `integer`) where upstream printed the ObjC class name (`GSMutableArray`…). The code comment cites bead oo-qps.50. — upstream `Core/OOShipRegistry.m:1167` ↔ port `Core/OOShipRegistry.cpp:1150`
- ⚠️ **low** — These loops now run in key order rather than hash order: the cached "ship conditions" condition-script list, the per-ship error and deprecation logs from `sanitizeConditions`, `canonicalizeAndTagSubentities` and the overrides, and the shipyard warnings. The data is the same; only log-line order differs (ADR-0043; comment at :892). — upstream `Core/OOShipRegistry.m:960,1043` ↔ port `Core/OOShipRegistry.cpp:893,969`
- ✅ **low** (subtle) — **Malformed shipyard entries**: upstream raised when a `shipyard.plist` entry or a `shipyard-overrides` entry was not a dictionary (`dictionaryByAddingEntriesFromDictionary:` sent to, or given, a non-dictionary). The port stores the entry or skips the merge and keeps loading. Only malformed data reaches this. — upstream `Core/OOShipRegistry.m:810` ↔ port `Core/OOShipRegistry.cpp:813-817`
- ✅ **low** — Cases where upstream raised still raise. These are: `setObject:nil` for a demo ship with no `name`, `addObject:nil` for a subentity with no `subentity_key` string, `objectAtIndex:0` on an empty token list, and the three `OOShipRegistryLoadFailure` exceptions in `init`. — upstream `Core/OOShipRegistry.m:154-171,494,871,1189,1493` ↔ port `Core/OOShipRegistry.cpp:102-108,202-219,540,1010`
- ✅ **low** — `oo_setFloat:` stored a double, and the port does too (`static_cast<double>`). Flasher and colour values stay single reals (`numberWithFloat:`). These defaults are unchanged: size 8, bright_fraction 0.5, frequency 2, phase 0, initially_on YES, `redColor`. So are the turret clamps: fire rate 0.25, range `TURRET_SHOT_RANGE*COMBAT_WEAPON_RANGE_FACTOR`, energy 100. — upstream `Core/OOShipRegistry.m:1318-1482` ↔ port `Core/OOShipRegistry.cpp:1294-1450`

## OOStringExpander

<a id="oostringexpander"></a>
Upstream `src/Core/OOStringExpander.m` ↔ `Core/OOStringExpander.cpp`

**Status:** done — 41 rows: 33 ✅ 5 ⚠️ 3 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| *(added)* `OO_EXPANDER_RANDOM` macro (43) | same macro Core/OOStringExpander.cpp:73 | ✅ |
| *(added)* `kStackAllocationLimit` / `kRecursionLimit` enum (45) | same enum Core/OOStringExpander.cpp:75 | ✅ |
| `OOExpandDescriptionString()` (160) | `cxx_OOExpandDescriptionString` Core/OOStringExpander.cpp:220 | ✅ |
| `OOGenerateSystemDescription()` (220) | `cxx_OOGenerateSystemDescription` Core/OOStringExpander.cpp:270 | ✅ |
| `OOStringExpanderDefaultRandomSeed()` (226) | `OOStringExpanderDefaultRandomSeed` Core/OOStringExpander.cpp:276 | ✅ |
| `Expand()` (243) | `Expand` Core/OOStringExpander.cpp:296 | ⚠️ |
| `ExpandKey()` (349) | `ExpandKey` Core/OOStringExpander.cpp:404 | ✅ |
| `ApplyOperators()` (410) | `ApplyOperators` Core/OOStringExpander.cpp:465 | ✅ |
| `Operator_cr()` (428) | `Operator_cr` Core/OOStringExpander.cpp:511 | ✅ |
| `Operator_dcr()` (433) | `Operator_dcr` Core/OOStringExpander.cpp:516 | ✅ |
| `Operator_icr()` (438) | `Operator_icr` Core/OOStringExpander.cpp:521 | ✅ |
| `Operator_idcr()` (443) | `Operator_idcr` Core/OOStringExpander.cpp:526 | ✅ |
| `Operator_precision()` (448) | `Operator_precision` Core/OOStringExpander.cpp:531 | ✅ |
| `Operator_multiply()` (453) | `Operator_multiply` Core/OOStringExpander.cpp:536 | ✅ |
| `Operator_add()` (458) | `Operator_add` Core/OOStringExpander.cpp:541 | ✅ |
| `ApplyOneOperator()` (472) | `ApplyOneOperator` Core/OOStringExpander.cpp:555 | ✅ |
| `ExpandDigitKey()` (508) | `ExpandDigitKey` Core/OOStringExpander.cpp:592 | ✅ |
| `ExpandStringKey()` (563) | `ExpandStringKey` Core/OOStringExpander.cpp:656 | ✅ |
| `ExpandStringKeyOverride()` (613) | `ExpandStringKeyOverride` Core/OOStringExpander.cpp:709 (+ `ValueText` :880) | ⚠️ |
| `ExpandStringKeySpecial()` (636) | `ExpandStringKeySpecial` Core/OOStringExpander.cpp:732 | ✅ |
| `ExpandStringKeyKeyboardBinding()` (659) | `ExpandStringKeyKeyboardBinding` Core/OOStringExpander.cpp:758 | ✅ |
| `SpecialSubstitutionSelectors()` (674) | `SpecialSubstitutionSelectors` Core/OOStringExpander.cpp:773 | ✅ |
| `ExpandStringKeyFromDescriptions()` (712) | `ExpandStringKeyFromDescriptions` Core/OOStringExpander.cpp:811 | ⚠️ |
| `ExpandStringKeyMissionVariable()` (738) | `ExpandStringKeyMissionVariable` Core/OOStringExpander.cpp:841 | ⚠️ |
| `ExpandStringKeyLegacyLocalVariable()` (753) | `ExpandStringKeyLegacyLocalVariable` Core/OOStringExpander.cpp:861 | ✅ |
| `ExpandLegacyScriptSelectorKey()` (764) | `ExpandLegacyScriptSelectorKey` Core/OOStringExpander.cpp:895 | ✅ |
| `LookUpLegacySelector()` (782) | `LookUpLegacySelector` Core/OOStringExpander.cpp:916 | ✅ |
| `ReportWarningForUnknownKey()` (834) | `ReportWarningForUnknownKey` Core/OOStringExpander.cpp:978 | ✅ |
| `ExpandPercentEscape()` (864) | `ExpandPercentEscape` Core/OOStringExpander.cpp:1008 | ⚠️ |
| `ExpandPercentR()` (934) | `ExpandPercentR` Core/OOStringExpander.cpp:1089 | ✅ |
| `ExpandSystemNameForGalaxyEscape()` (967) | `ExpandSystemNameForGalaxyEscape` Core/OOStringExpander.cpp:1135 | ✅ |
| `ExpandSystemNameEscape()` (1014) | `ExpandSystemNameEscape` Core/OOStringExpander.cpp:1182 | ✅ |
| `AppendCharacters()` (1047) | `AppendCharacters` Core/OOStringExpander.cpp:1215 (+ `UnitsWithCharacters` :1367) | ✅ |
| `GetSystemName()` (1075) | `GetSystemName` Core/OOStringExpander.cpp:1232 | ✅ |
| `GetSystemNameIan()` (1085) | `GetSystemNameIan` Core/OOStringExpander.cpp:1242 | ✅ |
| `GetRandomNameN()` (1096) | `GetRandomNameN` Core/OOStringExpander.cpp:1255 | ✅ |
| `GetRandomNameR()` (1107) | `GetRandomNameR` Core/OOStringExpander.cpp:1266 | ✅ |
| `GetSystemDescriptions()` (1118) | `GetSystemDescriptions` Core/OOStringExpander.cpp:1277 | ❌ |
| `OldRandomDigrams()` (1134) | `OldRandomDigrams` Core/OOStringExpander.cpp:1319 (+ `Digram` :1296, `Capitalized` :1310) | ❌ |
| `NewRandomDigrams()` (1152) | `NewRandomDigrams` Core/OOStringExpander.cpp:1340 | ❌ |
| `SyntaxIssue()` (1168) | `SyntaxIssue` Core/OOStringExpander.cpp:1418 (+ `ReportJavaScriptWarning` :1444) | ✅ |

**Differences:**

- ❌ **low** — Nil-messaging on `UNIVERSE`: `ExpandStringKeyFromDescriptions`, `GetSystemDescriptions`, `OldRandomDigrams` and `NewRandomDigrams` dereference `UNIVERSE->descriptions()` without checking for null. Upstream's `[[UNIVERSE descriptions] …]` gave nil, so the key was unknown, or the digram text was empty. The other lookups in this same file do guard `UNIVERSE`/`PLAYER` (:278, :1174, :1212, :1236). An expansion run before `Universe` exists (or in a test harness) would crash instead of degrading. — upstream `Core/OOStringExpander.m:714,1123,1139,1157` ↔ port `Core/OOStringExpander.cpp:814,1283,1324,1345`
- ⚠️ **low** — `Expand`: a `"\x7F"` replacement at the very end of the string no longer eats a character past the end. Upstream incremented `replaceLength` there, which set `copyRangeStart > size` and failed the `AppendCharacters` assertion. The port leaves it alone (bead oo-3rb.69, approved by Jon 2026-09-29). Output is unchanged wherever upstream did not assert. — upstream `Core/OOStringExpander.m:304-307` ↔ port `Core/OOStringExpander.cpp:359-363`
- ⚠️ **low** — Unknown `%x` escape warning: upstream's `%lc` of a unichar printed an undefined high byte on GNUstep, so the port prints only the low byte as U+00xx (code comment, probed on gnustep-base 1.31.1). This only affects the debug/console `strings.expand.warning.unknownPercentEscape` text. — upstream `Core/OOStringExpander.m:923` ↔ port `Core/OOStringExpander.cpp:1067-1078`
- ⚠️ **low** — In the `strings.expand.warning.invalidOverride` and `strings.expand.invalidData` texts, `oo::DescriptionOf(value)` replaces `-shortDescription` (`<ClassName 0x…>`). The bead is oo-qps.50; the comment at :813 still claims the class name is kept. — upstream `Core/OOStringExpander.m:621,723` ↔ port `Core/OOStringExpander.cpp:717,826`
- ⚠️ **low** — A mission variable whose value is not a string (e.g. an array set through legacy `set-list`) now expands as unset. Upstream returned the object, which a string operation later rejected (code comment, bead oo-qps.50). JS-set mission variables are always strings, so normal play is unaffected. — upstream `Core/OOStringExpander.m:740-742` ↔ port `Core/OOStringExpander.cpp:843-850`
- ✅ **(RNG order, verified)** — Each source draws the same values from the same generator, in the same order:
  - **Digit key `[n]`:** `system_description` is looked up first, then one `OO_EXPANDER_RANDOM` draw. The Elite 5-entry thresholds 0x33/0x66/0x99/0xCC apply only without GoodRNG; otherwise the pick is `(rnd*count)/256`.
  - **descriptions.plist array:** one draw, `% count`, and only for a non-empty array.
  - **`%N`:** two draws for the length (`%4`, then `%5` against the 3:1 test), then one draw per digram. It is cached per context.
  - **`%R`:** deferred to the post-pass, and only when `hasPercentR` is set. `gen_rnd_number` is called once for `len`, then `len+1` more times for the digrams. It is cached per context, and every `%R` gets the same name.
  - **`%I`:** a nested expansion of `planetname-possessive` with `GoodRNG|DisallowPercentI|Key`, so it uses Ranrot.
  - **ReseedRNG:** state is saved before the expansion and restored after it, including the `%R` pass. As upstream, it is not restored on an exception.

  — upstream `Core/OOStringExpander.m:43,180-213,533-551,717,934-960,1085-1166` ↔ port `Core/OOStringExpander.cpp:73,237-266,620-637,818,1089-1128,1242-1357`
- ✅ **(grammar, verified)** — The key grammar is unchanged:
  - **Brackets:** `[`/`]` are balance-counted. The first `|` ends the key, and only characters before it count toward `allDigits`.
  - **Empty key:** `[]` warns and gives no replacement.
  - **Operators:** they split on every `|` (an empty operator logs `strings.expand.invalidOperator`), and the parameter follows the first `:`.
  - **Key lookup order:** override → special → descriptions.plist → `oolite_key_` → `mission_` → legacy local. The legacy-selector result is still discarded, a quirk kept from upstream (comment).
  - **`oolite_key_` binding:** `substr(7)` is kept, an upstream quirk that passes `key_…`.
  - **Escapes:** `%%`, `%[` and `%]` are literals; `%@`, `%d` and `%.` are left untouched.
  - **`%J###`/`%G######`:** the same length and digit checks, the range limits and the shared `strings.expand.invalidJEscape` class.
  - **`%H`:** `systemName`, or else the player's current system name, cached only when it is non-nil.

  — upstream `Core/OOStringExpander.m:349-402,410-426,563-602,659-667,864-1045,1075-1083` ↔ port `Core/OOStringExpander.cpp:404-488,656-698,758-766,1008-1213,1232-1240`
- ✅ **low** (subtle) — Key, operator and literal segments go through `UnitsWithCharacters`, which reproduces GNUstep's leading-BOM handling in `-initWithCharacters:length:` (drop U+FEFF; drop U+FFFE and byte-swap; twice). `FindUnits` reproduces `-rangeOfString:`'s composed-sequence rule. The Mac (CoreFoundation) path had neither. The port follows GNUstep, as the goldens do. — upstream `Core/OOStringExpander.m:392,397,1066-1072` ↔ port `Core/OOStringExpander.cpp:1367-1405`
- ✅ **low** (subtle) — `SyntaxIssue` always formats the message before checking `oo::log::willDisplay`. Upstream checked first, so only CPU cost differs. The JS path passes the formatted text through `"%s"`, which gives the same output. The prefix `"----- WARNING: "` matches `OOLOG_WARNING_PREFIX`. — upstream `Core/OOStringExpander.m:1168-1191` ↔ port `Core/OOStringExpander.cpp:205,1418-1441`

## OOStringParsing

<a id="oostringparsing"></a>
Upstream `src/Core/OOStringParsing.m` ↔ `Core/OOStringParsing.cpp`

**Status:** done — 24 rows: 21 ✅ 1 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `ScanTokensFromString()` (44) | `oo::str::tokens` `oofnd/String.hpp:993` | ✅ |
| `ScanVectorFromString()` (70) | `cxx_ScanVectorFromString` `Core/OOStringParsing.cpp:58` | ✅ |
| `ScanHPVectorFromString()` (100) | `cxx_ScanHPVectorFromString` `Core/OOStringParsing.cpp:86` | ✅ |
| `ScanQuaternionFromString()` (112) | `cxx_ScanQuaternionFromString` `Core/OOStringParsing.cpp:98` | ✅ |
| `ScanVectorAndQuaternionFromString()` (146) | `cxx_ScanVectorAndQuaternionFromString` `Core/OOStringParsing.cpp:130` | ✅ |
| `VectorFromString()` (183) | `cxx_VectorFromString` `Core/OOStringParsing.cpp:165` | ✅ |
| `QuaternionFromString()` (191) | `cxx_QuaternionFromString` `Core/OOStringParsing.cpp:173` | ✅ |
| `StringFromPoint()` (199) | `cxx_StringFromPoint` `Core/OOStringParsing.cpp:181` | ✅ |
| `PointFromString()` (204) | `cxx_PointFromString` `Core/OOStringParsing.cpp:186` | ✅ |
| `RandomSeedFromString()` (217) | `cxx_RandomSeedFromString` `Core/OOStringParsing.cpp:198` | ⚠️ |
| `StringFromRandomSeed()` (248) | `cxx_StringFromRandomSeed` `Core/OOStringParsing.cpp:229` | ✅ |
| `OOPadStringToEms()` (253) | `cxx_OOPadStringToEms` `Core/OOStringParsing.cpp:234` | ✅ |
| `OOStringFromDeciCredits()` (270) | `cxx_OOStringFromDeciCredits` `Core/OOStringParsing.cpp:251` | ✅ |
| `OOStringFromIntCredits()` (header 52) | `cxx_OOStringFromIntCredits` `Core/OOStringParsing.h:56` | ✅ |
| `OOCredits()` (header 57) | `cxx_OOCredits` `Core/OOStringParsing.h:61` | ✅ |
| `OOIntCredits()` (header 61) | `cxx_OOIntCredits` `Core/OOStringParsing.h:65` | ✅ |
| `-[NSString(OOUtilities) pathHasExtension:]` (323) | `oo::str::pathHasExtension` `oofnd/String.hpp:908` | ❌ |
| `-[NSString(OOUtilities) pathHasExtensionInArray:]` (328) | `oo::str::pathHasExtensionIn` `oofnd/String.hpp:915` | ❌ |
| `ComponentsFromVersionString()` (342) | `cxx_ComponentsFromVersionString` → `oo::str::versionComponents` `Core/OOStringParsing.cpp:305`, `oofnd/String.hpp:1332` | ✅ |
| `CompareVersions()` (369) | `cxx_CompareVersions` → `oo::str::compareVersions` `Core/OOStringParsing.cpp:310`, `oofnd/String.hpp:1345` | ✅ |
| `ClockToString()` (402) | `cxx_ClockToString` `Core/OOStringParsing.cpp:320` | ✅ |
| `EscapedGraphVizString()` (424) | `cxx_EscapedGraphVizString` `Core/OOStringParsing.cpp:343` | ✅ |
| `GraphVizTokenString()` (459) | `cxx_GraphVizTokenString` `Core/OOStringParsing.cpp:386` | ✅ |
| `NameIsTaken()` (516) | `NameIsTaken` (anon namespace) `Core/OOStringParsing.cpp:371` | ✅ |

**Differences:**

- ❌ **low** — `pathHasExtension:`/`pathHasExtensionInArray:` compare with `equalsIgnoringCaseAscii` instead of the Unicode-aware `-caseInsensitiveCompare:`. A non-ASCII extension that differs only by case (`.Ä` vs `.ä`) no longer matches — upstream `Core/OOStringParsing.m:325,333` ↔ port `oofnd/String.hpp:910,918`
- ⚠️ **low** — `RandomSeedFromString(nil)` scans an empty string (proposed ADR-0039, commented). Both return `kNilRandomSeed`, but the logged reason changes from "could not scan a int value." to "found less than six int values." — upstream `Core/OOStringParsing.m:223-227` ↔ port `Core/OOStringParsing.cpp:204-212`
- ✅ checked (localisation) — `OOStringFromDeciCredits` keeps the reentrancy fallback `%0.1f` and the no-result fallback `%li` of `(long)tenths/10`. Formatting runs `vsnprintf` under `setlocale(LC_ALL,"C")` (`SDL/main.cpp:148`), so the decimal separator is '.' as in GNUstep; `long` is 32-bit on Windows in both builds — upstream `Core/OOStringParsing.m:272-318` ↔ port `Core/OOStringParsing.cpp:253-302`
- ✅ subtle — if JS `formatCredits` throws, the port's default `rval` takes the fallback; upstream read an uninitialised `jsval`. Both acquire the JS context before the reentrancy early return and never release it on that path — upstream `Core/OOStringParsing.m:272-318` ↔ port `Core/OOStringParsing.cpp:253-302`
- ✅ subtle — `ClockToString` keeps the int `floor` arithmetic and passes the DESC format (`%07d:%02d:%02d:%02d`) through `oo::str::formatRuntime` — upstream `Core/OOStringParsing.m:407-419` ↔ port `Core/OOStringParsing.cpp:325-338`
- ✅ subtle — `GraphVizTokenString` keeps upstream's infinite loop when `token_2` is already taken (`uniqueID` is never incremented). It is built only under DEBUG_GRAPHVIZ — upstream `Core/OOStringParsing.m:502-506` ↔ port `Core/OOStringParsing.cpp:430-434`


## OOSystemDescriptionManager

<a id="oosystemdescriptionmanager"></a>
Upstream `src/Core/OOSystemDescriptionManager.m` ↔ `Core/OOSystemDescriptionManager.cpp`

**Status:** done — 31 rows: 28 ✅ 1 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSystemDescriptionManager init]` (62) | `OOSystemDescriptionManager::OOSystemDescriptionManager` `Core/OOSystemDescriptionManager.cpp:90` | ✅ |
| `-[OOSystemDescriptionManager dealloc]` (82) | implicit destructor | ➖ |
| `-[OOSystemDescriptionManager buildRouteCache]` (96) | `OOSystemDescriptionManager::buildRouteCache` `Core/OOSystemDescriptionManager.cpp:103` | ✅ |
| `-[OOSystemDescriptionManager setUniversalProperties:]` (120) | `OOSystemDescriptionManager::setUniversalProperties` `Core/OOSystemDescriptionManager.cpp:128` | ✅ |
| `-[OOSystemDescriptionManager setInterstellarProperties:]` (129) | `OOSystemDescriptionManager::setInterstellarProperties` `Core/OOSystemDescriptionManager.cpp:142` | ✅ |
| `-[OOSystemDescriptionManager setProperties:forSystemKey:]` (134) | `OOSystemDescriptionManager::setProperties(const oo::PList&, const std::string&)` `Core/OOSystemDescriptionManager.cpp:147` | ✅ |
| `-[OOSystemDescriptionManager setProperty:forSystemKey:andLayer:toValue:fromManifest:]` (158) | `OOSystemDescriptionManager::setProperty` `Core/OOSystemDescriptionManager.cpp:173` | ✅ |
| `-[OOSystemDescriptionManager saveScriptedChangeToProperty:forSystemKey:andLayer:toValue:fromManifest:]` (188) | `OOSystemDescriptionManager::saveScriptedChangeToProperty` `Core/OOSystemDescriptionManager.cpp:202` | ✅ |
| `-[OOSystemDescriptionManager importScriptedChanges:]` (206) | `OOSystemDescriptionManager::importScriptedChanges` `Core/OOSystemDescriptionManager.cpp:226` (+ `OOSystemLayerFromNumber` :58) | ⚠️ |
| `-[OOSystemDescriptionManager importLegacyScriptedChanges:]` (235) | `OOSystemDescriptionManager::importLegacyScriptedChanges` `Core/OOSystemDescriptionManager.cpp:255` | ✅ |
| `-[OOSystemDescriptionManager exportScriptedChanges]` (271) | `OOSystemDescriptionManager::exportScriptedChanges` `Core/OOSystemDescriptionManager.cpp:291` | ✅ |
| `-[OOSystemDescriptionManager getPropertiesForCurrentSystem]` (276) | `OOSystemDescriptionManager::getPropertiesForCurrentSystem` `Core/OOSystemDescriptionManager.cpp:296` | ✅ |
| `-[OOSystemDescriptionManager getPropertiesForSystemKey:]` (293) | `OOSystemDescriptionManager::getPropertiesForSystemKey` `Core/OOSystemDescriptionManager.cpp:313` | ✅ |
| `-[OOSystemDescriptionManager getPropertiesForSystem:inGalaxy:]` (310) | `OOSystemDescriptionManager::getPropertiesForSystem` `Core/OOSystemDescriptionManager.cpp:330` | ✅ |
| `-[OOSystemDescriptionManager getProperty:forSystemKey:]` (320) | `OOSystemDescriptionManager::getProperty(property, key)` `Core/OOSystemDescriptionManager.cpp:340` | ✅ |
| `-[OOSystemDescriptionManager getProperty:forSystem:inGalaxy:]` (325) | `OOSystemDescriptionManager::getProperty(property, s, g)` `Core/OOSystemDescriptionManager.cpp:345` | ✅ |
| `-[OOSystemDescriptionManager getProperty:forSystemKey:withUniversal:]` (339) | `OOSystemDescriptionManager::getProperty(property, key, universal)` `Core/OOSystemDescriptionManager.cpp:359` | ✅ |
| `-[OOSystemDescriptionManager getProperty:orProperty:forSystemKey:withUniversal:]` (367) | `OOSystemDescriptionManager::getProperty(property1, property2, key, universal)` `Core/OOSystemDescriptionManager.cpp:388` | ✅ |
| `-[OOSystemDescriptionManager setProperties:inDescription:]` (407) | `OOSystemDescriptionManager::setProperties(const oo::PList&, OOSystemDescriptionEntry*)` `Core/OOSystemDescriptionManager.cpp:428` | ✅ |
| `-[OOSystemDescriptionManager calculatePropertiesForSystemKey:]` (424) | `OOSystemDescriptionManager::calculatePropertiesForSystemKey` `Core/OOSystemDescriptionManager.cpp:448` | ✅ |
| `-[OOSystemDescriptionManager updateCacheEntry:]` (448) | `OOSystemDescriptionManager::updateCacheEntry(NSUInteger)` `Core/OOSystemDescriptionManager.cpp:470` | ✅ |
| `-[OOSystemDescriptionManager updateCacheEntry:forProperty:]` (458) | `OOSystemDescriptionManager::updateCacheEntry(NSUInteger, const std::string&)` `Core/OOSystemDescriptionManager.cpp:477` | ✅ |
| `-[OOSystemDescriptionManager getCoordinatesForSystem:inGalaxy:]` (470) | `OOSystemDescriptionManager::getCoordinatesForSystem` `Core/OOSystemDescriptionManager.cpp:490` | ✅ |
| `-[OOSystemDescriptionManager getNeighbourIDsForSystem:inGalaxy:]` (484) | `OOSystemDescriptionManager::getNeighbourIDsForSystem` `Core/OOSystemDescriptionManager.cpp:504` | ✅ |
| `-[OOSystemDescriptionManager getRandomSeedForCurrentSystem]` (499) | `OOSystemDescriptionManager::getRandomSeedForCurrentSystem` `Core/OOSystemDescriptionManager.cpp:519` | ✅ |
| `-[OOSystemDescriptionManager getRandomSeedForSystem:inGalaxy:]` (514) | `OOSystemDescriptionManager::getRandomSeedForSystem` `Core/OOSystemDescriptionManager.cpp:535` | ✅ |
| `-[OOSystemDescriptionEntry init]` (536) | `OOSystemDescriptionEntry::OOSystemDescriptionEntry` `Core/OOSystemDescriptionManager.cpp:549` | ✅ |
| `-[OOSystemDescriptionEntry dealloc]` (547) | implicit destructor | ➖ |
| `-[OOSystemDescriptionEntry setProperty:forLayer:toValue:]` (555) | `OOSystemDescriptionEntry::setProperty` `Core/OOSystemDescriptionManager.cpp:556` | ✅ |
| `-[OOSystemDescriptionEntry getProperty:forLayer:]` (570) | `OOSystemDescriptionEntry::getProperty` `Core/OOSystemDescriptionManager.cpp:572` | ✅ |
| `-[OOSystemDescriptionEntry validateProperty:withValue:]` (580) | `OOSystemDescriptionEntry::validateProperty` `Core/OOSystemDescriptionManager.cpp:582` | ✅ |

**Differences:**

- ⚠️ **low** — `importScriptedChanges` clamps the saved layer. Upstream passed the raw `oo_intAtIndex:3` as an `OOSystemLayer`, so an out-of-range layer from a hand-edited save indexed past `layers[]` (UB). The port maps any value over 3, negatives included via the unsigned cast, to `OO_LAYER_OXP_PRIORITY`, the rule `setProperties:inDescription:` already applied (bead oo-2eby) — upstream `Core/OOSystemDescriptionManager.m:220` ↔ port `Core/OOSystemDescriptionManager.cpp:58-61,240`
- ⚠️ **low** — `importScriptedChanges`, `importLegacyScriptedChanges` and `setProperties:inDescription:` iterate in key order rather than hash order (commented). Order only matters in `importScriptedChanges`, when two manifests set the same key, property and layer: the last one wins, so the winner may differ from upstream — upstream `Core/OOSystemDescriptionManager.m:211` ↔ port `Core/OOSystemDescriptionManager.cpp:231-232`
- ✅ checked (layering) — there are 4 layers (CORE=0, OXP_STATIC=1, OXP_DYNAMIC=2, OXP_PRIORITY=3). Lookup order is PRIORITY → DYNAMIC → STATIC → universal (only when `universal`) → CORE, so universal overrides core. The two-property variant interleaves property1/property2 at each layer. `interstellar` maps to `interstellarSpace` only in the single-property overload — upstream `Core/OOSystemDescriptionManager.m:339-405` ↔ port `Core/OOSystemDescriptionManager.cpp:359-426`
- ✅ checked (layering) — planetinfo dicts default to layer OXP_STATIC; a layer over 3 logs `system.description.error` and clamps to PRIORITY. The `"layer"` key is kept out of the entry but still added to `propertiesInUse` — upstream `Core/OOSystemDescriptionManager.m:134-156,407-422` ↔ port `Core/OOSystemDescriptionManager.cpp:147-171,428-446`
- ✅ checked — interstellar regions (`interstellar:` keys) look up the region-specific value without universal, then fall back to the `interstellar` entry with universal. Regions are not cached, and region changes are saved but never update the cache — upstream `Core/OOSystemDescriptionManager.m:183,429-443` ↔ port `Core/OOSystemDescriptionManager.cpp:197,451-465`
- ✅ checked — the scripted-change key format is unchanged: `manifest~|~systemKey~|~property~|~layer`. A nil manifest skips the save; a nil value removes the key. Import requires exactly 4 parts (empty parts kept), skips manifests that are not installed, and logs `systemManager.import` "Key '%@' has unexpected format - skipping" — upstream `Core/OOSystemDescriptionManager.m:195-229` ↔ port `Core/OOSystemDescriptionManager.cpp:211-249`
- ✅ subtle — upstream returned the live `NSMutableDictionary` `propertyCache[i]`, which `updateCacheEntry:` mutated in place. The port returns an `oo::PList` copy and replaces the slot, so a caller that keeps the returned dict holds a snapshot. The upstream callers checked (Universe.m:1285,1328,1605,7428; GuiDisplayGen; PlayerEntity:7031) read it at once — upstream `Core/OOSystemDescriptionManager.m:285,454-455` ↔ port `Core/OOSystemDescriptionManager.cpp:305,474`
- ✅ subtle — the `importLegacyScriptedChanges` sun-radius fix is unchanged: it applies when `sun_radius < 600000`, adds 600000 as a float, and writes layer OXP_DYNAMIC with manifest `org.oolite.oolite` — upstream `Core/OOSystemDescriptionManager.m:257-265` ↔ port `Core/OOSystemDescriptionManager.cpp:277-285`


## OOTrumble

<a id="ootrumble"></a>
Upstream `src/Core/OOTrumble.m` ↔ `Core/OOTrumble.cpp`

**Status:** done — 41 rows: 39 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOTrumble init]` (41) | `OOTrumble::OOTrumble()` `Core/OOTrumble.cpp:40` | ✅ |
| `-[OOTrumble initForPlayer:]` (54) | `OOTrumble::OOTrumble(PlayerEntity*)` `Core/OOTrumble.cpp:49` | ✅ |
| `-[OOTrumble initForPlayer:digram:]` (63) | `OOTrumble::OOTrumble(PlayerEntity*, const std::string&)` `Core/OOTrumble.cpp:54` | ✅ |
| `-[OOTrumble setupForPlayer:digram:]` (72) | `OOTrumble::setupForPlayer` `Core/OOTrumble.cpp:59` | ❌ |
| `-[OOTrumble dealloc]` (210) | `oo::Ref<OOTexture> texture` member releases itself (`Core/OOTrumble.h`) | ➖ |
| `-[OOTrumble spawnFrom:]` (217) | `OOTrumble::spawnFrom` `Core/OOTrumble.cpp:193` | ✅ |
| `-[OOTrumble calcGrowthRate]` (252) | `OOTrumble::calcGrowthRate` `Core/OOTrumble.cpp:228` | ✅ |
| `-[OOTrumble digram]` (258) | `OOTrumble::getDigram` `Core/OOTrumble.cpp:234` | ✅ |
| `-[OOTrumble position]` (263) | `OOTrumble::getPosition` `Core/OOTrumble.cpp:239` | ✅ |
| `-[OOTrumble movement]` (268) | `OOTrumble::getMovement` `Core/OOTrumble.cpp:244` | ✅ |
| `-[OOTrumble rotation]` (273) | `OOTrumble::getRotation` `Core/OOTrumble.cpp:249` | ✅ |
| `-[OOTrumble size]` (278) | `OOTrumble::getSize` `Core/OOTrumble.cpp:254` | ✅ |
| `-[OOTrumble hunger]` (283) | `OOTrumble::getHunger` `Core/OOTrumble.cpp:259` | ✅ |
| `-[OOTrumble discomfort]` (288) | `OOTrumble::getDiscomfort` `Core/OOTrumble.cpp:264` | ✅ |
| `-[OOTrumble actionIdle]` (294) | `OOTrumble::actionIdle` `Core/OOTrumble.cpp:270` | ✅ |
| `-[OOTrumble actionBlink]` (300) | `OOTrumble::actionBlink` `Core/OOTrumble.cpp:276` | ✅ |
| `-[OOTrumble actionSnarl]` (306) | `OOTrumble::actionSnarl` `Core/OOTrumble.cpp:282` | ✅ |
| `-[OOTrumble actionProot]` (312) | `OOTrumble::actionProot` `Core/OOTrumble.cpp:288` | ✅ |
| `-[OOTrumble actionShudder]` (318) | `OOTrumble::actionShudder` `Core/OOTrumble.cpp:294` | ✅ |
| `-[OOTrumble actionStoned]` (324) | `OOTrumble::actionStoned` `Core/OOTrumble.cpp:300` | ✅ |
| `-[OOTrumble actionPop]` (330) | `OOTrumble::actionPop` `Core/OOTrumble.cpp:306` | ✅ |
| `-[OOTrumble actionSleep]` (336) | `OOTrumble::actionSleep` `Core/OOTrumble.cpp:312` | ✅ |
| `-[OOTrumble actionSpawn]` (342) | `OOTrumble::actionSpawn` `Core/OOTrumble.cpp:318` | ✅ |
| `-[OOTrumble randomizeMotionX]` (348) | `OOTrumble::randomizeMotionX` `Core/OOTrumble.cpp:324` | ✅ |
| `-[OOTrumble randomizeMotionY]` (355) | `OOTrumble::randomizeMotionY` `Core/OOTrumble.cpp:331` | ✅ |
| `-[OOTrumble drawTrumble:]` (362) | `OOTrumble::drawTrumble` `Core/OOTrumble.cpp:338` | ✅ |
| `-[OOTrumble updateTrumble:]` (490) | `OOTrumble::updateTrumble` `Core/OOTrumble.cpp:467` | ✅ |
| `-[OOTrumble updateIdle:]` (652) | `OOTrumble::updateIdle` `Core/OOTrumble.cpp:633` | ✅ |
| `-[OOTrumble updateBlink:]` (689) | `OOTrumble::updateBlink` `Core/OOTrumble.cpp:670` | ✅ |
| `-[OOTrumble updateSnarl:]` (706) | `OOTrumble::updateSnarl` `Core/OOTrumble.cpp:687` | ✅ |
| `-[OOTrumble updateProot:]` (742) | `OOTrumble::updateProot` `Core/OOTrumble.cpp:723` | ✅ |
| `-[OOTrumble updateShudder:]` (775) | `OOTrumble::updateShudder` `Core/OOTrumble.cpp:756` | ✅ |
| `-[OOTrumble updateStoned:]` (808) | `OOTrumble::updateStoned` `Core/OOTrumble.cpp:789` | ✅ |
| `-[OOTrumble updatePop:]` (812) | `OOTrumble::updatePop` `Core/OOTrumble.cpp:793` | ✅ |
| `-[OOTrumble updateSleep:]` (850) | `OOTrumble::updateSleep` `Core/OOTrumble.cpp:832` | ✅ |
| `-[OOTrumble updateSpawn:]` (880) | `OOTrumble::updateSpawn` `Core/OOTrumble.cpp:862` | ✅ |
| `-[OOTrumble dictionary]` (906) | `OOTrumble::dictionary` `Core/OOTrumble.cpp:889` | ✅ |
| `-[OOTrumble setFromDictionary:]` (923) | `OOTrumble::setFromDictionary` `Core/OOTrumble.cpp:905` | ✅ |
| `InitTrumbleSounds()` (943) | `InitTrumbleSounds` `Core/OOTrumble.cpp:926` | ✅ |
| `PlayTrumbleIdle()` (952) | `PlayTrumbleIdle` `Core/OOTrumble.cpp:935` | ✅ |
| `PlayTrumbleSqueal()` (962) | `PlayTrumbleSqueal` `Core/OOTrumble.cpp:947` | ✅ |

**Differences:**

- ❌ **low** — `setupForPlayer` with a one-character digram (e.g. a corrupt `digram` in a save): upstream `characterAtIndex:1` raised NSRangeException, while the port reads 0 and carries on. A nil or missing digram reads 0,0 in both — upstream `Core/OOTrumble.m:76-77` ↔ port `Core/OOTrumble.cpp:63-65`
- ✅ checked — the constants are unchanged: `TRUMBLE_MAX_ROTATION` 15.0, `TRUMBLE_MAX_ROTATIONAL_VELOCITY` 5.0, `TRUMBLE_GROWTH_RATE` 0.01, and all animation durations. The `ranrot_srand(r0 + r1*256)` seed and the order and count of `ranrot_rand()`/`randf()` calls match, including one `randf()` per cargo pod even with a null market — upstream `Core/OOTrumble.h:32-35`, `Core/OOTrumble.m:110-196,584` ↔ port `Core/OOTrumble.h:44-47`, `Core/OOTrumble.cpp:98-184,561`
- ✅ subtle — `spawnFrom` round-trips the mutated UTF-16 digram through UTF-8 (`utf16ToUtf8`/`utf8ToUtf16`). Values stay below 0x100, so no surrogates arise and nothing is lost — upstream `Core/OOTrumble.m:221-228` ↔ port `Core/OOTrumble.cpp:197-204`
- ✅ subtle — `dictionary` writes `singleReal` floats, matching `numberWithFloat:`. Cargo removal uses `std::erase`, which removes all equal entries, matching `removeObject:`. Sounds come from `OOSoundWithCustomSoundKey`, the same cache as `initWithCustomSoundKey:` — upstream `Core/OOTrumble.m:605,906-921,947-948` ↔ port `Core/OOTrumble.cpp:585,889-903,930-931`


## ResourceManager

<a id="resourcemanager"></a>
Upstream `src/Core/ResourceManager.m` ↔ `Core/ResourceManager.cpp`

**Status:** done — 71 rows: 58 ✅ 8 ⚠️ 3 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[ResourceManager reset]` (102) | `ResourceManager::reset` Core/ResourceManager.cpp:364 | ✅ |
| `+[ResourceManager resetManifestKnowledgeForOXZManager]` (114) | `resetManifestKnowledgeForOXZManager` Core/ResourceManager.cpp:376 | ✅ |
| `+[ResourceManager errors]` (123) | `errors` Core/ResourceManager.cpp:385 | ✅ |
| `+[ResourceManager rootPaths]` (151) | `rootPaths` Core/ResourceManager.cpp:412 (via `oo::ResourcePaths`, oofnd/ResourcePaths.hpp:243) | ✅ |
| `+[ResourceManager userRootPaths]` (163) | `userRootPaths` Core/ResourceManager.cpp:429 (oofnd/ResourcePaths.hpp:233) | ✅ |
| `+[ResourceManager builtInPath]` (192) | `builtInPath` Core/ResourceManager.cpp:445 (oofnd/ResourcePaths.hpp:224) | ⚠️ |
| `+[ResourceManager pathsWithAddOns]` (212) | `pathsWithAddOns` Core/ResourceManager.cpp:451 | ❌ |
| `+[ResourceManager preloadFileLists]` (332) | `preloadFileLists` Core/ResourceManager.cpp:568 | ✅ |
| `+[ResourceManager preloadFileListFromOXZ:forFolders:]` (349) | `preloadFileListFromOXZ` Core/ResourceManager.cpp:584 | ✅ |
| `+[ResourceManager preloadFileListFromFolder:forFolders:]` (388) | `preloadFileListFromFolder` Core/ResourceManager.cpp:621 | ✅ |
| `+[ResourceManager preloadFilePathFor:inFolder:atPath:]` (406) | `preloadFilePathFor` Core/ResourceManager.cpp:633 | ✅ |
| `+[ResourceManager paths]` (418) | `paths` Core/ResourceManager.cpp:644 | ✅ |
| `+[ResourceManager maskUserNameInPathArray:]` (426) | `maskUserNameInPathArray` Core/ResourceManager.cpp:652 | ✅ |
| `+[ResourceManager maskUserName:inPath:]` (444) | `maskUserName` Core/ResourceManager.cpp:669 | ✅ |
| `+[ResourceManager useAddOns]` (455) | `useAddOns` Core/ResourceManager.cpp:674 | ✅ |
| `+[ResourceManager setUseAddOns:]` (460) | `setUseAddOns` Core/ResourceManager.cpp:679 | ✅ |
| `+[ResourceManager addExternalPath:]` (494) | `addExternalPath` Core/ResourceManager.cpp:711 | ✅ |
| `+[ResourceManager pathEnumerator]` (507) | none; callers iterate `paths()` | ➖ |
| `+[ResourceManager reversePathEnumerator]` (512) | none; callers iterate `paths()` with `rbegin()` | ➖ |
| `+[ResourceManager OXPsWithMessagesFound]` (517) | `OXPsWithMessagesFound` Core/ResourceManager.cpp:722 | ✅ |
| `+[ResourceManager manifestForIdentifier:]` (522) | `manifestForIdentifier` Core/ResourceManager.cpp:727 | ✅ |
| `+[ResourceManager checkOXPMessagesInPath:]` (527) | `checkOXPMessagesInPath` Core/ResourceManager.cpp:759 | ✅ |
| `+[ResourceManager checkPotentialPath:searchPaths:]` (546) | `checkPotentialPath` Core/ResourceManager.cpp:778 | ✅ |
| `+[ResourceManager validateManifest:forOXP:]` (590) | `validateManifest` Core/ResourceManager.cpp:829 | ✅ |
| `+[ResourceManager checkVersionCompatibility:forOXP:]` (647) | `checkVersionCompatibility` Core/ResourceManager.cpp:884 | ✅ |
| `+[ResourceManager areRequirementsFulfilled:forOXP:andFile:]` (659) | `areRequirementsFulfilled` Core/ResourceManager.cpp:899 | ⚠️ |
| `+[ResourceManager manifestHasConflicts:logErrors:]` (719) | `manifestHasConflicts` Core/ResourceManager.cpp:955 | ✅ |
| `+[ResourceManager filterSearchPathsForConflicts:]` (749) | `filterSearchPathsForConflicts` Core/ResourceManager.cpp:980 | ⚠️ |
| `+[ResourceManager manifestHasMissingDependencies:logErrors:]` (769) | `manifestHasMissingDependencies` Core/ResourceManager.cpp:1002 | ✅ |
| `+[ResourceManager manifest:HasUnmetDependency:logErrors:]` (787) | `ResourceManager::manifest(manifest, required, logErrors)` Core/ResourceManager.cpp:1017 | ✅ |
| `+[ResourceManager filterSearchPathsForRequirements:]` (828) | `filterSearchPathsForRequirements` Core/ResourceManager.cpp:1065 | ⚠️ |
| `+[ResourceManager matchVersions:withVersion:]` (853) | `matchVersions` Core/ResourceManager.cpp:1092 | ✅ |
| `+[ResourceManager filterSearchPathsToExcludeScenarioOnlyPaths:]` (877) | `filterSearchPathsToExcludeScenarioOnlyPaths` Core/ResourceManager.cpp:1113 | ✅ |
| `+[ResourceManager filterSearchPathsByScenario:]` (896) | `filterSearchPathsByScenario` Core/ResourceManager.cpp:1134 | ⚠️ |
| `+[ResourceManager manifestAllowedByScenario:]` (916) | `manifestAllowedByScenario(manifest)` Core/ResourceManager.cpp:1156 | ✅ |
| `+[ResourceManager manifestAllowedByScenario:withIdentifier:]` (947) | `manifestAllowedByScenario(manifest, identifier)` Core/ResourceManager.cpp:1188 | ✅ |
| `+[ResourceManager manifestAllowedByScenario:withTag:]` (962) | `manifestAllowedByScenarioWithTag` Core/ResourceManager.cpp:1203 | ✅ |
| `+[ResourceManager addErrorWithKey:param1:param2:]` (985) | `addErrorWithKey` Core/ResourceManager.cpp:1222 | ✅ |
| `+[ResourceManager checkCacheUpToDateForPaths:]` (994) | `checkCacheUpToDateForPaths` Core/ResourceManager.cpp:1228 | ❌ |
| `+[ResourceManager corePlist:excludedAt:]` (1061) | `corePlist` Core/ResourceManager.cpp:1294 | ✅ |
| `+[ResourceManager dictionaryFromFilesNamed:]` (1081) (`…inFolder:andMerge:`) | `dictionaryFromFilesNamed(…, bool)` Core/ResourceManager.cpp:1313 | ✅ |
| `+[ResourceManager dictionaryFromFilesNamed:]` (1088) (`…inFolder:mergeMode:cache:`) | `dictionaryFromFilesNamed(…, OOResourceMergeMode, bool)` Core/ResourceManager.cpp:1320 | ✅ |
| `+[ResourceManager arrayFromFilesNamed:inFolder:andMerge:]` (1191) | `arrayFromFilesNamed(…, bool)` Core/ResourceManager.cpp:1415 | ✅ |
| `+[ResourceManager arrayFromFilesNamed:inFolder:andMerge:cache:]` (1196) | `arrayFromFilesNamed(…, bool, bool)` Core/ResourceManager.cpp:1420 | ✅ |
| `+[ResourceManager handleEquipmentListMerging:forLookupIndex:]` (1300) | `handleEquipmentListMerging` Core/ResourceManager.cpp:1511 | ✅ |
| `+[ResourceManager handleEquipmentOverrides:]` (1331) | `handleEquipmentOverrides` Core/ResourceManager.cpp:1543 | ❌ |
| `+[ResourceManager handleStarNebulaListMerging:]` (1414) | `handleStarNebulaListMerging` Core/ResourceManager.cpp:1606 (+ `TextureListKey` :286) | ✅ |
| `+[ResourceManager whitelistDictionary]` (1466) | `whitelistDictionary` Core/ResourceManager.cpp:1641 | ✅ |
| `LogClassKeyRoot()` (1484) | `LogClassKeyRoot` Core/ResourceManager.cpp:313 | ✅ |
| `+[ResourceManager logControlDictionary]` (1494) | `logControlDictionary` Core/ResourceManager.cpp:1652 | ✅ |
| `+[ResourceManager roleCategoriesDictionary]` (1558) | `roleCategoriesDictionary` Core/ResourceManager.cpp:1714 | ✅ |
| `+[ResourceManager mergeRoleCategories:intoDictionary:]` (1589) | `mergeRoleCategories` Core/ResourceManager.cpp:1747 | ⚠️ |
| `+[ResourceManager systemDescriptionManager]` (1607) | `systemDescriptionManager` Core/ResourceManager.cpp:1775 | ✅ |
| `+[ResourceManager shaderBindingTypesDictionary]` (1646) | `shaderBindingTypesDictionary` Core/ResourceManager.cpp:1808 | ✅ |
| `+[ResourceManager pathForFileNamed:inFolder:]` (1687) | `pathForFileNamed(…)` Core/ResourceManager.cpp:1850 | ✅ |
| `+[ResourceManager pathForFileNamed:inFolder:cache:]` (1693) | `pathForFileNamed(…, bool)` Core/ResourceManager.cpp:1856 | ✅ |
| `+[ResourceManager retrieveFileNamed:]` (1743) (`…inFolder:cache:key:class:usePathCache:`) | `retrieveFileNamed` Core/ResourceManager.cpp:1906 (class fixed to OOSound) | ✅ |
| `+[ResourceManager ooMusicNamed:inFolder:]` (1777) | `ooMusicNamed` Core/ResourceManager.cpp:1940 (inlines the uncached retrieve) | ✅ |
| `+[ResourceManager ooSoundNamed:inFolder:]` (1787) | `ooSoundNamed` Core/ResourceManager.cpp:1949 | ✅ |
| `+[ResourceManager stringFromFilesNamed:inFolder:]` (1797) | `stringFromFilesNamed(…)` Core/ResourceManager.cpp:1954 | ✅ |
| `+[ResourceManager stringFromFilesNamed:inFolder:cache:]` (1802) | `stringFromFilesNamed(…, bool)` Core/ResourceManager.cpp:1959 | ✅ |
| `+[ResourceManager loadScripts]` (1831) | `loadScripts` Core/ResourceManager.cpp:1988 | ⚠️ |
| `+[ResourceManager writeDiagnosticData:toFileNamed:]` (1898) | `writeDiagnosticData` Core/ResourceManager.cpp:2056 | ✅ |
| `+[ResourceManager writeDiagnosticString:toFileNamed:]` (1925) | `writeDiagnosticString` Core/ResourceManager.cpp:2083 | ✅ |
| `+[ResourceManager writeDiagnosticPList:toFileNamed:]` (1930) | `writeDiagnosticPList` Core/ResourceManager.cpp:2088 | ✅ |
| `+[ResourceManager materialDefaults]` (1941) | `materialDefaults` Core/ResourceManager.cpp:2099 | ✅ |
| `+[ResourceManager directoryExists:create:]` (1946) | `directoryExists` Core/ResourceManager.cpp:2104 | ✅ |
| `+[ResourceManager diagnosticFileLocation]` (1969) | `diagnosticFileLocation` Core/ResourceManager.cpp:2126 | ✅ |
| `+[ResourceManager logPaths]` (1974) | `logPaths` Core/ResourceManager.cpp:735 | ⚠️ |
| `+[ResourceManager clearCaches]` (1988) | `clearCaches` Core/ResourceManager.cpp:753 | ✅ |
| *(added)* `-[NSMutableDictionary(OOExtensions) mergeEntriesFromDictionary:]` (NSMutableDictionaryOOExtensions.m; used by MERGE_SMART) | `MergeEntries` Core/ResourceManager.cpp:258 (+ `PListIsEqual` :189 for `-isEqual:`) | ✅ |

**Differences:**

- ❌ **med** — A **symlinked `.oxp` folder** is no longer picked up. The OXP scan types each entry with `symlink_status`, so the link comes back as `FileType::symbolic_link`, falls into the "not a directory" branch (which only tests for `oxz`) and is silently ignored. Upstream's `fileExistsAtPath:isDirectory:` followed the link, so the OXP was validated and added to the search paths. Symlinked `.oxz` files still load. — upstream `Core/ResourceManager.m:263-269` ↔ port `Core/ResourceManager.cpp:498-500` (oofnd/FileSystem.hpp:186-247)
- ❌ **med** — Search-path modification dates are converted as `ftime - file_clock::now() + system_clock::now()`. The two `now()` calls sample different instants, so the stored double carries sub-microsecond jitter that changes on every call. The exact `PListIsEqual` against the previous run's cached dates then fails often. The result is "Cache is stale (modification dates have changed)" (`dataCache.rebuild.datesChanged`) and a full cache rebuild. Upstream stored a stable `-timeIntervalSince1970`. — upstream `Core/ResourceManager.m:1028-1041` ↔ port `Core/ResourceManager.cpp:1259-1274` (cause: oofnd/FileSystem.hpp:172-183)
- ❌ **low** — `equipment-overrides.plist`: within one entry, `name` and `short_description` write the same array slot, as do `description` and `long_description`. Which key wins depends on enumeration order. Upstream used NSDictionary hash order; the port's sorted `std::map` (oofnd/PList.hpp:136) always lets `short_description` and `long_description` win. No comment marks this as intended. — upstream `Core/ResourceManager.m:1356-1369` ↔ port `Core/ResourceManager.cpp:1563-1572`
- ⚠️ **low** — The manifest filters iterate `sOXPManifests` in sorted-identifier order rather than hash order (comment: "identifier order (was hash order)"). This is observable in three places:
  - which of two mutually conflicting OXPs is kept;
  - the order of `oxp.conflict` / `oxp.requirementMissing` log lines and `sErrors`;
  - in `filterSearchPathsByScenario`, whether a by-tag allowance through `required_by` sees a requirer that has already been removed.

  — upstream `Core/ResourceManager.m:753,832,900,974` ↔ port `Core/ResourceManager.cpp:982,1067,1136,1211`
- ⚠️ **low** — `mergeRoleCategories` keeps each category as an array of unique roles in first-seen order, where upstream used an `NSMutableSet` (commented). Membership is the same; enumeration order is not. — upstream `Core/ResourceManager.m:1589-1605` ↔ port `Core/ResourceManager.cpp:1747-1773`
- ⚠️ **low** — `loadScripts` returns name→script pairs in first-load order, and a later script with the same name replaces the earlier one in place (commented). Upstream returned an `NSMutableDictionary` in hash order. Callers that dispatch world-script events in container order now see a different order. The `listAll` log is sorted case-insensitively and is unaffected. — upstream `Core/ResourceManager.m:1840-1866` ↔ port `Core/ResourceManager.cpp:1991-2018`
- ⚠️ **low** — The `requirements.wrongType` log prints `oo::typeName(...)` ("dict") instead of the Foundation class name (bead oo-qps.49). — upstream `Core/ResourceManager.m:687,704` ↔ port `Core/ResourceManager.cpp:924,940`
- ⚠️ **low** — `logPaths` drops `-stringByStandardizingPath` and keeps only the home→`~` abbreviation (bead oo-qps.49). The stated reason, that the paths are already standard, is not quite true of the Windows extract root `../AddOns` (ResourcePaths.hpp:202), though GNUstep left a leading `..` alone anyway. — upstream `Core/ResourceManager.m:1982` ↔ port `Core/ResourceManager.cpp:735-751`
- ⚠️ **low** — `builtInPath`: the macOS `[[NSBundle mainBundle] resourcePath]` branch is not reproduced (ResourcePaths.hpp:41, ADR-0017). The Windows/Linux rule is the same: `<cwd>/Resources`, falling back to the standardized `<cwd>/../share/oolite/Resources`. — upstream `Core/ResourceManager.m:192-210` ↔ port `Core/ResourceManager.cpp:445` (oofnd/ResourcePaths.hpp:224-230)
- ✅ **Search-path order (verified)** — The search path is built in this order:
  1. builtIn, ManagedAddOns, each `OO_ADDITIONALADDONSDIRS` entry, `<cwd>/../share/oolite/AddOns`, `<cwd>/AddOns`, and the extract dir (ResourcePaths.hpp:233-249);
  2. what the recursive scan finds, in OS readdir order;
  3. external paths.

  Neither side sorts OXPs. The requirements filter repeats until stable, and the scenario filters run in the same order. — upstream `Core/ResourceManager.m:151-330` ↔ port `Core/ResourceManager.cpp:412-566`
- ✅ **Merging (verified)** — The merge modes match upstream:
  - **MERGE_NONE:** the last match in reverse order wins (folder before root, no `corePlist` check).
  - **MERGE_BASIC:** `addEntriesFromDictionary`.
  - **MERGE_SMART:** recurses into unequal dicts and concatenates unequal arrays.
  - **Array merge:** concatenation, with the equipment (lookup index 3) and star/nebula de-dup handlers run after each file is added, in the same order.

  The cache keys `"%@/%@ merge:%@"` and `"%@%@ merge:%@"` are identical. — upstream `Core/ResourceManager.m:1088-1295` ↔ port `Core/ResourceManager.cpp:1320-1506`
- ✅ **Resolved-paths cache (verified)** — The preload walks the paths in reverse, so the first-seen (highest-priority) path wins. `pathForFileNamed` always consults the cache, because upstream tested the cache-manager object. — upstream `Core/ResourceManager.m:332-416,1693-1741` ↔ port `Core/ResourceManager.cpp:568-642,1856-1902`
- ✅ **low** (subtle) — `maskUserNameInPathArray` with `HOME`/`USERPROFILE` unset passes `nullptr` to `oo::str::format("%s")`, where GNUstep printed "(null)". — upstream `Core/ResourceManager.m:436` ↔ port `Core/ResourceManager.cpp:662`

