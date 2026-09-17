# Golden harness runner

One golden scenario, one **native** game process, its own console port, its own artifact directory.
No containers ([ADR-0017](../../docs/decisions/0017-native-windows-subtree.md)); the console client
is the component tier's, shared as [ADR-0018](../../docs/decisions/0018-component-test-tier.md)
requires (`upstream/oolite/tests/component/console.py`).

```bash
tests/golden/run.sh 001                       # one scenario
tests/golden/run.sh 001 --dry-run             # print the run plan, launch nothing
tests/golden/run.sh 001 --check-isolation --plan-count 4   # prove 4 concurrent runs cannot collide
tests/golden/run.sh --help
```

It needs a built game: `upstream/oolite/build/meson_test/oolite.app` by default, `--app-dir` or
`$OO_APP_DIR` otherwise. Mesa's `opengl32.dll` and `libgallium_wgl.dll` are copied beside the
binary **unconditionally** on every run, as `upstream/oolite/tests/run_test_fn.sh:28-33` does — a
stale DLL from an older MSYS2 would otherwise render the goldens on a different rasteriser.
Artifacts land in `tests/golden/artifacts/<scenario>/<run-id>/`
(`Latest.log`, the snapshot PNG, `run.json` with the port, the game clock reading, `guiScreen` and
the wall time). The directory is git-ignored.

## Running N at once

`N` is the RAM budget row in [`docs/infra/0-machines.md`](../../docs/infra/0-machines.md) and is
carried as `GOLDEN_MAX_CONCURRENCY` at the top of `run.sh` (override with
`OO_GOLDEN_MAX_CONCURRENCY`). Just start N invocations; nothing is shared:

| Per run | How | Why it has to be |
|---|---|---|
| console port | reserved from 8600+ under an exclusive lock file **and** a test bind, held for the life of the run | The game *dials out* and reads `console-port` from `debugConfig.plist` (`OODebugSupport.m:67-80`, default 8563), so the port is made real by writing a plist the game merges — see below. Locking before binding closes the window between choosing a port and binding it. |
| artifact dir | `<timestamp>-p<port>-<pid>-<rand>` | `OO_SNAPSHOTSDIR`/`OO_LOGSDIR` point at it, so two runs would otherwise overwrite one `Latest.log`. |
| GNUstep prefs root | a private staged `oolite.app` | `src/SDL/main.m:119` sets `GNUSTEP_USERS_ROOT` to the directory the *executable* lives in. N processes in one `oolite.app` race on one `GNUstep/Defaults/oolite.plist`. Staging is junctions for read-only directories and hard links for files — 317 MB costs no bytes — with `GNUstep/`, `Logs/` and `oolite-saves/` real copies. |

The port is set by dropping a throwaway resource root containing `Config/debugConfig.plist` and
naming it in `OO_ADDITIONALADDONSDIRS`, which `ResourceManager` treats as a search root
(`OOOXZManager.m:286`). The stock Debug OXP leaves `console-host`/`console-port` commented out, so
this always wins the merge. Same mechanism as `upstream/oolite/tests/launch_snapshot.py`.

## Three rules the harness must keep

* **Never wait on the script's wall clock.** `console.py` pings until `Pong` proves the run loop is
  servicing packets; `golden_run.py` then polls `clock.absoluteSeconds` (UNIVERSE time, which
  advances only while the run loop steps) until the scenario's `settle_seconds` of *game* time have
  passed. A fixed sleep is how `launch_snapshot.py` once produced a ~5 KB black PNG.
* **Never hand an MSYS path to a native binary.** Any leading-slash path (`/c/...`, `/tmp/...`) is
  resolved by a native process against the current drive and lands where the caller never named.
  `run.sh` converts every path option with `cygpath -m`; `golden_run.py` re-checks with
  `is_msys_path`, which tests the **leading slash**, not a list of drive letters. It matters most
  for `config_dir`, handed to the *game* as `OO_ADDITIONALADDONSDIRS`: a misplaced one means the
  game never reads its `debugConfig.plist`, falls back to port 8563, and N runs collide there.
* **Never probe a sibling's liveness with `os.kill`.** On stock CPython for Windows
  `os.kill(pid, 0)` is `TerminateProcess`, so the stale-lock check would kill the concurrent game
  process whose lock it inspects. `_pid_is_alive` uses `OpenProcess`/`GetExitCodeProcess`.

## Scenarios

`tests/golden/scenarios/<name>/scenario.json`, all keys optional:

| Key | Default | Meaning |
|---|---|---|
| `seed` | `1` | `OO_RANDOM_SEED` for the run (`GameController.m:100`). |
| `settle_seconds` | `2.0` | Seconds of the **game's** clock to wait for before acting. |
| `snapshot` | `true` | Capture a PNG via `takeSnapShot()`. |
| `load_save` | `null` | `.oolite-save` handed to the game's `-load`, to start docked. |
| `js` | `[]` | JS performed once the game is rendering. |

Scenario `001` is the launch/main-menu baseline. Adding a scenario is a new directory and a JSON
file — data, not a new interface.

## Evidence

Four concurrent runs on the fleet Windows machine (16C/24T, 64 GiB): ports 8600-8603, four distinct
artifact directories, all four `ok`, `guiScreen=GUI_SCREEN_INTRO1`, snapshots 300-343 KB (a black
frame is ~5 KB), 21.7-38.3 s wall each.
