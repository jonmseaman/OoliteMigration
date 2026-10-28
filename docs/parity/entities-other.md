# Parity findings: Other entities (planets, effects, particles, base Entity)

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## DustEntity

<a id="dustentity"></a>
Upstream `src/Core/Entities/DustEntity.m` ↔ `Core/Entities/DustEntity.cpp`

**Status:** done — 14 rows: 13 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[DustEntity init]` (62) | `DustEntity::init` `Core/Entities/DustEntity.cpp:83` | ✅ |
| `-[DustEntity dealloc]` (113) | `DustEntity::~DustEntity` `Core/Entities/DustEntity.cpp:78` (members release) | ✅ |
| `-[DustEntity setDustColor:]` (127) | `DustEntity::setDustColor` `Core/Entities/DustEntity.cpp:131` | ✅ |
| `-[DustEntity dustColor]` (135) | `DustEntity::dustColor` `Core/Entities/DustEntity.cpp:139` | ✅ |
| `-[DustEntity canCollide]` (140) | `DustEntity::canCollide` `Core/Entities/DustEntity.cpp:144` | ✅ |
| `-[DustEntity updateCameraRelativePosition]` (145) | `DustEntity::updateCameraRelativePosition` `Core/Entities/DustEntity.cpp:149` | ✅ |
| `-[DustEntity update:]` (151) | `DustEntity::update` `Core/Entities/DustEntity.cpp:155` | ✅ |
| `-[DustEntity shader]` (187) | `DustEntity::getShader` `Core/Entities/DustEntity.cpp:191` | ❌ |
| `-[DustEntity offsetPlayerPosition]` (227) | `DustEntity::offsetPlayerPosition` `Core/Entities/DustEntity.cpp:234` | ✅ |
| `-[DustEntity checkShaderMode]` (235) | `DustEntity::checkShaderMode` `Core/Entities/DustEntity.cpp:242` | ✅ |
| `-[DustEntity warpVector]` (246) | `DustEntity::warpVector` `Core/Entities/DustEntity.cpp:253` | ✅ |
| `-[DustEntity drawImmediate:translucent:]` (251) | `DustEntity::drawImmediate` `Core/Entities/DustEntity.cpp:258` | ✅ |
| `-[DustEntity resetGraphicsState]` (395) | `DustEntity::resetGraphicsState` `Core/Entities/DustEntity.cpp:409` | ✅ |
| `-[DustEntity descriptionForObjDump]` (411) | `DustEntity::descriptionForObjDump` `Core/Entities/DustEntity.cpp:425` | ✅ |

**Differences:**

- ❌ **low** — Upstream builds the uniform list with `-initWithObjects:uWarp, uOffsetPlayerPosition, nil`, so if `uWarp` fails to initialise (no `uWarp` uniform in an overridden `oolite-dust.vertex`), the list is empty and `uOffsetPlayerPosition` is never applied either. The port pushes both and skips only the null one, so `uOffsetPlayerPosition` still applies — upstream `Core/Entities/DustEntity.m:219` ↔ port `Core/Entities/DustEntity.cpp:227`
- Subtle (✅): neither side sets `color_fv` in `-init`. It stays zero until `setDustColor` is called — upstream `Core/Entities/DustEntity.m:93` ↔ port `Core/Entities/DustEntity.cpp:114`

## Entity

<a id="entity"></a>
Upstream `src/Core/Entities/Entity.m` ↔ `Core/Entities/Entity.cpp`

**Status:** done — 106 rows: 105 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[Entity init]` (64) | `Entity::init` `Core/Entities/Entity.cpp:71` | ✅ |
| `-[Entity dealloc]` (98) | `Entity::willDispose` `Core/Entities/Entity.cpp:99` | ✅ |
| `-[Entity descriptionComponents]` (115) | `Entity::descriptionComponents` `Core/Entities/Entity.cpp:144` | ✅ |
| `-[Entity sessionID]` (120) | `Entity::sessionID` `Core/Entities/Entity.cpp:150` | ✅ |
| `-[Entity isShip]` (125) | `Entity::getIsShip` `Core/Entities/Entity.cpp:155` | ✅ |
| `-[Entity isDock]` (130) | `Entity::isDock` `Core/Entities/Entity.cpp:160` | ✅ |
| `-[Entity isStation]` (135) | `Entity::getIsStation` `Core/Entities/Entity.cpp:165` | ✅ |
| `-[Entity isSubEntity]` (140) | `Entity::getIsSubEntity` `Core/Entities/Entity.cpp:170` | ✅ |
| `-[Entity isPlayer]` (145) | `Entity::getIsPlayer` `Core/Entities/Entity.cpp:175` | ✅ |
| `-[Entity isPlanet]` (150) | `Entity::isPlanet` `Core/Entities/Entity.cpp:180` | ✅ |
| `-[Entity isSun]` (155) | `Entity::isSun` `Core/Entities/Entity.cpp:185` | ✅ |
| `-[Entity isSunlit]` (160) | `Entity::getIsSunlit` `Core/Entities/Entity.cpp:190` | ✅ |
| `-[Entity isStellarObject]` (165) | `Entity::isStellarObject` `Core/Entities/Entity.cpp:195` | ✅ |
| `-[Entity isSky]` (170) | `Entity::isSky` `Core/Entities/Entity.cpp:200` | ✅ |
| `-[Entity isWormhole]` (175) | `Entity::getIsWormhole` `Core/Entities/Entity.cpp:205` | ✅ |
| `-[Entity isEffect]` (180) | `Entity::isEffect` `Core/Entities/Entity.cpp:210` | ✅ |
| `-[Entity isVisualEffect]` (185) | `Entity::getIsVisualEffect` `Core/Entities/Entity.cpp:215` | ✅ |
| `-[Entity isWaypoint]` (190) | `Entity::isWaypoint` `Core/Entities/Entity.cpp:220` | ✅ |
| `-[Entity validForAddToUniverse]` (195) | `Entity::validForAddToUniverse` `Core/Entities/Entity.cpp:225` | ✅ |
| `-[Entity addToLinkedLists]` (207) | `Entity::addToLinkedLists` `Core/Entities/Entity.cpp:237` | ✅ |
| `-[Entity removeFromLinkedLists]` (269) | `Entity::removeFromLinkedLists` `Core/Entities/Entity.cpp:300` | ✅ |
| `-[Entity checkLinkedLists]` (321) | `Entity::checkLinkedLists` `Core/Entities/Entity.cpp:353` | ✅ |
| `-[Entity updateLinkedLists]` (393) | `Entity::updateLinkedLists` `Core/Entities/Entity.cpp:425` | ✅ |
| `-[Entity wasAddedToUniverse]` (489) | `Entity::wasAddedToUniverse` `Core/Entities/Entity.cpp:523` | ✅ |
| `-[Entity wasRemovedFromUniverse]` (494) | `Entity::wasRemovedFromUniverse` `Core/Entities/Entity.cpp:528` | ✅ |
| `-[Entity warnAboutHostiles]` (499) | `Entity::warnAboutHostiles` `Core/Entities/Entity.cpp:533` | ✅ |
| `-[Entity collisionRegion]` (505) | `Entity::getCollisionRegion` `Core/Entities/Entity.cpp:539` | ✅ |
| `-[Entity setCollisionRegion:]` (510) | `Entity::setCollisionRegion` `Core/Entities/Entity.cpp:544` | ✅ |
| `-[Entity setUniversalID:]` (517) | `Entity::setUniversalID` `Core/Entities/Entity.cpp:549` | ✅ |
| `-[Entity universalID]` (522) | `Entity::getUniversalID` `Core/Entities/Entity.cpp:554` | ✅ |
| `-[Entity throwingSparks]` (527) | `Entity::throwingSparks` `Core/Entities/Entity.cpp:559` | ✅ |
| `-[Entity setThrowSparks:]` (532) | `Entity::setThrowSparks` `Core/Entities/Entity.cpp:564` | ✅ |
| `-[Entity throwSparks]` (537) | `Entity::throwSparks` `Core/Entities/Entity.cpp:569` | ✅ |
| `-[Entity setOwner:]` (542) | `Entity::setOwner` `Core/Entities/Entity.cpp:574` | ✅ |
| `-[Entity owner]` (548) | `Entity::owner` `Core/Entities/Entity.cpp:579` | ✅ |
| `-[Entity parentEntity]` (553) | `Entity::parentEntity` `Core/Entities/Entity.cpp:597` | ✅ |
| `-[Entity superShaderBindingTarget]` (561) | `Entity::superShaderBindingTarget` `Core/Entities/Entity.cpp:605` | ✅ |
| `-[Entity rootShipEntity]` (566) | `Entity::rootShipEntity` `Core/Entities/Entity.cpp:610` | ✅ |
| `-[Entity position]` (576) | `Entity::getPosition` `Core/Entities/Entity.cpp:620` | ✅ |
| `-[Entity cameraRelativePosition]` (581) | `Entity::getCameraRelativePosition` `Core/Entities/Entity.cpp:625` | ✅ |
| `-[Entity cameraRangeFront]` (586) | `Entity::cameraRangeFront` `Core/Entities/Entity.cpp:630` | ✅ |
| `-[Entity cameraRangeBack]` (591) | `Entity::cameraRangeBack` `Core/Entities/Entity.cpp:635` | ✅ |
| `-[Entity relativePosition]` (598) | `Entity::relativePosition` `Core/Entities/Entity.cpp:642` | ✅ |
| `-[Entity vectorTo:]` (603) | `Entity::vectorTo` `Core/Entities/Entity.cpp:647` | ✅ |
| `-[Entity setPosition:]` (608) | `Entity::setPosition` `Core/Entities/Entity.cpp:653` | ✅ |
| `-[Entity setPositionX:y:z:]` (614) | `Entity::setPositionX` `Core/Entities/Entity.cpp:659` | ✅ |
| `-[Entity updateCameraRelativePosition]` (622) | `Entity::updateCameraRelativePosition` `Core/Entities/Entity.cpp:667` | ✅ |
| `-[Entity absolutePositionForSubentity]` (627) | `Entity::absolutePositionForSubentity` `Core/Entities/Entity.cpp:672` | ✅ |
| `-[Entity absolutePositionForSubentityOffset:]` (632) | `Entity::absolutePositionForSubentityOffset` `Core/Entities/Entity.cpp:677` | ✅ |
| `-[Entity zeroDistance]` (648) | `Entity::zeroDistance` `Core/Entities/Entity.cpp:693` | ✅ |
| `-[Entity camZeroDistance]` (653) | `Entity::camZeroDistance` `Core/Entities/Entity.cpp:698` | ✅ |
| `-[Entity compareZeroDistance:]` (658) | `Entity::compareZeroDistance` `Core/Entities/Entity.cpp:703` | ✅ |
| `-[Entity boundingBox]` (666) | `Entity::getBoundingBox` `Core/Entities/Entity.cpp:711` | ✅ |
| `-[Entity mass]` (671) | `Entity::getMass` `Core/Entities/Entity.cpp:716` | ✅ |
| `-[Entity setOrientation:]` (676) | `Entity::setOrientation` `Core/Entities/Entity.cpp:721` | ✅ |
| `-[Entity orientation]` (682) | `Entity::getOrientation` `Core/Entities/Entity.cpp:727` | ✅ |
| `-[Entity normalOrientation]` (687) | `Entity::normalOrientation` `Core/Entities/Entity.cpp:732` | ✅ |
| `-[Entity setNormalOrientation:]` (692) | `Entity::setNormalOrientation` `Core/Entities/Entity.cpp:737` | ✅ |
| `-[Entity orientationChanged]` (697) | `Entity::orientationChanged` `Core/Entities/Entity.cpp:742` | ✅ |
| `-[Entity setVelocity:]` (703) | `Entity::setVelocity` `Core/Entities/Entity.cpp:748` | ✅ |
| `-[Entity velocity]` (708) | `Entity::getVelocity` `Core/Entities/Entity.cpp:753` | ✅ |
| `-[Entity speed]` (713) | `Entity::speed` `Core/Entities/Entity.cpp:758` | ✅ |
| `-[Entity distanceTravelled]` (718) | `Entity::getDistanceTravelled` `Core/Entities/Entity.cpp:763` | ✅ |
| `-[Entity setDistanceTravelled:]` (723) | `Entity::setDistanceTravelled` `Core/Entities/Entity.cpp:768` | ✅ |
| `-[Entity setStatus:]` (728) | `Entity::setStatus` `Core/Entities/Entity.cpp:773` | ✅ |
| `-[Entity status]` (733) | `Entity::status` `Core/Entities/Entity.cpp:778` | ✅ |
| `-[Entity setScanClass:]` (738) | `Entity::setScanClass` `Core/Entities/Entity.cpp:783` | ✅ |
| `-[Entity scanClass]` (743) | `Entity::getScanClass` `Core/Entities/Entity.cpp:788` | ✅ |
| `-[Entity setEnergy:]` (748) | `Entity::setEnergy` `Core/Entities/Entity.cpp:793` | ✅ |
| `-[Entity energy]` (753) | `Entity::getEnergy` `Core/Entities/Entity.cpp:798` | ✅ |
| `-[Entity setMaxEnergy:]` (758) | `Entity::setMaxEnergy` `Core/Entities/Entity.cpp:803` | ✅ |
| `-[Entity maxEnergy]` (763) | `Entity::getMaxEnergy` `Core/Entities/Entity.cpp:808` | ✅ |
| `-[Entity applyRoll:andClimb:]` (768) | `Entity::applyRoll(roll, climb)` `Core/Entities/Entity.cpp:813` | ✅ |
| `-[Entity applyRoll:climb:andYaw:]` (781) | `Entity::applyRoll(roll, climb, yaw)` `Core/Entities/Entity.cpp:826` | ✅ |
| `-[Entity moveForward:]` (796) | `Entity::moveForward` `Core/Entities/Entity.cpp:841` | ✅ |
| `-[Entity rotationMatrix]` (803) | `Entity::rotationMatrix` `Core/Entities/Entity.cpp:848` | ✅ |
| `-[Entity drawRotationMatrix]` (808) | `Entity::drawRotationMatrix` `Core/Entities/Entity.cpp:853` | ✅ |
| `-[Entity transformationMatrix]` (813) | `Entity::transformationMatrix` `Core/Entities/Entity.cpp:858` | ✅ |
| `-[Entity drawTransformationMatrix]` (819) | `Entity::drawTransformationMatrix` `Core/Entities/Entity.cpp:864` | ✅ |
| `-[Entity canCollide]` (825) | `Entity::canCollide` `Core/Entities/Entity.cpp:870` | ✅ |
| `-[Entity collisionRadius]` (830) | `Entity::collisionRadius` `Core/Entities/Entity.cpp:875` | ✅ |
| `-[Entity frustumRadius]` (835) | `Entity::frustumRadius` `Core/Entities/Entity.cpp:880` | ✅ |
| `-[Entity setCollisionRadius:]` (840) | `Entity::setCollisionRadius` `Core/Entities/Entity.cpp:885` | ✅ |
| `-[Entity collisionArray]` (845) | `Entity::getCollidingEntities` `Core/Entities/Entity.cpp:890` (`std::vector<oo::EntityHold>*`) | ✅ |
| `-[Entity update:]` (850) | `Entity::update` `Core/Entities/Entity.cpp:895` | ✅ |
| `-[Entity applyVelocity:]` (878) | `Entity::applyVelocity` `Core/Entities/Entity.cpp:925` | ✅ |
| `-[Entity checkCloseCollisionWith:]` (883) | `Entity::checkCloseCollisionWith` `Core/Entities/Entity.cpp:930` | ✅ |
| `-[Entity findCollisionRadius]` (888) | `Entity::findCollisionRadius` `Core/Entities/Entity.cpp:935` | ✅ |
| `-[Entity drawImmediate:translucent:]` (894) | `Entity::drawImmediate` `Core/Entities/Entity.cpp:941` | ✅ |
| `-[Entity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (899) | `Entity::takeEnergyDamage` `Core/Entities/Entity.cpp:946` | ✅ |
| `-[Entity dumpState]` (903) | `Entity::dumpState` `Core/Entities/Entity.cpp:950` | ✅ |
| `-[Entity dumpSelfState]` (918) | `Entity::dumpSelfState` `Core/Entities/Entity.cpp:966` | ✅ |
| `-[Entity subEntityReallyDied:]` (958) | `Entity::subEntityReallyDied` `Core/Entities/Entity.cpp:1019` | ❌ |
| `-[Entity lastDrawCounter]` (963) | `Entity::getLastDrawCounter` `Core/Entities/Entity.cpp:1024` | ✅ |
| `-[Entity setLastDrawCounter:]` (968) | `Entity::setLastDrawCounter` `Core/Entities/Entity.cpp:1029` | ✅ |
| `-[Entity universalTime]` (975) | `Entity::universalTime` `Core/Entities/Entity.cpp:1036` | ✅ |
| `-[Entity spawnTime]` (980) | `Entity::getSpawnTime` `Core/Entities/Entity.cpp:1041` | ✅ |
| `-[Entity timeElapsedSinceSpawn]` (985) | `Entity::timeElapsedSinceSpawn` `Core/Entities/Entity.cpp:1046` | ✅ |
| `-[Entity setAtmosphereFogging:]` (990) | `Entity::setAtmosphereFogging` `Core/Entities/Entity.cpp:1051` | ✅ |
| `-[Entity fogUniform]` (996) | `Entity::fogUniform` `Core/Entities/Entity.cpp:1056` | ✅ |
| `-[Entity descriptionForObjDumpBasic]` (1002) | `Entity::descriptionForObjDumpBasic` `Core/Entities/Entity.cpp:1062` | ✅ |
| `-[Entity descriptionForObjDump]` (1013) | `Entity::descriptionForObjDump` `Core/Entities/Entity.cpp:1072` | ✅ |
| `-[Entity allTextures]` (1022) | `Entity::allTextures` `Core/Entities/Entity.cpp:1081` | ✅ |
| `-[Entity isVisible]` (1028) | `Entity::isVisible` `Core/Entities/Entity.cpp:1087` | ✅ |
| `-[Entity isInSpace]` (1033) | `Entity::isInSpace` `Core/Entities/Entity.cpp:1092` | ✅ |
| `-[Entity isImmuneToBreakPatternHide]` (1050) | `Entity::getIsImmuneToBreakPatternHide` `Core/Entities/Entity.cpp:1109` | ✅ |

**Differences:**

- ❌ **low** — The `entity.bug` message prints `__PRETTY_FUNCTION__`. That was `-[Entity subEntityReallyDied:]` upstream and is now the C++ signature (`void Entity::subEntityReallyDied(ShipEntity*)`), so the log text changes — upstream `Core/Entities/Entity.m:960` ↔ port `Core/Entities/Entity.cpp:1021`
- Subtle (✅): position, orientation and velocity integration (`update`, `applyVelocity`, `moveForward`, `applyRoll*`, `orientationChanged`) match line for line. The order is the same: zero_distance/cam_zero_distance, then camera-relative position, then `applyVelocity` (not in `STATUS_COCKPIT_DISPLAY`), then `hasMoved`/`hasRotated`, then last position and orientation. `zero_distance`, `cam_zero_distance` and `collision_radius` stay `GLfloat` — upstream `Core/Entities/Entity.m:850-881` ↔ port `Core/Entities/Entity.cpp:895-928`
- Subtle (✅): a sub-entity with a dead owner now reads 0 for the zero distances, guarded explicitly, which matches `[nil zeroDistance]`. The `PLAYER->position` dereference when PLAYER is null is unguarded on both sides — upstream `Core/Entities/Entity.m:854,858` ↔ port `Core/Entities/Entity.cpp:900-905`
- Subtle (✅): the `universe.unremovedEntity` log moved from `-[Universe ensureEntityReallyRemoved:]` into `willDispose`, ahead of the call, and keeps the same text and condition. The `gLiveEntityCount++` that `-init` did now happens in `EntityHelpers.cpp:103,119` — upstream `Core/Universe.m:5128` ↔ port `Core/Entities/Entity.cpp:124-127`

## EntityShaderBindings

<a id="entityshaderbindings"></a>
Upstream `src/Core/Entities/EntityShaderBindings.m` ↔ `Core/Entities/EntityShaderBindings.cpp`

**Status:** done — 14 rows: 12 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[Entity(ShaderBindings) clock]` (35) | `Entity::clock` `Core/Entities/EntityShaderBindings.cpp:58` | ✅ |
| `-[Entity(ShaderBindings) pseudoFixedD100]` (41) | `Entity::pseudoFixedD100` `Core/Entities/EntityShaderBindings.cpp:64` | ✅ |
| `-[Entity(ShaderBindings) pseudoFixedD256]` (46) | `Entity::pseudoFixedD256` `Core/Entities/EntityShaderBindings.cpp:69` | ✅ |
| `-[Entity(ShaderBindings) systemGovernment]` (52) | `Entity::systemGovernment` `Core/Entities/EntityShaderBindings.cpp:75` | ✅ |
| `-[Entity(ShaderBindings) systemEconomy]` (57) | `Entity::systemEconomy` `Core/Entities/EntityShaderBindings.cpp:80` | ✅ |
| `-[Entity(ShaderBindings) systemTechLevel]` (62) | `Entity::systemTechLevel` `Core/Entities/EntityShaderBindings.cpp:85` | ✅ |
| `-[Entity(ShaderBindings) systemPopulation]` (67) | `Entity::systemPopulation` `Core/Entities/EntityShaderBindings.cpp:90` | ✅ |
| `-[Entity(ShaderBindings) systemProductivity]` (72) | `Entity::systemProductivity` `Core/Entities/EntityShaderBindings.cpp:95` | ✅ |
| *(added)* selector binding of `shader_entity_binding_methods` (`Resources/Config/whitelist.plist:353`, 27 names) on any entity | `kEntityShaderBindings` rows `Core/Entities/EntityShaderBindings.cpp:151-190, 282-296` | ✅ |
| *(added)* selector binding of `shader_ship_binding_methods` (`whitelist.plist:386`, ship only) | `kEntityShaderBindings` rows `Core/Entities/EntityShaderBindings.cpp:191-256, 275, 304-313` | ❌ |
| *(added)* selector binding of `shader_player_ship_binding_methods` (`whitelist.plist:437`, player/proxy) | `kEntityShaderBindings` rows `Core/Entities/EntityShaderBindings.cpp:257-278, 314` | ✅ |
| *(added)* selector binding of `shader_visual_effect_binding_methods` (`whitelist.plist:452`, effects) | `kEntityShaderBindings` rows `Core/Entities/EntityShaderBindings.cpp:231, 298-303, 318-329` | ✅ |
| *(added)* `OOUniformBindingPermitted()` (`Core/Entities/ShipEntity.m:12998`), the whitelist gate | `OOUniformBindingPermitted` `Core/Entities/ShipEntity.cpp:13734` | ✅ |
| *(added)* `[target class]` in the bind-failure logs (`Core/Materials/OOShaderUniform.m:153,356`, `OOShaderMaterial.m:328`) | `ShaderClassName` hook `Core/Entities/EntityShaderBindings.cpp:388` | ❌ |

