/*

OOJSMissionVariables.h

JavaScript mission variables object.


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

#import "OOJSMissionVariables.h"
#import "OOJavaScriptEngine.h"
#import "OOIsNumberLiteral.h"

#import "OOJSPlayer.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar; see also OOJSClock.mm): the class dispatch table becomes a
	static ooscript::ClassDef (the stub hooks are nullptr), the class-creation call becomes
	ooscript::defineObject, the property-name-to-id call in the enumerate hook becomes
	ooscript::valueToId, and the directly spelled numeric-conversion call becomes
	ooscript::newNumberValue. `this` is renamed to `thisObj` because it is a reserved word once
	this file compiles as Objective-C++ (ADR-0001). The class hooks (delProperty, getProperty,
	setProperty) and the new-enumerate protocol hook now take the façade's Context/Object/
	PropertyId/Value signature instead of the engine's; a tiny shim at the top of each recovers
	the old JSContext/JSObject/jsid/jsval locals so the rest of each function body (including
	OOJS_NATIVE_ENTER/EXIT) is UNCHANGED, because ooscript::Value and ooscript::PropertyId are
	byte copies of jsval and jsid (JSEngine.hpp's own contract, verified by the backend's static
	asserts).
*/
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;
using ooscript::EnumerateOp;

// Byte-identical façade <-> jsapi views, local to this call site (see OOJSVector.mm).
namespace {
static inline Context    OOJSFCX(JSContext *cx)   { return reinterpret_cast<Context>(cx); }
} // namespace
namespace {
static inline JSContext *OOJSRCX(Context cx)      { return reinterpret_cast<JSContext*>(cx); }
} // namespace
namespace {
static inline Object     OOJSFOBJ(JSObject *o)    { return reinterpret_cast<Object>(o); }
} // namespace
namespace {
static inline JSObject  *OOJSROBJ(Object o)       { return reinterpret_cast<JSObject*>(o); }
} // namespace
namespace {
static inline jsval     *OOJSRVAL(Value *v)       { return reinterpret_cast<jsval*>(v); }
} // namespace
namespace {
static inline Value      OOJSFVAL(jsval v)        { Value r; std::memcpy(&r, &v, sizeof r); return r; }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace
namespace {
static inline PropertyId *OOJSFJSIDP(jsid *id)    { return reinterpret_cast<PropertyId*>(id); }
} // namespace


namespace {
static NSString *KeyForPropertyID(JSContext *context, jsid propID)
{
	NSCParameterAssert(JSID_IS_STRING(propID));
	
	NSString *key = OOStringFromJSString(context, JSID_TO_STRING(propID));
	if ([key hasPrefix:@"_"])  return nil;
	return [@"mission_" stringByAppendingString:key];
}
} // namespace


namespace {
static bool MissionVariablesDeleteProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool MissionVariablesGetProperty(Context cx, Object obj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool MissionVariablesSetProperty(Context cx, Object obj, PropertyId propID, bool strict, Value *value);
} // namespace
namespace {
static bool MissionVariablesEnumerate(Context cx, Object obj, EnumerateOp enumOp, Value *state, PropertyId *idp);
} // namespace

#ifndef NDEBUG
namespace {
static id MissionVariablesConverter(JSContext *context, JSObject *object);
} // namespace
#endif


namespace {
static ClassDef sMissionVariablesClass =
{
	"MissionVariables",
	ClassFlag::NewEnumerate,
	
	nullptr,							// addProperty (engine default: PropertyStub)
	MissionVariablesDeleteProperty,	// delProperty
	MissionVariablesGetProperty,		// getProperty
	MissionVariablesSetProperty,		// setProperty
	nullptr,							// enumerate (JSCLASS_NEW_ENUMERATE: newEnumerate used instead)
	MissionVariablesEnumerate,			// newEnumerate
	nullptr,							// resolve (engine default: ResolveStub)
	nullptr,							// convert (engine default: ConvertStub)
	nullptr,							// finalize (engine default: FinalizeStub)
	nullptr,							// call
	nullptr,							// construct
	nullptr,							// backend: owned by the façade backend, must start null
};
} // namespace


// The engine's own JSClass* for sMissionVariablesClass, for the not-yet-retargeted
// OOJSRegisterObjectConverter (OOJavaScriptEngine.h) that still takes a JSClass*. ClassDef's
// `backend` slot is a BackendClass* whose first member is the real JSClass
// (JSEngine_spidermonkey.cpp), and it is filled in by ooscript::defineObject() before
// InitOOJSMissionVariables() registers the converter (see OOJSWaypoint.mm's
// RawWaypointClass for the same pattern).
namespace {
static inline JSClass *RawMissionVariablesClass(void)
{
	return reinterpret_cast<JSClass*>(sMissionVariablesClass.backend);
}
} // namespace


void InitOOJSMissionVariables(JSContext *context, JSObject *global)
{
	ooscript::defineObject(OOJSFCX(context), OOJSFOBJ(global), "missionVariables", &sMissionVariablesClass, nullptr, PropertyFlag::ReadOnly);
	
#ifndef NDEBUG
	// Allow callObjC() on missionVariables to call methods on the mission variables dictionary.
	OOJSRegisterObjectConverter(RawMissionVariablesClass(), MissionVariablesConverter);
#endif
}


#ifndef NDEBUG
namespace {
static id MissionVariablesConverter(JSContext *context, JSObject *object)
{
	(void)context;
	(void)object;
	return [PLAYER missionVariables];
}
} // namespace
#endif


namespace {
static bool MissionVariablesDeleteProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsid jsPropID = OOJSRJSID(propID);
	(void)thisObj;
	(void)value;
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity				*player = OOPlayerForScripting();
	
