/*	test_EntityOOJavaScriptExtensions.mm
	Unit tests for the categories Entity (OOJavaScriptExtensions) and ShipEntity
	(OOJavaScriptExtensions) (src/Core/Scripting/EntityOOJavaScriptExtensions.h/.mm): bead oo-g223,
	what the script engine asks an entity by selector (is it visible to scripts, its JS class
	name, its JS class and prototype, its JS object) and what scripts ask a ship (its subentities,
	and setting its target, which climbs from a subentity to its root ship on both sides).

	The categories reach the entity's C++ part (_jsSelf), so the test links the whole game but main
	(['*']) and uses the real Entity. A ship is the test's subclass of ShipEntity made with
	class_createInstance (never initialised, never released): it answers the ShipEntity selectors
	the category sends (its subentities, its owner, being a subentity, its targets) and records
	what it was told. The JS object the entity already has is a plain object of a runtime the test
	makes. The expectations were written against the Objective-C categories and run on them
	first; they send only the categories' selectors, so the conversion (the bodies as free
	functions, the categories' forwarders in EntityOOJavaScriptExtensions+ObjCBridge.mm) changed no
	line here.
	Run: bash tools/check-core-tests.sh
*/

#import "EntityOOJavaScriptExtensions.h"
#import "ShipEntity.h"
#import "OOJSEntity.h"
#import "OOJSShip.h"

#include "oo_test.hpp"

#include <string>
#include <vector>


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif


// A ship that answers what the functions ask a ship, and records the targets it was told. A C++
// subclass since bead oo-9ht.144 deleted the Objective-C ship this subclassed: its subentities, owner
// and being a subentity are the ship's own state, set by the test; its primary target and the
// targets it is told are its overrides (removeTarget() is virtual for it, a test seam: amendment
// oo-9ht.107 item 6).
class TestShip : public ShipEntity
{
public:
	id								_testPrimaryTarget = nil;
	std::vector<std::string>		_told;		// "add <name>" / "remove <name>"
	const char						*_name = "";

	id primaryTarget() override	{ return _testPrimaryTarget; }

	void addTarget(::Entity *targetEntity) override
	{
		_told.push_back(std::string("add ") + (targetEntity != nil ? static_cast<TestShip *>(oo::ToShip(targetEntity))->_name : "nil"));
	}

	void removeTarget(::Entity *targetEntity) override
	{
		_told.push_back(std::string("remove ") + (targetEntity != nil ? static_cast<TestShip *>(oo::ToShip(targetEntity))->_name : "nil"));
	}
};


// An entity that scripts can see but that keeps Entity's JS class.
@interface TestVisibleEntity: Entity
@end


@implementation TestVisibleEntity

- (BOOL) isVisibleToScripts  { return YES; }

@end


namespace {

ooscript::Runtime sRuntime = nullptr;
ooscript::Context sContext = nullptr;


void SetUpContext()
{
	if (sContext != nullptr)  return;
	sRuntime = ooscript::newRuntime(8u * 1024u * 1024u);
	sContext = ooscript::newContext(sRuntime, 8192);
	ooscript::beginRequest(sContext);
}


// A ship made the way the test can: the C++ ship under its object (oo::NewEntityFacade, retained and
// never released), never set up from a definition, a ship (it answers -isShip, as the Objective-C
// class did, so shipSubEntities() keeps it).
TestShip *Ship(const char *name)
{
	oo::Ref<TestShip> ship = oo::makeRef<TestShip>();
	@autoreleasepool
	{
		[oo::NewEntityFacade(ship) retain];
	}
	ship->isShip = YES;
	ship->_name = name;
	return ship.get();
}


// A subentity's owner, and that it is one (the Objective-C ship answered -owner and -isSubEntity).
void SetSubEntityOf(TestShip *ship, Entity *owner)
{
	ship->isSubEntity = YES;
	ship->cxx::Entity::setOwner(oo::ToCxx(owner));
}


std::string Told(TestShip *ship)
{
	std::string result;
	for (const std::string &line : ship->_told)  result += (result.empty() ? "" : "; ") + line;
	return result;
}

}	// namespace


