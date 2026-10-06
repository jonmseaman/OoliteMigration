/*

HeadUpDisplay+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, bead oo-engam): the Objective-C HeadUpDisplay, a facade over the
C++ cxx::HeadUpDisplay (HeadUpDisplay.h), for the code that is not converted yet: the HUD's
callers (the player, the universe, the scripting bindings: about 30 files reach it through
[PLAYER hud]) and the drawing of slices 2-6 of HeadUpDisplay.mm
(docs/phases/3-slices/HeadUpDisplay.md), which stays Objective-C, as the Private category below,
until each slice's own bead. Its interface is the old one, copied exactly (same selectors, same
types, same root), except that -renderHUD and -cxx_setCrosshairDefinition:, which slice 2 owns, are
declared in the Private category that implements them, with the drawing methods the .mm declared
in it. Each method of the class forwards to its C++ member. Imported as the last line of
HeadUpDisplay.h; do not import it directly.

	a caller that is                       holds / passes                       crosses with
	-------------------------------------  -----------------------------------  ------------------------
	still Objective-C                      HeadUpDisplay *                      (nothing)
	  a drawing method (slices 2-6)        HeadUpDisplay * (self)               oo::ToCxx(self) for the state
	converted (C++)                        oo::Ref<cxx::HeadUpDisplay>          oo::ToObjC(hud)

The dials are called by name on the facade (OOCallByName, ADR-0055 item 5), so the facade keeps
answering every dial selector until it is deleted. The functions at the end are the one-line
sends of converted free functions to classes that are still Objective-C (ADR-0056 amendment
oo-9ht.139); each goes with its class's conversion.

Never add to this file except a forwarder or a send of that kind. Deleted, with namespace cxx in
HeadUpDisplay.h, by its deletion bead once the callers and the drawing are converted.

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

#ifndef HEADUPDISPLAY_OBJCBRIDGE_H
#define HEADUPDISPLAY_OBJCBRIDGE_H

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"


@class OOColor, GuiDisplayGen, MyOpenGLView;


@interface HeadUpDisplay: OOObject
{
@private
	oo::Ref<cxx::HeadUpDisplay>	_cxxHUD;
}

- (id) cxx_initWithDictionary:(const oo::PList &)hudinfo inFile:(const std::optional<std::string> &)hudFileName OO_RETURNS_RETAINED;

- (void) cxx_resetGuis:(const oo::PList &)info;

- (std::optional<std::string>) cxx_hudName;
- (void) setHudName:(const std::optional<std::string> &)newHudName;	// nullopt is ignored, as nil was

- (GLfloat) scannerZoom;
- (void) setScannerZoom:(GLfloat)value;

- (GLfloat) overallAlpha;
- (void) setOverallAlpha:(GLfloat)newAlphaValue;

- (BOOL) reticleTargetSensitive;
- (void) setReticleTargetSensitive:(BOOL)newReticleTargetSensitiveValue;
- (oo::PList *) propertiesReticleTargetSensitive;	// the live dictionary; nullptr for a nil receiver

- (BOOL) isHidden;
- (void) setHidden:(BOOL)newValue;

- (BOOL) allowBigGui;

- (BOOL) hasHidden:(const std::optional<std::string> &)selectorName;	// nullopt (was nil): NO
- (void) cxx_setHiddenSelector:(const std::string &)selectorName hidden:(BOOL)hide;
- (void) clearHiddenSelectors;

- (BOOL) isCompassActive;
- (void) setCompassActive:(BOOL)newValue;

- (BOOL) isUpdating;
- (void) cxx_setDeferredHudName:(const std::optional<std::string> &)newDeferredHudName;
- (std::optional<std::string>) cxx_deferredHudName;
- (std::optional<std::string>) cxx_crosshairDefinition;
- (BOOL) cxx_setCrosshairDefinition:(const std::string &)newDefinition;

// Each takes one hud.plist entry; a null PList where the entry was not a dictionary.
- (void) addLegend:(const oo::PList &)info;
- (void) addDial:(const oo::PList &)info;
- (void) addMFD:(const oo::PList &)info;

- (NSUInteger) mfdCount;

- (void) renderHUD;

- (void) refreshLastTransmitter;

- (void) setLineWidth:(GLfloat)value;
- (GLfloat) lineWidth;

- (BOOL) minimalisticScanner;
- (void) setMinimalisticScanner: (BOOL) newValue;

+ (Vector) nonlinearScannerScale:(Vector) V Zoom:(GLfloat) zoom Scale:(double) scale;
- (BOOL) nonlinearScanner;
- (void) setNonlinearScanner: (BOOL)newValue;

- (BOOL) scannerUltraZoom;
- (void) setScannerUltraZoom: (BOOL)newValue;

- (OOColor *) reticleColorForIndex:(NSUInteger)idx;
- (BOOL) setReticleColorForIndex:(NSUInteger)idx toColor:(OOColor *)newColor;

@end


// Sent by the drawing methods (slices 3-6), which the .mm declared in its Private category.
@interface HeadUpDisplay (OOPrivate)

- (BOOL) checkPlayerInFlight;
- (BOOL) checkPlayerInSystemFlight;

@end


// The dials that are C++ members, called by name (ADR-0055 item 5): one forwarder each.
@interface HeadUpDisplay (OODials)

- (void) drawSurround:(const oo::PList &)info;
- (void) drawGreenSurround:(const oo::PList &)info;
- (void) drawYellowSurround:(const oo::PList &)info;
- (void) drawScanner:(const oo::PList &)info;
- (void) drawScannerZoomIndicator:(const oo::PList &)info;

@end


/*	The drawing (slices 2-6 of HeadUpDisplay.mm, still Objective-C), implemented in HeadUpDisplay.mm.
	The dials are called by name (ADR-0055 item 5). The .mm declared -drawPrimedEquipmentText:,
	which nothing implemented or sent; the dial it draws is -drawPrimedEquipment:.
*/
@interface HeadUpDisplay (Private)

