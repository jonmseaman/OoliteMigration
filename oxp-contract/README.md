# OXP contract snapshots

Machine-readable records of the interfaces expansions (OXP/OXZ) are written against. They exist so
that a migration step which changes the engine's internals can be shown *not* to have changed what
scripts can see. Nothing here is hand-edited: regenerate, then read the diff.

## `js-api-1.93.json`

Every JavaScript global the running game exposes, and for every native class every property,
method, arity and type. Generated from the live game over the debug console by
`tools/js-api-snapshot.sh`, checked by `tools/js-api-check.sh`.

The name carries the engine version the file was measured against, and the file's own
`oolite_version` field must agree with it: this is a versioned conformance baseline, and
`docs/phases/1-js-engine.md` requires *this* file to reproduce exactly on QuickJS-ng. When the
engine version moves, regenerate under the new name rather than editing the old one, so a reader
diffing "the 1.93 API" is diffing 1.93 data.

```bash
tools/js-api-snapshot.sh          # regenerate from the built game (needs oolite.app; ~20 min)
tools/js-api-check.sh             # structural + determinism check; offline, no build needed
tools/js-api-contract.sh          # pin the counts and per-class method floors; offline
tools/js-api-check.sh --regen     # the full contract: regenerate, then git diff --exit-code
```

`js-api-check.sh` asks "is this file well-formed and reproducible?"; `js-api-contract.sh` asks "does
it still describe the API we recorded?". Both run offline, which is why they — and not `--regen` —
are what the bead's acceptance and CI execute: a clean checkout has no game binary.

### What the numbers actually are

The story that commissioned this file said "61 JS globals". The build disagrees, and the build
wins. Measured against `upstream/oolite` at version 1.93:

| Count | Value | What it is |
|---|---|---|
| `global_count` | 121 | every own property of the JS global object |
| `ecmascript_global_count` | 51 | ECMAScript/E4X builtins SpiderMonkey provides (`Array`, `XML`, ...) |
| `oolite_global_count` | 70 | globals Oolite itself installs |
| `oolite_global_count_without_debug_console` | 66 | the same, minus the four the Debug OXP adds (`Console`, `ConsoleSettings`, `console`, `debugConsole`) |
| `class_count` | 27 | Oolite globals that are real native classes: a constructor whose prototype carries members beyond the automatic `constructor` |
| (not a summary key) | 32 | Oolite globals that merely *own* a `.prototype`. Five more than `class_count`, and not the right number — see below |

`class_count` is 27, not 32. Every JavaScript function owns a `.prototype`, so "has a prototype" is
not the test for a class: `consoleMessage`, `formatCredits` and `formatInteger` are plain global
utility functions, and `ConsoleSettings` is a Debug-OXP constructor, whose prototypes contain
nothing but `constructor`. `SystemInfo` is a fifth: its `prototype` is a live `[object SystemInfo]`
with **zero** own property names — everything useful (`filteredSystems`, `systemsInRange`,
`setInterstellarProperty`) is a static on the constructor, not a prototype member. (An earlier
snapshot counted it as a class because a scanner bug filled its empty prototype with the previous
target's members; see "No two globals may share a member list by accident" below. `XML.prototype`
and `XMLList.prototype` are empty for the same real reason and were wrong for the same bug reason.)
A class installed by `JS_InitClass` has real members on its prototype,
which is the test `tools/js_api_snapshot.py::_is_native_class` applies and
`tools/js-api-check.sh` re-verifies against the committed file.

61 is not any of these. The closest reading is "Oolite globals that are not native classes"
(70 − 27 = 43) or the shipped non-debug set (66); the figure in the story appears to predate
several additions. The snapshot records what the engine does, and the summary block carries all
five counts so a later reader does not have to guess which one a check meant.

### Determinism

The whole point is that a regeneration diffs clean, so the file contains only *shapes*, never
session values: no timestamp, no path, no port, no address, and no property value. A member is
recorded as its kind (`method`, `property`, `accessor`, `native-opaque`), its arity if it is a
method, its descriptor flags, and — on a *class prototype* — the `typeof` of a data property.

The singleton globals (`clock`, `mission`, `player`, `system`, `oolite`, ...) are the exception,
and deliberately so. Each is one live object, so the `typeof` of its own data properties is the
current session, not the API: `mission.screenID` is `null` with no mission screen up and a string
with one; `system.mainStation` is an object in a system and `null` in interstellar space. Recording
those would make a regeneration diff against the savegame. `own_members` therefore carries kind,
arity and descriptor flags but **no `type`**. `tools/js-api-check.sh` fails the file if an
`own_members` entry ever regains a `type`.

That is not free, and an earlier version of this paragraph wrongly said it was ("nothing is lost,
every such member is also on the class prototype"), on the strength of four sampled globals. Across
all seventeen object globals, most own data properties *are* recoverable — the same member appears
on the class prototype (`Mission.prototype`, `System.prototype`, ...) with a state-independent
`typeof`, and for `global` the member is itself a top-level global with its own entry. Five are not:

    console.script  console.settings  debugConsole.script  debugConsole.settings  player.ship

For those five the `typeof` is genuinely gone from the document. They are also the members where it
was worth least: each holds a live object or `null` depending on what the session is doing, so the
recorded value would be exactly the session state this rule exists to keep out, and the engine
declares no static type to record instead. `tools/js-api-check.sh` pins that set by name and fails
if it grows, so widening the loss has to be argued for rather than noticed later.

Keys are sorted, the indent is two spaces, the encoding is ASCII with LF endings.
`tools/js-api-check.sh` re-serialises the file and fails if it is not byte-identical, so a hand
edit is caught even without a game build.

### No two globals may share a member list by accident

`tools/js-api-check.sh` fails if two globals record byte-identical member maps without a declared
reason. This is the detector for a whole class of enumeration fault, and it exists because one
happened: the scanner accumulated each target's members into a JS-side string that was reset only
when a scan actually ran, so a global with *zero* own property names was described with the
**previous** global's accumulator. Three globals in an earlier snapshot were therefore pure
fabrication — `StopIteration` held `Station.prototype`'s members, `missionVariables` held
`Mission.prototype`'s and `worldScripts` held `Array.prototype`'s, each the immediate successor of
its donor in sorted order. The correct answer for all three is an empty `own_members`.

Any bug that copies one target's members onto another produces an exact duplicate, because the copy
is of already-serialised records rather than a re-derivation. The comparison ignores `type` and
`native-opaque` entries, since those are added and removed per bucket and would mask the match. Real
aliasing does exist (a singleton shares its class's prototype object; `console` and `debugConsole`
are the same object under two names; the typed arrays come from one template) and is listed by name
in `EXPECTED_IDENTICAL_BUCKETS`; anything else fails.

### `native-opaque`

Sixty members across seven classes (`Dock`, `ExhaustPlume`, `Flasher`, `Station`, `VisualEffect`,
`Waypoint`, `Wormhole`) are recorded as `native-opaque`: they exist, but their descriptor cannot be
read. Asking for one invokes a native getter against the *prototype*, which has no backing
Objective-C object, and `OOJSReportBadPropertySelector` raises a SpiderMonkey error with no
exception object — uncatchable from JS, and it terminates the whole console command. The scanner
records its position before each member so it can resume past the offender instead of losing the
class; `native-opaque` is the honest answer for those members rather than a silent omission. If a
later engine change makes them readable, the diff will say so, which is exactly what this file is
for.
