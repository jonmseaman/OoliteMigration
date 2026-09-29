#!/usr/bin/env python3
"""@"..." census and mechanical rewrite before the constant-string flip (bead oo-qps.10).

WHY THIS EXISTS

ADR-0029 keeps @"..." literals in source. After the flip (oo-3rb.4: -fno-constant-cfstrings
-fconstant-string-class=OOConstantString) every literal is an OOConstantString, which answers
only the floor's selectors: the instance methods declared by oofnd/objc/OOObject.h and
oofnd/objc/OOConstantString.h (-UTF8String, -length, -isEqual:, -isEqualToString:, -hash,
retain/release/autorelease, -class ...). Anything else it receives is -doesNotRecognizeSelector:,
a run-time abort, not a compile error. So every literal left outside src/oofnd is classified by
its syntactic context:

  (a) receiver   [@"..." selector...]. Fine if the selector is in the floor; otherwise --check
                 fails (rewrite that site by hand onto std::string).
  (b) C++ string the literal only feeds a C++ string: an argument of oo::StdString,
                 oo::DescriptionOf, oo::OptionalString, std::string, std::string_view, OO_LOG
                 or an oo::str:: function. It was only ever converted back to UTF-8, so --fix
                 rewrites it to plain "..." (the three bridge calls become std::string /
                 std::optional<std::string>). --check fails on any left.
  (c) id slot    everything else: a message argument, a macro body, an assignment, a return,
                 an initializer. These stay (ADR-0029); the census lists them by context.

Only the literal's own syntax is read: a literal that reaches an NSString method through a
variable, a macro or a callee is (c) here. Comments are not code: a literal in a comment is not
counted. A text such as "status-@" (an @ before the closing quote) is not a literal.

USAGE

    python3 tools/codemods/at-literals.py [--list] DIR|FILE...   # census (default), per class
    python3 tools/codemods/at-literals.py --fix DIR|FILE...      # rewrite every simple (b)
    python3 tools/codemods/at-literals.py --check DIR|FILE...    # exit 1 on a bad (a) or any (b)
    python3 tools/codemods/at-literals.py --selftest             # fixtures below

A directory is walked for .h .m .mm .c .cpp .hpp files; src/oofnd (the floor itself) is skipped.
"""

import os
import re
import sys

EXTENSIONS = ('.h', '.m', '.mm', '.c', '.cpp', '.hpp')
SKIP_DIR = os.path.join('src', 'oofnd')
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
FLOOR_HEADERS = [os.path.join(REPO, 'upstream', 'oolite', 'src', 'oofnd', 'objc', name)
                 for name in ('OOObject.h', 'OOConstantString.h')]

# (b) callees -> what the call becomes once its literal is plain "..." (None: callee unchanged).
CXX_CALLEES = {
    'oo::StdString': 'std::string',
    'oo::DescriptionOf': 'std::string',
    'oo::OptionalString': 'std::optional<std::string>',
    'std::string': None,
    'std::string_view': None,
    'OO_LOG': None,
}
KEYWORDS = {'if', 'while', 'for', 'switch', 'return', 'sizeof', 'case', 'do', 'else', 'catch',
            '@synchronized', 'decltype', 'alignof', 'noexcept', 'static_cast', 'const_cast',
            'reinterpret_cast', 'dynamic_cast'}


# ------------------------------------------------------------------------------------------ lexer

class Tok:
    __slots__ = ('kind', 'text', 'start', 'end', 'directive', 'ats')

    def __init__(self, kind, text, start, end, directive, ats=()):
        self.kind, self.text, self.start, self.end = kind, text, start, end
        self.directive, self.ats = directive, ats

    def __repr__(self):
        return '%s(%r)' % (self.kind, self.text)


def _skip_quoted(src, i, quote):
    """i is at the opening quote; return the index after the closing one."""
    n = len(src)
    i += 1
    while i < n:
        c = src[i]
        if c == '\\':
            i += 2
            continue
        if c == quote or c == '\n':
            return i + 1
        i += 1
    return n


