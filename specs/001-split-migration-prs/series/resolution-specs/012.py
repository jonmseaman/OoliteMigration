# Step 12 resolutions (first slices, first facade deletions: MyOpenGLView, OOMesh, OOOXZManager become C++).
def guard(ours, theirs):
    if "OO_DEBUG_MONITOR_ENABLED" in ours:
        theirs = theirs.replace("#ifndef NDEBUG", "#ifdef OO_DEBUG_MONITOR_ENABLED")
    return theirs

def high_dpi_warp(ours, theirs):
    old = ("SDL_WarpMouseInWindow(oo::ToCxx(self)->window, oo::ToCxx(self)->viewSize.width / 2, "
           "oo::ToCxx(self)->viewSize.height / 2);\n")
    assert old in theirs
    new = ("// viewSize is in pixels; SDL mouse coordinates are in points (they differ on high-DPI displays)\n"
           "        float pixelDensity = SDL_GetWindowPixelDensity(oo::ToCxx(self)->window);\n"
           "        if (pixelDensity <= 0.0f)\n"
           "            pixelDensity = 1.0f;\n"
           "        SDL_WarpMouseInWindow(oo::ToCxx(self)->window, oo::ToCxx(self)->viewSize.width / 2 / pixelDensity, "
           "oo::ToCxx(self)->viewSize.height / 2 / pixelDensity);\n")
    return theirs.replace(old, new)

def save_size_in_points(ours, theirs):
    old = "[self saveWindowSize:oo::ToCxx(self)->viewSize]; // Save the updated window size\n"
    assert old in theirs
    new = ("// Save the window size in points, not pixels: they differ on high-DPI displays,\n"
           "            // and the saved size is passed back to SDL_SetWindowSize().\n"
           "            int windowWidth, windowHeight;\n"
           "            SDL_GetWindowSize(oo::ToCxx(self)->window, &windowWidth, &windowHeight);\n"
           "            [self saveWindowSize:NSMakeSize(windowWidth, windowHeight)];\n")
    return theirs.replace(old, new)

RES = {
    "src/Core/Entities/ShipEntity.h": ["theirs"],
    # OOMesh is C++ from this step; its Objective-C bridge keeps the history's selector spelling
    "src/Core/Entities/ShipEntity.mm": ["theirs"],
    "src/Core/OOMesh.h": ["theirs"],
    "src/Core/OOMesh.mm": [guard, "theirs", "theirs"],
    # the copy-URL key (upstream) must reach the bridge; the build checks it
    "src/Core/OOOXZManager.h": ["theirs"],
    # upstream #766: high-DPI mouse, in the history's C++ view
    "src/SDL/MyOpenGLView+Input.mm": [high_dpi_warp, save_size_in_points],
    # history's C++ members (#774's splash/game window port is deferred to step 023)
    "src/SDL/MyOpenGLView.h": ["theirs", "theirs"],
    "src/SDL/MyOpenGLView.mm": [
        "theirs",
        "ours",    # upstream #744 removed the undocumented dark-mode API: it stays removed
        "ours",    # Linux stubs: upstream made these methods common (#747)
        "theirs",  # macOS screenshot path (#766) deferred
    ],
}
DELETE = []
