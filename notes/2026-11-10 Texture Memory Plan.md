# Memory: decoded texture pixels held in RAM

| | |
|---|---|
| **Type** | Improvement plan (measured; cause partly attributed) |
| **Branch** | None yet. Baseline is `seriesb/026-migration-completion` at `977698a93` |
| **Introduced by** | Nothing in the fork. Upstream behaves the same way |
| **Priority** | Medium. It is the one part of the footprint that code can cut by hundreds of MB |

## Summary

On a Retina Mac the game uses about 1.4 GB docked and about 1.66 GB in flight. Upstream's build,
on the same machine and save, uses 1.07 GB and 1.35–1.4 GB. The fork's extra ~300 MB comes from
two loaded add-ons and a larger window, not from the migration.

Most of the footprint is expected for the resolution: GPU textures and framebuffers, Apple's GL
driver, and AppKit. About **400 MB is texture pixel data decoded on the CPU and still on the heap**
(fork 425 MiB in 123 blocks; upstream 379 MiB in 113). That is the target here. The first job is
to find which textures own those blocks and why they are still held. The fix depends on the answer.

## Measurements (2026-11-10, Apple M5, macOS 26.6)

Method: load `Resources/Scenarios/oolite-standard.oolite-save`, wait until docked, launch, and
measure with `footprint`. Malloc stack logging (`MallocStackLogging=1`, `malloc_history
-allBySize`) attributed the large blocks.

| | Fork | Upstream |
|---|---|---|
| Footprint, docked | 1379 MB | 1073 MB |
| Footprint, 10 s into flight | 1659 MB | 1351 MB |
| `MALLOC_LARGE`, docked and in flight (unchanged) | 689 MB | 565 MB |
| GPU (`IOAccelerator`), in flight | 489 MB | 411–467 MB |
| Live blocks from the texture loader (`OOTextureLoader::applySettings` realloc) | 425 MiB / 123 | 379 MiB / 113 |
| Live blocks from PNG decoding (`OOPNGTextureLoader::doLoadTexture`) | 91 MiB / 32 | 77 MiB / 29 |
| AppKit image catalog (`Cocoa_RegisterApp`, from SDL) | 153 MiB | 153 MiB |
| Render-target copies in the GL driver (`drawTargetTextureIntoDefaultFramebuffer`) | ~210 MiB | ~140 MiB |
| Window surface | 2920 × 1834 | 2560 × 1440 |
| Managed add-ons loaded | Svengali Library, SystemMap | none |

Two things stand out:

- Launching and drawing the scene **did not reduce** `MALLOC_LARGE`. The same 689 MB was live
  docked and in flight.
