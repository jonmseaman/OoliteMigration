"""Offline checks on a scenario-010-png-test-suite dump: does it prove a PNG was DECODED?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, a collapsed dump, an off-policy
quantisation, floats rounded to whole numbers). All of that is about the COMPARISON.

It cannot answer the other half of the vacuity problem, which is about the RUN. And for a
TEXTURE-DECODING scenario that half is unusually sharp: a run in which the PNG loader silently
produced nothing writes exactly the same clean log and exactly the same quiet world dump as a run
in which it worked. Absence of errors proves nothing at all here. So this file checks the CONTENT,
and every check below is POSITIVE - something had to happen for the field to hold its value.

THE FIVE DEFENCES, AND WHY A DEAD RUN CANNOT PRODUCE ANY OF THEM
----------------------------------------------------------------
1. `evidence.oxp_world_scripts` / `oxp_script_versions`. MEASURED on this box: a control run with
   nothing staged (`png_test_suite.py --no-oxp`) has 16 world scripts; the staged run has 17, the
   extra one being `oolite-png-test-suite`, and a property read off it returns "1.0". A name gets
   there only if the OXP's directory was accepted as a resource path, its script file found,
   compiled by the JS engine, and INSTANTIATED as a live object. Being named in
   `[searchPaths.dumpAll]` proves only that a DIRECTORY was accepted; this proves content ran.

2. `evidence.png_shipdata_entries` / `png_diffuse_map_sample`. `Ship.shipDataForKey`
   (OOJSShip.m:578) reads the MERGED ship registry. All 153 of PNGTestSuite's test-cube entries
   resolve, and the sample carries the `materials['cube-face'].diffuse_map` strings read back out
   of the running engine for a fixed set of indices. That proves the expansion's 2930-line
   Config/shipdata.plist was parsed and merged - each entry naming a PNG the fixture asks the
   engine to decode. A dead run has 0.

3. `evidence.png_texture_uploads` - THE TEXTURE-DECODE EVIDENCE. `[texture.upload]` is emitted by
   OOConcreteTexture -upload (OOConcreteTexture.m:525) and carries the texture's PIXEL DIMENSIONS.
   It is reached only AFTER OOPNGTextureLoader has decoded the file: the loader bails at
   `texture.load.png.setup.failed` (OOPNGTextureLoader.m:97) or `texture.load.png.failed` (:118)
   long before any upload happens. So a line naming the expansion's image, at that image's real
   pixel size, is direct evidence that libpng decoded those bytes.

   The dimensions are not a literal: `evidence.png_ihdr_dimensions` is parsed from the IHDR chunk
   of the staged file itself at capture time, and this checker requires the two to AGREE - and
   also requires both to equal the recorded 1024x512, so that a broken IHDR parse cannot quietly
   redefine what the test means (bead oo-vwd's pair rule).

4. `evidence.png_load_failures` must be EMPTY, and that is a check on channels PROVEN TO BE ON:
   `evidence.texture_log_channels` lists the log classes the run switched on and read back as
   enabled. Without that, an empty failure list would mean "not logged" rather than "did not fail".
   This is the one place where an absence is asserted, and it is only meaningful because the
   presence side (defence 3) had to hold on the same channels.

5. The NOMANIF allowance, held EXACTLY. PNGTestSuite predates the manifest format and emits
   exactly TWO `[oxp-standards.error]: OXP ... has no manifest.plist` lines per load - verbatim
   from a real launch on this host. oo-kcrw's NOMANIF class is honest because it is gated on
   positive proof of loading AND on the errors being EXCLUSIVELY that message at that exact count.
   A third line, or a different error, fails. That exactness earned its keep in bead oo-3ya: it
   caught a staging directory named `addons` colliding case-insensitively with the game's own
   `../AddOns` root, which loaded the expansion TWICE and produced four lines.

THE FRAME IS NOT CHECKED HERE. It cannot be: llvmpipe is not bit-reproducible (bead oo-ae9
measured 0 of 3 same-scene pairs byte-identical), so the rendered frame is compared with a
MEASURED TOLERANCE against a stored reference grid by `png_test_suite.py --compare-frame`, not by
byte equality. Two artifacts, two comparison rules, each matched to what its data can support.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and the
value found). A usage error is 2, the same convention golden_diff uses for "no verdict given".
"""

