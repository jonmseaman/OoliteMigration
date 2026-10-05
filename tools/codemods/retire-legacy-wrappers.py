#!/usr/bin/env python3
"""Retire the Foundation-shared legacy wrappers beside their cxx_ twins (ADR-0055 item 3).

WHY THIS EXISTS

The Foundation sweep (ADR-0043) gave every method whose selector Foundation also declares
(-name, -setName:, -initWithName:, -title, -setTitle:, -version, -state, -function,
-dependencies, -initWithDictionary:, -initWithPath:, -initWithContentsOfFile:) a C++-typed twin
-cxx_<selector>, and kept the id-typed original as a wrapper for callers whose receiver might
have been a Foundation object. Each wrapper is marked "shared selector (Foundation declares ...)"
on its declaration and definition. Once gnustep-base goes there is no Foundation object for such
a caller to hold, so the wrappers are deleted, in ONE tree-wide commit (bead oo-qps.44): deleting
them file by file would leave [obj name] dispatching at run time to a class that no longer
answers it, which aborts (ADR-0029). -Werror=objc-method-access (ADR-0050) then reports every
caller left behind; the author moves each to the cxx_ twin (the prefix stays: Phase 3 drops it,
ADR-0043 item 6).

WHAT --fix DELETES (outside comments and strings)

  a declaration line   - (id) name;	// shared selector (Foundation declares -name too): ...
  a definition         - (id) name	// shared selector (Foundation declares -name too; ...)
                       { ... }        (through its matching brace)
  and the blank lines after the deleted text, so the spacing around it stays as it was.

A marker in a block comment (prose about the twin) is not a method: --check reports it as
'prose' for the author to reword.

WHAT --check REPORTS (exit 1 if anything)

  wrapper  a marked declaration or definition still present
  prose    any other line that still says "Foundation declares"

USAGE

    python3 tools/codemods/retire-legacy-wrappers.py --check DIR|FILE...
    python3 tools/codemods/retire-legacy-wrappers.py --fix DIR|FILE...
    python3 tools/codemods/retire-legacy-wrappers.py --selftest
"""

import os
import re
import sys

EXTENSIONS = ('.h', '.m', '.mm')
MARKER = 'Foundation declares'
SIGNATURE = re.compile(r'^[-+][ \t]*\([^)\n]*\)[^\n;{]*?(;?)[ \t]*//[^\n]*[Ss]hared selector \(Foundation declares[^\n]*$', re.M)


def matching_brace(src, start):
    """Offset just past the '}' matching the '{' at src[start], skipping comments and strings."""
    depth, i, n = 0, start, len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            i = src.find('\n', i)
            if i < 0:
                return n
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in '"\'':
            j = i + 1
            while j < n and src[j] != c and src[j] != '\n':
                j += 2 if src[j] == '\\' else 1
            i = j + 1
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


def wrappers(src):
    """[(start, end)] of every marked declaration or definition, end past its trailing newline."""
    found = []
    for m in SIGNATURE.finditer(src):
        start = m.start()
        if m.group(1):
            end = m.end()
        else:
            brace = src.find('{', m.end())
            if brace < 0 or src[m.end():brace].strip():
                continue
            end = matching_brace(src, brace)
        if end < len(src) and src[end] == '\n':
            end += 1
        found.append((start, end))
    return found


def fix_source(src):
    for start, end in reversed(wrappers(src)):
        # Drop the blank lines that followed the wrapper, so its neighbours keep their spacing.
        while True:
            line_end = src.find('\n', end)
            if line_end < 0 or src[end:line_end].strip():
                break
            end = line_end + 1
        src = src[:start] + src[end:]
    return src


def check_source(src):
    """[(line, kind, text)] of what is left."""
    lines = src.split('\n')
    found, spans = [], wrappers(src)
    wrapper_lines = {src.count('\n', 0, start) + 1 for start, _ in spans}
    for number, line in enumerate(lines, 1):
        if MARKER in line:
            found.append((number, 'wrapper' if number in wrapper_lines else 'prose', line.strip()))
    return found


def walk(paths):
    for path in paths:
        if os.path.isdir(path):
            for root, dirs, files in os.walk(path):
                dirs.sort()
                for f in sorted(files):
                    if f.endswith(EXTENSIONS):
                        yield os.path.join(root, f)
        else:
            yield path


def main(argv):
    if argv[1:] == ['--selftest']:
        return selftest()
    if len(argv) < 3 or argv[1] not in ('--check', '--fix'):
        print(__doc__)
        return 2
    mode, total = argv[1], 0
    for path in walk(argv[2:]):
        with open(path, encoding='utf-8', newline='') as f:
            src = f.read()
        if mode == '--fix':
            out = fix_source(src)
            if out != src:
                with open(path, 'w', encoding='utf-8', newline='') as f:
                    f.write(out)
                print('fixed %s' % path)
        else:
            for line, kind, text in check_source(src):
                print('%s:%d: %s: %s' % (path, line, kind, text))
                total += 1
    if mode == '--check':
        print('%d legacy wrapper line(s)' % total)
        return 1 if total else 0
    return 0


FIX_CASES = [
    ('declaration', '- (id) cxx_a;\n- (id) name;\t// shared selector (Foundation declares -name too): x\n- (void) b;\n',
     '- (id) cxx_a;\n- (void) b;\n'),
    ('definition and spacing', '- (void) a\n{\n}\n\n\n- (id) name\t// shared selector (Foundation declares -name too; retires with oo-qps)\n'
     '{\n\treturn oo::NSStringOrNil([self cxx_name]);\t// "}" in a string, } in a comment\n}\n\n\n- (void) b\n{\n}\n',
     '- (void) a\n{\n}\n\n\n- (void) b\n{\n}\n'),
    ('setter with argument', '- (void) setName:(id)name\t// shared selector (Foundation declares -setName: too; retires with oo-qps)\n'
     '{\n\tif (x) { y(); }\n}\n\n\n- (void) c;\n', '- (void) c;\n'),
    ('unmarked twin kept', '- (std::optional<std::string>) cxx_name;\t// the twin\n',
     '- (std::optional<std::string>) cxx_name;\t// the twin\n'),
    ('prose kept', '/*\tFoundation declares -initWithDictionary: too, so its typed form is the twin\n*/\n',
     '/*\tFoundation declares -initWithDictionary: too, so its typed form is the twin\n*/\n'),
]

CHECK_CASES = [
    ('wrapper and prose', '- (id) name;\t// shared selector (Foundation declares -name too)\n// Foundation declares it\n',
     [(1, 'wrapper'), (2, 'prose')]),
    ('clean', '- (std::optional<std::string>) cxx_name;\n', []),
]


def selftest():
    failures = 0
    for name, before, after in FIX_CASES:
        got = fix_source(before)
        if got != after:
            failures += 1
            print('selftest fix %r:\n--- got\n%s--- expected\n%s' % (name, got, after))
    for name, src, want in CHECK_CASES:
        got = [(line, kind) for line, kind, _ in check_source(src)]
        if got != want:
            failures += 1
            print('selftest check %r: got %r, expected %r' % (name, got, want))
    print('selftest: %d failure(s) in %d cases' % (failures, len(FIX_CASES) + len(CHECK_CASES)))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