	if (JSID_IS_STRING(jsPropID))
	{
		NSString *key = KeyForPropertyID(context, jsPropID);
		[player setMissionVariable:nil forKey:key];
	}
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool MissionVariablesGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsid jsPropID = OOJSRJSID(propID);
	jsval *jsvalue = OOJSRVAL(value);
	(void)thisObj;
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity				*player = OOPlayerForScripting();
	
	if (JSID_IS_STRING(jsPropID))
	{
		NSString *key = KeyForPropertyID(context, jsPropID);
		if (key == nil)  return YES;
		
		id mvar = [player missionVariableForKey:key];
		
		if ([mvar isKindOfClass:[NSString class]])	// Currently there should only be strings, but we may want to change this.
		{
			if (OOIsNumberLiteral(mvar, YES))
			{
				return ooscript::newNumberValue(cx, [mvar doubleValue], value);
			}
		}
		
		*jsvalue = OOJSValueFromNativeObject(context, mvar);
	}
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool MissionVariablesSetProperty(Context cx, Object obj, PropertyId propID, bool /*strict*/, Value *value)
{
	JSContext *context = OOJSRCX(cx);
	JSObject *thisObj = OOJSROBJ(obj);
	jsid jsPropID = OOJSRJSID(propID);
	jsval *jsvalue = OOJSRVAL(value);
	(void)thisObj;
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity				*player = OOPlayerForScripting();
	
	if (JSID_IS_STRING(jsPropID))
	{
		NSString *key = KeyForPropertyID(context, jsPropID);
		if (key == nil)
		{
			OOJSReportError(context, @"Invalid mission variable name \"%@\".", [OOStringFromJSID(jsPropID) escapedForJavaScriptLiteral]);
			return NO;
		}
		
		NSString *objValue = OOStringFromJSValue(context, *jsvalue);
		
		if ([objValue isKindOfClass:[NSNull class]])  objValue = nil;
		[player setMissionVariable:objValue forKey:key];
	}
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool MissionVariablesEnumerate(Context cx, Object obj, EnumerateOp enumOp, Value *state, PropertyId *idp)
{
	JSContext *context = OOJSRCX(cx);
	JSObject *object = OOJSROBJ(obj);
	jsval *jsstate = OOJSRVAL(state);
	jsid *jsidp = idp != NULL ? reinterpret_cast<jsid*>(idp) : NULL;
	(void)object;
	
	OOJS_NATIVE_ENTER(context)
	
	NSEnumerator *enumerator = nil;
	
	switch (enumOp)
	{
		case EnumerateOp::Init:
		case EnumerateOp::InitAll:	// For ES5 Object.getOwnPropertyNames(). Since we have no non-enumerable properties, this is the same as _INIT.
		{
			// -allKeys implicitly makes a copy, which is good since the enumerating code might mutate.
			NSArray *mvars = [[PLAYER missionVariables] allKeys];
			enumerator = [[mvars objectEnumerator] retain];
			*jsstate = PRIVATE_TO_JSVAL(enumerator);
			
			NSUInteger count = [mvars count];
			assert(count <= INT32_MAX);
			if (jsidp != NULL)  *jsidp = INT_TO_JSID((uint32_t)count);
			return YES;
		}
		
		case EnumerateOp::Next:
		{
			enumerator = (NSEnumerator*)JSVAL_TO_PRIVATE(*jsstate);
			for (;;)
			{
				NSString *next = [enumerator nextObject];
				if (next == nil)  break;
				if (![next hasPrefix:@"mission_"])  continue;	// Skip mission instructions, which aren't visible through missionVariables.
				
				next = [next substringFromIndex:8];		// Cut off "mission_".
				
				jsval val = [next oo_jsValueInContext:context];
				return ooscript::valueToId(cx, OOJSFVAL(val), OOJSFJSIDP(jsidp));
			}
			
			// If we got here, we've hit the end of the enumerator.
			*jsstate = JSVAL_NULL;
			// Fall through.
		}
		
		case EnumerateOp::Destroy:
		{
			if (enumerator == nil && JSVAL_IS_DOUBLE(*jsstate))
			{
				enumerator = (NSEnumerator*)JSVAL_TO_PRIVATE(*jsstate);
			}
			[enumerator release];
			
			if (jsidp != NULL)  *jsidp = JSID_VOID;
			return YES;
		}
	}
	
	OOJS_NATIVE_EXIT
}
} // namespace
