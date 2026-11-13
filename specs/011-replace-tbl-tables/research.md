# Research: Replace the `.tbl` tables

Phase 0 for [plan.md](plan.md). Each item: the decision, why, and what else was considered.
Measurements were taken on the base, `origin/seriesb/026-migration-completion` `a3d651a4d`
(2026-11-12), in a throwaway worktree with a build dir freshly configured there (`meson setup
build/exp --native-file clang.ini`, MSYS2 UCRT64 clang 23.1.4, `-std=c++20 -Wall`). They were
first taken on `origin/develop` `3aa8d65e8` and repeated on the base when R1 changed; both gave
the same 61 lines in the same 8 files. The existing `oolite-dev/build/meson_*` directories were
configured for another branch and their compile database does not fit either tree.

## R1. Base branch and the enum-table helper

**Decision.** `feature/replace-tbl-tables` is a Git Town feature branch on
`seriesb/026-migration-completion` (`a3d651a4d`), the step the other current features
(`feature/double-wide-support`, `feature/visual-studio-build`) build on. It is created in its own
worktree and given that parent with `git town set-parent` (R10). Its first commit adds
`src/Core/OOEnumTable.h` with the text of spec 009's T046 version (`310cd4480`, today only on
`origin/feature/json5-data-files`) unchanged, plus `#include <type_traits>` and one appended
function, `MakeEnumTableInRange` (R3). Nothing else from `310cd4480` comes across: `OOEnumFlags.h`
and the `OODebugFlags` conversion stay spec 009's.

**Why.** CLAUDE.md puts feature branches on the `seriesb` step they build on; `develop` is not in
the Git Town tree and is where Jon merges finished features. `origin/develop` (`3aa8d65e8`,
2026-11-01) is 219 commits behind `seriesb/026` and still has the `ooscript` script façade, so it
is the wrong reference. `seriesb/027-modern-cpp` (spec 009, in progress) is not used: this feature
needs nothing from it, and a parent still moving would rebase this branch for no gain.
`seriesb/026` has neither `OOEnumTable.h` nor `OOEnumFlags.h`. Taking the file verbatim and only
appending to it means that when spec 009 lands its own copy, the two differ by one addition.

**C++ version.** `seriesb/026` builds as C++20 (`src/meson.build:25`); spec 009 moves to C++23 on
its own branch. So there is no `std::to_underlying`; the headers pin values with
`static_cast<std::int32_t>(…)`. Everything else used (`consteval`, `std::array`,
`std::string_view`, `std::optional`, `std::span`, designated initialisers) is C++20.

**Alternatives.** `origin/develop`: see above (this plan's first draft used it; the measurements
were redone on `seriesb/026`). Cherry-picking all of `310cd4480`: also brings the `OODebugFlags`
conversion, which is out of scope.

## R2. Scoping the enums: what it breaks (measured)

**Question.** The spec's Story 2 assumed that once every old name is a compatibility alias, no call
site outside a table's former consumers changes. An `enum class` also drops the implicit
conversion to `int`, which aliases cannot give back.

**Experiment.** All ten enums turned into `enum class … : std::int32_t` with an
`inline constexpr` alias for every old name and typed defaults (the enum-definition files only),
then every one of the base's 820 game and test translation units checked with `-fsyntax-only`
against an unchanged baseline (820 clean).

**Result.** 85 distinct errors in 10 files; no warnings added (6 before, the same 6 after); **no
test file breaks**. Besides the two script-engine files (R5: 9 lines in the `.cpp`, 14 in the
`.h`), the errors are ordinary implicit `int` conversions at 61 lines in 8 files (line numbers on
the base):

