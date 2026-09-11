# Setting up the Windows workstation

**Status:** written 2026-09-11 from the Azure VM bring-up · **Relates to:** [I0](0-machines.md)
(the machine and its checklist), [I1](1-base-images.md) (provisioning), [I5](5-hermes-goal.md)
(the Hermes runbook)

This is the runbook for bringing up Jon's own Windows machine as the fleet host, written while
doing it to an Azure VM so the traps are recorded rather than rediscovered. It complements the
[I0 checklist](0-machines.md); that page says *what* must be true, this one says *how*.

Everything here assumes native Windows, no WSL2 ([ADR-0017](../decisions/0017-native-windows-subtree.md)).

## What you are building

| Piece | Why |
|---|---|
| MSYS2 UCRT64 | the build. Upstream's Windows build is `ShellScripts/Windows/install_deps.sh` + `mk.sh`; clang, Mesa llvmpipe and ccache come from pacman. The beads-worker scripts are bash. |
| git | the repo, plus `git worktree` which `accept.sh` uses |
| Node | only to install the Claude Code CLI |
| bd + dolt | the queue. `bd` runs a `dolt sql-server`; the dolt binary is **not** bundled. |
| Claude Code | frontier tier: seams, `run-story`, `reevaluate.sh` |
| Hermes Agent | local tier: the `/goal` loop over `fleet` beads |

## Versions used on the VM (2026-09-11)

Pin these unless there is a reason to move. Recorded because [I1](1-base-images.md) wants pins in
the provisioning script, and because `winget` could not be used (below).

| Tool | Version | Source |
|---|---|---|
| Git for Windows | 2.55.0.5 | `github.com/git-for-windows/git` releases |
| Node.js LTS | 24.21.0 | `nodejs.org/dist` |
| MSYS2 | 2026-06-11 | `github.com/msys2/msys2-installer` (use a **dated** tag, not `nightly-x86_64/…-latest.exe`) |
| GitHub CLI | 2.100.0 | `github.com/cli/cli` releases |
| beads (`bd`) | 1.2.2 | `github.com/gastownhall/beads` releases |
| dolt | 2.3.3 | `github.com/dolthub/dolt` releases — **must match the other machine** |
| Claude Code | 2.1.268 | `npm i -g @anthropic-ai/claude-code` |
| Hermes Agent | 0.21.1 | `iex (irm https://hermes-agent.nousresearch.com/install.ps1)` |

On a machine you are sitting at, `winget install` is fine for the first five. The scripts in
[`tools/azure/`](../../tools/azure/) use pinned direct downloads instead, because `winget` cannot
search from a non-interactive SSH session (`0x8a15000f`, "Failed when searching source"). They are
still the fastest way to reproduce the exact set: `setup-vm.ps1` then `setup-vm-tools.ps1`.

## Steps

1. **Clone to a short path on NVMe.** `C:\src\OoliteMigration`. Long paths and deep worktrees are
   a real problem on Windows.

2. **git config** (I0 checklist):
   ```
   git config --system core.autocrlf false
   git config --system core.longpaths true
   ```
   The repo's `.gitattributes` keeps scripts LF. Set `user.name` / `user.email` globally.

3. **MSYS2**, then from a UCRT64 shell:
   ```
   pacman -Syuu --noconfirm --needed          # twice; the first pass may want a restart
   pacman -S --noconfirm --needed git base-devel ccache jq
   ```
   Then the build deps proper — `ShellScripts/Windows/install_deps.sh clang`,
   `mingw-w64-ucrt-x86_64-mesa` (the llvmpipe `opengl32.dll`), python with `pytest` and
   `pyautogui`. That is Phase 0 item 0.2 / bead `oo-f4i`; do it as the story, not by hand.

4. **Claude Code**: `npm i -g @anthropic-ai/claude-code`, then `claude` and `/login`.
   **This needs a browser and an interactive terminal** — it cannot be driven headlessly.
   Log in as the account the fleet runs as, so `run-story` and `reevaluate.sh` inherit it.

5. **Hermes**: run the installer, then apply the [I5](5-hermes-goal.md) table. On the VM:
   ```
   hermes config set goals.max_turns 1000000
   hermes config set delegation.max_concurrent_children 1     # 5 on a machine with the RAM
   hermes config set delegation.child_timeout_seconds 3600
   hermes config set delegation.subagent_auto_approve true
   hermes config set delegation.worktree_isolation false      # reported unrecognised; false is the default
   hermes skills trust C:\src\OoliteMigration
   ```
   Then **point Hermes at MSYS2's bash**, or every command it runs lands in a shell with no
   toolchain (see traps):
   ```
   setx HERMES_GIT_BASH_PATH C:\msys64\usr\bin\bash.exe
   ```

