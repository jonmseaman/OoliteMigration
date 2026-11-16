# Build with `dev` while developing

From `oolite-dev`, the edit/compile/test loop is:

```bash
./mk.sh build dev       # build/meson_dev: no LTO, not stripped
tests/run.sh unit       # tests/run.sh defaults to BUILD_TYPE=dev
```

- Don't use `./mk.sh build test` for day-to-day work. The `test` build turns on LTO and stripping,
  so every link is much slower.
- Build `test` (or `deployment`) only when the task needs the optimised build, such as reproducing
  an LTO-only or CI-only failure, or packaging. Then point the tests at it:
  `BUILD_TYPE=test tests/run.sh …`.
