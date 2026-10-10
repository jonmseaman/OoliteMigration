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
#import "OOColor.h"	// a colour result (kMethodTypeColorVoid)
#include "oofnd/objc/OORuntime.h"
#import "OOJavaScriptEngine.h"
#import "OOCallByName.h"
#import "OOObjCPList.h"

#import "OOFunctionAttributes.h"
#import "ShipEntity.h"
#import "PlayerEntity.h"	// the statistics members of callObjC's name table
#import "OOShaderUniformMethodType.h"
#import "OOJSVector.h"
#import "OOJSQuaternion.h"
#import "OOJSCallEntityMethods.h"	// callObjC()'s names for an entity (generated; bead oo-9ht.44)
#include "oofnd/PListGet.hpp"
#include "oofnd/String.hpp"


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
	kMethodTypeColorVoid			= kOOShaderUniformTypeColor,	// a colour (OOColor *) since bead oo-9ht.1

	kMethodTypeObjectVoid			= kOOShaderUniformTypeObject,
	kMethodTypeObjectObject,
	kMethodTypeVoidVoid,
	kMethodTypeVoidObject,
	kMethodTypePListVoid
} MethodType;


static MethodType GetMethodType(id object, SEL selector);

namespace {
OOINLINE bool MethodExpectsParameter(MethodType type)	{ return type == kMethodTypeVoidObject || type == kMethodTypeObjectObject; }


#if OO_DEBUG
/*	callObjC()'s names that are C++ members (ADR-0056 amendment oo-9ht.15): exactly the selectors
	of the deleted categories PlayerEntity (JSVectorStatistics) and (JSQuaternionStatistics), with
	the signatures they had (a property-list result, or void), answered by the player only.
*/
struct CxxMethod
{
	const char		*name;
	oo::PList		(*pListVoid)();		// a -(oo::PList)name method, else null
	void			(*voidVoid)();		// a -(void)name method
};

const CxxMethod kPlayerMethods[] =
{
	{ "reportJSVectorStatistics",		&PlayerEntity::reportJSVectorStatistics,		nullptr },
	{ "clearJSVectorStatistics",		nullptr,	&PlayerEntity::clearJSVectorStatistics },
	{ "reportJSQuaternionStatistics",	&PlayerEntity::reportJSQuaternionStatistics,	nullptr },
	{ "clearJSQuaternionStatistics",	nullptr,	&PlayerEntity::clearJSQuaternionStatistics },
};


// The table's entry for name when object is the player (it answered the categories), else null.
// The player is C++ since bead oo-9ht.177; object is its Objective-C object (a ship's).
const CxxMethod *CxxMethodNamed(id object, const std::optional<std::string> &name)
{
	if (!name.has_value() || PLAYER == nullptr || object != oo::ToObjC(PLAYER))  return nullptr;
	for (const CxxMethod &method : kPlayerMethods)
	{
		if (*name == method.name)  return &method;
	}
	return nullptr;
}
#endif
} // namespace


