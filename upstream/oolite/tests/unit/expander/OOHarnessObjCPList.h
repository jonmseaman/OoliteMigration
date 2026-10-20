// Stub for tests/unit/expander (bead oo-4aq6a.5): the harness's own copy of the Objective-C object's
// PList::Object node (oo::PListObject, oo::ObjectIn, oo::PListFromObjects, oo::ObjCRefsIn,
// ObjCPListForeign), taken unchanged from src/Core/OOObjCPList.h as bead oo-4aq6a.5 deleted it there
// (no game object is an Objective-C object), so the harness's Foundation conversions carry their
// objects exactly as before. Test infrastructure only (the harness links gnustep-base;
// OOHarnessFoundation.h); never in the game. It goes with the harness's Objective-C (oo-4aq6a.8).
#ifndef OO_HARNESS_OBJC_PLIST_H
#define OO_HARNESS_OBJC_PLIST_H

#include "OOObjCPList.h"	// what the header still includes
#include "OODescription.h"

// extern "C++" as OODescription.h is: a header may be reached from inside an extern "C" block.
extern "C++" {

#include "oofnd/StdLib.hpp"
#include "oofnd/PList.hpp"
#include "oofnd/objc/OOObjCRef.h"


namespace oo {

// A PList::Object node's payload: an Objective-C object, retained (Amendment 2 carrier). Not final:
// an entity's node is a subclass that also answers its C++ part (oo::EntityPListForeign, bead
// oo-9ht.39.5.3).
class ObjCPListForeign : public PListForeign
{
public:
	explicit ObjCPListForeign(id object) : object_(object) {}
	id object() const noexcept { return object_.get(); }
	std::string className() const override { return class_getName(object_getClass(object_.get())); }
	std::string description() const override { return DescriptionOf(object_.get()); }

private:
	ObjCRef<id> object_;
};

inline PList PListObject(id object)
{
	if (object == nil)  return PList();
	return PList(PList::Object(makeRef<ObjCPListForeign>(object)));
}

// The object a PList::Object node holds; nil for any other node.
inline id ObjectIn(const PList& plist)
{
	if (const PList::Object *node = plist.getIf<PList::Object>())
	{
		if (const auto *foreign = dynamic_cast<const ObjCPListForeign *>(node->get()))  return foreign->object();
	}
	return nil;
}

// An array of Object nodes, one per non-nil element, in order.
template <class T>
PList PListFromObjects(const std::vector<ObjCRef<T>>& objects)
{
	PList::Array result;
	result.reserve(objects.size());
	for (const auto& object : objects)
	{
		if (object)  result.push_back(PListObject(object.get()));
	}
	return PList(std::move(result));
}

// The objects of an array's Object nodes, retained, in order; other elements are skipped.
template <class T>
std::vector<ObjCRef<T>> ObjCRefsIn(const PList& plist)
{
	std::vector<ObjCRef<T>> result;
	if (const PList::Array *array = plist.getIf<PList::Array>())
	{
		for (const PList& element : *array)
		{
			id object = ObjectIn(element);
			if (object != nil)  result.emplace_back(static_cast<T>(object));
		}
	}
	return result;
}

}	// namespace oo

}	// extern "C++"

#endif	// OO_HARNESS_OBJC_PLIST_H
