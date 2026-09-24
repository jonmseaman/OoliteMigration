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
#import "NSNumberOOExtensions.h"


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


// The JavaScript glue for Foundation objects: categories on Foundation classes, retiring with
// gnustep-base (ADR-0043 Amendment 1 item 7; moved verbatim by bead oo-3rb.201), and their helpers.

namespace {
static ooscript::Object JSArrayFromNSArray(ooscript::Context context, NSArray *array)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object result = NULL;
	
	if (array == nil)  return NULL;
	
	@try
	{
		NSUInteger fullCount = [array count];
		if (EXPECT_NOT(fullCount > INT32_MAX))
		{
			return NULL;
		}
		
		uint32_t i, count = (int32_t)fullCount;
		
		result = (ooscript::newArrayObject((context), 0, NULL));
		if (result != NULL)
		{
			for (i = 0; i != count; ++i)
			{
				ooscript::Value value = [[array objectAtIndex:i] oo_jsValueInContext:context];
				ooscript::Value fval = (value);
				BOOL OK = ooscript::setElement((context), (result), i, &fval);
				
				if (EXPECT_NOT(!OK))
				{
					result = NULL;
					break;
				}
			}
		}
	}
	@catch (id ex)
	{
		result = NULL;
	}
	
	return (ooscript::Object)result;
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static BOOL JSNewNSArrayValue(ooscript::Context context, NSArray *array, ooscript::Value *value)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object object = NULL;
	BOOL					OK = YES;
	
	if (value == NULL)  return NO;
	
	// NOTE: rooted for GC reasons for the duration of the conversion, per ooscript/README.md's
	// "Not in the façade" note on EnterLocalRootScope / LeaveLocalRootScopeWithResult.
	ooscript::RootedValue rootedResult((context), ooscript::Value{0}, "JSNewNSArrayValue.result");
	
	object = JSArrayFromNSArray(context, array);
	if (object == NULL)
	{
		*value = ooscript::undefinedValue();
		OK = NO;
	}
	else
	{
		*value = ooscript::objectValue(object);
	}
	
	rootedResult.set((*value));
	return OK;
	
	OOJS_PROFILE_EXIT
}
} // namespace


/*	Convert an NSDictionary to a JavaScript Object.
	Only properties whose keys are either strings or non-negative NSNumbers,
	and	whose values have a non-void JS representation, are converted.
*/
namespace {
static ooscript::Object JSObjectFromNSDictionary(ooscript::Context context, NSDictionary *dictionary)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object result = NULL;
	BOOL					OK = YES;
	id						key = nil;
	ooscript::Value					value;
	int32_t					index;
	
	if (dictionary == nil)  return NULL;
	
	@try
	{
		result = (ooscript::newObject((context), NULL, NULL, NULL));	// create object of class Object
		if (result != NULL)
		{
			foreachkey (key, dictionary)
			{
				if ([key isKindOfClass:[NSString class]] && [key length] != 0)
				{
#ifndef __GNUC__
					value = [[dictionary objectForKey:key] oo_jsValueInContext:context];
#else
#if __GNUC__ > 4 || __GNUC_MINOR__ > 6
					value = [[dictionary objectForKey:key] oo_jsValueInContext:context];
#else
					// GCC before 4.7 seems to have problems with this
					// bit if the object is a weakref, causing crashes
					// in docking code.
					id tmp = [dictionary objectForKey:key];
					if ([tmp respondsToSelector:@selector(weakRefUnderlyingObject)])
					{
						tmp = [tmp weakRefUnderlyingObject];
					}
					value = [tmp oo_jsValueInContext:context];
#endif
#endif
					if (!ooscript::isUndefined(value))
					{
						OK = ooscript::setPropertyById((context), (result), (OOJSIDFromString(key)), (&value));
						if (EXPECT_NOT(!OK))  break;
					}
				}
				else if ([key isKindOfClass:[NSNumber class]])
				{
					index = [key intValue];
					if (0 < index)
					{
						value = [[dictionary objectForKey:key] oo_jsValueInContext:context];
						if (!ooscript::isUndefined(value))
						{
							OK = ooscript::setElement((context), ((ooscript::Object)result), index, (&value));
							if (EXPECT_NOT(!OK))  break;
						}
					}
				}
				
				if (EXPECT_NOT(!OK))  break;
			}
		}
	}
	@catch (id exception)
	{
		OK = NO;
	}
	
	if (EXPECT_NOT(!OK))
	{
		result = NULL;
	}
	
	return (ooscript::Object)result;
	
	OOJS_PROFILE_EXIT
}
} // namespace


namespace {
static BOOL JSNewNSDictionaryValue(ooscript::Context context, NSDictionary *dictionary, ooscript::Value *value)
{
	OOJS_PROFILE_ENTER
	
	ooscript::Object object = NULL;
	BOOL					OK = YES;
	
	if (value == NULL)  return NO;
	
	// NOTE: rooted for GC reasons for the duration of the conversion, per ooscript/README.md's
	// "Not in the façade" note on EnterLocalRootScope / LeaveLocalRootScopeWithResult.
	ooscript::RootedValue rootedResult((context), ooscript::Value{0}, "JSNewNSDictionaryValue.result");
	
	object = JSObjectFromNSDictionary(context, dictionary);
	if (object == NULL)
	{
		*value = ooscript::undefinedValue();
		OK = NO;
	}
	else
	{
		*value = ooscript::objectValue(object);
	}
	
	rootedResult.set((*value));
	return OK;
	
	OOJS_PROFILE_EXIT
}
} // namespace


