#!/usr/bin/env python3
"""Check a Phase 3 pre-split slice plan against the file it splits.

A slice plan (docs/phases/3-slices/<File>.md) says which methods and functions of one Objective-C++
file go into which conversion story ("slice"), so that each story reads under the 1,500-line story
budget (docs/phases/3-cpp-conversion.md, seam "Pre-splitting files > 400 lines"; docs/templates/story.md).
The plan is the markdown file's single fenced block tagged `slice-plan`:

    source: upstream/oolite/src/Core/Foo.mm      # the file being split (required)
    header: upstream/oolite/src/Core/Foo.h       # its header; every slice reads it (optional)
    header-decls: per-slice                      # optional (bead oo-9ht.140): a slice reads the
                                                 # header's method declarations of its own units
                                                 # only, and all the rest of the header (macros,
                                                 # ivars, types); for a header too big to charge
                                                 # whole to every slice (ShipEntity.h)
    header-names: by-use                         # optional (bead oo-9ht.154): a slice reads the
                                                 # header's other declarations (ivars, macros,
                                                 # enums, types, constants, functions) only where
                                                 # its own units use the names they declare; for a
                                                 # header whose ivars and constants leave a big
                                                 # method no room (PlayerEntity.h)
    one-unit-slices: frontier                    # optional (bead oo-9ht.157): a slice that owns
                                                 # exactly one unit may own more than --max-own
                                                 # (it must still read under --max-read): one
                                                 # method the plan cannot cut is a frontier story,
                                                 # not a fleet one (PlayerEntityControls.mm's
                                                 # 1,105-line pollGuiArrowKeyControls:)
    retired-by: oo-xxxx                          # optional: the file is deleted by that bead; an
                                                 # absent source then passes, a present one is checked
    slice 1: class shell and lifecycle           # a slice: "slice <n>: <title>", then its entries
      -[Foo init]                                # a method, by selector (category does not matter)
      +[Foo sharedFoo]
      FooHelper()                                # a C/C++ function defined in the file
      @Foo(Private)                              # every method of that @implementation block
      -[Foo draw*]                               # '*' is a wildcard (nothing else is special)
    verbatim: plain C, no Objective-C            # units that are not converted (ADR-0012, CLAUDE.md
      OOScaleHelper()                            # rule 9): never read by a slice, and each must
                                                 # contain no Objective-C syntax
    mac-only: the Mac layer, Phase 5             # units the fleet never compiles (bead oo-q9l2w):
      @Foo(MacOSX)                               # each must lie wholly inside an #if/#ifdef
                                                 # OOLITE_MAC_OS_X arm; not converted in Phase 3
                                                 # (ADR-0056 amendment oo-bgmb item 2, ADR-0009),
                                                 # never read by a slice, no story is emitted; a
                                                 # mac-only entry claims a unit in a Mac arm
                                                 # whatever its tier (the Mac arm of a method a
                                                 # slice names exactly stays Mac)

Units are found by a light lexer: comments and string literals are blanked, braces counted.
A unit is a method definition inside @implementation, or a function definition at file scope
(namespace / extern "C" blocks are transparent). Comment/blank lines directly above a unit belong
to it. Every other line (imports, statics, tables, @interface blocks, #pragma mark) is the
preamble, and every slice is charged for all of it.

Checks (exit 1 on any failure):
  * every unit is assigned to exactly one slice or to verbatim (the most specific entry kind
    wins: exact name, then a name with '*', then @block, then a lone '*' catch-all), so a slice
    can take a whole category by @block and another slice can still claim single methods of it;
  * each slice's read estimate, header + preamble + its own units, is under --max-read (1,500);
    with `header-decls: per-slice` the header part is the header less every method declaration
    of an @interface block, plus the declarations (and the comment lines directly above them) of
    the slice's own methods, matched by -[Class selector]; with `header-names: by-use` it is also
    less every other declaration (an ivar, #define, enum, typedef, constant or function, with the
    comment lines directly above it), plus those that declare a name the slice's units use, and
    the ones those use in turn;
  * each slice's own units total at most --max-own lines (default 800): converting a method
    rewrites roughly half its lines, so this keeps a story near the ~400-lines-written budget;
    with `one-unit-slices: frontier` a slice of a single unit is exempt (no plan can cut one
    method) and is reported as "frontier", which is the label its story bead takes;
  * no verbatim unit contains Objective-C (message send, @"...", @selector, @try, ...), except an
    out-of-line C++ member definition (X::m, its head qualified): that is a member a landed slice
    already converted, which ADR-0056 lets keep sends to Objective-C objects and @try (oo-9ht.117);
  * every mac-only unit lies wholly inside an OOLITE_MAC_OS_X preprocessor arm.
An exact entry that matches no unit is a warning (the method was removed or renamed upstream).

    python3 tools/check-slice-plan.py docs/phases/3-slices/Foo.md [--json] [--units]
    python3 tools/check-slice-plan.py --selftest
    python3 tools/check-slice-plan.py --slice-done 2 docs/phases/3-slices/Foo.md

--slice-done is a slice story's acceptance (tools/gen-stories.py emits one conversion story per
slice): it exits nonzero while any unit the plan assigns to that slice is still an Objective-C
method or a function with Objective-C syntax in it, and zero once none is.
"""
import argparse, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------- lexer
def blank_comments_and_strings(text):
    """Same length and newlines as text; comments, string and char literals become spaces."""
    out = list(text); i = 0; n = len(text)
    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n": out[k] = " "
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            j = text.find("\n", i); j = n if j < 0 else j
            blank(i, j); i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2); j = n if j < 0 else j + 2
            blank(i, j); i = j
        elif c == '"' or (c == "'" and not (i > 0 and (text[i-1].isalnum()))):
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            j = min(j + 1, n)
            blank(i + 1, j - 1) if j - 1 > i + 1 else None
            i = j
        else:
            i += 1
    return "".join(out)

OBJC_SEND = re.compile(r"\[\s*[A-Za-z_][\w.]*(\s*(->|\.)\s*\w+|\([^()]*\))*\s+[A-Za-z_]\w*\s*[\]:]")
MAC_COND = re.compile(r"(defined\s*\(\s*OOLITE_MAC_OS_X\s*\)|defined\s+OOLITE_MAC_OS_X|OOLITE_MAC_OS_X)")
OBJC_AT = re.compile(r'@"|@(selector|try|catch|finally|throw|synchronized|encode|protocol|autoreleasepool|interface|implementation)\b')

def objc_sites(code_lines):
    """0-based offsets of lines with Objective-C syntax. String delimiters survive blanking, so @"..." shows."""
    return [k for k, c in enumerate(code_lines) if OBJC_SEND.search(c) or OBJC_AT.search(c)]