**Differences:**

- ❌ **med** — **`laserColor` is lost.** Upstream whitelists it for ships (`whitelist.plist:420`; typed `"color"` in `shader-uniform-bindings.plist:57`), and `ShipEntity -laserColor` (`ShipEntity.m:10148`) returns an `OOColor`. That binds as `kOOShaderUniformTypeObject` and is uploaded as a vec4 of the colour components (`OOShaderUniform.m:506-515`). The port's member table has no `laserColor` row, although `ShipEntity::laserColor` exists (`ShipEntity.cpp:10713`) and the uniform code has a `kOOShaderUniformTypeColor` case for it (`OOShaderUniform.cpp:525`). The whitelist check passes, then `setEntityBindingTarget` finds no row, logs `shader.uniform.bind.failed … (target does not respond to selector)` and leaves the uniform inactive. Any ship shader that uses `laserColor` gets an unset (zero) uniform — upstream `Core/Materials/OOShaderUniform.m:506` ↔ port `Core/Entities/EntityShaderBindings.cpp:109,150-330`, `Core/Materials/OOShaderUniform.cpp:349-368`
- No other name is lost. I compared all four whitelist groups (port `whitelist.plist` is identical) against the 86 table rows: every whitelisted name except `laserColor` has a row. Whitelist gating matches `OOUniformBindingPermitted`, including `isPlayerLikeShip` → `PlayerEntity`/`ProxyPlayerEntity` casts. So rows whose `answers` predicate is broader than upstream's `respondsToSelector:` (`isBeacon`/`isJammingScanning` on waypoints and effects; `shaderFloat1…shaderVector2` on every entity) are still refused by the whitelist, as upstream — port `Core/Entities/ShipEntity.cpp:13743-13762`
- ❌ **low** — Bind-failure and unpermitted-method log lines print `[target class]`. Upstream that was the real class (`ShipEntity`, `PlayerEntity`, `OOPlanetEntity`, …). The port's hook always answers `"Entity"`, so text in `shader.uniform.bind.failed` / `shader.uniform.unpermittedMethod` changes — upstream `Core/Materials/OOShaderUniform.m:356` ↔ port `Core/Entities/EntityShaderBindings.cpp:388-391`
- Subtle (✅): uniform types come from each row's `kOOTypeEncoding<R>`, which matches upstream method return types (`escortCount` uint8_t, `messageTime`/`rangeToPrimaryTarget` double, `fuel` OOFuelQuantity, `missileCount`/`missileCapacity`/`trumbleCount` NSUInteger, `damage`/`legalStatus`/`tradeInFactor` int, `entityPersonalityInt` GLint, `pseudoFixedD100` unsigned → int, not the plist's "float"). `system*` with no PLAYER answer 0, as nil did — upstream `Core/Entities/ShipEntity.h:623-1206` ↔ port `Core/Entities/EntityShaderBindings.cpp:51-98`

## OOBreakPatternEntity

<a id="oobreakpatternentity"></a>
Upstream `src/Core/Entities/OOBreakPatternEntity.m` ↔ `Core/Entities/OOBreakPatternEntity.cpp`

**Status:** done — 10 rows: 8 ✅ 0 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOBreakPatternEntity initWithPolygonSides:startAngle:aspectRatio:]` (41) | `OOBreakPatternEntity::initWithPolygonSides` `Core/Entities/OOBreakPatternEntity.cpp:34` | ✅ |
| `+[OOBreakPatternEntity breakPatternWithPolygonSides:startAngle:aspectRatio:]` (78) | `OOBreakPatternEntity::breakPatternWithPolygonSides` `Core/Entities/OOBreakPatternEntity.cpp:70` | ✅ |
| `-[OOBreakPatternEntity setInnerColor:outerColor:]` (83) | `OOBreakPatternEntity::setInnerColor` `Core/Entities/OOBreakPatternEntity.cpp:77` | ✅ |
| `-[OOBreakPatternEntity setInnerColorComponents:outerColorComponents:]` (91) | `OOBreakPatternEntity::setInnerColorComponents` `Core/Entities/OOBreakPatternEntity.cpp:88` | ✅ |
| `-[OOBreakPatternEntity setLifetime:]` (101) | `OOBreakPatternEntity::setLifetime` `Core/Entities/OOBreakPatternEntity.cpp:98` | ✅ |
| `-[OOBreakPatternEntity update:]` (106) | `OOBreakPatternEntity::update` `Core/Entities/OOBreakPatternEntity.cpp:103` | ✅ |
| `-[OOBreakPatternEntity drawImmediate:translucent:]` (116) | `OOBreakPatternEntity::drawImmediate` `Core/Entities/OOBreakPatternEntity.cpp:114` | ✅ |
| `-[OOBreakPatternEntity canCollide]` (150) | `OOBreakPatternEntity::canCollide` `Core/Entities/OOBreakPatternEntity.cpp:148` | ✅ |
| `-[OOBreakPatternEntity isBreakPattern]` (155) | none; `Universe::removeEntity` uses `dynamic_cast<OOBreakPatternEntity*>` `Core/Universe.cpp:10114` | ➖ |
| `-[Entity(OOBreakPatternEntity) isBreakPattern]` (164) | none; `OOVisualEffectEntity::isBreakPattern` `Core/Entities/OOVisualEffectEntity.cpp:651` keeps the VE flag | ➖ |

**Differences:**

- ➖ **low** — `-isBreakPattern` on the ring and on the Entity category are gone. Their only real caller, `Universe -removeEntity:`'s `[entity isBreakPattern] && ![entity isVisualEffect]` breakPatternCounter test, is now `dynamic_cast<OOBreakPatternEntity*>`, which is equivalent. The by-name table answers `isBreakPattern` only for visual effects (`Core/Entities/OOEntityCalledByNameTable.h:2026`), so a by-name query on a core ring now answers NO where it answered YES. Scripts cannot reach a core ring — upstream `Core/Entities/OOBreakPatternEntity.m:155` ↔ port `Core/Universe.cpp:10114`
- Constants are unchanged: 3..128 sides, vertex radii 50/40, z −40/0, inner colour (1,0,0,0.5), outer colour (0,0,1,0.25), `BREAK_PATTERN_RING_SPEED` 200.

## OOECMBlastEntity

<a id="ooecmblastentity"></a>
Upstream `src/Core/Entities/OOECMBlastEntity.m` ↔ `Core/Entities/OOECMBlastEntity.cpp`

**Status:** done — 5 rows: 4 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOECMBlastEntity initFromShip:]` (45) | `OOECMBlastEntity::initFromShip` `Core/Entities/OOECMBlastEntity.cpp:60` + ctor `:48` | ✅ |
| `-[OOECMBlastEntity update:]` (63) | `OOECMBlastEntity::update` `Core/Entities/OOECMBlastEntity.cpp:68` | ✅ |
| `-[OOECMBlastEntity drawImmediate:translucent:]` (101) | `OOECMBlastEntity::drawImmediate` `Core/Entities/OOECMBlastEntity.cpp:107` | ✅ |
| `-[OOECMBlastEntity isECMBlast]` (109) | `OOECMBlastEntity::isECMBlast` `Core/Entities/OOECMBlastEntity.cpp:115` | ✅ |
| `-[Entity(OOECMBlastEntity) isECMBlast]` (118) | none (header says nothing sent it; bead oo-9ht.75) | ➖ |

**Differences:**

- ➖ **low** — the Entity category `-isECMBlast` was removed. Nothing upstream sent it — upstream `Core/Entities/OOECMBlastEntity.m:118` ↔ port `Core/Entities/OOECMBlastEntity.h:11`
- Gameplay check: `ECM_EFFECT_DURATION` 2.0, `ECM_PULSE_COUNT` 4, interval 0.5 s and `_blastsRemaining` `uint8_t` are all unchanged. Pulse radius is `clamp01((4−remaining+1)/4) × SCANNER_MAX_RANGE`, decremented before the event. The order is the same: `shipHitByECM(remaining, whom)`, then the `ECM` AI message, then `noticeECM`. Removal happens on `remaining==0 || !validShip`. All ✅.

## OOEntityWithDrawable

<a id="ooentitywithdrawable"></a>
Upstream `src/Core/Entities/OOEntityWithDrawable.m` ↔ `Core/Entities/OOEntityWithDrawable.cpp`

