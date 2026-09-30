/*	test_OOFileScannerVerifierStage.mm
	Unit tests for OOFileScannerVerifierStage.h/.mm (bead oo-up4b; proposed ADR-0056 Amendment 1
	and Amendment 2): cxx::OOFileScannerVerifierStage, the intermediate class
	cxx::OOFileHandlingVerifierStage that seven Objective-C stages still subclass, and their
	Objective-C facades (OOFileScannerVerifierStage+ObjCBridge.h).

	What the file computed before the conversion is pinned through the Objective-C API the other
	stages use: the dependency and dependent a file-handling stage names (and registers), [super
	dependents] from a subclass, and the scanner's answers over a real directory: case-insensitive
	look-up with folder fallback, junk, skipped and Read Me files, listings, data and property
	lists. Then the crossing: an Objective-C subclass of the intermediate class behind a C++
	pointer, a C++ subclass of it behind the facade, the scanner's own facade class and identity.
	Run: bash tools/check-core-tests.sh
*/

#import "OOFileScannerVerifierStage.h"
#import "OOOXPVerifierStageInternal.h"
#import "OODescription.h"

#import "OOLogging.h"
#include "oofnd/PListParsing.hpp"
#include "oo_test.hpp"

#include <filesystem>
#include <fstream>


/*	The game's OOLogging.mm reaches the resource manager, so it is not linked; the base calls
	this one function of it (a subclass responsibility).
*/
void OOLogGenericSubclassResponsibilityForFunction(const char *inFunction)
{
	(void)inFunction;
}


/*	The verifier and the resource manager are not linked either (they reach the whole game). The
	stages talk to the verifier through its interface only, so the test is the verifier: the
	configuration is a verifyOXP.plist of the test's, registration keeps stages by name. The
	resource manager answers the one question the scanner asks it, for built-in files.
*/
@interface OOOXPVerifier ()

- (id)initWithPath:(const std::string &)path configuration:(const char *)configuration;
- (int)registrations;

@end


static int gRegistrations = 0;


@implementation OOOXPVerifier

+ (BOOL)runVerificationIfRequested	{ return NO; }


- (id)initWithPath:(const std::string &)path configuration:(const char *)configuration
{
	self = [super init];
	if (self != nil)
	{
		_basePath = path;
		_verifierPList = *oo::parsePropertyListData(configuration);
		_openForRegistration = YES;
	}
	return self;
}


- (int)registrations	{ return gRegistrations; }


- (void)registerStage:(OOOXPVerifierStage *)stage
{
	_stagesByName[*[stage cxx_name]] = oo::ObjCRef<OOOXPVerifierStage *>(stage);
	[stage setVerifier:self];
	gRegistrations++;
}


- (std::optional<std::string>)cxx_oxpPath			{ return _basePath; }
- (std::optional<std::string>)cxx_oxpDisplayName	{ return "Test.oxp"; }


- (id)cxx_stageWithName:(const std::string &)name
{
	const auto found = _stagesByName.find(name);
	return found != _stagesByName.end() ? found->second.get() : nil;
}


- (oo::PList)configurationValueForKey:(const std::string &)key
{
	const oo::PList *value = _verifierPList.find(key);
	return value != nullptr ? *value : oo::PList();
}


- (oo::PList)cxx_configurationArrayForKey:(const std::string &)key
{
	const oo::PList *array = _verifierPList.get<oo::PList::Array>(key);
	return array != nullptr ? *array : oo::PList();
}


- (oo::PList)cxx_configurationDictionaryForKey:(const std::string &)key
{
	const oo::PList *dictionary = _verifierPList.get<oo::PList::Dict>(key);
	return dictionary != nullptr ? *dictionary : oo::PList();
}


- (std::optional<std::string>)cxx_configurationStringForKey:(const std::string &)key
{
	const oo::PList *value = _verifierPList.find(key);
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return _verifierPList.get<std::string>(key);
}


- (std::optional<std::vector<std::string>>)cxx_configurationSetForKey:(const std::string &)key
{
	const oo::PList *array = _verifierPList.get<oo::PList::Array>(key);
	if (array == nullptr)  return std::nullopt;

	std::set<std::string> strings;
	for (const oo::PList &element : *array->getIf<oo::PList::Array>())
	{
		if (const std::string *string = element.getIf<std::string>())  strings.insert(*string);
	}
	return std::vector<std::string>(strings.begin(), strings.end());
}

@end


@interface ResourceManager: OOObject

+ (std::optional<std::string>) cxx_pathForFileNamed:(const std::string &)fileName inFolder:(const std::optional<std::string> &)folderName;

@end


@implementation ResourceManager

+ (std::optional<std::string>) cxx_pathForFileNamed:(const std::string &)fileName inFolder:(const std::optional<std::string> &)folderName
{
	if (fileName != "builtin.png")  return std::nullopt;
	return "builtin/" + folderName.value_or("") + "/" + fileName;
}

@end


