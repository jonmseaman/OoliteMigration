# Step 3 hand resolutions (run after 003_custom.py).
RES = {}
# Joystick decoding: upstream #742 moved decode*Event into OOSDLJoystickManager (to silence an
# Objective-C GCC warning); the migration keeps them in OOJoystickManager, as develop does. Mixing
# the two (upstream's headers, the history's implementation) does not compile, so this step takes the
# history's four joystick files whole. Upstream's #748 `#pragma once` in the header returns with the
# history's own pull of upstream (step 19).
WHOLE = {p: "theirs" for p in ("src/Core/OOJoystickManager.h", "src/Core/OOJoystickManager.mm",
                               "src/SDL/OOSDLJoystickManager.h", "src/SDL/OOSDLJoystickManager.mm")}
# upstream (#737) deleted this dead Mac fullscreen category ("remove some crud"); not moved
DELETE = ["src/Core/GameController+FullScreen.mm"]


# Upstream's OOMaths.h (#748) includes OOOpenGL.h inside its extern "C" block, so from this step (the
# first C++ compile) the GL debug-string functions get C linkage where OOMaths.h comes first and C++
# linkage in OOOpenGL.mm, and the link fails. The history meets the same and fixes it in step 10 with
# an extern "C++" block; that fix is brought forward.
def _gl_debug_cxx_linkage(text):
    old = ("#ifndef NDEBUG\n\nNSString* OOGLColorToString(GLfloat color[4]);\nNSString* OOGLEnumToString(GLenum value);\n"
           "NSString* OOGLFlagToString(bool value);\n\n#endif\n")
    new = ("#ifndef NDEBUG\n\n#ifdef __cplusplus\n"
           "extern \"C++\" { // (this header is sometimes reached from inside OOMaths.h's extern \"C\" block)\n#endif\n"
           "NSString* OOGLColorToString(GLfloat color[4]);\nNSString* OOGLEnumToString(GLenum value);\n"
           "NSString* OOGLFlagToString(bool value);\n#ifdef __cplusplus\n}\n#endif\n\n#endif\n")
    assert text.count(old) == 1, text.count(old)
    return text.replace(old, new)


FIX = {"src/Core/OOOpenGL.h": _gl_debug_cxx_linkage}


# Clang 23 warnings in the files this step first compiles as Objective-C++. Each fix is the form the
# history itself reaches later, brought forward (rule 2: fixed, not silenced):
#  - variable-length arrays become std::vector (the history: as it converts each file); where the
#    array decays to a pointer, a `<name>Buffer` vector backs a pointer of the old name
#  - the GL state table: the history's own C++ table (declaration-order designators, the array
#    designators as comments); the same assignments, checked as multisets
#  - the rest as in the history's C++ files (Octree designator order, NSNotFound casts, `0 &&`,
#    `const char*` for string literals, the %S argument's unichar type)
import json as _json3
import os as _os3
_here = _os3.path.dirname(_os3.path.abspath(__file__))
CHANGES = {p: [tuple(x) for x in v] for p, v in _json3.load(open(_os3.path.join(_here, "003_vla.json"), encoding="utf-8")).items()}
_read = lambda name: open(_os3.path.join(_here, "003_files", name), encoding="utf-8").read()
CHANGES["src/Core/OOOpenGLStateManager.mm"] = [(_read("gl-states-table.before"), _read("gl-states-table.after"))]
CHANGES["src/Core/Octree.mm"] = [(
    "        .octree = _octree,\n        .radius = _radius,\n        .octree_collision = _collisionOctree\n",
    "        .radius = _radius,\n        .octree = _octree,\n        .octree_collision = _collisionOctree\n")]
CHANGES["src/Core/OOCPUInfo.mm"] = [("outUBRString, (const WCHAR*)osver.szCSDVersion]", "outUBRString, (const unichar*)osver.szCSDVersion]")]
CHANGES["src/Core/Materials/OOShaderProgram.mm"] = [("if (gDebugFlags & DEBUG_SHADER_VALIDATION && 0) {", "if (0 && (gDebugFlags & DEBUG_SHADER_VALIDATION)) {")]
# upstream compares an int with NSNotFound, so the not-found branch never runs; the history keeps that
# behaviour and makes the comparison explicit (step 19's form)
CHANGES["src/Core/Entities/PlayerEntityControls.mm"] = [("if (brightnessIdx == NSNotFound) {", "if (static_cast<NSInteger>(brightnessIdx) == NSNotFound) {")]
CHANGES["src/SDL/main.mm"] = [('    char* pathEnvVar = "Path";\n', '    const char* pathEnvVar = "Path";\n')]
_extra = {
    "src/Core/Entities/PlayerEntity.mm": [("if (brightnessIdx == NSNotFound) {", "if (static_cast<NSInteger>(brightnessIdx) == NSNotFound) {")],
    "src/Core/Universe.mm": [("    if (radius == NSNotFound) {\n", "    if (radius == static_cast<GLfloat>(NSNotFound)) {\n"),
                             ("    if (routeFraction == NSNotFound)\n", "    if (routeFraction == static_cast<double>(NSNotFound))\n")],
}
for _p, _v in _extra.items():
    CHANGES[_p] = CHANGES.get(_p, []) + _v
