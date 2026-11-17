# Parity findings: entities-ship
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## DockEntity

<a id="dockentity"></a>
Upstream `src/Core/Entities/DockEntity.m` ↔ `Core/Entities/DockEntity.cpp` (1176 / 1434 lines)

**Status:** done — 42 rows: 40 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[DockEntity pruneAndCountShipsOnApproach]` (60) | `pruneAndCountShipsOnApproach` Core/Entities/DockEntity.cpp:307 (approach queue walked in `std::map` key order) | ❌ |
| `-[DockEntity abortAllDockings]` (89) | `abortAllDockings` Core/Entities/DockEntity.cpp:339 (same map-order walk; 1500 m / 10 s branches same) | ✅ |
| `-[DockEntity abortAllLaunches]` (129) | `abortAllLaunches` Core/Entities/DockEntity.cpp:925 | ✅ |
| `-[DockEntity autoDockShipsInQueue:]` (135) | `autoDockShipsInQueue` Core/Entities/DockEntity.cpp:402 (same map-order walk) | ✅ |
| `-[DockEntity autoDockShipsOnApproach]` (148) | `autoDockShipsOnApproach` Core/Entities/DockEntity.cpp:415 | ✅ |
| `-[DockEntity allowsDocking]` (153) | `allowsDocking` Core/Entities/DockEntity.cpp:114 | ✅ |
| `-[DockEntity setAllowsDocking:]` (158) | `setAllowsDocking` Core/Entities/DockEntity.cpp:116 | ✅ |
| `-[DockEntity disallowedDockingCollides]` (166) | `disallowedDockingCollides` Core/Entities/DockEntity.cpp:123 | ✅ |
| `-[DockEntity allowsLaunching]` (171) | `allowsLaunching` Core/Entities/DockEntity.cpp:127 | ✅ |
| `-[DockEntity setAllowsLaunching:]` (176) | `setAllowsLaunching` Core/Entities/DockEntity.cpp:129 | ✅ |
| `-[DockEntity setDisallowedDockingCollides:]` (184) | `setDisallowedDockingCollides` Core/Entities/DockEntity.cpp:136 | ✅ |
| `-[DockEntity setVirtual]` (189) | `setVirtual` Core/Entities/DockEntity.cpp:140 | ✅ |
| `-[DockEntity canAcceptShipForDocking:]` (194) | `canAcceptShipForDocking` Core/Entities/DockEntity.cpp:419 | ✅ |
| `-[DockEntity isOffCentre]` (237) | `isOffCentre` Core/Entities/DockEntity.cpp:142 | ✅ |
| `-[DockEntity dockingInstructionsForShip:]` (249) | `dockingInstructionsForShip` Core/Entities/DockEntity.cpp:467 (error logs print plist text) | ⚠️ |
| `-[DockEntity addShipToShipsOnApproach:]` (403) | `addShipToShipsOnApproach` Core/Entities/DockEntity.cpp:683 | ✅ |
| `-[DockEntity noteDockingForShip:]` (525) | `noteDockingForShip` Core/Entities/DockEntity.cpp:835 | ✅ |
| `-[DockEntity abortDockingForShip:]` (534) | `abortDockingForShip` Core/Entities/DockEntity.cpp:843 | ✅ |
| `-[DockEntity portUpVectorForShipsBoundingBox:]` (563) | `portUpVectorForShipsBoundingBox` Core/Entities/DockEntity.cpp:153 | ✅ |
| `-[DockEntity shipIsInDockingQueue:]` (574) | `shipIsInDockingQueue` Core/Entities/DockEntity.cpp:889 | ✅ |
| `-[DockEntity countOfShipsInDockingQueue]` (594) | `countOfShipsInDockingQueue` Core/Entities/DockEntity.cpp:170 | ✅ |
| `-[DockEntity countOfShipsInLaunchQueue]` (599) | `countOfShipsInLaunchQueue` Core/Entities/DockEntity.cpp:174 | ✅ |
| `-[DockEntity shipIsInDockingCorridor:]` (604) | `shipIsInDockingCorridor` Core/Entities/DockEntity.cpp:930 | ✅ |
| `-[DockEntity pullInShipIfPermitted:]` (776) | `pullInShipIfPermitted` Core/Entities/DockEntity.cpp:914 | ✅ |
| `-[DockEntity addShipToLaunchQueue:withPriority:]` (785) | `addShipToLaunchQueue` Core/Entities/DockEntity.cpp:1142 | ✅ |
| `-[DockEntity launchShip:]` (804) | `launchShip` Core/Entities/DockEntity.cpp:1155 | ✅ |
| `-[DockEntity countOfShipsInLaunchQueueWithPrimaryRole:]` (857) | `countOfShipsInLaunchQueueWithPrimaryRole` Core/Entities/DockEntity.cpp:1230 | ✅ |
| `-[DockEntity allowsLaunchingOf:]` (868) | `allowsLaunchingOf` Core/Entities/DockEntity.cpp:1242 | ✅ |
| `-[DockEntity clear]` (900) | `clear` Core/Entities/DockEntity.cpp:178 | ✅ |
| `-[DockEntity dockingCorridorIsEmpty]` (906) | `dockingCorridorIsEmpty` Core/Entities/DockEntity.cpp:1278 | ✅ |
| `-[DockEntity clearDockingCorridor]` (972) | `clearDockingCorridor` Core/Entities/DockEntity.cpp:1360 | ✅ |
| `-[DockEntity setDimensionsAndCorridor:ddc:launching:]` (1038) | `setDimensionsAndCorridor` Core/Entities/DockEntity.cpp:183 | ✅ |
| `-[DockEntity isDock]` (1064) | `isDock` Core/Entities/DockEntity.cpp:215 | ✅ |
| `-[DockEntity initWithKey:definition:]` (1069) | `newDockObject` + `initDockDefaults` Core/Entities/DockEntity.cpp:91,101 (containers are members) | ✅ |
| `-[DockEntity dealloc]` (1088) | `willDealloc` Core/Entities/DockEntity.cpp:112 (+ member destructors) | ✅ |
| `-[DockEntity clearIdLocks:]` (1097) | `clearIdLocks` Core/Entities/DockEntity.cpp:228 | ✅ |
| `-[DockEntity clearAllIdLocks]` (1107) | `clearAllIdLocks` Core/Entities/DockEntity.cpp:237 | ✅ |
| `-[DockEntity setUpShipFromDictionary:]` (1115) | `setUpShipFromDictionary` Core/Entities/DockEntity.cpp:244 | ✅ |
| `-[DockEntity update:]` (1130) | `update` Core/Entities/DockEntity.cpp:257 | ✅ |
| `-[DockEntity noteTakingDamage:from:type:]` (1148) | `noteTakingDamage` Core/Entities/DockEntity.cpp:278 | ✅ |
| `-[DockEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (1157) | `takeEnergyDamage` Core/Entities/DockEntity.cpp:287 | ✅ |
| `-[DockEntity drawImmediate:translucent:]` (1167) | `drawImmediate` Core/Entities/DockEntity.cpp:297 | ✅ |

**Differences:**

- ❌ **low** — (still open) The approach queue is a `std::map<unsigned short, …>` walked in ascending ship-ID order (`ShipIDsIn`); upstream walked `NSMutableDictionary -allKeys` in hash order. The order in which `DOCKING_ABORTED`/`stationWithdrewDockingClearance` go out (prune, abortAllDockings) and `enterDock:` runs (autoDockShipsInQueue) can differ — upstream `Core/Entities/DockEntity.m:65,96,138` ↔ port `Core/Entities/DockEntity.cpp:310,344,404`
- ⚠️ **low** — (still open) The `station.issueDockingInstructions.failed` error logs print the queue/stack as old-style plist text, not GNUstep `-description`; the port comment says the exact `-description` is not kept (the ADR citation was dropped from the comment) — upstream `Core/Entities/DockEntity.m:297,307` ↔ port `Core/Entities/DockEntity.cpp:58-65,543-565`
- ✅ subtle — addShipToShipsOnApproach drops upstream's dead store `corridor_length += port_corridor` (after its last read); the port comment says so — upstream `Core/Entities/DockEntity.m:490-491` ↔ port `Core/Entities/DockEntity.cpp:793-796`
- ✅ subtle — dockingInstructionsForShip copies `coordinatesStack[1]` before sending the comms message and re-finds the stack before erasing / setting `hold_message_given`, so a script that removes the entry mid-call makes the port skip the edit; returned instructions are the same — upstream `Core/Entities/DockEntity.m:343-398` ↔ port `Core/Entities/DockEntity.cpp:611-677`
- ✅ subtle — update guards `launchQueue.erase` when `launchShip` emptied the queue (upstream `-removeObjectAtIndex:0` would raise) — upstream `Core/Entities/DockEntity.m:1140` ↔ port `Core/Entities/DockEntity.cpp:267-270`
- ✅ subtle — prune/abort/autoDock resolve IDs with `oo::ToShip`, so a UID now owned by a non-ship is treated as gone; upstream would message it as a ship. dockingCorridorIsEmpty/clearDockingCorridor skip non-`ShipEntity` objects with `isShip` set, where upstream cast blindly — port `Core/Entities/DockEntity.cpp:311,1317,1380`

## ShipEntity

<a id="shipentity"></a>
Upstream `src/Core/Entities/ShipEntity.m` ↔ `Core/Entities/ShipEntity.cpp` (13049 / 14079 lines)

**Status:** done — 646 rows: 623 ✅ 6 ⚠️ 10 ❌ 7 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `calcFuelChargeRate` (104) | `calcFuelChargeRate` (static) Core/Entities/ShipEntity.cpp:105 | ✅ |
| `-[ShipEntity init]` (174) | — (no default-constructed ship; ships are made only through `oo::NewShipObject` Core/Entities/ShipEntity.cpp:304) | ➖ |
| `-[ShipEntity initBypassForPlayer]` (184) | — (`PlayerEntity::newPlayerObject` Core/Entities/PlayerEntity.cpp:446 makes the player; `deferredInit` runs `initShipSetUp`) | ➖ |
| `-[ShipEntity initWithKey:definition:]` (190) | `oo::NewShipObject` + `initShipSetUp` + `initWithKey` Core/Entities/ShipEntity.cpp:304,314,385 | ✅ |
| `-[ShipEntity setUpFromDictionary:]` (235) | `setUpFromDictionary` Core/Entities/ShipEntity.cpp:598 | ✅ |
| `-[ShipEntity setUpShipFromDictionary:]` (500) | `setUpShipFromDictionary` Core/Entities/ShipEntity.cpp:901 | ✅ |
| `-[ShipEntity setSubIdx:]` (724) | `setSubIdx` Core/Entities/ShipEntity.cpp:1169 | ✅ |
| `-[ShipEntity subIdx]` (729) | `subIdx` Core/Entities/ShipEntity.cpp:1171 | ✅ |
| `-[ShipEntity maxShipSubEntities]` (734) | `maxShipSubEntities` Core/Entities/ShipEntity.cpp:1173 | ✅ |
| `-[ShipEntity repeatString:times:]` (739) | `RepeatString` (anonymous namespace) Core/Entities/ShipEntity.cpp:190 | ✅ |
| `-[ShipEntity serializeShipSubEntities]` (753) | `serializeShipSubEntities` Core/Entities/ShipEntity.cpp:1175 | ✅ |
| `-[ShipEntity deserializeShipSubEntitiesFrom:]` (771) | `deserializeShipSubEntitiesFrom` Core/Entities/ShipEntity.cpp:1191 (UTF-16 indexing, as `-substringWithRange:`) | ✅ |
| `-[ShipEntity setUpSubEntities]` (790) | `setUpSubEntities` Core/Entities/ShipEntity.cpp:1215 | ✅ |
| `-[ShipEntity frustumRadius]` (822) | `frustumRadius` Core/Entities/ShipEntity.cpp:1255 | ✅ |
| `-[ShipEntity setUpOneSubentity:]` (835) | `setUpOneSubentity` Core/Entities/ShipEntity.cpp:1269 | ✅ |
| `-[ShipEntity setUpOneFlasher:]` (851) | `setUpOneFlasher` Core/Entities/ShipEntity.cpp:1282 | ✅ |
| `-[ShipEntity setUpOneStandardSubentity:asTurret:]` (860) | `setUpOneStandardSubentity` Core/Entities/ShipEntity.cpp:1298 | ✅ |
| `-[ShipEntity isTemplateCargoPod]` (932) | `isTemplateCargoPod` Core/Entities/ShipEntity.cpp:1400 | ✅ |
| `-[ShipEntity setUpCargoType:]` (937) | `setUpCargoType` Core/Entities/ShipEntity.cpp:1404 | ✅ |
| `-[ShipEntity dealloc]` (986) | `shipWillDealloc` Core/Entities/ShipEntity.cpp:335 (+ member destructors) | ✅ |
| `-[ShipEntity removeScript]` (1060) | `removeScript` Core/Entities/ShipEntity.cpp:1450 | ✅ |
| `-[ShipEntity clearSubEntities]` (1066) | `clearSubEntities` Core/Entities/ShipEntity.cpp:1455 (last to first) | ✅ |
| `-[ShipEntity subEntityRotationalVelocity]` (1080) | `subEntityRotationalVelocity` Core/Entities/ShipEntity.cpp:1469 | ✅ |
| `-[ShipEntity setSubEntityRotationalVelocity:]` (1085) | `setSubEntityRotationalVelocity` Core/Entities/ShipEntity.cpp:1473 | ✅ |
| `-[ShipEntity descriptionComponents]` (1090) | `descriptionComponents` Core/Entities/ShipEntity.cpp:1628 | ✅ |
| `-[ShipEntity shortDescriptionComponents]` (1106) | `shortDescriptionComponents` Core/Entities/ShipEntity.cpp:1477 | ✅ |
| `-[ShipEntity sunGlareFilter]` (1111) | `getSunGlareFilter` Core/Entities/ShipEntity.cpp:1481 | ✅ |
| `-[ShipEntity setSunGlareFilter:]` (1116) | `setSunGlareFilter` Core/Entities/ShipEntity.cpp:1483 | ✅ |
| `-[ShipEntity accuracy]` (1121) | `getAccuracy` Core/Entities/ShipEntity.cpp:1487 | ✅ |
| `-[ShipEntity setAccuracy:]` (1126) | `setAccuracy` Core/Entities/ShipEntity.cpp:1489 | ✅ |
| `-[ShipEntity mesh]` (1145) | `mesh` Core/Entities/ShipEntity.cpp:1508 | ✅ |
| `-[ShipEntity setMesh:]` (1150) | `setMesh` Core/Entities/ShipEntity.cpp:1513 | ✅ |
| `-[ShipEntity totalBoundingBox]` (1159) | `getTotalBoundingBox` Core/Entities/ShipEntity.cpp:1520 | ✅ |
| `-[ShipEntity forwardVector]` (1164) | `forwardVector` Core/Entities/ShipEntity.cpp:1522 | ✅ |
| `-[ShipEntity upVector]` (1169) | `upVector` Core/Entities/ShipEntity.cpp:1524 | ✅ |
| `-[ShipEntity rightVector]` (1174) | `rightVector` Core/Entities/ShipEntity.cpp:1526 | ✅ |
| `-[ShipEntity scriptedMisjump]` (1179) | `scriptedMisjump` Core/Entities/ShipEntity.cpp:1528 | ✅ |
| `-[ShipEntity setScriptedMisjump:]` (1184) | `setScriptedMisjump` Core/Entities/ShipEntity.cpp:1530 | ✅ |
| `-[ShipEntity scriptedMisjumpRange]` (1189) | `scriptedMisjumpRange` Core/Entities/ShipEntity.cpp:1534 | ✅ |
| `-[ShipEntity setScriptedMisjumpRange:]` (1194) | `setScriptedMisjumpRange` Core/Entities/ShipEntity.cpp:1536 | ✅ |
| `-[ShipEntity subEntities]` (1199) | `getSubEntities` Core/Entities/ShipEntity.cpp:1540 (copy) | ✅ |
| `-[ShipEntity subEntityCount]` (1204) | `subEntityCount` Core/Entities/ShipEntity.cpp:1542 | ✅ |
| `-[ShipEntity hasSubEntity:]` (1209) | `hasSubEntity` Core/Entities/ShipEntity.cpp:1544 (identity) | ✅ |
| `-[ShipEntity subEntityEnumerator]` (1214) | `subEntityEnumerator` Core/Entities/ShipEntity.cpp:1550 (snapshot) | ✅ |
| `-[ShipEntity shipSubEntityEnumerator]` (1219) | `shipSubEntities` Core/Entities/ShipEntity.cpp:1554 | ✅ |
| `-[ShipEntity flasherEnumerator]` (1224) | `flasherEnumerator` Core/Entities/ShipEntity.cpp:1562 | ✅ |
| `-[ShipEntity exhaustEnumerator]` (1229) | `exhausts` Core/Entities/ShipEntity.cpp:1571 | ✅ |
| `-[ShipEntity subEntityTakingDamage]` (1234) | `subEntityTakingDamage` Core/Entities/ShipEntity.cpp:1580 | ✅ |
| `-[ShipEntity setSubEntityTakingDamage:]` (1252) | `setSubEntityTakingDamage` Core/Entities/ShipEntity.cpp:1597 | ✅ |
| `-[ShipEntity shipScript]` (1271) | `shipScript` Core/Entities/ShipEntity.cpp:1620 | ✅ |
| `-[ShipEntity shipAIScript]` (1276) | `shipAIScript` Core/Entities/ShipEntity.cpp:1622 | ✅ |
| `-[ShipEntity shipAIScriptWakeTime]` (1281) | `shipAIScriptWakeTime` Core/Entities/ShipEntity.cpp:1624 | ✅ |
| `-[ShipEntity setAIScriptWakeTime:]` (1286) | `setAIScriptWakeTime` Core/Entities/ShipEntity.cpp:1626 | ✅ |
| `-[ShipEntity findBoundingBoxRelativeToPosition:i:j:k:]` (1291) | `findBoundingBoxRelativeToPosition` Core/Entities/ShipEntity.cpp:1651 (nil mesh → zero box) | ✅ |
| `-[ShipEntity octree]` (1304) | `getOctree` Core/Entities/ShipEntity.cpp:1662 | ✅ |
| `-[ShipEntity volume]` (1309) | `volume` Core/Entities/ShipEntity.cpp:1664 | ✅ |
| `-[ShipEntity doesHitLine:v1:]` (1314) | `doesHitLine(v0, v1)` Core/Entities/ShipEntity.cpp:1666 | ✅ |
| `-[ShipEntity doesHitLine:v1:hitEntity:]` (1323) | `doesHitLine(v0, v1, hitEntity)` Core/Entities/ShipEntity.cpp:1677 | ✅ |
| `-[ShipEntity doesHitLine:v1:withPosition:i:j:k:]` (1359) | `doesHitLine(v0, v1, o, i, j, k)` Core/Entities/ShipEntity.cpp:1715 (upstream `u1·j` slip kept) | ✅ |
| `-[ShipEntity wasAddedToUniverse]` (1368) | `wasAddedToUniverse` Core/Entities/ShipEntity.cpp:1727 | ✅ |
| `-[ShipEntity wasRemovedFromUniverse]` (1395) | `wasRemovedFromUniverse` Core/Entities/ShipEntity.cpp:1759 | ✅ |
| `-[ShipEntity absoluteTractorPosition]` (1400) | `absoluteTractorPosition` Core/Entities/ShipEntity.cpp:1767 | ✅ |
| `-[ShipEntity beaconCode]` (1405) | `beaconCode` Core/Entities/ShipEntity.cpp:1772 | ✅ |
| `-[ShipEntity setBeaconCode:]` (1410) | `setBeaconCode` Core/Entities/ShipEntity.cpp:1777 | ✅ |
| `-[ShipEntity beaconLabel]` (1427) | `beaconLabel` Core/Entities/ShipEntity.cpp:1793 | ✅ |
| `-[ShipEntity setBeaconLabel:]` (1432) | `setBeaconLabel` Core/Entities/ShipEntity.cpp:1795 | ✅ |
| `-[ShipEntity isVisible]` (1443) | `isVisible` Core/Entities/ShipEntity.cpp:1804 | ✅ |
| `-[ShipEntity isBeacon]` (1448) | `isBeacon` Core/Entities/ShipEntity.cpp:1806 | ✅ |
| `-[ShipEntity beaconDrawable]` (1453) | `beaconDrawable` Core/Entities/ShipEntity.cpp:1808 | ✅ |
| `-[ShipEntity prevBeacon]` (1476) | `prevBeacon` Core/Entities/ShipEntity.cpp:1837 | ✅ |
| `-[ShipEntity nextBeacon]` (1481) | `nextBeacon` Core/Entities/ShipEntity.cpp:1839 | ✅ |
| `-[ShipEntity setPrevBeacon:]` (1486) | `setPrevBeacon` Core/Entities/ShipEntity.cpp:1845 | ✅ |
| `-[ShipEntity setNextBeacon:]` (1494) | `setNextBeacon` Core/Entities/ShipEntity.cpp:1851 | ✅ |
| `-[ShipEntity setIsBoulder:]` (1504) | `setIsBoulder` Core/Entities/ShipEntity.cpp:1857 | ✅ |
| `-[ShipEntity isBoulder]` (1512) | `isBoulder` Core/Entities/ShipEntity.cpp:1864 | ✅ |
| `-[ShipEntity isMinable]` (1517) | `isMinable` Core/Entities/ShipEntity.cpp:1868 | ✅ |
| `-[ShipEntity countsAsKill]` (1527) | `countsAsKill` Core/Entities/ShipEntity.cpp:1877 | ✅ |
| `-[ShipEntity setUpEscorts]` (1532) | `setUpEscorts` Core/Entities/ShipEntity.cpp:1881 | ✅ |
| `-[ShipEntity setUpMixedEscorts]` (1619) | `setUpMixedEscorts` Core/Entities/ShipEntity.cpp:1986 | ✅ |
| `-[ShipEntity setUpOneEscort:inGroup:withRole:atPosition:andCount:]` (1684) | `setUpOneEscort` Core/Entities/ShipEntity.cpp:2140 (`escortRole &&` guard dropped, per comment) | ⚠️ |
| `-[ShipEntity shipDataKey]` (1774) | `shipDataKey` Core/Entities/ShipEntity.cpp:2270 | ✅ |
| `-[ShipEntity shipDataKeyAutoRole]` (1779) | `shipDataKeyAutoRole` Core/Entities/ShipEntity.cpp:2272 | ✅ |
| `-[ShipEntity setShipDataKey:]` (1784) | `setShipDataKey` Core/Entities/ShipEntity.cpp:2278 | ✅ |
| `-[ShipEntity shipInfoDictionary]` (1790) | `shipInfoDictionary` Core/Entities/ShipEntity.cpp:2282 | ✅ |
| `-[ShipEntity getWeaponOffsetFrom:withKey:inMode:]` (1797) | `weaponOffsetsFrom` Core/Entities/ShipEntity.cpp:2284 | ✅ |
| `-[ShipEntity aftWeaponOffset]` (1819) | `getAftWeaponOffset` Core/Entities/ShipEntity.cpp:2310 | ✅ |
| `-[ShipEntity forwardWeaponOffset]` (1824) | `getForwardWeaponOffset` Core/Entities/ShipEntity.cpp:2312 | ✅ |
| `-[ShipEntity portWeaponOffset]` (1829) | `getPortWeaponOffset` Core/Entities/ShipEntity.cpp:2316 | ✅ |
| `-[ShipEntity starboardWeaponOffset]` (1834) | `getStarboardWeaponOffset` Core/Entities/ShipEntity.cpp:2320 | ✅ |
| `-[ShipEntity isFrangible]` (1839) | `getIsFrangible` Core/Entities/ShipEntity.cpp:2324 | ✅ |
| `-[ShipEntity suppressFlightNotifications]` (1844) | `suppressFlightNotifications` Core/Entities/ShipEntity.cpp:2326 | ✅ |
| `-[ShipEntity scanClass]` (1849) | `getScanClass` Core/Entities/ShipEntity.cpp:2328 | ✅ |
| `-[ShipEntity canCollide]` (1858) | `canCollide` Core/Entities/ShipEntity.cpp:2335 | ✅ |
| `doOctreesCollide` (1878) | `doOctreesCollide` Core/Entities/ShipEntity.cpp:2069 (nil prime octree → no hit, as nil messaging) | ✅ |
| `-[ShipEntity checkCloseCollisionWith:]` (1944) | `checkCloseCollisionWith` Core/Entities/ShipEntity.cpp:2453 | ✅ |
| `-[ShipEntity findSubentityBoundingBox]` (2002) | `findSubentityBoundingBox` Core/Entities/ShipEntity.cpp:2356 | ✅ |
| `-[ShipEntity absoluteIJKForSubentity]` (2007) | `absoluteIJKForSubentity` Core/Entities/ShipEntity.cpp:2363 | ✅ |
| `-[ShipEntity addSubentityToCollisionRadius:]` (2028) | `addSubentityToCollisionRadius` Core/Entities/ShipEntity.cpp:2384 | ✅ |
| `-[ShipEntity launchPodWithCrew:]` (2047) | `launchPodWithCrew` Core/Entities/ShipEntity.cpp:2402 | ✅ |
| `-[ShipEntity validForAddToUniverse]` (2074) | `validForAddToUniverse` Core/Entities/ShipEntity.cpp:2443 | ✅ |
| `-[ShipEntity update:]` (2083) | `update` Core/Entities/ShipEntity.cpp:2522 (close-contact walk in `std::map` order, per comment) | ⚠️ |
| `-[ShipEntity processBehaviour:]` (2485) | `processBehaviour` Core/Entities/ShipEntity.cpp:3024 | ✅ |
| `-[ShipEntity noteFrustration:]` (2641) | `noteFrustration` Core/Entities/ShipEntity.cpp:3179 | ✅ |
| `-[ShipEntity respondToAttackFrom:becauseOf:]` (2647) | `respondToAttackFrom` Core/Entities/ShipEntity.cpp:3184 | ✅ |
| `-[ShipEntity hasOneEquipmentItem:includeWeapons:whileLoading:]` (2699) | `hasOneEquipmentItem(key, includeWeapons, loading)` Core/Entities/ShipEntity.cpp:3243 | ✅ |
| `-[ShipEntity hasOneEquipmentItem:includeMissiles:whileLoading:]` (2722) | `hasOneEquipmentItemIncludingMissiles` Core/Entities/ShipEntity.cpp:3265 | ✅ |
| `-[ShipEntity hasPrimaryWeapon:]` (2746) | `hasPrimaryWeapon` Core/Entities/ShipEntity.cpp:3290 (virtual; PlayerEntity overrides) | ✅ |
| `-[ShipEntity countEquipmentItem:]` (2766) | `countEquipmentItem` Core/Entities/ShipEntity.cpp:3322 | ✅ |
| `-[ShipEntity hasEquipmentItem:includeWeapons:whileLoading:]` (2778) | `hasEquipmentItem(keys, includeWeapons, loading)` Core/Entities/ShipEntity.cpp:3326 | ✅ |
| `-[ShipEntity hasEquipmentItem:]` (2796) | `hasEquipmentItem(keys)` Core/Entities/ShipEntity.cpp:3351 | ✅ |
| `-[ShipEntity hasEquipmentItemProviding:]` (2803) | `hasEquipmentItemProviding` Core/Entities/ShipEntity.cpp:3357 | ✅ |
| `-[ShipEntity equipmentItemProviding:]` (2820) | `equipmentItemProviding` Core/Entities/ShipEntity.cpp:3374 | ✅ |
| `-[ShipEntity hasAllEquipment:includeWeapons:whileLoading:]` (2837) | `hasAllEquipment(keys, includeWeapons, loading)` Core/Entities/ShipEntity.cpp:3392 | ❌ |
| `-[ShipEntity hasAllEquipment:]` (2859) | `hasAllEquipment(keys)` Core/Entities/ShipEntity.cpp:3420 | ✅ |
| `-[ShipEntity hasHyperspaceMotor]` (2864) | `hasHyperspaceMotor` Core/Entities/ShipEntity.cpp:3424 | ✅ |
| `-[ShipEntity hyperspaceSpinTime]` (2869) | `hyperspaceSpinTime` Core/Entities/ShipEntity.cpp:3426 | ✅ |
| `-[ShipEntity setHyperspaceSpinTime:]` (2874) | `setHyperspaceSpinTime` Core/Entities/ShipEntity.cpp:3428 | ✅ |
| `-[ShipEntity canAddEquipment:inContext:]` (2879) | `canAddEquipment` Core/Entities/ShipEntity.cpp:3435 | ✅ |
| `-[ShipEntity weaponFacings]` (2901) | `weaponFacings` Core/Entities/ShipEntity.cpp:3463 | ✅ |
| `-[ShipEntity weaponTypeIDForFacing:strict:]` (2906) | `weaponTypeIDForFacing` Core/Entities/ShipEntity.cpp:3465 | ✅ |
| `-[ShipEntity weaponTypeForFacing:strict:]` (2943) | `weaponTypeForFacing` Core/Entities/ShipEntity.cpp:3503 | ✅ |
| `-[ShipEntity missilesList]` (2950) | `missilesList` Core/Entities/ShipEntity.cpp:3511 | ✅ |
| `-[ShipEntity passengerListForScripting]` (2956) | `passengerListForScripting` Core/Entities/ShipEntity.cpp:3522 | ✅ |
| `-[ShipEntity parcelListForScripting]` (2961) | `parcelListForScripting` Core/Entities/ShipEntity.cpp:3526 | ✅ |
| `-[ShipEntity contractListForScripting]` (2966) | `contractListForScripting` Core/Entities/ShipEntity.cpp:3530 | ✅ |
| `-[ShipEntity generateMissileEquipmentTypeFrom:]` (2971) | `generateMissileEquipmentTypeFrom` Core/Entities/ShipEntity.cpp:3534 | ✅ |
| `-[ShipEntity equipmentListForScripting]` (2993) | `equipmentListForScripting` Core/Entities/ShipEntity.cpp:3558 | ✅ |
| `-[ShipEntity equipmentValidToAdd:inContext:]` (3028) | `equipmentValidToAdd(key, context)` Core/Entities/ShipEntity.cpp:3599 | ✅ |
| `-[ShipEntity equipmentValidToAdd:whileLoading:inContext:]` (3033) | `equipmentValidToAdd(key, loading, context)` Core/Entities/ShipEntity.cpp:3604 | ✅ |
| `-[ShipEntity setWeaponMount:toWeapon:]` (3137) | `setWeaponMount` Core/Entities/ShipEntity.cpp:3753 | ✅ |
| `-[ShipEntity addEquipmentItem:inContext:]` (3169) | `addEquipmentItem(key, context)` Core/Entities/ShipEntity.cpp:3786 | ✅ |
| `-[ShipEntity addEquipmentItem:withValidation:inContext:]` (3174) | `addEquipmentItem(key, validate, context)` Core/Entities/ShipEntity.cpp:3791 | ✅ |
| `-[ShipEntity equipmentEnumerator]` (3257) | `equipmentKeys` Core/Entities/ShipEntity.cpp:3879 | ✅ |
| `-[ShipEntity equipmentCount]` (3262) | `equipmentCount` Core/Entities/ShipEntity.cpp:3881 | ✅ |
| `-[ShipEntity removeEquipmentItem:]` (3267) | `removeEquipmentItem` Core/Entities/ShipEntity.cpp:3886 | ✅ |
| `-[ShipEntity removeExternalStore:]` (3337) | `removeExternalStore` Core/Entities/ShipEntity.cpp:3958 | ✅ |
| `-[ShipEntity verifiedMissileTypeFromRole:]` (3355) | `verifiedMissileTypeFromRole` Core/Entities/ShipEntity.cpp:3979 | ❌ |
| `-[ShipEntity selectMissile]` (3433) | `selectMissile` Core/Entities/ShipEntity.cpp:4091 | ✅ |
| `-[ShipEntity removeAllEquipment]` (3489) | `removeAllEquipment` Core/Entities/ShipEntity.cpp:4163 | ✅ |
| `-[ShipEntity removeMissiles]` (3495) | `removeMissiles` Core/Entities/ShipEntity.cpp:4165 | ✅ |
| `-[ShipEntity parcelCount]` (3501) | `parcelCount` Core/Entities/ShipEntity.cpp:4170 | ✅ |
| `-[ShipEntity passengerCount]` (3506) | `passengerCount` Core/Entities/ShipEntity.cpp:4172 | ✅ |
| `-[ShipEntity passengerCapacity]` (3511) | `passengerCapacity` Core/Entities/ShipEntity.cpp:4174 | ✅ |
| `-[ShipEntity missileCount]` (3516) | `missileCount` Core/Entities/ShipEntity.cpp:4176 | ✅ |
| `-[ShipEntity missileCapacity]` (3521) | `missileCapacity` Core/Entities/ShipEntity.cpp:4178 | ✅ |
| `-[ShipEntity extraCargo]` (3526) | `extraCargo` Core/Entities/ShipEntity.cpp:4180 | ✅ |
| `-[ShipEntity hasScoop]` (3532) | `hasScoop` Core/Entities/ShipEntity.cpp:4183 | ✅ |
| `-[ShipEntity hasFuelScoop]` (3537) | `hasFuelScoop` Core/Entities/ShipEntity.cpp:4188 | ✅ |
| `-[ShipEntity hasCargoScoop]` (3543) | `hasCargoScoop` Core/Entities/ShipEntity.cpp:4193 | ✅ |
| `-[ShipEntity hasECM]` (3548) | `hasECM` Core/Entities/ShipEntity.cpp:4197 | ✅ |
| `-[ShipEntity hasCloakingDevice]` (3553) | `hasCloakingDevice` Core/Entities/ShipEntity.cpp:4199 | ✅ |
| `-[ShipEntity hasMilitaryScannerFilter]` (3559) | `hasMilitaryScannerFilter` Core/Entities/ShipEntity.cpp:4204 | ✅ |
| `-[ShipEntity hasMilitaryJammer]` (3568) | `hasMilitaryJammer` Core/Entities/ShipEntity.cpp:4212 | ✅ |
| `-[ShipEntity hasExpandedCargoBay]` (3577) | `hasExpandedCargoBay` Core/Entities/ShipEntity.cpp:4220 | ✅ |
| `-[ShipEntity hasShieldBooster]` (3583) | `hasShieldBooster` Core/Entities/ShipEntity.cpp:4225 | ✅ |
| `-[ShipEntity hasMilitaryShieldEnhancer]` (3589) | `hasMilitaryShieldEnhancer` Core/Entities/ShipEntity.cpp:4230 | ✅ |
| `-[ShipEntity hasHeatShield]` (3595) | `hasHeatShield` Core/Entities/ShipEntity.cpp:4235 | ✅ |
| `-[ShipEntity hasFuelInjection]` (3600) | `hasFuelInjection` Core/Entities/ShipEntity.cpp:4239 | ✅ |
| `-[ShipEntity hasCascadeMine]` (3605) | `hasCascadeMine` Core/Entities/ShipEntity.cpp:4243 | ✅ |
| `-[ShipEntity hasEscapePod]` (3613) | `hasEscapePod` Core/Entities/ShipEntity.cpp:4250 | ✅ |
| `-[ShipEntity hasDockingComputer]` (3618) | `hasDockingComputer` Core/Entities/ShipEntity.cpp:4254 | ✅ |
| `-[ShipEntity hasGalacticHyperdrive]` (3623) | `hasGalacticHyperdrive` Core/Entities/ShipEntity.cpp:4258 | ✅ |
| `-[ShipEntity shieldBoostFactor]` (3628) | `shieldBoostFactor` Core/Entities/ShipEntity.cpp:4262 | ✅ |
| `-[ShipEntity maxForwardShieldLevel]` (3641) | `maxForwardShieldLevel` Core/Entities/ShipEntity.cpp:4272 | ✅ |
| `-[ShipEntity maxAftShieldLevel]` (3646) | `maxAftShieldLevel` Core/Entities/ShipEntity.cpp:4276 | ✅ |
| `-[ShipEntity shieldRechargeRate]` (3651) | `shieldRechargeRate` Core/Entities/ShipEntity.cpp:4280 | ✅ |
| `-[ShipEntity maxHyperspaceDistance]` (3656) | `maxHyperspaceDistance` Core/Entities/ShipEntity.cpp:4284 | ✅ |
| `-[ShipEntity afterburnerFactor]` (3661) | `afterburnerFactor` Core/Entities/ShipEntity.cpp:4289 | ✅ |
| `-[ShipEntity afterburnerRate]` (3666) | `afterburnerRate` Core/Entities/ShipEntity.cpp:4291 | ✅ |
| `-[ShipEntity setAfterburnerFactor:]` (3671) | `setAfterburnerFactor` Core/Entities/ShipEntity.cpp:4293 | ✅ |
| `-[ShipEntity setAfterburnerRate:]` (3676) | `setAfterburnerRate` Core/Entities/ShipEntity.cpp:4297 | ✅ |
| `-[ShipEntity maxThrust]` (3681) | `maxThrust` Core/Entities/ShipEntity.cpp:4301 | ✅ |
| `-[ShipEntity setMaxThrust:]` (3686) | `setMaxThrust` Core/Entities/ShipEntity.cpp:4303 | ✅ |
| `-[ShipEntity thrust]` (3691) | `getThrust` Core/Entities/ShipEntity.cpp:4305 | ✅ |
| `-[ShipEntity behaviour_stop_still:]` (3700) | `behaviour_stop_still` Core/Entities/ShipEntity.cpp:4311 | ✅ |
| `-[ShipEntity behaviour_idle:]` (3708) | `behaviour_idle` Core/Entities/ShipEntity.cpp:4318 | ✅ |
| `-[ShipEntity behaviour_tumble:]` (3724) | `behaviour_tumble` Core/Entities/ShipEntity.cpp:4333 | ✅ |
| `-[ShipEntity behaviour_tractored:]` (3729) | `behaviour_tractored` Core/Entities/ShipEntity.cpp:4335 | ✅ |
| `-[ShipEntity behaviour_track_target:]` (3805) | `behaviour_track_target` Core/Entities/ShipEntity.cpp:4416 | ✅ |
| `-[ShipEntity behaviour_intercept_target:]` (3817) | `behaviour_intercept_target` Core/Entities/ShipEntity.cpp:4427 | ✅ |
| `-[ShipEntity behaviour_attack_break_off_target:]` (3886) | `behaviour_attack_break_off_target` Core/Entities/ShipEntity.cpp:4506 | ✅ |
| `-[ShipEntity behaviour_attack_slow_dogfight:]` (3944) | `behaviour_attack_slow_dogfight` Core/Entities/ShipEntity.cpp:4567 | ❌ |
| `-[ShipEntity behaviour_evasive_action:]` (3996) | `behaviour_evasive_action` Core/Entities/ShipEntity.cpp:4618 | ✅ |
| `-[ShipEntity behaviour_attack_target:]` (4038) | `behaviour_attack_target` Core/Entities/ShipEntity.cpp:4660 | ✅ |
| `-[ShipEntity behaviour_attack_broadside:]` (4187) | `behaviour_attack_broadside` Core/Entities/ShipEntity.cpp:4854 | ✅ |
| `-[ShipEntity behaviour_attack_broadside_left:]` (4235) | `behaviour_attack_broadside_left` Core/Entities/ShipEntity.cpp:4899 | ✅ |
| `-[ShipEntity behaviour_attack_broadside_right:]` (4240) | `behaviour_attack_broadside_right` Core/Entities/ShipEntity.cpp:4903 | ✅ |
| `-[ShipEntity behaviour_attack_broadside_target:leftside:]` (4245) | `behaviour_attack_broadside_target` Core/Entities/ShipEntity.cpp:4907 | ✅ |
| `-[ShipEntity behaviour_close_to_broadside_range:]` (4338) | `behaviour_close_to_broadside_range` Core/Entities/ShipEntity.cpp:5008 | ✅ |
| `-[ShipEntity behaviour_close_with_target:]` (4369) | `behaviour_close_with_target` Core/Entities/ShipEntity.cpp:5039 | ✅ |
| `-[ShipEntity behaviour_attack_sniper:]` (4397) | `behaviour_attack_sniper` Core/Entities/ShipEntity.cpp:5070 | ✅ |
| `-[ShipEntity behaviour_fly_to_target_six:]` (4461) | `behaviour_fly_to_target_six` Core/Entities/ShipEntity.cpp:5133 | ✅ |
| `-[ShipEntity behaviour_attack_mining_target:]` (4582) | `behaviour_attack_mining_target` Core/Entities/ShipEntity.cpp:5269 | ✅ |
| `-[ShipEntity behaviour_attack_fly_to_target:]` (4611) | `behaviour_attack_fly_to_target` Core/Entities/ShipEntity.cpp:5299 | ✅ |
| `-[ShipEntity behaviour_attack_fly_from_target:]` (4733) | `behaviour_attack_fly_from_target` Core/Entities/ShipEntity.cpp:5458 | ✅ |
| `-[ShipEntity behaviour_running_defense:]` (4801) | `behaviour_running_defense` Core/Entities/ShipEntity.cpp:5526 | ✅ |
| `-[ShipEntity behaviour_flee_target:]` (4840) | `behaviour_flee_target` Core/Entities/ShipEntity.cpp:5566 | ✅ |
| `-[ShipEntity behaviour_fly_range_from_destination:]` (4903) | `behaviour_fly_range_from_destination` Core/Entities/ShipEntity.cpp:5629 | ✅ |
| `-[ShipEntity behaviour_face_destination:]` (4920) | `behaviour_face_destination` Core/Entities/ShipEntity.cpp:5649 | ✅ |
| `-[ShipEntity behaviour_land_on_planet:]` (4967) | `behaviour_land_on_planet` Core/Entities/ShipEntity.cpp:5703 | ✅ |
| `-[ShipEntity behaviour_formation_form_up:]` (5002) | `behaviour_formation_form_up` Core/Entities/ShipEntity.cpp:5746 | ✅ |
| `-[ShipEntity behaviour_fly_to_destination:]` (5049) | `behaviour_fly_to_destination` Core/Entities/ShipEntity.cpp:5805 | ✅ |
| `-[ShipEntity behaviour_fly_from_destination:]` (5136) | `behaviour_fly_from_destination` Core/Entities/ShipEntity.cpp:5914 | ✅ |
| `-[ShipEntity behaviour_avoid_collision:]` (5155) | `behaviour_avoid_collision` Core/Entities/ShipEntity.cpp:5932 | ✅ |
| `-[ShipEntity behaviour_track_as_turret:]` (5173) | `behaviour_track_as_turret` Core/Entities/ShipEntity.cpp:5952 (`defenseTargets()` snapshot of live targets) | ✅ |
| `-[ShipEntity behaviour_fly_thru_navpoints:]` (5223) | `behaviour_fly_thru_navpoints` Core/Entities/ShipEntity.cpp:6019 | ✅ |
| `-[ShipEntity behaviour_scripted_ai:]` (5300) | `behaviour_scripted_ai` Core/Entities/ShipEntity.cpp:6097 | ❌ |
| `-[ShipEntity reactionTime]` (5402) | `getReactionTime` Core/Entities/ShipEntity.cpp:6203 | ✅ |
| `-[ShipEntity setReactionTime:]` (5407) | `setReactionTime` Core/Entities/ShipEntity.cpp:6205 | ✅ |
| `-[ShipEntity calculateTargetPosition]` (5412) | `calculateTargetPosition` Core/Entities/ShipEntity.cpp:6209 | ✅ |
| `-[ShipEntity startTrackingCurve]` (5425) | `startTrackingCurve` Core/Entities/ShipEntity.cpp:6228 | ✅ |
| `-[ShipEntity updateTrackingCurve]` (5444) | `updateTrackingCurve` Core/Entities/ShipEntity.cpp:6250 | ✅ |
| `-[ShipEntity calculateTrackingCurve]` (5469) | `calculateTrackingCurve` Core/Entities/ShipEntity.cpp:6284 | ✅ |
| `-[ShipEntity drawImmediate:translucent:]` (5491) | `drawImmediate` Core/Entities/ShipEntity.cpp:6311 (subentities via `cxx::OOSubEntityInterface`) | ✅ |
| `-[ShipEntity drawDebugStuff]` (5528) | `drawDebugStuff` Core/Entities/ShipEntity.cpp:6364 (dead `if (0 && …)` kept) | ✅ |
| `-[ShipEntity drawSubEntityImmediate:translucent:]` (5554) | `drawSubEntityImmediate` Core/Entities/ShipEntity.cpp:6405 | ✅ |
| static scanner colour tables `cargo_color` … `scripted_color` (5580) | Core/Entities/ShipEntity.cpp:409-420 (all 11 tables, same values) | ✅ |
| `-[ShipEntity scannerDisplayColorForShip:isHostile:flash:scannerDisplayColor1:scannerDisplayColor2:scannerDisplayColorH1:scannerDisplayColorH2:]` (5592) | `scannerDisplayColorForShip` Core/Entities/ShipEntity.cpp:6432 | ✅ |
| `-[ShipEntity setScannerDisplayColor1:]` (5690) | `setScannerDisplayColor1` Core/Entities/ShipEntity.cpp:6539 | ✅ |
| `-[ShipEntity setScannerDisplayColor2:]` (5699) | `setScannerDisplayColor2` Core/Entities/ShipEntity.cpp:6547 | ✅ |
| `-[ShipEntity scannerDisplayColor1]` (5708) | `scannerDisplayColor1` Core/Entities/ShipEntity.cpp:6555 | ✅ |
| `-[ShipEntity scannerDisplayColor2]` (5713) | `scannerDisplayColor2` Core/Entities/ShipEntity.cpp:6559 | ✅ |
| `-[ShipEntity setScannerDisplayColorHostile1:]` (5718) | `setScannerDisplayColorHostile1` Core/Entities/ShipEntity.cpp:6563 | ✅ |
| `-[ShipEntity setScannerDisplayColorHostile2:]` (5727) | `setScannerDisplayColorHostile2` Core/Entities/ShipEntity.cpp:6571 | ✅ |
| `-[ShipEntity scannerDisplayColorHostile1]` (5736) | `scannerDisplayColorHostile1` Core/Entities/ShipEntity.cpp:6579 | ✅ |
| `-[ShipEntity scannerDisplayColorHostile2]` (5741) | `scannerDisplayColorHostile2` Core/Entities/ShipEntity.cpp:6583 | ✅ |
| `-[ShipEntity isCloaked]` (5746) | `isCloaked` Core/Entities/ShipEntity.cpp:6587 | ✅ |
| `-[ShipEntity cloakPassive]` (5751) | `getCloakPassive` Core/Entities/ShipEntity.cpp:6589 | ✅ |
| `-[ShipEntity setCloaked:]` (5756) | `setCloaked` Core/Entities/ShipEntity.cpp:6591 | ✅ |
| `-[ShipEntity hasAutoCloak]` (5764) | `hasAutoCloak` Core/Entities/ShipEntity.cpp:6598 | ✅ |
| `-[ShipEntity setAutoCloak:]` (5769) | `setAutoCloak` Core/Entities/ShipEntity.cpp:6600 | ✅ |
| `-[ShipEntity isJammingScanning]` (5774) | `isJammingScanning` Core/Entities/ShipEntity.cpp:6602 | ✅ |
| `-[ShipEntity addSubEntity:]` (5779) | `addSubEntity` Core/Entities/ShipEntity.cpp:6606 (append before `setOwner`) | ✅ |
| `-[ShipEntity setOwner:]` (5794) | `setOwner` Core/Entities/ShipEntity.cpp:6617 | ✅ |
| `-[ShipEntity applyThrust:]` (5808) | `applyThrust` Core/Entities/ShipEntity.cpp:6631 | ✅ |
| `-[ShipEntity orientationChanged]` (5856) | `orientationChanged` Core/Entities/ShipEntity.cpp:6674 | ✅ |
| `-[ShipEntity applyRoll:andClimb:]` (5865) | `applyRoll(roll, climb)` Core/Entities/ShipEntity.cpp:6685 | ✅ |
| `-[ShipEntity applyRoll:climb:andYaw:]` (5881) | `applyRoll(roll, climb, yaw)` Core/Entities/ShipEntity.cpp:6697 | ✅ |
| `-[ShipEntity applyAttitudeChanges:]` (5899) | `applyAttitudeChanges` Core/Entities/ShipEntity.cpp:6711 | ✅ |
| `-[ShipEntity avoidCollision]` (5904) | `avoidCollision` Core/Entities/ShipEntity.cpp:6715 | ✅ |
| `-[ShipEntity resumePostProximityAlert]` (5938) | `resumePostProximityAlert` Core/Entities/ShipEntity.cpp:6752 | ✅ |
| `-[ShipEntity messageTime]` (5960) | `getMessageTime` Core/Entities/ShipEntity.cpp:6774 | ✅ |
| `-[ShipEntity setMessageTime:]` (5965) | `setMessageTime` Core/Entities/ShipEntity.cpp:6776 | ✅ |
| `-[ShipEntity group]` (5970) | `group` Core/Entities/ShipEntity.cpp:6778 | ✅ |
| `-[ShipEntity setGroup:]` (5975) | `setGroup` Core/Entities/ShipEntity.cpp:6780 | ✅ |
| `-[ShipEntity escortGroup]` (5991) | `escortGroup` Core/Entities/ShipEntity.cpp:6795 | ✅ |
| `-[ShipEntity setEscortGroup:]` (6001) | `setEscortGroup` Core/Entities/ShipEntity.cpp:6804 | ✅ |
| `-[ShipEntity rawEscortGroup]` (6012) | `rawEscortGroup` Core/Entities/ShipEntity.cpp:6815 | ✅ |
| `-[ShipEntity stationGroup]` (6018) | `stationGroup` Core/Entities/ShipEntity.cpp:6818 | ✅ |
| `-[ShipEntity hasEscorts]` (6028) | `hasEscorts` Core/Entities/ShipEntity.cpp:6827 | ✅ |
| `-[ShipEntity escortEnumerator]` (6035) | `escorts` Core/Entities/ShipEntity.cpp:6832 (member snapshot excluding self) | ✅ |
| `-[ShipEntity escortArray]` (6042) | `escortArray` Core/Entities/ShipEntity.cpp:6845 | ✅ |
| `-[ShipEntity escortCount]` (6049) | `escortCount` Core/Entities/ShipEntity.cpp:6847 | ✅ |
| `-[ShipEntity pendingEscortCount]` (6056) | `pendingEscortCount` Core/Entities/ShipEntity.cpp:6852 | ✅ |
| `-[ShipEntity setPendingEscortCount:]` (6061) | `setPendingEscortCount` Core/Entities/ShipEntity.cpp:6854 | ✅ |
| `-[ShipEntity maxEscortCount]` (6066) | `maxEscortCount` Core/Entities/ShipEntity.cpp:6858 | ✅ |
| `-[ShipEntity setMaxEscortCount:]` (6071) | `setMaxEscortCount` Core/Entities/ShipEntity.cpp:6860 | ✅ |
| `-[ShipEntity turretCount]` (6076) | `turretCount` Core/Entities/ShipEntity.cpp:6864 | ✅ |
| `-[ShipEntity proximityAlert]` (6089) | `proximityAlert` Core/Entities/ShipEntity.cpp:6876 | ✅ |
| `-[ShipEntity setProximityAlert:]` (6098) | `setProximityAlert` Core/Entities/ShipEntity.cpp:6885 | ✅ |
| `-[ShipEntity name]` (6148) | `getName` Core/Entities/ShipEntity.cpp:6941 | ✅ |
| `-[ShipEntity shipUniqueName]` (6153) | `getShipUniqueName` Core/Entities/ShipEntity.cpp:6943 | ✅ |
| `-[ShipEntity shipClassName]` (6158) | `getShipClassName` Core/Entities/ShipEntity.cpp:6947 | ✅ |
| `-[ShipEntity displayName]` (6163) | `getDisplayName` Core/Entities/ShipEntity.cpp:6951 | ✅ |
| `-[ShipEntity scanDescriptionForScripting]` (6184) | `scanDescriptionForScripting` Core/Entities/ShipEntity.cpp:6972 | ✅ |
| `-[ShipEntity scanDescription]` (6189) | `scanDescription` Core/Entities/ShipEntity.cpp:6976 | ✅ |
| `-[ShipEntity setName:]` (6224) | `setName` Core/Entities/ShipEntity.cpp:7017 | ✅ |
| `-[ShipEntity setShipUniqueName:]` (6230) | `setShipUniqueName` Core/Entities/ShipEntity.cpp:7021 | ✅ |
| `-[ShipEntity setShipClassName:]` (6236) | `setShipClassName` Core/Entities/ShipEntity.cpp:7025 | ✅ |
| `-[ShipEntity setDisplayName:]` (6242) | `setDisplayName` Core/Entities/ShipEntity.cpp:7029 | ✅ |
| `-[ShipEntity setScanDescription:]` (6248) | `setScanDescription` Core/Entities/ShipEntity.cpp:7033 | ✅ |
| `-[ShipEntity identFromShip:]` (6254) | `identFromShip` Core/Entities/ShipEntity.cpp:7040 | ✅ |
| `-[ShipEntity hasRole:]` (6262) | `hasRole` Core/Entities/ShipEntity.cpp:7048 | ✅ |
| `-[ShipEntity roleSet]` (6267) | `getRoleSet` Core/Entities/ShipEntity.cpp:7053 | ✅ |
| `-[ShipEntity addRole:]` (6274) | `addRole(role)` Core/Entities/ShipEntity.cpp:7066 | ✅ |
| `-[ShipEntity addRole:withProbability:]` (6279) | `addRole(role, probability)` Core/Entities/ShipEntity.cpp:7068 | ✅ |
| `-[ShipEntity removeRole:]` (6294) | `removeRole` Core/Entities/ShipEntity.cpp:7081 | ✅ |
| `-[ShipEntity primaryRole]` (6305) | `getPrimaryRole` Core/Entities/ShipEntity.cpp:7091 (same `ship.noPrimaryRole` log) | ✅ |
| `-[ShipEntity setPrimaryRole:]` (6319) | `setPrimaryRole` Core/Entities/ShipEntity.cpp:7104 | ✅ |
| `-[ShipEntity hasPrimaryRole:]` (6327) | `hasPrimaryRole` Core/Entities/ShipEntity.cpp:7106 | ✅ |
| `-[ShipEntity isPolice]` (6332) | `isPolice` Core/Entities/ShipEntity.cpp:7110 | ✅ |
| `-[ShipEntity isThargoid]` (6338) | `isThargoid` Core/Entities/ShipEntity.cpp:7116 | ✅ |
| `-[ShipEntity isTrader]` (6343) | `isTrader` Core/Entities/ShipEntity.cpp:7120 | ✅ |
| `-[ShipEntity isPirate]` (6348) | `isPirate` Core/Entities/ShipEntity.cpp:7126 | ✅ |
| `-[ShipEntity isMissile]` (6353) | `getIsMissile` Core/Entities/ShipEntity.cpp:7132 | ✅ |
| `-[ShipEntity isMine]` (6358) | `isMine` Core/Entities/ShipEntity.cpp:7137 | ✅ |
| `-[ShipEntity isWeapon]` (6363) | `isWeapon` Core/Entities/ShipEntity.cpp:7141 | ✅ |
| `-[ShipEntity isEscort]` (6368) | `isEscort` Core/Entities/ShipEntity.cpp:7143 | ✅ |
| `-[ShipEntity isShuttle]` (6373) | `isShuttle` Core/Entities/ShipEntity.cpp:7149 | ✅ |
| `-[ShipEntity isTurret]` (6378) | `isTurret` Core/Entities/ShipEntity.cpp:7155 | ✅ |
| `-[ShipEntity isPirateVictim]` (6383) | `isPirateVictim` Core/Entities/ShipEntity.cpp:7157 | ✅ |
| `-[ShipEntity isExplicitlyUnpiloted]` (6388) | `isExplicitlyUnpiloted` Core/Entities/ShipEntity.cpp:7163 | ✅ |
| `-[ShipEntity isUnpiloted]` (6393) | `isUnpiloted` Core/Entities/ShipEntity.cpp:7176 (virtual; StationEntity overrides) | ✅ |
| `IsBehaviourHostile` (6398) | `IsBehaviourHostile` (static) Core/Entities/ShipEntity.cpp:422 (same cases, same unreachable tail) | ✅ |
| `-[ShipEntity hasHostileTarget]` (6430) | `hasHostileTarget` Core/Entities/ShipEntity.cpp:7183 | ✅ |
| `-[ShipEntity isHostileTo:]` (6446) | `isHostileTo` Core/Entities/ShipEntity.cpp:7199 | ✅ |
| `-[ShipEntity weaponRange]` (6451) | `getWeaponRange` Core/Entities/ShipEntity.cpp:7203 | ✅ |
| `-[ShipEntity setWeaponRange:]` (6456) | `setWeaponRange` Core/Entities/ShipEntity.cpp:7205 | ✅ |
| `-[ShipEntity setWeaponDataFromType:]` (6461) | `setWeaponDataFromType` Core/Entities/ShipEntity.cpp:7207 (nil type → zeros) | ✅ |
| `-[ShipEntity energyRechargeRate]` (6477) | `energyRechargeRate` Core/Entities/ShipEntity.cpp:7227 | ✅ |
| `-[ShipEntity setEnergyRechargeRate:]` (6482) | `setEnergyRechargeRate` Core/Entities/ShipEntity.cpp:7229 | ✅ |
| `-[ShipEntity weaponRechargeRate]` (6487) | `weaponRechargeRate` Core/Entities/ShipEntity.cpp:7233 | ✅ |
| `-[ShipEntity setWeaponRechargeRate:]` (6492) | `setWeaponRechargeRate` Core/Entities/ShipEntity.cpp:7235 | ✅ |
| `-[ShipEntity setWeaponEnergy:]` (6497) | `setWeaponEnergy` Core/Entities/ShipEntity.cpp:7239 | ✅ |
| `-[ShipEntity currentWeaponFacing]` (6502) | `getCurrentWeaponFacing` Core/Entities/ShipEntity.cpp:7241 | ✅ |
| `-[ShipEntity scannerRange]` (6507) | `getScannerRange` Core/Entities/ShipEntity.cpp:7245 | ✅ |
| `-[ShipEntity setScannerRange:]` (6512) | `setScannerRange` Core/Entities/ShipEntity.cpp:7247 | ✅ |
| `-[ShipEntity reference]` (6517) | `getReference` Core/Entities/ShipEntity.cpp:7249 | ✅ |
| `-[ShipEntity setReference:]` (6522) | `setReference` Core/Entities/ShipEntity.cpp:7251 | ✅ |
| `-[ShipEntity reportAIMessages]` (6527) | `getReportAIMessages` Core/Entities/ShipEntity.cpp:7253 | ✅ |
| `-[ShipEntity setReportAIMessages:]` (6532) | `setReportAIMessages` Core/Entities/ShipEntity.cpp:7255 | ✅ |
| `-[ShipEntity transitionToAegisNone]` (6537) | `transitionToAegisNone` Core/Entities/ShipEntity.cpp:7257 | ✅ |
| `SurfaceDistanceSqaredV` (6558) | `SurfaceDistanceSqaredV` (anonymous namespace) Core/Entities/ShipEntity.cpp:454 | ✅ |
| `SurfaceDistanceSqared` (6568) | `SurfaceDistanceSqared` (anonymous namespace) Core/Entities/ShipEntity.cpp:464 | ✅ |
| `ComparePlanetsBySurfaceDistance` (6573) | `ComparePlanetsBySurfaceDistance` (anonymous namespace) Core/Entities/ShipEntity.cpp:468 | ✅ |
| `-[ShipEntity findNearestPlanet]` (6590) | `findNearestPlanet` Core/Entities/ShipEntity.cpp:7277 | ✅ |
| `-[ShipEntity findNearestStellarBody]` (6619) | `findNearestStellarBody` Core/Entities/ShipEntity.cpp:7310 | ✅ |
| `-[ShipEntity findNearestPlanetExcludingMoons]` (6633) | `findNearestPlanetExcludingMoons` Core/Entities/ShipEntity.cpp:7324 (`std::stable_sort`) | ✅ |
| `-[ShipEntity checkForAegis]` (6659) | `checkForAegis` Core/Entities/ShipEntity.cpp:7353 | ✅ |
| `-[ShipEntity forceAegisCheck]` (6789) | `forceAegisCheck` Core/Entities/ShipEntity.cpp:7527 | ✅ |
| `-[ShipEntity withinStationAegis]` (6794) | `withinStationAegis` Core/Entities/ShipEntity.cpp:7529 | ✅ |
| `-[ShipEntity lastAegisLock]` (6799) | `lastAegisLock` Core/Entities/ShipEntity.cpp:7535 | ✅ |
| `-[ShipEntity setLastAegisLock:]` (6810) | `setLastAegisLock` Core/Entities/ShipEntity.cpp:7545 | ✅ |
| `-[ShipEntity homeSystem]` (6816) | `homeSystem` Core/Entities/ShipEntity.cpp:7549 | ✅ |
| `-[ShipEntity destinationSystem]` (6821) | `ShipEntity::destinationSystem` Core/Entities/ShipEntity.cpp:7551 | ✅ |
| `-[ShipEntity setHomeSystem:]` (6826) | `ShipEntity::setHomeSystem` Core/Entities/ShipEntity.cpp:7553 | ✅ |
| `-[ShipEntity setDestinationSystem:]` (6831) | `ShipEntity::setDestinationSystem` Core/Entities/ShipEntity.cpp:7555 | ✅ |
| `-[ShipEntity setStatus:]` (6836) | `ShipEntity::setStatus` Core/Entities/ShipEntity.cpp:7557 | ✅ |
| `-[ShipEntity setLaunchDelay:]` (6846) | `ShipEntity::setLaunchDelay` Core/Entities/ShipEntity.cpp:7565 | ✅ |
| `-[ShipEntity crew]` (6851) | `ShipEntity::getCrew` Core/Entities/ShipEntity.cpp:7567 | ✅ |
| `-[ShipEntity setCrew:]` (6856) | `ShipEntity::setCrew` Core/Entities/ShipEntity.cpp:7571 | ✅ |
| `-[ShipEntity setSingleCrewWithRole:]` (6870) | `ShipEntity::setSingleCrewWithRole` Core/Entities/ShipEntity.cpp:7585 | ✅ |
| `-[ShipEntity crewForScripting]` (6879) | `ShipEntity::crewForScripting` Core/Entities/ShipEntity.cpp:7593 | ✅ |
| `-[ShipEntity setStateMachine:]` (6893) | `ShipEntity::setStateMachine` Core/Entities/ShipEntity.cpp:7605 | ✅ |
| `-[ShipEntity setAI:]` (6898) | `ShipEntity::setAI` Core/Entities/ShipEntity.cpp:7607 | ✅ |
| `-[ShipEntity getAI]` (6908) | `ShipEntity::getAI` Core/Entities/ShipEntity.cpp:7616 | ✅ |
| `-[ShipEntity hasAutoAI]` (6913) | `ShipEntity::hasAutoAI` Core/Entities/ShipEntity.cpp:7618 | ✅ |
| `-[ShipEntity hasNewAI]` (6918) | `ShipEntity::hasNewAI` Core/Entities/ShipEntity.cpp:7622 | ✅ |
| `-[ShipEntity hasAutoWeapons]` (6923) | `ShipEntity::hasAutoWeapons` Core/Entities/ShipEntity.cpp:7628 | ✅ |
| `-[ShipEntity setShipScript:]` (6928) | `ShipEntity::setShipScript` Core/Entities/ShipEntity.cpp:7632 | ✅ |
| `-[ShipEntity frustration]` (6978) | `ShipEntity::getFrustration` Core/Entities/ShipEntity.cpp:7689 | ✅ |
| `-[ShipEntity fuel]` (6983) | `ShipEntity::getFuel` Core/Entities/ShipEntity.cpp:7691 | ✅ |
| `-[ShipEntity setFuel:]` (6988) | `ShipEntity::setFuel` Core/Entities/ShipEntity.cpp:7693 | ✅ |
| `-[ShipEntity fuelCapacity]` (6996) | `ShipEntity::fuelCapacity` Core/Entities/ShipEntity.cpp:7699 | ✅ |
| `-[ShipEntity fuelChargeRate]` (7002) | `ShipEntity::fuelChargeRate` Core/Entities/ShipEntity.cpp:7705 | ✅ |
| `-[ShipEntity applySticks:]` (7018) | `ShipEntity::applySticks` Core/Entities/ShipEntity.cpp:7727 | ✅ |
| `-[ShipEntity setRoll:]` (7067) | `ShipEntity::setRoll` Core/Entities/ShipEntity.cpp:7774 | ✅ |
| `-[ShipEntity setRawRoll:]` (7072) | `ShipEntity::setRawRoll` Core/Entities/ShipEntity.cpp:7776 | ✅ |
| `-[ShipEntity setPitch:]` (7077) | `ShipEntity::setPitch` Core/Entities/ShipEntity.cpp:7778 | ✅ |
| `-[ShipEntity setYaw:]` (7082) | `ShipEntity::setYaw` Core/Entities/ShipEntity.cpp:7780 | ✅ |
| `-[ShipEntity setThrust:]` (7087) | `ShipEntity::setThrust` Core/Entities/ShipEntity.cpp:7782 | ✅ |
| `-[ShipEntity setThrustForDemo:]` (7092) | `ShipEntity::setThrustForDemo` Core/Entities/ShipEntity.cpp:7784 | ✅ |
| `-[ShipEntity setBounty:]` (7097) | `ShipEntity::setBounty(amount)` Core/Entities/ShipEntity.cpp:7788 | ✅ |
| `-[ShipEntity setBounty:withReason:]` (7102) | `ShipEntity::setBounty(amount, reason)` Core/Entities/ShipEntity.cpp:7792 | ✅ |
| `-[ShipEntity setBounty:withReasonAsString:]` (7118) | `ShipEntity::setBounty(amount, string)` Core/Entities/ShipEntity.cpp:7811 | ✅ |
| `-[ShipEntity bounty]` (7137) | `ShipEntity::getBounty` Core/Entities/ShipEntity.cpp:7833 | ✅ |
| `-[ShipEntity legalStatus]` (7146) | `ShipEntity::legalStatus` Core/Entities/ShipEntity.cpp:7843 | ✅ |
| `-[ShipEntity setCommodity:andAmount:]` (7155) | `ShipEntity::setCommodity` Core/Entities/ShipEntity.cpp:7849 | ✅ |
| `-[ShipEntity setCommodityForPod:andAmount:]` (7168) | `ShipEntity::setCommodityForPod` Core/Entities/ShipEntity.cpp:7857 | ✅ |
| `-[ShipEntity commodityType]` (7188) | `ShipEntity::commodityType` Core/Entities/ShipEntity.cpp:7882 | ✅ |
| `-[ShipEntity commodityAmount]` (7193) | `ShipEntity::commodityAmount` Core/Entities/ShipEntity.cpp:7886 | ✅ |
| `-[ShipEntity maxAvailableCargoSpace]` (7198) | `ShipEntity::maxAvailableCargoSpace` Core/Entities/ShipEntity.cpp:7888 | ✅ |
| `-[ShipEntity setMaxAvailableCargoSpace:]` (7203) | `ShipEntity::setMaxAvailableCargoSpace` Core/Entities/ShipEntity.cpp:7892 | ✅ |
| `-[ShipEntity availableCargoSpace]` (7208) | `ShipEntity::availableCargoSpace` Core/Entities/ShipEntity.cpp:7896 | ✅ |
| `-[ShipEntity cargoQuantityOnBoard]` (7216) | `ShipEntity::cargoQuantityOnBoard` Core/Entities/ShipEntity.cpp:7903 | ✅ |
| `-[ShipEntity cargoType]` (7223) | `ShipEntity::cargoType` Core/Entities/ShipEntity.cpp:7909 | ✅ |
| `-[ShipEntity cargo]` (7230) | `ShipEntity::getCargo` Core/Entities/ShipEntity.cpp:7915 | ✅ |
| `-[ShipEntity cargoListForScripting]` (7235) | `ShipEntity::cargoListForScripting` Core/Entities/ShipEntity.cpp:7919 | ⚠️ |
| `-[ShipEntity setCargo:]` (7269) | `ShipEntity::setCargo` Core/Entities/ShipEntity.cpp:7964 | ✅ |
| `-[ShipEntity addCargo:]` (7275) | `ShipEntity::addCargo` Core/Entities/ShipEntity.cpp:7968 | ✅ |
| `-[ShipEntity removeCargo:amount:]` (7285) | `ShipEntity::removeCargo` Core/Entities/ShipEntity.cpp:7977 | ✅ |
| `-[ShipEntity showScoopMessage]` (7313) | `ShipEntity::showScoopMessage` Core/Entities/ShipEntity.cpp:8008 | ✅ |
| `-[ShipEntity cargoFlag]` (7318) | `ShipEntity::cargoFlag` Core/Entities/ShipEntity.cpp:8010 | ✅ |
| `-[ShipEntity setCargoFlag:]` (7323) | `ShipEntity::setCargoFlag` Core/Entities/ShipEntity.cpp:8012 | ✅ |
| `-[ShipEntity setSpeed:]` (7375) | `ShipEntity::setSpeed` Core/Entities/ShipEntity.cpp:8079 | ✅ |
| `-[ShipEntity setDesiredSpeed:]` (7380) | `ShipEntity::setDesiredSpeed` Core/Entities/ShipEntity.cpp:8081 | ✅ |
| `-[ShipEntity desiredSpeed]` (7385) | `ShipEntity::desiredSpeed` Core/Entities/ShipEntity.cpp:8083 | ✅ |
| `-[ShipEntity desiredRange]` (7390) | `ShipEntity::desiredRange` Core/Entities/ShipEntity.cpp:8088 | ✅ |
| `-[ShipEntity setDesiredRange:]` (7395) | `ShipEntity::setDesiredRange` Core/Entities/ShipEntity.cpp:8090 | ✅ |
| `-[ShipEntity cruiseSpeed]` (7400) | `ShipEntity::getCruiseSpeed` Core/Entities/ShipEntity.cpp:8092 | ✅ |
| `-[ShipEntity increase_flight_speed:]` (7405) | `ShipEntity::increase_flight_speed` Core/Entities/ShipEntity.cpp:8094 | ✅ |
| `-[ShipEntity decrease_flight_speed:]` (7417) | `ShipEntity::decrease_flight_speed` Core/Entities/ShipEntity.cpp:8105 | ✅ |
| `-[ShipEntity increase_flight_roll:]` (7431) | `ShipEntity::increase_flight_roll` Core/Entities/ShipEntity.cpp:8118 | ✅ |
| `-[ShipEntity decrease_flight_roll:]` (7440) | `ShipEntity::decrease_flight_roll` Core/Entities/ShipEntity.cpp:8126 | ✅ |
| `-[ShipEntity increase_flight_pitch:]` (7449) | `ShipEntity::increase_flight_pitch` Core/Entities/ShipEntity.cpp:8134 | ✅ |
| `-[ShipEntity decrease_flight_pitch:]` (7458) | `ShipEntity::decrease_flight_pitch` Core/Entities/ShipEntity.cpp:8142 | ✅ |
| `-[ShipEntity increase_flight_yaw:]` (7467) | `ShipEntity::increase_flight_yaw` Core/Entities/ShipEntity.cpp:8150 | ✅ |
| `-[ShipEntity decrease_flight_yaw:]` (7476) | `ShipEntity::decrease_flight_yaw` Core/Entities/ShipEntity.cpp:8158 | ✅ |
| `-[ShipEntity flightRoll]` (7485) | `ShipEntity::getFlightRoll` Core/Entities/ShipEntity.cpp:8166 | ✅ |
| `-[ShipEntity flightPitch]` (7490) | `ShipEntity::getFlightPitch` Core/Entities/ShipEntity.cpp:8168 | ✅ |
| `-[ShipEntity flightYaw]` (7495) | `ShipEntity::getFlightYaw` Core/Entities/ShipEntity.cpp:8170 | ✅ |
| `-[ShipEntity flightSpeed]` (7500) | `ShipEntity::getFlightSpeed` Core/Entities/ShipEntity.cpp:8172 | ✅ |
| `-[ShipEntity maxFlightPitch]` (7505) | `ShipEntity::maxFlightPitch` Core/Entities/ShipEntity.cpp:8174 | ✅ |
| `-[ShipEntity maxFlightSpeed]` (7510) | `ShipEntity::getMaxFlightSpeed` Core/Entities/ShipEntity.cpp:8176 | ✅ |
| `-[ShipEntity maxFlightRoll]` (7515) | `ShipEntity::maxFlightRoll` Core/Entities/ShipEntity.cpp:8178 | ✅ |
| `-[ShipEntity maxFlightYaw]` (7520) | `ShipEntity::maxFlightYaw` Core/Entities/ShipEntity.cpp:8180 | ✅ |
| `-[ShipEntity setMaxFlightPitch:]` (7525) | `ShipEntity::setMaxFlightPitch` Core/Entities/ShipEntity.cpp:8182 | ✅ |
| `-[ShipEntity setMaxFlightSpeed:]` (7530) | `ShipEntity::setMaxFlightSpeed` Core/Entities/ShipEntity.cpp:8186 | ✅ |
| `-[ShipEntity setMaxFlightRoll:]` (7535) | `ShipEntity::setMaxFlightRoll` Core/Entities/ShipEntity.cpp:8190 | ✅ |
| `-[ShipEntity setMaxFlightYaw:]` (7540) | `ShipEntity::setMaxFlightYaw` Core/Entities/ShipEntity.cpp:8194 | ✅ |
| `-[ShipEntity speedFactor]` (7545) | `ShipEntity::speedFactor` Core/Entities/ShipEntity.cpp:8198 | ✅ |
| `-[ShipEntity temperature]` (7552) | `ShipEntity::temperature` Core/Entities/ShipEntity.cpp:8203 | ✅ |
| `-[ShipEntity setTemperature:]` (7557) | `ShipEntity::setTemperature` Core/Entities/ShipEntity.cpp:8205 | ✅ |
| `-[ShipEntity randomEjectaTemperature]` (7562) | `ShipEntity::randomEjectaTemperature` Core/Entities/ShipEntity.cpp:8207 | ✅ |
| `-[ShipEntity randomEjectaTemperatureWithMaxFactor:]` (7567) | `ShipEntity::randomEjectaTemperatureWithMaxFactor` Core/Entities/ShipEntity.cpp:8211 | ✅ |
| `-[ShipEntity heatInsulation]` (7584) | `ShipEntity::heatInsulation` Core/Entities/ShipEntity.cpp:8229 | ✅ |
| `-[ShipEntity setHeatInsulation:]` (7589) | `ShipEntity::setHeatInsulation` Core/Entities/ShipEntity.cpp:8231 | ✅ |
| `-[ShipEntity damage]` (7594) | `ShipEntity::damage` Core/Entities/ShipEntity.cpp:8233 | ✅ |
| `-[ShipEntity dealEnergyDamage:atRange:withBias:]` (7599) | `ShipEntity::dealEnergyDamage` Core/Entities/ShipEntity.cpp:8237 | ✅ |
| `-[ShipEntity dealEnergyDamageWithinDesiredRange]` (7662) | `ShipEntity::dealEnergyDamageWithinDesiredRange` Core/Entities/ShipEntity.cpp:8315 | ✅ |
| `-[ShipEntity dealMomentumWithinDesiredRange:]` (7680) | `ShipEntity::dealMomentumWithinDesiredRange` Core/Entities/ShipEntity.cpp:8344 | ✅ |
| `-[ShipEntity isHulk]` (7702) | `ShipEntity::getIsHulk` Core/Entities/ShipEntity.cpp:8368 | ✅ |
| `-[ShipEntity setHulk:]` (7707) | `ShipEntity::setHulk` Core/Entities/ShipEntity.cpp:8370 | ✅ |
| `-[ShipEntity noteTakingDamage:from:type:]` (7714) | `ShipEntity::noteTakingDamage` Core/Entities/ShipEntity.cpp:8376 | ✅ |
| `-[ShipEntity noteKilledBy:damageType:]` (7743) | `ShipEntity::noteKilledBy` Core/Entities/ShipEntity.cpp:8415 | ✅ |
| `-[ShipEntity getDestroyedBy:damageType:]` (7768) | `ShipEntity::getDestroyedBy` Core/Entities/ShipEntity.cpp:8443 | ✅ |
| `-[ShipEntity rescaleBy:]` (7775) | `ShipEntity::rescaleBy(factor)` Core/Entities/ShipEntity.cpp:8449 | ✅ |
| `-[ShipEntity rescaleBy:writeToCache:]` (7780) | `ShipEntity::rescaleBy(factor, writeToCache)` Core/Entities/ShipEntity.cpp:8451 | ✅ |
| `-[ShipEntity releaseCargoPodsDebris]` (7814) | `ShipEntity::releaseCargoPodsDebris` Core/Entities/ShipEntity.cpp:8489 | ❌ |
| `-[ShipEntity setIsWreckage:]` (7881) | `ShipEntity::setIsWreckage` Core/Entities/ShipEntity.cpp:8570 | ✅ |
| `-[ShipEntity showDamage]` (7886) | `ShipEntity::showDamage` Core/Entities/ShipEntity.cpp:8572 | ✅ |
| `-[ShipEntity becomeExplosion]` (7891) | `ShipEntity::becomeExplosion` Core/Entities/ShipEntity.cpp:8574 | ❌ |
| `-[ShipEntity becomeEnergyBlast]` (8146) | `ShipEntity::becomeEnergyBlast` Core/Entities/ShipEntity.cpp:8914 | ✅ |
| `-[ShipEntity broadcastEnergyBlastImminent]` (8155) | `ShipEntity::broadcastEnergyBlastImminent` Core/Entities/ShipEntity.cpp:8924 | ✅ |
| `-[ShipEntity removeExhaust:]` (8173) | `ShipEntity::removeExhaust` Core/Entities/ShipEntity.cpp:8947 | ✅ |
| `-[ShipEntity removeFlasher:]` (8179) | `ShipEntity::removeFlasher` Core/Entities/ShipEntity.cpp:8956 | ✅ |
| `-[ShipEntity subEntityDied:]` (8185) | `ShipEntity::subEntityDied` Core/Entities/ShipEntity.cpp:8962 | ✅ |
| `-[ShipEntity subEntityReallyDied:]` (8197) | `ShipEntity::subEntityReallyDied` Core/Entities/ShipEntity.cpp:8975 | ✅ |
| `-[ShipEntity positionOffsetForAlignment:]` (8210) | `ShipEntity::positionOffsetForAlignment` Core/Entities/ShipEntity.cpp:8992 | ✅ |
| `positionOffsetForShipInRotationToAlignment` (8253) | `positionOffsetForShipInRotationToAlignment` Core/Entities/ShipEntity.cpp:483 | ✅ |
| `-[ShipEntity becomeLargeExplosion:]` (8300) | `ShipEntity::becomeLargeExplosion` Core/Entities/ShipEntity.cpp:9035 | ✅ |
| `-[ShipEntity collectBountyFor:]` (8338) | `ShipEntity::collectBountyFor` Core/Entities/ShipEntity.cpp:9076 | ✅ |
| `-[ShipEntity compareBeaconCodeWith:]` (8346) | `ShipEntity::compareBeaconCodeWith` Core/Entities/ShipEntity.cpp:9084 | ❌ |
| `-[ShipEntity weaponRecoveryTime]` (8352) | `ShipEntity::weaponRecoveryTime` Core/Entities/ShipEntity.cpp:9091 | ✅ |
| `-[ShipEntity laserHeatLevel]` (8358) | `ShipEntity::laserHeatLevel` Core/Entities/ShipEntity.cpp:9096 | ✅ |
| `-[ShipEntity laserHeatLevelAft]` (8364) | `ShipEntity::laserHeatLevelAft` Core/Entities/ShipEntity.cpp:9101 | ✅ |
| `-[ShipEntity laserHeatLevelForward]` (8370) | `ShipEntity::laserHeatLevelForward` Core/Entities/ShipEntity.cpp:9106 | ✅ |
| `-[ShipEntity laserHeatLevelPort]` (8387) | `ShipEntity::laserHeatLevelPort` Core/Entities/ShipEntity.cpp:9122 | ✅ |
| `-[ShipEntity laserHeatLevelStarboard]` (8393) | `ShipEntity::laserHeatLevelStarboard` Core/Entities/ShipEntity.cpp:9127 | ✅ |
| `-[ShipEntity hullHeatLevel]` (8399) | `ShipEntity::hullHeatLevel` Core/Entities/ShipEntity.cpp:9132 | ✅ |
| `-[ShipEntity entityPersonality]` (8405) | `ShipEntity::entityPersonality` Core/Entities/ShipEntity.cpp:9138 | ✅ |
| `-[ShipEntity entityPersonalityInt]` (8410) | `ShipEntity::entityPersonalityInt` Core/Entities/ShipEntity.cpp:9142 | ✅ |
| `-[ShipEntity randomSeedForShaders]` (8415) | `ShipEntity::randomSeedForShaders` Core/Entities/ShipEntity.cpp:9144 | ✅ |
| `-[ShipEntity setEntityPersonalityInt:]` (8420) | `ShipEntity::setEntityPersonalityInt` Core/Entities/ShipEntity.cpp:9148 | ✅ |
| `-[ShipEntity setSuppressExplosion:]` (8428) | `ShipEntity::setSuppressExplosion` Core/Entities/ShipEntity.cpp:9155 | ✅ |
| `-[ShipEntity resetExhaustPlumes]` (8433) | `ShipEntity::resetExhaustPlumes` Core/Entities/ShipEntity.cpp:9159 | ✅ |
| `-[ShipEntity checkScanner]` (8448) | `ShipEntity::checkScanner` Core/Entities/ShipEntity.cpp:9173 | ✅ |
| `-[ShipEntity checkScannerIgnoringUnpowered]` (8486) | `ShipEntity::checkScannerIgnoringUnpowered` Core/Entities/ShipEntity.cpp:9219 | ✅ |
| `-[ShipEntity scannedShips]` (8528) | `ShipEntity::scannedShips` Core/Entities/ShipEntity.cpp:9276 | ✅ |
| `-[ShipEntity numberOfScannedShips]` (8534) | `ShipEntity::numberOfScannedShips` Core/Entities/ShipEntity.cpp:9281 | ✅ |
| `-[ShipEntity foundTarget]` (8539) | `ShipEntity::foundTarget` Core/Entities/ShipEntity.cpp:9285 | ✅ |
| `-[ShipEntity setFoundTarget:]` (8549) | `ShipEntity::setFoundTarget` Core/Entities/ShipEntity.cpp:9294 | ✅ |
| `-[ShipEntity primaryAggressor]` (8555) | `ShipEntity::primaryAggressor` Core/Entities/ShipEntity.cpp:9300 | ✅ |
| `-[ShipEntity setPrimaryAggressor:]` (8565) | `ShipEntity::setPrimaryAggressor` Core/Entities/ShipEntity.cpp:9309 | ✅ |
| `-[ShipEntity lastEscortTarget]` (8571) | `ShipEntity::lastEscortTarget` Core/Entities/ShipEntity.cpp:9315 | ✅ |
| `-[ShipEntity setLastEscortTarget:]` (8581) | `ShipEntity::setLastEscortTarget` Core/Entities/ShipEntity.cpp:9324 | ✅ |
| `-[ShipEntity thankedShip]` (8587) | `ShipEntity::thankedShip` Core/Entities/ShipEntity.cpp:9333 | ✅ |
| `-[ShipEntity setThankedShip:]` (8597) | `ShipEntity::setThankedShip` Core/Entities/ShipEntity.cpp:9342 | ✅ |
| `-[ShipEntity rememberedShip]` (8603) | `ShipEntity::rememberedShip` Core/Entities/ShipEntity.cpp:9348 | ✅ |
| `-[ShipEntity setRememberedShip:]` (8613) | `ShipEntity::setRememberedShip` Core/Entities/ShipEntity.cpp:9357 | ✅ |
| `-[ShipEntity targetStation]` (8619) | `ShipEntity::targetStation` Core/Entities/ShipEntity.cpp:9363 | ✅ |
| `-[ShipEntity setTargetStation:]` (8629) | `ShipEntity::setTargetStation` Core/Entities/ShipEntity.cpp:9372 | ✅ |
| `-[ShipEntity isValidTarget:]` (8638) | `ShipEntity::isValidTarget` Core/Entities/ShipEntity.cpp:9381 | ✅ |
| `-[ShipEntity addTarget:]` (8658) | `ShipEntity::addTarget` Core/Entities/ShipEntity.cpp:9404 | ✅ |
| `-[ShipEntity removeTarget:]` (8673) | `ShipEntity::removeTarget` Core/Entities/ShipEntity.cpp:9420 | ✅ |
| `-[ShipEntity canStillTrackPrimaryTarget]` (8696) | `ShipEntity::canStillTrackPrimaryTarget` Core/Entities/ShipEntity.cpp:9446 | ✅ |
| `-[ShipEntity primaryTarget]` (8718) | `ShipEntity::primaryTarget` Core/Entities/ShipEntity.cpp:9470 | ✅ |
| `-[ShipEntity primaryTargetWithoutValidityCheck]` (8737) | `ShipEntity::primaryTargetWithoutValidityCheck` Core/Entities/ShipEntity.cpp:9488 | ✅ |
| `-[ShipEntity isFriendlyTo:]` (8748) | `ShipEntity::isFriendlyTo` Core/Entities/ShipEntity.cpp:9498 | ✅ |
| `-[ShipEntity shipHitByLaser]` (8761) | `ShipEntity::shipHitByLaser` Core/Entities/ShipEntity.cpp:9521 | ✅ |
| `-[ShipEntity setShipHitByLaser:]` (8766) | `ShipEntity::setShipHitByLaser` Core/Entities/ShipEntity.cpp:9525 | ✅ |
| `-[ShipEntity noteLostTarget]` (8774) | `ShipEntity::noteLostTarget` Core/Entities/ShipEntity.cpp:9531 | ✅ |
| `-[ShipEntity noteLostTargetAndGoIdle]` (8799) | `ShipEntity::noteLostTargetAndGoIdle` Core/Entities/ShipEntity.cpp:9558 | ✅ |
| `-[ShipEntity noteTargetDestroyed:]` (8806) | `ShipEntity::noteTargetDestroyed` Core/Entities/ShipEntity.cpp:9564 | ✅ |
| `-[ShipEntity behaviour]` (8821) | `ShipEntity::getBehaviour` Core/Entities/ShipEntity.cpp:9578 | ✅ |
| `-[ShipEntity setBehaviour:]` (8826) | `ShipEntity::setBehaviour` Core/Entities/ShipEntity.cpp:9580 | ✅ |
| `-[ShipEntity destination]` (8834) | `ShipEntity::destination` Core/Entities/ShipEntity.cpp:9587 | ✅ |
| `-[ShipEntity coordinates]` (8839) | `ShipEntity::getCoordinates` Core/Entities/ShipEntity.cpp:9589 | ✅ |
| `-[ShipEntity setCoordinate:]` (8844) | `ShipEntity::setCoordinate` Core/Entities/ShipEntity.cpp:9591 | ✅ |
| `-[ShipEntity distance_six:]` (8849) | `ShipEntity::distance_six` Core/Entities/ShipEntity.cpp:9593 | ✅ |
| `-[ShipEntity distance_twelve:withOffset:]` (8858) | `ShipEntity::distance_twelve` Core/Entities/ShipEntity.cpp:9601 | ✅ |
| `-[ShipEntity trackOntoTarget:withDForward:]` (8870) | `ShipEntity::trackOntoTarget` Core/Entities/ShipEntity.cpp:9612 | ✅ |
| `-[ShipEntity ballTrackLeadingTarget:atTarget:]` (8907) | `ShipEntity::ballTrackLeadingTarget` Core/Entities/ShipEntity.cpp:9646 | ✅ |
| `-[ShipEntity setEvasiveJink:]` (8980) | `ShipEntity::setEvasiveJink` Core/Entities/ShipEntity.cpp:9726 | ✅ |
| `-[ShipEntity evasiveAction:]` (9003) | `ShipEntity::evasiveAction` Core/Entities/ShipEntity.cpp:9748 | ❌ |
| `-[ShipEntity trackPrimaryTarget:retreat:]` (9034) | `ShipEntity::trackPrimaryTarget` Core/Entities/ShipEntity.cpp:9779 | ✅ |
| `-[ShipEntity trackSideTarget:leftside:]` (9246) | `ShipEntity::trackSideTarget` Core/Entities/ShipEntity.cpp:10006 | ✅ |
| `-[ShipEntity missileTrackPrimaryTarget:]` (9356) | `ShipEntity::missileTrackPrimaryTarget` Core/Entities/ShipEntity.cpp:10122 | ✅ |
| `-[ShipEntity trackDestination:retreat:]` (9450) | `ShipEntity::trackDestination` Core/Entities/ShipEntity.cpp:10220 | ✅ |
| `-[ShipEntity rollToMatchUp:rotating:]` (9593) | `ShipEntity::rollToMatchUp` Core/Entities/ShipEntity.cpp:10385 | ✅ |
| `-[ShipEntity rangeToDestination]` (9617) | `ShipEntity::rangeToDestination` Core/Entities/ShipEntity.cpp:10412 | ✅ |
| `-[ShipEntity collisionExceptions]` (9622) | `ShipEntity::collisionExceptions` Core/Entities/ShipEntity.cpp:10416 | ✅ |
| `-[ShipEntity addCollisionException:]` (9630) | `ShipEntity::addCollisionException` Core/Entities/ShipEntity.cpp:10424 | ✅ |
| `-[ShipEntity removeCollisionException:]` (9639) | `ShipEntity::removeCollisionException` Core/Entities/ShipEntity.cpp:10429 | ✅ |
| `-[ShipEntity collisionExceptedFor:]` (9646) | `ShipEntity::collisionExceptedFor` Core/Entities/ShipEntity.cpp:10433 | ✅ |
| `-[ShipEntity defenseTargetCount]` (9654) | `ShipEntity::defenseTargetCount` Core/Entities/ShipEntity.cpp:10437 | ✅ |
| `-[ShipEntity allDefenseTargets]` (9659) | `ShipEntity::allDefenseTargets` Core/Entities/ShipEntity.cpp:10439 | ✅ |
| `-[ShipEntity defenseTargetEnumerator]` (9664) | `ShipEntity::defenseTargets` Core/Entities/ShipEntity.cpp:10446 | ✅ |
| `-[ShipEntity addDefenseTarget:]` (9669) | `ShipEntity::addDefenseTarget` Core/Entities/ShipEntity.cpp:10455 | ✅ |
| `-[ShipEntity validateDefenseTargets]` (9687) | `ShipEntity::validateDefenseTargets` Core/Entities/ShipEntity.cpp:10468 | ✅ |
| `-[ShipEntity isDefenseTarget:]` (9702) | `ShipEntity::isDefenseTarget` Core/Entities/ShipEntity.cpp:10479 | ✅ |
| `-[ShipEntity removeAllDefenseTargets]` (9708) | `ShipEntity::removeAllDefenseTargets` Core/Entities/ShipEntity.cpp:10484 | ✅ |
| `-[ShipEntity removeDefenseTarget:]` (9713) | `ShipEntity::removeDefenseTarget` Core/Entities/ShipEntity.cpp:10486 | ✅ |
| `-[ShipEntity rangeToPrimaryTarget]` (9718) | `ShipEntity::rangeToPrimaryTarget` Core/Entities/ShipEntity.cpp:10490 | ✅ |
| `-[ShipEntity rangeToSecondaryTarget:]` (9723) | `ShipEntity::rangeToSecondaryTarget` Core/Entities/ShipEntity.cpp:10494 | ✅ |
| `-[ShipEntity approachAspectToPrimaryTarget]` (9736) | `ShipEntity::approachAspectToPrimaryTarget` Core/Entities/ShipEntity.cpp:10506 | ✅ |
| `-[ShipEntity hasProximityAlertIgnoringTarget:]` (9751) | `ShipEntity::hasProximityAlertIgnoringTarget` Core/Entities/ShipEntity.cpp:10520 | ✅ |
| `-[ShipEntity currentAimTolerance]` (9761) | `ShipEntity::currentAimTolerance` Core/Entities/ShipEntity.cpp:10533 | ✅ |
| `-[ShipEntity lookingAtSunWithThresholdAngleCos:]` (9813) | `ShipEntity::lookingAtSunWithThresholdAngleCos` Core/Entities/ShipEntity.cpp:10597 | ✅ |
| `-[ShipEntity onTarget:withWeapon:]` (9851) | `ShipEntity::onTarget` Core/Entities/ShipEntity.cpp:10637 | ✅ |
| `-[ShipEntity fireWeapon:direction:range:]` (9912) | `ShipEntity::fireWeapon` Core/Entities/ShipEntity.cpp:10701 | ✅ |
| `-[ShipEntity fireMainWeapon:]` (10009) | `ShipEntity::fireMainWeapon` Core/Entities/ShipEntity.cpp:10798 | ✅ |
| `-[ShipEntity fireAftWeapon:]` (10048) | `ShipEntity::fireAftWeapon` Core/Entities/ShipEntity.cpp:10840 | ✅ |
| `-[ShipEntity firePortWeapon:]` (10057) | `ShipEntity::firePortWeapon` Core/Entities/ShipEntity.cpp:10848 | ✅ |
| `-[ShipEntity fireStarboardWeapon:]` (10066) | `ShipEntity::fireStarboardWeapon` Core/Entities/ShipEntity.cpp:10856 | ✅ |
| `-[ShipEntity shotTime]` (10075) | `ShipEntity::shotTime` Core/Entities/ShipEntity.cpp:10864 | ✅ |
| `-[ShipEntity resetShotTime]` (10080) | `ShipEntity::resetShotTime` Core/Entities/ShipEntity.cpp:10866 | ✅ |
| `-[ShipEntity fireTurretCannon:]` (10085) | `ShipEntity::fireTurretCannon` Core/Entities/ShipEntity.cpp:10868 | ✅ |
| `-[ShipEntity setLaserColor:]` (10136) | `ShipEntity::setLaserColor` Core/Entities/ShipEntity.cpp:10925 | ✅ |
| `-[ShipEntity setExhaustEmissiveColor:]` (10144) | `ShipEntity::setExhaustEmissiveColor` Core/Entities/ShipEntity.cpp:10931 | ✅ |
| `-[ShipEntity laserColor]` (10152) | `ShipEntity::laserColor` Core/Entities/ShipEntity.cpp:10937 | ✅ |
| `-[ShipEntity exhaustEmissiveColor]` (10157) | `ShipEntity::exhaustEmissiveColor` Core/Entities/ShipEntity.cpp:10939 | ✅ |
| `-[ShipEntity fireSubentityLaserShot:]` (10162) | `ShipEntity::fireSubentityLaserShot` Core/Entities/ShipEntity.cpp:10946 | ✅ |
| `-[ShipEntity fireDirectLaserShot:]` (10245) | `ShipEntity::fireDirectLaserShot` Core/Entities/ShipEntity.cpp:11063 | ✅ |
| `-[ShipEntity fireDirectLaserDefensiveShot]` (10257) | `ShipEntity::fireDirectLaserDefensiveShot` Core/Entities/ShipEntity.cpp:11072 | ✅ |
| `-[ShipEntity fireDirectLaserShotAt:]` (10277) | `ShipEntity::fireDirectLaserShotAt` Core/Entities/ShipEntity.cpp:11093 | ✅ |
| `-[ShipEntity laserPortOffset:]` (10336) | `ShipEntity::laserPortOffset` Core/Entities/ShipEntity.cpp:11180 | ✅ |
| `-[ShipEntity fireLaserShotInDirection:weaponIdentifier:]` (10360) | `ShipEntity::fireLaserShotInDirection` Core/Entities/ShipEntity.cpp:11203 | ✅ |
| `-[ShipEntity adjustMissedShots:]` (10468) | `ShipEntity::adjustMissedShots` Core/Entities/ShipEntity.cpp:11335 | ✅ |
| `-[ShipEntity missedShots]` (10480) | `ShipEntity::missedShots` Core/Entities/ShipEntity.cpp:11347 | ✅ |
| `-[ShipEntity throwSparks]` (10489) | `ShipEntity::throwSparks` Core/Entities/ShipEntity.cpp:11356 | ✅ |
| `-[ShipEntity considerFiringMissile:]` (10521) | `ShipEntity::considerFiringMissile` Core/Entities/ShipEntity.cpp:11387 | ✅ |
| `-[ShipEntity missileLaunchPosition]` (10534) | `ShipEntity::missileLaunchPosition` Core/Entities/ShipEntity.cpp:11398 | ✅ |
| `-[ShipEntity fireMissile]` (10558) | `ShipEntity::fireMissile` Core/Entities/ShipEntity.cpp:11426 | ✅ |
| `-[ShipEntity fireMissileWithIdentifier:andTarget:]` (10563) | `ShipEntity::fireMissileWithIdentifier` Core/Entities/ShipEntity.cpp:11433 | ✅ |
| `-[ShipEntity isMissileFlagSet]` (10693) | `ShipEntity::isMissileFlagSet` Core/Entities/ShipEntity.cpp:11597 | ✅ |
| `-[ShipEntity setIsMissileFlag:]` (10698) | `ShipEntity::setIsMissileFlag` Core/Entities/ShipEntity.cpp:11602 | ✅ |
| `-[ShipEntity missileLoadTime]` (10703) | `ShipEntity::missileLoadTime` Core/Entities/ShipEntity.cpp:11607 | ✅ |
| `-[ShipEntity setMissileLoadTime:]` (10708) | `ShipEntity::setMissileLoadTime` Core/Entities/ShipEntity.cpp:11609 | ✅ |
| `-[ShipEntity noticeECM]` (10714) | `ShipEntity::noticeECM` Core/Entities/ShipEntity.cpp:11614 | ✅ |
| `-[ShipEntity fireECM]` (10724) | `ShipEntity::fireECM` Core/Entities/ShipEntity.cpp:11630 | ✅ |
| `-[ShipEntity activateCloakingDevice]` (10735) | `ShipEntity::activateCloakingDevice` Core/Entities/ShipEntity.cpp:11638 | ✅ |
| `-[ShipEntity deactivateCloakingDevice]` (10747) | `ShipEntity::deactivateCloakingDevice` Core/Entities/ShipEntity.cpp:11649 | ✅ |
| `-[ShipEntity launchCascadeMine]` (10755) | `ShipEntity::launchCascadeMine` Core/Entities/ShipEntity.cpp:11656 | ✅ |
| `-[ShipEntity launchEscapeCapsule]` (10808) | `ShipEntity::launchEscapeCapsule` Core/Entities/ShipEntity.cpp:11712 | ❌ |
| `-[ShipEntity dumpCargo]` (10856) | `ShipEntity::dumpCargo` Core/Entities/ShipEntity.cpp:11765 | ⚠️ |
| `-[ShipEntity dumpCargoItem:]` (10866) | `ShipEntity::dumpCargoItem` Core/Entities/ShipEntity.cpp:11767 | ✅ |
| `-[ShipEntity dumpItem:]` (10907) | `ShipEntity::dumpItem` Core/Entities/ShipEntity.cpp:11815 | ✅ |
| `-[ShipEntity manageCollisions]` (10991) | `ShipEntity::manageCollisions` Core/Entities/ShipEntity.cpp:11926 | ✅ |
| `-[ShipEntity collideWithShip:]` (11020) | `ShipEntity::collideWithShip` Core/Entities/ShipEntity.cpp:11958 | ✅ |
| `-[ShipEntity thrustVector]` (11158) | `ShipEntity::thrustVector` Core/Entities/ShipEntity.cpp:12115 | ✅ |
| `-[ShipEntity velocity]` (11163) | `ShipEntity::getVelocity` Core/Entities/ShipEntity.cpp:12119 | ✅ |
| `-[ShipEntity setTotalVelocity:]` (11168) | `ShipEntity::setTotalVelocity` Core/Entities/ShipEntity.cpp:12124 | ✅ |
| `-[ShipEntity adjustVelocity:]` (11173) | `ShipEntity::adjustVelocity` Core/Entities/ShipEntity.cpp:12128 | ✅ |
| `-[ShipEntity addImpactMoment:fraction:]` (11178) | `ShipEntity::addImpactMoment` Core/Entities/ShipEntity.cpp:12132 | ✅ |
| `-[ShipEntity canScoop:]` (11183) | `ShipEntity::canScoop` Core/Entities/ShipEntity.cpp:12137 | ✅ |
| `-[ShipEntity getTractoredBy:]` (11211) | `ShipEntity::getTractoredBy` Core/Entities/ShipEntity.cpp:12163 | ✅ |
| `-[ShipEntity scoopIn:]` (11235) | `ShipEntity::scoopIn` Core/Entities/ShipEntity.cpp:12188 | ✅ |
| `-[ShipEntity suppressTargetLost]` (11240) | `ShipEntity::suppressTargetLost` Core/Entities/ShipEntity.cpp:12192 | ✅ |
| `-[ShipEntity scoopUp:]` (11244) | `ShipEntity::scoopUp` Core/Entities/ShipEntity.cpp:12194 | ✅ |
| `-[ShipEntity scoopUpProcess:processEvents:processMessages:]` (11249) | `ShipEntity::scoopUpProcess` Core/Entities/ShipEntity.cpp:12198 | ✅ |
| `-[ShipEntity cascadeIfAppropriateWithDamageAmount:cascadeOwner:]` (11381) | `ShipEntity::cascadeIfAppropriateWithDamageAmount` Core/Entities/ShipEntity.cpp:12390 | ✅ |
| `-[ShipEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (11418) | `ShipEntity::takeEnergyDamage` Core/Entities/ShipEntity.cpp:12432 | ✅ |
| `-[ShipEntity abandonShip]` (11576) | `ShipEntity::abandonShip` Core/Entities/ShipEntity.cpp:12621 | ✅ |
| `-[ShipEntity takeScrapeDamage:from:]` (11641) | `ShipEntity::takeScrapeDamage` Core/Entities/ShipEntity.cpp:12697 | ✅ |
| `-[ShipEntity takeHeatDamage:]` (11678) | `ShipEntity::takeHeatDamage` Core/Entities/ShipEntity.cpp:12735 | ✅ |
| `-[ShipEntity enterDock:]` (11706) | `ShipEntity::enterDock` Core/Entities/ShipEntity.cpp:12761 | ✅ |
| `-[ShipEntity leaveDock:]` (11721) | `ShipEntity::leaveDock` Core/Entities/ShipEntity.cpp:12772 | ✅ |
| `-[ShipEntity enterWormhole:]` (11730) | `ShipEntity::enterWormhole(w_hole)` Core/Entities/ShipEntity.cpp:12780 | ✅ |
| `-[ShipEntity enterWormhole:replacing:]` (11735) | `ShipEntity::enterWormhole(w_hole, replacing)` Core/Entities/ShipEntity.cpp:12784 | ✅ |
| `-[ShipEntity enterWitchspace]` (11765) | `ShipEntity::enterWitchspace` Core/Entities/ShipEntity.cpp:12817 | ✅ |
| `-[ShipEntity leaveWitchspace]` (11778) | `ShipEntity::leaveWitchspace` Core/Entities/ShipEntity.cpp:12832 | ✅ |
| `-[ShipEntity witchspaceLeavingEffects]` (11800) | `ShipEntity::witchspaceLeavingEffects` Core/Entities/ShipEntity.cpp:12859 | ✅ |
| `-[ShipEntity markAsOffender:]` (11827) | `ShipEntity::markAsOffender(value)` Core/Entities/ShipEntity.cpp:12887 | ✅ |
| `-[ShipEntity markAsOffender:withReason:]` (11832) | `ShipEntity::markAsOffender(value, reason)` Core/Entities/ShipEntity.cpp:12891 | ✅ |
| `-[ShipEntity switchLightsOn]` (11858) | `ShipEntity::switchLightsOn` Core/Entities/ShipEntity.cpp:12923 | ✅ |
| `-[ShipEntity switchLightsOff]` (11874) | `ShipEntity::switchLightsOff` Core/Entities/ShipEntity.cpp:12938 | ✅ |
| `-[ShipEntity lightsActive]` (11889) | `ShipEntity::lightsActive` Core/Entities/ShipEntity.cpp:12952 | ✅ |
| `-[ShipEntity setDestination:]` (11894) | `ShipEntity::setDestination` Core/Entities/ShipEntity.cpp:12954 | ✅ |
| `-[ShipEntity setEscortDestination:]` (11900) | `ShipEntity::setEscortDestination` Core/Entities/ShipEntity.cpp:12959 | ✅ |
| `-[ShipEntity canAcceptEscort:]` (11905) | `ShipEntity::canAcceptEscort` Core/Entities/ShipEntity.cpp:12963 | ✅ |
| `-[ShipEntity acceptAsEscort:]` (11926) | `ShipEntity::acceptAsEscort` Core/Entities/ShipEntity.cpp:12991 | ✅ |
| `-[ShipEntity updateEscortFormation]` (11986) | `ShipEntity::updateEscortFormation` Core/Entities/ShipEntity.cpp:13069 | ✅ |
| `-[ShipEntity refreshEscortPositions]` (11996) | `ShipEntity::refreshEscortPositions` Core/Entities/ShipEntity.cpp:13076 | ✅ |
| `-[ShipEntity coordinatesForEscortPosition:]` (12029) | `ShipEntity::coordinatesForEscortPosition` Core/Entities/ShipEntity.cpp:13108 | ✅ |
| `-[ShipEntity deployEscorts]` (12047) | `ShipEntity::deployEscorts` Core/Entities/ShipEntity.cpp:13130 | ❌ |
| `-[ShipEntity dockEscorts]` (12104) | `ShipEntity::dockEscorts` Core/Entities/ShipEntity.cpp:13191 | ✅ |
| `-[ShipEntity setTargetToNearestStationIncludingHostiles:]` (12138) | `ShipEntity::setTargetToNearestStationIncludingHostiles` Core/Entities/ShipEntity.cpp:13231 | ✅ |
| `-[ShipEntity setTargetToNearestFriendlyStation]` (12182) | `ShipEntity::setTargetToNearestFriendlyStation` Core/Entities/ShipEntity.cpp:13280 | ✅ |
| `-[ShipEntity setTargetToNearestStation]` (12188) | `ShipEntity::setTargetToNearestStation` Core/Entities/ShipEntity.cpp:13285 | ✅ |
| `-[ShipEntity setTargetToSystemStation]` (12194) | `ShipEntity::setTargetToSystemStation` Core/Entities/ShipEntity.cpp:13290 | ✅ |
| `-[ShipEntity landOnPlanet:]` (12219) | `ShipEntity::landOnPlanet` Core/Entities/ShipEntity.cpp:13318 | ✅ |
| `-[ShipEntity abortDocking]` (12236) | `ShipEntity::abortDocking` Core/Entities/ShipEntity.cpp:13335 | ✅ |
| `-[ShipEntity dockingInstructions]` (12246) | `ShipEntity::getDockingInstructions` Core/Entities/ShipEntity.cpp:13346 | ✅ |
| `-[ShipEntity broadcastThargoidDestroyed]` (12251) | `ShipEntity::broadcastThargoidDestroyed` Core/Entities/ShipEntity.cpp:13348 | ✅ |
| `AuthorityPredicate` (12261) | `AuthorityPredicate` (+ `AuthorityPredicateParameter`) Core/Entities/ShipEntity.cpp:547 | ✅ |
| `-[ShipEntity broadcastHitByLaserFrom:]` (12279) | `ShipEntity::broadcastHitByLaserFrom` Core/Entities/ShipEntity.cpp:13361 | ✅ |
| `-[ShipEntity sendMessage:toShip:withUnpilotedOverride:]` (12306) | `ShipEntity::sendMessage` Core/Entities/ShipEntity.cpp:13394 | ✅ |
| `-[ShipEntity sendExpandedMessage:toShip:]` (12328) | `ShipEntity::sendExpandedMessage` Core/Entities/ShipEntity.cpp:13417 | ✅ |
| `-[ShipEntity broadcastAIMessage:]` (12361) | `ShipEntity::broadcastAIMessage` Core/Entities/ShipEntity.cpp:13462 | ✅ |
| `-[ShipEntity broadcastMessage:withUnpilotedOverride:]` (12373) | `ShipEntity::broadcastMessage` Core/Entities/ShipEntity.cpp:13474 | ✅ |
| `-[ShipEntity setCommsMessageColor]` (12399) | `ShipEntity::setCommsMessageColor` Core/Entities/ShipEntity.cpp:13506 | ✅ |
| `-[ShipEntity receiveCommsMessage:from:]` (12409) | `ShipEntity::receiveCommsMessage` Core/Entities/ShipEntity.cpp:13516 | ✅ |
| `-[ShipEntity commsMessage:withUnpilotedOverride:]` (12415) | `ShipEntity::commsMessage` Core/Entities/ShipEntity.cpp:13523 | ✅ |
| `-[ShipEntity markedForFines]` (12429) | `ShipEntity::markedForFines` Core/Entities/ShipEntity.cpp:13537 | ✅ |
| `-[ShipEntity markForFines]` (12434) | `ShipEntity::markForFines` Core/Entities/ShipEntity.cpp:13539 | ✅ |
| `-[ShipEntity isMining]` (12442) | `ShipEntity::isMining` Core/Entities/ShipEntity.cpp:13545 | ✅ |
| `-[ShipEntity interpretAIMessage:]` (12447) | `ShipEntity::interpretAIMessage` Core/Entities/ShipEntity.cpp:13552 | ✅ |
| `-[ShipEntity findBoundingBoxRelativeTo:i:j:k:]` (12471) | `ShipEntity::findBoundingBoxRelativeTo` Core/Entities/ShipEntity.cpp:13589 | ✅ |
| `-[ShipEntity spawn:]` (12478) | `ShipEntity::spawn` Core/Entities/ShipEntity.cpp:13596 | ✅ |
| `-[ShipEntity checkShipsInVicinityForWitchJumpExit]` (12498) | `ShipEntity::checkShipsInVicinityForWitchJumpExit` Core/Entities/ShipEntity.cpp:13616 | ✅ |
| `-[ShipEntity trackCloseContacts]` (12538) | `ShipEntity::getTrackCloseContacts` Core/Entities/ShipEntity.cpp:13661 | ✅ |
| `-[ShipEntity setTrackCloseContacts:]` (12543) | `ShipEntity::setTrackCloseContacts` Core/Entities/ShipEntity.cpp:13663 | ✅ |
| `-[ShipEntity claimAsSalvage]` (12560) | none (`OO_SALVAGE_SUPPORT` block deleted from the port; compiled out upstream) | ➖ |
| `-[ShipEntity sendCoordinatesToPilot]` (12588) | none (`OO_SALVAGE_SUPPORT` block deleted from the port; compiled out upstream) | ➖ |
| `-[ShipEntity pilotArrived]` (12629) | none (`OO_SALVAGE_SUPPORT` block deleted from the port; compiled out upstream) | ➖ |
| `-[ShipEntity dumpSelfState]` (12637) | `ShipEntity::dumpSelfState` Core/Entities/ShipEntity.cpp:13691 | ✅ |
| `-[ShipEntity script]` (12714) | `ShipEntity::getScript` Core/Entities/ShipEntity.cpp:13782 | ✅ |
| `-[ShipEntity scriptInfo]` (12719) | `ShipEntity::getScriptInfo` Core/Entities/ShipEntity.cpp:13784 | ✅ |
| `-[ShipEntity overrideScriptInfo:]` (12724) | `ShipEntity::overrideScriptInfo` Core/Entities/ShipEntity.cpp:13789 | ✅ |
| `-[ShipEntity entityForShaderProperties]` (12736) | `ShipEntity::entityForShaderProperties` Core/Entities/ShipEntity.cpp:13802 | ✅ |
| `-[ShipEntity setDemoShip:]` (12741) | `ShipEntity::setDemoShip` Core/Entities/ShipEntity.cpp:13804 | ✅ |
| `-[ShipEntity isDemoShip]` (12750) | `ShipEntity::getIsDemoShip` Core/Entities/ShipEntity.cpp:13812 | ✅ |
| `-[ShipEntity setDemoStartTime:]` (12755) | `ShipEntity::setDemoStartTime` Core/Entities/ShipEntity.cpp:13814 | ✅ |
| `-[ShipEntity getDemoStartTime]` (12760) | `ShipEntity::getDemoStartTime` Core/Entities/ShipEntity.cpp:13816 | ✅ |
| `-[ShipEntity doScriptEvent:]` (12766) | `ShipEntity::doScriptEvent(message)` Core/Entities/ShipEntity.cpp:13819 | ✅ |
| `-[ShipEntity doScriptEvent:withArgument:]` (12773) | `ShipEntity::doScriptEvent(message, Entity*)` Core/Entities/ShipEntity.cpp:13828 | ⚠️ |
| `-[ShipEntity doScriptEvent:withArgument:andArgument:]` (12784) | `ShipEntity::doScriptEvent(message, Entity*, Entity*)` Core/Entities/ShipEntity.cpp:13838 | ⚠️ |
| `-[ShipEntity doScriptEvent:withArguments:]` (12798) | `ShipEntity::doScriptEvent(message, vector<PList>)` Core/Entities/ShipEntity.cpp:13851 | ✅ |
| `-[ShipEntity doScriptEvent:withArguments:count:]` (12830) | `ShipEntity::doScriptEvent(message, argv, argc)` Core/Entities/ShipEntity.cpp:13870 | ✅ |
| `-[ShipEntity doScriptEvent:inContext:withArguments:count:]` (12837) | `ShipEntity::doScriptEvent(message, context, argv, argc)` Core/Entities/ShipEntity.cpp:13876 | ✅ |
| `-[ShipEntity reactToAIMessage:context:]` (12844) | `ShipEntity::reactToAIMessage` Core/Entities/ShipEntity.cpp:13885 | ✅ |
| `-[ShipEntity sendAIMessage:]` (12849) | `ShipEntity::sendAIMessage` Core/Entities/ShipEntity.cpp:13891 | ✅ |
| `-[ShipEntity doScriptEvent:andReactToAIMessage:]` (12854) | `ShipEntity::doScriptEvent(event, aiMessage)` Core/Entities/ShipEntity.cpp:13895 | ✅ |
| `-[ShipEntity doScriptEvent:withArgument:andReactToAIMessage:]` (12860) | `ShipEntity::doScriptEvent(event, Entity*, aiMessage)` Core/Entities/ShipEntity.cpp:13901 | ✅ |
| `-[ShipEntity alertCondition]` (12868) | `ShipEntity::alertCondition` Core/Entities/ShipEntity.cpp:13909 | ✅ |
| `-[ShipEntity realAlertCondition]` (12879) | `ShipEntity::realAlertCondition` Core/Entities/ShipEntity.cpp:13919 | ✅ |
| `-[ShipEntity doNothing]` (12935) | `ShipEntity::doNothing` Core/Entities/ShipEntity.cpp:13997 | ✅ |
| `-[ShipEntity descriptionForObjDump]` (12940) | `ShipEntity::descriptionForObjDump` Core/Entities/ShipEntity.cpp:14000 | ✅ |
| `-[Entity(SubEntityRelationship) isShipWithSubEntityShip:]` (12955) | none (every caller holds a `ShipEntity*`) | ➖ |
| `-[Entity(SubEntityRelationship) drawSubEntityImmediate:translucent:]` (12960) | `cxx::OOSubEntityInterface` Core/Entities/Entity.h:426; non-adopters skipped at Core/Entities/ShipEntity.cpp:6355 | ➖ |
| `-[ShipEntity(SubEntityRelationship) isShipWithSubEntityShip:]` (12969) | `ShipEntity::isShipWithSubEntityShip` Core/Entities/ShipEntity.cpp:571 | ✅ |
| `OODefaultShipShaderMacros` (12994) | `OODefaultShipShaderMacros` Core/Entities/ShipEntity.cpp:14023 | ✅ |
| `OOUniformBindingPermitted` (13006) | `OOUniformBindingPermitted` Core/Entities/ShipEntity.cpp:14039 | ✅ |
| `getWeaponRangeFromType` (13041) | `getWeaponRangeFromType` Core/Entities/ShipEntity.cpp:14072 | ✅ |
| `isWeaponNone` (13046) | `isWeaponNone` Core/Entities/ShipEntity.cpp:14077 | ✅ |

**Differences:**

- ✅ **high** — (fixed since 2026-10-27) NPC/demo-ship subentity update loops now call `update` on every subentity (flashers and exhaust plumes too), and only the bounding-box step is limited to ships, as upstream. Changed in b5d6be770 ("every subentity, as [se update:] went to each") — upstream `Core/Entities/ShipEntity.m:2113-2114,2382-2383,2469-2470` ↔ port `Core/Entities/ShipEntity.cpp:2569-2580,2893-2897,3000-3011`
- ❌ **low** — (still open) `hasAllEquipment`: early `NO` is "equipment list empty", not "`_equipment == nil`". Re-read: `removeEquipmentItem:` calls `removeAllEquipment` when the list empties (nil again), so the only empty-but-non-nil case upstream is a ship whose first non-missile `addEquipmentItem:` allocated `_equipment` and was then rejected by the equipment_weight > max_cargo check. There upstream still tests each key (missiles, primary weapons with `includeWeapons:YES`); the port returns NO. Narrower than the previous wording — upstream `Core/Entities/ShipEntity.m:2842-2843,3227-3237,3332-3333` ↔ port `Core/Entities/ShipEntity.cpp:3394,3851-3859`
- ❌ **low** — (still open) Random-missile role pick walks the missile ship's roles in `OORoleSet::roles()` order (`std::map`, alphabetical) where upstream walked `[[missile roleSet] roles]` (an `NSSet`, hash order). With several missile/mine roles a different equipment type can be registered and fitted — upstream `Core/Entities/ShipEntity.m:3398` ↔ port `Core/Entities/ShipEntity.cpp:4045-4053` (`Core/OORoleSet.cpp:126`)
- ❌ **low** — (still open) `behaviour_attack_slow_dogfight` reads `target->collision_radius` through `oo::ToShip(primaryTarget())`, null for a non-ship target that `canStillTrackPrimaryTarget` accepts (e.g. a wormhole); upstream read the ivar of any `Entity`. The port dereferences null (crash) — upstream `Core/Entities/ShipEntity.m:3955-3957` ↔ port `Core/Entities/ShipEntity.cpp:4577-4580`
- ❌ **low** — (still open) `behaviour_scripted_ai` given an object that is not a dictionary (e.g. an Array): upstream converts it to `NSArray` and `-objectForKey:` raises; the port's `PList::find` on the array is null, so sticks and speed read 0 and the ship coasts. A `null` return now passes the object test in both (port comment) and reads zeros in both — upstream `Core/Entities/ShipEntity.m:5323-5336` ↔ port `Core/Entities/ShipEntity.cpp:6119-6139`
- ⚠️ **low** — (still open) `update` close-contact pass iterates a `std::map` copy in byte order of the `"%d"` ID text (port comment "ORDER: byte order of the ID text"); upstream used `NSDictionary` hash order, so `shipTraverse*` events/AI messages for several contacts leaving in one frame can fire in a different order — upstream `Core/Entities/ShipEntity.m:2160-2161` ↔ port `Core/Entities/ShipEntity.cpp:2618-2626`
- ⚠️ **low** — (still open) `setUpOneEscort` drops the `escortRole &&` guard before the `auto_ai` fuzzy boolean; the port comment says both callers always pass a role. `randf()` draw order unchanged — upstream `Core/Entities/ShipEntity.m:1743` ↔ port `Core/Entities/ShipEntity.cpp:2211-2216`
- ✅ note (RNG) — Set-up draw order is unchanged: `Ranrot` personality; fuzzy booleans has_ecm, has_scoop, has_escape_pod, has_cloaking_device, [has_energy_bomb only when > 0], has_fuel_injection, has_military_jammer, has_military_scanner_filter, fragment_chance; subentities; has_shield_booster, has_shield_enhancer, no_boulders; `selectMissile` retries (one `randf()` each); accuracy `randf`; unpiloted. Escorts: probe `newShipWithRole`/`newShipWithName`, three `randf` per escort, `Ranrot()%11` per mixed slot, `ranrot_rand()&15` for dirty escorts — port `Core/Entities/ShipEntity.cpp:389,724-762,934-976,1067-1092,1928-1946,2030,2161-2168,2259`
- ✅ note (shipdata) — Keys, defaults and clamps in `setUpFromDictionary`/`setUpShipFromDictionary` match one for one after the enum-class/`std::shared_ptr` refactors (injector factor clamp + logs, max_missiles/QC-mine slot, accuracy −100 sentinel, escorts ≤ MAX_ESCORTS, beacon_label fallback, heat_insulation 2.0 with heat shield, hyperspace_motor=NO → −1) — upstream `Core/Entities/ShipEntity.m:235-722` ↔ port `Core/Entities/ShipEntity.cpp:598-1167`
- ✅ note (lifetime) — `shipWillDealloc` keeps upstream's order (entityDestroyed, contact tracking off, parent `subEntityReallyDied`, `clearSubEntities`, `setSubEntityTakingDamage:nil`, `removeAllEquipment`, group/escort-group `removeShip`); weak refs (beacons, damage subentity, proximity alert, aegis lock, close-contact target swap) are `std::weak_ptr<Entity>` via `oo::share` — port `Core/Entities/ShipEntity.cpp:335-380`
- ✅ subtle — `findNearestPlanetExcludingMoons`: `-sortedArrayUsingFunction:` → `std::stable_sort` on the same comparator; only planets at exactly equal surface distance could come out differently — upstream `Core/Entities/ShipEntity.m:6653` ↔ port `Core/Entities/ShipEntity.cpp:7339-7344`
- ✅ subtle — Raw casts that became `oo::ToShip` (`behaviour_evasive_action`, `behaviour_attack_fly_from_target`, `behaviour_formation_form_up`, `behaviour_intercept_target` collect branch, `update` police check, subentity owner temperature) give 0/null for a non-ship where upstream messaged the entity; not reachable with shipped data (escort/subentity owners are ships; wormholes have zero speed) — port `Core/Entities/ShipEntity.cpp:2610,2765,4440,4625,5493,5748`
- ✅ subtle — `setBeaconCode`/`setBeaconLabel` replace whenever either side is set (upstream compared by pointer, so a new equal string also replaced); the rebuilt beacon icon is identical — upstream `Core/Entities/ShipEntity.m:1415,1437` ↔ port `Core/Entities/ShipEntity.cpp:1781,1799`

- ❌ **low** (still open) — `releaseCargoPodsDebris`: `container->setTemperature(randomEjectaTemperature())` is under `if (container != nullptr)`. ObjC still evaluated `[self randomEjectaTemperature]` (a `bellf(5)` draw) for a nil container, so when `reifyCargoPod` fails the port skips those RNG draws and later debris rolls go out of step — upstream `Core/Entities/ShipEntity.m:7859` ↔ port `Core/Entities/ShipEntity.cpp:8541-8542`
- ❌ **low** (still open) — `becomeExplosion` wreckage loop: `wreck->setVelocity(... randf() * wreck->collisionRadius())` is guarded by `if (wreck != nullptr)`. Upstream drew the `randf()` even for a nil wreck, so a failed `addWreckageFrom` shifts the RNG stream for `n_alloys = randf() * n_alloys` and the alloy spawns — upstream `Core/Entities/ShipEntity.m:8062` ↔ port `Core/Entities/ShipEntity.cpp:8824-8830`
- ❌ **low** (still open) — `compareBeaconCodeWith`: a nil own beacon code made `[nil compare:]` return `NSOrderedSame`; the port compares `""` with the other code (Ascending). No current caller sorts beacon-less ships — upstream `Core/Entities/ShipEntity.m:8348` ↔ port `Core/Entities/ShipEntity.cpp:9084-9088`
- ❌ **low** (still open) — `evasiveAction`: target is `oo::ToShip(primaryTarget())`, so a non-ship primary target (a wormhole) runs `noteLostTargetAndGoIdle` (TARGET_LOST, BEHAVIOUR_IDLE). Upstream cast it to `ShipEntity*`, read garbage `v_right` and kept jinking — upstream `Core/Entities/ShipEntity.m:9008` ↔ port `Core/Entities/ShipEntity.cpp:9752`
- ❌ **low** (still open) — `launchEscapeCapsule`: when `launchPodWithCrew` returns nil for a passenger pod, upstream `[passengers addObject:nil]` raised `NSInvalidArgumentException`; the port pushes a null hold and `shipLaunchedEscapePod` gets an array with a null entry — upstream `Core/Entities/ShipEntity.m:10846` ↔ port `Core/Entities/ShipEntity.cpp:11749`
- ❌ **low** (still open) — `deployEscorts`: `target = oo::ToShip(primaryTarget())`; upstream used the raw primary target. With a non-ship target the escorts get `addTarget(nullptr)` (no-op, they keep their old target) and `escortAttack` with `null` — upstream `Core/Entities/ShipEntity.m:12090` ↔ port `Core/Entities/ShipEntity.cpp:13176`
- ⚠️ **low** (still open) — `deployEscorts` collects idle escorts in escort-group order (`std::vector`) where upstream used an `NSMutableSet` (pointer-hash order), so which `deployCount` escorts attack differs; the port comment says so (no ADR/bead) — upstream `Core/Entities/ShipEntity.m:12073` ↔ port `Core/Entities/ShipEntity.cpp:13132-13133`
- ⚠️ **low** (still open) — `cargoListForScripting`: a pod whose commodity is nil or not a market good is skipped (upstream indexed `quantityInHold[NSNotFound]`, out of bounds); a missing `displayName` is omitted (upstream `setObject:nil` threw). Port comment documents it — upstream `Core/Entities/ShipEntity.m:7249` ↔ port `Core/Entities/ShipEntity.cpp:7934-7941`
- ⚠️ **low** (still open) — `dumpCargo` returns `void`; upstream returned the dumped pod's `commodityType`. Port comment: AIs cannot read it and no caller did (PlayerEntity reads `dumpCargoItem`) — upstream `Core/Entities/ShipEntity.m:10856` ↔ port `Core/Entities/ShipEntity.cpp:11765`
- ⚠️ **low** (still open) — `doScriptEvent:withArgument:` / `…andArgument:` took `id` via `OOJSValueFromNativeObject`; the port overloads take `Entity*` (`OOJSEntityJSValue`), non-entity arguments go through the `std::vector<oo::PList>` overload (`receiveCommsMessage`, `dockEscorts`, `launchEscapeCapsule`). Port comment: the `id` forms had no other callers — upstream `Core/Entities/ShipEntity.m:12773,12784` ↔ port `Core/Entities/ShipEntity.cpp:13828-13849`
- ➖ (changed since 2026-10-27) — `claimAsSalvage` / `sendCoordinatesToPilot` / `pilotArrived`: `OO_SALVAGE_SUPPORT` is undefined upstream, so these were never compiled. The port has now deleted the block entirely (previously it held unconverted ObjC syntax) — upstream `Core/Entities/ShipEntity.m:12558-12634` ↔ port none
- ➖ (still open) — `Entity (SubEntityRelationship)`: the `Entity` default `isShipWithSubEntityShip:` (NO) is gone because callers hold `ShipEntity*`; the no-op `drawSubEntityImmediate:` is replaced by `cxx::OOSubEntityInterface`, and non-adopters are skipped. Same observable behaviour — upstream `Core/Entities/ShipEntity.m:12955-12963` ↔ port `Core/Entities/Entity.h:426`, `Core/Entities/ShipEntity.cpp:6355`
- ✅ subtle (new) — `defenseTargets` / `collisionExceptions` / `allDefenseTargets` iterate `oo::WeakSet` in insertion order (documented in `oofnd/WeakSet.hpp:28-30`); upstream `OOWeakSet` was `NSSet` hash order. This affects which defence target `fireDirectLaserDefensiveShot` fires at first and the order of JS `ship.defenseTargets`, but upstream order was unspecified — upstream `Core/Entities/ShipEntity.m:9622-9716` ↔ port `Core/Entities/ShipEntity.cpp:10416-10488`
- ✅ subtle — `fireSubentityLaserShot` miss branch, `fireLaserShotInDirection` miss branch, `missileTrackPrimaryTarget`, `noteLostTarget` and `dockEscorts` use `oo::ToShip(primaryTarget())` where upstream used the raw entity. For a wormhole target upstream either sent selectors a wormhole doesn't implement or compared non-ships, so the port's skip/no-op is benign (`noteLostTarget` may reset an already-nil `_primaryAggressor`) — port `Core/Entities/ShipEntity.cpp:11031`, `:11290`, `:10125`, `:9534`, `:13195`
- ✅ subtle — `broadcastHitByLaserFrom` reads `[UNIVERSE station]` and `withinStationAegis` once into `AuthorityPredicateParameter` instead of per entity; both are plain reads (`aegis_status == kInDockingRange`), so the selected authorities are the same — upstream `Core/Entities/ShipEntity.m:12261-12301` ↔ port `Core/Entities/ShipEntity.cpp:541-565`, `:13374-13381`
- ✅ subtle — lifetime: `fireMissileWithIdentifier`, `launchCascadeMine`, `becomeExplosion` rocks/plates and `subEntityReallyDied` now use `std::shared_ptr` creators and a deliberately leaked holder (`new std::vector<oo::EntityHold>(...)`) in place of `release`/leaked ivar; the universe still holds each added entity, and `manageCollisions` keeps the player alive with a never-deleted `oo::EntityHold` where upstream did `[self retain]` — port `Core/Entities/ShipEntity.cpp:11433-11595`, `:8986`, `:11946`
- ✅ subtle (still) — `setCommodity` drops the `co_type != nil` guard (std::string parameter); callers unwrap and skip nil. `crewForScripting` returns an empty vector for nil crew; `OOJSShip` checks `getCrew().has_value()` first. `interpretAIMessage` adds a `tokens.size() < 3` early return. `setTrackCloseContacts` clears `closeContactsInfo` rather than nil/alloc — port `Core/Entities/ShipEntity.cpp:7849`, `:7593`, `:13557`, `:13663`
- ✅ checked — `takeEnergyDamage` inlines `SHIP_ENERGY_DAMAGE_TO_HEAT_FACTOR` with the same formula; pirate/police group loops iterate `memberArray()` snapshots as `mutationSafeEnumerator` did, with the same `otherPirate != self && randf() < 0.5` short-circuit. RNG draw order matches in `throwSparks`, `launchCascadeMine`, `dumpItem`, `fireDirectLaserShotAt`, `leaveWitchspace`, `setCargoFlag`, `considerFiringMissile` and `takeScrapeDamage`. Virtual dispatch for every method PlayerEntity/StationEntity override in this range (e.g. `doScriptEvent(…context…)`, `receiveCommsMessage`, `launchEscapeCapsule`, `dumpCargo`, `takeScrapeDamage`, `realAlertCondition`) is preserved in `Core/Entities/ShipEntity.h`

## ShipEntityAI

<a id="shipentityai"></a>
Upstream `src/Core/Entities/ShipEntityAI.m` ↔ `Core/Entities/ShipEntityAI.cpp` (2558 / 2797 lines)

**Status:** done — 156 rows: 154 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[ShipEntity(AI) setAITo:]` (245) | `ShipEntity::setAITo` `Core/Entities/ShipEntityAI.cpp:120` | ✅ |
| `-[ShipEntity(AI) setAIScript:]` (268) | `ShipEntity::setAIScript` `Core/Entities/ShipEntityAI.cpp:145` | ✅ |
| `-[ShipEntity(AI) switchAITo:]` (287) | `ShipEntity::switchAITo` `Core/Entities/ShipEntityAI.cpp:164` | ✅ |
| `-[ShipEntity(AI) scanForHostiles]` (293) | `ShipEntity::scanForHostiles` `Core/Entities/ShipEntityAI.cpp:170` | ✅ |
| `-[ShipEntity(AI) groupAttackTarget]` (315) | `ShipEntity::groupAttackTarget` `Core/Entities/ShipEntityAI.cpp:196` | ✅ |
| `-[ShipEntity(AI) performAttack]` (350) | `ShipEntity::performAttack` `Core/Entities/ShipEntityAI.cpp:251` | ✅ |
| `-[ShipEntity(AI) performCollect]` (359) | `ShipEntity::performCollect` `Core/Entities/ShipEntityAI.cpp:259` | ✅ |
| `-[ShipEntity(AI) performEscort]` (365) | `ShipEntity::performEscort` `Core/Entities/ShipEntityAI.cpp:264` | ✅ |
| `-[ShipEntity(AI) performFaceDestination]` (373) | `ShipEntity::performFaceDestination` `Core/Entities/ShipEntityAI.cpp:271` | ✅ |
| `-[ShipEntity(AI) performFlee]` (379) | `ShipEntity::performFlee` `Core/Entities/ShipEntityAI.cpp:276` | ✅ |
| `-[ShipEntity(AI) performFlyToRangeFromDestination]` (394) | `ShipEntity::performFlyToRangeFromDestination` `Core/Entities/ShipEntityAI.cpp:291` | ✅ |
| `-[ShipEntity(AI) performHold]` (400) | `ShipEntity::performHold` `Core/Entities/ShipEntityAI.cpp:296` | ✅ |
| `-[ShipEntity(AI) performIdle]` (407) | `ShipEntity::performIdle` `Core/Entities/ShipEntityAI.cpp:302` | ✅ |
| `-[ShipEntity(AI) performIntercept]` (413) | `ShipEntity::performIntercept` `Core/Entities/ShipEntityAI.cpp:307` | ✅ |
| `-[ShipEntity(AI) performLandOnPlanet]` (419) | `ShipEntity::performLandOnPlanet` `Core/Entities/ShipEntityAI.cpp:312` | ✅ |
| `-[ShipEntity(AI) performMining]` (434) | `ShipEntity::performMining` `Core/Entities/ShipEntityAI.cpp:327` | ✅ |
| `-[ShipEntity(AI) performScriptedAI]` (446) | `ShipEntity::performScriptedAI` `Core/Entities/ShipEntityAI.cpp:340` | ✅ |
| `-[ShipEntity(AI) performScriptedAttackAI]` (452) | `ShipEntity::performScriptedAttackAI` `Core/Entities/ShipEntityAI.cpp:345` | ✅ |
| `-[ShipEntity(AI) performBuoyTumble]` (458) | `ShipEntity::performBuoyTumble` `Core/Entities/ShipEntityAI.cpp:350` | ✅ |
| `-[ShipEntity(AI) performStop]` (466) | `ShipEntity::performStop` `Core/Entities/ShipEntityAI.cpp:357` | ✅ |
| `-[ShipEntity(AI) performTumble]` (473) | `ShipEntity::performTumble` `Core/Entities/ShipEntityAI.cpp:363` | ✅ |
| `-[ShipEntity(AI) performHyperSpaceToSpecificSystem:]` (481) | `ShipEntity::performHyperSpaceToSpecificSystem` `Core/Entities/ShipEntityAI.cpp:370` | ✅ |
| `-[ShipEntity(AI) requestDockingCoordinates]` (486) | `ShipEntity::requestDockingCoordinates` `Core/Entities/ShipEntityAI.cpp:374` | ✅ |
| `-[ShipEntity(AI) recallDockingInstructions]` (536) | `ShipEntity::recallDockingInstructions` `Core/Entities/ShipEntityAI.cpp:437` | ✅ |
| `-[ShipEntity(AI) scanForNearestIncomingMissile]` (555) | `ShipEntity::scanForNearestIncomingMissile` `Core/Entities/ShipEntityAI.cpp:458` | ✅ |
| `-[ShipEntity(AI) enterPlayerWormhole]` (564) | `ShipEntity::enterPlayerWormhole` `Core/Entities/ShipEntityAI.cpp:467` | ✅ |
| `-[ShipEntity(AI) enterTargetWormhole]` (569) | `ShipEntity::enterTargetWormhole` `Core/Entities/ShipEntityAI.cpp:473` | ✅ |
| `-[ShipEntity(AI) wormholeEscorts]` (609) | `ShipEntity::wormholeEscorts` `Core/Entities/ShipEntityAI.cpp:516` | ✅ |
| `-[ShipEntity(AI) wormholeEntireGroup]` (635) | `ShipEntity::wormholeEntireGroup` `Core/Entities/ShipEntityAI.cpp:539` | ✅ |
| `-[ShipEntity(AI) suggestEscortTo:]` (641) | `ShipEntity::suggestEscortTo` `Core/Entities/ShipEntityAI.cpp:544` | ✅ |
| `-[ShipEntity(AI) broadcastDistressMessage]` (677) | `ShipEntity::broadcastDistressMessage` `Core/Entities/ShipEntityAI.cpp:585` | ✅ |
| `-[ShipEntity(AI) broadcastDistressMessageWithDumping:]` (683) | `ShipEntity::broadcastDistressMessageWithDumping` `Core/Entities/ShipEntityAI.cpp:591` | ✅ |
| `-[ShipEntity(PureAI) setStateTo:]` (752) | `ShipEntity::setStateTo` `Core/Entities/ShipEntityAI.cpp:890` | ✅ |
| `-[ShipEntity(PureAI) pauseAI:]` (757) | `ShipEntity::pauseAI` `Core/Entities/ShipEntityAI.cpp:895` | ✅ |
| `-[ShipEntity(PureAI) randomPauseAI:]` (762) | `ShipEntity::randomPauseAI` `Core/Entities/ShipEntityAI.cpp:902` | ✅ |
| `-[ShipEntity(PureAI) dropMessages:]` (778) | `ShipEntity::dropMessages` `Core/Entities/ShipEntityAI.cpp:924` | ✅ |
| `-[ShipEntity(PureAI) debugDumpPendingMessages]` (790) | `ShipEntity::debugDumpPendingMessages` `Core/Entities/ShipEntityAI.cpp:934` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToCurrentLocation]` (795) | `ShipEntity::setDestinationToCurrentLocation` `Core/Entities/ShipEntityAI.cpp:938` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToJinkPosition]` (801) | `ShipEntity::setDestinationToJinkPosition` `Core/Entities/ShipEntityAI.cpp:943` | ✅ |
| `-[ShipEntity(PureAI) setDesiredRangeTo:]` (808) | `ShipEntity::setDesiredRangeTo` `Core/Entities/ShipEntityAI.cpp:953` | ✅ |
| `-[ShipEntity(PureAI) setDesiredRangeForWaypoint]` (813) | `ShipEntity::setDesiredRangeForWaypoint` `Core/Entities/ShipEntityAI.cpp:959` | ✅ |
| `-[ShipEntity(PureAI) setSpeedTo:]` (818) | `ShipEntity::setSpeedTo` `Core/Entities/ShipEntityAI.cpp:965` | ✅ |
| `-[ShipEntity(PureAI) setSpeedFactorTo:]` (823) | `ShipEntity::setSpeedFactorTo` `Core/Entities/ShipEntityAI.cpp:970` | ✅ |
| `-[ShipEntity(PureAI) setSpeedToCruiseSpeed]` (828) | `ShipEntity::setSpeedToCruiseSpeed` `Core/Entities/ShipEntityAI.cpp:976` | ✅ |
| `-[ShipEntity(PureAI) setThrustFactorTo:]` (833) | `ShipEntity::setThrustFactorTo` `Core/Entities/ShipEntityAI.cpp:978` | ✅ |
| `-[ShipEntity(PureAI) setTargetToPrimaryAggressor]` (838) | `ShipEntity::setTargetToPrimaryAggressor` `Core/Entities/ShipEntityAI.cpp:984` | ✅ |
| `-[ShipEntity(PureAI) addPrimaryAggressorAsDefenseTarget]` (871) | `ShipEntity::addPrimaryAggressorAsDefenseTarget` `Core/Entities/ShipEntityAI.cpp:1028` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestMerchantman]` (884) | `ShipEntity::scanForNearestMerchantman` `Core/Entities/ShipEntityAI.cpp:1041` | ✅ |
| `-[ShipEntity(PureAI) scanForRandomMerchantman]` (913) | `ShipEntity::scanForRandomMerchantman` `Core/Entities/ShipEntityAI.cpp:1075` | ✅ |
| `-[ShipEntity(PureAI) scanForLoot]` (937) | `ShipEntity::scanForLoot` `Core/Entities/ShipEntityAI.cpp:1103` | ✅ |
| `-[ShipEntity(PureAI) scanForRandomLoot]` (979) | `ShipEntity::scanForRandomLoot` `Core/Entities/ShipEntityAI.cpp:1158` | ✅ |
| `-[ShipEntity(PureAI) setTargetToFoundTarget]` (1007) | `ShipEntity::setTargetToFoundTarget` `Core/Entities/ShipEntityAI.cpp:1193` | ✅ |
| `-[ShipEntity(PureAI) addFoundTargetAsDefenseTarget]` (1016) | `ShipEntity::addFoundTargetAsDefenseTarget` `Core/Entities/ShipEntityAI.cpp:1204` | ✅ |
| `-[ShipEntity(PureAI) checkForFullHold]` (1026) | `ShipEntity::checkForFullHold` `Core/Entities/ShipEntityAI.cpp:1216` | ✅ |
| `-[ShipEntity(PureAI) getWitchspaceEntryCoordinates]` (1037) | `ShipEntity::getWitchspaceEntryCoordinates` `Core/Entities/ShipEntityAI.cpp:1226` | ✅ |
| `-[ShipEntity(PureAI) setDestinationFromCoordinates]` (1065) | `ShipEntity::setDestinationFromCoordinates` `Core/Entities/ShipEntityAI.cpp:1265` | ✅ |
| `-[ShipEntity(PureAI) setCoordinatesFromPosition]` (1070) | `ShipEntity::setCoordinatesFromPosition` `Core/Entities/ShipEntityAI.cpp:1267` | ✅ |
| `-[ShipEntity(PureAI) fightOrFleeMissile]` (1075) | `ShipEntity::fightOrFleeMissile` `Core/Entities/ShipEntityAI.cpp:1269` | ✅ |
| `-[ShipEntity(PureAI) setCourseToPlanet]` (1144) | `ShipEntity::setCourseToPlanet` `Core/Entities/ShipEntityAI.cpp:1345` | ✅ |
| `-[ShipEntity(PureAI) setTakeOffFromPlanet]` (1165) | `ShipEntity::setTakeOffFromPlanet` `Core/Entities/ShipEntityAI.cpp:1369` | ✅ |
| `-[ShipEntity(PureAI) landOnPlanet]` (1177) | `ShipEntity::landOnPlanet` `Core/Entities/ShipEntityAI.cpp:1388` | ✅ |
| `-[ShipEntity(PureAI) checkTargetLegalStatus]` (1183) | `ShipEntity::checkTargetLegalStatus` `Core/Entities/ShipEntityAI.cpp:1393` | ✅ |
| `-[ShipEntity(PureAI) checkOwnLegalStatus]` (1207) | `ShipEntity::checkOwnLegalStatus` `Core/Entities/ShipEntityAI.cpp:1416` | ✅ |
| `-[ShipEntity(PureAI) exitAIWithMessage:]` (1229) | `ShipEntity::exitAIWithMessage` `Core/Entities/ShipEntityAI.cpp:1437` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToTarget]` (1236) | `ShipEntity::setDestinationToTarget` `Core/Entities/ShipEntityAI.cpp:1445` | ✅ |
| `-[ShipEntity(PureAI) setDestinationWithinTarget]` (1243) | `ShipEntity::setDestinationWithinTarget` `Core/Entities/ShipEntityAI.cpp:1450` | ✅ |
| `-[ShipEntity(PureAI) checkCourseToDestination]` (1256) | `ShipEntity::checkCourseToDestination` `Core/Entities/ShipEntityAI.cpp:1468` | ✅ |
| `-[ShipEntity(PureAI) checkAegis]` (1272) | `ShipEntity::checkAegis` `Core/Entities/ShipEntityAI.cpp:1498` | ✅ |
| `-[ShipEntity(PureAI) checkEnergy]` (1308) | `ShipEntity::checkEnergy` `Core/Entities/ShipEntityAI.cpp:1538` | ✅ |
| `-[ShipEntity(PureAI) checkHeatInsulation]` (1325) | `ShipEntity::checkHeatInsulation` `Core/Entities/ShipEntityAI.cpp:1554` | ✅ |
| `-[ShipEntity(PureAI) findNewDefenseTarget]` (1336) | `ShipEntity::findNewDefenseTarget` `Core/Entities/ShipEntityAI.cpp:1564` | ✅ |
| `-[ShipEntity(PureAI) scanForOffenders]` (1351) | `ShipEntity::scanForOffenders` `Core/Entities/ShipEntityAI.cpp:1583` | ✅ |
| `-[ShipEntity(PureAI) setCourseToWitchpoint]` (1388) | `ShipEntity::setCourseToWitchpoint` `Core/Entities/ShipEntityAI.cpp:1636` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToWitchpoint]` (1396) | `ShipEntity::setDestinationToWitchpoint` `Core/Entities/ShipEntityAI.cpp:1644` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToStationBeacon]` (1401) | `ShipEntity::setDestinationToStationBeacon` `Core/Entities/ShipEntityAI.cpp:1649` | ✅ |
| `-[ShipEntity(PureAI) performHyperSpaceExit]` (1408) | `ShipEntity::performHyperSpaceExit` `Core/Entities/ShipEntityAI.cpp:1658` | ✅ |
| `-[ShipEntity(PureAI) performHyperSpaceExitWithoutReplacing]` (1413) | `ShipEntity::performHyperSpaceExitWithoutReplacing` `Core/Entities/ShipEntityAI.cpp:1660` | ✅ |
| `-[ShipEntity(PureAI) disengageAutopilot]` (1418) | `ShipEntity::disengageAutopilot` `Core/Entities/ShipEntityAI.cpp:1664` | ✅ |
| `-[ShipEntity(PureAI) wormholeGroup]` (1423) | `ShipEntity::wormholeGroup` `Core/Entities/ShipEntityAI.cpp:1675` | ✅ |
| `-[ShipEntity(PureAI) commsMessage:]` (1439) | `ShipEntity::commsMessage` `Core/Entities/ShipEntityAI.cpp:1694` | ✅ |
| `-[ShipEntity(PureAI) commsMessageByUnpiloted:]` (1444) | `ShipEntity::commsMessageByUnpiloted` `Core/Entities/ShipEntityAI.cpp:1699` | ✅ |
| `-[ShipEntity(PureAI) ejectCargo]` (1449) | `ShipEntity::ejectCargo` `Core/Entities/ShipEntityAI.cpp:1705` | ✅ |
| `-[ShipEntity(PureAI) scanForThargoid]` (1461) | `ShipEntity::scanForThargoid` `Core/Entities/ShipEntityAI.cpp:1723` | ✅ |
| `-[ShipEntity(PureAI) scanForNonThargoid]` (1466) | `ShipEntity::scanForNonThargoid` `Core/Entities/ShipEntityAI.cpp:1727` | ✅ |
| `-[ShipEntity(PureAI) thargonCheckMother]` (1488) | `ShipEntity::thargonCheckMother` `Core/Entities/ShipEntityAI.cpp:1753` | ✅ |
| `-[ShipEntity(PureAI) becomeUncontrolledThargon]` (1512) | `ShipEntity::becomeUncontrolledThargon` `Core/Entities/ShipEntityAI.cpp:1787` | ✅ |
| `-[ShipEntity(PureAI) checkDistanceTravelled]` (1536) | `ShipEntity::checkDistanceTravelled` `Core/Entities/ShipEntityAI.cpp:1812` | ✅ |
| `-[ShipEntity(PureAI) fightOrFleeHostiles]` (1542) | `ShipEntity::fightOrFleeHostiles` `Core/Entities/ShipEntityAI.cpp:1818` | ✅ |
| `-[ShipEntity(PureAI) suggestEscort]` (1585) | `ShipEntity::suggestEscort` `Core/Entities/ShipEntityAI.cpp:1860` | ✅ |
| `-[ShipEntity(PureAI) escortCheckMother]` (1591) | `ShipEntity::escortCheckMother` `Core/Entities/ShipEntityAI.cpp:1865` | ✅ |
| `-[ShipEntity(PureAI) checkGroupOddsVersusTarget]` (1607) | `ShipEntity::checkGroupOddsVersusTarget` `Core/Entities/ShipEntityAI.cpp:1882` | ✅ |
| `-[ShipEntity(PureAI) scanForFormationLeader]` (1621) | `ShipEntity::scanForFormationLeader` `Core/Entities/ShipEntityAI.cpp:1902` | ✅ |
| `-[ShipEntity(PureAI) messageMother:]` (1652) | `ShipEntity::messageMother` `Core/Entities/ShipEntityAI.cpp:1938` | ✅ |
| `-[ShipEntity(PureAI) messageSelf:]` (1665) | `ShipEntity::messageSelf` `Core/Entities/ShipEntityAI.cpp:1947` | ✅ |
| `-[ShipEntity(PureAI) setPlanetPatrolCoordinates]` (1670) | `ShipEntity::setPlanetPatrolCoordinates` `Core/Entities/ShipEntityAI.cpp:1952` | ✅ |
| `-[ShipEntity(PureAI) setSunSkimStartCoordinates]` (1732) | `ShipEntity::setSunSkimStartCoordinates` `Core/Entities/ShipEntityAI.cpp:2029` | ✅ |
| `-[ShipEntity(PureAI) setSunSkimEndCoordinates]` (1749) | `ShipEntity::setSunSkimEndCoordinates` `Core/Entities/ShipEntityAI.cpp:2047` | ✅ |
| `-[ShipEntity(PureAI) setSunSkimExitCoordinates]` (1760) | `ShipEntity::setSunSkimExitCoordinates` `Core/Entities/ShipEntityAI.cpp:2059` | ✅ |
| `-[ShipEntity(PureAI) patrolReportIn]` (1779) | `ShipEntity::patrolReportIn` `Core/Entities/ShipEntityAI.cpp:2078` | ✅ |
| `-[ShipEntity(PureAI) checkForMotherStation]` (1788) | `ShipEntity::checkForMotherStation` `Core/Entities/ShipEntityAI.cpp:2091` | ✅ |
| `-[ShipEntity(PureAI) sendTargetCommsMessage:]` (1804) | `ShipEntity::sendTargetCommsMessage` `Core/Entities/ShipEntityAI.cpp:2108` | ✅ |
| `-[ShipEntity(PureAI) markTargetForFines]` (1814) | `ShipEntity::markTargetForFines` `Core/Entities/ShipEntityAI.cpp:2123` | ✅ |
| `-[ShipEntity(PureAI) markTargetForOffence:]` (1825) | `ShipEntity::markTargetForOffence` `Core/Entities/ShipEntityAI.cpp:2138` | ✅ |
| `-[ShipEntity(PureAI) storeTarget]` (1838) | `ShipEntity::storeTarget` `Core/Entities/ShipEntityAI.cpp:2159` | ✅ |
| `-[ShipEntity(PureAI) recallStoredTarget]` (1849) | `ShipEntity::recallStoredTarget` `Core/Entities/ShipEntityAI.cpp:2172` | ✅ |
| `-[ShipEntity(PureAI) scanForRocks]` (1871) | `ShipEntity::scanForRocks` `Core/Entities/ShipEntityAI.cpp:2194` | ✅ |
| `-[ShipEntity(PureAI) setDestinationToDockingAbort]` (1907) | `ShipEntity::setDestinationToDockingAbort` `Core/Entities/ShipEntityAI.cpp:2229` | ✅ |
| `-[ShipEntity(PureAI) requestNewTarget]` (1936) | `ShipEntity::requestNewTarget` `Core/Entities/ShipEntityAI.cpp:2257` | ✅ |
| `-[ShipEntity(PureAI) rollD:]` (1965) | `ShipEntity::rollD` `Core/Entities/ShipEntityAI.cpp:2293` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithPrimaryRole:]` (1977) | `ShipEntity::scanForNearestShipWithPrimaryRole` `Core/Entities/ShipEntityAI.cpp:2306` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipHavingRole:]` (1982) | `ShipEntity::scanForNearestShipHavingRole` `Core/Entities/ShipEntityAI.cpp:2315` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithAnyPrimaryRole:]` (1987) | `ShipEntity::scanForNearestShipWithAnyPrimaryRole` `Core/Entities/ShipEntityAI.cpp:2323` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipHavingAnyRole:]` (1993) | `ShipEntity::scanForNearestShipHavingAnyRole` `Core/Entities/ShipEntityAI.cpp:2331` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithScanClass:]` (1999) | `ShipEntity::scanForNearestShipWithScanClass` `Core/Entities/ShipEntityAI.cpp:2339` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithoutPrimaryRole:]` (2005) | `ShipEntity::scanForNearestShipWithoutPrimaryRole` `Core/Entities/ShipEntityAI.cpp:2347` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipNotHavingRole:]` (2010) | `ShipEntity::scanForNearestShipNotHavingRole` `Core/Entities/ShipEntityAI.cpp:2356` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithoutAnyPrimaryRole:]` (2015) | `ShipEntity::scanForNearestShipWithoutAnyPrimaryRole` `Core/Entities/ShipEntityAI.cpp:2364` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipNotHavingAnyRole:]` (2021) | `ShipEntity::scanForNearestShipNotHavingAnyRole` `Core/Entities/ShipEntityAI.cpp:2372` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipWithoutScanClass:]` (2027) | `ShipEntity::scanForNearestShipWithoutScanClass` `Core/Entities/ShipEntityAI.cpp:2380` | ✅ |
| `-[ShipEntity(PureAI) scanForNearestShipMatchingPredicate:]` (2033) | `ShipEntity::scanForNearestShipMatchingPredicate` `Core/Entities/ShipEntityAI.cpp:2388` | ✅ |
| `-[ShipEntity(PureAI) setCoordinates:]` (2126) | `ShipEntity::setCoordinates` `Core/Entities/ShipEntityAI.cpp:2488` | ✅ |
| `-[ShipEntity(PureAI) checkForNormalSpace]` (2158) | `ShipEntity::checkForNormalSpace` `Core/Entities/ShipEntityAI.cpp:2524` | ✅ |
| `-[ShipEntity(PureAI) setTargetToRandomStation]` (2166) | `ShipEntity::setTargetToRandomStation` `Core/Entities/ShipEntityAI.cpp:2533` | ✅ |
| `-[ShipEntity(PureAI) setTargetToLastStation]` (2210) | `ShipEntity::setTargetToLastStation` `Core/Entities/ShipEntityAI.cpp:2584` | ✅ |
| `-[ShipEntity(PureAI) addFuel:]` (2222) | `ShipEntity::addFuel` `Core/Entities/ShipEntityAI.cpp:2595` | ✅ |
| `-[ShipEntity(PureAI) scriptActionOnTarget:]` (2227) | `ShipEntity::scriptActionOnTarget` `Core/Entities/ShipEntityAI.cpp:2600` | ✅ |
| `-[ShipEntity(PureAI) safeScriptActionOnTarget:]` (2256) | `ShipEntity::safeScriptActionOnTarget` `Core/Entities/ShipEntityAI.cpp:2650` | ✅ |
| `-[ShipEntity(PureAI) sendScriptMessage:]` (2274) | `ShipEntity::sendScriptMessage` `Core/Entities/ShipEntityAI.cpp:2677` | ⚠️ |
| `-[ShipEntity(PureAI) ai_throwSparks]` (2287) | `ShipEntity::ai_throwSparks` `Core/Entities/ShipEntityAI.cpp:2698` | ✅ |
| `-[ShipEntity(PureAI) explodeSelf]` (2292) | `ShipEntity::explodeSelf` `Core/Entities/ShipEntityAI.cpp:2700` | ✅ |
| `-[ShipEntity(PureAI) ai_debugMessage:]` (2297) | `ShipEntity::ai_debugMessage` `Core/Entities/ShipEntityAI.cpp:2704` | ✅ |
| `-[ShipEntity(PureAI) targetFirstBeaconWithCode:]` (2306) | `ShipEntity::targetFirstBeaconWithCode` `Core/Entities/ShipEntityAI.cpp:2714` | ✅ |
| `-[ShipEntity(PureAI) targetNextBeaconWithCode:]` (2316) | `ShipEntity::targetNextBeaconWithCode` `Core/Entities/ShipEntityAI.cpp:2729` | ✅ |
| `-[ShipEntity(PureAI) setRacepointsFromTarget]` (2347) | `ShipEntity::setRacepointsFromTarget` `Core/Entities/ShipEntityAI.cpp:2773` | ✅ |
| `-[ShipEntity(PureAI) performFlyRacepoints]` (2367) | `ShipEntity::performFlyRacepoints` `Core/Entities/ShipEntityAI.cpp:2793` | ✅ |
| `-[ShipEntity(OOAIPrivate) checkFoundTarget]` (2378) | `ShipEntity::checkFoundTarget` `Core/Entities/ShipEntityAI.cpp:665` | ✅ |
| `-[ShipEntity(OOAIPrivate) performHyperSpaceExitReplace:]` (2387) | `ShipEntity::performHyperSpaceExitReplace` `Core/Entities/ShipEntityAI.cpp:673` | ✅ |
| `-[ShipEntity(OOAIPrivate) performHyperSpaceExitReplace:toSystem:]` (2392) | `ShipEntity::performHyperSpaceExitReplace` `Core/Entities/ShipEntityAI.cpp:677` | ✅ |
| `-[ShipEntity(OOAIPrivate) scanForNearestShipWithPredicate:parameter:]` (2466) | `ShipEntity::scanForNearestShipWithPredicate` `Core/Entities/ShipEntityAI.cpp:766` | ✅ |
| `-[ShipEntity(OOAIPrivate) scanForNearestShipWithNegatedPredicate:parameter:]` (2492) | `ShipEntity::scanForNearestShipWithNegatedPredicate` `Core/Entities/ShipEntityAI.cpp:795` | ✅ |
| `-[ShipEntity(OOAIPrivate) acceptDistressMessageFrom:]` (2498) | `ShipEntity::acceptDistressMessageFrom` `Core/Entities/ShipEntityAI.cpp:801` | ✅ |
| `-[StationEntity(OOAIPrivate) acceptDistressMessageFrom:]` (2517) | `StationEntity::acceptDistressMessageFrom` `Core/Entities/ShipEntityAI.cpp:870` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchPatrol]` (2550) | `ShipEntity::launchPatrol` `Core/Entities/ShipEntityAI.cpp:856` | ✅ |
| `-[ShipEntity(OOAIStationStubs) increaseAlertLevel]` (2540, `STATION_STUB_NOARG`) | `ShipEntity::increaseAlertLevel` `Core/Entities/ShipEntityAI.cpp:830` | ✅ |
| `-[ShipEntity(OOAIStationStubs) decreaseAlertLevel]` (2541, `STATION_STUB_NOARG`) | `ShipEntity::decreaseAlertLevel` `Core/Entities/ShipEntityAI.cpp:833` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchPolice]` (2542, `STATION_STUB_NOARG`) | `ShipEntity::launchPolice` `Core/Entities/ShipEntityAI.cpp:837` | ⚠️ |
| `-[ShipEntity(OOAIStationStubs) launchDefenseShip]` (2543, `STATION_STUB_NOARG`) | `ShipEntity::launchDefenseShip` `Core/Entities/ShipEntityAI.cpp:844` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchScavenger]` (2544, `STATION_STUB_NOARG`) | `ShipEntity::launchScavenger` `Core/Entities/ShipEntityAI.cpp:847` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchMiner]` (2545, `STATION_STUB_NOARG`) | `ShipEntity::launchMiner` `Core/Entities/ShipEntityAI.cpp:848` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchPirateShip]` (2546, `STATION_STUB_NOARG`) | `ShipEntity::launchPirateShip` `Core/Entities/ShipEntityAI.cpp:849` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchShuttle]` (2547, `STATION_STUB_NOARG`) | `ShipEntity::launchShuttle` `Core/Entities/ShipEntityAI.cpp:852` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchTrader]` (2548, `STATION_STUB_NOARG`) | `ShipEntity::launchTrader` `Core/Entities/ShipEntityAI.cpp:853` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchEscort]` (2549, `STATION_STUB_NOARG`) | `ShipEntity::launchEscort` `Core/Entities/ShipEntityAI.cpp:854` | ✅ |
| `-[ShipEntity(OOAIStationStubs) launchShipWithRole:]` (2555, `STATION_STUB_ARG`) | `ShipEntity::launchShipWithRole` `Core/Entities/ShipEntityAI.cpp:861` | ✅ |
| `-[ShipEntity(OOAIStationStubs) abortAllDockings]` (2556, `STATION_STUB_NOARG`) | `ShipEntity::abortAllDockings` `Core/Entities/ShipEntityAI.cpp:864` | ✅ |
| AI-plist dispatch: `Resources/Config/whitelist.plist` `ai_methods` + `ai_and_action_methods` and `ai_method_aliases`, sent by `-performSelector:withObject:` | by-name rows in `Core/Entities/OOEntityCalledByNameTable.h` (e.g. `launchPolice` :2330, `launchPatrol` :2338, `pauseAI:` :2342, `rollD:` :2417); aliases resolved from `ai_method_aliases` in `Core/AI.cpp:849` | ✅ |

