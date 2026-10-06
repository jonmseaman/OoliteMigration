/*

OOMesh.m

A note on memory management:
The dynamically-sized buffers used by OOMesh (_vertex etc) are the byte arrays
of refcounted OOMeshBuffers (one oo::Data each), which are tracked using the
_retainedObjects map. This simplifies the implementation of -dealloc, but more
importantly, it means bytes are refcounted and shared by a mesh and its mutable
copies. (Bytes read from the cache are copied into a buffer of their own.)

Since _retainedObjects is a map its members can be replaced,
potentially allowing mutable meshes, although we have no use for this at
present.


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
#import "OOCacheManager.h"
#import <objc/runtime.h>
#import <objc/objc-arc.h>
#import "Universe.h"
#import "OOMeshToOctreeConverter.h"
#import "ResourceManager.h"
#import "Entity.h"		// for NO_DRAW_DISTANCE_FACTOR.
#import "Octree.h"
#import "OOMaterialConvenienceCreators.h"
#import "OOBasicMaterial.h"
#import "OOOpenGLExtensionManager.h"
#import "OOGraphicsResetManager.h"
#import "OODebugGLDrawing.h"
#import "OOShaderMaterial.h"
#import "OOMacroOpenGL.h"
#import "OOProfilingStopwatch.h"
#import "OODebugFlags.h"
#import "NSObjectOOExtensions.h"

#import "OOJavaScriptEngine.h"
#import "OODebugStandards.h"
#include "oofnd/objc/OOException.h"
#include "oofnd/String.hpp"
#include "oofnd/Scanner.hpp"
#include "oofnd/Log.hpp"
#include "oofnd/objc/OOAssert.h"

// If set, collision octree depth varies depending on the size of the mesh.
#define ADAPTIVE_OCTREE_DEPTH		1

// If set, cachable memory is scribbled with FEEDFACE to identify junk in cache.
#define SCRIBBLE					0


enum
{
	kBaseOctreeDepth				= 5,	// 32x32x32
//	kMaxOctreeDepth declared in Octree.h.
	kSmallOctreeDepth				= 4,	// 16x16x16
	kOctreeSizeThreshold			= 900,	// Size at which we start increasing octree depth
	kOctreeSmallSizeThreshold		= 20
};


typedef enum
{
	kNormalModePerFace,
	kNormalModeSmooth,
	kNormalModeExplicit
} OOMeshNormalMode;


static const char * const kOOLogMeshDataNotFound			= "mesh.load.failed.fileNotFound";	// an OO_LOG message class
static const char * const kOOLogMeshTooManyMaterials		= "mesh.load.failed.tooManyMaterials";


#if OOMESH_PROFILE
#define PROFILE(tag)  do { oo::ToCxx(self)->_stopwatchLastTime = Profile(tag, oo::ToCxx(self)->_stopwatch.get(), oo::ToCxx(self)->_stopwatchLastTime); } while (0)
static OOTimeDelta Profile(const char *tag, OOProfilingStopwatch *stopwatch, OOTimeDelta lastTime)
{
	OOTimeDelta now = stopwatch->currentTime();
	OO_LOG("mesh.profile", "Mesh profile: stage {}, {:g} seconds (delta {:g})", tag, now, now - lastTime);
	return now;
}
#else
#define PROFILE(tag)  do {} while (0)
#endif


/*	VertexFaceRef
	List of indices of faces used by a given vertex.
	Always access using the provided functions.
	
	The overflow list is a std::vector owned by the VertexFaceRef, which lives in
	a std::vector for the duration of -loadData:scaleFactor:.
*/
enum
{
#if OOLITE_64_BIT
	kVertexFaceDefInternalCount	= 11	// sizeof (VertexFaceRef) = 32
#else
	kVertexFaceDefInternalCount	= 5		// sizeof (VertexFaceRef) = 16
#endif
};

typedef struct VertexFaceRef
{
	uint16_t			internCount;
	uint16_t			internFaces[kVertexFaceDefInternalCount];
	std::vector<NSUInteger>	extra;
} VertexFaceRef;


static void VFRAddFace(VertexFaceRef *vfr, NSUInteger index);
static NSUInteger VFRGetCount(VertexFaceRef *vfr);
static NSUInteger VFRGetFaceAtIndex(VertexFaceRef *vfr, NSUInteger index);


@interface OOMesh (Private) <OOMutableCopying, OOGraphicsResetClient>

- (id)initWithName:(const std::string &)name
		  cacheKey:(const std::optional<std::string> &)cacheKey
materialDictionary:(const oo::PList &)materialDict
 shadersDictionary:(const oo::PList &)shadersDict
			smooth:(BOOL)smooth
	  shaderMacros:(const oo::PList &)macros
shaderBindingTarget:(id<OOWeakReferenceSupport>)object
	   scaleFactor:(float)scale
	cacheWriteable:(BOOL)cacheWriteable;

- (BOOL) loadData:(const std::string &)filename scaleFactor:(float)scale;

- (void) deleteDisplayLists;

- (oo::PList) modelData;	// null: incomplete
- (BOOL) setModelFromModelData:(const oo::PList &)dict name:(const std::string &)fileName;

- (BOOL) setUpVertexArrays;



#ifndef NDEBUG
- (void)debugDrawNormals;
#endif

// Manage the set of refcounted buffers we need to hang on to.
- (void) setRetainedObject:(oo::Data)object forKey:(const std::string &)key;
- (void *) allocateBytesWithSize:(size_t)size count:(NSUInteger)count key:(const std::string &)key;

// Allocate all per-vertex/per-face buffers.
- (BOOL) allocateVertexBuffersWithCount:(NSUInteger)count;
- (BOOL) allocateNormalBuffersWithCount:(NSUInteger)count;
- (BOOL) allocateFaceBuffersWithCount:(NSUInteger)count;
- (BOOL) allocateVertexArrayBuffersWithCount:(NSUInteger)count;

- (void) renameTexturesFrom:(const std::string &)from to:(const std::string &)to;

@end


// The OOCacheManager (OOMesh) category, as free functions next to the cache (defined below).
namespace {
oo::PList OOCacheManagerMeshDataForName(const std::string &inShipName);
void OOCacheManagerSetMeshData(const oo::PList &inData, const std::string &inShipName);
}


// One mesh buffer: the bytes _vertices & co. point into, shared (refcounted) by a mesh and its
// mutable copies as the retained data object was.
class OOMeshBuffer : public oo::RefCounted
{
public:
	explicit OOMeshBuffer(oo::Data bytes) : data_(std::move(bytes)) {}
	oo::Data &data() noexcept { return data_; }

private:
	oo::Data data_;
};


static BOOL IsLegacyNormalMode(OOMeshNormalMode mode)
{
	/*	True for modes that predate the "normal mode" concept, i.e. per-face
		and smooth. These modes require automatic winding correction.
	*/
	switch (mode)
	{
		case kNormalModePerFace:
		case kNormalModeSmooth:
			return YES;
			
		case kNormalModeExplicit:
			return NO;
	}
	
#ifndef NDEBUG
	OORaiseException(OOInvalidArgumentException, "Unexpected normal mode in %s", __PRETTY_FUNCTION__);
#endif
	return NO;	
}


static BOOL IsPerVertexNormalMode(OOMeshNormalMode mode)
{
	/*	True for modes that have per-vertex normals, i.e. not per-face mode.
	*/
	switch (mode)
	{
		case kNormalModePerFace:
			return NO;
			
		case kNormalModeSmooth:
		case kNormalModeExplicit:
			return YES;
	}
	
#ifndef NDEBUG
	OORaiseException(OOInvalidArgumentException, "Unexpected normal mode in %s", __PRETTY_FUNCTION__);
#endif
	return NO;
}


namespace cxx {

oo::Ref<OOMesh> OOMesh::meshWithName(const std::string &name,
									 const std::optional<std::string> &cacheKey,
									 const oo::PList &materialDict,
									 const oo::PList &shadersDict,
									 bool smooth,
									 const oo::PList &macros,
									 id<OOWeakReferenceSupport> object)
{
	// The designated initialiser is slice 2's, still Objective-C: the facade's, which makes this
	// mesh (its -init) and loads it, or answers nil.
	::OOMesh *mesh = [[[::OOMesh alloc] initWithName:name
											 cacheKey:cacheKey
								   materialDictionary:materialDict
									shadersDictionary:shadersDict
											   smooth:smooth
										 shaderMacros:macros
								  shaderBindingTarget:object
										  scaleFactor:1.0f
									   cacheWriteable:YES] autorelease];
	return oo::Ref<OOMesh>(oo::ToCxx(mesh));
}

oo::Ref<OOMesh> OOMesh::meshWithName(const std::string &name,
									 const std::optional<std::string> &cacheKey,
									 const oo::PList &materialDict,
									 const oo::PList &shadersDict,
									 bool smooth,
									 const oo::PList &macros,
									 id<OOWeakReferenceSupport> object,
									 float scale,
									 bool cacheWriteable)
{
	::OOMesh *mesh = [[[::OOMesh alloc] initWithName:name
											 cacheKey:cacheKey
								   materialDictionary:materialDict
									shadersDictionary:shadersDict
											   smooth:smooth
										 shaderMacros:macros
								  shaderBindingTarget:object
										  scaleFactor:scale
									   cacheWriteable:cacheWriteable] autorelease];
	return oo::Ref<OOMesh>(oo::ToCxx(mesh));
}


oo::Ref<OOMaterial> OOMesh::placeholderMaterial()
{
	static OOBasicMaterial	*placeholderMaterial = nullptr;	// never released, as before

	if (placeholderMaterial == nullptr)
	{
		// +cxx_materialDefaults answers a copy: keep it alive while noTextures points into it (bead oo-f4241).
		const oo::PList materialDefaults = [ResourceManager cxx_materialDefaults];
		const oo::PList *noTextures = materialDefaults.find("no-textures-material");
		placeholderMaterial = OOBasicMaterial::materialWithName(std::string("/placeholder/"), (noTextures != nullptr ? *noTextures : oo::PList())).leakRef();
	}

	return oo::Ref<OOMaterial>(placeholderMaterial);
}


OOMesh::OOMesh()
{
	baseFile = "No Model";
	baseFileOctreeCacheRef = "No Model-0.000";
	_cacheWriteable = YES;
#if OO_MULTITEXTURE
	_textureUnitCount = NSNotFound;
#endif

	_lastPosition = kZeroVector;
	_lastRotMatrix = kZeroMatrix; // not identity
	_lastBoundingBox = kZeroBoundingBox;
}


OOMesh::~OOMesh()
{
	unsigned				i;

	// [self deleteDisplayLists] and the graphics reset manager's -unregisterClient:self are the
	// facade's -dealloc (OOMesh+ObjCBridge.mm): they message the facade, the registered client,
	// which is gone by the time its C++ part is destroyed.

	for (i = 0; i != kOOMeshMaxMaterials; ++i)
	{
		DESTROY(materials[i]);
	}

	DESTROY(_shaderBindingTarget);

#if OOMESH_PROFILE
	_stopwatch = nullptr;
#endif
}


namespace {

const char *NormalModeDescription(OOMeshNormalMode mode)
{
	switch (mode)
	{
		case kNormalModePerFace:  return "per-face";
		case kNormalModeSmooth:  return "smooth";
		case kNormalModeExplicit:  return "explicit";
	}

	return "unknown";
}

} // namespace


std::optional<std::string> OOMesh::descriptionComponents() const
{
	OOMesh *mesh = const_cast<OOMesh *>(this);	// the getters are not const (ADR-0056 item 3)
	const std::optional<std::string> modelName = mesh->modelName();
	return oo::str::format("\"%s\", %zu vertices, %zu faces, radius: %g m normals: %s", modelName ? modelName->c_str() : "(null)", mesh->getVertexCount(), mesh->getFaceCount(), mesh->collisionRadius(), NormalModeDescription((OOMeshNormalMode)_normalMode));
}


oo::Ref<OOMesh> OOMesh::copyWithZone(OOZone *zone)
{
	// -zone is always nil (OOObject.h), so this is [self zone].
	if (zone == nullptr)  return oo::Ref<OOMesh>(this);	// OK because we're immutable seen from the outside
	// -mutableCopyWithZone: is slice 2's, still Objective-C. The copy's facade, its graphics reset
	// client, lives until the pool drains.
	::OOMesh *copy = [[oo::ToObjC(this) mutableCopyWithZone:zone] autorelease];
	return oo::Ref<OOMesh>(oo::ToCxx(copy));
}


std::optional<std::string> OOMesh::modelName()
{
	return baseFile;
}


size_t OOMesh::getVertexCount()
{
	return vertexCount;
}


size_t OOMesh::getFaceCount()
{
	return faceCount;
}


// Slice 4, still Objective-C: the facade's category method (amendment oo-dnbf).
void OOMesh::renderOpaqueParts()
{
	[oo::ToObjC(this) renderOpaqueParts];
}

}	// namespace cxx


