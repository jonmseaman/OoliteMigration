/*	test_OOTexture.mm
	Unit tests for OOTexture (src/Core/Materials/OOTexture.h), the root of the textures: bead
	oo-whzh (Phase 3, house style of proposed ADR-0056; the Materials module's pattern, amendments
	oo-smy and oo-2en).

	OOTexture is abstract. OOConcreteTexture and OONullTexture derive from it in their own files
	and convert in their own beads. The root keeps the texture caches (the live textures by cache
	key, unretained; the recent textures, retained; every live texture, for graphics resets) and is
	the factory that answers a cached texture or a new OOConcreteTexture. It links the whole game
	but main (tests/unit/core/meson.build entry ['*']), on the hidden GL context of
	oo_gl_test_context.hpp, because the factory checks the GL extensions on first use. Nothing here
	reaches the resource manager: the named texture is found in the cache by its key, and the
	generator's -enqueue is the test's, so no file is read and no worker thread runs.

	The expectations were written against the Objective-C API and run on the unconverted class
	first. Two Objective-C subclasses stand for the concrete textures: TestTexture overrides what
	OOConcreteTexture does and caches itself under a key, BareTexture overrides nothing, so it
	answers the root's defaults.
	Run: bash tools/check-core-tests.sh
*/

#import "OOTexture.h"
#import "OOTextureInternal.h"
#import "OOTextureGenerator.h"
#import "OOConcreteTexture.h"
#import "OONullTexture.h"
#import "OODescription.h"

#include "oo_test.hpp"
#include "oo_gl_test_context.hpp"

#include <algorithm>
#include <string>
#include <vector>


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif


static int gTestDeallocs = 0;


// A texture as OOConcreteTexture is one: it caches itself under its key, and uncaches itself.
@interface TestTexture: OOTexture
{
@public
	std::optional<std::string>	_key;
	int							_rebinds;
	int							_applies;
}

- (id) initWithKey:(const std::optional<std::string> &)key;

@end


@implementation TestTexture

- (id) initWithKey:(const std::optional<std::string> &)key
{
	if ((self = [super init]))
	{
		_key = key;
		[self addToCaches];
	}
	return self;
}


- (void) dealloc
{
	gTestDeallocs++;
	[self removeFromCaches];
	[super dealloc];
}


- (void) apply									{ _applies++; }
- (NSSize) dimensions							{ return NSMakeSize(8, 4); }
- (BOOL) isMipMapped							{ return YES; }
- (void) forceRebind							{ _rebinds++; }
- (std::optional<std::string>) cxx_cacheKey		{ return _key; }
- (GLint) glTextureName							{ return 7; }
- (std::optional<std::string>) cxx_descriptionComponents	{ return std::string("test"); }
#ifndef NDEBUG
- (std::optional<std::string>) cxx_name			{ return std::string("test texture"); }
#endif

@end


// A texture that overrides nothing: the root's own answers.
@interface BareTexture: OOTexture
@end

@implementation BareTexture
@end


// A generator that is never queued: -enqueue answers what the test says, and counts.
@interface TestGenerator: OOTextureGenerator
{
@public
	std::optional<std::string>	_key;
	BOOL						_accept;
	int							_enqueues;
}
@end

@implementation TestGenerator

- (std::optional<std::string>) cxx_cacheKey		{ return _key; }
- (BOOL) enqueue								{ _enqueues++; return _accept; }

@end


namespace {

TestTexture *MakeTexture(const std::optional<std::string> &key)
{
	return [[[TestTexture alloc] initWithKey:key] autorelease];
}


TestGenerator *MakeGenerator(const std::optional<std::string> &key, BOOL accept)
{
	TestGenerator *generator = [[[TestGenerator alloc] cxx_initWithPath:std::string("test generator") options:0] autorelease];
	generator->_key = key;
	generator->_accept = accept;
	return generator;
}


// -clearCache autoreleases the recent textures (a C++ cache), which needs a scope to be released.
void ClearCache()
{
	@autoreleasepool
	{
		oo::AutoreleaseScope scope;
		[OOTexture clearCache];
	}
}


bool SameSize(NSSize size, double width, double height)
{
	return size.width == width && size.height == height;
}


#ifndef NDEBUG
bool Contains(const std::vector<oo::ObjCRef<OOTexture *>> &textures, OOTexture *texture)
{
	return std::find(textures.begin(), textures.end(), texture) != textures.end();
}
#endif

}	// namespace


