# ADR-0029 — The Objective-C floor without Foundation

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-3rb.1, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Refines** [architecture §1 "load-bearing insight", §2.4, §3.4](../architecture.md) and
[phase 2](../phases/2-oofnd.md) work item 4. Implemented (root class, literals) in
`upstream/oolite/src/oofnd/objc/`; tested by `tests/unit/oofnd/test_objc_floor.mm` through
`tools/check-oofnd-objc.sh` (run by `tools/check-oofnd.sh`).

## Context

Phase 2 ends with `libgnustep-base` deleted from the link (oo-qps) while every game class is still
Objective-C++ on `libobjc2`. The sweep beads replace `NSString`/`NSArray`/`NSDictionary`/`NSSet`/
`NSNumber`/`NSData`/`NSEnumerator`/`NSMutable*`, and seams cover files, defaults, logging, strings
and plists. Nothing covered the rest of Foundation. Census of `upstream/oolite/src` on 2026-09-23
(refs / files):

| Family | Refs | Files | Family | Refs | Files |
|---|---:|---:|---|---:|---:|
| `NSObject` (root class) | 166 | 113 | `NSDate` / `NSTimeInterval` | 49 | 20 |
| `@"..."` literals (constant-string class) | thousands | most | `NSZone` / `NSCopying` | 51 / 62 | 21 / 34 |
| Foundation autorelease pool class | 117 | 36 | `NSCharacterSet` / `NSScanner` | 49 / 29 | 20 / 10 |
| `NSException`, `@try` (58 `@catch`, 16 of them `@catch (id)`, 10 `@finally`) | 89 | 39 | `NSURL` / `NSURLConnection` | 38 / 15 | 9 / 2 |
| `NSThread` / locks & conditions / `NSOperation` | 31 / 16 / 47 | 10 / 7 / 2 | `NSStream` / `NSHost` | 13 | 2 |
| `NSTimer` / `NSRunLoop` (the frame loop!) | 6 / 11 | 4 / 3 | `NSInvocation` / `NSMethodSignature` / `NSProxy` | 37 | 11 |
| `NSNotification` | 33 | 12 | `NSError` / `NSNull` / `NSProcessInfo` | 65 / 22 / 12 | 5 / 8 / 10 |
| `NSValue` | 99 | 20 | `NSClassFromString` & co. / `NSMapTable`·`NSHashTable` | 25 / 11 | 15 / 6 |
| `NSInteger`/`NSUInteger` | 1,245 | 164 | `NSRange`·`NSNotFound` / `NSPoint`·`NSSize`·`NSRect` | 232 / 516 | 53 / 53 |

### Measured on this toolchain (MSYS2 UCRT64, clang 22.1.8, libobjc2 2.3+803a2f6 = `libobjc-4.6.dll`, `-fobjc-runtime=gnustep-2.2` as `src/meson/meson.build` sets it)

Probes, then the unit test, established:

1. **A custom root class works.** `__attribute__((objc_root_class)) @interface OOObject { Class isa; }`,
   `+alloc` = `class_createInstance`, `-dealloc` = `object_dispose`. C++ ivars (including an
   `oo::Ref<T>`) are constructed and destroyed: libobjc2 runs `.cxx_construct`/`.cxx_destruct`.
