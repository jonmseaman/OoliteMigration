# Parity findings: entities-other
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## DustEntity

<a id="dustentity"></a>
Upstream `src/Core/Entities/DustEntity.m` ↔ `Core/Entities/DustEntity.cpp` (418 / 423 lines)

**Status:** done — 14 rows: 13 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[DustEntity init]` (62) | `DustEntity::init` `Core/Entities/DustEntity.cpp:78` | ✅ |
| `-[DustEntity dealloc]` (113) | `DustEntity::~DustEntity` `Core/Entities/DustEntity.cpp:74` (unregister; members release) | ✅ |
| `-[DustEntity setDustColor:]` (127) | `DustEntity::setDustColor` `Core/Entities/DustEntity.cpp:131` | ✅ |
| `-[DustEntity dustColor]` (135) | `DustEntity::dustColor` `Core/Entities/DustEntity.cpp:138` | ✅ |
| `-[DustEntity canCollide]` (140) | `DustEntity::canCollide` `Core/Entities/DustEntity.cpp:140` | ✅ |
| `-[DustEntity updateCameraRelativePosition]` (145) | `DustEntity::updateCameraRelativePosition` `Core/Entities/DustEntity.cpp:142` | ✅ |
| `-[DustEntity update:]` (151) | `DustEntity::update` `Core/Entities/DustEntity.cpp:151` | ✅ |
| `-[DustEntity shader]` (187) | `DustEntity::getShader` `Core/Entities/DustEntity.cpp:181` | ❌ |
| `-[DustEntity offsetPlayerPosition]` (227) | `DustEntity::offsetPlayerPosition` `Core/Entities/DustEntity.cpp:218` | ✅ |
| `-[DustEntity checkShaderMode]` (235) | `DustEntity::checkShaderMode` `Core/Entities/DustEntity.cpp:230` | ✅ |
| `-[DustEntity warpVector]` (246) | `DustEntity::warpVector` `Core/Entities/DustEntity.cpp:241` | ✅ |
| `-[DustEntity drawImmediate:translucent:]` (251) | `DustEntity::drawImmediate` `Core/Entities/DustEntity.cpp:247` | ✅ |
| `-[DustEntity resetGraphicsState]` (395) | `DustEntity::resetGraphicsState` `Core/Entities/DustEntity.cpp:403` | ✅ |
| `-[DustEntity descriptionForObjDump]` (411) | `DustEntity::descriptionForObjDump` `Core/Entities/DustEntity.cpp:419` | ✅ |

**Differences:**

- ❌ **low** — `initWithObjects:uWarp, uOffsetPlayerPosition, nil` stops at the first nil: if `uWarp` fails to bind (custom `oolite-dust.vertex` without `uWarp`), upstream applies neither uniform. The port pushes both and skips only the null one, so `uOffsetPlayerPosition` still applies (still open) — upstream `Core/Entities/DustEntity.m:219` ↔ port `Core/Entities/DustEntity.cpp:211-212,314-315`
- Subtle (✅): shader prefix moved from `%g` to `std::format("{:g}")`; both use 6 significant digits for the three float defines (covered by commit 371272857). `color_fv` stays zero until `setDustColor` is called on both sides — upstream `Core/Entities/DustEntity.m:93,190` ↔ port `Core/Entities/DustEntity.cpp:109,183`

## Entity

<a id="entity"></a>
Upstream `src/Core/Entities/Entity.m` ↔ `Core/Entities/Entity.cpp` (1055 / 956 lines)

**Status:** done — 106 rows: 105 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[Entity init]` (64) | `Entity::Entity` + `Entity::init` `Core/Entities/Entity.cpp:63,67` | ✅ |
| `-[Entity dealloc]` (98) | `Entity::willDispose` `Core/Entities/Entity.cpp:97` | ✅ |
| `-[Entity descriptionComponents]` (115) | `Entity::descriptionComponents` `Core/Entities/Entity.cpp:137` | ✅ |
| `-[Entity sessionID]` (120) | `Entity::sessionID` `Core/Entities/Entity.cpp:145` | ✅ |
| `-[Entity isShip]` (125) | `Entity::getIsShip` `Core/Entities/Entity.cpp:147` | ✅ |
| `-[Entity isDock]` (130) | `Entity::isDock` `Core/Entities/Entity.cpp:149` | ✅ |
| `-[Entity isStation]` (135) | `Entity::getIsStation` `Core/Entities/Entity.cpp:151` | ✅ |
| `-[Entity isSubEntity]` (140) | `Entity::getIsSubEntity` `Core/Entities/Entity.cpp:153` | ✅ |
| `-[Entity isPlayer]` (145) | `Entity::getIsPlayer` `Core/Entities/Entity.cpp:155` | ✅ |
| `-[Entity isPlanet]` (150) | `Entity::isPlanet` `Core/Entities/Entity.cpp:157` | ✅ |
| `-[Entity isSun]` (155) | `Entity::isSun` `Core/Entities/Entity.cpp:159` | ✅ |
| `-[Entity isSunlit]` (160) | `Entity::getIsSunlit` `Core/Entities/Entity.cpp:161` | ✅ |
| `-[Entity isStellarObject]` (165) | `Entity::isStellarObject` `Core/Entities/Entity.cpp:163` | ✅ |
| `-[Entity isSky]` (170) | `Entity::isSky` `Core/Entities/Entity.cpp:165` | ✅ |
| `-[Entity isWormhole]` (175) | `Entity::getIsWormhole` `Core/Entities/Entity.cpp:167` | ✅ |
| `-[Entity isEffect]` (180) | `Entity::isEffect` `Core/Entities/Entity.cpp:169` | ✅ |
| `-[Entity isVisualEffect]` (185) | `Entity::getIsVisualEffect` `Core/Entities/Entity.cpp:171` | ✅ |
| `-[Entity isWaypoint]` (190) | `Entity::isWaypoint` `Core/Entities/Entity.cpp:173` | ✅ |
| `-[Entity validForAddToUniverse]` (195) | `Entity::validForAddToUniverse` `Core/Entities/Entity.cpp:175` | ✅ |
| `-[Entity addToLinkedLists]` (207) | `Entity::addToLinkedLists` `Core/Entities/Entity.cpp:192` | ✅ |
| `-[Entity removeFromLinkedLists]` (269) | `Entity::removeFromLinkedLists` `Core/Entities/Entity.cpp:257` | ✅ |
| `-[Entity checkLinkedLists]` (321) | `Entity::checkLinkedLists` `Core/Entities/Entity.cpp:307` | ✅ |
| `-[Entity updateLinkedLists]` (393) | `Entity::updateLinkedLists` `Core/Entities/Entity.cpp:384` | ✅ |
| `-[Entity wasAddedToUniverse]` (489) | `Entity::wasAddedToUniverse` `Core/Entities/Entity.cpp:490` | ✅ |
| `-[Entity wasRemovedFromUniverse]` (494) | `Entity::wasRemovedFromUniverse` `Core/Entities/Entity.cpp:494` | ✅ |
| `-[Entity warnAboutHostiles]` (499) | `Entity::warnAboutHostiles` `Core/Entities/Entity.cpp:498` | ✅ |
| `-[Entity collisionRegion]` (505) | `Entity::getCollisionRegion` `Core/Entities/Entity.cpp:504` | ✅ |
| `-[Entity setCollisionRegion:]` (510) | `Entity::setCollisionRegion` `Core/Entities/Entity.cpp:506` | ✅ |
| `-[Entity setUniversalID:]` (517) | `Entity::setUniversalID` `Core/Entities/Entity.cpp:510` | ✅ |
| `-[Entity universalID]` (522) | `Entity::getUniversalID` `Core/Entities/Entity.cpp:512` | ✅ |
| `-[Entity throwingSparks]` (527) | `Entity::throwingSparks` `Core/Entities/Entity.cpp:514` | ✅ |
| `-[Entity setThrowSparks:]` (532) | `Entity::setThrowSparks` `Core/Entities/Entity.cpp:516` | ✅ |
| `-[Entity throwSparks]` (537) | `Entity::throwSparks` `Core/Entities/Entity.cpp:518` | ✅ |
| `-[Entity setOwner:]` (542) | `Entity::setOwner` `Core/Entities/Entity.cpp:522` | ✅ |
| `-[Entity owner]` (548) | `Entity::owner` `Core/Entities/Entity.cpp:527` | ✅ |
| `-[Entity parentEntity]` (553) | `Entity::parentEntity` `Core/Entities/Entity.cpp:542` | ✅ |
| `-[Entity superShaderBindingTarget]` (561) | `Entity::superShaderBindingTarget` `Core/Entities/Entity.cpp:548` | ✅ |
| `-[Entity rootShipEntity]` (566) | `Entity::rootShipEntity` `Core/Entities/Entity.cpp:552` | ✅ |
| `-[Entity position]` (576) | `Entity::getPosition` `Core/Entities/Entity.cpp:559` | ✅ |
| `-[Entity cameraRelativePosition]` (581) | `Entity::getCameraRelativePosition` `Core/Entities/Entity.cpp:561` | ✅ |
| `-[Entity cameraRangeFront]` (586) | `Entity::cameraRangeFront` `Core/Entities/Entity.cpp:563` | ✅ |
| `-[Entity cameraRangeBack]` (591) | `Entity::cameraRangeBack` `Core/Entities/Entity.cpp:567` | ✅ |
| `-[Entity relativePosition]` (598) | `Entity::relativePosition` `Core/Entities/Entity.cpp:573` | ✅ |
| `-[Entity vectorTo:]` (603) | `Entity::vectorTo` `Core/Entities/Entity.cpp:578` | ✅ |
| `-[Entity setPosition:]` (608) | `Entity::setPosition` `Core/Entities/Entity.cpp:585` | ✅ |
| `-[Entity setPositionX:y:z:]` (614) | `Entity::setPositionX` `Core/Entities/Entity.cpp:590` | ✅ |
| `-[Entity updateCameraRelativePosition]` (622) | `Entity::updateCameraRelativePosition` `Core/Entities/Entity.cpp:597` | ✅ |
| `-[Entity absolutePositionForSubentity]` (627) | `Entity::absolutePositionForSubentity` `Core/Entities/Entity.cpp:603` | ✅ |
| `-[Entity absolutePositionForSubentityOffset:]` (632) | `Entity::absolutePositionForSubentityOffset` `Core/Entities/Entity.cpp:607` | ✅ |
| `-[Entity zeroDistance]` (648) | `Entity::zeroDistance` `Core/Entities/Entity.cpp:624` | ✅ |
| `-[Entity camZeroDistance]` (653) | `Entity::camZeroDistance` `Core/Entities/Entity.cpp:626` | ✅ |
| `-[Entity compareZeroDistance:]` (658) | `Entity::compareZeroDistance` `Core/Entities/Entity.cpp:628` | ✅ |
| `-[Entity boundingBox]` (666) | `Entity::getBoundingBox` `Core/Entities/Entity.cpp:635` | ✅ |
| `-[Entity mass]` (671) | `Entity::getMass` `Core/Entities/Entity.cpp:637` | ✅ |
| `-[Entity setOrientation:]` (676) | `Entity::setOrientation` `Core/Entities/Entity.cpp:639` | ✅ |
| `-[Entity orientation]` (682) | `Entity::getOrientation` `Core/Entities/Entity.cpp:644` | ✅ |
| `-[Entity normalOrientation]` (687) | `Entity::normalOrientation` `Core/Entities/Entity.cpp:646` | ✅ |
| `-[Entity setNormalOrientation:]` (692) | `Entity::setNormalOrientation` `Core/Entities/Entity.cpp:648` | ✅ |
| `-[Entity orientationChanged]` (697) | `Entity::orientationChanged` `Core/Entities/Entity.cpp:650` | ✅ |
| `-[Entity setVelocity:]` (703) | `Entity::setVelocity` `Core/Entities/Entity.cpp:655` | ✅ |
| `-[Entity velocity]` (708) | `Entity::getVelocity` `Core/Entities/Entity.cpp:657` | ✅ |
| `-[Entity speed]` (713) | `Entity::speed` `Core/Entities/Entity.cpp:659` | ✅ |
| `-[Entity distanceTravelled]` (718) | `Entity::getDistanceTravelled` `Core/Entities/Entity.cpp:661` | ✅ |
| `-[Entity setDistanceTravelled:]` (723) | `Entity::setDistanceTravelled` `Core/Entities/Entity.cpp:663` | ✅ |
| `-[Entity setStatus:]` (728) | `Entity::setStatus` `Core/Entities/Entity.cpp:665` | ✅ |
| `-[Entity status]` (733) | `Entity::status` `Core/Entities/Entity.cpp:667` | ✅ |
| `-[Entity setScanClass:]` (738) | `Entity::setScanClass` `Core/Entities/Entity.cpp:669` | ✅ |
| `-[Entity scanClass]` (743) | `Entity::getScanClass` `Core/Entities/Entity.cpp:671` | ✅ |
| `-[Entity setEnergy:]` (748) | `Entity::setEnergy` `Core/Entities/Entity.cpp:673` | ✅ |
| `-[Entity energy]` (753) | `Entity::getEnergy` `Core/Entities/Entity.cpp:675` | ✅ |
| `-[Entity setMaxEnergy:]` (758) | `Entity::setMaxEnergy` `Core/Entities/Entity.cpp:677` | ✅ |
| `-[Entity maxEnergy]` (763) | `Entity::getMaxEnergy` `Core/Entities/Entity.cpp:679` | ✅ |
| `-[Entity applyRoll:andClimb:]` (768) | `Entity::applyRoll(roll, climb)` `Core/Entities/Entity.cpp:681` | ✅ |
| `-[Entity applyRoll:climb:andYaw:]` (781) | `Entity::applyRoll(roll, climb, yaw)` `Core/Entities/Entity.cpp:690` | ✅ |
| `-[Entity moveForward:]` (796) | `Entity::moveForward` `Core/Entities/Entity.cpp:700` | ✅ |
| `-[Entity rotationMatrix]` (803) | `Entity::rotationMatrix` `Core/Entities/Entity.cpp:707` | ✅ |
| `-[Entity drawRotationMatrix]` (808) | `Entity::drawRotationMatrix` `Core/Entities/Entity.cpp:709` | ✅ |
| `-[Entity transformationMatrix]` (813) | `Entity::transformationMatrix` `Core/Entities/Entity.cpp:711` | ✅ |
| `-[Entity drawTransformationMatrix]` (819) | `Entity::drawTransformationMatrix` `Core/Entities/Entity.cpp:716` | ✅ |
| `-[Entity canCollide]` (825) | `Entity::canCollide` `Core/Entities/Entity.cpp:721` | ✅ |
| `-[Entity collisionRadius]` (830) | `Entity::collisionRadius` `Core/Entities/Entity.cpp:723` | ✅ |
| `-[Entity frustumRadius]` (835) | `Entity::frustumRadius` `Core/Entities/Entity.cpp:725` | ✅ |
| `-[Entity setCollisionRadius:]` (840) | `Entity::setCollisionRadius` `Core/Entities/Entity.cpp:727` | ✅ |
| `-[Entity collisionArray]` (845) | `Entity::getCollidingEntities` `Core/Entities/Entity.cpp:729` (`std::vector<oo::EntityHold>*`) | ✅ |
| `-[Entity update:]` (850) | `Entity::update` `Core/Entities/Entity.cpp:733` | ✅ |
| `-[Entity applyVelocity:]` (878) | `Entity::applyVelocity` `Core/Entities/Entity.cpp:765` | ✅ |
| `-[Entity checkCloseCollisionWith:]` (883) | `Entity::checkCloseCollisionWith` `Core/Entities/Entity.cpp:770` | ✅ |
| `-[Entity findCollisionRadius]` (888) | `Entity::findCollisionRadius` `Core/Entities/Entity.cpp:772` | ✅ |
| `-[Entity drawImmediate:translucent:]` (894) | `Entity::drawImmediate` `Core/Entities/Entity.cpp:777` | ✅ |
| `-[Entity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (899) | `Entity::takeEnergyDamage` `Core/Entities/Entity.cpp:781` | ✅ |
| `-[Entity dumpState]` (903) | `Entity::dumpState` `Core/Entities/Entity.cpp:785` | ✅ |
| `-[Entity dumpSelfState]` (918) | `Entity::dumpSelfState` `Core/Entities/Entity.cpp:800` | ✅ |
| `-[Entity subEntityReallyDied:]` (958) | `Entity::subEntityReallyDied` `Core/Entities/Entity.cpp:854` | ❌ |
| `-[Entity lastDrawCounter]` (963) | `Entity::getLastDrawCounter` `Core/Entities/Entity.cpp:860` | ✅ |
| `-[Entity setLastDrawCounter:]` (968) | `Entity::setLastDrawCounter` `Core/Entities/Entity.cpp:862` | ✅ |
| `-[Entity universalTime]` (975) | `Entity::universalTime` `Core/Entities/Entity.cpp:868` | ✅ |
| `-[Entity spawnTime]` (980) | `Entity::getSpawnTime` `Core/Entities/Entity.cpp:872` | ✅ |
| `-[Entity timeElapsedSinceSpawn]` (985) | `Entity::timeElapsedSinceSpawn` `Core/Entities/Entity.cpp:874` | ✅ |
| `-[Entity setAtmosphereFogging:]` (990) | `Entity::setAtmosphereFogging` `Core/Entities/Entity.cpp:878` | ✅ |
| `-[Entity fogUniform]` (996) | `Entity::fogUniform` `Core/Entities/Entity.cpp:882` | ✅ |
| `-[Entity descriptionForObjDumpBasic]` (1002) | `Entity::descriptionForObjDumpBasic` `Core/Entities/Entity.cpp:885` | ✅ |
| `-[Entity descriptionForObjDump]` (1013) | `Entity::descriptionForObjDump` `Core/Entities/Entity.cpp:893` | ✅ |
| `-[Entity allTextures]` (1022) | `Entity::allTextures` `Core/Entities/Entity.cpp:905` | ✅ |
| `-[Entity isVisible]` (1028) | `Entity::isVisible` `Core/Entities/Entity.cpp:908` | ✅ |
| `-[Entity isInSpace]` (1033) | `Entity::isInSpace` `Core/Entities/Entity.cpp:912` | ✅ |
| `-[Entity isImmuneToBreakPatternHide]` (1050) | `Entity::getIsImmuneToBreakPatternHide` `Core/Entities/Entity.cpp:928` | ✅ |

**Differences:**

- ❌ **low** — the `entity.bug` line prints `__PRETTY_FUNCTION__`, which is now the C++ signature (`void Entity::subEntityReallyDied(ShipEntity*)`) instead of `-[Entity subEntityReallyDied:]`, so the log text differs (still open) — upstream `Core/Entities/Entity.m:960` ↔ port `Core/Entities/Entity.cpp:855`
- Subtle (✅): `update`/`applyVelocity`/`moveForward`/`applyRoll*`/`orientationChanged` match line for line (same order of zero/cam-zero distance, camera-relative position, `applyVelocity` outside `kCockpitDisplay`, then `hasMoved`/`hasRotated`). A sub-entity with a dead owner reads 0, as `[nil zeroDistance]`; `PLAYER->position` is unguarded on both sides — upstream `Core/Entities/Entity.m:850-876` ↔ port `Core/Entities/Entity.cpp:733-763`
- Subtle (✅): `willDispose` keeps upstream's `dealloc` order (ensureEntityReallyRemoved, collision region, `deleteJSSelf`, owner, fogging); ship/player/station/dock teardown now runs first from here, and the `universe.unremovedEntity` log moved here from `-[Universe ensureEntityReallyRemoved:]`. `gLiveEntityCount++` lives in `EntityHelpers.cpp:77,91` — upstream `Core/Entities/Entity.m:98-113` ↔ port `Core/Entities/Entity.cpp:97-135`
- Subtle (✅): `descriptionComponents` reads `_status` directly instead of `[self status]`; no subclass overrides `status()`, so the text is the same — port `Core/Entities/Entity.cpp:137-143`

## EntityShaderBindings

<a id="entityshaderbindings"></a>
Upstream `src/Core/Entities/EntityShaderBindings.m` ↔ `Core/Entities/EntityShaderBindings.cpp` (77 / 976 lines)

**Status:** done — 14 rows: 12 ✅ 0 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[Entity(ShaderBindings) clock]` (35) | `Entity::clock` `Core/Entities/EntityShaderBindings.cpp:53` | ✅ |
| `-[Entity(ShaderBindings) pseudoFixedD100]` (41) | `Entity::pseudoFixedD100` `Core/Entities/EntityShaderBindings.cpp:58` | ✅ |
| `-[Entity(ShaderBindings) pseudoFixedD256]` (46) | `Entity::pseudoFixedD256` `Core/Entities/EntityShaderBindings.cpp:62` | ✅ |
| `-[Entity(ShaderBindings) systemGovernment]` (52) | `Entity::systemGovernment` `Core/Entities/EntityShaderBindings.cpp:67` | ✅ |
| `-[Entity(ShaderBindings) systemEconomy]` (57) | `Entity::systemEconomy` `Core/Entities/EntityShaderBindings.cpp:72` | ✅ |
| `-[Entity(ShaderBindings) systemTechLevel]` (62) | `Entity::systemTechLevel` `Core/Entities/EntityShaderBindings.cpp:77` | ✅ |
| `-[Entity(ShaderBindings) systemPopulation]` (67) | `Entity::systemPopulation` `Core/Entities/EntityShaderBindings.cpp:82` | ✅ |
| `-[Entity(ShaderBindings) systemProductivity]` (72) | `Entity::systemProductivity` `Core/Entities/EntityShaderBindings.cpp:87` | ✅ |
| *(added)* selector binding of `shader_entity_binding_methods` (`Resources/Config/whitelist.plist`) on any entity | `kEntityShaderBindings` rows `Core/Entities/EntityShaderBindings.cpp:150-270,742` | ✅ |
| *(added)* selector binding of `shader_ship_binding_methods` (ship only) | `kEntityShaderBindings` rows `Core/Entities/EntityShaderBindings.cpp:271-825` | ❌ |
| *(added)* selector binding of `shader_player_ship_binding_methods` (player/proxy) | `kEntityShaderBindings` rows incl. `tradeInFactor` `Core/Entities/EntityShaderBindings.cpp:169,826` | ✅ |
| *(added)* selector binding of `shader_visual_effect_binding_methods` (effects) | `kEntityShaderBindings` rows `Core/Entities/EntityShaderBindings.cpp:750-785,840-885` | ✅ |
| *(added)* `OOUniformBindingPermitted()` (`Core/Entities/ShipEntity.m:13006`), the whitelist gate | `OOUniformBindingPermitted` `Core/Entities/ShipEntity.cpp:14039` | ✅ |
| *(added)* `[target class]` in the bind-failure logs (`Core/Materials/OOShaderUniform.m:153,356`, `OOShaderMaterial.m:328`) | `ShaderClassName` hook `Core/Entities/EntityShaderBindings.cpp:944` | ❌ |