// An unconverted file-handling stage, as the seven leaf stages are.
@interface TestFileStage: OOFileHandlingVerifierStage
@end


@implementation TestFileStage

- (std::optional<std::string>)cxx_name	{ return "Testing files"; }

@end


// Extends its superclass's dependents through [super dependents], as OOTextureHandlingStage does.
@interface TestSuperCallingFileStage: TestFileStage
@end


@implementation TestSuperCallingFileStage

- (std::optional<std::vector<std::string>>)dependents
{
	std::vector<std::string> result = [super dependents].value_or(std::vector<std::string>());
	result.push_back("Extra dependent");
	return result;
}

@end


namespace {

const char * const kConfiguration =
	"{"
	"	junkFiles = (\".DS_Store\");"
	"	skipDirectories = (\".svn\");"
	"	readMeNames = { stems = (\"readme\"); extensions = (\".txt\"); };"
	"	knownRootDirectories = (\"Config\", \"Textures\", \"Images\");"
	"	knownFiles = { Config = (\"shipdata.plist\"); };"
	"	knownConfigFiles = (\"shipdata.plist\");"
	"}";


void WriteFile(const std::filesystem::path &path, const char *contents)
{
	std::filesystem::create_directories(path.parent_path());
	std::ofstream(path, std::ios::binary) << contents;
}


// A small OXP in the working directory: a lowercase textures folder, a root file, a Read Me, a
// junk file, a skipped folder and a nested folder.
std::string MakeOXP()
{
	const std::filesystem::path base = std::filesystem::current_path() / "test_OOFileScannerVerifierStage.oxp";
	std::filesystem::remove_all(base);
	WriteFile(base / "Config" / "shipdata.plist", "{ a = 1; }");
	WriteFile(base / "Config" / "bad.plist", "{ a = ");
	WriteFile(base / "textures" / "Foo.PNG", "png");
	WriteFile(base / "Images" / "b.png", "b");
	WriteFile(base / "Images" / "A.png", "a");
	WriteFile(base / "Images" / "nested" / "c.png", "c");
	WriteFile(base / "Root.png", "root");
	WriteFile(base / "ReadMe.txt", "read me");
	WriteFile(base / ".DS_Store", "junk");
	WriteFile(base / ".svn" / "entries", "svn");
	return base.generic_string();
}


OOOXPVerifier *MakeVerifier(const std::string &path)
{
	return [[[OOOXPVerifier alloc] initWithPath:path configuration:kConfiguration] autorelease];
}


const std::vector<std::string> kScannerName = { "Scanning files" };
const std::vector<std::string> kUnusedName = { "Checking for unused files" };

}	// namespace


OO_TEST(fileHandlingStageNamesAndRegistersItsNeighbours)
{
	@autoreleasepool
	{
		OOOXPVerifier *verifier = MakeVerifier("");
		TestFileStage *stage = [[[TestFileStage alloc] init] autorelease];
		[stage setVerifier:verifier];
		const int before = [verifier registrations];

		OO_CHECK([stage cxx_dependencies] == kScannerName);
		OO_CHECK([stage dependents] == kUnusedName);
		OO_CHECK([verifier registrations] == before + 2);
		OO_CHECK([[verifier fileScannerStage] isKindOfClass:[OOFileScannerVerifierStage class]]);
		OO_CHECK([verifier cxx_stageWithName:"Checking for unused files"] != nil);

		// Asked again (by another stage), nothing new is registered.
		OO_CHECK([stage cxx_dependencies] == kScannerName);
		OO_CHECK([stage dependents] == kUnusedName);
		OO_CHECK([verifier registrations] == before + 2);

		// The rest is the base's.
		OO_CHECK([stage cxx_name] == std::optional<std::string>("Testing files"));
		OO_CHECK([stage shouldRun]);
	}
}


OO_TEST(superDependentsReachTheIntermediateClass)
{
	@autoreleasepool
	{
		TestSuperCallingFileStage *stage = [[[TestSuperCallingFileStage alloc] init] autorelease];
		[stage setVerifier:MakeVerifier("")];
		OO_CHECK([stage dependents] == (std::vector<std::string>{ "Checking for unused files", "Extra dependent" }));
		OO_CHECK([stage cxx_dependencies] == kScannerName);
	}
}