2. **libobjc2's own reference count, autorelease pool and zeroing weak references serve it.**
   The class must implement the *instance* method `-_ARCCompliantRetainRelease` (the marker
   gnustep-base's `NSObject` carries). Without it, `objc_autorelease()` sends `-autorelease` back
   to a root whose `-autorelease` calls `objc_autorelease()`: measured as a stack-overflow crash.
   A class-method marker does not count. gnustep-base's `NSObject` is on the same count: it
   responds to the marker, and after `[o retain]` + `objc_retain(o)` both its `-retainCount` and
   `object_getRetainCount_np(o)` read 3. A subclass overriding `-retain`/`-release` (Oolite's
   immortal singletons) loses the fast path for itself only and the runtime sends it the messages.
3. **Pools drain in reverse order, and so does the game today.** libobjc2 releases a pool's
   objects last-in-first-out. Linked against gnustep-base, `[[<Foundation pool> alloc] init]` …
   `release` released 3, 2, 1 too: on this toolchain GNUstep's pool is libobjc2's. (ADR-0026 and
   `oo::AutoreleaseScope` assumed GNUstep drains in insertion order; they do not match the game.)
4. **`-fconstant-string-class=OOConstantString` works**, and emits for a literal of 9+ characters
   or any non-ASCII character a static object `{isa; uint32 flags, length, size, hash; const char *data}`:
   `flags` 0 = ASCII bytes, NUL-terminated; `flags` 2 = UTF-16 code units (`length` units, `size`
   bytes); `hash` always 0.
5. **Literals of 1–8 ASCII characters are not objects** but small-object pointers, tag 4 (length
   in bits 3–7, 7-bit characters from bit 57 down). Messaging one needs a class registered with
   `objc_registerSmallObjectClass_np(cls, 4)`; unregistered, **every message silently returns nil**.
   Today gnustep-base registers `GSTinyString` there (measured: `@"hi"` is a `GSTinyString`).
6. **The literal's static type** is `NSString *` (clang implicitly declares `@class NSString`)
   unless `-fno-constant-cfstrings` is also given; then it is `OOConstantString *`.
7. **COFF import.** clang declares the constant-string class `dllimport` in every TU that does not
   define it, so a static link gets lld's LNK4217 "locally defined symbol imported", fatal under
   meson's `werror` (`-Wl,--fatal-warnings`). Defining the `__imp_$_OBJC_CLASS_OOConstantString`
   slot (what an import library provides) removes the cause. No other class reference is affected.
8. **GNU ld cannot link the gnustep-2 ABI** (undefined `.objc_selector_*`); lld can. The game
   already links with lld (`clang.ini`).
9. **Without Foundation an unrecognised selector returns nil silently** (libobjc2's default
   hooks). Setting `__objc_msg_forward2` and `objc_proxy_lookup` restores
   `-forwardingTargetForSelector:` and `-doesNotRecognizeSelector:`. libobjc2 selectors are typed:
   compare them with `sel_isEqual`, never `==`.
10. **Objective-C exceptions need no Foundation.** `@throw` of an `OOObject` subclass is caught by
    `@catch (ThatClass *)` and `@catch (id)`; `@finally` runs. A C++ exception unwinds through
    Objective-C frames and `@finally` and is caught by C++ `catch`, but **`@catch (id)` does not
    catch it** (`std::terminate`).
11. **Coexistence with gnustep-base works** for an `OOObject` subclass inside `NSMutableArray`/
    `NSMutableDictionary`, once the root has `-methodForSelector:` (gnustep-base's collections
    cache IMPs; without it they raise). `NSLog(@"%@", obj)` raises: `OOObject` has no `-description`.
12. **The test links libobjc2 alone.** Its import table (`objdump -p`) is `libobjc-4.6.dll`,
    `libstdc++-6.dll`, `libgcc_s_seh-1.dll`, `libwinpthread-1.dll`, `KERNEL32.dll` and the UCRT;
    a planted `-lgnustep-base` + `NSLog` shows `gnustep-base-1_31.dll`, so the check can fire.

## Decision

1. **Root class `OOObject` on libobjc2's own memory management, not on `oo::RefCounted`.**
   `-retain`/`-release`/`-autorelease`/`-retainCount` are `objc_retain_fast_np`/
   `objc_release_fast_np`/`objc_autorelease`/`object_getRetainCount_np`, with the
   `-_ARCCompliantRetainRelease` marker. It is the count gnustep-base already uses (measurement 2), so rerooting a
   class changes no retain/release/dealloc behaviour; `objc_retain()`, `objc_loadWeak()` and
   `@autoreleasepool` all agree with it. A second count (`oo::RefCounted` inside an ObjC object)
   would need its own pool and would disagree with every runtime entry point. `oo::RefCounted` is
   for classes once they are C++ (Phase 3); the bridge between the two is an ObjC object holding
   `oo::Ref<T>` ivars (measured working). The root implements what the census shows the game
   sends: alloc/new/allocWithZone, retain family, class/superclass, isKindOfClass/
   isMemberOfClass/respondsToSelector/instancesRespondToSelector/conformsToProtocol,
   methodForSelector/instanceMethodForSelector, isEqual/hash (identity), performSelector (0–2
   objects), copy/mutableCopy via `OOCopying`/`OOMutableCopying`, forwardingTargetForSelector,
   doesNotRecognizeSelector (logs, aborts). `NSZone *` becomes the opaque `OOZone *`.
2. **Autorelease pools are libobjc2's.** Foundation pool objects become `@autoreleasepool { }`,
   or `objc_autoreleasePoolPush()`/`objc_autoreleasePoolPop()` where the scope is not lexical.
   No pool class. This can land before oo-qps: it is the same pool and the same LIFO order.
3. **`@"..."` is `OOConstantString`.** The game switches to
   `-fno-constant-cfstrings -fconstant-string-class=OOConstantString` and calls
   `OOObjCInstallFloor()` first thing in `main` (registers `OOTinyString` for tag 4, installs the
   forwarding hooks) in **one commit, together with or immediately before oo-qps**. Not earlier:
   while gnustep-base is linked, `NSString` consumers need `NSConstantString`, and tag 4 belongs to
   `GSTinyString`. `OOObjCInstallFloor()` aborts if the tag is taken, so the two cannot be mixed
   silently. `OOConstantString` offers only `-UTF8String`, `-length` (UTF-16 units), `-isEqual:`,
   `-isEqualToString:`, `-hash` (FNV-1a over UTF-8, equal for tiny and non-tiny) and `-copy`; it is
   immortal.
4. **Exceptions stay Objective-C in Phase 2**, on a Foundation-free `OOException : OOObject`
   (name, reason; `[NSException raise:format:]` becomes one oofnd function). Moving to C++
   exceptions now would silently change the 16 `@catch (id)` sites (measurement 10). Phase 3 turns
   `@try` into `try`/`catch (const oo::Exception&)` class by class.
5. **Everything else goes to the C++ standard library or oofnd, one bead per family** (below):
   threads, locks and conditions → `std::thread`/`std::mutex`/`std::recursive_mutex`/
   `std::condition_variable`; the frame loop's `NSTimer` + `[[NSRunLoop currentRunLoop] run]` →
   an explicit steady-clock loop at the same tick interval; `NSDate`/`NSTimeInterval` →
   `std::chrono` (`NSTimeInterval` stays a `double` typedef); `NSNotification` → a small
   `oo::NotificationCenter`; `NSValue` → dropped as the collections it boxed for become std
   containers; `NSCharacterSet`/`NSScanner` → `oo::str`; `NSURLConnection` → an HTTP client chosen
   by its own ADR (default libcurl); `NSStream`/`NSHost` → sockets (`ws2_32` is already linked);
   Foundation C types (`NSInteger`, `NSUInteger`, `NSRange`, `NSPoint`, `NSSize`, `NSRect`,
   `NSNotFound`, `NSMake*`) → one oofnd header with GNUstep's identical definitions and names,
   because renaming 1,900 sites is churn with no behaviour (the ADR-0012 argument).
6. **Build requirements of the floor:** lld, `-fobjc-runtime=gnustep-2.2`, `-lobjc`, and the
   `__imp_` slot of measurement 7 (in `OOObject.mm`). `-description`/`%@` are not in the floor:
   the String and Logging seams remove `%@`; until then a rerooted class that reaches `%@` gets
   `-description` from a game-side category compiled only while gnustep-base is linked.

### How this meets the sweeps

The sweep beads (`NSString`/`NSArray`/…) leave `@"..."` alone — their acceptance regex does not
match literals — so literals stay legal and keep meaning `NSConstantString` until the flip in
Decision 3. A sweep that turns a consumer into `oo::String`/`std::string_view` should turn the
literals it feeds into plain `"..."`. At the flip, `-fno-constant-cfstrings` types every remaining
literal `OOConstantString *`, so any `NSString *x = @"..."` a sweep missed becomes a compile error
instead of a runtime surprise; what legitimately remains (an `id` key or a log tag) works on
`OOConstantString`. Rerooting (`: NSObject` → `: OOObject`) is independent of the sweeps and can
run in parallel with them, one file per story, because the two roots coexist (measurement 11).

## Consequences

- The floor adds ~500 lines and no dependency; the test proves it links libobjc2 alone.
- **Order of the endgame:** family beads (any order, all before oo-qps) → reroot sweep → the
  constant-string flip → oo-qps. Each family bead is a child of oo-3rb and blocks oo-qps.
- **`oo::AutoreleaseScope` drains in the opposite order to the game's real pool** (measurement 3).
  Harmless while nothing C++ is autoreleased; filed as its own bead before Phase 3 depends on it.
- Short literals depend on a clang/libobjc2 private convention (tag 4, 7-bit packing). The unit
  test pins it, so a toolchain update that changes it fails `tools/check-oofnd.sh`, not the game.
- `-doesNotRecognizeSelector:` aborts where GNUstep raised an exception a `@catch` could swallow.
  Deliberate: nothing in Oolite relies on catching it, and a crash is found where a nil is not.
- Apple Silicon is unaffected: the floor dies with the runtime in Phase 4 (ADR-0009).

## Alternatives considered

- **`OOObject` counting through `oo::RefCounted`.** Rejected: a second count beside libobjc2's
  (which `objc_retain`, weak references and `@autoreleasepool` use regardless), two pools, and a
  behaviour change at every reroot.
- **Keep gnustep-base's `NSObject`/`NSConstantString` and delete the rest.** Not possible: they
  live in `libgnustep-base`, which oo-qps deletes.
- **Adopt Apple's open-source CoreFoundation / swift-corelibs-foundation.** A second Foundation
  to port and carry, for a floor this small; contradicts oofnd's no-third-party rule.
- **Drop `@"..."` entirely before oo-qps.** Thousands of sites for no behaviour; the constant-string
  class costs ~200 lines and the flip turns stragglers into compile errors.
- **C++ exceptions for `NSException` now.** Changes `@catch (id)` semantics (measurement 10).
- **Register the tiny-string class and hooks in `+load`.** Would clobber gnustep-base's while the
  two are linked together; the explicit `OOObjCInstallFloor()` cannot run by accident.
