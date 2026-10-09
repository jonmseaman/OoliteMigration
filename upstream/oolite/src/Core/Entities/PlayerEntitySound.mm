/*

PlayerEntitySound.m

Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/

#import "PlayerEntitySound.h"
#import "OOSound.h"
#import "ResourceManager.h"
#import "Universe.h"
#import "OOSoundSourcePool.h"
#import "OOMaths.h"
#import "OOEquipmentType.h"
#import "GameController.h"

#include "oofnd/String.hpp"


// Sizes of sound source pools
enum
{
	kBuySellSourcePoolSize	= 4,
	kWarningPoolSize		= 6,
	kWeaponPoolSize			= 3,
	kDamagePoolSize			= 4,
	kMiscPoolSize			= 2
};


static OOSoundSourcePool	*sWarningSoundPool;
static OOSoundSourcePool	*sWeaponSoundPool;
static OOSoundSourcePool	*sDamageSoundPool;
static OOSoundSourcePool	*sMiscSoundPool;
static OOSoundSource		*sHyperspaceSoundSource;
static OOSoundSource		*sInterfaceBeepSource;
static OOSoundSource		*sEcmSource;
static OOSoundSource		*sBreakPatternSource;
static OOSoundSourcePool	*sBuySellSourcePool;
static OOSoundSource		*sAfterburnerSources[2];

// The pools are C++ (bead oo-9ht.89 deleted their Objective-C facade); each static holds one
// retain, as the facades did, given up by ReleasePool where the facades were DESTROYed. A message
// to a nil pool did nothing, so each play checks for none.
namespace {
void ReleasePool(OOSoundSourcePool *&pool)
{
	if (pool != nullptr)  pool->release();
	pool = nullptr;
}
}	// namespace

// Weapon identifier -> sound key (empty: no sound key, as @"" was).
using OOWeaponSoundMap = std::map<std::string, std::string, std::less<>>;
namespace {
OOWeaponSoundMap		weaponShotMiss;
OOWeaponSoundMap		weaponShotHit;
OOWeaponSoundMap		weaponShieldHit;
OOWeaponSoundMap		weaponUnshieldedHit;
OOWeaponSoundMap		weaponLaunched;
}	// namespace

static const Vector	 kInterfaceBeepPosition		= { 0.0f, -0.2f, 0.5f };
static const Vector	 kInterfaceWarningPosition	= { 0.0f, -0.2f, 0.4f };
static const Vector	 kBreakPatternPosition		= { 0.0f, 0.0f, 1.0f };
static const Vector	 kEcmPosition				= { 0.2f, 0.6f, -0.1f };
static const Vector	 kWitchspacePosition		= { 0.0f, -0.3f, -0.3f };
// maybe these should actually track engine positions
static const Vector	 kAfterburner1Position		= { -0.1f, 0.0f, -1.0f };
static const Vector	 kAfterburner2Position		= { 0.1f, 0.0f, -1.0f };

namespace {

// The sound key for a weapon, or fallback when the weapon has none (the dictionary lookup gave nil).
std::string WeaponSoundKey(const OOWeaponSoundMap &sounds, const std::string &weaponIdentifier, const std::string &fallback)
{
	const auto found = sounds.find(weaponIdentifier);
	return found != sounds.end() ? found->second : fallback;
}

}	// namespace


void cxx::PlayerEntity::setUpSound()
{
	destroySound();
	
	sInterfaceBeepSource = [[::OOSoundSource alloc] init];
	[sInterfaceBeepSource setPosition:kInterfaceBeepPosition];

	sBreakPatternSource = [[::OOSoundSource alloc] init];
	[sBreakPatternSource setPosition:kBreakPatternPosition];

	sEcmSource = [[::OOSoundSource alloc] init];
	[sEcmSource setPosition:kEcmPosition];

	sHyperspaceSoundSource = [[::OOSoundSource alloc] init];
	[sHyperspaceSoundSource setPosition:kWitchspacePosition];
	
	sBuySellSourcePool = OOSoundSourcePool::poolWithCount(kBuySellSourcePoolSize, 0.0).leakRef();
	sWarningSoundPool = OOSoundSourcePool::poolWithCount(kWarningPoolSize, 0.0).leakRef();
	sWeaponSoundPool = OOSoundSourcePool::poolWithCount(kWeaponPoolSize, 0.0).leakRef();
	sDamageSoundPool = OOSoundSourcePool::poolWithCount(kDamagePoolSize, 0.1).leakRef();	// Repeat time limit is to avoid playing a scrape sound every frame on glancing scrapes. This does limit the number of laser hits that can be played in a furrball, though; maybe lasers and scrapes should use different pools.
	sMiscSoundPool = OOSoundSourcePool::poolWithCount(kMiscPoolSize, 0.0).leakRef();
	
	// Two sources with the same sound are used to simulate looping.
	::OOSound *afterburnerSound = [::ResourceManager cxx_ooSoundNamed:"afterburner1.ogg" inFolder:"Sounds"];
	sAfterburnerSources[0] = [[::OOSoundSource alloc] initWithSound:afterburnerSound];
	[sAfterburnerSources[0] setPosition:kAfterburner1Position];
	sAfterburnerSources[1] = [[::OOSoundSource alloc] initWithSound:afterburnerSound];
	[sAfterburnerSources[1] setPosition:kAfterburner2Position];
}


// sets up the sound key dictionaries for all the available weapons/missiles/mines defined.


void cxx::PlayerEntity::setUpWeaponSounds()
{
	OOWeaponSoundMap	shotMissSounds;
	OOWeaponSoundMap	shotHitSounds;
	OOWeaponSoundMap	shieldHitSounds;
	OOWeaponSoundMap	unshieldedHitSounds;
	OOWeaponSoundMap	weaponLaunchedSounds;

	// special case: turrets aren't defined with a "EQ_WEAPON" prefix, and plasma shots don't have a matching equipment item,
	// so add a unique entry here. this could be overridden if an OXP creates an equipment item with this key.
	// plasma shots don't make a sound when fired, so we only need to provide for the hit player sound keys.
	shieldHitSounds["EQ_WEAPON_PLASMA_SHOT"] = "[player-hit-by-weapon]";
	unshieldedHitSounds["EQ_WEAPON_PLASMA_SHOT"] = "[player-direct-hit]";
	// grab a local copy of the sound identifiers for weapons to make the process of looking up a sound ref as fast as possible
	// a missing sound identifier is stored as an empty key
	auto assignSound = [](OOWeaponSoundMap &sounds, ::OOEquipmentType *eqType, std::string soundName) {
		sounds[[eqType cxx_identifier].value_or("")] = std::move(soundName);
	};

	for (const oo::ObjCRef<::OOEquipmentType *> &eqTypeRef : [::OOEquipmentType cxx_allEquipmentTypes])
	{
		::OOEquipmentType *eqType = eqTypeRef.get();
		if (oo::str::hasPrefix([eqType cxx_identifier].value_or(""), "EQ_WEAPON"))
		{
			assignSound(shotMissSounds, eqType, [eqType cxx_fxShotMissName].value_or(""));
			assignSound(shotHitSounds, eqType, [eqType cxx_fxShotHitName].value_or(""));
			assignSound(shieldHitSounds, eqType, [eqType cxx_fxShieldHitName].value_or(""));
			assignSound(unshieldedHitSounds, eqType, [eqType cxx_fxUnshieldedHitName].value_or(""));
		}
		if ([eqType isMissileOrMine])
		{
			assignSound(weaponLaunchedSounds, eqType, [eqType cxx_fxWeaponLaunchedName].value_or(""));
			assignSound(shieldHitSounds, eqType, [eqType cxx_fxShieldHitName].value_or(""));
			assignSound(unshieldedHitSounds, eqType, [eqType cxx_fxUnshieldedHitName].value_or(""));
		}
	}

	weaponShotMiss = std::move(shotMissSounds);
	weaponShotHit = std::move(shotHitSounds);
	weaponShieldHit = std::move(shieldHitSounds);
	weaponUnshieldedHit = std::move(unshieldedHitSounds);
	weaponLaunched = std::move(weaponLaunchedSounds);
}


void cxx::PlayerEntity::destroySound()
{
	DESTROY(sInterfaceBeepSource);
	DESTROY(sBreakPatternSource);
	DESTROY(sEcmSource);
	DESTROY(sHyperspaceSoundSource);
	
	DESTROY(sAfterburnerSources[0]);
	DESTROY(sAfterburnerSources[1]);

	ReleasePool(sBuySellSourcePool);
	ReleasePool(sWarningSoundPool);
	ReleasePool(sWeaponSoundPool);
	ReleasePool(sDamageSoundPool);
	ReleasePool(sMiscSoundPool);

	weaponShotMiss.clear();
	weaponShotHit.clear();
	weaponShieldHit.clear();
	weaponUnshieldedHit.clear();
	weaponLaunched.clear();
}


void cxx::PlayerEntity::playInterfaceBeep(const std::string & beepKey)
{
#if OOLITE_WINDOWS
	if (status() == STATUS_START_GAME) { return; }
#endif
	[sInterfaceBeepSource playOOSound:[::OOSound cxx_soundWithCustomSoundKey:beepKey]];
}


bool cxx::PlayerEntity::isBeeping()
{
	return [sInterfaceBeepSource isPlaying];
}


void cxx::PlayerEntity::boop()
{
	playInterfaceBeep("[general-boop]");
}


void cxx::PlayerEntity::playIdentOn()
{
	playInterfaceBeep("[ident-on]");
}


void cxx::PlayerEntity::playIdentOff()
{
	playInterfaceBeep("[ident-off]");
}


void cxx::PlayerEntity::playIdentLockedOn()
{
	playInterfaceBeep("[ident-locked-on]");
}


void cxx::PlayerEntity::playMissileArmed()
{
	playInterfaceBeep("[missile-armed]");
}


void cxx::PlayerEntity::playMineArmed()
{
	playInterfaceBeep("[mine-armed]");
}


void cxx::PlayerEntity::playMissileSafe()
{
	playInterfaceBeep("[missile-safe]");
}


void cxx::PlayerEntity::playMissileLockedOn()
{
	playInterfaceBeep("[missile-locked-on]");
}


void cxx::PlayerEntity::playNextEquipmentSelected()
{
	playInterfaceBeep("[next-equipment-selected]");
}


void cxx::PlayerEntity::playNextMissileSelected()
{
	playInterfaceBeep("[next-missile-selected]");
}


void cxx::PlayerEntity::playWeaponsOnline()
{
	playInterfaceBeep("[weapons-online]");
}


void cxx::PlayerEntity::playWeaponsOffline()
{
	playInterfaceBeep("[weapons-offline]");
}


void cxx::PlayerEntity::playCargoJettisioned()
{
	playInterfaceBeep("[cargo-jettisoned]");
}


void cxx::PlayerEntity::playAutopilotOn()
{
	playInterfaceBeep("[autopilot-on]");
}


void cxx::PlayerEntity::playAutopilotOff()
{
	// only if still alive
	if (energy > 0.0)
	{
		playInterfaceBeep("[autopilot-off]");
	}
}


void cxx::PlayerEntity::playAutopilotOutOfRange()
{
	playInterfaceBeep("[autopilot-out-of-range]");
}


void cxx::PlayerEntity::playAutopilotCannotDockWithTarget()
{
	playInterfaceBeep("[autopilot-cannot-dock-with-target]");
}


void cxx::PlayerEntity::playSaveOverwriteYes()
{
	playInterfaceBeep("[save-overwrite-yes]");
}


void cxx::PlayerEntity::playSaveOverwriteNo()
{
	playInterfaceBeep("[save-overwrite-no]");
}


void cxx::PlayerEntity::playHoldFull()
{
	playInterfaceBeep("[hold-full]");
}


void cxx::PlayerEntity::playJumpMassLocked()
{
	playInterfaceBeep("[jump-mass-locked]");
}


void cxx::PlayerEntity::playTargetLost()
{
	playInterfaceBeep("[target-lost]");
}


void cxx::PlayerEntity::playNoTargetInMemory()
{
	playInterfaceBeep("[no-target-in-memory]");
}


void cxx::PlayerEntity::playTargetSwitched()
{
	playInterfaceBeep("[target-switched]");
}


void cxx::PlayerEntity::playHyperspaceNoTarget()
{
	playInterfaceBeep("[witch-no-target]");
}


void cxx::PlayerEntity::playHyperspaceNoFuel()
{
	playInterfaceBeep("[witch-no-fuel]");
}


void cxx::PlayerEntity::playHyperspaceBlocked()
{
	playInterfaceBeep("[hyperspace-blocked]");
}


void cxx::PlayerEntity::playHyperspaceDistanceTooGreat()
{
	playInterfaceBeep("[witch-too-far]");
}


void cxx::PlayerEntity::playCloakingDeviceOn()
{
	playInterfaceBeep("[cloaking-device-on]");
}


void cxx::PlayerEntity::playCloakingDeviceOff()
{
	playInterfaceBeep("[cloaking-device-off]");
}


void cxx::PlayerEntity::playMenuNavigationUp()
{
	playInterfaceBeep("[menu-navigation-up]");
}


void cxx::PlayerEntity::playMenuNavigationDown()
{
	playInterfaceBeep("[menu-navigation-down]");
}


void cxx::PlayerEntity::playMenuNavigationNot()
{
	playInterfaceBeep("[menu-navigation-not]");
}


void cxx::PlayerEntity::playMenuPagePrevious()
{
	playInterfaceBeep("[menu-next-page]");
}


void cxx::PlayerEntity::playMenuPageNext()
{
	playInterfaceBeep("[menu-previous-page]");
}


void cxx::PlayerEntity::playDismissedReportScreen()
{
	playInterfaceBeep("[dismissed-report-screen]");
}


void cxx::PlayerEntity::playDismissedMissionScreen()
{
	playInterfaceBeep("[dismissed-mission-screen]");
}


void cxx::PlayerEntity::playChangedOption()
{
	playInterfaceBeep("[changed-option]");
}


void cxx::PlayerEntity::updateFuelScoopSoundWithInterval(OOTimeDelta delta_t)
{
	static double scoopSoundPlayTime = 0.0;
	scoopSoundPlayTime -= delta_t;
	if (scoopSoundPlayTime < 0.0)
	{
		if(![sInterfaceBeepSource isPlaying])
		{
		/* TODO: this should use the scoop position, not the standard
		 * interface beep position */
			playInterfaceBeep("[scoop]");
			scoopSoundPlayTime = 0.5;
		}
		else scoopSoundPlayTime = 0.0;
	}
	if (!scoopOverride)
	{
		scoopSoundPlayTime = 0.0;
	}
}


