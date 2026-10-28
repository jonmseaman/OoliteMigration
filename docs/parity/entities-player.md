# Parity findings: Player entity and its categories

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.


## PlayerEntity

<a id="playerentity"></a>

### PlayerEntity (part 1: lines 1-5981)

Upstream `src/Core/Entities/PlayerEntity.m` lines 1–5981 (up to but excluding `-setBounty:`) ↔ `Core/Entities/PlayerEntity.cpp`

**Status:** done — 258 rows: 248 ✅ 5 ⚠️ 2 ❌ 3 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `PLAYER_DEFAULT_NAME` (89) | `PLAYER_DEFAULT_NAME` `Core/Entities/PlayerEntity.cpp:103` | ✅ |
| `enum { kCommLogTrimThreshold, kCommLogTrimSize }` (91) | enum `Core/Entities/PlayerEntity.cpp:105` | ✅ |
| `kOOLogBuyMountedOK` / `kOOLogBuyMountedFailed` (97) | inlined literals `"equip.buy.mounted"` / `"equip.buy.mounted.failed"` `Core/Entities/PlayerEntity.cpp:9847` | ➖ |
| `kDeadResetTime` (99) | `kDeadResetTime` `Core/Entities/PlayerEntity.cpp:305` | ✅ |
| `gOOPlayer` (101) | `gOOPlayer` `Core/Entities/PlayerEntity.cpp:400` | ✅ |
| `sBaseMass` (102) | `sBaseMass` `Core/Entities/PlayerEntity.cpp:307` | ✅ |
| `STAGE_TRACKING_BEGIN` / `STAGE_TRACKING_END` / `UPDATE_STAGE` macros (2355) | same macros `Core/Entities/PlayerEntity.cpp:334` | ⚠️ |
| `VELOCITY_CLEANUP_MIN/FULL/RATE` (3346) | same macros `Core/Entities/PlayerEntity.cpp:363` | ✅ |
| `+[PlayerEntity sharedPlayer]` (168) | `sharedPlayer` `Core/Entities/PlayerEntity.cpp:422` | ✅ |
| `-[PlayerEntity setName:]` (176) | `setName` `Core/Entities/PlayerEntity.cpp:525` | ✅ |
| `-[PlayerEntity baseMass]` (181) | `baseMass` `Core/Entities/PlayerEntity.cpp:530` | ✅ |
| `-[PlayerEntity unloadAllCargoPodsForType:toManifest:]` (199) | `unloadAllCargoPodsForType` `Core/Entities/PlayerEntity.cpp:548` | ✅ |
| `-[PlayerEntity unloadCargoPodsForType:amount:]` (223) | `unloadCargoPodsForType` `Core/Entities/PlayerEntity.cpp:572` | ✅ |
| `-[PlayerEntity unloadCargoPods]` (263) | `unloadCargoPods` `Core/Entities/PlayerEntity.cpp:614` | ✅ |
| `-[PlayerEntity createCargoPodWithType:andAmount:]` (282) | `createCargoPodWithType` `Core/Entities/PlayerEntity.cpp:632` | ✅ |
| `-[PlayerEntity loadCargoPodsForType:fromManifest:]` (299) | `loadCargoPodsForType` `Core/Entities/PlayerEntity.cpp:652` | ✅ |
| `-[PlayerEntity loadCargoPodsForType:amount:]` (359) | `loadCargoPodsForType` `Core/Entities/PlayerEntity.cpp:712` | ✅ |
| `-[PlayerEntity loadCargoPods]` (410) | `loadCargoPods` `Core/Entities/PlayerEntity.cpp:772` | ✅ |
| `-[PlayerEntity shipCommodityData]` (421) | `getShipCommodityData` `Core/Entities/PlayerEntity.cpp:782` | ✅ |
| `-[PlayerEntity deciCredits]` (426) | `deciCredits` `Core/Entities/PlayerEntity.cpp:787` | ✅ |
| `-[PlayerEntity random_factor]` (431) | `random_factor` `Core/Entities/PlayerEntity.cpp:792` | ✅ |
| `-[PlayerEntity setRandom_factor:]` (436) | `setRandom_factor` `Core/Entities/PlayerEntity.cpp:797` | ✅ |
| `-[PlayerEntity galaxyNumber]` (441) | `galaxyNumber` `Core/Entities/PlayerEntity.cpp:802` | ✅ |
| `-[PlayerEntity galaxy_coordinates]` (446) | `getGalaxy_coordinates` `Core/Entities/PlayerEntity.cpp:807` | ✅ |
| `-[PlayerEntity setGalaxyCoordinates:]` (451) | `setGalaxyCoordinates` `Core/Entities/PlayerEntity.cpp:812` | ✅ |
| `-[PlayerEntity cursor_coordinates]` (457) | `getCursor_coordinates` `Core/Entities/PlayerEntity.cpp:818` | ✅ |
| `-[PlayerEntity chart_centre_coordinates]` (462) | `getChart_centre_coordinates` `Core/Entities/PlayerEntity.cpp:823` | ✅ |
| `-[PlayerEntity chart_zoom]` (467) | `getChart_zoom` `Core/Entities/PlayerEntity.cpp:828` | ✅ |
| `-[PlayerEntity custom_chart_zoom]` (479) | `getCustom_chart_zoom` `Core/Entities/PlayerEntity.cpp:840` | ✅ |
| `-[PlayerEntity setCustomChartZoom:]` (484) | `setCustomChartZoom` `Core/Entities/PlayerEntity.cpp:845` | ✅ |
| `-[PlayerEntity custom_chart_centre_coordinates]` (489) | `getCustom_chart_centre_coordinates` `Core/Entities/PlayerEntity.cpp:850` | ✅ |
| `-[PlayerEntity setCustomChartCentre:]` (494) | `setCustomChartCentre` `Core/Entities/PlayerEntity.cpp:855` | ✅ |
| `-[PlayerEntity adjusted_chart_centre]` (500) | `adjusted_chart_centre` `Core/Entities/PlayerEntity.cpp:861` | ✅ |
| `-[PlayerEntity ANAMode]` (558) | `ANAMode` `Core/Entities/PlayerEntity.cpp:919` | ✅ |
| `-[PlayerEntity systemID]` (563) | `systemID` `Core/Entities/PlayerEntity.cpp:924` | ✅ |
| `-[PlayerEntity setSystemID:]` (568) | `setSystemID` `Core/Entities/PlayerEntity.cpp:929` | ✅ |
| `-[PlayerEntity previousSystemID]` (576) | `previousSystemID` `Core/Entities/PlayerEntity.cpp:937` | ✅ |
| `-[PlayerEntity setPreviousSystemID:]` (581) | `setPreviousSystemID` `Core/Entities/PlayerEntity.cpp:942` | ✅ |
| `-[PlayerEntity targetSystemID]` (586) | `targetSystemID` `Core/Entities/PlayerEntity.cpp:950` | ✅ |
| `-[PlayerEntity setTargetSystemID:]` (591) | `setTargetSystemID` `Core/Entities/PlayerEntity.cpp:955` | ✅ |
| `-[PlayerEntity nextHopTargetSystemID]` (598) | `nextHopTargetSystemID` `Core/Entities/PlayerEntity.cpp:962` | ✅ |
| `-[PlayerEntity infoSystemID]` (621) | `infoSystemID` `Core/Entities/PlayerEntity.cpp:985` | ✅ |
| `-[PlayerEntity setInfoSystemID:moveChart:]` (626) | `setInfoSystemID` `Core/Entities/PlayerEntity.cpp:990` | ✅ |
| `-[PlayerEntity nextInfoSystem]` (653) | `nextInfoSystem` `Core/Entities/PlayerEntity.cpp:1017` | ✅ |
| `-[PlayerEntity previousInfoSystem]` (680) | `previousInfoSystem` `Core/Entities/PlayerEntity.cpp:1043` | ✅ |
| `-[PlayerEntity homeInfoSystem]` (707) | `homeInfoSystem` `Core/Entities/PlayerEntity.cpp:1069` | ✅ |
| `-[PlayerEntity targetInfoSystem]` (713) | `targetInfoSystem` `Core/Entities/PlayerEntity.cpp:1075` | ✅ |
| `-[PlayerEntity infoSystemOnRoute]` (719) | `infoSystemOnRoute` `Core/Entities/PlayerEntity.cpp:1081` | ✅ |
| `-[PlayerEntity wormhole]` (734) | `getWormhole` `Core/Entities/PlayerEntity.cpp:1097` | ✅ |
| `-[PlayerEntity setWormhole:]` (739) | `setWormhole` `Core/Entities/PlayerEntity.cpp:1102` | ✅ |
| `-[PlayerEntity commanderDataDictionary]` (749) | `commanderDataDictionary` `Core/Entities/PlayerEntity.cpp:1114` | ⚠️ |
| `-[PlayerEntity setCommanderDataFromDictionary:]` (1012) | `setCommanderDataFromDictionary` `Core/Entities/PlayerEntity.cpp:1413` | ❌ |
| `-[PlayerEntity init]` (1595) | `PlayerEntity` `Core/Entities/PlayerEntity.cpp:419` + `newPlayerObject` `Core/Entities/PlayerEntity.cpp:432` | ➖ |
| `-[PlayerEntity deferredInit]` (1601) | `deferredInit` `Core/Entities/PlayerEntity.cpp:443` | ✅ |
| `-[PlayerEntity setUpAndConfirmOK:]` (1639) | `setUpAndConfirmOK` `Core/Entities/PlayerEntity.cpp:1996` | ✅ |
| `-[PlayerEntity setUpAndConfirmOK:saveGame:]` (1644) | `setUpAndConfirmOK` `Core/Entities/PlayerEntity.cpp:2001` | ✅ |
| `-[PlayerEntity completeSetUp]` (2022) | `completeSetUp` `Core/Entities/PlayerEntity.cpp:2364` | ✅ |
| `-[PlayerEntity completeSetUpAndSetTarget:]` (2027) | `completeSetUpAndSetTarget` `Core/Entities/PlayerEntity.cpp:2369` | ✅ |
| `-[PlayerEntity startUpComplete]` (2043) | `startUpComplete` `Core/Entities/PlayerEntity.cpp:2388` | ✅ |
| `-[PlayerEntity setUpShipFromDictionary:]` (2050) | `setUpShipFromDictionary` `Core/Entities/PlayerEntity.cpp:2395` | ✅ |
| `-[PlayerEntity dealloc]` (2145) | `willDealloc` `Core/Entities/PlayerEntity.cpp:483` + `~PlayerEntity` `Core/Entities/PlayerEntity.cpp:420` | ➖ |
| `-[PlayerEntity sessionID]` (2231) | `sessionID` `Core/Entities/PlayerEntity.cpp:2487` | ✅ |
| `-[PlayerEntity warnAboutHostiles]` (2237) | `warnAboutHostiles` `Core/Entities/PlayerEntity.cpp:2493` | ✅ |
| `-[PlayerEntity canCollide]` (2242) | `canCollide` `Core/Entities/PlayerEntity.cpp:2498` | ✅ |
| `-[PlayerEntity compareZeroDistance:]` (2257) | `compareZeroDistance` `Core/Entities/PlayerEntity.cpp:2516` | ✅ |
| `-[PlayerEntity validForAddToUniverse]` (2262) | `validForAddToUniverse` `Core/Entities/PlayerEntity.cpp:2521` | ✅ |
| `-[PlayerEntity lookingAtSunWithThresholdAngleCos:]` (2267) | `lookingAtSunWithThresholdAngleCos` `Core/Entities/PlayerEntity.cpp:2526` | ✅ |
| `-[PlayerEntity insideAtmosphereFraction]` (2342) | `insideAtmosphereFraction` `Core/Entities/PlayerEntity.cpp:2601` | ✅ |
| `-[PlayerEntity update:]` (2380) | `update` `Core/Entities/PlayerEntity.cpp:2613` (calls `getPollControls`) | ✅ |
| `-[PlayerEntity doBookkeeping:]` (2461) | `doBookkeeping` `Core/Entities/PlayerEntity.cpp:2697` | ✅ |
| `-[PlayerEntity updateMovementFlags]` (2885) | `updateMovementFlags` `Core/Entities/PlayerEntity.cpp:3147` | ✅ |
| `-[PlayerEntity updateAlertConditionForNearbyEntities]` (2893) | `updateAlertConditionForNearbyEntities` `Core/Entities/PlayerEntity.cpp:3158` | ✅ |
| `-[PlayerEntity setMaxFlightPitch:]` (2996) | `setMaxFlightPitch` `Core/Entities/PlayerEntity.cpp:3260` | ✅ |
| `-[PlayerEntity setMaxFlightRoll:]` (3002) | `setMaxFlightRoll` `Core/Entities/PlayerEntity.cpp:3266` | ✅ |
| `-[PlayerEntity setMaxFlightYaw:]` (3008) | `setMaxFlightYaw` `Core/Entities/PlayerEntity.cpp:3272` | ✅ |
| `-[PlayerEntity checkEntityForMassLock:withScanClass:]` (3014) | `checkEntityForMassLock` `Core/Entities/PlayerEntity.cpp:3278` | ✅ |
| `-[PlayerEntity updateAlertCondition]` (3068) | `updateAlertCondition` `Core/Entities/PlayerEntity.cpp:3332` | ✅ |
| `-[PlayerEntity updateFuelScoops:]` (3099) | `updateFuelScoops` `Core/Entities/PlayerEntity.cpp:3363` | ✅ |
| `-[PlayerEntity updateClocks:]` (3110) | `updateClocks` `Core/Entities/PlayerEntity.cpp:3374` | ✅ |
| `-[PlayerEntity checkScriptsIfAppropriate]` (3160) | `checkScriptsIfAppropriate` `Core/Entities/PlayerEntity.cpp:3425` | ✅ |
| `-[PlayerEntity updateTrumbles:]` (3211) | `updateTrumbles` `Core/Entities/PlayerEntity.cpp:3476` | ✅ |
| `-[PlayerEntity performAutopilotUpdates:]` (3222) | `performAutopilotUpdates` `Core/Entities/PlayerEntity.cpp:3487` | ✅ |
| `-[PlayerEntity performDockingRequest:]` (3229) | `performDockingRequest` `Core/Entities/PlayerEntity.cpp:3494` | ✅ |
| `-[PlayerEntity requestDockingClearance:]` (3251) | `requestDockingClearance` `Core/Entities/PlayerEntity.cpp:3516` | ✅ |
| `-[PlayerEntity cancelDockingRequest:]` (3258) | `cancelDockingRequest` `Core/Entities/PlayerEntity.cpp:3523` | ✅ |
| `-[PlayerEntity engageAutopilotToStation:]` (3279) | `engageAutopilotToStation` `Core/Entities/PlayerEntity.cpp:3544` | ✅ |
| `-[PlayerEntity disengageAutopilot]` (3314) | `disengageAutopilot` `Core/Entities/PlayerEntity.cpp:3580` | ✅ |
| `-[PlayerEntity resetAutopilotAI]` (3333) | `resetAutopilotAI` `Core/Entities/PlayerEntity.cpp:3602` | ✅ |
| `-[PlayerEntity hyperspeedFactor]` (3351) | `getHyperspeedFactor` `Core/Entities/PlayerEntity.cpp:3621` | ✅ |
| `-[PlayerEntity injectorsEngaged]` (3357) | `injectorsEngaged` `Core/Entities/PlayerEntity.cpp:3627` | ✅ |
| `-[PlayerEntity hyperspeedEngaged]` (3362) | `hyperspeedEngaged` `Core/Entities/PlayerEntity.cpp:3632` | ✅ |
| `-[PlayerEntity performInFlightUpdates:]` (3367) | `performInFlightUpdates` `Core/Entities/PlayerEntity.cpp:3637` | ✅ |
| `-[PlayerEntity performWitchspaceCountdownUpdates:]` (3422) | `performWitchspaceCountdownUpdates` `Core/Entities/PlayerEntity.cpp:3692` | ✅ |
| `-[PlayerEntity performWitchspaceExitUpdates:]` (3479) | `performWitchspaceExitUpdates` `Core/Entities/PlayerEntity.cpp:3752` | ✅ |
| `-[PlayerEntity performLaunchingUpdates:]` (3519) | `performLaunchingUpdates` `Core/Entities/PlayerEntity.cpp:3796` | ✅ |
| `-[PlayerEntity performDockingUpdates:]` (3539) | `performDockingUpdates` `Core/Entities/PlayerEntity.cpp:3816` | ✅ |
| `-[PlayerEntity performDeadUpdates:]` (3551) | `performDeadUpdates` `Core/Entities/PlayerEntity.cpp:3831` | ✅ |
| `-[PlayerEntity gameOverFadeToBW]` (3566) | `gameOverFadeToBW` `Core/Entities/PlayerEntity.cpp:3850` | ✅ |
| `-[PlayerEntity isValidTarget:]` (3595) | `isValidTarget` `Core/Entities/PlayerEntity.cpp:3882` | ✅ |
| `-[PlayerEntity showGameOver]` (3630) | `showGameOver` `Core/Entities/PlayerEntity.cpp:3916` | ✅ |
| `-[PlayerEntity showShipModelWithKey:shipData:personality:factorX:factorY:factorZ:inContext:]` (3646) | `showShipModelWithKey` `Core/Entities/PlayerEntity.cpp:3940` | ✅ |
| `-[PlayerEntity updateTargeting]` (3699) | `updateTargeting` `Core/Entities/PlayerEntity.cpp:4007` | ✅ |
| `-[PlayerEntity orientationChanged]` (3803) | `orientationChanged` `Core/Entities/PlayerEntity.cpp:4123` | ✅ |
| `-[PlayerEntity applyAttitudeChanges:]` (3814) | `applyAttitudeChanges` `Core/Entities/PlayerEntity.cpp:4134` | ✅ |
| `-[PlayerEntity applyRoll:andClimb:]` (3820) | `applyRoll` `Core/Entities/PlayerEntity.cpp:4140` | ✅ |
| `-[PlayerEntity applyYaw:]` (3849) | `applyYaw` `Core/Entities/PlayerEntity.cpp:4169` | ✅ |
| `-[PlayerEntity drawRotationMatrix]` (3856) | `drawRotationMatrix` `Core/Entities/PlayerEntity.cpp:4176` | ✅ |
| `-[PlayerEntity drawTransformationMatrix]` (3861) | `drawTransformationMatrix` `Core/Entities/PlayerEntity.cpp:4181` | ✅ |
| `-[PlayerEntity normalOrientation]` (3868) | `normalOrientation` `Core/Entities/PlayerEntity.cpp:4188` | ✅ |
| `-[PlayerEntity setNormalOrientation:]` (3873) | `setNormalOrientation` `Core/Entities/PlayerEntity.cpp:4193` | ✅ |
| `-[PlayerEntity moveForward:]` (3878) | `moveForward` `Core/Entities/PlayerEntity.cpp:4198` | ✅ |
| `-[PlayerEntity breakPatternPosition]` (3884) | `breakPatternPosition` `Core/Entities/PlayerEntity.cpp:4204` | ✅ |
| `-[PlayerEntity viewpointOffset]` (3889) | `viewpointOffset` `Core/Entities/PlayerEntity.cpp:4209` | ✅ |
| `-[PlayerEntity viewpointOffsetAft]` (3916) | `viewpointOffsetAft` `Core/Entities/PlayerEntity.cpp:4236` | ✅ |
| `-[PlayerEntity viewpointOffsetForward]` (3921) | `viewpointOffsetForward` `Core/Entities/PlayerEntity.cpp:4241` | ✅ |
| `-[PlayerEntity viewpointOffsetPort]` (3926) | `viewpointOffsetPort` `Core/Entities/PlayerEntity.cpp:4246` | ✅ |
| `-[PlayerEntity viewpointOffsetStarboard]` (3931) | `viewpointOffsetStarboard` `Core/Entities/PlayerEntity.cpp:4251` | ✅ |
| `-[PlayerEntity viewpointPosition]` (3938) | `viewpointPosition` `Core/Entities/PlayerEntity.cpp:4258` | ✅ |
| `-[PlayerEntity drawImmediate:translucent:]` (3962) | `drawImmediate` `Core/Entities/PlayerEntity.cpp:4282` | ✅ |
| `-[PlayerEntity setMassLockable:]` (3979) | `setMassLockable` `Core/Entities/PlayerEntity.cpp:4299` | ✅ |
| `-[PlayerEntity massLockable]` (3985) | `getMassLockable` `Core/Entities/PlayerEntity.cpp:4305` | ✅ |
| `-[PlayerEntity massLocked]` (3990) | `massLocked` `Core/Entities/PlayerEntity.cpp:4310` | ✅ |
| `-[PlayerEntity atHyperspeed]` (3995) | `atHyperspeed` `Core/Entities/PlayerEntity.cpp:4315` | ✅ |
| `-[PlayerEntity occlusionLevel]` (4000) | `occlusionLevel` `Core/Entities/PlayerEntity.cpp:4320` | ✅ |
| `-[PlayerEntity setOcclusionLevel:]` (4005) | `setOcclusionLevel` `Core/Entities/PlayerEntity.cpp:4325` | ✅ |
| `-[PlayerEntity setDockedAtMainStation]` (4010) | `setDockedAtMainStation` `Core/Entities/PlayerEntity.cpp:4330` | ✅ |
| `-[PlayerEntity dockedStation]` (4017) | `dockedStation` `Core/Entities/PlayerEntity.cpp:4337` | ✅ |
| `-[PlayerEntity setDockedStation:]` (4022) | `setDockedStation` `Core/Entities/PlayerEntity.cpp:4342` | ✅ |
| `-[PlayerEntity setTargetDockStationTo:]` (4028) | `setTargetDockStationTo` `Core/Entities/PlayerEntity.cpp:4347` | ✅ |
| `-[PlayerEntity getTargetDockStation]` (4033) | `getTargetDockStation` `Core/Entities/PlayerEntity.cpp:4352` | ✅ |
| `-[PlayerEntity hud]` (4038) | `getHud` `Core/Entities/PlayerEntity.cpp:4357` | ✅ |
| `-[PlayerEntity resetHud]` (4043) | `resetHud` `Core/Entities/PlayerEntity.cpp:4362` | ✅ |
| `-[PlayerEntity switchHudTo:]` (4052) | `switchHudTo` `Core/Entities/PlayerEntity.cpp:4371` | ✅ |
| `-[PlayerEntity dialCustomFloat:]` (4112) | `dialCustomFloat` `Core/Entities/PlayerEntity.cpp:4430` | ✅ |
| `-[PlayerEntity dialCustomString:]` (4117) | `dialCustomString` `Core/Entities/PlayerEntity.cpp:4436` | ✅ |
| `-[PlayerEntity dialCustomColor:]` (4122) | `dialCustomColor` `Core/Entities/PlayerEntity.cpp:4442` | ✅ |
| `-[PlayerEntity setDialCustom:forKey:]` (4127) | `setDialCustom` `Core/Entities/PlayerEntity.cpp:4448` | ⚠️ |
| `-[PlayerEntity setShowDemoShips:]` (4132) | `setShowDemoShips` `Core/Entities/PlayerEntity.cpp:4453` | ✅ |
| `-[PlayerEntity showDemoShips]` (4137) | `getShowDemoShips` `Core/Entities/PlayerEntity.cpp:4458` | ✅ |
| `-[PlayerEntity maxForwardShieldLevel]` (4142) | `maxForwardShieldLevel` `Core/Entities/PlayerEntity.cpp:4463` | ✅ |
| `-[PlayerEntity maxAftShieldLevel]` (4147) | `maxAftShieldLevel` `Core/Entities/PlayerEntity.cpp:4468` | ✅ |
| `-[PlayerEntity forwardShieldRechargeRate]` (4152) | `forwardShieldRechargeRate` `Core/Entities/PlayerEntity.cpp:4473` | ✅ |
| `-[PlayerEntity aftShieldRechargeRate]` (4157) | `aftShieldRechargeRate` `Core/Entities/PlayerEntity.cpp:4478` | ✅ |
| `-[PlayerEntity setMaxForwardShieldLevel:]` (4162) | `setMaxForwardShieldLevel` `Core/Entities/PlayerEntity.cpp:4483` | ✅ |
| `-[PlayerEntity setMaxAftShieldLevel:]` (4167) | `setMaxAftShieldLevel` `Core/Entities/PlayerEntity.cpp:4488` | ✅ |
| `-[PlayerEntity setForwardShieldRechargeRate:]` (4172) | `setForwardShieldRechargeRate` `Core/Entities/PlayerEntity.cpp:4493` | ✅ |
| `-[PlayerEntity setAftShieldRechargeRate:]` (4177) | `setAftShieldRechargeRate` `Core/Entities/PlayerEntity.cpp:4498` | ✅ |
| `-[PlayerEntity forwardShieldLevel]` (4182) | `forwardShieldLevel` `Core/Entities/PlayerEntity.cpp:4503` | ✅ |
| `-[PlayerEntity aftShieldLevel]` (4187) | `aftShieldLevel` `Core/Entities/PlayerEntity.cpp:4508` | ✅ |
| `-[PlayerEntity setForwardShieldLevel:]` (4192) | `setForwardShieldLevel` `Core/Entities/PlayerEntity.cpp:4513` | ✅ |
| `-[PlayerEntity setAftShieldLevel:]` (4197) | `setAftShieldLevel` `Core/Entities/PlayerEntity.cpp:4518` | ✅ |
| `-[PlayerEntity keyConfig]` (4202) | `keyConfig` `Core/Entities/PlayerEntity.cpp:4523` | ✅ |
| `-[PlayerEntity isMouseControlOn]` (4208) | `isMouseControlOn` `Core/Entities/PlayerEntity.cpp:4529` | ✅ |
| `-[PlayerEntity dialRoll]` (4213) | `dialRoll` `Core/Entities/PlayerEntity.cpp:4534` | ✅ |
| `-[PlayerEntity dialPitch]` (4223) | `dialPitch` `Core/Entities/PlayerEntity.cpp:4544` | ✅ |
| `-[PlayerEntity dialYaw]` (4233) | `dialYaw` `Core/Entities/PlayerEntity.cpp:4554` | ✅ |
| `-[PlayerEntity dialSpeed]` (4243) | `dialSpeed` `Core/Entities/PlayerEntity.cpp:4564` | ✅ |
| `-[PlayerEntity dialHyperSpeed]` (4249) | `dialHyperSpeed` `Core/Entities/PlayerEntity.cpp:4570` | ✅ |
| `-[PlayerEntity dialForwardShield]` (4254) | `dialForwardShield` `Core/Entities/PlayerEntity.cpp:4575` | ✅ |
| `-[PlayerEntity dialAftShield]` (4263) | `dialAftShield` `Core/Entities/PlayerEntity.cpp:4587` | ✅ |
| `-[PlayerEntity dialEnergy]` (4272) | `dialEnergy` `Core/Entities/PlayerEntity.cpp:4596` | ✅ |
| `-[PlayerEntity dialMaxEnergy]` (4278) | `dialMaxEnergy` `Core/Entities/PlayerEntity.cpp:4602` | ✅ |
| `-[PlayerEntity dialFuel]` (4283) | `dialFuel` `Core/Entities/PlayerEntity.cpp:4607` | ✅ |
| `-[PlayerEntity dialHyperRange]` (4292) | `dialHyperRange` `Core/Entities/PlayerEntity.cpp:4616` | ✅ |
| `-[PlayerEntity laserHeatLevel]` (4299) | `laserHeatLevel` `Core/Entities/PlayerEntity.cpp:4623` | ✅ |
| `-[PlayerEntity laserHeatLevelAft]` (4305) | `laserHeatLevelAft` `Core/Entities/PlayerEntity.cpp:4629` | ✅ |
| `-[PlayerEntity laserHeatLevelForward]` (4311) | `laserHeatLevelForward` `Core/Entities/PlayerEntity.cpp:4635` | ✅ |
| `-[PlayerEntity laserHeatLevelPort]` (4318) | `laserHeatLevelPort` `Core/Entities/PlayerEntity.cpp:4642` | ✅ |
| `-[PlayerEntity laserHeatLevelStarboard]` (4324) | `laserHeatLevelStarboard` `Core/Entities/PlayerEntity.cpp:4648` | ✅ |
| `-[PlayerEntity dialAltitude]` (4330) | `dialAltitude` `Core/Entities/PlayerEntity.cpp:4654` | ✅ |
| `-[PlayerEntity clockTime]` (4349) | `clockTime` `Core/Entities/PlayerEntity.cpp:4673` | ✅ |
| `-[PlayerEntity clockTimeAdjusted]` (4354) | `clockTimeAdjusted` `Core/Entities/PlayerEntity.cpp:4678` | ✅ |
| `-[PlayerEntity clockAdjusting]` (4359) | `clockAdjusting` `Core/Entities/PlayerEntity.cpp:4683` | ✅ |
| `-[PlayerEntity addToAdjustTime:]` (4364) | `addToAdjustTime` `Core/Entities/PlayerEntity.cpp:4688` | ✅ |
| `-[PlayerEntity escapePodRescueTime]` (4369) | `escapePodRescueTime` `Core/Entities/PlayerEntity.cpp:4693` | ✅ |
| `-[PlayerEntity setEscapePodRescueTime:]` (4374) | `setEscapePodRescueTime` `Core/Entities/PlayerEntity.cpp:4698` | ✅ |
| `-[PlayerEntity dial_clock]` (4379) | `dial_clock` `Core/Entities/PlayerEntity.cpp:4703` | ✅ |
| `-[PlayerEntity dial_clock_adjusted]` (4384) | `dial_clock_adjusted` `Core/Entities/PlayerEntity.cpp:4708` | ✅ |
| `-[PlayerEntity dial_fpsinfo]` (4389) | `dial_fpsinfo` `Core/Entities/PlayerEntity.cpp:4713` | ✅ |
| `-[PlayerEntity dial_objinfo]` (4395) | `dial_objinfo` `Core/Entities/PlayerEntity.cpp:4719` | ✅ |
| `-[PlayerEntity countMissiles]` (4405) | `countMissiles` `Core/Entities/PlayerEntity.cpp:4729` | ✅ |
| `-[PlayerEntity dialMissileStatus]` (4416) | `dialMissileStatus` `Core/Entities/PlayerEntity.cpp:4740` | ✅ |
| `-[PlayerEntity canScoop:]` (4430) | `canScoop` `Core/Entities/PlayerEntity.cpp:4754` | ✅ |
| `-[PlayerEntity dialFuelScoopStatus]` (4437) | `dialFuelScoopStatus` `Core/Entities/PlayerEntity.cpp:4761` | ✅ |
| `-[PlayerEntity fuelLeakRate]` (4452) | `fuelLeakRate` `Core/Entities/PlayerEntity.cpp:4776` | ✅ |
| `-[PlayerEntity setFuelLeakRate:]` (4457) | `setFuelLeakRate` `Core/Entities/PlayerEntity.cpp:4781` | ✅ |
| `-[PlayerEntity commLog]` (4462) | `getCommLog` `Core/Entities/PlayerEntity.cpp:4786` | ✅ |
| `-[PlayerEntity roleWeights]` (4478) | `getRoleWeights` `Core/Entities/PlayerEntity.cpp:4798` | ✅ |
| `-[PlayerEntity addRoleForAggression:]` (4483) | `addRoleForAggression` `Core/Entities/PlayerEntity.cpp:4803` | ✅ |
| `-[PlayerEntity addRoleForMining]` (4510) | `addRoleForMining` `Core/Entities/PlayerEntity.cpp:4830` | ✅ |
| `-[PlayerEntity addRoleToPlayer:]` (4522) | `addRoleToPlayer` `Core/Entities/PlayerEntity.cpp:4842` | ✅ |
| `-[PlayerEntity addRoleToPlayer:inSlot:]` (4528) | `addRoleToPlayer` `Core/Entities/PlayerEntity.cpp:4848` | ✅ |
| `-[PlayerEntity clearRoleFromPlayer:]` (4540) | `clearRoleFromPlayer` `Core/Entities/PlayerEntity.cpp:4860` | ✅ |
| `-[PlayerEntity clearRolesFromPlayer:]` (4553) | `clearRolesFromPlayer` `Core/Entities/PlayerEntity.cpp:4873` | ✅ |
| `-[PlayerEntity maxPlayerRoles]` (4563) | `maxPlayerRoles` `Core/Entities/PlayerEntity.cpp:4883` | ✅ |
| `-[PlayerEntity updateSystemMemory]` (4574) | `updateSystemMemory` `Core/Entities/PlayerEntity.cpp:4894` | ✅ |
| `-[PlayerEntity compassTarget]` (4594) | `getCompassTargetEntity` `Core/Entities/PlayerEntity.cpp:4916` | ✅ |
| `-[PlayerEntity setCompassTarget:]` (4604) | `setCompassTargetEntity` `Core/Entities/PlayerEntity.cpp:4926` | ✅ |
| `-[PlayerEntity validateCompassTarget]` (4610) | `validateCompassTarget` `Core/Entities/PlayerEntity.cpp:4931` | ✅ |
| `-[PlayerEntity compassTargetLabel]` (4668) | `compassTargetLabel` `Core/Entities/PlayerEntity.cpp:4994` | ✅ |
| `-[PlayerEntity compassMode]` (4694) | `getCompassMode` `Core/Entities/PlayerEntity.cpp:5023` | ✅ |
| `-[PlayerEntity setCompassMode:]` (4699) | `setCompassMode` `Core/Entities/PlayerEntity.cpp:5028` | ✅ |
| `-[PlayerEntity setPrevCompassMode]` (4704) | `setPrevCompassMode` `Core/Entities/PlayerEntity.cpp:5033` | ✅ |
| `-[PlayerEntity setNextCompassMode]` (4761) | `setNextCompassMode` `Core/Entities/PlayerEntity.cpp:5090` | ✅ |
| `-[PlayerEntity activeMissile]` (4816) | `getActiveMissile` `Core/Entities/PlayerEntity.cpp:5145` | ✅ |
| `-[PlayerEntity setActiveMissile:]` (4821) | `setActiveMissile` `Core/Entities/PlayerEntity.cpp:5150` | ✅ |
| `-[PlayerEntity dialMaxMissiles]` (4826) | `dialMaxMissiles` `Core/Entities/PlayerEntity.cpp:5155` | ✅ |
| `-[PlayerEntity dialIdentEngaged]` (4831) | `dialIdentEngaged` `Core/Entities/PlayerEntity.cpp:5160` | ✅ |
| `-[PlayerEntity setDialIdentEngaged:]` (4836) | `setDialIdentEngaged` `Core/Entities/PlayerEntity.cpp:5165` | ✅ |
| `-[PlayerEntity specialCargo]` (4841) | `getSpecialCargo` `Core/Entities/PlayerEntity.cpp:5170` | ✅ |
| `-[PlayerEntity dialTargetName]` (4846) | `dialTargetName` `Core/Entities/PlayerEntity.cpp:5175` | ✅ |
| `-[PlayerEntity multiFunctionDisplayList]` (4865) | `multiFunctionDisplayList` `Core/Entities/PlayerEntity.cpp:5199` | ✅ |
| `-[PlayerEntity multiFunctionText:]` (4870) | `multiFunctionText` `Core/Entities/PlayerEntity.cpp:5204` | ✅ |
| `-[PlayerEntity setMultiFunctionText:forKey:]` (4880) | `setMultiFunctionText` `Core/Entities/PlayerEntity.cpp:5215` | ✅ |
| `-[PlayerEntity setMultiFunctionDisplay:toKey:]` (4894) | `setMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5227` | ✅ |
| `-[PlayerEntity cycleNextMultiFunctionDisplay:]` (4916) | `cycleNextMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5247` | ⚠️ |
| `-[PlayerEntity cyclePreviousMultiFunctionDisplay:]` (4946) | `cyclePreviousMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5281` | ⚠️ |
| `-[PlayerEntity selectNextMultiFunctionDisplay]` (4976) | `selectNextMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5315` | ✅ |
| `-[PlayerEntity selectPreviousMultiFunctionDisplay]` (4988) | `selectPreviousMultiFunctionDisplay` `Core/Entities/PlayerEntity.cpp:5328` | ✅ |
| `-[PlayerEntity activeMFD]` (5004) | `getActiveMFD` `Core/Entities/PlayerEntity.cpp:5345` | ✅ |
| `-[PlayerEntity missileForPylon:]` (5009) | `missileForPylon` `Core/Entities/PlayerEntity.cpp:5350` | ✅ |
| `-[PlayerEntity safeAllMissiles]` (5016) | `safeAllMissiles` `Core/Entities/PlayerEntity.cpp:5357` | ✅ |
| `-[PlayerEntity tidyMissilePylons]` (5028) | `tidyMissilePylons` `Core/Entities/PlayerEntity.cpp:5370` | ✅ |
| `-[PlayerEntity selectNextMissile]` (5050) | `selectNextMissile` `Core/Entities/PlayerEntity.cpp:5393` | ✅ |
| `-[PlayerEntity clearAlertFlags]` (5096) | `clearAlertFlags` `Core/Entities/PlayerEntity.cpp:5441` | ✅ |
| `-[PlayerEntity alertFlags]` (5101) | `getAlertFlags` `Core/Entities/PlayerEntity.cpp:5446` | ✅ |
| `-[PlayerEntity setAlertFlag:to:]` (5106) | `setAlertFlag` `Core/Entities/PlayerEntity.cpp:5451` | ✅ |
| `-[PlayerEntity realAlertCondition]` (5117) | `realAlertCondition` `Core/Entities/PlayerEntity.cpp:5462` | ✅ |
| `-[PlayerEntity alertCondition]` (5122) | `getAlertCondition` `Core/Entities/PlayerEntity.cpp:5470` | ✅ |
| `-[PlayerEntity fleeingStatus]` (5146) | `fleeingStatus` `Core/Entities/PlayerEntity.cpp:5494` | ✅ |
| `-[PlayerEntity interpretAIMessage:]` (5153) | `interpretAIMessage` `Core/Entities/PlayerEntity.cpp:5499` | ✅ |
| `-[PlayerEntity mountMissile:]` (5203) | `mountMissile` `Core/Entities/PlayerEntity.cpp:5554` | ✅ |
| `-[PlayerEntity mountMissileWithRole:]` (5223) | `mountMissileWithRole` `Core/Entities/PlayerEntity.cpp:5575` | ✅ |
| `-[PlayerEntity fireMissile]` (5230) | `fireMissile` `Core/Entities/PlayerEntity.cpp:5582` | ✅ |
| `-[PlayerEntity launchMine:]` (5282) | `launchMine` `Core/Entities/PlayerEntity.cpp:5634` | ✅ |
| `-[PlayerEntity assignToActivePylon:]` (5302) | `assignToActivePylon` `Core/Entities/PlayerEntity.cpp:5658` | ✅ |
| `-[PlayerEntity activateCloakingDevice]` (5342) | `activateCloakingDevice` `Core/Entities/PlayerEntity.cpp:5697` | ✅ |
| `-[PlayerEntity deactivateCloakingDevice]` (5359) | `deactivateCloakingDevice` `Core/Entities/PlayerEntity.cpp:5717` | ✅ |
| `-[PlayerEntity scannerFuzziness]` (5372) | `scannerFuzziness` `Core/Entities/PlayerEntity.cpp:5732` | ✅ |
| `-[PlayerEntity noticeECM]` (5388) | `noticeECM` `Core/Entities/PlayerEntity.cpp:5748` | ✅ |
| `-[PlayerEntity fireECM]` (5393) | `fireECM` `Core/Entities/PlayerEntity.cpp:5753` | ✅ |
| `-[PlayerEntity installedEnergyUnitType]` (5404) | `installedEnergyUnitType` `Core/Entities/PlayerEntity.cpp:5764` | ✅ |
| `-[PlayerEntity energyUnitType]` (5413) | `energyUnitType` `Core/Entities/PlayerEntity.cpp:5773` | ✅ |
| `-[PlayerEntity currentWeaponStats]` (5426) | `currentWeaponStats` `Core/Entities/PlayerEntity.cpp:5786` | ✅ |
| `-[PlayerEntity weaponsOnline]` (5435) | `weaponsOnline` `Core/Entities/PlayerEntity.cpp:5795` | ✅ |
| `-[PlayerEntity setWeaponsOnline:]` (5440) | `setWeaponsOnline` `Core/Entities/PlayerEntity.cpp:5800` | ✅ |
| `-[PlayerEntity currentLaserOffset]` (5447) | `currentLaserOffset` `Core/Entities/PlayerEntity.cpp:5807` | ✅ |
| `-[PlayerEntity fireMainWeapon]` (5452) | `fireMainWeapon` `Core/Entities/PlayerEntity.cpp:5812` | ❌ |
| `-[PlayerEntity weaponForFacing:]` (5529) | `weaponForFacing` `Core/Entities/PlayerEntity.cpp:5891` | ✅ |
| `-[PlayerEntity currentWeapon]` (5550) | `currentWeapon` `Core/Entities/PlayerEntity.cpp:5912` | ✅ |
| `-[PlayerEntity doesHitLine:v1:hitEntity:]` (5558) | `doesHitLine` `Core/Entities/PlayerEntity.cpp:5923` | ✅ |
| `-[PlayerEntity takeEnergyDamage:from:becauseOf:weaponIdentifier:]` (5599) | `takeEnergyDamage` `Core/Entities/PlayerEntity.cpp:5966` | ✅ |
| `-[PlayerEntity takeScrapeDamage:from:]` (5701) | `takeScrapeDamage` `Core/Entities/PlayerEntity.cpp:6073` | ✅ |
| `-[PlayerEntity takeHeatDamage:]` (5755) | `takeHeatDamage` `Core/Entities/PlayerEntity.cpp:6127` | ✅ |
| `-[PlayerEntity createDoppelganger]` (5785) | `createDoppelganger` `Core/Entities/PlayerEntity.cpp:6157` | ✅ |
| `-[PlayerEntity launchEscapeCapsule]` (5806) | `launchEscapeCapsule` `Core/Entities/PlayerEntity.cpp:6191` | ✅ |
| `-[PlayerEntity dumpCargo]` (5928) | `dumpCargo` `Core/Entities/PlayerEntity.cpp:6324` | ✅ |
| `-[PlayerEntity rotateCargo]` (5944) | `rotateCargo` `Core/Entities/PlayerEntity.cpp:6343` | ✅ |

