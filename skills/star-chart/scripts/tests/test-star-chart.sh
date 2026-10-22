#!/usr/bin/env bash
# test-star-chart.sh: network-free test suite for the star-chart scripts.
#
# Every jq transform, rule, plan round-trip, dry-run listing, apply guard and
# undo listing runs here against invented fixtures. Nothing in this suite may
# reach GitHub: gh is pointed at an unresolvable host with a dummy token, so a
# stray call fails instead of reading or writing a real account.
#
# Usage: bash skills/star-chart/scripts/tests/test-star-chart.sh
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPTS=$(dirname "$HERE")
SKILL=$(dirname "$SCRIPTS")
FIX="$HERE/fixtures"
JQ="$SCRIPTS/jq"

# A fixed clock: 24 calendar months before it is 2024-06-15T00:00:00Z and
# 90 days before it is 2026-03-17T00:00:00Z. The fixtures sit on both edges.
export STAR_CHART_NOW=2026-06-15T00:00:00Z
export STAR_CHART_THROTTLE=0
export STAR_CHART_MAX_WAIT=0
export GH_HOST=star-chart-test.invalid
export GH_TOKEN=star-chart-test-invalid
export GH_ENTERPRISE_TOKEN=star-chart-test-invalid
unset GITHUB_TOKEN

