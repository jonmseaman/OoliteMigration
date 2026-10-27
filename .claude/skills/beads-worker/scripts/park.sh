#!/usr/bin/env bash
# Park a bead the loop cannot finish: label it for Jon's inbox (`bd human list`), record why, and
# release the claim so it stops being handed back. The loop then picks up the next bead — it never
# waits for a human (CLAUDE.md hard rule 10).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: park.sh <bead> \"<why>\"}"
why="${2:?usage: park.sh <bead> \"<why>\"}"
real_bd label add "$id" human >/dev/null 2>&1 || real_bd tag "$id" human >/dev/null 2>&1 || true
real_bd update "$id" --append-notes "parked for Jon on $(date -u +%FT%TZ): $why" -q >&2
# --actor matters: bd defaults it to git user.name, but the bead was claimed as worker_actor, and
# bd refuses to unclaim a bead held by somebody else.
real_bd unclaim "$id" --actor "$(worker_actor)" -q >&2 || true
echo "parked $id: $why"
