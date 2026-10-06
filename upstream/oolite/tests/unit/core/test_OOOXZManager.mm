/*	test_OOOXZManager.mm
	Unit tests for OOOXZManager (src/Core/OOOXZManager.h): bead oo-bwjb, slice 1 of the Phase 3
	slice plan docs/phases/3-slices/OOOXZManager.md (the class shell: state, paths, filters,
	manifests and the download plumbing), in the house style of the OOColor exemplar (proposed
	ADR-0056).

	The manager is a process-wide singleton (amendment oo-r7m0) that keeps the list of OXZ
	manifests, the managed OXZs on disk, a filter over the list, and one download. The test points
	the user's home (HOMEPATH: the caches and the defaults), the managed, extract and additional
	add-on folders, and the built-in Resources (the current directory) at a scratch folder before
	the singleton exists, so nothing of the user's is read or written. Every manifest is synthetic,
	written by the test; no expansion is read. The one download is a file: URL (oofnd/Http.hpp),
	so no network is used.

	It pins what the manager computed before the conversion: the shared instance and the list it
	loads from the manifest cache, sorted; the paths; the filters and their validation; the human
	size; the managed OXZs read from disk and matched against the list; a manifest download from
	start to finish (the list replaced, the cache rewritten, the temporary file removed, the
	managed list rebuilt), and the requests it then refuses. The expectations were written
	against the Objective-C API and run on the unconverted class first; the public API still runs
	through the facade, which is its forwarding test, and the private units through their C++
	members (proposed ADR-0056 amendment oo-bwjb item 5). The facade's contract follows: one facade
	for the singleton, identity both ways, nil and null, and the forwarded private units.
	Run: bash tools/check-core-tests.sh test_OOOXZManager
*/

#import "OOOXZManager.h"
#import "OOCacheManager.h"
#import "ResourceManager.h"
#import "OOManifestProperties.h"
#import "OOXMLExtensions.h"
#import "OOPListParsing.h"
#import "OOColor.h"

#include "oofnd/Date.hpp"
#include "oofnd/Defaults.hpp"
#include "oofnd/FileSystem.hpp"
#include "oofnd/PListParsing.hpp"
#include "oofnd/ResourcePaths.hpp"
#include "oofnd/String.hpp"
#include "oo_test.hpp"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <process.h>
#include <string>
#include <thread>
#include <vector>


// main.mm's global, which the game's objects reference (the test links all of them but main's).
uint32_t gDebugFlags = 0;


// A text check that prints what it got.
static void CheckText(const std::string &actual, const std::string &expected, const char *text, int line)
{
	if (actual != expected)  std::printf("  got \"%s\", expected \"%s\"\n", actual.c_str(), expected.c_str());
	::oo_test::check(actual == expected, text, __FILE__, line);
}

#define OO_CHECK_TEXT(actual, expected) CheckText((actual), (expected), #actual " == " #expected, __LINE__)


