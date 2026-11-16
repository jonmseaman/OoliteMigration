---
status: Review
parent: seriesb/032-cleanup
---
# Move `oo::fs` onto SDL3 and `std::filesystem`

Related: [oofnd-shrink.md](oofnd-shrink.md). That card keeps `fs::pathFromUTF8` and `writeFile`;
this card does the rest of `src/oofnd/FileSystem.hpp`.

## Context

`FileSystem.hpp` (about 450 lines) already sits on `std::filesystem`, but it adds GNUstep's
answers on top:
- `removeItem` fails on a missing path.
- `moveItem` never overwrites.
- `createDirectories` reports `not_a_directory` when a file is in the way.
- `directoryContents` returns names only.
- `RecursiveDirectoryEnumerator` copies NSDirectoryEnumerator.

Players can't see any of that. On `seriesb/032-cleanup`, Jon allows answers that aren't
byte-exact (2026-11-15). SDL3 is already linked, it takes UTF-8 paths on every platform, and it
covers most of these jobs. Spec 009 decision 11 (keep thin helpers that read better) is replaced
here: under the 032 allowance, removing the GNUstep layer matters more than how the call sites read.

## What stays (because players can see it)

- **Atomic save:** write a temporary file, then rename it over the target. Without this, a crash
  mid-save loses the commander. `oo::fs::writeFile(kAtomic)` stays.
- **UTF-8 paths on Windows:** `pathFromUTF8`/`utf8String` stay wherever a `std::filesystem::path`
  is built. Without them, a non-ASCII profile name such as `C:\Users\Jörg` breaks saves and
  expansions.
- **The expansion scan doesn't follow directory symlinks,** so a looped link can't hang the start-up
  scan.
- **`/` in paths built for the cache and the log** (`utf8String` uses `generic_u8string`). This
  costs nothing, and it avoids a cache rebuild on every Windows install.
- `OODataFromOXZFile` / `OOOxzFileExistsAtPath`, which read paths inside a zip, are unchanged.

## Where each part goes

| `oo::fs` | Replacement | Callers |
|---|---|---|
| `fileExists`, `isDirectory`, `fileType`, `fileSize`, `modificationTimeSince1970` | `SDL_GetPathInfo` | about 23 game sites (`ResourceManager`, `GameController`, `OOOXZManager`, `OOCacheManager`, `PlayerEntityLoadSave`, …) |
| `freeSpace` | `std::filesystem::space` (SDL has none) | `OOOXZManager` |
| `currentDirectory`, `setCurrentDirectory` | `SDL_GetCurrentDirectory` / `std::filesystem::current_path` | `GameController` |
| `directoryContents` | `SDL_GlobDirectory(path, nullptr, 0, &n)` | `PlayerEntityLoadSave.cpp:1042`, `OOOXZManager.cpp:751`, `ResourceManager.cpp:640` |
| `createDirectories` | `SDL_CreateDirectory` | about 10 sites (snapshots, saves, logs, cache, OXZ install) |
| `moveItem` | `SDL_RenamePath` | `OOOXZManager.cpp:907-909`, where remove-then-move becomes one rename |
| `removeItem` | `std::filesystem::remove_all` (`SDL_RemovePath` won't delete a folder that isn't empty) | `OOOXZManager`, `OOCacheManager.cpp:264` |
| `RecursiveDirectoryEnumerator` | `std::filesystem::recursive_directory_iterator` (it doesn't follow directory symlinks by default) | `ResourceManager.cpp:501`, `OOFileScannerVerifierStage.cpp:333,510` |
| `createFileForWriting`, `synchronizeFile` | `SDL_IOFromFile(path, "wb")`, `SDL_FlushIO` | the OXZ download |
| `readFile` in Core | `SDL_LoadFile` | Core callers; `oofnd`'s own callers keep `oo::fs::readFile` |

`FileSystem.hpp` keeps `Path`, `pathFromUTF8`, `utf8String`, `readFile`, `writeFile` and the two
`.oxz` declarations, about 120 lines.

## Tasks (each is its own commit)

1. **Test the SDL behaviour the game relies on** (`tests/unit/core/test_sdl_filesystem.cpp`):
   - `SDL_RenamePath` replaces an existing file on Windows and POSIX.
   - `SDL_CreateDirectory` creates intermediate folders and succeeds when the folder exists.
   - `SDL_GetPathInfo` follows symlinks.
   - The UTF-8 non-ASCII round trip works.

   Write this first. If a row fails, keep the `oo::fs` function for that row and note it below.
2. **Query functions → `SDL_GetPathInfo`.** Done when
   `! git grep -qE 'fs::(fileExists|isDirectory|fileType|fileSize|modificationTimeSince1970)\(' -- src ':!src/oofnd'`.
3. **Directory operations** (`directoryContents`, `createDirectories`, `moveItem`, `removeItem`,
   `freeSpace`, current directory). Done when the same grep over those names exits nonzero.
4. **Enumerator → `recursive_directory_iterator`** at the 3 sites, with `disable_recursion_pending`
   doing the job of `skipDescendents`. Done when `! git grep -q RecursiveDirectoryEnumerator -- src`.
5. **OXZ download I/O → `SDL_IOStream`.** Done when
   `! git grep -qE 'createFileForWriting|synchronizeFile' -- src`.
6. **Delete the functions nobody uses any more from `FileSystem.hpp`** and update the header comment
   and `src/oofnd/README.md`.

## Test edits

`tests/unit/oofnd/test_filesystem.cpp` pins the GNUstep-only answers. Its cases for the deleted
functions are removed or moved to `test_sdl_filesystem.cpp`. The `tests/unit/core` tests that call
`oo::fs` for setup (`test_ResourceManager`, `test_OOCacheManager`, `test_GameController`, …) switch to
`std::filesystem`. Every edit goes in `notes/kanban/oofnd-shrink-test-ledger.md` under Jon's
2026-11-15 allowance: file, old form, new form, and whether the meaning is kept. Confirm the hard
rule 1 date at approval.

## Decisions (defaults taken)

- **`oofnd` doesn't link SDL.** The SDL calls go in Core, and `oofnd`'s own file users (`LogFile`,
  `Defaults`, `Http`, `ResourcePaths`) keep `std::filesystem`. That keeps `tests/run.sh unit`'s
  `oofnd` suite free of SDL.
- **No PhysicsFS.** Mounting `.oxz` files would be a separate redesign of `ResourceManager`.
- **No Windows UTF-8 code-page manifest** (`activeCodePage`). It would change every ANSI API in the
  process; `pathFromUTF8` is enough.
- **Save, log and settings locations don't move** (see oofnd-shrink Wave 5).

## Verification

- Each task: its grep check, `./mk.sh build dev` (no new warnings), `tests/run.sh unit`.
- At the end: `tests/run.sh component` and `tests/run.sh smoke`, then in the game: save, load,
  install and remove an OXZ, and take a snapshot.
- On Windows, from a user profile with a non-ASCII name: launch, save, and install an OXZ.
