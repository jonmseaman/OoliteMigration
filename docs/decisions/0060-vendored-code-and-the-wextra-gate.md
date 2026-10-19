# ADR-0060: Vendored third-party code and the Phase 3 `-Wall -Wextra` gate

- Status: Proposed (default in effect until Jon ratifies or supersedes it; hard rule 10)
- Status: proposed — proceeding on default (Migration Completion session, 2026-10-18); Jon may overrule.
  oo-cpztk's acceptance was narrowed to this default: a `warning_level=2` dev build with no warning from any
  first-party path, and every warning that does appear in exactly `src/Core/MiniZip/ioapi.c` or
  `src/SDL/stb_image_write.h`; the vendored copies are not patched.
- Date: 2026-10-17
- Beads: oo-cpztk (this decision), oo-o8x (the Phase 3 exit gate whose acceptance uses it)

## Context

The Phase 3 exit gate ([3-cpp-conversion.md](../phases/3-cpp-conversion.md), bead oo-o8x) requires
the Windows build to be clean at `-Wall -Wextra`. Measured on main `9b09e31df` with
`tools/build-windows.sh dev --setup-flags=-Dwarning_level=2` (a full rebuild), 921 distinct
warnings are reported. 18 of them are not in code this migration wrote or converts:

| Path | Warnings | What it is |
|---|---:|---|
| `src/Core/MiniZip/ioapi.c` | 10 `-Wunused-parameter` | zlib contrib MiniZip, pure C |
| `src/SDL/stb_image_write.h` | 8 `-Wmissing-field-initializers` | single-header stb library |

Hard rule 3 forbids silencing a warning (`-Wno-*`, pragmas, unused attributes). Hard rule 9 says a
file that compiles as C is not rewritten. Patching vendored copies also widens the delta against
their own upstreams, which nobody tracks.

## Decision (default in effect)

1. The gate's `-Wall -Wextra` check is applied to **first-party** code. The vendored paths are
   **enumerated explicitly** in the check and nowhere else: `src/Core/MiniZip/` and
   `src/SDL/stb_image_write.h`. Nothing is excluded by pattern, directory guess, or warning kind.
2. No compiler flag changes: the warnings are still printed by every build; the gate simply does
   not count those two paths. This is a scoping rule, not a suppression.
3. Adding a path to the list needs a new ADR. A first-party file can never be added.
4. If a vendored library is updated or replaced, its entry is re-checked then.

## Alternatives

- **Patch the vendored copies** (name-less parameters in C are not valid before C23, so
  `(void)param;` lines in `ioapi.c`; designators in `stb_image_write.h`) and record the delta in
  `docs/UPSTREAM_DELTA.md`. Rejected as the default: it edits C that compiles (rule 9) to satisfy a
  gate meant for the conversion.
- **Compile the vendored code as its own static library at `warning_level=1`.** Rejected: it is
  a per-target `-Wno-extra` in all but name (rule 3).

## Consequences

oo-o8x's acceptance greps the warning build's output for `warning:` and drops exactly these two
paths before counting. oo-cpztk closes when this ADR is ratified or superseded.
