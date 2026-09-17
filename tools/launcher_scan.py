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
by hiding behind an empty window title - and the contents of ``-c``/``/c``/``-Command``/
``-EncodedCommand`` command strings are re-scanned, so ``bash -c "$APP/oolite.exe --no-splash"``
and ``powershell -Command "Start-Process '$APP/oolite.exe'"`` are not hiding places either.

Comments are stripped before anything is matched, so prose never trips it.

ONE RULE, EVERY BRANCH (review 3)
=================================
Review 3 did not find a missing spelling. It found the rule CONTRADICTING ITSELF: the same
launcher was caught in one branch and missed in another, which is strictly worse than a rule that
is uniformly narrow, because the guard looks like it covers the shape and does not.

  * ``args=`` and ``executable=`` ARE argv[0].  ``argv0_exprs`` used to discard every ``name=``
    argument as "a kwarg" - including ``args``, which is subprocess's own DOCUMENTED name for the
    command line, and ``executable``, which overrides what is actually run. MEASURED:
    ``subprocess.run(args=[GAME, "--no-splash"])`` and ``subprocess.Popen(["game"],
    executable=GAME)`` both scanned clean. Those two names are now read AS the command
    expression; every other kwarg is still ignored, which is what kills the false positives.
  * LEADERS ARE STRIPPED IN THE LIST BRANCH TOO.  The shell branch has always skipped
    ``cmd /c`` / ``env VAR=x`` / ``winpty`` / ``wine`` before reading the command word; the Python
    LIST branch took ``elems[0]`` verbatim. So the byte-identical launcher was caught as a .sh and
    MISSED as a .py: ``subprocess.run(["cmd", "/c", GAME])``, ``Popen(["env", "SDL=x", GAME])``,
    ``["wine", GAME]``, ``["gdb", "--args", GAME]``, ``["timeout", "300", GAME]``,
    ``["winpty", GAME]`` - all measured clean, all opening a real foreground window on a
    Windows-first repo. Both branches now go through the SAME leader-stripping tokenizer
    (``_sh_command_words``), and an element sitting after ``-c``/``/c``/``-Command`` is re-scanned
    as its own shell command line exactly as ``_sh_lines`` does for shell files.
  * ASYNC SPAWNS COUNT.  ``asyncio.create_subprocess_exec`` / ``create_subprocess_shell`` are
    process spawns; an async console driver is a plausible next tool. So is
    ``functools.partial(subprocess.Popen, [GAME, ...])``, where the spawn name is not followed by
    ``(`` - that is handled by reading the partial's remaining arguments as the command line.

The probe matrix in tools/desktop-lock-rogue-proof is built as RULE x BRANCH (python-list,
python-string, python-kwarg, shell, batch, powershell) precisely because the defects have all
lived where two branches disagreed, not in any one branch's depth.
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
# asyncio.create_subprocess_exec/_shell are spawns too - an async console driver is a plausible
# next tool, and review 3 MEASURED `await asyncio.create_subprocess_exec(GAME, "--no-splash")`
# scanning clean.
_SPAWN_NAMES = (
    r"subprocess\s*\.\s*(?:Popen|run|call|check_call|check_output)"
    r"|Popen"
    r"|os\s*\.\s*(?:startfile|system|popen|exec\w*|spawn\w*)"
    r"|(?:asyncio\s*\.\s*)?create_subprocess_(?:exec|shell)")
PY_SPAWN = re.compile(r"\b(?:%s)\s*\(" % _SPAWN_NAMES)
# `functools.partial(subprocess.Popen, [GAME, ...])`: the spawn name is NOT followed by `(`, so
# PY_SPAWN cannot see it. The partial's remaining arguments ARE the command line.
PY_PARTIAL = re.compile(r"\b(?:functools\s*\.\s*)?partial\s*\(")
SPAWN_NAME = re.compile(r"^\s*(?:%s)\s*$" % _SPAWN_NAMES)
# The two subprocess kwargs that ARE the command line, rather than a setting beside it.
ARGV_KWARGS = ("args", "executable")
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
# Leading words that are NOT the command: shells, wrappers, env-setters, launch verbs. Review 3
# MEASURED every one of wine/gdb/timeout/winpty/env/cmd-/c as an evasion in the PYTHON LIST
# branch, where this table was not consulted at all - while the byte-identical .sh was caught.
# Both branches now share it (see _command_words / _list_command_exprs).
SH_LEADERS = re.compile(
    r"^(?:exec|start|[Ss]tart-[Pp]rocess|nohup|command|time|sudo|then|do|else|elif|if|while|until|"
    r"[A-Za-z_]\w*=\S*|[-/][cC]|cmd(?:\.exe)?|call|winpty|env|"
    r"wine|wine64|gdb|lldb|valgrind|strace|timeout|stdbuf|xvfb-run|"
    r"powershell(?:\.exe)?|pwsh(?:\.exe)?|bash|sh|zsh|dash)$")
# After a leader has been consumed, an option or a bare number is still not the command word:
# `gdb --args <game>`, `timeout 300 <game>`, `env -i <game>`. Only applied AFTER a real leader,
# so a plain `tail -n 50 "$LOGS/x.log"` still has argv[0] == "tail" and stays clean.
SH_LEADER_NOISE = re.compile(r"^(?:[-/][^\s]*|\d+(?:\.\d+)?[smhd]?)$")
# The option whose VALUE is another command line: `bash -c "..."`, `cmd /c "..."`, and - new in
# review 3 - `powershell -Command "..."`. The byte-identical intent as `bash -c` was caught
# (rogue 16) while the powershell spelling MEASURED clean, which is the rule disagreeing with
# itself across two branches rather than a missing depth.
SH_NESTED_OPT = re.compile(r"^(?:-c|/[cCkK]|-[Cc]ommand|-[Ee]ncoded[Cc]ommand)$")
# `bash -c "<command line>"` / `cmd /c "<command line>"` / `powershell -Command "<...>"`: the game
# word hides inside a quoted argument, so the contents are re-scanned as their own shell line.
SH_DASH_C = re.compile(
    r"""(?:^|\s)(?:-c|/[cCkK]|-[Cc]ommand|-[Ee]ncoded[Cc]ommand)\s+(['"])(.*?)\1""")


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


def _literal(expr):
    """The text of `expr` if it is a plain string literal, else None."""
    m = re.fullmatch(r"(?:[rbuf]*)(['\"])(.*)\1", expr.strip(), re.S)
    return m.group(2) if m else None


def _command_words(toks):
    """Shell tokens with leaders, empty tokens and post-leader noise stripped.

    ONE tokenizer for both branches (review 3). The shell branch always stripped leaders before
    reading the command word; the Python list branch did not, so the same launcher was caught as
    a .sh and missed as a .py. `-c`/`/c`/`-Command` are leaders too, so the command line they
    carry is what gets read next - exactly as _sh_lines re-scans it for shell files.
    """
    out = list(toks)
    saw_leader = False
    while out:
        head = out[0].strip("\"'")
        if not head:
            out.pop(0)
            continue
        if SH_LEADERS.match(head):
            saw_leader = True
            out.pop(0)
            continue
        if saw_leader and SH_LEADER_NOISE.match(head):
            out.pop(0)
            continue
        break
    return out


def _string_argv0(s):
    """argv[0] of a plain shell command line, re-quoted so bare `oolite` stays a complete literal."""
    words = _command_words(s.split())
    return '"%s"' % words[0].strip("\"'") if words else ""


def _list_command_exprs(elems):
    """Candidate argv[0] expressions of a Python list/tuple command line.

    The list branch now obeys the same leader rule as the shell branch: `["cmd","/c",GAME]`,
    `["env","SDL=x",GAME]`, `["wine",GAME]`, `["gdb","--args",GAME]`, `["timeout","300",GAME]`
    and `["winpty",GAME]` all resolve to GAME. An element that FOLLOWS a nested-command option is
    additionally re-scanned as its own shell command line, since it holds a command line rather
    than a program path.
    """
    out, nested_next, saw_leader = [], False, False
    for raw in elems:
        expr = raw.strip()
        if not expr:
            continue
        lit = _literal(expr)
        if nested_next:
            # `["bash","-c", "<command line>"]`: the whole element is a command line.
            out.append(_string_argv0(lit) if lit is not None else expr)
            return out
        if lit is not None and SH_NESTED_OPT.match(lit.strip()):
            nested_next = saw_leader = True
            continue
        if lit is not None and SH_LEADERS.match(lit.strip()):
            saw_leader = True
            continue
        if lit is not None and not lit.strip():
            continue
        if lit is not None and saw_leader and SH_LEADER_NOISE.match(lit.strip()):
            continue
        out.append(expr)
        return out
    return out


def _value_command_exprs(value):
    """Candidate argv[0] expressions for one command-line VALUE (list, string or bare name)."""
    first = value.strip()
    if not first:
        return []
    if first[:1] in "[(":
        close = {"[": "]", "(": ")"}[first[0]]
        end = first.rfind(close)
        elems = _split_top(first[1:end if end > 0 else len(first)])
        return _list_command_exprs(elems)
    lit = _literal(first)
    if lit is not None:
        # A plain string command line (shell=True, os.system, create_subprocess_shell).
        got = _string_argv0(lit)
        return [got] if got else []
    # A command line BUILT from a leading literal: `"tail -n 50 " + LOGS`, `"tail %s" % LOGS`.
    # argv[0] is inside that literal, so read it there rather than tainting the whole expression -
    # otherwise the shell-string branch would flag the log reader that the list branch correctly
    # ignores, which is the same two-branches-disagree defect pointed the other way.
    #
    # Only trusted when the literal CONTAINS the whole command word: another token follows it or
    # it ends in whitespace, AND that word is not itself a substitution placeholder.
    # `"%s --no-splash" % GAME` and `"{} --no-splash".format(GAME)` put argv[0] in the SUBSTITUTED
    # value, so they fall through to the conservative whole-expression form and are still caught;
    # so do `"%s" % GAME` and `"wine " + GAME`.
    m = re.match(r"(?:[rbuf]*)(['\"])((?:\\.|(?!\1).)*)\1", first, re.S)
    if m and m.end() < len(first):
        lit_text = m.group(2)
        words = _command_words(lit_text.split())
        if (words and (len(words) > 1 or lit_text != lit_text.rstrip())
                and not re.search(r"%[-#0 +]*\d*(?:\.\d+)?[a-zA-Z%]|\{[^}]*\}|\$\{?\w", words[0])):
            return ['"%s"' % words[0].strip("\"'")]
    return [first]


def argv0_exprs(call_args, extra_positional=0):
    """Every expression that can become argv[0] of a spawn, given the call's '(...)' text.

    This is THE detection rule: only the command position counts. `["tail", "-n", LOGS]` has
    argv[0] `"tail"` and is not a launch however much the rest of it mentions the game.

    TWO KWARGS ARE THE COMMAND POSITION (review 3). Attempt 3 discarded every `name=` argument as
    "a kwarg", including subprocess's own DOCUMENTED `args=` and the `executable=` that overrides
    what actually runs; `subprocess.run(args=[GAME, "--no-splash"])` and
    `Popen(["game"], executable=GAME)` both MEASURED clean. Every OTHER kwarg is still ignored -
    that restriction is what keeps the two measured false positives dead.

    `extra_positional` skips leading positionals that are not the command line, which is how
    `functools.partial(subprocess.Popen, [GAME, ...])` is read.
    """
    inner = call_args.strip()
    if inner.startswith("("):
        inner = inner[1:-1] if inner.endswith(")") else inner[1:]
    parts = _split_top(inner)
    positional, kwargs = [], []
    for p in parts:
        m = re.match(r"^\s*([A-Za-z_]\w*)\s*=(?!=)(.*)$", p, re.S)
        if m:
            kwargs.append((m.group(1), m.group(2)))
        else:
            positional.append(p)
    out = []
    positional = positional[extra_positional:]
    if positional:
        out.extend(_value_command_exprs(positional[0]))
    for name, value in kwargs:
        if name in ARGV_KWARGS:
            out.extend(_value_command_exprs(value))
    return [e for e in out if e]


def argv0_expr(call_args):
    """Back-compatible single-expression form of :func:`argv0_exprs`."""
    got = argv0_exprs(call_args)
    return got[0] if got else ""


def _is_launch(exprs, names):
    return any(GAME.search(e) or _refs(e, names) for e in exprs)


def spawns_python(text):
    body = strip_py_comments(text)
    if TRANSPORT.search(body):
        return True
    names = game_names_python(body)
    for m in PY_SPAWN.finditer(body):
        args = balanced(body, body.index("(", m.end() - 1))
        if _is_launch(argv0_exprs(args), names):
            return True
    # `functools.partial(subprocess.Popen, [GAME, ...])` - the spawn name is an ARGUMENT here, so
    # it is never followed by '(' and PY_SPAWN cannot see it. The reviewer judged this shape lower
    # realism than the rest; it is handled anyway rather than documented as a hole.
    for m in PY_PARTIAL.finditer(body):
        args = balanced(body, body.index("(", m.end() - 1))
        inner = args.strip()
        if inner.startswith("("):
            inner = inner[1:-1] if inner.endswith(")") else inner[1:]
        parts = _split_top(inner)
        if parts and SPAWN_NAME.match(parts[0]):
            if _is_launch(argv0_exprs(args, extra_positional=1), names):
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
            # ONE tokenizer, shared with the Python list branch: leaders, empty tokens (so
            # `start "" "%APP%\oolite.exe"` cannot hide behind an empty title) and post-leader
            # options all strip before the command word is read.
            toks = _command_words(seg.split())
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
