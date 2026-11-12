# Contract: ownership (US2, M5)

The interfaces design step D1 adds, quoted so the fan-out steps add none. D1 may change a detail
here only by editing this file in the same commit, with the reason. Research: R5.

## `src/oofnd/Object.hpp`

```cpp
#pragma once
#include <memory>

namespace oo {

// The common base of every shared-owned game object (was oo::RefCounted).
// Objects are created with oo::makeShared, never std::make_shared, so that
// willDispose() runs before the destructor.
class Object : public std::enable_shared_from_this<Object> {
 public:
  virtual ~Object() = default;

 protected:
  Object() noexcept = default;
  // Copying gives a new, unowned object (as RefCounted's copy did); assignment
  // leaves ownership alone.
  Object(const Object&) noexcept : std::enable_shared_from_this<Object>() {}
  Object& operator=(const Object&) noexcept { return *this; }

  // Called once, by the deleter, after the last owner has released the object
  // and before its destructor. Weak references to it are already empty.
  virtual void willDispose() noexcept {}

 private:
  friend struct Dispose;
};

// The deleter every oo::makeShared object carries.
struct Dispose {
  void operator()(Object* p) const noexcept {
    p->willDispose();
    delete p;
  }
};

template <class T, class... Args>
std::shared_ptr<T> makeShared(Args&&... args) {
  return std::shared_ptr<T>(new T(std::forward<Args>(args)...), Dispose{});
}

// An owning reference from a raw pointer to an object some shared_ptr already
// owns (was Ref<T>(T*)). Null gives null; an unowned object throws
// std::bad_weak_ptr.
template <class T>
std::shared_ptr<T> share(T* p) {
  if (p == nullptr) return nullptr;
  return std::static_pointer_cast<T>(
      static_cast<Object*>(const_cast<std::remove_const_t<T>*>(p))->shared_from_this());
}

// A singleton that is never destroyed (was makeRef(...).leakRef()). The
// returned reference lives for the rest of the program.
template <class T>
const std::shared_ptr<T>& Immortal(std::shared_ptr<T> p) {
  return *new std::shared_ptr<T>(std::move(p));
}

}  // namespace oo
```

Use: `static const std::shared_ptr<OOCacheManager>& sShared =
oo::Immortal(oo::makeShared<OOCacheManager>());`. Each use is an `exceptions.md` row (FR-005).

Shared ownership is `std::shared_ptr<T>`, observation is `std::weak_ptr<T>`, exclusive ownership
is `std::unique_ptr<T>` or a value member (FR-009). Setters take `std::shared_ptr<T>`; where a
caller has only a raw pointer, it passes `oo::share(p)`.

## `src/oofnd/AutoreleaseScope.hpp`

Same name, nesting and draining rules as today's `oo::AutoreleaseScope` (`Ref.hpp:501-531`):
per-thread, strictly LIFO (a scope destroyed out of order aborts), draining newest first, and an
object released during a drain that autoreleases another is drained in the same pass.

```cpp
namespace oo {

class AutoreleaseScope {
 public:
  AutoreleaseScope() noexcept;
  ~AutoreleaseScope();              // drains, then pops itself
  AutoreleaseScope(const AutoreleaseScope&) = delete;
  AutoreleaseScope& operator=(const AutoreleaseScope&) = delete;
  void drain() noexcept;            // releases newest first, cascading

 private:
  AutoreleaseScope* parent_;
  std::vector<std::shared_ptr<const void>> pending_;
};

// Hands one owning reference to the innermost scope on this thread and returns
// the raw pointer. With no scope open the object is kept forever and counted,
// as today.
template <class T>
T* autorelease(std::shared_ptr<T> p) noexcept;

}  // namespace oo
```

## `src/oofnd/WeakSet.hpp`

Today's contract (`WeakSet.hpp:1-40`) kept: identity uniquing, `add(nullptr)` ignored,
insertion-order iteration, `forEach` over a retained snapshot, copying gives the live members,
single-threaded. Members are `std::weak_ptr<T>`; `add` and `remove` take `const
std::shared_ptr<T>&` and `T*` (through `oo::share`); `allObjects()` returns
`std::vector<std::shared_ptr<T>>`.

## Entities

```cpp
// src/Core/Entities/OOEntityHold.h
using EntityHold = std::shared_ptr<Entity>;

// An owning reference to e if it has its object (Entity::hasObject()), else
// null: what EntityHold(raw) did.
inline EntityHold Hold(Entity* e) {
  return (e != nullptr && e->hasObject()) ? oo::share(e) : nullptr;
}
```

- Entities are made with `oo::makeShared`, so `Entity::willDispose()` (today's override) runs
  from `oo::Dispose`.
- The +1 creators (`newShipWithRole`, `newShipWithName`, …) return `std::shared_ptr<T>`.
  `MadeEntity` returns `oo::autorelease(…)` as today; `MadeEntityRetained` returns the
  `shared_ptr`.
- `RetainEntity`/`ReleaseEntity`/`AutoreleaseEntity` are removed with the bridge; until then the
  bridge's manual-hold counter implements them.
- Code that read a weak reference to the entity during `willDispose()` (D2's list, in
  `data-model.md` *Disposal readers*) is rewritten so its test passes: the work is done before
  the last release, or the field keeps the identity pointer beside its `std::weak_ptr`.

## The script-engine slot (`src/Core/Scripting/OOJSPrivateObject.*`)

```cpp
// Stores a new heap std::shared_ptr<oo::Object> holding obj in the JS object's
// opaque slot (was: retain obj, store the raw pointer).
void OOJSSetCxxPrivate(JSContext* ctx, JSValueConst jsObj, std::shared_ptr<oo::Object> obj);

// The object in the slot, or null (was a cast of the raw opaque pointer).
template <class T> T* OOJSGetCxxPrivate(JSValueConst jsObj);
```

The finaliser keeps today's order (`OOJSPrivateObject.cpp:88-102`): take the slot's holder, null
the slot, call `clearJSSelf`, delete the holder (releasing the object). Observing holders
(`OOJSEntityHolder`, `ScriptPrivate`) keep a `std::weak_ptr`.

## The transitional bridge (M5 only)

While callers move, `oofnd/Ref.hpp` keeps its names over the standard types:

| Today | Bridge | End state |
|---|---|---|
| `oo::RefCounted` | `class RefCounted : public Object` plus a manual-hold counter (`retain()` takes a `shared_ptr` to itself on 0→1; `release()` drops it on 1→0) | `oo::Object` |
| `oo::Ref<T>` | wraps `std::shared_ptr<T>`; `Ref<T>(T*)` is `oo::share` | `std::shared_ptr<T>` |
| `oo::WeakRef<T>` | wraps `std::weak_ptr<T>` | `std::weak_ptr<T>` |
| `oo::makeRef<T>` | `oo::makeShared<T>` | `oo::makeShared<T>` |
| `leakRef()` / `adopt(p)` | a manual hold taken / given back | removed (singletons use `oo::Immortal`; the script slot holds a heap `shared_ptr`) |
| `retainCount()` | `use_count()` of the object's control block, plus manual holds | `use_count()` |
| `dropWeakReferences()` | no-op: weak references are already empty in `willDispose()` | removed |

The bridge commit is the one where `test_ref.cpp:514` changes meaning; it waits for Jon's
sign-off (plan.md *Notes*).