| file | enum | lines | where |
|---|---|---:|---|
| `src/Core/Entities/PlayerEntity.cpp` | `OOScanClass` | 18 | 3617–3742 (`int theirClass = …getScanClass()` and the comparisons that follow) |
| `src/Core/Entities/PlayerEntity.cpp` | `OOLongRangeChartMode` | 1 | 1617 (`dict.get<int>("chart_colour_mode", OOLRC_MODE_SUNCOLOR)`: the **save-game read**) |
| `src/Core/Entities/PlayerEntity.cpp` | `OOGUIScreenID` | 3 | 13743, 13785, 13828 (`std::map<int, …>` keyed by a screen) |
| `src/Core/Entities/PlayerEntityControls.cpp` | `OOGUIScreenID` | 10 | 2076–2123, 3255 (`switch` on an `int`, `int` variables, the same map) |
| `src/Core/Entities/PlayerEntityControls.cpp` | `OOViewID`, `OOLongRangeChartMode` | 2 | 2121; 2237 (`(OOLongRangeChartMode)(mode + 1)`) |
| `src/Core/Entities/PlayerEntityLegacyScriptEngine.cpp` | `OOScanClass` | 3 | 2369–2371 |
| `src/Core/Entities/ShipEntity.cpp` | `OOBehaviour`, `OOEntityStatus` | 4 | 445 (`100 < behaviour && behaviour < 120`); 2323–2325 |
| `src/Core/GuiDisplayGen.cpp` | `OOEntityStatus` | 2 | 1434, 1436 |
| `src/Core/HeadUpDisplay.cpp` | `OOScanClass`, `OOViewID` | 12 | 1427–1468; 4659–4683 (the scanner-grid `switch`) |
| `src/Core/Scripting/OOJSGlobal.cpp` | `OOGUIScreenID` | 2 | 429 (`!gui`), 511 |
| `src/Core/Universe.cpp` | `OOEntityStatus` | 4 | 5282, 5647–5649 |

Only the Windows dev configuration was checked; `#if` branches for other platforms, `NDEBUG` and
the optional features may add a few more. The GCC build and CI's other platforms find them.

**Decision.** Scope the enums as the spec says (FR-002), and amend the spec: a conversion change
may also edit the lines where the compiler rejects an implicit conversion of that enum, and only
those. Each such edit keeps the meaning exactly: prefer giving the variable, parameter or map key
the enum's type (`OOScanClass theirClass = …`); where a number is genuinely meant (the `+ 1`
cycle, the `100 < behaviour < 120` range, the plist default), convert explicitly with
`static_cast`. Story 2's test becomes "no line outside the former consumers changes except where
the build required it", and the list above is what the reviewer checks against.

**Alternatives.** (a) Explicit underlying type but unscoped (`enum OOScanClass : std::int32_t`):
no call-site edits at all, but the members stay global names and the naming rule
(`kPascalCase`) cannot apply without renaming every use; it postpones the point of the change.
Rejected. (b) Adding `operator<`/`operator==` with `int` and an implicit-conversion helper: hides
the very conversions the scoping is meant to show. Rejected.

## R3. Deriving the name table from the switch

**Decision.** Each header has one exhaustive `OOEnumName` `switch` with no `default`, and its table
is `oo::MakeEnumTableInRange<E, Lo, Hi>()`, a `consteval` function appended to `OOEnumTable.h`
that tries every value in `[Lo, Hi]`, keeps the ones `OOEnumName` names, in ascending order, and
fails to compile if two values share a name. Each header `static_assert`s the table's size.

**Why.** T046's `MakeEnumTable<E, Values...>` takes the members as a second, hand-written list:
a member left out of it is silently missing from the table, which is exactly the drift FR-005
forbids. The range scan has no second list: `-Wswitch` ties the switch to the enum, and the scan
ties the table to the switch. The size `static_assert` catches a member whose value falls outside
`[Lo, Hi]`.

**Warning, not error.** The base builds without `-Werror` (no `werror` in any meson file or
native file), so in the game build a member without a case is a `-Wswitch` warning (on in
`-Wall`, Clang and GCC). FR-013 already makes a new warning a failed change, and
`tools/check-enum-headers.sh` (R6) also compiles each header on its own with
`-Wall -Werror=switch`, so the check script fails outright. This is how SC-004's enum trial is run.

**Cost.** The widest scans are `OOEntityStatus` (`-10…999`, 1,010 calls) and `OOBehaviour`
(`0…811`); the 2026-11-07 note measured all ten at about 0.07 s of compile time. Clang's default
constexpr step limit (1,048,576) is far above what 1,010 switch calls need.

