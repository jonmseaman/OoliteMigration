/*

OOMaterial+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, amendment oo-smy): the Objective-C OOMaterial, a facade over the
C++ cxx::OOMaterial (OOMaterial.h), for the callers that message materials and for the materials
not converted yet (OOBasicMaterial and the three under it). Its interface is the one OOMaterial.h
declared before the conversion, copied exactly (same selectors, same types), so they compile and
behave unchanged. Imported as the last line of OOMaterial.h; do not import it directly.

It is a hierarchy root's facade, as OOOXPVerifierStage+ObjCBridge.h is (ADR-0056 Amendment 1):

	the material is                      its facade is                      virtual calls on the
	                                                                          C++ side reach
	-----------------------------------  ---------------------------------  ---------------------
	an Objective-C subclass              the subclass instance itself; its  the subclass's
	  (unconverted, [[X alloc] init])    -init made its C++ part, an        methods (-doApply,
	                                     adapter that forwards the virtual  -unapplyWithNext:,
	                                     members to it                      -cxx_name, ...)
	a C++ subclass (converted)           made by oo::ToObjC, one live one   the C++ overrides
	                                     per material (oo::ObjCPeers)

An Objective-C subclass's [super doApply] (and every other overridable method) reaches the C++
base class's own member, not the virtual one, so it does what the base did.

	a caller that is                       holds / passes                   crosses with
	-------------------------------------  -------------------------------  -----------------------
	still Objective-C                      OOMaterial * (this facade)       nothing
	converted (C++), calling               cxx::OOMaterial * (borrowed)
	  handing a material to Objective-C                                     oo::ToObjC(material)
	  taking one from Objective-C                                           oo::ToCxx(objcMaterial)
	converted (C++), keeping one           oo::ObjCRef<OOMaterial *>        oo::ToObjC / oo::ToCxx
	  while any subclass is Objective-C    (an Objective-C material's C++
	                                       part does not retain it)

oo::ToObjC(oo::ToCxx(m)) == m for both kinds. Never add to this file; converted code does not
message the facade. Deleted by its deletion bead once every caller and every material is C++.


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

#ifndef OOMATERIAL_OBJCBRIDGE_H
#define OOMATERIAL_OBJCBRIDGE_H


@interface OOMaterial: OOObject
{
@private
	oo::Ref<cxx::OOMaterial>	_cxxMaterial;
}

// Called once at startup (by -[Universe init]).
+ (void) setUp;

- (std::optional<std::string>) cxx_name;	// nullopt: none (bead oo-3rb.289.5)

// Make this the current material.
- (void) apply;

/*	Make no material the current material, tearing down anything set up by the
	current material.
*/
+ (void) applyNone;

/*	Get current material.
*/
+ (OOMaterial *) current;

/*	Ensure material is ready to be used in a display list. This is not
	required before using a material directly.
*/
- (void) ensureFinishedLoading;
- (BOOL) isFinishedLoading;

// Only used by shader material, but defined for all materials for convenience.
- (void) setBindingTarget:(id<OOWeakReferenceSupport>)target;

// True if material wants three-component cube map texture coordinates.
- (BOOL) wantsNormalsAsTextureCoordinates;

#if OO_MULTITEXTURE
// Nasty hack: number of texture units for which the drawable should set its basic texture coordinates.
- (NSUInteger) countOfTextureUnitsWithBaseCoordinates;
#endif

#ifndef NDEBUG
- (std::vector<oo::ObjCRef<OOTexture *>>) cxx_allTextures;
#endif

@end

@interface OOMaterial (OOSubclassInterface)

// Subclass responsibilities - don't call directly.
- (BOOL) doApply;	// Override instead of -apply
- (void) unapplyWithNext:(OOMaterial *)next;

// Call at top of dealloc
- (void) willDealloc;

@end


namespace oo {

// The material's Objective-C object: an Objective-C material itself, else a C++ material's live
// facade (or a new one); autoreleased. nil for null.
OOMaterial *ToObjC(cxx::OOMaterial *material);
inline OOMaterial *ToObjC(const Ref<cxx::OOMaterial> &material)  { return ToObjC(material.get()); }

// The C++ material behind an Objective-C one, borrowed (the Objective-C object retains it); null for nil.
cxx::OOMaterial *ToCxx(OOMaterial *material);

}	// namespace oo

#endif	// OOMATERIAL_OBJCBRIDGE_H
