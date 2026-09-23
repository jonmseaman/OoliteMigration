/*

OOJSGuiScreenKeyDefinition.m


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

#import "OOJSGuiScreenKeyDefinition.h"
//#import "OOJavaScriptEngine.h"

#include "ooscript/JSEngine.hpp"

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) per bead oo-6u8, the same way bead oo-sdz
	retargeted OOJSVector.mm (the exemplar for this sweep; see its header comment for the full
	rationale). This file only directly called the two RemoveValueRoot / RemoveObjectRoot
	engine functions (ooscript/README.md's retarget map); OOJSAddGCValueRoot /
	OOJSAddGCObjectRoot are OOJS_*-spelled macros from OOJavaScriptEngine.h, not themselves
	spelled with the engine's own prefix at this call site, and are unchanged, out of scope for
	the sweep exactly as OOJSVector.mm's header comment describes for the OOJS_*
	argument-marshalling macros. `this` is not used here, so no reserved-word renames were
	needed; the file is still built as Objective-C++ (ADR-0001) because it now names the
	ooscript:: namespace.
*/

namespace ooscript { }
using ooscript::Context;
using ooscript::Value;
using ooscript::Object;

// Byte-identical façade <-> jsapi views, local to this call site (JSEngine.hpp: Value/Object are
// byte copies of ooscript::Value/ooscript::Object ; see OOJSVector.mm for the same, non-exported, pattern).
namespace {
static inline Object  *OOJSFOBJP(ooscript::Object *o)     { return reinterpret_cast<Object*>(o); }
} // namespace


@implementation OOJSGuiScreenKeyDefinition

- (id) init {
	self = [super init];
	_callback = ooscript::undefinedValue();
	_callbackThis = NULL;

	_owningScript = [[OOJSScript currentlyRunningScript] weakRetain];

	[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(deleteJSPointers)
												 name:kOOJavaScriptEngineWillResetNotification
											   object:[OOJavaScriptEngine sharedEngine]];

	return self;
}

- (void) deleteJSPointers
{

	ooscript::Context context = OOJSAcquireContext();
	_callback = ooscript::undefinedValue();
	_callbackThis = NULL;
	ooscript::removeValueRoot((context), (&_callback));
	ooscript::removeObjectRoot((context), OOJSFOBJP(&_callbackThis));

	OOJSRelinquishContext(context);

	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:kOOJavaScriptEngineWillResetNotification
												  object:[OOJavaScriptEngine sharedEngine]];

}

- (void) dealloc 
{
	[_owningScript release];

	[self deleteJSPointers];

	[super dealloc];
}

- (NSString *)name 
{
	return _name;
}


- (void)setName:(NSString *)name
{
	[_name autorelease];
	_name = [name retain];
}


- (NSDictionary *)registerKeys
{
	return _registerKeys;
}


- (void)setRegisterKeys:(NSDictionary *)registerKeys
{
	[_registerKeys release];
	_registerKeys = [registerKeys copy];
}


- (ooscript::Value)callback
{
	return _callback;
}


- (void)setCallback:(ooscript::Value)callback
{
	ooscript::Context context = OOJSAcquireContext();
	ooscript::removeValueRoot((context), (&_callback));
	_callback = callback;
	OOJSAddGCValueRoot(context, &_callback, "OOJSGuiScreenKeyDefinition callback function");
	OOJSRelinquishContext(context);
}


- (ooscript::Object)callbackThis
{
	return _callbackThis;
}


- (void)setCallbackThis:(ooscript::Object)callbackThis
{
	ooscript::Context context = OOJSAcquireContext();
	ooscript::removeObjectRoot((context), OOJSFOBJP(&_callbackThis));
	_callbackThis = callbackThis;
	OOJSAddGCObjectRoot(context, &_callbackThis, "OOJSGuiScreenKeyDefinition callback this");
	OOJSRelinquishContext(context);
}


- (void)runCallback:(NSString *)key
{
	OOJavaScriptEngine *engine = [OOJavaScriptEngine sharedEngine];
	ooscript::Context context = OOJSAcquireContext();		
	ooscript::Value					rval = ooscript::undefinedValue();

	ooscript::Value         cKey = OOJSValueFromNativeObject(context, key);

	OOJSScript *owner = [_owningScript retain]; // local copy needed
	[OOJSScript pushScript:owner];
	
	[engine callJSFunction:_callback
				 forObject:_callbackThis
					  argc:1
					  argv:&cKey
					result:&rval];
	
	[OOJSScript popScript:owner];
	[owner release];

	OOJSRelinquishContext(context);
}


- (NSComparisonResult)interfaceCompare:(OOJSGuiScreenKeyDefinition *)other
{
    return [_name caseInsensitiveCompare:[other name]];
}

@end
