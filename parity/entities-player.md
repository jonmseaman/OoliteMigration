# Parity findings: entities-player
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## PlayerEntity

<a id="playerentity"></a>
Upstream `src/Core/Entities/PlayerEntity.m` ↔ `Core/Entities/PlayerEntity.cpp` (11911 / 14092 lines)

**Status:** done — 491 rows: 466 ✅ 14 ⚠️ 8 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `PLAYER_DEFAULT_NAME` (89) | `PLAYER_DEFAULT_NAME` `Core/Entities/PlayerEntity.cpp:101` | ✅ |
| `enum { kCommLogTrimThreshold, kCommLogTrimSize }` (91) | `kCommLogTrimThreshold` / `kCommLogTrimSize` `Core/Entities/PlayerEntity.cpp:105` | ✅ |
| `kOOLogBuyMountedOK` / `kOOLogBuyMountedFailed` (97) | inlined literals `"equip.buy.mounted"` / `"equip.buy.mounted.failed"` `Core/Entities/PlayerEntity.cpp:11122` | ➖ |
| `kDeadResetTime` (99) | `kDeadResetTime` `Core/Entities/PlayerEntity.cpp:312` | ✅ |
| `gOOPlayer` (101) | `gOOPlayer` `Core/Entities/PlayerEntity.cpp:416` | ✅ |
| `sBaseMass` (102) | `sBaseMass` `Core/Entities/PlayerEntity.cpp:314` | ✅ |
| `STAGE_TRACKING_BEGIN` / `STAGE_TRACKING_END` / `UPDATE_STAGE` macros (2355) | same macros `Core/Entities/PlayerEntity.cpp:345` | ⚠️ |
| `VELOCITY_CLEANUP_MIN/FULL/RATE` (3346) | same macros `Core/Entities/PlayerEntity.cpp:375` | ✅ |
| `+[PlayerEntity sharedPlayer]` (168) | `sharedPlayer` `Core/Entities/PlayerEntity.cpp:435` | ✅ |
| `-[PlayerEntity setName:]` (176) | `setName` `Core/Entities/PlayerEntity.cpp:544` | ✅ |
| `-[PlayerEntity baseMass]` (181) | `baseMass` `Core/Entities/PlayerEntity.cpp:548` | ✅ |
| `-[PlayerEntity unloadAllCargoPodsForType:toManifest:]` (199) | `unloadAllCargoPodsForType` `Core/Entities/PlayerEntity.cpp:569` | ✅ |
| `-[PlayerEntity unloadCargoPodsForType:amount:]` (223) | `unloadCargoPodsForType` `Core/Entities/PlayerEntity.cpp:597` | ✅ |
| `-[PlayerEntity unloadCargoPods]` (263) | `unloadCargoPods` `Core/Entities/PlayerEntity.cpp:643` | ✅ |
| `-[PlayerEntity createCargoPodWithType:andAmount:]` (282) | `createCargoPodWithType` `Core/Entities/PlayerEntity.cpp:664` | ✅ |
| `-[PlayerEntity loadCargoPodsForType:fromManifest:]` (299) | `loadCargoPodsForType(type, manifest)` `Core/Entities/PlayerEntity.cpp:685` | ✅ |
| `-[PlayerEntity loadCargoPodsForType:amount:]` (359) | `loadCargoPodsForType(type, quantity)` `Core/Entities/PlayerEntity.cpp:746` | ✅ |
| `-[PlayerEntity loadCargoPods]` (410) | `loadCargoPods` `Core/Entities/PlayerEntity.cpp:816` | ✅ |
| `-[PlayerEntity shipCommodityData]` (421) | `getShipCommodityData` `Core/Entities/PlayerEntity.cpp:827` | ✅ |
| `-[PlayerEntity deciCredits]` (426) | `deciCredits` `Core/Entities/PlayerEntity.cpp:831` | ✅ |
| `-[PlayerEntity random_factor]` (431) | `random_factor` `Core/Entities/PlayerEntity.cpp:833` | ✅ |
| `-[PlayerEntity setRandom_factor:]` (436) | `setRandom_factor` `Core/Entities/PlayerEntity.cpp:835` | ✅ |
| `-[PlayerEntity galaxyNumber]` (441) | `galaxyNumber` `Core/Entities/PlayerEntity.cpp:837` | ✅ |
| `-[PlayerEntity galaxy_coordinates]` (446) | `getGalaxy_coordinates` `Core/Entities/PlayerEntity.cpp:839` | ✅ |
| `-[PlayerEntity setGalaxyCoordinates:]` (451) | `setGalaxyCoordinates` `Core/Entities/PlayerEntity.cpp:841` | ✅ |
| `-[PlayerEntity cursor_coordinates]` (457) | `getCursor_coordinates` `Core/Entities/PlayerEntity.cpp:846` | ✅ |
| `-[PlayerEntity chart_centre_coordinates]` (462) | `getChart_centre_coordinates` `Core/Entities/PlayerEntity.cpp:848` | ✅ |
| `-[PlayerEntity chart_zoom]` (467) | `getChart_zoom` `Core/Entities/PlayerEntity.cpp:852` | ✅ |
| `-[PlayerEntity custom_chart_zoom]` (479) | `getCustom_chart_zoom` `Core/Entities/PlayerEntity.cpp:873` | ✅ |
| `-[PlayerEntity setCustomChartZoom:]` (484) | `setCustomChartZoom` `Core/Entities/PlayerEntity.cpp:875` | ✅ |
| `-[PlayerEntity custom_chart_centre_coordinates]` (489) | `getCustom_chart_centre_coordinates` `Core/Entities/PlayerEntity.cpp:879` | ✅ |
| `-[PlayerEntity setCustomChartCentre:]` (494) | `setCustomChartCentre` `Core/Entities/PlayerEntity.cpp:883` | ✅ |
| `-[PlayerEntity adjusted_chart_centre]` (500) | `adjusted_chart_centre` `Core/Entities/PlayerEntity.cpp:888` | ✅ |
| `-[PlayerEntity ANAMode]` (558) | `ANAMode` `Core/Entities/PlayerEntity.cpp:973` | ✅ |
| `-[PlayerEntity systemID]` (563) | `systemID` `Core/Entities/PlayerEntity.cpp:975` | ✅ |
| `-[PlayerEntity setSystemID:]` (568) | `setSystemID` `Core/Entities/PlayerEntity.cpp:977` | ✅ |
| `-[PlayerEntity previousSystemID]` (576) | `previousSystemID` `Core/Entities/PlayerEntity.cpp:988` | ✅ |
| `-[PlayerEntity setPreviousSystemID:]` (581) | `setPreviousSystemID` `Core/Entities/PlayerEntity.cpp:990` | ✅ |
| `-[PlayerEntity targetSystemID]` (586) | `targetSystemID` `Core/Entities/PlayerEntity.cpp:997` | ✅ |
| `-[PlayerEntity setTargetSystemID:]` (591) | `setTargetSystemID` `Core/Entities/PlayerEntity.cpp:999` | ✅ |
| `-[PlayerEntity nextHopTargetSystemID]` (598) | `nextHopTargetSystemID` `Core/Entities/PlayerEntity.cpp:1013` | ✅ |
| `-[PlayerEntity infoSystemID]` (621) | `infoSystemID` `Core/Entities/PlayerEntity.cpp:1038` | ✅ |
| `-[PlayerEntity setInfoSystemID:moveChart:]` (626) | `setInfoSystemID` `Core/Entities/PlayerEntity.cpp:1040` | ✅ |
| `-[PlayerEntity nextInfoSystem]` (653) | `nextInfoSystem` `Core/Entities/PlayerEntity.cpp:1081` | ✅ |
| `-[PlayerEntity previousInfoSystem]` (680) | `previousInfoSystem` `Core/Entities/PlayerEntity.cpp:1109` | ✅ |
| `-[PlayerEntity homeInfoSystem]` (707) | `homeInfoSystem` `Core/Entities/PlayerEntity.cpp:1137` | ✅ |
| `-[PlayerEntity targetInfoSystem]` (713) | `targetInfoSystem` `Core/Entities/PlayerEntity.cpp:1142` | ✅ |
| `-[PlayerEntity infoSystemOnRoute]` (719) | `infoSystemOnRoute` `Core/Entities/PlayerEntity.cpp:1147` | ✅ |
| `-[PlayerEntity wormhole]` (734) | `getWormhole` `Core/Entities/PlayerEntity.cpp:1165` | ✅ |
| `-[PlayerEntity setWormhole:]` (739) | `setWormhole` `Core/Entities/PlayerEntity.cpp:1167` | ✅ |
| `-[PlayerEntity commanderDataDictionary]` (749) | `commanderDataDictionary` `Core/Entities/PlayerEntity.cpp:1177` | ⚠️ |
| `-[PlayerEntity setCommanderDataFromDictionary:]` (1012) | `setCommanderDataFromDictionary` `Core/Entities/PlayerEntity.cpp:1544` | ❌ |
| `-[PlayerEntity init]` (1595) | `PlayerEntity()` `Core/Entities/PlayerEntity.cpp:432` + `newPlayerObject` `Core/Entities/PlayerEntity.cpp:446` | ➖ |
| `-[PlayerEntity deferredInit]` (1601) | `deferredInit` `Core/Entities/PlayerEntity.cpp:455` | ✅ |
| `-[PlayerEntity setUpAndConfirmOK:]` (1639) | `setUpAndConfirmOK(bool)` `Core/Entities/PlayerEntity.cpp:2332` | ✅ |
| `-[PlayerEntity setUpAndConfirmOK:saveGame:]` (1644) | `setUpAndConfirmOK(bool, bool)` `Core/Entities/PlayerEntity.cpp:2336` | ✅ |
| `-[PlayerEntity completeSetUp]` (2022) | `completeSetUp` `Core/Entities/PlayerEntity.cpp:2727` | ✅ |
| `-[PlayerEntity completeSetUpAndSetTarget:]` (2027) | `completeSetUpAndSetTarget` `Core/Entities/PlayerEntity.cpp:2729` | ✅ |
| `-[PlayerEntity startUpComplete]` (2043) | `startUpComplete` `Core/Entities/PlayerEntity.cpp:2755` | ✅ |
| `-[PlayerEntity setUpShipFromDictionary:]` (2050) | `setUpShipFromDictionary` `Core/Entities/PlayerEntity.cpp:2762` | ✅ |
| `-[PlayerEntity dealloc]` (2145) | `willDealloc` `Core/Entities/PlayerEntity.cpp:501` + `~PlayerEntity` `Core/Entities/PlayerEntity.cpp:433` | ➖ |
| `-[PlayerEntity sessionID]` (2231) | `sessionID` `Core/Entities/PlayerEntity.cpp:2871` | ✅ |
| `-[PlayerEntity warnAboutHostiles]` (2237) | `warnAboutHostiles` `Core/Entities/PlayerEntity.cpp:2876` | ✅ |
| `-[PlayerEntity canCollide]` (2242) | `canCollide` `Core/Entities/PlayerEntity.cpp:2878` | ✅ |
| `-[PlayerEntity compareZeroDistance:]` (2257) | `compareZeroDistance` `Core/Entities/PlayerEntity.cpp:2894` | ✅ |
| `-[PlayerEntity validForAddToUniverse]` (2262) | `validForAddToUniverse` `Core/Entities/PlayerEntity.cpp:2898` | ✅ |
| `-[PlayerEntity lookingAtSunWithThresholdAngleCos:]` (2267) | `lookingAtSunWithThresholdAngleCos` `Core/Entities/PlayerEntity.cpp:2900` | ✅ |
| `-[PlayerEntity insideAtmosphereFraction]` (2342) | `insideAtmosphereFraction` `Core/Entities/PlayerEntity.cpp:2987` | ✅ |
| `-[PlayerEntity update:]` (2380) | `update` `Core/Entities/PlayerEntity.cpp:3001` (calls `getPollControls`) | ✅ |
| `-[PlayerEntity doBookkeeping:]` (2461) | `doBookkeeping` `Core/Entities/PlayerEntity.cpp:3098` | ✅ |
| `-[PlayerEntity updateMovementFlags]` (2885) | `updateMovementFlags` `Core/Entities/PlayerEntity.cpp:3576` | ✅ |
| `-[PlayerEntity updateAlertConditionForNearbyEntities]` (2893) | `updateAlertConditionForNearbyEntities` `Core/Entities/PlayerEntity.cpp:3586` | ✅ |
| `-[PlayerEntity setMaxFlightPitch:]` (2996) | `setMaxFlightPitch` `Core/Entities/PlayerEntity.cpp:3698` | ✅ |
| `-[PlayerEntity setMaxFlightRoll:]` (3002) | `setMaxFlightRoll` `Core/Entities/PlayerEntity.cpp:3703` | ✅ |
| `-[PlayerEntity setMaxFlightYaw:]` (3008) | `setMaxFlightYaw` `Core/Entities/PlayerEntity.cpp:3708` | ✅ |
| `-[PlayerEntity checkEntityForMassLock:withScanClass:]` (3014) | `checkEntityForMassLock` `Core/Entities/PlayerEntity.cpp:3713` | ✅ |
| `-[PlayerEntity updateAlertCondition]` (3068) | `updateAlertCondition` `Core/Entities/PlayerEntity.cpp:3771` | ✅ |
| `-[PlayerEntity updateFuelScoops:]` (3099) | `updateFuelScoops` `Core/Entities/PlayerEntity.cpp:3816` | ✅ |
| `-[PlayerEntity updateClocks:]` (3110) | `updateClocks` `Core/Entities/PlayerEntity.cpp:3826` | ✅ |
| `-[PlayerEntity checkScriptsIfAppropriate]` (3160) | `checkScriptsIfAppropriate` `Core/Entities/PlayerEntity.cpp:3881` | ✅ |
| `-[PlayerEntity updateTrumbles:]` (3211) | `updateTrumbles` `Core/Entities/PlayerEntity.cpp:3930` | ✅ |
| `-[PlayerEntity performAutopilotUpdates:]` (3222) | `performAutopilotUpdates` `Core/Entities/PlayerEntity.cpp:3940` | ✅ |
| `-[PlayerEntity performDockingRequest:]` (3229) | `performDockingRequest` `Core/Entities/PlayerEntity.cpp:3946` | ✅ |
| `-[PlayerEntity requestDockingClearance:]` (3251) | `requestDockingClearance` `Core/Entities/PlayerEntity.cpp:3969` | ✅ |
| `-[PlayerEntity cancelDockingRequest:]` (3258) | `cancelDockingRequest` `Core/Entities/PlayerEntity.cpp:3976` | ✅ |
| `-[PlayerEntity engageAutopilotToStation:]` (3279) | `engageAutopilotToStation` `Core/Entities/PlayerEntity.cpp:3998` | ✅ |
| `-[PlayerEntity disengageAutopilot]` (3314) | `disengageAutopilot` `Core/Entities/PlayerEntity.cpp:4030` | ✅ |
| `-[PlayerEntity resetAutopilotAI]` (3333) | `resetAutopilotAI` `Core/Entities/PlayerEntity.cpp:4052` | ✅ |
| `-[PlayerEntity hyperspeedFactor]` (3351) | `getHyperspeedFactor` `Core/Entities/PlayerEntity.cpp:4069` | ✅ |
| `-[PlayerEntity injectorsEngaged]` (3357) | `injectorsEngaged` `Core/Entities/PlayerEntity.cpp:4072` | ✅ |
| `-[PlayerEntity hyperspeedEngaged]` (3362) | `hyperspeedEngaged` `Core/Entities/PlayerEntity.cpp:4074` | ✅ |
| `-[PlayerEntity performInFlightUpdates:]` (3367) | `performInFlightUpdates` `Core/Entities/PlayerEntity.cpp:4076` | ✅ |
| `-[PlayerEntity performWitchspaceCountdownUpdates:]` (3422) | `performWitchspaceCountdownUpdates` `Core/Entities/PlayerEntity.cpp:4135` | ✅ |
| `-[PlayerEntity performWitchspaceExitUpdates:]` (3479) | `performWitchspaceExitUpdates` `Core/Entities/PlayerEntity.cpp:4204` | ✅ |
| `-[PlayerEntity performLaunchingUpdates:]` (3519) | `performLaunchingUpdates` `Core/Entities/PlayerEntity.cpp:4253` | ✅ |
| `-[PlayerEntity performDockingUpdates:]` (3539) | `performDockingUpdates` `Core/Entities/PlayerEntity.cpp:4277` | ✅ |
| `-[PlayerEntity performDeadUpdates:]` (3551) | `performDeadUpdates` `Core/Entities/PlayerEntity.cpp:4289` | ✅ |
| `-[PlayerEntity gameOverFadeToBW]` (3566) | `gameOverFadeToBW` `Core/Entities/PlayerEntity.cpp:4305` | ✅ |
| `-[PlayerEntity isValidTarget:]` (3595) | `isValidTarget` `Core/Entities/PlayerEntity.cpp:4349` | ✅ |
| `-[PlayerEntity showGameOver]` (3630) | `showGameOver` `Core/Entities/PlayerEntity.cpp:4392` | ✅ |
| `-[PlayerEntity showShipModelWithKey:shipData:personality:factorX:factorY:factorZ:inContext:]` (3646) | `showShipModelWithKey` `Core/Entities/PlayerEntity.cpp:4414` | ✅ |
| `-[PlayerEntity updateTargeting]` (3699) | `updateTargeting` `Core/Entities/PlayerEntity.cpp:4485` | ✅ |
| `-[PlayerEntity orientationChanged]` (3803) | `orientationChanged` `Core/Entities/PlayerEntity.cpp:4635` | ✅ |
| `-[PlayerEntity applyAttitudeChanges:]` (3814) | `applyAttitudeChanges` `Core/Entities/PlayerEntity.cpp:4646` | ✅ |
| `-[PlayerEntity applyRoll:andClimb:]` (3820) | `applyRoll` `Core/Entities/PlayerEntity.cpp:4651` | ✅ |
| `-[PlayerEntity applyYaw:]` (3849) | `applyYaw` `Core/Entities/PlayerEntity.cpp:4676` | ✅ |
| `-[PlayerEntity drawRotationMatrix]` (3856) | `drawRotationMatrix` `Core/Entities/PlayerEntity.cpp:4682` | ✅ |
| `-[PlayerEntity drawTransformationMatrix]` (3861) | `drawTransformationMatrix` `Core/Entities/PlayerEntity.cpp:4684` | ✅ |
| `-[PlayerEntity normalOrientation]` (3868) | `normalOrientation` `Core/Entities/PlayerEntity.cpp:4690` | ✅ |
| `-[PlayerEntity setNormalOrientation:]` (3873) | `setNormalOrientation` `Core/Entities/PlayerEntity.cpp:4695` | ✅ |
| `-[PlayerEntity moveForward:]` (3878) | `moveForward` `Core/Entities/PlayerEntity.cpp:4699` | ✅ |
| `-[PlayerEntity breakPatternPosition]` (3884) | `breakPatternPosition` `Core/Entities/PlayerEntity.cpp:4706` | ✅ |
| `-[PlayerEntity viewpointOffset]` (3889) | `viewpointOffset` `Core/Entities/PlayerEntity.cpp:4712` | ✅ |
| `-[PlayerEntity viewpointOffsetAft]` (3916) | `viewpointOffsetAft` `Core/Entities/PlayerEntity.cpp:4738` | ✅ |
| `-[PlayerEntity viewpointOffsetForward]` (3921) | `viewpointOffsetForward` `Core/Entities/PlayerEntity.cpp:4740` | ✅ |
| `-[PlayerEntity viewpointOffsetPort]` (3926) | `viewpointOffsetPort` `Core/Entities/PlayerEntity.cpp:4742` | ✅ |
| `-[PlayerEntity viewpointOffsetStarboard]` (3931) | `viewpointOffsetStarboard` `Core/Entities/PlayerEntity.cpp:4744` | ✅ |
| `-[PlayerEntity viewpointPosition]` (3938) | `viewpointPosition` `Core/Entities/PlayerEntity.cpp:4748` | ✅ |
| `-[PlayerEntity drawImmediate:translucent:]` (3962) | `drawImmediate` `Core/Entities/PlayerEntity.cpp:4771` | ✅ |
| `-[PlayerEntity setMassLockable:]` (3979) | `setMassLockable` `Core/Entities/PlayerEntity.cpp:4786` | ✅ |
| `-[PlayerEntity massLockable]` (3985) | `getMassLockable` `Core/Entities/PlayerEntity.cpp:4791` | ✅ |
| `-[PlayerEntity massLocked]` (3990) | `massLocked` `Core/Entities/PlayerEntity.cpp:4793` | ✅ |
| `-[PlayerEntity atHyperspeed]` (3995) | `atHyperspeed` `Core/Entities/PlayerEntity.cpp:4797` | ✅ |
| `-[PlayerEntity occlusionLevel]` (4000) | `occlusionLevel` `Core/Entities/PlayerEntity.cpp:4799` | ✅ |
| `-[PlayerEntity setOcclusionLevel:]` (4005) | `setOcclusionLevel` `Core/Entities/PlayerEntity.cpp:4801` | ✅ |
| `-[PlayerEntity setDockedAtMainStation]` (4010) | `setDockedAtMainStation` `Core/Entities/PlayerEntity.cpp:4803` | ✅ |
| `-[PlayerEntity dockedStation]` (4017) | `dockedStation` `Core/Entities/PlayerEntity.cpp:4808` | ✅ |
| `-[PlayerEntity setDockedStation:]` (4022) | `setDockedStation` `Core/Entities/PlayerEntity.cpp:4812` | ✅ |
| `-[PlayerEntity setTargetDockStationTo:]` (4028) | `setTargetDockStationTo` `Core/Entities/PlayerEntity.cpp:4816` | ✅ |
| `-[PlayerEntity getTargetDockStation]` (4033) | `getTargetDockStation` `Core/Entities/PlayerEntity.cpp:4820` | ✅ |
| `-[PlayerEntity hud]` (4038) | `getHud` `Core/Entities/PlayerEntity.cpp:4824` | ✅ |
| `-[PlayerEntity resetHud]` (4043) | `resetHud` `Core/Entities/PlayerEntity.cpp:4826` | ✅ |
| `-[PlayerEntity switchHudTo:]` (4052) | `switchHudTo` `Core/Entities/PlayerEntity.cpp:4835` | ✅ |
| `-[PlayerEntity dialCustomFloat:]` (4112) | `dialCustomFloat` `Core/Entities/PlayerEntity.cpp:4898` | ✅ |
| `-[PlayerEntity dialCustomString:]` (4117) | `dialCustomString` `Core/Entities/PlayerEntity.cpp:4904` | ✅ |
| `-[PlayerEntity dialCustomColor:]` (4122) | `dialCustomColor` `Core/Entities/PlayerEntity.cpp:4910` | ✅ |
| `-[PlayerEntity setDialCustom:forKey:]` (4127) | `setDialCustom` `Core/Entities/PlayerEntity.cpp:4917` | ⚠️ |
| `-[PlayerEntity setShowDemoShips:]` (4132) | `setShowDemoShips` `Core/Entities/PlayerEntity.cpp:4924` | ✅ |
| `-[PlayerEntity showDemoShips]` (4137) | `getShowDemoShips` `Core/Entities/PlayerEntity.cpp:4926` | ✅ |
| `-[PlayerEntity maxForwardShieldLevel]` (4142) | `maxForwardShieldLevel` `Core/Entities/PlayerEntity.cpp:4928` | ✅ |
| `-[PlayerEntity maxAftShieldLevel]` (4147) | `maxAftShieldLevel` `Core/Entities/PlayerEntity.cpp:4930` | ✅ |
| `-[PlayerEntity forwardShieldRechargeRate]` (4152) | `forwardShieldRechargeRate` `Core/Entities/PlayerEntity.cpp:4932` | ✅ |
| `-[PlayerEntity aftShieldRechargeRate]` (4157) | `aftShieldRechargeRate` `Core/Entities/PlayerEntity.cpp:4936` | ✅ |
| `-[PlayerEntity setMaxForwardShieldLevel:]` (4162) | `setMaxForwardShieldLevel` `Core/Entities/PlayerEntity.cpp:4938` | ✅ |
| `-[PlayerEntity setMaxAftShieldLevel:]` (4167) | `setMaxAftShieldLevel` `Core/Entities/PlayerEntity.cpp:4942` | ✅ |
| `-[PlayerEntity setForwardShieldRechargeRate:]` (4172) | `setForwardShieldRechargeRate` `Core/Entities/PlayerEntity.cpp:4946` | ✅ |
| `-[PlayerEntity setAftShieldRechargeRate:]` (4177) | `setAftShieldRechargeRate` `Core/Entities/PlayerEntity.cpp:4950` | ✅ |
| `-[PlayerEntity forwardShieldLevel]` (4182) | `forwardShieldLevel` `Core/Entities/PlayerEntity.cpp:4954` | ✅ |
| `-[PlayerEntity aftShieldLevel]` (4187) | `aftShieldLevel` `Core/Entities/PlayerEntity.cpp:4956` | ✅ |
| `-[PlayerEntity setForwardShieldLevel:]` (4192) | `setForwardShieldLevel` `Core/Entities/PlayerEntity.cpp:4958` | ✅ |
| `-[PlayerEntity setAftShieldLevel:]` (4197) | `setAftShieldLevel` `Core/Entities/PlayerEntity.cpp:4962` | ✅ |
| `-[PlayerEntity keyConfig]` (4202) | `keyConfig` `Core/Entities/PlayerEntity.cpp:4966` | ✅ |
| `-[PlayerEntity isMouseControlOn]` (4208) | `isMouseControlOn` `Core/Entities/PlayerEntity.cpp:4971` | ✅ |
| `-[PlayerEntity dialRoll]` (4213) | `dialRoll` `Core/Entities/PlayerEntity.cpp:4973` | ✅ |
| `-[PlayerEntity dialPitch]` (4223) | `dialPitch` `Core/Entities/PlayerEntity.cpp:4980` | ✅ |
| `-[PlayerEntity dialYaw]` (4233) | `dialYaw` `Core/Entities/PlayerEntity.cpp:4987` | ✅ |
| `-[PlayerEntity dialSpeed]` (4243) | `dialSpeed` `Core/Entities/PlayerEntity.cpp:4994` | ✅ |
| `-[PlayerEntity dialHyperSpeed]` (4249) | `dialHyperSpeed` `Core/Entities/PlayerEntity.cpp:4999` | ✅ |
| `-[PlayerEntity dialForwardShield]` (4254) | `dialForwardShield` `Core/Entities/PlayerEntity.cpp:5001` | ✅ |
| `-[PlayerEntity dialAftShield]` (4263) | `dialAftShield` `Core/Entities/PlayerEntity.cpp:5013` | ✅ |
| `-[PlayerEntity dialEnergy]` (4272) | `dialEnergy` `Core/Entities/PlayerEntity.cpp:5021` | ✅ |
| `-[PlayerEntity dialMaxEnergy]` (4278) | `dialMaxEnergy` `Core/Entities/PlayerEntity.cpp:5026` | ✅ |
| `-[PlayerEntity dialFuel]` (4283) | `dialFuel` `Core/Entities/PlayerEntity.cpp:5028` | ✅ |
| `-[PlayerEntity dialHyperRange]` (4292) | `dialHyperRange` `Core/Entities/PlayerEntity.cpp:5034` | ✅ |
| `-[PlayerEntity laserHeatLevel]` (4299) | `laserHeatLevel` `Core/Entities/PlayerEntity.cpp:5041` | ✅ |
| `-[PlayerEntity laserHeatLevelAft]` (4305) | `laserHeatLevelAft` `Core/Entities/PlayerEntity.cpp:5046` | ✅ |
| `-[PlayerEntity laserHeatLevelForward]` (4311) | `laserHeatLevelForward` `Core/Entities/PlayerEntity.cpp:5052` | ✅ |
| `-[PlayerEntity laserHeatLevelPort]` (4318) | `laserHeatLevelPort` `Core/Entities/PlayerEntity.cpp:5059` | ✅ |
| `-[PlayerEntity laserHeatLevelStarboard]` (4324) | `laserHeatLevelStarboard` `Core/Entities/PlayerEntity.cpp:5064` | ✅ |
| `-[PlayerEntity dialAltitude]` (4330) | `dialAltitude` `Core/Entities/PlayerEntity.cpp:5069` | ✅ |
| `-[PlayerEntity clockTime]` (4349) | `clockTime` `Core/Entities/PlayerEntity.cpp:5085` | ✅ |
| `-[PlayerEntity clockTimeAdjusted]` (4354) | `clockTimeAdjusted` `Core/Entities/PlayerEntity.cpp:5087` | ✅ |
| `-[PlayerEntity clockAdjusting]` (4359) | `clockAdjusting` `Core/Entities/PlayerEntity.cpp:5091` | ✅ |
| `-[PlayerEntity addToAdjustTime:]` (4364) | `addToAdjustTime` `Core/Entities/PlayerEntity.cpp:5093` | ✅ |
| `-[PlayerEntity escapePodRescueTime]` (4369) | `escapePodRescueTime` `Core/Entities/PlayerEntity.cpp:5097` | ✅ |
| `-[PlayerEntity setEscapePodRescueTime:]` (4374) | `setEscapePodRescueTime` `Core/Entities/PlayerEntity.cpp:5099` | ✅ |
| `-[PlayerEntity dial_clock]` (4379) | `dial_clock` `Core/Entities/PlayerEntity.cpp:5103` | ✅ |
| `-[PlayerEntity dial_clock_adjusted]` (4384) | `dial_clock_adjusted` `Core/Entities/PlayerEntity.cpp:5107` | ✅ |
| `-[PlayerEntity dial_fpsinfo]` (4389) | `dial_fpsinfo` `Core/Entities/PlayerEntity.cpp:5111` | ✅ |
| `-[PlayerEntity dial_objinfo]` (4395) | `dial_objinfo` `Core/Entities/PlayerEntity.cpp:5116` | ✅ |
| `-[PlayerEntity countMissiles]` (4405) | `countMissiles` `Core/Entities/PlayerEntity.cpp:5129` | ✅ |
| `-[PlayerEntity dialMissileStatus]` (4416) | `dialMissileStatus` `Core/Entities/PlayerEntity.cpp:5138` | ✅ |
| `-[PlayerEntity canScoop:]` (4430) | `canScoop` `Core/Entities/PlayerEntity.cpp:5154` | ✅ |
| `-[PlayerEntity dialFuelScoopStatus]` (4437) | `dialFuelScoopStatus` `Core/Entities/PlayerEntity.cpp:5159` | ✅ |
| `-[PlayerEntity fuelLeakRate]` (4452) | `fuelLeakRate` `Core/Entities/PlayerEntity.cpp:5176` | ✅ |
| `-[PlayerEntity setFuelLeakRate:]` (4457) | `setFuelLeakRate` `Core/Entities/PlayerEntity.cpp:5178` | ✅ |
| `-[PlayerEntity commLog]` (4462) | `getCommLog` `Core/Entities/PlayerEntity.cpp:5182` | ✅ |
| `-[PlayerEntity roleWeights]` (4478) | `getRoleWeights` `Core/Entities/PlayerEntity.cpp:5195` | ✅ |
| `-[PlayerEntity addRoleForAggression:]` (4483) | `addRoleForAggression` `Core/Entities/PlayerEntity.cpp:5197` | ✅ |
| `-[PlayerEntity addRoleForMining]` (4510) | `addRoleForMining` `Core/Entities/PlayerEntity.cpp:5234` | ✅ |
| `-[PlayerEntity addRoleToPlayer:]` (4522) | `addRoleToPlayer(role)` `Core/Entities/PlayerEntity.cpp:5246` | ✅ |
| `-[PlayerEntity addRoleToPlayer:inSlot:]` (4528) | `addRoleToPlayer(role, slot)` `Core/Entities/PlayerEntity.cpp:5251` | ✅ |
| `-[PlayerEntity clearRoleFromPlayer:]` (4540) | `clearRoleFromPlayer` `Core/Entities/PlayerEntity.cpp:5262` | ✅ |
| `-[PlayerEntity clearRolesFromPlayer:]` (4553) | `clearRolesFromPlayer` `Core/Entities/PlayerEntity.cpp:5274` | ✅ |
| `-[PlayerEntity maxPlayerRoles]` (4563) | `maxPlayerRoles` `Core/Entities/PlayerEntity.cpp:5283` | ✅ |
| `-[PlayerEntity updateSystemMemory]` (4574) | `updateSystemMemory` `Core/Entities/PlayerEntity.cpp:5293` | ✅ |
| `-[PlayerEntity compassTarget]` (4594) | `getCompassTargetEntity` `Core/Entities/PlayerEntity.cpp:5315` | ✅ |
| `-[PlayerEntity setCompassTarget:]` (4604) | `setCompassTargetEntity` `Core/Entities/PlayerEntity.cpp:5324` | ✅ |
| `-[PlayerEntity validateCompassTarget]` (4610) | `validateCompassTarget` `Core/Entities/PlayerEntity.cpp:5329` | ✅ |
| `-[PlayerEntity compassTargetLabel]` (4668) | `compassTargetLabel` `Core/Entities/PlayerEntity.cpp:5399` | ✅ |
| `-[PlayerEntity compassMode]` (4694) | `getCompassMode` `Core/Entities/PlayerEntity.cpp:5433` | ✅ |
| `-[PlayerEntity setCompassMode:]` (4699) | `setCompassMode` `Core/Entities/PlayerEntity.cpp:5435` | ✅ |
| `-[PlayerEntity setPrevCompassMode]` (4704) | `setPrevCompassMode` `Core/Entities/PlayerEntity.cpp:5437` | ✅ |
| `-[PlayerEntity setNextCompassMode]` (4761) | `setNextCompassMode` `Core/Entities/PlayerEntity.cpp:5494` | ✅ |
| `-[PlayerEntity activeMissile]` (4816) | `getActiveMissile` `Core/Entities/PlayerEntity.cpp:5550` | ✅ |
| `-[PlayerEntity setActiveMissile:]` (4821) | `setActiveMissile` `Core/Entities/PlayerEntity.cpp:5552` | ✅ |
| `-[PlayerEntity dialMaxMissiles]` (4826) | `dialMaxMissiles` `Core/Entities/PlayerEntity.cpp:5556` | ✅ |
| `-[PlayerEntity dialIdentEngaged]` (4831) | `dialIdentEngaged` `Core/Entities/PlayerEntity.cpp:5558` | ✅ |
| `-[PlayerEntity setDialIdentEngaged:]` (4836) | `setDialIdentEngaged` `Core/Entities/PlayerEntity.cpp:5560` | ✅ |
| `-[PlayerEntity specialCargo]` (4841) | `getSpecialCargo` `Core/Entities/PlayerEntity.cpp:5564` | ✅ |
| `-[PlayerEntity dialTargetName]` (4846) | `dialTargetName` `Core/Entities/PlayerEntity.cpp:5568` | ✅ |
| `-[PlayerEntity multiFunctionDisplayList]` (4865) | `multiFunctionDisplayList` `Core/Entities/PlayerEntity.cpp:5591` | ✅ |
| `-[PlayerEntity multiFunctionText:]` (4870) | `multiFunctionText` `Core/Entities/PlayerEntity.cpp:5596` | ✅ |
| `-[PlayerEntity setMultiFunctionText:forKey:]` (4880) | `setMultiFunctionText` `Core/Entities/PlayerEntity.cpp:5607` | ✅ |
| `-[PlayerEntity setMultiFunctionDisplay:toKey:]` (4894) | `setMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5621` | ✅ |
| `-[PlayerEntity cycleNextMultiFunctionDisplay:]` (4916) | `cycleNextMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5645` | ⚠️ |
| `-[PlayerEntity cyclePreviousMultiFunctionDisplay:]` (4946) | `cyclePreviousMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5683` | ⚠️ |
| `-[PlayerEntity selectNextMultiFunctionDisplay]` (4976) | `selectNextMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5721` | ✅ |
| `-[PlayerEntity selectPreviousMultiFunctionDisplay]` (4988) | `selectPreviousMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5733` | ✅ |
| `-[PlayerEntity activeMFD]` (5004) | `getActiveMFD` `Core/Entities/PlayerEntity.cpp:5749` | ✅ |
| `-[PlayerEntity missileForPylon:]` (5009) | `missileForPylon` `Core/Entities/PlayerEntity.cpp:5751` | ✅ |
| `-[PlayerEntity safeAllMissiles]` (5016) | `safeAllMissiles` `Core/Entities/PlayerEntity.cpp:5756` | ✅ |
| `-[PlayerEntity tidyMissilePylons]` (5028) | `tidyMissilePylons` `Core/Entities/PlayerEntity.cpp:5771` | ✅ |
| `-[PlayerEntity selectNextMissile]` (5050) | `selectNextMissile` `Core/Entities/PlayerEntity.cpp:5804` | ✅ |
| `-[PlayerEntity clearAlertFlags]` (5096) | `clearAlertFlags` `Core/Entities/PlayerEntity.cpp:5869` | ✅ |
| `-[PlayerEntity alertFlags]` (5101) | `getAlertFlags` `Core/Entities/PlayerEntity.cpp:5871` | ✅ |
| `-[PlayerEntity setAlertFlag:to:]` (5106) | `setAlertFlag` `Core/Entities/PlayerEntity.cpp:5873` | ✅ |
| `-[PlayerEntity realAlertCondition]` (5117) | `realAlertCondition` `Core/Entities/PlayerEntity.cpp:5882` | ✅ |
| `-[PlayerEntity alertCondition]` (5122) | `getAlertCondition` `Core/Entities/PlayerEntity.cpp:5889` (virtual `alertCondition()` forwards, :531) | ✅ |
| `-[PlayerEntity fleeingStatus]` (5146) | `fleeingStatus` `Core/Entities/PlayerEntity.cpp:5913` | ✅ |
| `-[PlayerEntity interpretAIMessage:]` (5153) | `interpretAIMessage` `Core/Entities/PlayerEntity.cpp:5915` | ✅ |
| `-[PlayerEntity mountMissile:]` (5203) | `mountMissile` `Core/Entities/PlayerEntity.cpp:5971` | ✅ |
| `-[PlayerEntity mountMissileWithRole:]` (5223) | `mountMissileWithRole` `Core/Entities/PlayerEntity.cpp:5995` | ✅ |
| `-[PlayerEntity fireMissile]` (5230) | `fireMissile` `Core/Entities/PlayerEntity.cpp:6001` | ✅ |
| `-[PlayerEntity launchMine:]` (5282) | `launchMine` `Core/Entities/PlayerEntity.cpp:6057` | ✅ |
| `-[PlayerEntity assignToActivePylon:]` (5302) | `assignToActivePylon` `Core/Entities/PlayerEntity.cpp:6078` | ✅ |
| `-[PlayerEntity activateCloakingDevice]` (5342) | `activateCloakingDevice` `Core/Entities/PlayerEntity.cpp:6118` | ✅ |
| `-[PlayerEntity deactivateCloakingDevice]` (5359) | `deactivateCloakingDevice` `Core/Entities/PlayerEntity.cpp:6134` | ✅ |
| `-[PlayerEntity scannerFuzziness]` (5372) | `scannerFuzziness` `Core/Entities/PlayerEntity.cpp:6145` | ✅ |
| `-[PlayerEntity noticeECM]` (5388) | `noticeECM` `Core/Entities/PlayerEntity.cpp:6162` | ✅ |
| `-[PlayerEntity fireECM]` (5393) | `fireECM` `Core/Entities/PlayerEntity.cpp:6166` | ✅ |
| `-[PlayerEntity installedEnergyUnitType]` (5404) | `installedEnergyUnitType` `Core/Entities/PlayerEntity.cpp:6176` | ✅ |
| `-[PlayerEntity energyUnitType]` (5413) | `energyUnitType` `Core/Entities/PlayerEntity.cpp:6184` | ✅ |
| `-[PlayerEntity currentWeaponStats]` (5426) | `currentWeaponStats` `Core/Entities/PlayerEntity.cpp:6196` | ✅ |
| `-[PlayerEntity weaponsOnline]` (5435) | `weaponsOnline` `Core/Entities/PlayerEntity.cpp:6206` | ✅ |
| `-[PlayerEntity setWeaponsOnline:]` (5440) | `setWeaponsOnline` `Core/Entities/PlayerEntity.cpp:6208` | ✅ |
| `-[PlayerEntity currentLaserOffset]` (5447) | `currentLaserOffset` `Core/Entities/PlayerEntity.cpp:6213` | ✅ |
| `-[PlayerEntity fireMainWeapon]` (5452) | `fireMainWeapon` `Core/Entities/PlayerEntity.cpp:6217` | ❌ |
| `-[PlayerEntity weaponForFacing:]` (5529) | `weaponForFacing` `Core/Entities/PlayerEntity.cpp:6302` | ✅ |
| `-[PlayerEntity currentWeapon]` (5550) | `currentWeapon` `Core/Entities/PlayerEntity.cpp:6322` | ✅ |
| `-[PlayerEntity doesHitLine:v1:hitEntity:]` (5558) | `PlayerEntity::doesHitLine` Core/Entities/PlayerEntity.cpp:6332 | ✅ |
| `-[PlayerEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (5599) | `PlayerEntity::takeEnergyDamage` Core/Entities/PlayerEntity.cpp:6377 | ✅ |
| `-[PlayerEntity takeScrapeDamage:from:]` (5701) | `PlayerEntity::takeScrapeDamage` Core/Entities/PlayerEntity.cpp:6490 | ✅ |
| `-[PlayerEntity takeHeatDamage:]` (5755) | `PlayerEntity::takeHeatDamage` Core/Entities/PlayerEntity.cpp:6546 | ✅ |
| `-[PlayerEntity createDoppelganger]` (5785) | `PlayerEntity::createDoppelganger` Core/Entities/PlayerEntity.cpp:6574 | ✅ |
| `-[PlayerEntity launchEscapeCapsule]` (5806) | `PlayerEntity::launchEscapeCapsule` Core/Entities/PlayerEntity.cpp:6601 | ✅ |
| `-[PlayerEntity dumpCargo]` (5928) | `PlayerEntity::dumpCargo` Core/Entities/PlayerEntity.cpp:6740 | ✅ |
| `-[PlayerEntity rotateCargo]` (5944) | `PlayerEntity::rotateCargo` Core/Entities/PlayerEntity.cpp:6769 | ✅ |
| `-[PlayerEntity setBounty:]` (5982) | `PlayerEntity::setBounty(OOCreditsQuantity)` Core/Entities/PlayerEntity.cpp:6825 | ✅ |
| `-[PlayerEntity setBounty:withReason:]` (5987) | `PlayerEntity::setBounty(amount, OOLegalStatusReason)` Core/Entities/PlayerEntity.cpp:6829 | ✅ |
| `-[PlayerEntity setBounty:withReasonAsString:]` (5993) | `PlayerEntity::setBounty(amount, const std::string&)` Core/Entities/PlayerEntity.cpp:6834 | ✅ |
| `-[PlayerEntity bounty]` (6009) | `PlayerEntity::getBounty` Core/Entities/PlayerEntity.cpp:6856 | ✅ |
| `-[PlayerEntity legalStatus]` (6014) | `PlayerEntity::getLegalStatus` Core/Entities/PlayerEntity.cpp:6858 | ✅ |
| `-[PlayerEntity markAsOffender:]` (6019) | `PlayerEntity::markAsOffender(int)` Core/Entities/PlayerEntity.cpp:6860 | ✅ |
| `-[PlayerEntity markAsOffender:withReason:]` (6024) | `PlayerEntity::markAsOffender(int, OOLegalStatusReason)` Core/Entities/PlayerEntity.cpp:6864 | ✅ |
| `-[PlayerEntity collectBountyFor:]` (6042) | `PlayerEntity::collectBountyFor` Core/Entities/PlayerEntity.cpp:6883 | ✅ |
| `-[PlayerEntity takeInternalDamage]` (6097) | `PlayerEntity::takeInternalDamage` Core/Entities/PlayerEntity.cpp:6947 | ✅ |
| `-[PlayerEntity getDestroyedBy:damageType:]` (6187) | `PlayerEntity::getDestroyedBy` Core/Entities/PlayerEntity.cpp:7051 | ✅ |
| `-[PlayerEntity loseTargetStatus]` (6225) | `PlayerEntity::loseTargetStatus` Core/Entities/PlayerEntity.cpp:7098 | ✅ |
| `-[PlayerEntity endScenario:]` (6249) | `PlayerEntity::endScenario` Core/Entities/PlayerEntity.cpp:7122 | ✅ |
| `-[PlayerEntity enterDock:]` (6258) | `PlayerEntity::enterDock` Core/Entities/PlayerEntity.cpp:7130 | ✅ |
| `-[PlayerEntity docked]` (6297) | `PlayerEntity::docked` Core/Entities/PlayerEntity.cpp:7173 | ✅ |
| `-[PlayerEntity leaveDock:]` (6392) | `PlayerEntity::leaveDock` Core/Entities/PlayerEntity.cpp:7293 | ✅ |
| `-[PlayerEntity witchStart]` (6488) | `PlayerEntity::witchStart` Core/Entities/PlayerEntity.cpp:7399 | ✅ |
| `-[PlayerEntity witchEnd]` (6531) | `PlayerEntity::witchEnd` Core/Entities/PlayerEntity.cpp:7450 | ✅ |
| `-[PlayerEntity witchJumpChecklist:]` (6544) | `PlayerEntity::witchJumpChecklist` Core/Entities/PlayerEntity.cpp:7468 | ✅ |
| `-[PlayerEntity setJumpType:]` (6615) | `PlayerEntity::setJumpType` Core/Entities/PlayerEntity.cpp:7554 | ✅ |
| `-[PlayerEntity hyperspaceJumpDistance]` (6624) | `PlayerEntity::hyperspaceJumpDistance` Core/Entities/PlayerEntity.cpp:7562 | ✅ |
| `-[PlayerEntity fuelRequiredForJump]` (6630) | `PlayerEntity::fuelRequiredForJump` Core/Entities/PlayerEntity.cpp:7573 | ✅ |
| `-[PlayerEntity hasSufficientFuelForJump]` (6635) | `PlayerEntity::hasSufficientFuelForJump` Core/Entities/PlayerEntity.cpp:7577 | ✅ |
| `-[PlayerEntity noteCompassLostTarget]` (6640) | `PlayerEntity::noteCompassLostTarget` Core/Entities/PlayerEntity.cpp:7581 | ✅ |
| `-[PlayerEntity enterGalacticWitchspace]` (6653) | `PlayerEntity::enterGalacticWitchspace` Core/Entities/PlayerEntity.cpp:7595 | ✅ |
| `-[PlayerEntity enterWormhole:]` (6745) | `PlayerEntity::enterWormhole` Core/Entities/PlayerEntity.cpp:7708 | ✅ |
| `-[PlayerEntity enterWitchspace]` (6772) | `PlayerEntity::enterWitchspace` Core/Entities/PlayerEntity.cpp:7748 | ✅ |
| `-[PlayerEntity witchJumpTo:misjump:]` (6861) | `PlayerEntity::witchJumpTo` Core/Entities/PlayerEntity.cpp:7855 | ✅ |
| `-[PlayerEntity leaveWitchspace]` (6913) | `PlayerEntity::leaveWitchspace` Core/Entities/PlayerEntity.cpp:7921 | ✅ |
| `-[PlayerEntity setGuiToStatusScreen]` (7004) | `PlayerEntity::setGuiToStatusScreen` Core/Entities/PlayerEntity.cpp:8032 | ✅ |
| `-[PlayerEntity equipmentList]` (7144) | `PlayerEntity::equipmentList` Core/Entities/PlayerEntity.cpp:8220 | ✅ |
| `-[PlayerEntity primedEquipmentCount]` (7243) | `PlayerEntity::primedEquipmentCount` Core/Entities/PlayerEntity.cpp:8424 | ✅ |
| `-[PlayerEntity primedEquipmentName:]` (7248) | `PlayerEntity::primedEquipmentName` Core/Entities/PlayerEntity.cpp:8426 | ✅ |
| `-[PlayerEntity currentPrimedEquipment]` (7259) | `PlayerEntity::currentPrimedEquipment` Core/Entities/PlayerEntity.cpp:8443 | ✅ |
| `-[PlayerEntity setPrimedEquipment:showMessage:]` (7269) | `PlayerEntity::setPrimedEquipment` Core/Entities/PlayerEntity.cpp:8452 | ✅ |
| `-[PlayerEntity activatePrimableEquipment:withMode:]` (7289) | `PlayerEntity::activatePrimableEquipment` Core/Entities/PlayerEntity.cpp:8494 | ✅ |
| `-[PlayerEntity fastEquipmentA]` (7309) | `PlayerEntity::fastEquipmentA` Core/Entities/PlayerEntity.cpp:8519 | ✅ |
| `-[PlayerEntity fastEquipmentB]` (7314) | `PlayerEntity::fastEquipmentB` Core/Entities/PlayerEntity.cpp:8523 | ✅ |
| `-[PlayerEntity setFastEquipmentA:]` (7319) | `PlayerEntity::setFastEquipmentA` Core/Entities/PlayerEntity.cpp:8527 | ✅ |
| `-[PlayerEntity setFastEquipmentB:]` (7325) | `PlayerEntity::setFastEquipmentB` Core/Entities/PlayerEntity.cpp:8531 | ✅ |
| `-[PlayerEntity weaponTypeForFacing:strict:]` (7331) | `PlayerEntity::weaponTypeForFacing` Core/Entities/PlayerEntity.cpp:8535 | ✅ |
| `-[PlayerEntity missilesList]` (7359) | `PlayerEntity::missilesList` Core/Entities/PlayerEntity.cpp:8566 | ✅ |
| `-[PlayerEntity cargoList]` (7365) | `PlayerEntity::cargoList` Core/Entities/PlayerEntity.cpp:8571 | ✅ |
| `-[PlayerEntity cargoListForScripting]` (7391) | `PlayerEntity::cargoListForScripting` Core/Entities/PlayerEntity.cpp:8611 | ⚠️ |
| `-[PlayerEntity legalStatusOfCargoList]` (7430) | `PlayerEntity::legalStatusOfCargoList` Core/Entities/PlayerEntity.cpp:8667 | ✅ |
| `-[PlayerEntity contractsListForScriptingFromArray:forCargo:]` (7443) | `PlayerEntity::contractsListForScriptingFromArray` Core/Entities/PlayerEntity.cpp:8685 | ✅ |
| `-[PlayerEntity passengerListForScripting]` (7481) | `PlayerEntity::passengerListForScripting` Core/Entities/PlayerEntity.cpp:8745 | ✅ |
| `-[PlayerEntity parcelListForScripting]` (7486) | `PlayerEntity::parcelListForScripting` Core/Entities/PlayerEntity.cpp:8749 | ✅ |
| `-[PlayerEntity contractListForScripting]` (7491) | `PlayerEntity::contractListForScripting` Core/Entities/PlayerEntity.cpp:8753 | ✅ |
| `-[PlayerEntity setGuiToSystemDataScreen]` (7496) | `PlayerEntity::setGuiToSystemDataScreen` Core/Entities/PlayerEntity.cpp:8757 | ✅ |
| `-[PlayerEntity setGuiToSystemDataScreenRefreshBackground:]` (7501) | `PlayerEntity::setGuiToSystemDataScreenRefreshBackground` Core/Entities/PlayerEntity.cpp:8761 | ✅ |
| `-[PlayerEntity prepareMarkedDestination:marker:]` (7697) | `PrepareMarkedDestination` (anon. namespace) Core/Entities/PlayerEntity.cpp:388 | ✅ |
| `-[PlayerEntity markedDestinations]` (7709) | `PlayerEntity::markedDestinations` Core/Entities/PlayerEntity.cpp:9009 | ⚠️ |
| `-[PlayerEntity setGuiToLongRangeChartScreen]` (7744) | `PlayerEntity::setGuiToLongRangeChartScreen` Core/Entities/PlayerEntity.cpp:9040 | ✅ |
| `-[PlayerEntity setGuiToShortRangeChartScreen]` (7756) | `PlayerEntity::setGuiToShortRangeChartScreen` Core/Entities/PlayerEntity.cpp:9051 | ✅ |
| `-[PlayerEntity setGuiToChartScreenFrom:]` (7767) | `PlayerEntity::setGuiToChartScreenFrom` Core/Entities/PlayerEntity.cpp:9061 | ✅ |
| `SliderString` (7821) | `SliderString` (anon. namespace) Core/Entities/PlayerEntity.cpp:398 | ✅ |
| `-[PlayerEntity setGuiToGameOptionsScreen]` (7828) | `PlayerEntity::setGuiToGameOptionsScreen` Core/Entities/PlayerEntity.cpp:9145 | ✅ |
| `-[PlayerEntity setGuiToLoadSaveScreen]` (8059) | `PlayerEntity::setGuiToLoadSaveScreen` Core/Entities/PlayerEntity.cpp:9529 | ✅ |
| `-[PlayerEntity highlightEquipShipScreenKey:]` (8155) | `PlayerEntity::highlightEquipShipScreenKey` Core/Entities/PlayerEntity.cpp:9678 | ✅ |
| `-[PlayerEntity availableFacings]` (8195) | `PlayerEntity::availableFacings` Core/Entities/PlayerEntity.cpp:9722 | ✅ |
| `-[PlayerEntity setGuiToEquipShipScreen:selectingFacingFor:]` (8204) | `PlayerEntity::setGuiToEquipShipScreen(int, optional)` Core/Entities/PlayerEntity.cpp:9736 | ✅ |
| `-[PlayerEntity setGuiToEquipShipScreen:]` (8545) | `PlayerEntity::setGuiToEquipShipScreen(int)` Core/Entities/PlayerEntity.cpp:10178 | ✅ |
| `-[PlayerEntity showInformationForSelectedUpgrade]` (8550) | `PlayerEntity::showInformationForSelectedUpgrade` Core/Entities/PlayerEntity.cpp:10182 | ✅ |
| `-[PlayerEntity showInformationForSelectedUpgradeWithFormatString:]` (8555) | `PlayerEntity::showInformationForSelectedUpgradeWithFormatString` Core/Entities/PlayerEntity.cpp:10186 | ✅ |
| `-[PlayerEntity setGuiToInterfacesScreen:]` (8586) | `PlayerEntity::setGuiToInterfacesScreen` Core/Entities/PlayerEntity.cpp:10238 | ⚠️ |
| `-[PlayerEntity showInformationForSelectedInterface]` (8696) | `PlayerEntity::showInformationForSelectedInterface` Core/Entities/PlayerEntity.cpp:10397 | ✅ |
| `-[PlayerEntity activateSelectedInterface]` (8717) | `PlayerEntity::activateSelectedInterface` Core/Entities/PlayerEntity.cpp:10421 | ✅ |
| `-[PlayerEntity setupStartScreenGui]` (8745) | `PlayerEntity::setupStartScreenGui` Core/Entities/PlayerEntity.cpp:10453 | ✅ |
| `-[PlayerEntity setGuiToIntroFirstGo:]` (8817) | `PlayerEntity::setGuiToIntroFirstGo` Core/Entities/PlayerEntity.cpp:10526 | ✅ |
| `-[PlayerEntity setGuiToOXZManager]` (8920) | `PlayerEntity::setGuiToOXZManager` Core/Entities/PlayerEntity.cpp:10644 | ✅ |
| `-[PlayerEntity noteGUIWillChangeTo:]` (8938) | `PlayerEntity::noteGUIWillChangeTo` Core/Entities/PlayerEntity.cpp:10663 | ✅ |
| `-[PlayerEntity noteGUIDidChangeFrom:to:]` (8945) | `PlayerEntity::noteGUIDidChangeFrom(from, to)` Core/Entities/PlayerEntity.cpp:10671 | ✅ |
| `-[PlayerEntity noteGUIDidChangeFrom:to:refresh:]` (8950) | `PlayerEntity::noteGUIDidChangeFrom(from, to, refresh)` Core/Entities/PlayerEntity.cpp:10676 | ✅ |
| `-[PlayerEntity noteViewDidChangeFrom:toView:]` (8983) | `PlayerEntity::noteViewDidChangeFrom` Core/Entities/PlayerEntity.cpp:10730 | ✅ |
| `-[PlayerEntity buySelectedItem]` (8988) | `PlayerEntity::buySelectedItem` Core/Entities/PlayerEntity.cpp:10737 | ✅ |
| `-[PlayerEntity adjustPriceByScriptForEqKey:withCurrent:]` (9068) | `PlayerEntity::adjustPriceByScriptForEqKey` Core/Entities/PlayerEntity.cpp:10842 | ✅ |
| `-[PlayerEntity tryBuyingItem:]` (9104) | `PlayerEntity::tryBuyingItem` Core/Entities/PlayerEntity.cpp:10885 | ✅ |
| `-[PlayerEntity setWeaponMount:toWeapon:]` (9345) | `PlayerEntity::setWeaponMount(facing, eqKey)` Core/Entities/PlayerEntity.cpp:11168 | ✅ |
| `-[PlayerEntity setWeaponMount:toWeapon:inContext:]` (9350) | `PlayerEntity::setWeaponMount(facing, eqKey, context)` Core/Entities/PlayerEntity.cpp:11173 | ✅ |
| `-[PlayerEntity changePassengerBerths:]` (9395) | `PlayerEntity::changePassengerBerths` Core/Entities/PlayerEntity.cpp:11225 | ✅ |
| `-[PlayerEntity removeMissiles]` (9410) | `PlayerEntity::removeMissiles` Core/Entities/PlayerEntity.cpp:11241 | ✅ |
| `-[PlayerEntity doTradeIn:forPriceFactor:]` (9431) | `PlayerEntity::doTradeIn` Core/Entities/PlayerEntity.cpp:11264 | ✅ |
| `-[PlayerEntity cargoQuantityForType:]` (9440) | `PlayerEntity::cargoQuantityForType` Core/Entities/PlayerEntity.cpp:11275 | ✅ |
| `-[PlayerEntity setCargoQuantityForType:amount:]` (9461) | `PlayerEntity::setCargoQuantityForType` Core/Entities/PlayerEntity.cpp:11298 | ✅ |
| `-[PlayerEntity calculateCurrentCargo]` (9503) | `PlayerEntity::calculateCurrentCargo` Core/Entities/PlayerEntity.cpp:11348 | ✅ |
| `-[PlayerEntity cargoQuantityOnBoard]` (9508) | `PlayerEntity::cargoQuantityOnBoard` Core/Entities/PlayerEntity.cpp:11352 | ✅ |
| `-[PlayerEntity localMarket]` (9547) | `PlayerEntity::localMarket` Core/Entities/PlayerEntity.cpp:11401 | ✅ |
| `-[PlayerEntity applyMarketFilter:onMarket:]` (9569) | `PlayerEntity::applyMarketFilter` Core/Entities/PlayerEntity.cpp:11429 | ✅ |
| `-[PlayerEntity applyMarketSorter:onMarket:]` (9612) | `PlayerEntity::applyMarketSorter` Core/Entities/PlayerEntity.cpp:11475 | ✅ |
| `-[PlayerEntity showMarketScreenHeaders]` (9632) | `PlayerEntity::showMarketScreenHeaders` Core/Entities/PlayerEntity.cpp:11509 | ✅ |
| `-[PlayerEntity showMarketScreenDataLine:forGood:inMarket:holdQuantity:]` (9654) | `PlayerEntity::showMarketScreenDataLine` Core/Entities/PlayerEntity.cpp:11541 | ✅ |
| `-[PlayerEntity marketScreenTitle]` (9700) | `PlayerEntity::marketScreenTitle` Core/Entities/PlayerEntity.cpp:11619 | ✅ |
| `-[PlayerEntity setGuiToMarketScreen]` (9728) | `PlayerEntity::setGuiToMarketScreen` Core/Entities/PlayerEntity.cpp:11662 | ✅ |
| `-[PlayerEntity setGuiToMarketInfoScreen]` (9895) | `PlayerEntity::setGuiToMarketInfoScreen` Core/Entities/PlayerEntity.cpp:11880 | ❌ |
| `-[PlayerEntity showMarketCashAndLoadLine]` (9979) | `PlayerEntity::showMarketCashAndLoadLine` Core/Entities/PlayerEntity.cpp:12018 | ✅ |
| `-[PlayerEntity guiScreen]` (9988) | `PlayerEntity::guiScreen` Core/Entities/PlayerEntity.cpp:12032 | ✅ |
| `-[PlayerEntity tryBuyingCommodity:all:]` (9993) | `PlayerEntity::tryBuyingCommodity` Core/Entities/PlayerEntity.cpp:12034 | ✅ |
| `-[PlayerEntity trySellingCommodity:all:]` (10074) | `PlayerEntity::trySellingCommodity` Core/Entities/PlayerEntity.cpp:12134 | ✅ |
| `-[PlayerEntity isMining]` (10126) | `PlayerEntity::isMining` Core/Entities/PlayerEntity.cpp:12193 | ✅ |
| `-[PlayerEntity isSpeechOn]` (10131) | `PlayerEntity::getIsSpeechOn` Core/Entities/PlayerEntity.cpp:12195 | ✅ |
| `-[PlayerEntity canAddEquipment:inContext:]` (10136) | `PlayerEntity::canAddEquipment` Core/Entities/PlayerEntity.cpp:12197 | ✅ |
| `-[PlayerEntity addEquipmentItem:inContext:]` (10150) | `PlayerEntity::addEquipmentItem(key, context)` Core/Entities/PlayerEntity.cpp:12216 | ✅ |
| `-[PlayerEntity addEquipmentItem:withValidation:inContext:]` (10155) | `PlayerEntity::addEquipmentItem(key, validate, context)` Core/Entities/PlayerEntity.cpp:12225 | ✅ |
| `-[PlayerEntity customEquipmentActivation]` (10186) | `PlayerEntity::customEquipmentActivation` Core/Entities/PlayerEntity.cpp:12262 | ✅ |
| `-[PlayerEntity addEquipmentWithScriptToCustomKeyArray:]` (10191) | `PlayerEntity::addEquipmentWithScriptToCustomKeyArray` Core/Entities/PlayerEntity.cpp:12266 | ✅ |
| `-[PlayerEntity validateCustomEquipActivationArray]` (10233) | `PlayerEntity::validateCustomEquipActivationArray` Core/Entities/PlayerEntity.cpp:12313 | ✅ |
| `-[PlayerEntity removeEquipmentItem:]` (10256) | `PlayerEntity::removeEquipmentItem` Core/Entities/PlayerEntity.cpp:12338 | ✅ |
| `-[PlayerEntity addEquipmentFromCollection:]` (10268) | `PlayerEntity::addEquipmentFromCollection` Core/Entities/PlayerEntity.cpp:12352 | ⚠️ |
| `-[PlayerEntity hasOneEquipmentItem:includeMissiles:]` (10335) | `PlayerEntity::hasOneEquipmentItem` Core/Entities/PlayerEntity.cpp:12419 | ✅ |
| `-[PlayerEntity hasPrimaryWeapon:]` (10357) | `PlayerEntity::hasPrimaryWeapon` Core/Entities/PlayerEntity.cpp:12443 | ✅ |
| `-[PlayerEntity removeExternalStore:]` (10369) | `PlayerEntity::removeExternalStore` Core/Entities/PlayerEntity.cpp:12468 | ✅ |
| `-[PlayerEntity removeFromPylon:]` (10386) | `PlayerEntity::removeFromPylon` Core/Entities/PlayerEntity.cpp:12494 | ✅ |
| `-[PlayerEntity parcelCount]` (10419) | `PlayerEntity::parcelCount` Core/Entities/PlayerEntity.cpp:12530 | ✅ |
| `-[PlayerEntity passengerCount]` (10424) | `PlayerEntity::passengerCount` Core/Entities/PlayerEntity.cpp:12532 | ✅ |
| `-[PlayerEntity passengerCapacity]` (10429) | `PlayerEntity::passengerCapacity` Core/Entities/PlayerEntity.cpp:12534 | ✅ |
| `-[PlayerEntity hasHostileTarget]` (10434) | `PlayerEntity::hasHostileTarget` Core/Entities/PlayerEntity.cpp:12536 | ✅ |
| `-[PlayerEntity receiveCommsMessage:from:]` (10440) | `PlayerEntity::receiveCommsMessage` Core/Entities/PlayerEntity.cpp:12545 | ✅ |
| `-[PlayerEntity getFined]` (10450) | `PlayerEntity::getFined` Core/Entities/PlayerEntity.cpp:12563 | ✅ |
| `-[PlayerEntity adjustTradeInFactorBy:]` (10476) | `PlayerEntity::adjustTradeInFactorBy` Core/Entities/PlayerEntity.cpp:12592 | ✅ |
| `-[PlayerEntity tradeInFactor]` (10485) | `PlayerEntity::tradeInFactor` Core/Entities/PlayerEntity.cpp:12598 | ✅ |
| `-[PlayerEntity renovationCosts]` (10490) | `PlayerEntity::renovationCosts` Core/Entities/PlayerEntity.cpp:12600 | ✅ |
| `-[PlayerEntity renovationFactor]` (10501) | `PlayerEntity::renovationFactor` Core/Entities/PlayerEntity.cpp:12613 | ✅ |
| `-[PlayerEntity setDefaultViewOffsets]` (10508) | `PlayerEntity::setDefaultViewOffsets` Core/Entities/PlayerEntity.cpp:12620 | ✅ |
| `-[PlayerEntity setDefaultCustomViews]` (10520) | `PlayerEntity::setDefaultCustomViews` Core/Entities/PlayerEntity.cpp:12631 | ✅ |
| `-[PlayerEntity weaponViewOffset]` (10532) | `PlayerEntity::weaponViewOffset` Core/Entities/PlayerEntity.cpp:12643 | ✅ |
| `-[PlayerEntity setUpTrumbles]` (10551) | `PlayerEntity::setUpTrumbles` Core/Entities/PlayerEntity.cpp:12661 | ✅ |
| `-[PlayerEntity addTrumble:]` (10580) | `PlayerEntity::addTrumble` Core/Entities/PlayerEntity.cpp:12694 | ✅ |
| `-[PlayerEntity removeTrumble:]` (10590) | `PlayerEntity::removeTrumble` Core/Entities/PlayerEntity.cpp:12702 | ❌ |
| `-[PlayerEntity trumbleArray]` (10611) | `PlayerEntity::trumbleArray` Core/Entities/PlayerEntity.cpp:12722 | ✅ |
| `-[PlayerEntity trumbleCount]` (10616) | `PlayerEntity::getTrumbleCount` Core/Entities/PlayerEntity.cpp:12724 | ✅ |
| `-[PlayerEntity trumbleValue]` (10621) | `PlayerEntity::trumbleValue` Core/Entities/PlayerEntity.cpp:12729 | ✅ |
| `-[PlayerEntity setTrumbleValueFrom:]` (10643) | `PlayerEntity::setTrumbleValueFrom` Core/Entities/PlayerEntity.cpp:12756 | ✅ |
| `-[PlayerEntity trumbleAppetiteAccumulator]` (10741) | `PlayerEntity::trumbleAppetiteAccumulator` Core/Entities/PlayerEntity.cpp:12858 | ✅ |
| `-[PlayerEntity setTrumbleAppetiteAccumulator:]` (10746) | `PlayerEntity::setTrumbleAppetiteAccumulator` Core/Entities/PlayerEntity.cpp:12862 | ✅ |
| `-[PlayerEntity mungChecksumWithNSString:]` (10751) | `PlayerEntity::mungChecksumWithString` Core/Entities/PlayerEntity.cpp:12866 | ✅ |
| `-[PlayerEntity screenModeStringForWidth:height:refreshRate:]` (10762) | `PlayerEntity::screenModeStringForWidth` Core/Entities/PlayerEntity.cpp:12877 | ✅ |
| `-[PlayerEntity suppressTargetLost]` (10771) | `PlayerEntity::getSuppressTargetLost` Core/Entities/PlayerEntity.cpp:12887 | ✅ |
| `-[PlayerEntity setScoopsActive]` (10776) | `PlayerEntity::setScoopsActive` Core/Entities/PlayerEntity.cpp:12889 | ✅ |
| `-[PlayerEntity setFoundTarget:]` (10782) | `PlayerEntity::setFoundTarget` Core/Entities/PlayerEntity.cpp:12892 | ✅ |
| `-[PlayerEntity addTarget:]` (10794) | `PlayerEntity::addTarget` Core/Entities/PlayerEntity.cpp:12902 | ✅ |
| `-[PlayerEntity clearTargetMemory]` (10847) | `PlayerEntity::clearTargetMemory` Core/Entities/PlayerEntity.cpp:12976 | ✅ |
| `-[PlayerEntity targetMemory]` (10860) | `PlayerEntity::targetMemory` Core/Entities/PlayerEntity.cpp:12988 | ✅ |
| `-[PlayerEntity moveTargetMemoryBy:]` (10865) | `PlayerEntity::moveTargetMemoryBy` Core/Entities/PlayerEntity.cpp:12992 | ✅ |
| `-[PlayerEntity printIdentLockedOnForMissile:]` (10911) | `PlayerEntity::printIdentLockedOnForMissile` Core/Entities/PlayerEntity.cpp:13048 | ❌ |
| `-[PlayerEntity customViewQuaternion]` (10921) | `PlayerEntity::getCustomViewQuaternion` Core/Entities/PlayerEntity.cpp:13065 | ✅ |
| `-[PlayerEntity setCustomViewQuaternion:]` (10926) | `PlayerEntity::setCustomViewQuaternion` Core/Entities/PlayerEntity.cpp:13069 | ✅ |
| `-[PlayerEntity customViewMatrix]` (10932) | `PlayerEntity::getCustomViewMatrix` Core/Entities/PlayerEntity.cpp:13074 | ✅ |
| `-[PlayerEntity customViewOffset]` (10937) | `PlayerEntity::getCustomViewOffset` Core/Entities/PlayerEntity.cpp:13076 | ✅ |
| `-[PlayerEntity setCustomViewOffset:]` (10942) | `PlayerEntity::setCustomViewOffset` Core/Entities/PlayerEntity.cpp:13078 | ✅ |
| `-[PlayerEntity customViewRotationCenter]` (10947) | `PlayerEntity::getCustomViewRotationCenter` Core/Entities/PlayerEntity.cpp:13082 | ✅ |
| `-[PlayerEntity setCustomViewRotationCenter:]` (10952) | `PlayerEntity::setCustomViewRotationCenter` Core/Entities/PlayerEntity.cpp:13086 | ✅ |
| `-[PlayerEntity customViewZoomIn:]` (10957) | `PlayerEntity::customViewZoomIn` Core/Entities/PlayerEntity.cpp:13090 | ✅ |
| `-[PlayerEntity customViewZoomOut:]` (10968) | `PlayerEntity::customViewZoomOut` Core/Entities/PlayerEntity.cpp:13102 | ✅ |
| `-[PlayerEntity customViewRotateLeft:]` (10979) | `PlayerEntity::customViewRotateLeft` Core/Entities/PlayerEntity.cpp:13114 | ✅ |
| `-[PlayerEntity customViewRotateRight:]` (10990) | `PlayerEntity::customViewRotateRight` Core/Entities/PlayerEntity.cpp:13126 | ✅ |
| `-[PlayerEntity customViewRotateUp:]` (11001) | `PlayerEntity::customViewRotateUp` Core/Entities/PlayerEntity.cpp:13138 | ✅ |
| `-[PlayerEntity customViewRotateDown:]` (11012) | `PlayerEntity::customViewRotateDown` Core/Entities/PlayerEntity.cpp:13150 | ✅ |
| `-[PlayerEntity customViewRollRight:]` (11023) | `PlayerEntity::customViewRollRight` Core/Entities/PlayerEntity.cpp:13162 | ✅ |
| `-[PlayerEntity customViewRollLeft:]` (11034) | `PlayerEntity::customViewRollLeft` Core/Entities/PlayerEntity.cpp:13174 | ✅ |
| `-[PlayerEntity customViewPanUp:]` (11045) | `PlayerEntity::customViewPanUp` Core/Entities/PlayerEntity.cpp:13186 | ✅ |
| `-[PlayerEntity customViewPanDown:]` (11052) | `PlayerEntity::customViewPanDown` Core/Entities/PlayerEntity.cpp:13197 | ✅ |
| `-[PlayerEntity customViewPanLeft:]` (11059) | `PlayerEntity::customViewPanLeft` Core/Entities/PlayerEntity.cpp:13212 | ✅ |
| `-[PlayerEntity customViewPanRight:]` (11066) | `PlayerEntity::customViewPanRight` Core/Entities/PlayerEntity.cpp:13223 | ✅ |
| `-[PlayerEntity customViewForwardVector]` (11073) | `PlayerEntity::getCustomViewForwardVector` Core/Entities/PlayerEntity.cpp:13234 | ✅ |
| `-[PlayerEntity customViewUpVector]` (11078) | `PlayerEntity::getCustomViewUpVector` Core/Entities/PlayerEntity.cpp:13238 | ✅ |
| `-[PlayerEntity customViewRightVector]` (11083) | `PlayerEntity::getCustomViewRightVector` Core/Entities/PlayerEntity.cpp:13240 | ✅ |
| `-[PlayerEntity customViewDescription]` (11088) | `PlayerEntity::getCustomViewDescription` Core/Entities/PlayerEntity.cpp:13244 | ✅ |
| `-[PlayerEntity resetCustomView]` (11093) | `PlayerEntity::resetCustomView` Core/Entities/PlayerEntity.cpp:13248 | ✅ |
| `-[PlayerEntity setCustomViewData]` (11098) | `PlayerEntity::setCustomViewData` Core/Entities/PlayerEntity.cpp:13257 | ✅ |
| `-[PlayerEntity setCustomViewDataFromDictionary:withScaling:]` (11109) | `PlayerEntity::setCustomViewDataFromDictionary` Core/Entities/PlayerEntity.cpp:13268 | ✅ |
| `-[PlayerEntity showInfoFlag]` (11143) | `PlayerEntity::showInfoFlag` Core/Entities/PlayerEntity.cpp:13309 | ✅ |
| `-[PlayerEntity missionOverlayDescriptor]` (11148) | `PlayerEntity::missionOverlayDescriptor` Core/Entities/PlayerEntity.cpp:13311 | ✅ |
| `-[PlayerEntity missionOverlayDescriptorOrDefault]` (11153) | `PlayerEntity::missionOverlayDescriptorOrDefault` Core/Entities/PlayerEntity.cpp:13315 | ✅ |
| `-[PlayerEntity setMissionOverlayDescriptor:]` (11167) | `PlayerEntity::setMissionOverlayDescriptor` Core/Entities/PlayerEntity.cpp:13332 | ✅ |
| `-[PlayerEntity missionBackgroundDescriptor]` (11175) | `PlayerEntity::missionBackgroundDescriptor` Core/Entities/PlayerEntity.cpp:13336 | ✅ |
| `-[PlayerEntity missionBackgroundDescriptorOrDefault]` (11180) | `PlayerEntity::missionBackgroundDescriptorOrDefault` Core/Entities/PlayerEntity.cpp:13340 | ✅ |
| `-[PlayerEntity setMissionBackgroundDescriptor:]` (11190) | `PlayerEntity::setMissionBackgroundDescriptor` Core/Entities/PlayerEntity.cpp:13351 | ✅ |
| `-[PlayerEntity missionBackgroundSpecial]` (11198) | `PlayerEntity::missionBackgroundSpecial` Core/Entities/PlayerEntity.cpp:13355 | ✅ |
| `-[PlayerEntity setMissionBackgroundSpecial:]` (11203) | `PlayerEntity::setMissionBackgroundSpecial` Core/Entities/PlayerEntity.cpp:13359 | ✅ |
| `-[PlayerEntity setMissionExitScreen:]` (11254) | `PlayerEntity::setMissionExitScreen` Core/Entities/PlayerEntity.cpp:13409 | ✅ |
| `-[PlayerEntity missionExitScreen]` (11259) | `PlayerEntity::missionExitScreen` Core/Entities/PlayerEntity.cpp:13413 | ✅ |
| `-[PlayerEntity equipScreenBackgroundDescriptor]` (11264) | `PlayerEntity::equipScreenBackgroundDescriptor` Core/Entities/PlayerEntity.cpp:13415 | ✅ |
| `-[PlayerEntity setEquipScreenBackgroundDescriptor:]` (11269) | `PlayerEntity::setEquipScreenBackgroundDescriptor` Core/Entities/PlayerEntity.cpp:13419 | ✅ |
| `-[PlayerEntity scriptsLoaded]` (11277) | `PlayerEntity::scriptsLoaded` Core/Entities/PlayerEntity.cpp:13424 | ✅ |
| `-[PlayerEntity worldScriptNames]` (11282) | `PlayerEntity::worldScriptNames` Core/Entities/PlayerEntity.cpp:13426 | ⚠️ |
| `-[PlayerEntity worldScriptsByName]` (11287) | `PlayerEntity::worldScriptsByName` Core/Entities/PlayerEntity.cpp:13434 | ⚠️ |
| `-[PlayerEntity commodityScriptNamed:]` (11292) | `PlayerEntity::commodityScriptNamed` Core/Entities/PlayerEntity.cpp:13438 | ✅ |
| `-[PlayerEntity doScriptEvent:inContext:withArguments:count:]` (11311) | `PlayerEntity::doScriptEvent(message, context, argv, argc)` Core/Entities/PlayerEntity.cpp:13464 | ✅ |
| `-[PlayerEntity doWorldEventUntilMissionScreen:]` (11317) | `PlayerEntity::doWorldEventUntilMissionScreen` Core/Entities/PlayerEntity.cpp:13472 | ⚠️ |
| `-[PlayerEntity doWorldScriptEvent:inContext:withArguments:count:timeLimit:]` (11344) | `PlayerEntity::doWorldScriptEvent` Core/Entities/PlayerEntity.cpp:13506 | ⚠️ |
| `-[PlayerEntity setGalacticHyperspaceBehaviour:]` (11357) | `PlayerEntity::setGalacticHyperspaceBehaviour` Core/Entities/PlayerEntity.cpp:13523 | ✅ |
| `-[PlayerEntity galacticHyperspaceBehaviour]` (11364) | `PlayerEntity::getGalacticHyperspaceBehaviour` Core/Entities/PlayerEntity.cpp:13531 | ✅ |
| `-[PlayerEntity setGalacticHyperspaceFixedCoords:]` (11369) | `PlayerEntity::setGalacticHyperspaceFixedCoords` Core/Entities/PlayerEntity.cpp:13535 | ✅ |
| `-[PlayerEntity setGalacticHyperspaceFixedCoordsX:y:]` (11374) | `PlayerEntity::setGalacticHyperspaceFixedCoordsX` Core/Entities/PlayerEntity.cpp:13541 | ✅ |
| `-[PlayerEntity galacticHyperspaceFixedCoords]` (11380) | `PlayerEntity::getGalacticHyperspaceFixedCoords` Core/Entities/PlayerEntity.cpp:13547 | ✅ |
| `-[PlayerEntity setWitchspaceCountdown:]` (11385) | `PlayerEntity::setWitchspaceCountdown` Core/Entities/PlayerEntity.cpp:13551 | ✅ |
| `-[PlayerEntity longRangeChartMode]` (11390) | `PlayerEntity::getLongRangeChartMode` Core/Entities/PlayerEntity.cpp:13555 | ✅ |
| `-[PlayerEntity setLongRangeChartMode:]` (11395) | `PlayerEntity::setLongRangeChartMode` Core/Entities/PlayerEntity.cpp:13559 | ✅ |
| `-[PlayerEntity scoopOverride]` (11400) | `PlayerEntity::getScoopOverride` Core/Entities/PlayerEntity.cpp:13563 | ✅ |
| `-[PlayerEntity setScoopOverride:]` (11405) | `PlayerEntity::setScoopOverride` Core/Entities/PlayerEntity.cpp:13565 | ✅ |
| `-[PlayerEntity fuelChargeRate]` (11413) | `PlayerEntity::fuelChargeRate` Core/Entities/PlayerEntity.cpp:13570 | ✅ |
| `-[PlayerEntity setDockTarget:]` (11429) | `PlayerEntity::setDockTarget` Core/Entities/PlayerEntity.cpp:13594 | ✅ |
| `-[PlayerEntity jumpCause]` (11438) | `PlayerEntity::jumpCause` Core/Entities/PlayerEntity.cpp:13603 | ✅ |
| `-[PlayerEntity setJumpCause:]` (11443) | `PlayerEntity::setJumpCause` Core/Entities/PlayerEntity.cpp:13605 | ✅ |
| `-[PlayerEntity commanderName]` (11450) | `PlayerEntity::commanderName` Core/Entities/PlayerEntity.cpp:13610 | ✅ |
| `-[PlayerEntity lastsaveName]` (11455) | `PlayerEntity::lastsaveName` Core/Entities/PlayerEntity.cpp:13614 | ✅ |
| `-[PlayerEntity setCommanderName:]` (11460) | `PlayerEntity::setCommanderName` Core/Entities/PlayerEntity.cpp:13618 | ✅ |
| `-[PlayerEntity setLastsaveName:]` (11467) | `PlayerEntity::setLastsaveName` Core/Entities/PlayerEntity.cpp:13623 | ✅ |
| `-[PlayerEntity isDocked]` (11475) | `PlayerEntity::isDocked` Core/Entities/PlayerEntity.cpp:13635 | ✅ |
| `-[PlayerEntity clearedToDock]` (11529) | `PlayerEntity::clearedToDock` Core/Entities/PlayerEntity.cpp:13698 | ✅ |
| `-[PlayerEntity setDockingClearanceStatus:]` (11534) | `PlayerEntity::setDockingClearanceStatus` Core/Entities/PlayerEntity.cpp:13703 | ✅ |
| `-[PlayerEntity getDockingClearanceStatus]` (11550) | `PlayerEntity::getDockingClearanceStatus` Core/Entities/PlayerEntity.cpp:13721 | ✅ |
| `-[PlayerEntity penaltyForUnauthorizedDocking]` (11555) | `PlayerEntity::penaltyForUnauthorizedDocking` Core/Entities/PlayerEntity.cpp:13725 | ✅ |
| `-[PlayerEntity addScannedWormhole:]` (11572) | `PlayerEntity::addScannedWormhole` Core/Entities/PlayerEntity.cpp:13742 | ✅ |
| `-[PlayerEntity updateWormholes]` (11590) | `PlayerEntity::updateWormholes` Core/Entities/PlayerEntity.cpp:13756 | ✅ |
| `-[PlayerEntity scannedWormholes]` (11620) | `PlayerEntity::getScannedWormholes` Core/Entities/PlayerEntity.cpp:13784 | ✅ |
| `-[PlayerEntity initialiseMissionDestinations:andLegacy:]` (11625) | `PlayerEntity::initialiseMissionDestinations` Core/Entities/PlayerEntity.cpp:13788 | ✅ |
| `-[PlayerEntity markerKey:]` (11657) | `PlayerEntity::markerKey` Core/Entities/PlayerEntity.cpp:13811 | ✅ |
| `-[PlayerEntity addMissionDestinationMarker:]` (11662) | `PlayerEntity::addMissionDestinationMarker` Core/Entities/PlayerEntity.cpp:13820 | ✅ |
| `-[PlayerEntity removeMissionDestinationMarker:]` (11672) | `PlayerEntity::removeMissionDestinationMarker` Core/Entities/PlayerEntity.cpp:13829 | ✅ |
| `-[PlayerEntity getMissionDestinations]` (11686) | `PlayerEntity::getMissionDestinations` Core/Entities/PlayerEntity.cpp:13838 | ❌ |
| `-[PlayerEntity shipyardRecord]` (11691) | `PlayerEntity::shipyardRecord` Core/Entities/PlayerEntity.cpp:13842 | ✅ |
| `-[PlayerEntity setLastShot:]` (11696) | `PlayerEntity::setLastShot` Core/Entities/PlayerEntity.cpp:13844 | ✅ |
| `-[PlayerEntity clearExtraMissionKeys]` (11701) | `PlayerEntity::clearExtraMissionKeys` Core/Entities/PlayerEntity.cpp:13849 | ✅ |
| `-[PlayerEntity setExtraMissionKeys:]` (11707) | `PlayerEntity::setExtraMissionKeys` Core/Entities/PlayerEntity.cpp:13851 | ✅ |
| `-[PlayerEntity clearExtraGuiScreenKeys:key:]` (11718) | `PlayerEntity::clearExtraGuiScreenKeys` Core/Entities/PlayerEntity.cpp:13862 | ❌ |
| `-[PlayerEntity setExtraGuiScreenKeys:definition:]` (11733) | `PlayerEntity::setExtraGuiScreenKeys` Core/Entities/PlayerEntity.cpp:13884 | ⚠️ |
| `-[PlayerEntity dumpSelfState]` (11794) | `PlayerEntity::dumpSelfState` Core/Entities/PlayerEntity.cpp:13954 | ❌ |
| `-[PlayerEntity suppressClangStuff]` (11856) | `PlayerEntity::suppressClangStuff` Core/Entities/PlayerEntity.cpp:14029 | ✅ |
| `marketSorterByName` (11868) | `marketSorterByName` (anon. namespace) Core/Entities/PlayerEntity.cpp:207 | ✅ |
| `marketSorterByPrice` (11874) | `marketSorterByPrice` (anon. namespace) Core/Entities/PlayerEntity.cpp:218 | ✅ |
| `marketSorterByQuantity` (11887) | `marketSorterByQuantity` (anon. namespace) Core/Entities/PlayerEntity.cpp:227 | ✅ |
| `marketSorterByMassUnit` (11900) | `marketSorterByMassUnit` (anon. namespace) Core/Entities/PlayerEntity.cpp:236 | ✅ |

**Differences:**

- ❌ **low** — Loading a save: `role_weights` keeps only string elements (non-strings dropped, shifting slots and shortening the list) where upstream `mutableCopy` kept every element; a non-string `comm_log` entry is passed as nil instead of the object; an int contract `type` with no legacy mapping becomes `""` where upstream raised on `setObject:nil`. Only hand-edited or corrupt saves — (still open) upstream `Core/Entities/PlayerEntity.m:1425`, `:1473`, `:1266` ↔ port `Core/Entities/PlayerEntity.cpp:2127`, `:2183`, `:1884`
- ❌ **low** — Also on load: `role_system_memory` elements are read with `at<int>`, so a non-number entry becomes system 0 where upstream kept the object as is — (new) upstream `Core/Entities/PlayerEntity.m:1443` ↔ port `Core/Entities/PlayerEntity.cpp:2147`
- ❌ **low** — `fireMainWeapon` overheat path calls `currentLaserOffset().at(0)`: with an empty weapon-offset list this throws `std::out_of_range`, where upstream `oo_vectorAtIndex:0` returned `kZeroVector` and went on (overheat sound + message) — (still open) upstream `Core/Entities/PlayerEntity.m:5461` ↔ port `Core/Entities/PlayerEntity.cpp:6225`
- ⚠️ **low** — `cycleNext/PreviousMultiFunctionDisplay` cycle MFD keys in `std::map` byte order, not `-[NSDictionary allKeys]` hash order, so the cycle key picks MFDs in a different order (the code comment says so) — (still open) upstream `Core/Entities/PlayerEntity.m:4920`, `:4950` ↔ port `Core/Entities/PlayerEntity.cpp:5647`, `:5685`
- ⚠️ **low** — `commanderDataDictionary` leaves out a key whose value is nil (`written_by_version`, `current_system_name`, `player_name`, `subentities_status`, `primed_equipment_a/b`, `trumbles`, …) where upstream `setObject:nil` raised mid-save (the code comment says so); a nil missile `primaryRole` is saved as `""`. Key spellings, number kinds and defaults match; the parcel-reputation backfill happens before `reputation` is stored, which gives the same saved dictionary as upstream storing the live object first — (still open) upstream `Core/Entities/PlayerEntity.m:755`, `:834`, `:888` ↔ port `Core/Entities/PlayerEntity.cpp:1188`, `:1307`, `:1382`
- ⚠️ **low** — `setDialCustom` stores a null value as a null entry, where upstream `setObject:nil forKey:` raised (the code comment says so) — (still open) upstream `Core/Entities/PlayerEntity.m:4129` ↔ port `Core/Entities/PlayerEntity.cpp:4919`
- ⚠️ **low** — Debug `STAGE_TRACKING_END` logs `"***** Exception during [...]"` only for an `OOException` and rethrows anything else without the line; upstream `@catch (NSException *)` logged every NSException (the code comment says so) — (still open) upstream `Core/Entities/PlayerEntity.m:2359` ↔ port `Core/Entities/PlayerEntity.cpp:350`
- ➖ — `-init` is `PlayerEntity()` + `newPlayerObject()` (held for the process by a never-deleted holder in `sharedPlayer`); `-dealloc` is `willDealloc()` + member destructors; the `kOOLogBuyMounted*` constants are inlined at their use sites (in the other auditor's rows) — port `Core/Entities/PlayerEntity.cpp:432`, `:446`, `:501`
- Subtle (✅): setting up resets `customDialSettings`, MFD settings, `reputation` (all 9 keys at 0/0/`MAX_CONTRACT_REP`), `roleWeights` (8 × `player-unknown`), credits 1000, `PLAYER_MAX_FUEL`, galaxy coords (0x14,0xAD), trade-in 95, energy 256, temperature 60, shields `BASELINE_SHIELD_LEVEL` / recharge 2.0, as upstream. The ship clock start uses `oo::date::localUTCOffsetMinutes` for local h/m/s instead of `NSCalendarDate` — upstream `Core/Entities/PlayerEntity.m:1850` ↔ port `Core/Entities/PlayerEntity.cpp:2540`
- Subtle (✅): `setCommanderDataFromDictionary` guards `% _customViews.size()` against an empty `custom_views` array (upstream divided by zero) and skips `removeObjectForKey:nil` for a passenger without a string name (upstream raised) — upstream `Core/Entities/PlayerEntity.m:1569`, `:1333` ↔ port `Core/Entities/PlayerEntity.cpp:2308`, `:1986`
- Subtle (✅): `addRoleForAggression` / `addRoleForMining` store `role_weight_flags` counts as signed integers (upstream `numberWithUnsignedInteger:`); the XML plist `<integer>` is the same — upstream `Core/Entities/PlayerEntity.m:4503` ↔ port `Core/Entities/PlayerEntity.cpp:5226`
- Subtle (✅): `performWitchspaceCountdownUpdates` passes `""` as `destination` when `getSystemName` has no name, where upstream passed nil to `OOExpandKey` (only for an invalid next-hop ID) — upstream `Core/Entities/PlayerEntity.m:3448` ↔ port `Core/Entities/PlayerEntity.cpp:4163`
- Subtle (✅): the shared_ptr/enum-class refactors since the last run (T094/T095, T051–T068) leave these rows unchanged in logic: missile/cargo pods and the HUD are now `std::shared_ptr`, the docked station and compass target `std::weak_ptr` (expired = nil), and alert flags/compass modes/scan classes are enum classes with the same values and comparisons — e.g. port `Core/Entities/PlayerEntity.cpp:4808`, `:5315`, `:5873`

- ❌ **med** (still open) — `printIdentLockedOnForMissile` still resolves the name through `oo::ToShip(primaryTarget())`; upstream sent `-identFromShip:` to any target, and `WormholeEntity` has its own `identFromShip` (`Core/Entities/WormholeEntity.h:155`). With ident engaged on a wormhole the "ident-locked-onto-target" message shows an empty name — upstream `Core/Entities/PlayerEntity.m:10917` ↔ port `Core/Entities/PlayerEntity.cpp:13054`
- ❌ **low** (still open) — `setGuiToMarketInfoScreen` still adds pod contents at `quantityInHold[j]` with no not-found guard (the market screen has one, :11713). With a filter hiding a carried good, `j == oo::kNotFound` writes outside the `std::vector` (heap corruption/crash risk; upstream scribbled on a stack VLA) — upstream `Core/Entities/PlayerEntity.m:9922-9923` ↔ port `Core/Entities/PlayerEntity.cpp:11924-11928`
- ❌ **low** (still open) — `getMissionDestinations` returns a snapshot of a `std::map` keyed by `"%d-name"`, so `mission.markedSystems` lists markers in key byte order instead of NSMutableDictionary order; no comment marks it intentional — upstream `Core/Entities/PlayerEntity.m:11686` ↔ port `Core/Entities/PlayerEntity.cpp:13838`
- ❌ **low** (still open) — `clearExtraGuiScreenKeys`: upstream sent `-oo_stringForKey:` to an `OOJSGuiScreenKeyDefinition`, raising (reported as a JS error) whenever definitions exist; the port reads `"name"` from an empty PList and silently never matches. Nothing is removed in either tree — upstream `Core/Entities/PlayerEntity.m:11725` ↔ port `Core/Entities/PlayerEntity.cpp:13874-13877`
- ❌ **low** (still open) — `removeTrumble` "trumble.zombie" log prints a bare pointer (`{}` of `const void*`) where upstream's `%@` printed `<OOTrumble: 0x…>`; class unchanged, text differs — upstream `Core/Entities/PlayerEntity.m:10603` ↔ port `Core/Entities/PlayerEntity.cpp:12713-12714`
- ❌ **low** (new) — `dumpSelfState` "Alert level" line formats the second value with `std::format("{:#x}")`, which prints `0x0` for zero, where printf `%#x` printed `0` (the `#` flag adds no prefix to zero). `alertCondition` is 0 when docked, so the debug-monitor dump text differs there. The other `%g`/`%u`/`%i`/`%zu` fields match — upstream `Core/Entities/PlayerEntity.m:11806` ↔ port `Core/Entities/PlayerEntity.cpp:13969-13971`
- ❌ **low** (still open, narrowed) — (helper, no row) `adjustPriceByScriptForEqKey` relies on `OOJSValueToInt32`, which now rounds with `floor(d+0.5)` and then rejects results outside `[INT32_MIN, INT32_MAX]`. SpiderMonkey 1.8.5 accepted `-2147483649 < d < 2147483648` and wrapped; only a script price in `[2147483647.5, 2147483648)` (or the mirror negative window) now reports an error instead of being ignored as negative. Price unchanged either way — upstream `Core/Entities/PlayerEntity.m:9088` ↔ port `Core/Scripting/OOJavaScriptEngine.cpp:607-624`
- ⚠️ **low** (still open) — `cargoListForScripting` skips pods whose commodity is nil/unknown (upstream indexed with `NSNotFound`, undefined behaviour) and omits `displayName` where upstream raised on nil; port comments mark it — upstream `Core/Entities/PlayerEntity.m:7407-7420` ↔ port `Core/Entities/PlayerEntity.cpp:8634-8656`
- ⚠️ **low** (still open) — `markedDestinations` adds mission markers in `std::map` key byte order (comment "ORDER-SENSITIVE"); draw order of several markers on one system can change — upstream `Core/Entities/PlayerEntity.m:7735` ↔ port `Core/Entities/PlayerEntity.cpp:9031-9035`
- ⚠️ **low** (still open) — `setGuiToInterfacesScreen` stable-sorts map keys by `interfaceCompare`; ties keep byte order instead of NSDictionary order (comment "ORDER-SENSITIVE") — upstream `Core/Entities/PlayerEntity.m:8595` ↔ port `Core/Entities/PlayerEntity.cpp:10256-10263`
- ⚠️ **low** (still open) — `addEquipmentFromCollection` walks a dictionary in key byte order (comment "key byte order (was NSDictionary order)"), fixing `eqScripts`/`customEquipActivation` and so priming order after load; NSSet input gone, non-string array elements skipped — upstream `Core/Entities/PlayerEntity.m:10276-10287` ↔ port `Core/Entities/PlayerEntity.cpp:12359-12369`
- ⚠️ **low** (still open) — `worldScriptNames`/`worldScriptsByName` return world scripts in load order instead of `-allKeys` order (decision D, comment at :13470) — upstream `Core/Entities/PlayerEntity.m:11284,11289` ↔ port `Core/Entities/PlayerEntity.cpp:13426,13434`
- ⚠️ **low** (still open) — `doWorldEventUntilMissionScreen`/`doWorldScriptEvent` call world scripts in load order over a snapshot ("ORDER-SENSITIVE (decision D)"); which script raises a mission screen first can differ — upstream `Core/Entities/PlayerEntity.m:11330,11350` ↔ port `Core/Entities/PlayerEntity.cpp:13470-13494,13511-13520`
- ⚠️ **low** (still open) — `setExtraGuiScreenKeys` checks existing definitions in byte order; only the order of the "key already in use" log lines can change (comment) — upstream `Core/Entities/PlayerEntity.m:11773` ↔ port `Core/Entities/PlayerEntity.cpp:13927-13931`
- ➖ **low** (still open) — `setGuiToGameOptionsScreen` drops the `#if !NEW_PLANETS` procedurally-textured-planets row (and `PlayerEntityControls` drops its key handler); upstream builds with `NEW_PLANETS 1`, so the code was dead and the row numbers match — upstream `Core/Entities/PlayerEntity.m:8017-8023` ↔ port `Core/Entities/PlayerEntity.cpp:9470-9472`
- ✅ **low** (note) — The port's refactors since the previous audit (enum classes, `std::format`, `std::shared_ptr` holders, GUI-row `constexpr` functions) were checked in these rows: `{:.1f}`/`{:f}`/`{:g}` give the same text as `%.1f`/`%f`/`%g`; `OOGUIFirstRow`/`OOGUIListRow` equal `GUI_FIRST_ROW`/`GUI_ROW`; `OOWeaponFacingIsIn` replaces the `&` facing tests; `fuelChargeRate` keeps the integer `ship_trade_in_factor / 100` — port `Core/Entities/PlayerEntity.h:180-249`, `Core/Entities/PlayerEntity.cpp:13579`
- ✅ **low** (note) — Bounty, kill, witchspace, equipment-purchase and market maths re-verified as in the previous audit: `markAsOffender` OR, score ×10 (÷10 for cargo/buoys/rocks except tharglets), fuel `10*max(0.1,d)`, malfunction 253/256, misjump `randf() > 0.75`, role clearing at 6400/2560 kills, `600+price` install time, energy-unit refunds /2 /4 ×3/4 ×3/8, renovation `5+techLevel` capped at 100, buy/sell limits, `penaltyForUnauthorizedDocking` `credits*0.05` capped at 50000 — port `Core/Entities/PlayerEntity.cpp:6883-6945,7748-7853,10885-11166,12034-12191,13725-13737`
- ✅ **low** (note) — Nil arguments to `OOExpandKey` (which raised upstream) become `""` in the port (`witch-blocked`, `status-hyperspace-system-multi`, `equipment-plural*`, `equipment-primed`, `manifest-cargo-quantity*`, `game-paused-docked`); `currentPrimedEquipment` returns `""` past the end where upstream returned nil — port `Core/Entities/PlayerEntity.cpp:7479-7488,8093-8098,8262-8305,8443-8450`
- ✅ **low** (note, risk) — `marketSorterByName` compares UTF-16 units via `oo::str::compare`, not GNUstep's composed/decomposed equivalence; localised names with combining marks could sort differently. Ties stay stable (`std::stable_sort`) — upstream `Core/Entities/PlayerEntity.m:11871` ↔ port `Core/Entities/PlayerEntity.cpp:207-216,11484`