OO_TEST(rootDefaults)
{
	@autoreleasepool
	{
		OOTexture *bare = [[[BareTexture alloc] init] autorelease];
		OO_CHECK([bare isKindOfClass:[OOWeakRefObject class]]);
		OO_CHECK([bare isFinishedLoading]);
		OO_CHECK(![bare cxx_cacheKey].has_value());
		OO_CHECK(![bare isRectangleTexture] && ![bare isCubeMap]);
		OO_CHECK(SameSize([bare texCoordsScale], 1, 1));
		OO_CHECK(OOIsNullPixMap([bare copyPixMapRepresentation]));
		[bare ensureFinishedLoading];

		// The subclass responsibilities log and answer zero.
		OO_CHECK(SameSize([bare dimensions], 0, 0));
		OO_CHECK(SameSize([bare originalDimensions], 0, 0));
		OO_CHECK(![bare isMipMapped]);
		OO_CHECK([bare glTextureName] == 0);
		[bare apply];
#ifndef NDEBUG
		OO_CHECK(![bare cxx_name].has_value());
		OO_CHECK([bare dataSize] == 0);
#endif
		OO_CHECK(oo::DescriptionOf(bare).starts_with("<BareTexture 0x"));
	}
}


OO_TEST(subclassOverrides)
{
	@autoreleasepool
	{
		TestTexture *texture = MakeTexture(std::nullopt);
		OO_CHECK(SameSize([texture originalDimensions], 8, 4));	// the root's, from -dimensions
		OO_CHECK(SameSize([texture texCoordsScale], 1, 1));
		OO_CHECK([texture glTextureName] == 7 && [texture isMipMapped]);
		[texture apply];
		OO_CHECK(texture->_applies == 1);
#ifndef NDEBUG
		OO_CHECK([texture dataSize] == 42);	// 8 * 4, mip-mapped: * 4 / 3
		OO_CHECK([texture cxx_name] == std::optional<std::string>("test texture"));
		[texture setTrace:YES];
		[texture setTrace:NO];
#endif
		const std::string text = oo::DescriptionOf(texture);
		OO_CHECK(text.starts_with("<TestTexture 0x") && text.ends_with(">{test}"));
	}
}


OO_TEST(cachesKeepAndForget)
{
	ClearCache();
	const int deallocs = gTestDeallocs;
	TestTexture *texture = nil;
	OOTexture *bare = nil;
	@autoreleasepool
	{
		texture = MakeTexture(std::string("test:cache"));
		bare = [[BareTexture alloc] init];
		OO_CHECK([OOTexture cxx_existingTextureForKey:std::string("test:cache")] == texture);
		OO_CHECK([OOTexture cxx_existingTextureForKey:std::nullopt] == nil);
		OO_CHECK([OOTexture cxx_existingTextureForKey:std::string("test:none")] == nil);
	}

	// The recent textures keep it alive; the live textures find it.
	OO_CHECK(gTestDeallocs == deallocs);
	OO_CHECK([OOTexture cxx_existingTextureForKey:std::string("test:cache")] == texture);
#ifndef NDEBUG
	@autoreleasepool
	{
		OO_CHECK(Contains([OOTexture cxx_cachedTexturesByAge], texture));
		OO_CHECK(!Contains([OOTexture cxx_cachedTexturesByAge], bare));	// no key: not cached
		const std::vector<oo::ObjCRef<OOTexture *>> all = [OOTexture cxx_allTextures];
		OO_CHECK(Contains(all, texture) && Contains(all, bare));
	}
#endif

	// Clearing forgets both caches, and releases what only they kept.
	@autoreleasepool
	{
		oo::AutoreleaseScope scope;
		[OOTexture clearCache];
		OO_CHECK([OOTexture cxx_existingTextureForKey:std::string("test:cache")] == nil);
	}
	OO_CHECK(gTestDeallocs == deallocs + 1);
#ifndef NDEBUG
	@autoreleasepool
	{
		OO_CHECK([OOTexture cxx_cachedTexturesByAge].empty());
		const std::vector<oo::ObjCRef<OOTexture *>> all = [OOTexture cxx_allTextures];
		OO_CHECK(Contains(all, bare));
		OO_CHECK(std::none_of(all.begin(), all.end(), [](const oo::ObjCRef<OOTexture *> &t) { return [t.get() isKindOfClass:[TestTexture class]]; }));
	}
#endif
	[bare release];
}


OO_TEST(rebindAllTextures)
{
	const int deallocs = gTestDeallocs;
	@autoreleasepool
	{
		TestTexture *cached = MakeTexture(std::string("test:rebind"));
		TestTexture *plain = MakeTexture(std::nullopt);
		[OOTexture rebindAllTextures];
		OO_CHECK(cached->_rebinds == 1 && plain->_rebinds == 1);

		// The recent textures are dropped; the live textures still find it while it lives.
		OO_CHECK([OOTexture cxx_existingTextureForKey:std::string("test:rebind")] == cached);
#ifndef NDEBUG
		OO_CHECK([OOTexture cxx_cachedTexturesByAge].empty());
#endif
	}
	OO_CHECK(gTestDeallocs == deallocs + 2);
	OO_CHECK([OOTexture cxx_existingTextureForKey:std::string("test:rebind")] == nil);
}


