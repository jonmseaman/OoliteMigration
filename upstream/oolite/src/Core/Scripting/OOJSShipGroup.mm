/*

OOShipGroup.m


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

#import "OOShipGroup.h"
#import "OOJSShipGroup.h"
#import "OOJavaScriptEngine.h"
#import "OOShipGroup.h"
#import "Universe.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar): the class dispatch table becomes a static ooscript::ClassDef
	(the stub hooks are nullptr), InitClass becomes ooscript::initClass, and the directly
	spelled construction-check, object-construction and private-storage calls become
	ooscript::isConstructing (via CallArgs), ooscript::newObject and ooscript::setPrivate.
	`this` is renamed to `thisObj` because it is a reserved word once this file compiles as
	Objective-C++ (ADR-0001).

	ShipGroup has its own private-object getter (originally built by DEFINE_JS_OBJECT_GETTER(),
	OOJavaScriptEngine.h) the way OOJSSoundSource.mm's JSSoundSourceGetSoundSource does; it checks
	against &sShipGroupClass, the same ooscript::ClassDef that ooscript::getClass() reports.

	The finalizer (OOJSObjectWrapperFinalize) and toString() (OOJSObjectWrapperToString) are the
	shared natives, which already take the façade signatures and go into the tables directly.
*/
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::CallArgs;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::PropertySpec;
using ooscript::FunctionSpec;

// Byte-identical façade <-> jsapi views, local to this call site (see OOJSVector.mm).


namespace {
static ooscript::Object sShipGroupPrototype;
} // namespace


