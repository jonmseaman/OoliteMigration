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
        "theirs",  # the history's C++ view (upstream's #766 guard is re-applied below)
        "theirs",
        # upstream #744 removed the undocumented dark-mode API; the history's unit test of the view
        # calls it until the history's own port of #744 (step 19), so the history's API stays to then,
        # inside upstream's Windows block (it is Windows-only)
        "both",
        # Linux stubs: upstream made three of these common (#747); the HDR stub stays, in the history's C++ form
        "bool cxx::MyOpenGLView::hdrOutput()\n",
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
            if (_currentOXPURL != nil)
                [[UNIVERSE gameView] cxx_stringToClipboard:oo::StdString(_currentOXPURL)];
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
    # (_currentOXPURL is a std::optional<std::string> from step 10)
]}

# the automatic resolution of the class file, with the port applied on top
EDIT = {"src/Core/OOOXZManager.mm": subs(
        # step 10 ported the state to std::optional<std::string>; the methods become members here
        ("- (void)setOXPURL:(const std::optional<std::string>&)url\n{\n",
         "void OOOXZManager::setOXPURL(const std::optional<std::string>& url)\n{\n"),
        ("            [self setOXPURL:infoURL];\n", "            setOXPURL(infoURL);\n"),
        ("- (void)processCopyUrlKey\n{\n", "void OOOXZManager::processCopyUrlKey()\n{\n"),
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

# upstream (#766) guards the full-screen setters with OOLITE_SDL instead of GNUSTEP_BASE_LIBRARY
POST["src/SDL/MyOpenGLView.mm"] = [("#ifdef GNUSTEP_BASE_LIBRARY\nvoid cxx::MyOpenGLView::setFullScreenMode(bool fsm)\n",
                                    "#if OOLITE_SDL\nvoid cxx::MyOpenGLView::setFullScreenMode(bool fsm)\n")]


# Upstream code the merge carries into the history's C++ view, in its terms:
#  - #774's splash-window replacement calls the C++ member
#  - #747 made getDisplayDimensions & co. common, so the history's Windows guard above them goes
#  - #766's mouse-motion pixel density reads the C++ view's window
POST["src/SDL/MyOpenGLView.mm"] += [
    # the dark-mode API kept for the history's test (above) needs the history's Windows declarations,
    # which #744 deleted with it
    ("#include <ctype.h>\n\nnamespace {\n",
     "#include <ctype.h>\n\n" + open(__file__.replace("012.py", "012_files/darkmode_block.mm"), encoding="utf-8").read()
     + "\nnamespace {\n"),
    ("        [self createWindowWithSize:firstScreen];\n", "        createWindowWithSize(firstScreen);\n"),
    ("#endif\n\n#if OOLITE_WINDOWS\nvoid cxx::MyOpenGLView::getDisplayDimensions(",
     "#endif\n\nvoid cxx::MyOpenGLView::getDisplayDimensions("),
]
# #747's common getDisplayDimensions is declared for every platform
POST["src/SDL/MyOpenGLView.h"] = [(
    "#if OOLITE_WINDOWS\n    void getDisplayDimensions(unsigned* width, unsigned* height);\n",
    "    void getDisplayDimensions(unsigned* width, unsigned* height);\n#if OOLITE_WINDOWS\n")]
POST["src/SDL/MyOpenGLView+Input.mm"] = [
    ("SDL_GetWindowPixelDensity(window);", "SDL_GetWindowPixelDensity(oo::ToCxx(self)->window);")]
# Upstream's #745 named this selector's parts (ri:rj:rk:...si:sj:sk:); the normaliser's table has no
# entry for it, so the merge mixed the two spellings in the call. The history's OOMesh bridge declares
# its own spelling here; the call uses it.
POST["src/Core/Entities/ShipEntity.mm"] = [(
    "    return [[self mesh] findBoundingBoxRelativeToPosition:HPVectorToVector(opv)\n"
    "                                                       ri:i\n"
    "                                                       rj:j\n"
    "                                                       rk:k\n"
    "                                             selfPosition:HPVectorToVector(_cxxEntity->position)\n"
    "                                                selfBasis:_cxxShip->\n"
    "                                                  v_right:_cxxShip->\n"
    "                                                     v_up:_cxxShip->v_forward];\n",
    "    return [[self mesh] findBoundingBoxRelativeToPosition:HPVectorToVector(opv)\n"
    "                                                    basis:i\n"
    "                                                         :j\n"
    "                                                         :k\n"
    "                                             selfPosition:HPVectorToVector(_cxxEntity->position)\n"
    "                                                selfBasis:_cxxShip->v_right\n"
    "                                                         :_cxxShip->v_up\n"
    "                                                         :_cxxShip->v_forward];\n")]


# the containers selector gets a named second part (see selector_containers.py)
exec(open(__file__.replace("012.py", "selector_containers.py"), encoding="utf-8").read())
RENAMES = list(globals().get("RENAMES", [])) + CONTAINERS_RENAMES


# The history's tests that arrive here (test_OOJSSystem) leave autoreleased OOJSValues in the
# thread's pools at exit, which libobjc drains after the CRT's static destructors; the freed values
# reached the destroyed JS registries and notification center (std::system_error at exit). The
# history's own fix (3179b9ce0, oo-9ht.173: the registries and the default center are immortal),
# which the history makes at step 14, is brought forward; its test change stays at step 14.
try:
    CHANGES
except NameError:
    CHANGES = {}
_IMMORTAL_NOTE = (
    "    // The process registries are immortal: allocated once and never destroyed (bead oo-9ht.173).\n"
    "    // libobjc drains a thread's open autorelease pools at thread detach, which on Windows runs after\n"
    "    // the CRT has destroyed namespace-scope objects; an autoreleased OOJSValue or script freed there\n"
    "    // still reaches them (beginRequest -> csOf, finalizers, roots). The same holds for every\n"
    "    // registry below that a finalizer or a façade call can reach.\n")
def _immortal(decl_type, name, comment=""):
    tail = f" // {comment}" if comment else ""
    return (f"    {decl_type} {name};{tail}\n", f"    {decl_type}& {name} = *new {decl_type};{tail}\n")
CHANGES["src/Core/Scripting/ooscript/JSEngine_quickjs.cpp"] = [
    ("    std::unordered_map<JSContext*, ContextState*> gContexts;\n",
     _IMMORTAL_NOTE + "    std::unordered_map<JSContext*, ContextState*>& gContexts = *new std::unordered_map<JSContext*, ContextState*>;\n"),
    _immortal("std::unordered_map<JSRuntime*, JSContext*>", "gCtxForRuntime", "finalizers get only a JSRuntime*"),
    _immortal("std::vector<const Value*>", "gConstructing", "vp blocks of constructor calls"),
    _immortal("std::unordered_map<JSClassID, BackendClass*>", "gClasses"),
    _immortal("std::unordered_map<void*, std::vector<SharedPermanent>>", "gSharedPermanent", "prototype -> entries (atoms owned)"),
    _immortal("std::unordered_map<std::string, JSValue>", "gScopeByFile", "owned references"),
    _immortal("std::vector<JSValue>", "gCallThis", "`this` of each façade call in progress (borrowed)"),
    ("    static std::unordered_map<JSClassID, ClassDef*> sForeign;\n",
     "    static std::unordered_map<JSClassID, ClassDef*>& sForeign = *new std::unordered_map<JSClassID, ClassDef*>; // immortal, as the registries above (bead oo-9ht.173)\n"),
    _immortal("std::unordered_map<JSContext*, FrameSnapshot>", "gFrames"),
    _immortal("std::unordered_map<std::string, ScriptRep*>", "gFrameScripts", "one stable Script token per filename"),
]
CHANGES["src/oofnd/Notification.hpp"] = [
    ("        static NotificationCenter center;\n",
     "        // Immortal (bead oo-9ht.173): an object freed by a pool drained at thread detach, after the\n"
     "        // CRT's static destructors, may still remove its observers here.\n"
     "        static NotificationCenter& center = *new NotificationCenter;\n"),
]
