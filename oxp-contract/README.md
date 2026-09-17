# OXP contract snapshots

Machine-readable records of the interfaces expansions (OXP/OXZ) are written against. They exist so
that a migration step which changes the engine's internals can be shown *not* to have changed what
scripts can see. Nothing here is hand-edited: regenerate, then read the diff.

## `js-api-1.92.json`

Every JavaScript global the running game exposes, and for every native class every property,
method, arity and type. Generated from the live game over the debug console by
`tools/js-api-snapshot.sh`, checked by `tools/js-api-check.sh`.

```bash
tools/js-api-snapshot.sh          # regenerate from the built game (needs oolite.app; ~20 min)
tools/js-api-check.sh             # structural + determinism check; offline, no build needed
tools/js-api-check.sh --regen     # the full contract: regenerate, then git diff --exit-code
```

### What the numbers actually are

The story that commissioned this file said "61 JS globals". The build disagrees, and the build
wins. Measured against `upstream/oolite` at version 1.93:

| Count | Value | What it is |
|---|---|---|
| `global_count` | 121 | every own property of the JS global object |
| `ecmascript_global_count` | 51 | ECMAScript/E4X builtins SpiderMonkey provides (`Array`, `XML`, ...) |
| `oolite_global_count` | 70 | globals Oolite itself installs |
| `oolite_global_count_without_debug_console` | 66 | the same, minus the four the Debug OXP adds (`Console`, `ConsoleSettings`, `console`, `debugConsole`) |
| `class_count` | 32 | Oolite globals that are constructors with a prototype |

61 is not any of these. The closest reading is "Oolite globals that are not native classes"
(70 − 32 = 38) or the shipped non-debug set (66); the figure in the story appears to predate
several additions. The snapshot records what the engine does, and the summary block carries all
five counts so a later reader does not have to guess which one a check meant.

### Determinism

The whole point is that a regeneration diffs clean, so the file contains only *shapes*, never
session values: no timestamp, no path, no port, no address, and no property value. A member is
recorded as its kind (`method`, `property`, `accessor`, `native-opaque`), its arity if it is a
method, the `typeof` of its value if it is a data property, and its descriptor flags. Keys are
sorted, the indent is two spaces, the encoding is ASCII with LF endings. `tools/js-api-check.sh`
re-serialises the file and fails if it is not byte-identical, so a hand edit is caught even
without a game build.

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
