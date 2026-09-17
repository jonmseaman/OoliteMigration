#!/usr/bin/env python3
"""Find every file in the repository that SPAWNS THE GAME (bug oo-ccy9).

    python3 tools/launcher_scan.py tools tests upstream/oolite/tests

Prints one repo-relative path per line. tools/check-desktop-lock.sh check 2 uses it to notice a
launcher nobody has classified as "must take the desktop lock" or "exempt, and here is why".

WHY THIS IS A SEPARATE FILE. It used to be a heredoc inside check-desktop-lock.sh, which made it
impossible to unit-test a detection rule without running the whole guard over the whole tree.
tools/desktop-lock-rogue-proof now plants rogues against the guard AND this module is importable,
so a rule can be argued about directly.

THE RULE, AND WHY IT IS KEYED ON SEMANTICS RATHER THAN SPELLING
===============================================================
A launcher is: **a process-spawning call whose argv[0] resolves to the game binary.**

Not "a file that mentions oolite.exe" - that is a grep, and two successive reviews broke greps:

  * Attempt 1 matched the *string idiom* the existing launchers happened to use
    (``"oolite.exe" if IS_WINDOWS``). Three natural spellings were invisible while it printed PASS.
  * Attempt 2 matched the spawn, but followed the binary through plain ``name =`` assignment only,
    and treated ANY mention of the game anywhere in a call's arguments as a launch. A review broke
    it five ways, all measured:
      - ``cmd = []`` / ``cmd += [os.path.join(APP, "oolite.exe")]`` / ``Popen(cmd)``  -> MISSED
        (the ASSIGN regex demanded ``=`` not preceded by ``+``), and this is the repo's OWN house
        style: component/console.py:122 builds argv with ``argv += [...]``.
      - ``argv.append(...)`` / ``cmd.extend([...])``                                  -> MISSED
      - ``def game_binary(app): return os.path.join(app, "oolite.exe")`` then
        ``Popen([game_binary(...), "--no-splash"])``                                  -> MISSED
        (no propagation through a function return - and a factored-out helper is the single most
        likely shape for the NEXT launcher, since every current one duplicates that join)
      - ``PROJECT = "oolite"`` + ``subprocess.run(["meson", "setup", d, "-Dproject=" + PROJECT])``
        -> FALSE POSITIVE, and
      - ``LOGS = ".../oolite.app/logs"`` + ``subprocess.run(["tail", "-n", "50", LOGS + "/x.log"])``
        -> FALSE POSITIVE.

    The false positives matter as much as the misses. check-desktop-lock.sh is a SHARED GATE: a
    false positive fails an UNRELATED bead's acceptance, and that is exactly what gets a guard
    deleted. tools/js_api_check.py and tests/golden/golden_run.py already hold oolite.app paths for
    non-launching purposes, so this was live, not hypothetical.

So the two halves of the rule are:

  1. WHAT COUNTS AS THE BINARY (`GAME`). ``oolite.exe``; a path that ends AT the binary inside the
     app bundle (``oolite.app/oolite`` - not merely a path that *contains* an ``oolite.app``
     directory, which is what a log reader holds); ``./oolite``; or the bare word ``oolite``.
  2. WHERE IT HAS TO APPEAR (`argv[0]`). Only the COMMAND position counts. Mentioning the game in
     a later argument, an env var or a path is not launching it. This single restriction is what
     kills both measured false positives while keeping every real launcher.

Resolution of argv[0] is transitive, to a fixpoint, through everything this codebase actually
uses to build a command line:

    name = ...            name: T = ...        name += ...        a, b = ...
    self.name = ...       name.append(x)       name.extend(x)     name.insert(i, x)
    def f(...): return <something game-valued>      ->  f is game-valued

plus ``DebugConsole(...)``: the shared transport whose constructor's whole job is to spawn the
game. It is a launcher wherever it appears, with or without a visible path.

Shell files get the same treatment with shell syntax: the COMMAND WORD of each pipeline segment,
after stripping leaders (``exec``, ``start``, ``nohup``, ``VAR=x``, ``cmd /c``, ...) - INCLUDING
empty tokens, so the canonical batch line ``start "" "%OO_APP_DIR%\\oolite.exe"`` does not escape
by hiding behind an empty window title - and the contents of ``-c``/``/c`` command strings are
re-scanned, so ``bash -c "$APP/oolite.exe --no-splash"`` is not a hiding place either.

Comments are stripped before anything is matched, so prose never trips it.
"""

import os
import re
import sys

# Files whose JOB is to quote launcher spellings; scanning them would make it impossible for the
# guard to describe what it hunts for. Neither ever runs the game (the rogue proof writes scratch
# files and deletes them).
SELF_REFERENTIAL = (
    "tools/check-desktop-lock.sh",
    "tools/launcher_scan.py",
    "tools/desktop-lock-rogue-proof",
    "tools/desktop-lock-selftest",
)

