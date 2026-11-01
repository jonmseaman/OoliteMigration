# (run from the end of 008.py)
# OODebugTCPConsoleClient.mm: the hunk choices no longer line up after the earlier steps changed, and
# the merge lost the file's opening guard. The history's whole file, with upstream's #756 guard (the
# debug console is compiled with OO_DEBUG_MONITOR_ENABLED, not !NDEBUG); upstream's macOS socket block
# is deferred with macOS.
del RES["src/Core/Debug/OODebugTCPConsoleClient.mm"]


def _tcp_guard(text):
    assert text.count("#ifndef NDEBUG\n") == 1 and text.count("#endif /* NDEBUG */\n") == 1
    return text.replace("#ifndef NDEBUG\n", "#ifdef OO_DEBUG_MONITOR_ENABLED\n").replace(
        "#endif /* NDEBUG */\n", "#endif /* OO_DEBUG_MONITOR_ENABLED */\n")


WHOLE = dict(globals().get("WHOLE", {}))
WHOLE["src/Core/Debug/OODebugTCPConsoleClient.mm"] = _tcp_guard

try:
    POST
except NameError:
    POST = {}
# upstream #740 (remember the last saved game) in this step's types: the history makes the name a
# std::optional<std::string> here; the defaults are read and written through oo::Defaults, as the
# history's own port of #740 does (step 19)
POST["src/Core/Entities/PlayerEntity.mm"] = [
    ("    NSString* savedName = [[NSUserDefaults standardUserDefaults] stringForKey:@\"last_savename\"];\n"
     "    if (savedName != nil) {\n"
     "        [_lastsaveName autorelease];\n"
     "        _lastsaveName = [savedName copy];\n"
     "    }\n",
     "    const oo::PList savedName = oo::Defaults::standard().object(\"last_savename\");\n"
     "    if (const std::string* name = savedName.getIf<std::string>()) {\n"
     "        _lastsaveName = *name;\n"
     "    }\n"),
    ("    [[NSUserDefaults standardUserDefaults] setObject:_lastsaveName forKey:@\"last_savename\"];\n",
     "    oo::Defaults::standard().setObject(\"last_savename\", _lastsaveName.has_value() ? oo::PList(*_lastsaveName) : oo::PList());\n"),
]
# upstream's copy-URL key (#747): the manifests are oo::PList and the clipboard takes a std::string here
POST["src/Core/OOOXZManager.mm"] = [
    ("            [[UNIVERSE gameView] stringToClipboard:_currentOXPURL];\n",
     "            if (_currentOXPURL != nil)\n"
     "                [[UNIVERSE gameView] cxx_stringToClipboard:oo::StdString(_currentOXPURL)];\n"),
    ("            NSDictionary* manifest = [_filteredList oo_dictionaryAtIndex:_item];\n"
     "            // infoURL\n"
     "            NSString* infoURLString = [manifest oo_stringForKey:kOOManifestInformationURL];\n"
     "            // copy url info text to clipboard automatically once we are in the oxz info page\n"
     "            [[UNIVERSE gameView] stringToClipboard:infoURLString];\n",
     "            const oo::PList manifest = ElementAt(_filteredList, _item);\n"
     "            // infoURL\n"
     "            const std::optional<std::string> infoURL = ManifestString(manifest, oo::StdString(kOOManifestInformationURL));\n"
     "            // copy url info text to clipboard automatically once we are in the oxz info page\n"
     "            if (infoURL.has_value())\n"
     "                [[UNIVERSE gameView] cxx_stringToClipboard:*infoURL];\n"),
]
# the history's load/save helpers sit inside OO_USE_CUSTOM_LOAD_SAVE, a macro upstream removed (custom
# load/save is always on); the guard goes as upstream's other uses of it did
CHANGES["src/Core/Entities/PlayerEntityLoadSave.mm"] = [
    ("}\n\n#if OO_USE_CUSTOM_LOAD_SAVE\n\n// %@ of a string that may be nil", "}\n\n// %@ of a string that may be nil"),
    ("    return units.empty() ? 0 : static_cast<unsigned char>(units[0] & 0x00ff);\n}\n\n#endif\n\n} // namespace\n",
     "    return units.empty() ? 0 : static_cast<unsigned char>(units[0] & 0x00ff);\n}\n\n} // namespace\n"),
]


