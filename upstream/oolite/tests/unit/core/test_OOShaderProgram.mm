/*	test_OOShaderProgram.mm
	Unit tests for OOShaderProgram (src/Core/Materials/OOShaderProgram.h): bead oo-f9zg.

	A linked GLSL program, made from sources or from shader files and shared through a cache keyed
	by what made it. This pins, through the Objective-C API its callers use (OOShaderMaterial,
	OOShaderUniform, DustEntity), what it did before the conversion, in a hidden GL context: the
	programs made (the prefix prepended, an empty prefix counting as none, the attribute bindings),
	the failures (no source, a source that does not compile, a file that is not there), the cache
	(one program per key while it lives, none without a key, a new one once it has gone), the
	files asked for, and -apply / +applyNone (the program in use, kept while it is). There is no
	game view here, so no standard matrix uniforms are bound. Those checks ran on the Objective-C
	class first and now run through the facade. After them: the C++ API (null where it answered
	nil, the cache shared with the facade's class methods) and the facade's identity.
	Run: bash tools/check-core-tests.sh
*/

#import "OOShaderProgram.h"
#import "OODescription.h"

#include "oo_gl_test_context.hpp"
#include "oo_test.hpp"

#include <map>
#include <string>
#include <vector>


// --- Stubs --------------------------------------------------------------------------------------

// OOLogging.mm's (it would bring the resource manager into the link).
void OOLogIndent(void)  {}
void OOLogOutdent(void)  {}
const char *const cxx_kOOLogFileNotFound = "files.notFound";


// The resource manager: the extension manager's two class methods, and shader files from a table.
static std::map<std::string, std::string> gShaderFiles;
static std::vector<std::string> gShaderFileRequests;

@interface ResourceManager: OOObject
+ (std::vector<std::string>) cxx_paths;
+ (oo::PList) cxx_dictionaryFromFilesNamed:(const std::string &)fileName inFolder:(const std::string &)folderName andMerge:(BOOL)mergeFiles;
+ (std::optional<std::string>) cxx_stringFromFilesNamed:(const std::string &)fileName inFolder:(const std::string &)folderName;
@end

@implementation ResourceManager
+ (std::vector<std::string>) cxx_paths  { return {}; }
+ (oo::PList) cxx_dictionaryFromFilesNamed:(const std::string &)fileName inFolder:(const std::string &)folderName andMerge:(BOOL)mergeFiles  { return oo::PList(oo::PList::Dict{}); }
+ (std::optional<std::string>) cxx_stringFromFilesNamed:(const std::string &)fileName inFolder:(const std::string &)folderName
{
	gShaderFileRequests.push_back(folderName + "/" + fileName);
	auto found = gShaderFiles.find(fileName);
	if (found == gShaderFiles.end())  return std::nullopt;
	return found->second;
}
@end


@interface OORegExpMatcher: OOObject
+ (instancetype) regExpMatcher;
- (BOOL) string:(const std::string &)string matchesExpression:(const std::string &)regExp;
@end

@implementation OORegExpMatcher
+ (instancetype) regExpMatcher  { return [[[self alloc] init] autorelease]; }
- (BOOL) string:(const std::string &)string matchesExpression:(const std::string &)regExp  { return NO; }
@end


OOShaderSetting cxx_OOShaderSettingFromString(const std::string &string)
{
	return string == "SHADERS_FULL" ? SHADERS_FULL : SHADERS_NOT_SUPPORTED;
}


// UNIVERSE is gSharedUniverse: nil, so there is no game view and no matrix manager.
@class Universe;
Universe *gSharedUniverse = nil;


namespace {

const std::string kVertex =
	"attribute vec3 tangent;\n"
	"void main() { gl_Position = gl_Vertex + vec4(tangent, 0.0); }\n";
const std::string kFragment =
	"void main() { gl_FragColor = vec4(1.0); }\n";
const std::string kFragmentNeedingPrefix =
	"void main() { gl_FragColor = vec4(PREFIXED); }\n";

const oo::PList kBindings = oo::PList(oo::PList::Dict{ { "tangent", oo::PList::signedInteger(15) } });


typedef GLint (APIENTRY *GetAttribLocationProc)(GLhandleARB, const GLcharARB *);
typedef GLboolean (APIENTRY *IsProgramProc)(GLuint);
GetAttribLocationProc gGetAttribLocation = nullptr;
IsProgramProc gIsProgram = nullptr;


bool SetUp()
{
	if (!OOTestGLContext())  return false;
	[OOOpenGLExtensionManager sharedManager];	// loads the ARB shader entry points
	gGetAttribLocation = (GetAttribLocationProc)SDL_GL_GetProcAddress("glGetAttribLocationARB");
	gIsProgram = (IsProgramProc)SDL_GL_GetProcAddress("glIsProgram");
	return gGetAttribLocation != nullptr && gIsProgram != nullptr;
}


OOShaderProgram *Make(const std::optional<std::string> &vertex, const std::optional<std::string> &fragment, const std::optional<std::string> &prefix = std::nullopt, const std::optional<std::string> &key = std::nullopt)
{
	return [OOShaderProgram shaderProgramWithVertexShader:vertex fragmentShader:fragment vertexShaderName:std::string("v") fragmentShaderName:std::string("f") prefix:prefix attributeBindings:kBindings cacheKey:key];
}


GLint CurrentProgram()
{
	GLint current = -1;
	glGetIntegerv(GL_CURRENT_PROGRAM, &current);
	return current;
}

}	// namespace


