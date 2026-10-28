# Parity findings: Ship, station, dock entities

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## DockEntity

<a id="dockentity"></a>
Upstream `src/Core/Entities/DockEntity.m` ↔ `Core/Entities/DockEntity.cpp`

**Status:** done — 43 rows: 41 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `shipsOnApproach` ivar (`DockEntity.h:34`, `NSMutableDictionary` keyed by `NSNumber`) | `shipsOnApproach` `std::map<unsigned short, …>` `Core/Entities/DockEntity.h:126` | ❌ |
| `-[DockEntity pruneAndCountShipsOnApproach]` (60) | `DockEntity::pruneAndCountShipsOnApproach` `Core/Entities/DockEntity.cpp:332` | ✅ |
| `-[DockEntity abortAllDockings]` (89) | `DockEntity::abortAllDockings` `Core/Entities/DockEntity.cpp:362` | ✅ |
| `-[DockEntity abortAllLaunches]` (129) | `DockEntity::abortAllLaunches` `Core/Entities/DockEntity.cpp:832` | ✅ |
| `-[DockEntity autoDockShipsInQueue:]` (135) | `DockEntity::autoDockShipsInQueue` `Core/Entities/DockEntity.cpp:410` | ✅ |
| `-[DockEntity autoDockShipsOnApproach]` (148) | `DockEntity::autoDockShipsOnApproach` `Core/Entities/DockEntity.cpp:422` | ✅ |
| `-[DockEntity allowsDocking]` (153) | `DockEntity::allowsDocking` `Core/Entities/DockEntity.cpp:121` | ✅ |
| `-[DockEntity setAllowsDocking:]` (158) | `DockEntity::setAllowsDocking` `Core/Entities/DockEntity.cpp:126` | ✅ |
| `-[DockEntity disallowedDockingCollides]` (166) | `DockEntity::disallowedDockingCollides` `Core/Entities/DockEntity.cpp:134` | ✅ |
| `-[DockEntity allowsLaunching]` (171) | `DockEntity::allowsLaunching` `Core/Entities/DockEntity.cpp:139` | ✅ |
| `-[DockEntity setAllowsLaunching:]` (176) | `DockEntity::setAllowsLaunching` `Core/Entities/DockEntity.cpp:144` | ✅ |
| `-[DockEntity setDisallowedDockingCollides:]` (184) | `DockEntity::setDisallowedDockingCollides` `Core/Entities/DockEntity.cpp:152` | ✅ |
| `-[DockEntity setVirtual]` (189) | `DockEntity::setVirtual` `Core/Entities/DockEntity.cpp:157` | ✅ |
| `-[DockEntity canAcceptShipForDocking:]` (194) | `DockEntity::canAcceptShipForDocking` `Core/Entities/DockEntity.cpp:427` | ✅ |
| `-[DockEntity isOffCentre]` (234) | `DockEntity::isOffCentre` `Core/Entities/DockEntity.cpp:162` | ✅ |
| `-[DockEntity dockingInstructionsForShip:]` (246) | `DockEntity::dockingInstructionsForShip` `Core/Entities/DockEntity.cpp:467` | ⚠️ |
| `-[DockEntity addShipToShipsOnApproach:]` (400) | `DockEntity::addShipToShipsOnApproach` `Core/Entities/DockEntity.cpp:631` | ✅ |
| `-[DockEntity noteDockingForShip:]` (522) | `DockEntity::noteDockingForShip` `Core/Entities/DockEntity.cpp:757` | ✅ |
| `-[DockEntity abortDockingForShip:]` (531) | `DockEntity::abortDockingForShip` `Core/Entities/DockEntity.cpp:766` | ✅ |
| `-[DockEntity portUpVectorForShipsBoundingBox:]` (560) | `DockEntity::portUpVectorForShipsBoundingBox` `Core/Entities/DockEntity.cpp:174` | ✅ |
| `-[DockEntity shipIsInDockingQueue:]` (571) | `DockEntity::shipIsInDockingQueue` `Core/Entities/DockEntity.cpp:799` | ✅ |
| `-[DockEntity countOfShipsInDockingQueue]` (591) | `DockEntity::countOfShipsInDockingQueue` `Core/Entities/DockEntity.cpp:185` | ✅ |
| `-[DockEntity countOfShipsInLaunchQueue]` (596) | `DockEntity::countOfShipsInLaunchQueue` `Core/Entities/DockEntity.cpp:190` | ✅ |
| `-[DockEntity shipIsInDockingCorridor:]` (601) | `DockEntity::shipIsInDockingCorridor` `Core/Entities/DockEntity.cpp:838` | ✅ |
| `-[DockEntity pullInShipIfPermitted:]` (773) | `DockEntity::pullInShipIfPermitted` `Core/Entities/DockEntity.cpp:819` | ✅ |
| `-[DockEntity addShipToLaunchQueue:withPriority:]` (782) | `DockEntity::addShipToLaunchQueue` `Core/Entities/DockEntity.cpp:1017` | ✅ |
| `-[DockEntity launchShip:]` (801) | `DockEntity::launchShip` `Core/Entities/DockEntity.cpp:1033` | ✅ |
| `-[DockEntity countOfShipsInLaunchQueueWithPrimaryRole:]` (854) | `DockEntity::countOfShipsInLaunchQueueWithPrimaryRole` `Core/Entities/DockEntity.cpp:1103` | ✅ |
| `-[DockEntity allowsLaunchingOf:]` (865) | `DockEntity::allowsLaunchingOf` `Core/Entities/DockEntity.cpp:1113` | ✅ |
| `-[DockEntity clear]` (894) | `DockEntity::clear` `Core/Entities/DockEntity.cpp:195` | ✅ |
| `-[DockEntity dockingCorridorIsEmpty]` (900) | `DockEntity::dockingCorridorIsEmpty` `Core/Entities/DockEntity.cpp:1142` | ✅ |
| `-[DockEntity clearDockingCorridor]` (966) | `DockEntity::clearDockingCorridor` `Core/Entities/DockEntity.cpp:1210` | ✅ |
| `-[DockEntity setDimensionsAndCorridor:ddc:launching:]` (1032) | `DockEntity::setDimensionsAndCorridor` `Core/Entities/DockEntity.cpp:201` | ✅ |
| `-[DockEntity isDock]` (1058) | `DockEntity::isDock` `Core/Entities/DockEntity.cpp:227` | ✅ |
| `-[DockEntity initWithKey:definition:]` (1063) | `DockEntity::newDockObject` `Core/Entities/DockEntity.cpp:96` + `initDockDefaults` `:104` (queues are value members) | ✅ |
| `-[DockEntity dealloc]` (1082) | `DockEntity::willDealloc` `Core/Entities/DockEntity.cpp:116` | ✅ |
| `-[DockEntity clearIdLocks:]` (1091) | `DockEntity::clearIdLocks` `Core/Entities/DockEntity.cpp:249` | ✅ |
| `-[DockEntity clearAllIdLocks]` (1101) | `DockEntity::clearAllIdLocks` `Core/Entities/DockEntity.cpp:259` | ✅ |
| `-[DockEntity setUpShipFromDictionary:]` (1109) | `DockEntity::setUpShipFromDictionary` `Core/Entities/DockEntity.cpp:267` | ✅ |
| `-[DockEntity update:]` (1124) | `DockEntity::update` `Core/Entities/DockEntity.cpp:282` | ✅ |
| `-[DockEntity noteTakingDamage:from:type:]` (1142) | `DockEntity::noteTakingDamage` `Core/Entities/DockEntity.cpp:301` | ✅ |
| `-[DockEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (1151) | `DockEntity::takeEnergyDamage` `Core/Entities/DockEntity.cpp:310` | ✅ |
| `-[DockEntity drawImmediate:translucent:]` (1161) | `DockEntity::drawImmediate` `Core/Entities/DockEntity.cpp:320` | ✅ |

Checked against the emphasis points: the corridor tables (`corridor_distance/offset/speed/range/rotate`, count 9, final approach index 3), the 16-point offset from `entityPersonalityInt & 0xf`/`0xf0`/`0xf00`, `ssize = MAX(port_depth, 1500)`, the approach thresholds (SCANNER_MAX_RANGE → APPROACH 10000; `< 1000 + radii` → BACK_OFF 5000; wrong side → side point at `collisionRadius + 5000`, range 1000; `> 12500` → APPROACH 10000), `max_allowed_range = 2*range + collision_radius`, the stage-1 half speed inside 1 km, the three-stage id_lock look-ahead with stage 1 never claimed, corridor box `0.90`/`1.25`/×3 warning/×1.5 safety, the `0.9*max.z + 0.1*min.z` pull-in point, the 1500 m (2 250 000) abort radius with the 10 s grace, the launch-queue priority insert at index 0, `STATION_DELAY_BETWEEN_LAUNCHES`/`STATION_LAUNCH_RETRY_INTERVAL`, mass > 1000, 5 km/2 km/`vdp > 0.86`, the 15 s nudge loop and 3 km push. All match the upstream lines.

**Differences:**

- ❌ **low** — The approach queue is a `std::map` (iterates by ascending ship ID). Upstream used an `NSMutableDictionary` (hash order). So the order in which `DOCKING_ABORTED`/`stationWithdrewDockingClearance` go out in prune and abortAllDockings, and the order of `enterDock:` in autoDockShipsInQueue, can differ — upstream `Core/Entities/DockEntity.m:65,96,138` ↔ port `Core/Entities/DockEntity.cpp:336,368,412` (`ShipIDsIn`)
- ⚠️ **low** — The `station.issueDockingInstructions.failed` error logs print the queue/stack as old-style plist text, not GNUstep `-description` (comment cites ADR-0043 item 23) — upstream `Core/Entities/DockEntity.m:294,304` ↔ port `Core/Entities/DockEntity.cpp:516-519,529`
- ✅ subtle — addShipToShipsOnApproach drops upstream's `corridor_length += port_corridor`. That was a dead store: `rz` was already assigned. The port comment cites bead oo-ao2d — upstream `Core/Entities/DockEntity.m:487-488` ↔ port `Core/Entities/DockEntity.cpp:718-720`
- ✅ subtle — dockingInstructionsForShip copies the next-coords dict before sending the comms message, then finds the stack again before erasing or setting `hold_message_given`. If script code removes the ship's entry in the middle, the port skips the edit. Upstream mutated an array that might already be orphaned. The returned instructions are the same — upstream `Core/Entities/DockEntity.m:340-397` ↔ port `Core/Entities/DockEntity.cpp:565-628`
- ✅ subtle — update guards `launchQueue.erase` when the queue was emptied during `launchShip` (upstream `-removeObjectAtIndex:0` would have raised) — upstream `Core/Entities/DockEntity.m:1134` ↔ port `Core/Entities/DockEntity.cpp:292-293`
- ✅ subtle — prune/abort/autoDock use `oo::ToShip(entityForUniversalID)`. If a UID now belongs to a non-ship, the port treats it as dead and removes it. Upstream would have sent ship selectors to it — upstream `Core/Entities/DockEntity.m:66` ↔ port `Core/Entities/DockEntity.cpp:337`

## ShipEntity

<a id="shipentity"></a>

### ShipEntity (part 1: lines 1-3262)

Upstream `src/Core/Entities/ShipEntity.m` lines 1–3262 ↔ `Core/Entities/ShipEntity.cpp`

**Status:** done — 139 rows: 133 ✅ 1 ⚠️ 2 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `calcFuelChargeRate()` (104) | `calcFuelChargeRate` Core/Entities/ShipEntity.cpp:105 | ✅ |
| `-[ShipEntity init]` (174) | — (no default-constructed ship; ships are made only through `oo::NewShipObject` Core/Entities/ShipEntity.cpp:304) | ➖ |
| `-[ShipEntity initBypassForPlayer]` (184) | — (`PlayerEntity` builds its ship part itself, `Core/Entities/PlayerEntity.cpp:433`) | ➖ |
| `-[ShipEntity initWithKey:definition:]` (190) | `oo::NewShipObject` Core/Entities/ShipEntity.cpp:304 + `initShipSetUp` Core/Entities/ShipEntity.cpp:317 + `initWithKey` Core/Entities/ShipEntity.cpp:390 | ✅ |
| `-[ShipEntity setUpFromDictionary:]` (235) | `setUpFromDictionary` Core/Entities/ShipEntity.cpp:602 | ✅ |
| `-[ShipEntity setUpShipFromDictionary:]` (500) | `setUpShipFromDictionary` Core/Entities/ShipEntity.cpp:867 | ✅ |
| `-[ShipEntity setSubIdx:]` (724) | `setSubIdx` Core/Entities/ShipEntity.cpp:1097 | ✅ |
| `-[ShipEntity subIdx]` (729) | `subIdx` Core/Entities/ShipEntity.cpp:1102 | ✅ |
| `-[ShipEntity maxShipSubEntities]` (734) | `maxShipSubEntities` Core/Entities/ShipEntity.cpp:1107 | ✅ |
| `-[ShipEntity repeatString:times:]` (739) | `RepeatString` (anonymous namespace) Core/Entities/ShipEntity.cpp:190 | ✅ |
| `-[ShipEntity serializeShipSubEntities]` (753) | `serializeShipSubEntities` Core/Entities/ShipEntity.cpp:1112 | ✅ |
| `-[ShipEntity deserializeShipSubEntitiesFrom:]` (771) | `deserializeShipSubEntitiesFrom` Core/Entities/ShipEntity.cpp:1129 | ✅ |
| `-[ShipEntity setUpSubEntities]` (790) | `setUpSubEntities` Core/Entities/ShipEntity.cpp:1152 | ✅ |
| `-[ShipEntity frustumRadius]` (822) | `frustumRadius` Core/Entities/ShipEntity.cpp:1186 | ✅ |
| `-[ShipEntity setUpOneSubentity:]` (835) | `setUpOneSubentity` Core/Entities/ShipEntity.cpp:1199 | ✅ |
| `-[ShipEntity setUpOneFlasher:]` (851) | `setUpOneFlasher` Core/Entities/ShipEntity.cpp:1213 | ✅ |
| `-[ShipEntity setUpOneStandardSubentity:asTurret:]` (860) | `setUpOneStandardSubentity` Core/Entities/ShipEntity.cpp:1229 | ✅ |
| `-[ShipEntity isTemplateCargoPod]` (932) | `isTemplateCargoPod` Core/Entities/ShipEntity.cpp:1317 | ✅ |
| `-[ShipEntity setUpCargoType:]` (937) | `setUpCargoType` Core/Entities/ShipEntity.cpp:1322 | ✅ |
| `-[ShipEntity dealloc]` (986) | `shipWillDealloc` Core/Entities/ShipEntity.cpp:338 (+ member destructors) | ✅ |
| `-[ShipEntity removeScript]` (1060) | `removeScript` Core/Entities/ShipEntity.cpp:1367 | ✅ |
| `-[ShipEntity clearSubEntities]` (1066) | `clearSubEntities` Core/Entities/ShipEntity.cpp:1373 | ✅ |
| `-[ShipEntity subEntityRotationalVelocity]` (1080) | `subEntityRotationalVelocity` Core/Entities/ShipEntity.cpp:1389 | ✅ |
| `-[ShipEntity setSubEntityRotationalVelocity:]` (1085) | `setSubEntityRotationalVelocity` Core/Entities/ShipEntity.cpp:1394 | ✅ |
| `-[ShipEntity descriptionComponents]` (1090) | `descriptionComponents` Core/Entities/ShipEntity.cpp:1598 | ✅ |
| `-[ShipEntity shortDescriptionComponents]` (1106) | `shortDescriptionComponents` Core/Entities/ShipEntity.cpp:1399 | ✅ |
| `-[ShipEntity sunGlareFilter]` (1111) | `getSunGlareFilter` Core/Entities/ShipEntity.cpp:1404 | ✅ |
| `-[ShipEntity setSunGlareFilter:]` (1116) | `setSunGlareFilter` Core/Entities/ShipEntity.cpp:1409 | ✅ |
| `-[ShipEntity accuracy]` (1121) | `getAccuracy` Core/Entities/ShipEntity.cpp:1414 | ✅ |
| `-[ShipEntity setAccuracy:]` (1126) | `setAccuracy` Core/Entities/ShipEntity.cpp:1419 | ✅ |
| `-[ShipEntity mesh]` (1145) | `mesh` Core/Entities/ShipEntity.cpp:1438 | ✅ |
| `-[ShipEntity setMesh:]` (1150) | `setMesh` Core/Entities/ShipEntity.cpp:1443 | ✅ |
| `-[ShipEntity totalBoundingBox]` (1159) | `getTotalBoundingBox` Core/Entities/ShipEntity.cpp:1451 | ✅ |
| `-[ShipEntity forwardVector]` (1164) | `forwardVector` Core/Entities/ShipEntity.cpp:1456 | ✅ |
| `-[ShipEntity upVector]` (1169) | `upVector` Core/Entities/ShipEntity.cpp:1461 | ✅ |
| `-[ShipEntity rightVector]` (1174) | `rightVector` Core/Entities/ShipEntity.cpp:1466 | ✅ |
| `-[ShipEntity scriptedMisjump]` (1179) | `scriptedMisjump` Core/Entities/ShipEntity.cpp:1471 | ✅ |
| `-[ShipEntity setScriptedMisjump:]` (1184) | `setScriptedMisjump` Core/Entities/ShipEntity.cpp:1476 | ✅ |
| `-[ShipEntity scriptedMisjumpRange]` (1189) | `scriptedMisjumpRange` Core/Entities/ShipEntity.cpp:1481 | ✅ |
| `-[ShipEntity setScriptedMisjumpRange:]` (1194) | `setScriptedMisjumpRange` Core/Entities/ShipEntity.cpp:1486 | ✅ |
| `-[ShipEntity subEntities]` (1199) | `getSubEntities` Core/Entities/ShipEntity.cpp:1491 | ✅ |
| `-[ShipEntity subEntityCount]` (1204) | `subEntityCount` Core/Entities/ShipEntity.cpp:1496 | ✅ |
| `-[ShipEntity hasSubEntity:]` (1209) | `hasSubEntity` Core/Entities/ShipEntity.cpp:1501 | ✅ |
| `-[ShipEntity subEntityEnumerator]` (1214) | `subEntityEnumerator` Core/Entities/ShipEntity.cpp:1507 | ✅ |
| `-[ShipEntity shipSubEntityEnumerator]` (1219) | `shipSubEntities` Core/Entities/ShipEntity.cpp:1512 | ✅ |
| `-[ShipEntity flasherEnumerator]` (1224) | `flasherEnumerator` Core/Entities/ShipEntity.cpp:1522 | ✅ |
| `-[ShipEntity exhaustEnumerator]` (1229) | `exhausts` Core/Entities/ShipEntity.cpp:1532 | ✅ |
| `-[ShipEntity subEntityTakingDamage]` (1234) | `subEntityTakingDamage` Core/Entities/ShipEntity.cpp:1542 | ✅ |
| `-[ShipEntity setSubEntityTakingDamage:]` (1252) | `setSubEntityTakingDamage` Core/Entities/ShipEntity.cpp:1560 | ✅ |
| `-[ShipEntity shipScript]` (1271) | `shipScript` Core/Entities/ShipEntity.cpp:1578 | ✅ |
| `-[ShipEntity shipAIScript]` (1276) | `shipAIScript` Core/Entities/ShipEntity.cpp:1583 | ✅ |
| `-[ShipEntity shipAIScriptWakeTime]` (1281) | `shipAIScriptWakeTime` Core/Entities/ShipEntity.cpp:1588 | ✅ |
| `-[ShipEntity setAIScriptWakeTime:]` (1286) | `setAIScriptWakeTime` Core/Entities/ShipEntity.cpp:1593 | ✅ |
| `-[ShipEntity findBoundingBoxRelativeToPosition:i:j:k:]` (1291) | `findBoundingBoxRelativeToPosition` Core/Entities/ShipEntity.cpp:1620 | ✅ |
| `-[ShipEntity octree]` (1304) | `getOctree` Core/Entities/ShipEntity.cpp:1629 | ✅ |
| `-[ShipEntity volume]` (1309) | `volume` Core/Entities/ShipEntity.cpp:1634 | ✅ |
| `-[ShipEntity doesHitLine:v1:]` (1314) | `doesHitLine(v0, v1)` Core/Entities/ShipEntity.cpp:1639 | ✅ |
| `-[ShipEntity doesHitLine:v1:hitEntity:]` (1323) | `doesHitLine(v0, v1, hitEntity)` Core/Entities/ShipEntity.cpp:1648 | ✅ |
| `-[ShipEntity doesHitLine:v1:withPosition:i:j:k:]` (1359) | `doesHitLine(v0, v1, o, i, j, k)` Core/Entities/ShipEntity.cpp:1685 | ✅ |
| `-[ShipEntity wasAddedToUniverse]` (1368) | `wasAddedToUniverse` Core/Entities/ShipEntity.cpp:1694 | ✅ |
| `-[ShipEntity wasRemovedFromUniverse]` (1395) | `wasRemovedFromUniverse` Core/Entities/ShipEntity.cpp:1725 | ✅ |
| `-[ShipEntity absoluteTractorPosition]` (1400) | `absoluteTractorPosition` Core/Entities/ShipEntity.cpp:1735 | ✅ |
| `-[ShipEntity beaconCode]` (1405) | `beaconCode` Core/Entities/ShipEntity.cpp:1740 | ✅ |
| `-[ShipEntity setBeaconCode:]` (1410) | `setBeaconCode` Core/Entities/ShipEntity.cpp:1747 | ✅ |
| `-[ShipEntity beaconLabel]` (1427) | `beaconLabel` Core/Entities/ShipEntity.cpp:1764 | ✅ |
| `-[ShipEntity setBeaconLabel:]` (1432) | `setBeaconLabel` Core/Entities/ShipEntity.cpp:1769 | ✅ |
| `-[ShipEntity isVisible]` (1443) | `isVisible` Core/Entities/ShipEntity.cpp:1780 | ✅ |
| `-[ShipEntity isBeacon]` (1448) | `isBeacon` Core/Entities/ShipEntity.cpp:1785 | ✅ |
| `-[ShipEntity beaconDrawable]` (1453) | `beaconDrawable` Core/Entities/ShipEntity.cpp:1790 | ✅ |
| `-[ShipEntity prevBeacon]` (1476) | `prevBeacon` Core/Entities/ShipEntity.cpp:1815 | ✅ |
| `-[ShipEntity nextBeacon]` (1481) | `nextBeacon` Core/Entities/ShipEntity.cpp:1820 | ✅ |
| `-[ShipEntity setPrevBeacon:]` (1486) | `setPrevBeacon` Core/Entities/ShipEntity.cpp:1832 | ✅ |
| `-[ShipEntity setNextBeacon:]` (1494) | `setNextBeacon` Core/Entities/ShipEntity.cpp:1839 | ✅ |
| `-[ShipEntity setIsBoulder:]` (1504) | `setIsBoulder` Core/Entities/ShipEntity.cpp:1846 | ✅ |
| `-[ShipEntity isBoulder]` (1512) | `isBoulder` Core/Entities/ShipEntity.cpp:1854 | ✅ |
| `-[ShipEntity isMinable]` (1517) | `isMinable` Core/Entities/ShipEntity.cpp:1859 | ✅ |
| `-[ShipEntity countsAsKill]` (1527) | `countsAsKill` Core/Entities/ShipEntity.cpp:1869 | ✅ |
| `-[ShipEntity setUpEscorts]` (1532) | `setUpEscorts` Core/Entities/ShipEntity.cpp:1874 | ✅ |
| `-[ShipEntity setUpMixedEscorts]` (1619) | `setUpMixedEscorts` Core/Entities/ShipEntity.cpp:1963 | ✅ |
| `-[ShipEntity setUpOneEscort:inGroup:withRole:atPosition:andCount:]` (1684) | `setUpOneEscort` Core/Entities/ShipEntity.cpp:2103 | ⚠️ |
| `-[ShipEntity shipDataKey]` (1774) | `shipDataKey` Core/Entities/ShipEntity.cpp:2214 | ✅ |
| `-[ShipEntity shipDataKeyAutoRole]` (1779) | `shipDataKeyAutoRole` Core/Entities/ShipEntity.cpp:2219 | ✅ |
| `-[ShipEntity setShipDataKey:]` (1784) | `setShipDataKey` Core/Entities/ShipEntity.cpp:2224 | ✅ |
| `-[ShipEntity shipInfoDictionary]` (1790) | `shipInfoDictionary` Core/Entities/ShipEntity.cpp:2229 | ✅ |
| `-[ShipEntity getWeaponOffsetFrom:withKey:inMode:]` (1797) | `weaponOffsetsFrom` Core/Entities/ShipEntity.cpp:2234 | ✅ |
| `-[ShipEntity aftWeaponOffset]` (1819) | `getAftWeaponOffset` Core/Entities/ShipEntity.cpp:2257 | ✅ |
| `-[ShipEntity forwardWeaponOffset]` (1824) | `getForwardWeaponOffset` Core/Entities/ShipEntity.cpp:2262 | ✅ |
| `-[ShipEntity portWeaponOffset]` (1829) | `getPortWeaponOffset` Core/Entities/ShipEntity.cpp:2267 | ✅ |
| `-[ShipEntity starboardWeaponOffset]` (1834) | `getStarboardWeaponOffset` Core/Entities/ShipEntity.cpp:2272 | ✅ |
| `-[ShipEntity isFrangible]` (1839) | `getIsFrangible` Core/Entities/ShipEntity.cpp:2277 | ✅ |
| `-[ShipEntity suppressFlightNotifications]` (1844) | `suppressFlightNotifications` Core/Entities/ShipEntity.cpp:2282 | ✅ |
| `-[ShipEntity scanClass]` (1849) | `getScanClass` Core/Entities/ShipEntity.cpp:2287 | ✅ |
| `-[ShipEntity canCollide]` (1858) | `canCollide` Core/Entities/ShipEntity.cpp:2296 | ✅ |
| `doOctreesCollide()` (1878) | `doOctreesCollide` Core/Entities/ShipEntity.cpp:2038 | ✅ |
| `-[ShipEntity checkCloseCollisionWith:]` (1944) | `checkCloseCollisionWith` Core/Entities/ShipEntity.cpp:2408 | ✅ |
| `-[ShipEntity findSubentityBoundingBox]` (2002) | `findSubentityBoundingBox` Core/Entities/ShipEntity.cpp:2316 | ✅ |
| `-[ShipEntity absoluteIJKForSubentity]` (2007) | `absoluteIJKForSubentity` Core/Entities/ShipEntity.cpp:2324 | ✅ |
| `-[ShipEntity addSubentityToCollisionRadius:]` (2028) | `addSubentityToCollisionRadius` Core/Entities/ShipEntity.cpp:2346 | ✅ |
| `-[ShipEntity launchPodWithCrew:]` (2047) | `launchPodWithCrew` Core/Entities/ShipEntity.cpp:2365 | ✅ |
| `-[ShipEntity validForAddToUniverse]` (2074) | `validForAddToUniverse` Core/Entities/ShipEntity.cpp:2399 | ✅ |
| `-[ShipEntity update:]` (2083) | `update` Core/Entities/ShipEntity.cpp:2469 | ❌ |
| `-[ShipEntity processBehaviour:]` (2485) | `processBehaviour` Core/Entities/ShipEntity.cpp:2888 | ✅ |
| `-[ShipEntity noteFrustration:]` (2641) | `noteFrustration` Core/Entities/ShipEntity.cpp:3044 | ✅ |
| `-[ShipEntity respondToAttackFrom:becauseOf:]` (2647) | `respondToAttackFrom` Core/Entities/ShipEntity.cpp:3051 | ✅ |
| `-[ShipEntity hasOneEquipmentItem:includeWeapons:whileLoading:]` (2699) | `hasOneEquipmentItem(key, includeWeapons, loading)` Core/Entities/ShipEntity.cpp:3111 | ✅ |
| `-[ShipEntity hasOneEquipmentItem:includeMissiles:whileLoading:]` (2722) | `hasOneEquipmentItemIncludingMissiles` Core/Entities/ShipEntity.cpp:3134 | ✅ |
| `-[ShipEntity hasPrimaryWeapon:]` (2746) | `hasPrimaryWeapon` Core/Entities/ShipEntity.cpp:3157 | ✅ |
| `-[ShipEntity countEquipmentItem:]` (2766) | `countEquipmentItem` Core/Entities/ShipEntity.cpp:3173 | ✅ |
| `-[ShipEntity hasEquipmentItem:includeWeapons:whileLoading:]` (2778) | `hasEquipmentItem(keys, includeWeapons, loading)` Core/Entities/ShipEntity.cpp:3178 | ✅ |
| `-[ShipEntity hasEquipmentItem:]` (2796) | `hasEquipmentItem(keys)` Core/Entities/ShipEntity.cpp:3199 | ✅ |
| `-[ShipEntity hasEquipmentItemProviding:]` (2803) | `hasEquipmentItemProviding` Core/Entities/ShipEntity.cpp:3206 | ✅ |
| `-[ShipEntity equipmentItemProviding:]` (2820) | `equipmentItemProviding` Core/Entities/ShipEntity.cpp:3222 | ✅ |
| `-[ShipEntity hasAllEquipment:includeWeapons:whileLoading:]` (2837) | `hasAllEquipment(keys, includeWeapons, loading)` Core/Entities/ShipEntity.cpp:3238 | ❌ |
| `-[ShipEntity hasAllEquipment:]` (2859) | `hasAllEquipment(keys)` Core/Entities/ShipEntity.cpp:3267 | ✅ |
| `-[ShipEntity hasHyperspaceMotor]` (2864) | `hasHyperspaceMotor` Core/Entities/ShipEntity.cpp:3272 | ✅ |
| `-[ShipEntity hyperspaceSpinTime]` (2869) | `hyperspaceSpinTime` Core/Entities/ShipEntity.cpp:3277 | ✅ |
| `-[ShipEntity setHyperspaceSpinTime:]` (2874) | `setHyperspaceSpinTime` Core/Entities/ShipEntity.cpp:3282 | ✅ |
| `-[ShipEntity canAddEquipment:inContext:]` (2879) | `canAddEquipment` Core/Entities/ShipEntity.cpp:3291 | ✅ |
| `-[ShipEntity weaponFacings]` (2901) | `weaponFacings` Core/Entities/ShipEntity.cpp:3315 | ✅ |
| `-[ShipEntity weaponTypeIDForFacing:strict:]` (2906) | `weaponTypeIDForFacing` Core/Entities/ShipEntity.cpp:3320 | ✅ |
| `-[ShipEntity weaponTypeForFacing:strict:]` (2943) | `weaponTypeForFacing` Core/Entities/ShipEntity.cpp:3358 | ✅ |
| `-[ShipEntity missilesList]` (2950) | `missilesList` Core/Entities/ShipEntity.cpp:3365 | ✅ |
| `-[ShipEntity passengerListForScripting]` (2956) | `passengerListForScripting` Core/Entities/ShipEntity.cpp:3377 | ✅ |
| `-[ShipEntity parcelListForScripting]` (2961) | `parcelListForScripting` Core/Entities/ShipEntity.cpp:3382 | ✅ |
| `-[ShipEntity contractListForScripting]` (2966) | `contractListForScripting` Core/Entities/ShipEntity.cpp:3387 | ✅ |
| `-[ShipEntity generateMissileEquipmentTypeFrom:]` (2971) | `generateMissileEquipmentTypeFrom` Core/Entities/ShipEntity.cpp:3392 | ✅ |
| `-[ShipEntity equipmentListForScripting]` (2993) | `equipmentListForScripting` Core/Entities/ShipEntity.cpp:3414 | ✅ |
| `-[ShipEntity equipmentValidToAdd:inContext:]` (3028) | `equipmentValidToAdd(key, context)` Core/Entities/ShipEntity.cpp:3451 | ✅ |
| `-[ShipEntity equipmentValidToAdd:whileLoading:inContext:]` (3033) | `equipmentValidToAdd(key, loading, context)` Core/Entities/ShipEntity.cpp:3456 | ✅ |
| `-[ShipEntity setWeaponMount:toWeapon:]` (3133) | `setWeaponMount` Core/Entities/ShipEntity.cpp:3564 | ✅ |
| `-[ShipEntity addEquipmentItem:inContext:]` (3165) | `addEquipmentItem(key, context)` Core/Entities/ShipEntity.cpp:3596 | ✅ |
| `-[ShipEntity addEquipmentItem:withValidation:inContext:]` (3170) | `addEquipmentItem(key, validate, context)` Core/Entities/ShipEntity.cpp:3601 | ✅ |
| `-[ShipEntity equipmentEnumerator]` (3253) | `equipmentKeys` Core/Entities/ShipEntity.cpp:3682 | ✅ |
| `-[ShipEntity equipmentCount]` (3258) | `equipmentCount` Core/Entities/ShipEntity.cpp:3687 | ✅ |
| `USEMASC` macro (96) | `USEMASC` Core/Entities/ShipEntity.cpp:99 | ✅ |
| `kOOLogSyntaxAddShips` constant (98) | inlined `"script.debug.syntax.addShips"` Core/Entities/ShipEntity.cpp:13216 | ✅ |
| `kOOLogEntityBehaviourChanged` constant (100) | inlined `"entity.behaviour.changed"` Core/Entities/ShipEntity.cpp:2594 | ✅ |
| `kBoulderRole` macro (1502) | `kBoulderRole` Core/Entities/ShipEntity.cpp:413 | ✅ |
| `MAKE_VECTOR_ARRAY` macro (1795) | — (offsets are a `std::vector<Vector>` built in `weaponOffsetsFrom` Core/Entities/ShipEntity.cpp:2234) | ➖ |

**Differences:**

- ❌ **high** — The NPC subentity update loops only update subentities that are `ShipEntity` (`oo::ToShip(sub.get())`), but upstream sends `-update:` to *every* subentity. So an NPC's (and a demo ship's) `OOFlasherEntity` lights never advance phase, brightness or colour, and its `OOExhaustPlumeEntity` plumes never refresh their track/vertices or `collision_radius`. This happens in all three loops: the demo-ship branch, the launching branch and the main path. By contrast, `PlayerEntity::update` (`Core/Entities/PlayerEntity.cpp:3104-3106`) and `OOVisualEffectEntity` (`Core/Entities/OOVisualEffectEntity.cpp:645-647`) still update every subentity. `Universe` updates only top-level entities (`Core/Universe.cpp:6955`), so nothing else updates them — upstream `Core/Entities/ShipEntity.m:2113-2114`, `:2382-2383`, `:2469-2470` ↔ port `Core/Entities/ShipEntity.cpp:2500-2503`, `:2773-2776`, `:2866-2869`
- ❌ **low** — `hasAllEquipment`: the early `NO` is now "equipment list empty" instead of "`_equipment == nil`". Upstream allocates `_equipment` on the first non-missile add (`ShipEntity.m:3223-3224`) and nils it only in `removeAllEquipment`. So once a ship's list has been emptied by `removeEquipmentItem:`, upstream still checks each key, including through missiles and primary weapons (`includeWeapons:YES` from `equipmentValidToAdd`), and returns YES for an empty key list. The port returns NO. This can change `requires_equipment` checks for weapon/missile requirements — upstream `Core/Entities/ShipEntity.m:2842-2843` ↔ port `Core/Entities/ShipEntity.cpp:3240-3241`
- ⚠️ **low** — `update` close-contact pass: it iterates a `std::map` copy in byte order of the `"%d"` ID text, where upstream used `NSDictionary` hash order. When several contacts leave the sphere in one frame, the `shipTraverse*` script events and AI messages can fire in a different order. The port code comment flags this ("ORDER: byte order of the ID text") — upstream `Core/Entities/ShipEntity.m:2160-2161` ↔ port `Core/Entities/ShipEntity.cpp:2546-2548`
- ⚠️ **low** — `setUpOneEscort`: the port drops the `escortRole &&` guard ahead of the `auto_ai` fuzzy boolean. The port comment says it was always true because both callers pass a role. The `randf()` draw sequence is unchanged — upstream `Core/Entities/ShipEntity.m:1743` ↔ port `Core/Entities/ShipEntity.cpp:2167-2168`
- ✅ note (RNG) — Set-up keeps its draw order. Order: `Ranrot` personality; fuzzy booleans for has_ecm, has_scoop, has_escape_pod, has_cloaking_device, [has_energy_bomb only when > 0], has_fuel_injection, has_military_jammer, has_military_scanner_filter, fragment_chance; subentity creation; has_shield_booster, has_shield_enhancer, no_boulders; `selectMissile` retries; accuracy `randf`; unpiloted. Escort set-up keeps its order too: `newShipWithRole`/`newShipWithName` probe ships, three `randf` per escort, `Ranrot()%11` per mixed-escort slot, `ranrot_rand()&15` for dirty escorts. `OOFuzzyBooleanFromPList` always draws `randf()`, as `OOFuzzyBooleanFromObject` did — upstream `Core/Entities/ShipEntity.m:203-700`, `:1571-1581`, `:1658`, `:1704-1711`, `:1765` ↔ port `Core/Entities/ShipEntity.cpp:395-1066`, `:1913-1923`, `:2002`, `:2121-2128`, `:2203`; `Core/OOPListGameTypes.cpp:135-142`
- ✅ note (shipdata) — Keys, defaults and clamps in `setUpFromDictionary`/`setUpShipFromDictionary` match one for one. Examples: injector_speed_factor clamped to [1, torus factor] with its log; max_missiles ≤ SHIPENTITY_MAX_MISSILES, with the extra Q-mine slot only when `max_missiles` is absent; accuracy −100 sentinel → `randf()*10−5`, mirrored for police/military, missiles clamped to [0,10]; escorts ≤ MAX_ESCORTS, with MAX_ESCORTS pending when only `escort_roles` is given; `beacon_label` falls back to `beacon`; heat_insulation is 2.0 with a heat shield; fuel 0; hyperspace_motor=NO → spin time −1. Every `ShipEntity.h` data member defaults to zero, matching ObjC's zero-filled ivars, so values the set-up does not assign agree — upstream `Core/Entities/ShipEntity.m:235-722` ↔ port `Core/Entities/ShipEntity.cpp:602-1095`, `Core/Entities/ShipEntity.h:1170-1400`
- ✅ note (equipment) — `hasOneEquipmentItem*`, `hasEquipmentItem`, `canAddEquipment`, `equipmentValidToAdd` (every requirement check, the `allowAwardEquipment` condition script, player shipyard options) and `addEquipmentItem` are equivalent. `addEquipmentItem` covers thargon aliasing, damaged-key repair removing every occurrence, the missile/mine path before the weapon/thargon rejections, the equipment_weight vs max_cargo rollback, and the NPC cargo-bay/booster/enhancer adjustments. The port calls `hasOneEquipmentItem` directly where upstream went through `hasEquipmentItem:`; neither is overridden, so dispatch is unchanged. PlayerEntity's `hasOneEquipmentItem:includeMissiles:` was a different selector upstream and stays separate in the port — upstream `Core/Entities/ShipEntity.m:2699-3251` ↔ port `Core/Entities/ShipEntity.cpp:3111-3680`
- ✅ note (lifetime) — `-dealloc` → `shipWillDealloc`: `entityDestroyed`, contact tracking off, parent `subEntityReallyDied`, `clearSubEntities`, equipment removal and group/escort-group `removeShip` keep their order. The string, array and cargo ivars that upstream `DESTROY`ed inline are released afterwards by C++ member destructors. Subentity, escort and pod creation pair `newShip…`/`newSubentity…` with `oo::ReleaseEntity`/`oo::AutoreleaseEntity` as upstream paired them with `release`/`autorelease`. Beacon and damage-subentity weak refs become `oo::WeakRef<Entity>` — upstream `Core/Entities/ShipEntity.m:986-1058`, `:1252-1269`, `:1486-1500`, `:1604-1610` ↔ port `Core/Entities/ShipEntity.cpp:338-385`, `:1560-1576`, `:1832-1844`, `:1947-1954`
- ✅ note — `clearSubEntities`, `wasAddedToUniverse` and `wasRemovedFromUniverse` walk subentities from last to first. This matches GNUstep's `-makeObjectsPerformSelector:` (port comments say so) — upstream `Core/Entities/ShipEntity.m:1068`, `:1390`, `:1397` ↔ port `Core/Entities/ShipEntity.cpp:1376`, `:1717`, `:1729`
- ✅ note — `setBeaconCode`/`setBeaconLabel`: upstream compared the new string with the old by pointer. The port replaces whenever either side is non-nil, so setting the same code again also drops and lazily rebuilds `_beaconDrawable`. The rebuilt icon is identical — upstream `Core/Entities/ShipEntity.m:1415-1420` ↔ port `Core/Entities/ShipEntity.cpp:1753-1757`
- ✅ note — `launchPodWithCrew` passes `""` where upstream passed a nil `escape_pod_role`. Both find no probability set, so the fallback to `escape_pod_model`/`escape-capsule` and the `shipEntity.noEscapePod` log are unchanged. The only caller passes a present crew, so `setCrew` gets an array in both — upstream `Core/Entities/ShipEntity.m:2051-2065` ↔ port `Core/Entities/ShipEntity.cpp:2370-2388`, `:11463`

### ShipEntity (part 2: lines 3263-6521)

Upstream `src/Core/Entities/ShipEntity.m` ↔ `Core/Entities/ShipEntity.cpp` (rows with upstream line 3263..6521 only)

**Status:** done — 175 rows: 172 ✅ 0 ⚠️ 3 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[ShipEntity removeEquipmentItem:]` (3263) | `removeEquipmentItem` Core/Entities/ShipEntity.cpp:3696 (same `_DAMAGED` strip, thargon test, weight/energy/cargo adjustments, damaged-counterpart removal, event after removal, autopilot disengage; virtual, PlayerEntity overrides as upstream) | ✅ |
| `-[ShipEntity removeExternalStore:]` (3333) | `removeExternalStore` Core/Entities/ShipEntity.cpp:3764 (nil id matches nothing, as `isEqualTo:nil`) | ✅ |
| `-[ShipEntity verifiedMissileTypeFromRole:]` (3351) | `verifiedMissileTypeFromRole` Core/Entities/ShipEntity.cpp:3783 | ❌ |
| `-[ShipEntity selectMissile]` (3429) | `selectMissile` Core/Entities/ShipEntity.cpp:3862 (one `randf()` up front, same 0.9/0.8 thresholds, same logs) | ✅ |
| `-[ShipEntity removeAllEquipment]` (3485) | `removeAllEquipment` Core/Entities/ShipEntity.cpp:3918 (nil array → cleared vector) | ✅ |
| `-[ShipEntity removeMissiles]` (3491) | `removeMissiles` Core/Entities/ShipEntity.cpp:3923 | ✅ |
| `-[ShipEntity parcelCount]` (3497) | `parcelCount` Core/Entities/ShipEntity.cpp:3929 | ✅ |
| `-[ShipEntity passengerCount]` (3502) | `passengerCount` Core/Entities/ShipEntity.cpp:3934 | ✅ |
| `-[ShipEntity passengerCapacity]` (3507) | `passengerCapacity` Core/Entities/ShipEntity.cpp:3939 | ✅ |
| `-[ShipEntity missileCount]` (3512) | `missileCount` Core/Entities/ShipEntity.cpp:3944 | ✅ |
| `-[ShipEntity missileCapacity]` (3517) | `missileCapacity` Core/Entities/ShipEntity.cpp:3949 | ✅ |
| `-[ShipEntity extraCargo]` (3522) | `extraCargo` Core/Entities/ShipEntity.cpp:3954 | ✅ |
| `-[ShipEntity hasScoop]` (3528) | `hasScoop` Core/Entities/ShipEntity.cpp:3960 | ✅ |
| `-[ShipEntity hasFuelScoop]` (3533) | `hasFuelScoop` Core/Entities/ShipEntity.cpp:3965 | ✅ |
| `-[ShipEntity hasCargoScoop]` (3539) | `hasCargoScoop` Core/Entities/ShipEntity.cpp:3971 | ✅ |
| `-[ShipEntity hasECM]` (3544) | `hasECM` Core/Entities/ShipEntity.cpp:3976 | ✅ |
| `-[ShipEntity hasCloakingDevice]` (3549) | `hasCloakingDevice` Core/Entities/ShipEntity.cpp:3981 (string PList → `hasOneEquipmentItem`, as upstream's string branch) | ✅ |
| `-[ShipEntity hasMilitaryScannerFilter]` (3555) | `hasMilitaryScannerFilter` Core/Entities/ShipEntity.cpp:3987 | ✅ |
| `-[ShipEntity hasMilitaryJammer]` (3564) | `hasMilitaryJammer` Core/Entities/ShipEntity.cpp:3996 | ✅ |
| `-[ShipEntity hasExpandedCargoBay]` (3573) | `hasExpandedCargoBay` Core/Entities/ShipEntity.cpp:4005 | ✅ |
| `-[ShipEntity hasShieldBooster]` (3579) | `hasShieldBooster` Core/Entities/ShipEntity.cpp:4011 | ✅ |
| `-[ShipEntity hasMilitaryShieldEnhancer]` (3585) | `hasMilitaryShieldEnhancer` Core/Entities/ShipEntity.cpp:4017 | ✅ |
| `-[ShipEntity hasHeatShield]` (3591) | `hasHeatShield` Core/Entities/ShipEntity.cpp:4023 | ✅ |
| `-[ShipEntity hasFuelInjection]` (3596) | `hasFuelInjection` Core/Entities/ShipEntity.cpp:4028 | ✅ |
| `-[ShipEntity hasCascadeMine]` (3601) | `hasCascadeMine` Core/Entities/ShipEntity.cpp:4033 (includeWeapons YES, loading NO) | ✅ |
| `-[ShipEntity hasEscapePod]` (3609) | `hasEscapePod` Core/Entities/ShipEntity.cpp:4041 | ✅ |
| `-[ShipEntity hasDockingComputer]` (3614) | `hasDockingComputer` Core/Entities/ShipEntity.cpp:4046 | ✅ |
| `-[ShipEntity hasGalacticHyperdrive]` (3619) | `hasGalacticHyperdrive` Core/Entities/ShipEntity.cpp:4051 | ✅ |
| `-[ShipEntity shieldBoostFactor]` (3624) | `shieldBoostFactor` Core/Entities/ShipEntity.cpp:4056 | ✅ |
| `-[ShipEntity maxForwardShieldLevel]` (3637) | `maxForwardShieldLevel` Core/Entities/ShipEntity.cpp:4069 (virtual; PlayerEntity overrides) | ✅ |
| `-[ShipEntity maxAftShieldLevel]` (3642) | `maxAftShieldLevel` Core/Entities/ShipEntity.cpp:4074 (virtual; PlayerEntity overrides) | ✅ |
| `-[ShipEntity shieldRechargeRate]` (3647) | `shieldRechargeRate` Core/Entities/ShipEntity.cpp:4079 | ✅ |
| `-[ShipEntity maxHyperspaceDistance]` (3652) | `maxHyperspaceDistance` Core/Entities/ShipEntity.cpp:4084 | ✅ |
| `-[ShipEntity afterburnerFactor]` (3657) | `afterburnerFactor` Core/Entities/ShipEntity.cpp:4094 | ✅ |
| `-[ShipEntity afterburnerRate]` (3662) | `afterburnerRate` Core/Entities/ShipEntity.cpp:4099 | ✅ |
| `-[ShipEntity setAfterburnerFactor:]` (3667) | `setAfterburnerFactor` Core/Entities/ShipEntity.cpp:4104 | ✅ |
| `-[ShipEntity setAfterburnerRate:]` (3672) | `setAfterburnerRate` Core/Entities/ShipEntity.cpp:4109 | ✅ |
| `-[ShipEntity maxThrust]` (3677) | `maxThrust` Core/Entities/ShipEntity.cpp:4114 | ✅ |
| `-[ShipEntity setMaxThrust:]` (3682) | `setMaxThrust` Core/Entities/ShipEntity.cpp:4119 | ✅ |
| `-[ShipEntity thrust]` (3687) | `getThrust` Core/Entities/ShipEntity.cpp:4124 | ✅ |
| `-[ShipEntity behaviour_stop_still:]` (3696) | `behaviour_stop_still` Core/Entities/ShipEntity.cpp:4133 | ✅ |
| `-[ShipEntity behaviour_idle:]` (3704) | `behaviour_idle` Core/Entities/ShipEntity.cpp:4141 | ✅ |
| `-[ShipEntity behaviour_tumble:]` (3720) | `behaviour_tumble` Core/Entities/ShipEntity.cpp:4157 | ✅ |
| `-[ShipEntity behaviour_tractored:]` (3725) | `behaviour_tractored` Core/Entities/ShipEntity.cpp:4162 (same spring terms 0.25/0.5/5.0·tf, 250 m beam, scoop-status switch, thrust 25→0) | ✅ |
| `-[ShipEntity behaviour_track_target:]` (3801) | `behaviour_track_target` Core/Entities/ShipEntity.cpp:4240 | ✅ |
| `-[ShipEntity behaviour_intercept_target:]` (3813) | `behaviour_intercept_target` Core/Entities/ShipEntity.cpp:4252 (96/thrust slowdown, 0.005 turn factor, 0.75 cut, 0.9/10/5 frustration) | ✅ |
| `-[ShipEntity behaviour_attack_break_off_target:]` (3882) | `behaviour_attack_break_off_target` Core/Entities/ShipEntity.cpp:4322 (3×target speed injector cap, 15 s / 3000 m / `fmin(1.6/roll, aspect)` / −0.75 / 0.85 branches identical) | ✅ |
| `-[ShipEntity behaviour_attack_slow_dogfight:]` (3940) | `behaviour_attack_slow_dogfight` Core/Entities/ShipEntity.cpp:4380 | ❌ |
| `-[ShipEntity behaviour_evasive_action:]` (3992) | `behaviour_evasive_action` Core/Entities/ShipEntity.cpp:4432 | ✅ |
| `-[ShipEntity behaviour_attack_target:]` (4034) | `behaviour_attack_target` Core/Entities/ShipEntity.cpp:4478 (subentity weapon scan over `shipSubEntities()`, same ready/usable tests, `randf() < 0.75` only when `accuracy >= IS_SMART`, same jink formula) | ✅ |
| `-[ShipEntity behaviour_attack_broadside:]` (4183) | `behaviour_attack_broadside` Core/Entities/ShipEntity.cpp:4628 | ✅ |
| `-[ShipEntity behaviour_attack_broadside_left:]` (4231) | `behaviour_attack_broadside_left` Core/Entities/ShipEntity.cpp:4676 | ✅ |
| `-[ShipEntity behaviour_attack_broadside_right:]` (4236) | `behaviour_attack_broadside_right` Core/Entities/ShipEntity.cpp:4681 | ✅ |
| `-[ShipEntity behaviour_attack_broadside_target:leftside:]` (4241) | `behaviour_attack_broadside_target` Core/Entities/ShipEntity.cpp:4686 | ✅ |
| `-[ShipEntity behaviour_close_to_broadside_range:]` (4334) | `behaviour_close_to_broadside_range` Core/Entities/ShipEntity.cpp:4779 | ✅ |
| `-[ShipEntity behaviour_close_with_target:]` (4365) | `behaviour_close_with_target` Core/Entities/ShipEntity.cpp:4810 | ✅ |
| `-[ShipEntity behaviour_attack_sniper:]` (4393) | `behaviour_attack_sniper` Core/Entities/ShipEntity.cpp:4842 | ✅ |
| `-[ShipEntity behaviour_fly_to_target_six:]` (4457) | `behaviour_fly_to_target_six` Core/Entities/ShipEntity.cpp:4907 (750 m, `(universalID & 14) > 4`, turret offset 750·acc / spacing 2000+500·acc, 1250 m twelve, 0.85/0.75 frustration) | ✅ |
| `-[ShipEntity behaviour_attack_mining_target:]` (4578) | `behaviour_attack_mining_target` Core/Entities/ShipEntity.cpp:5029 (`== NO_TARGET` → `== nullptr`) | ✅ |
| `-[ShipEntity behaviour_attack_fly_to_target:]` (4607) | `behaviour_attack_fly_to_target` Core/Entities/ShipEntity.cpp:5060 (10000·OUT back-off, all speed branches and 0.99999/−0.999 dodge identical) | ✅ |
| `-[ShipEntity behaviour_attack_fly_from_target:]` (4729) | `behaviour_attack_fly_from_target` Core/Entities/ShipEntity.cpp:5188 (same up-to-four `randf()` calls, same short-circuit order) | ✅ |
| `-[ShipEntity behaviour_running_defense:]` (4797) | `behaviour_running_defense` Core/Entities/ShipEntity.cpp:5257 | ✅ |
| `-[ShipEntity behaviour_flee_target:]` (4836) | `behaviour_flee_target` Core/Entities/ShipEntity.cpp:5297 (qbomb `randf()` only behind the same three guards) | ✅ |
| `-[ShipEntity behaviour_fly_range_from_destination:]` (4899) | `behaviour_fly_range_from_destination` Core/Entities/ShipEntity.cpp:5362 | ✅ |
| `-[ShipEntity behaviour_face_destination:]` (4916) | `behaviour_face_destination` Core/Entities/ShipEntity.cpp:5380 | ✅ |
| `-[ShipEntity behaviour_land_on_planet:]` (4963) | `behaviour_land_on_planet` Core/Entities/ShipEntity.cpp:5429 (`dynamic_cast<OOPlanetEntity*>` + `isPlanet`) | ✅ |
| `-[ShipEntity behaviour_formation_form_up:]` (4998) | `behaviour_formation_form_up` Core/Entities/ShipEntity.cpp:5466 | ✅ |
| `-[ShipEntity behaviour_fly_to_destination:]` (5045) | `behaviour_fly_to_destination` Core/Entities/ShipEntity.cpp:5518 (docking stage ≥ 7 roll-match block, `get<int>("docking_stage")`/`get<float>("speed")` default 0 as `oo_*ForKey:`) | ✅ |
| `-[ShipEntity behaviour_fly_from_destination:]` (5132) | `behaviour_fly_from_destination` Core/Entities/ShipEntity.cpp:5607 | ✅ |
| `-[ShipEntity behaviour_avoid_collision:]` (5151) | `behaviour_avoid_collision` Core/Entities/ShipEntity.cpp:5628 | ✅ |
| `-[ShipEntity behaviour_track_as_turret:]` (5169) | `behaviour_track_as_turret` Core/Entities/ShipEntity.cpp:5647 (`defenseTargets()` snapshot of live targets; non-ship primary target cannot pass `hasHostileTarget` in either) | ✅ |
| `-[ShipEntity behaviour_fly_thru_navpoints:]` (5219) | `behaviour_fly_thru_navpoints` Core/Entities/ShipEntity.cpp:5699 | ✅ |
| `-[ShipEntity behaviour_scripted_ai:]` (5296) | `behaviour_scripted_ai` Core/Entities/ShipEntity.cpp:5777 | ❌ |
| `-[ShipEntity reactionTime]` (5397) | `getReactionTime` Core/Entities/ShipEntity.cpp:5874 | ✅ |
| `-[ShipEntity setReactionTime:]` (5402) | `setReactionTime` Core/Entities/ShipEntity.cpp:5879 | ✅ |
| `-[ShipEntity calculateTargetPosition]` (5407) | `calculateTargetPosition` Core/Entities/ShipEntity.cpp:5884 | ✅ |
| `-[ShipEntity startTrackingCurve]` (5420) | `startTrackingCurve` Core/Entities/ShipEntity.cpp:5902 | ✅ |
| `-[ShipEntity updateTrackingCurve]` (5439) | `updateTrackingCurve` Core/Entities/ShipEntity.cpp:5922 (cloaked jitter `OOHPVectorRandomSpatial(speed·rt·0.02)` same) | ✅ |
| `-[ShipEntity calculateTrackingCurve]` (5464) | `calculateTrackingCurve` Core/Entities/ShipEntity.cpp:5948 (same coefficient expressions and evaluation order) | ✅ |
| `-[ShipEntity drawImmediate:translucent:]` (5486) | `drawImmediate` Core/Entities/ShipEntity.cpp:5970 (subentities via `cxx::OOSubEntityInterface`, which ships, flashers, plumes and visual effects implement) | ✅ |
| `-[ShipEntity drawDebugStuff]` (5523) | `drawDebugStuff` Core/Entities/ShipEntity.cpp:6011 (dead `if (0 && …)` kept) | ✅ |
| `-[ShipEntity drawSubEntityImmediate:translucent:]` (5549) | `drawSubEntityImmediate` Core/Entities/ShipEntity.cpp:6038 | ✅ |
| static scanner colour tables `cargo_color` … `scripted_color` (5575) | Core/Entities/ShipEntity.cpp:415-425 (all 11 tables, same values) | ✅ |
| `-[ShipEntity scannerDisplayColorForShip:isHostile:flash:scannerDisplayColor1:scannerDisplayColor2:scannerDisplayColorH1:scannerDisplayColorH2:]` (5587) | `scannerDisplayColorForShip` Core/Entities/ShipEntity.cpp:6065 | ✅ |
| `-[ShipEntity setScannerDisplayColor1:]` (5685) | `setScannerDisplayColor1` Core/Entities/ShipEntity.cpp:6164 | ✅ |
| `-[ShipEntity setScannerDisplayColor2:]` (5694) | `setScannerDisplayColor2` Core/Entities/ShipEntity.cpp:6172 | ✅ |
| `-[ShipEntity scannerDisplayColor1]` (5703) | `scannerDisplayColor1` Core/Entities/ShipEntity.cpp:6180 | ✅ |
| `-[ShipEntity scannerDisplayColor2]` (5708) | `scannerDisplayColor2` Core/Entities/ShipEntity.cpp:6185 | ✅ |
| `-[ShipEntity setScannerDisplayColorHostile1:]` (5713) | `setScannerDisplayColorHostile1` Core/Entities/ShipEntity.cpp:6190 | ✅ |
| `-[ShipEntity setScannerDisplayColorHostile2:]` (5722) | `setScannerDisplayColorHostile2` Core/Entities/ShipEntity.cpp:6198 | ✅ |
| `-[ShipEntity scannerDisplayColorHostile1]` (5731) | `scannerDisplayColorHostile1` Core/Entities/ShipEntity.cpp:6206 | ✅ |
| `-[ShipEntity scannerDisplayColorHostile2]` (5736) | `scannerDisplayColorHostile2` Core/Entities/ShipEntity.cpp:6211 | ✅ |
| `-[ShipEntity isCloaked]` (5741) | `isCloaked` Core/Entities/ShipEntity.cpp:6216 | ✅ |
| `-[ShipEntity cloakPassive]` (5746) | `getCloakPassive` Core/Entities/ShipEntity.cpp:6221 | ✅ |
| `-[ShipEntity setCloaked:]` (5751) | `setCloaked` Core/Entities/ShipEntity.cpp:6226 | ✅ |
| `-[ShipEntity hasAutoCloak]` (5759) | `hasAutoCloak` Core/Entities/ShipEntity.cpp:6235 | ✅ |
| `-[ShipEntity setAutoCloak:]` (5764) | `setAutoCloak` Core/Entities/ShipEntity.cpp:6240 | ✅ |
| `-[ShipEntity isJammingScanning]` (5769) | `isJammingScanning` Core/Entities/ShipEntity.cpp:6245 | ✅ |
| `-[ShipEntity addSubEntity:]` (5774) | `addSubEntity` Core/Entities/ShipEntity.cpp:6251 (append before `setOwner`, as upstream) | ✅ |
| `-[ShipEntity setOwner:]` (5789) | `setOwner` Core/Entities/ShipEntity.cpp:6265 | ✅ |
| `-[ShipEntity applyThrust:]` (5803) | `applyThrust` Core/Entities/ShipEntity.cpp:6281 (same Newtonian brake, tumble early-out, speed clamp, fuel accumulator loop) | ✅ |
| `-[ShipEntity orientationChanged]` (5851) | `orientationChanged` Core/Entities/ShipEntity.cpp:6330 | ✅ |
| `-[ShipEntity applyRoll:andClimb:]` (5860) | `applyRoll(roll, climb)` Core/Entities/ShipEntity.cpp:6344 | ✅ |
| `-[ShipEntity applyRoll:climb:andYaw:]` (5876) | `applyRoll(roll, climb, yaw)` Core/Entities/ShipEntity.cpp:6361 | ✅ |
| `-[ShipEntity applyAttitudeChanges:]` (5894) | `applyAttitudeChanges` Core/Entities/ShipEntity.cpp:6380 (virtual; PlayerEntity overrides) | ✅ |
| `-[ShipEntity avoidCollision]` (5899) | `avoidCollision` Core/Entities/ShipEntity.cpp:6386 (previousCondition keeps integer behaviour, float range/speed, weak target, HPVector) | ✅ |
| `-[ShipEntity resumePostProximityAlert]` (5933) | `resumePostProximityAlert` Core/Entities/ShipEntity.cpp:6416 | ✅ |
| `-[ShipEntity messageTime]` (5955) | `getMessageTime` Core/Entities/ShipEntity.cpp:6438 | ✅ |
| `-[ShipEntity setMessageTime:]` (5960) | `setMessageTime` Core/Entities/ShipEntity.cpp:6443 | ✅ |
| `-[ShipEntity group]` (5965) | `group` Core/Entities/ShipEntity.cpp:6448 | ✅ |
| `-[ShipEntity setGroup:]` (5970) | `setGroup` Core/Entities/ShipEntity.cpp:6453 | ✅ |
| `-[ShipEntity escortGroup]` (5986) | `escortGroup` Core/Entities/ShipEntity.cpp:6473 | ✅ |
| `-[ShipEntity setEscortGroup:]` (5996) | `setEscortGroup` Core/Entities/ShipEntity.cpp:6485 | ✅ |
| `-[ShipEntity rawEscortGroup]` (6007) | `rawEscortGroup` Core/Entities/ShipEntity.cpp:6497 (debug-monitor only in both) | ✅ |
| `-[ShipEntity stationGroup]` (6013) | `stationGroup` Core/Entities/ShipEntity.cpp:6503 | ✅ |
| `-[ShipEntity hasEscorts]` (6023) | `hasEscorts` Core/Entities/ShipEntity.cpp:6515 | ✅ |
| `-[ShipEntity escortEnumerator]` (6030) | `escorts` Core/Entities/ShipEntity.cpp:6522 (member snapshot excluding self) | ✅ |
| `-[ShipEntity escortArray]` (6037) | `escortArray` Core/Entities/ShipEntity.cpp:6538 | ✅ |
| `-[ShipEntity escortCount]` (6044) | `escortCount` Core/Entities/ShipEntity.cpp:6544 | ✅ |
| `-[ShipEntity pendingEscortCount]` (6051) | `pendingEscortCount` Core/Entities/ShipEntity.cpp:6551 | ✅ |
| `-[ShipEntity setPendingEscortCount:]` (6056) | `setPendingEscortCount` Core/Entities/ShipEntity.cpp:6556 | ✅ |
| `-[ShipEntity maxEscortCount]` (6061) | `maxEscortCount` Core/Entities/ShipEntity.cpp:6561 | ✅ |
| `-[ShipEntity setMaxEscortCount:]` (6066) | `setMaxEscortCount` Core/Entities/ShipEntity.cpp:6566 | ✅ |
| `-[ShipEntity turretCount]` (6071) | `turretCount` Core/Entities/ShipEntity.cpp:6571 | ✅ |
| `-[ShipEntity proximityAlert]` (6084) | `proximityAlert` Core/Entities/ShipEntity.cpp:6584 | ✅ |
| `-[ShipEntity setProximityAlert:]` (6093) | `setProximityAlert` Core/Entities/ShipEntity.cpp:6594 (mass 2000, ×0.25·max/speed forward zone, subtended-angle tie-break identical) | ✅ |
| `-[ShipEntity name]` (6143) | `getName` Core/Entities/ShipEntity.cpp:6644 | ✅ |
| `-[ShipEntity shipUniqueName]` (6148) | `getShipUniqueName` Core/Entities/ShipEntity.cpp:6649 | ✅ |
| `-[ShipEntity shipClassName]` (6153) | `getShipClassName` Core/Entities/ShipEntity.cpp:6654 | ✅ |
| `-[ShipEntity displayName]` (6158) | `getDisplayName` Core/Entities/ShipEntity.cpp:6659 (nil name → "(null)" as `%@`) | ✅ |
| `-[ShipEntity scanDescriptionForScripting]` (6179) | `scanDescriptionForScripting` Core/Entities/ShipEntity.cpp:6681 | ✅ |
| `-[ShipEntity scanDescription]` (6184) | `scanDescription` Core/Entities/ShipEntity.cpp:6686 (`oo_stringAtIndex:` string-or-number semantics kept) | ✅ |
| `-[ShipEntity setName:]` (6219) | `setName` Core/Entities/ShipEntity.cpp:6727 (virtual; PlayerEntity overrides) | ✅ |
| `-[ShipEntity setShipUniqueName:]` (6225) | `setShipUniqueName` Core/Entities/ShipEntity.cpp:6732 | ✅ |
| `-[ShipEntity setShipClassName:]` (6231) | `setShipClassName` Core/Entities/ShipEntity.cpp:6737 | ✅ |
| `-[ShipEntity setDisplayName:]` (6237) | `setDisplayName` Core/Entities/ShipEntity.cpp:6742 | ✅ |
| `-[ShipEntity setScanDescription:]` (6243) | `setScanDescription` Core/Entities/ShipEntity.cpp:6747 | ✅ |
| `-[ShipEntity identFromShip:]` (6249) | `identFromShip` Core/Entities/ShipEntity.cpp:6756 | ✅ |
| `-[ShipEntity hasRole:]` (6257) | `hasRole` Core/Entities/ShipEntity.cpp:6765 | ✅ |
| `-[ShipEntity roleSet]` (6262) | `getRoleSet` Core/Entities/ShipEntity.cpp:6773 (nil primary role → "" which `roleSetWithAddedRoleIfNotSet` ignores, as nil) | ✅ |
| `-[ShipEntity addRole:]` (6269) | `addRole(role)` Core/Entities/ShipEntity.cpp:6787 | ✅ |
| `-[ShipEntity addRole:withProbability:]` (6274) | `addRole(role, probability)` Core/Entities/ShipEntity.cpp:6793 | ✅ |
| `-[ShipEntity removeRole:]` (6289) | `removeRole` Core/Entities/ShipEntity.cpp:6808 | ✅ |
| `-[ShipEntity primaryRole]` (6300) | `getPrimaryRole` Core/Entities/ShipEntity.cpp:6819 (same `ship.noPrimaryRole` log) | ✅ |
| `-[ShipEntity setPrimaryRole:]` (6314) | `setPrimaryRole` Core/Entities/ShipEntity.cpp:6833 | ✅ |
| `-[ShipEntity hasPrimaryRole:]` (6322) | `hasPrimaryRole` Core/Entities/ShipEntity.cpp:6838 | ✅ |
| `-[ShipEntity isPolice]` (6327) | `isPolice` Core/Entities/ShipEntity.cpp:6844 | ✅ |
| `-[ShipEntity isThargoid]` (6333) | `isThargoid` Core/Entities/ShipEntity.cpp:6851 | ✅ |
| `-[ShipEntity isTrader]` (6338) | `isTrader` Core/Entities/ShipEntity.cpp:6857 | ✅ |
| `-[ShipEntity isPirate]` (6343) | `isPirate` Core/Entities/ShipEntity.cpp:6863 | ✅ |
| `-[ShipEntity isMissile]` (6348) | `getIsMissile` Core/Entities/ShipEntity.cpp:6869 | ✅ |
| `-[ShipEntity isMine]` (6353) | `isMine` Core/Entities/ShipEntity.cpp:6875 | ✅ |
| `-[ShipEntity isWeapon]` (6358) | `isWeapon` Core/Entities/ShipEntity.cpp:6881 | ✅ |
| `-[ShipEntity isEscort]` (6363) | `isEscort` Core/Entities/ShipEntity.cpp:6887 | ✅ |
| `-[ShipEntity isShuttle]` (6368) | `isShuttle` Core/Entities/ShipEntity.cpp:6893 | ✅ |
| `-[ShipEntity isTurret]` (6373) | `isTurret` Core/Entities/ShipEntity.cpp:6899 | ✅ |
| `-[ShipEntity isPirateVictim]` (6378) | `isPirateVictim` Core/Entities/ShipEntity.cpp:6904 | ✅ |
| `-[ShipEntity isExplicitlyUnpiloted]` (6383) | `isExplicitlyUnpiloted` Core/Entities/ShipEntity.cpp:6910 | ✅ |
| `-[ShipEntity isUnpiloted]` (6388) | `isUnpiloted` Core/Entities/ShipEntity.cpp:6932 (virtual; StationEntity overrides) | ✅ |
| `IsBehaviourHostile()` (6393) | `IsBehaviourHostile` Core/Entities/ShipEntity.cpp:427 (same case list, same unreachable tail) | ✅ |
| `-[ShipEntity hasHostileTarget]` (6425) | `hasHostileTarget` Core/Entities/ShipEntity.cpp:6939 | ✅ |
| `-[ShipEntity isHostileTo:]` (6441) | `isHostileTo` Core/Entities/ShipEntity.cpp:6956 | ✅ |
| `-[ShipEntity weaponRange]` (6446) | `getWeaponRange` Core/Entities/ShipEntity.cpp:6962 | ✅ |
| `-[ShipEntity setWeaponRange:]` (6451) | `setWeaponRange` Core/Entities/ShipEntity.cpp:6967 | ✅ |
| `-[ShipEntity setWeaponDataFromType:]` (6456) | `setWeaponDataFromType` Core/Entities/ShipEntity.cpp:6972 (nil type → zeros, as nil messaging) | ✅ |
| `-[ShipEntity energyRechargeRate]` (6472) | `energyRechargeRate` Core/Entities/ShipEntity.cpp:6989 | ✅ |
| `-[ShipEntity setEnergyRechargeRate:]` (6477) | `setEnergyRechargeRate` Core/Entities/ShipEntity.cpp:6994 | ✅ |
| `-[ShipEntity weaponRechargeRate]` (6482) | `weaponRechargeRate` Core/Entities/ShipEntity.cpp:6999 | ✅ |
| `-[ShipEntity setWeaponRechargeRate:]` (6487) | `setWeaponRechargeRate` Core/Entities/ShipEntity.cpp:7004 | ✅ |
| `-[ShipEntity setWeaponEnergy:]` (6492) | `setWeaponEnergy` Core/Entities/ShipEntity.cpp:7009 | ✅ |
| `-[ShipEntity currentWeaponFacing]` (6497) | `getCurrentWeaponFacing` Core/Entities/ShipEntity.cpp:7014 | ✅ |
| `-[ShipEntity scannerRange]` (6502) | `getScannerRange` Core/Entities/ShipEntity.cpp:7019 | ✅ |
| `-[ShipEntity setScannerRange:]` (6507) | `setScannerRange` Core/Entities/ShipEntity.cpp:7024 | ✅ |
| `-[ShipEntity reference]` (6512) | `getReference` Core/Entities/ShipEntity.cpp:7029 | ✅ |
| `-[ShipEntity setReference:]` (6517) | `setReference` Core/Entities/ShipEntity.cpp:7034 | ✅ |

**Differences:**

- ❌ **low** — Random-missile role pick iterates the missile ship's roles in a different order. Upstream walks `[[missile roleSet] roles]`, an `NSSet` in hash order. The port walks `OORoleSet::roles()`, which is in `std::map` order (alphabetical). When a "missile"-role ship has more than one role that names a missile/mine equipment type, a different type can be registered and fitted — upstream `Core/Entities/ShipEntity.m:3394` ↔ port `Core/Entities/ShipEntity.cpp:3826` (`Core/OORoleSet.cpp:138`)
- ❌ **low** — `behaviour_attack_slow_dogfight` reads `target->collision_radius` through `oo::ToShip(primaryTarget())`, a `dynamic_cast` that is null for a non-ship target. Upstream reads the ivar from any `Entity` (for example a wormhole, which `isValidTarget:` can accept). In the port that case is a null dereference (crash), not a range test — upstream `Core/Entities/ShipEntity.m:3951-3953` ↔ port `Core/Entities/ShipEntity.cpp:4391-4393`
- ❌ **low** — `behaviour_scripted_ai` given a JS return value that is an object but not a dictionary (for example an Array). Upstream converts it to an `NSArray` and then sends it `objectForKey:`, which raises. The port's `PList::find` returns null, so every stick and speed reads 0 and the ship coasts with its sticks centred — upstream `Core/Entities/ShipEntity.m:5327-5331` ↔ port `Core/Entities/ShipEntity.cpp:5804-5811`
- ✅ **note** — Several upstream raw casts `(ShipEntity*)[self owner]` / `[self primaryTarget]` became `oo::ToShip` (`dynamic_cast`): `behaviour_evasive_action`, `behaviour_attack_fly_from_target` (non-ship target speed reads 0), `behaviour_formation_form_up` (non-ship owner takes the `noteFrustration` path, not `pitching_over`), and `behaviour_intercept_target` (upstream would raise on `cargoType`). None is reachable with the shipped data paths: escort owners are ships, and wormholes have zero speed — port `Core/Entities/ShipEntity.cpp:4441`, `:5222`, `:5470`, `:4265`
- ✅ **note** — Every numeric constant these bodies use (`COMBAT_*`, `COMBAT_AI_*`, `MIN_FUEL`, `TRACTOR_FORCE`, `SHIP_THRUST_FACTOR`, `PROXIMITY_AVOID_DISTANCE_FACTOR`, `MAX_COS`/`MAX_COS2`, `MAX_LANDING_SPEED2`, `BASELINE_SHIELD_LEVEL`, `MAX_JUMP_RANGE`, `NPC_MAX_WEAPON_TEMP`, `WEAPON_COOLING_CUTOUT`) has the same `#define` value in the port. The `randf()` call sites and their short-circuit guards also match in `selectMissile`, `behaviour_attack_target`, `behaviour_attack_fly_from_target`, `behaviour_flee_target` and `drawImmediate`, and so does the `OOHPVectorRandomSpatial` site in `updateTrackingCurve`. So the RNG draw sequence is the same.

### ShipEntity (part 3: lines 6522-9808)

Upstream `src/Core/Entities/ShipEntity.m` lines 6522–9808 ↔ `Core/Entities/ShipEntity.cpp`

**Status:** done — 199 rows: 194 ✅ 1 ⚠️ 4 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[ShipEntity reportAIMessages]` (6522) | `getReportAIMessages` Core/Entities/ShipEntity.cpp:7039 | ✅ |
| `-[ShipEntity setReportAIMessages:]` (6527) | `setReportAIMessages` Core/Entities/ShipEntity.cpp:7044 | ✅ |
| `-[ShipEntity transitionToAegisNone]` (6532) | `transitionToAegisNone` Core/Entities/ShipEntity.cpp:7049 | ✅ |
| `SurfaceDistanceSqaredV()` (6553) | `SurfaceDistanceSqaredV` (anonymous namespace) Core/Entities/ShipEntity.cpp:460 | ✅ |
| `SurfaceDistanceSqared()` (6563) | `SurfaceDistanceSqared` (anonymous namespace) Core/Entities/ShipEntity.cpp:470 | ✅ |
| `ComparePlanetsBySurfaceDistance()` (6568) | `ComparePlanetsBySurfaceDistance` (anonymous namespace) Core/Entities/ShipEntity.cpp:475 | ✅ |
| `-[ShipEntity findNearestPlanet]` (6585) | `findNearestPlanet` Core/Entities/ShipEntity.cpp:7074 | ✅ |
| `-[ShipEntity findNearestStellarBody]` (6614) | `findNearestStellarBody` Core/Entities/ShipEntity.cpp:7105 | ✅ |
| `-[ShipEntity findNearestPlanetExcludingMoons]` (6628) | `findNearestPlanetExcludingMoons` Core/Entities/ShipEntity.cpp:7120 | ✅ |
| `-[ShipEntity checkForAegis]` (6654) | `checkForAegis` Core/Entities/ShipEntity.cpp:7147 | ✅ |
| `-[ShipEntity forceAegisCheck]` (6784) | `forceAegisCheck` Core/Entities/ShipEntity.cpp:7288 | ✅ |
| `-[ShipEntity withinStationAegis]` (6789) | `withinStationAegis` Core/Entities/ShipEntity.cpp:7293 | ✅ |
| `-[ShipEntity lastAegisLock]` (6794) | `lastAegisLock` Core/Entities/ShipEntity.cpp:7299 | ✅ |
| `-[ShipEntity setLastAegisLock:]` (6805) | `setLastAegisLock` Core/Entities/ShipEntity.cpp:7310 | ✅ |
| `-[ShipEntity homeSystem]` (6811) | `homeSystem` Core/Entities/ShipEntity.cpp:7315 | ✅ |
| `-[ShipEntity destinationSystem]` (6816) | `destinationSystem` Core/Entities/ShipEntity.cpp:7320 | ✅ |
| `-[ShipEntity setHomeSystem:]` (6821) | `setHomeSystem` Core/Entities/ShipEntity.cpp:7325 | ✅ |
| `-[ShipEntity setDestinationSystem:]` (6826) | `setDestinationSystem` Core/Entities/ShipEntity.cpp:7330 | ✅ |
| `-[ShipEntity setStatus:]` (6831) | `setStatus` Core/Entities/ShipEntity.cpp:7335 | ✅ |
| `-[ShipEntity setLaunchDelay:]` (6841) | `setLaunchDelay` Core/Entities/ShipEntity.cpp:7345 | ✅ |
| `-[ShipEntity crew]` (6846) | `getCrew` Core/Entities/ShipEntity.cpp:7350 | ✅ |
| `-[ShipEntity setCrew:]` (6851) | `setCrew` Core/Entities/ShipEntity.cpp:7355 | ✅ |
| `-[ShipEntity setSingleCrewWithRole:]` (6865) | `setSingleCrewWithRole` Core/Entities/ShipEntity.cpp:7367 | ✅ |
| `-[ShipEntity crewForScripting]` (6874) | `crewForScripting` Core/Entities/ShipEntity.cpp:7375 | ✅ |
| `-[ShipEntity setStateMachine:]` (6888) | `setStateMachine` Core/Entities/ShipEntity.cpp:7388 | ✅ |
| `-[ShipEntity setAI:]` (6893) | `setAI` Core/Entities/ShipEntity.cpp:7393 | ✅ |
| `-[ShipEntity getAI]` (6903) | `getAI` Core/Entities/ShipEntity.cpp:7403 | ✅ |
| `-[ShipEntity hasAutoAI]` (6908) | `hasAutoAI` Core/Entities/ShipEntity.cpp:7408 | ✅ |
| `-[ShipEntity hasNewAI]` (6913) | `hasNewAI` Core/Entities/ShipEntity.cpp:7413 | ✅ |
| `-[ShipEntity hasAutoWeapons]` (6918) | `hasAutoWeapons` Core/Entities/ShipEntity.cpp:7418 | ✅ |
| `-[ShipEntity setShipScript:]` (6923) | `setShipScript` Core/Entities/ShipEntity.cpp:7423 | ✅ |
| `-[ShipEntity frustration]` (6973) | `getFrustration` Core/Entities/ShipEntity.cpp:7470 | ✅ |
| `-[ShipEntity fuel]` (6978) | `getFuel` Core/Entities/ShipEntity.cpp:7475 | ✅ |
| `-[ShipEntity setFuel:]` (6983) | `setFuel` Core/Entities/ShipEntity.cpp:7480 | ✅ |
| `-[ShipEntity fuelCapacity]` (6991) | `fuelCapacity` Core/Entities/ShipEntity.cpp:7488 | ✅ |
| `-[ShipEntity fuelChargeRate]` (6997) | `fuelChargeRate` Core/Entities/ShipEntity.cpp:7494 | ✅ |
| `-[ShipEntity applySticks:]` (7013) | `applySticks` Core/Entities/ShipEntity.cpp:7514 | ✅ |
| `-[ShipEntity setRoll:]` (7062) | `setRoll` Core/Entities/ShipEntity.cpp:7563 | ✅ |
| `-[ShipEntity setRawRoll:]` (7067) | `setRawRoll` Core/Entities/ShipEntity.cpp:7568 | ✅ |
| `-[ShipEntity setPitch:]` (7072) | `setPitch` Core/Entities/ShipEntity.cpp:7573 | ✅ |
| `-[ShipEntity setYaw:]` (7077) | `setYaw` Core/Entities/ShipEntity.cpp:7578 | ✅ |
| `-[ShipEntity setThrust:]` (7082) | `setThrust` Core/Entities/ShipEntity.cpp:7583 | ✅ |
| `-[ShipEntity setThrustForDemo:]` (7087) | `setThrustForDemo` Core/Entities/ShipEntity.cpp:7588 | ✅ |
| `-[ShipEntity setBounty:]` (7092) | `setBounty` Core/Entities/ShipEntity.cpp:7593 | ✅ |
| `-[ShipEntity setBounty:withReason:]` (7097) | `setBounty` Core/Entities/ShipEntity.cpp:7598 | ✅ |
| `-[ShipEntity setBounty:withReasonAsString:]` (7113) | `setBounty` Core/Entities/ShipEntity.cpp:7614 | ✅ |
| `-[ShipEntity bounty]` (7133) | `getBounty` Core/Entities/ShipEntity.cpp:7635 | ✅ |
| `-[ShipEntity legalStatus]` (7142) | `legalStatus` Core/Entities/ShipEntity.cpp:7644 | ✅ |
| `-[ShipEntity setCommodity:andAmount:]` (7151) | `setCommodity` Core/Entities/ShipEntity.cpp:7653 | ✅ |
| `-[ShipEntity setCommodityForPod:andAmount:]` (7164) | `setCommodityForPod` Core/Entities/ShipEntity.cpp:7661 | ✅ |
| `-[ShipEntity commodityType]` (7184) | `commodityType` Core/Entities/ShipEntity.cpp:7682 | ✅ |
| `-[ShipEntity commodityAmount]` (7189) | `commodityAmount` Core/Entities/ShipEntity.cpp:7687 | ✅ |
| `-[ShipEntity maxAvailableCargoSpace]` (7194) | `maxAvailableCargoSpace` Core/Entities/ShipEntity.cpp:7692 | ✅ |
| `-[ShipEntity setMaxAvailableCargoSpace:]` (7199) | `setMaxAvailableCargoSpace` Core/Entities/ShipEntity.cpp:7697 | ✅ |
| `-[ShipEntity availableCargoSpace]` (7204) | `availableCargoSpace` Core/Entities/ShipEntity.cpp:7702 | ✅ |
| `-[ShipEntity cargoQuantityOnBoard]` (7212) | `cargoQuantityOnBoard` Core/Entities/ShipEntity.cpp:7710 | ✅ |
| `-[ShipEntity cargoType]` (7219) | `cargoType` Core/Entities/ShipEntity.cpp:7717 | ✅ |
| `-[ShipEntity cargo]` (7226) | `getCargo` Core/Entities/ShipEntity.cpp:7725 | ✅ |
| `-[ShipEntity cargoListForScripting]` (7231) | `cargoListForScripting` Core/Entities/ShipEntity.cpp:7735 | ⚠️ |
| `-[ShipEntity setCargo:]` (7265) | `setCargo` Core/Entities/ShipEntity.cpp:7771 | ✅ |
| `-[ShipEntity addCargo:]` (7271) | `addCargo` Core/Entities/ShipEntity.cpp:7776 | ✅ |
| `-[ShipEntity removeCargo:amount:]` (7281) | `removeCargo` Core/Entities/ShipEntity.cpp:7786 | ✅ |
| `-[ShipEntity showScoopMessage]` (7309) | `showScoopMessage` Core/Entities/ShipEntity.cpp:7813 | ✅ |
| `-[ShipEntity cargoFlag]` (7314) | `cargoFlag` Core/Entities/ShipEntity.cpp:7818 | ✅ |
| `-[ShipEntity setCargoFlag:]` (7319) | `setCargoFlag` Core/Entities/ShipEntity.cpp:7823 | ✅ |
| `-[ShipEntity setSpeed:]` (7371) | `setSpeed` Core/Entities/ShipEntity.cpp:7876 | ✅ |
| `-[ShipEntity setDesiredSpeed:]` (7376) | `setDesiredSpeed` Core/Entities/ShipEntity.cpp:7881 | ✅ |
| `-[ShipEntity desiredSpeed]` (7381) | `desiredSpeed` Core/Entities/ShipEntity.cpp:7886 | ✅ |
| `-[ShipEntity desiredRange]` (7386) | `desiredRange` Core/Entities/ShipEntity.cpp:7895 | ✅ |
| `-[ShipEntity setDesiredRange:]` (7391) | `setDesiredRange` Core/Entities/ShipEntity.cpp:7900 | ✅ |
| `-[ShipEntity cruiseSpeed]` (7396) | `getCruiseSpeed` Core/Entities/ShipEntity.cpp:7905 | ✅ |
| `-[ShipEntity increase_flight_speed:]` (7401) | `increase_flight_speed` Core/Entities/ShipEntity.cpp:7910 | ✅ |
| `-[ShipEntity decrease_flight_speed:]` (7413) | `decrease_flight_speed` Core/Entities/ShipEntity.cpp:7922 | ✅ |
| `-[ShipEntity increase_flight_roll:]` (7427) | `increase_flight_roll` Core/Entities/ShipEntity.cpp:7936 | ✅ |
| `-[ShipEntity decrease_flight_roll:]` (7436) | `decrease_flight_roll` Core/Entities/ShipEntity.cpp:7945 | ✅ |
| `-[ShipEntity increase_flight_pitch:]` (7445) | `increase_flight_pitch` Core/Entities/ShipEntity.cpp:7954 | ✅ |
| `-[ShipEntity decrease_flight_pitch:]` (7454) | `decrease_flight_pitch` Core/Entities/ShipEntity.cpp:7963 | ✅ |
| `-[ShipEntity increase_flight_yaw:]` (7463) | `increase_flight_yaw` Core/Entities/ShipEntity.cpp:7972 | ✅ |
| `-[ShipEntity decrease_flight_yaw:]` (7472) | `decrease_flight_yaw` Core/Entities/ShipEntity.cpp:7981 | ✅ |
| `-[ShipEntity flightRoll]` (7481) | `getFlightRoll` Core/Entities/ShipEntity.cpp:7990 | ✅ |
| `-[ShipEntity flightPitch]` (7486) | `getFlightPitch` Core/Entities/ShipEntity.cpp:7995 | ✅ |
| `-[ShipEntity flightYaw]` (7491) | `getFlightYaw` Core/Entities/ShipEntity.cpp:8000 | ✅ |
| `-[ShipEntity flightSpeed]` (7496) | `getFlightSpeed` Core/Entities/ShipEntity.cpp:8005 | ✅ |
| `-[ShipEntity maxFlightPitch]` (7501) | `maxFlightPitch` Core/Entities/ShipEntity.cpp:8010 | ✅ |
| `-[ShipEntity maxFlightSpeed]` (7506) | `getMaxFlightSpeed` Core/Entities/ShipEntity.cpp:8015 | ✅ |
| `-[ShipEntity maxFlightRoll]` (7511) | `maxFlightRoll` Core/Entities/ShipEntity.cpp:8020 | ✅ |
| `-[ShipEntity maxFlightYaw]` (7516) | `maxFlightYaw` Core/Entities/ShipEntity.cpp:8025 | ✅ |
| `-[ShipEntity setMaxFlightPitch:]` (7521) | `setMaxFlightPitch` Core/Entities/ShipEntity.cpp:8030 | ✅ |
| `-[ShipEntity setMaxFlightSpeed:]` (7526) | `setMaxFlightSpeed` Core/Entities/ShipEntity.cpp:8035 | ✅ |
| `-[ShipEntity setMaxFlightRoll:]` (7531) | `setMaxFlightRoll` Core/Entities/ShipEntity.cpp:8040 | ✅ |
| `-[ShipEntity setMaxFlightYaw:]` (7536) | `setMaxFlightYaw` Core/Entities/ShipEntity.cpp:8045 | ✅ |
| `-[ShipEntity speedFactor]` (7541) | `speedFactor` Core/Entities/ShipEntity.cpp:8050 | ✅ |
| `-[ShipEntity temperature]` (7548) | `temperature` Core/Entities/ShipEntity.cpp:8057 | ✅ |
| `-[ShipEntity setTemperature:]` (7553) | `setTemperature` Core/Entities/ShipEntity.cpp:8062 | ✅ |
| `-[ShipEntity randomEjectaTemperature]` (7558) | `randomEjectaTemperature` Core/Entities/ShipEntity.cpp:8067 | ✅ |
| `-[ShipEntity randomEjectaTemperatureWithMaxFactor:]` (7563) | `randomEjectaTemperatureWithMaxFactor` Core/Entities/ShipEntity.cpp:8072 | ✅ |
| `-[ShipEntity heatInsulation]` (7580) | `heatInsulation` Core/Entities/ShipEntity.cpp:8089 | ✅ |
| `-[ShipEntity setHeatInsulation:]` (7585) | `setHeatInsulation` Core/Entities/ShipEntity.cpp:8094 | ✅ |
| `-[ShipEntity damage]` (7590) | `damage` Core/Entities/ShipEntity.cpp:8099 | ✅ |
| `-[ShipEntity dealEnergyDamage:atRange:withBias:]` (7595) | `dealEnergyDamage` Core/Entities/ShipEntity.cpp:8104 | ✅ |
| `-[ShipEntity dealEnergyDamageWithinDesiredRange]` (7658) | `dealEnergyDamageWithinDesiredRange` Core/Entities/ShipEntity.cpp:8167 | ✅ |
| `-[ShipEntity dealMomentumWithinDesiredRange:]` (7676) | `dealMomentumWithinDesiredRange` Core/Entities/ShipEntity.cpp:8185 | ✅ |
| `-[ShipEntity isHulk]` (7698) | `getIsHulk` Core/Entities/ShipEntity.cpp:8208 | ✅ |
| `-[ShipEntity setHulk:]` (7703) | `setHulk` Core/Entities/ShipEntity.cpp:8213 | ✅ |
| `-[ShipEntity noteTakingDamage:from:type:]` (7710) | `noteTakingDamage` Core/Entities/ShipEntity.cpp:8220 | ✅ |
| `-[ShipEntity noteKilledBy:damageType:]` (7740) | `noteKilledBy` Core/Entities/ShipEntity.cpp:8250 | ✅ |
| `-[ShipEntity getDestroyedBy:damageType:]` (7764) | `getDestroyedBy` Core/Entities/ShipEntity.cpp:8279 | ✅ |
| `-[ShipEntity rescaleBy:]` (7771) | `rescaleBy` Core/Entities/ShipEntity.cpp:8286 | ✅ |
| `-[ShipEntity rescaleBy:writeToCache:]` (7776) | `rescaleBy` Core/Entities/ShipEntity.cpp:8291 | ✅ |
| `-[ShipEntity releaseCargoPodsDebris]` (7810) | `releaseCargoPodsDebris` Core/Entities/ShipEntity.cpp:8330 | ❌ |
| `-[ShipEntity setIsWreckage:]` (7877) | `setIsWreckage` Core/Entities/ShipEntity.cpp:8406 | ✅ |
| `-[ShipEntity showDamage]` (7882) | `showDamage` Core/Entities/ShipEntity.cpp:8411 | ✅ |
| `-[ShipEntity becomeExplosion]` (7887) | `becomeExplosion` Core/Entities/ShipEntity.cpp:8416 | ❌ |
| `-[ShipEntity becomeEnergyBlast]` (8142) | `becomeEnergyBlast` Core/Entities/ShipEntity.cpp:8710 | ✅ |
| `-[ShipEntity broadcastEnergyBlastImminent]` (8151) | `broadcastEnergyBlastImminent` Core/Entities/ShipEntity.cpp:8721 | ✅ |
| `-[ShipEntity removeExhaust:]` (8169) | `removeExhaust` Core/Entities/ShipEntity.cpp:8742 | ✅ |
| `-[ShipEntity removeFlasher:]` (8175) | `removeFlasher` Core/Entities/ShipEntity.cpp:8753 | ✅ |
| `-[ShipEntity subEntityDied:]` (8181) | `subEntityDied` Core/Entities/ShipEntity.cpp:8760 | ✅ |
| `-[ShipEntity subEntityReallyDied:]` (8193) | `subEntityReallyDied` Core/Entities/ShipEntity.cpp:8773 | ✅ |
| `-[ShipEntity positionOffsetForAlignment:]` (8206) | `positionOffsetForAlignment` Core/Entities/ShipEntity.cpp:8789 | ✅ |
| `positionOffsetForShipInRotationToAlignment()` (8249) | `cxx_positionOffsetForShipInRotationToAlignment` Core/Entities/ShipEntity.cpp:491 | ✅ |
| `-[ShipEntity becomeLargeExplosion:]` (8296) | `becomeLargeExplosion` Core/Entities/ShipEntity.cpp:8833 | ✅ |
| `-[ShipEntity collectBountyFor:]` (8334) | `collectBountyFor` Core/Entities/ShipEntity.cpp:8877 | ✅ |
| `-[ShipEntity compareBeaconCodeWith:]` (8342) | `compareBeaconCodeWith` Core/Entities/ShipEntity.cpp:8885 | ❌ |
| `-[ShipEntity weaponRecoveryTime]` (8348) | `weaponRecoveryTime` Core/Entities/ShipEntity.cpp:8891 | ✅ |
| `-[ShipEntity laserHeatLevel]` (8354) | `laserHeatLevel` Core/Entities/ShipEntity.cpp:8897 | ✅ |
| `-[ShipEntity laserHeatLevelAft]` (8360) | `laserHeatLevelAft` Core/Entities/ShipEntity.cpp:8903 | ✅ |
| `-[ShipEntity laserHeatLevelForward]` (8366) | `laserHeatLevelForward` Core/Entities/ShipEntity.cpp:8909 | ✅ |
| `-[ShipEntity laserHeatLevelPort]` (8383) | `laserHeatLevelPort` Core/Entities/ShipEntity.cpp:8927 | ✅ |
| `-[ShipEntity laserHeatLevelStarboard]` (8389) | `laserHeatLevelStarboard` Core/Entities/ShipEntity.cpp:8933 | ✅ |
| `-[ShipEntity hullHeatLevel]` (8395) | `hullHeatLevel` Core/Entities/ShipEntity.cpp:8939 | ✅ |
| `-[ShipEntity entityPersonality]` (8401) | `entityPersonality` Core/Entities/ShipEntity.cpp:8945 | ✅ |
| `-[ShipEntity entityPersonalityInt]` (8406) | `entityPersonalityInt` Core/Entities/ShipEntity.cpp:8950 | ✅ |
| `-[ShipEntity randomSeedForShaders]` (8411) | `randomSeedForShaders` Core/Entities/ShipEntity.cpp:8955 | ✅ |
| `-[ShipEntity setEntityPersonalityInt:]` (8416) | `setEntityPersonalityInt` Core/Entities/ShipEntity.cpp:8960 | ✅ |
| `-[ShipEntity setSuppressExplosion:]` (8424) | `setSuppressExplosion` Core/Entities/ShipEntity.cpp:8969 | ✅ |
| `-[ShipEntity resetExhaustPlumes]` (8429) | `resetExhaustPlumes` Core/Entities/ShipEntity.cpp:8974 | ✅ |
| `-[ShipEntity checkScanner]` (8444) | `checkScanner` Core/Entities/ShipEntity.cpp:8988 | ✅ |
| `-[ShipEntity checkScannerIgnoringUnpowered]` (8482) | `checkScannerIgnoringUnpowered` Core/Entities/ShipEntity.cpp:9026 | ✅ |
| `-[ShipEntity scannedShips]` (8524) | `scannedShips` Core/Entities/ShipEntity.cpp:9068 | ✅ |
| `-[ShipEntity numberOfScannedShips]` (8530) | `numberOfScannedShips` Core/Entities/ShipEntity.cpp:9074 | ✅ |
| `-[ShipEntity foundTarget]` (8535) | `foundTarget` Core/Entities/ShipEntity.cpp:9080 | ✅ |
| `-[ShipEntity setFoundTarget:]` (8545) | `setFoundTarget` Core/Entities/ShipEntity.cpp:9090 | ✅ |
| `-[ShipEntity primaryAggressor]` (8551) | `primaryAggressor` Core/Entities/ShipEntity.cpp:9096 | ✅ |
| `-[ShipEntity setPrimaryAggressor:]` (8561) | `setPrimaryAggressor` Core/Entities/ShipEntity.cpp:9106 | ✅ |
| `-[ShipEntity lastEscortTarget]` (8567) | `lastEscortTarget` Core/Entities/ShipEntity.cpp:9112 | ✅ |
| `-[ShipEntity setLastEscortTarget:]` (8577) | `setLastEscortTarget` Core/Entities/ShipEntity.cpp:9122 | ✅ |
| `-[ShipEntity thankedShip]` (8583) | `thankedShip` Core/Entities/ShipEntity.cpp:9132 | ✅ |
| `-[ShipEntity setThankedShip:]` (8593) | `setThankedShip` Core/Entities/ShipEntity.cpp:9142 | ✅ |
| `-[ShipEntity rememberedShip]` (8599) | `rememberedShip` Core/Entities/ShipEntity.cpp:9148 | ✅ |
| `-[ShipEntity setRememberedShip:]` (8609) | `setRememberedShip` Core/Entities/ShipEntity.cpp:9158 | ✅ |
| `-[ShipEntity targetStation]` (8615) | `targetStation` Core/Entities/ShipEntity.cpp:9164 | ✅ |
| `-[ShipEntity setTargetStation:]` (8625) | `setTargetStation` Core/Entities/ShipEntity.cpp:9174 | ✅ |
| `-[ShipEntity isValidTarget:]` (8634) | `isValidTarget` Core/Entities/ShipEntity.cpp:9183 | ✅ |
| `-[ShipEntity addTarget:]` (8654) | `addTarget` Core/Entities/ShipEntity.cpp:9203 | ✅ |
| `-[ShipEntity removeTarget:]` (8669) | `removeTarget` Core/Entities/ShipEntity.cpp:9221 | ✅ |
| `-[ShipEntity canStillTrackPrimaryTarget]` (8692) | `canStillTrackPrimaryTarget` Core/Entities/ShipEntity.cpp:9247 | ✅ |
| `-[ShipEntity primaryTarget]` (8714) | `primaryTarget` Core/Entities/ShipEntity.cpp:9271 | ✅ |
| `-[ShipEntity primaryTargetWithoutValidityCheck]` (8733) | `primaryTargetWithoutValidityCheck` Core/Entities/ShipEntity.cpp:9290 | ✅ |
| `-[ShipEntity isFriendlyTo:]` (8744) | `isFriendlyTo` Core/Entities/ShipEntity.cpp:9301 | ✅ |
| `-[ShipEntity shipHitByLaser]` (8757) | `shipHitByLaser` Core/Entities/ShipEntity.cpp:9314 | ✅ |
| `-[ShipEntity setShipHitByLaser:]` (8762) | `setShipHitByLaser` Core/Entities/ShipEntity.cpp:9319 | ✅ |
| `-[ShipEntity noteLostTarget]` (8770) | `noteLostTarget` Core/Entities/ShipEntity.cpp:9326 | ✅ |
| `-[ShipEntity noteLostTargetAndGoIdle]` (8795) | `noteLostTargetAndGoIdle` Core/Entities/ShipEntity.cpp:9355 | ✅ |
| `-[ShipEntity noteTargetDestroyed:]` (8802) | `noteTargetDestroyed` Core/Entities/ShipEntity.cpp:9362 | ✅ |
| `-[ShipEntity behaviour]` (8817) | `getBehaviour` Core/Entities/ShipEntity.cpp:9379 | ✅ |
| `-[ShipEntity setBehaviour:]` (8822) | `setBehaviour` Core/Entities/ShipEntity.cpp:9384 | ✅ |
| `-[ShipEntity destination]` (8830) | `destination` Core/Entities/ShipEntity.cpp:9392 | ✅ |
| `-[ShipEntity coordinates]` (8835) | `getCoordinates` Core/Entities/ShipEntity.cpp:9397 | ✅ |
| `-[ShipEntity setCoordinate:]` (8840) | `setCoordinate` Core/Entities/ShipEntity.cpp:9402 | ✅ |
| `-[ShipEntity distance_six:]` (8845) | `distance_six` Core/Entities/ShipEntity.cpp:9407 | ✅ |
| `-[ShipEntity distance_twelve:withOffset:]` (8854) | `distance_twelve` Core/Entities/ShipEntity.cpp:9416 | ✅ |
| `-[ShipEntity trackOntoTarget:withDForward:]` (8866) | `trackOntoTarget` Core/Entities/ShipEntity.cpp:9428 | ✅ |
| `-[ShipEntity ballTrackLeadingTarget:atTarget:]` (8903) | `ballTrackLeadingTarget` Core/Entities/ShipEntity.cpp:9465 | ✅ |
| `-[ShipEntity setEvasiveJink:]` (8976) | `setEvasiveJink` Core/Entities/ShipEntity.cpp:9543 | ✅ |
| `-[ShipEntity evasiveAction:]` (8999) | `evasiveAction` Core/Entities/ShipEntity.cpp:9566 | ❌ |
| `-[ShipEntity trackPrimaryTarget:retreat:]` (9030) | `trackPrimaryTarget` Core/Entities/ShipEntity.cpp:9597 | ✅ |
| `-[ShipEntity trackSideTarget:leftside:]` (9242) | `trackSideTarget` Core/Entities/ShipEntity.cpp:9809 | ✅ |
| `-[ShipEntity missileTrackPrimaryTarget:]` (9352) | `missileTrackPrimaryTarget` Core/Entities/ShipEntity.cpp:9923 | ✅ |
| `-[ShipEntity trackDestination:retreat:]` (9446) | `trackDestination` Core/Entities/ShipEntity.cpp:10017 | ✅ |
| `-[ShipEntity rollToMatchUp:rotating:]` (9589) | `rollToMatchUp` Core/Entities/ShipEntity.cpp:10160 | ✅ |
| `-[ShipEntity rangeToDestination]` (9613) | `rangeToDestination` Core/Entities/ShipEntity.cpp:10184 | ✅ |
| `-[ShipEntity collisionExceptions]` (9618) | `collisionExceptions` Core/Entities/ShipEntity.cpp:10189 | ✅ |
| `-[ShipEntity addCollisionException:]` (9626) | `addCollisionException` Core/Entities/ShipEntity.cpp:10198 | ✅ |
| `-[ShipEntity removeCollisionException:]` (9635) | `removeCollisionException` Core/Entities/ShipEntity.cpp:10203 | ✅ |
| `-[ShipEntity collisionExceptedFor:]` (9642) | `collisionExceptedFor` Core/Entities/ShipEntity.cpp:10208 | ✅ |
| `-[ShipEntity defenseTargetCount]` (9650) | `defenseTargetCount` Core/Entities/ShipEntity.cpp:10213 | ✅ |
| `-[ShipEntity allDefenseTargets]` (9655) | `allDefenseTargets` Core/Entities/ShipEntity.cpp:10218 | ✅ |
| `-[ShipEntity defenseTargetEnumerator]` (9660) | `defenseTargets` Core/Entities/ShipEntity.cpp:10226 | ✅ |
| `-[ShipEntity addDefenseTarget:]` (9665) | `addDefenseTarget` Core/Entities/ShipEntity.cpp:10236 | ✅ |
| `-[ShipEntity validateDefenseTargets]` (9683) | `validateDefenseTargets` Core/Entities/ShipEntity.cpp:10249 | ✅ |
| `-[ShipEntity isDefenseTarget:]` (9698) | `isDefenseTarget` Core/Entities/ShipEntity.cpp:10260 | ✅ |
| `-[ShipEntity removeAllDefenseTargets]` (9704) | `removeAllDefenseTargets` Core/Entities/ShipEntity.cpp:10266 | ✅ |
| `-[ShipEntity removeDefenseTarget:]` (9709) | `removeDefenseTarget` Core/Entities/ShipEntity.cpp:10271 | ✅ |
| `-[ShipEntity rangeToPrimaryTarget]` (9714) | `rangeToPrimaryTarget` Core/Entities/ShipEntity.cpp:10276 | ✅ |
| `-[ShipEntity rangeToSecondaryTarget:]` (9719) | `rangeToSecondaryTarget` Core/Entities/ShipEntity.cpp:10281 | ✅ |
| `-[ShipEntity approachAspectToPrimaryTarget]` (9732) | `approachAspectToPrimaryTarget` Core/Entities/ShipEntity.cpp:10294 | ✅ |
| `-[ShipEntity hasProximityAlertIgnoringTarget:]` (9747) | `hasProximityAlertIgnoringTarget` Core/Entities/ShipEntity.cpp:10309 | ✅ |
| `-[ShipEntity currentAimTolerance]` (9757) | `currentAimTolerance` Core/Entities/ShipEntity.cpp:10323 | ✅ |

**Differences:**

- ❌ **low** — `releaseCargoPodsDebris`: `container->setTemperature(randomEjectaTemperature())` sits under `if (container != nullptr)`. ObjC evaluated `[self randomEjectaTemperature]` (which calls `bellf(5)`) even when the message went to a nil container. So when `reifyCargoPod` returns nil (only if `cargoPodFromTemplate` fails), the port skips the RNG draws and every later ejecta/debris roll is out of step. — upstream `Core/Entities/ShipEntity.m:7859` ↔ port `Core/Entities/ShipEntity.cpp:8383`
- ❌ **low** — `becomeExplosion` wreckage loop: `wreck->setVelocity(... randf() * wreck->collisionRadius())` is guarded by `if (wreck != nullptr)`. Upstream still called `randf()` while building the argument for a nil `wreck`, so a failed `addWreckageFrom` (no ship found for the "wreckage" role) gives a different RNG stream for the `n_alloys = randf() * n_alloys` draw and the alloy spawns after it. — upstream `Core/Entities/ShipEntity.m:8062` ↔ port `Core/Entities/ShipEntity.cpp:8625`
- ❌ **low** — `compareBeaconCodeWith`: nil-messaging lost. `[[self beaconCode] compare:…]` with a nil code returned `NSOrderedSame`. The port compares `""` against the other code and returns Ascending. It only matters if a ship without a beacon code is ever sorted with beacons, which today's callers do not do. — upstream `Core/Entities/ShipEntity.m:8342` ↔ port `Core/Entities/ShipEntity.cpp:8885`
- ❌ **low** — `evasiveAction`: the target is `oo::ToShip(primaryTarget())`, so a non-ship primary target (a wormhole) is treated as no target: `noteLostTargetAndGoIdle` runs, sending TARGET_LOST and setting BEHAVIOUR_IDLE. Upstream cast the wormhole to `ShipEntity*`, read `target->v_right` (undefined, garbage) and kept jinking. — upstream `Core/Entities/ShipEntity.m:9004` ↔ port `Core/Entities/ShipEntity.cpp:9571`
- ⚠️ **low** — `cargoListForScripting`: a pod whose commodity is not in the market's goods, or is nil, is skipped. Upstream indexed `quantityInHold[NSNotFound]`, an out-of-bounds write. The port comment documents this. A missing `displayName` is also left out of the dict, where upstream's `setObject:nil` would have thrown. — upstream `Core/Entities/ShipEntity.m:7245` ↔ port `Core/Entities/ShipEntity.cpp:7745`
- ✅ subtle — `crewForScripting` returns an empty vector, not nil, when `crew` is nil. The only caller, `OOJSShip` `kShip_crew` (`Core/Scripting/OOJSShip.cpp:877`), checks `getCrew().has_value()` first, so `ship.crew` is still `null` for crewless ships. — upstream `Core/Entities/ShipEntity.m:6874` ↔ port `Core/Entities/ShipEntity.cpp:7375`
- ✅ subtle — `setCommodity` loses upstream's `if (co_type != nil)` no-op guard because its parameter is a `std::string`. Every caller (`scoopUp` `Core/Entities/ShipEntity.cpp:11976`, `Universe.cpp:4343`, PlayerEntity) unwraps the optional and skips a nil type itself, so the result is the same. — upstream `Core/Entities/ShipEntity.m:7151` ↔ port `Core/Entities/ShipEntity.cpp:7653`
- ✅ subtle — `becomeExplosion` / `becomeLargeExplosion`: `@try/@finally` becomes `oo::Finally`, declared after `setStatus(STATUS_DEAD)` as before. The early `return` in the asteroid/boulder branch still runs `removeEntity`. The subentity loops go over a `shipSubEntities()` snapshot, as `-shipSubEntityEnumerator` went over a copy. The fragment/debris counts (`n_rocks = 2 + Ranrot() % (likely_cargo+1)`, `n_wreckage`, `numAlloys = floorf(n_alloys)`), the 0.95/0.50 `UNIVERSE_MAX_ENTITIES` thresholds and the RNG call order all match, apart from the nil-wreck case above. — upstream `Core/Entities/ShipEntity.m:7887` ↔ port `Core/Entities/ShipEntity.cpp:8416`
- ✅ subtle — `findNearestPlanetExcludingMoons`: `-sortedArrayUsingFunction:` becomes `std::stable_sort` on the same comparator. Only planets at exactly equal surface distance could come out in a different order. — upstream `Core/Entities/ShipEntity.m:6648` ↔ port `Core/Entities/ShipEntity.cpp:7135`
- ✅ subtle — `subEntityReallyDied`: upstream leaked the subentity array by setting the ivar to nil. The port gives each entry one extra retain and clears the vector, which has the same observable result (empty list, subentities kept alive). — upstream `Core/Entities/ShipEntity.m:8202` ↔ port `Core/Entities/ShipEntity.cpp:8785`
- ✅ subtle — every method a subclass overrides upstream (`addTarget`, `removeTarget`, `isValidTarget`, `setFoundTarget`, `bounty`, `legalStatus`, `setBounty`×3, `cargoQuantityOnBoard`, `cargoListForScripting`, `collectBountyFor`, `fuelChargeRate`, `getDestroyedBy`, `noteTakingDamage`, `becomeExplosion`, `becomeLargeExplosion`, `becomeEnergyBlast`, the `laserHeatLevel*` family, `setMaxFlight{Pitch,Roll,Yaw}`) is `virtual` in `Core/Entities/ShipEntity.h`, so the internal self-sends still dispatch to PlayerEntity/StationEntity.

### ShipEntity (part 4: lines 9809-end)

Upstream `src/Core/Entities/ShipEntity.m` lines 9809–13041 ↔ `Core/Entities/ShipEntity.cpp`

**Status:** done — 138 rows: 128 ✅ 3 ⚠️ 2 ❌ 5 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[ShipEntity lookingAtSunWithThresholdAngleCos:]` (9809) | `ShipEntity::lookingAtSunWithThresholdAngleCos` Core/Entities/ShipEntity.cpp:10375 | ✅ |
| `-[ShipEntity onTarget:withWeapon:]` (9847) | `ShipEntity::onTarget` Core/Entities/ShipEntity.cpp:10413 | ✅ |
| `-[ShipEntity fireWeapon:direction:range:]` (9908) | `ShipEntity::fireWeapon` Core/Entities/ShipEntity.cpp:10474 | ✅ |
| `-[ShipEntity fireMainWeapon:]` (10005) | `ShipEntity::fireMainWeapon` Core/Entities/ShipEntity.cpp:10570 | ✅ |
| `-[ShipEntity fireAftWeapon:]` (10044) | `ShipEntity::fireAftWeapon` Core/Entities/ShipEntity.cpp:10610 | ✅ |
| `-[ShipEntity firePortWeapon:]` (10053) | `ShipEntity::firePortWeapon` Core/Entities/ShipEntity.cpp:10619 | ✅ |
| `-[ShipEntity fireStarboardWeapon:]` (10062) | `ShipEntity::fireStarboardWeapon` Core/Entities/ShipEntity.cpp:10628 | ✅ |
| `-[ShipEntity shotTime]` (10071) | `ShipEntity::shotTime` Core/Entities/ShipEntity.cpp:10637 | ✅ |
| `-[ShipEntity resetShotTime]` (10076) | `ShipEntity::resetShotTime` Core/Entities/ShipEntity.cpp:10642 | ✅ |
| `-[ShipEntity fireTurretCannon:]` (10081) | `ShipEntity::fireTurretCannon` Core/Entities/ShipEntity.cpp:10647 | ✅ |
| `-[ShipEntity setLaserColor:]` (10132) | `ShipEntity::setLaserColor` Core/Entities/ShipEntity.cpp:10699 | ✅ |
| `-[ShipEntity setExhaustEmissiveColor:]` (10140) | `ShipEntity::setExhaustEmissiveColor` Core/Entities/ShipEntity.cpp:10706 | ✅ |
| `-[ShipEntity laserColor]` (10148) | `ShipEntity::laserColor` Core/Entities/ShipEntity.cpp:10713 | ✅ |
| `-[ShipEntity exhaustEmissiveColor]` (10153) | `ShipEntity::exhaustEmissiveColor` Core/Entities/ShipEntity.cpp:10718 | ✅ |
| `-[ShipEntity fireSubentityLaserShot:]` (10158) | `ShipEntity::fireSubentityLaserShot` Core/Entities/ShipEntity.cpp:10727 | ✅ |
| `-[ShipEntity fireDirectLaserShot:]` (10241) | `ShipEntity::fireDirectLaserShot` Core/Entities/ShipEntity.cpp:10822 | ✅ |
| `-[ShipEntity fireDirectLaserDefensiveShot]` (10253) | `ShipEntity::fireDirectLaserDefensiveShot` Core/Entities/ShipEntity.cpp:10834 | ✅ |
| `-[ShipEntity fireDirectLaserShotAt:]` (10273) | `ShipEntity::fireDirectLaserShotAt` Core/Entities/ShipEntity.cpp:10853 | ✅ |
| `-[ShipEntity laserPortOffset:]` (10332) | `ShipEntity::laserPortOffset` Core/Entities/ShipEntity.cpp:10917 | ✅ |
| `-[ShipEntity fireLaserShotInDirection:weaponIdentifier:]` (10356) | `ShipEntity::fireLaserShotInDirection` Core/Entities/ShipEntity.cpp:10941 | ✅ |
| `-[ShipEntity adjustMissedShots:]` (10464) | `ShipEntity::adjustMissedShots` Core/Entities/ShipEntity.cpp:11061 | ✅ |
| `-[ShipEntity missedShots]` (10476) | `ShipEntity::missedShots` Core/Entities/ShipEntity.cpp:11074 | ✅ |
| `-[ShipEntity throwSparks]` (10485) | `ShipEntity::throwSparks` Core/Entities/ShipEntity.cpp:11083 | ✅ |
| `-[ShipEntity considerFiringMissile:]` (10517) | `ShipEntity::considerFiringMissile` Core/Entities/ShipEntity.cpp:11115 | ✅ |
| `-[ShipEntity missileLaunchPosition]` (10530) | `ShipEntity::missileLaunchPosition` Core/Entities/ShipEntity.cpp:11128 | ✅ |
| `-[ShipEntity fireMissile]` (10554) | `ShipEntity::fireMissile` Core/Entities/ShipEntity.cpp:11152 | ✅ |
| `-[ShipEntity fireMissileWithIdentifier:andTarget:]` (10559) | `ShipEntity::fireMissileWithIdentifier` Core/Entities/ShipEntity.cpp:11161 | ✅ |
| `-[ShipEntity isMissileFlagSet]` (10689) | `ShipEntity::isMissileFlagSet` Core/Entities/ShipEntity.cpp:11312 | ✅ |
| `-[ShipEntity setIsMissileFlag:]` (10694) | `ShipEntity::setIsMissileFlag` Core/Entities/ShipEntity.cpp:11317 | ✅ |
| `-[ShipEntity missileLoadTime]` (10699) | `ShipEntity::missileLoadTime` Core/Entities/ShipEntity.cpp:11322 | ✅ |
| `-[ShipEntity setMissileLoadTime:]` (10704) | `ShipEntity::setMissileLoadTime` Core/Entities/ShipEntity.cpp:11327 | ✅ |
| `-[ShipEntity noticeECM]` (10710) | `ShipEntity::noticeECM` Core/Entities/ShipEntity.cpp:11333 | ✅ |
| `-[ShipEntity fireECM]` (10720) | `ShipEntity::fireECM` Core/Entities/ShipEntity.cpp:11343 | ✅ |
| `-[ShipEntity activateCloakingDevice]` (10731) | `ShipEntity::activateCloakingDevice` Core/Entities/ShipEntity.cpp:11353 | ✅ |
| `-[ShipEntity deactivateCloakingDevice]` (10743) | `ShipEntity::deactivateCloakingDevice` Core/Entities/ShipEntity.cpp:11365 | ✅ |
| `-[ShipEntity launchCascadeMine]` (10751) | `ShipEntity::launchCascadeMine` Core/Entities/ShipEntity.cpp:11373 | ✅ |
| `-[ShipEntity launchEscapeCapsule]` (10804) | `ShipEntity::launchEscapeCapsule` Core/Entities/ShipEntity.cpp:11437 | ❌ |
| `-[ShipEntity dumpCargo]` (10852) | `ShipEntity::dumpCargo` (returns `void`) Core/Entities/ShipEntity.cpp:11488 | ⚠️ |
| `-[ShipEntity dumpCargoItem:]` (10862) | `ShipEntity::dumpCargoItem` Core/Entities/ShipEntity.cpp:11493 | ✅ |
| `-[ShipEntity dumpItem:]` (10903) | `ShipEntity::dumpItem` Core/Entities/ShipEntity.cpp:11535 | ✅ |
| `-[ShipEntity manageCollisions]` (10987) | `ShipEntity::manageCollisions` Core/Entities/ShipEntity.cpp:11635 | ✅ |
| `-[ShipEntity collideWithShip:]` (11016) | `ShipEntity::collideWithShip` Core/Entities/ShipEntity.cpp:11665 | ✅ |
| `-[ShipEntity thrustVector]` (11154) | `ShipEntity::thrustVector` Core/Entities/ShipEntity.cpp:11812 | ✅ |
| `-[ShipEntity velocity]` (11159) | `ShipEntity::getVelocity` Core/Entities/ShipEntity.cpp:11817 | ✅ |
| `-[ShipEntity setTotalVelocity:]` (11164) | `ShipEntity::setTotalVelocity` Core/Entities/ShipEntity.cpp:11822 | ✅ |
| `-[ShipEntity adjustVelocity:]` (11169) | `ShipEntity::adjustVelocity` Core/Entities/ShipEntity.cpp:11827 | ✅ |
| `-[ShipEntity addImpactMoment:fraction:]` (11174) | `ShipEntity::addImpactMoment` Core/Entities/ShipEntity.cpp:11832 | ✅ |
| `-[ShipEntity canScoop:]` (11179) | `ShipEntity::canScoop` Core/Entities/ShipEntity.cpp:11837 | ✅ |
| `-[ShipEntity getTractoredBy:]` (11207) | `ShipEntity::getTractoredBy` Core/Entities/ShipEntity.cpp:11865 | ✅ |
| `-[ShipEntity scoopIn:]` (11231) | `ShipEntity::scoopIn` Core/Entities/ShipEntity.cpp:11890 | ✅ |
| `-[ShipEntity suppressTargetLost]` (11236) | `ShipEntity::suppressTargetLost` Core/Entities/ShipEntity.cpp:11896 | ✅ |
| `-[ShipEntity scoopUp:]` (11240) | `ShipEntity::scoopUp` Core/Entities/ShipEntity.cpp:11900 | ✅ |
| `-[ShipEntity scoopUpProcess:processEvents:processMessages:]` (11245) | `ShipEntity::scoopUpProcess` Core/Entities/ShipEntity.cpp:11905 | ✅ |
| `-[ShipEntity cascadeIfAppropriateWithDamageAmount:cascadeOwner:]` (11377) | `ShipEntity::cascadeIfAppropriateWithDamageAmount` Core/Entities/ShipEntity.cpp:12067 | ✅ |
| `-[ShipEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (11414) | `ShipEntity::takeEnergyDamage` Core/Entities/ShipEntity.cpp:12105 | ✅ |
| `-[ShipEntity abandonShip]` (11572) | `ShipEntity::abandonShip` Core/Entities/ShipEntity.cpp:12273 | ✅ |
| `-[ShipEntity takeScrapeDamage:from:]` (11637) | `ShipEntity::takeScrapeDamage` Core/Entities/ShipEntity.cpp:12340 | ✅ |
| `-[ShipEntity takeHeatDamage:]` (11674) | `ShipEntity::takeHeatDamage` Core/Entities/ShipEntity.cpp:12378 | ✅ |
| `-[ShipEntity enterDock:]` (11702) | `ShipEntity::enterDock` Core/Entities/ShipEntity.cpp:12406 | ✅ |
| `-[ShipEntity leaveDock:]` (11717) | `ShipEntity::leaveDock` Core/Entities/ShipEntity.cpp:12421 | ✅ |
| `-[ShipEntity enterWormhole:]` (11726) | `ShipEntity::enterWormhole(WormholeEntity*)` Core/Entities/ShipEntity.cpp:12431 | ✅ |
| `-[ShipEntity enterWormhole:replacing:]` (11731) | `ShipEntity::enterWormhole(WormholeEntity*, bool)` Core/Entities/ShipEntity.cpp:12436 | ✅ |
| `-[ShipEntity enterWitchspace]` (11761) | `ShipEntity::enterWitchspace` Core/Entities/ShipEntity.cpp:12469 | ✅ |
| `-[ShipEntity leaveWitchspace]` (11774) | `ShipEntity::leaveWitchspace` Core/Entities/ShipEntity.cpp:12486 | ✅ |
| `-[ShipEntity witchspaceLeavingEffects]` (11796) | `ShipEntity::witchspaceLeavingEffects` Core/Entities/ShipEntity.cpp:12512 | ✅ |
| `-[ShipEntity markAsOffender:]` (11823) | `ShipEntity::markAsOffender(int)` Core/Entities/ShipEntity.cpp:12541 | ✅ |
| `-[ShipEntity markAsOffender:withReason:]` (11828) | `ShipEntity::markAsOffender(int, OOLegalStatusReason)` Core/Entities/ShipEntity.cpp:12546 | ✅ |
| `-[ShipEntity switchLightsOn]` (11855) | `ShipEntity::switchLightsOn` Core/Entities/ShipEntity.cpp:12574 | ✅ |
| `-[ShipEntity switchLightsOff]` (11871) | `ShipEntity::switchLightsOff` Core/Entities/ShipEntity.cpp:12590 | ✅ |
| `-[ShipEntity lightsActive]` (11886) | `ShipEntity::lightsActive` Core/Entities/ShipEntity.cpp:12605 | ✅ |
| `-[ShipEntity setDestination:]` (11891) | `ShipEntity::setDestination` Core/Entities/ShipEntity.cpp:12610 | ✅ |
| `-[ShipEntity setEscortDestination:]` (11897) | `ShipEntity::setEscortDestination` Core/Entities/ShipEntity.cpp:12616 | ✅ |
| `-[ShipEntity canAcceptEscort:]` (11902) | `ShipEntity::canAcceptEscort` Core/Entities/ShipEntity.cpp:12621 | ✅ |
| `-[ShipEntity acceptAsEscort:]` (11923) | `ShipEntity::acceptAsEscort` Core/Entities/ShipEntity.cpp:12642 | ✅ |
| `-[ShipEntity updateEscortFormation]` (11983) | `ShipEntity::updateEscortFormation` Core/Entities/ShipEntity.cpp:12707 | ✅ |
| `-[ShipEntity refreshEscortPositions]` (11993) | `ShipEntity::refreshEscortPositions` Core/Entities/ShipEntity.cpp:12717 | ✅ |
| `-[ShipEntity coordinatesForEscortPosition:]` (12024) | `ShipEntity::coordinatesForEscortPosition` Core/Entities/ShipEntity.cpp:12744 | ✅ |
| `-[ShipEntity deployEscorts]` (12042) | `ShipEntity::deployEscorts` Core/Entities/ShipEntity.cpp:12762 | ❌ |
| `-[ShipEntity dockEscorts]` (12099) | `ShipEntity::dockEscorts` Core/Entities/ShipEntity.cpp:12823 | ✅ |
| `-[ShipEntity setTargetToNearestStationIncludingHostiles:]` (12133) | `ShipEntity::setTargetToNearestStationIncludingHostiles` Core/Entities/ShipEntity.cpp:12865 | ✅ |
| `-[ShipEntity setTargetToNearestFriendlyStation]` (12177) | `ShipEntity::setTargetToNearestFriendlyStation` Core/Entities/ShipEntity.cpp:12910 | ✅ |
| `-[ShipEntity setTargetToNearestStation]` (12183) | `ShipEntity::setTargetToNearestStation` Core/Entities/ShipEntity.cpp:12916 | ✅ |
| `-[ShipEntity setTargetToSystemStation]` (12189) | `ShipEntity::setTargetToSystemStation` Core/Entities/ShipEntity.cpp:12922 | ✅ |
| `-[ShipEntity landOnPlanet:]` (12214) | `ShipEntity::landOnPlanet` Core/Entities/ShipEntity.cpp:12955 | ✅ |
| `-[ShipEntity abortDocking]` (12231) | `ShipEntity::abortDocking` Core/Entities/ShipEntity.cpp:12974 | ✅ |
| `-[ShipEntity dockingInstructions]` (12241) | `ShipEntity::getDockingInstructions` Core/Entities/ShipEntity.cpp:12983 | ✅ |
| `-[ShipEntity broadcastThargoidDestroyed]` (12246) | `ShipEntity::broadcastThargoidDestroyed` Core/Entities/ShipEntity.cpp:12988 | ✅ |
| `AuthorityPredicate()` (12256) | `AuthorityPredicate` (+ `AuthorityPredicateParameter`) Core/Entities/ShipEntity.cpp:552 | ✅ |
| `-[ShipEntity broadcastHitByLaserFrom:]` (12274) | `ShipEntity::broadcastHitByLaserFrom` Core/Entities/ShipEntity.cpp:12998 | ✅ |
| `-[ShipEntity sendMessage:toShip:withUnpilotedOverride:]` (12301) | `ShipEntity::sendMessage` Core/Entities/ShipEntity.cpp:13024 | ✅ |
| `-[ShipEntity sendExpandedMessage:toShip:]` (12323) | `ShipEntity::sendExpandedMessage` Core/Entities/ShipEntity.cpp:13047 | ✅ |
| `-[ShipEntity broadcastAIMessage:]` (12356) | `ShipEntity::broadcastAIMessage` Core/Entities/ShipEntity.cpp:13085 | ✅ |
| `-[ShipEntity broadcastMessage:withUnpilotedOverride:]` (12368) | `ShipEntity::broadcastMessage` Core/Entities/ShipEntity.cpp:13098 | ✅ |
| `-[ShipEntity setCommsMessageColor]` (12394) | `ShipEntity::setCommsMessageColor` Core/Entities/ShipEntity.cpp:13128 | ✅ |
| `-[ShipEntity receiveCommsMessage:from:]` (12404) | `ShipEntity::receiveCommsMessage` Core/Entities/ShipEntity.cpp:13138 | ✅ |
| `-[ShipEntity commsMessage:withUnpilotedOverride:]` (12410) | `ShipEntity::commsMessage` Core/Entities/ShipEntity.cpp:13144 | ✅ |
| `-[ShipEntity markedForFines]` (12424) | `ShipEntity::markedForFines` Core/Entities/ShipEntity.cpp:13158 | ✅ |
| `-[ShipEntity markForFines]` (12429) | `ShipEntity::markForFines` Core/Entities/ShipEntity.cpp:13163 | ✅ |
| `-[ShipEntity isMining]` (12437) | `ShipEntity::isMining` Core/Entities/ShipEntity.cpp:13171 | ✅ |
| `-[ShipEntity interpretAIMessage:]` (12442) | `ShipEntity::interpretAIMessage` Core/Entities/ShipEntity.cpp:13176 | ✅ |
| `-[ShipEntity findBoundingBoxRelativeTo:i:j:k:]` (12466) | `ShipEntity::findBoundingBoxRelativeTo` Core/Entities/ShipEntity.cpp:13203 | ✅ |
| `-[ShipEntity spawn:]` (12473) | `ShipEntity::spawn` Core/Entities/ShipEntity.cpp:13210 | ✅ |
| `-[ShipEntity checkShipsInVicinityForWitchJumpExit]` (12493) | `ShipEntity::checkShipsInVicinityForWitchJumpExit` Core/Entities/ShipEntity.cpp:13228 | ✅ |
| `-[ShipEntity trackCloseContacts]` (12533) | `ShipEntity::getTrackCloseContacts` Core/Entities/ShipEntity.cpp:13269 | ✅ |
| `-[ShipEntity setTrackCloseContacts:]` (12538) | `ShipEntity::setTrackCloseContacts` Core/Entities/ShipEntity.cpp:13274 | ✅ |
| `-[ShipEntity claimAsSalvage]` (12555) | `ShipEntity::claimAsSalvage` Core/Entities/ShipEntity.cpp:13303 (inside `#if OO_SALVAGE_SUPPORT`, never defined; body still ObjC message syntax) | ➖ |
| `-[ShipEntity sendCoordinatesToPilot]` (12583) | `ShipEntity::sendCoordinatesToPilot` Core/Entities/ShipEntity.cpp:13331 (same, compiled out) | ➖ |
| `-[ShipEntity pilotArrived]` (12624) | `ShipEntity::pilotArrived` Core/Entities/ShipEntity.cpp:13379 (same, compiled out) | ➖ |
| `-[ShipEntity dumpSelfState]` (12632) | `ShipEntity::dumpSelfState` Core/Entities/ShipEntity.cpp:13387 | ✅ |
| `-[ShipEntity script]` (12709) | `ShipEntity::getScript` Core/Entities/ShipEntity.cpp:13469 | ✅ |
| `-[ShipEntity scriptInfo]` (12714) | `ShipEntity::getScriptInfo` Core/Entities/ShipEntity.cpp:13474 | ✅ |
| `-[ShipEntity overrideScriptInfo:]` (12719) | `ShipEntity::overrideScriptInfo` Core/Entities/ShipEntity.cpp:13479 | ✅ |
| `-[ShipEntity entityForShaderProperties]` (12731) | `ShipEntity::entityForShaderProperties` Core/Entities/ShipEntity.cpp:13492 | ✅ |
| `-[ShipEntity setDemoShip:]` (12736) | `ShipEntity::setDemoShip` Core/Entities/ShipEntity.cpp:13497 | ✅ |
| `-[ShipEntity isDemoShip]` (12745) | `ShipEntity::getIsDemoShip` Core/Entities/ShipEntity.cpp:13506 | ✅ |
| `-[ShipEntity setDemoStartTime:]` (12750) | `ShipEntity::setDemoStartTime` Core/Entities/ShipEntity.cpp:13511 | ✅ |
| `-[ShipEntity getDemoStartTime]` (12755) | `ShipEntity::getDemoStartTime` Core/Entities/ShipEntity.cpp:13516 | ✅ |
| `-[ShipEntity doScriptEvent:]` (12761) | `ShipEntity::doScriptEvent(PropertyId)` Core/Entities/ShipEntity.cpp:13522 | ✅ |
| `-[ShipEntity doScriptEvent:withArgument:]` (12768) | `ShipEntity::doScriptEvent(PropertyId, Entity*)` Core/Entities/ShipEntity.cpp:13531 | ⚠️ |
| `-[ShipEntity doScriptEvent:withArgument:andArgument:]` (12778) | `ShipEntity::doScriptEvent(PropertyId, Entity*, Entity*)` Core/Entities/ShipEntity.cpp:13541 | ⚠️ |
| `-[ShipEntity doScriptEvent:withArguments:]` (12790) | `ShipEntity::doScriptEvent(PropertyId, const std::vector<oo::PList>&)` Core/Entities/ShipEntity.cpp:13551 | ✅ |
| `-[ShipEntity doScriptEvent:withArguments:count:]` (12822) | `ShipEntity::doScriptEvent(PropertyId, Value*, unsigned)` Core/Entities/ShipEntity.cpp:13583 | ✅ |
| `-[ShipEntity doScriptEvent:inContext:withArguments:count:]` (12829) | `ShipEntity::doScriptEvent(PropertyId, Context, Value*, unsigned)` Core/Entities/ShipEntity.cpp:13590 | ✅ |
| `-[ShipEntity reactToAIMessage:context:]` (12836) | `ShipEntity::reactToAIMessage` Core/Entities/ShipEntity.cpp:13599 | ✅ |
| `-[ShipEntity sendAIMessage:]` (12841) | `ShipEntity::sendAIMessage` Core/Entities/ShipEntity.cpp:13605 | ✅ |
| `-[ShipEntity doScriptEvent:andReactToAIMessage:]` (12846) | `ShipEntity::doScriptEvent(PropertyId, const std::string&)` Core/Entities/ShipEntity.cpp:13611 | ✅ |
| `-[ShipEntity doScriptEvent:withArgument:andReactToAIMessage:]` (12852) | `ShipEntity::doScriptEvent(PropertyId, Entity*, const std::string&)` Core/Entities/ShipEntity.cpp:13617 | ✅ |
| `-[ShipEntity alertCondition]` (12860) | `ShipEntity::alertCondition` Core/Entities/ShipEntity.cpp:13625 | ✅ |
| `-[ShipEntity realAlertCondition]` (12871) | `ShipEntity::realAlertCondition` Core/Entities/ShipEntity.cpp:13636 | ✅ |
| `-[ShipEntity doNothing]` (12927) | `ShipEntity::doNothing` Core/Entities/ShipEntity.cpp:13699 | ✅ |
| `-[ShipEntity descriptionForObjDump]` (12932) | `ShipEntity::descriptionForObjDump` Core/Entities/ShipEntity.cpp:13704 | ✅ |
| `-[Entity(SubEntityRelationship) isShipWithSubEntityShip:]` (12947) | — (callers now hold a `ShipEntity*`; no `Entity` overload) | ➖ |
| `-[Entity(SubEntityRelationship) drawSubEntityImmediate:translucent:]` (12952) | — replaced by `cxx::OOSubEntityInterface::drawSubEntityImmediate` (pure virtual, Core/Entities/Entity.h:401); non-adopters are skipped by the caller (Core/Entities/ShipEntity.cpp:6003) | ➖ |
| `-[ShipEntity(SubEntityRelationship) isShipWithSubEntityShip:]` (12961) | `ShipEntity::isShipWithSubEntityShip` Core/Entities/ShipEntity.cpp:574 | ✅ |
| `OODefaultShipShaderMacros()` (12986) | `OODefaultShipShaderMacros` Core/Entities/ShipEntity.cpp:13720 | ✅ |
| `OOUniformBindingPermitted()` (12998) | `OOUniformBindingPermitted` Core/Entities/ShipEntity.cpp:13734 | ✅ |
| `getWeaponRangeFromType()` (13033) | `getWeaponRangeFromType` Core/Entities/ShipEntity.cpp:13766 | ✅ |
| `isWeaponNone()` (13038) | `isWeaponNone` Core/Entities/ShipEntity.cpp:13772 | ✅ |

**Differences:**

- ❌ **low** — `deployEscorts` assigns `target = oo::ToShip(primaryTarget())`; upstream sends the raw primary target. If the leader's primary target is not a ship, escorts get `addTarget(nullptr)` (a no-op, so they keep their old target) and `escortAttack` with `null` instead of the entity. — upstream `Core/Entities/ShipEntity.m:12085` ↔ port `Core/Entities/ShipEntity.cpp:12805`
- ⚠️ **low** — `deployEscorts` collects idle escorts in escort-group order (`std::vector`); upstream used an `NSMutableSet`, so pointer-hash order chose which `deployCount` escorts attack. The port's own comment says so; no ADR or bead is cited. The choice is deterministic now. — upstream `Core/Entities/ShipEntity.m:12068` ↔ port `Core/Entities/ShipEntity.cpp:12765`
- ❌ **low** — `launchEscapeCapsule`: upstream `[passengers addObject:passenger]` throws `NSInvalidArgumentException` when `launchPodWithCrew:` returns nil. The port pushes a null hold and carries on, so `shipLaunchedEscapePod` gets an array with a null element. — upstream `Core/Entities/ShipEntity.m:10842` ↔ port `Core/Entities/ShipEntity.cpp:11476`
- ⚠️ **low** — `dumpCargo` returns `void`; upstream returned the dumped pod's `commodityType` (or nil). The port comment says no caller read the value (AI method; PlayerEntity reads its commodity from `dumpCargoItem`). — upstream `Core/Entities/ShipEntity.m:10852` ↔ port `Core/Entities/ShipEntity.cpp:11488`
- ⚠️ **low** — `doScriptEvent:withArgument:` / `…andArgument:` took `id`, converted with `OOJSValueFromNativeObject`. The port takes only `Entity*` (via `OOJSEntityJSValue`); non-entity arguments go through the `std::vector<oo::PList>` overload (e.g. `receiveCommsMessage`, `dockEscorts`, `launchEscapeCapsule`). Per the comment, the `id` forms had no callers (bead oo-4aq6a.6, oo-9ht.39.16). — upstream `Core/Entities/ShipEntity.m:12768,12778` ↔ port `Core/Entities/ShipEntity.cpp:13529-13549`
- ➖ — `claimAsSalvage` / `sendCoordinatesToPilot` / `pilotArrived`: `OO_SALVAGE_SUPPORT` is defined in neither tree, so both compile this out. The port bodies still use unconverted ObjC message syntax (`[this setTargetToSystemStation]` etc.) and would not compile if the flag were enabled. — upstream `Core/Entities/ShipEntity.m:12553-12629` ↔ port `Core/Entities/ShipEntity.cpp:13301-13384`
- ➖ — `Entity (SubEntityRelationship)` category: the `Entity` default `isShipWithSubEntityShip:` (NO) is gone, because every caller now holds a `ShipEntity*`. The default no-op `drawSubEntityImmediate:` is replaced by `cxx::OOSubEntityInterface`, and the caller skips subentities that do not adopt it. Observable behaviour is the same. — upstream `Core/Entities/ShipEntity.m:12945-12957` ↔ port `Core/Entities/Entity.h:395-402`, `Core/Entities/ShipEntity.cpp:6003`
- subtle (✅) — `fireSubentityLaserShot`, miss branch: the port does `victim = oo::ToShip(parent->primaryTarget())`; upstream used the raw entity. With a non-ship primary target (e.g. a wormhole), upstream would send `setPrimaryAggressor:` to a non-ship (unrecognised selector). The port skips the reaction instead. — upstream `Core/Entities/ShipEntity.m:10218` ↔ port `Core/Entities/ShipEntity.cpp:10793`
- subtle (✅) — `interpretAIMessage` adds `if (tokens.size() < 3) return;`. Upstream `objectAtIndex:` would raise `NSRangeException` on a short `AGGRESSOR_SWITCHED_TARGET` message, which the engine never sends. — upstream `Core/Entities/ShipEntity.m:12447` ↔ port `Core/Entities/ShipEntity.cpp:13182`
- subtle (✅) — `fireWeapon` / `fireSubentityLaserShot` / `fireDirectLaserShotAt` pass `identifier().value_or("")` where upstream passed a possibly-nil `NSString` as `weaponIdentifier`. `ShipEntity::takeEnergyDamage` ignores it in both trees. Only `PlayerEntity::takeEnergyDamage` uses it, for shield-hit sounds, and there `""` and nil should resolve the same. — upstream `Core/Entities/ShipEntity.m:9959` ↔ port `Core/Entities/ShipEntity.cpp:10525`
- subtle (✅) — `setTrackCloseContacts:` clears `closeContactsInfo` instead of releasing it to nil or allocating a fresh dictionary. It is read only while tracking, and both trees start each tracking period with an empty record. — upstream `Core/Entities/ShipEntity.m:12538` ↔ port `Core/Entities/ShipEntity.cpp:13274`
- Checked and equivalent, the points of emphasis: weapon energy and heat costs (`energy -= weapon_energy_use * multiplier`, `*_weapon_temp += weapon_shot_temperature * multiplier`, the `WEAPON_COOLING_CUTOUT` tests, subentity lasers drawing on the parent's energy); missile selection, removal of invalid roles, the bounding-box eject loop, submunition owner and `missile_launch_time`; cascade mine eject speeds; `SHIP_ENERGY_DAMAGE_TO_HEAT_FACTOR` (same macro, inlined); `acceptAsEscort` limits and log texts; `dockEscorts` delays (`i*3+1.5`, `ABORT` at `+0.25`); `canAcceptEscort` docking-instructions gate; `dumpSelfState` log lines and flag order; `descriptionForObjDump` format.

## ShipEntityAI

<a id="shipentityai"></a>
Upstream `src/Core/Entities/ShipEntityAI.m` ↔ `Core/Entities/ShipEntityAI.cpp`

**Status:** done — 156 rows: 154 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[ShipEntity(AI) setAITo:]` (245) | `ShipEntity::setAITo` `Core/Entities/ShipEntityAI.cpp:105` | ✅ |
| `-[ShipEntity(AI) setAIScript:]` (268) | `ShipEntity::setAIScript` `Core/Entities/ShipEntityAI.cpp:131` | ✅ |
| `-[ShipEntity(AI) switchAITo:]` (287) | `ShipEntity::switchAITo` `Core/Entities/ShipEntityAI.cpp:146` | ✅ |
| `-[ShipEntity(AI) scanForHostiles]` (293) | `ShipEntity::scanForHostiles` `Core/Entities/ShipEntityAI.cpp:153` | ✅ |
| `-[ShipEntity(AI) groupAttackTarget]` (315) | `ShipEntity::groupAttackTarget` `Core/Entities/ShipEntityAI.cpp:175` | ✅ |
| `-[ShipEntity(AI) performAttack]` (350) | `ShipEntity::performAttack` `Core/Entities/ShipEntityAI.cpp:217` | ✅ |
| `-[ShipEntity(AI) performCollect]` (359) | `ShipEntity::performCollect` `Core/Entities/ShipEntityAI.cpp:226` | ✅ |
| `-[ShipEntity(AI) performEscort]` (365) | `ShipEntity::performEscort` `Core/Entities/ShipEntityAI.cpp:232` | ✅ |
| `-[ShipEntity(AI) performFaceDestination]` (373) | `ShipEntity::performFaceDestination` `Core/Entities/ShipEntityAI.cpp:240` | ✅ |
| `-[ShipEntity(AI) performFlee]` (379) | `ShipEntity::performFlee` `Core/Entities/ShipEntityAI.cpp:246` | ✅ |
| `-[ShipEntity(AI) performFlyToRangeFromDestination]` (394) | `ShipEntity::performFlyToRangeFromDestination` `Core/Entities/ShipEntityAI.cpp:261` | ✅ |
| `-[ShipEntity(AI) performHold]` (400) | `ShipEntity::performHold` `Core/Entities/ShipEntityAI.cpp:267` | ✅ |
| `-[ShipEntity(AI) performIdle]` (407) | `ShipEntity::performIdle` `Core/Entities/ShipEntityAI.cpp:274` | ✅ |
| `-[ShipEntity(AI) performIntercept]` (413) | `ShipEntity::performIntercept` `Core/Entities/ShipEntityAI.cpp:280` | ✅ |
| `-[ShipEntity(AI) performLandOnPlanet]` (419) | `ShipEntity::performLandOnPlanet` `Core/Entities/ShipEntityAI.cpp:286` | ✅ |
| `-[ShipEntity(AI) performMining]` (434) | `ShipEntity::performMining` `Core/Entities/ShipEntityAI.cpp:302` | ✅ |
| `-[ShipEntity(AI) performScriptedAI]` (446) | `ShipEntity::performScriptedAI` `Core/Entities/ShipEntityAI.cpp:314` | ✅ |
| `-[ShipEntity(AI) performScriptedAttackAI]` (452) | `ShipEntity::performScriptedAttackAI` `Core/Entities/ShipEntityAI.cpp:320` | ✅ |
| `-[ShipEntity(AI) performBuoyTumble]` (458) | `ShipEntity::performBuoyTumble` `Core/Entities/ShipEntityAI.cpp:326` | ✅ |
| `-[ShipEntity(AI) performStop]` (466) | `ShipEntity::performStop` `Core/Entities/ShipEntityAI.cpp:334` | ✅ |
| `-[ShipEntity(AI) performTumble]` (473) | `ShipEntity::performTumble` `Core/Entities/ShipEntityAI.cpp:341` | ✅ |
| `-[ShipEntity(AI) performHyperSpaceToSpecificSystem:]` (481) | `ShipEntity::performHyperSpaceToSpecificSystem` `Core/Entities/ShipEntityAI.cpp:349` | ✅ |
| `-[ShipEntity(AI) requestDockingCoordinates]` (486) | `ShipEntity::requestDockingCoordinates` `Core/Entities/ShipEntityAI.cpp:354` | ✅ |
| `-[ShipEntity(AI) recallDockingInstructions]` (536) | `ShipEntity::recallDockingInstructions` `Core/Entities/ShipEntityAI.cpp:406` | ✅ |
| `-[ShipEntity(AI) scanForNearestIncomingMissile]` (555) | `ShipEntity::scanForNearestIncomingMissile` `Core/Entities/ShipEntityAI.cpp:426` | ✅ |
| `-[ShipEntity(AI) enterPlayerWormhole]` (564) | `ShipEntity::enterPlayerWormhole` `Core/Entities/ShipEntityAI.cpp:436` | ✅ |
| `-[ShipEntity(AI) enterTargetWormhole]` (569) | `ShipEntity::enterTargetWormhole` `Core/Entities/ShipEntityAI.cpp:441` | ✅ |
| `-[ShipEntity(AI) wormholeEscorts]` (609) | `ShipEntity::wormholeEscorts` `Core/Entities/ShipEntityAI.cpp:481` | ✅ |
| `-[ShipEntity(AI) wormholeEntireGroup]` (635) | `ShipEntity::wormholeEntireGroup` `Core/Entities/ShipEntityAI.cpp:507` | ✅ |
| `-[ShipEntity(AI) suggestEscortTo:]` (641) | `ShipEntity::suggestEscortTo` `Core/Entities/ShipEntityAI.cpp:513` | ✅ |
| `-[ShipEntity(AI) broadcastDistressMessage]` (677) | `ShipEntity::broadcastDistressMessage` `Core/Entities/ShipEntityAI.cpp:551` | ✅ |
| `-[ShipEntity(AI) broadcastDistressMessageWithDumping:]` (683) | `ShipEntity::broadcastDistressMessageWithDumping` `Core/Entities/ShipEntityAI.cpp:557` | ✅ |
| `-[ShipEntity(PureAI) setStateTo:]` (752) | `ShipEntity::setStateTo` `Core/Entities/ShipEntityAI.cpp:820` | ✅ |
| `-[ShipEntity(PureAI) pauseAI:]` (757) | `ShipEntity::pauseAI` `Core/Entities/ShipEntityAI.cpp:826` | ✅ |
| `-[ShipEntity(PureAI) randomPauseAI:]` (762) | `ShipEntity::randomPauseAI` `Core/Entities/ShipEntityAI.cpp:832` | ✅ |
| `-[ShipEntity(PureAI) dropMessages:]` (778) | `ShipEntity::dropMessages` `Core/Entities/ShipEntityAI.cpp:849` | ✅ |
| `-[ShipEntity(PureAI) debugDumpPendingMessages]` (790) | `ShipEntity::debugDumpPendingMessages` `Core/Entities/ShipEntityAI.cpp:857` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToCurrentLocation]` (795) | `ShipEntity::setDestinationToCurrentLocation` `Core/Entities/ShipEntityAI.cpp:863` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToJinkPosition]` (801) | `ShipEntity::setDestinationToJinkPosition` `Core/Entities/ShipEntityAI.cpp:869` | ✅ |
| `-[ShipEntity(PureAI) setDesiredRangeTo:]` (808) | `ShipEntity::setDesiredRangeTo` `Core/Entities/ShipEntityAI.cpp:876` | ✅ |
| `-[ShipEntity(PureAI) setDesiredRangeForWaypoint]` (813) | `ShipEntity::setDesiredRangeForWaypoint` `Core/Entities/ShipEntityAI.cpp:881` | ✅ |
| `-[ShipEntity(PureAI) setSpeedTo:]` (818) | `ShipEntity::setSpeedTo` `Core/Entities/ShipEntityAI.cpp:886` | ✅ |
| `-[ShipEntity(PureAI) setSpeedFactorTo:]` (823) | `ShipEntity::setSpeedFactorTo` `Core/Entities/ShipEntityAI.cpp:891` | ✅ |
| `-[ShipEntity(PureAI) setSpeedToCruiseSpeed]` (828) | `ShipEntity::setSpeedToCruiseSpeed` `Core/Entities/ShipEntityAI.cpp:896` | ✅ |
| `-[ShipEntity(PureAI) setThrustFactorTo:]` (833) | `ShipEntity::setThrustFactorTo` `Core/Entities/ShipEntityAI.cpp:901` | ✅ |
| `-[ShipEntity(PureAI) setTargetToPrimaryAggressor]` (838) | `ShipEntity::setTargetToPrimaryAggressor` `Core/Entities/ShipEntityAI.cpp:906` | ✅ |
| `-[ShipEntity(PureAI) addPrimaryAggressorAsDefenseTarget]` (871) | `ShipEntity::addPrimaryAggressorAsDefenseTarget` `Core/Entities/ShipEntityAI.cpp:941` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestMerchantman]` (884) | `ShipEntity::scanForNearestMerchantman` `Core/Entities/ShipEntityAI.cpp:954` | ✅ |
| `-[ShipEntity(PureAI) scanForRandomMerchantman]` (913) | `ShipEntity::scanForRandomMerchantman` `Core/Entities/ShipEntityAI.cpp:983` | ✅ |
| `-[ShipEntity(PureAI) scanForLoot]` (937) | `ShipEntity::scanForLoot` `Core/Entities/ShipEntityAI.cpp:1009` | ✅ |
| `-[ShipEntity(PureAI) scanForRandomLoot]` (979) | `ShipEntity::scanForRandomLoot` `Core/Entities/ShipEntityAI.cpp:1056` | ✅ |
| `-[ShipEntity(PureAI) setTargetToFoundTarget]` (1007) | `ShipEntity::setTargetToFoundTarget` `Core/Entities/ShipEntityAI.cpp:1088` | ✅ |
| `-[ShipEntity(PureAI) addFoundTargetAsDefenseTarget]` (1016) | `ShipEntity::addFoundTargetAsDefenseTarget` `Core/Entities/ShipEntityAI.cpp:1098` | ✅ |
| `-[ShipEntity(PureAI) checkForFullHold]` (1026) | `ShipEntity::checkForFullHold` `Core/Entities/ShipEntityAI.cpp:1108` | ✅ |
| `-[ShipEntity(PureAI) getWitchspaceEntryCoordinates]` (1037) | `ShipEntity::getWitchspaceEntryCoordinates` `Core/Entities/ShipEntityAI.cpp:1122` | ✅ |
| `-[ShipEntity(PureAI) setDestinationFromCoordinates]` (1065) | `ShipEntity::setDestinationFromCoordinates` `Core/Entities/ShipEntityAI.cpp:1148` | ✅ |
| `-[ShipEntity(PureAI) setCoordinatesFromPosition]` (1070) | `ShipEntity::setCoordinatesFromPosition` `Core/Entities/ShipEntityAI.cpp:1153` | ✅ |
| `-[ShipEntity(PureAI) fightOrFleeMissile]` (1075) | `ShipEntity::fightOrFleeMissile` `Core/Entities/ShipEntityAI.cpp:1158` | ✅ |
| `-[ShipEntity(PureAI) setCourseToPlanet]` (1144) | `ShipEntity::setCourseToPlanet` `Core/Entities/ShipEntityAI.cpp:1235` | ✅ |
| `-[ShipEntity(PureAI) setTakeOffFromPlanet]` (1165) | `ShipEntity::setTakeOffFromPlanet` `Core/Entities/ShipEntityAI.cpp:1257` | ✅ |
| `-[ShipEntity(PureAI) landOnPlanet]` (1177) | `ShipEntity::landOnPlanet` `Core/Entities/ShipEntityAI.cpp:1269` | ✅ |
| `-[ShipEntity(PureAI) checkTargetLegalStatus]` (1183) | `ShipEntity::checkTargetLegalStatus` `Core/Entities/ShipEntityAI.cpp:1275` | ✅ |
| `-[ShipEntity(PureAI) checkOwnLegalStatus]` (1207) | `ShipEntity::checkOwnLegalStatus` `Core/Entities/ShipEntityAI.cpp:1304` | ✅ |
| `-[ShipEntity(PureAI) exitAIWithMessage:]` (1229) | `ShipEntity::exitAIWithMessage` `Core/Entities/ShipEntityAI.cpp:1331` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToTarget]` (1236) | `ShipEntity::setDestinationToTarget` `Core/Entities/ShipEntityAI.cpp:1337` | ✅ |
| `-[ShipEntity(PureAI) setDestinationWithinTarget]` (1243) | `ShipEntity::setDestinationWithinTarget` `Core/Entities/ShipEntityAI.cpp:1344` | ✅ |
| `-[ShipEntity(PureAI) checkCourseToDestination]` (1256) | `ShipEntity::checkCourseToDestination` `Core/Entities/ShipEntityAI.cpp:1357` | ✅ |
| `-[ShipEntity(PureAI) checkAegis]` (1272) | `ShipEntity::checkAegis` `Core/Entities/ShipEntityAI.cpp:1382` | ✅ |
| `-[ShipEntity(PureAI) checkEnergy]` (1308) | `ShipEntity::checkEnergy` `Core/Entities/ShipEntityAI.cpp:1426` | ✅ |
| `-[ShipEntity(PureAI) checkHeatInsulation]` (1325) | `ShipEntity::checkHeatInsulation` `Core/Entities/ShipEntityAI.cpp:1447` | ✅ |
| `-[ShipEntity(PureAI) findNewDefenseTarget]` (1336) | `ShipEntity::findNewDefenseTarget` `Core/Entities/ShipEntityAI.cpp:1460` | ✅ |
| `-[ShipEntity(PureAI) scanForOffenders]` (1351) | `ShipEntity::scanForOffenders` `Core/Entities/ShipEntityAI.cpp:1475` | ✅ |
| `-[ShipEntity(PureAI) setCourseToWitchpoint]` (1388) | `ShipEntity::setCourseToWitchpoint` `Core/Entities/ShipEntityAI.cpp:1511` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToWitchpoint]` (1396) | `ShipEntity::setDestinationToWitchpoint` `Core/Entities/ShipEntityAI.cpp:1519` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToStationBeacon]` (1401) | `ShipEntity::setDestinationToStationBeacon` `Core/Entities/ShipEntityAI.cpp:1524` | ✅ |
| `-[ShipEntity(PureAI) performHyperSpaceExit]` (1408) | `ShipEntity::performHyperSpaceExit` `Core/Entities/ShipEntityAI.cpp:1531` | ✅ |
| `-[ShipEntity(PureAI) performHyperSpaceExitWithoutReplacing]` (1413) | `ShipEntity::performHyperSpaceExitWithoutReplacing` `Core/Entities/ShipEntityAI.cpp:1536` | ✅ |
| `-[ShipEntity(PureAI) disengageAutopilot]` (1418) | `ShipEntity::disengageAutopilot` `Core/Entities/ShipEntityAI.cpp:1541` | ✅ |
| `-[ShipEntity(PureAI) wormholeGroup]` (1423) | `ShipEntity::wormholeGroup` `Core/Entities/ShipEntityAI.cpp:1546` | ✅ |
| `-[ShipEntity(PureAI) commsMessage:]` (1439) | `ShipEntity::commsMessage` `Core/Entities/ShipEntityAI.cpp:1566` | ✅ |
| `-[ShipEntity(PureAI) commsMessageByUnpiloted:]` (1444) | `ShipEntity::commsMessageByUnpiloted` `Core/Entities/ShipEntityAI.cpp:1571` | ✅ |
| `-[ShipEntity(PureAI) ejectCargo]` (1449) | `ShipEntity::ejectCargo` `Core/Entities/ShipEntityAI.cpp:1576` | ✅ |
| `-[ShipEntity(PureAI) scanForThargoid]` (1461) | `ShipEntity::scanForThargoid` `Core/Entities/ShipEntityAI.cpp:1589` | ✅ |
| `-[ShipEntity(PureAI) scanForNonThargoid]` (1466) | `ShipEntity::scanForNonThargoid` `Core/Entities/ShipEntityAI.cpp:1594` | ✅ |
| `-[ShipEntity(PureAI) thargonCheckMother]` (1488) | `ShipEntity::thargonCheckMother` `Core/Entities/ShipEntityAI.cpp:1616` | ✅ |
| `-[ShipEntity(PureAI) becomeUncontrolledThargon]` (1512) | `ShipEntity::becomeUncontrolledThargon` `Core/Entities/ShipEntityAI.cpp:1641` | ✅ |
| `-[ShipEntity(PureAI) checkDistanceTravelled]` (1536) | `ShipEntity::checkDistanceTravelled` `Core/Entities/ShipEntityAI.cpp:1667` | ✅ |
| `-[ShipEntity(PureAI) fightOrFleeHostiles]` (1542) | `ShipEntity::fightOrFleeHostiles` `Core/Entities/ShipEntityAI.cpp:1675` | ✅ |
| `-[ShipEntity(PureAI) suggestEscort]` (1585) | `ShipEntity::suggestEscort` `Core/Entities/ShipEntityAI.cpp:1724` | ✅ |
| `-[ShipEntity(PureAI) escortCheckMother]` (1591) | `ShipEntity::escortCheckMother` `Core/Entities/ShipEntityAI.cpp:1730` | ✅ |
| `-[ShipEntity(PureAI) checkGroupOddsVersusTarget]` (1607) | `ShipEntity::checkGroupOddsVersusTarget` `Core/Entities/ShipEntityAI.cpp:1748` | ✅ |
| `-[ShipEntity(PureAI) scanForFormationLeader]` (1621) | `ShipEntity::scanForFormationLeader` `Core/Entities/ShipEntityAI.cpp:1767` | ✅ |
| `-[ShipEntity(PureAI) messageMother:]` (1652) | `ShipEntity::messageMother` `Core/Entities/ShipEntityAI.cpp:1800` | ✅ |
| `-[ShipEntity(PureAI) messageSelf:]` (1665) | `ShipEntity::messageSelf` `Core/Entities/ShipEntityAI.cpp:1809` | ✅ |
| `-[ShipEntity(PureAI) setPlanetPatrolCoordinates]` (1670) | `ShipEntity::setPlanetPatrolCoordinates` `Core/Entities/ShipEntityAI.cpp:1814` | ✅ |
| `-[ShipEntity(PureAI) setSunSkimStartCoordinates]` (1732) | `ShipEntity::setSunSkimStartCoordinates` `Core/Entities/ShipEntityAI.cpp:1877` | ✅ |
| `-[ShipEntity(PureAI) setSunSkimEndCoordinates]` (1749) | `ShipEntity::setSunSkimEndCoordinates` `Core/Entities/ShipEntityAI.cpp:1897` | ✅ |
| `-[ShipEntity(PureAI) setSunSkimExitCoordinates]` (1760) | `ShipEntity::setSunSkimExitCoordinates` `Core/Entities/ShipEntityAI.cpp:1910` | ✅ |
| `-[ShipEntity(PureAI) patrolReportIn]` (1779) | `ShipEntity::patrolReportIn` `Core/Entities/ShipEntityAI.cpp:1930` | ✅ |
| `-[ShipEntity(PureAI) checkForMotherStation]` (1788) | `ShipEntity::checkForMotherStation` `Core/Entities/ShipEntityAI.cpp:1940` | ✅ |
| `-[ShipEntity(PureAI) sendTargetCommsMessage:]` (1804) | `ShipEntity::sendTargetCommsMessage` `Core/Entities/ShipEntityAI.cpp:1959` | ✅ |
| `-[ShipEntity(PureAI) markTargetForFines]` (1814) | `ShipEntity::markTargetForFines` `Core/Entities/ShipEntityAI.cpp:1969` | ✅ |
| `-[ShipEntity(PureAI) markTargetForOffence:]` (1825) | `ShipEntity::markTargetForOffence` `Core/Entities/ShipEntityAI.cpp:1982` | ✅ |
| `-[ShipEntity(PureAI) storeTarget]` (1838) | `ShipEntity::storeTarget` `Core/Entities/ShipEntityAI.cpp:1996` | ✅ |
| `-[ShipEntity(PureAI) recallStoredTarget]` (1849) | `ShipEntity::recallStoredTarget` `Core/Entities/ShipEntityAI.cpp:2012` | ✅ |
| `-[ShipEntity(PureAI) scanForRocks]` (1871) | `ShipEntity::scanForRocks` `Core/Entities/ShipEntityAI.cpp:2036` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToDockingAbort]` (1907) | `ShipEntity::setDestinationToDockingAbort` `Core/Entities/ShipEntityAI.cpp:2072` | ✅ |
| `-[ShipEntity(PureAI) requestNewTarget]` (1936) | `ShipEntity::requestNewTarget` `Core/Entities/ShipEntityAI.cpp:2101` | ✅ |
| `-[ShipEntity(PureAI) rollD:]` (1965) | `ShipEntity::rollD` `Core/Entities/ShipEntityAI.cpp:2131` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithPrimaryRole:]` (1977) | `ShipEntity::scanForNearestShipWithPrimaryRole` `Core/Entities/ShipEntityAI.cpp:2143` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipHavingRole:]` (1982) | `ShipEntity::scanForNearestShipHavingRole` `Core/Entities/ShipEntityAI.cpp:2148` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithAnyPrimaryRole:]` (1987) | `ShipEntity::scanForNearestShipWithAnyPrimaryRole` `Core/Entities/ShipEntityAI.cpp:2153` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipHavingAnyRole:]` (1993) | `ShipEntity::scanForNearestShipHavingAnyRole` `Core/Entities/ShipEntityAI.cpp:2159` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithScanClass:]` (1999) | `ShipEntity::scanForNearestShipWithScanClass` `Core/Entities/ShipEntityAI.cpp:2165` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithoutPrimaryRole:]` (2005) | `ShipEntity::scanForNearestShipWithoutPrimaryRole` `Core/Entities/ShipEntityAI.cpp:2171` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipNotHavingRole:]` (2010) | `ShipEntity::scanForNearestShipNotHavingRole` `Core/Entities/ShipEntityAI.cpp:2176` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithoutAnyPrimaryRole:]` (2015) | `ShipEntity::scanForNearestShipWithoutAnyPrimaryRole` `Core/Entities/ShipEntityAI.cpp:2181` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipNotHavingAnyRole:]` (2021) | `ShipEntity::scanForNearestShipNotHavingAnyRole` `Core/Entities/ShipEntityAI.cpp:2187` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithoutScanClass:]` (2027) | `ShipEntity::scanForNearestShipWithoutScanClass` `Core/Entities/ShipEntityAI.cpp:2193` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipMatchingPredicate:]` (2033) | `ShipEntity::scanForNearestShipMatchingPredicate` `Core/Entities/ShipEntityAI.cpp:2199` | ✅ |
| `-[ShipEntity(PureAI) setCoordinates:]` (2126) | `ShipEntity::setCoordinates` `Core/Entities/ShipEntityAI.cpp:2296` | ✅ |
| `-[ShipEntity(PureAI) checkForNormalSpace]` (2158) | `ShipEntity::checkForNormalSpace` `Core/Entities/ShipEntityAI.cpp:2326` | ✅ |
| `-[ShipEntity(PureAI) setTargetToRandomStation]` (2166) | `ShipEntity::setTargetToRandomStation` `Core/Entities/ShipEntityAI.cpp:2337` | ✅ |
| `-[ShipEntity(PureAI) setTargetToLastStation]` (2210) | `ShipEntity::setTargetToLastStation` `Core/Entities/ShipEntityAI.cpp:2383` | ✅ |
| `-[ShipEntity(PureAI) addFuel:]` (2222) | `ShipEntity::addFuel` `Core/Entities/ShipEntityAI.cpp:2396` | ✅ |
| `-[ShipEntity(PureAI) scriptActionOnTarget:]` (2227) | `ShipEntity::scriptActionOnTarget` `Core/Entities/ShipEntityAI.cpp:2401` | ✅ |
| `-[ShipEntity(PureAI) safeScriptActionOnTarget:]` (2256) | `ShipEntity::safeScriptActionOnTarget` `Core/Entities/ShipEntityAI.cpp:2431` | ✅ |
| `-[ShipEntity(PureAI) sendScriptMessage:]` (2274) | `ShipEntity::sendScriptMessage` `Core/Entities/ShipEntityAI.cpp:2449` | ⚠️ |
| `-[ShipEntity(PureAI) ai_throwSparks]` (2287) | `ShipEntity::ai_throwSparks` `Core/Entities/ShipEntityAI.cpp:2465` | ✅ |
| `-[ShipEntity(PureAI) explodeSelf]` (2292) | `ShipEntity::explodeSelf` `Core/Entities/ShipEntityAI.cpp:2470` | ✅ |
| `-[ShipEntity(PureAI) ai_debugMessage:]` (2297) | `ShipEntity::ai_debugMessage` `Core/Entities/ShipEntityAI.cpp:2475` | ✅ |
| `-[ShipEntity(PureAI) targetFirstBeaconWithCode:]` (2306) | `ShipEntity::targetFirstBeaconWithCode` `Core/Entities/ShipEntityAI.cpp:2484` | ✅ |
| `-[ShipEntity(PureAI) targetNextBeaconWithCode:]` (2316) | `ShipEntity::targetNextBeaconWithCode` `Core/Entities/ShipEntityAI.cpp:2497` | ✅ |
| `-[ShipEntity(PureAI) setRacepointsFromTarget]` (2347) | `ShipEntity::setRacepointsFromTarget` `Core/Entities/ShipEntityAI.cpp:2536` | ✅ |
| `-[ShipEntity(PureAI) performFlyRacepoints]` (2367) | `ShipEntity::performFlyRacepoints` `Core/Entities/ShipEntityAI.cpp:2558` | ✅ |
| `-[ShipEntity(OOAIPrivate) checkFoundTarget]` (2378) | `ShipEntity::checkFoundTarget` `Core/Entities/ShipEntityAI.cpp:621` | ✅ |
| `-[ShipEntity(OOAIPrivate) performHyperSpaceExitReplace:]` (2387) | `ShipEntity::performHyperSpaceExitReplace` `Core/Entities/ShipEntityAI.cpp:632` | ✅ |
| `-[ShipEntity(OOAIPrivate) performHyperSpaceExitReplace:toSystem:]` (2392) | `ShipEntity::performHyperSpaceExitReplace` `Core/Entities/ShipEntityAI.cpp:637` | ✅ |
| `-[ShipEntity(OOAIPrivate) scanForNearestShipWithPredicate:parameter:]` (2466) | `ShipEntity::scanForNearestShipWithPredicate` `Core/Entities/ShipEntityAI.cpp:719` | ✅ |
| `-[ShipEntity(OOAIPrivate) scanForNearestShipWithNegatedPredicate:parameter:]` (2492) | `ShipEntity::scanForNearestShipWithNegatedPredicate` `Core/Entities/ShipEntityAI.cpp:745` | ✅ |
| `-[ShipEntity(OOAIPrivate) acceptDistressMessageFrom:]` (2498) | `ShipEntity::acceptDistressMessageFrom` `Core/Entities/ShipEntityAI.cpp:751` | ✅ |
| `-[StationEntity(OOAIPrivate) acceptDistressMessageFrom:]` (2517) | `StationEntity::acceptDistressMessageFrom` `Core/Entities/ShipEntityAI.cpp:802` | ✅ |
| `-[ShipEntity(OOAIStationStubs) increaseAlertLevel]` (2540, `STATION_STUB_NOARG`) | `ShipEntity::increaseAlertLevel` `Core/Entities/ShipEntityAI.cpp:775` | ✅ |
| `-[ShipEntity(OOAIStationStubs) decreaseAlertLevel]` (2541, `STATION_STUB_NOARG`) | `ShipEntity::decreaseAlertLevel` `Core/Entities/ShipEntityAI.cpp:776` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchPolice]` (2542, `STATION_STUB_NOARG`) | `ShipEntity::launchPolice` `Core/Entities/ShipEntityAI.cpp:778` | ⚠️ |
| `-[ShipEntity(OOAIStationStubs) launchDefenseShip]` (2543, `STATION_STUB_NOARG`) | `ShipEntity::launchDefenseShip` `Core/Entities/ShipEntityAI.cpp:784` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchScavenger]` (2544, `STATION_STUB_NOARG`) | `ShipEntity::launchScavenger` `Core/Entities/ShipEntityAI.cpp:785` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchMiner]` (2545, `STATION_STUB_NOARG`) | `ShipEntity::launchMiner` `Core/Entities/ShipEntityAI.cpp:786` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchPirateShip]` (2546, `STATION_STUB_NOARG`) | `ShipEntity::launchPirateShip` `Core/Entities/ShipEntityAI.cpp:787` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchShuttle]` (2547, `STATION_STUB_NOARG`) | `ShipEntity::launchShuttle` `Core/Entities/ShipEntityAI.cpp:788` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchTrader]` (2548, `STATION_STUB_NOARG`) | `ShipEntity::launchTrader` `Core/Entities/ShipEntityAI.cpp:789` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchEscort]` (2549, `STATION_STUB_NOARG`) | `ShipEntity::launchEscort` `Core/Entities/ShipEntityAI.cpp:790` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchPatrol]` (2550) | `ShipEntity::launchPatrol` `Core/Entities/ShipEntityAI.cpp:792` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchShipWithRole:]` (2555, `STATION_STUB_ARG`) | `ShipEntity::launchShipWithRole` `Core/Entities/ShipEntityAI.cpp:798` | ✅ |
| `-[ShipEntity(OOAIStationStubs) abortAllDockings]` (2556, `STATION_STUB_NOARG`) | `ShipEntity::abortAllDockings` `Core/Entities/ShipEntityAI.cpp:799` | ✅ |
| AI-plist dispatch: `Resources/Config/whitelist.plist` `ai_methods` + `ai_and_action_methods` (168 names) and `ai_method_aliases`, sent by `-performSelector:withObject:` (`AI.m:809-870`) | one by-name row per selector in `Core/Entities/OOEntityCalledByNameTable.h` (e.g. `pauseAI:` :2360, `launchPatrol` :2356, `rollD:` :2435) | ✅ |

