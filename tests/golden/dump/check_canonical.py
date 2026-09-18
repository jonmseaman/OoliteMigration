"""Assert a dump is CANONICAL by inspecting the emitted JSON, not the source text that made it.

The acceptance block's grep lines (toFixed(QUANT_DECIMALS), Object.keys(o).sort(), ents.sort)
match SOURCE TEXT, and a source-text match can be satisfied by a comment, a docstring or the
check's own line - this repo has already been bitten by exactly that. This checker instead reads
the JSON the game actually produced and asserts the three canonical properties structurally:

  1. every object's keys appear in sorted order IN THE EMITTED TEXT (not merely "can be sorted"),
  2. every number carries at most QUANT_DECIMALS decimal places (quantisation really applied),
  3. the entities array is sorted by its id key (stable identity order, not iteration order).

Property 1 needs the raw text, not json.load's dict: a dict preserves insertion order in CPython
but comparing it to a sorted copy is the same assertion, so we use object_pairs_hook to see the
key order exactly as it was written.
"""

import argparse
import json
import sys

QUANT_DECIMALS = 3


class Problem(Exception):
    pass


def _check_pairs(pairs, problems):
    """object_pairs_hook: sees each object's keys in the order they were EMITTED.

    The hook fires bottom-up, before the enclosing object exists, so there is no path to report -
    the offending key list is the identification, and it is unambiguous enough to act on.
    """
    keys = [k for k, _ in pairs]
    if keys != sorted(keys):
        problems.append(
            "an object has keys in non-sorted order: emitted %r, sorted would be %r - canonical "
            "JSON requires sorted keys or the dump inherits NSDictionary hash-iteration order"
            % (keys, sorted(keys))
        )
    return dict(pairs)


def _walk(node, path, problems):
    if isinstance(node, list):
        for i, item in enumerate(node):
            _walk(item, "%s[%d]" % (path, i), problems)
    elif isinstance(node, dict):
        for k, v in node.items():
            _walk(v, "%s.%s" % (path, k), problems)
    elif isinstance(node, float):
        # repr of a float parsed back from the dump: quantisation is TEXTUAL (toFixed), so a value
        # that survived it cannot need more than QUANT_DECIMALS digits to write down.
        text = repr(node)
        if "e" in text or "E" in text:
            problems.append("%s = %s is in exponent form; quantisation did not normalise it"
                            % (path, text))
            return
        if "." in text:
            decimals = len(text.split(".", 1)[1])
            if decimals > QUANT_DECIMALS:
                problems.append(
                    "%s = %s carries %d decimal places, more than QUANT_DECIMALS=%d; the float was "
                    "not quantised and will bit-flip the golden on harmless platform noise"
                    % (path, text, decimals, QUANT_DECIMALS)
                )


def check(text):
    problems = []

    # Key order exactly as emitted (object_pairs_hook), then a second parse for value checks.
    json.loads(text, object_pairs_hook=lambda p: _check_pairs(p, problems))

    data = json.loads(text)
    _walk(data, "", problems)

    for required in ("entities", "market", "player"):
        if required not in data:
            problems.append("dump has no %r key; it is not a world-state dump" % required)

    ents = data.get("entities", [])
    if not isinstance(ents, list) or not ents:
        problems.append("entities is empty or not a list; the check would be vacuous")
    else:
        ids = [e.get("id") for e in ents]
        if any(i is None for i in ids):
            problems.append("some entity has no id: %r" % (ids,))
        elif ids != sorted(ids):
            problems.append(
                "entities are NOT sorted by id: emitted %r, sorted would be %r - the dump is in "
                "system.allShips iteration order and every golden blessed against it is hostage "
                "to entity creation order" % (ids, sorted(ids))
            )

    if not data.get("market"):
        problems.append("market is empty; the check would be vacuous")
    if "credits" not in data.get("player", {}):
        problems.append("player has no credits; the check would be vacuous")

    return problems


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("dump", help="path to a dump JSON produced by run_dump.py")
    args = parser.parse_args(argv)

    with open(args.dump, "r", encoding="utf-8") as handle:
        text = handle.read()

    problems = check(text)
    if problems:
        sys.stderr.write("FAIL: dump %s is not canonical:\n" % args.dump)
        for p in problems:
            sys.stderr.write("  - %s\n" % p)
        return 1
    print("PASS: dump is canonical (sorted keys, entities sorted by id, floats quantised to "
          "%d decimals, non-vacuous)" % QUANT_DECIMALS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
