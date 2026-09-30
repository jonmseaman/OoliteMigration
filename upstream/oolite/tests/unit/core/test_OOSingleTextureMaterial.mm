/*	test_OOSingleTextureMaterial.mm
	Unit tests for OOSingleTextureMaterial (src/Core/Materials/OOSingleTextureMaterial.h): bead
	oo-zxzb, converted after its superclass OOBasicMaterial (bead oo-vl43; proposed ADR-0056,
	amendments oo-smy and oo-vl43).

	A basic material with one texture. This pins, through the Objective-C API its callers use
	(OOPlanetDrawable, OOPlanetEntity, the convenience creators), what it computed before the
	conversion: which texture specifier each initialiser asks for and when it fails (no name, no
	texture), the configuration reaching the basic material, the texture kept for the material's
	life, what -doApply / -unapplyWithNext: do to the texture and the GL material, the loading and
	cube-map questions it passes to the texture, and the description.
	Run: bash tools/check-core-tests.sh
*/

#import "OOSingleTextureMaterial.h"
#import "OODescription.h"

#include "oo_gl_test_context.hpp"
#include "oo_test.hpp"

#include <cstdlib>
#include <vector>


/*	The game's OOLogging.mm reaches the resource manager, so it is not linked; what the material
	and the GL error check call of it is defined here.
*/
void OOLogGenericSubclassResponsibilityForFunction(const char *inFunction)	{ (void)inFunction; }
void OOLogGenericParameterErrorForFunction(const char *inFunction)			{ (void)inFunction; }
void OOLogIndent(void)  {}
void OOLogOutdent(void)  {}


/*	OOTexture (OOTexture.mm links the texture loaders and the game) is a stand-in that records what
	the material asks of it (proposed ADR-0056, amendment oo-z1s4 item 4). +cxx_textureWithConfiguration:
	answers nil for a null specifier, or for the name "missing", as a texture that fails to load does.
*/
static int gTextureApplyNones = 0;
static int gTexturesDeallocated = 0;
static std::vector<oo::PList> gTextureConfigurations;

@interface OOTexture: OOObject
{
@public
	oo::PList	_configuration;
	int			_applies;
	int			_ensures;
	BOOL		_finished;
	BOOL		_cubeMap;
}
+ (void) applyNone;
+ (id) cxx_textureWithConfiguration:(const oo::PList &)configuration;
- (void) apply;
- (void) ensureFinishedLoading;
- (BOOL) isFinishedLoading;
- (BOOL) isCubeMap;
@end

@implementation OOTexture

+ (void) applyNone	{ gTextureApplyNones++; }

+ (id) cxx_textureWithConfiguration:(const oo::PList &)configuration
{
	gTextureConfigurations.push_back(configuration);
	if (configuration.isNull() || configuration == oo::PList("missing"))  return nil;
	OOTexture *texture = [[[OOTexture alloc] init] autorelease];
	texture->_configuration = configuration;
	return texture;
}

- (void) dealloc						{ gTexturesDeallocated++; [super dealloc]; }
- (void) apply							{ _applies++; }
- (void) ensureFinishedLoading			{ _ensures++; }
- (BOOL) isFinishedLoading				{ return _finished; }
- (BOOL) isCubeMap						{ return _cubeMap; }
- (std::optional<std::string>) cxx_description	{ return std::string("<TestTexture>"); }

@end


/*	The texture specifier OOTexture.mm makes of a diffuse_map value, recorded: a dictionary naming
	what it was given (the game's own is pinned by the texture's tests).
*/
oo::PList cxx_OOTextureSpecFromObject(const oo::PList &object, const std::optional<std::string> &defaultName)
{
	return oo::PList(oo::PList::Dict{
		{ "object", object.isNull() ? oo::PList("(null)") : object },
		{ "defaultName", oo::PList(defaultName.value_or("(nil)")) },
	});
}


// Link stubs (amendment oo-zffj item 2), never reached here: OOOpenGL.mm's GL state dump.
cxx::OOOpenGLExtensionManager *cxx::OOOpenGLExtensionManager::sharedManager()	{ std::abort(); }
GLint cxx::OOOpenGLExtensionManager::textureUnitCount()							{ std::abort(); }


