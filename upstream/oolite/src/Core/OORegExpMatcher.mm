/*

OORegExpMatcher.mm


Copyright (C) 2010-2013 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#import "OORegExpMatcher.h"
#import "OOJSFunction.h"
#import "OOJavaScriptEngine.h"

#include "ooscript/JSEngine.hpp"

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm was (bead oo-sdz):
	the one directly-spelled engine call this file made — compiling a RegExp object from a
	cached UTF-16 pattern — now goes through the façade's own regexp entry point, engine
	still underneath. Everything else here (OOJSAcquireContext, OOJSRelinquishContext,
	OOJSValue, OOJSFunction) already spoke the façade's older OOJS_* naming and is unchanged.
	A tiny local reinterpret_cast, the same shape as OOJSVector.mm's OOJSFCX/OOJSROBJ, recovers
	the plain engine-context and engine-object pointer locals so the rest of the function body is
	byte for byte what it was.
*/

namespace ooscript { }
using ooscript::Context;
using ooscript::Object;

namespace {
static inline Context   OOJSFCX(JSContext *cx) { return reinterpret_cast<Context>(cx); }
} // namespace
namespace {
static inline JSObject *OOJSROBJ(Object o)      { return reinterpret_cast<JSObject*>(o); }
} // namespace


// Pseudo-singleton: a single instance exists at a given time, but can be released.
namespace {
static OORegExpMatcher *sActiveInstance;
} // namespace


@implementation OORegExpMatcher

+ (instancetype) regExpMatcher
{
	NSAssert(![NSThread respondsToSelector:@selector(isMainThread)] || [[NSThread currentThread] isMainThread], @"OORegExpMatcher may only be used on the main thread.");
	
	if (sActiveInstance == nil)
	{
		sActiveInstance = [[[self alloc] init] autorelease];
	}
	
	return sActiveInstance;
}


- (id) init
{
	self = [super init];
	if (self != nil)
	{	
		const char *argumentNames[2] = { "string", "regexp" };
		unsigned codeLine = __LINE__ + 1;	// NB: should remain line before code.
		NSString *code = @"return regexp.test(string);";
		
		[OOJavaScriptEngine sharedEngine];	// Summon the beast from the Pit.
		
		JSContext *context = OOJSAcquireContext();
		_tester = [[OOJSFunction alloc] initWithName:@"matchesRegExp"
											   scope:NULL
												code:code
									   argumentCount:2
									   argumentNames:argumentNames
											fileName:[@__FILE__ lastPathComponent]
										  lineNumber:codeLine
											 context:context];
		
		OOJSRelinquishContext(context);
		
		if (_tester == nil)  DESTROY(self);
	}
	
	return self;
}


- (void) dealloc
{
	if (sActiveInstance == self)  sActiveInstance = nil;
	
	DESTROY(_tester);
	DESTROY(_cachedRegExpString);
	DESTROY(_cachedRegExpObject);
	
	[super dealloc];
}


- (BOOL) string:(NSString *)string matchesExpression:(NSString *)regExp
{
	return [self string:string matchesExpression:regExp flags:0];
}


- (BOOL) string:(NSString *)string matchesExpression:(NSString *)regExp flags:(NSUInteger)flags
{
	NSAssert(![NSThread respondsToSelector:@selector(isMainThread)] || [[NSThread currentThread] isMainThread], @"OORegExpMatcher may only be used on the main thread.");
	
	size_t expLength = [regExp length];
	if (EXPECT_NOT(expLength == 0))  return NO;
	
	JSContext *context = OOJSAcquireContext();
	
	// Create new RegExp object if necessary.
	if (flags != _cachedFlags || ![regExp isEqualToString:_cachedRegExpString])
	{
		DESTROY(_cachedRegExpString);
		DESTROY(_cachedRegExpObject);
		
		unichar *buffer;
		buffer = static_cast<unichar *>(malloc(expLength * sizeof *buffer));
		if (EXPECT_NOT(buffer == NULL))  return NO;
		[regExp getCharacters:buffer];
		
		_cachedRegExpString = [regExp retain];
		Object regExpFacadeObj = ooscript::newUCRegExpObjectNoStatics(OOJSFCX(context), reinterpret_cast<const ooscript::Char16 *>(buffer), expLength, static_cast<std::uint32_t>(flags));
		JSObject *regExpObj = OOJSROBJ(regExpFacadeObj);
		_cachedRegExpObject = [[OOJSValue alloc] initWithJSObject:regExpObj inContext:context];
		_cachedFlags = flags;
		
		free(buffer);
	}
	
	BOOL result = [_tester evaluatePredicateWithContext:context
												  scope:nil
											  arguments:[NSArray arrayWithObjects:string, _cachedRegExpObject, nil]];
	
	OOJSRelinquishContext(context);
	
	return result;
}

@end


@implementation NSString (OORegExpMatcher)

- (BOOL) oo_matchesRegularExpression:(NSString *)regExp
{
	return [[OORegExpMatcher regExpMatcher] string:self matchesExpression:regExp];
}

@end