**Differences:**

- ❌ **med** — **`laserColor` cannot be bound.** It is whitelisted for ships and upstream `-laserColor` returns an `OOColor` uploaded as a vec4. The port table has no `laserColor` row (its comment at `:98` claims there is no method, but `ShipEntity::laserColor` exists at `ShipEntity.cpp:10937`, and `OOShaderUniform.cpp:535` handles colour values). The whitelist passes, the member lookup fails, `shader.uniform.bind.failed` is logged and the uniform stays unset. All other 85 whitelisted names have rows (script cross-check) (still open) — upstream `Core/Materials/OOShaderUniform.m:506` ↔ port `Core/Entities/EntityShaderBindings.cpp:98,150-886`
- ❌ **low** — the bind-failure and unpermitted-method logs print `[target class]`. Upstream gave the real class (`ShipEntity`, `PlayerEntity`, `OOPlanetEntity`…); the port's hook always answers `"Entity"` (or `"(null)"`), so the log text differs (still open) — upstream `Core/Materials/OOShaderUniform.m:356` ↔ port `Core/Entities/EntityShaderBindings.cpp:944-947`
- Subtle (✅): rows whose `answers` predicate is broader than upstream `respondsToSelector:` (`isBeacon`/`isJammingScanning` on waypoints, `shaderFloat1…shaderVector2` on every entity) are still refused by the whitelist gate, which matches upstream including `isPlayerLikeShip` → Player/Proxy casts. `system*` with no PLAYER answer 0, as nil did — port `Core/Entities/ShipEntity.cpp:14052-14066`, `Core/Entities/EntityShaderBindings.cpp:48-90`

## OOBreakPatternEntity

<a id="oobreakpatternentity"></a>
Upstream `src/Core/Entities/OOBreakPatternEntity.m` ↔ `Core/Entities/OOBreakPatternEntity.cpp` (169 / 153 lines)

**Status:** done — 10 rows: 8 ✅ 0 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOBreakPatternEntity initWithPolygonSides:startAngle:aspectRatio:]` (41) | `OOBreakPatternEntity::initWithPolygonSides` `Core/Entities/OOBreakPatternEntity.cpp:36` | ✅ |
| `+[OOBreakPatternEntity breakPatternWithPolygonSides:startAngle:aspectRatio:]` (78) | `OOBreakPatternEntity::breakPatternWithPolygonSides` `Core/Entities/OOBreakPatternEntity.cpp:75` | ✅ |
| `-[OOBreakPatternEntity setInnerColor:outerColor:]` (83) | `OOBreakPatternEntity::setInnerColor` `Core/Entities/OOBreakPatternEntity.cpp:84` | ✅ |
| `-[OOBreakPatternEntity setInnerColorComponents:outerColorComponents:]` (91) | `OOBreakPatternEntity::setInnerColorComponents` `Core/Entities/OOBreakPatternEntity.cpp:95` | ✅ |
| `-[OOBreakPatternEntity setLifetime:]` (101) | `OOBreakPatternEntity::setLifetime` `Core/Entities/OOBreakPatternEntity.cpp:105` | ✅ |
| `-[OOBreakPatternEntity update:]` (106) | `OOBreakPatternEntity::update` `Core/Entities/OOBreakPatternEntity.cpp:109` | ✅ |
| `-[OOBreakPatternEntity drawImmediate:translucent:]` (116) | `OOBreakPatternEntity::drawImmediate` `Core/Entities/OOBreakPatternEntity.cpp:118` | ✅ |
| `-[OOBreakPatternEntity canCollide]` (150) | `OOBreakPatternEntity::canCollide` `Core/Entities/OOBreakPatternEntity.cpp:153` | ✅ |
| `-[OOBreakPatternEntity isBreakPattern]` (155) | none; `Universe::removeEntity` uses `dynamic_cast<OOBreakPatternEntity*>` `Core/Universe.cpp:10968` | ➖ |
| `-[Entity(OOBreakPatternEntity) isBreakPattern]` (164) | none; by-name `isBreakPattern` is effect-only (`Core/Entities/OOEntityCalledByNameTable.h:2997`) | ➖ |

**Differences:**

- ➖ **low** — `-isBreakPattern` on the ring and the Entity category are gone. The only real caller (the breakPatternCounter test in `-removeEntity:`) is now an equivalent `dynamic_cast`. A by-name query on a core ring now answers NO where it answered YES; scripts cannot reach a core ring (still open) — upstream `Core/Entities/OOBreakPatternEntity.m:155,164` ↔ port `Core/Universe.cpp:10968`
- Subtle (✅): constants unchanged: 3..128 sides, radii 50/40, z −40/0, inner (1,0,0,0.5), outer (0,0,1,0.25), `BREAK_PATTERN_RING_SPEED`. `setInnerColor` with a nil colour leaves components uninitialised on both sides.

## OOECMBlastEntity

<a id="ooecmblastentity"></a>
Upstream `src/Core/Entities/OOECMBlastEntity.m` ↔ `Core/Entities/OOECMBlastEntity.cpp` (124 / 122 lines)

**Status:** done — 5 rows: 4 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOECMBlastEntity initFromShip:]` (45) | `OOECMBlastEntity::initFromShip` `Core/Entities/OOECMBlastEntity.cpp:60` + ctor `:49` | ✅ |
| `-[OOECMBlastEntity update:]` (63) | `OOECMBlastEntity::update` `Core/Entities/OOECMBlastEntity.cpp:69` | ✅ |
| `-[OOECMBlastEntity drawImmediate:translucent:]` (102) | `OOECMBlastEntity::drawImmediate` `Core/Entities/OOECMBlastEntity.cpp:115` | ✅ |
| `-[OOECMBlastEntity isECMBlast]` (110) | `OOECMBlastEntity::isECMBlast` `Core/Entities/OOECMBlastEntity.cpp:122` | ✅ |
| `-[Entity(OOECMBlastEntity) isECMBlast]` (119) | none (category removed; nothing upstream sent it to a non-blast) | ➖ |

**Differences:**

- ➖ **low** — the Entity category `-isECMBlast` was removed (still open) — upstream `Core/Entities/OOECMBlastEntity.m:119`
- Subtle (✅): `ECM_EFFECT_DURATION` 2.0, `ECM_PULSE_COUNT` 4, interval 0.5 s unchanged. Radius `clamp01((4−remaining+1)/4)×SCANNER_MAX_RANGE`, decrement before the event; per target `shipHitByECM(remaining, whom)`, then AI `ECM`, then `noticeECM`; removal on `remaining==0 \|\| !validShip`. A nil ship still yields no entity — upstream `Core/Entities/OOECMBlastEntity.m:45-100` ↔ port `Core/Entities/OOECMBlastEntity.cpp:49-113`

## OOEntityWithDrawable

<a id="ooentitywithdrawable"></a>
Upstream `src/Core/Entities/OOEntityWithDrawable.m` ↔ `Core/Entities/OOEntityWithDrawable.cpp` (122 / 124 lines)