@implementation OOMesh (OOMeshRendering)

- (void)renderOpaqueParts
{
	OO_ENTER_OPENGL();
	
	BOOL meshBelongsToVisualEffect = [oo::ToCxx(self)->_shaderBindingTarget isVisualEffect];
	
	OOSetOpenGLState(OPENGL_STATE_OPAQUE);
	
	OOGL(glVertexPointer(3, GL_FLOAT, 0, oo::ToCxx(self)->_displayLists.vertexArray));
	OOGL(glNormalPointer(GL_FLOAT, 0, oo::ToCxx(self)->_displayLists.normalArray));
	
	// for visual effects enable blending. This will allow use of alpha
	// channel in shaders - note, this is a bit of cheating the system,
	// which expects blending to be disabled at this point
	if (meshBelongsToVisualEffect)
	{
		OOGL(glEnable(GL_BLEND));
		OOGL(glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA));
	}
	
#if OO_SHADERS
	if ([[OOOpenGLExtensionManager sharedManager] shadersSupported])
	{
		OOGL(glEnableVertexAttribArrayARB(kTangentAttributeIndex));
		OOGL(glVertexAttribPointerARB(kTangentAttributeIndex, 3, GL_FLOAT, GL_FALSE, 0, oo::ToCxx(self)->_displayLists.tangentArray));
	}
#endif
	
	BOOL usingNormalsAsTexCoords = NO;
	OOMeshMaterialIndex ti;
	
	/*	FIXME: really, really horrible hack to set up texture coordinates for
		each texture unit. Very messy and still fails to handle some possibly-
		basic stuff, like switching usingNormalsAsTexCoords per texture unit.
		The right way to do this is probably to move attribute setup into the
		material model.
		-- Ahruman 2010-04-12
	*/
#if OO_MULTITEXTURE
	if (oo::ToCxx(self)->_textureUnitCount == NSNotFound)
	{
		oo::ToCxx(self)->_textureUnitCount = 0;
		for (ti = 0; ti < oo::ToCxx(self)->materialCount; ti++)
		{
			NSUInteger count = [oo::ToCxx(self)->materials[ti] countOfTextureUnitsWithBaseCoordinates];
			if (oo::ToCxx(self)->_textureUnitCount < count)  oo::ToCxx(self)->_textureUnitCount = count;
		}
	}
	
	NSUInteger unit;
	if (oo::ToCxx(self)->_textureUnitCount <= 1)
	{
		OOGL(glEnableClientState(GL_TEXTURE_COORD_ARRAY));
	}
	else
	{
		/*	It should not be possible to have multiple texture units if
			texture combiners are not available.
		*/
		OOAssert([[OOOpenGLExtensionManager sharedManager] textureCombinersSupported], "Mesh %s uses %zu texture units, but multitexturing is not available.", oo::ShortDescriptionOf(self).c_str(), oo::ToCxx(self)->_textureUnitCount);
		
		for (unit = 0; unit < oo::ToCxx(self)->_textureUnitCount; unit++)
		{
			OOGL(glClientActiveTextureARB(GL_TEXTURE0_ARB + unit));
			OOGL(glEnableClientState(GL_TEXTURE_COORD_ARRAY));
		}
	}
#else
	OOGL(glEnableClientState(GL_TEXTURE_COORD_ARRAY));
#endif
	
	@try
	{
		if (!oo::ToCxx(self)->listsReady)
		{
			OOGL(oo::ToCxx(self)->displayList0 = glGenLists(oo::ToCxx(self)->materialCount));
			
			// Ensure all textures are loaded
			for (ti = 0; ti < oo::ToCxx(self)->materialCount; ti++)
			{
				[oo::ToCxx(self)->materials[ti] ensureFinishedLoading];
			}
		}
		
		for (ti = 0; ti < oo::ToCxx(self)->materialCount; ti++)
		{
			BOOL wantsNormalsAsTextureCoordinates = [oo::ToCxx(self)->materials[ti] wantsNormalsAsTextureCoordinates];
			if (ti == 0 || wantsNormalsAsTextureCoordinates != usingNormalsAsTexCoords)
			{
					// FIXME: enabling/disabling texturing should be handled by the material.
#if OO_MULTITEXTURE
				for (unit = 0; unit < oo::ToCxx(self)->_textureUnitCount; unit++)
				{
					if (oo::ToCxx(self)->_textureUnitCount > 1)
					{
						OOGL(glClientActiveTextureARB(GL_TEXTURE0_ARB + unit));
						OOGL(glActiveTextureARB(GL_TEXTURE0_ARB + unit));
					}
#endif
					if (!wantsNormalsAsTextureCoordinates)
					{
						OOGL(glDisable(GL_TEXTURE_CUBE_MAP));
						OOGL(glTexCoordPointer(2, GL_FLOAT, 0, oo::ToCxx(self)->_displayLists.textureUVArray));
						/*	FIXME: Not including the line below breaks multitexturing in no-shaders mode.
							However, the OpenGL state manager should probably be handling this;
							TEXTURE_2D is part of OPENGL_STATE_OPAQUE, which has already been set.
							- Nikos 20130103
						*/
						OOGL(glEnable(GL_TEXTURE_2D));
					}
					else
					{
						OOGL(glDisable(GL_TEXTURE_2D));
						OOGL(glTexCoordPointer(3, GL_FLOAT, 0, oo::ToCxx(self)->_displayLists.vertexArray));
						OOGL(glEnable(GL_TEXTURE_CUBE_MAP));
					}
#if OO_MULTITEXTURE
				}
#endif
				usingNormalsAsTexCoords = wantsNormalsAsTextureCoordinates;
			}
			
			[oo::ToCxx(self)->materials[ti] apply];
			OOGL(glDrawArrays(GL_TRIANGLES, oo::ToCxx(self)->triangle_range[ti].location, oo::ToCxx(self)->triangle_range[ti].length));
		}
		
		oo::ToCxx(self)->listsReady = YES;
		oo::ToCxx(self)->brokenInRender = NO;
	}
	@catch (OOException *exception)
	{
		if (!oo::ToCxx(self)->brokenInRender)
		{
			OO_LOG(cxx_kOOLogException, "***** {} for {} encountered exception: {} : {} *****", __PRETTY_FUNCTION__, oo::DescriptionOf(self), [exception name], [exception reason]);
			oo::ToCxx(self)->brokenInRender = YES;
		}
		if (strncmp([exception name], "Oolite", 6) == 0)  [UNIVERSE handleOoliteException:exception];	// handle these ourself
		else  @throw exception;	// pass these on
	}
	
#if OO_SHADERS
	if ([[OOOpenGLExtensionManager sharedManager] shadersSupported])
	{
		OOGL(glDisableVertexAttribArrayARB(kTangentAttributeIndex));
	}
#endif
	
	[OOMaterial applyNone];
	cxx_OOCheckOpenGLErrors([&]() -> std::string { return "OOMesh after drawing " + oo::DescriptionOf(self); });
	
#if OO_MULTITEXTURE
	if (oo::ToCxx(self)->_textureUnitCount <= 1)
	{
		OOGL(glDisableClientState(GL_TEXTURE_COORD_ARRAY));
	}
	else
	{
		for (unit = 0; unit < oo::ToCxx(self)->_textureUnitCount; unit++)
		{
			OOGL(glClientActiveTextureARB(GL_TEXTURE0_ARB + unit));
			OOGL(glDisableClientState(GL_TEXTURE_COORD_ARRAY));
		}
		
		OOGL(glClientActiveTextureARB(GL_TEXTURE0_ARB));
		OOGL(glActiveTextureARB(GL_TEXTURE0_ARB));
	}
#else
	OOGL(glDisableClientState(GL_TEXTURE_COORD_ARRAY));
#endif
	
#ifndef NDEBUG
	if (gDebugFlags & DEBUG_DRAW_NORMALS)  [self debugDrawNormals];
	if (gDebugFlags & DEBUG_OCTREE_DRAW)  [[self octree] drawOctree];
#endif
	
	// visual effect - disable previously enabled blending
	if (meshBelongsToVisualEffect)  OOGL(glDisable(GL_BLEND));
	
	OOVerifyOpenGLState();
}


