# Scenario 010 `test-oxp: PNG` — what is measured, what is excluded, and why

This file exists so the exclusions in this golden can be **audited**. An exclusion list nobody can
check is how a golden becomes a lie, so every field and every entity this scenario does not carry
is named below with the mechanism that puts it there.

## The observable, and the anti-vacuity problem it solves

A texture test that silently decodes nothing produces the **same clean log and the same quiet
dump** as one that worked. Four independent defences answer that, each measuring a different stage
of the pipeline — see `tests/golden/png_test_suite.py`'s module docstring for the full argument and
`tests/golden/check_png_evidence.py` for the executable form. The strongest one is measured, not
argued:

| observation | distance | ratio to tolerance |
| --- | --- | --- |
| tolerance (bead oo-ae9, `frame_hash.derive_tolerance()`) | 0.004377 | 1.00x |
| same scene, two independent launches | 0.000531 | **0.12x** |
| the identical run with the decoded PNG NOT on screen | 0.138777 | **31.70x** |

A **261-fold separation**. Both values sit inside bead oo-ae9's measured discrimination band
(noise floor 0.002541, weakest real signal 0.007541): this scenario's own floor is ~5x below the
measured floor because a docked mission screen is a far more static stimulus than a starfield, and
its signal is ~18x above the weakest measured signal. **The tolerance is used exactly as measured
and was not adjusted.** The numbers are recorded in `provenance.json` under `frame_control`.

### The control is the same run with the image absent, and it is doubly informative

The control is `--blank-screen`: the *identical* staging, world, tick budget and dump, with the
same mission screen opened with **no background image**. The only variable is whether the decoded
PNG reaches the screen.

That run **also fails the evidence gate**, with `evidence.png_texture_uploads == []`. This is a
finding worth stating plainly: the backdrop PNG is decoded **only when the mission screen asks for
it**, so the texture-upload evidence and the frame evidence are not two readings of one event but
two consequences of the same cause, each of which independently goes to zero when the image is
absent. Capturing the control's frame therefore required a throwaway copy of the runner with
`assert_ran()` bypassed — a measurement instrument, deleted immediately; the real gate keeps every
predicate.

## Exclusions, each named and traced

### 1. The 153 PNG Suite images are not rendered — they are not shipped

PNGTestSuite's own README states the suite images are omitted for licensing reasons. Verified on
disk: `Images/` holds exactly **one** file, `oolite_material_test_suite_backdrop.png`, 1024x512.
This scenario therefore does **not** run the suite's 153 rendering tests; it asserts that the
2930-line `Config/shipdata.plist` naming those 153 images was parsed and merged
(`evidence.png_shipdata_entries == 153`, plus three diffuse-map strings read back out of the
running engine), and that the **one real PNG** was decoded and uploaded. A scenario built on 153
guaranteed texture failures would have to tolerate real errors to stay green, which is the opposite
of what a golden is for.

### 2. The world contains exactly two entities, both stations

`entities` carries `Coriolis Station` and `Rock Hermit`, both at zero velocity. This is **not** a
filter — it is the world the scenario constructs. Every non-player, non-station ship is removed,
and three independent traffic sources are switched off first (all three are recorded in the
evidence block, so dropping any one of them goes red by name):

* `system.populatorSettings` — the system populator (`populators_suppressed`, measured 36 keys);
* each station's own launch schedule, `StationEntity.m:960-995` gated on `hasNPCTraffic`
  (`stations_quieted`, measured 2);
* `oolite-populator.js`'s `systemWillRepopulate` (`repopulator_handlers_quieted`), which
  `hasNPCTraffic` does **not** stop because its station picker `_tradeStation` ends with an
  unconditional `return system.mainStation`.

Nothing is excluded from the dump on the grounds of being inconvenient. `world_reached_fixed_point`
records that the clearing loop saw a round that both removed nothing and left nothing.

### 3. No field is excluded because of the `velocity`/`thrustVector` engine defect