def selector_of(decl):
    """'- (void) foo:(int)a bar:(id)b' -> 'foo:bar:'; '+ (id) shared' -> 'shared'."""
    s = decl.strip()[1:]
    out = []; depth = 0
    for ch in s:  # drop balanced (type) groups
        if ch == "(": depth += 1; continue
        if ch == ")": depth -= 1; continue
        if depth == 0: out.append(ch)
    s = "".join(out)
    kw = re.findall(r"(\w+)\s*:", s)
    if kw: return "".join(k + ":" for k in kw)
    m = re.search(r"\w+", s)
    return m.group(0) if m else "?"

FUNC_NAME = re.compile(r"(~?[A-Za-z_][\w:]*|operator\s*\S+)\s*\([^;]*\)\s*(const\s*|noexcept\s*|override\s*|->\s*[\w:<>*& ]+)*$", re.S)
NOT_FUNC = re.compile(r"^\s*(struct|class|union|enum|typedef|namespace|extern\s*\"C\"|template\s*<[^>]*>\s*(struct|class))\b|=\s*$|=[^=]*$")

def parse_units(path):
    """Return (units, preamble_lines, total_lines, code_lines, raw_lines).
    units: list of dicts {name, block, kind, start, end} with 0-based inclusive line ranges."""
    raw = open(path, encoding="utf-8", errors="replace").read()
    code = blank_comments_and_strings(raw)
    raw_lines = raw.split("\n"); code_lines = code.split("\n")
    if raw_lines and raw_lines[-1] == "": raw_lines.pop(); code_lines = code_lines[:len(raw_lines)]
    units = []
    stack = []            # brace kinds: 'ns' (namespace / extern "C": transparent), 'body' (a unit), 'other'
    impl = None           # current @implementation block name, e.g. 'Foo' or 'Foo(Private)'
    in_interface = False
    buf = []; buf_line = None   # the file-scope statement text since the last ; { or }
    cur = None            # the unit being read
    def eff(): return sum(1 for k in stack if k != "ns")
    pp = False            # inside a preprocessor directive (continued with a trailing backslash)
    cond = []             # one bool per open #if: is its current arm an OOLITE_MAC_OS_X arm?
    mac_line = [False] * len(code_lines)
    for ln, line in enumerate(code_lines):
        s = line.strip()
        if pp or s.startswith("#"):   # directives never count braces (#define bodies, #if arms)
            if not pp:
                d = re.match(r"#\s*(ifdef|ifndef|if|elif|else|endif)\b\s*(.*)$", s)
                if d:
                    kw, arg = d.group(1), d.group(2).strip()
                    if kw in ("if", "ifdef", "ifndef"): cond.append(kw != "ifndef" and bool(MAC_COND.fullmatch(arg)))
                    elif kw == "elif" and cond: cond[-1] = bool(MAC_COND.fullmatch(arg))
                    elif kw == "else" and cond: cond[-1] = False
                    elif kw == "endif" and cond: cond.pop()
            pp = line.rstrip().endswith("\\")
            mac_line[ln] = any(cond)
            continue
        mac_line[ln] = any(cond)
        if eff() == 0 and cur is None:
            if in_interface:
                if s.startswith("@end"): in_interface = False
                continue
            m = re.match(r"@implementation\s+(\w+)\s*(\(\s*(\w*)\s*\))?", s)
            if m:
                impl = m.group(1) + (f"({m.group(3)})" if m.group(2) else ""); buf = []; buf_line = None; continue
            if re.match(r"@(interface|protocol)\b", s) and not s.endswith(";"):
                in_interface = True; buf = []; buf_line = None; continue
            if s.startswith("@end"):
                impl = None; buf = []; buf_line = None; continue
        for ch in line + "\n":
            if ch == "{":
                if eff() == 0 and cur is None:
                    head = "".join(buf).strip()
                    if impl and head[:1] in "-+":
                        cur = {"name": f"{head[0]}[{impl.split('(')[0]} {selector_of(head)}]",
                               "block": "@" + impl, "kind": "method", "member": False, "start": buf_line}
                        stack.append("body")
                    elif re.match(r"^(namespace\b[^{]*|extern\s*\"C\"\s*)$", head):
                        stack.append("ns")
                    elif head and not NOT_FUNC.search(head) and FUNC_NAME.search(head):
                        name = FUNC_NAME.search(head).group(1)
                        member = "::" in name   # an out-of-line C++ member definition: X::m(...) { (oo-9ht.117)
                        mac = re.fullmatch(r"([A-Z][A-Z0-9_]+)\s*\(([^()]*)\)", head)
                        name = f"{mac.group(1)}({mac.group(2).strip()})" if mac else name.split("::")[-1] + "()"
                        cur = {"name": name, "block": "@" + impl if impl else "", "kind": "function", "member": member, "start": buf_line}
                        stack.append("body")
                    else:
                        stack.append("other")
                    buf = []; buf_line = None
                else:
                    stack.append("other")
            elif ch == "}":
                if stack: stack.pop()
                if cur is not None and "body" not in stack:
                    cur["end"] = ln; units.append(cur); cur = None
                if eff() == 0: buf = []; buf_line = None
            elif ch == ";" and eff() == 0 and cur is None:
                if impl and "".join(buf).strip()[:1] in ("-", "+"):
                    continue   # '- (void) foo:(int)x;' then '{' is a legal method definition: keep the head
                buf = []; buf_line = None
            elif eff() == 0 and cur is None:
                if buf_line is None and not ch.isspace(): buf_line = ln
                if buf_line is not None: buf.append(ch)
    for u in units:   # before the leading comments are attached: the unit's own lines
        u["mac"] = all(mac_line[k] for k in range(u["start"], u["end"] + 1))
    # attach leading comment / blank lines to each unit
    taken = [False] * len(raw_lines)
    for u in units:
        for k in range(u["start"], u["end"] + 1): taken[k] = True
    for u in units:
        k = u["start"] - 1
        while k >= 0 and not taken[k] and code_lines[k].strip() == "":
            k -= 1
        # only claim back to the previous code line; do not eat a blank run that ends a preamble block
        u["start"] = k + 1
        for j in range(u["start"], u["end"] + 1): taken[j] = True
    preamble = sum(1 for t in taken if not t)
    return units, preamble, len(raw_lines), code_lines, raw_lines

