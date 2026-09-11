# I1 — Base images and build caches

**Status:** not started · **Gates:** Phase 0 items 0.2, 0.9 (Tier A/B timing is meaningless without this)

## Goal

Stop paying the GNUstep-from-source and MSYS2-provisioning cost on every run. This is the single
change most likely to cut iteration time, more than any model choice.

## Work items

1. **Bake GNUstep into an image.** `ShellScripts/Linux/build_gnustep.sh` pins its inputs by commit
   hash, so the result is reproducible and cacheable. Build `oolite-ci-linux:gnustep-<pin>` once,
   rebuild only when a pin moves. This likely cuts iteration time
   more than any other single change.
2. **Pre-provision MSYS2 on the Windows runner.** The hosted workflow spends real time on
   `msys2/setup-msys2@v2` plus `ShellScripts/Windows/install_deps.sh clang` on every run. On a
   self-hosted box you install UCRT64 and the dependencies **once**. This also removes the main
   third-party-action dependency, which is what would otherwise block a Forgejo port later.
3. **Shared compiler cache.** `ccache` or `sccache` with one cache volume shared across every agent
   worktree and the Linux runner containers. Measure hit rate; it should be high because agents
   touch one file at a time.
4. **Golden harness container.** One scenario per container, Xvfb inside, port and `DISPLAY`
   parameterised (today `tests/launch_snapshot.py` hardcodes `PORT = 8563`, `HOST = 127.0.0.1`).
   Emits the canonical sorted-JSON state dump as its artifact. Built on the GNUstep base image.
   Specified in Phase 0 item 0.4; the *image* lives here.
5. **Audio and video env** baked in: `SDL_VIDEODRIVER=offscreen` for goldens, Xvfb + `DISPLAY` for
   the GUI tier, `SDL_AUDIODRIVER=dummy` / `ALSOFT_DRIVERS=null` always. CI machines have no audio
   device and OpenAL init failure otherwise masquerades as a launch failure.

## Verification

- [ ] `oolite-ci-linux:gnustep-<pin>` builds once and is pulled, not rebuilt, by CI
- [ ] A Linux Tier-B run on a warm cache completes in under 10 minutes end to end
- [ ] Windows runner: `mk.sh build` succeeds with no `setup-msys2` step
- [ ] 20 golden containers run concurrently in WSL2 without port or display collisions, with the Windows build still able to run alongside
- [ ] ccache hit rate reported by the Reporter

## Status log

- 2026-09-06 — Created from AI_EXECUTION_PLAN §4.2 and §14.4.
