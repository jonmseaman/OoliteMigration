#!/usr/bin/env python3
"""Generate callObjC()'s name table for entities (bead oo-9ht.44, ADR-0056 amendment oo-9ht.44).

callObjC() on an entity dispatches through kOOJSCallEntityMethods
(upstream/oolite/src/Core/Scripting/OOJSCallEntityMethods.h) instead of reading the Objective-C
method signatures of the entity's object. The table is exactly the instance methods the root
facade's @implementation blocks define (Entity and its categories: the forwarders, the shader,
beacon and JS categories, the cascade's) and the rows of the by-name table
(OOEntityCalledByNameTable.h), read where the facade marks the place its by-name categories held
until bead oo-9ht.39.7.3, that the old signature matcher
could call safely: no argument, or one `const std::string &` argument with a void or oo::PList
result (the two string templates). Lifetime and root-protocol names (init, dealloc, ...) are
left out, as are argument-taking scalar methods (the matcher called them with their argument
missing). Each row keeps the method's #if conditions and, for a typed result, @encode() of the
declared return type, which callObjC() reads through OOShaderUniformTypeFromEncoding() as the
matcher read the method's return type.

    python3 tools/gen-callobjc-entity-table.py           # rewrite the header
    python3 tools/gen-callobjc-entity-table.py --check   # exit 1 if the header is stale
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "upstream/oolite/src"
SOURCES = [
    SRC / "Core/Entities/Entity+ObjCBridge.mm",
]
# The cascade's Entity (OOQuiriumCascadeExtensions) category was deleted by bead oo-9ht.186; its one
# method stays a callObjC() name (answered on the C++ part by OOEntityCalledByName.mm's facade row
# Facade_isCascadeWeapon), rendered where the category's rows followed the facade's.
RETIRED_CASCADE_CATEGORY_ROWS = [
    ("isCascadeWeapon", "Typed", "BOOL"),
]
OUT = SRC / "Core/Scripting/OOJSCallEntityMethods.h"
# The five by-name categories are deleted (bead oo-9ht.39.7.3): their methods are the rows of the
# C++ by-name table, read where the facade marks their place, as the categories' methods were.
BY_NAME_TABLE = SRC / "Core/Entities/OOEntityCalledByNameTable.h"
BY_NAME_MARKER = "// BY-NAME TABLE ROWS HERE"
BY_NAME_ARG = {"None": None, "String": "const std::string &", "PList": "const oo::PList &"}

# Lifetime and root-protocol names: never callable by name (amendment oo-9ht.74 item 4).
EXCLUDED = {
    "init", "dealloc", "finalize", "retain", "release", "autorelease", "retainCount", "copy",
    "mutableCopy", "self", "class", "superclass", "hash", "description", "debugDescription",
    "isProxy", "zone",
}
STRING_ARG = "const std::string &"
# A facade method answering one entity (Entity *, Entity <OOBeaconEntity> *): its row is written
# @encode(id), the same "@", as the by-name table writes a cxx::Entity * result (bead oo-9ht.39.24).
ENTITY_RESULT = re.compile(r"^Entity\b[^*]*\*$")

# The facade's Entity (OOJavaScriptExtensions) category was deleted by bead oo-9ht.39.8.9; its
# callable methods stay callObjC() names (answered on the C++ part by OOEntityCalledByName.mm's
# facade rows), rendered where the category followed the by-name rows (bead oo-9ht.39.30).
RETIRED_JS_CATEGORY_ROWS = [
    ("isVisibleToScripts", "Typed", "BOOL"),
    ("cxx_oo_jsClassName", "Typed", "std::optional<std::string>"),
    ("deleteJSSelf", "VoidVoid", "void"),
]


def balanced(text, start):
    """Index just past the parenthesised group that opens at text[start] == '('."""
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
    return re.sub(r"\s*&\s*", " &", re.sub(r"\s+", " ", t.strip())).strip()


def parse_method(line):
    """(return type, name, argument type or None) of a '- (T) name[:(A)arg]' definition line, or
    None for a method with more than one argument."""
    rest = line[1:].lstrip()
    end = balanced(rest, 0)
    ret = norm(rest[1:end - 1])
    rest = rest[end:].split("{", 1)[0].split("//", 1)[0].strip()
    m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)(.*)$", rest, re.S)
    name, tail = m.group(1), m.group(2).strip()
    if not tail:
        return ret, name, None
    if not tail.startswith(":"):
        raise ValueError("cannot parse: " + line)
    tail = tail[1:].strip()
    end = balanced(tail, 0)
    arg = norm(tail[1:end - 1])
    after = tail[end:].strip()
    after = re.sub(r"^[A-Za-z_][A-Za-z0-9_]*", "", after).strip()
    if after:
        return None	# another argument
    return ret, name + ":", arg


def by_name_methods():
    """[(conditions, return type, name, argument type or None)] of the by-name table's rows."""
    result = []
    conds = []
    inrows = False
    for line in BY_NAME_TABLE.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if line.startswith("inline const OOEntityByNameRow kOOEntityByNameRows[]"):
            inrows = True
            continue
        if not inrows:
            continue
        if re.match(r"#\s*(if|ifdef|ifndef)\b", s):
            conds.append(s)
            continue
        if re.match(r"#\s*(else|elif)\b", s):
            raise SystemExit(f"{BY_NAME_TABLE.name}: #else/#elif is not handled: {s}")
        if re.match(r"#\s*endif\b", s):
            conds.pop()
            continue
        if s == "};":
            break
        m = re.match(r'\{ "([^"]+)",\t[^\t]+,\t@encode\((.*)\),\tOOEntityByNameArgument::(\w+),', s)
        if m:
            result.append((list(conds), m.group(2), m.group(1), BY_NAME_ARG[m.group(3)]))
    if not result:
        raise SystemExit(f"{BY_NAME_TABLE.name}: no rows found")
    return result


