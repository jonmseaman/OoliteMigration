# Blessed goldens

**Do not hand-edit anything in here.** A golden is evidence of what the game did; editing a value
so a test passes destroys the evidence and leaves a green suite that proves nothing.

Layout, precision, pinned build flags and the reasoning behind all three:
**[tests/golden/GOLDEN_STORAGE.md](../tests/golden/GOLDEN_STORAGE.md)** (decision 11).

```
<platform>/<scenario>/state.json        the canonical dump
<platform>/<scenario>/provenance.json   quantisation, build flags, compiler, OS, commit
```

Present: `windows-x64/001`. `macos-arm64` and `linux-x64` arrive at Phase 5.

If a fresh run disagrees with a stored golden, that is a **finding to investigate and report**, not
a file to rewrite. The only writer is `tests/golden/bless_golden.py`, it is never invoked from a
test, and it refuses to overwrite an existing golden without an explicit `--force`.
