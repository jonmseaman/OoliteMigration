# Contract: guards (FR-021, M0 onward)

Research: R3.

## `.clang-tidy` entries

Added to `Checks` in M0 (non-fatal), each added to `WarningsAsErrors` in the commit that brings its
category to zero:

```yaml
Checks: >
  ...existing entries...,
  cppcoreguidelines-no-malloc,
  cppcoreguidelines-owning-memory,
  cppcoreguidelines-use-enum-class,
  modernize-macro-to-enum,
  readability-identifier-naming
CheckOptions:
  cppcoreguidelines-use-enum-class.IgnoreUnscopedEnumsInClasses: false
  readability-identifier-naming.ScopedEnumConstantCase: CamelCase
  readability-identifier-naming.ScopedEnumConstantPrefix: k
```

| Check | Fatal in |
|---|---|
| `cppcoreguidelines-no-malloc` | M1 |
| `cppcoreguidelines-owning-memory` | M5 |
| `cppcoreguidelines-use-enum-class`, `modernize-macro-to-enum` | M4 (their findings at zero apart from the exceptions list, which needs no suppression because every exception is a construct the check does not flag: a C-API constant passed as `int`, an `#if`-tested macro) |
| `readability-identifier-naming` (enum constants only) | M6, after P10 |

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

## Removed types

No check is needed for `oo::Ref`, `oo::WeakRef`, `oo::RefCounted`, `oo::makeRef`, `oo::Expected`,
`oo::thread::detach` or `isMainThread`: their definitions are deleted, so a reintroduction does not
compile.
