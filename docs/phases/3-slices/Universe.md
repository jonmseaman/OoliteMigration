# Slice plan: Universe

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-9ht.155; the class is the frontier giant
oo-pas). Checked by `python3 tools/check-slice-plan.py docs/phases/3-slices/Universe.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Universe.mm` (11,770 lines) + header (896 lines). One class,
  `Universe : OOWeakRefObject` (the game world: entities and their sorted lists, system set-up and
  population, ship creation by role, the frame `update:` and `drawUniverse`, messages and comms,
  descriptions and system data, routes, markets, speech and settings), ~390 methods in one
  `@implementation` with no `#pragma mark` sections, so the slices follow the order of the file.
  Also in the file: the small private class `RouteElement` (route finding; it moves with
  `cxx_routeFromSystem:toSystem:optimizedBy:`, slice 20), an empty `OOUniverseDelayedMessage`, and
  the categories `OOSound (OOCustomSounds)` and `OOSoundSource (OOCustomSounds)`, on converted
  classes' façades (slice 26: their bodies become free functions and the categories one-line
  forwarders in the bridge, amendments oo-6ia4 item 3 and oo-9fwb).
- **The header is charged by use** (`header-decls: per-slice` and `header-names: by-use`, beads
  oo-9ht.140 and oo-9ht.154; see [PlayerEntity.md](PlayerEntity.md)). Charged whole, the header and
  the 407-line preamble leave ~200 lines' headroom over the biggest methods (`filterSortedLists`
  513, `drawUniverse` 482); by use, ~300 lines of the header stay shared and each slice reads the
  members, macros and enums it names.
- **mac-only:** the `OOLITE_MAC_OS_X` arms of `-cxx_startSpeakingString:`, `-stopSpeaking` and
  `-isSpeaking` (NSSpeechSynthesizer) are fenced Mac code: not converted, no story (bead oo-q9l2w,
  ADR-0056 amendment oo-bgmb item 2; Phase 5 rewrites the Mac layer). Their eSpeak and no-speech
  arms convert with slice 24.
- **Order:** after the module pattern seam and this pre-split. Slice 1 first; slices 2-26 each
  wait on slice 1 and are then independent of each other. `Universe` has no Objective-C superclass
  to wait for (`OOWeakRefObject` stays the façade's superclass until oo-9ht.22) and no subclasses.
  The old "convert when nothing else is left" order is not needed: a converted body messages an
  unconverted class through its Objective-C object as every slice does.
- **Verbatim:** the 42 plist / string / sort / description-check helpers with no Objective-C
  (`OOGraphicsDetailFromNumber()` … `StringifiedLabel()`) stay verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9). The helpers that message
  objects move with their callers: `AutoreleaseAll()` with `update:` (slice 17),
  `RemoveFirstWormhole()` with `populateSpaceFromActiveWormholes` (slice 25),
  `MaintainLinkedLists()` with `addEntity:` (slice 13), the station predicates, `RemoveKeyAt()`,
  `PreloadOneSound()`, `CachedConditionScripts()` and the two `cxx_OOLookUp…DescriptionPRIV()`
  functions where the file has them.

## Slice 1: the class shell (frontier)

