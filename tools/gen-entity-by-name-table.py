#!/usr/bin/env python3
"""Generate the entities' by-name C++ table (bead oo-9ht.39.7.1, ADR-0056 amendment oo-9ht.39.7.1).

The root entity facade's five by-name categories (Entity (OOShipSelectorsCalledByName),
(OOPlayerSelectorsCalledByName), (OOStationSelectorsCalledByName), (OODockSelectorsCalledByName),
(OOVisualEffectSelectorsCalledByName) in upstream/oolite/src/Core/Entities/Entity+ObjCBridge.mm)
become one C++ table, upstream/oolite/src/Core/Entities/OOEntityCalledByNameTable.h: a row per
method, exactly the categories' names, each keeping its #if conditions, with

  - the applies-to flags: the name sets (IsShipSelectorCalledByName() and its siblings) that
    -[Entity respondsToSelector:] reads to answer the name for an entity's C++ part;
  - the encoding of the declared result type (@encode() of it, measured; kOOTypeEncoding<> since
    bead oo-dbz.3, OOTypeEncodings.h), which the dispatcher classifies as OOCallByName
    classifies the method's type encoding;
  - the argument kind (none, const std::string &, const oo::PList &);
  - an adaptor taking Entity *: the category method's body, verbatim, with the entity for
    _cxxEntity.get();
  - for a method with no argument, a typed adaptor that keeps its result by type (an integer, a
    floating-point number, a vector, a quaternion, an object, a property list), which callObjC()
    reads as it read the method's typed result (bead oo-9ht.39.7.2).

Since bead oo-9ht.39.7.3 deleted the categories, the header is the source: the script reads its
functions and rows (table_rows()) and renders them again, so --check fails unless every row names
its own function with the function's #if conditions, result and argument, no name is there twice,
no function is left without a row, and the flags are the six known ones.

    python3 tools/gen-entity-by-name-table.py           # rewrite the header
    python3 tools/gen-entity-by-name-table.py --check   # exit 1 if the header is stale
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "upstream/oolite/src"
FACADE = SRC / "Core/Entities/Entity+ObjCBridge.mm"
OUT = SRC / "Core/Entities/OOEntityCalledByNameTable.h"

CATEGORIES = [
    "OOShipSelectorsCalledByName",
    "OOPlayerSelectorsCalledByName",
    "OOStationSelectorsCalledByName",
    "OODockSelectorsCalledByName",
    "OOVisualEffectSelectorsCalledByName",
]
# name set function -> flag
SETS = {
    "IsShipSelectorCalledByName": "kOOByNameShip",
    "IsPlayerSelectorCalledByName": "kOOByNamePlayer",
    "IsProxySelectorCalledByName": "kOOByNameProxy",
    "IsStationSelectorCalledByName": "kOOByNameStation",
    "IsDockSelectorCalledByName": "kOOByNameDock",
    "IsEffectSelectorCalledByName": "kOOByNameEffect",
}
# -respondsToSelector: answers these before the name sets: a row must not hold one.
PLANET = {"airColorAsVector", "illuminationColorAsVector", "airColorMixRatio", "airDensity",
          "terminatorThresholdVector"}
BEACON = {"compareBeaconCodeWith:", "beaconCode", "setBeaconCode:", "beaconLabel", "setBeaconLabel:",
          "isBeacon", "beaconDrawable", "prevBeacon", "nextBeacon", "setPrevBeacon:", "setNextBeacon:",
          "isJammingScanning"}
ARG_KINDS = {"const std::string &": "String", "const oo::PList &": "PList"}
ARG_TYPES = {"String": "const std::string &", "PList": "const oo::PList &"}


def skip_literal(text, i):
    """Index past the string/char literal or comment at text[i], or i if none starts there."""
    c = text[i]
    if text.startswith("//", i):
        j = text.find("\n", i)
        return len(text) if j < 0 else j
    if text.startswith("/*", i):
        return text.index("*/", i + 2) + 2
    if c in "\"'":
        j = i + 1
        while text[j] != c:
            j += 2 if text[j] == "\\" else 1
        return j + 1
    return i


def balanced_braces(text, start):
    """Index just past the brace group opening at text[start] == '{' (literals and comments skipped)."""
    depth = 0
    i = start
    while i < len(text):
        j = skip_literal(text, i)
        if j != i:
            i = j
            continue
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced braces at %d" % start)


def balanced_parens(text, start):
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i + 1
    raise ValueError("unbalanced: " + text)


def norm(t):
    return re.sub(r"\s*&\s*", " &", re.sub(r"\s*\*\s*", " *", re.sub(r"\s+", " ", t.strip()))).strip()


def parse_header(header):
    """(result type, name, argument type, argument name) of '- (T) name[:(A)arg]'."""
    rest = header.strip()[1:].lstrip()
    end = balanced_parens(rest, 0)
    ret = norm(rest[1:end - 1])
    rest = rest[end:].strip()
    m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*(.*)$", rest, re.S)
    name, tail = m.group(1), m.group(2).strip()
    if not tail:
        return ret, name, None, None
    if not tail.startswith(":"):
        raise SystemExit("cannot parse method header: " + header)
    tail = tail[1:].strip()
    end = balanced_parens(tail, 0)
    arg = norm(tail[1:end - 1])
    argname = tail[end:].strip()
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", argname):
        raise SystemExit("not a one-argument method: " + header)
    return ret, name + ":", arg, argname


def name_sets(text):
    sets = {}
    for func in SETS:
        m = re.search(r"^bool " + func + r"\(SEL selector\)\n\{(.*?)^\}", text, re.S | re.M)
        if m is None:
            raise SystemExit("name set not found: " + func)
        body = re.sub(r"//[^\n]*", "", m.group(1))
        sets[func] = set(re.findall(r'"([^"]+)"', body))
    return sets


def methods(text):
    """[(conditions, category, header, body)] of the five categories' methods, in file order."""
    result = []
    lines = text.split("\n")
    offsets = []
    pos = 0
    for line in lines:
        offsets.append(pos)
        pos += len(line) + 1
    conds = []
    category = None
    i = 0
    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if re.match(r"#\s*(if|ifdef|ifndef)\b", s):
            conds.append(s)
        elif re.match(r"#\s*(else|elif)\b", s):
            raise SystemExit(f"#else/#elif is not handled: {s}")
        elif re.match(r"#\s*endif\b", s):
            conds.pop()
        elif line.startswith("@implementation"):
            m = re.match(r"@implementation\s+Entity\s*\((\w+)\)", line)
            category = m.group(1) if m and m.group(1) in CATEGORIES else None
        elif line.startswith("@end"):
            category = None
        elif category is not None and re.match(r"-\s*\(", line):
            start = offsets[i]
            brace = text.index("{", start)
            end = balanced_braces(text, brace)
            header = text[start:brace]
            body = text[brace:end]
            result.append((list(conds), category, header, body))
            # continue after the line holding the closing brace
            while i + 1 < len(lines) and offsets[i + 1] < end:
                i += 1
        i += 1
    if conds:
        raise SystemExit("unbalanced #if")
    return result


