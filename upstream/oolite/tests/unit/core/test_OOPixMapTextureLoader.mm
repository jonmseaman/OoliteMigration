/*	test_OOPixMapTextureLoader.mm
	Unit tests for OOPixMapTextureLoader (src/Core/Materials/OOPixMapTextureLoader.h), the texture
	generator whose pixels are a pixmap made in memory (the planets' generated surface and cloud
	textures): bead oo-kvqq (Phase 3, house style of proposed ADR-0056; a leaf of the texture
	generators, amendments oo-zl36, oo-rr2x and oo-bj8 item 12).

	It takes over the pixmap it is given, answers its texture options with the defaults applied, and
	hands the pixels to the texture as they are, after making room for and generating mip-maps when
	its options ask for them. It links the whole game but main (tests/unit/core/meson.build entry
	['*']), on the hidden GL context of oo_gl_test_context.hpp. The expectations were written against
	the Objective-C API and run on the unconverted class first. Making a loader goes through the
	helper below, the only lines the conversion ports (amendment oo-bj8 item 11).
	Run: bash tools/check-core-tests.sh
*/

#import "OOPixMapTextureLoader.h"
#import "OOConcreteTexture.h"

#include "oo_test.hpp"
#include "oo_gl_test_context.hpp"

#include <cstdlib>


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif


namespace {

// The loaders' sizes come from their one-time set-up, which a path with no known extension runs
// (and then answers nil, reading nothing).
void SetUpLoaders()
{
	@autoreleasepool
	{
		(void)[OOTextureLoader cxx_loaderWithPath:std::string("unknown.type") options:0];
	}
}


// An 8 x 8 RGBA pixmap whose bytes count up from 1, allocated with malloc().
OOPixMap TestPixMap()
{
	OOPixMap pixMap = OOAllocatePixMap(8, 8, kOOPixMapRGBA, 0, 0);
	uint8_t *bytes = (uint8_t *)pixMap.pixels;
	for (unsigned i = 0; i < 8 * 8 * 4; i++)  bytes[i] = (uint8_t)(i + 1);
	return pixMap;
}


// [[OOPixMapTextureLoader alloc] initWithPixMap:...], autoreleased: the loader as a generator.
OOTextureGenerator *NewLoader(OOPixMap pixMap, uint32_t options, BOOL freeWhenDone)
{
	return [[[OOPixMapTextureLoader alloc] initWithPixMap:pixMap textureOptions:options freeWhenDone:freeWhenDone] autorelease];
}


void ClearCache()
{
	@autoreleasepool
	{
		oo::AutoreleaseScope scope;
		[OOTexture clearCache];
	}
}

}	// namespace


OO_TEST(takesThePixMap)
{
	OO_CHECK(OOTestGLContext());
	SetUpLoaders();
	@autoreleasepool
	{
		OOTextureGenerator *loader = NewLoader(TestPixMap(), kOOTextureMinFilterLinear | kOOTextureRepeatS, YES);
		OO_CHECK(loader != nil && [loader isKindOfClass:[OOTextureGenerator class]]);
		OO_CHECK([loader textureOptions] == OOApplyTextureOptionDefaults(kOOTextureMinFilterLinear | kOOTextureRepeatS));
		OO_CHECK([loader cxx_path].value_or("").starts_with("OOPixMap@"));
		OO_CHECK(![loader cxx_cacheKey].has_value());	// a generator: not cached

		OO_CHECK([loader enqueue]);
		OOPixMap result = kOONullPixMap;
		OOTextureDataFormat format = kOOPixMapInvalidFormat;
		uint32_t width = 0, height = 0;
		OO_CHECK([loader getResult:&result format:&format originalWidth:&width originalHeight:&height]);
		OO_CHECK(format == kOOPixMapRGBA && result.width == 8 && result.height == 8 && result.rowBytes == 32);
		OO_CHECK(width == 8 && height == 8);
		OO_CHECK(((const uint8_t *)result.pixels)[0] == 1 && ((const uint8_t *)result.pixels)[255] == 0);
		OOFreePixMap(&result);
	}
}


OO_TEST(refusals)
{
	OO_CHECK(OOTestGLContext());
	SetUpLoaders();
	@autoreleasepool
	{
		// Not a pixmap.
		OO_CHECK(NewLoader(kOONullPixMap, kOOTextureMinFilterLinear, YES) == nil);

		// Not taken over: the initialiser duplicates its own (still empty) pixmap, not the one it was
		// given, so it answers nil and the caller keeps its pixels. (As it has since 2010; kept.)
		OOPixMap kept = TestPixMap();
		OO_CHECK(NewLoader(kept, kOOTextureMinFilterLinear, NO) == nil);
		OO_CHECK(OOIsValidPixMap(kept) && ((const uint8_t *)kept.pixels)[0] == 1);
		OOFreePixMap(&kept);
	}
}


OO_TEST(loadsWithMipMaps)
{
	OO_CHECK(OOTestGLContext());
	SetUpLoaders();
	@autoreleasepool
	{
		OOTextureGenerator *loader = NewLoader(TestPixMap(), kOOTextureMinFilterMipMap, YES);
		OO_CHECK([loader textureOptions] == OOApplyTextureOptionDefaults(kOOTextureMinFilterMipMap));
		OO_CHECK([loader enqueue]);
		OOPixMap result = kOONullPixMap;
		OOTextureDataFormat format = kOOPixMapInvalidFormat;
		OO_CHECK([loader getResult:&result format:&format originalWidth:NULL originalHeight:NULL]);
		OO_CHECK(result.width == 8 && result.height == 8 && format == kOOPixMapRGBA);
		OO_CHECK(((const uint8_t *)result.pixels)[0] == 1);	// the base level as given
		OOFreePixMap(&result);
	}
}


OO_TEST(aTextureOfTheGenerator)
{
	OO_CHECK(OOTestGLContext());
	SetUpLoaders();
	@autoreleasepool
	{
		OOTextureGenerator *loader = NewLoader(TestPixMap(), kOOTextureDefaultOptions | kOOTextureRepeatS, YES);
		OOTexture *texture = [OOTexture textureWithGenerator:loader];
		OO_CHECK([texture isKindOfClass:[OOConcreteTexture class]]);
		[texture ensureFinishedLoading];
		OO_CHECK([texture dimensions].width == 8 && [texture dimensions].height == 8);
		OO_CHECK([texture isFinishedLoading]);
	}
	ClearCache();
}


OO_TEST_MAIN()
