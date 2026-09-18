#!/usr/bin/env python3
"""Detect iteration-order-dependent gameplay paths in Oolite (bead oo-djn, seam 0.1b).

WHAT THIS IS FOR

`OOEnumerationShuffle` (seam 0.1a, OOEnumerationShuffle.h) randomises NSDictionary/NSSet
enumeration order in a debug build under $OO_SHUFFLE_ENUMERATION. That instrumentation only
tells you something if somebody compares the runs, which is what this does: it launches the
smoke test once per seed, reduces each Latest.log to its order-sensitive gameplay lines, and
requires every run to produce the SAME sequence.

A difference is an order-dependency bug in the GAME, not in the shuffle: the C++ port will
have a different hash order, and any gameplay that reads correct today only because of
GNUstep's order is a latent defect with no reference implementation left to diff against.

    tools/check-enumeration-order.py                       # baseline + 9 seeds = 10 runs
    tools/check-enumeration-order.py --seeds 1 2 3          # explicit seed list
    tools/check-enumeration-order.py --control-only         # just the positive control
    tools/check-enumeration-order.py --self-test            # offline; no built game

THE POSITIVE CONTROL IS NOT OPTIONAL (docs/fleet/LEARNINGS.md)

Two runs at the SAME setting must normalise identically. If they do not, the normaliser or
the launch environment is broken and NO row in the table means anything, so `--control-only`
runs exactly that row and every full sweep runs it first. A sweep whose control fails exits
non-zero naming the control, never reporting the seed comparisons as a result.

VERBOSE LOGGING, WITHOUT TOUCHING THE TEST

The stock log shows ~16 gameplay lines, far too coarse to see an ordering difference. Log
verbosity is raised by dropping a throwaway resource root holding Config/logcontrol.plist and
naming it in $OO_ADDITIONALADDONSDIRS, which ResourceManager treats as a search root and
launch_snapshot.py passes through (launch_snapshot.py:501). Same mechanism the golden harness
uses for the console port. Nothing under tests/ is modified.

THE PATH BOUNDARY (docs/fleet/LEARNINGS.md)

Every path handed to the native python or to the game is converted with `cygpath -m` and
asserted absolute. `cygpath -m ./x` returns a RELATIVE "x", which the game then resolves
against its own staged cwd - that silently disabled the verbose logcontrol and made the
positive control fail, so absoluteness is asserted rather than assumed.
"""

import argparse
import collections
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OOLITE = os.path.join(REPO_ROOT, "upstream", "oolite")
SNAPSHOT = os.path.join(OOLITE, "tests", "launch_snapshot.py")
DEBUG_APP = os.path.join(OOLITE, "build", "meson_debug", "oolite.app")

# Nine seeds plus the unshuffled baseline: ten consecutive runs of the smoke test.
DEFAULT_SEEDS = [1, 7, 42, 1337, 424242, 65537, 2147483647, 99991, 31337]

# Raise log verbosity to everything; the normaliser below drops what is not gameplay.
LOGCONTROL = "{\n\t_override = yes;\n}\n"


# --- normalisation -------------------------------------------------------------------------
#
# What survives is the ORDER and IDENTITY of gameplay events. What is dropped is anything
# that legitimately differs run to run on one machine: the wall clock, this box's GL driver,
# this run's temp directories and pointer-shaped values, and the shuffle's own banner (which
# names the seed and would make every seed differ trivially).

