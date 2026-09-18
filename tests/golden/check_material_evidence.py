"""Offline checks on a scenario-008-material-test-suite dump: did the MATERIALS go live?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, a collapsed dump, an off-policy
quantisation). All of that is about the COMPARISON.

It cannot answer the other half of the vacuity problem, which is about the RUN - and for MATERIALS
that half is unusually sharp. A material dictionary that was merged but never bound to a mesh, a
texture map that never decoded, a mission screen that opened with no model on it: every one of
those writes exactly the same clean log and exactly the same quiet world dump as a run in which a
textured cube was drawn. Absence of errors proves nothing here; neither does rc=0. So this file
checks the CONTENT, and every check below is POSITIVE - something had to happen for the field to
hold its value - and every value is EMITTED BY THE ENGINE, not inferred by the harness.

THE SIX DEFENCES, AND WHY A DEAD RUN CANNOT PRODUCE ANY OF THEM
----------------------------------------------------------------
1. `oxp_world_scripts` / `oxp_script_versions`. MEASURED on this box: a control with nothing
   staged (`material_test_suite.py --no-oxp`) has 16 world scripts; the staged run has 17, the
   extra being `oolite-material-test-suite`, and a property read off it returns "1.3". A name gets
   there only if the OXP directory was accepted as a resource path, its script file found,
   compiled and INSTANTIATED. Being named in `[searchPaths.dumpAll]` proves only that a DIRECTORY
   was accepted; this proves content ran.

2. `material_shipdata_entries` / `material_map_sample`. `Ship.shipDataForKey` reads the MERGED
   ship registry. All 24 of the fixture's material-bearing entries resolve (17 `shaders` +
   7 `materials`), and the sample carries the PROPERTY NAMES INSIDE the `cube-face` material
   dictionary plus the fixture's own `script_info` label, read back out of the running engine. An
   entry that resolved but lost its material dictionary is caught by name here - the failure a key
   COUNT alone cannot see.

3. `material_texture_uploads` / `material_map_ihdr`. `[texture.upload]` is emitted by
   OOConcreteTexture -upload (OOConcreteTexture.m:525) with the texture's PIXEL DIMENSIONS, and is
   reached only AFTER the PNG loader decoded the file - the loader bails at
   `texture.load.png.failed` long before any upload. Every map this scenario's material names must
   appear, at the size its own IHDR chunk records. The dimensions are not a literal: the run parses
   them off the STAGED FILES, and this checker requires those AND the recorded literals to agree,
   so a broken IHDR parse cannot quietly redefine the test (bead oo-vwd's pair rule).

4. `display_model_key` / `display_model_label`. `mission.displayModel` is the ShipEntity the ENGINE
   constructed for the screen (OOJSMission.m:660-665), and the property is DELETED when it made
   none. Reading `.dataKey` and the expansion-private `scriptInfo` label off it proves the pinned
   entry - not some other ship - is the thing being drawn with that material.

5. `texture_load_failures` must be EMPTY, and that is a check on channels PROVEN TO BE ON:
   `log_channels` lists the classes the run switched on and READ BACK as enabled. Without that, an
   empty failure list would mean "not logged" rather than "did not fail". This is the one place an
   ABSENCE is asserted, and it is meaningful only because the presence side (defence 3) held on the
   same channels.

6. `oxp_standards_errors` must be EXACTLY ZERO, with an EMPTY allow-list. This fixture is NOT one
   of bead oo-kcrw's five NOMANIF fixtures: `Material Test Suite.oxp` SHIPS a `manifest.plist`
   (identifier `org.oolite.material-test-suite`, version 1.3) - verified on disk against all six
   in-tree test-oxps, and confirmed by a real launch whose 13452-byte Latest.log contains zero
   `[oxp-standards.error]` lines while `[searchPaths.dumpAll]` names the staged copy. So nothing is
   allow-listed and any such line fails. That is STRICTER than 010/012's exact-count allowance.

THE FRAME IS NOT CHECKED HERE. It cannot be: llvmpipe is not bit-reproducible (bead oo-ae9
measured 0 of 3 same-scene pairs byte-identical), so the rendered frame is compared with a MEASURED
TOLERANCE against a stored reference grid by `material_test_suite.py --compare-frame`, not by byte
equality. Two artifacts, two comparison rules, each matched to what its data can support.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and the
value found). A usage error is 2, the convention golden_diff uses for "no verdict given".
"""

