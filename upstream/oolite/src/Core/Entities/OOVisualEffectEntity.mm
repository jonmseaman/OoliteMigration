/*

OOVisualEffectEntity.m


Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the impllied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/

#import "OOVisualEffectEntity.h"

#import "OOMaths.h"
#import "Universe.h"
#import "OOShaderMaterial.h"
#import "OOOpenGLExtensionManager.h"

#import "ResourceManager.h"
#import "OOStringParsing.h"
#import "OOStringExpander.h"
#import "OOConstToString.h"
#import "OOConstToJSString.h"

#import "OOMesh.h"

#import "OOColor.h"
#import "OOPolygonSprite.h"
#import "HeadUpDisplay.h"

#import "OOFlasherEntity.h"

#import "OODebugGLDrawing.h"
#import "OODebugFlags.h"

#import "OOJSScript.h"


#import "MyOpenGLView.h"
#import "OOPListGameTypes.h"

#include "oofnd/PListGet.hpp"
#import "OOObjCPList.h"
#include "oofnd/String.hpp"


namespace {

// -objectForKey: as plist data (a null PList when absent), for +cxx_colorWithDescription:.
oo::PList ValueForKey(const oo::PList &dict, std::string_view key)
{
	const oo::PList *value = dict.find(key);
	return value != nullptr ? *value : oo::PList();
}


// get<std::string> where the Foundation code read nil: std::nullopt when the key is absent or its
// value is neither a string nor a number.
std::optional<std::string> OptionalStringForKey(const oo::PList &dict, std::string_view key)
{
	const oo::PList *value = dict.find(key);
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return dict.get<std::string>(key);
}


// get<PList::Dict>: the dictionary, or null (nil).
oo::PList DictionaryForKey(const oo::PList &dict, std::string_view key)
{
	const oo::PList *value = dict.get<oo::PList::Dict>(key);
	return value != nullptr ? *value : oo::PList();
}


// A copy of the subentity list to walk (the Foundation code walked a copy of the array).
OOVisualEffectSubEntities SubEntitiesOf(const std::optional<OOVisualEffectSubEntities> &subEntities)
{
	return subEntities.value_or(OOVisualEffectSubEntities{});
}


// The subentities that answer YES to -isVisualEffect.
std::vector<oo::ObjCRef<OOVisualEffectEntity *>> VisualEffectsIn(const OOVisualEffectSubEntities &subEntities)
{
	std::vector<oo::ObjCRef<OOVisualEffectEntity *>> result;
	for (const auto &sub : subEntities)
	{
		if (!oo::ToCxx((::Entity *)sub.get())->getIsVisualEffect())  continue;	// -isVisualEffect, through the converted root
		result.emplace_back((OOVisualEffectEntity *)sub.get());
	}
	return result;
}

}	// namespace


namespace cxx {

/*	-cxx_initWithKey:definition:'s body after [super init] (the constructor ran Entity's). The
	façade runs it once it holds this object (amendment oo-0mxi item 2); false where the
	initialiser released itself and answered nil.
*/
bool OOVisualEffectEntity::initWithKey(const std::string &key, const oo::PList &dict)
{
	OOJS_PROFILE_ENTER

	_effectKey = key;

	if (!setUpVisualEffectFromDictionary(dict))
	{
		return false;
	}

	_haveExecutedSpawnAction = false;

	return true;

	OOJS_PROFILE_EXIT
}


