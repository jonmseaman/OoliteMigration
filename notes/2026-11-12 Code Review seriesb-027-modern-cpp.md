# Code review: `oolite-dev` at `seriesb/027-modern-cpp`

**Commit** `3732f6126` · **Date** 2026-11-12 · **Scope** all first-party C++ (534 files, about
232,700 lines), plus build, CI, tooling and test infrastructure · **No code was changed.**

These findings are proposals (CLAUDE.md rule 5). Each correctness finding says "suspected" and
names the test or tool that would settle it. Three verifiers then re-read the code behind every
High finding and every Medium correctness finding, tried to refute each one, and compared it with
upstream's Objective-C. Their verdicts are **holds on reading**, **partly**, **plausible** or
**refuted**. Per-finding detail, evidence snippets and coverage notes are in
`.agent-tmp/review-027/findings/` and `.agent-tmp/review-027/verify/`.

**In numbers.**

- **Findings.** 278 in all, as reported: 42 High, 116 Medium, 113 Low, 7 Nit.
- **Verification.** 104 findings (every High, plus Medium findings in correctness categories) were re-checked independently: 97 hold on reading, 5 partly, 2 plausible, 0 refuted.
- **Severity changes.** 28 were lowered by one level and none raised, leaving 32 High, 108 Medium, 131 Low and 7 Nit.
- **Origin of the verified findings.** 89 are inherited from upstream, **14 were introduced by the port** (§4.6), and 1 is unclear.


---

## 1. Summary

**Overall.** The port is in better shape than its size suggests.

- **Ownership core.** `oo::Ref` is a correct intrusive refcount, and the entity graph uses weak
  references almost everywhere it should. No `oo::Ref` cycle was found between ships, groups and
  AIs.
- **Deferred entity removal.** Removal is deferred and iteration works on snapshots, which
  removes the largest class of game-loop lifetime bugs.
- **Frame loop.** It uses a steady clock, skips late ticks instead of bursting, and clamps `dt`.
- **JS engine binding.** The QuickJS-ng binding has a written JSValue ownership contract and
  follows it.
- **Parsers.** The PList parsers were fuzzed against GNUstep.
- **Tests.** Almost every class has its own unit test.

**Where the risk is.**

1. **Input from outside the game is not validated, which is most of the serious findings.**
   Counts, indices and sizes read from OXP data, OXZ archives, save files, preferences and JS are
   used as array indices, loop bounds, divisors, format strings and paths without range checks.
   Most of these are inherited from upstream. Upstream Objective-C often failed softly (messages
   to nil, `NSRangeException`), while C++ now gives UB or crashes.
2. **Lifetime around script callbacks and message-to-nil.** These sites are:
   - functions that release an object and then return it;
   - collections indexed after a script callback may have changed them;
   - paired global state (time limiter, AI dispatcher, running-script stack) that an exception
     leaves unbalanced;
   - a few null dereferences where Objective-C's message to nil used to be a harmless no-op.
3. **A handful of data races** between worker threads and the main thread: the cache writer,
   planet texture generation, texture-loader flags, and the log sink.

**Readability.** This is the main drag on the code.

- **Trailing comments.** 6,032 comments trail code. 803 of them wrap into multi-line `//`
  columns, and 1,109 forced clang-format to break a statement. This is a mechanical artefact of
  an 80-column limit plus comment reflow, applied to Objective-C comments that used to sit to the
  right of the code.
- **Naming.** Four naming schemes coexist:
  - `OO`-prefixed globals: 292 types, 499 functions, 197 constants, 270 macros;
  - `namespace oo`, which is the foundation only;
  - unprefixed globals (`Entity`, `AI`, `Universe`);
  - the `cxx_` port prefix: 371 names, 2,310 uses.
- **Null-guard ternaries.** More than 3,000 `x != nullptr ? x->f() : T{}` ternaries, left over
  from message-to-nil, hide which pointers can really be null.

Both of Jon's readability items are real and measurable. Both have a safe, mostly mechanical fix.
The namespace move is a large diff, though, and it should be timed against upstream (§3.2).

### Top recommendations, in priority order

1. **Harden the input boundaries in one sweep (§4.1).** Do it with a small shared toolkit:
   - `oo::SaturatingCast<T>(double)`, which maps NaN to 0 and clamps;
   - `ClampCount`;
   - `IsAsciiDigit`;
   - a path-containment check;
   - "validate once at load".

   Apply it to the High findings, grouped by input surface: OXZ install, save load, OXP data
   files, preferences, the JS→PList converter. Most fixes are one to five lines, and each comes
   with a table test.
2. **Add an ASan+UBSan CI job and parser table tests (CX-05, C7-13, C9-27).** Several Highs
   (double frees, an unterminated buffer, out-of-bounds writes) are exactly what a sanitizer run
   catches on first contact. M7 will rewrite about 1,500 ownership lines and needs this safety
   net first.
3. **Fix the dangling-pointer cluster.** `addShipWithRole`/`addWreckageFrom` (C4-03),
   `launchEscort` (C5-02), the raw `scriptTarget` (C9-02), `sRunningStack` (C9-03) and the
   texture loader's `_data` (C3-06). Then move the factories to `oo::EntityHold` returns as part
   of M7. Work through C1-04's M7 hazard list before M7 starts.
4. **Make paired state exception-safe with RAII.** Cover:
   - the JS time limiter (C4-07, C9-08, C10-02, C10-04);
   - the AI dispatcher (C5-09);
   - the running-script stack (C9-03).

   Catch `std::exception` at the tick, async-task and Load-screen boundaries (C1-08, C7-03,
   C5-05). The guard type already exists (`OOJSFullNativeScope`, `oo::Finally`).
5. **Never index a collection after a script callback.** Erase by identity and snapshot before
   any callback: C5-03, C5-08, C5-14, C7-07, C4-06.
6. **Fix the data races:** C2-05, C3-03, C3-07, C1-09, C3-08.
7. **Move trailing comments above the code with a script.** Run it per directory. Prove each
   change is comment-only with a token diff. Add a ratchet check (CX-06, CX-12; §3.1).
8. **State null contracts instead of guarding everything.** Assert `UNIVERSE`, `PLAYER`, `gui`
   and `hud` once per function, and keep guards only where null is a real state (§3.3). This
   also surfaces the real nullables, as in C5-04 and C4-02.
9. **Namespaces: adopt the rule now and rename later (§3.2).**
   - Now: new code goes in `oo::<area>`, with no new `OO` globals and no new `cxx_` names. Pin
     the `typeid`-derived class names in log output (CX-07).
   - Later: rename area by area, after M7 and after upstream has seen the faithful series.
10. **Raise the tooling floor (§6).**
    - Turn on `-Wextra -Wpedantic -Wshadow`, with `-Werror` on Clang CI.
    - Run clang-tidy on the Windows test flavour too.
    - Turn on `bugprone-unchecked-optional-access` and `bugprone-exception-escape`.
    - Pin CI's clang-tidy version.

---

## 2. What is good (keep it this way)

- **Ownership core** (C1).
  - `Ref.hpp` uses relaxed increments and an `acq_rel` final decrement.
  - Weak references are zeroed before any destructor runs. An unbalanced resurrection in
    `willDispose()` aborts.
  - `WeakRef` identity is the control block, so address reuse never matches a dead object.
  - `test_ref.cpp` covers threads, drain cascades and address reuse.
- **Weak back-pointers in the entity graph** (C5, C6, C9, C10).
  - Every ship-to-ship reference is an `oo::WeakRef` or `WeakSet` (`ShipEntity.h:1500-1558`).
  - So are `AI::_owner`, group membership, dock locks, effect owners and beacon links.
  - JS entity wrappers hold `oo::WeakRef<Entity>`, so script handles cannot dangle.
  - `oo::EntityHold` is a small, correct RAII owner.
- **Entity lifecycle** (C4, C5).
  - `removeEntity` defers release to the end of the update (`Universe.cpp:5998-6002`).
  - Update, draw and queries iterate snapshots.
  - `zero_index = -1` stops the bubble sort resurrecting a removed entity.
- **Frame loop** (C8).
  - Deadlines are on `steady_clock`, and a late tick skips rather than bursting, so there is no
    spiral of death.
  - `dt` is clamped to 0.25 s.
  - There is one `AutoreleaseScope` per pass and per tick (`GameController.cpp:87-118, 446-528`).
  - Deferred calls erase themselves before running.
- **JS binding** (C9, C10).
  - The JSValue ownership rules are written once (`OOJSEngineCore.h:36-67`) and followed.
  - `OOJS_NATIVE_ENTER/EXIT` stops C++ exceptions at the C boundary.
  - `JS_SetInterruptHandler`, the memory limit and the stack limit are all set.
  - `argc` is checked before `argv[i]` everywhere traced.
  - Property dispatch is O(1) through an enum and a switch.
- **Parsers and I/O** (C1, C2, C7).
  - `PListXML.hpp` has bounds-guarded reads, found by a GNUstep differential fuzzer.
  - `like_ship` is resolved iteratively, and cycles terminate.
  - The string expander has both a recursion limit and a size budget.
  - The data cache validates its version, format and endian tag.
  - `FileSystem.hpp` uses only non-throwing overloads with `std::expected` and atomic writes, so
    saves are written atomically.
  - `Http.hpp` keeps TLS verification on, adds native CAs, a protocol whitelist and timeouts.
- **No per-frame by-name dispatch where upstream had it** (C3, C4, C6).
  - HUD dials and shader uniforms resolve to member pointers once.
  - By-name lookups are hashed.
  - A script checked every row of the 965-row by-name table, and all rows are consistent today.
- **Pinned external numbers** (C1, C7, C8). `static_assert`s pin every enum value that saves, JS
  or shaders see. The ten converted enum tables agree with their `OOEnumName` switches.
- **Upstream bugs fixed and documented.** Examples include the OXZ Vorbis per-read leak, the
  `loadPlayerIfRequired` use-after-free, setter fall-throughs in `OOJSPlayerShip`, the GNUstep
  over-reads, and the binary-search underflow (C3, C7, C8, C10).
- **Tests.**
  - There is a `test_<Class>.cpp` for nearly every class.
  - A file with no registered case fails (`oo_test.hpp:91-94`), and the GUI tier cannot pass
    vacuously.
  - `check_debug_monitor_guards.py` is a good template for further source checks (CX).
- **Rendering precision** (C4). Rendering is camera-relative in `HPVector`
  (`Universe.cpp:5374-5391`).

---

## 3. Readability

### 3.1 Comments after code (Jon's first item)

**How much** (CX-06, CX-12; whole first-party tree):

| Measure | Count |
|---|---:|
| `//` comments trailing code | **6,032** |
| …that wrap into a multi-line `//` column ("runs") | **803** (715 two-line, 65 three-line, 23 of 4–8 lines) |
| …that forced clang-format to break the *statement* (`x =` / `{};  // …`) | **1,109** (47 leave a lone `{};`) |
| …on the last line of a wrapped statement | 2,484 |
| `/*` opened after code and running onto later lines | 6 (plus 41 closed on the line; 371 `/*name=*/` argument comments are fine) |
| Comments still containing ObjC-era TABs | 1,126 |
| Block comments with zig-zag reflow / lists broken mid-item | 112 / ≥10 |

The densest files are `ShipEntity.cpp` (81 runs, 609 trailing), `Universe.cpp` (55/444),
`PlayerEntity.cpp` (45/408), `OOJSPlayerShip.cpp` (31/90) and `OOPListSchemaVerifier.h` (114
trailing comments per 1,000 lines). `Entities/` and `Universe.cpp` hold 45% of the runs.

**What it looks like:**

```cpp
// src/Core/Entities/StationEntity.cpp:1808 — the same note is pasted 12 times in 5 files
      const std::string grantedFormat = OO_DESC(
          "station-docking-clearance-granted-in-@-until-@");  // the format
                                                              // first, as
                                                              // Clang
                                                              // evaluates the …
```
```cpp
// src/Core/HeadUpDisplay.cpp:1849 — the comment split the condition at `->`
        if (reference != nullptr &&
            reference
                ->getIsStation())  // validateCompassTarget in PlayerEntity.m
                                   // changes COMPASS_BASIC_MODE target to the
                                   // main station when inside the planetary …
```
```cpp
// src/Core/AI.h:177 — initialisers orphaned on their own line
  std::optional<std::string> ownerDesc =
      {};  // describes the object this is the AI for; nullopt until it has an
           // owner
```
```cpp
// src/Core/Entities/OOVisualEffectEntity.h:58 — a block comment about the class *below*,
// glued to a forward declaration, with a TAB inside
class OOFlasherEntity; /*	The effect definition and script_info are
        oo::PLists (script_info null where it was nil); …
```

The exemplar is affected too. `OOColor.h:74-85` has its bullet list reflowed mid-item
("redColor" & / co.), and so does the test harness's own usage example (`oo_test.hpp:6-8`).

**Why it happens.** CX reproduced this on scratch input. `BasedOnStyle: Google` gives
`ColumnLimit: 80`, `ReflowComments` and `AlignTrailingComments`. A trailing comment counts
against the line, so clang-format first breaks the *code* to make room. It then reflows the
comment into a narrow column that is kept at the comment's start column. The Objective-C sources
had these comments at tab stops to the right of the code, with no column limit. clang-format
cannot move a comment to another line, and setting `ReflowComments: IndentOnly` still breaks the
code. The same text placed above the declaration formats as one line of code under one comment
line.

**Recommendation (CX §"Comment layout").**

- **Target convention.** A comment that explains code goes on its own line or lines above the
  statement, as `//` prose. A trailing comment is allowed only on a data member, an enumerator,
  an `#endif`/`#else`, a namespace closer or a `/*name=*/` argument, and only if it fits on the
  line. This matches Google ("Two spaces before end-of-line comments", used for short notes) and
  LLVM (comments are prose, placed before the code). Of the 6,032 trailing comments, 3,438 are 30
  characters or fewer and can stay where they are allowed.