namespace {
static bool ShipGroupGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool ShipGroupSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
namespace {
static bool ShipGroupConstruct(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace

// Methods
namespace {
static bool ShipGroupAddShip(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool ShipGroupRemoveShip(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace
namespace {
static bool ShipGroupContainsShip(ooscript::Context cx, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
static ClassDef sShipGroupClass =
{
	"ShipGroup",
	ClassFlag::HasPrivate,

	nullptr,				// addProperty (engine default: PropertyStub)
	nullptr,				// delProperty (engine default: PropertyStub)
	ShipGroupGetProperty,	// getProperty
	ShipGroupSetProperty,	// setProperty
	nullptr,				// enumerate (engine default: EnumerateStub)
	nullptr,				// newEnumerate (ooscript::ClassFlag::NewEnumerate not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	OOJSObjectWrapperFinalize,		// finalize
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


enum : std::uint8_t
{
	// Property IDs
	kShipGroup_ships,			// array of ships, double, read-only
	kShipGroup_leader,			// leader, Ship, read/write
	kShipGroup_name,			// name, string, read/write
	kShipGroup_count,			// number of ships, integer, read-only
};


namespace {
static PropertySpec sShipGroupProperties[] =
{
	// JS name					ID							flags										getter	setter
	{ "count",					kShipGroup_count,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ "leader",					kShipGroup_leader,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "name",					kShipGroup_name,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::Shared,	nullptr, nullptr },
	{ "ships",					kShipGroup_ships,			PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly | PropertyFlag::Shared, nullptr, nullptr },
	{ 0 }
};
} // namespace


// A raw jsapi mirror of sShipGroupProperties, used only for the two bad-property error
// reporters in OOJavaScriptEngine.m (OOJSReportBadPropertySelector/Value): those helpers are
// outside this bead's scope (shared across every binding file) and still take a
// ooscript::PropertySpec*, not ooscript::PropertySpec* (see OOJSVector.mm's sVectorPropertiesRaw).
namespace {
static ooscript::PropertySpec sShipGroupPropertiesRaw[] =
{
	// JS name					ID							flags
	{ "count",					kShipGroup_count,			OOJS_PROP_READONLY_CB },
	{ "leader",					kShipGroup_leader,			OOJS_PROP_READWRITE_CB },
	{ "name",					kShipGroup_name,			OOJS_PROP_READWRITE_CB },
	{ "ships",					kShipGroup_ships,			OOJS_PROP_READONLY_CB },
	{ 0 }
};
} // namespace


namespace {
static FunctionSpec sShipGroupMethods[] =
{
	// JS name					Function					min args	flags
	{ "toString",				OOJSObjectWrapperToString,			0,			0 },
	{ "addShip",				ShipGroupAddShip,			1,			0 },
	{ "containsShip",			ShipGroupContainsShip,		1,			0 },
	{ "removeShip",				ShipGroupRemoveShip,		1,			0 },
	{ 0 }
};
} // namespace


// Equivalent of DEFINE_JS_OBJECT_GETTER(JSShipGroupGetShipGroup, &sShipGroupClass,
// sShipGroupPrototype, OOShipGroup), kept hand-written (see the file-top comment and
// OOJSSoundSource.mm's JSSoundSourceGetSoundSource).
namespace {
#ifndef NDEBUG
static BOOL JSShipGroupGetShipGroup(ooscript::Context context, ooscript::Object inObject, OOShipGroup **outObject)  GCC_ATTR((unused));
static BOOL JSShipGroupGetShipGroup(ooscript::Context context, ooscript::Object inObject, OOShipGroup **outObject)
{
	NSCParameterAssert(outObject != NULL);
	static Class cls = Nil;
	if (EXPECT_NOT(cls == Nil))  cls = [OOShipGroup class];
	return OOJSObjectGetterImplPRIVATE(context, inObject, &sShipGroupClass, cls, "JSShipGroupGetShipGroup", (id *)outObject);
}
#else
OOINLINE BOOL JSShipGroupGetShipGroup(ooscript::Context context, ooscript::Object inObject, OOShipGroup **outObject)
{
	return OOJSObjectGetterImplPRIVATE(context, inObject, &sShipGroupClass, (id *)outObject);
}
#endif
} // namespace


// *** Public ***

void InitOOJSShipGroup(ooscript::Context context, ooscript::Object global)
{
	Object proto = ooscript::initClass((context), (global), nullptr, &sShipGroupClass,
										ShipGroupConstruct, 0, sShipGroupProperties, sShipGroupMethods,
										nullptr, nullptr);
	sShipGroupPrototype = (proto);
	OOJSRegisterObjectConverter(&sShipGroupClass, OOJSBasicPrivateObjectConverter);
}


namespace {
static bool ShipGroupGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;

	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);

	OOJS_NATIVE_ENTER(context)

	OOShipGroup				*group = nil;
	id						result = nil;

	if (EXPECT_NOT(!JSShipGroupGetShipGroup(context, thisObj, &group)))  return NO;

	switch (ooscript::idToInt32(propID))
	{
		case kShipGroup_ships:
			result = [group memberArray];
			if (result == nil)  result = [NSArray array];
			break;
			
		case kShipGroup_leader:
			result = [group leader];
			break;
			
		case kShipGroup_name:
			result = [group name];
			if (result == nil)  result = [NSNull null];
			break;
			
		case kShipGroup_count:
			return ooscript::newNumberValue(cx, [group count], value);
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sShipGroupPropertiesRaw);
			return NO;
	}
	
	*value = (OOJSValueFromNativeObject(context, result));
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool ShipGroupSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	if (!ooscript::isInt32Id(propID))  return YES;

	ooscript::Context context = (cx);
	ooscript::Object thisObj = (obj);

	OOJS_NATIVE_ENTER(context)

	OOShipGroup				*group = nil;
	ShipEntity				*shipValue = nil;

	if (EXPECT_NOT(!JSShipGroupGetShipGroup(context, thisObj, &group)))  return NO;

	switch (ooscript::idToInt32(propID))
	{
		case kShipGroup_leader:
			shipValue = OOJSNativeObjectOfClassFromJSValue(context, *(value), [ShipEntity class]);
			if (shipValue != nil || ooscript::isNull(*value))
			{
				[group setLeader:shipValue];
				return YES;
			}
			break;
			
		case kShipGroup_name:
			[group setName:OOStringFromJSValueEvenIfNull(context, *(value))];
			return YES;
			break;
			
		default:
			OOJSReportBadPropertySelector(context, thisObj, (propID), sShipGroupPropertiesRaw);
			return NO;
	}
	
	OOJSReportBadPropertyValue(context, thisObj, (propID), sShipGroupPropertiesRaw, *(value));
	return NO;
	
	OOJS_NATIVE_EXIT
}
} // namespace


// new ShipGroup([name : String [, leader : Ship]]) : ShipGroup
namespace {
static bool ShipGroupConstruct(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(!oojsArgs.isConstructing()))
	{
		OOJSReportError(context, @"ShipGroup() cannot be called as a function, it must be used as a constructor (as in new ShipGroup(...)).");
		return NO;
	}
	
	NSString				*name = nil;
	ShipEntity				*leader = nil;
	
	if (oojsArgs.count() >= 1)
	{
		if (!ooscript::isString(OOJS_ARGV[0]))
		{
			OOJSReportBadArguments(context, nil, @"ShipGroup()", 1, OOJS_ARGV, @"Could not create ShipGroup", @"group name");
			return NO;
		}
		name = OOStringFromJSValue(context, OOJS_ARGV[0]);
	}
	
	if (oojsArgs.count() >= 2)
	{
		leader = OOJSNativeObjectOfClassFromJSValue(context, OOJS_ARGV[1], [ShipEntity class]);
		if (leader == nil && !ooscript::isNull(OOJS_ARGV[1]))
		{
			OOJSReportBadArguments(context, nil, @"ShipGroup()", 1, OOJS_ARGV + 1, @"Could not create ShipGroup", @"ship");
			return NO;
		}
	}
	
	OOJS_RETURN_OBJECT([OOShipGroup groupWithName:name leader:leader]);
	
	OOJS_NATIVE_EXIT
}
} // namespace


@implementation OOShipGroup (OOJavaScriptExtensions)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	ooscript::Value					result = ooscript::nullValue();
	
	if (_jsSelf == NULL)
	{
		_jsSelf = (ooscript::newObject((context), &sShipGroupClass, (sShipGroupPrototype), nullptr));
		if (_jsSelf != NULL)
		{
			if (!ooscript::setPrivate((context), (_jsSelf), [self retain]))  _jsSelf = NULL;
		}
	}
	
	if (_jsSelf != NULL)  result = ooscript::objectValue(_jsSelf);
	
	return result;
}


- (void) oo_clearJSSelf:(ooscript::Object)selfVal
{
	if (_jsSelf == selfVal)  _jsSelf = NULL;
}

@end



// *** Methods ***

// addShip(ship : Ship)
namespace {
static bool ShipGroupAddShip(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	OOShipGroup				*thisGroup = nil;
	ShipEntity				*ship = nil;
	BOOL					OK = YES;
	
	if (EXPECT_NOT(!JSShipGroupGetShipGroup(context, OOJS_THIS, &thisGroup)))  return NO;
	
	if (oojsArgs.count() > 0)  ship = OOJSNativeObjectOfClassFromJSValue(context, OOJS_ARGV[0], [ShipEntity class]);
	if (ship == nil)
	{
		if (oojsArgs.count() > 0 && ooscript::isNull(OOJS_ARGV[0]))  OOJS_RETURN_VOID;	// OK, do nothing for null ship.
		
		OOJSReportBadArguments(context, @"ShipGroup", @"addShip", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"ship");
		return NO;
	}
	
	if ([thisGroup containsShip:ship])
	{
		// nothing to do...
		OOJS_RETURN_VOID;
	}
	else
	{
		ShipEntity				*thisGroupLeader = [thisGroup leader];
		
		if ([thisGroupLeader escortGroup] == thisGroup) // escort group!
		{
			if ([thisGroup count] > 1) // already with some escorts
			{
				OOShipGroup			*thatGroup = [ship group];
				if ([thatGroup count] > 1 && [[thatGroup leader] escortGroup] == thatGroup)	// new escort already escorting!
				{
					OOJSReportWarningForCaller(context, @"ShipGroup", @"addShip", @"Ship %@ cannot be assigned to two escort groups, ignoring.", ship);
					OK = NO;
				}
				else
				{
					OK = [thisGroupLeader acceptAsEscort:ship];
				}
			}
			else // [thisGroup count] == 1, default unescorted ship?
			{
				if ([thisGroupLeader escortGroup] == [thisGroupLeader group])
				{
					// Default unescorted, unescortable, ship. Create new group and use that instead.
					[thisGroupLeader setGroup:[[OOShipGroup alloc] initWithName:@"ship group"]];
					thisGroup = [thisGroupLeader group];
				}
				else
				{
					// Unescorted ship with custom group. See if it accepts escorts.
					OK = [thisGroupLeader acceptAsEscort:ship];
				}
			}
		}
		if (OK)
		{
			OOJS_RETURN_BOOL([thisGroup addShip:ship]);	// if ship is there already, noop & YES
		}
		else  OOJS_RETURN_BOOL(NO);
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace


// removeShip(ship : Ship)
namespace {
static bool ShipGroupRemoveShip(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	OOShipGroup				*thisGroup = nil;
	ShipEntity				*ship = nil;
	
	if (EXPECT_NOT(!JSShipGroupGetShipGroup(context, OOJS_THIS, &thisGroup)))  return NO;
	
	if (oojsArgs.count() > 0)  ship = OOJSNativeObjectOfClassFromJSValue(context, OOJS_ARGV[0], [ShipEntity class]);
	if (ship == nil)
	{
		if (oojsArgs.count() > 0 && ooscript::isNull(OOJS_ARGV[0]))  OOJS_RETURN_VOID;	// OK, do nothing for null ship.
		
		OOJSReportBadArguments(context, @"ShipGroup", @"removeShip", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"ship");
		return NO;
	}
	
	OOJS_RETURN_BOOL([thisGroup removeShip:ship]);
	
	OOJS_NATIVE_EXIT
}
} // namespace


// containsShip(ship : Ship) : Boolean
namespace {
static bool ShipGroupContainsShip(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{

	OOJS_NATIVE_ENTER(context)
	
	OOShipGroup				*thisGroup = nil;
	ShipEntity				*ship = nil;
	
	if (EXPECT_NOT(!JSShipGroupGetShipGroup(context, OOJS_THIS, &thisGroup)))  return NO;
	
	if (oojsArgs.count() > 0)  ship = OOJSNativeObjectOfClassFromJSValue(context, OOJS_ARGV[0], [ShipEntity class]);
	if (ship == nil)
	{
		if (oojsArgs.count() > 0 && ooscript::isNull(OOJS_ARGV[0]))  OOJS_RETURN_BOOL(NO); // OK, return false for null ship.
		
		OOJSReportBadArguments(context, @"ShipGroup", @"containsShip", MIN(oojsArgs.count(), 1U), OOJS_ARGV, nil, @"ship");
		return NO;
	}
	
	OOJS_RETURN_BOOL([thisGroup containsShip:ship]);
	
	OOJS_NATIVE_EXIT
}
} // namespace
