# ADR-0018: A component test tier — Gherkin scenarios over the debug console, in Python

**Status:** Proposed — recommended default, in effect unless Jon overrides ([ADR-0013](0013-decide-up-front-minimise-human.md))
**Date:** 2026-09-10 · **Extends:** [Phase 0 item 0.4](../phases/0-safety-net.md) (goldens), [item 0.8](../phases/0-gui-tier.md) (GUI tier)

## Context

The safety net as specified has two tiers: the golden harness (item 0.4) and the PyAutoGUI smoke tier
(item 0.8). Between them they answer "did anything change?" and "does the application start?". Neither
answers **"which behaviour broke?"**

A golden is a byte-compared canonical state dump. That is exactly the right instrument for catching
unanticipated divergence — its whole value is that it asserts on things nobody thought to assert. But
when a Phase 3 conversion breaks combat, a golden diff reports that 1,800 floats moved. It cannot say
*weapons stopped dealing damage*. Across 686 beads, that difference is most of the debugging cost, and
it falls on the one resource the project is actually short of: Jon's adjudication time.

A second observation: the goldens are expensive to make trustworthy. They need a fixed RNG seed, a
fixed tick count, a fixed clock, quantised floats, pinned `-ffp-contract=off` and `-O`, per-platform
blessing (decision 11), and a human gate to re-bless. All of that must be right *before the first
golden is blessed*. Tolerant assertions need almost none of it.

A third: a request for readable scenarios ("spawn ships and enemies, run N frames, check enemies die")
is a request for a *specification* the project does not currently have anywhere. The scenario list in
item 0.4 is prose in a phase doc. Gherkin makes it executable.

## Decision

### 1. Add a third tier: component tests, Gherkin scenarios driven over the debug console

Specified in [0-component-tier.md](../phases/0-component-tier.md). It shares the golden harness's
transport (debug-console TCP, `Perform Command`, no window) and differs in what it asserts:

| | Golden harness (0.4) | **Component tier (0.13)** | PyAutoGUI (0.8) |
|---|---|---|---|
| Driven via | debug-console TCP/JS | debug-console TCP/JS | synthetic OS input |
| Asserts | full state dump, byte-compared | named invariants, tolerant | launched / responded / exited |
| Catches | any divergence, incl. unanticipated | the specific behaviour that broke | window, input, shutdown |
| On failure says | "1,800 floats moved" | "pirates no longer die" | "window never opened" |
| Determinism needed | fixed seed + fixed dt + quantised floats + per-platform bless | **fixed seed only** | n/a |
| Human gate | re-bless (Jon, weekly) | **none — assertions are in-tree code** | none |
| Runs in | Tier B subset / Tier C | Tier B subset / Tier C | Tier C + nightly |

The boundary is to be held as strictly as [0-gui-tier.md](../phases/0-gui-tier.md) holds its own. A
component test that starts byte-comparing a state dump belongs in the goldens. A golden that grows a
hand-written assertion belongs here.

**This does not weaken "never verify with a model" (hard rule 7).** A step asserting
`countShipsWithRole("pirate") === 0` is mechanical, lives in the tree, and is reviewed as code. Rule 7
forbids a *model* adjudicating whether a diff is legitimate; it has never forbidden tests from
asserting outcomes. Verification stays mechanical; adjudication stays Jon's.

### 2. pytest-bdd, not cucumber-cpp — and the trigger to revisit

In order of weight:

1. **There is nothing in-process to bind C++ step definitions to.** `Universe -update:` is mercifully
   free of render coupling, but the only supported entry into a live world is the full application
   bootstrap: `src/SDL/main.m` → `GameController` → the `PLAYER` singleton
   (`src/Core/Entities/PlayerEntity.h:1325`) → a live JS context. C++ step definitions would therefore
   be TCP clients exactly as Python ones are — C++ buys nothing, and costs Boost plus a build
   integration on the path that gates every bead.
2. **The transport is already written, in Python.** `upstream/oolite/tests/launch_snapshot.py` already
   does the plist framing (`send_plist_packet`, :31), the handshake (:129-143) and `Perform Command`
   (:153-157). `pytest` is already in the item 0.2 provisioning list and is the GUI tier's runner. One
   language across both test tiers, one dependency already present.
3. **cucumber-cpp's own documentation describes it as unmaintained** (maintenance possibly resumed per
   its issue #242), with declining commit activity. Poor footing for a Tier B dependency.
4. [ADR-0011](0011-cpp20-then-cpp23.md)'s principle applies verbatim: do not add per-platform
   variability while the tests are the only thing holding the line.

**Revisit at Phase 4/6**, once the Objective-C runtime is gone and a `Universe` can be constructed
in-process without `GameController`. In-process step definitions would be dramatically faster (no
process launch, no ~5-10 s boot), which is the only route to running this tier in Tier A at all. At
that point prefer **Catch2's `SCENARIO`/`GIVEN`/`WHEN`/`THEN`**, which buys most of the readability
with zero new dependencies; cucumber-cpp only if `.feature` files are still wanted for their own sake.

### 3. One enabler: `OO_RANDOM_SEED`

`src/Core/GameController.m:100` seeds the RANROT generator from the wall clock:

