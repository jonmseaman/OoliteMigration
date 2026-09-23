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
#import "OOFoundationBridge.h"

#include "ooscript/JSEngine.hpp"

/*
	Retargeted (bead oo-mqb) onto the ooscript façade (JSEngine.hpp), same pattern as the
	Phase 1 exemplar OOJSVector.mm (bead oo-sdz): the two directly spelled engine calls this
	file makes (RemoveValueRoot, RemoveObjectRoot) go through ooscript::removeValueRoot/
	removeObjectRoot. OOJSAddGCValueRoot/OOJSAddGCObjectRoot are OOJS_* macros, not engine calls, so
	they are out of scope for this sweep and unchanged. The instance variables are façade
	Value/Object values, so their addresses go to the façade calls directly.
*/

namespace {
// -caseInsensitiveCompare: as the definitions used it: a nil receiver answers
// NSOrderedSame (a message to nil); a nil argument compares as the empty string.
static NSComparisonResult CaseInsensitiveCompare(const std::optional<std::string> &a, const std::optional<std::string> &b)
{
	if (!a.has_value())  return NSOrderedSame;
	int order = oo::str::caseInsensitiveCompare(*a, b.value_or(std::string()));
	return (order < 0) ? NSOrderedAscending : ((order > 0) ? NSOrderedDescending : NSOrderedSame);
}
} // namespace


@implementation OOJSInterfaceDefinition

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
	ooscript::removeObjectRoot((context), &_callbackThis);

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

- (id)title	// shared selector (proposed ADR-0043)
{
	return oo::NSStringOrNil(_title);
}


- (void)setTitle:(id)title	// shared selector (proposed ADR-0043)
{
	_title = oo::OptionalString(title);
}


- (std::optional<std::string>)category
{
	return _category;
}


- (void)setCategory:(const std::string &)category
{
	_category = category;
}


- (std::optional<std::string>)summary
{
	return _summary;
}


- (void)setSummary:(const std::string &)summary
{
	_summary = summary;
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


- (void)runCallback:(id)key	// shared selector (proposed ADR-0043)
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
	NSComparisonResult byCategory = CaseInsensitiveCompare(_category, [other category]);
	if (byCategory == NSOrderedSame)
	{
		return CaseInsensitiveCompare(_title, oo::OptionalString([other title]));
	}
	else
	{
		return byCategory;
	}
}

@end