- `console.writeMemoryStats()` reports 136 "MiB" of texture data for the fork and 151 for upstream.
  That figure is **texels, not bytes**. `OOTexture::dataSize()` (`src/Core/Materials/OOTexture.cpp`,
  same in upstream's `OOTexture.m`) multiplies width × height × faces × 4/3 for mipmaps, but never
  by bytes per pixel. At 3–4 bytes per texel, 136 M texels is 400–540 MB, which matches the 425 MiB
  on the heap. So this is probably not a leak. Step 1 checks that.

## How texture memory is held now

1. `OOTextureLoader::performAsyncTask` decodes the image on a worker thread into `_data`, then
   `applySettings` reallocs it to hold the mip chain.
2. Nothing happens until the texture is first drawn. `OOConcreteTexture::apply()` calls
   `setUpTexture()`, which takes the pixels from the loader (`getResult`) into `_bytes`, then
   `uploadTexture()`.
3. After upload, `_bytes` is freed **only if `isReloadable()`**, which means the texture has a
   file `_path`. On a graphics reset, `forceRebind()` makes a new loader from that path.
4. Textures from a generator (planet, atmosphere, normal maps:
   `OOTexture::textureWithGenerator`) have no path. They keep `_bytes` for their whole life, so
   a graphics reset can upload them again.
5. `sRecentTextures` (`OOCache`, `kRecentTexturesCount = 50`) keeps recently used textures alive
   after their last user goes away. So their CPU pixels stay too, if they were never drawn or
   never freed.

So a texture's pixels stay on the CPU when it is:

- **(A) Loaded but never drawn.** It is still sitting in its loader, for example for a ship that
  spawned off screen or a material that was built but not used.
- **(B) Not reloadable.** Generated textures keep their pixels permanently.
- **(C) Kept alive by the cache** while in state A or B.

## Plan

Each step needs a command that fails before and passes after (see the agent contract). The steps
are ordered so the measurements decide what to build.

### Step 1: Make the memory statistics report bytes, and split them by state

- Add `OOTexture::cpuResidentBytes()`. It reports bytes held in `_bytes`, or in the pending
  loader's `_data`, with format components and the mip chain included.
- Add `gpuBytes()`, the estimated uploaded size.
- Log the state of each texture: `pending-loader`, `loaded-not-uploaded`, `uploaded-retained`,
  `uploaded-freed`.
- Keep `dataSize()` as upstream has it, so the existing `writeMemoryStats` output keeps its
  meaning. Add the new figures as extra lines.
- **Verify:** a new unit test in `tests/unit/core/test_OOConcreteTexture.cpp`. A 64×64 RGBA
  mipmapped texture reports `64*64*4*4/3` CPU bytes before `apply()`. After upload it reports 0
  if it was loaded from a path, and the same bytes if it came from a generator. Run with
  `tests/run.sh unit`.

### Step 2: Attribute the ~400 MB

- Run the measurement in "Reproducing" below with the new statistics.
- Record bytes per state (A, B, C) and the top 20 textures by CPU bytes, with their keys.
- Do it docked, after 10 s in flight, and after 60 s in flight, with and without the two
  managed add-ons.
- Write the table into this note. **Decide steps 3–4 from it.** If A is small, skip step 3.
  If B is small, skip step 4.

### Step 3 (if A dominates): free pixels promptly for textures that are never drawn

Options, in order of preference:

1. **Upload in the background on the main thread.** Each frame, upload up to N finished loaders
   (a byte budget per frame, for example 16 MB) whether or not anything has drawn them. Pixels
   from path-loaded textures are freed as soon as they upload. The extra cost is GPU memory for
   textures that are never drawn, which is cheaper than CPU memory on unified-memory Macs and
   costs no more than it does today on discrete GPUs.
2. **Drop pixels for never-drawn textures when the cache evicts them.** Smaller change, but it
   only helps state C.
3. **Load lazily on first draw.** It saves the most, but brings back the first-sight stutter that
   asynchronous loading exists to avoid. Not recommended.

**Verify:** a unit test that a loader which has finished frees its CPU bytes once the per-frame
upload hook runs, with no `apply()` call. Then the step-2 measurement shows state A near zero.

### Step 4 (if B dominates): make generated textures reloadable without keeping pixels

- Generated textures are deterministic: same seed, same parameters, same pixels.
- Keep a way to build the loader again (the generator's parameters) instead of `_bytes`. Then
  `isReloadable()` is true and `forceRebind()` regenerates the texture.
- A graphics reset then pays for regenerating planets (tens of ms each on a worker thread) rather
  than holding their pixels forever.
- **Verify:**
  - A unit test that a generator texture frees `_bytes` after upload.
  - A unit test that `forceRebind()` produces identical pixels. Read them back with
    `copyPixMapRepresentation` and compare.
  - `test_OOGraphicsResetManager.cpp` still passes.
  - A manual or GUI check: toggle full screen on Windows, where the context is recreated, and the
    planet still renders.

### Step 5 (optional, separate feature): compressed textures

- Colour textures could be stored as BC1/BC3 (`GL_EXT_texture_compression_s3tc` is present on the
  M5 and on mainstream Windows and Linux GPUs).
- That cuts GPU memory about 4–6× and, if the pixels are compressed before they are kept, CPU
  memory too.
- Costs: CPU time to encode at load, or pre-compressed assets; quality loss on HUD and UI
  textures, which should be excluded; and a change in look, which upstream would need to agree to.
- Treat as its own spec, not part of this plan.

### Out of scope

- **Window size and Retina.** Framebuffers and driver copies scale with the pixel size of the
  window. A "render at 1×" option (SDL without high pixel density) would roughly halve them. That
  is a user setting, not a fix.
- **AppKit image catalog (153 MiB).** It is mapped by SDL's Cocoa menu setup and is the same in
  every build.
- **System descriptions (~35 MB in ~330,000 small map-node allocations).** Wasteful, but small. Revisit if
  `OOSystemDescriptionManager` is reworked for other reasons.

## Risks

- **Graphics reset.** Windows recreates the GL context when the window changes, and every texture
  must survive that. Steps 3 and 4 change what `forceRebind()` relies on.
- **Upload stalls.** Background uploads must stay inside a per-frame budget. A system with many
  new ships must not drop frames on arrival.
- **Upstream parity.** Visible behaviour must not change. The extra statistics are additions; the
  existing `writeMemoryStats` lines keep upstream's meaning. Steps 3–4 are candidates to send
  upstream, since upstream has the same footprint.

## Reproducing

The scratch scripts live in `.agent-tmp/hudrepro/` (git-ignored). Move them under `tools/` if this
plan goes ahead. Each wraps `oolite-dev/tests/launch_snapshot.py` and stages a private copy of the
app.

```bash
# footprint docked, then 10 s and 40 s into flight
python3 .agent-tmp/hudrepro/measure_mem.py <oolite.app/Contents/MacOS> <out-dir> <port>
# malloc stacks of every live allocation while docked (the output is about 1 GB)
python3 .agent-tmp/hudrepro/malloc_docked.py <oolite.app/Contents/MacOS> <out-dir> <port>
python3 .agent-tmp/hudrepro/topsites.py <out-dir>/malloc_history.txt 15
# console.writeMemoryStats() into <out-dir>/Latest.log
python3 .agent-tmp/hudrepro/memstats.py <oolite.app/Contents/MacOS> <out-dir> <port>
```

The fork's app is `oolite-dev/build/meson_deployment/oolite.app`; upstream's is
`upstream/oolite/build/meson_deployment/oolite.app`. Use a different port for each run. The game
window opens and must not be closed until the script quits it.
