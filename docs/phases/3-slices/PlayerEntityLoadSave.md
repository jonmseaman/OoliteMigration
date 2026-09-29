# Slice plan: PlayerEntityLoadSave

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-0fvy). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/PlayerEntityLoadSave.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/PlayerEntityLoadSave.mm` (1,529 lines) + header (96 lines). Two
  `PlayerEntity` categories, `LoadSave` (the public load/save/scenario entry points) and
  `OOLoadSavePrivate` (the commander-file browser and the native save writer), plus a one-method
  `MyOpenGLView (OOLoadSaveExtensions)` category and a dozen small string/credit helpers.
- **Shape:** the categories become `PlayerEntity` member functions defined in
  `PlayerEntityLoadSave.cpp` (the per-file recipe's "`@interface X (Feature)` in its own file"
  row). The free helpers contain no Objective-C and stay verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9).
- **Order:** after the `ooentity` pattern seam (oo-bj8) and once the `PlayerEntity` class
  shell is C++ (frontier, oo-a70, which converts the category files through these slices). The two slices only define
  `PlayerEntity` member functions declared in the header or the preamble, so either can go first.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | `LoadSave`: load, save, autosave, quicksave, scenarios, commander input handlers, `loadPlayerFromFile:asNew:` | ~720 | ~970 |
| 2 | `OOLoadSavePrivate`: native save writer, load/save/overwrite screens, `lsCommanders`, `showCommanderShip:`; `MyOpenGLView` extension | ~540 | ~790 |
| verbatim | string / file-name / deci-credit helpers | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Entities/PlayerEntityLoadSave.mm
header: upstream/oolite/src/Core/Entities/PlayerEntityLoadSave.h

slice 1: LoadSave category: entry points, scenarios, commander input, loadPlayerFromFile
  @PlayerEntity(LoadSave)

slice 2: OOLoadSavePrivate category: save writer and the commander browser screens
  @PlayerEntity(OOLoadSavePrivate)
  @MyOpenGLView(OOLoadSaveExtensions)

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
