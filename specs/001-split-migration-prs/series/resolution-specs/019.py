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
    "src/SDL/MyOpenGLView.cpp": ["ours"],  # Linux stubs stay removed (#747)
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
CHANGES["src/meson.build"] = [(_THREADS_019 + "# Bead oo-bipqn: ", "# Bead oo-bipqn: ")]
# the history separates winsock2.h from windows.h here, with its comment (step 10 did it first)
RES["src/Core/OOFoundation.h"] = ["theirs"]