// time delay method for playing afterburner sounds
// this overlaps two sounds each 2 seconds long, but with a 0.75s
// crossfade


void cxx::PlayerEntity::updateAfterburnerSound()
{
	static uint8_t which = 0;
	
	if (!afterburner_engaged)				// end the loop cycle
	{
		afterburnerSoundLooping = NO;
	}
	
	if (afterburnerSoundLooping)
	{
		[sAfterburnerSources[which] play];
		which = !which;
		
		[oo::ToObjC(this) cxx_scheduleAfterburnerSoundUpdate];	// and swap sounds in 1.25s time
	}
}


void cxx::PlayerEntity::startAfterburnerSound()
{
	if (!afterburnerSoundLooping)
	{
		afterburnerSoundLooping = YES;
		updateAfterburnerSound();
	}
}


void cxx::PlayerEntity::stopAfterburnerSound()
{
	// Do nothing, stop is detected in updateAfterburnerSound
}


void cxx::PlayerEntity::playCloakingDeviceInsufficientEnergy()
{
	playInterfaceBeep("[cloaking-device-insufficent-energy]");
}


void cxx::PlayerEntity::playBuyCommodity()
{
	if (sBuySellSourcePool != nullptr)  sBuySellSourcePool->playSoundWithKey("[buy-commodity]");
}


