#!/usr/bin/env python3
"""
js_stubs.py -- mechanical JS_* -> ooscript façade rewrite for the "stub /
init / numeric-conversion" pattern family.

Covers exactly the call-site patterns hand-retargeted in OOJSVector.mm
(bead oo-sdz, the seam exemplar for bead oo-oio):

  * JS_PropertyStub / JS_EnumerateStub / JS_ResolveStub / JS_ConvertStub
    (the JSClass hook-stub family) -> nullptr, wherever they appear as a
    bare token (e.g. as a JSClass/ClassDef initializer field). These have
    no façade call: a nullptr hook is the stub (ooscript::ClassDef,
    JSEngine.hpp; see ooscript/README.md).

  * JS_InitClass(cx, global, parent, clasp, ctor, nargs, ps, fs,
    static_ps, static_fs) call, when its result is assigned directly to a
    variable ("proto = JS_InitClass(...);"), rewritten to the two-line
    ooscript::initClass(...) + OOJSROBJ(...) façade form.

  * JS_NewNumberValue(cx, double, jsval*) -> ooscript::newNumberValue(...)
  * JS_ValueToNumber(cx, jsval, double*)  -> ooscript::valueToNumber(...)
  * JS_ValueToBoolean(cx, jsval, JSBool*) -> ooscript::valueToBoolean(...)

    For these three, the façade takes ooscript::Context/Value, not the raw
    jsapi JSContext*/jsval; call-site arguments of jsapi type are wrapped
    with the byte-identical façade views (OOJSFCX/OOJSFVAL/OOJSFVALP) the
    same way OOJSVector.mm's retarget does it. Arguments already spelled
    "cx" are assumed to already be façade Context values and are left
    alone; every other context expression is wrapped. jsval-typed value
    arguments are detected from `jsval` declarations/parameters found
    earlier in the same file (locals, parameters, and jsval* pointers
    subscripted with []); anything not recognised as jsval-typed (e.g. a
    dereferenced façade Value*, or a plain double) is left untouched,
    which is always the conservative, safe choice.

This script does NOT touch anything else: it does not retype JSClass to
ClassDef, does not rename `this`/`private` to `thisObj`/`priv`, does not
touch the OOJS_* macros, and does not add the shim helper functions that a
full per-file retarget needs. Those remain later, file-specific bead work;
this script only removes the ~40% of call sites in this pattern family so
that work is mechanical, not manual.
"""
import argparse
import re
import sys


STUB_TOKENS = (
    "JS_PropertyStub",
    "JS_EnumerateStub",
    "JS_ResolveStub",
    "JS_ConvertStub",
)

NUMERIC_FUNCS = ("JS_NewNumberValue", "JS_ValueToNumber", "JS_ValueToBoolean")
FACADE_NUMERIC = {
    "JS_NewNumberValue": "ooscript::newNumberValue",
    "JS_ValueToNumber": "ooscript::valueToNumber",
    "JS_ValueToBoolean": "ooscript::valueToBoolean",
}


def find_jsval_names(text):
    """Return (scalar_names, pointer_names): jsval identifiers declared as
    plain scalars vs. as pointers/arrays (whose subscript is a scalar
    jsval). Best-effort regex scan; false negatives just mean we leave an
    argument unwrapped (safe), never mis-wrap something we didn't see."""
    scalars = set()
    pointers = set()
    for m in re.finditer(r"\bjsval\b([^;()]*);", text):
        decl = m.group(1)
        for part in decl.split(","):
            part = part.strip()
            if not part:
                continue
            starcount = part.count("*")
            part = part.replace("*", " ")
            part = re.sub(r"\[[^\]]*\]", "", part)
            name_match = re.search(r"(\w+)\s*$", part)
            if not name_match:
                continue
            name = name_match.group(1)
            if starcount > 0:
                pointers.add(name)
            else:
                scalars.add(name)
    # jsval params inside function argument lists, e.g. "jsval *vp" or
    # "jsval argv[]" or "jsval v" -- declared without a trailing ';'.
    for m in re.finditer(r"\bjsval\s*(\**)\s*(\w+)\s*(\[\s*\])?", text):
        stars, name, is_array = m.group(1), m.group(2), m.group(3)
        if stars or is_array:
            pointers.add(name)
        else:
            scalars.add(name)
    return scalars, pointers


def wrap_ctx(expr):
    expr = expr.strip()
    if expr == "cx":
        return "cx"
    return f"OOJSFCX({expr})"


def wrap_val_if_jsval(expr, scalars, pointers):
    e = expr.strip()
    bare = re.match(r"^(\w+)$", e)
    if bare and bare.group(1) in scalars:
        return f"OOJSFVAL({e})"
    sub = re.match(r"^(\w+)\s*\[\s*[^\]]*\s*\]$", e)
    if sub and sub.group(1) in pointers:
        return f"OOJSFVAL({e})"
    return e


def wrap_ptr_if_jsval(expr, scalars, pointers):
    e = expr.strip()
    addr = re.match(r"^&\s*(\w+)$", e)
    if addr and addr.group(1) in scalars:
        return f"OOJSFVALP({e})"
    bare = re.match(r"^(\w+)$", e)
    if bare and bare.group(1) in pointers:
        return f"OOJSFVALP({e})"
    return e


def split_top_level_args(s):
    """Split a call's argument text on top-level commas (respecting
    nested parens/brackets); tolerant of the simple expressions found in
    these call sites."""
    args = []
    depth = 0
    cur = []
    for ch in s:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == "," and depth == 0:
            args.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    args.append("".join(cur))
    return [a.strip() for a in args if a.strip() != ""] or [""]


