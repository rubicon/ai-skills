#!/usr/bin/env bash
#
# validate-skills.sh — baseline verification for the ai-skills repo.
#
# Checks repo conventions (see CLAUDE.md / docs/process/ai-skills-repo-overlay.md):
#   - every skills/<name>/ is a directory containing SKILL.md, README.md, CHANGELOG.md
#   - no flat .md files directly under skills/
#   - each SKILL.md begins with YAML frontmatter that includes name + description
#   - the version field, when present, is full SemVer (MAJOR.MINOR.PATCH)
#   - each plugins/<name>/ has .claude-plugin/plugin.json, README.md, CHANGELOG.md;
#     plugin.json parses, has a name, and a SemVer version when present
#   - .claude-plugin/marketplace.json, when present, parses and has name, owner.name, plugins[]
#
# An empty plugins/ is fine. JSON checks use python3 (present in CI and locally).
# Exits non-zero on any violation. Run locally before opening a PR; also run in CI.

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

if [ ! -d skills ]; then
  echo "FAIL: no skills/ directory (run from the repo root)" >&2
  exit 1
fi

# No flat markdown files directly under skills/ (skills must be directories).
for f in skills/*.md; do
  [ -e "$f" ] && err "flat markdown in skills/: $f (skills must be directories)"
done

found=0
for dir in skills/*/; do
  [ -d "$dir" ] || continue
  found=1
  name=$(basename "$dir")

  for req in SKILL.md README.md CHANGELOG.md; do
    [ -f "${dir}${req}" ] || err "$name: missing $req"
  done

  skill="${dir}SKILL.md"
  [ -f "$skill" ] || continue

  # Extract the YAML frontmatter block (between the first '---' and the next '---').
  fm=$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f{print}' "$skill")
  if [ -z "$fm" ]; then
    err "$name: SKILL.md has no YAML frontmatter"
    continue
  fi

  printf '%s\n' "$fm" | grep -qE '^name:[[:space:]]*[^[:space:]]'        || err "$name: frontmatter missing 'name'"
  printf '%s\n' "$fm" | grep -qE '^description:'                          || err "$name: frontmatter missing 'description'"

  ver=$(printf '%s\n' "$fm" | grep -E '^version:' | head -1 | sed -E "s/^version:[[:space:]]*//; s/[\"' ]//g")
  if [ -n "$ver" ] && ! printf '%s' "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    err "$name: version '$ver' is not SemVer (MAJOR.MINOR.PATCH)"
  fi
done

[ "$found" -eq 1 ] || err "no skill directories found under skills/"

# --- Plugin / marketplace checks (Claude Code plugin standards) ---
# Skills and plugins are independent trees; an empty plugins/ is valid. A flat README.md
# directly under plugins/ is allowed (unlike skills/), so no flat-markdown check here.

mp=".claude-plugin/marketplace.json"
if [ -f "$mp" ]; then
  python3 - "$mp" <<'PY' || fail=1
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception as e:
    print(f"FAIL: {p}: invalid JSON ({e})", file=sys.stderr); sys.exit(1)
ok = True
if not isinstance(d.get("name"), str) or not d["name"].strip():
    print(f"FAIL: {p}: missing 'name'", file=sys.stderr); ok = False
owner = d.get("owner")
if not isinstance(owner, dict) or not isinstance(owner.get("name"), str) or not owner["name"].strip():
    print(f"FAIL: {p}: missing 'owner.name'", file=sys.stderr); ok = False
if not isinstance(d.get("plugins"), list):
    print(f"FAIL: {p}: 'plugins' must be an array", file=sys.stderr); ok = False
sys.exit(0 if ok else 1)
PY
fi

for dir in plugins/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")

  for req in .claude-plugin/plugin.json README.md CHANGELOG.md; do
    [ -f "${dir}${req}" ] || err "plugin $name: missing $req"
  done

  manifest="${dir}.claude-plugin/plugin.json"
  [ -f "$manifest" ] || continue
  python3 - "$manifest" "$name" <<'PY' || fail=1
import json, re, sys
p, name = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(p))
except Exception as e:
    print(f"FAIL: plugin {name}: invalid JSON in plugin.json ({e})", file=sys.stderr); sys.exit(1)
ok = True
if not isinstance(d.get("name"), str) or not d["name"].strip():
    print(f"FAIL: plugin {name}: plugin.json missing 'name'", file=sys.stderr); ok = False
v = d.get("version")
if v is not None and not re.match(r'^[0-9]+\.[0-9]+\.[0-9]+$', str(v)):
    print(f"FAIL: plugin {name}: version '{v}' is not SemVer (MAJOR.MINOR.PATCH)", file=sys.stderr); ok = False
sys.exit(0 if ok else 1)
PY
done

if [ "$fail" -ne 0 ]; then
  echo "Skill validation FAILED." >&2
  exit 1
fi
echo "All skill checks passed."