namespace {
// The table's row for name (bead oo-9ht.44); null for a name it does not list.
const OOJSCallEntityMethodRow *EntityMethodNamed(const std::optional<std::string> &name)
{
	if (!name.has_value())  return nullptr;
	for (const OOJSCallEntityMethodRow &row : kOOJSCallEntityMethods)
	{
		if (*name == row.name)  return &row;
	}
	return nullptr;
}


// The row's signature, as GetMethodType() classified the method it was generated from.
MethodType MethodTypeOfRow(const OOJSCallEntityMethodRow &row)
{
	switch (row.form)
	{
		case OOJSCallEntityMethodForm::VoidVoid:	return kMethodTypeVoidVoid;
		case OOJSCallEntityMethodForm::VoidString:	return kMethodTypeVoidObject;
		case OOJSCallEntityMethodForm::PListString:	return kMethodTypeObjectObject;
		case OOJSCallEntityMethodForm::PListVoid:	return kMethodTypePListVoid;
		case OOJSCallEntityMethodForm::Typed:		return (MethodType)OOShaderUniformTypeFromEncoding(row.encoding);
	}
	return kMethodTypeInvalid;
}


// -boolValue, else -intValue, of a "_bool" method's object result, if it answers one (what the
// scalar-value protocol of the deleted bridge declared); false if it answers neither.
bool ScalarBoolValue(id object)
{
	SEL boolValue = OOSelectorFromName("boolValue"), intValue = OOSelectorFromName("intValue");
	if ([object respondsToSelector:boolValue])  return ((BOOL (*)(id, SEL))[object methodForSelector:boolValue])(object, boolValue);
	if ([object respondsToSelector:intValue])  return ((int (*)(id, SEL))[object methodForSelector:intValue])(object, intValue) != 0;
	return false;
}


/*	The call: of any object by its method's signature (OOJSCallObjCObjectMethod), or of an entity's
	object by the entity table (entityTable): a name the table does not list does not respond, and
	a listed one is called with the table's signature.
*/
bool CallMethod(ooscript::Context context, id object, const std::string &oo_jsClassName, unsigned argc, ooscript::Value *argv, ooscript::Value *outResult, bool entityTable)
{
	OOJS_PROFILE_ENTER
	
	std::optional<std::string>	selectorString;
	SEL						selector = NULL;
	std::optional<std::string>	paramString;
	MethodType				type;
	bool					haveParameter = false,
							error = false;
	oo::PList				result;		// null for none
	
	if (argc == 0)
	{
		cxx_OOJSReportError(context, "%s.callObjC(): no selector specified.", oo_jsClassName.c_str());
		return false;
	}
	
	if ((oo::ToShip(object) != nullptr))
	{
		if (PLAYER != nullptr)  PLAYER->PlayerEntity::setScriptTarget(oo::ToShip(object));	// qualified: the final overrider (bead oo-9ht.177), so the binding test stands in for it
	}
	
	selectorString = cxx_OOStringFromJSValue(context, argv[0]);
	
	// Join all parameters together with spaces.
	if (1 < argc && selectorString.has_value() && oo::str::hasSuffix(*selectorString, ":"))
	{
		haveParameter = true;
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
	
#if OO_DEBUG
	if (const CxxMethod *cxxMethod = CxxMethodNamed(object, selectorString))
	{
		// As the category's method was called: a property-list result as kMethodTypePListVoid's
		// (no name in the table ends in "_bool"), a void method leaves the result alone.
		if (cxxMethod->pListVoid != nullptr)  result = cxxMethod->pListVoid();
		else  cxxMethod->voidVoid();
		if (!result.isNull())  *outResult = OOJSValueFromPList(context, result);
	}
	else
#endif
	if (const OOJSCallEntityMethodRow *row = entityTable ? EntityMethodNamed(selectorString) : nullptr; (!entityTable || row != nullptr) && [object respondsToSelector:selector])
	{
		// Validate signature: the table's for an entity (bead oo-9ht.44), else the method's.
		type = (row != nullptr) ? MethodTypeOfRow(*row) : GetMethodType(object, selector);
		
		if (MethodExpectsParameter(type) && !haveParameter)
		{
			cxx_OOJSReportError(context, "%s.callObjC(): method %s requires a parameter.", oo_jsClassName.c_str(), (selectorString ? selectorString->c_str() : "(null)"));
			error = true;
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
					
				case kMethodTypeColorVoid:
					// A colour result is its PList::Object node, as the colour's facade's was (bead oo-9ht.1).
					result = OOColorObjectNode(((ColorReturnMsgSend)method)(object, selector));
					if (selectorString.has_value() && oo::str::hasSuffix(*selectorString, "_bool"))  result = oo::PList(false);	// a colour answered neither -boolValue nor -intValue
					break;

				case kMethodTypeObjectVoid:
				case kMethodTypePListVoid:
					if (type == kMethodTypePListVoid)  result = OOCallByName(object, selector);
					// An object result (a ship, a colour) is its PList::Object node, as oo::PListFrom()
					// made of it; OOCallByName ignores an object result (ADR-0055 Amendment 2).
					else  result = oo::PListObject(((id (*)(id, SEL))method)(object, selector));
					if (selectorString.has_value() && oo::str::hasSuffix(*selectorString, "_bool"))
					{
						// OOBooleanFromObject(result, false): a string or number reads as oo::plist_get::boolFrom
						// does (bead oo-2764); any other object answers -boolValue / -intValue if it can.
						id resultObject = oo::ObjectIn(result);
						bool boolResult = false;
						if (result.type() != oo::PList::Type::Object)  boolResult = oo::plist_get::boolFrom(!result.isNull() ? &result : nullptr, false);
						else  boolResult = ScalarBoolValue(resultObject);
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
					error = true;
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
		error = true;
	}
	
	return !error;
	
	OOJS_PROFILE_EXIT
}
} // namespace


bool OOJSCallObjCObjectMethod(ooscript::Context context, id object, const std::string &oo_jsClassName, unsigned argc, ooscript::Value *argv, ooscript::Value *outResult)
{
	return CallMethod(context, object, oo_jsClassName, argc, argv, outResult, false);
}


bool OOJSCallEntityMethod(ooscript::Context context, cxx::Entity *entity, const std::string &oo_jsClassName, unsigned argc, ooscript::Value *argv, ooscript::Value *outResult)
{
	return CallMethod(context, oo::ToObjC(entity), oo_jsClassName, argc, argv, outResult, true);
}




/*	Whether method has the signature returnType (self, _cmd[, argument]): the same return type and
	the same argument types, as the method signature objects' -isEqual: compared them (bead
	oo-3rb.15; offsets and frame size are not compared). The template class whose methods gave
	these encodings went with the bridge (bead oo-9ht.44): they are @encode() of the same types.
*/
namespace {
static bool SameTypeEncoding(char *copied, const char *expected)
{
	bool result = (copied != NULL && expected != NULL && strcmp(copied, expected) == 0);
	free(copied);
	return result;
}


static bool SignatureMatch(Method method, const char *returnType, const char *argument)
{
	if (method == NULL)  return false;

	const char *arguments[] = { @encode(id), @encode(SEL), argument };
	unsigned argCount = method_getNumberOfArguments(method);
	if (argCount != (argument != NULL ? 3u : 2u))  return false;
	if (!SameTypeEncoding(method_copyReturnType(method), returnType))  return false;
	for (unsigned i = 0; i < argCount; i++)
	{
		if (!SameTypeEncoding(method_copyArgumentType(method, i), arguments[i]))  return false;
	}
	return true;
}
} // namespace


static MethodType GetMethodType(id object, SEL selector)
{
	Method method = class_getInstanceMethod(object_getClass(object), selector);

	if (SignatureMatch(method, @encode(void), NULL))  return kMethodTypeVoidVoid;
	// The C++ signatures of a selector called by name (ADR-0055 item 5), which OOCallByName calls:
	// the joined string argument, a PList result. oo-qps.72 deleted the id-parameter forms
	// (-voidObjectMethod:, -objectObjectMethod:): OOCallByName no longer passes an object.
	if (SignatureMatch(method, @encode(void), @encode(const std::string &)))  return kMethodTypeVoidObject;
	if (SignatureMatch(method, @encode(oo::PList), @encode(const std::string &)))  return kMethodTypeObjectObject;
	if (SignatureMatch(method, @encode(oo::PList), NULL))  return kMethodTypePListVoid;

	MethodType type = (MethodType)OOShaderUniformTypeFromMethod(method);
	if (type != kMethodTypeInvalid)  return type;
	
	return kMethodTypeInvalid;
}



#endif
