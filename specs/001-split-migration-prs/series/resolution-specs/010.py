# Step 10: the history adds its own extern "C++" block for the GL debug-string declarations; step 3's
# earlier wrapper (the same fix, brought forward) gives way to it.
RES = {}
CHANGES = {"src/Core/OOOpenGL.h": [
    ("#ifdef __cplusplus\nextern \"C++\" { // (this header is sometimes reached from inside OOMaths.h's extern \"C\" block)\n#endif\n#ifdef __cplusplus\n",
     "#ifdef __cplusplus\n"),
    ("}\n#endif\n#ifdef __cplusplus\n}\n#endif\n", "}\n#endif\n"),
]}


# The history starts compiling plain C units here (OOVoxel.c, for one), so OOMaths.h includes only the
# GL types outside Objective-C (OOOpenGL.h brings in Foundation). Upstream's #748 OOMaths.h includes
# OOOpenGL.h unconditionally and drops OOMATHS_OPENGL_INTEGRATION; the history's condition is put in
# upstream's layout. (By step 19 the history includes OOOpenGL.h unconditionally again.)
RES["src/Core/OOMaths.h"] = [""]
POST = {"src/Core/OOMaths.h": [(
    '#include "OOFunctionAttributes.h"\n#include "OOOpenGL.h"\n',
    '#include "OOFunctionAttributes.h"\n'
    '#ifdef __OBJC__\n'
    '#include "OOOpenGL.h"\n'
    '#else\n'
    '/*	A plain C or C++ translation unit (OOVoxel.c, for one) needs only the GL types. OOOpenGL.h\n'
    '        imports OOFoundation.h, i.e. Foundation, which does not compile outside Objective-C.\n'
    '*/\n'
    '#include "OOOpenGLOnly.h"\n'
    '#endif\n')]}


# the same include order for the new oofnd peer header as for OOObjCRef.h (step 6)
CHANGES["src/oofnd/objc/OOObjCPeer.h"] = [("#include <objc/objc-arc.h>\n#include <objc/runtime.h>\n",
                                           "#include <objc/runtime.h>\n\n#include <objc/objc-arc.h>\n")]


# the containers selector gets a named second part (see selector_containers.py)
exec(open(__file__.replace("010.py", "selector_containers.py"), encoding="utf-8").read())
RENAMES = list(globals().get("RENAMES", [])) + CONTAINERS_RENAMES
