# Golden storage policy (decision 11)

Where goldens live, at what precision they are stored, and which build flags they are only valid
under. Implemented by bead `oo-ss8`; decision 11 is
[ADR-0013](../../docs/decisions/0013-decide-up-front-minimise-human.md) item 11.

```bash
# offline: the whole falsifiability suite, no game, no build, ~2.5s
python3 -m pytest tests/golden/test_golden_storage.py -q

# do the build flags the policy claims actually reach the compiler?
python3 tests/golden/check_build_flags.py \
  --configure-from "$PWD/upstream/oolite" --build-dir /tmp/flagcheck

# two fresh runs vs each other and vs the stored golden (2 launches, ~30s warm)
export PATH=/ucrt64/bin:$PATH   # else the loader kills oolite.exe with 3221225781, no log
python3 tests/golden/dump/run_dump.py --app-dir "$OO_APP_DIR" --out /tmp/r1.json
python3 tests/golden/dump/run_dump.py --app-dir "$OO_APP_DIR" --out /tmp/r2.json
python3 tests/golden/golden_diff.py /tmp/r1.json /tmp/r2.json
python3 tests/golden/golden_diff.py goldens/windows-x64/001/state.json /tmp/r1.json

# re-measure the run-to-run float spread from scratch (4 launches, ~1 min warm)
bash tests/golden/measure_quantisation.sh
```

## Layout

```
goldens/<platform>/<scenario>/state.json        the canonical dump
goldens/<platform>/<scenario>/provenance.json   what produced it
```

`windows-x64` exists now. `macos-arm64` and `linux-x64` join at Phase 5, which is the first time
this policy is exercised across platforms ([ADR-0009](../../docs/decisions/0009-apple-silicon-after-runtime-removal.md),
[Phase 5](../../docs/phases/5-apple-silicon.md)).

The platform is a **directory**, not a filename suffix, and the platform key is deliberately coarse
(`os-arch`, nothing else). Two consequences, both wanted:

* A platform with no golden has no directory. That is loud. A suffix scheme degrades into
  "fall back to the other platform's numbers", which is precisely the cross-platform comparison
  decision 11 exists to prevent.
* The compiler version and OS build are recorded in `provenance.json`, **not** in the key. Putting
  them in the key would re-fragment the golden set on every toolchain bump and silently leave every
  platform with nothing to compare against.

`provenance.json` is load-bearing, not metadata. Without it, a disagreement between a golden and a
run is uninterpretable: nobody can tell whether the code changed or the build flags did. It records
the quantisation, both pinned flags, the compiler, the OS and the commit — and `golden_diff.py`
**refuses to compare at all** against a golden whose recorded quantisation is off policy.

## The quantisation precision, and what it is actually based on

**`QUANT_DECIMALS = 3`** (`tests/golden/dump/dump_state.js`), i.e. 1 mm on positions and 1 mm/s on
velocities, mirrored as a constant in `check_canonical.py` and `golden_diff.py` so that editing one
of them fails loudly.

### The honest version first: the precision is NOT derived from a measured spread, because on this platform there is none

The intended derivation was: dump scenario 001 repeatedly at full precision, look at how far the
raw doubles move between runs, and pick a decimal count comfortably above that. That measurement
was done — `tests/golden/measure_quantisation.sh`, `--quant-decimals 15`, five separate game
processes — and it returned a null result:

```
rawA sha256=a12ebfaed616eefd bytes=2008   wall=13s
rawB sha256=a12ebfaed616eefd bytes=2008   wall=12s
rawC sha256=a12ebfaed616eefd bytes=2008   wall=11s
rawD sha256=a12ebfaed616eefd bytes=2008   wall=15s
rawE sha256=a12ebfaed616eefd bytes=2008   wall=33s

float fields per dump: 21 ; leaf fields: 122
pairwise-vs-rawA differing float fields across 4 comparisons: 0
max observed absolute spread: 0.0
distinct dump hashes: 1
```

**Five separate launches produced byte-identical dumps. The observed run-to-run spread is exactly
zero in all 21 float fields.** There is no measured number to derive a decimal count from, and any
figure quoted as "the measured spread" would be fabricated. None is quoted.

The raw evidence is committed under `tests/golden/measurements/` (`001-raw15-runA.json`, the
full-precision dump, and `001-raw15-summary.json`, the five-run comparison with its limits), so
this reasoning can be checked without re-running four launches. Those are **measurement artifacts,
not goldens** — nothing compares against them.