Slice 1 is the `GameController` / `HeadUpDisplay` class shell
([ADR-0056](../../decisions/0056-phase3-class-conversion-house-style.md) item 5; amendment oo-bj8
item 2's mechanical rewrite) applied to the biggest non-entity class. Its own units are two
(`initWithGameView:`, `dealloc`, ~220 lines), but it moves the class.

1. **`cxx::Universe`** in `Universe.h`: the 122 ivars become data members by the same names, every
   one zero-initialised. The `@public` ones (`sortedEntities`, `n_entities`, the `x/y/z_list_start`
   collision lists, `cursor_row`, `stars_ambient`) are public; the `@private` ones are public too
   while the class is half converted, marked `// private once Universe is converted (oo-pas)`
   (amendment oo-60fwo item 2's reason: the façade's unconverted methods read them). The macros,
   enums and C declarations around the `@interface`, `OOGetUniverse()` / `UNIVERSE` and the two
   `OOSound` category interfaces stay.
2. **The façade** `@interface Universe : OOWeakRefObject` in `Universe+ObjCBridge.h/.mm`, imported
   as the last line of `Universe.h`: every method declaration of the old `@interface` copied
   exactly (~280 selectors, messaged from ~150 files through `UNIVERSE`). The façade's
   `-initWithGameView:` makes and owns the `cxx::Universe` and runs its set-up; `-dealloc` stays in
   the façade. `gSharedUniverse` stays the façade.
3. **The unconverted methods reach the members through the façade's `@public` owning pointer
   `cxx::Universe *_cxxUniverse`** (GameController's `_cxxController`): the compiler-guided rewrite
   inserts `_cxxUniverse->` at every "use of undeclared identifier" error in `Universe.mm`'s
   unconverted methods, and `UNIVERSE->_cxxUniverse->n_entities` where other files read the
   `@public` ivars (ten files: `CollisionRegion`, `Entity`, `ShipEntity`, `ShipEntityAI`,
   `DockEntity`, `DustEntity`, `PlayerEntity`, `PlayerEntityControls`,
   `PlayerEntityLegacyScriptEngine` and `HeadUpDisplay`; `n_entities`, `sortedEntities`, the list
   heads, `cursor_row`, `stars_ambient`). Then build once with poison ivars of the old names. Each later slice deletes
   `_cxxUniverse->` from its own bodies to get them back verbatim. `oo::ToCxx(::Universe *)`
   answers `_cxxUniverse` (oofnd/objc/OOObjCPeer.h identity, as `OOColor`).
4. **Test first:** `tests/unit/core/test_Universe.mm` against the Objective-C API, run on the
   unconverted class, then ported: the accessors and settings a headless universe can answer
   (stand-ins as amendment oo-z1s4 item 4; drawing is pinned by the goldens, not a unit test).
   Slice 1 files the "Delete Universe+ObjCBridge" bead (like oo-9ht.1), which waits on the
   umbrella oo-pas.

## Slices 2-26 (fleet)

Each slice moves its units into `cxx::Universe` as member functions, declares them in the class,
leaves a forwarder on the façade for each, and deletes `_cxxUniverse->` from the moved bodies.
Calls from a converted body to a method of a slice that has not landed stay sends to
`oo::ToObjC(this)`.

| Slice | Content | Own lines | Reads (header part + preamble + own) |
|---|---|---:|---:|
| 1 | class shell (frontier): the C++ class, the façade, the `_cxxUniverse->` rewrite; `initWithGameView:`, `dealloc` | ~218 | ~966 |
| 2 | post-processing FX and colour-blind modes, the target framebuffer, start-up flags, add-ons, the entity list | ~496 | ~1,272 |
| 3 | pause and quit, carrying the player on, set-up from station / witchspace / misjump, witchspace and planet set-up | ~372 | ~1,115 |
| 4 | `setUpSpace`, populating normal space, the system populator | ~501 | ~1,236 |
| 5 | locations by code, lighting, adding ships by role, coordinate systems | ~443 | ~1,175 |
| 6 | legacy positions, adding ships at / near positions and in boxes, spawning, visual effects | ~477 | ~1,195 |
| 7 | adding ships within a radius and on routes, role categories, witchspace entries and effects, break patterns, docking clearance protocol, game over | ~419 | ~1,151 |
| 8 | the intro and demo ships, the ship library text, station and planet look-ups | ~516 | ~1,248 |
| 9 | wormholes, the main station, beacons, waypoints, sky colour, break pattern, making ships by role and name, default AIs, cargo capacity | ~515 | ~1,255 |
| 10 | equipment prices, commodities and cargo pods, the game view and controller, settings, entity lighting, the active view matrix | ~455 | ~1,212 |
| 11 | the view frustum | ~107 | ~814 |
| 12 | `drawUniverse`, framebuffer preparation, frame counters, the view matrix | ~516 | ~1,273 |
| 13 | messages and the watermark, entity look-up, the linked lists, adding and removing entities, demo ships | ~494 | ~1,234 |
| 14 | making demo ships, safe vectors, hazards on route, wreckage, laser hits | ~437 | ~1,162 |
| 15 | player targeting, entities in range, counting and finding ships by role and predicate, time, collisions, view direction | ~473 | ~1,229 |
| 16 | setting the view direction, GUI view mode, custom sounds, screen textures, messages and comms, delayed messages, repopulating | ~403 | ~1,149 |
| 17 | `update:`, time acceleration, ECM visual effects | ~330 | ~1,065 |
| 18 | `filterSortedLists`, `setGalaxyTo:` | ~519 | ~1,226 |
| 19 | galaxy and system changes, descriptions, scenarios, characters, mission text, system data and names, finding systems | ~496 | ~1,269 |
| 20 | neighbouring systems, system-name look-up, routes (with `RouteElement`), planet textures, global and equipment data, the commodity market, time descriptions | ~501 | ~1,236 |
| 21 | short time descriptions, sun skimmers, station markets | ~140 | ~865 |
| 22 | ships for sale (`cxx_shipsForSaleForSystem:withTL:atTime:`) | ~417 | ~1,144 |
| 23 | trade-in value, brochure descriptions, witchspace exit and sun-skim positions, beacons by code, script events to all ships, the GUIs, FPS and autosave | ~517 | ~1,290 |
| 24 | autosave, wireframe and detail levels, shaders, exceptions, air resistance, speech (eSpeak and none), message logs, settings, cargo pods, session IDs | ~382 | ~1,165 |
| 25 | reinitialising and the demo, the initial universe, random positions, removing entities, preloading sounds, wormhole population, graph dumps | ~494 | ~1,228 |
| 26 | graph-viz references, localisation tools, planet-material pruning, condition scripts, the `OOSound` / `OOSoundSource` custom-sound categories, description look-ups | ~286 | ~1,015 |
| verbatim | 42 plain-C helpers | ~415 | not read |
| mac-only | the Mac arms of the three speech methods | ~24 | not read |

## The waiting beads

- **The façade-deletion beads** that waited on oo-pas wait instead on slice 1 and the slices whose
  units name the façade's class, a member or accessor typed with it, or a selector only it
  declares (the list is in oo-pas's notes; e.g. `OOSunEntity` 3-8, 12, 13, 19, 23, 25,
  `SkyEntity` 3-5, 19, `DustEntity` 3, 4, 19, the HUD 12, 13). oo-9ht.22 (`OOWeakRefObject`, the
  façade's superclass) and the phase review and gate keep waiting on the umbrella.
- `OOConstToString.mm` still sends `cxx_descriptions`, `cxx_descriptionForKey:` and
  `commodityMarket` to `UNIVERSE` (oo-3c81's note): those become member calls once slices 19 and 20
  land; no bead waits on it.
- **oo-pas is the umbrella.** It keeps its old dependencies (it was the phase's "last" bead) and
  gains the 26 slices and this pre-split. Its acceptance is every slice's `--slice-done` and the guardrails
  (not a whole-file `@implementation` grep: the fenced Mac speech arms stay Objective-C, as
  `GameController`'s Mac category does).

```slice-plan
source: upstream/oolite/src/Core/Universe.mm
header: upstream/oolite/src/Core/Universe.h
header-decls: per-slice
header-names: by-use

slice 1: class shell: the C++ class, the façade and the _cxxUniverse-> rewrite; initWithGameView:, dealloc
  -[Universe initWithGameView:]
  -[Universe dealloc]

slice 2: post-processing FX and colour-blind modes, the target framebuffer, start-up flags, add-ons, the entity list
  -[Universe bloom]
  -[Universe setBloom:]
  -[Universe currentPostFX]
  -[Universe setCurrentPostFX:]
  -[Universe terminatePostFX:]
  -[Universe nextColorblindMode:]
  -[Universe prevColorblindMode:]
  -[Universe colorblindMode]
  -[Universe initTargetFramebufferWithViewSize:]
  -[Universe deleteOpenGLObjects]
  -[Universe resizeTargetFramebufferWithViewSize:]
  -[Universe drawTargetTextureIntoDefaultFramebuffer]
  -[Universe sessionID]
  -[Universe doingStartUp]
  -[Universe doProcedurallyTexturedPlanets]
  -[Universe setDoProcedurallyTexturedPlanets:]
  -[Universe cxx_useAddOns]
  -[Universe cxx_setUseAddOns:fromSaveGame:]
  -[Universe cxx_setUseAddOns:fromSaveGame:forceReinit:]
  -[Universe entityCount]
  -[Universe debugDumpEntities]
  -[Universe cxx_entityList]

slice 3: pause and quit, carrying the player on, set-up from station / witchspace / misjump, witchspace and planet set-up
  -[Universe pauseGame]
  -[Universe quitGame]
  -[Universe carryPlayerOn:inWormhole:]
  -[Universe setUpUniverseFromStation]
  -[Universe setUpUniverseFromWitchspace]
  -[Universe setUpUniverseFromMisjump]
  -[Universe setUpWitchspace]
  -[Universe setUpWitchspaceBetweenSystem:andSystem:]
  -[Universe setUpPlanet]

slice 4: setUpSpace, populating normal space, the system populator
  -[Universe setUpSpace]
  -[Universe populateNormalSpace]
  -[Universe clearSystemPopulator]
  -[Universe cxx_getPopulatorSettings]
  -[Universe cxx_setPopulatorSetting:to:]
  -[Universe deterministicPopulation]
  -[Universe populateSystemFromDictionariesWithSun:andPlanet:]

slice 5: locations by code, lighting, adding ships by role, coordinate systems
  -[Universe cxx_locationByCode:withSun:andPlanet:]
  -[Universe setAmbientLightLevel:]
  -[Universe ambientLightLevel]
  -[Universe setLighting]
  -[Universe forceLightSwitch]
  -[Universe setMainLightPosition:]
  -[Universe addShipWithRole:launchPos:rfactor:]
  -[Universe cxx_addShipWithRole:nearRouteOneAt:]
  -[Universe cxx_coordinatesForPosition:withCoordinateSystem:returningScalar:]
  -[Universe cxx_expressPosition:inCoordinateSystem:]

slice 6: legacy positions, adding ships at / near positions and in boxes, spawning, visual effects
  -[Universe cxx_legacyPositionFrom:asCoordinateSystem:]
  -[Universe cxx_coordinatesFromCoordinateSystemString:]
  -[Universe cxx_addShipWithRole:nearPosition:withCoordinateSystem:]
  -[Universe cxx_addShips:withRole:atPosition:withCoordinateSystem:]
  -[Universe cxx_addShips:withRole:nearPosition:withCoordinateSystem:]
  -[Universe cxx_addShips:withRole:nearPosition:withCoordinateSystem:withinRadius:]
  -[Universe cxx_addShips:withRole:intoBoundingBox:]
  -[Universe cxx_spawnShip:]
  -[Universe cxx_witchspaceShipWithPrimaryRole:]
  -[Universe cxx_spawnShipWithRole:near:]
  -[Universe cxx_addVisualEffectAt:withKey:]

slice 7: adding ships within a radius and on routes, role categories, witchspace entries and effects, break patterns, the docking clearance protocol, game over
  -[Universe addShipAt:withRole:withinRadius:]
  -[Universe cxx_addShipsAt:withRole:quantity:withinRadius:asGroup:]
  -[Universe cxx_addShipsToRoute:withRole:quantity:routeFraction:asGroup:]
  -[Universe cxx_roleIsPirateVictim:]
  -[Universe cxx_role:isInCategory:]
  -[Universe forceWitchspaceEntries]
  -[Universe addWitchspaceJumpEffectForShip:]
  -[Universe safeWitchspaceExitDistance]
  -[Universe setUpBreakPattern:orientation:forDocking:]
  -[Universe witchspaceBreakPattern]
  -[Universe setWitchspaceBreakPattern:]
  -[Universe dockingClearanceProtocolActive]
  -[Universe setDockingClearanceProtocolActive:]
  -[Universe handleGameOver]

slice 8: the intro and demo ships, the ship library text, station and planet look-ups
  -[Universe setupIntroFirstGo:]
  -[Universe demoShipData]
  -[Universe setLibraryTextForDemoShip]
  -[Universe selectIntro2Previous]
  -[Universe selectIntro2PreviousCategory]
  -[Universe selectIntro2NextCategory]
  -[Universe selectIntro2Next]
  IsCandidateMainStationPredicate()
  IsFriendlyStationPredicate()
  -[Universe station]
  -[Universe cxx_stationWithRole:andPosition:]
  -[Universe stationFriendlyTo:]
  -[Universe planet]
  -[Universe sun]
  -[Universe cxx_planets]
  -[Universe cxx_stations]

slice 9: wormholes, the main station, beacons, waypoints, sky colour, the break pattern, making ships by role and name, default AIs, cargo capacity
  -[Universe cxx_wormholes]
  -[Universe unMagicMainStation]
  -[Universe resetBeacons]
  -[Universe firstBeacon]
  -[Universe setFirstBeacon:]
  -[Universe lastBeacon]
  -[Universe setLastBeacon:]
  -[Universe setNextBeacon:]
  -[Universe clearBeacon:]
  -[Universe cxx_currentWaypoints]
  -[Universe cxx_defineWaypoint:forKey:]
  -[Universe skyClearColor]
  -[Universe setSkyColorRed:green:blue:alpha:]
  -[Universe breakPatternOver]
  -[Universe breakPatternHide]
  -[Universe canInstantiateShip:]
  -[Universe cxx_randomShipKeyForRoleRespectingConditions:]
  -[Universe cxx_newShipWithRole:]
  -[Universe cxx_newVisualEffectWithName:]
  -[Universe cxx_newSubentityWithName:andScaleFactor:]
  -[Universe cxx_newShipWithName:usePlayerProxy:]
  -[Universe cxx_newShipWithName:usePlayerProxy:isSubentity:]
  -[Universe cxx_newShipWithName:usePlayerProxy:isSubentity:andScaleFactor:]
  -[Universe cxx_newDockWithName:andScaleFactor:]
  -[Universe cxx_newShipWithName:]
  -[Universe cxx_shipClassForShipDictionary:]
  -[Universe defaultAIForRole:]
  -[Universe cxx_maxCargoForShip:]

slice 10: equipment prices, commodities and cargo pods, the game view and controller, settings, entity lighting, the active view matrix
  -[Universe cxx_getEquipmentPriceForKey:]
  -[Universe commodities]
  -[Universe reifyCargoPod:]
  -[Universe cargoPodFromTemplate:]
  -[Universe cxx_getContainersOfGoods:scarce:legal:]
  -[Universe cxx_getContainersOfCommodity:commodity_name:]
  -[Universe fillCargopodWithRandomCargo:]
  -[Universe getRandomCommodity]
  -[Universe cxx_getRandomAmountOfCommodity:]
  -[Universe commodityDataForType:]
  -[Universe cxx_displayNameForCommodity:]
  -[Universe cxx_describeCommodity:amount:]
  -[Universe setGameView:]
  -[Universe gameView]
  -[Universe gameController]
  -[Universe cxx_gameSettings]
  -[Universe useGUILightSource:]
  -[Universe lightForEntity:]
  -[Universe getActiveViewMatrix:forwardVector:upVector:]
  -[Universe activeViewMatrix]

slice 11: the view frustum
  -[Universe defineFrustum]
  -[Universe viewFrustumIntersectsSphereAt:withRadius:]

slice 12: drawUniverse, framebuffer preparation, frame counters, the view matrix
  -[Universe drawUniverse]
  -[Universe prepareToRenderIntoDefaultFramebuffer]
  -[Universe framesDoneThisUpdate]
  -[Universe resetFramesDoneThisUpdate]
  -[Universe viewMatrix]

slice 13: messages and the watermark, entity look-up, the linked lists, adding and removing entities, demo ships
  -[Universe drawMessage]
  -[Universe drawWatermarkString:]
  -[Universe entityForUniversalID:]
  MaintainLinkedLists()
  -[Universe addEntity:]
  -[Universe removeEntity:]
  -[Universe ensureEntityReallyRemoved:]
  -[Universe removeAllEntitiesExceptPlayer]
  -[Universe removeDemoShips]

slice 14: making demo ships, safe vectors, hazards on route, wreckage, laser hits
  -[Universe cxx_makeDemoShipWithRole:spinning:]
  -[Universe isVectorClearFromEntity:toDistance:fromPoint:]
  -[Universe hazardOnRouteFromEntity:toDistance:fromPoint:]
  -[Universe getSafeVectorFromEntity:toDistance:fromPoint:]
  -[Universe cxx_addWreckageFrom:withRole:at:scale:lifetime:]
  -[Universe addLaserHitEffectsAt:against:damage:color:]
  -[Universe firstShipHitByLaserFromShip:inDirection:offset:gettingRangeFound:]

slice 15: player targeting, entities in range, counting and finding ships by role and predicate, time, collisions, view direction
  -[Universe firstEntityTargetedByPlayer]
  -[Universe firstEntityTargetedByPlayerPrecisely]
  -[Universe cxx_entitiesWithinRange:ofEntity:]
  -[Universe cxx_countShipsWithRole:inRange:ofEntity:]
  -[Universe cxx_countShipsWithRole:]
  -[Universe cxx_countShipsWithPrimaryRole:inRange:ofEntity:]
  -[Universe countShipsWithScanClass:inRange:ofEntity:]
  -[Universe cxx_countShipsWithPrimaryRole:]
  -[Universe countEntitiesMatchingPredicate:parameter:inRange:ofEntity:]
  -[Universe countShipsMatchingPredicate:parameter:inRange:ofEntity:]
  -[Universe cxx_findEntitiesMatchingPredicate:parameter:inRange:ofEntity:]
  -[Universe findOneEntityMatchingPredicate:parameter:]
  -[Universe cxx_findShipsMatchingPredicate:parameter:inRange:ofEntity:]
  -[Universe cxx_findVisualEffectsMatchingPredicate:parameter:inRange:ofEntity:]
  -[Universe nearestEntityMatchingPredicate:parameter:relativeToEntity:]
  -[Universe nearestShipMatchingPredicate:parameter:relativeToEntity:]
  -[Universe getTime]
  -[Universe getTimeDelta]
  -[Universe findCollisionsAndShadows]
  -[Universe collisionDescription]
  -[Universe dumpCollisions]
  -[Universe viewDirection]

slice 16: setting the view direction, GUI view mode, custom sounds, screen textures, messages and comms, delayed messages, repopulating
  -[Universe setViewDirection:]
  -[Universe enterGUIViewModeWithMouseInteraction:]
  -[Universe soundNameForCustomSoundKey:]
  -[Universe cxx_screenTextureDescriptorForKey:]
  -[Universe cxx_setScreenTextureDescriptorForKey:descriptor:]
  -[Universe clearPreviousMessage]
  -[Universe setMessageGuiBackgroundColor:]
  -[Universe cxx_displayMessage:forCount:]
  -[Universe cxx_displayCountdownMessage:forCount:]
  -[Universe cxx_addDelayedMessage:forCount:afterDelay:]
  -[Universe addDelayedMessage:]
  -[Universe cxx_addMessage:forCount:]
  -[Universe speakWithSubstitutions:]
  -[Universe cxx_addMessage:forCount:forceDisplay:]
  -[Universe cxx_addCommsMessage:forCount:]
  -[Universe cxx_addCommsMessage:forCount:andShowComms:logOnly:]
  -[Universe showCommsLog:]
  -[Universe showGUIMessage:withScroll:andColor:overDuration:]
  -[Universe repopulateSystem]

slice 17: update:, time acceleration, ECM visual effects
  -[Universe update:]
  AutoreleaseAll()
  -[Universe timeAccelerationFactor]
  -[Universe setTimeAccelerationFactor:]
  -[Universe timeAccelerationFactor]
  -[Universe setTimeAccelerationFactor:]
  -[Universe ECMVisualFXEnabled]
  -[Universe setECMVisualFXEnabled:]

slice 18: filterSortedLists, setGalaxyTo:
  -[Universe filterSortedLists]
  -[Universe setGalaxyTo:]

slice 19: galaxy and system changes, descriptions, scenarios, characters, mission text, system data and names, finding systems
  -[Universe setGalaxyTo:andReinit:]
  -[Universe setSystemTo:]
  -[Universe currentSystemID]
  -[Universe cxx_descriptions]
  -[Universe cxx_descriptionsGeneration]
  -[Universe verifyDescriptions]
  -[Universe loadDescriptions]
  -[Universe cxx_explosionSetting:]
  -[Universe cxx_scenarios]
  -[Universe loadScenarios]
  -[Universe cxx_characters]
  -[Universe cxx_missiontext]
  -[Universe cxx_descriptionForKey:]
  -[Universe cxx_descriptionForArrayKey:index:]
  -[Universe descriptionBooleanForKey:]
  -[Universe systemManager]
  -[Universe cxx_keyForPlanetOverridesForSystem:inGalaxy:]
  -[Universe keyForInterstellarOverridesForSystems:s1:inGalaxy:]
  -[Universe cxx_generateSystemData:]
  -[Universe cxx_generateSystemData:useCache:]
  -[Universe cxx_currentSystemData]
  -[Universe inInterstellarSpace]
  -[Universe cxx_setSystemDataKey:value:fromManifest:]
  -[Universe cxx_setSystemDataForGalaxy:planet:key:value:fromManifest:forLayer:]
  -[Universe generateSystemDataForGalaxy:planet:]
  -[Universe cxx_systemDataKeysForGalaxy:planet:]
  -[Universe cxx_systemDataForGalaxy:planet:key:]
  -[Universe cxx_getSystemName:]
  -[Universe cxx_getSystemName:forGalaxy:]
  -[Universe getSystemGovernment:]
  -[Universe cxx_getSystemInhabitants:]
  -[Universe cxx_getSystemInhabitants:plural:]
  -[Universe coordinatesForSystem:]
  -[Universe cxx_findSystemFromName:]
  -[Universe findSystemAtCoords:withGalaxy:]

slice 20: neighbouring systems, system-name look-up, routes (with RouteElement), planet textures, global and equipment data, the commodity market, time descriptions
  -[Universe cxx_nearbyDestinationsWithinRange:]
  -[Universe findNeighbouringSystemToCoords:withGalaxy:]
  -[Universe findConnectedSystemAtCoords:withGalaxy:]
  -[Universe findSystemNumberAtCoords:withGalaxy:includingHidden:]
  -[Universe cxx_findSystemCoordinatesWithPrefix:]
  -[Universe cxx_findSystemCoordinatesWithPrefix:exactMatch:]
  -[Universe systemsFound]
  -[Universe cxx_systemNameIndex:]
  -[Universe cxx_routeFromSystem:toSystem:optimizedBy:]
  +[RouteElement elementWithLocation:parent:cost:distance:time:jumps:]
  -[RouteElement parent]
  -[RouteElement location]
  -[RouteElement cost]
  -[RouteElement distance]
  -[RouteElement time]
  -[RouteElement jumps]
  -[Universe neighboursToSystem:]
  -[Universe preloadPlanetTexturesForSystem:]
  -[Universe cxx_globalSettings]
  -[Universe cxx_equipmentData]
  -[Universe cxx_equipmentDataOutfitting]
  -[Universe commodityMarket]
  -[Universe timeDescription:]

slice 21: short time descriptions, sun skimmers, station markets
  -[Universe cxx_shortTimeDescription:]
  -[Universe makeSunSkimmer:andSetAI:]
  -[Universe marketSeed]
  -[Universe cxx_loadStationMarkets:]
  -[Universe cxx_getStationMarkets]
  RemoveKeyAt()

slice 22: ships for sale (cxx_shipsForSaleForSystem:withTL:atTime:)
  -[Universe cxx_shipsForSaleForSystem:withTL:atTime:]

slice 23: trade-in value, brochure descriptions, witchspace exit and sun-skim positions, beacons by code, script events to all ships, the GUIs, FPS and autosave
  -[Universe cxx_tradeInValueForCommanderDictionary:]
  -[Universe brochureDescriptionWithDictionary:standardEquipment:optionalEquipment:]
  -[Universe getWitchspaceExitPosition]
  -[Universe getWitchspaceExitRotation]
  -[Universe getSunSkimStartPositionForShip:]
  -[Universe getSunSkimEndPositionForShip:]
  -[Universe cxx_listBeaconsWithCode:]
  -[Universe cxx_allShipsDoScriptEvent:andReactToAIMessage:]
  -[Universe gui]
  -[Universe commLogGUI]
  -[Universe messageGUI]
  -[Universe clearGUIs]
  -[Universe resetCommsLogColor]
  -[Universe setDisplayText:]
  -[Universe displayGUI]
  -[Universe setDisplayFPS:]
  -[Universe displayFPS]
  -[Universe setAutoSave:]
  -[Universe autoSave]
  -[Universe setAutoSaveNow:]

slice 24: autosave, wireframe and detail levels, shaders, exceptions, air resistance, speech (eSpeak and none), message logs, settings, cargo pods, session IDs
  -[Universe autoSaveNow]
  -[Universe setWireframeGraphics:]
  -[Universe wireframeGraphics]
  -[Universe reducedDetail]
  -[Universe setDetailLevelDirectly:]
  -[Universe setDetailLevel:]
  -[Universe detailLevel]
  -[Universe useShaders]
  -[Universe handleOoliteException:]
  -[Universe airResistanceFactor]
  -[Universe setAirResistanceFactor:]
  -[Universe cxx_startSpeakingString:]
  -[Universe stopSpeaking]
  -[Universe isSpeaking]
  -[Universe cxx_startSpeakingString:]
  -[Universe stopSpeaking]
  -[Universe isSpeaking]
  -[Universe cxx_voiceName:]
  -[Universe cxx_voiceNumber:]
  -[Universe nextVoice:]
  -[Universe prevVoice:]
  -[Universe setVoice:withGenderM:]
  -[Universe cxx_startSpeakingString:]
  -[Universe stopSpeaking]
  -[Universe isSpeaking]
  -[Universe pauseMessageVisible]
  -[Universe setPauseMessageVisible:]
  -[Universe permanentMessageLog]
  -[Universe setPermanentMessageLog:]
  -[Universe autoMessageLogBg]
  -[Universe setAutoMessageLogBg:]
  -[Universe permanentCommLog]
  -[Universe setPermanentCommLog:]
  -[Universe setAutoCommLog:]
  -[Universe blockJSPlayerShipProps]
  -[Universe setBlockJSPlayerShipProps:]
  -[Universe setUpSettings]
  -[Universe setUpCargoPods]
  -[Universe verifyEntitySessionIDs]

slice 25: reinitialising and the demo, the initial universe, random positions, removing entities, preloading sounds, wormhole population, graph dumps
  -[Universe reinitAndShowDemo:]
  -[Universe setUpInitialUniverse]
  -[Universe randomDistanceWithinScanner]
  -[Universe randomPlaceWithinScannerFrom:alongRoute:withOffset:]
  -[Universe fractionalPositionFrom:to:withFraction:]
  -[Universe doRemoveEntity:]
  PreloadOneSound()
  -[Universe preloadSounds]
  -[Universe populateSpaceFromActiveWormholes]
  RemoveFirstWormhole()
  -[Universe chooseStringForKey:inDictionary:]
  -[Universe dumpDebugGraphViz]
  -[Universe dumpSystemDescriptionGraphViz]

slice 26: graph-viz references, localisation tools, planet-material pruning, condition scripts, the custom-sound categories of OOSound and OOSoundSource, description look-ups
  -[Universe addNumericRefsInString:toGraphViz:fromNode:nodeCount:]
  -[Universe runLocalizationTools]
  -[Universe prunePreloadingPlanetMaterials]
  CachedConditionScripts()
  -[Universe loadConditionScripts]
  -[Universe addConditionScripts:]
  -[Universe cxx_getConditionScript:]
  +[OOSound cxx_soundWithCustomSoundKey:]
  -[OOSound initWithCustomSoundKey:]
  +[OOSoundSource sourceWithCustomSoundKey:]
  -[OOSoundSource initWithCustomSoundKey:]
  -[OOSoundSource cxx_playCustomSoundWithKey:]
  cxx_OOLookUpDescriptionPRIV()
  cxx_OOLookUpPluralDescriptionPRIV()

verbatim: plain C, no Objective-C
  OOGraphicsDetailFromNumber()
  AddIfAbsent()
  StringOrNull()
  ScriptValueDouble()
  ScriptValueFloat()
  ScriptValueInt()
  BeaconCodeMatches()
  DemoShipEntry()
  DemoClassCount()
  DemoClassAt()
  LibrarySetting()
  ExpandText()
  CustomLibraryText()
  FieldsUpToNil()
  EntityInRange()
  SameMessage()
  DictionaryWithContentsOfFile()
  OptionalStringAt()
  OptionalStringIn()
  PListForKeyIn()
  VectorIn()
  HPVectorIn()
  TextOrNull()
  EquipmentExtraInfo()
  ExtraInfoValue()
  equipmentSort()
  equipmentSortOutfitting()
  EquipmentItemString()
  populatorPrioritySort()
  FuzzyBooleanIn()
  SystemPropertyString()
  VerifyDescString()
  VerifyDescArray()
  VerifyDesc()
  ContainsKey()
  RemoveOption()
  SetInDict()
  ExpandKeyWith()
  ExpandKey()
  comparePrice()
  compareName()
  StringifiedLabel()

mac-only: the Mac speech-synthesiser arms (NSSpeechSynthesizer); not converted, Phase 5
  -[Universe cxx_startSpeakingString:]
  -[Universe stopSpeaking]
  -[Universe isSpeaking]
```
