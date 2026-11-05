# Move Foundation usage to oofnd, part 1

**Series:** step 6 of 24 · base `seriesb/005-typed-accessors` · next `seriesb/007-foundation-wave-2` **(gen)**

**Replays:** `series/008-foundation-wave-1` (old 8 of the master-based series) · 34.9k src, 1.2k tests, 0 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This is the first half of moving the game's own code off Foundation and onto `oofnd`, the C++20
library added in step 4. File by file, the `NSString`, `NSArray`, `NSDictionary`, `NSSet`,
`NSNumber` and `NSData` values inside a class become `std::string`, `std::vector`, `std::map`,
`std::optional`, `oo::PList` and `oo::Data`. The classes themselves are still Objective-C. A
selector that only one class declares takes and returns the C++ types, and its callers change at the
call expression only. A selector that several classes declare (a "shared" selector) keeps `id` at its
boundary for now and converts on the inside. #768's binding files are swept the same way as the rest.

Where a class has too many callers to adapt in the same change, it gets a `cxx_`-prefixed C++ API,
and a transitional `X+FoundationBridge.h/.mm` category (a bridge) keeps its old Foundation-typed
selectors working by forwarding to that API. This step adds 25 bridges; step 7 deletes 5 of them and
step 8 the rest. `Core/OOFoundationException.h` lets a handler catch both the game's `OOException`
and the `NSException`s gnustep-base itself still raises.

`oofnd` gains what the sweep needed:
- `oo::str` (`String.hpp`): path components, GNUstep's `%p` text, run-time format strings with `%@`
  and positional arguments, Unicode file decoding;
- `oo::PList` can carry live objects and single-precision reals;
- `oo::AutoreleaseScope` now drains newest first (see Behaviour changes).

## Why

Foundation (gnustep-base) can't be unlinked while game code still names its types, and the classes
can't become C++ (steps 9–13) while their interfaces are Foundation-typed. Changing the types first,
inside Objective-C, keeps each change small enough to check against the game's behaviour. The order
follows dependencies: maths and Core leaf utilities, then Materials, the OXP verifier, scripting,
entities and `Universe`. This step comes right after step 5, because many of these files had to stop
using the `oo_*ForKey:` extractors before their collections could become `oo::PList`.

## Behaviour changes

None in the game. Every new `oo::str` and `oo::PList` helper reproduces gnustep-base 1.31.1's
answers, captured from the real library and pinned in `tests/unit/oofnd/test_string_sweep.cpp`,
`test_string_format_runtime.cpp`, `test_unicode_file.cpp`, `test_unicode_file_decode.cpp` and
`test_plist_carrier.cpp`.

- `oo::AutoreleaseScope` (oofnd) releases its objects last-in-first-out, as libobjc2's pool (the
  game's real autorelease pool) does, where it used insertion order. No game code uses the scope yet.
  Pinned by `tests/unit/oofnd/test_objc_floor.mm` (`autoreleaseScopeDrainsInTheRuntimePoolsOrder`,
  new) and by `tests/unit/oofnd/test_ref.cpp` (`autoreleaseScopesNest`,
  `drainReleasesInOrderAndKeepsTheScopeOpen`, `drainingCascades`), whose expected orders this step
  changes from insertion order to LIFO.
- macOS only, not built or verified here: `+builtInPath` is kept (as `+cxx_builtInPath` plus its
  bridge), but it now goes through `oo::ResourcePaths`, which has no `OOLITE_MAC_COCOA_UI` branch.
  A Cocoa build no longer takes the resource path from the main bundle. Not pinned by a test.

## How to review

Start with `src/oofnd/README.md`, section "Migrating Foundation usage". Its type table (which C++
type replaces which Foundation type, and why a method never returns a bare `std::string` to a
possibly-nil receiver) is the rule every file follows. Then read one example per kind:
`src/Core/OOMesh.h/.mm` (instance variables and unique selectors: `std::optional` where nil and an
empty string differ, `oo::PList` for mixed configurations), `src/Core/Entities/OOPlanetEntity.h/.mm`
(shared selectors that keep `id` at the boundary) and `src/Core/OOColor.h` with
`OOColor+FoundationBridge.h/.mm` (the `cxx_` API and its bridge).

The rest is the same pattern, file by file. To spot-check a file, compare it on both branches
(`git diff seriesb/005-typed-accessors seriesb/006-foundation-wave-1 -- <file>`): each NS type
should map to the table's C++ type, and each caller hunk should be just a conversion at the call
(`oo::StdString(s)`, `oo::NSStringOrNil(...)`). Things to look for:

- a test against nil that became a test against an empty string where the two behaved differently
  (the README says to use `std::optional` there);
- a loop over a former `NSDictionary` or `NSSet` that now runs in `std::map` key order or in
  insertion order, where the order matters (first match wins, a random pick, text output);
- formatted strings that are no longer byte-identical;
- upstream's guards kept where the swept code has them: #756's `OO_DEBUG_MONITOR_ENABLED` (not
  `NDEBUG`) around `AI.mm`'s `debugContext` and the texture bridge's `+cachedTexturesByAge` and
  `+allTextures`, and `Universe.mm` importing `OOFoundationBridge.h` in every flavour. With these
  the deployment flavour (`./mk.sh build deployment`) compiles.

The bridge files are boilerplate and forward one line per method. The new `oofnd` code is in
`src/oofnd/String.hpp`, `PList.hpp` and `PListWriting.hpp`. `tests/source_paths.py` and the
`tests/gui` edits let the source-text guards find a file by its stem whatever its suffix
(`.m`, `.mm`, `.cpp`), so later renames don't break them. `tests/component/steps/world_steps.py`
spawns a fixed hull for each role so the component scenarios don't depend on a random ship draw.
`tests/unit/oofnd/test_thread.cpp` now waits for its detached thread without a time limit: the
bounded wait could return while the thread still used the test's stack frame.

## Verified **(gen)**

Not verified at this branch's tip (`1afa395c36`) yet: the last record is for `02c82ec354` (2026-11-02), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
