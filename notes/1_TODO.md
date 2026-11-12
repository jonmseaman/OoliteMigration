TODO Mac icon used to have a grey background, then it was gone... Sometimes it is there and sometimes not.

More branches:
- Cleanup pass (plan on WinPC)
- TBL drop, switch to enums... — planned: [[2026-11-07 Enum Tables from tbl X-Macros]]
- oofnd cleanup, stop using that, use C++ types instead.
- SDL_Net? What was the platform specific http test that was broken?
- Google test instead of custom?
- Google style guide with cpplint:
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
    work land incrementally: [[2026-11-07 Enum Tables from tbl X-Macros]]

- Convert tools directory to C++.
- Import javascript tests from the upstream.
- Encapsulation pass.

https://github.com/jonmseaman/oolite/branches/all

----------------------------------------



- [ ] Do a write up of this project to send to upstream.
	- Include why I did this.
	- How I did this.
	- How I designed tests, what tests were created, results.
	- Phase plan with a summary of each one.
	- Future improvement ideas. Upgrade to arm, replace plist maybe, fine tune the menus, other modernization ideas.
- [ ] Idea: Visual studio support?
- [ ] Try a rust version with Bevy one day?
- [ ] Typescript tests?
- [ ] Get rid of Gherkin tests, apply what was in the upstream testing pull request.
- [ ] Remove OO prefix?
- [ ] Google style guide with cpp lint.

- [ ] Unit tests passing on ubuntu, mac.
- [ ] Decrease oofnd usage.
- [ ] Use Google Test instead of OOAssert?
- [ ] Should delete probably the gui tests and other tests to clean up.
- [X] Fix unit tests taking over 1h