**Differences:**

- ⚠️ **low** (still open) — `sendScriptMessage:` with an empty or whitespace-only message: upstream raised `NSRangeException` at `-objectAtIndex:0`, aborting the AI action; the port does nothing, per its code comment — upstream `Core/Entities/ShipEntityAI.m:2274-2284` ↔ port `Core/Entities/ShipEntityAI.cpp:2677-2696`
- ⚠️ **low** (still open) — The ship stub `launchPolice` returns an empty `oo::PList` instead of `void` so the by-name row can return the station's launched ships ("called by name" comment); it still logs `ai.invalid.notAStation` with the same text — upstream `Core/Entities/ShipEntityAI.m:2542` ↔ port `Core/Entities/ShipEntityAI.cpp:837-842`
- ✅ note — Whitelist reachability re-checked on this commit: `Resources/Config/whitelist.plist` is byte-identical to upstream, and every `ai_methods`/`ai_and_action_methods` name has a by-name row in `OOEntityCalledByNameTable.h`, except `throwSparks`, `clearDefenseTargets` and `launchIndependentShipWithRole:`, which are `ai_method_aliases` entries whose targets (`ai_throwSparks`, `removeAllDefenseTargets`, `launchIndependentShip:`) have rows — port `Core/Entities/OOEntityCalledByNameTable.h:2330-2437,2980`, `Core/AI.cpp:849`
- ✅ note — Constants, AI message strings and RNG draw order re-read and unchanged: attack range `1250*randf()+750`; flee jink 400, aspect `> 0.9995`, `randf() < 0.15`; docking range `SCANNER_MAX_RANGE2 * 6.25`; distress `messageTime > 2*randf()`, beg at `0.375*maxEnergy`; offence marks 8/64/`1\|(ranrot&15)`; `scanForOffenders` `0.4*gov` vs `ranrot&255` (1.0 with no sun); patrol 5 km/25 km legs, range 250, `randf() < .25` dock; witchspace 10 km / `maxFlightSpeed*10`; dock-abort 8 km; sun-skim exit 10 km; `ejectCargo` 10% cut below 16, `0.75*i` delays (now `oo::ScheduleEntityCall`) — upstream `ShipEntityAI.m` passim ↔ port `ShipEntityAI.cpp` passim
- ✅ note — The `-mutationSafeEnumerator` loops (groupAttackTarget, fightOrFleeMissile, wormholeGroup) iterate a `memberArray()` snapshot, and `escortEnumerator` became `escorts()`, the escort group's `memberArray()` without self, so order and mutation safety match — port `Core/Entities/ShipEntityAI.cpp:213,1315,1683`, `Core/Entities/ShipEntity.cpp:6832-6843`
- ✅ note — `checkAegis`'s invalid-state `NSLog` is `OO_LOG("unclassified", …)`, the class upstream gave a routed NSLog — upstream `Core/Entities/ShipEntityAI.m:1303` ↔ port `Core/Entities/ShipEntityAI.cpp:1530`
- ✅ subtle — Where upstream typed `[self primaryTarget]` as `ShipEntity*` and messaged it (groupAttackTarget, checkTargetLegalStatus, suggestEscort, checkGroupOddsVersusTarget, sendTargetCommsMessage, markTargetFor*, setRacepointsFromTarget, targetNextBeaconWithCode), the port uses `oo::ToShip`, so a non-ship target (e.g. a wormhole) counts as no target. Upstream would message the non-ship; not reached by the core AIs in these states — port `Core/Entities/ShipEntityAI.cpp:199,1394,1861,1885,2111,2124,2142,2736,2775`