OO_TEST(entityIsNotVisible)
{
	@autoreleasepool
	{
		Entity *entity = [[[Entity alloc] init] autorelease];
		OO_CHECK(![entity isVisibleToScripts]);
		OO_CHECK([entity cxx_oo_jsClassName] == std::optional<std::string>("Entity"));

		ooscript::ClassDef *jsClass = nullptr;
		ooscript::Object prototype = reinterpret_cast<ooscript::Object>(1);
		[entity getJSClass:&jsClass andPrototype:&prototype];
		OO_CHECK(jsClass == JSEntityClass());
		OO_CHECK(prototype == JSEntityPrototype());

		// Not visible: no JS object is made, and the value is null.
		SetUpContext();
		ooscript::Value value = [entity oo_jsValueInContext:sContext];
		OO_CHECK(ooscript::isNull(value));
		OO_CHECK(entity->_cxxEntity->_jsSelf == nullptr);

		// With no JS object, -deleteJSSelf does nothing.
		[entity deleteJSSelf];
		OO_CHECK(entity->_cxxEntity->_jsSelf == nullptr);
	}
}


OO_TEST(existingJSObject)
{
	@autoreleasepool
	{
		SetUpContext();
		ooscript::Object object = ooscript::newObject(sContext, nullptr, nullptr, nullptr);
		OO_CHECK(object != nullptr);

		// An entity that already has its JS object answers it, visible or not.
		Entity *entity = [[[Entity alloc] init] autorelease];
		entity->_cxxEntity->_jsSelf = object;
		ooscript::Value value = [entity oo_jsValueInContext:sContext];
		OO_CHECK(ooscript::isObject(value));
		ooscript::Object got = nullptr;
		OO_CHECK(ooscript::valueToObject(sContext, value, &got) && got == object);

		TestVisibleEntity *visible = [[[TestVisibleEntity alloc] init] autorelease];
		visible->_cxxEntity->_jsSelf = object;
		got = nullptr;
		OO_CHECK(ooscript::valueToObject(sContext, [visible oo_jsValueInContext:sContext], &got) && got == object);

		// The test's object is not rooted: the entities let go of it before they go.
		entity->_cxxEntity->_jsSelf = nullptr;
		visible->_cxxEntity->_jsSelf = nullptr;
	}
}


OO_TEST(visibleEntityKeepsEntityClass)
{
	@autoreleasepool
	{
		TestVisibleEntity *visible = [[[TestVisibleEntity alloc] init] autorelease];
		OO_CHECK([visible isVisibleToScripts]);
		OO_CHECK([visible cxx_oo_jsClassName] == std::optional<std::string>("Entity"));
		ooscript::ClassDef *jsClass = nullptr;
		ooscript::Object prototype = nullptr;
		[visible getJSClass:&jsClass andPrototype:&prototype];
		OO_CHECK(jsClass == JSEntityClass());
	}
}


OO_TEST(shipIsVisible)
{
	@autoreleasepool
	{
		TestShip *ship = Ship("ship");
		OO_CHECK([oo::ToObjC(ship) isVisibleToScripts]);
		OO_CHECK([oo::ToObjC(ship) cxx_oo_jsClassName] == std::optional<std::string>("Ship"));

		ooscript::ClassDef *jsClass = nullptr;
		ooscript::Object prototype = reinterpret_cast<ooscript::Object>(1);
		[oo::ToObjC(ship) getJSClass:&jsClass andPrototype:&prototype];
		OO_CHECK(jsClass == JSShipClass());
		OO_CHECK(prototype == JSShipPrototype());
	}
}


OO_TEST(subEntitiesForScript)
{
	@autoreleasepool
	{
		TestShip *ship = Ship("ship");
		OO_CHECK(ShipEntityJSSubEntitiesForScript(ship).empty());	// -subEntitiesForScript until bead oo-9ht.144

		TestShip *turret = Ship("turret");
		TestShip *hull = Ship("hull");
		ship->subEntities = { oo::ObjCRef<::Entity *>(oo::ToObjC(turret)), oo::ObjCRef<::Entity *>(oo::ToObjC(hull)) };
		std::vector<oo::ObjCRef<Entity *>> subs = ShipEntityJSSubEntitiesForScript(ship);
		OO_CHECK(subs.size() == 2);
		OO_CHECK(subs.size() == 2 && subs[0].get() == oo::ToObjC(turret) && subs[1].get() == oo::ToObjC(hull));
		ship->subEntities.clear();
	}
}


