#!/usr/bin/env bash
# Carry auto-memory from one project's memory/ directory to another.
#
# Copy only: never moves, never overwrites. Every copy is checksum-verified,
# so a truncated or failed write is reported rather than counted as success.
# Exits non-zero if any file that should have been copied is missing or does
# not match — the caller must not relocate the session on a non-zero exit.
#
# This lives in a file rather than inline in SKILL.md on purpose: skill text is
# rendered with the invocation's argument substituted for $0, which silently
# rewrites awk's $0 into the argument and destroys the index merge.
set -uo pipefail

SRC=${1:?usage: carry-memory.sh <source-memory-dir> <destination-memory-dir>}
DST=${2:?usage: carry-memory.sh <source-memory-dir> <destination-memory-dir>}

count() { find "$1" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' '; }
sum()   { shasum -a 256 "$1" | cut -d' ' -f1; }

if [ "$SRC" = "$DST" ]; then
  echo "Same memory directory — nothing to carry."; exit 0
fi
if [ ! -d "$SRC" ] || [ "$(count "$SRC")" -eq 0 ]; then
  echo "No memory at the source — nothing to carry."; exit 0
fi

mkdir -p "$DST"
rc=0 copied=0 collided=0

while IFS= read -r f; do
  b=${f##*/}
  [ "$b" = "MEMORY.md" ] && continue
  if [ -e "$DST/$b" ]; then
    if [ "$(sum "$f")" = "$(sum "$DST/$b")" ]; then
      echo "already present, identical: $b"
    else
      echo "COLLISION (kept destination): $b"
      collided=$((collided + 1))
    fi
    continue
  fi
  cp -- "$f" "$DST/$b"
  if [ -e "$DST/$b" ] && [ "$(sum "$f")" = "$(sum "$DST/$b")" ]; then
    echo "copied: $b"
    copied=$((copied + 1))
  else
    echo "FAILED (missing or content differs after copy): $b"
    rc=1
  fi
done < <(find "$SRC" -maxdepth 1 -name '*.md' | sort)

# Index: keep the destination's MEMORY.md and append only lines it lacks.
if [ -e "$SRC/MEMORY.md" ]; then
  if [ -e "$DST/MEMORY.md" ]; then
    tmp=$(mktemp)
    awk 'FNR==NR{seen[$0];next} /^[[:space:]]*-/ && !($0 in seen)' \
        "$DST/MEMORY.md" "$SRC/MEMORY.md" > "$tmp"
    if [ -s "$tmp" ]; then
      cat "$tmp" >> "$DST/MEMORY.md"
      echo "MEMORY.md: appended $(wc -l < "$tmp" | tr -d ' ') index line(s)"
    else
      echo "MEMORY.md: no new index lines"
    fi
    rm -f "$tmp"
  else
    cp -- "$SRC/MEMORY.md" "$DST/MEMORY.md"
    echo "MEMORY.md: copied (destination had none)"
  fi
fi

echo "source=$(count "$SRC") destination=$(count "$DST") copied=$copied collisions=$collided"
[ "$rc" -ne 0 ] && echo "VERIFICATION FAILED — do not relocate the session."
exit "$rc"