## ShipEntityLoadRestore

<a id="shipentityloadrestore"></a>
Upstream `src/Core/Entities/ShipEntityLoadRestore.m` ↔ `Core/Entities/ShipEntityLoadRestore.cpp` (358 / 425 lines)

**Status:** done — 7 rows: 6 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `KEY_*` save-game key table (38-61) | `KEY_*` macros `Core/Entities/ShipEntityLoadRestore.cpp:43-66` (identical spellings) | ✅ |
| `-[ShipEntity(LoadRestore) savedShipDictionaryWithContext:]` (75) | `ShipEntity::savedShipDictionaryWithContext` `Core/Entities/ShipEntityLoadRestore.cpp:85` | ✅ |
| `+[ShipEntity(LoadRestore) shipRestoredFromDictionary:useFallback:context:]` (163) | `ShipEntity::shipRestoredFromDictionary` (static) `Core/Entities/ShipEntityLoadRestore.cpp:199` | ❌ |
| `-[ShipEntity(LoadRestore) simplifyShipdata:andGetDeletes:]` (251) | `ShipEntity::simplifyShipdata` `Core/Entities/ShipEntityLoadRestore.cpp:330` | ✅ |
| `StripIgnoredKeys` (292) | `StripIgnoredKeys` (anon ns) `Core/Entities/ShipEntityLoadRestore.cpp:355` | ✅ |
| `GroupIDForGroup` (304) | `GroupIDForGroup` (anon ns, `OOShipSaveContext`) `Core/Entities/ShipEntityLoadRestore.cpp:369` | ✅ |
| `GroupForGroupID` (341) | `GroupForGroupID` (anon ns) `Core/Entities/ShipEntityLoadRestore.cpp:391` | ✅ |

