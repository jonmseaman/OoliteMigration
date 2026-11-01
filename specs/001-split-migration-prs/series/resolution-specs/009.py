# Step 9 resolutions (selector families, last bridge callers, gnustep-base gone).
RES = {
    # upstream #740 remembers the last saved game; ported with the history's oo::Defaults
    "src/Core/Entities/PlayerEntity.mm": [
        "    [self cxx_setCommanderName:std::string(PLAYER_DEFAULT_NAME)];\n"
        "    const oo::PList savedName = oo::Defaults::standard().object(\"last_savename\");\n"
        "    if (const std::string* name = savedName.getIf<std::string>()) {\n"
        "        [self cxx_setLastsaveName:*name];\n"
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
