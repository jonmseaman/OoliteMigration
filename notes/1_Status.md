# Oolite C++

Since early September, I've been working on a C++ conversion of this project.

## Project

## Tasks and Progress

**DONE** Phase 0 - Safety net
- Introduce python component tests, gui tests, and others to prevent regressions in the Objective C to C++ migration.
**DONE** Phase 1 - JS engine (De-Mozilla)
- Introduced quickjs-ng similar to another pull request. Removed Spider Monkey.
- Scanned expansions for compatibility issues. Expansions *will not* all be compatible with this change as there are some js differences between the two engines.
**DONE** Phase 2 - Obj-C to C++20
- Built as Objective-C++.
- Created an `oofnd` library for incremental conversion from Objective-C to C++, which replaces the Foundation library from Objective-C.
**DONE** Phase 3 - C++ Conversion
- Convert various Objective-C code pieces to C++. (e.g. `@interface` to `class` in cpp)
- ~500 files converted to C++.
**DONE** Phase 4 - Remove Objective-C runtime.
- Build entirely with clang in C++ mode.
- Remove `libobjc2` and rename `.mm` files to `.cpp`.
- GNUStep is gone from compilation.


**TODO** Phase 5 - Prepare for merge.
- **DONE** Basic playtest. I did a playtest by starting a new game. I was able to fly the ship, buy/sell cargo, fly around, jump systems without issues (after a couple bugfixes). I also completed the tutorial. No bugs detected here.
- **DONE** Support Apple Silicon - From the Git repo, it seems like this was broken, but recently fixed. I need to investigate making this work with my changes. I confirmed that the latest upstream builds and runs on my mac.
- **TODO** Integrate needed PRs such as:
  - https://github.com/OoliteProject/oolite/pull/767 - quickjs, but behind a flag.
  - https://github.com/OoliteProject/oolite/pull/771 - SDL GPU change.
  - https://github.com/OoliteProject/oolite/pull/772 - JavaScript tests change.
- **TODO** More thorough playtest - Test more features like buying ships, load/save, dying, killing pirates, etc.
- **TODO** More thorough testing - Add tests from this upstream PR and convert current tests into js instead of python. <where?>
- **TODO** More thorough code review. Read through many files to compare to the objective c source code. I need to compare against the current upstream code to spot discrepancies in recent commits.



## Questions

**TODO** Keep QuickJS as is, or add backwards compatible spidermonkey with a flag as in <where?>. QuickJS has some differences with spidermonkey, and so some expansions would not continue to work without changes.


## Out of scope

-  Data formats - Support something like JSON5 alongside plist/tbl files.
	- plist seems like an Objective-C thing, but don't see any strong reason to change it for now.
- Modern C++
	- Making the code base more idiomatic for C++ would be good, but it would also
	  make it essentially impossible for me to merge in Objective-C changes from
	  upstream, so I'm not tackling that just yet.
	- Use Modern C++ idioms like constructors instead of initWith, constants
	  instead of macros, std types instead of `oofnd`
	- Use a modern style guide like
	  https://google.github.io/styleguide/cppguide.html
	- C++ unit test library instead of custom.
	- Clang Tidy and consistent naming rules for constants, functions, classes.
- Feature development - This would be great, but is not part of this.
- Refactor codebase - It would make it much harder for me to merge in upstream
  changes, which are in a different language. Any rename or substantial
  refactors could make it impossible to merge between languages.