import argparse
import json
import os
import sys

# Every field the evidence block must carry, with the value a REAL staged run produces. A table
# rather than inline ifs, so the set is readable and a future edit cannot quietly drop one.
REQUIRED_TRUE = ("oxp_staged", "tick_budget_met", "world_reached_fixed_point", "player_docked")
REQUIRED_POSITIVE = ("ticks", "populators_suppressed", "stations_quieted")

# The one world script this expansion contributes, MEASURED against a control that staged nothing.
# Pinned as a SET, not as a floor, so a run that loaded a DIFFERENT expansion cannot satisfy this.
EXPECTED_OXP_WORLD_SCRIPTS = frozenset(("oolite-material-test-suite",))
EXPECTED_LIVE_SCRIPT_VERSIONS = {"oolite-material-test-suite": "1.3"}

# Config/shipdata.plist defines 25 entries: one is_template base plus 17 shader and 7
# fixed-function material entries. The base is excluded - it is a template, not a material under
# test - so 24 is the number read back out of the merged registry.
EXPECTED_SHIPDATA_ENTRIES = 24

# The material DICTIONARIES themselves, read back out of the running engine. These property names
# exist only inside the expansion's own shipdata.plist.
EXPECTED_MATERIAL_SAMPLE = {
    "oolite_non_shader_test_suite_1": {
        "label": "diffuse_map",
        "material_keys": ["diffuse_map"],
    },
    "oolite_shader_test_suite_13": {
        "label": "diffuse_map + specular_map",
        "material_keys": ["diffuse_map", "gloss", "specular_map", "specular_modulate_color"],
    },
    "oolite_shader_test_suite_17": {
        "label": "diffuse_map + normal_map + specular_and_gloss_map",
        "material_keys": ["diffuse_map", "gloss", "normal_map", "specular_map"],
    },
}

# Every map the pinned material names, at the size its own IHDR chunk records.
EXPECTED_IHDR_DIMENSIONS = {
    "Images/oolite_material_test_suite_backdrop.png": [2048, 1024],
    "Textures/oolite_shader_test_suite_13_specular.png": [512, 512],
    "Textures/oolite_shader_test_suite_diffuse_blank.png": [512, 512],
}

# What the ENGINE put on the screen. The label is expansion-private.
EXPECTED_DISPLAY_MODEL_KEY = "oolite_shader_test_suite_13"
EXPECTED_DISPLAY_MODEL_LABEL = "diffuse_map + specular_map"

# The renderer path the golden was blessed at. The fixture ships parallel shader and
# fixed-function material sets and they do not render alike.
EXPECTED_DETAIL_LEVEL = "DETAIL_LEVEL_SHADERS"

# The channels the material evidence is read from. Required to be recorded as ON, because an empty
# `texture_load_failures` list means nothing if nobody was listening.
REQUIRED_LOG_CHANNELS = frozenset((
    "texture.upload",
    "texture.load.png.error",
    "texture.load.png.failed",
    "texture.load.png.setup.failed",
    "shader.load.failed",
    "shader.load.noShader",
    "shader.load.fullModeFailed",
))

# This fixture HAS a manifest.plist, so there is nothing to tolerate: exactly zero, allow-list
# empty. See module docstring, defence 6.
EXPECTED_STANDARDS_ERRORS = 0

# The oolite-populator handlers this scenario must have neutered (bead oo-gxp).
EXPECTED_REPOPULATOR_HANDLERS = frozenset(("systemWillRepopulate",))

