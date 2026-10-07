/*

Universe+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendment oo-riqmz): the Objective-C Universe facade (see
Universe+ObjCBridge.h). Its initialiser and -dealloc are here, in a category while the class's
@implementation is still Universe.mm, because they need the Objective-C object as self; their
bodies are cxx::Universe's initWithGameView() and dealloc(), in Universe.mm. The other methods are
still in Universe.mm until their slices move them. Deleted with Universe+ObjCBridge.h.

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

#import "Universe.h"
#import "GameController.h"
#include "oofnd/objc/OOException.h"


extern Universe *gSharedUniverse;


@implementation Universe (OOObjCBridge)

- (id) initWithGameView:(MyOpenGLView *)inGameView
{
	/*	The part first: a universe refused below is released at once, and its -dealloc runs the
		whole body as it did when the ivars were the object's.
	*/
	if (_cxxUniverse == nullptr)  _cxxUniverse = oo::makeRef<cxx::Universe>(self);

	if (gSharedUniverse != nil)
	{
		[self release];
		[OOException raise:OOInternalInconsistencyException format:"%s: expected only one Universe to exist at a time.", __PRETTY_FUNCTION__];
	}

	OO_DEBUG_PROGRESS("Universe initWithGameView:");

	self = [super init];
	if (self == nil)  return nil;

	_cxxUniverse->initWithGameView(inGameView);
	return self;
}


- (void) dealloc
{
	// A universe released before -initWithGameView: made its part has nothing to tear down (oo-s6ic6).
	if (_cxxUniverse != nullptr)  _cxxUniverse->dealloc();
	_cxxUniverse = nullptr;

	[super dealloc];
}

@end


@implementation Universe (OOSlice2)

- (BOOL) bloom	{ return _cxxUniverse->bloom(); }
- (void) setBloom:(BOOL)newBloom	{ _cxxUniverse->setBloom(newBloom); }
- (int) currentPostFX	{ return _cxxUniverse->currentPostFX(); }
- (void) setCurrentPostFX:(int)newCurrentPostFX	{ _cxxUniverse->setCurrentPostFX(newCurrentPostFX); }
- (void) terminatePostFX:(int)postFX	{ _cxxUniverse->terminatePostFX(postFX); }
- (int) nextColorblindMode:(int)index	{ return _cxxUniverse->nextColorblindMode(index); }
- (int) prevColorblindMode:(int)index	{ return _cxxUniverse->prevColorblindMode(index); }
- (int) colorblindMode	{ return _cxxUniverse->colorblindMode(); }
- (void) initTargetFramebufferWithViewSize:(NSSize)viewSize	{ _cxxUniverse->initTargetFramebufferWithViewSize(viewSize); }
- (void) deleteOpenGLObjects	{ _cxxUniverse->deleteOpenGLObjects(); }
- (void) resizeTargetFramebufferWithViewSize:(NSSize)viewSize	{ _cxxUniverse->resizeTargetFramebufferWithViewSize(viewSize); }
- (void) drawTargetTextureIntoDefaultFramebuffer	{ _cxxUniverse->drawTargetTextureIntoDefaultFramebuffer(); }
- (NSUInteger) sessionID	{ return _cxxUniverse->sessionID(); }
- (BOOL) doingStartUp	{ return _cxxUniverse->doingStartUp(); }
- (BOOL) doProcedurallyTexturedPlanets	{ return _cxxUniverse->getDoProcedurallyTexturedPlanets(); }
- (void) setDoProcedurallyTexturedPlanets:(BOOL)value	{ _cxxUniverse->setDoProcedurallyTexturedPlanets(value); }
- (std::optional<std::string>) cxx_useAddOns	{ return _cxxUniverse->getUseAddOns(); }
- (BOOL) cxx_setUseAddOns:(const std::string &)newUse fromSaveGame:(BOOL)saveGame	{ return _cxxUniverse->setUseAddOns(newUse, saveGame); }
- (BOOL) cxx_setUseAddOns:(const std::string &)newUse fromSaveGame:(BOOL)saveGame forceReinit:(BOOL)force	{ return _cxxUniverse->setUseAddOns(newUse, saveGame, force); }
- (NSUInteger) entityCount	{ return _cxxUniverse->entityCount(); }
#ifndef NDEBUG
- (void) debugDumpEntities	{ _cxxUniverse->debugDumpEntities(); }
- (std::vector<oo::ObjCRef<Entity *>>) cxx_entityList	{ return _cxxUniverse->entityList(); }
#endif

@end


@implementation Universe (OOSlice3)

- (void) pauseGame	{ _cxxUniverse->pauseGame(); }
- (void) quitGame	{ _cxxUniverse->quitGame(); }
- (void) carryPlayerOn:(StationEntity*)carrier inWormhole:(WormholeEntity*)wormhole	{ _cxxUniverse->carryPlayerOn(carrier, wormhole); }
- (void) setUpUniverseFromStation	{ _cxxUniverse->setUpUniverseFromStation(); }
- (void) setUpUniverseFromWitchspace	{ _cxxUniverse->setUpUniverseFromWitchspace(); }
- (void) setUpUniverseFromMisjump	{ _cxxUniverse->setUpUniverseFromMisjump(); }
- (void) setUpWitchspace	{ _cxxUniverse->setUpWitchspace(); }
- (void) setUpWitchspaceBetweenSystem:(OOSystemID)s1 andSystem:(OOSystemID)s2	{ _cxxUniverse->setUpWitchspaceBetweenSystem(s1, s2); }
- (OOPlanetEntity *) setUpPlanet	{ return _cxxUniverse->setUpPlanet(); }

@end


@implementation Universe (OOSlice4)

- (void) setUpSpace	{ _cxxUniverse->setUpSpace(); }
- (void) populateNormalSpace	{ _cxxUniverse->populateNormalSpace(); }
- (void) clearSystemPopulator	{ _cxxUniverse->clearSystemPopulator(); }
- (oo::PList) cxx_getPopulatorSettings	{ return _cxxUniverse->getPopulatorSettings(); }
- (void) cxx_setPopulatorSetting:(const std::string &)key to:(const oo::PList &)setting	{ _cxxUniverse->setPopulatorSetting(key, setting); }
- (BOOL) deterministicPopulation	{ return _cxxUniverse->deterministicPopulation(); }
- (void) populateSystemFromDictionariesWithSun:(OOSunEntity *)sun andPlanet:(OOPlanetEntity *)planet	{ _cxxUniverse->populateSystemFromDictionariesWithSun(sun, planet); }

@end