- **Migration.** Use a script built on CX's lexer (`cx/comments.py`):
  - It finds each trailing comment and its run, joins the text, walks back to the statement's
    first line, and writes the comment above it, wrapped at 80.
  - It skips `\`-continued macros, and flags single-argument comments for hand review.
  - Then run clang-format, which rejoins the 1,109 forced breaks by itself.
  - Prove the change is comment-only: the comment-stripped token stream must be identical. Then
    build and run `tests/run.sh unit`.
  - Make one commit per directory, `Entities/` and `Universe.cpp` first, and add each to
    `.git-blame-ignore-revs`.
  - Fix the TAB and zig-zag block comments and the reflowed tables by hand in the same pass. There
    are a few hundred, not thousands.
- **Stop regressions.** Add `tests/check_comment_layout.py` to the `headers` suite, in the same
  shape as `check_debug_monitor_guards.py`. It fails on:
  - a trailing comment followed by a same-column comment line;
  - a comment on a forced code fragment;
  - a `/*` opened after code;
  - a TAB inside a comment.

  Start it as a per-file ratchet, then switch to zero tolerance.
- **Keep the formatter settings.** Keep `ColumnLimit: 80`. Raising it to 100 would fix only half
  the runs, and it reformats the whole tree.

### 3.2 `OO` prefixes instead of namespaces (Jon's second item)

**How much** (CX-08; code only, comments and strings excluded):

| Global scope | `OO…` | `kOO…` | `OO_…` | Unprefixed |
|---|---:|---:|---:|---:|
| Types | 292 | – | – | 66 (`Entity`, `ShipEntity`, `Universe`, `AI`, `Vector`, `Frame`…) |
| Free functions | 499 | – | – | 469 |
| Constants | 19 | 161 | 17 | ~875 (`k*` 135, CAPS 323, other 417) |
| Macros | 193 | 28 | 49 | 617 CAPS |
| In `namespace oo` | 57 types, 283 functions, 19 constants. 67 of these names are game code (`oo::ToShip`, `oo::EntityHold`, …). | | | |

- **Blast radius of a full rename.** It touches 12.4% of all lines (28,906 lines in 477 of 533
  files).
- **The `cxx_` prefix.** There are also 371 `cxx_` names (2,310 uses). `cxx_` marked "the C++
  twin of an ObjC function"; the twins are gone, so it is pure noise. Examples:
  `cxx_OOJSReportBadArguments` ×254 and `cxx_kOOMaterialDiffuseColorName`.
- **Mixed spellings.** `oo::Ref<OOColor>` and similar forms appear 1,213 times.
- **A reader can't tell from a name where it lives** (CG SF.20 "Use namespaces to express logical
  structure", NL.5; Google: "place code in a namespace").
- **Generic one-word globals.** A bare global `class AI` and `typedef struct {…} Frame` are the
  most collision-prone names (C5, C6).

**What must keep its spelling.** Nearly everything outside the code sees *strings*, not
identifiers: JS class and property names, log message classes, and plist, save and defaults keys.
Those are unaffected by a rename. **The one trap is CX-07:** entity, material, texture, loader and
sound descriptions print `<ClassName 0x…>` from `typeid` (`EntityHelpers.cpp:122-126`). Renaming
`OOPlanetEntity` or moving `ShipEntity` into a namespace therefore changes log and console text
that upstream also prints. `OOOXPVerifierStage::className()` and `OOScript::description()` have the
same problem (C2, C9).

**The cost against upstream.** The fork's `seriesb/*` stack is reviewed against the Objective-C
line by line, and later upstream fixes have to be ported across. A 12%-of-lines rename conflicts
with every step and every port. Phase 4p already defers "the mechanical modernisation sweeps …
after upstream has seen the faithful version", and this belongs with them. M7 rewrites the ~1,500
`oo::Ref<OO…>` lines anyway, so renaming first would make the two diffs conflict.

**Recommendation.** This is one plan, not a menu.

1. **Now (cheap).**
   - Pin the `typeid` descriptions with a literal `className()` or a namespace strip, plus a unit
     test (CX-07).
   - Put the rule for new code into 009-M8's naming check: new names go in `oo::<area>`, with no
     new `OO` globals and no new `cxx_`.
   - Move the two generic globals (`AI`, `Frame`) and the 67 game helpers already in `oo::` into
     their area namespaces when they are next touched.
2. **After M7, and after the series has been through upstream review (or the fork stops rebasing
   on it).** Rename area by area, leaves first, one PR per area. Each PR keeps
   `using OOColor = oo::Color;` aliases and adds an `<Area>Fwd.h`, because forward declarations
   can't name an alias. Do the rename with a lexer-based token rename (the prefix makes each name
   a unique token), verified by the build, `tests/run.sh all` and the JS API snapshot.
   - **Order:** `oo::` vocabulary and value types (`Color`, `Vector`, `HPVector`, `Quaternion`,
     `Matrix`) → `oo::sound` → `oo::gfx` → `oo::oxp`/`oo::debug` → `oo::data` → `oo::script` →
     `oo::ui` → `oo::entity` last. `Universe` and `GameController` wait for spec-003's game
     context.
   - **Rules:**
     - Types drop `OO`.
     - Unprefixed types gain only the namespace.
     - `kOOFoo` becomes `oo::<area>::kFoo`.
     - `cxx_` is dropped everywhere.
     - Configuration macros keep `OO_` (macros have no namespace).
     - `OO_LOG*`/`OO_DESC` stay macros, for lazy evaluation, but use `std::source_location`
       inside.
     - Other function-like macros become functions (`OOINLINE` → `inline`, `EXPECT` →
       `[[likely]]`, `MIN`/`MAX` → `std::`).
     - The category files `Foo+Bar.cpp` lose the `+` when their area moves.
3. **End.** Remove the aliases, and switch M8's check to fail on any global `OO` name.

Each chunk's findings file ends with a namespace sketch for that area: natural sub-namespaces,
strings that must stay, and obstacles.

### 3.3 Null-guard ternaries left over from message-to-nil

The C4–C10 reviewers counted more than **3,000** `x != nullptr ? x->f() : T{}` ternaries and
about 900 `if (x != nullptr) x->…` guards in their chunks (C5 alone has 818 and 376; C7 has 538,
523 of them on `UNIVERSE`).

They are a faithful translation of message-to-nil, but they do harm:

- **They bury the logic.** `OOOXZManager`'s two screens carry 90 `gui != nullptr` guards (C2-22).
- **They guard pointers already proven non-null.** `if (subentity != nullptr)` appears eight
  times after an early return (C5-13).
- **They sit beside unguarded dereferences of the same pointer**, so they protect nothing:
  `gui = (UNIVERSE ? getGui() : nullptr); gui->clear();` (C7-11, C8-23, C9-16).
- **They hide the few real nullables.** Those are exactly where the port has regressions: a null
  ship in `shipRestoredFromDictionary` (C5-04), a null shader program every frame (C4-02), and
  unguarded `UNIVERSE->descriptions()` (C2-10, C1-27).

**Recommendation.** Decide per pointer and per function:

- `UNIVERSE`, `PLAYER`, `gui` and `hud` are non-null during update, draw, input polling and
  script calls. Assert that once at the top, or bind a reference (`PlayerEntity& player =
  *PLAYER;`), and delete the inner guards.
- Keep an explicit check, ideally with an early return (LLVM "early exits"), only where null is a
  legitimate state: `dockedStation()`, `primaryTarget()`, missing textures, stale planet or sun
  wrappers.
- Do it one file at a time against the tests, alongside the comment hoist.

### 3.4 Other readability findings

- **History comments describe the Objective-C, not the code** (CX-19, C2-20, C3-22, C6-23,
  C9-20). The project rule is "describe the code as it is now".
  - Counts: "nil" in 1,173 comments; "(was …)/formerly" 145; "as before" 117; GNUstep 251; 541
    `-selector:` references; 49 `// [receiver msg]` quotes.
  - 19 "unmigrated" notes in C2 are now false.
  - 186 GPL banners, and 175 test banners, still name the `.m`/`.mm` file.
  - Keep upstream's own comments and the SpiderMonkey-compatibility explanations; drop the
    narration.
- **Planning-repo references in the game repo** (CX-18). These include "spec 009 research R14",
  "D3", "FR-014", "T031"/"T033" and `docs/architecture.md`: 9 in `src/`, about 12 in `tests/` and
  2 in `.clang-tidy`. The phase-4p exit gate's grep (`ADR-…|oo-…`) does not match them, so it
  reports success. Extend the gate.
- **Very long functions.**
  - 30 top-level functions are over 300 lines.
  - The longest:
    - `pollGuiArrowKeyControls` 1,202 lines and `pollFlightControls` 970
      (`PlayerEntityControls.cpp`);
    - `setCommanderDataFromDictionary` 786 (the save loader, which is also the riskiest code;
      C7-14);
    - `pollControls` 731 (`MyOpenGLView+Input.cpp`);
    - `ShipSetProperty` 726 (where C10-01's missing `break` hid);
    - `drawStarChart` 654;
    - `drawUniverse` 510;
    - `ShipEntity::update` 499.
  - `filterSortedLists` is ten pasted axis sweeps (C4-12).
  - `PlayerEntityControls.cpp` has 79 hand-rolled debounce latches (C8-14).
- **Copy-paste that has already drifted into bugs.** The rule this suggests: when you find a
  bug, check its siblings.
  - The market screen's "quantity in hold" loop has three copies, and only the unguarded one
    underflows (C7-01).
  - Ten station launchers; `launchEscort` is the one that releases instead of autoreleasing
    (C5-02, C5-12).
  - The four effect-texture singletons each re-register a reset client (C6-02).
  - Others:
    - the beacon protocol ×3 (C6-04);
    - Vector/HPVector (C1-24);
    - the mesh split ×3 (C1-19);
    - the planet and atmosphere generators (~550 lines; C3-14);
    - Vector3D/Quaternion JS (C9-22);
    - about 35 binding helpers (C10-10);
    - reputation ×3 (C7-22);
    - the paging blocks ×5 and pagination ×3 (C8-14, C8-15);
    - about 30 hand-written GUI screen transitions (C7-12);
    - `OoliteInfoString` ×7 (C2-18).
- **Macros.**
  - 1,182 `#define`s, about 496 of them numeric constants. `HeadUpDisplay.h` alone has 156, 27 of
    them unused (C4-18).
  - Two diverging `MIN`/`MAX`/`ABS` sets use GNU statement-expressions (C1-20, CX-13).
  - Elsewhere: `OOINLINE` (= `inline`, 326 uses), `EXPECT` (551 uses), the
    `OOJS_PROFILE_ENTER/NATIVE_ENTER` macros that hide braces and a `try` (C9-17), and a
    statement-expression in `OOJSID` (C9-19).
- **Test seams that make the code unreadable** (C4-09, C6-05, C10-12, CX-09).
  - `OO_UNIVERSE_VIRTUAL_MEMBERS` (160 KB in 218 lines, up to 1,035 columns) and
    `OO_ENTITY_VIRTUAL_MEMBERS` hide the real interface of `Universe` and `Entity`. They exist so
    that 15 tests can define a *second* `class Universe` or `class Entity`, which is an ODR
    violation that works only while the layouts match by hand.
  - 32 "qualified: the final overrider" calls switch off virtual dispatch to suit the same
    seams. Their comments are C10's largest source of multi-line trailing comments.
  - The fix is a real abstract interface (`UniverseServices`), which fits spec-003. Until then,
    add a GCC LTO `-Wodr` build of the core suite as a detector.

---

## 4. Correctness and safety

### The High findings after verification

| ID | Finding | Verdict | Origin |
|---|---|---|---|
| C1-01 | Removing a timer from the priority queue breaks heap order, so timers can fire late | HOLDS | upstream |
| C1-02 | `formatRuntime` copies an uninitialised 400-byte buffer when a format has a large precision | HOLDS | regression |
| C2-01 | OXZ extraction writes outside its folder ("zip-slip") | HOLDS | upstream |
| C2-03 | Description-file text is used as a raw printf format | HOLDS | upstream |
| C2-04 | A missing or short `digrams` crashes `%N` and `%R` | HOLDS | upstream |
| C2-06 | Equipment overrides throw on valid 5-element rows | HOLDS | upstream |
| C3-01 | The OXP `.dat` mesh parser trusts vertex indices and counts | HOLDS | upstream |
| C3-02 | An OXP `galaxy` value indexes `_probMaxGal` without a bounds check | HOLDS | upstream |
| C3-05 | `OOMultiTextureMaterial::unapplyWithNext` loops about 2⁶⁴ times when the next material uses more units | HOLDS | upstream |
| C4-01 | GUI resize trusts `hud.plist` sizes: fixed row arrays overflow, and a zero row height divides by zero | HOLDS | upstream |
| C4-02 | A missing or broken post-processing shader dereferences a null program every frame (upstream's message to nil returned 0) | HOLDS | regression |
| C4-03 | `addShipWithRole` (and similar) return a ship they have just freed when `addEntity` refuses it | HOLDS | upstream |
| C4-04 | `entityForUniversalID(MAX_ENTITY_UID)` reads one slot past `entity_for_uid` | HOLDS | upstream |
| C4-05 | A HUD `n_bars` of 0, negative or huge hangs the frame loop | HOLDS | upstream |
| C5-01 | A shipdata or save `missiles` value overruns `missile_list[32]` | HOLDS | upstream |
| C5-02 | `StationEntity::launchEscort` frees the escort, then hands the dangling pointer to JS | HOLDS | upstream |
| C5-03 | `dumpCargoItem` erases by an index that a script callback may have made stale | HOLDS | upstream |
| C5-04 | `shipRestoredFromDictionary` dereferences a null ship. Message-to-nil was a no-op here. | HOLDS | regression |
| C5-05 | An OXP AI plist can crash the game through two unchecked AI methods | HOLDS | upstream (spawn: worse here) |
| C6-01 | Sky star and nebula counts from system info: float→int UB, no upper bound, and a crash where upstream bailed out | HOLDS | regression |
| C7-01 | The market-info screen writes `quantityInHold[kNotFound]`, a heap underflow (the sibling site was fixed) | HOLDS | upstream |
| C7-02 | A saved trumble count goes into `trumbleCount` unchecked, then indexes `trumble[24]` out of bounds | HOLDS | upstream |
| C7-03 | A crafted save crashes the Load screen: `std::format("{:c}")` throws on values `%c` accepted | HOLDS | regression |
| C7-04 | Unvalidated save fields reach crash paths: `target_id` gives a negative array index, an empty `role_weights` gives `% 0` | HOLDS | upstream |
| C7-05 | More save fields give hangs and UB: equipment counts, `ship_clock`, contract times and fees, `galaxy_number`, `max_passengers` | HOLDS | upstream |
| C7-07 | `buySelectedShip` removes the wrong shipyard entry on page 2 and later, and its `erase` is unchecked after a JS hook | HOLDS | upstream |
| C8-02 | The OXZ Vorbis codec calls `unzClose` twice on every failure after `unzOpen64`; a corrupt `.ogg` inside an OXZ frees the handle twice | HOLDS | upstream |
| C8-03 | Key decoding: an unchecked scancode index, and `SDL_Keycode` truncated to `Uint16`, so non-character keys alias letters (the Menu key fires ECM) | HOLDS | upstream |
| C8-05 | The splash screen destroys its SDL surface twice on the default start-up path | HOLDS | upstream |
| C9-01 | Suspected: JS→PList conversion has no cycle, depth or size bound | HOLDS | upstream |
| C9-02 | Suspected use-after-free: `::scriptTarget` is a raw global `ShipEntity*` that dangles after the ship dies | HOLDS | upstream |
| C9-03 | Suspected: `sRunningStack` is left pointing into a dead stack frame when script load raises | HOLDS | upstream |

**Lowered by one level** after verification. In each case the mechanism holds, but the consequence is smaller than first stated. Typical reasons: a formal race with no lost update; a bounded read with no write; a narrow window; a latent configuration; data only the game itself writes; or an effect bounded by a later reset. The verifier tables give the reason for each. The findings are: C1-04, C1-06, C1-11, C1-13, C1-16, C2-02, C2-05, C2-10, C2-14, C3-03, C3-04, C3-07, C3-11, C3-12, C4-06, C4-13, C5-07, C5-14, C6-02, C7-06, C8-01, C8-04, C8-09, C8-16, C9-12, C10-01, C10-02, C10-06.

**Not fully confirmed:**
- C2-10 (partly): The four expander sites really dereference `UNIVERSE` unguarded (`OOStringExpander.cpp:913,1441-1442,1485,1509`), where upstream's message to nil was harmless. But `OOCharacter.cpp:171` cannot be reached with a null Universe (`speciesString` is nullopt then, `:165-169`), `OOConvertSystemDescriptions.cpp:224` is called only from `Universe.cpp:11253`, and no game path that runs the expander without a Universe was shown.
- C3-08 (plausible): The worker's local `task` Ref is released after `queueResult` (`OOAsyncWorkManager.cpp:382-389`), so if the main thread has already completed and dropped the task, the generator and its `_diffuseMap` (`OOCombinedEmissionMapGenerator.cpp:158`) can die on the worker. That needs the owning material destroyed while the task is in flight, inside a window of a few instructions; I could not show it happening in practice.
- C3-12 (partly): The typo is real: `wglGetProcAddress("glDeleteRenderbuffer")` (`OOOpenGLExtensionManager.cpp:771-772`) overwrites the trap default (`:206-207`) with null, as upstream `.m:649` does. But the claimed crash path, `Universe::deleteOpenGLObjects` (`Universe.cpp:11574-11584`), runs only from `~Universe` (`:274`, `:512`), which never runs in the game (see Notes).
- C4-13 (partly): The `OOLITE_MAC_COCOA_UI` branch was dropped (compare `Universe.m:6319-6324`), so `replacementIndex` is uninitialised unless `OOLITE_ESPEAK` is set (`Universe.cpp:7265-7271`). But `OOLITE_SPEECH_SYNTH` is defined only together with `OOLITE_ESPEAK` (`OOFoundation.h:114-117`, from `-DHAVE_LIBESPEAK` in `src/meson.build:23`), so no current build compiles the uninitialised read. It is latent.
- C5-07 (plausible): Approach queues are keyed by ID and re-resolved with `entityForUniversalID` (`DockEntity.cpp:316-334,408-419`). Pruning runs only on clearance, dock, abort or launch-queue events (`StationEntity.cpp:1691,2078,2348`; `DockEntity.cpp:1149`), and `PlayerEntity.cpp:7356` auto-docks without a prune first. A wrong ship needs the ID to wrap around about 2,049 allocations before the next prune, which is real but a narrow window. The out-of-bounds sub-point duplicates C4-04.
- C5-14 (partly): The nested `checkScannerIgnoringUnpowered()` does overwrite the member array mid-loop (`ShipEntityAI.cpp:576,589-597` → `ShipEntity.cpp:11820`). But it is the same scan, in the same frame, over unchanged positions; the new pod is `kCargo` and skipped (`ShipEntity.cpp:9234-9236`), so the outer loop normally sees an identical array. A skip or repeat needs a script callback that moves or cloaks ships, or rescans that same ship.
- C9-08 (partly): Confirmed: the pairs are manual. A non-OO exception is rethrown between Pause and Resume (OODebugMonitor.cpp:188-200), the catch-all at OOJavaScriptEngine.cpp:961-971 returns past `OOJSResumeTimeLimiter` (:967), and a skipped `OOJSStopTimeLimiter` (:180) leaves `sLimiterStartDepth` raised for good. Not confirmed: that a skipped Resume leaves the limiter "paused for good". The next depth-0 Start resets `sLimiterPauseDepth = 0` (:651-655), so the effect lasts only until the current top-level call ends.

**Corrections the verifiers made.** These are reflected in this report.
- C1-01: the proposed verify test passes today. Assert the heap invariant instead; a random-sequence check fails in 176 of 2,000 runs.
- C1-05: also needs round-trip float formatting in the XML writer.
- C3-12: the null pointer is never called in the game, because `~GameController` never runs.
- C5-07's off-by-one is C4-04.
- C5-08: the dropped ship is freed, not leaked.
- C7-05's equipment loop is at `PlayerEntity.cpp:12433`.
- C9-03: `version` and `identifier` are validated earlier; a non-string `author` or `license` still triggers it.
- C9-08: the paused-for-good half is bounded by the next top-level Start.
- C10-05: the concrete thrower is `adjustCargo` → `reserve` (`Universe.cpp:4793`).


### 4.1 Untrusted input, the dominant theme

Severities are as reported. **↓** marks a finding the verifier lowered by one level; the current
severities are in §11.

| Input | Findings (High unless marked) |
|---|---|
| **OXZ archives and downloads** | C2-01 zip-slip (`../` entries write anywhere); C2-02↓ unterminated 512-byte entry-name buffer, read at every start-up; C8-02 double `unzClose` on a corrupt `.ogg`; C2-07 (Med) manifest identifier joined into paths, then `removeItem`d; C2-14↓ (Med) HTTP status ignored, partial files kept; C1-30 (Low) status-code `int` overflow |
| **OXP data files** | C3-01 `.dat` mesh indices and counts unchecked (heap OOB write); C3-02 `galaxy` ≥ 8 overruns `_probMaxGal[8]`; C4-01 `hud.plist` GUI sizes overflow fixed row arrays or divide by zero; C4-05 `n_bars` 0 hangs the frame loop; C5-01 `missiles` > 32 overruns `missile_list`; C5-05 AI plist `performFlyRacepoints` `% 0` and `spawn: x -1`; C6-01 sky star counts (float→int UB, `bad_alloc`; a regression); C2-03 `descriptions.plist` text used as a raw `vsnprintf` format; C2-04 short `digrams` → `% 0`; C1-02 `%.500f` copies 400 bytes of uninitialised stack; C2-06 valid 5-element equipment overrides throw; C1-07, C1-16↓, C2-08, C2-09, C2-11, C3-16 (Med) |
| **Save files** (players share them) | C7-02 trumble count indexes `trumble[24]`; C7-03 `std::format("{:c}")` throws on government ≥128, which aborts at the Load screen (a regression); C7-04 `target_id = -5` → `cheapest[-5]`, empty `role_weights` → `% 0`; C7-05 huge equipment counts hang, and clock or fee doubles hit UB; C7-06↓ `player_save_name` with `../` escapes the save folder; C5-01 via `shipdata_overrides`. The trumble hash check is no defence, because it is computed from save fields an attacker controls (V2). |
| **Preferences and key config** | C8-04↓ joystick settings used as unchecked array indices; C8-03 unchecked scancode index into `keys[327]` and `SDL_Keycode` truncated to `Uint16` (the Menu key fires ECM; Caps Lock types `'9'`) |
| **OXP scripts (JS and legacy)** | C9-01 JS→PList conversion has no cycle, depth or size bound (`o.o = o`); C10-01↓ `entityPersonality` setter missing `break`; C10-02↓ predicates and scoop events run with no time limit, mid-iteration; C9-04, C9-10, C9-11, C9-12↓, C9-13, C10-08 (Med) |
| **Debug TCP console** | C9-05, C9-06, C9-14 (Med): re-entrant decoder, partial-send resend, no packet cap; C9-25 (Low) an OXP can set the console host |

**Recommendation.** Don't fix these one at a time with ad hoc checks. Add a small, tested toolkit
and use it at every boundary:

- **`oo::SaturatingCast<T>(double)`.** It maps NaN to 0 and clamps to `numeric_limits<T>`. It
  replaces the float→int UB at about 20 sites (C1-13, C2-11, C6-01, C7-05, C9-13, C10-08).
  `OOJSValueToInt32` already shows the checked form.
- **`ClampCount(v, lo, hi)` with a log line.** For OXP and save counts: missiles, `n_bars`, star
  counts, trumbles, equipment.
- **`IsAsciiDigit(char16_t)`** (C2-09), and a **path-containment check**: reject `..`, rooted
  and drive components, then a `weakly_canonical` prefix test (C2-01, C2-07, C7-06).
- **Depth and size budgets on every recursive converter or parser** (C9-01, C1-07, C2-08).
- **Validate once, where data enters.** Do it in `setCommanderDataFromDictionary`, split per save
  section (C7-14); in `setUpFromDictionary`; in the mesh parser; in `resizeTo`. Don't validate at
  every use.
- **Catch `std::exception` at the tick and async boundaries** (C1-08, C7-03). Upstream's
  `@catch` caught everything, but the port catches only `oo::Exception`, so any `std::` throw from
  bad data terminates the game.
- **Tests.** One table test per surface, feeding wrong type, negative, huge, NaN and empty
  values (C7-13, C9-27), plus the sanitizer job (CX-05).

### 4.2 Lifetime and ownership

- **Use after free or dangling pointer.**
  - C4-03 `addShipWithRole`/`addWreckageFrom` return a ship they just released when the universe
    is full.
  - C5-02 `launchEscort` hands JS a freed escort.
  - C9-02 the raw `::scriptTarget` global outlives dying ships.
  - C9-03 `sRunningStack` points into a dead stack frame after a manifest error.
  - C3-06 `OOTextureLoader::_data` dangles after a failed rescale.
  - C8-05 the splash surface is destroyed twice.
  - The fix pattern is the one the code already uses elsewhere: `oo::AutoreleaseEntity`,
    `EntityHold`, `WeakRef`.
- **Leaks that are deliberate parity with upstream's manual-refcounting leaks** (C7-09, C10-06,
  C2-13; C8-11 for sound sources).
  - `.leak()` and `leakRef()` reproduce leaks that no script, save or log can observe. Parity does
    not require them.
  - `OOShipRegistry::reload()` leaks the whole registry on every new game (C2-13).
- **M7 hazards to clear before the ownership migration** (C1-04, C1-03).
  - 158 `Ref<T>(raw)` constructions *retain*, whereas `shared_ptr<T>(raw)` *adopts*, so each
    would become a double delete under a mechanical swap.
  - There are 12 `Ref<T>(this)`.
  - `willDispose()` runs "while the object is whole".
  - `WeakRef == nullptr` is always false today.
  - C6-21's "objectless until `MadeEntity()`" two-step should become `oo::MakeEntity<T>()`.
- **Copyable polymorphic bases.**
  - `Entity` is copyable through `RefCounted`, and a copy would double-free `_jsSelf` (C6-13).
  - `OOMesh` has a defaulted copy over raw retained pointers (C3-18).
  - `OOCrosshairs` breaks the rule of three (C4-22).
  - Delete the copies (CG C.67, C.21).

### 4.3 Script re-entrancy and iteration

Scripts run synchronously from inside game logic, and several callers index a collection after
the callback has had a chance to change it:

- C5-03 `dumpCargoItem` erases by an index two JS events may have made stale;
- C5-08 the launch queue erases its front after launch scripts inserted at the front;
- C7-07 `buySelectedShip` ignores paging and erases after a `playerWillBuyNewShip` hook;
- C5-14 `scanned_ships` is overwritten while callers iterate it;
- C4-06 the shipyard's double removal drops the wrong ship;
- C10-02 a `filteredEntities` predicate runs while `sortedEntities` is being walked.

**Rule.** Snapshot before any callback, then erase by identity (`std::erase(v, x)` or `find_if`
on an id), never by a saved index.

### 4.4 Exception safety of paired global state

The pattern "pause … resume" or "push … pop" with a C++ exception in between appears at:

- the JS time limiter: C4-07 (`findOneEntityMatchingPredicate` returns without resuming, which
  switches the runaway-script watchdog off for the rest of the run), C9-08 (10+ sites), C10-02,
  C10-04;
- the AI dispatcher's recursion limiter and current-AI global (C5-09; 33 escapes and every AI
  message is refused);
- the running-script stack (C9-03);
- the mission callback (C10-16).

The RAII guard already exists (`OOJSFullNativeScope`, `oo::Finally`). Add
`OOJSTimeLimiterScope`, `OOJSPauseScope` and `RunningScriptScope`, and replace the manual pairs
(CG R.1, E.6). Related: 45 natives registered with only `OOJS_PROFILE_ENTER` let C++ exceptions
unwind through QuickJS (C10-05), and promise jobs are never run (C9-23).

### 4.5 Concurrency

- C2-05: the cache-writer worker assigns `_scheduledWrite` while the main thread reads it.
- C3-03: `textureWithGenerator()` reads the planet generator's size and seed after `enqueue()`
  while the worker changes them.
- C3-07: texture-loader bit-fields share one memory location with `_ready`, which planets poll
  every frame.
- C1-09: the log sink is replaced on the main thread while workers log, including from `atexit`.
- C3-08: a texture's last release, and its `glDelete*`, can happen on a worker thread.
- C1-28 (Low): `Notification.hpp` claims more thread safety than it provides.
- **Pattern:** set results and clear state in `completeAsyncTask()`, which runs on the main
  thread. Capture everything the main thread needs *before* `enqueue()`. Assert
  `isMainThread()` in GL-owning destructors.

### 4.6 Regressions introduced by the port

The verifiers compared every verified finding with `upstream/oolite/src`. 89 are inherited from
upstream, **14 were introduced by the port**, and 1 is unclear. Fix the port's own first, because
upstream players never saw them:

| ID | Sev (after verification) | What changed in the port |
|---|---|---|
| C1-02 | High | The new `formatRuntime` ignores `to_chars` failure: `%.500f` copies 400 bytes of uninitialised stack. |
| C4-02 | High | A null post-processing shader program is dereferenced every frame. Upstream's message to nil gave `glUseProgram(0)`. |
| C5-04 | High | `shipRestoredFromDictionary` writes through a null ship. Upstream's message to nil was a no-op. |
| C6-01 | High | Sky star counts: `vector::resize` throws `bad_alloc` where upstream checked `malloc` for NULL and bailed out. |
| C7-03 | High | `std::format("{:c}")` throws on save values that `%c` accepted, which aborts at the Load screen. |
| C1-05 | Medium | Modification times mix two clocks. The cache also writes reals with `%0.16g`, so values never round-trip on sub-µs filesystems and the cache is rebuilt. |
| C1-08 | Medium | Async tasks catch only `oo::Exception`, so a `std::` exception terminates the game. Upstream's `@catch (id)` caught everything. |
| C5-09 | Medium | The AI dispatcher's globals are left corrupt by a non-`OOException`. |
| C8-01 | Medium | Two `GameController`s exist, and the port's OXZ path ticks the wrong one. |
| C9-10 | Medium | An AI predicate body can break out of its wrapper. SpiderMonkey's `JS_CompileUCFunction` rejected this. |
| C1-06, C2-10, C4-13, C6-02 | Low | Date overflow; unguarded `UNIVERSE->descriptions()`; the dropped macOS speech branch, latent; reset clients re-registered with `new`. |

The C++ is also **worse than upstream** where upstream logic was the same but upstream raised a
catchable `NSRangeException`: the C++ `erase` past `end()` is silent UB (C5-03, C7-07), and
`spawn: x -1` now ends in `std::terminate` (C5-05).

---

## 5. Modern C++ and design

- **Value types should be values** (C1-14, C4-23, C6-22, C1-32). This is a critique of the
  exemplar.
  - `OOColor` is a 16-byte RGBA as a heap `RefCounted`, with an atomic count and a vtable.
    `redColor()` allocates on every call, and planets allocate two per frame inside an atmosphere.
  - Proposal: `struct OOColor { float r, g, b, a; }` with `constexpr` named colours and
    `static std::optional<OOColor> fromDescription(const PList&)`, plus a small boxed type only
    where a PList node or JS needs identity (CG C.10).
  - The same applies to `RouteElement` (one `oo::Ref` per relaxation step) and
    `OOProfilingStopwatch` (a heap object around a non-monotonic or millisecond clock; use
    `steady_clock`).
  - Because CLAUDE.md says "do it the way the exemplar does it", changing the exemplar changes
    what every later conversion copies. Decide this before M7.
- **Standard library replacements that fix bugs, not only style:**
  - `std::endian` and guarded `cpuid` for ARM (C1-18);
  - `file_clock::to_sys`, plus round-trip float formatting (`%.17g` or shortest `to_chars`) in
    the XML writer (C1-05, cache rebuilds; V1 found the writer half);
  - checked `to_chars` (C1-02);
  - `std::min`/`std::max` instead of the macros (C1-20);
  - `<numbers>` (65 `M_PI`);
  - `uint32_t` arithmetic in `legacy_random`, which gives identical bits (C1-12);
  - `std::array`/`std::span` for the GUI tab-stop arrays that copy 37 indeterminate values
    (C4-15);
  - a lazy dirty-flag matrix sync (C3-15).
- **Interfaces.**
  - `Entity::willDispose()` downcasts to its leaf classes (C6-07); use a template-method
    `teardown()`.
  - The 965-row by-name table restates what `decltype` knows. Generate rows from
    `Row<Part, &Method>` so they cannot drift (C6-03, C6-12).
  - `OOTypeEncodings.h` freezes libstdc++ object layouts in hand strings (C1-17).
  - Shader uniform types are matched by `@encode` strings (C3-24).
- **Headers and build time** (CX-11, CX-14, C5-23, C6-11, C10-19).
  - Each TU parses about 100k preprocessed lines through `OOFoundation.h`, which already pulls in
    all 17 of the T031 std headers. Trimming the per-header T031 blocks therefore saves almost
    nothing on its own.
  - A precompiled header for the std + oofnd umbrella, or splitting `OOFoundation.h`, is the
    lever. Then run `misc-include-cleaner`.
  - Other items: an `OOFoundation.h`↔`OOLogging.h` include cycle; `OOSoundSource.h` includes
    itself; 34 Core files include `src/SDL/MyOpenGLView.h`; `StationEntity.h` includes all of
    `Universe.h`.
- **Non-standard C++** (CX-01, C3-23, C6-18, C9-19).
  - GNU statement-expressions (`MIN`/`MAX`, `OOJSID`), C99 compound literals and the
    strict-aliasing `FREE` macro.
  - `-Wpedantic` finds them. They also block MSVC, which a Windows-native build will need
    (notes/2026-11-08).

---

## 6. Game design and per-frame performance

- **Timestep** (C8-09, C5-06, C4-16, C7-16).
  - The loop is one variable step per rendered frame, with no accumulator or interpolation
    (Fiedler). That is upstream's design, and the 0.25 s clamp plus skip-not-burst avoids the
    spiral of death, so keep it.
  - The defects inside it:
    - `dt == 0` while paused makes `considerFiringMissile` compute `3.2/dt` and convert `+inf`
      to `int` every frame for every armed attacker (C5-06);
    - chart and custom-view easing is per frame, not per second (C8-09);
    - trumble shake amplitude grows with fps (C7-16);
    - time acceleration is applied after the clamp (C4-16).
  - Return early on `dt <= 0` and scale easing by `dt`.
- **Two `GameController`s** (C8-01). `sharedController()` never returns main's instance. The
  second one re-seeds RANROT and has no view, and the port's Windows OXZ path ticks it. Fixing it
  changes the RNG sequence under some paths, so it needs Jon's call and a note for upstream.
- **Entity identity** (C5-07, C4-04).
  - Docking queues and close contacts are keyed by universal IDs, which get reused, so a new ship
    can inherit a dead one's place.
  - `entityForUniversalID(2149)` reads one slot past the table.
  - Key by `WeakRef`, or check that the ID and the `WeakRef` still agree.
- **Collision broad phase** (C1-15, C4-12, C6-06).
  - `CollisionRegion` allocates two entity-sized vectors per region per frame and rescans the
    whole list in each.
  - `filterSortedLists` is ten pasted sweeps.
  - The axis-list head is lost when it moves up. This is upstream's bug too, and it is pinned by
    `test_Entity.cpp:538-543`, so it needs Jon's ruling.
- **Hot-path copies.** These belong to spec-006, which should take these sites first:
  - charts copy up to ~770 dictionaries per frame (C4-11);
  - each HUD string costs two buffer copies (C2-16);
  - AI dispatch deep-copies the state machine per message (C5-11);
  - per-frame `getGlobalSettings()` copies and a route search in the countdown (C7-08);
  - every `worldScripts.X` copies all world scripts (C10-03);
  - equipment lookups through the registry for every fitted item (C5-10);
  - the input path builds a whole axis dictionary per frame (C8-10);
  - three GL matrix loads per push/mult/pop (C3-15).
- **Script boundary.**
  - Re-entrancy (§4.3) and the time limiter (§4.4).
  - A timer whose `this` has died leaks its closure graph, and liveness is tested by
    deep-converting `this` on every fire (C9-07).
  - NaN timer times break the priority queue (C9-09).
  - Removing a timer bubbles only down, so timers fire late (C1-01). Upstream shares this.
- **Precision and money** (C6-16, C7-15).
  - Absolute times exposed as `float` pass the 0.05 s arming delay after about 2^20 s of session
    time.
  - Rescue rewards go through `float`, which rounds the balance above 1.67M credits.
- **RNG coupling** (C7-17, C8-01). Trumble set-up and the second controller re-seed the shared
  game RNG, so cosmetic actions change later market and misjump rolls.
- **Rendering.**
  - `GL_UNPACK_ALIGNMENT` is never set (C3-04).
  - `OOMultiTextureMaterial::unapplyWithNext` loops about 2^64 times (C3-05).
  - A software window surface is taken on the GL window, and V-Sync is set on it rather than on
    the swap (C8-13).
  - `glDeleteRenderbuffers` is loaded under a misspelt name on Windows (C3-12).
  - The `USE_NEW_SHADER_SYNTHESIZER` path does not compile, so `OODefaultShaderSynthesizer`
    (1,675 lines plus a test) is unreachable (C3-13).

---

## 7. Build, tooling and tests

- **Warnings** (CX-01).
  - The game builds at meson's default `-Wall`, with no `-Wextra` and no `-Werror`, although
    CLAUDE.md rule 5 says `-Wall -Wextra` decide correctness.
  - On a 66-TU sample, `-Wextra -Wpedantic -Wshadow` cost about 11 sites, mostly the GNU macros;
    `-Wconversion` costs 173.
  - One warning already slipped through: a C-style cast in Windows-only `OOCPUInfo.cpp:196`.
  - Proposal: `warning_level=3` plus `-Wshadow` now, `-Werror` in the Clang CI jobs, and
    `-Wconversion` later together with `bugprone-narrowing-conversions`.
- **clang-tidy coverage** (CX-02, CX-03, CX-04, C4-21, C8-18).
  - Tidy runs once, on the Linux deployment flavour, so about 4,100 lines are never checked: 1,209
    Windows-only (including the debug console's socket code), 1,558 debug-only, 515 GraphViz, 420
    localisation tools. Add a tidy step to the Windows test job.
  - The fatal lists are wildcards (`bugprone-*`, `performance-*`) and CI's clang-tidy version is
    unpinned, so an LLVM bump can fail CI with no code change.
  - The checks that suit an Objective-C→C++ port are off: `bugprone-unchecked-optional-access`,
    `bugprone-exception-escape`, `clang-analyzer-*`.
- **Sanitizers** (CX-05). There is no option and no CI job, although spec 009 SC-005 requires "no
  new sanitizer reports". The pieces exist: `b_sanitize`, the suppressions file,
  `--no-suite openal`, `--nosound`. Add a `sanitize-windows` job before M7.
- **Unit tests run only on Windows** (CX-10). On a non-Windows host `tests/run.sh unit` may pass
  with zero tests. Make it fail on an empty suite, and ungate the pure-Python `headers` suite.
- **Test-harness hazards to carry into the GoogleTest move** (CX-15, spec-005).
  - Failures print the expression, not the values.
  - 1,044 compound `&&` checks.
  - Teardown "cases" depend on registration order.
  - 14 checks can never fail.
  - The JS scaffolding is copied into 28 files.
- **The smoke and component harnesses think they disable the splash screen, but don't** (V3, on
  C8-05).
  - They pass `--no-splash`, which `MyOpenGLView.cpp:415` does not recognise. The GUI conftest
    uses `-nosplash`.
  - So the smoke and component runs do show the splash, which frees its surface twice on every
    default start. An ASan smoke run would report it.
- **Other test findings** (CX-16, CX-17).
  - The `tests/unit/expander` and `sysdesc` harnesses are dead (wired nowhere) and give false
    assurance. Jon decides whether to wire them in or delete them.
  - The component and GUI tiers time on `time.time()` with fixed sleeps; use `time.monotonic()`
    and polled conditions.
- **Build flavours** (CX-20).
  - `debug=true` silently appends `-O0` after meson's `-O2`.
  - ThinLTO is hand-rolled, so each of the 74 core-test links redoes ThinLTO locally.
- **Platform readiness for phase 5** (C1-18, C3-12, C4-13, C6-20, C9-24).
  - aarch64 Linux hits `#error` in `OOCPUInfoEndian.h`, and the `cpuid` asm does not assemble on
    ARM.
  - `OOLITE_NATIVE_64_BIT` keys on an Apple header guard.
  - The macOS speech branch was dropped.
  - `OO_SHADERS 0` does not compile.
  - JS runtime limits are computed in 32-bit `long` on Windows.

---

## 8. Upstream bugs carried verbatim (a decision list for Jon)

These faithfully reproduce upstream behaviour, but each is a defect. For each one, fix it as a
recorded divergence with a test and report it upstream, or keep it with an "upstream quirk, kept:"
comment. Items that change gameplay or script-visible behaviour are marked ⚑.

- C1-01: timer heap removal. C1-11: `OOMatrixForRotation` formula and pivot search.
- C2-15: a list of eight resource and registry logic bugs (fix 2, 6 and 8 now).
- C3-17: shader-material detection; the specular map stored as diffuse.
- C4-08: frustum near and far planes not normalised (rendering only).
- C5-15: docking-lane `.x`/`.y` typos. C5-16 ⚑: NPC Q-mines overwritten during set-up, so fixing
  it makes NPCs start using Q-mines.
- C6-06 ⚑: the axis-list head (pinned by a test). C6-19: a plasma shot damaging two entities.
- C7-10 ⚑: `clearExtraGuiScreenKeys()` is a no-op. C7-15 ⚑: the worn-ship fuel-price integer
  division. C7-20: x taken from y, and wrong row colours.
- C8-06 ⚑: hat buttons numbered by stick. C8-07: joystick "previous" buttons do "next"
  (3 sites).
- C10-07 ⚑: `repeatCount = -5` gives 251 repeats; the escape-pod destination; the cargo clamp.
  C10-22: copy-pasted method names in error messages.

---

## 9. Already planned or decided (cross-references only)

Findings tagged `planned:` add specific sites or hazards to work that is already scheduled:

- **009-M7 (ownership):** C1-03, C1-04, C5-20, C6-21, C7-18, C10-16. Clear C1-04's hazard list
  first.
- **009-M8 (naming):** C2-26, C3-21, C9-26. Add the namespace rule for new code (§3.2).
- **009-M1 (malloc):** C3-06, C3-18, C4-22. Each is a specific bug inside the planned work.
- **spec-003 (global state):** C7-19, plus the ODR test seams (C4-09, CX-09), whose fix is spec-003's
  context object.
- **spec-005 (GoogleTest):** C7-13, C9-27, CX-15.
- **spec-006 (performance):** C2-17, C3-15, C4-11, C5-11, C7-08, plus the hot-path lists in C5-10,
  C8-10 and C10-03.
- **4p:** CX-01 (`-Wextra`), CX-10 (unit suites on every OS).

Findings tagged `decided:` report a concrete bug inside something Jon chose to keep. They do not
argue for redesign:

- the `oo::String` formatter (C1-02);
- `oo::fs` modification times (C1-05);
- PList nesting depth (C1-07);
- the `Log` enable check (C1-10);
- `legacy_random` signed overflow, where unsigned arithmetic gives identical bits (C1-12);
- the `Http` status parse (C1-30);
- the T031 header blocks (CX-11, which argues the trim cannot pay off without the umbrella
  change).

---

## 10. Suggested order of work

1. **Port regressions and High findings that hold on reading (§4).** Each fix is small, with a
   test, grouped into about five PRs by input surface: OXZ, save load, OXP data, preferences and
   input, scripts. Start with the regressions in §4.6.
2. **Safety net.** Add the ASan+UBSan job, tidy on the Windows test flavour, `-Wextra -Wpedantic
   -Wshadow` with `-Werror` on Clang, `bugprone-unchecked-optional-access`, and a pinned tidy
   version.
3. **RAII scope guards** for the limiter, AI dispatcher, running stack and mission callback.
   Catch `std::exception` at the boundaries.
4. **Before M7.** Clear C1-04's hazard list, fix `WeakRef == nullptr` (C1-03), add
   `EntityHold`-returning factories and `MakeEntity<T>`, and decide the `OOColor` value-type
   question for the exemplar.
5. **The comment hoist** (scripted, token-diff-verified, per directory) and its ratchet check.
   Then fix the banners, sweep the history comments, and extend the planning-reference gate.
6. **Null-contract cleanup**, file by file, alongside or right after the hoist.
7. **Naming.** The rule for new code and the `typeid` pin now; the area-by-area rename after M7
   and after upstream review.
8. **Drift refactors** (launchers, beacons, binding helpers, generators) and the spec-006 hot
   paths.
9. **Jon's decisions** on the §8 upstream-bug list; report the accepted ones upstream.

---

## 11. Finding index by area

Verdicts come from the verifier (V1 covers C1–C3, V2 C4–C7, V3 C8–C10). "—" means the finding was
not in the verification set: Low and Nit findings, and Medium findings in design, performance or
readability categories.

### C1: Foundation, core types, maths, spatial

34 findings: 2 High, 17 Medium, 14 Low, 1 Nit. Full text: `.agent-tmp/review-027/findings/C1.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C1-01 | High | correctness | Removing a timer from the priority queue breaks heap order, so timers can fire late | HOLDS; upstream | new |
| C1-02 | High | security | `formatRuntime` copies an uninitialised 400-byte buffer when a format has a large precision | HOLDS; regression | decided:oo::String |
| C1-03 | Medium | api | `weakRef == nullptr` is always false and `!= nullptr` always true | — | planned:009-M7 |
| C1-04 | Medium | lifetime | M7 hazards: `oo::Ref`'s semantics differ from `shared_ptr` where a mechanical swap is wrong | HOLDS (Medium→Low); unclear | planned:009-M7 |
| C1-05 | Medium | correctness | File modification times are not reproducible, so the data cache is sometimes rebuilt for no reason | HOLDS; regression | decided:oo::fs wrappers |
| C1-06 | Medium | ub | Converting a large date (network or plist input) to nanoseconds overflows int64 | HOLDS (Medium→Low); regression | new |
| C1-07 | Medium | security | Deeply nested plists overflow the stack, during parsing and when the PList is destroyed | HOLDS; upstream | decided:PList family |
| C1-08 | Medium | error-handling | A standard exception thrown in an async task terminates the game; upstream swallowed every exception | HOLDS; regression | new |
| C1-09 | Medium | concurrency | The log sink's global state is read on any thread while the main thread replaces it | HOLDS; upstream | new |
| C1-10 | Medium | performance | Checking whether a log class is enabled takes a global mutex; `OO_LOG_ERR/WARN` evaluate their arguments even when the class is off | — | decided:Log |
| C1-11 | Medium | correctness | `OOMatrixForRotation` is not a rotation, and the matrix inverse divides by zero for some exact rotations | HOLDS (Medium→Low); upstream | new |
| C1-12 | Medium | ub | Signed overflow in `legacy_random` on the galaxy-seed and save-checksum paths | HOLDS; upstream | decided:legacy_random |
| C1-13 | Medium | ub | `OOColor::setHue` converts a NaN or infinite hue to `int` | HOLDS (Medium→Low); upstream | new |
| C1-14 | Medium | design | The exemplar `OOColor` teaches heap-allocated value types and ObjC naming | — | new |
| C1-15 | Medium | performance | Collision and shadow passes allocate on the heap and rescan every entity per region, every frame | — | new |
| C1-16 | Medium | security | Octrees read back from the cache are used without checking their structure | HOLDS (Medium→Low); upstream | new |
| C1-17 | Medium | design | `OOTypeEncodings.h` freezes libstdc++ object layouts in hand-maintained strings | — | new |
| C1-18 | Medium | build | Apple Silicon and Linux ARM, the next targets, break on platform checks in this chunk | — | new |
| C1-19 | Medium | design | Three copies of the mesh-split code have drifted, and the geometry struct dangles if it is copied | — | new |
| C1-20 | Low | modern-cpp | Two different `MIN`/`MAX`/`ABS` macro sets; the include order picks one | — | new |
| C1-21 | Low | comments | Trailing comments and reflowed banners make headers hard to read | — | new |
| C1-22 | Low | comments | The GPL licence notice in `OOConstToString.cpp` has been corrupted | — | new |
| C1-23 | Low | build | `OOFunctionAttributes.h` and `OOFoundation.h` are mostly dead ObjC-era scaffolding | — | new |
| C1-24 | Low | design | Vector and HPVector are a hand-duplicated API with four naming styles | — | new |
| C1-25 | Low | correctness | NaN can leak into orientations and shadow levels from unguarded maths | — | new |
| C1-26 | Low | correctness | `OOCPUDescription` reads an uninitialised buffer on CPUs without brand-string leaves | — | new |
| C1-27 | Low | error-handling | `UNIVERSE` null checks are inconsistent in `OOConstToString.cpp` | — | new |
| C1-28 | Low | concurrency | `Notification.hpp` claims more thread safety than it provides | — | new |
| C1-29 | Low | performance | Every filter predicate repeats `dynamic_cast` 2–4 times per call; one predicate does not check for null | — | new |
| C1-30 | Low | security | The HTTP header callback can overflow `int` on a long status-code digit run | — | decided:Http |
| C1-31 | Low | performance | Octree hit tests clear a debug-only buffer on every call and keep results in file-scope globals | — | new |
| C1-32 | Low | modern-cpp | `OOProfilingStopwatch` is a heap object around a non-monotonic or millisecond clock | — | new |
| C1-33 | Low | comments | History comments and planning-repo references in game code | — | new |
| C1-34 | Nit | readability | Voxel helpers have external linkage | — | new |

### C2: Resources, caches, OXZ/OXP, registries, string expansion, OXP verifier

27 findings: 6 High, 12 Medium, 9 Low, 0 Nit. Full text: `.agent-tmp/review-027/findings/C2.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C2-01 | High | security | OXZ extraction writes outside its folder ("zip-slip") | HOLDS; upstream | new |
| C2-02 | High | ub | Unterminated zip entry-name buffer, read at every start-up | HOLDS (High→Medium); upstream | new |
| C2-03 | High | security | Description-file text is used as a raw printf format | HOLDS; upstream | new |
| C2-04 | High | ub | A missing or short `digrams` crashes `%N` and `%R` | HOLDS; upstream | new |
| C2-05 | High | concurrency | The cache writer thread races on `_scheduledWrite` | HOLDS (High→Medium); upstream | new |
| C2-06 | High | correctness | Equipment overrides throw on valid 5-element rows | HOLDS; upstream | new |
| C2-07 | Medium | security | Untrusted names are joined into paths without a containment check | HOLDS; upstream | new |
| C2-08 | Medium | security | Expansion output has no total bound ("billion laughs") | HOLDS; upstream | new |
| C2-09 | Medium | ub | `isdigit` is given UTF-16 units, and `%J`/`%G` truncate them to `char` | HOLDS; upstream | new |
| C2-10 | Medium | correctness | Unguarded `UNIVERSE->descriptions()` (the nil-message trap) | PARTLY (Medium→Low); regression | new |
| C2-11 | Medium | ub | Float-to-integer conversions of OXP numbers are not range-checked | HOLDS; upstream | new |
| C2-12 | Medium | security | The OXP verifier opens its log through a shell, using a name taken from the OXP folder | HOLDS; upstream | new |
| C2-13 | Medium | lifetime | `OOShipRegistry::reload()` leaks the whole registry on every reinit | HOLDS; upstream | new |
| C2-14 | Medium | error-handling | Download failures are mis-reported, and partial files are kept | HOLDS (Medium→Low); upstream | new |
| C2-15 | Medium | correctness | Upstream logic bugs are kept verbatim; a list for Jon | HOLDS; upstream | new |
| C2-16 | Medium | performance | Per-frame PList copies in the HUD text and chart drawing paths | — | new |
| C2-17 | Medium | performance | Each lookup re-opens every OXZ, and misses are never cached | — | planned:spec-006 |
| C2-18 | Medium | design | Seven copies of `OoliteInfoString`, each re-parsing `Info-gnustep.plist` | — | new |
| C2-19 | Low | naming | Selector names were truncated to their first keyword | — | new |
| C2-20 | Low | comments | Migration notes describe a bridge that no longer exists | — | new |
| C2-21 | Low | modern-cpp | Raw ownership and a hand-rolled LRU cache | — | new |
| C2-22 | Low | readability | 90 null-GUI guards make the OXZ screens unreadable | — | new |
| C2-23 | Low | comments | Trailing comments after code (Jon's first example), with examples | — | new |
| C2-24 | Low | ub | Schema-verifier error formats are unchecked, with `%u` given `size_t` | — | new |
| C2-25 | Low | design | OXP-verifier robustness and dead code | — | new |
| C2-26 | Low | naming | The bridge-era `cxx_` prefix survives on 26 functions and 6 macros | — | planned:009-M8 |
| C2-27 | Low | design | All of `OOOXZManager`'s state is public "for the unit test" | — | new |

### C3: Rendering: materials, textures, shaders, GL layer, meshes, drawables

25 findings: 5 High, 11 Medium, 9 Low, 0 Nit. Full text: `.agent-tmp/review-027/findings/C3.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C3-01 | High | security | The OXP `.dat` mesh parser trusts vertex indices and counts | HOLDS; upstream | new |
| C3-02 | High | security | An OXP `galaxy` value indexes `_probMaxGal` without a bounds check | HOLDS; upstream | new |
| C3-03 | High | concurrency | `textureWithGenerator()` reads the generator after `enqueue()`, while the worker mutates it | HOLDS (High→Medium); upstream | new |
| C3-04 | High | security | Texture upload assumes tight rows, but `GL_UNPACK_ALIGNMENT` is the default 4 | HOLDS (High→Medium); upstream | new |
| C3-05 | High | correctness | `OOMultiTextureMaterial::unapplyWithNext` loops about 2⁶⁴ times when the next material uses more units | HOLDS; upstream | new |
| C3-06 | Medium | lifetime | `OOTextureLoader::_data` dangles when a rescale or cube-map conversion fails | HOLDS; upstream | planned:009-M1 |
| C3-07 | Medium | concurrency | Texture loaders share unsynchronised state with the work threads | HOLDS (Medium→Low); upstream | new |
| C3-08 | Medium | lifetime | A texture can be destroyed on a work thread, and GL names have no thread-checked owner | PLAUSIBLE; upstream | new |
| C3-09 | Medium | correctness | `OODuplicatePixMap` uses the width as the height | HOLDS; upstream | new |
| C3-10 | Medium | correctness | The vertical stretch overflows its fixed-point coordinate for targets of about 8192 rows | HOLDS; upstream | new |
| C3-11 | Medium | lifetime | The planet and atmosphere generators leak through a strong cycle on cache hits | HOLDS (Medium→Low); upstream | new |
| C3-12 | Medium | correctness | Windows loads `glDeleteRenderbuffers` under a misspelt name, and failed loads become null | PARTLY (Medium→Low); upstream | new |
| C3-13 | Medium | design | Dead or uncompilable code paths with latent bugs | — | new |
| C3-14 | Medium | design | The planet and atmosphere generators duplicate ~550 lines, and the copies have drifted | — | new |
| C3-15 | Medium | performance | Per-frame draw path: matrix syncs, PList decoding, client arrays | — | planned:spec-006 |
| C3-16 | Medium | security | PNG loader: a clobbered `setjmp` local, the format chosen before transforms, no size limit | HOLDS; upstream | new |
| C3-17 | Low | correctness | Inherited copy-paste slips that change behaviour (each needs an upstream-parity decision) | — | new |
| C3-18 | Low | modern-cpp | Manual retain arrays, including a public defaulted copy constructor over raw retained pointers | — | planned:009-M1 |
| C3-19 | Low | error-handling | Shader error paths: info log over-read, a silent catch-all, and a duplicated `GetShaderSource` | — | new |
| C3-20 | Low | comments | Trailing and reflowed comments are hard to read (Jon's example 1) | — | new |
| C3-21 | Low | naming | `cxx_` migration prefixes and ObjC-style names on a pure C++ API | — | planned:009-M8 |
| C3-22 | Low | comments | History comments, planning-repo references, and a comment broken by a mechanical rename | — | new |
| C3-23 | Low | modern-cpp | Macros and C-isms: no-op macros, aliasing in `FREE`, compound literals, `M_PI` | — | new |
| C3-24 | Low | design | Shader uniform types are matched by `@encode` strings | — | new |
| C3-25 | Low | correctness | `removeFromCaches()` drops a newer texture's live-cache entry | — | new |

### C4: Universe, HUD, GUI

25 findings: 6 High, 7 Medium, 11 Low, 1 Nit. Full text: `.agent-tmp/review-027/findings/C4.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C4-01 | High | security | GUI resize trusts `hud.plist` sizes: fixed row arrays overflow, and a zero row height divides by zero | HOLDS; upstream | new |
| C4-02 | High | lifetime | A missing or broken post-processing shader dereferences a null program every frame (upstream's message to nil returned 0) | HOLDS; regression | new |
| C4-03 | High | lifetime | `addShipWithRole` (and similar) return a ship they have just freed when `addEntity` refuses it | HOLDS; upstream | new |
| C4-04 | High | ub | `entityForUniversalID(MAX_ENTITY_UID)` reads one slot past `entity_for_uid` | HOLDS; upstream | new |
| C4-05 | High | security | A HUD `n_bars` of 0, negative or huge hangs the frame loop | HOLDS; upstream | new |
| C4-06 | High | correctness | Shipyard generation divides by zero when every ship fails its conditions, and its double removal drops the wrong ship | HOLDS (High→Medium); upstream | new |
| C4-07 | Medium | correctness | `findOneEntityMatchingPredicate` returns without resuming the JS time limiter, which switches off the runaway-script watchdog | HOLDS; upstream | new |
| C4-08 | Medium | correctness | `defineFrustum` scales the near and far planes by their length instead of normalising them | HOLDS; upstream | new |
| C4-09 | Medium | design | The test seam is a second `class Universe` that must match the game's vtable, written as an unreadable macro | — | new |
| C4-10 | Medium | readability | Emulating "a message to nil" buries the logic, and some guards mislead | — | new |
| C4-11 | Medium | performance | Per-frame deep `PList` copies and heap colours on the charts and the HUD | — | planned:spec-006 |
| C4-12 | Medium | readability | `filterSortedLists` is about 470 lines of ten pasted sweeps | — | new |
| C4-13 | Medium | ub | `speakWithSubstitutions` reads an uninitialised `replacementIndex` on non-eSpeak speech builds (the macOS branch was dropped) | PARTLY (Medium→Low); regression | new |
| C4-14 | Low | comments | Reflowed trailing comments: the worst cases | — | new |
| C4-15 | Low | ub | `OOGUITabSettings` arrays are filled to 3 of 40 entries and then copied whole | — | new |
| C4-16 | Low | game-loop | Timestep and update-order notes for `Universe::update` | — | new |
| C4-17 | Low | build | Header weight and the forwarding shims | — | new |
| C4-18 | Low | modern-cpp | Macro constants: unused ones, a trailing `;`, and a width/height mix-up | — | new |
| C4-19 | Low | readability | Dead and disabled code | — | new |
| C4-20 | Low | comments | Planning-repo references and history comments in game source | — | new |
| C4-21 | Low | build | C-style casts survive inside `OOGL(...)` arguments on the Windows build | — | new |
| C4-22 | Low | lifetime | Specific hazards inside the remaining `malloc` work: crosshairs and the cascade blip | — | planned:009-M1 |
| C4-23 | Low | modern-cpp | Small value types are heap refcounted objects (`RouteElement`, transient `OOColor`) | — | new |
| C4-24 | Low | error-handling | Smaller hardening gaps | — | new |
| C4-25 | Nit | naming | Typos in identifiers and comments | — | new |

### C5: Ships, AI, stations, docks

24 findings: 5 High, 10 Medium, 8 Low, 1 Nit. Full text: `.agent-tmp/review-027/findings/C5.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C5-01 | High | security | A shipdata or save `missiles` value overruns `missile_list[32]` | HOLDS; upstream | new |
| C5-02 | High | lifetime | `StationEntity::launchEscort` frees the escort, then hands the dangling pointer to JS | HOLDS; upstream | new |
| C5-03 | High | ub | `dumpCargoItem` erases by an index that a script callback may have made stale | HOLDS; upstream | new |
| C5-04 | High | error-handling | `shipRestoredFromDictionary` dereferences a null ship. Message-to-nil was a no-op here. | HOLDS; regression | new |
| C5-05 | High | ub | An OXP AI plist can crash the game through two unchecked AI methods | HOLDS; upstream (spawn: worse here) | new |
| C5-06 | Medium | game-loop | `dt == 0`, the normal case while paused, hits UB; large `dt` breaks the integration | HOLDS; upstream | new |
| C5-07 | Medium | lifetime | Docking queues and close contacts are keyed by universal IDs, which wrap and get reused | PLAUSIBLE (Medium→Low); upstream | new |
| C5-08 | Medium | correctness | `DockEntity::update` removes the front of the launch queue after launch scripts may have changed it | HOLDS; upstream | new |
| C5-09 | Medium | error-handling | `AI::reactToMessage` is not exception-safe: a non-OOException leaves the global dispatcher state corrupt | HOLDS; regression | new |
| C5-10 | Medium | performance | Per-frame allocations and registry lookups in the ship update and behaviour path | — | new |
| C5-11 | Medium | performance | AI dispatch deep-copies PList state machines and re-parses actions on every message | — | planned:spec-006 |
| C5-12 | Medium | design | Ten copy-pasted station launchers have drifted | — | new |
| C5-13 | Medium | readability | Null-guard theatre from the nil-messaging translation hides the real null contracts | — | new |
| C5-14 | Medium | lifetime | `scanned_ships` is overwritten while callers iterate it | PARTLY (Medium→Low); upstream | new |
| C5-15 | Low | correctness | Three suspected copy-paste typos, probably inherited from upstream | — | new |
| C5-16 | Medium | correctness | Suspected: an NPC's `has_energy_bomb` Q-mine is overwritten during set-up | HOLDS; upstream | new |
| C5-17 | Low | comments | The worst trailing and reflow-mangled comments (metrics above) | — | new |
| C5-18 | Low | readability | ObjC history and two-phase init survive in names and comments | — | new |
| C5-19 | Low | modern-cpp | 99 macros, several unsafe | — | new |
| C5-20 | Low | lifetime | Manual retain/release protocols where `EntityHold` exists | — | planned:009-M7 |
| C5-21 | Low | design | Dead and broken code | — | new |
| C5-22 | Low | lifetime | The JS predicate cache is never freed, so the runtime is abandoned at shutdown | — | new |
| C5-23 | Low | build | Heavy, order-dependent headers | — | new |
| C5-24 | Nit | readability | Implicit `switch` fallthroughs without `[[fallthrough]]` | — | new |

### C6: Entity base, by-name dispatch, effects and stellar bodies

23 findings: 1 High, 8 Medium, 14 Low, 0 Nit. Full text: `.agent-tmp/review-027/findings/C6.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C6-01 | High | security | Sky star and nebula counts from system info: float→int UB, no upper bound, and a crash where upstream bailed out | HOLDS; regression | new |
| C6-02 | Medium | lifetime | Texture reset clients are re-registered with `new` every time the texture is rebuilt | HOLDS (Medium→Low); regression | new |
| C6-03 | Medium | design | The 3,000-line by-name table repeats facts the compiler already knows, and nothing checks them | — | new |
| C6-04 | Medium | design | The beacon protocol is copied three times, with three-way `dynamic_cast` dispatch around it | — | new |
| C6-05 | Medium | design | `EntityVirtualMembers.h` exists so that a test can define a second `class Entity`, which is an ODR violation | — | new |
| C6-06 | Medium | correctness | The axis lists lose their head when the head moves up (suspected; upstream shares it; pinned by a test) | HOLDS; upstream | new |
| C6-07 | Medium | design | `Entity::willDispose()` downcasts to its leaf classes to run their teardown | — | new |
| C6-08 | Medium | readability | About 340 nil-messaging guards, many provably redundant, and not consistent enough to protect anything | — | new |
| C6-09 | Medium | comments | Comments trail code or are reflow-mangled, worst in the root entity's interface | — | new |
| C6-10 | Low | performance | Per-frame copies and lookups in effect update and draw | — | new |
| C6-11 | Low | build | Heavy or unused includes in widely included entity headers | — | new |
| C6-12 | Low | correctness | Facade rows and the object-names table disagree on two names: responds-to says yes, the call says "does not respond" | — | new |
| C6-13 | Low | modern-cpp | Entity is a copyable polymorphic base; one destructor lacks `override`; `init()` is hidden by unrelated `init()`s | — | new |
| C6-14 | Low | ub | ObjC nil semantics kept literally give indeterminate values and a colliding sentinel | — | new |
| C6-15 | Low | lifetime | `collidingEntities` holds strong references and is not cleared when an entity leaves the universe | — | new |
| C6-16 | Low | game-loop | Absolute times exposed as `float` are used in game logic | — | new |
| C6-17 | Low | readability | Dead code: unreachable branches, a dead virtual, and commented-out ObjC rewritten by the converter | — | new |
| C6-18 | Low | modern-cpp | C idioms: mutable statics, macros, compound literals and four copies of the texture-singleton pattern | — | new |
| C6-19 | Low | correctness | A plasma shot that hits two entities in one frame damages both and spawns two bursts (suspected upstream bug) | — | new |
| C6-20 | Low | build | `OOPlanetEntity::setTextureFileName` doesn't compile with `OO_SHADERS 0` | — | new |
| C6-21 | Low | lifetime | Entities are "objectless" until a second call, and a forgotten `MadeEntity` is silently dropped | — | planned:009-M7 |
| C6-22 | Low | performance | The exemplar `OOColor` is a heap object, so value-like colours allocate in hot paths | — | new |
| C6-23 | Low | comments | ObjC narration and history comments describe what the code used to be | — | new |

### C7: Player core, save/load, contracts

26 findings: 7 High, 7 Medium, 11 Low, 1 Nit. Full text: `.agent-tmp/review-027/findings/C7.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C7-01 | High | ub | The market-info screen writes `quantityInHold[kNotFound]`, a heap underflow (the sibling site was fixed) | HOLDS; upstream | new |
| C7-02 | High | security | A saved trumble count goes into `trumbleCount` unchecked, then indexes `trumble[24]` out of bounds | HOLDS; upstream | new |
| C7-03 | High | security | A crafted save crashes the Load screen: `std::format("{:c}")` throws on values `%c` accepted | HOLDS; regression | new |
| C7-04 | High | security | Unvalidated save fields reach crash paths: `target_id` gives a negative array index, an empty `role_weights` gives `% 0` | HOLDS; upstream | new |
| C7-05 | High | security | More save fields give hangs and UB: equipment counts, `ship_clock`, contract times and fees, `galaxy_number`, `max_passengers` | HOLDS; upstream | new |
| C7-06 | High | security | The save name from a loaded save goes into autosave and save paths unsanitised (path traversal) | HOLDS (High→Medium); upstream | new |
| C7-07 | High | correctness | `buySelectedShip` removes the wrong shipyard entry on page 2 and later, and its `erase` is unchecked after a JS hook | HOLDS; upstream | new |
| C7-08 | Medium | performance | Per-frame waste in the flight path | — | planned:spec-006 |
| C7-09 | Medium | lifetime | Upstream's retain leaks are reproduced on purpose | HOLDS; upstream | new |
| C7-10 | Medium | correctness | `clearExtraGuiScreenKeys` never removes anything (a no-op preserved behind the global JS function `clearExtraGuiScreenKeys()`) | HOLDS; upstream | new |
| C7-11 | Medium | readability | Mechanical nil-guards: 538 `p != nullptr ? p->f() : default` ternaries that do not make the code safe | — | new |
| C7-12 | Medium | design | GUI screen transitions are written by hand in about 30 places, and the notifications have drifted | — | new |
| C7-13 | Medium | tests | There are no tests of the save round-trip or of malformed saves | — | planned:spec-005 |
| C7-14 | Medium | design | Functions over 300 lines, nested up to 6 deep | — | new |
| C7-15 | Low | correctness | Money arithmetic goes through `float`, and the fuel-rate integer division is preserved | — | new |
| C7-16 | Low | game-loop | Frame-rate-dependent trumble animation and game-over fade | — | new |
| C7-17 | Low | design | Every trumble set-up reseeds the global game RNG | — | new |
| C7-18 | Low | lifetime | Sound sources are raw owning statics with manual `release()` | — | planned:009-M7 |
| C7-19 | Low | lifetime | Lifetimes of `gOOPlayer`, the second-player path and `targetDockStation` | — | planned:spec-003 |
| C7-20 | Low | correctness | Copy-paste slips preserved from upstream | — | new |
| C7-21 | Low | modern-cpp | Assert hygiene and C idioms | — | new |
| C7-22 | Low | design | Duplicated reputation and key-description code | — | new |
| C7-23 | Low | comments | Trailing and reflowed comments, history notes and stale comments | — | new |
| C7-24 | Low | naming | Global namespace pollution and empty shim headers | — | new |
| C7-25 | Low | api | Getters with side effects | — | new |
| C7-26 | Nit | readability | The release-build stage macro and a shadowed loop counter | — | new |

### C8: Platform (SDL), game loop, input, sound

23 findings: 5 High, 11 Medium, 7 Low, 0 Nit. Full text: `.agent-tmp/review-027/findings/C8.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C8-01 | High | correctness | `sharedController()` is not the application's controller: two `GameController`s exist, and the OXZ path ticks the wrong one | HOLDS (High→Medium); regression | new |
| C8-02 | High | security | The OXZ Vorbis codec calls `unzClose` twice on every failure after `unzOpen64`; a corrupt `.ogg` inside an OXZ frees the handle twice | HOLDS; upstream | new |
| C8-03 | High | correctness | Key decoding: an unchecked scancode index, and `SDL_Keycode` truncated to `Uint16`, so non-character keys alias letters (the Menu key fires ECM) | HOLDS; upstream | new |
| C8-04 | High | security | Joystick settings from the preferences file are used as unchecked array indices | HOLDS (High→Medium); upstream | new |
| C8-05 | High | ub | The splash screen destroys its SDL surface twice on the default start-up path | HOLDS; upstream | new |
| C8-06 | Medium | correctness | Joystick hats: the hat index is unchecked, and hat buttons are numbered by stick instead of by hat | HOLDS; upstream | new |
| C8-07 | Medium | correctness | Joystick "previous" buttons perform "next" (inverted condition at 3 sites), and prime-previous cannot be bound at all | HOLDS; upstream | new |
| C8-08 | Medium | error-handling | Vorbis full-buffer decode mixes bytes with frames, and a failed `ov_open_callbacks` leaks the `FILE*` | HOLDS; upstream | new |
| C8-09 | Medium | game-loop | Variable timestep coupled to render rate, with frame-rate-dependent easing and private wall clocks in the input code | HOLDS (Medium→Low); upstream | new |
| C8-10 | Medium | performance | Per-frame allocation and string-keyed lookups in the flight input path and the no-sound path | — | new |
| C8-11 | Medium | lifetime | Sound sources are never removed from the playing set when they finish, and `play()` with no free channel adds them anyway | HOLDS; upstream | new |
| C8-12 | Medium | correctness | HDR snapshots are written with the wrong row stride, and a failed `SDL_GetWindowSurface` is dereferenced | HOLDS; upstream | new |
| C8-13 | Medium | design | A software window surface is taken on the OpenGL window, and V-Sync is requested on that surface, not on the GL swap (suspected) | — | new |
| C8-14 | Medium | readability | PlayerEntityControls: 300- to 1200-line functions, 79 hand-rolled debounce latches, and paging blocks copied 5× that have already drifted | — | new |
| C8-15 | Medium | design | Key- and stick-mapper data is hand-coded, and the pagination and custom-equipment encodings are duplicated | — | new |
| C8-16 | Medium | ub | `main` indexes `result[-1]` when `readlink("/proc/self/exe")` fails | HOLDS (Medium→Low); upstream | new |
| C8-17 | Low | lifetime | Shutdown and teardown contracts are fragile | — | new |
| C8-18 | Low | build | Windows-only code escapes the cast and lint gates, and Windows paths mix ANSI with UTF-8 | — | new |
| C8-19 | Low | design | Dead code, and a header chain that pulls SDL3 and GL into 29 translation units | — | new |
| C8-20 | Low | comments | Trailing comments have drifted from their code, and one sits on the wrong member | — | new |
| C8-21 | Low | design | `snapShot` changes the process working directory, and every `ResourcePaths::current()` derives its paths from the working directory | — | new |
| C8-22 | Low | design | SDL joystick manager: string-keyed id map, no hot-plug, and gamepad events reinterpreted as joystick events | — | new |
| C8-23 | Low | readability | Message-to-nil translations obscure intent and are applied inconsistently | — | new |

### C9: JS engine core, legacy scripts, debug console

28 findings: 3 High, 11 Medium, 13 Low, 1 Nit. Full text: `.agent-tmp/review-027/findings/C9.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C9-01 | High | security | Suspected: JS→PList conversion has no cycle, depth or size bound | HOLDS; upstream | new |
| C9-02 | High | lifetime | Suspected use-after-free: `::scriptTarget` is a raw global `ShipEntity*` that dangles after the ship dies | HOLDS; upstream | new |
| C9-03 | High | lifetime | Suspected: `sRunningStack` is left pointing into a dead stack frame when script load raises | HOLDS; upstream | new |
| C9-04 | Medium | security | Pre-"sanitized" conditions bypass the legacy-script whitelist | HOLDS; upstream | new |
| C9-05 | Medium | concurrency | TCP console: the send retry services input, and the stream decoder is not re-entrant | HOLDS; upstream | new |
| C9-06 | Medium | correctness | A partial `send()` followed by a retry resends from byte 0 | HOLDS; upstream | new |
| C9-07 | Medium | lifetime | Timer: `this` is deep-converted on every fire, and a timer whose `this` has died leaks its closure graph | HOLDS; upstream | new |
| C9-08 | Medium | error-handling | Manual time-limiter and running-script pairs are not exception-safe | PARTLY; upstream | new |
| C9-09 | Medium | correctness | NaN/Infinity timer times break the timer priority queue | HOLDS; upstream | new |
| C9-10 | Medium | security | `OOJSFunction::initWithName` evaluates a concatenated body that can break out, and its handles go stale on reset | HOLDS; regression | new |
| C9-11 | Medium | security | The interrupt handler and error reporter read the script name through JS getters | HOLDS; upstream | new |
| C9-12 | Medium | security | Cached QuickJS bytecode is executed as trusted input | HOLDS (Medium→Low); upstream | new |
| C9-13 | Medium | ub | Out-of-range script and plist numbers are converted to integers (UB) | HOLDS; upstream | new |
| C9-14 | Medium | design | The TCP decoder emulates CoreFoundation, with mismatched varargs and no packet-size cap | — | new |
| C9-15 | Low | performance | The atom cache grows without bound | — | new |
| C9-16 | Low | readability | Half-guarded nil-messaging ternaries (94), some of them still dereferencing | — | new |
| C9-17 | Low | readability | The `OOJS_PROFILE_ENTER/NATIVE_ENTER` macros hide braces and a `try` | — | new |
| C9-18 | Low | comments | Trailing and reflow-mangled comments (469 trailing, 62 multi-line runs, ~254 ragged lines) | — | new |
| C9-19 | Low | modern-cpp | Non-standard GNU extensions in core macros | — | new |
| C9-20 | Low | comments | History comments, stale `.m` names, planning references and dead stubs | — | new |
| C9-21 | Low | performance | `OOStandardsSetup()` never caches its result | — | new |
| C9-22 | Low | design | Vector3D and Quaternion are near-duplicates that have drifted; the POC copies the engine | — | new |
| C9-23 | Low | correctness | Promise jobs are never run | — | new |
| C9-24 | Low | build | Runtime limits are computed in `long` and the JS stack limit is unchecked | — | new |
| C9-25 | Low | security | The debug console's host comes from merged OXP config | — | new |
| C9-26 | Low | naming | `cxx_` prefixes, and `JS*` free functions that look like QuickJS API | — | planned:009-M8 |
| C9-27 | Low | tests | No tests for the untrusted-input parts of this chunk | — | planned:spec-005 |
| C9-28 | Nit | modern-cpp | C idioms in small tables | — | new |

### C10: JS object bindings

22 findings: 2 High, 11 Medium, 8 Low, 1 Nit. Full text: `.agent-tmp/review-027/findings/C10.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| C10-01 | High | correctness | `ship.entityPersonality` setter falls through into `hyperspaceSpinTime` | HOLDS (High→Medium); upstream | new |
| C10-02 | High | security | Script code re-entered from a paused-limiter native runs with no time limit | HOLDS (High→Medium); upstream | new |
| C10-03 | Medium | performance | Every `worldScripts.X` lookup copies all world scripts and scans them linearly | — | new |
| C10-04 | Medium | error-handling | Manual `OOJSPauseTimeLimiter`/`Resume` pairs are not exception-safe | HOLDS; upstream | new |
| C10-05 | Medium | error-handling | 45 natives registered with only `OOJS_PROFILE_ENTER` let C++ exceptions unwind through QuickJS | HOLDS; upstream | new |
| C10-06 | Medium | lifetime | `ShipGroup.addShip` deliberately leaks a new group (`leakRef`) | HOLDS (Medium→Low); upstream | new |
| C10-07 | Medium | correctness | Upstream bugs carried verbatim that a test would pin down | HOLDS; upstream | new |
| C10-08 | Medium | ub | Script-supplied numbers reach undefined float→int and negation | HOLDS; upstream | new |
| C10-09 | Medium | design | Stale-entity handling differs per binding, behind dead null-guards | — | new |
| C10-10 | Medium | design | Copy-pasted helpers across bindings, some already drifted | — | new |
| C10-11 | Medium | readability | Giant property switches and boilerplate method bodies | — | new |
| C10-12 | Medium | design | Qualified "final overrider" calls exist only so tests can stand in for members | — | new |
| C10-13 | Medium | readability | Mechanical message-to-nil ternaries, even where the pointer is known non-null | — | new |
| C10-14 | Low | comments | Reflowed trailing comments, history notes and contradicting comments | — | new |
| C10-15 | Low | modern-cpp | `OOConstToJSString`: hand-rolled tables, signedness mismatch, dead table | — | new |
| C10-16 | Low | lifetime | Mission callback state: raw manually-retained script, set before the screen is built | — | planned:009-M7 |
| C10-17 | Low | api | System data written from scripts is persisted unvalidated | — | new |
| C10-18 | Low | performance | `oolite.version`/`versionString`/`compareVersion` re-read and re-parse a plist from disk every call | — | new |
| C10-19 | Low | build | Binding headers pull in the world, while some leaf headers are not self-contained | — | new |
| C10-20 | Low | readability | Dead code and leftover scaffolding | — | new |
| C10-21 | Low | modern-cpp | Small idiom items repeated across the chunk | — | new |
| C10-22 | Nit | api | Copy-pasted method names in user-visible error and warning strings | — | new |

### CX: Cross-cutting: build, tooling, tests, comments, naming, headers

21 findings: 0 High, 11 Medium, 9 Low, 1 Nit. Full text: `.agent-tmp/review-027/findings/CX.md`.

| ID | Sev | Category | Finding | Verified | Status |
|---|---|---|---|---|---|
| CX-01 | Medium | build | The game builds at `-Wall` with no `-Wextra` and no `-Werror`, so the warnings rule 5 names never judge anything | — | planned:4p-item5 |
| CX-02 | Medium | build | clang-tidy runs once, on Linux with the deployment flavour: ~4,100 first-party lines are never tidied | — | new |
| CX-03 | Medium | build | Fatal check families are wildcards and CI's clang-tidy version is unpinned, so an LLVM bump can fail CI with no code change | — | new |
| CX-04 | Medium | build | The checks most relevant to an ObjC→C++ port are off or non-fatal | — | new |
| CX-05 | Medium | build | No sanitizer build option or CI job; ASan is run by hand | — | new |
| CX-06 | Medium | comments | 6,032 trailing comments after code; 803 wrap into multi-line runs and 1,109 forced clang-format to break the code instead | — | new |
| CX-07 | Medium | naming | C++ class names leak into log and console output through `typeid`, so any rename or namespace move changes upstream-visible text | — | new |
| CX-08 | Medium | naming | Four naming schemes coexist: `OO`-prefixed globals, `namespace oo`, unprefixed globals and the `cxx_` port prefix | — | new |
| CX-09 | Medium | tests | Narrow tests redefine `class Universe` / `class Entity` and link them with game objects compiled against the real classes (ODR by design) | — | new |
| CX-10 | Medium | tests | The unit tier exists only on Windows; on Linux/macOS CI "Test Oolite" is the smoke test, and `tests/run.sh unit` may pass with no tests | — | planned:4p |
| CX-11 | Medium | performance | Every TU parses ~100k preprocessed lines of oofnd/std before any game code; trimming T031's 17-header blocks alone would not change that | — | decided:T031-trim-deferred |
| CX-12 | Low | comments | Block comments mangled by reflow of ObjC tab layout, including the exemplar and the test harness's own usage example | — | new |
| CX-13 | Low | ub | `MIN`/`MAX`/`ABS` and other macros leak from foundation headers into every TU, with two diverging definitions | — | new |
| CX-14 | Low | design | Include cycles, a self-include, the SDL front end included from Core, and a flat include path that hides layering | — | new |
| CX-15 | Low | tests | Harness and test-code hazards to carry into the GoogleTest move | — | planned:spec-005 |
| CX-16 | Low | tests | Two dead harnesses, 175 stale `.mm` banners, and no formatting policy for tests | — | new |
| CX-17 | Low | tests | Component and GUI tiers measure deadlines on the wall clock and settle with fixed sleeps | — | new |
| CX-18 | Low | comments | Planning-repo references remain in the game repo, and the 4p exit-gate grep cannot see them | — | new |
| CX-19 | Low | comments | Port-history comments describe the ObjC code rather than the C++ code | — | new |
| CX-20 | Low | build | Flavour quirks: a hidden `-O0`, hand-rolled LTO flags, whole-game ThinLTO per core test locally | — | new |
| CX-21 | Nit | comments | Dead code in comments: ObjC message syntax, `#if 0` | — | new |


---

## 12. Method, coverage and sources

### Scope

- **What was reviewed.** All first-party C++ under `oolite-dev/src` at `seriesb/027-modern-cpp`
  `3732f6126` ("T080: C strings in the SDL and debug areas", 2026-11-12). That is 534 files and
  about 232,700 lines. The build files, CI, `.clang-format`/`.clang-tidy` and the test
  infrastructure were reviewed too.
- **What was excluded.**
  - Vendored code: `src/SDL/EXRSnapshotSupport/`, `src/SDL/stb_image_write.*`,
    `src/Core/MiniZip/`.
  - The generated `src/Core/OOPlanetData.*`.
  - QuickJS-ng itself.
  - Game data, shaders and JS under `Resources/`.
  - `tools/`.
  - All expansion (OXP/OXZ) content (CLAUDE.md rule 4).
- **How.**
  - The branch was extracted read-only with `git archive` into `.agent-tmp/review-027/tree`.
    Nothing in `oolite-dev` was checked out, changed or built.
  - Ten reviewers each read one area of about 18–26k lines. An eleventh covered build, tooling,
    tests, the include graph, comment layout and naming across the whole tree.
  - Three verifiers then independently re-read the code behind all 104 High findings and
    Medium correctness findings, tried to refute each one, and compared it with upstream's
    Objective-C to classify it as a regression or inherited. That made 14 agents in total.
  - Each reviewer's raw findings, with coverage notes, are kept in
    `.agent-tmp/review-027/findings/`.
- **Status of the findings.** These are proposals (CLAUDE.md rule 5). Correctness findings say
  "suspected" and name the test or tool run that would settle them. Where something is already
  planned (spec 009 milestones, specs 003/005/006/011/013/014) or was decided (the idiom review
  §2.1, `docs/phases/6-solid-review.md`), it is tagged and not argued again.
- **Line numbers** are those at `3732f6126`.

### Severity

| Level | Meaning |
|---|---|
| **High** | Likely defect: UB, crash, use-after-free, steady-state leak, data race, overrun, wrong behaviour; or a weakness on untrusted input (saves, OXP data and scripts, OXZ downloads, the debug TCP console) |
| **Medium** | A real maintenance or performance cost, or a design problem a maintainer will trip over |
| **Low** | Readability or style with a clear benefit |
| **Nit** | Preference |

### Guidance used as the yardstick

- [ISO C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines), cited
  as `CG <rule>`:
  - P (philosophy), I.2/I.3 (globals, singletons), I.11 (ownership by raw pointer);
  - F (functions), C.10/C.20/C.21/C.35/C.128 (classes);
  - R.1–R.37 (resources), ES (expressions), CP (concurrency);
  - SF.7/SF.20/SF.21 (headers and namespaces);
  - NL.1–NL.3 (comments), NL.5 (no type information in names), NL.8 (consistent naming),
    NL.20 (one statement per line).
- [Google eng-practices, "What to look for in a code review"](https://google.github.io/eng-practices/review/reviewer/looking-for.html):
  design, functionality, complexity, tests, naming, comments that explain *why*, style,
  consistency, docs, context, and good things worth keeping.
- [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html):
  - "With few exceptions, place code in a namespace";
  - single fixed owners and `std::unique_ptr`;
  - "think about whether [a function over about 40 lines] can be broken up";
  - "Two spaces before end-of-line comments";
  - no transitive includes.
- [LLVM Coding Standards](https://llvm.org/docs/CodingStandards.html): comment formatting, early
  exits, no `else` after `return`, predicate functions, `#include` as little as possible, no
  static constructors, `auto` only where it helps.
- [Epic C++ Coding Standard for Unreal Engine](https://dev.epicgames.com/documentation/en-us/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine).
  This is a large legacy game codebase that has started moving prefixed globals into a `UE::`
  namespace, and its notes are relevant here:
  - "Const is documentation as much as it is a compiler directive";
  - keep physical dependencies to a minimum.
- [Robert Nystrom, *Game Programming Patterns*](https://gameprogrammingpatterns.com/contents.html):
  Game Loop, Update Method, Component, Singleton (and why to avoid it), Service Locator, Event
  Queue, Object Pool, Spatial Partition, Data Locality, Dirty Flag.
- [Glenn Fiedler, "Fix Your Timestep!"](https://gafferongames.com/post/fix_your_timestep/): a
  fixed simulation step with an accumulator, clamped frame time, interpolation, and the
  "spiral of death".
- [Bungie, "C++ Guidelines & Razors"](https://www.bungie.net/7/en/News/Article/50666), and the
  data-oriented design literature: optimise for the reader, consistency first, no per-frame
  allocation, cache-friendly data.


### Coverage

| Area | Reviewer coverage |
|---|---|
| C1 | All of `src/Core` in the chunk. In `oofnd`, the generated Unicode tables, `PListWriting.hpp`, `PListDescription.hpp` and part of `Defaults.hpp` were skimmed; `String.hpp` lines 1–96 were not read. |
| C2 | All 75 files. The `OOEXPAND_*` macro ladder and the `static_assert` blocks were skimmed. |
| C3 | All 82 files. `OODefaultShaderSynthesizer.cpp` (unreachable; C3-13) and the Windows extension-pointer tables were skimmed. |
| C4 | All 10 files, including all 11,825 lines of `Universe.cpp`. The `OO_UNIVERSE_VIRTUAL_MEMBERS` macro body was skimmed for structure. |
| C5 | All 16 files, including all 14,111 lines of `ShipEntity.cpp`, read in sections of about 800 lines. |
| C6 | All files except the two by-name tables. Those were skimmed, and every row was checked by a script. |
| C7 | All 14 files, including all 14,119 lines of `PlayerEntity.cpp`. The long GUI-building functions got less depth. |
| C8 | All 53 files. The licence banners and the hand-maintained data rows were skimmed. |
| C9 | All files except `OOJSCallEntityMethods.h` and `Scripting/poc/**`, which were skimmed; `poc/OOJSScript.cpp` and `poc/OOLogStub.*` were not read. |
| C10 | Every line of all 60 files. |
| CX | Build, CI, tooling and test-infrastructure files read in full. Whole-tree measurements were made with read-only scripts (`.agent-tmp/review-027/cx/`); about 10 tests were sampled. |

Most reviewers also read upstream's matching `.m` files (`upstream/oolite/src`, read-only) to tell
regressions from inherited bugs. No expansion (OXP/OXZ) content was opened.

### Whole-tree metrics

These were measured by the planning-phase explorer with `git grep` on the branch (±5%). CX's
lexer-based counts in §3 supersede them where the two differ.


**Scope.** 508 first-party `.cpp` and `.h` files, 220,937 lines, plus the 26 `.hpp` files under
`oofnd` (11,703 lines) for part B. Vendored and generated code is excluded. Counts are about ±5%.

#### A. Trailing comments

| Measure | Count |
|---|---|
| Single-line trailing `//` after code (not on `#` lines) | 5,832, about 26 per 1,000 lines |
| Trailing `//` on preprocessor lines (mostly fine) | 191 |
| **Multi-line trailing `//` runs** | **791 runs, 1,711 lines, in 173 files** |
| Trailing one-line `/* */` (71 are `/*param*/` names in `UniverseVirtualMembers.h`) | 338 |
| Trailing multi-line `/*` | 4 |
| Statement split as `x =\n    value;  // comment` so the comment fits | 118 |

- **Run lengths:** 2 lines: 690; 3 lines: 66; 4 lines: 11; 5 lines: 8; 7 lines: 2; 8 lines: 1.
- **Density per 1,000 lines (trailing lines / runs):**
  - Core/Entities 31.7 (2,450 / 311)
  - Core/Scripting 26.7 (1,020 / 162)
  - Core top level 24.3 (1,801 / 232)
  - OXPVerifier 20.4
  - SDL 19.1
  - Materials 18.1
  - Debug 17.6
  - Tables 0
- **Worst files (trailing lines / runs):**
  - ShipEntity.cpp 609 / 81
  - Universe.cpp 444 / 55
  - PlayerEntity.cpp 408 / 45
  - OOJSShip.cpp 300 / 22
  - ShipEntity.h 154 / 17
  - OOJSPlayerShip.cpp 90 / 31
  - OOPListSchemaVerifier.h 25 runs
  - StationEntity.cpp 12 runs, including runs of 8, 7 and 7 lines

##### Examples

- `StationEntity.cpp:1809`. An 8-line run at 1–3 words per line:
  `"station-docking-clearance-granted-in-@-until-@");  // the format` / `// first, as` / `// Clang …`.
  The same "the format first, as Clang evaluates the arguments…" comment is pasted 12 times in
  5 files, and each copy reflows to 5–8 lines.
- `ShipEntity.cpp:5642`:
  `desired_speed =` / `maxFlightSpeed;  // Not all AI define speed when flying away. Start` /
  `// with max speed …`.
  The statement was split and a 4-line run followed.
- `Universe.cpp:763`: `"Expected z-list to be non-empty.");  // Previously an` /
  `// implicit assumption.` / `// -- Ahruman 2011-01-25`.
- `OXPVerifier/OOPListSchemaVerifier.h:243`. Enumerators:
  `kDictionaryMissingRequiredKeys,  // requiredKeys rule is not` / `// fulfilled. …`.
- `HeadUpDisplay.h:399`. A 5-line comment on a member:
  `deferredHudName;  // Usually it will be nullopt. If engaged, …`.
- `Materials/OOTextureFlags.h:57`:
  `kNeverScale =` / `0x000400U,  // Don't rescale texture, even if rect textures are not` / `// available. …`.
- `PlayerEntitySound.cpp:140`:
  `.leakRef();  // Repeat time limit is to avoid playing a scrape sound` / `// every frame …`.
- `Entities/OOVisualEffectEntity.h:58`:
  `class OOFlasherEntity; /*	The effect definition and script_info are` / `oo::PLists …`.
  This block comment describes the class below it but is glued to the end of a forward
  declaration, with a tab inside.
- `OOMatrix.h:41`. A `/* {1,0,0,0}, … */` comment split across lines.

**Mechanism.** `.clang-format` is `BasedOnStyle: Google` (ColumnLimit 80, ReflowComments,
AlignTrailingComments). Wide Obj-C-era trailing comments are squeezed into the narrow column to
the right of the code, and statements are sometimes split to make room.

#### B. The `OO` prefix against namespaces

**Overall.** OO-prefixed tokens (`OO*`, `kOO*`, `OO_*`) appear 41,094 times, on 33,384 lines
(15% of all lines). There are about 1,636 distinct names.

| Kind | Count |
|---|---|
| Classes and structs | 184; 183 of the 232 column-0 class names are `OO`-prefixed |
| Enums | 57, all `enum class`; enumerators read `OOAlertCondition::kRed` (421 distinct) |
| `typedef`/`using OO*` | 53 |
| C-style `typedef struct {…}` | 43, for example `OORGBAComponents` |
| Free functions `OO*` | about 470 (`OOMatrixRotateZ`, `OOGLPopModelView`, `OOCPUCount`, `OOALRelease`, `OOEnumName`) |
| Macros `#define OO*` / `kOO*` | 269; `OO_` has 89 distinct names (`OO_LOG` 1,074 uses, `OO_DESC` 822, `OO_DEBUG_MONITOR_ENABLED` 196); `OOINLINE` (meaning `inline`) is used 326 times |
| `kOO` constants | 283 distinct (241 `const`/`constexpr`, 30 `#define`, about 25 enumerators) |
| Second prefix `cxx_` | 371 distinct names plus 54 `cxx_kOO…` (`cxx_OOJSReportBadArguments` 254 uses, `cxx_OOStringFromJSValue` 194) |