**Differences:**

- ❌ **low** (still open) — When the restored dictionary has no `primary_role` (or a non-string/number value), the port writes `ship->primaryRole = std::nullopt` with no null check; if `newStationObject`/`NewShipObject` returned null, this dereferences null. Upstream sent `-setPrimaryRole:nil` to nil and went on to return nil — upstream `Core/Entities/ShipEntityLoadRestore.m:194` ↔ port `Core/Entities/ShipEntityLoadRestore.cpp:245-250`
- ✅ note — Save keys and restore defaults re-read: `AI` defaults to `"nullAI.plist"`; `energy_level` defaults to `1.0` and is written only when `energy != maxEnergy`, as a double; `position`/`orientation` default to `kZeroHPVector`/`kIdentityQuaternion` and are written only when different; `group`/`escort_group` default to `NSNotFound` (`oo::kNotFound`); forced `auto_ai = NO` and `escorts = 0`; the 17 `StripIgnoredKeys` names are identical — upstream `Core/Entities/ShipEntityLoadRestore.m:75-246,292-301` ↔ port `Core/Entities/ShipEntityLoadRestore.cpp:85-328,355-367`
- ✅ note — Where upstream would raise on nil in `-setObject:forKey:` (nil `_shipKey`, role string, primary role, AI `associatedJS`), the port writes `""` or omits the key, per its comments. These are crash paths upstream — upstream `Core/Entities/ShipEntityLoadRestore.m:81,85,109,154` ↔ port `Core/Entities/ShipEntityLoadRestore.cpp:91-101,129,185-188`
- ✅ note — `shipdata_deletes` is listed in key byte order, where upstream used `NSDictionary` hash order; it is applied as a set of removals, so only the order in the save file changes — upstream `Core/Entities/ShipEntityLoadRestore.m:266-271` ↔ port `Core/Entities/ShipEntityLoadRestore.cpp:344-350`
- ✅ note — The ship class is chosen by `Universe::isStationShipDictionary` (station vs ship), standing in for `-shipClassForShipDictionary:` — port `Core/Entities/ShipEntityLoadRestore.cpp:233-239`

