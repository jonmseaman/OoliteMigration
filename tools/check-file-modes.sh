#!/usr/bin/env bash
#
# Guardrail: git index file modes match the repo's shebang/exec-bit convention.
#
#     tools/check-file-modes.sh            # enforce; exit 1 on any violation
#     tools/check-file-modes.sh --list     # report every shebang/mode fact, exit 0
#
# THE RULE (CLAUDE.md "Repo conventions"):
#
#   * A file invoked as a BARE PROGRAM (`tools/foo`, `./foo`) MUST be mode 100755 in the
#     git index and MUST start with a `#!` shebang.
#   * A file always invoked through an interpreter (`python3 tools/foo.py`, `bash tools/foo.sh`)
#     MAY be 100644; a shebang on it is documentation, not a promise.
#   * Nothing is 100755 without a shebang.
#
# Why a check and not a habit: MSYS on NTFS reports rwx for every file, so `test -x` is
# always true on the Windows fleet machine and cannot see the defect. `git ls-files -s` is
# what the index actually records and what a Linux checkout or CI will see, so that is what
# this checks. tools/gui-lock shipped 100644 with a `test -x` acceptance that passed on this
# machine and would have failed anywhere else (bead oo-tqmx); this exists so that cannot recur.
#
# "Invoked as a bare program" is decided from the tree, not from a hand-kept list: a call site
# is a tracked line where the path stands in COMMAND POSITION - at the start of a line, after
# a usage-comment marker, or after `;`, `|`, `&&`, `(`, `$(`. A path that only ever appears
# after an interpreter (`python3 tools/x.py`), inside a shell variable (`"$REPO/tools/x.py"`),
# or quoted in prose (`` `tools/x.sh` ``) is not a call site.
#
# upstream/ is a third-party subtree and is excluded: its modes come from upstream.
set -u

cd "$(dirname "$0")/.." || exit 1

LIST_ONLY=0
[ "${1:-}" = "--list" ] && LIST_ONLY=1

fail=0
note() { echo "check-file-modes: $*" >&2; }

# Tracked, non-upstream, non-submodule blobs, as "<mode><TAB><path>".
blobs=$(git ls-files -s | grep -v '^160000' | sed 's/^\([0-7]*\) [0-9a-f]* [0-3]\t/\1\t/' \
        | grep -v $'\t''upstream/')

has_shebang() { [ -f "$1" ] && [ "$(head -c 2 -- "$1" 2>/dev/null)" = '#!' ]; }

# Does any tracked file call PATH in command position?
bare_call_sites() {
	# shellcheck disable=SC2016
	git grep -n -I -E "(^|#)[[:space:]]*(\./)?$1([[:space:]]|$)|[;&|(][[:space:]]*(\./)?$1([[:space:]]|\$)" \
		-- ':!.beads/' ':!upstream/' ':!tools/check-file-modes.sh' 2>/dev/null
}

while IFS=$'\t' read -r mode path; do
	[ -n "${path:-}" ] || continue
	if has_shebang "$path"; then sb=yes; else sb=no; fi

	if [ "$sb" = no ] && [ "$mode" = 100755 ]; then
		if [ "$LIST_ONLY" = 1 ]; then
			echo "100755 no-shebang   $path"
		else
			note "$path is 100755 but has no '#!' shebang; use 100644 (git update-index --chmod=-x $path)"
			fail=1
		fi
		continue
	fi

	[ "$sb" = yes ] || continue

	sites=$(bare_call_sites "$(printf '%s' "$path" | sed 's/[.[\*^$]/\\&/g')")
	if [ -n "$sites" ]; then kind=bare-program; else kind=interpreted; fi

	if [ "$LIST_ONLY" = 1 ]; then
		echo "$mode $kind $path"
		continue
	fi

	if [ "$kind" = bare-program ] && [ "$mode" != 100755 ]; then
		note "$path is invoked as a bare program but is committed $mode; run: git update-index --chmod=+x $path"
		printf '%s\n' "$sites" | sed 's/^/    call site: /' >&2
		fail=1
	fi
done <<EOF
$blobs
EOF

if [ "$LIST_ONLY" = 1 ]; then
	exit 0
fi

if [ "$fail" -ne 0 ]; then
	note "FAILED - see docs/decisions or CLAUDE.md 'Repo conventions' for the shebang/mode rule"
	exit 1
fi
echo "check-file-modes: OK - every bare-program script is 100755, nothing is 100755 without a shebang"
