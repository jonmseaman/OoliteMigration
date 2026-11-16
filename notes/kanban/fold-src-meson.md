---
status: Ready
parent: seriesb/032-cleanup
---
# Fold `src/meson/` into `src/meson.build`

## Context

`oolite-dev/src/meson/` is 123 lines across 4 files: `meson.build` (compiler id, gnu99 for GCC, the
QuickJS-ng dependency, the LTO flags) and `windows/`, `darwin/` and `linux/` (one file each, with that
platform's defines, link args and GL deps). Nothing outside `src/meson.build` includes them, and
every variable they touch (`oolite_dependencies`, `oolite_link_args`, `oolite_override_options`) is
defined in `src/meson.build`. The directory name says nothing about what's in it, and
`linux/meson.build` has dead code (`fs`, `project_root`, `shared_roots`) left over from upstream's
GNUstep search. Platform code belongs inline: `if host_os == … endif` blocks in a single file are the
usual Meson pattern, and a `subdir()` per platform only helps when each platform has a lot of
build logic.

Trade-off: upstream (`upstream/oolite`) has the same layout and still changes it (3193dfe80, the
Apple Silicon work). Once the files are folded in, an upstream change to `src/meson/*` has to be
ported by hand instead of applied as a patch. The fork's copies already differ a lot from upstream's
(no GNUstep, no SpiderMonkey), so this mostly adds a path change on top. Record this in the
Decisions section of `docs/phases/4p-upstream-polish.md`.

## Approach

1. **Branch**: work on `seriesb/032-cleanup`, or on a branch made with `git town append` from it.
   Start only after the uncommitted `src/meson.build` / `meson.build` edits on
   `seriesb/031-third-party` are committed.
2. In `src/meson.build`, put the contents in place of `subdir('meson')`, in the same order. They
   must stay before `subdir('oofnd')`, because `add_project_arguments` is refused once a target
   exists:
   - `cc` / `ccid`
   - `# Platform` section: `if host_os in ['windows','cygwin'] … elif host_os == 'darwin' … else …
     endif`, with each body copied verbatim from its file, comments included
   - GCC `c_std=gnu99`, the `threads` override and the QuickJS-ng `dependency()` with its comment
   - the LTO block
3. Drop the dead Linux lines (`fs`, `project_root`, `shared_roots`, and the stale "vendored
   QuickJS-ng subproject" comment).
4. `git rm -r src/meson`. In `src/Core/Scripting/poc/meson.build`, change the two comments at lines
   14 and 31 to point at `src/meson.build`. Run `git grep src/meson` in this repo's docs as well,
   and update any hits.
5. Keep the existing 4-space style. clang-format doesn't format Meson files.

## Verification (Windows/Clang only; CI covers Linux, macOS and GCC)

- Before the change, save the setup outputs: run `meson introspect build --targets
  --buildoptions`, copy `build/compile_commands.json` to `.agent-tmp/`, and grep the `LINK_ARGS`
  lines out of `build/build.ninja`.
- After the change, run `meson setup --reconfigure` and diff the same outputs. Expect no
  difference.
- `test ! -e src/meson && ! git grep -q "src/meson/"`: this fails before the change and passes
  after.
- `./mk.sh build test`.
- Push the branch so CI checks the Linux and macOS branches of the `if`.