namespace {

namespace stdfs = std::filesystem;

stdfs::path sRoot;


void WriteText(const stdfs::path &path, const std::string &text)
{
	stdfs::create_directories(path.parent_path());
	FILE *file = std::fopen(path.string().c_str(), "wb");
	if (file == nullptr)  return;
	std::fwrite(text.data(), 1, text.size(), file);
	std::fclose(file);
}


std::string Generic(const stdfs::path &path)
{
	return path.generic_string();
}


void SetEnv(const char *name, const std::string &value)
{
	OO_CHECK(::_putenv_s(name, value.c_str()) == 0);
}


oo::PList Manifest(const char *identifier, const char *title, const char *version, const char *category, const char *author, const char *description, std::vector<std::string> tags, long long uploadDate, const char *downloadURL)
{
	oo::PList::Dict entries;
	entries[std::string(kOOManifestIdentifier)] = oo::PList(identifier);
	entries[std::string(kOOManifestTitle)] = oo::PList(title);
	entries[std::string(kOOManifestVersion)] = oo::PList(version);
	entries[std::string(kOOManifestCategory)] = oo::PList(category);
	if (author != nullptr)  entries[std::string(kOOManifestAuthor)] = oo::PList(author);
	if (description != nullptr)  entries[std::string(kOOManifestDescription)] = oo::PList(description);
	if (!tags.empty())
	{
		oo::PList::Array array;
		for (const std::string &tag : tags)  array.push_back(oo::PList(tag));
		entries[std::string(kOOManifestTags)] = oo::PList(std::move(array));
	}
	if (uploadDate >= 0)  entries[std::string(kOOManifestUploadDate)] = oo::PList(uploadDate);
	if (downloadURL != nullptr)  entries[std::string(kOOManifestDownloadURL)] = oo::PList(downloadURL);
	return oo::PList(std::move(entries));
}


stdfs::path CacheDirectory()
{
	return sRoot / "GNUstep" / "Library" / "Caches" / "org.aegidian.oolite";
}


// The scratch home, add-on folders and game folder, and the manifest cache the manager loads,
// made once, before the singleton exists.
void SetUp()
{
	if (!sRoot.empty())  return;
	sRoot = stdfs::temp_directory_path() / ("oo-test-oxzmanager-" + std::to_string(static_cast<unsigned long>(::_getpid())));
	stdfs::remove_all(sRoot);
	stdfs::create_directories(sRoot);
	SetEnv("HOMEPATH", sRoot.string());
	SetEnv("OO_MANAGEDADDONSDIR", Generic(sRoot / "Managed"));
	SetEnv("OO_ADDONSEXTRACTDIR", Generic(sRoot / "Extract"));
	SetEnv("OO_ADDITIONALADDONSDIRS", Generic(sRoot / "More1") + ",," + Generic(sRoot / "More2"));
	stdfs::current_path(sRoot);
	WriteText(sRoot / "Resources" / "Info-gnustep.plist", "{ CFBundleVersion = \"1.91\"; CFBundleName = \"oolite\"; }");

	const long long now = static_cast<long long>(oo::date::timeIntervalSince1970());
	oo::PList::Array cached;
	cached.push_back(Manifest("oolite.oxp.test.zeta", "Zeta", "1.0", "Ships", "Ann Author", "A fast ship\nwith a second line", { "fast", "combat" }, now - 86400, "file:///nowhere/zeta.oxz"));
	cached.push_back(Manifest("oolite.oxp.test.alpha", "Alpha", "1.5", "Ships", "Bob Builder", "Cobra variants", { "ships" }, now - 10 * 86400, "file:///nowhere/alpha-1.5.oxz"));
	cached.push_back(Manifest("oolite.oxp.test.alpha", "Alpha", "2.0", "Ships", "Bob Builder", "Cobra variants", { "ships" }, now - 10 * 86400, "file:///nowhere/alpha-2.0.oxz"));
	cached.push_back(Manifest("oolite.oxp.test.mission", "Mission", "0.1", "Missions", "Ann Author", "A mission", { "story" }, 0, nullptr));
	stdfs::create_directories(CacheDirectory());
	OO_CHECK(OOWriteXMLPListToFile(oo::PList(std::move(cached)), Generic(CacheDirectory() / "Oolite-manifests.plist"), nullptr));
}


std::string Str(const oo::PList &manifest, std::string_view key)
{
	const oo::PList *value = manifest.find(key);
	if (value == nullptr)  return "-";
	const std::string *string = value->getIf<std::string>();
	return (string != nullptr) ? *string : "?";
}


// "title version" for each manifest of an Array, space-joined ("" for none, "null" for null).
std::string Titles(const oo::PList &list)
{
	if (list.isNull())  return "null";
	std::string result;
	if (const oo::PList::Array *array = list.getIf<oo::PList::Array>())
	{
		for (const oo::PList &manifest : *array)
		{
			if (!result.empty())  result += ", ";
			result += Str(manifest, kOOManifestTitle) + " " + Str(manifest, kOOManifestVersion);
		}
	}
	return result;
}


// The manager's private API (the units of slice 1 the facade does not declare): its C++ members.
cxx::OOOXZManager *Manager()								{ return cxx::OOOXZManager::sharedManager(); }
std::optional<std::string> ManifestPath()					{ return Manager()->manifestPath(); }
std::optional<std::string> DownloadPath()					{ return Manager()->downloadPath(); }
std::optional<std::string> ExtractionBase(const std::string &identifier, const std::string &version)	{ return Manager()->extractionBasePathForIdentifier(identifier, version); }
std::optional<std::string> DataURL()						{ return Manager()->dataURL(); }
std::optional<std::string> HumanSize(NSUInteger bytes)		{ return Manager()->humanSize(bytes); }
bool EnsureInstallPath()									{ return Manager()->ensureInstallPath(); }
bool ValidateFilter(const std::string &input)				{ return Manager()->validateFilter(input); }

std::string Filtered(const std::string &filter)
{
	Manager()->setFilter(filter);
	return Titles(Manager()->applyCurrentFilter(Manager()->manifests()));
}

}	// namespace


