#!/usr/bin/env python3
"""Flip the legacy -description family onto OODescription.h's C++ family (ADR-0055 item 1).

WHY THIS EXISTS

The legacy family (-descriptionComponents, -shortDescriptionComponents, -description,
-shortDescription) returns a Foundation string as `id`. Its C++ replacement on the OOObject root
(Core/OODescription.h, bead oo-qps.31) is -cxx_descriptionComponents & co., returning
std::optional<std::string>. The family cannot be flipped file by file: a converted superclass
hides an unconverted subclass's override. So bead oo-qps.43 runs --fix over the whole tree in one
commit, fixes the residue --check reports by hand, and deletes the legacy root family in
Core/OOCocoa.h/.mm. oo-qps.31 applied it to one exemplar, Core/OORoleSet.mm.

WHAT --fix REWRITES (outside Mac fences, comments and strings)

  - (id) descriptionComponents { ... }      - (std::optional<std::string>) cxx_descriptionComponents
  (and the short / plain forms, definitions and header declarations; the trailing
  "shared selector (proposed ADR-0043)" comment goes: the C++ selector is not shared)
      inside a flipped body:
      return oo::NSStringFrom(e);           return e;
      return oo::NSStringOrNil(e);          return e;
      return nil;                           return std::nullopt;
      return [x descriptionComponents];     return [x cxx_descriptionComponents];  (forwarding)
  [super descriptionComponents] (& co.)     [super cxx_descriptionComponents]; [self ...] likewise
  oo::DescriptionOf([super cxx_X])          [super cxx_X].value_or("(null)")  ("%@" of nil)
  oo::DescriptionOf([x description])        oo::DescriptionOf(x)       (and short: oo::ShortDescriptionOf(x))

Anything else in a flipped body that still produces an `id` is a compile error the author fixes by
hand; --check lists what is left.

WHAT --check REPORTS (exit 1 if anything)

  override  a legacy definition or declaration still typed id (in a class, or the root's own
            in Core/OOCocoa.h/.mm, reported as 'root')
  send      a direct -description / -shortDescription / ...Components message: after the flip
            the root no longer answers it (use oo::DescriptionOf / oo::ShortDescriptionOf, or
            the cxx_ form on an OOObject)

Core/OODescription.h/.mm (the family itself, whose transitional forwarding oo-qps.72 deletes) and
Core/OOObjectGNUstepBridge.* (+description of a class, deleted by oo-qps.16) are skipped, as is
Mac-fenced code (#if OOLITE_MAC_OS_X ... : Phase 5, ADR-0055 item 7).

USAGE

    python3 tools/codemods/description-family.py --check DIR|FILE...
    python3 tools/codemods/description-family.py --fix DIR|FILE...
    python3 tools/codemods/description-family.py --selftest
"""

import os
import re
import sys

EXTENSIONS = ('.h', '.m', '.mm')
SKIP_FILES = ('OODescription.h', 'OODescription.mm', 'OOObjectGNUstepBridge.h', 'OOObjectGNUstepBridge.mm')
ROOT_FILES = ('OOCocoa.h', 'OOCocoa.mm')
FAMILY = ('shortDescriptionComponents', 'descriptionComponents', 'shortDescription', 'description')
FAMILY_RE = '|'.join(FAMILY)
CXX_TYPE = '(std::optional<std::string>)'

SIGNATURE = re.compile(r'^-[ \t]*\([ \t]*id[ \t]*\)[ \t]*(' + FAMILY_RE + r')\b[ \t]*(;?)([^\n]*)$', re.M)
SHARED_COMMENT = re.compile(r'^\s*//\s*shared selector\b.*$')
SELF_SEND = re.compile(r'\[(super|self)[ \t]+(' + FAMILY_RE + r')\]')
SEND = re.compile(r'[\w\])][ \t]+(' + FAMILY_RE + r')\]')
DESCRIBED_SUPER = re.compile(r'oo::DescriptionOf\(\[(super|self) (cxx_(?:' + FAMILY_RE + r'))\]\)')


# ---------------------------------------------------------------------------------- lexing

