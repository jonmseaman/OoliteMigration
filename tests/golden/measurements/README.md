# Measurement artifacts

**These are NOT goldens.** Nothing compares against them and no test asserts the game still
produces them. They are the raw evidence behind the numbers quoted in
[../GOLDEN_STORAGE.md](../GOLDEN_STORAGE.md), committed so a reviewer can check the reasoning
without re-running four game launches.

* `001-raw15-runA.json` — scenario 001 dumped at **15** decimal places (`run_dump.py
  --quant-decimals 15`) instead of the policy 3. Kept because the *shape* of these values is the
  finding: they are exact binary fractions terminating at 7 decimal places, which is why the
  five-run byte-identical result does not locate a float noise floor.
* `001-raw15-summary.json` — the five-run comparison, its result, and — prominently — its limits.
* `001-fma-contract-summary.json` — **does `-ffp-contract=off` actually change the dump?** (bead
  oo-5ggu). Two builds of the same source — the shared one with 0/242 translation units carrying
  the flag, and a compliant one with 243/243 at an effective `-O2` — compared at full precision.
  **Answer: no. Not one of the 21 float fields moved; all four dumps share one sha256, which is
  also oo-ss8's.** The cause is established by disassembly rather than assumed: neither binary
  contains a single FMA instruction, because clang targets baseline `x86_64-w64-windows-gnu` here
  and no `-march` appears anywhere in the build database. A positive control in the same file
  shows the flag *does* change codegen at `-march=x86-64-v3`, so the null result is a property of
  the target, not of the flag or the measurement. The pin is insurance for FMA-capable targets
  (Phase 5's macos-arm64 contracts by default), not a fix for this scenario.

The quantisation precision is **still an unmeasured choice.** oo-ss8 could not locate a noise
floor because every value is an exact binary fraction; oo-5ggu hoped two genuinely different
builds would supply variation and they did not, because the two builds emit identical bits. What
would settle it: an FMA-capable `-march`, a second platform, or a scenario that integrates motion.

Goldens live under `goldens/<platform>/<scenario>/`. Do not move these there.