TMP=$(mktemp -d "${TMPDIR:-/tmp}/star-chart-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; printf '%s\n' "$1" >>"$TMP/passed-names"; }
not_ok() {
  fail=$((fail + 1))
  printf 'FAIL %s\n' "$1"
  if [ -n "${2:-}" ]; then printf '%s\n' "$2" | sed 's/^/     /' | head -20; fi
}

# check <name> <jq boolean expression> <json file>
check() {
  if jq -e "$2" "$3" >/dev/null 2>&1; then ok "$1"
  else not_ok "$1" "$(jq -c . "$3" 2>&1 | head -c 600)"; fi
}

# contains <name> <needle> <haystack file>
contains() {
  if grep -qF -- "$2" "$3"; then ok "$1"; else not_ok "$1" "missing: $2"$'\n'"$(cat "$3")"; fi
}

# lacks <name> <needle> <haystack file>
lacks() {
  if grep -qF -- "$2" "$3"; then not_ok "$1" "unexpected: $2"$'\n'"$(cat "$3")"; else ok "$1"; fi
}

# exits <name> <expected status> <actual status> [output file]
exits() {
  if [ "$3" -eq "$2" ]; then ok "$1"
  else not_ok "$1" "expected exit $2, got $3"$'\n'"$( [ -n "${4:-}" ] && cat "$4")"; fi
}

normalize() { # <previous export timestamp or "">
  jq -n -L "$JQ" \
    --slurpfile starred "$FIX/starred.raw.json" \
    --slurpfile lists "$FIX/lists.raw.json" \
    --arg exported_at "$STAR_CHART_NOW" --arg login example-user --arg previous "$1" \
    -f "$JQ/normalize.jq"
}

rules_json() { jq -R -s -L "$JQ" -f "$JQ/rules.jq" "$1"; }

classify() { # <stars.json> <rules json> [previous classification file]
  if [ -n "${3:-}" ]; then
    jq -L "$JQ" --argjson rules "$2" --arg now "$STAR_CHART_NOW" --slurpfile prev "$3" -f "$JQ/classify.jq" "$1"
  else
    jq -L "$JQ" --argjson rules "$2" --arg now "$STAR_CHART_NOW" --argjson prev '[]' -f "$JQ/classify.jq" "$1"
  fi
}

# A data directory laid out the way export.sh leaves it, plus the fixture plan.
make_data_dir() {
  local d="$TMP/$1"
  mkdir -p "$d"
  normalize "" >"$d/stars.json"
  cp "$FIX/rules.fixture.md" "$d/rules.md"
  cp "$FIX/plan.fixture.json" "$d/plan.json"
  printf '%s' "$d"
}

# Approve the plan's category changes the way the user's yes does: list them,
# take the hash the listing prints, and pass it back.
approve_categories() { # <data dir>
  local sha
  sha=$(STAR_CHART_DIR="$1" bash "$SCRIPTS/plan.sh" categories | sed -n 's/^Categories SHA-256: //p')
  STAR_CHART_DIR="$1" bash "$SCRIPTS/plan.sh" approve-categories "$sha" >/dev/null
}

# The approval hash dry-run.sh prints for a data directory's current plan.
approval_hash() { # <data dir>
  (STAR_CHART_DIR="$1"; . "$SCRIPTS/lib.sh"; sc_approval_hash "$1/plan.json" "$1/stars.json")
}

# Fingerprint of every file in a directory, to prove a script changed nothing.
fingerprint() { (cd "$1" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null || true); }

echo "# normalize.jq"
normalize "" >"$TMP/stars.json"
check "keeps all nine stars" '.stars | length == 9' "$TMP/stars.json"
check "records login and export time" '.login == "example-user" and .exported_at == "2026-06-15T00:00:00Z"' "$TMP/stars.json"
check "carries the required fields" '.stars[0] | keys == (["archived","description","full_name","language","list_ids","lists","new","node_id","pushed_at","stargazers_count","starred_at","topics","url"])' "$TMP/stars.json"
check "url comes from html_url" '.stars[0].url == "https://github.com/example-org/fast-parser"' "$TMP/stars.json"
check "membership by List id and name" '(.stars[] | select(.full_name == "example-org/fast-parser")) | .list_ids == ["UL_1","UL_2","UL_3"] and .lists == ["Parsers","CLI Tools","Parsing Libs"]' "$TMP/stars.json"
check "a star in no List has empty membership" '(.stars[] | select(.full_name == "sample-labs/new-agent")) | .list_ids == [] and .lists == []' "$TMP/stars.json"
check "null topics become an empty array" '(.stars[] | select(.full_name == "example-org/empty-repo")) | .topics == [] and .description == null' "$TMP/stars.json"
check "List metadata with item counts, without items" '.lists == [{"id":"UL_1","name":"Parsers","description":"Parsing libraries","isPrivate":false,"item_count":2},{"id":"UL_2","name":"CLI Tools","description":"","isPrivate":true,"item_count":2},{"id":"UL_3","name":"Parsing Libs","description":"Overlaps Parsers","isPrivate":false,"item_count":2},{"id":"UL_4","name":"Old Stuff","description":"","isPrivate":false,"item_count":0}]' "$TMP/stars.json"
check "first export marks every star new" '[.stars[] | select(.new)] | length == 9' "$TMP/stars.json"
check "first export has no previous timestamp" '.previous_export_at == null' "$TMP/stars.json"
normalize "2025-06-01T00:00:00Z" >"$TMP/stars-incremental.json"
check "later export marks only stars added since" '[.stars[] | select(.new) | .full_name] | sort == ["boundary/protect-edge","sample-labs/new-agent"]' "$TMP/stars-incremental.json"
check "later export records the previous timestamp" '.previous_export_at == "2025-06-01T00:00:00Z"' "$TMP/stars-incremental.json"

echo "# rules.jq"
rules_json "$SKILL/rules.example.md" >"$TMP/rules-default.json"
check "shipped defaults" '. == {"stale_months":24,"protect_days":90,"flag_archived":true,"deprecated_terms":["deprecated","unmaintained"],"target_lists":20,"keep_always":[],"categories_use":[],"categories_avoid":[]}' "$TMP/rules-default.json"
rules_json "$FIX/rules.fixture.md" >"$TMP/rules.json"
check "keep-always patterns lose backticks; prose lines are ignored" '.keep_always == ["keepers/*"]' "$TMP/rules.json"
check "categories to use and avoid" '.categories_use == ["Parsers","CLI Tools","AI Agents"] and .categories_avoid == ["Misc"]' "$TMP/rules.json"
check "no List target when the setting is absent" '.target_lists == null' "$TMP/rules.json"
sed 's/(months without a push): 24/(months without a push): two years/' "$FIX/rules.fixture.md" >"$TMP/rules-bad.md"
rules_json "$TMP/rules-bad.md" >"$TMP/rules-bad.out" 2>&1
exits "a non-numeric cutoff is an error" 5 $? "$TMP/rules-bad.out"
contains "the error names the setting" 'Stale cutoff' "$TMP/rules-bad.out"
sed 's/^- Flag archived repos: yes/- Flag archived repos: no/; s/^- Flag descriptions containing:.*/- Flag descriptions containing:/' "$FIX/rules.fixture.md" >"$TMP/rules-off.md"
rules_json "$TMP/rules-off.md" >"$TMP/rules-off.json"
check "archived and description flags can be switched off" '.flag_archived == false and .deprecated_terms == []' "$TMP/rules-off.json"

echo "# classify.jq"
RULES=$(cat "$TMP/rules.json")
classify "$TMP/stars.json" "$RULES" >"$TMP/cls.json"
check "cutoff is 24 calendar months back" '.stale_cutoff == "2024-06-15T00:00:00Z"' "$TMP/cls.json"
check "protection starts 90 days back" '.protect_since == "2026-03-17T00:00:00Z"' "$TMP/cls.json"
check "flagged set" '[.flagged[].repo] | sort == ["boundary/just-before","example-org/empty-repo","example-org/old-cli","sample-labs/legacy-sdk"]' "$TMP/cls.json"
check "pushed exactly at the cutoff is not stale" '[.flagged[].repo] | index(["boundary/at-cutoff"]) == null' "$TMP/cls.json"
check "stale reason carries the push date" '(.flagged[] | select(.repo == "example-org/old-cli")).reasons == ["no push since 2023-01-01"]' "$TMP/cls.json"
check "archived and deprecated text, case-insensitive" '(.flagged[] | select(.repo == "sample-labs/legacy-sdk")).reasons == ["archived","description mentions \"deprecated\""]' "$TMP/cls.json"
check "one second before the cutoff is stale, plus unmaintained" '(.flagged[] | select(.repo == "boundary/just-before")).reasons == ["no push since 2024-06-14","description mentions \"unmaintained\""]' "$TMP/cls.json"
check "never pushed is flagged" '(.flagged[] | select(.repo == "example-org/empty-repo")).reasons == ["never pushed"]' "$TMP/cls.json"
check "protected set" '[.protected[].repo] | sort == ["boundary/protect-edge","keepers/forever-tool","sample-labs/new-agent"]' "$TMP/cls.json"
check "keep-always beats staleness" '(.protected[] | select(.repo == "keepers/forever-tool")) | .reason == "keep-always pattern" and .reasons == ["no push since 2022-01-01"]' "$TMP/cls.json"
check "a recent star is protected even when stale" '(.protected[] | select(.repo == "sample-labs/new-agent")).reason == "starred within the last 90 days"' "$TMP/cls.json"
check "starred exactly at the edge is protected" '[.protected[].repo] | index(["boundary/protect-edge"]) != null' "$TMP/cls.json"
check "with no previous run, every flag is new" '[.flagged[] | select(.newly_flagged | not)] | length == 0' "$TMP/cls.json"
jq '{flagged: [{repo: "example-org/old-cli"}]}' -n >"$TMP/cls-prev.json"
classify "$TMP/stars.json" "$RULES" "$TMP/cls-prev.json" >"$TMP/cls2.json"
check "flags seen in the previous run are not new" '(.flagged[] | select(.repo == "example-org/old-cli")).newly_flagged == false and ([.flagged[] | select(.newly_flagged)] | length == 3)' "$TMP/cls2.json"
classify "$TMP/stars.json" "$(cat "$TMP/rules-off.json")" >"$TMP/cls-off.json"
check "switched-off flags leave only staleness" '([.flagged[] | select(.repo == "sample-labs/legacy-sdk")] == []) and ((.flagged[] | select(.repo == "boundary/just-before")).reasons == ["no push since 2024-06-14"])' "$TMP/cls-off.json"

check "per-List size, flags and overlap" '(.lists[] | select(.name == "Parsing Libs")) == {"name":"Parsing Libs","repos":2,"flagged":1,"top_languages":["Python","Rust"],"overlaps":[{"list":"Parsers","shared":1},{"list":"CLI Tools","shared":1}]}' "$TMP/cls.json"
check "an empty List is reported" '(.lists[] | select(.name == "Old Stuff")) | .repos == 0 and .overlaps == []' "$TMP/cls.json"
check "stars in no List are counted" '.unlisted == 5' "$TMP/cls.json"

echo "# validate.jq"
validate() { jq -L "$JQ" --slurpfile stars "$TMP/stars.json" --slurpfile cls "$TMP/cls.json" -f "$JQ/validate.jq" "$1"; }
validate "$FIX/plan.fixture.json" >"$TMP/v-ok.json"
check "the fixture plan is valid" '. == []' "$TMP/v-ok.json"
bad_plan() { jq "$1" "$FIX/plan.fixture.json" >"$TMP/bad.json"; validate "$TMP/bad.json" >"$TMP/v-bad.json"; }
bad_plan '.unstar += [{"repo": "sample-labs/new-agent", "reason": "x"}]'
check "unstarring a recent star is rejected" 'any(.[]; test("sample-labs/new-agent is protected \\(starred within the last 90 days\\)"))' "$TMP/v-bad.json"
bad_plan '.unstar += [{"repo": "KEEPERS/forever-tool", "reason": "x"}]'
check "unstarring a keep-always repo is rejected, any case" 'any(.[]; test("is protected \\(keep-always pattern\\)"))' "$TMP/v-bad.json"
bad_plan '.unstar += [{"repo": "nobody/nothing", "reason": "x"}]'
check "unknown repo is rejected" 'any(.[]; test("nobody/nothing is not in your stars"))' "$TMP/v-bad.json"
bad_plan '.assignments += [{"repo": "boundary/just-before", "lists": ["Nowhere"], "reason": "x"}]'
check "unknown List is rejected" 'any(.[]; test("List \"Nowhere\""))' "$TMP/v-bad.json"
bad_plan '.lists_to_create += [{"name": "parsers", "description": "", "private": false, "reason": "x"}]'
check "creating an existing List is rejected, any case" 'any(.[]; test("already exists"))' "$TMP/v-bad.json"
bad_plan '.unstar += [{"repo": "sample-labs/new-agent", "reason": "x"}] | .unstar[0].repo = "boundary/at-cutoff"'
check "assigning and unstarring one repo is rejected" 'any(.[]; test("boundary/at-cutoff is both"))' "$TMP/v-bad.json"
bad_plan '.assignments += [.assignments[0]]'
check "duplicate assignment is rejected" 'any(.[]; test("more than once"))' "$TMP/v-bad.json"
bad_plan '.unstar[0].reason = ""'
check "a missing reason is rejected" 'any(.[]; test("has no reason"))' "$TMP/v-bad.json"
bad_plan '.assignments[0].lists = []'
check "an assignment with no Lists is rejected" 'any(.[]; test("names no List"))' "$TMP/v-bad.json"

echo "# ops.jq"
jq -L "$JQ" --slurpfile stars "$TMP/stars.json" -f "$JQ/ops.jq" "$FIX/plan.fixture.json" >"$TMP/ops.json"
check "new Lists, and calls that need them, come last" '[.ops[].op] == ["unstar","create_list","set_lists","set_lists"]' "$TMP/ops.json"
check "create_list carries name, description, privacy, key" '(.ops[] | select(.op == "create_list")) == {"op":"create_list","key":"create:ai agents","name":"AI Agents","description":"Agent frameworks | tools","private":false}' "$TMP/ops.json"
check "assignment keeps current Lists and adds new ones" '(.ops[] | select(.repo == "boundary/at-cutoff")) | .key == "set:R_7" and .item_id == "R_7" and .before_ids == [] and .after == [{"id":"UL_2","name":"CLI Tools"},{"name":"AI Agents"}]' "$TMP/ops.json"
check "new-agent goes into the List the plan creates" '(.ops[] | select(.repo == "sample-labs/new-agent")).after == [{"name":"AI Agents"}]' "$TMP/ops.json"
check "an assignment already in place makes no call" '.unchanged == ["example-org/fast-parser"]' "$TMP/ops.json"
check "unstar records the original star time and Lists for undo" '(.ops[] | select(.op == "unstar")) == {"op":"unstar","key":"unstar:R_2","repo":"example-org/old-cli","item_id":"R_2","starred_at":"2022-05-01T00:00:00Z","list_ids":["UL_2"],"list_names":["CLI Tools"],"lists":{"UL_2":{"name":"CLI Tools","isPrivate":true}}}' "$TMP/ops.json"

echo "# render.jq / parse.jq / diff.jq"
jq -r -L "$JQ" -f "$JQ/render.jq" "$FIX/plan.fixture.json" >"$TMP/plan.md"
contains "pipes in cells are escaped" 'Agent frameworks \| tools' "$TMP/plan.md"
contains "several Lists are comma-separated" '| boundary/at-cutoff | CLI Tools, AI Agents | Shell CLI used by agents |' "$TMP/plan.md"
jq -R -s -L "$JQ" -f "$JQ/parse.jq" "$TMP/plan.md" >"$TMP/plan-roundtrip.json"
contains "assignments are grouped by List" "$(printf '| sample-labs/new-agent |')" "$TMP/plan.md"
if [ "$(grep -E '^\| (sample-labs/new-agent|boundary/at-cutoff|example-org/fast-parser) \|' "$TMP/plan.md" | cut -d'|' -f2 | tr -d ' ' | tr '\n' ' ')" = "sample-labs/new-agent boundary/at-cutoff example-org/fast-parser " ]; then
  ok "assignment rows are sorted by their first List"
else
  not_ok "assignment rows are sorted by their first List" "$(grep -E '^\| [a-z-]+/' "$TMP/plan.md")"
fi
# parse.jq always writes every section; the fixture omits the consolidation ones, and
# plan.md lists assignments by List rather than in the plan's order.
if jq -e -n --slurpfile a "$FIX/plan.fixture.json" --slurpfile b "$TMP/plan-roundtrip.json" '
    def by_list: .assignments |= sort_by((.lists[0] // "" | ascii_downcase), (.repo | ascii_downcase));
    (({renames: [], merges: [], deletions: []} + $a[0]) | by_list) == $b[0]' >/dev/null; then
  ok "render then parse returns the same plan"
else
  not_ok "render then parse returns the same plan" "$(diff <(jq -S . "$FIX/plan.fixture.json") <(jq -S . "$TMP/plan-roundtrip.json"))"
fi
# Simulate the user's edits: drop the unstar row, retarget one assignment, add a List.
awk '
  /^\| example-org\/old-cli \|/ { next }
  /^\| sample-labs\/new-agent \| AI Agents \|/ { sub(/\| AI Agents \|/, "| AI Agents, Parsers |") }
  /^\| AI Agents \| Agent frameworks/ { print "| Research | Papers and notes | yes | Asked for in chat |" }
  { print }
' "$TMP/plan.md" >"$TMP/plan-edited.md"
jq -R -s -L "$JQ" -f "$JQ/parse.jq" "$TMP/plan-edited.md" >"$TMP/plan-edited.json"
check "edited plan parses" '(.unstar == []) and (.lists_to_create | map(.name) == ["Research","AI Agents"]) and (.lists_to_create[0].private == true)' "$TMP/plan-edited.json"
jq -n -r -L "$JQ" --slurpfile a "$FIX/plan.fixture.json" --slurpfile b "$TMP/plan-edited.json" -f "$JQ/diff.jq" >"$TMP/diff.txt"
contains "diff summary counts" 'Plan changes: 1 added, 1 removed, 1 changed' "$TMP/diff.txt"
contains "diff shows the new List" '+ create List "Research"' "$TMP/diff.txt"
contains "diff shows the dropped unstar" '- unstar example-org/old-cli' "$TMP/diff.txt"
contains "diff shows the retargeted assignment" '~ assign sample-labs/new-agent: AI Agents -> AI Agents, Parsers' "$TMP/diff.txt"
jq -n -r -L "$JQ" --slurpfile a "$FIX/plan.fixture.json" --slurpfile b "$FIX/plan.fixture.json" -f "$JQ/diff.jq" >"$TMP/diff-none.txt"
contains "identical plans report no changes" 'Plan changes: none' "$TMP/diff-none.txt"
printf '## Unstar\n\n| Repo | Reason |\n|---|---|\n| only-one-cell |\n' >"$TMP/plan-broken.md"
jq -R -s -L "$JQ" -f "$JQ/parse.jq" "$TMP/plan-broken.md" >"$TMP/parse-broken.out" 2>&1
exits "a malformed row is an error" 5 $? "$TMP/parse-broken.out"
contains "the error quotes the row" 'only-one-cell' "$TMP/parse-broken.out"

echo "# plan.sh"
D=$(make_data_dir plan-sh)
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" render >"$TMP/plan-render.out" 2>&1
exits "plan.sh render succeeds" 0 $? "$TMP/plan-render.out"
check "render snapshots what the user saw" '.lists_to_create[0].name == "AI Agents"' "$D/plan.rendered.json"
sed -i.bak '/^| example-org\/old-cli |/d' "$D/plan.md" && rm -f "$D/plan.md.bak"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" parse >"$TMP/plan-parse.out" 2>&1
exits "plan.sh parse succeeds" 0 $? "$TMP/plan-parse.out"
contains "parse prints the diff summary" 'Plan changes: 0 added, 1 removed, 0 changed' "$TMP/plan-parse.out"
check "parse regenerates plan.json from the edits" '.unstar == []' "$D/plan.json"
check "parse moves the snapshot forward" '.unstar == []' "$D/plan.rendered.json"

echo "# dry-run.sh"
D=$(make_data_dir dry-run)
approve_categories "$D"
before=$(fingerprint "$D")
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/dry.out" 2>&1
exits "dry run succeeds" 0 $? "$TMP/dry.out"
contains "lists the List creation" 'graphql createUserList  name="AI Agents" private=false' "$TMP/dry.out"
contains "lists the assignment with current and new Lists" 'graphql updateUserListsForItem  boundary/at-cutoff  [] -> [CLI Tools, AI Agents]' "$TMP/dry.out"
contains "lists the unstar" 'REST DELETE /user/starred/example-org/old-cli' "$TMP/dry.out"
contains "counts every call" 'Write calls: 4 (1 createUserList, 0 updateUserList, 2 updateUserListsForItem, 1 unstar)' "$TMP/dry.out"
contains "reports assignments already in place" 'Already in place, no call: 1' "$TMP/dry.out"
contains "prints the approval hash" "Approval SHA-256: $(approval_hash "$D")" "$TMP/dry.out"
contains "prints the apply command with GH_TOKEN cleared" 'env -u GH_TOKEN -u GITHUB_TOKEN bash' "$TMP/dry.out"
contains "estimates the time" 'Time: at least about 1 minute' "$TMP/dry.out"
if [ "$before" = "$(fingerprint "$D")" ]; then ok "dry run changes no file in the data directory"; else not_ok "dry run changes no file in the data directory"; fi
jq '.unstar += [{"repo": "sample-labs/new-agent", "reason": "x"}]' "$FIX/plan.fixture.json" >"$D/plan.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/dry-bad.out" 2>&1
exits "dry run refuses an invalid plan" 1 $? "$TMP/dry-bad.out"
contains "and says why" 'sample-labs/new-agent is protected' "$TMP/dry-bad.out"

echo "# consolidation: validate.jq"
CPLAN="$FIX/plan-consolidate.fixture.json"
validate "$CPLAN" >"$TMP/vc-ok.json"
check "the consolidation plan is valid" '. == []' "$TMP/vc-ok.json"
cbad() { jq "$1" "$CPLAN" >"$TMP/cbad.json"; validate "$TMP/cbad.json" >"$TMP/vc-bad.json"; }
cbad '.renames[0].list = "Nope"'
check "renaming an unknown List is rejected" 'any(.[]; test("renames: List \"Nope\" does not exist"))' "$TMP/vc-bad.json"
cbad '.renames[0].to = "parsers"'
check "a rename onto an existing name is rejected" 'any(.[]; test("would collide"))' "$TMP/vc-bad.json"
cbad '.renames[0].to = "AI Agents"'
check "a rename onto a new List's name is rejected" 'any(.[]; test("would collide"))' "$TMP/vc-bad.json"
cbad '.renames += [{"list": "Parsing Libs", "to": "X", "description": null, "private": null, "reason": "r"}]'
check "renaming a List that is merged away is rejected" 'any(.[]; test("Parsing Libs\" is merged or deleted"))' "$TMP/vc-bad.json"
cbad '.merges[0].into = "Parsing Libs"'
check "merging a List into itself is rejected" 'any(.[]; test("into \"Parsing Libs\", which will not exist"))' "$TMP/vc-bad.json"
cbad '.merges[0].into = "CLI Tools"'
check "merging into a renamed-away name is rejected" 'any(.[]; test("into \"CLI Tools\", which will not exist"))' "$TMP/vc-bad.json"
cbad '.merges[0].into = "Command Line"'
check "merging into a rename's new name is accepted" '. == []' "$TMP/vc-bad.json"
cbad '.merges[0].into = "AI Agents"'
check "merging into a List the plan creates is accepted" '. == []' "$TMP/vc-bad.json"
cbad '.merges += [{"lists": ["Parsing Libs"], "into": "AI Agents", "reason": "r"}]'
check "merging one List twice is rejected" 'any(.[]; test("Parsing Libs\" is merged more than once"))' "$TMP/vc-bad.json"
cbad '.merges[0].lists = ["Ghost"]'
check "merging an unknown List is rejected" 'any(.[]; test("merges: List \"Ghost\" does not exist"))' "$TMP/vc-bad.json"
cbad '.deletions += [{"list": "Parsers", "reason": "r"}]'
check "deleting a List that keeps repos is rejected" 'any(.[]; test("Parsers\" still has 2 repos"))' "$TMP/vc-bad.json"
cbad '.assignments[1].lists = ["CLI Tools"]'
check "assigning to a renamed-away name is rejected" 'any(.[]; test("names List \"CLI Tools\", which will not exist after the plan"))' "$TMP/vc-bad.json"
cbad '.assignments[1].lists = ["Old Stuff"]'
check "assigning to a deleted List is rejected" 'any(.[]; test("names List \"Old Stuff\", which will not exist after the plan"))' "$TMP/vc-bad.json"
cbad '.merges[0].reason = ""'
check "a merge without a reason is rejected" 'any(.[]; test("merges: .* has no reason"))' "$TMP/vc-bad.json"

echo "# consolidation: ops.jq"
jq -L "$JQ" --slurpfile stars "$TMP/stars.json" -f "$JQ/ops.jq" "$CPLAN" >"$TMP/cops.json"
check "order: rename, moves to existing Lists, create, moves needing new Lists" '[.ops[].op] == ["rename_list","set_lists","set_lists","create_list","set_lists"]' "$TMP/cops.json"
check "the call needing a new List comes after its creation" '.ops[4].repo == "sample-labs/legacy-sdk"' "$TMP/cops.json"
check "rename keeps description and privacy when not given" '(.ops[] | select(.op == "rename_list")) == {"op":"rename_list","key":"rename:UL_2","list_id":"UL_2","from":"CLI Tools","to":"Command Line","description":"","private":true,"before":{"name":"CLI Tools","description":"","isPrivate":true},"requires":{"name":"CLI Tools","description":"","isPrivate":true},"expects":{"name":"Command Line","description":"","isPrivate":true}}' "$TMP/cops.json"
check "a merge drops the source and keeps the target once" '(.ops[] | select(.repo == "example-org/fast-parser")) | .before_ids == ["UL_1","UL_2","UL_3"] and .after == [{"id":"UL_1","name":"Parsers"},{"id":"UL_2","name":"Command Line"}]' "$TMP/cops.json"
check "a merge and an assignment become one call" '(.ops[] | select(.repo == "sample-labs/legacy-sdk")).after == [{"id":"UL_1","name":"Parsers"},{"name":"AI Agents"}]' "$TMP/cops.json"
check "assignments use final names" '(.ops[] | select(.repo == "boundary/at-cutoff")).after == [{"id":"UL_2","name":"Command Line"}]' "$TMP/cops.json"
check "a rename alone changes no membership" '[.ops[] | select(.repo == "example-org/old-cli")] == []' "$TMP/cops.json"
check "deletions are listed apart from the main calls" '.deletions == [{"op":"delete_list","list_id":"UL_3","name":"Parsing Libs","description":"Overlaps Parsers","private":false},{"op":"delete_list","list_id":"UL_4","name":"Old Stuff","description":"","private":false}]' "$TMP/cops.json"
check "List count after the plan" '.lists_after == 3' "$TMP/cops.json"

echo "# consolidation: render.jq / parse.jq / diff.jq"
jq -r -L "$JQ" -f "$JQ/render.jq" "$CPLAN" >"$TMP/cplan.md"
contains "renames table" '| CLI Tools | Command Line |  |  | Matches the other names |' "$TMP/cplan.md"
contains "merges table" '| Parsing Libs | Parsers | Duplicates Parsers |' "$TMP/cplan.md"
contains "deletions table" '| Old Stuff | Already empty |' "$TMP/cplan.md"
jq -R -s -L "$JQ" -f "$JQ/parse.jq" "$TMP/cplan.md" >"$TMP/cplan-rt.json"
if jq -e -n --slurpfile a "$CPLAN" --slurpfile b "$TMP/cplan-rt.json" '$a[0] == $b[0]' >/dev/null; then
  ok "consolidation plan survives render then parse"
else
  not_ok "consolidation plan survives render then parse" "$(diff <(jq -S . "$CPLAN") <(jq -S . "$TMP/cplan-rt.json"))"
fi
jq '.renames[0].to = "Terminal" | .merges = [] | .deletions = [.deletions[1]]' "$CPLAN" >"$TMP/cplan2.json"
jq -n -r -L "$JQ" --slurpfile a "$CPLAN" --slurpfile b "$TMP/cplan2.json" -f "$JQ/diff.jq" >"$TMP/cdiff.txt"
contains "diff shows a changed rename" '~ rename "CLI Tools": Command Line -> Terminal' "$TMP/cdiff.txt"
contains "diff shows a dropped merge" '- merge Parsing Libs into Parsers' "$TMP/cdiff.txt"
contains "diff shows a dropped deletion" '- delete List "Parsing Libs"' "$TMP/cdiff.txt"

echo "# consolidation: dry-run.sh"
D=$(make_data_dir dry-run-consolidate)
cp "$CPLAN" "$D/plan.json"
approve_categories "$D"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/cdry.out" 2>&1
exits "consolidation dry run succeeds" 0 $? "$TMP/cdry.out"
contains "lists the rename" 'graphql updateUserList  "CLI Tools" -> "Command Line"' "$TMP/cdry.out"
contains "lists the merge move" 'graphql updateUserListsForItem  example-org/fast-parser  [Parsers, CLI Tools, Parsing Libs] -> [Parsers, Command Line]' "$TMP/cdry.out"
contains "counts the main calls" 'Write calls: 5 (1 createUserList, 1 updateUserList, 3 updateUserListsForItem, 0 unstar)' "$TMP/cdry.out"
contains "lists deletions as a separate step" 'graphql deleteUserList  "Parsing Libs"' "$TMP/cdry.out"
contains "says deletions need their own confirmation" 'Deletions run later with delete-lists.sh' "$TMP/cdry.out"
contains "reports the List count against the target" 'Lists after this plan: 3 (now 4; target in rules.md: none)' "$TMP/cdry.out"

echo "# consolidation: deletable.jq"
jq '.[2].items = []' "$FIX/lists.raw.json" >"$TMP/lists-after-moves.json"
jq -L "$JQ" --slurpfile lists "$TMP/lists-after-moves.json" --slurpfile stars "$TMP/stars.json" -f "$JQ/deletable.jq" "$CPLAN" >"$TMP/del.json"
check "an emptied List and an empty List can be deleted" '.delete == [{"list_id":"UL_3","name":"Parsing Libs","description":"Overlaps Parsers","private":false},{"list_id":"UL_4","name":"Old Stuff","description":"","private":false}] and .skipped == []' "$TMP/del.json"
jq -L "$JQ" --slurpfile lists "$FIX/lists.raw.json" --slurpfile stars "$TMP/stars.json" -f "$JQ/deletable.jq" "$CPLAN" >"$TMP/del2.json"
check "a List that still has repos is skipped" '.delete == [{"list_id":"UL_4","name":"Old Stuff","description":"","private":false}] and .skipped == [{"list":"Parsing Libs","why":"still has 2 repos"}]' "$TMP/del2.json"
jq '[.[0], .[1], .[2]]' "$FIX/lists.raw.json" >"$TMP/lists-gone.json"
jq -L "$JQ" --slurpfile lists "$TMP/lists-gone.json" --slurpfile stars "$TMP/stars.json" -f "$JQ/deletable.jq" "$CPLAN" >"$TMP/del3.json"
check "a List already gone is skipped" '.skipped == [{"list":"Parsing Libs","why":"still has 2 repos"},{"list":"Old Stuff","why":"no longer exists"}]' "$TMP/del3.json"

echo "# category gate"
D=$(make_data_dir gate)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" categories >"$TMP/cat.out" 2>&1
exits "listing the category changes succeeds" 0 $? "$TMP/cat.out"
contains "lists a new List" '+ create List "AI Agents" (public): Agent frameworks' "$TMP/cat.out"
contains "lists a rename with size and visibility" '~ rename "CLI Tools" -> "Command Line" (2 repos, private, stays private)' "$TMP/cat.out"
contains "lists a merge with what moves" '> merge "Parsing Libs" (2 repos, public) into "Parsers" (public): 1 already there, 1 moves' "$TMP/cat.out"
contains "lists a deletion with its size" '- delete List "Old Stuff" (0 repos now, public); runs later, with its own approval' "$TMP/cat.out"
contains "shows each reason" '      Why: Duplicates Parsers' "$TMP/cat.out"
lacks "no private-to-public warning when nothing goes public" 'Private to public' "$TMP/cat.out"
contains "says they are not approved yet" 'Not approved yet.' "$TMP/cat.out"
csha=$(sed -n 's/^Categories SHA-256: //p' "$TMP/cat.out")
if [ ${#csha} -eq 64 ]; then ok "prints a categories hash"; else not_ok "prints a categories hash" "$(cat "$TMP/cat.out")"; fi
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/gate-dry.out" 2>&1
exits "dry run refuses unapproved category changes" 1 $? "$TMP/gate-dry.out"
contains "and says so" 'category changes have not been approved' "$TMP/gate-dry.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" approve-categories 0000 >"$TMP/gate-wrong.out" 2>&1
exits "approving with the wrong hash refuses" 1 $? "$TMP/gate-wrong.out"
if [ -e "$D/categories.approved.json" ]; then not_ok "a refused approval records nothing"; else ok "a refused approval records nothing"; fi
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" approve-categories "$csha" >"$TMP/gate-ok.out" 2>&1
exits "approving with the listed hash succeeds" 0 $? "$TMP/gate-ok.out"
check "the approval records the category changes" '.merges == [{"lists":["Parsing Libs"],"into":"Parsers"}] and (.lists_to_create[0] | has("reason") | not)' "$D/categories.approved.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" categories >"$TMP/cat2.out" 2>&1
contains "the listing reports the approval" 'Approved.' "$TMP/cat2.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/gate-dry2.out" 2>&1
exits "dry run accepts approved category changes" 0 $? "$TMP/gate-dry2.out"
jq '.merges[0].reason = "Reworded"' "$FIX/plan-consolidate.fixture.json" >"$D/plan.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/gate-dry3.out" 2>&1
exits "a reworded reason needs no new approval" 0 $? "$TMP/gate-dry3.out"
jq '.merges[0].into = "Command Line"' "$FIX/plan-consolidate.fixture.json" >"$D/plan.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/gate-dry4.out" 2>&1
exits "a changed merge needs a new approval" 1 $? "$TMP/gate-dry4.out"
contains "and says the changes differ" 'differ from the ones approved' "$TMP/gate-dry4.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/apply.sh" --approved "$(approval_hash "$D")" >"$TMP/gate-apply.out" 2>&1
exits "apply refuses category changes that differ from the approval" 1 $? "$TMP/gate-apply.out"
contains "apply says why" 'differ from the ones approved' "$TMP/gate-apply.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/delete-lists.sh" >"$TMP/gate-del.out" 2>&1
exits "delete-lists refuses too" 1 $? "$TMP/gate-del.out"
if find "$D" -name 'changes-*.jsonl' | grep -q .; then not_ok "refused runs write no change log"; else ok "refused runs write no change log"; fi
D=$(make_data_dir gate-none)
jq '.lists_to_create = [] | .assignments |= map(select(.lists | index(["AI Agents"]) | not))' "$FIX/plan.fixture.json" >"$D/plan.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" categories >"$TMP/cat-none.out" 2>&1
contains "a plan with no category changes says so" 'No category changes in this plan.' "$TMP/cat-none.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/gate-none.out" 2>&1
exits "a plan with no category changes needs no approval" 0 $? "$TMP/gate-none.out"

echo "# apply.sh guards (all must stop before any network call)"
D=$(make_data_dir apply)
STAR_CHART_DIR="$D" bash "$SCRIPTS/apply.sh" >"$TMP/apply-none.out" 2>&1
exits "apply without --approved refuses" 1 $? "$TMP/apply-none.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/apply.sh" --approved 0000 >"$TMP/apply-wrong.out" 2>&1
exits "apply with the wrong hash refuses" 1 $? "$TMP/apply-wrong.out"
contains "and says the plan changed" 'do not match the approved hash' "$TMP/apply-wrong.out"
jq '.unstar += [{"repo": "keepers/forever-tool", "reason": "x"}]' "$FIX/plan.fixture.json" >"$D/plan.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/apply.sh" --approved "$(approval_hash "$D")" >"$TMP/apply-prot.out" 2>&1
exits "apply refuses a protected unstar even with a matching hash" 1 $? "$TMP/apply-prot.out"
contains "and names the guard" 'keepers/forever-tool is protected (keep-always pattern)' "$TMP/apply-prot.out"
if find "$D" -name 'changes-*.jsonl' | grep -q .; then not_ok "refused applies write no change log"; else ok "refused applies write no change log"; fi

echo "# apply.sh end to end (tests/bin/gh stands in for GitHub)"
# make_stub <name> : a stub directory serving the fixture Lists.
make_stub() {
  local s="$TMP/stub-$1"
  mkdir -p "$s"
  cp "$FIX/lists.raw.json" "$s/lists.json"
  : >"$s/calls"
  printf '%s' "$s"
}
# run_apply <data dir> <stub dir> <output file> : apply with the dry run's hash.
run_apply() {
  local sha
  sha=$(approval_hash "$1")
  STAR_CHART_DIR="$1" STUB_DIR="$2" PATH="$HERE/bin:$PATH" \
    bash "$SCRIPTS/apply.sh" --approved "$sha" >"$3" 2>&1
}
D=$(make_data_dir e2e)
S=$(make_stub e2e)
approve_categories "$D"
run_apply "$D" "$S" "$TMP/e2e.out"
exits "apply completes" 0 $? "$TMP/e2e.out"
lacks "logging works on the shell that runs it" 'invalid JSON' "$TMP/e2e.out"
cat "$D"/changes-*.jsonl | jq -s --argjson calls "$(wc -l <"$S/calls")" \
  '{calls: $calls, started: map(select(.status == "started")) | length, ok: map(select(.status == "ok")) | length}' >"$TMP/e2e-log.json"
check "every call is logged as started, then ok" '.calls > 0 and .started == .calls and .ok == .calls' "$TMP/e2e-log.json"
contains "the summary counts the changes" "Done: $(jq .ok "$TMP/e2e-log.json") changed, 0 failed" "$TMP/e2e.out"
check "a fully applied plan moves the baseline" '.applied_export_at == "2026-06-15T00:00:00Z"' "$D/state.json"

D=$(make_data_dir e2e-refused)
S=$(make_stub e2e-refused)
echo 403 >"$S/status"
approve_categories "$D"
run_apply "$D" "$S" "$TMP/e2e-refused.out"
exits "apply exits 2 when GitHub refuses its calls" 2 $? "$TMP/e2e-refused.out"
contains "and counts them as failed" 'Done: 0 changed, ' "$TMP/e2e-refused.out"
lacks "and does not report zero failures" ' 0 failed' "$TMP/e2e-refused.out"
contains "and says how to retry" 'Retry the failed calls' "$TMP/e2e-refused.out"
if [ -e "$D/state.json" ]; then not_ok "a partly failed apply keeps the baseline"; else ok "a partly failed apply keeps the baseline"; fi

# A merge approved while its source List was public; the source turns private
# before apply. The assignment out of that List is left out, so only the
# merge publishes it.
D=$(make_data_dir e2e-private)
S=$(make_stub e2e-private)
jq '.assignments |= map(select(.repo != "sample-labs/legacy-sdk"))' "$FIX/plan-consolidate.fixture.json" >"$D/plan.json"
approve_categories "$D"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/e2e-private-dry.out" 2>&1
exits "the dry run accepts the merge while its source is public" 0 $? "$TMP/e2e-private-dry.out"
jq 'map(if .id == "UL_3" then .isPrivate = true else . end)' "$FIX/lists.raw.json" >"$S/lists.json"
run_apply "$D" "$S" "$TMP/e2e-private.out"
exits "apply refuses a merge that now publishes a private List" 1 $? "$TMP/e2e-private.out"
contains "and names the List" '"Parsing Libs" is private; it must be "Parsing Libs", public' "$TMP/e2e-private.out"
if [ -s "$S/calls" ]; then not_ok "a refused apply makes no call" "$(cat "$S/calls")"; else ok "a refused apply makes no call"; fi

# boundary/at-cutoff is in no List and approved for private "CLI Tools";
# that List turns public before apply.
D=$(make_data_dir e2e-visibility)
S=$(make_stub e2e-visibility)
approve_categories "$D"
jq 'map(if .id == "UL_2" then .isPrivate = false else . end)' "$FIX/lists.raw.json" >"$S/lists.json"
run_apply "$D" "$S" "$TMP/e2e-visibility.out"
exits "apply refuses when a List it writes to changed visibility" 1 $? "$TMP/e2e-visibility.out"
contains "and names the List" '"CLI Tools" is public; it must be "CLI Tools", private' "$TMP/e2e-visibility.out"
if [ -s "$S/calls" ]; then not_ok "and makes no call" "$(cat "$S/calls")"; else ok "and makes no call"; fi

# During the rename (call 1), boundary/at-cutoff is added to "Parsers" on
# another device. Its approved call adds only "Command Line" and keeps that.
D=$(make_data_dir e2e-midrun)
S=$(make_stub e2e-midrun)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
echo 'map(if .id == "UL_1" then .items += [{"id":"R_7","nameWithOwner":"boundary/at-cutoff"}] else . end)' >"$S/change-1"
run_apply "$D" "$S" "$TMP/e2e-midrun.out"
exits "a run with an edit made elsewhere mid-run completes" 0 $? "$TMP/e2e-midrun.out"
contains "and keeps that edit" '{"itemId":"R_7","listIds":["UL_1","UL_2"]}' "$S/calls"

# During the rename, "Parsers" is deleted and a new public "Parsers" takes its
# name. Calls that write to it are refused; the others are made.
D=$(make_data_dir e2e-swap)
S=$(make_stub e2e-swap)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
echo 'map(if .id == "UL_1" then .id = "UL_11" else . end)' >"$S/change-1"
run_apply "$D" "$S" "$TMP/e2e-swap.out"
exits "a List replaced mid-run leaves the plan unfinished" 2 $? "$TMP/e2e-swap.out"
lacks "and nothing is written to the replacement" 'UL_11' "$S/calls"
contains "the refusal says why" 'REFUSED example-org/fast-parser -> Parsers, Command Line: List "Parsers" no longer exists' "$TMP/e2e-swap.out"
contains "calls that do not touch it are still made" '{"itemId":"R_7","listIds":["UL_2"]}' "$S/calls"
if [ -e "$D/state.json" ]; then not_ok "a refused call keeps the baseline"; else ok "a refused call keeps the baseline"; fi

# old-cli is re-starred after the dry run, so protection refuses its unstar.
D=$(make_data_dir e2e-protect)
S=$(make_stub e2e-protect)
approve_categories "$D"
printf '[{"starred_at":"2026-06-14T00:00:00Z","repo":{"full_name":"example-org/old-cli"}}]' >"$S/recent.json"
run_apply "$D" "$S" "$TMP/e2e-protect.out"
exits "a refused unstar leaves the plan unfinished" 2 $? "$TMP/e2e-protect.out"
contains "and says so" 'REFUSED unstar example-org/old-cli: starred within the last 90 days' "$TMP/e2e-protect.out"
lacks "and does not suggest a new export as if done" 'Then export again' "$TMP/e2e-protect.out"

# A create whose outcome was never recorded (the run stopped mid-call), and a
# List of that name now. It may be the one that run made, or someone else's:
# the re-run cannot tell, so it refuses rather than write to it.
D=$(make_data_dir e2e-adopt)
S=$(make_stub e2e-adopt)
approve_categories "$D"
h=$(approval_hash "$D")
printf '{"ts":"2026-06-15T01:00:00Z","run_id":"R0","login":"example-user","plan_hash":"%s","op_key":"create:ai agents","op":"create_list","status":"started","name":"AI Agents","description":"Agent frameworks | tools","private":false}\n' "$h" >"$D/changes-2026-06-15.jsonl"
jq '. + [{"id":"UL_AI","name":"AI Agents","description":"Agent frameworks | tools","isPrivate":false,"items":[]}]' "$FIX/lists.raw.json" >"$S/lists.json"
run_apply "$D" "$S" "$TMP/e2e-adopt.out"
exits "a re-run does not take up a same-name List an interrupted run may have made" 1 $? "$TMP/e2e-adopt.out"
if [ -s "$S/calls" ]; then not_ok "and changes nothing" "$(cat "$S/calls")"; else ok "and changes nothing"; fi
contains "and says what to do" 'export again' "$TMP/e2e-adopt.out"

# The same approval run again after it finished: every call is skipped.
D=$(make_data_dir e2e-rerun)
S=$(make_stub e2e-rerun)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
run_apply "$D" "$S" "$TMP/e2e-rerun1.out"
exits "a full run completes" 0 $? "$TMP/e2e-rerun1.out"
: >"$S/calls"
run_apply "$D" "$S" "$TMP/e2e-rerun2.out"
exits "running it again completes too" 0 $? "$TMP/e2e-rerun2.out"
if [ -s "$S/calls" ]; then not_ok "and makes no call" "$(cat "$S/calls")"; else ok "and makes no call"; fi

# After that run, the user adds sample-labs/legacy-sdk to "Old Stuff". Undo
# reverses only the run's own changes and keeps that.
echo 'map(if .id == "UL_4" then .items += [{"id":"R_3","nameWithOwner":"sample-labs/legacy-sdk"}] else . end)' >"$S/edit.jq"
jq -f "$S/edit.jq" "$S/lists.json" >"$S/lists.tmp" && mv "$S/lists.tmp" "$S/lists.json"
urun=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --list-runs | head -n 1 | cut -d' ' -f1)
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --run "$urun" >"$TMP/e2e-undo.out" 2>&1
usha=$(sed -n 's/^Undo SHA-256: //p' "$TMP/e2e-undo.out")
STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH" \
  bash "$SCRIPTS/undo.sh" --run "$urun" --approved "$usha" >"$TMP/e2e-undo-run.out" 2>&1
exits "undoing the run completes" 0 $? "$TMP/e2e-undo-run.out"
check "every List is back as it was, plus the user's own edit" \
  'map({id, name, isPrivate, items: [.items[].id] | sort}) | sort_by(.id) == [
     {"id":"UL_1","name":"Parsers","isPrivate":false,"items":["R_1","R_9"]},
     {"id":"UL_2","name":"CLI Tools","isPrivate":true,"items":["R_1","R_2"]},
     {"id":"UL_3","name":"Parsing Libs","isPrivate":false,"items":["R_1","R_3"]},
     {"id":"UL_4","name":"Old Stuff","isPrivate":false,"items":["R_3"]},
     {"id":"UL_NEW_AI Agents","name":"AI Agents","isPrivate":false,"items":[]}]' "$S/lists.json"

D=$(make_data_dir reexport-private)
cp "$TMP/e2e-private/plan.json" "$D/plan.json"
approve_categories "$D"
jq '.lists |= map(if .id == "UL_3" then .isPrivate = true else . end)' "$D/stars.json" >"$D/s.tmp" && mv "$D/s.tmp" "$D/stars.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/reexport-private.out" 2>&1
exits "the dry run refuses a private-to-public change the approval did not acknowledge" 1 $? "$TMP/reexport-private.out"
contains "and says to approve again" 'get a new approval' "$TMP/reexport-private.out"
rsha=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" categories | sed -n 's/^Categories SHA-256: //p')
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" approve-categories "$rsha" --publishes-private >/dev/null 2>&1
check "the new approval records what the user acknowledged" '.acknowledged_exposure == [{"into":"parsers","kind":"merge","list":"parsing libs"}]' "$D/categories.approved.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/reexport-private2.out" 2>&1
exits "once acknowledged, the dry run accepts it" 0 $? "$TMP/reexport-private2.out"

echo "# apply-step.jq: each approved call held to its contract"
# The consolidation plan's calls: rename UL_2 "CLI Tools" -> "Command Line"
# (stays private); R_1 [UL_1, UL_2, UL_3] -> [UL_1, UL_2] (merge out of
# UL_3); R_7 [] -> [UL_2]; create "AI Agents"; R_3 [UL_3] -> [UL_1, new
# "AI Agents"]. Each call carries "requires": the state every List it names
# must be in. A List a repo ends up in must be in its final approved state;
# a List a repo leaves must be as approved, or gone.
jq -L "$JQ" --slurpfile stars "$TMP/stars.json" -f "$JQ/ops.jq" "$FIX/plan-consolidate.fixture.json" >"$TMP/m-ops.json"
# now <name> <jq filter on the fixture Lists> : the Lists as they are now.
now() { jq "$2" "$FIX/lists.raw.json" >"$TMP/now-$1.json"; printf '%s' "$TMP/now-$1.json"; }
# step <name> <op key> <now file> <jq check> [created] [attempted] [preflight]
# The calls come from $STEP_OPS (default: the consolidation plan's).
step() {
  local created='{}' attempted='[]' preflight=false ops=${STEP_OPS:-$TMP/m-ops.json}
  [ -n "${5:-}" ] && created=$5
  [ -n "${6:-}" ] && attempted=$6
  [ -n "${7:-}" ] && preflight=$7
  jq -n -c -L "$JQ" --argjson op "$(jq -c --arg k "$2" '.ops[] | select(.key == $k)' "$ops")" \
    --slurpfile approved "$ops" --slurpfile now "$3" --argjson created "$created" \
    --argjson attempted "$attempted" --argjson preflight "$preflight" -f "$JQ/apply-step.jq" >"$TMP/step.json" 2>&1
  check "$1" "$4" "$TMP/step.json"
}
REN='map(if .id == "UL_2" then .name = "Command Line" else . end)'
asis=$(now asis '.')
renamed=$(now renamed "$REN")
check "the approval records every List as it was" '.snapshot == [{"id":"UL_1","name":"Parsers","isPrivate":false},{"id":"UL_2","name":"CLI Tools","isPrivate":true},{"id":"UL_3","name":"Parsing Libs","isPrivate":false},{"id":"UL_4","name":"Old Stuff","isPrivate":false}]' "$TMP/m-ops.json"
check "each membership call carries its contract" '(.ops[] | select(.key == "set:R_3")).requires == [{"id":"UL_1","name":"Parsers","isPrivate":false},{"create":"create:ai agents","name":"AI Agents","isPrivate":false},{"id":"UL_3","name":"Parsing Libs","isPrivate":false,"may_be_gone":true}]' "$TMP/m-ops.json"
check "a rename carries what it needs and what it leaves" '(.ops[] | select(.key == "rename:UL_2")) | .requires == {"name":"CLI Tools","description":"","isPrivate":true} and .expects == {"name":"Command Line","description":"","isPrivate":true}' "$TMP/m-ops.json"

step "rename: as approved, the call is made" rename:UL_2 "$asis" '.action == "call" and .variables == {"listId":"UL_2","name":"Command Line","description":"","isPrivate":true}'
step "rename: already renamed, nothing to do" rename:UL_2 "$renamed" '.action == "done"'
step "rename: renamed by someone else, refused" rename:UL_2 "$(now ren-other 'map(if .id == "UL_2" then .name = "Shell Tools" else . end)')" '.action == "refuse" and (.reason | test("\"Shell Tools\" is private; it must be \"CLI Tools\", private"))'
step "rename: List deleted, refused" rename:UL_2 "$(now ren-gone 'map(select(.id != "UL_2"))')" '.action == "refuse" and (.reason | test("\"CLI Tools\" no longer exists"))'
step "rename: List made public, refused" rename:UL_2 "$(now ren-pub 'map(if .id == "UL_2" then .isPrivate = false else . end)')" '.action == "refuse" and (.reason | test("is public; it must be \"CLI Tools\", private"))'
step "rename: description edited elsewhere, refused" rename:UL_2 "$(now ren-desc 'map(if .id == "UL_2" then .description = "mine" else . end)')" '.action == "refuse" and (.reason | test("description"))'
jq '.renames = [{"list": "Old Stuff", "to": "Old Stuff", "description": "Kept for later", "private": null, "reason": "r"}] | .assignments = []' "$FIX/plan-consolidate.fixture.json" >"$TMP/plan-desc.json"
jq -L "$JQ" --slurpfile stars "$TMP/stars.json" -f "$JQ/ops.jq" "$TMP/plan-desc.json" >"$TMP/m-ops-desc.json"
STEP_OPS="$TMP/m-ops-desc.json" step "rename: a description-only change is made" rename:UL_4 "$asis" '.action == "call" and .variables.description == "Kept for later"'
STEP_OPS="$TMP/m-ops-desc.json" step "rename: and is done once the description matches" rename:UL_4 "$(now desc-done 'map(if .id == "UL_4" then .description = "Kept for later" else . end)')" '.action == "done"'

step "membership: as approved, only the approved change" set:R_1 "$renamed" '.action == "call" and .variables == {"itemId":"R_1","listIds":["UL_1","UL_2"]} and .before_ids == ["UL_1","UL_2","UL_3"]'
step "membership: a List it stays in, not yet renamed by this plan, refused" set:R_1 "$asis" '.action == "refuse" and (.reason | test("\"CLI Tools\" is private; it must be \"Command Line\", private"))'
step "membership: the same, before any call (preflight), is accepted" set:R_1 "$asis" '.action == "call"' '' '' true
step "membership: merged-away List already deleted, nothing to do" set:R_1 "$(now set-del3 "$REN"' | map(select(.id != "UL_3"))')" '.action == "done"'
step "membership: a List added since is kept" set:R_1 "$(now set-add4 "$REN"' | map(if .id == "UL_4" then .items += [{"id":"R_1","nameWithOwner":"x"}] else . end)')" '.action == "call" and .variables.listIds == ["UL_1","UL_2","UL_4"]'
step "membership: a List removed since stays removed" set:R_1 "$(now set-rm1 "$REN"' | map(if .id == "UL_1" then .items |= map(select(.id != "R_1")) else . end)')" '.action == "call" and .variables.listIds == ["UL_2"]'
step "membership: a List replaced by another of the same name, refused" set:R_1 "$(now set-repl1 "$REN"' | map(if .id == "UL_1" then .id = "UL_11" else . end)')" '.action == "refuse" and (.reason | test("\"Parsers\" no longer exists"))'
step "membership: a merged-away List made private, refused" set:R_1 "$(now set-priv3 "$REN"' | map(if .id == "UL_3" then .isPrivate = true else . end)')" '.action == "refuse" and (.reason | test("\"Parsing Libs\" is private; it must be \"Parsing Libs\", public"))'
step "membership: a private target replaced by a public one of the same name, refused" set:R_7 "$(now set-repl2 "$REN"' | map(if .id == "UL_2" then .id = "UL_22" | .isPrivate = false else . end)')" '.action == "refuse" and .variables == null'
step "membership: a private target made public, refused" set:R_7 "$(now set-pub2 "$REN"' | map(if .id == "UL_2" then .isPrivate = false else . end)')" '.action == "refuse" and (.reason | test("is public; it must be \"Command Line\", private"))'
step "membership: a List the plan creates, not created yet, refused" set:R_3 "$renamed" '.action == "refuse" and (.reason | test("\"AI Agents\" was not created"))'
step "membership: the same, before any call (preflight), is accepted" set:R_3 "$asis" '.action == "call"' '' '' true
withnew=$(now set-new "$REN"' | . + [{"id":"UL_NEW","name":"AI Agents","description":"","isPrivate":false,"items":[]}]')
step "membership: a created List is found through the plan's own log" set:R_3 "$withnew" '.action == "call" and .variables.listIds == ["UL_1","UL_NEW"]' '{"create:ai agents":"UL_NEW"}'
step "membership: a created List deleted since, refused" set:R_3 "$renamed" '.action == "refuse" and (.reason | test("\"AI Agents\" no longer exists"))' '{"create:ai agents":"UL_NEW"}'
step "membership: a created List made private since, refused" set:R_3 "$(now set-newpriv2 "$REN"' | . + [{"id":"UL_NEW","name":"AI Agents","description":"","isPrivate":true,"items":[]}]')" '.action == "refuse" and (.reason | test("is private; it must be \"AI Agents\", public"))' '{"create:ai agents":"UL_NEW"}'
# A plan whose rename also makes "CLI Tools" public: R_7 goes into it only
# once it is public, never while the rename has not happened or failed.
jq '.renames[0].private = false' "$FIX/plan-consolidate.fixture.json" >"$TMP/plan-pub.json"
jq -L "$JQ" --slurpfile stars "$TMP/stars.json" -f "$JQ/ops.jq" "$TMP/plan-pub.json" >"$TMP/m-ops-pub.json"
STEP_OPS="$TMP/m-ops-pub.json" step "membership: a target whose rename has not happened, refused" set:R_7 "$asis" '.action == "refuse" and (.reason | test("it must be \"Command Line\", public"))'
STEP_OPS="$TMP/m-ops-pub.json" step "membership: a target renamed but not made public, refused" set:R_7 "$renamed" '.action == "refuse"'
STEP_OPS="$TMP/m-ops-pub.json" step "membership: a target in its final approved state, accepted" set:R_7 "$(now pub-done "$REN"' | map(if .id == "UL_2" then .isPrivate = false else . end)')" '.action == "call"'

# plan.fixture: sample-labs/new-agent (R_4) is in no List and goes into new,
# public "AI Agents". If it is put into a private List before the call, it is
# a repo only in private Lists going public: that needs plan.sh allow-public.
jq -L "$JQ" --slurpfile stars "$TMP/stars.json" -f "$JQ/ops.jq" "$FIX/plan.fixture.json" >"$TMP/m-ops-assign.json"
privnew=$(now priv-new '. + [{"id":"UL_NEW","name":"AI Agents","description":"","isPrivate":false,"items":[]}] | map(if .id == "UL_2" then .items += [{"id":"R_4","nameWithOwner":"x"}] else . end)')
STEP_OPS="$TMP/m-ops-assign.json" step "membership: a repo only in private Lists now does not go public unacknowledged" set:R_4 "$privnew" '.action == "refuse" and (.reason | test("only in private Lists"))' '{"create:ai agents":"UL_NEW"}'
jq '.publish_private = ["sample-labs/new-agent"]' "$FIX/plan.fixture.json" >"$TMP/plan-ack.json"
jq -L "$JQ" --slurpfile stars "$TMP/stars.json" -f "$JQ/ops.jq" "$TMP/plan-ack.json" >"$TMP/m-ops-ack.json"
STEP_OPS="$TMP/m-ops-ack.json" step "membership: it does once acknowledged" set:R_4 "$privnew" '.action == "call"' '{"create:ai agents":"UL_NEW"}'

step "create: no such List, the call is made" "create:ai agents" "$asis" '.action == "call" and .variables == {"name":"AI Agents","description":"Agent frameworks","isPrivate":false}'
step "create: created earlier by this plan, nothing to do" "create:ai agents" "$withnew" '.action == "done" and .list_id == "UL_NEW"' '{"create:ai agents":"UL_NEW"}'
step "create: someone else's List has the name, refused" "create:ai agents" "$withnew" '.action == "refuse" and (.reason | test("already exists"))'
step "create: right after this plan's own uncertain attempt, the List is taken up" "create:ai agents" "$withnew" '.action == "done" and .list_id == "UL_NEW" and .adopted' '' '["create:ai agents"]'
step "create: not if its visibility differs" "create:ai agents" "$(now set-newpriv '. + [{"id":"UL_NEW","name":"AI Agents","description":"","isPrivate":true,"items":[]}]')" '.action == "refuse"' '' '["create:ai agents"]'
step "create: not if it existed at approval" "create:ai agents" "$(now set-newold 'map(if .id == "UL_4" then .name = "AI Agents" else . end)')" '.action == "refuse"' '' '["create:ai agents"]'

echo "# undo-step.jq: each reversal held to the state the run left"
# ustep <name> <step JSON> <now file> <jq check> [remap] [attempted]
# ustep <name> <step JSON> <now file> <jq check> [remap] [attempted] [restored]
ustep() {
  local remap='{}' attempted='[]' restored='{}'
  [ -n "${5:-}" ] && remap=$5
  [ -n "${6:-}" ] && attempted=$6
  [ -n "${7:-}" ] && restored=$7
  jq -n -c -L "$JQ" --argjson step "$2" --slurpfile now "$3" --argjson remap "$remap" \
    --argjson attempted "$attempted" --argjson restored "$restored" -f "$JQ/undo-step.jq" >"$TMP/ustep.json" 2>&1
  check "$1" "$4" "$TMP/ustep.json"
}
# A run moved R_1 out of UL_3 and into UL_4; undo moves it back. "add" carries
# the state each List was in when the run removed the repo from it.
USET='{"op":"set_lists","repo":"example-org/fast-parser","item_id":"R_1","add":[{"id":"UL_3","name":"Parsing Libs","isPrivate":false}],"remove":[{"id":"UL_4","name":"Old Stuff","isPrivate":false}],"undoes":"R/set:R_1"}'
MOVED='map(if .id == "UL_3" then .items |= map(select(.id != "R_1")) elif .id == "UL_4" then .items += [{"id":"R_1","nameWithOwner":"x"}] else . end)'
ustep "undo membership: the run's change is reversed" "$USET" "$(now u-set "$MOVED")" '.action == "call" and .variables == {"itemId":"R_1","listIds":["UL_1","UL_2","UL_3"]}'
ustep "undo membership: already as before, nothing to do" "$USET" "$asis" '.action == "done"'
ustep "undo membership: a List to restore is gone, refused" "$USET" "$(now u-gone "$MOVED"' | map(select(.id != "UL_3"))')" '.action == "refuse" and (.reason | test("\"Parsing Libs\" no longer exists"))'
ustep "undo membership: a List to restore made private since, refused" "$USET" "$(now u-priv "$MOVED"' | map(if .id == "UL_3" then .isPrivate = true else . end)')" '.action == "refuse" and (.reason | test("is private; it must be \"Parsing Libs\", public"))'
ustep "undo membership: a recreated List is used, following every recreation" "$USET" "$(now u-remap "$MOVED"' | map(if .id == "UL_3" then .id = "UL_31" else . end)')" '.action == "call" and (.variables.listIds | index("UL_31") != null)' '{"UL_3":"UL_30","UL_30":"UL_31"}'
ustep "undo membership: a List with no recorded state, refused" '{"op":"set_lists","repo":"r","item_id":"R_1","add":[{"id":"UL_3","unrecorded":true}],"remove":[],"undoes":"R/x"}' "$(now u-unrec "$MOVED")" '.action == "refuse" and (.reason | test("does not record"))'
ustep "undo membership: a List to remove the repo from changed since, refused" "$USET" "$(now u-rmchg "$MOVED"' | map(if .id == "UL_4" then .name = "Junk" else . end)')" '.action == "refuse" and (.reason | test("\"Junk\" is public; it must be \"Old Stuff\", public"))'
ustep "undo membership: a List to remove the repo from that is gone is fine" "$USET" "$(now u-rmgone 'map(if .id == "UL_3" then .items |= map(select(.id != "R_1")) else . end) | map(select(.id != "UL_4"))')" '.action == "call" and .variables.listIds == ["UL_1","UL_2","UL_3"]'
ustep "undo membership: a List an undo already renamed back is accepted as it left it" '{"op":"set_lists","repo":"r","item_id":"R_7","add":[],"remove":[{"id":"UL_2","name":"Command Line","isPrivate":true}],"undoes":"R/set:R_7"}' "$(now u-restored 'map(if .id == "UL_2" then .items += [{"id":"R_7","nameWithOwner":"x"}] else . end)')" '.action == "call" and (.variables.listIds | index("UL_2") == null)' '' '' '{"UL_2":{"name":"CLI Tools","description":"","isPrivate":true}}'
ustep "undo membership: but not a state no undo restored" '{"op":"set_lists","repo":"r","item_id":"R_7","add":[],"remove":[{"id":"UL_2","name":"Command Line","isPrivate":true}],"undoes":"R/set:R_7"}' "$(now u-notrestored 'map(if .id == "UL_2" then .name = "Shell" | .items += [{"id":"R_7","nameWithOwner":"x"}] else . end)')" '.action == "refuse"' '' '' '{"UL_2":{"name":"CLI Tools","description":"","isPrivate":true}}'
UREN='{"op":"rename_back","list_id":"UL_2","requires":{"name":"Command Line","description":"","isPrivate":true},"expects":{"name":"CLI Tools","description":"","isPrivate":true},"undoes":"R/rename:UL_2"}'
ustep "undo rename: renamed back" "$UREN" "$renamed" '.action == "call" and .variables == {"listId":"UL_2","name":"CLI Tools","description":"","isPrivate":true}'
ustep "undo rename: already back, nothing to do" "$UREN" "$asis" '.action == "done"'
ustep "undo rename: renamed again since, refused" "$UREN" "$(now u-ren2 'map(if .id == "UL_2" then .name = "Shell" else . end)')" '.action == "refuse" and (.reason | test("it must be \"Command Line\", private"))'
ustep "undo rename: description edited since, refused" "$UREN" "$(now u-ren4 "$REN"' | map(if .id == "UL_2" then .description = "mine" else . end)')" '.action == "refuse"'
ustep "undo rename: a recreated List is renamed under its new id" "$UREN" "$(now u-ren3 "$REN"' | map(if .id == "UL_2" then .id = "UL_20" else . end)')" '.variables.listId == "UL_20"' '{"UL_2":"UL_20"}'
UREC='{"op":"recreate_list","old_id":"UL_3","name":"Parsing Libs","description":"Overlaps Parsers","private":false,"undoes":"D1/delete:UL_3"}'
GONE3=$(now u-gone3 'map(select(.id != "UL_3"))')
ustep "undo deletion: recreated" "$UREC" "$GONE3" '.action == "call" and .variables == {"name":"Parsing Libs","description":"Overlaps Parsers","isPrivate":false}'
ustep "undo deletion: already recreated, nothing to do" "$UREC" "$(now u-rec 'map(if .id == "UL_3" then .id = "UL_30" else . end)')" '.action == "done" and .new_id == "UL_30"' '{"UL_3":"UL_30"}'
ustep "undo deletion: another List has the name, refused" "$UREC" "$(now u-rec2 'map(if .id == "UL_3" then .id = "UL_99" else . end)')" '.action == "refuse" and (.reason | test("already exists"))'
ustep "undo deletion: right after the undo's own uncertain attempt, the List is taken up" "$UREC" "$(now u-rec3 'map(if .id == "UL_3" then .id = "UL_99" else . end)')" '.action == "done" and .new_id == "UL_99" and .adopted' '' '["D1/delete:UL_3"]'

echo "# undo.sh (listing only)"
D=$(make_data_dir undo)
cp "$FIX/changes.fixture.jsonl" "$D/changes-2026-06-15.jsonl"
before=$(fingerprint "$D")
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" "$D/changes-2026-06-15.jsonl" >"$TMP/undo.out" 2>&1
exits "undo listing succeeds" 0 $? "$TMP/undo.out"
grep -E '^  (REST|graphql|kept)' "$TMP/undo.out" >"$TMP/undo-calls.txt"
expected=$(cat <<'EOF'
  graphql createUserList  name="Parsing Libs" private=false  (recreates deleted List UL_3)
  graphql updateUserListsForItem  boundary/protect-edge  remove ["Command Line" (UL_2)]
  REST PUT /user/starred/keepers/forever-tool  (outcome unknown; repeating it is harmless)
  REST PUT /user/starred/example-org/old-cli
  graphql updateUserListsForItem  example-org/old-cli  add ["Command Line" (UL_2)]
  graphql updateUserListsForItem  sample-labs/new-agent  remove ["AI Agents" (UL_9)]
  graphql updateUserListsForItem  example-org/fast-parser  add ["Parsing Libs" (recreated UL_3)]
  graphql updateUserList  UL_2  name="CLI Tools" private=true
  kept: List "AI Agents" (UL_9), created by run R1
EOF
)
if [ "$(cat "$TMP/undo-calls.txt")" = "$expected" ]; then ok "undo reverses successful and uncertain changes, newest first"
else not_ok "undo reverses successful and uncertain changes, newest first" "$(diff <(printf '%s\n' "$expected") "$TMP/undo-calls.txt")"; fi
lacks "failed changes are not undone" 'boundary/at-cutoff' "$TMP/undo-calls.txt"
lacks "refused changes are not undone" 'REST PUT /user/starred/sample-labs/new-agent' "$TMP/undo-calls.txt"
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" "$D/changes-2026-06-15.jsonl" --run R1 >"$TMP/undo-r1.out" 2>&1
lacks "--run limits undo to one run" 'boundary/protect-edge' "$TMP/undo-r1.out"
contains "--run keeps that run's changes" 'REST PUT /user/starred/example-org/old-cli' "$TMP/undo-r1.out"
all_sha=$(sed -n 's/^Undo SHA-256: //p' "$TMP/undo.out")
r1_sha=$(sed -n 's/^Undo SHA-256: //p' "$TMP/undo-r1.out")
if [ ${#all_sha} -eq 64 ] && [ "$all_sha" != "$r1_sha" ]; then ok "the undo hash depends on the runs selected"
else not_ok "the undo hash depends on the runs selected" "all=$all_sha r1=$r1_sha"; fi
if [ "$before" = "$(fingerprint "$D")" ]; then ok "undo listing changes nothing"; else not_ok "undo listing changes nothing"; fi
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" "$D/changes-2026-06-15.jsonl" --approved "$r1_sha" >"$TMP/undo-wrongrun.out" 2>&1
exits "a hash approved for one run does not undo every run" 1 $? "$TMP/undo-wrongrun.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" "$D/changes-2026-06-15.jsonl" --approved 0000 >"$TMP/undo-wrong.out" 2>&1
exits "undo with the wrong hash refuses" 1 $? "$TMP/undo-wrong.out"
# A later undo already recreated UL_3 as UL_30 and restored boundary/protect-edge.
cp "$FIX/undone-changes.fixture.jsonl" "$D/changes-2026-06-16.jsonl"
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" "$D/changes-2026-06-15.jsonl" >"$TMP/undo-resume.out" 2>&1
lacks "a List already recreated is not recreated again" 'recreates deleted List UL_3' "$TMP/undo-resume.out"
lacks "a change already undone is not undone again" 'boundary/protect-edge' "$TMP/undo-resume.out"
contains "membership restores use the recreated List's new id" 'example-org/fast-parser  add ["Parsing Libs" (UL_30)]' "$TMP/undo-resume.out"
# Recreated twice, in two undo runs: UL_3 -> UL_30 -> UL_31.
printf '{"ts":"2026-06-17T00:00:00Z","run_id":"U9","login":"example-user","op":"undo_recreate_list","op_key":"undo:x","undoes":"x","status":"ok","old_id":"UL_30","new_id":"UL_31"}\n' >"$D/changes-2026-06-17.jsonl"
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" "$D/changes-2026-06-15.jsonl" >"$TMP/undo-chain.out" 2>&1
contains "a List recreated more than once is followed to its current id" 'example-org/fast-parser  add ["Parsing Libs" (UL_31)]' "$TMP/undo-chain.out"

# Run R3 renamed UL_3 "Parse Kit" -> "Parsing Libs" first; then R1, R2 and
# D1, which deleted it. Undo recreates it under a new id and must rename that
# one back. The stub starts as the log leaves GitHub: "CLI Tools" renamed to
# "Command Line", UL_3 deleted, every recorded membership in place.
D=$(make_data_dir undo-rename)
S=$(make_stub undo-rename)
jq 'map(select(.id != "UL_3")) | map(if .id == "UL_2" then .name = "Command Line" | .items += [{"id":"R_9","nameWithOwner":"boundary/protect-edge"}] else . end)
    + [{"id":"UL_9","name":"AI Agents","description":"","isPrivate":false,"items":[{"id":"R_4","nameWithOwner":"sample-labs/new-agent"}]}]' \
  "$FIX/lists.raw.json" >"$S/lists.json"
{ cat <<'EOF'
{"ts":"2026-06-15T00:30:00Z","run_id":"R3","login":"example-user","plan_hash":"H3","op_key":"rename:UL_3","op":"rename_list","status":"started","list_id":"UL_3","from":"Parse Kit","to":"Parsing Libs","description":"Overlaps Parsers","private":null,"before":{"name":"Parse Kit","description":"Overlaps Parsers","isPrivate":false}}
{"ts":"2026-06-15T00:30:00Z","run_id":"R3","login":"example-user","plan_hash":"H3","op_key":"rename:UL_3","op":"rename_list","status":"ok"}
EOF
  cat "$FIX/changes.fixture.jsonl"; } >"$D/changes-2026-06-15.jsonl"
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" "$D/changes-2026-06-15.jsonl" >"$TMP/undo-rename.out" 2>&1
contains "the listing renames the recreated List back" 'graphql updateUserList  recreated UL_3  name="Parse Kit"' "$TMP/undo-rename.out"
usha=$(sed -n 's/^Undo SHA-256: //p' "$TMP/undo-rename.out")
STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH" \
  bash "$SCRIPTS/undo.sh" "$D/changes-2026-06-15.jsonl" --approved "$usha" >"$TMP/undo-rename-run.out" 2>&1
exits "the undo completes" 0 $? "$TMP/undo-rename-run.out"
contains "and renames the recreated List, not the deleted one" '{"listId":"UL_NEW_Parsing Libs","name":"Parse Kit"' "$S/calls"

echo "# retries are re-checked like first attempts"
# Calls for plan.fixture: 1 unstar old-cli, 2 create "AI Agents", 3 R_4,
# 4 R_7 -> [UL_2, AI Agents].
D=$(make_data_dir e2e-retry)
S=$(make_stub e2e-retry)
approve_categories "$D"
printf '200\n200\n200\n429\n200\n' >"$S/statuses"
echo 'map(if .id == "UL_1" then .items += [{"id":"R_7","nameWithOwner":"boundary/at-cutoff"}] else . end)' >"$S/change-4"
run_apply "$D" "$S" "$TMP/e2e-retry.out"
exits "a rate-limited call is retried" 0 $? "$TMP/e2e-retry.out"
contains "and rebuilt from a fresh read, keeping an edit made meanwhile" '{"itemId":"R_7","listIds":["UL_1","UL_2","UL_NEW_AI Agents"]}' "$S/calls"
D=$(make_data_dir e2e-landed)
S=$(make_stub e2e-landed)
approve_categories "$D"
printf '200\n200\n200\n502+\n' >"$S/statuses"
run_apply "$D" "$S" "$TMP/e2e-landed.out"
exits "a call that landed despite a server error" 0 $? "$TMP/e2e-landed.out"
if [ "$(grep -c '"itemId":"R_7"' "$S/calls")" -eq 1 ]; then ok "is seen on the re-read, not sent again"; else not_ok "is seen on the re-read, not sent again" "$(cat "$S/calls")"; fi
contains "and is logged as done" '"op_key":"set:R_7","plan_hash"' "$D/changes-$(date +%F).jsonl"
jq -s '[.[] | select(.op_key == "set:R_7")] | last | .status' "$D/changes-$(date +%F).jsonl" >"$TMP/landed-status.json"
check "with an ok outcome" '. == "ok"' "$TMP/landed-status.json"
# run_delete <data dir> <stub dir> <output file>
run_delete() {
  STAR_CHART_DIR="$1" STUB_DIR="$2" PATH="$HERE/bin:$PATH" \
    bash "$SCRIPTS/delete-lists.sh" --run >"$3" 2>&1
}
D=$(make_data_dir e2e-del-retry)
S=$(make_stub e2e-del-retry)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
printf '429\n200\n' >"$S/statuses"
echo 'map(if .id == "UL_4" then .items += [{"id":"R_9","nameWithOwner":"boundary/protect-edge"}] else . end)' >"$S/change-1"
run_delete "$D" "$S" "$TMP/e2e-del-retry.out"
if [ "$(wc -l <"$S/calls" | tr -d ' ')" -eq 1 ]; then ok "a rate-limited deletion is not resent once the List holds a repo"; else not_ok "a rate-limited deletion is not resent once the List holds a repo" "$(cat "$S/calls")"; fi
contains "and the List is skipped with the reason" 'SKIPPED "Old Stuff"' "$TMP/e2e-del-retry.out"

# The audit's remaining cells (see write-paths.md).
# R8 + R5, unstar: old-cli is re-starred while its unstar waits out a rate limit.
D=$(make_data_dir e2e-unstar-retry)
S=$(make_stub e2e-unstar-retry)
approve_categories "$D"
printf '429\n' >"$S/statuses"
printf '[{"starred_at":"2026-06-14T00:00:00Z","repo":{"full_name":"example-org/old-cli"}}]' >"$S/recent-1"
run_apply "$D" "$S" "$TMP/e2e-unstar-retry.out"
contains "an unstar retry re-checks protection first" 'REFUSED unstar example-org/old-cli: starred within the last 90 days' "$TMP/e2e-unstar-retry.out"
if [ "$(grep -c '^DELETE' "$S/calls")" -eq 1 ]; then ok "and does not send it again"; else not_ok "and does not send it again" "$(cat "$S/calls")"; fi
# R5 + R6, create: the create lands, but its answer is a server error.
D=$(make_data_dir e2e-create-landed)
S=$(make_stub e2e-create-landed)
approve_categories "$D"
printf '200\n502+\n' >"$S/statuses"
run_apply "$D" "$S" "$TMP/e2e-create-landed.out"
exits "a create that landed despite a server error completes" 0 $? "$TMP/e2e-create-landed.out"
if [ "$(grep -c '"name":"AI Agents"' "$S/calls")" -eq 1 ]; then ok "the re-check finds it, so it is not created twice"; else not_ok "the re-check finds it, so it is not created twice" "$(cat "$S/calls")"; fi
contains "and the repos go into it" '{"itemId":"R_4","listIds":["UL_NEW_AI Agents"]}' "$S/calls"
# R7: apply records the state of every List a call touches, for undo to check.
jq -s '[.[] | select(.op_key == "set:R_7" and .status == "started")] | last | .lists' "$D/changes-$(date +%F).jsonl" >"$TMP/logged-lists.json"
check "a membership call logs the state of the Lists it touches" '. == {"UL_2":{"name":"CLI Tools","description":"","isPrivate":true},"UL_NEW_AI Agents":{"name":"AI Agents","description":"Agent frameworks | tools","isPrivate":false}}' "$TMP/logged-lists.json"
# R5 + R6, delete: the deletion lands, but its answer is a server error.
D=$(make_data_dir e2e-del-landed)
S=$(make_stub e2e-del-landed)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
printf '502+\n' >"$S/statuses"
run_delete "$D" "$S" "$TMP/e2e-del-landed.out"
exits "a deletion that landed despite a server error completes" 0 $? "$TMP/e2e-del-landed.out"
if [ "$(wc -l <"$S/calls" | tr -d ' ')" -eq 1 ]; then ok "the re-check finds it gone, so it is not sent again"; else not_ok "the re-check finds it gone, so it is not sent again" "$(cat "$S/calls")"; fi
# R6, undo: a refused step leaves the undo unfinished. The run's rename of
# "CLI Tools" is renamed again elsewhere before the undo.
D=$(make_data_dir undo-refused)
S=$(make_stub undo-refused)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
run_apply "$D" "$S" "$TMP/undo-refused-apply.out"
jq 'map(if .id == "UL_2" then .name = "Shell" else . end)' "$S/lists.json" >"$S/l.tmp" && mv "$S/l.tmp" "$S/lists.json"
urun=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --list-runs | head -n 1 | cut -d' ' -f1)
usha=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --run "$urun" | sed -n 's/^Undo SHA-256: //p')
STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH" bash "$SCRIPTS/undo.sh" --run "$urun" --approved "$usha" >"$TMP/undo-refused.out" 2>&1
exits "an undo with a refused step leaves it unfinished" 2 $? "$TMP/undo-refused.out"
contains "and says why" 'REFUSED rename_back CLI Tools: "Shell" is private; it must be "Command Line", private' "$TMP/undo-refused.out"
# R5 + R6, undo recreate: the recreate lands, but its answer is a server error.
D=$(make_data_dir undo-recreate-landed)
S=$(make_stub undo-recreate-landed)
jq 'map(select(.id != "UL_3"))' "$FIX/lists.raw.json" >"$S/lists.json"
grep '"run_id":"D1"' "$FIX/changes.fixture.jsonl" >"$D/changes-2026-06-15.jsonl"
printf '502+\n' >"$S/statuses"
usha=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --run D1 | sed -n 's/^Undo SHA-256: //p')
STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH" bash "$SCRIPTS/undo.sh" --run D1 --approved "$usha" >"$TMP/undo-rec-landed.out" 2>&1
exits "a recreate that landed despite a server error completes" 0 $? "$TMP/undo-rec-landed.out"
if [ "$(wc -l <"$S/calls" | tr -d ' ')" -eq 1 ]; then ok "the re-check finds it, so it is not recreated twice"; else not_ok "the re-check finds it, so it is not recreated twice" "$(cat "$S/calls")"; fi
contains "and the new id is recorded for later steps" '"new_id":"UL_NEW_Parsing Libs"' "$D/changes-$(date +%F).jsonl"
jq -s '[.[] | select(.op == "undo_recreate_list")] | map(.status)' "$D/changes-$(date +%F).jsonl" >"$TMP/undo-logged.json"
check "an undo step is logged before each attempt, then with its outcome" '. == ["started","ok"]' "$TMP/undo-logged.json"

# R2, approvals: "Old Stuff" (UL_4) is replaced by another List of the same
# name, and the export is run again. The category approval named UL_4, so
# nothing that relies on it accepts the replacement.
D=$(make_data_dir approval-ids)
S=$(make_stub approval-ids)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
check "the category approval records the id of every List it names" '.list_ids == {"cli tools":"UL_2","old stuff":"UL_4","parsing libs":"UL_3","parsers":"UL_1"}' "$D/categories.approved.json"
jq '.lists |= map(if .id == "UL_4" then .id = "UL_44" else . end)' "$D/stars.json" >"$D/s.tmp" && mv "$D/s.tmp" "$D/stars.json"
jq 'map(if .id == "UL_4" then .id = "UL_44" else . end)' "$FIX/lists.raw.json" >"$S/lists.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/approval-ids-dry.out" 2>&1
exits "the dry run refuses a replaced List" 1 $? "$TMP/approval-ids-dry.out"
contains "and names it" '"Old Stuff" is not the List the approval named' "$TMP/approval-ids-dry.out"
run_delete "$D" "$S" "$TMP/approval-ids-del.out"
exits "delete-lists refuses it too" 1 $? "$TMP/approval-ids-del.out"
if [ -s "$S/calls" ]; then not_ok "and deletes nothing" "$(cat "$S/calls")"; else ok "and deletes nothing"; fi

# R7, unstar: a plan renames "CLI Tools" and unstars old-cli, which is in it.
# The unstar logs the repo's Lists as they are at the call (renamed), so undo
# can put it back before renaming the List back.
D=$(make_data_dir unstar-log)
S=$(make_stub unstar-log)
jq '.unstar = [{"repo": "example-org/old-cli", "reason": "stale"}]' "$FIX/plan-consolidate.fixture.json" >"$D/plan.json"
approve_categories "$D"
run_apply "$D" "$S" "$TMP/unstar-log-apply.out"
exits "a plan that renames a List and unstars one of its repos completes" 0 $? "$TMP/unstar-log-apply.out"
jq -s '[.[] | select(.op == "unstar" and .status == "started")] | last | {list_ids, lists}' "$D/changes-$(date +%F).jsonl" >"$TMP/unstar-logged.json"
check "an unstar logs the repo's Lists as they are at the call" '. == {"list_ids":["UL_2"],"lists":{"UL_2":{"name":"Command Line","description":"","isPrivate":true}}}' "$TMP/unstar-logged.json"
urun=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --list-runs | head -n 1 | cut -d' ' -f1)
usha=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --run "$urun" | sed -n 's/^Undo SHA-256: //p')
STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH" bash "$SCRIPTS/undo.sh" --run "$urun" --approved "$usha" >"$TMP/unstar-log-undo.out" 2>&1
exits "and undoing it completes" 0 $? "$TMP/unstar-log-undo.out"