**Differences:**

- ⚠️ **low** — `sendScriptMessage:` with an empty or whitespace-only message: upstream raised `NSRangeException` at `-objectAtIndex:0`, which aborted the AI action. The port does nothing; the code comment says this is deliberate — upstream `Core/Entities/ShipEntityAI.m:2278-2283` ↔ port `Core/Entities/ShipEntityAI.cpp:2453-2462`
- ⚠️ **low** — The ship stub `launchPolice` returns an empty `oo::PList` instead of `void`, so that the by-name row can return the station's launched ships (cites ADR-0055 item 5). It still logs `ai.invalid.notAStation` with the same text — upstream `Core/Entities/ShipEntityAI.m:2542` ↔ port `Core/Entities/ShipEntityAI.cpp:778-782`
- ✅ note — AI-plist reachability: every name in `whitelist.plist` `ai_methods` + `ai_and_action_methods` (168), and every alias target, resolves to a row in `OOEntityCalledByNameTable.h` with the right ship, station or dock routing. The port's whitelist is byte-identical to upstream's. The only methods of this file without a row take non-string arguments (`suggestEscortTo:`, `acceptDistressMessageFrom:`, `performHyperSpaceExitReplace:`, `performHyperSpaceToSpecificSystem:`, `broadcastDistressMessageWithDumping:`, the predicate scans), and none of them is whitelisted — port `Core/Entities/OOEntityCalledByNameTable.h:2346-2445`
- ✅ note — Constants and search ranges match upstream: `desired_range = 1250*randf()+750`; flee jink 400 and the aspect test `> 0.9995` with `randf() < 0.15`; docking-request range `SCANNER_MAX_RANGE2 * 6.25`; distress spacing `messageTime > 2*randf()` and the beg threshold `0.375*maxEnergy`; offence marks 8 (distress), 64 (attacked police) and `1|(ranrot&15)` (assisting); `scanForOffenders` `gov*0.4` against `ranrot&255` (1.0 without a sun); patrol legs at 5 km and 25 km with `desired_range` 250 and a `randf() < .25` chance to dock; witchspace-entry offset 10 km and `maxFlightSpeed*10`; dock-abort back-off 8 km; sun-skim exit 10 km; `ejectCargo` 10% of the hold, cut below 16, one canister every 0.75 s. Every AI message string (`TARGET_FOUND`, `NOTHING_FOUND`, `HOLD_FULL`, `ROLL_%d`, `AIMS_AGGRESSOR_SWITCHED_TARGET %d %d`, …) and its order is unchanged, and so are the RNG draw order and the scanner-range loops — upstream `ShipEntityAI.m` passim ↔ port `ShipEntityAI.cpp` passim
- ✅ note — The predicate parameters changed type with the predicates: `HasScanClassPredicate` takes an `OOScanClass*` (was `NSNumber`), the role predicates take a `std::string*`, and the role-set predicates take a `std::vector<std::string>*` (was `NSSet`; membership is the same) — upstream `Core/OOEntityFilterPredicate.m:108-164` ↔ port `Core/OOEntityFilterPredicate.cpp:111-179`
- ✅ note — `ejectCargo`'s `-performSelector:withObject:afterDelay:` became `oo::ScheduleEntityCall` (a deferred call that holds the entity), with the same delays `0.75*i` — upstream `Core/Entities/ShipEntityAI.m:1456-1458` ↔ port `Core/Entities/ShipEntityAI.cpp:1583-1586`
- ✅ note — `checkAegis`'s invalid-state `NSLog` is now `OO_LOG("unclassified", …)`, which is the class upstream gave a routed NSLog (`kOOLogUnconvertedNSLog`, `OOLogging.m:604`) — upstream `Core/Entities/ShipEntityAI.m:1303` ↔ port `Core/Entities/ShipEntityAI.cpp:1420`

