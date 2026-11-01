# Step 7 resolutions: history's types and accessors + upstream's selector names (#745),
# debug-monitor guards (#756), Mac Cocoa-UI guards and fixes (#766), SDL3 clipboard (#747), Dock icon (#781).
RES = {
    "src/Core/AI.mm": [
        "theirs",  # upstream side differs from base only in formatting
        "#ifdef OO_DEBUG_MONITOR_ENABLED\n"
        "    if (currentState.has_value() && message != \"UPDATE\" && [owner reportAIMessages]) {\n"
        "        OOLog(@\"ai.message.receive\", @\"AI %@ for %@ in state '%@' receives message '%@'. Context: %@, stack depth: %u\", oo::NSStringFrom(stateMachineName), oo::NSStringOrNil(ownerDesc), oo::NSStringOrNil(currentState), oo::NSStringFrom(message), oo::NSStringOrNil(debugContext), recursionLimiter);\n",
    ],
    "src/Core/Entities/PlayerEntity.mm": [
        # history's empty() check + upstream's new OXZ-manager copy-URL key
        lambda ours, theirs: theirs.replace(
            "n_key_oxzmanager_showinfo && n_key_oxzmanager_extract &&",
            "n_key_oxzmanager_showinfo && n_key_oxzmanager_copyurl && n_key_oxzmanager_extract &&"),
    ],
    "src/Core/Entities/ShipEntity.mm": [
        "        [(DockEntity*)subentity setDimensionsAndCorridor:allow_docking ddc:ddc launching:allow_launching];\n"
        "        [subentity setDisplayName:oo::PListView(subentDict).get<NSString*>(@\"dock_label\", @\"the docking bay\")];\n",
        "                newCargo = [UNIVERSE getContainersOfCommodity:oo::PListView(shipinfoDictionary).get<NSString*>(@\"cargo_carried\") how_much:num];\n",
    ],
    "src/Core/Entities/SkyEntity.h": [
        "- (id)initWithColors:(OOColor*)col1 col2:(OOColor*)col2 andSystemInfo:(const oo::PList&)systemInfo;\n"
        "- (BOOL)changeProperty:(const std::string&)key withDictionary:(const oo::PList&)dict;\n",
    ],
    "src/Core/Entities/SkyEntity.mm": [
        "- (id)initWithColors:(OOColor*)col1 col2:(OOColor*)col2 andSystemInfo:(const oo::PList&)systemInfo\n",
        "#ifdef OO_DEBUG_MONITOR_ENABLED\n"
        "- (id)descriptionForObjDump // shared selector (proposed ADR-0043)\n",
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
    "src/Core/ResourceManager.mm": [
        "+ (void)checkOXPMessagesInPath:(const std::string&)path;\n"
        "+ (void)checkPotentialPath:(const std::string&)path searchPaths:(std::vector<std::string>&)searchPaths;\n"
        "+ (BOOL)validateManifest:(const oo::PList&)manifest forOXP:(const std::string&)path;\n"
        "+ (BOOL)areRequirementsFulfilled:(const oo::PList&)requirements forOXP:(const std::optional<std::string>&)path andFile:(const std::string&)file;\n"
        "+ (void)filterSearchPathsForConflicts:(std::vector<std::string>&)searchPaths;\n"
        "+ (BOOL)filterSearchPathsForRequirements:(std::vector<std::string>&)searchPaths;\n"
        "+ (void)filterSearchPathsToExcludeScenarioOnlyPaths:(std::vector<std::string>&)searchPaths;\n"
        "+ (void)filterSearchPathsByScenario:(std::vector<std::string>&)searchPaths;\n"
        "+ (BOOL)manifestAllowedByScenario:(const oo::PList&)manifest;\n"
        "+ (BOOL)manifestAllowedByScenario:(const oo::PList&)manifest withIdentifier:(const std::string&)identifier;\n"
        "+ (BOOL)manifestAllowedByScenario:(const oo::PList&)manifest withTag:(const std::string&)tag;\n",
        "theirs",  # history's cxx_userRootPaths; upstream's Mac bundle resource path (#766) is deferred
        "    sSearchPaths.emplace();\n"
        "    std::vector<std::string>& searchPaths = *sSearchPaths;\n"
        "    for (const std::string& path : existingRootPaths) {\n"
        "        [self checkPotentialPath:path searchPaths:searchPaths];\n",
        "                        if (oo::str::lowercase(oo::str::pathExtension(path)) == \"oxp\") {\n"
        "                            [self checkPotentialPath:path searchPaths:searchPaths];\n"
        "                            if (PathListContains(searchPaths, path))\n",
        "                        if (oo::str::lowercase(oo::str::pathExtension(path)) == \"oxz\") {\n"
        "                            [self checkPotentialPath:path searchPaths:searchPaths];\n"
        "                            if (PathListContains(searchPaths, path))\n",
        "    for (const std::string& path : sExternalPaths) {\n"
        "        [self checkPotentialPath:path searchPaths:searchPaths];\n"
        "        if (PathListContains(searchPaths, path))\n",
        "+ (void)checkPotentialPath:(const std::string&)path searchPaths:(std::vector<std::string>&)searchPaths\n",
    ],
    "src/Core/Scripting/OOJSStation.mm": [
        "    if (!shipyardDefinition.get<oo::PList>(oo::StdString(SHIPYARD_KEY_PERSONALITY))) {\n"
        "        // default to 0 if not supplied\n"
        "        result[oo::StdString(SHIPYARD_KEY_PERSONALITY)] = oo::PList::unsignedInteger(0);\n",
    ],
    "src/Core/Scripting/OOJavaScriptEngine.h": [
        "        See comments for -descriptionComponents in OOFoundation.h. Strings, typed id: the selectors are\n"
        "        shared with the Foundation root class and every class that overrides them.\n",
    ],
    "src/Core/Universe.mm": [
        "    thing = [[SkyEntity alloc] initWithColors:col1 col2:col2 andSystemInfo:oo::PListFrom(systeminfo)]; // alloc retains!\n",
        "    thing = [[SkyEntity alloc] initWithColors:col1 col2:col2 andSystemInfo:oo::PListFrom(systeminfo)]; // alloc retains!\n",
    ],
    "src/SDL/MyOpenGLView.mm": [
        "both",  # upstream's png/SDL3 clipboard includes and history's oofnd includes
        "",      # upstream declares the icon locals inside the Dock-icon guard (#781)
        "#if !OOLITE_MAC_OS_X\n"
        "    // On macOS SDL would set this 32x32 image as the Dock icon, replacing the bundle's\n"
        "    // high-resolution oolite-icon.icns.\n"
        "    const std::string imagesDir = oo::str::appendingPathComponent(oo::StdString([[NSBundle mainBundle] resourcePath]), \"Images\");\n"
        "    SDL_Surface* icon = SDL_LoadBMP(oo::str::appendingPathComponent(imagesDir, \"WMicon.bmp\").c_str());\n",
        "    {\n"
        "        const char* clipboardText = stringToCopy.c_str();\n"
        "        if (!SDL_SetClipboardText(clipboardText)) {\n"
        "            OOLog(@\"stringToClipboard.failed\", @\"Failed to copy string %@ to clipboard: %s\", oo::NSStringFrom(stringToCopy), SDL_GetError());\n",
        "",      # upstream made these common to all SDL platforms (#747); the Linux stubs go
        "#endif\n"
        "    OOLog(@\"screenshot\", @\"Saving screen shot \\\"%@\\\" (%u x %u pixels).\", oo::NSStringFrom(*pathToPic), surface->w, surface->h);\n",
        "theirs",  # upstream side differs from base only in formatting
        "theirs",
    ],
}
DELETE = []
