# Step 9 resolutions (selector families, last bridge callers, gnustep-base gone).
RES = {
    # upstream #740 remembers the last saved game; ported with the history's oo::Defaults
    "src/Core/Entities/PlayerEntity.mm": [
        "    [self cxx_setCommanderName:std::string(PLAYER_DEFAULT_NAME)];\n"
        "    const oo::PList savedName = oo::Defaults::standard().object(\"last_savename\");\n"
        "    if (const std::string* savedLastsaveName = savedName.getIf<std::string>()) {\n"
        "        [self cxx_setLastsaveName:*savedLastsaveName];\n"
        "    }\n",
    ],
    # the history moved these onto OOObject; upstream's guard change (#756) was on the NSObject category
    "src/Core/NSObjectOOExtensions.h": ["theirs"],
    "src/Core/NSObjectOOExtensions.mm": ["theirs"],
    "src/Core/OOALSoundChannel.h": ["both"],  # upstream's #pragma once + the history's include
    "src/Core/OOCache.mm": ["theirs"],
    "src/Core/Scripting/OOJavaScriptEngine.h": ["theirs"],
    # upstream (#748) dropped the closing include guard for #pragma once; keep the history's comment block
    # (OOHPVector.h: now merges cleanly, its conditionals balanced; no resolution needed)
}
# the history retired this header; upstream's change to it is #pragma once and its include (mechanical)
DELETE = ["src/Core/NSFileManagerOOExtensions.h"]


# the containers selector gets a named second part (see selector_containers.py)
exec(open(__file__.replace("009.py", "selector_containers.py"), encoding="utf-8").read())
RENAMES = list(globals().get("RENAMES", [])) + CONTAINERS_RENAMES
# the history's step-9 forms supersede step 8's warning fixes (its own local names and types); it
# deletes the Universe Foundation bridge, so step 8's selector rename there goes with it
RES["src/Core/Entities/PlayerEntityLegacyScriptEngine.mm"] = ["theirs"] * 5
RES["src/Core/Entities/ShipEntityAI.mm"] = ["theirs", "theirs"]
DELETE = DELETE + ["src/Core/Universe+FoundationBridge.h", "src/Core/Universe+FoundationBridge.mm"]


# The history's selector families make the key constants std::string_view and replace OOLog with
# OO_LOG here; upstream code carried in by earlier steps follows (its own forms elsewhere in the file):
#  - oo::StdString(kOOManifestInformationURL) / (SHIPYARD_KEY_PERSONALITY) -> std::string(...)
#  - upstream's OpenGL-context log lines (#766/#774) -> OO_LOG
# and the id overload of OptionalStringValue goes: only upstream's deleted AppKit load/save used it.
RENAMES = RENAMES + [
    (r"oo::StdString\((kOOManifestInformationURL|SHIPYARD_KEY_PERSONALITY)\)", r"std::string(\1)"),
    (r'OOLog\(@"sdl\.create_context", @"Could not make OpenGL context current: %s", SDL_GetError\(\)\);',
     'OO_LOG("sdl.create_context", "Could not make OpenGL context current: {}", SDL_GetError());'),
]
try:
    CHANGES
except NameError:
    CHANGES = {}
CHANGES["src/Core/Entities/PlayerEntityLoadSave.mm"] = [(
    "std::optional<std::string> OptionalStringValue(id object)\n{\n    const oo::PList value = oo::PListFrom(object);\n"
    "    return OptionalStringValue(&value);\n}\n\n", "")]