def header_decls(path, taken=None):
    """The method declarations of a header's @interface blocks: (total lines, {'-[Class sel]': lines}).

    A declaration runs from its '-'/'+' line to its ';' and owns the comment-only lines directly
    above it (its doc comment). Ivar blocks, macros and everything outside @interface are not
    declarations. Used by `header-decls: per-slice` (bead oo-9ht.140)."""
    raw = open(path, encoding="utf-8", errors="replace").read()
    code_lines = blank_comments_and_strings(raw).split("\n"); raw_lines = raw.split("\n")
    if raw_lines and raw_lines[-1] == "": raw_lines.pop(); code_lines = code_lines[:len(raw_lines)]
    decls = {}; cls = None; depth = 0; pp = False; cur = None
    for ln, line in enumerate(code_lines):
        s = line.strip()
        if pp or (cur is None and s.startswith("#")):   # directives and macro bodies
            pp = line.rstrip().endswith("\\"); continue
        if cls is None:
            m = re.match(r"@interface\s+(\w+)", s)
            if m and not s.endswith(";"): cls = m.group(1); depth = s.count("{") - s.count("}")
            continue
        if depth > 0 or (cur is None and s.startswith("{")):   # the ivar block
            depth += line.count("{") - line.count("}"); continue
        if cur is None:
            if s.startswith("@end"): cls = None; continue
            if s[:1] not in ("-", "+"): continue
            cur = {"start": ln, "text": ""}
        cur["text"] += line + " "
        if ";" in line:
            head = cur["text"].split(";", 1)[0]
            name = f"{head.strip()[0]}[{cls} {selector_of(head)}]"
            k = cur["start"]
            while k > 0 and code_lines[k-1].strip() == "" and raw_lines[k-1].strip() != "":
                k -= 1   # the doc comment directly above
            decls[name] = decls.get(name, 0) + ln - k + 1
            if taken is not None: taken.update(range(k, ln + 1))
            cur = None
    return len(raw_lines), decls

def header_names(path):
    """The header's other declarations, charged by use: [(lines, {names declared}, {identifiers used})].

    Everything but the @interface method declarations (`header-decls`) is cut into declarations:
    each ivar statement of an ivar block (`int a, b;` declares a and b), each #define (with its
    continuation lines), and each top-level C statement: an enum or struct with its enumerators,
    tag and typedef name, a typedef, a constant or variable, a function declaration or inline
    definition. Each owns the comment-only lines directly above it. What declares nothing (#import,
    #if arms, @interface / @end lines, access keywords, blank lines, a namespace's braces) stays
    charged to every slice. Used by `header-names: by-use` (bead oo-9ht.154)."""
    raw = open(path, encoding="utf-8", errors="replace").read()
    code_lines = blank_comments_and_strings(raw).split("\n"); raw_lines = raw.split("\n")
    if raw_lines and raw_lines[-1] == "": raw_lines.pop(); code_lines = code_lines[:len(raw_lines)]
    taken = set(); header_decls(path, taken)
    IDENT = re.compile(r"[A-Za-z_]\w*")
    out = []
    def emit(start, end, names):
        k = start
        while k > 0 and (k - 1) not in taken and code_lines[k-1].strip() == "" and raw_lines[k-1].strip() != "":
            k -= 1   # the comment directly above
        text = " ".join(l for l in code_lines[start:end+1] if not l.strip().startswith("#"))
        if code_lines[start].strip().startswith("#"):   # a #define: what its body uses
            text = re.sub(r"^\s*#\s*define\s+\w+", " ", " ".join(code_lines[start:end+1]))
        out.append((end - k + 1, set(names), set(IDENT.findall(text)) - set(names)))
    def names_of(text):
        """The names one C statement (no trailing ';') declares."""
        t = text.strip()
        m = re.match(r"(typedef\s+)?(enum|struct|union|class)\b\s*(\w*)[^{]*\{(.*)\}\s*([^{}]*)$", t, re.S)
        if m:
            names = {m.group(3)} if m.group(3) else set()
            if m.group(2) == "enum":
                body = re.sub(r"\([^()]*\)", " ", m.group(4))
                for item in body.split(","):
                    ids = IDENT.findall(item.split("=")[0])
                    if ids: names.add(ids[0])
            names |= set(IDENT.findall(re.sub(r"\[[^\]]*\]", " ", m.group(5))))
            return names
        t = t.split("{", 1)[0]           # an inline function's head
        t = re.sub(r"\[[^\]]*\]", " ", t)
        while re.search(r"<[^<>]*>", t): t = re.sub(r"<[^<>]*>", " ", t)
        if "(" in t.split("=")[0]:              # a function: the name before its parameter list
            ids = IDENT.findall(t.split("(")[0])
            return {ids[-1]} if ids else set()
        names = set()
        for part in t.split("=")[0].split(","):
            part = re.sub(r":\s*\w+\s*$", "", part)   # a bit-field width
            ids = IDENT.findall(part)
            if ids: names.add(ids[-1])
        return names
    iface = False; ivar_depth = 0; cur = None; depth = 0; pp = None; fwd = False
    for ln, line in enumerate(code_lines):
        if ln in taken: continue
        s = line.strip()
        if pp is not None:                     # a #define's continuation lines
            if not line.rstrip().endswith("\\"): emit(pp[0], ln, pp[1]); pp = None
            continue
        if s.startswith("#"):
            m = re.match(r"#\s*define\s+(\w+)", s)
            if m and cur is None:
                if line.rstrip().endswith("\\"): pp = (ln, {m.group(1)})
                else: emit(ln, ln, {m.group(1)})
            continue
        if ivar_depth > 0:                    # inside an ivar block
            ivar_depth += line.count("{") - line.count("}")
            if ivar_depth <= 0: ivar_depth = 0; cur = None; continue
            if cur is None:
                if not s or re.fullmatch(r"@(private|public|protected|package)", s): continue
                cur = ln
            if ";" in line and ivar_depth == 1:
                emit(cur, ln, names_of(" ".join(l for l in code_lines[cur:ln+1] if not l.strip().startswith("#")).split(";", 1)[0])); cur = None
            continue
        if iface:
            if s.startswith("@end"): iface = False
            elif s.startswith("{"): ivar_depth = line.count("{") - line.count("}")
            continue
        if cur is None:
            if not s: continue
            if re.match(r"@(interface|protocol)\b", s) and not s.endswith(";"):
                iface = True
                if "{" in line: ivar_depth = line.count("{") - line.count("}")
                continue
            if s.startswith("@class") and not s.endswith(";"):
                fwd = True; continue          # a forward declaration over several lines
            if fwd:
                fwd = not s.endswith(";"); continue
            if s.startswith("@") or s == "}" or re.match(r"(namespace\b[^{;]*|extern\s*\"[^\"]*\"\s*)\{\s*$", s):
                continue                      # @class/@end lines, a namespace's or extern "C"'s braces
            cur = ln; depth = 0
        depth += line.count("{") - line.count("}")
        text = " ".join(l for l in code_lines[cur:ln+1] if not l.strip().startswith("#"))   # #if arms inside an enum
        head = text.split("{", 1)[0]
        if depth <= 0 and (";" in line.split("//")[0] or ("{" in text and "(" in head and not re.match(r"\s*(typedef|enum|struct|union|class)\b", head))):
            emit(cur, ln, names_of(text.rsplit(";", 1)[0] if text.rstrip().endswith(";") else text)); cur = None
    return out

