# Step 16 resolutions (the root Entity facade).
RES = {
    "src/Core/Debug/OODebugSupport.mm": [
        "theirs",
        lambda ours, theirs: theirs.replace("#endif /* NDEBUG */", "#endif /* OO_DEBUG_MONITOR_ENABLED */"),
    ],
    # the history's C++ manager; upstream's copy-URL key needs its C++ port (deferred.md, from step 12)
    # upstream #747: the info page records the URL for the copy key instead of copying it at once
    "src/Core/OOOXZManager.mm": ["ours"],
    "src/SDL/MyOpenGLView.mm": [
        "ours",  # upstream #744 removed the undocumented dark-mode API: it stays removed
        # (the Linux stubs no longer conflict: step 12 keeps the history's C++ HDR stub)
    ],
}
DELETE = []


# The history moves this file's Universe and GUI calls to C++ here; step 12's copy-URL port follows,
# in the form of the history's own port (step 19).
_POST_016 = {"src/Core/OOOXZManager.mm": [
    ("        ::GuiDisplayGen* gui = [UNIVERSE gui];\n\n        if (_interfaceShowingOXZDetail) {\n"
     "            if (_currentOXPURL.has_value())\n"
     "                [[UNIVERSE gameView] cxx_stringToClipboard:*_currentOXPURL];\n"
     "        } else {\n            OOGUIRow selection = (gui != nullptr ? gui->getSelectedRow() : 0);\n",
     "        ::GuiDisplayGen* gui = (UNIVERSE != nullptr ? UNIVERSE->getGui() : nullptr);\n\n"
     "        if (_interfaceShowingOXZDetail) {\n"
     "            if (_currentOXPURL.has_value() && UNIVERSE != nullptr && UNIVERSE->getGameView() != nullptr)\n"
     "                UNIVERSE->getGameView()->stringToClipboard(*_currentOXPURL);\n"
     "        } else {\n            OOGUIRow selection = (gui != nullptr ? gui->getSelectedRow() : 0);\n"),
    ("            if (infoURL.has_value())\n                [[UNIVERSE gameView] cxx_stringToClipboard:*infoURL];\n",
     "            if (infoURL.has_value() && UNIVERSE != nullptr && UNIVERSE->getGameView() != nullptr)\n"
     "                UNIVERSE->getGameView()->stringToClipboard(*infoURL);\n"),
]}
try:
    POST.update(_POST_016)
except NameError:
    POST = _POST_016
# the history converts the arrays step 3 fixed (its forms win); the shader check keeps upstream's #756
# guard with the history's `0 &&` form
RES["src/Core/Entities/PlayerEntity.mm"] = ["theirs", "theirs"]
RES["src/Core/Entities/ShipEntity.mm"] = ["theirs", "theirs"]
RES["src/Core/Materials/OOShaderProgram.mm"] = ["ours"]
RES["src/Core/Scripting/OOJSFunction.mm"] = ["theirs"]
RES["src/Core/Universe.mm"] = ["theirs"] * 6
# the history turns the profiling #warning into a comment here (step 4 did the same, earlier)
RES["src/Core/Scripting/OOJSEngineTimeManagement.mm"] = ["theirs"]
# the history re-lists texture includes that the series already has lower down (its block once sorted)
RES["src/Core/Materials/OOConcreteTexture.mm"] = ["ours"]
# the history adds the same enum/float casts here (step 5 had them first) and converts the arrays
RES["src/Core/Entities/ShipEntity.mm"] = ["theirs"] * 4
# the containers calls become C++ member calls here (the selector, and its how_much: part, go)
RES["src/Core/Entities/ShipEntity.mm"] = ["theirs"] * 6
RES["src/Core/Scripting/OOJSShip.mm"] = ["theirs"]
# the history deletes the Universe facade here; step 15's selector part goes with it
DELETE = list(globals().get("DELETE", [])) + ["src/Core/Universe+ObjCBridge.h", "src/Core/Universe+ObjCBridge.mm"]


# The history adds the Windows threads override here (bead oo-bipqn), next to the copy step 4
# brought forward; step 4's copy gives way to the history's text.
_THREADS_016 = (
    "# QuickJS-ng adds dependency('threads') (-pthread) to its link line, and every target\n"
    "# that links it. The MinGW clang driver does not use -pthread when linking (cutils.h takes Win32\n"
    "# threads under _WIN32), so each link printed \"argument unused during compilation: '-pthread'\".\n"
    "# On Windows the threads dependency is the same compile flag without the unused link flag, so the\n"
    "# objects and the links are unchanged and the driver has nothing to report.\n"
    "if host_machine.system() == 'windows'\n"
    "    meson.override_dependency('threads', declare_dependency(compile_args: ['-pthread']))\n"
    "endif\n")
try:
    CHANGES
except NameError:
    CHANGES = {}
CHANGES["src/meson.build"] = [(_THREADS_016 + "# Bead oo-bipqn: ", "# Bead oo-bipqn: ")]
# the history's view class leaves namespace cxx here; the dark-mode API kept for its test follows
POST = dict(globals().get("POST", {}))
POST["src/SDL/MyOpenGLView.mm"] = list(POST.get("src/SDL/MyOpenGLView.mm", [])) + [
    ("void cxx::MyOpenGLView::refreshDarKOrLightMode()\n", "void MyOpenGLView::refreshDarKOrLightMode()\n")]