## ShipEntityLoadRestore

<a id="shipentityloadrestore"></a>
Upstream `src/Core/Entities/ShipEntityLoadRestore.m` ↔ `Core/Entities/ShipEntityLoadRestore.cpp`

**Status:** done — 7 rows: 6 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `KEY_*` save-game key table (38-61) | `KEY_*` macros `Core/Entities/ShipEntityLoadRestore.cpp:42-65` (identical spellings) | ✅ |
| `-[ShipEntity(LoadRestore) savedShipDictionaryWithContext:]` (75) | `ShipEntity::savedShipDictionaryWithContext` `Core/Entities/ShipEntityLoadRestore.cpp:85` | ✅ |
| `+[ShipEntity(LoadRestore) shipRestoredFromDictionary:]` (163) | `ShipEntity::shipRestoredFromDictionary` (static) `Core/Entities/ShipEntityLoadRestore.cpp:179` | ❌ |
| `-[ShipEntity(LoadRestore) simplifyShipdata:andGetDeletes:]` (251) | `ShipEntity::simplifyShipdata` `Core/Entities/ShipEntityLoadRestore.cpp:305` | ✅ |
| `StripIgnoredKeys()` (292) | `StripIgnoredKeys` (anon ns) `Core/Entities/ShipEntityLoadRestore.cpp:341` | ✅ |
| `GroupIDForGroup()` (304) | `GroupIDForGroup` (anon ns, `OOShipSaveContext`) `Core/Entities/ShipEntityLoadRestore.cpp:352` | ✅ |
| `GroupForGroupID()` (341) | `GroupForGroupID` (anon ns) `Core/Entities/ShipEntityLoadRestore.cpp:375` | ✅ |

