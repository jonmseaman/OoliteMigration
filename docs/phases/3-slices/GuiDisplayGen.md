# Slice plan: GuiDisplayGen

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-ukoi). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/GuiDisplayGen.md`, which recounts the
file every time, so the numbers below are only a snapshot.

- **File:** `Core/GuiDisplayGen.mm` (2,766 lines) + header (393 lines). One class,
  `GuiDisplayGen` (the text/menu GUI screen), in a single `@implementation` block, plus five
  small plain C++ string helpers that stay verbatim.
- **Shape:** four slices. `drawStarChart:x:y:z:alpha:` alone is ~600 lines, so it is a slice of
  its own; the other drawing code is a second slice; text layout and background/foreground
  textures a third; the class shell with its rows, selection, colours and fades the first.
- **Order:** slice 1 (class shell) first; 2, 3 and 4 are independent of each other.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell, sizing, colours, fades, rows, selection, tab stops, set text | ~655 | ~1,125 |
| 2 | long text, reflow, printing, arrays, scrolling, GUI textures, equipment list | ~705 | ~1,175 |
| 3 | drawing: GUI, GL display, cross-hairs, system markers, advanced nav array | ~690 | ~1,160 |
| 4 | `drawStarChart:x:y:z:alpha:` | ~600 | ~1,070 |
| verbatim | string helpers | — | not read |

```slice-plan
source: upstream/oolite/src/Core/GuiDisplayGen.mm
header: upstream/oolite/src/Core/GuiDisplayGen.h

slice 1: class shell, sizing, colours, fades, rows and selection
  @GuiDisplayGen

slice 2: text layout and printing, arrays, scrolling, GUI textures, equipment list
  -[GuiDisplayGen cxx_addLongText:startingAtRow:align:]
  -[GuiDisplayGen cxx_reflowTextForMFD:]
  -[GuiDisplayGen leaveLastLine]
  -[GuiDisplayGen cxx_getLastLines]
  -[GuiDisplayGen cxx_printLongText:align:color:fadeTime:key:addToArray:]
  -[GuiDisplayGen cxx_printLineNoScroll:align:color:fadeTime:key:addToArray:]
  -[GuiDisplayGen cxx_setArray:forRow:]
  -[GuiDisplayGen cxx_insertItemsFromArray:withKeys:intoRow:color:]
  -[GuiDisplayGen scrollUp:]
  -[GuiDisplayGen clearBackground]
  DescriptorName()
  TextureForGUITexture()
  NewTextureSpriteWithDescriptor()
  -[GuiDisplayGen setBackgroundTextureSpecial:withBackground:]
  -[GuiDisplayGen cxx_set*TextureDescriptor:]
  -[GuiDisplayGen cxx_set*TextureKey:]
  -[GuiDisplayGen cxx_preloadGUITexture:]
  -[GuiDisplayGen cxx_textureDescriptorFromJSValue:inContext:callerDescription:]
  -[GuiDisplayGen setStatusPage:]
  -[GuiDisplayGen statusPage]
  -[GuiDisplayGen cxx_drawEquipmentList:z:]

slice 3: drawing - GUI, GL display, cross-hairs, system markers, advanced navigation array
  -[GuiDisplayGen drawGUIBackground]
  -[GuiDisplayGen refreshStarChart]
  -[GuiDisplayGen drawGUI:drawCursor:]
  -[GuiDisplayGen drawGLDisplay:x:y:z:]
  -[GuiDisplayGen drawCrossHairsWithSize:x:y:z:]
  -[GuiDisplayGen setStarChartTitle]
  -[GuiDisplayGen drawSystemMarker*]
  -[GuiDisplayGen targetNextFoundSystem:]
  -[GuiDisplayGen drawAdvancedNavArrayAtX:y:z:alpha:usingRoute:optimizedBy:zoom:]

slice 4: the star chart
  -[GuiDisplayGen drawStarChart:x:y:z:alpha:]

verbatim: plain C++ string helpers, no Objective-C (checked)
  *
```
