#!/usr/bin/env python3
"""Differential test of oofnd's plist parser/writers against GNUstep (bead oo-g2k, contract C1).

Two programs read the same files and print the same protocol (tools/plist-fuzz/*):

  * gnustep_oracle   OOPropertyListFromData (ChangeDTDIfApplicable + NSPropertyListSerialization),
                     the game's OldSchoolPropertyListWriting.mm and GNUstep's XML writer, linked
                     against the installed GNUstep base. A test utility built on demand; it is
                     not part of the game.
  * oofnd_plist      oo::parsePropertyList, oo::writeOldStylePList, oo::writeXMLPList.

Each parse is printed in plist_dump.hpp's canonical form. Per file the comparator checks:

  parse   same result (tree + format, or the same error message, or both nil)
  old     old-style writer bytes identical (or the same error)
  xml     XML writer bytes identical (or the same error)
  rt-old  oofnd's old-style bytes, re-parsed by GNUstep, give back the original tree
  rt-xml  oofnd's XML bytes, re-parsed by GNUstep, give back the original tree

A difference ADR-0027 declares intentional is classified with its item number and not counted
as a divergence; a round-trip loss that GNUstep's own writer has too (its bytes equal oofnd's)
is "lossy-in-gnustep". Anything else is UNEXPLAINED and fails the run.

RULE 6: the corpus mode opens expansion archives, but this tool never prints their content. A
divergence is reported as the expansion identifier (catalogue metadata, tools/oxp-corpus/
tier3.json), a hash of the member path, the stage, a structural path whose dictionary steps are
key INDICES (never key text), and the two node types.

    python3 tools/plist_fuzz.py fuzz   [--seed N] [--count N]        synthetic seeds + mutants
    python3 tools/plist_fuzz.py corpus [--tier FILE] [--limit N]     every .plist in the corpus
    python3 tools/plist_fuzz.py selftest                             the comparator catches a planted divergence
"""
from __future__ import annotations

import argparse
import collections
import concurrent.futures
import hashlib
import json
import os
import random
import re
import subprocess
import sys
import tempfile
import unicodedata
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
OO = REPO / "upstream" / "oolite"
SRC = HERE / "plist-fuzz"
sys.path.insert(0, str(HERE))

# ---------------------------------------------------------------------------------------- build

def build(work: Path) -> tuple[Path, Path]:
    """Compile both programs into `work`; returns (oracle, oofnd)."""
    cxx = os.environ.get("CXX", "clang++")
    oracle, oofnd = work / "gnustep_oracle.exe", work / "oofnd_plist.exe"
    subprocess.run([cxx, "-std=c++20", "-O2", "-Wall", "-Wextra", "-Werror",
                    f"-I{OO / 'src'}", f"-I{OO / 'tests' / 'unit' / 'oofnd'}",
                    str(SRC / "oofnd_plist.cpp"), "-o", str(oofnd)], check=True)
    cfg = lambda flag: subprocess.run(["sh", "-c", f"gnustep-config {flag}"], check=True,
                                      capture_output=True, text=True).stdout.split()
    # gnustep-config's -MMD would drop .d files into the working directory; no dependency files.
    objc = [f for f in cfg("--objc-flags") if f not in ("-MMD", "-MP")]
    core = OO / "src" / "Core"
    subprocess.run([cxx, "-x", "objective-c++", *objc, "-Wextra", f"-I{core}",
                    str(SRC / "gnustep_oracle.mm"), str(core / "OldSchoolPropertyListWriting.mm"),
                    str(core / "NSNumberOOExtensions.mm"), *cfg("--base-libs"), "-o", str(oracle)],
                   check=True, cwd=work)
    return oracle, oofnd


# ------------------------------------------------------------------------------------- running

# A batch's time limit: GNUstep's old-style writer is slow on big files (about 100 KB/s for a
# 900 KB plist), so the limit grows with the batch's bytes. A hang is charged to its file.
def time_limit(items) -> float:
    return 20 + sum(p.stat().st_size for _, p in items) / 10_000