## PlayerEntityContracts

<a id="playerentitycontracts"></a>
Upstream `src/Core/Entities/PlayerEntityContracts.m` ↔ `Core/Entities/PlayerEntityContracts.cpp` (1775 / 2236 lines)

**Status:** done — 40 rows: 39 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(Contracts) processEscapePods]` (61) | `PlayerEntity::processEscapePods` Core/Entities/PlayerEntityContracts.cpp:86 | ✅ |
| `-[PlayerEntity(Contracts) checkPassengerContracts]` (147) | `PlayerEntity::checkPassengerContracts` Core/Entities/PlayerEntityContracts.cpp:217 | ✅ |
| `-[PlayerEntity(Contracts) contractedVolumeForGood:]` (422) | `PlayerEntity::contractedVolumeForGood` Core/Entities/PlayerEntityContracts.cpp:625 | ✅ |
| `-[PlayerEntity(Contracts) addMessageToReport:]` (435) | `PlayerEntity::addMessageToReport` Core/Entities/PlayerEntityContracts.cpp:637 | ✅ |
| `-[PlayerEntity(Contracts) reputation]` (445) | `PlayerEntity::getReputation` Core/Entities/PlayerEntityContracts.cpp:646 | ✅ |
| `-[PlayerEntity(Contracts) passengerReputation]` (450) | `PlayerEntity::passengerReputation` Core/Entities/PlayerEntityContracts.cpp:648 | ✅ |
| `-[PlayerEntity(Contracts) increasePassengerReputation:]` (464) | `PlayerEntity::increasePassengerReputation` Core/Entities/PlayerEntityContracts.cpp:662 | ✅ |
| `-[PlayerEntity(Contracts) decreasePassengerReputation:]` (489) | `PlayerEntity::decreasePassengerReputation` Core/Entities/PlayerEntityContracts.cpp:683 | ✅ |
| `-[PlayerEntity(Contracts) parcelReputation]` (514) | `PlayerEntity::parcelReputation` Core/Entities/PlayerEntityContracts.cpp:704 | ✅ |
| `-[PlayerEntity(Contracts) increaseParcelReputation:]` (528) | `PlayerEntity::increaseParcelReputation` Core/Entities/PlayerEntityContracts.cpp:718 | ✅ |
| `-[PlayerEntity(Contracts) decreaseParcelReputation:]` (553) | `PlayerEntity::decreaseParcelReputation` Core/Entities/PlayerEntityContracts.cpp:739 | ✅ |
| `-[PlayerEntity(Contracts) contractReputation]` (578) | `PlayerEntity::contractReputation` Core/Entities/PlayerEntityContracts.cpp:760 | ✅ |
| `-[PlayerEntity(Contracts) increaseContractReputation:]` (592) | `PlayerEntity::increaseContractReputation` Core/Entities/PlayerEntityContracts.cpp:774 | ✅ |
| `-[PlayerEntity(Contracts) decreaseContractReputation:]` (617) | `PlayerEntity::decreaseContractReputation` Core/Entities/PlayerEntityContracts.cpp:795 | ✅ |
| `-[PlayerEntity(Contracts) erodeReputation]` (642) | `PlayerEntity::erodeReputation` Core/Entities/PlayerEntityContracts.cpp:816 | ✅ |
| `-[PlayerEntity(Contracts) normaliseReputation]` (696) | `PlayerEntity::normaliseReputation` Core/Entities/PlayerEntityContracts.cpp:867 | ✅ |
| `-[PlayerEntity(Contracts) addPassenger:start:destination:eta:fee:advance:risk:]` (746) | `PlayerEntity::addPassenger` Core/Entities/PlayerEntityContracts.cpp:917 | ✅ |
| `-[PlayerEntity(Contracts) removePassenger:]` (776) | `PlayerEntity::removePassenger` Core/Entities/PlayerEntityContracts.cpp:954 | ✅ |
| `-[PlayerEntity(Contracts) addParcel:start:destination:eta:fee:premium:risk:]` (797) | `PlayerEntity::addParcel` Core/Entities/PlayerEntityContracts.cpp:977 | ✅ |
| `-[PlayerEntity(Contracts) removeParcel:]` (828) | `PlayerEntity::removeParcel` Core/Entities/PlayerEntityContracts.cpp:1015 | ✅ |
| `-[PlayerEntity(Contracts) awardContract:commodity:start:destination:eta:fee:premium:]` (849) | `PlayerEntity::awardContract` Core/Entities/PlayerEntityContracts.cpp:1038 | ✅ |
| `-[PlayerEntity(Contracts) removeContract:destination:]` (920) | `PlayerEntity::removeContract` Core/Entities/PlayerEntityContracts.cpp:1118 | ✅ |
| `-[PlayerEntity(Contracts) passengerList]` (945) | `PlayerEntity::passengerList` Core/Entities/PlayerEntityContracts.cpp:1150 | ✅ |
| `-[PlayerEntity(Contracts) parcelList]` (950) | `PlayerEntity::parcelList` Core/Entities/PlayerEntityContracts.cpp:1154 | ✅ |
| `-[PlayerEntity(Contracts) contractList]` (955) | `PlayerEntity::contractList` Core/Entities/PlayerEntityContracts.cpp:1158 | ✅ |
| `-[PlayerEntity(Contracts) contractsListFromArray:forCargo:forParcels:]` (960) | `PlayerEntity::contractsListFromEntries` Core/Entities/PlayerEntityContracts.cpp:1162 | ✅ |
| `-[PlayerEntity(Contracts) setGuiToManifestScreen]` (986) | `PlayerEntity::setGuiToManifestScreen` Core/Entities/PlayerEntityContracts.cpp:1216 | ✅ |
| `-[PlayerEntity(Contracts) setManifestScreenRow:inColor:forRow:ofRows:andOffset:inMultipage:]` (1167) | `PlayerEntity::setManifestScreenRow` Core/Entities/PlayerEntityContracts.cpp:1425 | ✅ |
| `-[PlayerEntity(Contracts) setGuiToDockingReportScreen]` (1183) | `PlayerEntity::setGuiToDockingReportScreen` Core/Entities/PlayerEntityContracts.cpp:1448 | ✅ |
| `-[PlayerEntity(Contracts) priceForShipKey:]` (1255) | `PlayerEntity::priceForShipKey` Core/Entities/PlayerEntityContracts.cpp:1596 | ✅ |
| `-[PlayerEntity(Contracts) setGuiToShipyardScreen:]` (1261) | `PlayerEntity::setGuiToShipyardScreen` Core/Entities/PlayerEntityContracts.cpp:1601 | ✅ |
| `-[PlayerEntity(Contracts) showShipyardInfoForSelection]` (1393) | `PlayerEntity::showShipyardInfoForSelection` Core/Entities/PlayerEntityContracts.cpp:1765 | ✅ |
| `-[PlayerEntity(Contracts) showTradeInInformationFooter]` (1463) | `PlayerEntity::showTradeInInformationFooter` Core/Entities/PlayerEntityContracts.cpp:1851 | ✅ |
| `-[PlayerEntity(Contracts) showShipyardModel:shipData:personality:]` (1476) | `PlayerEntity::showShipyardModel` Core/Entities/PlayerEntityContracts.cpp:1873 (nil key checked by the caller, :1836) | ✅ |
| `-[PlayerEntity(Contracts) missingSubEntitiesAdjustment]` (1483) | `PlayerEntity::missingSubEntitiesAdjustment` Core/Entities/PlayerEntityContracts.cpp:1881 | ✅ |
| `-[PlayerEntity(Contracts) tradeInValue]` (1490) | `PlayerEntity::tradeInValue` Core/Entities/PlayerEntityContracts.cpp:1888 | ✅ |
| `-[PlayerEntity(Contracts) buySelectedShip]` (1510) | `PlayerEntity::buySelectedShip` Core/Entities/PlayerEntityContracts.cpp:1916 | ✅ |
| `-[PlayerEntity(Contracts) replaceShipWithNamedShip:]` (1620) | `PlayerEntity::replaceShipWithNamedShip` Core/Entities/PlayerEntityContracts.cpp:2060 | ✅ |
| `-[PlayerEntity(Contracts) newShipCommonSetup:yardInfo:baseInfo:]` (1658) | `PlayerEntity::newShipCommonSetup` Core/Entities/PlayerEntityContracts.cpp:2106 | ⚠️ |
| `RepForRisk` (1764) | `RepForRisk` (static) Core/Entities/PlayerEntityContracts.cpp:2226 | ✅ |

**Differences:**

- ⚠️ **low** (still open) — Portable equipment carried over to a new ship is re-added from a `std::set` in key order; upstream used `NSMutableSet` hash order. Only the order of the `addEquipmentItem(…, NO, "portable")` calls changes; the port's comment says so — upstream `Core/Entities/PlayerEntityContracts.m:1725-1742` ↔ port `Core/Entities/PlayerEntityContracts.cpp:2189-2205`
- ✅ **low** (note) — Fee and deadline maths re-verified: integer `dest_eta`, the `fee *= 110; fee /= 100; dest_eta *= 0.5` tip loop (3600 s passengers, 86400 s parcels), late-fare halving, cargo `10 * float fee` truncated to `int`, `acceptable_ratio = 100 - 10*system_id/256`, float `reward` added to `credits`, `RepForRisk` 1/2/4, the bean-shift loops and `normaliseReputation` integer scaling. `market_rnd % unknown` in the reputation getters is unchanged — port `Core/Entities/PlayerEntityContracts.cpp:217-622,648-915`
- ✅ **low** (note) — Report text: each line built with `formatRuntime(...) + "\n"` and the last `\n` trimmed, as `appendFormatLine:` and `deleteCharacterAtIndex:` did; nil names print `(null)` via `FormatArg::null()`. `awardContract` IDs use `{:06x}-{:06x}`, the same text as `%06x-%06x` for the non-negative masked values — port `Core/Entities/PlayerEntityContracts.cpp:265-269,615-620,1044,1055`
- ✅ **low** (note) — Where upstream would have raised, the port is defensive: a nil `SHIPYARD_KEY_ID` is skipped (:1639, :2025), a nil `CARGO_KEY_ID` in `removeContract` (:1141), nil values left out of the manifest `OOExpandKey` dictionary (:1197-1200), and `playerWillBuyNewShip` arguments end at the first null as `arrayWithObjects:` did (:1974-1984). Malformed data only.
- ✅ **low** (note, upstream quirk kept) — `buySelectedShip` indexes `localShipyard` by `selectedRow - GUI_ROW_SHIPYARD_START`, ignoring the page `skip`, both for the event argument and for the ship it removes — upstream `Core/Entities/PlayerEntityContracts.m:1561,1598` ↔ port `Core/Entities/PlayerEntityContracts.cpp:1972,2036-2037`

## PlayerEntityControls

<a id="playerentitycontrols"></a>
Upstream `src/Core/Entities/PlayerEntityControls.m` ↔ `Core/Entities/PlayerEntityControls.cpp` (4831 / 6144 lines)

**Status:** done — 46 rows: 38 ✅ 4 ⚠️ 4 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(Controls) initControls]` (203) | `PlayerEntity::initControls` Core/Entities/PlayerEntityControls.cpp:228 | ✅ |
| `-[PlayerEntity(Controls) initKeyConfigSettings]` (293) | `PlayerEntity::initKeyConfigSettings` Core/Entities/PlayerEntityControls.cpp:313 | ❌ |
| `-[PlayerEntity(Controls) processKeyCode:]` (512) | `PlayerEntity::processKeyCode` Core/Entities/PlayerEntityControls.cpp:587 | ❌ |
| `-[PlayerEntity(Controls) checkNavKeyPress:]` (591) | `PlayerEntity::checkNavKeyPress` Core/Entities/PlayerEntityControls.cpp:663 | ✅ |
| `-[PlayerEntity(Controls) checkKeyPress:]` (603) | `PlayerEntity::checkKeyPress (1 arg)` Core/Entities/PlayerEntityControls.cpp:675 | ✅ |
| `-[PlayerEntity(Controls) checkKeyPress:fKey_only:]` (608) | `PlayerEntity::checkKeyPress (fKey_only)` Core/Entities/PlayerEntityControls.cpp:679 | ✅ |
| `-[PlayerEntity(Controls) checkKeyPress:ignore_ctrl:]` (613) | `PlayerEntity::checkKeyPressIgnoreCtrl` Core/Entities/PlayerEntityControls.cpp:683 | ✅ |
| `-[PlayerEntity(Controls) checkKeyPress:fKey_only:ignore_ctrl:]` (618) | `PlayerEntity::checkKeyPress (3 args)` Core/Entities/PlayerEntityControls.cpp:688 | ✅ |
| `-[PlayerEntity(Controls) getFirstKeyCode:]` (642) | `PlayerEntity::getFirstKeyCode` Core/Entities/PlayerEntityControls.cpp:724 | ✅ |
| `-[PlayerEntity(Controls) pollControls:]` (648) | `PlayerEntity::pollControls` Core/Entities/PlayerEntityControls.cpp:729 | ✅ |
| `-[PlayerEntity(Controls) handleGUIUpDownArrowKeys]` (697) | `PlayerEntity::handleGUIUpDownArrowKeys (+ static ClickedGUIRow :788)` Core/Entities/PlayerEntityControls.cpp:805 | ⚠️ |
| `-[PlayerEntity(Controls) targetNewSystem:whileTyping:]` (774) | `PlayerEntity::targetNewSystem(int,bool)` Core/Entities/PlayerEntityControls.cpp:882 | ✅ |
| `-[PlayerEntity(Controls) clearPlanetSearchString]` (787) | `PlayerEntity::clearPlanetSearchString` Core/Entities/PlayerEntityControls.cpp:898 | ✅ |
| `-[PlayerEntity(Controls) targetNewSystem:]` (795) | `PlayerEntity::targetNewSystem(int)` Core/Entities/PlayerEntityControls.cpp:904 | ✅ |
| `-[PlayerEntity(Controls) switchToMainView]` (800) | `PlayerEntity::switchToMainView` Core/Entities/PlayerEntityControls.cpp:908 | ✅ |
| `-[PlayerEntity(Controls) noteSwitchToView:fromView:]` (815) | `PlayerEntity::noteSwitchToView` Core/Entities/PlayerEntityControls.cpp:926 | ✅ |
| `-[PlayerEntity(Controls) beginWitchspaceCountdown:]` (820) | `PlayerEntity::beginWitchspaceCountdown(int)` Core/Entities/PlayerEntityControls.cpp:931 | ✅ |
| `-[PlayerEntity(Controls) beginWitchspaceCountdown]` (848) | `PlayerEntity::beginWitchspaceCountdown()` Core/Entities/PlayerEntityControls.cpp:970 | ✅ |
| `-[PlayerEntity(Controls) cancelWitchspaceCountdown]` (855) | `PlayerEntity::cancelWitchspaceCountdown` Core/Entities/PlayerEntityControls.cpp:976 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollApplicationControls]` (870) | `PlayerEntity::pollApplicationControls (+ static AnyKeyPressed :111)` Core/Entities/PlayerEntityControls.cpp:986 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollFlightControls:]` (1045) | `PlayerEntity::pollFlightControls` Core/Entities/PlayerEntityControls.cpp:1211 | ❌ |
| `-[PlayerEntity(OOControlsPrivate) pollGuiArrowKeyControls:]` (1797) | `PlayerEntity::pollGuiArrowKeyControls` Core/Entities/PlayerEntityControls.cpp:2182 | ⚠️ |
| `-[PlayerEntity(OOControlsPrivate) pollMarketScreenControls]` (2709) | `PlayerEntity::pollMarketScreenControls` Core/Entities/PlayerEntityControls.cpp:3385 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleGameOptionsScreenKeys]` (2903) | `PlayerEntity::handleGameOptionsScreenKeys` Core/Entities/PlayerEntityControls.cpp:3633 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleKeyMapperScreenKeys]` (3339) | `PlayerEntity::handleKeyMapperScreenKeys` Core/Entities/PlayerEntityControls.cpp:4306 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleKeyboardLayoutKeys]` (3375) | `PlayerEntity::handleKeyboardLayoutKeys` Core/Entities/PlayerEntityControls.cpp:4353 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleStickMapperScreenKeys]` (3411) | `PlayerEntity::handleStickMapperScreenKeys` Core/Entities/PlayerEntityControls.cpp:4398 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollCustomViewControls]` (3449) | `PlayerEntity::pollCustomViewControls` Core/Entities/PlayerEntityControls.cpp:4447 | ⚠️ |
| `-[PlayerEntity(OOControlsPrivate) pollViewControls]` (3570) | `PlayerEntity::pollViewControls` Core/Entities/PlayerEntityControls.cpp:4632 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollFlightArrowKeyControls:]` (3695) | `PlayerEntity::pollFlightArrowKeyControls` Core/Entities/PlayerEntityControls.cpp:4787 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollGuiScreenControls]` (3905) | `PlayerEntity::pollGuiScreenControls` Core/Entities/PlayerEntityControls.cpp:5009 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollGuiScreenControlsWithFKeyAlias:]` (3910) | `PlayerEntity::pollGuiScreenControlsWithFKeyAlias` Core/Entities/PlayerEntityControls.cpp:5013 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollGameOverControls:]` (4032) | `PlayerEntity::pollGameOverControls` Core/Entities/PlayerEntityControls.cpp:5142 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollAutopilotControls:]` (4050) | `PlayerEntity::pollAutopilotControls` Core/Entities/PlayerEntityControls.cpp:5161 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollDockedControls:]` (4124) | `PlayerEntity::pollDockedControls` Core/Entities/PlayerEntityControls.cpp:5249 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleUndockControl]` (4190) | `PlayerEntity::handleUndockControl` Core/Entities/PlayerEntityControls.cpp:5330 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollDemoControls:]` (4204) | `PlayerEntity::pollDemoControls` Core/Entities/PlayerEntityControls.cpp:5352 | ⚠️ |
| `-[PlayerEntity(OOControlsPrivate) pollMissionInterruptControls]` (4515) | `PlayerEntity::pollMissionInterruptControls` Core/Entities/PlayerEntityControls.cpp:5761 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleMissionCallback]` (4532) | `PlayerEntity::handleMissionCallback` Core/Entities/PlayerEntityControls.cpp:5777 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) setGuiToMissionEndScreen]` (4560) | `PlayerEntity::setGuiToMissionEndScreen` Core/Entities/PlayerEntityControls.cpp:5810 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) switchToThisView:]` (4616) | `PlayerEntity::switchToThisView(view)` Core/Entities/PlayerEntityControls.cpp:5867 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) switchToThisView:andProcessWeaponFacing:]` (4621) | `PlayerEntity::switchToThisView(view,bool)` Core/Entities/PlayerEntityControls.cpp:5871 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) switchToThisView:fromView:andProcessWeaponFacing:justNotify:]` (4626) | `PlayerEntity::switchToThisView (4 args)` Core/Entities/PlayerEntityControls.cpp:5879 | ❌ |
| `-[PlayerEntity(OOControlsPrivate) handleAutopilotOn:]` (4671) | `PlayerEntity::handleAutopilotOn` Core/Entities/PlayerEntityControls.cpp:5934 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleButtonIdent]` (4776) | `PlayerEntity::handleButtonIdent` Core/Entities/PlayerEntityControls.cpp:6071 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleButtonTargetMissile]` (4793) | `PlayerEntity::handleButtonTargetMissile` Core/Entities/PlayerEntityControls.cpp:6086 | ✅ |