- (void) rebindMaterials
{
	OOMeshMaterialCount		i;
	OOMaterial				*material = nil;

	if (oo::ToCxx(self)->materialCount != 0)
	{
		for (i = 0; i != oo::ToCxx(self)->materialCount; ++i)
		{
			OOMaterial *oldMaterial = oo::ToCxx(self)->materials[i];

			if (oo::ToCxx(self)->materialKeys[i] != "_oo_placeholder_material")
			{
				material = [OOMaterial materialWithName:oo::ToCxx(self)->materialKeys[i]
											   cacheKey:oo::ToCxx(self)->_cacheKey
									 materialDictionary:oo::ToCxx(self)->_materialDict
									  shadersDictionary:oo::ToCxx(self)->_shadersDict
												 macros:oo::ToCxx(self)->_shaderMacros
										  bindingTarget:[oo::ToCxx(self)->_shaderBindingTarget weakRefUnderlyingObject]	// Windows DEP fix.
										forSmoothedMesh:IsPerVertexNormalMode((OOMeshNormalMode)oo::ToCxx(self)->_normalMode)];
			}
			else
			{
				material = nil;
			}
			
			if (material != nil)
			{
				oo::ToCxx(self)->materials[i] = [material retain];
			}
			else
			{
				oo::ToCxx(self)->materials[i] = [[OOMesh placeholderMaterial] retain];
			}
			
			/*	Release is deferred to here to ensure we don't end up releasing
				a texture that's not in the recent-cache and then reloading it.
			*/
			[oldMaterial release];
		}
	}
}


@end


namespace cxx {

oo::PList OOMesh::getMaterials()
{
	return _materialDict;
}


oo::PList OOMesh::shaders()
{
	return _shadersDict;
}


bool OOMesh::hasOpaqueParts()
{
	return YES;
}

GLfloat OOMesh::collisionRadius()
{
	return _collisionRadius;
}


GLfloat OOMesh::maxDrawDistance()
{
	return _maxDrawDistance;
}

}	// namespace cxx


namespace cxx {

#if ADAPTIVE_OCTREE_DEPTH
unsigned OOMesh::octreeDepth()
{
	float				threshold = kOctreeSizeThreshold;
	unsigned			result = kBaseOctreeDepth;
	GLfloat				xs, ys, zs, t, size;

	bounding_box_get_dimensions(_boundingBox, &xs, &ys, &zs);
	// Shuffle dimensions around so zs is smallest
	if (xs < zs)  { t = zs; zs = xs; xs = t; }
	if (ys < zs)  { t = zs; zs = ys; ys = t; }
	size = (xs + ys) / 2.0f;	// Use average of two largest

	if (size < kOctreeSmallSizeThreshold)  result = kSmallOctreeDepth;
	else while (result < kMaxOctreeDepth)
	{
		if (size < threshold) break;
		threshold *= 2.0f;
		result++;
	}

	OO_LOG("mesh.load.octree.size", "Selected octree depth {} for size {:g} for {}", result, size, baseFile.value_or("(null)"));
	return result;
}
#else
unsigned OOMesh::octreeDepth()
{
	return kBaseOctreeDepth;
}
#endif


oo::Ref<Octree> OOMesh::getOctree()
{
	if (octree == nullptr)
	{
		octree = baseFileOctreeCacheRef ? OOCacheManagerOctreeForModel(*baseFileOctreeCacheRef) : oo::Ref<Octree>();
		if (octree == nullptr)
		{
			void *pool = objc_autoreleasePoolPush();	// @autoreleasepool
			{
				oo::Ref<OOMeshToOctreeConverter> converter = OOMeshToOctreeConverter::converterWithCapacity(faceCount);
				OOMeshFaceCount i;
				for (i = 0; i < faceCount; i++)
				{
					// Somewhat surprisingly, this method doesn't even show up in profiles. -- Ahruman 2012-09-22
					Triangle tri;
					tri.v[0] = _vertices[_faces[i].vertex[0]];
					tri.v[1] = _vertices[_faces[i].vertex[1]];
					tri.v[2] = _vertices[_faces[i].vertex[2]];
					converter->addTriangle(tri);
				}

				octree = converter->findOctreeToDepth(octreeDepth());
				if (EXPECT(_cacheWriteable) && baseFileOctreeCacheRef)
				{
					OOCacheManagerSetOctree(octree.get(), *baseFileOctreeCacheRef);
				}
			}
			objc_autoreleasePoolPop(pool);
		}
		else
		{
			OO_LOG("mesh.load.octreeCached", "Retrieved octree \"{}\" from cache.", baseFileOctreeCacheRef.value_or("(null)"));
		}
	}

	return octree;
}


BoundingBox OOMesh::findBoundingBoxRelativeToPosition(Vector opv, Vector ri, Vector rj, Vector rk, Vector position, Vector si, Vector sj, Vector sk)
{
	BoundingBox	result;
	Vector		pv, rv;
	
	// FIXME: rewrite with matrices
	Vector rpos = vector_subtract(position, opv);	// model origin relative to opv
	
	rv.x = dot_product(ri,rpos);
	rv.y = dot_product(rj,rpos);
	rv.z = dot_product(rk,rpos);	// model origin rel to opv in ijk
	
	if (EXPECT_NOT(vertexCount < 1))
	{
		bounding_box_reset_to_vector(&result, rv);
	}
	else
	{
		pv.x = rpos.x + si.x * _vertices[0].x + sj.x * _vertices[0].y + sk.x * _vertices[0].z;
		pv.y = rpos.y + si.y * _vertices[0].x + sj.y * _vertices[0].y + sk.y * _vertices[0].z;
		pv.z = rpos.z + si.z * _vertices[0].x + sj.z * _vertices[0].y + sk.z * _vertices[0].z;	// _vertices[0] position rel to opv
		rv.x = dot_product(ri, pv);
		rv.y = dot_product(rj, pv);
		rv.z = dot_product(rk, pv);	// _vertices[0] position rel to opv in ijk
		bounding_box_reset_to_vector(&result, rv);
	}
	
	OOMeshVertexCount i;
	for (i = 1; i < vertexCount; i++)
	{
		pv.x = rpos.x + si.x * _vertices[i].x + sj.x * _vertices[i].y + sk.x * _vertices[i].z;
		pv.y = rpos.y + si.y * _vertices[i].x + sj.y * _vertices[i].y + sk.y * _vertices[i].z;
		pv.z = rpos.z + si.z * _vertices[i].x + sj.z * _vertices[i].y + sk.z * _vertices[i].z;
		rv.x = dot_product(ri, pv);
		rv.y = dot_product(rj, pv);
		rv.z = dot_product(rk, pv);
		bounding_box_add_vector(&result, rv);
	}

	return result;
}


BoundingBox OOMesh::findSubentityBoundingBoxWithPosition(Vector position, OOMatrix rotMatrix)
{
	// HACK! Should work out what the various bounding box things do and make it neat and consistent.
	// FIXME: this is a bottleneck.
// Try to fix bottleneck by caching for common case where subentity
// pos+rot is constant from frame to frame. - CIM

	if (vector_equal(position,_lastPosition) && OOMatrixEqual(rotMatrix,_lastRotMatrix))
	{
		return _lastBoundingBox;
	}

	BoundingBox		result;
	Vector			v;
	
	v = vector_add(position, OOVectorMultiplyMatrix(_vertices[0], rotMatrix));
	bounding_box_reset_to_vector(&result,v);
	
	OOMeshVertexCount i;
	for (i = 1; i < vertexCount; i++)
	{
		v = vector_add(position, OOVectorMultiplyMatrix(_vertices[i], rotMatrix));
		bounding_box_add_vector(&result,v);
	}
	
	_lastBoundingBox = result;
	_lastPosition = position;
	_lastRotMatrix = rotMatrix;

	return result;
}


oo::Ref<OOMesh> OOMesh::meshRescaledBy(GLfloat scaleFactor)
{
	// -mutableCopy is slice 2's, still Objective-C: the copy's facade (its graphics reset client)
	// lives until the pool drains, as the autoreleased result did.
	::OOMesh *copy = [[oo::ToObjC(this) mutableCopy] autorelease];
	oo::Ref<OOMesh> result(oo::ToCxx(copy));
	result->rescaleByFactor(scaleFactor);
	return result;
}

}	// namespace cxx


namespace cxx {

void OOMesh::setBindingTarget(id<OOWeakReferenceSupport> target)
{
	unsigned				i;

	for (i = 0; i != kOOMeshMaxMaterials; ++i)
	{
		// A nil material did nothing.
		if (OOMaterial *material = oo::ToCxx(materials[i]))  material->setBindingTarget(target);
	}
}


#ifndef NDEBUG
void OOMesh::dumpSelfState()
{
	OODrawable::dumpSelfState();

	if (baseFile)  OO_LOG("dumpState.mesh", "Model file: {}", *baseFile);
	OO_LOG("dumpState.mesh", "Vertex count: {}, face count: {}", static_cast<unsigned>(vertexCount), static_cast<unsigned>(faceCount));
	OO_LOG("dumpState.mesh", "Normals: {}", NormalModeDescription((OOMeshNormalMode)_normalMode));
}
#endif


#ifndef NDEBUG
std::vector<oo::ObjCRef<::OOTexture *>> OOMesh::allTextures()
{
	// Every material's textures; id forwarder NSSetFromObjects drops duplicates as -unionSet: did.
	std::vector<oo::ObjCRef<::OOTexture *>> result;
	OOMeshMaterialCount i;
	for (i = 0; i != materialCount; i++)
	{
		// A nil material answered no textures.
		OOMaterial *material = oo::ToCxx(materials[i]);
		if (material == nullptr)  continue;
		for (const oo::ObjCRef<::OOTexture *> &texture : material->allTextures())  result.push_back(texture);
	}

	return result;
}


size_t OOMesh::totalSize()
{
	size_t result = OODrawable::totalSize();
	if (_vertices != NULL)  result += sizeof *_vertices * vertexCount;
	if (_normals != NULL)  result += sizeof *_normals * vertexCount;
	if (_tangents != NULL)  result += sizeof *_tangents * vertexCount;
	if (_faces != NULL)  result += sizeof *_faces * faceCount;

	result += _displayLists.count * (sizeof (GLint) + sizeof (GLfloat) + sizeof (Vector) * 3);

	OOMeshMaterialCount i;
	for (i = 0; i != materialCount; i++)
	{
		// -oo_objectSize: its class's instance size (NSObjectOOExtensions.mm), 0 for nil.
		result += class_getInstanceSize(object_getClass(materials[i]));
	}

	// A nil octree answered 0.
	if (octree != nullptr)  result += octree->totalSize();
	return result;
}
#endif


/*	This method exists purely to suppress Clang static analyzer warnings that
	these ivars are unused (but may be used by categories, which they are).
	FIXME: there must be a feature macro we can use to avoid actually building
	this into the app, but I can't find it in docs.
*/
bool OOMesh::suppressClangStuff()
{
	return _normals && _tangents && _faces && _boundingBox.min.x;
}

}	// namespace cxx


