/*	test_OOPListSchemaVerifier.mm
	Unit tests for OOPListSchemaVerifier (src/Core/OXPVerifier/OOPListSchemaVerifier.h): bead
	oo-pni4, slice 1 of the Phase 3 slice plan docs/phases/3-slices/OOPListSchemaVerifier.md (the
	class shell, the public API and the OOPrivate verification core), in the house style of the
	OOColor exemplar (proposed ADR-0056).

	It pins what the verifier answered before the conversion, through the Objective-C API its one
	caller (OOCheckShipDataPListVerifierStage) uses: nil for a null schema, the delegate, verifying
	valid and invalid property lists (the failure the delegate is told about: code, reason, key path
	and expected type), $definitions macros and a bad schema, delegated types (answered, refused,
	throwing, or a delegate that does not handle them), a delegate that stops at the first failure,
	no failure handler at all, and +descriptionForKeyPath:. The expectations were written against
	the unconverted class and run on it first. After the conversion the class is cxx::
	OOPListSchemaVerifier behind an Objective-C facade; the test also checks the facade: the
	delegate is handed the facade it registered with, and the same answers come back.
	Run: bash tools/check-core-tests.sh test_OOPListSchemaVerifier
*/

#import "OOPListSchemaVerifier.h"
#import "OODescription.h"

#include "oofnd/PListParsing.hpp"
#include "oofnd/objc/OOException.h"

#include "oo_test.hpp"

#include <cstdio>
#include <string>
#include <vector>


namespace {

oo::PList Parse(const char *text)
{
	auto result = oo::parsePropertyList(text);
	OO_CHECK(result.has_value());
	return result ? *result : oo::PList();
}


std::string KeyPathText(const oo::PList &keyPath)
{
	return [OOPListSchemaVerifier descriptionForKeyPath:keyPath].value_or("(nullopt)");
}


// One failure as the delegate saw it: "<code> <key path> | <reason> | <expected type>".
std::string FailureText(const OOPListSchemaVerifierError &error, const oo::PList &localSchema)
{
	const oo::PList *keyPath = error.userInfo.find(kPListKeyPathErrorKey);
	return std::to_string(error.code) + " " + KeyPathText(keyPath != nullptr ? *keyPath : oo::PList())
		+ " | " + error.failureReason.value_or("(nullopt)") + " | " + oo::DescriptionOf(localSchema);
}

}	// namespace


// A delegate that records what it is told. Delegated types answer `delegatedAnswer`, or raise.
@interface TestSchemaDelegate: OOObject
{
@public
	std::vector<std::string>	failures;
	std::vector<std::string>	delegated;		// "<name> <type key> <key path> <value>"
	std::vector<id>				verifiers;		// the verifier each call was handed
	BOOL						delegatedAnswer;
	BOOL						delegatedRaises;
	BOOL						delegatedError;
	BOOL						continueAfterFailure;
}
@end


@implementation TestSchemaDelegate

- (BOOL)verifier:(OOPListSchemaVerifier *)verifier
withPropertyList:(const oo::PList &)rootPList
		   named:(const std::string &)name
	testProperty:(const oo::PList &)subPList
		  atPath:(const oo::PList &)keyPath
	 againstType:(const oo::PList &)typeKey
		   error:(std::optional<OOPListSchemaVerifierError> *)outError
{
	(void)rootPList;
	verifiers.push_back(verifier);
	delegated.push_back(name + " " + oo::DescriptionOf(typeKey) + " " + KeyPathText(keyPath) + " " + oo::DescriptionOf(subPList));
	if (delegatedRaises)  [OOException raise:OOGenericException format:"delegate refuses %s", name.c_str()];
	if (delegatedError && outError != nullptr)  *outError = OOPListSchemaVerifierError{ "test.domain", 42, std::string("delegate's own error"), oo::PList() };
	return delegatedAnswer;
}


- (BOOL)verifier:(OOPListSchemaVerifier *)verifier
withPropertyList:(const oo::PList &)rootPList
		   named:(const std::string &)name
 failedForProperty:(const oo::PList &)subPList
	   withError:(const OOPListSchemaVerifierError &)error
	expectedType:(const oo::PList &)localSchema
{
	(void)rootPList; (void)subPList;
	verifiers.push_back(verifier);
	failures.push_back(name + ": " + FailureText(error, localSchema));
	return continueAfterFailure;
}

@end


// A delegate that handles neither delegated types nor failures.
@interface TestMuteDelegate: OOObject
@end

@implementation TestMuteDelegate
@end