**Differences:**

- ❌ **low** — Loading `role_weights` keeps only string elements (non-strings are dropped, shifting slots and shortening the list); upstream `mutableCopy` kept every element. Likewise a non-string `comm_log` entry is passed as nil rather than the object, and an int contract `type` with no legacy mapping becomes `""` where upstream raised on `setObject:nil`. Only hand-edited or corrupt saves are affected — upstream `Core/Entities/PlayerEntity.m:1425`, `:1473`, `:1266` ↔ port `Core/Entities/PlayerEntity.cpp:1836`, `:1880`, `:1675`
- ❌ **low** — `fireMainWeapon` overheat path uses `currentLaserOffset().at(0)`: with an empty weapon-offset list this throws `std::out_of_range`, where upstream `oo_vectorAtIndex:0` returned `kZeroVector` and carried on (overheat sound + message) — upstream `Core/Entities/PlayerEntity.m:5461` ↔ port `Core/Entities/PlayerEntity.cpp:5821`
- ⚠️ **low** — `cycleNext/PreviousMultiFunctionDisplay` cycle MFD keys in `std::map` byte order instead of `-[NSDictionary allKeys]` hash order, so the order of MFDs selected by the cycle key differs (the code comment says so) — upstream `Core/Entities/PlayerEntity.m:4920`, `:4950` ↔ port `Core/Entities/PlayerEntity.cpp:5251`, `:5285`
- ⚠️ **low** — `commanderDataDictionary` omits a key whose value is nil (`written_by_version`, `current_system_name`, `player_name`, `subentities_status`, `primed_equipment_a/b`, `trumbles`, …) where upstream `setObject:nil` raised mid-save (the code comment says so); a nil missile `primaryRole` is saved as `""`. Key spellings, number kinds (`chart_zoom` single, `credits` double, `fuel`/`entity_personality` unsigned, ints signed) and defaults all match. The checksum hashes the length of `oo::DescriptionOf(mission_variables/equipment)` for `NSDictionary -description`; nothing reads `checksum` back — upstream `Core/Entities/PlayerEntity.m:755`, `:834`, `:998` ↔ port `Core/Entities/PlayerEntity.cpp:1122`, `:1216`, `:1397`
- ⚠️ **low** — `setDialCustom` stores a null value as a null entry, where upstream `setObject:nil forKey:` raised (the code comment says so) — upstream `Core/Entities/PlayerEntity.m:4129` ↔ port `Core/Entities/PlayerEntity.cpp:4450`
- ⚠️ **low** — Debug `STAGE_TRACKING_END` logs `"***** Exception during [...]"` only for `OOException`; other C++ exceptions are rethrown without the log line, where upstream `@catch (NSException *)` logged every NSException (the code comment says so) — upstream `Core/Entities/PlayerEntity.m:2361` ↔ port `Core/Entities/PlayerEntity.cpp:345`
- ➖ — `-init` is `PlayerEntity()` + `newPlayerObject()`; `-dealloc` is `willDealloc()` (run first by the ship's dealloc) + member destructors; `kOOLogBuyMounted*` constants are inlined at their use sites (beyond line 5981).
- Subtle (✅): setting up with `customDialSettings`, `multiFunctionDisplay*`, `reputation` (all 9 keys at 0/0/`MAX_CONTRACT_REP`), `roleWeights` (8 × `player-unknown`), credits 1000, `PLAYER_MAX_FUEL`, galaxy coords (0x14,0xAD), `ship_trade_in_factor` 95, energy 256, temperature 60, shields `BASELINE_SHIELD_LEVEL` / recharge 2.0 all match. The ship clock start now comes from `oo::date::localUTCOffsetMinutes` (h/m/s of local time) rather than `NSCalendarDate` — upstream `Core/Entities/PlayerEntity.m:1850` ↔ port `Core/Entities/PlayerEntity.cpp:2198`
- Subtle (✅): `setCommanderDataFromDictionary` guards `% [_customViews count]` against an empty `custom_views` array (upstream divided by zero) and skips `removeObjectForKey:nil` for a passenger without a name (upstream raised) — upstream `Core/Entities/PlayerEntity.m:1569`, `:1333` ↔ port `Core/Entities/PlayerEntity.cpp:1978`, `:1734`
- Subtle (✅): `addRoleForAggression` / `addRoleForMining` store `role_weight_flags` counts as signed integers (upstream `numberWithUnsignedInteger:`). This makes no difference to the XML plist `<integer>` — upstream `Core/Entities/PlayerEntity.m:4503` ↔ port `Core/Entities/PlayerEntity.cpp:4823`
- Subtle (✅): `dumpCargo` returns `void` (upstream returned the commodity). No caller used the value; the hold-locked check, message and sound are unchanged — upstream `Core/Entities/PlayerEntity.m:5928` ↔ port `Core/Entities/PlayerEntity.cpp:6324`
- Subtle (✅): doBookkeeping (weapon cooling, cloak/jammer/ECM drain, shield/energy recharge with `shield_charge_energybank_threshold` 0.25, sun-skim fuel scoop `0.010/fuelChargeRate`, cabin heat, hyperspeed/injector fuel burn, fuel leak), alert flags/mass lock and the fleeing heuristic, witchspace countdown (`fdim`, gal-drive abort, `witch-to-x-in-y-seconds` with `seconds`/`destination`), launching/docking/dead updates and the escape-capsule sequence are line-for-line equal.

### PlayerEntity (part 2: lines 5982-end)

Upstream `src/Core/Entities/PlayerEntity.m` lines 5982–11911 ↔ `Core/Entities/PlayerEntity.cpp`

**Status:** done — 234 rows: 220 ✅ 9 ⚠️ 5 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity setBounty:]` (5982) | `setBounty(OOCreditsQuantity)` Core/Entities/PlayerEntity.cpp:6388 | ✅ |
| `-[PlayerEntity setBounty:withReason:]` (5987) | `setBounty(amount, OOLegalStatusReason)` Core/Entities/PlayerEntity.cpp:6393 | ✅ |
| `-[PlayerEntity setBounty:withReasonAsString:]` (5993) | `setBounty(amount, const std::string&)` Core/Entities/PlayerEntity.cpp:6398 | ✅ |
| `-[PlayerEntity bounty]` (6010) | `getBounty` Core/Entities/PlayerEntity.cpp:6418 | ✅ |
| `-[PlayerEntity legalStatus]` (6015) | `getLegalStatus` Core/Entities/PlayerEntity.cpp:6423 (virtual `legalStatus()` forwards, :516) | ✅ |
| `-[PlayerEntity markAsOffender:]` (6020) | `markAsOffender(int)` Core/Entities/PlayerEntity.cpp:6428 | ✅ |
| `-[PlayerEntity markAsOffender:withReason:]` (6025) | `markAsOffender(int, OOLegalStatusReason)` Core/Entities/PlayerEntity.cpp:6433 | ✅ |
| `-[PlayerEntity collectBountyFor:]` (6044) | `collectBountyFor` Core/Entities/PlayerEntity.cpp:6452 | ✅ |
| `-[PlayerEntity takeInternalDamage]` (6099) | `takeInternalDamage` Core/Entities/PlayerEntity.cpp:6508 | ✅ |
| `-[PlayerEntity getDestroyedBy:damageType:]` (6189) | `getDestroyedBy` Core/Entities/PlayerEntity.cpp:6598 | ✅ |
| `-[PlayerEntity loseTargetStatus]` (6227) | `loseTargetStatus` Core/Entities/PlayerEntity.cpp:6640 | ✅ |
| `-[PlayerEntity endScenario:]` (6251) | `endScenario` Core/Entities/PlayerEntity.cpp:6665 | ✅ |
| `-[PlayerEntity enterDock:]` (6260) | `enterDock` Core/Entities/PlayerEntity.cpp:6674 | ✅ |
| `-[PlayerEntity docked]` (6299) | `docked` Core/Entities/PlayerEntity.cpp:6719 | ✅ |
| `-[PlayerEntity leaveDock:]` (6394) | `leaveDock` Core/Entities/PlayerEntity.cpp:6818 | ✅ |
| `-[PlayerEntity witchStart]` (6490) | `witchStart` Core/Entities/PlayerEntity.cpp:6928 | ✅ |
| `-[PlayerEntity witchEnd]` (6533) | `witchEnd` Core/Entities/PlayerEntity.cpp:6975 | ✅ |
| `-[PlayerEntity witchJumpChecklist:]` (6546) | `witchJumpChecklist` Core/Entities/PlayerEntity.cpp:6992 | ✅ |
| `-[PlayerEntity setJumpType:]` (6617) | `setJumpType` Core/Entities/PlayerEntity.cpp:7071 | ✅ |
| `-[PlayerEntity hyperspaceJumpDistance]` (6626) | `hyperspaceJumpDistance` Core/Entities/PlayerEntity.cpp:7080 | ✅ |
| `-[PlayerEntity fuelRequiredForJump]` (6632) | `fuelRequiredForJump` Core/Entities/PlayerEntity.cpp:7086 | ✅ |
| `-[PlayerEntity hasSufficientFuelForJump]` (6637) | `hasSufficientFuelForJump` Core/Entities/PlayerEntity.cpp:7091 | ✅ |
| `-[PlayerEntity noteCompassLostTarget]` (6642) | `noteCompassLostTarget` Core/Entities/PlayerEntity.cpp:7096 | ✅ |
| `-[PlayerEntity enterGalacticWitchspace]` (6655) | `enterGalacticWitchspace` Core/Entities/PlayerEntity.cpp:7109 | ✅ |
| `-[PlayerEntity enterWormhole:]` (6747) | `enterWormhole` Core/Entities/PlayerEntity.cpp:7200 | ✅ |
| `-[PlayerEntity enterWitchspace]` (6774) | `enterWitchspace` Core/Entities/PlayerEntity.cpp:7230 | ✅ |
| `-[PlayerEntity witchJumpTo:misjump:]` (6863) | `witchJumpTo` Core/Entities/PlayerEntity.cpp:7328 | ✅ |
| `-[PlayerEntity leaveWitchspace]` (6915) | `leaveWitchspace` Core/Entities/PlayerEntity.cpp:7387 | ✅ |
| `-[PlayerEntity setGuiToStatusScreen]` (7006) | `setGuiToStatusScreen` Core/Entities/PlayerEntity.cpp:7485 | ✅ |
| `-[PlayerEntity equipmentList]` (7146) | `equipmentList` Core/Entities/PlayerEntity.cpp:7624 | ✅ |
| `-[PlayerEntity primedEquipmentCount]` (7245) | `primedEquipmentCount` Core/Entities/PlayerEntity.cpp:7726 | ✅ |
| `-[PlayerEntity primedEquipmentName:]` (7250) | `primedEquipmentName` Core/Entities/PlayerEntity.cpp:7731 | ✅ |
| `-[PlayerEntity currentPrimedEquipment]` (7261) | `currentPrimedEquipment` Core/Entities/PlayerEntity.cpp:7742 | ✅ |
| `-[PlayerEntity setPrimedEquipment:showMessage:]` (7271) | `setPrimedEquipment` Core/Entities/PlayerEntity.cpp:7752 | ✅ |
| `-[PlayerEntity activatePrimableEquipment:withMode:]` (7291) | `activatePrimableEquipment` Core/Entities/PlayerEntity.cpp:7780 | ✅ |
| `-[PlayerEntity fastEquipmentA]` (7311) | `fastEquipmentA` Core/Entities/PlayerEntity.cpp:7802 | ✅ |
| `-[PlayerEntity fastEquipmentB]` (7316) | `fastEquipmentB` Core/Entities/PlayerEntity.cpp:7807 | ✅ |
| `-[PlayerEntity setFastEquipmentA:]` (7321) | `setFastEquipmentA` Core/Entities/PlayerEntity.cpp:7812 | ✅ |
| `-[PlayerEntity setFastEquipmentB:]` (7327) | `setFastEquipmentB` Core/Entities/PlayerEntity.cpp:7817 | ✅ |
| `-[PlayerEntity weaponTypeForFacing:strict:]` (7333) | `weaponTypeForFacing` Core/Entities/PlayerEntity.cpp:7822 | ✅ |
| `-[PlayerEntity missilesList]` (7361) | `missilesList` Core/Entities/PlayerEntity.cpp:7853 | ✅ |
| `-[PlayerEntity cargoList]` (7367) | `cargoList` Core/Entities/PlayerEntity.cpp:7859 | ✅ |
| `-[PlayerEntity cargoListForScripting]` (7393) | `cargoListForScripting` Core/Entities/PlayerEntity.cpp:7890 | ⚠️ |
| `-[PlayerEntity legalStatusOfCargoList]` (7432) | `legalStatusOfCargoList` Core/Entities/PlayerEntity.cpp:7934 | ✅ |
| `-[PlayerEntity contractsListForScriptingFromArray:forCargo:]` (7445) | `contractsListForScriptingFromArray` Core/Entities/PlayerEntity.cpp:7946 | ✅ |
| `-[PlayerEntity passengerListForScripting]` (7483) | `passengerListForScripting` Core/Entities/PlayerEntity.cpp:7990 | ✅ |
| `-[PlayerEntity parcelListForScripting]` (7488) | `parcelListForScripting` Core/Entities/PlayerEntity.cpp:7995 | ✅ |
| `-[PlayerEntity contractListForScripting]` (7493) | `contractListForScripting` Core/Entities/PlayerEntity.cpp:8000 | ✅ |
| `-[PlayerEntity setGuiToSystemDataScreen]` (7498) | `setGuiToSystemDataScreen` Core/Entities/PlayerEntity.cpp:8005 | ✅ |
| `-[PlayerEntity setGuiToSystemDataScreenRefreshBackground:]` (7503) | `setGuiToSystemDataScreenRefreshBackground` Core/Entities/PlayerEntity.cpp:8010 | ✅ |
| `-[PlayerEntity prepareMarkedDestination:marker:]` (7699) | `PrepareMarkedDestination` (anonymous-namespace free function) Core/Entities/PlayerEntity.cpp:375 | ✅ |
| `-[PlayerEntity markedDestinations]` (7711) | `markedDestinations` Core/Entities/PlayerEntity.cpp:8186 | ⚠️ |
| `-[PlayerEntity setGuiToLongRangeChartScreen]` (7746) | `setGuiToLongRangeChartScreen` Core/Entities/PlayerEntity.cpp:8215 | ✅ |
| `-[PlayerEntity setGuiToShortRangeChartScreen]` (7758) | `setGuiToShortRangeChartScreen` Core/Entities/PlayerEntity.cpp:8227 | ✅ |
| `-[PlayerEntity setGuiToChartScreenFrom:]` (7769) | `setGuiToChartScreenFrom` Core/Entities/PlayerEntity.cpp:8238 | ✅ |
| `SliderString()` (7823) | `SliderString` Core/Entities/PlayerEntity.cpp:385 | ✅ |
| `-[PlayerEntity setGuiToGameOptionsScreen]` (7830) | `setGuiToGameOptionsScreen` Core/Entities/PlayerEntity.cpp:8305 | ✅ |
| `-[PlayerEntity setGuiToLoadSaveScreen]` (8061) | `setGuiToLoadSaveScreen` Core/Entities/PlayerEntity.cpp:8545 | ✅ |
| `static last_outfitting_key` (8155) | `last_outfitting_key` Core/Entities/PlayerEntity.cpp:396 | ✅ |
| `-[PlayerEntity highlightEquipShipScreenKey:]` (8157) | `highlightEquipShipScreenKey` Core/Entities/PlayerEntity.cpp:8643 | ✅ |
| `-[PlayerEntity availableFacings]` (8197) | `availableFacings` Core/Entities/PlayerEntity.cpp:8683 | ✅ |
| `-[PlayerEntity setGuiToEquipShipScreen:selectingFacingFor:]` (8206) | `setGuiToEquipShipScreen(int, const std::optional<std::string>&)` Core/Entities/PlayerEntity.cpp:8695 | ✅ |
| `-[PlayerEntity setGuiToEquipShipScreen:]` (8547) | `setGuiToEquipShipScreen(int)` Core/Entities/PlayerEntity.cpp:9046 | ✅ |
| `-[PlayerEntity showInformationForSelectedUpgrade]` (8552) | `showInformationForSelectedUpgrade` Core/Entities/PlayerEntity.cpp:9051 | ✅ |
| `-[PlayerEntity showInformationForSelectedUpgradeWithFormatString:]` (8557) | `showInformationForSelectedUpgradeWithFormatString` Core/Entities/PlayerEntity.cpp:9056 | ✅ |
| `-[PlayerEntity setGuiToInterfacesScreen:]` (8588) | `setGuiToInterfacesScreen` Core/Entities/PlayerEntity.cpp:9090 | ⚠️ |
| `-[PlayerEntity showInformationForSelectedInterface]` (8698) | `showInformationForSelectedInterface` Core/Entities/PlayerEntity.cpp:9219 | ✅ |
| `-[PlayerEntity activateSelectedInterface]` (8719) | `activateSelectedInterface` Core/Entities/PlayerEntity.cpp:9239 | ✅ |
| `-[PlayerEntity setupStartScreenGui]` (8747) | `setupStartScreenGui` Core/Entities/PlayerEntity.cpp:9267 | ✅ |
| `-[PlayerEntity setGuiToIntroFirstGo:]` (8819) | `setGuiToIntroFirstGo` Core/Entities/PlayerEntity.cpp:9340 | ✅ |
| `-[PlayerEntity setGuiToOXZManager]` (8922) | `setGuiToOXZManager` Core/Entities/PlayerEntity.cpp:9454 | ✅ |
| `-[PlayerEntity noteGUIWillChangeTo:]` (8940) | `noteGUIWillChangeTo` Core/Entities/PlayerEntity.cpp:9476 | ✅ |
| `-[PlayerEntity noteGUIDidChangeFrom:to:]` (8947) | `noteGUIDidChangeFrom(from, to)` Core/Entities/PlayerEntity.cpp:9483 | ✅ |
| `-[PlayerEntity noteGUIDidChangeFrom:to:refresh:]` (8952) | `noteGUIDidChangeFrom(from, to, refresh)` Core/Entities/PlayerEntity.cpp:9488 | ✅ |
| `-[PlayerEntity noteViewDidChangeFrom:toView:]` (8985) | `noteViewDidChangeFrom` Core/Entities/PlayerEntity.cpp:9522 | ✅ |
| `-[PlayerEntity buySelectedItem]` (8990) | `buySelectedItem` Core/Entities/PlayerEntity.cpp:9530 | ✅ |
| `-[PlayerEntity adjustPriceByScriptForEqKey:withCurrent:]` (9070) | `adjustPriceByScriptForEqKey` Core/Entities/PlayerEntity.cpp:9620 | ✅ |
| `-[PlayerEntity tryBuyingItem:]` (9104) | `tryBuyingItem` Core/Entities/PlayerEntity.cpp:9650 | ✅ |
| `-[PlayerEntity setWeaponMount:toWeapon:]` (9345) | `setWeaponMount(facing, eqKey)` Core/Entities/PlayerEntity.cpp:9892 | ✅ |
| `-[PlayerEntity setWeaponMount:toWeapon:inContext:]` (9350) | `setWeaponMount(facing, eqKey, context)` Core/Entities/PlayerEntity.cpp:9897 | ✅ |
| `-[PlayerEntity changePassengerBerths:]` (9395) | `changePassengerBerths` Core/Entities/PlayerEntity.cpp:9943 | ✅ |
| `-[PlayerEntity removeMissiles]` (9410) | `removeMissiles` Core/Entities/PlayerEntity.cpp:9958 | ✅ |
| `-[PlayerEntity doTradeIn:forPriceFactor:]` (9431) | `doTradeIn` Core/Entities/PlayerEntity.cpp:9978 | ✅ |
| `-[PlayerEntity cargoQuantityForType:]` (9440) | `cargoQuantityForType` Core/Entities/PlayerEntity.cpp:9990 | ✅ |
| `-[PlayerEntity setCargoQuantityForType:amount:]` (9461) | `setCargoQuantityForType` Core/Entities/PlayerEntity.cpp:10010 | ✅ |
| `-[PlayerEntity calculateCurrentCargo]` (9503) | `calculateCurrentCargo` Core/Entities/PlayerEntity.cpp:10053 | ✅ |
| `-[PlayerEntity cargoQuantityOnBoard]` (9508) | `cargoQuantityOnBoard` Core/Entities/PlayerEntity.cpp:10058 | ✅ |
| `-[PlayerEntity localMarket]` (9547) | `localMarket` Core/Entities/PlayerEntity.cpp:10096 | ✅ |
| `-[PlayerEntity applyMarketFilter:onMarket:]` (9569) | `applyMarketFilter` Core/Entities/PlayerEntity.cpp:10118 | ✅ |
| `-[PlayerEntity applyMarketSorter:onMarket:]` (9612) | `applyMarketSorter` Core/Entities/PlayerEntity.cpp:10161 | ✅ |
| `-[PlayerEntity showMarketScreenHeaders]` (9632) | `showMarketScreenHeaders` Core/Entities/PlayerEntity.cpp:10187 | ✅ |
| `-[PlayerEntity showMarketScreenDataLine:forGood:inMarket:holdQuantity:]` (9654) | `showMarketScreenDataLine` Core/Entities/PlayerEntity.cpp:10205 | ✅ |
| `-[PlayerEntity marketScreenTitle]` (9700) | `marketScreenTitle` Core/Entities/PlayerEntity.cpp:10254 | ✅ |
| `-[PlayerEntity setGuiToMarketScreen]` (9728) | `setGuiToMarketScreen` Core/Entities/PlayerEntity.cpp:10285 | ✅ |
| `-[PlayerEntity setGuiToMarketInfoScreen]` (9895) | `setGuiToMarketInfoScreen` Core/Entities/PlayerEntity.cpp:10455 | ❌ |
| `-[PlayerEntity showMarketCashAndLoadLine]` (9979) | `showMarketCashAndLoadLine` Core/Entities/PlayerEntity.cpp:10547 | ✅ |
| `-[PlayerEntity guiScreen]` (9988) | `guiScreen` Core/Entities/PlayerEntity.cpp:10556 | ✅ |
| `-[PlayerEntity tryBuyingCommodity:all:]` (9993) | `tryBuyingCommodity` Core/Entities/PlayerEntity.cpp:10561 | ✅ |
| `-[PlayerEntity trySellingCommodity:all:]` (10074) | `trySellingCommodity` Core/Entities/PlayerEntity.cpp:10646 | ✅ |
| `-[PlayerEntity isMining]` (10126) | `isMining` Core/Entities/PlayerEntity.cpp:10702 | ✅ |
| `-[PlayerEntity isSpeechOn]` (10131) | `getIsSpeechOn` Core/Entities/PlayerEntity.cpp:10707 | ✅ |
| `-[PlayerEntity canAddEquipment:inContext:]` (10136) | `canAddEquipment` Core/Entities/PlayerEntity.cpp:10712 | ✅ |
| `-[PlayerEntity addEquipmentItem:inContext:]` (10150) | `addEquipmentItem` Core/Entities/PlayerEntity.cpp:10727 | ✅ |
| `-[PlayerEntity addEquipmentItem:withValidation:inContext:]` (10155) | `addEquipmentItem` Core/Entities/PlayerEntity.cpp:10735 | ✅ |
| `-[PlayerEntity customEquipmentActivation]` (10186) | `customEquipmentActivation` Core/Entities/PlayerEntity.cpp:10767 | ✅ |
| `-[PlayerEntity addEquipmentWithScriptToCustomKeyArray:]` (10191) | `addEquipmentWithScriptToCustomKeyArray` Core/Entities/PlayerEntity.cpp:10772 | ✅ |
| `-[PlayerEntity validateCustomEquipActivationArray]` (10233) | `validateCustomEquipActivationArray` Core/Entities/PlayerEntity.cpp:10814 | ✅ |
| `-[PlayerEntity removeEquipmentItem:]` (10256) | `removeEquipmentItem` Core/Entities/PlayerEntity.cpp:10836 | ✅ |
| `-[PlayerEntity addEquipmentFromCollection:]` (10268) | `addEquipmentFromCollection` Core/Entities/PlayerEntity.cpp:10849 | ⚠️ |
| `-[PlayerEntity hasOneEquipmentItem:includeMissiles:]` (10335) | `hasOneEquipmentItem` Core/Entities/PlayerEntity.cpp:10913 | ✅ |
| `-[PlayerEntity hasPrimaryWeapon:]` (10357) | `hasPrimaryWeapon` Core/Entities/PlayerEntity.cpp:10935 | ✅ |
| `-[PlayerEntity removeExternalStore:]` (10369) | `removeExternalStore` Core/Entities/PlayerEntity.cpp:10946 | ✅ |
| `-[PlayerEntity removeFromPylon:]` (10386) | `removeFromPylon` Core/Entities/PlayerEntity.cpp:10963 | ✅ |
| `-[PlayerEntity parcelCount]` (10419) | `parcelCount` Core/Entities/PlayerEntity.cpp:10995 | ✅ |
| `-[PlayerEntity passengerCount]` (10424) | `passengerCount` Core/Entities/PlayerEntity.cpp:11000 | ✅ |
| `-[PlayerEntity passengerCapacity]` (10429) | `passengerCapacity` Core/Entities/PlayerEntity.cpp:11005 | ✅ |
| `-[PlayerEntity hasHostileTarget]` (10434) | `hasHostileTarget` Core/Entities/PlayerEntity.cpp:11010 | ✅ |
| `-[PlayerEntity receiveCommsMessage:from:]` (10440) | `receiveCommsMessage` Core/Entities/PlayerEntity.cpp:11016 | ✅ |
| `-[PlayerEntity getFined]` (10450) | `getFined` Core/Entities/PlayerEntity.cpp:11027 | ✅ |
| `-[PlayerEntity adjustTradeInFactorBy:]` (10476) | `adjustTradeInFactorBy` Core/Entities/PlayerEntity.cpp:11054 | ✅ |
| `-[PlayerEntity tradeInFactor]` (10485) | `tradeInFactor` Core/Entities/PlayerEntity.cpp:11063 | ✅ |
| `-[PlayerEntity renovationCosts]` (10490) | `renovationCosts` Core/Entities/PlayerEntity.cpp:11068 | ✅ |
| `-[PlayerEntity renovationFactor]` (10501) | `renovationFactor` Core/Entities/PlayerEntity.cpp:11079 | ✅ |
| `-[PlayerEntity setDefaultViewOffsets]` (10508) | `setDefaultViewOffsets` Core/Entities/PlayerEntity.cpp:11086 | ✅ |
| `-[PlayerEntity setDefaultCustomViews]` (10520) | `setDefaultCustomViews` Core/Entities/PlayerEntity.cpp:11098 | ✅ |
| `-[PlayerEntity weaponViewOffset]` (10532) | `weaponViewOffset` Core/Entities/PlayerEntity.cpp:11110 | ✅ |
| `-[PlayerEntity setUpTrumbles]` (10551) | `setUpTrumbles` Core/Entities/PlayerEntity.cpp:11129 | ✅ |
| `-[PlayerEntity addTrumble:]` (10580) | `addTrumble` Core/Entities/PlayerEntity.cpp:11157 | ✅ |
| `-[PlayerEntity removeTrumble:]` (10590) | `removeTrumble` Core/Entities/PlayerEntity.cpp:11166 | ❌ |
| `-[PlayerEntity trumbleArray]` (10611) | `trumbleArray` Core/Entities/PlayerEntity.cpp:11186 | ✅ |
| `-[PlayerEntity trumbleCount]` (10616) | `getTrumbleCount` Core/Entities/PlayerEntity.cpp:11191 | ✅ |
| `-[PlayerEntity trumbleValue]` (10621) | `trumbleValue` Core/Entities/PlayerEntity.cpp:11199 | ✅ |
| `-[PlayerEntity setTrumbleValueFrom:]` (10643) | `setTrumbleValueFrom` Core/Entities/PlayerEntity.cpp:11223 | ✅ |
| `-[PlayerEntity trumbleAppetiteAccumulator]` (10741) | `trumbleAppetiteAccumulator` Core/Entities/PlayerEntity.cpp:11321 | ✅ |
| `-[PlayerEntity setTrumbleAppetiteAccumulator:]` (10746) | `setTrumbleAppetiteAccumulator` Core/Entities/PlayerEntity.cpp:11326 | ✅ |
| `-[PlayerEntity mungChecksumWithNSString:]` (10751) | `mungChecksumWithString` Core/Entities/PlayerEntity.cpp:11331 | ✅ |
| `-[PlayerEntity screenModeStringForWidth:height:refreshRate:]` (10762) | `screenModeStringForWidth` Core/Entities/PlayerEntity.cpp:11342 | ✅ |
| `-[PlayerEntity suppressTargetLost]` (10771) | `getSuppressTargetLost` Core/Entities/PlayerEntity.cpp:11351 | ✅ |
| `-[PlayerEntity setScoopsActive]` (10776) | `setScoopsActive` Core/Entities/PlayerEntity.cpp:11356 | ✅ |
| `-[PlayerEntity setFoundTarget:]` (10782) | `setFoundTarget` Core/Entities/PlayerEntity.cpp:11362 | ✅ |
| `-[PlayerEntity addTarget:]` (10794) | `addTarget` Core/Entities/PlayerEntity.cpp:11373 | ✅ |
| `-[PlayerEntity clearTargetMemory]` (10847) | `clearTargetMemory` Core/Entities/PlayerEntity.cpp:11432 | ✅ |
| `-[PlayerEntity targetMemory]` (10860) | `targetMemory` Core/Entities/PlayerEntity.cpp:11445 | ✅ |
| `-[PlayerEntity moveTargetMemoryBy:]` (10865) | `moveTargetMemoryBy` Core/Entities/PlayerEntity.cpp:11450 | ✅ |
| `-[PlayerEntity printIdentLockedOnForMissile:]` (10911) | `printIdentLockedOnForMissile` Core/Entities/PlayerEntity.cpp:11498 | ❌ |
| `-[PlayerEntity customViewQuaternion]` (10921) | `getCustomViewQuaternion` Core/Entities/PlayerEntity.cpp:11509 | ✅ |
| `-[PlayerEntity setCustomViewQuaternion:]` (10926) | `setCustomViewQuaternion` Core/Entities/PlayerEntity.cpp:11514 | ✅ |
| `-[PlayerEntity customViewMatrix]` (10932) | `getCustomViewMatrix` Core/Entities/PlayerEntity.cpp:11520 | ✅ |
| `-[PlayerEntity customViewOffset]` (10937) | `getCustomViewOffset` Core/Entities/PlayerEntity.cpp:11525 | ✅ |
| `-[PlayerEntity setCustomViewOffset:]` (10942) | `setCustomViewOffset` Core/Entities/PlayerEntity.cpp:11530 | ✅ |
| `-[PlayerEntity customViewRotationCenter]` (10947) | `getCustomViewRotationCenter` Core/Entities/PlayerEntity.cpp:11535 | ✅ |
| `-[PlayerEntity setCustomViewRotationCenter:]` (10952) | `setCustomViewRotationCenter` Core/Entities/PlayerEntity.cpp:11540 | ✅ |
| `-[PlayerEntity customViewZoomIn:]` (10957) | `customViewZoomIn` Core/Entities/PlayerEntity.cpp:11545 | ✅ |
| `-[PlayerEntity customViewZoomOut:]` (10968) | `customViewZoomOut` Core/Entities/PlayerEntity.cpp:11556 | ✅ |
| `-[PlayerEntity customViewRotateLeft:]` (10979) | `customViewRotateLeft` Core/Entities/PlayerEntity.cpp:11567 | ✅ |
| `-[PlayerEntity customViewRotateRight:]` (10990) | `customViewRotateRight` Core/Entities/PlayerEntity.cpp:11578 | ✅ |
| `-[PlayerEntity customViewRotateUp:]` (11001) | `customViewRotateUp` Core/Entities/PlayerEntity.cpp:11589 | ✅ |
| `-[PlayerEntity customViewRotateDown:]` (11012) | `customViewRotateDown` Core/Entities/PlayerEntity.cpp:11600 | ✅ |
| `-[PlayerEntity customViewRollRight:]` (11023) | `customViewRollRight` Core/Entities/PlayerEntity.cpp:11611 | ✅ |
| `-[PlayerEntity customViewRollLeft:]` (11034) | `customViewRollLeft` Core/Entities/PlayerEntity.cpp:11622 | ✅ |
| `-[PlayerEntity customViewPanUp:]` (11045) | `customViewPanUp` Core/Entities/PlayerEntity.cpp:11633 | ✅ |
| `-[PlayerEntity customViewPanDown:]` (11052) | `customViewPanDown` Core/Entities/PlayerEntity.cpp:11640 | ✅ |
| `-[PlayerEntity customViewPanLeft:]` (11059) | `customViewPanLeft` Core/Entities/PlayerEntity.cpp:11650 | ✅ |
| `-[PlayerEntity customViewPanRight:]` (11066) | `customViewPanRight` Core/Entities/PlayerEntity.cpp:11657 | ✅ |
| `-[PlayerEntity customViewForwardVector]` (11073) | `getCustomViewForwardVector` Core/Entities/PlayerEntity.cpp:11664 | ✅ |
| `-[PlayerEntity customViewUpVector]` (11078) | `getCustomViewUpVector` Core/Entities/PlayerEntity.cpp:11669 | ✅ |
| `-[PlayerEntity customViewRightVector]` (11083) | `getCustomViewRightVector` Core/Entities/PlayerEntity.cpp:11674 | ✅ |
| `-[PlayerEntity customViewDescription]` (11088) | `getCustomViewDescription` Core/Entities/PlayerEntity.cpp:11679 | ✅ |
| `-[PlayerEntity resetCustomView]` (11093) | `resetCustomView` Core/Entities/PlayerEntity.cpp:11684 | ✅ |
| `-[PlayerEntity setCustomViewData]` (11098) | `setCustomViewData` Core/Entities/PlayerEntity.cpp:11690 | ✅ |
| `-[PlayerEntity setCustomViewDataFromDictionary:withScaling:]` (11109) | `setCustomViewDataFromDictionary` Core/Entities/PlayerEntity.cpp:11701 | ✅ |
| `-[PlayerEntity showInfoFlag]` (11143) | `showInfoFlag` Core/Entities/PlayerEntity.cpp:11736 | ✅ |
| `-[PlayerEntity missionOverlayDescriptor]` (11148) | `missionOverlayDescriptor` Core/Entities/PlayerEntity.cpp:11741 | ✅ |
| `-[PlayerEntity missionOverlayDescriptorOrDefault]` (11153) | `missionOverlayDescriptorOrDefault` Core/Entities/PlayerEntity.cpp:11746 | ✅ |
| `-[PlayerEntity setMissionOverlayDescriptor:]` (11167) | `setMissionOverlayDescriptor` Core/Entities/PlayerEntity.cpp:11760 | ✅ |
| `-[PlayerEntity missionBackgroundDescriptor]` (11175) | `missionBackgroundDescriptor` Core/Entities/PlayerEntity.cpp:11765 | ✅ |
| `-[PlayerEntity missionBackgroundDescriptorOrDefault]` (11180) | `missionBackgroundDescriptorOrDefault` Core/Entities/PlayerEntity.cpp:11770 | ✅ |
| `-[PlayerEntity setMissionBackgroundDescriptor:]` (11190) | `setMissionBackgroundDescriptor` Core/Entities/PlayerEntity.cpp:11780 | ✅ |
| `-[PlayerEntity missionBackgroundSpecial]` (11198) | `missionBackgroundSpecial` Core/Entities/PlayerEntity.cpp:11785 | ✅ |
| `-[PlayerEntity setMissionBackgroundSpecial:]` (11203) | `setMissionBackgroundSpecial` Core/Entities/PlayerEntity.cpp:11790 | ✅ |
| `-[PlayerEntity setMissionExitScreen:]` (11254) | `setMissionExitScreen` Core/Entities/PlayerEntity.cpp:11841 | ✅ |
| `-[PlayerEntity missionExitScreen]` (11259) | `missionExitScreen` Core/Entities/PlayerEntity.cpp:11846 | ✅ |
| `-[PlayerEntity equipScreenBackgroundDescriptor]` (11264) | `equipScreenBackgroundDescriptor` Core/Entities/PlayerEntity.cpp:11851 | ✅ |
| `-[PlayerEntity setEquipScreenBackgroundDescriptor:]` (11269) | `setEquipScreenBackgroundDescriptor` Core/Entities/PlayerEntity.cpp:11856 | ✅ |
| `-[PlayerEntity scriptsLoaded]` (11277) | `scriptsLoaded` Core/Entities/PlayerEntity.cpp:11861 | ✅ |
| `-[PlayerEntity worldScriptNames]` (11282) | `worldScriptNames` Core/Entities/PlayerEntity.cpp:11866 | ⚠️ |
| `-[PlayerEntity worldScriptsByName]` (11287) | `worldScriptsByName` Core/Entities/PlayerEntity.cpp:11875 | ⚠️ |
| `-[PlayerEntity commodityScriptNamed:]` (11292) | `commodityScriptNamed` Core/Entities/PlayerEntity.cpp:11880 | ✅ |
| `-[PlayerEntity doScriptEvent:inContext:withArguments:count:]` (11311) | `doScriptEvent` Core/Entities/PlayerEntity.cpp:11904 | ✅ |
| `-[PlayerEntity doWorldEventUntilMissionScreen:]` (11317) | `doWorldEventUntilMissionScreen` Core/Entities/PlayerEntity.cpp:11911 | ⚠️ |
| `-[PlayerEntity doWorldScriptEvent:inContext:withArguments:count:timeLimit:]` (11344) | `doWorldScriptEvent` Core/Entities/PlayerEntity.cpp:11940 | ⚠️ |
| `-[PlayerEntity setGalacticHyperspaceBehaviour:]` (11357) | `setGalacticHyperspaceBehaviour` Core/Entities/PlayerEntity.cpp:11954 | ✅ |
| `-[PlayerEntity galacticHyperspaceBehaviour]` (11364) | `getGalacticHyperspaceBehaviour` Core/Entities/PlayerEntity.cpp:11961 | ✅ |
| `-[PlayerEntity setGalacticHyperspaceFixedCoords:]` (11369) | `setGalacticHyperspaceFixedCoords` Core/Entities/PlayerEntity.cpp:11966 | ✅ |
| `-[PlayerEntity setGalacticHyperspaceFixedCoordsX:y:]` (11374) | `setGalacticHyperspaceFixedCoordsX` Core/Entities/PlayerEntity.cpp:11971 | ✅ |
| `-[PlayerEntity galacticHyperspaceFixedCoords]` (11380) | `getGalacticHyperspaceFixedCoords` Core/Entities/PlayerEntity.cpp:11977 | ✅ |
| `-[PlayerEntity setWitchspaceCountdown:]` (11385) | `setWitchspaceCountdown` Core/Entities/PlayerEntity.cpp:11982 | ✅ |
| `-[PlayerEntity longRangeChartMode]` (11390) | `getLongRangeChartMode` Core/Entities/PlayerEntity.cpp:11987 | ✅ |
| `-[PlayerEntity setLongRangeChartMode:]` (11395) | `setLongRangeChartMode` Core/Entities/PlayerEntity.cpp:11992 | ✅ |
| `-[PlayerEntity scoopOverride]` (11400) | `getScoopOverride` Core/Entities/PlayerEntity.cpp:11997 | ✅ |
| `-[PlayerEntity setScoopOverride:]` (11405) | `setScoopOverride` Core/Entities/PlayerEntity.cpp:12002 | ✅ |
| `-[PlayerEntity fuelChargeRate]` (11413) | `fuelChargeRate` Core/Entities/PlayerEntity.cpp:12009 | ✅ |
| `-[PlayerEntity setDockTarget:]` (11429) | `setDockTarget` Core/Entities/PlayerEntity.cpp:12029 | ✅ |
| `-[PlayerEntity jumpCause]` (11438) | `jumpCause` Core/Entities/PlayerEntity.cpp:12038 | ✅ |
| `-[PlayerEntity setJumpCause:]` (11443) | `setJumpCause` Core/Entities/PlayerEntity.cpp:12043 | ✅ |
| `-[PlayerEntity commanderName]` (11450) | `commanderName` Core/Entities/PlayerEntity.cpp:12049 | ✅ |
| `-[PlayerEntity lastsaveName]` (11455) | `lastsaveName` Core/Entities/PlayerEntity.cpp:12054 | ✅ |
| `-[PlayerEntity setCommanderName:]` (11460) | `setCommanderName` Core/Entities/PlayerEntity.cpp:12059 | ✅ |
| `-[PlayerEntity setLastsaveName:]` (11467) | `setLastsaveName` Core/Entities/PlayerEntity.cpp:12065 | ✅ |
| `-[PlayerEntity isDocked]` (11475) | `isDocked` Core/Entities/PlayerEntity.cpp:12075 | ✅ |
| `-[PlayerEntity clearedToDock]` (11529) | `clearedToDock` Core/Entities/PlayerEntity.cpp:12129 | ✅ |
| `-[PlayerEntity setDockingClearanceStatus:]` (11534) | `setDockingClearanceStatus` Core/Entities/PlayerEntity.cpp:12134 | ✅ |
| `-[PlayerEntity getDockingClearanceStatus]` (11550) | `getDockingClearanceStatus` Core/Entities/PlayerEntity.cpp:12150 | ✅ |
| `-[PlayerEntity penaltyForUnauthorizedDocking]` (11555) | `penaltyForUnauthorizedDocking` Core/Entities/PlayerEntity.cpp:12155 | ✅ |
| `-[PlayerEntity addScannedWormhole:]` (11572) | `addScannedWormhole` Core/Entities/PlayerEntity.cpp:12172 | ✅ |
| `-[PlayerEntity updateWormholes]` (11590) | `updateWormholes` Core/Entities/PlayerEntity.cpp:12189 | ✅ |
| `-[PlayerEntity scannedWormholes]` (11620) | `getScannedWormholes` Core/Entities/PlayerEntity.cpp:12218 | ✅ |
| `-[PlayerEntity initialiseMissionDestinations:andLegacy:]` (11625) | `initialiseMissionDestinations` Core/Entities/PlayerEntity.cpp:12223 | ✅ |
| `-[PlayerEntity markerKey:]` (11657) | `markerKey` Core/Entities/PlayerEntity.cpp:12245 | ✅ |
| `-[PlayerEntity addMissionDestinationMarker:]` (11662) | `addMissionDestinationMarker` Core/Entities/PlayerEntity.cpp:12253 | ✅ |
| `-[PlayerEntity removeMissionDestinationMarker:]` (11672) | `removeMissionDestinationMarker` Core/Entities/PlayerEntity.cpp:12263 | ✅ |
| `-[PlayerEntity getMissionDestinations]` (11686) | `getMissionDestinations` Core/Entities/PlayerEntity.cpp:12273 | ❌ |
| `-[PlayerEntity shipyardRecord]` (11691) | `shipyardRecord` Core/Entities/PlayerEntity.cpp:12278 | ✅ |
| `-[PlayerEntity setLastShot:]` (11696) | `setLastShot` Core/Entities/PlayerEntity.cpp:12283 | ✅ |
| `-[PlayerEntity clearExtraMissionKeys]` (11701) | `clearExtraMissionKeys` Core/Entities/PlayerEntity.cpp:12288 | ✅ |
| `-[PlayerEntity setExtraMissionKeys:]` (11707) | `setExtraMissionKeys` Core/Entities/PlayerEntity.cpp:12293 | ✅ |
| `-[PlayerEntity clearExtraGuiScreenKeys:key:]` (11718) | `clearExtraGuiScreenKeys` Core/Entities/PlayerEntity.cpp:12304 | ❌ |
| `-[PlayerEntity setExtraGuiScreenKeys:definition:]` (11733) | `setExtraGuiScreenKeys` Core/Entities/PlayerEntity.cpp:12325 | ⚠️ |
| `-[PlayerEntity dumpSelfState]` (11794) | `dumpSelfState` Core/Entities/PlayerEntity.cpp:12381 | ✅ |
| `-[PlayerEntity suppressClangStuff]` (11856) | `suppressClangStuff` Core/Entities/PlayerEntity.cpp:12458 | ✅ |
| `marketSorterByName()` (11868) | `marketSorterByName` Core/Entities/PlayerEntity.cpp:209 | ✅ |
| `marketSorterByPrice()` (11874) | `marketSorterByPrice` Core/Entities/PlayerEntity.cpp:217 | ✅ |
| `marketSorterByQuantity()` (11887) | `marketSorterByQuantity` Core/Entities/PlayerEntity.cpp:223 | ✅ |
| `marketSorterByMassUnit()` (11900) | `marketSorterByMassUnit` Core/Entities/PlayerEntity.cpp:229 | ✅ |

**Differences:**

- ❌ **med** — `printIdentLockedOnForMissile` resolves the target name via `oo::ToShip(primaryTarget())`; upstream sent `-identFromShip:` to any target. `WormholeEntity` is not a `ShipEntity` but has its own `identFromShip` (`Core/Entities/WormholeEntity.cpp:592`), so with ident engaged on a wormhole the "ident-locked-onto-target" message shows an empty name instead of the wormhole description. — upstream `Core/Entities/PlayerEntity.m:10917` ↔ port `Core/Entities/PlayerEntity.cpp:11504`
- ❌ **low** — `setGuiToMarketInfoScreen` adds pod contents at `quantityInHold[j]` with no `NSNotFound` guard (the market screen has one). With a filter hiding a carried good, `j` is out of range in both trees; upstream scribbled below a stack VLA, the port writes before a `std::vector` heap buffer (heap corruption/crash risk). — upstream `Core/Entities/PlayerEntity.m:9922` ↔ port `Core/Entities/PlayerEntity.cpp:10485`
- ❌ **low** — `getMissionDestinations` now returns a `std::map` ordered by the `"%d-name"` key, not NSMutableDictionary order, so `mission.markedSystems` lists markers in a different order; no comment/ADR marks it intentional. — upstream `Core/Entities/PlayerEntity.m:11686` (`Core/Scripting/OOJSMission.m:191`) ↔ port `Core/Entities/PlayerEntity.cpp:12273` (`Core/Entities/PlayerEntity.h:1463`)
- ❌ **low** — `clearExtraGuiScreenKeys`: upstream sent `-oo_stringForKey:` to an `OOJSGuiScreenKeyDefinition` (not a dictionary), raising an unrecognised-selector exception reported as a JS error whenever definitions exist; the port silently never matches. Nothing is removed in either tree; only the upstream error report disappears. — upstream `Core/Entities/PlayerEntity.m:11725` ↔ port `Core/Entities/PlayerEntity.cpp:12316`
- ❌ **low** — `removeTrumble` "trumble.zombie" log prints a bare pointer where upstream's `%@` printed `<OOTrumble: 0x…>`; log class unchanged, text differs. — upstream `Core/Entities/PlayerEntity.m:10603` ↔ port `Core/Entities/PlayerEntity.cpp:11179`
- ⚠️ **low** — `cargoListForScripting` skips pods whose commodity is nil/unknown (upstream indexed with `NSNotFound`, undefined behaviour) and omits `displayName` where upstream raised on nil; port comment marks it deliberate. — upstream `Core/Entities/PlayerEntity.m:7409` ↔ port `Core/Entities/PlayerEntity.cpp:7906`
- ⚠️ **low** — `markedDestinations` adds a system's markers in `std::map` key byte order, not NSDictionary order (comment "ORDER-SENSITIVE"); draw order of several markers on one system can change. — upstream `Core/Entities/PlayerEntity.m:7737` ↔ port `Core/Entities/PlayerEntity.cpp:8206`
- ⚠️ **low** — `setGuiToInterfacesScreen` uses `std::stable_sort` over `interfaceCompare`; ties (same category and title) keep map byte order instead of NSDictionary key order (comment "ORDER-SENSITIVE"). — upstream `Core/Entities/PlayerEntity.m:8597` ↔ port `Core/Entities/PlayerEntity.cpp:9104`
- ⚠️ **low** — `addEquipmentFromCollection` walks a dictionary in key byte order (comment "key byte order (was NSDictionary order)"), which fixes `eqScripts`/`customEquipActivation` order and so priming order after load; NSSet input gone, non-string array elements skipped. — upstream `Core/Entities/PlayerEntity.m:10278` ↔ port `Core/Entities/PlayerEntity.cpp:10859`
- ⚠️ **low** — `worldScriptNames`/`worldScriptsByName` return world scripts in load order rather than `-allKeys` order ("ORDER-SENSITIVE (decision D)"). — upstream `Core/Entities/PlayerEntity.m:11284,11289` ↔ port `Core/Entities/PlayerEntity.cpp:11866,11875`
- ⚠️ **low** — `doWorldEventUntilMissionScreen`/`doWorldScriptEvent` call world scripts in load order over a snapshot ("ORDER-SENSITIVE (decision D)"); which script runs first, and so which one raises a mission screen first, can differ. — upstream `Core/Entities/PlayerEntity.m:11330,11350` ↔ port `Core/Entities/PlayerEntity.cpp:11910,11944`
- ⚠️ **low** — `setExtraGuiScreenKeys` checks existing definitions in byte order; only the order of "key already in use" log lines can change (comment). — upstream `Core/Entities/PlayerEntity.m:11773` ↔ port `Core/Entities/PlayerEntity.cpp:12359`
- ❌ **low** — (helper, no row) `adjustPriceByScriptForEqKey` relies on `ooscript::valueToInt32`, whose range check is `d > 2147483647 || d < -2147483648`; SpiderMonkey 1.8.5 `JS_ValueToInt32` accepted up to `< 2147483648`. A script price in (2147483647, 2147483648) now errors and is ignored instead of rounding. — upstream `Core/Entities/PlayerEntity.m:9093` ↔ port `Core/Scripting/ooscript/JSEngine_quickjs.cpp:2445`
- ➖ **low** — `setGuiToGameOptionsScreen` drops the `#if !NEW_PLANETS` "procedurally textured planets" row and its enum entry; upstream compiles with `NEW_PLANETS 1` (`OOStellarBody.h:35`), so the code was dead and row numbers match. — upstream `Core/Entities/PlayerEntity.m:8019` ↔ port `Core/Entities/PlayerEntity.cpp:8508`
- ✅ **low** — Nil arguments to `OOExpandKey` (which raised upstream) become `""` in the port, with comments (`witch-blocked`, `status-hyperspace-system-multi`, `equipment-plural*`, `equipment-primed`, `manifest-cargo-quantity*`); an exception path becomes text with an empty field. — upstream `Core/Entities/PlayerEntity.m:6556,7043,7177,7193,7285,7384` ↔ port `Core/Entities/PlayerEntity.cpp:7002,7524,7655,7672,7771,7877`
- ✅ **low** — `contractsListForScriptingFromArray` omits a key whose value is nil where upstream threw in `setObject:forKey:` (port comment :7951). — upstream `Core/Entities/PlayerEntity.m:7455-7474` ↔ port `Core/Entities/PlayerEntity.cpp:7952-7981`
- ✅ **low** — Status screen and `equipmentList` dereference `gui` unguarded where upstream nil-messaging made a no-op; unreachable (gui always exists). `currentPrimedEquipment` returns `""` rather than nil when the index exceeds the count (extra guard). — upstream `Core/Entities/PlayerEntity.m:7058,7156,7265` ↔ port `Core/Entities/PlayerEntity.cpp:7540,7632,7746`
- ✅ **low** — Status screen verified line-for-line: rows 0–7 and 9 with the same localisation keys, tab stops 20/160/290, colours, `"%.1f %s"` fuel, "(null)" fallbacks matching `%@` of nil, two-column rows truncated at the first nil (`RowOf`, :270), equipment order = reverse `sEquipmentTypes`, damaged first when `prioritiseDamaged`, then berths, then fwd/aft/port/stb weapons. — upstream `Core/Entities/PlayerEntity.m:7006` ↔ port `Core/Entities/PlayerEntity.cpp:7485`
- ✅ **low** — System data screen verified: tabs 0/96/144 (`kGuiSystemdataTabs`), 16 `sysdata-line-N` lines with the same 8 args split on `\t` (empty third column dropped), `%.1f ly` with 0.1 floor, ANA route string with the 0.95/1.05 plural rule, long text at row 17 (15 without data), NONAME/NODATA concealment, nova zeroing with `nova-system-*` keys, RNG save/restore around the background. — upstream `Core/Entities/PlayerEntity.m:7503` ↔ port `Core/Entities/PlayerEntity.cpp:8010`
- ✅ **low** — Bounty/kills/witchspace maths verified: `markAsOffender` OR, `shipBountyChanged` args, score ×10 (÷10 for cargo/buoys/rocks except tharglets), `bounty-awarded` when score > 9, `right-on-commander` every 256 kills, fuel `10*max(0.1,d)`, malfunction 253/256 at trade-in ≥ 100, misjump when `randf() > 0.75`, galactic-jump role clearing at 6400/2560 kills. — upstream `Core/Entities/PlayerEntity.m:6020-6098,6546-6747` ↔ port `Core/Entities/PlayerEntity.cpp:6428-6507,6992-7200`
- ✅ **low** — Equipment purchase maths verified: price = fuel/renovation/unit price → script adjustment (truncated) → ×priceFactor → ÷2 for repair; install time `600+price`; laser trade-in × weapon-offset multiplier with `doTradeIn` factor only below 1.0; energy-unit refunds /2, /4, ×3/4, ×3/8 in integer maths; renovation adds `5+techLevel` capped at 100; berths ±1 at 5 t; missile removal credit `(int)` price; `playerBoughtEquipment` args and unsigned wrap identical. — upstream `Core/Entities/PlayerEntity.m:8990-9440` ↔ port `Core/Entities/PlayerEntity.cpp:9530-9989`
- ✅ **low** — `noteGUIDidChangeFrom` verified: demo ship released for SHIPYARD/LOAD/SAVE, sun colour from `info_system_id` on SYSTEM_DATA else `system_id`, `guiScreenChanged(to, from)` skipped when paused. — upstream `Core/Entities/PlayerEntity.m:8952` ↔ port `Core/Entities/PlayerEntity.cpp:9488`
- ✅ **low** — (risk) `marketSorterByName` compares UTF-16 units via `oo::str::compare`, not modelling GNUstep composed/decomposed equivalence (`oofnd/String.hpp:1260`); localised names with combining marks could sort differently. Ties stable. — upstream `Core/Entities/PlayerEntity.m:11871` ↔ port `Core/Entities/PlayerEntity.cpp:214`
- ✅ **low** — `renovationFactor` returns 0.0 (not 1.0) with no shipyard entry in both trees (nil messaging upstream, null `PList::get` in the port). `getFined`, `penaltyForUnauthorizedDocking` (`credits*0.05`, cap 50000), buy/sell limits, `removeFromPylon` and `fuelChargeRate` integer division all match. — upstream `Core/Entities/PlayerEntity.m:10450-10505,11555` ↔ port `Core/Entities/PlayerEntity.cpp:11027-11083,12155`

