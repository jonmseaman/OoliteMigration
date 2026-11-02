# Step 19 resolutions (the history pulls upstream 9ee8ff22f and ports it): the history's own port
# where both sides carry the same (<= 9ee8ff22f) change; upstream's later changes (#766) kept.
RES = {
    # upstream #782 (no Fedora AppImage) and #766 (macOS job) are later than the history's pull
    ".github/workflows/test_builds.yaml": ["ours", "ours"],
    "ShellScripts/Windows/install_deps.sh": ["theirs"],
    "ShellScripts/common/post_build.sh": ["theirs"],
    "src/Core/Debug/OODebugStandards.cpp": ["theirs"],
    "src/Core/Debug/OODebugTCPConsoleClient.cpp": ["theirs"],  # macOS socket path deferred with macOS
    "src/Core/Entities/PlayerEntity.cpp": ["theirs"],  # the history's port of #740 (develop's)
    "src/Core/GameController.cpp": ["ours"],  # #766: OOLITE_SDL in the debug-monitor exit guard
    "src/Core/Materials/OOTexture.cpp": ["theirs"],
    "src/Core/OOMaths.h": ["theirs", "theirs", "theirs"],
    "src/Core/OOOXZManager.cpp": ["theirs"],  # the history's C++ copy-URL port
    "src/Core/OOOpenGLOnly.h": ["ours"],  # #766: GL_GLEXT_PROTOTYPES on macOS too
    # the includes are already in the file's include block; the history's port of #744 removes the
    # dark-mode API the history's test needed until here
    "src/SDL/MyOpenGLView.cpp": ["ours", "theirs"],
    "src/SDL/MyOpenGLView.h": ["theirs"],  # (its declarations go with it)
}
DELETE = []
# step 2 removed the unused system prototype; the history removes it here too
RES["src/Core/Scripting/OOJSSystem.cpp"] = ["theirs", "theirs"]
# the history removes the unused manifest object here too (step 4 did, earlier)
RES["src/Core/Scripting/OOJSManifest.cpp"] = ["theirs"]


# The history adds what step 4 brought forward (OOJSShipGroup.h's includes, the Windows threads
# override) at another place in the file; step 4's copies give way to the history's text.
_THREADS_019 = (
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
CHANGES["src/Core/Scripting/OOJSShipGroup.h"] = [(
    "#include \"ooscript/JSEngine.hpp\"\n\n#include \"OOFoundation.h\"\n#include \"ooscript/JSEngine.hpp\"\n",
    "#include \"ooscript/JSEngine.hpp\"\n")]
# (the threads override's copy goes at step 16, where the history adds its own)
# the history separates winsock2.h from windows.h here, with its comment (step 10 did it first)
RES["src/Core/OOFoundation.h"] = ["theirs"]

# step 15's logical-or key checks give way to the history's own fix of the same warning
RES["src/Core/Entities/PlayerEntityControls.cpp"] = ["theirs"] * 7
# The history closes OOMATHS_STANDALONE's block and then its include guard; the series keeps
# upstream's #pragma once (#748), and the resolution dropped the block's #endif with the guard's
POST = dict(globals().get("POST", {}))
POST["src/Core/OOMaths.h"] = [('#include "legacy_random.h"\n\n#ifdef __cplusplus\n',
                               '#include "legacy_random.h"\n#endif\n\n#ifdef __cplusplus\n')]