def table_rows():
    """The rows of the header itself, the source since bead oo-9ht.39.7.3 deleted the categories:
    [(conditions, None, result type, name, argument type, argument name, flags, body)], the
    function ByName_<i> of the i-th row. Rendering them again must give the header back."""
    text = OUT.read_text(encoding="utf-8")
    lines = text.split("\n")
    offsets = []
    pos = 0
    for line in lines:
        offsets.append(pos)
        pos += len(line) + 1
    functions = {}
    conds = []
    rows_ = []
    section = None
    i = 0
    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if line.startswith("// The category methods, as functions of the C++ entity."):
            section = "functions"
        elif line.startswith("inline const OOEntityByNameRow kOOEntityByNameRows[]"):
            section = "rows"
        elif section is None or section == "done":
            pass
        elif re.match(r"#\s*(if|ifdef|ifndef)\b", s):
            conds.append(s)
        elif re.match(r"#\s*(else|elif)\b", s):
            raise SystemExit(f"#else/#elif is not handled: {s}")
        elif re.match(r"#\s*endif\b", s):
            conds.pop()
        elif section == "functions":
            m = re.match(r"^(.+?) ByName_(\d+)\((Entity \*(?:entity)?)(?:, (const (?:std::string|oo::PList) &)(\w*))?\)$", line)
            if m:
                start = offsets[i + 1]
                if not text.startswith("{", start):
                    raise SystemExit(f"ByName_{m.group(2)}: no body")
                end = balanced_braces(text, start)
                index = int(m.group(2))
                if index in functions:
                    raise SystemExit(f"ByName_{index} defined twice")
                functions[index] = (list(conds), norm(m.group(1)), m.group(4), m.group(5) or "", text[start:end])
                while i + 1 < len(lines) and offsets[i + 1] < end:
                    i += 1
        elif section == "rows":
            if s == "};":
                section = "done"
            m = re.match(r'\{ "([^"]+)",\t([^\t]+),\tkOOTypeEncoding<(.*)>,\tOOEntityByNameArgument::(\w+),\t&OOEntityByNameAdapt\w+<&ByName_(\d+)>,', s)
            if m:
                rows_.append((list(conds), m.group(1), m.group(2).split(" | "), norm(m.group(3)), m.group(4), int(m.group(5))))
        i += 1
    if conds:
        raise SystemExit("unbalanced #if")
    result = []
    seen = set()
    for conds, name, flags, ret, kind, index in rows_:
        if name in seen:
            raise SystemExit("a name twice: " + name)
        seen.add(name)
        if name in PLANET or name in BEACON:
            raise SystemExit("a planet or beacon name in the table: " + name)
        if index not in functions:
            raise SystemExit(f"{name}: ByName_{index} is not defined")
        fconds, fret, arg, argname, body = functions.pop(index)
        if fconds != conds or encoded(fret) != ret or (ARG_KINDS[arg] if arg else "None") != kind:
            raise SystemExit(f"{name}: the row and ByName_{index} disagree")
        unknown = [flag for flag in flags if flag not in SETS.values()]
        if unknown:
            raise SystemExit(f"{name}: unknown flags {unknown}")
        result.append((conds, None, fret, name, arg, argname, flags, body))
    if functions:
        raise SystemExit("functions no row names: " + ", ".join(f"ByName_{i}" for i in sorted(functions)))
    return result


