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
    argv = entry.get("arguments") or shlex.split(entry["command"], posix=False)
    # shlex with posix=False keeps the surrounding quotes meson emits.
    argv = [a[1:-1] if len(a) > 1 and a[0] == a[-1] == '"' else a for a in argv]

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
