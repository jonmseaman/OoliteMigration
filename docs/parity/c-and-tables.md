# Parity findings: C sources and tables

Rule 9: C stays C. These files should be byte-identical to upstream apart from include/guard plumbing.
Checked with `diff --strip-trailing-cr upstream/oolite/src/<f> src/<f>`.

| File | Diff lines | Verdict | Note |
|---|---|---|---|
| `Core/Debug/OOTCPStreamDecoder.c` | 0 | ✅ | identical |
| `Core/MiniZip/ioapi.c` | 0 | ✅ | identical |
| `Core/MiniZip/unzip.c` | 0 | ✅ | identical |
| `Core/OOPlanetData.c` | 0 | ✅ | identical |
| `SDL/EXRSnapshotSupport/miniz.c` | 0 | ✅ | identical |
| `Core/legacy_random.c` | 4 | ✅ | `sReallyRandomInited` and its assignment wrapped in `#ifndef NDEBUG` (it is only read by `assert`). This silences an unused-variable warning in release builds; behaviour is unchanged (src/Core/legacy_random.c:220-239). |
| `Core/OOVoxel.m` → `Core/OOVoxel.c` | 1 | ✅ | renamed to `.c`; the only change is `#import "OOMaths.h"` → `#include`. Body identical (197 lines each). |
| `SDL/EXRSnapshotSupport/OOSaveEXRSnapshot.cpp` | 1 | ✅ | added `#include <cstring>` |
| `Core/Tables/*.tbl` (11 files) | 0 each | ✅ | identical; same file set on both sides |

**Status:** done. No behavioural differences.
