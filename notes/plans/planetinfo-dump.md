# Make `OO_DUMP_PLANETINFO` build, and give #799 a review step that works

Status: **Prepare**.

## Why

On upstream PR #799 (`[C++ 01/28] Let OO_RANDOM_SEED pin the random seed`), mcarans asked on
2026-11-16 whether the `OO_DUMP_PLANETINFO` code could be fixed. They want it so they can check the
seed by hand. With the define set, upstream `master` doesn't compile. They tried it through a Meson
option they added:

```meson
option('oo_dump_planetinfo', type: 'boolean', value: false,
       description: 'Enable logging of planet info')
```

The PR's "How to review" section says to "compare the `rand.seed` line and the first system
generated". There's no log line for the first system, which is what sent them looking.

## What the code says

1. **The dump won't show `OO_RANDOM_SEED` at all.**
   - `Universe -setUpSpace` calls `seed_for_planet_description(systemSeed)` before its dump lines.
     That resets RANROT from the system's own seed (`legacy_random.c:185-189`; upstream
     `Universe.m:1388,1444`, fork `Universe.cpp:1832,1908`). `setUpPlanet` does the same
     (`Universe.m:1302`).
   - So every `planetinfo.record` line is the same whatever the start-up seed. A dump would show
     nothing for #799.
2. **For the same reason, the start-up seed may not outlive the first `setUpSpace`.**
   - Nothing saves and restores RANROT around those reseeds. So after the first system is set up,
     RANROT may be a function of the system seed only.
   - JS `Math.random`, which the populator uses 95 times (`oolite-populator.js`), isn't RANROT at
     all. The fork seeds it separately for headless runs (`Headless.h:122`).
   - **That is a hypothesis.** Step 1 checks it. If it holds, #799's "Why" is weaker than the PR
     says, and Jon needs to know before replying.
3. **`OO_DUMP_PLANETINFO` is a debug mode, not a log switch.** It also changes play, so that a
   script can jump through every system:
   - `PLAYER_MAX_FUEL` 7000 (`PlayerEntity.h:278`);
   - `MAX_JUMP_RANGE` 150 (`ShipEntity.h:105`);
   - no misjumps (`PlayerEntity.m:6763,6787`);
   - a 1 s spin-up (`OOJSPlayerShip.m:1467`, `PlayerEntityControls.m:826`);
   - `player.ship.targetSystem` writable in flight (`OOJSPlayerShip.m:921`).

   `tools/planetinfo-source/README.md` says the mode was used to generate the planet data.
4. **Known build errors in the dump code** (upstream line numbers; the fork has the same blocks at
   `Universe.cpp:1736-2040`, `PlanetEntity.cpp:388`, `SunEntity.cpp:168`):
   - `Universe.m:1370-1371`: `system_seed` isn't declared. The local is `systemSeed`, a
     `Random_Seed` with fields `a`-`f`.
   - `Universe.m:1491`: the `sun_vector` line prints `vf` before it's assigned (it's set at :1541).
     The vector it means is `sun_dir`. It compiles, but `-Wall` may warn about the uninitialised
     use, and the value is wrong.
   - The rest are found by compiling. mcarans reports "a bunch".

## Steps

1. **Check what `OO_RANDOM_SEED` changes in the fork (no code change).**
   - From `oolite-dev`, run `tests/run.sh component -k s1_police_kills_pirate` four times: twice
     with the scenario's seed, once with a different seed, and once without the env var. To change
     the seed, copy the feature into `.agent-tmp/`; don't edit the test.
   - Diff the game logs (`rand.seed`, the ship spawns, the kill time).
   - Write the result under Decisions below: which outputs, if any, differ between seeds. Don't
     judge #799 from it. Report it, and Jon decides what the PR says.
2. **Fix the dump: replaced by [planetinfo-runtime-flag.md](planetinfo-runtime-flag.md)**
   (Jon, 2026-11-16). The `#ifdef` becomes a runtime switch, `-dump-planetinfo YES`, on a branch
   prepended below 001, then ported to the fork. That plan has the steps and the done check.
3. **Port to the fork:** also in that plan.
4. **Draft Jon's reply to mcarans** in this plan, under "Reply draft". Jon posts it; agents post
   nothing on GitHub. It should say:
   - the dump is fixed on `fix/planetinfo-dump`, with how to turn it on;
   - the dump doesn't show the seed, and why (finding 1);
   - the dump mode also changes fuel, jump range and misjumps;
   - what step 1 found, and a corrected "How to review" for #799's description.

## Done check

Each command exits nonzero before the work and zero after.

- Upstream branch, from its worktree:
  `meson setup build/dump -Doo_dump_planetinfo=true && meson compile -C build/dump`. Before the
  work it fails, at the option (unknown option) or at compile.
- Fork, from `oolite-dev`:
  `./mk.sh build dev --setup-flags="-Doo_dump_planetinfo=true"`, the way CI passes `-Ddocs=enabled`.
  Afterwards, switch the option back with `./mk.sh build dev --setup-flags="-Doo_dump_planetinfo=false"`,
  then run `tests/run.sh unit` as usual.
- Step 1 and the reply draft can't be checked by a command. They're done when their sections below
  are filled in.