def run_tool(exe: Path, items: list[tuple[str, Path]], outdir: Path, parse_only: bool) -> dict:
    """{id: {"P": ..., "W1": ..., "W2": ...}}. A crash or hang is charged to the file that was
    being processed ("P CRASH"/"P HANG") and the run resumes after it."""
    results: dict[str, dict] = {}
    todo = list(items)
    n = 0
    while todo:
        n += 1
        listfile = outdir / f"{exe.stem}.{items[0][0]}.{n}.list"   # unique per chunk: chunks run in parallel
        # bytes, not write_text: text mode on Windows would end each path with a CR
        listfile.write_bytes("".join(f"{i}\t{p}\n" for i, p in todo).encode("utf-8"))
        args = [str(exe), str(listfile), str(outdir)] + (["parse-only"] if parse_only else [])
        env = dict(os.environ, TZ="UTC", GNUSTEP_TZ="UTC")
        try:
            cp = subprocess.run(args, capture_output=True, timeout=time_limit(todo), env=env)
            out, fate = cp.stdout, ("CRASH" if cp.returncode != 0 else None)
        except subprocess.TimeoutExpired as e:
            out, fate = e.stdout or b"", "HANG"
        current = None
        ended = False
        for line in out.decode("utf-8", "replace").splitlines():
            if line.startswith("F "):
                current = line[2:]
                results[current] = {}
            elif line == "END":
                ended = True
            elif current is not None and " " in line:
                tag, rest = line.split(" ", 1)
                results[current][tag] = rest
        if ended and fate is None:
            break
        if current is None:
            raise SystemExit(f"{exe.name} produced no output: {out[:200]!r}")
        if "P" not in results[current] or fate:
            results[current].setdefault("P", fate or "CRASH")
            results[current]["FATE"] = fate or "CRASH"   # a writer that died shows as MISSING + this
        done = [i for i, _ in todo].index(current) + 1
        todo = todo[done:]
    return results


# ------------------------------------------------------------------------ the canonical dump

class Dump:
    """Parser for plist_dump.hpp's one-line form into (type, value) trees."""

    def __init__(self, s: str):
        self.s, self.i = s, 0

    def value(self):
        s, c = self.s, self.s[self.i]
        if s.startswith("nil", self.i):
            self.i += 3
            return ("nil", None)
        if c == "S":
            self.i += 1
            return ("string", self.string())
        if c == "!":
            self.i += 1
            return ("nonstring-key", self.value())
        if c == "[":
            self.i += 1
            items = []
            while s[self.i] != "]":
                items.append(self.value())
                if s[self.i] == ",":
                    self.i += 1
            self.i += 1
            return ("array", items)
        if c == "{":
            self.i += 1
            items = []
            while s[self.i] != "}":
                k = self.string() if s[self.i] == '"' else self.value()
                assert s[self.i] == "="
                self.i += 1
                items.append((k, self.value()))
                assert s[self.i] == ";"
                self.i += 1
            self.i += 1
            return ("dict", items)
        j = self.i + 1
        while j < len(s) and s[j] not in ",;]}":
            j += 1
        tok, self.i = s[self.i:j], j
        kind = {"B": "bool", "I": "integer", "U": "integer", "R": "real", "D": "data", "T": "date"}
        return (kind.get(tok[0], "unknown"), tok)

    def string(self):
        s = self.s
        assert s[self.i] == '"'
        self.i += 1
        out = []
        while s[self.i] != '"':
            if s[self.i] == "\\":
                if s[self.i + 1] == "u":
                    out.append(chr(int(s[self.i + 2:self.i + 6], 16)))
                    self.i += 6
                    continue
                self.i += 1
            out.append(s[self.i])
            self.i += 1
        self.i += 1
        return "".join(out)


def tree(p: str):
    """The tree of a "P OK <format> <dump>" line."""
    return Dump(p.split(" ", 2)[2]).value()


