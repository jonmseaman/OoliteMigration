#!/bin/bash
set -e
export PATH="/ucrt64/bin:$PATH"
export MINGW_PREFIX=/ucrt64
export OO_APP_DIR="C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"
cd /c/Users/jon/OoliteMigration/.worktrees/oo-fjku
python3.exe -m pytest upstream/oolite/tests/component/ -k s6_ -x -q