**Differences:**

- ❌ **low** — A keyconfig layout that lacks a binding no longer aborts init: the port leaves a null `n_key_*` and carries on, where upstream raised on `setObject:nil` — upstream `Core/Entities/PlayerEntityControls.m:331` ↔ port `Core/Entities/PlayerEntityControls.cpp:348-360` (still open)
- ❌ **low** — processKeyCode pushes a definition that has no "key" entry, so it reads as key code 0; upstream raised — upstream `Core/Entities/PlayerEntityControls.m:581` ↔ port `Core/Entities/PlayerEntityControls.cpp:651-654` (still open)
- ❌ **low** — The laser-hit sound uses `currentLaserOffset().at(0)`, which throws `std::out_of_range` on an empty offset list. The catch rethrows anything that is not an OOException. Upstream got `kZeroVector` from nil messaging — upstream `Core/Entities/PlayerEntityControls.m:1189` ↔ port `Core/Entities/PlayerEntityControls.cpp:1403` (still open)
- ❌ **low** — The invalid-view log prints `__FUNCTION__` ("switchToThisView") instead of the full ObjC selector, so the log text differs — upstream `Core/Entities/PlayerEntityControls.m:4660` ↔ port `Core/Entities/PlayerEntityControls.cpp:5914-5917` (still open)
- ⚠️ **low** — GUI mouse click rows come from `ClickedGUIRow`/`rowAtVirtualJoystickPosition`, not `cursor_row`. This is documented in the comment at :779-787 — upstream `Core/Entities/PlayerEntityControls.m:697` ↔ port `Core/Entities/PlayerEntityControls.cpp:788-801,859,866` (still open)
- ⚠️ **low** — Script-registered GUI screen keys are walked in byte order ("byte order (was -allKeys order)") — upstream `Core/Entities/PlayerEntityControls.m:1797` ↔ port `Core/Entities/PlayerEntityControls.cpp:3321` (still open)
- ⚠️ **low** — Mission-screen extra keys are walked in byte order (comment "ORDER-SENSITIVE") — upstream `Core/Entities/PlayerEntityControls.m:4204` ↔ port `Core/Entities/PlayerEntityControls.cpp:5702` (still open)
- ⚠️ **low** — Custom-view and GUI repeat timers use `monotonicSeconds()` instead of wall-clock time — port `Core/Entities/PlayerEntityControls.cpp:1735,1744,1968,4490` (still open)
- Note: The upstream joystick GUI buttons (commits 82705fe48, 38aa005d3) are fully ported, and the per-function BUTTON_GUI* counts match. The `clearStickStates` calls are at :3657, :3665, :4350, :4395, :4442 and :5429.
- Note: The port drops the dead NEW_PLANETS options-row block (upstream .m:3256-3258) and the Mac-only `oolite-keyconfig-mod2-mac` text, which is not used in SDL builds. `AnyKeyPressed` (:111) evaluates every operand. The fullscreen pause target is nil (:1021, :2775), with no observable change. A per-function string-literal comparison found no other differences.