**Status:** done — 6 rows: 5 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOEntityWithDrawable dealloc]` (33) | `oo::Ref<OODrawable> drawable` member `Core/Entities/OOEntityWithDrawable.h:52` | ➖ |
| `-[OOEntityWithDrawable drawable]` (41) | `OOEntityWithDrawable::getDrawable` `Core/Entities/OOEntityWithDrawable.cpp:35` | ✅ |
| `-[OOEntityWithDrawable setDrawable:]` (46) | `OOEntityWithDrawable::setDrawable` `Core/Entities/OOEntityWithDrawable.cpp:40` | ✅ |
| `-[OOEntityWithDrawable findCollisionRadius]` (59) | `OOEntityWithDrawable::findCollisionRadius` `Core/Entities/OOEntityWithDrawable.cpp:56` | ✅ |
| `-[OOEntityWithDrawable drawImmediate:translucent:]` (64) | `OOEntityWithDrawable::drawImmediate` `Core/Entities/OOEntityWithDrawable.cpp:62` | ✅ |
| `-[OOEntityWithDrawable allTextures]` (116) | `OOEntityWithDrawable::allTextures` `Core/Entities/OOEntityWithDrawable.cpp:115` | ✅ |

**Differences:**

- ➖ **low** — `-dealloc` release is now RAII. The old drawable is still deferred via `OODrawableAutorelease`, as `[drawable autorelease]` was — upstream `Core/Entities/OOEntityWithDrawable.m:33` ↔ port `Core/Entities/OOEntityWithDrawable.cpp:43`
- Subtle (✅): the frustum clip radius calls the virtual `frustumRadius()` only for ships and visual effects, which are its only overrides (`ShipEntity.cpp:1186`, `OOVisualEffectEntity.cpp:245`). Other entities use `collision_radius`, as upstream does.

## OOExhaustPlumeEntity

<a id="ooexhaustplumeentity"></a>
Upstream `src/Core/Entities/OOExhaustPlumeEntity.m` ↔ `Core/Entities/OOExhaustPlumeEntity.cpp`

**Status:** done — 18 rows: 16 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOExhaustPlumeEntity exhaustForShip:withDefinition:andScale:]` (57) | `OOExhaustPlumeEntity::exhaustForShip` `Core/Entities/OOExhaustPlumeEntity.cpp:61` | ✅ |
| `-[OOExhaustPlumeEntity initForShip:withDefinition:andScale:]` (62) | `OOExhaustPlumeEntity::initForShip` `Core/Entities/OOExhaustPlumeEntity.cpp:69` | ✅ |
| `-[OOExhaustPlumeEntity scale]` (81) | `OOExhaustPlumeEntity::scale` `Core/Entities/OOExhaustPlumeEntity.cpp:90` | ✅ |
| `-[OOExhaustPlumeEntity setScale:]` (86) | `OOExhaustPlumeEntity::setScale` `Core/Entities/OOExhaustPlumeEntity.cpp:95` | ✅ |
| `-[OOExhaustPlumeEntity isExhaust]` (94) | `OOExhaustPlumeEntity::isExhaust` `Core/Entities/OOExhaustPlumeEntity.cpp:103` | ✅ |
| `-[OOExhaustPlumeEntity findCollisionRadius]` (99) | `OOExhaustPlumeEntity::findCollisionRadius` `Core/Entities/OOExhaustPlumeEntity.cpp:108` | ✅ |
| `-[OOExhaustPlumeEntity update:]` (104) | `OOExhaustPlumeEntity::update` `Core/Entities/OOExhaustPlumeEntity.cpp:113` | ✅ |
| `-[OOExhaustPlumeEntity drawSubEntityImmediate:translucent:]` (359) | `OOExhaustPlumeEntity::drawSubEntityImmediate` `Core/Entities/OOExhaustPlumeEntity.cpp:370` | ✅ |
| `-[OOExhaustPlumeEntity saveToLastFrame]` (542) | `OOExhaustPlumeEntity::saveToLastFrame` `Core/Entities/OOExhaustPlumeEntity.cpp:554` | ✅ |
| `-[OOExhaustPlumeEntity frameAtTime:fromFrame:]` (558) | `OOExhaustPlumeEntity::frameAtTime` `Core/Entities/OOExhaustPlumeEntity.cpp:570` | ✅ |
| `-[OOExhaustPlumeEntity resetPlume]` (610) | `OOExhaustPlumeEntity::resetPlume` `Core/Entities/OOExhaustPlumeEntity.cpp:622` | ✅ |
| `-[OOExhaustPlumeEntity rescaleBy:]` (631) | `OOExhaustPlumeEntity::rescaleBy(GLfloat)` `Core/Entities/OOExhaustPlumeEntity.cpp:643` | ✅ |
| `-[OOExhaustPlumeEntity rescaleBy:writeToCache:]` (636) | `OOExhaustPlumeEntity::rescaleBy(GLfloat,bool)` `Core/Entities/OOExhaustPlumeEntity.cpp:648` | ✅ |
| `-[OOExhaustPlumeEntity texture]` (642) | `OOExhaustPlumeEntity::texture` `Core/Entities/OOExhaustPlumeEntity.cpp:654` | ✅ |
| `+[OOExhaustPlumeEntity setUpTexture]` (647) | `OOExhaustPlumeEntity::setUpTexture` `Core/Entities/OOExhaustPlumeEntity.cpp:659` | ❌ |
| `+[OOExhaustPlumeEntity plumeTexture]` (659) | `OOExhaustPlumeEntity::plumeTexture` `Core/Entities/OOExhaustPlumeEntity.cpp:667` | ✅ |
| `+[OOExhaustPlumeEntity resetGraphicsState]` (666) | `OOExhaustPlumeEntity::resetGraphicsState` `Core/Entities/OOExhaustPlumeEntity.cpp:674` | ✅ |
| `-[Entity(OOExhaustPlume) isExhaust]` (676) | none (category removed) | ➖ |

**Differences:**

- ❌ **low** — `setUpTexture` registers a fresh `new PlumeTextureResetClient` each time the texture is recreated. Upstream registered the class pointer into a set, which is idempotent. The manager's `unordered_set` is keyed by pointer, so every graphics reset followed by a redraw adds one more client. The result is a small leak and N redundant (harmless) `resetGraphicsState` calls — upstream `Core/Entities/OOExhaustPlumeEntity.m:655` ↔ port `Core/Entities/OOExhaustPlumeEntity.cpp:663`
- ➖ **low** — the `Entity(OOExhaustPlume) -isExhaust` category was removed and the subclass keeps `isExhaust()` — upstream `Core/Entities/OOExhaustPlumeEntity.m:676`
- Subtle (✅): the definition is now `std::vector<std::string>` tokens read through `oo::PList::at<float>`. Out-of-range indices give 0, as `oo_floatAtIndex:` did (`oofnd/PList.hpp:258`). Geometry is unchanged: 16 frames, `kTimeStep` 0.05, i03/06/08/10 = −0.12/−0.25/−0.32/−0.40 × scale.z, fade levels 0.4/0.2/0.02, scale levels 1.0/0.8/0.6 with extra 0.8/0.5, z-scale clamp [0.5,2.0]→1. The RNG order is unchanged: one `ranrot_rand()%11`, then %50/%40/%25, then 24 `randf()`.

## OOExplosionCloudEntity

<a id="ooexplosioncloudentity"></a>
Upstream `src/Core/Entities/OOExplosionCloudEntity.m` ↔ `Core/Entities/OOExplosionCloudEntity.cpp`

**Status:** done — 6 rows: 5 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOExplosionCloudEntity initExplosionCloudWithEntity:size:andSettings:]` (57) | `OOExplosionCloudEntity::initExplosionCloudWithEntity` `Core/Entities/OOExplosionCloudEntity.cpp:57` | ✅ |
| `-[OOExplosionCloudEntity dealloc]` (160) | `oo::Ref` members (comment `:156`) | ➖ |
| `+[OOExplosionCloudEntity explosionCloudFromEntity:withSettings:]` (167) | `OOExplosionCloudEntity::explosionCloudFromEntity(Entity*, const PList&)` `Core/Entities/OOExplosionCloudEntity.cpp:158` | ✅ |
| `+[OOExplosionCloudEntity explosionCloudFromEntity:withSize:andSettings:]` (172) | `OOExplosionCloudEntity::explosionCloudFromEntity(Entity*, float, const PList&)` `Core/Entities/OOExplosionCloudEntity.cpp:166` | ✅ |
| `-[OOExplosionCloudEntity update:]` (177) | `OOExplosionCloudEntity::update` `Core/Entities/OOExplosionCloudEntity.cpp:174` | ✅ |
| `-[OOExplosionCloudEntity texture]` (247) | `OOExplosionCloudEntity::texture` `Core/Entities/OOExplosionCloudEntity.cpp:244` | ✅ |

**Differences:**

- ➖ **low** — `-dealloc` releases are now members — upstream `Core/Entities/OOExplosionCloudEntity.m:160` ↔ port `Core/Entities/OOExplosionCloudEntity.cpp:156`
- Subtle (✅): keys and defaults are identical: count 25 capped at 10 (detail ≤ SHADERS) or 25, size 2.5, growth_rate 1.5, alpha 0.85, brightness ≥ 1.0, duration 0.9, spread 1.0, texture `oolite-particle-cloud2.png`, color_order `rgb`. The velocity clamp is 1000 above 10⁶ m²/s². Speeds are 0.8–1.2 × size × spread. Per-particle draws happen in the base init, then 3 (or 1 for `white`) `randf()` per particle. A missing texture still yields no entity.

## OOFlashEffectEntity

<a id="ooflasheffectentity"></a>
Upstream `src/Core/Entities/OOFlashEffectEntity.m` ↔ `Core/Entities/OOFlashEffectEntity.cpp`

**Status:** done — 9 rows: 8 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOFlashEffectEntity initExplosionFlashWithPosition:velocity:size:]` (55) | `OOFlashEffectEntity::initExplosionFlashWithPosition` `Core/Entities/OOFlashEffectEntity.cpp:54` | ✅ |
| `-[OOFlashEffectEntity initLaserFlashWithPosition:velocity:color:]` (65) | `OOFlashEffectEntity::initLaserFlashWithPosition` `Core/Entities/OOFlashEffectEntity.cpp:65` | ✅ |
| `+[OOFlashEffectEntity explosionFlashFromEntity:]` (74) | `OOFlashEffectEntity::explosionFlashFromEntity` `Core/Entities/OOFlashEffectEntity.cpp:77` | ✅ |
| `+[OOFlashEffectEntity laserFlashWithPosition:velocity:color:]` (79) | `OOFlashEffectEntity::laserFlashWithPosition` `Core/Entities/OOFlashEffectEntity.cpp:84` | ✅ |
| `-[OOFlashEffectEntity initWithPosition:size:color:duration:]` (84) | `OOFlashEffectEntity::initWithPosition` `Core/Entities/OOFlashEffectEntity.cpp:91` | ✅ |
| `-[OOFlashEffectEntity update:]` (96) | `OOFlashEffectEntity::update` `Core/Entities/OOFlashEffectEntity.cpp:104` | ✅ |
| `-[OOFlashEffectEntity texture]` (115) | `OOFlashEffectEntity::texture` `Core/Entities/OOFlashEffectEntity.cpp:125` | ✅ |
| `+[OOFlashEffectEntity setUpTexture]` (122) | `OOFlashEffectEntity::setUpTexture` `Core/Entities/OOFlashEffectEntity.cpp:132` | ❌ |
| `+[OOFlashEffectEntity resetGraphicsState]` (134) | `OOFlashEffectEntity::resetGraphicsState` `Core/Entities/OOFlashEffectEntity.cpp:140` | ✅ |

**Differences:**

- ❌ **low** — each texture re-creation after a graphics reset registers a new `FlashTextureResetClient`. Upstream's class registration was idempotent. The result is accumulating clients and a leak — upstream `Core/Entities/OOFlashEffectEntity.m:130` ↔ port `Core/Entities/OOFlashEffectEntity.cpp:136`
- Subtle (✅): constants are identical: laser flash 0.3 s, size 1, alpha 1; explosion flash 0.4 s, alpha 0.5, growth `max(150×size, 600)`. The fade is in over 0.667 × duration and out over the rest.

## OOFlasherEntity

<a id="ooflasherentity"></a>
Upstream `src/Core/Entities/OOFlasherEntity.m` ↔ `Core/Entities/OOFlasherEntity.cpp`

**Status:** done — 22 rows: 19 ✅ 1 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOFlasherEntity flasherWithDictionary:]` (42) | `OOFlasherEntity::flasherWithDictionary` `Core/Entities/OOFlasherEntity.cpp:34` | ✅ |
| `-[OOFlasherEntity initWithDictionary:]` (47) | `OOFlasherEntity::initWithDictionary` `Core/Entities/OOFlasherEntity.cpp:41` | ✅ |
| `-[OOFlasherEntity dealloc]` (64) | `std::vector<oo::Ref<OOColor>> _colors` member | ➖ |
| `-[OOFlasherEntity setUpColors:]` (71) | `OOFlasherEntity::setUpColors` `Core/Entities/OOFlasherEntity.cpp:59` | ✅ |
| `-[OOFlasherEntity getCurrentColorComponents]` (82) | `OOFlasherEntity::getCurrentColorComponents` `Core/Entities/OOFlasherEntity.cpp:77` (+ `flasherColorAtIndex` `:72`) | ⚠️ |
| `-[OOFlasherEntity isActive]` (87) | `OOFlasherEntity::isActive` `Core/Entities/OOFlasherEntity.cpp:82` | ✅ |
| `-[OOFlasherEntity setActive:]` (92) | `OOFlasherEntity::setActive` `Core/Entities/OOFlasherEntity.cpp:87` | ✅ |
| `-[OOFlasherEntity color]` (97) | `OOFlasherEntity::color` `Core/Entities/OOFlasherEntity.cpp:92` | ✅ |
| `-[OOFlasherEntity frequency]` (105) | `OOFlasherEntity::frequency` `Core/Entities/OOFlasherEntity.cpp:100` | ✅ |
| `-[OOFlasherEntity setFrequency:]` (110) | `OOFlasherEntity::setFrequency` `Core/Entities/OOFlasherEntity.cpp:105` | ✅ |
| `-[OOFlasherEntity phase]` (115) | `OOFlasherEntity::phase` `Core/Entities/OOFlasherEntity.cpp:110` | ✅ |
| `-[OOFlasherEntity setPhase:]` (120) | `OOFlasherEntity::setPhase` `Core/Entities/OOFlasherEntity.cpp:115` | ✅ |
| `-[OOFlasherEntity fraction]` (125) | `OOFlasherEntity::fraction` `Core/Entities/OOFlasherEntity.cpp:120` | ✅ |
| `-[OOFlasherEntity setFraction:]` (130) | `OOFlasherEntity::setFraction` `Core/Entities/OOFlasherEntity.cpp:125` | ✅ |
| `-[OOFlasherEntity update:]` (135) | `OOFlasherEntity::update` `Core/Entities/OOFlasherEntity.cpp:130` | ✅ |
| `-[OOFlasherEntity drawImmediate:translucent:]` (173) | `OOFlasherEntity::drawImmediate` `Core/Entities/OOFlasherEntity.cpp:168` | ✅ |
| `-[OOFlasherEntity drawSubEntityImmediate:translucent:]` (180) | `OOFlasherEntity::drawSubEntityImmediate` `Core/Entities/OOFlasherEntity.cpp:175` | ✅ |
| `-[OOFlasherEntity isFlasher]` (187) | `OOFlasherEntity::isFlasher` `Core/Entities/OOFlasherEntity.cpp:182` | ✅ |
| `-[OOFlasherEntity findCollisionRadius]` (192) | `OOFlasherEntity::findCollisionRadius` `Core/Entities/OOFlasherEntity.cpp:187` | ✅ |
| `-[OOFlasherEntity rescaleBy:]` (197) | `OOFlasherEntity::rescaleBy(GLfloat)` `Core/Entities/OOFlasherEntity.cpp:192` | ✅ |
| `-[OOFlasherEntity rescaleBy:writeToCache:]` (202) | `OOFlasherEntity::rescaleBy(GLfloat,bool)` `Core/Entities/OOFlasherEntity.cpp:197` | ✅ |
| `-[Entity(OOFlasherEntityExtensions) isFlasher]` (212) | none (category removed) | ➖ |

**Differences:**

- ⚠️ **low** — with an empty colour list, upstream `[_colors objectAtIndex:0]` raised `NSRangeException`. The port's `flasherColorAtIndex` returns null, so the colour stays white (1,1,1); this is documented in the port comment. It is unreachable from shipdata, because `OOShipRegistry` guarantees at least one valid colour (`OOShipRegistry.m:1332-1348`) — upstream `Core/Entities/OOFlasherEntity.m:84` ↔ port `Core/Entities/OOFlasherEntity.cpp:71-80`
- Subtle (✅, low): `setUpColors` pushes a null `Ref` for a specifier that `colorWithDescription` rejects, where upstream `addObject:nil` raised. The registry pre-validates specifiers — upstream `Core/Entities/OOFlasherEntity.m:76` ↔ port `Core/Entities/OOFlasherEntity.cpp:64`
- ➖ **low** — the `Entity -isFlasher` category was removed — upstream `Core/Entities/OOFlasherEntity.m:212`
- Subtle (✅): frequency and phase are identical: `_frequency = frequency×2`, `wave = sinf(f·π·(t+phase))` (double `_time`), and colours switch on a rising negative half-wave. Threshold `cosf(bf·π)` and the brightness piecewise formula are unchanged. Defaults are size 1, frequency 1, phase 0, bright_fraction 0.5, initially_on YES, saturation 0.75.

## OOLaserShotEntity

<a id="oolasershotentity"></a>
Upstream `src/Core/Entities/OOLaserShotEntity.m` ↔ `Core/Entities/OOLaserShotEntity.cpp`

**Status:** done — 16 rows: 14 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOLaserShotEntity initLaserFromShip:direction:offset:]` (58) | `OOLaserShotEntity::initLaserFromShip` `Core/Entities/OOLaserShotEntity.cpp:70` | ✅ |
| `+[OOLaserShotEntity laserFromShip:direction:offset:]` (117) | `OOLaserShotEntity::laserFromShip` `Core/Entities/OOLaserShotEntity.cpp:126` | ✅ |
| `-[OOLaserShotEntity dealloc]` (122) | removed (comment `:133`) | ➖ |
| `-[OOLaserShotEntity descriptionComponents]` (129) | `OOLaserShotEntity::descriptionComponents` `Core/Entities/OOLaserShotEntity.cpp:135` | ✅ |
| `-[OOLaserShotEntity setColor:]` (134) | `OOLaserShotEntity::setColor` `Core/Entities/OOLaserShotEntity.cpp:141` | ✅ |
| `-[OOLaserShotEntity setRange:]` (142) | `OOLaserShotEntity::setRange` `Core/Entities/OOLaserShotEntity.cpp:150` | ✅ |
| `-[OOLaserShotEntity update:]` (148) | `OOLaserShotEntity::update` `Core/Entities/OOLaserShotEntity.cpp:156` | ✅ |
| `-[OOLaserShotEntity drawImmediate:translucent:]` (197) | `OOLaserShotEntity::drawImmediate` `Core/Entities/OOLaserShotEntity.cpp:206` | ✅ |
| `-[OOLaserShotEntity isEffect]` (255) | `OOLaserShotEntity::isEffect` `Core/Entities/OOLaserShotEntity.cpp:266` | ✅ |
| `-[OOLaserShotEntity canCollide]` (260) | `OOLaserShotEntity::canCollide` `Core/Entities/OOLaserShotEntity.cpp:271` | ✅ |
| `-[OOLaserShotEntity texture1]` (265) | `OOLaserShotEntity::texture1` `Core/Entities/OOLaserShotEntity.cpp:276` | ✅ |
| `-[OOLaserShotEntity texture2]` (270) | `OOLaserShotEntity::texture2` `Core/Entities/OOLaserShotEntity.cpp:281` | ✅ |
| `+[OOLaserShotEntity setUpTexture]` (275) | `OOLaserShotEntity::setUpTexture` `Core/Entities/OOLaserShotEntity.cpp:286` | ❌ |
| `+[OOLaserShotEntity innerTexture]` (293) | `OOLaserShotEntity::innerTexture` `Core/Entities/OOLaserShotEntity.cpp:296` | ✅ |
| `+[OOLaserShotEntity outerTexture]` (300) | `OOLaserShotEntity::outerTexture` `Core/Entities/OOLaserShotEntity.cpp:303` | ✅ |
| `+[OOLaserShotEntity resetGraphicsState]` (307) | `OOLaserShotEntity::resetGraphicsState` `Core/Entities/OOLaserShotEntity.cpp:310` | ✅ |

