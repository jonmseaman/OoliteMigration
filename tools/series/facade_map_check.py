#!/usr/bin/env python3
"""Check that facade-map.md has a row for every public name in JSEngine.hpp.

Run from the OoliteMigration root:

    python -I .agent-tmp/facade_map_check.py [--list]

The public names are the declarations inside `namespace ooscript { ... }` of
src/Core/Scripting/ooscript/JSEngine.hpp (read from the worktree at
.agent-tmp/upstream-binding-wt):

  * namespace-scope functions (operators included, e.g. `operator|`);
  * struct / class / enum / using names;
  * the enumerators of every enum, as `Enum::Name`;
  * constexpr constants;
  * the public members of every struct / class with a body, as `Type::member`
    (data members and methods; constructors, destructors and `= delete`d
    members are covered by the type's own row and are not listed).

The table's names are the first cell of every Markdown table row in
specs/002-seriesb-rebase-stack/series/facade-map.md, backticks stripped.

Exit 0 when the two sets are equal. Exit 1 listing names missing from the
table, and names in the table that the header does not declare (stale rows).
Exit 2 when an input cannot be read or parsed. `--list` prints the extracted
names and exits 0.
"""

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
HEADER = os.path.join(ROOT, ".agent-tmp", "upstream-binding-wt", "src", "Core",
                      "Scripting", "ooscript", "JSEngine.hpp")
TABLE = os.path.join(ROOT, "specs", "002-seriesb-rebase-stack", "series",
                     "facade-map.md")

IDENT = r"[A-Za-z_]\w*"


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    return text