# Warnings in the history's own step-8 code under Clang 23 (the history built with them). Fixed, not
# silenced, mostly in the forms the history reaches in step 9:
#  - setAIScript:'s definition takes the declared const std::string& (callers pass one; the history's
#    step-8 definition took an NSString*, a real mismatch), converting where an NSString is needed
#  - locals that hide instance variables get the history's step-9 names (imageName, backgroundName,
#    orientationValue, positionValue) or a plain new one (tickleScript)
#  - unnamed selector parts written `x:(T)y` get a space (`x :(T)y`): the same selector
#  - this step's own last_savename port names its local savedLastsaveName
_old_tcp_guard = _tcp_guard


def _tcp_guard(text):
    text = _old_tcp_guard(text)
    assert text.count(")readSet:(fd_set*)writeSet") == 2
    return text.replace(")readSet:(fd_set*)writeSet", ")readSet :(fd_set*)writeSet")


WHOLE["src/Core/Debug/OODebugTCPConsoleClient.mm"] = _tcp_guard
POST["src/Core/Entities/PlayerEntity.mm"][0] = (
    POST["src/Core/Entities/PlayerEntity.mm"][0][0],
    POST["src/Core/Entities/PlayerEntity.mm"][0][1].replace("const std::string* name =", "const std::string* savedLastsaveName =")
                                                    .replace("_lastsaveName = *name;", "_lastsaveName = *savedLastsaveName;"))
POST["src/Core/Universe.h"] = [(")commodity_name:(OOCargoQuantity)how_many;", ")commodity_name how_much:(OOCargoQuantity)how_many;")]
CHANGES["src/Core/Entities/ShipEntityAI.mm"] = [
    ("- (void)setAIScript:(NSString*)aiString\n", "- (void)setAIScript:(const std::string&)aiString\n"),
    ("    aiScript = [OOScript jsAIScriptFromFileNamed:aiString properties:properties];\n",
     "    aiScript = [OOScript jsAIScriptFromFileNamed:oo::NSStringFrom(aiString) properties:properties];\n"),
    ("\"Unable to load JS AI {} for ship {} ({} for role {})\", oo::DescriptionOf(aiString),",
     "\"Unable to load JS AI {} for ship {} ({} for role {})\", aiString,"),
]
CHANGES["src/Core/Entities/PlayerEntityLegacyScriptEngine.mm"] = [
    ("    const std::string name = oo::StdString(value);\n    if (!IsNoneValue(name)) {\n"
     "        [self setMissionOverlayDescriptor:oo::ObjectFromPList(oo::PList(oo::PList::Dict { { \"name\", oo::PList(name) } }))];\n",
     "    const std::string imageName = oo::StdString(value);\n    if (!IsNoneValue(imageName)) {\n"
     "        [self setMissionOverlayDescriptor:oo::ObjectFromPList(oo::PList(oo::PList::Dict { { \"name\", oo::PList(imageName) } }))];\n"),
    ("    const std::string name = oo::StdString(value);\n    if (!IsNoneValue(name)) {\n"
     "        [self setMissionBackgroundDescriptor:oo::ObjectFromPList(oo::PList(oo::PList::Dict { { \"name\", oo::PList(name) } }))];\n",
     "    const std::string backgroundName = oo::StdString(value);\n    if (!IsNoneValue(backgroundName)) {\n"
     "        [self setMissionBackgroundDescriptor:oo::ObjectFromPList(oo::PList(oo::PList::Dict { { \"name\", oo::PList(backgroundName) } }))];\n"),
    ("    const oo::PList* orientation = dict.find(\"orientation\");\n"
     "    if (ScanQuaternionFromString(orientation != nullptr ? oo::ObjectFromPList(*orientation) : nil, &planetOrientation)) {\n",
     "    const oo::PList* orientationValue = dict.find(\"orientation\");\n"
     "    if (ScanQuaternionFromString(orientationValue != nullptr ? oo::ObjectFromPList(*orientationValue) : nil, &planetOrientation)) {\n", 2),
    ("    const oo::PList* position = dict.find(\"position\");\n    if (position == nullptr) {\n",
     "    const oo::PList* positionValue = dict.find(\"position\");\n    if (positionValue == nullptr) {\n", 2),
    ("    const std::string positionString = ConditionString(*position).value_or(std::string());\n",
     "    const std::string positionString = ConditionString(*positionValue).value_or(std::string());\n", 2),
    ("for (const auto& [scriptName, script] : *tickleScripts.getIf<oo::PList::Dict>()) {\n"
     "            [(OOScript*)oo::ObjectIn(script) runWithTarget:self];\n",
     "for (const auto& [scriptName, tickleScript] : *tickleScripts.getIf<oo::PList::Dict>()) {\n"
     "            [(OOScript*)oo::ObjectIn(tickleScript) runWithTarget:self];\n"),
]