- (void) drawCompass:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawCompassPlanetBlipAt:(Vector) relativePosition Size:(NSSize) siz Alpha:(GLfloat) alpha;
- (void) drawCompassStationBlipAt:(Vector) relativePosition Size:(NSSize) siz Alpha:(GLfloat) alpha;
- (void) drawCompassSunBlipAt:(Vector) relativePosition Size:(NSSize) siz Alpha:(GLfloat) alpha;
- (void) drawCompassTargetBlipAt:(Vector) relativePosition Size:(NSSize) siz Alpha:(GLfloat) alpha;
- (void) drawCompassBeaconBlipAt:(Vector) relativePosition Size:(NSSize) siz Alpha:(GLfloat) alpha;

- (void) drawAegis:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawSpeedBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawRollBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawPitchBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawYawBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawEnergyGauge:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawForwardShieldBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawAftShieldBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawFuelBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawWitchspaceDestination:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawCabinTempBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawWeaponTempBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawAltitudeBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawMissileDisplay:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawTargetReticle:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawSecondaryTargetReticle:(const oo::PList &)info;
- (void) drawWaypoints:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawStatusLight:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawDirectionCue:(const oo::PList &)info;
- (void) drawClock:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawPrimedEquipment:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawASCTarget:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawWeaponsOfflineText:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawFPSInfoCounter:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawScoopStatus:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawStickSensitivityIndicator:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawCustomBar:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawCustomText:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawCustomIndicator:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawCustomLight:(const oo::PList &)info;	// called by name (ADR-0055 item 5)
- (void) drawCustomImage:(const oo::PList &)info;	// called by name (ADR-0055 item 5)


- (void) drawTrumbles:(const oo::PList &)info;	// called by name (ADR-0055 item 5)

@end


namespace oo {

// The HUD's Objective-C facade: its live one, else a new one; autoreleased. nil for null.
HeadUpDisplay *ToObjC(cxx::HeadUpDisplay *hud);
inline HeadUpDisplay *ToObjC(const Ref<cxx::HeadUpDisplay> &hud)  { return ToObjC(hud.get()); }
// The C++ HUD behind a facade, borrowed (the facade retains it); null for nil.
cxx::HeadUpDisplay *ToCxx(HeadUpDisplay *hud);

}	// namespace oo


/*	Sends of converted free functions to classes that are still Objective-C (ADR-0056 amendment
	oo-9ht.139), one function per send, the body the send verbatim. Members keep their sends
	(amendment oo-ppc item 4). Each goes with its class's conversion.
*/
// +[ResourceManager cxx_dictionaryFromFilesNamed:inFolder:andMerge:] (InitTextEngine()).
oo::PList HeadUpDisplayDictionaryFromFilesNamed(const std::string &fileName, const std::optional<std::string> &folderName, bool mergeFiles);
// -[[UNIVERSE gui] cxx_setGLColorFromSetting:defaultValue:alpha:] (OODrawPlanetInfo()).
void HeadUpDisplayUniverseGUISetGLColorFromSetting(const std::optional<std::string> &setting, OOColor *defaultValue, GLfloat alpha);
// [UNIVERSE gameView], -[MyOpenGLView fov:] and -[MyOpenGLView viewSize] (drawScannerGrid()).
MyOpenGLView *HeadUpDisplayUniverseGameView();
GLfloat HeadUpDisplayGameViewFov(MyOpenGLView *gameView, bool inFraction);
NSSize HeadUpDisplayGameViewViewSize(MyOpenGLView *gameView);

#endif	// HEADUPDISPLAY_OBJCBRIDGE_H
