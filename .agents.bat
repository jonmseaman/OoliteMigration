@echo off
rem cmd.exe shim for /goal quality gates.
rem
rem Hermes runs a goal gate with subprocess.run(cmd, shell=True), which on Windows is cmd.exe.
rem cmd.exe cannot execute a .sh file, so the gate registered as
rem     .agents/skills/beads-worker/scripts/goal-gate.sh 0
rem fails with "'.agents' is not recognized as an internal or external command".
rem
rem cmd.exe splits that token at the first '/', so it looks for ".agents(.bat)" in the current
rem directory and passes "/skills/beads-worker/scripts/goal-gate.sh 0" as the arguments. This file
rem catches that, glues the path back together and hands it to MSYS2 bash. bash inherits the
rem working directory from cmd.exe, which inherits it from Hermes, so no cd is needed.
rem
rem Prefer registering the gate as `bash .agents/...` where you control the command; this shim
rem exists so an already-registered gate keeps working unattended.

setlocal
set "REST=%*"
if not defined REST (
  echo .agents.bat: no script path given 1>&2
  exit /b 2
)

rem %* is "/skills/.../goal-gate.sh 0" -- prepend ".agents" to rebuild the repo-relative path.
set "CMDLINE=.agents%REST%"

set "MSYSBASH=C:\Users\jon\scoop\apps\msys2\current\usr\bin\bash.exe"
if not exist "%MSYSBASH%" set "MSYSBASH=bash"

"%MSYSBASH%" -c "%CMDLINE%"
exit /b %ERRORLEVEL%