OO_TEST(programsFromSources)
{
	if (!SetUp())  { OO_CHECK(false); return; }
	@autoreleasepool
	{
		OOShaderProgram *p = Make(kVertex, kFragment);
		OO_CHECK(p != nil && [p program] != 0);
		OO_CHECK(gGetAttribLocation([p program], "tangent") == 15);	// the attribute bindings

		OO_CHECK(Make(std::nullopt, kFragment) != nil);	// one shader is enough
		OO_CHECK(Make(kVertex, std::nullopt) != nil);
		OO_CHECK(glGetError() == GL_NO_ERROR);

		/*	A failed initialiser leaves exactly one GL_INVALID_VALUE behind (observed on the
			Objective-C class before its conversion: its teardown deletes program 0), and a
			successful one none.
		*/
		OO_CHECK(Make(std::nullopt, std::nullopt) == nil);	// none is not
		OO_CHECK(glGetError() == GL_INVALID_VALUE && glGetError() == GL_NO_ERROR);

		// The prefix is prepended to both sources; an empty one is none.
		OO_CHECK(Make(kVertex, kFragmentNeedingPrefix) == nil);
		OO_CHECK(glGetError() == GL_INVALID_VALUE && glGetError() == GL_NO_ERROR);
		OO_CHECK(Make(kVertex, kFragmentNeedingPrefix, std::string("")) == nil);
		OO_CHECK(glGetError() == GL_INVALID_VALUE && glGetError() == GL_NO_ERROR);
		OO_CHECK(Make(kVertex, kFragmentNeedingPrefix, std::string("#define PREFIXED 0.5\n")) != nil);
		OO_CHECK(glGetError() == GL_NO_ERROR);

		OO_CHECK(Make(std::string("this is not GLSL"), kFragment) == nil);	// does not compile
		OO_CHECK(glGetError() == GL_INVALID_VALUE && glGetError() == GL_NO_ERROR);
	}
}


OO_TEST(cache)
{
	if (!SetUp())  { OO_CHECK(false); return; }
	OOShaderProgram *kept = nil;
	GLhandleARB handle = 0;
	@autoreleasepool
	{
		OOShaderProgram *a = Make(kVertex, kFragment, std::nullopt, std::string("key-a"));
		OO_CHECK(a != nil && Make(kVertex, kFragment, std::nullopt, std::string("key-a")) == a);	// one per key
		OO_CHECK(Make(std::string("anything: it is not compiled"), std::nullopt, std::nullopt, std::string("key-a")) == a);
		OO_CHECK(Make(kVertex, kFragment, std::nullopt, std::string("key-b")) != a);
		OO_CHECK(Make(kVertex, kFragment) != Make(kVertex, kFragment));	// no key: never shared
		kept = [a retain];
		handle = [a program];
	}
	@autoreleasepool
	{
		// Still alive (kept): still the cached one.
		OO_CHECK(Make(kVertex, kFragment, std::nullopt, std::string("key-a")) == kept);
	}
	[kept release];
	@autoreleasepool
	{
		// Gone: the cache forgot it, and its GL program was deleted.
		OO_CHECK(!gIsProgram(handle));
		OOShaderProgram *again = Make(kVertex, kFragment, std::nullopt, std::string("key-a"));
		OO_CHECK(again != nil && [again program] != 0);
	}
}


OO_TEST(programsFromFiles)
{
	if (!SetUp())  { OO_CHECK(false); return; }
	@autoreleasepool
	{
		gShaderFiles = { { "test.vertex", kVertex }, { "test.frag", kFragment }, { "other.vert", kVertex } };
		gShaderFileRequests.clear();

		// Each name bare, then with its type's two extensions until one is found.
		OOShaderProgram *p = [OOShaderProgram shaderProgramWithVertexShaderName:"test" fragmentShaderName:"test" prefix:std::nullopt attributeBindings:kBindings];
		OO_CHECK(p != nil && gGetAttribLocation([p program], "tangent") == 15);
		OO_CHECK(gShaderFileRequests == (std::vector<std::string>{ "Shaders/test", "Shaders/test.vertex", "Shaders/test", "Shaders/test.fragment", "Shaders/test.frag" }));

		// Cached by the names and the prefix: the files are not read again.
		gShaderFileRequests.clear();
		OO_CHECK([OOShaderProgram shaderProgramWithVertexShaderName:"test" fragmentShaderName:"test" prefix:std::string("") attributeBindings:kBindings] == p);
		OO_CHECK(gShaderFileRequests.empty());
		OOShaderProgram *prefixed = [OOShaderProgram shaderProgramWithVertexShaderName:"test" fragmentShaderName:"test" prefix:std::string("#define UNUSED 1\n") attributeBindings:kBindings];
		OO_CHECK(prefixed != nil && prefixed != p && gShaderFileRequests.size() == 5);

		// A name with one of the extensions is not extended; a file that is not there fails.
		gShaderFileRequests.clear();
		OO_CHECK([OOShaderProgram shaderProgramWithVertexShaderName:"other.vert" fragmentShaderName:"missing.frag" prefix:std::nullopt attributeBindings:kBindings] == nil);
		OO_CHECK(gShaderFileRequests == (std::vector<std::string>{ "Shaders/other.vert", "Shaders/missing.frag" }));
		gShaderFiles.clear();
	}
}