# A call that starts a process. run/call/check_call/check_output only count with an explicit
# subprocess. prefix (a bare run() is any function); Popen is unambiguous enough on its own.
PY_SPAWN = re.compile(
    r"\b(?:subprocess\s*\.\s*(?:Popen|run|call|check_call|check_output)"
    r"|Popen"
    r"|os\s*\.\s*(?:startfile|system|popen|exec\w*|spawn\w*))\s*\(")
# The transport whose constructor spawns the game.
TRANSPORT = re.compile(r"\bDebugConsole\s*\(")

# "this expression names the GAME BINARY".
#   oolite.exe                    the Windows binary, however it is assembled
#   .../oolite.app/oolite[.exe]   a path that ENDS AT the binary in the bundle. NOT a path that
#                                 merely contains the bundle directory: ".../oolite.app/logs" is a
#                                 log reader, and flagging it failed an unrelated bead (review 2).
#   ./oolite                      the posix binary, run from the app dir
#   "oolite"                      the bare binary name as a complete string literal
GAME = re.compile(r"oolite\.exe"
                  r"|oolite\.app[/\\]+oolite(?![\w.])"
                  r"|\./oolite(?![\w.])"
                  r"|['\"]\.?/?oolite['\"]",
                  re.IGNORECASE)

# name = / name: T = / name += / a, b = / self.name = ... - every augmented operator, because
# `cmd += [...]` is this repo's own house style and attempt 2 did not match it.
ASSIGN = re.compile(
    r"^\s*([A-Za-z_][\w\s,\.\[\]'\"]*?)\s*"
    r"(?::[^=\n]+?)?"
    r"\s*(?:\*\*|//|>>|<<|[-+*/%|&^@])?=(?!=)(.*)$")
# argv.append(x) / cmd.extend([...]) / cmd.insert(0, x) - a mutation IS an assignment into <name>.
APPEND = re.compile(
    r"^\s*(?:self\s*\.\s*)?([A-Za-z_]\w*)\s*\.\s*(?:append|extend|insert|update)\s*\((.*)$")
DEF = re.compile(r"^(\s*)(?:async\s+)?def\s+([A-Za-z_]\w*)\s*\(")
RETURN = re.compile(r"^\s*(?:return|yield)\b(.*)$")

SH_ASSIGN = re.compile(r"^\s*(?:export\s+)?([A-Za-z_]\w*)=(.*)$")
SH_LEADERS = re.compile(
    r"^(?:exec|start|nohup|command|time|sudo|then|do|else|elif|if|while|until|"
    r"[A-Za-z_]\w*=\S*|[-/][cC]|cmd(?:\.exe)?|call|winpty|env)$")
# `bash -c "<command line>"` / `cmd /c "<command line>"`: the game word hides inside a quoted
# argument, so the contents are re-scanned as their own shell line.
SH_DASH_C = re.compile(r"""(?:^|\s)(?:-c|/[cCkK])\s+(['"])(.*?)\1""")


def _refs(expr, names):
    """Does `expr` mention any of `names` as a whole word?"""
    return any(re.search(r"\b%s\b" % re.escape(v), expr) for v in names)


def strip_py_comments(text):
    return "\n".join(re.sub(r"(^|\s)#.*$", r"\1", ln) for ln in text.splitlines())


def _assign_targets(lhs):
    """The identifiers a left-hand side binds: `a, b`, `self.x`, `d["k"]` -> a, b / x / d."""
    out = []
    for part in lhs.split(","):
        part = part.strip()
        part = re.sub(r"\[.*$", "", part).strip()       # d["k"] = ... binds d
        if not part:
            continue
        tail = part.split(".")[-1].strip()              # self.x = ... binds x
        if part.startswith("self.") or part.startswith("self ."):
            name = tail
        else:
            name = part.split(".")[0].strip()
        if re.fullmatch(r"[A-Za-z_]\w*", name or ""):
            out.append(name)
    return out


def _functions(body):
    """{function name: [its return/yield expressions]} - indentation-scoped, no ast needed.

    ast would be stricter, but the scan must also survive a file that does not parse (a template,
    a partially-written tool) rather than silently reporting "no launchers here".
    """
    lines = body.splitlines()
    funcs = {}
    for i, line in enumerate(lines):
        m = DEF.match(line)
        if not m:
            continue
        indent, name = len(m.group(1)), m.group(2)
        rets = []
        for nxt in lines[i + 1:]:
            if nxt.strip() and (len(nxt) - len(nxt.lstrip())) <= indent and not DEF.match(nxt):
                break
            if nxt.strip() and DEF.match(nxt) and (len(nxt) - len(nxt.lstrip())) <= indent:
                break
            r = RETURN.match(nxt)
            if r:
                rets.append(r.group(1))
        funcs.setdefault(name, []).extend(rets)
    return funcs


def game_names_python(body):
    """Every name (variable OR function) that transitively holds/returns the game binary."""
    funcs = _functions(body)
    names, changed = set(), True
    while changed:
        changed = False
        for line in body.splitlines():
            targets, rhs = [], None
            m = APPEND.match(line)
            if m:
                targets, rhs = [m.group(1)], m.group(2)
            else:
                m = ASSIGN.match(line)
                if m:
                    targets, rhs = _assign_targets(m.group(1)), m.group(2)
            if not targets or rhs is None:
                continue
            if not (GAME.search(rhs) or _refs(rhs, names)):
                continue
            for t in targets:
                if t not in names:
                    names.add(t)
                    changed = True
        for fname, rets in funcs.items():
            if fname in names:
                continue
            if any(GAME.search(r) or _refs(r, names) for r in rets):
                names.add(fname)
                changed = True
    return names