void cxx::PlayerEntity::playBuyShip()
{
	if (sBuySellSourcePool != nullptr)  sBuySellSourcePool->playSoundWithKey("[buy-ship]");
}


void cxx::PlayerEntity::playSellCommodity()
{
	if (sBuySellSourcePool != nullptr)  sBuySellSourcePool->playSoundWithKey("[sell-commodity]");
}


void cxx::PlayerEntity::playCantBuyCommodity()
{
	if (sBuySellSourcePool != nullptr)  sBuySellSourcePool->playSoundWithKey("[could-not-buy-commodity]");
}


void cxx::PlayerEntity::playCantSellCommodity()
{
	if (sBuySellSourcePool != nullptr)  sBuySellSourcePool->playSoundWithKey("[could-not-sell-commodity]");
}


void cxx::PlayerEntity::playCantBuyShip()
{
	if (sBuySellSourcePool != nullptr)  sBuySellSourcePool->playSoundWithKey("[could-not-buy-ship]");
}


void cxx::PlayerEntity::playStandardHyperspace()
{
	[sHyperspaceSoundSource cxx_playCustomSoundWithKey:"[hyperspace-countdown-begun]"];
}


void cxx::PlayerEntity::playGalacticHyperspace()
{
	[sHyperspaceSoundSource cxx_playCustomSoundWithKey:"[galactic-hyperspace-countdown-begun]"];
}