## PlayerEntityKeyMapper

<a id="playerentitykeymapper"></a>
Upstream `src/Core/Entities/PlayerEntityKeyMapper.m` ↔ `Core/Entities/PlayerEntityKeyMapper.cpp` (1616 / 2188 lines)

**Status:** done — 42 rows: 39 ✅ 1 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(KeyMapper) initCheckingDictionary]` (78) | `PlayerEntity::initCheckingDictionary` Core/Entities/PlayerEntityKeyMapper.cpp:201 | ✅ |
| `-[PlayerEntity(KeyMapper) resetKeyFunctions]` (113) | `PlayerEntity::resetKeyFunctions` Core/Entities/PlayerEntityKeyMapper.cpp:232 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyMapperScreen:]` (119) | `PlayerEntity::setGuiToKeyMapperScreen(unsigned)` Core/Entities/PlayerEntityKeyMapper.cpp:234 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyMapperScreen:resetCurrentRow:]` (124) | `PlayerEntity::setGuiToKeyMapperScreen(unsigned,bool)` Core/Entities/PlayerEntityKeyMapper.cpp:238 | ✅ |
| `-[PlayerEntity(KeyMapper) keyMapperInputHandler:view:]` (189) | `PlayerEntity::keyMapperInputHandler` Core/Entities/PlayerEntityKeyMapper.cpp:313 | ❌ |
| `-[PlayerEntity(KeyMapper) entryIsIndexCustomEquip:]` (298) | `PlayerEntity::entryIsIndexCustomEquip` Core/Entities/PlayerEntityKeyMapper.cpp:454 | ✅ |
| `-[PlayerEntity(KeyMapper) entryIsDictCustomEquip:]` (303) | `PlayerEntity::entryIsDictCustomEquip` Core/Entities/PlayerEntityKeyMapper.cpp:460 | ✅ |
| `-[PlayerEntity(KeyMapper) entryIsCustomEquip:]` (308) | `PlayerEntity::entryIsCustomEquip` Core/Entities/PlayerEntityKeyMapper.cpp:465 | ✅ |
| `-[PlayerEntity(KeyMapper) getCustomEquipArray:]` (316) | `PlayerEntity::getCustomEquipArray` Core/Entities/PlayerEntityKeyMapper.cpp:473 | ✅ |
| `-[PlayerEntity(KeyMapper) getCustomEquipIndex:]` (339) | `PlayerEntity::getCustomEquipIndex` Core/Entities/PlayerEntityKeyMapper.cpp:497 | ✅ |
| `-[PlayerEntity(KeyMapper) getCustomEquipKeyDefType:]` (359) | `PlayerEntity::getCustomEquipKeyDefType` Core/Entities/PlayerEntityKeyMapper.cpp:516 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyConfigScreen]` (370) | `PlayerEntity::setGuiToKeyConfigScreen()` Core/Entities/PlayerEntityKeyMapper.cpp:527 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyConfigScreen:]` (375) | `PlayerEntity::setGuiToKeyConfigScreen(bool)` Core/Entities/PlayerEntityKeyMapper.cpp:529 | ✅ |
| `-[PlayerEntity(KeyMapper) outputKeyDefinition:shift:mod1:mod2:skiprows:]` (471) | `PlayerEntity::outputKeyDefinition` Core/Entities/PlayerEntityKeyMapper.cpp:637 | ✅ |
| `-[PlayerEntity(KeyMapper) handleKeyConfigKeys:view:]` (514) | `PlayerEntity::handleKeyConfigKeys` Core/Entities/PlayerEntityKeyMapper.cpp:679 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyConfigEntryScreen]` (551) | `PlayerEntity::setGuiToKeyConfigEntryScreen` Core/Entities/PlayerEntityKeyMapper.cpp:730 | ✅ |
| `-[PlayerEntity(KeyMapper) handleKeyConfigEntryKeys:view:]` (601) | `PlayerEntity::handleKeyConfigEntryKeys` Core/Entities/PlayerEntityKeyMapper.cpp:793 | ✅ |
| `-[PlayerEntity(KeyMapper) updateKeyDefinition:index:]` (633) | `PlayerEntity::updateKeyDefinition` Core/Entities/PlayerEntityKeyMapper.cpp:831 | ✅ |
| `-[PlayerEntity(KeyMapper) updateShiftKeyDefinition:index:]` (659) | `PlayerEntity::updateShiftKeyDefinition` Core/Entities/PlayerEntityKeyMapper.cpp:854 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToConfirmClearScreen]` (701) | `PlayerEntity::setGuiToConfirmClearScreen` Core/Entities/PlayerEntityKeyMapper.cpp:894 | ✅ |
| `-[PlayerEntity(KeyMapper) handleKeyMapperConfirmClearKeys:view:]` (734) | `PlayerEntity::handleKeyMapperConfirmClearKeys` Core/Entities/PlayerEntityKeyMapper.cpp:930 | ✅ |
| `-[PlayerEntity(KeyMapper) displayKeyFunctionList:skip:]` (764) | `PlayerEntity::displayKeyFunctionList` Core/Entities/PlayerEntityKeyMapper.cpp:980 | ✅ |
| `-[PlayerEntity(KeyMapper) keyFunctionList]` (879) | `PlayerEntity::keyFunctionList` Core/Entities/PlayerEntityKeyMapper.cpp:1128 | ✅ |
| `-[PlayerEntity(KeyMapper) makeKeyGuiDict:keyDef:]` (1046) | `PlayerEntity::makeKeyGuiDict` Core/Entities/PlayerEntityKeyMapper.cpp:1485 | ✅ |
| `-[PlayerEntity(KeyMapper) makeKeyGuiDictHeader:]` (1056) | `PlayerEntity::makeKeyGuiDictHeader` Core/Entities/PlayerEntityKeyMapper.cpp:1498 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyboardLayoutScreen:]` (1065) | `PlayerEntity::setGuiToKeyboardLayoutScreen(unsigned)` Core/Entities/PlayerEntityKeyMapper.cpp:1506 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyboardLayoutScreen:resetCurrentRow:]` (1070) | `PlayerEntity::setGuiToKeyboardLayoutScreen(unsigned,bool)` Core/Entities/PlayerEntityKeyMapper.cpp:1510 | ✅ |
| `-[PlayerEntity(KeyMapper) handleKeyboardLayoutEntryKeys:view:]` (1105) | `PlayerEntity::handleKeyboardLayoutEntryKeys` Core/Entities/PlayerEntityKeyMapper.cpp:1550 | ✅ |
| `-[PlayerEntity(KeyMapper) keyboardDescription:]` (1147) | `PlayerEntity::keyboardDescription` Core/Entities/PlayerEntityKeyMapper.cpp:1601 | ✅ |
| `-[PlayerEntity(KeyMapper) keyboardLayoutList]` (1164) | `PlayerEntity::keyboardLayoutList` Core/Entities/PlayerEntityKeyMapper.cpp:1611 | ⚠️ |
| `-[PlayerEntity(KeyMapper) displayKeyboardLayoutList:skip:]` (1207) | `PlayerEntity::displayKeyboardLayoutList` Core/Entities/PlayerEntityKeyMapper.cpp:1656 | ✅ |
| `-[PlayerEntity(KeyMapper) validateAllKeys]` (1270) | `PlayerEntity::validateAllKeys` Core/Entities/PlayerEntityKeyMapper.cpp:1721 | ✅ |
| `-[PlayerEntity(KeyMapper) validateKey:checkKeys:]` (1287) | `PlayerEntity::validateKey` Core/Entities/PlayerEntityKeyMapper.cpp:1739 | ✅ |
| `-[PlayerEntity(KeyMapper) searchArrayForMatch:key:checkKeys:]` (1421) | `PlayerEntity::searchArrayForMatch` Core/Entities/PlayerEntityKeyMapper.cpp:1964 | ✅ |
| `-[PlayerEntity(KeyMapper) entryIsEqualToDefault:]` (1451) | `PlayerEntity::entryIsEqualToDefault` Core/Entities/PlayerEntityKeyMapper.cpp:2004 | ✅ |
| `-[PlayerEntity(KeyMapper) compareKeyEntries:second:]` (1468) | `PlayerEntity::compareKeyEntries` Core/Entities/PlayerEntityKeyMapper.cpp:2022 | ✅ |
| `-[PlayerEntity(KeyMapper) saveKeySetting:]` (1480) | `PlayerEntity::saveKeySetting` Core/Entities/PlayerEntityKeyMapper.cpp:2037 | ❌ |
| `-[PlayerEntity(KeyMapper) unsetKeySetting:]` (1531) | `PlayerEntity::unsetKeySetting` Core/Entities/PlayerEntityKeyMapper.cpp:2093 | ✅ |
| `-[PlayerEntity(KeyMapper) deleteKeySetting:]` (1553) | `PlayerEntity::deleteKeySetting` Core/Entities/PlayerEntityKeyMapper.cpp:2112 | ✅ |
| `-[PlayerEntity(KeyMapper) deleteAllKeySettings]` (1570) | `PlayerEntity::deleteAllKeySettings` Core/Entities/PlayerEntityKeyMapper.cpp:2134 | ✅ |
| `-[PlayerEntity(KeyMapper) loadKeySettings]` (1596) | `PlayerEntity::loadKeySettings` Core/Entities/PlayerEntityKeyMapper.cpp:2171 | ✅ |
| `-[PlayerEntity(KeyMapper) reloadPage]` (1603) | `PlayerEntity::reloadPage` Core/Entities/PlayerEntityKeyMapper.cpp:2176 | ✅ |

**Differences:**

- ❌ **low** — 'u' or 'r' on the keyboard-layout row (`selFunctionIdx=-1`) gets a null entry from `KeyFunctionAt(-1)`. 'u' then calls `unsetKeySetting("")`, which persists a `"" = ()` override, and 'r' calls `deleteKeySetting("")` and rewrites the defaults. Upstream raised on `objectAtIndex:-1` and changed nothing — upstream `Core/Entities/PlayerEntityKeyMapper.m:241,254` ↔ port `Core/Entities/PlayerEntityKeyMapper.cpp:379-382,394-397` (still open)
- ❌ **low** — saveKeySetting runs to completion in two cases where upstream raised. With an empty `key_list`, `at(0)` is null and the port saves an empty override. With a cleared primary key and a numeric alternate, `IsEmptyString` returns false where upstream's `isEqualToString:` on an NSNumber raised — upstream `Core/Entities/PlayerEntityKeyMapper.m:1480-1495` ↔ port `Core/Entities/PlayerEntityKeyMapper.cpp:2051-2062` (still open)
- ⚠️ **low** — The keyboard layout list is built in map order, then `stable_sort`ed by description (documented). Upstream used NSDictionary `allKeys` order before sorting — upstream `Core/Entities/PlayerEntityKeyMapper.m:1164` ↔ port `Core/Entities/PlayerEntityKeyMapper.cpp:1611` (still open)
- Note: Upstream commit 040599229 (text moved into descriptions.plist) is ported at :261, :770, :805, :983-985, :1473, :1477, :1529, :1659 and :1704. The joystick `BUTTON_GUISELECT` select is ported at :319, :685, :937 and :1556. A string-literal diff found nothing else.

## PlayerEntityLoadSave

<a id="playerentityloadsave"></a>
Upstream `src/Core/Entities/PlayerEntityLoadSave.m` ↔ `Core/Entities/PlayerEntityLoadSave.cpp` (1185 / 1438 lines)

**Status:** done — 26 rows: 23 ✅ 2 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(LoadSave) loadPlayer]` (80) | `PlayerEntity::loadPlayer` Core/Entities/PlayerEntityLoadSave.cpp:117 | ✅ |
| `-[PlayerEntity(LoadSave) savePlayer]` (88) | `PlayerEntity::savePlayer` Core/Entities/PlayerEntityLoadSave.cpp:124 | ✅ |
| `-[PlayerEntity(LoadSave) autosavePlayer]` (93) | `PlayerEntity::autosavePlayer` Core/Entities/PlayerEntityLoadSave.cpp:128 | ✅ |
| `-[PlayerEntity(LoadSave) quicksavePlayer]` (128) | `PlayerEntity::quicksavePlayer` Core/Entities/PlayerEntityLoadSave.cpp:169 | ✅ |
| `-[PlayerEntity(LoadSave) setGuiToScenarioScreen:]` (149) | `PlayerEntity::setGuiToScenarioScreen` Core/Entities/PlayerEntityLoadSave.cpp:196 | ✅ |
| `-[PlayerEntity(LoadSave) addScenarioModel:]` (215) | `PlayerEntity::addScenarioModel` Core/Entities/PlayerEntityLoadSave.cpp:265 | ✅ |
| `-[PlayerEntity(LoadSave) showScenarioDetails]` (220) | `PlayerEntity::showScenarioDetails` Core/Entities/PlayerEntityLoadSave.cpp:269 | ✅ |
| `-[PlayerEntity(LoadSave) startScenario]` (244) | `PlayerEntity::startScenario` Core/Entities/PlayerEntityLoadSave.cpp:301 | ✅ |
| `-[PlayerEntity(LoadSave) commanderSelector]` (282) | `PlayerEntity::commanderSelector` Core/Entities/PlayerEntityLoadSave.cpp:342 | ✅ |
| `-[PlayerEntity(LoadSave) saveCommanderInputHandler]` (366) | `PlayerEntity::saveCommanderInputHandler` Core/Entities/PlayerEntityLoadSave.cpp:446 | ✅ |
| `-[PlayerEntity(LoadSave) overwriteCommanderInputHandler]` (453) | `PlayerEntity::overwriteCommanderInputHandler` Core/Entities/PlayerEntityLoadSave.cpp:566 | ✅ |
| `-[PlayerEntity(LoadSave) loadPlayerFromFile:asNew:]` (485) | `PlayerEntity::loadPlayerFromFile` Core/Entities/PlayerEntityLoadSave.cpp:615 | ⚠️ |
| `-[PlayerEntity(OOLoadSavePrivate) writePlayerToPath:]` (683) | `PlayerEntity::writePlayerToPath` Core/Entities/PlayerEntityLoadSave.cpp:863 | ❌ |
| `-[PlayerEntity(OOLoadSavePrivate) nativeSavePlayer:]` (718) | `PlayerEntity::nativeSavePlayer` Core/Entities/PlayerEntityLoadSave.cpp:907 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) setGuiToLoadCommanderScreen]` (730) | `PlayerEntity::setGuiToLoadCommanderScreen` Core/Entities/PlayerEntityLoadSave.cpp:923 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) setGuiToSaveCommanderScreen:]` (752) | `PlayerEntity::setGuiToSaveCommanderScreen` Core/Entities/PlayerEntityLoadSave.cpp:949 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) setGuiToOverwriteScreen:]` (782) | `PlayerEntity::setGuiToOverwriteScreen` Core/Entities/PlayerEntityLoadSave.cpp:983 | ✅ |
| `sortCommanders` (818) | `comparator lambda in PlayerEntity::lsCommanders` Core/Entities/PlayerEntityLoadSave.cpp:1098 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) lsCommanders:directory:pageNumber:highlightName:]` (823) | `PlayerEntity::lsCommanders` Core/Entities/PlayerEntityLoadSave.cpp:1028 | ⚠️ |
| `-[PlayerEntity(OOLoadSavePrivate) existingNativeSave:]` (987) | `PlayerEntity::existingNativeSave` Core/Entities/PlayerEntityLoadSave.cpp:1217 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) showCommanderShip:]` (996) | `PlayerEntity::showCommanderShip` Core/Entities/PlayerEntityLoadSave.cpp:1230 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) findIndexOfCommander:]` (1114) | `PlayerEntity::findIndexOfCommander` Core/Entities/PlayerEntityLoadSave.cpp:1360 | ✅ |
| `-[MyOpenGLView(OOLoadSaveExtensions) isCommandModifierKeyDown]` (1132) | `IsCommandModifierKeyDown (anon. namespace)` Core/Entities/PlayerEntityLoadSave.cpp:110 | ✅ |
| `PersonalityForCommanderDict` (1139) | `PersonalityForCommanderDict (anon. namespace)` Core/Entities/PlayerEntityLoadSave.cpp:1378 | ✅ |
| `OODeciCreditsFromDouble` (1151) | `OODeciCreditsFromDouble` Core/Entities/PlayerEntityLoadSave.cpp:1398 | ✅ |
| `OODeciCreditsFromObject` (1178) | `OODeciCreditsFromPList` Core/Entities/PlayerEntityLoadSave.cpp:1425 | ✅ |