def encoded(ret):
    # A function answering the C++ entity (bead oo-9ht.39.24) keeps its row's object encoding ("@", as
    # @encode(Entity *) gave): the dispatcher classifies the row as it classified the method's object result.
    # The encoding is the measured literal kOOTypeEncoding<> gives (OOTypeEncodings.h; bead oo-dbz.3), id's keyed by OOObjCId.
    return "OOObjCId" if ret == "Entity *" else ret


def rows():
    if not FACADE.exists():
        return table_rows()	# the facade itself was deleted by bead oo-dpyk8: the header is the source
    text = FACADE.read_text(encoding="utf-8")
    if not any(f"@implementation Entity ({category})" in text for category in CATEGORIES):
        return table_rows()
    sets = name_sets(text)
    seen = set()
    result = []
    for conds, category, header, body in methods(text):
        ret, name, arg, argname = parse_header(header)
        if name in seen:
            raise SystemExit("defined twice: " + name)
        seen.add(name)
        if name in PLANET or name in BEACON:
            raise SystemExit("a planet or beacon name in a by-name category: " + name)
        flags = [flag for func, flag in SETS.items() if name in sets[func]]
        if not flags:
            raise SystemExit(f"{name} ({category}) is in no name set: -respondsToSelector: never answers it")
        if arg is not None and arg not in ARG_KINDS:
            raise SystemExit(f"{name}: an argument a by-name call cannot pass: {arg}")
        if "_cxxEntity" in body.replace("_cxxEntity.get()", ""):
            raise SystemExit(f"{name}: body reads _cxxEntity other than _cxxEntity.get()")
        if re.search(r"\b(self|super|_cmd)\b", body):
            raise SystemExit(f"{name}: body reads self, super or _cmd")
        if re.search(r"\bentity\b", body):
            raise SystemExit(f"{name}: body already names 'entity'")
        result.append((conds, category, ret, name, arg, argname, flags, body.replace("_cxxEntity.get()", "entity")))
    missing = set().union(*sets.values()) - seen
    if missing:
        raise SystemExit("names in the sets the categories do not define: " + ", ".join(sorted(missing)))
    return result