@implementation NSObject (OOJavaScriptConversion)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context
{
	return ooscript::undefinedValue();
}


- (NSString *) oo_jsClassName
{
	return nil;
}


- (NSString *) oo_jsDescription
{
	return [self oo_jsDescriptionWithClassName:[self oo_jsClassName]];
}


- (NSString *) oo_jsDescriptionWithClassName:(NSString *)className
{
	OOJS_PROFILE_ENTER
	
	NSString				*components = nil;
	NSString				*description = nil;
	
	components = [self descriptionComponents];
	if (className == nil)  className = [[self class] description];
	
	if (components != nil)
	{
		description = [NSString stringWithFormat:@"[%@ %@]", className, components];
	}
	else
	{
		description = [NSString stringWithFormat:@"[object %@]", className];
	}
	
	return description;
	
	OOJS_PROFILE_EXIT
}


- (void) oo_clearJSSelf:(ooscript::Object)selfVal
{

}

@end


@implementation NSArray (OOJavaScriptConversion)

- (ooscript::Value)oo_jsValueInContext:(ooscript::Context)context
{
	ooscript::Value value = ooscript::undefinedValue();
	JSNewNSArrayValue(context, self, &value);
	return value;
}

@end


@implementation NSDictionary (OOJavaScriptConversion)

- (ooscript::Value)oo_jsValueInContext:(ooscript::Context)context
{
	ooscript::Value value = ooscript::undefinedValue();
	JSNewNSDictionaryValue(context, self, &value);
	return value;
}

@end


@implementation NSNumber (OOJavaScriptConversion)

- (ooscript::Value)oo_jsValueInContext:(ooscript::Context)context
{
	OOJS_PROFILE_ENTER
	
	ooscript::Value					result;
	BOOL					isFloat = NO;
	long long				longLongValue;
	
	isFloat = [self oo_isFloatingPointNumber];
	if (!isFloat)
	{
		longLongValue = [self longLongValue];
		if (longLongValue < (long long)INT32_MIN || (long long)INT32_MAX < longLongValue)
		{
			// values outside int32 range are returned as doubles.
			isFloat = YES;
		}
	}
	
	if (isFloat)
	{
		if (!ooscript::newNumberValue((context), [self doubleValue], (&result))) result = ooscript::undefinedValue();
	}
	else
	{
		result = ooscript::int32Value((int32_t)longLongValue);
	}
	
	return result;
	
	OOJS_PROFILE_EXIT_JSVAL
}


- (NSString *) oo_jsClassName
{
	return @"Number";
}

@end


NSDictionary *OOJSDictionaryFromJSObject(ooscript::Context context, ooscript::Object object)
{
	OOJS_PROFILE_ENTER
	
	ooscript::IdArray			*ids = NULL;
	std::size_t					i;
	NSMutableDictionary			*result = nil;
	ooscript::Value						value = ooscript::undefinedValue();
	id							objKey = nil;
	id							objValue = nil;
	
	ids = ooscript::enumerate((context), (object));
	if (EXPECT_NOT(ids == NULL))
	{
		return nil;
	}
	
	result = [NSMutableDictionary dictionaryWithCapacity:ids->length];
	for (i = 0; i != ids->length; ++i)
	{
		ooscript::PropertyId thisID = (ids->ids[i]);
		
		if (ooscript::isStringId(thisID))
		{
			objKey = OOStringFromJSString(context, ooscript::idToString(thisID));
		}
		else if (ooscript::isInt32Id(thisID))
		{
			/* this causes problems with native functions which expect string keys
			 * e.g. in mission.runScreen with the 'choices' parameter
			 * should this instead be making the objKey a string?
			 * is there anything that relies on the current behaviour?
			 * - CIM 15/2/13 */
			objKey = [NSNumber numberWithInt:ooscript::idToInt32(thisID)];
		}
		else
		{
			objKey = nil;
		}
		
		value = ooscript::undefinedValue();
		if (objKey != nil && !ooscript::lookupPropertyById((context), (object), (thisID), (&value)))  value = ooscript::undefinedValue();
		
		if (objKey != nil && !ooscript::isUndefined(value))
		{
			objValue = OOJSNativeObjectFromJSValue(context, value);
			if (objValue != nil)
			{
				[result setObject:objValue forKey:objKey];
			}
		}
	}
	
	ooscript::destroyIdArray((context), ids);
	return result;
	
	OOJS_PROFILE_EXIT
}


void OOJSRegisterFoundationObjectConverter(ooscript::ClassDef *objectClass)
{
	OOJSRegisterObjectConverter(objectClass, (OOJSClassConverterCallback)OOJSDictionaryFromJSObject);
}
