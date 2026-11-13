#!/usr/bin/env bash
#
# Spec 008 FR-014 / SC-005: screen matching may cost at most 5% of the frame rate. Reads the
# frame-rate table in baselines.md (or the file given) and fails if any row's "on" median is more
# than 5% below its "off" median.
#
#     specs/008-display-geometry-fov/check-fps.sh                 # baselines.md beside this script
#     specs/008-display-geometry-fov/check-fps.sh <file.md>       # another table
#
# The table is the first Markdown table in the file whose header names "Off median" and "On
# median"; each data row has the setting, the off median and the on median in frames per second.
# Exits 2 when there is no such table or a row's numbers do not parse.
set -euo pipefail

file="${1:-$(dirname "$0")/baselines.md}"
[[ -f "$file" ]] || { echo "check-fps: no file $file" >&2; exit 2; }

awk -F'|' '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    !in_table && /Off median/ && /On median/ {
        for (i = 1; i <= NF; i++) {
            h = trim($i)
            if (h ~ /^Off median/) off_col = i
            if (h ~ /^On median/) on_col = i
        }
        in_table = 1; next
    }
    in_table && /^\|[ \t:-]+\|/ && !/[0-9A-Za-z]/ { next }          # the separator row
    in_table && !/^\|/ { exit }                                      # the table ended
    in_table {
        setting = trim($2); off = trim($off_col); on = trim($on_col)
        if (off !~ /^[0-9]+(\.[0-9]+)?$/ || on !~ /^[0-9]+(\.[0-9]+)?$/ || off + 0 <= 0) {
            printf "check-fps: row \"%s\": cannot read \"%s\" and \"%s\"\n", setting, off, on > "/dev/stderr"
            bad = 1; next
        }
        rows++
        drop = (off - on) / off * 100
        printf "%-40s off %7.2f  on %7.2f  drop %5.1f%%\n", setting, off, on, drop
        if (on < off * 0.95) failed = 1
    }
    END {
        if (!off_col || !on_col || rows == 0) { print "check-fps: no frame-rate table" > "/dev/stderr"; exit 2 }
        if (bad) exit 2
        if (failed) { print "check-fps: FAIL, a drop above 5%"; exit 1 }
        print "check-fps: ok"
    }
' "$file"
