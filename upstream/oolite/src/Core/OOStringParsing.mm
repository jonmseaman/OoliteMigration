/*

OOStringParsing.mm

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

#import "OOStringParsing.h"
#import "OOLogging.h"
#import "NSScannerOOExtensions.h"
#import "legacy_random.h"
#import "Universe.h"
#import "PlayerEntity.h"
#import "PlayerEntityLegacyScriptEngine.h"
#import "OOFunctionAttributes.h"
#import "OOCollectionExtractors.h"
#import "ResourceManager.h"
#import "HeadUpDisplay.h"

#import "OOJavaScriptEngine.h"
#import "OOJSEngineTimeManagement.h"
#import "OOStringBridge.h"
#import "OOFoundationBridge.h"

#include "ooscript/JSEngine.hpp"

/*
	OOStringFromDeciCredits below is retargeted onto the ooscript façade (JSEngine.hpp), the
	same call-site pattern OOJSVector.mm (bead oo-sdz) established: the small set of directly
	spelled engine calls it makes (retrieving and restoring a pending exception, looking a
	method up by id, the numeric-conversion call, and invoking a function value) become the
	façade's equivalents, taking and returning the façade's own Context/Object/Value/PropertyId
	types directly, while the OOJS_* helpers stay exactly as they were.
*/

namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::Value;
using ooscript::PropertyId;



BOOL cxx_ScanVectorFromString(const std::optional<std::string> &xyzString, Vector *outVector)
{
	GLfloat					xyz[] = {0.0, 0.0, 0.0};
	int						i = 0;
	const char				*error = nullptr;
	NSScanner				*scanner = nil;

	assert(outVector != NULL);
	if (!xyzString.has_value()) return NO;

	if (!error) scanner = [NSScanner scannerWithString:oo::NSStringFrom(*xyzString)];	// the NSScanner family (oo-3rb.12) retires this
	while (![scanner isAtEnd] && i < 3 && !error)
	{
		if (![scanner scanFloat:&xyz[i++]])  error = "could not scan a float value.";
	}

	if (!error && i < 3)  error = "found less than three float values.";

	if (!error)
	{
		*outVector = make_vector(xyz[0], xyz[1], xyz[2]);
		return YES;
	}
	else
	{
		 OOLogERR(@"strings.conversion.vector", @"cannot make vector from '%@': %s", oo::NSStringFrom(*xyzString), error);
		 return NO;
	}
}

BOOL cxx_ScanHPVectorFromString(const std::optional<std::string> &xyzString, HPVector *outVector)
{
	Vector scanVector;
	assert(outVector != NULL);
	BOOL result = cxx_ScanVectorFromString(xyzString, &scanVector);
	if (!result)
	{
		return NO;
	}
	*outVector = vectorToHPVector(scanVector);
	return YES;
}

BOOL cxx_ScanQuaternionFromString(const std::optional<std::string> &wxyzString, Quaternion *outQuaternion)
{
	GLfloat					wxyz[] = {1.0, 0.0, 0.0, 0.0};
	int						i = 0;
	const char				*error = nullptr;
	NSScanner				*scanner = nil;

	assert(outQuaternion != NULL);
	if (!wxyzString.has_value()) return NO;

	if (!error) scanner = [NSScanner scannerWithString:oo::NSStringFrom(*wxyzString)];	// the NSScanner family (oo-3rb.12) retires this
	while (![scanner isAtEnd] && i < 4 && !error)
	{
		if (![scanner scanFloat:&wxyz[i++]])  error = "could not scan a float value.";
	}

	if (!error && i < 4)  error = "found less than four float values.";

	if (!error)
	{
		outQuaternion->w = wxyz[0];
		outQuaternion->x = wxyz[1];
		outQuaternion->y = wxyz[2];
		outQuaternion->z = wxyz[3];
		quaternion_normalize(outQuaternion);
		return YES;
	}
	else
	{
		OOLogERR(@"strings.conversion.quaternion", @"cannot make quaternion from '%@': %s", oo::NSStringFrom(*wxyzString), error);
		return NO;
	}
}