OO_TEST(setTarget)
{
	@autoreleasepool
	{
		TestShip *ship = Ship("ship");
		TestShip *other = Ship("other");
		ShipEntityJSSetTargetForScript(ship, other);	// -setTargetForScript: until bead oo-9ht.144
		OO_CHECK(Told(ship) == "add other");
	}
}


OO_TEST(setTargetNilRemovesPrimaryTarget)
{
	@autoreleasepool
	{
		TestShip *ship = Ship("ship");
		TestShip *current = Ship("current");
		ship->_testPrimaryTarget = oo::ToObjC(current);
		ShipEntityJSSetTargetForScript(ship, nullptr);	// -setTargetForScript: until bead oo-9ht.144
		OO_CHECK(Told(ship) == "remove current");

		// No primary target: remove nil.
		TestShip *idle = Ship("idle");
		ShipEntityJSSetTargetForScript(idle, nullptr);	// -setTargetForScript: until bead oo-9ht.144
		OO_CHECK(Told(idle) == "remove nil");
	}
}


OO_TEST(setTargetClimbsToRootShips)
{
	@autoreleasepool
	{
		// A subentity's target is set on its root ship, and a subentity target is replaced by its
		// root ship, however deep.
		TestShip *root = Ship("root");
		TestShip *middle = Ship("middle");
		TestShip *turret = Ship("turret");
		SetSubEntityOf(middle, oo::ToObjC(root));
		SetSubEntityOf(turret, oo::ToObjC(middle));

		TestShip *enemy = Ship("enemy");
		TestShip *enemyTurret = Ship("enemyTurret");
		SetSubEntityOf(enemyTurret, oo::ToObjC(enemy));

		ShipEntityJSSetTargetForScript(turret, enemyTurret);	// -setTargetForScript: until bead oo-9ht.144
		OO_CHECK(Told(root) == "add enemy");
		OO_CHECK(Told(turret).empty() && Told(middle).empty());
	}
}


OO_TEST(setTargetStopsAtSelfOwnedOrOwnerless)
{
	@autoreleasepool
	{
		// A subentity that owns itself, or has no owner, is where the climb stops.
		TestShip *loop = Ship("loop");
		SetSubEntityOf(loop, oo::ToObjC(loop));
		TestShip *orphan = Ship("orphan");
		orphan->isSubEntity = YES;
		ShipEntityJSSetTargetForScript(loop, orphan);	// -setTargetForScript: until bead oo-9ht.144
		OO_CHECK(Told(loop) == "add orphan");
	}
}


OO_TEST(setTargetOnANonShipRootDoesNothing)
{
	@autoreleasepool
	{
		// A subentity whose owner is not a ship: nothing is told.
		Entity *notAShip = [[[Entity alloc] init] autorelease];
		TestShip *sub = Ship("sub");
		SetSubEntityOf(sub, notAShip);
		TestShip *target = Ship("target");
		ShipEntityJSSetTargetForScript(sub, target);	// -setTargetForScript: until bead oo-9ht.144
		OO_CHECK(Told(sub).empty() && Told(target).empty());
	}
}


// Bead oo-9ht.107 (ADR-0056 amendment oo-9ht.107): the root category asks the entity's C++ part,
// so a C++ entity with no façade of its own answers the engine through its overrides, the defaults
// are the category's bodies, and an Objective-C class's own selectors still answer first.
namespace {

ooscript::ClassDef sTestScriptedClass = { "TestScripted", ooscript::ClassFlag::HasPrivate };

class TestScriptedEntity : public cxx::Entity
{
public:
	void getJSClass(ooscript::ClassDef **outClass, ooscript::Object *outPrototype) override
	{
		*outClass = &sTestScriptedClass;
		*outPrototype = nullptr;
	}
	std::optional<std::string> jsClassName() override  { return std::string("TestScripted"); }
	bool isVisibleToScripts() override  { return true; }
};

}	// namespace


