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

# make_plugin_skill <root> <plugin-name> <skill-dir-name> <frontmatter-body>
# Builds a minimal valid plugin around one bundled skill. Bundled skills carry
# no README.md or CHANGELOG.md of their own; the plugin supplies those.
make_plugin_skill() {
  local root="$1" plugin="$2" name="$3" fm="$4"
  mkdir -p "$root/skills" "$root/plugins/$plugin/.claude-plugin" "$root/plugins/$plugin/skills/$name"
  printf '{"name": "%s", "version": "1.0.0"}\n' "$plugin" > "$root/plugins/$plugin/.claude-plugin/plugin.json"
  echo "# $plugin" > "$root/plugins/$plugin/README.md"
  echo "# Changelog — $plugin" > "$root/plugins/$plugin/CHANGELOG.md"
  {
    echo "---"
    printf '%s\n' "$fm"
    echo "---"
    echo
    echo "# $name"
  } > "$root/plugins/$plugin/skills/$name/SKILL.md"
  # The validator requires at least one skill under skills/.
  make_skill "$root" "good-skill" 'name: good-skill
description: A well-formed skill.
version: 1.0.0'
}

# register_packages <root>
# Writes release-please-config.json and .release-please-manifest.json listing
# every directory under skills/ and plugins/, as a fully registered repo would
# have. expect() runs this after each setup so a case only has to say what it
# breaks; the release-please cases below remove one entry afterwards.
register_packages() {
  local root="$1" dir sep_c="" sep_m=""
  local config='{"packages": {' manifest='{'
  for dir in "$root"/skills/*/ "$root"/plugins/*/; do
    [ -d "$dir" ] || continue
    local key="$(basename "$(dirname "$dir")")/$(basename "$dir")"
    config="${config}${sep_c}\"${key}\": {}"
    manifest="${manifest}${sep_m}\"${key}\": \"1.0.0\""
    sep_c=", "; sep_m=", "
  done
  printf '%s}}\n' "$config" > "$root/release-please-config.json"
  printf '%s}\n' "$manifest" > "$root/.release-please-manifest.json"
}

# drop_json_key <file> <key> [<parent-key>]
# Deletes <key> from the top level of <file>, or from <parent-key> inside it.
drop_json_key() {
  python3 - "$@" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
parent = sys.argv[3] if len(sys.argv) > 3 else None
data = json.load(open(path))
del (data[parent] if parent else data)[key]
json.dump(data, open(path, "w"))
PY
}

# expect <expected-status: ok|err> <description> <setup-fn> [<mutate-fn>]
expect() {
  local want="$1" desc="$2" setup="$3" mutate="${4:-}"
  local root status
  root=$(mktemp -d)
  "$setup" "$root"
  register_packages "$root"
  [ -z "$mutate" ] || "$mutate" "$root"
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

setup_missing_description() {
  make_skill "$1" "no-description" 'name: no-description
version: 1.0.0'
}

setup_plugin_skill_valid() {
  make_plugin_skill "$1" "good-plugin" "bundled-skill" 'name: bundled-skill
description: A well-formed bundled skill.
version: 1.0.0'
}

setup_plugin_skill_no_version() {
  make_plugin_skill "$1" "good-plugin" "bundled-skill" 'name: bundled-skill
description: Version is optional.'
}

setup_plugin_skill_malformed_yaml() {
  make_plugin_skill "$1" "good-plugin" "bundled-skill" 'name: bundled-skill
description: [unclosed, flow, sequence
version: 1.0.0'
}

setup_plugin_skill_missing_name() {
  make_plugin_skill "$1" "good-plugin" "bundled-skill" 'description: Frontmatter has no name key.'
}

setup_plugin_skill_missing_description() {
  make_plugin_skill "$1" "good-plugin" "bundled-skill" 'name: bundled-skill
version: 1.0.0'
}

setup_plugin_skill_bad_semver() {
  make_plugin_skill "$1" "good-plugin" "bundled-skill" 'name: bundled-skill
description: Version is not SemVer.
version: 1.0'
}

setup_plugin_skill_duplicate_keys() {
  make_plugin_skill "$1" "good-plugin" "bundled-skill" 'name: bundled-skill
description: First description.
description: Second description.
version: 1.0.0'
}

setup_plugin_skill_no_frontmatter() {
  make_plugin_skill "$1" "good-plugin" "bundled-skill" 'name: bundled-skill'
  printf '# bundled-skill\n' > "$1/plugins/good-plugin/skills/bundled-skill/SKILL.md"
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

echo " skills/ frontmatter requires a description:"
expect err "rejects frontmatter with no description"          setup_missing_description

echo " skills bundled inside plugins:"
expect ok  "accepts a well-formed bundled skill"              setup_plugin_skill_valid
expect ok  "accepts a bundled skill with no version"          setup_plugin_skill_no_version
expect err "rejects a bundled skill with unparseable YAML"    setup_plugin_skill_malformed_yaml
expect err "rejects a bundled skill with no name"             setup_plugin_skill_missing_name
expect err "rejects a bundled skill with no description"      setup_plugin_skill_missing_description
expect err "rejects a bundled skill with a non-SemVer version" setup_plugin_skill_bad_semver
expect err "rejects a bundled skill with duplicate keys"      setup_plugin_skill_duplicate_keys
expect err "rejects a bundled skill with no frontmatter"      setup_plugin_skill_no_frontmatter

# Mutations applied after register_packages: each removes one registration.
drop_skill_config()    { drop_json_key "$1/release-please-config.json" "skills/good-skill" packages; }
drop_skill_manifest()  { drop_json_key "$1/.release-please-manifest.json" "skills/good-skill"; }
drop_plugin_config()   { drop_json_key "$1/release-please-config.json" "plugins/good-plugin" packages; }
drop_plugin_manifest() { drop_json_key "$1/.release-please-manifest.json" "plugins/good-plugin"; }
remove_config_file()   { rm "$1/release-please-config.json"; }
remove_manifest_file() { rm "$1/.release-please-manifest.json"; }

echo " every skill and plugin is under release-please:"
expect ok  "accepts skills and plugins that are all registered" setup_plugin_skill_valid
expect err "rejects a skill with no release-please config entry"       setup_valid drop_skill_config
expect err "rejects a skill with no release-please manifest entry"     setup_valid drop_skill_manifest
expect err "rejects a plugin with no release-please config entry"      setup_plugin_skill_valid drop_plugin_config
expect err "rejects a plugin with no release-please manifest entry"    setup_plugin_skill_valid drop_plugin_manifest
expect err "rejects a missing release-please-config.json"              setup_valid remove_config_file
expect err "rejects a missing .release-please-manifest.json"           setup_valid remove_manifest_file

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ] || exit 1