**What is already namespaced.**
- **Outside `oofnd`.** There are 18 `namespace oo {` blocks in 17 `.cpp`/`.h` files, plus
  `oo::http` (OOOXZManager.h), `cxx` (Entity.h:422) and one `detail`. Only 18 of the 279 `.h`
  headers open any named namespace.
- **`oofnd` `.hpp` files.** These have `namespace oo` plus `oo::str`, `oo::log`, `oo::fs`,
  `oo::date`, `oo::http` and `oo::thread`.
- **Use.** There are 14,513 `oo::` uses of 286 distinct names: `oo::PList` 6,044, `oo::Ref`
  1,573, `oo::ToShip` 460, `oo::EntityHold` 334.
- **Anonymous namespaces.** There are 375. They are good.

**Mixing.** `oo::Ref<OO…>` appears 1,406 times: `<OOColor>` 262, `<OOTexture>` 151, `<OOScript>`
68, `<OOCharacter>` 65.

**Examples at global scope.**
- `Entity.h:441 std::string cxx_OOStringFromEntityStatus(OOEntityStatus status);`
- `Universe.h:74 namespace oo { class Exception; }`, followed by 6 global forward declarations.
- `PlayerEntity.h:2087 OOINLINE PlayerEntity* OOGetPlayer(void) INLINE_CONST_FUNC;`