# R8, fail closed: rules.md becomes unreadable mid-run (at the rename, call 1);
# the unstar later in the run cannot check its protection, so it is refused.
D=$(make_data_dir e2e-rules-gone)
S=$(make_stub e2e-rules-gone)
jq '.unstar = [{"repo": "example-org/old-cli", "reason": "stale"}]' "$FIX/plan-consolidate.fixture.json" >"$D/plan.json"
approve_categories "$D"
printf 'chmod 000 "%s/rules.md"\n' "$D" >"$S/run-1"
run_apply "$D" "$S" "$TMP/e2e-rules-gone.out"
exits "a run whose protection check breaks is unfinished" 2 $? "$TMP/e2e-rules-gone.out"
contains "the unstar is refused" 'REFUSED unstar example-org/old-cli' "$TMP/e2e-rules-gone.out"
if grep -q '^DELETE' "$S/calls"; then not_ok "and not sent" "$(cat "$S/calls")"; else ok "and not sent"; fi
chmod 600 "$D/rules.md"

# R6 + R7, undo after a retry: attempt 1 (rate limited, not made) would have
# moved R_1 out of UL_1; the user then changed things, and attempt 2 made
# [UL_3] -> [UL_3, UL_2]. Only the attempt that was made is reversed.
cat >"$TMP/log-retry.jsonl" <<'EOF'
{"ts":"2026-06-15T05:00:00Z","run_id":"R5","login":"example-user","plan_hash":"H5","op_key":"set:R_1","op":"set_lists","status":"started","repo":"example-org/fast-parser","item_id":"R_1","before_ids":["UL_1"],"after_ids":["UL_2"],"lists":{"UL_1":{"name":"Parsers","isPrivate":false},"UL_2":{"name":"CLI Tools","isPrivate":true}}}
{"ts":"2026-06-15T05:00:10Z","run_id":"R5","login":"example-user","plan_hash":"H5","op_key":"set:R_1","op":"set_lists","status":"started","repo":"example-org/fast-parser","item_id":"R_1","before_ids":["UL_3"],"after_ids":["UL_3","UL_2"],"lists":{"UL_2":{"name":"CLI Tools","isPrivate":true},"UL_3":{"name":"Parsing Libs","isPrivate":false}}}
{"ts":"2026-06-15T05:00:11Z","run_id":"R5","login":"example-user","plan_hash":"H5","op_key":"set:R_1","op":"set_lists","status":"ok"}
EOF
jq -s . "$TMP/log-retry.jsonl" >"$TMP/all-retry.json"
jq -s -L "$JQ" --arg run R5 --slurpfile all "$TMP/all-retry.json" -f "$JQ/undo.jq" "$TMP/log-retry.jsonl" >"$TMP/undo-retry.json"
check "undo reverses only the attempt that was made" 'length == 1 and .[0].add == [] and .[0].remove == [{"id":"UL_2","name":"CLI Tools","isPrivate":true}]' "$TMP/undo-retry.json"