OO_TEST(sharedManagerLoadsTheCachedListSorted)
{
	SetUp();
	@autoreleasepool
	{
		OOOXZManager *manager = [OOOXZManager sharedManager];
		OO_CHECK(manager != nil);
		OO_CHECK([OOOXZManager sharedManager] == manager);
		// category, then title, then version descending
		OO_CHECK_TEXT(Titles([manager manifests]), "Mission 0.1, Alpha 2.0, Alpha 1.5, Zeta 1.0");
		OO_CHECK(![manager isRestarting]);
		// Nothing to cancel, and no download to deliver.
		OO_CHECK(![manager cancelUpdate]);
		[manager processDownloadEvents];
		OO_CHECK_TEXT(Titles([manager manifests]), "Mission 0.1, Alpha 2.0, Alpha 1.5, Zeta 1.0");
	}
}


OO_TEST(paths)
{
	SetUp();
	@autoreleasepool
	{
		OOOXZManager *manager = [OOOXZManager sharedManager];
		OO_CHECK_EQ([manager installPath].value_or("(none)"), Generic(sRoot / "Managed"));
		OO_CHECK_EQ([manager extractAddOnsPath].value_or("(none)"), Generic(sRoot / "Extract"));
		const std::vector<std::string> additional = [manager additionalAddOnsPaths];
		OO_CHECK_EQ(additional.size(), 3u);
		if (additional.size() == 3)
		{
			OO_CHECK_EQ(additional[0], Generic(sRoot / "More1"));
			OO_CHECK_EQ(additional[1], "");
			OO_CHECK_EQ(additional[2], Generic(sRoot / "More2"));
		}

		const std::string cacheDirectory = cxx::OOCacheManager::sharedCache()->cacheDirectoryPathCreatingIfNecessary(true).value_or("(none)");
		OO_CHECK_EQ(ManifestPath().value_or("(none)"), oo::str::appendingPathComponent(cacheDirectory, "Oolite-manifests.plist"));
		OO_CHECK_EQ(DownloadPath().value_or("(none)"), oo::str::appendingPathComponent(cacheDirectory, "Oolite-download.oxz"));

		// The extraction folder: the last user root, the blacklisted characters removed.
		const std::vector<std::string> roots = [ResourceManager cxx_userRootPaths];
		OO_CHECK(!roots.empty());
		if (!roots.empty())
		{
			OO_CHECK_EQ(ExtractionBase("oolite.oxp.test:alpha", "1.0 beta/2#").value_or("(none)"), oo::str::appendingPathComponent(roots.back(), "oolite.oxp.testalpha-1.0beta2.off"));
		}

		// The install folder is made when missing, and refused when it is a file.
		OO_CHECK(!stdfs::exists(sRoot / "Managed"));
		OO_CHECK(EnsureInstallPath());
		OO_CHECK(stdfs::is_directory(sRoot / "Managed"));
		OO_CHECK(EnsureInstallPath());
		WriteText(sRoot / "AFile", "x");
		SetEnv("OO_MANAGEDADDONSDIR", Generic(sRoot / "AFile"));
		OO_CHECK(!EnsureInstallPath());
		SetEnv("OO_MANAGEDADDONSDIR", Generic(sRoot / "Managed"));

		OO_CHECK_EQ(DataURL().value_or("(none)"), "https://addons.oolite.space/api/1.0/overview");
	}
}


OO_TEST(humanSizeAndFilterValidation)
{
	SetUp();
	@autoreleasepool
	{
		// The missing-field description; with no Universe the description lookup answers its key.
		OO_CHECK_EQ(HumanSize(0).value_or("(none)"), "oolite-oxzmanager-missing-field");
		OO_CHECK_EQ(HumanSize(1).value_or("(none)"), "<1 kB");
		OO_CHECK_EQ(HumanSize(1023).value_or("(none)"), "<1 kB");
		OO_CHECK_EQ(HumanSize(1024).value_or("(none)"), "1 kB");
		OO_CHECK_EQ(HumanSize(1048575).value_or("(none)"), "1023 kB");
		OO_CHECK_EQ(HumanSize(1048576).value_or("(none)"), "1.00 MB");
		OO_CHECK_EQ(HumanSize(1572864).value_or("(none)"), "1.50 MB");

		const char *valid[] = { "", "*", "u", "i", "U", "k:x", "A:x", "d:5", "t:a", "c:b", "k: " };
		for (const char *filter : valid)  { if (!ValidateFilter(filter))  std::printf("  valid filter refused: \"%s\"\n", filter);  OO_CHECK(ValidateFilter(filter)); }
		const char *invalid[] = { "k:", "a:", "d:0", "d:x", "d:-1", "t:", "c:", "x", "**", "ux" };
		for (const char *filter : invalid)  { if (ValidateFilter(filter))  std::printf("  invalid filter accepted: \"%s\"\n", filter);  OO_CHECK(!ValidateFilter(filter)); }
	}
}


