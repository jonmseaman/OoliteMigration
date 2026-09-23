#!/usr/bin/env python3
"""Selector families for the Foundation sweep (proposed ADR-0043, bead oo-g7k5).

WHY THIS EXISTS

Objective-C dispatches by selector NAME. When two classes declare the same selector with
different types, a message compiled against one declaration and delivered to the other class is
called with the wrong calling convention: an NSString * where a std::string is expected, a
pointer where an sret buffer is. Clang warns (-Wobjc-multiple-method-names) only when a
translation unit sees both declarations AND the receiver is `id`; otherwise it silently picks the
one it sees. Before the sweep every selector's types were Objective-C objects and scalars, so a
mismatch was harmless (an id is an id); a sweep bead that gives one class's selector a C++ type
makes it a crash. Hence the recipe's rule (src/oofnd/README.md, "Migrating Foundation usage"):

    a selector declared by more than one class or protocol (a FAMILY) keeps an Objective-C object
    type (`id`) in the sweep bead; the whole family changes to C++ types together, in one bead.

USAGE

    python3 tools/check-selector-types.py FILE...     # which of FILE's selectors are shared
    python3 tools/check-selector-types.py --check     # tree-wide: fail on a family with C++ types
                                                      # that its members do not all agree on

The first form is the recipe's step: for every method in the bead's header it prints `unique`
(change its types; adapt the direct callers) or `shared` with the other declarers (keep `id`).
Declarations are attributed to the @interface / @implementation / @protocol they sit in, so a
class's header, its .mm and its category files count as ONE declarer. Foundation's own headers
(gnustep-base, under $MINGW_PREFIX/include/Foundation) are declarers too: `-name`, `-count`,
`-intersectsSet:` ... exist there, and an `id` receiver can be either.

--check is the guard: it exits 1 if any selector has a C++ type (std::, oo::, a reference) in a
slot where another declaration of the same selector has a different type, and prints each such
family. It exits 0 on today's tree. Pure text analysis, no compiler; < 5 s.
"""

import argparse
import collections
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO_ROOT, "upstream", "oolite", "src")

COMMENT = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)
STRING = re.compile(r'@?"(?:\\.|[^"\\\n])*"')
# GNUstep spells a generic class @interface GS_GENERIC_CLASS(NSSet, ElementT)
CONTAINER = re.compile(r"^\s*@(interface|implementation|protocol)\s+(?:GS_GENERIC_CLASS\(\s*)?(\w+)", re.M)
CONTAINER_END = re.compile(r"^\s*@end\b", re.M)
METHOD = re.compile(r"^[ \t]*([-+])[ \t]*\(", re.M)
# name:(type)arg, where type may nest one level of parentheses (blocks, function pointers)
PART = re.compile(r"(\w*)\s*:\s*\(((?:[^()]|\([^()]*\))*)\)\s*\w+")


def strip(text):
    text = COMMENT.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)
    return STRING.sub('""', text)


def norm(t):
    return " ".join(t.replace("*", " * ").replace("&", " & ").split())


def balanced_paren(text, start):
    """Index just past the ')' matching the '(' at text[start]."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i + 1
    return -1


def declarations(path):
    """Yield (kind, selector, return type, param types, container, line) for each method."""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = strip(f.read())
    except OSError:
        return
    marks = sorted([(m.start(), m.group(2)) for m in CONTAINER.finditer(text)] +
                   [(m.start(), None) for m in CONTAINER_END.finditer(text)])
    for m in METHOD.finditer(text):
        container = None
        for pos, name in marks:
            if pos > m.start():
                break
            container = name
        if container is None:
            continue
        open_paren = m.end() - 1
        close = balanced_paren(text, open_paren)
        if close < 0:
            continue
        ret = norm(text[open_paren + 1:close - 1])
        end = len(text)
        for stop in (";", "{"):
            k = text.find(stop, close)
            if 0 <= k < end:
                end = k
        rest = text[close:end]
        parts = PART.findall(rest)
        if parts:
            selector = "".join(name + ":" for name, _ in parts)
            params = tuple(norm(t) for _, t in parts)
        else:
            name = re.match(r"\s*(\w+)", rest)
            if not name:
                continue
            selector, params = name.group(1), ()
        line = text.count("\n", 0, m.start()) + 1
        yield m.group(1), selector, ret, params, container, line


def scan(roots):
    table = collections.defaultdict(list)   # (kind, selector) -> [(ret, params, container, where)]
    for root in roots:
        for dirpath, _dirs, files in os.walk(root):
            for name in files:
                if not name.endswith((".h", ".m", ".mm")):
                    continue
                path = os.path.join(dirpath, name)
                for kind, sel, ret, params, container, line in declarations(path):
                    where = f"{os.path.relpath(path, REPO_ROOT)}:{line}"
                    table[(kind, sel)].append((ret, params, container, where))
    return table


def foundation_root():
    prefix = os.environ.get("MINGW_PREFIX")
    for base in ([prefix] if prefix else []) + ["/ucrt64"]:
        path = os.path.join(base, "include", "Foundation")
        if os.path.isdir(path):
            return path
    return None


def is_cxx(t):
    return "std::" in t or "oo::" in t or "&" in t


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("files", nargs="*", help="files whose selectors to classify")
    ap.add_argument("--check", action="store_true", help="tree-wide C++-type collision check")
    ap.add_argument("--no-foundation", action="store_true", help="ignore gnustep-base's headers")
    args = ap.parse_args()
    if not args.files and not args.check:
        ap.error("give FILE... or --check")

    roots = [SRC]
    fnd = None if args.no_foundation else foundation_root()
    if fnd:
        roots.append(fnd)
    table = scan(roots)

    status = 0
    if args.check:
        bad = 0
        for (kind, sel), decls in sorted(table.items()):
            slots = [(ret,) + params for ret, params, _c, _w in decls]
            width = max(len(s) for s in slots)
            for i in range(width):
                types = {s[i] for s in slots if i < len(s)}
                if len(types) > 1 and any(is_cxx(t) for t in types):
                    bad += 1
                    print(f"COLLISION {kind}{sel} slot {i} ({'return' if i == 0 else 'param ' + str(i)}):")
                    for ret, params, c, w in decls:
                        print(f"    {c:<32} ({ret}) {params}  {w}")
                    break
        print(f"check-selector-types: {bad} selector famil{'y' if bad == 1 else 'ies'} with disagreeing C++ types")
        status = 1 if bad else 0

    for f in args.files:
        path = os.path.abspath(f)
        own = {(k, s): c for k, s, _r, _p, c, _l in declarations(path)}
        for (kind, sel), container in sorted(own.items(), key=lambda x: x[0][1]):
            others = sorted({c for _r, _p, c, _w in table.get((kind, sel), []) if c != container})
            if others:
                shown = ", ".join(others[:8]) + (f", ... ({len(others)})" if len(others) > 8 else "")
                print(f"shared  {kind}{sel:<48} also: {shown}")
            else:
                print(f"unique  {kind}{sel}")
    return status


if __name__ == "__main__":
    sys.exit(main())
