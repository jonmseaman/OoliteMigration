# Frame hashes with tolerance, at fixed camera positions

Two renders of the same scene are compared with a **measured** tolerance, so a rendering change is
caught and ordinary rasteriser noise is not.

```bash
# offline: ~1 s, no game, no desktop, no GPU
python3 -m pytest tests/golden/test_frame_hash.py -m "not online" -q

# online: four real launches, ~2 min; needs the SHARED build (a worktree has none)
OO_APP_DIR=C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app \
  python3 -m pytest tests/golden/test_frame_hash.py -m online -q

# re-measure the tolerance from scratch (10 launches, ~5 min)
python3 tests/golden/calibrate.py --out-dir /tmp/cal \
  --app-dir C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app --write
```

## The tolerance is measured, not chosen

The whole risk of a fuzzy frame hash is the threshold. Too loose and it passes against *any* frame,
which makes it decoration; too tight and it flakes on legitimate driver noise. Neither failure is
visible by reading the constant, so **no constant is written down**. `calibrate.py` measures two
populations on this host and records them in `calibration.json`; `frame_hash.TOLERANCE` is derived
from that file at import, and `test_frame_hash.py` asserts the derivation agrees with the data.

| Population | What it is | How it is produced |
|---|---|---|
| **noise floor** | distance between two renders of the **same** scene | three captures of the reference pose, **each from its own game process** — a floor measured by hashing one PNG twice is zero and proves nothing. Measured: 0.002244, 0.002487, 0.002541 |
| **signal** | distance between renders of **deliberately different** scenes | camera translated 400 km (0.0368–0.0371); camera yawed 90° (0.0075–0.0078); same camera with a trader at 200 m (0.0648–0.0652) |

**Result: noise floor 0.002541, weakest real difference 0.007541, threshold 0.004377 — a 2.97-fold
gap between the populations, with the threshold 1.72× above the floor and 1.72× below the signal.**

The threshold is the **geometric mean** of the worst same-scene distance and the best
different-scene distance: with ratios spanning an order of magnitude that puts it at an equal
*multiplicative* margin from both, so one number states the margin in both directions.
`derive_tolerance()` **raises** if the populations overlap, because "there is no threshold" is a
real result and inventing one anyway is exactly the decoration this guards against.

**The tolerance is a function, never a module-scope constant.** An earlier version computed it at
import and raised on overlapping data, so `import frame_hash` threw — which broke every consumer,
including `calibrate.py`, the one tool able to *replace* that data. A module that cannot be imported
while the data is bad cannot be used to fix the data. Import only loads; whether a threshold exists
is a value the caller checks with `separated()`.

`calibration.json` also records `exact_match_rate`: the fraction of same-scene pairs that are
byte-identical. It is **0%** here — `sha256` of the PNG fails every time — which is why a tolerance
is needed at all.

## Why an L1 luminance grid, and not dHash

The obvious metric — a 16×16 difference hash compared by Hamming distance — was implemented first
and **measured against these frames**. It does not work on this content:

| metric | noise floor | weakest signal | margin |
|---|---|---|---|
| dHash 16×16, Hamming | 0.2383 | 0.2773 | 1.08× — and on the first scene set it **overlapped outright** (floor 0.234 > signal 0.184) |
| L1 luminance grid 64×64 | 0.002541 | 0.007541 | **1.72×** |

An Oolite system view is ~99 % black sky. Most cells of a coarse grid are flat, so every
"is this cell brighter than the next" bit there is decided by single-digit luminance noise and
roughly half of them coin-flip between two runs of *the same scene*. dHash's virtue — invariance to
overall brightness — buys nothing here, and its cost is fatal. A metric that keeps **magnitude**
instead of reducing to a sign does not have the problem. `calibrate.py` re-measures dHash on the
same frames every run (`calibration.json` → `rejected_dhash`), so the rejection stays evidence
rather than a story in a comment. The claim is *not* "dHash never separates" — on a strong enough
scene set it sometimes does. The claim is that its noise floor on this content is two orders of
magnitude larger, which leaves a margin too thin to gate anything.