OO_TEST(filters)
{
	SetUp();
	@autoreleasepool
	{
		OO_CHECK_TEXT(Filtered("*"), "Mission 0.1, Alpha 2.0, Alpha 1.5, Zeta 1.0");
		OO_CHECK_TEXT(Filtered("K:cobra"), "Alpha 2.0, Alpha 1.5");
		OO_CHECK_TEXT(Filtered("k:  FAST"), "Zeta 1.0");
		OO_CHECK_TEXT(Filtered("k:"), "Mission 0.1, Alpha 2.0, Alpha 1.5, Zeta 1.0");
		OO_CHECK_TEXT(Filtered("a:ann"), "Mission 0.1, Zeta 1.0");
		OO_CHECK_TEXT(Filtered("c:miss"), "Mission 0.1");
		OO_CHECK_TEXT(Filtered("t:comb"), "Zeta 1.0");
		OO_CHECK_TEXT(Filtered("t:nothing"), "");
		OO_CHECK_TEXT(Filtered("d:3"), "Zeta 1.0");
		OO_CHECK_TEXT(Filtered("d:30"), "Alpha 2.0, Alpha 1.5, Zeta 1.0");
		OO_CHECK_TEXT(Filtered("d:0"), "");
		OO_CHECK_TEXT(Filtered("zzz"), "Mission 0.1, Alpha 2.0, Alpha 1.5, Zeta 1.0");
		// A null list filters to an empty one.
		OO_CHECK_TEXT(Titles(Manager()->applyCurrentFilter(oo::PList())), "");
		Manager()->setFilter("*");
	}
}


OO_TEST(managedOXZs)
{
	SetUp();
	@autoreleasepool
	{
		// Two managed OXZs (synthetic manifests), and a stray file with none.
		WriteText(sRoot / "Managed" / "alpha.oxp" / "manifest.plist", "{ identifier = \"oolite.oxp.test.alpha\"; title = Alpha; version = \"1.0\"; category = Ships; }");
		WriteText(sRoot / "Managed" / "local.oxp" / "manifest.plist", "{ identifier = \"oolite.oxp.test.local\"; title = Local; version = \"3\"; category = Ambience; }");
		WriteText(sRoot / "Managed" / "stray.txt", "not a manifest");

		const oo::PList managed = [[OOOXZManager sharedManager] managedOXZs];
		OO_CHECK_TEXT(Titles(managed), "Local 3, Alpha 1.0");
		const oo::PList::Array *array = managed.getIf<oo::PList::Array>();
		OO_CHECK(array != nullptr && array->size() == 2);
		if (array != nullptr && array->size() == 2)
		{
			const oo::PList &local = (*array)[0];
			const oo::PList &alpha = (*array)[1];
			OO_CHECK_EQ(Str(local, kOOManifestFilePath), oo::str::appendingPathComponent(Generic(sRoot / "Managed"), "local.oxp"));
			OO_CHECK_EQ(Str(local, kOOManifestAvailableVersion), "-");
			OO_CHECK_EQ(Str(local, kOOManifestDownloadURL), "-");
			OO_CHECK_EQ(Str(alpha, kOOManifestFilePath), oo::str::appendingPathComponent(Generic(sRoot / "Managed"), "alpha.oxp"));
			OO_CHECK_EQ(Str(alpha, kOOManifestAvailableVersion), "2.0");
			OO_CHECK_EQ(Str(alpha, kOOManifestDownloadURL), "file:///nowhere/alpha-2.0.oxz");
		}

		// Kept until the list changes.
		WriteText(sRoot / "Managed" / "late.oxp" / "manifest.plist", "{ identifier = \"oolite.oxp.test.late\"; title = Late; version = \"1\"; category = Ambience; }");
		OO_CHECK_TEXT(Titles([[OOOXZManager sharedManager] managedOXZs]), "Local 3, Alpha 1.0");

		// The installable states (slice 2) decide these, from the managed OXZs.
		OO_CHECK_TEXT(Filtered("u"), "Alpha 2.0, Alpha 1.5");
		OO_CHECK_TEXT(Filtered("i"), "Mission 0.1, Alpha 2.0, Alpha 1.5, Zeta 1.0");
		Manager()->setFilter("*");
	}
}