### …and the null result is even narrower than it looks

It is tempting to read "identical at 15 decimals" as "the noise floor is below 1e-15". **It is not,
and nobody should cite it that way.** Every float in this dump is an exact binary fraction whose
decimal expansion *terminates*, and terminates far short of 15 places:

| value | fraction | exact decimal places needed |
|---|---|---|
| `-49474.3203125` | …+41/128 | 7 |
| `60752.15625` | …+5/32 | 5 |
| `427652.3984375` | …+51/128 | 7 |
| `-473553.375` | …+3/8 | 3 |
| `-186315.515625` | …+33/64 | 6 |
| `609470.5` | …+1/2 | 1 |

Maximum over all 21 fields: **7 exact decimal places.** So at `--quant-decimals 15`
`toFixed()` rounded *nothing* — it printed every value exactly. The experiment never exercised
rounding at all.

What it therefore establishes is **that scenario 001 is bit-reproducible on windows-x64 with this
build** — a genuine and useful result, and the thing the zero-difference gate rests on. What it
does **not** establish is where any noise floor sits, because no noise was observed and no rounding
was performed.

### Sample size, stated plainly

The evidence base is thin and a reviewer should weigh it accordingly:

* 2008 bytes per dump, 122 leaf fields, **21 float fields** — of which only **6 are distinct
  values**, because the four spawned ships share the station's position exactly (`radius_m=0`).
* Every velocity is `0`. Nothing is in flight.
* `run_dump.py` calls `pauseGame()` before touching the world, forcing `delta_t` to 0
  (`GameController.m:401-402`), so no physics integrates between spawn and dump. The dumped values
  are positions *copied* from the station, not the output of an arithmetic pipeline — there is
  essentially nothing for FMA, libm or reassociation to perturb.

**This is a static scenario, and a static scenario is weak evidence of engine-wide determinism.**
A scenario with entities genuinely in flight — non-zero velocities integrated over a fixed tick
count, so positions are the product of repeated arithmetic rather than a copy — would exercise this
far harder and is where a real spread would first become visible. That is out of scope for this
bead (it needs a scenario with a tick budget, not just a storage policy) and is recorded here as a
**known limit**, not as work done.

### So what IS the precision based on?

Two documented grounds, neither of which is a measured spread:

**1. Quantisation is for CROSS-PLATFORM divergence, and there is no second platform yet.** Decision
11 pairs per-platform goldens with quantisation precisely because the same source compiled by a
different compiler for a different ISA will not produce bit-identical floats — different libm
implementations, different vector widths, different legal reassociations. `-ffp-contract=off`
removes the largest and most arbitrary of those (FMA fusion, measured below); quantisation absorbs
what remains. **None of that can be validated on a single platform.** The precision is a
*forward-looking guard* whose value is untestable until `macos-arm64` or `linux-x64` exists at
Phase 5. What would validate it: run this same scenario on a second platform, diff the raw dumps at
full precision, and check the observed cross-platform delta is comfortably under 0.001. If it is
not, **3 is the wrong number and must be re-derived from that measurement** — and every golden
re-blessed.

**2. The float32 ULP of the data bounds it from below; behavioural resolution bounds it from
above.** Oolite stores entity positions as 32-bit `float`, and at the magnitudes scenario 001
occupies (5×10⁴ – 6×10⁵ m) one float32 ULP is **0.0039 – 0.0625 m**, i.e. larger than the 0.001
quantum in all 21 fields:

| field | value | float32 ULP |
|---|---|---|
| `entities[Coriolis Station].position[0]` | `-49474.3203125` | 0.00390625 |
| `entities[Coriolis Station].position[2]` | `427652.3984375` | 0.03125 |
| `entities[Rock Hermit].position[1]` | `-186315.515625` | 0.015625 |
| `entities[Rock Hermit].position[2]` | `609470.5` | 0.0625 |

So 3 decimals is *finer than the storage format's own resolution over the observed range*: it
cannot merge two values the engine can actually tell apart here. At the other end, 1 mm is orders
of magnitude below any behavioural difference a golden exists to catch — a ship in the wrong place,
a changed AI state, a different market price. The quantisation is real work, not a no-op: it alters
**19 of the 21** float values in this dump.