**Status:** done — 6 rows: 5 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOEntityWithDrawable dealloc]` (33) | `drawable` member (comment `Core/Entities/OOEntityWithDrawable.cpp:31`) | ➖ |
| `-[OOEntityWithDrawable drawable]` (41) | `OOEntityWithDrawable::getDrawable` `Core/Entities/OOEntityWithDrawable.cpp:33` | ✅ |
| `-[OOEntityWithDrawable setDrawable:]` (46) | `OOEntityWithDrawable::setDrawable` `Core/Entities/OOEntityWithDrawable.cpp:35` | ✅ |
| `-[OOEntityWithDrawable findCollisionRadius]` (59) | `OOEntityWithDrawable::findCollisionRadius` `Core/Entities/OOEntityWithDrawable.cpp:55` | ✅ |
| `-[OOEntityWithDrawable drawImmediate:translucent:]` (64) | `OOEntityWithDrawable::drawImmediate` `Core/Entities/OOEntityWithDrawable.cpp:60` | ✅ |
| `-[OOEntityWithDrawable allTextures]` (116) | `OOEntityWithDrawable::allTextures` `Core/Entities/OOEntityWithDrawable.cpp:119` | ✅ |

**Differences:**

- ➖ **low** — `-dealloc` release is RAII; the replaced drawable is still deferred via `OODrawableAutorelease`, as `[drawable autorelease]` was (still open) — upstream `Core/Entities/OOEntityWithDrawable.m:33,49` ↔ port `Core/Entities/OOEntityWithDrawable.cpp:37`
- Subtle (✅): the frustum clip radius calls the virtual `frustumRadius()` only for ships and visual effects, as upstream's casts did; a nil drawable gives 0 radius/draw distance and a zero bounding box, as nil messaging — port `Core/Entities/OOEntityWithDrawable.cpp:42-51,69-75`

## OOExhaustPlumeEntity

<a id="ooexhaustplumeentity"></a>
Upstream `src/Core/Entities/OOExhaustPlumeEntity.m` ↔ `Core/Entities/OOExhaustPlumeEntity.cpp` (681 / 686 lines)

**Status:** done — 18 rows: 16 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOExhaustPlumeEntity exhaustForShip:withDefinition:andScale:]` (57) | `OOExhaustPlumeEntity::exhaustForShip` `Core/Entities/OOExhaustPlumeEntity.cpp:67` | ✅ |
| `-[OOExhaustPlumeEntity initForShip:withDefinition:andScale:]` (62) | `OOExhaustPlumeEntity::initForShip` `Core/Entities/OOExhaustPlumeEntity.cpp:76` | ✅ |
| `-[OOExhaustPlumeEntity scale]` (81) | `OOExhaustPlumeEntity::scale` `Core/Entities/OOExhaustPlumeEntity.cpp:103` | ✅ |
| `-[OOExhaustPlumeEntity setScale:]` (86) | `OOExhaustPlumeEntity::setScale` `Core/Entities/OOExhaustPlumeEntity.cpp:105` | ✅ |
| `-[OOExhaustPlumeEntity isExhaust]` (94) | `OOExhaustPlumeEntity::isExhaust` `Core/Entities/OOExhaustPlumeEntity.cpp:112` | ✅ |
| `-[OOExhaustPlumeEntity findCollisionRadius]` (99) | `OOExhaustPlumeEntity::findCollisionRadius` `Core/Entities/OOExhaustPlumeEntity.cpp:114` | ✅ |
| `-[OOExhaustPlumeEntity update:]` (104) | `OOExhaustPlumeEntity::update` `Core/Entities/OOExhaustPlumeEntity.cpp:116` | ✅ |
| `-[OOExhaustPlumeEntity drawSubEntityImmediate:translucent:]` (359) | `OOExhaustPlumeEntity::drawSubEntityImmediate` `Core/Entities/OOExhaustPlumeEntity.cpp:408` | ✅ |
| `-[OOExhaustPlumeEntity saveToLastFrame]` (542) | `OOExhaustPlumeEntity::saveToLastFrame` `Core/Entities/OOExhaustPlumeEntity.cpp:536` | ✅ |
| `-[OOExhaustPlumeEntity frameAtTime:fromFrame:]` (558) | `OOExhaustPlumeEntity::frameAtTime` `Core/Entities/OOExhaustPlumeEntity.cpp:556` | ✅ |
| `-[OOExhaustPlumeEntity resetPlume]` (610) | `OOExhaustPlumeEntity::resetPlume` `Core/Entities/OOExhaustPlumeEntity.cpp:616` | ✅ |
| `-[OOExhaustPlumeEntity rescaleBy:]` (631) | `OOExhaustPlumeEntity::rescaleBy(GLfloat)` `Core/Entities/OOExhaustPlumeEntity.cpp:641` | ✅ |
| `-[OOExhaustPlumeEntity rescaleBy:writeToCache:]` (636) | `OOExhaustPlumeEntity::rescaleBy(GLfloat,bool)` `Core/Entities/OOExhaustPlumeEntity.cpp:645` | ✅ |
| `-[OOExhaustPlumeEntity texture]` (642) | `OOExhaustPlumeEntity::texture` `Core/Entities/OOExhaustPlumeEntity.cpp:651` | ✅ |
| `+[OOExhaustPlumeEntity setUpTexture]` (647) | `OOExhaustPlumeEntity::setUpTexture` `Core/Entities/OOExhaustPlumeEntity.cpp:655` | ❌ |
| `+[OOExhaustPlumeEntity plumeTexture]` (659) | `OOExhaustPlumeEntity::plumeTexture` `Core/Entities/OOExhaustPlumeEntity.cpp:668` | ✅ |
| `+[OOExhaustPlumeEntity resetGraphicsState]` (666) | `OOExhaustPlumeEntity::resetGraphicsState` `Core/Entities/OOExhaustPlumeEntity.cpp:673` | ✅ |
| `-[Entity(OOExhaustPlume) isExhaust]` (676) | none (category removed) | ➖ |

**Differences:**

- ❌ **low** — `setUpTexture` registers a fresh `new PlumeTextureResetClient` every time the texture is re-created after a graphics reset (the comment says "registered once", the code does not). Upstream registered the class object, which is idempotent; the port leaks one client per reset and calls `resetGraphicsState` N times (still open) — upstream `Core/Entities/OOExhaustPlumeEntity.m:655` ↔ port `Core/Entities/OOExhaustPlumeEntity.cpp:663-664`
- ➖ **low** — the `Entity(OOExhaustPlume) -isExhaust` category was removed; the subclass keeps `isExhaust()` (still open) — upstream `Core/Entities/OOExhaustPlumeEntity.m:676`
- Subtle (✅): geometry and RNG order unchanged (one `ranrot_rand()%11`, then %50/%40/%25 compared as `int` since port `ranrot_rand()` casts to `int` (`legacy_random.h:68`), then 24 `randf()`); fade 0.4/0.2/0.02, scale 1.0/0.8/0.6 with 0.8/0.5, z-scale clamp [0.5,2.0]. A nil `exhaustEmissiveColor` leaves `ex_emissive` uninitialised on both sides — port `Core/Entities/OOExhaustPlumeEntity.cpp:142-179`

## OOExplosionCloudEntity

<a id="ooexplosioncloudentity"></a>
Upstream `src/Core/Entities/OOExplosionCloudEntity.m` ↔ `Core/Entities/OOExplosionCloudEntity.cpp` (252 / 261 lines)

**Status:** done — 6 rows: 5 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOExplosionCloudEntity initExplosionCloudWithEntity:size:andSettings:]` (57) | `OOExplosionCloudEntity::initExplosionCloudWithEntity` `Core/Entities/OOExplosionCloudEntity.cpp:54` | ✅ |
| `-[OOExplosionCloudEntity dealloc]` (160) | members (comment `Core/Entities/OOExplosionCloudEntity.cpp:170`) | ➖ |
| `+[OOExplosionCloudEntity explosionCloudFromEntity:withSettings:]` (167) | `OOExplosionCloudEntity::explosionCloudFromEntity(Entity*, const PList&)` `Core/Entities/OOExplosionCloudEntity.cpp:173` | ✅ |
| `+[OOExplosionCloudEntity explosionCloudFromEntity:withSize:andSettings:]` (172) | `OOExplosionCloudEntity::explosionCloudFromEntity(Entity*, float, const PList&)` `Core/Entities/OOExplosionCloudEntity.cpp:183` | ✅ |
| `-[OOExplosionCloudEntity update:]` (177) | `OOExplosionCloudEntity::update` `Core/Entities/OOExplosionCloudEntity.cpp:192` | ✅ |
| `-[OOExplosionCloudEntity texture]` (247) | `OOExplosionCloudEntity::texture` `Core/Entities/OOExplosionCloudEntity.cpp:261` | ✅ |

**Differences:**

- ➖ **low** — `-dealloc` releases are now members (still open) — upstream `Core/Entities/OOExplosionCloudEntity.m:160` ↔ port `Core/Entities/OOExplosionCloudEntity.cpp:170`
- Subtle (✅): keys and defaults identical (count 25 capped at 10 when detail ≤ shaders else 25, size 2.5, growth_rate 1.5, alpha 0.85, brightness ≥1, duration 0.9, spread 1, texture `oolite-particle-cloud2.png`, color_order `rgb`); velocity clamp to 1000 above 10⁶; 3 (or 1 for `white`) `randf()` per particle after the base init; a missing texture still yields no entity. A nil entity reads zero position/velocity/radius as nil did — port `Core/Entities/OOExplosionCloudEntity.cpp:54-168`

## OOFlashEffectEntity

<a id="ooflasheffectentity"></a>
Upstream `src/Core/Entities/OOFlashEffectEntity.m` ↔ `Core/Entities/OOFlashEffectEntity.cpp` (140 / 161 lines)

**Status:** done — 9 rows: 8 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOFlashEffectEntity initExplosionFlashWithPosition:velocity:size:]` (55) | `OOFlashEffectEntity::initExplosionFlashWithPosition` `Core/Entities/OOFlashEffectEntity.cpp:63` | ✅ |
| `-[OOFlashEffectEntity initLaserFlashWithPosition:velocity:color:]` (65) | `OOFlashEffectEntity::initLaserFlashWithPosition` `Core/Entities/OOFlashEffectEntity.cpp:76` | ✅ |
| `+[OOFlashEffectEntity explosionFlashFromEntity:]` (74) | `OOFlashEffectEntity::explosionFlashFromEntity` `Core/Entities/OOFlashEffectEntity.cpp:90` | ✅ |
| `+[OOFlashEffectEntity laserFlashWithPosition:velocity:color:]` (79) | `OOFlashEffectEntity::laserFlashWithPosition` `Core/Entities/OOFlashEffectEntity.cpp:101` | ✅ |
| `-[OOFlashEffectEntity initWithPosition:size:color:duration:]` (84) | `OOFlashEffectEntity::initWithPosition` `Core/Entities/OOFlashEffectEntity.cpp:109` | ✅ |
| `-[OOFlashEffectEntity update:]` (96) | `OOFlashEffectEntity::update` `Core/Entities/OOFlashEffectEntity.cpp:123` | ✅ |
| `-[OOFlashEffectEntity texture]` (115) | `OOFlashEffectEntity::texture` `Core/Entities/OOFlashEffectEntity.cpp:144` | ✅ |
| `+[OOFlashEffectEntity setUpTexture]` (122) | `OOFlashEffectEntity::setUpTexture` `Core/Entities/OOFlashEffectEntity.cpp:149` | ❌ |
| `+[OOFlashEffectEntity resetGraphicsState]` (134) | `OOFlashEffectEntity::resetGraphicsState` `Core/Entities/OOFlashEffectEntity.cpp:161` | ✅ |

**Differences:**

- ❌ **low** — each texture re-creation after a graphics reset registers a new `FlashTextureResetClient`; upstream's class registration was idempotent. Clients accumulate and leak (still open) — upstream `Core/Entities/OOFlashEffectEntity.m:130` ↔ port `Core/Entities/OOFlashEffectEntity.cpp:156-157`
- Subtle (✅): laser flash 0.3 s, size 1, alpha 1; explosion flash 0.4 s, alpha 0.5, growth `max(150×size, 600)`; fade in over 0.667×duration, out over the rest; removal when `lifeTime > duration`.

## OOFlasherEntity

<a id="ooflasherentity"></a>
Upstream `src/Core/Entities/OOFlasherEntity.m` ↔ `Core/Entities/OOFlasherEntity.cpp` (217 / 177 lines)

**Status:** done — 22 rows: 19 ✅ 1 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOFlasherEntity flasherWithDictionary:]` (42) | `OOFlasherEntity::flasherWithDictionary` `Core/Entities/OOFlasherEntity.cpp:31` | ✅ |
| `-[OOFlasherEntity initWithDictionary:]` (47) | `OOFlasherEntity::initWithDictionary` `Core/Entities/OOFlasherEntity.cpp:39` | ✅ |
| `-[OOFlasherEntity dealloc]` (64) | `std::vector<std::shared_ptr<OOColor>> _colors` member | ➖ |
| `-[OOFlasherEntity setUpColors:]` (71) | `OOFlasherEntity::setUpColors` `Core/Entities/OOFlasherEntity.cpp:56` | ✅ |
| `-[OOFlasherEntity getCurrentColorComponents]` (82) | `OOFlasherEntity::getCurrentColorComponents` `Core/Entities/OOFlasherEntity.cpp:73` (+ `flasherColorAtIndex` `:69`) | ⚠️ |
| `-[OOFlasherEntity isActive]` (87) | `OOFlasherEntity::isActive` `Core/Entities/OOFlasherEntity.cpp:77` | ✅ |
| `-[OOFlasherEntity setActive:]` (92) | `OOFlasherEntity::setActive` `Core/Entities/OOFlasherEntity.cpp:79` | ✅ |
| `-[OOFlasherEntity color]` (97) | `OOFlasherEntity::color` `Core/Entities/OOFlasherEntity.cpp:81` | ✅ |
| `-[OOFlasherEntity frequency]` (105) | `OOFlasherEntity::frequency` `Core/Entities/OOFlasherEntity.cpp:86` | ✅ |
| `-[OOFlasherEntity setFrequency:]` (110) | `OOFlasherEntity::setFrequency` `Core/Entities/OOFlasherEntity.cpp:88` | ✅ |
| `-[OOFlasherEntity phase]` (115) | `OOFlasherEntity::phase` `Core/Entities/OOFlasherEntity.cpp:90` | ✅ |
| `-[OOFlasherEntity setPhase:]` (120) | `OOFlasherEntity::setPhase` `Core/Entities/OOFlasherEntity.cpp:92` | ✅ |
| `-[OOFlasherEntity fraction]` (125) | `OOFlasherEntity::fraction` `Core/Entities/OOFlasherEntity.cpp:94` | ✅ |
| `-[OOFlasherEntity setFraction:]` (130) | `OOFlasherEntity::setFraction` `Core/Entities/OOFlasherEntity.cpp:96` | ✅ |
| `-[OOFlasherEntity update:]` (135) | `OOFlasherEntity::update` `Core/Entities/OOFlasherEntity.cpp:100` | ✅ |
| `-[OOFlasherEntity drawImmediate:translucent:]` (173) | `OOFlasherEntity::drawImmediate` `Core/Entities/OOFlasherEntity.cpp:143` | ✅ |
| `-[OOFlasherEntity drawSubEntityImmediate:translucent:]` (180) | `OOFlasherEntity::drawSubEntityImmediate` `Core/Entities/OOFlasherEntity.cpp:149` | ✅ |
| `-[OOFlasherEntity isFlasher]` (187) | `OOFlasherEntity::isFlasher` `Core/Entities/OOFlasherEntity.cpp:155` | ✅ |
| `-[OOFlasherEntity findCollisionRadius]` (192) | `OOFlasherEntity::findCollisionRadius` `Core/Entities/OOFlasherEntity.cpp:157` | ✅ |
| `-[OOFlasherEntity rescaleBy:]` (197) | `OOFlasherEntity::rescaleBy(GLfloat)` `Core/Entities/OOFlasherEntity.cpp:159` | ✅ |
| `-[OOFlasherEntity rescaleBy:writeToCache:]` (202) | `OOFlasherEntity::rescaleBy(GLfloat,bool)` `Core/Entities/OOFlasherEntity.cpp:163` | ✅ |
| `-[Entity(OOFlasherEntityExtensions) isFlasher]` (212) | none (category removed) | ➖ |

**Differences:**

- ⚠️ **low** — with an empty colour list upstream `[_colors objectAtIndex:0]` raised `NSRangeException`; the port's `flasherColorAtIndex` (commented "null past the end (-objectAtIndex: raised there)") returns null and `setColor(nullptr)` leaves the colour white. Unreachable from shipdata since the registry guarantees one valid colour (still open) — upstream `Core/Entities/OOFlasherEntity.m:84` ↔ port `Core/Entities/OOFlasherEntity.cpp:68-75`
- Subtle (✅, low): `setUpColors` stores a null entry for a specifier `colorWithDescription` rejects, where upstream `addObject:nil` raised; the registry pre-validates specifiers — upstream `Core/Entities/OOFlasherEntity.m:76` ↔ port `Core/Entities/OOFlasherEntity.cpp:61`
- ➖ **low** — `-dealloc` is RAII and the `Entity -isFlasher` category was removed (still open) — upstream `Core/Entities/OOFlasherEntity.m:64,212`
- Subtle (✅): `_frequency = frequency×2`, `wave = sinf(f·π·(t+phase))`, colour switch on a rising negative half-wave, threshold `cosf(bf·π)` and the brightness formula unchanged; defaults size 1, frequency 1, phase 0, bright_fraction 0.5, initially_on YES, saturation 0.75.

## OOLaserShotEntity

<a id="oolasershotentity"></a>
Upstream `src/Core/Entities/OOLaserShotEntity.m` ↔ `Core/Entities/OOLaserShotEntity.cpp` (315 / 324 lines)

**Status:** done — 16 rows: 14 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOLaserShotEntity initLaserFromShip:direction:offset:]` (58) | `OOLaserShotEntity::initLaserFromShip` `Core/Entities/OOLaserShotEntity.cpp:83` | ✅ |
| `+[OOLaserShotEntity laserFromShip:direction:offset:]` (117) | `OOLaserShotEntity::laserFromShip` `Core/Entities/OOLaserShotEntity.cpp:153` | ✅ |
| `-[OOLaserShotEntity dealloc]` (122) | removed (comment `Core/Entities/OOLaserShotEntity.cpp:161`) | ➖ |
| `-[OOLaserShotEntity descriptionComponents]` (129) | `OOLaserShotEntity::descriptionComponents` `Core/Entities/OOLaserShotEntity.cpp:164` | ✅ |
| `-[OOLaserShotEntity setColor:]` (134) | `OOLaserShotEntity::setColor` `Core/Entities/OOLaserShotEntity.cpp:171` | ✅ |
| `-[OOLaserShotEntity setRange:]` (142) | `OOLaserShotEntity::setRange` `Core/Entities/OOLaserShotEntity.cpp:182` | ✅ |
| `-[OOLaserShotEntity update:]` (148) | `OOLaserShotEntity::update` `Core/Entities/OOLaserShotEntity.cpp:187` | ✅ |
| `-[OOLaserShotEntity drawImmediate:translucent:]` (197) | `OOLaserShotEntity::drawImmediate` `Core/Entities/OOLaserShotEntity.cpp:219` | ✅ |
| `-[OOLaserShotEntity isEffect]` (255) | `OOLaserShotEntity::isEffect` `Core/Entities/OOLaserShotEntity.cpp:281` | ✅ |
| `-[OOLaserShotEntity canCollide]` (260) | `OOLaserShotEntity::canCollide` `Core/Entities/OOLaserShotEntity.cpp:283` | ✅ |
| `-[OOLaserShotEntity texture1]` (265) | `OOLaserShotEntity::texture1` `Core/Entities/OOLaserShotEntity.cpp:285` | ✅ |
| `-[OOLaserShotEntity texture2]` (270) | `OOLaserShotEntity::texture2` `Core/Entities/OOLaserShotEntity.cpp:289` | ✅ |
| `+[OOLaserShotEntity setUpTexture]` (275) | `OOLaserShotEntity::setUpTexture` `Core/Entities/OOLaserShotEntity.cpp:293` | ❌ |
| `+[OOLaserShotEntity innerTexture]` (293) | `OOLaserShotEntity::innerTexture` `Core/Entities/OOLaserShotEntity.cpp:311` | ✅ |
| `+[OOLaserShotEntity outerTexture]` (300) | `OOLaserShotEntity::outerTexture` `Core/Entities/OOLaserShotEntity.cpp:316` | ✅ |
| `+[OOLaserShotEntity resetGraphicsState]` (307) | `OOLaserShotEntity::resetGraphicsState` `Core/Entities/OOLaserShotEntity.cpp:321` | ✅ |

