# Slice plan: OOTextureScaling

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-k7v8). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOTextureScaling.md`, which recounts the
file every time, so the numbers below are only a snapshot.

- **File:** `Core/OOTextureScaling.mm` (1,709 lines) + header (47 lines). **No class**: thirty
  C functions (pixmap scaling and mipmap generation). The generator counted it as a conversion
  file only because three functions still raise with `[OOException raise:format:]`.
- **Shape:** one small slice. Those three functions (`SqueezeVertically`,
  `StretchHorizontally`, `SqueezeHorizontally`, the format-dispatch wrappers) replace the
  message send with the C++ throw the house style uses for `OOException`; every other function
  is plain C and stays byte-for-byte verbatim ([ADR-0012](../../decisions/0012-c-stays-c.md),
  CLAUDE.md rule 9). The story must not touch the scaler bodies.
- **Order:** one slice; no dependency inside the file. `StretchVertically` appears twice
  (preprocessor alternatives), both verbatim.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | the three dispatch wrappers that raise `OOException` | ~85 | ~355 |
| verbatim | every scaler, mipmap generator and helper | — | not read |

```slice-plan
source: upstream/oolite/src/Core/OOTextureScaling.mm
header: upstream/oolite/src/Core/OOTextureScaling.h

slice 1: the format-dispatch wrappers that raise OOException
  SqueezeVertically()
  StretchHorizontally()
  SqueezeHorizontally()

verbatim: plain C scalers and mipmap generators, no Objective-C (checked)
  *
```