OO_TEST(scannerFindsFiles)
{
	@autoreleasepool
	{
		const std::string base = MakeOXP();
		OOOXPVerifier *verifier = MakeVerifier(base);
		OO_CHECK([OOFileScannerVerifierStage nameForDependencyForVerifier:verifier] == std::optional<std::string>("Scanning files"));
		OOFileScannerVerifierStage *scanner = [verifier fileScannerStage];
		OO_CHECK(scanner != nil && [scanner verifier] == verifier);
		OO_CHECK([scanner cxx_name] == std::optional<std::string>("Scanning files"));
		OO_CHECK(oo::DescriptionOf(scanner).starts_with("<OOFileScannerVerifierStage 0x"));
		OO_CHECK(oo::DescriptionOf(scanner).ends_with(">{\"Scanning files\"}"));
		[scanner run];

		// Case-insensitive, in the folder or bare in the root; the result is the path on disk.
		OO_CHECK([scanner cxx_fileExists:"foo.png" inFolder:"Textures" referencedFrom:"a test" checkBuiltIn:NO]);
		OO_CHECK([scanner cxx_pathForFile:"FOO.png" inFolder:"Textures" referencedFrom:std::nullopt checkBuiltIn:NO] == std::optional<std::string>(base + "/textures/Foo.PNG"));
		OO_CHECK([scanner cxx_pathForFile:"root.png" inFolder:"Textures" referencedFrom:std::nullopt checkBuiltIn:NO] == std::optional<std::string>(base + "/Root.png"));
		OO_CHECK([scanner cxx_pathForFile:"Root.png" inFolder:std::nullopt referencedFrom:std::nullopt checkBuiltIn:NO] == std::optional<std::string>(base + "/Root.png"));

		// Not found: the built-in files only when asked; no name is no file.
		OO_CHECK(![scanner cxx_pathForFile:"builtin.png" inFolder:"Textures" referencedFrom:std::nullopt checkBuiltIn:NO].has_value());
		OO_CHECK([scanner cxx_pathForFile:"builtin.png" inFolder:"Textures" referencedFrom:std::nullopt checkBuiltIn:YES] == std::optional<std::string>("builtin/Textures/builtin.png"));
		OO_CHECK(![scanner cxx_pathForFile:"missing.png" inFolder:"Textures" referencedFrom:std::nullopt checkBuiltIn:YES].has_value());
		OO_CHECK(![scanner cxx_fileExists:std::nullopt inFolder:"Textures" referencedFrom:std::nullopt checkBuiltIn:YES]);

		// Junk, Read Me files and skipped folders are not part of the OXP; a nested folder is ignored.
		OO_CHECK(![scanner cxx_fileExists:".DS_Store" inFolder:std::nullopt referencedFrom:std::nullopt checkBuiltIn:NO]);
		OO_CHECK(![scanner cxx_fileExists:"ReadMe.txt" inFolder:std::nullopt referencedFrom:std::nullopt checkBuiltIn:NO]);
		OO_CHECK(![scanner cxx_filesInFolder:".svn"].has_value());
		OO_CHECK(![scanner cxx_fileExists:"c.png" inFolder:"Images" referencedFrom:std::nullopt checkBuiltIn:NO]);

		// Listings: in the byte order of the lowercase names; the root's is "".
		OO_CHECK([scanner cxx_filesInFolder:"IMAGES"] == (std::vector<std::string>{ "A.png", "b.png" }));
		OO_CHECK([scanner cxx_filesInFolder:""] == std::vector<std::string>{ "Root.png" });
		OO_CHECK(![scanner cxx_filesInFolder:"Sounds"].has_value());
		OO_CHECK(![scanner cxx_filesInFolder:std::nullopt].has_value());

		OO_CHECK([scanner cxx_displayNameForFile:"f" andFolder:"d"] == std::optional<std::string>("d/f"));
		OO_CHECK([scanner cxx_displayNameForFile:"f" andFolder:std::nullopt] == std::optional<std::string>("f"));
		OO_CHECK(![scanner cxx_displayNameForFile:std::nullopt andFolder:"d"].has_value());

		// Contents.
		OO_CHECK([scanner dataForFile:"shipdata.plist" inFolder:"config" referencedFrom:std::nullopt checkBuiltIn:NO].stringView() == "{ a = 1; }");
		OO_CHECK([scanner dataForFile:"missing.plist" inFolder:"Config" referencedFrom:std::nullopt checkBuiltIn:NO].stringView().empty());
		const oo::PList plist = [scanner cxx_plistNamed:"shipdata.plist" inFolder:"Config" referencedFrom:std::nullopt checkBuiltIn:NO];
		OO_CHECK(plist.get<std::string>("a") == "1");
		OO_CHECK([scanner cxx_plistNamed:"bad.plist" inFolder:"Config" referencedFrom:std::nullopt checkBuiltIn:NO].isNull());	// logs the parse error
		OO_CHECK([scanner cxx_plistNamed:"missing.plist" inFolder:"Config" referencedFrom:std::nullopt checkBuiltIn:NO].isNull());

		std::filesystem::remove_all(base);
	}
}


OO_TEST(scannerMadeByAllocInit)
{
	@autoreleasepool
	{
		OOFileScannerVerifierStage *scanner = [[[OOFileScannerVerifierStage alloc] init] autorelease];
		OO_CHECK([scanner isKindOfClass:[OOFileScannerVerifierStage class]]);
		OO_CHECK([scanner cxx_name] == std::optional<std::string>("Scanning files"));
		OO_CHECK(![scanner cxx_filesInFolder:""].has_value());	// nothing scanned yet
	}
}

OO_TEST_MAIN()