def balanced(text, open_at):
    """The argument text of the call whose '(' is at open_at, to its matching ')'."""
    depth, i = 0, open_at
    while i < len(text) and i < open_at + 4000:
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[open_at:i + 1]
        i += 1
    return text[open_at:open_at + 4000]


def _split_top(text):
    """Split on commas that are not inside (), [], {} or a string."""
    parts, depth, quote, cur = [], 0, None, []
    for ch in text:
        if quote:
            cur.append(ch)
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
            continue
        cur.append(ch)
    parts.append("".join(cur))
    return parts


def argv0_expr(call_args):
    """The expression that becomes argv[0] of a spawn, given the call's '(...)' text.

    This is THE detection rule: only the command position counts. `["tail", "-n", LOGS]` has
    argv[0] `"tail"` and is not a launch however much the rest of it mentions the game.
    """
    inner = call_args.strip()
    if inner.startswith("("):
        inner = inner[1:-1] if inner.endswith(")") else inner[1:]
    positional = [p for p in _split_top(inner)
                  if not re.match(r"^\s*[A-Za-z_]\w*\s*=(?!=)", p)]
    if not positional:
        return ""
    first = positional[0].strip()
    # A list/tuple command: argv[0] is its first element.
    if first[:1] in "[(":
        close = {"[": "]", "(": ")"}[first[0]]
        end = first.rfind(close)
        elems = _split_top(first[1:end if end > 0 else len(first)])
        return elems[0].strip() if elems else ""
    # A plain string command line (shell=True, os.system): argv[0] is its first word, re-quoted so
    # the bare-`oolite` form is still recognisable as a complete literal.
    lit = re.fullmatch(r"(?:[rbuf]*)(['\"])(.*)\1", first, re.S)
    if lit:
        words = lit.group(2).split()
        return '"%s"' % words[0] if words else ""
    return first


def spawns_python(text):
    body = strip_py_comments(text)
    if TRANSPORT.search(body):
        return True
    names = game_names_python(body)
    for m in PY_SPAWN.finditer(body):
        args = balanced(body, body.index("(", m.end() - 1))
        target = argv0_expr(args)
        if not target:
            continue
        if GAME.search(target) or _refs(target, names):
            return True
    return False


def game_names_shell(text):
    names, changed = set(), True
    while changed:
        changed = False
        for line in text.splitlines():
            m = SH_ASSIGN.match(line)
            if not m:
                continue
            rhs = m.group(2)
            if (GAME.search(rhs) or _refs(rhs, names)) and m.group(1) not in names:
                names.add(m.group(1))
                changed = True
    return names


def _sh_lines(text):
    """Every shell line, plus the contents of any `-c "..."` / `/c "..."` command string."""
    for raw in text.splitlines():
        yield raw
        for _, inner in SH_DASH_C.findall(raw):
            yield inner


def spawns_shell(text):
    names = game_names_shell(text)
    for raw in _sh_lines(text):
        line = raw.strip()
        if not line or line.startswith("#") or line.upper().startswith(("REM ", "::")):
            continue
        # Each pipeline/list segment gets its own command position.
        for seg in re.split(r"\|\||&&|[|;&]|\$\(|`", line):
            toks = seg.split()
            # Strip leaders AND empty tokens: `start "" "%APP%\oolite.exe"` must not escape by
            # putting an empty window title where the command word is looked for.
            while toks:
                head = toks[0].strip("\"'")
                if head and not SH_LEADERS.match(head):
                    break
                toks.pop(0)
            if not toks:
                continue
            word = toks[0].strip("\"'").lstrip("$").strip("{}")
            if GAME.search(word) or GAME.search('"%s"' % word):
                return True
            if word in names or re.sub(r"[^\w].*$", "", word) in names:
                return True
    return False


def scan(roots, skip=SELF_REFERENTIAL):
    out = []
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "build")]
            for name in sorted(filenames):
                path = os.path.join(dirpath, name).replace("\\", "/")
                ext = os.path.splitext(name)[1].lower()
                try:
                    text = open(path, "r", encoding="utf-8", errors="replace").read()
                except OSError:
                    continue
                if ext not in (".py", ".sh", ".bat", ".cmd"):
                    head = text[:200].splitlines()
                    if not (head and head[0].startswith("#!")
                            and re.search(r"\b(ba)?sh\b|python", head[0])):
                        continue
                    ext = ".py" if "python" in head[0] else ".sh"
                if path in skip:
                    continue
                if spawns_python(text) if ext == ".py" else spawns_shell(text):
                    out.append(path)
    return sorted(set(out))


if __name__ == "__main__":
    print("\n".join(scan(sys.argv[1:])))