def classify(ret, arg):
    """callObjC()'s form for a method, or None if its argument is not one the templates take."""
    if arg is None:
        return {"void": "VoidVoid", "oo::PList": "PListVoid"}.get(ret, "Typed")
    if arg == STRING_ARG and ret in ("void", "oo::PList"):
        return "VoidString" if ret == "void" else "PListString"
    return None


def rows():
    result = []
    for path in SOURCES:
        conds = []
        inimpl = False
        for line in path.read_text(encoding="utf-8").splitlines():
            s = line.strip()
            if re.match(r"#\s*(if|ifdef|ifndef)\b", s):
                conds.append(s)
                continue
            if re.match(r"#\s*(else|elif)\b", s):
                raise SystemExit(f"{path.name}: #else/#elif is not handled: {s}")
            if re.match(r"#\s*endif\b", s):
                conds.pop()
                continue
            if s.startswith(BY_NAME_MARKER):
                for bconds, ret, name, arg in by_name_methods():
                    form = classify(ret, arg)
                    if form is not None and name.rstrip(":") not in EXCLUDED:
                        result.append((conds + bconds, name, form, ret))
                for name, form, ret in RETIRED_JS_CATEGORY_ROWS:
                    result.append((list(conds), name, form, ret))
                continue
            if re.match(r"@implementation\s+Entity\b", line):
                inimpl = True
                continue
            if line.startswith("@end"):
                inimpl = False
                continue
            if not inimpl or not re.match(r"-\s*\(", line):
                continue
            parsed = parse_method(line)
            if parsed is None:
                continue
            ret, name, arg = parsed
            if ENTITY_RESULT.match(ret):
                ret = "id"	# the same "@"; callObjC() makes the C++ entity's Object node (bead oo-9ht.39.24)
            if name.rstrip(":") in EXCLUDED:
                continue
            form = classify(ret, arg)
            if form is None:
                continue	# an argument the templates do not take: not callable by name
            result.append((list(conds), name, form, ret))
    for name, form, ret in RETIRED_CASCADE_CATEGORY_ROWS:
        result.append(([], name, form, ret))
    return result


def render():
    out = []
    out.append("/*")
    out.append("")
    out.append("OOJSCallEntityMethods.h")
    out.append("")
    out.append("GENERATED by tools/gen-callobjc-entity-table.py from the root entity facade's @implementation")
    out.append("blocks (Entity+ObjCBridge.mm; the cascade's deleted category's row, bead oo-9ht.186) and the by-name table")
    out.append("(OOEntityCalledByNameTable.h, where the facade's by-name categories were; bead oo-9ht.39.7.3).")
    out.append("Do not edit: rerun the script. callObjC()'s names for an entity (bead oo-9ht.44, ADR-0056")
    out.append("amendment oo-9ht.44): each is a selector the facade defines, or a by-name row, with no argument,")
    out.append("or with one const std::string & argument and a void or oo::PList result; a Typed row keeps")
    out.append("@encode() of the declared return type.")
    out.append("Included by OOJSCall.mm and its test only.")
    out.append("")
    out.append("*/")
    out.append("")
    out.append("#ifndef OOJSCALLENTITYMETHODS_H")
    out.append("#define OOJSCALLENTITYMETHODS_H")
    out.append("")
    out.append("#import \"Entity.h\"")
    out.append("#import \"ShipEntity.h\"")
    out.append("#import \"PlayerEntity.h\"")
    out.append("#import \"StationEntity.h\"")
    out.append("#import \"OOVisualEffectEntity.h\"")
    out.append("#import \"OOPlanetEntity.h\"")
    out.append("#include \"oofnd/PList.hpp\"")
    out.append("#include <string>")
    out.append("")
    out.append("enum class OOJSCallEntityMethodForm")
    out.append("{")
    out.append("\tVoidVoid,\t\t// - (void) name")
    out.append("\tVoidString,\t\t// - (void) name:(const std::string &)")
    out.append("\tPListString,\t// - (oo::PList) name:(const std::string &)")
    out.append("\tPListVoid,\t\t// - (oo::PList) name")
    out.append("\tTyped\t\t\t// - (T) name: encoding is @encode(T)")
    out.append("};")
    out.append("")
    out.append("struct OOJSCallEntityMethodRow")
    out.append("{")
    out.append("\tconst char\t\t\t\t\t*name;")
    out.append("\tOOJSCallEntityMethodForm\tform;")
    out.append("\tconst char\t\t\t\t\t*encoding;\t// a Typed row's @encode() of the return type, else null")
    out.append("};")
    out.append("")
    out.append("inline const OOJSCallEntityMethodRow kOOJSCallEntityMethods[] =")
    out.append("{")
    current = []
    for conds, name, form, ret in rows():
        if conds != current:
            for _ in current:
                out.append("#endif")
            for c in conds:
                out.append(c)
            current = conds
        enc = f"@encode({ret})" if form == "Typed" else "nullptr"
        out.append(f"\t{{ \"{name}\",\tOOJSCallEntityMethodForm::{form},\t{enc} }},")
    for _ in current:
        out.append("#endif")
    out.append("};")
    out.append("")
    out.append("#endif\t// OOJSCALLENTITYMETHODS_H")
    out.append("")
    return "\n".join(out)


def main():
    text = render()
    if "--check" in sys.argv[1:]:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print(f"{OUT.relative_to(ROOT)} is stale: run python3 tools/gen-callobjc-entity-table.py", file=sys.stderr)
            return 1
        return 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)} ({text.count(chr(10) + chr(9) + '{ ')} rows)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