HEAD = """/*

OOEntityCalledByNameTable.h

Generated by tools/gen-entity-by-name-table.py from the root entity facade's by-name categories
(Entity+ObjCBridge.mm: Entity (OOShipSelectorsCalledByName), (OOPlayerSelectorsCalledByName),
(OOStationSelectorsCalledByName), (OODockSelectorsCalledByName), (OOVisualEffectSelectorsCalledByName)),
bead oo-9ht.39.7.1, ADR-0056 amendment oo-9ht.39.7.1. The categories are deleted (bead
oo-9ht.39.7.3): this file is the source. Edit a function and its row together, then run
python3 tools/gen-entity-by-name-table.py --check (it renders the rows again and must get this file).

One row per former category method, exactly the categories' names and #if conditions: the name
sets the root facade's -respondsToSelector: read (the applies-to flags), the encoding of the declared result
(kOOTypeEncoding<>, @encode()'s measured literal: OOTypeEncodings.h, bead oo-dbz.3),
the argument kind, the adaptor: the method's body, verbatim, with the entity for the facade's own C++
entity, and for a method with no argument the typed adaptor (its result by type; bead oo-9ht.39.7.2).
Included by OOEntityCalledByName.cpp only, after the parts (ShipPart() ...) the bodies read.

*/

#ifndef OOENTITYCALLEDBYNAMETABLE_H
#define OOENTITYCALLEDBYNAMETABLE_H

namespace {

// The category methods, as functions of the C++ entity.
"""


def render():
    out = [HEAD]
    table = []
    current = []

    def switch(conds, sink):
        nonlocal current
        if conds != current:
            for _ in current:
                sink.append("#endif")
            for c in conds:
                sink.append(c)
            current = conds

    data = rows()
    for index, (conds, category, ret, name, arg, argname, flags, body) in enumerate(data):
        switch(conds, out)
        params = "Entity *entity" if re.search(r"\bentity\b", body) else "Entity *"
        if arg is not None:
            params += ", " + arg + (argname if re.search(r"\b" + argname + r"\b", body) else "")
        out.append(f"{ret} ByName_{index}({params})")
        out.append(body)
    switch([], out)
    current = []
    out.append("")
    out.append("}\t// namespace")
    out.append("")
    out.append("")
    out.append("// name, applies-to flags, the encoding of the result, argument kind, adaptor, typed adaptor (no argument)")
    out.append("inline const OOEntityByNameRow kOOEntityByNameRows[] =")
    out.append("{")
    for index, (conds, category, ret, name, arg, argname, flags, body) in enumerate(data):
        switch(conds, out)
        kind = ARG_KINDS[arg] if arg is not None else "None"
        typed = f"&OOEntityByNameTyped<&ByName_{index}>" if arg is None else "nullptr"
        out.append(f"\t{{ \"{name}\",\t{' | '.join(flags)},\tkOOTypeEncoding<{encoded(ret)}>,\tOOEntityByNameArgument::{kind},\t&OOEntityByNameAdapt{kind}<&ByName_{index}>,\t{typed} }},")
    switch([], out)
    out.append("};")
    out.append("")
    out.append("#endif\t// OOENTITYCALLEDBYNAMETABLE_H")
    out.append("")
    return "\n".join(out)


def main():
    text = render()
    if "--check" in sys.argv[1:]:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print(f"{OUT.relative_to(ROOT)} is stale: run python3 tools/gen-entity-by-name-table.py", file=sys.stderr)
            return 1
        return 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)} ({text.count(chr(10) + chr(9) + '{ ')} rows)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
