/*

OOMaterial+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendment oo-smy): the Objective-C OOMaterial facade (see
OOMaterial+ObjCBridge.h). Every method forwards to its C++ member: arguments that were
OOMaterial * go through oo::ToCxx, results come back through oo::ToObjC. An Objective-C
subclass's C++ part is an ObjCMaterial, whose virtual members message the subclass. Deleted with
OOMaterial+ObjCBridge.h.


Copyright (C) 2007-2013 Jens Ayton and contributors

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

#import "OOMaterial.h"
#import "OODescription.h"
#include "oofnd/String.hpp"
#include "oofnd/objc/OOObjCPeer.h"

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


/*	The C++ part of an Objective-C material: each virtual member messages the Objective-C object,
	so the subclass's override runs, as it did when the base class was Objective-C. The
	Objective-C object owns this (its _cxxMaterial) and is not retained by it; its -dealloc clears
	the pointer, after which the members answer as a message to nil did.
*/
class ObjCMaterial final : public cxx::OOMaterial
{
public:
	explicit ObjCMaterial(::OOMaterial *owner) : _owner(owner) {}

	::OOMaterial *owner()	{ return _owner; }
	void ownerDeallocated()	{ _owner = nil; }

	std::optional<std::string> name() override								{ return [_owner cxx_name]; }
	std::optional<std::string> descriptionComponents() const override		{ return [_owner cxx_descriptionComponents]; }
	void ensureFinishedLoading() override									{ [_owner ensureFinishedLoading]; }
	bool isFinishedLoading() override										{ return [_owner isFinishedLoading]; }
	void setBindingTarget(id<OOWeakReferenceSupport> target) override		{ [_owner setBindingTarget:target]; }
	bool wantsNormalsAsTextureCoordinates() override						{ return [_owner wantsNormalsAsTextureCoordinates]; }
#if OO_MULTITEXTURE
	NSUInteger countOfTextureUnitsWithBaseCoordinates() override			{ return [_owner countOfTextureUnitsWithBaseCoordinates]; }
#endif
#ifndef NDEBUG
	std::vector<oo::ObjCRef<OOTexture *>> allTextures() override			{ return [_owner cxx_allTextures]; }
#endif
	bool doApply() override													{ return [_owner doApply]; }
	void unapplyWithNext(cxx::OOMaterial *next) override					{ [_owner unapplyWithNext:oo::ToObjC(next)]; }

private:
	::OOMaterial *_owner = {};	// Not retained.
};


ObjCMaterial *AsObjCMaterial(cxx::OOMaterial *material)
{
	return dynamic_cast<ObjCMaterial *>(material);
}


// The C++ class's name, as [self class] named an Objective-C material's class ("cxx::" dropped).
std::string ClassName(cxx::OOMaterial &material)
{
	int status = 0;
	char *demangled = abi::__cxa_demangle(typeid(material).name(), nullptr, nullptr, &status);
	std::string result = (status == 0 && demangled != nullptr) ? demangled : typeid(material).name();
	std::free(demangled);
	if (result.starts_with("cxx::"))  result.erase(0, 5);
	return result;
}

}	// namespace


@interface OOMaterial (OOObjCBridgePrivate)

- (id) initWithCxxMaterial:(cxx::OOMaterial *)material;

@end


@implementation OOMaterial

// Inside the @implementation for the private ivar.
OOMaterial *oo::ToObjC(cxx::OOMaterial *material)
{
	if (ObjCMaterial *objCMaterial = AsObjCMaterial(material))  return [[objCMaterial->owner() retain] autorelease];
	return Peers().peerFor(material, [material] { return [[OOMaterial alloc] initWithCxxMaterial:material]; });
}


cxx::OOMaterial *oo::ToCxx(OOMaterial *material)
{
	if (material == nil)  return nullptr;
	return material->_cxxMaterial.get();
}


// An Objective-C material: [[X alloc] init] of a subclass (or of this class).
- (id)init
{
	self = [super init];
	if (self != nil)  _cxxMaterial = oo::makeRef<ObjCMaterial>(self);
	return self;
}


