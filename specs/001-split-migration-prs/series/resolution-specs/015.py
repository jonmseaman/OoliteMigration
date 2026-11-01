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
RES["src/Core/Entities/ShipEntity.mm"] = ["theirs", "theirs", "theirs"]  # its includes cover std::vector
# the history deletes the vector bridge include here; its closing include-guard #endif goes too, since
# upstream's #748 header uses #pragma once
RES["src/Core/OOVector.h"] = [""]
