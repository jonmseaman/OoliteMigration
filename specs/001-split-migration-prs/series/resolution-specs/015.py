# Step 15 resolutions (facade-deletion batches): earlier ports carried into the history's C++ forms.
def last_savename(ours, theirs):
    old = "    setLastsaveName(std::string(PLAYER_DEFAULT_NAME));\n"
    assert old in theirs
    return theirs.replace(old, "    const oo::PList savedName = oo::Defaults::standard().object(\"last_savename\");\n"
                               "    if (const std::string* name = savedName.getIf<std::string>()) {\n"
                               "        setLastsaveName(*name);\n"
                               "    }\n")

def copyurl_check(ours, theirs):
    old = "checkKeyPress(n_key_oxzmanager_showinfo) || checkKeyPress(n_key_oxzmanager_extract)"
    assert old in theirs
    return theirs.replace(old, "checkKeyPress(n_key_oxzmanager_showinfo) || checkKeyPress(n_key_oxzmanager_copyurl) || "
                               "checkKeyPress(n_key_oxzmanager_extract)")

def copyurl_branch(ours, theirs):
    lines = theirs.splitlines(keepends=True)
    i = next(i for i, l in enumerate(lines) if "checkKeyPress(n_key_oxzmanager_extract)) {" in l and "else if" in l)
    indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
    add = [f"{indent}}} else if (checkKeyPress(n_key_oxzmanager_copyurl)) {{\n", f"{indent}    oxzmanager->processCopyUrlKey();\n"]
    return "".join(lines[:i] + add + lines[i:])

def gl_names(ours, theirs):
    for var, prog in (("program", "textureProgram"), ("blur", "blurProgram"), ("final", "finalProgram")):
        old = f"GLhandleARB {var} = {prog}->program();"
        assert old in theirs, old
        theirs = theirs.replace(old, f"GLuint {var} = OOGLProgramName({prog}->program());")
    return theirs

def blur_uniform(ours, theirs):
    old = 'glGetUniformLocation(blurProgram->program(), "imageIn")'
    assert old in theirs
    return theirs.replace(old, 'glGetUniformLocation(blur, "imageIn")')

RES = {
    "src/Core/Entities/PlayerEntity.mm": [last_savename],          # upstream #740
    "src/Core/Entities/PlayerEntityControls.mm": [copyurl_check, copyurl_branch],  # upstream copy-URL key
    "src/Core/Entities/PlayerEntityLoadSave.h": ["theirs"],          # Mac load/save macros: deferred with macOS
    "src/Core/Entities/PlayerEntityLoadSave.mm": ["theirs", "theirs"],
    "src/Core/Entities/ShipEntity.mm": ["theirs", "theirs"],
    "src/Core/Scripting/OOJSSound.h": ["theirs"],
    "src/Core/Universe.mm": [gl_names, blur_uniform],               # upstream #766
}
DELETE = []
# the history deletes the OXZ manager's facade here; step 12's copy-URL forwarder goes with it
DELETE = DELETE + ["src/Core/OOOXZManager+ObjCBridge.h", "src/Core/OOOXZManager+ObjCBridge.mm"]


# step 3's std::vector fix re-applied where the history's PlayerEntity code keeps the arrays
import re as _re15


def vla(ours, theirs):
    out, n = _re15.subn(r"(?m)^(\s*)((?:::)?\w+\*) (\w+)\[(\w+)\];$", r"\1std::vector<\2> \3(\4);", theirs)
    assert n == 1, n
    return out


RES["src/Core/Entities/PlayerEntity.mm"] = [last_savename, vla, vla]
# the setter step 14 wrote through _cxxPlayer is a C++ member from here
POST = dict(globals().get("POST", {}))
POST["src/Core/Entities/PlayerEntity.mm"] = list(POST.get("src/Core/Entities/PlayerEntity.mm", [])) + [(
    "_cxxPlayer->_lastsaveName.has_value() ? oo::PList(*_cxxPlayer->_lastsaveName)",
    "_lastsaveName.has_value() ? oo::PList(*_lastsaveName)")]
# The history's C++ key checks here combine bool results with a bitwise or, which Clang 23 reports
# (-Wbitwise-instead-of-logical). checkKeyPress only reads the key state, so the logical or the
# history writes by step 19 gives the same result.
_KEYS_OLD = ("checkKeyPress(n_key_gui_arrow_right) | checkKeyPress(n_key_gui_arrow_left) | "
             "checkKeyPress(n_key_gui_page_down) | checkKeyPress(n_key_gui_page_up);")
