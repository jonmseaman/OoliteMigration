/*

OOJSCall.h

Basic JavaScript-to-ObjC bridge implementation.

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

#ifndef NDEBUG


#import "OOJSCall.h"
#include "oofnd/objc/OORuntime.h"
#import "OOJavaScriptEngine.h"
#import "OOCallByName.h"
#import "OOObjCPList.h"

#import "OOFunctionAttributes.h"
#import "ShipEntity.h"
#import "OOShaderUniformMethodType.h"
#import "OOJSVector.h"
#import "OOJSQuaternion.h"
#import "OOFoundationBridge.h"
#include "oofnd/PListGet.hpp"


typedef enum
{
	kMethodTypeInvalid				= kOOShaderUniformTypeInvalid,
	
	kMethodTypeCharVoid				= kOOShaderUniformTypeChar,
	kMethodTypeUnsignedCharVoid		= kOOShaderUniformTypeUnsignedChar,
	kMethodTypeShortVoid			= kOOShaderUniformTypeShort,
	kMethodTypeUnsignedShortVoid	= kOOShaderUniformTypeUnsignedShort,
	kMethodTypeIntVoid				= kOOShaderUniformTypeInt,
	kMethodTypeUnsignedIntVoid		= kOOShaderUniformTypeUnsignedInt,
	kMethodTypeLongVoid				= kOOShaderUniformTypeLong,
	kMethodTypeUnsignedLongVoid		= kOOShaderUniformTypeUnsignedLong,
	kMethodTypeFloatVoid			= kOOShaderUniformTypeFloat,
	kMethodTypeDoubleVoid			= kOOShaderUniformTypeDouble,
	kMethodTypeVectorVoid			= kOOShaderUniformTypeVector,
	kMethodTypeQuaternionVoid		= kOOShaderUniformTypeQuaternion,
	kMethodTypeMatrixVoid			= kOOShaderUniformTypeMatrix,
	kMethodTypePointVoid			= kOOShaderUniformTypePoint,
	
	kMethodTypeObjectVoid			= kOOShaderUniformTypeObject,
	kMethodTypeObjectObject,
	kMethodTypeVoidVoid,
	kMethodTypeVoidObject,
	kMethodTypePListVoid
} MethodType;


static MethodType GetMethodType(id object, SEL selector);
OOINLINE BOOL MethodExpectsParameter(MethodType type)	{ return type == kMethodTypeVoidObject || type == kMethodTypeObjectObject; }


BOOL OOJSCallObjCObjectMethod(ooscript::Context context, id object, const std::string &oo_jsClassName, unsigned argc, ooscript::Value *argv, ooscript::Value *outResult)
{
	OOJS_PROFILE_ENTER
	
	std::optional<std::string>	selectorString;
	SEL						selector = NULL;
	std::optional<std::string>	paramString;
	MethodType				type;
	BOOL					haveParameter = NO,
							error = NO;
	oo::PList				result;		// null for none
	
	if (argc == 0)
	{
		cxx_OOJSReportError(context, "%s.callObjC(): no selector specified.", oo_jsClassName.c_str());
		return NO;
	}
	
	if ([object isKindOfClass:[ShipEntity class]])
	{
		[PLAYER setScriptTarget:object];
	}
	
	selectorString = cxx_OOStringFromJSValue(context, argv[0]);
	
	// Join all parameters together with spaces.
	if (1 < argc && selectorString.has_value() && oo::str::hasSuffix(*selectorString, ":"))
	{
		haveParameter = YES;
		// As +concatenationOfStringsFromJavaScriptValues:count:separator:@" " joined them.
		std::string joined;
		for (unsigned i = 1; i < argc; i++)
		{
			if (i > 1)  joined += " ";
			joined += cxx_OOStringFromJSValueEvenIfNull(context, argv[i]).value_or(std::string());
		}
		paramString = joined;
	}
	
	selector = OOSelectorFromName(selectorString.has_value() ? selectorString->c_str() : NULL);
	
	if ([object respondsToSelector:selector])
	{
		// Validate signature.
		type = GetMethodType(object, selector);
		
		if (MethodExpectsParameter(type) && !haveParameter)
		{
			cxx_OOJSReportError(context, "%s.callObjC(): method %s requires a parameter.", oo_jsClassName.c_str(), (selectorString ? selectorString->c_str() : "(null)"));
			error = YES;
		}
		else
		{
			IMP method = [object methodForSelector:selector];
			switch (type)
			{
				case kMethodTypeVoidObject:
				case kMethodTypeObjectObject:
					// Called by name with the joined string (ADR-0055 item 5); a void method gives null.
					result = OOCallByName(object, selector, *paramString);
					break;
					
				case kMethodTypeObjectVoid:
				case kMethodTypePListVoid:
					if (type == kMethodTypePListVoid)  result = OOCallByName(object, selector);
					// An object result (a ship, a colour) is its PList::Object node, as oo::PListFrom()
					// made of it; OOCallByName ignores an object result (ADR-0055 Amendment 2).
					else  result = oo::PListObject(((id (*)(id, SEL))method)(object, selector));
					if (selectorString.has_value() && oo::str::hasSuffix(*selectorString, "_bool"))
					{
						// OOBooleanFromObject(result, NO): a string or number reads as oo::plist_get::boolFrom
						// does (bead oo-2764); any other object answers -boolValue / -intValue if it can.
						id resultObject = oo::ObjectIn(result);
						bool boolResult = NO;
						if (result.type() != oo::PList::Type::Object)  boolResult = oo::plist_get::boolFrom(!result.isNull() ? &result : nullptr, NO);
						else if ([resultObject respondsToSelector:@selector(boolValue)])  boolResult = [resultObject boolValue];
						else if ([resultObject respondsToSelector:@selector(intValue)])  boolResult = [resultObject intValue] != 0;
						result = oo::PList(boolResult);
					}
					break;
					
				case kMethodTypeVoidVoid:
					OOCallByName(object, selector);
					break;
					
				case kMethodTypeCharVoid:
				case kMethodTypeUnsignedCharVoid:
				case kMethodTypeShortVoid:
				case kMethodTypeUnsignedShortVoid:
				case kMethodTypeIntVoid:
				case kMethodTypeUnsignedIntVoid:
				case kMethodTypeLongVoid:
					result = oo::PList::signedInteger(OOCallIntegerMethod(object, selector, method, (OOShaderUniformType)type));
					break;
					
				case kMethodTypeUnsignedLongVoid:
					result = oo::PList::unsignedInteger(OOCallIntegerMethod(object, selector, method, (OOShaderUniformType)type));
					break;
					
				case kMethodTypeFloatVoid:
				case kMethodTypeDoubleVoid:
					result = oo::PList(static_cast<double>(OOCallFloatMethod(object, selector, method, (OOShaderUniformType)type)));
					break;
					
				case kMethodTypeVectorVoid:
				{
					Vector v = ((VectorReturnMsgSend)method)(object, selector);
					*outResult = ooscript::objectValue(JSVectorWithVector(context, v));
					break;
				}
					
				case kMethodTypeQuaternionVoid:
				{
					Quaternion q = ((QuaternionReturnMsgSend)method)(object, selector);
					*outResult = ooscript::objectValue(JSQuaternionWithQuaternion(context, q));
					break;
				}
					
				case kMethodTypeMatrixVoid:
				case kMethodTypePointVoid:
				case kMethodTypeInvalid:
					cxx_OOJSReportError(context, "%s.callObjC(): method %s cannot be called from JavaScript.", oo_jsClassName.c_str(), (selectorString ? selectorString->c_str() : "(null)"));
					error = YES;
					break;
			}
			if (!result.isNull())
			{
				*outResult = OOJSValueFromPList(context, result);	// a Foundation result's PList form, as OOJSValueFromNativeObject gave it (ADR-0051)
			}
		}
	}
	else
	{
		cxx_OOJSReportError(context, "%s.callObjC(): %s does not respond to method %s.", oo_jsClassName.c_str(), oo::ShortDescriptionOf(object).c_str(), (selectorString ? selectorString->c_str() : "(null)"));
		error = YES;
	}
	
	return !error;
	
	OOJS_PROFILE_EXIT
}


// Template class providing method type encodings for the signatures matched here.
@interface OOJSCallMethodSignatureTemplateClass: OOObject

- (void)voidVoidMethod;
- (void)voidStringMethod:(const std::string &)string;
- (oo::PList)pListStringMethod:(const std::string &)string;
- (oo::PList)pListVoidMethod;

@end


static BOOL SameTypeEncoding(char *a, char *b)
{
	BOOL result = (a != NULL && b != NULL && strcmp(a, b) == 0);
	free(a);
	free(b);
	return result;
}


/*	Whether method has the same signature as the template's method for selector: the same
	return type and the same argument types, as the method signature objects' -isEqual:
	compared them (bead oo-3rb.15; offsets and frame size are not compared).
*/
static BOOL SignatureMatch(Method method, SEL selector)
{
	Method methodTemplate = class_getInstanceMethod([OOJSCallMethodSignatureTemplateClass class], selector);

	if (method == NULL || methodTemplate == NULL)  return NO;

	unsigned argCount = method_getNumberOfArguments(method);
	if (argCount != method_getNumberOfArguments(methodTemplate))  return NO;
	if (!SameTypeEncoding(method_copyReturnType(method), method_copyReturnType(methodTemplate)))  return NO;
	for (unsigned i = 0; i < argCount; i++)
	{
		if (!SameTypeEncoding(method_copyArgumentType(method, i), method_copyArgumentType(methodTemplate, i)))  return NO;
	}
	return YES;
}


