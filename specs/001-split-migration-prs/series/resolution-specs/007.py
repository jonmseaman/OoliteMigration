# Step 7 resolutions (after the #745/#737 rename transform): history's types and accessors +
# upstream's debug-monitor guards (#756), Mac fixes (#766), SDL3 clipboard (#747), Dock icon (#781).
RES = {
    "src/Core/AI.mm": ["theirs"],  # upstream side differs from base only in formatting
    "src/Core/Entities/PlayerEntity.mm": [
        # history's empty() check + upstream's new OXZ-manager copy-URL key
        lambda ours, theirs: theirs.replace(
            "n_key_oxzmanager_showinfo && n_key_oxzmanager_extract &&",
            "n_key_oxzmanager_showinfo && n_key_oxzmanager_copyurl && n_key_oxzmanager_extract &&"),
    ],
    "src/Core/Materials/OOShaderProgram.mm": [
        "OOShaderProgram* sActiveProgram = nil;\n"
        "\n"
        "BOOL GetShaderSource(const std::optional<std::string>& fileName, const std::string& shaderType, std::optional<std::string>* outResult);\n"
        "std::string GetGLSLInfoLog(GLhandleARB shaderObject);\n"
        "\n"
        "} // namespace\n"
        "\n"
        "#if OOLITE_MAC_OS_X\n"
        "static NSString* TranslateGLSL330To120(NSString* source, BOOL isVertexShader, NSMutableDictionary* attributeBindings);\n"
        "#endif\n",
    ],
    # history's cxx_userRootPaths; upstream's Mac bundle resource path (#766) is deferred (deferred.md)
    "src/Core/ResourceManager.mm": ["theirs"],
    "src/Core/Scripting/OOJSStation.mm": [
        # upstream's fix (#766): a missing shipyard personality defaults to 0 instead of raising
        "    if (!shipyardDefinition.get<oo::PList>(oo::StdString(SHIPYARD_KEY_PERSONALITY))) {\n"
        "        // default to 0 if not supplied\n"
        "        result[oo::StdString(SHIPYARD_KEY_PERSONALITY)] = oo::PList::unsignedInteger(0);\n",
    ],
    "src/Core/Scripting/OOJavaScriptEngine.h": [
        "        See comments for -descriptionComponents in OOFoundation.h. Strings, typed id: the selectors are\n"
        "        shared with the Foundation root class and every class that overrides them.\n",
    ],
    "src/SDL/MyOpenGLView.mm": [
        "both",  # upstream's png/SDL3 clipboard includes and history's oofnd includes
        "#if !OOLITE_MAC_OS_X\n"
        "    // On macOS SDL would set this 32x32 image as the Dock icon, replacing the bundle's\n"
        "    // high-resolution oolite-icon.icns.\n"
        "    const std::string imagesDir = oo::str::appendingPathComponent(oo::StdString([[NSBundle mainBundle] resourcePath]), \"Images\");\n"
        "    SDL_Surface* icon = SDL_LoadBMP(oo::str::appendingPathComponent(imagesDir, \"WMicon.bmp\").c_str());\n",
        # upstream's SDL3 clipboard for every platform (#747) with the history's std::string
        "    {\n"
        "        const char* clipboardText = stringToCopy.c_str();\n"
        "        if (!SDL_SetClipboardText(clipboardText)) {\n"
        "            OOLog(@\"stringToClipboard.failed\", @\"Failed to copy string %@ to clipboard: %s\", oo::NSStringFrom(stringToCopy), SDL_GetError());\n",
        "ours",  # Linux stubs: upstream made these methods common to all SDL platforms (#747)
        "#endif\n"
        "    OOLog(@\"screenshot\", @\"Saving screen shot \\\"%@\\\" (%u x %u pixels).\", oo::NSStringFrom(*pathToPic), surface->w, surface->h);\n",
        "theirs",  # upstream side differs from base only in formatting
        "theirs",
    ],
}
DELETE = []

# Joystick decoding: upstream (#742) moved decode*Event into OOSDLJoystickManager to silence an
# Objective-C GCC warning; the migration keeps them in OOJoystickManager (as develop does). From
# this step the SDL manager is the history's, so its files are the history's whole.
WHOLE = {"src/SDL/OOSDLJoystickManager.h": "theirs", "src/SDL/OOSDLJoystickManager.mm": "theirs"}