_PAGE_OLD = "pageUpDownKeyPressed = checkKeyPress(n_key_gui_page_down) | checkKeyPress(n_key_gui_page_up);"


def _logical_or(text):
    assert text.count(_KEYS_OLD) == 6 and text.count(_PAGE_OLD) == 1, (text.count(_KEYS_OLD), text.count(_PAGE_OLD))
    return text.replace(_KEYS_OLD, _KEYS_OLD.replace(") | ", ") || ")).replace(_PAGE_OLD, _PAGE_OLD.replace(") | ", ") || "))


POST["src/Core/Entities/PlayerEntityControls.mm"] = list(POST.get("src/Core/Entities/PlayerEntityControls.mm", [])) + [_logical_or]
# the copy-URL port (step 12): the GUI is the C++ class from here, as at the file's other uses
try:
    CHANGES
except NameError:
    CHANGES = {}
CHANGES["src/Core/OOOXZManager.mm"] = [(
    "        } else {\n            OOGUIRow selection = [gui selectedRow];\n",
    "        } else {\n            OOGUIRow selection = (gui != nullptr ? gui->getSelectedRow() : 0);\n")]
RES["src/Core/Entities/ShipEntity.mm"] = ["theirs"]  # its includes cover std::vector
# the history deletes the vector bridge include here; its closing include-guard #endif goes too, since
# upstream's #748 header uses #pragma once
RES["src/Core/OOVector.h"] = [""]


# The containers selector: steps 8-14 name its second part how_much: (see selector_containers.py).
# Here the history's test_OOJSShip arrives, whose stand-in universe overrides the history's
# -cxx_getContainersOfCommodity:: and records the call; the named selector would bypass it. So this
# step takes the history's selector and sends. The declarations keep the whitespace before the
# unnamed part that Clang's -Wmissing-selector-name asks for (its own suggested fix); clang-format
# drops a bare space there, so a comment holds it. Step 16 deletes the bridge.
_UNNAMED_DECL = (r"\)commodity_name ?(?:how_much)?:\(OOCargoQuantity\)",
                 ")commodity_name /* unnamed second part */ :(OOCargoQuantity)")
_UNNAMED_SEND = (r"(cxx_getContainersOfCommodity:[^\]\n]*?) how_much:(num|adjustment|how_many)\]", r"\1:\2]")


def _unnamed(text):
    text, d = _re15.subn(_UNNAMED_DECL[0], _UNNAMED_DECL[1], text)
    text, c = _re15.subn(_UNNAMED_SEND[0], _UNNAMED_SEND[1], text)
    assert d or c, "no containers selector found"
    return text


RES["src/Core/Universe+ObjCBridge.h"] = ["theirs"]
RES["src/Core/Universe+ObjCBridge.mm"] = ["theirs"]
RES["src/Core/Scripting/OOJSShip.mm"] = ["theirs"]
for _p in ("src/Core/Universe+ObjCBridge.h", "src/Core/Universe+ObjCBridge.mm"):
    POST[_p] = list(POST.get(_p, [])) + [_unnamed]
POST["src/Core/Entities/ShipEntity.mm"] = list(POST.get("src/Core/Entities/ShipEntity.mm", [])) + [_unnamed]


# The history makes main's controller C++ here (c820fb8f8d); the game view still keeps the
# controller's Objective-C facade unretained, and peers are weak and autoreleased, so the facade
# died at a pool drain and the view's pointer dangled (smoke: a crash in -mouseInteractionMode from
# Universe::drawMessage, about 3 runs in 5). The history has the same window until it deletes the
# view's and controller's facades (0eabd9899, step 16). Main retains its controller's facade for the
# process, as it held its Objective-C controller before (+sharedController would make a second
# controller: the constructor does not record the shared one).
CHANGES["src/SDL/main.mm"] = [(
    "        controller = oo::makeRef<cxx::GameController>();\n",
    "        controller = oo::makeRef<cxx::GameController>();\n"
    "        // The game view keeps the controller's facade unretained; it lives as long as the process,\n"
    "        // as the Objective-C controller main held did.\n"
    "        [oo::ToObjC(controller.get()) retain];\n")]