#### C. Objective-C residue

- **Keywords.** `nil` and `YES`/`NO` do not appear in code. In comments, `nil` appears 1,110
  times, `YES`/`NO` 290 times and "(was nil)" 101 times.
- **`self` as a variable.** 116 uses in code, across 21 files: PlayerEntity 34, ShipEntity 28,
  StationEntity 21, OOSkyDrawable 20, Octree 16. Example:
  `OOConcreteTexture.cpp:112 oo::Ref<OOConcreteTexture> self = initWithLoader(...)`.
- **Selectors.**
  - 304 code identifiers contain "selector".
  - 393 selector string literals, such as `"setUpShipFromDictionary:"`.
  - `OOEntityCalledByNameTable.h` is 3,006 lines with 965 `ByName_N` adaptors.
  - `kOOTypeEncoding<>`, which mimics `@encode`, is used 1,511 times.
  - Example: `AI.cpp:516 oo::CallEntityByName(owner, "interpretAIMessage:", message)`.
- **Two-phase init.**
  - 82 `bool`/`void init…(` member declarations, 105 `->init…(` calls and 286 `initWith*`
    identifiers.
  - Example: `OOExhaustPlumeEntity.cpp:66 if (!exhaust->initForShip(...)) return nullptr;`.
- **Factory names `xWithY(`.** 1,888 calls of 239 distinct names: `colorWithDescription` 82,
  `equipmentTypeWithIdentifier` 66, `newShipWithRole` 52.
