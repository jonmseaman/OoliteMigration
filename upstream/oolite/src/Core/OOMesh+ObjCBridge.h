/*

OOMesh+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, amendment oo-dnbf): the Objective-C OOMesh, a facade over the C++
cxx::OOMesh (OOMesh.h), for the code that is not converted yet: the callers that message meshes
(the ship and visual effect entities, the ship registry, the scripting bindings), and slices 2
and 4 of docs/phases/3-slices/OOMesh.md (loading, rendering), which are still Objective-C and
are categories of this facade in OOMesh.mm. Its interface is the one OOMesh.h declared before the
conversion, copied exactly (same selectors, same types), less the ivars, which are the C++ class's
members; the selector that slice 4 implements is declared in its category below. Each
method of the class forwards to its C++ member. Imported as the last line of OOMesh.h; do not
import it directly.

It is a converted subclass's facade under the drawables' root facade (amendment oo-up4b item 3):
it has no ivars, OODrawable's holds its C++ part, and OODrawable's methods for the overridable
members reach cxx::OOMesh's overrides.

	a caller that is                       holds / passes                  crosses with
	-------------------------------------  ------------------------------  ----------------------------
	still Objective-C                      OOMesh * (this facade)          nothing: messages as before
	converted (C++)                        oo::Ref<cxx::OOMesh>
	  handing the mesh to Objective-C                                      oo::ToObjC(mesh)
	  taking it from Objective-C                                           oo::ToCxx(objcMesh)

The facade is the mesh's graphics reset client (its loading registered it), so its -dealloc
unregisters it and deletes the display lists, which message it. oo::ToObjC(oo::ToCxx(m)) == m.
Never add to this file; converted code does not message the facade. Deleted by its deletion bead
once every slice and every caller is C++.


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

#ifndef OOMESH_OBJCBRIDGE_H
#define OOMESH_OBJCBRIDGE_H


@interface OOMesh: OODrawable <OOCopying>

+ (instancetype) meshWithName:(const std::string &)name
					 cacheKey:(const std::optional<std::string> &)cacheKey
		   materialDictionary:(const oo::PList &)materialDict
			shadersDictionary:(const oo::PList &)shadersDict
					   smooth:(BOOL)smooth
				 shaderMacros:(const oo::PList &)macros
		  shaderBindingTarget:(id<OOWeakReferenceSupport>)object;

+ (instancetype) meshWithName:(const std::string &)name
					 cacheKey:(const std::optional<std::string> &)cacheKey
		   materialDictionary:(const oo::PList &)materialDict
			shadersDictionary:(const oo::PList &)shadersDict
					   smooth:(BOOL)smooth
				 shaderMacros:(const oo::PList &)macros
		  shaderBindingTarget:(id<OOWeakReferenceSupport>)object
				  scaleFactor:(float)factor
			   cacheWriteable:(BOOL)cacheWriteable;


+ (OOMaterial *) placeholderMaterial;

- (std::optional<std::string>) modelName;

- (oo::PList) materials;	// null: none
- (oo::PList) shaders;

- (size_t) vertexCount;
- (size_t) faceCount;

- (Octree *) octree;

// This needs a better name.
- (BoundingBox) findBoundingBoxRelativeToPosition:(Vector)opv
											basis:(Vector)ri :(Vector)rj :(Vector)rk
									 selfPosition:(Vector)position
										selfBasis:(Vector)si :(Vector)sj :(Vector)sk;
- (BoundingBox) findSubentityBoundingBoxWithPosition:(Vector)position rotMatrix:(OOMatrix)rotMatrix;

- (OOMesh *) meshRescaledBy:(GLfloat)scaleFactor;

@end


// Slice 4 (rendering), still Objective-C: OOMesh.mm.
@interface OOMesh (OOMeshRendering)

- (void) rebindMaterials;

@end


namespace oo {

// The mesh's Objective-C facade: its live one, else a new one; autoreleased. nil for null.
OOMesh *ToObjC(cxx::OOMesh *mesh);
inline OOMesh *ToObjC(const Ref<cxx::OOMesh> &mesh)  { return ToObjC(mesh.get()); }

// The C++ mesh behind a facade, borrowed (the facade retains it); null for nil.
cxx::OOMesh *ToCxx(OOMesh *mesh);

}	// namespace oo

#endif	// OOMESH_OBJCBRIDGE_H
