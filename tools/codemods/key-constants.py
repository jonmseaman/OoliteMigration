#!/usr/bin/env python3
"""Key constants become C++ constants: @"..." key macros -> std::string_view (ADR-0055 item 6).

WHY THIS EXISTS

The game names its dictionary and preference keys with Objective-C string constants
(`#define KEY_NAME @"name"`, `NSString *const kX = @"x"`), and the files the Foundation sweep
migrated read them back as C++ text through the bridge: 562 lines of `oo::StdString(KEY_NAME)`.
Once gnustep-base is unlinked there is no NSString for such a constant to be, so each becomes an
`inline constexpr std::string_view` with the same spelling (oo-qps.8's form for kOOManifest*,
Core/OOManifestProperties.h), and each `oo::StdString(KEY)` becomes `std::string(KEY)`. The
constants are shared by many files through a few headers, so the flip is one tree-wide commit
(bead oo-qps.42); the uses --fix cannot rewrite (a key compared, formatted, or handed to an API
still typed `id`) are compile errors the author adapts by hand.

WHAT IS A TARGET

A key constant defined by an Objective-C string literal, in any of these forms (a trailing
comment is kept):

  #define NAME @"x"                     #define NAME (@"x")
  [static] NSString *const NAME = @"x";  [static] NSString * const NAME = @"x";

that the tree reads at least once as `oo::StdString(NAME)` (directly, or through an alias
`#define ALIAS NAME`). A constant never read that way is not this codemod's: it stays an
Objective-C literal until the chunk that removes its last `id` use.

WHAT --fix REWRITES

  in a header (.h)                      inline constexpr std::string_view NAME = "x";
  in a source file (.m, .mm)            static constexpr std::string_view NAME = "x";
  (the whitespace between the name and the value is kept, so aligned tables stay aligned;
  `#include <string_view>` is added after the file's last leading #import/#include)
  oo::StdString(NAME), oo::StdString(ALIAS)   std::string(NAME), std::string(ALIAS)

Every file is rewritten, Mac-fenced code included: a constant has one type, so every use of it
must agree (ADR-0055 item 7 leaves fenced helper calls alone, but a fenced use of a retyped
constant would not compile on the Mac either way).

WHAT --check REPORTS (exit 1 if anything)

  stdstring  an `oo::StdString(NAME)` of a key constant: an @"..." one (not yet flipped) or a
             std::string_view one (a leftover use)

USAGE

    python3 tools/codemods/key-constants.py --check <root>
    python3 tools/codemods/key-constants.py --fix <root>
    python3 tools/codemods/key-constants.py --selftest
"""

import os
import re
import sys

EXTENSIONS = ('.h', '.m', '.mm')
IDENT = r'[A-Za-z_][A-Za-z0-9_]*'
STRING = r'"(?:[^"\\\n]|\\.)*"'
TRAIL = r'(?P<trail>\s*(?://.*|/\*.*)?)$'

# #define NAME @"x"  /  #define NAME (@"x")
DEFINE_RE = re.compile(r'^(?P<lead>[ \t]*)#[ \t]*define[ \t]+(?P<name>' + IDENT + r')(?P<ws>[ \t]+)'
                       r'(?:@(?P<s1>' + STRING + r')|\([ \t]*@(?P<s2>' + STRING + r')[ \t]*\))' + TRAIL)
# [static] NSString *const NAME = @"x";
CONST_RE = re.compile(r'^(?P<lead>[ \t]*)(?:(?P<static>static)[ \t]+)?NSString[ \t]*\*[ \t]*const[ \t]+'
                      r'(?P<name>' + IDENT + r')(?P<ws>[ \t]*)=[ \t]*@(?P<s1>' + STRING + r')[ \t]*;' + TRAIL)
# inline|static constexpr std::string_view NAME = "x";   (already flipped)
VIEW_RE = re.compile(r'^[ \t]*(?:inline|static)[ \t]+constexpr[ \t]+std::string_view[ \t]+(?P<name>' + IDENT + r')[ \t]*=')
# #define ALIAS NAME
ALIAS_RE = re.compile(r'^[ \t]*#[ \t]*define[ \t]+(?P<name>' + IDENT + r')[ \t]+(?P<target>' + IDENT + r')' + TRAIL)
STDSTRING_RE = re.compile(r'oo::StdString\([ \t]*(?P<name>' + IDENT + r')[ \t]*\)')
INCLUDE_RE = re.compile(r'^[ \t]*#[ \t]*(?:import|include)\b')


def read(path):
    with open(path, encoding='utf-8', newline='') as f:
        return f.read()


def walk(root):
    if os.path.isfile(root):
        yield root
        return
    for d, dirs, files in os.walk(root):
        dirs.sort()
        for name in sorted(files):
            if name.endswith(EXTENSIONS):
                yield os.path.join(d, name).replace('\\', '/')


