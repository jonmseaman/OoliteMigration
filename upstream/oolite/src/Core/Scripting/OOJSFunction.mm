/*

OOJSFunction.m
 

JavaScript support for Oolite
Copyright (C) 2007-2013 David Taylor and Jens Ayton.

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

#import "OOJSFunction.h"
#import "OOJSScript.h"
#import "OOJSEngineTimeManagement.h"
#include "oofnd/Notification.hpp"


@implementation OOJSFunction

- (id) initWithFunction:(ooscript::Function)function context:(ooscript::Context)context
{
	NSParameterAssert(context != NULL);
	
	if (function == NULL)
	{
		[self release];
		return nil;
	}
	
	if ((self = [super init]))
	{
		_function = function;
		OOJSAddGCObjectRoot(context, (ooscript::Object *)&_function, "OOJSFunction._function");
		_name = [OOStringFromJSString(context, ooscript::getFunctionId(function)) retain];
		
		oo::NotificationCenter::defaultCenter().addObserver(self, kOOJavaScriptEngineWillResetNotificationName,
															[OOJavaScriptEngine sharedEngine],
															[self](const oo::Notification &) { [self deleteJSValue]; });
	}
	
	return self;
}


- (id) initWithName:(NSString *)name
			  scope:(ooscript::Object)scope
			   code:(NSString *)code
	  argumentCount:(NSUInteger)argCount
	  argumentNames:(const char **)argNames
		   fileName:(NSString *)fileName
		 lineNumber:(NSUInteger)lineNumber
			context:(ooscript::Context)context
{
	BOOL						OK = YES;
	BOOL						releaseContext = NO;
	ooscript::Char16						*buffer = NULL;
	size_t						length = 0;
	ooscript::Function function;
	
	if (context == NULL)
	{
		context = OOJSAcquireContext();
		releaseContext = YES;
	}
	if (scope == NULL)  scope = [[OOJavaScriptEngine sharedEngine] globalObject];
	
	if (code == nil || (argCount > 0 && argNames == NULL))  OK = NO;
	
	if (OK)
	{
		// ooscript::Char16 and unichar are both defined to be 16-bit elements.
		assert(sizeof(ooscript::Char16) == sizeof(unichar));
		
		length = [code length];
		buffer = (ooscript::Char16 *)malloc(sizeof(ooscript::Char16) * length);
		if (buffer == NULL)  OK = NO;
	}
	
	if (OK)
	{
		assert(argCount < UINT32_MAX);
		
		[code getCharacters:(unichar *)buffer];
		
		function = ooscript::compileUCFunction(context, scope, [name UTF8String], (uint32_t)argCount, argNames, buffer, length, [fileName UTF8String], (uint32_t)lineNumber);
		if (function == NULL)  OK = NO;
		
		free(buffer);
	}
	
	if (OK)
	{
		self = [self initWithFunction:function context:context];
	}
	else
	{
		DESTROY(self);
	}
	
	if (releaseContext)  OOJSRelinquishContext(context);
	
	return self;
}


- (void) deleteJSValue
{
	if (_function != NULL)
	{
		ooscript::Context context = OOJSAcquireContext();
		ooscript::removeObjectRoot(context, (ooscript::Object *)&_function);
		OOJSRelinquishContext(context);
		
		_function = NULL;
		oo::NotificationCenter::defaultCenter().removeObserver(self, kOOJavaScriptEngineWillResetNotificationName,
																[OOJavaScriptEngine sharedEngine]);
	}
}


- (void) dealloc
{
	[self deleteJSValue];
	DESTROY(_name);
	
	[super dealloc];
}


- (NSString *) descriptionComponents
{
	NSString *name = [self name];
	if (name == nil)  name = @"<anonymous>";
	return [NSString stringWithFormat:@"%@()", name];
}


- (NSString *) name
{
	return _name;
}


- (ooscript::Function) function
{
	return _function;
}


- (ooscript::Value) functionValue
{
	if (EXPECT(_function != NULL))
	{
		return ooscript::objectValue(ooscript::getFunctionObject(_function));
	}
	else
	{
		return ooscript::nullValue();
	}

}


- (BOOL) evaluateWithContext:(ooscript::Context)context
					   scope:(ooscript::Object)jsThis
						argc:(unsigned)argc
						argv:(ooscript::Value *)argv
					  result:(ooscript::Value *)result
{
	[OOJSScript pushScript:nil];
	OOJSStartTimeLimiter();
	BOOL OK = ooscript::callFunction(context, jsThis, _function, argc, argv, result);
	OOJSStopTimeLimiter();
	[OOJSScript popScript:nil];
	
	return OK;
}

// Semi-raw evaluation shared by convenience methods below.
- (BOOL) evaluateWithContext:(ooscript::Context)context
					   scope:(id)jsThis
				   arguments:(NSArray *)arguments
					  result:(ooscript::Value *)result
{
	NSUInteger i, argc = [arguments count];
	assert(argc < UINT32_MAX);
	ooscript::Value argv[argc];
	
	for (i = 0; i < argc; i++)
	{
		argv[i] = [[arguments objectAtIndex:i] oo_jsValueInContext:context];
		OOJSAddGCValueRoot(context, &argv[i], "OOJSFunction argv");
	}
	
	ooscript::Object scopeObj = NULL;
	BOOL OK = YES;
	if (jsThis != nil)  OK = ooscript::valueToObject(context, [jsThis oo_jsValueInContext:context], &scopeObj);
	if (OK)  OK = [self evaluateWithContext:context
									  scope:scopeObj
									   argc:(uint32_t)argc
									   argv:argv
									 result:result];
	
	for (i = 0; i < argc; i++)
	{
		ooscript::removeValueRoot(context, &argv[i]);
	}
	
	return OK;
}


- (id) evaluateWithContext:(ooscript::Context)context
					 scope:(id)jsThis
				 arguments:(NSArray *)arguments
{
	ooscript::Value result;
	BOOL OK = [self evaluateWithContext:context
								  scope:jsThis
							  arguments:arguments
								 result:&result];
	if (!OK)  return nil;
	
	return OOJSNativeObjectFromJSValue(context, result);
}
			   

- (BOOL) evaluatePredicateWithContext:(ooscript::Context)context
								scope:(id)jsThis
							arguments:(NSArray *)arguments
{
	ooscript::Value result;
	BOOL OK = [self evaluateWithContext:context
								  scope:jsThis
							  arguments:arguments
								 result:&result];
	bool retval = NO;
	if (OK)  OK = ooscript::valueToBoolean(context, result, &retval);
	return OK && retval;
}

@end
