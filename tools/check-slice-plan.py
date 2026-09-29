#!/usr/bin/env python3
"""Check a Phase 3 pre-split slice plan against the file it splits.

A slice plan (docs/phases/3-slices/<File>.md) says which methods and functions of one Objective-C++
file go into which conversion story ("slice"), so that each story reads under the 1,500-line story
budget (docs/phases/3-cpp-conversion.md, seam "Pre-splitting files > 400 lines"; docs/templates/story.md).
The plan is the markdown file's single fenced block tagged `slice-plan`:

    source: upstream/oolite/src/Core/Foo.mm      # the file being split (required)
    header: upstream/oolite/src/Core/Foo.h       # its header; every slice reads it (optional)
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
  * each slice's own units total at most --max-own lines (default 800): converting a method
    rewrites roughly half its lines, so this keeps a story near the ~400-lines-written budget;
  * no verbatim unit contains Objective-C (message send, @"...", @selector, @try, ...).
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
    for ln, line in enumerate(code_lines):
        s = line.strip()
        if pp or s.startswith("#"):   # directives never count braces (#define bodies, #if arms)
            pp = line.rstrip().endswith("\\")
            continue
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
                               "block": "@" + impl, "kind": "method", "start": buf_line}
                        stack.append("body")
                    elif re.match(r"^(namespace\b[^{]*|extern\s*\"C\"\s*)$", head):
                        stack.append("ns")
                    elif head and not NOT_FUNC.search(head) and FUNC_NAME.search(head):
                        name = FUNC_NAME.search(head).group(1)
                        mac = re.fullmatch(r"([A-Z][A-Z0-9_]+)\s*\(([^()]*)\)", head)
                        name = f"{mac.group(1)}({mac.group(2).strip()})" if mac else name.split("::")[-1] + "()"
                        cur = {"name": name, "block": "@" + impl if impl else "", "kind": "function", "start": buf_line}
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
                buf = []; buf_line = None
            elif eff() == 0 and cur is None:
                if buf_line is None and not ch.isspace(): buf_line = ln
                if buf_line is not None: buf.append(ch)
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

# ---------------------------------------------------------------- plan
def read_plan(path):
    text = open(path, encoding="utf-8").read()
    m = re.search(r"^```slice-plan[ \t]*\n(.*?)^```", text, re.S | re.M)
    if not m: raise SystemExit(f"{path}: no ```slice-plan fenced block")
    plan = {"source": None, "header": None, "retired_by": None, "groups": []}
    group = None
    for raw in m.group(1).splitlines():
        line = raw.split("#", 1)[0].rstrip() if not raw.lstrip().startswith("#") else ""
        if not line.strip(): continue
        s = line.strip()
        kv = re.match(r"(source|header|retired-by):\s*(\S+)$", s)
        if kv and not raw[:1].isspace():
            plan[kv.group(1).replace("-", "_")] = kv.group(2); continue
        g = re.match(r"slice\s+(\w+)\s*:\s*(.*)$", s)
        if g and not raw[:1].isspace():
            group = {"id": g.group(1), "title": g.group(2), "verbatim": False, "entries": []}; plan["groups"].append(group); continue
        v = re.match(r"verbatim\s*:\s*(.*)$", s)
        if v and not raw[:1].isspace():
            group = {"id": "verbatim", "title": v.group(1), "verbatim": True, "entries": []}; plan["groups"].append(group); continue
        if group is None: raise SystemExit(f"{path}: entry before any slice: {s!r}")
        group["entries"].append(s)
    if not plan["source"]: raise SystemExit(f"{path}: plan has no 'source:'")
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
    names = [u["name"] for u in units]
    for n in sorted(set(x for x in names if names.count(x) > 1)):
        warnings.append(f"unit name {n} occurs {names.count(n)} times (preprocessor alternatives?); each copy is assigned the same way")
    assign = {}; shared = {}; unassigned = []; empty = []
    for i, u in enumerate(units):
        best = None; owners = set()
        for g in plan["groups"]:
            for e in g["entries"]:
                if entry_matches(e, u):
                    t = entry_tier(e)
                    if best is None or t < best: best, owners = t, {g["id"]}
                    elif t == best: owners.add(g["id"])
        if not owners: unassigned.append(i); errors.append(f"unassigned: {u['name']} (line {u['start']+1}-{u['end']+1}, {u['end']-u['start']+1} lines)")
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
                hits = objc_sites(code_lines[u["start"]:u["end"]+1])
                if hits: errors.append(f"verbatim unit {u['name']} contains Objective-C at line {u['start']+hits[0]+1}: {raw_lines[u['start']+hits[0]].strip()[:90]}")
            report.append({"id": g["id"], "title": g["title"], "verbatim": True, "units": len(mine), "own": own, "read": 0,
                           "members": [u["name"] for u in mine]})
            continue
        read = hdr + preamble + own
        if not mine: empty.append(g["id"]); errors.append(f"slice {g['id']} is empty")
        if read >= max_read: errors.append(f"slice {g['id']} reads ~{read} lines (header {hdr} + preamble {preamble} + own {own}); must be under {max_read}")
        if own > max_own: errors.append(f"slice {g['id']} owns {own} lines of units; at most {max_own}")
        report.append({"id": g["id"], "title": g["title"], "verbatim": False, "units": len(mine), "own": own, "read": read,
                       "members": [u["name"] for u in mine]})
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
    if not any(g["id"] == slice_id and not g["verbatim"] for g in plan["groups"]):
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
            tag = "verbatim" if r["verbatim"] else f"slice {r['id']}"
            print(f"  {tag:>9}: {r['units']:3d} units, own {r['own']:4d}, reads ~{r['read']:4d}  {r['title']}")
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
	NSLog(@"}");
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
    private = '@implementation Foo (Private)\n- (void) hidden\n{\n\tNSLog(@"}");\n}\n@end\n'
    converted = SELFTEST_SRC.replace(private, 'void Foo::hidden()\n{\n\too::log("}");\n}\n')
    if converted == SELFTEST_SRC: fails.append("selftest fixture edit did not apply")
    open(os.path.join(d, "Foo.mm"), "w").write(converted)
    if done("2") != 0: fails.append("slice-done failed after slice 2 was converted")
    if done("1") != 1: fails.append("slice-done passed slice 1, which is still Objective-C")
    open(os.path.join(d, "Foo.mm"), "w").write(SELFTEST_SRC.replace("\treturn x + 1;", "\treturn [Foo bar:x];"))
    if not any(u["name"] == "helper()" for u, _ in unconverted(analyse(os.path.join(d, "plan.md"), base=d), "1")):
        fails.append("slice-done missed Objective-C inside a slice's C function")
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