def first_difference(a, b, path="$"):
    """(path, type_a, type_b) of the first structural difference; dict steps are key indices."""
    if a[0] != b[0]:
        return path, a[0], b[0]
    if a[0] == "array":
        for n, (x, y) in enumerate(zip(a[1], b[1])):
            d = first_difference(x, y, f"{path}[{n}]")
            if d:
                return d
        if len(a[1]) != len(b[1]):
            return f"{path}.count", f"{len(a[1])} items", f"{len(b[1])} items"
        return None
    if a[0] == "dict":
        for n, ((ka, x), (kb, y)) in enumerate(zip(a[1], b[1])):
            if ka != kb:
                return f"{path}{{key #{n}}}", "key", "different key"
            d = first_difference(x, y, f"{path}{{#{n}}}")
            if d:
                return d
        if len(a[1]) != len(b[1]):
            return f"{path}.count", f"{len(a[1])} keys", f"{len(b[1])} keys"
        return None
    if a[0] == "nonstring-key":
        return first_difference(a[1], b[1], path)
    if a[1] != b[1]:
        return path, f"{a[0]} (value hash {digest(a[1])})", f"{b[0]} (value hash {digest(b[1])})"
    return None


def digest(x) -> str:
    return hashlib.sha256(repr(x).encode("utf-8", "surrogatepass")).hexdigest()[:10]


def walk(t):
    yield t
    if t[0] == "array":
        for x in t[1]:
            yield from walk(x)
    elif t[0] == "dict":
        for k, v in t[1]:
            yield ("string", k) if isinstance(k, str) else k
            yield from walk(v)


# ------------------------------------------------------------------------- ADR-0027 classifier

def has_nonstring_key(t) -> bool:
    return t[0] == "dict" and any(not isinstance(k, str) or has_nonstring_key(v) for k, v in t[1]) \
        or t[0] == "array" and any(has_nonstring_key(x) for x in t[1])


def item5_allowances(t) -> tuple[bool, bool, bool]:
    """(quotes, case, decomposed): what ADR-0027 item 5 lets oofnd's writers do differently for this tree.
    quotes: a non-ASCII string GNUstep's old-style writer leaves bare (all of it in
    +alphanumericCharacterSet) is quoted by oofnd. case: keys equal ignoring case, which the
    old-style writer leaves in hash order. decomposed: keys with characters from U+00C0 up, which
    GNUstep's -compare:/-caseInsensitiveCompare: order by its canonical decomposition and oofnd by
    UTF-16 units (both writers)."""
    quotes = case = decomposed = False
    for node in walk(t):
        if node[0] == "string" and any(ord(c) > 0x7F for c in node[1]) and all(
                unicodedata.category(c)[0] in "LMN" for c in node[1]):
            quotes = True
        if node[0] == "dict" and len(node[1]) > 1:
            keys = [k for k, _ in node[1] if isinstance(k, str)]
            folded = [k.lower() for k in keys]
            case = case or len(folded) != len(set(folded))
            decomposed = decomposed or any(ord(c) >= 0xC0 for k in keys for c in k)
    return quotes, case, decomposed


def item5_only(gnustep: bytes, oofnd: bytes, quotes: bool, reorder: bool) -> bool:
    """The outputs differ only as item 5 allows: quotes added, and/or the same lines in another
    order."""
    def norm(b):
        lines = (b.replace(b'"', b"") if quotes else b).split(b"\n")
        return sorted(lines) if reorder else lines
    return (quotes or reorder) and norm(gnustep) == norm(oofnd)


DATA_COMMENT_TO_END = re.compile(rb"<[^>]*//[^\n]*\Z")
DECLARED_ENCODING = re.compile(rb"encoding\s*=\s*[\"']([^\"']*)[\"']", re.I)
READ_AS_UTF8_OR_LATIN1 = {b"", b"utf-8", b"utf8", b"us-ascii", b"ascii", b"iso-8859-1", b"latin1", b"iso_8859-1",
                          b"iso-latin-1", b"cp1252"}
ENTITY_WITHOUT_NUMBER = re.compile(rb"&#x?\s*;")
WIDE_XML = re.compile(rb"encoding\s*=\s*[\"']\s*(utf-16|utf-32|ucs-2)", re.I)


