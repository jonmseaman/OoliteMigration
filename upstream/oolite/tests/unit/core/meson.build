# Unit tests of converted game classes (Phase 3; proposed ADR-0056, exemplar bead oo-11m):
# meson test -C build/meson_<type> --suite core, or bash tools/check-core-tests.sh.
#
# One executable per tests/unit/core/test_<Class>.mm. It links the GAME'S OWN objects for the
# class, its Objective-C bridge and whatever else they reference (extracted from the oolite
# target, so compiled exactly as the game compiles them), with the game's include directories and
# dependencies but not its link arguments (-mwindows would hide the test's output). Add a converted
# class as one entry: its test name and the game sources whose objects it needs (['*']: all but main).
# tools/check-core-tests.sh fails when a test_*.mm here is missing from this list.

core_tests = {
    'test_OOColor': ['Core/OOColor.mm', 'Core/OOColor+ObjCBridge.mm', 'Core/OODescription.mm'],
    'test_Octree': ['*'],
    'test_OOMeshToOctreeConverter': ['*'],
    'test_OOSDLJoystickManager': ['SDL/OOSDLJoystickManager.mm', 'SDL/OOSDLJoystickManager+ObjCBridge.mm', 'Core/OOJoystickManager.mm', 'Core/OOJoystickProfile.mm', 'Core/OOCallByName.mm', 'Core/OODescription.mm'],
}

fs = import('fs')

foreach name, game_sources : core_tests
    # The oolite target's own File objects for these sources (extract_objects matches Files, and
    # a files() made here would name a different directory).
    wanted = []
    foreach s : game_sources
        wanted += ['src/' + s]
    endforeach
    # ['*'] is every game object but main's, for a class whose object needs the game graph
    # (Universe, Entity ivars): proposed ADR-0056 amendment oo-44gg.
    whole_game = game_sources == ['*']
    sources = []
    foreach f : oolite_sources
        rel = fs.relative_to(f, meson.project_source_root()).replace('\\', '/')
        if rel in wanted or (whole_game and rel != 'src/SDL/main.mm')
            sources += [f]
        endif
    endforeach
    assert(whole_game or sources.length() == game_sources.length(), name + ': a game source in core_tests is not in the oolite target')
    exe = executable(
        'core_' + name,
        name + '.mm',
        objects: oolite_bin.extract_objects(sources),
        include_directories: [oolite_includes, include_directories('../oofnd')],
        dependencies: oolite_dependencies,
        override_options: oolite_override_options,
        install: false,
    )
    test(name, exe, suite: 'core', timeout: 60)
endforeach
