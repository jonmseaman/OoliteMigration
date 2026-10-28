# Parity findings: Universe and GameController

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## GameController

<a id="gamecontroller"></a>
Upstream `src/Core/GameController.m` ↔ `Core/GameController.cpp`

**Status:** done — 60 rows: 50 ✅ 5 ⚠️ 3 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[GameController sharedController]` (70) | `GameController::sharedController` `Core/GameController.cpp:215` | ✅ |
| `-[GameController init]` (78) | `GameController::GameController` `Core/GameController.cpp:223` | ❌ |
| `-[GameController dealloc]` (101) | `GameController::~GameController` `Core/GameController.cpp:255` | ✅ |
| `-[GameController isGamePaused]` (118) | `GameController::isGamePaused` `Core/GameController.cpp:267` | ✅ |
| `-[GameController setGamePaused:]` (123) | `GameController::setGamePaused` `Core/GameController.cpp:272` | ✅ |
| `-[GameController setEcoQoS:]` (139) | `GameController::setEcoQoS` `Core/GameController.cpp:290` | ❌ |
| `-[GameController mouseInteractionMode]` (162) | `GameController::mouseInteractionMode` `Core/GameController.cpp:323` | ✅ |
| `-[GameController setMouseInteractionMode:]` (167) | `GameController::setMouseInteractionMode` `Core/GameController.cpp:328` | ✅ |
| `-[GameController setMouseInteractionModeForFlight]` (186) | `GameController::setMouseInteractionModeForFlight` `Core/GameController.cpp:348` | ✅ |
| `-[GameController setMouseInteractionModeForUIWithMouseInteraction:]` (191) | `GameController::setMouseInteractionModeForUIWithMouseInteraction` `Core/GameController.cpp:353` | ✅ |
| `-[GameController gameView]` (196) | `GameController::gameView` `Core/GameController.cpp:358` | ✅ |
| `-[GameController setGameView:]` (201) | `GameController::setGameView` `Core/GameController.cpp:363` | ✅ |
| `-[GameController applicationDidFinishLaunching:]` (209) | `GameController::applicationDidFinishLaunching` `Core/GameController.cpp:546` (+ `runFrameLoop` `Core/GameController.cpp:489`) | ⚠️ |
| `-[GameController finishedLaunching]` (283) | `GameController::finishedLaunching` `Core/GameController.cpp:376` | ✅ |
| `-[GameController loadPlayerIfRequired]` (288) | `GameController::loadPlayerIfRequired` `Core/GameController.cpp:623` | ✅ |
| `-[GameController beginSplashScreen]` (300) | `GameController::beginSplashScreen` `Core/GameController.cpp:642` | ⚠️ |
| `-[GameController performGameTick:]` (316) | `-[GameController(MacOSX) performGameTick:]` (Mac, not built) `Core/GameController.cpp:873` | ✅ |
| `-[GameController performGameTick:]` (324) | `GameController::performGameTick` `Core/GameController.cpp:393` | ✅ |
| `-[GameController doPerformGameTick]` (336) | `GameController::doPerformGameTick` `Core/GameController.cpp:404` | ⚠️ |
| `-[GameController startAnimationTimer]` (369) | `GameController::startAnimationTimer` `Core/GameController.cpp:442` (+ `performGameTickIfDue` `Core/GameController.cpp:460`) | ⚠️ |
| `-[GameController stopAnimationTimer]` (384) | `GameController::stopAnimationTimer` `Core/GameController.cpp:455` | ⚠️ |
| `-[GameController recenterVirtualJoystick]` (395) | Mac category `Core/GameController.cpp:879` (not built) | ✅ |
| `-[GameController showLogAction:]` (402) | Mac category `Core/GameController.cpp:886` (not built) | ✅ |
| `-[GameController showLogFolderAction:]` (407) | Mac category `Core/GameController.cpp:891` (not built) | ✅ |
| `GetPreference()` (413) | `GetPreference` `Core/GameController.cpp:898` (the class check moved to the callers, `:924,:933`) | ✅ |
| `SetPreference()` (422) | `SetPreference` `Core/GameController.cpp:903` | ✅ |
| `RemovePreference()` (427) | `RemovePreference` `Core/GameController.cpp:908` | ✅ |
| `-[GameController snapshotsURLCreatingIfNeeded:]` (435) | Mac category `Core/GameController.cpp:916` (not built) | ✅ |
| `-[GameController showSnapshotsAction:]` (497) | Mac category `Core/GameController.cpp:980` (not built) | ✅ |
| `-[GameController showAddOnsAction:]` (502) | Mac category `Core/GameController.cpp:985` (not built) | ✅ |
| `-[GameController isDirectoryAtPath:]` (530) | `-cxx_isDirectoryAtPath:` `Core/GameController.cpp:1010` (not built) | ✅ |
| `-[GameController addOnsExistAtPath:]` (536) | `-cxx_addOnsExistAtPath:` `Core/GameController.cpp:1015` (not built) | ✅ |
| `-[GameController openPath:]` (552) | `-cxx_openPath:` `Core/GameController.cpp:1035` (not built) | ✅ |
| `-[GameController validateMenuItem:]` (557) | Mac category `Core/GameController.cpp:1040` (not built) | ✅ |
| `-[GameController applicationDockMenu:]` (592) | Mac category `Core/GameController.cpp:1077` (not built) | ✅ |
| `-[GameController snapshotsURLCreatingIfNeeded:]` (599) | removed on SDL: "nothing on SDL called it (bead oo-3rb.13)" `Core/GameController.cpp:666`; upstream has no SDL caller either | ➖ |
| `-[GameController logProgress:]` (617) | `GameController::logProgress` `Core/GameController.cpp:671` | ✅ |
| `-[GameController debugMessageTrackingIsOn]` (633) | Mac category `Core/GameController.cpp:1083` (not built) | ✅ |
| `-[GameController debugMessageCurrentString]` (638) | `-cxx_debugMessageCurrentString` `Core/GameController.cpp:1088` (not built) | ✅ |
| `-[GameController debugMessageTrackingIsOn]` (643) | `GameController::debugMessageTrackingIsOn` `Core/GameController.cpp:687` | ✅ |
| `-[GameController debugMessageCurrentString]` (648) | `GameController::debugMessageCurrentString` `Core/GameController.cpp:692` | ✅ |
| `-[GameController debugLogProgress:]` (654) | `GameController::debugLogProgress(const std::string&)` `Core/GameController.cpp:698` (callers pass the formatted message; `OO_DEBUG_PROGRESS` `Core/GameController.h:247`) | ✅ |
| `-[GameController debugLogProgress:arguments:]` (662) | folded into `debugLogProgress` `Core/GameController.cpp:698` | ➖ |
| `-[GameController debugPushProgressMessage:]` (670) | `GameController::debugPushProgressMessage` `Core/GameController.cpp:707` | ✅ |
| `-[GameController debugPopProgressMessage]` (686) | `GameController::debugPopProgressMessage` `Core/GameController.cpp:717` | ✅ |
| `-[GameController endSplashScreen]` (700) | `GameController::endSplashScreen` `Core/GameController.cpp:731` | ✅ |
| `-[GameController awakeFromNib]` (720) | Mac category `Core/GameController.cpp:1095` (not built) | ✅ |
| `-[GameController application:openFile:]` (735) | Mac category `Core/GameController.cpp:1109` (not built) | ✅ |
| `-[GameController exitAppWithContext:]` (756) | `-cxx_exitAppWithContext:` `Core/GameController.cpp:1127` (not built) | ✅ |
| `-[GameController applicationShouldTerminate:]` (763) | Mac category `Core/GameController.cpp:1134` (not built) | ✅ |
| `-[GameController exitAppWithContext:]` (773) | `GameController::exitAppWithContext` `Core/GameController.cpp:750` | ✅ |
| `-[GameController exitAppCommandQ]` (799) | `GameController::exitAppCommandQ` `Core/GameController.cpp:777` | ✅ |
| `-[GameController windowDidResize:]` (804) | `GameController::windowDidResize` `Core/GameController.cpp:782` | ✅ |
| `-[GameController playerFileToLoad]` (809) | `GameController::playerFileToLoad` `Core/GameController.cpp:788` | ✅ |
| `-[GameController setPlayerFileToLoad:]` (814) | `GameController::setPlayerFileToLoad` `Core/GameController.cpp:793` | ✅ |
| `-[GameController playerFileDirectory]` (823) | `GameController::playerFileDirectory` `Core/GameController.cpp:803` (`-defaultCommanderPath` inlined) | ✅ |
| `-[GameController setPlayerFileDirectory:]` (839) | `GameController::setPlayerFileDirectory` `Core/GameController.cpp:835` | ✅ |
| `-[GameController reportUnhandledStartupException:]` (854) | `GameController::reportUnhandledStartupExceptionName` `Core/GameController.cpp:849` | ✅ |
| `-[GameController suppressClangStuff]` (869) | `GameController::suppressClangStuff` `Core/GameController.cpp:385` | ✅ |
| `SetUpSparkle()` (879) | `SetUpSparkle` `Core/GameController.cpp:1143` (Mac, not built) | ❌ |

**Differences:**

- ❌ **med** — The `animation_timer_interval` default (the main-loop tick) loses `oo_doubleForKey:defaultValue:` fallback semantics. The port reads `prefs.object(k).isNull() ? MINIMUM_ANIMATION_TICK : prefs.doubleForKey(k)`, so the 0.0041667 s default applies only when the key is absent. Upstream `OODoubleFromObject` also fell back for a value of the wrong kind (array/dict/data) and for a non-numeric string (`"fast"`, `""`). `oo::Defaults::doubleForKey` gives `0.0` there (`oofnd/Defaults.hpp:490-496`), and `startAnimationTimer` clamps that to 0.0001 s: a 10 kHz tick deadline instead of 240 Hz, so the loop spins. This is the same cross-cutting `isNull() ? default : xForKey()` pattern recorded in Universe part 1. Upstream `Core/GameController.m:89` ↔ port `Core/GameController.cpp:235,446-447`.
- ❌ **low** — `ecoqos` (Windows pause efficiency mode) has the same pattern: `object("ecoqos").isNull() ? true : boolForKey("ecoqos")`. Upstream `OOBooleanFromObject(…, YES)` treated `"on"` and `"0.5"` as YES, and an unrecognised string or a non-scalar value as the default YES. The port's `stringBoolValue` gives NO for all of these (`oofnd/Defaults.hpp:90-101`), so pausing no longer drops to `IDLE_PRIORITY_CLASS`/power throttling. Upstream `Core/GameController.m:142` ↔ port `Core/GameController.cpp:303`.
- ❌ **low** — `use-test-release-updates` (Sparkle feed) has the same pattern. This is Mac-only and never built. Upstream `Core/GameController.m:895-896` ↔ port `Core/GameController.cpp:1159-1161`.
- ⚠️ **low** — `init` seeds RANROT from `OO_RANDOM_SEED` when that variable is set, and logs `rand.seed`. Unset keeps wall-clock seeding. The comment says this is for the goldens (0.4) and the component tier (0.13b). Upstream `Core/GameController.m:93` ↔ port `Core/GameController.cpp:243-249`.
- ⚠️ **low** — `last_timeInterval` and `_splashStart` use a monotonic clock instead of `timeIntervalSinceReferenceDate` (comment: "the frame clock: intervals only"). A wall-clock step backwards no longer feeds a negative `delta_t` into `-[Universe update:]`; upstream clamped only the top, at `MINIMUM_GAME_TICK` 0.25. The startup timings in the log are unchanged. Upstream `Core/GameController.m:87,95,342` ↔ port `Core/GameController.cpp:231,251,410`.
- ⚠️ **low** — `setEcoQoS(true)` returns early while a debug console is waiting for input, so a console-driven pause stays at normal priority (comment cites bug oo-37zzy). Upstream `Core/GameController.m:139-160` ↔ port `Core/GameController.cpp:293-302`.
- ⚠️ **med** — The main loop: `-[NSRunLoop run]` plus a repeating `NSTimer` became `runFrameLoop` with a `steady_clock` deadline (ADR-0029 Decision 5, proposed ADR-0033). Late ticks skip and never burst, an interval ≤ 0 is clamped to 0.0001 s, and the wait is a whole-millisecond `Sleep`. Each pass fires the tick, then the log flush, then at most two deferred calls (proposed ADR-0040), then OXZ download events (proposed ADR-0044), or services the debug-console socket instead. Upstream `Core/GameController.m:258,279,369-391` ↔ port `Core/GameController.cpp:111-123,442-544,619`.
- ⚠️ **low** — `doPerformGameTick` catches only `oo::Exception` and logs `"{name} : {reason}"` under `exception.backtrace` instead of `-callStackSymbols` (bead oo-rskgl.1, proposed ADR-0037). A non-`oo::Exception` C++ exception (`std::bad_alloc`, `std::out_of_range`) now escapes the frame loop and ends the process. Upstream `@catch (id)` logged any Objective-C exception and carried on. Upstream `Core/GameController.m:357-366` ↔ port `Core/GameController.cpp:426-439`.
- ⚠️ **low** — `beginSplashScreen`: when `MyOpenGLView::init()` fails, the view is released and `_gameView` stays null, so later sends are skipped. Upstream kept the dangling pointer (ADR-0056 amendment oo-9ht.153 item 2). Upstream `Core/GameController.m:303-308` ↔ port `Core/GameController.cpp:645-659`.
- ➖ — The SDL `-snapshotsURLCreatingIfNeeded:` is removed: upstream had no SDL caller (grep finds it only in `GameController.h`/`.m`). `-debugLogProgress:arguments:` is folded into the single formatted-string `debugLogProgress`, and `OO_DEBUG_PUSH_PROGRESS` takes the message pre-formatted. Upstream `Core/GameController.m:599-611,662-666` ↔ port `Core/GameController.cpp:666,698`.
- Subtle (✅, recorded) — Pause/resume matches: `_resumeMode` is saved and restored, the UI mouse mode is set, eco QoS is toggled and `gamePaused`/`gameResumed` fire, with `PLAYER` null-guarded as nil messaging was. Paused ticks set `delta_t = 0` and skip `OOJSFrameCallbacksInvoke`, as upstream did. Port `Core/GameController.cpp:272-288,407-425`.
- Subtle (✅, recorded) — The startup order matches: OXP verifier (exits via `exitAppWithContext`) or splash, display modes, `expansionPathsToInclude` → `ResourceManager::addExternalPath` before the Universe exists, `OOOXZManager`, Universe, the player load, `logProgress("")`, the timer, `endSplashScreen`, the `startup.complete` log line, then the frame loop. An unhandled `oo::Exception` at startup logs `startup.exception` and calls `exit(EXIT_FAILURE)`; any other C++ exception is rethrown (upstream caught only `NSException`). Port `Core/GameController.cpp:546-621`.
- Subtle (✅, recorded) — The SDL exit path keeps upstream's order: `exit.context` log, debug monitor, desktop-resolution restore (a null view counts as "not at desktop resolution", as nil did), defaults synchronize, its log line, `OOLoggingTerminate`, `SDL_Quit`, OpenAL shutdown (null-guarded), `exit(0)`. Port `Core/GameController.cpp:750-771`.
- Subtle (✅, recorded) — `playerFileDirectory` inlines `-defaultCommanderPath` with the same create/not-a-directory fallbacks and log classes, via `ResourcePaths::saveDirectory()` (`OO_SAVEDIR` or `~/oolite-saves`). Port `Core/GameController.cpp:803-833`.

## Universe

<a id="universe"></a>

### Universe (part 1: lines 1-3383)

Upstream `src/Core/Universe.m` lines 1–3383 ↔ `Core/Universe.cpp`

**Status:** done — 106 rows: 99 ✅ 1 ⚠️ 6 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| file-level `enum DEMO_*`, `#define DEMO2_*`, `MAX_NUMBER_OF_ENTITIES`, `STANDARD_STATION_ROLL`, `LANE_WIDTH` (101-112) | same macros `Core/Universe.cpp:113-125` | ✅ |
| log-class constants `kOOLogUniversePopulate*`, `kOOLogEntityVerification*` (114-117) | `Core/Universe.cpp:127-132` (verification pair now `#ifndef NDEBUG`; only read by the debug list checks) | ✅ |
| `framebufferQuadVertices` / `framebufferQuadIndices` (119-129) | `Core/Universe.cpp:134-144` | ✅ |
| `gSharedUniverse`, `gOOJSPlayerIfStale`, forward decls `MaintainLinkedLists`/`EntityInRange`/`compareName`/`comparePrice` (131-140) | `Core/Universe.cpp:146-154` (compare* declared/defined at `Core/Universe.cpp:1037,1048`) | ✅ |
| statics `JSResetFlags`, `object_light_on`, `demo_light_on`, `sun_off`, `demo_light_position`, `DOCKED_*`, `docked_light_*`, `SUN_AMBIENT_INFLUENCE`, `SKY_AMBIENT_ADJUSTMENT` (264-283) | `Core/Universe.cpp:506-524` | ✅ |
| `+[RouteElement elementWithLocation:parent:cost:distance:time:jumps:]` (164) | `RouteElement::elementWithLocation` `Core/Universe.cpp:8025` | ✅ |
| `-[RouteElement parent]` (178) | `RouteElement::parent` `Core/Universe.cpp:8039` | ✅ |
| `-[RouteElement location]` (182) | `RouteElement::location` `Core/Universe.cpp:8040` | ✅ |
| `-[RouteElement cost]` (186) | `RouteElement::cost` `Core/Universe.cpp:8041` | ✅ |
| `-[RouteElement distance]` (190) | `RouteElement::distance` `Core/Universe.cpp:8042` | ✅ |
| `-[RouteElement time]` (194) | `RouteElement::time` `Core/Universe.cpp:8043` | ✅ |
| `-[RouteElement jumps]` (198) | `RouteElement::jumps` `Core/Universe.cpp:8044` | ✅ |
| `-[Universe bloom]` (284) | `Universe::bloom` `Core/Universe.cpp:10417` | ✅ |
| `-[Universe setBloom:]` (289) | `Universe::setBloom` `Core/Universe.cpp:10422` | ✅ |
| `-[Universe currentPostFX]` (294) | `Universe::currentPostFX` `Core/Universe.cpp:10427` | ✅ |
| `-[Universe setCurrentPostFX:]` (299) | `Universe::setCurrentPostFX` `Core/Universe.cpp:10432` | ✅ |
| `-[Universe terminatePostFX:]` (312) | `Universe::terminatePostFX` `Core/Universe.cpp:10445` | ✅ |
| `-[Universe nextColorblindMode:]` (319) | `Universe::nextColorblindMode` `Core/Universe.cpp:10452` | ✅ |
| `-[Universe prevColorblindMode:]` (327) | `Universe::prevColorblindMode` `Core/Universe.cpp:10460` | ✅ |
| `-[Universe colorblindMode]` (335) | `Universe::colorblindMode` `Core/Universe.cpp:10468` | ✅ |
| `-[Universe initTargetFramebufferWithViewSize:]` (340) | `Universe::initTargetFramebufferWithViewSize` `Core/Universe.cpp:10473` | ✅ |
| `-[Universe deleteOpenGLObjects]` (520) | `Universe::deleteOpenGLObjects` `Core/Universe.cpp:10654` | ✅ |
| `-[Universe resizeTargetFramebufferWithViewSize:]` (540) | `Universe::resizeTargetFramebufferWithViewSize` `Core/Universe.cpp:10674` | ✅ |
| `-[Universe drawTargetTextureIntoDefaultFramebuffer]` (579) | `Universe::drawTargetTextureIntoDefaultFramebuffer` `Core/Universe.cpp:10713` | ❌ |
| `-[Universe initWithGameView:]` (673) | `Universe::newUniverse` `Core/Universe.cpp:264` + `Universe::initWithGameView` `Core/Universe.cpp:285` | ❌ |
| `-[Universe dealloc]` (839) | `Universe::~Universe` `Core/Universe.cpp:259` → `Universe::dealloc` `Core/Universe.cpp:449` | ✅ |
| `-[Universe sessionID]` (903) | `Universe::sessionID` `Core/Universe.cpp:10807` | ✅ |
| `-[Universe doingStartUp]` (908) | `Universe::doingStartUp` `Core/Universe.cpp:10812` | ✅ |
| `-[Universe doProcedurallyTexturedPlanets]` (913) | `Universe::getDoProcedurallyTexturedPlanets` `Core/Universe.cpp:10817` | ✅ |
| `-[Universe setDoProcedurallyTexturedPlanets:]` (918) | `Universe::setDoProcedurallyTexturedPlanets` `Core/Universe.cpp:10822` | ✅ |
| `-[Universe useAddOns]` (924) | `Universe::getUseAddOns` `Core/Universe.cpp:10828` | ✅ |
| `-[Universe setUseAddOns:fromSaveGame:]` (929) | `Universe::setUseAddOns(newUse, saveGame)` `Core/Universe.cpp:10833` | ✅ |
| `-[Universe setUseAddOns:fromSaveGame:forceReinit:]` (934) | `Universe::setUseAddOns(newUse, saveGame, force)` `Core/Universe.cpp:10838` | ✅ |
| `-[Universe entityCount]` (945) | `Universe::entityCount` `Core/Universe.cpp:10848` | ✅ |
| `-[Universe debugDumpEntities]` (951) | `Universe::debugDumpEntities` `Core/Universe.cpp:10854` | ✅ |
| `-[Universe entityList]` (972) | `Universe::entityList` `Core/Universe.cpp:10875` | ✅ |
| `-[Universe pauseGame]` (978) | `Universe::pauseGame` `Core/Universe.cpp:1242` | ✅ |
| `-[Universe quitGame]` (1005) | `Universe::quitGame` `Core/Universe.cpp:1271` | ✅ |
| `-[Universe carryPlayerOn:inWormhole:]` (1011) | `Universe::carryPlayerOn` `Core/Universe.cpp:1278` | ✅ |
| `-[Universe setUpUniverseFromStation]` (1069) | `Universe::setUpUniverseFromStation` `Core/Universe.cpp:1354` | ✅ |
| `-[Universe setUpUniverseFromWitchspace]` (1143) | `Universe::setUpUniverseFromWitchspace` `Core/Universe.cpp:1436` | ✅ |
| `-[Universe setUpUniverseFromMisjump]` (1179) | `Universe::setUpUniverseFromMisjump` `Core/Universe.cpp:1477` | ✅ |
| `-[Universe setUpWitchspace]` (1210) | `Universe::setUpWitchspace` `Core/Universe.cpp:1512` | ✅ |
| `-[Universe setUpWitchspaceBetweenSystem:andSystem:]` (1215) | `Universe::setUpWitchspaceBetweenSystem` `Core/Universe.cpp:1517` | ✅ |
| `-[Universe setUpPlanet]` (1279) | `Universe::setUpPlanet` `Core/Universe.cpp:1586` | ✅ |
| `-[Universe setUpSpace]` (1315) | `Universe::setUpSpace` `Core/Universe.cpp:1640` | ✅ |
| `-[Universe populateNormalSpace]` (1603) | `Universe::populateNormalSpace` `Core/Universe.cpp:1966` | ✅ |
| `-[Universe clearSystemPopulator]` (1663) | `Universe::clearSystemPopulator` `Core/Universe.cpp:2025` | ✅ |
| `-[Universe getPopulatorSettings]` (1669) | `Universe::getPopulatorSettings` `Core/Universe.cpp:2030` | ✅ |
| `-[Universe setPopulatorSetting:to:]` (1674) | `Universe::setPopulatorSetting` `Core/Universe.cpp:2035` | ✅ |
| `-[Universe deterministicPopulation]` (1683) | `Universe::deterministicPopulation` `Core/Universe.cpp:2047` | ✅ |
| `-[Universe populateSystemFromDictionariesWithSun:andPlanet:]` (1688) | `Universe::populateSystemFromDictionariesWithSun` `Core/Universe.cpp:2052` | ⚠️ |
| `-[Universe locationByCode:withSun:andPlanet:]` (1764) | `Universe::locationByCode` `Core/Universe.cpp:2138` | ✅ |
| `-[Universe setAmbientLightLevel:]` (1847) | `Universe::setAmbientLightLevel` `Core/Universe.cpp:2221` | ✅ |
| `-[Universe ambientLightLevel]` (1855) | `Universe::getAmbientLightLevel` `Core/Universe.cpp:2229` | ✅ |
| `-[Universe setLighting]` (1860) | `Universe::setLighting` `Core/Universe.cpp:2234` | ✅ |
| `-[Universe forceLightSwitch]` (1941) | `Universe::forceLightSwitch` `Core/Universe.cpp:2322` | ✅ |
| `-[Universe setMainLightPosition:]` (1946) | `Universe::setMainLightPosition` `Core/Universe.cpp:2327` | ✅ |
| `-[Universe addShipWithRole:launchPos:rfactor:]` (1954) | `Universe::addShipWithRole(desc, launchPos, rfactor)` `Core/Universe.cpp:2335` | ✅ |
| `-[Universe addShipWithRole:nearRouteOneAt:]` (1988) | `Universe::addShipWithRole(desc, route_fraction)` `Core/Universe.cpp:2371` | ✅ |
| `-[Universe coordinatesForPosition:withCoordinateSystem:returningScalar:]` (2002) | `Universe::coordinatesForPosition` `Core/Universe.cpp:2385` | ✅ |
| `-[Universe expressPosition:inCoordinateSystem:]` (2144) | `Universe::expressPosition` `Core/Universe.cpp:2527` | ✅ |
| `-[Universe legacyPositionFrom:asCoordinateSystem:]` (2150) | `Universe::legacyPositionFrom` `Core/Universe.cpp:2537` | ✅ |
| `-[Universe coordinatesFromCoordinateSystemString:]` (2254) | `Universe::coordinatesFromCoordinateSystemString` `Core/Universe.cpp:2641` | ✅ |
| `-[Universe addShipWithRole:nearPosition:withCoordinateSystem:]` (2265) | `Universe::addShipWithRole(desc, pos, system)` `Core/Universe.cpp:2657` | ✅ |
| `-[Universe addShips:withRole:atPosition:withCoordinateSystem:]` (2280) | `Universe::addShipsAtPosition` `Core/Universe.cpp:2672` | ❌ |
| `-[Universe addShips:withRole:nearPosition:withCoordinateSystem:]` (2354) | `Universe::addShipsNearPosition(4 args)` `Core/Universe.cpp:2750` | ✅ |
| `-[Universe addShips:withRole:nearPosition:withCoordinateSystem:withinRadius:]` (2371) | `Universe::addShipsNearPosition(5 args)` `Core/Universe.cpp:2767` | ✅ |
| `-[Universe addShips:withRole:intoBoundingBox:]` (2386) | `Universe::addShips` `Core/Universe.cpp:2782` | ✅ |
| `-[Universe spawnShip:]` (2428) | `Universe::spawnShip` `Core/Universe.cpp:2824` | ✅ |
| `-[Universe witchspaceShipWithPrimaryRole:]` (2498) | `Universe::witchspaceShipWithPrimaryRole` `Core/Universe.cpp:2898` | ✅ |
| `-[Universe spawnShipWithRole:near:]` (2549) | `Universe::spawnShipWithRole` `Core/Universe.cpp:2957` | ✅ |
| `-[Universe addVisualEffectAt:withKey:]` (2568) | `Universe::addVisualEffectAt` `Core/Universe.cpp:2977` | ✅ |
| `-[Universe addShipAt:withRole:withinRadius:]` (2589) | `Universe::addShipAt` `Core/Universe.cpp:3003` | ✅ |
| `-[Universe addShipsAt:withRole:quantity:withinRadius:asGroup:]` (2679) | `Universe::addShipsAt` `Core/Universe.cpp:3102` | ✅ |
| `-[Universe addShipsToRoute:withRole:quantity:routeFraction:asGroup:]` (2709) | `Universe::addShipsToRoute` `Core/Universe.cpp:3132` | ✅ |
| `-[Universe roleIsPirateVictim:]` (2784) | `Universe::roleIsPirateVictim` `Core/Universe.cpp:3205` | ✅ |
| `-[Universe role:isInCategory:]` (2789) | `Universe::role` `Core/Universe.cpp:3210` | ✅ |
| `-[Universe forceWitchspaceEntries]` (2799) | `Universe::forceWitchspaceEntries` `Core/Universe.cpp:3224` | ✅ |
| `-[Universe addWitchspaceJumpEffectForShip:]` (2815) | `Universe::addWitchspaceJumpEffectForShip` `Core/Universe.cpp:3243` | ✅ |
| `-[Universe safeWitchspaceExitDistance]` (2824) | `Universe::safeWitchspaceExitDistance` `Core/Universe.cpp:3252` | ✅ |
| `-[Universe setUpBreakPattern:orientation:forDocking:]` (2835) | `Universe::setUpBreakPattern` `Core/Universe.cpp:3263` | ✅ |
| `-[Universe witchspaceBreakPattern]` (2907) | `Universe::witchspaceBreakPattern` `Core/Universe.cpp:3335` | ✅ |
| `-[Universe setWitchspaceBreakPattern:]` (2912) | `Universe::setWitchspaceBreakPattern` `Core/Universe.cpp:3340` | ✅ |
| `-[Universe dockingClearanceProtocolActive]` (2917) | `Universe::dockingClearanceProtocolActive` `Core/Universe.cpp:3345` | ✅ |
| `-[Universe setDockingClearanceProtocolActive:]` (2922) | `Universe::setDockingClearanceProtocolActive` `Core/Universe.cpp:3350` | ❌ |
| `-[Universe handleGameOver]` (2942) | `Universe::handleGameOver` `Core/Universe.cpp:3373` | ✅ |
| `-[Universe setupIntroFirstGo:]` (2951) | `Universe::setupIntroFirstGo` `Core/Universe.cpp:3387` | ✅ |
| `-[Universe demoShipData]` (3038) | `Universe::demoShipData` `Core/Universe.cpp:3492` (+ `DemoShipEntry` `Core/Universe.cpp:532`) | ✅ |
| `-[Universe setLibraryTextForDemoShip]` (3043) | `Universe::setLibraryTextForDemoShip` `Core/Universe.cpp:3497` | ❌ |
| `-[Universe selectIntro2Previous]` (3242) | `Universe::selectIntro2Previous` `Core/Universe.cpp:3700` | ✅ |
| `-[Universe selectIntro2PreviousCategory]` (3250) | `Universe::selectIntro2PreviousCategory` `Core/Universe.cpp:3708` | ✅ |
| `-[Universe selectIntro2NextCategory]` (3258) | `Universe::selectIntro2NextCategory` `Core/Universe.cpp:3716` | ✅ |
| `-[Universe selectIntro2Next]` (3266) | `Universe::selectIntro2Next` `Core/Universe.cpp:3724` | ✅ |
| `IsCandidateMainStationPredicate()` (3272) | `IsCandidateMainStationPredicate` `Core/Universe.cpp:588` | ✅ |
| `IsFriendlyStationPredicate()` (3277) | `IsFriendlyStationPredicate` `Core/Universe.cpp:593` | ✅ |
| `-[Universe station]` (3282) | `Universe::station` `Core/Universe.cpp:3730` | ✅ |
| `-[Universe stationWithRole:andPosition:]` (3291) | `Universe::stationWithRole` `Core/Universe.cpp:3738` | ✅ |
| `-[Universe stationFriendlyTo:]` (3311) | `Universe::stationFriendlyTo` `Core/Universe.cpp:3759` | ✅ |
| `-[Universe planet]` (3318) | `Universe::planet` `Core/Universe.cpp:3766` | ✅ |
| `-[Universe sun]` (3326) | `Universe::sun` `Core/Universe.cpp:3774` | ✅ |
| `-[Universe planets]` (3334) | `Universe::planets` `Core/Universe.cpp:3782` | ✅ |
| `-[Universe stations]` (3339) | `Universe::stations` `Core/Universe.cpp:3787` | ❌ |
| `-[Universe wormholes]` (3344) | `Universe::wormholes` `Core/Universe.cpp:3797` | ✅ |
| `-[Universe unMagicMainStation]` (3349) | `Universe::unMagicMainStation` `Core/Universe.cpp:3802` | ✅ |
| `-[Universe resetBeacons]` (3370) | `Universe::resetBeacons` `Core/Universe.cpp:3825` | ✅ |

