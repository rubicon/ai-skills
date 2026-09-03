#!/usr/bin/env bash
#
# test-check-no-personal-data.sh — tests for check-no-personal-data.sh.
#
# Each case builds a throwaway tree in a temp dir, runs the checker there, and
# asserts the exit status. Run from the repo root:
#   bash scripts/test-check-no-personal-data.sh

set -u

CHECKER="$(cd "$(dirname "$0")" && pwd)/check-no-personal-data.sh"
[ -f "$CHECKER" ] || { echo "cannot find check-no-personal-data.sh next to this test" >&2; exit 1; }

pass=0
fail=0

# run_case <expected-exit> <name> <setup-fn>
run_case() {
  expected="$1"; name="$2"; setup="$3"
  tmp="$(mktemp -d)"
  ( cd "$tmp" && "$setup" ) >/dev/null 2>&1
  out="$(cd "$tmp" && bash "$CHECKER" 2>&1)"
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    pass=$((pass + 1))
    printf 'ok   %s\n' "$name"
  else
    fail=$((fail + 1))
    printf 'FAIL %s (expected exit %s, got %s)\n' "$name" "$expected" "$actual"
    printf '%s\n' "$out" | sed 's/^/       /'
  fi
  rm -rf "$tmp"
}

seed() {
  mkdir -p skills/demo plugins/demo/skills/demo
  printf -- '---\nname: demo\ndescription: demo\n---\n\nNothing personal here.\n' \
    > skills/demo/SKILL.md
  printf -- '---\nname: demo\ndescription: demo\n---\n\nNothing personal here.\n' \
    > plugins/demo/skills/demo/SKILL.md
}

# --- clean tree ---------------------------------------------------------------

case_clean() { seed; }

# --- absolute home paths ------------------------------------------------------

case_users_path() {
  seed
  printf 'Read /Users/jsmith/Documents/Career for the spine.\n' >> skills/demo/SKILL.md
}

case_home_path() {
  seed
  printf 'Read /home/jsmith/career for the spine.\n' >> plugins/demo/skills/demo/SKILL.md
}

case_windows_path() {
  seed
  printf 'Read C:\\Users\\jsmith\\Documents for the spine.\n' >> skills/demo/SKILL.md
}

case_volumes_path() {
  seed
  printf 'Archive lives on /Volumes/Backup2024/career.\n' >> skills/demo/SKILL.md
}

# Documented placeholders are how you write an example absolute path.
case_placeholder_paths() {
  seed
  {
    printf 'rsync "/Users/you/Library/Application Support/App/./config.json" dest/\n'
    printf 'A backup of /Users/x/Library/config.json lands under files/.\n'
    printf 'On Linux that is /home/user/.config/app.\n'
    printf 'Windows: C:\\Users\\<user>\\AppData\\Roaming\\app\n'
  } >> skills/demo/SKILL.md
}

# --- email addresses ----------------------------------------------------------

case_real_email() {
  seed
  printf 'Questions to jane.doe@somecompany.com.\n' >> plugins/demo/skills/demo/SKILL.md
}

case_example_email() {
  seed
  {
    printf 'Write to morgan@example.com or team@example.org.\n'
    printf 'Commits use noreply@users.noreply.github.com.\n'
    printf 'Clone with git@github.com:owner/repo.git\n'
  } >> skills/demo/SKILL.md
}

# --- scope --------------------------------------------------------------------

# Root governance files are not installed content. A maintainer contact address
# in CODE_OF_CONDUCT.md is deliberate and must not fail the build.
case_root_file_ignored() {
  seed
  printf 'Report conduct issues to maintainer@somecompany.com.\n' > CODE_OF_CONDUCT.md
  printf 'Maintainer home: /Users/jsmith/dev\n' >> README.md
}

# --- allowlist ----------------------------------------------------------------

case_allowlisted() {
  seed
  printf 'Read /Users/jsmith/Documents/Career for the spine.\n' >> skills/demo/SKILL.md
  printf 'skills/demo/SKILL.md\n' > .personal-data-allow
}

case_allowlist_comments() {
  seed
  printf 'Read /Users/jsmith/Documents/Career for the spine.\n' >> skills/demo/SKILL.md
  printf '# a comment\n\nskills/demo/SKILL.md\n' > .personal-data-allow
}

# --- run ----------------------------------------------------------------------

run_case 0 "clean tree passes"                          case_clean
run_case 1 "/Users/<name> path fails"                   case_users_path
run_case 1 "/home/<name> path fails"                    case_home_path
run_case 1 "C:\\Users\\<name> path fails"               case_windows_path
run_case 1 "/Volumes/<name> path fails"                 case_volumes_path
run_case 0 "documented placeholder paths pass"          case_placeholder_paths
run_case 1 "real email address fails"                   case_real_email
run_case 0 "example.com and noreply addresses pass"     case_example_email
run_case 0 "root files are out of scope"                case_root_file_ignored
run_case 0 "allowlisted file is skipped"                case_allowlisted
run_case 0 "allowlist ignores comments and blanks"      case_allowlist_comments

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
