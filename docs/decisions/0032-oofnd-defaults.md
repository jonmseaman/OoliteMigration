# ADR-0032 — `oofnd` Defaults reproduce GNUstep's `NSUserDefaults` as the game runs it

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-32f, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Implements** the `Defaults` component of seam 2.7 of [Phase 2](../phases/2-oofnd.md) in
`upstream/oolite/src/oofnd/Defaults.hpp`.

## Context

The game keeps its preferences through `NSUserDefaults` (about 145 call sites), bent by two
categories: `NSUserDefaults+Override.m` replaces GNUstep's private `-writeDictionary:toFile:` so
the file is written as an OpenStep (old-style) plist, and `NSBundle+Override.m` makes
`-infoDictionary` read `Resources/Info-gnustep.plist` from the current directory, which is where
the defaults domain gets its name. Nothing recorded what that combination does on disk, and the
bead requires that an existing preferences file loads identically and is written identically.

It was measured with throwaway probe programs linked against the game's gnustep-base 1.31 (with
both categories compiled in) on this toolchain; the probes are not committed, their results are the
expectations in `tests/unit/oofnd/test_defaults.cpp`.

## Decision

1. **Same file.** `<home>/GNUstep/Defaults/<domain>.plist`, home being
   `ResourcePaths::homeDirectory()` (on Windows the executable's directory, via `SDL/main.mm`'s
   `HOMEPATH`). The directory is GNUstep.conf's `GNUSTEP_USER_DEFAULTS_DIR`, which the environment
   does not override (probed). `<domain>` is `CFBundleIdentifier` of
   `<builtInResourcesDirectory>/Info-gnustep.plist` (`oolite`), else the process name (probed
   both). The file is `oolite.plist`; the `OoliteDefaults.plist` in the 1.93 readme is a different
   GNUstep build's name and is not what this build reads. `NSGlobalDomain.plist` beside it is read
   too. On POSIX `OO_GNUSTEPDEFAULTSDIR` (what `run_oolite.sh` writes into its GNUstep.conf)
   overrides the directory.
2. **Same format.** Writing is GNUstep's `NSPropertyListOpenStepFormat` (`oo::writeOpenStepPList`),
   byte for byte: 4-space/tab indentation, keys sorted, strings bare only when non-empty ASCII
   alphanumerics, `\a \b \v \f \" \\` escapes, other controls `\ooo`, non-ASCII `\UXXXX` per
   UTF-16 unit, numbers as `-[NSNumber description]` (`%.16g` doubles, `%.7g` floats, 1/0 for
   booleans), data `<xxxxxxxx xxxx>`, no final newline. It is not Oolite's own old-style writer
   (`writeOldStylePList`), which differs. Reading accepts any format `parsePropertyList` does; a
   missing, unparsable or non-dictionary file is an empty domain.
3. **Same semantics.** Search list: arguments, application domain, `NSGlobalDomain`, registration.
   The argument domain is GNUstep's parse of the command line (value parsed as a plist, else the
   raw string; a `-key` with no value sets nothing). Getters coerce exactly as `NSUserDefaults`
   does, including GNUstep's `-[NSString boolValue]`, `-integerValue` and `-doubleValue` quirks.
   Only `synchronize()` writes (never at exit); it re-reads the file, applies this process's
   changes since the last synchronize, writes only if that changed the file, and deletes the file
   when the domain is empty, as GNUstep does. `setFloat` values are remembered as single
   precision so they are written `%.7g`, since `PList` has one real type.
4. **The two categories are retired by replacement, not yet deleted.** Their behaviour is in
   `Defaults` (`writeOpenStepPList` + `synchronize`; `applicationDomainName` over the same
   Info-gnustep.plist lookup). They stay compiled while any `NSUserDefaults` or `-[NSBundle
   infoDictionary]` caller remains, and are deleted with the last one.
5. **Coexistence during the migration.** `oo::Defaults::standard()` is a separate reader of the
   same file, loaded on first use. A migrated consumer must therefore only *read* keys the game
   never writes at run time (the exemplar's `sky-*` keys are user-edited only), until the writers
   of a key migrate together. Setting a key through both stores in one run is not supported.
6. **Not reproduced**, all outside what the game reads: GNUstep's `.lck` lock directory (the
   game is one process); `GSPrimaryDomain`, `GSConfigDomain` and language domains; key order for
   non-ASCII keys (GNUstep's `-compare:` folds canonical decompositions, oofnd sorts by UTF-16
   units); `-doubleValue` of more than 19 significant digits (GNUstep loses precision
   idiosyncratically, oofnd rounds correctly); the Info-gnustep.plist warning `NSBundle+Override`
   logs (oofnd has no logging yet); dates are written in local time as `-description` does.

## Consequences

- Exemplar: `Core/OOSkyDrawable.mm` has no `NSUserDefaults` left (`sky-render-inset-coords`,
  `sky-color-correction`). `-integerForKey:` returns 0 in every case where
  `oo_integerForKey:defaultValue:0` returned its default, so the value is identical; the goldens,
  which draw the sky, are unchanged.
- The remaining consumers migrate family by family; consumers that write (`GameController`,
  `MyOpenGLView`, `PlayerEntity`, the key and stick mappers) must move with every reader of the
  keys they write, or `standard()` must become the only store first.
- `PList::get<T>` (the `oo_*ForKey:defaultValue:` extractors) is a separate seam; `Defaults` offers
  only `NSUserDefaults`' own getters.
