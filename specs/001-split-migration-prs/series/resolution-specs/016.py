# Step 16 resolutions (the root Entity facade).
RES = {
    "src/Core/Debug/OODebugSupport.mm": [
        "theirs",
        lambda ours, theirs: theirs.replace("#endif /* NDEBUG */", "#endif /* OO_DEBUG_MONITOR_ENABLED */"),
    ],
    # the history's C++ manager; upstream's copy-URL key needs its C++ port (deferred.md, from step 12)
    "src/Core/OOOXZManager.mm": ["theirs"],
    "src/SDL/MyOpenGLView.mm": [
        "ours",  # upstream #744 removed the undocumented dark-mode API: it stays removed
        "ours",  # Linux stubs: upstream made these methods common (#747)
    ],
}
DELETE = []
