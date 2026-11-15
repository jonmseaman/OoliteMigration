@echo off
rem CLion toolchain environment file (Toolchains > Add environment > From file).
rem Puts MSYS2 UCRT64's tools and MSYS's bash/cat/cygpath on PATH for Meson.
set "MSYS_ROOT=C:\Users\jon\scoop\apps\msys2\current"
set "PATH=%MSYS_ROOT%\ucrt64\bin;%MSYS_ROOT%\usr\bin;%PATH%"
set "MSYSTEM=UCRT64"
set "MINGW_PREFIX=/ucrt64"