Bead oo-jou1 is fixing a real defect: `ShipEntity -velocity` is `[super velocity] + [self
thrustVector]` (`ShipEntity.m:12830-12833`), `speed` is `OOJS_PROP_READONLY_CB` with no setter, and
`setTotalVelocity:` only subtracts the *current* thrust vector (`ShipEntity.h:945`) — so a ship
under thrust reads a non-zero velocity no JS write can clear, with a frame-count-dependent value no
two runs reproduce.

**This scenario excludes nothing because of it.** It does not zero velocities and then hope; it
*removes* every mover and then *asserts* `assert_at_rest()` — every non-player ship's
`velocity.magnitude()` (a **function call**; bead oo-jor measured a version comparing a function
object with a number, which passed on every run) must read zero at the instant the dump is taken.
The two surviving stations are not under thrust and read exactly `[0, 0, 0]`. The defect is
therefore visible to this gate rather than worked around by it: if a thrusting ship were present,
the run would **refuse to dump**, and its refusal message names the mechanism and cites those
source lines.

### 4. The frame grid is deliberately NOT in `state.json`

llvmpipe is not bit-reproducible across runs (bead oo-ae9 measured 0 of 3 same-scene pairs
byte-identical; this bead measured **10 distinct grid digests over 10 runs** whose dumps were all
byte-identical). Putting a frame hash into `state.json` would make the byte-exact golden
comparison fail on every run. Two artifacts, two comparison rules: `state.json` byte-exact,
`frame.grid` under the measured tolerance.

### 5. Two `[oxp-standards.error]` lines are allowed — exactly, by message and by count

