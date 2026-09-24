/*	OOTCPStreamDecoderAbstractionLayer.h

	Abstraction layer to allow OOTCPStreamDecoder to work with CoreFoundation/
	CF-Lite, Cocoa Foundation or GNUstep Foundation.

	oofnd implementation (proposed ADR-0043 Amendment 2 item 14): each handle is a struct
	OOALObject holding its value as an oo::PList (a string, a data buffer or the parsed packet).
*/

#ifndef NDEBUG

#import "OOTCPStreamDecoderAbstractionLayer.h"
#import "OOCocoa.h"
#import "OOFoundationBridge.h"
#import <objc/runtime.h>
#import <objc/objc-arc.h>

#include "oofnd/PListParsing.hpp"
#include "oofnd/String.hpp"

#include "oofnd/StdLib.hpp"


struct OOALObject
{
	oo::PList value;
	// Borrowed handles given out for this object: its dictionary values and its type description.
	std::map<std::string, std::unique_ptr<OOALObject>, std::less<>> children;
	std::unique_ptr<OOALObject> typeDescription;
};


struct OOALAutoreleasePool
{
	void *objcPool = nullptr;
	std::vector<std::unique_ptr<OOALObject>> objects;
};


namespace {

// The innermost pools, innermost last (per thread, as autorelease pools are).
thread_local std::vector<OOALAutoreleasePool *> sPools;


OOALObject *NewObject(oo::PList value)
{
	auto *object = new OOALObject;
	object->value = std::move(value);
	return object;
}


// "%@" of a handle: what GNUstep printed for the object it stood for.
std::string DescriptionOf(OOALObjectRef object)
{
	if (object == nullptr)  return "(null)";
	if (const std::string *string = object->value.getIf<std::string>())  return *string;
	return oo::DescriptionOf(oo::ObjectFromPList(object->value));
}


// -initWithFormat:arguments: for the conversions OOTCPStreamDecoder.c uses: %u, %zu, %@ (a
// handle) and %%. Anything else is copied as it stands.
std::string FormatWithArguments(const std::string &format, va_list args)
{
	std::string out;
	for (std::size_t i = 0; i < format.size(); ++i)
	{
		const char c = format[i];
		if (c != '%' || i + 1 == format.size())
		{
			out += c;
			continue;
		}
		const char next = format[i + 1];
		if (next == '%')
		{
			out += '%';
			++i;
		}
		else if (next == 'u')
		{
			out += std::to_string(va_arg(args, unsigned));
			++i;
		}
		else if (next == 'z' && i + 2 < format.size() && format[i + 2] == 'u')
		{
			out += std::to_string(va_arg(args, size_t));
			i += 2;
		}
		else if (next == '@')
		{
			out += DescriptionOf(va_arg(args, OOALObjectRef));
			++i;
		}
		else
		{
			out += c;
		}
	}
	return out;
}

}	// namespace


// Simulate literal CF/NS strings. Each literal string that is used becomes a single object. Since it uses pointers as keys, it should only be used with literals.
// Called from OOTCPStreamDecoder.c through OOALSTR(), so it keeps C linkage now that this file is Objective-C++ (bead oo-x7o).
extern "C" OOALStringRef OOALGetConstantString(const char *string);
OOALStringRef OOALGetConstantString(const char *string)
{
	static std::map<const char *, std::unique_ptr<OOALObject>> *sStrings = nullptr;

	if (sStrings == nullptr)
	{
		sStrings = new std::map<const char *, std::unique_ptr<OOALObject>>;
	}

	std::unique_ptr<OOALObject> &value = (*sStrings)[string];
	if (value == nullptr)
	{
		// Note: non-ASCII strings are not permitted, but we don't bother to detect them.
		value.reset(NewObject(oo::PList(std::string(string))));
	}

	return value.get();
}


void OOALRelease(OOALObjectRef object)
{
	delete object;
}


OOALStringRef OOTypeDescription(OOALObjectRef object)
{
	// The class name of the object the handle stood for ([[object class] description]).
	auto *mutableObject = const_cast<OOALObject *>(object);
	if (mutableObject->typeDescription == nullptr)
	{
		mutableObject->typeDescription.reset(NewObject(oo::PList(oo::DescriptionOf([oo::ObjectFromPList(object->value) class]))));
	}
	return mutableObject->typeDescription.get();
}


bool OOALIsString(OOALObjectRef object)
{
	return object->value.isString();
}


OOALStringRef OOALStringCreateWithFormatAndArguments(OOALStringRef format, va_list args)
{
	return NewObject(oo::PList(FormatWithArguments(DescriptionOf(format), args)));
}


bool OOALIsDictionary(OOALObjectRef object)
{
	return object->value.isDict();
}


OOALObjectRef OOALDictionaryGetValue(OOALDictionaryRef dictionary, OOALObjectRef key)
{
	const std::string *keyString = key->value.getIf<std::string>();
	if (keyString == nullptr)  return nullptr;
	const oo::PList *value = dictionary->value.find(*keyString);
	if (value == nullptr)  return nullptr;

	auto *parent = const_cast<OOALObject *>(dictionary);
	std::unique_ptr<OOALObject> &child = parent->children[*keyString];
	if (child == nullptr)  child.reset(NewObject(*value));
	return child.get();
}


bool OOALIsData(OOALObjectRef object)
{
	return object->value.isData();
}


OOALMutableDataRef OOALDataCreateMutable(size_t capacity)
{
	(void)capacity;
	return NewObject(oo::PList(oo::Data()));
}


void OOALMutableDataAppendBytes(OOALMutableDataRef data, const void *bytes, size_t length)
{
	data->value.getIf<oo::PList::Data>()->append(bytes, length);
}


const void *OOALDataGetBytePtr(OOALDataRef data)
{
	return data->value.getIf<oo::PList::Data>()->bytes();
}


size_t OOALDataGetLength(OOALDataRef data)
{
	return data->value.getIf<oo::PList::Data>()->length();
}


OOALAutoreleasePoolRef OOALCreateAutoreleasePool(void)
{
	auto *pool = new OOALAutoreleasePool;
	pool->objcPool = objc_autoreleasePoolPush();
	sPools.push_back(pool);
	return pool;
}


void OOALDestroyAutoreleasePool(OOALAutoreleasePoolRef pool)
{
	if (!sPools.empty() && sPools.back() == pool)  sPools.pop_back();
	objc_autoreleasePoolPop(pool->objcPool);
	delete pool;
}


OOALObjectRef OOALPropertyListFromData(OOALMutableDataRef data, OOALStringRef *errStr)
{
	const oo::Data &bytes = *data->value.getIf<oo::PList::Data>();
	oo::Expected<oo::PList, oo::PListError> parsed = oo::parsePropertyList(std::string_view(reinterpret_cast<const char *>(bytes.bytes()), bytes.length()));
	if (!parsed || parsed->isNull())
	{
		// The error string is owned by the caller (+1); no error text reads as nil did.
		if (errStr != nullptr)  *errStr = parsed ? nullptr : NewObject(oo::PList(parsed.error().description()));
		return nullptr;
	}

	OOALObject *result = NewObject(std::move(*parsed));
	// Belongs to the innermost pool (the decoder never releases a packet).
	if (!sPools.empty())  sPools.back()->objects.emplace_back(result);
	return result;
}


const oo::PList &OOALObjectPList(OOALObjectRef object)
{
	return object->value;
}

#endif /* NDEBUG */
