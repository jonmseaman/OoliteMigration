# Step 4: the history rewrites the manifest object's lines that step 2's warning fix removed; take its form.
RES = {"src/Core/Scripting/OOJSManifest.mm": ["theirs", "theirs"],
       # the history retypes step 3's argument buffer; its VLA fix is re-applied to the new type
       "src/Core/Scripting/OOJSFunction.mm": ["theirs"]}
POST = {"src/Core/Scripting/OOJSFunction.mm": [
    ("    ooscript::Value argv[argc];\n",
     "    std::vector<ooscript::Value> argvBuffer(argc);\n    ooscript::Value* argv = argvBuffer.data();\n")]}
