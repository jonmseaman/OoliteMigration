/*

OOMesh.h

Standard OODrawable for static meshes from DAT files. OOMeshes are immutable
(and can therefore be shared). Avoid the temptation to add externally-visible
mutator methods as it will break such sharing. (Sharing will be implemented
when ship types are turned into objects instead of dictionaries; this is
currently slated for post-1.70. -- Ahruman)

Hmm. On further consideration, sharing will be problematic because of material
bindings. Two possible solutions: separate mesh data into shared object with
each mesh instance having its own set of materials but shared data, or
retarget bindings each frame. -- Ahruman


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

#import "OODrawable.h"
#import "OOOpenGL.h"
#import "OOWeakReference.h"
#import "OOOpenGLExtensionManager.h"

#include "oofnd/StdLib.hpp"
#include "oofnd/PList.hpp"
#include "oofnd/Ref.hpp"

@class OOMaterial, Octree;
class OOMeshBuffer;	// OOMesh.mm: one refcounted buffer (an oo::Data), shared by a mesh and its mutable copies


#define OOMESH_PROFILE	0
#if OOMESH_PROFILE
#import "OOProfilingStopwatch.h"
#endif


enum
{
	kOOMeshMaxMaterials			= 8
};


typedef uint16_t			OOMeshSmoothGroup;
typedef uint8_t				OOMeshMaterialIndex, OOMeshMaterialCount;
typedef uint32_t			OOMeshVertexCount;
typedef uint32_t			OOMeshFaceCount;
typedef uint8_t				OOMeshFaceVertexCount;


typedef struct
{
	OOMeshSmoothGroup		smoothGroup;
	OOMeshMaterialIndex		materialIndex;
	GLuint					vertex[3];
	
	Vector					normal;
	Vector					tangent;
	GLfloat					s[3];
	GLfloat					t[3];
} OOMeshFace;


typedef struct
{
	GLint					*indexArray;
	GLfloat					*textureUVArray;
	Vector					*vertexArray;
	Vector					*normalArray;
	Vector					*tangentArray;
	
	GLuint					count;
} OOMeshDisplayLists;


namespace cxx {

class Octree;
class OOMaterial;


/*	C++20 since bead oo-dnbf, slice 1 of docs/phases/3-slices/OOMesh.md (proposed ADR-0056,
	amendments oo-smy, oo-pni4 and oo-dnbf): the class shell, its factories, lifecycle and
	accessors. The class is cxx::OOMesh, a C++ subclass of cxx::OODrawable, while
	OOMesh+ObjCBridge.h, imported at the end of this header, keeps the Objective-C OOMesh its
	callers message. Slices 2-4 (loading, geometry, rendering) are still Objective-C: categories of
	that facade in OOMesh.mm, which read and write the members below through oo::ToCxx(self).
*/
class OOMesh : public OODrawable
{
public:
	static oo::Ref<OOMesh> meshWithName(const std::string &name,
										const std::optional<std::string> &cacheKey,
										const oo::PList &materialDict,
										const oo::PList &shadersDict,
										bool smooth,
										const oo::PList &macros,
										id<OOWeakReferenceSupport> object);

	static oo::Ref<OOMesh> meshWithName(const std::string &name,
										const std::optional<std::string> &cacheKey,
										const oo::PList &materialDict,
										const oo::PList &shadersDict,
										bool smooth,
										const oo::PList &macros,
										id<OOWeakReferenceSupport> object,
										float factor,
										bool cacheWriteable);

	static oo::Ref<OOMaterial> placeholderMaterial();

	OOMesh();
	OOMesh(const OOMesh &) = default;	// -mutableCopyWithZone:'s copy: every member, the buffers shared
	~OOMesh() override;

	oo::Ref<OOMesh> copyWithZone(OOZone *zone);

	std::optional<std::string> modelName();

	oo::PList getMaterials();	// null: none (-materials; the member materials is the materials)
	oo::PList shaders();