## PlayerEntityContracts

<a id="playerentitycontracts"></a>
Upstream `src/Core/Entities/PlayerEntityContracts.m` ↔ `Core/Entities/PlayerEntityContracts.cpp`

**Status:** done — 41 rows: 40 ✅ 1 ⚠️ 0 ❌ 0 ➖

Scope note: this file does **not** generate passenger, parcel or cargo contracts. Upstream generates them in the JS world scripts (`oolite-contracts-*.js`). This category only accepts contracts (`addPassenger…`, `addParcel…`, `awardContract…`, called from JS), settles them on docking (`checkPassengerContracts`), and draws the manifest and report screens. The RNG uses that do live here were checked: `randf()` for the tip and halving loops, `Ranrot()` for escape-pod bounty against insurance and for the cargo IDs in `awardContract`, and `market_rnd` in the reputation getters. Each one is called in the same order and under the same conditions as upstream.

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(Contracts) processEscapePods]` (61) | `PlayerEntity::processEscapePods` Core/Entities/PlayerEntityContracts.cpp:94 | ✅ |
| `-[PlayerEntity(Contracts) checkPassengerContracts]` (147) | `PlayerEntity::checkPassengerContracts` Core/Entities/PlayerEntityContracts.cpp:186 | ✅ |
| `-[PlayerEntity(Contracts) contractedVolumeForGood:]` (422) | `PlayerEntity::contractedVolumeForGood` Core/Entities/PlayerEntityContracts.cpp:466 | ✅ |
| `-[PlayerEntity(Contracts) addMessageToReport:]` (435) | `PlayerEntity::addMessageToReport` Core/Entities/PlayerEntityContracts.cpp:478 | ✅ |
| `-[PlayerEntity(Contracts) reputation]` (445) | `PlayerEntity::getReputation` Core/Entities/PlayerEntityContracts.cpp:488 | ✅ |
| `-[PlayerEntity(Contracts) passengerReputation]` (450) | `PlayerEntity::passengerReputation` Core/Entities/PlayerEntityContracts.cpp:493 | ✅ |
| `-[PlayerEntity(Contracts) increasePassengerReputation:]` (464) | `PlayerEntity::increasePassengerReputation` Core/Entities/PlayerEntityContracts.cpp:507 | ✅ |
| `-[PlayerEntity(Contracts) decreasePassengerReputation:]` (489) | `PlayerEntity::decreasePassengerReputation` Core/Entities/PlayerEntityContracts.cpp:532 | ✅ |
| `-[PlayerEntity(Contracts) parcelReputation]` (514) | `PlayerEntity::parcelReputation` Core/Entities/PlayerEntityContracts.cpp:557 | ✅ |
| `-[PlayerEntity(Contracts) increaseParcelReputation:]` (528) | `PlayerEntity::increaseParcelReputation` Core/Entities/PlayerEntityContracts.cpp:571 | ✅ |
| `-[PlayerEntity(Contracts) decreaseParcelReputation:]` (553) | `PlayerEntity::decreaseParcelReputation` Core/Entities/PlayerEntityContracts.cpp:596 | ✅ |
| `-[PlayerEntity(Contracts) contractReputation]` (578) | `PlayerEntity::contractReputation` Core/Entities/PlayerEntityContracts.cpp:621 | ✅ |
| `-[PlayerEntity(Contracts) increaseContractReputation:]` (592) | `PlayerEntity::increaseContractReputation` Core/Entities/PlayerEntityContracts.cpp:635 | ✅ |
| `-[PlayerEntity(Contracts) decreaseContractReputation:]` (617) | `PlayerEntity::decreaseContractReputation` Core/Entities/PlayerEntityContracts.cpp:660 | ✅ |
| `-[PlayerEntity(Contracts) erodeReputation]` (642) | `PlayerEntity::erodeReputation` Core/Entities/PlayerEntityContracts.cpp:685 | ✅ |
| `-[PlayerEntity(Contracts) normaliseReputation]` (696) | `PlayerEntity::normaliseReputation` Core/Entities/PlayerEntityContracts.cpp:739 | ✅ |
| `-[PlayerEntity(Contracts) addPassenger:start:destination:eta:fee:advance:risk:]` (746) | `PlayerEntity::addPassenger` Core/Entities/PlayerEntityContracts.cpp:789 | ✅ |
| `-[PlayerEntity(Contracts) removePassenger:]` (776) | `PlayerEntity::removePassenger` Core/Entities/PlayerEntityContracts.cpp:819 | ✅ |
| `-[PlayerEntity(Contracts) addParcel:start:destination:eta:fee:premium:risk:]` (797) | `PlayerEntity::addParcel` Core/Entities/PlayerEntityContracts.cpp:840 | ✅ |
| `-[PlayerEntity(Contracts) removeParcel:]` (828) | `PlayerEntity::removeParcel` Core/Entities/PlayerEntityContracts.cpp:872 | ✅ |
| `-[PlayerEntity(Contracts) awardContract:commodity:start:]` (849) | `PlayerEntity::awardContract` Core/Entities/PlayerEntityContracts.cpp:893 | ✅ |
| `-[PlayerEntity(Contracts) removeContract:destination:]` (920) | `PlayerEntity::removeContract` Core/Entities/PlayerEntityContracts.cpp:961 | ✅ |
| `-[PlayerEntity(Contracts) passengerList]` (945) | `PlayerEntity::passengerList` Core/Entities/PlayerEntityContracts.cpp:988 | ✅ |
| `-[PlayerEntity(Contracts) parcelList]` (950) | `PlayerEntity::parcelList` Core/Entities/PlayerEntityContracts.cpp:993 | ✅ |
| `-[PlayerEntity(Contracts) contractList]` (955) | `PlayerEntity::contractList` Core/Entities/PlayerEntityContracts.cpp:998 | ✅ |
| `-[PlayerEntity(Contracts) contractsListFromArray:forCargo:forParcels:]` (960) | `PlayerEntity::contractsListFromEntries` Core/Entities/PlayerEntityContracts.cpp:1003 | ✅ |
| `SET_MANIFEST_ROW` macro (984) *(added)* | `SET_MANIFEST_ROW` macro Core/Entities/PlayerEntityContracts.cpp:1038 | ✅ |
| `-[PlayerEntity(Contracts) setGuiToManifestScreen]` (986) | `PlayerEntity::setGuiToManifestScreen` Core/Entities/PlayerEntityContracts.cpp:1040 | ✅ |
| `-[PlayerEntity(Contracts) setManifestScreenRow:inColor:forRow:ofRows:andOffset:inMultipage:]` (1167) | `PlayerEntity::setManifestScreenRow` Core/Entities/PlayerEntityContracts.cpp:1228 | ✅ |
| `-[PlayerEntity(Contracts) setGuiToDockingReportScreen]` (1183) | `PlayerEntity::setGuiToDockingReportScreen` Core/Entities/PlayerEntityContracts.cpp:1250 | ✅ |
| `-[PlayerEntity(Contracts) priceForShipKey:]` (1255) | `PlayerEntity::priceForShipKey` Core/Entities/PlayerEntityContracts.cpp:1369 | ✅ |
| `-[PlayerEntity(Contracts) setGuiToShipyardScreen:]` (1261) | `PlayerEntity::setGuiToShipyardScreen` Core/Entities/PlayerEntityContracts.cpp:1374 | ✅ |
| `-[PlayerEntity(Contracts) showShipyardInfoForSelection]` (1393) | `PlayerEntity::showShipyardInfoForSelection` Core/Entities/PlayerEntityContracts.cpp:1507 | ✅ |
| `-[PlayerEntity(Contracts) showTradeInInformationFooter]` (1463) | `PlayerEntity::showTradeInInformationFooter` Core/Entities/PlayerEntityContracts.cpp:1575 | ✅ |
| `-[PlayerEntity(Contracts) showShipyardModel:shipData:personality:]` (1476) | `PlayerEntity::showShipyardModel` Core/Entities/PlayerEntityContracts.cpp:1588 | ✅ |
| `-[PlayerEntity(Contracts) missingSubEntitiesAdjustment]` (1483) | `PlayerEntity::missingSubEntitiesAdjustment` Core/Entities/PlayerEntityContracts.cpp:1595 | ✅ |
| `-[PlayerEntity(Contracts) tradeInValue]` (1490) | `PlayerEntity::tradeInValue` Core/Entities/PlayerEntityContracts.cpp:1602 | ✅ |
| `-[PlayerEntity(Contracts) buySelectedShip]` (1510) | `PlayerEntity::buySelectedShip` Core/Entities/PlayerEntityContracts.cpp:1623 | ✅ |
| `-[PlayerEntity(Contracts) replaceShipWithNamedShip:]` (1620) | `PlayerEntity::replaceShipWithNamedShip` Core/Entities/PlayerEntityContracts.cpp:1746 | ✅ |
| `-[PlayerEntity(Contracts) newShipCommonSetup:yardInfo:baseInfo:]` (1658) | `PlayerEntity::newShipCommonSetup` Core/Entities/PlayerEntityContracts.cpp:1785 | ⚠️ |
| `RepForRisk()` (1764) | `RepForRisk` Core/Entities/PlayerEntityContracts.cpp:1887 | ✅ |

**Differences:**

- ⚠️ **low**: portable equipment carried over to a new ship is re-added in sorted key order. Upstream used `NSMutableSet` hash order. This changes only the order of the `addEquipmentItem(…, NO, "portable")` calls; the port's comment says so. — upstream `Core/Entities/PlayerEntityContracts.m:1725-1742` ↔ port `Core/Entities/PlayerEntityContracts.cpp:1853-1867`
- ✅ note: the fee and deadline maths match exactly. This covers the integer `dest_eta`, the `fee *= 110; fee /= 100; dest_eta *= 0.5` tip loop, the 3600 s threshold for passengers and 86400 s for parcels, the late-delivery fare halving, the cargo `10 * float fee` truncated to `int`, and `acceptable_ratio = 100 - 10*system_id/256`. It also covers `credits += reward` with a `float` reward (the float-precision rounding of `credits` is kept), `RepForRisk` 1/2/4, `MAX_CONTRACT_REP` and the bean-shift loops. — upstream `Core/Entities/PlayerEntityContracts.m:147-418` ↔ port `Core/Entities/PlayerEntityContracts.cpp:186-464`
- ✅ note: the contract and manifest screen text matches. It uses the same `DESC` keys (`passenger-delivered-okay-@-@-@`, `cargo-delivered-short-@-@-d`, `cargo-refused-short-%@`, `contracts-cash-@-load-d-of-d-passengers-d-of-d-berths`, and the rest) with the same argument order. Each report line ends with `\n` and the last one is trimmed, as `appendFormatLine:` did. A nil name prints `(null)` through `FormatArg::null()`. `OOExpandKey` argument names match: `label`/`destination`/`deadline`/`feeDesc`, `current`/`max`, `system`, `shipType`/`tradeIn`/`total`/`credits`. — port `Core/Entities/PlayerEntityContracts.cpp:219-408, 1003-1035, 1125-1128, 1288, 1422, 1584-1585`
- ✅ note: the contract dictionaries keep the upstream number kinds: `signedInteger` for start, destination and amount; double for the times, fee and premium; `unsignedInteger` for risk. The port builds them as `oo::PList::Dict`, so the key order of the in-memory dictionary is sorted rather than hashed. Any effect on the saved XML belongs to the plist writer, not to this file. — port `Core/Entities/PlayerEntityContracts.cpp:792-801, 843-852, 913-924`
- ✅ note (upstream quirk kept): `buySelectedShip` indexes `localShipyard` by `selectedRow - GUI_ROW_SHIPYARD_START` and ignores the page `skip`. It does this both for the `playerWillBuyNewShip` argument and for the ship it removes. — upstream `Core/Entities/PlayerEntityContracts.m:1561,1598` ↔ port `Core/Entities/PlayerEntityContracts.cpp:1673,1723`
- ✅ note: where upstream would have raised an exception, the port is defensive instead. A nil `SHIPYARD_KEY_ID` is skipped where `setObject:forKey:nil` raised, and a nil `CARGO_KEY_ID` is skipped in `removeContract`. A nil value in an `OOExpandKey` dictionary is left out where `dictionaryWithObjects:count:` raised. These change behaviour only on malformed data. — port `Core/Entities/PlayerEntityContracts.cpp:1404-1408, 977-979, 1022-1030`

## PlayerEntityControls

<a id="playerentitycontrols"></a>
Upstream `src/Core/Entities/PlayerEntityControls.m` ↔ `Core/Entities/PlayerEntityControls.cpp`

**Status:** done — 50 rows: 40 ✅ 6 ⚠️ 4 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| file-scope statics / `#define`s (68–165) | statics + `CUSTOM_VIEW_*` defines Core/Entities/PlayerEntityControls.cpp:75–183 | ✅ |
| (port-only) `AnyKeyPressed`, replaces bitwise `a \| b \| c` | `AnyKeyPressed` Core/Entities/PlayerEntityControls.cpp:81 | ⚠️ |
| (port-only) `OOExpandKey(...)` macro uses (839, 1299) | `ExpandKeyWithArguments` Core/Entities/PlayerEntityControls.cpp:189 | ✅ |
| (extracted) click-row lookup, inline `UNIVERSE->cursor_row` (745–756) | `ClickedGUIRow` (static) Core/Entities/PlayerEntityControls.cpp:664 | ⚠️ |
| `-[PlayerEntity(Controls) initControls]` (203) | `PlayerEntity::initControls` Core/Entities/PlayerEntityControls.cpp:198 | ✅ |
| `-[PlayerEntity(Controls) initKeyConfigSettings]` (293) | `PlayerEntity::initKeyConfigSettings` Core/Entities/PlayerEntityControls.cpp:288 | ❌ |
| `-[PlayerEntity(Controls) processKeyCode:]` (512) | `PlayerEntity::processKeyCode` Core/Entities/PlayerEntityControls.cpp:479 | ❌ |
| `-[PlayerEntity(Controls) checkNavKeyPress:]` (591) | `PlayerEntity::checkNavKeyPress` Core/Entities/PlayerEntityControls.cpp:548 | ✅ |
| `-[PlayerEntity(Controls) checkKeyPress:]` (603) | `PlayerEntity::checkKeyPress(const oo::PList&)` Core/Entities/PlayerEntityControls.cpp:561 | ✅ |
| `-[PlayerEntity(Controls) checkKeyPress:fKey_only:]` (608) | `PlayerEntity::checkKeyPress(const oo::PList&, bool)` Core/Entities/PlayerEntityControls.cpp:566 | ✅ |
| `-[PlayerEntity(Controls) checkKeyPress:ignore_ctrl:]` (613) | `PlayerEntity::checkKeyPressIgnoreCtrl` Core/Entities/PlayerEntityControls.cpp:571 | ✅ |
| `-[PlayerEntity(Controls) checkKeyPress:fKey_only:ignore_ctrl:]` (618) | `PlayerEntity::checkKeyPress(const oo::PList&, bool, bool)` Core/Entities/PlayerEntityControls.cpp:576 | ✅ |
| `-[PlayerEntity(Controls) getFirstKeyCode:]` (642) | `PlayerEntity::getFirstKeyCode` Core/Entities/PlayerEntityControls.cpp:601 | ✅ |
| `-[PlayerEntity(Controls) pollControls:]` (648) | `PlayerEntity::getPollControls` Core/Entities/PlayerEntityControls.cpp:607 | ✅ |
| `-[PlayerEntity(Controls) handleGUIUpDownArrowKeys]` (697) | `PlayerEntity::handleGUIUpDownArrowKeys` Core/Entities/PlayerEntityControls.cpp:678 | ⚠️ |
| `-[PlayerEntity(Controls) targetNewSystem:whileTyping:]` (772) | `PlayerEntity::targetNewSystem(int, bool)` Core/Entities/PlayerEntityControls.cpp:750 | ✅ |
| `-[PlayerEntity(Controls) clearPlanetSearchString]` (785) | `PlayerEntity::clearPlanetSearchString` Core/Entities/PlayerEntityControls.cpp:763 | ✅ |
| `-[PlayerEntity(Controls) targetNewSystem:]` (793) | `PlayerEntity::targetNewSystem(int)` Core/Entities/PlayerEntityControls.cpp:770 | ✅ |
| `-[PlayerEntity(Controls) switchToMainView]` (798) | `PlayerEntity::switchToMainView` Core/Entities/PlayerEntityControls.cpp:775 | ✅ |
| `-[PlayerEntity(Controls) noteSwitchToView:fromView:]` (813) | `PlayerEntity::noteSwitchToView` Core/Entities/PlayerEntityControls.cpp:795 | ✅ |
| `-[PlayerEntity(Controls) beginWitchspaceCountdown:]` (818) | `PlayerEntity::beginWitchspaceCountdown(int)` Core/Entities/PlayerEntityControls.cpp:800 | ✅ |
| `-[PlayerEntity(Controls) beginWitchspaceCountdown]` (846) | `PlayerEntity::beginWitchspaceCountdown()` Core/Entities/PlayerEntityControls.cpp:830 | ✅ |
| `-[PlayerEntity(Controls) cancelWitchspaceCountdown]` (853) | `PlayerEntity::cancelWitchspaceCountdown` Core/Entities/PlayerEntityControls.cpp:837 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollApplicationControls]` (868) | `PlayerEntity::pollApplicationControls` Core/Entities/PlayerEntityControls.cpp:849 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollFlightControls:]` (1043) | `PlayerEntity::pollFlightControls` Core/Entities/PlayerEntityControls.cpp:1047 | ❌ |
| `-[PlayerEntity(OOControlsPrivate) pollGuiArrowKeyControls:]` (1795) | `PlayerEntity::pollGuiArrowKeyControls` Core/Entities/PlayerEntityControls.cpp:1834 | ⚠️ |
| `-[PlayerEntity(OOControlsPrivate) pollMarketScreenControls]` (2706) | `PlayerEntity::pollMarketScreenControls` Core/Entities/PlayerEntityControls.cpp:2780 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleGameOptionsScreenKeys]` (2899) | `PlayerEntity::handleGameOptionsScreenKeys` Core/Entities/PlayerEntityControls.cpp:2975 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleKeyMapperScreenKeys]` (3332) | `PlayerEntity::handleKeyMapperScreenKeys` Core/Entities/PlayerEntityControls.cpp:3434 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleKeyboardLayoutKeys]` (3365) | `PlayerEntity::handleKeyboardLayoutKeys` Core/Entities/PlayerEntityControls.cpp:3467 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleStickMapperScreenKeys]` (3398) | `PlayerEntity::handleStickMapperScreenKeys` Core/Entities/PlayerEntityControls.cpp:3500 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollCustomViewControls]` (3433) | `PlayerEntity::pollCustomViewControls` Core/Entities/PlayerEntityControls.cpp:3535 | ⚠️ |
| `-[PlayerEntity(OOControlsPrivate) pollViewControls]` (3554) | `PlayerEntity::pollViewControls` Core/Entities/PlayerEntityControls.cpp:3661 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollFlightArrowKeyControls:]` (3679) | `PlayerEntity::pollFlightArrowKeyControls` Core/Entities/PlayerEntityControls.cpp:3789 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollGuiScreenControls]` (3889) | `PlayerEntity::pollGuiScreenControls` Core/Entities/PlayerEntityControls.cpp:4000 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollGuiScreenControlsWithFKeyAlias:]` (3894) | `PlayerEntity::pollGuiScreenControlsWithFKeyAlias` Core/Entities/PlayerEntityControls.cpp:4005 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollGameOverControls:]` (4016) | `PlayerEntity::pollGameOverControls` Core/Entities/PlayerEntityControls.cpp:4133 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollAutopilotControls:]` (4034) | `PlayerEntity::pollAutopilotControls` Core/Entities/PlayerEntityControls.cpp:4152 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollDockedControls:]` (4108) | `PlayerEntity::pollDockedControls` Core/Entities/PlayerEntityControls.cpp:4227 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleUndockControl]` (4174) | `PlayerEntity::handleUndockControl` Core/Entities/PlayerEntityControls.cpp:4299 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) pollDemoControls:]` (4188) | `PlayerEntity::pollDemoControls` Core/Entities/PlayerEntityControls.cpp:4314 | ⚠️ |
| `-[PlayerEntity(OOControlsPrivate) pollMissionInterruptControls]` (4497) | `PlayerEntity::pollMissionInterruptControls` Core/Entities/PlayerEntityControls.cpp:4632 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleMissionCallback]` (4514) | `PlayerEntity::handleMissionCallback` Core/Entities/PlayerEntityControls.cpp:4650 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) setGuiToMissionEndScreen]` (4542) | `PlayerEntity::setGuiToMissionEndScreen` Core/Entities/PlayerEntityControls.cpp:4679 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) switchToThisView:]` (4598) | `PlayerEntity::switchToThisView(OOViewID)` Core/Entities/PlayerEntityControls.cpp:4736 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) switchToThisView:andProcessWeaponFacing:]` (4603) | `PlayerEntity::switchToThisView(OOViewID, bool)` Core/Entities/PlayerEntityControls.cpp:4741 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) switchToThisView:fromView:andProcessWeaponFacing:justNotify:]` (4608) | `PlayerEntity::switchToThisView(OOViewID, OOViewID, bool, bool)` Core/Entities/PlayerEntityControls.cpp:4746 | ❌ |
| `-[PlayerEntity(OOControlsPrivate) handleAutopilotOn:]` (4653) | `PlayerEntity::handleAutopilotOn` Core/Entities/PlayerEntityControls.cpp:4792 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleButtonIdent]` (4758) | `PlayerEntity::handleButtonIdent` Core/Entities/PlayerEntityControls.cpp:4904 | ✅ |
| `-[PlayerEntity(OOControlsPrivate) handleButtonTargetMissile]` (4775) | `PlayerEntity::handleButtonTargetMissile` Core/Entities/PlayerEntityControls.cpp:4922 | ✅ |

Checked and equal:
- **Default key bindings:** all 144 `LOAD_KEY_SETTING2` lines (key code, shift, mod1, second key) are byte-identical. In upstream `keyDef` is never allocated (`NSMutableArray* keyDef = nil`), so the defaults are built but never stored, and every binding comes from `keyconfig2.plist`. The port drops the dead construction and says so in a comment. Both merge in the same order: the `keyboard-code` layout (fallback `"default"`, run through `processKeyCode`), then the `KeyConfigOverrides` default on top, unprocessed.
- **Constants:** `KEY_REPEAT_INTERVAL` 0.20, `MINIMUM_GAME_TICK` 0.25, `SHIP_THRUST_FACTOR` 5, `DEFAULT_HYPERSPACE_SPIN_TIME` 15, `CUSTOM_VIEW_ROTATE_SPEED` 1.0 / `_ZOOM_SPEED` 5.0 / `_SPEED_REDUCTION_FACTOR` 0.3, the precision factor (default 0.5, clamped to [0.05, 1.0]), mouse sensitivity 2.0, view-switch threshold 0.5, scanner zoom limits 5.0/1.0, and the chart lerp (3:1, /4) and zoom factors.
- **Debounce:** every `*_pressed` flag and `timeLastKeyPress` repeat is set and cleared in the same order.
- **Flight input:** the roll/pitch/yaw dampner ramps, the `-reqYaw` sign, `STICK_AXISUNASSIGNED` zeroing and the keyboard-override cancel rules match.
- **Strings:** the `DESC`/expander keys (`seconds`, `destination`, `equipmentName`, `brightnessValue`, `voiceName`, `musicMode`, `colorblindModeDesc`, `detailLevel`) match.
- **Autopilot:** the `handleAutopilotOn:` fine maths (`ranrot_rand() & 0x3ff`, `/ (1+government)`, interstellar = 2), the +1200 s clock penalty, and the order `forceWitchspaceEntries` → `safeAllMissiles` → `setViewDirection` → `enterDock` match.

**Differences:**

- ❌ **low** — **Key-config errors no longer abort.** Case: the chosen keyboard layout lacks a binding (or `keyboard-code` names no layout, so `kdic2` is empty).
  - Upstream: `[kdic2 setObject:curr ?: keyDef …]` inserts nil (`keyDef` is always nil), which raises and aborts `initKeyConfigSettings`/`initControls`. `keyconfig2_settings` is not stored, the later `n_key_*` stay stale, and the exception reaches the caller.
  - Port: leaves that one `n_key_*` as a null PList (unbound) and carries on.
  - Error path only; the shipped plist has every key — upstream `Core/Entities/PlayerEntityControls.m:331,348-359` ↔ port `Core/Entities/PlayerEntityControls.cpp:318-327`
- ❌ **low** — **A definition with no `"key"` entry** (e.g. `{shift = YES;}`), which is not empty.
  - Upstream: `[defNew setObject:nil forKey:@"key"]` in the non-string branch raises, so the key-config load is aborted.
  - Port: pushes the entry without a key, which reads as key code 0. The port's comment at :539 acknowledges this — upstream `Core/Entities/PlayerEntityControls.m:526,581` ↔ port `Core/Entities/PlayerEntityControls.cpp:538-540`
- ❌ **low** — **The laser-hit sound can throw.** After a successful `fireMainWeapon`, upstream's `[[self currentLaserOffset] oo_vectorAtIndex:0]` gives `kZeroVector` when the offset array is empty. That happens for a multi-mount ship whose `weapon_position_*` is `()`.
  - Port: `currentLaserOffset().at(0)` throws `std::out_of_range`. That is not an `OOException`, so the `catch` rethrows it out of `pollFlightControls`/`getPollControls` instead of logging and continuing — upstream `Core/Entities/PlayerEntityControls.m:1187,1790-1792` ↔ port `Core/Entities/PlayerEntityControls.cpp:1194,1826-1830`
- ❌ **low** — **Error-log text.** With `processWeaponFacing=YES` and a non-main view, upstream's `%s __FUNCTION__` prints the full selector `-[PlayerEntity(OOControlsPrivate) switchToThisView:fromView:andProcessWeaponFacing:justNotify:]`; the port prints `switchToThisView`. The class `general.error.parameterError`, the prefix and the view number are unchanged — upstream `Core/Entities/PlayerEntityControls.m:4642` ↔ port `Core/Entities/PlayerEntityControls.cpp:4781`
- ⚠️ **low** — **Click and double-click on a GUI list.** In `MOUSE_MODE_UI_SCREEN_WITH_INTERACTION` the port selects the row under the pointer now (`rowAtVirtualJoystickPosition`), not `UNIVERSE->cursor_row` from the last render. After a frame stall, a click can select a different row than upstream did. Deliberate (bead oo-3rb.348, comment at :657–663) — upstream `Core/Entities/PlayerEntityControls.m:745-757` ↔ port `Core/Entities/PlayerEntityControls.cpp:664-675,726,733`
- ⚠️ **low** — **`AnyKeyPressed({...})`** replaces bitwise `a | b | c` (bead oo-we7mm). The initializer list still evaluates every operand, so the side effects of the key reads are the same — port `Core/Entities/PlayerEntityControls.cpp:79-88`
- ⚠️ **low** — **Script-registered GUI keys** are walked in `std::map` byte order, not `NSDictionary -allKeys` hash order (port comment: "byte order (was -allKeys order)"). All the keys share one `extra_gui_key_pressed` flag, and the key walked last decides it. So with two or more registered keys, the order can change which held key fires every frame instead of once, and the callback order when two are pressed together — upstream `Core/Entities/PlayerEntityControls.m:2649` ↔ port `Core/Entities/PlayerEntityControls.cpp:2721`
- ⚠️ **low** — **Mission-screen extra keys** are walked in `std::map` order instead of `-allKeys` order (port comment "ORDER-SENSITIVE"). `extra_key_pressed` is reset by every unpressed key after a pressed one, so the order decides which bound key latches or repeats, and which key wins when two are held — upstream `Core/Entities/PlayerEntityControls.m:4441-4451` ↔ port `Core/Entities/PlayerEntityControls.cpp:4576-4588`
- ⚠️ **low** — **The custom-view timer** uses `oo::date::monotonicSeconds()` instead of `[NSDate timeIntervalSinceReferenceDate]` (commented "intervals only"). The zoom/rotate `delta_t` is the same except across a wall-clock jump, or on the very first call (`last_time = 0`), where the size of the bogus first delta differs. The 0.20 s escape-pod double-press window and the paused-options `time_last_frame` (:1461, :1469, :1662) use the same substitution — upstream `Core/Entities/PlayerEntityControls.m:3463` ↔ port `Core/Entities/PlayerEntityControls.cpp:3566`
- ⚠️ **low** — **Fullscreen pause targets.** The quicksave-failure fallback `pauseFullScreenModeToPerform("savePlayer", nil)` (bead oo-w9pi2) and Cmd-Q `("exitAppCommandQ", nil)` (bead oo-9ht.164) pass no target. There is no observable change: on SDL both builds only store the selector/target pair and never perform it — upstream `Core/Entities/PlayerEntityControls.m:2269, 896` ↔ port `Core/Entities/PlayerEntityControls.cpp:2328, 880-882`
- ✅ **low** (note) — **Exception catching.** `getPollControls`, `pollApplicationControls`, `pollFlightControls` and `pollDockedControls` catch only `OOException` and rethrow anything else. Upstream's `@catch (NSException*)` caught every raise, including range errors, which the port sometimes turns into `std::` exceptions (see the laser-offset bullet). The log formats are kept — upstream `Core/Entities/PlayerEntityControls.m:691-693,1038-1040,4169-4171` ↔ port `Core/Entities/PlayerEntityControls.cpp:649-654,1039-1044,4291-4296`
- ✅ **low** (note) — **String modifier flags.** For modifier flags given as strings, upstream uses `-[NSString boolValue]` (a leading 1-9/y/Y/t/T). The port's `get<bool>` uses `OOBooleanFromObject` rules. They differ for strings like "on" or "0.5". The shipped plists use YES/NO — upstream `Core/Entities/PlayerEntityControls.m:634-636` ↔ port `Core/Entities/PlayerEntityControls.cpp:593-595`
- ✅ **low** (note) — **Unchecked dereferences.** Some messages to nil became unchecked dereferences, which would crash where upstream did nothing:
  - `getHud()->setHidden` (:1028)
  - `gui->` in `handleGUIUpDownArrowKeys`/`targetNewSystem` (:690, :752)
  - `gui->setSelectedRow`/`keyForRow`/`clearBackground` (:4071–4122, :4333, :4443, :4562)
  - `UNIVERSE->getGui()->…` (:4248, :4654, :4702)
  - `UNIVERSE->messageGUI()->clear()` (:4254)

  The HUD and GUI are never nil in a running game.
- ✅ **low** (note) — **A nil station or missile name** is expanded as `""` in the port. Upstream's `OOExpandKey` with a nil argument would raise. That needs `ts == nil`, e.g. inside the Aegis with no main station. `handleAutopilotOn` also uses `oo::ToStation(target)` where upstream had a C cast — upstream `Core/Entities/PlayerEntityControls.m:4699-4710, 4801, 4806` ↔ port `Core/Entities/PlayerEntityControls.cpp:4842-4853, 4950, 4956`
- ✅ **low** (note) — **Upstream quirks the port keeps:**
  - Market `NSNotFound` index arithmetic: `++NSIntegerMax` wraps and selects the last item in both (`.m:2775` ↔ `.cpp:2851`).
  - Windows HDR max-brightness lookup: `int brightnessIdx = NSNotFound` narrows to -1, so `"hdr.maxBrightness.notFound"` never logs (`.m:2928` ↔ `.cpp:3009`).
  - The FOV row's `%c` 176 is written as UTF-8 `"\xC2\xB0"`, the same glyph (`.m:3183` ↔ `.cpp:3292`).
  - The always-YES `respondsToSelector:@selector(masterVolume)` guard is dropped (`.m:3130` ↔ `.cpp:3238`).
  - The dead `#if !NEW_PLANETS` options row is dropped, so the row indices still match (`.m:3248`).

