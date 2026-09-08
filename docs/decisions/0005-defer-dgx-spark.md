# ADR-0005: Do not buy inference hardware now; inference is a network endpoint behind configuration

**Status:** Accepted · **Date:** 2026-09-05 (amended same day)

## Context

The question was whether to stand up an agent fleet on a DGX Spark. Measured: the bottleneck is
validation machine-time (GNUstep built from source, 20 real game launches per golden run,
ASan/UBSan), which is x86-64 Linux/Windows build-farm work, not inference. The workload that would
justify bulk local inference (Phase 4 fan-out) starts at month 10–16. The one large batch job
available today (the expansion scan, 818–1,591 small classifications) is tens of dollars of rented
GPU time.

## Decision

1. Do not buy now. Re-evaluate at Phase 4 entry with measurements from the scan pilot.
2. **Model routing is configuration, not architecture.** Every task class maps to an
   OpenAI-compatible endpoint URL in config; the endpoint's identity (rented GPU, a Spark on the
   LAN, a frontier API) is a config change.
3. **Never put an inference endpoint on Tier A's critical path.** Tier A is compiler, linter, and
   deny-list only: under 30 seconds, offline.
4. If money is to be spent on hardware today, spend it on an x86-64 Linux CI runner (high core
   count, NVMe, 64–128 GB RAM), useful from Phase 0 onward.

## Consequences

- The aarch64-vs-x86 objection to the Spark is void once it is a pure inference endpoint; the
  remaining objections (timing, bandwidth profile suits batch not interactive, rentable today) stand.
- The scan pilot must hand-audit a random 50 of its outputs before any bulk model output is trusted.

## History

`AI_EXECUTION_PLAN.md` §2 (original "don't buy"), §12 (amendment: network endpoint defeats
reason 1). The original version of §2 also assumed the Spark would host agents and builds.
