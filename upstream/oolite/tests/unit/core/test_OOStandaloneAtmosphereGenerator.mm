/*	test_OOStandaloneAtmosphereGenerator.mm
	Unit tests for OOStandaloneAtmosphereGenerator (src/Core/Materials/OOStandaloneAtmosphereGenerator.h),
	the texture generator of a planet's cloud layer when its surface is not generated: bead oo-y3dd
	(Phase 3, house style of proposed ADR-0056; a leaf of the texture generators, amendments oo-zl36,
	oo-rr2x and oo-kvqq).

	It reads the cloud parameters from the planet's material parameters (colours as PList::Object
	nodes holding OOColors), sizes its texture by the detail level (no universe here: the lowest,
	so 512 x 512, or 512 x 256 with 3D noise), keys it by its parameters, and fills it with clouds
	from the seed's noise, their alpha scaled by cloud_alpha. It links the whole game but main
	(tests/unit/core/meson.build entry ['*']), on the hidden GL context of oo_gl_test_context.hpp.
	The expectations were written against the Objective-C API and run on the unconverted class
	first. Making a generator and the class methods go through the helpers below, the only lines a
	conversion ports (amendment oo-bj8 item 11).
	Run: bash tools/check-core-tests.sh test_OOStandaloneAtmosphereGenerator
*/

#import "OOStandaloneAtmosphereGenerator.h"
#import "OOConcreteTexture.h"
#import "OOColor.h"
#import "OODescription.h"
#import "OOObjCPList.h"

#include "oo_test.hpp"
#include "oo_gl_test_context.hpp"

#include <cstdlib>
#include <cstring>
#include <string>


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif


namespace {

const RANROTSeed kSeed = { 12345, 67890 };


// The loaders' sizes come from their one-time set-up, which a path with no known extension runs
// (and then answers nil, reading nothing).
void SetUp()
{
	OO_CHECK(OOTestGLContext());
	@autoreleasepool
	{
		(void)[OOTextureLoader cxx_loaderWithPath:std::string("unknown.type") options:0];
	}
}


oo::PList PlanetInfo(float cloudAlpha, bool perlin3d)
{
	return oo::PList(oo::PList::Dict{
		{ "cloud_alpha", oo::PList(cloudAlpha) },
		{ "cloud_fraction", oo::PList(0.5) },
		{ "cloud_color", oo::PListObject([OOColor colorWithRed:1.0f green:0.5f blue:0.25f alpha:1.0f]) },
		{ "polar_cloud_color", oo::PListObject([OOColor whiteColor]) },
		{ "perlin_3d", oo::PList(perlin3d) },
	});
}


// --- The only lines a conversion ports ----------------------------------------------------------

// [[OOStandaloneAtmosphereGenerator alloc] initWithPlanetInfo:seed:], autoreleased, as a generator.
OOTextureGenerator *NewGenerator(const oo::PList &info, RANROTSeed seed)
{
	return [[[OOStandaloneAtmosphereGenerator alloc] initWithPlanetInfo:info seed:seed] autorelease];
}


// +generateAtmosphereTexture:withInfo:seed:; the texture, or nil where it answered NO.
OOTexture *GenerateAtmosphere(const oo::PList &info, RANROTSeed seed)
{
	OOTexture *texture = nil;
	return [OOStandaloneAtmosphereGenerator generateAtmosphereTexture:&texture withInfo:info seed:seed] ? texture : nil;
}


// +planetTextureWithInfo:seed:.
OOTexture *PlanetTexture(const oo::PList &info, RANROTSeed seed)
{
	return [OOStandaloneAtmosphereGenerator planetTextureWithInfo:info seed:seed];
}

// --------------------------------------------------------------------------------------------------


struct Generated
{
	bool				ok = false;
	OOPixMap			pixMap = kOONullPixMap;
	OOTextureDataFormat	format = kOOPixMapInvalidFormat;

	~Generated()	{ OOFreePixMap(&pixMap); }