def mask(src):
    """<src> with every comment and string/char literal body blanked (newlines kept), so a regex
    over it finds only code at the same offsets."""
    out = list(src)
    n, i = len(src), 0

    def blank(start, end):
        for k in range(start, min(end, n)):
            if out[k] != '\n':
                out[k] = ' '

    while i < n:
        if src.startswith('//', i):
            j = src.find('\n', i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            blank(i, j)
            i = j
        elif src[i] in '"\'':
            j = i + 1
            while j < n and src[j] != src[i] and src[j] != '\n':
                j += 2 if src[j] == '\\' else 1
            blank(i + 1, j)		# the quotes themselves stay
            i = j + 1
        else:
            i += 1
    return ''.join(out)


def fenced_lines(src):
    """The set of 1-based line numbers inside a Mac-only preprocessor branch."""
    fenced, stack = set(), []	# stack of (mac_if_branch: bool|None, in_else: bool)
    for number, line in enumerate(src.split('\n'), 1):
        m = re.match(r'\s*#\s*(if|ifdef|ifndef|elif|else|endif)\b(.*)', line)
        if m:
            kind, cond = m.group(1), m.group(2).split('//')[0].strip()
            if kind in ('if', 'ifdef', 'ifndef'):
                mac = None
                if re.fullmatch(r'(defined\s*\(?\s*)?OOLITE_MAC_OS_X\s*\)?', cond):
                    mac = kind != 'ifndef'
                elif re.fullmatch(r'!\s*(defined\s*\(?\s*)?OOLITE_MAC_OS_X\s*\)?', cond):
                    mac = False
                stack.append([mac, False])
            elif kind in ('else', 'elif') and stack:
                stack[-1][1] = True
            elif kind == 'endif' and stack:
                stack.pop()
            continue
        if any(mac is not None and mac != in_else for mac, in_else in stack):
            fenced.add(number)
    return fenced


def line_of(src, offset):
    return src.count('\n', 0, offset) + 1


def matching_close(code, start, opener, closer):
    """Offset just past the <closer> that matches the <opener> at code[start]."""
    depth = 0
    for k in range(start, len(code)):
        if code[k] == opener:
            depth += 1
        elif code[k] == closer:
            depth -= 1
            if depth == 0:
                return k + 1
    return len(code)


# ---------------------------------------------------------------------------------- rewrite

def rewrite_body(body):
    """A flipped method's body ({...}) in the C++ family's terms."""
    code = mask(body)
    edits = []	# (start, end, replacement)
    for m in re.finditer(r'\breturn[ \t]+oo::(NSStringFrom|NSStringOrNil)\(', code):
        close = matching_close(code, m.end() - 1, '(', ')')
        if re.match(r'[ \t]*;', code[close:]):
            edits.append((m.start(), close, 'return ' + body[m.end():close - 1]))
    for m in re.finditer(r'\breturn[ \t]+nil[ \t]*;', code):
        edits.append((m.start(), m.end(), 'return std::nullopt;'))
    for m in re.finditer(r'\breturn[ \t]+\[', code):
        close = matching_close(code, m.end() - 1, '[', ']')
        send = re.search(r'[ \t](' + FAMILY_RE + r')\]$', code[m.start():close])
        if send and re.match(r'[ \t]*;', code[close:]):
            at = m.start() + send.start(1)
            edits.append((at, at, 'cxx_'))
    for start, end, text in sorted(edits, reverse=True):
        body = body[:start] + text + body[end:]
    return body


def fix_source(src, name=''):
    if os.path.basename(name) in SKIP_FILES + ROOT_FILES:
        return src
    fenced = fenced_lines(src)
    code = mask(src)
    edits = []
    for m in SIGNATURE.finditer(code):
        if line_of(src, m.start()) in fenced:
            continue
        selector, semicolon = m.group(1), m.group(2)
        trailing = src[m.start(3):m.end(3)]
        if SHARED_COMMENT.match(trailing):
            trailing = ''
        head = '- %s cxx_%s%s%s' % (CXX_TYPE, selector, semicolon, trailing)
        if semicolon:
            edits.append((m.start(), m.end(), head))
            continue
        brace = code.find('{', m.end())
        if brace < 0 or code[m.end():brace].strip():
            edits.append((m.start(), m.end(), head))
            continue
        end = matching_close(code, brace, '{', '}')
        edits.append((m.start(), m.end(), head))
        edits.append((brace, end, rewrite_body(src[brace:end])))
    for start, end, text in sorted(edits, reverse=True):
        src = src[:start] + text + src[end:]
    # "%@" of an object's -description / -shortDescription is oo::DescriptionOf / ShortDescriptionOf
    # of the object (both give "(null)" for nil), whatever the receiver's root.
    fenced, code = fenced_lines(src), mask(src)
    for m in reversed(list(re.finditer(r'\boo::DescriptionOf\(\[', code))):
        close = matching_close(code, m.end() - 1, '[', ']')
        send = re.search(r'[ \t](shortDescription|description)\]$', code[m.end():close])
        if send is None or code[close:close + 1] != ')' or line_of(src, m.start()) in fenced:
            continue
        receiver = src[m.end():m.end() + send.start()].strip()
        function = 'ShortDescriptionOf' if send.group(1) == 'shortDescription' else 'DescriptionOf'
        src = src[:m.start()] + 'oo::%s(%s)' % (function, receiver) + src[close + 1:]
    # [super X] / [self X] anywhere (outside fences), then "%@" of such a send.
    fenced, code = fenced_lines(src), mask(src)
    for m in reversed(list(SELF_SEND.finditer(code))):
        if line_of(src, m.start()) not in fenced:
            src = src[:m.start(2)] + 'cxx_' + src[m.start(2):]
    code = mask(src)
    for m in reversed(list(DESCRIBED_SUPER.finditer(code))):
        src = src[:m.start()] + '[%s %s].value_or("(null)")' % (m.group(1), m.group(2)) + src[m.end():]
    return src


# ---------------------------------------------------------------------------------- census

def check_source(src, name=''):
    """[(line, kind, text)] of legacy family uses left in <src>."""
    base = os.path.basename(name)
    if base in SKIP_FILES:
        return []
    fenced, code, found = fenced_lines(src), mask(src), []
    lines = src.split('\n')
    for m in SIGNATURE.finditer(code):
        line = line_of(src, m.start())
        if line not in fenced:
            found.append((line, 'root' if base in ROOT_FILES else 'override', lines[line - 1].strip()))
    for m in SEND.finditer(code):
        line = line_of(src, m.start())
        if line not in fenced:
            found.append((line, 'send', lines[line - 1].strip()))
    return sorted(set(found))


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


def read(path):
    with open(path, encoding='utf-8', newline='') as f:
        return f.read()


def main(argv):
    if argv[1:] == ['--selftest']:
        return selftest()
    if len(argv) < 3 or argv[1] not in ('--check', '--fix'):
        print(__doc__)
        return 2
    mode, total = argv[1], 0
    for path in walk(argv[2:]):
        src = read(path)
        if mode == '--fix':
            out = fix_source(src, path)
            if out != src:
                with open(path, 'w', encoding='utf-8', newline='') as f:
                    f.write(out)
                print('fixed %s' % path)
        else:
            for line, kind, text in check_source(src, path):
                print('%s:%d: %s: %s' % (path, line, kind, text))
                total += 1
    if mode == '--check':
        print('%d legacy description-family use(s)' % total)
        return 1 if total else 0
    return 0


# ---------------------------------------------------------------------------------- selftest

FIX_CASES = [
    # (name, before, after)
    ('components', '''- (id)descriptionComponents
{
	return oo::NSStringOrNil([self roleString]);
}
''', '''- (std::optional<std::string>) cxx_descriptionComponents
{
	return [self roleString];
}
'''),
    ('shared comment, format, super', '''- (id) descriptionComponents	// shared selector (proposed ADR-0043)
{
	return oo::NSStringFrom(oo::str::format("\\"%s\\" %s", n.c_str(), oo::DescriptionOf([super descriptionComponents]).c_str()));
}
''', '''- (std::optional<std::string>) cxx_descriptionComponents
{
	return oo::str::format("\\"%s\\" %s", n.c_str(), [super cxx_descriptionComponents].value_or("(null)").c_str());
}
'''),
    ('nil and forwarding', '''- (id) shortDescription
{
	if (x)  return nil;
	return [(id)_object shortDescription];
}
''', '''- (std::optional<std::string>) cxx_shortDescription
{
	if (x)  return std::nullopt;
	return [(id)_object cxx_shortDescription];
}
'''),
    ('declaration keeps other comments', '- (id) shortDescription;	// NPC flavour text\n',
     '- (std::optional<std::string>) cxx_shortDescription;	// NPC flavour text\n'),
    ('declaration drops shared comment', '- (id) description;	// shared selector (proposed ADR-0043)\n',
     '- (std::optional<std::string>) cxx_description;\n'),
    ('residue left for the author', '''- (id) description
{
	id x = [thing description];
	return oo::NSStringFrom(s) ;
}
''', '''- (std::optional<std::string>) cxx_description
{
	id x = [thing description];
	return s ;
}
'''),
    ('%@ of a send', 'OO_LOG("x", "{} {}", oo::DescriptionOf([[self owner] shortDescription]), oo::DescriptionOf([self description]));\n',
     'OO_LOG("x", "{} {}", oo::ShortDescriptionOf([self owner]), oo::DescriptionOf(self));\n'),
    ('%@ of components is not a description', 'oo::DescriptionOf([bgcolor descriptionComponents])\n',
     'oo::DescriptionOf([bgcolor descriptionComponents])\n'),
    ('Mac fence untouched','#if OOLITE_MAC_OS_X\n- (id) description;\n#endif\n',
     '#if OOLITE_MAC_OS_X\n- (id) description;\n#endif\n'),
    ('not Mac else branch', '#if OOLITE_MAC_OS_X\n#else\n- (id) description;\n#endif\n',
     '#if OOLITE_MAC_OS_X\n#else\n- (std::optional<std::string>) cxx_description;\n#endif\n'),
    ('comments and strings untouched', '// - (id) description\nx = "[super description]";\n',
     '// - (id) description\nx = "[super description]";\n'),
    ('other selectors untouched', '- (id) descriptionForKey:(id)k;\n- (NSString *) description2;\n',
     '- (id) descriptionForKey:(id)k;\n- (NSString *) description2;\n'),
]

CHECK_CASES = [
    # (name, file name, source, [(line, kind)])
    ('override and send', 'Foo.mm', '- (id) descriptionComponents\n{\n\treturn [x description];\n}\n',
     [(1, 'override'), (3, 'send')]),
    ('root', 'OOCocoa.mm', '- (id) description\n{\n}\n', [(1, 'root')]),
    ('skipped family file', 'OODescription.mm', '- (id) description;\n[x description];\n', []),
    ('fenced, commented, flipped', 'Foo.mm',
     '#ifdef OOLITE_MAC_OS_X\n[x description];\n#endif\n// [x description]\n[x cxx_description];\n'
     '- (std::optional<std::string>) cxx_description;\n', []),
    ('not a send', 'Foo.mm', 'NSString *description = nil;\n@selector(description)\n', []),
]


def selftest():
    failures = 0
    for name, before, after in FIX_CASES:
        got = fix_source(before, 'Foo.mm')
        if got != after:
            failures += 1
            print('selftest fix %r:\n--- got\n%s--- expected\n%s' % (name, got, after))
    for name, fname, src, want in CHECK_CASES:
        got = [(line, kind) for line, kind, _ in check_source(src, fname)]
        if got != want:
            failures += 1
            print('selftest check %r: got %r, expected %r' % (name, got, want))
    fixed = fix_source(FIX_CASES[0][1], 'Foo.mm')
    if check_source(fixed, 'Foo.mm'):
        failures += 1
        print('selftest: --check still reports a flipped exemplar')
    print('selftest: %d failure(s) in %d cases' % (failures, len(FIX_CASES) + len(CHECK_CASES) + 1))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