## PlayerEntityKeyMapper

<a id="playerentitykeymapper"></a>
Upstream `src/Core/Entities/PlayerEntityKeyMapper.m` ↔ `Core/Entities/PlayerEntityKeyMapper.cpp`

**Status:** done — 43 rows: 40 ✅ 1 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| file-scope statics `key_index`…`camera_keys` (35–44) | statics + anonymous-namespace `selected_entry`/`key_list`/`kdic_check`/`nav_keys`/`camera_keys` Core/Entities/PlayerEntityKeyMapper.cpp:39–51 | ✅ |
| `-[PlayerEntity(KeyMapper) initCheckingDictionary]` (77) | `PlayerEntity::initCheckingDictionary` Core/Entities/PlayerEntityKeyMapper.cpp:192 | ✅ |
| `-[PlayerEntity(KeyMapper) resetKeyFunctions]` (112) | `PlayerEntity::resetKeyFunctions` Core/Entities/PlayerEntityKeyMapper.cpp:215 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyMapperScreen:]` (118) | `PlayerEntity::setGuiToKeyMapperScreen(unsigned)` Core/Entities/PlayerEntityKeyMapper.cpp:220 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyMapperScreen:resetCurrentRow:]` (123) | `PlayerEntity::setGuiToKeyMapperScreen(unsigned, bool)` Core/Entities/PlayerEntityKeyMapper.cpp:225 | ✅ |
| `-[PlayerEntity(KeyMapper) keyMapperInputHandler:view:]` (188) | `PlayerEntity::keyMapperInputHandler` Core/Entities/PlayerEntityKeyMapper.cpp:293 | ❌ |
| `-[PlayerEntity(KeyMapper) entryIsIndexCustomEquip:]` (296) | `PlayerEntity::entryIsIndexCustomEquip` Core/Entities/PlayerEntityKeyMapper.cpp:411 | ✅ |
| `-[PlayerEntity(KeyMapper) entryIsDictCustomEquip:]` (301) | `PlayerEntity::entryIsDictCustomEquip` Core/Entities/PlayerEntityKeyMapper.cpp:416 | ✅ |
| `-[PlayerEntity(KeyMapper) entryIsCustomEquip:]` (306) | `PlayerEntity::entryIsCustomEquip` Core/Entities/PlayerEntityKeyMapper.cpp:421 | ✅ |
| `-[PlayerEntity(KeyMapper) getCustomEquipArray:]` (314) | `PlayerEntity::getCustomEquipArray` Core/Entities/PlayerEntityKeyMapper.cpp:429 | ✅ |
| `-[PlayerEntity(KeyMapper) getCustomEquipIndex:]` (337) | `PlayerEntity::getCustomEquipIndex` Core/Entities/PlayerEntityKeyMapper.cpp:454 | ✅ |
| `-[PlayerEntity(KeyMapper) getCustomEquipKeyDefType:]` (357) | `PlayerEntity::getCustomEquipKeyDefType` Core/Entities/PlayerEntityKeyMapper.cpp:474 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyConfigScreen]` (368) | `PlayerEntity::setGuiToKeyConfigScreen()` Core/Entities/PlayerEntityKeyMapper.cpp:485 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyConfigScreen:]` (373) | `PlayerEntity::setGuiToKeyConfigScreen(bool)` Core/Entities/PlayerEntityKeyMapper.cpp:490 | ✅ |
| `-[PlayerEntity(KeyMapper) outputKeyDefinition:shift:mod1:mod2:skiprows:]` (469) | `PlayerEntity::outputKeyDefinition` Core/Entities/PlayerEntityKeyMapper.cpp:582 | ✅ |
| `-[PlayerEntity(KeyMapper) handleKeyConfigKeys:view:]` (512) | `PlayerEntity::handleKeyConfigKeys` Core/Entities/PlayerEntityKeyMapper.cpp:614 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyConfigEntryScreen]` (548) | `PlayerEntity::setGuiToKeyConfigEntryScreen` Core/Entities/PlayerEntityKeyMapper.cpp:652 | ✅ |
| `-[PlayerEntity(KeyMapper) handleKeyConfigEntryKeys:view:]` (598) | `PlayerEntity::handleKeyConfigEntryKeys` Core/Entities/PlayerEntityKeyMapper.cpp:706 | ✅ |
| `-[PlayerEntity(KeyMapper) updateKeyDefinition:index:]` (630) | `PlayerEntity::updateKeyDefinition` Core/Entities/PlayerEntityKeyMapper.cpp:739 | ✅ |
| `-[PlayerEntity(KeyMapper) updateShiftKeyDefinition:index:]` (656) | `PlayerEntity::updateShiftKeyDefinition` Core/Entities/PlayerEntityKeyMapper.cpp:758 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToConfirmClearScreen]` (698) | `PlayerEntity::setGuiToConfirmClearScreen` Core/Entities/PlayerEntityKeyMapper.cpp:793 | ✅ |
| `-[PlayerEntity(KeyMapper) handleKeyMapperConfirmClearKeys:view:]` (731) | `PlayerEntity::handleKeyMapperConfirmClearKeys` Core/Entities/PlayerEntityKeyMapper.cpp:827 | ✅ |
| `-[PlayerEntity(KeyMapper) displayKeyFunctionList:skip:]` (760) | `PlayerEntity::displayKeyFunctionList` Core/Entities/PlayerEntityKeyMapper.cpp:862 | ✅ |
| `-[PlayerEntity(KeyMapper) keyFunctionList]` (875) | `PlayerEntity::keyFunctionList` Core/Entities/PlayerEntityKeyMapper.cpp:978 | ✅ |
| `-[PlayerEntity(KeyMapper) makeKeyGuiDict:keyDef:]` (1042) | `PlayerEntity::makeKeyGuiDict` Core/Entities/PlayerEntityKeyMapper.cpp:1146 | ✅ |
| `-[PlayerEntity(KeyMapper) makeKeyGuiDictHeader:]` (1052) | `PlayerEntity::makeKeyGuiDictHeader` Core/Entities/PlayerEntityKeyMapper.cpp:1157 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyboardLayoutScreen:]` (1061) | `PlayerEntity::setGuiToKeyboardLayoutScreen(unsigned)` Core/Entities/PlayerEntityKeyMapper.cpp:1166 | ✅ |
| `-[PlayerEntity(KeyMapper) setGuiToKeyboardLayoutScreen:resetCurrentRow:]` (1066) | `PlayerEntity::setGuiToKeyboardLayoutScreen(unsigned, bool)` Core/Entities/PlayerEntityKeyMapper.cpp:1171 | ✅ |
| `-[PlayerEntity(KeyMapper) handleKeyboardLayoutEntryKeys:view:]` (1101) | `PlayerEntity::handleKeyboardLayoutEntryKeys` Core/Entities/PlayerEntityKeyMapper.cpp:1210 | ✅ |
| `-[PlayerEntity(KeyMapper) keyboardDescription:]` (1142) | `PlayerEntity::keyboardDescription` Core/Entities/PlayerEntityKeyMapper.cpp:1257 | ✅ |
| `-[PlayerEntity(KeyMapper) keyboardLayoutList]` (1159) | `PlayerEntity::keyboardLayoutList` Core/Entities/PlayerEntityKeyMapper.cpp:1264 | ⚠️ |
| `-[PlayerEntity(KeyMapper) displayKeyboardLayoutList:skip:]` (1202) | `PlayerEntity::displayKeyboardLayoutList` Core/Entities/PlayerEntityKeyMapper.cpp:1303 | ✅ |
| `-[PlayerEntity(KeyMapper) validateAllKeys]` (1265) | `PlayerEntity::validateAllKeys` Core/Entities/PlayerEntityKeyMapper.cpp:1365 | ✅ |
| `-[PlayerEntity(KeyMapper) validateKey:checkKeys:]` (1282) | `PlayerEntity::validateKey` Core/Entities/PlayerEntityKeyMapper.cpp:1381 | ✅ |
| `-[PlayerEntity(KeyMapper) searchArrayForMatch:key:checkKeys:]` (1416) | `PlayerEntity::searchArrayForMatch` Core/Entities/PlayerEntityKeyMapper.cpp:1523 | ✅ |
| `-[PlayerEntity(KeyMapper) entryIsEqualToDefault:]` (1446) | `PlayerEntity::entryIsEqualToDefault` Core/Entities/PlayerEntityKeyMapper.cpp:1554 | ✅ |
| `-[PlayerEntity(KeyMapper) compareKeyEntries:second:]` (1463) | `PlayerEntity::compareKeyEntries` Core/Entities/PlayerEntityKeyMapper.cpp:1573 | ✅ |
| `-[PlayerEntity(KeyMapper) saveKeySetting:]` (1475) | `PlayerEntity::saveKeySetting` Core/Entities/PlayerEntityKeyMapper.cpp:1584 | ❌ |
| `-[PlayerEntity(KeyMapper) unsetKeySetting:]` (1526) | `PlayerEntity::unsetKeySetting` Core/Entities/PlayerEntityKeyMapper.cpp:1635 | ✅ |
| `-[PlayerEntity(KeyMapper) deleteKeySetting:]` (1548) | `PlayerEntity::deleteKeySetting` Core/Entities/PlayerEntityKeyMapper.cpp:1653 | ✅ |
| `-[PlayerEntity(KeyMapper) deleteAllKeySettings]` (1565) | `PlayerEntity::deleteAllKeySettings` Core/Entities/PlayerEntityKeyMapper.cpp:1673 | ✅ |
| `-[PlayerEntity(KeyMapper) loadKeySettings]` (1591) | `PlayerEntity::loadKeySettings` Core/Entities/PlayerEntityKeyMapper.cpp:1702 | ✅ |
| `-[PlayerEntity(KeyMapper) reloadPage]` (1598) | `PlayerEntity::reloadPage` Core/Entities/PlayerEntityKeyMapper.cpp:1708 | ✅ |

Checked and equal:
- **Function list:** `keyFunctionList` has the same headers, `oolite-keydesc-*` keys, `key_*` definitions and `#if OO_FOV_INFLIGHT_CONTROL_ENABLED` block, in the same order (mechanical diff; `key_bloom_toggle` is commented out in both).
- **Validation groups:** the 10 groups in `validateKey` (gui, debug, customview, inflight + custom equipment, docking, docked, paused, chart, sysinfo, market) list identical keys in the same order (mechanical diff).
- **Text layout:** the tab stops are the same (10/290/400 on the mapper screen, 10/290 on the config and layout screens). So are the `"Function"`/`"Assigned to"`/`"Overrides"` heading, the `"Index:%zu"`/`"More:%zd"` row keys, the paging maths (`MAX_ROWS_KC_FUNCTIONS`, `previous = skip - (MAX-2)`), the selectable ranges, and the `+ 5` row offset for the alternate key.
- **Description truncation:** over 50 UTF-16 units becomes the first 48 + `"..."`.
- **Other screens and saving:** the confirm-clear Y/N bytes (`& 0x00ff`, `- 32`), the shift auto-toggle on one-character keys, and the save path (blank-alternate removal, primary == alternate removal, revert-to-default) match.