def find_call(text, start, func_name):
    """Locate `func_name(...)` starting at or after `start`; return
    (call_start, args_start, args_end_exclusive_of_paren) or None."""
    idx = text.find(func_name + "(", start)
    if idx == -1:
        return None
    args_start = idx + len(func_name) + 1
    depth = 1
    i = args_start
    while i < len(text) and depth > 0:
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
        i += 1
    args_end = i - 1
    return idx, args_start, args_end


def rewrite_stub_tokens(text):
    count = 0

    def sub(m):
        nonlocal count
        count += 1
        return "nullptr"

    for tok in STUB_TOKENS:
        text = re.sub(r"\b" + tok + r"\b", sub, text)
    return text, count


def rewrite_init_class(text):
    count = 0
    out = []
    pos = 0
    pattern = re.compile(r"(?P<lhs>\b\w+)\s*=\s*JS_InitClass\s*\(")
    while True:
        m = pattern.search(text, pos)
        if not m:
            out.append(text[pos:])
            break
        call = find_call(text, m.start(), "JS_InitClass")
        if not call:
            out.append(text[pos:m.end()])
            pos = m.end()
            continue
        call_start, args_start, args_end = call
        # trailing ';' right after the call's closing paren
        tail = args_end
        if tail < len(text) and text[tail] == ")":
            pass
        semi_end = args_end + 1
        if semi_end < len(text) and text[semi_end] == ";":
            semi_end += 1
        args_text = text[args_start:args_end]
        args = split_top_level_args(args_text)
        if len(args) != 10:
            # Not the plain 10-argument form we know how to rewrite;
            # leave it untouched.
            out.append(text[pos:semi_end])
            pos = semi_end
            continue
        cx_a, global_a, parent_a, clasp_a, ctor_a, nargs_a, ps_a, fs_a, sps_a, sfs_a = args

        def wrap_obj(a):
            a = a.strip()
            if a in ("NULL", "nullptr"):
                return "nullptr"
            return f"OOJSFOBJ({a})"

        new_cx = wrap_ctx(cx_a)
        new_global = wrap_obj(global_a)
        new_parent = wrap_obj(parent_a)
        lhs = m.group("lhs")
        indent_match = re.search(r"[ \t]*$", text[:m.start()].split("\n")[-1])
        indent = indent_match.group(0) if indent_match else ""
        replacement = (
            f"Object proto = ooscript::initClass({new_cx}, {new_global}, {new_parent}, "
            f"{clasp_a}, {ctor_a}, {nargs_a}, {ps_a}, {fs_a}, "
            f"{sps_a}, {sfs_a});\n{indent}{lhs} = OOJSROBJ(proto);"
        )
        out.append(text[pos:m.start()])
        out.append(replacement)
        pos = semi_end
        count += 1
    return "".join(out), count


def rewrite_numeric(text, scalars, pointers):
    count = 0
    out = []
    pos = 0
    pattern = re.compile(r"\b(" + "|".join(NUMERIC_FUNCS) + r")\s*\(")
    while True:
        m = pattern.search(text, pos)
        if not m:
            out.append(text[pos:])
            break
        func = m.group(1)
        call = find_call(text, m.start(), func)
        if not call:
            out.append(text[pos:m.end()])
            pos = m.end()
            continue
        call_start, args_start, args_end = call
        args_text = text[args_start:args_end]
        args = split_top_level_args(args_text)
        if len(args) != 3:
            out.append(text[pos:args_end + 1])
            pos = args_end + 1
            continue
        cx_a, val_a, ptr_a = args
        new_cx = wrap_ctx(cx_a)
        if func == "JS_NewNumberValue":
            new_val = val_a.strip()
            new_ptr = wrap_ptr_if_jsval(ptr_a, scalars, pointers)
        elif func == "JS_ValueToNumber":
            new_val = wrap_val_if_jsval(val_a, scalars, pointers)
            new_ptr = ptr_a.strip()
        else:  # JS_ValueToBoolean
            new_val = wrap_val_if_jsval(val_a, scalars, pointers)
            new_ptr = ptr_a.strip()
        replacement = f"{FACADE_NUMERIC[func]}({new_cx}, {new_val}, {new_ptr})"
        out.append(text[pos:m.start()])
        out.append(replacement)
        pos = args_end + 1
        count += 1
    return "".join(out), count


def transform(text):
    scalars, pointers = find_jsval_names(text)
    text, n_numeric = rewrite_numeric(text, scalars, pointers)
    text, n_init = rewrite_init_class(text)
    text, n_stub = rewrite_stub_tokens(text)
    counts = {
        "stub_tokens": n_stub,
        "init_class": n_init,
        "numeric_calls": n_numeric,
    }
    return text, counts


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("path", help="source file to rewrite in place (or - for stdin/stdout)")
    ap.add_argument("--dry-run", action="store_true", help="print counts only, do not write")
    ap.add_argument("--stdout", action="store_true", help="print rewritten text to stdout instead of writing the file")
    args = ap.parse_args(argv)

    if args.path == "-":
        text = sys.stdin.read()
    else:
        with open(args.path, "r", encoding="utf-8", newline="") as f:
            text = f.read()

    new_text, counts = transform(text)

    total = sum(counts.values())
    sys.stderr.write(
        "js-stubs: stub_tokens=%d init_class=%d numeric_calls=%d (total=%d)\n"
        % (counts["stub_tokens"], counts["init_class"], counts["numeric_calls"], total)
    )

    if args.dry_run:
        return 0

    if args.stdout or args.path == "-":
        sys.stdout.write(new_text)
    else:
        with open(args.path, "w", encoding="utf-8", newline="") as f:
            f.write(new_text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