	const uint8_t *bytes() const	{ return (const uint8_t *)pixMap.pixels; }
	size_t size() const				{ return (size_t)pixMap.rowBytes * pixMap.height; }
};


void Generate(OOTextureGenerator *generator, Generated &generated)
{
	OO_CHECK([generator enqueue]);
	generated.ok = [generator getResult:&generated.pixMap format:&generated.format originalWidth:NULL originalHeight:NULL];
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


OO_TEST(settings)
{
	SetUp();
	@autoreleasepool
	{
		OOTextureGenerator *generator = NewGenerator(PlanetInfo(0.75f, false), kSeed);
		OO_CHECK(generator != nil && [generator isKindOfClass:[OOTextureGenerator class]]);
		OO_CHECK([generator textureOptions] == (kOOTextureMinFilterLinear | kOOTextureMagFilterLinear | kOOTextureRepeatS | kOOTextureNoShrink));
		OO_CHECK([generator cxx_path].value_or("").starts_with("OOStandaloneAtmosphereTexture@"));

		// Keyed by the scale (512: 2), the size (not known until it loads), the seed and the clouds;
		// the air colour is never set.
		const std::string key = [generator cxx_cacheKey].value_or("");
		OO_CHECK(key.starts_with("OOStandaloneAtmosphereGenerator-@2\n0,0/12345,67890/0.750000/0.500000/0.000000,0.000000,0.000000/"));
		OO_CHECK([NewGenerator(PlanetInfo(0.75f, false), kSeed) cxx_cacheKey] == std::optional<std::string>(key));
		OO_CHECK([NewGenerator(PlanetInfo(0.75f, false), (RANROTSeed){ 1, 2 }) cxx_cacheKey] != std::optional<std::string>(key));

		OO_CHECK(oo::DescriptionOf(generator).find("{seed: 12345,67890}") != std::string::npos);
	}
}


OO_TEST(generatesClouds)
{
	SetUp();
	@autoreleasepool
	{
		Generated a, b;
		Generate(NewGenerator(PlanetInfo(1.0f, false), kSeed), a);
		OO_CHECK(a.ok && a.format == kOOPixMapRGBA && a.pixMap.width == 512 && a.pixMap.height == 512 && a.pixMap.rowBytes == 2048);

		// The same seed and parameters give the same clouds.
		Generate(NewGenerator(PlanetInfo(1.0f, false), kSeed), b);
		OO_CHECK(b.ok && b.size() == a.size() && std::memcmp(a.bytes(), b.bytes(), a.size()) == 0);

		// Some cloud, some clear sky.
		bool someCloud = false, someClear = false;
		for (size_t i = 3; i < a.size(); i += 4)
		{
			if (a.bytes()[i] > 128)  someCloud = true;
			if (a.bytes()[i] < 128)  someClear = true;
		}
		OO_CHECK(someCloud && someClear);

		// No cloud alpha: transparent everywhere.
		Generated clear;
		Generate(NewGenerator(PlanetInfo(0.0f, false), kSeed), clear);
		bool allClear = clear.ok;
		for (size_t i = 3; i < clear.size(); i += 4)  allClear = allClear && clear.bytes()[i] == 0;
		OO_CHECK(allClear);

		// 3D noise: twice as wide as high.
		Generated wide;
		Generate(NewGenerator(PlanetInfo(1.0f, true), kSeed), wide);
		OO_CHECK(wide.ok && wide.pixMap.width == 512 && wide.pixMap.height == 256);
	}
}


OO_TEST(textures)
{
	SetUp();
	@autoreleasepool
	{
		OOTexture *atmosphere = GenerateAtmosphere(PlanetInfo(1.0f, false), kSeed);
		OO_CHECK([atmosphere isKindOfClass:[OOConcreteTexture class]]);
		[atmosphere ensureFinishedLoading];
		OO_CHECK([atmosphere isFinishedLoading] && [atmosphere dimensions].width == 512 && [atmosphere dimensions].height == 512);

		OOTexture *texture = PlanetTexture(PlanetInfo(1.0f, true), (RANROTSeed){ 3, 4 });
		OO_CHECK([texture isKindOfClass:[OOConcreteTexture class]]);
		[texture ensureFinishedLoading];
		OO_CHECK([texture dimensions].width == 512 && [texture dimensions].height == 256);
	}
	ClearCache();
}


OO_TEST_MAIN()