# R6, unstar: the unstar lands but is answered with a server error. The
# re-check sees the repo is no longer starred: done, not sent again, and its
# one attempt (with the repo's Lists) is what undo reverses.
D=$(make_data_dir e2e-unstar-landed)
S=$(make_stub e2e-unstar-landed)
approve_categories "$D"
printf '502+\n' >"$S/statuses"
run_apply "$D" "$S" "$TMP/e2e-unstar-landed.out"
exits "an unstar that landed despite a server error completes" 0 $? "$TMP/e2e-unstar-landed.out"
if [ "$(grep -c '^DELETE' "$S/calls")" -eq 1 ]; then ok "the re-check sees it is no longer starred, so it is not sent again"; else not_ok "the re-check sees it is no longer starred, so it is not sent again" "$(cat "$S/calls")"; fi
jq -s '[.[] | select(.op == "unstar" and .status == "started")] | map(.list_ids)' "$D/changes-$(date +%F).jsonl" >"$TMP/unstar-attempts.json"
check "one attempt is logged, with the repo's Lists" '. == [["UL_2"]]' "$TMP/unstar-attempts.json"
# R6, undo re-star: the same for the reversal. Undo runs newest first: R_7,
# R_4, then the re-star, the third write, which lands with a server error.
urun=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --list-runs | head -n 1 | cut -d' ' -f1)
usha=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --run "$urun" | sed -n 's/^Undo SHA-256: //p')
: >"$S/calls"
printf '200\n200\n502+\n' >"$S/statuses"
STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH" bash "$SCRIPTS/undo.sh" --run "$urun" --approved "$usha" >"$TMP/undo-restar-landed.out" 2>&1
exits "a re-star that landed despite a server error completes" 0 $? "$TMP/undo-restar-landed.out"
if [ "$(grep -c '^PUT' "$S/calls")" -eq 1 ]; then ok "the re-check sees it is starred again, so it is not sent again"; else not_ok "the re-check sees it is starred again, so it is not sent again" "$(cat "$S/calls")"; fi
# A repo unstarred elsewhere before the call: nothing to do.
D=$(make_data_dir e2e-unstar-gone)
S=$(make_stub e2e-unstar-gone)
approve_categories "$D"
echo example-org/old-cli >"$S/unstarred"
run_apply "$D" "$S" "$TMP/e2e-unstar-gone.out"
contains "an unstar of a repo no longer starred is already in place" 'already in place: unstar example-org/old-cli' "$TMP/e2e-unstar-gone.out"

