# I1 — Provisioning and build caches

**Status:** not started · **Gates:** Phase 0 items 0.2, 0.9 (Tier A/B timing is meaningless without this)

## Goal

Stop paying upstream's per-run provisioning cost. Upstream's Windows job runs `msys2/setup-msys2`
and `ShellScripts/Windows/install_deps.sh clang` on every run; here the machine is provisioned
**once**, scripted and idempotent, and every build after that is incremental behind `ccache`. This
is the single change most likely to cut iteration time, more than any model choice.

## Work items

1. **`tools/setup-windows.sh`** (Phase 0 item 0.2). From an MSYS2 UCRT64 shell: upstream's
   `install_deps.sh clang`, `mingw-w64-ucrt-x86_64-mesa` (the llvmpipe `opengl32.dll` the goldens
   copy beside the binary, as `tests/run_test_fn.sh` already does), `ccache`, `jq`, Python with
   `pytest` and `pyautogui`. Running it twice installs nothing the second time. Pins recorded in
   the script; a pin move is the only reason to re-run.
2. **Shared compiler cache.** `ccache` with one cache directory on NVMe shared across every agent
   worktree and the verification worktrees. Measure hit rate; it should be high because agents
   touch one file at a time.
3. **Golden harness environment.** `SDL_AUDIODRIVER=dummy` / `ALSOFT_DRIVERS=null` always; port and
   output directory per process (today `tests/launch_snapshot.py` hardcodes `PORT = 8563`); the
   Mesa DLL beside the binary. Specified in Phase 0 item 0.4; the provisioning lives here.
4. **GUI tier environment.** Real window, no `SDL_VIDEODRIVER` override, desktop unlocked
   ([I0 checklist](0-machines.md)); PyAutoGUI installed by item 1.
5. **Phase 5:** the Linux flow (`ShellScripts/Linux/build_gnustep.sh` pinned, `mozillajs-linux`)
   comes back as a container image or a rented box; not before ([ADR-0017](../decisions/0017-native-windows-subtree.md)).

## Verification

- [ ] `tools/setup-windows.sh` run twice: the second run installs nothing
- [ ] `./mk.sh build test` succeeds with no `setup-msys2` step and no `install_deps.sh` run
- [ ] A Tier-B run on a warm cache completes in under 10 minutes end to end
- [ ] N golden processes run concurrently without port or output collisions, with a build running alongside
- [ ] ccache hit rate reported by the Reporter

## Status log

- 2026-09-06 — Created from AI_EXECUTION_PLAN §4.2 and §14.4 (base images, WSL2).
- 2026-09-11 — Rewritten for native Windows: one-time MSYS2 provisioning instead of images (ADR-0017).
