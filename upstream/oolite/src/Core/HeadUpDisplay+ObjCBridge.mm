/*

HeadUpDisplay+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, bead oo-engam): the Objective-C facade over cxx::HeadUpDisplay.
See HeadUpDisplay+ObjCBridge.h. The drawing (the Private category) is implemented in
HeadUpDisplay.mm, not here.

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

#import "HeadUpDisplay.h"
#import "OOColor.h"

#include "oofnd/objc/OOObjCPeer.h"


namespace {

// Never destroyed: a facade may be released while the process exits.
oo::ObjCPeers &Peers()
{
	static oo::ObjCPeers *peers = new oo::ObjCPeers;
	return *peers;
}

}	// namespace


@interface HeadUpDisplay (OOObjCBridgePrivate)

- (id) initWithCxxHUD:(cxx::HeadUpDisplay *)hud;

@end


@implementation HeadUpDisplay

// Inside the @implementation for the private ivar.
HeadUpDisplay *oo::ToObjC(cxx::HeadUpDisplay *hud)
{
	return Peers().peerFor(hud, [hud] { return [[HeadUpDisplay alloc] initWithCxxHUD:hud]; });
}


cxx::HeadUpDisplay *oo::ToCxx(HeadUpDisplay *hud)
{
	if (hud == nil)  return nullptr;
	return hud->_cxxHUD.get();
}


/*	The facade is the HUD's peer before the C++ initialisation runs: it hands the HUD to the drawing
	that is still Objective-C (the dial check asks the facade which dials it answers, and a crosshair
	file is read by -cxx_setCrosshairDefinition:), which must see this object (amendment oo-8kx7).
*/
- (id) cxx_initWithDictionary:(const oo::PList &)hudinfo inFile:(const std::optional<std::string> &)hudFileName
{
	self = [super init];
	if (self == nil)  return nil;

	_cxxHUD = oo::makeRef<cxx::HeadUpDisplay>();
	@autoreleasepool
	{
		Peers().peerFor(_cxxHUD.get(), [self] { return [self retain]; });
	}
	_cxxHUD->initWithDictionary(hudinfo, hudFileName);
	return self;
}


- (id) initWithCxxHUD:(cxx::HeadUpDisplay *)hud
{
	self = [super init];
	if (self != nil)  _cxxHUD = oo::Ref<cxx::HeadUpDisplay>(hud);
	return self;
}


- (void) dealloc
{
	Peers().forget(_cxxHUD.get());
	[super dealloc];
}


- (void) cxx_resetGuis:(const oo::PList &)info	{ _cxxHUD->resetGuis(info); }

- (std::optional<std::string>) cxx_hudName	{ return _cxxHUD->getHudName(); }
- (void) setHudName:(const std::optional<std::string> &)newHudName	{ _cxxHUD->setHudName(newHudName); }

- (GLfloat) scannerZoom	{ return _cxxHUD->scannerZoom(); }
- (void) setScannerZoom:(GLfloat)value	{ _cxxHUD->setScannerZoom(value); }

- (GLfloat) overallAlpha	{ return _cxxHUD->getOverallAlpha(); }
- (void) setOverallAlpha:(GLfloat)newAlphaValue	{ _cxxHUD->setOverallAlpha(newAlphaValue); }

- (BOOL) reticleTargetSensitive	{ return _cxxHUD->getReticleTargetSensitive(); }
- (void) setReticleTargetSensitive:(BOOL)newReticleTargetSensitiveValue	{ _cxxHUD->setReticleTargetSensitive(newReticleTargetSensitiveValue); }
- (oo::PList *) propertiesReticleTargetSensitive	{ return _cxxHUD->getPropertiesReticleTargetSensitive(); }

- (BOOL) isHidden	{ return _cxxHUD->isHidden(); }
- (void) setHidden:(BOOL)newValue	{ _cxxHUD->setHidden(newValue); }

- (BOOL) allowBigGui	{ return _cxxHUD->getAllowBigGui(); }

- (BOOL) hasHidden:(const std::optional<std::string> &)selectorName	{ return _cxxHUD->hasHidden(selectorName); }
- (void) cxx_setHiddenSelector:(const std::string &)selectorName hidden:(BOOL)hide	{ _cxxHUD->setHiddenSelector(selectorName, hide); }
- (void) clearHiddenSelectors	{ _cxxHUD->clearHiddenSelectors(); }

- (BOOL) isCompassActive	{ return _cxxHUD->isCompassActive(); }
- (void) setCompassActive:(BOOL)newValue	{ _cxxHUD->setCompassActive(newValue); }

- (BOOL) isUpdating	{ return _cxxHUD->isUpdating(); }
- (void) cxx_setDeferredHudName:(const std::optional<std::string> &)newDeferredHudName	{ _cxxHUD->setDeferredHudName(newDeferredHudName); }
- (std::optional<std::string>) cxx_deferredHudName	{ return _cxxHUD->getDeferredHudName(); }
- (std::optional<std::string>) cxx_crosshairDefinition	{ return _cxxHUD->getCrosshairDefinition(); }

- (void) addLegend:(const oo::PList &)info	{ _cxxHUD->addLegend(info); }
- (void) addDial:(const oo::PList &)info	{ _cxxHUD->addDial(info); }
- (void) addMFD:(const oo::PList &)info	{ _cxxHUD->addMFD(info); }

- (NSUInteger) mfdCount	{ return _cxxHUD->mfdCount(); }

- (void) refreshLastTransmitter	{ _cxxHUD->refreshLastTransmitter(); }

- (void) setLineWidth:(GLfloat)value	{ _cxxHUD->setLineWidth(value); }
- (GLfloat) lineWidth	{ return _cxxHUD->getLineWidth(); }

- (BOOL) minimalisticScanner	{ return _cxxHUD->minimalisticScanner(); }
- (void) setMinimalisticScanner:(BOOL)newValue	{ _cxxHUD->setMinimalisticScanner(newValue); }

+ (Vector) nonlinearScannerScale:(Vector)V Zoom:(GLfloat)zoom Scale:(double)scale	{ return cxx::HeadUpDisplay::nonlinearScannerScale(V, zoom, scale); }
- (BOOL) nonlinearScanner	{ return _cxxHUD->nonlinearScanner(); }
- (void) setNonlinearScanner:(BOOL)newValue	{ _cxxHUD->setNonlinearScanner(newValue); }

- (BOOL) scannerUltraZoom	{ return _cxxHUD->scannerUltraZoom(); }
- (void) setScannerUltraZoom:(BOOL)newValue	{ _cxxHUD->setScannerUltraZoom(newValue); }

- (OOColor *) reticleColorForIndex:(NSUInteger)idx	{ return oo::ToObjC(_cxxHUD->reticleColorForIndex(idx)); }
- (BOOL) setReticleColorForIndex:(NSUInteger)idx toColor:(OOColor *)newColor	{ return _cxxHUD->setReticleColorForIndex(idx, oo::ToCxx(newColor)); }

@end


@implementation HeadUpDisplay (OOPrivate)

- (BOOL) checkPlayerInFlight	{ return _cxxHUD->checkPlayerInFlight(); }
- (BOOL) checkPlayerInSystemFlight	{ return _cxxHUD->checkPlayerInSystemFlight(); }

@end
