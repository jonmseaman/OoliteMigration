# Contract: threads (US3, M2)

Design step D4. Research: R6.

## `OOAsyncWorkManager`

- The workers (1 to `WorkThreadCount()`) are a `std::vector<std::jthread>` owned by the manager's
  internal object. Each worker loop waits with
  `std::condition_variable_any::wait(lock, stopToken, predicate)` and returns when stop is
  requested and its current task (if any) has finished.
- New member, called once from the quit path before `exit(0)` (`GameController.cpp:706`):

  ```cpp
  // Requests stop, wakes every worker, and joins them. Tasks still queued are
  // dropped without running their completion. Idempotent.
  void shutdown() noexcept;
  ```

- The manager stays immortal (`oo::Immortal`, FR-005); its destructor is never run, so
  `shutdown()` is the only join.
- Each worker still calls `oo::thread::setCurrentPriority(0.5)` and
  `oo::thread::setCurrentName("OOAsyncWorkManager thread N")` first, as today
  (`OOAsyncWorkManager.cpp:193-194`).
- The singleton is created by a function-local static, replacing `pthread_once` and the Windows
  mutex.

## `oofnd/Thread.hpp` after M2

```cpp
namespace oo::thread {

// The id of the thread that ran static initialisation (the one that calls main).
inline const std::thread::id kMainThreadId = std::this_thread::get_id();

bool setCurrentName(std::string_view utf8);   // unchanged
bool setCurrentPriority(double p);            // unchanged

}  // namespace oo::thread
```

`detach` and `isMainThread` are gone. Callers write `std::this_thread::get_id() ==
oo::thread::kMainThreadId`. `OOLogOutputHandler.cpp`'s own `sMainThreadID` uses `kMainThreadId`.

## Unchanged

The log writer (`LogFile.hpp:165`, joined by `stop()`) and the HTTP download (`Http.hpp:257`,
joined by `~Download` after cancelling) already own their threads. Converting them to
`std::jthread` is optional and changes nothing observable.

## Acceptance

- Quitting with a planet texture being generated, and with an expansion download in progress,
  exits in no more time than the base (test added in M0, FR-016).
- TSan over the smoke run reports nothing the base does not.
