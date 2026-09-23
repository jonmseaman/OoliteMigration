/*

OOJSInterfaceDefinition.mm


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

#import "OOJSInterfaceDefinition.h"
#import "OOJavaScriptEngine.h"

#include "ooscript/JSEngine.hpp"
#include "oofnd/Notification.hpp"

/*
	Retargeted (bead oo-mqb) onto the ooscript façade (JSEngine.hpp), same pattern as the
	Phase 1 exemplar OOJSVector.mm (bead oo-sdz): the two directly spelled engine calls this
	file makes (RemoveValueRoot, RemoveObjectRoot) go through ooscript::removeValueRoot/
	removeObjectRoot. OOJSAddGCValueRoot/OOJSAddGCObjectRoot are OOJS_* macros, not engine calls, so
	they are out of scope for this sweep and unchanged. The instance variables are façade
	Value/Object values, so their addresses go to the façade calls directly.
*/

@implementation OOJSInterfaceDefinition

- (id) init {
	self = [super init];
	_callback = ooscript::undefinedValue();
	_callbackThis = NULL;

	_owningScript = [[OOJSScript currentlyRunningScript] weakRetain];

	oo::NotificationCenter::defaultCenter().addObserver(self, kOOJavaScriptEngineWillResetNotificationName,
														[OOJavaScriptEngine sharedEngine],
														[self](const oo::Notification &) { [self deleteJSPointers]; });

	return self;
}

- (void) deleteJSPointers
{

	ooscript::Context context = OOJSAcquireContext();
	_callback = ooscript::undefinedValue();
	_callbackThis = NULL;
	ooscript::removeValueRoot((context), (&_callback));
	ooscript::removeObjectRoot((context), &_callbackThis);

	OOJSRelinquishContext(context);

	oo::NotificationCenter::defaultCenter().removeObserver(self, kOOJavaScriptEngineWillResetNotificationName,
															[OOJavaScriptEngine sharedEngine]);

}

- (void) dealloc 
{
	[_owningScript release];

	[self deleteJSPointers];

	[super dealloc];
}

- (NSString *)title 
{
	return _title;
}


- (void)setTitle:(NSString *)title
{
	[_title autorelease];
	_title = [title retain];
}


- (NSString *)category
{
	return _category;
}


- (void)setCategory:(NSString *)category
{
	[_category autorelease];
	_category = [category retain];
}


- (NSString *)summary
{
	return _summary;
}


- (void)setSummary:(NSString *)summary
{
	[_summary autorelease];
	_summary = [summary retain];
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
	OOJSAddGCValueRoot(context, &_callback, "OOJSInterfaceDefinition callback function");
	OOJSRelinquishContext(context);
}


- (ooscript::Object)callbackThis
{
	return _callbackThis;
}


- (void)setCallbackThis:(ooscript::Object)callbackThis
{
	ooscript::Context context = OOJSAcquireContext();
	ooscript::removeObjectRoot((context), &_callbackThis);
	_callbackThis = callbackThis;
	OOJSAddGCObjectRoot(context, &_callbackThis, "OOJSInterfaceDefinition callback this");
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


- (NSComparisonResult)interfaceCompare:(OOJSInterfaceDefinition *)other
{
	NSComparisonResult byCategory = [_category caseInsensitiveCompare:[other category]];
	if (byCategory == NSOrderedSame)
	{
		return [_title caseInsensitiveCompare:[other title]];
	}
	else
	{
		return byCategory;
	}
}

@end