def match_brace(text, open_idx):
    depth = 0
    for i in range(open_idx, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("unbalanced braces")


def statements(body):
    """Split a brace body into (head, inner-or-None) statements at depth 0.

    head is the text before the statement's first '{' (or the whole statement
    when it has none); inner is the text between that brace pair."""
    out = []
    i, start = 0, 0
    while i < len(body):
        c = body[i]
        if c == ";":
            stmt = body[start:i].strip()
            if stmt:
                out.append((stmt, None))
            i += 1
            start = i
        elif c == "{" and re.search(r"(?<![=!<>])=(?!=)\s*[\w:]*\s*$", body[start:i]):
            # A brace initialiser (`T x = T{};`), not a body.
            i = match_brace(body, i) + 1
        elif c == "{":
            end = match_brace(body, i)
            head = body[start:i].strip()
            inner = body[i + 1:end]
            j = end + 1
            # A type or enum body ends with ';'; a function body does not.
            k = j
            while k < len(body) and body[k] in " \t\r\n":
                k += 1
            if k < len(body) and body[k] == ";":
                j = k + 1
            out.append((head, inner))
            i = j
            start = i
        elif c == "}":
            raise ValueError("unexpected '}'")
        else:
            i += 1
    if body[start:].strip():
        raise ValueError("trailing text without ';': %r" % body[start:].strip()[:60])
    return out


def norm(s):
    return " ".join(s.split())


def function_name(head):
    """The declared name of a function declaration/definition head, or None."""
    m = re.search(r"\boperator\s*(\(\)|\[\]|[^\s(]+)\s*\(", head)
    if m:
        return "operator" + m.group(1)
    m = re.search(r"(~?" + IDENT + r")\s*\(", head)
    return m.group(1) if m else None


def enumerators(inner):
    names = []
    for part in inner.split(","):
        part = part.strip()
        if not part:
            continue
        m = re.match(r"(" + IDENT + r")\b", part)
        if not m:
            raise ValueError("bad enumerator %r" % part)
        names.append(m.group(1))
    return names


def members(type_name, inner, default_public):
    names = []
    public = default_public
    for head, body in statements(inner):
        # Peel access labels off the front of the statement.
        while True:
            m = re.match(r"(public|private|protected)\s*:(?!:)\s*", head)
            if not m:
                break
            public = m.group(1) == "public"
            head = head[m.end():]
        if not head or not public:
            continue
        h = norm(head)
        if re.search(r"=\s*delete\s*$", h):
            continue
        before_init = h.split("=")[0] if "(" not in h.split("=")[0] else h
        if "(" in before_init or body is not None:
            name = function_name(h)
            if name is None:
                raise ValueError("cannot name member %r of %s" % (h, type_name))
            if name in (type_name, "~" + type_name):
                continue  # constructor / destructor: the type's row covers it
            names.append(type_name + "::" + name)
        else:
            m = re.search(r"(" + IDENT + r")\s*(\[[^\]]*\])?\s*$", h.split("=")[0].strip())
            if not m:
                raise ValueError("cannot name data member %r of %s" % (h, type_name))
            names.append(type_name + "::" + m.group(1))
    return names


def header_names(path):
    with open(path, encoding="utf-8") as f:
        text = strip_comments(f.read())
    m = re.search(r"namespace\s+ooscript\s*\{", text)
    if not m:
        raise ValueError("no namespace ooscript in header")
    open_idx = m.end() - 1
    body = text[open_idx + 1:match_brace(text, open_idx)]

    names = []
    for head, inner in statements(body):
        h = norm(head)
        if h.startswith("#"):
            continue
        tm = re.match(r"(struct|class)\s+(" + IDENT + r")\b", h)
        em = re.match(r"enum(?:\s+(?:class|struct))?\s+(" + IDENT + r")\b", h)
        um = re.match(r"using\s+(" + IDENT + r")\s*=", h)
        if tm:
            names.append(tm.group(2))
            if inner is not None:
                names.extend(members(tm.group(2), inner, tm.group(1) == "struct"))
        elif em:
            names.append(em.group(1))
            if inner is not None:
                names.extend(em.group(1) + "::" + e for e in enumerators(inner))
        elif um:
            names.append(um.group(1))
        elif "(" in h.split("=")[0] or inner is not None:
            name = function_name(h)
            if name is None:
                raise ValueError("cannot name declaration %r" % h)
            names.append(name)
        elif h.startswith("constexpr") or h.startswith("extern"):
            cm = re.search(r"(" + IDENT + r")\s*(=|$)", h)
            if not cm:
                raise ValueError("cannot name constant %r" % h)
            names.append(cm.group(1))
        else:
            raise ValueError("unclassified declaration %r" % h)
    return names


def table_names(path):
    names = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("|"):
                continue
            cells = [c.strip() for c in re.split(r"(?<!\\)\|", line[1:])]
            first = cells[0] if cells else ""
            if not first or re.fullmatch(r":?-{3,}:?", first) or first == "Façade name":
                continue
            names.append(first.replace("`", "").replace("\\|", "|").strip())
    return names


def main(argv):
    try:
        declared = header_names(HEADER)
    except (OSError, ValueError) as e:
        print("facade_map_check: cannot read header: %s" % e, file=sys.stderr)
        return 2
    if "--list" in argv:
        for n in declared:
            print(n)
        print("%d names" % len(set(declared)), file=sys.stderr)
        return 0
    try:
        listed = table_names(TABLE)
    except OSError as e:
        print("facade_map_check: cannot read table: %s" % e, file=sys.stderr)
        return 2

    declared_set, listed_set = set(declared), set(listed)
    missing = [n for n in dict.fromkeys(declared) if n not in listed_set]
    stale = [n for n in dict.fromkeys(listed) if n not in declared_set]
    dupes = sorted({n for n in listed if listed.count(n) > 1})
    for n in missing:
        print("missing from table: %s" % n)
    for n in stale:
        print("not declared in JSEngine.hpp: %s" % n)
    for n in dupes:
        print("duplicate row: %s" % n)
    print("%d public names, %d table rows" % (len(declared_set), len(listed)))
    return 1 if (missing or stale or dupes) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