**Differences:**

- ❌ **low** — When the restored dictionary has no `primary_role` (or a value that is not a string or number), the port writes `ship->primaryRole = std::nullopt` with no null check. If the ship's init failed (`newStationObject`/`NewShipObject` returned null), this dereferences null. Upstream sent `-setPrimaryRole:nil` to nil, which did nothing, and returned nil — upstream `Core/Entities/ShipEntityLoadRestore.m:194` ↔ port `Core/Entities/ShipEntityLoadRestore.cpp:220-225`
- ✅ note — The save keys and restore defaults match: `AI` defaults to `"nullAI.plist"`; `energy_level` defaults to `1.0` (written only if `energy != maxEnergy`, as a double, which is what `oo_setFloat:` stored); `position` defaults to `kZeroHPVector` and `orientation` to `kIdentityQuaternion` (each written only when different from that default); `group` and `escort_group` default to `NSNotFound`; `is_group_leader` defaults to NO. The forced overrides `auto_ai = NO` and `escorts = 0` are kept, and the 17 `StripIgnoredKeys` names are identical — upstream `Core/Entities/ShipEntityLoadRestore.m:38-61,185-246,296` ↔ port `Core/Entities/ShipEntityLoadRestore.cpp:42-65,206-300,343`
- ✅ note — Where upstream would raise on a nil value in `-setObject:forKey:` (nil `_shipKey`, role string, primary role, AI `associatedJS`), the port writes `""` or omits the key; the code comments say so. These are crash paths upstream, not reachable in normal play — upstream `Core/Entities/ShipEntityLoadRestore.m:81,85,109,154` ↔ port `Core/Entities/ShipEntityLoadRestore.cpp:92,96-99,124,168-170`
- ✅ note — `shipdata_deletes` is listed in key byte order, where upstream used `NSDictionary` hash order. It is applied as a set of removals, so only the order in the save file changes — upstream `Core/Entities/ShipEntityLoadRestore.m:266-271` ↔ port `Core/Entities/ShipEntityLoadRestore.cpp:317-322`
- ✅ note — The ship class is chosen by `Universe::isStationShipDictionary`, which carries the same roles/`isCarrier`/`is_carrier` priority as `-shipClassForShipDictionary:` — upstream `Core/Universe.m:3777-3796` ↔ port `Core/Universe.cpp:4258-4277`, `Core/Entities/ShipEntityLoadRestore.cpp:211-214`