**Differences:**

- ❌ **low** — `setUpTexture` registers a new `ShotTextureResetClient` on every re-creation after a reset, where upstream registration was idempotent. This leaks and adds redundant reset calls — upstream `Core/Entities/OOLaserShotEntity.m:283` ↔ port `Core/Entities/OOLaserShotEntity.cpp:290`
- ➖ **low** — `-dealloc`'s `[self setColor:nil]` was dropped, which is unobservable — upstream `Core/Entities/OOLaserShotEntity.m:124` ↔ port `Core/Entities/OOLaserShotEntity.cpp:133`
- Subtle (✅): range and lifetime are identical: `_range = collision_radius = [srcEntity weaponRange]` (`getWeaponRange`), `kLaserDuration` 0.09 s, and removal when `_lifetime < 0`. Player shots are re-anchored each tick. Colour is `brightness 5 × rgb / 3` and alpha `0.45/5`. Widths are 0.4/1.8/3.6. Texture phase uses `/200` and `/500`. The facing rotations (aft π, port π/2, starboard −π/2) are unchanged.

## OOLightParticleEntity

<a id="oolightparticleentity"></a>
Upstream `src/Core/Entities/OOLightParticleEntity.m` ↔ `Core/Entities/OOLightParticleEntity.cpp`

**Status:** done — 14 rows: 13 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOLightParticleEntity initWithDiameter:]` (50) | `OOLightParticleEntity::initWithDiameter` `Core/Entities/OOLightParticleEntity.cpp:53` | ✅ |
| `-[OOLightParticleEntity diameter]` (69) | `OOLightParticleEntity::diameter` `Core/Entities/OOLightParticleEntity.cpp:71` | ✅ |
| `-[OOLightParticleEntity setDiameter:]` (74) | `OOLightParticleEntity::setDiameter` `Core/Entities/OOLightParticleEntity.cpp:76` | ✅ |
| `-[OOLightParticleEntity setColor:]` (79) | `OOLightParticleEntity::setColor(OOColor*)` `Core/Entities/OOLightParticleEntity.cpp:81` | ✅ |
| `-[OOLightParticleEntity setColor:alpha:]` (84) | `OOLightParticleEntity::setColor(OOColor*, GLfloat)` `Core/Entities/OOLightParticleEntity.cpp:88` | ✅ |
| `-[OOLightParticleEntity drawSubEntityImmediate:translucent:]` (90) | `OOLightParticleEntity::drawSubEntityImmediate` `Core/Entities/OOLightParticleEntity.cpp:94` | ✅ |
| `-[OOLightParticleEntity drawImmediate:translucent:]` (129) | `OOLightParticleEntity::drawImmediate` `Core/Entities/OOLightParticleEntity.cpp:135` | ✅ |
| `-[OOLightParticleEntity texture]` (282) | `OOLightParticleEntity::texture` `Core/Entities/OOLightParticleEntity.cpp:291` | ✅ |
| `+[OOLightParticleEntity setUpTexture]` (287) | `OOLightParticleEntity::setUpTexture` `Core/Entities/OOLightParticleEntity.cpp:296` | ❌ |
| `+[OOLightParticleEntity defaultParticleTexture]` (299) | `OOLightParticleEntity::defaultParticleTexture` `Core/Entities/OOLightParticleEntity.cpp:304` | ✅ |
| `+[OOLightParticleEntity resetGraphicsState]` (306) | `OOLightParticleEntity::resetGraphicsState` `Core/Entities/OOLightParticleEntity.cpp:311` | ✅ |
| `-[OOLightParticleEntity isEffect]` (312) | `OOLightParticleEntity::isEffect` `Core/Entities/OOLightParticleEntity.cpp:317` | ✅ |
| `-[OOLightParticleEntity canCollide]` (317) | `OOLightParticleEntity::canCollide` `Core/Entities/OOLightParticleEntity.cpp:322` | ✅ |
| `-[OOLightParticleEntity allTextures]` (323) | `OOLightParticleEntity::allTextures` `Core/Entities/OOLightParticleEntity.cpp:328` | ✅ |

**Differences:**

- ❌ **low** — `setUpTexture` adds a new `BlobTextureResetClient` each time the blob texture is recreated after a reset, where upstream's class registration was idempotent. This leaks and adds redundant calls — upstream `Core/Entities/OOLightParticleEntity.m:295` ↔ port `Core/Entities/OOLightParticleEntity.cpp:300`
- Subtle (✅): the owner walk drops the `!= NO_TARGET` test (NO_TARGET is 0, which equals null). An ownerless sub-entity under break-pattern hide still returns, because `[nil isImmuneToBreakPatternHide]` was NO. `no_draw_distance = (d/2)^√2 × NDDF² × (12 reduced / 36)` is unchanged.

## OOParticleSystem

<a id="ooparticlesystem"></a>
Upstream `src/Core/Entities/OOParticleSystem.m` ↔ `Core/Entities/OOParticleSystem.cpp`

**Status:** done — 16 rows: 14 ✅ 1 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOParticleSystem init]` (39) | protected default ctor `Core/Entities/OOParticleSystem.h:62` | ➖ |
| `-[OOParticleSystem initWithPosition:]` (48) | `OOParticleSystem::initWithPosition` `Core/Entities/OOParticleSystem.cpp:50` | ⚠️ |
| `-[OOParticleSystem descriptionComponents]` (87) | `OOParticleSystem::descriptionComponents` `Core/Entities/OOParticleSystem.cpp:91` | ✅ |
| `-[OOParticleSystem canCollide]` (92) | `OOParticleSystem::canCollide` `Core/Entities/OOParticleSystem.cpp:96` | ✅ |
| `-[OOParticleSystem checkCloseCollisionWith:]` (97) | `OOParticleSystem::checkCloseCollisionWith` `Core/Entities/OOParticleSystem.cpp:101` | ✅ |
| `-[OOParticleSystem update:]` (104) | `OOParticleSystem::update` `Core/Entities/OOParticleSystem.cpp:108` | ✅ |
| `-[OOParticleSystem drawImmediate:translucent:]` (136) | `OOParticleSystem::drawImmediate` `Core/Entities/OOParticleSystem.cpp:142` | ✅ |
| `-[OOParticleSystem isEffect]` (225) | `OOParticleSystem::isEffect` `Core/Entities/OOParticleSystem.cpp:232` | ✅ |
| `-[OOParticleSystem texture]` (230) | `OOParticleSystem::texture` `Core/Entities/OOParticleSystem.cpp:237` | ✅ |
| `-[OOParticleSystem allTextures]` (236) | `OOParticleSystem::allTextures` `Core/Entities/OOParticleSystem.cpp:243` | ✅ |
| `-[OOSmallFragmentBurstEntity initFragmentBurstFrom:velocity:size:]` (246) | `OOSmallFragmentBurstEntity::initFragmentBurstFrom` `Core/Entities/OOParticleSystem.cpp:251` | ✅ |
| `+[OOSmallFragmentBurstEntity fragmentBurstFromEntity:]` (272) | `OOSmallFragmentBurstEntity::fragmentBurstFromEntity` `Core/Entities/OOParticleSystem.cpp:276` | ✅ |
| `-[OOSmallFragmentBurstEntity update:]` (277) | `OOSmallFragmentBurstEntity::update` `Core/Entities/OOParticleSystem.cpp:283` | ✅ |
| `-[OOBigFragmentBurstEntity initFragmentBurstFrom:velocity:size:]` (300) | `OOBigFragmentBurstEntity::initFragmentBurstFrom` `Core/Entities/OOParticleSystem.cpp:302` | ✅ |
| `+[OOBigFragmentBurstEntity fragmentBurstFromEntity:]` (322) | `OOBigFragmentBurstEntity::fragmentBurstFromEntity` `Core/Entities/OOParticleSystem.cpp:323` | ✅ |
| `-[OOBigFragmentBurstEntity update:]` (327) | `OOBigFragmentBurstEntity::update` `Core/Entities/OOParticleSystem.cpp:330` | ✅ |

**Differences:**

- ⚠️ **low** — the three `randf()` calls inside `make_vector(...)` for each particle's colour are sequenced into locals in Clang's left-to-right order (ADR-0063 item 5). The result is identical under Clang, which is the order the goldens use. A GCC-built upstream would have drawn right to left — upstream `Core/Entities/OOParticleSystem.m:70` ↔ port `Core/Entities/OOParticleSystem.cpp:73-76`
- ➖ **low** — `-init` (which returned nil) is now a protected constructor, so only subclasses construct — upstream `Core/Entities/OOParticleSystem.m:39` ↔ port `Core/Entities/OOParticleSystem.h:62`
- Subtle (✅): particle counts are identical. Small burst is `(unsigned)(0.4·size) | 12` capped at 64, speeds 100–400, 1.5 s, one hue `randf()` before the base init's draws, size `3200/speed`. Big burst is `(0.2·size) | 3` capped at 16, speeds `1+size/2` to ×4, 1.0 s, base colour (1,1,0.5,1), velocity ×0.85. The per-particle RNG order is `randf, randf, OORandomUnitVector, 3×randf`. A null `other` in `checkCloseCollisionWith` answers true, as `![nil isEffect]` did.

## OOPlanetEntity

<a id="ooplanetentity"></a>
Upstream `src/Core/Entities/OOPlanetEntity.m` ↔ `Core/Entities/OOPlanetEntity.cpp`

