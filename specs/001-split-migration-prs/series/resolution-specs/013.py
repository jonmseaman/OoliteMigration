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
