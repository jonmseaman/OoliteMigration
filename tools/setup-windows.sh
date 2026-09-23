#!/usr/bin/env bash
#
# One-time provisioning of the Windows fleet machine.
# Phase 0 item 0.2 (docs/phases/0-safety-net.md) - I1 item 1 (docs/infra/1-base-images.md).
#
# Upstream's CI reprovisions MSYS2 on every run (msys2/setup-msys2 + install_deps.sh).
# Here the machine is provisioned once and every later build is incremental behind ccache.
# Run from an MSYS2 UCRT64 shell:
#
#     tools/setup-windows.sh            # provision; safe to re-run, installs nothing when current
#     tools/setup-windows.sh --check    # verify only; installs nothing, exits 1 if anything is missing
#
# A pin move (editing the package sets below) is the only reason to re-run.
# Resolved versions land in tools/windows-packages.lock so drift is visible in a diff.

set -euo pipefail

# --- Pins: the package set this machine is provisioned to -----------------------------------
#
# MSYS2 repositories roll forward, so the pin is the *set*, not a version; the lock file records
# what the set resolved to. Names mirror upstream's ShellScripts/Windows/install_deps.sh so the
# build matches CI, plus the additions this project needs (mesa, ccache, jq, python-pytest).

MSYS_PKGS=(dos2unix git pactoys unzip)

# mingw-w64-ucrt-x86_64-* packages. mesa supplies the llvmpipe opengl32.dll the goldens copy
# beside the binary (upstream/oolite/tests/run_test_fn.sh); ccache backs the shared compiler
# cache; jq is required by the fleet scripts (.agents/skills/beads-worker/scripts/_lib.sh);
# clang-tools-extra supplies clang-tidy, which tools/tier-a.sh requires (Phase 0 item 0.9) -
# the clang package alone does not ship it, so Tier A dies on a machine provisioned without it.
UCRT_PKGS=(
  binutils clang clang-tools-extra lld
  espeak-ng libpng libvorbis openal pcaudiolib sdl3
  meson ninja nsis jq
  mesa ccache
  # llvm-tools ships llvm-symbolizer, which Tier C's ASan stage REQUIRES (bead oo-j4u): without
  # it every sanitizer frame is a bare address, and a report cannot be attributed to oolite.exe
  # rather than to a prebuilt third-party DLL. clang alone does not provide it.
  llvm-tools
  python python-pip python-setuptools python-wheel python-pytest python-pillow
)

# Installed by upstream's install_deps.sh from the oolite_windeps_build releases, not from a
# repository: the GNUstep/libobjc2 stack built against clang. Phase 2 deletes these; until then
# the build needs them. (SpiderMonkey left with Phase 1, bead oo-7wx.)
WINDEPS_PKGS=(libobjc2 gnustep-make gnustep-base)

# Pure-Python, no MSYS2 package exists. pytest-bdd drives the component tier (ADR-0018);
# pyautogui drives the GUI tier against a real window (docs/phases/0-gui-tier.md). The GUI
# tier's own pin is upstream/oolite/tests/gui/requirements.txt, installed by tools/gui-tier.sh
# on every run; this list keeps a set-up-once machine from paying for that install each time.
# Keep the two in step: a name added there belongs here.
PIP_PKGS=(pytest-bdd pyautogui)

# Shared compiler cache, outside every worktree so it survives worktree removal (I1 item 2).
CCACHE_DIR_DEFAULT="C:/ccache"
CCACHE_MAX_SIZE="20G"

# --- Plumbing ------------------------------------------------------------------------------

CHECK_ONLY=false
case "${1:-}" in
  --check) CHECK_ONLY=true ;;
  "") ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="$REPO_ROOT/tools/windows-packages.lock"
MISSING=()

say()  { echo "==> $*"; }
skip() { echo "    ok: $*"; }
die()  { echo "setup-windows: $*" >&2; exit 1; }

