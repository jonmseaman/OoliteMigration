/*	test_ResourceManager.mm
	Unit tests for ResourceManager (src/Core/ResourceManager.h): bead oo-jfno, slice 1 of the Phase 3
	slice plan docs/phases/3-slices/ResourceManager.md (the class shell, the file-scope state, the
	search paths, the add-on selection and the path utilities), in the house style of the OOColor
	exemplar (proposed ADR-0056, amendments oo-pni4 and oo-3bgz).

	ResourceManager is class methods over file-scope state. These tests pin, through the Objective-C
	API its callers use, what the slice's units answered before the conversion: the state before any
	scan (no add-on selection, no errors, no OXP messages, no manifests), external paths, which make
	the search paths without a scan, the root paths (the built-in data, the managed add-ons, the
	user's add-on folders, as oo::ResourcePaths computes them), masking the user's name in paths, and
	resetting. They never scan for add-ons: that would read the machine's installed expansions
	(CLAUDE.md rule 6), so the search paths are always given as external paths first. The
	expectations were written against the unconverted class and run on it first. After the
	conversion the class is cxx::ResourceManager (static members) behind an Objective-C facade; the
	last test checks that the C++ API answers the same.

	ResourceManager.mm reaches the universe, the HUD, the OXZ manager and the scripts, so the test
	links every game object but main's (tests/unit/core/meson.build entry ['*'], ADR-0056 amendment
	oo-44gg) and defines gDebugFlags. UNIVERSE is nil.
	Run: bash tools/check-core-tests.sh test_ResourceManager
*/

#import "ResourceManager.h"

#include "oofnd/FileSystem.hpp"
#include "oofnd/ResourcePaths.hpp"
#include "oofnd/String.hpp"
#include "oo_test.hpp"

#include <cstdlib>
#include <string>
#include <vector>


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif


namespace {

// The user name the masking functions read, as they read it (the last component of the profile path).
std::string UserName()
{
	const char *profile = std::getenv("USERPROFILE");
	return oo::str::lastPathComponent(oo::str::format("%s", profile));
}

}	// namespace


OO_TEST(stateBeforeAnyScan)
{
	@autoreleasepool
	{
		OO_CHECK([ResourceManager cxx_useAddOns] == std::nullopt);
		OO_CHECK([ResourceManager cxx_errors] == std::nullopt);
		OO_CHECK([ResourceManager cxx_OXPsWithMessagesFound].empty());
		OO_CHECK([ResourceManager cxx_manifestForIdentifier:"org.test.none"].isNull());
		[ResourceManager clearCaches];
	}
}


OO_TEST(rootPathsAreTheResourcePaths)
{
	@autoreleasepool
	{
		const oo::ResourcePaths paths = oo::ResourcePaths::current();
		const std::string builtIn = oo::fs::utf8String(paths.builtInResourcesDirectory());
		OO_CHECK([ResourceManager cxx_builtInPath] == std::optional<std::string>(builtIn));

		std::vector<std::string> userRoots;
		for (const oo::fs::Path &path : paths.userRootDirectories())  userRoots.push_back(oo::fs::utf8String(path));
		OO_CHECK([ResourceManager cxx_userRootPaths] == userRoots);

		const std::vector<std::string> roots = [ResourceManager cxx_rootPaths];
		OO_CHECK_EQ(roots.size(), userRoots.size() + 2);
		OO_CHECK(roots.size() >= 2 && roots[0] == builtIn);
		OO_CHECK(roots.size() >= 2 && roots[1] == oo::fs::utf8String(paths.managedAddOnsDirectory()));
		OO_CHECK(roots.size() >= 2 && std::vector<std::string>(roots.begin() + 2, roots.end()) == userRoots);
		OO_CHECK([ResourceManager cxx_rootPaths] == roots);	// computed once
	}
}


OO_TEST(maskUserName)
{
	@autoreleasepool
	{
		OO_CHECK([ResourceManager cxx_maskUserName:"jon" inPath:"C:/Users/jon/AddOns"] == std::optional<std::string>("C:/Users/*/AddOns"));
		OO_CHECK([ResourceManager cxx_maskUserName:"jon" inPath:"/home/jon/jon.oxp"] == std::optional<std::string>("/home/*/*.oxp"));
		OO_CHECK([ResourceManager cxx_maskUserName:"jon" inPath:"/srv/oolite"] == std::optional<std::string>("/srv/oolite"));
		OO_CHECK([ResourceManager cxx_maskUserName:"jon" inPath:""] == std::optional<std::string>(""));

		// The array form masks the name of the user running the game, in every path.
		const std::string user = UserName();
		if (!user.empty())
		{
			const std::vector<std::string> masked = [ResourceManager cxx_maskUserNameInPathArray:{ "/a/" + user + "/b", "/c/d" }];
			OO_CHECK(masked == (std::vector<std::string>{ "/a/*/b", "/c/d" }));
		}
		OO_CHECK([ResourceManager cxx_maskUserNameInPathArray:{}].empty());
	}
}


OO_TEST(externalPathsAreTheSearchPathsWithoutAScan)
{
	@autoreleasepool
	{
		[ResourceManager cxx_addExternalPath:"ext/one.oxp"];
		[ResourceManager cxx_addExternalPath:"ext/two.oxp"];
		[ResourceManager cxx_addExternalPath:"ext/one.oxp"];	// already there
		const std::vector<std::string> expected{ "ext/one.oxp", "ext/two.oxp" };
		OO_CHECK([ResourceManager cxx_paths] == expected);
		OO_CHECK([ResourceManager cxx_pathsWithAddOns] == expected);
		OO_CHECK([ResourceManager cxx_useAddOns] == std::nullopt);	// no scan, so no selection

		// -reset forgets them (the next -cxx_paths would scan again, which the test does not do).
		[ResourceManager reset];
		OO_CHECK([ResourceManager cxx_useAddOns] == std::nullopt);
		OO_CHECK([ResourceManager cxx_errors] == std::nullopt);
		[ResourceManager cxx_addExternalPath:"ext/three.oxp"];
		OO_CHECK([ResourceManager cxx_paths] == std::vector<std::string>{ "ext/three.oxp" });
		[ResourceManager reset];
	}
}


OO_TEST_MAIN()
