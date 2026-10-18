/*	EntityHelpersStandIn.h
	For a narrow test that stands in for the root entity with its own Objective-C object per C++
	entity (its oo::ToObjC(), declared before this is imported) and links code that holds, asks or
	describes entities through EntityHelpers.mm (bead oo-dpyk8, ADR-0056 amendment oo-dpyk8, which
	deleted the game's root facade and its oo::ToObjC()). The helpers answer on the test's objects as
	the game's answered on the facade: an entity "has its object" while its stand-in object exists,
	a hold retains and releases that object, and the descriptions are the object's. Import it once,
	in the test's own file, after its oo::ToObjC(). A test that links no OODescription.mm (and whose
	code under test describes no entity) defines OO_ENTITY_HELPERS_STAND_IN_NO_DESCRIPTIONS first.
*/
#ifndef ENTITY_HELPERS_STAND_IN_H
#define ENTITY_HELPERS_STAND_IN_H

#import "OODescription.h"

#include <string>

namespace cxx { class Entity; }

namespace oo {
namespace detail {
bool EntityHasObject(const cxx::Entity *entity) noexcept;
void EntityRetain(cxx::Entity *entity) noexcept;
void EntityRelease(cxx::Entity *entity) noexcept;
}	// namespace detail
cxx::Entity *WithObject(cxx::Entity *entity);
std::string EntityDescription(cxx::Entity *entity);
std::string EntityShortDescription(cxx::Entity *entity);
}	// namespace oo


bool oo::detail::EntityHasObject(const cxx::Entity *entity) noexcept	{ return entity != nullptr && oo::ToObjC(const_cast<cxx::Entity *>(entity)) != nil; }
void oo::detail::EntityRetain(cxx::Entity *entity) noexcept				{ if (entity != nullptr)  [oo::ToObjC(entity) retain]; }
void oo::detail::EntityRelease(cxx::Entity *entity) noexcept			{ if (entity != nullptr)  [oo::ToObjC(entity) release]; }
cxx::Entity *oo::WithObject(cxx::Entity *entity)						{ return (entity != nullptr && oo::ToObjC(entity) != nil) ? entity : nullptr; }
#ifndef OO_ENTITY_HELPERS_STAND_IN_NO_DESCRIPTIONS
std::string oo::EntityDescription(cxx::Entity *entity)					{ return oo::DescriptionOf(oo::ToObjC(entity)); }
std::string oo::EntityShortDescription(cxx::Entity *entity)				{ return oo::ShortDescriptionOf(oo::ToObjC(entity)); }
#endif

#endif	// ENTITY_HELPERS_STAND_IN_H