import argparse
import json
import os
import sys

# Every field the evidence block must carry, with the value a REAL staged run produces. Listed as
# a table rather than as inline ifs so the set is readable and so a future scenario cannot quietly
# drop one of them.
REQUIRED_TRUE = ("oxp_staged", "tick_budget_met", "world_at_rest", "world_reached_fixed_point")
REQUIRED_POSITIVE = ("ticks", "populators_suppressed", "stations_quieted")

# The one world script PNGTestSuite contributes, MEASURED against a control run that staged
# nothing. Pinned as a set, not as a floor, so a run that loads a DIFFERENT expansion cannot
# satisfy this checker.
EXPECTED_OXP_WORLD_SCRIPTS = frozenset(("oolite-png-test-suite",))
EXPECTED_LIVE_SCRIPT_VERSIONS = {"oolite-png-test-suite": "1.0"}

# The expansion's Config/shipdata.plist defines exactly this many test-cube entries; counted in
# the file (153 `like_ship = "oolite_png_test_suite_base"` blocks) and read back out of the
# running engine's merged registry.
EXPECTED_SHIPDATA_ENTRIES = 153
EXPECTED_DIFFUSE_MAP_SAMPLE = {"1": "basi0g01.png", "77": "g05n3p04.png", "153": "z09n2c08.png"}

# The one PNG the expansion actually ships (its README states the 153 suite images are omitted for
# licensing reasons) and its real pixel size, read from the file's IHDR chunk.
EXPECTED_TEXTURE_KEY = "Images/oolite_material_test_suite_backdrop.png"
EXPECTED_IHDR_DIMENSIONS = [1024, 512]

# The channels the texture evidence is read from. Required to be recorded as ON, because an empty
# `png_load_failures` list means nothing if nobody was listening.
REQUIRED_LOG_CHANNELS = frozenset(("texture.upload", "texture.load.png.error",
                                   "texture.load.png.failed", "texture.load.png.warning"))

# Bead oo-kcrw's NOMANIF allowance, stated exactly.
EXPECTED_STANDARDS_ERRORS = 2
ALLOWED_STANDARDS_ERROR_SIGNATURES = frozenset((
    "OXP PNGTestSuite.oxp has no manifest.plist",
))

# Floors on the dump's own shape, under what a real run produces, so a truncated or half-written
# dump is rejected here rather than silently compared. This scenario spawns no cast and switches
# BOTH populators off, so the entities are the system's own fixed furniture.
MIN_ENTITIES = 2
MIN_MARKET_GOODS = 10

# The oolite-populator world-script handlers this scenario must have neutered. MEASURED: with only
# system.setPopulator(k, null) and hasNPCTraffic=false, the repopulator kept launching traffic,
# because its station picker _tradeStation (oolite-populator.js:2656-2680) ENDS WITH an
# unconditional `return system.mainStation` that ignores the flag it just tested.
EXPECTED_REPOPULATOR_HANDLERS = frozenset(("systemWillRepopulate",))


