# ADR-0050: A message to an undeclared Objective-C method fails the build

- Status: Accepted (Jon, 2026-09-30, in chat). Recorded from the in-effect default.
- Date: 2026-09-28
- Beads: oo-tk0w (implements); oo-2o5x (evidence)

## Context

Phase 2 deletes Foundation bridge categories one bead at a time
([ADR-0043](0043-foundation-sweep-recipe.md) "Transitional bridges"). Each deletion
removes selectors. If a caller that still sends one of those selectors survives the
deletion, clang reports it only as a warning:

    warning: instance method '-objectForKey:inCache:' not found (return type defaults to 'id') [-Wobjc-method-access]

The program still links, because Objective-C dispatch is dynamic. The defect only shows up
at run time, as an `NSInvalidArgumentException ... unrecognized selector` or a crash.

This has already happened, in bead oo-2o5x:

- oo-5pae (merge b75b5d1bc) deleted `OOCacheManager+FoundationBridge` on the basis that it
  had "no remaining outside callers".
- `ResourceManager+FoundationBridge.mm` still sent `-objectForKey:inCache:` from six places.
  The build printed six `-Wobjc-method-access` warnings among roughly 86 others, and every
  gate that checks the exit status passed.
- Every launch of the game then died at startup with
  `-[OOCacheManager objectForKey:inCache:]: unrecognized selector`. As a result, tier-b's
  golden stage failed at scenario 001 ("Oolite exited ... before connecting to the
  console"). It failed 3 times out of 3 on a fresh phase-2 build.
- The failure first looked like an environmental flake, and a P1 investigation was needed to
  trace it back to a warning the compiler had already printed.

A warning is not enough for this class. The fleet agents read exit codes, not warning
text, and more bridge deletions are queued behind this one.

## Decision (recommended default)

The game's Objective-C and Objective-C++ translation units compile with
`-Werror=objc-method-access`, set by `add_project_arguments` in
`upstream/oolite/meson.build`.

- **It is stricter, not silencing.** It turns one existing diagnostic into an error, and it
  turns nothing off. CLAUDE.md hard rule 3 forbids only `-Wno-*`, diagnostic pragmas and
  unused attributes.
- **It is narrow.** It is not a blanket `-Werror`. Other warnings keep their current status,
  because promoting all of them would block the migration on style noise.
- **The fix for a hit is to send a declared method.** For example, move the caller to the
  `cxx_` API, or send to `id` when the protocol simply does not declare a method that the
  object implements. Casting to `id` is allowed only when the receiver really implements the
  method. It is not a way to paper over a deleted selector.
- **At adoption the tree is clean.** The last instance was `OOCache.mm:1049`, which sent
  `-description` to an `id<OOCacheComparable>` whose protocol does not declare it; it now
  sends to `(id)`. Before the flag, a planted revert of that fix built green with a warning;
  with the flag the build fails with
  `error: ... [-Werror,-Wobjc-method-access]`.

## Consequences

- A bead that deletes a bridge while a caller survives now fails `tools/build-windows.sh`,
  and so fails its own acceptance, instead of failing a later golden run.
- Code a bead touches after this change must declare every method it sends. That is what
  the migration needs anyway.
- If a future toolchain reports false positives, raise that with Jon as a new ADR. Do not
  remove the flag locally.

## Alternatives considered

- **A guard script that greps the build log for the warning.** This duplicates what the
  compiler already does, and it only works where the log is kept.
- **Blanket `-Werror`.** Too broad while about 80 unrelated warnings are still outstanding.