@implementation OOMesh (Private)

- (id)initWithName:(const std::string &)name
		  cacheKey:(const std::optional<std::string> &)cacheKey
materialDictionary:(const oo::PList &)materialDict
 shadersDictionary:(const oo::PList &)shadersDict
			smooth:(BOOL)smooth
	  shaderMacros:(const oo::PList &)macros
shaderBindingTarget:(id<OOWeakReferenceSupport>)target
	   scaleFactor:(float)scale
	cacheWriteable:(BOOL)cacheWriteable
{
	OOJS_PROFILE_ENTER
	
	self = [self init];	// the C++ mesh (bead oo-dnbf): was [super init], with every ivar zero
	if (self == nil)  return nil;
	
	@autoreleasepool
	{
		oo::ToCxx(self)->_normalMode = smooth ? kNormalModeSmooth : kNormalModePerFace;
		oo::ToCxx(self)->_cacheWriteable = cacheWriteable;
		
#if OOMESH_PROFILE
		oo::ToCxx(self)->_stopwatch = oo::makeRef<OOProfilingStopwatch>();
#endif
		
		if ([self loadData:name scaleFactor:scale])
		{
			oo::ToCxx(self)->calculateBoundingVolumes();
			PROFILE("finished calculateBoundingVolumes (again\?\?)");
			
			oo::ToCxx(self)->baseFile = name;
			oo::ToCxx(self)->baseFileOctreeCacheRef = oo::str::format("%s-%.3f", name.c_str(), scale);
			
			/*	New in r3033: save the material-defining parameters here so we
				can rebind the materials at any time.
				-- Ahruman 2010-02-17
			*/
			oo::ToCxx(self)->_materialDict = materialDict;
			oo::ToCxx(self)->_shadersDict = shadersDict;
			oo::ToCxx(self)->_cacheKey = cacheKey;
			oo::ToCxx(self)->_shaderMacros = macros;
			oo::ToCxx(self)->_shaderBindingTarget = [target weakRetain];
			
			[self rebindMaterials];
			PROFILE("finished material setup");
			
			[[OOGraphicsResetManager sharedManager] registerClient:self];
		}
		else
		{
			[self release];
			self = nil;
		}
#if OOMESH_PROFILE
		oo::ToCxx(self)->_stopwatch = nullptr;
#endif
#if OO_MULTITEXTURE
		if (EXPECT(self != nil))
		{
			oo::ToCxx(self)->_textureUnitCount = NSNotFound;
		}
#endif
	}
	return self;
	
	OOJS_PROFILE_EXIT
}


- (id)mutableCopyWithZone:(OOZone *)zone
{
	OOMesh				*result = nil;
	OOMeshMaterialCount	i;

	// NSCopyObject(self, 0, zone) without Foundation (ADR-0029 reroot), on the C++ part (bead
	// oo-dnbf): a new mesh whose members are copied one by one, as NSCopyObject copied the ivars
	// bitwise and the C++ ones were then constructed afresh over the copy (so the buffers are
	// shared). Its facade is a new one of this class. Zones are unused, as on GNUstep.
	result = [oo::ToObjC(oo::makeRef<cxx::OOMesh>(*oo::ToCxx(self))) retain];

	if (result != nil)
	{
		// The Objective-C members, copied as pointers, get their -retain (the octree is a C++ reference, copied).
		cxx::OOMesh *copy = oo::ToCxx(result);
		[copy->_shaderBindingTarget retain];

		for (i = 0; i != kOOMeshMaxMaterials; ++i)
		{
			[copy->materials[i] retain];
		}

		// Reset unsharable GL state
		copy->listsReady = NO;

		[[OOGraphicsResetManager sharedManager] registerClient:result];
	}

	return result;
}


- (void) deleteDisplayLists
{
	if (oo::ToCxx(self)->listsReady)
	{
		OO_ENTER_OPENGL();
		
		OOGL(glDeleteLists(oo::ToCxx(self)->displayList0, oo::ToCxx(self)->materialCount));
		oo::ToCxx(self)->listsReady = NO;
	}
}


- (void) resetGraphicsState
{
	[self deleteDisplayLists];
	[self rebindMaterials];
	oo::ToCxx(self)->_textureUnitCount = NSNotFound;
}


- (oo::PList)modelData
{
	OOJS_PROFILE_ENTER

	BOOL includeNormals = IsPerVertexNormalMode((OOMeshNormalMode)oo::ToCxx(self)->_normalMode);

	// Prepare cache data elements.
	const auto vertData = oo::ToCxx(self)->_retainedObjects.find("vertices");
	const auto faceData = oo::ToCxx(self)->_retainedObjects.find("faces");
	const auto normData = oo::ToCxx(self)->_retainedObjects.find("normals");
	const auto tanData = oo::ToCxx(self)->_retainedObjects.find("tangents");

	// Ensure we have all the required data elements.
	if (vertData == oo::ToCxx(self)->_retainedObjects.end() || faceData == oo::ToCxx(self)->_retainedObjects.end())
	{
		return oo::PList();
	}

	if (includeNormals)
	{
		if (normData == oo::ToCxx(self)->_retainedObjects.end() || tanData == oo::ToCxx(self)->_retainedObjects.end())  return oo::PList();
	}

	// All OK; stick 'em in a dictionary. The counts are unsigned (+numberWithUnsignedInt:, and
	// +numberWithUnsignedChar: for the normal mode); the normals are only included when used.
	oo::PList::Array mtlKeys;
	for (OOMeshMaterialCount i = 0; i != oo::ToCxx(self)->materialCount; ++i)  mtlKeys.emplace_back(oo::ToCxx(self)->materialKeys[i]);

	oo::PList::Dict result;
	result["vertex count"] = oo::PList(oo::ToCxx(self)->vertexCount);
	result["vertex data"] = oo::PList(vertData->second->data());
	result["face count"] = oo::PList(oo::ToCxx(self)->faceCount);
	result["face data"] = oo::PList(faceData->second->data());
	result["material keys"] = oo::PList(std::move(mtlKeys));
	result["normal mode"] = oo::PList::unsignedInteger(oo::ToCxx(self)->_normalMode);
	if (includeNormals)
	{
		result["normal data"] = oo::PList(normData->second->data());
		result["tangent data"] = oo::PList(tanData->second->data());
	}
	return oo::PList(std::move(result));

	OOJS_PROFILE_EXIT
}


- (BOOL)setModelFromModelData:(const oo::PList &)dict name:(const std::string &)fileName
{
	OOJS_PROFILE_ENTER

	unsigned			i;

	if (!dict.isDict())  return NO;

	oo::ToCxx(self)->vertexCount = dict.get<unsigned int>("vertex count");
	oo::ToCxx(self)->faceCount = dict.get<unsigned int>("face count");

	if (oo::ToCxx(self)->vertexCount == 0 || oo::ToCxx(self)->faceCount == 0)  return NO;

	// Read data elements from dictionary.
	const oo::PList *vertData = dict.get<oo::PList::Data>("vertex data");
	const oo::PList *faceData = dict.get<oo::PList::Data>("face data");
	const oo::PList *normData = nullptr;
	const oo::PList *tanData = nullptr;

	const oo::PList *mtlKeys = dict.get<oo::PList::Array>("material keys");
	oo::ToCxx(self)->_normalMode = dict.get<unsigned char>("normal mode");
	BOOL includeNormals = IsPerVertexNormalMode((OOMeshNormalMode)oo::ToCxx(self)->_normalMode);

	// Ensure we have all the required data elements.
	if (vertData == nullptr ||
		faceData == nullptr ||
		mtlKeys == nullptr)
	{
		OO_LOG("mesh.load.error.badCacheData", "Ignoring bad cache data for mesh \"{}\".", fileName);
		return NO;
	}

	if (includeNormals)
	{
		normData = dict.get<oo::PList::Data>("normal data");
		tanData = dict.get<oo::PList::Data>("tangent data");
		if (normData == nullptr || tanData == nullptr)
		{
			OO_LOG("mesh.load.error.badCacheData", "Ignoring bad normal/tangent cache data for mesh \"{}\".", fileName);
			return NO;
		}
	}

	// Ensure data objects are of correct size.
	if (vertData->getIf<oo::PList::Data>()->length() != sizeof *oo::ToCxx(self)->_vertices * oo::ToCxx(self)->vertexCount)  return NO;
	if (faceData->getIf<oo::PList::Data>()->length() != sizeof *oo::ToCxx(self)->_faces * oo::ToCxx(self)->faceCount)  return NO;
	if (includeNormals)
	{
		if (normData->getIf<oo::PList::Data>()->length() != sizeof *oo::ToCxx(self)->_normals * oo::ToCxx(self)->vertexCount)  return NO;
		if (tanData->getIf<oo::PList::Data>()->length() != sizeof *oo::ToCxx(self)->_tangents * oo::ToCxx(self)->vertexCount)  return NO;
	}

	// Retain data: each is copied into a buffer of this mesh's, and the pointers taken from it.
	[self setRetainedObject:*vertData->getIf<oo::PList::Data>() forKey:"vertices"];
	oo::ToCxx(self)->_vertices = (Vector *)oo::ToCxx(self)->_retainedObjects.find("vertices")->second->data().mutableBytes();
	[self setRetainedObject:*faceData->getIf<oo::PList::Data>() forKey:"faces"];
	oo::ToCxx(self)->_faces = (OOMeshFace *)oo::ToCxx(self)->_retainedObjects.find("faces")->second->data().mutableBytes();
	if (includeNormals)
	{
		[self setRetainedObject:*normData->getIf<oo::PList::Data>() forKey:"normals"];
		oo::ToCxx(self)->_normals = (Vector *)oo::ToCxx(self)->_retainedObjects.find("normals")->second->data().mutableBytes();
		[self setRetainedObject:*tanData->getIf<oo::PList::Data>() forKey:"tangents"];
		oo::ToCxx(self)->_tangents = (Vector *)oo::ToCxx(self)->_retainedObjects.find("tangents")->second->data().mutableBytes();
	}
	else
	{
		oo::ToCxx(self)->_normals = NULL;
		oo::ToCxx(self)->_tangents = NULL;
	}

	// Copy material keys (oo_stringAtIndex: a string, or a number's -stringValue).
	const oo::PList::Array &keys = *mtlKeys->getIf<oo::PList::Array>();
	oo::ToCxx(self)->materialCount = keys.size();
	for (i = 0; i != oo::ToCxx(self)->materialCount; ++i)
	{
		const oo::PList &key = keys[i];
		if (key.isString() || key.isNumber())  oo::ToCxx(self)->materialKeys[i] = oo::PListGet<std::string>::from(&key, std::string());
		else
		{
			OO_LOG("mesh.load.error.badCacheData", "Ignoring bad cache data for mesh \"{}\".", fileName);
			return NO;
		}
	}

	return YES;

	OOJS_PROFILE_EXIT
}


