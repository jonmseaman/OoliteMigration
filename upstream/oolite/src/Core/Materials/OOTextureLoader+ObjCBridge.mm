/*

OOTextureLoader+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendments oo-whzh, oo-bj8 and oo-zl36): the Objective-C
OOTextureLoader facade over cxx::OOTextureLoader, and the adapter that is an Objective-C loader's
C++ part. Every method forwards in one line. Deleted, with OOTextureLoader+ObjCBridge.h, by the
bridge's deletion bead.


Copyright (C) 2007-2014 Jens Ayton

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

#import "OOTextureLoader.h"
#import "OODescription.h"
#include "oofnd/String.hpp"
#include "oofnd/objc/OOObjCPeer.h"
#include "oofnd/objc/OORuntime.h"

#include <cstdlib>
#include <cxxabi.h>
#include <typeinfo>


namespace {

// Never destroyed: a facade may be released while the process exits.
oo::ObjCPeers &Peers()
{
	static oo::ObjCPeers *peers = new oo::ObjCPeers;
	return *peers;
}


/*	The C++ part of an Objective-C loader: each virtual member messages the Objective-C object, so
	the subclass's override runs, as it did when the base class was Objective-C. The Objective-C
	object owns this (its _cxxLoader) and is not retained by it; its -dealloc clears the pointer,
	after which the members answer as a message to nil did. -loadTexture is sent on a work thread,
	as it was.
*/
class ObjCTextureLoader final : public cxx::OOTextureLoader
{
public:
	explicit ObjCTextureLoader(::OOTextureLoader *owner) : _owner(owner) {}

	::OOTextureLoader *owner()		{ return _owner; }
	void ownerDeallocated()			{ _owner = nil; }

	bool getResult(OOPixMap *result, OOTextureDataFormat *outFormat, uint32_t *outWidth, uint32_t *outHeight) override
	{
		return [_owner getResult:result format:outFormat originalWidth:outWidth originalHeight:outHeight];
	}
	std::optional<std::string> cacheKey() override						{ return [_owner cxx_cacheKey]; }
	void loadTexture() override											{ [_owner loadTexture]; }
	std::optional<std::string> descriptionComponents() const override		{ return [_owner cxx_descriptionComponents]; }
	std::optional<std::string> shortDescriptionComponents() const override	{ return [_owner cxx_shortDescriptionComponents]; }

private:
	::OOTextureLoader *_owner = {};	// Not retained.
};


ObjCTextureLoader *AsObjCTextureLoader(cxx::OOTextureLoader *loader)
{
	return dynamic_cast<ObjCTextureLoader *>(loader);
}


std::string DemangledName(cxx::OOTextureLoader &loader)
{
	int status = 0;
	char *demangled = abi::__cxa_demangle(typeid(loader).name(), nullptr, nullptr, &status);
	std::string result = (status == 0 && demangled != nullptr) ? demangled : typeid(loader).name();
	std::free(demangled);
	return result;
}


// The C++ class's name, as [self class] named an Objective-C loader's class ("cxx::" dropped).
std::string ClassName(cxx::OOTextureLoader &loader)
{
	std::string result = DemangledName(loader);
	if (result.starts_with("cxx::"))  result.erase(0, 5);
	return result;
}


/*	The class of a C++ loader's facade: a converted subclass in namespace cxx that its callers
	message by its own selectors has a facade of its own, the Objective-C class of the same name,
	a subclass of this one (amendment oo-up4b item 3). Any other C++ loader is an OOTextureLoader.
*/
Class FacadeClass(cxx::OOTextureLoader &loader)
{
	const std::string name = DemangledName(loader);
	if (name.starts_with("cxx::"))
	{
		Class facade = OOClassFromName(std::string_view(name).substr(5));
		if (facade != Nil && [facade isSubclassOfClass:[OOTextureLoader class]])  return facade;
	}
	return [OOTextureLoader class];
}

}	// namespace


@interface OOTextureLoader (OOObjCBridgePrivate)

- (id) initWithCxxLoader:(cxx::OOTextureLoader *)loader;

@end


@implementation OOTextureLoader

// Inside the @implementation for the protected ivar.
OOTextureLoader *oo::ToObjC(cxx::OOTextureLoader *loader)
{
	if (ObjCTextureLoader *objCLoader = AsObjCTextureLoader(loader))  return [[objCLoader->owner() retain] autorelease];
	if (loader == nullptr)  return nil;
	Class facadeClass = FacadeClass(*loader);
	return Peers().peerFor(loader, [loader, facadeClass] { return [[facadeClass alloc] initWithCxxLoader:loader]; });
}


cxx::OOTextureLoader *oo::ToCxx(OOTextureLoader *loader)
{
	if (loader == nil)  return nullptr;
	return loader->_cxxLoader.get();
}


+ (id)cxx_loaderWithPath:(const std::optional<std::string> &)inPath options:(uint32_t)options
{
	return [[cxx::OOTextureLoader::loaderWithPath(inPath, options).get() retain] autorelease];
}


