
## Tasks

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
## Later/Maybe


**TODO** Support Apple Silicon
**TODO** Data formats - Support something like JSON5 alongside plist/tbl files.
**TODO** Modern C++
- Use Modern C++ idioms like constructors instead of initWith, constants instead of macros, std types instead of `oofnd`
- Use a modern style guide like https://google.github.io/styleguide/cppguide.html
- C++ unit test library instead of custom.
- C++ modules instead of header includes?
- Use a renderer like GL 3.3 Core (or SDL3 GPU)?

## Out of scope

- Feature development - This would be great, but is not part of this.
- Refactor codebase - There is some potential for refactor that could make it easier for feature development later, but it would make it much harder for me to merge in upstream changes, which are in a different language. Any rename or substantial refactors could make it manual merges instead of AI merges.