def classify_parse(g: str, o: str, data: bytes) -> tuple[str, str]:
    """(verdict, detail) for the parse stage; verdict is MATCH, BOTH-REJECT, BOTH-NIL,
    ADR-0027 item N, or DIVERGE."""
    if o in ("CRASH", "HANG", "MISSING"):
        return "DIVERGE", f"oofnd {o}"   # never reproduced, even where GNUstep does the same
    if g == o:
        return ("MATCH" if g.startswith("OK") else "BOTH-NIL" if g == "NIL" else "BOTH-REJECT"), ""
    # o's error is PListError::description(), the text OOPropertyListFromData logged.
    oerr = o.startswith("ERR ")
    if oerr and o.endswith('"binary property lists are not supported by oofnd"'):
        return "ADR-0027 item 3", "binary plist"
    if oerr and o.endswith(' - non-string key in dictionary"') and (
            g.startswith("ERR") or g.startswith("OK") and has_nonstring_key(tree(g))):
        # GNUstep accepts the key (and may fail later in the same data); oofnd stops at it.
        return "ADR-0027 item 2", "non-string key"
    if o.endswith('"failed to parse as XML property list"') and (
            data[:2] in (b"\xfe\xff", b"\xff\xfe") or b"\0" in data[:4] or WIDE_XML.search(data[:512])):
        return "ADR-0027 item 6", "UTF-16/32 XML"
    enc = DECLARED_ENCODING.search(data[:512])
    if enc and enc.group(1).lower() not in READ_AS_UTF8_OR_LATIN1 and data.lstrip()[:5] == b"<?xml":
        # GNUstep transcodes e.g. windows-1252 or iso-8859-2; oofnd reads UTF-8 or Latin-1 only
        return "ADR-0027 item 6", "declared single-byte encoding other than UTF-8/Latin-1"
    if ENTITY_WITHOUT_NUMBER.search(data) and not g.startswith("OK"):
        # &#; / &#x; : sscanf returns EOF and GNUstep uses an uninitialised value
        return "ADR-0027 item 4", "GNUstep reads an uninitialised value"
    if g in ("CRASH", "HANG", "EXC NSMallocException") and oerr:
        # reads past the buffer, never returns, or asks malloc for a negative length
        return "ADR-0027 item 4", f"GNUstep's behaviour is undefined here ({g.split()[-1]})"
    if oerr and o.endswith("unexpected character (wanted '>')\"") and DATA_COMMENT_TO_END.search(data):
        # old-style <hex data whose // comment runs to the end: GNUstep reads past the buffer
        return "ADR-0027 item 4", "GNUstep reads past the buffer"
    if g in ("EXC NSInvalidArgumentException", "EXC NSCharacterConversionException") and oerr:
        return "ADR-0027 item 7", "GNUstep raises out of the parser; oofnd returns the error"
    if g.startswith("OK") and o.startswith("OK"):
        gt, ot = tree(g), tree(o)
        d = first_difference(gt, ot)
        if d is None:
            return "DIVERGE", "format %s vs %s" % (g.split()[1], o.split()[1])
        return "DIVERGE", "%s: GNUstep %s, oofnd %s" % d
    kind = lambda r: r.split(" ", 1)[0]
    return "DIVERGE", f"GNUstep {kind(g)} (hash {digest(g)}), oofnd {kind(o)} (hash {digest(o)})"


# ------------------------------------------------------------------------------------ compare

FORMATS = {"1": "old-style (OpenStep)", "1000": "old-style with GNUstep <*...> extensions", "100": "XML"}