**Differences:**

- ❌ **med** — Preferences lose `oo_*ForKey:defaultValue:` fallback semantics: the port reads `prefs.object(k).isNull() ? default : prefs.xForKey(k)`, so the default applies only to an absent key. Upstream also fell back for a present value of the wrong kind (array/dict/data), for a string that is no bool (`"maybe"` → YES) and for a float string that does not read as a number (`"abc"` → 57.2). `oo::Defaults::boolForKey`/`floatForKey` give `false`/`0` instead, and `stringBoolValue` does not accept `"on"` (`oofnd/Defaults.hpp:90`). The visible results are planets not procedurally textured, ECM FX off, FOV clamped to `MIN_FOV_DEG` instead of 57.2, and the detail level at 0 instead of `defaultDetailLevel` — upstream `Core/Universe.m:707,733,736,740` ↔ port `Core/Universe.cpp:308,333,338,344`
- ❌ **low** — The same Defaults reads without defaults for `speech_on`, `autosave`, `wireframe-graphics` and `anti-aliasing` (default NO both sides) still differ for string values: `"on"`/`"yes"` with a trailing letter parse differently (OOBooleanFromObject vs `stringBoolValue`) — upstream `Core/Universe.m:718,731,732,734` ↔ port `Core/Universe.cpp:318,331,332,335`
- ⚠️ **med** — Populator blocks with equal `priority` (the default is 100, so most blocks) run in a different order. Upstream sorted `[populatorSettings allValues]`, which is NSDictionary hash order; the port collects blocks in key byte order (std::map) and then runs `std::stable_sort`. Each callback draws from the main RNG, so a different order moves populated ships and groups to different places. The port's comment admits it: "in key byte order (was the dictionary's hash order) … order-sensitive, the goldens decide" — upstream `Core/Universe.m:1691-1692` ↔ port `Core/Universe.cpp:2055-2062`
- ❌ **low** — `allStations` was an `NSMutableSet` and is now a vector in insertion order (`Core/Universe.h:384`). `stations` returns insertion order where upstream returned `allObjects` hash order, and that changes the order of JS `system.stations`-style lists and which station `stationWithRole:andPosition:` matches first (only when two stations share a role within 1 km) — upstream `Core/Universe.m:3339-3342` ↔ port `Core/Universe.cpp:3787-3790`
- ❌ **low** — `setDockingClearanceProtocolActive:` loops over `allStations` in the new insertion order. Each station calls `randomShipKeyForRole:`, which draws from the RNG, so the station-to-draw pairing changes, and with it which stations get `requiresDockingClearance` set when a role maps to ship types with and without that key — upstream `Core/Universe.m:2932-2937` ↔ port `Core/Universe.cpp:3360-3367`
- ❌ **low** — Nil-messaging lost: `[textureProgram program]` (and blur/final) returned 0 when the shader program was nil. The port's `textureProgram->program()` dereferences null, so it crashes if `OOShaderProgram::shaderProgramWithVertexShaderName` failed while `useShaders()` is true. Both callers (`Core/Universe.cpp:5151,5256`) are guarded by `useShaders()` only — upstream `Core/Universe.m:597-599` ↔ port `Core/Universe.cpp:10731-10733`
- ❌ **low** — `addShips:withRole:atPosition:withCoordinateSystem:` with `howMany < 0`: upstream's VLA loop never ran and returned YES. The port's `std::vector<HPVector> ship_positions(howMany)` converts the negative int to a huge `size_t` and throws `std::length_error`. It is reachable from the legacy `addShipsAt` script action with a negative count — upstream `Core/Universe.m:2287` ↔ port `Core/Universe.cpp:2679`
- ❌ **low** — `setLibraryTextForDemoShip` now returns early when `gui` is nil, which upstream did not; the side effects it skips are only the `OOExpand` calls. With an empty demo sub-list, `end = count - 1` underflows: upstream raised `NSRangeException` from `objectAtIndex:0`, while the port's `subList.at(i)` returns null and the loop runs on to `NSUIntegerMax`, effectively a hang (normally unreachable, since `demoShipKeys` builds no empty classes) — upstream `Core/Universe.m:3211-3229` ↔ port `Core/Universe.cpp:3497-3503,3667-3685`
- ✅ **low** (subtle, checked) — RNG seeding and call order are preserved. `OOInitReallyRandom` comes first in init. `setUpSpace` re-seeds with `seed_for_planet_description` before the sky, `setUpPlanet` re-seeds, and `setUpSpace` re-seeds again before the sun. The randf() calls inside ObjC message arguments are hoisted into locals in Clang's left-to-right order (`Core/Universe.cpp:1701-1706,1731-1732`, citing ADR-0063 item 5). The sky/dust/quaternion draw order in witchspace is unchanged. The populator's per-iteration `RANROTSetFullSeed` save/restore is identical — upstream `Core/Universe.m:1369,1425,1283,1716-1738` ↔ port `Core/Universe.cpp:1693,1761,1590,2084-2108`
- ✅ **low** (subtle, checked) — `setUpWitchspaceBetweenSystem` dereferences the optional `*keyForInterstellarOverridesForSystems(...)`, which is safe because that function always returns a value (`Core/Universe.cpp:7717-7720`). The z-order lists, `addEntity`/`removeEntity` bookkeeping and the collision code (`MaintainLinkedLists`, `findCollisionsAndShadows`) are at upstream lines ≥ 3384 and belong to part 2. The only collision setup in this range is `universeRegion` (`CollisionRegion AsUniverse`) and `entitiesDeadThisUpdate` in init, and both match — upstream `Core/Universe.m:810-813` ↔ port `Core/Universe.cpp:416-419`

