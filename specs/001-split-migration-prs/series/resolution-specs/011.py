# Step 11 resolutions (Scripting, Entities, audio and Materials conversions).
def guard(ours, theirs):
    """The history's code; where upstream's side of the hunk uses the debug-monitor guard (#756),
    the history's NDEBUG guards in the hunk take it too."""
    if "OO_DEBUG_MONITOR_ENABLED" in ours:
        theirs = theirs.replace("#ifndef NDEBUG", "#ifdef OO_DEBUG_MONITOR_ENABLED")
    return theirs

RES = {
    # Entity became C++; the live-entity counters live in the facade now
    "src/Core/Entities/Entity.mm": ["theirs", "theirs", guard, guard],
    "src/Core/Materials/OOShaderMaterial.h": ["theirs"],
    # upstream's macOS GLSL 330 -> 120 translation (#766) is deferred with macOS
    "src/Core/Materials/OOShaderProgram.mm": ["theirs", "theirs"],
    "src/Core/Materials/OOTexture.h": ["both", "theirs"],  # #pragma once and the history's guard
    "src/Core/Materials/OOTexture.mm": [guard, guard],
    # the C++ OOJoystickManager keeps decode*Event (develop's design)
    "src/Core/OOJoystickManager.h": ["theirs", "theirs", "theirs"],
    "src/Core/Scripting/OOJavaScriptEngine.h": [guard, guard],
}
# the history deleted this compiled-out old-planet code
DELETE = ["src/Core/Entities/PlanetEntity.h", "src/Core/Entities/PlanetEntity.mm"]
# the history moved the Mac-only methods into a category at the end; keep its file, with upstream's
# debug-monitor guard on the exit path (#756)
WHOLE = {"src/Core/GameController.mm": lambda text: text.replace(
    "#if (OOLITE_GNUSTEP && !defined(NDEBUG))", "#if (OOLITE_SDL && defined(OO_DEBUG_MONITOR_ENABLED))")}
# upstream's include block sits lower in this file; the history adds SDL_timer.h among the includes
RES["src/SDL/MyOpenGLView.mm"] = [lambda ours, theirs: ours + "#include <SDL3/SDL_timer.h>\n"]


# the containers selector gets a named second part (see selector_containers.py)
exec(open(__file__.replace("011.py", "selector_containers.py"), encoding="utf-8").read())
RENAMES = list(globals().get("RENAMES", [])) + CONTAINERS_RENAMES
# the history converts the console client to C++ here; step 8's selector spacing goes with the method
RES["src/Core/Debug/OODebugTCPConsoleClient.mm"] = ["theirs", "theirs"]


# The history's scripting unit tests (new here, Objective-C++ until step 17) declare their own stub
# entity classes and include only the scripting header, as the history's headers forward-declare
# the class (@class). Upstream's #748 also imports the entity header there, which defines each class
# twice in those tests. The redundant import stays out until the tests stop stubbing the classes.
try:
    CHANGES
except NameError:
    CHANGES = {}
for _js, _entity in (("Dock", "DockEntity"), ("Sound", "OOSound"), ("Player", "PlayerEntity"),
                     ("Station", "StationEntity"), ("Planet", "OOPlanetEntity"),
                     ("Waypoint", "OOWaypointEntity"), ("Wormhole", "WormholeEntity")):
    CHANGES[f"src/Core/Scripting/OOJS{_js}.h"] = [(f'#import "{_entity}.h"\n', "")]
