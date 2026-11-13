# Research: Replace the last `.tbl` table

## R1. The base

`seriesb/027-modern-cpp` (`3732f6126`), C++23 (`src/meson.build`). Spec 009's T060–T063 are on it,
so the ten enum tables are already headers in `src/Core/Tables`; `OOOpenGLStates.tbl` is the one
table left (`git grep '\.tbl"'` finds its five includes in `OOOpenGLStateManager.cpp` and nothing
else). The base builds with `-Wold-style-cast`, and `StateFlag` is already
`enum class StateFlag : std::uint8_t { kFalse, kTrue, kMaybe }`.

## R2. The OpenGL state list as plain code

**What it is.** 30 items in this order: 16 flags (`LIGHTING` … `RESCALE_NORMAL`), 6 client-array
flags, the special `DEPTH_WRITEMASK` (`bool`), the flag `CULL_FACE`, the integer `SHADE_MODEL`, the
specials `TEXTURE_ENV_MODE`, `ACTIVE_TEXTURE`, `CLIENT_ACTIVE_TEXTURE` (`GLenum`), the integers
`CULL_FACE_MODE`, `FRONT_FACE`. Five expansions: the record's fields, read (debug only), compare
(debug only), log mismatches (debug only), write. The blend function sits outside the list in all
five and stays there.

**Decision.**
- **The record.** `OOOpenGLState` stays a struct with one named field per item, so the five
  standard states keep their designated initialisers (`.LIGHTING = StateFlag::kTrue`).
- **The table.** The `.tbl` becomes one `constexpr` table of items, `kStateItems`, in
  `OOOpenGLStateManager.cpp`. Each item holds its log name, its GL enumerant and a function per
  step.
- **The builders.** Each item is built by a function template for its kind. The template takes
  the item's field and, for specials and integers, its getter and setter as template arguments,
  so a missing one does not compile.
- **The steps.** Read, compare, log and write become loops over the table. The log step returns
  the two strings to print, and `VerifyOpenGLStateInternal` prints them itself, so each line is
  still logged from that function.
- **The field count.** A `consteval` count of the struct's fields is `static_assert`ed equal to
  `1 + items + 2` (the name, the items, the two blend fields). It is the aggregate-initialisation
  count, checked on Clang 23.1 and GCC 15.2 in C++23 with `std::string_view` and `enum class`
  fields. A field without an item, or an item without a field, therefore fails the build.

**Behaviour to keep exactly.**
- **Order.** The log prints mismatches in table order.
- **The "maybe" rule.** Compare and write skip a flag when either side is maybe, and the log skips
  it when the expected value is maybe.
- **The blend function.** It is written when its values differ *or* the source state's `BLEND` is
  `kFalse`.
- **A quirk.** The verifier logs **every** special item through `OOGLFlagToString`, ignoring the
  display function the table names.
- **The getters.** `GetState_*` were compiled only without `NDEBUG`. They are now compiled always,
  because the builders name them; they are called only when `OO_GL_STATE_VERIFICATION` is on.

**Differences only a heavy-check build can see.** With `OO_CHECK_GL_HEAVY`, `OOGL()` logs the text
of a GL call that raised an error, and that text changes (`glEnable(cap)` where it was
`glEnable(GL_LIGHTING)`). The function it notes is ignored here, because the state manager turns
function tracking off around its own calls. Accepted: the text appears only on a GL error, in a
build option nobody ships.

**Alternatives.**
- **(a) Arrays indexed by an item enum in the record.** One list, but the standard states would
  become positional arrays of 30 values each and lose their labels. Rejected.
- **(b) The same X-macro list as a macro inside the `.cpp`.** Still a preprocessor contract, just
  not in a file. Rejected.

## R3. Proving the log is unchanged

`oo::log::Logger` has `setSink()` and `setDisplay()`, so a unit test can turn on
`rendering.opengl.state` and capture the lines. `test_OOOpenGLStateVerifier` sets
`OPENGL_STATE_OPAQUE` and changes one item of each kind behind the manager's back:
- a flag;
- a client-array flag;
- a `bool` special;
- an integer;
- a `GLenum` special, for the quirk;
- the blend mode.

It then calls `OOVerifyOpenGLState()` and checks the six mismatch lines in order. It also checks
that an open item (`LIGHT0`) is not reported and that GL is repaired. It is written and passing on
the base first.

## R4. Where the work happens

`oolite-dev`'s own checkout is in use by another session, so the work is in a worktree:

```bash
git -C oolite-dev worktree add ../.agent-tmp/wt-tbl seriesb/027-modern-cpp
```

with `oolite-dev/subprojects/quickjs-0.17.0` copied into it. Remove it with
`git -C oolite-dev worktree remove ../.agent-tmp/wt-tbl`, never `prune`. `seriesb/028-upstream-772-tests` is a
child of `seriesb/027-modern-cpp` and is checked out in `.agent-tmp/wt-772`; it needs a
`git town sync` after these commits, from wherever it is checked out.