OO_TEST(manifestDownload)
{
	SetUp();
	@autoreleasepool
	{
		OOOXZManager *manager = [OOOXZManager sharedManager];

		// The new index, served from a file: URL named by the oxz-index-url default (in memory
		// only: nothing synchronizes the defaults).
		oo::PList::Array index;
		index.push_back(Manifest("oolite.oxp.test.beta", "Beta", "1.0", "Ships", "Cy", "Beta ship", {}, -1, nullptr));
		index.push_back(Manifest("oolite.oxp.test.alpha", "Alpha", "3.0", "Ships", "Bob Builder", "Cobra variants", {}, -1, "file:///nowhere/alpha-3.0.oxz"));
		OO_CHECK(OOWriteXMLPListToFile(oo::PList(std::move(index)), Generic(sRoot / "index.plist"), nullptr));
		const std::string url = "file:///" + Generic(sRoot / "index.plist");
		oo::Defaults::standard().setObject("oxz-index-url", oo::PList(url));
		OO_CHECK_EQ(DataURL().value_or("(none)"), url);

		const std::string cacheDirectory = cxx::OOCacheManager::sharedCache()->cacheDirectoryPathCreatingIfNecessary(true).value_or("(none)");
		OO_CHECK([manager updateManifests]);
		OO_CHECK_EQ(DownloadPath().value_or("(none)"), oo::str::appendingPathComponent(cacheDirectory, "Oolite-download.plist"));
		// A second request while one is under way is refused.
		OO_CHECK(![manager updateManifests]);

		const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(20);
		while (Titles([manager manifests]) != "Alpha 3.0, Beta 1.0" && std::chrono::steady_clock::now() < deadline)
		{
			[manager processDownloadEvents];
			std::this_thread::sleep_for(std::chrono::milliseconds(10));
		}
		OO_CHECK_TEXT(Titles([manager manifests]), "Alpha 3.0, Beta 1.0");

		// The cache holds the new list, the temporary file is gone, and the managed list is rebuilt.
		const oo::PList cached = cxx_OOPropertyListFromFile(oo::str::appendingPathComponent(cacheDirectory, "Oolite-manifests.plist"));
		OO_CHECK_TEXT(Titles(cached), "Alpha 3.0, Beta 1.0");
		OO_CHECK(!stdfs::exists(stdfs::path(oo::str::appendingPathComponent(cacheDirectory, "Oolite-download.plist"))));
		const oo::PList managed = [manager managedOXZs];
		OO_CHECK_TEXT(Titles(managed), "Late 1, Local 3, Alpha 1.0");
		const oo::PList::Array *array = managed.getIf<oo::PList::Array>();
		if (array != nullptr && array->size() == 3)
		{
			OO_CHECK_EQ(Str((*array)[2], kOOManifestAvailableVersion), "3.0");
			OO_CHECK_EQ(Str((*array)[2], kOOManifestDownloadURL), "file:///nowhere/alpha-3.0.oxz");
		}

		// The download is complete: no new one starts, and there is nothing to cancel.
		OO_CHECK(![manager updateManifests]);
		OO_CHECK(![manager cancelUpdate]);
		OO_CHECK_EQ(DownloadPath().value_or("(none)"), oo::str::appendingPathComponent(cacheDirectory, "Oolite-download.oxz"));
	}
}


