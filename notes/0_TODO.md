Reference: https://github.com/jonmseaman/oolite/branches/all

## TODO 
- [ ] Use Google test instead of custom assertions.
- [ ] Encapsulate platform-specific code into classes.
- [ ] Encapsulate global state into classes.
- [ ] Use feature flags instead of compile-time macros (works better with IDEs + clang-tidy).
- [ ] Further replacements of oofnd with C++ std libraries.

## In-Progress

- [ ] Use a namespace instead of OO prefix.


## Maybe

- [ ] Google style guide with cpplint:
    CheckOptions:
        - { key: readability-identifier-naming.ClassCase,           value: CamelCase }
        - { key: readability-identifier-naming.FunctionCase,        value: CamelCase }
        - { key: readability-identifier-naming.VariableCase,        value: lower_case }
        - { key: readability-identifier-naming.PrivateMemberSuffix, value: _ }
        - { key: readability-identifier-naming.ConstantCase,        value: CamelCase }
        - { key: readability-identifier-naming.ConstantPrefix,      value: k }
        - { key: readability-identifier-naming.EnumConstantCase,    value: CamelCase }
        - { key: readability-identifier-naming.EnumConstantPrefix,  value: k }
    NB EnumConstant* covers scoped AND unscoped constants, so it puts all 175 unscoped enums in
    scope at once. ScopedEnumConstant* confines it to enum class, which is what lets the enum
    work land incrementally.

More branches:
- SDL_Net? What was the platform specific http test that was broken?

- [ ] Do a write up of this project to send to upstream.
	- Include why I did this.
	- How I did this.
	- How I designed tests, what tests were created, results.
	- Phase plan with a summary of each one.
	- Future improvement ideas. Upgrade to arm, replace plist maybe, fine tune the menus, other modernization ideas.
- [ ] Idea: Visual studio support?
- [ ] Typescript tests?
- [ ] Get rid of Gherkin tests, apply what was in the upstream testing pull request.
- [ ] Remove OO prefix?
- [ ] Google style guide with cpp lint.

- [ ] Unit tests passing on ubuntu, mac.
- [ ] Decrease oofnd usage.
- [ ] Use Google Test instead of OOAssert?
- [ ] Should delete probably the gui tests and other tests to clean up.

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
- Refactor codebase - It would make it much harder for me to port upstream
  changes, which are in a different language. Any rename or substantial
  refactors could make it impossible to merge between languages.
