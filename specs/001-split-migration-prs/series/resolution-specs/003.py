# Step 3 hand resolutions (run after 003_custom.py).
RES = {
    # upstream (#747) moved the decode*Event methods into OOSDLJoystickManager; the history keeps
    # them in OOJoystickManager (as develop does in the end), so the base class keeps its copy
    "src/Core/OOJoystickManager.mm": ["theirs"],
}
# upstream (#737) deleted this dead Mac fullscreen category ("remove some crud"); not moved
DELETE = ["src/Core/GameController+FullScreen.mm"]