# ---------------------------------------------------------------- plan
def read_plan(path):
    text = open(path, encoding="utf-8").read()
    m = re.search(r"^```slice-plan[ \t]*\n(.*?)^```", text, re.S | re.M)
    if not m: raise SystemExit(f"{path}: no ```slice-plan fenced block")
    plan = {"source": None, "header": None, "retired_by": None, "header_decls": None, "header_names": None, "one_unit_slices": None, "groups": []}
    group = None
    for raw in m.group(1).splitlines():
        line = raw.split("#", 1)[0].rstrip() if not raw.lstrip().startswith("#") else ""
        if not line.strip(): continue
        s = line.strip()
        kv = re.match(r"(source|header|retired-by|header-decls|header-names|one-unit-slices):\s*(\S+)$", s)
        if kv and not raw[:1].isspace():
            plan[kv.group(1).replace("-", "_")] = kv.group(2); continue
        g = re.match(r"slice\s+(\w+)\s*:\s*(.*)$", s)
        if g and not raw[:1].isspace():
            group = {"id": g.group(1), "title": g.group(2), "verbatim": False, "mac_only": False, "entries": []}; plan["groups"].append(group); continue
        mo = re.match(r"mac-only\s*:\s*(.*)$", s)
        if mo and not raw[:1].isspace():
            group = {"id": "mac-only", "title": mo.group(1), "verbatim": False, "mac_only": True, "entries": []}; plan["groups"].append(group); continue
        v = re.match(r"verbatim\s*:\s*(.*)$", s)
        if v and not raw[:1].isspace():
            group = {"id": "verbatim", "title": v.group(1), "verbatim": True, "mac_only": False, "entries": []}; plan["groups"].append(group); continue
        if group is None: raise SystemExit(f"{path}: entry before any slice: {s!r}")
        group["entries"].append(s)
    if not plan["source"]: raise SystemExit(f"{path}: plan has no 'source:'")
    if plan["header_decls"] not in (None, "per-slice"): raise SystemExit(f"{path}: header-decls must be 'per-slice'")
    if plan["header_decls"] and not plan["header"]: raise SystemExit(f"{path}: header-decls needs a 'header:'")
    if plan["header_names"] not in (None, "by-use"): raise SystemExit(f"{path}: header-names must be 'by-use'")
    if plan["header_names"] and not plan["header"]: raise SystemExit(f"{path}: header-names needs a 'header:'")
    if plan["one_unit_slices"] not in (None, "frontier"): raise SystemExit(f"{path}: one-unit-slices must be 'frontier'")
    ids = [g["id"] for g in plan["groups"]]
    if len(ids) != len(set(ids)): raise SystemExit(f"{path}: duplicate slice id")
    return plan

def entry_tier(e):
    """Lower is more specific: exact name, name wildcard, @block (wildcards allowed), lone '*'."""
    if e == "*": return 3
    if e.startswith("@"): return 2
    return 1 if "*" in e else 0

def wild(e, text):
    return re.fullmatch(".*".join(re.escape(p) for p in e.split("*")), text) is not None

def entry_matches(e, u):
    if e == "*": return True
    if e.startswith("@"): return wild(e, u["block"]) if u["block"] else False
    return wild(e, u["name"])