### Universe (part 2: lines 3384-7125)

Upstream `src/Core/Universe.m` lines 3384–7125 (`-firstBeacon` … `-filterSortedLists`) ↔ `Core/Universe.cpp`

**Status:** done — 119 rows: 114 ✅ 3 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[Universe firstBeacon]` (3384) | `Universe::firstBeacon` `Core/Universe.cpp:3839` | ✅ |
| `-[Universe setFirstBeacon:]` (3389) | `Universe::setFirstBeacon` `Core/Universe.cpp:3844` | ✅ |
| `-[Universe lastBeacon]` (3400) | `Universe::lastBeacon` `Core/Universe.cpp:3854` | ✅ |
| `-[Universe setLastBeacon:]` (3405) | `Universe::setLastBeacon` `Core/Universe.cpp:3859` | ✅ |
| `-[Universe setNextBeacon:]` (3416) | `Universe::setNextBeacon` `Core/Universe.cpp:3869` | ✅ |
| `-[Universe clearBeacon:]` (3427) | `Universe::clearBeacon` `Core/Universe.cpp:3881` | ✅ |
| `-[Universe currentWaypoints]` (3448) | `Universe::currentWaypoints` `Core/Universe.cpp:3903` | ✅ |
| `-[Universe defineWaypoint:forKey:]` (3453) | `Universe::defineWaypoint` `Core/Universe.cpp:3908` | ✅ |
| `-[Universe skyClearColor]` (3478) | `Universe::getSkyClearColor` `Core/Universe.cpp:3937` | ✅ |
| `-[Universe setSkyColorRed:green:blue:alpha:]` (3483) | `Universe::setSkyColorRed` `Core/Universe.cpp:3942` | ✅ |
| `-[Universe breakPatternOver]` (3492) | `Universe::breakPatternOver` `Core/Universe.cpp:3951` | ✅ |
| `-[Universe breakPatternHide]` (3497) | `Universe::breakPatternHide` `Core/Universe.cpp:3956` | ✅ |
| `-[Universe canInstantiateShip:]` (3505) | `Universe::canInstantiateShip` `Core/Universe.cpp:3962` | ✅ |
| `-[Universe randomShipKeyForRoleRespectingConditions:]` (3551) | `Universe::randomShipKeyForRoleRespectingConditions` `Core/Universe.cpp:4004` | ❌ |
| `-[Universe newShipWithRole:]` (3602) | `Universe::newShipWithRole` `Core/Universe.cpp:4060` | ✅ |
| `-[Universe newVisualEffectWithName:]` (3647) | `Universe::newVisualEffectWithName` `Core/Universe.cpp:4117` | ✅ |
| `-[Universe newSubentityWithName:andScaleFactor:]` (3673) | `Universe::newSubentityWithName` `Core/Universe.cpp:4145` | ✅ |
| `-[Universe newShipWithName:usePlayerProxy:]` (3678) | `Universe::newShipWithName(key, proxy)` `Core/Universe.cpp:4150` | ✅ |
| `-[Universe newShipWithName:usePlayerProxy:isSubentity:]` (3683) | `Universe::newShipWithName(key, proxy, sub)` `Core/Universe.cpp:4155` | ✅ |
| `-[Universe newShipWithName:usePlayerProxy:isSubentity:andScaleFactor:]` (3688) | `Universe::newShipWithName(key, proxy, sub, scale)` `Core/Universe.cpp:4160` | ✅ |
| `-[Universe newDockWithName:andScaleFactor:]` (3735) | `Universe::newDockWithName` `Core/Universe.cpp:4214` | ✅ |
| `-[Universe newShipWithName:]` (3772) | `Universe::newShipWithName(key)` `Core/Universe.cpp:4253` | ✅ |
| `-[Universe shipClassForShipDictionary:]` (3777) | `Universe::isStationShipDictionary` `Core/Universe.cpp:4258` | ⚠️ |
| `-[Universe defaultAIForRole:]` (3801) | `Universe::defaultAIForRole` `Core/Universe.cpp:4281` | ✅ |
| `-[Universe maxCargoForShip:]` (3806) | `Universe::maxCargoForShip` `Core/Universe.cpp:4286` | ✅ |
| `-[Universe getEquipmentPriceForKey:]` (3814) | `Universe::getEquipmentPriceForKey` `Core/Universe.cpp:4299` | ✅ |
| `-[Universe commodities]` (3827) | `Universe::getCommodities` `Core/Universe.cpp:4313` | ✅ |
| `-[Universe reifyCargoPod:]` (3833) | `Universe::reifyCargoPod` `Core/Universe.cpp:4319` | ✅ |
| `-[Universe cargoPodFromTemplate:]` (3842) | `Universe::cargoPodFromTemplate` `Core/Universe.cpp:4328` | ✅ |
| `-[Universe getContainersOfGoods:scarce:legal:]` (3859) | `Universe::getContainersOfGoods` `Core/Universe.cpp:4348` | ✅ |
| `-[Universe getContainersOfCommodity:how_much:]` (3919) | `Universe::getContainersOfCommodity` `Core/Universe.cpp:4414` | ✅ |
| `-[Universe fillCargopodWithRandomCargo:]` (3939) | `Universe::fillCargopodWithRandomCargo` `Core/Universe.cpp:4438` | ✅ |
| `-[Universe getRandomCommodity]` (3951) | `Universe::getRandomCommodity` `Core/Universe.cpp:4451` | ✅ |
| `-[Universe getRandomAmountOfCommodity:]` (3956) | `Universe::getRandomAmountOfCommodity` `Core/Universe.cpp:4456` | ❌ |
| `-[Universe commodityDataForType:]` (3977) | `Universe::commodityDataForType` `Core/Universe.cpp:4475` | ✅ |
| `-[Universe displayNameForCommodity:]` (3982) | `Universe::displayNameForCommodity` `Core/Universe.cpp:4480` | ✅ |
| `-[Universe describeCommodity:amount:]` (3987) | `Universe::describeCommodity` `Core/Universe.cpp:4485` | ✅ |
| `-[Universe setGameView:]` (4032) | `Universe::setGameView` `Core/Universe.cpp:4531` | ✅ |
| `-[Universe gameView]` (4038) | `Universe::getGameView` `Core/Universe.cpp:4540` | ✅ |
| `-[Universe gameController]` (4043) | `Universe::gameController` `Core/Universe.cpp:4545` | ✅ |
| `-[Universe gameSettings]` (4048) | `Universe::gameSettings` `Core/Universe.cpp:4552` | ✅ |
| `-[Universe useGUILightSource:]` (4103) | `Universe::useGUILightSource` `Core/Universe.cpp:4600` | ✅ |
| `-[Universe lightForEntity:]` (4128) | `Universe::lightForEntity` `Core/Universe.cpp:4625` | ✅ |
| static `fwd_/aft_/port_/starboard_matrix` (4160) *(added: missed by extractor)* | same statics `Core/Universe.cpp:603` | ✅ |
| `-[Universe getActiveViewMatrix:forwardVector:upVector:]` (4177) | `Universe::getActiveViewMatrix` `Core/Universe.cpp:4656` | ✅ |
| `-[Universe activeViewMatrix]` (4220) | `Universe::activeViewMatrix` `Core/Universe.cpp:4700` | ✅ |
| `-[Universe defineFrustum]` (4234) | `Universe::defineFrustum` `Core/Universe.cpp:4718` | ✅ |
| `-[Universe viewFrustumIntersectsSphereAt:withRadius:]` (4320) | `Universe::viewFrustumIntersectsSphereAt` `Core/Universe.cpp:4804` | ✅ |
| `-[Universe drawUniverse]` (4332) | `Universe::drawUniverse` `Core/Universe.cpp:4820` | ✅ |
| `-[Universe prepareToRenderIntoDefaultFramebuffer]` (4761) | `Universe::prepareToRenderIntoDefaultFramebuffer` `Core/Universe.cpp:5262` | ✅ |
| `-[Universe framesDoneThisUpdate]` (4774) | `Universe::getFramesDoneThisUpdate` `Core/Universe.cpp:5275` | ✅ |
| `-[Universe resetFramesDoneThisUpdate]` (4779) | `Universe::resetFramesDoneThisUpdate` `Core/Universe.cpp:5280` | ✅ |
| `-[Universe viewMatrix]` (4784) | `Universe::getViewMatrix` `Core/Universe.cpp:5285` | ✅ |
| `-[Universe drawMessage]` (4789) | `Universe::drawMessage` `Core/Universe.cpp:5294` | ✅ |
| `-[Universe drawWatermarkString:]` (4810) | `Universe::drawWatermarkString` `Core/Universe.cpp:5319` | ✅ |
| `-[Universe entityForUniversalID:]` (4820) | `Universe::entityForUniversalID` `Core/Universe.cpp:5330` | ✅ |
| `MaintainLinkedLists()` (4846) | `MaintainLinkedLists` `Core/Universe.cpp:620` | ✅ |
| `-[Universe addEntity:]` (4969) | `Universe::addEntity` `Core/Universe.cpp:5356` | ✅ |
| `-[Universe removeEntity:]` (5107) | `Universe::removeEntity` `Core/Universe.cpp:5494` | ✅ |
| `-[Universe ensureEntityReallyRemoved:]` (5126) | `Universe::ensureEntityReallyRemoved` `Core/Universe.cpp:5514` (+ log in `Entity::~Entity` `Core/Entities/Entity.cpp:125`) | ⚠️ |
| `-[Universe removeAllEntitiesExceptPlayer]` (5134) | `Universe::removeAllEntitiesExceptPlayer` `Core/Universe.cpp:5523` | ✅ |
| `-[Universe removeDemoShips]` (5180) | `Universe::removeDemoShips` `Core/Universe.cpp:5568` | ✅ |
| `-[Universe makeDemoShipWithRole:spinning:]` (5196) | `Universe::makeDemoShipWithRole` `Core/Universe.cpp:5588` | ✅ |
| `-[Universe isVectorClearFromEntity:toDistance:fromPoint:]` (5232) | `Universe::isVectorClearFromEntity` `Core/Universe.cpp:5636` | ✅ |
| `-[Universe hazardOnRouteFromEntity:toDistance:fromPoint:]` (5296) | `Universe::hazardOnRouteFromEntity` `Core/Universe.cpp:5701` | ✅ |
| `-[Universe getSafeVectorFromEntity:toDistance:fromPoint:]` (5358) | `Universe::getSafeVectorFromEntity` `Core/Universe.cpp:5764` | ✅ |
| `-[Universe addWreckageFrom:withRole:at:scale:lifetime:]` (5476) | `Universe::addWreckageFrom` `Core/Universe.cpp:5882` | ✅ |
| `-[Universe addLaserHitEffectsAt:against:damage:color:]` (5507) | `Universe::addLaserHitEffectsAt` `Core/Universe.cpp:5924` | ✅ |
| `-[Universe firstShipHitByLaserFromShip:inDirection:offset:gettingRangeFound:]` (5528) | `Universe::firstShipHitByLaserFromShip` `Core/Universe.cpp:5947` | ✅ |
| `-[Universe firstEntityTargetedByPlayer]` (5628) | `Universe::firstEntityTargetedByPlayer` `Core/Universe.cpp:6057` | ✅ |
| `-[Universe firstEntityTargetedByPlayerPrecisely]` (5702) | `Universe::firstEntityTargetedByPlayerPrecisely` `Core/Universe.cpp:6131` | ✅ |
| `-[Universe entitiesWithinRange:ofEntity:]` (5738) | `Universe::entitiesWithinRange` `Core/Universe.cpp:6169` | ✅ |
| `-[Universe countShipsWithRole:inRange:ofEntity:]` (5749) | `Universe::countShipsWithRole(role, range, e)` `Core/Universe.cpp:6179` | ✅ |
| `-[Universe countShipsWithRole:]` (5757) | `Universe::countShipsWithRole(role)` `Core/Universe.cpp:6185` | ✅ |
| `-[Universe countShipsWithPrimaryRole:inRange:ofEntity:]` (5762) | `Universe::countShipsWithPrimaryRole(role, range, e)` `Core/Universe.cpp:6190` | ✅ |
| `-[Universe countShipsWithScanClass:inRange:ofEntity:]` (5770) | `Universe::countShipsWithScanClass` `Core/Universe.cpp:6197` | ✅ |
| `-[Universe countShipsWithPrimaryRole:]` (5778) | `Universe::countShipsWithPrimaryRole(role)` `Core/Universe.cpp:6202` | ✅ |
| `-[Universe countEntitiesMatchingPredicate:]` (5783) | `Universe::countEntitiesMatchingPredicate` `Core/Universe.cpp:6207` | ✅ |
| `-[Universe countShipsMatchingPredicate:]` (5818) | `Universe::countShipsMatchingPredicate` `Core/Universe.cpp:6239` | ✅ |
| `EntityInRange()` (5841) | `EntityInRange` `Core/Universe.cpp:765` | ✅ |
| `-[Universe findEntitiesMatchingPredicate:]` (5851) | `Universe::findEntitiesMatchingPredicate` `Core/Universe.cpp:6257` | ✅ |
| `-[Universe findOneEntityMatchingPredicate:]` (5889) | `Universe::findOneEntityMatchingPredicate` `Core/Universe.cpp:6292` | ✅ |
| `-[Universe findShipsMatchingPredicate:]` (5911) | `Universe::findShipsMatchingPredicate` `Core/Universe.cpp:6313` | ✅ |
| `-[Universe findVisualEffectsMatchingPredicate:]` (5934) | `Universe::findVisualEffectsMatchingPredicate` `Core/Universe.cpp:6327` | ✅ |
| `-[Universe nearestEntityMatchingPredicate:]` (5957) | `Universe::nearestEntityMatchingPredicate` `Core/Universe.cpp:6341` | ✅ |
| `-[Universe nearestShipMatchingPredicate:]` (5987) | `Universe::nearestShipMatchingPredicate` `Core/Universe.cpp:6369` | ✅ |
| `-[Universe getTime]` (6007) | `Universe::getTime` `Core/Universe.cpp:6383` | ✅ |
| `-[Universe getTimeDelta]` (6012) | `Universe::getTimeDelta` `Core/Universe.cpp:6388` | ✅ |
| `-[Universe findCollisionsAndShadows]` (6017) | `Universe::findCollisionsAndShadows` `Core/Universe.cpp:6393` | ✅ |
| `-[Universe collisionDescription]` (6035) | `Universe::collisionDescription` `Core/Universe.cpp:6416` | ✅ |
| `-[Universe dumpCollisions]` (6043) | `Universe::dumpCollisions` `Core/Universe.cpp:6424` | ✅ |
| `-[Universe viewDirection]` (6048) | `Universe::getViewDirection` `Core/Universe.cpp:6429` | ✅ |
| `-[Universe setViewDirection:]` (6053) | `Universe::setViewDirection` `Core/Universe.cpp:6438` | ✅ |
| `-[Universe enterGUIViewModeWithMouseInteraction:]` (6117) | `Universe::enterGUIViewModeWithMouseInteraction` `Core/Universe.cpp:6505` | ✅ |
| `-[Universe soundNameForCustomSoundKey:]` (6130) | `Universe::soundNameForCustomSoundKey` `Core/Universe.cpp:6521` | ✅ |
| `-[Universe screenTextureDescriptorForKey:]` (6183) | `Universe::screenTextureDescriptorForKey` `Core/Universe.cpp:6577` | ✅ |
| `-[Universe setScreenTextureDescriptorForKey:descriptor:]` (6201) | `Universe::setScreenTextureDescriptorForKey` `Core/Universe.cpp:6601` | ✅ |
| `-[Universe clearPreviousMessage]` (6214) | `Universe::clearPreviousMessage` `Core/Universe.cpp:6613` | ✅ |
| `-[Universe setMessageGuiBackgroundColor:]` (6221) | `Universe::setMessageGuiBackgroundColor` `Core/Universe.cpp:6618` | ✅ |
| `-[Universe displayMessage:forCount:]` (6226) | `Universe::displayMessage` `Core/Universe.cpp:6625` | ✅ |
| `-[Universe displayCountdownMessage:forCount:]` (6237) | `Universe::displayCountdownMessage` `Core/Universe.cpp:6634` | ✅ |
| `-[Universe addDelayedMessage:forCount:afterDelay:]` (6248) | `Universe::addDelayedMessage(text, count, delay)` `Core/Universe.cpp:6645` | ⚠️ |
| `-[Universe addDelayedMessage:]` (6256) | `Universe::addDelayedMessage(PList)` `Core/Universe.cpp:6656` | ✅ |
| `-[Universe addMessage:forCount:]` (6269) | `Universe::addMessage(text, count)` `Core/Universe.cpp:6669` | ✅ |
| `-[Universe speakWithSubstitutions:]` (6274) | `Universe::speakWithSubstitutions` `Core/Universe.cpp:6674` | ✅ |
| `-[Universe addMessage:forCount:forceDisplay:]` (6319) | `Universe::addMessage(text, count, force)` `Core/Universe.cpp:6723` | ✅ |
| `-[Universe addCommsMessage:forCount:]` (6336) | `Universe::addCommsMessage(text, count)` `Core/Universe.cpp:6740` | ✅ |
| `-[Universe addCommsMessage:forCount:andShowComms:logOnly:]` (6341) | `Universe::addCommsMessage(text, count, show, logOnly)` `Core/Universe.cpp:6745` | ✅ |
| `-[Universe showCommsLog:]` (6372) | `Universe::showCommsLog` `Core/Universe.cpp:6781` | ✅ |
| `-[Universe showGUIMessage:withScroll:andColor:overDuration:]` (6379) | `Universe::showGUIMessage` `Core/Universe.cpp:6790` | ✅ |
| `-[Universe repopulateSystem]` (6389) | `Universe::repopulateSystem` `Core/Universe.cpp:6802` | ✅ |
| `-[Universe update:]` (6400) | `Universe::update` `Core/Universe.cpp:6818` | ✅ |
| `-[Universe timeAccelerationFactor]` (6659) | `Universe::getTimeAccelerationFactor` (debug monitor) `Core/Universe.cpp:7094` | ✅ |
| `-[Universe setTimeAccelerationFactor:]` (6664) | `Universe::setTimeAccelerationFactor` (debug monitor) `Core/Universe.cpp:7099` | ✅ |
| `-[Universe timeAccelerationFactor]` (6672) | `Universe::getTimeAccelerationFactor` (release) `Core/Universe.cpp:7107` | ✅ |
| `-[Universe setTimeAccelerationFactor:]` (6677) | `Universe::setTimeAccelerationFactor` (release) `Core/Universe.cpp:7112` | ✅ |
| `-[Universe ECMVisualFXEnabled]` (6682) | `Universe::getECMVisualFXEnabled` `Core/Universe.cpp:7117` | ✅ |
| `-[Universe setECMVisualFXEnabled:]` (6687) | `Universe::setECMVisualFXEnabled` `Core/Universe.cpp:7122` | ✅ |
| `-[Universe filterSortedLists]` (6692) | `Universe::filterSortedLists` `Core/Universe.cpp:7131` | ✅ |

**Differences:**

- ❌ **low** — When the first pick fails its conditions and every remaining candidate has weight 0, `-[OOProbabilitySet randomObject]` returns nil, `canInstantiateShip:nil` says YES, and upstream returns **nil**. The port turns the null object into `""`, `canInstantiateShip("")` says YES, and it returns `std::optional("")` (has_value). `ShipEntity` missile setup then takes the "newShipWithName failed" path, with different warning text, not the nil-key path — upstream `Core/Universe.m:3588` ↔ port `Core/Universe.cpp:4044-4048`, caller `Core/Entities/ShipEntity.cpp:3794`
- ❌ **low** — The `co_type == nil → return 0` guard has gone: a missing commodity now arrives as `""`, which `massUnitForGood` treats as tonnes, so the call returns **1** instead of 0. This is only reachable through `fillCargopodWithRandomCargo` when `getRandomCommodity` gives nothing, i.e. no commodities are defined — upstream `Core/Universe.m:3960` ↔ port `Core/Universe.cpp:4456-4460`, `Core/OOCommodities.cpp:410-415`
- ⚠️ **low** — `shipClassForShipDictionary:` (which returned a `Class`) is now `isStationShipDictionary` (returns a bool). `newShipWithName` builds the entity through `makeStation`/`makeProxy` flags instead of `[shipClass alloc]` (beads oo-9ht.175, oo-9ht.183, cited in code). The roles/`isCarrier`/`is_carrier` priority is unchanged, and so is the proxy rule (proxy only when the class would be a plain ShipEntity) — upstream `Core/Universe.m:3699-3707,3777` ↔ port `Core/Universe.cpp:4171-4191,4258`
- ⚠️ **low** — The `universe.unremovedEntity` log line has moved out of `ensureEntityReallyRemoved` into `Entity::~Entity`, just before the call, with the same text and condition (beads oo-9ht.39.26, oo-dpyk8). It still fires for that caller; a direct call to `ensureEntityReallyRemoved` no longer logs — upstream `Core/Universe.m:5128-5130` ↔ port `Core/Universe.cpp:5514-5520`, `Core/Entities/Entity.cpp:124-127`
- ⚠️ **low** — `addDelayedMessage:forCount:afterDelay:`: upstream raised on a nil text (`setObject:nil`). The port leaves `message` out, so the deferred call shows nothing. The delay now comes from `OOScheduleDeferredCall`, not `performSelector:afterDelay:` (bead oo-pvhrh, comment at the call site) — upstream `Core/Universe.m:6250-6253` ↔ port `Core/Universe.cpp:6643-6653`
- Subtle (✅): `update:` collects zombie entities in an `NSMutableSet` upstream, so removal and `universe.zombie` log order is hash order. The port uses a vector, so it is order-found (`Core/Universe.cpp:6941,6951`). `entitiesDeadThisUpdate` and `allStations` likewise change from sets to vectors with `AddIfAbsent`, which only affects release order and the iteration order of `stations()`.
- Subtle (✅): `currentWaypoints` returns a key-sorted `std::map` copy where upstream returned the live `NSMutableDictionary` in hash order. Any caller that enumerates it now sees sorted key order — `Core/Universe.cpp:3903`.
- Subtle (✅): `cargoPodFromTemplate` skips `setCommodity` when the template has no commodity type; upstream sent `setCommodity:nil andAmount:0` — `Core/Universe.cpp:4341-4344`.
- Subtle (✅): `soundNameForCustomSoundKey` caches a nil key (an array entry that is not a string) under `""`, which the code comment documents — `Core/Universe.cpp:6519-6567`.
- Subtle (✅, upstream bug kept): `findOneEntityMatchingPredicate` returns early without `OOJSResumeTimeLimiter()`, exactly as upstream does — `Core/Universe.cpp:6304-6305`.
- Checked equal: the beacon list relinking, the bubble insertion into `sortedEntities` in `addEntity:` and `update:`, the per-frame order in `update:` (repopulate → retain copy → demo management → entity `update` + bubble + AI think → zombies → `updateLinkedLists` → `filterSortedLists` → `findCollisionsAndShadows` → `MaintainLinkedLists`), the session-ID break, the draw loop (visible entities nearest→furthest, drawn furthest→nearest in two vdist passes with the same break plane, fog, lighting and HUD/message order), the frustum quirks (FAR and NEAR planes multiplied by the length, not normalised), the laser and targeting range tests, the `EntityInRange` float narrowing, the `nearestEntity` float distance, the message repeat timing (6.0 s, and `SameMessage` keeps the nil-is-never-equal semantics), and `filterSortedLists`, which a line diff shows identical apart from syntax.
- Out of range: `descriptionForKey` (upstream 7279) and the expansion/RNG helpers are in later parts of the file and are not audited here.

### Universe (part 3: lines 7126-end)

Upstream `src/Core/Universe.m` lines 7126–10137 (`-setGalaxyTo:` … `OOLookUpPluralDescriptionPRIV`) ↔ `Core/Universe.cpp`

**Status:** done — 149 rows: 138 ✅ 6 ⚠️ 2 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[Universe setGalaxyTo:]` (7126) | `Universe::setGalaxyTo(g)` `Core/Universe.cpp:7565` | ✅ |
| `-[Universe setGalaxyTo:andReinit:]` (7131) | `Universe::setGalaxyTo(g, forced)` `Core/Universe.cpp:7574` (names through `SystemPropertyString` `Core/Universe.cpp:940`) | ✅ |
| `-[Universe setSystemTo:]` (7152) | `Universe::setSystemTo` `Core/Universe.cpp:7590` | ✅ |
| `-[Universe currentSystemID]` (7172) | `Universe::currentSystemID` `Core/Universe.cpp:7609` | ✅ |
| `-[Universe descriptions]` (7177) | `Universe::descriptions` `Core/Universe.cpp:7614` (plus a generation counter, C++-only) | ✅ |
| `VerifyDescString()` (7193) | `VerifyDescString` `Core/Universe.cpp:955` | ✅ |
| `VerifyDescArray()` (7201) | `VerifyDescArray` `Core/Universe.cpp:963` | ✅ |
| `VerifyDesc()` (7209) | `VerifyDesc` `Core/Universe.cpp:970` | ✅ |
| `-[Universe verifyDescriptions]` (7223) | `Universe::verifyDescriptions` `Core/Universe.cpp:7632` | ⚠️ |
| `-[Universe loadDescriptions]` (7246) | `Universe::loadDescriptions` `Core/Universe.cpp:7656` | ✅ |
| `-[Universe explosionSetting:]` (7253) | `Universe::explosionSetting` `Core/Universe.cpp:7663` | ✅ |
| `-[Universe scenarios]` (7258) | `Universe::scenarios` `Core/Universe.cpp:7669` | ✅ |
| `-[Universe loadScenarios]` (7263) | `Universe::loadScenarios` `Core/Universe.cpp:7674` | ✅ |
| `-[Universe characters]` (7269) | `Universe::getCharacters` `Core/Universe.cpp:7679` | ✅ |
| `-[Universe missiontext]` (7274) | `Universe::getMissiontext` `Core/Universe.cpp:7684` | ✅ |
| `-[Universe descriptionForKey:]` (7279) | `Universe::descriptionForKey` `Core/Universe.cpp:7689` | ✅ |
| `-[Universe descriptionForArrayKey:index:]` (7284) | `Universe::descriptionForArrayKey` `Core/Universe.cpp:7694` | ✅ |
| `-[Universe descriptionBooleanForKey:]` (7292) | `Universe::descriptionBooleanForKey` `Core/Universe.cpp:7702` | ✅ |
| `-[Universe systemManager]` (7297) | `Universe::getSystemManager` `Core/Universe.cpp:7707` | ✅ |
| `-[Universe keyForPlanetOverridesForSystem:inGalaxy:]` (7302) | `Universe::keyForPlanetOverridesForSystem` `Core/Universe.cpp:7712` | ✅ |
| `-[Universe keyForInterstellarOverridesForSystems:s2:inGalaxy:]` (7307) | `Universe::keyForInterstellarOverridesForSystems` `Core/Universe.cpp:7717` | ✅ |
| `-[Universe generateSystemData:]` (7312) | `Universe::generateSystemData(s)` `Core/Universe.cpp:7722` | ✅ |
| `-[Universe generateSystemData:useCache:]` (7318) | `Universe::generateSystemData(s, bool)` `Core/Universe.cpp:7728` | ✅ |
| `-[Universe currentSystemData]` (7332) | `Universe::currentSystemData` `Core/Universe.cpp:7742` | ✅ |
| `-[Universe inInterstellarSpace]` (7364) | `Universe::inInterstellarSpace` `Core/Universe.cpp:7774` | ✅ |
| `-[Universe setSystemDataKey:value:fromManifest:]` (7371) | `Universe::setSystemDataKey` `Core/Universe.cpp:7781` | ✅ |
| `-[Universe setSystemDataForGalaxy:planet:key:value:fromManifest:forLayer:]` (7376) | `Universe::setSystemDataForGalaxy` `Core/Universe.cpp:7786` | ✅ |
| `-[Universe generateSystemDataForGalaxy:planet:]` (7486) | `Universe::generateSystemDataForGalaxy` `Core/Universe.cpp:7920` | ✅ |
| `-[Universe systemDataKeysForGalaxy:planet:]` (7492) | `Universe::systemDataKeysForGalaxy` `Core/Universe.cpp:7927` | ⚠️ |
| `-[Universe systemDataForGalaxy:planet:key:]` (7498) | `Universe::systemDataForGalaxy` `Core/Universe.cpp:7939` | ✅ |
| `-[Universe getSystemName:]` (7503) | `Universe::getSystemName(sys)` `Core/Universe.cpp:7944` | ✅ |
| `-[Universe getSystemName:forGalaxy:]` (7508) | `Universe::getSystemName(sys, gnum)` `Core/Universe.cpp:7949` | ✅ |
| `-[Universe getSystemGovernment:]` (7513) | `Universe::getSystemGovernment` `Core/Universe.cpp:7954` | ✅ |
| `-[Universe getSystemInhabitants:]` (7518) | `Universe::getSystemInhabitants(sys)` `Core/Universe.cpp:7960` | ✅ |
| `-[Universe getSystemInhabitants:plural:]` (7523) | `Universe::getSystemInhabitants(sys, plural)` `Core/Universe.cpp:7965` | ✅ |
| `-[Universe coordinatesForSystem:]` (7537) | `Universe::coordinatesForSystem` `Core/Universe.cpp:7979` | ✅ |
| `-[Universe findSystemFromName:]` (7542) | `Universe::findSystemFromName` `Core/Universe.cpp:7984` | ✅ |
| `-[Universe findSystemAtCoords:withGalaxy:]` (7559) | `Universe::findSystemAtCoords` `Core/Universe.cpp:7997` | ✅ |
| `-[Universe nearbyDestinationsWithinRange:]` (7565) | `Universe::nearbyDestinationsWithinRange` `Core/Universe.cpp:8052` | ✅ |
| `-[Universe findNeighbouringSystemToCoords:withGalaxy:]` (7590) | `Universe::findNeighbouringSystemToCoords` `Core/Universe.cpp:8075` | ✅ |
| `-[Universe findConnectedSystemAtCoords:withGalaxy:]` (7632) | `Universe::findConnectedSystemAtCoords` `Core/Universe.cpp:8117` | ✅ |
| `-[Universe findSystemNumberAtCoords:withGalaxy:includingHidden:]` (7672) | `Universe::findSystemNumberAtCoords` `Core/Universe.cpp:8157` | ✅ |
| `-[Universe findSystemCoordinatesWithPrefix:]` (7719) | `Universe::findSystemCoordinatesWithPrefix(p_fix)` `Core/Universe.cpp:8204` | ✅ |
| `-[Universe findSystemCoordinatesWithPrefix:exactMatch:]` (7724) | `Universe::findSystemCoordinatesWithPrefix(p_fix, exactMatch)` `Core/Universe.cpp:8209` | ✅ |
| `-[Universe systemsFound]` (7752) | `Universe::systemsFound` `Core/Universe.cpp:8239` | ✅ |
| `-[Universe systemNameIndex:]` (7757) | `Universe::systemNameIndex` `Core/Universe.cpp:8244` | ✅ |
| `-[Universe routeFromSystem:toSystem:optimizedBy:]` (7762) | `Universe::routeFromSystem` `Core/Universe.cpp:8249` | ✅ |
| `-[Universe neighboursToSystem:]` (7885) | `Universe::neighboursToSystem` `Core/Universe.cpp:8372` | ✅ |
| `-[Universe preloadPlanetTexturesForSystem:]` (7928) | `Universe::preloadPlanetTexturesForSystem` `Core/Universe.cpp:8414` (body `#if 0` on both sides) | ✅ |
| `-[Universe globalSettings]` (7960) | `Universe::getGlobalSettings` `Core/Universe.cpp:8445` | ✅ |
| `-[Universe equipmentData]` (7965) | `Universe::getEquipmentData` `Core/Universe.cpp:8450` | ✅ |
| `-[Universe equipmentDataOutfitting]` (7970) | `Universe::getEquipmentDataOutfitting` `Core/Universe.cpp:8455` | ✅ |
| `-[Universe commodityMarket]` (7975) | `Universe::getCommodityMarket` `Core/Universe.cpp:8460` | ✅ |
| `-[Universe timeDescription:]` (7980) | `Universe::timeDescription` `Core/Universe.cpp:8465` | ✅ |
| `-[Universe shortTimeDescription:]` (8007) | `Universe::shortTimeDescription` `Core/Universe.cpp:8496` | ✅ |
| `-[Universe makeSunSkimmer:andSetAI:]` (8041) | `Universe::makeSunSkimmer` `Core/Universe.cpp:8530` | ✅ |
| `-[Universe marketSeed]` (8052) | `Universe::marketSeed` `Core/Universe.cpp:8546` | ✅ |
| `-[Universe loadStationMarkets:]` (8069) | `Universe::loadStationMarkets` `Core/Universe.cpp:8563` | ✅ |
| `-[Universe getStationMarkets]` (8094) | `Universe::getStationMarkets` `Core/Universe.cpp:8593` | ✅ |
| `-[Universe shipsForSaleForSystem:withTL:atTime:]` (8120) | `Universe::shipsForSaleForSystem` `Core/Universe.cpp:8621` (helpers `RemoveKeyAt`/`ContainsKey`/`RemoveOption`/`SetInDict`/`ExpandKeyWith` `Core/Universe.cpp:991-1035`) | ❌ |
| `compareName()` (8486) | `compareName` `Core/Universe.cpp:1048` | ✅ |
| `comparePrice()` (8500) | `comparePrice` `Core/Universe.cpp:1037` | ✅ |
| `-[Universe tradeInValueForCommanderDictionary:]` (8508) | `Universe::tradeInValueForCommanderDictionary` `Core/Universe.cpp:8990` | ✅ |
| `-[Universe brochureDescriptionWithDictionary:standardEquipment:optionalEquipment:]` (8644) | `Universe::brochureDescriptionWithDictionary` `Core/Universe.cpp:9145` | ✅ |
| `-[Universe getWitchspaceExitPosition]` (8744) | `Universe::getWitchspaceExitPosition` `Core/Universe.cpp:9249` | ✅ |
| `-[Universe getWitchspaceExitRotation]` (8749) | `Universe::getWitchspaceExitRotation` `Core/Universe.cpp:9254` | ✅ |
| `-[Universe getSunSkimStartPositionForShip:]` (8768) | `Universe::getSunSkimStartPositionForShip` `Core/Universe.cpp:9273` | ✅ |
| `-[Universe getSunSkimEndPositionForShip:]` (8801) | `Universe::getSunSkimEndPositionForShip` `Core/Universe.cpp:9306` (three `randf()` draws hoisted into locals in left-to-right order, ADR-0063 item 5) | ✅ |
| `-[Universe listBeaconsWithCode:]` (8859) | `Universe::listBeaconsWithCode` `Core/Universe.cpp:9367` (matching `BeaconCodeMatches` `Core/Universe.cpp:238`) | ⚠️ |
| `-[Universe allShipsDoScriptEvent:andReactToAIMessage:]` (8875) | `Universe::allShipsDoScriptEvent` `Core/Universe.cpp:9387` | ✅ |
| `-[Universe gui]` (8898) | `Universe::getGui` `Core/Universe.cpp:9414` | ✅ |
| `-[Universe commLogGUI]` (8903) | `Universe::commLogGUI` `Core/Universe.cpp:9419` | ✅ |
| `-[Universe messageGUI]` (8908) | `Universe::messageGUI` `Core/Universe.cpp:9424` | ✅ |
| `-[Universe clearGUIs]` (8913) | `Universe::clearGUIs` `Core/Universe.cpp:9429` | ✅ |
| `-[Universe resetCommsLogColor]` (8926) | `Universe::resetCommsLogColor` `Core/Universe.cpp:9441` | ❌ |
| `-[Universe setDisplayText:]` (8931) | `Universe::setDisplayText` `Core/Universe.cpp:9446` | ✅ |
| `-[Universe displayGUI]` (8936) | `Universe::getDisplayGUI` `Core/Universe.cpp:9451` | ✅ |
| `-[Universe setDisplayFPS:]` (8941) | `Universe::setDisplayFPS` `Core/Universe.cpp:9456` | ✅ |
| `-[Universe displayFPS]` (8946) | `Universe::getDisplayFPS` `Core/Universe.cpp:9461` | ✅ |
| `-[Universe setAutoSave:]` (8951) | `Universe::setAutoSave` `Core/Universe.cpp:9466` | ✅ |
| `-[Universe autoSave]` (8957) | `Universe::getAutoSave` `Core/Universe.cpp:9472` | ✅ |
| `-[Universe setAutoSaveNow:]` (8962) | `Universe::setAutoSaveNow` `Core/Universe.cpp:9477` | ✅ |
| `-[Universe autoSaveNow]` (8967) | `Universe::getAutoSaveNow` `Core/Universe.cpp:9486` | ✅ |
| `-[Universe setWireframeGraphics:]` (8972) | `Universe::setWireframeGraphics` `Core/Universe.cpp:9491` | ✅ |
| `-[Universe wireframeGraphics]` (8978) | `Universe::getWireframeGraphics` `Core/Universe.cpp:9497` | ✅ |
| `-[Universe reducedDetail]` (8983) | `Universe::reducedDetail` `Core/Universe.cpp:9502` | ✅ |
| `-[Universe setDetailLevelDirectly:]` (8989) | `Universe::setDetailLevelDirectly` `Core/Universe.cpp:9508` | ✅ |
| `-[Universe setDetailLevel:]` (9002) | `Universe::setDetailLevel` `Core/Universe.cpp:9521` | ✅ |
| `-[Universe detailLevel]` (9015) | `Universe::getDetailLevel` `Core/Universe.cpp:9534` | ✅ |
| `-[Universe useShaders]` (9020) | `Universe::useShaders` `Core/Universe.cpp:9539` | ✅ |
| `-[Universe handleOoliteException:]` (9025) | `Universe::handleOoliteException` `Core/Universe.cpp:9544` | ✅ |
| `-[Universe airResistanceFactor]` (9042) | `Universe::getAirResistanceFactor` `Core/Universe.cpp:9564` | ✅ |
| `-[Universe setAirResistanceFactor:]` (9047) | `Universe::setAirResistanceFactor` `Core/Universe.cpp:9569` | ✅ |
| `-[Universe startSpeakingString:]` (9055) | `Universe::startSpeakingString` (Mac arm, not built) `Core/Universe.cpp:9579` | ✅ |
| `-[Universe stopSpeaking]` (9060) | `Universe::stopSpeaking` (Mac arm, not built) `Core/Universe.cpp:9584` | ✅ |
| `-[Universe isSpeaking]` (9069) | `Universe::isSpeaking` (Mac arm, not built) `Core/Universe.cpp:9593` | ✅ |
| `-[Universe startSpeakingString:]` (9076) | `Universe::startSpeakingString` (eSpeak) `Core/Universe.cpp:9600` | ✅ |
| `-[Universe stopSpeaking]` (9087) | `Universe::stopSpeaking` (eSpeak) `Core/Universe.cpp:9607` | ✅ |
| `-[Universe isSpeaking]` (9092) | `Universe::isSpeaking` (eSpeak) `Core/Universe.cpp:9612` | ✅ |
| `-[Universe voiceName:]` (9097) | `Universe::voiceName` `Core/Universe.cpp:9617` | ✅ |
| `-[Universe voiceNumber:]` (9104) | `Universe::voiceNumber` `Core/Universe.cpp:9624` (loop rewritten for clang-tidy, ADR-0056 amendment oo-7jhs5; same search) | ✅ |
| `-[Universe nextVoice:]` (9119) | `Universe::nextVoice` `Core/Universe.cpp:9636` | ✅ |
| `-[Universe prevVoice:]` (9126) | `Universe::prevVoice` `Core/Universe.cpp:9643` | ✅ |
| `-[Universe setVoice:withGenderM:]` (9133) | `Universe::setVoice` `Core/Universe.cpp:9650` | ✅ |
| `-[Universe startSpeakingString:]` (9148) | `Universe::startSpeakingString` (no synth) `Core/Universe.cpp:9665` | ✅ |
| `-[Universe stopSpeaking]` (9152) | `Universe::stopSpeaking` (no synth) `Core/Universe.cpp:9667` | ✅ |
| `-[Universe isSpeaking]` (9156) | `Universe::isSpeaking` (no synth) `Core/Universe.cpp:9669` | ✅ |
| `-[Universe pauseMessageVisible]` (9162) | `Universe::pauseMessageVisible` `Core/Universe.cpp:9675` | ✅ |
| `-[Universe setPauseMessageVisible:]` (9167) | `Universe::setPauseMessageVisible` `Core/Universe.cpp:9680` | ✅ |
| `-[Universe permanentMessageLog]` (9172) | `Universe::permanentMessageLog` `Core/Universe.cpp:9685` | ✅ |
| `-[Universe setPermanentMessageLog:]` (9177) | `Universe::setPermanentMessageLog` `Core/Universe.cpp:9690` | ✅ |
| `-[Universe autoMessageLogBg]` (9182) | `Universe::autoMessageLogBg` `Core/Universe.cpp:9695` | ✅ |
| `-[Universe setAutoMessageLogBg:]` (9187) | `Universe::setAutoMessageLogBg` `Core/Universe.cpp:9700` | ✅ |
| `-[Universe permanentCommLog]` (9192) | `Universe::permanentCommLog` `Core/Universe.cpp:9705` | ✅ |
| `-[Universe setPermanentCommLog:]` (9197) | `Universe::setPermanentCommLog` `Core/Universe.cpp:9710` | ✅ |
| `-[Universe setAutoCommLog:]` (9202) | `Universe::setAutoCommLog` `Core/Universe.cpp:9715` | ✅ |
| `-[Universe blockJSPlayerShipProps]` (9207) | `Universe::blockJSPlayerShipProps` `Core/Universe.cpp:9720` | ✅ |
| `-[Universe setBlockJSPlayerShipProps:]` (9212) | `Universe::setBlockJSPlayerShipProps` `Core/Universe.cpp:9725` | ✅ |
| `-[Universe setUpSettings]` (9221) | `Universe::setUpSettings` `Core/Universe.cpp:9734` | ⚠️ |
| `-[Universe setUpCargoPods]` (9307) | `Universe::setUpCargoPods` `Core/Universe.cpp:9821` | ⚠️ |
| `-[Universe verifyEntitySessionIDs]` (9323) | `Universe::verifyEntitySessionIDs` `Core/Universe.cpp:9838` | ✅ |
| `-[Universe reinitAndShowDemo:]` (9347) | `Universe::reinitAndShowDemo` `Core/Universe.cpp:9864` | ✅ |
| `-[Universe setUpInitialUniverse]` (9451) | `Universe::setUpInitialUniverse` `Core/Universe.cpp:9979` | ✅ |
| `-[Universe randomDistanceWithinScanner]` (9486) | `Universe::randomDistanceWithinScanner` `Core/Universe.cpp:10015` | ✅ |
| `-[Universe randomPlaceWithinScannerFrom:alongRoute:withOffset:]` (9491) | `Universe::randomPlaceWithinScannerFrom` `Core/Universe.cpp:10020` | ✅ |
| `-[Universe fractionalPositionFrom:to:withFraction:]` (9500) | `Universe::fractionalPositionFrom` `Core/Universe.cpp:10029` | ✅ |
| `-[Universe doRemoveEntity:]` (9514) | `Universe::doRemoveEntity` `Core/Universe.cpp:10043` | ✅ |
| `PreloadOneSound()` (9615) | `PreloadOneSound` `Core/Universe.cpp:1064` | ✅ |
| `-[Universe preloadSounds]` (9622) | `Universe::preloadSounds` `Core/Universe.cpp:10143` | ⚠️ |
| `-[Universe populateSpaceFromActiveWormholes]` (9645) | `Universe::populateSpaceFromActiveWormholes` `Core/Universe.cpp:10164` | ✅ |
| `-[Universe chooseStringForKey:inDictionary:]` (9668) | `Universe::chooseStringForKey` `Core/Universe.cpp:10189` | ✅ |
| `-[Universe dumpDebugGraphViz]` (9681) | `Universe::dumpDebugGraphViz` `Core/Universe.cpp:10202` | ✅ |
| `-[Universe dumpSystemDescriptionGraphViz]` (9688) | `Universe::dumpSystemDescriptionGraphViz` `Core/Universe.cpp:10209` | ✅ |
| `-[Universe addNumericRefsInString:toGraphViz:fromNode:nodeCount:]` (9791) | `Universe::addNumericRefsInString` `Core/Universe.cpp:10302` | ✅ |
| `-[Universe runLocalizationTools]` (9842) | `Universe::runLocalizationTools` `Core/Universe.cpp:10347` | ✅ |
| `-[Universe prunePreloadingPlanetMaterials]` (9872) | `Universe::prunePreloadingPlanetMaterials` `Core/Universe.cpp:10372` (upstream `#if NEW_PLANETS`, which is 1) | ✅ |
| `-[Universe loadConditionScripts]` (9885) | `Universe::loadConditionScripts` `Core/Universe.cpp:10384` (`CachedConditionScripts` `Core/Universe.cpp:1095`) | ✅ |
| `-[Universe addConditionScripts:]` (9897) | `Universe::addConditionScripts` `Core/Universe.cpp:10395` | ✅ |
| `-[Universe getConditionScript:]` (9910) | `Universe::getConditionScript` `Core/Universe.cpp:10407` | ✅ |
| `+[OOSound(OOCustomSounds) soundWithCustomSoundKey:]` (9919) | `OOSoundWithCustomSoundKey` `Core/Universe.cpp:1119` | ✅ |
| `-[OOSound(OOCustomSounds) initWithCustomSoundKey:]` (9927) | removed; its one caller now does `oo::retain(OOSoundWithCustomSoundKey(...))` `Core/OOTrumble.cpp:930-931` | ➖ |
| `+[OOSoundSource(OOCustomSounds) sourceWithCustomSoundKey:]` (9937) | removed (no caller upstream or in the port) | ➖ |
| `-[OOSoundSource(OOCustomSounds) initWithCustomSoundKey:]` (9942) | removed (no caller upstream or in the port) | ➖ |
| `-[OOSoundSource(OOCustomSounds) playCustomSoundWithKey:]` (9954) | `OOSoundSourcePlayCustomSoundWithKey` `Core/Universe.cpp:1128` | ✅ |
| `populatorPrioritySort()` (9963) | `populatorPrioritySort` (bool comparator for `std::stable_sort`) `Core/Universe.cpp:917` | ✅ |
| `equipmentSort()` (9976) | `equipmentSort` `Core/Universe.cpp:872` | ✅ |
| `equipmentSortOutfitting()` (10007) | `equipmentSortOutfitting` `Core/Universe.cpp:890` | ✅ |
| `OOLookUpDescriptionPRIV()` (10038) | `cxx_OOLookUpDescriptionPRIV` `Core/Universe.cpp:1137` | ✅ |
| `OOLookUpPluralDescriptionPRIV()` (10047) | `cxx_OOLookUpPluralDescriptionPRIV` `Core/Universe.cpp:1146` | ✅ |

