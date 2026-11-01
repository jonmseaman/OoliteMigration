# Step 10: the history adds its own extern "C++" block for the GL debug-string declarations; step 3's
# earlier wrapper (the same fix, brought forward) gives way to it.
RES = {}
CHANGES = {"src/Core/OOOpenGL.h": [
    ("#ifdef __cplusplus\nextern \"C++\" { // (this header is sometimes reached from inside OOMaths.h's extern \"C\" block)\n#endif\n#ifdef __cplusplus\n",
     "#ifdef __cplusplus\n"),
    ("}\n#endif\n#ifdef __cplusplus\n}\n#endif\n", "}\n#endif\n"),
]}