void cxx::PlayerEntity::playHyperspaceAborted()
{
	[sHyperspaceSoundSource cxx_playCustomSoundWithKey:"[hyperspace-countdown-aborted]"];
}


void cxx::PlayerEntity::playHitByECMSound()
{
	if (![sEcmSource isPlaying]) [sEcmSource cxx_playCustomSoundWithKey:"[player-hit-by-ecm]"];
}


void cxx::PlayerEntity::playFiredECMSound()
{
	if (![sEcmSource isPlaying]) [sEcmSource cxx_playCustomSoundWithKey:"[player-fired-ecm]"];
}


void cxx::PlayerEntity::playLaunchFromStation()
{
	[sBreakPatternSource cxx_playCustomSoundWithKey:"[player-launch-from-station]"];
}


void cxx::PlayerEntity::playDockWithStation()
{
	[sBreakPatternSource cxx_playCustomSoundWithKey:"[player-dock-with-station]"];
}


void cxx::PlayerEntity::playExitWitchspace()
{
	[sBreakPatternSource cxx_playCustomSoundWithKey:"[player-exit-witchspace]"];
}


void cxx::PlayerEntity::playHostileWarning()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[hostile-warning]", 1.0f, kInterfaceWarningPosition);
}


void cxx::PlayerEntity::playAlertConditionRed()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[alert-condition-red]", 2.0f, kInterfaceWarningPosition);
}