def definitions(sources):
    """{name: 'objc'|'view'} for every key constant, plus {alias: target}."""
    kinds, aliases = {}, {}
    for src in sources.values():
        for line in src.splitlines():
            m = DEFINE_RE.match(line) or CONST_RE.match(line)
            if m:
                kinds[m.group('name')] = 'objc'
                continue
            m = VIEW_RE.match(line)
            if m:
                kinds[m.group('name')] = 'view'
                continue
            m = ALIAS_RE.match(line)
            if m:
                aliases[m.group('name')] = m.group('target')
    # An alias of a key constant is a key constant of the same kind (resolved transitively).
    changed = True
    while changed:
        changed = False
        for alias, target in aliases.items():
            if target in kinds and alias not in kinds:
                kinds[alias] = kinds[target]
                changed = True
    return kinds, aliases


def root_of(name, aliases, kinds):
    seen = set()
    while name in aliases and aliases[name] in kinds and name not in seen:
        seen.add(name)
        name = aliases[name]
    return name


def targets(sources):
    """The @"..." constants read through oo::StdString (via an alias or not), and every name to rewrite."""
    kinds, aliases = definitions(sources)
    read_names = set()
    for src in sources.values():
        for m in STDSTRING_RE.finditer(src):
            if m.group('name') in kinds:
                read_names.add(m.group('name'))
    flip = {root_of(n, aliases, kinds) for n in read_names}
    flip = {n for n in flip if kinds.get(n) == 'objc'}
    rewrite = {n for n in kinds if root_of(n, aliases, kinds) in flip or kinds[n] == 'view'}
    return flip, rewrite


def flip_definitions(src, path, flip):
    header = path.endswith('.h')
    storage = 'inline' if header else 'static'
    out, changed = [], False
    for line in src.splitlines(keepends=True):
        body = line.rstrip('\r\n')
        eol = line[len(body):]
        m = DEFINE_RE.match(body) or CONST_RE.match(body)
        if m and m.group('name') in flip:
            value = m.group('s1') or m.groupdict().get('s2')
            ws = m.group('ws') if m.group('ws') not in ('', ' ') else ' '
            body = '%s%s constexpr std::string_view %s%s= %s;%s' % (
                m.group('lead'), storage, m.group('name'), ws, value, m.group('trail'))
            changed = True
        out.append(body + eol)
    src = ''.join(out)
    if changed and not re.search(r'^[ \t]*#[ \t]*include[ \t]*<string_view>', src, re.M):
        src = add_include(src)
    return src


def add_include(src):
    lines = src.splitlines(keepends=True)
    eol = '\r\n' if lines and lines[0].endswith('\r\n') else '\n'
    first_def = next((i for i, l in enumerate(lines)
                      if re.match(r'^[ \t]*(?:inline|static)[ \t]+constexpr[ \t]+std::string_view', l)), len(lines))
    last_inc = None
    for i, l in enumerate(lines[:first_def]):
        if INCLUDE_RE.match(l):
            last_inc = i
    if last_inc is not None:
        lines.insert(last_inc + 1, '#include <string_view>' + eol)
    else:
        lines.insert(first_def, '#include <string_view>' + eol + eol)
    return ''.join(lines)


def rewrite_uses(src, rewrite):
    return STDSTRING_RE.sub(lambda m: 'std::string(%s)' % m.group('name') if m.group('name') in rewrite else m.group(0), src)


def fix_tree(sources):
    flip, rewrite = targets(sources)
    out = {}
    for path, src in sources.items():
        new = rewrite_uses(flip_definitions(src, path, flip), rewrite)
        if new != src:
            out[path] = new
    return out


def check_tree(sources):
    kinds, _ = definitions(sources)
    found = []
    for path, src in sources.items():
        for n, line in enumerate(src.splitlines(), 1):
            for m in STDSTRING_RE.finditer(line):
                if m.group('name') in kinds:
                    found.append((path, n, 'stdstring', line.strip()))
    return found


def load(root):
    return {p: read(p) for p in walk(root)}


def main(argv):
    if argv[1:] == ['--selftest']:
        return selftest()
    if len(argv) != 3 or argv[1] not in ('--check', '--fix'):
        print(__doc__)
        return 2
    sources = load(argv[2])
    if argv[1] == '--fix':
        for path, new in sorted(fix_tree(sources).items()):
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(new)
            print('fixed %s' % path)
        return 0
    found = check_tree(sources)
    for path, line, kind, text in found:
        print('%s:%d: %s: %s' % (path, line, kind, text))
    print('%d oo::StdString use(s) of a key constant' % len(found))
    return 1 if found else 0


# ---------------------------------------------------------------------------------- selftest