- (BOOL)loadData:(const std::string &)filename scaleFactor:(float)scale
{
	OOJS_PROFILE_ENTER
	
	std::optional<oo::str::Scanner>	scanner;	// made from the preprocessed text below
	BOOL				failFlag = NO;
	std::string			failString = "***** ";
	unsigned			i, j;
	std::map<std::string, unsigned, std::less<>>	texFileName2Idx;
	BOOL				using_preloaded = NO;
	
	const std::string cacheKey = oo::str::format("%s:%u:%.3f", filename.c_str(), oo::ToCxx(self)->_normalMode, scale);
	const oo::PList cacheData = OOCacheManagerMeshDataForName(cacheKey);
	if (cacheData)
	{
		if ([self setModelFromModelData:cacheData name:filename])
		{
			using_preloaded = YES;
			PROFILE("loaded from cache");
			OO_LOG("mesh.load.cached", "Retrieved mesh \"{}\" from cache.", filename);
		}
	}
	
	if (!using_preloaded)
	{
		OO_LOG("mesh.load.uncached", "Mesh \"{}\" is not in cache, loading.", cacheKey);
		
		const oo::str::CharacterSet	whitespaceCharSet = oo::str::CharacterSet::whitespace();
		const oo::str::CharacterSet	whitespaceAndNewlineCharSet = oo::str::CharacterSet::whitespaceAndNewline();
		// The newline set. The non-Mac build made it as whitespace-and-newline minus whitespace,
		// which is the same set (U+000A-U+000D and U+0085: Scanner.hpp's tables).
		const oo::str::CharacterSet	newlineCharSet = oo::str::CharacterSet::newline();
		
		{
			void *pool = objc_autoreleasePoolPush();
			const std::optional<std::string> dataOpt = [ResourceManager cxx_stringFromFilesNamed:filename inFolder:"Models" cache:NO];
			if (!dataOpt)
			{
				// Model not found
				OO_LOG(kOOLogMeshDataNotFound, "***** ERROR: could not find {}", filename);
				cxx_OOStandardsError("Model file not found");
				objc_autoreleasePoolPop(pool);
				return NO;
			}
			
			// strip out comments and commas between values
			std::vector<std::string> lines = oo::str::split(*dataOpt, "\n");
			for (i = 0; i < lines.size(); i++)
			{
				std::string line = lines[i];
				std::vector<std::string> parts;
				//
				// comments
				//
				parts = oo::str::split(line, "#");
				line = parts.empty() ? std::string() : parts[0];
				parts = oo::str::split(line, "//");
				line = parts.empty() ? std::string() : parts[0];
				//
				// commas
				//
				parts = oo::str::split(line, ",");
				line.clear();
				for (std::size_t p = 0; p < parts.size(); ++p)
				{
					if (p)  line += ' ';
					line += parts[p];
				}
				//
				lines[i] = std::move(line);
			}
			
			std::string data;
			for (std::size_t li = 0; li < lines.size(); ++li)
			{
				if (li)  data += '\n';
				data += lines[li];
			}
			scanner.emplace(data);

			objc_autoreleasePoolPop(pool);
		}
		
		PROFILE("finished preprocessing");

		// get number of vertices
		//
		scanner->setScanLocation(0);	//reset
		if (scanner->scanString("NVERTS"))
		{
			int n_v;
			if (scanner->scanInt(&n_v))
				oo::ToCxx(self)->vertexCount = n_v;
			else
			{
				failFlag = YES;
				failString += "Failed to read value of NVERTS\n";
			}
		}
		else
		{
			failFlag = YES;
			failString += "Failed to read NVERTS\n";
		}
		
		if (![self allocateVertexBuffersWithCount:oo::ToCxx(self)->vertexCount])
		{
			OO_LOG(cxx_kOOLogAllocationFailure, "***** ERROR: failed to allocate memory for model {} ({} vertices).", filename, static_cast<unsigned>(oo::ToCxx(self)->vertexCount));
			return NO;
		}
		
		// get number of faces
		if (scanner->scanString("NFACES"))
		{
			int n_f;
			if (scanner->scanInt(&n_f))
			{
				oo::ToCxx(self)->faceCount = n_f;
			}
			else
			{
				failFlag = YES;
				failString += "Failed to read value of NFACES\n";
			}
		}
		else
		{
			failFlag = YES;
			failString += "Failed to read NFACES\n";
		}
		
		// Allocate face->vertex table.
		std::vector<VertexFaceRef> faceRefTable(oo::ToCxx(self)->vertexCount);	// zeroed, freed when loading ends
		VertexFaceRef *faceRefs = faceRefTable.data();

		if (![self allocateFaceBuffersWithCount:oo::ToCxx(self)->faceCount])
		{
			OO_LOG(cxx_kOOLogAllocationFailure, "***** ERROR: failed to allocate memory for model {} ({} vertices, {} faces).", filename, static_cast<unsigned>(oo::ToCxx(self)->vertexCount), static_cast<unsigned>(oo::ToCxx(self)->faceCount));
			return NO;
		}
		
		// get vertex data
		if (scanner->scanString("VERTEX"))
		{
			for (j = 0; j < oo::ToCxx(self)->vertexCount; j++)
			{
				float x, y, z;
				if (!failFlag)
				{
					if (!scanner->scanFloat(&x))  failFlag = YES;
					if (!scanner->scanFloat(&y))  failFlag = YES;
					if (!scanner->scanFloat(&z))  failFlag = YES;
					if (!failFlag)
					{
						oo::ToCxx(self)->_vertices[j] = make_vector(x*scale, y*scale, z*scale);
					}
					else
					{
						failString += oo::str::format("Failed to read a value for vertex[%d] in %s\n", j, "VERTEX");
					}
				}
			}
		}
		else
		{
			failFlag = YES;
			failString += "Failed to find VERTEX data\n";
		}

		// get face data
		if (scanner->scanString("FACES"))
		{
			for (j = 0; j < oo::ToCxx(self)->faceCount; j++)
			{
				int r, g, b;
				float nx, ny, nz;
				int n_v;
				if (!failFlag)
				{
					// colors
					if (!scanner->scanInt(&r))  failFlag = YES;
					if (!scanner->scanInt(&g))  failFlag = YES;
					if (!scanner->scanInt(&b))  failFlag = YES;
					if (!failFlag)
					{
						oo::ToCxx(self)->_faces[j].smoothGroup = r;
					}
					else
					{
						failString += oo::str::format("Failed to read a color for face[%d] in FACES\n", j);
					}
					
					// normal
					if (!scanner->scanFloat(&nx))  failFlag = YES;
					if (!scanner->scanFloat(&ny))  failFlag = YES;
					if (!scanner->scanFloat(&nz))  failFlag = YES;
					if (!failFlag)
					{
						oo::ToCxx(self)->_faces[j].normal = vector_normal(make_vector(nx, ny, nz));
					}
					else
					{
						failString += oo::str::format("Failed to read a normal for face[%d] in FACES\n", j);
					}
					
					// vertices
					if (scanner->scanInt(&n_v))
					{
						if (n_v < 3)
						{
							failFlag = YES;
							failString += oo::str::format("Face[%u] has fewer than three vertices.\n", j);
						}
						else if (n_v > 3)
						{
							OO_LOG_WARN("mesh.load.warning.nonTriangular", "Face[{}] of {} has {} vertices specified. Only the first three will be used.", static_cast<unsigned>(j), oo::ToCxx(self)->baseFile.value_or("(null)"), static_cast<unsigned>(n_v));
							n_v = 3;
						}
					}
					else
					{
						failFlag = YES;
						failString += oo::str::format("Failed to read number of vertices for face[%d] in FACES\n", j);
					}
					
					if (!failFlag)
					{
						int vi;
						for (i = 0; (int)i < n_v; i++)
						{
							if (scanner->scanInt(&vi))
							{
								oo::ToCxx(self)->_faces[j].vertex[i] = vi;
								if (faceRefs != NULL)  VFRAddFace(&faceRefs[vi], j);
							}
							else
							{
								failFlag = YES;
								failString += oo::str::format("Failed to read vertex[%d] for face[%d] in FACES\n", i, j);
							}
						}
					}
				}
			}
		}
		else
		{
			failFlag = YES;
			failString += "Failed to find FACES data\n";
		}

		// Get textures data.
		if (scanner->scanString("TEXTURES"))
		{
			for (j = 0; j < oo::ToCxx(self)->faceCount; j++)
			{
				std::string	materialKey;
				float	max_x, max_y;
				float	s, t;
				if (!failFlag)
				{
					// materialKey
					//
					scanner->scanCharactersFromSet(whitespaceAndNewlineCharSet);
					std::string scannedKey;
					if (!scanner->scanUpToCharactersFromSet(whitespaceCharSet, &scannedKey))
					{
						failFlag = YES;
						failString += oo::str::format("Failed to read texture filename for face[%d] in TEXTURES\n", j);
					}
					else
					{
						materialKey = std::move(scannedKey);
						const auto indexIt = texFileName2Idx.find(materialKey);
						if (indexIt != texFileName2Idx.end())
						{
							oo::ToCxx(self)->_faces[j].materialIndex = indexIt->second;
						}
						else
						{
							if (oo::ToCxx(self)->materialCount == kOOMeshMaxMaterials)
							{
								OO_LOG(kOOLogMeshTooManyMaterials, "***** ERROR: model {} has too many materials (maximum is {})", filename, static_cast<int>(kOOMeshMaxMaterials));
								return NO;
							}
							oo::ToCxx(self)->_faces[j].materialIndex = oo::ToCxx(self)->materialCount;
							oo::ToCxx(self)->materialKeys[oo::ToCxx(self)->materialCount] = materialKey;
							texFileName2Idx.emplace(materialKey, oo::ToCxx(self)->materialCount);
							++oo::ToCxx(self)->materialCount;
						}
					}

					// texture size
					//
				   if (!failFlag)
					{
						if (!scanner->scanFloat(&max_x))  failFlag = YES;
						if (!scanner->scanFloat(&max_y))  failFlag = YES;
						if (failFlag)
							failString += oo::str::format("Failed to read texture size for max_x and max_y in face[%d] in TEXTURES\n", j);
					}

					// vertices
					//
					if (!failFlag)
					{
						for (i = 0; i < 3; i++)
						{
							if (!scanner->scanFloat(&s))  failFlag = YES;
							if (!scanner->scanFloat(&t))  failFlag = YES;
							if (!failFlag)
							{
								oo::ToCxx(self)->_faces[j].s[i] = s / max_x;
								oo::ToCxx(self)->_faces[j].t[i] = t / max_y;
							}
							else
								failString += oo::str::format("Failed to read s t coordinates for vertex[%d] in face[%d] in TEXTURES\n", i, j);
						}
					}
				}
			}
		}
		else
		{
			failFlag = YES;
			failString += "Failed to find TEXTURES data (will use placeholder material)\n";
			oo::ToCxx(self)->materialKeys[0] = "_oo_placeholder_material";
			oo::ToCxx(self)->materialCount = 1;
			
			for (j = 0; j < oo::ToCxx(self)->faceCount; j++)
			{
				oo::ToCxx(self)->_faces[j].materialIndex = 0;
			}
		}
		
		if (scanner->scanString("NAMES"))
		{
			unsigned int count;
			if (!scanner->scanInt((int *)&count))
			{	
				failFlag = YES;
				failString += "Expected count after NAMES\n";
			}
			else
			{
				for (j = 0; j < count; j++)
				{
					scanner->scanCharactersFromSet(whitespaceAndNewlineCharSet);
					std::string scannedName;
					if (!scanner->scanUpToCharactersFromSet(newlineCharSet, &scannedName))
					{
						failFlag = YES;
						failString += "Expected file name\n";
					}
					else
					{
						[self renameTexturesFrom:oo::str::format("%u", j) to:scannedName];
					}
				}
			}
		}
		
		BOOL explicitTangents = NO;
		
		// Get explicit normals.
		if (scanner->scanString("NORMALS"))
		{
			oo::ToCxx(self)->_normalMode = kNormalModeExplicit;
			if (![self allocateNormalBuffersWithCount:oo::ToCxx(self)->vertexCount])
			{
				OO_LOG(cxx_kOOLogAllocationFailure, "***** ERROR: failed to allocate memory for model {} ({} vertices).", filename, static_cast<unsigned>(oo::ToCxx(self)->vertexCount));
				return NO;
			}
			
			for (j = 0; j < oo::ToCxx(self)->vertexCount; j++)
			{
				float x, y, z;
				if (!failFlag)
				{
					if (!scanner->scanFloat(&x))  failFlag = YES;
					if (!scanner->scanFloat(&y))  failFlag = YES;
					if (!scanner->scanFloat(&z))  failFlag = YES;
					if (!failFlag)
					{
						oo::ToCxx(self)->_normals[j] = vector_normal(make_vector(x, y, z));
					}
					else
					{
						failString += oo::str::format("Failed to read a value for vertex[%d] in %s\n", j, "NORMALS");
					}
				}
			}
			
			// Get explicit tangents (only together with vertices).
			if (scanner->scanString("TANGENTS"))
			{
				for (j = 0; j < oo::ToCxx(self)->vertexCount; j++)
				{
					float x, y, z;
					if (!failFlag)
					{
						if (!scanner->scanFloat(&x))  failFlag = YES;
						if (!scanner->scanFloat(&y))  failFlag = YES;
						if (!scanner->scanFloat(&z))  failFlag = YES;
						if (!failFlag)
						{
							oo::ToCxx(self)->_tangents[j] = vector_normal(make_vector(x, y, z));
						}
						else
						{
							failString += oo::str::format("Failed to read a value for vertex[%d] in %s\n", j, "TANGENTS");
						}
					}
				}
			}
		}
		
		PROFILE("finished parsing");
		
		if (IsLegacyNormalMode((OOMeshNormalMode)oo::ToCxx(self)->_normalMode))
		{
			oo::ToCxx(self)->checkNormalsAndAdjustWinding();
			PROFILE("finished checkNormalsAndAdjustWinding");
		}
		if (!explicitTangents)
		{
			oo::ToCxx(self)->generateFaceTangents();
			PROFILE("finished generateFaceTangents");
		}
		
		// check for smooth shading and recalculate normals
		if (oo::ToCxx(self)->_normalMode == kNormalModeSmooth)
		{
			if (![self allocateNormalBuffersWithCount:oo::ToCxx(self)->vertexCount])
			{
				OO_LOG(cxx_kOOLogAllocationFailure, "***** ERROR: failed to allocate memory for model {} ({} vertices).", filename, static_cast<unsigned>(oo::ToCxx(self)->vertexCount));
				return NO;
			}
			oo::ToCxx(self)->calculateVertexNormalsAndTangentsWithFaceRefs(faceRefs);
			PROFILE("finished calculateVertexNormalsAndTangents");
			
		}
		else if (IsPerVertexNormalMode((OOMeshNormalMode)oo::ToCxx(self)->_normalMode) && !explicitTangents)
		{
			oo::ToCxx(self)->calculateVertexTangentsWithFaceRefs(faceRefs);
			PROFILE("finished calculateVertexTangents");
		}
		
		// save the resulting data for possible reuse
		if (EXPECT(oo::ToCxx(self)->_cacheWriteable))
		{
			OOCacheManagerSetMeshData([self modelData], cacheKey);
			PROFILE("saved to cache");
		}
		
		if (failFlag)
		{
			OO_LOG("mesh.error", "{} ..... from {} {}", failString, filename, (using_preloaded)? "(from preloaded data)" : "(from file)");
		}
	}
	
	oo::ToCxx(self)->calculateBoundingVolumes();
	PROFILE("finished calculateBoundingVolumes");
	
	// set up vertex arrays for drawing
	if (![self setUpVertexArrays])  return NO;
	PROFILE("finished setUpVertexArrays");
	
	return YES;
	
	OOJS_PROFILE_EXIT
}


