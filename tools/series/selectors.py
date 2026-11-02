"""Upstream's Objective-C selector renames (#745), applied to history snapshots before merging.

Upstream PR #745 ("Add missing selectors") named the unnamed parts of about twenty selectors
(`initWithColors::andSystemInfo:` -> `initWithColors:col2:andSystemInfo:`) and renamed a few named
parts (`andIJK:` -> `i:`). The history kept the old spellings. Rewriting them in the history's
snapshots makes the merge see upstream's names on both sides, so no conflict is caused by naming
alone and the history's new files (bridge headers, say) come in with upstream's names.

rename_selectors(text, table) rewrites declarations, definitions, message sends and @selector()
literals whose full selector is a key of `table` (old full selector -> new full selector, e.g.
"initWithColors::andSystemInfo:" -> "initWithColors:col2:andSystemInfo:"). It changes nothing else.
"""
import re

IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def _skip_ws_comments(s, i):
    n = len(s)
    while i < n:
        if s[i].isspace():
            i += 1
        elif s.startswith("//", i):
            j = s.find("\n", i)
            i = n if j < 0 else j + 1
        elif s.startswith("/*", i):
            j = s.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            break
    return i


def _skip_literal(s, i):
    """i at a quote (" or '); returns index after the literal."""
    q = s[i]
    i += 1
    while i < len(s):
        if s[i] == "\\":
            i += 2
            continue
        if s[i] == q:
            return i + 1
        if s[i] == "\n" and q == "'":
            return i
        i += 1
    return i


def _parse_send_arg(s, i):
    """Scan one message argument starting at i. Returns (end, kind, name_start, name_end) where kind
    is "unnamed" (a bare ':' follows), "named" (an `ident:` follows), or "end" (']' closes)."""
    depth, n, start, question = 0, len(s), i, 0
    while i < n:
        c = s[i]
        if c in "\"'":
            i = _skip_literal(s, i)
            continue
        if s.startswith("//", i) or s.startswith("/*", i):
            i = _skip_ws_comments(s, i)
            continue
        if c in "([{":
            depth += 1
        elif c in ")}":
            depth -= 1
            if depth < 0:
                return i, "end", None, None
        elif c == "]":
            if depth == 0:
                return i, "end", None, None
            depth -= 1
        elif c == ";" and depth == 0:
            return i, "end", None, None
        elif c == ":" and s.startswith("::", i):  # C++ scope, not a selector part
            i += 2
            continue
        elif c == "?" and depth == 0:
            question += 1
        elif c == ":" and depth == 0:
            if question:
                question -= 1
                i += 1
                continue
            # `expr name:` is a named part; `expr:` / `expr :` is an unnamed one
            j = i
            while j > start and (s[j - 1].isalnum() or s[j - 1] == "_"):
                j -= 1
            if j < i and j > start and s[j - 1].isspace() and s[start:j].strip():
                return j, "named", j, i
            return i, "unnamed", None, None
        i += 1
    return i, "end", None, None


def _parse_decl_arg(s, i):
    """At i after 'piece:' in a method declaration: skip `(Type)name`. Returns index after name."""
    i = _skip_ws_comments(s, i)
    if i < len(s) and s[i] == "(":
        depth = 0
        while i < len(s):
            if s[i] == "(":
                depth += 1
            elif s[i] == ")":
                depth -= 1
                if depth == 0:
                    i += 1
                    break
            i += 1
    i = _skip_ws_comments(s, i)
    m = IDENT.match(s, i)
    return m.end() if m else i


def _decl_parts(s, i):
    """Parts after the first `piece:(T)name` of a declaration. Returns a list of
    (name or "", name_start, colon_index)."""
    parts = []
    while True:
        j = _skip_ws_comments(s, i)
        if j < len(s) and s[j] == ":":
            parts.append(("", j, j))
            i = _parse_decl_arg(s, j + 1)
            continue
        m = IDENT.match(s, j)
        if m and m.end() < len(s) and s[m.end()] == ":":
            parts.append((m.group(0), m.start(), m.end()))
            i = _parse_decl_arg(s, m.end() + 1)
            continue
        return parts


def _send_parts(s, i):
    parts = []
    while True:
        end, kind, ns, ne = _parse_send_arg(s, i)
        if kind == "unnamed":
            parts.append(("", end, end))
            i = end + 1
        elif kind == "named":
            parts.append((s[ns:ne], ns, ne))
            i = ne + 1
        else:
            return parts


def _rewrite(s, first_end, parts, new_pieces):
    """Return edits [(start, end, text)] turning parts' names into new_pieces[1:]."""
    edits = []
    for (name, ns, colon), new in zip(parts, new_pieces[1:]):
        if name == new:
            continue
        if name == "":
            pad = "" if ns > 0 and s[ns - 1].isspace() else " "
            edits.append((ns, ns, pad + new))
        else:
            edits.append((ns, colon, new))
    return edits


def build_table(pairs):
    """{old full selector: new full selector}, keeping only renames with the same number of parts."""
    return {o: n for o, n in pairs if o != n and o.count(":") == n.count(":")}