**Status:** done — 51 rows: 49 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPlanetEntity initAsMainPlanetForSystem:]` (70) | `OOPlanetEntity::initAsMainPlanetForSystem` `Core/Entities/OOPlanetEntity.cpp:163` | ✅ |
| `-[OOPlanetEntity initFromDictionary:withAtmosphere:andSeed:forSystem:]` (84) | `OOPlanetEntity::initFromDictionary` `Core/Entities/OOPlanetEntity.cpp:176` | ⚠️ |
| `RandomHSBColor()` (248) | `RandomHSBColor` `Core/Entities/OOPlanetEntity.cpp:335` | ✅ |
| `LighterHSBColor()` (257) | `LighterHSBColor` `Core/Entities/OOPlanetEntity.cpp:344` | ✅ |
| `HSBColorWithColor()` (266) | `HSBColorWithColor` `Core/Entities/OOPlanetEntity.cpp:355` | ✅ |
| `ColorWithHSBColor()` (272) | `ColorWithHSBColor` `Core/Entities/OOPlanetEntity.cpp:362` (Object node of the colour) | ✅ |
| `-[OOPlanetEntity setUpTypeParametersWithSourceInfo:targetInfo:]` (277) | `OOPlanetEntity::setUpTypeParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:369` | ✅ |
| `-[OOPlanetEntity setUpTerrainParametersWithSourceInfo:targetInfo:]` (283) | `OOPlanetEntity::setUpTerrainParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:375` | ✅ |
| `-[OOPlanetEntity setUpLandParametersWithSourceInfo:targetInfo:]` (295) | `OOPlanetEntity::setUpLandParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:386` | ✅ |
| `-[OOPlanetEntity setUpAtmosphereParametersWithSourceInfo:targetInfo:]` (300) | `OOPlanetEntity::setUpAtmosphereParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:391` | ✅ |
| `-[OOPlanetEntity setUpColorParametersWithSourceInfo:targetInfo:isAtmosphere:]` (305) | `OOPlanetEntity::setUpColorParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:396` | ✅ |
| `-[OOPlanetEntity initAsMiniatureVersionOfPlanet:]` (411) | `OOPlanetEntity::initAsMiniatureVersionOfPlanet` `Core/Entities/OOPlanetEntity.cpp:504` | ✅ |
| `-[OOPlanetEntity dealloc]` (459) | `OOPlanetEntity::~OOPlanetEntity` `Core/Entities/OOPlanetEntity.cpp:553` | ✅ |
| `-[OOPlanetEntity descriptionComponents]` (477) | `OOPlanetEntity::descriptionComponents` `Core/Entities/OOPlanetEntity.cpp:559` | ✅ |
| `-[OOPlanetEntity setOrientation:]` (482) | `OOPlanetEntity::setOrientation` `Core/Entities/OOPlanetEntity.cpp:564` | ✅ |
| `-[OOPlanetEntity radius]` (488) | `OOPlanetEntity::radius` `Core/Entities/OOPlanetEntity.cpp:570` | ✅ |
| `-[OOPlanetEntity planetType]` (493) | `OOPlanetEntity::planetType` `Core/Entities/OOPlanetEntity.cpp:575` | ✅ |
| `-[OOPlanetEntity miniatureVersion]` (502) | `OOPlanetEntity::miniatureVersion` `Core/Entities/OOPlanetEntity.cpp:584` | ✅ |
| `-[OOPlanetEntity update:]` (507) | `OOPlanetEntity::update` `Core/Entities/OOPlanetEntity.cpp:593` | ✅ |
| `-[OOPlanetEntity isFinishedLoading]` (605) | `OOPlanetEntity::isFinishedLoading` `Core/Entities/OOPlanetEntity.cpp:694` | ✅ |
| `-[OOPlanetEntity drawImmediate:translucent:]` (619) | `OOPlanetEntity::drawImmediate` `Core/Entities/OOPlanetEntity.cpp:709` | ✅ |
| `-[OOPlanetEntity checkCloseCollisionWith:]` (700) | `OOPlanetEntity::checkCloseCollisionWith` `Core/Entities/OOPlanetEntity.cpp:791` | ✅ |
| `-[OOPlanetEntity planetHasStation]` (714) | `OOPlanetEntity::planetHasStation` `Core/Entities/OOPlanetEntity.cpp:805` | ✅ |
| `-[OOPlanetEntity launchShuttle]` (729) | `OOPlanetEntity::launchShuttle` `Core/Entities/OOPlanetEntity.cpp:818` | ✅ |
| `-[OOPlanetEntity welcomeShuttle:]` (769) | `OOPlanetEntity::welcomeShuttle` `Core/Entities/OOPlanetEntity.cpp:866` | ✅ |
| `-[OOPlanetEntity isPlanet]` (774) | `OOPlanetEntity::isPlanet` `Core/Entities/OOPlanetEntity.cpp:871` | ✅ |
| `-[OOPlanetEntity isVisible]` (779) | `OOPlanetEntity::isVisible` `Core/Entities/OOPlanetEntity.cpp:876` | ✅ |
| `-[OOPlanetEntity rotationalVelocity]` (784) | `OOPlanetEntity::rotationalVelocity` `Core/Entities/OOPlanetEntity.cpp:881` | ✅ |
| `-[OOPlanetEntity setRotationalVelocity:]` (789) | `OOPlanetEntity::setRotationalVelocity` `Core/Entities/OOPlanetEntity.cpp:886` | ✅ |
| `-[OOPlanetEntity airColorAsVector]` (798) | `OOPlanetEntity::airColorAsVector` `Core/Entities/OOPlanetEntity.cpp:895` | ✅ |
| `-[OOPlanetEntity airColor]` (805) | `OOPlanetEntity::airColor` `Core/Entities/OOPlanetEntity.cpp:903` | ✅ |
| `-[OOPlanetEntity setAirColor:]` (810) | `OOPlanetEntity::setAirColor` `Core/Entities/OOPlanetEntity.cpp:908` | ✅ |
| `-[OOPlanetEntity illuminationColorAsVector]` (819) | `OOPlanetEntity::illuminationColorAsVector` `Core/Entities/OOPlanetEntity.cpp:916` | ✅ |
| `-[OOPlanetEntity illuminationColor]` (826) | `OOPlanetEntity::illuminationColor` `Core/Entities/OOPlanetEntity.cpp:924` | ✅ |
| `-[OOPlanetEntity setIlluminationColor:]` (831) | `OOPlanetEntity::setIlluminationColor` `Core/Entities/OOPlanetEntity.cpp:929` | ✅ |
| `-[OOPlanetEntity airColorMixRatio]` (840) | `OOPlanetEntity::airColorMixRatio` `Core/Entities/OOPlanetEntity.cpp:937` | ✅ |
| `-[OOPlanetEntity setAirColorMixRatio:]` (845) | `OOPlanetEntity::setAirColorMixRatio` `Core/Entities/OOPlanetEntity.cpp:942` | ✅ |
| `-[OOPlanetEntity airDensity]` (851) | `OOPlanetEntity::airDensity` `Core/Entities/OOPlanetEntity.cpp:948` | ✅ |
| `-[OOPlanetEntity setAirDensity:]` (856) | `OOPlanetEntity::setAirDensity` `Core/Entities/OOPlanetEntity.cpp:953` | ✅ |
| `-[OOPlanetEntity setTerminatorThresholdVector:]` (861) | `OOPlanetEntity::setTerminatorThresholdVector` `Core/Entities/OOPlanetEntity.cpp:958` | ✅ |
| `-[OOPlanetEntity terminatorThresholdVector]` (868) | `OOPlanetEntity::terminatorThresholdVector` `Core/Entities/OOPlanetEntity.cpp:965` | ✅ |
| `-[OOPlanetEntity hasAtmosphere]` (873) | `OOPlanetEntity::hasAtmosphere` `Core/Entities/OOPlanetEntity.cpp:970` | ✅ |
| `-[OOPlanetEntity textureFileName]` (879) | `OOPlanetEntity::textureFileName` `Core/Entities/OOPlanetEntity.cpp:976` | ✅ |
| `-[OOPlanetEntity resetGraphicsState]` (884) | `OOPlanetEntity::resetGraphicsState` `Core/Entities/OOPlanetEntity.cpp:981` | ✅ |
| `-[OOPlanetEntity setTextureFileName:]` (890) | `OOPlanetEntity::setTextureFileName` `Core/Entities/OOPlanetEntity.cpp:987` | ⚠️ |
| `-[OOPlanetEntity setUpPlanetFromTexture:]` (1016) | `OOPlanetEntity::setUpPlanetFromTexture` `Core/Entities/OOPlanetEntity.cpp:1117` | ✅ |
| `-[OOPlanetEntity material]` (1022) | `OOPlanetEntity::material` `Core/Entities/OOPlanetEntity.cpp:1123` | ✅ |
| `-[OOPlanetEntity atmosphereMaterial]` (1027) | `OOPlanetEntity::atmosphereMaterial` `Core/Entities/OOPlanetEntity.cpp:1128` | ✅ |
| `-[OOPlanetEntity atmosphereShaderMaterial]` (1032) | `OOPlanetEntity::atmosphereShaderMaterial` `Core/Entities/OOPlanetEntity.cpp:1133` | ✅ |
| `-[OOPlanetEntity name]` (1039) | `OOPlanetEntity::name` `Core/Entities/OOPlanetEntity.cpp:1140` | ✅ |
| `-[OOPlanetEntity setName:]` (1044) | `OOPlanetEntity::setName` `Core/Entities/OOPlanetEntity.cpp:1145` | ✅ |

**Differences:**

- ⚠️ **low** — The RANROT noise seed is no longer boxed as `NSValue` under `"noise_map_seed"` in planetInfo and `_materialParameters`. It is kept in `_noiseMapSeed` and passed explicitly to `OOPlanetTextureGenerator`/`OOStandaloneAtmosphereGenerator` (bead oo-3rb.48, `OOPlanetEntity.h:168`). The seed is captured at the same point (before `setUpLandParameters…`), so generated textures are unchanged. Only the key is gone from `_materialParameters` — upstream `Core/Entities/OOPlanetEntity.m:143-144,174,185,938-954` ↔ port `Core/Entities/OOPlanetEntity.cpp:234,264,275,1035-1056`
- Subtle (✅): system-dictionary defaults match. Radius is `radius_km * 10` from dict then planetInfo. Shuttles are `1 + min(techLevel,14)/2` over 3600 s, first launch at +30 s. `percent_land` defaults to `24 + rnd%48`, `percent_ice` to 5, `percent_cloud` to `100-(3+(r&31)+(r&31))`. Air colour mix 0.5 and density 0.75 when there is no atmosphere, else read from planetInfo with density clamped. Terminator default is (0.105, 0.18, 0.28). Rotation is `rotational_velocity` (default `0.01*randf()`) or `rotation_speed*rotation_speed_factor`, and atmosphere rotation defaults to `0.01*randf()`. Default arguments that call RNG are evaluated unconditionally on both sides, so the PRNG stream is the same. A null planetInfo reads 0, as nil did (`PList::get` on null, `oofnd/PListGet.hpp:650`) — upstream `Core/Entities/OOPlanetEntity.m:119-221` ↔ port `Core/Entities/OOPlanetEntity.cpp:210-310`
- Subtle (✅): `NEW_ATMOSPHERE` is defined to 1 on both sides. Upstream wraps the whole file in `#if NEW_PLANETS` (default 1, `OOStellarBody.h:33-35`); the port compiles it unconditionally — upstream `Core/Entities/OOPlanetEntity.m:27-29` ↔ port `Core/Entities/OOPlanetEntity.cpp:33`

## OOPlasmaBurstEntity

<a id="ooplasmaburstentity"></a>
Upstream `src/Core/Entities/OOPlasmaBurstEntity.m` ↔ `Core/Entities/OOPlasmaBurstEntity.cpp`

**Status:** done — 2 rows: 2 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPlasmaBurstEntity initWithPosition:]` (35) | `OOPlasmaBurstEntity::initWithPosition` `Core/Entities/OOPlasmaBurstEntity.cpp:40` (factory `burstWithPosition` `:33`) | ✅ |
| `-[OOPlasmaBurstEntity update:]` (47) | `OOPlasmaBurstEntity::update` `Core/Entities/OOPlasmaBurstEntity.cpp:52` | ✅ |

**Differences:**

- None. Initial size 64, growth 64/s, duration 2 s, red colour, collision radius 2 and linear alpha attenuation are all unchanged.

## OOPlasmaShotEntity

<a id="ooplasmashotentity"></a>
Upstream `src/Core/Entities/OOPlasmaShotEntity.m` ↔ `Core/Entities/OOPlasmaShotEntity.cpp`

**Status:** done — 4 rows: 4 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPlasmaShotEntity initWithPosition:]` (43) | `OOPlasmaShotEntity::initWithPosition` `Core/Entities/OOPlasmaShotEntity.cpp:56` (factory `shotWithPosition` `:45`) | ✅ |
| `-[OOPlasmaShotEntity canCollide]` (64) | `OOPlasmaShotEntity::canCollide` `Core/Entities/OOPlasmaShotEntity.cpp:77` | ✅ |
| `-[OOPlasmaShotEntity checkCloseCollisionWith:]` (69) | `OOPlasmaShotEntity::checkCloseCollisionWith` `Core/Entities/OOPlasmaShotEntity.cpp:83` | ✅ |
| `-[OOPlasmaShotEntity update:]` (74) | `OOPlasmaShotEntity::update` `Core/Entities/OOPlasmaShotEntity.cpp:88` | ✅ |

**Differences:**

- Subtle (✅): `update` iterates a snapshot of `collidingEntities`. Upstream iterated the live array by index with the count taken up front, so the result is identical unless the array shrinks mid-loop, which upstream would have raised on. Every non-owner hit still takes `energy × 1.0` with weapon `EQ_WEAPON_PLASMA_SHOT`, removes the shot and spawns one burst — upstream `Core/Entities/OOPlasmaShotEntity.m:86` ↔ port `Core/Entities/OOPlasmaShotEntity.cpp:100`
- Activation delay 0.05 s, size 12 and collision radius 2 are unchanged.

## OOQuiriumCascadeEntity

<a id="ooquiriumcascadeentity"></a>
Upstream `src/Core/Entities/OOQuiriumCascadeEntity.m` ↔ `Core/Entities/OOQuiriumCascadeEntity.cpp`

**Status:** done — 10 rows: 9 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOQuiriumCascadeEntity initQuiriumCascadeFromShip:]` (36) | `OOQuiriumCascadeEntity::initQuiriumCascadeFromShip` `Core/Entities/OOQuiriumCascadeEntity.cpp:36` | ✅ |
| `+[OOQuiriumCascadeEntity quiriumCascadeFromShip:]` (59) | `OOQuiriumCascadeEntity::quiriumCascadeFromShip` `Core/Entities/OOQuiriumCascadeEntity.cpp:59` | ✅ |
| `-[OOQuiriumCascadeEntity descriptionComponents]` (64) | `OOQuiriumCascadeEntity::descriptionComponents` `Core/Entities/OOQuiriumCascadeEntity.cpp:67` | ✅ |
| `-[OOQuiriumCascadeEntity update:]` (69) | `OOQuiriumCascadeEntity::update` `Core/Entities/OOQuiriumCascadeEntity.cpp:72` | ✅ |
| `-[OOQuiriumCascadeEntity drawImmediate:translucent:]` (110) | `OOQuiriumCascadeEntity::drawImmediate` `Core/Entities/OOQuiriumCascadeEntity.cpp:117` | ✅ |
| `-[OOQuiriumCascadeEntity isEffect]` (136) | `OOQuiriumCascadeEntity::isEffect` `Core/Entities/OOQuiriumCascadeEntity.cpp:143` | ✅ |
| `-[OOQuiriumCascadeEntity isCascadeWeapon]` (141) | `OOQuiriumCascadeEntity::isCascadeWeapon` `Core/Entities/OOQuiriumCascadeEntity.cpp:148` | ✅ |
| `-[OOQuiriumCascadeEntity canCollide]` (146) | `OOQuiriumCascadeEntity::canCollide` `Core/Entities/OOQuiriumCascadeEntity.cpp:153` | ✅ |
| `-[OOQuiriumCascadeEntity checkCloseCollisionWith:]` (151) | `OOQuiriumCascadeEntity::checkCloseCollisionWith` `Core/Entities/OOQuiriumCascadeEntity.cpp:158` | ✅ |
| `-[Entity(OOQuiriumCascadeExtensions) isCascadeWeapon]` (160) | `OOEntityIsCascadeWeapon()` `Core/Entities/OOQuiriumCascadeEntity.h:61`; `Facade_isCascadeWeapon` `Core/Entities/OOEntityCalledByName.cpp:301` | ➖ |

**Differences:**

- ➖ **low** — the category `-isCascadeWeapon` is replaced by the free function `OOEntityIsCascadeWeapon` (a dynamic_cast, false for null). All five upstream callers use it (PlayerEntity ×2, ShipEntity, StationEntity, HeadUpDisplay) — upstream `Core/Entities/OOQuiriumCascadeEntity.m:160` ↔ port `Core/Entities/OOQuiriumCascadeEntity.h:61`
- Subtle (✅): `update` damages a snapshot of `collidingEntities`. Upstream fast enumeration would have raised on mutation. Damage is identical: per-tick `energy = Δt·(100000 − 90000·tf)` to every colliding entity with weapon `EQ_QC_MINE`, and the damage source is the weak owner (`ownerEntity()`, null if gone, as `-owner` was). The radius grows by `Δt·min(240 + 10/tf², 1000)`. Duration is 20 s, collision delay 0.05 s, and the colour/alpha formulas and the single `randf()` are unchanged — upstream `Core/Entities/OOQuiriumCascadeEntity.m:84-102` ↔ port `Core/Entities/OOQuiriumCascadeEntity.cpp:88-108`

## OORingEffectEntity

<a id="ooringeffectentity"></a>
Upstream `src/Core/Entities/OORingEffectEntity.m` ↔ `Core/Entities/OORingEffectEntity.cpp`

**Status:** done — 9 rows: 9 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OORingEffectEntity initialize]` (52) | `OORingEffectEntity::initialize` `Core/Entities/OORingEffectEntity.cpp:56` (called from `ringFromEntity`) | ✅ |
| `-[OORingEffectEntity initRingFromEntity:]` (61) | `OORingEffectEntity::initRingFromEntity` `Core/Entities/OORingEffectEntity.cpp:71` | ✅ |
| `+[OORingEffectEntity ringFromEntity:]` (88) | `OORingEffectEntity::ringFromEntity` `Core/Entities/OORingEffectEntity.cpp:98` | ✅ |
| `+[OORingEffectEntity shrinkingRingFromEntity:]` (93) | `OORingEffectEntity::shrinkingRingFromEntity` `Core/Entities/OORingEffectEntity.cpp:107` | ✅ |
| `-[OORingEffectEntity descriptionComponents]` (103) | `OORingEffectEntity::descriptionComponents` `Core/Entities/OORingEffectEntity.cpp:117` | ✅ |
| `-[OORingEffectEntity update:]` (108) | `OORingEffectEntity::update` `Core/Entities/OORingEffectEntity.cpp:122` | ✅ |
| `-[OORingEffectEntity drawImmediate:translucent:]` (121) | `OORingEffectEntity::drawImmediate` `Core/Entities/OORingEffectEntity.cpp:136` | ✅ |
| `-[OORingEffectEntity isEffect]` (147) | `OORingEffectEntity::isEffect` `Core/Entities/OORingEffectEntity.cpp:162` | ✅ |
| `-[OORingEffectEntity canCollide]` (152) | `OORingEffectEntity::canCollide` `Core/Entities/OORingEffectEntity.cpp:167` | ✅ |

**Differences:**

- Subtle (✅): `+initialize` ran lazily on the first message to the class; the port runs it on the first `ringFromEntity` call, which is the only way to construct a ring. Constants are identical: 2 s duration, 0.4 s attack, inner/outer sizes 0.5/0.625 × radius, growth 0.55/0.625 × radius, shrink factors −2.5/−2.0, and 65 segments. The GL error label still says "OOQuiriumCascadeEntity", as upstream does.

## OOSparkEntity

