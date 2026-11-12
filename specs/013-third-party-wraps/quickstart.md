# Quickstart: verifying each milestone

All commands run from `oolite-dev` in an MSYS2 UCRT64 shell, on `feature/third-party-wraps`.
`B` is a scratch build directory under `build/`, which git ignores. Each milestone's commands
must exit 0. Where a command is meant to fail before the milestone, that is said.

## Helpers

```bash
# Sorted, de-duplicated warning lines of a clean full build. $1 = dir, $2 = native file.
warnings() { rm -rf "$1" && meson setup "$1" --native-file "$2" >/dev/null &&
  ninja -C "$1" 2>&1 | grep -E 'warning:' | sed -E 's/\x1b\[[0-9;]*m//g' | sort -u; }
```

## M0: baselines and the snapshot test

```bash
git switch -c feature/third-party-wraps develop
mkdir -p ../specs/013-third-party-wraps/baselines
warnings build/wl-clang clang.ini > ../specs/013-third-party-wraps/baselines/warnings-clang.txt
warnings build/wl-gcc   gcc.ini   > ../specs/013-third-party-wraps/baselines/warnings-gcc.txt
./mk.sh build deployment
find build/meson_deployment -name '*.dll' -printf '%f\n' | sort > ../specs/013-third-party-wraps/baselines/dlls.txt
meson introspect --installed build/meson_deployment > ../specs/013-third-party-wraps/baselines/installed.json
```

Before the test exists, `meson test -C build/meson_test test_OOSnapshotWriters` fails (no such
test). After it is added:

```bash
./mk.sh build test && meson test -C build/meson_test --suite core test_OOSnapshotWriters
./mk.sh build test --native-file=gcc.ini && meson test -C build/meson_test --suite core test_OOSnapshotWriters
```

Both pass on the unmoved code ([contracts/snapshot-test.md](contracts/snapshot-test.md)).

## M1: wraps fetch and build alone

```bash
rm -rf subprojects/packagecache
meson subprojects download miniz minizip tinyexr stb
ls subprojects/packagecache   # four archives (plus QuickJS-ng's when fetched)
git grep -nE 'revision|branch|master|main' -- 'subprojects/*.wrap'; test $? -eq 1
```

Before the wraps exist, `meson subprojects download minizip` fails. Each library also gets a probe
under `.agent-tmp/` in the planning repo: a three-line `meson.build` that requests the dependency
and compiles one file including its header. These probes prove R2, R3 and R4. They are scratch
and are not committed.

## M2: wired, copies gone

```bash
# SC-001: nothing third-party left in src/
test -z "$(git ls-files src | grep -E 'MiniZip/|miniz\.|tinyexr\.h|stb_image_write\.h|LICENSE\.(miniz|tinyexr)')"
tests/run.sh all
tests/run.sh unit   # again after: ./mk.sh build test --native-file=gcc.ini
diff <(warnings build/wl-clang clang.ini) ../specs/013-third-party-wraps/baselines/warnings-clang.txt
diff <(warnings build/wl-gcc   gcc.ini)   ../specs/013-third-party-wraps/baselines/warnings-gcc.txt
```

A warning line in the baseline whose file no longer exists, for example one in
`src/Core/MiniZip/`, is removed from the baseline copy before the `diff`. The removal is noted in
`baselines/README.md`. Any other difference fails.

## M3: licences, tidy, docs

```bash
for l in MiniZip miniz TinyEXR stb_image_write; do grep -q "$l" LICENSE.md || echo "missing $l"; done | (! grep .)
grep -q 'subprojects/minizip.wrap' LICENSE.md
! grep -nE 'MiniZip|stb_image_write' .clang-tidy
! grep -n 'src/Core/MiniZip' ../docs/current-state.md
```

## M4: offline, installer, suppressions, phase 2

```bash
# Offline (SC-006): cache filled by M1, downloads forbidden
rm -rf build/offline && meson setup build/offline --native-file clang.ini --wrap-mode=nodownload && ninja -C build/offline

# Installer (SC-007)
./mk.sh build deployment
diff <(find build/meson_deployment -name '*.dll' -printf '%f\n' | sort) ../specs/013-third-party-wraps/baselines/dlls.txt

# Suppressions (SC-003): none in the feature's added lines
! git diff develop... -- subprojects meson.build src tests | grep -E '^\+' |
  grep -nE -- '-Wno-|diagnostic|is_system|include_type|maybe_unused|__attribute__\(\(unused\)\)|warning_level'

# Phase 2 (SC-008): adding gtest is a one-line addition
sed -i "s/^\(\s*\)'tinyexr',$/&\n\1'gtest',/" meson.build && git diff --numstat meson.build | grep -qx $'1\t0\tmeson.build'
git checkout -- meson.build
```

The installer itself is built once with `./mk.sh` and NSIS, as the release process does. Then
`License.pdf` is checked for the four names (`pdftotext`, or open it).