# R6, a dropped connection: the create lands, then the answer is cut off and
# gh exits 1. It is not taken as done; the re-check finds the List.
D=$(make_data_dir e2e-truncated)
S=$(make_stub e2e-truncated)
approve_categories "$D"
printf '200\n200~\n' >"$S/statuses"
run_apply "$D" "$S" "$TMP/e2e-truncated.out"
exits "a create whose answer was cut off completes" 0 $? "$TMP/e2e-truncated.out"
jq -s '[.[] | select(.op_key == "create:ai agents" and .status != "started")] | last | {status, list_id}' "$D/changes-$(date +%F).jsonl" >"$TMP/trunc-outcome.json"
check "its outcome comes from the re-check, with the List it found" '. == {"status":"ok","list_id":"UL_NEW_AI Agents"}' "$TMP/trunc-outcome.json"
if [ "$(grep -c '"name":"AI Agents"' "$S/calls")" -eq 1 ]; then ok "and it is not created twice"; else not_ok "and it is not created twice" "$(cat "$S/calls")"; fi

# R6, undo resumed after a failure: undoing the consolidation run, the reversal
# for boundary/at-cutoff (the second write) is refused by GitHub, and the
# rename back of "Command Line" still happens. Run again, the reversal is
# made: the List is as the undo itself left it, not as someone else changed it.
D=$(make_data_dir undo-resume-after-failure)
S=$(make_stub undo-resume-after-failure)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
run_apply "$D" "$S" "$TMP/urf-apply.out"
urun=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --list-runs | head -n 1 | cut -d' ' -f1)
usha=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --run "$urun" | sed -n 's/^Undo SHA-256: //p')
printf '200\n403\n' >"$S/statuses"
STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH" bash "$SCRIPTS/undo.sh" --run "$urun" --approved "$usha" >"$TMP/urf-1.out" 2>&1
exits "an undo with a failed step is unfinished" 2 $? "$TMP/urf-1.out"
usha=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --run "$urun" | sed -n 's/^Undo SHA-256: //p')
STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH" bash "$SCRIPTS/undo.sh" --run "$urun" --approved "$usha" >"$TMP/urf-2.out" 2>&1
exits "run again, it finishes" 0 $? "$TMP/urf-2.out"
check "and boundary/at-cutoff is out of the List again" '[.[] | select(.id == "UL_2") | .items[].id] | index("R_7") == null' "$S/lists.json"