**Differences:**

- ❌ **low** — `setUpTexture` registers a new `ShotTextureResetClient` on every re-creation after a reset, where upstream's class registration was idempotent; clients leak and reset calls multiply (still open) — upstream `Core/Entities/OOLaserShotEntity.m:283` ↔ port `Core/Entities/OOLaserShotEntity.cpp:300-301`
- ➖ **low** — `-dealloc`'s `[self setColor:nil]` was dropped; unobservable (still open) — upstream `Core/Entities/OOLaserShotEntity.m:124` ↔ port `Core/Entities/OOLaserShotEntity.cpp:161`
- Subtle (✅): `_range = collision_radius = [srcEntity weaponRange]`, `kLaserDuration` 0.09 s, removal when `_lifetime < 0`, player shots re-anchored each tick; colour `5×rgb/3`, alpha `0.45/5`, widths 0.4/1.8/3.6, texture phases `/200` and `/500`, facing rotations (aft π, port π/2, starboard −π/2) unchanged. `descriptionComponents` keeps `%.3f` as `{:.3f}`.

## OOLightParticleEntity

<a id="oolightparticleentity"></a>
Upstream `src/Core/Entities/OOLightParticleEntity.m` ↔ `Core/Entities/OOLightParticleEntity.cpp` (329 / 341 lines)

**Status:** done — 14 rows: 13 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOLightParticleEntity initWithDiameter:]` (50) | `OOLightParticleEntity::initWithDiameter` `Core/Entities/OOLightParticleEntity.cpp:60` | ✅ |
| `-[OOLightParticleEntity diameter]` (69) | `OOLightParticleEntity::diameter` `Core/Entities/OOLightParticleEntity.cpp:81` | ✅ |
| `-[OOLightParticleEntity setDiameter:]` (74) | `OOLightParticleEntity::setDiameter` `Core/Entities/OOLightParticleEntity.cpp:83` | ✅ |
| `-[OOLightParticleEntity setColor:]` (79) | `OOLightParticleEntity::setColor(OOColor*)` `Core/Entities/OOLightParticleEntity.cpp:87` | ✅ |
| `-[OOLightParticleEntity setColor:alpha:]` (84) | `OOLightParticleEntity::setColor(OOColor*, GLfloat)` `Core/Entities/OOLightParticleEntity.cpp:94` | ✅ |
| `-[OOLightParticleEntity drawSubEntityImmediate:translucent:]` (90) | `OOLightParticleEntity::drawSubEntityImmediate` `Core/Entities/OOLightParticleEntity.cpp:99` | ✅ |
| `-[OOLightParticleEntity drawImmediate:translucent:]` (129) | `OOLightParticleEntity::drawImmediate` `Core/Entities/OOLightParticleEntity.cpp:145` | ✅ |
| `-[OOLightParticleEntity texture]` (282) | `OOLightParticleEntity::texture` `Core/Entities/OOLightParticleEntity.cpp:308` | ✅ |
| `+[OOLightParticleEntity setUpTexture]` (287) | `OOLightParticleEntity::setUpTexture` `Core/Entities/OOLightParticleEntity.cpp:312` | ❌ |
| `+[OOLightParticleEntity defaultParticleTexture]` (299) | `OOLightParticleEntity::defaultParticleTexture` `Core/Entities/OOLightParticleEntity.cpp:324` | ✅ |
| `+[OOLightParticleEntity resetGraphicsState]` (306) | `OOLightParticleEntity::resetGraphicsState` `Core/Entities/OOLightParticleEntity.cpp:329` | ✅ |
| `-[OOLightParticleEntity isEffect]` (312) | `OOLightParticleEntity::isEffect` `Core/Entities/OOLightParticleEntity.cpp:331` | ✅ |
| `-[OOLightParticleEntity canCollide]` (317) | `OOLightParticleEntity::canCollide` `Core/Entities/OOLightParticleEntity.cpp:333` | ✅ |
| `-[OOLightParticleEntity allTextures]` (323) | `OOLightParticleEntity::allTextures` `Core/Entities/OOLightParticleEntity.cpp:336` | ✅ |

**Differences:**

- ❌ **low** — `setUpTexture` adds a new `BlobTextureResetClient` each time the blob texture is re-created after a reset; upstream's class registration was idempotent. Leak plus redundant reset calls (still open) — upstream `Core/Entities/OOLightParticleEntity.m:295` ↔ port `Core/Entities/OOLightParticleEntity.cpp:319-320`
- Subtle (✅): the owner walks drop the `!= NO_TARGET` test (NO_TARGET is 0, i.e. null); an ownerless entity under break-pattern hide still returns, as `[nil isImmuneToBreakPatternHide]` was NO. `no_draw_distance = (d/2)^√2 × NDDF² × (12 reduced / 36)` unchanged; `setColor(nil)` leaves components as they were — port `Core/Entities/OOLightParticleEntity.cpp:64-69,87-92,107-127,148-162`

## OOParticleSystem

<a id="ooparticlesystem"></a>
Upstream `src/Core/Entities/OOParticleSystem.m` ↔ `Core/Entities/OOParticleSystem.cpp` (353 / 367 lines)

**Status:** done — 16 rows: 14 ✅ 1 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOParticleSystem init]` (39) | protected default ctor `Core/Entities/OOParticleSystem.h:59` | ➖ |
| `-[OOParticleSystem initWithPosition:velocity:count:minSpeed:maxSpeed:duration:baseColor:]` (48) | `OOParticleSystem::initWithPosition` `Core/Entities/OOParticleSystem.cpp:46` | ⚠️ |
| `-[OOParticleSystem descriptionComponents]` (87) | `OOParticleSystem::descriptionComponents` `Core/Entities/OOParticleSystem.cpp:89` | ✅ |
| `-[OOParticleSystem canCollide]` (92) | `OOParticleSystem::canCollide` `Core/Entities/OOParticleSystem.cpp:93` | ✅ |
| `-[OOParticleSystem checkCloseCollisionWith:]` (97) | `OOParticleSystem::checkCloseCollisionWith` `Core/Entities/OOParticleSystem.cpp:95` | ✅ |
| `-[OOParticleSystem update:]` (104) | `OOParticleSystem::update` `Core/Entities/OOParticleSystem.cpp:101` | ✅ |
| `-[OOParticleSystem drawImmediate:translucent:]` (136) | `OOParticleSystem::drawImmediate` `Core/Entities/OOParticleSystem.cpp:135` | ✅ |
| `-[OOParticleSystem isEffect]` (225) | `OOParticleSystem::isEffect` `Core/Entities/OOParticleSystem.cpp:236` | ✅ |
| `-[OOParticleSystem texture]` (230) | `OOParticleSystem::texture` `Core/Entities/OOParticleSystem.cpp:238` | ✅ |
| `-[OOParticleSystem allTextures]` (236) | `OOParticleSystem::allTextures` `Core/Entities/OOParticleSystem.cpp:243` | ✅ |
| `-[OOSmallFragmentBurstEntity initFragmentBurstFrom:velocity:size:]` (246) | `OOSmallFragmentBurstEntity::initFragmentBurstFrom` `Core/Entities/OOParticleSystem.cpp:251` | ✅ |
| `+[OOSmallFragmentBurstEntity fragmentBurstFromEntity:]` (272) | `OOSmallFragmentBurstEntity::fragmentBurstFromEntity` `Core/Entities/OOParticleSystem.cpp:280` | ✅ |
| `-[OOSmallFragmentBurstEntity update:]` (277) | `OOSmallFragmentBurstEntity::update` `Core/Entities/OOParticleSystem.cpp:292` | ✅ |
| `-[OOBigFragmentBurstEntity initFragmentBurstFrom:velocity:size:]` (300) | `OOBigFragmentBurstEntity::initFragmentBurstFrom` `Core/Entities/OOParticleSystem.cpp:309` | ✅ |
| `+[OOBigFragmentBurstEntity fragmentBurstFromEntity:]` (322) | `OOBigFragmentBurstEntity::fragmentBurstFromEntity` `Core/Entities/OOParticleSystem.cpp:333` | ✅ |
| `-[OOBigFragmentBurstEntity update:]` (327) | `OOBigFragmentBurstEntity::update` `Core/Entities/OOParticleSystem.cpp:345` | ✅ |

**Differences:**

- ⚠️ **low** — the three `randf()` calls inside `make_vector(...)` for each particle colour are sequenced into locals in Clang's left-to-right order (port comment; ADR-0063 item 5 per the previous audit). Identical under Clang, which the goldens use; a GCC-built upstream would draw right to left (still open) — upstream `Core/Entities/OOParticleSystem.m:70` ↔ port `Core/Entities/OOParticleSystem.cpp:69-74`
- ➖ **low** — `-init` (which released self and returned nil) is now a protected default constructor, so only subclasses construct (still open) — upstream `Core/Entities/OOParticleSystem.m:39` ↔ port `Core/Entities/OOParticleSystem.h:59`
- Subtle (✅): small burst `(unsigned)(0.4·size) \| 12` capped at 64, speeds 100–400, 1.5 s, one hue `randf()` before the base init's draws, size `3200/speed`; big burst `(0.2·size) \| 3` capped at 16, speeds `1+size/2` to ×4, 1.0 s, base colour (1,1,0.5,1), velocity ×0.85. Per-particle RNG order `randf, randf, OORandomUnitVector, 3×randf`. A null `other` in `checkCloseCollisionWith` answers true, as `![nil isEffect]`.

## OOPlanetEntity

<a id="ooplanetentity"></a>
Upstream `src/Core/Entities/OOPlanetEntity.m` ↔ `Core/Entities/OOPlanetEntity.cpp` (1052 / 1274 lines)