**Ranges** (the program's values, from spec 009's `external-values.md`, 152 rows for these ten):

| header | values | range | rows |
|---|---|---|---:|
| `OOEntityStatus.h` | written, −10…999 | `-10, 999` | 20 |
| `OOScanClass.h` | written, −1…999 | `-1, 999` | 16 |
| `OOCompassMode.h` | written, −1…6 (no 2); shader-visible | `-1, 6` | 7 |
| `OOBehaviour.h` | written, 0…811 | `0, 811` | 39 |
| `OOGalacticHyperspaceBehaviour.h` | written, −1…2 | `-1, 2` | 4 |
| `OOViewID.h` | **ordinals 0…7**, not the column | `0, 7` | 8 |
| `OOLongRangeChartMode.h` | **ordinals 0…4**; in saved games | `0, 4` | 5 |
| `OOGUIScreenID.h` | **ordinals 0…28**, not the 29 `-1`s | `0, 28` | 29 |
| `OOLegalStatusReason.h` | ordinals 0…16 | `0, 16` | 17 |
| `OOShipDamageType.h` | ordinals 0…6 | `0, 6` | 7 |

**Alternatives.** T046's explicit list plus a size `static_assert`: still two lists, and the size
is a third hand-kept number. A generator script: the tree has no working generators (the
`tools/gen-*.py` its banners cite are absent), so codegen is not a house pattern.

## R4. Enumerator names

**Decision.** A mechanical rule, no exceptions: drop the prefix all of the type's members share,
split the rest on `_`, capitalise the first letter of each word and lower-case the rest, prefix
`k`. Members already in `kOO…` camel form drop the shared `kOO<Type>` part. So
`STATUS_IN_FLIGHT` → `OOEntityStatus::kInFlight`, `GUI_SCREEN_OXZMANAGER` → `kOxzmanager`,
`OOLRC_MODE_SUNCOLOR` → `kSuncolor`, `GALACTIC_HYPERSPACE_BEHAVIOUR_STANDARD` → `kStandard`,
`kOODamageTypeHitASun` → `kHitASun`, `kOOLegalStatusReasonPaidFine` → `kPaidFine`. No collisions
result within any type (checked against all 152 labels).

**Why.** Spec 009's exemplar (`OODebugFlags`, `DEBUG_LINKED_LISTS` → `kLinkedLists`) uses the same
rule. A fixed rule leaves nothing to taste and is checkable by reading; nicer spellings
(`kSunColor`, `kOXZManager`) are a later rename in spec 009's naming sweep if Jon wants them.

## R5. The script engine's name tables

**What it is on the base.** `OOConstToJSString.cpp` uses QuickJS-ng's own API. Each table is
`{NSInteger value; const char* cString; JSAtom atom}` entries filled from the `.tbl` files;
`OOConstToJSStringInit` interns an atom per entry with `JS_NewAtom` once per process
(`sAtomsInterned`: atoms belong to the runtime and survive engine resets) and `qsort`s each table;
lookups by value use a binary search with signed bounds, and lookups by string compare atoms.

**Decision.** This is the 2026-11-07 note's design. Each `ConstTable` becomes two spans: the
enum's rows (value as `std::int32_t`, name) read from the header's table, already ascending, and a
parallel mutable array of `JSAtom` that `InitTable` fills with
`JS_NewAtomLen(context, name.data(), name.size())`. `CompareEntries`, `qsort`, `TableEntry` and
the `TABLE` macro go; a `static_assert` that each row array is ascending replaces the sort. The
binary search and the atom scan keep their logic, reading `rows[i].value` and `atoms[i]`. The
inline wrappers in `OOConstToJSString.h` convert explicitly to and from the `NSInteger` the
private functions take; the private functions' signatures do not change. Afterwards the only
mutable state is the 152 atoms in nine small arrays.

**`OOLongRangeChartMode`'s table**, built and interned but never looked up, is carried across with
a comment.

**Engine resets.** `sAtomsInterned` and the once-per-process interning are unchanged.

## R6. Holding the new headers to the naming rule

