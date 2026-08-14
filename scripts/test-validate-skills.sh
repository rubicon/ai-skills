#!/usr/bin/env bash
#
# test-validate-skills.sh — tests for validate-skills.sh.
#
# Each case builds a throwaway repo tree in a temp dir, drops the validator in,
# runs it there, and asserts the exit status. Run from the repo root:
#   bash scripts/test-validate-skills.sh

set -u

VALIDATOR="$(cd "$(dirname "$0")" && pwd)/validate-skills.sh"
[ -f "$VALIDATOR" ] || { echo "cannot find validate-skills.sh next to this test" >&2; exit 1; }

pass=0
fail=0

# make_skill <root> <dir-name> <frontmatter-body>
make_skill() {
  local root="$1" name="$2" fm="$3"
  mkdir -p "$root/skills/$name"
  {
    echo "---"
    printf '%s\n' "$fm"
    echo "---"
    echo
    echo "# $name"
  } > "$root/skills/$name/SKILL.md"
  echo "# $name" > "$root/skills/$name/README.md"
  echo "# Changelog — $name" > "$root/skills/$name/CHANGELOG.md"
}

# expect <expected-status: ok|err> <description> <setup-fn>
expect() {
  local want="$1" desc="$2" setup="$3"
  local root status
  root=$(mktemp -d)
  "$setup" "$root"
  ( cd "$root" && bash "$VALIDATOR" >/dev/null 2>&1 )
  status=$?
  rm -rf "$root"

  if { [ "$want" = "ok" ] && [ "$status" -eq 0 ]; } || { [ "$want" = "err" ] && [ "$status" -ne 0 ]; }; then
    echo "  ok   — $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL — $desc (wanted $want, validator exited $status)"
    fail=$((fail + 1))
  fi
}

setup_valid() {
  make_skill "$1" "good-skill" 'name: good-skill
description: A well-formed skill.
version: 1.0.0'
}

setup_valid_annotated() {
  # release-please annotates the version line; that must still pass.
  make_skill "$1" "annotated-skill" 'name: annotated-skill
description: Version carries a release-please annotation.
version: 2.3.4  # x-release-please-version'
}

setup_bad_semver() {
  make_skill "$1" "bad-semver" 'name: bad-semver
description: Version is not SemVer.
version: 1.0'
}

setup_missing_name() {
  make_skill "$1" "no-name" 'description: Frontmatter has no name key.'
}

setup_malformed_yaml() {
  # Valid-looking to a grep, but not parseable YAML: unclosed flow sequence.
  make_skill "$1" "malformed-yaml" 'name: malformed-yaml
description: [unclosed, flow, sequence
version: 1.0.0'
}

setup_tab_indented_yaml() {
  # Tabs are illegal for YAML indentation; grep-based checks never notice.
  make_skill "$1" "tabbed-yaml" 'name: tabbed-yaml
description: >-
	tab indented continuation
version: 1.0.0'
}

setup_duplicate_keys() {
  make_skill "$1" "dupe-keys" 'name: dupe-keys
description: First description.
description: Second description.
version: 1.0.0'
}

setup_bad_dir_name() {
  make_skill "$1" "Bad_Skill_Name" 'name: Bad_Skill_Name
description: Directory name is not kebab-case.
version: 1.0.0'
}

setup_kebab_with_digits() {
  make_skill "$1" "divi-5-builder" 'name: divi-5-builder
description: Kebab-case with digits is legitimate.
version: 1.0.0'
}

echo "validate-skills.sh"

echo " already covered:"
expect ok  "accepts a well-formed skill"                      setup_valid
expect ok  "accepts a release-please annotated version"       setup_valid_annotated
expect err "rejects a non-SemVer version"                     setup_bad_semver
expect err "rejects frontmatter with no name"                 setup_missing_name

echo " frontmatter must be real YAML:"
expect err "rejects unparseable YAML frontmatter"             setup_malformed_yaml
expect err "rejects tab-indented YAML frontmatter"            setup_tab_indented_yaml
expect err "rejects duplicate frontmatter keys"               setup_duplicate_keys

echo " skill directory naming:"
expect err "rejects a non-kebab-case directory name"          setup_bad_dir_name
expect ok  "accepts kebab-case containing digits"             setup_kebab_with_digits

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ] || exit 1