BOOL cxx_ScanVectorAndQuaternionFromString(const std::optional<std::string> &xyzwxyzString, Vector *outVector, Quaternion *outQuaternion)
{
	GLfloat					xyzwxyz[] = { 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0};
	int						i = 0;
	const char				*error = nullptr;
	NSScanner				*scanner = nil;

	assert(outVector != NULL && outQuaternion != NULL);
	if (!xyzwxyzString.has_value()) return NO;

	if (!error) scanner = [NSScanner scannerWithString:oo::NSStringFrom(*xyzwxyzString)];	// the NSScanner family (oo-3rb.12) retires this
	while (![scanner isAtEnd] && i < 7 && !error)
	{
		if (![scanner scanFloat:&xyzwxyz[i++]])  error = "Could not scan a float value.";
	}

	if (!error && i < 7)  error = "Found less than seven float values.";

	if (error)
	{
		OOLogERR(@"strings.conversion.quaternion", @"cannot make vector and quaternion from '%@': %s", oo::NSStringFrom(*xyzwxyzString), error);
		return NO;
	}

	outVector->x = xyzwxyz[0];
	outVector->y = xyzwxyz[1];
	outVector->z = xyzwxyz[2];
	outQuaternion->w = xyzwxyz[3];
	outQuaternion->x = xyzwxyz[4];
	outQuaternion->y = xyzwxyz[5];
	outQuaternion->z = xyzwxyz[6];

	return YES;
}


Vector cxx_VectorFromString(const std::optional<std::string> &xyzString, Vector defaultValue)
{
	Vector result;
	if (!cxx_ScanVectorFromString(xyzString, &result))  result = defaultValue;
	return result;
}


Quaternion cxx_QuaternionFromString(const std::optional<std::string> &wxyzString, Quaternion defaultValue)
{
	Quaternion result;
	if (!cxx_ScanQuaternionFromString(wxyzString, &result))  result = defaultValue;
	return result;
}


std::string cxx_StringFromPoint(NSPoint point)
{
	return oo::str::format("%f %f", point.x, point.y);
}


NSPoint cxx_PointFromString(const std::string &xyString)
{
	const std::vector<std::string> tokens = oo::str::tokens(xyString);
	NSPoint		result = NSZeroPoint;

	if (tokens.size() == 2)
	{
		result.x = oo::str::doubleValue(tokens[0]);
		result.y = oo::str::doubleValue(tokens[1]);
	}
	return result;
}


Random_Seed cxx_RandomSeedFromString(const std::optional<std::string> &abcdefString)
{
	Random_Seed				result;
	int						abcdef[] = { 0, 0, 0, 0, 0, 0};
	int						i = 0;
	const char				*error = nullptr;
	// the NSScanner family (oo-3rb.12) retires this; a nil string scans as it did
	NSScanner				*scanner = [NSScanner scannerWithString:oo::NSStringOrNil(abcdefString)];

	while (![scanner isAtEnd] && i < 6 && !error)
	{
		if (![scanner scanInt:&abcdef[i++]])  error = "could not scan a int value.";
	}

	if (!error && i < 6)  error = "found less than six int values.";

	if (!error)
	{
		result.a = abcdef[0];
		result.b = abcdef[1];
		result.c = abcdef[2];
		result.d = abcdef[3];
		result.e = abcdef[4];
		result.f = abcdef[5];
	}
	else
	{
		OOLogERR(@"strings.conversion.randomSeed", @"cannot make Random_Seed from '%@': %s", oo::NSStringOrNil(abcdefString), error);
		result = kNilRandomSeed;
	}

	return result;
}


std::string cxx_StringFromRandomSeed(Random_Seed seed)
{
	return oo::str::format("%d %d %d %d %d %d", seed.a, seed.b, seed.c, seed.d, seed.e, seed.f);
}