namespace {

const char *const kShipSchema =
	"{ type = dictionary; allowOthers = NO; requiredKeys = ( name ); schema = {"
	"  name = string; count = positiveInteger; roles = { type = array; valueType = $role; };"
	"  scale = { type = float; minimum = 0.5; maximum = 2; };"
	"}; $definitions = { $role = { type = string; }; }; }";


oo::PList GoodShip()
{
	return oo::PList(oo::PList::Dict {
		{ "name", oo::PList("Cobra") },
		{ "count", oo::PList(3) },
		{ "roles", oo::PList(oo::PList::Array { oo::PList("trader"), oo::PList("hunter") }) },
		{ "scale", oo::PList(1.5) },
	});
}

}	// namespace


OO_TEST(nullSchemaGivesNil)
{
	OO_CHECK([OOPListSchemaVerifier verifierWithSchema:oo::PList()] == nil);
	OOPListSchemaVerifier *allocated = [[OOPListSchemaVerifier alloc] initWithSchema:oo::PList()];
	OO_CHECK(allocated == nil);
	OO_CHECK([OOPListSchemaVerifier verifierWithSchema:Parse("string")] != nil);
}


OO_TEST(keepsItsDelegate)
{
	@autoreleasepool
	{
		OOPListSchemaVerifier *verifier = [OOPListSchemaVerifier verifierWithSchema:Parse(kShipSchema)];
		OO_CHECK([verifier delegate] == nil);
		TestSchemaDelegate *delegate = [[[TestSchemaDelegate alloc] init] autorelease];
		[verifier setDelegate:delegate];
		OO_CHECK([verifier delegate] == delegate);
		OO_CHECK([delegate retainCount] == 1);	// not retained
		[verifier setDelegate:nil];
		OO_CHECK([verifier delegate] == nil);
	}
}


OO_TEST(acceptsAValidPropertyList)
{
	@autoreleasepool
	{
		OOPListSchemaVerifier *verifier = [OOPListSchemaVerifier verifierWithSchema:Parse(kShipSchema)];
		TestSchemaDelegate *delegate = [[[TestSchemaDelegate alloc] init] autorelease];
		[verifier setDelegate:delegate];
		OO_CHECK([verifier verifyPropertyList:GoodShip() named:"cobra"]);
		OO_CHECK(delegate->failures.empty());
		OO_CHECK(delegate->verifiers.empty());
	}
}


OO_TEST(reportsEachFailureToTheDelegate)
{
	@autoreleasepool
	{
		OOPListSchemaVerifier *verifier = [OOPListSchemaVerifier verifierWithSchema:Parse(kShipSchema)];
		TestSchemaDelegate *delegate = [[[TestSchemaDelegate alloc] init] autorelease];
		delegate->continueAfterFailure = YES;
		[verifier setDelegate:delegate];

		oo::PList::Dict ship = *GoodShip().getIf<oo::PList::Dict>();
		ship["count"] = oo::PList(-2);
		ship["roles"] = oo::PList(oo::PList::Array { oo::PList("trader"), oo::PList(7) });
		ship["scale"] = oo::PList(3.0);
		ship["colour"] = oo::PList("red");
		OO_CHECK(![verifier verifyPropertyList:oo::PList(ship) named:"bad"]);

		const std::vector<std::string> expected = {
		};
		OO_CHECK(delegate->failures == expected);
		for (const std::string &failure : delegate->failures)  std::fprintf(stderr, "  failure: %s\n", failure.c_str());
		for (id seen : delegate->verifiers)  OO_CHECK(seen == verifier);
	}
}


OO_TEST(stopsWhenTheDelegateSaysSo)
{
	@autoreleasepool
	{
		OOPListSchemaVerifier *verifier = [OOPListSchemaVerifier verifierWithSchema:Parse(kShipSchema)];
		TestSchemaDelegate *delegate = [[[TestSchemaDelegate alloc] init] autorelease];
		delegate->continueAfterFailure = NO;
		[verifier setDelegate:delegate];

		oo::PList::Dict ship = *GoodShip().getIf<oo::PList::Dict>();
		ship.erase("name");
		ship["count"] = oo::PList(-2);
		OO_CHECK(![verifier verifyPropertyList:oo::PList(ship) named:"stop"]);
		OO_CHECK_EQ(delegate->failures.size(), 1u);
		for (const std::string &failure : delegate->failures)  std::fprintf(stderr, "  failure: %s\n", failure.c_str());
	}
}


