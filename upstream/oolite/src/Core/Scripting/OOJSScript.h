/*

OOJSScript.h

JavaScript support for Oolite
Copyright (C) 2007-2013 David Taylor and Jens Ayton.

C++20 since bead oo-u61e.4 (proposed ADR-0056, the OOColor house style), a subclass of
cxx::OOScript (bead oo-604l). Its Objective-C facade was deleted by bead oo-9ht.137 (ADR-0056
amendments oo-9ht.12 item 6 and oo-9ht.137): the class is global, and its object (its identity: the
JS object, the stack of running scripts and the weak references hold it) is the OOScript root's
facade, made once by scriptWithPath() and owning the C++ script; oo::ToObjC answers it. That facade
answers what the deleted one did for a JS script (OOScript+ObjCBridge.h: -callMethod:..., the weak
reference support, the JS glue, -dealloc's willDealloc()).

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

#ifndef OOJSSCRIPT_H
#define OOJSSCRIPT_H

#import "OOScript.h"
#import "OOJavaScriptEngine.h"
#include "oofnd/Notification.hpp"

// The script property that holds the identifier of the manifest the script was loaded under.
inline constexpr char kLocalManifestProperty[] = "oolite_manifest_identifier";

@class OOWeakReference;


class OOJSScript : public cxx::OOScript
{
public:
	// +scriptWithPath:properties:: a new script and its Objective-C object (the OOScript root's
	// facade, its identity), autoreleased; nil when the script could not be loaded. path nullopt is
	// nil (the script is then named after its address); properties may hold live objects.
	static ::OOScript *scriptWithPath(const std::optional<std::string> &path, const oo::PList &properties);

	// The old -initWithPath:properties: after [super init], run by scriptWithPath() once the object
	// is the peer; false: the script could not be loaded, and the object is released.
	bool initWithPath(const std::optional<std::string> &path, const oo::PList &properties);
	// The old -dealloc before [super dealloc], run by the object's -dealloc.
	void willDealloc();

	// The running scripts' Objective-C objects (the stack holds only JS scripts, or nil).
	static ::OOScript *currentlyRunningScript();
	static std::vector<oo::ObjCRef<::OOScript *>> scriptStack();

	/*	External manipulation of acrtive script stack. Used, for instance, by
		timers. Failing to balance these will crash!
		Passing a nil script is valid for cases where JS is used which is not
		attached to a specific script.
	*/
	static void pushScript(::OOScript *script);
	static void popScript(::OOScript *script);

	/*	Call a method.
		Requires a request on context.
		outResult may be NULL.
	*/
	bool callMethod(ooscript::PropertyId methodID, ooscript::Context context, ooscript::Value *argv, int argc, ooscript::Value *outResult);

	// The property as cxx_OOJSPListFromJSValue() converts it; null when there is no script object or it could not be read.
	oo::PList propertyWithID(ooscript::PropertyId propID, ooscript::Context context);
	// Set a property which can be modified or deleted by the script.
	bool setProperty(const oo::PList &value, ooscript::PropertyId propID, ooscript::Context context);
	// Set a special property which cannot be modified or deleted by the script.
	bool defineProperty(const oo::PList &value, ooscript::PropertyId propID, ooscript::Context context);

	oo::PList propertyNamed(const std::string &name);
	bool setProperty(const oo::PList &value, const std::string &name);
	bool defineProperty(const oo::PList &value, const std::string &name);

	// OOWeakReferenceSupport and the JS glue of OOObject, which the object answers for a JS script.
	id weakRetain();
	void weakRefDied(::OOWeakReference *weakRef);
	std::optional<std::string> jsClassName();
	ooscript::Value jsValueInContext(ooscript::Context context);

	// OOScript
	std::optional<std::string> descriptionComponents() override;
	std::optional<std::string> name() override;
	std::optional<std::string> scriptDescription() override;
	std::optional<std::string> version() override;
	void runWithTarget(::Entity *target) override;

private:
	void javaScriptEngineWillReset(const oo::Notification &notification);
	std::string scriptNameFromPath(const std::optional<std::string> &path);
	oo::PList::Dict defaultPropertiesFromPath(const std::optional<std::string> &path);

	ooscript::Object			_jsSelf = {};

	std::optional<std::string>	_name;
	std::optional<std::string>	_description;
	std::optional<std::string>	_version;
	std::optional<std::string>	_filePath;

	::OOWeakReference			*_weakSelf = nil;
};


OOJS_EXTERN_C void InitOOJSScript(ooscript::Context context, ooscript::Object global);


#endif	// OOJSSCRIPT_H