void cxx::PlayerEntity::playIncomingMissile(Vector missileVector)
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[incoming-missile]", 3.0f, missileVector);
}


void cxx::PlayerEntity::playEnergyLow()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[energy-low]", 0.5f, kInterfaceWarningPosition);
}


void cxx::PlayerEntity::playDockingDenied()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[autopilot-denied]", 1.0f, kInterfaceWarningPosition);
}


void cxx::PlayerEntity::playWitchjumpFailure()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[witchdrive-failure]", 1.5f, kWitchspacePosition);
}


void cxx::PlayerEntity::playWitchjumpMisjump()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[witchdrive-malfunction]", 1.5f, kWitchspacePosition);
}


void cxx::PlayerEntity::playWitchjumpBlocked()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[witch-blocked-by-@]", 1.3f, kWitchspacePosition);
}


void cxx::PlayerEntity::playWitchjumpDistanceTooGreat()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[witch-too-far]", 1.3f, kWitchspacePosition);
}


void cxx::PlayerEntity::playWitchjumpInsufficientFuel()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[witch-no-fuel]", 1.3f, kWitchspacePosition);
}


void cxx::PlayerEntity::playFuelLeak()
{
	if (sWarningSoundPool != nullptr)  sWarningSoundPool->playSoundWithKey("[fuel-leak]", 0.5f, kWitchspacePosition);
}


