# Slice plan: OODefaultShaderSynthesizer

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-t61j). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OODefaultShaderSynthesizer.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Materials/OODefaultShaderSynthesizer.mm` (1,629 lines) + header (46 lines).
  The header only declares the entry point `OOSynthesizeMaterialShader`; the class
  `OODefaultShaderSynthesizer` is declared in the `.mm` itself (its `@interface` is part of the
  ~300-line preamble). After the class come the material-specifier canonicalisation functions.
- **Shape:** three slices: (1) the class shell, entry point, lifecycle, the variable/uniform
  declaration helpers and texture bookkeeping; (2) the shader stages (`write*`) with the
  temporaries they share; (3) the free functions that canonicalise a material specifier
  (`CanonicalizeMaterialSpecifier` and the helpers that still use Objective-C).
- **Order:** slice 1 (class shell) first; slices 2 and 3 are independent of each other. This is a
  `Materials` file: it waits for the Materials pattern seam (oo-smy).

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | entry point, class shell, lifecycle, declarations, texture IDs and reads | ~460 | ~805 |
| 2 | shader stages `write*`, temporaries | ~560 | ~905 |
| 3 | material-specifier canonicalisation | ~270 | ~620 |
| verbatim | small string/specifier helpers | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Materials/OODefaultShaderSynthesizer.mm
header: upstream/oolite/src/Core/Materials/OODefaultShaderSynthesizer.h

slice 1: entry point, class shell, lifecycle, declarations, texture bookkeeping
  @OODefaultShaderSynthesizer
  OOSynthesizeMaterialShader()

slice 2: the shader stages and their temporaries
  -[OODefaultShaderSynthesizer write*]
  -[OODefaultShaderSynthesizer createTemporaries]
  -[OODefaultShaderSynthesizer destroyTemporaries]

slice 3: material-specifier canonicalisation
  CanonicalizeMaterialSpecifier()
  ColorIn()
  NormalizedArray()

verbatim: plain C++ helpers, no Objective-C (checked)
  *
```