def compare(items, data_of, work: Path, oracle: Path, oofnd: Path, jobs: int) -> list[dict]:
    """Run both programs over `items` [(id, path)] and return one record per file."""
    gdir, odir = work / "gnustep", work / "oofnd"
    for d in (gdir, odir):
        d.mkdir(exist_ok=True)
    chunks = [items[i:i + 400] for i in range(0, len(items), 400)]

    def both(chunk, parse_only, dirs):
        return (run_tool(oracle, chunk, dirs[0], parse_only), run_tool(oofnd, chunk, dirs[1], parse_only))

    g, o = {}, {}
    with concurrent.futures.ThreadPoolExecutor(jobs) as ex:
        for gr, orr in ex.map(lambda c: both(c, False, (gdir, odir)), chunks):
            g.update(gr)
            o.update(orr)

    # Round trip: every oofnd-written file, re-parsed by GNUstep.
    rt_items = [(f"{i}.{ext}", odir / f"{i}.{ext}") for i, _ in items for ext in ("old", "xml")
                if (odir / f"{i}.{ext}").exists()]
    rtdir = work / "rt"
    rtdir.mkdir(exist_ok=True)
    rt = {}
    with concurrent.futures.ThreadPoolExecutor(jobs) as ex:
        for r in ex.map(lambda c: run_tool(oracle, c, rtdir, True), [rt_items[i:i + 400] for i in range(0, len(rt_items), 400)]):
            rt.update(r)

    records = []
    for ident, _path in items:
        gp, op = g.get(ident, {}), o.get(ident, {})
        rec = {"id": ident, "stages": {}}
        if gp.get("P", "").startswith("OK"):
            rec["format"] = FORMATS.get(gp["P"].split(" ")[1], "other")
        verdict, detail = classify_parse(gp.get("P", "MISSING"), op.get("P", "MISSING"), data_of(ident))
        rec["stages"]["parse"] = (verdict, detail)
        if verdict == "MATCH":
            original = tree(gp["P"])
            allow = item5_allowances(original)
            for tag, ext, stage in (("W1", "old", "old"), ("W2", "xml", "xml")):
                gw, ow = gp.get(tag, "MISSING"), op.get(tag, "MISSING")
                gb, ob = gdir / f"{ident}.{ext}", odir / f"{ident}.{ext}"
                same_bytes = gw == ow == "OK" and gb.read_bytes() == ob.read_bytes()
                if gw == "SKIP data-length-undefined":
                    rec["stages"][stage] = ("ADR-0027 item 4", "GNUstep's data writer is undefined here")
                elif same_bytes or (gw == ow and gw != "OK"):
                    rec["stages"][stage] = ("MATCH", "")
                elif gw == ow == "OK" and item5_only(gb.read_bytes(), ob.read_bytes(),
                                                     allow[0] and stage == "old",
                                                     allow[2] or (allow[1] and stage == "old")):
                    kinds = [k for k, on in zip(("bare non-ASCII", "case-equal keys", "non-ASCII key order"),
                                                (allow[0] and stage == "old", allow[1] and stage == "old", allow[2])) if on]
                    rec["stages"][stage] = (f"ADR-0027 item 5 ({', '.join(kinds)})", "")
                else:
                    rec["stages"][stage] = ("DIVERGE", f"GNUstep {gw.split(' ')[0]}{' ' + gp['FATE'] if 'FATE' in gp else ''}, oofnd {ow.split(' ')[0]}"
                                            + (" (bytes differ)" if gw == ow == "OK" else ""))
                if ow == "OK":
                    back = rt.get(f"{ident}.{ext}", {}).get("P", "MISSING")
                    if back.startswith("OK") and first_difference(original, tree(back)) is None:
                        rec["stages"]["rt-" + stage] = ("MATCH", "")
                    elif same_bytes:
                        rec["stages"]["rt-" + stage] = ("lossy-in-gnustep", "GNUstep's own writer writes the same bytes")
                    elif rec["stages"][stage][0].startswith("ADR"):
                        rec["stages"]["rt-" + stage] = (rec["stages"][stage][0], "follows the writer difference")
                    else:
                        d = first_difference(original, tree(back)) if back.startswith("OK") else None
                        rec["stages"]["rt-" + stage] = ("DIVERGE", "%s: original %s, re-read %s" % d if d
                                                        else f"GNUstep re-read: {back.split(' ')[0]}")
        records.append(rec)
    return records


def summarise(records, label: str, describe) -> tuple[dict, list[str]]:
    counts = collections.Counter()
    unexplained = []
    for rec in records:
        counts["files"] += 1
        if "format" in rec:
            counts[f"format: {rec['format']}"] += 1
        for stage, (verdict, detail) in rec["stages"].items():
            counts[f"{stage}: {verdict}"] += 1
            if verdict == "DIVERGE":
                unexplained.append(f"  {describe(rec['id'])} [{stage}] {detail}")
    counts["unexplained divergences"] = len(unexplained)
    print(f"== {label}")
    for k in sorted(counts):
        print(f"   {k}: {counts[k]}")
    for line in unexplained[:200]:
        print(line)
    return dict(counts), unexplained


