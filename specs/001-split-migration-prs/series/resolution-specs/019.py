# Step 19 resolutions (the history pulls upstream 9ee8ff22f and ports it): the history's own port
# where both sides carry the same (<= 9ee8ff22f) change; upstream's later changes (#766) kept.
RES = {
    ".github/workflows/test_builds.yaml": ["theirs", "theirs"],
    "ShellScripts/Windows/install_deps.sh": ["theirs"],
    "ShellScripts/common/post_build.sh": ["theirs"],
    "src/Core/Debug/OODebugStandards.cpp": ["theirs"],
    "src/Core/Debug/OODebugTCPConsoleClient.cpp": ["theirs"],  # macOS socket path deferred with macOS
    "src/Core/Entities/PlayerEntity.cpp": ["theirs", "theirs"],  # the history's port of #740 (develop's)
    "src/Core/GameController.cpp": ["ours"],  # #766: OOLITE_SDL in the debug-monitor exit guard
    "src/Core/Materials/OOTexture.cpp": ["theirs"],
    "src/Core/OOMaths.h": ["theirs", "theirs"],
    "src/Core/OOOXZManager.cpp": ["theirs", "theirs"],  # the history's C++ copy-URL port
    "src/Core/OOOpenGLOnly.h": ["ours"],  # #766: GL_GLEXT_PROTOTYPES on macOS too
    "src/SDL/MyOpenGLView.cpp": ["ours"],  # Linux stubs stay removed (#747)
}
DELETE = []
