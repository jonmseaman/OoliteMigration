# Phase 4p — Polish for upstream

**Status:** in progress · **Depends on:** Phase 4 (done 2026-10-21) · **Before:** [Phase 5](5-apple-silicon.md)

## Goal

Make the C++ fork something the Oolite maintainers can review and want:
- behaviour matches 1.93 where it should, and the remaining differences are documented;
- the source is free of migration scaffolding;
- a write-up explains the work.

Windows x64 is the reference platform. macOS and Linux are Phase 5.

## Where it stands (2026-11-15)

**Done:**
- **No migration bookkeeping in the source.** `grep -rnE "ADR-[0-9]{4}|\boo-[0-9a-z]{3,}\b" oolite-dev/src`
  finds nothing.
- **No Objective-C.** No `.m`, `.mm`, Xcode or GNUstep-make files are tracked. The remaining
  `@end` and `[[X alloc]` text is all in comments that describe upstream's calls.
- **No GNUstep in the build, CI or install scripts,** except the names kept on purpose
  (current-state.md, Leftovers):
  - `OO_GNUSTEPDEFAULTSDIR`;
  - `Info-gnustep.plist`;
  - the Windows installer's `oolite.app\GNUstep\…` data folders.
- **Both high parity findings fixed,** with tests (see [parity/README.md](../../parity/README.md)).
- **The idiom review's real bugs fixed:** the `SDL/main.cpp` `strcat` and `-load` argv read, the
  256-byte path buffer, `OOCPUInfo.cpp`'s `strcpy`, and the octree `realloc` leak.
- **Tooling:** `.clang-tidy` (CI's clang-tidy guards), `.editorconfig`, and the Google-style
  `.clang-format`.
- **Windows manifest:** `src/SDL/OOResourcesWin/oolite.exe.manifest`.
- **QuickJS-ng 0.17:** in `third_party/quickjs-0.17.0/`.
- **The playtest keys and tutorial:** spec 011's component tests cover them. The view and
  tutorial key faults that remain are upstream's own, registered `should_fail` (`key_fault_h1`-`h4`,
  `test_tutorial_keys_ru`).

## Work items

1. **Medium parity fixes.** About 12 medium findings in [parity/README.md](../../parity/README.md)
   ("Suspected divergences → Medium") are open. `notes/2026-11-07 Parity Fixes.md` lists 13
   items, re-checked on 2026-11-07, waiting for Jon's review. Each item is either fixed with a unit
   or component test, or moved to ⚠️ with a reason. Examples still open on 2026-11-15:
   - JS `ship.speed` is writable (`Scripting/OOJSShip.cpp:588`, `OOJS_PROPERTY_RW`); upstream had
     it read-only.
   - The `laserColor` shader uniform has no row in `Entities/EntityShaderBindings.cpp`.
   - The preference defaults use `isNull() ? default : xForKey()` instead of upstream's
     `oo_*ForKey:defaultValue:` semantics (cross-cutting finding 1: `OOALSound.cpp`,
     `OOLogging.cpp`, `GameController.cpp`, `Universe.cpp`).

   Re-check the "symlinked `.oxp` folders" finding first: the `symlink_status` call it cites has
   gone from `ResourceManager.cpp`.
2. **Clang and GCC both green.** `tests/run.sh all` passes on Clang, and CI's GCC jobs (Fedora,
   Ubuntu) build and pass. GCC is checked only in CI; don't build it locally.
3. **Expansion compatibility.** Keep [EXPANSION_MIGRATION.md](../EXPANSION_MIGRATION.md) and
   [expansions/](../expansions/README.md) current. They ship with the write-up.
4. **The write-up** (Jon). Finish `notes/Phase 4 Writeup.md` (Jon's motivation paragraph, the final
   numbers) and send it upstream.

Other work that helps the review is in its own plans:
- the idiom work, including the warning flags (I21), in `notes/plans/modern-cpp-idioms.md`;
- the platform layer, in `notes/plans/platform-layer.md`;
- the one-off reformat with `.git-blame-ignore-revs`, a task in `notes/0_AI_Tasks.md`.

Running the unit suites on macOS and Linux is Phase 5, item 1.

## Exit gate

- [x] No migration bookkeeping in source comments (the grep above is empty).
- [x] No Objective-C sources or Xcode/GNUstep-make projects tracked:
      `git ls-files '*.m' '*.mm' '*.xcodeproj/*' '*.nib' '*.pch' '*GNUmakefile*'` is empty.
- [x] No live Objective-C: every source compiles as plain C++, so any Objective-C outside a
      comment fails the build. From `oolite-dev`, no Objective-C compile mode or flag remains:
      `! git grep -nE 'objective-c|-fobjc|objc_args' -- meson.build src/meson.build src/meson`
- [x] No GNUstep in the build, CI or install scripts beyond the kept names:
      `git grep -niE 'gnustep|libobjc' -- .github ShellScripts installers meson.build src/meson`.
- [ ] Every medium ❌ in [parity/README.md](../../parity/README.md) is fixed with a test, or moved
      to ⚠️ with a reason (item 1).
- [ ] `tests/run.sh all` is green on Clang, and CI is green on GCC (item 2).
- [ ] The write-up is final and sent upstream (item 4, Jon).

## Decisions

- **The PR series** is built on upstream `49a5eb9fc` as the `seriesb/*` stack (spec 002). The
  mechanical modernisation is on its own branch at the top (`seriesb/027-modern-cpp`, spec 009),
  so the branches before it stay the faithful version reviewers can compare line for line.
- **Third-party copies** (MiniZip, miniz, tinyexr, stb_image_write) live in `oolite-dev/third_party/`,
  unchanged. Upstream keeps them in `src/`; the difference is recorded in `docs/UPSTREAM_DELTA.md`.