**Finding (measured).** A `.clang-tidy` file in `src/Core/Tables` is **not** applied to a header
there when clang-tidy checks a `.cpp` elsewhere that includes it: clang-tidy uses the main file's
configuration (a test with a root config of `Checks: "-*"` and a `Tables` config enabling
`readability-identifier-naming` reported nothing through the `.cpp`, and an error when the header
itself was the main file). The 2026-11-07 note's per-directory plan therefore does not enforce
anything on its own. There is also no `./mk.sh tidy` and no clang-tidy step in CI on the base.

**Decision.** Add `src/Core/Tables/.clang-tidy` (only `readability-identifier-naming` with
`ScopedEnumConstantCase: CamelCase`, `ScopedEnumConstantPrefix: k`, in `WarningsAsErrors`) and
`tools/check-enum-headers.sh` (mode `100755`), which for each `src/Core/Tables/*.h` runs clang-tidy
with the header as its own main file and that config named explicitly
(`--config-file=src/Core/Tables/.clang-tidy`, then `-- -x c++ -std=c++20 -Isrc/Core -Isrc/Core/Tables`;
without `--config-file`, clang-tidy takes the config from the file's own folder and its parents, so
a header given from anywhere else, such as the script's own negative check, is not held to the
rule) and
compiles it alone with `clang++ -fsyntax-only -Wall -Wextra -Werror=switch`, and exits nonzero on
any finding. The headers include only standard headers and `OOEnumTable.h`, so
they need no other flags. The root `.clang-tidy` is not changed (enabling the check there would
report the existing `enum class`es elsewhere; that sweep is spec 009's).

**Alternatives.** Adding the check to the `headers` meson suite: that suite compiles, it does not
run clang-tidy, and CI's Windows image is not known to carry clang-tidy. Revisit when spec 009's
`./mk.sh tidy` lands.

## R7. The OpenGL state list as plain code

**What it is.** 30 items: 17 on/off flags (`glIsEnabled`/`glEnable`/`glDisable`, may be
`kStateMaybe`), 6 client-array flags (`glEnableClientState`, never maybe), 4 specials with their
own getter and setter (`DEPTH_WRITEMASK` `bool`, `TEXTURE_ENV_MODE`, `ACTIVE_TEXTURE`,
`CLIENT_ACTIVE_TEXTURE` `GLenum`), 3 integers (`glGetIntegerv`, own setter). Five expansions:
the record's fields, read (debug only), compare (debug only), log mismatches (debug only), write.
The blend function sits outside the list in all five and stays there.

**Decision.** Keep `OOOpenGLState` as a struct with one named field per item, so the five standard
states keep their designated initialisers (`.LIGHTING = kStateTrue`), and replace the `.tbl` with
one `constexpr` table of item descriptors in `OOOpenGLStateManager.cpp`, one entry per item, each
built by a kind-specific function that takes the item's log name, its GL enumerant and a pointer
to its field, and for specials and integers its getter and setter (a missing argument does not
compile). Read, compare, log and write become loops over the table. A `consteval` count of the
struct's fields (the aggregate-initialisation count, tested on Clang and GCC in C++20) is
`static_assert`ed equal to `1 + items + 2` (name, items, the two blend fields), so a field without
an item, or an item without a field, fails the build.

**Behaviour to keep exactly.** Item order (the log prints mismatches in table order); the "maybe"
rule (compare and write skip a flag item when either side is maybe); writing the blend function
when its values differ *or* the source state's `BLEND` is `kStateFalse` (`!sourceState->BLEND`,
which is false for maybe); and one quirk: the verifier logs **every** special item through
`OOGLFlagToString`, ignoring the display function the table names, so a `TEXTURE_ENV_MODE`
mismatch prints `true`/`false`. The log is debug-only; the quirk is kept and listed for Jon.
`GetState_*` functions exist only when `OO_GL_STATE_VERIFICATION`; the descriptor table's getter
column is compiled only there.

**Performance.** The write runs once per state change (a few hundred a frame at most) over 30
items; a loop over a `constexpr` table of member pointers costs nothing measurable against the GL
calls it makes.

