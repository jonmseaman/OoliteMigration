# CLion on Windows

How to open `oolite-dev` in CLion (2026.2) on Windows with working Meson sync, highlighting,
building and debugging. It uses the same MSYS2 UCRT64 Clang toolchain as `./mk.sh build dev`.
Set up MSYS2 first with [tools/setup-windows.sh](../tools/setup-windows.sh).

The two helper files are in [tools/clion/](../tools/clion/). Copy them somewhere outside the repo
(for example `C:\Users\jon\`) and change `MSYS_ROOT` / the bash path if MSYS2 is not at
`C:\Users\jon\scoop\apps\msys2\current`.

| File | Used as | Why |
|---|---|---|
| `clion-ucrt64-env.bat` | the toolchain's environment file | puts `ucrt64\bin` (clang, meson, pkg-config) and `usr\bin` (bash, cat, cygpath) on PATH; sets `MSYSTEM` and `MINGW_PREFIX` |
| `meson-msys.bat` | the Meson executable | starts meson from MSYS bash; see [Why the wrapper](#why-the-wrapper) |

## Steps

1. **Open** the `oolite-dev` folder in CLion and choose the Meson project when asked.
2. **Settings → Build, Execution, Deployment → Toolchains**: add a **MinGW** toolchain, named for
   example `MinGW UCRT64`.
   - Toolset: `C:\Users\jon\scoop\apps\msys2\current\ucrt64`
   - C compiler: `...\ucrt64\bin\clang.exe`; C++ compiler: `...\ucrt64\bin\clang++.exe`
   - Debugger: **Bundled GDB**. The UCRT64 GDB is newer than CLion supports.
   - **Add environment → From file**: `clion-ucrt64-env.bat`
   - Ignore "Test CMake run finished with errors": that checks CMake, which Oolite does not use.
3. **Settings → Build, Execution, Deployment → Meson**:
   - Toolchain: pick `MinGW UCRT64` by name, not "Use default". A profile with no toolchain name
     made this settings page fail to open.
   - Meson executable: `meson-msys.bat`
   - Setup options: `-Ddev_release=true -Ddebug=true -Dstrip_bin=false --native-file=clang.ini`
     (the `dev` options from `mk.sh`, with debug info on). Leave `-Dpdb` off: it switches the
     debug info to PDB, which GDB cannot read.
   - Build directory: `build/meson_clion`. Keep it separate from `mk.sh`'s `build/meson_dev`, or
     the two keep reconfiguring each other's directory.
   - Build options: `-j <cores>`.
4. **Reload Meson Project** (the ⟳ in the Build → Sync pane). It is done when the Sync pane is
   green and the `oolite` and `post_build` targets are listed.
5. **Run/debug configuration**: executable `build/meson_clion/oolite.app/oolite.exe`, working
   directory `build/meson_clion/oolite.app`, with the build target before launch. The game needs
   the files `post_build` stages next to it, so don't run `build/meson_clion/src/oolite.exe`.

## When sync fails

CLion's Sync pane only says "Meson failed with error code 1". Read the last lines of
`build/meson_clion/meson-logs/meson-log.txt` (CLion's own log is
`%LOCALAPPDATA%\JetBrains\CLion2026.2\log\idea.log`; search it for `MesonProjectResolver`).

| Message in the editor or log | Cause |
|---|---|
| "This file does not belong to any project target" | sync failed; the targets are unknown until it succeeds |
| `Program or command 'bash' not found` | the environment file is not attached to the toolchain |
| `Parent process is , Bash parent is .` from `get_version.sh` | the Meson executable is the plain `meson.exe`, or `MINGW_PREFIX` is unset |
| `meson setup buildDir` with no options in `idea.log` | the Meson profile has no setup options; delete the stray `buildDir` folder afterwards |

## Why the wrapper

`ShellScripts/common/get_version.sh` refuses to run unless meson called it. On Windows it checks
that by asking PowerShell for its parent process (`python.exe`) and then looking for `meson` in
MSYS's `ps`. MSYS's `ps` only lists processes started from MSYS, so a `meson.exe` that CLion
starts directly fails the check. `meson-msys.bat` starts meson from MSYS bash, which puts it in
`ps`; Meson's own regeneration during a build runs under the same wrapper, so it passes too.