// UNIVERSE is gSharedUniverse: nil, so not reduced detail and no shaders.
@class Universe;
Universe *gSharedUniverse = nil;


namespace {

OOTexture *MakeTexture()
{
	return [OOTexture cxx_textureWithConfiguration:oo::PList("hull.png")];
}


OOSingleTextureMaterial *Make(const std::optional<std::string> &name, OOTexture *texture, const oo::PList &configuration = oo::PList())
{
	return [[[OOSingleTextureMaterial alloc] initWithName:name texture:texture configuration:configuration] autorelease];
}


bool Same(const GLfloat *a, std::initializer_list<GLfloat> b)
{
	const GLfloat *e = b.begin();
	for (int i = 0; i < 4; i++)
	{
		if (a[i] != e[i])  return false;
	}
	return true;
}

}	// namespace


OO_TEST(initWithTexture)
{
	@autoreleasepool
	{
		OOTexture *texture = MakeTexture();
		OOSingleTextureMaterial *m = Make(std::string("Hull"), texture, oo::PList(oo::PList::Dict{ { "diffuse_color", oo::PList("redColor") } }));
		OO_CHECK(m != nil && [m cxx_name] == std::optional<std::string>("Hull"));
		GLfloat c[4] = {};
		[m getDiffuseComponents:c];
		OO_CHECK(Same(c, { 1, 0, 0, 1 }));	// the configuration reached the basic material
		OO_CHECK([m shininess] == 10);
#ifndef NDEBUG
		const std::vector<oo::ObjCRef<OOTexture *>> textures = [m cxx_allTextures];
		OO_CHECK(textures.size() == 1 && textures[0].get() == texture);
#endif

		// No name, or no texture: no material.
		OO_CHECK(Make(std::nullopt, texture) == nil);
		OO_CHECK(Make(std::string("Bare"), nil) == nil);
	}
}


OO_TEST(initWithConfiguration)
{
	@autoreleasepool
	{
		// A configuration: the texture is the diffuse_map's specifier, with the name as its default.
		gTextureConfigurations.clear();
		OOSingleTextureMaterial *m = [[[OOSingleTextureMaterial alloc] initWithName:std::string("Hull") configuration:oo::PList(oo::PList::Dict{
			{ "diffuse_map", oo::PList("hull_diffuse.png") },
		})] autorelease];
		OO_CHECK(m != nil);
		OO_CHECK(gTextureConfigurations.size() == 1 && gTextureConfigurations[0] == oo::PList(oo::PList::Dict{
			{ "object", oo::PList("hull_diffuse.png") }, { "defaultName", oo::PList("Hull") } }));

		// No diffuse_map: the specifier of nothing, still with the name as its default.
		gTextureConfigurations.clear();
		m = [[[OOSingleTextureMaterial alloc] initWithName:std::string("Plain") configuration:oo::PList(oo::PList::Dict{})] autorelease];
		OO_CHECK(m != nil && gTextureConfigurations.size() == 1);
		OO_CHECK(gTextureConfigurations[0] == oo::PList(oo::PList::Dict{ { "object", oo::PList("(null)") }, { "defaultName", oo::PList("Plain") } }));

		// No configuration: the name is the texture's specifier.
		gTextureConfigurations.clear();
		m = [[[OOSingleTextureMaterial alloc] initWithName:std::string("named.png") configuration:oo::PList()] autorelease];
		OO_CHECK(m != nil && gTextureConfigurations.size() == 1 && gTextureConfigurations[0] == oo::PList("named.png"));
		OO_CHECK([m cxx_name] == std::optional<std::string>("named.png"));

		// Neither: a null specifier, no texture, no material. A texture that fails: no material.
		gTextureConfigurations.clear();
		OO_CHECK([[[OOSingleTextureMaterial alloc] initWithName:std::nullopt configuration:oo::PList()] autorelease] == nil);
		OO_CHECK(gTextureConfigurations.size() == 1 && gTextureConfigurations[0].isNull());
		OO_CHECK([[[OOSingleTextureMaterial alloc] initWithName:std::string("missing") configuration:oo::PList()] autorelease] == nil);
	}
}


