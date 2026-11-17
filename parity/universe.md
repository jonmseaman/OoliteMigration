# Parity findings: universe
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## GameController

<a id="gamecontroller"></a>
Upstream `src/Core/GameController.m` ↔ `Core/GameController.cpp` (902 / 822 lines)

**Status:** done — 60 rows: 28 ✅ 5 ⚠️ 3 ❌ 24 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[GameController sharedController]` (70) | `GameController::sharedController` `Core/GameController.cpp:209` (never-deleted holder; second construction raises `OOInternalInconsistencyException` `:221-225`) | ✅ |
| `-[GameController init]` (78) | `GameController::GameController` `Core/GameController.cpp:220` | ❌ |
| `-[GameController dealloc]` (101) | `GameController::~GameController` (defaulted) `Core/GameController.cpp:260`; members `_universe`/`_gameView`/strings own themselves (`Core/GameController.h:177,193`) | ✅ |
| `-[GameController isGamePaused]` (118) | `GameController::isGamePaused` `Core/GameController.cpp:262` | ✅ |
| `-[GameController setGamePaused:]` (123) | `GameController::setGamePaused` `Core/GameController.cpp:264` (same order; `PLAYER` null-guarded) | ✅ |
| `-[GameController setEcoQoS:]` (139) | `GameController::setEcoQoS` `Core/GameController.cpp:279` | ❌ |
| `-[GameController mouseInteractionMode]` (162) | `GameController::mouseInteractionMode` `Core/GameController.cpp:322` | ✅ |
| `-[GameController setMouseInteractionMode:]` (167) | `GameController::setMouseInteractionMode` `Core/GameController.cpp:326` (same log class/text; fullscreen-controller branch is Mac-only) | ✅ |
| `-[GameController setMouseInteractionModeForFlight]` (186) | `GameController::setMouseInteractionModeForFlight` `Core/GameController.cpp:342` (nil PLAYER → NO, as nil messaging) | ✅ |
| `-[GameController setMouseInteractionModeForUIWithMouseInteraction:]` (191) | `GameController::setMouseInteractionModeForUIWithMouseInteraction` `Core/GameController.cpp:349` | ✅ |
| `-[GameController gameView]` (196) | `GameController::gameView` `Core/GameController.cpp:356` | ✅ |
| `-[GameController setGameView:]` (201) | `GameController::setGameView` `Core/GameController.cpp:358` | ✅ |
| `-[GameController applicationDidFinishLaunching:]` (209) | `GameController::applicationDidFinishLaunching` `Core/GameController.cpp:524` (+ `runFrameLoop` `:463`) | ⚠️ |
| `-[GameController finishedLaunching]` (283) | `GameController::finishedLaunching` `Core/GameController.cpp:364` | ✅ |
| `-[GameController loadPlayerIfRequired]` (288) | `GameController::loadPlayerIfRequired` `Core/GameController.cpp:595` (copies the path before load; same calls/order) | ✅ |
| `-[GameController beginSplashScreen]` (300) | `GameController::beginSplashScreen` `Core/GameController.cpp:610` | ⚠️ |
| `-[GameController performGameTick:]` (316) | removed: Mac Cocoa variant; the port is SDL-only (`#error Unknown environment!` `Core/GameController.cpp:624-626`) | ➖ |
| `-[GameController performGameTick:]` (324) | `GameController::performGameTick` `Core/GameController.cpp:375` (pool, pollControls, doPerformGameTick) | ✅ |
| `-[GameController doPerformGameTick]` (336) | `GameController::doPerformGameTick` `Core/GameController.cpp:382` | ❌ |
| `-[GameController startAnimationTimer]` (369) | `GameController::startAnimationTimer` `Core/GameController.cpp:420` (+ `performGameTickIfDue` `:440`) | ⚠️ |
| `-[GameController stopAnimationTimer]` (384) | `GameController::stopAnimationTimer` `Core/GameController.cpp:438` | ⚠️ |
| `-[GameController recenterVirtualJoystick]` (395) | removed: Mac-only; no counterpart in `src/` (grep) | ➖ |
| `-[GameController showLogAction:]` (402) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController showLogFolderAction:]` (407) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `GetPreference` (413) | removed: Mac-only helper; no counterpart in `src/` | ➖ |
| `SetPreference` (422) | removed: Mac-only helper; no counterpart in `src/` | ➖ |
| `RemovePreference` (427) | removed: Mac-only helper; no counterpart in `src/` | ➖ |
| `-[GameController snapshotsURLCreatingIfNeeded:]` (435) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController showSnapshotsAction:]` (497) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController showAddOnsAction:]` (502) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController isDirectoryAtPath:]` (530) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController addOnsExistAtPath:]` (536) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController openPath:]` (552) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController validateMenuItem:]` (557) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController applicationDockMenu:]` (592) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController snapshotsURLCreatingIfNeeded:]` (599) | removed: SDL variant had no caller upstream either; no counterpart in `src/` | ➖ |
| `-[GameController logProgress:]` (617) | `GameController::logProgress` `Core/GameController.cpp:628` (same `doingStartUp` gate, class `startup.progress`, `%.2f`) | ✅ |
| `-[GameController debugMessageTrackingIsOn]` (633) | removed: Mac-only variant | ➖ |
| `-[GameController debugMessageCurrentString]` (638) | removed: Mac-only variant | ➖ |
| `-[GameController debugMessageTrackingIsOn]` (643) | `GameController::debugMessageTrackingIsOn` `Core/GameController.cpp:639` | ✅ |
| `-[GameController debugMessageCurrentString]` (648) | `GameController::debugMessageCurrentString` `Core/GameController.cpp:643` | ✅ |
| `-[GameController debugLogProgress:]` (654) | `GameController::debugLogProgress(const std::string&)` `Core/GameController.cpp:645` (callers pre-format; `OO_DEBUG_PROGRESS` `Core/GameController.h:256`) | ✅ |
| `-[GameController debugLogProgress:arguments:]` (662) | folded into `debugLogProgress` `Core/GameController.cpp:645` | ➖ |
| `-[GameController debugPushProgressMessage:]` (670) | `GameController::debugPushProgressMessage` `Core/GameController.cpp:653` (push current string, log, `indentIf` unconditionally) | ✅ |
| `-[GameController debugPopProgressMessage]` (686) | `GameController::debugPopProgressMessage` `Core/GameController.cpp:662` | ✅ |
| `-[GameController endSplashScreen]` (700) | `GameController::endSplashScreen` `Core/GameController.cpp:674` | ✅ |
| `-[GameController awakeFromNib]` (720) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController application:openFile:]` (735) | removed: Mac-only; `expansionPathsToInclude` is still read at `Core/GameController.cpp:553` | ➖ |
| `-[GameController exitAppWithContext:]` (756) | removed: Mac-only variant | ➖ |
| `-[GameController applicationShouldTerminate:]` (763) | removed: Mac-only; no counterpart in `src/` | ➖ |
| `-[GameController exitAppWithContext:]` (773) | `GameController::exitAppWithContext` `Core/GameController.cpp:683` | ⚠️ |
| `-[GameController exitAppCommandQ]` (799) | `GameController::exitAppCommandQ` `Core/GameController.cpp:717` | ✅ |
| `-[GameController windowDidResize:]` (804) | `GameController::windowDidResize` `Core/GameController.cpp:719` | ✅ |
| `-[GameController playerFileToLoad]` (809) | `GameController::playerFileToLoad` `Core/GameController.cpp:723` | ✅ |
| `-[GameController setPlayerFileToLoad:]` (814) | `GameController::setPlayerFileToLoad` `Core/GameController.cpp:727` (lowercased extension `oolite-save`, else cleared) | ✅ |
| `-[GameController playerFileDirectory]` (823) | `GameController::playerFileDirectory` `Core/GameController.cpp:736` (inlines `-defaultCommanderPath`, same log classes/texts as `NSFileManagerOOExtensions.m:97,104`) | ✅ |
| `-[GameController setPlayerFileDirectory:]` (839) | `GameController::setPlayerFileDirectory` `Core/GameController.cpp:776` (nil → key removed, as `setObject:nil`) | ✅ |
| `-[GameController reportUnhandledStartupException:]` (854) | `GameController::reportUnhandledStartupExceptionName` `Core/GameController.cpp:791` | ✅ |
| `-[GameController suppressClangStuff]` (869) | `GameController::suppressClangStuff` `Core/GameController.cpp:370` | ✅ |
| `SetUpSparkle` (879) | removed: Mac-only; no counterpart in `src/` | ➖ |

**Differences:**

