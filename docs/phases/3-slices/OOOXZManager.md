# Slice plan: OOOXZManager

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-hgwi). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOOXZManager.md`, which recounts the
file every time, so the numbers below are only a snapshot.

- **File:** `Core/OOOXZManager.mm` (2,609 lines) + header (136 lines). One singleton class in a
  single `@implementation` block (~2,220 lines of methods) and about twenty plain C++ helpers
  (manifest/string/PList access, the dependency stack) that stay verbatim.
- **Shape:** four slices along the manager's responsibilities: (1) state, paths, filters and the
  download plumbing; (2) installing, updating, removing and extracting OXZs; (3) the main GUI
  page and its key/text input; (4) the install/remove option pages and their paging.
- **Order:** slice 1 (class shell) first; 2, 3 and 4 are independent of each other.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell, paths, filters, manifests, download callbacks | ~695 | ~1,040 |
| 2 | processDownloadedOXZ, install state, install/update/remove/extract | ~615 | ~960 |
| 3 | gui, processSelection, text input, filter/info/extract keys | ~520 | ~865 |
| 4 | install/remove option pages, options paging | ~390 | ~740 |
| verbatim | manifest/string helpers, dependency stack | — | not read |

```slice-plan
source: upstream/oolite/src/Core/OOOXZManager.mm
header: upstream/oolite/src/Core/OOOXZManager.h

slice 1: class shell, paths, filters, manifests and download plumbing
  @OOOXZManager

slice 2: installing, updating, removing and extracting OXZs
  -[OOOXZManager processDownloadedOXZ]
  -[OOOXZManager installedManifestForIdentifier:]
  -[OOOXZManager installableState:]
  -[OOOXZManager colorForManifest:]
  -[OOOXZManager installStatusForManifest:]
  -[OOOXZManager isRestarting]
  -[OOOXZManager installOXZ:]
  -[OOOXZManager updateAllOXZ]
  -[OOOXZManager removeOXZ:]
  -[OOOXZManager extractOXZ:]

slice 3: the main GUI page and its input handling
  -[OOOXZManager gui]
  -[OOOXZManager processSelection]
  -[OOOXZManager isAcceptingTextInput]
  -[OOOXZManager isAcceptingGUIInput]
  -[OOOXZManager processTextInput:]
  -[OOOXZManager refreshTextInput:]
  -[OOOXZManager processFilterKey]
  -[OOOXZManager processShowInfoKey]
  -[OOOXZManager processExtractKey]

slice 4: install and remove option pages, options paging
  -[OOOXZManager installOptions]
  -[OOOXZManager showInstallOptions]
  -[OOOXZManager removeOptions]
  -[OOOXZManager showRemoveOptions]
  -[OOOXZManager showOptions*]
  -[OOOXZManager processOptions*]

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