<a id="oosparkentity"></a>
Upstream `src/Core/Entities/OOSparkEntity.m` ↔ `Core/Entities/OOSparkEntity.cpp`

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSparkEntity initWithPosition:]` (39) | `OOSparkEntity::initWithPosition` `Core/Entities/OOSparkEntity.cpp:42` (factory `sparkWithPosition` `:31`) | ✅ |
| `-[OOSparkEntity update:]` (58) | `OOSparkEntity::update` `Core/Entities/OOSparkEntity.cpp:63` | ✅ |
| `-[OOSparkEntity performUpdate:]` (64) | `OOSparkEntity::performUpdate` `Core/Entities/OOSparkEntity.cpp:69` | ✅ |

**Differences:**

- None. The fade-to-red mix, removal at `mix == 0`, and `GLfloat` duration and time-remaining are all unchanged.

## OOSunEntity

<a id="oosunentity"></a>
Upstream `src/Core/Entities/OOSunEntity.m` ↔ `Core/Entities/OOSunEntity.cpp`

**Status:** done — 30 rows: 29 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSunEntity init]` (52) | — (debug-only `assert(0)` guard; the port has no `-init` path to guard) | ➖ |
| `-[OOSunEntity setSunColor:]` (59) | `OOSunEntity::setSunColor` `Core/Entities/OOSunEntity.cpp:49` | ✅ |
| `-[OOSunEntity initSunWithColor:andDictionary:]` (123) | `OOSunEntity::initSunWithColor` `Core/Entities/OOSunEntity.cpp:113` | ✅ |
| `-[OOSunEntity dealloc]` (203) | implicit (`_name` is a member) | ✅ |
| `-[OOSunEntity descriptionComponents]` (209) | `OOSunEntity::descriptionComponents` `Core/Entities/OOSunEntity.cpp:197` | ✅ |
| `-[OOSunEntity canCollide]` (221) | `OOSunEntity::canCollide` `Core/Entities/OOSunEntity.cpp:211` | ✅ |
| `-[OOSunEntity checkCloseCollisionWith:]` (227) | `OOSunEntity::checkCloseCollisionWith` `Core/Entities/OOSunEntity.cpp:217` | ✅ |
| `-[OOSunEntity update:]` (237) | `OOSunEntity::update` `Core/Entities/OOSunEntity.cpp:227` | ✅ |
| `-[OOSunEntity drawImmediate:translucent:]` (307) | `OOSunEntity::drawImmediate` `Core/Entities/OOSunEntity.cpp:303` | ✅ |
| `-[OOSunEntity updateCameraRelativePosition]` (327) | `OOSunEntity::updateCameraRelativePosition` `Core/Entities/OOSunEntity.cpp:323` | ✅ |
| `-[OOSunEntity drawOpaqueParts]` (339) | `OOSunEntity::drawOpaqueParts` `Core/Entities/OOSunEntity.cpp:335` | ✅ |
| `-[OOSunEntity drawTranslucentParts]` (419) | `OOSunEntity::drawTranslucentParts` `Core/Entities/OOSunEntity.cpp:415` | ✅ |
| `-[OOSunEntity calculateGLArrays:width:zDistance:]` (438) | `OOSunEntity::calculateGLArrays` `Core/Entities/OOSunEntity.cpp:434` | ✅ |
| `-[OOSunEntity drawDirectVisionSunGlare]` (550) | `OOSunEntity::drawDirectVisionSunGlare` `Core/Entities/OOSunEntity.cpp:546` | ✅ |
| `-[OOSunEntity drawStarGlare]` (584) | `OOSunEntity::drawStarGlare` `Core/Entities/OOSunEntity.cpp:580` | ✅ |
| `-[OOSunEntity changeSunProperty:withDictionary:]` (616) | `OOSunEntity::changeSunProperty` `Core/Entities/OOSunEntity.cpp:612` | ✅ |
| `-[OOSunEntity planetType]` (647) | `OOSunEntity::planetType` `Core/Entities/OOSunEntity.cpp:646` | ✅ |
| `-[OOSunEntity getDiffuseComponents:]` (652) | `OOSunEntity::getDiffuseComponents` `Core/Entities/OOSunEntity.cpp:651` | ✅ |
| `-[OOSunEntity getSpecularComponents:]` (658) | `OOSunEntity::getSpecularComponents` `Core/Entities/OOSunEntity.cpp:657` | ✅ |
| `-[OOSunEntity radius]` (664) | `OOSunEntity::radius` `Core/Entities/OOSunEntity.cpp:663` | ✅ |
| `-[OOSunEntity setRadius:andCorona:]` (669) | `OOSunEntity::setRadius` `Core/Entities/OOSunEntity.cpp:668` | ✅ |
| `-[OOSunEntity setPosition:]` (682) | `OOSunEntity::setPosition` `Core/Entities/OOSunEntity.cpp:681` | ✅ |
| `-[OOSunEntity willGoNova]` (688) | `OOSunEntity::willGoNova` `Core/Entities/OOSunEntity.cpp:688` | ✅ |
| `-[OOSunEntity goneNova]` (693) | `OOSunEntity::goneNova` `Core/Entities/OOSunEntity.cpp:693` | ✅ |
| `-[OOSunEntity setGoingNova:inTime:]` (698) | `OOSunEntity::setGoingNova` `Core/Entities/OOSunEntity.cpp:698` | ✅ |
| `-[OOSunEntity resetNova]` (710) | `OOSunEntity::resetNova` `Core/Entities/OOSunEntity.cpp:710` | ✅ |
| `-[OOSunEntity isSun]` (717) | `OOSunEntity::isSun` `Core/Entities/OOSunEntity.cpp:717` | ✅ |
| `-[OOSunEntity isVisible]` (722) | `OOSunEntity::isVisible` `Core/Entities/OOSunEntity.cpp:722` | ✅ |
| `-[OOSunEntity name]` (727) | `OOSunEntity::name` `Core/Entities/OOSunEntity.cpp:727` | ✅ |
| `-[OOSunEntity setName:]` (732) | `OOSunEntity::setName` `Core/Entities/OOSunEntity.cpp:732` | ✅ |

**Differences:**

- ➖ `-init` (`#ifndef NDEBUG assert(0)`) guarded against plain `-init`. The port builds suns only through `initSunWithColor`, so the guard has nothing to guard — upstream `Core/Entities/OOSunEntity.m:51-57`
- Subtle (✅): defaults are identical. Radius is 100 km. `sbf` 80 and `scaf` 0.005 come from user defaults. Star name defaults to `[oolite-default-star-name]`. `corona_hues` 1.0 is clamped. `corona_shimmer` -1 gives `1/(0.5+2(randf+randf))`, otherwise `clamp*2 + randf*randf`. `corona_flare` 0 is clamped to ≥0.01 in `setRadius`. `cor16k = r*8*corona`. A null dict reads 0 and a nil name, as nil messaging did (`PListGet.hpp:650`) — upstream `Core/Entities/OOSunEntity.m:129-158,616-680` ↔ port `Core/Entities/OOSunEntity.cpp:119-154,612-679`
- Subtle (✅): nova behaviour is the same. `setGoingNova` sets rate 10000 and countdown `fmax(interval,0)`. While counting down, corona speed rises by 0.75/s up to 5. Expansion lasts 60 s with `sky_bri = 1-1.5t`. On the first tick (sky_bri == 1.0) it writes `sun_gone_nova`=YES, `corona_flare`=0.3f and `corona_hues`=0.05f under `org.oolite.oolite`, then `sun_radius` grows by `dt*rate` as a float. At the end it calls `resetNova` and keeps `throw_sparks`. `changeSunProperty("sun_gone_nova")` restores the static `oldRadius` — upstream `Core/Entities/OOSunEntity.m:245-291,631-639,698-715` ↔ port `Core/Entities/OOSunEntity.cpp:235-287,630-638,698-715`

## OOVisualEffectEntity

<a id="oovisualeffectentity"></a>
Upstream `src/Core/Entities/OOVisualEffectEntity.m` ↔ `Core/Entities/OOVisualEffectEntity.cpp`