def tokenize(src):
    """Tokens of a C/C++/Objective-C source, comments dropped. Adjacent string pieces are one
    token: kind 'at' when any piece is @"...", with .ats the offsets of each '@'."""
    toks = []
    n = len(src)
    i = 0
    line_start = True
    directive = None
    while i < n:
        c = src[i]
        if c == '\n':
            line_start = True
            if not (i > 0 and src[i - 1] == '\\'):
                directive = None
            i += 1
            continue
        if c in ' \t\r\f\v\\':
            i += 1
            continue
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c == '#' and line_start:
            m = re.compile(r'#\s*(\w*)').match(src, i)
            directive = m.group(1)
            line_start = False
            if directive in ('error', 'warning', 'include', 'import'):
                j = src.find('\n', i)
                i = n if j < 0 else j
                continue
            i = m.end()
            continue
        line_start = False
        m = re.compile(r'(?:u8|u|U|L)?R"([^(\s]*)\(').match(src, i)
        if m and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_')):
            j = src.find(')' + m.group(1) + '"', m.end())
            end = n if j < 0 else j + len(m.group(1)) + 2
            toks.append(Tok('str', src[i:end], i, end, directive))
            i = end
            continue
        if c == '"' or (c == '@' and i + 1 < n and src[i + 1] == '"'):
            start, ats = i, []
            while True:
                if src[i] == '@':
                    ats.append(i)
                    i += 1
                i = _skip_quoted(src, i, '"')
                m = re.compile(r'(?:\s|//[^\n]*|/\*.*?\*/)*(@?")', re.S).match(src, i)
                if not m:
                    break
                i = m.start(1)
            toks.append(Tok('at' if ats else 'str', src[start:i], start, i, directive, tuple(ats)))
            continue
        if c == "'":
            if i > 0 and src[i - 1].isalnum() and i + 1 < n and src[i + 1].isalnum():
                i += 1		# digit separator
                continue
            end = _skip_quoted(src, i, "'")
            toks.append(Tok('chr', src[i:end], i, end, directive))
            i = end
            continue
        m = re.compile(r'@?[A-Za-z_]\w*').match(src, i)
        if m:
            toks.append(Tok('ident', m.group(0), i, m.end(), directive))
            i = m.end()
            continue
        m = re.compile(r'\d[\w.]*').match(src, i)
        if m:
            toks.append(Tok('num', m.group(0), i, m.end(), directive))
            i = m.end()
            continue
        two = src[i:i + 2]
        text = two if two in ('::', '->', '==', '!=', '<=', '>=', '&&', '||', '<<', '>>') else c
        toks.append(Tok('punct', text, i, i + len(text), directive))
        i += len(text)
    return toks


# ------------------------------------------------------------------------------- classification

OPEN = {'(': ')', '[': ']', '{': '}'}
CLOSE = {v: k for k, v in OPEN.items()}


def enclosing(toks, i):
    """Index of the innermost unmatched opener before toks[i], or -1."""
    depth = 0
    for k in range(i - 1, -1, -1):
        t = toks[k]
        if t.kind != 'punct':
            continue
        if t.text in CLOSE:
            depth += 1
        elif t.text in OPEN:
            if depth == 0:
                return k
            depth -= 1
        elif t.text == ';' and depth == 0:
            return -1
    return -1


def matching(toks, k):
    """Index of the closer matching the opener toks[k]."""
    want, depth = OPEN[toks[k].text], 0
    for j in range(k, len(toks)):
        t = toks[j]
        if t.kind == 'punct' and t.text in OPEN:
            depth += 1
        elif t.kind == 'punct' and t.text in CLOSE:
            depth -= 1
            if depth == 0:
                return j
    return len(toks) - 1


def callee(toks, k):
    """The (qualified) name called by the '(' at toks[k], or '' for a grouping parenthesis."""
    j = k - 1
    if j >= 0 and toks[j].text == '>':			# f<T>(...)
        depth = 0
        while j >= 0:
            if toks[j].text == '>':
                depth += 1
            elif toks[j].text == '<':
                depth -= 1
                if depth == 0:
                    break
            j -= 1
        j -= 1
    parts = []
    while j >= 0 and toks[j].kind == 'ident':
        parts.insert(0, toks[j].text)
        if j >= 1 and toks[j - 1].text == '::':
            parts.insert(0, '::')
            j -= 2
        else:
            break
    name = ''.join(parts)
    return '' if name in KEYWORDS else name