**Differences:**

- ❌ **low** — **'u' or 'r' on the "Keyboard layout" row** (`GUI_ROW_KC_SELECTKBD`, key `kbd:…`, inside the selectable range, so `selFunctionIdx = -1`).
  - Upstream: `[keyFunctions objectAtIndex:-1]` raises `NSRangeException`, which `pollControls` catches and logs. Nothing is changed.
  - Port: `KeyFunctionAt(-1)` gives a null entry. For 'u' it calls `unsetKeySetting("")`, which persists a bogus `"" = ()` entry in the `KeyConfigOverrides` default, re-reads the key config and reloads the page. For 'r' it calls `deleteKeySetting("")` (rewrites the overrides unchanged) and reloads — upstream `Core/Entities/PlayerEntityKeyMapper.m:239, 252` ↔ port `Core/Entities/PlayerEntityKeyMapper.cpp:352, 366`
- ❌ **low** — **`saveKeySetting`: two raise paths now complete.**
  - (a) Empty `key_list`, e.g. Save on an entry already unset with 'u'. Upstream's `[key_list objectAtIndex:0]` raises, so nothing is saved, the error is logged and the screen stays. The port treats the key as 0 and saves an empty override (or deletes it if it matches the default), then returns to the list.
  - (b) Primary key cleared (0) while the alternate is set. Upstream sends `-isEqualToString:@""` to the alternate's `"key"`, which `processKeyCode` stored as an `NSNumber`; that raises. The port's `IsEmptyString` returns false and saves `[unset, alternate]`.
  - upstream `Core/Entities/PlayerEntityKeyMapper.m:1488-1489` ↔ port `Core/Entities/PlayerEntityKeyMapper.cpp:1598-1600`
