# Step 6 resolutions.
RES = {
    # history's accessor + upstream's new deployment-quiet default (#756)
    "src/Core/Debug/OODebugStandards.mm": [
        "    int s = oo::PListView(prefs).get<int>(@\"enforce-oxp-standards\", STANDARDS_ENFORCEMENT_DEFAULT);\n",
    ],
    # the history replaced the NSTimer with std::chrono scheduling; the Mac-only event-tracking
    # addTimer needs that timer and goes with it
    "src/Core/GameController.mm": ["theirs"],
}
# upstream (#737) deleted this dead Mac fullscreen category; the history's edits to it are moot
DELETE = ["src/Core/GameController+FullScreen.mm"]