**Differences:**

- ❌ **low** — Shipyard de-duplication can keep a different offer. Upstream gathered the offers in an `NSMutableDictionary` keyed by ship ID, sorted `[resultDictionary allValues]` (hash order) by lower-cased name then price, then dropped every offer equal to the one before it. The port gathers them in a `std::map` (ID byte order) and runs `std::stable_sort`. When two offers tie on name and price (two uncustomised ships of the same model), a different one survives, so the shipyard shows a different ship ID, personality and extras. The RNG draws are unchanged. Upstream `Core/Universe.m:8125,8457,8467-8479` ↔ port `Core/Universe.cpp:8626,8955,8965-8979`.
- ❌ **low** — `resetCommsLogColor` dereferences `comm_log_gui` without a null check. Upstream `[comm_log_gui setTextColor:]` was a no-op on nil. Before `setUpSettings` has built the GUI, the port crashes. Upstream `Core/Universe.m:8928` ↔ port `Core/Universe.cpp:9443`.
- ⚠️ **low** — `verifyDescriptions` walks the keys in byte order (upstream walked them in hash order). This only decides which bad entry is reported before the FATAL exit. The comment says "Byte order of the key (was hash order)". Upstream `Core/Universe.m:7240` ↔ port `Core/Universe.cpp:7648-7653`.
- ⚠️ **low** — `systemDataKeysForGalaxy` returns its keys in byte order (upstream used `-allKeys` hash order). The order reaches `SystemInfo` property enumeration in JS. The comment says "Byte order of the key (was the dictionary's -allKeys, hash order)". Upstream `Core/Universe.m:7494` ↔ port `Core/Universe.cpp:7926-7936`.
- ⚠️ **low** — `listBeaconsWithCode` sorts with `std::stable_sort`, so beacons whose codes compare equal keep their list order; upstream used `-sortedArrayUsingSelector:` with no stability guarantee. The comment says "ORDER-SENSITIVE (decision D)". The match is also done by a full lower-casing (`oo::str::lowercase`) where upstream used `NSCaseInsensitiveSearch`. A nil code still matches and an empty search string still matches nothing. Upstream `Core/Universe.m:8866,8872` ↔ port `Core/Universe.cpp:238-245,9380-9383`.
- ⚠️ **low** — `setUpSettings` sorts `equipmentData` and `equipmentDataOutfitting` with `std::stable_sort`, so equal entries keep their file order; upstream used `-sortedArrayUsingFunction:`. The comment says "ORDER-SENSITIVE". Equipment screens can list tied items in a different order. Upstream `Core/Universe.m:9298-9299` ↔ port `Core/Universe.cpp:9805-9814`.
- ⚠️ **low** — `setUpCargoPods` skips a commodity whose template pod could not be made. Upstream `-setObject:nil forKey:` raised and aborted the reset. The comment says "a nil container was an exception before". Upstream `Core/Universe.m:9312-9316` ↔ port `Core/Universe.cpp:9825-9834`.
- ⚠️ **low** — `preloadSounds` walks `customsounds.plist` keys in byte order (upstream walked them in hash order). Only the preload order changes, which matters for load logging. The comment says "ORDER-SENSITIVE (decision D)". Upstream `Core/Universe.m:9626` ↔ port `Core/Universe.cpp:10142-10158`.
- ➖ — The `OOSoundSource` custom-sound initialisers had no callers and are gone. `-[OOSound initWithCustomSoundKey:]` is replaced at its only call site (trumbles) by a retained `OOSoundWithCustomSoundKey`. Upstream `Core/Universe.m:9927-9952` ↔ port `Core/OOTrumble.cpp:926-932`.
- Subtle (✅, recorded) — `shipsForSaleForSystem` keeps upstream's double removal: a key that fails `conditions` can be removed again by its `condition_script`. `RemoveKeyAt` reproduces the `OORangeException` at index −1 (`Core/Universe.cpp:991-997`).
- Subtle (✅, recorded) — Galaxy/system data: `setGalaxyTo`, `setSystemTo` (`get<unsigned char>` clamps as `oo_unsignedCharForKey` did; the market comes from `generateMarketForSystemWithEconomy`), `generateSystemData` (`"%u %u"` key), the connectivity flood fills, `findSystemNumberAtCoords` integer distance, `routeFromSystem` (same cost model and `maxCost` pruning) and `nearbyDestinationsWithinRange` all match line for line. Every `systemManager` send is null-guarded, as nil messaging was.
- Subtle (✅, recorded) — `descriptionForArrayKey` returns nullopt for a non-string, non-number element. Upstream returned the raw object (an `NSArray`, say) typed as `NSString*`. Upstream `Core/Universe.m:7289` ↔ port `Core/Universe.cpp:7699`.
- Subtle (✅, recorded) — In `setSystemDataForGalaxy`, a non-string `name` value becomes `""` before capitalisation. Upstream sent `-lowercaseString` to it, which raised for an `NSNumber`. Upstream `Core/Universe.m:7409` ↔ port `Core/Universe.cpp:7822-7824`.
- Subtle (✅, recorded) — `tradeInValueForCommanderDictionary` builds `ship_extra_equipment` from the dictionary in byte order (upstream used `-allKeys`). Only integer sums depend on it, so the result is the same. Unsigned wrap-around in `ship_missiles_value - base_missiles_value` and the 1.4/0.9 truncation are kept. Port `Core/Universe.cpp:9025-9029,9135`.
- Not in range — Contract and passenger generation RNG is not in `Universe.m` lines 7126-end. The only equipment RNG here is the shipyard customisation loop above, which draws `randf()`/`Ranrot()` in the same order, after `ranrot_srand(superRand2)`, and restores the full seed at the end.