- ⚠️ **low** — **Keyboard-layout list sorting.** Non-default layouts are walked in `std::map` key order and stable-sorted by `"description"` with `oo::str::compare` (port comment cites bead oo-3rb.20). Upstream walked `-allKeys` (hash order) and used `NSSortDescriptor` (ascending, `-compare:`). The result can differ only for layouts with equal or missing descriptions. A keymappings file without a `"default"` entry makes upstream raise on `insertObject:nil`; the port inserts a null row instead — upstream `Core/Entities/PlayerEntityKeyMapper.m:1173-1195` ↔ port `Core/Entities/PlayerEntityKeyMapper.cpp:1271-1297`
- ✅ **low** (note) — **Out-of-range reads.** Where upstream would raise on an out-of-range `objectAtIndex:` (`customEquipActivation` at index -1 in `displayKeyFunctionList`/`searchArrayForMatch`/`saveKeySetting`, `kbdLayouts` beyond the end, `characterAtIndex:0` on an empty yes/no description), the port reads a null entry or 0 and continues. None of these is reachable with consistent data — e.g. upstream `Core/Entities/PlayerEntityKeyMapper.m:822, 1432, 1126, 744` ↔ port `Core/Entities/PlayerEntityKeyMapper.cpp:924, 1537, 1239, 844`
- ✅ **low** (note) — **Unchecked `gui->` dereferences** throughout (upstream messages to a nil GUI did nothing); the GUI is never nil in a running game.

## PlayerEntityLoadSave

<a id="playerentityloadsave"></a>
Upstream `src/Core/Entities/PlayerEntityLoadSave.m` ↔ `Core/Entities/PlayerEntityLoadSave.cpp`

**Status:** done — 26 rows: 23 ✅ 2 ⚠️ 1 ❌ 0 ➖

Scope note: the save-file **keys** are not in this file. They are written by `commanderDataDictionary` and read by `setCommanderDataFromDictionary`, both in `PlayerEntity`. The default commander (the `setUp…`/new-commander dictionary) and the default save directory (`GameController::playerFileDirectory`/`defaultCommanderPath`) are also elsewhere. This file covers the container: the XML write, the load order, file naming, the listing and the error paths. All the layout constants in `PlayerEntityLoadSave.h` (`STARTROW`, `NUMROWS`, `MOREROW`, `BACKROW`, `EXITROW`, `CDRDESCROW`, `INPUTROW`, `LABELROW`, `ENDROW`, `SAVE_OVERWRITE_*_ROW`) are identical in both trees.

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(LoadSave) loadPlayer]` (79) | `PlayerEntity::loadPlayer` Core/Entities/PlayerEntityLoadSave.cpp:134 | ✅ |
| `-[PlayerEntity(LoadSave) savePlayer]` (87) | `PlayerEntity::savePlayer` Core/Entities/PlayerEntityLoadSave.cpp:142 | ✅ |
| `-[PlayerEntity(LoadSave) autosavePlayer]` (92) | `PlayerEntity::autosavePlayer` Core/Entities/PlayerEntityLoadSave.cpp:147 | ✅ |
| `-[PlayerEntity(LoadSave) quicksavePlayer]` (127) | `PlayerEntity::quicksavePlayer` Core/Entities/PlayerEntityLoadSave.cpp:183 | ✅ |
| `-[PlayerEntity(LoadSave) setGuiToScenarioScreen:]` (148) | `PlayerEntity::setGuiToScenarioScreen` Core/Entities/PlayerEntityLoadSave.cpp:204 | ✅ |
| `-[PlayerEntity(LoadSave) addScenarioModel:]` (214) | `PlayerEntity::addScenarioModel` Core/Entities/PlayerEntityLoadSave.cpp:271 | ✅ |
| `-[PlayerEntity(LoadSave) showScenarioDetails]` (219) | `PlayerEntity::showScenarioDetails` Core/Entities/PlayerEntityLoadSave.cpp:276 | ✅ |
| `-[PlayerEntity(LoadSave) startScenario]` (243) | `PlayerEntity::startScenario` Core/Entities/PlayerEntityLoadSave.cpp:304 | ✅ |
| `-[PlayerEntity(LoadSave) commanderSelector]` (281) | `PlayerEntity::commanderSelector` Core/Entities/PlayerEntityLoadSave.cpp:342 | ✅ |
| `-[PlayerEntity(LoadSave) saveCommanderInputHandler]` (364) | `PlayerEntity::saveCommanderInputHandler` Core/Entities/PlayerEntityLoadSave.cpp:434 | ✅ |
| `-[PlayerEntity(LoadSave) overwriteCommanderInputHandler]` (450) | `PlayerEntity::overwriteCommanderInputHandler` Core/Entities/PlayerEntityLoadSave.cpp:527 | ✅ |
| `-[PlayerEntity(LoadSave) loadPlayerFromFile:asNew:]` (481) | `PlayerEntity::loadPlayerFromFile` Core/Entities/PlayerEntityLoadSave.cpp:559 | ⚠️ |
| `-[PlayerEntity(OOLoadSavePrivate) writePlayerToPath:]` (679) | `PlayerEntity::writePlayerToPath` Core/Entities/PlayerEntityLoadSave.cpp:781 | ❌ |
| `-[PlayerEntity(OOLoadSavePrivate) nativeSavePlayer:]` (714) | `PlayerEntity::nativeSavePlayer` Core/Entities/PlayerEntityLoadSave.cpp:823 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) setGuiToLoadCommanderScreen]` (726) | `PlayerEntity::setGuiToLoadCommanderScreen` Core/Entities/PlayerEntityLoadSave.cpp:835 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) setGuiToSaveCommanderScreen:]` (748) | `PlayerEntity::setGuiToSaveCommanderScreen` Core/Entities/PlayerEntityLoadSave.cpp:859 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) setGuiToOverwriteScreen:]` (778) | `PlayerEntity::setGuiToOverwriteScreen` Core/Entities/PlayerEntityLoadSave.cpp:892 | ✅ |
| `sortCommanders()` (814) | lambda in `PlayerEntity::lsCommanders` Core/Entities/PlayerEntityLoadSave.cpp:987 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) lsCommanders:]` (819) | `PlayerEntity::lsCommanders` Core/Entities/PlayerEntityLoadSave.cpp:928 | ⚠️ |
| `-[PlayerEntity(OOLoadSavePrivate) existingNativeSave:]` (983) | `PlayerEntity::existingNativeSave` Core/Entities/PlayerEntityLoadSave.cpp:1088 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) showCommanderShip:]` (992) | `PlayerEntity::showCommanderShip` Core/Entities/PlayerEntityLoadSave.cpp:1097 | ✅ |
| `-[PlayerEntity(OOLoadSavePrivate) findIndexOfCommander:]` (1110) | `PlayerEntity::findIndexOfCommander` Core/Entities/PlayerEntityLoadSave.cpp:1215 | ✅ |
| `-[MyOpenGLView(OOLoadSaveExtensions) isCommandModifierKeyDown]` (1128) | `IsCommandModifierKeyDown` (anon. namespace) Core/Entities/PlayerEntityLoadSave.cpp:126 | ✅ |
| `PersonalityForCommanderDict()` (1135) | `PersonalityForCommanderDict` (anon. namespace) Core/Entities/PlayerEntityLoadSave.cpp:1232 | ✅ |
| `OODeciCreditsFromDouble()` (1147) | `OODeciCreditsFromDouble` Core/Entities/PlayerEntityLoadSave.cpp:1249 | ✅ |
| `OODeciCreditsFromObject()` (1174) | `OODeciCreditsFromPList` Core/Entities/PlayerEntityLoadSave.cpp:1276 | ✅ |

**Differences:**

