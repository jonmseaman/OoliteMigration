# Step 17 resolutions (.mm -> .cpp, Objective-C runtime out): the history's #include lists win over
# upstream's #import reordering (#748); upstream's needed headers are kept.
def sdl_clipboard(ours, theirs):
    if "SDL3/SDL_clipboard.h" in theirs:
        return theirs
    assert '#include "png.h"\n' in theirs
    return theirs.replace('#include "png.h"\n', '#include "png.h"\n#include <SDL3/SDL_clipboard.h>\n')

RES = {p: ["theirs"] for p in (
    "src/Core/Materials/OOConcreteTexture.cpp", "src/Core/Materials/OOShaderUniformMethodType.h",
    "src/Core/OOALSoundChannel.h", "src/Core/OOJoystickManager.h",
    "src/Core/Scripting/EntityOOJavaScriptExtensions.cpp", "src/Core/Scripting/OOJSDock.cpp",
    "src/Core/Scripting/OOJSEntity.cpp", "src/Core/Scripting/OOJSEquipmentInfo.cpp",
    "src/Core/Scripting/OOJSPlayer.cpp", "src/Core/Scripting/OOJSPlayerShip.cpp",
    "src/Core/Scripting/OOJSShip.cpp", "src/Core/Scripting/OOJSSound.cpp", "src/Core/Scripting/OOJSStation.cpp",
    "src/Core/Scripting/OOJSWaypoint.cpp", "src/Core/Scripting/OOJSWormhole.cpp",
    "src/SDL/MyOpenGLView+Input.cpp",
    "src/meson/meson.build",  # the history's flags; upstream's darwin arms (#766) deferred with macOS
)}
RES["src/Core/OOHPVector.h"] = ["ours"]  # as in step 9: upstream dropped the closing guard for #pragma once
RES["src/Core/meson.build"] = [lambda ours, theirs: theirs.replace("'OOCocoa.cpp'", "'OOFoundation.cpp'")]
RES["src/SDL/MyOpenGLView.cpp"] = [sdl_clipboard]
DELETE = []
# the history rewrites the include blocks; step 2's <vector> include is not needed by its form
RES["src/Core/Entities/ShipEntityAI.cpp"] = ["theirs"]
RES["src/Core/OOStringParsing.cpp"] = ["theirs"]
# step 3's <vector> includes meet the history's rewritten include blocks; the history's blocks win
for _p in ("src/Core/CollisionRegion.cpp", "src/Core/Entities/DockEntity.cpp", "src/Core/Entities/PlayerEntity.cpp",
           "src/Core/Entities/PlayerEntityLegacyScriptEngine.cpp", "src/Core/GuiDisplayGen.cpp",
           "src/Core/HeadUpDisplay.cpp", "src/Core/OOMesh.cpp", "src/Core/OOPolygonSprite.cpp",
           "src/Core/Scripting/OOJSFunction.cpp", "src/Core/Universe.cpp"):
    RES[_p] = ["theirs"]


# The history's include list wins; upstream's png, SDL init and SDL3 clipboard headers (#747) stay.
def _sdl_includes_017(ours, theirs):
    return theirs + '#include "png.h"\n#include <SDL3/SDL_clipboard.h>\n#include <SDL3/SDL_init.h>\n'


del RES["src/SDL/MyOpenGLView.cpp"]  # (the automatic merge keeps upstream's png and SDL headers)


# OOMaths.h: the history changes its GL-include condition here (no Objective-C units remain); step 10
# carried that condition into upstream's #748 layout, so the change is made there too (the automatic
# merge read the moved block as an upstream deletion and dropped the history's edit).
try:
    CHANGES
except NameError:
    CHANGES = {}
CHANGES["src/Core/OOMaths.h"] = [(
    '#include "OOFunctionAttributes.h"\n#ifdef __OBJC__\n#include "OOOpenGL.h"\n',
    '#include "OOFunctionAttributes.h"\n#if defined(__cplusplus) && !defined(OO_PLAIN_CPP_UNIT) // was __OBJC__: a game unit, not a plain C++ one\n#include "OOOpenGL.h"\n')]
# the history deletes the oofnd Objective-C headers here; the include order steps 6 and 10 restored goes with them
DELETE = list(globals().get("DELETE", [])) + ["src/oofnd/objc/OOObjCPeer.h", "src/oofnd/objc/OOObjCRef.h"]


# Upstream (#748) and the history (here) each put a #pragma once at the top of a header; the merge
# keeps both. The first is kept. (Vendored miniz.h is left as it is.)
RENAMES = list(globals().get("RENAMES", [])) + [
    # a second #pragma once anywhere below the first
    (r"(?ms)\A(.*?^#pragma once\n.*?)^#pragma once\n(?:[ \t]*\n)?", r"\1", r"^#pragma once",
     ["src", ":(exclude)src/SDL/EXRSnapshotSupport"]),
    # upstream's #748 imports in headers the history makes C++ here; they forward-declare the class,
    # as the history's own port of #748 (step 19) leaves them
    (r'(?m)^#import "(?:OOEquipmentType|PlayerEntity|ShipEntity)\.h"\n', "",
     r'^#import "(OOEquipmentType|PlayerEntity|ShipEntity)\.h"',
     [f"src/Core/Scripting/OOJS{n}.h" for n in ("EquipmentInfo", "PlayerShip", "Ship")]),
    # OOJSVisualEffect.h declares a function returning std::vector<oo::EntityHold>, which the entity
    # header gave it: it includes OOEntityHold.h instead, as the history's header does by step 19
    # (the format pass sorts includes from here, so a header includes what it uses)
    (r'(?m)^#import "OOVisualEffectEntity\.h"\n', '#include "OOEntityHold.h"\n',
     r'^#import "OOVisualEffectEntity\.h"', ["src/Core/Scripting/OOJSVisualEffect.h"]),
]
POST = dict(globals().get("POST", {}))
POST["src/Core/OOHPVector.h"] = list(POST.get("src/Core/OOHPVector.h", [])) + [
    ("#pragma once\n\n#pragma once\n\n", "#pragma once\n\n")]
# OOMaths.h includes OOHPVector.h after the types it needs; the header's own include of it, which the
# format pass sorts ahead of OOMaths.h, goes, as in the history's header by step 19
POST["src/Core/Materials/OOShaderUniformMethodType.h"] = list(POST.get("src/Core/Materials/OOShaderUniformMethodType.h", [])) + [
    ('#include "OOHPVector.h"\n#include "OOMaths.h"\n', '#include "OOMaths.h"\n')]


# Upstream (#737) renamed OOCocoa.mm to OOFoundation.mm; the history makes it OOCocoa.cpp here. With
# the include rename both sides hold the same text, under two names: it is OOFoundation.cpp, the
# name this step's meson.build resolution builds.
DELETE = list(globals().get("DELETE", [])) + ["src/Core/OOCocoa.cpp", "src/Core/OOFoundation.mm"]
ADD = dict(globals().get("ADD", {}))
ADD["src/Core/OOFoundation.cpp"] = "017_files/OOFoundation.cpp"
