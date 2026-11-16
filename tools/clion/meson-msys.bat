@echo off
rem CLion's Meson executable (Settings > Meson > Meson executable).
rem Runs meson as a child of MSYS bash, so get_version.sh sees meson in ps.
"C:\Users\jon\scoop\apps\msys2\current\usr\bin\bash.exe" -c "meson \"$@\"" meson %*