- (BOOL) setUpVertexArrays
{
	OOJS_PROFILE_ENTER
	
	NSUInteger	fi, vi, mi;
	
	if (![self allocateVertexArrayBuffersWithCount:oo::ToCxx(self)->faceCount])  return NO;
	
	// if smoothed, find any vertices that are between faces of different
	// smoothing groups and mark them as being on an edge and therefore NOT
	// smooth shaded
	std::vector<BOOL>	is_edge_vertex(oo::ToCxx(self)->vertexCount);
	std::vector<GLfloat>	smoothGroup(oo::ToCxx(self)->vertexCount);
	for (vi = 0; vi < oo::ToCxx(self)->vertexCount; vi++)
	{
		is_edge_vertex[vi] = NO;
		smoothGroup[vi] = -1;
	}
	if (oo::ToCxx(self)->_normalMode == kNormalModeSmooth)
	{
		for (fi = 0; fi < oo::ToCxx(self)->faceCount; fi++)
		{
			GLfloat rv = oo::ToCxx(self)->_faces[fi].smoothGroup;
			int i;
			for (i = 0; i < 3; i++)
			{
				vi = oo::ToCxx(self)->_faces[fi].vertex[i];
				if (smoothGroup[vi] < 0.0)	// unassigned
					smoothGroup[vi] = rv;
				else if (smoothGroup[vi] != rv)	// a different colour
					is_edge_vertex[vi] = YES;
			}
		}
	}


	// base model, flat or smooth shaded, all triangles
	int tri_index = 0;
	int uv_index = 0;
	int vertex_index = 0;
	
	// Iterate over material names
	for (mi = 0; mi != oo::ToCxx(self)->materialCount; ++mi)
	{
		oo::ToCxx(self)->triangle_range[mi].location = tri_index;
		
		for (fi = 0; fi < oo::ToCxx(self)->faceCount; fi++)
		{
			Vector normal, tangent;
			
			if (oo::ToCxx(self)->_faces[fi].materialIndex == mi)
			{
				for (vi = 0; vi < 3; vi++)
				{
					int v = oo::ToCxx(self)->_faces[fi].vertex[vi];
					if (IsPerVertexNormalMode((OOMeshNormalMode)oo::ToCxx(self)->_normalMode))
					{
						if (is_edge_vertex[v])
						{
							oo::ToCxx(self)->getNormal(&normal, &tangent, v, oo::ToCxx(self)->_faces[fi].smoothGroup);
						}
						else
						{
							OOAssert(oo::ToCxx(self)->_normals != NULL && oo::ToCxx(self)->_tangents != NULL, "Normal/tangent buffers not allocated in %s", __PRETTY_FUNCTION__);
							
							normal = oo::ToCxx(self)->_normals[v];
							tangent = oo::ToCxx(self)->_tangents[v];
						}
					}
					else
					{
						normal = oo::ToCxx(self)->_faces[fi].normal;
						tangent = oo::ToCxx(self)->_faces[fi].tangent;
					}
					
					// FIXME: avoid redundant vertices so index array is actually useful.
					oo::ToCxx(self)->_displayLists.indexArray[tri_index++] = vertex_index;
					oo::ToCxx(self)->_displayLists.normalArray[vertex_index] = normal;
					oo::ToCxx(self)->_displayLists.tangentArray[vertex_index] = tangent;
					oo::ToCxx(self)->_displayLists.vertexArray[vertex_index++] = oo::ToCxx(self)->_vertices[v];
					oo::ToCxx(self)->_displayLists.textureUVArray[uv_index++] = oo::ToCxx(self)->_faces[fi].s[vi];
					oo::ToCxx(self)->_displayLists.textureUVArray[uv_index++] = oo::ToCxx(self)->_faces[fi].t[vi];
				}
			}
		}
		oo::ToCxx(self)->triangle_range[mi].length = tri_index - oo::ToCxx(self)->triangle_range[mi].location;
	}
	
	oo::ToCxx(self)->_displayLists.count = tri_index;	// total number of triangle vertices
	return YES;
	
	OOJS_PROFILE_EXIT
}


