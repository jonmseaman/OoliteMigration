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