OO_TEST(reportsABadSchema)
{
	@autoreleasepool
	{
		TestSchemaDelegate *delegate = [[[TestSchemaDelegate alloc] init] autorelease];
		delegate->continueAfterFailure = YES;

		OOPListSchemaVerifier *undefinedMacro = [OOPListSchemaVerifier verifierWithSchema:Parse("{ type = $nothing; }")];
		[undefinedMacro setDelegate:delegate];
		OO_CHECK(![undefinedMacro verifyPropertyList:oo::PList("x") named:"macro"]);

		OOPListSchemaVerifier *unknownType = [OOPListSchemaVerifier verifierWithSchema:Parse("{ type = gizmo; }")];
		[unknownType setDelegate:delegate];
		OO_CHECK(![unknownType verifyPropertyList:oo::PList("x") named:"unknown"]);

		OOPListSchemaVerifier *noType = [OOPListSchemaVerifier verifierWithSchema:Parse("{ minimum = 1; }")];
		[noType setDelegate:delegate];
		OO_CHECK(![noType verifyPropertyList:oo::PList("x") named:"untyped"]);

		const std::vector<std::string> expected = {
		};
		OO_CHECK(delegate->failures == expected);
		for (const std::string &failure : delegate->failures)  std::fprintf(stderr, "  failure: %s\n", failure.c_str());
	}
}


OO_TEST(asksTheDelegateAboutDelegatedTypes)
{
	@autoreleasepool
	{
		OOPListSchemaVerifier *verifier = [OOPListSchemaVerifier verifierWithSchema:Parse("{ type = array; valueType = { type = delegatedType; baseType = string; key = shipKey; }; }")];
		TestSchemaDelegate *delegate = [[[TestSchemaDelegate alloc] init] autorelease];
		delegate->continueAfterFailure = YES;
		[verifier setDelegate:delegate];
		const oo::PList list(oo::PList::Array { oo::PList("adder"), oo::PList("viper") });

		delegate->delegatedAnswer = YES;
		OO_CHECK([verifier verifyPropertyList:list named:"yes"]);

		delegate->delegatedAnswer = NO;
		OO_CHECK(![verifier verifyPropertyList:list named:"no"]);

		delegate->delegatedAnswer = YES;
		delegate->delegatedError = YES;
		OO_CHECK(![verifier verifyPropertyList:list named:"error"]);

		delegate->delegatedError = NO;
		delegate->delegatedRaises = YES;
		OO_CHECK(![verifier verifyPropertyList:list named:"raises"]);

		const std::vector<std::string> expectedDelegated = {
		};
		const std::vector<std::string> expectedFailures = {
		};
		OO_CHECK(delegate->delegated == expectedDelegated);
		OO_CHECK(delegate->failures == expectedFailures);
		for (const std::string &call : delegate->delegated)  std::fprintf(stderr, "  delegated: %s\n", call.c_str());
		for (const std::string &failure : delegate->failures)  std::fprintf(stderr, "  failure: %s\n", failure.c_str());
		for (id seen : delegate->verifiers)  OO_CHECK(seen == verifier);
	}
}


OO_TEST(aDelegateThatHandlesNothing)
{
	@autoreleasepool
	{
		// Delegated types pass; a failure stops verification.
		OOPListSchemaVerifier *verifier = [OOPListSchemaVerifier verifierWithSchema:Parse("{ type = array; valueType = { type = delegatedType; baseType = string; key = shipKey; }; }")];
		[verifier setDelegate:[[[TestMuteDelegate alloc] init] autorelease]];
		OO_CHECK([verifier verifyPropertyList:oo::PList(oo::PList::Array { oo::PList("adder"), oo::PList("viper") }) named:"mute"]);
		OO_CHECK(![verifier verifyPropertyList:oo::PList(4) named:"mute"]);

		OOPListSchemaVerifier *orphan = [OOPListSchemaVerifier verifierWithSchema:Parse("string")];
		OO_CHECK(![orphan verifyPropertyList:oo::PList(4) named:"orphan"]);
		OO_CHECK([orphan verifyPropertyList:oo::PList("four") named:"orphan"]);
	}
}


OO_TEST(describesKeyPaths)
{
	OO_CHECK_EQ(KeyPathText(oo::PList()), "root");
	OO_CHECK_EQ(KeyPathText(oo::PList(oo::PList::Array {})), "root");
	OO_CHECK_EQ(KeyPathText(oo::PList(oo::PList::Array { oo::PList("adder-player"), oo::PList("custom_views"), oo::PList(0), oo::PList("view_description") })), "adder-player.custom_views[0].view_description");
	OO_CHECK_EQ(KeyPathText(oo::PList(oo::PList::Array { oo::PList(2), oo::PList("x") })), "[2].x");
	OO_CHECK_EQ(KeyPathText(oo::PList(oo::PList::Array { oo::PList(1.5) })), "[1.5]");
	OO_CHECK_EQ(KeyPathText(oo::PList(oo::PList::Array { oo::PList("a"), oo::PList(oo::PList::Dict {}) })), "(nullopt)");
	OO_CHECK_EQ(KeyPathText(oo::PList("not an array")), "root");
}


OO_TEST_MAIN()
