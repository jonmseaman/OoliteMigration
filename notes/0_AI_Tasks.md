# Instructions for Task Executor:

You are a task worker responsible for completing all the tasks in this file.

When you are done, make sure `./mk.sh build dev` pass and the unit tests.
Then, check the task off when you are ready and commit your oolite-dev changes.

I will sometimes add tasks to this file, so don't be surprised if there are new tasks.
Plans in the "Prepare" section aren't ready for work, but plans in the "Tasks" sections are.

# Instructions for Task Planner:

You turn Jon's requests into tasks in this file. You do not change code in `oolite-dev`.

- **Adding a task:** if Jon tells you to add a task, add it under "Tasks" straight away, so it
  survives if the agent dies. Look at the code first, so the task can name the files, the
  `file:line` and the size (for example "326 uses in 34 files").
- **Planning:** if Jon tells you to plan, write the plan in `notes/plans/<short-name>.md` and link
  it from a one-line task. A new plan goes under "Prepare". Move it to "Tasks" only when Jon says it
  is ready.
- **Every task and plan needs a done check:** a command, run from `oolite-dev`, that exits nonzero
  before the work and zero after. It usually comes on top of `./mk.sh build dev` and
  `tests/run.sh unit`. If you can't write one, say so in the task.
- **Look at the code, not just the request.** Work out who uses the thing, what upstream
  (`upstream/oolite`) does, and which tests pin the behaviour. A task should state what is dead,
  frozen or duplicated, with evidence. Don't guess.
- **Tests:** if the work would edit a test, check the hard rules in `CLAUDE.md`. Where no
  exception covers the edit, say so and ask Jon to sign off. Once he has, record the date in the
  task and add a test-change ledger to the plan: file, edit, and whether each assertion's meaning
  is kept.
- **Defaults:** take the conservative option, so behaviour stays the same and the tests pass
  unedited. Record it under "Decisions" in the plan, with the reason.
- **Order:** if two tasks touch the same lines, put the dependency in the later task ("do X first").
- **What a plan contains:**
  - why the work is needed;
  - the done check;
  - the design: each consumer and what changes there;
  - the steps;
  - the test-change ledger, if there is one;
  - the decisions taken and their defaults;
  - what is out of scope, with a follow-up if it's worth doing.

  Keep it to what the executor needs, and don't add history.
- **Commits:** commit nothing in `oolite-dev`. Edits to `notes/` stay uncommitted unless Jon asks.

# Prepare

# Tasks
- [ ] Delete `src/Core/OOTypeEncodings.h`; carry return types as a compile-time `OOValueType` enum (test edits signed off 2026-11-15): [plan](plans/retire-type-encodings.md)
- [x] Fix all clang tidy redundant conversion notifications in the oolite-dev/src directory (oolite-dev 73d99d167)
- [x] Rename GameController+SDLFullScreen.cpp to GameController.cpp (oolite-dev 796b9556d)
- [x] GameController.cpp should be alongside it's header too. I'm not sure why it's in the SDL folder. (oolite-dev 1ad3e3e3e: merged into src/Core/GameController.cpp, under OOLITE_SDL)
- [x] Clang-Tidy: Use 'using' instead of 'typedef' Fix all of these in the src/ directory. (oolite-dev 603decc60; check now an error)
- [ ] Fix all of these Redundant 'inline' specifier on a global static function in the src/directory
- [ ] Replace the `OOINLINE` macro (`src/Core/OOFunctionAttributes.h:24`, `#define OOINLINE inline`) with plain `inline` at every use (326 uses in 34 files, all under src/; tests/ has none), then delete the `#define`. Do the 'Redundant inline' task above first, or drop `inline` where clang-tidy calls it redundant. Done when `git grep -q OOINLINE -- src tests` exits nonzero.
- [ ] Remove the `OOLITE_OPENAL` macro. It is always 1 (`src/Core/OOSound.h:48`, unconditional `#define`; nothing else sets it). In `OOSound.h` and `OOSoundInternal.h`, unwrap the `#if OOLITE_OPENAL` blocks and delete the dead `#else #warning …` branches. In `src/Core/OOLogHeader.cpp:101`, keep `"OpenAL"` in the feature list without the `#if`. Done when `git grep -q OOLITE_OPENAL -- src tests` exits nonzero.
- [ ] Resolve Possibly unused #include directive for all obviously unused includes. If there is platform specific code in the file, please make sure it is not used on any platform.
- [ ] Resolve all the redundant static_cast tidies in the src/ directory.
- [ ] Declare structs, unions and enums directly instead of aliasing them with `using` (what clang-tidy's typedef→using fix left behind: 59 lines in src/, 22 of them anonymous). Do the 'using instead of typedef' task first, since these lines come from it.
  - `using X = struct X { … };` → `struct X { … };`
  - `using X = struct { … };` (anonymous, e.g. `ChainedEntityPredicateParameter`, `BinaryOperationPredicateParameter` in `OOEntityFilterPredicate.h`) → `struct X { … };`. Same for `union`/`enum`.
  - `using X = struct X;` (forward declaration, e.g. `AI.cpp:388`) → `struct X;`
  - `using XRef = struct X*;` (e.g. `OOTCPStreamDecoder.h:35`, `OOTCPStreamDecoderAbstractionLayer.h:22-25`) → `struct X;` once, then `using XRef = X*;`
  - Leave plain type aliases alone (`using OOMeshSmoothGroup = uint16_t;` and the like). Those are what `using` is for.
  - Done when `git grep -qE 'using \w+ = (const )?(struct|union|enum)\b' -- src` exits nonzero.