OO_TEST(textureKeptForTheMaterialsLife)
{
	const int deallocated = gTexturesDeallocated;
	OOSingleTextureMaterial *m = nil;
	@autoreleasepool
	{
		m = [Make(std::string("Kept"), MakeTexture()) retain];
	}
	OO_CHECK(gTexturesDeallocated == deallocated);
	[m release];
	OO_CHECK(gTexturesDeallocated == deallocated + 1);
}


OO_TEST(texturesQuestions)
{
	@autoreleasepool
	{
		OOTexture *texture = MakeTexture();
		OOSingleTextureMaterial *m = Make(std::string("Asks"), texture);
		OO_CHECK(![m isFinishedLoading] && ![m wantsNormalsAsTextureCoordinates]);
		texture->_finished = YES;
		texture->_cubeMap = YES;
		OO_CHECK([m isFinishedLoading] && [m wantsNormalsAsTextureCoordinates]);
		[m ensureFinishedLoading];
		OO_CHECK(texture->_ensures == 1);
#if OO_MULTITEXTURE
		OO_CHECK([m countOfTextureUnitsWithBaseCoordinates] == 1);
#endif
		[m setBindingTarget:nil];
		OO_CHECK([m permitSpecular]);
	}
}


OO_TEST(doApply)
{
	if (!OOTestGLContext())  { OO_CHECK(false); return; }
	@autoreleasepool
	{
		OOTexture *texture = MakeTexture();
		OOSingleTextureMaterial *m = Make(std::string("Applied"), texture);
		[m setDiffuseRed:0.5f green:0.25f blue:0.125f alpha:1];
		const int applyNones = gTextureApplyNones;
		OO_CHECK([m doApply]);
		OO_CHECK(texture->_applies == 1);
		OO_CHECK(gTextureApplyNones == applyNones);	// not exactly a basic material
		GLfloat c[4] = {};
		glGetMaterialfv(GL_FRONT, GL_DIFFUSE, c);
		OO_CHECK(Same(c, { 0.5f, 0.25f, 0.125f, 1 }));

		[m apply];
		OO_CHECK([OOMaterial current] == m && texture->_applies == 2);
		[OOMaterial applyNone];
		OO_CHECK([OOMaterial current] == nil);
	}
}


OO_TEST(unapplyWithNext)
{
	if (!OOTestGLContext())  { OO_CHECK(false); return; }
	@autoreleasepool
	{
		OOSingleTextureMaterial *m = Make(std::string("Current"), MakeTexture());
		[m setDiffuseRed:0.5f green:0.25f blue:0.125f alpha:1];
		[m doApply];
		GLfloat c[4] = {};

		// Another textured material: the texture stays, and so does the GL material.
		int applyNones = gTextureApplyNones;
		[m unapplyWithNext:Make(std::string("Next"), MakeTexture())];
		OO_CHECK(gTextureApplyNones == applyNones);
		glGetMaterialfv(GL_FRONT, GL_DIFFUSE, c);
		OO_CHECK(Same(c, { 0.5f, 0.25f, 0.125f, 1 }));

		// A basic material: no texture; it sets its own GL material.
		[m unapplyWithNext:[[[OOBasicMaterial alloc] cxx_initWithName:std::string("Basic")] autorelease]];
		OO_CHECK(gTextureApplyNones == applyNones + 1);
		glGetMaterialfv(GL_FRONT, GL_DIFFUSE, c);
		OO_CHECK(Same(c, { 0.5f, 0.25f, 0.125f, 1 }));

		// Nothing: no texture, and the default material (which also has none).
		applyNones = gTextureApplyNones;
		[m unapplyWithNext:nil];
		OO_CHECK(gTextureApplyNones == applyNones + 2);
		glGetMaterialfv(GL_FRONT, GL_DIFFUSE, c);
		OO_CHECK(Same(c, { 1, 1, 1, 1 }));
	}
}


OO_TEST(description)
{
	@autoreleasepool
	{
		const std::string text = oo::DescriptionOf(Make(std::string("Hull"), MakeTexture()));
		OO_CHECK(text.starts_with("<OOSingleTextureMaterial 0x"));
		OO_CHECK(text.ends_with(">{<TestTexture>}"));
	}
}

OO_TEST_MAIN()
