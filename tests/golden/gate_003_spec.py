"""Gate: scenario 003's determinism knobs are PINNED, READ, and AGREE WITH PROVENANCE.

WHY A SEPARATE FILE AND NOT AN INLINE ONE-LINER IN THE ACCEPTANCE BLOCK
-----------------------------------------------------------------------
Bead oo-3ya's equivalent check was a single `python -c` line of ~2 kB of nested shell quoting.
It worked, but a mutation run found a survivor inside it - the seed was PRINTED and never
PREDICATED - and the quoting made that impossible to see by reading. This is the same set of
checks as an executable file, so each one can be read, and so the acceptance line is short enough
to audit.

THE THREE QUESTIONS, ASKED OF EVERY KNOB
----------------------------------------
  1. IS IT PINNED?   The spec must declare it, with the right type and a sane value.
  2. IS IT READ?     combat.py must actually read `spec["<knob>"]`. A knob the scenario never
                     consults is decoration: changing it changes nothing and no line goes red.
  3. DOES IT MATCH THE GOLDEN?  The staged golden's provenance.json records the knobs the golden
                     was BLESSED with. The spec must equal them.

Question 3 is the one that matters most and the one that is easy to get wrong. A fresh-run-vs-
golden comparison CANNOT catch a changed seed, because changing the seed changes BOTH sides of
that comparison - it re-runs with the new seed and compares against a golden blessed with the
old one only if the golden is stale, and if the golden is re-blessed at the same time the drift
is invisible. Pinning the seed as a literal in this file would be worse: it would make a
deliberate re-bless illegal and invite someone to edit the constant. Agreement with provenance
makes drift fatal while keeping a deliberate re-bless legal.

GOLDEN PATH RESOLUTION: goldens/ is a protected path. tools/guardrails.sh refuses ANY change
under it without a human approval line, and bead oo-8ij proved by A/B control that it does not
distinguish CREATE from MODIFY - so this bead cannot land a golden there. The golden is staged in
tests/golden/pending/003-combat/. The guarded location is searched FIRST so this file keeps
working unchanged after a human re-bless moves it.

EXIT CODES: 0 every knob is pinned, read and agrees with provenance; 1 otherwise (naming the
knob and the disagreement); 2 a usage/structural error that prevented a verdict.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", "003-combat", "spec.json"),
    os.path.join(HERE, "pending", "003-combat", "spec.json"),
)
SCENARIO_SCRIPT = os.path.join(HERE, "combat.py")

# Guarded location first, staged location second - the same order bead oo-3ya's line 5 uses.
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", "003-combat"),
    os.path.join(HERE, "pending", "003-combat"),
)

# Every knob that must be pinned in the spec. The value the scenario is blessed at is NOT
# hardcoded here (that would make a re-bless illegal); only the shape is.
REQUIRED_KNOBS = (
    "seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
    "attacker_key", "victim_key", "attacker_position", "victim_position",
    "strikes", "strike_damage", "strike_range",
)

# Knobs combat.py must demonstrably READ as spec["<knob>"]. load_save, quant_decimals and the
# positions are read through different idioms and are checked separately below.
MUST_BE_READ = (
    "seed", "system_id", "ticks", "tick_seconds", "attacker_key", "victim_key",
    "strikes", "strike_damage", "strike_range", "attacker_position", "victim_position",
    "load_save",
)

# A knob that is READ ONLY TO BE RECORDED IN THE EVIDENCE BLOCK is still decoration: the dump
# reports it faithfully while the behaviour it names is driven by a literal. A plain substring
# search cannot see that - MEASURED: hardcoding the strike amounts at combat.py's ONE behavioural
# call site left `spec["strike_damage"]` present at the evidence-recording site, and a
# substring-only gate stayed GREEN. So each of these knobs must be read inside the FUNCTION that
# acts on it, checked by AST rather than by text.
READ_IN_FUNCTION = {
    "strikes": "strike",
    "strike_damage": "strike",
    "strike_range": "strike",
    "attacker_key": "spawn_cast",
    "victim_key": "spawn_cast",
    "attacker_position": "spawn_cast",
    "victim_position": "spawn_cast",
    "system_id": "assert_system",
}

# The storage policy, duplicated from golden_diff.POLICY_QUANT_DECIMALS and dump_state.js on
# purpose: the point of the guard is that it disagrees loudly if someone edits one of them.
POLICY_QUANT_DECIMALS = 3


def fail(message):
    sys.stderr.write("FAIL: %s\n" % message)
    raise SystemExit(1)


def refuse(message):
    sys.stderr.write("REFUSED: %s\n" % message)
    raise SystemExit(2)


def resolve_golden_dir():
    for candidate in GOLDEN_CANDIDATES:
        if os.path.isfile(os.path.join(candidate, "provenance.json")):
            return candidate
    refuse("no provenance.json in any of %s; the knobs the golden was blessed with are "
           "unrecorded, so nothing can detect the spec drifting away from them"
           % ", ".join(GOLDEN_CANDIDATES))


def main():
    spec_path = next((c for c in SPEC_CANDIDATES if os.path.isfile(c)), None)
    if spec_path is None:
        refuse("no spec.json in any of %s" % ", ".join(SPEC_CANDIDATES))
    if not os.path.isfile(SCENARIO_SCRIPT):
        refuse("no scenario script at %s" % SCENARIO_SCRIPT)

    with open(spec_path, "r", encoding="utf-8") as handle:
        spec = json.load(handle)

    # --- 1. pinned -------------------------------------------------------------------------
    missing = [k for k in REQUIRED_KNOBS if k not in spec]
    if missing:
        fail("spec.json does not pin %s; without them the scenario is not reproducible" % missing)

    if spec["quant_decimals"] != POLICY_QUANT_DECIMALS:
        fail("spec quant_decimals=%r but the storage policy is %d. Coarsening quantisation makes "
             "every golden pass and is the standard way a golden suite rots into decoration."
             % (spec["quant_decimals"], POLICY_QUANT_DECIMALS))
    if not isinstance(spec["ticks"], int) or spec["ticks"] < 1:
        fail("spec ticks=%r, must be a positive int" % spec["ticks"])
    if not isinstance(spec["seed"], int):
        fail("spec seed=%r, must be an int" % spec["seed"])
    if not isinstance(spec["strikes"], int) or spec["strikes"] < 1:
        fail("spec strikes=%r, must be a positive int: a scenario that fires zero times is not a "
             "combat encounter" % spec["strikes"])
    if not isinstance(spec["strike_damage"], (int, float)) or spec["strike_damage"] <= 0:
        fail("spec strike_damage=%r, must be > 0: ShipEntity.m:13122 returns immediately for "
             "amount <= 0, so a non-positive strike dispatches no shipTakingDamage at all and "
             "the encounter would be silently vacuous" % spec["strike_damage"])
    if not isinstance(spec["strike_range"], (int, float)) or spec["strike_range"] <= 0:
        fail("spec strike_range=%r, must be > 0" % spec["strike_range"])

    # THE CAST MUST BE PINNED BY SHIP KEY, NOT BY ROLE. This is the finding this whole scenario
    # rests on: system.addShips(<role>) draws a ship type from a RANROT-fed probability set
    # (Universe.m:4008 -> :3948 -> OOShipRegistry.m:276-279), and the draw offset depends on how
    # many frames the run burned, not on the seed. Measured at one fixed seed, the victim came
    # back as a Moray Star Boat with maxEnergy 240, a Moray Star Boat with maxEnergy 496, and a
    # Mamba - which changed whether the fixed strike killed it. A literal key in the "[shipKey]"
    # form (OOShipRegistry.m:1229) makes no draw.
    for knob in ("attacker_key", "victim_key"):
        value = spec[knob]
        if not (isinstance(value, str) and value.startswith("[") and value.endswith("]")
                and len(value) > 2):
            fail("spec %s=%r is not a literal ship key in the '[shipKey]' form. A ROLE name here "
                 "reintroduces the RANROT ship-type draw (Universe.m:3948 -> "
                 "OOShipRegistry.m:276-279) that makes the encounter's OUTCOME vary run to run - "
                 "measured: the same seed produced victims with maxEnergy 240, 496 and 240 of "
                 "three different ship types, killing the victim in 2 of 3 runs." % (knob, value))

    for knob in ("attacker_position", "victim_position"):
        value = spec[knob]
        if not (isinstance(value, list) and len(value) == 3
                and all(isinstance(c, (int, float)) for c in value)):
            fail("spec %s=%r must be a 3-element numeric vector" % (knob, value))

    # --- 2. read ---------------------------------------------------------------------------
    with open(SCENARIO_SCRIPT, "r", encoding="utf-8") as handle:
        source = handle.read()
    for knob in MUST_BE_READ:
        if 'spec["%s"]' % knob not in source:
            fail("combat.py never reads spec[%r]; the knob is decoration - changing it would "
                 "change nothing and no line would go red" % knob)

    # A knob must be read where it is ACTED ON, not merely where it is recorded. AST, not text:
    # see READ_IN_FUNCTION above for the mutant that proved a substring check insufficient.
    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree)
                 if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("combat.py has no function %r, so the gate cannot verify that spec[%r] is read "
                 "where it is acted on; the scenario was refactored and this gate was not"
                 % (func_name, knob))
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript)
                 and isinstance(n.value, ast.Name) and n.value.id == "spec"
                 and isinstance(n.slice, ast.Constant) and n.slice.value == knob]
        if not reads:
            fail("combat.py reads spec[%r] somewhere, but NOT inside %s() - the function that "
                 "acts on it. A knob read only to be copied into the evidence block is still "
                 "decoration: the dump would report the spec's value while the behaviour ran on "
                 "a literal, and no line would go red." % (knob, func_name))

    # The seed must actually reach the game, and the run must be isolated. Same three checks
    # scenario 001's gate makes, for the same measured reasons (beads oo-het, oo-gla).
    console_path = os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py")
    if not os.path.isfile(console_path):
        refuse("no console.py at %s" % console_path)
    with open(console_path, "r", encoding="utf-8") as handle:
        console_src = handle.read()
    if "OO_RANDOM_SEED" not in console_src:
        fail("console.py does not export OO_RANDOM_SEED; the seed knob cannot reach the game")
    if "seed=seed" not in source:
        fail("combat.py does not pass seed= to DebugConsole; the seed knob never reaches the game")
    if "reserve_port" not in source:
        fail("combat.py does not reserve a private console port; on the shared 8563 a sibling "
             "worker's console can capture and quit the game seconds in and the run still exits "
             "0 (bead oo-het)")
    if "_write_console_config" not in source:
        fail("combat.py does not write a debugConfig.plist; the game DIALS OUT to the port named "
             "there (OODebugSupport.m:67-80), so a port that writes no plist can never connect "
             "(bead oo-gla)")

    # --- 3. agrees with provenance ----------------------------------------------------------
    golden_dir = resolve_golden_dir()
    with open(os.path.join(golden_dir, "provenance.json"), "r", encoding="utf-8") as handle:
        provenance = json.load(handle)
    knobs = provenance.get("scenario_knobs")
    if not knobs:
        fail("%s records no scenario_knobs; the seed this golden was BLESSED with is unrecorded, "
             "so nothing can detect the spec drifting away from it"
             % os.path.join(golden_dir, "provenance.json"))
    if provenance.get("quant_decimals") != POLICY_QUANT_DECIMALS:
        fail("%s records quant_decimals=%r but the policy is %d"
             % (golden_dir, provenance.get("quant_decimals"), POLICY_QUANT_DECIMALS))

    unrecorded = [k for k in REQUIRED_KNOBS if k not in knobs]
    if unrecorded:
        fail("provenance scenario_knobs does not record %s; those knobs could be changed in the "
             "spec with nothing going red" % unrecorded)

    drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}
    if drift:
        fail("spec.json disagrees with the knobs this golden was blessed with (%s records "
             "blessed-vs-spec %r). The stored golden no longer corresponds to what the spec "
             "would produce; re-bless deliberately or restore the spec - do NOT edit one side to "
             "match." % (os.path.join(golden_dir, "provenance.json"), drift))

    print("PASS: seed=%s system_id=%s ticks=%s tick_seconds=%s quant=%d "
          "attacker=%s victim=%s strikes=%s x %s damage at %s m; all %d knob(s) pinned, %d read "
          "by combat.py (%d of them checked by AST at their acting call site), and all %d match the values recorded in %s"
          % (spec["seed"], spec["system_id"], spec["ticks"], spec["tick_seconds"],
             POLICY_QUANT_DECIMALS, spec["attacker_key"], spec["victim_key"], spec["strikes"],
             spec["strike_damage"], spec["strike_range"], len(REQUIRED_KNOBS), len(MUST_BE_READ), len(READ_IN_FUNCTION),
             len(knobs), os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
