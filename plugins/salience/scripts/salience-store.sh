#!/usr/bin/env bash
#
# salience-store.sh — manage the private Salience store.
#
# The store holds the user's professional identity record, voice profile,
# positioning, relationships, content log, and experiments. It lives OUTSIDE the
# repository and is never committed.
#
#   init     create the store and seed empty files (never overwrites)
#   status   show what exists, sizes, and last modification
#   export   write a portable archive of everything stored
#   reset    clear learned preferences, preserving verified career facts
#   path     print the resolved store path
#
# Location: $SALIENCE_HOME, default ~/.claude/salience

set -euo pipefail

STORE="${SALIENCE_HOME:-$HOME/.claude/salience}"
FILES=(identity.yaml voice.yaml positioning.yaml relationships.yaml content-log.yaml experiments.yaml)

usage() {
  sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

die() { echo "salience-store: $*" >&2; exit 1; }

cmd_path() { echo "$STORE"; }

cmd_init() {
  mkdir -p "$STORE/imports"
  local created=0 skipped=0
  for f in "${FILES[@]}"; do
    if [ -e "$STORE/$f" ]; then
      skipped=$((skipped + 1))
      continue
    fi
    # Seed with a header only. Salience fills these in; an empty file is valid.
    printf '# Salience %s\n# Private. Never commit this file.\n' "$f" > "$STORE/$f"
    created=$((created + 1))
  done

  # The store frequently sits inside a directory the user syncs or backs up.
  # Refuse to let it be picked up by a git repo that happens to contain it.
  if [ ! -e "$STORE/.gitignore" ]; then
    printf '*\n' > "$STORE/.gitignore"
  fi
  chmod 700 "$STORE" 2>/dev/null || true

  echo "Store: $STORE"
  echo "Created $created file(s), left $skipped existing file(s) untouched."
}

cmd_status() {
  [ -d "$STORE" ] || die "no store at $STORE (run: $0 init)"
  echo "Store: $STORE"
  echo
  printf '%-22s %10s  %s\n' "FILE" "BYTES" "MODIFIED"
  for f in "${FILES[@]}"; do
    if [ -e "$STORE/$f" ]; then
      # BSD stat on macOS; -f, not -c.
      printf '%-22s %10s  %s\n' "$f" \
        "$(stat -f %z "$STORE/$f")" \
        "$(stat -f %Sm -t '%Y-%m-%d %H:%M' "$STORE/$f")"
    else
      printf '%-22s %10s  %s\n' "$f" "-" "absent"
    fi
  done
  if [ -d "$STORE/imports" ]; then
    echo
    echo "imports/: $(find "$STORE/imports" -type f | wc -l | tr -d ' ') file(s)"
  fi
}

cmd_export() {
  [ -d "$STORE" ] || die "no store at $STORE"
  local stamp out
  stamp="$(date +%Y%m%d-%H%M%S)"
  out="${1:-$HOME/salience-export-$stamp.tar.gz}"
  tar -czf "$out" -C "$(dirname "$STORE")" "$(basename "$STORE")"
  echo "Exported to $out"
  echo "Contains everything Salience has stored about you, including imports."
}

cmd_reset() {
  [ -d "$STORE" ] || die "no store at $STORE"
  # Learned preferences and career facts are different things and must be
  # separately resettable. This clears the former and never touches the latter.
  echo "This clears learned preferences and keeps verified career facts:"
  echo
  echo "  CLEARED   voice.yaml, experiments.yaml"
  echo "  KEPT      identity.yaml, positioning.yaml, relationships.yaml, content-log.yaml, imports/"
  echo
  printf 'Type "reset" to confirm: '
  read -r reply
  [ "$reply" = "reset" ] || die "aborted"

  local stamp; stamp="$(date +%Y%m%d-%H%M%S)"
  for f in voice.yaml experiments.yaml; do
    [ -e "$STORE/$f" ] || continue
    mv "$STORE/$f" "$STORE/$f.pre-reset-$stamp"
    printf '# Salience %s\n# Private. Never commit this file.\n' "$f" > "$STORE/$f"
  done
  echo "Reset. Previous versions kept as *.pre-reset-$stamp."
}

case "${1:-}" in
  init)   shift; cmd_init "$@" ;;
  status) shift; cmd_status "$@" ;;
  export) shift; cmd_export "$@" ;;
  reset)  shift; cmd_reset "$@" ;;
  path)   shift; cmd_path "$@" ;;
  -h|--help|help|"") usage 0 ;;
  *) echo "salience-store: unknown command '$1'" >&2; usage 1 ;;
esac
