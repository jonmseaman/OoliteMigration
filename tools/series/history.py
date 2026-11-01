"""Reading the iterative migration history (research R1, R2, R13).

The history lives in OoliteMigration under `upstream/oolite/`; in `oolite-dev` it is reachable as
`refs/series/history`, so commit ids are the same in both repositories.
"""
import re
import subprocess

# The upstream commit under each part of the history (research, "Upstream under the history").
HISTORY_BASE_UPSTREAM = "dc55e3e05"
HISTORY_PULLS = (("4c2bfae9f", "9ee8ff22f"),)
EPIC_PHASE = {"oo-1bf": "P0", "oo-1gc": "P1", "oo-3rb": "P2", "oo-9ht": "P3", "oo-6e1": "P4"}
BEAD_RE = re.compile(r"\boo-[0-9a-z]+(?:\.[0-9]+)*")


def git(repo, *args, check=True):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, encoding="utf-8")
    if check and r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout.strip() if check else r


def phase_of(bead):
    if not bead:
        return "?"
    return EPIC_PHASE.get(bead.split(".")[0], "?")


def first_parent(repo, prefix, start, end):
    """First-parent commits in start..end that change `prefix`, oldest first."""
    out = git(repo, "log", "--reverse", "--first-parent", "--date=short",
              "--format=%H%x09%ad%x09%P%x09%s", f"{start}..{end}", "--", prefix)
    rows = []
    for line in out.splitlines():
        commit, date, parents, subject = line.split("\t", 3)
        m = BEAD_RE.search(subject)
        bead = m.group(0) if m else None
        rows.append({"commit": commit, "date": date, "merge": len(parents.split()) > 1,
                     "subject": subject, "bead": bead, "phase": phase_of(bead)})
    return rows


def snapshot(repo, commit, prefix):
    """Tree id of the game at `commit` (paths mapped from `prefix` to the root)."""
    return git(repo, "rev-parse", f"{commit}:{prefix}")


def upstream_under(repo, commit, base=HISTORY_BASE_UPSTREAM, pulls=HISTORY_PULLS):
    """The upstream commit the history at `commit` sits on."""
    under = base
    for pull, upstream in pulls:
        r = git(repo, "merge-base", "--is-ancestor", pull, commit, check=False)
        if r.returncode == 0:
            under = upstream
    return under