# ------------------------------------------------------------------------------------- fuzzing

# Seeds: the inputs of the oofnd unit-test fixtures (upstream/oolite/tests/unit/oofnd/
# test_plist_*.cpp), plus the shapes the game's own data uses. No expansion content.
SEEDS = [
    b"abc", b"a.b/c_d-e:f$g+h!#%&*?@^|~9", b"a/b//c", b"\x08\x0b\x0cabc\r\n", b"ab cd", b"'single'",
    b"\"hello world\"", b"\"\"", b"\"tab\there\"", "\"caf\u00e9\"".encode(), b"\"\\U00e9\\u12\"",
    b"\"\\101\\n\\t\\\\\\\"\"", b"// c\n /* multi\n line */ word // trailing", b"x /* never closed",
    b"\"\xef\xbb\xbfb\"", b"\"x\xef\xbb\xbf\"", b"\"\\12\n\" x", b"()", b"(a, \"b c\", (d), {e = f;})",
    b"(1 , 2 ,3)", b"(a, b,)", b"(a,,b)", b"{}", b"{ a = b; }", b"{ \"a\" = 1; b = (x, y); }", b"{ a = b }",
    b"{ a = b; a = c; }", b"{a=b;c={d=(e,<0a0b>);};}", b"<0a0B ff>", b"< 01 02 >", b"<01 // x\n 02>",
    b"(<*I12>, <*I-5>, <*I18446744073709551615>, <*I99999999999999999999>)",
    b"(<*R1.5>, <*R-0.25e2>, <*Rjunk>, <*R\"2.5\">)", b"(<*BY>, <*BN>, <*BYES>, <*BNO>)",
    b"{ key = <*D2001-01-01 00:00:00 +0000>; }", b"(<[AAEC]>, <[]>, <[AAE=]>, <[AA==]>, <[ A A E C ]>)",
    b"/*c*/ { /* k */ a /* e */ = /* v */ b /* s */ ; }",
    b"{\n\tshipdata = {\n\t\tmodel = \"x.dat\";\n\t\tmax_flight_speed = 300;\n\t\troles = \"trader pirate(0.5)\";\n\t};\n}\n",
    b"{ a = <000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2021>; }",
    b"<?xml version=\"1.0\"?><plist><dict><key>a</key><date>2001-01-01 00:00:00 +0000</date></dict></plist>",
    b"<?xml version=\"1.0\"?><plist><string>\\U00411</string></plist>",
    b"<?xml version=\"1.0\"?><plist><array><string>&#xFEFF;a</string><string>a&amp;b&lt;</string></array></plist>",
    b"<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist><string>x</string></plist>",
    b"<?xml version=\"1.0\"?><plist><key>k</key></plist>",
    b"<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><plist><string>caf\xe9</string></plist>",
    b"<?xml version=\"1.0\"?><plist><date>junk</date></plist>",
    b"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
    b"\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>b</key>\n"
    b"\t<array>\n\t\t<integer>-3</integer>\n\t\t<real>2.5</real>\n\t\t<true/>\n\t\t<false/>\n"
    b"\t\t<data>\n\t\tAAEC\n\t\t</data>\n\t\t<date>2001-01-01T00:00:00Z</date>\n\t</array>\n"
    b"\t<key>a</key>\n\t<string>x y</string>\n</dict>\n</plist>\n",
    b"<?xml version=\"1.0\"?><plist><dict><key>k</key><dict/><key>e</key><array/><key>s</key><string/></dict></plist>",
]