# #748 moved each implementation's import of its entity header into the header; with the header's
# import out, the implementation keeps the history's own import
for _js, _entity, _anchor, _after in (
        ("Dock", "DockEntity", '#import "GameController.h"\n', False),
        ("Sound", "OOSound", '#import "ResourceManager.h"\n', False),
        ("Player", "PlayerEntity", '#import "PlayerEntityContracts.h"\n', False),
        ("Station", "StationEntity", '#import "OOShipRegistry.h"\n', True),
        ("Planet", "OOPlanetEntity", '#import "OOJavaScriptEngine.h"\n', True),
        ("Waypoint", "OOWaypointEntity", '#import "OOJavaScriptEngine.h"\n', True),
        ("Wormhole", "WormholeEntity", '#import "OOJavaScriptEngine.h"\n', True)):
    _imp = f'#import "{_entity}.h"\n'
    CHANGES[f"src/Core/Scripting/OOJS{_js}.mm"] = [(_anchor, _anchor + _imp if _after else _imp + _anchor)]


# Warnings in the history's own step-11 code under Clang 23 (-Wunused-but-set-global, which the
# history's compiler did not have), fixed in the forms the history reaches by step 19:
#  - the texture trace context is written and never read: the markers are no-ops
#  - the Manifest prototype is stored and never read: it is not stored
_BS = "\\"
_TRACE_OLD = ("#ifdef OO_DEBUG_MONITOR_ENABLED\nnamespace {\n\nconst char* sGlobalTraceContext = nullptr;\n\n"
              "} // namespace\n\n#define SET_TRACE_CONTEXT(str)       " + _BS + "\n    do {                             " + _BS + "\n"
              "        sGlobalTraceContext = (str); " + _BS + "\n    } while (0)\n#else\n#define SET_TRACE_CONTEXT(str) " + _BS + "\n"
              "    do {                       " + _BS + "\n    } while (0)\n#endif\n")
_TRACE_NEW = ("// The ObjC tree kept a trace context here for the debug monitor; nothing reads it, so the\n"
              "// markers are no-ops in every build.\n#define SET_TRACE_CONTEXT(str) " + _BS + "\n"
              "    do {                       " + _BS + "\n    } while (0)\n")
POST = dict(globals().get("POST", {}))
POST["src/Core/Materials/OOTexture.mm"] = list(POST.get("src/Core/Materials/OOTexture.mm", [])) + [(_TRACE_OLD, _TRACE_NEW)]
CHANGES["src/Core/Scripting/OOJSManifest.mm"] = [
    ("namespace {\nstatic ooscript::Object sManifestPrototype;\n} // namespace\n", ""),
    ("    sManifestPrototype = (proto);\n", ""),
]


# The history's own fix (f4fc8a0dd, oo-lglaq) is brought forward from step 16: the history's
# texture tests that arrive here pin the optimised build's 2 for OORoundUpToPowerOf2_32(1), which
# the unfixed expression leaves undefined (__builtin_clz(0)), and the series' test build is not -O2.
_RU_OLD_NOTE = "/* Round integer up to nearest power of 2. NOTE: these return 0 if the high bit of value is set. */\n"
_RU_NEW_NOTE = ("/* Round integer up to nearest power of 2.\n"
                "   The expression has no defined value for 1 (__builtin_clz(0)) nor for 0 and values above the\n"
                "   high bit (a shift by -1). Those inputs return what the optimised x86-64 build has always\n"
                "   returned for them, so debug and release agree (bead oo-lglaq): 2 for 1, and 1 for 0 and for\n"
                "   values above the high bit (not 0, as an older note here said). */\n")
CHANGES["src/Core/OOFastArithmetic.h"] = [
    (_RU_OLD_NOTE, _RU_NEW_NOTE),
    ("    return 0x80000000U >> (__builtin_clz(value - 1) - 1);\n",
     "    if (value == 1)\n        return 2;\n    int zeros = __builtin_clz(value - 1);\n"
     "    return (zeros == 0) ? 1 : 0x80000000U >> (zeros - 1);\n"),
    ("    return 0x8000000000000000ULL >> (__builtin_clzll(value - 1) - 1);\n",
     "    if (value == 1)\n        return 2;\n    int zeros = __builtin_clzll(value - 1);\n"
     "    return (zeros == 0) ? 1 : 0x8000000000000000ULL >> (zeros - 1);\n"),
]
