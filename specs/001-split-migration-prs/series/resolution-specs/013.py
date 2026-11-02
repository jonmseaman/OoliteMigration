# Step 13 resolutions (ShipEntity slices).
def guard(ours, theirs):
    if "OO_DEBUG_MONITOR_ENABLED" in ours:
        theirs = theirs.replace("#ifndef NDEBUG", "#ifdef OO_DEBUG_MONITOR_ENABLED")
    return theirs

def gl_program_names(ours, theirs):
    # upstream #766: GL program handles as GLuint names (portable to the macOS context)
    out = theirs
    for p in ("textureProgram", "blurProgram", "finalProgram"):
        var = {"textureProgram": "program", "blurProgram": "blur", "finalProgram": "final"}[p]
        old = f"GLhandleARB {var} = [_cxxUniverse->{p} program];"
        assert old in out, old
        out = out.replace(old, f"GLuint {var} = OOGLProgramName([_cxxUniverse->{p} program]);")
    return out

def blur_uniform(ours, theirs):
    old = 'glGetUniformLocation([_cxxUniverse->blurProgram program], "imageIn")'
    assert old in theirs
    return theirs.replace(old, 'glGetUniformLocation(blur, "imageIn")')

RES = {
    "src/Core/Entities/ShipEntity.mm": ["theirs", "theirs"],  # upstream renamed parameters of now-C++ methods
    "src/Core/GameController.h": ["theirs"] * 4,  # Mac Cocoa-UI macro renames deferred with macOS
    "src/Core/Universe.h": [guard],
    "src/Core/Universe.mm": [
        "theirs", "theirs", "theirs",  # macOS multisample renderbuffer path (#766) deferred
        gl_program_names,
        blur_uniform,
        "theirs",  # Mac macro renames in code the history removed
    ],
}
DELETE = []
# The history's ShipEntity slices keep two variable-length arrays (now ::Entity*); step 3's std::vector
# fix is re-applied to its form. OOConvertCubeMapToLatLong: the history's own std::vector form.
RES["src/Core/Entities/ShipEntity.mm"] = ["theirs", "theirs", "theirs", "theirs"]
RES["src/Core/OOConvertCubeMapToLatLong.cpp"] = ["theirs"]
try:
    POST
except NameError:
    POST = {}
POST["src/Core/Entities/ShipEntity.mm"] = [
    ("\n    ::Entity* my_entities[ent_count];\n", "\n    std::vector<::Entity*> my_entities(ent_count);\n"),
    ("\n    ::ShipEntity* my_entities[ent_count];\n", "\n    std::vector<::ShipEntity*> my_entities(ent_count);\n"),
]


# step 5's C++20 enum/float casts re-applied to the history's slice form of these lines
def _enum_cast(ours, theirs):
    assert theirs.count(" * UNIVERSE_MAX_ENTITIES") == 1
    return theirs.replace(" * UNIVERSE_MAX_ENTITIES", " * static_cast<double>(UNIVERSE_MAX_ENTITIES)")


# (the second hunk: step 12's bounding-box call, which the history converts to C++ here)
RES["src/Core/Entities/ShipEntity.mm"] = ["theirs", "theirs", _enum_cast, _enum_cast, "theirs", "theirs", "theirs"]


# the history's C++ findBoundingBoxRelativeTo names its basis _i, _j, _k; the call's selector parts
# carry upstream's #745 names
POST["src/Core/Entities/ShipEntity.mm"] = list(POST["src/Core/Entities/ShipEntity.mm"]) + [
    ("    return [self findBoundingBoxRelativeToPosition:opv i:i j:j k:k];\n}\n",
     "    return [self findBoundingBoxRelativeToPosition:opv i:_i j:_j k:_k];\n}\n")]
# the macOS multisample renderbuffer path (#766) is deferred: its #if/#else went with the hunks, and
# its #endif goes too
POST["src/Core/Universe.mm"] = [
    ("_cxxUniverse->msaaTextureID, 0));\n#endif\n", "_cxxUniverse->msaaTextureID, 0));\n"),
    ("    OOGL(glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0));\n#endif\n",
     "    OOGL(glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0));\n"),
]
# the copy-URL port (step 12): the GUI is the C++ class from here, as at the file's other uses
try:
    CHANGES
except NameError:
    CHANGES = {}
CHANGES["src/Core/OOOXZManager.mm"] = [
    ("        GuiDisplayGen* gui = [UNIVERSE gui];\n\n        if (_interfaceShowingOXZDetail) {\n",
     "        ::GuiDisplayGen* gui = [UNIVERSE gui];\n\n        if (_interfaceShowingOXZDetail) {\n")]


# the containers selector gets a named second part (see selector_containers.py)
exec(open(__file__.replace("013.py", "selector_containers.py"), encoding="utf-8").read())
RENAMES = list(globals().get("RENAMES", [])) + CONTAINERS_RENAMES