// A C++ material's facade (oo::ToObjC).
- (id) initWithCxxMaterial:(cxx::OOMaterial *)material
{
	self = [super init];
	if (self != nil)  _cxxMaterial = oo::Ref<cxx::OOMaterial>(material);
	return self;
}


- (void)dealloc
{
	if (ObjCMaterial *objCMaterial = AsObjCMaterial(_cxxMaterial.get()))
	{
		// Ensure cleanup happens; doing it more than once is safe.
		[self willDealloc];
		objCMaterial->ownerDeallocated();
	}
	else  Peers().forget(_cxxMaterial.get());

	[super dealloc];
}


// On an Objective-C material this is reached only when the subclass does not override it, or by
// [super ...]: the base class's own member answers. On a C++ material's facade the C++ override does.
- (std::optional<std::string>) cxx_descriptionComponents
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  return _cxxMaterial->cxx::OOMaterial::descriptionComponents();
	return _cxxMaterial->descriptionComponents();
}


// A C++ material's facade describes itself with the C++ class's name.
- (std::optional<std::string>) cxx_description
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  return [super cxx_description];
	std::string result = oo::str::format("<%s %s>", ClassName(*_cxxMaterial).c_str(), oo::str::pointerDescription(self).c_str());
	if (const std::optional<std::string> components = _cxxMaterial->descriptionComponents())  result += "{" + *components + "}";
	return result;
}


+ (void)setUp						{ cxx::OOMaterial::setUp(); }
- (void)apply						{ _cxxMaterial->apply(); }
+ (void)applyNone					{ cxx::OOMaterial::applyNone(); }
+ (OOMaterial *)current				{ return oo::ToObjC(cxx::OOMaterial::current()); }


// The overridable methods: the same two cases as -cxx_descriptionComponents.

- (std::optional<std::string>)cxx_name
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  return _cxxMaterial->cxx::OOMaterial::name();
	return _cxxMaterial->name();
}


- (void)ensureFinishedLoading
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  _cxxMaterial->cxx::OOMaterial::ensureFinishedLoading();
	else  _cxxMaterial->ensureFinishedLoading();
}


- (BOOL) isFinishedLoading
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  return _cxxMaterial->cxx::OOMaterial::isFinishedLoading();
	return _cxxMaterial->isFinishedLoading();
}


- (void)setBindingTarget:(id<OOWeakReferenceSupport>)target
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  _cxxMaterial->cxx::OOMaterial::setBindingTarget(target);
	else  _cxxMaterial->setBindingTarget(target);
}


- (BOOL) wantsNormalsAsTextureCoordinates
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  return _cxxMaterial->cxx::OOMaterial::wantsNormalsAsTextureCoordinates();
	return _cxxMaterial->wantsNormalsAsTextureCoordinates();
}


#if OO_MULTITEXTURE
- (NSUInteger) countOfTextureUnitsWithBaseCoordinates
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  return _cxxMaterial->cxx::OOMaterial::countOfTextureUnitsWithBaseCoordinates();
	return _cxxMaterial->countOfTextureUnitsWithBaseCoordinates();
}
#endif


#ifndef NDEBUG
- (std::vector<oo::ObjCRef<OOTexture *>>) cxx_allTextures
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  return _cxxMaterial->cxx::OOMaterial::allTextures();
	return _cxxMaterial->allTextures();
}
#endif


- (BOOL)doApply
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  return _cxxMaterial->cxx::OOMaterial::doApply();
	return _cxxMaterial->doApply();
}


- (void)unapplyWithNext:(OOMaterial *)next
{
	if (AsObjCMaterial(_cxxMaterial.get()) != nullptr)  _cxxMaterial->cxx::OOMaterial::unapplyWithNext(oo::ToCxx(next));
	else  _cxxMaterial->unapplyWithNext(oo::ToCxx(next));
}


- (void)willDealloc					{ _cxxMaterial->willDealloc(); }

@end