- **`NS*` types.**
  - 752 uses: `NSPoint` 315, `NSSize` 211, `NSMakeSize` 63, `NSMakePoint` 55, `NSRange` 27,
    `NSRect` 21. They are typedefs in `oofnd/objc/OOFoundationTypes.h:70-90` (decided: kept).
  - `src/oofnd/objc/` (`OOObject.h`, `OOAssert.h`, `OOException.h`) is a leftover.
- **Category files.** `MyOpenGLView+Input.cpp` and `GameController+SDLFullScreen.cpp`.
- **Obj-C in comments.** 541 `-selector:`/`+method:` references, 250 `[obj msg]`, 290 mentions of
  Objective-C, and `// [super wasAddedToUniverse]` at `ShipEntity.cpp:1734`.
- **Other.** 146 `(void)` parameter lists.

#### D. Memory and ownership

- **Reference types.** `oo::Ref<` appears on 1,517 lines in 249 files, `oo::makeRef` 196 times,
  `oo::adopt(new …)` 31, `oo::WeakRef` 97 and `oo::EntityHold` 334.
- **Standard smart pointers.** `std::unique_ptr` appears 12 times in 4 files.
  `std::shared_ptr`/`weak_ptr` do not appear.
- **Raw allocation.**
  - `new` on about 100 lines, mostly inside `adopt`; `delete` on 18 lines in 14 files.
  - `malloc`/`calloc`/`realloc` on 56 lines in 25 files; `free` on 57 lines in 30 files.
  - Worst for `malloc`: OOPlanetTextureGenerator (8), OOStandaloneAtmosphereGenerator (5),
    Octree, OOSkyDrawable, CollisionRegion.
