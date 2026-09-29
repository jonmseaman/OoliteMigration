# Slice plan: PlayerEntityKeyMapper

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-gdgx). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/PlayerEntityKeyMapper.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/PlayerEntityKeyMapper.mm` (1,867 lines) + header (98 lines). One
  `PlayerEntity (KeyMapper)` category (the key-mapper GUI) and sixteen small `oo::PList` / string
  helpers at file scope.
- **Shape:** three screens share one category: the key-function list, the per-key configuration
  and custom-equipment entry screens, and the keyboard-layout picker plus the validation and
  persistence of key settings. Each becomes a group of `PlayerEntity` member functions defined in
  `PlayerEntityKeyMapper.cpp`. The helpers contain no Objective-C and stay verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9).
- **Order:** after the `ooentity` pattern seam (oo-bj8) and once the `PlayerEntity` class
  shell is C++ (frontier, oo-a70, which converts the category files through these slices). Slices only define members declared in
  the header or the `KeyMapperInternal` interface in the preamble, so they are independent.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | key-mapper screen, input handler, key-function list and its GUI rows, `reloadPage` | ~580 | ~765 |
| 2 | key-config and key-entry screens, custom-equipment key lookup, clear-all confirmation | ~485 | ~670 |
| 3 | keyboard-layout screen, key validation, saving / unsetting / deleting key settings | ~570 | ~755 |
| verbatim | `oo::PList` / string helpers | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Entities/PlayerEntityKeyMapper.mm
header: upstream/oolite/src/Core/Entities/PlayerEntityKeyMapper.h

slice 1: key-mapper screen and the key-function list
  -[PlayerEntity initCheckingDictionary]
  -[PlayerEntity resetKeyFunctions]
  -[PlayerEntity setGuiToKeyMapperScreen:*]
  -[PlayerEntity keyMapperInputHandler:view:]
  -[PlayerEntity displayKeyFunctionList:skip:]
  -[PlayerEntity keyFunctionList]
  -[PlayerEntity makeKeyGuiDict*]
  -[PlayerEntity reloadPage]

slice 2: key-config and key-entry screens, custom-equipment keys
  -[PlayerEntity entryIs*CustomEquip:]
  -[PlayerEntity getCustomEquip*]
  -[PlayerEntity setGuiToKeyConfigScreen*]
  -[PlayerEntity outputKeyDefinition:*]
  -[PlayerEntity handleKeyConfigKeys:view:]
  -[PlayerEntity setGuiToKeyConfigEntryScreen]
  -[PlayerEntity handleKeyConfigEntryKeys:view:]
  -[PlayerEntity updateKeyDefinition:index:]
  -[PlayerEntity updateShiftKeyDefinition:index:]
  -[PlayerEntity setGuiToConfirmClearScreen]
  -[PlayerEntity handleKeyMapperConfirmClearKeys:view:]

slice 3: keyboard layouts, key validation and key-setting persistence
  -[PlayerEntity setGuiToKeyboardLayoutScreen:*]
  -[PlayerEntity handleKeyboardLayoutEntryKeys:view:]
  -[PlayerEntity keyboardDescription:]
  -[PlayerEntity keyboardLayoutList]
  -[PlayerEntity displayKeyboardLayoutList:skip:]
  -[PlayerEntity validateAllKeys]
  -[PlayerEntity validateKey:checkKeys:]
  -[PlayerEntity searchArrayForMatch:key:checkKeys:]
  -[PlayerEntity entryIsEqualToDefault:]
  -[PlayerEntity compareKeyEntries:second:]
  -[PlayerEntity saveKeySetting:]
  -[PlayerEntity unsetKeySetting:]
  -[PlayerEntity deleteKeySetting:]
  -[PlayerEntity deleteAllKeySettings]
  -[PlayerEntity loadKeySettings]

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