OO_TEST(facadeContract)
{
	SetUp();
	@autoreleasepool
	{
		OOOXZManager *facade = [OOOXZManager sharedManager];
		cxx::OOOXZManager *manager = cxx::OOOXZManager::sharedManager();
		OO_CHECK(manager != nullptr);
		OO_CHECK(oo::ToCxx(facade) == manager);
		OO_CHECK(oo::ToObjC(manager) == facade);
		OO_CHECK([OOOXZManager sharedManager] == facade);
		OO_CHECK(oo::ToCxx(static_cast<OOOXZManager *>(nil)) == nullptr);
		OO_CHECK(oo::ToObjC(static_cast<cxx::OOOXZManager *>(nullptr)) == nil);

		// The same answers from either side.
		OO_CHECK(Titles([facade manifests]) == Titles(manager->manifests()));
		OO_CHECK(Titles([facade managedOXZs]) == Titles(manager->managedOXZs()));
		OO_CHECK([facade installPath] == manager->installPath());
		OO_CHECK([facade extractAddOnsPath] == manager->extractAddOnsPath());
		OO_CHECK([facade additionalAddOnsPaths] == manager->additionalAddOnsPaths());

		// The slice 1 units that slices 2 to 4 send, forwarded.
		OO_CHECK([facade downloadPath] == manager->downloadPath());
		OO_CHECK([facade humanSize:2048] == std::optional<std::string>("2 kB"));
		OO_CHECK([facade validateFilter:"k:x"]);
		OO_CHECK(![facade validateFilter:"k:"]);
		OO_CHECK([facade ensureInstallPath]);
		OO_CHECK([facade extractionBasePathForIdentifier:"a" andVersion:"1"] == manager->extractionBasePathForIdentifier("a", "1"));
		[facade setFilter:"C:MISS"];
		OO_CHECK_EQ(manager->_currentFilter, "c:miss");
		OO_CHECK_TEXT(Titles([facade applyCurrentFilter:[facade manifests]]), "");
		[facade setFilteredList:[facade manifests]];
		OO_CHECK(manager->_filteredList == manager->_oxzList);
		[facade setProgressStatus:"halfway"];
		OO_CHECK_EQ(manager->_progressStatus, "halfway");
		[facade setFilter:"*"];
	}
}


// Slice 2 (bead oo-0hyr): installing, updating, removing and extracting OXZs.
@interface OOOXZManager (TestSliceTwo)
- (oo::PList) installedManifestForIdentifier:(const std::string &)identifier;
- (std::optional<std::string>) installStatusForManifest:(const oo::PList &)manifest;
- (OOColor *) colorForManifest:(const oo::PList &)manifest;
- (BOOL) installOXZ:(NSUInteger)item;
- (BOOL) updateAllOXZ;
- (BOOL) removeOXZ:(NSUInteger)item;
- (std::string) extractOXZ:(NSUInteger)item;
@end


