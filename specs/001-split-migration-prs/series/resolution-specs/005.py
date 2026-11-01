# Step 5: the history wraps the tokeniser in an autorelease scope (re-indenting it); step 2's VLA fix
# is re-applied to its form (the history drops the buffer itself in step 7).
RES = {"src/Core/OOStringParsing.mm": ["theirs", "theirs"]}
POST = {"src/Core/OOStringParsing.mm": [
    ("        unichar result[length];\n", "        std::vector<unichar> result(length);\n"),
    ("            token = [NSString stringWithCharacters:result length:ri];\n",
     "            token = [NSString stringWithCharacters:result.data() length:ri];\n"),
]}
# upstream's include block sits lower in this file (its order); the history adds oofnd/Process.hpp
# among the includes it had here, which the series keeps
RES["src/SDL/MyOpenGLView.mm"] = [lambda ours, theirs: ours + '#include "oofnd/Process.hpp"\n']


# The game builds as C++20 from this step; Clang 23 reports arithmetic and comparisons that mix an
# enumeration with a floating-point or another enumeration type (deprecated in C++20). Each fix is the
# history's own later form: an explicit conversion, the same value.
try:
    CHANGES
except NameError:
    CHANGES = {}
CHANGES.update({
    "src/Core/Entities/OOParticleSystem.mm": [("32.0f * kMinSpeed / _particleSize[i]",
                                                "32.0f * static_cast<float>(kMinSpeed) / _particleSize[i]")],
    "src/Core/Entities/ShipEntity.mm": [("0.95 * UNIVERSE_MAX_ENTITIES", "0.95 * static_cast<double>(UNIVERSE_MAX_ENTITIES)"),
                                         ("0.50 * UNIVERSE_MAX_ENTITIES", "0.50 * static_cast<double>(UNIVERSE_MAX_ENTITIES)")],
    "src/Core/OOJoystickManager.mm": [("evt->type == JOYBUTTONDOWN", "evt->type == static_cast<SDL_EventType>(JOYBUTTONDOWN)")],
    "src/Core/OOMesh.mm": [("size < kOctreeSmallSizeThreshold", "size < static_cast<GLfloat>(kOctreeSmallSizeThreshold)")],
})
# The normaliser's include sorting put objc-arc.h before objc/runtime.h, which it needs (BOOL, size_t);
# the history's order is restored, runtime.h in a block of its own so that sorting keeps it first.
CHANGES["src/SDL/main.mm"] = [("#import <objc/objc-arc.h>\n#import <objc/runtime.h>\n",
                               "#import <objc/runtime.h>\n\n#import <objc/objc-arc.h>\n")]
