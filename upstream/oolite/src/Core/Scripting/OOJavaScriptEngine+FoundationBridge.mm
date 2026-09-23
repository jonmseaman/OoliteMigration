/*

OOJavaScriptEngine+FoundationBridge.mm

TRANSITIONAL: see OOJavaScriptEngine+FoundationBridge.h. Each function forwards to its cxx_
counterpart and converts the result exactly as the old function produced it (nil for nil).
The NSString (OOJavaScriptExtensions) category retires here (ADR-0043 Amendment 1 item 7): its
-oo_jsValueInContext: and -oo_jsClassName are the JS glue for NSString objects and go with
gnustep-base (bead oo-3rb.199).

*/

#import "OOJavaScriptEngine.h"	// declares the bridge at its end
#import "OOFoundationBridge.h"


NSString *OOStringFromJSString(ooscript::Context context, ooscript::String string)
{
	return oo::NSStringOrNil(cxx_OOStringFromJSString(context, string));
}


NSString *OOStringFromJSValueEvenIfNull(ooscript::Context context, ooscript::Value value)
{
	return oo::NSStringOrNil(cxx_OOStringFromJSValueEvenIfNull(context, value));
}


NSString *OOStringFromJSValue(ooscript::Context context, ooscript::Value value)
{
	return oo::NSStringOrNil(cxx_OOStringFromJSValue(context, value));
}


NSString *OOStringFromJSPropertyIDAndSpec(ooscript::Context context, ooscript::PropertyId propID, ooscript::PropertySpec *propertySpec)
{
	return oo::NSStringOrNil(cxx_OOStringFromJSPropertyIDAndSpec(context, propID, propertySpec));
}


NSString *OOStringFromJSID(ooscript::PropertyId propID)
{
	return oo::NSStringOrNil(cxx_OOStringFromJSID(propID));
}


ooscript::PropertyId OOJSIDFromString(NSString *string)
{
	if (EXPECT_NOT(string == nil))  return ooscript::voidId();
	return cxx_OOJSIDFromString(oo::StdString(string));
}


NSString *OOJSDescribeValue(ooscript::Context context, ooscript::Value value, BOOL abbreviateObjects)
{
	return oo::NSStringFrom(cxx_OOJSDescribeValue(context, value, abbreviateObjects));
}


void OOJSReportError(ooscript::Context context, NSString *format, ...)
{
	va_list					args;

	va_start(args, format);
	OOJSReportErrorWithArguments(context, format, args);
	va_end(args);
}


void OOJSReportErrorForCaller(ooscript::Context context, NSString *scriptClass, NSString *function, NSString *format, ...)
{
	va_list					args;
	NSString				*msg = nil;

	@try
	{
		va_start(args, format);
		msg = [[NSString alloc] initWithFormat:format arguments:args];
		va_end(args);

		cxx_OOJSReportErrorForCaller(context, oo::OptionalString(scriptClass), oo::OptionalString(function), "%s", [msg UTF8String]);
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
	[msg release];
}


void OOJSReportErrorWithArguments(ooscript::Context context, NSString *format, va_list args)
{
	NSString				*msg = nil;

	NSCParameterAssert(ooscript::isInRequest((context)));

	@try
	{
		msg = [[NSString alloc] initWithFormat:format arguments:args];
		cxx_OOJSReportError(context, "%s", [msg UTF8String]);
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
	[msg release];
}


void OOJSReportWarning(ooscript::Context context, NSString *format, ...)
{
	va_list					args;

	va_start(args, format);
	OOJSReportWarningWithArguments(context, format, args);
	va_end(args);
}


void OOJSReportWarningForCaller(ooscript::Context context, NSString *scriptClass, NSString *function, NSString *format, ...)
{
	va_list					args;
	NSString				*msg = nil;

	@try
	{
		va_start(args, format);
		msg = [[NSString alloc] initWithFormat:format arguments:args];
		va_end(args);

		cxx_OOJSReportWarningForCaller(context, oo::OptionalString(scriptClass), oo::OptionalString(function), "%s", [msg UTF8String]);
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
	[msg release];
}


void OOJSReportWarningWithArguments(ooscript::Context context, NSString *format, va_list args)
{
	NSString				*msg = nil;

	@try
	{
		msg = [[NSString alloc] initWithFormat:format arguments:args];
		cxx_OOJSReportWarning(context, "%s", [msg UTF8String]);
	}
	@catch (id exception)
	{
		// Squash any secondary errors during error handling.
	}
	[msg release];
}


void OOJSReportBadArguments(ooscript::Context context, NSString *scriptClass, NSString *function, unsigned argc, ooscript::Value *argv, NSString *message, NSString *expectedArgsDescription)
{
	cxx_OOJSReportBadArguments(context, oo::OptionalString(scriptClass), oo::OptionalString(function), argc, argv, oo::OptionalString(message), oo::OptionalString(expectedArgsDescription));
}


BOOL OOJSArgumentListGetNumber(ooscript::Context context, NSString *scriptClass, NSString *function, unsigned argc, ooscript::Value *argv, double *outNumber, unsigned *outConsumed)
{
	return cxx_OOJSArgumentListGetNumber(context, oo::OptionalString(scriptClass), oo::OptionalString(function), argc, argv, outNumber, outConsumed);
}


@implementation NSString (OOJavaScriptExtensions)

+ (NSString *) stringWithJavaScriptParameters:(ooscript::Value *)params count:(unsigned)count inContext:(ooscript::Context)context
{
	return oo::NSStringOrNil(cxx_OOJSStringWithJavaScriptParameters(params, count, context));
}


- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	OOJS_PROFILE_ENTER
	
	size_t					length = [self length];
	unichar					*buffer = NULL;
	ooscript::String string = NULL;
	
	if (length == 0)
	{
		ooscript::Value result = ooscript::emptyStringValue((context));
		return result;
	}
	else
	{
		buffer = static_cast<unichar*>(malloc(length * sizeof *buffer));
		if (buffer == NULL) return ooscript::undefinedValue();
		
		[self getCharacters:buffer];
		
		string = (ooscript::newUCStringCopyN((context), reinterpret_cast<const ooscript::Char16*>(buffer), length));
		
		free(buffer);
		return ooscript::stringValue(string);
	}
	
	OOJS_PROFILE_EXIT_JSVAL
}


+ (NSString *) concatenationOfStringsFromJavaScriptValues:(ooscript::Value *)values count:(size_t)count separator:(NSString *)separator inContext:(ooscript::Context)context
{
	return oo::NSStringOrNil(cxx_OOJSConcatenationOfStringsFromJavaScriptValues(values, count, oo::StdString(separator), context));
}


- (NSString *)escapedForJavaScriptLiteral
{
	return oo::NSStringFrom(cxx_OOJSEscapedForJavaScriptLiteral(oo::StdString(self)));
}


- (NSString *) oo_jsClassName
{
	return @"String";
}

@end