TOKENS = [b"\"", b"\\", b"\\U", b"\\u00", b"\\n", b"\\0", b";", b"=", b",", b"{", b"}", b"(", b")", b"<", b">",
          b"<*I", b"<*R", b"<*B", b"<*D", b"<[", b"]>", b"//", b"/*", b"*/", b"\n", b"\r", b" ", b"\t",
          b"<?xml version=\"1.0\"?>", b"<plist>", b"</plist>", b"<dict>", b"</dict>", b"<key>", b"</key>",
          b"<string>", b"</string>", b"<array>", b"</array>", b"<integer>", b"</integer>", b"<real>",
          b"</real>", b"<true/>", b"<false/>", b"<data>", b"</data>", b"<date>", b"</date>", b"&amp;",
          b"&lt;", b"&#65;", b"&#x41;", b"<![CDATA[", b"]]>", b"<!--", b"-->", b"\xef\xbb\xbf", b"\xc3\xa9",
          b"\xff", b"\x00", b"\x80", b"-1e5", b"0x10", b"18446744073709551616", b"2001-01-01 00:00:00 +0000",
          b"2001-01-01T00:00:00Z", b"YES", b"AAEC", b"0a0b"]


def mutate(rng: random.Random, data: bytes) -> bytes:
    b = bytearray(data)
    for _ in range(rng.randint(1, 4)):
        op = rng.randrange(7)
        pos = rng.randint(0, len(b))
        if op == 0 and b:
            b[min(pos, len(b) - 1)] = rng.randrange(256)
        elif op == 1:
            b[pos:pos] = rng.choice(TOKENS)
        elif op == 2 and b:
            del b[pos:pos + rng.randint(1, 8)]
        elif op == 3 and b:
            b[pos:pos] = b[pos:pos + rng.randint(1, 16)]
        elif op == 4:
            del b[pos:]
        elif op == 5:
            other = rng.choice(SEEDS)
            b = b[:pos] + other[rng.randint(0, len(other)):]
        elif op == 6 and b:
            b[min(pos, len(b) - 1)] = rng.choice(b"\x00\x80\xc3\xff\xef\n\r\"\\<>{}();=,")
    return bytes(b)


def cmd_fuzz(args) -> int:
    rng = random.Random(args.seed)
    cases = list(SEEDS) + [mutate(rng, rng.choice(SEEDS)) for _ in range(args.count)]
    with tempfile.TemporaryDirectory(prefix="plist-fuzz-") as tmp:
        work = Path(tmp)
        oracle, oofnd = build(work)
        indir = work / "in"
        indir.mkdir()
        items = []
        for n, c in enumerate(cases):
            p = indir / f"f{n}.plist"
            p.write_bytes(c)
            items.append((f"f{n}", p))
        records = compare(items, lambda i: cases[int(i[1:])], work, oracle, oofnd, args.jobs)
        label = f"fuzz: seed {args.seed}, {len(SEEDS)} seeds + {args.count} mutants"
        counts, unexplained = summarise(records, label, lambda i: f"case {i} (seed {args.seed})")
        if args.keep_failures and unexplained:
            dest = Path(args.keep_failures)
            dest.mkdir(parents=True, exist_ok=True)
            for rec in records:
                if any(v == "DIVERGE" for v, _ in rec["stages"].values()):
                    (dest / f"{rec['id']}.plist").write_bytes(cases[int(rec["id"][1:])])
    if counts["files"] != len(cases):
        print("FAIL: not every case was compared")
        return 1
    return 1 if unexplained else 0


