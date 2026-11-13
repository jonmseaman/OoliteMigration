# Data model: Headless simulation tests

The feature stores almost nothing. These are the values tests and the game pass to each other, and
the three files the tier keeps. Names are the plan's working names; the interfaces are in
[contracts/](contracts/).

## Headless options

What a test gives the game when it creates it. Every field's default is today's windowed
behaviour, so the windowed game passes the defaults.

| Field | Meaning | Windowed default | Scenario game | Menu game |
|---|---|---|---|---|
| `headless` | no window, no GL, no sound | false | true | true |
| `seed` | one seed for every generator | from clock or `OO_RANDOM_SEED` | from the test | from the test |
| `addOns` | which expansions are read | all | none | none |
| `populate` | fill the system with traffic | true | false | true |
| `startInFlight` | put the player in flight at once | false | true | false |
| `inputView` | create a view with no window, for keys | n/a | false | true |
| `step` | fixed dt for the stepper | n/a | 1/60 s | 1/60 s |
| `scriptTimeLimit` | JS limiter's limit | as today | 10 s | 10 s |

Rules:
- `headless` true requires `seed` to be given.
- `addOns` is never `all` when `headless` is true.

## Game clock

| Value | Windowed | Headless |
|---|---|---|
| monotonic seconds | steady clock | starts at 0; `tick(dt)` adds dt |
| time of day | system | derived from the seed, then advanced with monotonic seconds |

State changes: only `tick` advances the headless clock. Nothing else writes it.

## Event record

An ordered list. One entry per thing the game raised.

| Field | Meaning |
|---|---|
| `time` | game time, seconds |
| `kind` | `shipEvent`, `worldEvent`, `log`, `scriptError` |
| `name` | event name (`shipDied`, `shipAttackedOther`, …) or log class |
| `subject` | entity id and its definition key, when there is one |
| `text` | the log line, for `log` and `scriptError` |
| `isError` | true for `scriptError`, and for `log` lines with the error prefix or a class in the error list |

The error list: `shipData.load.error`, `setup.ship.badEntry.*`, `script.javaScript.exception.*`,
`exception`, `equipment.load`.

## Presentation record

| Field | Meaning |
|---|---|
| `framesRequested` | how many times the game would have drawn |
| `soundsRequested` | ordered names of sounds the game would have played, with game time |

The showing screen is not stored here. It is read live:

| Value | Source |
|---|---|
| screen id | the player's GUI screen (`OOGUIScreenID`) |
| selected row | `GuiDisplayGen::getSelectedRow` |
| row text, row key | `GuiDisplayGen` row data |
| selectable range | `GuiDisplayGen` |

## Key event

| Field | Meaning |
|---|---|
| `scancode` | the physical key (SDL scancode) |
| `mods` | shift, ctrl, alt, caps lock, num lock |
| `down` | press or release |

A test may name a key by the character it wants (`'n'`) and a layout. The support library looks
up the scancode and modifiers in that layout. Pressing by scancode directly is for the fault
tests.

## Recorded layout (`tests/sim/layouts/<name>.tsv`)

One row per (scancode, modifiers) pair that produces a key.

| Column | Meaning |
|---|---|
| `scancode` | SDL scancode number |
| `mods` | `-`, `shift`, `caps`, `shift+caps`, `altgr` |
| `keycode` | the SDL key code that layout gives, in hex |
| `comment` | the character, for the reader |

Rules:
- `us.tsv` must agree with SDL's built-in map. A test checks this, so the tables are known to be
  in the form SDL produces.
- Each file's header comment says how it was recorded and on what system.
- The set is `us`, `fr_azerty`, `ru`.

## Definition

| Field | Meaning |
|---|---|
| `kind` | `ship` or `equipment` |
| `key` | the name in the data (`cobra3-trader`, `EQ_ECM`) |
| `class` | from the data: `template`, `part`, `service`, or `candidate` |

Classification:
- `template`: the ship definition has `is_template`.
- `part`: the registry tagged it as a sub-part and no role selects it.
- `service`: an equipment item that is applied and gone (`EQ_FUEL`, `EQ_RENOVATION`,
  `EQ_MISSILE_REMOVAL`, `EQ_PASSENGER_BERTH_REMOVAL`), recognised by having no fitted state after
  award.
- `candidate`: everything else. Candidates are tried.

## Census outcome

One per definition, exactly.

| Outcome | When |
|---|---|
| `passed` | tried, and every pass condition held |
| `left` | tried; it removed itself within the span, and the expectations file says it does |
| `failed` | tried, and a pass condition did not hold; or the child died while trying it |
| `not-applicable` | class is `template`, `part` or `service`, or the expectations file says so |

Pass conditions for a ship: spawn returned an entity; it is in the universe at the end of the
span; it has one attached part for each sub-part its definition declares; no error entry in the
event record names it or occurred during its span; after removal the entity count equals the
count before the spawn.

Pass conditions for an equipment item: award succeeded; the ship reports it fitted; activation,
if it has a script, raised no error; no error entry during its span; after removal the ship no
longer reports it.

A `part` is `not-applicable` only if at least one ship that carries it `passed`. Otherwise it is
`failed` with the reason "no passing parent".

## Expectations file (`tests/sim/census-expectations.tsv`)

| Column | Meaning |
|---|---|
| `kind` | `ship` or `equipment` |
| `key` | definition name |
| `expect` | `failed`, `left` or `not-applicable` |
| `reason` | one sentence; required |

Rules, checked by the census:
- a key not in the data is an error;
- a listed definition whose outcome differs from `expect` is an error (so a fixed fault must be
  taken off the list);
- an empty `reason` is an error.

## Census report (`<build>/sim/census-report.tsv`)

One row per definition: `kind`, `key`, `class`, `outcome`, `seed`, `gameTime`, `evidence`.
`evidence` is the first error line, or the reason, or empty. Rows are sorted by kind and key, so
two reports diff cleanly.

## Scenario digest

A hash, per step, of every entity's id, definition key, position, orientation and energy, and of
the event record so far. Two runs with the same seed on one platform must give the same sequence
of digests. The repeat test compares them and reports the first step that differs.
