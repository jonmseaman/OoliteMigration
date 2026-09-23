/*

OOJavaScriptEngine+FoundationBridge.mm

TRANSITIONAL: see OOJavaScriptEngine+FoundationBridge.h. Each function forwards to its cxx_
counterpart and converts the result exactly as the old function produced it (nil for nil).

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