```objc
ranrot_srand((uint32_t)[[NSDate date] timeIntervalSince1970]);   // reset randomiser with current time
```

Combat draws on that generator heavily — 52 `randf()` sites in `ShipEntity.m`, 14 in
`ShipEntityAI.m`, including the shot-attempt gate at `ShipEntity.m:11481`:

```objc
if (range > randf() * weaponRange * (accuracy+7.5))  return NO;
```

So "the pirate dies within 900 ticks" is genuinely flaky without a pinned seed. **Decision:** honour an
`OO_RANDOM_SEED` environment variable when set; fall back to today's behaviour when not. Roughly three
lines, upstreamable as a plain determinism fix, and explicitly within Phase 0's allowance of "no
production code changes except determinism fixes that are upstreamable as plain bug fixes".

**This is not only a component-tier need.** Item 0.4 lists "fixed RNG seed" as a required golden
property, and beads `oo-gla`, `oo-jor` and `oo-izi` all assume it, but no bead made the seed settable.
The golden chain was silently blocked on it.

**Explicitly not decided here: fixed-delta-t frame stepping.** The goldens need it, because they
byte-compare positions. This tier does not, because its assertions are tolerant. Leaving it out is what
lets the component tier land *before* the golden harness and before item 0.1's iteration-order work —
and what keeps it valid across Phase 5's platforms with no per-platform blessing.

### 4. Observation uses the existing JS surface; no new native interfaces

| Need | Existing surface |
|---|---|
| Spawn a scene | `addShips` (`src/Core/Scripting/OOJSSystem.m:192`), `legacy_spawnShip` (`:213`) |
| Count survivors | `countShipsWithRole` (`OOJSSystem.m:197`) |
| Enumerate the world | `system.allShips` (`OOJSSystem.m:116,152`) |
| Position, orientation, scan class, liveness | `OOJSEntity.m:105,107,108,119` |
| AI state, motion, identity | `OOJSShip.m:340` (`AIState`), `:472` (`velocity`), `:458` (`speed`), `:439` (`primaryRole`) |
| Cross-command scratch state | `debugConsole` is a writable JS global (`src/Core/Debug/OODebugMonitor.m:761`) |

Two limits, both accepted rather than engineered around:

- **`energy` is not exposed to JS** (only `energyRechargeRate`, `OOJSShip.m:371`). Assert death and
  survival, not health.
- **Killer attribution needs a script resource.** `shipDied` / `shipKilledOther` fire from
  `-noteKilledBy:damageType:` (`ShipEntity.m:9007,9020,9024`), but capturing them requires a script
  object on a ship (`setScript`, `OOJSShip.m:560`). S1 therefore asserts "no pirate remains and a
  police ship survives", which with two spawned ships already proves engage → fire → damage → death.

Do not add native properties to make an assertion easier. Asserting only on what is already observable
is what keeps this a small seam rather than a native-API project.

### 5. Later beads may add scenarios; the step library grows only by seam

The tier is worth building only if a conversion bead can add coverage for what it just converted.

- **A new `.feature` scenario using only existing steps is fleet work.** A `.feature` file is data, not
  an interface, so sizing check 5 is not violated and such a story scores 7/7 against the S1 exemplar.
  Any bead may add one.
- **A new step definition is a new interface.** Check 5 fails, so the standing rule applies: stop and
  file a bead. The step library grows deliberately, by seam, never opportunistically inside a
  conversion bead.
- **"Do not modify or delete tests" never meant "do not add tests."** Stated explicitly in
  [the story template](../templates/story.md) so the prohibition block is not misread as hands-off.
- `tools/gen-stories.py` gains the `sweep:component` emitter and a standing clause on conversion-bead
  bodies inviting a scenario when the conversion changes observable ship/AI/weapon behaviour.
- The item 0.11 guardrail that detects deleted tests must cover `.feature` files and the step library,
  or the tier can be quietly gutted by a bead trying to go green.

## Consequences

- Phase 0 gains item 0.13 and one exit-gate line; the seam is `tests/component/` plus S1, and S2–S8
  are its sweep.
- Tier B gains a tagged component subset alongside its 3–5 fast goldens; Tier C runs the full suite.
  Each scenario is one game process, so the tier competes for the same RAM budget as the goldens
  ([I0](../infra/0-machines.md)) and must be tagged, not run whole, per bead.
- **Ordering:** S1 should land before the golden harness runner (`oo-16s`). It needs strictly less
  machinery, so it reaches green sooner, and the harness can then reuse its console client rather than
  the reverse.
- The project acquires an executable specification of gameplay behaviour, which is the artifact an
  expansion author or a future maintainer will read first.
- A risk accepted: two tiers now drive the game over the same TCP channel, so a change to the console
  protocol breaks both. Mitigated by sharing one console client between them.

## History

Prompted by Jon (2026-09-10), who proposed scenario-based component tests and asked whether Gherkin
via cucumber-cpp would fit. The premise that "the goldens are going to be PyAutoGUI" was mistaken — the
goldens are console-driven and headless ([0-gui-tier.md](../phases/0-gui-tier.md):16-21) — but the gap
the question pointed at was real, and is what this ADR fills.