static MethodType GetMethodType(id object, SEL selector)
{
	Method method = class_getInstanceMethod(object_getClass(object), selector);

	if (SignatureMatch(method, @selector(voidVoidMethod)))  return kMethodTypeVoidVoid;
	// The C++ signatures of a selector called by name (ADR-0055 item 5), which OOCallByName calls:
	// the joined string argument, a PList result. oo-qps.72 deleted the id-parameter forms
	// (-voidObjectMethod:, -objectObjectMethod:): OOCallByName no longer passes an object.
	if (SignatureMatch(method, @selector(voidStringMethod:)))  return kMethodTypeVoidObject;
	if (SignatureMatch(method, @selector(pListStringMethod:)))  return kMethodTypeObjectObject;
	if (SignatureMatch(method, @selector(pListVoidMethod)))  return kMethodTypePListVoid;

	MethodType type = (MethodType)OOShaderUniformTypeFromMethod(method);
	if (type != kMethodTypeInvalid)  return type;
	
	return kMethodTypeInvalid;
}


@implementation OOJSCallMethodSignatureTemplateClass: OOObject

- (void)voidVoidMethod {}


- (void)voidStringMethod:(const std::string &)string {}


- (oo::PList)pListStringMethod:(const std::string &)string { return oo::PList(); }


- (oo::PList)pListVoidMethod { return oo::PList(); }

@end

#endif