**Status:** done — 51 rows: 49 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPlanetEntity initAsMainPlanetForSystem:]` (70) | `OOPlanetEntity::initAsMainPlanetForSystem` `Core/Entities/OOPlanetEntity.cpp:166` | ✅ |
| `-[OOPlanetEntity initFromDictionary:withAtmosphere:andSeed:forSystem:]` (84) | `OOPlanetEntity::initFromDictionary` `Core/Entities/OOPlanetEntity.cpp:187` | ⚠️ |
| `RandomHSBColor` (248) | `RandomHSBColor` `Core/Entities/OOPlanetEntity.cpp:411` | ✅ |
| `LighterHSBColor` (257) | `LighterHSBColor` `Core/Entities/OOPlanetEntity.cpp:417` | ✅ |
| `HSBColorWithColor` (266) | `HSBColorWithColor` `Core/Entities/OOPlanetEntity.cpp:423` | ✅ |
| `ColorWithHSBColor` (272) | `ColorWithHSBColor` `Core/Entities/OOPlanetEntity.cpp:429` (answers an Object node) | ✅ |
| `-[OOPlanetEntity setUpTypeParametersWithSourceInfo:targetInfo:]` (277) | `OOPlanetEntity::setUpTypeParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:435` | ✅ |
| `-[OOPlanetEntity setUpTerrainParametersWithSourceInfo:targetInfo:]` (283) | `OOPlanetEntity::setUpTerrainParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:443` | ✅ |
| `-[OOPlanetEntity setUpLandParametersWithSourceInfo:targetInfo:]` (295) | `OOPlanetEntity::setUpLandParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:457` | ✅ |
| `-[OOPlanetEntity setUpAtmosphereParametersWithSourceInfo:targetInfo:]` (300) | `OOPlanetEntity::setUpAtmosphereParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:462` | ✅ |
| `-[OOPlanetEntity setUpColorParametersWithSourceInfo:targetInfo:isAtmosphere:]` (305) | `OOPlanetEntity::setUpColorParametersWithSourceInfo` `Core/Entities/OOPlanetEntity.cpp:467` | ✅ |
| `-[OOPlanetEntity initAsMiniatureVersionOfPlanet:]` (411) | `OOPlanetEntity::initAsMiniatureVersionOfPlanet` `Core/Entities/OOPlanetEntity.cpp:590` | ✅ |
| `-[OOPlanetEntity dealloc]` (459) | `OOPlanetEntity::~OOPlanetEntity` `Core/Entities/OOPlanetEntity.cpp:647` (unregister; members release) | ✅ |
| `-[OOPlanetEntity descriptionComponents]` (477) | `OOPlanetEntity::descriptionComponents` `Core/Entities/OOPlanetEntity.cpp:652` | ✅ |
| `-[OOPlanetEntity setOrientation:]` (482) | `OOPlanetEntity::setOrientation` `Core/Entities/OOPlanetEntity.cpp:658` | ✅ |
| `-[OOPlanetEntity radius]` (488) | `OOPlanetEntity::radius` `Core/Entities/OOPlanetEntity.cpp:663` | ✅ |
| `-[OOPlanetEntity planetType]` (493) | `OOPlanetEntity::planetType` `Core/Entities/OOPlanetEntity.cpp:665` | ✅ |
| `-[OOPlanetEntity miniatureVersion]` (502) | `OOPlanetEntity::miniatureVersion` `Core/Entities/OOPlanetEntity.cpp:671` | ✅ |
| `-[OOPlanetEntity update:]` (507) | `OOPlanetEntity::update` `Core/Entities/OOPlanetEntity.cpp:679` | ✅ |
| `-[OOPlanetEntity isFinishedLoading]` (605) | `OOPlanetEntity::isFinishedLoading` `Core/Entities/OOPlanetEntity.cpp:807` | ✅ |
| `-[OOPlanetEntity drawImmediate:translucent:]` (619) | `OOPlanetEntity::drawImmediate` `Core/Entities/OOPlanetEntity.cpp:819` | ✅ |
| `-[OOPlanetEntity checkCloseCollisionWith:]` (700) | `OOPlanetEntity::checkCloseCollisionWith` `Core/Entities/OOPlanetEntity.cpp:908` | ✅ |
| `-[OOPlanetEntity planetHasStation]` (714) | `OOPlanetEntity::planetHasStation` `Core/Entities/OOPlanetEntity.cpp:921` | ✅ |
| `-[OOPlanetEntity launchShuttle]` (729) | `OOPlanetEntity::launchShuttle` `Core/Entities/OOPlanetEntity.cpp:939` | ✅ |
| `-[OOPlanetEntity welcomeShuttle:]` (769) | `OOPlanetEntity::welcomeShuttle` `Core/Entities/OOPlanetEntity.cpp:994` | ✅ |
| `-[OOPlanetEntity isPlanet]` (774) | `OOPlanetEntity::isPlanet` `Core/Entities/OOPlanetEntity.cpp:998` | ✅ |
| `-[OOPlanetEntity isVisible]` (779) | `OOPlanetEntity::isVisible` `Core/Entities/OOPlanetEntity.cpp:1000` | ✅ |
| `-[OOPlanetEntity rotationalVelocity]` (784) | `OOPlanetEntity::rotationalVelocity` `Core/Entities/OOPlanetEntity.cpp:1002` | ✅ |
| `-[OOPlanetEntity setRotationalVelocity:]` (789) | `OOPlanetEntity::setRotationalVelocity` `Core/Entities/OOPlanetEntity.cpp:1004` | ✅ |
| `-[OOPlanetEntity airColorAsVector]` (798) | `OOPlanetEntity::airColorAsVector` `Core/Entities/OOPlanetEntity.cpp:1012` | ✅ |
| `-[OOPlanetEntity airColor]` (805) | `OOPlanetEntity::airColor` `Core/Entities/OOPlanetEntity.cpp:1018` | ✅ |
| `-[OOPlanetEntity setAirColor:]` (810) | `OOPlanetEntity::setAirColor` `Core/Entities/OOPlanetEntity.cpp:1020` | ✅ |
| `-[OOPlanetEntity illuminationColorAsVector]` (819) | `OOPlanetEntity::illuminationColorAsVector` `Core/Entities/OOPlanetEntity.cpp:1027` | ✅ |
| `-[OOPlanetEntity illuminationColor]` (826) | `OOPlanetEntity::illuminationColor` `Core/Entities/OOPlanetEntity.cpp:1033` | ✅ |
| `-[OOPlanetEntity setIlluminationColor:]` (831) | `OOPlanetEntity::setIlluminationColor` `Core/Entities/OOPlanetEntity.cpp:1037` | ✅ |
| `-[OOPlanetEntity airColorMixRatio]` (840) | `OOPlanetEntity::airColorMixRatio` `Core/Entities/OOPlanetEntity.cpp:1044` | ✅ |
| `-[OOPlanetEntity setAirColorMixRatio:]` (845) | `OOPlanetEntity::setAirColorMixRatio` `Core/Entities/OOPlanetEntity.cpp:1046` | ✅ |
| `-[OOPlanetEntity airDensity]` (851) | `OOPlanetEntity::airDensity` `Core/Entities/OOPlanetEntity.cpp:1051` | ✅ |
| `-[OOPlanetEntity setAirDensity:]` (856) | `OOPlanetEntity::setAirDensity` `Core/Entities/OOPlanetEntity.cpp:1053` | ✅ |
| `-[OOPlanetEntity setTerminatorThresholdVector:]` (861) | `OOPlanetEntity::setTerminatorThresholdVector` `Core/Entities/OOPlanetEntity.cpp:1057` | ✅ |
| `-[OOPlanetEntity terminatorThresholdVector]` (868) | `OOPlanetEntity::terminatorThresholdVector` `Core/Entities/OOPlanetEntity.cpp:1064` | ✅ |
| `-[OOPlanetEntity hasAtmosphere]` (873) | `OOPlanetEntity::hasAtmosphere` `Core/Entities/OOPlanetEntity.cpp:1068` | ✅ |
| `-[OOPlanetEntity textureFileName]` (879) | `OOPlanetEntity::textureFileName` `Core/Entities/OOPlanetEntity.cpp:1071` | ✅ |
| `-[OOPlanetEntity resetGraphicsState]` (884) | `OOPlanetEntity::resetGraphicsState` `Core/Entities/OOPlanetEntity.cpp:1075` | ✅ |
| `-[OOPlanetEntity setTextureFileName:]` (890) | `OOPlanetEntity::setTextureFileName` `Core/Entities/OOPlanetEntity.cpp:1080` | ⚠️ |
| `-[OOPlanetEntity setUpPlanetFromTexture:]` (1016) | `OOPlanetEntity::setUpPlanetFromTexture` `Core/Entities/OOPlanetEntity.cpp:1242` | ✅ |
| `-[OOPlanetEntity material]` (1022) | `OOPlanetEntity::material` `Core/Entities/OOPlanetEntity.cpp:1248` | ✅ |
| `-[OOPlanetEntity atmosphereMaterial]` (1027) | `OOPlanetEntity::atmosphereMaterial` `Core/Entities/OOPlanetEntity.cpp:1250` | ✅ |
| `-[OOPlanetEntity atmosphereShaderMaterial]` (1032) | `OOPlanetEntity::atmosphereShaderMaterial` `Core/Entities/OOPlanetEntity.cpp:1254` | ✅ |
| `-[OOPlanetEntity name]` (1039) | `OOPlanetEntity::name` `Core/Entities/OOPlanetEntity.cpp:1259` | ✅ |
| `-[OOPlanetEntity setName:]` (1044) | `OOPlanetEntity::setName` `Core/Entities/OOPlanetEntity.cpp:1261` | ✅ |

**Differences:**

- ⚠️ **low** — the RANROT noise seed is no longer boxed as `NSValue` under `"noise_map_seed"` in planetInfo/`_materialParameters`; it is kept in `_noiseMapSeed` (header comment `OOPlanetEntity.h:188`) and passed to `OOPlanetTextureGenerator`/`OOStandaloneAtmosphereGenerator`. It is captured at the same point (before `setUpLandParameters…`), so generated textures are unchanged; only the key is missing from `_materialParameters` (still open) — upstream `Core/Entities/OOPlanetEntity.m:143-144,174,185,938-954` ↔ port `Core/Entities/OOPlanetEntity.cpp:268,312-334,1145-1169`
- Subtle (✅): system-dictionary defaults match: radius `radius_km*10`, shuttles `1+min(tl,14)/2` over 3600 s with first launch at +30 s, `percent_land` `24+rnd%48`, `percent_ice` 5, `percent_cloud` `100-(3+(r&31)+(r&31))`, mix 0.5/density 0.75 without atmosphere, terminator default (0.105,0.18,0.28) written with `{:f}` = `%f`, rotation from `rotational_velocity` or `rotation_speed*rotation_speed_factor`, atmosphere rotation `0.01*randf()`. RNG draw order unchanged; `_materialParameters` uses an OONull node for missing keys as `-dictionaryWithValuesForKeys:` did — port `Core/Entities/OOPlanetEntity.cpp:121-132,187-409`
- Subtle (✅): `_oo_texture_objects` stops at the first null texture, as `+arrayWithObjects:` did; a missing config stays null like `[nil mutableCopy]`. `airColorAsVector`/`illuminationColorAsVector` with no colour return zero where upstream read uninitialised locals — port `Core/Entities/OOPlanetEntity.cpp:148-161,1012-1031`

## OOPlasmaBurstEntity

<a id="ooplasmaburstentity"></a>
Upstream `src/Core/Entities/OOPlasmaBurstEntity.m` ↔ `Core/Entities/OOPlasmaBurstEntity.cpp` (62 / 66 lines)

**Status:** done — 2 rows: 2 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPlasmaBurstEntity initWithPosition:]` (35) | `OOPlasmaBurstEntity::initWithPosition` `Core/Entities/OOPlasmaBurstEntity.cpp:42` (+ `burstWithPosition` `:34`) | ✅ |
| `-[OOPlasmaBurstEntity update:]` (47) | `OOPlasmaBurstEntity::update` `Core/Entities/OOPlasmaBurstEntity.cpp:53` | ✅ |

**Differences:**

- None. Initial size 64, growth 64/s, duration 2 s, red colour, collision radius 2 and linear alpha attenuation are unchanged.

## OOPlasmaShotEntity

<a id="ooplasmashotentity"></a>
Upstream `src/Core/Entities/OOPlasmaShotEntity.m` ↔ `Core/Entities/OOPlasmaShotEntity.cpp` (113 / 125 lines)

**Status:** done — 4 rows: 4 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPlasmaShotEntity initWithPosition:velocity:energy:duration:color:]` (43) | `OOPlasmaShotEntity::initWithPosition` `Core/Entities/OOPlasmaShotEntity.cpp:52` (+ `shotWithPosition` `:43`) | ✅ |
| `-[OOPlasmaShotEntity canCollide]` (64) | `OOPlasmaShotEntity::canCollide` `Core/Entities/OOPlasmaShotEntity.cpp:71` | ✅ |
| `-[OOPlasmaShotEntity checkCloseCollisionWith:]` (69) | `OOPlasmaShotEntity::checkCloseCollisionWith` `Core/Entities/OOPlasmaShotEntity.cpp:77` | ✅ |
| `-[OOPlasmaShotEntity update:]` (74) | `OOPlasmaShotEntity::update` `Core/Entities/OOPlasmaShotEntity.cpp:83` | ✅ |

**Differences:**

- Subtle (✅): `update` iterates a snapshot of `collidingEntities`; upstream iterated the live array by index with the count taken up front, so results match unless the array shrank mid-loop (upstream would have raised). Each non-owner hit takes `energy × 1.0` with `EQ_WEAPON_PLASMA_SHOT`, removes the shot and spawns one burst. The owner comparison uses `ownerEntity()` (raw weak lock) where `-owner` was compared — identical except for an owner mid-dispose — upstream `Core/Entities/OOPlasmaShotEntity.m:86-100` ↔ port `Core/Entities/OOPlasmaShotEntity.cpp:94-115`
- Activation delay 0.05 s, size 12 and collision radius 2 are unchanged.

## OOQuiriumCascadeEntity

<a id="ooquiriumcascadeentity"></a>
Upstream `src/Core/Entities/OOQuiriumCascadeEntity.m` ↔ `Core/Entities/OOQuiriumCascadeEntity.cpp` (165 / 161 lines)

**Status:** done — 10 rows: 9 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOQuiriumCascadeEntity initQuiriumCascadeFromShip:]` (36) | `OOQuiriumCascadeEntity::initQuiriumCascadeFromShip` `Core/Entities/OOQuiriumCascadeEntity.cpp:38` | ✅ |
| `+[OOQuiriumCascadeEntity quiriumCascadeFromShip:]` (59) | `OOQuiriumCascadeEntity::quiriumCascadeFromShip` `Core/Entities/OOQuiriumCascadeEntity.cpp:62` | ✅ |
| `-[OOQuiriumCascadeEntity descriptionComponents]` (64) | `OOQuiriumCascadeEntity::descriptionComponents` `Core/Entities/OOQuiriumCascadeEntity.cpp:69` | ✅ |
| `-[OOQuiriumCascadeEntity update:]` (69) | `OOQuiriumCascadeEntity::update` `Core/Entities/OOQuiriumCascadeEntity.cpp:75` | ✅ |
| `-[OOQuiriumCascadeEntity drawImmediate:translucent:]` (110) | `OOQuiriumCascadeEntity::drawImmediate` `Core/Entities/OOQuiriumCascadeEntity.cpp:121` | ✅ |
| `-[OOQuiriumCascadeEntity isEffect]` (136) | `OOQuiriumCascadeEntity::isEffect` `Core/Entities/OOQuiriumCascadeEntity.cpp:151` | ✅ |
| `-[OOQuiriumCascadeEntity isCascadeWeapon]` (141) | `OOQuiriumCascadeEntity::isCascadeWeapon` `Core/Entities/OOQuiriumCascadeEntity.cpp:153` | ✅ |
| `-[OOQuiriumCascadeEntity canCollide]` (146) | `OOQuiriumCascadeEntity::canCollide` `Core/Entities/OOQuiriumCascadeEntity.cpp:155` | ✅ |
| `-[OOQuiriumCascadeEntity checkCloseCollisionWith:]` (151) | `OOQuiriumCascadeEntity::checkCloseCollisionWith` `Core/Entities/OOQuiriumCascadeEntity.cpp:159` | ✅ |
| `-[Entity(OOQuiriumCascadeExtensions) isCascadeWeapon]` (160) | `OOEntityIsCascadeWeapon()` `Core/Entities/OOQuiriumCascadeEntity.h:59` | ➖ |

**Differences:**

- ➖ **low** — the category `-isCascadeWeapon` is replaced by the free function `OOEntityIsCascadeWeapon` (dynamic_cast, false for null); all upstream callers use it (PlayerEntity ×2, ShipEntity, StationEntity, HeadUpDisplay) (still open) — upstream `Core/Entities/OOQuiriumCascadeEntity.m:160` ↔ port `Core/Entities/OOQuiriumCascadeEntity.h:59`
- Subtle (✅): `update` damages a snapshot of `collidingEntities` (upstream fast enumeration would have raised on mutation). Per-tick `energy = Δt·(100000 − 90000·tf)` with `EQ_QC_MINE`, source the weak owner; radius grows by `Δt·min(240 + 10/tf², 1000)`; duration 20 s, collision delay 0.05 s; colour/alpha formulas and the single `randf()` unchanged — upstream `Core/Entities/OOQuiriumCascadeEntity.m:69-108` ↔ port `Core/Entities/OOQuiriumCascadeEntity.cpp:75-119`

## OORingEffectEntity

<a id="ooringeffectentity"></a>
Upstream `src/Core/Entities/OORingEffectEntity.m` ↔ `Core/Entities/OORingEffectEntity.cpp` (157 / 161 lines)

