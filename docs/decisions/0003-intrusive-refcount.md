# ADR-0003: `oo::Ref<T>` / `oo::WeakRef<T>`, not `std::shared_ptr`

**Status:** Accepted · **Date:** 2026-09-05

## Context

~2,116 `retain`/`release`/`autorelease` sites, 92 `NSAutoreleasePool`, no ARC, and a custom
`OOWeakReference` proxy marking every weak edge in the entity graph. `ShipEntity` has 186 ivars and
there can be thousands of entities.

## Decision

Mirror ObjC refcounting 1:1 with an intrusive `oo::RefCounted` base, `oo::Ref<T>`, `oo::WeakRef<T>`,
and a scope-based `oo::AutoreleaseScope` shim that is deleted in Phase 5. Do **not** use
`std::shared_ptr` during translation.

## Consequences

- `[x retain]` → `x->retain()` is a reviewable one-line change; ownership redesign is not mixed
  into language conversion.
- Object identity stays the pointer; no control block per object; no `shared_from_this`.
- After a class is in C++ and green, a *second* pass demotes leaf types to values and
  exclusively-owned members to `unique_ptr`. Two passes, each individually reviewable.
- Hand-translated refcounting *will* produce use-after-free; ASan on Linux is mandatory per PR.

## History

`MIGRATION_PLAN.md` §3.5, §4/R3. Now [architecture.md §3.5](../architecture.md).