def cmd_corpus(args) -> int:
    import oxp_corpus as oc
    import oxp_tier1 as t1
    entries = json.loads(Path(args.tier).read_text(encoding="utf-8"))["entries"]
    if args.limit:
        entries = entries[:args.limit]
    cache = t1.cache_dir()
    with tempfile.TemporaryDirectory(prefix="plist-corpus-") as tmp:
        work = Path(tmp)
        oracle, oofnd = build(work)
        indir = work / "in"
        indir.mkdir()
        items, where, missing, archives = [], {}, 0, 0
        for e in entries:
            blob = oc.blob_path(cache, e["url"])
            if not blob.exists():
                missing += 1
                continue
            archives += 1
            with zipfile.ZipFile(blob) as z:
                for info in z.infolist():
                    if info.is_dir() or not info.filename.lower().endswith(".plist"):
                        continue
                    ident = f"c{len(items)}"
                    p = indir / f"{ident}.plist"
                    p.write_bytes(z.read(info))
                    items.append((ident, p))
                    where[ident] = (e["identifier"], hashlib.sha256(info.filename.encode("utf-8")).hexdigest()[:12])
        print(f"corpus: {archives} archives ({missing} not cached), {len(items)} .plist members")
        records = compare(items, lambda i: (indir / f"{i}.plist").read_bytes(), work, oracle, oofnd, args.jobs)
        counts, unexplained = summarise(records, f"corpus: {args.tier}",
                                        lambda i: f"{where[i][0]} member#{where[i][1]}")
        counts.update({"archives": archives, "archives not cached": missing})
    if args.json:
        Path(args.json).write_text(json.dumps(counts, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    if missing and not args.allow_missing:
        print(f"FAIL: {missing} archive(s) of the tier are not in the cache ({cache})")
        return 1
    return 1 if unexplained else 0


def cmd_selftest(_args) -> int:
    """The comparator must see a planted divergence, and must not excuse it."""
    ok = 'OK 1 {"a"=[S"x",I1];}'
    NSK = 'ERR Error Domain=NSPropertyListSerialization Code=0 "Parse failed at line 1 (char 5) - non-string key in dictionary"'
    cases = [
        (ok, ok, "MATCH"),
        (ok, 'OK 1 {"a"=[S"x",I2];}', "DIVERGE"),
        (ok, 'OK 1 {"a"=[S"x"];}', "DIVERGE"),
        (ok, 'OK 1 {"b"=[S"x",I1];}', "DIVERGE"),
        (ok, 'OK 1000 {"a"=[S"x",I1];}', "DIVERGE"),
        (ok, "ERR failed", "DIVERGE"),
        ("ERR x", "ERR y", "DIVERGE"),
        ("ERR x", "ERR x", "BOTH-REJECT"),
        ("CRASH", "OK 1 S\"a\"", "DIVERGE"),
        ("HANG", "HANG", "DIVERGE"),   # oofnd must terminate even where GNUstep does not
        ("OK 1 S\"a\"", "HANG", "DIVERGE"),
        ('OK 1 {!S"k"=S"v";}', NSK, "ADR-0027 item 2"),
        (ok, NSK, "DIVERGE"),
        ("OK 1 D<00>", 'ERR E "binary property lists are not supported by oofnd"', "ADR-0027 item 3"),
        ("EXC NSMallocException", "ERR x", "ADR-0027 item 4"),
        ("EXC NSMallocException", "OK 1 S\"a\"", "DIVERGE"),
        ("EXC NSInvalidArgumentException", "ERR x", "ADR-0027 item 7"),
        ("EXC NSGenericException", "ERR x", "DIVERGE"),
    ]
    bad = 0
    for g, o, want in cases:
        got, detail = classify_parse(g, o, b"x")
        if got != want:
            bad += 1
            print(f"FAIL: GNUstep {g!r} vs oofnd {o!r}: {got} ({detail}), wanted {want}")
    # A divergence is reported by path and type only: neither the key nor the value may appear.
    for o in ('OK 1 {"a"=[S"secret",I1];}', 'OK 1 {"secretkey"=[S"x",I1];}', "ERR secret message"):
        detail = classify_parse(ok, o, b"")[1]
        if "secret" in detail:
            bad += 1
            print(f"FAIL: divergence detail leaks a value: {detail}")
    print(f"selftest: {len(cases)} comparator cases, {bad} failure(s)")
    return 1 if bad else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fuzz")
    f.add_argument("--seed", type=int, default=1)
    f.add_argument("--count", type=int, default=3000)
    f.add_argument("--jobs", type=int, default=8)
    f.add_argument("--keep-failures", help="directory to copy diverging synthetic cases into")
    c = sub.add_parser("corpus")
    c.add_argument("--tier", default=str(REPO / "tools" / "oxp-corpus" / "tier3.json"))
    c.add_argument("--limit", type=int, default=0)
    c.add_argument("--jobs", type=int, default=8)
    c.add_argument("--json", help="write the counts here")
    c.add_argument("--allow-missing", action="store_true")
    sub.add_parser("selftest")
    args = ap.parse_args(argv)
    return {"fuzz": cmd_fuzz, "corpus": cmd_corpus, "selftest": cmd_selftest}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