- ❌ **med** (still open) — `animation_timer_interval` uses `object(k).isNull() ? MINIMUM_ANIMATION_TICK : doubleForKey(k)`. Upstream `OODoubleFromObject` falls back to the default for a non-numeric string (`"fast"`, `""`) and for array/dict values (`OOCollectionExtractors.m:1189-1198`). `oo::Defaults::doubleForKey` gives 0.0 for those (`oofnd/Defaults.hpp:509-514,190`). `startAnimationTimer` clamps 0 to 0.0001 s, so the tick runs at 10 kHz instead of 240 Hz and the loop spins — upstream `Core/GameController.m:89` ↔ port `Core/GameController.cpp:235-238,427`
- ❌ **low** (still open) — `ecoqos` uses the same `isNull() ? true : boolForKey()` pattern. Upstream `BooleanFromString` reads `"on"` and `"0.5"` as YES, and an unrecognised string or a non-scalar as the default YES (`OOCollectionExtractors.m:1098-1108,1131-1136`). `stringBoolValue` gives NO for all of these (`oofnd/Defaults.hpp:101-109,495-500`), so pausing skips IDLE priority and power throttling — upstream `Core/GameController.m:142` ↔ port `Core/GameController.cpp:291-293`
- ❌ **med** (still open; the previous run graded this ⚠️ low) — `doPerformGameTick` catches only `oo::Exception`, and the `updateScreen` catch rethrows anything else. A `std::out_of_range` (port code calls `.at(` 86 times in `Core/`) or a `std::bad_alloc` thrown in `UNIVERSE->update` escapes `runFrameLoop` and is rethrown from `SDL/main.cpp:311-313` to `std::terminate`. Upstream `@catch (id)` logged the exception and carried on. The comment's premise ("the game throws only oo::Exception") no longer names a bead or ADR — upstream `Core/GameController.m:338-366` ↔ port `Core/GameController.cpp:404-417`
- ⚠️ **low** (still open) — `OO_RANDOM_SEED` env seeds RANROT and logs `rand.seed`; when unset, the seed is wall-clock as before (the comment says component tests depend on it) — upstream `Core/GameController.m:93` ↔ port `Core/GameController.cpp:243-254`
- ⚠️ **low** (still open) — `last_timeInterval` and `_splashStart` use a monotonic clock (comment "the frame clock: intervals only"), so a wall-clock step back no longer gives a negative `delta_t` — upstream `Core/GameController.m:87,95,342` ↔ port `Core/GameController.cpp:229-231,256,387`
- ⚠️ **low** (still open) — `setEcoQoS(true)` returns early while a debug console is waiting for input (comment gives measured rationale) — upstream `Core/GameController.m:139-160` ↔ port `Core/GameController.cpp:281-290`
- ⚠️ **med** (still open) — The run loop plus the `NSTimer` became `runFrameLoop` with a steady_clock deadline (block comment at `:81-99`). Late ticks skip and never burst, an interval ≤ 0 is clamped to 0.0001 s, and waits are a whole-ms `Sleep`. Each pass runs the tick, the log flush, ≤2 deferred calls and then the OXZ download events, or services the debug-console socket instead — upstream `Core/GameController.m:279,369-391` ↔ port `Core/GameController.cpp:420-522,592`
- ⚠️ **low** (still open) — `beginSplashScreen` resets `_gameView` to null when `init()` fails, instead of keeping a dangling pointer (comment) — upstream `Core/GameController.m:303-308` ↔ port `Core/GameController.cpp:611-621`
- ⚠️ **low** (new) — The SDL `exitAppWithContext` adds `OOAsyncWorkManager::shutdown()`, which joins the work threads, before the defaults sync. Debug builds also call `OOJavaScriptEngine::shutDown()` (leak check) before `OOLoggingTerminate`, so they may log extra lines at exit. Both are commented. The rest of the order is unchanged — upstream `Core/GameController.m:773-793` ↔ port `Core/GameController.cpp:696-705`
- ➖ (new) — All of the `OOLITE_MAC_COCOA_UI` code was deleted. The previous run counted it ✅ as "not built". That covers the Cocoa `performGameTick:`, the menu, dock and NIB actions, `Get/Set/RemovePreference`, the snapshot and add-on helpers, `applicationShouldTerminate:` and the Mac `exitAppWithContext:`. The port is SDL-only (`#error` `Core/GameController.cpp:624-626`), and `grep` finds none of these in `src/` — upstream `Core/GameController.m:314-320,393-595,632-641,717-768`
- ➖ (no longer applicable since 2026-10-27) — The previous `use-test-release-updates` ❌ low on `SetUpSparkle` lapses: the function is deleted together with the Mac code — upstream `Core/GameController.m:879-900`
- ➖ (still open) — The SDL `snapshotsURLCreatingIfNeeded:` has gone; upstream had no SDL caller. `debugLogProgress:arguments:` is folded into the pre-formatted `debugLogProgress` — upstream `Core/GameController.m:599-611,662-666` ↔ port `Core/GameController.cpp:645`
- Subtle (✅) — Pause and resume keep their order: the mouse mode is saved, then ecoQoS, the flag and the `gamePaused`/`gameResumed` events, with PLAYER null-guarded. A paused tick has `delta_t = 0` and skips the frame callbacks. Port `Core/GameController.cpp:264-277,384-403`
- Subtle (✅) — The startup order is unchanged, and so is the `startup.complete` log format. A startup exception that is not an `oo::Exception` is rethrown, where upstream caught only `NSException`. The fullscreen-controller block is Mac-only. Port `Core/GameController.cpp:524-593`

## Universe

<a id="universe"></a>
Upstream `src/Core/Universe.m` ↔ `Core/Universe.cpp` (10164 / 11827 lines)