bool OOVisualEffectEntity::setUpVisualEffectFromDictionary(const oo::PList &effectDict)
{
	OOJS_PROFILE_ENTER

	effectinfoDictionary = effectDict;
	if (effectinfoDictionary.isNull())  effectinfoDictionary = oo::PList(oo::PList::Dict{});

	orientation = kIdentityQuaternion;
	rotMatrix	= kIdentityMatrix;

	collision_radius = 0.0;

	const std::optional<std::string> modelName = OptionalStringForKey(effectDict, "model");
	if (modelName.has_value())
	{
		::OOMesh *mesh = [::OOMesh meshWithName:*modelName
								   cacheKey:_effectKey
						 materialDictionary:DictionaryForKey(effectDict, "materials")
						  shadersDictionary:DictionaryForKey(effectDict, "shaders")
									 smooth:effectDict.get<bool>("smooth", false)
							   shaderMacros:OODefaultShipShaderMacros()
						shaderBindingTarget:oo::ToObjC(this)];
		if (mesh == nil)  return false;
		setMesh(mesh);
	}

	isImmuneToBreakPatternHide = effectDict.get<bool>("is_break_pattern");
	_scaleX = 1.0;
	_scaleY = 1.0;
	_scaleZ = 1.0;

	clearSubEntities();
	setUpSubEntities();

	[oo::ToObjC(this) setScannerDisplayColor1:nil];
	[oo::ToObjC(this) setScannerDisplayColor2:nil];

	scanClass = CLASS_VISUAL_EFFECT;

	setStatus(STATUS_EFFECT);

	_hullHeatLevel = 60.0 / 256.0;
	_shaderFloat1 = 0.0;
	_shaderFloat2 = 0.0;
	_shaderInt1 = 0;
	_shaderInt2 = 0;
	_shaderVector1 = kZeroVector;
	_shaderVector2 = kZeroVector;

	[oo::ToObjC(this) setBeaconCode:OptionalStringForKey(effectDict, "beacon")];
	const std::optional<std::string> beaconLabel = OptionalStringForKey(effectDict, "beacon_label");
	[oo::ToObjC(this) setBeaconLabel:beaconLabel.has_value() ? beaconLabel : [oo::ToObjC(this) beaconCode]];

	const oo::PList *scriptInfoValue = effectDict.get<oo::PList::Dict>("script_info");
	scriptInfo = scriptInfoValue != nullptr ? *scriptInfoValue : oo::PList();
	[oo::ToObjC(this) setScript:OptionalStringForKey(effectDict, "script")];

	return true;

	OOJS_PROFILE_EXIT
}


OOVisualEffectEntity::~OOVisualEffectEntity()
{
	clearSubEntities();
	DESTROY(scanner_display_color1);
	DESTROY(scanner_display_color2);
	DESTROY(script);
	DESTROY(_beaconDrawable);
}


bool OOVisualEffectEntity::isEffect()
{
	return true;
}


bool OOVisualEffectEntity::getIsVisualEffect()
{
	return true;
}


bool OOVisualEffectEntity::canCollide()
{
	return false;
}


::OOMesh *OOVisualEffectEntity::mesh()
{
	return (::OOMesh *)getDrawable();
}


void OOVisualEffectEntity::setMesh(::OOMesh *mesh)
{
	if (mesh != this->mesh())
	{
		setDrawable(mesh);
	}
}


std::optional<std::string> OOVisualEffectEntity::effectKey()
{
	return _effectKey;
}


GLfloat OOVisualEffectEntity::frustumRadius()
{
	return scaleMax() * _profileRadius;
}


void OOVisualEffectEntity::clearSubEntities()
{
	for (const auto &sub : SubEntitiesOf(_subEntities))  [sub.get() setOwner:nil];	// Ensure backlinks are broken
	_subEntities.reset();

	// reset size & mass!
	if (mesh())
	{
		collision_radius = findCollisionRadius();
	}
	else
	{
		collision_radius = 0.0;
	}
	_profileRadius = collision_radius;
}


bool OOVisualEffectEntity::setUpSubEntities()
{
	unsigned int	i;
	_profileRadius = collision_radius;
	const oo::PList *subs = effectinfoDictionary.get<oo::PList::Array>("subentities");

	for (i = 0; subs != nullptr && i < subs->count(); i++)
	{
		const oo::PList *subentDict = subs->at<oo::PList::Dict>(i);	// nil for anything but a dictionary
		setUpOneSubentity(subentDict != nullptr ? *subentDict : oo::PList());
	}

	setNoDrawDistance();

	return true;
}


void OOVisualEffectEntity::removeSubEntity(OOVisualEffectSubEntity *sub)
{
	[sub setOwner:nil];
	if (_subEntities.has_value())  std::erase_if(*_subEntities, [sub](const auto &entry) { return entry.get() == sub; });
}


void OOVisualEffectEntity::setNoDrawDistance()
{
	GLfloat r = _profileRadius * scaleMax();
	no_draw_distance = r * r * NO_DRAW_DISTANCE_FACTOR * NO_DRAW_DISTANCE_FACTOR * 2.0;

}


bool OOVisualEffectEntity::setUpOneSubentity(const oo::PList &subentDict)
{
	const std::optional<std::string> type = OptionalStringForKey(subentDict, "type");
	if (type == "flasher")
	{
		return setUpOneFlasher(subentDict);
	}
	else
	{
		return setUpOneStandardSubentity(subentDict);
	}


}