# Floors on the dump's own shape, under what a real run produces, so a truncated or half-written
# dump is rejected here rather than silently compared.
MIN_ENTITIES = 2
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove the expansion's materials went live."""


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that the Material Test "
            "Suite was ever loaded or that any material was ever applied, and two such dumps "
            "agreeing proves only that the same nothing happened twice." % label)

    for field in REQUIRED_TRUE:
        if field not in ev:
            problems.append("evidence.%s is ABSENT" % field)
        elif ev[field] is not True:
            problems.append("evidence.%s is %r, expected True" % (field, ev[field]))

    for field in REQUIRED_POSITIVE:
        if field not in ev:
            problems.append("evidence.%s is ABSENT" % field)
        elif not isinstance(ev[field], int) or ev[field] < 1:
            problems.append("evidence.%s is %r, expected an integer >= 1" % (field, ev[field]))

    if ev.get("gui_screen") != "GUI_SCREEN_MISSION":
        problems.append(
            "evidence.gui_screen is %r, not 'GUI_SCREEN_MISSION': the frame this scenario exists "
            "to take was not taken on the mission screen that carries the expansion's materials"
            % (ev.get("gui_screen"),))

    if ev.get("detail_level") != EXPECTED_DETAIL_LEVEL:
        problems.append(
            "evidence.detail_level is %r, expected %r. debugConsole.detailLevel selects between "
            "the shader and fixed-function material paths, and the fixture ships separate entry "
            "sets for each precisely because they do not render alike; a golden blessed at one "
            "level says nothing at the other."
            % (ev.get("detail_level"), EXPECTED_DETAIL_LEVEL))

    # --- DEFENCE 0: the world was actually quiet when this dump was taken ----------------------
    handlers = ev.get("repopulator_handlers_quieted")
    if not isinstance(handlers, list) or set(handlers) != EXPECTED_REPOPULATOR_HANDLERS:
        problems.append(
            "evidence.repopulator_handlers_quieted is %r, expected %r: oolite-populator.js's "
            "systemWillRepopulate (:1027) launches freighters, couriers, police patrols and "
            "shuttles for the life of the system, and hasNPCTraffic does NOT stop it because its "
            "station picker ends with an unconditional `return system.mainStation`. Without that "
            "handler neutered no two runs of this scenario can agree."
            % (handlers, sorted(EXPECTED_REPOPULATOR_HANDLERS)))

    # --- DEFENCE 1: the expansion's world script is LIVE in the running game -------------------
    live = ev.get("oxp_world_scripts")
    if not isinstance(live, list) or not live:
        problems.append(
            "evidence.oxp_world_scripts is %r: the running game had no world script a stock game "
            "lacks, so the expansion's script was never compiled or instantiated. Being on the "
            "search path is not being live." % (live,))
    elif set(live) != EXPECTED_OXP_WORLD_SCRIPTS:
        missing = sorted(EXPECTED_OXP_WORLD_SCRIPTS - set(live))
        extra = sorted(set(live) - EXPECTED_OXP_WORLD_SCRIPTS)
        problems.append(
            "evidence.oxp_world_scripts is %r, which is not the Material Test Suite's measured set "
            "(missing %r, unexpected %r). A dump taken with a different expansion loaded is not "
            "this scenario." % (sorted(live), missing, extra))

    versions = ev.get("oxp_script_versions")
    if not isinstance(versions, dict) or not versions:
        problems.append(
            "evidence.oxp_script_versions is %r: no property was read off any expansion script "
            "object, so the name above is an unbacked key rather than a live script" % (versions,))
    elif versions != EXPECTED_LIVE_SCRIPT_VERSIONS:
        problems.append(
            "evidence.oxp_script_versions is %r but the measured value is %r. This is the read "
            "that proves a script FILE was found, compiled and instantiated; a name in "
            "oxp_world_scripts only proves the world-scripts list was merged."
            % (versions, EXPECTED_LIVE_SCRIPT_VERSIONS))

    # --- DEFENCE 2: the material definitions were PARSED AND MERGED ----------------------------
    entries = ev.get("material_shipdata_entries")
    if entries != EXPECTED_SHIPDATA_ENTRIES:
        problems.append(
            "evidence.material_shipdata_entries is %r but the fixture defines exactly %d "
            "material-bearing entries in Config/shipdata.plist (17 with a `shaders` dict, 7 with a "
            "`materials` dict, excluding the is_template base). Fewer means the plist was not "
            "merged, or was merged partially; more means something else contributes these keys."
            % (entries, EXPECTED_SHIPDATA_ENTRIES))
    sample = ev.get("material_map_sample")
    if sample != EXPECTED_MATERIAL_SAMPLE:
        problems.append(
            "evidence.material_map_sample is %r but the measured value is %r. These are the "
            "MATERIAL DICTIONARIES themselves - the property names inside "
            "shaders['cube-face'] / materials['cube-face'] and the fixture's own label - read back "
            "out of the RUNNING engine's merged registry. A mismatch means the merged registry is "
            "not this fixture's, or an entry resolved while its material did not survive the "
            "merge, which is the silent half-failure a key count alone cannot see."
            % (sample, EXPECTED_MATERIAL_SAMPLE))

    # --- DEFENCE 3: the material maps were DECODED and UPLOADED --------------------------------
    uploads = ev.get("material_texture_uploads")
    if not isinstance(uploads, list) or not uploads:
        problems.append(
            "evidence.material_texture_uploads is %r: not one [texture.upload] line was recorded. "
            "OOConcreteTexture -upload (OOConcreteTexture.m:525) is reached only AFTER the PNG "
            "loader decoded the file - it bails at texture.load.png.failed long before any upload "
            "- so an empty list means NOTHING WAS DECODED. This is exactly the silent failure a "
            "clean log and a quiet world dump cannot distinguish from success." % (uploads,))
    else:
        by_key = {u.get("key"): u for u in uploads if isinstance(u, dict)}
        for key in sorted(EXPECTED_IHDR_DIMENSIONS):
            if key not in by_key:
                problems.append(
                    "no [texture.upload] entry named %r; the uploads recorded were %r. That map is "
                    "part of the material this scenario draws, and an unuploaded map is a material "
                    "that did not go live." % (key, sorted(by_key)))
                continue
            want = EXPECTED_IHDR_DIMENSIONS[key]
            got = [by_key[key].get("width"), by_key[key].get("height")]
            if got != want:
                problems.append(
                    "the engine reports uploading %r at %rx%r pixels, but the image is %dx%d. A "
                    "texture of the wrong size is not this image, so the decode evidence does not "
                    "apply to it." % (key, got[0], got[1], want[0], want[1]))

    ihdr = ev.get("material_map_ihdr")
    if ihdr != EXPECTED_IHDR_DIMENSIONS:
        problems.append(
            "evidence.material_map_ihdr is %r but the staged files' IHDR chunks read %r. The run "
            "parses those bytes off the STAGED FILES and the engine's own upload lines are checked "
            "against them, so this pair is what makes the upload evidence be about THESE images; "
            "the literal here keeps a broken IHDR parse from quietly redefining the test "
            "(bead oo-vwd)." % (ihdr, EXPECTED_IHDR_DIMENSIONS))

    # --- DEFENCE 4: the ENGINE put the material-bearing model on the screen --------------------
    if ev.get("display_model_key") != EXPECTED_DISPLAY_MODEL_KEY:
        problems.append(
            "evidence.display_model_key is %r, expected %r. mission.displayModel is the ShipEntity "
            "the ENGINE constructed for this screen (OOJSMission.m:660-665) and the property is "
            "DELETED when it made none, so None means no model was drawn at all and a different "
            "key means some other ship - and therefore some other material - was."
            % (ev.get("display_model_key"), EXPECTED_DISPLAY_MODEL_KEY))
    if ev.get("display_model_label") != EXPECTED_DISPLAY_MODEL_LABEL:
        problems.append(
            "evidence.display_model_label is %r, expected %r. The label is read off the LIVE "
            "entity's scriptInfo and that string exists only inside the expansion's own "
            "shipdata.plist - this harness contains no copy of it to fall back on."
            % (ev.get("display_model_label"), EXPECTED_DISPLAY_MODEL_LABEL))

    # --- DEFENCE 5: the absence assertion, over channels PROVEN to be listening ----------------
    channels = ev.get("log_channels")
    if not isinstance(channels, list) or not REQUIRED_LOG_CHANNELS.issubset(set(channels)):
        problems.append(
            "evidence.log_channels is %r and does not cover %r. logcontrol.plist has these classes "
            "OFF by default ($textureDebug = no), so without a record that the run switched them "
            "on and READ THE FLAG BACK, both the upload evidence and the empty failure list below "
            "would mean 'nobody was listening' rather than 'it worked'."
            % (channels, sorted(REQUIRED_LOG_CHANNELS)))
    failures = ev.get("texture_load_failures")
    if not isinstance(failures, list):
        problems.append("evidence.texture_load_failures is %r, expected a list" % (failures,))
    elif failures:
        problems.append(
            "evidence.texture_load_failures is non-empty - the run emitted texture/shader loader "
            "diagnostics: %r. These mean a map or a shader "
            "did not load cleanly, and a materials scenario must not tolerate them - an unloaded "
            "map is a material that did not go live." % (failures,))

    # --- DEFENCE 6: the standards predicate, held at EXACTLY ZERO ------------------------------
    count = ev.get("oxp_standards_errors")
    if count != EXPECTED_STANDARDS_ERRORS:
        problems.append(
            "evidence.oxp_standards_errors is %r but exactly %d is allowed. `Material Test "
            "Suite.oxp` SHIPS a manifest.plist (org.oolite.material-test-suite 1.3) - verified on "
            "disk and by a real launch with zero such lines - so unlike the five NOMANIF fixtures "
            "bead oo-kcrw classified there is nothing here to tolerate and any such line is a NEW "
            "problem. Widening this to make a run pass is forbidden."
            % (count, EXPECTED_STANDARDS_ERRORS))
    sigs = ev.get("oxp_standards_error_signatures")
    if not isinstance(sigs, list):
        problems.append("evidence.oxp_standards_error_signatures is %r, expected a list" % (sigs,))
    elif sigs:
        problems.append(
            "the run emitted [oxp-standards.error] line(s) %r. The allow-list for this fixture is "
            "EMPTY by design - it has a manifest - so any such line is a finding, not noise."
            % (sigs,))

    # --- the dump's own shape ------------------------------------------------------------------
    ents = data.get("entities")
    if not isinstance(ents, list) or len(ents) < MIN_ENTITIES:
        problems.append("entities has %r member(s), fewer than the %d a real run of this scenario "
                        "carries" % (len(ents) if isinstance(ents, list) else ents, MIN_ENTITIES))
    market = data.get("market")
    if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:
        problems.append("market has %r good(s), fewer than the %d minimum; the station's market is "
                        "missing, so the dump is not a docked world state"
                        % (len(market) if isinstance(market, dict) else market, MIN_MARKET_GOODS))
    if not (data.get("player") or {}).get("ship"):
        problems.append("player.ship is absent: the dump is not a world-state dump")

    if problems:
        raise EvidenceError("%s does not prove a Material Test Suite materials run:\n  %s"
                            % (label, "\n  ".join(problems)))

    return ("%s: Material Test Suite live and its MATERIALS applied - world script %s live at "
            "version %s; %d material-bearing ship entries merged, sample naming %s; the engine "
            "uploaded %d map(s) (%s) each at the IHDR size of the staged file, with 0 texture or "
            "shader diagnostics on %d channel(s) proven enabled; the engine drew %s labelled %r at "
            "%s; exactly %d [oxp-standards.error] line(s) - this fixture ships a manifest; ran %d "
            "ticks with %d populator setting(s) and %d station(s) quieted; %d entities, %d market "
            "goods"
            % (label, ", ".join(sorted(live)),
               ", ".join(sorted(versions.values())),
               entries,
               "; ".join("%s=%s" % (k, ",".join(v["material_keys"]))
                         for k, v in sorted(sample.items())),
               len(EXPECTED_IHDR_DIMENSIONS), ", ".join(sorted(EXPECTED_IHDR_DIMENSIONS)),
               len(channels), EXPECTED_DISPLAY_MODEL_KEY, EXPECTED_DISPLAY_MODEL_LABEL,
               EXPECTED_DETAIL_LEVEL, EXPECTED_STANDARDS_ERRORS, ev["ticks"],
               ev["populators_suppressed"], ev["stations_quieted"], len(ents), len(market)))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("dump")
    parser.add_argument("--label", default=None)
    args = parser.parse_args(argv)
    label = args.label or args.dump

    if not os.path.isfile(args.dump):
        sys.stderr.write("USAGE: no such dump: %s\n" % args.dump)
        return 2
    try:
        with open(args.dump, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except ValueError as exc:
        sys.stderr.write("USAGE: %s is not valid JSON: %s\n" % (label, exc))
        return 2

    try:
        print(check(data, label))
    except EvidenceError as exc:
        sys.stderr.write("NO EVIDENCE: %s\n" % exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