**Status:** done — 374 rows: 347 ✅ 10 ⚠️ 11 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| file-level `enum DEMO_*`, `#define DEMO2_*`, `MAX_NUMBER_OF_ENTITIES`, `STANDARD_STATION_ROLL`, `LANE_WIDTH` (101-112) *(added)* | same constants `Core/Universe.cpp:116-126` | ✅ |
| log-class constants `kOOLogUniversePopulate*`, `kOOLogEntityVerification*` (114-117) *(added)* | `Core/Universe.cpp:128-138` (verification pair `#ifndef NDEBUG`) | ✅ |
| `framebufferQuadVertices` / `framebufferQuadIndices` (119-129) *(added)* | `Core/Universe.cpp:140-150` | ✅ |
| `gSharedUniverse`, `gOOJSPlayerIfStale`, forward decls (131-140) *(added)* | `Core/Universe.cpp:152-159` | ✅ |
| statics `JSResetFlags`, `object_light_on`, `demo_light_on`, `sun_off`, `demo_light_position`, `DOCKED_*`, `docked_light_*`, `SUN_AMBIENT_INFLUENCE`, `SKY_AMBIENT_ADJUSTMENT` (264-283) *(added)* | `Core/Universe.cpp:513-536` | ✅ |
| `+[RouteElement elementWithLocation:parent:cost:distance:time:jumps:]` (164) | `RouteElement::elementWithLocation` `Core/Universe.cpp:8719` | ✅ |
| `-[RouteElement parent]` (178) | `RouteElement::parent` `Core/Universe.cpp:8734` | ✅ |
| `-[RouteElement location]` (182) | `RouteElement::location` `Core/Universe.cpp:8735` | ✅ |
| `-[RouteElement cost]` (186) | `RouteElement::cost` `Core/Universe.cpp:8736` | ✅ |
| `-[RouteElement distance]` (190) | `RouteElement::distance` `Core/Universe.cpp:8737` | ✅ |
| `-[RouteElement time]` (194) | `RouteElement::time` `Core/Universe.cpp:8738` | ✅ |
| `-[RouteElement jumps]` (198) | `RouteElement::jumps` `Core/Universe.cpp:8739` | ✅ |
| `-[Universe bloom]` (284) | `Universe::bloom` `Core/Universe.cpp:11301` | ✅ |
| `-[Universe setBloom:]` (289) | `Universe::setBloom` `Core/Universe.cpp:11305` | ✅ |
| `-[Universe currentPostFX]` (294) | `Universe::currentPostFX` `Core/Universe.cpp:11307` | ✅ |
| `-[Universe setCurrentPostFX:]` (299) | `Universe::setCurrentPostFX` `Core/Universe.cpp:11309` | ✅ |
| `-[Universe terminatePostFX:]` (312) | `Universe::terminatePostFX` `Core/Universe.cpp:11322` | ✅ |
| `-[Universe nextColorblindMode:]` (319) | `Universe::nextColorblindMode` `Core/Universe.cpp:11328` | ✅ |
| `-[Universe prevColorblindMode:]` (327) | `Universe::prevColorblindMode` `Core/Universe.cpp:11334` | ✅ |
| `-[Universe colorblindMode]` (335) | `Universe::colorblindMode` `Core/Universe.cpp:11340` | ✅ |
| `-[Universe initTargetFramebufferWithViewSize:]` (340) | `Universe::initTargetFramebufferWithViewSize` `Core/Universe.cpp:11342` (new `OO_MSAA_COLOR_RENDERBUFFER` arm mirrored) | ✅ |
| `-[Universe deleteOpenGLObjects]` (529) | `Universe::deleteOpenGLObjects` `Core/Universe.cpp:11576` (renderbuffer arm mirrored) | ✅ |
| `-[Universe resizeTargetFramebufferWithViewSize:]` (553) | `Universe::resizeTargetFramebufferWithViewSize` `Core/Universe.cpp:11599` (renderbuffer arm mirrored) | ✅ |
| `-[Universe drawTargetTextureIntoDefaultFramebuffer]` (598) | `Universe::drawTargetTextureIntoDefaultFramebuffer` `Core/Universe.cpp:11658` | ❌ |
| `-[Universe initWithGameView:]` (692) | `Universe::newUniverse` `Core/Universe.cpp:265` + `Universe::initWithGameView` `Core/Universe.cpp:287` | ❌ |
| `-[Universe dealloc]` (858) | `Universe::~Universe` `Core/Universe.cpp:262` → `Universe::dealloc` `Core/Universe.cpp:453` | ✅ |
| `-[Universe sessionID]` (922) | `Universe::sessionID` `Core/Universe.cpp:11769` | ✅ |
| `-[Universe doingStartUp]` (927) | `Universe::doingStartUp` `Core/Universe.cpp:11771` | ✅ |
| `-[Universe doProcedurallyTexturedPlanets]` (932) | `Universe::getDoProcedurallyTexturedPlanets` `Core/Universe.cpp:11773` | ✅ |
| `-[Universe setDoProcedurallyTexturedPlanets:]` (937) | `Universe::setDoProcedurallyTexturedPlanets` `Core/Universe.cpp:11777` | ✅ |
| `-[Universe useAddOns]` (943) | `Universe::getUseAddOns` `Core/Universe.cpp:11783` | ✅ |
| `-[Universe setUseAddOns:fromSaveGame:]` (948) | `Universe::setUseAddOns(newUse, saveGame)` `Core/Universe.cpp:11785` | ✅ |
| `-[Universe setUseAddOns:fromSaveGame:forceReinit:]` (953) | `Universe::setUseAddOns(newUse, saveGame, force)` `Core/Universe.cpp:11789` | ✅ |
| `-[Universe entityCount]` (964) | `Universe::entityCount` `Core/Universe.cpp:11799` | ✅ |
| `-[Universe debugDumpEntities]` (970) | `Universe::debugDumpEntities` `Core/Universe.cpp:11802` | ✅ |
| `-[Universe entityList]` (991) | `Universe::entityList` `Core/Universe.cpp:11826` | ✅ |
| `-[Universe pauseGame]` (997) | `Universe::pauseGame` `Core/Universe.cpp:1278` | ✅ |
| `-[Universe quitGame]` (1024) | `Universe::quitGame` `Core/Universe.cpp:1318` | ✅ |
| `-[Universe carryPlayerOn:inWormhole:]` (1030) | `Universe::carryPlayerOn` `Core/Universe.cpp:1324` | ✅ |
| `-[Universe setUpUniverseFromStation]` (1088) | `Universe::setUpUniverseFromStation` `Core/Universe.cpp:1411` | ✅ |
| `-[Universe setUpUniverseFromWitchspace]` (1162) | `Universe::setUpUniverseFromWitchspace` `Core/Universe.cpp:1511` | ✅ |
| `-[Universe setUpUniverseFromMisjump]` (1198) | `Universe::setUpUniverseFromMisjump` `Core/Universe.cpp:1556` | ✅ |
| `-[Universe setUpWitchspace]` (1229) | `Universe::setUpWitchspace` `Core/Universe.cpp:1588` | ✅ |
| `-[Universe setUpWitchspaceBetweenSystem:andSystem:]` (1234) | `Universe::setUpWitchspaceBetweenSystem` `Core/Universe.cpp:1594` | ✅ |
| `-[Universe setUpPlanet]` (1298) | `Universe::setUpPlanet` `Core/Universe.cpp:1678` | ✅ |
| `-[Universe setUpSpace]` (1334) | `Universe::setUpSpace` `Core/Universe.cpp:1737` | ✅ |
| `-[Universe populateNormalSpace]` (1622) | `Universe::populateNormalSpace` `Core/Universe.cpp:2123` | ✅ |
| `-[Universe clearSystemPopulator]` (1682) | `Universe::clearSystemPopulator` `Core/Universe.cpp:2197` | ✅ |
| `-[Universe getPopulatorSettings]` (1688) | `Universe::getPopulatorSettings` `Core/Universe.cpp:2201` | ✅ |
| `-[Universe setPopulatorSetting:to:]` (1693) | `Universe::setPopulatorSetting` `Core/Universe.cpp:2203` | ✅ |
| `-[Universe deterministicPopulation]` (1702) | `Universe::deterministicPopulation` `Core/Universe.cpp:2215` | ✅ |
| `-[Universe populateSystemFromDictionariesWithSun:andPlanet:]` (1707) | `Universe::populateSystemFromDictionariesWithSun` `Core/Universe.cpp:2217` | ⚠️ |
| `-[Universe locationByCode:withSun:andPlanet:]` (1783) | `Universe::locationByCode` `Core/Universe.cpp:2306` | ✅ |
| `-[Universe setAmbientLightLevel:]` (1866) | `Universe::setAmbientLightLevel` `Core/Universe.cpp:2483` | ✅ |
| `-[Universe ambientLightLevel]` (1874) | `Universe::getAmbientLightLevel` `Core/Universe.cpp:2492` | ✅ |
| `-[Universe setLighting]` (1879) | `Universe::setLighting` `Core/Universe.cpp:2494` | ✅ |
| `-[Universe forceLightSwitch]` (1960) | `Universe::forceLightSwitch` `Core/Universe.cpp:2590` | ✅ |
| `-[Universe setMainLightPosition:]` (1965) | `Universe::setMainLightPosition` `Core/Universe.cpp:2592` | ✅ |
| `-[Universe addShipWithRole:launchPos:rfactor:]` (1973) | `Universe::addShipWithRole(desc, launchPos, rfactor)` `Core/Universe.cpp:2599` | ✅ |
| `-[Universe addShipWithRole:nearRouteOneAt:]` (2007) | `Universe::addShipWithRole(desc, route_fraction)` `Core/Universe.cpp:2641` | ✅ |
| `-[Universe coordinatesForPosition:withCoordinateSystem:returningScalar:]` (2021) | `Universe::coordinatesForPosition` `Core/Universe.cpp:2655` | ✅ |
| `-[Universe expressPosition:inCoordinateSystem:]` (2163) | `Universe::expressPosition` `Core/Universe.cpp:2801` | ✅ |
| `-[Universe legacyPositionFrom:asCoordinateSystem:]` (2169) | `Universe::legacyPositionFrom` `Core/Universe.cpp:2811` | ✅ |
| `-[Universe coordinatesFromCoordinateSystemString:]` (2273) | `Universe::coordinatesFromCoordinateSystemString` `Core/Universe.cpp:2918` | ✅ |
| `-[Universe addShipWithRole:nearPosition:withCoordinateSystem:]` (2284) | `Universe::addShipWithRole(desc, pos, system)` `Core/Universe.cpp:2936` | ✅ |
| `-[Universe addShips:withRole:atPosition:withCoordinateSystem:]` (2299) | `Universe::addShipsAtPosition` `Core/Universe.cpp:2949` | ❌ |
| `-[Universe addShips:withRole:nearPosition:withCoordinateSystem:]` (2373) | `Universe::addShipsNearPosition(4 args)` `Core/Universe.cpp:3032` | ✅ |
| `-[Universe addShips:withRole:nearPosition:withCoordinateSystem:withinRadius:]` (2390) | `Universe::addShipsNearPosition(5 args)` `Core/Universe.cpp:3050` | ✅ |
| `-[Universe addShips:withRole:intoBoundingBox:]` (2405) | `Universe::addShips` `Core/Universe.cpp:3068` | ✅ |
| `-[Universe spawnShip:]` (2447) | `Universe::spawnShip` `Core/Universe.cpp:3109` | ✅ |
| `-[Universe witchspaceShipWithPrimaryRole:]` (2517) | `Universe::witchspaceShipWithPrimaryRole` `Core/Universe.cpp:3194` | ✅ |
| `-[Universe spawnShipWithRole:near:]` (2568) | `Universe::spawnShipWithRole` `Core/Universe.cpp:3261` | ✅ |
| `-[Universe addVisualEffectAt:withKey:]` (2587) | `Universe::addVisualEffectAt` `Core/Universe.cpp:3282` | ✅ |
| `-[Universe addShipAt:withRole:withinRadius:]` (2608) | `Universe::addShipAt` `Core/Universe.cpp:3306` | ✅ |
| `-[Universe addShipsAt:withRole:quantity:withinRadius:asGroup:]` (2698) | `Universe::addShipsAt` `Core/Universe.cpp:3415` | ✅ |
| `-[Universe addShipsToRoute:withRole:quantity:routeFraction:asGroup:]` (2728) | `Universe::addShipsToRoute` `Core/Universe.cpp:3446` | ✅ |
| `-[Universe roleIsPirateVictim:]` (2803) | `Universe::roleIsPirateVictim` `Core/Universe.cpp:3524` | ✅ |
| `-[Universe role:isInCategory:]` (2808) | `Universe::role` `Core/Universe.cpp:3528` | ✅ |
| `-[Universe forceWitchspaceEntries]` (2818) | `Universe::forceWitchspaceEntries` `Core/Universe.cpp:3543` | ✅ |
| `-[Universe addWitchspaceJumpEffectForShip:]` (2834) | `Universe::addWitchspaceJumpEffectForShip` `Core/Universe.cpp:3562` | ✅ |
| `-[Universe safeWitchspaceExitDistance]` (2843) | `Universe::safeWitchspaceExitDistance` `Core/Universe.cpp:3574` | ✅ |
| `-[Universe setUpBreakPattern:orientation:forDocking:]` (2854) | `Universe::setUpBreakPattern` `Core/Universe.cpp:3589` | ✅ |
| `-[Universe witchspaceBreakPattern]` (2926) | `Universe::witchspaceBreakPattern` `Core/Universe.cpp:3685` | ✅ |
| `-[Universe setWitchspaceBreakPattern:]` (2931) | `Universe::setWitchspaceBreakPattern` `Core/Universe.cpp:3687` | ✅ |
| `-[Universe dockingClearanceProtocolActive]` (2936) | `Universe::dockingClearanceProtocolActive` `Core/Universe.cpp:3691` | ✅ |
| `-[Universe setDockingClearanceProtocolActive:]` (2941) | `Universe::setDockingClearanceProtocolActive` `Core/Universe.cpp:3695` | ❌ |
| `-[Universe handleGameOver]` (2961) | `Universe::handleGameOver` `Core/Universe.cpp:3722` | ✅ |
| `-[Universe setupIntroFirstGo:]` (2970) | `Universe::setupIntroFirstGo` `Core/Universe.cpp:3735` | ✅ |
| `-[Universe demoShipData]` (3057) | `Universe::demoShipData` `Core/Universe.cpp:3843` | ✅ |
| `-[Universe setLibraryTextForDemoShip]` (3062) | `Universe::setLibraryTextForDemoShip` `Core/Universe.cpp:3847` | ❌ |
| `-[Universe selectIntro2Previous]` (3261) | `Universe::selectIntro2Previous` `Core/Universe.cpp:4078` | ✅ |
| `-[Universe selectIntro2PreviousCategory]` (3269) | `Universe::selectIntro2PreviousCategory` `Core/Universe.cpp:4085` | ✅ |
| `-[Universe selectIntro2NextCategory]` (3277) | `Universe::selectIntro2NextCategory` `Core/Universe.cpp:4093` | ✅ |
| `-[Universe selectIntro2Next]` (3285) | `Universe::selectIntro2Next` `Core/Universe.cpp:4100` | ✅ |
| `IsCandidateMainStationPredicate` (3291) | `IsCandidateMainStationPredicate` `Core/Universe.cpp:601` | ✅ |
| `IsFriendlyStationPredicate` (3296) | `IsFriendlyStationPredicate` `Core/Universe.cpp:606` | ✅ |
| `-[Universe station]` (3301) | `Universe::station` `Core/Universe.cpp:4105` | ✅ |
| `-[Universe stationWithRole:andPosition:]` (3310) | `Universe::stationWithRole` `Core/Universe.cpp:4113` | ✅ |
| `-[Universe stationFriendlyTo:]` (3330) | `Universe::stationFriendlyTo` `Core/Universe.cpp:4137` | ✅ |
| `-[Universe planet]` (3337) | `Universe::planet` `Core/Universe.cpp:4144` | ✅ |
| `-[Universe sun]` (3345) | `Universe::sun` `Core/Universe.cpp:4152` | ✅ |
| `-[Universe planets]` (3353) | `Universe::planets` `Core/Universe.cpp:4160` | ✅ |
| `-[Universe stations]` (3358) | `Universe::stations` `Core/Universe.cpp:4162` | ❌ |
| `-[Universe wormholes]` (3363) | `Universe::wormholes` `Core/Universe.cpp:4167` | ✅ |
| `-[Universe unMagicMainStation]` (3368) | `Universe::unMagicMainStation` `Core/Universe.cpp:4169` | ✅ |
| `-[Universe resetBeacons]` (3389) | `Universe::resetBeacons` `Core/Universe.cpp:4190` | ✅ |
| `-[Universe firstBeacon]` (3403) | `Universe::firstBeacon` `Core/Universe.cpp:4203` | ✅ |
| `-[Universe setFirstBeacon:]` (3408) | `Universe::setFirstBeacon` `Core/Universe.cpp:4208` | ✅ |
| `-[Universe lastBeacon]` (3419) | `Universe::lastBeacon` `Core/Universe.cpp:4218` | ✅ |
| `-[Universe setLastBeacon:]` (3424) | `Universe::setLastBeacon` `Core/Universe.cpp:4220` | ✅ |
| `-[Universe setNextBeacon:]` (3435) | `Universe::setNextBeacon` `Core/Universe.cpp:4229` | ✅ |
| `-[Universe clearBeacon:]` (3446) | `Universe::clearBeacon` `Core/Universe.cpp:4242` | ✅ |
| `-[Universe currentWaypoints]` (3467) | `Universe::currentWaypoints` `Core/Universe.cpp:4265` | ✅ |
| `-[Universe defineWaypoint:forKey:]` (3472) | `Universe::defineWaypoint` `Core/Universe.cpp:4269` | ✅ |
| `-[Universe skyClearColor]` (3497) | `Universe::getSkyClearColor` `Core/Universe.cpp:4297` | ✅ |
| `-[Universe setSkyColorRed:green:blue:alpha:]` (3502) | `Universe::setSkyColorRed` `Core/Universe.cpp:4299` | ✅ |
| `-[Universe breakPatternOver]` (3511) | `Universe::breakPatternOver` `Core/Universe.cpp:4308` | ✅ |
| `-[Universe breakPatternHide]` (3516) | `Universe::breakPatternHide` `Core/Universe.cpp:4310` | ✅ |
| `-[Universe canInstantiateShip:]` (3524) | `Universe::canInstantiateShip` `Core/Universe.cpp:4316` | ✅ |
| `-[Universe randomShipKeyForRoleRespectingConditions:]` (3572) | `Universe::randomShipKeyForRoleRespectingConditions` `Core/Universe.cpp:4361` | ❌ |
| `-[Universe newShipWithRole:]` (3623) | `Universe::newShipWithRole` `Core/Universe.cpp:4427` | ✅ |
| `-[Universe newVisualEffectWithName:]` (3668) | `Universe::newVisualEffectWithName` `Core/Universe.cpp:4481` | ✅ |
| `-[Universe newSubentityWithName:andScaleFactor:]` (3694) | `Universe::newSubentityWithName` `Core/Universe.cpp:4511` | ✅ |
| `-[Universe newShipWithName:usePlayerProxy:]` (3699) | `Universe::newShipWithName(key, proxy)` `Core/Universe.cpp:4516` | ✅ |
| `-[Universe newShipWithName:usePlayerProxy:isSubentity:]` (3704) | `Universe::newShipWithName(key, proxy, sub)` `Core/Universe.cpp:4521` | ✅ |
| `-[Universe newShipWithName:usePlayerProxy:isSubentity:andScaleFactor:]` (3709) | `Universe::newShipWithName(key, proxy, sub, scale)` `Core/Universe.cpp:4526` | ✅ |
| `-[Universe newDockWithName:andScaleFactor:]` (3756) | `Universe::newDockWithName` `Core/Universe.cpp:4584` | ✅ |
| `-[Universe newShipWithName:]` (3793) | `Universe::newShipWithName(key)` `Core/Universe.cpp:4625` | ✅ |
| `-[Universe shipClassForShipDictionary:]` (3798) | `Universe::isStationShipDictionary` `Core/Universe.cpp:4630` | ⚠️ |
| `-[Universe defaultAIForRole:]` (3822) | `Universe::defaultAIForRole` `Core/Universe.cpp:4652` | ✅ |
| `-[Universe maxCargoForShip:]` (3827) | `Universe::maxCargoForShip` `Core/Universe.cpp:4656` | ✅ |
| `-[Universe getEquipmentPriceForKey:]` (3835) | `Universe::getEquipmentPriceForKey` `Core/Universe.cpp:4668` | ✅ |
| `-[Universe commodities]` (3848) | `Universe::getCommodities` `Core/Universe.cpp:4682` | ✅ |
| `-[Universe reifyCargoPod:]` (3854) | `Universe::reifyCargoPod` `Core/Universe.cpp:4685` | ✅ |
| `-[Universe cargoPodFromTemplate:]` (3863) | `Universe::cargoPodFromTemplate` `Core/Universe.cpp:4694` | ✅ |
| `-[Universe getContainersOfGoods:scarce:legal:]` (3880) | `Universe::getContainersOfGoods` `Core/Universe.cpp:4723` | ✅ |
| `-[Universe getContainersOfCommodity:how_much:]` (3940) | `Universe::getContainersOfCommodity` `Core/Universe.cpp:4801` | ✅ |
| `-[Universe fillCargopodWithRandomCargo:]` (3960) | `Universe::fillCargopodWithRandomCargo` `Core/Universe.cpp:4827` | ✅ |
| `-[Universe getRandomCommodity]` (3972) | `Universe::getRandomCommodity` `Core/Universe.cpp:4844` | ✅ |
| `-[Universe getRandomAmountOfCommodity:]` (3977) | `Universe::getRandomAmountOfCommodity` `Core/Universe.cpp:4849` | ❌ |
| `-[Universe commodityDataForType:]` (3998) | `Universe::commodityDataForType` `Core/Universe.cpp:4872` | ✅ |
| `-[Universe displayNameForCommodity:]` (4003) | `Universe::displayNameForCommodity` `Core/Universe.cpp:4877` | ✅ |
| `-[Universe describeCommodity:amount:]` (4008) | `Universe::describeCommodity` `Core/Universe.cpp:4883` | ✅ |
| `-[Universe setGameView:]` (4053) | `Universe::setGameView` `Core/Universe.cpp:4932` | ✅ |
| `-[Universe gameView]` (4059) | `Universe::getGameView` `Core/Universe.cpp:4934` | ✅ |
| `-[Universe gameController]` (4064) | `Universe::gameController` `Core/Universe.cpp:4936` | ✅ |
| `-[Universe gameSettings]` (4069) | `Universe::gameSettings` `Core/Universe.cpp:4944` | ✅ |
| `-[Universe useGUILightSource:]` (4124) | `Universe::useGUILightSource` `Core/Universe.cpp:5008` | ✅ |
| `-[Universe lightForEntity:]` (4149) | `Universe::lightForEntity` `Core/Universe.cpp:5034` | ✅ |
| static `fwd_/aft_/port_/starboard_matrix` (4181) *(added: missed by extractor)* | same statics `Core/Universe.cpp:618-633` | ✅ |
| `-[Universe getActiveViewMatrix:forwardVector:upVector:]` (4198) | `Universe::getActiveViewMatrix` `Core/Universe.cpp:5064` | ✅ |
| `-[Universe activeViewMatrix]` (4241) | `Universe::activeViewMatrix` `Core/Universe.cpp:5112` | ✅ |
| `-[Universe defineFrustum]` (4255) | `Universe::defineFrustum` `Core/Universe.cpp:5129` | ✅ |
| `-[Universe viewFrustumIntersectsSphereAt:withRadius:]` (4341) | `Universe::viewFrustumIntersectsSphereAt` `Core/Universe.cpp:5224` | ✅ |
| `-[Universe drawUniverse]` (4353) | `Universe::drawUniverse` `Core/Universe.cpp:5239` | ✅ |
| `-[Universe prepareToRenderIntoDefaultFramebuffer]` (4782) | `Universe::prepareToRenderIntoDefaultFramebuffer` `Core/Universe.cpp:5750` | ✅ |
| `-[Universe framesDoneThisUpdate]` (4795) | `Universe::getFramesDoneThisUpdate` `Core/Universe.cpp:5767` | ✅ |
| `-[Universe resetFramesDoneThisUpdate]` (4800) | `Universe::resetFramesDoneThisUpdate` `Core/Universe.cpp:5769` | ✅ |
| `-[Universe viewMatrix]` (4805) | `Universe::getViewMatrix` `Core/Universe.cpp:5771` | ✅ |
| `-[Universe drawMessage]` (4810) | `Universe::drawMessage` `Core/Universe.cpp:5776` | ✅ |
| `-[Universe drawWatermarkString:]` (4831) | `Universe::drawWatermarkString` `Core/Universe.cpp:5805` | ✅ |
| `-[Universe entityForUniversalID:]` (4841) | `Universe::entityForUniversalID` `Core/Universe.cpp:5821` | ✅ |
| `MaintainLinkedLists` (4867) | `MaintainLinkedLists` `Core/Universe.cpp:635` | ✅ |
| `-[Universe addEntity:]` (4990) | `Universe::addEntity` `Core/Universe.cpp:5848` | ✅ |
| `-[Universe removeEntity:]` (5128) | `Universe::removeEntity` `Core/Universe.cpp:6000` | ✅ |
| `-[Universe ensureEntityReallyRemoved:]` (5147) | `Universe::ensureEntityReallyRemoved` `Core/Universe.cpp:6021` (log in `Entity::~Entity` `Core/Entities/Entity.cpp:118-123`) | ⚠️ |
| `-[Universe removeAllEntitiesExceptPlayer]` (5155) | `Universe::removeAllEntitiesExceptPlayer` `Core/Universe.cpp:6029` | ✅ |
| `-[Universe removeDemoShips]` (5201) | `Universe::removeDemoShips` `Core/Universe.cpp:6076` | ✅ |
| `-[Universe makeDemoShipWithRole:spinning:]` (5217) | `Universe::makeDemoShipWithRole` `Core/Universe.cpp:6094` | ✅ |
| `-[Universe isVectorClearFromEntity:toDistance:fromPoint:]` (5253) | `Universe::isVectorClearFromEntity` `Core/Universe.cpp:6136` | ✅ |
| `-[Universe hazardOnRouteFromEntity:toDistance:fromPoint:]` (5317) | `Universe::hazardOnRouteFromEntity` `Core/Universe.cpp:6202` | ✅ |
| `-[Universe getSafeVectorFromEntity:toDistance:fromPoint:]` (5379) | `Universe::getSafeVectorFromEntity` `Core/Universe.cpp:6265` | ✅ |
| `-[Universe addWreckageFrom:withRole:at:scale:lifetime:]` (5497) | `Universe::addWreckageFrom` `Core/Universe.cpp:6397` | ✅ |
| `-[Universe addLaserHitEffectsAt:against:damage:color:]` (5528) | `Universe::addLaserHitEffectsAt` `Core/Universe.cpp:6439` | ✅ |
| `-[Universe firstShipHitByLaserFromShip:inDirection:offset:gettingRangeFound:]` (5549) | `Universe::firstShipHitByLaserFromShip` `Core/Universe.cpp:6473` | ✅ |
| `-[Universe firstEntityTargetedByPlayer]` (5649) | `Universe::firstEntityTargetedByPlayer` `Core/Universe.cpp:6600` | ✅ |
| `-[Universe firstEntityTargetedByPlayerPrecisely]` (5723) | `Universe::firstEntityTargetedByPlayerPrecisely` `Core/Universe.cpp:6681` | ✅ |
| `-[Universe entitiesWithinRange:ofEntity:]` (5759) | `Universe::entitiesWithinRange` `Core/Universe.cpp:6732` | ✅ |
| `-[Universe countShipsWithRole:inRange:ofEntity:]` (5770) | `Universe::countShipsWithRole(role, range, e)` `Core/Universe.cpp:6741` | ✅ |
| `-[Universe countShipsWithRole:]` (5778) | `Universe::countShipsWithRole(role)` `Core/Universe.cpp:6748` | ✅ |
| `-[Universe countShipsWithPrimaryRole:inRange:ofEntity:]` (5783) | `Universe::countShipsWithPrimaryRole(role, range, e)` `Core/Universe.cpp:6752` | ✅ |
| `-[Universe countShipsWithScanClass:inRange:ofEntity:]` (5791) | `Universe::countShipsWithScanClass` `Core/Universe.cpp:6760` (predicate reads an `OOScanClass*`, `Core/OOEntityFilterPredicate.cpp:98`) | ✅ |
| `-[Universe countShipsWithPrimaryRole:]` (5799) | `Universe::countShipsWithPrimaryRole(role)` `Core/Universe.cpp:6766` | ✅ |
| `-[Universe countEntitiesMatchingPredicate:parameter:inRange:ofEntity:]` (5804) | `Universe::countEntitiesMatchingPredicate` `Core/Universe.cpp:6770` | ✅ |
| `-[Universe countShipsMatchingPredicate:parameter:inRange:ofEntity:]` (5839) | `Universe::countShipsMatchingPredicate` `Core/Universe.cpp:6802` | ✅ |
| `EntityInRange` (5862) | `EntityInRange` `Core/Universe.cpp:794` | ✅ |
| `-[Universe findEntitiesMatchingPredicate:parameter:inRange:ofEntity:]` (5872) | `Universe::findEntitiesMatchingPredicate` `Core/Universe.cpp:6821` | ✅ |
| `-[Universe findOneEntityMatchingPredicate:parameter:]` (5910) | `Universe::findOneEntityMatchingPredicate` `Core/Universe.cpp:6856` | ✅ |
| `-[Universe findShipsMatchingPredicate:parameter:inRange:ofEntity:]` (5932) | `Universe::findShipsMatchingPredicate` `Core/Universe.cpp:6875` | ✅ |
| `-[Universe findVisualEffectsMatchingPredicate:parameter:inRange:ofEntity:]` (5955) | `Universe::findVisualEffectsMatchingPredicate` `Core/Universe.cpp:6889` | ✅ |
| `-[Universe nearestEntityMatchingPredicate:parameter:relativeToEntity:]` (5978) | `Universe::nearestEntityMatchingPredicate` `Core/Universe.cpp:6903` | ✅ |
| `-[Universe nearestShipMatchingPredicate:parameter:relativeToEntity:]` (6008) | `Universe::nearestShipMatchingPredicate` `Core/Universe.cpp:6933` | ✅ |
| `-[Universe getTime]` (6028) | `Universe::getTime` `Core/Universe.cpp:6946` | ✅ |
| `-[Universe getTimeDelta]` (6033) | `Universe::getTimeDelta` `Core/Universe.cpp:6948` | ✅ |
| `-[Universe findCollisionsAndShadows]` (6038) | `Universe::findCollisionsAndShadows` `Core/Universe.cpp:6950` | ✅ |
| `-[Universe collisionDescription]` (6056) | `Universe::collisionDescription` `Core/Universe.cpp:6973` | ✅ |
| `-[Universe dumpCollisions]` (6064) | `Universe::dumpCollisions` `Core/Universe.cpp:6980` | ✅ |
| `-[Universe viewDirection]` (6069) | `Universe::getViewDirection` `Core/Universe.cpp:6982` | ✅ |
| `-[Universe setViewDirection:]` (6074) | `Universe::setViewDirection` `Core/Universe.cpp:6987` | ✅ |
| `-[Universe enterGUIViewModeWithMouseInteraction:]` (6138) | `Universe::enterGUIViewModeWithMouseInteraction` `Core/Universe.cpp:7057` | ✅ |
| `-[Universe soundNameForCustomSoundKey:]` (6151) | `Universe::soundNameForCustomSoundKey` `Core/Universe.cpp:7075` | ✅ |
| `-[Universe screenTextureDescriptorForKey:]` (6204) | `Universe::screenTextureDescriptorForKey` `Core/Universe.cpp:7142` | ✅ |
| `-[Universe setScreenTextureDescriptorForKey:descriptor:]` (6222) | `Universe::setScreenTextureDescriptorForKey` `Core/Universe.cpp:7165` | ✅ |
| `-[Universe clearPreviousMessage]` (6235) | `Universe::clearPreviousMessage` `Core/Universe.cpp:7176` | ✅ |
| `-[Universe setMessageGuiBackgroundColor:]` (6242) | `Universe::setMessageGuiBackgroundColor` `Core/Universe.cpp:7178` | ✅ |
| `-[Universe displayMessage:forCount:]` (6247) | `Universe::displayMessage` `Core/Universe.cpp:7183` | ✅ |
| `-[Universe displayCountdownMessage:forCount:]` (6258) | `Universe::displayCountdownMessage` `Core/Universe.cpp:7196` | ✅ |
| `-[Universe addDelayedMessage:forCount:afterDelay:]` (6269) | `Universe::addDelayedMessage(text, count, delay)` `Core/Universe.cpp:7212` | ⚠️ |
| `-[Universe addDelayedMessage:]` (6277) | `Universe::addDelayedMessage(PList)` `Core/Universe.cpp:7225` | ✅ |
| `-[Universe addMessage:forCount:]` (6290) | `Universe::addMessage(text, count)` `Core/Universe.cpp:7236` | ✅ |
| `-[Universe speakWithSubstitutions:]` (6295) | `Universe::speakWithSubstitutions` `Core/Universe.cpp:7241` | ✅ |
| `-[Universe addMessage:forCount:forceDisplay:]` (6340) | `Universe::addMessage(text, count, force)` `Core/Universe.cpp:7299` | ✅ |
| `-[Universe addCommsMessage:forCount:]` (6357) | `Universe::addCommsMessage(text, count)` `Core/Universe.cpp:7322` | ✅ |
| `-[Universe addCommsMessage:forCount:andShowComms:logOnly:]` (6362) | `Universe::addCommsMessage(text, count, show, logOnly)` `Core/Universe.cpp:7327` | ✅ |
| `-[Universe showCommsLog:]` (6393) | `Universe::showCommsLog` `Core/Universe.cpp:7376` | ✅ |
| `-[Universe showGUIMessage:withScroll:andColor:overDuration:]` (6400) | `Universe::showGUIMessage` `Core/Universe.cpp:7382` | ✅ |
| `-[Universe repopulateSystem]` (6410) | `Universe::repopulateSystem` `Core/Universe.cpp:7396` | ✅ |
| `-[Universe update:]` (6421) | `Universe::update` `Core/Universe.cpp:7413` | ❌ |
| `-[Universe timeAccelerationFactor]` (6680) | `Universe::getTimeAccelerationFactor` (debug monitor) `Core/Universe.cpp:7726` | ✅ |
| `-[Universe setTimeAccelerationFactor:]` (6685) | `Universe::setTimeAccelerationFactor` (debug monitor) `Core/Universe.cpp:7728` | ✅ |
| `-[Universe timeAccelerationFactor]` (6693) | `Universe::getTimeAccelerationFactor` (no monitor) `Core/Universe.cpp:7736` | ✅ |
| `-[Universe setTimeAccelerationFactor:]` (6698) | `Universe::setTimeAccelerationFactor` (no monitor) `Core/Universe.cpp:7738` | ✅ |
| `-[Universe ECMVisualFXEnabled]` (6703) | `Universe::getECMVisualFXEnabled` `Core/Universe.cpp:7742` | ✅ |
| `-[Universe setECMVisualFXEnabled:]` (6708) | `Universe::setECMVisualFXEnabled` `Core/Universe.cpp:7744` | ✅ |
| `-[Universe filterSortedLists]` (6713) | `Universe::filterSortedLists` `Core/Universe.cpp:7750` | ✅ |
| `-[Universe setGalaxyTo:]` (7147) | `Universe::setGalaxyTo(g)` `Core/Universe.cpp:8222` | ✅ |
| `-[Universe setGalaxyTo:andReinit:]` (7152) | `Universe::setGalaxyTo(g, forced)` `Core/Universe.cpp:8227` | ✅ |
| `-[Universe setSystemTo:]` (7173) | `Universe::setSystemTo` `Core/Universe.cpp:8244` | ✅ |
| `-[Universe currentSystemID]` (7193) | `Universe::currentSystemID` `Core/Universe.cpp:8265` | ✅ |
| `-[Universe descriptions]` (7198) | `Universe::descriptions` `Core/Universe.cpp:8267` (plus a C++-only generation counter) | ✅ |
| `VerifyDescString` (7214) | `VerifyDescString` `Core/Universe.cpp:982` | ✅ |
| `VerifyDescArray` (7222) | `VerifyDescArray` `Core/Universe.cpp:992` | ✅ |
| `VerifyDesc` (7230) | `VerifyDesc` `Core/Universe.cpp:998` | ✅ |
| `-[Universe verifyDescriptions]` (7244) | `Universe::verifyDescriptions` `Core/Universe.cpp:8285` | ⚠️ |
| `-[Universe loadDescriptions]` (7267) | `Universe::loadDescriptions` `Core/Universe.cpp:8311` | ✅ |
| `-[Universe explosionSetting:]` (7274) | `Universe::explosionSetting` `Core/Universe.cpp:8318` | ✅ |
| `-[Universe scenarios]` (7279) | `Universe::scenarios` `Core/Universe.cpp:8323` | ✅ |
| `-[Universe loadScenarios]` (7284) | `Universe::loadScenarios` `Core/Universe.cpp:8325` | ✅ |
| `-[Universe characters]` (7290) | `Universe::getCharacters` `Core/Universe.cpp:8330` | ✅ |
| `-[Universe missiontext]` (7295) | `Universe::getMissiontext` `Core/Universe.cpp:8332` | ✅ |
| `-[Universe descriptionForKey:]` (7300) | `Universe::descriptionForKey` `Core/Universe.cpp:8334` | ✅ |
| `-[Universe descriptionForArrayKey:index:]` (7305) | `Universe::descriptionForArrayKey` `Core/Universe.cpp:8338` | ✅ |
| `-[Universe descriptionBooleanForKey:]` (7313) | `Universe::descriptionBooleanForKey` `Core/Universe.cpp:8346` | ✅ |
| `-[Universe systemManager]` (7318) | `Universe::getSystemManager` `Core/Universe.cpp:8350` | ✅ |
| `-[Universe keyForPlanetOverridesForSystem:inGalaxy:]` (7323) | `Universe::keyForPlanetOverridesForSystem` `Core/Universe.cpp:8354` | ✅ |
| `-[Universe keyForInterstellarOverridesForSystems:s2:inGalaxy:]` (7328) | `Universe::keyForInterstellarOverridesForSystems` `Core/Universe.cpp:8359` | ✅ |
| `-[Universe generateSystemData:]` (7333) | `Universe::generateSystemData(s)` `Core/Universe.cpp:8365` | ✅ |
| `-[Universe generateSystemData:useCache:]` (7339) | `Universe::generateSystemData(s, bool)` `Core/Universe.cpp:8370` | ✅ |
| `-[Universe currentSystemData]` (7353) | `Universe::currentSystemData` `Core/Universe.cpp:8389` | ✅ |
| `-[Universe inInterstellarSpace]` (7385) | `Universe::inInterstellarSpace` `Core/Universe.cpp:8422` | ✅ |
| `-[Universe setSystemDataKey:value:fromManifest:]` (7392) | `Universe::setSystemDataKey` `Core/Universe.cpp:8426` | ✅ |
| `-[Universe setSystemDataForGalaxy:planet:key:value:fromManifest:forLayer:]` (7397) | `Universe::setSystemDataForGalaxy` `Core/Universe.cpp:8432` | ✅ |
| `-[Universe generateSystemDataForGalaxy:planet:]` (7507) | `Universe::generateSystemDataForGalaxy` `Core/Universe.cpp:8599` | ✅ |
| `-[Universe systemDataKeysForGalaxy:planet:]` (7513) | `Universe::systemDataKeysForGalaxy` `Core/Universe.cpp:8609` | ⚠️ |
| `-[Universe systemDataForGalaxy:planet:key:]` (7519) | `Universe::systemDataForGalaxy` `Core/Universe.cpp:8620` | ✅ |
| `-[Universe getSystemName:]` (7524) | `Universe::getSystemName(sys)` `Core/Universe.cpp:8626` | ✅ |
| `-[Universe getSystemName:forGalaxy:]` (7529) | `Universe::getSystemName(sys, gnum)` `Core/Universe.cpp:8630` (via `SystemPropertyString` `Core/Universe.cpp:967`) | ✅ |
| `-[Universe getSystemGovernment:]` (7534) | `Universe::getSystemGovernment` `Core/Universe.cpp:8637` | ✅ |
| `-[Universe getSystemInhabitants:]` (7539) | `Universe::getSystemInhabitants(sys)` `Core/Universe.cpp:8646` | ✅ |
| `-[Universe getSystemInhabitants:plural:]` (7544) | `Universe::getSystemInhabitants(sys, plural)` `Core/Universe.cpp:8650` | ✅ |
| `-[Universe coordinatesForSystem:]` (7558) | `Universe::coordinatesForSystem` `Core/Universe.cpp:8672` | ✅ |
| `-[Universe findSystemFromName:]` (7563) | `Universe::findSystemFromName` `Core/Universe.cpp:8678` | ✅ |
| `-[Universe findSystemAtCoords:withGalaxy:]` (7580) | `Universe::findSystemAtCoords` `Core/Universe.cpp:8691` | ✅ |
| `-[Universe nearbyDestinationsWithinRange:]` (7586) | `Universe::nearbyDestinationsWithinRange` `Core/Universe.cpp:8746` | ✅ |
| `-[Universe findNeighbouringSystemToCoords:withGalaxy:]` (7611) | `Universe::findNeighbouringSystemToCoords` `Core/Universe.cpp:8775` | ✅ |
| `-[Universe findConnectedSystemAtCoords:withGalaxy:]` (7653) | `Universe::findConnectedSystemAtCoords` `Core/Universe.cpp:8824` | ✅ |
| `-[Universe findSystemNumberAtCoords:withGalaxy:includingHidden:]` (7693) | `Universe::findSystemNumberAtCoords` `Core/Universe.cpp:8870` | ✅ |
| `-[Universe findSystemCoordinatesWithPrefix:]` (7740) | `Universe::findSystemCoordinatesWithPrefix(p_fix)` `Core/Universe.cpp:8924` | ✅ |
| `-[Universe findSystemCoordinatesWithPrefix:exactMatch:]` (7745) | `Universe::findSystemCoordinatesWithPrefix(p_fix, exactMatch)` `Core/Universe.cpp:8928` | ✅ |
| `-[Universe systemsFound]` (7773) | `Universe::systemsFound` `Core/Universe.cpp:8966` | ✅ |
| `-[Universe systemNameIndex:]` (7778) | `Universe::systemNameIndex` `Core/Universe.cpp:8968` | ✅ |
| `-[Universe routeFromSystem:toSystem:optimizedBy:]` (7783) | `Universe::routeFromSystem` `Core/Universe.cpp:8972` (RouteElement `Core/Universe.cpp:8701-8739`, now held by `std::shared_ptr`) | ✅ |
| `-[Universe neighboursToSystem:]` (7906) | `Universe::neighboursToSystem` `Core/Universe.cpp:9115` | ✅ |
| `-[Universe preloadPlanetTexturesForSystem:]` (7949) | `Universe::preloadPlanetTexturesForSystem` `Core/Universe.cpp:9159` (upstream body is `#if 0`; port body empty) | ✅ |
| `-[Universe globalSettings]` (7981) | `Universe::getGlobalSettings` `Core/Universe.cpp:9163` | ✅ |
| `-[Universe equipmentData]` (7986) | `Universe::getEquipmentData` `Core/Universe.cpp:9165` | ✅ |
| `-[Universe equipmentDataOutfitting]` (7991) | `Universe::getEquipmentDataOutfitting` `Core/Universe.cpp:9167` | ✅ |
| `-[Universe commodityMarket]` (7996) | `Universe::getCommodityMarket` `Core/Universe.cpp:9171` | ✅ |
| `-[Universe timeDescription:]` (8001) | `Universe::timeDescription` `Core/Universe.cpp:9175` | ✅ |
| `-[Universe shortTimeDescription:]` (8028) | `Universe::shortTimeDescription` `Core/Universe.cpp:9203` | ✅ |
| `-[Universe makeSunSkimmer:andSetAI:]` (8062) | `Universe::makeSunSkimmer` `Core/Universe.cpp:9243` | ✅ |
| `-[Universe marketSeed]` (8073) | `Universe::marketSeed` `Core/Universe.cpp:9257` | ✅ |
| `-[Universe loadStationMarkets:]` (8090) | `Universe::loadStationMarkets` `Core/Universe.cpp:9275` | ✅ |
| `-[Universe getStationMarkets]` (8115) | `Universe::getStationMarkets` `Core/Universe.cpp:9306` | ✅ |
| `-[Universe shipsForSaleForSystem:withTL:atTime:]` (8141) | `Universe::shipsForSaleForSystem` `Core/Universe.cpp:9338` (helpers `RemoveKeyAt`, `ContainsKey`, `RemoveOption`, `SetInDict`, `ExpandKeyWith` `Core/Universe.cpp:1015-1070`) | ❌ |
| `compareName` (8513) | `compareName` `Core/Universe.cpp:1084` | ✅ |
| `comparePrice` (8527) | `comparePrice` `Core/Universe.cpp:1072` | ✅ |
| `-[Universe tradeInValueForCommanderDictionary:]` (8535) | `Universe::tradeInValueForCommanderDictionary` `Core/Universe.cpp:9832` | ✅ |
| `-[Universe brochureDescriptionWithDictionary:standardEquipment:optionalEquipment:]` (8671) | `Universe::brochureDescriptionWithDictionary` `Core/Universe.cpp:10063` | ✅ |
| `-[Universe getWitchspaceExitPosition]` (8771) | `Universe::getWitchspaceExitPosition` `Core/Universe.cpp:10174` | ✅ |
| `-[Universe getWitchspaceExitRotation]` (8776) | `Universe::getWitchspaceExitRotation` `Core/Universe.cpp:10176` | ✅ |
| `-[Universe getSunSkimStartPositionForShip:]` (8795) | `Universe::getSunSkimStartPositionForShip` `Core/Universe.cpp:10194` | ✅ |
| `-[Universe getSunSkimEndPositionForShip:]` (8828) | `Universe::getSunSkimEndPositionForShip` `Core/Universe.cpp:10229` (three `randf()` hoisted into locals left-to-right) | ✅ |
| `-[Universe listBeaconsWithCode:]` (8886) | `Universe::listBeaconsWithCode` `Core/Universe.cpp:10294` (`BeaconCodeMatches` `Core/Universe.cpp:245`) | ⚠️ |
| `-[Universe allShipsDoScriptEvent:andReactToAIMessage:]` (8902) | `Universe::allShipsDoScriptEvent` `Core/Universe.cpp:10317` | ✅ |
| `-[Universe gui]` (8925) | `Universe::getGui` `Core/Universe.cpp:10344` | ✅ |
| `-[Universe commLogGUI]` (8930) | `Universe::commLogGUI` `Core/Universe.cpp:10346` | ✅ |
| `-[Universe messageGUI]` (8935) | `Universe::messageGUI` `Core/Universe.cpp:10348` | ✅ |
| `-[Universe clearGUIs]` (8940) | `Universe::clearGUIs` `Core/Universe.cpp:10350` | ✅ |
| `-[Universe resetCommsLogColor]` (8953) | `Universe::resetCommsLogColor` `Core/Universe.cpp:10360` | ❌ |
| `-[Universe setDisplayText:]` (8958) | `Universe::setDisplayText` `Core/Universe.cpp:10364` | ✅ |
| `-[Universe displayGUI]` (8963) | `Universe::getDisplayGUI` `Core/Universe.cpp:10366` | ✅ |
| `-[Universe setDisplayFPS:]` (8968) | `Universe::setDisplayFPS` `Core/Universe.cpp:10368` | ✅ |
| `-[Universe displayFPS]` (8973) | `Universe::getDisplayFPS` `Core/Universe.cpp:10370` | ✅ |
| `-[Universe setAutoSave:]` (8978) | `Universe::setAutoSave` `Core/Universe.cpp:10372` | ✅ |
| `-[Universe autoSave]` (8984) | `Universe::getAutoSave` `Core/Universe.cpp:10377` | ✅ |
| `-[Universe setAutoSaveNow:]` (8989) | `Universe::setAutoSaveNow` `Core/Universe.cpp:10379` | ✅ |
| `-[Universe autoSaveNow]` (8994) | `Universe::getAutoSaveNow` `Core/Universe.cpp:10384` | ✅ |
| `-[Universe setWireframeGraphics:]` (8999) | `Universe::setWireframeGraphics` `Core/Universe.cpp:10386` | ✅ |
| `-[Universe wireframeGraphics]` (9005) | `Universe::getWireframeGraphics` `Core/Universe.cpp:10391` | ✅ |
| `-[Universe reducedDetail]` (9010) | `Universe::reducedDetail` `Core/Universe.cpp:10393` | ✅ |
| `-[Universe setDetailLevelDirectly:]` (9016) | `Universe::setDetailLevelDirectly` `Core/Universe.cpp:10398` | ✅ |
| `-[Universe setDetailLevel:]` (9029) | `Universe::setDetailLevel` `Core/Universe.cpp:10410` | ✅ |
| `-[Universe detailLevel]` (9042) | `Universe::getDetailLevel` `Core/Universe.cpp:10424` | ✅ |
| `-[Universe useShaders]` (9047) | `Universe::useShaders` `Core/Universe.cpp:10426` | ✅ |
| `-[Universe handleOoliteException:]` (9052) | `Universe::handleOoliteException` `Core/Universe.cpp:10430` | ✅ |
| `-[Universe airResistanceFactor]` (9069) | `Universe::getAirResistanceFactor` `Core/Universe.cpp:10452` | ✅ |
| `-[Universe setAirResistanceFactor:]` (9074) | `Universe::setAirResistanceFactor` `Core/Universe.cpp:10454` | ✅ |
| `-[Universe startSpeakingString:]` (9082) | removed: Mac Cocoa speech arm deleted in port commit e69f3a299 (comment `Core/Universe.cpp:10458`) | ➖ |
| `-[Universe stopSpeaking]` (9087) | removed (Mac Cocoa speech arm, same commit) | ➖ |
| `-[Universe isSpeaking]` (9096) | removed (Mac Cocoa speech arm, same commit) | ➖ |
| `-[Universe startSpeakingString:]` (9103) | `Universe::startSpeakingString` (eSpeak) `Core/Universe.cpp:10461` | ✅ |
| `-[Universe stopSpeaking]` (9114) | `Universe::stopSpeaking` (eSpeak) `Core/Universe.cpp:10469` | ✅ |
| `-[Universe isSpeaking]` (9119) | `Universe::isSpeaking` (eSpeak) `Core/Universe.cpp:10471` | ✅ |
| `-[Universe voiceName:]` (9124) | `Universe::voiceName` `Core/Universe.cpp:10473` | ✅ |
| `-[Universe voiceNumber:]` (9131) | `Universe::voiceNumber` `Core/Universe.cpp:10478` (loop rewritten for clang-tidy; same search) | ✅ |
| `-[Universe nextVoice:]` (9146) | `Universe::nextVoice` `Core/Universe.cpp:10489` | ✅ |
| `-[Universe prevVoice:]` (9153) | `Universe::prevVoice` `Core/Universe.cpp:10494` | ✅ |
| `-[Universe setVoice:withGenderM:]` (9160) | `Universe::setVoice` `Core/Universe.cpp:10499` | ✅ |
| `-[Universe startSpeakingString:]` (9175) | `Universe::startSpeakingString` (no synth) `Core/Universe.cpp:10521` | ✅ |
| `-[Universe stopSpeaking]` (9179) | `Universe::stopSpeaking` (no synth) `Core/Universe.cpp:10523` | ✅ |
| `-[Universe isSpeaking]` (9183) | `Universe::isSpeaking` (no synth) `Core/Universe.cpp:10525` | ✅ |
| `-[Universe pauseMessageVisible]` (9189) | `Universe::pauseMessageVisible` `Core/Universe.cpp:10528` | ✅ |
| `-[Universe setPauseMessageVisible:]` (9194) | `Universe::setPauseMessageVisible` `Core/Universe.cpp:10530` | ✅ |
| `-[Universe permanentMessageLog]` (9199) | `Universe::permanentMessageLog` `Core/Universe.cpp:10532` | ✅ |
| `-[Universe setPermanentMessageLog:]` (9204) | `Universe::setPermanentMessageLog` `Core/Universe.cpp:10534` | ✅ |
| `-[Universe autoMessageLogBg]` (9209) | `Universe::autoMessageLogBg` `Core/Universe.cpp:10538` | ✅ |
| `-[Universe setAutoMessageLogBg:]` (9214) | `Universe::setAutoMessageLogBg` `Core/Universe.cpp:10540` | ✅ |
| `-[Universe permanentCommLog]` (9219) | `Universe::permanentCommLog` `Core/Universe.cpp:10542` | ✅ |
| `-[Universe setPermanentCommLog:]` (9224) | `Universe::setPermanentCommLog` `Core/Universe.cpp:10544` | ✅ |
| `-[Universe setAutoCommLog:]` (9229) | `Universe::setAutoCommLog` `Core/Universe.cpp:10546` | ✅ |
| `-[Universe blockJSPlayerShipProps]` (9234) | `Universe::blockJSPlayerShipProps` `Core/Universe.cpp:10548` | ✅ |
| `-[Universe setBlockJSPlayerShipProps:]` (9239) | `Universe::setBlockJSPlayerShipProps` `Core/Universe.cpp:10552` | ✅ |
| `-[Universe setUpSettings]` (9248) | `Universe::setUpSettings` `Core/Universe.cpp:10560` | ⚠️ |
| `-[Universe setUpCargoPods]` (9334) | `Universe::setUpCargoPods` `Core/Universe.cpp:10662` | ⚠️ |
| `-[Universe verifyEntitySessionIDs]` (9350) | `Universe::verifyEntitySessionIDs` `Core/Universe.cpp:10679` | ✅ |
| `-[Universe reinitAndShowDemo:]` (9374) | `Universe::reinitAndShowDemo` `Core/Universe.cpp:10708` | ✅ |
| `-[Universe setUpInitialUniverse]` (9478) | `Universe::setUpInitialUniverse` `Core/Universe.cpp:10815` | ✅ |
| `-[Universe randomDistanceWithinScanner]` (9513) | `Universe::randomDistanceWithinScanner` `Core/Universe.cpp:10859` | ✅ |
| `-[Universe randomPlaceWithinScannerFrom:alongRoute:withOffset:]` (9518) | `Universe::randomPlaceWithinScannerFrom` `Core/Universe.cpp:10863` | ✅ |
| `-[Universe fractionalPositionFrom:to:withFraction:]` (9527) | `Universe::fractionalPositionFrom` `Core/Universe.cpp:10872` | ✅ |
| `-[Universe doRemoveEntity:]` (9541) | `Universe::doRemoveEntity` `Core/Universe.cpp:10886` | ✅ |
| `PreloadOneSound` (9642) | `PreloadOneSound` `Core/Universe.cpp:1108` | ✅ |
| `-[Universe preloadSounds]` (9649) | `Universe::preloadSounds` `Core/Universe.cpp:10998` | ⚠️ |
| `-[Universe populateSpaceFromActiveWormholes]` (9672) | `Universe::populateSpaceFromActiveWormholes` `Core/Universe.cpp:11018` (`RemoveFirstWormhole` `Core/Universe.cpp:230`) | ✅ |
| `-[Universe chooseStringForKey:inDictionary:]` (9695) | `Universe::chooseStringForKey` `Core/Universe.cpp:11047` | ✅ |
| `-[Universe dumpDebugGraphViz]` (9708) | `Universe::dumpDebugGraphViz` `Core/Universe.cpp:11059` | ✅ |
| `-[Universe dumpSystemDescriptionGraphViz]` (9715) | `Universe::dumpSystemDescriptionGraphViz` `Core/Universe.cpp:11065` | ✅ |
| `-[Universe addNumericRefsInString:toGraphViz:fromNode:nodeCount:]` (9818) | `Universe::addNumericRefsInString` `Core/Universe.cpp:11180` | ✅ |
| `-[Universe runLocalizationTools]` (9869) | `Universe::runLocalizationTools` `Core/Universe.cpp:11237` | ✅ |
| `-[Universe prunePreloadingPlanetMaterials]` (9899) | `Universe::prunePreloadingPlanetMaterials` `Core/Universe.cpp:11260` | ✅ |
| `-[Universe loadConditionScripts]` (9912) | `Universe::loadConditionScripts` `Core/Universe.cpp:11271` (`CachedConditionScripts` `Core/Universe.cpp:1141`) | ✅ |
| `-[Universe addConditionScripts:]` (9924) | `Universe::addConditionScripts` `Core/Universe.cpp:11281` | ✅ |
| `-[Universe getConditionScript:]` (9937) | `Universe::getConditionScript` `Core/Universe.cpp:11293` | ✅ |
| `+[OOSound(OOCustomSounds) soundWithCustomSoundKey:]` (9946) | `OOSoundWithCustomSoundKey` `Core/Universe.cpp:1160` | ✅ |
| `-[OOSound(OOCustomSounds) initWithCustomSoundKey:]` (9954) | removed; trumble call sites use `oo::share(OOSoundWithCustomSoundKey(...))` `Core/OOTrumble.cpp:906,911` | ➖ |
| `+[OOSoundSource(OOCustomSounds) sourceWithCustomSoundKey:]` (9964) | removed (no caller upstream or in the port) | ➖ |
| `-[OOSoundSource(OOCustomSounds) initWithCustomSoundKey:]` (9969) | removed (no caller upstream or in the port) | ➖ |
| `-[OOSoundSource(OOCustomSounds) playCustomSoundWithKey:]` (9981) | `OOSoundSourcePlayCustomSoundWithKey` `Core/Universe.cpp:1168` | ✅ |
| `populatorPrioritySort` (9990) | `populatorPrioritySort` (bool comparator) `Core/Universe.cpp:947` | ✅ |
| `equipmentSort` (10003) | `equipmentSort` `Core/Universe.cpp:900` (`ExtraInfoValue` gives 0 for a missing dict, as nil messaging did) | ✅ |
| `equipmentSortOutfitting` (10034) | `equipmentSortOutfitting` `Core/Universe.cpp:917` | ✅ |
| `OOLookUpDescriptionPRIV` (10065) | `OOLookUpDescriptionPRIV` `Core/Universe.cpp:1175` | ✅ |
| `OOLookUpPluralDescriptionPRIV` (10074) | `OOLookUpPluralDescriptionPRIV` `Core/Universe.cpp:1182` | ✅ |