bool OOVisualEffectEntity::setUpOneFlasher(const oo::PList &subentDict)
{
	::OOFlasherEntity *flasher = [::OOFlasherEntity flasherWithDictionary:subentDict];
	[flasher setPosition:subentDict ? OOHPVectorFromPList(subentDict.find("position"), kZeroHPVector) : kZeroHPVector];
	addSubEntity(flasher);
	return true;
}


bool OOVisualEffectEntity::setUpOneStandardSubentity(const oo::PList &subentDict)
{
	::OOVisualEffectEntity			*subentity = nil;
	std::optional<std::string>	subentKey;
	HPVector				subPosition;
	Quaternion			subOrientation;

	subentKey = OptionalStringForKey(subentDict, "subentity_key");
	if (!subentKey.has_value()) {
		OO_LOG("setup.visualeffect.badEntry.subentities", "Failed to set up entity - no subentKey in {}", oo::DescriptionOf(subentDict));
		return false;
	}

	subentity = [UNIVERSE cxx_newVisualEffectWithName:*subentKey];
	if (subentity == nil) {
		OO_LOG("setup.visualeffect.badEntry.subentities", "Failed to set up entity {}", *subentKey);
		return false;
	}

	subPosition = OOHPVectorFromPList(subentDict.find("position"), kZeroHPVector);
	subOrientation = OOQuaternionFromPList(subentDict.find("orientation"), kIdentityQuaternion);

	[subentity setPosition:subPosition];
	[subentity setOrientation:subOrientation];

	addSubEntity(subentity);

	[subentity release];

	return true;
}


void OOVisualEffectEntity::addSubEntity(OOVisualEffectSubEntity *sub)
{
	if (sub == nil)  return;

	if (!_subEntities.has_value())  _subEntities.emplace();
	sub->_cxxEntity->isSubEntity = true;
	// Order matters - need consistent state in setOwner:. -- Ahruman 2008-04-20
	_subEntities->emplace_back(sub);
	[sub setOwner:oo::ToObjC(this)];

	double distance = HPmagnitude([sub position]) + [sub findCollisionRadius];
	if (distance > _profileRadius)
	{
		_profileRadius = distance;
	}
}


std::vector<oo::ObjCRef<::Entity *>> OOVisualEffectEntity::subEntities()
{
	if (!_subEntities.has_value())  return {};
	std::vector<oo::ObjCRef<::Entity *>> result;
	result.reserve(_subEntities->size());
	for (const auto &sub : *_subEntities)
	{
		result.emplace_back(sub.get());
	}
	return result;
}


NSUInteger OOVisualEffectEntity::subEntityCount()
{
	return _subEntities.has_value() ? _subEntities->size() : 0;
}


std::optional<std::vector<oo::ObjCRef<::OOVisualEffectEntity *>>> OOVisualEffectEntity::visualEffectSubEntityEnumerator()
{
	if (!_subEntities.has_value())  return std::nullopt;
	return VisualEffectsIn(*_subEntities);
}


bool OOVisualEffectEntity::hasSubEntity(OOVisualEffectSubEntity *sub)
{
	if (!_subEntities.has_value())  return false;
	return std::find_if(_subEntities->begin(), _subEntities->end(), [sub](const auto &entry) { return entry.get() == sub; }) != _subEntities->end();
}


std::vector<oo::ObjCRef<::Entity *>> OOVisualEffectEntity::subEntityEnumerator()
{
	return subEntities();
}


std::vector<oo::ObjCRef<::OOVisualEffectEntity *>> OOVisualEffectEntity::effectSubEntityEnumerator()
{
	return VisualEffectsIn(SubEntitiesOf(_subEntities));
}


std::vector<oo::ObjCRef<::OOFlasherEntity *>> OOVisualEffectEntity::flasherEnumerator()
{
	std::vector<oo::ObjCRef<::OOFlasherEntity *>> flashers;
	if (!_subEntities.has_value())  return flashers;
	for (const auto &sub : *_subEntities)
	{
		if (![sub.get() isFlasher])  continue;
		flashers.emplace_back((::OOFlasherEntity *)sub.get());
	}
	return flashers;
}