NSString *OOPadStringToEms(NSString * string, float padEms)
{
	NSString		*result = string;
	float numEms = padEms - OOStringWidthInEm(result);
	if (numEms>0)
	{
		numEms /= OOStringWidthInEm(@" "); // start with wide space
		result=[[@"" stringByPaddingToLength:(NSUInteger)numEms withString: @" " startingAtIndex:0] stringByAppendingString: result];
	}
	// most of the way there, so switch to narrow space
	numEms = padEms - OOStringWidthInEm(result);
	if (numEms>0)
	{
		numEms /= OOStringWidthInEm(@"\037"); // 037 is narrow space
		result=[[@"" stringByPaddingToLength:(NSUInteger)numEms withString: @"\037" startingAtIndex:0] stringByAppendingString: result];
	}
	return result;
}


NSString *OOStringFromDeciCredits(OOCreditsQuantity tenthsOfCredits, BOOL includeDecimal, BOOL includeSymbol)
{
	ooscript::Context context = OOJSAcquireContext();
	ooscript::Object global = [[OOJavaScriptEngine sharedEngine] globalObject];
	ooscript::Value				method;
	ooscript::Value				rval;
	NSString			*result = nil;
	ooscript::Value				exception;
	BOOL				hadException;
	
	/*	Because the |cr etc. formatting operators call this, and the
		implementation may use string expansion, we need to ensure recursion
		can't happen.
	*/
	static BOOL reentrancyLock;
	if (reentrancyLock)  return [NSString stringWithFormat:@"%0.1f", tenthsOfCredits * 0.1];
	
	reentrancyLock = YES;
	
	hadException = ooscript::getPendingException((context), (&exception));
	ooscript::clearPendingException((context));
	
	{
		Object fakeRootFacade = NULL;
		if (ooscript::getMethodById((context), (global), OOJSID("formatCredits"), &fakeRootFacade, (&method)))
		{
			ooscript::Value args[3];
			if (ooscript::newNumberValue((context), tenthsOfCredits * 0.1, (&args[0])))
			{
				args[1] = OOJSValueFromBOOL(includeDecimal);
				args[2] = OOJSValueFromBOOL(includeSymbol);
				
				OOJSStartTimeLimiter();
				ooscript::callFunctionValue((context), (global), (method), 3, (args), (&rval));
				OOJSStopTimeLimiter();
				
				result = OOStringFromJSValue(context, rval);
			}
		}
	}
	
	if (hadException)  ooscript::setPendingException((context), (exception));
	
	OOJSRelinquishContext(context);
	
	if (EXPECT_NOT(result == nil))  result = [NSString stringWithFormat:@"%li", (long)(tenthsOfCredits) / 10];
	
	reentrancyLock = NO;
	
	return result;
}


NSArray *ComponentsFromVersionString(NSString *string)
{
	NSArray				*stringComponents = nil;
	NSMutableArray		*result = nil;
	NSUInteger			i, count;
	int					value;
	id					component;
	
	stringComponents = [string componentsSeparatedByString:@" "];
	stringComponents = [[stringComponents objectAtIndex:0] componentsSeparatedByString:@"-"];
	stringComponents = [[stringComponents objectAtIndex:0] componentsSeparatedByString:@"."];
	count = [stringComponents count];
	result = [NSMutableArray arrayWithCapacity:count];
	
	for (i = 0; i != count; ++i)
	{
		component = [stringComponents objectAtIndex:i];
		if ([component respondsToSelector:@selector(intValue)])  value = MAX([component intValue], 0);
		else  value = 0;
		
		[result addObject:[NSNumber numberWithUnsignedInt:value]];
	}
	
	return result;
}


NSComparisonResult CompareVersions(NSArray *version1, NSArray *version2)
{
	NSEnumerator		*leftEnum = nil,
						*rightEnum = nil;
	NSNumber			*leftComponent = nil,
						*rightComponent = nil;
	unsigned			leftValue,
						rightValue;
	
	leftEnum = [version1 objectEnumerator];
	rightEnum = [version2 objectEnumerator];
	
	for (;;)
	{
		leftComponent = [leftEnum nextObject];
		rightComponent = [rightEnum nextObject];
		
		if (leftComponent == nil && rightComponent == nil)  break;	// End of both versions
		
		// We'll get 0 if the component is nil, which is what we want.
		leftValue = [leftComponent unsignedIntValue];
		rightValue = [rightComponent unsignedIntValue];
		
		if (leftValue < rightValue) return NSOrderedAscending;
		if (leftValue > rightValue) return NSOrderedDescending;
	}
	
	// If there was a difference, we'd have returned already.
	return NSOrderedSame;
}