# R6 + R7, delete-lists: a deletion is rate-limited, and the List's description
# changes while it waits. The attempt that deletes it logs what it deleted.
D=$(make_data_dir del-retry-meta)
S=$(make_stub del-retry-meta)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
printf '429\n200\n' >"$S/statuses"
echo 'map(if .id == "UL_4" then .description = "Changed meanwhile" else . end)' >"$S/change-1"
run_delete "$D" "$S" "$TMP/del-retry-meta.out"
jq -s '[.[] | select(.op == "delete_list" and .status == "started")] | last | .description' "$D/changes-$(date +%F).jsonl" >"$TMP/del-meta.json"
check "a retried deletion logs the List as the attempt found it" '. == "Changed meanwhile"' "$TMP/del-meta.json"

# R3 + class 1, undo: only the run being undone counts. An earlier undo (U1)
# renamed UL_1 back to public "X". A later run (B) took boundary/protect-edge
# out of UL_1 while it was private "Parsers". UL_1 is public "X" again now;
# undoing B must not put the repo back into it on the strength of U1.
D=$(make_data_dir undo-stale-restore)
S=$(make_stub undo-stale-restore)
jq 'map(if .id == "UL_1" then .name = "X" | .items |= map(select(.id != "R_9")) else . end)' "$FIX/lists.raw.json" >"$S/lists.json"
cat >"$D/changes-2026-06-15.jsonl" <<'EOF'
{"ts":"2026-06-15T01:00:00Z","run_id":"A","login":"example-user","plan_hash":"HA","op_key":"rename:UL_1","op":"rename_list","status":"started","list_id":"UL_1","from":"X","to":"Parsers","description":"Parsing libraries","private":false,"before":{"name":"X","description":"Parsing libraries","isPrivate":false}}
{"ts":"2026-06-15T01:00:01Z","run_id":"A","login":"example-user","plan_hash":"HA","op_key":"rename:UL_1","op":"rename_list","status":"ok"}
{"ts":"2026-06-15T02:00:00Z","run_id":"U1","login":"example-user","op":"undo_rename_back","op_key":"undo:A/rename:UL_1","undoes":"A/rename:UL_1","status":"started","list_id":"UL_1","requires":{"name":"Parsers","description":"Parsing libraries","isPrivate":false},"expects":{"name":"X","description":"Parsing libraries","isPrivate":false}}
{"ts":"2026-06-15T02:00:01Z","run_id":"U1","login":"example-user","op":"undo_rename_back","op_key":"undo:A/rename:UL_1","undoes":"A/rename:UL_1","status":"ok"}
{"ts":"2026-06-15T03:00:00Z","run_id":"B","login":"example-user","plan_hash":"HB","op_key":"set:R_9","op":"set_lists","status":"started","repo":"boundary/protect-edge","item_id":"R_9","before_ids":["UL_1"],"after_ids":[],"lists":{"UL_1":{"name":"Parsers","description":"Parsing libraries","isPrivate":true}}}
{"ts":"2026-06-15T03:00:01Z","run_id":"B","login":"example-user","plan_hash":"HB","op_key":"set:R_9","op":"set_lists","status":"ok"}
EOF
usha=$(STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --run B | sed -n 's/^Undo SHA-256: //p')
STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH" bash "$SCRIPTS/undo.sh" --run B --approved "$usha" >"$TMP/undo-stale.out" 2>&1
exits "undo does not use a state an unrelated undo restored" 2 $? "$TMP/undo-stale.out"
if grep -q 'R_9' "$S/calls"; then not_ok "and does not put the repo into the now-public List" "$(cat "$S/calls")"; else ok "and does not put the repo into the now-public List"; fi