void OOVisualEffectEntity::drawSubEntityImmediate(bool immediate, bool translucent)
{
	if (cam_zero_distance > no_draw_distance) // this test provides an opportunity to do simple LoD culling
	{
		return; // TOO FAR AWAY
	}
	OOGLPushModelView();
	// HPVect: camera position
	OOGLTranslateModelView(HPVectorToVector(position));
	OOGLMultModelView(rotMatrix);
	drawImmediate(immediate, translucent);

	OOGLPopModelView();
}


void OOVisualEffectEntity::rescaleBy(GLfloat factor)
{
	if (mesh() != nil) {
		setMesh([mesh() meshRescaledBy:factor]);
	}

	// rescale subentities
	OOVisualEffectSubEntity	*se = nil;
	for (const auto &seRef : SubEntitiesOf(_subEntities))
	{
		se = seRef.get();
		[se setPosition:HPvector_multiply_scalar([se position], factor)];
		[se rescaleBy:factor];
	}

	collision_radius *= factor;
	_profileRadius *= factor;
}


void OOVisualEffectEntity::rescaleBy(GLfloat /*factor*/, bool /*writeToCache*/)
{
	/* Do nothing; this is only needed because of OOEntityWithDrawable
	   implementation requirements */
}


GLfloat OOVisualEffectEntity::scaleMax()
{
	GLfloat scale = 1.0;
	if (_scaleX > _scaleY)
	{
		if (_scaleX > _scaleZ)
		{
			scale *= _scaleX;
		}
		else
		{
			scale *= _scaleZ;
		}
	}
	else if (_scaleY > _scaleZ)
	{
		scale *= _scaleY;
	}
	else
	{
		scale *= _scaleZ;
	}
	return scale;
}

GLfloat OOVisualEffectEntity::scaleX()
{
	return _scaleX;
}


void OOVisualEffectEntity::setScaleX(GLfloat factor)
{
	// rescale subentities
	OOVisualEffectSubEntity	*se = nil;
	GLfloat flasher_factor = pow(factor/_scaleX,1.0/3.0);
	for (const auto &seRef : SubEntitiesOf(_subEntities))
	{
		se = seRef.get();
		HPVector move = [se position];
		move.x *= factor/_scaleX;
		[se setPosition:move];
		if ([se isVisualEffect])
		{
			[(::OOVisualEffectEntity*)se setScaleX:factor];
		}
		else
		{
			[se rescaleBy:flasher_factor];
		}
	}

	_scaleX = factor;
	setNoDrawDistance();
}


GLfloat OOVisualEffectEntity::scaleY()
{
	return _scaleY;
}


void OOVisualEffectEntity::setScaleY(GLfloat factor)
{
	// rescale subentities
	OOVisualEffectSubEntity	*se = nil;
	GLfloat flasher_factor = pow(factor/_scaleY,1.0/3.0);
	for (const auto &seRef : SubEntitiesOf(_subEntities))
	{
		se = seRef.get();
		HPVector move = [se position];
		move.y *= factor/_scaleY;
		[se setPosition:move];
		if ([se isVisualEffect])
		{
			[(::OOVisualEffectEntity*)se setScaleY:factor];
		}
		else
		{
			[se rescaleBy:flasher_factor];
		}
	}

	_scaleY = factor;
	setNoDrawDistance();
}


GLfloat OOVisualEffectEntity::scaleZ()
{
	return _scaleZ;
}


void OOVisualEffectEntity::setScaleZ(GLfloat factor)
{
	// rescale subentities
	OOVisualEffectSubEntity	*se = nil;
	GLfloat flasher_factor = pow(factor/_scaleZ,1.0/3.0);
	for (const auto &seRef : SubEntitiesOf(_subEntities))
	{
		se = seRef.get();
		HPVector move = [se position];
		move.z *= factor/_scaleZ;
		[se setPosition:move];
		if ([se isVisualEffect])
		{
			[(::OOVisualEffectEntity*)se setScaleZ:factor];
		}
		else
		{
			[se rescaleBy:flasher_factor];
		}
	}

	_scaleZ = factor;
	setNoDrawDistance();
}


GLfloat OOVisualEffectEntity::collisionRadius()
{
	return scaleMax() * collision_radius;
}


void OOVisualEffectEntity::orientationChanged()
{
	OOEntityWithDrawable::orientationChanged();

	_v_forward   = vector_forward_from_quaternion(orientation);
	_v_up		= vector_up_from_quaternion(orientation);
	_v_right		= vector_right_from_quaternion(orientation);
}


// exposed to shaders
Vector OOVisualEffectEntity::forwardVector()
{
	return _v_forward;
}