**Differences:**

- ❌ **low** — The writePlayerToPath error log embeds `__PRETTY_FUNCTION__` (C++ signature text) instead of the ObjC method name. The nil-path guard also fires on an empty path — upstream `Core/Entities/PlayerEntityLoadSave.m:690-693` ↔ port `Core/Entities/PlayerEntityLoadSave.cpp:869-872` (still open)
- ⚠️ **low** — A save file whose root is not a dictionary no longer logs the `plist.wrongType` line that upstream's typed plist load printed. It still fails with the same user-facing error — upstream `Core/Entities/PlayerEntityLoadSave.m:507` ↔ port `Core/Entities/PlayerEntityLoadSave.cpp:639-648` (still open)
- ⚠️ **low** — lsCommanders also loses the `plist.wrongType` log for non-dictionary saves — upstream `Core/Entities/PlayerEntityLoadSave.m:823` ↔ port `Core/Entities/PlayerEntityLoadSave.cpp:1067-1072` (still open)
- Note: lsCommanders now inlines upstream `commanderContentsOfPath:`. The missing-directory `savedGame.read.fail.fileNotFound` ERR matches (:1048-1049). Upstream's `notDictionary` log was dead code (comment :1036-1038). The sort uses `localizedCompare` with `stable_sort`.
- Note: These all match: `showCommanderShip` `%c`→`{:c}`, the single-precision float case in `OODeciCreditsFromPList`, `IsCommandModifierKeyDown`→`isCtrlDown`, `autosavePlayer` (catches OOException) and `nativeSavePlayer` (`SaveFileName` path-extension rule). Out-of-range `cdrDetailArray` guards return quietly where upstream raised.

