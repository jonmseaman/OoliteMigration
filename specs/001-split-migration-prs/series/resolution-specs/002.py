# Step 2 fixes. The step compiles these upstream files as Objective-C++ for the first time, and
# Clang 23 warns about C constructs that C++ lacks or that C++ checks harder. Each fix is the form the
# history itself reaches later (std::vector buffers: steps 7 and 9; the cast: step 16; the unused
# JS objects removed: step 4), brought forward so step 2 builds without warnings.


def subs(*pairs):
    def fn(text):
        for old, new in pairs:
            assert text.count(old) == 1, (old, text.count(old))
            text = text.replace(old, new)
        return text
    return fn


FIX = {
    "src/Core/Entities/ShipEntityAI.mm": subs(
        ('#import "ShipEntityAI.h"\n', '#import "ShipEntityAI.h"\n\n#include <vector>\n'),
        ("        WormholeEntity* wormholes[ent_count];\n", "        std::vector<WormholeEntity*> wormholes(ent_count);\n"),
        ("    Entity* my_entities[ent_count];\n", "    std::vector<Entity*> my_entities(ent_count);\n"),
    ),
    "src/Core/OOStringParsing.mm": subs(
        ('#import "OOStringParsing.h"\n', '#import "OOStringParsing.h"\n\n#include <vector>\n'),
        ("    unichar result[length];\n", "    std::vector<unichar> result(length);\n"),
        ("[NSString stringWithCharacters:result length:ri]", "[NSString stringWithCharacters:result.data() length:ri]"),
    ),
    "src/Core/Scripting/OOJSManifest.mm": subs(
        ("namespace {\nstatic JSObject* sManifestObject;\n} // namespace\n", ""),
        ("    sManifestObject = OOJSROBJ(manifestObj);\n", ""),
    ),
    "src/Core/Scripting/OOJSSystem.mm": subs(
        ("namespace {\nstatic JSObject* sSystemPrototype;\n} // namespace\n", ""),
        ("    sSystemPrototype = OOJSROBJ(proto);\n", ""),
        ("    double radius = NSNotFound; // a negative value means",
         "    double radius = static_cast<double>(NSNotFound); // a negative value means"),
        ("    double where = NSNotFound; // a negative value means random positioning!",
         "    double where = static_cast<double>(NSNotFound); // a negative value means random positioning!"),
    ),
}