class EvidenceError(Exception):
    """The dump does not prove a PNG was decoded."""


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that PNGTestSuite was "
            "ever loaded or that any image was ever decoded, and two such dumps agreeing proves "
            "only that the same nothing happened twice." % label)

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
            "to take was not taken on the mission screen that carries the expansion's image"
            % (ev.get("gui_screen"),))

    # --- DEFENCE 0: the world was actually quiet when this dump was taken ----------------------
    # Three independent traffic sources had to be switched off for two runs of this scenario to
    # agree. Each is recorded separately so dropping any ONE of them goes red by name.
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
            "lacks, so PNGTestSuite's Config/script.js was never compiled or instantiated. Being "
            "on the search path is not being live." % (live,))
    elif set(live) != EXPECTED_OXP_WORLD_SCRIPTS:
        missing = sorted(EXPECTED_OXP_WORLD_SCRIPTS - set(live))
        extra = sorted(set(live) - EXPECTED_OXP_WORLD_SCRIPTS)
        problems.append(
            "evidence.oxp_world_scripts is %r, which is not PNGTestSuite's measured set (missing "
            "%r, unexpected %r). A dump taken with a different expansion loaded is not this "
            "scenario." % (sorted(live), missing, extra))

    versions = ev.get("oxp_script_versions")
    if not isinstance(versions, dict) or not versions:
        problems.append(
            "evidence.oxp_script_versions is %r: no property was read off any expansion script "
            "object, so the name above is an unbacked key rather than a live script"
            % (versions,))
    elif versions != EXPECTED_LIVE_SCRIPT_VERSIONS:
        problems.append(
            "evidence.oxp_script_versions is %r but the measured value is %r. This is the read "
            "that proves a script FILE was found, compiled and instantiated; a name in "
            "oxp_world_scripts only proves the world-scripts list was merged."
            % (versions, EXPECTED_LIVE_SCRIPT_VERSIONS))

    # --- DEFENCE 2: the 153-entry shipdata registry was PARSED AND MERGED ----------------------
    entries = ev.get("png_shipdata_entries")
    if entries != EXPECTED_SHIPDATA_ENTRIES:
        problems.append(
            "evidence.png_shipdata_entries is %r but PNGTestSuite defines exactly %d test-cube "
            "entries in Config/shipdata.plist, each naming a PNG for the engine to decode. Fewer "
            "means the plist was not merged (or was merged partially); more means something else "
            "is contributing keys with this prefix." % (entries, EXPECTED_SHIPDATA_ENTRIES))
    sample = ev.get("png_diffuse_map_sample")
    if sample != EXPECTED_DIFFUSE_MAP_SAMPLE:
        problems.append(
            "evidence.png_diffuse_map_sample is %r but the measured value is %r. These strings "
            "are read back out of the RUNNING engine's merged ship registry and each names an "
            "image the fixture asks it to decode; a mismatch means the merged registry is not "
            "this fixture's." % (sample, EXPECTED_DIFFUSE_MAP_SAMPLE))

    # --- DEFENCE 3: a PNG was actually DECODED and UPLOADED ------------------------------------
    uploads = ev.get("png_texture_uploads")
    if not isinstance(uploads, list) or not uploads:
        problems.append(
            "evidence.png_texture_uploads is %r: not one [texture.upload] line named the "
            "expansion's image. OOConcreteTexture -upload (OOConcreteTexture.m:525) is reached "
            "only AFTER OOPNGTextureLoader has decoded the file - the loader bails at "
            "texture.load.png.failed (OOPNGTextureLoader.m:118) long before any upload - so an "
            "empty list means NO PNG FROM THIS EXPANSION WAS DECODED. This is exactly the silent "
            "failure that a clean log and a quiet world dump cannot distinguish from success."
            % (uploads,))
    else:
        matching = [u for u in uploads
                    if isinstance(u, dict) and u.get("key") == EXPECTED_TEXTURE_KEY]
        if not matching:
            problems.append(
                "no [texture.upload] entry named %r; the uploads recorded were %r. This "
                "scenario's texture evidence is about THAT image and no other."
                % (EXPECTED_TEXTURE_KEY, uploads))
        for upload in matching:
            if [upload.get("width"), upload.get("height")] != EXPECTED_IHDR_DIMENSIONS:
                problems.append(
                    "the engine reports uploading %r at %rx%r pixels, but the image is %dx%d. A "
                    "texture of the wrong size is not this image, so the decode evidence does not "
                    "apply to it." % (EXPECTED_TEXTURE_KEY, upload.get("width"),
                                      upload.get("height"), EXPECTED_IHDR_DIMENSIONS[0],
                                      EXPECTED_IHDR_DIMENSIONS[1]))

    ihdr = ev.get("png_ihdr_dimensions")
    if ihdr != EXPECTED_IHDR_DIMENSIONS:
        problems.append(
            "evidence.png_ihdr_dimensions is %r but the image's IHDR chunk reads %r. The run "
            "parses those bytes off the STAGED FILE and the engine's own upload line is checked "
            "against them, so this pair is what makes the upload evidence be about this image; "
            "the literal here keeps a broken IHDR parse from quietly redefining the test "
            "(bead oo-vwd)." % (ihdr, EXPECTED_IHDR_DIMENSIONS))

    # --- DEFENCE 4: the absence assertion, over channels PROVEN to be listening -----------------
    channels = ev.get("texture_log_channels")
    if not isinstance(channels, list) or not REQUIRED_LOG_CHANNELS.issubset(set(channels)):
        problems.append(
            "evidence.texture_log_channels is %r and does not cover %r. logcontrol.plist:454-457 "
            "has these classes OFF by default ($textureDebug = no), so without a record that the "
            "run switched them on and read the flag back, both the upload evidence and the empty "
            "failure list below would mean 'nobody was listening' rather than 'it worked'."
            % (channels, sorted(REQUIRED_LOG_CHANNELS)))
    failures = ev.get("png_load_failures")
    if not isinstance(failures, list):
        problems.append("evidence.png_load_failures is %r, expected a list" % (failures,))
    elif failures:
        problems.append(
            "the run emitted PNG loader diagnostics: %r. These come from OOPNGTextureLoader's "
            "error and warning callbacks (OOPNGTextureLoader.m:223, :236) and mean an image did "
            "not decode cleanly. A texture-decoding scenario must not tolerate them." % (failures,))

    # --- DEFENCE 5: the NOMANIF allowance, held EXACTLY ----------------------------------------
    count = ev.get("oxp_standards_errors")
    if count != EXPECTED_STANDARDS_ERRORS:
        problems.append(
            "evidence.oxp_standards_errors is %r but exactly %d is allowed (bead oo-kcrw: "
            "PNGTestSuite is NOMANIF and emits exactly that many "
            "'[oxp-standards.error]: OXP ... has no manifest.plist' lines). Fewer means the "
            "expansion was not parsed; more means a NEW problem - bead oo-3ya's double-root "
            "staging bug produced four. Widening this to make a run pass is forbidden."
            % (count, EXPECTED_STANDARDS_ERRORS))
    sigs = ev.get("oxp_standards_error_signatures")
    if not isinstance(sigs, list):
        problems.append("evidence.oxp_standards_error_signatures is %r, expected a list" % (sigs,))
    else:
        unexpected = [s for s in sigs if s not in ALLOWED_STANDARDS_ERROR_SIGNATURES]
        if unexpected:
            problems.append(
                "the run emitted an [oxp-standards.error] line that is NOT the known "
                "missing-manifest message: %r. The allow-list is %r and is deliberately exact - a "
                "different error is a finding, not noise."
                % (unexpected, sorted(ALLOWED_STANDARDS_ERROR_SIGNATURES)))
        if not sigs:
            problems.append(
                "evidence.oxp_standards_error_signatures is empty: the known missing-manifest "
                "line was never emitted, so this dump was not taken with PNGTestSuite staged")

    # --- the dump's own shape ------------------------------------------------------------------
    ents = data.get("entities")
    if not isinstance(ents, list) or len(ents) < MIN_ENTITIES:
        problems.append("entities has %r member(s), fewer than the %d a real run of this scenario "
                        "carries" % (len(ents) if isinstance(ents, list) else ents, MIN_ENTITIES))
    market = data.get("market")
    if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:
        problems.append("market has %r good(s), fewer than the %d minimum; the station's market "
                        "is missing, so the dump is not a docked world state"
                        % (len(market) if isinstance(market, dict) else market, MIN_MARKET_GOODS))
    if not (data.get("player") or {}).get("ship"):
        problems.append("player.ship is absent: the dump is not a world-state dump")

    if problems:
        raise EvidenceError("%s does not prove a PNGTestSuite texture-decoding run:\n  %s"
                            % (label, "\n  ".join(problems)))

    return ("%s: PNGTestSuite live and a PNG DECODED - world script %s live at version %s; %d "
            "test-cube ship entries merged, sample naming %s; the engine uploaded %s at %dx%d "
            "pixels, matching the IHDR of the staged file, with 0 PNG loader diagnostics on %d "
            "channel(s) proven enabled; exactly %d known missing-manifest error(s) and no others; "
            "ran %d ticks with %d populator setting(s) and %d station(s) quieted; %d entities, "
            "%d market goods"
            % (label, ", ".join(sorted(live)),
               ", ".join("%s" % v for v in sorted(versions.values())),
               entries, ", ".join("%s=%s" % kv for kv in sorted(sample.items())),
               EXPECTED_TEXTURE_KEY, EXPECTED_IHDR_DIMENSIONS[0], EXPECTED_IHDR_DIMENSIONS[1],
               len(channels), EXPECTED_STANDARDS_ERRORS, ev["ticks"],
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
