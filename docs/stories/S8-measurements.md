# Bead oo-qwk5 / component scenario S8 — measurements

S8 is "Destroyed ships leave `system.allShips`". Expressed with the existing step catalogue
(`upstream/oolite/tests/component/README.md`), the only destruction mechanism available is
*combat between spawned ships*, and the only observable is a **role count** reaching zero.
This file records what was measured about whether that can be made reliable, with
`tools/oo-qwk5-probe.py`, on the shared build, seed 20260910, system Lave.

Every number below is from a real run; the raw JSON records are under `$LOCALAPPDATA/Temp/qwk5/`
and are not committed (they are launch traces, not artifacts).

## The root cause of the flakiness is NOT only the populator

The previous attempt attributed S8's 3-pass/6-fail record to the system populator adding a
`pirate` mid-run and re-falsifying "no pirate remains". That is real, and reproduced here
(run r2: `pirate` went 1 -> 2 at t=27.5 s with nothing spawned in between). But it is the
*second* cause, and the smaller one.

**The first cause is that the police often never attack at all, and whether they do is a random
draw made at spawn time.**

Traced in source and then confirmed in the running game:

| Fact | Where |
|---|---|
| a ship spawned under the literal role `pirate` gets `bounty = 20 + randf() * 50`, i.e. a draw over 20..70 | `src/Core/Universe.m:4026` |
| `policeAI` attacks a scanned ship only through `conditionScannerContainsFugitive` (`bounty > 50`) or `conditionScannerContainsSeriousOffender` (`bounty > fineThreshold()`) | `Resources/AIs/oolite-policeAI.js:91-99` |
| `fineThreshold() = 50 - system.info.government * 6` | `Resources/Scripts/oolite-priorityai.js:845` |
| Lave has `government = 3`, so the threshold is **32** | measured: `system|government|fineThreshold = Lave|3|32` |

So a legitimately spawned pirate is below the police's attack threshold whenever its bounty draw
lands in 20..32 — **about 24 % of runs** for a uniform draw over 20..70. In those runs the eight
vipers never engage, the quarry cannot die, and the scenario fails at the full tick ceiling.
That is the "Mode A" failure the previous attempt saw at 118-138 s, and no amount of extra
killers or extra ticks can fix it, because nobody is shooting.

Directly observed, run r2 (1 pirate + 8 police, 1 km, 110 s, per-ship sampling):

```
bounties: police=0 ... pirate=22          <- 22 <= 32, below threshold
t=  0.0 .. t=108.6   every viper: AIState GLOBAL, hasHostileTarget '-', target none
quarry 'pirate' dead_at=None
```

Eight police, 110 seconds, **not one of them ever took a hostile target**. The pirate was
simply not a criminal as far as the AI was concerned.

## Reversing the cast does not help either

Run r1 (1 police quarry + 16 pirate killers, 1 km, 148 s): `police=1` for the whole run,
`dead_at=None`. Pirates do not hunt police — `oolite-pirateAI.js` treats `CLASS_POLICE` through
`conditionScannerContainsHunters` and **leaves the vicinity** rather than attacking
(`behaviourLeaveVicinityOfTarget`). The populator meanwhile added a `worm|shuttle` at t=32.7 s,
so `allShips` still moved under the scenario's feet. Raising the killer count cannot fix an AI
that is running away by design.

## Only three roles are both single-carrier and unconditionally attacked

An observable safe from the populator needs exactly one carrier in `shipdata.plist`, and a
stimulus that is not a draw needs a **fixed** bounty above 50 (`conditionScannerContainsFugitive`
is the one police priority with `reconsider: 1`). The complete list, from a full resolve of
`shipdata.plist` through `like_ship`:

| role | ship | bounty | max_energy | speed | weapon | verdict |
|---|---|---:|---:|---:|---|---|
| `asp-cloaked` | asp-cloaked | 150 | 350 | 400 | beam | **cloaks and escapes** |
| `constrictor` | constrictor | 250 | 450 | 600 | military | **outruns and outguns 12 vipers** |
| `thargoid` / `thargoid-mothership` | thargoid | 100 | 600 | 500 | thargoid laser | tougher still |

Measured against 8, 12 and 24 police at 1 km. Runs that died with
`ConsoleError: Oolite did not connect to the console within 60s` (shared port 8563, a sibling
agent's game still holding it) are excluded as instrument failures, not results:

| cast | valid runs | quarry destroyed | times |
|---|---:|---:|---|
| `asp-cloaked` + 8 police (r3, r7-2, r7-3) | 3 | **2** | 92.1 s, 113.0 s, — |
| `asp-cloaked` + 24 police (r4-1, r4-2) | 2 | **1** | —, 60.4 s |
| `constrictor` + 12 police (r6-1..3) | 3 | **1** | 64.1 s, —, — |
| `pirate` + 8 police (r2) | 1 | **0** | — (bounty 22 <= 32, never engaged) |
| `police` + 16 pirates (r1) | 1 | **0** | — (pirates flee police by design) |

Best case is `asp-cloaked` + 8 police at **5 of 8 across both police counts** — nowhere near the
10/10 the bead requires, and note that *tripling the killers made it no better*. The per-ship
sampling explains why: at t=21.6 s the Asp's `scanClass` had changed from `CLASS_NEUTRAL` to
**`CLASS_NO_DRAW`** — it had activated its cloaking device, at which point it is unscannable and
every viper loses it. The runs that killed it did so before the cloak mattered. That is a coin
flip, not a stimulus that can be strengthened.

`constrictor` fails for the opposite reason: 450 energy, a military laser, 3 missiles, ECM and
600 m/s against a viper's 180 energy and 320 m/s. It wins the fight or leaves.

## Conclusion

Within the existing step catalogue there is **no cast that destroys a single-carrier quarry
reliably**. The three available observables are all either a random draw (`pirate`, whose bounty
decides whether combat happens at all), an escape artist (`asp-cloaked`), or a ship that beats
the killers (`constrictor`, `thargoid`). Raising the killer count and the tick budget was tried
and measured and does not converge — it made the best candidate strictly worse.

What S8 needs is one of:

* **a step that sets a ship's bounty** after spawning, so the police's attack condition is a
  fact of the scenario rather than a draw. `ship.bounty` is already writable from JS
  (`OOJSShip.m:1378`), so this is a step-library change and nothing native; or
* **a per-ship handle** (oo-kbqw / oo-bdl0), so the assertion names the ship the scenario
  spawned instead of a role the populator also writes to — which additionally closes the
  vacuity hole that no role-count observable can close.

Either is a new entry in the step catalogue, which is a new interface: **sizing check 5**
(`docs/decisions/0018-component-test-tier.md` §5). The correct move is to stop rather than to
add one inside a conversion story.

## Reproducing

```bash
export PATH="/ucrt64/bin:$PATH" MINGW_PREFIX=/ucrt64
OO_APP_DIR=C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app \
  python3 tools/oo-qwk5-probe.py --seconds 110 --interval 6 --engage \
  --spawn 'pirate:1,police:8@1' --quarry pirate --json /tmp/r.json
```

Run it a handful of times and read the `bounties:` line against the `fineThreshold` on the line
above it: the runs where the printed pirate bounty is at or below the threshold are exactly the
runs where every viper stays at `hasHostileTarget '-'` for the whole budget.

Note the probe needs a **built** app dir, which a worktree is not; point `OO_APP_DIR` at the
main checkout's build, and run one at a time — the console port (8563) is shared, and two
concurrent probes give `Oolite did not connect to the console within 60s`.