def rename_selectors(text, table):
    if not table:
        return text
    firsts = {k.split(":", 1)[0] for k in table}
    pat = re.compile(r"\b(" + "|".join(sorted(map(re.escape, firsts), key=len, reverse=True)) + r"):")
    edits = []
    for m in pat.finditer(text):
        first = m.group(1)
        line_start = text.rfind("\n", 0, m.start()) + 1
        prefix = text[line_start:m.start()]
        if re.fullmatch(r"\s*[-+]\s*\([^;{}]*\)\s*", prefix):
            parts = _decl_parts(text, _parse_decl_arg(text, m.end()))
        elif re.search(r"@selector\(\s*$", prefix):
            close = text.find(")", m.end())
            sel = text[m.start():close]
            new = table.get(sel)
            if new:
                edits.append((m.start(), close, new))
            continue
        else:
            k = m.start() - 1
            while k >= 0 and text[k].isspace():
                k -= 1
            if k < 0 or not (text[k].isalnum() or text[k] in "_])"):
                continue  # not a message send
            end, kind, ns, ne = _parse_send_arg(text, m.end())
            parts = []
            if kind == "unnamed":
                parts = [("", end, end)] + _send_parts(text, end + 1)
            elif kind == "named":
                parts = [(text[ns:ne], ns, ne)] + _send_parts(text, ne + 1)
        old = first + ":" + "".join(p[0] + ":" for p in parts)
        new = table.get(old)
        if not new:
            continue
        edits += _rewrite(text, m.end(), parts, new.split(":")[:-1])
    for start, end, repl in sorted(edits, reverse=True):
        text = text[:start] + repl + text[end:]
    return text


def selectors_in_decls(text):
    """Full selectors of the method declarations in `text` (for building the table from a diff)."""
    out = []
    for m in re.finditer(r"^\s*[-+]\s*\([^;{}]*?\)\s*([A-Za-z_][A-Za-z0-9_]*):", text, re.M):
        parts = _decl_parts(text, _parse_decl_arg(text, m.end()))
        out.append(m.group(1) + ":" + "".join(p[0] + ":" for p in parts))
    return out


# Built from upstream ad5288b4a (#745), declarations in its .h and .m changes, paired in order.
UPSTREAM_745 = build_table([
    ("checkPotentialPath::", "checkPotentialPath:searchPaths:"),
    ("doesHitLine::", "doesHitLine:v1:"),
    ("doesHitLine:::", "doesHitLine:v1:hitEntity:"),
    ("doesHitLine::withPosition:andIJK:::", "doesHitLine:v1:withPosition:i:j:k:"),
    ("drawGLDisplay::::", "drawGLDisplay:y:z:alpha:"),
    ("drawOctreeCollisionFromLocation:::", "drawOctreeCollisionFromLocation:scale:offset:"),
    ("drawOctreeFromLocation:::", "drawOctreeFromLocation:scale:offset:"),
    ("drawStarChart:::::", "drawStarChart:y:z:alpha:compact:"),
    ("findBoundingBoxRelativeTo:InVectors:::", "findBoundingBoxRelativeTo:i:j:k:"),
    ("findBoundingBoxRelativeToPosition:InVectors:::", "findBoundingBoxRelativeToPosition:i:j:k:"),
    ("getCloudTextureNameFor:::", "getCloudTextureNameFor:impress:bias:"),
    ("getCloudTextureNameFor:::intoData:width:height:", "getCloudTextureNameFor:impress:bias:intoData:width:height:"),
    ("getContainersOfCommodity::", "getContainersOfCommodity:how_much:"),
    ("initWithColors::andSystemInfo:", "initWithColors:col2:andSystemInfo:"),
    ("isHitByLine::", "isHitByLine:v1:"),
    ("isHitByOctree:withOrigin:andIJK:andScales::", "isHitByOctree:withOrigin:andIJK:s1:s2:"),
    ("keyForInterstellarOverridesForSystems::inGalaxy:", "keyForInterstellarOverridesForSystems:s2:inGalaxy:"),
    ("paintVertex::", "paintVertex:seed:"),
    ("prepareMarkedDestination::", "prepareMarkedDestination:marker:"),
    ("scannerDisplayColorForShip:::", "scannerDisplayColorForShip:scannerDisplayColor1:scannerDisplayColor2:"),
    ("scannerDisplayColorForShip:::::::", "scannerDisplayColorForShip:isHostile:flash:scannerDisplayColor1:"
                                          "scannerDisplayColor2:scannerDisplayColorH1:scannerDisplayColorH2:"),
    ("setDimensionsAndCorridor:::", "setDimensionsAndCorridor:ddc:launching:"),
    ("setVirtualJoystick::", "setVirtualJoystick:vmy:"),
    ("trackDestination::", "trackDestination:retreat:"),
    ("trackPrimaryTarget::", "trackPrimaryTarget:retreat:"),
    ("trackSideTarget::", "trackSideTarget:leftside:"),
])

# Upstream #737 renamed OOCocoa.h to OOFoundation.h.
INCLUDE_RENAMES = (('"OOCocoa.h"', '"OOFoundation.h"'), ("<OOCocoa.h>", "<OOFoundation.h>"))
TRANSFORM_VERSION = "upstream-745-737-v2"
OBJC_SOURCES = (".h", ".m", ".mm")
C_SOURCES = OBJC_SOURCES + (".c", ".cc", ".cpp", ".hpp")


def upstream_renames(path, text):
    """The history snapshot transform: upstream's mechanical renames. The header rename (#737) reaches
    every C-family source, since the history's sources become C++ (step 17); the selector renames
    (#745) are Objective-C only."""
    if not path.endswith(C_SOURCES):
        return text
    for old, new in INCLUDE_RENAMES:
        text = text.replace(old, new)
    return rename_selectors(text, UPSTREAM_745) if path.endswith(OBJC_SOURCES) else text
