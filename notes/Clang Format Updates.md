
Your current [.clang-format](vscode-webview://1p4je726cg52tg1fdbito2u5c9lvle5v3gdmej2a0oi8uqec3mfs/.clang-format) is just `BasedOnStyle: WebKit`, left over from the Objective-C era. There's no `.clang-tidy`. Both tools are installed through MSYS2.

## .clang-format

Google is a built-in preset, so the file is two lines:

```yaml
BasedOnStyle: Google
Language: Cpp
Standard: Latest      # C++23
```

Settings you may want on top of that:

- **Includes:** Google's preset sorts and regroups `#include`s. That can break code that depends on include order, which is common in older code. If the first run breaks the build, add `SortIncludes: Never` for now and turn it on later.
- **C and Objective-C files:** `Language: Cpp` doesn't cover `.m` or `.mm` files, which clang-format treats as `ObjC`. While the migration is in progress, format only `.cpp`, `.hpp` and `.h` files and exclude the ObjC ones. The `.h` files are ambiguous, so you may need a per-directory `.clang-format` or `--assume-filename`.
- **Plain-C code:** CLAUDE.md rule 9 says C stays verbatim. Reformatting it adds diff noise and invites merge conflicts. Either exclude it or accept a one-time reformat.
- **Line length:** the preset uses 80 columns. That's the main thing that will reflow existing code, so decide now whether to keep it.

**How it works:** clang-format only changes whitespace, line breaks and include order. It never changes behavior, so it is safe to automate.

- In the editor, "Format on save" (or `Shift+Alt+F`) in VS Code uses the nearest `.clang-format`.
- On the command line, `clang-format -i file.cpp` formats a file in place.
- `git clang-format` formats only the lines you changed.
- In CI or a guardrail, `clang-format --dry-run --Werror file.cpp` fails if the file isn't formatted.

**Rollout:** do one mass-reformat commit and nothing else in it. Record its hash in `.git-blame-ignore-revs` and run `git config blame.ignoreRevsFile .git-blame-ignore-revs`, so `git blame` skips it. Make that commit at a quiet point, because it will conflict with any open branches. After that, enforce formatting only on changed lines (`git clang-format`) so the fleet agents never re-reflow whole files.

## .clang-tidy

Yes, add one. Formatting only handles whitespace. clang-tidy checks the things Google's guide actually cares about: naming, `override`, `nullptr`, rule of five, and so on. The cleanest mapping is:

```yaml
Checks: >
  -*,
  google-*,
  -google-readability-todo,
  readability-identifier-naming,
  modernize-use-nullptr,
  modernize-use-override,
  modernize-use-using,
  bugprone-*,
  performance-*
WarningsAsErrors: ''
HeaderFilterRegex: 'src/.*'
FormatStyle: file
CheckOptions:
  - { key: readability-identifier-naming.ClassCase,           value: CamelCase }
  - { key: readability-identifier-naming.FunctionCase,        value: CamelCase }
  - { key: readability-identifier-naming.VariableCase,        value: lower_case }
  - { key: readability-identifier-naming.PrivateMemberSuffix, value: _ }
  - { key: readability-identifier-naming.ConstantCase,        value: CamelCase }
  - { key: readability-identifier-naming.ConstantPrefix,      value: k }
  - { key: readability-identifier-naming.EnumConstantCase,    value: CamelCase }
  - { key: readability-identifier-naming.EnumConstantPrefix,  value: k }
```