def message_selector(toks, i):
    """Selector sent to the receiver toks[i] (toks[i - 1] is '[')."""
    close = matching(toks, i - 1)
    parts, depth, j = [], 0, i + 1
    while j < close:
        t = toks[j]
        if t.kind == 'punct' and t.text in OPEN:
            depth += 1
        elif t.kind == 'punct' and t.text in CLOSE:
            depth -= 1
        elif depth == 0 and t.kind == 'ident' and j + 1 < close and toks[j + 1].text == ':' \
                and toks[j - 1].text != '?':
            parts.append(t.text + ':')
        j += 1
    return ''.join(parts) if parts else toks[i + 1].text


def classify(toks, i):
    """(cls, detail, call) for the literal toks[i]; call is the (b) call's '(' index."""
    prev = toks[i - 1] if i > 0 else None
    nxt = toks[i + 1] if i + 1 < len(toks) else None
    if prev is not None and prev.text == '[' and nxt is not None and nxt.kind == 'ident':
        return 'a', message_selector(toks, i), None
    k = enclosing(toks, i)
    while k >= 0 and toks[k].text == '(':
        name = callee(toks, k)
        if name and toks[k].directive == 'define' and toks[k].start > toks[k - 1].end:
            name = ''		# #define NAME (@"...") : NAME is not called
        if name in CXX_CALLEES or name.startswith('oo::str::'):
            return 'b', name, k
        if name:
            return 'c', 'argument of %s()' % name, None
        k = enclosing(toks, k)
    if toks[i].directive == 'define':
        return 'c', 'macro body', None
    if k >= 0 and toks[k].text == '[':
        if prev is not None and prev.text == ':' and i >= 2 and toks[i - 2].kind == 'ident':
            return 'c', 'message argument %s:' % toks[i - 2].text, None
        return 'c', 'message argument', None
    if prev is not None and prev.text in ('=', 'return', '?', ':'):
        return 'c', {'=': 'assignment', 'return': 'return'}.get(prev.text, 'conditional'), None
    if k >= 0 and toks[k].text == '{' and prev is not None and prev.text in ',{':
        return 'c', 'initializer', None
    return 'c', 'other', None


# ------------------------------------------------------------------------------------ rewriting

def _strip_parens(toks, lo, hi):
    """[lo, hi) with balanced outer grouping parentheses removed."""
    while hi - lo >= 2 and toks[lo].text == '(' and matching(toks, lo) == hi - 1:
        lo, hi = lo + 1, hi - 1
    return lo, hi


def _single_literal(toks, lo, hi):
    lo, hi = _strip_parens(toks, lo, hi)
    return hi - lo == 1 and toks[lo].kind == 'at'


def argument_span(toks, call, i):
    """[lo, hi) of the comma-separated argument of the call at toks[call] that holds toks[i]."""
    close = matching(toks, call)
    lo, depth = call + 1, 0
    for j in range(call + 1, close):
        t = toks[j]
        if t.kind == 'punct' and t.text in OPEN:
            depth += 1
        elif t.kind == 'punct' and t.text in CLOSE:
            depth -= 1
        elif depth == 0 and t.text == ',':
            if j > i:
                return lo, j
            lo = j + 1
    return lo, close


def simple_argument(toks, lo, hi):
    """True when [lo, hi) is one literal, or `cond ? literal : literal`."""
    lo, hi = _strip_parens(toks, lo, hi)
    if _single_literal(toks, lo, hi):
        return True
    depth, q = 0, None
    for j in range(lo, hi):
        t = toks[j]
        if t.kind == 'punct' and t.text in OPEN:
            depth += 1
        elif t.kind == 'punct' and t.text in CLOSE:
            depth -= 1
        elif depth == 0 and t.text == '?':
            q = j
            break
    if q is None:
        return False
    colon = [j for j in range(q + 1, hi) if toks[j].text == ':' and toks[j].kind == 'punct']
    return len(colon) == 1 and _single_literal(toks, q + 1, colon[0]) \
        and _single_literal(toks, colon[0] + 1, hi)