_STAMP = re.compile(r"\d\d:\d\d:\d\d\.\d\d\d ")
_CLASS = re.compile(r"^\s*\[([a-zA-Z0-9_.$]+)\]: ")
_NOISE_CLASS = re.compile(
    r"^(display|rendering|joystick|MSAA|process|searchPaths|screenshot|startup|"
    r"gameController|debugTCP|debugConsole|sdl|temp|oxz|exception\.backtrace|"
    r"script\.javaScript\.timeLimit|debug\.shuffleEnumeration|"
    # universe.profile.* is emitted ONCE PER RENDERED FRAME, so its count tracks how many
    # frames the machine drew before the snapshot - measured 12018 vs 12001 lines for two
    # identical unshuffled runs. That is scheduler noise, not enumeration order, and it made
    # the positive control fail. Dropped so the control can detect a REAL instrument fault.
    r"universe\.profile|"
    # texture.load.asyncLoad* is logged from -performAsyncTask, which runs on an
    # OOAsyncWorkManager LOADER THREAD (OOTextureLoader.m:100,313-332). Its position in the
    # log is decided by thread scheduling, so it moved between two identical unshuffled runs.
    # The texture SET being loaded still shows up in the deterministic classes around it; only
    # the async completion notice is dropped.
    r"texture\.load\.asyncLoad|"
    # sound.buffer is logged from -[OOALSoundChannel update] (OOALSoundChannel.m:74-98),
    # which polls the OpenAL source EVERY FRAME and logs once per poll that finds the
    # streaming decode still behind. How many times that happens is a race between the
    # decoder and the frame rate - one extra "Incomplete, trying next for OoliteTheme.ogg"
    # appeared in one of two identical unshuffled runs. Timing, not enumeration order.
    r"sound\.buffer)"
)
_NOISE_LINE = re.compile(
    r"Opening log for|processors detected|Build options:|Closing log at|"
    r"contents of the log file|GL_[A-Z]|oolite-run-\d+|oolite-console-|"
    r"Loading complete in|0x[0-9a-fA-F]{6,}|Temp[/\\]"
)