- **Manual refcounting.**
  - `oo::RetainEntity`/`ReleaseEntity`/`AutoreleaseEntity` on 168 lines in 19 files: Universe 51,
    ShipEntity 25, PlayerEntity 24, StationEntity 17.
  - `oo::AutoreleaseScope` appears 42 times, usually commented `// was @autoreleasepool`.
- **Casts and `void*`.** `reinterpret_cast` on 217 lines in 22 files; `void*` on 194 lines in 47
  files.
- **Deliberate leaks.** `.leakRef()` at `PlayerEntitySound.cpp:140`; `new std::map` at
  `OOTCPStreamDecoderAbstractionLayer.cpp:71`.

#### E. Macros

- **Totals.** 1,182 `#define`s. None are include guards.
  - 349 function-like, about 274 distinct, including `OOEXPAND_MAP_IMPL_0..63` in
    `OOStringExpander.h`.
  - 833 object-like, of which about 496 are numeric constants.
  - `HeadUpDisplay.h` alone has 156 (`#define SCANNER_CENTRE_X 0`).
- **Top files.** HeadUpDisplay.h 156, OOStringExpander.h 79, ShipEntity.h 68, PlayerEntity.h 55,
  OOJSEngineCore.h 37, OOFunctionAttributes.h 30, Universe.h 29.