## ShipEntityScriptMethods

<a id="shipentityscriptmethods"></a>
Upstream `src/Core/Entities/ShipEntityScriptMethods.m` ↔ `Core/Entities/ShipEntityScriptMethods.cpp` (92 / 99 lines)

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[ShipEntity(ScriptMethods) ejectShipOfType:]` (34) | `ShipEntity::ejectShipOfType` `Core/Entities/ShipEntityScriptMethods.cpp:35` | ✅ |
| `-[ShipEntity(ScriptMethods) ejectShipOfRole:]` (47) | `ShipEntity::ejectShipOfRole` `Core/Entities/ShipEntityScriptMethods.cpp:48` | ✅ |
| `-[ShipEntity(ScriptMethods) spawnShipsWithRole:count:]` (60) | `ShipEntity::spawnShipsWithRole` `Core/Entities/ShipEntityScriptMethods.cpp:61` | ✅ |

**Differences:**

- ✅ note — `spawnShipsWithRole:count:` keeps the `script.debug.note.addShips` log text, spawns near `rootShipEntity()`, sets ejecta temperature, applies the submunition owner/target/missile-flag rule only when the missile flag is set and `is_submunition` is true, and owns mines to self. `count == 0` returns an empty result; otherwise the `do … while (--count)` loop is kept. The result is now a vector of held entities instead of an `NSArray` — upstream `Core/Entities/ShipEntityScriptMethods.m:60-89` ↔ port `Core/Entities/ShipEntityScriptMethods.cpp:61-99`

## StationEntity

<a id="stationentity"></a>
Upstream `src/Core/Entities/StationEntity.m` ↔ `Core/Entities/StationEntity.cpp` (2192 / 2611 lines)

**Status:** done — 112 rows: 107 ✅ 3 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `_shipsOnHold` ivar (`StationEntity.h:53`, `OOWeakSet`) | `_shipsOnHold` `oo::WeakSet<Entity>` `Core/Entities/StationEntity.h:231` | ⚠️ |
| `@interface StationEntity (mwDebug)` `dbgGetShipsOnApproach`/`dbgGetIdLocks`/`dbgDumpIdLocks` (64-69, declared only, never implemented) | — | ➖ |
| `-[StationEntity isUnpiloted]` (76) | `StationEntity::isUnpiloted` `Core/Entities/StationEntity.cpp:802` | ✅ |
| `-[StationEntity equivalentTechLevel]` (81) | `StationEntity::getEquivalentTechLevel` `Core/Entities/StationEntity.cpp:816` | ✅ |
| `-[StationEntity setEquivalentTechLevel:]` (90) | `StationEntity::setEquivalentTechLevel` `Core/Entities/StationEntity.cpp:825` | ✅ |
| `-[StationEntity virtualPortDimensions]` (95) | `StationEntity::virtualPortDimensions` `Core/Entities/StationEntity.cpp:829` | ✅ |
| `-[StationEntity playerReservedDock]` (100) | `StationEntity::playerReservedDock` `Core/Entities/StationEntity.cpp:831` | ✅ |
| `-[StationEntity beaconPosition]` (105) | `StationEntity::beaconPosition` `Core/Entities/StationEntity.cpp:835` | ✅ |
| `-[StationEntity equipmentPriceFactor]` (114) | `StationEntity::getEquipmentPriceFactor` `Core/Entities/StationEntity.cpp:845` | ✅ |
| `-[StationEntity marketCapacity]` (119) | `StationEntity::getMarketCapacity` `Core/Entities/StationEntity.cpp:847` | ✅ |
| `-[StationEntity marketDefinition]` (124) | `StationEntity::getMarketDefinition` `Core/Entities/StationEntity.cpp:849` | ✅ |
| `-[StationEntity marketScriptName]` (129) | `StationEntity::getMarketScriptName` `Core/Entities/StationEntity.cpp:851` | ✅ |
| `-[StationEntity marketMonitored]` (134) | `StationEntity::getMarketMonitored` `Core/Entities/StationEntity.cpp:855` | ✅ |
| `-[StationEntity marketBroadcast]` (142) | `StationEntity::getMarketBroadcast` `Core/Entities/StationEntity.cpp:862` | ✅ |
| `-[StationEntity legalStatusOfManifest:export:]` (150) | `StationEntity::legalStatusOfManifest` `Core/Entities/StationEntity.cpp:869` | ✅ |
| `-[StationEntity localMarket]` (166) | `StationEntity::getLocalMarket` `Core/Entities/StationEntity.cpp:884` | ✅ |
| `-[StationEntity setLocalMarket:]` (179) | `StationEntity::setLocalMarket` `Core/Entities/StationEntity.cpp:896` | ✅ |
| `-[StationEntity localMarketForScripting]` (184) | `StationEntity::localMarketForScripting` `Core/Entities/StationEntity.cpp:902` | ✅ |
| `-[StationEntity setPrice:forCommodity:]` (189) | `StationEntity::setPrice` `Core/Entities/StationEntity.cpp:908` | ✅ |
| `-[StationEntity setQuantity:forCommodity:]` (194) | `StationEntity::setQuantity` `Core/Entities/StationEntity.cpp:915` | ✅ |
| `-[StationEntity localShipyard]` (199) | `StationEntity::getLocalShipyard` `Core/Entities/StationEntity.cpp:922` | ✅ |
| `-[StationEntity setLocalShipyard:]` (204) | `StationEntity::setLocalShipyard` `Core/Entities/StationEntity.cpp:926` | ✅ |
| `-[StationEntity localInterfaces]` (211) | `StationEntity::getLocalInterfaces` `Core/Entities/StationEntity.cpp:932` | ✅ |
| `-[StationEntity setInterfaceDefinition:forKey:]` (216) | `StationEntity::setInterfaceDefinition` `Core/Entities/StationEntity.cpp:936` | ✅ |
| `-[StationEntity initialiseLocalMarket]` (225) | `StationEntity::initialiseLocalMarket` `Core/Entities/StationEntity.cpp:945` | ✅ |
| `-[StationEntity setPlanet:]` (232) | `StationEntity::setPlanet` `Core/Entities/StationEntity.cpp:953` | ✅ |
| `-[StationEntity planet]` (240) | `StationEntity::getPlanet` `Core/Entities/StationEntity.cpp:961` | ✅ |
| `-[StationEntity countOfDockedContractors]` (245) | `StationEntity::countOfDockedContractors` `Core/Entities/StationEntity.cpp:967` | ✅ |
| `-[StationEntity countOfDockedPolice]` (250) | `StationEntity::countOfDockedPolice` `Core/Entities/StationEntity.cpp:973` | ✅ |
| `-[StationEntity countOfDockedDefenders]` (255) | `StationEntity::countOfDockedDefenders` `Core/Entities/StationEntity.cpp:977` | ✅ |
| `-[StationEntity dockSubEntityEnumerator]` (260) | `StationEntity::dockSubEntities` `Core/Entities/StationEntity.cpp:983` (held snapshot vector, same order and `isDock` filter) | ➖ |
| `-[StationEntity sanityCheckShipsOnApproach]` (265) | `StationEntity::sanityCheckShipsOnApproach` `Core/Entities/StationEntity.cpp:1395` | ✅ |
| `-[StationEntity launchShip:]` (283) | `StationEntity::launchShip` `Core/Entities/StationEntity.cpp:1410` | ✅ |
| `-[StationEntity abortAllDockings]` (312) | `StationEntity::abortAllDockings` `Core/Entities/StationEntity.cpp:1441` | ✅ |
| `-[StationEntity autoDockShipsOnHold]` (343) | `StationEntity::autoDockShipsOnHold` `Core/Entities/StationEntity.cpp:1480` | ✅ |
| `-[StationEntity autoDockShipsOnApproach]` (354) | `StationEntity::autoDockShipsOnApproach` `Core/Entities/StationEntity.cpp:1489` | ✅ |
| `-[StationEntity portUpVectorForShip:]` (368) | `StationEntity::portUpVectorForShip` `Core/Entities/StationEntity.cpp:1501` | ✅ |
| `OOMakeDockingInstructions` (380) | `OOMakeDockingInstructions` `Core/Entities/StationEntity.cpp:74` | ✅ |
| `-[StationEntity dockingInstructionsForShip:]` (401) | `StationEntity::dockingInstructionsForShip` `Core/Entities/StationEntity.cpp:1517` | ✅ |
| `-[StationEntity holdPositionInstructionForShip:]` (506) | `StationEntity::holdPositionInstructionForShip` `Core/Entities/StationEntity.cpp:1644` | ✅ |
| `-[StationEntity abortDockingForShip:]` (516) | `StationEntity::abortDockingForShip` `Core/Entities/StationEntity.cpp:1655` | ✅ |
| `-[StationEntity initWithKey:definition:]` (538) | `StationEntity::newStationObject` `Core/Entities/StationEntity.cpp:773` + `initStationDefaults` `:783` | ✅ |
| `-[StationEntity dealloc]` (554) | `StationEntity::willDealloc` `Core/Entities/StationEntity.cpp:793` (other members released by the destructor) | ✅ |
| `-[StationEntity setUpShipFromDictionary:]` (569) | `StationEntity::setUpShipFromDictionary` `Core/Entities/StationEntity.cpp:993` | ✅ |
| `-[StationEntity setUpSubEntities]` (658) | `StationEntity::setUpSubEntities` `Core/Entities/StationEntity.cpp:1107` | ✅ |
| `-[StationEntity shipIsInDockingCorridor:]` (703) | `StationEntity::shipIsInDockingCorridor` `Core/Entities/StationEntity.cpp:1676` | ✅ |
| `-[StationEntity pullInShipIfPermitted:]` (720) | `StationEntity::pullInShipIfPermitted` `Core/Entities/StationEntity.cpp:1692` | ✅ |
| `-[StationEntity dockingCorridorIsEmpty]` (725) | `StationEntity::dockingCorridorIsEmpty` `Core/Entities/StationEntity.cpp:1696` | ✅ |
| `-[StationEntity clearDockingCorridor]` (740) | `StationEntity::clearDockingCorridor` `Core/Entities/StationEntity.cpp:1708` | ✅ |
| `-[StationEntity update:]` (754) | `StationEntity::update` `Core/Entities/StationEntity.cpp:1719` | ✅ |
| `-[StationEntity clear]` (856) | `StationEntity::clear` `Core/Entities/StationEntity.cpp:1867` | ✅ |
| `-[StationEntity hasMultipleDocks]` (867) | `StationEntity::hasMultipleDocks` `Core/Entities/StationEntity.cpp:1876` | ✅ |
| `-[StationEntity hasClearDock]` (883) | `StationEntity::hasClearDock` `Core/Entities/StationEntity.cpp:1880` | ✅ |
| `-[StationEntity hasEligibleDock]` (897) | `StationEntity::hasEligibleDock` `Core/Entities/StationEntity.cpp:1896` | ✅ |
| `-[StationEntity hasLaunchDock]` (911) | `StationEntity::hasLaunchDock` `Core/Entities/StationEntity.cpp:1914` | ✅ |
| `-[StationEntity selectDockForDocking]` (924) | `StationEntity::selectDockForDocking` `Core/Entities/StationEntity.cpp:1925` | ✅ |
| `-[StationEntity addShipToLaunchQueue:withPriority:]` (936) | `StationEntity::addShipToLaunchQueue` `Core/Entities/StationEntity.cpp:1937` | ✅ |
| `-[StationEntity countOfShipsInLaunchQueueWithPrimaryRole:]` (987) | `StationEntity::countOfShipsInLaunchQueueWithPrimaryRole` `Core/Entities/StationEntity.cpp:1998` | ✅ |
| `-[StationEntity fitsInDock:]` (998) | `StationEntity::fitsInDock(ship)` `Core/Entities/StationEntity.cpp:2010` | ✅ |
| `-[StationEntity fitsInDock:andLogNoFit:]` (1003) | `StationEntity::fitsInDock(ship, logNoFit)` `Core/Entities/StationEntity.cpp:2014` | ✅ |
| `-[StationEntity noteDockedShip:]` (1022) | `StationEntity::noteDockedShip` `Core/Entities/StationEntity.cpp:2039` | ✅ |
| `-[StationEntity addShipToStationCount:]` (1068) | `StationEntity::addShipToStationCount` `Core/Entities/StationEntity.cpp:2093` | ✅ |
| `-[StationEntity interstellarUndockingAllowed]` (1084) | `StationEntity::getInterstellarUndockingAllowed` `Core/Entities/StationEntity.cpp:1171` | ✅ |
| `-[StationEntity hasNPCTraffic]` (1089) | `StationEntity::getHasNPCTraffic` `Core/Entities/StationEntity.cpp:1175` | ✅ |
| `-[StationEntity setHasNPCTraffic:]` (1094) | `StationEntity::setHasNPCTraffic` `Core/Entities/StationEntity.cpp:1177` | ✅ |
| `-[StationEntity collideWithShip:]` (1099) | `StationEntity::collideWithShip` `Core/Entities/StationEntity.cpp:2113` | ✅ |
| `-[StationEntity hasHostileTarget]` (1111) | `StationEntity::hasHostileTarget` `Core/Entities/StationEntity.cpp:2124` | ✅ |
| `-[StationEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (1116) | `StationEntity::takeEnergyDamage` `Core/Entities/StationEntity.cpp:2131` | ✅ |
| `-[StationEntity adjustVelocity:]` (1159) | `StationEntity::adjustVelocity` `Core/Entities/StationEntity.cpp:2190` | ✅ |
| `-[StationEntity takeScrapeDamage:from:]` (1165) | `StationEntity::takeScrapeDamage` `Core/Entities/StationEntity.cpp:2195` | ✅ |
| `-[StationEntity takeHeatDamage:]` (1172) | `StationEntity::takeHeatDamage` `Core/Entities/StationEntity.cpp:2201` | ✅ |
| `-[StationEntity allegiance]` (1179) | `StationEntity::getAllegiance` `Core/Entities/StationEntity.cpp:2207` | ✅ |
| `-[StationEntity setAllegiance:]` (1184) | `StationEntity::setAllegiance` `Core/Entities/StationEntity.cpp:2209` | ✅ |
| `-[StationEntity alertLevel]` (1190) | `StationEntity::getAlertLevel` `Core/Entities/StationEntity.cpp:2214` | ✅ |
| `-[StationEntity setAlertLevel:signallingScript:]` (1195) | `StationEntity::setAlertLevel` `Core/Entities/StationEntity.cpp:2216` | ✅ |
| `-[StationEntity launchIndependentShip:]` (1225) | `StationEntity::launchIndependentShip` `Core/Entities/StationEntity.cpp:104` (returns Object node(s)) | ⚠️ |
| `-[StationEntity increaseAlertLevel]` (1300) | `StationEntity::increaseAlertLevel` `Core/Entities/StationEntity.cpp:2253` | ✅ |
| `-[StationEntity decreaseAlertLevel]` (1306) | `StationEntity::decreaseAlertLevel` `Core/Entities/StationEntity.cpp:2260` | ✅ |
| `-[StationEntity launchPolice]` (1312) | `StationEntity::launchPolice` `Core/Entities/StationEntity.cpp:201` (returns Object node(s)) | ⚠️ |
| `-[StationEntity launchDefenseShip]` (1369) | `StationEntity::launchDefenseShip` `Core/Entities/StationEntity.cpp:278` | ✅ |
| `-[StationEntity launchScavenger]` (1464) | `StationEntity::launchScavenger` `Core/Entities/StationEntity.cpp:410` | ✅ |
| `-[StationEntity launchMiner]` (1506) | `StationEntity::launchMiner` `Core/Entities/StationEntity.cpp:468` | ✅ |
| `-[StationEntity launchPirateShip]` (1552) | `StationEntity::launchPirateShip` `Core/Entities/StationEntity.cpp:527` | ✅ |
| `-[StationEntity launchShuttle]` (1606) | `StationEntity::launchShuttle` `Core/Entities/StationEntity.cpp:601` | ✅ |
| `-[StationEntity launchEscort]` (1639) | `StationEntity::launchEscort` `Core/Entities/StationEntity.cpp:643` | ✅ |
| `-[StationEntity launchPatrol]` (1665) | `StationEntity::launchPatrol` `Core/Entities/StationEntity.cpp:677` | ✅ |
| `-[StationEntity launchShipWithRole:]` (1715) | `StationEntity::launchShipWithRole` `Core/Entities/StationEntity.cpp:740` | ✅ |
| `-[StationEntity becomeExplosion]` (1737) | `StationEntity::becomeExplosion` `Core/Entities/StationEntity.cpp:2267` | ✅ |
| `-[StationEntity becomeEnergyBlast]` (1764) | `StationEntity::becomeEnergyBlast` `Core/Entities/StationEntity.cpp:2299` | ✅ |
| `-[StationEntity becomeLargeExplosion:]` (1771) | `StationEntity::becomeLargeExplosion` `Core/Entities/StationEntity.cpp:2304` | ✅ |
| `-[StationEntity acceptPatrolReportFrom:]` (1778) | `StationEntity::acceptPatrolReportFrom` `Core/Entities/StationEntity.cpp:2310` | ✅ |
| `-[StationEntity acceptDockingClearanceRequestFrom:]` (1785) | `StationEntity::acceptDockingClearanceRequestFrom` `Core/Entities/StationEntity.cpp:2316` | ✅ |
| `-[StationEntity currentlyInDockingQueues]` (1981) | `StationEntity::currentlyInDockingQueues` `Core/Entities/StationEntity.cpp:2594` | ✅ |
| `-[StationEntity currentlyInLaunchingQueues]` (1993) | `StationEntity::currentlyInLaunchingQueues` `Core/Entities/StationEntity.cpp:2604` | ✅ |
| `-[StationEntity requiresDockingClearance]` (2004) | `StationEntity::getRequiresDockingClearance` `Core/Entities/StationEntity.cpp:1181` | ✅ |
| `-[StationEntity setRequiresDockingClearance:]` (2009) | `StationEntity::setRequiresDockingClearance` `Core/Entities/StationEntity.cpp:1185` | ✅ |
| `-[StationEntity allowsFastDocking]` (2014) | `StationEntity::getAllowsFastDocking` `Core/Entities/StationEntity.cpp:1189` | ✅ |
| `-[StationEntity setAllowsFastDocking:]` (2019) | `StationEntity::setAllowsFastDocking` `Core/Entities/StationEntity.cpp:1191` | ✅ |
| `-[StationEntity allowsAutoDocking]` (2024) | `StationEntity::getAllowsAutoDocking` `Core/Entities/StationEntity.cpp:1195` | ✅ |
| `-[StationEntity setAllowsAutoDocking:]` (2029) | `StationEntity::setAllowsAutoDocking` `Core/Entities/StationEntity.cpp:1197` | ✅ |
| `-[StationEntity allowsSaving]` (2034) | `StationEntity::getAllowsSaving` `Core/Entities/StationEntity.cpp:1201` | ✅ |
| `-[StationEntity isRotatingStation]` (2040) | `StationEntity::isRotatingStation` `Core/Entities/StationEntity.cpp:1206` | ✅ |
| `-[StationEntity marketOverrideName]` (2047) | `StationEntity::marketOverrideName` `Core/Entities/StationEntity.cpp:1217` | ✅ |
| `-[StationEntity hasShipyard]` (2057) | `StationEntity::hasShipyard` `Core/Entities/StationEntity.cpp:1228` | ✅ |
| `-[StationEntity generateShipyard]` (2078) | `StationEntity::generateShipyard()` `Core/Entities/StationEntity.cpp:1251` | ✅ |
| `-[StationEntity generateShipyard:]` (2083) | `StationEntity::generateShipyard(OOTechLevelID)` `Core/Entities/StationEntity.cpp:1255` | ✅ |
| `-[StationEntity suppressArrivalReports]` (2102) | `StationEntity::suppressArrivalReports` `Core/Entities/StationEntity.cpp:1288` | ✅ |
| `-[StationEntity setSuppressArrivalReports:]` (2107) | `StationEntity::setSuppressArrivalReports` `Core/Entities/StationEntity.cpp:1292` | ✅ |
| `-[StationEntity hasBreakPattern]` (2112) | `StationEntity::getHasBreakPattern` `Core/Entities/StationEntity.cpp:1296` | ✅ |
| `-[StationEntity setHasBreakPattern:]` (2117) | `StationEntity::setHasBreakPattern` `Core/Entities/StationEntity.cpp:1298` | ✅ |
| `-[StationEntity descriptionComponents]` (2122) | `StationEntity::descriptionComponents` `Core/Entities/StationEntity.cpp:1302` | ✅ |
| `-[StationEntity dumpSelfState]` (2127) | `StationEntity::dumpSelfState` `Core/Entities/StationEntity.cpp:1307` | ✅ |

**Differences:**

- ⚠️ **low** (still open; reclassified from ❌, the container now documents it) — `_shipsOnHold` is an insertion-ordered `oo::WeakSet`; upstream `OOWeakSet` enumerated in `NSMutableSet` pointer-hash order. `oofnd/WeakSet.hpp:28-30` calls insertion order "one deliberate strengthening". So the order of `DOCKING_ABORTED`/`stationWithdrewDockingClearance` in abortAllDockings, of `enterDock:` in autoDockShipsOnHold, and of the dumpSelfState listing is deterministic where upstream's varied run to run — upstream `Core/Entities/StationEntity.m:320-325,345-349,2180-2184` ↔ port `Core/Entities/StationEntity.cpp:1448-1455,1481-1484,1376-1388`
- ⚠️ **low** (still open) — `launchIndependentShip` and `launchPolice` return `oo::PList` Object node(s), not `ShipEntity*`/`NSArray`, per the "called by name" comments; the selection and side effects are the same — upstream `Core/Entities/StationEntity.m:1225,1312` ↔ port `Core/Entities/StationEntity.cpp:104,201`
- ➖ **low** (still open) — `dockSubEntityEnumerator` is replaced by `dockSubEntities()`, a snapshot of held subentity refs filtered by `isDock`. Every former enumerator loop iterates the snapshot, so a dock added or removed mid-loop is still or not yet visited — upstream `Core/Entities/StationEntity.m:260` ↔ port `Core/Entities/StationEntity.cpp:983-991`
- ✅ subtle — launchShip's "just use the last one" fallback is dead in both: upstream's exhausted enumerator left `sub` nil, and the port keeps it dead on purpose (comment) — upstream `Core/Entities/StationEntity.m:303-307` ↔ port `Core/Entities/StationEntity.cpp:1429-1437`
- ✅ subtle — launchDefenseShip's retry of `default_defense_ship_role` was a pointer comparison (true only when shipdata supplied `defense_ship_role`); the port's `shipdataSuppliedRole` flag gives the extra `newShipWithRole` call (and its RNG draws) in the same cases — upstream `Core/Entities/StationEntity.m:1409-1415` ↔ port `Core/Entities/StationEntity.cpp:325-342`
- ✅ subtle — launchEscort returns a pointer whose last owner (the local `shared_ptr`) goes at return when the ship was not queued; upstream released before returning. Same latent dangling return in both — upstream `Core/Entities/StationEntity.m:1657-1658` ↔ port `Core/Entities/StationEntity.cpp:670-674`
- ✅ subtle — legalStatusOfManifest dereferences `getLocalMarket()` and `manifest` without null checks; upstream messaged nil and got 0. Reachable only if the main station runs with no `UNIVERSE commodityMarket` — upstream `Core/Entities/StationEntity.m:150-163` ↔ port `Core/Entities/StationEntity.cpp:869-882`
- ✅ subtle — getPlanet does `dynamic_cast<OOPlanetEntity*>`, so a reused UID naming a non-planet gives null (upstream returned it typed as a planet); isRotatingStation returns NO for a non-string `roles` (upstream raised an unrecognised selector) and still YES for an absent `roles` — port `Core/Entities/StationEntity.cpp:961-965,1206-1215`
- ✅ subtle — takeEnergyDamage reads the attacker's bounty through `oo::ToShip(other)` (0 for a non-ship); upstream sent `-bounty` to it. Bounty 64/96, ×1.5 when already at least that, then markAsOffender, setPrimaryAggressor, setFoundTarget, launchPolice, in upstream's order — upstream `Core/Entities/StationEntity.m:1116-1156` ↔ port `Core/Entities/StationEntity.cpp:2131-2188`
- ✅ note — Re-read against upstream with matching constants: dock pick by fewest queued under a cap of 100, `willOpenDockingPortFor` for DOCK_CLOSED, `alldockstoosmall`/TRY_AGAIN_LATER fallback; hold on `\|v\|² > 1`, pitch/yaw `> 0.01`, roll `> 0.01` with an off-centre dock; fugitive refusal at `legalStatus > 50`; two launch-queue threshold passes to 16; shuttles `ranrot&3`, 900 s, offset `(ranrot&63)*15`; traders `3+(ranrot&7)`, `3600/n`, first in 60 s; patrol 300 s; police `i < 4 && defenders_launched < max_police` with `(Ranrot&3)+9 < TL`; defence/patrol `(Ranrot&7)+6 <= TL`, TL 6 when NSNotFound; pirates bounty `10+floor(randf*20)`; defaults max_scavengers/max_defense_ships 3, `equipment_price_factor` floor 0.5; fuzzy `has_npc_traffic`/`has_patrol_ships`/`has_shipyard`; alert clamp GREEN..RED then `alertConditionChanged(new, old)` then the *_ALERT message — upstream `StationEntity.m` passim ↔ port `StationEntity.cpp` passim