- ❌ **low**: the "nil path" save-error log line embeds `__PRETTY_FUNCTION__`. Its text changes from `-[PlayerEntity(OOLoadSavePrivate) writePlayerToPath:]` to the C++ signature `void PlayerEntity::writePlayerToPath(const std::string&)`. The guard also fires on an empty path where upstream fired only on nil. Upstream with an empty path would try the write and raise `OoliteException` instead. — upstream `Core/Entities/PlayerEntityLoadSave.m:686-689` ↔ port `Core/Entities/PlayerEntityLoadSave.cpp:788-791`
- ⚠️ **low**: a save file whose root parses but is not a dictionary no longer logs `OODictionaryFromFile`'s `plist.wrongType` line. The load still fails with `loadfailed-could-not-load-file`, and the listing still skips the file. The port's comment says this is deliberate. — upstream `Core/Entities/PlayerEntityLoadSave.m:503,852` ↔ port `Core/Entities/PlayerEntityLoadSave.cpp:582-584, 962-964`
- ✅ note (load error paths): the order of the five checks matches: no file, could not load, `setUseAddOns`, ship type missing or unknown, `setUpAndConfirmOK`, then `setCommanderDataFromDictionary`. Each uses the same `DESC` keys. The failure tail matches too: the `load.failed` line `***** Failed to load saved game "<lastPathComponent>": <reason|unknown error>`, `setPlayerFileToLoad(nil)` (the port passes `""`, which `GameController::setPlayerFileToLoad` maps to nullopt because the extension is not `oolite-save`), `handleGameOver`, and both 9 s messages. The `load.progress` lines are identical. One small change: an empty `fileToOpen` now reports `loadfailed-no-file-specified` (upstream: nil only), but every caller passes a real path. — port `Core/Entities/PlayerEntityLoadSave.cpp:570-674`
- ✅ note (post-load sequence): this matches step for step. It sets the time acceleration, calls `setSystemTo`, `removeAllEntitiesExceptPlayer`, `setGalaxyTo(…, YES)`, `setUpSpace` and `setAutoSaveNow(NO)`, docks at the main station, zeroes the flight variables, and sets personality. It reads `localMarket` (array) or initialises the market, then `scenario_key`, `completeSetUpAndSetTarget(NO)`, `populateNormalSpace`, GC, and the `docked_station_position`/`docked_station_role` station switch (only when `allowsSaving`). Then `station_markets`, `startUpComplete`, key suppression only when `finishedLaunching`, the `gui_screen` choice, and `missionScreenOpportunity`. — port `Core/Entities/PlayerEntityLoadSave.cpp:676-778`
- ✅ note (file naming): a native save is `<dir>/<name>.oolite-save`. `SaveFileName` emulates `stringByAppendingPathExtension:`, dropping trailing `/` or `\`. An autosave is `<dir>/<lastsaveName><DESC(autosave-commander-suffix)>.oolite-save`, a plain append that adds the suffix only when it is missing. Afterwards it restores `save_path` and `lastsaveName` exactly as upstream, keeping the autosave path when there was no previous `save_path`. Quicksave reuses `save_path`, then `playerFileToLoad`, and otherwise logs `quickSave.failed.noName` and raises `OoliteGameNotSavedException`. — port `Core/Entities/PlayerEntityLoadSave.cpp:102-108, 147-202, 823-833`
- ✅ note (write path): `OOWriteXMLPListToFile` replaces `-writeOOXMLToFile:atomically:errorDescription:` and still writes atomically. On success it does `clearPreviousMessage`, shows `game-saved` for 2 s, records `save_path`, `playerFileToLoad` and `playerFileDirectory`, and calls `setAutoSaveNow(NO)`. On failure it logs `save.failed` and raises `OoliteException` with the same text. Upstream's conversion-error text always ended `: (null)`, because its local `errorDesc` was never assigned. The port appends the real reason; that difference belongs to `OOXMLExtensions`. — upstream `Core/OOXMLExtensions.m:31-40` ↔ port `Core/OOXMLExtensions.cpp:30-37`
- ✅ note (listing order): entries are the `(..)` parent-folder row, readable `*.oolite-save` files whose extension matches case-insensitively, and non-hidden sub-folders. They are sorted by `saved_game_path` using the locale collation (`oo::str::localizedCompare`, ICU, as GNUstep's `-localizedCompare:` sorted). `stable_sort` against GNUstep's sort makes no difference because the paths are unique. The upstream quirk `highlightIdx = … + currentPage*NUMROWS` (not `page`) is kept. — upstream `Core/Entities/PlayerEntityLoadSave.m:814-981` ↔ port `Core/Entities/PlayerEntityLoadSave.cpp:928-1085`
- ✅ note: `autosavePlayer` catches only the game's own `oo::Exception` (what `@catch (id)` caught) and re-throws anything else, as the port's comment says. — port `Core/Entities/PlayerEntityLoadSave.cpp:168-175`
- ✅ note: out-of-range `cdrDetailArray` indices now return quietly where `-objectAtIndex:` raised. — port `Core/Entities/PlayerEntityLoadSave.cpp:405-406, 445, 488, 1102-1103`

## PlayerEntityScriptMethods

<a id="playerentityscriptmethods"></a>
Upstream `src/Core/Entities/PlayerEntityScriptMethods.m` ↔ `Core/Entities/PlayerEntityScriptMethods.cpp`

**Status:** done — 35 rows: 35 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(ScriptMethods) score]` (40) | `PlayerEntity::score` Core/Entities/PlayerEntityScriptMethods.cpp:84 | ✅ |
| `-[PlayerEntity(ScriptMethods) setScore:]` (45) | `PlayerEntity::setScore` Core/Entities/PlayerEntityScriptMethods.cpp:89 | ✅ |
| `-[PlayerEntity(ScriptMethods) creditBalance]` (50) | `PlayerEntity::creditBalance` Core/Entities/PlayerEntityScriptMethods.cpp:94 | ✅ |
| `-[PlayerEntity(ScriptMethods) setCreditBalance:]` (55) | `PlayerEntity::setCreditBalance` Core/Entities/PlayerEntityScriptMethods.cpp:99 | ✅ |
| `-[PlayerEntity(ScriptMethods) dockedStationName]` (60) | `PlayerEntity::dockedStationName` Core/Entities/PlayerEntityScriptMethods.cpp:104 | ✅ |
| `-[PlayerEntity(ScriptMethods) dockedStationDisplayName]` (65) | `PlayerEntity::dockedStationDisplayName` Core/Entities/PlayerEntityScriptMethods.cpp:109 | ✅ |
| `-[PlayerEntity(ScriptMethods) dockedAtMainStation]` (70) | `PlayerEntity::dockedAtMainStation` Core/Entities/PlayerEntityScriptMethods.cpp:114 | ✅ |
| `-[PlayerEntity(ScriptMethods) awardCommodityType:amount:]` (75) | `PlayerEntity::awardCommodityType` Core/Entities/PlayerEntityScriptMethods.cpp:119 | ✅ |
| `-[PlayerEntity(ScriptMethods) resetScannerZoom]` (148) | `PlayerEntity::resetScannerZoom` Core/Entities/PlayerEntityScriptMethods.cpp:202 | ✅ |
| `-[PlayerEntity(ScriptMethods) currentGalaxyID]` (153) | `PlayerEntity::currentGalaxyID` Core/Entities/PlayerEntityScriptMethods.cpp:207 | ✅ |
| `-[PlayerEntity(ScriptMethods) currentSystemID]` (158) | `PlayerEntity::currentSystemID` Core/Entities/PlayerEntityScriptMethods.cpp:212 | ✅ |
| `-[PlayerEntity(ScriptMethods) setMissionChoice:]` (165) | `PlayerEntity::setMissionChoice(newChoice)` Core/Entities/PlayerEntityScriptMethods.cpp:219 | ✅ |
| `-[PlayerEntity(ScriptMethods) setMissionChoice:withEvent:]` (170) | `PlayerEntity::setMissionChoice(newChoice, withEvent)` Core/Entities/PlayerEntityScriptMethods.cpp:224 | ✅ |
| `-[PlayerEntity(ScriptMethods) setMissionChoice:keyPress:]` (175) | `PlayerEntity::setMissionChoice(newChoice, keyPress)` Core/Entities/PlayerEntityScriptMethods.cpp:229 | ✅ |
| `-[PlayerEntity(ScriptMethods) setMissionChoice:keyPress:withEvent:]` (180) | `PlayerEntity::setMissionChoice(newChoice, keyPress, withEvent)` Core/Entities/PlayerEntityScriptMethods.cpp:234 | ✅ |
| `-[PlayerEntity(ScriptMethods) allowMissionInterrupt]` (202) | `PlayerEntity::allowMissionInterrupt` Core/Entities/PlayerEntityScriptMethods.cpp:253 | ✅ |
| `-[PlayerEntity(ScriptMethods) scriptTimer]` (207) | `PlayerEntity::scriptTimer` Core/Entities/PlayerEntityScriptMethods.cpp:258 | ✅ |
| `-[PlayerEntity(ScriptMethods) systemPseudoRandom100]` (215) | `PlayerEntity::systemPseudoRandom100` Core/Entities/PlayerEntityScriptMethods.cpp:266 | ✅ |
| `-[PlayerEntity(ScriptMethods) systemPseudoRandom256]` (221) | `PlayerEntity::systemPseudoRandom256` Core/Entities/PlayerEntityScriptMethods.cpp:272 | ✅ |
| `-[PlayerEntity(ScriptMethods) systemPseudoRandomFloat]` (227) | `PlayerEntity::systemPseudoRandomFloat` Core/Entities/PlayerEntityScriptMethods.cpp:278 | ✅ |
| `-[PlayerEntity(ScriptMethods) passengerContractMarker:]` (238) | `PlayerEntity::passengerContractMarker` (+ `MarkerFor`) Core/Entities/PlayerEntityScriptMethods.cpp:289 | ✅ |
| `-[PlayerEntity(ScriptMethods) parcelContractMarker:]` (248) | `PlayerEntity::parcelContractMarker` Core/Entities/PlayerEntityScriptMethods.cpp:294 | ✅ |
| `-[PlayerEntity(ScriptMethods) cargoContractMarker:]` (258) | `PlayerEntity::cargoContractMarker` Core/Entities/PlayerEntityScriptMethods.cpp:299 | ✅ |
| `-[PlayerEntity(ScriptMethods) defaultMarker:]` (268) | `PlayerEntity::defaultMarker` Core/Entities/PlayerEntityScriptMethods.cpp:304 | ✅ |
| `-[PlayerEntity(ScriptMethods) validatedMarker:]` (278) | `PlayerEntity::validatedMarker` Core/Entities/PlayerEntityScriptMethods.cpp:309 | ✅ |
| `-[PlayerEntity(ScriptMethods) creditsFormattedForSubstitution]` (301) | `PlayerEntity::creditsFormattedForSubstitution` Core/Entities/PlayerEntityScriptMethods.cpp:334 | ✅ |
| `-[PlayerEntity(ScriptMethods) creditsFormattedForLegacySubstitution]` (312) | `PlayerEntity::creditsFormattedForLegacySubstitution` Core/Entities/PlayerEntityScriptMethods.cpp:345 | ✅ |
| `-[PlayerEntity(ScriptMethods) commanderBountyAsString]` (322) | `PlayerEntity::commanderBountyAsString` Core/Entities/PlayerEntityScriptMethods.cpp:355 | ✅ |
| `-[PlayerEntity(ScriptMethods) commanderKillsAsString]` (328) | `PlayerEntity::commanderKillsAsString` Core/Entities/PlayerEntityScriptMethods.cpp:361 | ✅ |
| `-[PlayerEntity(ScriptMethods) keyBindingDescription2:]` (334) | `PlayerEntity::keyBindingDescription2` Core/Entities/PlayerEntityScriptMethods.cpp:367 | ✅ |
| `-[PlayerEntity(ScriptMethods) getKeyBindingDescription:]` (344) | `PlayerEntity::getKeyBindingDescription` (+ `BoolValueOf`/`IntegerValueOf`) Core/Entities/PlayerEntityScriptMethods.cpp:378 | ✅ |
| `-[PlayerEntity(ScriptMethods) keyCodeDescription:]` (369) | `PlayerEntity::keyCodeDescription` Core/Entities/PlayerEntityScriptMethods.cpp:403 | ✅ |
| `-[PlayerEntity(ScriptMethods) keyCodeDescriptionShort:]` (468) | `PlayerEntity::keyCodeDescriptionShort` Core/Entities/PlayerEntityScriptMethods.cpp:502 | ✅ |
| `OOGalacticCoordinatesFromInternal()` (568) | `OOGalacticCoordinatesFromInternal` Core/Entities/PlayerEntityScriptMethods.cpp:600 | ✅ |
| `OOInternalCoordinatesFromGalactic()` (573) | `OOInternalCoordinatesFromGalactic` Core/Entities/PlayerEntityScriptMethods.cpp:605 | ✅ |

**Differences:**

- ✅ note: the `keyCodeDescription`/`keyCodeDescriptionShort` switch tables are identical, case for case and `DESC` key for `DESC` key (diffed mechanically). For the default `%C`, the port truncates the code to one UTF-16 unit as upstream did. — port `Core/Entities/PlayerEntityScriptMethods.cpp:403-598`
- ✅ note: `validatedMarker` with a nil marker keeps the upstream nil-messaging result `{system = 0}`. The nil `name` ended `+dictionaryWithObjectsAndKeys:` early. The range check, defaults (`MISSION_DEST_LEGACY`, `redColor`, `MARKER_X`, scale 1.0 as a single real) and the four fixed markers' colours and shapes all match. — port `Core/Entities/PlayerEntityScriptMethods.cpp:289-331`
- ✅ note: `awardCommodityType` keeps the upstream infinite loop for tonne goods while special cargo is aboard (the outer `while (amount)` with nothing decremented). It keeps the `amount_per_container` 1000/1000000 split and the docked path's cap at `maxAvailableCargoSpace`. — port `Core/Entities/PlayerEntityScriptMethods.cpp:131-199`
- ✅ note: `systemPseudoRandom*` reseed the planet-description RNG on every call, as upstream did (its FIXME is kept). — port `Core/Entities/PlayerEntityScriptMethods.cpp:266-287`

## PlayerEntitySound

<a id="playerentitysound"></a>
Upstream `src/Core/Entities/PlayerEntitySound.m` ↔ `Core/Entities/PlayerEntitySound.cpp`

**Status:** done — 86 rows: 86 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(Sound) setUpSound]` (70) | `PlayerEntity::setUpSound` Core/Entities/PlayerEntitySound.cpp:123 | ✅ |
| `-[PlayerEntity(Sound) setUpWeaponSounds]` (101) | `PlayerEntity::setUpWeaponSounds` Core/Entities/PlayerEntitySound.cpp:155 | ✅ |
| `-[PlayerEntity(Sound) destroySound]` (155) | `PlayerEntity::destroySound` Core/Entities/PlayerEntitySound.cpp:196 | ✅ |
| `-[PlayerEntity(Sound) playInterfaceBeep:]` (178) | `PlayerEntity::playInterfaceBeep` Core/Entities/PlayerEntitySound.cpp:219 | ✅ |
| `-[PlayerEntity(Sound) isBeeping]` (188) | `PlayerEntity::isBeeping` Core/Entities/PlayerEntitySound.cpp:230 | ✅ |
| `-[PlayerEntity(Sound) boop]` (193) | `PlayerEntity::boop` Core/Entities/PlayerEntitySound.cpp:235 | ✅ |
| `-[PlayerEntity(Sound) playIdentOn]` (198) | `PlayerEntity::playIdentOn` Core/Entities/PlayerEntitySound.cpp:240 | ✅ |
| `-[PlayerEntity(Sound) playIdentOff]` (203) | `PlayerEntity::playIdentOff` Core/Entities/PlayerEntitySound.cpp:245 | ✅ |
| `-[PlayerEntity(Sound) playIdentLockedOn]` (208) | `PlayerEntity::playIdentLockedOn` Core/Entities/PlayerEntitySound.cpp:250 | ✅ |
| `-[PlayerEntity(Sound) playMissileArmed]` (213) | `PlayerEntity::playMissileArmed` Core/Entities/PlayerEntitySound.cpp:255 | ✅ |
| `-[PlayerEntity(Sound) playMineArmed]` (218) | `PlayerEntity::playMineArmed` Core/Entities/PlayerEntitySound.cpp:260 | ✅ |
| `-[PlayerEntity(Sound) playMissileSafe]` (223) | `PlayerEntity::playMissileSafe` Core/Entities/PlayerEntitySound.cpp:265 | ✅ |
| `-[PlayerEntity(Sound) playMissileLockedOn]` (228) | `PlayerEntity::playMissileLockedOn` Core/Entities/PlayerEntitySound.cpp:270 | ✅ |
| `-[PlayerEntity(Sound) playNextEquipmentSelected]` (233) | `PlayerEntity::playNextEquipmentSelected` Core/Entities/PlayerEntitySound.cpp:275 | ✅ |
| `-[PlayerEntity(Sound) playNextMissileSelected]` (238) | `PlayerEntity::playNextMissileSelected` Core/Entities/PlayerEntitySound.cpp:280 | ✅ |
| `-[PlayerEntity(Sound) playWeaponsOnline]` (243) | `PlayerEntity::playWeaponsOnline` Core/Entities/PlayerEntitySound.cpp:285 | ✅ |
| `-[PlayerEntity(Sound) playWeaponsOffline]` (248) | `PlayerEntity::playWeaponsOffline` Core/Entities/PlayerEntitySound.cpp:290 | ✅ |
| `-[PlayerEntity(Sound) playCargoJettisioned]` (253) | `PlayerEntity::playCargoJettisioned` Core/Entities/PlayerEntitySound.cpp:295 | ✅ |
| `-[PlayerEntity(Sound) playAutopilotOn]` (258) | `PlayerEntity::playAutopilotOn` Core/Entities/PlayerEntitySound.cpp:300 | ✅ |
| `-[PlayerEntity(Sound) playAutopilotOff]` (263) | `PlayerEntity::playAutopilotOff` Core/Entities/PlayerEntitySound.cpp:305 | ✅ |
| `-[PlayerEntity(Sound) playAutopilotOutOfRange]` (271) | `PlayerEntity::playAutopilotOutOfRange` Core/Entities/PlayerEntitySound.cpp:313 | ✅ |
| `-[PlayerEntity(Sound) playAutopilotCannotDockWithTarget]` (276) | `PlayerEntity::playAutopilotCannotDockWithTarget` Core/Entities/PlayerEntitySound.cpp:318 | ✅ |
| `-[PlayerEntity(Sound) playSaveOverwriteYes]` (281) | `PlayerEntity::playSaveOverwriteYes` Core/Entities/PlayerEntitySound.cpp:323 | ✅ |
| `-[PlayerEntity(Sound) playSaveOverwriteNo]` (286) | `PlayerEntity::playSaveOverwriteNo` Core/Entities/PlayerEntitySound.cpp:328 | ✅ |
| `-[PlayerEntity(Sound) playHoldFull]` (291) | `PlayerEntity::playHoldFull` Core/Entities/PlayerEntitySound.cpp:333 | ✅ |
| `-[PlayerEntity(Sound) playJumpMassLocked]` (296) | `PlayerEntity::playJumpMassLocked` Core/Entities/PlayerEntitySound.cpp:338 | ✅ |
| `-[PlayerEntity(Sound) playTargetLost]` (301) | `PlayerEntity::playTargetLost` Core/Entities/PlayerEntitySound.cpp:343 | ✅ |
| `-[PlayerEntity(Sound) playNoTargetInMemory]` (306) | `PlayerEntity::playNoTargetInMemory` Core/Entities/PlayerEntitySound.cpp:348 | ✅ |
| `-[PlayerEntity(Sound) playTargetSwitched]` (311) | `PlayerEntity::playTargetSwitched` Core/Entities/PlayerEntitySound.cpp:353 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceNoTarget]` (316) | `PlayerEntity::playHyperspaceNoTarget` Core/Entities/PlayerEntitySound.cpp:358 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceNoFuel]` (321) | `PlayerEntity::playHyperspaceNoFuel` Core/Entities/PlayerEntitySound.cpp:363 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceBlocked]` (326) | `PlayerEntity::playHyperspaceBlocked` Core/Entities/PlayerEntitySound.cpp:368 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceDistanceTooGreat]` (331) | `PlayerEntity::playHyperspaceDistanceTooGreat` Core/Entities/PlayerEntitySound.cpp:373 | ✅ |
| `-[PlayerEntity(Sound) playCloakingDeviceOn]` (336) | `PlayerEntity::playCloakingDeviceOn` Core/Entities/PlayerEntitySound.cpp:378 | ✅ |
| `-[PlayerEntity(Sound) playCloakingDeviceOff]` (341) | `PlayerEntity::playCloakingDeviceOff` Core/Entities/PlayerEntitySound.cpp:383 | ✅ |
| `-[PlayerEntity(Sound) playMenuNavigationUp]` (346) | `PlayerEntity::playMenuNavigationUp` Core/Entities/PlayerEntitySound.cpp:388 | ✅ |
| `-[PlayerEntity(Sound) playMenuNavigationDown]` (351) | `PlayerEntity::playMenuNavigationDown` Core/Entities/PlayerEntitySound.cpp:393 | ✅ |
| `-[PlayerEntity(Sound) playMenuNavigationNot]` (356) | `PlayerEntity::playMenuNavigationNot` Core/Entities/PlayerEntitySound.cpp:398 | ✅ |
| `-[PlayerEntity(Sound) playMenuPagePrevious]` (361) | `PlayerEntity::playMenuPagePrevious` Core/Entities/PlayerEntitySound.cpp:403 | ✅ |
| `-[PlayerEntity(Sound) playMenuPageNext]` (366) | `PlayerEntity::playMenuPageNext` Core/Entities/PlayerEntitySound.cpp:408 | ✅ |
| `-[PlayerEntity(Sound) playDismissedReportScreen]` (371) | `PlayerEntity::playDismissedReportScreen` Core/Entities/PlayerEntitySound.cpp:413 | ✅ |
| `-[PlayerEntity(Sound) playDismissedMissionScreen]` (376) | `PlayerEntity::playDismissedMissionScreen` Core/Entities/PlayerEntitySound.cpp:418 | ✅ |
| `-[PlayerEntity(Sound) playChangedOption]` (381) | `PlayerEntity::playChangedOption` Core/Entities/PlayerEntitySound.cpp:423 | ✅ |
| `-[PlayerEntity(Sound) updateFuelScoopSoundWithInterval:]` (386) | `PlayerEntity::updateFuelScoopSoundWithInterval` Core/Entities/PlayerEntitySound.cpp:428 | ✅ |
| `-[PlayerEntity(Sound) updateAfterburnerSound]` (407) | `PlayerEntity::updateAfterburnerSound` Core/Entities/PlayerEntitySound.cpp:450 | ✅ |
| `-[PlayerEntity(Sound) startAfterburnerSound]` (426) | `PlayerEntity::startAfterburnerSound` Core/Entities/PlayerEntitySound.cpp:469 | ✅ |
| `-[PlayerEntity(Sound) stopAfterburnerSound]` (434) | `PlayerEntity::stopAfterburnerSound` Core/Entities/PlayerEntitySound.cpp:477 | ✅ |
| `-[PlayerEntity(Sound) playCloakingDeviceInsufficientEnergy]` (439) | `PlayerEntity::playCloakingDeviceInsufficientEnergy` Core/Entities/PlayerEntitySound.cpp:482 | ✅ |
| `-[PlayerEntity(Sound) playBuyCommodity]` (444) | `PlayerEntity::playBuyCommodity` Core/Entities/PlayerEntitySound.cpp:487 | ✅ |
| `-[PlayerEntity(Sound) playBuyShip]` (449) | `PlayerEntity::playBuyShip` Core/Entities/PlayerEntitySound.cpp:493 | ✅ |
| `-[PlayerEntity(Sound) playSellCommodity]` (454) | `PlayerEntity::playSellCommodity` Core/Entities/PlayerEntitySound.cpp:499 | ✅ |
| `-[PlayerEntity(Sound) playCantBuyCommodity]` (459) | `PlayerEntity::playCantBuyCommodity` Core/Entities/PlayerEntitySound.cpp:505 | ✅ |
| `-[PlayerEntity(Sound) playCantSellCommodity]` (464) | `PlayerEntity::playCantSellCommodity` Core/Entities/PlayerEntitySound.cpp:511 | ✅ |
| `-[PlayerEntity(Sound) playCantBuyShip]` (469) | `PlayerEntity::playCantBuyShip` Core/Entities/PlayerEntitySound.cpp:517 | ✅ |
| `-[PlayerEntity(Sound) playStandardHyperspace]` (474) | `PlayerEntity::playStandardHyperspace` Core/Entities/PlayerEntitySound.cpp:523 | ✅ |
| `-[PlayerEntity(Sound) playGalacticHyperspace]` (479) | `PlayerEntity::playGalacticHyperspace` Core/Entities/PlayerEntitySound.cpp:528 | ✅ |
| `-[PlayerEntity(Sound) playHyperspaceAborted]` (484) | `PlayerEntity::playHyperspaceAborted` Core/Entities/PlayerEntitySound.cpp:533 | ✅ |
| `-[PlayerEntity(Sound) playHitByECMSound]` (489) | `PlayerEntity::playHitByECMSound` Core/Entities/PlayerEntitySound.cpp:538 | ✅ |
| `-[PlayerEntity(Sound) playFiredECMSound]` (495) | `PlayerEntity::playFiredECMSound` Core/Entities/PlayerEntitySound.cpp:544 | ✅ |
| `-[PlayerEntity(Sound) playLaunchFromStation]` (501) | `PlayerEntity::playLaunchFromStation` Core/Entities/PlayerEntitySound.cpp:550 | ✅ |
| `-[PlayerEntity(Sound) playDockWithStation]` (506) | `PlayerEntity::playDockWithStation` Core/Entities/PlayerEntitySound.cpp:555 | ✅ |
| `-[PlayerEntity(Sound) playExitWitchspace]` (511) | `PlayerEntity::playExitWitchspace` Core/Entities/PlayerEntitySound.cpp:560 | ✅ |
| `-[PlayerEntity(Sound) playHostileWarning]` (516) | `PlayerEntity::playHostileWarning` Core/Entities/PlayerEntitySound.cpp:565 | ✅ |
| `-[PlayerEntity(Sound) playAlertConditionRed]` (521) | `PlayerEntity::playAlertConditionRed` Core/Entities/PlayerEntitySound.cpp:571 | ✅ |
| `-[PlayerEntity(Sound) playIncomingMissile:]` (526) | `PlayerEntity::playIncomingMissile` Core/Entities/PlayerEntitySound.cpp:577 | ✅ |
| `-[PlayerEntity(Sound) playEnergyLow]` (531) | `PlayerEntity::playEnergyLow` Core/Entities/PlayerEntitySound.cpp:583 | ✅ |
| `-[PlayerEntity(Sound) playDockingDenied]` (536) | `PlayerEntity::playDockingDenied` Core/Entities/PlayerEntitySound.cpp:589 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpFailure]` (541) | `PlayerEntity::playWitchjumpFailure` Core/Entities/PlayerEntitySound.cpp:595 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpMisjump]` (546) | `PlayerEntity::playWitchjumpMisjump` Core/Entities/PlayerEntitySound.cpp:601 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpBlocked]` (551) | `PlayerEntity::playWitchjumpBlocked` Core/Entities/PlayerEntitySound.cpp:607 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpDistanceTooGreat]` (556) | `PlayerEntity::playWitchjumpDistanceTooGreat` Core/Entities/PlayerEntitySound.cpp:613 | ✅ |
| `-[PlayerEntity(Sound) playWitchjumpInsufficientFuel]` (561) | `PlayerEntity::playWitchjumpInsufficientFuel` Core/Entities/PlayerEntitySound.cpp:619 | ✅ |
| `-[PlayerEntity(Sound) playFuelLeak]` (566) | `PlayerEntity::playFuelLeak` Core/Entities/PlayerEntitySound.cpp:625 | ✅ |
| `-[PlayerEntity(Sound) playShieldHit:weaponIdentifier:]` (571) | `PlayerEntity::playShieldHit` Core/Entities/PlayerEntitySound.cpp:631 | ✅ |
| `-[PlayerEntity(Sound) playDirectHit:weaponIdentifier:]` (579) | `PlayerEntity::playDirectHit` Core/Entities/PlayerEntitySound.cpp:637 | ✅ |
| `-[PlayerEntity(Sound) playScrapeDamage:]` (587) | `PlayerEntity::playScrapeDamage` Core/Entities/PlayerEntitySound.cpp:643 | ✅ |
| `-[PlayerEntity(Sound) playLaserHit:offset:weaponIdentifier:]` (592) | `PlayerEntity::playLaserHit` Core/Entities/PlayerEntitySound.cpp:649 | ✅ |
| `-[PlayerEntity(Sound) playWeaponOverheated:]` (608) | `PlayerEntity::playWeaponOverheated` Core/Entities/PlayerEntitySound.cpp:660 | ✅ |
| `-[PlayerEntity(Sound) playMissileLaunched:weaponIdentifier:]` (613) | `PlayerEntity::playMissileLaunched` Core/Entities/PlayerEntitySound.cpp:666 | ✅ |
| `-[PlayerEntity(Sound) playMineLaunched:weaponIdentifier:]` (621) | `PlayerEntity::playMineLaunched` Core/Entities/PlayerEntitySound.cpp:672 | ✅ |
| `-[PlayerEntity(Sound) playEscapePodScooped]` (629) | `PlayerEntity::playEscapePodScooped` Core/Entities/PlayerEntitySound.cpp:678 | ✅ |
| `-[PlayerEntity(Sound) playAegisCloseToPlanet]` (634) | `PlayerEntity::playAegisCloseToPlanet` Core/Entities/PlayerEntitySound.cpp:684 | ✅ |
| `-[PlayerEntity(Sound) playAegisCloseToStation]` (639) | `PlayerEntity::playAegisCloseToStation` Core/Entities/PlayerEntitySound.cpp:690 | ✅ |
| `-[PlayerEntity(Sound) playGameOver]` (644) | `PlayerEntity::playGameOver` Core/Entities/PlayerEntitySound.cpp:696 | ✅ |
| `-[PlayerEntity(Sound) playLegacyScriptSound:]` (649) | `PlayerEntity::playLegacyScriptSound` Core/Entities/PlayerEntitySound.cpp:702 | ✅ |
| `OO_ASSIGN_SOUNDSTR_TO_SOUNDS` macro (119) *(added)* | `assignSound` lambda in `PlayerEntity::setUpWeaponSounds` Core/Entities/PlayerEntitySound.cpp:170 | ✅ |

**Differences:**

- ✅ note (events and keys): every `play…` method uses the same custom-sound key as upstream, including the upstream quirks. `playMenuPagePrevious` plays `[menu-next-page]` and `playMenuPageNext` plays `[menu-previous-page]`. The spelling `[cloaking-device-insufficent-energy]` is kept. Each method also goes to the same source or pool: interface beep, break-pattern, ECM, hyperspace, or the buy-sell, warning, weapon, damage or misc pool. Positions are unchanged (`kInterfaceBeepPosition` and the rest). — port `Core/Entities/PlayerEntitySound.cpp:103-110, 219-706`
- ✅ note (volume/priority): pool sizes are unchanged (4/6/3/4/2), as is the damage pool's 0.1 s minimum repeat. Warning priorities match: hostile 1, red alert 2, incoming missile 3, energy low 0.5, docking denied 1, witchdrive failure and misjump 1.5, blocked, too far and no fuel 1.3, fuel leak 0.5. So do the laser hit/miss settings (priority 1.0, expiry 0.05, overlap YES), overheat (overlap NO) and legacy script sound (priority 1.1). Each call reaches the `OOSoundSourcePool` overload of the same shape: `(key, float, Vector)`, `(key, bool, Vector)`, `(key, float)`, `(key, Vector)`. — port `Core/Entities/PlayerEntitySound.cpp:139-143, 565-706`; `Core/OOSoundSourcePool.h:65-72`
- ✅ note: in `updateAfterburnerSound`, the 1.25 s re-arm moves from `performSelector:afterDelay:` to `oo::ScheduleEntityCall`. That queue runs on wall-clock time (`steady_clock`) and holds the entity, matching the run-loop timer and its retain. — port `Core/Entities/PlayerEntitySound.cpp:450-467`; `Core/Entities/OOEntityCalledByName.cpp:1006-1014`; `Core/GameController.cpp:156-168`
- ✅ note: the weapon-sound maps are `std::map` rather than `NSDictionary`. They are only looked up, never iterated, so the ordering change has no effect. A missing identifier still falls back to the default key. — port `Core/Entities/PlayerEntitySound.cpp:93-119, 155-194`

## PlayerEntityStickMapper

<a id="playerentitystickmapper"></a>
Upstream `src/Core/Entities/PlayerEntityStickMapper.m` ↔ `Core/Entities/PlayerEntityStickMapper.cpp`

**Status:** done — 13 rows: 12 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[PlayerEntity(StickMapper) resetStickFunctions]` (48) | `PlayerEntity::resetStickFunctions` Core/Entities/PlayerEntityStickMapper.cpp:134 | ✅ |
| `-[PlayerEntity(StickMapper) setGuiToStickMapperScreen:]` (54) | `PlayerEntity::setGuiToStickMapperScreen(unsigned)` Core/Entities/PlayerEntityStickMapper.cpp:139 | ✅ |
| `-[PlayerEntity(StickMapper) setGuiToStickMapperScreen:resetCurrentRow:]` (59) | `PlayerEntity::setGuiToStickMapperScreen(unsigned, bool)` Core/Entities/PlayerEntityStickMapper.cpp:144 | ✅ |
| `-[PlayerEntity(StickMapper) stickMapperInputHandler:]` (124) | `PlayerEntity::stickMapperInputHandler` Core/Entities/PlayerEntityStickMapper.cpp:205 | ✅ |
| `-[PlayerEntity(StickMapper) updateFunction:]` (201) | `PlayerEntity::updateFunction` Core/Entities/PlayerEntityStickMapper.cpp:277 | ❌ |
| `-[PlayerEntity(StickMapper) checkCustomEquipButtons:ignore:]` (283) | `PlayerEntity::checkCustomEquipButtons` Core/Entities/PlayerEntityStickMapper.cpp:357 | ✅ |
| `-[PlayerEntity(StickMapper) removeFunction:]` (307) | `PlayerEntity::removeFunction` Core/Entities/PlayerEntityStickMapper.cpp:381 | ✅ |
| `-[PlayerEntity(StickMapper) displayFunctionList:]` (358) | `PlayerEntity::displayFunctionList` Core/Entities/PlayerEntityStickMapper.cpp:427 | ✅ |
| `-[PlayerEntity(StickMapper) describeStickDict:]` (474) | `PlayerEntity::describeStickDict` Core/Entities/PlayerEntityStickMapper.cpp:539 | ✅ |
| `-[PlayerEntity(StickMapper) hwToString:]` (499) | `PlayerEntity::hwToString` Core/Entities/PlayerEntityStickMapper.cpp:563 | ✅ |
| `-[PlayerEntity(StickMapper) stickFunctionList]` (517) | `PlayerEntity::stickFunctionList` Core/Entities/PlayerEntityStickMapper.cpp:581 | ✅ |
| `-[PlayerEntity(StickMapper) makeStickGuiDict:]` (825) | `PlayerEntity::makeStickGuiDict` Core/Entities/PlayerEntityStickMapper.cpp:724 | ✅ |
| `-[PlayerEntity(StickMapper) makeStickGuiDictHeader:]` (846) | `PlayerEntity::makeStickGuiDictHeader` Core/Entities/PlayerEntityStickMapper.cpp:739 | ✅ |

