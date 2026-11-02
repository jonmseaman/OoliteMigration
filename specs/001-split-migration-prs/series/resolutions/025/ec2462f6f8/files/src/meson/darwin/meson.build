# macOS specific: the SDL front end, with no Foundation (the C++ tree has none).
add_project_arguments(
    '-DXP_UNIX',
    '-DXP_MACOSX',
    '-DGL_SILENCE_DEPRECATION',
    language: c_family,
)
oolite_link_args += [
    # Embed the Info plist so an unbundled executable still has bundle metadata.
    '-Wl,-sectcreate,__TEXT,__info_plist,' + meson.project_source_root() / 'Resources/Info-gnustep.plist',
]

oolite_dependencies += [
    dependency('appleframeworks', modules: ['OpenGL']),
]

# The JavaScript engine is the vendored QuickJS-ng subproject.
