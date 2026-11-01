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


# Upstream's copy-URL key (#747) arrived as Objective-C methods; this step converts OOOXZManager to a
# C++ class, so they are ported here in the form the history's own port takes (step 19).
def subs(*pairs):
    def fn(text):
        for old, new in pairs:
            assert text.count(old) == 1, (old, text.count(old))
            text = text.replace(old, new)
        return text
    return fn


COPY_URL_OLD = '''- (void)processCopyUrlKey
{

    if (_interfaceState == OXZ_STATE_PICK_INSTALL || _interfaceState == OXZ_STATE_PICK_INSTALLED || _interfaceState == OXZ_STATE_PICK_REMOVE) {
        GuiDisplayGen* gui = [UNIVERSE gui];

        if (_interfaceShowingOXZDetail) {
            [[UNIVERSE gameView] stringToClipboard:_currentOXPURL];
        } else {'''
COPY_URL_NEW = '''void OOOXZManager::processCopyUrlKey()
{

    if (_interfaceState == OXZ_STATE_PICK_INSTALL || _interfaceState == OXZ_STATE_PICK_INSTALLED || _interfaceState == OXZ_STATE_PICK_REMOVE) {
        GuiDisplayGen* gui = [UNIVERSE gui];

        if (_interfaceShowingOXZDetail) {
            if (_currentOXPURL.has_value())
                [[UNIVERSE gameView] cxx_stringToClipboard:*_currentOXPURL];
        } else {'''
LIST_OLD = '''            NSDictionary* manifest = [_filteredList oo_dictionaryAtIndex:_item];
            // infoURL
            NSString* infoURLString = [manifest oo_stringForKey:kOOManifestInformationURL];
            // copy url info text to clipboard automatically once we are in the oxz info page
            [[UNIVERSE gameView] stringToClipboard:infoURLString];'''
LIST_NEW = '''            const oo::PList manifest = ElementAt(_filteredList, _item);
            // infoURL
            const std::optional<std::string> infoURL = ManifestString(manifest, std::string(kOOManifestInformationURL));
            // copy url info text to clipboard automatically once we are in the oxz info page
            if (infoURL.has_value())
                [[UNIVERSE gameView] cxx_stringToClipboard:*infoURL];'''

POST = {"src/Core/OOOXZManager.h": [  # a conflict path here: edits on the resolved file
    ("    void processShowInfoKey();\n", "    void processShowInfoKey();\n    void processCopyUrlKey();\n"),
    ("    void setFilter(const std::string& filter);\n",
     "    void setFilter(const std::string& filter);\n"
     "    void setOXPURL(const std::optional<std::string>& url); // lowercased; nullopt: none (was nil)\n"),
    ("    NSString* _currentOXPURL;\n",
     "    std::optional<std::string> _currentOXPURL; // lowercase; the info page's URL, nullopt: none (was nil)\n"),
]}

# the automatic resolution of the class file, with the port applied on top
EDIT = {"src/Core/OOOXZManager.mm": subs(
        ("- (void)setOXPURL:(NSString*)url\n{\n    DESTROY(_currentOXPURL);\n"
         "    _currentOXPURL = [[url lowercaseString] copy]; // copy retains\n}\n",
         "void OOOXZManager::setOXPURL(const std::optional<std::string>& url)\n{\n"
         "    _currentOXPURL = url.has_value() ? std::optional<std::string>(oo::str::lowercase(*url)) : std::nullopt;\n}\n"),
        ("            [self setOXPURL:oo::NSStringOrNil(infoURL)];\n", "            setOXPURL(infoURL);\n"),
        (COPY_URL_OLD, COPY_URL_NEW),
        (LIST_OLD, LIST_NEW),
)}

FIX = {
    "src/Core/OOOXZManager+ObjCBridge.h": subs(
        ("- (void)processShowInfoKey;\n", "- (void)processShowInfoKey;\n- (void)processCopyUrlKey;\n"),
    ),
    "src/Core/OOOXZManager+ObjCBridge.mm": subs(
        ("- (void)processShowInfoKey\n{\n    _cxxManager->processShowInfoKey();\n}\n",
         "- (void)processShowInfoKey\n{\n    _cxxManager->processShowInfoKey();\n}\n"
         "- (void)processCopyUrlKey\n{\n    _cxxManager->processCopyUrlKey();\n}\n"),
    ),
}
