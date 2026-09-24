# ADR-0026 — `oo::Ref` details ADR-0003 leaves open

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-qpa, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Point 4's drain order superseded by [ADR-0045](0045-autorelease-scope-drains-lifo.md)**
(2026-09-23: the game's pool is libobjc2's and drains LIFO; the rest of point 4 stands).
**Refines** [ADR-0003](0003-intrusive-refcount.md) and the sketch in
[architecture §3.4](../architecture.md). Implemented in `upstream/oolite/src/oofnd/Ref.hpp` and
`WeakSet.hpp`.

## Context

ADR-0003 fixes the shape (intrusive `RefCounted`, `Ref<T>`, `WeakRef<T>`, `AutoreleaseScope`, an
atomic count) but not six details that every translated call site depends on. Each has a default
that mirrors Objective-C/GNUstep as it runs today; where mirroring exactly is unsafe in C++, the
default is the nearest safe behaviour.

## Decision

1. **Ownership of a raw pointer.** The count starts at 1 (`+alloc`). `Ref<T>(T*)` *retains*
   (explicit), like a retaining setter; `oo::adopt(T*)` / `oo::makeRef<T>(...)` take over the +1
   of `new`, a copy or an `OO_RETURNS_RETAINED` return; `ref.leakRef()` hands a +1 back out.
   Null-safe free functions `oo::retain`/`oo::release`/`oo::autorelease` translate messages to a
   pointer that may be nil.
2. **Weak references zero before the destructor runs.** At count 0 the object's `WeakControl` is
   cleared, then the object is deleted. `OOWeakReference` kept forwarding until the root
   `-dealloc`; in C++ that would hand out a half-destroyed object. This is ARC-weak behaviour.
3. **Cycles are not collected**, exactly as under manual retain/release. Weak edges break them.
4. **`AutoreleaseScope` is GNUstep's pool:** per-thread, nested, innermost receives; drains in
   insertion order, including objects autoreleased during the drain; `drain()` keeps the scope
   open (the recycle-the-pool idiom). Autorelease with no scope leaks and is counted
   (GNUstep leaks and logs). Non-LIFO destruction aborts. Stack-only (`operator new` deleted).
5. **Thread safety is ADR-0003's, no more:** the object count (so `Ref` copy/destroy) is atomic;
   `WeakRef` dereference, weak-control creation and `WeakSet` are confined to one thread, which
   makes the final release, as `OOWeakReference`/`OOWeakSet` are today. The control block's own
   count is atomic, so `WeakRef` handles may be copied or destroyed anywhere.
6. **`WeakSet` iterates in insertion order** (NSSet's order was pointer-hash, i.e. unspecified),
   uniques by identity through the control block (so a new object at a dead member's address is
   never mistaken for it), and `forEach` runs over a retained snapshot so callbacks may mutate
   the set.

## Consequences

- Every translated `retain`/`release`/`autorelease`/`weakRetain` has a one-line mapping (table in
  the `Ref.hpp` banner). Mixing up `Ref<T>(new T)` and `oo::adopt(new T)` leaks; ASan does not
  report leaks on this toolchain (`detect_leaks=0`), so reviewers must check for it.
- Code that relied on messaging a dying object through its weak proxy during `-dealloc` now sees
  null. None is known; the golden runs are the oracle.
- Moving `WeakRef`/`WeakSet` use off the main thread would need a new ADR (a locking or
  control-block-count design), not a local fix.
