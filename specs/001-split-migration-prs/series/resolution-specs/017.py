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
