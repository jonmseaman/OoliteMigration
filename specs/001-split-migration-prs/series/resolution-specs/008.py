# Step 8 resolutions (Foundation -> oofnd wave 2).
COPYURL_DECL = lambda ours, theirs: theirs.replace(
    "    oo::PList n_key_oxzmanager_showinfo;\n",
    "    oo::PList n_key_oxzmanager_showinfo;\n    oo::PList n_key_oxzmanager_copyurl;\n")
COPYURL_CHECK = lambda ours, theirs: theirs.replace(
    "n_key_oxzmanager_showinfo && n_key_oxzmanager_extract &&",
    "n_key_oxzmanager_showinfo && n_key_oxzmanager_copyurl && n_key_oxzmanager_extract &&")
RES = {
    # the history replaced the notification-name global; upstream's side is otherwise formatting
    "src/Core/Debug/OODebugMonitor.mm": ["theirs", "theirs"],
    # history's oo::Defaults + upstream's deployment-quiet default (#756)
    "src/Core/Debug/OODebugStandards.mm": [
        lambda ours, theirs: theirs.replace("STANDARDS_ENFORCEMENT_WARN", "STANDARDS_ENFORCEMENT_DEFAULT")],
    # the history's plain-socket client covers upstream's macOS socket change (#766) on every platform
    "src/Core/Debug/OODebugTCPConsoleClient.h": ["theirs"],
    "src/Core/Debug/OODebugTCPConsoleClient.mm": ["theirs", "theirs", "theirs", "theirs"],
    # history's oo::PList key members + upstream's copy-URL key
    "src/Core/Entities/PlayerEntity.h": [COPYURL_DECL],
    "src/Core/Entities/PlayerEntity.mm": ["theirs", COPYURL_CHECK],  # the history converts the cargo arrays (step 3 fixed them)
    # the history factored the per-platform keymap file into KeyMappingsFileName() (Mac deferred)
    "src/Core/Entities/PlayerEntityKeyMapper.mm": ["theirs", "theirs"],
    "src/Core/OOOXZManager.mm": [
        "theirs",  # NSURLConnection is gone in the history; the category is private
        # upstream's copy-URL support (setOXPURL:) + history's filter signature
        "- (void)setOXPURL:(NSString*)url\n"
        "{\n"
        "    DESTROY(_currentOXPURL);\n"
        "    _currentOXPURL = [[url lowercaseString] copy]; // copy retains\n"
        "}\n"
        "\n"
        "- (oo::PList)applyCurrentFilter:(const oo::PList&)list\n",
        # history's text; upstream keeps the URL for the copy-URL key instead of copying it at once
        "            const std::optional<std::string> infoURL = ManifestString(manifest, oo::StdString(kOOManifestInformationURL));\n"
        "            [gui cxx_setText:DescFormat(DESC(@\"oolite-oxzmanager-infopage-infourl-@\"),\n"
        "                                 { Arg(infoURL) })\n"
        "                      forRow:25\n"
        "                       align:GUI_ALIGN_LEFT];\n"
        "            [self setOXPURL:oo::NSStringOrNil(infoURL)];\n",
    ],
    "src/Core/Octree.h": ["theirs"],  # comment naming the history's cxx_ initialiser
    "src/Core/Universe.h": ["theirs"],  # history's cxx_ declarations (selector names already upstream's)
    "src/SDL/MyOpenGLView.mm": [
        "both",
        "#if !OOLITE_MAC_OS_X\n"
        "    // On macOS SDL would set this 32x32 image as the Dock icon, replacing the bundle's\n"
        "    // high-resolution oolite-icon.icns.\n"
        "    const std::string imagesDir = oo::fs::utf8String(oo::ResourcePaths::current().builtInResourcesDirectory() / \"Images\");\n"
        "    SDL_Surface* icon = SDL_LoadBMP(oo::str::appendingPathComponent(imagesDir, \"WMicon.bmp\").c_str());\n",
        "#endif\n"
        "    OO_LOG(\"display.initGL\", \"V-Sync {}requested.\", vSyncPreference ? \"\" : \"not \");\n",
        "#endif\n"
        "        OO_LOG_WARN(\"display.initGL\", \"Could not enable V-Sync. Please check that your graphics driver supports the {}_swap_control extension.\", OOLITE_WINDOWS ? \"WGL_EXT\" : \"[GLX_SGI/GLX_MESA]\");\n",
        "        if (!SDL_SetClipboardText(clipboardText)) {\n"
        "            OO_LOG(\"stringToClipboard.failed\", \"Failed to copy string {} to clipboard: {}\", stringToCopy, SDL_GetError());\n",
        "#endif\n"
        "    OO_LOG(\"screenshot\", \"Saving screen shot \\\"{}\\\" ({} x {} pixels).\", *pathToPic, static_cast<unsigned>(surface->w), static_cast<unsigned>(surface->h));\n",
    ],
}
DELETE = []
# the history converts these functions; its forms supersede step 3's Clang 23 fixes
RES["src/Core/Entities/ShipEntity.mm"] = ["theirs"]
RES["src/Core/OOStringExpander.mm"] = ["theirs", "theirs"]


# the history rewrites the QuickJS-ng subproject call; step 4's Windows threads override stays before it
_THREADS_008 = (
    "# QuickJS-ng adds dependency('threads') (-pthread) to its link line, and every target\n"
    "# that links it. The MinGW clang driver does not use -pthread when linking (cutils.h takes Win32\n"
    "# threads under _WIN32), so each link printed \"argument unused during compilation: '-pthread'\".\n"
    "# On Windows the threads dependency is the same compile flag without the unused link flag, so the\n"
    "# objects and the links are unchanged and the driver has nothing to report.\n"
    "if host_machine.system() == 'windows'\n"
    "    meson.override_dependency('threads', declare_dependency(compile_args: ['-pthread']))\n"
    "endif\n")


def _threads_008(ours, theirs):
    assert theirs.count("quickjs_ng_proj = subproject(") == 1
    return theirs.replace("quickjs_ng_proj = subproject(", _THREADS_008 + "quickjs_ng_proj = subproject(")


RES["src/meson.build"] = [_threads_008]
# main.mm: the history drops the runtime and NSDate imports from the head (the game headers come first
# now); upstream's guard (#766) stays
RES["src/SDL/main.mm"] = ["#if defined(GNUSTEP_BASE_LIBRARY) || defined(OOLITE_SDL_MAC)\n"]
# the history adds its -O2 wrap patch here; step 4's void-return patch joins it on one diff_files line
# (meson reads one value per key), in develop's order
try:
    CHANGES
except NameError:
    CHANGES = {}
CHANGES["subprojects/quickjs-ng.wrap"] = [("diff_files = quickjs-ng-void-return.patch\ndiff_files = quickjs-ng-o2.patch\n",
                                           "diff_files = quickjs-ng-o2.patch, quickjs-ng-void-return.patch\n")]
exec(open(__file__.replace("008.py", "008_late.py"), encoding="utf-8").read())


# the containers selector gets a named second part (see selector_containers.py)
exec(open(__file__.replace("008.py", "selector_containers.py"), encoding="utf-8").read())
RENAMES = list(globals().get("RENAMES", [])) + CONTAINERS_RENAMES