**Stated plainly: 3 decimal places is a justified choice, not a measured one.** It is bounded below
by the float32 ULP of the data (measured) and above by the behavioural resolution a golden needs
(argued), and its actual job — absorbing cross-platform divergence — cannot be tested until a
second platform exists. If a future platform produces a divergence wider than 0.001, this number
must be re-derived from that measurement. It must never be quietly coarsened to make a failure
disappear; `golden_diff.py` refuses to compare at all if someone tries (see below), which matters
doubly here, because coarse quantisation would hide exactly the cross-platform divergence the
policy exists to catch.

### A note on wall times

The five raw runs took 13s, 12s, 11s, 15s and 33s. Launch cost on this host is highly variable
under sibling load (the fleet's own measurements range from ~4s warm to ~140s cold/contended), so
**a launching gate returning in under a second did not launch anything**, and a slow run is not
by itself a failure.

## The build flags, and why they are coupled to the quantisation

Two flags are pinned in `upstream/oolite/meson.build`:

| flag | where | why |
|---|---|---|
| `-ffp-contract=off` | `add_project_arguments`, unconditional | stops clang fusing `a*b + c` into a single FMA |
| `optimization=2` (`-O2`) | `default_options` | `-O` changes vectorisation width, reassociation and inlining, all of which move low-order float bits |

`-ffp-contract=off` is not a superstition, and the difference it makes was measured on this exact
toolchain (clang 22.1.8, ucrt64) with `a=0.1, b=0.3, c=-0.03` **read from `argv`**, so nothing can
be constant-folded at compile time and the runtime result is the real instruction's output:

```
-ffp-contract=off      vfmadd_in_asm=0  result=0                        0x0.0000000000000p+0
-ffp-contract=fast     vfmadd_in_asm=2  result=1.665334536937734749e-18 0x1.eb851eb851eb8p-60
```

The flag both changes the generated code (`vfmadd` appears and disappears with it) and changes the
answer. One FMA rounds **once** where the unfused form rounds **twice**, and whether the fusion
happens depends on the target ISA and the optimiser's mood — i.e. on the machine, which is exactly
what a per-platform golden must not silently inherit.

(A first version of this probe passed the constants as literals and measured nothing useful: at
`-O2` clang folded the whole expression at compile time in double precision, so the `fast` build
printed the *uncontracted* answer while its assembly still contained the FMA. If you re-run this,
keep the inputs opaque to the optimiser.)

**The coupling:** the flag pin is the first line of defence and the quantisation is the second.
The pin removes the *structural* discrepancies — a fused-vs-unfused multiply-add can move a result
by far more than a last bit once it propagates through a physics step, and no sane quantisation
absorbs that. The quantisation then only has to absorb ordinary last-bit noise. Leaving the flag
off and quantising harder would work in exactly one sense — the goldens would pass — and would
destroy the golden's ability to detect anything, which is the failure mode this whole document is
written against.

It is applied **unconditionally**, not only in a "golden build" configuration. A flag that is only
on in one configuration is a flag whose absence nobody notices.

### The flags are verified, not asserted

`tests/golden/check_build_flags.py` never reads `meson.build`. It configures the build (or reads an
existing build dir) and inspects `compile_commands.json` — the literal command lines ninja will run
— asserting per translation unit that `-ffp-contract=off` is present, that the **effective** `-O`
is the pinned one, and that no contraction-enabling flag (`-ffast-math`, `-Ofast`,
`-ffp-contract=fast`, …) appears. Verified output on this tree:

```
PASS: 243/243 translation units carry -ffp-contract=off and compile at the pinned -O2
(effective, i.e. last -O on the line); no contraction-enabling flag present.
Effective -O levels: {'-O2': 243}
```

Three anti-vacuity properties in that checker are worth calling out, because all three were found
by running it rather than by designing it:

* **"Effective", i.e. the last `-O` on the line.** Oolite's `meson.build` appends `-O0` after
  meson's `-O2` when `debug` is true, and every TU in a default configure carries **both** — so it
  really compiles at `-O0`. A naive "is `-O2` somewhere on the command line" test passes on that
  build. The checker takes the last one, and configures with `-Ddebug=false`, which is what
  `mk.sh` passes for the `test` and `deployment` flavours (`mk.sh:173-177`) — the only flavours a
  golden is ever produced from.
* **A minimum TU count.** "0 of 0 translation units violate the policy" is the vacuous form of this
  check, so a database with fewer than 100 entries is rejected outright.
* **Configure through a shell, not a bare `subprocess.run`.** `meson.build:5` runs
  `ShellScripts/common/get_version.sh`, which identifies its caller by walking the Windows parent
  process chain. An extra `python.exe` in that chain breaks the identification and the script
  refuses to run, with its telltale *empty* diagnostic values — surfacing only as
  `get_version.sh failed with status 1`, which reads exactly like a repo defect. Measured back to
  back on the same source and env: meson from bash `rc=0`, the identical invocation from
  `subprocess.run([...])` `rc=1`.

### FINDING: the build that produced the current golden predates this pin

Running the checker against the **shared** build directory that actually produced
`goldens/windows-x64/001/state.json`:

```
FAIL: the configured build does not honour the golden flag policy:
  - 242 of 242 translation units do NOT carry -ffp-contract=off (first: ../../src/Core/AI.m).
```

That build was configured before this bead added the pin, so **the stored golden was produced by a
binary that could contract multiply-adds.** This is recorded, not papered over:
`provenance.json` for that golden carries `"verified": false` with the full reason, because
`bless_golden.py` writes the **observed** flags read from `compile_commands.json` rather than the
policy constants. Writing the policy values there would make every golden claim compliance by
construction — the exact failure the pin exists to prevent.

The correct resolution is to rebuild the shared app dir and re-bless, which is out of this bead's
scope (a worktree has no build and must not create one). Until then the golden is honest about its
own provenance, and `test_provenance_records_OBSERVED_flags_not_the_policy_it_wishes_for` keeps the
finding from being tidied away.

Note also that the dump values themselves are essentially insensitive to this: the scenario is
paused (`delta_t = 0`) and the dumped positions are copies, so there is almost no float arithmetic
for contraction to affect — which is consistent with the five runs being byte-identical. That is an
explanation, not an excuse; the flags still need to be right before a golden is trusted
cross-platform.

## Why `golden_diff.py` and not `diff`

`diff -q` answers "same bytes". That is a fine repeatability check and the dump tier already uses
it. It is not a golden comparison, and a zero-difference gate built on it is the easiest kind of
gate to make vacuous. `golden_diff.py` closes all three holes:

| hole | what closes it |
|---|---|
| both sides are empty / collapsed | non-vacuity floor: ≥40 leaf fields, ≥2 entities, non-empty `entities`/`market`/`player` |
| the tool compared a file to itself | path equality **and** `(st_dev, st_ino)` identity — a hardlink is not a second run |
| quantisation coarsened until everything matches | provenance `quant_decimals` must equal the policy value, **and**, independent of provenance, the data must still carry fractional floats (an all-whole-numbers dump is refused) |

Exit codes are three-valued on purpose:

* `0` — no differences, every guard satisfied
* `1` — differences, each printed as `path: <left> != <right>`
* `2` — **refused**: the comparison was unsound

`2` is separate from `1` because "I cannot tell you" must never be readable as "they match". Note
that a refusal is also not a pass: the acceptance gate treats anything other than the expected code
as failure.

Entities are keyed by `id`, not by array index, so a removed ship reports as one absent entity
instead of shifting every later index and burying the real change in noise.

## Re-blessing

`tests/golden/bless_golden.py` is the only writer, it is never called from a test, and it
**refuses to overwrite an existing golden** without `--force`:

```
REFUSING to overwrite the existing golden goldens/windows-x64/001/state.json. A golden that
disagrees with a fresh run is a FINDING to investigate and report, not a file to rewrite.
```

A golden that updates itself when it fails is not a golden. If a behaviour change is genuinely
intended, re-bless explicitly with `--force` and say why in the commit message.

## Proof that the gate can fail

The falsifiability evidence is in `tests/golden/test_golden_storage.py` (17 offline tests) and in
acceptance lines 5, 7 and 8. Concretely, on the **real** stored golden, in a throwaway copy:

```
perturbed Coriolis Station position[0] -49474.32 -> -49474.319 in a THROWAWAY COPY
DIFFERENCES (1) between goldens/windows-x64/001/state.json and .../mutant.json:
  entities[Coriolis Station].position[0]: -49474.32 != -49474.319
```

…and green against an untouched copy of the same file. One quantised unit — the smallest change the
policy can represent — is detected and named, with both values. Coarsening quantisation to 0
decimals, and comparing the golden with itself, are both refused with `rc=2`.
