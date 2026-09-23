#!/usr/bin/env python3
"""Read one entry out of a meson compile_commands.json for tools/tier-a.sh.

Prints, on stdout, NUL-separated fields:

    <ninja output target> NUL <clang arg> NUL <clang arg> NUL ...

The clang args are the compile command with the compiler driver, the ccache
wrapper, the dependency-file flags, `-c`, `-o <obj>` and the input file removed:
what `clang-tidy <file> -- <args>` wants.  Everything else (include paths,
defines, the Objective-C runtime flags) is kept verbatim, because the whole
point of Tier A is that the TU is parsed exactly as the real build parses it.

Paths are emitted as the compile database has them — relative to the build
directory — so the caller must run clang-tidy with cwd = build directory.
Exits 2 when the file has no entry, which is what the caller reports as
"not in the build".
"""

import json
import os
import shlex
import sys


def norm(path, directory):
    """Absolute, forward-slashed, case-folded: comparable on Windows."""
    joined = path if os.path.isabs(path) else os.path.join(directory, path)
    return os.path.normcase(os.path.normpath(joined)).replace("\\", "/")


def split_windows(command):
    """Split a command line by the MSVC runtime's rules (CommandLineToArgvW).

    This is the quoting meson uses for compile_commands.json on Windows: every
    argument in double quotes, an embedded quote escaped as \\", backslashes
    literal unless they precede a quote.  2n backslashes before a quote give n
    backslashes and the quote delimits; 2n+1 give n backslashes and a literal
    quote.  shlex(posix=False) knows none of this: it cut
    "-DOO_VERSION_FULL=\\"0.0.0-fleet\\"" at the escaped quote (bead oo-3rb.97).
    """
    args = []
    current = []
    in_arg = False
    in_quotes = False
    index = 0
    length = len(command)
    while index < length:
        char = command[index]
        if char == "\\":
            run = index
            while run < length and command[run] == "\\":
                run += 1
            count = run - index
            if run < length and command[run] == '"':
                current.append("\\" * (count // 2))
                if count % 2:
                    current.append('"')
                    run += 1
                index = run
            else:
                current.append("\\" * count)
                index = run
            in_arg = True
            continue
        if char == '"':
            in_quotes = not in_quotes
            in_arg = True
        elif char in " \t" and not in_quotes:
            if in_arg:
                args.append("".join(current))
                current = []
                in_arg = False
        else:
            current.append(char)
            in_arg = True
        index += 1
    if in_arg:
        args.append("".join(current))
    return args


def split_command(command):
    """meson quotes for the host: Windows rules on a native Windows python, POSIX sh otherwise."""
    if os.name == "nt":
        return split_windows(command)
    return shlex.split(command, posix=True)


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("usage: tier-a-compdb.py <compile_commands.json> <source file>\n")
        return 2

    compdb_path, source = sys.argv[1], sys.argv[2]
    with open(compdb_path, encoding="utf-8") as handle:
        entries = json.load(handle)

    wanted = norm(source, os.getcwd())
    entry = next(
        (e for e in entries if norm(e["file"], e["directory"]) == wanted),
        None,
    )
    if entry is None:
        sys.stderr.write(
            "tier-a-compdb: %s has no entry in %s\n" % (source, compdb_path)
        )
        return 2

    # meson writes "command"; support "arguments" too, in case the generator changes.
    argv = entry.get("arguments") or split_command(entry["command"])

    source_in_db = entry["file"]
    output = entry.get("output", "")

    args = []
    skip_next = False
    # argv[0] is ccache.exe and argv[1] the compiler when the ccache native file is
    # in use; a plain build has only the compiler.  Drop every leading non-flag.
    index = 0
    while index < len(argv) and not argv[index].startswith("-"):
        index += 1
    for arg in argv[index:]:
        if skip_next:
            skip_next = False
            continue
        if arg in ("-o", "-MF", "-MQ", "-MT"):
            skip_next = True
            continue
        if arg in ("-c", "-MD", "-MMD"):
            continue
        if arg == source_in_db or norm(arg, entry["directory"]) == wanted:
            continue
        args.append(arg)

    sys.stdout.write("\0".join([output] + args))
    return 0


if __name__ == "__main__":
    sys.exit(main())
