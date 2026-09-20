/*

OOJSWorldScripts.mm


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

#import "OOJSWorldScripts.h"
#import "OOJavaScriptEngine.h"
#import "PlayerEntity.h"
#import "OOJSPlayer.h"

#include "ooscript/JSEngine.hpp"
#include <cstring>

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) per the OOJSVector.mm exemplar (bead
	oo-sdz): the class dispatch table (PropertyStub / StrictPropertyStub / ResolveStub /
	ConvertStub / FinalizeStub) is replaced by nullptr hooks in ooscript::ClassDef, and the two
	directly-spelled engine calls (DefineObject, DefineProperty) go through the façade. The hook
	functions (WorldScriptsGetProperty, WorldScriptsEnumerate) take the façade's hook signature
	(ooscript::Context / Object / PropertyId) rather than the engine's; a tiny shim at the top of
	each recovers the old JSContext pointer and jsid/jsval locals so the OOJS_* macros and the
	rest of each function body are UNCHANGED, because ooscript::Value and ooscript::PropertyId are
	byte copies of jsval and jsid (JSEngine.hpp's own contract). `this` is renamed to `thisObj`
	because it is a reserved word once this file compiles as Objective-C++ (ADR-0001).
*/

namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;
using ooscript::ClassDef;
using ooscript::ClassFlag;
using ooscript::PropertyFlag;

// Byte-identical façade <-> jsapi views, local to this call site (JSEngine.hpp: Value/PropertyId
// are byte copies of jsval/jsid; see OOJSVector.mm's OOJSFCX/OOJSRCX/OOJSRJSID for the same,
// non-exported, pattern).
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
static inline jsval     *OOJSRVAL(Value *v)       { return reinterpret_cast<jsval*>(v); }
} // namespace
namespace {
static inline jsid       OOJSRJSID(PropertyId id) { jsid r; std::memcpy(&r, &id, sizeof r); return r; }
} // namespace


namespace {
static bool WorldScriptsGetProperty(Context context, Object thisObj, PropertyId propID, Value *value);
} // namespace
namespace {
static bool WorldScriptsEnumerate(Context cx, Object obj);
} // namespace


static const PropertyFlag kWorldScriptsObjectFlags = PropertyFlag::ReadOnly | PropertyFlag::Enumerate | PropertyFlag::Permanent;
static const PropertyFlag kWorldScriptsPropertyFlags = PropertyFlag::ReadOnly | PropertyFlag::Shared | PropertyFlag::Permanent | PropertyFlag::Enumerate;


namespace {
static ClassDef sWorldScriptsClass =
{
	"WorldScripts",
	ClassFlag::None,

	nullptr,				// addProperty (engine default: PropertyStub)
	nullptr,				// delProperty (engine default: PropertyStub)
	WorldScriptsGetProperty,	// getProperty
	nullptr,				// setProperty (engine default: StrictPropertyStub)
	WorldScriptsEnumerate,	// enumerate
	nullptr,				// newEnumerate (JSCLASS_NEW_ENUMERATE not used)
	nullptr,				// resolve (engine default: ResolveStub)
	nullptr,				// convert (engine default: ConvertStub)
	nullptr,				// finalize (engine default: FinalizeStub)
	nullptr,				// call
	nullptr,				// construct
	nullptr,				// backend: owned by the façade backend, must start null
};
} // namespace


void InitOOJSWorldScripts(JSContext *context, JSObject *global)
{
	ooscript::defineObject(OOJSFCX(context), OOJSFOBJ(global), "worldScripts", &sWorldScriptsClass, nullptr, kWorldScriptsObjectFlags);
}


namespace {
static bool WorldScriptsGetProperty(Context cx, Object obj, PropertyId propID, Value *value)
{
	JSContext *context = OOJSRCX(cx);
	jsid jsPropID = OOJSRJSID(propID);
	jsval *jsValue = OOJSRVAL(value);
	(void)obj;
	
	OOJS_NATIVE_ENTER(context)
	
	PlayerEntity				*player = OOPlayerForScripting();
	NSString					*scriptName = nil;
	id							script = nil;
	
	if (!JSID_IS_STRING(jsPropID))  return YES;
	scriptName = OOStringFromJSString(context, JSID_TO_STRING(jsPropID));
	
	if (scriptName != nil)
	{
		script = [[player worldScriptsByName] objectForKey:scriptName];
		if (script != nil)
		{
			/*	If script is an OOJSScript, this should return a JS Script
				object. For other OOScript subclasses, it will return
				JSVAL_NULL. If no script exists, the value will be
				JSVAL_VOID.
			*/
			*jsValue = [script oo_jsValueInContext:context];
		}
		else
		{
			*jsValue = JSVAL_VOID;
		}

	}
	
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace


namespace {
static bool WorldScriptsEnumerate(Context cx, Object obj)
{
	JSContext *context = OOJSRCX(cx);
	
	OOJS_NATIVE_ENTER(context)
	
	/*	In order to support enumeration of world scripts (e.g.,
		for (name in worldScripts) { ... }), define each property on demand.
		Since world scripts cannot be deleted, we don't need to worry about
		that case (as in OOJSMissionVariables).
		
		Since WorldScriptsGetProperty() will be called for each access anyway,
		we define the value as null here.
	*/
	
	NSArray					*names = nil;
	NSString				*name = nil;
	
	names = [OOPlayerForScripting() worldScriptNames];
	
	foreach (name, names)
	{
		Value nullVal = ooscript::nullValue();
		if (!ooscript::defineProperty(cx, obj, [name UTF8String], nullVal, WorldScriptsGetProperty, nullptr, kWorldScriptsPropertyFlags))  return NO;
	}
	
	return YES;
	
	OOJS_NATIVE_EXIT
}
} // namespace