- **X-macros.**
  - `OO_UNIVERSE_VIRTUAL_MEMBERS` (`UniverseVirtualMembers.h:65`, 62 uses) and
    `OO_ENTITY_VIRTUAL_MEMBERS` (`EntityVirtualMembers.h:60`, 52 uses) generate the virtual
    functions that tests use as a seam.
  - `UniverseVirtualMembers.h` is 218 lines but 160 KB. Lines run up to 1,035 characters, padded
    with spaces inside a `clang-format off` region.
  - `OOOpenGLStateManager.cpp` includes `OOOpenGLStates.tbl` 5 times.
- **Language features in macros.** `OOINLINE`, `MIN`/`MAX`/`ABS`, `UNIVERSE`/`PLAYER`, and
  `OO_DESC(key)`, which expands to `cxx_OOLookUpDescriptionPRIV(key "")` at `Universe.h:1008`.

#### F. Globals

- **`UNIVERSE`.** `Universe.h:1003 #define UNIVERSE OOGetUniverse()` appears on 2,398 lines in 94
  files: PlayerEntity.cpp 609, PlayerEntityControls.cpp 289, ShipEntity.cpp 253,
  HeadUpDisplay.cpp 200.
- **`PLAYER`.** 432 lines in 49 files.
- **Singletons.** 15 `sharedXxx()` accessors, used on 340 lines.
- **Non-const statics.** About 251 at column 0. `PlayerEntityControls.cpp` has 84 key-latch
  flags (decided: upstream has them); next come OOExhaustPlumeEntity with 11 and ShipEntity with
  10. There are also 67 `s`/`g` globals in anonymous namespaces.