PNGTestSuite predates the manifest format (bead oo-kcrw's NOMANIF class). The allowance is a
**pin**, not a suppression: a third line, or any different message, fails the run. No
`manifest.plist` is staged — fabricating one would falsify the fixture under test.

## Nothing is spawned by role, so bead oo-izi's nondeterminism does not apply

Bead oo-izi proved that spawning by **role** is a RANROT draw whose position depends on elapsed
frames (`Universe.m:4008` -> `:3948` -> `OOShipRegistry.m:276-279`), so a fixed seed does not fix
the cast. **Checked: this scenario spawns nothing at all.** The only entity operations it performs
are `ships[i].remove()` and property writes; there is no `addShips`, `addShipAt`, `spawn` or
`[shipKey]` call anywhere in `png_test_suite.py`. The cast is the system's own fixed furniture, so
the latent role-spawn nondeterminism has no purchase here. This is why the dump is byte-identical
across 10 runs rather than merely similar.

## Every knob has a predicate

Bead oo-3ya's finding: a seed that is *printed* but has no predicate can be changed with the gate
staying green, and a fresh-run-vs-golden comparison cannot catch it because changing the seed
changes **both sides**. So `provenance.json` records the knobs the golden was **blessed** with and
acceptance line 2 asserts `spec.json` still agrees, field by field. Re-blessing with a new seed
stays legal — both files move together; drift between them is fatal. Line 2 also asserts that
`png_test_suite.py` actually *reads* each of the 17 knobs, so a knob nobody reads is rejected as
decoration.

## Stability, measured

10 runs, all rc=0, all writing a **byte-identical** 2438-byte dump
(`32cc0e7f17bd6c4cc5b9e9db359eebd7`), wall 19.4-22.8s. Recorded in `provenance.json` under
`stability`.

### On the predecessor's "1/10 dumped" and its nonzero exits

That figure and the `ValueError: min() iterable argument is empty` that followed it were both
**instrument bugs**, and the nonzero exits it appeared to show were an artifact of the same bug.
The harness recorded a digest only when `returncode == 0` and then filtered rows to `rc == 0`, so
it could not tell "this run wrote a dump" from "this run's row was populated". Its scratch
directory held stale dumps from *earlier* invocations that it never deleted before each run, so
files present after a failed run were read as "wrote a dump but exited nonzero".

Proven by construction rather than argued: a known-good dump was planted at the output path and a
run that must fail (`--empty-stage`) was executed against it. Result — `rc=1`, and the planted file
came back **byte-identical** (`32cc0e7f17bd6c4cc5b9e9db359eebd7` before and after). The mechanism
is in the code: `run()` calls `assert_ran(evidence, spec)` **before** it opens the output file, so
a run that fails its evidence gate cannot write a dump. `rc != 0` and "a dump exists" therefore
cannot both be true of the same invocation, and the replacement harness confirms it by deciding
`dumped` from the **file's existence**, independently of `rc`, and reporting any disagreement
loudly. Over 10 runs: `rc_nonzero_but_dumped = 0`.

There was no intermittent post-dump failure. The replacement harness also refuses to print a
stability verdict below 2 dumps, rather than reporting a reassuring `worst 0.000000` over zero
pairs.

## The gate was proven able to fail

Every mutant ran against a **throwaway copy** of the tree under `$LOCALAPPDATA/Temp`; the real
worktree was never written to. Every offline acceptance line was **baselined green in the same
scratch tree** before any mutation, because a line already red at baseline registers as a kill for
every mutant run against it (bead oo-4vdc).

The first baseline attempt aborted — correctly — with two reds. Those two unit tests pin
**upstream engine source** (`OOConcreteTexture.m`'s `[texture.upload]` format string and
`logcontrol.plist`'s `$textureDebug = no` default), so that an engine refactor becomes the red
instead of silently emptying `png_texture_uploads`. The scratch tree carried no
`upstream/oolite/src`, so they could not pass there by construction. The fix was in the **harness**
— copy exactly those two files — not in the tests. **They were not deselected**: deselecting is how
a gate quietly loses the defence that makes it honest.

### `state.json` is witnessed by an independent digest; `frame.grid` deliberately is not

The one genuine hole the mutants found: perturbing one float in the stored golden by **one
quantised unit** (`market.alien_items.price` 516 -> 516.001) left the gate green, because the
golden-reading line compares the golden against **a copy of itself** — mutating it moves *both*
sides, exactly bead oo-3ya's finding about the seed. The defence has to be an **independent
witness**, so acceptance now verifies `state.json`'s byte size and sha256 against the figures
recorded in `provenance.json`. A mutant that edits the golden alone cannot satisfy it; a change
that moves both files together is a deliberate re-bless, which is what
`tools/rebless-approvals.txt` and Jon's approval exist to govern. And because that is not
sufficient on its own, mutant **D11** laundered a corrupt golden *as* a re-bless — emptying
`png_texture_uploads` and re-hashing provenance to match — to confirm the **content** checks still
hold the property with the digest satisfied by construction.

**`frame.grid` is deliberately NOT byte-hashed, and must not be.** llvmpipe is not bit-reproducible
(10 distinct grid digests over 10 byte-identical dumps), so byte-hashing the frame would make the
gate flake on renderer noise instead of catching a texture failure. It is compared with the
measured tolerance. Do not "improve" this into a hash.

### The two survivors are redundant defences, decided by reading the code

A surviving mutant means a blind gate, an equivalent mutant, or a deliberately redundant defence
(bead oo-jor) — and the way to tell them apart is to decompose, not to assume.

**C5, the 153-entry shipdata merge.** Two clauses in `check_png_evidence.py` defend it. Removed
separately and fed a golden with `png_shipdata_entries = 0` and `png_diffuse_map_sample = {}`:

| clauses removed | checker | which clause spoke |
| --- | --- | --- |
| none (control) | **rejects** | diffuse-map sample |
| the count clause | **rejects** | diffuse-map sample |
| the diffuse-sample clause | **rejects** | the 153-entry count |
| **both** | **accepts — property lost** | — |

Each defence holds the property alone and removing both flips the verdict: **deliberate
redundancy**, now pinned by `test_a_dump_with_an_incomplete_shipdata_merge_is_refused` and its
sibling, so a later refactor cannot silently collapse the pair.

**C3, the spec-vs-provenance knob drift.** Same shape across *lines* rather than clauses: deleting
the unit test's drift computation flips that test green, but acceptance line 2 recomputes the same
drift in-line and went red on the identical input (`{'seed': (20260918, 31337)}`). The property is
defended twice, in two files, by two independently written comparisons.