echo "# outcomes across retries, deletion identity, export baseline"
S=$(make_stub retry)
printf '{"query":"mutation { x }","variables":{}}' >"$TMP/retry-body.json"
# checked <statuses> <decision before each attempt, one per line> : the
# outcome sc_checked_call reaches.
checked() {
  printf "$1" >"$S/statuses"
  printf "$2" >"$S/decisions"
  (export STUB_DIR="$S" PATH="$HERE/bin:$PATH"
   . "$SCRIPTS/lib.sh"
   # shellcheck disable=SC2034 # read by sc_checked_call
   check() { SC_DECISION=$(head -n 1 "$S/decisions"); tail -n +2 "$S/decisions" >"$S/d.tmp"; mv "$S/d.tmp" "$S/decisions"; }
   # shellcheck disable=SC2034 # read by sc_checked_call
   send() { SC_RC=0; sc_call graphql --input "$TMP/retry-body.json" >/dev/null 2>&1 || SC_RC=$?; }
   sc_checked_call check send
   printf '%s' "$SC_OUTCOME")
}
C='{"action":"call"}\n'
D_='{"action":"done"}\n'
R='{"action":"refuse","reason":"x"}\n'
[ "$(checked '200\n' "$C")" = ok ] && ok "a call that succeeds is ok" || not_ok "a call that succeeds is ok"
[ "$(checked '403\n' "$C")" = failed ] && ok "a refused call has failed" || not_ok "a refused call has failed"
[ "$(checked '429\n200\n' "$C$C")" = ok ] && ok "a rate limit is retried after a new check" || not_ok "a rate limit is retried after a new check"
[ "$(checked '429\n' "$C$R")" = refused ] && ok "a retry the new check refuses is refused, not sent" || not_ok "a retry the new check refuses is refused, not sent"
[ "$(checked '502\n403\n' "$C$C")" = unknown ] && ok "a server error then a refusal stays unknown" || not_ok "a server error then a refusal stays unknown"
[ "$(checked '502\n200\n' "$C$C")" = ok ] && ok "a server error then success is ok" || not_ok "a server error then success is ok"
[ "$(checked '502\n' "$C$D_")" = ok ] && ok "a server error the new check finds done is ok" || not_ok "a server error the new check finds done is ok"
[ "$(checked '502\n' "$C$R")" = unknown ] && ok "a server error the new check refuses is unknown" || not_ok "a server error the new check refuses is unknown"
[ "$(checked '' "$D_")" = exists ] && ok "done before any attempt is already in place" || not_ok "done before any attempt is already in place"
: >"$S/calls"
[ "$(checked '200\n' '{"action":"maybe"}\n')" = refused ] && ok "a check with no clear answer is a refusal" || not_ok "a check with no clear answer is a refusal"
[ ! -s "$S/calls" ] && ok "and nothing is sent" || not_ok "and nothing is sent" "$(cat "$S/calls")"
[ "$(checked '429\n429\n429\n429\n429\n' "$C$C$C$C$C")" = failed ] && ok "five rate limits fail" || not_ok "five rate limits fail"
[ "$(checked '502\n502\n502\n502\n502\n' "$C$C$C$C$C")" = unknown ] && ok "five server errors are unknown" || not_ok "five server errors are unknown"

D=$(make_data_dir delete-ok)
S=$(make_stub delete-ok)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
run_delete "$D" "$S" "$TMP/delete-ok.out"
contains "an approved List that is empty now is deleted" '{"listId":"UL_4"}' "$S/calls"
jq -s '[.[] | select(.op == "delete_list" and .status == "started")] | first | {list_id, name, description, private}' "$D/changes-$(date +%F).jsonl" >"$TMP/del-logged.json"
check "a deletion is logged first with what undo needs to recreate the List" '. == {"list_id":"UL_4","name":"Old Stuff","description":"","private":false}' "$TMP/del-logged.json"
lacks "a List that still holds repos is not" 'UL_3' "$S/calls"
D=$(make_data_dir delete-identity)
S=$(make_stub delete-identity)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
approve_categories "$D"
# "Old Stuff" (UL_4) was deleted on GitHub, and another empty List took its name.
jq 'map(if .id == "UL_4" then .id = "UL_44" else . end)' "$FIX/lists.raw.json" >"$S/lists.json"
run_delete "$D" "$S" "$TMP/delete-identity.out"
lacks "a different List that took an approved List's name is not deleted" 'UL_44' "$S/calls"
contains "and the skip says why" '"Old Stuff": a different List has this name now' "$TMP/delete-identity.out"

D="$TMP/export-baseline"
mkdir -p "$D"
S=$(make_stub export-baseline)
cp "$FIX/starred.raw.json" "$S/starred.json"
(unset STAR_CHART_NOW; export STAR_CHART_DIR="$D" STUB_DIR="$S" PATH="$HERE/bin:$PATH"
 bash "$SCRIPTS/export.sh") >"$TMP/export.out" 2>&1
exits "export runs" 0 $? "$TMP/export.out"
jq -n --arg read "$(cat "$S/stars-read-at" 2>/dev/null)" --slurpfile s "$D/stars.json" \
  '{exported_at: $s[0].exported_at, stars_read_at: $read}' >"$TMP/baseline.json"
check "the export's timestamp is taken before its stars are read" '.exported_at < .stars_read_at' "$TMP/baseline.json"

echo "# privacy, drift, protection, resume, account, names, baseline"
D=$(make_data_dir privacy)
cp "$FIX/plan-consolidate.fixture.json" "$D/plan.json"
jq '.lists |= map(if .id == "UL_3" then .isPrivate = true else . end)' "$D/stars.json" >"$D/s.tmp" && mv "$D/s.tmp" "$D/stars.json"
jq '.renames[0].private = false' "$FIX/plan-consolidate.fixture.json" >"$D/plan.json"
PRIVSTARS="$D/stars.json"
PRIVPLAN="$D/plan.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" categories >"$TMP/priv.out" 2>&1
contains "a rename that publishes a private List says so" '~ rename "CLI Tools" -> "Command Line" (2 repos, private -> public)' "$TMP/priv.out"
contains "the warning names the List going public" '! "CLI Tools" (2 repos) becomes public' "$TMP/priv.out"
contains "the warning names a private merge into a public List" '! "Parsing Libs" is private; its 2 repos join public "Parsers"' "$TMP/priv.out"
psha=$(sed -n 's/^Categories SHA-256: //p' "$TMP/priv.out")
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" approve-categories "$psha" >"$TMP/priv-approve.out" 2>&1
exits "approving a private-to-public change without acknowledging it refuses" 1 $? "$TMP/priv-approve.out"
contains "and says how to acknowledge it" '--publishes-private' "$TMP/priv-approve.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" approve-categories "$psha" --publishes-private >"$TMP/priv-approve2.out" 2>&1
exits "an acknowledged private-to-public change is approved" 0 $? "$TMP/priv-approve2.out"
# legacy-sdk is only in private Parsing Libs and is also assigned to public AI Agents.
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/priv-dry-unack.out" 2>&1
exits "the dry run stops until that assignment is acknowledged too" 1 $? "$TMP/priv-dry-unack.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" allow-public sample-labs/legacy-sdk >/dev/null 2>&1
STAR_CHART_DIR="$D" bash "$SCRIPTS/dry-run.sh" >"$TMP/priv-dry.out" 2>&1
contains "the dry run marks a move out of a private List" 'sample-labs/legacy-sdk  [Parsing Libs] -> [Parsers, AI Agents]  (private -> public: Parsing Libs)' "$TMP/priv-dry.out"
contains "the dry run marks a List made public" 'graphql updateUserList  "CLI Tools" -> "Command Line"  (private -> public)' "$TMP/priv-dry.out"

jq -n -L "$JQ" --argjson rules "$RULES" '
  include "common";
  [("KEEPERS/x" | sc_protection_reason($rules; [])),
   ("a/recent" | sc_protection_reason($rules; ["a/recent"])),
   ("a/old" | sc_protection_reason($rules; ["a/recent"]))]' >"$TMP/prot.json"
check "protection is decided from current rules and current recent stars" '. == ["keep-always pattern","starred within the last 90 days",null]' "$TMP/prot.json"

jq -s -L "$JQ" 'include "common"; sc_done_keys("H1")' "$FIX/changes.fixture.jsonl" >"$TMP/done.json"
check "a re-run skips only changes that finished for the same approval" '. == ["create:ai agents","rename:UL_2","set:R_1","set:R_4","unstar:R_2"]' "$TMP/done.json"

(. "$SCRIPTS/lib.sh"
 if sc_same_account Example-User example-user && ! sc_same_account example-user someone-else; then exit 0; else exit 1; fi)
exits "the account check ignores case and catches a different account" 0 $?

jq '.assignments[1].lists = ["Command, Line"] | .lists_to_create += [{"name": "Command, Line", "description": "", "private": false, "reason": "r"}]' "$CPLAN" >"$TMP/comma.json"
jq -r -L "$JQ" -f "$JQ/render.jq" "$TMP/comma.json" >"$TMP/comma.md"
contains "a comma inside a List name is escaped" '| Command\, Line |' "$TMP/comma.md"
jq -R -s -L "$JQ" -f "$JQ/parse.jq" "$TMP/comma.md" >"$TMP/comma-rt.json"
check "a comma inside a List name survives editing" '(.assignments[] | select(.repo == "boundary/at-cutoff")).lists == ["Command, Line"]' "$TMP/comma-rt.json"