def analyse(plan_path, max_read=1500, max_own=800, base=ROOT):
    """Parse the plan and its source; return everything check() reports, as data.

    Keys: plan, retired (source absent and the plan says retired-by), missing (source absent and
    no retired-by), and when the source exists: units, assign (unit index -> slice id), shared
    (unit index -> slice ids, for a unit claimed by several), unassigned (unit
    indices), empty (ids of slices that match no unit), total, preamble, header_lines,
    slices (the per-group report), errors, warnings, code_lines, raw_lines.
    tools/gen-stories.py reads plans through this function, so there is one parser."""
    plan = read_plan(plan_path)
    src = os.path.join(base, plan["source"])
    if not os.path.exists(src):
        return {"plan": plan, "retired": bool(plan["retired_by"]), "missing": not plan["retired_by"]}
    errors, warnings = [], []
    units, preamble, total, code_lines, raw_lines = parse_units(src)
    hdr = 0
    if plan["header"]:
        hp = os.path.join(base, plan["header"])
        if os.path.exists(hp): hdr = sum(1 for _ in open(hp, encoding="utf-8", errors="replace"))
        else: errors.append(f"header {plan['header']} missing")
    decls = {}
    if plan["header_decls"] and hdr:
        hdr, decls = header_decls(hp)
    hnames = header_names(hp) if plan["header_names"] and hdr else []
    hdr_shared = hdr - sum(decls.values()) - sum(n for n, _, _ in hnames)
    names = [u["name"] for u in units]
    for n in sorted(set(x for x in names if names.count(x) > 1)):
        warnings.append(f"unit name {n} occurs {names.count(n)} times (preprocessor alternatives?); each copy is assigned the same way, except that a mac-only entry claims a copy in an OOLITE_MAC_OS_X arm")
    assign = {}; shared = {}; unassigned = []; empty = []
    for i, u in enumerate(units):
        best = None; owners = set()
        # A mac-only entry claims a unit inside an OOLITE_MAC_OS_X arm whatever its tier: the Mac arm
        # of a method a slice names exactly (-[X performGameTick:] in both arms) stays Mac (oo-q9l2w).
        if u.get("mac") and any(g["mac_only"] and any(entry_matches(e, u) for e in g["entries"]) for g in plan["groups"]):
            assign[i] = "mac-only"; continue
        for g in plan["groups"]:
            if g["mac_only"]: continue   # outside a Mac arm: a slice or verbatim owns it (below if none)
            for e in g["entries"]:
                if entry_matches(e, u):
                    t = entry_tier(e)
                    if best is None or t < best: best, owners = t, {g["id"]}
                    elif t == best: owners.add(g["id"])
        if not owners and any(g["mac_only"] and any(entry_matches(e, u) for e in g["entries"]) for g in plan["groups"]):
            assign[i] = "mac-only"   # claimed by mac-only only, but compiled: reported below
        elif not owners: unassigned.append(i); errors.append(f"unassigned: {u['name']} (line {u['start']+1}-{u['end']+1}, {u['end']-u['start']+1} lines)")
        elif len(owners) > 1:
            errors.append(f"assigned to {len(owners)} slices ({', '.join(sorted(owners))}): {u['name']}"); shared[i] = owners
        else: assign[i] = owners.pop()
    for g in plan["groups"]:
        for e in g["entries"]:
            if not any(entry_matches(e, u) for u in units):
                warnings.append(f"slice {g['id']}: entry matches nothing: {e}")
    report = []
    for g in plan["groups"]:
        mine = [units[i] for i, gid in assign.items() if gid == g["id"]]
        own = sum(u["end"] - u["start"] + 1 for u in mine)
        if g["verbatim"]:
            for u in mine:
                if u["kind"] == "method":
                    errors.append(f"verbatim unit {u['name']} is a method: it must become a member function in some slice"); continue
                if u["member"]:
                    # A converted member (cxx::X::m) that a landed slice moved out of its @implementation:
                    # ADR-0056 keeps sends to unconverted Objective-C objects and @try/@catch (amendment
                    # oo-puw9 item 4) in it, so it is not plain C and is not held to that (oo-9ht.117).
                    continue
                hits = objc_sites(code_lines[u["start"]:u["end"]+1])
                if hits: errors.append(f"verbatim unit {u['name']} contains Objective-C at line {u['start']+hits[0]+1}: {raw_lines[u['start']+hits[0]].strip()[:90]}")
            report.append({"id": g["id"], "title": g["title"], "verbatim": True, "mac_only": False, "units": len(mine), "own": own, "read": 0,
                           "members": [u["name"] for u in mine]})
            continue
        if g["mac_only"]:
            for u in mine:
                if not u["mac"]: errors.append(f"mac-only unit {u['name']} (line {u['start']+1}) is not wholly inside an OOLITE_MAC_OS_X arm: the fleet compiles it, so some slice converts it")
            report.append({"id": g["id"], "title": g["title"], "verbatim": False, "mac_only": True, "units": len(mine), "own": own, "read": 0,
                           "members": [u["name"] for u in mine]})
            continue
        h = hdr_shared + sum(decls.get(n, 0) for n in sorted(set(u["name"] for u in mine))) if (decls or hnames) else hdr
        if hnames:   # header-names: by-use (bead oo-9ht.154): the declarations the slice's units use, and theirs
            toks = set(re.findall(r"[A-Za-z_]\w*", " ".join(code_lines[k] for u in mine for k in range(u["start"], u["end"] + 1))))
            used = set(); grew = True
            while grew:
                grew = False
                for i, (_, declared, uses) in enumerate(hnames):
                    if i not in used and declared & toks: used.add(i); toks |= uses; grew = True
            h += sum(hnames[i][0] for i in used)
        read = h + preamble + own
        if not mine: empty.append(g["id"]); errors.append(f"slice {g['id']} is empty")
        if read >= max_read: errors.append(f"slice {g['id']} reads ~{read} lines (header {h} + preamble {preamble} + own {own}); must be under {max_read}")
        # one-unit-slices: frontier (bead oo-9ht.157): one method over --max-own is a frontier story
        frontier = bool(plan["one_unit_slices"]) and len(mine) == 1 and own > max_own
        if own > max_own and not frontier: errors.append(f"slice {g['id']} owns {own} lines of units; at most {max_own}" + ("" if len(mine) != 1 else " (one unit: see one-unit-slices: frontier)"))
        report.append({"id": g["id"], "title": g["title"], "verbatim": False, "mac_only": False, "units": len(mine), "own": own, "read": read,
                       "header": h, "frontier": frontier, "members": [u["name"] for u in mine]})
    return {"plan": plan, "retired": False, "missing": False, "units": units, "assign": assign, "shared": shared,
            "unassigned": unassigned, "empty": empty,
            "total": total, "preamble": preamble, "header_lines": hdr, "slices": report, "errors": errors,
            "warnings": warnings, "code_lines": code_lines, "raw_lines": raw_lines}

def unconverted(a, slice_id):
    """The units of slice `slice_id` that are still Objective-C: a method (it is still inside an
    @implementation block) or a function whose body still has Objective-C syntax. Empty means the
    slice is converted. A unit claimed by several slices counts for each of them."""
    out = []
    for i, u in enumerate(a["units"]):
        if a["assign"].get(i) != slice_id and slice_id not in a["shared"].get(i, ()): continue
        if u["kind"] == "method":
            out.append((u, f"still an Objective-C method in {u['block']}"))
        else:
            hits = objc_sites(a["code_lines"][u["start"]:u["end"]+1])
            if hits: out.append((u, f"Objective-C at line {u['start']+hits[0]+1}: {a['raw_lines'][u['start']+hits[0]].strip()[:90]}"))
    return out

def slice_done(plan_path, slice_id, base=ROOT):
    """A slice story's acceptance: 0 once none of the slice's units is Objective-C.

    Nonzero before the story (the slice owns at least one method or Objective-C function) and zero
    after it, whatever the other slices of the file still hold. Units are matched by the plan's
    entries, so a converted method (now a C++ member function outside @implementation) is no longer
    one of the slice's -[X sel] / @X(Cat) units."""
    a = analyse(plan_path, base=base); plan = a["plan"]
    if a["retired"]:
        print(f"OK {plan['source']}: absent, retired by {plan['retired_by']}; slice {slice_id} has nothing left"); return 0
    if a["missing"]:
        print(f"FAIL {plan['source']}: source file missing and the plan has no retired-by"); return 1
    if not any(g["id"] == slice_id and not g["verbatim"] and not g["mac_only"] for g in plan["groups"]):
        print(f"FAIL {plan_path}: no slice {slice_id!r}"); return 1
    left = unconverted(a, slice_id)
    for u, why in left: print(f"  not converted: {u['name']} (line {u['start']+1}): {why}")
    print(f"slice {slice_id} of {plan['source']}: " + ("converted" if not left else f"{len(left)} unit(s) still Objective-C"))
    return 1 if left else 0