**Status:** done — 9 rows: 9 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OORingEffectEntity initialize]` (52) | `OORingEffectEntity::initialize` `Core/Entities/OORingEffectEntity.cpp:54` | ✅ |
| `-[OORingEffectEntity initRingFromEntity:]` (61) | `OORingEffectEntity::initRingFromEntity` `Core/Entities/OORingEffectEntity.cpp:67` | ✅ |
| `+[OORingEffectEntity ringFromEntity:]` (88) | `OORingEffectEntity::ringFromEntity` `Core/Entities/OORingEffectEntity.cpp:93` | ✅ |
| `+[OORingEffectEntity shrinkingRingFromEntity:]` (93) | `OORingEffectEntity::shrinkingRingFromEntity` `Core/Entities/OORingEffectEntity.cpp:102` | ✅ |
| `-[OORingEffectEntity descriptionComponents]` (103) | `OORingEffectEntity::descriptionComponents` `Core/Entities/OORingEffectEntity.cpp:112` | ✅ |
| `-[OORingEffectEntity update:]` (108) | `OORingEffectEntity::update` `Core/Entities/OORingEffectEntity.cpp:116` | ✅ |
| `-[OORingEffectEntity drawImmediate:translucent:]` (121) | `OORingEffectEntity::drawImmediate` `Core/Entities/OORingEffectEntity.cpp:128` | ✅ |
| `-[OORingEffectEntity isEffect]` (147) | `OORingEffectEntity::isEffect` `Core/Entities/OORingEffectEntity.cpp:159` | ✅ |
| `-[OORingEffectEntity canCollide]` (152) | `OORingEffectEntity::canCollide` `Core/Entities/OORingEffectEntity.cpp:161` | ✅ |

**Differences:**

- Subtle (✅): `+initialize` ran lazily on the first message to the class; the port runs it (guarded, once) on the first `ringFromEntity` call, the only way to construct a ring. Constants identical: 2 s duration, 0.4 s attack, sizes 0.5/0.625 × radius, growth 0.55/0.625 × radius, shrink factors −2.5/−2.0, 65 segments. The GL error label still says "OOQuiriumCascadeEntity", as upstream — port `Core/Entities/OORingEffectEntity.cpp:54-64,93-100,153-156`

## OOSparkEntity

<a id="oosparkentity"></a>
Upstream `src/Core/Entities/OOSparkEntity.m` ↔ `Core/Entities/OOSparkEntity.cpp` (81 / 77 lines)

**Status:** done — 3 rows: 3 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSparkEntity initWithPosition:velocity:duration:size:color:]` (39) | `OOSparkEntity::initWithPosition` `Core/Entities/OOSparkEntity.cpp:39` (+ `sparkWithPosition` `:31`) | ✅ |
| `-[OOSparkEntity update:]` (58) | `OOSparkEntity::update` `Core/Entities/OOSparkEntity.cpp:57` | ✅ |
| `-[OOSparkEntity performUpdate:]` (64) | `OOSparkEntity::performUpdate` `Core/Entities/OOSparkEntity.cpp:62` | ✅ |

**Differences:**

- None. Fade-to-red mix, removal at `mix == 0`, and a nil colour leaving `_baseRGBA` as it was are unchanged.

## OOSunEntity

<a id="oosunentity"></a>
Upstream `src/Core/Entities/OOSunEntity.m` ↔ `Core/Entities/OOSunEntity.cpp` (738 / 796 lines)

**Status:** done — 30 rows: 29 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSunEntity init]` (52) | — (debug-only `assert(0)` guard; suns are built only through `initSunWithColor`) | ➖ |
| `-[OOSunEntity setSunColor:]` (59) | `OOSunEntity::setSunColor` `Core/Entities/OOSunEntity.cpp:46` | ✅ |
| `-[OOSunEntity initSunWithColor:andDictionary:]` (123) | `OOSunEntity::initSunWithColor` `Core/Entities/OOSunEntity.cpp:120` | ✅ |
| `-[OOSunEntity dealloc]` (203) | `std::optional<std::string> _name` member (RAII) | ✅ |
| `-[OOSunEntity descriptionComponents]` (209) | `OOSunEntity::descriptionComponents` `Core/Entities/OOSunEntity.cpp:208` | ✅ |
| `-[OOSunEntity canCollide]` (221) | `OOSunEntity::canCollide` `Core/Entities/OOSunEntity.cpp:223` | ✅ |
| `-[OOSunEntity checkCloseCollisionWith:]` (227) | `OOSunEntity::checkCloseCollisionWith` `Core/Entities/OOSunEntity.cpp:226` | ✅ |
| `-[OOSunEntity update:]` (237) | `OOSunEntity::update` `Core/Entities/OOSunEntity.cpp:235` | ✅ |
| `-[OOSunEntity drawImmediate:translucent:]` (307) | `OOSunEntity::drawImmediate` `Core/Entities/OOSunEntity.cpp:320` | ✅ |
| `-[OOSunEntity updateCameraRelativePosition]` (327) | `OOSunEntity::updateCameraRelativePosition` `Core/Entities/OOSunEntity.cpp:339` | ✅ |
| `-[OOSunEntity drawOpaqueParts]` (339) | `OOSunEntity::drawOpaqueParts` `Core/Entities/OOSunEntity.cpp:352` | ✅ |
| `-[OOSunEntity drawTranslucentParts]` (419) | `OOSunEntity::drawTranslucentParts` `Core/Entities/OOSunEntity.cpp:436` | ✅ |
| `-[OOSunEntity calculateGLArrays:width:zDistance:]` (438) | `OOSunEntity::calculateGLArrays` `Core/Entities/OOSunEntity.cpp:455` | ✅ |
| `-[OOSunEntity drawDirectVisionSunGlare]` (550) | `OOSunEntity::drawDirectVisionSunGlare` `Core/Entities/OOSunEntity.cpp:571` | ✅ |
| `-[OOSunEntity drawStarGlare]` (584) | `OOSunEntity::drawStarGlare` `Core/Entities/OOSunEntity.cpp:626` | ✅ |
| `-[OOSunEntity changeSunProperty:withDictionary:]` (616) | `OOSunEntity::changeSunProperty` `Core/Entities/OOSunEntity.cpp:661` | ✅ |
| `-[OOSunEntity planetType]` (647) | `OOSunEntity::planetType` `Core/Entities/OOSunEntity.cpp:702` | ✅ |
| `-[OOSunEntity getDiffuseComponents:]` (652) | `OOSunEntity::getDiffuseComponents` `Core/Entities/OOSunEntity.cpp:704` | ✅ |
| `-[OOSunEntity getSpecularComponents:]` (658) | `OOSunEntity::getSpecularComponents` `Core/Entities/OOSunEntity.cpp:709` | ✅ |
| `-[OOSunEntity radius]` (664) | `OOSunEntity::radius` `Core/Entities/OOSunEntity.cpp:714` | ✅ |
| `-[OOSunEntity setRadius:andCorona:]` (669) | `OOSunEntity::setRadius` `Core/Entities/OOSunEntity.cpp:716` | ✅ |
| `-[OOSunEntity setPosition:]` (682) | `OOSunEntity::setPosition` `Core/Entities/OOSunEntity.cpp:729` | ✅ |
| `-[OOSunEntity willGoNova]` (688) | `OOSunEntity::willGoNova` `Core/Entities/OOSunEntity.cpp:735` | ✅ |
| `-[OOSunEntity goneNova]` (693) | `OOSunEntity::goneNova` `Core/Entities/OOSunEntity.cpp:737` | ✅ |
| `-[OOSunEntity setGoingNova:inTime:]` (698) | `OOSunEntity::setGoingNova` `Core/Entities/OOSunEntity.cpp:739` | ✅ |
| `-[OOSunEntity resetNova]` (710) | `OOSunEntity::resetNova` `Core/Entities/OOSunEntity.cpp:751` | ✅ |
| `-[OOSunEntity isSun]` (717) | `OOSunEntity::isSun` `Core/Entities/OOSunEntity.cpp:757` | ✅ |
| `-[OOSunEntity isVisible]` (722) | `OOSunEntity::isVisible` `Core/Entities/OOSunEntity.cpp:759` | ✅ |
| `-[OOSunEntity name]` (727) | `OOSunEntity::name` `Core/Entities/OOSunEntity.cpp:761` | ✅ |
| `-[OOSunEntity setName:]` (732) | `OOSunEntity::setName` `Core/Entities/OOSunEntity.cpp:763` | ✅ |

**Differences:**

- ➖ **low** — `-init` (`#ifndef NDEBUG assert(0)`) guarded against plain `-init`; the port builds suns only through `initSunWithColor`, so the guard has nothing to guard (still open) — upstream `Core/Entities/OOSunEntity.m:51-57`
- Subtle (✅): defaults identical: radius 100 km, `sbf` 80 and `scaf` 0.005 from user defaults, star name `[oolite-default-star-name]` (nil dict reads nil name, as nil messaging), `corona_hues` 1.0 clamped, `corona_shimmer` −1 → `1/(0.5+2(randf+randf))` else `clamp*2 + randf*randf`, `corona_flare` clamped ≥0.01 in `setRadius`, `cor16k = r*8*corona`. RNG order (2 in `setSunColor`, 2 for shimmer, `SUN_CORONA_SAMPLES` for rvalue) unchanged — port `Core/Entities/OOSunEntity.cpp:46-206,661-727`
- Subtle (✅): nova: `setGoingNova` sets rate 10000 and countdown `fmax(interval,0)`; corona speed +0.75/s up to 5 during countdown; 60 s expansion with `sky_bri = 1-1.5t`; on the first tick writes `sun_gone_nova`=YES, `corona_flare`=0.3f, `corona_hues`=0.05f under `org.oolite.oolite` (as single reals, i.e. `+numberWithFloat:`), then `sun_radius` as a float; at the end `resetNova` keeps `throw_sparks`. Log texts `%.1f` → `{:.1f}` unchanged — port `Core/Entities/OOSunEntity.cpp:243-304,739-755`

## OOVisualEffectEntity

<a id="oovisualeffectentity"></a>
Upstream `src/Core/Entities/OOVisualEffectEntity.m` ↔ `Core/Entities/OOVisualEffectEntity.cpp` (875 / 909 lines)