+ (id)cxx_loaderWithTextureSpecifier:(const oo::PList &)specifier extraOptions:(uint32_t)extraOptions folder:(const std::optional<std::string> &)folder
{
	return [[cxx::OOTextureLoader::loaderWithTextureSpecifier(specifier, extraOptions, folder).get() retain] autorelease];
}


// An Objective-C loader: [[X alloc] init] of a subclass (or of this class).
- (id) init
{
	self = [super init];
	if (self != nil)  _cxxLoader = oo::makeRef<ObjCTextureLoader>(self);
	return self;
}


// An Objective-C loader's designated initialiser: its C++ part, then the old body on it.
- (id)cxx_initWithPath:(const std::optional<std::string> &)inPath options:(uint32_t)options
{
	self = [super init];
	if (self == nil)  return nil;
	_cxxLoader = oo::makeRef<ObjCTextureLoader>(self);

	if (!_cxxLoader->initWithPath(inPath, options))
	{
		[self release];
		return nil;
	}

	return self;
}


// A C++ loader's facade (oo::ToObjC).
- (id) initWithCxxLoader:(cxx::OOTextureLoader *)loader
{
	self = [super init];
	if (self != nil)  _cxxLoader = oo::Ref<cxx::OOTextureLoader>(loader);
	return self;
}


// A converted subclass's facade, made by its initialiser: the new C++ loader, and this is its peer.
- (id) initWithNewCxxLoader:(const oo::Ref<cxx::OOTextureLoader> &)loader
{
	self = [super init];
	if (self != nil)
	{
		_cxxLoader = loader;
		@autoreleasepool
		{
			Peers().peerFor(_cxxLoader.get(), [self] { return [self retain]; });
		}
	}
	return self;
}


// The pixels not handed over are freed with the C++ part, after this.
- (void) dealloc
{
	if (ObjCTextureLoader *objCLoader = AsObjCTextureLoader(_cxxLoader.get()))  objCLoader->ownerDeallocated();
	else  Peers().forget(_cxxLoader.get());
	[super dealloc];
}


// A C++ loader's facade describes itself with the C++ class's name and components.
- (std::optional<std::string>) cxx_description
{
	if (AsObjCTextureLoader(_cxxLoader.get()) != nullptr)  return [super cxx_description];
	std::string result = oo::str::format("<%s %s>", ClassName(*_cxxLoader).c_str(), oo::str::pointerDescription(self).c_str());
	if (const std::optional<std::string> components = _cxxLoader->descriptionComponents())  result += "{" + *components + "}";
	return result;
}


/*	The descriptions. On an Objective-C loader that does not override them, the base class's own
	member answers; on a C++ loader's facade, the C++ override.
*/
- (std::optional<std::string>) cxx_descriptionComponents
{
	if (AsObjCTextureLoader(_cxxLoader.get()) != nullptr)  return _cxxLoader->cxx::OOTextureLoader::descriptionComponents();
	return _cxxLoader->descriptionComponents();
}


- (std::optional<std::string>) cxx_shortDescriptionComponents
{
	if (AsObjCTextureLoader(_cxxLoader.get()) != nullptr)  return _cxxLoader->cxx::OOTextureLoader::shortDescriptionComponents();
	return _cxxLoader->shortDescriptionComponents();
}


- (std::optional<std::string>)cxx_path
{
	return _cxxLoader->path();
}


- (BOOL)isReady
{
	return _cxxLoader->isReady();
}


/*	The overridable methods. On an Objective-C loader these are reached only when the subclass
	does not override them, or by [super ...]: the base class's own member answers. On a C++
	loader's facade the C++ override answers.
*/

- (BOOL) getResult:(OOPixMap *)result
			format:(OOTextureDataFormat *)outFormat
	 originalWidth:(uint32_t *)outWidth
	originalHeight:(uint32_t *)outHeight
{
	if (AsObjCTextureLoader(_cxxLoader.get()) != nullptr)  return _cxxLoader->cxx::OOTextureLoader::getResult(result, outFormat, outWidth, outHeight);
	return _cxxLoader->getResult(result, outFormat, outWidth, outHeight);
}


- (std::optional<std::string>) cxx_cacheKey
{
	if (AsObjCTextureLoader(_cxxLoader.get()) != nullptr)  return _cxxLoader->cxx::OOTextureLoader::cacheKey();
	return _cxxLoader->cacheKey();
}


- (void)loadTexture
{
	if (AsObjCTextureLoader(_cxxLoader.get()) != nullptr)  _cxxLoader->cxx::OOTextureLoader::loadTexture();
	else  _cxxLoader->loadTexture();
}


// OOAsyncWorkTask: the work manager sends these to the task, the Objective-C object.

- (void)performAsyncTask
{
	_cxxLoader->performAsyncTask();
}


- (void) completeAsyncTask
{
	_cxxLoader->completeAsyncTask();
}

@end
