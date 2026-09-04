#!/usr/bin/env bash
# Re-check every reviewed source against the commit it was reviewed at.
#
# Prints only what moved. A repo whose HEAD still matches repos.tsv needs no
# re-reading — that is the whole point of pinning the SHA.
#
#   bash refresh.sh            # compare against remote, clone nothing
#   bash refresh.sh --clone D  # also clone/update changed repos into D
#
# Exit 0 = nothing changed. Exit 10 = at least one repo moved.

set -uo pipefail
export PATH=/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin

cd "$(dirname "$0")" || exit 1
LEDGER=repos.tsv
[ -f "$LEDGER" ] || { echo "missing $LEDGER" >&2; exit 1; }

CLONE_DIR=""
[ "${1:-}" = "--clone" ] && CLONE_DIR="${2:?--clone needs a directory}"
[ -n "$CLONE_DIR" ] && mkdir -p "$CLONE_DIR"

checked=0; moved=0; failed=0

# Read from a file descriptor, not a pipe: a pipeline runs the loop body in a
# subshell and the counters never make it back out.
while IFS=$'\t' read -r repo url sha date count scope; do
    [ "$repo" = "repo" ] && continue
    [ -z "${repo:-}" ] && continue
    checked=$((checked + 1))

    head=$(git ls-remote "$url" HEAD 2>/dev/null | awk '{print $1}')
    if [ -z "$head" ]; then
        printf 'UNREACHABLE  %s\n' "$repo"
        failed=$((failed + 1))
        continue
    fi

    if [ "$head" = "$sha" ]; then
        continue
    fi

    moved=$((moved + 1))
    printf 'MOVED        %s\n  reviewed %s (%s)\n  now      %s\n' \
        "$repo" "${sha:0:12}" "$date" "${head:0:12}"

    if [ -n "$CLONE_DIR" ]; then
        dest="$CLONE_DIR/${repo//\//~}"
        if [ -d "$dest/.git" ]; then
            git -C "$dest" fetch --quiet origin && git -C "$dest" checkout --quiet FETCH_HEAD
        else
            git clone --quiet --depth 50 "$url" "$dest"
        fi
        # What actually changed, limited to skill definitions.
        printf '  changed SKILL.md files:\n'
        git -C "$dest" diff --name-only "$sha" FETCH_HEAD -- '*SKILL.md' 2>/dev/null \
            | sed 's/^/    /' || printf '    (could not diff — reviewed commit not in shallow history)\n'
    fi
done < "$LEDGER"

printf '\n%d repos checked, %d moved, %d unreachable\n' "$checked" "$moved" "$failed"

# A zero-iteration loop must never read as "nothing changed".
if [ "$checked" -eq 0 ]; then
    echo "ERROR: read 0 rows from $LEDGER — not a clean result" >&2
    exit 1
fi

[ "$moved" -gt 0 ] && exit 10
exit 0