echo "# pass-2 fixes: unknown outcomes, undone changes, assignment privacy, same-name Lists"
{ cat "$FIX/changes.fixture.jsonl"
  printf '%s\n' '{"ts":"2026-06-15T04:00:00Z","run_id":"R3","login":"example-user","plan_hash":"H3","op_key":"unstar:R_8","op":"unstar","status":"started","repo":"boundary/just-before","item_id":"R_8","starred_at":"2025-01-02T00:00:00Z","list_ids":[]}' \
                '{"ts":"2026-06-15T04:00:01Z","run_id":"R3","login":"example-user","plan_hash":"H3","op_key":"unstar:R_8","op":"unstar","status":"unknown","error":"connection reset"}'
} >"$TMP/log-unknown.jsonl"
jq -s . "$TMP/log-unknown.jsonl" >"$TMP/all-unknown.json"
jq -s -L "$JQ" --arg run R3 --slurpfile all "$TMP/all-unknown.json" -f "$JQ/undo.jq" "$TMP/log-unknown.jsonl" >"$TMP/undo-unknown.json"
check "a change with an unknown outcome is reversed as uncertain" '. == [{"op":"restar","repo":"boundary/just-before","undoes":"R3/unstar:R_8","uncertain":true}]' "$TMP/undo-unknown.json"
jq -s -L "$JQ" 'include "common"; sc_done_keys("H3")' "$TMP/log-unknown.jsonl" >"$TMP/done-unknown.json"
check "a change with an unknown outcome is not treated as done" '. == []' "$TMP/done-unknown.json"
jq -s -L "$JQ" -f "$JQ/runs.jq" "$TMP/log-unknown.jsonl" >"$TMP/runs-unknown.json"
check "the run list counts an unknown outcome as uncertain" '(.[] | select(.run_id == "R3")).uncertain == 1' "$TMP/runs-unknown.json"
cat "$FIX/changes.fixture.jsonl" "$FIX/undone-changes.fixture.jsonl" | jq -s -L "$JQ" 'include "common"; sc_done_keys("H2")' >"$TMP/done-undone.json"
check "a change reversed by undo is no longer done" '. == ["create:parsers"]' "$TMP/done-undone.json"

jq '.stars |= map(if .node_id == "R_3" then .list_ids = ["UL_3"] | .lists = ["Parsing Libs"] else . end)
    | .lists |= map(if .id == "UL_3" then .isPrivate = true else . end)' "$TMP/stars.json" >"$TMP/stars-privrepo.json"
jq '.lists_to_create = [] | .unstar = [] | .assignments = [{"repo": "sample-labs/legacy-sdk", "lists": ["Parsers"], "reason": "r"}]' \
  "$FIX/plan.fixture.json" >"$TMP/plan-privassign.json"
classify "$TMP/stars-privrepo.json" "$RULES" >"$TMP/cls-privrepo.json"
jq -L "$JQ" --slurpfile stars "$TMP/stars-privrepo.json" --slurpfile cls "$TMP/cls-privrepo.json" -f "$JQ/validate.jq" "$TMP/plan-privassign.json" >"$TMP/v-privassign.json"
check "assigning a privately listed repo to a public List needs acknowledgment" 'any(.[]; test("sample-labs/legacy-sdk is only in private Lists"))' "$TMP/v-privassign.json"
jq '.publish_private = ["sample-labs/legacy-sdk"]' "$TMP/plan-privassign.json" >"$TMP/plan-privassign-ok.json"
jq -L "$JQ" --slurpfile stars "$TMP/stars-privrepo.json" --slurpfile cls "$TMP/cls-privrepo.json" -f "$JQ/validate.jq" "$TMP/plan-privassign-ok.json" >"$TMP/v-privassign-ok.json"
check "an acknowledged assignment validates" '. == []' "$TMP/v-privassign-ok.json"
jq -L "$JQ" --slurpfile stars "$TMP/stars-privrepo.json" -f "$JQ/items.jq" "$TMP/plan-privassign.json" >"$TMP/items-privassign.json"
check "the assignment items name the privately listed repos" '.assignment_groups == [{"id":"assign-list:parsers","list":"Parsers","repos":["sample-labs/legacy-sdk"],"private_repos":["sample-labs/legacy-sdk"]}]' "$TMP/items-privassign.json"
jq -L "$JQ" --slurpfile stars "$TMP/stars-privrepo.json" -f "$JQ/ops.jq" "$TMP/plan-privassign.json" >"$TMP/ops-privassign.json"
check "the dry run marks the assignment as publishing" '(.ops[] | select(.repo == "sample-labs/legacy-sdk")).publishes == ["Parsing Libs"]' "$TMP/ops-privassign.json"
D=$(make_data_dir allow-public)
cp "$TMP/plan-privassign.json" "$D/plan.json"
cp "$TMP/stars-privrepo.json" "$D/stars.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" allow-public sample-labs/legacy-sdk >"$TMP/allow.out" 2>&1
exits "plan.sh allow-public records the acknowledgment" 0 $? "$TMP/allow.out"
check "and the plan carries it" '.publish_private == ["sample-labs/legacy-sdk"]' "$D/plan.json"

D=$(make_data_dir baseline)
(export STAR_CHART_DIR="$D"; . "$SCRIPTS/lib.sh"; [ -z "$(sc_previous_export)" ])
exits "with nothing applied, every star stays new" 0 $?
printf '{"applied_export_at":"2025-06-01T00:00:00Z"}\n' >"$D/state.json"
(export STAR_CHART_DIR="$D"; . "$SCRIPTS/lib.sh"; [ "$(sc_previous_export)" = "2025-06-01T00:00:00Z" ])
exits "the baseline is the export of the last fully applied plan" 0 $?

echo "# items, dropping and run list (what the pop-ups are built from)"
jq -L "$JQ" --slurpfile stars "$TMP/stars.json" -f "$JQ/items.jq" "$CPLAN" >"$TMP/items.json"
check "every category change has a stable id, in order" '[.categories[].id] == ["create:ai agents","rename:cli tools","merge:parsing libs","delete:parsing libs","delete:old stuff"]' "$TMP/items.json"
check "a category item has a short label, detail, reason and privacy flag" '.categories[2] == {"id":"merge:parsing libs","kind":"merge","label":"Merge \"Parsing Libs\" into \"Parsers\"","detail":"2 repos, public into public: 1 already there, 1 moves","reason":"Duplicates Parsers","publishes":false}' "$TMP/items.json"
check "a deletion is its own item" '.categories[4] == {"id":"delete:old stuff","kind":"delete","label":"Delete List \"Old Stuff\" once empty","detail":"0 repos now, public","reason":"Already empty","publishes":false}' "$TMP/items.json"
check "assignments are grouped by List" '.assignment_groups == [{"id":"assign-list:ai agents","list":"AI Agents","repos":["sample-labs/legacy-sdk"]},{"id":"assign-list:command line","list":"Command Line","repos":["boundary/at-cutoff"]}]' "$TMP/items.json"
jq -L "$JQ" --slurpfile stars "$TMP/stars.json" -f "$JQ/items.jq" "$FIX/plan.fixture.json" >"$TMP/items2.json"
check "each unstar is an item with its reason" '.unstars == [{"id":"unstar:example-org/old-cli","repo":"example-org/old-cli","reason":"No push since 2023-01-01"}]' "$TMP/items2.json"
jq -L "$JQ" --slurpfile stars "$PRIVSTARS" -f "$JQ/items.jq" "$PRIVPLAN" >"$TMP/items3.json"
check "a private-to-public change is flagged" '[.categories[] | select(.publishes) | .id] == ["rename:cli tools","merge:parsing libs"]' "$TMP/items3.json"

drop() { # <plan> <ids JSON>
  jq -L "$JQ" --argjson ids "$2" -f "$JQ/drop.jq" "$1"
}
drop "$CPLAN" '["merge:parsing libs"]' >"$TMP/d1.json"
check "rejecting a merge also drops the deletion that needed it" '.plan.merges == [] and ([.plan.deletions[].list] == ["Old Stuff"]) and .cascaded == ["delete:parsing libs"]' "$TMP/d1.json"
drop "$CPLAN" '["create:ai agents"]' >"$TMP/d2.json"
check "rejecting a new List drops what pointed at it" '.plan.lists_to_create == [] and ([.plan.assignments[].repo] == ["boundary/at-cutoff"]) and .cascaded == ["assign:sample-labs/legacy-sdk"]' "$TMP/d2.json"
drop "$CPLAN" '["rename:cli tools"]' >"$TMP/d3.json"
check "rejecting a rename points everything back at the old name" '.plan.renames == [] and ((.plan.assignments[] | select(.repo == "boundary/at-cutoff")).lists == ["CLI Tools"])' "$TMP/d3.json"
drop "$CPLAN" '["assign-list:command line"]' >"$TMP/d4.json"
check "rejecting a List's assignments removes only those" '[.plan.assignments[].repo] == ["sample-labs/legacy-sdk"]' "$TMP/d4.json"
drop "$FIX/plan.fixture.json" '["unstar:example-org/old-cli"]' >"$TMP/d5.json"
check "rejecting an unstar keeps the star" '.plan.unstar == []' "$TMP/d5.json"
drop "$CPLAN" '["merge:nope"]' >"$TMP/d6.json" 2>&1
exits "an unknown id is an error" 5 $? "$TMP/d6.json"
for f in d1 d2 d3 d4; do
  jq '.plan' "$TMP/$f.json" >"$TMP/$f-plan.json"
  jq -L "$JQ" --slurpfile stars "$TMP/stars.json" --slurpfile cls "$TMP/cls.json" -f "$JQ/validate.jq" "$TMP/$f-plan.json" >"$TMP/$f-v.json"
  check "the plan left after dropping ($f) is valid" '. == []' "$TMP/$f-v.json"
done
D=$(make_data_dir drop-sh)
cp "$CPLAN" "$D/plan.json"
STAR_CHART_DIR="$D" bash "$SCRIPTS/plan.sh" drop merge:parsing\ libs >"$TMP/drop-sh.out" 2>&1
exits "plan.sh drop succeeds" 0 $? "$TMP/drop-sh.out"
contains "and names what else it dropped" 'Also dropped, because it depended on that: delete:parsing libs' "$TMP/drop-sh.out"
check "plan.sh drop rewrites plan.json" '.merges == []' "$D/plan.json"

jq -s -L "$JQ" -f "$JQ/runs.jq" "$FIX/changes.fixture.jsonl" >"$TMP/runs.json"
check "the run list is newest first with what each run changed" '[.[] | {run_id, changed, uncertain}] == [{"run_id":"D1","changed":{"delete_list":1},"uncertain":0},{"run_id":"R2","changed":{"set_lists":1},"uncertain":0},{"run_id":"R1","changed":{"create_list":1,"rename_list":1,"set_lists":2,"unstar":1},"uncertain":1}]' "$TMP/runs.json"

D=$(make_data_dir runs)
cp "$FIX/changes.fixture.jsonl" "$D/changes-2026-06-15.jsonl"
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --list-runs >"$TMP/runs.out" 2>&1
contains "undo lists the recorded runs" 'R1  2026-06-15T01:00:00Z  example-user  1 create_list, 1 rename_list, 2 set_lists, 1 unstar, 1 uncertain' "$TMP/runs.out"
STAR_CHART_DIR="$D" bash "$SCRIPTS/undo.sh" --run R2 >"$TMP/undo-byrun.out" 2>&1
contains "undo finds a run without being told its log" 'boundary/protect-edge  remove ["Command Line" (UL_2)]' "$TMP/undo-byrun.out"
contains "and prints the command without a log path" 'undo.sh --run R2 --approved' "$TMP/undo-byrun.out"

echo "# lib.sh response handling"
# shellcheck source=../lib.sh
. "$SCRIPTS/lib.sh"
NOW=1781481600
resp() { # <file> <status line> <header lines, \n separated> <body>
  { printf '%s\r\n' "$2"; [ -n "$3" ] && printf '%s\n' "$3" | sed 's/$/\r/'; printf '\r\n%s' "$4"; } >"$TMP/$1"
}
verdict_is() { # <name> <file> <expected>
  local got
  got=$(sc_response_verdict "$TMP/$2" "$NOW")
  if [ "$got" = "$3" ]; then ok "$1"; else not_ok "$1" "expected '$3', got '$got'"; fi
}
resp r200 'HTTP/2.0 200 OK' 'Content-Type: application/json' '{"data":{"viewer":{"login":"x"}}}'
verdict_is "200 is ok" r200 ok
resp r204 'HTTP/2.0 204 No Content' 'X-Ratelimit-Remaining: 10' ''
verdict_is "204 with no body is ok" r204 ok
resp r403 'HTTP/2.0 403 Forbidden' "X-Ratelimit-Remaining: 0
X-Ratelimit-Reset: $((NOW + 30))" '{"message":"API rate limit exceeded"}'
verdict_is "primary rate limit waits until reset" r403 'retry 30'
resp r429 'HTTP/2.0 429 Too Many Requests' 'Retry-After: 7' '{"message":"slow down"}'
verdict_is "Retry-After is honored" r429 'retry 7'
resp r403s 'HTTP/2.0 403 Forbidden' 'X-Ratelimit-Remaining: 4000' '{"message":"You have exceeded a secondary rate limit."}'
verdict_is "secondary rate limit waits a minute" r403s 'retry 60'
resp r403p 'HTTP/2.0 403 Forbidden' 'X-Ratelimit-Remaining: 4000' '{"message":"Resource not accessible by personal access token"}'
verdict_is "a permission 403 fails without retrying" r403p fail
resp r404 'HTTP/2.0 404 Not Found' '' '{"message":"Not Found"}'
verdict_is "404 fails" r404 fail
resp r502 'HTTP/2.0 502 Bad Gateway' '' ''
verdict_is "5xx retries" r502 'retry 5'
resp rgql 'HTTP/2.0 200 OK' '' '{"errors":[{"type":"RATE_LIMITED","message":"API rate limit exceeded"}]}'
verdict_is "GraphQL RATE_LIMITED retries" rgql 'retry 60'
resp rgqlerr 'HTTP/2.0 200 OK' '' '{"data":null,"errors":[{"type":"NOT_FOUND","message":"Could not resolve"}]}'
verdict_is "other GraphQL errors fail" rgqlerr fail
resp rtrunc 'HTTP/2.0 200 OK' '' '{"data":'
verdict_is "a 200 whose body is cut off is an unknown outcome" rtrunc unknown
resp rnotjson 'HTTP/2.0 200 OK' '' 'garbled'
verdict_is "a 200 whose body is not JSON is an unknown outcome" rnotjson unknown
: >"$TMP/rempty"
verdict_is "no response at all is an unknown outcome" rempty unknown
body=$(sc_response_body "$TMP/r200")
if [ "$body" = '{"data":{"viewer":{"login":"x"}}}' ]; then ok "body is separated from CRLF headers"; else not_ok "body is separated from CRLF headers" "$body"; fi

echo "# jq lint"
# Inside "$x | index([.])", "." is $x, not the value meant; bind it first
# ('. as $id | ... index([$id])'). This slip recurred while writing these
# filters, so no filter may use "index([." at all.
if grep -nE 'index\(\[\.' "$JQ"/*.jq >"$TMP/jq-lint.txt"; then
  not_ok "no jq filter indexes with \".\" inside index([...])" "$(cat "$TMP/jq-lint.txt")"
else
  ok "no jq filter indexes with \".\" inside index([...])"
fi

echo "# write-paths.md: every test the audit names passed in this run"
# Each cell of the audit's path table names tests, separated by ";".
awk -F'|' '/^\| (apply|delete-lists|undo|categories|calls)/ { for (i = 3; i < NF; i++) print $i }' "$HERE/write-paths.md" \
  | tr ';' '\n' | sed 's/^ *//; s/ *$//; s/^e2e: //' | grep -v '^$' | grep -v '^n/a' >"$TMP/audit-names"
missing=$(grep -Fxv -f "$TMP/passed-names" "$TMP/audit-names" || true)
if [ "$(wc -l <"$TMP/audit-names" | tr -d ' ')" -gt 0 ] && [ -z "$missing" ]; then
  ok "every cell of the audit table names a test that passed ($(wc -l <"$TMP/audit-names" | tr -d ' ') names)"
else
  not_ok "every cell of the audit table names a test that passed" "$missing"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