**Status:** done — 83 rows: 81 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOVisualEffectEntity init]` (69) | — (forwarded to `initWithKey:@"" definition:nil`, which asserts; replaced by `oo::NewVisualEffect` `Core/Entities/OOVisualEffectEntity.cpp:125`) | ➖ |
| `-[OOVisualEffectEntity initWithKey:definition:]` (74) | `OOVisualEffectEntity::initWithKey` `Core/Entities/OOVisualEffectEntity.cpp:138` | ✅ |
| `-[OOVisualEffectEntity setUpVisualEffectFromDictionary:]` (98) | `OOVisualEffectEntity::setUpVisualEffectFromDictionary` `Core/Entities/OOVisualEffectEntity.cpp:155` | ✅ |
| `-[OOVisualEffectEntity dealloc]` (159) | `OOVisualEffectEntity::~OOVisualEffectEntity` `Core/Entities/OOVisualEffectEntity.cpp:218` | ✅ |
| `-[OOVisualEffectEntity isEffect]` (175) | `OOVisualEffectEntity::isEffect` `Core/Entities/OOVisualEffectEntity.cpp:226` | ✅ |
| `-[OOVisualEffectEntity isVisualEffect]` (180) | `OOVisualEffectEntity::getIsVisualEffect` `Core/Entities/OOVisualEffectEntity.cpp:228` | ✅ |
| `-[OOVisualEffectEntity canCollide]` (185) | `OOVisualEffectEntity::canCollide` `Core/Entities/OOVisualEffectEntity.cpp:230` | ✅ |
| `-[OOVisualEffectEntity mesh]` (190) | `OOVisualEffectEntity::mesh` `Core/Entities/OOVisualEffectEntity.cpp:232` | ✅ |
| `-[OOVisualEffectEntity setMesh:]` (195) | `OOVisualEffectEntity::setMesh` `Core/Entities/OOVisualEffectEntity.cpp:237` | ✅ |
| `-[OOVisualEffectEntity effectKey]` (202) | `OOVisualEffectEntity::effectKey` `Core/Entities/OOVisualEffectEntity.cpp:243` | ✅ |
| `-[OOVisualEffectEntity frustumRadius]` (207) | `OOVisualEffectEntity::frustumRadius` `Core/Entities/OOVisualEffectEntity.cpp:247` | ✅ |
| `-[OOVisualEffectEntity clearSubEntities]` (212) | `OOVisualEffectEntity::clearSubEntities` `Core/Entities/OOVisualEffectEntity.cpp:251` | ✅ |
| `-[OOVisualEffectEntity setUpSubEntities]` (227) | `OOVisualEffectEntity::setUpSubEntities` `Core/Entities/OOVisualEffectEntity.cpp:266` | ✅ |
| `-[OOVisualEffectEntity removeSubEntity:]` (242) | `OOVisualEffectEntity::removeSubEntity` `Core/Entities/OOVisualEffectEntity.cpp:284` | ✅ |
| `-[OOVisualEffectEntity setNoDrawDistance]` (248) | `OOVisualEffectEntity::setNoDrawDistance` `Core/Entities/OOVisualEffectEntity.cpp:291` | ✅ |
| `-[OOVisualEffectEntity setUpOneSubentity:]` (254) | `OOVisualEffectEntity::setUpOneSubentity` `Core/Entities/OOVisualEffectEntity.cpp:297` | ✅ |
| `-[OOVisualEffectEntity setUpOneFlasher:]` (264) | `OOVisualEffectEntity::setUpOneFlasher` `Core/Entities/OOVisualEffectEntity.cpp:307` | ✅ |
| `-[OOVisualEffectEntity setUpOneStandardSubentity:]` (272) | `OOVisualEffectEntity::setUpOneStandardSubentity` `Core/Entities/OOVisualEffectEntity.cpp:319` | ✅ |
| `-[OOVisualEffectEntity addSubEntity:]` (304) | `OOVisualEffectEntity::addSubEntity` `Core/Entities/OOVisualEffectEntity.cpp:357` | ✅ |
| `-[OOVisualEffectEntity subEntities]` (322) | `OOVisualEffectEntity::subEntities` `Core/Entities/OOVisualEffectEntity.cpp:373` | ✅ |
| `-[OOVisualEffectEntity subEntityCount]` (327) | `OOVisualEffectEntity::subEntityCount` `Core/Entities/OOVisualEffectEntity.cpp:383` | ✅ |
| `-[OOVisualEffectEntity visualEffectSubEntityEnumerator]` (332) | `OOVisualEffectEntity::visualEffectSubEntityEnumerator` `Core/Entities/OOVisualEffectEntity.cpp:388` | ✅ |
| `-[OOVisualEffectEntity hasSubEntity:]` (337) | `OOVisualEffectEntity::hasSubEntity` `Core/Entities/OOVisualEffectEntity.cpp:393` | ✅ |
| `-[OOVisualEffectEntity subEntityEnumerator]` (342) | `OOVisualEffectEntity::subEntityEnumerator` `Core/Entities/OOVisualEffectEntity.cpp:401` | ✅ |
| `-[OOVisualEffectEntity effectSubEntityEnumerator]` (347) | `OOVisualEffectEntity::effectSubEntityEnumerator` `Core/Entities/OOVisualEffectEntity.cpp:405` | ✅ |
| `-[OOVisualEffectEntity flasherEnumerator]` (352) | `OOVisualEffectEntity::flasherEnumerator` `Core/Entities/OOVisualEffectEntity.cpp:409` | ✅ |
| `-[OOVisualEffectEntity drawSubEntityImmediate:translucent:]` (357) | `OOVisualEffectEntity::drawSubEntityImmediate` `Core/Entities/OOVisualEffectEntity.cpp:419` | ✅ |
| `-[OOVisualEffectEntity rescaleBy:]` (372) | `OOVisualEffectEntity::rescaleBy(factor)` `Core/Entities/OOVisualEffectEntity.cpp:436` | ✅ |
| `-[OOVisualEffectEntity rescaleBy:writeToCache:]` (389) | `OOVisualEffectEntity::rescaleBy(factor, writeToCache)` `Core/Entities/OOVisualEffectEntity.cpp:456` | ✅ |
| `-[OOVisualEffectEntity scaleMax]` (395) | `OOVisualEffectEntity::scaleMax` `Core/Entities/OOVisualEffectEntity.cpp:462` | ✅ |
| `-[OOVisualEffectEntity scaleX]` (412) | `OOVisualEffectEntity::scaleX` `Core/Entities/OOVisualEffectEntity.cpp:478` | ✅ |
| `-[OOVisualEffectEntity setScaleX:]` (417) | `OOVisualEffectEntity::setScaleX` `Core/Entities/OOVisualEffectEntity.cpp:480` | ✅ |
| `-[OOVisualEffectEntity scaleY]` (437) | `OOVisualEffectEntity::scaleY` `Core/Entities/OOVisualEffectEntity.cpp:506` | ✅ |
| `-[OOVisualEffectEntity setScaleY:]` (442) | `OOVisualEffectEntity::setScaleY` `Core/Entities/OOVisualEffectEntity.cpp:508` | ✅ |
| `-[OOVisualEffectEntity scaleZ]` (462) | `OOVisualEffectEntity::scaleZ` `Core/Entities/OOVisualEffectEntity.cpp:534` | ✅ |
| `-[OOVisualEffectEntity setScaleZ:]` (467) | `OOVisualEffectEntity::setScaleZ` `Core/Entities/OOVisualEffectEntity.cpp:536` | ✅ |
| `-[OOVisualEffectEntity collisionRadius]` (487) | `OOVisualEffectEntity::collisionRadius` `Core/Entities/OOVisualEffectEntity.cpp:562` | ✅ |
| `-[OOVisualEffectEntity orientationChanged]` (492) | `OOVisualEffectEntity::orientationChanged` `Core/Entities/OOVisualEffectEntity.cpp:566` | ✅ |
| `-[OOVisualEffectEntity forwardVector]` (502) | `OOVisualEffectEntity::forwardVector` `Core/Entities/OOVisualEffectEntity.cpp:575` | ✅ |
| `-[OOVisualEffectEntity upVector]` (508) | `OOVisualEffectEntity::upVector` `Core/Entities/OOVisualEffectEntity.cpp:578` | ✅ |
| `-[OOVisualEffectEntity rightVector]` (514) | `OOVisualEffectEntity::rightVector` `Core/Entities/OOVisualEffectEntity.cpp:581` | ✅ |
| `-[OOVisualEffectEntity scannerDisplayColor1]` (519) | `OOVisualEffectEntity::scannerDisplayColor1` `Core/Entities/OOVisualEffectEntity.cpp:665` | ✅ |
| `-[OOVisualEffectEntity scannerDisplayColor2]` (524) | `OOVisualEffectEntity::scannerDisplayColor2` `Core/Entities/OOVisualEffectEntity.cpp:669` | ✅ |
| `-[OOVisualEffectEntity setScannerDisplayColor1:]` (529) | `OOVisualEffectEntity::setScannerDisplayColor1` `Core/Entities/OOVisualEffectEntity.cpp:673` | ✅ |
| `-[OOVisualEffectEntity setScannerDisplayColor2:]` (538) | `OOVisualEffectEntity::setScannerDisplayColor2` `Core/Entities/OOVisualEffectEntity.cpp:683` | ✅ |
| `-[OOVisualEffectEntity scannerDisplayColorForShip:scannerDisplayColor1:scannerDisplayColor2:]` (550) | `OOVisualEffectEntity::scannerDisplayColorForShip` `Core/Entities/OOVisualEffectEntity.cpp:696` | ✅ |
| `-[OOVisualEffectEntity drawImmediate:translucent:]` (575) | `OOVisualEffectEntity::drawImmediate` `Core/Entities/OOVisualEffectEntity.cpp:583` | ✅ |
| `-[OOVisualEffectEntity update:]` (598) | `OOVisualEffectEntity::update` `Core/Entities/OOVisualEffectEntity.cpp:610` | ✅ |
| `-[OOVisualEffectEntity isBreakPattern]` (613) | `OOVisualEffectEntity::isBreakPattern` `Core/Entities/OOVisualEffectEntity.cpp:625` | ✅ |
| `-[OOVisualEffectEntity setIsBreakPattern:]` (618) | `OOVisualEffectEntity::setIsBreakPattern` `Core/Entities/OOVisualEffectEntity.cpp:629` | ✅ |
| `-[OOVisualEffectEntity effectInfoDictionary]` (623) | `OOVisualEffectEntity::effectInfoDictionary` `Core/Entities/OOVisualEffectEntity.cpp:633` | ✅ |
| `-[OOVisualEffectEntity setScript:]` (630) | `OOVisualEffectEntity::setScript` `Core/Entities/OOVisualEffectEntity.cpp:726` | ✅ |
| `-[OOVisualEffectEntity script]` (646) | `OOVisualEffectEntity::script` `Core/Entities/OOVisualEffectEntity.cpp:742` | ✅ |
| `-[OOVisualEffectEntity scriptInfo]` (651) | `OOVisualEffectEntity::scriptInfo` `Core/Entities/OOVisualEffectEntity.cpp:744` | ✅ |
| `-[OOVisualEffectEntity doScriptEvent:]` (657) | `OOVisualEffectEntity::doScriptEvent` `Core/Entities/OOVisualEffectEntity.cpp:749` | ✅ |
| `-[OOVisualEffectEntity remove]` (664) | `OOVisualEffectEntity::remove` `Core/Entities/OOVisualEffectEntity.cpp:756` | ✅ |
| `-[OOVisualEffectEntity compareBeaconCodeWith:]` (672) | `OOVisualEffectEntity::compareBeaconCodeWith` `Core/Entities/OOVisualEffectEntity.cpp:763` | ❌ |
| `-[OOVisualEffectEntity beaconCode]` (677) | `OOVisualEffectEntity::beaconCode` `Core/Entities/OOVisualEffectEntity.cpp:768` | ✅ |
| `-[OOVisualEffectEntity setBeaconCode:]` (682) | `OOVisualEffectEntity::setBeaconCode` `Core/Entities/OOVisualEffectEntity.cpp:775` | ✅ |
| `-[OOVisualEffectEntity beaconLabel]` (699) | `OOVisualEffectEntity::beaconLabel` `Core/Entities/OOVisualEffectEntity.cpp:792` | ✅ |
| `-[OOVisualEffectEntity setBeaconLabel:]` (704) | `OOVisualEffectEntity::setBeaconLabel` `Core/Entities/OOVisualEffectEntity.cpp:796` | ✅ |
| `-[OOVisualEffectEntity isBeacon]` (715) | `OOVisualEffectEntity::isBeacon` `Core/Entities/OOVisualEffectEntity.cpp:806` | ✅ |
| `-[OOVisualEffectEntity beaconDrawable]` (720) | `OOVisualEffectEntity::beaconDrawable` `Core/Entities/OOVisualEffectEntity.cpp:808` | ✅ |
| `-[OOVisualEffectEntity prevBeacon]` (743) | `OOVisualEffectEntity::prevBeacon` `Core/Entities/OOVisualEffectEntity.cpp:835` | ✅ |
| `-[OOVisualEffectEntity nextBeacon]` (748) | `OOVisualEffectEntity::nextBeacon` `Core/Entities/OOVisualEffectEntity.cpp:839` | ✅ |
| `-[OOVisualEffectEntity setPrevBeacon:]` (753) | `OOVisualEffectEntity::setPrevBeacon` `Core/Entities/OOVisualEffectEntity.cpp:843` | ✅ |
| `-[OOVisualEffectEntity setNextBeacon:]` (761) | `OOVisualEffectEntity::setNextBeacon` `Core/Entities/OOVisualEffectEntity.cpp:849` | ✅ |
| `-[OOVisualEffectEntity isJammingScanning]` (769) | `OOVisualEffectEntity::isJammingScanning` `Core/Entities/OOVisualEffectEntity.cpp:855` | ✅ |
| `-[OOVisualEffectEntity hullHeatLevel]` (777) | `OOVisualEffectEntity::hullHeatLevel` `Core/Entities/OOVisualEffectEntity.cpp:860` | ✅ |
| `-[OOVisualEffectEntity setHullHeatLevel:]` (782) | `OOVisualEffectEntity::setHullHeatLevel` `Core/Entities/OOVisualEffectEntity.cpp:862` | ✅ |
| `-[OOVisualEffectEntity shaderFloat1]` (787) | `OOVisualEffectEntity::shaderFloat1` `Core/Entities/OOVisualEffectEntity.cpp:866` | ✅ |
| `-[OOVisualEffectEntity setShaderFloat1:]` (792) | `OOVisualEffectEntity::setShaderFloat1` `Core/Entities/OOVisualEffectEntity.cpp:868` | ✅ |
| `-[OOVisualEffectEntity shaderFloat2]` (797) | `OOVisualEffectEntity::shaderFloat2` `Core/Entities/OOVisualEffectEntity.cpp:872` | ✅ |
| `-[OOVisualEffectEntity setShaderFloat2:]` (802) | `OOVisualEffectEntity::setShaderFloat2` `Core/Entities/OOVisualEffectEntity.cpp:874` | ✅ |
| `-[OOVisualEffectEntity shaderInt1]` (807) | `OOVisualEffectEntity::shaderInt1` `Core/Entities/OOVisualEffectEntity.cpp:878` | ✅ |
| `-[OOVisualEffectEntity setShaderInt1:]` (812) | `OOVisualEffectEntity::setShaderInt1` `Core/Entities/OOVisualEffectEntity.cpp:880` | ✅ |
| `-[OOVisualEffectEntity shaderInt2]` (817) | `OOVisualEffectEntity::shaderInt2` `Core/Entities/OOVisualEffectEntity.cpp:882` | ✅ |
| `-[OOVisualEffectEntity setShaderInt2:]` (822) | `OOVisualEffectEntity::setShaderInt2` `Core/Entities/OOVisualEffectEntity.cpp:884` | ✅ |
| `-[OOVisualEffectEntity shaderVector1]` (827) | `OOVisualEffectEntity::shaderVector1` `Core/Entities/OOVisualEffectEntity.cpp:886` | ✅ |
| `-[OOVisualEffectEntity setShaderVector1:]` (832) | `OOVisualEffectEntity::setShaderVector1` `Core/Entities/OOVisualEffectEntity.cpp:888` | ✅ |
| `-[OOVisualEffectEntity shaderVector2]` (837) | `OOVisualEffectEntity::shaderVector2` `Core/Entities/OOVisualEffectEntity.cpp:892` | ✅ |
| `-[OOVisualEffectEntity setShaderVector2:]` (842) | `OOVisualEffectEntity::setShaderVector2` `Core/Entities/OOVisualEffectEntity.cpp:894` | ✅ |
| `-[OOVisualEffectEntity(SubEntityRelationship) isShipWithSubEntityShip:]` (852) | `OOVisualEffectEntity::isShipWithSubEntityShip` `Core/Entities/OOVisualEffectEntity.cpp:640` | ✅ |

**Differences:**

- ❌ **low** — `compareBeaconCodeWith`: with no beacon code on this effect, upstream messages nil and gets `NSOrderedSame` (0). The port compares `""` with the other code and answers ascending, so code-less effects can sort differently in the beacon list (still open) — upstream `Core/Entities/OOVisualEffectEntity.m:674` ↔ port `Core/Entities/OOVisualEffectEntity.cpp:764-765`
- ➖ **low** — `-init` forwarded to `initWithKey:@"" definition:nil` and tripped `NSParameterAssert(dict != nil)`. The port has no such entry point, and `setUpVisualEffectFromDictionary` substitutes an empty dict for a null one (still open, unchanged) — upstream `Core/Entities/OOVisualEffectEntity.m:69-78` ↔ port `Core/Entities/OOVisualEffectEntity.cpp:125-161`
- Subtle (✅): `setBeaconCode`/`setBeaconLabel` replace whenever either side is non-null, where upstream compared pointers. Re-setting the same code rebuilds `_beaconDrawable`; the visible result is the same — upstream `Core/Entities/OOVisualEffectEntity.m:687,709` ↔ port `Core/Entities/OOVisualEffectEntity.cpp:780,801`
- Subtle (✅): `setScript(nullopt)` passes `""` to `jsScriptFromFileNamed`, which returns null on an empty name as upstream did on nil (`OOScript.cpp:211` ↔ `OOScript.m:180`), so the default effect script is loaded. `OptionalStringForKey` accepts strings and numbers, as `oo_stringForKey:` did. Sub-entity orientation defaults to identity, position to zero — port `Core/Entities/OOVisualEffectEntity.cpp:88-94,343-345`

## OOWaypointEntity

<a id="oowaypointentity"></a>
Upstream `src/Core/Entities/OOWaypointEntity.m` ↔ `Core/Entities/OOWaypointEntity.cpp` (289 / 273 lines)

**Status:** done — 22 rows: 20 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOWaypointEntity waypointWithDictionary:]` (43) | `OOWaypointEntity::waypointWithDictionary` `Core/Entities/OOWaypointEntity.cpp:46` | ✅ |
| `-[OOWaypointEntity initWithDictionary:]` (48) | `OOWaypointEntity::initWithDictionary` `Core/Entities/OOWaypointEntity.cpp:54` | ✅ |
| `-[OOWaypointEntity dealloc]` (68) | members (`std::optional`, `weak_ptr`, `shared_ptr`) `Core/Entities/OOWaypointEntity.h` | ➖ |
| `-[OOWaypointEntity setOrientation:]` (80) | `OOWaypointEntity::setOrientation` `Core/Entities/OOWaypointEntity.cpp:81` | ✅ |
| `-[OOWaypointEntity oriented]` (91) | `OOWaypointEntity::getOriented` `Core/Entities/OOWaypointEntity.cpp:91` | ✅ |
| `-[OOWaypointEntity size]` (96) | `OOWaypointEntity::size` `Core/Entities/OOWaypointEntity.cpp:93` | ✅ |
| `-[OOWaypointEntity setSize:]` (101) | `OOWaypointEntity::setSize` `Core/Entities/OOWaypointEntity.cpp:95` | ✅ |
| `-[OOWaypointEntity isEffect]` (109) | `OOWaypointEntity::isEffect` `Core/Entities/OOWaypointEntity.cpp:103` | ✅ |
| `-[OOWaypointEntity isWaypoint]` (114) | `OOWaypointEntity::isWaypoint` `Core/Entities/OOWaypointEntity.cpp:105` | ✅ |
| `-[OOWaypointEntity drawImmediate:translucent:]` (119) | `OOWaypointEntity::drawImmediate` `Core/Entities/OOWaypointEntity.cpp:107` | ✅ |
| `-[OOWaypointEntity compareBeaconCodeWith:]` (187) | `OOWaypointEntity::compareBeaconCodeWith` `Core/Entities/OOWaypointEntity.cpp:177` | ❌ |
| `-[OOWaypointEntity beaconCode]` (192) | `OOWaypointEntity::beaconCode` `Core/Entities/OOWaypointEntity.cpp:182` | ✅ |
| `-[OOWaypointEntity setBeaconCode:]` (197) | `OOWaypointEntity::setBeaconCode` `Core/Entities/OOWaypointEntity.cpp:189` | ✅ |
| `-[OOWaypointEntity beaconLabel]` (214) | `OOWaypointEntity::beaconLabel` `Core/Entities/OOWaypointEntity.cpp:205` | ✅ |
| `-[OOWaypointEntity setBeaconLabel:]` (219) | `OOWaypointEntity::setBeaconLabel` `Core/Entities/OOWaypointEntity.cpp:209` | ✅ |
| `-[OOWaypointEntity isBeacon]` (230) | `OOWaypointEntity::isBeacon` `Core/Entities/OOWaypointEntity.cpp:219` | ✅ |
| `-[OOWaypointEntity beaconDrawable]` (235) | `OOWaypointEntity::beaconDrawable` `Core/Entities/OOWaypointEntity.cpp:221` | ✅ |
| `-[OOWaypointEntity prevBeacon]` (258) | `OOWaypointEntity::prevBeacon` `Core/Entities/OOWaypointEntity.cpp:248` | ✅ |
| `-[OOWaypointEntity nextBeacon]` (263) | `OOWaypointEntity::nextBeacon` `Core/Entities/OOWaypointEntity.cpp:250` | ✅ |
| `-[OOWaypointEntity setPrevBeacon:]` (268) | `OOWaypointEntity::setPrevBeacon` `Core/Entities/OOWaypointEntity.cpp:252` | ✅ |
| `-[OOWaypointEntity setNextBeacon:]` (276) | `OOWaypointEntity::setNextBeacon` `Core/Entities/OOWaypointEntity.cpp:258` | ✅ |
| `-[OOWaypointEntity isJammingScanning]` (284) | `OOWaypointEntity::isJammingScanning` `Core/Entities/OOWaypointEntity.cpp:264` | ✅ |