# --check must never install. Anything that would install is recorded and reported at the end.
want() {
  MISSING+=("$1")
  if $CHECK_ONLY; then
    echo "    MISSING: $1"
    return 1
  fi
  return 0
}

have_pkg() { pacman -Qq "$1" >/dev/null 2>&1; }
have_py()  { python -c "import $1" >/dev/null 2>&1; }

# --- Preflight -----------------------------------------------------------------------------
#
# This must run in an MSYS2 UCRT64 shell, but it is also called as a bead's acceptance command,
# and accept.sh runs those with a plain `bash -c` in whatever shell the fleet was started from -
# Git Bash, say, where MSYSTEM is unset. Re-exec into the UCRT64 shell rather than fail, so the
# acceptance does not depend on how the orchestrator happened to be launched. CHERE_INVOKING
# keeps the working directory; OOLITE_SETUP_REEXEC stops a loop if the re-exec does not take.

MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OOLITE_SETUP_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  echo "==> MSYSTEM is '${MSYSTEM:-unset}'; re-executing under MSYS2 UCRT64"
  export OOLITE_SETUP_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

[ "${MSYSTEM:-}" = "UCRT64" ] || die "run this from an MSYS2 UCRT64 shell (MSYSTEM is '${MSYSTEM:-unset}'); start C:/msys64/ucrt64.exe"
[ -n "${MINGW_PREFIX:-}" ] || die "MINGW_PREFIX is unset; this is not a working MSYS2 UCRT64 shell"
for c in pacman curl git; do
  command -v "$c" >/dev/null 2>&1 || die "missing command: $c"
done
[ -d "$REPO_ROOT/upstream/oolite" ] || die "upstream/oolite not found under $REPO_ROOT; run from a full checkout"

say "MSYS2 $MSYSTEM, prefix $MINGW_PREFIX"

# --- 1. MSYS2 base packages ----------------------------------------------------------------