## PlayerEntityScriptMethods

<a id="playerentityscriptmethods"></a>
Upstream `src/Core/Entities/PlayerEntityScriptMethods.m` ↔ `Core/Entities/PlayerEntityScriptMethods.cpp` (576 / 600 lines)

**Status:** done — 35 rows: 35 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(ScriptMethods) score]` (40) | `PlayerEntity::score` Core/Entities/PlayerEntityScriptMethods.cpp:78 | ✅ |
| `-[PlayerEntity(ScriptMethods) setScore:]` (45) | `PlayerEntity::setScore` Core/Entities/PlayerEntityScriptMethods.cpp:80 | ✅ |
| `-[PlayerEntity(ScriptMethods) creditBalance]` (50) | `PlayerEntity::creditBalance` Core/Entities/PlayerEntityScriptMethods.cpp:82 | ✅ |
| `-[PlayerEntity(ScriptMethods) setCreditBalance:]` (55) | `PlayerEntity::setCreditBalance` Core/Entities/PlayerEntityScriptMethods.cpp:84 | ✅ |
| `-[PlayerEntity(ScriptMethods) dockedStationName]` (60) | `PlayerEntity::dockedStationName` Core/Entities/PlayerEntityScriptMethods.cpp:88 | ✅ |
| `-[PlayerEntity(ScriptMethods) dockedStationDisplayName]` (65) | `PlayerEntity::dockedStationDisplayName` Core/Entities/PlayerEntityScriptMethods.cpp:93 | ✅ |
| `-[PlayerEntity(ScriptMethods) dockedAtMainStation]` (70) | `PlayerEntity::dockedAtMainStation` Core/Entities/PlayerEntityScriptMethods.cpp:98 | ✅ |
| `-[PlayerEntity(ScriptMethods) awardCommodityType:amount:]` (75) | `PlayerEntity::awardCommodityType` Core/Entities/PlayerEntityScriptMethods.cpp:104 | ✅ |
| `-[PlayerEntity(ScriptMethods) resetScannerZoom]` (148) | `PlayerEntity::resetScannerZoom` Core/Entities/PlayerEntityScriptMethods.cpp:198 | ✅ |
| `-[PlayerEntity(ScriptMethods) currentGalaxyID]` (153) | `PlayerEntity::currentGalaxyID` Core/Entities/PlayerEntityScriptMethods.cpp:202 | ✅ |
| `-[PlayerEntity(ScriptMethods) currentSystemID]` (158) | `PlayerEntity::currentSystemID` Core/Entities/PlayerEntityScriptMethods.cpp:204 | ✅ |
| `-[PlayerEntity(ScriptMethods) setMissionChoice:]` (165) | `PlayerEntity::setMissionChoice(newChoice)` Core/Entities/PlayerEntityScriptMethods.cpp:210 | ✅ |
| `-[PlayerEntity(ScriptMethods) setMissionChoice:withEvent:]` (170) | `PlayerEntity::setMissionChoice(newChoice, withEvent)` Core/Entities/PlayerEntityScriptMethods.cpp:215 | ✅ |
| `-[PlayerEntity(ScriptMethods) setMissionChoice:keyPress:]` (175) | `PlayerEntity::setMissionChoice(newChoice, keyPress)` Core/Entities/PlayerEntityScriptMethods.cpp:220 | ✅ |
| `-[PlayerEntity(ScriptMethods) setMissionChoice:keyPress:withEvent:]` (180) | `PlayerEntity::setMissionChoice(newChoice, keyPress, withEvent)` Core/Entities/PlayerEntityScriptMethods.cpp:226 | ✅ |
| `-[PlayerEntity(ScriptMethods) allowMissionInterrupt]` (202) | `PlayerEntity::allowMissionInterrupt` Core/Entities/PlayerEntityScriptMethods.cpp:248 | ✅ |
| `-[PlayerEntity(ScriptMethods) scriptTimer]` (207) | `PlayerEntity::scriptTimer` Core/Entities/PlayerEntityScriptMethods.cpp:250 | ✅ |
| `-[PlayerEntity(ScriptMethods) systemPseudoRandom100]` (215) | `PlayerEntity::systemPseudoRandom100` Core/Entities/PlayerEntityScriptMethods.cpp:255 | ✅ |
| `-[PlayerEntity(ScriptMethods) systemPseudoRandom256]` (221) | `PlayerEntity::systemPseudoRandom256` Core/Entities/PlayerEntityScriptMethods.cpp:263 | ✅ |
| `-[PlayerEntity(ScriptMethods) systemPseudoRandomFloat]` (227) | `PlayerEntity::systemPseudoRandomFloat` Core/Entities/PlayerEntityScriptMethods.cpp:271 | ✅ |
| `-[PlayerEntity(ScriptMethods) passengerContractMarker:]` (238) | `PlayerEntity::passengerContractMarker` Core/Entities/PlayerEntityScriptMethods.cpp:284 | ✅ |
| `-[PlayerEntity(ScriptMethods) parcelContractMarker:]` (248) | `PlayerEntity::parcelContractMarker` Core/Entities/PlayerEntityScriptMethods.cpp:288 | ✅ |
| `-[PlayerEntity(ScriptMethods) cargoContractMarker:]` (258) | `PlayerEntity::cargoContractMarker` Core/Entities/PlayerEntityScriptMethods.cpp:292 | ✅ |
| `-[PlayerEntity(ScriptMethods) defaultMarker:]` (268) | `PlayerEntity::defaultMarker` Core/Entities/PlayerEntityScriptMethods.cpp:296 | ✅ |
| `-[PlayerEntity(ScriptMethods) validatedMarker:]` (278) | `PlayerEntity::validatedMarker` Core/Entities/PlayerEntityScriptMethods.cpp:300 | ✅ |
| `-[PlayerEntity(ScriptMethods) creditsFormattedForSubstitution]` (301) | `PlayerEntity::creditsFormattedForSubstitution` Core/Entities/PlayerEntityScriptMethods.cpp:327 | ✅ |
| `-[PlayerEntity(ScriptMethods) creditsFormattedForLegacySubstitution]` (312) | `PlayerEntity::creditsFormattedForLegacySubstitution` Core/Entities/PlayerEntityScriptMethods.cpp:339 | ✅ |
| `-[PlayerEntity(ScriptMethods) commanderBountyAsString]` (322) | `PlayerEntity::commanderBountyAsString` Core/Entities/PlayerEntityScriptMethods.cpp:348 | ✅ |
| `-[PlayerEntity(ScriptMethods) commanderKillsAsString]` (328) | `PlayerEntity::commanderKillsAsString` Core/Entities/PlayerEntityScriptMethods.cpp:353 | ✅ |
| `-[PlayerEntity(ScriptMethods) keyBindingDescription2:]` (334) | `PlayerEntity::keyBindingDescription2` Core/Entities/PlayerEntityScriptMethods.cpp:358 | ✅ |
| `-[PlayerEntity(ScriptMethods) getKeyBindingDescription:]` (344) | `PlayerEntity::getKeyBindingDescription` Core/Entities/PlayerEntityScriptMethods.cpp:370 | ✅ |
| `-[PlayerEntity(ScriptMethods) keyCodeDescription:]` (369) | `PlayerEntity::keyCodeDescription` Core/Entities/PlayerEntityScriptMethods.cpp:394 | ✅ |
| `-[PlayerEntity(ScriptMethods) keyCodeDescriptionShort:]` (468) | `PlayerEntity::keyCodeDescriptionShort` Core/Entities/PlayerEntityScriptMethods.cpp:493 | ✅ |
| `OOGalacticCoordinatesFromInternal` (568) | `OOGalacticCoordinatesFromInternal` Core/Entities/PlayerEntityScriptMethods.cpp:592 | ✅ |
| `OOInternalCoordinatesFromGalactic` (573) | `OOInternalCoordinatesFromGalactic` Core/Entities/PlayerEntityScriptMethods.cpp:597 | ✅ |

**Differences:**

- ✅ note: the `keyCodeDescription`/`keyCodeDescriptionShort` switch tables match case for case and `DESC` key for `DESC` key (180 tokens, mechanical diff). The default `%C` keeps a single UTF-16 unit — upstream `Core/Entities/PlayerEntityScriptMethods.m:369-566` ↔ port `Core/Entities/PlayerEntityScriptMethods.cpp:394-590`
- ✅ note: `validatedMarker` keeps the nil-marker result `{system = 0}`, the 0..`kOOMaximumSystemID` range check, the `MISSION_DEST_LEGACY`/`redColor`/`MARKER_X` defaults and `markerScale` as a single real — port `Core/Entities/PlayerEntityScriptMethods.cpp:300-324`
- ✅ note: `awardCommodityType` keeps the upstream endless outer `while (amount)` for ton goods while special cargo is aboard, the 1000/1000000 container split and the docked cap at `maxAvailableCargoSpace` — port `Core/Entities/PlayerEntityScriptMethods.cpp:121-195`
- ✅ note: `getKeyBindingDescription` keeps the `" or "` separator, mod2/mod1/shift order and the `k_int != 0` skip; `systemPseudoRandom*` still reseed the planet RNG on every call (FIXME kept) — port `Core/Entities/PlayerEntityScriptMethods.cpp:255-282, 370-392`
- No previous non-✅ findings for this section (previous run 2026-10-27).

## PlayerEntitySound

<a id="playerentitysound"></a>
Upstream `src/Core/Entities/PlayerEntitySound.m` ↔ `Core/Entities/PlayerEntitySound.cpp` (654 / 678 lines)

**Status:** done — 85 rows: 85 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(Sound) setUpSound]` (70) | `PlayerEntity::setUpSound` Core/Entities/PlayerEntitySound.cpp:110 | ✅ |
| `-[PlayerEntity(Sound) setUpWeaponSounds]` (101) | `PlayerEntity::setUpWeaponSounds` Core/Entities/PlayerEntitySound.cpp:150 | ✅ |
| `-[PlayerEntity(Sound) destroySound]` (155) | `PlayerEntity::destroySound` Core/Entities/PlayerEntitySound.cpp:221 | ✅ |
| `-[PlayerEntity(Sound) playInterfaceBeep:]` (178) | `PlayerEntity::playInterfaceBeep` Core/Entities/PlayerEntitySound.cpp:243 | ✅ |
| `-[PlayerEntity(Sound) isBeeping]` (188) | `PlayerEntity::isBeeping` Core/Entities/PlayerEntitySound.cpp:253 | ✅ |
| `-[PlayerEntity(Sound) boop]` (193) | `PlayerEntity::boop` Core/Entities/PlayerEntitySound.cpp:255 | ✅ |
| `-[PlayerEntity(Sound) playIdentOn]` (198) | `PlayerEntity::playIdentOn` Core/Entities/PlayerEntitySound.cpp:257 | ✅ |
| `-[PlayerEntity(Sound) playIdentOff]` (203) | `PlayerEntity::playIdentOff` Core/Entities/PlayerEntitySound.cpp:259 | ✅ |
| `-[PlayerEntity(Sound) playIdentLockedOn]` (208) | `PlayerEntity::playIdentLockedOn` Core/Entities/PlayerEntitySound.cpp:261 | ✅ |
| `-[PlayerEntity(Sound) playMissileArmed]` (213) | `PlayerEntity::playMissileArmed` Core/Entities/PlayerEntitySound.cpp:265 | ✅ |
| `-[PlayerEntity(Sound) playMineArmed]` (218) | `PlayerEntity::playMineArmed` Core/Entities/PlayerEntitySound.cpp:267 | ✅ |
| `-[PlayerEntity(Sound) playMissileSafe]` (223) | `PlayerEntity::playMissileSafe` Core/Entities/PlayerEntitySound.cpp:269 | ✅ |
| `-[PlayerEntity(Sound) playMissileLockedOn]` (228) | `PlayerEntity::playMissileLockedOn` Core/Entities/PlayerEntitySound.cpp:271 | ✅ |
| `-[PlayerEntity(Sound) playNextEquipmentSelected]` (233) | `PlayerEntity::playNextEquipmentSelected` Core/Entities/PlayerEntitySound.cpp:275 | ✅ |
| `-[PlayerEntity(Sound) playNextMissileSelected]` (238) | `PlayerEntity::playNextMissileSelected` Core/Entities/PlayerEntitySound.cpp:279 | ✅ |
| `-[PlayerEntity(Sound) playWeaponsOnline]` (243) | `PlayerEntity::playWeaponsOnline` Core/Entities/PlayerEntitySound.cpp:283 | ✅ |
| `-[PlayerEntity(Sound) playWeaponsOffline]` (248) | `PlayerEntity::playWeaponsOffline` Core/Entities/PlayerEntitySound.cpp:287 | ✅ |
| `-[PlayerEntity(Sound) playCargoJettisioned]` (253) | `PlayerEntity::playCargoJettisioned` Core/Entities/PlayerEntitySound.cpp:291 | ✅ |
| `-[PlayerEntity(Sound) playAutopilotOn]` (258) | `PlayerEntity::playAutopilotOn` Core/Entities/PlayerEntitySound.cpp:295 | ✅ |
| `-[PlayerEntity(Sound) playAutopilotOff]` (263) | `PlayerEntity::playAutopilotOff` Core/Entities/PlayerEntitySound.cpp:297 | ✅ |
| `-[PlayerEntity(Sound) playAutopilotOutOfRange]` (271) | `PlayerEntity::playAutopilotOutOfRange` Core/Entities/PlayerEntitySound.cpp:304 | ✅ |
| `-[PlayerEntity(Sound) playAutopilotCannotDockWithTarget]` (276) | `PlayerEntity::playAutopilotCannotDockWithTarget` Core/Entities/PlayerEntitySound.cpp:308 | ✅ |
| `-[PlayerEntity(Sound) playSaveOverwriteYes]` (281) | `PlayerEntity::playSaveOverwriteYes` Core/Entities/PlayerEntitySound.cpp:312 | ✅ |
| `-[PlayerEntity(Sound) playSaveOverwriteNo]` (286) | `PlayerEntity::playSaveOverwriteNo` Core/Entities/PlayerEntitySound.cpp:316 | ✅ |
| `-[PlayerEntity(Sound) playHoldFull]` (291) | `PlayerEntity::playHoldFull` Core/Entities/PlayerEntitySound.cpp:320 | ✅ |
| `-[PlayerEntity(Sound) playJumpMassLocked]` (296) | `PlayerEntity::playJumpMassLocked` Core/Entities/PlayerEntitySound.cpp:322 | ✅ |
| `-[PlayerEntity(Sound) playTargetLost]` (301) | `PlayerEntity::playTargetLost` Core/Entities/PlayerEntitySound.cpp:326 | ✅ |
| `-[PlayerEntity(Sound) playNoTargetInMemory]` (306) | `PlayerEntity::playNoTargetInMemory` Core/Entities/PlayerEntitySound.cpp:328 | ✅ |
| `-[PlayerEntity(Sound) playTargetSwitched]` (311) | `PlayerEntity::playTargetSwitched` Core/Entities/PlayerEntitySound.cpp:332 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceNoTarget]` (316) | `PlayerEntity::playHyperspaceNoTarget` Core/Entities/PlayerEntitySound.cpp:336 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceNoFuel]` (321) | `PlayerEntity::playHyperspaceNoFuel` Core/Entities/PlayerEntitySound.cpp:340 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceBlocked]` (326) | `PlayerEntity::playHyperspaceBlocked` Core/Entities/PlayerEntitySound.cpp:344 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceDistanceTooGreat]` (331) | `PlayerEntity::playHyperspaceDistanceTooGreat` Core/Entities/PlayerEntitySound.cpp:348 | ✅ |
| `-[PlayerEntity(Sound) playCloakingDeviceOn]` (336) | `PlayerEntity::playCloakingDeviceOn` Core/Entities/PlayerEntitySound.cpp:352 | ✅ |
| `-[PlayerEntity(Sound) playCloakingDeviceOff]` (341) | `PlayerEntity::playCloakingDeviceOff` Core/Entities/PlayerEntitySound.cpp:356 | ✅ |
| `-[PlayerEntity(Sound) playMenuNavigationUp]` (346) | `PlayerEntity::playMenuNavigationUp` Core/Entities/PlayerEntitySound.cpp:360 | ✅ |
| `-[PlayerEntity(Sound) playMenuNavigationDown]` (351) | `PlayerEntity::playMenuNavigationDown` Core/Entities/PlayerEntitySound.cpp:364 | ✅ |
| `-[PlayerEntity(Sound) playMenuNavigationNot]` (356) | `PlayerEntity::playMenuNavigationNot` Core/Entities/PlayerEntitySound.cpp:368 | ✅ |
| `-[PlayerEntity(Sound) playMenuPagePrevious]` (361) | `PlayerEntity::playMenuPagePrevious` Core/Entities/PlayerEntitySound.cpp:372 | ✅ |
| `-[PlayerEntity(Sound) playMenuPageNext]` (366) | `PlayerEntity::playMenuPageNext` Core/Entities/PlayerEntitySound.cpp:376 | ✅ |
| `-[PlayerEntity(Sound) playDismissedReportScreen]` (371) | `PlayerEntity::playDismissedReportScreen` Core/Entities/PlayerEntitySound.cpp:380 | ✅ |
| `-[PlayerEntity(Sound) playDismissedMissionScreen]` (376) | `PlayerEntity::playDismissedMissionScreen` Core/Entities/PlayerEntitySound.cpp:384 | ✅ |
| `-[PlayerEntity(Sound) playChangedOption]` (381) | `PlayerEntity::playChangedOption` Core/Entities/PlayerEntitySound.cpp:388 | ✅ |
| `-[PlayerEntity(Sound) updateFuelScoopSoundWithInterval:]` (386) | `PlayerEntity::updateFuelScoopSoundWithInterval` Core/Entities/PlayerEntitySound.cpp:392 | ✅ |
| `-[PlayerEntity(Sound) updateAfterburnerSound]` (407) | `PlayerEntity::updateAfterburnerSound` Core/Entities/PlayerEntitySound.cpp:413 | ✅ |
| `-[PlayerEntity(Sound) startAfterburnerSound]` (426) | `PlayerEntity::startAfterburnerSound` Core/Entities/PlayerEntitySound.cpp:437 | ✅ |
| `-[PlayerEntity(Sound) stopAfterburnerSound]` (434) | `PlayerEntity::stopAfterburnerSound` Core/Entities/PlayerEntitySound.cpp:444 | ✅ |
| `-[PlayerEntity(Sound) playCloakingDeviceInsufficientEnergy]` (439) | `PlayerEntity::playCloakingDeviceInsufficientEnergy` Core/Entities/PlayerEntitySound.cpp:448 | ✅ |
| `-[PlayerEntity(Sound) playBuyCommodity]` (444) | `PlayerEntity::playBuyCommodity` Core/Entities/PlayerEntitySound.cpp:452 | ✅ |
| `-[PlayerEntity(Sound) playBuyShip]` (449) | `PlayerEntity::playBuyShip` Core/Entities/PlayerEntitySound.cpp:457 | ✅ |
| `-[PlayerEntity(Sound) playSellCommodity]` (454) | `PlayerEntity::playSellCommodity` Core/Entities/PlayerEntitySound.cpp:462 | ✅ |
| `-[PlayerEntity(Sound) playCantBuyCommodity]` (459) | `PlayerEntity::playCantBuyCommodity` Core/Entities/PlayerEntitySound.cpp:467 | ✅ |
| `-[PlayerEntity(Sound) playCantSellCommodity]` (464) | `PlayerEntity::playCantSellCommodity` Core/Entities/PlayerEntitySound.cpp:472 | ✅ |
| `-[PlayerEntity(Sound) playCantBuyShip]` (469) | `PlayerEntity::playCantBuyShip` Core/Entities/PlayerEntitySound.cpp:477 | ✅ |
| `-[PlayerEntity(Sound) playStandardHyperspace]` (474) | `PlayerEntity::playStandardHyperspace` Core/Entities/PlayerEntitySound.cpp:482 | ✅ |
| `-[PlayerEntity(Sound) playGalacticHyperspace]` (479) | `PlayerEntity::playGalacticHyperspace` Core/Entities/PlayerEntitySound.cpp:487 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceAborted]` (484) | `PlayerEntity::playHyperspaceAborted` Core/Entities/PlayerEntitySound.cpp:492 | ✅ |
| `-[PlayerEntity(Sound) playHitByECMSound]` (489) | `PlayerEntity::playHitByECMSound` Core/Entities/PlayerEntitySound.cpp:497 | ✅ |
| `-[PlayerEntity(Sound) playFiredECMSound]` (495) | `PlayerEntity::playFiredECMSound` Core/Entities/PlayerEntitySound.cpp:503 | ✅ |
| `-[PlayerEntity(Sound) playLaunchFromStation]` (501) | `PlayerEntity::playLaunchFromStation` Core/Entities/PlayerEntitySound.cpp:509 | ✅ |
| `-[PlayerEntity(Sound) playDockWithStation]` (506) | `PlayerEntity::playDockWithStation` Core/Entities/PlayerEntitySound.cpp:514 | ✅ |
| `-[PlayerEntity(Sound) playExitWitchspace]` (511) | `PlayerEntity::playExitWitchspace` Core/Entities/PlayerEntitySound.cpp:519 | ✅ |
| `-[PlayerEntity(Sound) playHostileWarning]` (516) | `PlayerEntity::playHostileWarning` Core/Entities/PlayerEntitySound.cpp:524 | ✅ |
| `-[PlayerEntity(Sound) playAlertConditionRed]` (521) | `PlayerEntity::playAlertConditionRed` Core/Entities/PlayerEntitySound.cpp:530 | ✅ |
| `-[PlayerEntity(Sound) playIncomingMissile:]` (526) | `PlayerEntity::playIncomingMissile` Core/Entities/PlayerEntitySound.cpp:536 | ✅ |
| `-[PlayerEntity(Sound) playEnergyLow]` (531) | `PlayerEntity::playEnergyLow` Core/Entities/PlayerEntitySound.cpp:542 | ✅ |
| `-[PlayerEntity(Sound) playDockingDenied]` (536) | `PlayerEntity::playDockingDenied` Core/Entities/PlayerEntitySound.cpp:548 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpFailure]` (541) | `PlayerEntity::playWitchjumpFailure` Core/Entities/PlayerEntitySound.cpp:554 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpMisjump]` (546) | `PlayerEntity::playWitchjumpMisjump` Core/Entities/PlayerEntitySound.cpp:560 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpBlocked]` (551) | `PlayerEntity::playWitchjumpBlocked` Core/Entities/PlayerEntitySound.cpp:566 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpDistanceTooGreat]` (556) | `PlayerEntity::playWitchjumpDistanceTooGreat` Core/Entities/PlayerEntitySound.cpp:572 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpInsufficientFuel]` (561) | `PlayerEntity::playWitchjumpInsufficientFuel` Core/Entities/PlayerEntitySound.cpp:578 | ✅ |
| `-[PlayerEntity(Sound) playFuelLeak]` (566) | `PlayerEntity::playFuelLeak` Core/Entities/PlayerEntitySound.cpp:584 | ✅ |
| `-[PlayerEntity(Sound) playShieldHit:weaponIdentifier:]` (571) | `PlayerEntity::playShieldHit` Core/Entities/PlayerEntitySound.cpp:590 | ✅ |
| `-[PlayerEntity(Sound) playDirectHit:weaponIdentifier:]` (579) | `PlayerEntity::playDirectHit` Core/Entities/PlayerEntitySound.cpp:599 | ✅ |
| `-[PlayerEntity(Sound) playScrapeDamage:]` (587) | `PlayerEntity::playScrapeDamage` Core/Entities/PlayerEntitySound.cpp:608 | ✅ |
| `-[PlayerEntity(Sound) playLaserHit:offset:weaponIdentifier:]` (592) | `PlayerEntity::playLaserHit` Core/Entities/PlayerEntitySound.cpp:614 | ✅ |
| `-[PlayerEntity(Sound) playWeaponOverheated:]` (608) | `PlayerEntity::playWeaponOverheated` Core/Entities/PlayerEntitySound.cpp:630 | ✅ |
| `-[PlayerEntity(Sound) playMissileLaunched:weaponIdentifier:]` (613) | `PlayerEntity::playMissileLaunched` Core/Entities/PlayerEntitySound.cpp:636 | ✅ |
| `-[PlayerEntity(Sound) playMineLaunched:weaponIdentifier:]` (621) | `PlayerEntity::playMineLaunched` Core/Entities/PlayerEntitySound.cpp:644 | ✅ |
| `-[PlayerEntity(Sound) playEscapePodScooped]` (629) | `PlayerEntity::playEscapePodScooped` Core/Entities/PlayerEntitySound.cpp:652 | ✅ |
| `-[PlayerEntity(Sound) playAegisCloseToPlanet]` (634) | `PlayerEntity::playAegisCloseToPlanet` Core/Entities/PlayerEntitySound.cpp:658 | ✅ |
| `-[PlayerEntity(Sound) playAegisCloseToStation]` (639) | `PlayerEntity::playAegisCloseToStation` Core/Entities/PlayerEntitySound.cpp:664 | ✅ |
| `-[PlayerEntity(Sound) playGameOver]` (644) | `PlayerEntity::playGameOver` Core/Entities/PlayerEntitySound.cpp:670 | ✅ |
| `-[PlayerEntity(Sound) playLegacyScriptSound:]` (649) | `PlayerEntity::playLegacyScriptSound` Core/Entities/PlayerEntitySound.cpp:675 | ✅ |

