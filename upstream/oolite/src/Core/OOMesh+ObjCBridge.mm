/*

OOMesh+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, amendment oo-dnbf): the Objective-C OOMesh facade (see
OOMesh+ObjCBridge.h). Every method forwards to its C++ member through oo::ToCxx(self); -init makes
a new cxx::OOMesh, which the designated initialiser of slice 2 (still Objective-C, in OOMesh.mm)
then loads. Deleted with OOMesh+ObjCBridge.h.


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

#import "OOMesh.h"
#import "OOMaterial.h"
#import "OOGraphicsResetManager.h"


// Slice 4's display-list deletion, in the private category of OOMesh.mm, which the facade's
// -dealloc sends (it messaged self from -dealloc before); that category makes the mesh a graphics
// reset client.
@interface OOMesh (Private) <OOGraphicsResetClient>

- (void) deleteDisplayLists;

@end


// A facade of this class is only ever made for a cxx::OOMesh (oo::ToObjC names the facade class
// after the C++ class, and -init makes one), so the casts are exact.
OOMesh *oo::ToObjC(cxx::OOMesh *mesh)
{
	return static_cast<OOMesh *>(oo::ToObjC(static_cast<cxx::OODrawable *>(mesh)));
}


cxx::OOMesh *oo::ToCxx(OOMesh *mesh)
{
	return static_cast<cxx::OOMesh *>(oo::ToCxx(static_cast<OODrawable *>(mesh)));
}


@implementation OOMesh

+ (instancetype) meshWithName:(const std::string &)name
					 cacheKey:(const std::optional<std::string> &)cacheKey
		   materialDictionary:(const oo::PList &)materialDict
			shadersDictionary:(const oo::PList &)shadersDict
					   smooth:(BOOL)smooth
				 shaderMacros:(const oo::PList &)macros
		  shaderBindingTarget:(id<OOWeakReferenceSupport>)object
{
	return oo::ToObjC(cxx::OOMesh::meshWithName(name, cacheKey, materialDict, shadersDict, smooth, macros, object));
}


+ (instancetype) meshWithName:(const std::string &)name
					 cacheKey:(const std::optional<std::string> &)cacheKey
		   materialDictionary:(const oo::PList &)materialDict
			shadersDictionary:(const oo::PList &)shadersDict
					   smooth:(BOOL)smooth
				 shaderMacros:(const oo::PList &)macros
		  shaderBindingTarget:(id<OOWeakReferenceSupport>)object
				  scaleFactor:(float)factor
			   cacheWriteable:(BOOL)cacheWriteable
{
	return oo::ToObjC(cxx::OOMesh::meshWithName(name, cacheKey, materialDict, shadersDict, smooth, macros, object, factor, cacheWriteable));
}


// One facade for the life of the process, as the material itself was (amendment oo-r7m0).
+ (OOMaterial *) placeholderMaterial
{
	static OOMaterial *facade = nil;
	if (facade == nil)  facade = [oo::ToObjC(cxx::OOMesh::placeholderMaterial().get()) retain];
	return facade;
}


// A new C++ mesh, which this facade owns and is the peer of: -init ran the constructor's body.
- (id) init
{
	return [super initWithNewCxxDrawable:oo::makeRef<cxx::OOMesh>()];
}


// The facade is the mesh's graphics reset client, so what the old -dealloc sent to self is sent
// here, before the C++ part goes (its destructor releases the members).
- (void) dealloc
{
	[self deleteDisplayLists];
	[[OOGraphicsResetManager sharedManager] unregisterClient:self];
	[super dealloc];
}


- (id) copyWithZone:(OOZone *)zone
{
	return [oo::ToObjC(oo::ToCxx(self)->copyWithZone(zone)) retain];
}


- (std::optional<std::string>) modelName	{ return oo::ToCxx(self)->modelName(); }

- (oo::PList) materials						{ return oo::ToCxx(self)->getMaterials(); }
- (oo::PList) shaders						{ return oo::ToCxx(self)->shaders(); }

- (size_t) vertexCount						{ return oo::ToCxx(self)->getVertexCount(); }
- (size_t) faceCount						{ return oo::ToCxx(self)->getFaceCount(); }

@end