#ifndef NDEBUG
- (void)debugDrawNormals
{
	GLuint				i;
	Vector				v, n, t, b;
	float				length, blend;
	GLfloat				color[3];
	OODebugWFState		state;
	
	OO_ENTER_OPENGL();
	
	state = OODebugBeginWireframe(NO);
	
	// Draw
	OOGLBEGIN(GL_LINES);
	for (i = 0; i < oo::ToCxx(self)->_displayLists.count; ++i)
	{
		v = oo::ToCxx(self)->_displayLists.vertexArray[i];
		n = oo::ToCxx(self)->_displayLists.normalArray[i];
		t = oo::ToCxx(self)->_displayLists.tangentArray[i];
		b = true_cross_product(n, t);
		
		// Draw normal
		length = magnitude2(n);
		blend = fabs(length - 1) * 5.0;
		color[0] = MIN(blend, 1.0f);
		color[1] = 1.0f - color[0];
		color[2] = color[1];
		glColor3fv(color);
		
		glVertex3f(v.x, v.y, v.z);
		scale_vector(&n, 5.0f);
		n = vector_add(n, v);
		glVertex3f(n.x, n.y, n.z);
		
		// Draw tangent
		glColor3f(1.0f, 1.0f, 0.0f);
		t = vector_add(v, vector_multiply_scalar(t, 3.0f));
		glVertex3f(v.x, v.y, v.z);
		glVertex3f(t.x, t.y, t.z);
		
		// Draw bitangent
		glColor3f(0.0f, 1.0f, 0.0f);
		b = vector_add(v, vector_multiply_scalar(b, 3.0f));
		glVertex3f(v.x, v.y, v.z);
		glVertex3f(b.x, b.y, b.z);
	}
	OOGLEND();
	
	OODebugEndWireframe(state);
}
#endif


- (void) setRetainedObject:(oo::Data)object forKey:(const std::string &)key
{
	oo::ToCxx(self)->_retainedObjects.insert_or_assign(key, oo::adopt(new OOMeshBuffer(std::move(object))));
}


#if SCRIBBLE
static void Scribble(void *bytes, size_t size)
{
	#if OOLITE_BIG_ENDIAN
	enum { kScribble = 0xFEEDFACE };
	#else
	enum { kScribble = 0xCEFAEDFE };
	#endif
	
	size /= sizeof (uint32_t);
	uint32_t *mem = bytes;
	while (size--)  *mem++ = kScribble;
}
#else
#define Scribble(bytes, size) do {} while (0)
#endif


/* valgrind complains that the memory allocated here isn't initialised
	 at the time OOCacheManager::writeDict is pushing it to the
	 cache. Not sure if that's a problem or not. - CIM */
- (void *) allocateBytesWithSize:(size_t)size count:(NSUInteger)count key:(const std::string &)key
{
	if (count == 0) { count=1; }
	size *= count;
	oo::Data holder;
	holder.setLength(size);	// zero-filled (malloc left it uninitialised)
	[self setRetainedObject:std::move(holder) forKey:key];
	void *bytes = oo::ToCxx(self)->_retainedObjects.find(key)->second->data().mutableBytes();
	if (bytes != NULL)
	{
		Scribble(bytes, size);
	}
	return bytes;
}


- (BOOL) allocateVertexBuffersWithCount:(NSUInteger)count
{
	oo::ToCxx(self)->_vertices = (Vector *)[self allocateBytesWithSize:sizeof *oo::ToCxx(self)->_vertices count:oo::ToCxx(self)->vertexCount key:"vertices"];
	return oo::ToCxx(self)->_vertices != NULL;
}


- (BOOL) allocateNormalBuffersWithCount:(NSUInteger)count
{
	oo::ToCxx(self)->_normals = (Vector *)[self allocateBytesWithSize:sizeof *oo::ToCxx(self)->_normals count:oo::ToCxx(self)->vertexCount key:"normals"];
	oo::ToCxx(self)->_tangents = (Vector *)[self allocateBytesWithSize:sizeof *oo::ToCxx(self)->_tangents count:oo::ToCxx(self)->vertexCount key:"tangents"];
	return oo::ToCxx(self)->_normals != NULL && oo::ToCxx(self)->_tangents != NULL;
}


- (BOOL) allocateFaceBuffersWithCount:(NSUInteger)count
{
	oo::ToCxx(self)->_faces = (OOMeshFace *)[self allocateBytesWithSize:sizeof *oo::ToCxx(self)->_faces count:oo::ToCxx(self)->faceCount key:"faces"];
	return	oo::ToCxx(self)->_faces != NULL;
}


- (BOOL) allocateVertexArrayBuffersWithCount:(NSUInteger)count
{
	oo::ToCxx(self)->_displayLists.indexArray = (GLint *)[self allocateBytesWithSize:sizeof *oo::ToCxx(self)->_displayLists.indexArray count:count * 3 key:"indexArray"];
	oo::ToCxx(self)->_displayLists.textureUVArray = (GLfloat *)[self allocateBytesWithSize:sizeof *oo::ToCxx(self)->_displayLists.textureUVArray count:count * 6 key:"textureUVArray"];
	oo::ToCxx(self)->_displayLists.vertexArray = (Vector *)[self allocateBytesWithSize:sizeof *oo::ToCxx(self)->_displayLists.vertexArray count:count * 3 key:"vertexArray"];
	oo::ToCxx(self)->_displayLists.normalArray = (Vector *)[self allocateBytesWithSize:sizeof *oo::ToCxx(self)->_displayLists.normalArray count:count * 3 key:"normalArray"];
	oo::ToCxx(self)->_displayLists.tangentArray = (Vector *)[self allocateBytesWithSize:sizeof *oo::ToCxx(self)->_displayLists.tangentArray count:count * 3 key:"tangentArray"];
	
	return	oo::ToCxx(self)->_faces != NULL &&
			oo::ToCxx(self)->_displayLists.indexArray != NULL &&
			oo::ToCxx(self)->_displayLists.textureUVArray != NULL &&
			oo::ToCxx(self)->_displayLists.vertexArray != NULL &&
			oo::ToCxx(self)->_displayLists.normalArray != NULL &&
			oo::ToCxx(self)->_displayLists.tangentArray != NULL;
}


- (void) renameTexturesFrom:(const std::string &)from to:(const std::string &)to
{
	/*	IMPORTANT: this has to be called before setUpMaterials..., so it can
		only be used during loading.
	*/
	OOMeshMaterialCount i;
	for (i = 0; i != oo::ToCxx(self)->materialCount; i++)
	{
		if (oo::ToCxx(self)->materialKeys[i] == from)
		{
			oo::ToCxx(self)->materialKeys[i] = to;
		}
	}
}

@end


static float FaceArea(GLuint *vertIndices, Vector *vertices)
{
	/*	Calculate areas using Heron's formula.	*/
	float	a2 = distance2(vertices[vertIndices[0]], vertices[vertIndices[1]]);
	float	b2 = distance2(vertices[vertIndices[1]], vertices[vertIndices[2]]);
	float	c2 = distance2(vertices[vertIndices[2]], vertices[vertIndices[0]]);
	return sqrt((2.0f * (a2 * b2 + b2 * c2 + c2 * a2) - (a2 * a2 + b2 * b2 +c2 * c2)) * 0.0625f);
}


static float FaceAreaCorrect(GLuint *vertIndices, Vector *vertices)
{
	/*	Calculate area of triangle.
		The magnitude of the cross product of two vectors is the area of
		the parallelogram they span. The area of a triangle is half the
		area of a parallelogram sharing two of its sides.
		Since we only use the area of the triangle as a weight factor,
		constant terms are irrelevant, so we don't bother halving the
		value.
	*/
	Vector AB = vector_subtract(vertices[vertIndices[1]], vertices[vertIndices[0]]);
	Vector AC = vector_subtract(vertices[vertIndices[2]], vertices[vertIndices[0]]);
	return magnitude(true_cross_product(AB, AC));
}