OO_TEST(namedTextureFromTheCache)
{
	OO_CHECK(OOTestGLContext());
	@autoreleasepool
	{
		OO_CHECK([OOTexture cxx_textureWithName:std::nullopt inFolder:std::string("Textures")] == nil);

		// Linear filtering: no anisotropy and no LOD bias in the key, whatever the extensions.
		const std::string key = OOGenerateTextureCacheKey(std::string("Textures"), "test.png", kOOTextureMinFilterLinear | kOOTextureMagFilterLinear, 0.5f, -0.25f);
		OO_CHECK(key == "Textures/test.png:0x0006/0/0");
		TestTexture *texture = MakeTexture(key);

		OO_CHECK([OOTexture cxx_textureWithName:std::string("test.png")
									   inFolder:std::string("Textures")
										options:kOOTextureMinFilterLinear | kOOTextureMagFilterLinear | kOOTextureNoFNFMessage
									 anisotropy:kOOTextureDefaultAnisotropy
										lodBias:kOOTextureDefaultLODBias] == texture);
		OO_CHECK([OOTexture cxx_textureWithConfiguration:oo::PList(oo::PList::Dict{ { "name", oo::PList("test.png") }, { "min_filter", oo::PList("linear") } })] == texture);
		OO_CHECK([OOTexture cxx_textureWithConfiguration:oo::PList(oo::PList::Dict{ { "name", oo::PList("test.png") } }) extraOptions:kOOTextureMinFilterLinear] == texture);

		// A specifier that names no texture.
		OO_CHECK([OOTexture cxx_textureWithConfiguration:oo::PList(oo::PList::Dict{ { "min_filter", oo::PList("linear") } })] == nil);
		OO_CHECK([OOTexture cxx_textureWithConfiguration:oo::PList(3.0)] == nil);
		OO_CHECK([OOTexture cxx_textureWithConfiguration:oo::PList()] == nil);
		ClearCache();
	}
}


OO_TEST(texturesFromGenerators)
{
	@autoreleasepool
	{
		ClearCache();
		OO_CHECK([OOTexture textureWithGenerator:nil] == nil);
		TestGenerator *refusing = MakeGenerator(std::string("test:refused"), NO);
		OO_CHECK([OOTexture textureWithGenerator:refusing] == nil && refusing->_enqueues == 1);

		TestGenerator *generator = MakeGenerator(std::string("test:gen"), YES);
		OOTexture *first = [OOTexture textureWithGenerator:generator];
		OO_CHECK([first isKindOfClass:[OOConcreteTexture class]] && generator->_enqueues == 1);
		OO_CHECK([first cxx_cacheKey] == std::optional<std::string>("test:gen"));
		OO_CHECK([OOTexture cxx_existingTextureForKey:std::string("test:gen")] == first);

		// Cached: the same texture, not queued again; unless the caller forces a new one.
		OO_CHECK([OOTexture textureWithGenerator:generator] == first && generator->_enqueues == 1);
		OOTexture *second = [OOTexture textureWithGenerator:generator enqueue:YES];
		OO_CHECK(second != nil && second != first && generator->_enqueues == 2);
		OO_CHECK([OOTexture cxx_existingTextureForKey:std::string("test:gen")] == second);

		// No key: never cached.
		TestGenerator *uncached = MakeGenerator(std::nullopt, YES);
		OOTexture *a = [OOTexture textureWithGenerator:uncached];
		OOTexture *b = [OOTexture textureWithGenerator:uncached];
		OO_CHECK(a != nil && b != nil && a != b && uncached->_enqueues == 2);
	}

	/*	The first texture's -dealloc (when the recent textures replaced it and the pool drained)
		uncached its key from the live textures, although the second texture had it by then.
	*/
	OO_CHECK([OOTexture cxx_existingTextureForKey:std::string("test:gen")] == nil);
	ClearCache();
}


OO_TEST(nullTexture)
{
	OO_CHECK(OOTestGLContext());
	@autoreleasepool
	{
		OOTexture *none = [OOTexture nullTexture];
		OO_CHECK([none isKindOfClass:[OONullTexture class]] && none == [OOTexture nullTexture]);
		OO_CHECK(SameSize([none dimensions], 0, 0) && ![none isMipMapped]);
#ifndef NDEBUG
		OO_CHECK([none cxx_name] == std::optional<std::string>("<null texture>"));
#endif
		[none forceRebind];

		// Applying it is applying none.
		GLuint name = 0;
		glGenTextures(1, &name);
		glBindTexture(GL_TEXTURE_2D, name);
		[none apply];
		GLint bound = -1;
		glGetIntegerv(GL_TEXTURE_BINDING_2D, &bound);
		OO_CHECK(bound == 0);
		glDeleteTextures(1, &name);
	}
}


OO_TEST(applyNone)
{
	OO_CHECK(OOTestGLContext());
	GLuint name = 0;
	glGenTextures(1, &name);
	glBindTexture(GL_TEXTURE_2D, name);
	GLint bound = -1;
	glGetIntegerv(GL_TEXTURE_BINDING_2D, &bound);
	OO_CHECK(bound == (GLint)name);
	[OOTexture applyNone];
	glGetIntegerv(GL_TEXTURE_BINDING_2D, &bound);
	OO_CHECK(bound == 0);
	glDeleteTextures(1, &name);
}


OO_TEST_MAIN()