namespace {

// A stored (uncompressed) zip of the named files, written by hand: a synthetic OXZ.
uint32_t Crc32(const std::string &data)
{
	uint32_t crc = 0xFFFFFFFFu;
	for (unsigned char byte : data)
	{
		crc ^= byte;
		for (int k = 0; k < 8; k++)  crc = (crc >> 1) ^ (0xEDB88320u & (0u - (crc & 1u)));
	}
	return ~crc;
}


void Put16(std::string &out, unsigned value)  { out += static_cast<char>(value & 0xFF); out += static_cast<char>((value >> 8) & 0xFF); }
void Put32(std::string &out, uint32_t value)  { Put16(out, value & 0xFFFF); Put16(out, value >> 16); }


void WriteZip(const stdfs::path &path, const std::vector<std::pair<std::string, std::string>> &entries)
{
	std::string zip, directory;
	for (const auto &[name, data] : entries)
	{
		const uint32_t offset = static_cast<uint32_t>(zip.size()), crc = Crc32(data), size = static_cast<uint32_t>(data.size());
		Put32(zip, 0x04034b50); Put16(zip, 20); Put16(zip, 0); Put16(zip, 0); Put16(zip, 0); Put16(zip, 0x21);
		Put32(zip, crc); Put32(zip, size); Put32(zip, size); Put16(zip, static_cast<unsigned>(name.size())); Put16(zip, 0);
		zip += name; zip += data;
		Put32(directory, 0x02014b50); Put16(directory, 20); Put16(directory, 20); Put16(directory, 0); Put16(directory, 0);
		Put16(directory, 0); Put16(directory, 0x21); Put32(directory, crc); Put32(directory, size); Put32(directory, size);
		Put16(directory, static_cast<unsigned>(name.size())); Put16(directory, 0); Put16(directory, 0); Put16(directory, 0);
		Put16(directory, 0); Put32(directory, 0); Put32(directory, offset);
		directory += name;
	}
	const uint32_t directoryOffset = static_cast<uint32_t>(zip.size());
	zip += directory;
	Put32(zip, 0x06054b50); Put16(zip, 0); Put16(zip, 0); Put16(zip, static_cast<unsigned>(entries.size())); Put16(zip, static_cast<unsigned>(entries.size()));
	Put32(zip, static_cast<uint32_t>(directory.size())); Put32(zip, directoryOffset); Put16(zip, 0);
	WriteText(path, zip);
}


const char *kGammaManifest = "{ identifier = \"oolite.oxp.test.gamma\"; title = Gamma; version = \"1.0\"; category = Ships; }";


std::string ColorName(OOColor *color)
{
	cxx::OOColor *c = oo::ToCxx(color);
	if (c == nullptr)  return "nil";
	const std::pair<const char *, oo::Ref<cxx::OOColor>> named[] = {
		{ "yellow", cxx::OOColor::yellowColor() }, { "cyan", cxx::OOColor::cyanColor() }, { "orange", cxx::OOColor::orangeColor() },
		{ "brown", cxx::OOColor::brownColor() }, { "white", cxx::OOColor::whiteColor() }, { "red", cxx::OOColor::redColor() },
		{ "gray", cxx::OOColor::grayColor() }, { "blue", cxx::OOColor::blueColor() } };
	for (const auto &[name, n] : named)
	{
		if (n->redComponent() == c->redComponent() && n->greenComponent() == c->greenComponent() && n->blueComponent() == c->blueComponent())  return name;
	}
	return "other";
}


// The slice 2 units.
oo::PList InstalledManifest(const std::string &identifier)		{ return [[OOOXZManager sharedManager] installedManifestForIdentifier:identifier]; }
std::string InstallStatus(const oo::PList &manifest)			{ return [[OOOXZManager sharedManager] installStatusForManifest:manifest].value_or("(none)"); }
std::string Color(const oo::PList &manifest)					{ return ColorName([[OOOXZManager sharedManager] colorForManifest:manifest]); }
bool InstallOXZ(NSUInteger item)								{ return [[OOOXZManager sharedManager] installOXZ:item]; }
bool UpdateAllOXZ()												{ return [[OOOXZManager sharedManager] updateAllOXZ]; }
bool RemoveOXZ(NSUInteger item)									{ return [[OOOXZManager sharedManager] removeOXZ:item]; }
std::string ExtractOXZ(NSUInteger item)							{ return [[OOOXZManager sharedManager] extractOXZ:item]; }
bool IsRestarting()												{ return [[OOOXZManager sharedManager] isRestarting]; }


// Deliver the download's events until it is no longer under way (at most 20 s).
void FinishDownload()
{
	const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(20);
	while ((Manager()->_downloadStatus == OXZ_DOWNLOAD_STARTED || Manager()->_downloadStatus == OXZ_DOWNLOAD_RECEIVING) && std::chrono::steady_clock::now() < deadline)
	{
		Manager()->processDownloadEvents();
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
	}
}


std::string Element(const oo::PList &list, NSUInteger index)
{
	const oo::PList *element = list.at(index);
	return (element != nullptr) ? Str(*element, kOOManifestTitle) : "(none)";
}

}	// namespace


OO_TEST(installableStates)
{
	SetUp();
	@autoreleasepool
	{
		// The list holds Alpha 3.0 and Beta 1.0; Alpha 1.0 is managed.
		const oo::PList list = Manager()->manifests();
		OO_CHECK_TEXT(Titles(list), "Alpha 3.0, Beta 1.0");
		const oo::PList alpha = *list.at(0), beta = *list.at(1);
		OO_CHECK_TEXT(InstallStatus(alpha), "oolite-oxzmanager-installable-update");
		OO_CHECK_TEXT(InstallStatus(beta), "oolite-oxzmanager-installable-okay");
		OO_CHECK_TEXT(Color(alpha), "cyan");
		OO_CHECK_TEXT(Color(beta), "yellow");
		OO_CHECK_TEXT(Str(InstalledManifest("oolite.oxp.test.alpha"), kOOManifestVersion), "1.0");
		OO_CHECK(InstalledManifest("oolite.oxp.test.beta").isNull());
		OO_CHECK(!IsRestarting());
	}
}