def plan_fixes(src, toks):
    """[(start, end, replacement)] for every simple (b), and the (b) literals left unfixed."""
    edits, manual, seen = [], [], set()
    for i, t in enumerate(toks):
        if t.kind != 'at':
            continue
        cls, name, call = classify(toks, i)
        if cls != 'b':
            continue
        lo, hi = argument_span(toks, call, i)
        if not simple_argument(toks, lo, hi):
            manual.append(i)
            continue
        if (call, lo) in seen:
            continue
        seen.add((call, lo))
        for j in range(lo, hi):
            for at in toks[j].ats:
                edits.append((at, at + 1, ''))
        if CXX_CALLEES.get(name):
            first = call - 1
            while first >= 1 and toks[first - 1].text == '::':
                first -= 2
            edits.append((toks[first].start, toks[call - 1].end, CXX_CALLEES[name]))
    return edits, manual


def apply_edits(src, edits):
    for start, end, text in sorted(edits, reverse=True):
        src = src[:start] + text + src[end:]
    return src


# ----------------------------------------------------------------------------------------- tree

def floor_selectors(paths=FLOOR_HEADERS):
    sels = set()
    for path in paths:
        with open(path, encoding='utf-8') as f:
            for line in f:
                m = re.match(r'\s*-\s*\(([^)]*)\)\s*(.*?);', line)
                if not m:
                    continue
                body = re.sub(r'\([^)]*\)', ' ', m.group(2))
                keys = re.findall(r'(\w+)\s*:', body)
                sels.add(''.join(k + ':' for k in keys) if keys else body.split()[0])
    return sels


def source_files(paths):
    for path in paths:
        if os.path.isfile(path):
            yield path
            continue
        for root, dirs, files in os.walk(path):
            dirs[:] = sorted(d for d in dirs
                             if not os.path.join(root, d).replace('\\', '/').endswith('src/oofnd'))
            for name in sorted(files):
                if name.endswith(EXTENSIONS):
                    yield os.path.join(root, name)


def read(path):
    with open(path, encoding='utf-8', errors='surrogateescape', newline='') as f:
        return f.read()


def line_of(src, pos):
    return src.count('\n', 0, pos) + 1


def main(argv):
    mode = 'census'
    listing = False
    paths = []
    for arg in argv:
        if arg in ('--fix', '--check', '--selftest'):
            mode = arg[2:]
        elif arg == '--list':
            listing = True
        elif arg.startswith('-'):
            print(__doc__)
            return 2
        else:
            paths.append(arg)
    if mode == 'selftest':
        return selftest()
    if not paths:
        print('at-literals: no DIR or FILE given', file=sys.stderr)
        return 2
    floor = floor_selectors()
    counts, per_dir, failures, rewritten = {'a': 0, 'b': 0, 'c': 0}, {}, [], 0
    for path in source_files(paths):
        src = read(path)
        if '@"' not in src:
            continue
        toks = tokenize(src)
        if mode == 'fix':
            edits, _ = plan_fixes(src, toks)
            if edits:
                src = apply_edits(src, edits)
                with open(path, 'w', encoding='utf-8', errors='surrogateescape', newline='') as f:
                    f.write(src)
                rewritten += 1
                toks = tokenize(src)
        for i, t in enumerate(toks):
            if t.kind != 'at':
                continue
            cls, detail, _ = classify(toks, i)
            where = '%s:%d' % (path.replace('\\', '/'), line_of(src, t.start))
            counts[cls] += 1
            d = os.path.dirname(path).replace('\\', '/')
            per_dir.setdefault(d, {'a': 0, 'b': 0, 'c': 0})[cls] += 1
            bad = (cls == 'a' and detail not in floor) or cls == 'b'
            if bad:
                failures.append('%s: (%s) %s %s' % (where, cls, detail, t.text[:60]))
            if listing:
                print('%s: (%s) %s %s' % (where, cls, detail, t.text[:60]))
    if mode == 'census' or listing:
        for d in sorted(per_dir):
            c = per_dir[d]
            print('  %-60s a=%d b=%d c=%d' % (d, c['a'], c['b'], c['c']))
    print('at-literals: %d literal(s): (a) receiver %d, (b) C++ string %d, (c) id slot %d'
          % (sum(counts.values()), counts['a'], counts['b'], counts['c']))
    if mode == 'fix':
        print('at-literals: rewrote %d file(s)' % rewritten)
    if failures and mode in ('check', 'fix'):
        for line in failures:
            print('  ' + line)
        print('at-literals: %d literal(s) the constant-string floor cannot take: a receiver of '
              'a selector OOConstantString lacks, or a C++-string literal --fix did not rewrite'
              % len(failures))
        return 1 if mode == 'check' else 0
    return 0