## Decisions (defaults taken)

- **Fix the dump, even though it doesn't answer the seed question.** mcarans asked for the fix. The
  dump build is broken in its own right, and the fix is small and contained to `#ifdef` blocks.
- **Use mcarans' option name and default.** That matches what they tried, and `false` keeps every
  normal build unchanged.
- **Don't change #799's code.** It's under review, and the reviewer can verify the seed with the
  existing `rand.seed` line. Jon may still want the `rand.seed` line to print the first three
  RANROT values, taken from a copy of the seed (`RANROTGetFullSeed()` into `RanrotWithSeed`), so
  that no draw is consumed. That would give the reviewer something to compare. Offer it in the
  reply; don't do it.
- **The upstream fix is a branch off `master`, prepended below 001** (Jon, 2026-11-16: use
  `git town prepend`). It has no C++ in it, so it can go upstream on its own.

## Out of scope

- Restoring RANROT after `setUpSpace`, if step 1 shows the start-up seed is lost. That would change
  1.93's behaviour, so it's Jon's call and would be its own task.

## Step 1 result

Run by the planner on 2026-11-16 against the fork's dev build (`build/meson_dev`, version
`1.93.1-seriesb-033-drop-oo-prefix.1`). The script is `.agent-tmp/seedcheck/run.py`, and the logs
are in `.agent-tmp/seedcheck/logs-*`.

**How:** each run launched the game through `tests/component/console.py`, then spawned 3 traders
with `system.addShips`. It recorded each new ship's `entityPersonality`, which is `Ranrot() & 0x7FFF`
when a ship is made, and its spawn position, which comes from `randf`. It did that once as soon as
the console answered, and again 3 s later. There were four runs: seed 42, seed 42 again, seed 7,
and no seed.

**Results:**
- **The env var is read.** Every seeded run logs `[rand.seed]: RANROT seeded from OO_RANDOM_SEED=<n>`.
  The unseeded runs log no such line.
- **At the main menu (no save), all four runs are identical**, the unseeded one included: the
  personalities are `20523,17839,25932`, then `14237,4333,26833`. RANROT there comes only from the
  system seed (finding 1). The start-up seed makes no difference.
- **With the scenario save loaded (what the component tests do), all four runs differ**, the two
  seed-42 runs included. Their personalities are `32456,17325,8878` and `14419,27693,18793`, and
  their ship counts are 71 and 89. Loading the save reseeds RANROT in `setUpSpace`. After that, how
  many draws have been made depends on real time, and the JS populator uses `Math.random`.

**Conclusion (for Jon to judge):** `OO_RANDOM_SEED` is read and logged. In neither case did it change
or pin any RANROT draw I could observe, so the component scenarios aren't made repeatable by it.
That bears on #799's "Why", and on the comment in `console.py:106-107`.

A second probe, `player.ship.entityPersonality`, is drawn in `PlayerEntity::setUpAndConfirmOK`. It was `27313` in all eight runs, with the save and without. The standard scenario save stores `entity_personality`, and the main menu loads the same commander.

The probe only sees draws made after the console answers. If anything draws from RANROT between
`GameController` init and the first `setUpSpace`, that would depend on the seed, and this probe
can't see it.

## Reply draft

Drafted by the planner on 2026-11-16 for Jon to edit and post. It assumes Jon closes #799. If he
doesn't, drop the last paragraph.

> @mcarans Thanks for digging into this. You were right that there was nothing to see, and it
> turned out to be more than a logging gap. I tested it properly: four runs each at the main menu
> and from the standard scenario save, with seed 42 twice, seed 7 and no seed. I compared values
> that come straight from RANROT (the `entityPersonality` of freshly spawned ships, and their spawn
> positions).
>
> - At the main menu, all four runs are identical, including the one with no seed.
> - From the save, all four differ, including the two with seed 42.
>
> The reason is that `-setUpSpace` and `-setUpPlanet` call `seed_for_planet_description()`, which
> resets RANROT from the system's own seed. That happens before the first frame and again on every
> jump and load, so the start-up seed is gone before anything could use it. After that, real-time
> frame timing and JS `Math.random` (which the populator uses) make each run different anyway. So
> my "How to review" was wrong, and so was the PR's premise: on its own, `OO_RANDOM_SEED` doesn't
> make runs repeatable.
>
> `OO_DUMP_PLANETINFO` wouldn't have shown it either. Everything it logs is generated from the
> system seed, so the dump is the same with any seed or none. That's by design: it's the mode the
> planet data was generated with. It's also more than a log switch: it gives 7000 fuel, a 150 ly
> jump range, no misjumps and a 1 s spin-up, so a script can tour every system. The build is broken
> regardless (for example, `system_seed` is undeclared in `-setUpSpace`, and the `sun_vector` line
> prints `vf` before it's set), so I'll fix it in a separate PR against master, and make it a runtime switch (`-dump-planetinfo YES`)
> rather than an `#ifdef`, so it can't rot again.
>
> I'll close this PR. In the C++ series, repeatable runs come from the headless test mode instead.
> It pins the clock to a fixed step and seeds `Math.random` as well as RANROT, so it isn't needed
> as a separate first step.