Checked and equal:
- **Function list:** `stickFunctionList` has the same 233 tokens (`stickmapper-*` keys, `HW_*`, `AXIS_*`, `BUTTON_*`, the `10000`/`20000` custom-equipment offsets) in the same order (mechanical diff). That includes upstream's reuse of `BUTTON_PRIMEEQUIPMENT` for "prime-prev-equipment".
- **Truncation:** stick names are cut by 5 characters plus `"..."` while wider than 18 em (11 em for the additional name). `makeStickGuiDict` cuts at 28 UTF-16 units (not 48) above 50.
- **Axis/button unsetting:** the cross-unsetting in `updateFunction` (thrust, FOV, view X/Y) matches.
- **Custom equipment:** the `10000`/`20000` decoding into `CUSTOMEQUIP_BUTTONACTIVATE`/`_BUTTONMODE` matches.
- **Display and paging:** the hat description (`(n - MAX_REAL_BUTTONS)/4 + 1`, `dir[n & 3]`), the paging maths and the `GUI_ROW_STICKPROFILE` selectable range match. Upstream's in-place edits through `mutableCopy` + `replaceObjectAtIndex:` become direct edits of the vector entry, with the same result.
- **Callback:** the joystick callback is a lambda instead of `@selector(updateFunction:)` (ADR-0055 item 5, cited at :277).

**Differences:**

- ❌ **low** — **Error-log text in `updateFunction`.** The "called when not on stick mapper screen" error logs `__PRETTY_FUNCTION__` through `{}`. Upstream printed `-[PlayerEntity(StickMapper) updateFunction:]`; the port prints the C++ signature (`void PlayerEntity::updateFunction(const oo::PList&)`). The class `joystick.configure.error` is unchanged — upstream `Core/Entities/PlayerEntityStickMapper.m:208` ↔ port `Core/Entities/PlayerEntityStickMapper.cpp:284`
- ✅ **low** (note) — **Out-of-range indexes.** `stickFunctions`/`customEquipActivation` indexes past the end (upstream `objectAtIndex:` raises) give a null entry in the port. That would need `Enter` with `selFunctionIdx == -1` on a selectable non-`Index:` row; none exists besides the profile row, which is handled first — upstream `Core/Entities/PlayerEntityStickMapper.m:171, 213` ↔ port `Core/Entities/PlayerEntityStickMapper.cpp:249, 289`

## PlayerEntityStickProfile

<a id="playerentitystickprofile"></a>
Upstream `src/Core/Entities/PlayerEntityStickProfile.m` ↔ `Core/Entities/PlayerEntityStickProfile.cpp`

**Status:** done — 27 rows: 26 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `GUI_ROW_STICKPROFILE_*` defines + `static BOOL stickProfileArrow_pressed` (36–43) | same, Core/Entities/PlayerEntityStickProfile.cpp:38–45 | ✅ |
| `-[PlayerEntity(StickProfile) setGuiToStickProfileScreen:]` (69) | `PlayerEntity::setGuiToStickProfileScreen` Core/Entities/PlayerEntityStickProfile.cpp:69 | ✅ |
| `-[PlayerEntity(StickProfile) stickProfileInputHandler:]` (76) | `PlayerEntity::stickProfileInputHandler` Core/Entities/PlayerEntityStickProfile.cpp:77 | ✅ |
| `-[PlayerEntity(StickProfile) stickProfileGraphAxisProfile:screenAt:screenSize:]` (180) | `PlayerEntity::stickProfileGraphAxisProfile` Core/Entities/PlayerEntityStickProfile.cpp:194 | ✅ |
| `-[StickProfileScreen init]` (191) | `StickProfileScreen::StickProfileScreen` Core/Entities/PlayerEntityStickProfile.cpp:207 | ✅ |
| `-[StickProfileScreen dealloc]` (207) | implicit destructor (`oo::Ref` members release `profiles[][]`) Core/Entities/PlayerEntityStickProfile.h:78 | ➖ |
| `-[StickProfileScreen startGui:]` (217) | `StickProfileScreen::startGui` Core/Entities/PlayerEntityStickProfile.cpp:214 | ✅ |
| `-[StickProfileScreen mouseDown:]` (228) | `StickProfileScreen::mouseDown` Core/Entities/PlayerEntityStickProfile.cpp:225 | ✅ |
| `-[StickProfileScreen mouseUp]` (253) | `StickProfileScreen::mouseUp` Core/Entities/PlayerEntityStickProfile.cpp:250 | ✅ |
| `-[StickProfileScreen deleteSelected]` (262) | `StickProfileScreen::deleteSelected` Core/Entities/PlayerEntityStickProfile.cpp:259 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) nextAxis]` (280) | `StickProfileScreen::nextAxis` Core/Entities/PlayerEntityStickProfile.cpp:272 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) previousAxis]` (290) | `StickProfileScreen::previousAxis` Core/Entities/PlayerEntityStickProfile.cpp:282 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) currentAxis]` (300) | `StickProfileScreen::currentAxis` Core/Entities/PlayerEntityStickProfile.cpp:292 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) increaseDeadzone]` (315) | `StickProfileScreen::increaseDeadzone` Core/Entities/PlayerEntityStickProfile.cpp:307 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) decreaseDeadzone]` (325) | `StickProfileScreen::decreaseDeadzone` Core/Entities/PlayerEntityStickProfile.cpp:317 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) nextProfileType]` (335) | `StickProfileScreen::nextProfileType` Core/Entities/PlayerEntityStickProfile.cpp:327 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) previousProfileType]` (355) | `StickProfileScreen::previousProfileType` Core/Entities/PlayerEntityStickProfile.cpp:346 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) currentProfileIsSpline]` (375) | `StickProfileScreen::currentProfileIsSpline` Core/Entities/PlayerEntityStickProfile.cpp:365 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) IncreasePower]` (383) | `StickProfileScreen::IncreasePower` Core/Entities/PlayerEntityStickProfile.cpp:373 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) DecreasePower]` (397) | `StickProfileScreen::DecreasePower` Core/Entities/PlayerEntityStickProfile.cpp:386 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) IncreaseParam]` (411) | `StickProfileScreen::IncreaseParam` Core/Entities/PlayerEntityStickProfile.cpp:399 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) DecreaseParam]` (425) | `StickProfileScreen::DecreaseParam` Core/Entities/PlayerEntityStickProfile.cpp:412 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) graphProfile:at:size:]` (439) | `StickProfileScreen::graphProfile` Core/Entities/PlayerEntityStickProfile.cpp:425 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) startEdit]` (487) | `StickProfileScreen::startEdit` Core/Entities/PlayerEntityStickProfile.cpp:473 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) saveSettings]` (504) | `StickProfileScreen::saveSettings` Core/Entities/PlayerEntityStickProfile.cpp:489 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) showScreen]` (510) | `StickProfileScreen::showScreen` Core/Entities/PlayerEntityStickProfile.cpp:495 | ✅ |
| `-[StickProfileScreen(StickProfileInternal) profileType]` (584) | `StickProfileScreen::profileType` Core/Entities/PlayerEntityStickProfile.cpp:555 | ✅ |

Checked and equal:
- **Profile edits:** the deadzone step is `STICK_MAX_DEADZONE / 20`, the power step `STICKPROFILE_MAX_POWER / 20`, the parameter step ±0.05. The shared constants and the `GUI_ROW_*` defines are identical in the port headers.
- **Profile type switch:** next/previous profile type keep the outgoing profile in `profiles[axis][0|1]` (retained via `oo::Ref`'s retaining constructor; `OOJoystickManager::setProfile` also retains) and copy the deadzone across. `isKindOfClass:` becomes `dynamic_cast`.
- **Curve drawing:** `graphProfile` uses the same 220×220 box at (x−110, y−100), the same 10-px inset, `rawValue(i/(w−20))` per pixel column, the 4×4 ovals with 20 segments, and the same colours and string positions.
- **Spline editing by mouse:** `(pos.x − origin.x − 10)/(w − 20)` and `(−pos.y − origin.y − 10)/(h − 20)`, the [0,1] hit test, and the add/move/delete with `saveStickSettings` match.
- **`showScreen` text:** tab stops 50/140. The bar strings are `|`×n + `.`×(20−n), with n = `(int)(20·v/max + 0.5)` for deadzone and power, n = `(int)(20·param)` for sensitivity, clamped to 0..20. The formats `"%@%@ (%0.4f)"`, `"%@%@ (%.1f) "`, `"%@%@ (%0.2f) "` are unchanged, and the spline layout sets `GUI_KEY_SKIP` rows in magenta. The selectable range is `(1, 20)`.
- **Initial state:** `selected/dragged/double_click_control_point` start at 0 in both (ObjC zero-fill ↔ member initialisers) until `startEdit` sets them to -1.

**Differences:**

- ➖ **low** — `-dealloc` (releasing `profiles[3][2]`) is replaced by `oo::Ref` member destruction; same effect — upstream `Core/Entities/PlayerEntityStickProfile.m:207-215` ↔ port `Core/Entities/PlayerEntityStickProfile.h:78`
- ✅ **low** (note) — **Nil checks.** The port guards `stickProfileScreen != nullptr` at every call (matching nil messaging) and reads `deadzone` as 0.0 for a null profile in `showScreen` (matching `[nil deadzone]`). `!currentProfileIsSpline` on a nil screen is true in both, so the power/param rows still react — upstream `Core/Entities/PlayerEntityStickProfile.m:146, 526` ↔ port `Core/Entities/PlayerEntityStickProfile.cpp:156, 509`

## ProxyPlayerEntity

<a id="proxyplayerentity"></a>
Upstream `src/Core/Entities/ProxyPlayerEntity.m` ↔ `Core/Entities/ProxyPlayerEntity.cpp`

**Status:** done — 29 rows: 27 ✅ 0 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[ProxyPlayerEntity initWithKey:definition:]` (30) | `ProxyPlayerEntity::newProxyObject` + `initProxyDefaults` Core/Entities/ProxyPlayerEntity.cpp:28,41 | ✅ |
| `-[ProxyPlayerEntity copyValuesFromPlayer:]` (44) | `ProxyPlayerEntity::copyValuesFromPlayer` Core/Entities/ProxyPlayerEntity.cpp:50 | ✅ |
| `-[ProxyPlayerEntity isPlayerLikeShip]` (63) | `ProxyPlayerEntity::isPlayerLikeShip` Core/Entities/ProxyPlayerEntity.cpp:69 | ✅ |
| `-[ProxyPlayerEntity fuelLeakRate]` (68) | `ProxyPlayerEntity::fuelLeakRate` Core/Entities/ProxyPlayerEntity.cpp:74 | ✅ |
| `-[ProxyPlayerEntity setFuelLeakRate:]` (73) | `ProxyPlayerEntity::setFuelLeakRate` Core/Entities/ProxyPlayerEntity.cpp:79 | ✅ |
| `-[ProxyPlayerEntity massLocked]` (78) | `ProxyPlayerEntity::massLocked` Core/Entities/ProxyPlayerEntity.cpp:84 | ✅ |
| `-[ProxyPlayerEntity setMassLocked:]` (83) | `ProxyPlayerEntity::setMassLocked` Core/Entities/ProxyPlayerEntity.cpp:89 | ✅ |
| `-[ProxyPlayerEntity atHyperspeed]` (88) | `ProxyPlayerEntity::atHyperspeed` Core/Entities/ProxyPlayerEntity.cpp:94 | ✅ |
| `-[ProxyPlayerEntity setAtHyperspeed:]` (93) | `ProxyPlayerEntity::setAtHyperspeed` Core/Entities/ProxyPlayerEntity.cpp:99 | ✅ |
| `-[ProxyPlayerEntity dialForwardShield]` (98) | `ProxyPlayerEntity::dialForwardShield` Core/Entities/ProxyPlayerEntity.cpp:104 | ✅ |
| `-[ProxyPlayerEntity setDialForwardShield:]` (103) | `ProxyPlayerEntity::setDialForwardShield` Core/Entities/ProxyPlayerEntity.cpp:109 | ✅ |
| `-[ProxyPlayerEntity dialAftShield]` (108) | `ProxyPlayerEntity::dialAftShield` Core/Entities/ProxyPlayerEntity.cpp:114 | ✅ |
| `-[ProxyPlayerEntity setDialAftShield:]` (113) | `ProxyPlayerEntity::setDialAftShield` Core/Entities/ProxyPlayerEntity.cpp:119 | ✅ |
| `-[ProxyPlayerEntity dialMissileStatus]` (118) | `ProxyPlayerEntity::dialMissileStatus` Core/Entities/ProxyPlayerEntity.cpp:124 | ✅ |
| `-[ProxyPlayerEntity setDialMissileStatus:]` (123) | `ProxyPlayerEntity::setDialMissileStatus` Core/Entities/ProxyPlayerEntity.cpp:129 | ✅ |
| `-[ProxyPlayerEntity dialFuelScoopStatus]` (128) | `ProxyPlayerEntity::dialFuelScoopStatus` Core/Entities/ProxyPlayerEntity.cpp:134 | ✅ |
| `-[ProxyPlayerEntity setDialFuelScoopStatus:]` (133) | `ProxyPlayerEntity::setDialFuelScoopStatus` Core/Entities/ProxyPlayerEntity.cpp:139 | ✅ |
| `-[ProxyPlayerEntity compassMode]` (138) | `ProxyPlayerEntity::compassMode` Core/Entities/ProxyPlayerEntity.cpp:144 | ✅ |
| `-[ProxyPlayerEntity setCompassMode:]` (143) | `ProxyPlayerEntity::setCompassMode` Core/Entities/ProxyPlayerEntity.cpp:149 | ✅ |
| `-[ProxyPlayerEntity dialIdentEngaged]` (148) | `ProxyPlayerEntity::dialIdentEngaged` Core/Entities/ProxyPlayerEntity.cpp:154 | ✅ |
| `-[ProxyPlayerEntity setDialIdentEngaged:]` (153) | `ProxyPlayerEntity::setDialIdentEngaged` Core/Entities/ProxyPlayerEntity.cpp:159 | ✅ |
| `-[ProxyPlayerEntity alertCondition]` (158) | `ProxyPlayerEntity::alertCondition` Core/Entities/ProxyPlayerEntity.cpp:164 | ✅ |
| `-[ProxyPlayerEntity setAlertCondition:]` (163) | `ProxyPlayerEntity::setAlertCondition` Core/Entities/ProxyPlayerEntity.cpp:169 | ✅ |
| `-[ProxyPlayerEntity trumbleCount]` (168) | `ProxyPlayerEntity::trumbleCount` Core/Entities/ProxyPlayerEntity.cpp:174 | ✅ |
| `-[ProxyPlayerEntity setTrumbleCount:]` (173) | `ProxyPlayerEntity::setTrumbleCount` Core/Entities/ProxyPlayerEntity.cpp:179 | ✅ |
| `-[ProxyPlayerEntity setTradeInFactor:]` (178) | `ProxyPlayerEntity::setTradeInFactor` Core/Entities/ProxyPlayerEntity.cpp:184 | ✅ |
| `-[ProxyPlayerEntity tradeInFactor]` (183) | `ProxyPlayerEntity::tradeInFactor` Core/Entities/ProxyPlayerEntity.cpp:189 | ✅ |
| `-[Entity(ProxyPlayer) isPlayerLikeShip]` (194) | — (replaced by type test in `OOUniformBindingPermitted`, Core/Entities/ShipEntity.cpp:13753) | ➖ |
| `-[PlayerEntity(ProxyPlayer) isPlayerLikeShip]` (203) | — (replaced by type test in `OOUniformBindingPermitted`, Core/Entities/ShipEntity.cpp:13753) | ➖ |

**Differences:**

- ➖ `-isPlayerLikeShip` had a single caller, `OOUniformBindingPermitted`. It now tests `dynamic_cast<PlayerEntity*> || dynamic_cast<ProxyPlayerEntity*>`. That gives the same answer: YES for exactly those two classes, NO for every other entity. `ProxyPlayerEntity::isPlayerLikeShip` (non-virtual) is left with no callers. Bead oo-9ht.177/183 per the comment. — upstream `Core/Entities/ShipEntity.m:13020` ↔ port `Core/Entities/ShipEntity.cpp:13751-13756`
- ✅ note (copied fields): `copyValuesFromPlayer` copies all 12 fields in upstream order, through the same player getters: fuelLeakRate, massLocked, atHyperspeed, dialForwardShield, dialAftShield, dialMissileStatus, dialFuelScoopStatus, compassMode, dialIdentEngaged, alertCondition (the computing `getAlertCondition`, as upstream's `-alertCondition` computed), trumbleCount and tradeInFactor. The extra `player != nullptr` ternaries are dead after the early return. — port `Core/Entities/ProxyPlayerEntity.cpp:50-67`
- ✅ note: the defaults are unchanged. Both shields are 1.0, scoop status follows `hasScoop`, compass follows `EQ_ADVANCED_COMPASS`, and trade-in is 95. They are applied after the ship set-up, as upstream's `-initWithKey:definition:` did after `super`. The ivar defaults are zero and the setter clamps (`fmax` on the leak rate, `!!` on the bools) are kept. — port `Core/Entities/ProxyPlayerEntity.cpp:28-48, 79-102`; `Core/Entities/ProxyPlayerEntity.h:107-119`