// exposed to shaders
Vector OOVisualEffectEntity::upVector()
{
	return _v_up;
}


// exposed to shaders
Vector OOVisualEffectEntity::rightVector()
{
	return _v_right;
}


void OOVisualEffectEntity::drawImmediate(bool immediate, bool translucent)
{
	if (no_draw_distance < cam_zero_distance)
	{
		return; // too far away to draw
	}
	OOGLPushModelView();
	OOGLScaleModelView(make_vector(_scaleX,_scaleY,_scaleZ));

	if (mesh() != nil)
	{
		OOEntityWithDrawable::drawImmediate(immediate, translucent);
	}
	OOGLPopModelView();

	// Draw subentities.
	if (!immediate)	// TODO: is this relevant any longer?
	{
		OOVisualEffectSubEntity *subEntity = nil;
		for (const auto &subEntityRef : SubEntitiesOf(_subEntities))
		{
			subEntity = subEntityRef.get();
			[subEntity drawSubEntityImmediate:immediate translucent:translucent];
		}
	}
}


void OOVisualEffectEntity::update(OOTimeDelta delta_t)
{
	OOEntityWithDrawable::update(delta_t);

	if (!_haveExecutedSpawnAction) {
		[oo::ToObjC(this) doScriptEvent:OOJSID("effectSpawned")];
		_haveExecutedSpawnAction = true;
	}

	::Entity *se = nil;
	for (const auto &seRef : SubEntitiesOf(_subEntities))
	{
		se = seRef.get();
		[se update:delta_t];
	}
}


bool OOVisualEffectEntity::isBreakPattern()
{
	return isImmuneToBreakPatternHide;
}


void OOVisualEffectEntity::setIsBreakPattern(bool bp)
{
	isImmuneToBreakPatternHide = bp;
}


oo::PList OOVisualEffectEntity::effectInfoDictionary()
{
	return effectinfoDictionary;
}


// (SubEntityRelationship) a slightly misnamed test now things other than ships can have subents
bool OOVisualEffectEntity::isShipWithSubEntityShip(::Entity *other)
{
	assert (getIsVisualEffect());

	if (![other isVisualEffect])  return false;
	if (![other isSubEntity])  return false;
	if ([other owner] != oo::ToObjC(this))  return false;

#ifndef NDEBUG
	// Sanity check; this should always be true.
	if (!hasSubEntity((::OOVisualEffectEntity *)other))
	{
		OO_LOG_ERR("visualeffect.subentity.sanityCheck.failed", "{} thinks it's a subentity of {}, but the supposed parent does not agree. {}", oo::ShortDescriptionOf(other), oo::ShortDescriptionOf(oo::ToObjC(this)), "This is an internal error, please report it.");
		[other setOwner:nil];
		return false;
	}
#endif

	return true;
}

}	// namespace cxx


// Slice 2 of docs/phases/3-slices/OOVisualEffectEntity.md (scanner colours, the script and its events,
// the beacons and the shader uniforms): still Objective-C, a category of the façade declared in
// OOVisualEffectEntity+ObjCBridge.h, reading the state through oo::ToCxx(self) (amendment oo-dnbf
// item 2) until its bead.
@implementation OOVisualEffectEntity (OOVisualEffectEntityScripting)



- (OOColor *)scannerDisplayColor1
{
	return [[oo::ToCxx(self)->scanner_display_color1 retain] autorelease];
}


- (OOColor *)scannerDisplayColor2
{
	return [[oo::ToCxx(self)->scanner_display_color2 retain] autorelease];
}


- (void)setScannerDisplayColor1:(OOColor *)color
{
	DESTROY(oo::ToCxx(self)->scanner_display_color1);
	
	if (color == nil)  color = [OOColor cxx_colorWithDescription:ValueForKey(oo::ToCxx(self)->effectinfoDictionary, "scanner_display_color1")];
	oo::ToCxx(self)->scanner_display_color1 = [color retain];
}


- (void)setScannerDisplayColor2:(OOColor *)color
{
	DESTROY(oo::ToCxx(self)->scanner_display_color2);
	
	if (color == nil)  color = [OOColor cxx_colorWithDescription:ValueForKey(oo::ToCxx(self)->effectinfoDictionary, "scanner_display_color2")];
	oo::ToCxx(self)->scanner_display_color2 = [color retain];
}

static GLfloat default_color[4] =	{ 0.0, 0.0, 0.0, 0.0};
static GLfloat scripted_color[4] = 	{ 0.0, 0.0, 0.0, 0.0};

