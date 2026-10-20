# ADR-0062: Objective-C-only inputs inside test cases whose subject survives

- Status: Proposed (default in effect for planning only; the test changes it describes wait for Jon,
  because [delegated-2026-10-19](delegated-2026-10-19.md) keeps them his)
- Date: 2026-10-20
- Beads: oo-4aq6a (retire OOObject and OOConstantString), its slices oo-4aq6a.3 (OOPriorityQueue),
  oo-4aq6a.5 (Objective-C objects in plist data and by-name calls), oo-4aq6a.7 (shader binding
  targets), oo-dbz (drop libobjc2)

## Context

oo-4aq6a can close only when no Objective-C object is made, in `src` or in the tests. Batch BA
re-based every test whose Objective-C stand-in is the test's own business (oo-4aq6a.2,
oo-4aq6a.4, oo-4aq6a.11: std-2026-10-19 item 1) and retired a test whose only subject went
(oo-4aq6a.9: item 2). What remains in `src` are paths that exist only for Objective-C objects,
which no game class makes any more: the Objective-C `OOPriorityQueue`, `OOCallByName(id, ...)`
and the debug console's `OOJSCallObjCObjectMethod` on a non-entity object, the `PList::Object`
node of an Objective-C object (`oo::PListObject`, `SendIntValue`), the shader uniform's
Objective-C binding target (selector, IMP, return-type encoding), the JS engine's `id` private
slot. Deleting each is behaviour-identical for the game. But some of their tests are cases with
two subjects: a surviving C++ path and an Objective-C input to the deleted one:

1. test_OOPriorityQueue's `cxxQueueGivesTheSameOrder` and `cxxQueueHoldsAndRemovesByIdentity`
   check OOPriorityQueueOf against the Objective-C queue as an oracle.
2. test_OOCharacter's `dictionaries` passes an Objective-C object answering `-intValue` as one
   of several `origin` inputs.
3. test_OOShaderUniform's binding cases bind an Objective-C target by selector; the convert
   options they pin (clamp, normalise, to-matrix, colour) survive on the C++ target factory,
   which takes the uniform type explicitly where the selector path read it from the method's
   return-type encoding.

std-2026-10-19 covers re-bases that keep every input and whole-case retirements; it does not
cover dropping an input inside a surviving case, or re-expressing an oracle as a literal.

## Decision (recommended defaults, for Jon)

1. **Oracle -> measured literal.** Where a case compares a surviving C++ path with a deleted
   Objective-C one, the expected value becomes the Objective-C path's output measured on the
   tree before the deletion, written as a literal, in the same change; the case and its other
   checks stay.
2. **Objective-C-only inputs leave with their path.** A check whose input can only be an
   Objective-C object (an object in a `PList::Object` node, a selector-bound Objective-C target)
   retires with the path the same change deletes; the case's other checks stay. Each use names
   the check (file, case, line) in its approval line.
3. **A surviving behaviour pinned only through a deleted path is re-pinned first.** Where the
   only check of surviving behaviour (the shader uniform's convert options) goes through the
   Objective-C path, the change adds the same check through the C++ path before retiring the
   Objective-C one.

Until Jon approves (a line in `tools/retire-test-approvals.txt` citing this ADR), the slices
that need it (oo-4aq6a.3, .5, .7) stay open, and oo-4aq6a, oo-dbz with them.

## Consequences

- With 1-3 approved, oo-4aq6a's remaining slices are mechanical deletions plus re-bases.
- Without them, the Objective-C runtime floor stays for these test inputs alone; the game makes
  no Objective-C object either way.
