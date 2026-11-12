# Contract: guards (FR-021, M0 onward)

Research: R3.

## `.clang-tidy` entries

Added to `Checks` in M0 (non-fatal), each added to `WarningsAsErrors` in the commit that brings its
category to zero:

```yaml
Checks: >
  ...existing entries...,
  cppcoreguidelines-no-malloc,
  cppcoreguidelines-use-enum-class,
  readability-identifier-naming,
  google-readability-casting
CheckOptions:
  cppcoreguidelines-use-enum-class.IgnoreUnscopedEnumsInClasses: false
  readability-identifier-naming.ScopedEnumConstantCase: CamelCase
  readability-identifier-naming.ScopedEnumConstantPrefix: k
```

| Check | Fatal in |
|---|---|
| `cppcoreguidelines-no-malloc` | M1 |
| `cppcoreguidelines-use-enum-class` | M4 (its findings at zero apart from the exceptions list, which needs no suppression because every exception is a construct the check does not flag: a typed constant, a QuickJS flag macro, an `#if`-tested macro) |
| `readability-identifier-naming` (enum constants only) | M8, after P10 |
| `google-readability-casting`, plus `-Wold-style-cast` in the game's warning flags | M5 |
| `bugprone-unsafe-functions` (already fatal) with `CustomFunctions` set ([contracts/strings.md](strings.md)) | M6 (the option is added in the commit that reaches zero) |

If an exceptions-list entry turns out to be flagged by its check, the check stays non-fatal and the
conflict is recorded in `exceptions.md`; no `NOLINT` and no `IgnoredRegexp` (FR-003).

`readability-identifier-naming` is configured for scoped enum constants only; no other naming
option is set by this feature.

## `./mk.sh tidy`

Runs `run-clang-tidy -p . -quiet 'src/(Core|SDL|oofnd)/.*\.cpp'` with the clang-tidy 22 binary
(`/opt/homebrew/opt/llvm@22/bin` on macOS, `clang-tidy` on `PATH` elsewhere) over the root
`compile_commands.json` that `./mk.sh build` writes. Exits nonzero if any `WarningsAsErrors` check
reports. Builds first if the database is missing.

## CI step

In `.github/workflows/build-all.yaml`, after the Arch build: `./mk.sh tidy`. It fails the job
exactly when `./mk.sh tidy` fails. If it takes more than 15 minutes, it is restricted to the
translation units of files changed against the merge base, and a full run is added on a schedule.

Not guarded (FR-021): the macro constant sets and the `.tbl` tables; their searches in
data-model.md run by hand. `vsnprintf` is left out of `CustomFunctions` because `oofnd`'s printf
engine keeps it (FR-026).

Not used (research R3): `cppcoreguidelines-owning-memory` (needs `gsl::owner` annotations) and
`modernize-macro-to-enum` (flags plain numeric constants that are out of scope). The macro sets
are guarded by the per-set searches in data-model.md.

## Removed types

No check is needed for `oo::Ref`, `oo::WeakRef`, `oo::RefCounted`, `oo::makeRef`, `oo::Expected`,
`oo::thread::detach` or `isMainThread`: their definitions are deleted, so a reintroduction does not
compile.