**Status:** done — 83 rows: 81 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOVisualEffectEntity init]` (69) | — (forwarded to `initWithKey:@"" definition:nil`, which `NSParameterAssert`s; replaced by `oo::NewVisualEffect` `Core/Entities/OOVisualEffectEntity.cpp:109`) | ➖ |
| `-[OOVisualEffectEntity initWithKey:definition:]` (74) | `OOVisualEffectEntity::initWithKey` `Core/Entities/OOVisualEffectEntity.cpp:124` | ✅ |
| `-[OOVisualEffectEntity setUpVisualEffectFromDictionary:]` (98) | `OOVisualEffectEntity::setUpVisualEffectFromDictionary` `Core/Entities/OOVisualEffectEntity.cpp:141` | ✅ |
| `-[OOVisualEffectEntity dealloc]` (159) | `OOVisualEffectEntity::~OOVisualEffectEntity` `Core/Entities/OOVisualEffectEntity.cpp:204` | ✅ |
| `-[OOVisualEffectEntity isEffect]` (175) | `OOVisualEffectEntity::isEffect` `Core/Entities/OOVisualEffectEntity.cpp:213` | ✅ |
| `-[OOVisualEffectEntity isVisualEffect]` (180) | `OOVisualEffectEntity::getIsVisualEffect` `Core/Entities/OOVisualEffectEntity.cpp:218` | ✅ |
| `-[OOVisualEffectEntity canCollide]` (185) | `OOVisualEffectEntity::canCollide` `Core/Entities/OOVisualEffectEntity.cpp:223` | ✅ |
| `-[OOVisualEffectEntity mesh]` (190) | `OOVisualEffectEntity::mesh` `Core/Entities/OOVisualEffectEntity.cpp:228` | ✅ |
| `-[OOVisualEffectEntity setMesh:]` (195) | `OOVisualEffectEntity::setMesh` `Core/Entities/OOVisualEffectEntity.cpp:233` | ✅ |
| `-[OOVisualEffectEntity effectKey]` (202) | `OOVisualEffectEntity::effectKey` `Core/Entities/OOVisualEffectEntity.cpp:240` | ✅ |
| `-[OOVisualEffectEntity frustumRadius]` (207) | `OOVisualEffectEntity::frustumRadius` `Core/Entities/OOVisualEffectEntity.cpp:245` | ✅ |
| `-[OOVisualEffectEntity clearSubEntities]` (212) | `OOVisualEffectEntity::clearSubEntities` `Core/Entities/OOVisualEffectEntity.cpp:250` | ✅ |
| `-[OOVisualEffectEntity setUpSubEntities]` (227) | `OOVisualEffectEntity::setUpSubEntities` `Core/Entities/OOVisualEffectEntity.cpp:267` | ✅ |
| `-[OOVisualEffectEntity removeSubEntity:]` (242) | `OOVisualEffectEntity::removeSubEntity` `Core/Entities/OOVisualEffectEntity.cpp:284` | ✅ |
| `-[OOVisualEffectEntity setNoDrawDistance]` (248) | `OOVisualEffectEntity::setNoDrawDistance` `Core/Entities/OOVisualEffectEntity.cpp:292` | ✅ |
| `-[OOVisualEffectEntity setUpOneSubentity:]` (254) | `OOVisualEffectEntity::setUpOneSubentity` `Core/Entities/OOVisualEffectEntity.cpp:298` | ✅ |
| `-[OOVisualEffectEntity setUpOneFlasher:]` (264) | `OOVisualEffectEntity::setUpOneFlasher` `Core/Entities/OOVisualEffectEntity.cpp:308` | ✅ |
| `-[OOVisualEffectEntity setUpOneStandardSubentity:]` (272) | `OOVisualEffectEntity::setUpOneStandardSubentity` `Core/Entities/OOVisualEffectEntity.cpp:318` | ✅ |
| `-[OOVisualEffectEntity addSubEntity:]` (304) | `OOVisualEffectEntity::addSubEntity` `Core/Entities/OOVisualEffectEntity.cpp:350` | ✅ |
| `-[OOVisualEffectEntity subEntities]` (322) | `OOVisualEffectEntity::subEntities` `Core/Entities/OOVisualEffectEntity.cpp:368` | ✅ |
| `-[OOVisualEffectEntity subEntityCount]` (327) | `OOVisualEffectEntity::subEntityCount` `Core/Entities/OOVisualEffectEntity.cpp:380` | ✅ |
| `-[OOVisualEffectEntity visualEffectSubEntityEnumerator]` (332) | `OOVisualEffectEntity::visualEffectSubEntityEnumerator` `Core/Entities/OOVisualEffectEntity.cpp:385` | ✅ |
| `-[OOVisualEffectEntity hasSubEntity:]` (337) | `OOVisualEffectEntity::hasSubEntity` `Core/Entities/OOVisualEffectEntity.cpp:392` | ✅ |
| `-[OOVisualEffectEntity subEntityEnumerator]` (342) | `OOVisualEffectEntity::subEntityEnumerator` `Core/Entities/OOVisualEffectEntity.cpp:399` | ✅ |
| `-[OOVisualEffectEntity effectSubEntityEnumerator]` (347) | `OOVisualEffectEntity::effectSubEntityEnumerator` `Core/Entities/OOVisualEffectEntity.cpp:404` | ✅ |
| `-[OOVisualEffectEntity flasherEnumerator]` (352) | `OOVisualEffectEntity::flasherEnumerator` `Core/Entities/OOVisualEffectEntity.cpp:409` | ✅ |
| `-[OOVisualEffectEntity drawSubEntityImmediate:translucent:]` (357) | `OOVisualEffectEntity::drawSubEntityImmediate` `Core/Entities/OOVisualEffectEntity.cpp:422` | ✅ |
| `-[OOVisualEffectEntity rescaleBy:]` (372) | `OOVisualEffectEntity::rescaleBy(factor)` `Core/Entities/OOVisualEffectEntity.cpp:437` | ✅ |
| `-[OOVisualEffectEntity rescaleBy:writeToCache:]` (389) | `OOVisualEffectEntity::rescaleBy(factor, writeToCache)` `Core/Entities/OOVisualEffectEntity.cpp:459` | ✅ |
| `-[OOVisualEffectEntity scaleMax]` (395) | `OOVisualEffectEntity::scaleMax` `Core/Entities/OOVisualEffectEntity.cpp:465` | ✅ |
| `-[OOVisualEffectEntity scaleX]` (412) | `OOVisualEffectEntity::scaleX` `Core/Entities/OOVisualEffectEntity.cpp:482` | ✅ |
| `-[OOVisualEffectEntity setScaleX:]` (417) | `OOVisualEffectEntity::setScaleX` `Core/Entities/OOVisualEffectEntity.cpp:487` | ✅ |
| `-[OOVisualEffectEntity scaleY]` (437) | `OOVisualEffectEntity::scaleY` `Core/Entities/OOVisualEffectEntity.cpp:513` | ✅ |
| `-[OOVisualEffectEntity setScaleY:]` (442) | `OOVisualEffectEntity::setScaleY` `Core/Entities/OOVisualEffectEntity.cpp:518` | ✅ |
| `-[OOVisualEffectEntity scaleZ]` (462) | `OOVisualEffectEntity::scaleZ` `Core/Entities/OOVisualEffectEntity.cpp:544` | ✅ |
| `-[OOVisualEffectEntity setScaleZ:]` (467) | `OOVisualEffectEntity::setScaleZ` `Core/Entities/OOVisualEffectEntity.cpp:549` | ✅ |
| `-[OOVisualEffectEntity collisionRadius]` (487) | `OOVisualEffectEntity::collisionRadius` `Core/Entities/OOVisualEffectEntity.cpp:575` | ✅ |
| `-[OOVisualEffectEntity orientationChanged]` (492) | `OOVisualEffectEntity::orientationChanged` `Core/Entities/OOVisualEffectEntity.cpp:580` | ✅ |
| `-[OOVisualEffectEntity forwardVector]` (502) | `OOVisualEffectEntity::forwardVector` `Core/Entities/OOVisualEffectEntity.cpp:590` | ✅ |
| `-[OOVisualEffectEntity upVector]` (508) | `OOVisualEffectEntity::upVector` `Core/Entities/OOVisualEffectEntity.cpp:596` | ✅ |
| `-[OOVisualEffectEntity rightVector]` (514) | `OOVisualEffectEntity::rightVector` `Core/Entities/OOVisualEffectEntity.cpp:602` | ✅ |
| `-[OOVisualEffectEntity scannerDisplayColor1]` (519) | `OOVisualEffectEntity::scannerDisplayColor1` `Core/Entities/OOVisualEffectEntity.cpp:692` | ✅ |
| `-[OOVisualEffectEntity scannerDisplayColor2]` (524) | `OOVisualEffectEntity::scannerDisplayColor2` `Core/Entities/OOVisualEffectEntity.cpp:697` | ✅ |
| `-[OOVisualEffectEntity setScannerDisplayColor1:]` (529) | `OOVisualEffectEntity::setScannerDisplayColor1` `Core/Entities/OOVisualEffectEntity.cpp:702` | ✅ |
| `-[OOVisualEffectEntity setScannerDisplayColor2:]` (538) | `OOVisualEffectEntity::setScannerDisplayColor2` `Core/Entities/OOVisualEffectEntity.cpp:712` | ✅ |
| `-[OOVisualEffectEntity scannerDisplayColorForShip:scannerDisplayColor1:scannerDisplayColor2:]` (550) | `OOVisualEffectEntity::scannerDisplayColorForShip` `Core/Entities/OOVisualEffectEntity.cpp:725` | ✅ |
| `-[OOVisualEffectEntity drawImmediate:translucent:]` (575) | `OOVisualEffectEntity::drawImmediate` `Core/Entities/OOVisualEffectEntity.cpp:607` | ✅ |
| `-[OOVisualEffectEntity update:]` (598) | `OOVisualEffectEntity::update` `Core/Entities/OOVisualEffectEntity.cpp:634` | ✅ |
| `-[OOVisualEffectEntity isBreakPattern]` (613) | `OOVisualEffectEntity::isBreakPattern` `Core/Entities/OOVisualEffectEntity.cpp:651` | ✅ |
| `-[OOVisualEffectEntity setIsBreakPattern:]` (618) | `OOVisualEffectEntity::setIsBreakPattern` `Core/Entities/OOVisualEffectEntity.cpp:656` | ✅ |
| `-[OOVisualEffectEntity effectInfoDictionary]` (623) | `OOVisualEffectEntity::effectInfoDictionary` `Core/Entities/OOVisualEffectEntity.cpp:661` | ✅ |
| `-[OOVisualEffectEntity setScript:]` (630) | `OOVisualEffectEntity::setScript` `Core/Entities/OOVisualEffectEntity.cpp:752` | ✅ |
| `-[OOVisualEffectEntity script]` (646) | `OOVisualEffectEntity::script` `Core/Entities/OOVisualEffectEntity.cpp:766` | ✅ |
| `-[OOVisualEffectEntity scriptInfo]` (651) | `OOVisualEffectEntity::scriptInfo` `Core/Entities/OOVisualEffectEntity.cpp:771` | ✅ |
| `-[OOVisualEffectEntity doScriptEvent:]` (657) | `OOVisualEffectEntity::doScriptEvent` `Core/Entities/OOVisualEffectEntity.cpp:777` | ✅ |
| `-[OOVisualEffectEntity remove]` (664) | `OOVisualEffectEntity::remove` `Core/Entities/OOVisualEffectEntity.cpp:785` | ✅ |
| `-[OOVisualEffectEntity compareBeaconCodeWith:]` (672) | `OOVisualEffectEntity::compareBeaconCodeWith` `Core/Entities/OOVisualEffectEntity.cpp:794` | ❌ |
| `-[OOVisualEffectEntity beaconCode]` (677) | `OOVisualEffectEntity::beaconCode` `Core/Entities/OOVisualEffectEntity.cpp:799` | ✅ |
| `-[OOVisualEffectEntity setBeaconCode:]` (682) | `OOVisualEffectEntity::setBeaconCode` `Core/Entities/OOVisualEffectEntity.cpp:806` | ✅ |
| `-[OOVisualEffectEntity beaconLabel]` (699) | `OOVisualEffectEntity::beaconLabel` `Core/Entities/OOVisualEffectEntity.cpp:823` | ✅ |
| `-[OOVisualEffectEntity setBeaconLabel:]` (704) | `OOVisualEffectEntity::setBeaconLabel` `Core/Entities/OOVisualEffectEntity.cpp:828` | ✅ |
| `-[OOVisualEffectEntity isBeacon]` (715) | `OOVisualEffectEntity::isBeacon` `Core/Entities/OOVisualEffectEntity.cpp:839` | ✅ |
| `-[OOVisualEffectEntity beaconDrawable]` (720) | `OOVisualEffectEntity::beaconDrawable` `Core/Entities/OOVisualEffectEntity.cpp:844` | ✅ |
| `-[OOVisualEffectEntity prevBeacon]` (743) | `OOVisualEffectEntity::prevBeacon` `Core/Entities/OOVisualEffectEntity.cpp:868` | ✅ |
| `-[OOVisualEffectEntity nextBeacon]` (748) | `OOVisualEffectEntity::nextBeacon` `Core/Entities/OOVisualEffectEntity.cpp:873` | ✅ |
| `-[OOVisualEffectEntity setPrevBeacon:]` (753) | `OOVisualEffectEntity::setPrevBeacon` `Core/Entities/OOVisualEffectEntity.cpp:878` | ✅ |
| `-[OOVisualEffectEntity setNextBeacon:]` (761) | `OOVisualEffectEntity::setNextBeacon` `Core/Entities/OOVisualEffectEntity.cpp:885` | ✅ |
| `-[OOVisualEffectEntity isJammingScanning]` (769) | `OOVisualEffectEntity::isJammingScanning` `Core/Entities/OOVisualEffectEntity.cpp:892` | ✅ |
| `-[OOVisualEffectEntity hullHeatLevel]` (777) | `OOVisualEffectEntity::hullHeatLevel` `Core/Entities/OOVisualEffectEntity.cpp:900` | ✅ |
| `-[OOVisualEffectEntity setHullHeatLevel:]` (782) | `OOVisualEffectEntity::setHullHeatLevel` `Core/Entities/OOVisualEffectEntity.cpp:905` | ✅ |
| `-[OOVisualEffectEntity shaderFloat1]` (787) | `OOVisualEffectEntity::shaderFloat1` `Core/Entities/OOVisualEffectEntity.cpp:910` | ✅ |
| `-[OOVisualEffectEntity setShaderFloat1:]` (792) | `OOVisualEffectEntity::setShaderFloat1` `Core/Entities/OOVisualEffectEntity.cpp:915` | ✅ |
| `-[OOVisualEffectEntity shaderFloat2]` (797) | `OOVisualEffectEntity::shaderFloat2` `Core/Entities/OOVisualEffectEntity.cpp:920` | ✅ |
| `-[OOVisualEffectEntity setShaderFloat2:]` (802) | `OOVisualEffectEntity::setShaderFloat2` `Core/Entities/OOVisualEffectEntity.cpp:925` | ✅ |
| `-[OOVisualEffectEntity shaderInt1]` (807) | `OOVisualEffectEntity::shaderInt1` `Core/Entities/OOVisualEffectEntity.cpp:930` | ✅ |
| `-[OOVisualEffectEntity setShaderInt1:]` (812) | `OOVisualEffectEntity::setShaderInt1` `Core/Entities/OOVisualEffectEntity.cpp:935` | ✅ |
| `-[OOVisualEffectEntity shaderInt2]` (817) | `OOVisualEffectEntity::shaderInt2` `Core/Entities/OOVisualEffectEntity.cpp:940` | ✅ |
| `-[OOVisualEffectEntity setShaderInt2:]` (822) | `OOVisualEffectEntity::setShaderInt2` `Core/Entities/OOVisualEffectEntity.cpp:945` | ✅ |
| `-[OOVisualEffectEntity shaderVector1]` (827) | `OOVisualEffectEntity::shaderVector1` `Core/Entities/OOVisualEffectEntity.cpp:950` | ✅ |
| `-[OOVisualEffectEntity setShaderVector1:]` (832) | `OOVisualEffectEntity::setShaderVector1` `Core/Entities/OOVisualEffectEntity.cpp:955` | ✅ |
| `-[OOVisualEffectEntity shaderVector2]` (837) | `OOVisualEffectEntity::shaderVector2` `Core/Entities/OOVisualEffectEntity.cpp:960` | ✅ |
| `-[OOVisualEffectEntity setShaderVector2:]` (842) | `OOVisualEffectEntity::setShaderVector2` `Core/Entities/OOVisualEffectEntity.cpp:965` | ✅ |
| `-[OOVisualEffectEntity(SubEntityRelationship) isShipWithSubEntityShip:]` (852) | `OOVisualEffectEntity::isShipWithSubEntityShip` `Core/Entities/OOVisualEffectEntity.cpp:669` | ✅ |

**Differences:**

- ❌ **low** — `compareBeaconCodeWith`: when this effect's beacon code is nil, upstream messages nil and gets `NSOrderedSame` (0). The port compares `""` with the other code and so answers ascending, which can change the beacon-list order for code-less effects — upstream `Core/Entities/OOVisualEffectEntity.m:674` ↔ port `Core/Entities/OOVisualEffectEntity.cpp:796`
- ➖ `-init` forwarded to `initWithKey:@"" definition:nil` and would trip `NSParameterAssert(dict != nil)`. The port has no such path, and `initWithKey` no longer asserts on a null dict; it substitutes an empty dict — upstream `Core/Entities/OOVisualEffectEntity.m:69-78` ↔ port `Core/Entities/OOVisualEffectEntity.cpp:109-147`
- Subtle (✅): `setBeaconCode` now drops the cached `_beaconDrawable` whenever a code is passed. Upstream compared pointers, so it only skipped this when given its own `_beaconCode` object back; the port says so in a comment — upstream `Core/Entities/OOVisualEffectEntity.m:687` ↔ port `Core/Entities/OOVisualEffectEntity.cpp:804-816`

## OOWaypointEntity

<a id="oowaypointentity"></a>
Upstream `src/Core/Entities/OOWaypointEntity.m` ↔ `Core/Entities/OOWaypointEntity.cpp`

**Status:** done — 22 rows: 20 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOWaypointEntity waypointWithDictionary:]` (43) | `OOWaypointEntity::waypointWithDictionary` `Core/Entities/OOWaypointEntity.cpp:46` | ✅ |
| `-[OOWaypointEntity initWithDictionary:]` (48) | `OOWaypointEntity::initWithDictionary` `Core/Entities/OOWaypointEntity.cpp:53` | ✅ |
| `-[OOWaypointEntity dealloc]` (68) | members (`std::optional`, `WeakRef`, `Ref`) `Core/Entities/OOWaypointEntity.h` | ➖ |
| `-[OOWaypointEntity setOrientation:]` (80) | `OOWaypointEntity::setOrientation` `Core/Entities/OOWaypointEntity.cpp:71` | ✅ |
| `-[OOWaypointEntity oriented]` (91) | `OOWaypointEntity::getOriented` `Core/Entities/OOWaypointEntity.cpp:82` | ✅ |
| `-[OOWaypointEntity size]` (96) | `OOWaypointEntity::size` `Core/Entities/OOWaypointEntity.cpp:87` | ✅ |
| `-[OOWaypointEntity setSize:]` (101) | `OOWaypointEntity::setSize` `Core/Entities/OOWaypointEntity.cpp:92` | ✅ |
| `-[OOWaypointEntity isEffect]` (109) | `OOWaypointEntity::isEffect` `Core/Entities/OOWaypointEntity.cpp:100` | ✅ |
| `-[OOWaypointEntity isWaypoint]` (114) | `OOWaypointEntity::isWaypoint` `Core/Entities/OOWaypointEntity.cpp:105` | ✅ |
| `-[OOWaypointEntity drawImmediate:translucent:]` (119) | `OOWaypointEntity::drawImmediate` `Core/Entities/OOWaypointEntity.cpp:110` | ✅ |
| `-[OOWaypointEntity compareBeaconCodeWith:]` (187) | `OOWaypointEntity::compareBeaconCodeWith` `Core/Entities/OOWaypointEntity.cpp:178` | ❌ |
| `-[OOWaypointEntity beaconCode]` (192) | `OOWaypointEntity::beaconCode` `Core/Entities/OOWaypointEntity.cpp:183` | ✅ |
| `-[OOWaypointEntity setBeaconCode:]` (197) | `OOWaypointEntity::setBeaconCode` `Core/Entities/OOWaypointEntity.cpp:190` | ✅ |
| `-[OOWaypointEntity beaconLabel]` (214) | `OOWaypointEntity::beaconLabel` `Core/Entities/OOWaypointEntity.cpp:207` | ✅ |
| `-[OOWaypointEntity setBeaconLabel:]` (219) | `OOWaypointEntity::setBeaconLabel` `Core/Entities/OOWaypointEntity.cpp:212` | ✅ |
| `-[OOWaypointEntity isBeacon]` (230) | `OOWaypointEntity::isBeacon` `Core/Entities/OOWaypointEntity.cpp:223` | ✅ |
| `-[OOWaypointEntity beaconDrawable]` (235) | `OOWaypointEntity::beaconDrawable` `Core/Entities/OOWaypointEntity.cpp:228` | ✅ |
| `-[OOWaypointEntity prevBeacon]` (258) | `OOWaypointEntity::prevBeacon` `Core/Entities/OOWaypointEntity.cpp:252` | ✅ |
| `-[OOWaypointEntity nextBeacon]` (263) | `OOWaypointEntity::nextBeacon` `Core/Entities/OOWaypointEntity.cpp:257` | ✅ |
| `-[OOWaypointEntity setPrevBeacon:]` (268) | `OOWaypointEntity::setPrevBeacon` `Core/Entities/OOWaypointEntity.cpp:262` | ✅ |
| `-[OOWaypointEntity setNextBeacon:]` (276) | `OOWaypointEntity::setNextBeacon` `Core/Entities/OOWaypointEntity.cpp:269` | ✅ |
| `-[OOWaypointEntity isJammingScanning]` (284) | `OOWaypointEntity::isJammingScanning` `Core/Entities/OOWaypointEntity.cpp:276` | ✅ |

**Differences:**

- ❌ **low** — `compareBeaconCodeWith` substitutes `""` for a missing code on either side. Upstream `[nil compare:...]` answered `NSOrderedSame` for a nil receiver, and `[code compare:nil ...]` took Foundation's nil-argument path. The beacon list holds only coded beacons, so this is unlikely to be observable — upstream `Core/Entities/OOWaypointEntity.m:189` ↔ port `Core/Entities/OOWaypointEntity.cpp:180`
- ➖ **low** — `-dealloc` releases are now RAII members — upstream `Core/Entities/OOWaypointEntity.m:68`
- Subtle (✅): `setBeaconCode` and `setBeaconLabel` replace whenever either side is non-nil. Upstream compared string pointers, so `[wp setBeaconCode:[wp beaconCode]]` kept the cached drawable, which the port rebuilds; the visible result is the same (port comment `:188`). A nil dictionary reproduces messaging nil: zero position, zero quaternion (identity, `oriented=NO`), size 0 ignored, nil code and label (`:57-64`). Defaults are size 1000 (non-negative), code `W`, label `Waypoint`. Orientation defaults to identity, as `oo_quaternionForKey:` does (`OOCollectionExtractors.m:645`). `beaconDrawable` measures length in UTF-16 units, as `-length` did.

## PlanetEntity

<a id="planetentity"></a>
Upstream `src/Core/Entities/PlanetEntity.m` ↔ *(no counterpart: dead upstream)*