NSString *ClockToString(double clock, BOOL adjusting)
{
	int				days, hrs, mins, secs;
	NSString		*format = nil;
	
	days = floor(clock / 86400.0);
	secs = floor(clock - days * 86400.0);
	hrs = floor(secs / 3600.0);
	secs %= 3600;
	mins = floor(secs / 60.0);
	secs %= 60;
	
	if (adjusting)  format = DESC(@"clock-format-adjusting");
	else  format = DESC(@"clock-format");
	
	return [NSString stringWithFormat:format, days, hrs, mins, secs];
}


#if DEBUG_GRAPHVIZ

NSString *EscapedGraphVizString(NSString *string)
{
	NSString * const srcStrings[] =
	{
		//Note: backslash must be first.
		@"\\", @"\"", @"\'", @"\r", @"\n", @"\t", nil
	};
	NSString * const subStrings[] =
	{
		//Note: must be same order.
		@"\\\\", @"\\\"", @"\\\'", @"\\r", @"\\n", @"\\t", nil
	};
	
	NSString * const *		src = srcStrings;
	NSString * const *		sub = subStrings;
	NSMutableString			*mutableString = nil;
	NSString				*result = nil;
	
	mutableString = [string mutableCopy];
	while (*src != nil)
	{
		[mutableString replaceOccurrencesOfString:*src++
									 withString:*sub++
										options:0
										  range:(NSRange){ 0, [mutableString length] }];
	}
	
	if ([mutableString length] == [string length])
	{
		result = string;
	}
	else
	{
		result = [[mutableString copy] autorelease];
	}
	[mutableString release];
	return result;
}


namespace {
static BOOL NameIsTaken(NSString *name, NSSet *uniqueSet);
} // namespace

NSString *GraphVizTokenString(NSString *string, NSMutableSet *uniqueSet)
{
	NSString *token = nil;
	@autoreleasepool
	{
		BOOL lastWasUnderscore = NO;
		NSUInteger i, length = [string length], ri = 0;
		unichar result[length];
	
		if (length > 0)
		{
			// Special case for first char - can't be digit.
			unichar c = [string characterAtIndex:0];
			if (!isalpha(c))
			{
				c = '_';
				lastWasUnderscore = YES;
			}
			result[ri++] = c;
		
			for (i = 1; i < length; i++)
			{
				c = [string characterAtIndex:i];
				if (!isalnum(c))
				{
					if (lastWasUnderscore)  continue;
					c = '_';
					lastWasUnderscore = YES;
				}
				else
				{
					lastWasUnderscore = NO;
				}
			
				result[ri++] = c;
			}
		
			token = [NSString stringWithCharacters:result length:ri];
		}
		else
		{
			token = @"_";
		}
	
		if (NameIsTaken(token, uniqueSet))
		{
			if (!lastWasUnderscore)  token = [token stringByAppendingString:@"_"];
			NSString *uniqueToken = nil;
			unsigned uniqueID = 2;
		
			for (;;)
			{
				uniqueToken = [NSString stringWithFormat:@"%@%u", token, uniqueID];
				if (!NameIsTaken(uniqueToken, uniqueSet))  break;
			}
			token = uniqueToken;
		}
		[uniqueSet addObject:token];
	
		[token retain];
	}
	return [token autorelease];
}


namespace {
static BOOL NameIsTaken(NSString *name, NSSet *uniqueSet)
{
	if ([uniqueSet containsObject:name])  return YES;
	
	static NSSet *keywords = nil;
	if (keywords == nil)  keywords = [[NSSet alloc] initWithObjects:@"node", @"edge", @"graph", @"digraph", @"subgraph", @"strict", nil];
	
	return [keywords containsObject:[name lowercaseString]];
}
} // namespace

#endif //DEBUG_GRAPHVIZ