- **Mutable externs in headers.** `gDebugFlags`; `gLiveEntityCount`, declared in both
  `OODebugFlags.h:84` and `Entity.h:72`; `gOOTextureInfo`; and 14 tables in `OOConstToJSString.h`.

#### G. Size

**Ten largest files (lines).**

| File | Lines |
|---|---|
| PlayerEntity.cpp | 14,119 |
| ShipEntity.cpp | 14,111 |
| Universe.cpp | 11,825 |
| PlayerEntityControls.cpp | 6,124 |
| HeadUpDisplay.cpp | 4,936 |
| OOJSShip.cpp | 4,562 |
| PlayerEntityLegacyScriptEngine.cpp | 3,179 |
| OOEntityCalledByNameTable.h | 3,006 |
| ShipEntityAI.cpp | 2,783 |
| GuiDisplayGen.cpp | 2,687 |

**Function lengths.** There are 6,334 top-level functions. The median is 10 lines and the mean
23. 234 functions are at least 100 lines, 66 at least 200, and 30 at least 300.

**Longest functions.**
- `PlayerEntityControls.cpp:2162 pollGuiArrowKeyControls` 1,202
- `PlayerEntityControls.cpp:1191 pollFlightControls` 970
- `PlayerEntity.cpp:1556 setCommanderDataFromDictionary` 786
- `MyOpenGLView+Input.cpp:188 pollControls` 731
- `OOJSShip.cpp:1421 ShipSetProperty` 726
- `PlayerEntityControls.cpp:3613 handleGameOptionsScreenKeys` 671
- `GuiDisplayGen.cpp:2029 drawStarChart` 654
- `OOJSShip.cpp:834 ShipGetProperty` 586
- `Universe.cpp:5232 drawUniverse` 510
- `ShipEntity.cpp:2529 update` 499

#### H. Errors

- **Exceptions.**
  - 76 `try` and 89 `catch`, of which 74 are `catch (...)`, then `oo::CurrentOOException()`.
    This emulates `@catch(NSException*)`.
  - 59 `throw`. The line `if (!exception) throw;  // not an OOException: it goes on up, as before`
    is copied 36 times in 17 files (see `AI.cpp:502-508`).
- **Logging and JS errors.**
  - `OO_LOG*` on 1,361 lines in 119 files, about 183 of them at error class.
  - `OOJSReport*` on 562 lines; `OOJSNativeFailure` 366.
- **Other returns.** `std::optional` on 3,037 lines.
- **Assertions.**
  - `OOCAssert`/`OOCParameterAssert` on 230 lines in 63 files. They are always on and ignore
    `NDEBUG` (`oofnd/objc/OOAssert.h:43`).
  - 72 plain `assert(`.
  - 2 `NSAssert`, and `OOFoundation.h:46 #define NS_BLOCK_ASSERTIONS 1`.
  - 552 `static_assert`, 131 of them in OOJoystickManager.h.
- **Termination.** 72 `noexcept`; 31 `abort`/`exit`.

#### I. Comment hygiene

- **Markers.** TODO 88 in 39 files, FIXME 93 in 43, XXX 1, HACK 16, BUG/KLUDGE 14.
- **Dead code.** Commented-out code is rare: 13 lines, plus 8 `#if 0` blocks
  (`PlayerEntityControls.cpp:2187`, `OODebugTCPConsoleClient.cpp:932`,
  `OOShaderMaterial.cpp:216`).
- **Planning-repo IDs.** No ADR references. One task id: `oofnd/objc/OOFoundationTypes.h:5`
  "Since spec 009 (T033)". The context explorer separately counted 13 "spec 009" comments in 8
  `src` files; CX checks this.
- **Migration history.**
  - "was nil" on 101 lines in 47 files.
  - "as before" on 117 lines in 57 files.
  - `// [super …]` and `// was @…` on 56 lines in 28 files.
  - Obj-C mentioned on 290 lines.
  - `-selector:` references 541.
- **Suppressions.** 7 `clang-format off` regions and 1 `NOLINT`.

#### J. Headers

- **Guards.** 303 of 305 headers use `#pragma once`. `oofnd/PList.hpp` uses `#ifndef`, and
  `SDL/OOResourcesWin/OOResourcesWin.h` has no guard.
- **`using namespace`.** None in headers at namespace scope. Two are function-local: `Date.hpp:86`
  and `FileSystem.hpp:180`.
- **Includes.**
  - 114 files include 15 or more std headers. 115 include `<mutex>`/`<condition_variable>`, but
    only 2 use them. `OOColor.h:33-50` is an example.
  - The average is 12.2 includes per file; the maximum is 94, in Universe.cpp.
- **Most-included headers.** OOFoundation.h 130 (it pulls in `oofnd/objc/OOObject.h`,
  OOLogging.h and OODescription.h), Universe.h 97 (6 of them headers), OOMaths.h 71,
  OOJavaScriptEngine.h 64, PlayerEntity.h 57.
- **C headers.** `<math.h>`, `<stdbool.h>` and `<stdlib.h>` are still included in up to 10 files
  each.