OO_TEST(installExtractAndRemove)
{
	SetUp();
	@autoreleasepool
	{
		// A synthetic OXZ, offered in the list with a file: URL.
		WriteZip(sRoot / "gamma.oxz", { { "manifest.plist", kGammaManifest }, { "Config/notes.txt", "gamma notes" } });
		oo::PList::Array entries = *Manager()->manifests().getIf<oo::PList::Array>();
		auto parsed = oo::parsePropertyList(kGammaManifest);
		oo::PList gamma = parsed ? *parsed : oo::PList();
		gamma.getIf<oo::PList::Dict>()->insert_or_assign(std::string(kOOManifestDownloadURL), oo::PList("file:///" + Generic(sRoot / "gamma.oxz")));
		entries.push_back(gamma);
		Manager()->setOXZList(oo::PList(std::move(entries)));
		Manager()->setFilteredList(Manager()->manifests());
		OO_CHECK_TEXT(Titles(Manager()->manifests()), "Alpha 3.0, Beta 1.0, Gamma 1.0");
		Manager()->_downloadStatus = OXZ_DOWNLOAD_NONE;

		OO_CHECK(!InstallOXZ(3));
		OO_CHECK(InstallOXZ(2));
		OO_CHECK(Manager()->_interfaceState == OXZ_STATE_INSTALLING);
		OO_CHECK(!InstallOXZ(2));	// one download at a time
		FinishDownload();
		OO_CHECK(Manager()->_downloadStatus == OXZ_DOWNLOAD_COMPLETE);
		OO_CHECK(Manager()->_interfaceState == OXZ_STATE_TASKDONE);
		OO_CHECK(Manager()->_changesMade);
		OO_CHECK(Manager()->_dependencyStack.empty());
		OO_CHECK(stdfs::exists(sRoot / "Managed" / "oolite.oxp.test.gamma.oxz"));
		const oo::PList managed = Manager()->managedOXZs();
		OO_CHECK_TEXT(Titles(managed), "Late 1, Local 3, Alpha 1.0, Gamma 1.0");
		OO_CHECK_TEXT(InstallStatus(*Manager()->manifests().at(2)), "oolite-oxzmanager-installable-already");
		OO_CHECK_TEXT(Color(*Manager()->manifests().at(2)), "white");
		Manager()->_downloadStatus = OXZ_DOWNLOAD_NONE;
		OO_CHECK(!InstallOXZ(2));	// already installed

		// Extracting: Gamma into the extract folder; again (it exists); Alpha (a folder, not a zip); nothing.
		Manager()->setFilteredList(managed);
		OO_CHECK_TEXT(Element(managed, 3), "Gamma");
		OO_CHECK_TEXT(ExtractOXZ(3), "oolite-oxzmanager-extract-log-main-createdoolite-oxzmanager-extract-log-num-u-extractedoolite-oxzmanager-extract-log-extracted-to-@");
		const stdfs::path extracted = sRoot / "Extract" / "oolite.oxp.test.gamma-1.0.off";
		OO_CHECK(stdfs::exists(extracted / "manifest.plist"));
		OO_CHECK(stdfs::exists(extracted / "Config" / "notes.txt"));
		OO_CHECK_TEXT(ExtractOXZ(3), "oolite-oxzmanager-extract-log-main-exists");
		OO_CHECK_TEXT(ExtractOXZ(2), "oolite-oxzmanager-extract-log-bad-original");
		OO_CHECK_TEXT(ExtractOXZ(9), "oolite-oxzmanager-extract-log-no-original");

		// Removing: out of range, then Gamma.
		OO_CHECK(!RemoveOXZ(9));
		OO_CHECK(RemoveOXZ(3));
		OO_CHECK(!stdfs::exists(sRoot / "Managed" / "oolite.oxp.test.gamma.oxz"));
		OO_CHECK(Manager()->_interfaceState == OXZ_STATE_REMOVING);
		OO_CHECK_TEXT(Titles(Manager()->managedOXZs()), "Late 1, Local 3, Alpha 1.0");
	}
}


OO_TEST(restartAndUpdateAll)
{
	SetUp();
	@autoreleasepool
	{
		Manager()->_interfaceState = OXZ_STATE_RESTARTING;
		OO_CHECK(IsRestarting());
		OO_CHECK(Manager()->_interfaceState == OXZ_STATE_MAIN);
		OO_CHECK(!Manager()->_changesMade);
		OO_CHECK(Manager()->_downloadStatus == OXZ_DOWNLOAD_NONE);
		OO_CHECK(!IsRestarting());

		// Alpha 3.0 updates the managed Alpha 1.0; its URL names no file, so the download fails.
		OO_CHECK(UpdateAllOXZ());
		OO_CHECK(Manager()->_downloadAllDependencies);
		OO_CHECK_EQ(Manager()->_dependencyStack.size(), 1u);
		OO_CHECK_EQ(Manager()->_item, 0u);
		OO_CHECK(Manager()->_interfaceState == OXZ_STATE_INSTALLING);
		OO_CHECK_TEXT(Titles(Manager()->_filteredList), "Alpha 3.0, Beta 1.0, Gamma 1.0");
		FinishDownload();
		OO_CHECK(Manager()->_downloadStatus == OXZ_DOWNLOAD_ERROR);
	}
}


OO_TEST_MAIN()
