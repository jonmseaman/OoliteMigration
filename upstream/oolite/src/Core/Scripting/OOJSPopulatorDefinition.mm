/*

OOJSPopulatorDefinition.mm


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

#import "OOJSPopulatorDefinition.h"
#import "OOJavaScriptEngine.h"
#import "OOMaths.h"
#import "OOJSVector.h"

#include "ooscript/JSEngine.hpp"

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) per the OOJSVector.mm exemplar (bead
	oo-sdz): the two directly-spelled engine calls here (RemoveValueRoot, RemoveObjectRoot) go
	through ooscript:: instead of JS_*. OOJSAcquireContext/OOJSRelinquishContext/
	OOJSAddGCValueRoot/OOJSAddGCObjectRoot are OOJS_* macros, not JS_* calls, so they are
	untouched and out of scope for this bead (see JSEngine.hpp's own header comment and
	OOJSVector.mm's exemplar comment). The two byte-identical façade <-> jsapi view helpers
	below are local to this call site, exactly as OOJSVector.mm's OOJSFCX/OOJSFVALP/OOJSFOBJ
	family is local to it.
*/

namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;

namespace {
static inline Object   *OOJSFOBJP(ooscript::Object *o)     { return reinterpret_cast<Object*>(o); }
} // namespace


@implementation OOJSPopulatorDefinition

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

- (ooscript::Value)callback
{
	return _callback;
}


- (void)setCallback:(ooscript::Value)callback
{
	ooscript::Context context = OOJSAcquireContext();
	ooscript::removeValueRoot((context), (&_callback));
	_callback = callback;
	OOJSAddGCValueRoot(context, &_callback, "OOJSPopulatorDefinition callback function");
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
	OOJSAddGCObjectRoot(context, &_callbackThis, "OOJSPopulatorDefinition callback this");
	OOJSRelinquishContext(context);
}


- (void)runCallback:(HPVector)location
{
	OOJavaScriptEngine *engine = [OOJavaScriptEngine sharedEngine];
	ooscript::Context context = OOJSAcquireContext();		
	ooscript::Value					loc, rval = ooscript::undefinedValue();

	VectorToJSValue(context, HPVectorToVector(location), &loc);

	OOJSScript *owner = [_owningScript retain]; // local copy needed
	[OOJSScript pushScript:owner];

	[engine callJSFunction:_callback
				 forObject:_callbackThis
					  argc:1
					  argv:&loc
					result:&rval];
	
	[OOJSScript popScript:owner];
	[owner release];

	OOJSRelinquishContext(context);
}

@end