# ------------------------------------------------------------------------------------- selftest

FIXTURES = [
    # (source, [(class, detail) per literal], source after --fix)
    ('x = oo::StdString(@"abc");',
     [('b', 'oo::StdString')], 'x = std::string("abc");'),
    ('OO_LOG("c", "{}", oo::DescriptionOf((full ? @"fullscreen" : @"windowed")));',
     [('b', 'oo::DescriptionOf'), ('b', 'oo::DescriptionOf')],
     'OO_LOG("c", "{}", std::string((full ? "fullscreen" : "windowed")));'),
    ('[g k:oo::OptionalString([s st] == D ? @"a" : @"b")];',
     [('b', 'oo::OptionalString'), ('b', 'oo::OptionalString')],
     '[g k:std::optional<std::string>([s st] == D ? "a" : "b")];'),
    ('OO_LOG("c", "{} {}", n, @"lit" @"eral");',
     [('b', 'OO_LOG')], 'OO_LOG("c", "{} {}", n, "lit" "eral");'),
    ('y = oo::str::join(v, @", ");', [('b', 'oo::str::join')], 'y = oo::str::join(v, ", ");'),
    ('z = oo::StdString([@"p" stringByAppendingString:s]);',
     [('a', 'stringByAppendingString:')], None),
    ('n = [@"abc" length];', [('a', 'length')], None),
    ('b = [@"abc" isEqualToString:s];', [('a', 'isEqualToString:')], None),
    ('[ship setAITo:@"nullAI.plist"];', [('c', 'message argument setAITo:')], None),
    ('#define KEY_NAME @"name"\nint q;', [('c', 'macro body')], None),
    ('#define kWidth (@"Width")\nint q;', [('c', 'macro body')], None),
    ('if (x) { y = @"a"; }', [('c', 'assignment')], None),
    ('OOColor *c[2] = { @"a", @"b" };', [('c', 'initializer'), ('c', 'initializer')], None),
    ('return @"YES";', [('c', 'return')], None),
    ('s = OO_DESC("status-commander-@");', [], None),
    ('// [x foo:@"comment"]\n/* @"block" */ c = \'"\';', [], None),
    ('t = cond ? @"a" : @"b";', [('c', 'conditional'), ('c', 'conditional')], None),
    ('get<float>(@"hue");', [('c', 'argument of get()')], None),
    ('oo::StdString(f(@"x"));', [('c', 'argument of f()')], None),
    ('oo::StdString(x ? @"a" : y);', [('b', 'oo::StdString')], None),
]


def selftest():
    floor = floor_selectors()
    failed = 0
    for want in ('UTF8String', 'length', 'isEqual:', 'isEqualToString:', 'hash', 'retain'):
        if want not in floor:
            print('selftest: floor selector %s not parsed from the oofnd headers' % want)
            failed += 1
    for bad in ('stringByAppendingString:', 'description', 'hasSuffix:'):
        if bad in floor:
            print('selftest: %s wrongly counted as a floor selector' % bad)
            failed += 1
    for src, want, fixed in FIXTURES:
        toks = tokenize(src)
        got = [classify(toks, i)[:2] for i, t in enumerate(toks) if t.kind == 'at']
        if got != want:
            print('selftest: %r\n  classified %r\n  expected   %r' % (src, got, want))
            failed += 1
        edits, manual = plan_fixes(src, toks)
        out = apply_edits(src, edits)
        if fixed is not None and out != fixed:
            print('selftest: %r\n  fixed to %r\n  expected %r' % (src, out, fixed))
            failed += 1
        if fixed is None and any(c == 'b' for c, _ in want) and not manual:
            print('selftest: %r should be left for a hand rewrite' % src)
            failed += 1
        if fixed is None and not any(c == 'b' for c, _ in want) and out != src:
            print('selftest: %r must not be rewritten, got %r' % (src, out))
            failed += 1
    print('at-literals selftest: %d fixture(s), %s' % (len(FIXTURES),
                                                      'FAIL (%d)' % failed if failed else 'ok'))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
