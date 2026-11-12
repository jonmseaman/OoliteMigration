# Contract: wraps, overlays and patches

What every file this feature adds under `oolite-dev/subprojects/` must satisfy. The exemplar is
`subprojects/quickjs-ng.wrap` and its `packagefiles/`.

## W1. Every `.wrap`

- Is a `[wrap-file]`. No `[wrap-git]`: git wraps are not cached in `packagecache`, so they would
  break offline setup (FR-012).
- Names the source by an exact version or a full 40-character commit hash, never a branch or a
  moving tag, and carries its `source_hash` (SHA-256 of the downloaded archive).
- Has `source_filename` set, so the cached archive's name is stable in `packagecache/`.
- Each custom wrap carries a comment block above `[provide]` saying what the library is, why it is
  a wrap, and where its overlay and patches are. For stb the comment also gives the short hash and
  commit date.
- Provides exactly one dependency, named like the file (`[provide] dependency_names = <name>`).
- miniz's file is WrapDB's, installed with `meson wrap install miniz`, and is not edited.

## W2. Every fork-written overlay (`packagefiles/<name>/meson.build`)

- Opens with a `project()` call naming the library, its version and licence (`license:` and
  `license_files:` pointing at the source's own licence file).
- Sets no `warning_level`, `werror` or `-W` argument, and no `default_options` that change
  warnings.
- Declares include directories with `include_directories()`, never `is_system: true`, and the
  dependency without `include_type: 'system'`.
- A compiled library (MiniZip only) is a `static_library`, so `default_library` does not apply.
- Declares the dependency with `declare_dependency()` and registers it with
  `meson.override_dependency('<name>', ...)`.
- Builds only what the game uses: MiniZip `ioapi.c` and `unzip.c`; tinyexr and stb nothing.

## W3. Every patch

- Is a unified diff with paths relative to the subproject root, listed in the wrap's `diff_files`.
- Starts with a header (above the diff, as in `quickjs-ng-o2.patch`) giving what it changes, the
  origin commit in `oolite-dev`'s history, and why the pinned version still needs it.
- Changes only what its header says.
- A warning patch (FR-006) names the warning, the compiler and the version that emits it.

## W4. Checks

| Check | How (quickstart M1/M2/M4) |
|---|---|
| Every wrap fetches and verifies | `meson subprojects download` exits 0 with an empty `packagecache/` |
| Offline setup | `meson setup --wrap-mode=nodownload` on a fresh build directory with the cache filled exits 0 |
| Pinned, not moving | `git grep -nE 'revision|branch|master|main' subprojects/*.wrap` finds nothing |
| No suppression added | `git diff develop... -- subprojects meson.build src tests` added lines contain none of `-Wno-`, `diagnostic`, `is_system`, `include_type`, `maybe_unused`, `__attribute__((unused))`, and no `warning_level` |
| Static linking | the deployment install tree's `*.dll` list equals M0's |
