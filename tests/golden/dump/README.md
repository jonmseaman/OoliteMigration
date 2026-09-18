# Canonical world-state dump (bead oo-gla)

The dump other golden scenarios are blessed against. Determinism is the entire point: two runs of
the same scenario on the same build must produce **byte-identical** JSON.

## Files

| file | role |
| --- | --- |
| `dump_state.js` | The debug-console JS command. Runs **inside the game**, returns canonical JSON as a string. |
| `state_dump.py` | Python glue: loads the JS, runs it over the console, spawns the deterministic scenario. |
| `run_dump.py` | CLI: launch one game, spawn, dump, write JSON. |
| `check_canonical.py` | Asserts a dump **is** canonical by reading the emitted JSON (not the source text). |
| `run_order_proof.sh` | Proves the entity sort is load-bearing. |
| `run_epsilon_proof.sh` | Proves float quantisation is load-bearing. |

## What "canonical" means here

1. **Sorted object keys.** `canon()` rebuilds every object with `Object.keys(o).sort()`. Some of
   these objects originate in an Objective-C `NSDictionary` (`localMarketForScripting`), whose key
   order is a hash-iteration artifact, not a contract.
2. **Stable entity order.** Entities are sorted by `id` (`shipUniqueName`, assigned zero-padded by
   the spawning script so lexicographic order is spawn order) — *not* `system.allShips` order,
   which walks Universe's `sortedEntities` (draw order).
3. **Quantised floats.** `q()` rounds through `toFixed(QUANT_DECIMALS)` (3 decimals) and reads the
   result back as a Number, per decision 11. Quantisation is **textual**, so two binary doubles
   that agree to 3 decimal places serialise identically — that is what absorbs FMA/libm/platform
   noise without a per-platform golden.

Determinism also depends on two scenario choices made in `run_dump.py::run_once`:
`pauseGame()` before touching the world (`delta_t` is forced to 0, `GameController.m:401-402`, so
the simulation cannot advance between spawn and dump) and `radius_m=0` on `addShips` (no
scatter-radius RNG draw).

## Why there are two separate proof scripts

The headline gate — three runs, byte-identical — is necessary but **measured not to be
sufficient**:

* **`run_order_proof.sh` exists because the three-run gate does not catch an unsorted dump.**
  Deleting `ents.sort(...)` and running three times still produced three identical dumps: repeating
  the *identical* spawn sequence on the *identical* build happens to yield the same `allShips`
  order every time. The same mutant *did* change the dump versus the sorted baseline, so the sort
  does real work the repeat-run gate cannot see. The proof instead spawns the **same two roles in
  the opposite order** — same ships, same field values, different iteration order — and requires
  the dumps to match. It checks a **positive control first** (`--raw-order` shows the unsorted
  `allShips` id sequence genuinely differs between the two spawn orders), so it cannot report a
  vacuous green. Verified red against the un-sorted mutant, with the offending diff printed.

* **`run_epsilon_proof.sh` exists because "floats are quantised" has two failure modes.** A
  sub-epsilon nudge (0.0002 m) must be **absorbed** (otherwise quantisation absorbs nothing and
  every golden bit-flips on harmless noise) and a super-epsilon nudge (0.01 m) must be **visible**
  (otherwise quantisation is truncating real signal and the golden cannot catch a behaviour
  change). One direction alone proves nothing.

* **`check_canonical.py` exists because the acceptance block's other guards grep source text**, and
  a source-text match can be satisfied by a comment or a docstring. It parses the JSON the game
  actually emitted and asserts key order via `object_pairs_hook` (the order as *written*), decimal
  places per number, and `entities` sorted by `id` — plus non-vacuity (entities/market/player must
  have content). Its own three negative controls run offline as an acceptance line.

## Running it

```sh
PY=$(command -v python3 || command -v python || echo /ucrt64/bin/python3)
"$PY" "$(cygpath -m "$PWD/tests/golden/dump/run_dump.py")" \
  --app-dir C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app \
  --port 8563 --seed 1 --out dump.json
```

**MSYS path conversion is disabled on this host.** `run_dump.py` is executed by a *native*
`python3.exe`, which resolves an MSYS-style `/c/...` path against the current drive instead of
converting it. Convert with `cygpath -m` (never `-u`) for every path that crosses into a native
binary — the same guard `golden_run.py::to_native()` applies.

## Not under `tools/gui-lock`

Deliberately, and for the reason `golden_run.py`'s module docstring gives: no synthetic input, no
window click, artifacts read over the console socket. `console.py` does not take the lock either
(its own docstring explains why the lock belongs to whoever decides how many games run at once).
