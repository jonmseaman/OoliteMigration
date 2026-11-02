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


# OOFoundation.h (upstream's #737 name for the history's OOCocoa.h): upstream moved the Foundation
# import to the top (#748); the history drops Foundation here (oofnd's types replace it). The merge
# took the history's deletion at the old place and kept upstream's moved copy; it goes.
CHANGES["src/Core/OOFoundation.h"] = [("#pragma once\n\n#import <Foundation/Foundation.h>\n", "#pragma once\n\n")]


# Upstream's copy-URL key (#747): NSString goes in this step, so the recorded URL becomes the history's
# std::optional<std::string> here (the methods stay Objective-C until the class is C++ in step 12)
CHANGES["src/Core/OOOXZManager.h"] = [("    NSString* _currentOXPURL;\n",
    "    std::optional<std::string> _currentOXPURL; // lowercase; the info page's URL, nullopt: none (was nil)\n")]
CHANGES["src/Core/OOOXZManager.mm"] = [
    ("- (void)setOXPURL:(NSString*)url\n{\n    DESTROY(_currentOXPURL);\n    _currentOXPURL = [[url lowercaseString] copy]; // copy retains\n}\n",
     "- (void)setOXPURL:(const std::optional<std::string>&)url\n{\n"
     "    _currentOXPURL = url.has_value() ? std::optional<std::string>(oo::str::lowercase(*url)) : std::nullopt;\n}\n"),
    ("            [self setOXPURL:oo::NSStringOrNil(infoURL)];\n", "            [self setOXPURL:infoURL];\n"),
    ("            if (_currentOXPURL != nil)\n                [[UNIVERSE gameView] cxx_stringToClipboard:oo::StdString(_currentOXPURL)];\n",
     "            if (_currentOXPURL.has_value())\n                [[UNIVERSE gameView] cxx_stringToClipboard:*_currentOXPURL];\n"),
]
# the normaliser's include sorting put windows.h before winsock2.h, which must come first (the
# history's order); winsock2.h is restored first, in a block of its own
CHANGES["src/Core/OOFoundation.h"].append(("#include <windows.h>\n#include <winsock2.h>\n",
                                           "#include <winsock2.h>\n\n#include <windows.h>\n"))