	size_t getVertexCount();	// -vertexCount
	size_t getFaceCount();		// -faceCount

	// OODrawable
	bool hasOpaqueParts() override;
	GLfloat collisionRadius() override;
	GLfloat maxDrawDistance() override;
	void setBindingTarget(id<OOWeakReferenceSupport> target) override;
	std::optional<std::string> descriptionComponents() const override;
#ifndef NDEBUG
	void dumpSelfState() override;
	std::vector<oo::ObjCRef<::OOTexture *>> allTextures() override;
	size_t totalSize() override;
#endif

	// Slices 3 and 4, still Objective-C (categories of the facade in OOMesh.mm): a C++ caller of
	// the drawable reaches them through the facade until their slices convert them.
	void renderOpaqueParts() override;
	BoundingBox boundingBox() override;

	// Internal: the state, read and written by the Objective-C categories of slices 2-4 through
	// oo::ToCxx(self) (amendment oo-pni4 item 1). Zero, as class_createInstance left the ivars.
	uint8_t					_normalMode: 2 = 0,
							brokenInRender: 1 = 0,
							listsReady: 1 = 0;
	
	OOMeshMaterialCount		materialCount = {};
	OOMeshVertexCount		vertexCount = {};
	OOMeshFaceCount			faceCount = {};
	
	std::optional<std::string>	baseFile;					// "No Model" until loaded; nullopt after -rescaleByFactor: (no octree cache)
	std::optional<std::string>	baseFileOctreeCacheRef;
	bool					_cacheWriteable = {};
	
	Vector					*_vertices = {};
	Vector					*_normals = {};
	Vector					*_tangents = {};
	OOMeshFace				*_faces = {};
	
	// Redundancy! Needs fixing.
	OOMeshDisplayLists		_displayLists = {};
	
	NSRange					triangle_range[kOOMeshMaxMaterials] = {};
	std::string				materialKeys[kOOMeshMaxMaterials];
	::OOMaterial			*materials[kOOMeshMaxMaterials] = {};	// retained
	GLuint					displayList0 = {};
	
	// (named like the overridden getters, which a C++ member cannot be: amendment oo-rdfh item 1)
	GLfloat					_collisionRadius = {};
	GLfloat					_maxDrawDistance = {};
	BoundingBox				_boundingBox = {};
	
	::Octree				*octree = {};	// retained
	
	std::map<std::string, oo::Ref<OOMeshBuffer>, std::less<>>	_retainedObjects;	// the buffers _vertices & co. point into, by key
	
	oo::PList				_materialDict;		// mixed configurations (proposed ADR-0043 Amendment 2); null = nil
	oo::PList				_shadersDict;
	std::optional<std::string>	_cacheKey;		// nil and @"" differ for OOMaterial
	oo::PList				_shaderMacros;
	id						_shaderBindingTarget = {};	// retained (a weak reference)

	Vector					_lastPosition = {};
	OOMatrix				_lastRotMatrix = {};
	BoundingBox				_lastBoundingBox = {};
	
#if OO_MULTITEXTURE
	NSUInteger				_textureUnitCount = {};
#endif
	
#if OOMESH_PROFILE
	oo::Ref<OOProfilingStopwatch>	_stopwatch;
	double					_stopwatchLastTime = {};
#endif

private:
	bool suppressClangStuff();
};

}	// namespace cxx


// The OOCacheManager (Octree) category, as free functions next to the cache (the slice plan, bead
// oo-dnbf). The octree cached for a model key, made afresh from its representation; null when none.
oo::Ref<cxx::Octree> OOCacheManagerOctreeForModel(const std::string &inKey);
// Caches the octree's representation under the key; a null octree does nothing.
void OOCacheManagerSetOctree(cxx::Octree *inOctree, const std::string &inKey);


// Transitional: the Objective-C OOMesh, for its callers and for slices 2-4 of OOMesh.mm, not yet
// converted. Deleted, with namespace cxx above, by the bridge's deletion bead.
#import "OOMesh+ObjCBridge.h"