def check(plan_path, max_read, max_own, as_json=False, show_units=False, base=ROOT):
    a = analyse(plan_path, max_read, max_own, base)
    plan = a["plan"]
    if a["retired"]:
        print(f"OK {plan['source']}: absent, retired by {plan['retired_by']}; nothing to slice")
        return 0
    if a["missing"]:
        print(f"FAIL {plan['source']}: source file missing and the plan has no retired-by"); return 1
    units, assign, report, errors, warnings = a["units"], a["assign"], a["slices"], a["errors"], a["warnings"]
    total, preamble, hdr = a["total"], a["preamble"], a["header_lines"]
    if as_json:
        print(json.dumps({"source": plan["source"], "header": plan["header"], "lines": total, "header_lines": hdr,
                          "preamble": preamble, "slices": report, "errors": errors, "warnings": warnings}, indent=1))
    else:
        print(f"{plan['source']}: {total} lines, {len(units)} units, preamble {preamble}, header {hdr}")
        for r in report:
            tag = "verbatim" if r["verbatim"] else "mac-only" if r["mac_only"] else f"slice {r['id']}"
            print(f"  {tag:>9}: {r['units']:3d} units, own {r['own']:4d}, reads ~{r['read']:4d}  {r['title']}" + ("  [frontier: one unit over --max-own]" if r.get("frontier") else ""))
        if show_units:
            for u in units:
                print(f"    {u['start']+1:5d}-{u['end']+1:5d} {u['end']-u['start']+1:4d}  {assign.get(units.index(u), '-'):>8}  {u['name']}")
        for w in warnings: print(f"  warning: {w}")
        for e in errors: print(f"  FAIL: {e}")
        print("OK" if not errors else f"FAIL ({len(errors)} problem(s))")
    return 1 if errors else 0

# ---------------------------------------------------------------- self-test
SELFTEST_SRC = r'''#import "Foo.h"
static const char *kTable[] = { "a{", "b}" };   // braces in strings do not count
@interface Foo (Private)
- (void) hidden;
@end
static int helper(int x)
{
	return x + 1;
}
@implementation Foo
// comment above init belongs to init
- (id) init
{
	if ((self = [super init])) { _x = helper(1); }
	return self;
}
- (void) setA:(int)a b:(oo::PList *)b { _x = a; }
@end
@implementation Foo (Private)
- (void) hidden
{
	[self log:@"}"];
}
@end
namespace {
int plainC(int y) { return y * 2; }
}
'''

