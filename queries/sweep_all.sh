#!/bin/bash
# sweep_all.sh <QuestieDB dir> [saved GearPath.lua with a /gp snapshot]
# Every class, both factions, seven levels (126 characters) on the real
# database: sweep.lua's own checks, then post_draw.lua (every tooltip, source
# and row). Prints the characters with a problem and "runs=N bad=N".
Q="$1"; SNAP="$2"
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../harness" || exit 2
runs=0; bad=0
for c in WARRIOR PALADIN HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID; do
  for f in Horde Alliance; do
    for l in 8 15 23 33 42 51 60; do
      out=$(GPDIR=../addon CLASS=$c FACTION=$f LEVEL=$l SNAPSHOT="$SNAP" POST=../queries/post_draw.lua timeout 600 lua5.1 qdb.lua "$Q" ../queries/sweep.lua 2>&1)
      runs=$((runs+1))
      if ! echo "$out" | grep -q 'problems 0$' || ! echo "$out" | grep -q '^draw problems 0 '; then
        bad=$((bad+1)); echo "== $c $f $l"; echo "$out" | grep -E 'PROBLEM|problems|error|!' | head -8
      fi
    done
  done
done
echo "runs=$runs bad=$bad"