**Alternatives.** (a) Arrays indexed by an item enum in the record: one list, but the standard
states become positional arrays of 30 values each and lose their labels. Rejected as less
readable and more error-prone. (b) The same X-macro list as a macro inside the `.cpp`: still a
preprocessor contract, just not in a file. Rejected: it is what the request objects to.

## R8. The one test edit and the ledger

`tests/unit/core/test_OOJSSound.cpp:33-40` rebuilds `OOEntityStatus` from `OOEntityStatus.tbl` with
its own `ENTRY` because it avoids `Entity.h`. With the `.tbl` gone it includes `OOEntityStatus.h`
instead (four lines become one); its uses (`_status = STATUS_IN_FLIGHT`, `OOEntityStatus status()`)
compile unchanged through the aliases, as R2's experiment showed for every test. Rule 1's third
exception covers it (a header the test names replaced by its equivalent; spec 009 T063 classes it
*covered*). It goes in `test-ledger.md` in this directory in the commit that makes it.

## R9. Proving saved games and scripts are unchanged

- **Numbers**: every one of the 152 `external-values.md` rows for these types becomes a
  `static_assert` in its header (FR-003); `chart_colour_mode` in particular is pinned 0…4.
- **Names**: each name in the switch is a literal; a new unit test,
  `tests/unit/core/test_OOConstToStringEnums.cpp`, checks the 144 (value, name) pairs of the nine
  types that `OOConstToString.cpp` converts (all but `OOViewID`, which has no conversion function
  there), written into the test as literals copied from `external-values.md`, through the fifteen
  `cxx_OOStringFrom…`/`…FromString` functions (both directions where both exist), and every
  fallback (`UNDEFINED`, `** BEHAVIOUR UNKNOWN **`, the `BEHAVIOR_` spelling, each default). It links
  the same sources as `test_OOConstToString` (`tests/unit/core/meson.build:99`) with its own copy of
  that test's stubs; the existing test file is not touched (adding a test is allowed; the
  `meson.build` entry is a build file, not a test). A second new test,
  `tests/unit/core/test_OOConstToJSStringEnums.cpp`, checks the nine script-engine tables (all but
  `OOBehaviour`, which has none) both ways through `OOJSValueFrom<Type>` / `<Type>FromJSValue`, so
  `OOViewID`'s names are covered too, with the `"UNDEFINED"` and default fallbacks, before and after
  an engine reset (`OOConstToJSStringDestroy`, a new context on the same runtime,
  `OOConstToJSStringInit`; FR-007). Both use only functions that exist before and after the change,
  so they are written and passing on the base **before** the first conversion and are the
  before-and-after check.
- **Saved games**: a unit test cannot load a save without the game. The save path reads and writes
  `chart_colour_mode` as an `int`, so the pinned ordinals are what keeps old saves loading; the
  quickstart adds a by-hand check (save on the base with the chart in economy mode, load on the
  branch).
- **Scripts**: the component suite exercises `status`, `scanClass`, `guiScreen`,
  `viewDirection` and `compassMode` through the debug console; it must pass unchanged. There is no
  script-API snapshot tool on the base (spec 009 T013 restores one on its branch); SC-003's
  snapshot clause is met by the component suite plus the two tests above until then.

## R10. Where the work happens

`oolite-dev`'s checkout is in use by another session (`feature/double-wide-support`, untracked
files), and `seriesb/026` may be checked out elsewhere, so `git town append` (which needs the
parent checked out) is not usable. From the planning repo's root:

```bash
git -C oolite-dev worktree add ../.agent-tmp/wt-tbl -b feature/replace-tbl-tables origin/seriesb/026-migration-completion
```

```bash
git -C .agent-tmp/wt-tbl town set-parent seriesb/026-migration-completion
```

The second command records the parent, as CLAUDE.md requires; `git town branch` then shows the
branch under `seriesb/026`. The worktree gets its own `build/` (copy
`oolite-dev/subprojects/quickjs-0.17.0` into it to avoid a download). Push with
`git push -u origin feature/replace-tbl-tables`; later syncs use
`git town sync --stack --detached`. Remove the worktree at the end with `git worktree remove`,
never `git worktree prune` (prune drops other sessions' live worktrees).