**Differences:**

- ❌ **low** — `compareBeaconCodeWith` substitutes `""` for a missing code on either side, where upstream `[nil compare:…]` answered `NSOrderedSame` and `[code compare:nil …]` took Foundation's nil-argument path. Waypoints always carry a code (default `W`), so this shows only against a code-less other entity (still open) — upstream `Core/Entities/OOWaypointEntity.m:189` ↔ port `Core/Entities/OOWaypointEntity.cpp:178-179`
- ➖ **low** — `-dealloc` releases are now RAII members (still open, unchanged) — upstream `Core/Entities/OOWaypointEntity.m:68`
- Subtle (✅): `drawImmediate` keeps the constants and vertex order (alpha 0.75, ×0.25 when not the compass target, fade `0.004·√d/size`, cut-off 0.01, s1 = 0.75·size, chevrons while s1 > 20). A null PLAYER answers NO/nil as messaging nil did. Defaults are size 1000 (non-negative), code `W`, label `Waypoint`; the only caller passes a non-null dict (`Universe.cpp:4283`) — upstream `Core/Entities/OOWaypointEntity.m:54-63,119-183` ↔ port `Core/Entities/OOWaypointEntity.cpp:59-77,107-173`

## PlanetEntity

<a id="planetentity"></a>
Upstream `src/Core/Entities/PlanetEntity.m` ↔ *(no counterpart: dead upstream under `#if !NEW_PLANETS`; live planet is `Core/Entities/OOPlanetEntity.cpp`)*

**Status:** done — 51 rows: 0 ✅ 0 ⚠️ 0 ❌ 51 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlanetEntity init]` (180) | — (dead upstream: `#if !NEW_PLANETS`) | ➖ |
| `-[PlanetEntity initAsAtmosphereForPlanet:dictionary:]` (187) | — (dead upstream) | ➖ |
| `-[PlanetEntity miniaturize]` (334) | — (dead upstream) | ➖ |
| `-[PlanetEntity initFromDictionary:withAtmosphere:andSeed:]` (351) | — (dead upstream; live path is `OOPlanetEntity::initFromDictionary` `Core/Entities/OOPlanetEntity.cpp`) | ➖ |
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
| `baseVertexIndexForEdge` (1212) | — (dead upstream) | ➖ |
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

- ➖ Dead code upstream (still holds). The whole body of `PlanetEntity.m` sits inside `#if !NEW_PLANETS` (`PlanetEntity.m:27…1498`; header `PlanetEntity.h:31…128`), and `NEW_PLANETS` is `#define`d to 1 in `OOStellarBody.h:35` with no other definition in the tree. So the translation unit was empty in every upstream build. The live planet is `OOPlanetEntity` (`OOPlanetEntity.m:27` `#if NEW_PLANETS`) ↔ port `Core/Entities/OOPlanetEntity.cpp`. The port has no `PlanetEntity` class, and nothing behavioural was lost — upstream `Core/Entities/PlanetEntity.m:27`

## SkyEntity

<a id="skyentity"></a>
Upstream `src/Core/Entities/SkyEntity.m` ↔ `Core/Entities/SkyEntity.cpp` (313 / 317 lines)

**Status:** done — 13 rows: 13 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[SkyEntity initWithColors:col2:andSystemInfo:]` (51) | `SkyEntity::initWithColors` `Core/Entities/SkyEntity.cpp:80` | ✅ |
| `-[SkyEntity dealloc]` (138) | implicit (`skyColor` is a `std::shared_ptr<OOColor>` member) | ✅ |
| `-[SkyEntity skyColor]` (145) | `SkyEntity::getSkyColor` `Core/Entities/SkyEntity.cpp:161` | ✅ |
| `-[SkyEntity changeProperty:withDictionary:]` (150) | `SkyEntity::changeProperty` `Core/Entities/SkyEntity.cpp:163` | ✅ |
| `-[SkyEntity update:]` (170) | `SkyEntity::update` `Core/Entities/SkyEntity.cpp:183` | ✅ |
| `-[SkyEntity isSky]` (182) | `SkyEntity::isSky` `Core/Entities/SkyEntity.cpp:194` | ✅ |
| `-[SkyEntity isVisible]` (187) | `SkyEntity::isVisible` `Core/Entities/SkyEntity.cpp:196` | ✅ |
| `-[SkyEntity canCollide]` (192) | `SkyEntity::canCollide` `Core/Entities/SkyEntity.cpp:198` | ✅ |
| `-[SkyEntity cameraRangeFront]` (197) | `SkyEntity::cameraRangeFront` `Core/Entities/SkyEntity.cpp:200` | ✅ |
| `-[SkyEntity cameraRangeBack]` (202) | `SkyEntity::cameraRangeBack` `Core/Entities/SkyEntity.cpp:202` | ✅ |
| `-[SkyEntity drawImmediate:translucent:]` (207) | `SkyEntity::drawImmediate` `Core/Entities/SkyEntity.cpp:204` | ✅ |
| `-[SkyEntity descriptionForObjDump]` (218) | `SkyEntity::descriptionForObjDump` `Core/Entities/SkyEntity.cpp:215` | ✅ |
| `-[SkyEntity(OOPrivate) readColor1:andColor2:andColor3:andColor4:fromDictionary:]` (229) | `SkyEntity::readColor1` `Core/Entities/SkyEntity.cpp:221` | ✅ |

**Differences:**

- None (previous audit also had none). Subtle (✅): star and nebula counts keep the float→`signed` truncation (`sky_n_stars`/`sky_n_blurs` default -1, multipliers made non-negative, `SKY_BASIS_* * (0.5+randf())`; reduced detail caps at basis and halves stars), with one `randf()` each in the same order. Colour precedence is unchanged: `sky_rgb_colors` (six tokens, clamped), then premultiplied `sky_color_1/2`, then `nebula_color_1/2` falling back to the sky colours, and `nebulaSet` only from the nebula keys. Warning classes and texts (`sky.fromDict`, `script.warning`, `sky.warning`) match — upstream `Core/Entities/SkyEntity.m:66-133,150-180,229-311` ↔ port `Core/Entities/SkyEntity.cpp:90-159,163-192,221-317`
- Subtle (✅): when `sun_color` is absent and `col2` is null, upstream messaged nil and got a nil `skyColor`; the port guards and stores null explicitly. `changeProperty` stores the new colour itself instead of `[col copy]`, which is the same for an immutable colour — port `Core/Entities/SkyEntity.cpp:103-108,169`

## WormholeEntity

<a id="wormholeentity"></a>
Upstream `src/Core/Entities/WormholeEntity.m` ↔ `Core/Entities/WormholeEntity.cpp` (802 / 922 lines)

**Status:** done — 38 rows: 38 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[WormholeEntity(Private) init]` (58) | `WormholeEntity::init` `Core/Entities/WormholeEntity.cpp:76` | ✅ |
| `-[WormholeEntity initWithDict:]` (84) | `WormholeEntity::initWithDict` `Core/Entities/WormholeEntity.cpp:97` | ✅ |
| `-[WormholeEntity initWormholeTo:fromShip:]` (144) | `WormholeEntity::initWormholeTo` `Core/Entities/WormholeEntity.cpp:174` | ✅ |
| `-[WormholeEntity setMisjump]` (189) | `WormholeEntity::setMisjump` `Core/Entities/WormholeEntity.cpp:236` | ✅ |
| `-[WormholeEntity setMisjumpWithRange:]` (204) | `WormholeEntity::setMisjumpWithRange` `Core/Entities/WormholeEntity.cpp:256` | ✅ |
| `-[WormholeEntity withMisjump]` (226) | `WormholeEntity::withMisjump` `Core/Entities/WormholeEntity.cpp:283` | ✅ |
| `-[WormholeEntity misjumpRange]` (231) | `WormholeEntity::misjumpRange` `Core/Entities/WormholeEntity.cpp:285` | ✅ |
| `-[WormholeEntity suckInShip:]` (236) | `WormholeEntity::suckInShip` `Core/Entities/WormholeEntity.cpp:287` | ✅ |
| `-[WormholeEntity disgorgeShips]` (317) | `WormholeEntity::disgorgeShips` `Core/Entities/WormholeEntity.cpp:397` | ✅ |
| `-[WormholeEntity setContainsPlayer:]` (448) | `WormholeEntity::setContainsPlayer` `Core/Entities/WormholeEntity.cpp:572` | ✅ |
| `-[WormholeEntity setExitPosition:]` (453) | `WormholeEntity::setExitPosition` `Core/Entities/WormholeEntity.cpp:574` | ✅ |
| `-[WormholeEntity origin]` (459) | `WormholeEntity::getOrigin` `Core/Entities/WormholeEntity.cpp:579` | ✅ |
| `-[WormholeEntity destination]` (464) | `WormholeEntity::getDestination` `Core/Entities/WormholeEntity.cpp:581` | ✅ |
| `-[WormholeEntity originCoordinates]` (469) | `WormholeEntity::originCoordinates` `Core/Entities/WormholeEntity.cpp:583` | ✅ |
| `-[WormholeEntity destinationCoordinates]` (474) | `WormholeEntity::destinationCoordinates` `Core/Entities/WormholeEntity.cpp:585` | ✅ |
| `-[WormholeEntity exitSpeed]` (479) | `WormholeEntity::exitSpeed` `Core/Entities/WormholeEntity.cpp:587` | ✅ |
| `-[WormholeEntity setExitSpeed:]` (484) | `WormholeEntity::setExitSpeed` `Core/Entities/WormholeEntity.cpp:589` | ✅ |
| `-[WormholeEntity expiryTime]` (489) | `WormholeEntity::expiryTime` `Core/Entities/WormholeEntity.cpp:591` | ✅ |
| `-[WormholeEntity arrivalTime]` (494) | `WormholeEntity::arrivalTime` `Core/Entities/WormholeEntity.cpp:593` | ✅ |
| `-[WormholeEntity estimatedArrivalTime]` (499) | `WormholeEntity::estimatedArrivalTime` `Core/Entities/WormholeEntity.cpp:595` | ✅ |
| `-[WormholeEntity travelTime]` (504) | `WormholeEntity::travelTime` `Core/Entities/WormholeEntity.cpp:597` | ✅ |
| `-[WormholeEntity scanTime]` (509) | `WormholeEntity::scanTime` `Core/Entities/WormholeEntity.cpp:599` | ✅ |
| `-[WormholeEntity isScanned]` (514) | `WormholeEntity::isScanned` `Core/Entities/WormholeEntity.cpp:601` | ✅ |
| `-[WormholeEntity setScannedAt:]` (519) | `WormholeEntity::setScannedAt` `Core/Entities/WormholeEntity.cpp:605` | ✅ |
| `-[WormholeEntity scanInfo]` (528) | `WormholeEntity::scanInfo` `Core/Entities/WormholeEntity.cpp:613` | ✅ |
| `-[WormholeEntity setScanInfo:]` (533) | `WormholeEntity::setScanInfo` `Core/Entities/WormholeEntity.cpp:615` | ✅ |
| `-[WormholeEntity shipsInTransit]` (538) | `WormholeEntity::getShipsInTransit` `Core/Entities/WormholeEntity.cpp:619` (+ `WormholeEntityShipsInTransit` `:918`) | ✅ |
| `-[WormholeEntity dealloc]` (543) | implicit (`std::vector<OOWormholeTransit>` member) | ✅ |
| `-[WormholeEntity descriptionComponents]` (550) | `WormholeEntity::descriptionComponents` `Core/Entities/WormholeEntity.cpp:631` | ✅ |
| `-[WormholeEntity identFromShip:]` (559) | `WormholeEntity::identFromShip` `Core/Entities/WormholeEntity.cpp:643` | ✅ |
| `-[WormholeEntity canCollide]` (578) | `WormholeEntity::canCollide` `Core/Entities/WormholeEntity.cpp:668` | ✅ |
| `-[WormholeEntity checkCloseCollisionWith:]` (593) | `WormholeEntity::checkCloseCollisionWith` `Core/Entities/WormholeEntity.cpp:688` | ✅ |
| `-[WormholeEntity update:]` (598) | `WormholeEntity::update` `Core/Entities/WormholeEntity.cpp:692` | ✅ |
| `-[WormholeEntity drawImmediate:translucent:]` (626) | `WormholeEntity::drawImmediate` `Core/Entities/WormholeEntity.cpp:723` | ✅ |
| `DrawWormholeCorona` (669) | `DrawWormholeCorona` `Core/Entities/WormholeEntity.cpp:764` | ✅ |
| `-[WormholeEntity getDict]` (729) | `WormholeEntity::getDict` `Core/Entities/WormholeEntity.cpp:830` | ✅ |
| `-[WormholeEntity scanInfoString]` (761) | `WormholeEntity::scanInfoString` `Core/Entities/WormholeEntity.cpp:865` (+ `OOEnumName` `Core/Entities/WormholeEntity.h:80-90`) | ✅ |
| `-[WormholeEntity dumpSelfState]` (780) | `WormholeEntity::dumpSelfState` `Core/Entities/WormholeEntity.cpp:870` | ✅ |

**Differences:**

- None (previous audit also had none). Subtle (✅): lifetime, mass and expiry maths are identical. Minimum `witch_mass` is 200000, plus the player's mass for the player. `shrink_factor = mass/240000` for ships over 240000 in a nova system, else 1. `collision_radius = 0.5π·∛mass`; expiry is `now + mass/WORMHOLE_SHRINK_RATE/shrink_factor`, recomputed per sucked-in ship and capped at `arrival-1`. Travel time is `d²·3600` with `d ≥ 0.1`; misjump subtracts `d²·900`, or `(d(1-r))²·3600` with a range — upstream `Core/Entities/WormholeEntity.m:144-315,598-624` ↔ port `Core/Entities/WormholeEntity.cpp:174-395,692-721`
- Subtle (✅): `disgorgeShips` keeps the RNG order (`quaternion_set_random`, then `ranrot_rand()%256` for `d1`, `min_d1` ×3 behind the buoy, then `randf()` x then y for the ±75 m scatter) and the side-effect order (exit speed, beacon, bounty/2 unless misjump, leaving effects or addEntity, speed, `aiStarted`, `shipExitedWormhole`/`EXITED WITCHSPACE`, update). It iterates a snapshot of `shipsInTransit`, which matches fast enumeration — upstream `Core/Entities/WormholeEntity.m:317-446` ↔ port `Core/Entities/WormholeEntity.cpp:397-570`
- Subtle (✅): `getDict` writes doubles (`oo_setFloat:` stores `numberWithDouble:`, `OOCollectionExtractors.m:972`) and omits `ship_info` when a ship saves nil, as `dictionaryWithObjectsAndKeys:` stopped at nil. `getShipsInTransit` always emits `"time"` (0 when the save lacked `time_delta`; upstream omitted the key); consumers only read `"ship"` and the count — port `Core/Entities/WormholeEntity.cpp:619-629,850-859`

