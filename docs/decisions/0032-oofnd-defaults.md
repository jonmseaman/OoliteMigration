# ADR-0032 â€” `oofnd` Defaults reproduce GNUstep's `NSUserDefaults` as the game runs it

**Status:** Proposed â€” default in effect (Claude Code, frontier agent, bead oo-32f, 2026-09-23;
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
5. **Coexistence during the migration: one store** (amended by bead oo-mwo0, 2026-09-24; see
   Amendment 1). The game's `+[NSUserDefaults standardUserDefaults]` is backed by
   `oo::Defaults::standard()` (`Core/NSUserDefaults+OODefaultsBridge`), so there is one in-memory
   store and one writer of the file. A value set through either API is read back through the
   other, and a file can move off `NSUserDefaults` on its own, readers and writers alike.
   *(Originally: `oo::Defaults::standard()` was a separate reader of the same file, loaded on
   first use; a migrated consumer could only read keys the game never writes at run time, until
   the writers of a key migrated together, and setting a key through both stores in one run was
   not supported.)*
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

## Amendment 1 — one store (bead oo-mwo0, 2026-09-24)

**Status:** Proposed — default in effect (Claude Code, fleet sweep worker; ADR-0013). Jon may
override.

GameController's `save-directory` (oo-3rb.91) showed the cost of point 5 as first written: a key
the game writes could not be migrated file by file, because `oo::Defaults` and `NSUserDefaults`
held separate copies and whichever synchronized last would drop the other's change. 43 files
(about 145 call sites) still use `NSUserDefaults`.

**Decision.** A transitional shim, `upstream/oolite/src/Core/NSUserDefaults+OODefaultsBridge.h/.mm`
(the ADR-0043 Amendment 1 bridge pattern), makes `oo::Defaults::standard()` the only store:

- `+standardUserDefaults` is exchanged, at `+load` and with runtime calls only, for a wrapper that
  lets GNUstep build its standard object as always and then retargets that one object
  (`object_setClass`) to `OODefaultsBackedUserDefaults`, a subclass without instance variables.
  No other `NSUserDefaults` instance changes.
- Its `-objectForKey:` and typed getters (`-stringForKey:`, `-arrayForKey:`, `-dictionaryForKey:`,
  `-boolForKey:`, `-integerForKey:`, `-floatForKey:`, `-doubleForKey:`) answer from `oo::Defaults`
  with its coercions (point 3); GNUstep's other getters read `-objectForKey:`. Its setters,
  `-removeObjectForKey:`, `-registerDefaults:` and `-synchronize` forward to `oo::Defaults`
  (`oo::PListFrom` / `oo::ObjectFromPList`; a float `NSNumber` is kept single precision so it is
  written `%.7g`). Each change posts `NSUserDefaultsDidChangeNotification` as GNUstep did.
- A key `oo::Defaults` has no value for is one of GNUstep's own settings, which live in the domains
  point 6 does not reproduce (language domains, `GSConfigDomain`, GNUstep's registration domain):
  GNUstep's volatile domains answer it, so GNUstep's internal settings read as before.
- Only `oo::Defaults::synchronize()` writes the file. GNUstep's own store is never changed, so
  `NSUserDefaults+Override`'s writer is no longer reached; it stays compiled until point 4 retires
  it.
- `-dictionaryRepresentation`, `-persistentDomainForName:` and the other domain methods remain
  GNUstep's (the game uses none of them).

**Proof.** `upstream/oolite/tests/unit/game/test_defaults_bridge.mm` (meson suite `game-unit`,
`bash tools/check-game-unit.sh`), linked like the game: the standard object is retargeted; values
set through `NSUserDefaults` (string, bool, integer, float, double, array, dictionary) read back
through `oo::Defaults` and the reverse; a removal through either is seen by both; registered
defaults are shared; one `-synchronize` writes the one file with the changes made through both
APIs, and a second synchronize through either writes nothing.

**Consequences.** Per-file `NSUserDefaults` sweeps are safe, readers and writers alike. The shim,
`NSUserDefaults+Override` and the `game-unit` test go in bead oo-iobt once no file uses
`NSUserDefaults`; oo-qps cannot compile while they exist. No behavioural difference: GNUstep's
automatic save is kept (this sentence corrected by bead oo-xeve; see Amendment 2).

## Amendment 2 — the automatic save (bead oo-xeve, 2026-09-24)

**Status:** Proposed — default in effect (Claude Code, fleet sweep worker; ADR-0013). Jon may
override.

**Measured** (gnustep-base 1.31.1, throwaway probes): the standard defaults object runs a
repeating **30-second** timer, started when the object is made, that sends `-synchronize` whether
or not anything changed (a change made 13.1 s after creation was written at 30.1 s; with
`-setObject:forKey:` overridden so GNUstep's own store never changed, `-synchronize` still arrived
at 30.0 s and 60.0 s). The message is dispatched, so since Amendment 1 it already reaches the
shim's `-synchronize` and `oo::Defaults` writes pending changes: Amendment 1's statement that the
background save no longer happened was wrong. The timer lives on the run loop, which the frame
loop pumps only until oo-3rb.58 removes the pump.

**Decision.** The shim schedules the save itself so it survives the pump's removal: the first
change after a save schedules one `-synchronize` 30 s later through `OOScheduleDeferredCall`
(ADR-0040, main thread only); later changes add none until it has run. Any change is therefore
written at most 30 s after it was made, as with GNUstep's timer; the write happens only if
something changed (point 3). While the pump remains, GNUstep's own timer also still calls
`-synchronize`, which writes nothing when nothing is pending.

**Proof.** `test_defaults_bridge.mm`'s `firstChangeSchedulesOneDeferredSave`, with the deferred-call
queue recorded by the test: one call, 30 s, scheduled by the first change; running it writes the
pending changes once; the next change schedules the next save.