`GRID_SIDE` is likewise measured: `grid_sweep` records both populations at 16/32/64/128/240 and 64
is the smallest that separates them.

## The instrument's blind spot, stated in numbers

**A frame hash sees objects that occupy pixels, not objects that exist.** A trader parked dead
ahead of an unmoved camera, at a 960×720 surface, against a noise floor of ~0.0030:

| range | distance | vs tolerance 0.004377 |
|---|---|---|
| 200 m | 0.0848 | detectable, 19× the tolerance |
| 400 m | 0.0058 | detectable, 1.3× |
| 800 m | 0.0027 | **below the tolerance — the gate cannot see it** |
| 3 000 m | 0.0030 | **invisible** |
| 12 000 m | 0.0031 | **invisible** |

Detectability is scored against the **tolerance**, not the raw noise floor: the gate passes
everything at or below the tolerance, so a distance a hair above the floor is still invisible to it.

> **A ship beyond ~800 m is below the noise floor at 960×720 software GL. Frame hashing here
> detects camera pose and near-field geometry, not distant objects.** A passing frame hash is
> therefore *not* evidence that a distant ship rendered — do not read it as one.

This is a real limit of the technique at this resolution, and the honest response is to record it
rather than to loosen the tolerance until the far cases pass — a tolerance stretched below the
noise floor passes every frame.

**It is also what made the first calibration overlap**, and the diagnosis matters: the populations
did not overlap because the renderer is too noisy to hash, but because `ship-3000m` *is not a
visibly different frame* — it scored **below** `ref` vs `ref-again`. A "different" scene that is not
different on screen contributes a spurious weak signal and drags any threshold into the noise. The
signal population therefore uses changes the hash can actually see, and the distant cases live in
the sensitivity curve where they document the boundary instead of defining the threshold. `calibrate.py` re-measures the whole curve each run
(`calibration.json` → `sensitivity`), and an offline test fails if *every* measured range becomes
detectable, because a curve with no blind end no longer locates the limit.

## A fixed camera is half the design

Two renders taken from wherever the player drifted to are two different scenes, and a "tolerance"
that absorbs that absorbs everything. `frame_capture.py` therefore drives the game to a **named
pose** from `POSES` and only then snapshots, and it **reads the position back** — a pose that
silently failed to apply gives two renders of the same *wrong* scene, which passes a same-scene
check perfectly while measuring nothing.

The player ship *is* the camera in the forward view (`PlayerShip.setCustomView` refuses unless
`VIEW_CUSTOM` is already active, which is keyboard work and belongs to the GUI tier), so a pose
writes `player.ship.position` and `.orientation` directly — both READWRITE on `Entity`
(`OOJSEntity.m`) — and zeroes `.velocity`, or the ship coasts between the console round trip and
the snapshot. The HUD is hidden: it draws a clock and a speed readout that change every frame.

Getting to a renderable state reproduces `world_steps.py`'s hard-won order for the same reasons:
load a save (the main menu is a rotating demo, not a camera), launch (a loaded save starts docked,
where the screen is a station GUI), then clear the system (a loaded save carries ~80 entities
including pirates that fly around).

## Where the game is

Fleet work happens in **git worktrees**, and `accept.sh` runs in a throwaway detached checkout
under the MSYS temp dir. **Neither contains a build** — nobody builds a 5 GB game per worktree — so
a default of "relative to this file" is a trap that makes the tooling unusable exactly where it is
used. `resolve_app_dir()` tries, in order: `--app-dir`, `$OO_APP_DIR`, a build inside this checkout,
then the shared build in the main checkout; it checks up front and its refusal names every path it
tried.

The rasteriser is pinned to Mesa **llvmpipe** (`LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`
via `console.py::_env`) and re-asserted before capture. A tolerance measured on llvmpipe says
nothing about a hardware driver, so capturing against another renderer is refused rather than
silently compared.

## Cost

Measured on this host: a warm launch is 21–36 s, a cold one can be minutes. `test_live_captures_
cost_what_a_game_launch_costs` fails any capture that finishes under 5 s — a fixed console port
lets a run attach to a *leftover* game and "pass" in seconds without launching anything.
