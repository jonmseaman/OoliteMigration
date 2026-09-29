# Slice plan: ResourceManager

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-yqzt). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/ResourceManager.md`, which recounts the
file every time, so the numbers below are only a snapshot.

- **File:** `Core/ResourceManager.mm` (2,368 lines) + header (157 lines). One class,
  `ResourceManager`, made only of class methods over file-scope state (it becomes a class of
  `static` member functions, or a namespace, per the recipe), plus ~18 plain C++ helpers
  (manifest/PList access, merging) that stay verbatim except `ReplaceArrayElement`.
- **Shape:** four slices along what the methods do: (1) search paths, add-ons and file-list
  preloading; (2) OXP manifests: validation, requirements, conflicts, dependencies, scenarios;
  (3) loading and merging plist files, equipment/star/role overrides, the caches;
  (4) the remaining single-file lookups: path lookup, sounds/music/strings, scripts, diagnostics.
- **Order:** slice 1 (class shell, file-scope state) first; 2, 3 and 4 are independent of each other.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell, state, search paths, add-ons, preloading, paths utilities | ~465 | ~760 |
| 2 | manifests: validation, requirements, conflicts, dependencies, scenarios | ~550 | ~845 |
| 3 | plist loading and merging, overrides, whitelist/log-control/role dictionaries | ~615 | ~910 |
| 4 | file lookup, sounds/music/strings, scripts, diagnostics | ~400 | ~695 |
| verbatim | manifest/PList helpers | — | not read |

```slice-plan
source: upstream/oolite/src/Core/ResourceManager.mm
header: upstream/oolite/src/Core/ResourceManager.h

slice 1: class shell, file-scope state, search paths, add-ons, preloading
  @ResourceManager
  ReplaceArrayElement()

slice 2: OXP manifests - validation, requirements, conflicts, dependencies, scenarios
  +[ResourceManager checkOXPMessagesInPath:]
  +[ResourceManager checkPotentialPath:path:]
  +[ResourceManager validateManifest:forOXP:]
  +[ResourceManager cxx_checkVersionCompatibility:forOXP:]
  +[ResourceManager areRequirementsFulfilled:forOXP:andFile:]
  +[ResourceManager cxx_manifestHasConflicts:logErrors:]
  +[ResourceManager cxx_manifestHasMissingDependencies:logErrors:]
  +[ResourceManager cxx_manifest:HasUnmetDependency:logErrors:]
  +[ResourceManager filterSearchPaths*]
  +[ResourceManager cxx_matchVersions:withVersion:]
  +[ResourceManager manifestAllowedByScenario*]
  +[ResourceManager addErrorWithKey:param1:param2:]

slice 3: plist loading and merging, overrides, the configuration dictionaries
  +[ResourceManager checkCacheUpToDateForPaths:]
  +[ResourceManager cxx_corePlist:excludedAt:]
  +[ResourceManager cxx_dictionaryFromFilesNamed:*]
  +[ResourceManager cxx_arrayFromFilesNamed:*]
  +[ResourceManager handle*]
  +[ResourceManager cxx_whitelistDictionary]
  +[ResourceManager cxx_logControlDictionary]
  +[ResourceManager cxx_roleCategoriesDictionary]
  +[ResourceManager mergeRoleCategories:intoDictionary:]

slice 4: file lookup, sounds, music, strings, scripts, diagnostics
  +[ResourceManager systemDescriptionManager]
  +[ResourceManager cxx_shaderBindingTypesDictionary]
  +[ResourceManager cxx_pathForFileNamed:*]
  +[ResourceManager retrieveFileNamed:inFolder:cache:key:class:usePathCache:]
  +[ResourceManager cxx_ooMusicNamed:inFolder:]
  +[ResourceManager cxx_ooSoundNamed:inFolder:]
  +[ResourceManager cxx_stringFromFilesNamed:*]
  +[ResourceManager cxx_loadScripts]
  +[ResourceManager cxx_writeDiagnostic*]
  +[ResourceManager cxx_materialDefaults]
  +[ResourceManager directoryExists:create:]
  +[ResourceManager cxx_diagnosticFileLocation]

verbatim: plain C++ helpers, no Objective-C (checked)
  *
```