OO_TEST(applyAndApplyNone)
{
	if (!SetUp())  { OO_CHECK(false); return; }
	OOShaderProgram *p = nil;
	@autoreleasepool
	{
		p = [Make(kVertex, kFragment) retain];
		OOShaderProgram *q = Make(kVertex, kFragment);
		const unsigned retained = [p retainCount];
		[p apply];
		OO_CHECK(CurrentProgram() == (GLint)[p program]);
		OO_CHECK([p retainCount] == retained + 1);	// kept while in use
		[p apply];	// again: no change
		OO_CHECK([p retainCount] == retained + 1);
		[q apply];
		OO_CHECK(CurrentProgram() == (GLint)[q program] && [p retainCount] == retained);
		[OOShaderProgram applyNone];
		OO_CHECK(CurrentProgram() == 0);
		[OOShaderProgram applyNone];	// nothing in use: nothing
		OO_CHECK(CurrentProgram() == 0);
		OO_CHECK(glGetError() == GL_NO_ERROR);
	}
	[p release];
}


// --- The C++ class and the facade (after the conversion) -----------------------------------------

OO_TEST(cxxAPI)
{
	if (!SetUp())  { OO_CHECK(false); return; }
	@autoreleasepool
	{
		OO_CHECK(cxx::OOShaderProgram::shaderProgramWithVertexShader(std::nullopt, std::nullopt, std::nullopt, std::nullopt, std::nullopt, kBindings, std::nullopt) == nullptr);
		const oo::Ref<cxx::OOShaderProgram> p = cxx::OOShaderProgram::shaderProgramWithVertexShader(kVertex, kFragment, std::string("v"), std::string("f"), std::nullopt, kBindings, std::string("cxx-key"));
		OO_CHECK(p != nullptr && p->program() != 0 && gGetAttribLocation(p->program(), "tangent") == 15);

		// One cache for both APIs.
		OO_CHECK(cxx::OOShaderProgram::shaderProgramWithVertexShader(std::nullopt, std::nullopt, std::nullopt, std::nullopt, std::nullopt, kBindings, std::string("cxx-key")).get() == p.get());
		OO_CHECK(oo::ToCxx(Make(kVertex, kFragment, std::nullopt, std::string("cxx-key"))) == p.get());

		gShaderFiles = { { "c.vert", kVertex }, { "c.frag", kFragment } };
		const oo::Ref<cxx::OOShaderProgram> fromFiles = cxx::OOShaderProgram::shaderProgramWithVertexShaderName("c.vert", "c.frag", std::nullopt, kBindings);
		OO_CHECK(fromFiles != nullptr && fromFiles.get() == cxx::OOShaderProgram::shaderProgramWithVertexShaderName("c.vert", "c.frag", std::nullopt, kBindings).get());
		OO_CHECK(cxx::OOShaderProgram::shaderProgramWithVertexShaderName("none.vert", "c.frag", std::nullopt, kBindings) == nullptr);
		gShaderFiles.clear();

		p->apply();
		OO_CHECK(CurrentProgram() == (GLint)p->program());
		cxx::OOShaderProgram::applyNone();
		OO_CHECK(CurrentProgram() == 0);
	}
}


OO_TEST(facade)
{
	if (!SetUp())  { OO_CHECK(false); return; }
	@autoreleasepool
	{
		OOShaderProgram *made = Make(kVertex, kFragment);
		cxx::OOShaderProgram *part = oo::ToCxx(made);
		OO_CHECK(part != nullptr && oo::ToObjC(part) == made && [made program] == part->program());

		const oo::Ref<cxx::OOShaderProgram> p = cxx::OOShaderProgram::shaderProgramWithVertexShader(kVertex, kFragment, std::nullopt, std::nullopt, std::nullopt, kBindings, std::nullopt);
		OO_CHECK(oo::ToObjC(p) == oo::ToObjC(p.get()) && oo::ToCxx(oo::ToObjC(p)) == p.get());

		OOShaderProgram *none = nil;
		OO_CHECK(oo::ToCxx(none) == nullptr && oo::ToObjC(static_cast<cxx::OOShaderProgram *>(nullptr)) == nil);
	}
}

OO_TEST_MAIN()
