# Linux specific
add_project_arguments('-ggdb3', '-DLINUX', '-DXP_UNIX', language: c_family)
oolite_link_args += ['-ggdb3']

oolite_dependencies += [
    dependency('gl'),
    dependency('glu'),
    dependency('x11'),
]

fs = import('fs')
project_root = meson.project_source_root()
shared_roots = [
    fs.expanduser('~') / '.local',
    '/usr/local',
    '/usr',
    '/app'
]

# =====================================================================
# GNUSTEP BLOCK (Scan & Resolve)
# =====================================================================
gs_search_roots = [project_root / 'build/gnustep'] + shared_roots
found_gs_dir = ''
found_gs_inc = ''

foreach root : gs_search_roots
    if found_gs_dir == ''
        foreach sub_dir : ['lib', 'lib64']
            current_dir = root / sub_dir
            if fs.is_file(current_dir / 'libgnustep-base.so') or fs.is_file(current_dir / 'libgnustep-base.a')
                gnustep_folder = root
                found_gs_dir = current_dir
                found_gs_inc = root / 'include'
                break
            endif
        endforeach
    endif
endforeach

if found_gs_dir != ''
    gs_lib = cc.find_library('gnustep-base', dirs: [found_gs_dir], required: true)
    objc_lib = cc.find_library('objc', dirs: [found_gs_dir], required: true)
else
    error('Required dependency "gnustep-base" was not found in SEARCH_ROOTS.')
endif

# SpiderMonkey only when it is the selected backend (bead oo-1gc.4); QuickJS-ng is a subproject.
gs_inc_dirs = [found_gs_inc]
gs_libs = [gs_lib, objc_lib]
if js_backend == 'spidermonkey'
    # =====================================================================
    # MOZILLA JS BLOCK (Scan & Resolve)
    # =====================================================================
    js_name = is_debug ? 'jsdbg_static' : 'js_static'
    js_search_roots = [project_root / 'build/mozilla_js'] + shared_roots
    found_js_dir = ''
    found_js_inc = ''

    foreach root : js_search_roots
        if found_js_dir == ''
            foreach sub_dir : ['lib', 'lib64']
                current_dir = root / sub_dir
                if fs.is_file(current_dir / 'lib' + js_name + '.a')
                    found_js_dir = current_dir
                    found_js_inc = root / 'include'
                    break
                endif
            endforeach
        endif
    endforeach

    if found_js_dir != ''
        js_lib = cc.find_library(js_name, dirs: [found_js_dir], static: true, required: true)
    else
        error('Required dependency "@0@" was not found in SEARCH_ROOTS.'.format(js_name))
    endif
    gs_inc_dirs += [found_js_inc]
    gs_libs += [js_lib]
endif

inc_dir = include_directories(gs_inc_dirs, is_system: true)
oolite_dependencies += declare_dependency(
    dependencies: gs_libs,
    include_directories: inc_dir,
)
