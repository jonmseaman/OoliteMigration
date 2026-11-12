# Data model: Third-party code by wrap

The "data" here is build configuration: four wraps, what each brings in, and how the game asks for
it. Field rules are in [contracts/wraps.md](contracts/wraps.md).

## Wraps

| Field | miniz | minizip | tinyexr | stb |
|---|---|---|---|---|
| File | `subprojects/miniz.wrap` | `subprojects/minizip.wrap` | `subprojects/tinyexr.wrap` | `subprojects/stb.wrap` |
| Kind | `[wrap-file]`, WrapDB 3.1.2-1 (`wrapdb_version`) | `[wrap-file]`, custom | `[wrap-file]`, custom | `[wrap-file]`, custom |
| Source | `miniz-3.1.2.zip` (GitHub release, as WrapDB names it) | `zlib-1.4.tar.gz` (GitHub release asset) | `archive/refs/tags/v3.4.0.tar.gz` | `archive/<full hash of 48fb1c9>.tar.gz` |
| Fallback URL | WrapDB's mirror (as published) | `https://zlib.net/zlib-1.4.tar.gz` | none | none |
| `directory` | `miniz-3.1.2` (WrapDB) | `minizip-zlib-1.4`, `lead_directory_missing = true` (R3) | `tinyexr-3.4.0` | `stb-<full hash>` |
| Overlay | WrapDB's `miniz` packagefiles (downloaded) | `packagefiles/minizip/meson.build` (fork) | `packagefiles/tinyexr/meson.build` (fork) | `packagefiles/stb/meson.build` (fork) |
| Patches | none | `minizip/0001-unzOpenCurrentFile3-reject-unsupported-method.patch` | none | none |
| Provides | `miniz` | `minizip` | `tinyexr` | `stb` |
| Builds | `library('miniz', 'miniz.c')`, made static by the request | `static_library` of `ioapi.c`, `unzip.c` | nothing (headers) | nothing (headers) |
| Needs | — | `dependency('zlib')` (system, as the game already uses) | `dependency('miniz')` | — |
| Licence file shipped in the source | `LICENSE` (MIT) | `contrib/minizip/` headers' notice (zlib licence); zlib's `LICENSE` | `LICENSE` (BSD-3-Clause) | `LICENSE` (MIT / public domain) |
| Hosts | Windows | all | Windows | all |

Hashes and stb's full commit hash are filled in at M1 (research R3, R5).

## The game's requests (`src/meson/meson.build`)

| Order | Dependency | Condition | `default_options` | Appended to |
|---|---|---|---|---|
| 1 | `minizip` | — | none (the overlay builds a static library itself) | `oolite_dependencies` |
| 2 | `stb` | — | none | `oolite_dependencies` |
| 3 | `miniz` | `host_machine.system() == 'windows'` | `['default_library=static']`, plus the MinGW definition if M1 needs it (R2) | `oolite_dependencies` |
| 4 | `tinyexr` | same | none | `oolite_dependencies` |

`force_fallback_for` lists `quickjs-ng`, `miniz`, `minizip`, `stb`, `tinyexr`, one per line (R7).

## The patch

| Patch | Origin | What it does | Why it is still needed |
|---|---|---|---|
| `0001-unzOpenCurrentFile3-reject-unsupported-method.patch` | 96f39f346 (2013, "Fix some warnings") | When an entry's compression method is not stored, deflate or bzip2, frees the read state and returns `UNZ_BADZIPFILE` | zlib 1.4 still sets the error, keeps the read state and returns `UNZ_OK` |

## Local edits not carried

Every row of the spec's edit table marked *dropped* stays dropped, for the reason given there.
No patch is written for any of them. The suites and the snapshot test check at M2 that dropping
them changed nothing: stb's negative clamp is assertion S2.3 of the snapshot test.

## Ledger (`test-ledger.md`, created at M0)

One row per edit under `oolite-dev/tests/`: file, entry, before, after, reason, FR. Expected rows:
the `test_OOSnapshotWriters` entry and file (M0, addition), and the three MiniZip source paths
removed from `test_OOALSoundDecoder`, `test_OOALBufferedSound` and `test_OOALStreamedSound` (M2,
FR-014).