HEADER = '''#import "OOCocoa.h"
#include "oofnd/StdLib.hpp"

#define KEY_NAME\t\t\t@"name"
#define kOOWidth\t(@"Width")\t// a comment
#define KEY_UNREAD\t\t@"unread"
#define KEY_ESC @"a \\"quoted\\" key"
#define KEY_ALIAS\tKEY_NAME
#define NOT_A_KEY 12
'''

HEADER_FIXED = '''#import "OOCocoa.h"
#include "oofnd/StdLib.hpp"
#include <string_view>

inline constexpr std::string_view KEY_NAME\t\t\t= "name";
inline constexpr std::string_view kOOWidth\t= "Width";\t// a comment
#define KEY_UNREAD\t\t@"unread"
inline constexpr std::string_view KEY_ESC = "a \\"quoted\\" key";
#define KEY_ALIAS\tKEY_NAME
#define NOT_A_KEY 12
'''

SOURCE = '''#import "Header.h"

static NSString * const kBoulderRole = @"boulder";
#define LOCAL_KEY @"local"

void f(const oo::PList &d)
{
	d.get<int>(oo::StdString(KEY_NAME));
	d.get<int>(oo::StdString( kOOWidth ));
	d.get<int>(oo::StdString(KEY_ALIAS));
	d.get<int>(oo::StdString(KEY_ESC));
	d.get<int>(oo::StdString(kBoulderRole));
	d.get<int>(oo::StdString(LOCAL_KEY));
	d.get<int>(oo::StdString(kOOManifestTitle));
	d.get<int>(oo::StdString(someVariable));
	[d objectForKey:KEY_UNREAD];
#if OOLITE_MAC_OS_X
	d.get<int>(oo::StdString(KEY_NAME));
#endif
}
'''

SOURCE_FIXED = '''#import "Header.h"
#include <string_view>

static constexpr std::string_view kBoulderRole = "boulder";
static constexpr std::string_view LOCAL_KEY = "local";

void f(const oo::PList &d)
{
	d.get<int>(std::string(KEY_NAME));
	d.get<int>(std::string(kOOWidth));
	d.get<int>(std::string(KEY_ALIAS));
	d.get<int>(std::string(KEY_ESC));
	d.get<int>(std::string(kBoulderRole));
	d.get<int>(std::string(LOCAL_KEY));
	d.get<int>(std::string(kOOManifestTitle));
	d.get<int>(oo::StdString(someVariable));
	[d objectForKey:KEY_UNREAD];
#if OOLITE_MAC_OS_X
	d.get<int>(std::string(KEY_NAME));
#endif
}
'''

MANIFEST = '''#include <string_view>

inline constexpr std::string_view kOOManifestTitle\t= "title";
'''

NO_INCLUDES = '''/* no includes */
#define KEY_ONLY @"only"
'''

NO_INCLUDES_FIXED = '''/* no includes */
#include <string_view>

inline constexpr std::string_view KEY_ONLY = "only";
'''


def selftest():
    failures = 0

    def expect(name, got, want):
        nonlocal failures
        if got != want:
            failures += 1
            print('FAIL %s\n--- got\n%s--- want\n%s' % (name, got, want))
        else:
            print('ok   %s' % name)

    tree = {'a/Header.h': HEADER, 'a/Source.mm': SOURCE, 'a/Manifest.h': MANIFEST}
    before = check_tree(tree)
    expect('check finds every StdString read of a key constant', sorted(l for _, l, _, _ in before),
           [8, 9, 10, 11, 12, 13, 14, 18])
    fixed = fix_tree(tree)
    expect('header: #define and (@"...") forms, trailing comment, alignment, include', fixed.get('a/Header.h'), HEADER_FIXED)
    expect('source: static forms, aliases, Mac fence, strangers untouched', fixed.get('a/Source.mm'), SOURCE_FIXED)
    expect('an already-flipped header is untouched', 'a/Manifest.h' in fixed, False)
    after = dict(tree, **fixed)
    expect('check is clean after --fix', check_tree(after), [])
    expect('--fix is idempotent', fix_tree(after), {})
    expect('the include goes before the first constant when there is no #include',
           fix_tree({'b/Only.h': NO_INCLUDES, 'b/Use.mm': 'x(oo::StdString(KEY_ONLY));\n'}).get('b/Only.h'), NO_INCLUDES_FIXED)
    expect('an unread constant is not flipped', fix_tree({'c/U.h': '#define KEY_U @"u"\n'}), {})
    crlf = fix_tree({'d/C.h': '#import "x.h"\r\n#define KEY_C @"c"\r\n', 'd/C.mm': 'oo::StdString(KEY_C)\r\n'})
    expect('CRLF files keep CRLF', crlf.get('d/C.h'),
           '#import "x.h"\r\n#include <string_view>\r\ninline constexpr std::string_view KEY_C = "c";\r\n')

    print('key-constants selftest: %s' % ('FAIL (%d)' % failures if failures else 'PASS'))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