def selftest():
    import tempfile
    d = tempfile.mkdtemp(prefix="slice-plan-selftest-", dir=os.path.join(ROOT, ".agent-tmp") if os.path.isdir(os.path.join(ROOT, ".agent-tmp")) else None)
    open(os.path.join(d, "Foo.mm"), "w").write(SELFTEST_SRC)
    open(os.path.join(d, "Foo.h"), "w").write("@interface Foo\n@end\n")
    units = parse_units(os.path.join(d, "Foo.mm"))[0]
    got = [u["name"] for u in units]
    want = ["helper()", "-[Foo init]", "-[Foo setA:b:]", "-[Foo hidden]", "plainC()"]
    fails = []
    if got != want: fails.append(f"units {got} != {want}")
    # a method defined with a stray ';' before its body (legal Objective-C; SDL/MyOpenGLView.mm has one)
    open(os.path.join(d, "Semi.mm"), "w").write("@implementation Foo\n- (void) adjust:(float)x;\n{\n\t_x += x;\n}\nstatic int n;\n- (int) n { return n; }\n@end\n")
    got = [u["name"] for u in parse_units(os.path.join(d, "Semi.mm"))[0]]
    if got != ["-[Foo adjust:]", "-[Foo n]"]: fails.append(f"stray-semicolon method: units {got}")
    def run(body, expect):
        p = os.path.join(d, "plan.md")
        open(p, "w").write("x\n```slice-plan\nsource: Foo.mm\nheader: Foo.h\n" + body + "```\n")
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf): r = check(p, 1500, 800, base=d)
        if r != expect: fails.append(f"plan exit {r} != {expect}:\n{body}\n{buf.getvalue()}")
    good = "slice 1: shell\n  -[Foo init]\n  -[Foo set*]\n  helper()\nslice 2: private\n  @Foo(Private)\nverbatim: C\n  plainC()\n"
    run(good, 0)
    run(good.replace("  plainC()\n", ""), 1)                               # a unit left out
    run(good + "slice 3: dup\n  -[Foo init]\n", 1)                          # a unit in two slices
    run(good.replace("verbatim: C\n  plainC()\n", "verbatim: C\n  plainC()\n  @Foo(Private)\n").replace("slice 2: private\n  @Foo(Private)\n", "slice 2: p\n  -[Foo nothing]\n"), 1)  # ObjC in verbatim (+ empty slice)
    run(good.replace("-[Foo init]", "@Foo"), 0)                              # a whole block
    run(good + "slice 3: tiers\n  @Foo(Private)\n", 1)                      # one block in two slices
    run(good.replace("  -[Foo init]\n", "  @Foo\n").replace("  -[Foo set*]\n", "") + "slice 3: one method\n  -[Foo set*]\n", 0)  # a name beats a block
    run(good.replace("  plainC()\n", "  *\n"), 0)                           # a catch-all verbatim
    run(good.replace("  plainC()\n", "  plainC()\n  -[Foo hidden]\n"), 1)   # a method is never verbatim
    p = os.path.join(d, "gone.md"); open(p, "w").write("```slice-plan\nsource: Gone.mm\nretired-by: oo-x\nslice 1: all\n  *\n```\n")
    import io, contextlib
    with contextlib.redirect_stdout(io.StringIO()):
        if check(p, 1500, 800, base=d) != 0: fails.append("retired absent source should pass")
    with contextlib.redirect_stdout(io.StringIO()):
        if check(os.path.join(d, "plan.md"), 10, 800, base=d) != 1: fails.append("read budget not enforced")
    # --slice-done: nonzero while a slice's units are Objective-C, zero once they are C++
    open(os.path.join(d, "plan.md"), "w").write("x\n```slice-plan\nsource: Foo.mm\nheader: Foo.h\n" + good + "```\n")
    def done(sid):
        with contextlib.redirect_stdout(io.StringIO()): return slice_done(os.path.join(d, "plan.md"), sid, base=d)
    if done("1") != 1 or done("2") != 1: fails.append("slice-done passed before conversion")
    if done("9") != 1: fails.append("slice-done accepted an unknown slice id")
    if done("verbatim") != 1: fails.append("slice-done accepted the verbatim group as a slice")
    private = '@implementation Foo (Private)\n- (void) hidden\n{\n\t[self log:@"}"];\n}\n@end\n'
    converted = SELFTEST_SRC.replace(private, 'void Foo::hidden()\n{\n\too::log("}");\n}\n')
    if converted == SELFTEST_SRC: fails.append("selftest fixture edit did not apply")
    open(os.path.join(d, "Foo.mm"), "w").write(converted)
    if done("2") != 0: fails.append("slice-done failed after slice 2 was converted")
    if done("1") != 1: fails.append("slice-done passed slice 1, which is still Objective-C")
    open(os.path.join(d, "Foo.mm"), "w").write(SELFTEST_SRC.replace("\treturn x + 1;", "\treturn [Foo bar:x];"))
    if not any(u["name"] == "helper()" for u, _ in unconverted(analyse(os.path.join(d, "plan.md"), base=d), "1")):
        fails.append("slice-done missed Objective-C inside a slice's C function")
    # mac-only (bead oo-q9l2w): a unit wholly inside an OOLITE_MAC_OS_X arm is not converted and gets no
    # story; a unit outside one (or in its #else) cannot be mac-only
    open(os.path.join(d, "Mac.mm"), "w").write("@implementation Foo\n- (void) a { }\n#if OOLITE_MAC_OS_X\n- (void) m { [x y]; }\n#else\n- (void) e { }\n#endif\n@end\n"
                                               "#if OO_DEBUG\n#ifdef OOLITE_MAC_OS_X\nstatic void mf(void) { [x y]; }\n#endif\n#endif\n#if !OOLITE_MAC_OS_X\nstatic void nf(void) { }\n#endif\n")
    mac = {u["name"]: u["mac"] for u in parse_units(os.path.join(d, "Mac.mm"))[0]}
    if mac != {"-[Foo a]": False, "-[Foo m]": True, "-[Foo e]": False, "mf()": True, "nf()": False}: fails.append(f"mac arms: {mac}")
    def macplan(body, expect):
        p = os.path.join(d, "mac.md"); open(p, "w").write("```slice-plan\nsource: Mac.mm\n" + body + "```\n")
        with contextlib.redirect_stdout(io.StringIO()): r = check(p, 1500, 800, base=d)
        if r != expect: fails.append(f"mac plan exit {r} != {expect}:\n{body}")
        return p
    mp = macplan("slice 1: all\n  -[Foo a]\n  -[Foo e]\n  nf()\nmac-only: Mac\n  -[Foo m]\n  mf()\n", 0)
    a = analyse(mp, base=d)
    if [r["id"] for r in a["slices"] if not r["verbatim"] and not r["mac_only"]] != ["1"]: fails.append("mac-only reported as a slice")
    with contextlib.redirect_stdout(io.StringIO()):
        if slice_done(mp, "mac-only", base=d) != 1: fails.append("slice-done accepted the mac-only group as a slice")
    open(os.path.join(d, "Arms.mm"), "w").write("@implementation Foo\n#if OOLITE_MAC_OS_X\n- (void) t { [x y]; }\n#else\n- (void) t { }\n#endif\n@end\n"
                                                "#if OOLITE_MAC_OS_X\n@implementation Foo (Mac)\n- (void) u { [x y]; }\n@end\n#endif\n")
    p = os.path.join(d, "arms.md"); open(p, "w").write("```slice-plan\nsource: Arms.mm\nslice 1: t\n  -[Foo t]\nmac-only: Mac\n  -[Foo t]\n  @Foo(Mac)\n```\n")
    a = analyse(p, base=d)   # the exact name in slice 1 takes only the compiled arm; the Mac arm stays Mac
    if a["errors"] or sorted(a["assign"].values()) != ["1", "mac-only", "mac-only"]: fails.append(f"mac arm of a sliced method: {a['errors']} {a['assign']}")
    macplan("slice 1: all\n  -[Foo a]\n  nf()\nmac-only: Mac\n  -[Foo m]\n  -[Foo e]\n  mf()\n", 1)   # the #else arm is compiled
    macplan("slice 1: all\n  -[Foo e]\n  -[Foo m]\n  mf()\nmac-only: Mac\n  -[Foo a]\n  nf()\n", 1)    # outside any arm / #if !MAC
    # a landed class-shell slice (oo-9ht.117): its converted out-of-line members fall to the verbatim
    # catch-all and may still message Objective-C objects; a plain function that does still fails
    landed = SELFTEST_SRC.replace(private, 'void Foo::hidden()\n{\n\t[_delegate log:@"}"];\n\t@try { x(); } @catch (id e) { }\n}\n')
    if landed == SELFTEST_SRC: fails.append("selftest landed-slice fixture edit did not apply")
    open(os.path.join(d, "Foo.mm"), "w").write(landed)
    rest = "slice 1: shell\n  -[Foo init]\n  -[Foo set*]\n  helper()\nverbatim: C\n  *\n"
    run(rest, 0)                                                              # converted member in verbatim
    open(os.path.join(d, "Foo.mm"), "w").write(landed.replace("int plainC(int y) { return y * 2; }", "int plainC(int y) { return [Foo twice:y]; }"))
    run(rest, 1)                                                              # a plain function still may not
    # header-decls: per-slice (bead oo-9ht.140): a slice is charged the header less its method
    # declarations, plus its own units' declarations (with their doc comments)
    open(os.path.join(d, "Foo.mm"), "w").write(SELFTEST_SRC)
    open(os.path.join(d, "Foo.h"), "w").write("#define X 1\n@interface Foo : Bar\n{\n\tint _x;\n\t- not a decl;\n}\n"
                                              "- (id) init;\n/* doc */\n- (void) setA:(int)a\n\tb:(oo::PList *)b;\n\n- (void) gone;\n"
                                              "#define M(x) do { \\n- (void) notOne; \\n} while (0)\n@end\n@interface Foo (Private)\n- (void) hidden;\n@end\n")
    hl, hd = header_decls(os.path.join(d, "Foo.h"))
    if hl != 17 or hd != {"-[Foo init]": 1, "-[Foo setA:b:]": 3, "-[Foo gone]": 1, "-[Foo hidden]": 1}: fails.append(f"header decls: {hl} {hd}")
    p = os.path.join(d, "hd.md"); open(p, "w").write("```slice-plan\nsource: Foo.mm\nheader: Foo.h\nheader-decls: per-slice\n" + good + "```\n")
    hr = {r["id"]: r.get("header") for r in analyse(p, base=d)["slices"] if not r["verbatim"]}
    if hr != {"1": 11 + 1 + 3, "2": 11 + 1}: fails.append(f"header-decls charges: {hr}")
    open(p, "w").write("```slice-plan\nsource: Foo.mm\nheader-decls: per-slice\n" + good + "```\n")
    try:
        analyse(p, base=d); fails.append("header-decls without a header accepted")
    except SystemExit: pass
    # header-names: by-use (bead oo-9ht.154): a slice is charged the declarations its units use
    open(os.path.join(d, "Iv.h"), "w").write(
        "#import \"Bar.h\"\n#define X 1\n#define Y(a) \\\n\t((a) + X)\n// doc\ntypedef enum\n{\n\tkA = 1,\n#if B\n\tkB,\n#endif\n} OOMode;\n"
        "inline constexpr std::string_view KEY = \"k\";\n@interface Foo : Bar\n{\n@private\n\tint _x, _y;\n\t// doc\n"
        "\tstd::map<int, std::vector<int>> _m;\n#if A\n\tunsigned _f: 1;\n#endif\n\tOOMode _buf[4];\n}\n- (id) init;\n@end\n"
        "OOINLINE Foo *GetFoo(void)\n{\n\treturn Y(gFoo);\n}\nstd::string cxx_Name(int x);\n")
    got = {frozenset(n): (k, frozenset(u)) for k, n, u in header_names(os.path.join(d, "Iv.h"))}
    want = {frozenset({"X"}): (1, frozenset()), frozenset({"Y"}): (2, frozenset({"a", "X"})),
            frozenset({"kA", "kB", "OOMode"}): (8, frozenset({"typedef", "enum"})),
            frozenset({"KEY"}): (1, frozenset({"inline", "constexpr", "std", "string_view"})),
            frozenset({"_x", "_y"}): (1, frozenset({"int"})), frozenset({"_m"}): (2, frozenset({"std", "map", "int", "vector"})),
            frozenset({"_f"}): (1, frozenset({"unsigned"})), frozenset({"_buf"}): (1, frozenset({"OOMode"})),
            frozenset({"GetFoo"}): (4, frozenset({"OOINLINE", "Foo", "void", "return", "Y", "gFoo"})),
            frozenset({"cxx_Name"}): (1, frozenset({"std", "string", "int", "x"}))}
    if got != want: fails.append(f"header names: {got}")
    p = os.path.join(d, "iv.md"); open(p, "w").write("```slice-plan\nsource: Foo.mm\nheader: Iv.h\nheader-decls: per-slice\nheader-names: by-use\n" + good + "```\n")
    hr = {r["id"]: r.get("header") for r in analyse(p, base=d)["slices"] if not r["verbatim"]}
    shared = 31 - 1 - sum(k for k, _ in want.values())    # 31 lines less init's declaration and the declarations
    if hr != {"1": shared + 1 + 1, "2": shared}: fails.append(f"header-names charges: {hr} (shared {shared})")   # slice 1: init's decl, and it names _x
    open(os.path.join(d, "Foo.mm"), "w").write(SELFTEST_SRC.replace("_x = helper(1);", "_buf[0] = GetFoo();"))
    hr = {r["id"]: r.get("header") for r in analyse(p, base=d)["slices"] if not r["verbatim"]}
    if hr["1"] != shared + 1 + 1 + 1 + 8 + 4 + 2 + 1: fails.append(f"header-names closure: {hr}")   # _x (setA:b:), _buf -> OOMode; GetFoo -> Y -> X
    open(os.path.join(d, "Foo.mm"), "w").write(SELFTEST_SRC)
    open(p, "w").write("```slice-plan\nsource: Foo.mm\nheader-names: by-use\n" + good + "```\n")
    try:
        analyse(p, base=d); fails.append("header-names without a header accepted")
    except SystemExit: pass
    # one-unit-slices: frontier (bead oo-9ht.157): a one-unit slice over --max-own passes with the
    # key and is reported frontier; without the key, or for a slice of two units, it still fails
    def own_check(body, max_own):
        open(p, "w").write("```slice-plan\nsource: Foo.mm\n" + body + "```\n")
        with contextlib.redirect_stdout(io.StringIO()): r = check(p, 1500, max_own, base=d)
        return r, {x["id"]: x.get("frontier") for x in analyse(p, 1500, max_own, base=d)["slices"] if not x["verbatim"]}
    one = "slice 1: init\n  -[Foo init]\nslice 2: set\n  -[Foo set*]\n  helper()\nslice 3: private\n  @Foo(Private)\nverbatim: C\n  plainC()\n"
    two = "slice 1: init and set\n  -[Foo init]\n  -[Foo set*]\nslice 2: helper\n  helper()\nslice 3: private\n  @Foo(Private)\nverbatim: C\n  plainC()\n"
    if own_check(one, 5)[0] != 1: fails.append("a one-unit slice over --max-own passed without one-unit-slices")
    got = own_check("one-unit-slices: frontier\n" + one, 5)
    if got != (0, {"1": True, "2": False, "3": False}): fails.append(f"one-unit-slices: frontier: {got}")
    if own_check("one-unit-slices: frontier\n" + two, 5)[0] != 1: fails.append("one-unit-slices exempted a slice of two units")
    open(p, "w").write("```slice-plan\nsource: Foo.mm\none-unit-slices: yes\n" + good + "```\n")
    try:
        analyse(p, base=d); fails.append("one-unit-slices: yes accepted")
    except SystemExit: pass
    import shutil; shutil.rmtree(d, ignore_errors=True)
    for f in fails: print("SELFTEST FAIL:", f)
    print("selftest OK" if not fails else "selftest FAILED")
    return 1 if fails else 0

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("plans", nargs="*")
    ap.add_argument("--max-read", type=int, default=1500)
    ap.add_argument("--max-own", type=int, default=800)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--units", action="store_true", help="also list every unit with its slice")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--slice-done", metavar="ID", help="exit 0 iff slice ID of the one plan given has no Objective-C unit left (a slice story's acceptance)")
    ap.add_argument("--dump", metavar="SOURCE", help="list the units of a source file (to write a plan from)")
    a = ap.parse_args()
    if a.selftest: return selftest()
    if a.dump:
        units, pre, total, code_lines, _ = parse_units(a.dump)
        print(f"{a.dump}: {total} lines, {len(units)} units, preamble {pre}")
        for u in units:
            objc = "objc" if objc_sites(code_lines[u["start"]:u["end"]+1]) else "C"
            print(f"{u['start']+1:5d}-{u['end']+1:5d} {u['end']-u['start']+1:4d} {objc:4} {u['block']:28} {u['name']}")
        return 0
    if not a.plans: ap.error("give at least one plan, or --selftest")
    if a.slice_done is not None:
        if len(a.plans) != 1: ap.error("--slice-done takes exactly one plan")
        return slice_done(a.plans[0], a.slice_done)
    rc = 0
    for p in a.plans: rc |= check(p, a.max_read, a.max_own, a.json, a.units)
    return rc

if __name__ == "__main__":
    sys.exit(main())