**Differences:**

- ❌ **med** (still open) — Preference defaults apply only when the key is absent (`prefs.object(k).isNull() ? default : prefs.xForKey(k)`); upstream `oo_*ForKey:defaultValue:` also fell back for a wrong-kind or unparsable value, where `Defaults::boolForKey`/`floatForKey`/`integerForKey` give false/0 (`oofnd/Defaults.hpp:495-520`). Effect: detail level 0, FOV clamped to MIN_FOV_DEG instead of 57.2, procedural planets and ECM FX off — upstream `Core/Universe.m:726,752,754,758` ↔ port `Core/Universe.cpp:307-314,337-361`
- ❌ **low** (still open) — `speech_on`, `autosave`, `wireframe-graphics`, `anti-aliasing` parse strings via `stringBoolValue` (`oofnd/Defaults.hpp:101`) instead of OOBooleanFromObject, so values such as `"on"` differ — upstream `Core/Universe.m:737,750,751,753` ↔ port `Core/Universe.cpp:323,336-342`
- ❌ **low** (still open) — Nil messaging lost: upstream `OOGLProgramName([textureProgram program])` (and blur/final) gave 0 for a nil program; the port's `textureProgram->program()` dereferences null if shader creation failed — upstream `Core/Universe.m:616-618` ↔ port `Core/Universe.cpp:11677-11679`
- ❌ **low** (still open; coordinator: unreachable, because the only caller rejects `number < 1` at `PlayerEntityLegacyScriptEngine.cpp:1730-1736`) — `addShipsAtPosition` with `howMany < 0`: upstream's VLA loop never ran and returned YES; the port's `std::vector<HPVector> ship_positions(howMany)` converts to a huge size_t and throws `std::length_error` (reachable from legacy `addShipsAt` script action) — upstream `Core/Universe.m:2306` ↔ port `Core/Universe.cpp:2956`
- ⚠️ **med** (still open) — Populator blocks with equal priority (default 100) run in key byte order then `std::stable_sort` (comment: "in key byte order … the order matters"); upstream sorted `allValues` hash order. Each callback draws from the RNG, so ships land differently — upstream `Core/Universe.m:1710-1711` ↔ port `Core/Universe.cpp:2222-2230`
- ❌ **low** (still open) — `allStations` is a vector in insertion order (upstream `NSMutableSet`), so `stations()` and the first match in `stationWithRole:andPosition:` follow insertion order, not hash order; also seen by `loadStationMarkets`/`getStationMarkets` snapshots — upstream `Core/Universe.m:3358-3361` ↔ port `Core/Universe.cpp:4162,9284,9311`, `Core/Universe.h:424`
- ❌ **low** (still open) — `setDockingClearanceProtocolActive` walks `allStations` in insertion order while each station's `randomShipKeyForRole` draws from the RNG, so station-to-draw pairing changes — upstream `Core/Universe.m:2951-2956` ↔ port `Core/Universe.cpp:3704-3717`
- ❌ **low** (still open) — `setLibraryTextForDemoShip` returns early when `gui` is null (skips `ExpandText` side effects); with an empty sub-list `end = count - 1` underflows and the `i <= end` loop never ends, where upstream raised `NSRangeException` (normally unreachable) — upstream `Core/Universe.m:3230-3248` ↔ port `Core/Universe.cpp:3852-3854,4042-4065`
- ❌ **low** (still open) — `randomShipKeyForRoleRespectingConditions`: on the slow path a zero-weight pick yields null → `""`, `canInstantiateShip("")` is true, and the port returns `optional("")` where upstream returned nil — upstream `Core/Universe.m:3609-3611` ↔ port `Core/Universe.cpp:4408-4415`, caller `Core/Entities/ShipEntity.cpp:3991,4004`
- ❌ **low** (still open) — `getRandomAmountOfCommodity` lacks the `co_type == nil → 0` guard; with no commodities `""` maps to tonnes and returns 1 instead of 0 — upstream `Core/Universe.m:3981-3983` ↔ port `Core/Universe.cpp:4849-4857`, `Core/OOCommodities.cpp:491-495`
- ⚠️ **low** (still open) — `shipClassForShipDictionary:` became bool `isStationShipDictionary`; `newShipWithName` uses `makeStation`/`makeProxy` flags (beads oo-9ht.175, oo-9ht.183). Role/`isCarrier`/`is_carrier` priority and proxy rule unchanged — upstream `Core/Universe.m:3720-3737,3798-3820` ↔ port `Core/Universe.cpp:4537-4559,4630-4650`
- ⚠️ **low** (still open) — `universe.unremovedEntity` log lives in `Entity::~Entity` (same text/condition); a direct `ensureEntityReallyRemoved` call no longer logs — upstream `Core/Universe.m:5149-5151` ↔ port `Core/Universe.cpp:6021-6027`, `Core/Entities/Entity.cpp:118-123`
- ⚠️ **low** (still open) — `addDelayedMessage:forCount:afterDelay:` with nil text: upstream raised from `setObject:nil`; the port omits `message` and shows nothing (comment `Core/Universe.cpp:7209-7211`); delay via `OOScheduleDeferredCall` (bead oo-pvhrh) — upstream `Core/Universe.m:6269-6275` ↔ port `Core/Universe.cpp:7212-7223`
- ❌ **low** (new) — `update:` dropped the debug-build (`#ifndef NDEBUG`) JSGC_BYTES before/after check around `garbageCollectionOpportunity` and its `universe.profile.jsgc` "Unplanned JS Garbage Collection" log; no `profile.jsgc` remains in port `src/`. Release builds unaffected — upstream `Core/Universe.m:6647-6660` ↔ port `Core/Universe.cpp:7703-7705`
- ⚠️ **low** (still open) — `verifyDescriptions` walks keys in byte order (comment "was hash order"); only changes which bad entry is reported before FATAL exit — upstream `Core/Universe.m:7261-7264` ↔ port `Core/Universe.cpp:8302-8308`
- ⚠️ **low** (still open) — `systemDataKeysForGalaxy` returns keys in byte order (comment says so); visible in JS `SystemInfo` enumeration — upstream `Core/Universe.m:7515` ↔ port `Core/Universe.cpp:8608-8617`
- ❌ **low** (still open) — Shipyard de-dup can keep a different offer: upstream sorted `[resultDictionary allValues]` (hash order), the port a `std::map` (ID byte order) with `std::stable_sort`; when two offers tie on name and price a different ship ID/personality/extras survives. RNG draws unchanged — upstream `Core/Universe.m:8494-8506` ↔ port `Core/Universe.cpp:9343,9804-9821`
- ⚠️ **low** (still open) — `listBeaconsWithCode` uses `std::stable_sort` ("ORDER-SENSITIVE (decision D)") and full lower-casing instead of `NSCaseInsensitiveSearch`; nil code still matches, empty search matches nothing — upstream `Core/Universe.m:8893,8899` ↔ port `Core/Universe.cpp:245-253,10307-10313`
- ❌ **low** (still open) — `resetCommsLogColor` dereferences `comm_log_gui` without a null check (upstream nil message was a no-op); crashes before `setUpSettings` builds the GUI. `clearGUIs` next to it is guarded — upstream `Core/Universe.m:8955` ↔ port `Core/Universe.cpp:10361`
- ⚠️ **low** (still open) — `setUpSettings` sorts equipment lists with `std::stable_sort` ("ORDER-SENSITIVE"); tied entries may list differently — upstream `Core/Universe.m:9325-9326` ↔ port `Core/Universe.cpp:10641-10654`
- ⚠️ **low** (still open) — `setUpCargoPods` skips a commodity whose template pod failed; upstream `setObject:nil` raised and aborted (comment says so) — upstream `Core/Universe.m:9339-9343` ↔ port `Core/Universe.cpp:10667-10674`
- ⚠️ **low** (still open) — `preloadSounds` walks `customsounds.plist` keys in byte order ("ORDER-SENSITIVE (decision D)"); only preload/log order changes — upstream `Core/Universe.m:9653` ↔ port `Core/Universe.cpp:10996-11012`
- ➖ (new) — The Mac Cocoa speech arm (`startSpeakingString:`/`stopSpeaking`/`isSpeaking` via `NSSpeechSynthesizer`, upstream guard now `OOLITE_MAC_COCOA_UI`) was present-but-unbuilt last time and is now deleted (port commit e69f3a299) — upstream `Core/Universe.m:9080-9099` ↔ port `Core/Universe.cpp:10458`
- ➖ (still open) — `OOSoundSource` custom-sound initialisers (no callers) are gone; `-[OOSound initWithCustomSoundKey:]` replaced at trumble call sites by `oo::share(OOSoundWithCustomSoundKey(...))` — upstream `Core/Universe.m:9954-9979` ↔ port `Core/OOTrumble.cpp:906,911`
- ✅ subtle (checked) — `drawUniverse` and `update:` `catch (...)` rethrow anything that is not an OOException without resetting `no_update`/logging, mirroring upstream `@catch (NSException*)` letting non-NSExceptions pass. A `std::` exception (e.g. `std::length_error`) has no upstream counterpart; if caught higher up, `no_update` would stay set — upstream `Core/Universe.m:4755-4763` ↔ port `Core/Universe.cpp:5718-5731,7671-7689`
- ✅ subtle (checked) — Upstream changes since 2026-10-27 are mirrored: `OO_MSAA_COLOR_RENDERBUFFER` arms in init/delete/resize; `carryPlayerOn` passes jump cause as JS string and `dest` via `OOJSValueFromDouble`; `canInstantiateShip`, `allowOfferShip`, `allowAwardEquipment` use `OOJSValueToBOOL` and free result and args in the same order — port `Core/Universe.cpp:11366-11388,11577-11614,1337-1342,4327-4349,9383-9406,9588-9616`
- ✅ subtle (checked) — shared_ptr refactor keeps lifetimes: `addShipWithRole`/`addShipAt`/`addWreckageFrom` return `.get()` after the universe holds the entity; `setUpPlanet` drops the old planet hold before `removeEntity`; `drawUniverse` keeps visible entities alive via `oo::autorelease(oo::Hold(e))`; `my_entities` snapshots became `oo::HoldIn` vectors released at the same points; `allShipsDoScriptEvent` holds each ship — port `Core/Universe.cpp:2627-2635,1715-1724,3410,5304,10322-10339`
- ✅ subtle (new) — At DEMO_FLY_OUT a demo ship that `addEntity` refuses is now destroyed when its holder goes out of scope; upstream leaked it. `demo_ship` becomes nil either way — upstream `Core/Universe.m:6490-6519` ↔ port `Core/Universe.cpp:7489-7545`
- ✅ subtle (checked) — `speakWithSubstitutions` keeps only the eSpeak `replacementIndex` arm (Mac Cocoa arm index 1 dropped) — upstream `Core/Universe.m:6319-6329` ↔ port `Core/Universe.cpp:7267-7281`
- ✅ subtle (still recorded) — RNG order preserved (sky/sun `randf()` hoisted in Clang order, populator `RANROTSetFullSeed` save/restore); `update:` zombies collected in found order (upstream set hash order); `currentWaypoints` is a key-sorted copy; `cargoPodFromTemplate` skips `setCommodity` with no type; `soundNameForCustomSoundKey` caches nil key under `""`; `findOneEntityMatchingPredicate` early return without `OOJSResumeTimeLimiter()` kept (upstream bug); `RemoveKeyAt` reproduces the index −1 `OORangeException`; `filterSortedLists` matches line for line — port `Core/Universe.cpp:1804-1847,2252-2271,7568-7641,4265,4717,7073-7140,6867,1015-1024`