def gameplay_lines(log_path):
    """The order-sensitive gameplay lines of one Latest.log.

    A long OOLog message WRAPS, and the continuation lines carry no "[class]:" prefix, so a
    naive per-line class filter lets them through. They are attributed to the class of the
    line they continue - otherwise the tail of a filtered message survives while its head is
    dropped, which is how a texture-description continuation ("...,  loading}", whose text
    depends on whether the async generator thread had finished) leaked past the filter and
    was misreported as a content difference.
    """
    out = []
    current = None
    with open(log_path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = _STAMP.sub("", raw.rstrip("\r\n")).strip()
            if not line or _NOISE_LINE.search(line):
                continue
            match = _CLASS.match(line)
            if match:
                current = match.group(1)
            # else: no prefix, so this continues the previous message and keeps its class.
            if current and _NOISE_CLASS.match(current):
                continue
            out.append(re.sub(r"\b\d+\.\d+\b", "<f>", line))
    return out


# --- log-order-only channels ---------------------------------------------------------------
#
# A reordering that is VISIBLE IN THE LOG is not automatically an order-dependent GAMEPLAY
# path, and this bead is scoped to gameplay. A channel earns a place in this table only when
# its container has been traced to EVERY consumer and every consumer is order-INSENSITIVE
# (set membership, a count, an aggregation) rather than order-SENSITIVE (indexing, first
# match, a loop that picks a winner, anything feeding RNG draw order).
#
# Being in this table downgrades the channel from a failure to a reported classification, so
# the next agent is not sent chasing a known-benign reordering - but a channel NOT in it is a
# hard failure, and a CONTENT difference is a hard failure whatever the channel. Add an entry
# only with the consumer trace written out, and never to quieten a channel you have not traced.

LOG_ORDER_ONLY = {
    "shipData.load.roleCategories": (
        "ResourceManager.m:1836, emitted once per key by +mergeRoleCategories: while "
        "enumerating an NSDictionary (:1827). The ORDER is nondeterministic, but the DATA is "
        "not: each value is an NSMutableSet filled with -addObjectsFromArray: (:1832-1837) and "
        "set union is commutative. The built dictionary has exactly ONE read site - "
        "Universe.m:3013 -role:isInCategory:, which does objectForKey: then containsObject:, a "
        "set membership test - and all seven callers of that (ShipEntity.m:7344/7350/7374/7380/"
        "7392, PlayerEntity.m:5042, OOJSShip.m:4337) use it as a BOOL predicate. It is never "
        "enumerated and never indexed, so insertion order cannot reach gameplay."
    ),
}


def classify_divergences(a, b):
    """Which channels differ positionally, and is any difference a CONTENT difference?

    Returns (channels, content_only_lines). `channels` is the set of message classes seen at
    a positional divergence; `content_only_lines` is non-empty when the two runs do not even
    hold the same multiset of lines, which is never mere ordering.
    """
    ca, cb = collections.Counter(a), collections.Counter(b)
    content = list((ca - cb).elements()) + list((cb - ca).elements())
    channels = set()
    for x, y in zip(a, b):
        if x != y:
            for text in (x, y):
                match = _CLASS.match(text)
                channels.add(match.group(1) if match else "<no message class>")
    for text in content:
        match = _CLASS.match(text)
        channels.add(match.group(1) if match else "<no message class>")
    return channels, content


def describe_difference(a, b, label_a, label_b, limit=8):
    """Human-readable account of how two normalised runs differ."""
    ca, cb = collections.Counter(a), collections.Counter(b)
    only_a, only_b = ca - cb, cb - ca
    lines = [f"    {label_a}: {len(a)} lines   {label_b}: {len(b)} lines"]
    if only_a or only_b:
        lines.append("    the runs differ in CONTENT, not only in order:")
        for text in list(only_a)[:limit]:
            lines.append(f"      only in {label_a} | {text[:170]}")
        for text in list(only_b)[:limit]:
            lines.append(f"      only in {label_b} | {text[:170]}")
    else:
        lines.append("    PURE REORDERING: identical multiset of lines, different sequence")
        shown = 0
        for i, (x, y) in enumerate(zip(a, b)):
            if x != y:
                lines.append(f"      at index {i}:")
                lines.append(f"        {label_a} | {x[:160]}")
                lines.append(f"        {label_b} | {y[:160]}")
                shown += 1
                if shown >= limit:
                    break
    return "\n".join(lines)


# --- launching -----------------------------------------------------------------------------


def native(path):
    """A path a NATIVE Windows program can resolve. Asserts the result is absolute."""
    if not os.path.isabs(path):
        path = os.path.abspath(path)
    if shutil.which("cygpath"):
        converted = subprocess.run(
            ["cygpath", "-m", path], capture_output=True, text=True, check=False
        ).stdout.strip()
        if converted:
            path = converted
    # A relative result means the conversion silently failed; the game would resolve it
    # against its own staged cwd and the setting would be inert.
    if not (path.startswith("/") or re.match(r"^[A-Za-z]:", path)):
        raise RuntimeError(f"native() produced a non-absolute path: {path!r}")
    return path


def run_once(app_dir, verbose_root, out_dir, seed, port, timeout):
    """One smoke launch. Returns (gameplay_lines, wall_seconds) or (None, wall) on failure."""
    os.makedirs(out_dir, exist_ok=True)
    log = os.path.join(out_dir, "Latest.log")
    if os.path.exists(log):
        os.remove(log)

    env = dict(os.environ)
    if seed is None:
        env.pop("OO_SHUFFLE_ENUMERATION", None)
    else:
        env["OO_SHUFFLE_ENUMERATION"] = str(seed)
    existing = env.get("OO_ADDITIONALADDONSDIRS")
    env["OO_ADDITIONALADDONSDIRS"] = (
        f"{verbose_root},{existing}" if existing else verbose_root
    )

    label = "baseline" if seed is None else f"seed {seed}"
    started = time.time()
    proc = subprocess.run(
        [
            sys.executable, native(SNAPSHOT),
            "--path", native(app_dir),
            "--output", native(out_dir),
            "--port", str(port),
        ],
        env=env, capture_output=True, text=True, timeout=timeout, check=False,
    )
    wall = time.time() - started

    if proc.returncode != 0:
        print(f"FAILED step=launch ({label}) rc={proc.returncode} wall={wall:.0f}s")
        print("    ---- launch_snapshot.py stdout (tail) ----")
        for line in proc.stdout.strip().splitlines()[-12:]:
            print("    " + line)
        for line in proc.stderr.strip().splitlines()[-6:]:
            print("    " + line, file=sys.stderr)
        return None, wall
    if not os.path.isfile(log):
        print(f"FAILED step=log-missing ({label}) no Latest.log in {out_dir} wall={wall:.0f}s")
        return None, wall

    lines = gameplay_lines(log)
    # A run that logged almost nothing did not play the game: either the verbose logcontrol
    # never took effect or the game died early. Counting it as agreement would make this
    # whole check vacuous, which is exactly the failure mode the control exists to catch.
    if len(lines) < 200:
        print(
            f"FAILED step=log-too-sparse ({label}) only {len(lines)} gameplay lines; "
            f"the verbose logcontrol did not take effect, so no comparison is meaningful"
        )
        return None, wall
    shutil.copyfile(log, os.path.join(out_dir, os.pardir, f"gameplay-{label.replace(' ', '')}.log"))
    return lines, wall


def sweep(seeds, with_baseline, app_dir, base_port, timeout, keep):
    work = tempfile.mkdtemp(prefix="oo-enum-order-")
    verbose_root = os.path.join(work, "verbose")
    os.makedirs(os.path.join(verbose_root, "Config"), exist_ok=True)
    with open(os.path.join(verbose_root, "Config", "logcontrol.plist"), "w") as fh:
        fh.write(LOGCONTROL)
    verbose_native = native(verbose_root)

    runs = []          # (label, lines)
    failures = []
    port = base_port
    started = time.time()

    plan = []
    # THE POSITIVE CONTROL, FIRST AND ALWAYS: two runs at the same setting.
    plan.append(("control-a", None))
    plan.append(("control-b", None))
    if with_baseline:
        plan.append(("baseline", None))
    for seed in seeds:
        plan.append((f"seed-{seed}", seed))

    for label, seed in plan:
        out_dir = os.path.join(work, label)
        lines, wall = run_once(app_dir, verbose_native, out_dir, seed, port, timeout)
        port += 1
        if lines is None:
            failures.append(label)
            continue
        print(f"    run {label:16s} gameplay_lines={len(lines):5d} wall={wall:5.1f}s")
        runs.append((label, lines))

    elapsed = time.time() - started
    print(f"\n    {len(runs)} run(s) completed, {len(failures)} failed, {elapsed:.0f}s total")

    if failures:
        print(f"FAILED step=runs the following runs did not complete: {', '.join(failures)}")
        if not keep:
            shutil.rmtree(work, ignore_errors=True)
        return 1, elapsed

    by_label = dict(runs)
    rc = 0

    # --- the control ------------------------------------------------------------------------
    ctrl_a, ctrl_b = by_label["control-a"], by_label["control-b"]
    if ctrl_a != ctrl_b:
        print("FAILED step=positive-control two runs at the SAME setting normalised "
              "differently, so the instrument is broken and no seed comparison below is "
              "interpretable:")
        print(describe_difference(ctrl_a, ctrl_b, "control-a", "control-b"))
        if not keep:
            shutil.rmtree(work, ignore_errors=True)
        return 1, elapsed
    print(f"    positive control OK: two unshuffled runs agree on all "
          f"{len(ctrl_a)} gameplay lines")

    # --- the actual question ----------------------------------------------------------------
    reference_label, reference = runs[0]
    identical = 0
    differing = []
    for label, lines in runs:
        if lines == reference:
            identical += 1
        else:
            differing.append((label, lines))

    print(f"    agreement: {identical}/{len(runs)} runs byte-identical to {reference_label}")

    # --- classify, do not just fail --------------------------------------------------------
    #
    # A reordering in a channel already TRACED to order-insensitive consumers is reported and
    # allowed; anything else - an untraced channel, or a content difference - fails.
    if differing:
        all_channels = set()
        content_diffs = []
        for label, lines in differing:
            channels, content = classify_divergences(lines, reference)
            all_channels |= channels
            content_diffs.extend((label, text) for text in content)

        unexplained = sorted(c for c in all_channels if c not in LOG_ORDER_ONLY)
        explained = sorted(c for c in all_channels if c in LOG_ORDER_ONLY)

        for chan in explained:
            print(f"    LOG-ORDER ONLY: [{chan}] reordered in "
                  f"{len(differing)}/{len(runs)} runs")
            print(f"      traced: {LOG_ORDER_ONLY[chan]}")

        if content_diffs:
            print(f"FAILED step=content-difference {len(content_diffs)} line(s) are present in "
                  f"one run and not another; that is never mere ordering:")
            for label, text in content_diffs[:10]:
                print(f"      {label} | {text[:170]}")
            print(f"    artifacts kept under {work}")
            return 1, elapsed

        if unexplained:
            print(f"FAILED step=order-dependence {len(unexplained)} channel(s) reordered that "
                  f"have NOT been traced to order-insensitive consumers: "
                  f"{', '.join(unexplained)}")
            print("    Trace each container to EVERY consumer. If a consumer indexes, takes a "
                  "first match, picks a winner, or feeds an RNG draw, that is an "
                  "order-dependent GAMEPLAY path: sort at that site. If every consumer is "
                  "order-insensitive, add the channel to LOG_ORDER_ONLY WITH the trace.")
            for label, lines in differing[:2]:
                print(f"  --- {label} vs {reference_label} ---")
                print(describe_difference(lines, reference, label, reference_label))
            print(f"    artifacts kept under {work}")
            return 1, elapsed

        print(f"    every reordering is in a channel traced to order-insensitive consumers, "
              f"and all {len(runs)} runs hold the IDENTICAL multiset of gameplay lines")

    if keep:
        print(f"    artifacts kept under {work}")
    else:
        shutil.rmtree(work, ignore_errors=True)
    return rc, elapsed


# --- offline self-test ---------------------------------------------------------------------
#
# Proves the normaliser and the difference reporter work with no built game and no desktop,
# so this file still gates something real in accept.sh's build-less checkout. Each case is a
# property the sweep above depends on, and each is checked in BOTH directions.


def self_test():
    work = tempfile.mkdtemp(prefix="oo-enum-order-selftest-")
    failures = []

    def check(name, condition, detail=""):
        if condition:
            print(f"    ok   {name}")
        else:
            print(f"    FAIL {name} {detail}")
            failures.append(name)

    def write(name, body):
        path = os.path.join(work, name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(body)
        return path

    head = (
        "Opening log for Oolite version 0.0.0 by nobody at 2026-01-01 00:00:00 +0000.\n"
        "8 processors detected. System RAM: 1 MB (free: 1 MB).\n"
    )
    play = (
        "00:00:01.000 [shipData.load.begin]: Loading ship data.\n"
        "00:00:01.100 [shipData.load.progress]: Finished applying patches...\n"
        "00:00:01.200 [player.equipmentScript]: Added equipment EQ_FUEL_SCOOPS.\n"
    )
    tail = "Closing log at 2026-01-01 00:00:09 +0000.\n"

    # 1. Volatile noise is dropped: two logs differing ONLY in stamps/machine/GL normalise equal.
    a = write("a.log", head + play + "00:00:02.000 [display.initGL]: Red: 8\n" + tail)
    b = write(
        "b.log",
        "Opening log for Oolite version 0.0.0 by nobody at 2026-06-06 06:06:06 +0000.\n"
        "24 processors detected. System RAM: 9 MB (free: 9 MB).\n"
        + play.replace("00:00:01", "11:22:33")
        + "11:22:34.000 [display.initGL]: Red: 16\n"
        + "Closing log at 2026-06-06 06:06:59 +0000.\n",
    )
    na, nb = gameplay_lines(a), gameplay_lines(b)
    check("timestamps/machine/GL noise is normalised away", na == nb, f"{na} != {nb}")
    check("normalisation keeps the gameplay lines", len(na) == 3, f"kept {len(na)}")

    # 2. A REORDERING is detected - the whole point. Same lines, different order.
    reordered = write(
        "reordered.log",
        head
        + "00:00:01.000 [player.equipmentScript]: Added equipment EQ_FUEL_SCOOPS.\n"
        + "00:00:01.100 [shipData.load.begin]: Loading ship data.\n"
        + "00:00:01.200 [shipData.load.progress]: Finished applying patches...\n"
        + tail,
    )
    nr = gameplay_lines(reordered)
    check("a pure reordering is NOT normalised away", nr != na)
    check("a pure reordering has the same multiset",
          collections.Counter(nr) == collections.Counter(na))
    report = describe_difference(nr, na, "reordered", "original")
    check("the report names a reordering as such", "PURE REORDERING" in report)

    # 3. A CONTENT difference is reported as content, not as order.
    extra = write("extra.log", head + play + "00:00:03.000 [ai.message.receive]: PIRATE.\n" + tail)
    report2 = describe_difference(gameplay_lines(extra), na, "extra", "original")
    check("a content difference is reported as content", "differ in CONTENT" in report2)
    check("the report quotes the differing line", "PIRATE" in report2)

    # 4. The shuffle's own banner must not make every seed differ trivially.
    banner = write(
        "banner.log",
        head
        + "00:00:00.500 [debug.shuffleEnumeration]: order is SHUFFLED, seed 12345\n"
        + play + tail,
    )
    check("the shuffle banner is excluded from the comparison",
          gameplay_lines(banner) == na)

    # 5. native() refuses to hand a relative path to a native program (the defect that
    #    silently disabled the verbose logcontrol and broke the positive control).
    check("native() returns an absolute path for a relative input",
          re.match(r"^([A-Za-z]:|/)", native("./verbose")) is not None,
          native("./verbose"))

    # 6. The classifier separates a TRACED log-order channel from an untraced one. Both
    #    directions, because a classifier that only ever says "benign" is not a check.
    traced = next(iter(LOG_ORDER_ONLY))
    benign_a = [f"[{traced}]: Adding 1 entries for category x",
                f"[{traced}]: Adding 2 entries for category y"]
    benign_b = list(reversed(benign_a))
    chans, content = classify_divergences(benign_a, benign_b)
    check("a reordering in a traced channel is recognised", chans == {traced}, str(chans))
    check("a reordering reports no content difference", content == [], str(content))
    check("a traced channel is classified as log-order-only",
          all(c in LOG_ORDER_ONLY for c in chans))

    rogue_a = ["[ai.message.receive]: ATTACKER", "[ai.message.receive]: VICTIM"]
    rogue_b = list(reversed(rogue_a))
    chans2, _ = classify_divergences(rogue_a, rogue_b)
    check("an UNTRACED reordered channel is not excused",
          chans2 and not all(c in LOG_ORDER_ONLY for c in chans2), str(chans2))

    # 7. A CONTENT difference is caught even in a traced channel - being on the log-order
    #    allow-list must never excuse a line appearing in one run and not another.
    extra_a = benign_a + [f"[{traced}]: Adding 3 entries for category z"]
    chans3, content3 = classify_divergences(extra_a, benign_a)
    check("a content difference in a TRACED channel is still reported as content",
          len(content3) == 1, str(content3))

    # 8. Every LOG_ORDER_ONLY entry carries a real consumer trace, so the allow-list cannot
    #    grow by silently adding a bare channel name.
    check("every LOG_ORDER_ONLY entry cites a source file and a consumer",
          all(".m:" in v and len(v) > 120 for v in LOG_ORDER_ONLY.values()))

    shutil.rmtree(work, ignore_errors=True)
    if failures:
        print(f"FAILED step=self-test {len(failures)} case(s) failed: {', '.join(failures)}")
        return 1
    print("check-enumeration-order --self-test: PASS")
    return 0


def check_finding():
    """Assert this bead's FINDING is still intact and its classifier still discriminates.

    The deliverable of bead oo-djn is a negative result: under the shuffle, exactly one log
    channel reorders, and it is benign because every consumer of its container is
    order-insensitive. That conclusion lives in LOG_ORDER_ONLY, and it is only worth
    anything while the trace is present and the classifier can still fail. Offline.
    """
    failures = []

    def check(name, condition, detail=""):
        if condition:
            print(f"    ok   {name}")
        else:
            print(f"    FAIL {name} {detail}")
            failures.append(name)

    key = "shipData.load.roleCategories"
    check(f"{key} is still classified", key in LOG_ORDER_ONLY)
    if key in LOG_ORDER_ONLY:
        trace = LOG_ORDER_ONLY[key]
        for citation in ("ResourceManager.m:1836", "Universe.m:3013",
                         "containsObject:", "NSMutableSet"):
            check(f"the trace still cites {citation}", citation in trace)

    # The classifier must discriminate in BOTH directions, or the allow-list is decoration.
    benign = [f"[{key}]: Adding 1 entries for category x",
              f"[{key}]: Adding 2 entries for category y"]
    channels, content = classify_divergences(benign, list(reversed(benign)))
    check("a reordering in the traced channel is recognised", channels == {key}, str(channels))
    check("a reordering is not reported as a content difference", content == [], str(content))
    check("the traced channel is treated as log-order-only",
          bool(channels) and all(c in LOG_ORDER_ONLY for c in channels))

    rogue, _ = classify_divergences(["[ai.message.receive]: A"], ["[ai.message.receive]: B"])
    check("an untraced channel is NOT excused",
          bool(rogue) and not all(c in LOG_ORDER_ONLY for c in rogue), str(rogue))

    _, extra = classify_divergences(benign + [f"[{key}]: Adding 3 for z"], benign)
    check("a content difference in the traced channel is still reported", len(extra) == 1,
          str(extra))

    if failures:
        print(f"FAILED step=check-finding {len(failures)} case(s): {', '.join(failures)}")
        return 1
    print("check-enumeration-order --check-finding: PASS")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seeds", type=int, nargs="*", default=None,
                        help="shuffle seeds to run (default: nine fixed seeds)")
    parser.add_argument("--no-baseline", action="store_true",
                        help="omit the unshuffled baseline run")
    parser.add_argument("--control-only", action="store_true",
                        help="run only the positive control (two runs, same setting)")
    parser.add_argument("--app-dir", default=os.environ.get("OO_APP_DIR", DEBUG_APP),
                        help="built oolite.app (default: the debug flavour)")
    parser.add_argument("--base-port", type=int,
                        default=int(os.environ.get("OO_CONSOLE_PORT", "8760")))
    parser.add_argument("--timeout", type=float, default=600.0,
                        help="seconds allowed for one launch (default: 600)")
    parser.add_argument("--keep", action="store_true", help="keep the per-run artifacts")
    parser.add_argument("--self-test", action="store_true",
                        help="offline: prove the normaliser and reporter work; no game needed")
    parser.add_argument("--check-finding", action="store_true",
                        help="offline: assert bead oo-djn's classified channel and its "
                             "consumer trace are still present and the classifier still fails")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if args.check_finding:
        return check_finding()

    binary = os.path.join(args.app_dir, "oolite.exe")
    if not os.path.isfile(binary):
        binary = os.path.join(args.app_dir, "oolite")
    if not os.path.isfile(binary):
        print(f"check-enumeration-order: no built game at {args.app_dir}", file=sys.stderr)
        print("  build one with: tools/build-windows.sh debug", file=sys.stderr)
        print("  (the shuffle is compiled only into the debug flavour; see "
              "OOEnumerationShuffle.h)", file=sys.stderr)
        return 2
    if not os.path.isfile(SNAPSHOT):
        print(f"check-enumeration-order: missing {SNAPSHOT}", file=sys.stderr)
        return 2

    seeds = [] if args.control_only else (
        DEFAULT_SEEDS if args.seeds is None else args.seeds
    )
    with_baseline = (not args.no_baseline) and not args.control_only

    print(f"==> enumeration-order sweep: control + "
          f"{'baseline + ' if with_baseline else ''}{len(seeds)} seed(s)")
    rc, elapsed = sweep(seeds, with_baseline, args.app_dir, args.base_port,
                        args.timeout, args.keep)
    # The banner is conditional on rc: a harness that says DONE after a failed step is a
    # check that cannot fail (docs/fleet/LEARNINGS.md).
    if rc == 0:
        print(f"check-enumeration-order: PASS ({elapsed:.0f}s)")
    else:
        print(f"check-enumeration-order: FAIL ({elapsed:.0f}s)")
    return rc


if __name__ == "__main__":
    sys.exit(main())
