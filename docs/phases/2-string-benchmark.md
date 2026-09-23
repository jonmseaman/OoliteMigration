# Decision 4 benchmark: `std::string` copying vs `NSString` on golden wall-clock

**Bead:** oo-lvj (seam 2.5a) · **Date:** 2026-09-23 · **Threshold** (ADR-0013 decision 4, Phase 2
entry gate): golden wall-clock regression > 5% escalates via the Reporter; otherwise proceed.

**Result: Decision 4 is confirmed.** Value-semantics string copying adds no measurable golden
wall-clock (paired median +0.1% over 22 interleaved repetitions) and ~13 ms of CPU per golden pair
(0.07%). Nothing is escalated. The pessimistic model (every `-retain` of a string becomes a deep
copy) does cost more than 5%, which turns into one design rule for the String seam, below.

## What is being decided

`NSString` is immutable and reference-counted: `-copy` of an immutable string and `-retain` are
both O(1). `std::string` is a value: a copy is O(n), a heap allocation plus a byte copy once the
string outgrows the 15-byte small-string buffer (libstdc++), and a free when it dies. The question
is whether moving Oolite's string traffic onto `std::string` makes the game measurably slower.

## Method

A golden-level A/B is possible without writing the String seam first: make today's game **pay**
the `std::string` cost at every point where it copies (or retains) an `NSString`, on top of
everything it already does, and time the blessed goldens.

- `tools/bench/string-copy/OOBenchStringCopy.mm` is linked into a throwaway build. At `+load` it
  swizzles `-copyWithZone:` on every `NSString` class (and, in the pessimistic mode, gives
  `NSString` its own `-retain`), so each call also builds and destroys a `std::string` of the
  string's length. Selected at run time by `OO_BENCH_STRING_MODE`:
  - **`off`**: nothing installed (the in-binary control);
  - **`copy`**: every `-copyWithZone:`: the representative model. `std::string` has value
    semantics exactly where the Objective-C code copies (dictionary keys, `copy` setters, explicit
    `-copy`); retains become references and moves;
  - **`all`**: every `-copyWithZone:` **and** every `-retain`: the pessimistic bound, as if every
    extra owner of a string held a deep copy.
  The shadow copy is *added*, not substituted, so each mode is an upper bound (the real seam also
  deletes the `NSString` work). At exit the hook appends the game process's own user+kernel CPU
  and its copy counts to `OO_BENCH_STRING_REPORT`. The optimiser cannot elide the copy (checked in
  the generated assembly: `operator new`, `memset`, `operator delete` all remain).
- **A0** is the tree as it is, with no benchmark code at all.
- `tools/bench_string_copy.py` runs every blessed golden (`001`, `001-launch-dock`) exactly as
  `tools/tier-c.sh`'s goldens stage does, for each of A0 / B-off / B-copy / B-all, **interleaved in
  a freshly shuffled order per repetition**, and diffs every dump against its blessed golden (all
  88 runs matched: the hook changes no behaviour). The headline figure is **paired**: each
  repetition's variant divided by the same repetition's B-off, which cancels most of the machine's
  drift.
- `tools/bench/string-copy/unit_cost.cpp` is the noise-free half: it times one `std::string` copy
  (small-string, heap, per byte) on an idle core and prices each mode's *measured* traffic with it.

Reproduce (≈ 25 min on the fleet machine; builds, restores the tree, runs, prints all of the below):

```bash
bash tools/bench-string-copy.sh --reps 12
```

## Results

Two runs (10 and 12 repetitions) on 2026-09-23, back to back, on the shared fleet machine under
its normal concurrent load; pooled: 22 repetitions × 4 variants × 2 goldens.

Golden wall-clock, sum of both scenarios, **paired against B-off in the same repetition**:

| Variant | Median | IQR | Reading |
|---|---:|---|---|
| A0 (no benchmark code) | +4.4% | −6.8% … +16.4% | the **noise floor**: A0 and B-off do the same work |
| B-copy (representative) | **+0.1%** | −9.8% … +16.5% | indistinguishable from the control |
| B-all (pessimistic) | +16.5% | +3.6% … +53.5% | over the threshold |

Game-process CPU (user + kernel), paired against B-off (median B-off: 17.9 s CPU, 14.8 s wall):

| Variant | Median | IQR |
|---|---:|---|
| B-copy | +3.7% | −5.1% … +9.1% |
| B-all | +15.0% | +1.4% … +21.2% |

Measured copy traffic per golden pair (medians; identical run to run within 1%), priced by
`unit_cost` (3.3–3.4 ns per small copy, +19 ns per heap copy, 0.0047 ns per byte):

| Mode | Copies | of which heap | Bytes on the heap | Modelled added CPU |
|---|---:|---:|---:|---:|
| copy | 2,220,701 | 280,280 | 7.4 MB | **13 ms** (0.07% of 17.9 s) |
| all | 8,871,275 | 2,917,920 | 105 GB | 577 ms (3.2%) |

Run 1 alone: B-copy wall +2.1% / CPU +3.7%, B-all wall +18.0% / CPU +15.6%; run 2 alone: B-copy
+7.0% / +3.3%, B-all +16.5% / +13.5%, with the A0 control itself at +13.7% in run 2, which is why
neither run is quoted alone.

## Reading the numbers honestly

- **The machine's noise is larger than the threshold.** The control (A0 vs B-off, no difference
  in work) spreads over ±15% and its median sits at +4.4%. A 5% effect cannot be resolved at the
  golden level on this box by a single pair; the medians of 22 interleaved pairs can bound a large
  one, and the noise-free model sizes a small one.
- **B-copy:** the golden wall-clock shows nothing (+0.1%), and the model agrees: 13 ms of copying
  across two game launches that each take seconds. The +3.7% CPU median is within its own IQR and
  is mostly instrument cost (an Objective-C message per swizzled copy to read `-length`, plus the
  atomics), not string copying.
- **B-all:** over the threshold as measured. Two thirds of the measured cost is the instrument:
  giving `NSString` its own `-retain` takes every string off libobjc2's fast retain path. The
  copies themselves model at 0.58 s, ~3% of CPU, almost all of it in **105 GB of large strings**
  (2.9 M heap copies averaging 36 KB: whole files, script sources and plist texts retained over and
  over). That is the case value semantics must not be allowed to copy.

## Decision

The threshold was applied to the representative model, B-copy: **+0.1% golden wall-clock, below
5%. Decision 4 (`std::string`) stands; nothing is escalated.** The pessimistic bound is not the
design being adopted, and it becomes a rule instead, recorded for the String seam (bead oo-dps,
proposed ADR-0034):

> Where Objective-C **retained** a string, C++ takes a reference or a move, never a copy:
> parameters are `std::string_view` or `const std::string&`, ownership transfers are
> `std::move`, and a large text (a file's contents, a script source) is held once and shared by
> reference (`oo::Ref` of its owner). A `std::string` is copied only where Objective-C copied.

Seam sweeps that follow the rule stay in the B-copy regime. A sweep that copies large strings by
value per owner is a performance regression of the B-all kind and is caught by this benchmark:
rerun it after the String sweep lands (it needs no code change, only the same command).