needed_msys=()
for p in "${MSYS_PKGS[@]}"; do have_pkg "$p" || needed_msys+=("$p"); done
if [ ${#needed_msys[@]} -eq 0 ]; then
  skip "msys packages (${#MSYS_PKGS[@]})"
elif want "msys: ${needed_msys[*]}"; then
  say "installing msys packages: ${needed_msys[*]}"
  pacman -S --needed --noconfirm "${needed_msys[@]}"
fi

# --- 2. UCRT64 toolchain and libraries -------------------------------------------------------

needed_ucrt=()
for p in "${UCRT_PKGS[@]}"; do have_pkg "mingw-w64-ucrt-x86_64-$p" || needed_ucrt+=("mingw-w64-ucrt-x86_64-$p"); done
if [ ${#needed_ucrt[@]} -eq 0 ]; then
  skip "ucrt64 packages (${#UCRT_PKGS[@]})"
elif want "ucrt64: ${needed_ucrt[*]}"; then
  say "installing ucrt64 packages: ${needed_ucrt[*]}"
  pacman -S --needed --noconfirm "${needed_ucrt[@]}"
fi

# --- 3. Oolite Windows dependencies (libobjc2, GNUstep) ---------------------------------------
#
# Delegated to upstream's install_deps.sh so this stays in step with CI. That script is not
# idempotent - it re-downloads every release asset and re-runs pacman -U - so it is gated on the
# packages actually being absent. Set GITHUB_TOKEN to avoid the anonymous GitHub API rate limit.

needed_windeps=()
for p in "${WINDEPS_PKGS[@]}"; do have_pkg "mingw-w64-ucrt-x86_64-$p" || needed_windeps+=("$p"); done
if [ ${#needed_windeps[@]} -eq 0 ]; then
  skip "oolite windows dependencies (${WINDEPS_PKGS[*]})"
elif want "windeps: ${needed_windeps[*]}"; then
  say "installing oolite windows dependencies via upstream install_deps.sh clang (${needed_windeps[*]})"
  "$REPO_ROOT/upstream/oolite/ShellScripts/Windows/install_deps.sh" clang
  for p in "${WINDEPS_PKGS[@]}"; do
    have_pkg "mingw-w64-ucrt-x86_64-$p" \
      || die "install_deps.sh finished but mingw-w64-ucrt-x86_64-$p is still missing; see https://github.com/OoliteProject/oolite_windeps_build/releases"
  done
fi

# --- 4. Python packages with no MSYS2 package -------------------------------------------------
#
# MSYS2's Python is marked externally-managed, so pip refuses to touch site-packages without
# --break-system-packages. These are pure-Python and this is a dedicated build machine; a venv
# would be invisible to upstream/oolite/tests/run_test_fn.sh, which calls bare `python3`.

pip_module() { echo "${1//-/_}"; }

needed_pip=()
for p in "${PIP_PKGS[@]}"; do have_py "$(pip_module "$p")" || needed_pip+=("$p"); done
if [ ${#needed_pip[@]} -eq 0 ]; then
  skip "pip packages (${PIP_PKGS[*]})"
elif want "pip: ${needed_pip[*]}"; then
  say "installing pip packages: ${needed_pip[*]}"
  python -m pip install --break-system-packages --upgrade "${needed_pip[@]}"
fi

# --- 5. Mesa llvmpipe driver ------------------------------------------------------------------
#
# run_test_fn.sh copies $MINGW_PREFIX/bin/opengl32.dll beside the binary. Nothing to install here
# beyond the mesa package; assert it landed, because a silent absence means the goldens fall back
# to whatever GL the desktop offers and stop being reproducible.

if [ -f "$MINGW_PREFIX/bin/opengl32.dll" ]; then
  skip "mesa llvmpipe driver at $MINGW_PREFIX/bin/opengl32.dll"
elif $CHECK_ONLY; then
  want "mesa opengl32.dll at $MINGW_PREFIX/bin/opengl32.dll" || true
else
  die "mesa is installed but $MINGW_PREFIX/bin/opengl32.dll is absent; the goldens have no software GL"
fi

# --- 6. Windows environment for MSYS2 shells --------------------------------------------------
#
# ccache.exe and the other native tools are Windows binaries and abort without USERPROFILE
# ("ccache: error: The USERPROFILE environment variable must be set to your user profile folder").
# An MSYS2 shell started from Windows Explorer inherits it, but one started by the fleet from
# another shell does not - MSYS2 filters the environment - so every agent build would lose the
# compiler cache, silently and only under automation. cygpath -F reads the shell folder from the
# OS rather than the environment, so it works either way.

PROFILE_D="/etc/profile.d/oolite-windows-env.sh"
if [ -f "$PROFILE_D" ]; then
  skip "MSYS2 windows environment shim at $PROFILE_D"
elif want "windows environment shim at $PROFILE_D"; then
  say "installing $PROFILE_D so native tools see USERPROFILE under automation"
  cat > "$PROFILE_D" <<'EOF'
# Written by tools/setup-windows.sh. MSYS2 filters the inherited Windows environment, so a shell
# started by the fleet loses USERPROFILE and LOCALAPPDATA; ccache.exe refuses to run without them.
# cygpath -F takes the path from the OS shell-folder API, not from the environment.
[ -n "${USERPROFILE:-}" ]  || export USERPROFILE="$(cygpath -w "$(cygpath -F 40)")"
[ -n "${LOCALAPPDATA:-}" ] || export LOCALAPPDATA="$(cygpath -w "$(cygpath -F 28)")"
[ -n "${APPDATA:-}" ]      || export APPDATA="$(cygpath -w "$(cygpath -F 26)")"
EOF
fi

# --- 7. Shared ccache ------------------------------------------------------------------------
#
# ccache is a native Windows binary and reads %LOCALAPPDATA%\ccache\ccache.conf, NOT the MSYS2
# $HOME/.config/ccache/ccache.conf that the Unix build of ccache would use. Writing to the Unix
# path leaves ccache on its defaults with no error at all, so the state is read back from
# `ccache --show-config` rather than from the file this script just wrote.

CCACHE_CONF="$(cygpath -F 28)/ccache/ccache.conf"
CCACHE_DIR_WANTED="${OOLITE_CCACHE_DIR:-$CCACHE_DIR_DEFAULT}"

# `ccache --show-config` prints "(default) key = value" for a setting it did not read from a
# config file, and "(<path>) key = value" for one it did. A value we did not set is a miss.
# NOT `ccache --show-config | grep -qE ...`: this script runs under `set -euo pipefail` (line 16)
# and that idiom inverts under it - grep -q exits on the first match, SIGPIPEs ccache, and
# pipefail reports 141, so a CONFIRMED setting reads as a miss and the script rewrites a config
# that was already correct (or dies at the `|| die` below). Bead oo-mxgy: measured, ccache emits
# ~1.5 KB here so it fits the 64 KB pipe buffer and the site did not fire in 100 runs - but the
# volume is ccache's to change, not ours. Capture first, then match; no `|| true` (it would hide
# a ccache that failed to run at all, which is exactly what this function must notice).
ccache_reports() {
  local cfg
  cfg=$(USERPROFILE="${USERPROFILE:-$(cygpath -w "$(cygpath -F 40)")}" \
        LOCALAPPDATA="${LOCALAPPDATA:-$(cygpath -w "$(cygpath -F 28)")}" \
          ccache --show-config 2>/dev/null) || return 1
  grep -qE "^\(.*ccache\.conf\) +$1 = $2\$" <<< "$cfg"
}

if ccache_reports cache_dir "$(cygpath -w "$CCACHE_DIR_WANTED" | sed 's/\\/\\\\/g')" \
   && ccache_reports max_size '20\.0 GB'; then
  skip "ccache reports cache_dir $CCACHE_DIR_WANTED, max_size $CCACHE_MAX_SIZE"
elif want "ccache config at $CCACHE_CONF"; then
  say "configuring shared ccache at $CCACHE_DIR_WANTED"
  mkdir -p "$(dirname "$CCACHE_CONF")" "$CCACHE_DIR_WANTED"
  cat > "$CCACHE_CONF" <<EOF
# Written by tools/setup-windows.sh. One cache shared by every agent worktree (I1 item 2).
cache_dir = $(cygpath -w "$CCACHE_DIR_WANTED")
max_size = $CCACHE_MAX_SIZE
EOF
  ccache_reports cache_dir "$(cygpath -w "$CCACHE_DIR_WANTED" | sed 's/\\/\\\\/g')" \
    || die "wrote $CCACHE_CONF but ccache --show-config still reports its default cache_dir"
fi

# --- Report ----------------------------------------------------------------------------------

if $CHECK_ONLY; then
  if [ ${#MISSING[@]} -eq 0 ]; then
    echo "setup-windows: provisioned and current; nothing to install"
    exit 0
  fi
  echo "setup-windows: ${#MISSING[@]} item(s) not provisioned; run tools/setup-windows.sh" >&2
  exit 1
fi

say "recording resolved versions in ${LOCK_FILE#"$REPO_ROOT"/}"
{
  echo "# Resolved by tools/setup-windows.sh. Do not edit by hand."
  echo "# The pin is the package set in the script; this records what it resolved to."
  for p in "${MSYS_PKGS[@]}"; do pacman -Q "$p"; done
  for p in "${UCRT_PKGS[@]}" "${WINDEPS_PKGS[@]}"; do pacman -Q "mingw-w64-ucrt-x86_64-$p"; done
  for p in "${PIP_PKGS[@]}"; do python -m pip show "$p" 2>/dev/null | awk '/^Name:/{n=$2} /^Version:/{print n" "$2}'; done
} | sort > "$LOCK_FILE"

if [ ${#MISSING[@]} -eq 0 ]; then
  say "already provisioned; nothing installed"
else
  say "provisioned ${#MISSING[@]} item(s): ${MISSING[*]}"
fi
echo "setup-windows: done. Verify with: tools/setup-windows.sh --check"
