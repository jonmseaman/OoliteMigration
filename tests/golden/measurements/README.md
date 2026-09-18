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

Goldens live under `goldens/<platform>/<scenario>/`. Do not move these there.