namespace cxx {

void OOMesh::checkNormalsAndAdjustWinding()
{
	OOJS_PROFILE_ENTER
	
	Vector				calculatedNormal;
	OOMeshFaceCount		i;
	
	OOCParameterAssert(_normalMode != kNormalModeExplicit);
	
	for (i = 0; i < faceCount; i++)
	{
		Vector v0, v1, v2, norm;
		v0 = _vertices[_faces[i].vertex[0]];
		v1 = _vertices[_faces[i].vertex[1]];
		v2 = _vertices[_faces[i].vertex[2]];
		norm = _faces[i].normal;
		
		calculatedNormal = normal_to_surface(v2, v1, v0);
		if (vector_equal(norm, kZeroVector))
		{
			norm = vector_flip(calculatedNormal);
			_faces[i].normal = norm;
		}
		
		/*	FIXME: for 2.0, either require explicit normals for every model
			or change to: if (dot_product(norm, calculatedNormal) < 0.0f)
			-- Ahruman 2010-01-23
		*/
		if (norm.x * calculatedNormal.x < 0 || norm.y * calculatedNormal.y < 0 || norm.z * calculatedNormal.z < 0)
		{
			// normal lies in the WRONG direction!
			// reverse the winding
			int v0 = _faces[i].vertex[0];
			_faces[i].vertex[0] = _faces[i].vertex[2];
			_faces[i].vertex[2] = v0;
			
			GLfloat f0 = _faces[i].s[0];
			_faces[i].s[0] = _faces[i].s[2];
			_faces[i].s[2] = f0;
			
			f0 = _faces[i].t[0];
			_faces[i].t[0] = _faces[i].t[2];
			_faces[i].t[2] = f0;
		}
	}
	
	OOJS_PROFILE_EXIT_VOID
}


void OOMesh::generateFaceTangents()
{
	OOJS_PROFILE_ENTER
	
	OOMeshFaceCount	i;
	for (i = 0; i < faceCount; i++)
	{
		OOMeshFace *face = _faces + i;
		
		/*	Generate tangents, i.e. vectors that run in the direction of the s
			texture coordinate. Based on code I found in a forum somewhere and
			then lost track of. Sorry to whomever I should be crediting.
			-- Ahruman 2008-11-23
		*/
		Vector vAB = vector_subtract(_vertices[face->vertex[1]], _vertices[face->vertex[0]]);
		Vector vAC = vector_subtract(_vertices[face->vertex[2]], _vertices[face->vertex[0]]);
		Vector nA = face->normal;
		
		// projAB = aB - (nA . vAB) * nA
		Vector vProjAB = vector_subtract(vAB, vector_multiply_scalar(nA, dot_product(nA, vAB)));
		Vector vProjAC = vector_subtract(vAC, vector_multiply_scalar(nA, dot_product(nA, vAC)));
		
		// delta s/t
		GLfloat dsAB = face->s[1] - face->s[0];
		GLfloat dsAC = face->s[2] - face->s[0];
		GLfloat dtAB = face->t[1] - face->t[0];
		GLfloat dtAC = face->t[2] - face->t[0];
		
		if (dsAC * dtAB > dsAB * dtAC)
		{
			face->tangent = vector_normal(vector_subtract(vector_multiply_scalar(vProjAC, dtAB), vector_multiply_scalar(vProjAB, dtAC)));
		}
		else
		{
			face->tangent = vector_normal(vector_subtract(vector_multiply_scalar(vProjAB, dtAC), vector_multiply_scalar(vProjAC, dtAB)));
		}			
	}
	
	OOJS_PROFILE_EXIT_VOID
}


void OOMesh::calculateVertexNormalsAndTangentsWithFaceRefs(VertexFaceRef *faceRefs)
{
	OOJS_PROFILE_ENTER
	
	OOCParameterAssert(faceRefs != NULL);
	
	NSUInteger	i,j;
	std::vector<float>	triangle_area(faceCount);
	
	OOCAssert(_normals != NULL && _tangents != NULL, "Normal/tangent buffers not allocated in %s", __PRETTY_FUNCTION__);
	
	for (i = 0 ; i < faceCount; i++)
	{
		triangle_area[i] = FaceArea(_faces[i].vertex, _vertices);
	}
	for (i = 0; i < vertexCount; i++)
	{
		Vector normal_sum = kZeroVector;
		Vector tangent_sum = kZeroVector;
		
		VertexFaceRef *vfr = &faceRefs[i];
		NSUInteger fIter, fCount = VFRGetCount(vfr);
		for (fIter = 0; fIter < fCount; fIter++)
		{
			j = VFRGetFaceAtIndex(vfr, fIter);
			
			float t = triangle_area[j]; // weight sum by area
			normal_sum = vector_add(normal_sum, vector_multiply_scalar(_faces[j].normal, t));
			tangent_sum = vector_add(tangent_sum, vector_multiply_scalar(_faces[j].tangent, t));
		}
		
		normal_sum = vector_normal_or_fallback(normal_sum, kBasisZVector);
		tangent_sum = vector_subtract(tangent_sum, vector_multiply_scalar(normal_sum, dot_product(tangent_sum, normal_sum)));
		tangent_sum = vector_normal_or_fallback(tangent_sum, kBasisXVector);
		
		_normals[i] = normal_sum;
		_tangents[i] = tangent_sum;
	}
	
	OOJS_PROFILE_EXIT_VOID
}


void OOMesh::calculateVertexTangentsWithFaceRefs(VertexFaceRef *faceRefs)
{
	OOJS_PROFILE_ENTER
	
	OOCParameterAssert(faceRefs != NULL);
	
	/*	This is conceptually broken.
		At the moment, it's calculating one tangent per "input" vertex. It should
		be calculating one tangent per "real" vertex, where a "real" vertex is
		defined as a combination of position, normal, material and texture
		coordinates.
		Currently, we don't have a format with unique "real" vertices.
		This basically means explicit-normal models without explicit tangents
		can't usefully be normal mapped.
		I don't intend to do anything about this pre-MSNR, although it might be
		possible to fix it by moving tangent generation to the same stage as
		smooth-grouped normal generation.
		-- Ahruman 2010-05-22
	*/
	NSUInteger	i,j;
	std::vector<float>	triangle_area(faceCount);
	for (i = 0 ; i < faceCount; i++)
	{
		triangle_area[i] = FaceAreaCorrect(_faces[i].vertex, _vertices);
	}
	for (i = 0; i < vertexCount; i++)
	{
		Vector tangent_sum = kZeroVector;
		
		VertexFaceRef *vfr = &faceRefs[i];
		NSUInteger fIter, fCount = VFRGetCount(vfr);
		for (fIter = 0; fIter < fCount; fIter++)
		{
			j = VFRGetFaceAtIndex(vfr, fIter);
			
			float t = triangle_area[j]; // weight sum by area
			tangent_sum = vector_add(tangent_sum, vector_multiply_scalar(_faces[j].tangent, t));
		}
		
		tangent_sum = vector_subtract(tangent_sum, vector_multiply_scalar(_normals[i], dot_product(_normals[i], tangent_sum)));
		tangent_sum = vector_normal_or_fallback(tangent_sum, kBasisXVector);
		
		_tangents[i] = tangent_sum;
	}
	
	OOJS_PROFILE_EXIT_VOID
}


/* profiling suggests this function takes a lot of time - almost all
 * the overhead of setting up a new ship is here. - CIM */
void OOMesh::getNormal(Vector *outNormal, Vector *outTangent, OOMeshVertexCount v_index, OOMeshSmoothGroup smoothGroup)
{
	OOJS_PROFILE_ENTER
	
	assert(outNormal != NULL && outTangent != NULL);
	
	NSUInteger j;
	Vector normal_sum = kZeroVector;
	Vector tangent_sum = kZeroVector;
	for (j = 0; j < faceCount; j++)
	{
		if (_faces[j].smoothGroup == smoothGroup)
		{
			if ((_faces[j].vertex[0] == v_index)||(_faces[j].vertex[1] == v_index)||(_faces[j].vertex[2] == v_index))
			{
				float area = FaceArea(_faces[j].vertex, _vertices);
				normal_sum = vector_add(normal_sum, vector_multiply_scalar(_faces[j].normal, area));
				tangent_sum = vector_add(tangent_sum, vector_multiply_scalar(_faces[j].tangent, area));
			}
		}
	}
	
	*outNormal = vector_normal_or_fallback(normal_sum, kBasisZVector);
	*outTangent = vector_normal_or_fallback(tangent_sum, kBasisXVector);
	
	OOJS_PROFILE_EXIT_VOID
}


void OOMesh::calculateBoundingVolumes()
{
	OOJS_PROFILE_ENTER
	
	OOMeshVertexCount	i;
	float				d_squared, length_longest_axis, length_shortest_axis;
	GLfloat				result;
	
	result = 0.0f;
	if (vertexCount)  bounding_box_reset_to_vector(&_boundingBox, _vertices[0]);
	else  bounding_box_reset(&_boundingBox);

	for (i = 0; i < vertexCount; i++)
	{
		d_squared = magnitude2(_vertices[i]);
		if (d_squared > result)  result = d_squared;
		bounding_box_add_vector(&_boundingBox, _vertices[i]);
	}

	length_longest_axis = _boundingBox.max.x - _boundingBox.min.x;
	if (_boundingBox.max.y - _boundingBox.min.y > length_longest_axis)
		length_longest_axis = _boundingBox.max.y - _boundingBox.min.y;
	if (_boundingBox.max.z - _boundingBox.min.z > length_longest_axis)
		length_longest_axis = _boundingBox.max.z - _boundingBox.min.z;

	length_shortest_axis = _boundingBox.max.x - _boundingBox.min.x;
	if (_boundingBox.max.y - _boundingBox.min.y < length_shortest_axis)
		length_shortest_axis = _boundingBox.max.y - _boundingBox.min.y;
	if (_boundingBox.max.z - _boundingBox.min.z < length_shortest_axis)
		length_shortest_axis = _boundingBox.max.z - _boundingBox.min.z;

	d_squared = (length_longest_axis + length_shortest_axis) * (length_longest_axis + length_shortest_axis) * 0.25; // square of average length
	_maxDrawDistance = d_squared * NO_DRAW_DISTANCE_FACTOR * NO_DRAW_DISTANCE_FACTOR;	// no longer based on the collision radius
	
	_collisionRadius = sqrtf(result);
	
	OOJS_PROFILE_EXIT_VOID
}


void OOMesh::rescaleByFactor(GLfloat factor)
{
	// Rescale base vertices used for geometry calculations.
	OOMeshVertexCount	i;
	Vector				*vertex = NULL;
	
	for (i = 0; i < vertexCount; i++)
	{
		vertex = &_vertices[i];
		*vertex = vector_multiply_scalar(*vertex, factor);
	}
	
	// Rescale actual display vertices.
	for (i = 0; i < _displayLists.count; i++)
	{
		vertex = &_displayLists.vertexArray[i];
		*vertex = vector_multiply_scalar(*vertex, factor);
	}
	
	calculateBoundingVolumes();
	octree = nullptr;
	baseFile.reset();	// Avoid octree cache.
	baseFileOctreeCacheRef.reset();
}


BoundingBox OOMesh::boundingBox()
{
	return _boundingBox;
}

}	// namespace cxx


static const char * const kOOCacheMeshes = "OOMesh";

// The OOCacheManager (OOMesh) category, as free functions next to the cache (the slice plan).

namespace {

oo::PList OOCacheManagerMeshDataForName(const std::string &inShipName)
{
	return cxx::OOCacheManager::sharedCache()->pListForKey(inShipName, kOOCacheMeshes);
}


void OOCacheManagerSetMeshData(const oo::PList &inData, const std::string &inShipName)
{
	if (inData)
	{
		cxx::OOCacheManager::sharedCache()->setPList(inData, inShipName, kOOCacheMeshes);
	}
}

}	// namespace


static const char * const kOOCacheOctrees = "octrees";

// The OOCacheManager (Octree) category, as free functions next to the cache (OOMesh.h).

oo::Ref<cxx::Octree> OOCacheManagerOctreeForModel(const std::string &inKey)
{
	oo::Ref<cxx::Octree>	result;
	cxx::OOCacheManager		*cache = cxx::OOCacheManager::sharedCache();

	const oo::PList data = cache->pListForKey(inKey, kOOCacheOctrees);	// null: absent
	if (data)
	{
		result = cxx::Octree::initWithDictionary(data);
	}

	return result;
}


void OOCacheManagerSetOctree(cxx::Octree *inOctree, const std::string &inKey)
{
	if (inOctree != nullptr)
	{
		cxx::OOCacheManager::sharedCache()->setPList(inOctree->dictionaryRepresentation(), inKey, kOOCacheOctrees);
	}
}


static void VFRAddFace(VertexFaceRef *vfr, NSUInteger index)
{
	OOCParameterAssert(vfr != NULL);
	
	if (index < UINT16_MAX && vfr->internCount < kVertexFaceDefInternalCount)
	{
		vfr->internFaces[vfr->internCount++] = index;
	}
	else
	{
		vfr->extra.push_back(index);
	}
}


static NSUInteger VFRGetCount(VertexFaceRef *vfr)
{
	OOCParameterAssert(vfr != NULL);
	
	return vfr->internCount + vfr->extra.size();
}


static NSUInteger VFRGetFaceAtIndex(VertexFaceRef *vfr, NSUInteger index)
{
	OOCParameterAssert(vfr != NULL && index < VFRGetCount(vfr));
	
	if (index < vfr->internCount)  return vfr->internFaces[index];
	else  return vfr->extra[index - vfr->internCount];
}
