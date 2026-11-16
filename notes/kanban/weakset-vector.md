---
status: New
parent: seriesb/032-cleanup
---
# Slim `oo::WeakSet` to a vector

Related: [oofnd-shrink.md](oofnd-shrink.md) task 7, which goes further: it deletes the type and its
test. This card keeps both.

## Why the type exists

The standard library has no set of weak references that drops members when they die.

- `std::set<std::weak_ptr<T>, std::owner_less<>>` keeps dead members, so `size()` is wrong until
  you prune them by hand. It is also ordered by control-block address, which changes from run to run.
- `std::unordered_set` needs `std::owner_hash`/`owner_equal`, which only arrive in C++26.
- Neither Boost nor Abseil has one.

## Order: needed for determinism, not correctness

Upstream's `OOWeakSet` was an `NSSet`, whose order is unspecified, so no legacy code needs a
particular order. The port guarantees insertion order anyway, because the order changes what the
game does:

- `fireDirectLaserDefensiveShot` (`ShipEntity.cpp:11073`) and turret tracking (`:5979`) act on the
  first defense target in range.
- `abortAllDockings` and `autoDockShipsOnHold` (`StationEntity.cpp:1448-1483`) send AI messages and
  script events in set order.
- The JS arrays `ship.defenseTargets` and `ship.collisionExceptions` come out in set order.

With address order, component scenarios such as `s1_police_kills_pirate` could pass or fail
depending on which ship got shot first. `test_weakset.cpp:122,135,141` pin the insertion order.

## Complexity

n ≤ `MAX_TARGETS` (24, `ShipEntity.h:74`). Ships on hold and collision exceptions usually number 0–3.
Today's header already costs O(n) per operation: `add`, `contains` and `count` all call `compact()`,
which scans the vector, and `remove` runs `erase_if`. The `std::set` index (`index_`) adds memory
and code and makes nothing faster. At this size a scan over contiguous memory beats O(log n) steps
through tree nodes scattered across the heap.

## Task

Rewrite `src/oofnd/WeakSet.hpp` to hold only `std::vector<std::weak_ptr<T>> entries_`:

- `contains`, `add` and `remove` find members by a linear identity scan (`w.lock().get() == object`,
  or `owner_before` in both directions). `add` appends only if the object isn't there yet.
- `count()` compacts with `std::erase_if(entries_, expired)`.
- `allObjects`, the snapshot `forEach`, the copy (live members only) and `operator==` keep their
  meaning.
- Delete `Key`, `identityOf`, `index_` and `#include <set>`. The API doesn't change, so neither do
  the 3 members (`ShipEntity.h:1556,1559`, `StationEntity.h:231`).
- Update the `WeakSet` row in `src/oofnd/README.md:88` to say why it exists: no standard zeroing
  weak set, insertion order, and identity lookup by raw pointer.
- Run clang-format 22 on the header only.

## Decisions (defaults taken)

- **Keep the type, and keep `test_weakset` unchanged.** `oofnd-shrink` task 7 would delete both. That
  would put `erase_if(expired)` in 3 places and lose the snapshot `forEach` that callbacks rely on.
  Jon decides between the two.

## Done

- `tests/run.sh unit`: `test_weakset` passes unchanged.
- `git grep -qE 'index_|<set>' -- src/oofnd/WeakSet.hpp` exits nonzero. It exits 0 today.
- `./mk.sh build test` (Clang) and `tests/run.sh component` pass with no new warnings.
