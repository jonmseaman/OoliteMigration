#!/bin/bash
# Scratch: recompute trees from step $1 to 19; on a conflict, replay that step's specs once.
cd /c/Users/jon/OoliteMigration
for n in $(seq "$1" 19); do
    if ! python -I tools/series/series.py tree $n > .agent-tmp/series-tree-$n.txt 2>&1; then
        if [ -f .agent-tmp/res/$(printf %03d $n).py ]; then
            python -I .agent-tmp/apply_res.py $n > .agent-tmp/apply-$n.txt 2>&1 || { echo "APPLY FAILED at $n"; tail -3 .agent-tmp/apply-$n.txt; exit 1; }
        fi
        python -I tools/series/series.py tree $n > .agent-tmp/series-tree-$n.txt 2>&1 || { echo "STOP at $n"; cat .agent-tmp/series-tree-$n.txt; exit 1; }
        echo "step $n: replayed"
    fi
done
echo "chain done"
