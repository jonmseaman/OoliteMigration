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