- (GLfloat *) scannerDisplayColorForShip:(BOOL)flash :(OOColor *)scannerDisplayColor1 :(OOColor *)scannerDisplayColor2
{
	
	if (scannerDisplayColor1 || scannerDisplayColor2)
	{
		if (scannerDisplayColor1 && !scannerDisplayColor2)
		{
			[scannerDisplayColor1 getRed:&scripted_color[0] green:&scripted_color[1] blue:&scripted_color[2] alpha:&scripted_color[3]];
		}
		
		if (!scannerDisplayColor1 && scannerDisplayColor2)
		{
			[scannerDisplayColor2 getRed:&scripted_color[0] green:&scripted_color[1] blue:&scripted_color[2] alpha:&scripted_color[3]];
		}
		
		if (scannerDisplayColor1 && scannerDisplayColor2)
		{
			if (flash)
				[scannerDisplayColor1 getRed:&scripted_color[0] green:&scripted_color[1] blue:&scripted_color[2] alpha:&scripted_color[3]];
			else
				[scannerDisplayColor2 getRed:&scripted_color[0] green:&scripted_color[1] blue:&scripted_color[2] alpha:&scripted_color[3]];
		}
		
		return scripted_color;
	}

	return default_color; // transparent black if not specified
}


/* scripting */

- (void) setScript:(const std::optional<std::string> &)script_name
{
	oo::PList::Dict propertyList;
	propertyList["visualEffect"] = oo::PListObject(self);
	const oo::PList properties(std::move(propertyList));

	[oo::ToCxx(self)->script autorelease];
	oo::ToCxx(self)->script = [OOScript cxx_jsScriptFromFileNamed:script_name.value_or(std::string()) properties:properties];
	// does not support legacy scripting
	if (oo::ToCxx(self)->script == nil) {
		oo::ToCxx(self)->script = [OOScript cxx_jsScriptFromFileNamed:"oolite-default-effect-script.js" properties:properties];
	}
	[oo::ToCxx(self)->script retain];
}


- (OOJSScript *)script
{
	return oo::ToCxx(self)->script;
}


- (oo::PList)scriptInfo
{
	return oo::ToCxx(self)->scriptInfo ? oo::ToCxx(self)->scriptInfo : oo::PList(oo::PList::Dict{});
}

// unlikely to need events with arguments
- (void) doScriptEvent:(ooscript::PropertyId)message
{
	ooscript::Context context = OOJSAcquireContext();
	[oo::ToCxx(self)->script callMethod:message inContext:context withArguments:NULL count:0 result:NULL];
	OOJSRelinquishContext(context);
}


- (void) remove
{
	[self doScriptEvent:OOJSID("effectRemoved")];
	[UNIVERSE removeEntity:(Entity*)self];
}


/* beacons */

- (OOComparisonResult) compareBeaconCodeWith:(Entity<OOBeaconEntity> *) other
{
	return (OOComparisonResult)oo::str::caseInsensitiveCompare([self beaconCode].value_or(""), [other beaconCode].value_or(""));
}


- (std::optional<std::string>) beaconCode
{
	return oo::ToCxx(self)->_beaconCode;
}


// bcode: optional string; empty is treated as none. The Foundation version compared the new string with the
// old by pointer, so any new string (every string this class hands out is new) replaced it.
- (void) setBeaconCode:(const std::optional<std::string> &)bcode
{
	std::optional<std::string> code = bcode;
	if (code.has_value() && code->empty())  code.reset();

	if (code.has_value() || oo::ToCxx(self)->_beaconCode.has_value())
	{
		oo::ToCxx(self)->_beaconCode = code;

		DESTROY(oo::ToCxx(self)->_beaconDrawable);
	}
	// if not blanking code and label is currently blank, default label to code
	if (code.has_value() && (!oo::ToCxx(self)->_beaconLabel.has_value() || oo::ToCxx(self)->_beaconLabel->empty()))
	{
		[self setBeaconLabel:code];
	}

}


- (std::optional<std::string>) beaconLabel
{
	return oo::ToCxx(self)->_beaconLabel;
}


- (void) setBeaconLabel:(const std::optional<std::string> &)blabel
{
	std::optional<std::string> label = blabel;
	if (label.has_value() && label->empty())  label.reset();

	if (label.has_value() || oo::ToCxx(self)->_beaconLabel.has_value())
	{
		oo::ToCxx(self)->_beaconLabel = label.has_value() ? cxx_OOExpand(*label) : std::nullopt;
	}
}