**Differences:**

- ✅ note: every `play…` method uses the same custom-sound key and the same source/pool as upstream, including the swapped `[menu-next-page]`/`[menu-previous-page]` and the `[cloaking-device-insufficent-energy]` spelling. Pool sizes 4/6/3/4/2, the damage pool's 0.1 s repeat, warning priorities (1, 2, 3, 0.5, 1, 1.5, 1.5, 1.3, 1.3, 1.3, 0.5), laser 1.0/0.05/overlap, overheat overlap NO and legacy priority 1.1 all match — port `Core/Entities/PlayerEntitySound.cpp:36-40, 110-145, 243-678`
- ✅ note: the nil-source/nil-pool semantics are kept (`IsPlaying`, null checks, `OOSoundSourcePlayCustomSoundWithKey` returns on null and skips a nil sound as `-playCustomSoundWithKey:` did) — port `Core/Universe.cpp:1168-1173`
- ✅ note: `updateAfterburnerSound` re-arms through `oo::ScheduleEntityCall(this, …, 1.25)` in place of `performSelector:afterDelay:`; the weapon-sound maps are `std::map`, only looked up, with `""` for a missing sound name and the same fallback keys — port `Core/Entities/PlayerEntitySound.cpp:99-106, 150-219, 413-435`
- No previous non-✅ findings for this section (previous run 2026-10-27). The previous run listed 86 rows; this extraction has 85 and no row was missed.