OO_TEST(cxxEntityAnswersThroughItsJSMembers)
{
	@autoreleasepool
	{
		ooscript::ClassDef *jsClass = nullptr;
		ooscript::Object prototype = reinterpret_cast<ooscript::Object>(1);

		Entity *plain = oo::NewEntityFacade(oo::makeRef<cxx::Entity>());
		OO_CHECK(plain != nil && [plain class] == [Entity class]);
		OO_CHECK(![plain isVisibleToScripts] && !oo::ToCxx(plain)->isVisibleToScripts());
		OO_CHECK([plain cxx_oo_jsClassName] == std::optional<std::string>("Entity"));
		[plain getJSClass:&jsClass andPrototype:&prototype];
		OO_CHECK(jsClass == JSEntityClass() && prototype == JSEntityPrototype());

		Entity *scripted = oo::NewEntityFacade(oo::makeRef<TestScriptedEntity>());
		OO_CHECK(scripted != nil && [scripted class] == [Entity class]);
		OO_CHECK([scripted isVisibleToScripts]);
		OO_CHECK([scripted cxx_oo_jsClassName] == std::optional<std::string>("TestScripted"));
		[scripted getJSClass:&jsClass andPrototype:&prototype];
		OO_CHECK(jsClass == &sTestScriptedClass && prototype == nullptr);

		// An Objective-C override answers first; the C++ part keeps the default.
		TestVisibleEntity *visible = [[[TestVisibleEntity alloc] init] autorelease];
		OO_CHECK([visible isVisibleToScripts] && !oo::ToCxx(visible)->isVisibleToScripts());
	}
}


// An entity's Object node (bead oo-9ht.39.5.3): it holds the object, as oo::PListObject()'s did,
// answers the C++ part, and its JS value is the part's JS object (through the object, as before).
OO_TEST(entityObjectNodeHoldsTheEntity)
{
	@autoreleasepool
	{
		SetUpContext();
		ooscript::Object object = ooscript::newObject(sContext, nullptr, nullptr, nullptr);
		OO_CHECK(object != nullptr);
		Entity *entity = [[[Entity alloc] init] autorelease];
		cxx::Entity *part = oo::ToCxx(entity);
		part->_jsSelf = object;

		const oo::PList node = oo::EntityObjectNode(part);
		OO_CHECK(node.type() == oo::PList::Type::Object);
		OO_CHECK(oo::ObjectIn(node) == entity);
		OO_CHECK(oo::EntityIn(node) == part);
		const oo::PList::Object *payload = node.getIf<oo::PList::Object>();
		OO_CHECK(payload != nullptr && (*payload)->className() == "Entity");
		OO_CHECK(payload != nullptr && (*payload)->description() == oo::DescriptionOf(entity));
		ooscript::Object got = nullptr;
		OO_CHECK(ooscript::valueToObject(sContext, OOJSValueFromPList(sContext, node), &got) && got == object);

		// A plain Object node of the object answers the same entity; anything else answers none.
		OO_CHECK(oo::EntityIn(oo::PListObject(entity)) == part);
		OO_CHECK(oo::EntityIn(oo::PList(1)) == nullptr);
		OO_CHECK(oo::EntityIn(oo::PList()) == nullptr);
		OO_CHECK(oo::EntityObjectNode(static_cast<cxx::Entity *>(nullptr)).isNull());

		// Arrays: one node per entity, in order.
		const std::vector<oo::ObjCRef<Entity *>> refs{ oo::ObjCRef<Entity *>(entity), oo::ObjCRef<Entity *>(entity) };
		const std::vector<cxx::Entity *> parts = oo::EntitiesIn(oo::EntityNodesFrom(refs));
		OO_CHECK(parts.size() == 2 && parts[0] == part && parts[1] == part);

		part->_jsSelf = nullptr;	// the test's object is not rooted
	}
}


OO_TEST_MAIN()
