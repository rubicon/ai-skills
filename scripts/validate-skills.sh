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

  # Directory name is the skill's invocation name; it must be kebab-case.
  printf '%s' "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' \
    || err "$name: skill directory name must be kebab-case (lowercase, digits, single hyphens)"

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

  # Parse the frontmatter as real YAML. Checking with grep alone lets malformed
  # frontmatter (unclosed flow sequences, tab indentation, duplicate keys) pass
  # here and then fail wherever the skill is actually loaded.
  # The frontmatter travels in an env var: the heredoc already occupies stdin
  # (it is the Python program), so a pipe here would be discarded.
  SKILL_FRONTMATTER="$fm" python3 - "$name" <<'PY' || fail=1
import os, re, sys

name = sys.argv[1]
text = os.environ["SKILL_FRONTMATTER"]

try:
    import yaml
except ImportError:
    print("FAIL: PyYAML is required to validate SKILL.md frontmatter "
          "(pip install pyyaml)", file=sys.stderr)
    sys.exit(1)


class Strict(yaml.SafeLoader):
    """SafeLoader that rejects duplicate mapping keys instead of silently
    keeping the last one."""


def _no_duplicates(loader, node, deep=False):
    seen = set()
    for key_node, _ in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in seen:
            raise yaml.YAMLError(f"duplicate key {key!r}")
        seen.add(key)
    return yaml.SafeLoader.construct_mapping(loader, node, deep)


Strict.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _no_duplicates
)

try:
    # Strict subclasses SafeLoader, so this is safe_load semantics plus the
    # duplicate-key check above — no arbitrary object construction.
    data = yaml.load(text, Loader=Strict)
except yaml.YAMLError as e:
    detail = str(e).replace("\n", " ")
    print(f"FAIL: {name}: SKILL.md frontmatter is not valid YAML ({detail})",
          file=sys.stderr)
    sys.exit(1)

if not isinstance(data, dict):
    print(f"FAIL: {name}: SKILL.md frontmatter must be a YAML mapping",
          file=sys.stderr)
    sys.exit(1)

ok = True

value = data.get("name")
if not isinstance(value, str) or not value.strip():
    print(f"FAIL: {name}: frontmatter missing 'name'", file=sys.stderr)
    ok = False

if "description" not in data:
    print(f"FAIL: {name}: frontmatter missing 'description'", file=sys.stderr)
    ok = False
else:
    value = data["description"]
    if not isinstance(value, str) or not value.strip():
        print(f"FAIL: {name}: frontmatter 'description' must be a non-empty string",
              file=sys.stderr)
        ok = False

if "version" in data and data["version"] is not None:
    # A bare 1.0 parses as a float, so compare on the raw text to report what
    # the author actually wrote.
    raw = re.search(r"^version:[ \t]*(.*)$", text, re.MULTILINE)
    version = raw.group(1) if raw else str(data["version"])
    version = re.sub(r"[ \t]*#.*$", "", version).strip().strip("\"'")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        print(f"FAIL: {name}: version '{version}' is not SemVer (MAJOR.MINOR.PATCH)",
              file=sys.stderr)
        ok = False

sys.exit(0 if ok else 1)
PY
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