void cxx::PlayerEntity::playShieldHit(Vector attackVector, const std::string & weaponIdentifier)
{
	if (sDamageSoundPool != nullptr)  sDamageSoundPool->playSoundWithKey(WeaponSoundKey(weaponShieldHit, weaponIdentifier, "[player-hit-by-weapon]"), attackVector);
}


void cxx::PlayerEntity::playDirectHit(Vector attackVector, const std::string & weaponIdentifier)
{
	if (sDamageSoundPool != nullptr)  sDamageSoundPool->playSoundWithKey(WeaponSoundKey(weaponUnshieldedHit, weaponIdentifier, "[player-direct-hit]"), attackVector);
}


void cxx::PlayerEntity::playScrapeDamage(Vector attackVector)
{
	if (sDamageSoundPool != nullptr)  sDamageSoundPool->playSoundWithKey("[player-scrape-damage]", attackVector);
}


void cxx::PlayerEntity::playLaserHit(bool hit, Vector weaponOffset, const std::string & weaponIdentifier)
{
	if (hit)
	{
		if (sWeaponSoundPool != nullptr)  sWeaponSoundPool->playSoundWithKey(WeaponSoundKey(weaponShotHit, weaponIdentifier, "[player-laser-hit]"), 1.0f, 0.05, static_cast<bool>(YES), weaponOffset);
	}
	else
	{
		if (sWeaponSoundPool != nullptr)  sWeaponSoundPool->playSoundWithKey(WeaponSoundKey(weaponShotMiss, weaponIdentifier, "[player-laser-miss]"), 1.0f, 0.05, static_cast<bool>(YES), weaponOffset);

	}
}


void cxx::PlayerEntity::playWeaponOverheated(Vector weaponOffset)
{
	if (sWeaponSoundPool != nullptr)  sWeaponSoundPool->playSoundWithKey("[weapon-overheat]", static_cast<bool>(NO), weaponOffset);
}


void cxx::PlayerEntity::playMissileLaunched(Vector weaponOffset, const std::string & weaponIdentifier)
{
	if (sWeaponSoundPool != nullptr)  sWeaponSoundPool->playSoundWithKey(WeaponSoundKey(weaponLaunched, weaponIdentifier, "[missile_launched]"), weaponOffset);
}


void cxx::PlayerEntity::playMineLaunched(Vector weaponOffset, const std::string & weaponIdentifier)
{
	if (sWeaponSoundPool != nullptr)  sWeaponSoundPool->playSoundWithKey(WeaponSoundKey(weaponLaunched, weaponIdentifier, "[mine_launched]"), weaponOffset);
}


void cxx::PlayerEntity::playEscapePodScooped()
{
	if (sMiscSoundPool != nullptr)  sMiscSoundPool->playSoundWithKey("[escape-pod-scooped]", kInterfaceBeepPosition);
}


void cxx::PlayerEntity::playAegisCloseToPlanet()
{
	if (sMiscSoundPool != nullptr)  sMiscSoundPool->playSoundWithKey("[aegis-planet]", kInterfaceBeepPosition);
}


void cxx::PlayerEntity::playAegisCloseToStation()
{
	if (sMiscSoundPool != nullptr)  sMiscSoundPool->playSoundWithKey("[aegis-station]", kInterfaceBeepPosition);
}


void cxx::PlayerEntity::playGameOver()
{
	if (sMiscSoundPool != nullptr)  sMiscSoundPool->playSoundWithKey("[game-over]");
}


void cxx::PlayerEntity::playLegacyScriptSound(const std::string & key)
{
	if (sMiscSoundPool != nullptr)  sMiscSoundPool->playSoundWithKey(key, 1.1f);
}

