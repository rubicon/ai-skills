#!/usr/bin/env bash
#
# check-no-personal-data.sh — fail the build when installed content carries a
# contributor's personal data.
#
# Everything under skills/ and plugins/ is published and installed on other
# people's machines. A path or address that names a real person, machine, or
# home directory does not belong there, whether it was written deliberately or
# transcribed from a working session.
#
# Scope is skills/ and plugins/ only. Root governance files are excluded on
# purpose: a maintainer contact address in CODE_OF_CONDUCT.md is deliberate.
#
# What this catches:
#   - absolute home paths        /Users/<name>, /home/<name>, C:\Users\<name>
#   - mounted volume paths       /Volumes/<name>
#   - real email addresses       anything not example.com/.org or a noreply form
#
# What it does NOT catch, and no mechanical check can: content that is
# personal by virtue of being *accurate* — a directory tree transcribed from a
# real folder, real file counts, a real document title. Those read as ordinary
# examples. The defense is the rule, not the grep: examples in installed
# content are invented, never observed.
#
# Escape hatch: list a path in .personal-data-allow (one per line, # comments
# allowed) to skip it. Use it for a file whose match is genuinely a
# placeholder this script cannot recognize, and say why in a comment.
#
# Usage: bash scripts/check-no-personal-data.sh   (from the repo root)

set -u

status=0
ROOTS="skills plugins"
ALLOW_FILE=".personal-data-allow"

# Placeholder user segments. These are how you write an example absolute path,
# and they are the only user names permitted in one.
PLACEHOLDERS='you|x|user|username|me|name|someone|<user>|<username>|<you>|<name>|USER|USERNAME'

# Addresses that are documentation, not contact details.
EMAIL_OK='@example\.(com|org|net)$|@users\.noreply\.github\.com$|^noreply@|^git@github\.com$'

report() {
  # report <file> <rule> ; reads offending "line:text" pairs on stdin
  file="$1"; rule="$2"
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    printf 'FAIL %s: %s\n' "$rule" "$file"
    printf '     %s\n' "$hit"
    status=1
  done
}

# Build the allowlist.
allowed() {
  [ -f "$ALLOW_FILE" ] || return 1
  grep -v '^[[:space:]]*#' "$ALLOW_FILE" 2>/dev/null \
    | grep -v '^[[:space:]]*$' \
    | grep -qxF "$1"
}

scanned=0

for root in $ROOTS; do
  [ -d "$root" ] || continue
  while IFS= read -r file; do
    allowed "$file" && continue
    scanned=$((scanned + 1))

    # --- absolute home and volume paths ---
    # Match the path, then drop hits whose user segment is a placeholder.
    # `report` must run in THIS shell to set status, so it is fed by process
    # substitution rather than by a pipe.
    report "$file" "absolute home path" < <(
      grep -nE '(/Users/|/home/|/Volumes/)[A-Za-z0-9_.<>-]+|[Cc]:\\Users\\[A-Za-z0-9_.<>-]+' "$file" 2>/dev/null \
        | grep -vE "(/Users/|/home/|/Volumes/|[Cc]:\\\\Users\\\\)($PLACEHOLDERS)([/\\\\[:space:]\"'\`]|$)"
    )

    # --- email addresses ---
    report "$file" "email address" < <(
      grep -nE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$file" 2>/dev/null \
        | while IFS= read -r line; do
            num="${line%%:*}"
            printf '%s\n' "${line#*:}" \
              | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
              | grep -vE "$EMAIL_OK" \
              | while IFS= read -r addr; do printf '%s: %s\n' "$num" "$addr"; done
          done
    )

  done < <(find "$root" -type f \
             \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' -o -name '*.json' \
                -o -name '*.sh' -o -name '*.txt' \) \
             -not -path '*/node_modules/*' -not -path '*/.git/*' | sort)
done

if [ "$status" -eq 0 ]; then
  printf 'No personal data found in installed content (%s files scanned).\n' "$scanned"
else
  printf '\nInstalled content must not carry a contributor'"'"'s personal data.\n'
  printf 'Replace the value with an invented example, or allowlist the file in %s with a reason.\n' "$ALLOW_FILE"
fi

exit "$status"