## ShipEntityScriptMethods

<a id="shipentityscriptmethods"></a>
Upstream `src/Core/Entities/ShipEntityScriptMethods.m` ↔ `Core/Entities/ShipEntityScriptMethods.cpp`

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[ShipEntity(ScriptMethods) ejectShipOfType:]` (34) | `ShipEntity::ejectShipOfType` `Core/Entities/ShipEntityScriptMethods.cpp:36` | ✅ |
| `-[ShipEntity(ScriptMethods) ejectShipOfRole:]` (47) | `ShipEntity::ejectShipOfRole` `Core/Entities/ShipEntityScriptMethods.cpp:49` | ✅ |
| `-[ShipEntity(ScriptMethods) spawnShipsWithRole:count:]` (60) | `ShipEntity::spawnShipsWithRole` `Core/Entities/ShipEntityScriptMethods.cpp:62` | ✅ |

**Differences:**

- ✅ note — `spawnShipsWithRole:count:` keeps the `script.debug.note.addShips` log, the submunition check (`is_submunition` only when the missile flag is set), and the owner rules for submunitions and mines. `count == 0` returns an empty array; otherwise one spawn is attempted per count, as in the `do … while (--count)` loop — upstream `Core/Entities/ShipEntityScriptMethods.m:60-89` ↔ port `Core/Entities/ShipEntityScriptMethods.cpp:62-97`

## StationEntity

<a id="stationentity"></a>
Upstream `src/Core/Entities/StationEntity.m` ↔ `Core/Entities/StationEntity.cpp`

**Status:** done — 112 rows: 107 ✅ 2 ⚠️ 1 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `_shipsOnHold` ivar (`StationEntity.h:53`, `OOWeakSet`) | `_shipsOnHold` `oo::WeakSet<Entity>` `Core/Entities/StationEntity.h:209` | ❌ |
| `@interface StationEntity (mwDebug)` `dbgGetShipsOnApproach`/`dbgGetIdLocks`/`dbgDumpIdLocks` (67-69, declared only, never implemented) | — | ➖ |
| `-[StationEntity isUnpiloted]` (76) | `StationEntity::isUnpiloted` `Core/Entities/StationEntity.cpp:727` | ✅ |
| `-[StationEntity equivalentTechLevel]` (81) | `StationEntity::getEquivalentTechLevel` `Core/Entities/StationEntity.cpp:747` | ✅ |
| `-[StationEntity setEquivalentTechLevel:]` (90) | `StationEntity::setEquivalentTechLevel` `Core/Entities/StationEntity.cpp:756` | ✅ |
| `-[StationEntity virtualPortDimensions]` (95) | `StationEntity::virtualPortDimensions` `Core/Entities/StationEntity.cpp:761` | ✅ |
| `-[StationEntity playerReservedDock]` (100) | `StationEntity::playerReservedDock` `Core/Entities/StationEntity.cpp:766` | ✅ |
| `-[StationEntity beaconPosition]` (105) | `StationEntity::beaconPosition` `Core/Entities/StationEntity.cpp:771` | ✅ |
| `-[StationEntity equipmentPriceFactor]` (114) | `StationEntity::getEquipmentPriceFactor` `Core/Entities/StationEntity.cpp:780` | ✅ |
| `-[StationEntity marketCapacity]` (119) | `StationEntity::getMarketCapacity` `Core/Entities/StationEntity.cpp:785` | ✅ |
| `-[StationEntity marketDefinition]` (124) | `StationEntity::getMarketDefinition` `Core/Entities/StationEntity.cpp:790` | ✅ |
| `-[StationEntity marketScriptName]` (129) | `StationEntity::getMarketScriptName` `Core/Entities/StationEntity.cpp:795` | ✅ |
| `-[StationEntity marketMonitored]` (134) | `StationEntity::getMarketMonitored` `Core/Entities/StationEntity.cpp:800` | ✅ |
| `-[StationEntity marketBroadcast]` (142) | `StationEntity::getMarketBroadcast` `Core/Entities/StationEntity.cpp:808` | ✅ |
| `-[StationEntity legalStatusOfManifest:export:]` (150) | `StationEntity::legalStatusOfManifest` `Core/Entities/StationEntity.cpp:816` | ✅ |
| `-[StationEntity localMarket]` (166) | `StationEntity::getLocalMarket` `Core/Entities/StationEntity.cpp:831` | ✅ |
| `-[StationEntity setLocalMarket:]` (179) | `StationEntity::setLocalMarket` `Core/Entities/StationEntity.cpp:844` | ✅ |
| `-[StationEntity localMarketForScripting]` (184) | `StationEntity::localMarketForScripting` `Core/Entities/StationEntity.cpp:851` | ✅ |
| `-[StationEntity setPrice:forCommodity:]` (189) | `StationEntity::setPrice` `Core/Entities/StationEntity.cpp:857` | ✅ |
| `-[StationEntity setQuantity:forCommodity:]` (194) | `StationEntity::setQuantity` `Core/Entities/StationEntity.cpp:864` | ✅ |
| `-[StationEntity localShipyard]` (199) | `StationEntity::getLocalShipyard` `Core/Entities/StationEntity.cpp:871` | ✅ |
| `-[StationEntity setLocalShipyard:]` (204) | `StationEntity::setLocalShipyard` `Core/Entities/StationEntity.cpp:876` | ✅ |
| `-[StationEntity localInterfaces]` (211) | `StationEntity::getLocalInterfaces` `Core/Entities/StationEntity.cpp:881` | ✅ |
| `-[StationEntity setInterfaceDefinition:forKey:]` (216) | `StationEntity::setInterfaceDefinition` `Core/Entities/StationEntity.cpp:886` | ✅ |
| `-[StationEntity initialiseLocalMarket]` (225) | `StationEntity::initialiseLocalMarket` `Core/Entities/StationEntity.cpp:895` | ✅ |
| `-[StationEntity setPlanet:]` (232) | `StationEntity::setPlanet` `Core/Entities/StationEntity.cpp:901` | ✅ |
| `-[StationEntity planet]` (240) | `StationEntity::getPlanet` `Core/Entities/StationEntity.cpp:909` | ✅ |
| `-[StationEntity countOfDockedContractors]` (245) | `StationEntity::countOfDockedContractors` `Core/Entities/StationEntity.cpp:915` | ✅ |
| `-[StationEntity countOfDockedPolice]` (250) | `StationEntity::countOfDockedPolice` `Core/Entities/StationEntity.cpp:920` | ✅ |
| `-[StationEntity countOfDockedDefenders]` (255) | `StationEntity::countOfDockedDefenders` `Core/Entities/StationEntity.cpp:925` | ✅ |
| `-[StationEntity dockSubEntityEnumerator]` (260) | `StationEntity::dockSubEntities` `Core/Entities/StationEntity.cpp:930` (held snapshot vector, same order and `isDock` filter) | ➖ |
| `-[StationEntity sanityCheckShipsOnApproach]` (265) | `StationEntity::sanityCheckShipsOnApproach` `Core/Entities/StationEntity.cpp:1299` | ✅ |
| `-[StationEntity launchShip:]` (283) | `StationEntity::launchShip` `Core/Entities/StationEntity.cpp:1317` | ✅ |
| `-[StationEntity abortAllDockings]` (312) | `StationEntity::abortAllDockings` `Core/Entities/StationEntity.cpp:1351` | ✅ |
| `-[StationEntity autoDockShipsOnHold]` (343) | `StationEntity::autoDockShipsOnHold` `Core/Entities/StationEntity.cpp:1389` | ✅ |
| `-[StationEntity autoDockShipsOnApproach]` (354) | `StationEntity::autoDockShipsOnApproach` `Core/Entities/StationEntity.cpp:1399` | ✅ |
| `-[StationEntity portUpVectorForShip:]` (368) | `StationEntity::portUpVectorForShip` `Core/Entities/StationEntity.cpp:1414` | ✅ |
| `OOMakeDockingInstructions()` (380) | `cxx_OOMakeDockingInstructions` `Core/Entities/StationEntity.cpp:72` | ✅ |
| `-[StationEntity dockingInstructionsForShip:]` (401) | `StationEntity::dockingInstructionsForShip` `Core/Entities/StationEntity.cpp:1428` | ✅ |
| `-[StationEntity holdPositionInstructionForShip:]` (503) | `StationEntity::holdPositionInstructionForShip` `Core/Entities/StationEntity.cpp:1530` | ✅ |
| `-[StationEntity abortDockingForShip:]` (513) | `StationEntity::abortDockingForShip` `Core/Entities/StationEntity.cpp:1540` | ✅ |
| `-[StationEntity initWithKey:definition:]` (535) | `StationEntity::newStationObject` `Core/Entities/StationEntity.cpp:699` + `initStationDefaults` `:707` | ✅ |
| `-[StationEntity dealloc]` (551) | `StationEntity::willDealloc` `Core/Entities/StationEntity.cpp:718` (other members released by destructor) | ✅ |
| `-[StationEntity setUpShipFromDictionary:]` (566) | `StationEntity::setUpShipFromDictionary` `Core/Entities/StationEntity.cpp:942` | ✅ |
| `-[StationEntity setUpSubEntities]` (655) | `StationEntity::setUpSubEntities` `Core/Entities/StationEntity.cpp:1033` | ✅ |
| `-[StationEntity shipIsInDockingCorridor:]` (700) | `StationEntity::shipIsInDockingCorridor` `Core/Entities/StationEntity.cpp:1564` | ✅ |
| `-[StationEntity pullInShipIfPermitted:]` (717) | `StationEntity::pullInShipIfPermitted` `Core/Entities/StationEntity.cpp:1580` | ✅ |
| `-[StationEntity dockingCorridorIsEmpty]` (722) | `StationEntity::dockingCorridorIsEmpty` `Core/Entities/StationEntity.cpp:1586` | ✅ |
| `-[StationEntity clearDockingCorridor]` (737) | `StationEntity::clearDockingCorridor` `Core/Entities/StationEntity.cpp:1600` | ✅ |
| `-[StationEntity update:]` (751) | `StationEntity::update` `Core/Entities/StationEntity.cpp:1614` | ✅ |
| `-[StationEntity clear]` (853) | `StationEntity::clear` `Core/Entities/StationEntity.cpp:1718` | ✅ |
| `-[StationEntity hasMultipleDocks]` (864) | `StationEntity::hasMultipleDocks` `Core/Entities/StationEntity.cpp:1729` | ✅ |
| `-[StationEntity hasClearDock]` (880) | `StationEntity::hasClearDock` `Core/Entities/StationEntity.cpp:1736` | ✅ |
| `-[StationEntity hasEligibleDock]` (894) | `StationEntity::hasEligibleDock` `Core/Entities/StationEntity.cpp:1749` | ✅ |
| `-[StationEntity hasLaunchDock]` (908) | `StationEntity::hasLaunchDock` `Core/Entities/StationEntity.cpp:1762` | ✅ |
| `-[StationEntity selectDockForDocking]` (921) | `StationEntity::selectDockForDocking` `Core/Entities/StationEntity.cpp:1774` | ✅ |
| `-[StationEntity addShipToLaunchQueue:withPriority:]` (933) | `StationEntity::addShipToLaunchQueue` `Core/Entities/StationEntity.cpp:1785` | ✅ |
| `-[StationEntity countOfShipsInLaunchQueueWithPrimaryRole:]` (984) | `StationEntity::countOfShipsInLaunchQueueWithPrimaryRole` `Core/Entities/StationEntity.cpp:1838` | ✅ |
| `-[StationEntity fitsInDock:]` (995) | `StationEntity::fitsInDock(ship)` `Core/Entities/StationEntity.cpp:1848` | ✅ |
| `-[StationEntity fitsInDock:andLogNoFit:]` (1000) | `StationEntity::fitsInDock(ship, logNoFit)` `Core/Entities/StationEntity.cpp:1853` | ✅ |
| `-[StationEntity noteDockedShip:]` (1019) | `StationEntity::noteDockedShip` `Core/Entities/StationEntity.cpp:1872` | ✅ |
| `-[StationEntity addShipToStationCount:]` (1065) | `StationEntity::addShipToStationCount` `Core/Entities/StationEntity.cpp:1911` | ✅ |
| `-[StationEntity interstellarUndockingAllowed]` (1081) | `StationEntity::getInterstellarUndockingAllowed` `Core/Entities/StationEntity.cpp:1081` | ✅ |
| `-[StationEntity hasNPCTraffic]` (1086) | `StationEntity::getHasNPCTraffic` `Core/Entities/StationEntity.cpp:1086` | ✅ |
| `-[StationEntity setHasNPCTraffic:]` (1091) | `StationEntity::setHasNPCTraffic` `Core/Entities/StationEntity.cpp:1091` | ✅ |
| `-[StationEntity collideWithShip:]` (1096) | `StationEntity::collideWithShip` `Core/Entities/StationEntity.cpp:1930` | ✅ |
| `-[StationEntity hasHostileTarget]` (1108) | `StationEntity::hasHostileTarget` `Core/Entities/StationEntity.cpp:1942` | ✅ |
| `-[StationEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (1113) | `StationEntity::takeEnergyDamage` `Core/Entities/StationEntity.cpp:1947` | ✅ |
| `-[StationEntity adjustVelocity:]` (1156) | `StationEntity::adjustVelocity` `Core/Entities/StationEntity.cpp:1993` | ✅ |
| `-[StationEntity takeScrapeDamage:from:]` (1162) | `StationEntity::takeScrapeDamage` `Core/Entities/StationEntity.cpp:1999` | ✅ |
| `-[StationEntity takeHeatDamage:]` (1169) | `StationEntity::takeHeatDamage` `Core/Entities/StationEntity.cpp:2006` | ✅ |
| `-[StationEntity allegiance]` (1176) | `StationEntity::getAllegiance` `Core/Entities/StationEntity.cpp:2013` | ✅ |
| `-[StationEntity setAllegiance:]` (1181) | `StationEntity::setAllegiance` `Core/Entities/StationEntity.cpp:2018` | ✅ |
| `-[StationEntity alertLevel]` (1187) | `StationEntity::getAlertLevel` `Core/Entities/StationEntity.cpp:2023` | ✅ |
| `-[StationEntity setAlertLevel:signallingScript:]` (1192) | `StationEntity::setAlertLevel` `Core/Entities/StationEntity.cpp:2028` | ✅ |
| `-[StationEntity launchIndependentShip:]` (1222) | `StationEntity::launchIndependentShip` `Core/Entities/StationEntity.cpp:97` (returns an Object node) | ⚠️ |
| `-[StationEntity increaseAlertLevel]` (1297) | `StationEntity::increaseAlertLevel` `Core/Entities/StationEntity.cpp:2064` | ✅ |
| `-[StationEntity decreaseAlertLevel]` (1303) | `StationEntity::decreaseAlertLevel` `Core/Entities/StationEntity.cpp:2070` | ✅ |
| `-[StationEntity launchPolice]` (1309) | `StationEntity::launchPolice` `Core/Entities/StationEntity.cpp:191` (returns Object nodes) | ⚠️ |
| `-[StationEntity launchDefenseShip]` (1366) | `StationEntity::launchDefenseShip` `Core/Entities/StationEntity.cpp:257` | ✅ |
| `-[StationEntity launchScavenger]` (1461) | `StationEntity::launchScavenger` `Core/Entities/StationEntity.cpp:368` | ✅ |
| `-[StationEntity launchMiner]` (1503) | `StationEntity::launchMiner` `Core/Entities/StationEntity.cpp:418` | ✅ |
| `-[StationEntity launchPirateShip]` (1549) | `StationEntity::launchPirateShip` `Core/Entities/StationEntity.cpp:472` | ✅ |
| `-[StationEntity launchShuttle]` (1603) | `StationEntity::launchShuttle` `Core/Entities/StationEntity.cpp:537` | ✅ |
| `-[StationEntity launchEscort]` (1636) | `StationEntity::launchEscort` `Core/Entities/StationEntity.cpp:576` | ✅ |
| `-[StationEntity launchPatrol]` (1662) | `StationEntity::launchPatrol` `Core/Entities/StationEntity.cpp:607` | ✅ |
| `-[StationEntity launchShipWithRole:]` (1712) | `StationEntity::launchShipWithRole` `Core/Entities/StationEntity.cpp:667` | ✅ |
| `-[StationEntity becomeExplosion]` (1734) | `StationEntity::becomeExplosion` `Core/Entities/StationEntity.cpp:2076` | ✅ |
| `-[StationEntity becomeEnergyBlast]` (1761) | `StationEntity::becomeEnergyBlast` `Core/Entities/StationEntity.cpp:2107` | ✅ |
| `-[StationEntity becomeLargeExplosion:]` (1768) | `StationEntity::becomeLargeExplosion` `Core/Entities/StationEntity.cpp:2114` | ✅ |
| `-[StationEntity acceptPatrolReportFrom:]` (1775) | `StationEntity::acceptPatrolReportFrom` `Core/Entities/StationEntity.cpp:2121` | ✅ |
| `-[StationEntity acceptDockingClearanceRequestFrom:]` (1782) | `StationEntity::acceptDockingClearanceRequestFrom` `Core/Entities/StationEntity.cpp:2128` | ✅ |
| `-[StationEntity currentlyInDockingQueues]` (1974) | `StationEntity::currentlyInDockingQueues` `Core/Entities/StationEntity.cpp:2319` | ✅ |
| `-[StationEntity currentlyInLaunchingQueues]` (1986) | `StationEntity::currentlyInLaunchingQueues` `Core/Entities/StationEntity.cpp:2330` | ✅ |
| `-[StationEntity requiresDockingClearance]` (1997) | `StationEntity::getRequiresDockingClearance` `Core/Entities/StationEntity.cpp:1096` | ✅ |
| `-[StationEntity setRequiresDockingClearance:]` (2002) | `StationEntity::setRequiresDockingClearance` `Core/Entities/StationEntity.cpp:1101` | ✅ |
| `-[StationEntity allowsFastDocking]` (2007) | `StationEntity::getAllowsFastDocking` `Core/Entities/StationEntity.cpp:1106` | ✅ |
| `-[StationEntity setAllowsFastDocking:]` (2012) | `StationEntity::setAllowsFastDocking` `Core/Entities/StationEntity.cpp:1111` | ✅ |
| `-[StationEntity allowsAutoDocking]` (2017) | `StationEntity::getAllowsAutoDocking` `Core/Entities/StationEntity.cpp:1116` | ✅ |
| `-[StationEntity setAllowsAutoDocking:]` (2022) | `StationEntity::setAllowsAutoDocking` `Core/Entities/StationEntity.cpp:1121` | ✅ |
| `-[StationEntity allowsSaving]` (2027) | `StationEntity::getAllowsSaving` `Core/Entities/StationEntity.cpp:1126` | ✅ |
| `-[StationEntity isRotatingStation]` (2033) | `StationEntity::isRotatingStation` `Core/Entities/StationEntity.cpp:1132` | ✅ |
| `-[StationEntity marketOverrideName]` (2040) | `StationEntity::marketOverrideName` `Core/Entities/StationEntity.cpp:1144` | ✅ |
| `-[StationEntity hasShipyard]` (2050) | `StationEntity::hasShipyard` `Core/Entities/StationEntity.cpp:1154` | ✅ |
| `-[StationEntity generateShipyard]` (2071) | `StationEntity::generateShipyard()` `Core/Entities/StationEntity.cpp:1175` | ✅ |
| `-[StationEntity generateShipyard:]` (2076) | `StationEntity::generateShipyard(OOTechLevelID)` `Core/Entities/StationEntity.cpp:1180` | ✅ |
| `-[StationEntity suppressArrivalReports]` (2095) | `StationEntity::suppressArrivalReports` `Core/Entities/StationEntity.cpp:1202` | ✅ |
| `-[StationEntity setSuppressArrivalReports:]` (2100) | `StationEntity::setSuppressArrivalReports` `Core/Entities/StationEntity.cpp:1207` | ✅ |
| `-[StationEntity hasBreakPattern]` (2105) | `StationEntity::getHasBreakPattern` `Core/Entities/StationEntity.cpp:1212` | ✅ |
| `-[StationEntity setHasBreakPattern:]` (2110) | `StationEntity::setHasBreakPattern` `Core/Entities/StationEntity.cpp:1217` | ✅ |
| `-[StationEntity descriptionComponents]` (2115) | `StationEntity::descriptionComponents` `Core/Entities/StationEntity.cpp:1222` | ✅ |
| `-[StationEntity dumpSelfState]` (2120) | `StationEntity::dumpSelfState` `Core/Entities/StationEntity.cpp:1227` | ✅ |

Checked against the emphasis points:
- Docking queue: the dock pick chooses the fewest enqueued below a queue cap of 100, uses `willOpenDockingPortFor` for DOCK_CLOSED, and has the `alldockstoosmall`/TRY_AGAIN_LATER fallback. Hold is triggered by `|v|² > 1`, pitch or yaw `> 0.01`, or roll `> 0.01` with an off-centre dock. The fugitive-player refusal is at `legalStatus > 50`.
- Launch scheduling: there are two threshold passes up to 16, the first skipping `player_reserved_dock` and docks with inbound ships. The shuttle interval is 900 s, with `ranrot & 3` docked and last-launch offset `(ranrot & 63) * 15`. Traders are `3 + (ranrot & 7)`, interval `3600/n`, first launch in 60 s. Patrol is 300 s.
- Defence launch counts: police use `i < 4 && defenders_launched < max_police`, with the interceptor test `(Ranrot & 3) + 9 < TL`. Defence ships and patrol use `(Ranrot & 7) + 6 <= TL`, TL 6 when NSNotFound. Pirates get bounty `10 + floor(randf*20)`. Defaults are max_scavengers/max_defense_ships 3, max_police STATION_MAX_POLICE, and `equipment_price_factor` clamped to ≥ 0.5.
- Fuzzy booleans: `has_npc_traffic`, `has_patrol_ships` and `has_shipyard` still draw `randf()` through `OOFuzzyBooleanFromPList`. The market comes from `generateMarketForStation`. The shipyard comes from `shipsForSaleForSystem:withTL:atTime:`, and bought IDs are removed.
- Alert levels: the clamp is GREEN..RED, then `alertConditionChanged(new, old)`, then the GREEN/YELLOW/RED_ALERT AI message. Main-station retaliation is bounty 64, or 96 for a cascade, ×1.5 if the bounty is already at least that.

All of these match the upstream lines.

**Differences:**

- ❌ **low** — `_shipsOnHold` is an insertion-ordered `oo::WeakSet` (vector + index). Upstream `OOWeakSet` enumerated in `NSMutableSet` hash order. So the order of `DOCKING_ABORTED`/`stationWithdrewDockingClearance` in abortAllDockings, the order of `enterDock:` in autoDockShipsOnHold, and the dumpSelfState listing can differ — upstream `Core/Entities/StationEntity.m:320-325,345-349,2175` ↔ port `Core/Entities/StationEntity.cpp:1360-1368,1391-1394,1288`
- ⚠️ **low** — `launchIndependentShip` and `launchPolice` return `oo::PList` Object node(s), not `ShipEntity*`/`NSArray`. The comment cites the "called by name (ADR-0055 item 5)" interface. The selection and side effects are the same — upstream `Core/Entities/StationEntity.m:1222,1309` ↔ port `Core/Entities/StationEntity.cpp:97,191`
- ➖ **low** — `dockSubEntityEnumerator` is replaced by `dockSubEntities()`, a snapshot of held subentity refs filtered by `isDock`. Every former enumerator loop iterates that snapshot, so a dock removed or added during a loop is still or not yet visited — upstream `Core/Entities/StationEntity.m:260` ↔ port `Core/Entities/StationEntity.cpp:930`
- ✅ subtle — In launchShip, upstream's "just use the last one" fallback is dead code: the exhausted enumerator left `sub` nil. The port keeps it dead on purpose (comment), so a station with no launching dock does not launch the player here in either version — upstream `Core/Entities/StationEntity.m:303-307` ↔ port `Core/Entities/StationEntity.cpp:1339-1346`
- ✅ subtle — In launchDefenseShip, upstream retried `default_defense_ship_role` by pointer comparison, that is, only when shipdata supplied `defense_ship_role`. The port turns this into the `shipdataSuppliedRole` flag. The extra `newShipWithRole` call (and its RNG draws) happens in the same cases — upstream `Core/Entities/StationEntity.m:1406-1412` ↔ port `Core/Entities/StationEntity.cpp:299-307`
- ✅ subtle — launchEscort and launchShipWithRole still release the new ship before returning it. launchEscort returns a dangling pointer when the ship did not fit. This is the same latent bug as upstream — upstream `Core/Entities/StationEntity.m:1657` ↔ port `Core/Entities/StationEntity.cpp:601-603`
- ✅ subtle — legalStatusOfManifest dereferences `getLocalMarket()` without a null check. Upstream messaged nil and got status 0. This is only reachable if the main station runs while `UNIVERSE commodityMarket` is nil — upstream `Core/Entities/StationEntity.m:153-163` ↔ port `Core/Entities/StationEntity.cpp:819-820`
- ✅ subtle — getPlanet does a `dynamic_cast<OOPlanetEntity*>`, so a reused UID that now names a non-planet gives null. Upstream returned that entity under a planet type — upstream `Core/Entities/StationEntity.m:242` ↔ port `Core/Entities/StationEntity.cpp:912`
- ✅ subtle — For a `roles` value that is not a string, isRotatingStation returns NO. Upstream raised an unrecognised selector. An absent `roles` still gives YES (nil range location 0) — upstream `Core/Entities/StationEntity.m:2037` ↔ port `Core/Entities/StationEntity.cpp:1136-1141`