**Status:** done — 51 rows: 0 ✅ 0 ⚠️ 0 ❌ 51 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlanetEntity init]` (180) | — (dead upstream: `#if !NEW_PLANETS`) | ➖ |
| `-[PlanetEntity initAsAtmosphereForPlanet:dictionary:]` (187) | — (dead upstream) | ➖ |
| `-[PlanetEntity miniaturize]` (334) | — (dead upstream) | ➖ |
| `-[PlanetEntity initFromDictionary:withAtmosphere:andSeed:]` (351) | — (dead upstream; live path is `OOPlanetEntity::initFromDictionary`) | ➖ |
| `-[PlanetEntity dealloc]` (554) | — (dead upstream) | ➖ |
| `-[PlanetEntity descriptionComponents]` (567) | — (dead upstream) | ➖ |
| `-[PlanetEntity canCollide]` (590) | — (dead upstream) | ➖ |
| `-[PlanetEntity checkCloseCollisionWith:]` (606) | — (dead upstream) | ➖ |
| `-[PlanetEntity update:]` (631) | — (dead upstream) | ➖ |
| `-[PlanetEntity setPosition:]` (695) | — (dead upstream) | ➖ |
| `-[PlanetEntity setOrientation:]` (701) | — (dead upstream) | ➖ |
| `-[PlanetEntity setUseTexturedModel:]` (709) | — (dead upstream) | ➖ |
| `-[PlanetEntity drawImmediate:translucent:]` (721) | — (dead upstream) | ➖ |
| `-[PlanetEntity drawUnconditionally]` (739) | — (dead upstream) | ➖ |
| `-[PlanetEntity atmosphere]` (921) | — (dead upstream) | ➖ |
| `-[PlanetEntity planet_seed]` (927) | — (dead upstream) | ➖ |
| `-[PlanetEntity isTextured]` (932) | — (dead upstream) | ➖ |
| `-[PlanetEntity textureFileName]` (937) | — (dead upstream) | ➖ |
| `-[PlanetEntity setTextureColorForPlanet:inSystem:]` (942) | — (dead upstream) | ➖ |
| `-[PlanetEntity setUpPlanetFromTexture:]` (971) | — (dead upstream) | ➖ |
| `-[PlanetEntity polar_color_factor]` (1008) | — (dead upstream) | ➖ |
| `-[PlanetEntity amb_land]` (1013) | — (dead upstream) | ➖ |
| `-[PlanetEntity amb_polar_land]` (1018) | — (dead upstream) | ➖ |
| `-[PlanetEntity amb_sea]` (1023) | — (dead upstream) | ➖ |
| `-[PlanetEntity amb_polar_sea]` (1028) | — (dead upstream) | ➖ |
| `-[PlanetEntity planetType]` (1033) | — (dead upstream) | ➖ |
| `-[PlanetEntity setPlanetType:]` (1038) | — (dead upstream) | ➖ |
| `-[PlanetEntity radius]` (1043) | — (dead upstream) | ➖ |
| `-[PlanetEntity setRadius:]` (1048) | — (dead upstream) | ➖ |
| `-[PlanetEntity rotationalVelocity]` (1053) | — (dead upstream) | ➖ |
| `-[PlanetEntity setRotationalVelocity:]` (1058) | — (dead upstream) | ➖ |
| `-[PlanetEntity sqrtZeroDistance]` (1067) | — (dead upstream) | ➖ |
| `-[PlanetEntity hasAtmosphere]` (1072) | — (dead upstream) | ➖ |
| `-[PlanetEntity drawModelWithVertexArraysAndSubdivision:]` (1077) | — (dead upstream) | ➖ |
| `-[PlanetEntity launchShuttle]` (1082) | — (dead upstream) | ➖ |
| `-[PlanetEntity welcomeShuttle:]` (1115) | — (dead upstream) | ➖ |
| `-[PlanetEntity initialiseBaseVertexArray]` (1120) | — (dead upstream) | ➖ |
| `baseVertexIndexForEdge()` (1212) | — (dead upstream) | ➖ |
| `-[PlanetEntity initialiseBaseTerrainArray:]` (1255) | — (dead upstream) | ➖ |
| `-[PlanetEntity paintVertex:seed:]` (1320) | — (dead upstream) | ➖ |
| `-[PlanetEntity scaleVertices]` (1369) | — (dead upstream) | ➖ |
| `-[PlanetEntity deleteDisplayLists]` (1382) | — (dead upstream) | ➖ |
| `-[PlanetEntity resetGraphicsState]` (1393) | — (dead upstream) | ➖ |
| `-[PlanetEntity isExplicitlyTextured]` (1398) | — (dead upstream) | ➖ |
| `-[PlanetEntity texture]` (1403) | — (dead upstream) | ➖ |
| `-[PlanetEntity loadTexture:]` (1408) | — (dead upstream) | ➖ |
| `-[PlanetEntity planetTextureWithInfo:]` (1430) | — (dead upstream) | ➖ |
| `-[PlanetEntity cloudTextureWithCloudColor:cloudImpress:cloudBias:]` (1452) | — (dead upstream) | ➖ |
| `-[PlanetEntity allTextures]` (1477) | — (dead upstream) | ➖ |
| `-[PlanetEntity isPlanet]` (1486) | — (dead upstream) | ➖ |
| `-[PlanetEntity isVisible]` (1491) | — (dead upstream) | ➖ |

**Differences:**

- ➖ Dead code upstream. `PlanetEntity.m` is listed in `src/Core/Entities/meson.build:26`, so it is compiled, but its whole body sits inside `#if !NEW_PLANETS` (`PlanetEntity.m:27…1498`). `NEW_PLANETS` defaults to 1 in `OOStellarBody.h:33-35`, which `PlanetEntity.h` imports first (`PlanetEntity.h:26`), and no build file overrides it. The translation unit was therefore empty in every upstream build. The live planet is `OOPlanetEntity` (`OOPlanetEntity.m` is `#if NEW_PLANETS`). Nothing was lost by omitting it — upstream `Core/Entities/PlanetEntity.m:27`

## SkyEntity

<a id="skyentity"></a>
Upstream `src/Core/Entities/SkyEntity.m` ↔ `Core/Entities/SkyEntity.cpp`

**Status:** done — 13 rows: 13 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[SkyEntity initWithColors:col2:andSystemInfo:]` (51) | `SkyEntity::initWithColors` `Core/Entities/SkyEntity.cpp:74` | ✅ |
| `-[SkyEntity dealloc]` (138) | implicit (`skyColor` is an `oo::Ref`) | ✅ |
| `-[SkyEntity skyColor]` (145) | `SkyEntity::getSkyColor` `Core/Entities/SkyEntity.cpp:158` | ✅ |
| `-[SkyEntity changeProperty:withDictionary:]` (150) | `SkyEntity::changeProperty` `Core/Entities/SkyEntity.cpp:163` | ✅ |
| `-[SkyEntity update:]` (170) | `SkyEntity::update` `Core/Entities/SkyEntity.cpp:181` | ✅ |
| `-[SkyEntity isSky]` (182) | `SkyEntity::isSky` `Core/Entities/SkyEntity.cpp:193` | ✅ |
| `-[SkyEntity isVisible]` (187) | `SkyEntity::isVisible` `Core/Entities/SkyEntity.cpp:198` | ✅ |
| `-[SkyEntity canCollide]` (192) | `SkyEntity::canCollide` `Core/Entities/SkyEntity.cpp:203` | ✅ |
| `-[SkyEntity cameraRangeFront]` (197) | `SkyEntity::cameraRangeFront` `Core/Entities/SkyEntity.cpp:208` | ✅ |
| `-[SkyEntity cameraRangeBack]` (202) | `SkyEntity::cameraRangeBack` `Core/Entities/SkyEntity.cpp:213` | ✅ |
| `-[SkyEntity drawImmediate:translucent:]` (207) | `SkyEntity::drawImmediate` `Core/Entities/SkyEntity.cpp:218` | ✅ |
| `-[SkyEntity descriptionForObjDump]` (218) | `SkyEntity::descriptionForObjDump` `Core/Entities/SkyEntity.cpp:229` | ✅ |
| `-[SkyEntity(OOPrivate) readColor1:andColor2:andColor3:andColor4:fromDictionary:]` (229) | `SkyEntity::readColor1` `Core/Entities/SkyEntity.cpp:236` | ✅ |

**Differences:**

- None. Subtle (✅): star and nebula counts keep the float→`signed` truncation (`sky_n_stars`/`sky_n_blurs` default -1, multipliers made non-negative, `SKY_BASIS_* * (0.5+randf())`, reduced detail caps at basis and halves stars). Colour precedence is the same: `sky_rgb_colors`, then premultiplied `sky_color_1/2`, then `nebula_color_1/2` falling back to sky colours. The warning texts are the same — upstream `Core/Entities/SkyEntity.m:66-133,229-311` ↔ port `Core/Entities/SkyEntity.cpp:88-156,236-319`

## WormholeEntity

<a id="wormholeentity"></a>
Upstream `src/Core/Entities/WormholeEntity.m` ↔ `Core/Entities/WormholeEntity.cpp`

**Status:** done — 38 rows: 38 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[WormholeEntity(Private) init]` (58) | `WormholeEntity::init` `Core/Entities/WormholeEntity.cpp:66` | ✅ |
| `-[WormholeEntity initWithDict:]` (84) | `WormholeEntity::initWithDict` `Core/Entities/WormholeEntity.cpp:88` | ✅ |
| `-[WormholeEntity initWormholeTo:fromShip:]` (144) | `WormholeEntity::initWormholeTo` `Core/Entities/WormholeEntity.cpp:147` | ✅ |
| `-[WormholeEntity setMisjump]` (189) | `WormholeEntity::setMisjump` `Core/Entities/WormholeEntity.cpp:193` | ✅ |
| `-[WormholeEntity setMisjumpWithRange:]` (204) | `WormholeEntity::setMisjumpWithRange` `Core/Entities/WormholeEntity.cpp:208` | ✅ |
| `-[WormholeEntity withMisjump]` (226) | `WormholeEntity::withMisjump` `Core/Entities/WormholeEntity.cpp:230` | ✅ |
| `-[WormholeEntity misjumpRange]` (231) | `WormholeEntity::misjumpRange` `Core/Entities/WormholeEntity.cpp:235` | ✅ |
| `-[WormholeEntity suckInShip:]` (236) | `WormholeEntity::suckInShip` `Core/Entities/WormholeEntity.cpp:240` | ✅ |
| `-[WormholeEntity disgorgeShips]` (317) | `WormholeEntity::disgorgeShips` `Core/Entities/WormholeEntity.cpp:328` | ✅ |
| `-[WormholeEntity setContainsPlayer:]` (448) | `WormholeEntity::setContainsPlayer` `Core/Entities/WormholeEntity.cpp:477` | ✅ |
| `-[WormholeEntity setExitPosition:]` (453) | `WormholeEntity::setExitPosition` `Core/Entities/WormholeEntity.cpp:482` | ✅ |
| `-[WormholeEntity origin]` (459) | `WormholeEntity::getOrigin` `Core/Entities/WormholeEntity.cpp:488` | ✅ |
| `-[WormholeEntity destination]` (464) | `WormholeEntity::getDestination` `Core/Entities/WormholeEntity.cpp:493` | ✅ |
| `-[WormholeEntity originCoordinates]` (469) | `WormholeEntity::originCoordinates` `Core/Entities/WormholeEntity.cpp:498` | ✅ |
| `-[WormholeEntity destinationCoordinates]` (474) | `WormholeEntity::destinationCoordinates` `Core/Entities/WormholeEntity.cpp:503` | ✅ |
| `-[WormholeEntity exitSpeed]` (479) | `WormholeEntity::exitSpeed` `Core/Entities/WormholeEntity.cpp:508` | ✅ |
| `-[WormholeEntity setExitSpeed:]` (484) | `WormholeEntity::setExitSpeed` `Core/Entities/WormholeEntity.cpp:513` | ✅ |
| `-[WormholeEntity expiryTime]` (489) | `WormholeEntity::expiryTime` `Core/Entities/WormholeEntity.cpp:518` | ✅ |
| `-[WormholeEntity arrivalTime]` (494) | `WormholeEntity::arrivalTime` `Core/Entities/WormholeEntity.cpp:523` | ✅ |
| `-[WormholeEntity estimatedArrivalTime]` (499) | `WormholeEntity::estimatedArrivalTime` `Core/Entities/WormholeEntity.cpp:528` | ✅ |
| `-[WormholeEntity travelTime]` (504) | `WormholeEntity::travelTime` `Core/Entities/WormholeEntity.cpp:533` | ✅ |
| `-[WormholeEntity scanTime]` (509) | `WormholeEntity::scanTime` `Core/Entities/WormholeEntity.cpp:538` | ✅ |
| `-[WormholeEntity isScanned]` (514) | `WormholeEntity::isScanned` `Core/Entities/WormholeEntity.cpp:543` | ✅ |
| `-[WormholeEntity setScannedAt:]` (519) | `WormholeEntity::setScannedAt` `Core/Entities/WormholeEntity.cpp:548` | ✅ |
| `-[WormholeEntity scanInfo]` (528) | `WormholeEntity::scanInfo` `Core/Entities/WormholeEntity.cpp:557` | ✅ |
| `-[WormholeEntity setScanInfo:]` (533) | `WormholeEntity::setScanInfo` `Core/Entities/WormholeEntity.cpp:562` | ✅ |
| `-[WormholeEntity shipsInTransit]` (538) | `WormholeEntity::getShipsInTransit` `Core/Entities/WormholeEntity.cpp:567` (+ `WormholeEntityShipsInTransit` :853) | ✅ |
| `-[WormholeEntity dealloc]` (543) | implicit (`std::vector<OOWormholeTransit>` member) | ✅ |
| `-[WormholeEntity descriptionComponents]` (550) | `WormholeEntity::descriptionComponents` `Core/Entities/WormholeEntity.cpp:583` | ✅ |
| `-[WormholeEntity identFromShip:]` (559) | `WormholeEntity::identFromShip` `Core/Entities/WormholeEntity.cpp:592` | ✅ |
| `-[WormholeEntity canCollide]` (578) | `WormholeEntity::canCollide` `Core/Entities/WormholeEntity.cpp:611` | ✅ |
| `-[WormholeEntity checkCloseCollisionWith:]` (593) | `WormholeEntity::checkCloseCollisionWith` `Core/Entities/WormholeEntity.cpp:627` | ✅ |
| `-[WormholeEntity update:]` (598) | `WormholeEntity::update` `Core/Entities/WormholeEntity.cpp:632` | ✅ |
| `-[WormholeEntity drawImmediate:translucent:]` (626) | `WormholeEntity::drawImmediate` `Core/Entities/WormholeEntity.cpp:661` | ✅ |
| `DrawWormholeCorona()` (669) | `DrawWormholeCorona` `Core/Entities/WormholeEntity.cpp:704` | ✅ |
| `-[WormholeEntity getDict]` (729) | `WormholeEntity::getDict` `Core/Entities/WormholeEntity.cpp:764` | ✅ |
| `-[WormholeEntity scanInfoString]` (761) | `WormholeEntity::scanInfoString` `Core/Entities/WormholeEntity.cpp:797` | ✅ |
| `-[WormholeEntity dumpSelfState]` (780) | `WormholeEntity::dumpSelfState` `Core/Entities/WormholeEntity.cpp:816` | ✅ |

**Differences:**

- None. Subtle (✅): lifetime, mass and expiry maths are identical:
  - Minimum `witch_mass` is 200000, plus the player's mass for the player. `shrink_factor = mass/240000` for ships over 240000 in a nova system, else 1.
  - `collision_radius = 0.5π·∛mass`. `expiry = now + mass/WORMHOLE_SHRINK_RATE/shrink_factor`, recomputed per sucked-in ship and always capped to `arrival-1`.
  - Travel time is `d²·3600` with `d ≥ 0.1`. Misjump subtracts `d²·900`, or `(d(1-r))²·3600` for a misjump with a range.
  - Shrinking per tick is clamped at 0. `shrink_factor` is 0 for dict-loaded wormholes on both sides (upstream ivar zero-init, port `= { }`).

  Upstream `Core/Entities/WormholeEntity.m:144-187,236-315,598-624` ↔ port `Core/Entities/WormholeEntity.cpp:147-191,240-326,632-659`
- Subtle (✅): `shipsInTransit` order is insertion order on both sides (NSMutableArray ↔ `std::vector`), in `suckInShip`, `initWithDict` (savegame `ships` order), `disgorgeShips`' still-in-transit list and `getDict`. The port's `getShipsInTransit` always emits `"time"` (0 when the save lacked `time_delta`; upstream omitted the key). The only consumers are `-count` and `"ship"` (`PlayerEntity.cpp:7410,12208`, `OODebugMonitor.cpp:417`) — upstream `Core/Entities/WormholeEntity.m:130-133,281-285,335` ↔ port `Core/Entities/WormholeEntity.cpp:136,285-287,347,567-581`
- Subtle (✅): the arrival-position RNG draws in the same order: `quaternion_set_random`, then `ranrot_rand()%256` for `d1`, with the `min_d1` (×3 behind the buoy) push-out applied once. Later ships take `randf()` x then y for ±75 m scatter. The port iterates a snapshot of `shipsInTransit`, which is equivalent to upstream's fast enumeration since upstream would have thrown on mutation — upstream `Core/Entities/WormholeEntity.m:338-371` ↔ port `Core/Entities/WormholeEntity.cpp:336-384`

