# Step 14 resolutions (Universe and PlayerEntity slices). Earlier ports re-applied where the history
# moved the code (POST replacements on the resolved file).
def guard(ours, theirs):
    if "OO_DEBUG_MONITOR_ENABLED" in ours:
        theirs = theirs.replace("#ifndef NDEBUG", "#ifdef OO_DEBUG_MONITOR_ENABLED")
    return theirs

def copyurl_check(ours, theirs):
    old = "[self checkKeyPress:_cxxPlayer->n_key_oxzmanager_showinfo] ||\n"
    assert old in theirs
    return theirs.replace(old, old + theirs[theirs.index("[self checkKeyPress:_cxxPlayer->n_key_oxzmanager_showinfo]") - 16:
                                           theirs.index("[self checkKeyPress:_cxxPlayer->n_key_oxzmanager_showinfo]")]
                          + "[self checkKeyPress:_cxxPlayer->n_key_oxzmanager_copyurl] ||\n")

def copyurl_branch(ours, theirs):
    old = "                    } else if ([self checkKeyPress:_cxxPlayer->n_key_oxzmanager_extract]) {\n"
    assert old in theirs
    return theirs.replace(old, "                    } else if ([self checkKeyPress:_cxxPlayer->n_key_oxzmanager_copyurl]) {\n"
                               "                        [oxzmanager processCopyUrlKey];\n" + old)

RES = {
    "src/Core/Entities/PlayerEntityControls.mm": [copyurl_check, copyurl_branch],  # upstream's copy-URL key
    "src/Core/Universe.mm": ["theirs", "theirs", guard],
    "src/SDL/MyOpenGLView+Input.mm": ["theirs", "theirs"],
}
POST = {
    "src/Core/Universe.mm": [  # upstream #766: GL program names
        ("GLhandleARB program = [textureProgram program];", "GLuint program = OOGLProgramName([textureProgram program]);"),
        ("GLhandleARB blur = [blurProgram program];", "GLuint blur = OOGLProgramName([blurProgram program]);"),
        ("GLhandleARB final = [finalProgram program];", "GLuint final = OOGLProgramName([finalProgram program]);"),
        ('glGetUniformLocation([blurProgram program], "imageIn")', 'glGetUniformLocation(blur, "imageIn")'),
    ],
    "src/SDL/MyOpenGLView+Input.mm": [  # upstream #766: high-DPI mouse
        ("SDL_WarpMouseInWindow(window, viewSize.width / 2, viewSize.height / 2);\n",
         "// viewSize is in pixels; SDL mouse coordinates are in points (they differ on high-DPI displays)\n"
         "        float pixelDensity = SDL_GetWindowPixelDensity(window);\n"
         "        if (pixelDensity <= 0.0f)\n"
         "            pixelDensity = 1.0f;\n"
         "        SDL_WarpMouseInWindow(window, viewSize.width / 2 / pixelDensity, viewSize.height / 2 / pixelDensity);\n"),
        ("saveWindowSize(viewSize); // Save the updated window size\n",
         "// Save the window size in points, not pixels: they differ on high-DPI displays,\n"
         "            // and the saved size is passed back to SDL_SetWindowSize().\n"
         "            int windowWidth, windowHeight;\n"
         "            SDL_GetWindowSize(window, &windowWidth, &windowHeight);\n"
         "            saveWindowSize(NSMakeSize(windowWidth, windowHeight));\n"),
    ],
}
# the history folded the +Input header into the view class
DELETE = ["src/SDL/MyOpenGLView+Input.h"]