6. **The `bd` guard shim must precede the real `bd` on PATH.** This is the enforcement of
   CLAUDE.md rule 4 and [ADR-0015](../decisions/0015-hermes-goal-loop.md): *the cheapest way to
   satisfy "all beads closed" is to close them, and a goal-seeking loop will find that path if it
   exists.* Put this in `/etc/profile.d/oolite-fleet.sh` (see traps for why not `.bashrc`):
   ```sh
   export PATH="/c/tools/bd:/c/tools/dolt:/c/Program Files/nodejs:$PATH"
   export PATH="/c/src/OoliteMigration/.agents/skills/beads-worker/scripts/bin:$PATH"
   ```
   Verify, and do not skip this:
   ```
   command -v bd            # want .../beads-worker/scripts/bin/bd
   bd close <some-bead>     # want: "bd guard: refusing", exit 77
   ```

7. **Beads**: `bd dolt push` on the machine that has the truth, then on the new machine
   `bd bootstrap` (a fresh clone has no Dolt data — it is runtime state, not in git).
   Read "Two machines, one queue" below before doing this.

## Traps that cost real time

- **Hermes picks Git Bash, not MSYS2.** Its installer detects a system Git and sets
  `HERMES_GIT_BASH_PATH` to `C:\Program Files\Git\bin\bash.exe`. Git Bash cannot see `ccache`,
  `clang` or anything else from pacman, so builds fail or silently use the wrong toolchain.
- **MSYS2 has two home directories.** `bash -lc` with an inherited `HOME` uses the Windows profile
  (`/c/Users/<you>`); the UCRT64 shortcut lets MSYS2 compute it and you get `/home/<you>`. A
  `.bashrc` in one is invisible from the other. Use `/etc/profile.d/*.sh`, which every login shell
  sources either way. Also: a login shell reads `.bash_profile`, not `.bashrc`, and the Windows
  profile has no `.bash_profile` because MSYS2 never populated it from `/etc/skel`.
- **MSYS2 strips the Windows PATH** in login shells (`MSYS2_PATH_TYPE` unset = minimal), so
  anything you add to the Windows PATH is dropped. Add it explicitly in `profile.d`.
- **MSYS2's ssh cannot read keys in the Windows profile.** It is a Cygwin build and the mount is
  `noacl`, so `chmod` is a no-op and the key is skipped: `no identity pubkey loaded`, then
  `Permission denied (publickey)`. Windows OpenSSH reads the same key fine. If MSYS2 git needs the
  remote, point it at the Windows ssh:
  ```
  git config --global core.sshCommand "/c/Windows/System32/OpenSSH/ssh.exe"
  ```
  `accept.sh` uses `git worktree add` against the **local** repo and never touches the remote, so
  the fleet does not need this.
- **The Dolt server dies with its session.** `bd` auto-starts a `dolt sql-server`; start it in one
  shell and it is gone in the next. Pin the port (`bd dolt set port 3307`) or each auto-start picks
  a new one and strands the previous. Run the fleet from a session that stays open.
- **A private repo over HTTPS breaks `bd bootstrap`.** Dolt shells out to git and cannot prompt, so
  it fails with "could not read Username". Either use an SSH `sync.remote` or rewrite globally:
  ```
  git config --global url."git@github.com:".insteadOf "https://github.com/"
  ```
- **PowerShell functions returning extra values.** `Write-Output` inside a PowerShell function is
  added to its return value, so a helper that logs and returns a path returns an *array*, and every
  `-FilePath` binding then fails with "Cannot convert System.Object[]". Use `Write-Host` for logging.

## Two machines, one queue

The beads database is a local Dolt DB per machine; `bd dolt push` / `pull` sync it through
`refs/dolt/data` on the git remote. It merges like git, which means it also **diverges** like git.

- Keep **one writer at a time**. The machine running the fleet is the natural owner, because
  `accept.sh` closes beads there.
- `bd dolt pull` before you start, `bd dolt push` when you stop. Same discipline as git.
- Edits to *different* issues merge cleanly. Edits to the *same* issue conflict.
- `.beads/issues.jsonl` is a **generated export** that is tracked in git, so two machines both
  committing it produces git conflicts on a file neither of you wrote by hand. Let one machine own
  it; regenerate rather than hand-merge.

## Verification

- [ ] `command -v bd` is the guard shim; `bd close <bead>` exits 77
- [ ] `command -v ccache` resolves and `echo $MSYSTEM` is `UCRT64`
- [ ] `claude --version` works and `/login` has been done
- [ ] `hermes --version` works; `HERMES_GIT_BASH_PATH` is MSYS2's bash
- [ ] `bd ready` lists issues
- [ ] `cd upstream/oolite && ./mk.sh build test` is green
- [ ] `python3 tests/launch_snapshot.py` runs