- (BOOL) isBeacon
{
	return [self beaconCode].has_value();
}


- (id <OOHUDBeaconIcon>) beaconDrawable
{
	if (oo::ToCxx(self)->_beaconDrawable == nil)
	{
		const std::u16string	beaconCode = oo::utf8ToUtf16(oo::ToCxx(self)->_beaconCode.value_or(std::string()));
		NSUInteger	length = beaconCode.size();	// -length: UTF-16 units

		if (length > 1)
		{
			const oo::PList *iconEntry = [UNIVERSE cxx_descriptions]->find(*oo::ToCxx(self)->_beaconCode);
			const oo::PList iconData = (iconEntry != nullptr) ? *iconEntry : oo::PList();
			if (iconData.isArray())  oo::ToCxx(self)->_beaconDrawable = [[OOPolygonSprite alloc] initWithDataArray:iconData outlineWidth:0.5 name:*oo::ToCxx(self)->_beaconCode];
		}

		if (oo::ToCxx(self)->_beaconDrawable == nil)
		{
			if (length > 0)  oo::ToCxx(self)->_beaconDrawable = [[OOHUDBeaconCodeIcon alloc] initWithText:oo::utf16ToUtf8(beaconCode.substr(0, 1))];	// -substringToIndex:1
			else  oo::ToCxx(self)->_beaconDrawable = [[OOHUDBeaconCodeIcon alloc] initWithText:std::string()];
		}
	}
	
	return oo::ToCxx(self)->_beaconDrawable;
}


- (Entity <OOBeaconEntity> *) prevBeacon
{
	return [oo::ToCxx(self)->_prevBeacon weakRefUnderlyingObject];
}


- (Entity <OOBeaconEntity> *) nextBeacon
{
	return [oo::ToCxx(self)->_nextBeacon weakRefUnderlyingObject];
}


- (void) setPrevBeacon:(Entity <OOBeaconEntity> *)beaconShip
{
	if (beaconShip != [self prevBeacon])
	{
		[oo::ToCxx(self)->_prevBeacon release];
		oo::ToCxx(self)->_prevBeacon = [beaconShip weakRetain];
	}
}


- (void) setNextBeacon:(Entity <OOBeaconEntity> *)beaconShip
{
	if (beaconShip != [self nextBeacon])
	{
		[oo::ToCxx(self)->_nextBeacon release];
		oo::ToCxx(self)->_nextBeacon = [beaconShip weakRetain];
	}
}


- (BOOL) isJammingScanning 
{
	return NO;
}


/* Shader bindable uniforms */

// no automatic change of this, but simplifies use of default shader
- (GLfloat)hullHeatLevel
{
	return oo::ToCxx(self)->_hullHeatLevel;
}


- (void)setHullHeatLevel:(GLfloat)value
{
	oo::ToCxx(self)->_hullHeatLevel = OOClamp_0_1_f(value);
}


- (GLfloat) shaderFloat1 
{
	return oo::ToCxx(self)->_shaderFloat1;
}


- (void)setShaderFloat1:(GLfloat)value
{
	oo::ToCxx(self)->_shaderFloat1 = value;
}


- (GLfloat) shaderFloat2 
{
	return oo::ToCxx(self)->_shaderFloat2;
}


- (void)setShaderFloat2:(GLfloat)value
{
	oo::ToCxx(self)->_shaderFloat2 = value;
}


- (int) shaderInt1 
{
	return oo::ToCxx(self)->_shaderInt1;
}


- (void)setShaderInt1:(int)value
{
	oo::ToCxx(self)->_shaderInt1 = value;
}


- (int) shaderInt2 
{
	return oo::ToCxx(self)->_shaderInt2;
}


- (void)setShaderInt2:(int)value
{
	oo::ToCxx(self)->_shaderInt2 = value;
}


- (Vector) shaderVector1 
{
	return oo::ToCxx(self)->_shaderVector1;
}


- (void)setShaderVector1:(Vector)value
{
	oo::ToCxx(self)->_shaderVector1 = value;
}


- (Vector) shaderVector2 
{
	return oo::ToCxx(self)->_shaderVector2;
}


- (void)setShaderVector2:(Vector)value
{
	oo::ToCxx(self)->_shaderVector2 = value;
}


@end
