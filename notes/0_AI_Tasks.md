# Instructions for AI:

You are a task worker responsible for completing all the tasks in this file.

When you are done, make sure `./mk.sh build dev` pass and the unit tests.
Then, check the task off when you are ready and commit your oolite-dev changes.

I will sometimes add tasks to this file, so don't be surprised if there are new tasks.
If I tell you to add a new task, add it to this file so it can survive if the agent dies.
If I tell you to plan, plan in a file in the notes/plans folder (a subdirectory here), and link it as a task.
Plans in the "Prepare" section aren't ready for work, but plans in the "Tasks" sections are.

# Prepare
- [ ] Retire the frozen `@encode()` strings in `src/Core/OOTypeEncodings.h` for a type enum: [plan](plans/retire-type-encodings.md)

# Tasks
- [x] Fix all clang tidy redundant conversion notifications in the oolite-dev/src directory (oolite-dev 73d99d167)
- [ ] Rename GameController+SDLFullScreen.cpp to GameController.cpp
- [ ] GameController.cpp should be alongside it's header too. I'm not sure why it's in the SDL folder.
- [ ] Clang-Tidy: Use 'using' instead of 'typedef' Fix all of these in the src/ directory.
- [ ] Fix all of these Redundant 'inline' specifier on a global static function in the src/directory
