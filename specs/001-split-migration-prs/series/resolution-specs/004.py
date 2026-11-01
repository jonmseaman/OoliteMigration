# Step 4: the history rewrites the manifest object's lines that step 2's warning fix removed; take its form.
RES = {"src/Core/Scripting/OOJSManifest.mm": ["theirs", "theirs"],
       # the history retypes step 3's argument buffer; its VLA fix is re-applied to the new type
       "src/Core/Scripting/OOJSFunction.mm": ["theirs"]}
POST = {"src/Core/Scripting/OOJSFunction.mm": [
    ("    ooscript::Value argv[argc];\n",
     "    std::vector<ooscript::Value> argvBuffer(argc);\n    ooscript::Value* argv = argvBuffer.data();\n")]}


# Step 4 builds the QuickJS-ng library with the test flavour's LTO and links the game with Clang 23.
# Fixes, each in the form the history reaches later (rule 2: fixed, not silenced):
#  - clang.ini names llvm-ar: LTO objects are LLVM bitcode that GNU ar cannot index (the history's CI
#    fix); the Windows dependency script installs llvm-tools to provide it
#  - OOJSShipGroup.h includes what it uses (the normaliser's include sorting put it first in its .mm)
#  - the profiling #warning that names a SpiderMonkey option becomes a comment, and the JavaScript-time
#    total is compiled only with that option (no QuickJS build sets it)
#  - two globals that QuickJS never reads go: the debugger handler (no hook) and the manifest object
CHANGES = {
    "clang.ini": [("objcpp_ld = 'lld'",
                   "objcpp_ld = 'lld'\n# LTO objects are LLVM bitcode; only an LLVM archiver indexes them, so static libraries (libqjs.a)\n"
                   "# linked with -flto need llvm-ar, not GNU ar.\nar = 'llvm-ar'")],
    "ShellScripts/Windows/install_deps.sh": [
        ("        pacboy -S lld --noconfirm\n",
         "        pacboy -S lld --noconfirm\n        pacboy -S llvm-tools --noconfirm  # llvm-ar, which clang.ini names as the archiver\n")],
    "src/Core/Scripting/OOJSShipGroup.h": [
        ("*/\n\n#ifdef __cplusplus\nextern \"C\" {\n",
         "*/\n\n#pragma once\n\n#include \"OOFoundation.h\"\n#include \"ooscript/JSEngine.hpp\"\n\n#ifdef __cplusplus\nextern \"C\" {\n")],
    "src/Core/Scripting/OOJSEngineTimeManagement.mm": [
        ("#ifndef MOZ_TRACE_JSCALLS\n#warning Profiling is enabled, but MOZ_TRACE_JSCALLS is disabled, so only native functions will be profiled.\n#endif\n",
         "// Profiling is enabled, but MOZ_TRACE_JSCALLS is disabled, so only native functions are profiled.\n"
         "// MOZ_TRACE_JSCALLS was a SpiderMonkey build option; the QuickJS-ng engine has no such hook, so it\n"
         "// is never defined and this is how every profiling build profiles.\n"),
        ("\nstatic double sProfilerTotalJavaScriptTime;\n",
         "\n#ifdef MOZ_TRACE_JSCALLS // read only by the call-tracing paths below\nstatic double sProfilerTotalJavaScriptTime;\n#endif\n"),
        ("\n    sProfilerTotalJavaScriptTime = 0.0;\n",
         "\n#ifdef MOZ_TRACE_JSCALLS\n    sProfilerTotalJavaScriptTime = 0.0;\n#endif\n"),
    ],
    "src/Core/Scripting/ooscript/JSEngine_quickjs.cpp": [
        ("    DebuggerHandler gDebuggerHandler = nullptr;\n", ""),
        ("void setDebuggerHandler(Runtime, DebuggerHandler handler, void*) { gDebuggerHandler = handler; }",
         "// quickjs-ng has no debugger hook, so a stored handler would never be called.\n"
         "void setDebuggerHandler(Runtime, DebuggerHandler, void*) { }"),
    ],
}
POST["src/Core/Scripting/OOJSManifest.mm"] = [
    ("namespace {\nstatic ooscript::Object sManifestObject;\n} // namespace\n", ""),
    ("    sManifestObject = (manifestObj);\n", ""),
]
exec(open(__file__.replace("004.py", "004_late.py"), encoding="utf-8").read())
CHANGES.update(CHANGES_LATE)