## PlayerEntityStickMapper

<a id="playerentitystickmapper"></a>
Upstream `src/Core/Entities/PlayerEntityStickMapper.m` ↔ `Core/Entities/PlayerEntityStickMapper.cpp` (910 / 896 lines)

**Status:** done — 13 rows: 12 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(StickMapper) resetStickFunctions]` (48) | `PlayerEntity::resetStickFunctions` Core/Entities/PlayerEntityStickMapper.cpp:133 | ✅ |
| `-[PlayerEntity(StickMapper) setGuiToStickMapperScreen:]` (54) | `PlayerEntity::setGuiToStickMapperScreen(skip)` Core/Entities/PlayerEntityStickMapper.cpp:135 | ✅ |
| `-[PlayerEntity(StickMapper) setGuiToStickMapperScreen:resetCurrentRow:]` (59) | `PlayerEntity::setGuiToStickMapperScreen(skip, resetCurrentRow)` Core/Entities/PlayerEntityStickMapper.cpp:139 | ✅ |
| `-[PlayerEntity(StickMapper) stickMapperInputHandler:view:]` (124) | `PlayerEntity::stickMapperInputHandler` Core/Entities/PlayerEntityStickMapper.cpp:210 | ✅ |
| `-[PlayerEntity(StickMapper) updateFunction:]` (201) | `PlayerEntity::updateFunction` Core/Entities/PlayerEntityStickMapper.cpp:287 | ❌ |
| `-[PlayerEntity(StickMapper) checkCustomEquipButtons:ignore:]` (287) | `PlayerEntity::checkCustomEquipButtons` Core/Entities/PlayerEntityStickMapper.cpp:378 | ✅ |
| `-[PlayerEntity(StickMapper) removeFunction:]` (311) | `PlayerEntity::removeFunction` Core/Entities/PlayerEntityStickMapper.cpp:409 | ✅ |
| `-[PlayerEntity(StickMapper) displayFunctionList:skip:]` (362) | `PlayerEntity::displayFunctionList` Core/Entities/PlayerEntityStickMapper.cpp:458 | ✅ |
| `-[PlayerEntity(StickMapper) describeStickDict:]` (491) | `PlayerEntity::describeStickDict` Core/Entities/PlayerEntityStickMapper.cpp:602 | ✅ |
| `-[PlayerEntity(StickMapper) hwToString:]` (516) | `PlayerEntity::hwToString` Core/Entities/PlayerEntityStickMapper.cpp:631 | ✅ |
| `-[PlayerEntity(StickMapper) stickFunctionList]` (534) | `PlayerEntity::stickFunctionList` Core/Entities/PlayerEntityStickMapper.cpp:648 | ✅ |
| `-[PlayerEntity(StickMapper) makeStickGuiDict:allowable:axisfn:butfn:]` (879) | `PlayerEntity::makeStickGuiDict` Core/Entities/PlayerEntityStickMapper.cpp:874 | ✅ |
| `-[PlayerEntity(StickMapper) makeStickGuiDictHeader:]` (900) | `PlayerEntity::makeStickGuiDictHeader` Core/Entities/PlayerEntityStickMapper.cpp:889 | ✅ |

**Differences:**

- ❌ **low** — The "called when not on stick mapper screen" error logs `__PRETTY_FUNCTION__`, so the line shows the C++ signature (`void PlayerEntity::updateFunction(const oo::PList&)`) where upstream printed `-[PlayerEntity(StickMapper) updateFunction:]`; the class `joystick.configure.error` is unchanged (still open) — upstream `Core/Entities/PlayerEntityStickMapper.m:208` ↔ port `Core/Entities/PlayerEntityStickMapper.cpp:295-296`
- ✅ note: `stickFunctionList` has the same 266 tokens (`stickmapper-*` keys, `HW_*`/`AXIS_*`/`BUTTON_*`, `#if` FOV block, `10000`/`20000` offsets) in the same order (mechanical diff); `makeStickGuiDict` still cuts at 28 UTF-16 units above 50 — port `Core/Entities/PlayerEntityStickMapper.cpp:648-887`
- ✅ note: the stick-name truncation (5 units + `"..."` while wider than 18 em / 11 em), the cross-unsetting in `updateFunction`, the paging maths and the hat description `(n - MAX_REAL_BUTTONS)/4 + 1`, `dir[n & 3]` match. In-place edits of `customEquipActivation` replace `mutableCopy` + `replaceObjectAtIndex:` with the same result — port `Core/Entities/PlayerEntityStickMapper.cpp:157-186, 341-363, 378-407, 602-629`
- ✅ **low** (note) — An out-of-range `stickFunctions`/`customEquipActivation` index gives a null entry where upstream `objectAtIndex:` raised; it is not reachable from the GUI (only `Index:` rows set `selFunctionIdx >= 0`) — upstream `Core/Entities/PlayerEntityStickMapper.m:171, 213` ↔ port `Core/Entities/PlayerEntityStickMapper.cpp:106-129, 259, 301`

## PlayerEntityStickProfile

<a id="playerentitystickprofile"></a>
Upstream `src/Core/Entities/PlayerEntityStickProfile.m` ↔ `Core/Entities/PlayerEntityStickProfile.cpp` (597 / 601 lines)

**Status:** done — 26 rows: 25 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(StickProfile) setGuiToStickProfileScreen:]` (69) | `PlayerEntity::setGuiToStickProfileScreen` Core/Entities/PlayerEntityStickProfile.cpp:66 | ✅ |
| `-[PlayerEntity(StickProfile) stickProfileInputHandler:view:]` (76) | `PlayerEntity::stickProfileInputHandler` Core/Entities/PlayerEntityStickProfile.cpp:73 | ✅ |
| `-[PlayerEntity(StickProfile) stickProfileGraphAxisProfile:screenAt:screenSize:]` (180) | `PlayerEntity::stickProfileGraphAxisProfile` Core/Entities/PlayerEntityStickProfile.cpp:203 | ✅ |
| `-[StickProfileScreen init]` (191) | `StickProfileScreen::StickProfileScreen` Core/Entities/PlayerEntityStickProfile.cpp:215 | ✅ |
| `-[StickProfileScreen dealloc]` (207) | `oo::Ref`/`shared_ptr` member `profiles[3][2]` destruction, Core/Entities/PlayerEntityStickProfile.h:76 | ➖ |
| `-[StickProfileScreen startGui:]` (217) | `StickProfileScreen::startGui` Core/Entities/PlayerEntityStickProfile.cpp:221 | ✅ |
| `-[StickProfileScreen mouseDown:]` (228) | `StickProfileScreen::mouseDown` Core/Entities/PlayerEntityStickProfile.cpp:231 | ✅ |
| `-[StickProfileScreen mouseUp]` (253) | `StickProfileScreen::mouseUp` Core/Entities/PlayerEntityStickProfile.cpp:259 | ✅ |
| `-[StickProfileScreen deleteSelected]` (262) | `StickProfileScreen::deleteSelected` Core/Entities/PlayerEntityStickProfile.cpp:267 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) nextAxis]` (280) | `StickProfileScreen::nextAxis` Core/Entities/PlayerEntityStickProfile.cpp:281 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) previousAxis]` (290) | `StickProfileScreen::previousAxis` Core/Entities/PlayerEntityStickProfile.cpp:290 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) currentAxis]` (300) | `StickProfileScreen::currentAxis` Core/Entities/PlayerEntityStickProfile.cpp:299 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) increaseDeadzone]` (315) | `StickProfileScreen::increaseDeadzone` Core/Entities/PlayerEntityStickProfile.cpp:313 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) decreaseDeadzone]` (325) | `StickProfileScreen::decreaseDeadzone` Core/Entities/PlayerEntityStickProfile.cpp:323 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) nextProfileType]` (335) | `StickProfileScreen::nextProfileType` Core/Entities/PlayerEntityStickProfile.cpp:333 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) previousProfileType]` (355) | `StickProfileScreen::previousProfileType` Core/Entities/PlayerEntityStickProfile.cpp:352 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) currentProfileIsSpline]` (375) | `StickProfileScreen::currentProfileIsSpline` Core/Entities/PlayerEntityStickProfile.cpp:372 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) IncreasePower]` (383) | `StickProfileScreen::IncreasePower` Core/Entities/PlayerEntityStickProfile.cpp:380 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) DecreasePower]` (397) | `StickProfileScreen::DecreasePower` Core/Entities/PlayerEntityStickProfile.cpp:395 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) IncreaseParam]` (411) | `StickProfileScreen::IncreaseParam` Core/Entities/PlayerEntityStickProfile.cpp:410 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) DecreaseParam]` (425) | `StickProfileScreen::DecreaseParam` Core/Entities/PlayerEntityStickProfile.cpp:424 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) graphProfile:at:size:]` (439) | `StickProfileScreen::graphProfile` Core/Entities/PlayerEntityStickProfile.cpp:438 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) startEdit]` (487) | `StickProfileScreen::startEdit` Core/Entities/PlayerEntityStickProfile.cpp:496 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) saveSettings]` (504) | `StickProfileScreen::saveSettings` Core/Entities/PlayerEntityStickProfile.cpp:511 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) showScreen]` (510) | `StickProfileScreen::showScreen` Core/Entities/PlayerEntityStickProfile.cpp:516 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) profileType]` (584) | `StickProfileScreen::profileType` Core/Entities/PlayerEntityStickProfile.cpp:590 | ✅ |

**Differences:**

- ➖ **low** — `-dealloc` (releasing `profiles[3][2]`) is replaced by destruction of the `std::shared_ptr` members; same effect (still open as ➖) — upstream `Core/Entities/PlayerEntityStickProfile.m:207-215` ↔ port `Core/Entities/PlayerEntityStickProfile.h:76`
- ✅ note: deadzone step `STICK_MAX_DEADZONE / 20`, power step `STICKPROFILE_MAX_POWER / 20`, param ±0.05, the 220×220 graph at (x−110, y−100), the spline hit test, the bar strings (`(int)(v/max·20 + 0.5)`, `20·param`, clamped 0..20), the `%0.4f`/`%.1f`/`%0.2f` formats, tab stops 50/140 and the `(1, 20)` selectable range all match; `isKindOfClass:` is `dynamic_cast` — port `Core/Entities/PlayerEntityStickProfile.cpp:313-436, 438-494, 516-588`
- ✅ **low** (note) — A null `stickProfileScreen` is guarded at every call, matching nil messaging (`!currentProfileIsSpline` on nil is true in both); `showScreen` reads `deadzone` 0.0 for a null profile as `[nil deadzone]` did; `graphRect` and the control-point ivars start zeroed as the ObjC ivars did — port `Core/Entities/PlayerEntityStickProfile.cpp:160-161, 532-533`; `Core/Entities/PlayerEntityStickProfile.h:77-80`

## ProxyPlayerEntity

<a id="proxyplayerentity"></a>
Upstream `src/Core/Entities/ProxyPlayerEntity.m` ↔ `Core/Entities/ProxyPlayerEntity.cpp` (208 / 147 lines)

**Status:** done — 29 rows: 27 ✅ 0 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[ProxyPlayerEntity initWithKey:definition:]` (30) | `ProxyPlayerEntity::newProxyObject` + `initProxyDefaults` Core/Entities/ProxyPlayerEntity.cpp:28, :41 | ✅ |
| `-[ProxyPlayerEntity copyValuesFromPlayer:]` (44) | `ProxyPlayerEntity::copyValuesFromPlayer` Core/Entities/ProxyPlayerEntity.cpp:52 | ✅ |
| `-[ProxyPlayerEntity isPlayerLikeShip]` (63) | `ProxyPlayerEntity::isPlayerLikeShip` Core/Entities/ProxyPlayerEntity.cpp:74 | ✅ |
| `-[ProxyPlayerEntity fuelLeakRate]` (68) | `ProxyPlayerEntity::fuelLeakRate` Core/Entities/ProxyPlayerEntity.cpp:76 | ✅ |
| `-[ProxyPlayerEntity setFuelLeakRate:]` (73) | `ProxyPlayerEntity::setFuelLeakRate` Core/Entities/ProxyPlayerEntity.cpp:78 | ✅ |
| `-[ProxyPlayerEntity massLocked]` (78) | `ProxyPlayerEntity::massLocked` Core/Entities/ProxyPlayerEntity.cpp:82 | ✅ |
| `-[ProxyPlayerEntity setMassLocked:]` (83) | `ProxyPlayerEntity::setMassLocked` Core/Entities/ProxyPlayerEntity.cpp:84 | ✅ |
| `-[ProxyPlayerEntity atHyperspeed]` (88) | `ProxyPlayerEntity::atHyperspeed` Core/Entities/ProxyPlayerEntity.cpp:86 | ✅ |
| `-[ProxyPlayerEntity setAtHyperspeed:]` (93) | `ProxyPlayerEntity::setAtHyperspeed` Core/Entities/ProxyPlayerEntity.cpp:88 | ✅ |
| `-[ProxyPlayerEntity dialForwardShield]` (98) | `ProxyPlayerEntity::dialForwardShield` Core/Entities/ProxyPlayerEntity.cpp:90 | ✅ |
| `-[ProxyPlayerEntity setDialForwardShield:]` (103) | `ProxyPlayerEntity::setDialForwardShield` Core/Entities/ProxyPlayerEntity.cpp:92 | ✅ |
| `-[ProxyPlayerEntity dialAftShield]` (108) | `ProxyPlayerEntity::dialAftShield` Core/Entities/ProxyPlayerEntity.cpp:96 | ✅ |
| `-[ProxyPlayerEntity setDialAftShield:]` (113) | `ProxyPlayerEntity::setDialAftShield` Core/Entities/ProxyPlayerEntity.cpp:98 | ✅ |
| `-[ProxyPlayerEntity dialMissileStatus]` (118) | `ProxyPlayerEntity::dialMissileStatus` Core/Entities/ProxyPlayerEntity.cpp:102 | ✅ |
| `-[ProxyPlayerEntity setDialMissileStatus:]` (123) | `ProxyPlayerEntity::setDialMissileStatus` Core/Entities/ProxyPlayerEntity.cpp:106 | ✅ |
| `-[ProxyPlayerEntity dialFuelScoopStatus]` (128) | `ProxyPlayerEntity::dialFuelScoopStatus` Core/Entities/ProxyPlayerEntity.cpp:110 | ✅ |
| `-[ProxyPlayerEntity setDialFuelScoopStatus:]` (133) | `ProxyPlayerEntity::setDialFuelScoopStatus` Core/Entities/ProxyPlayerEntity.cpp:114 | ✅ |
| `-[ProxyPlayerEntity compassMode]` (138) | `ProxyPlayerEntity::compassMode` Core/Entities/ProxyPlayerEntity.cpp:118 | ✅ |
| `-[ProxyPlayerEntity setCompassMode:]` (143) | `ProxyPlayerEntity::setCompassMode` Core/Entities/ProxyPlayerEntity.cpp:120 | ✅ |
| `-[ProxyPlayerEntity dialIdentEngaged]` (148) | `ProxyPlayerEntity::dialIdentEngaged` Core/Entities/ProxyPlayerEntity.cpp:124 | ✅ |
| `-[ProxyPlayerEntity setDialIdentEngaged:]` (153) | `ProxyPlayerEntity::setDialIdentEngaged` Core/Entities/ProxyPlayerEntity.cpp:126 | ✅ |
| `-[ProxyPlayerEntity alertCondition]` (158) | `ProxyPlayerEntity::alertCondition` Core/Entities/ProxyPlayerEntity.cpp:130 | ✅ |
| `-[ProxyPlayerEntity setAlertCondition:]` (163) | `ProxyPlayerEntity::setAlertCondition` Core/Entities/ProxyPlayerEntity.cpp:132 | ✅ |
| `-[ProxyPlayerEntity trumbleCount]` (168) | `ProxyPlayerEntity::trumbleCount` Core/Entities/ProxyPlayerEntity.cpp:136 | ✅ |
| `-[ProxyPlayerEntity setTrumbleCount:]` (173) | `ProxyPlayerEntity::setTrumbleCount` Core/Entities/ProxyPlayerEntity.cpp:138 | ✅ |
| `-[ProxyPlayerEntity setTradeInFactor:]` (178) | `ProxyPlayerEntity::setTradeInFactor` Core/Entities/ProxyPlayerEntity.cpp:142 | ✅ |
| `-[ProxyPlayerEntity tradeInFactor]` (183) | `ProxyPlayerEntity::tradeInFactor` Core/Entities/ProxyPlayerEntity.cpp:144 | ✅ |
| `-[Entity(ProxyPlayer) isPlayerLikeShip]` (194) | inlined `dynamic_cast` test in `OOUniformBindingPermitted`, Core/Entities/ShipEntity.cpp:14058 | ➖ |
| `-[PlayerEntity(ProxyPlayer) isPlayerLikeShip]` (203) | inlined `dynamic_cast<PlayerEntity*>` test, Core/Entities/ShipEntity.cpp:14058 | ➖ |

**Differences:**

- ➖ — `-[Entity isPlayerLikeShip]`/`-[PlayerEntity isPlayerLikeShip]` had one caller, `OOUniformBindingPermitted`; it now tests `dynamic_cast<PlayerEntity*> || dynamic_cast<ProxyPlayerEntity*>`, which answers YES for exactly the same two classes. `ProxyPlayerEntity::isPlayerLikeShip` is kept but has no callers (still open as ➖) — upstream `Core/Entities/ShipEntity.m:13028` ↔ port `Core/Entities/ShipEntity.cpp:14058-14063`
- ✅ note: `copyValuesFromPlayer` copies the same 12 fields in upstream order, using the computing `getAlertCondition` as upstream's `-alertCondition` did; the `player != nullptr` ternaries are dead after the early return — port `Core/Entities/ProxyPlayerEntity.cpp:52-72`
- ✅ note: the init defaults (both shields 1.0, scoop status from `hasScoop`, compass from `EQ_ADVANCED_COMPASS`, trade-in 95) run after the ship set-up and only when it succeeded, as after `[super initWithKey:definition:]`; the `fmax` and `!!` setter clamps are kept — port `Core/Entities/ProxyPlayerEntity.cpp:28-50, 78-88`

