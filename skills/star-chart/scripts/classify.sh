#!/usr/bin/env bash
# classify.sh: apply rules.md to stars.json. Local only.
#
# Usage: bash classify.sh
#
# Writes $STAR_CHART_DIR/classification.json: "flagged" holds unstar
# candidates and their reasons (archived, stale, deprecated wording);
# "protected" holds stars that may never be unstarred (keep-always patterns
# and stars inside the protection window). Claude proposes unstars only from
# "flagged"; validate.jq rejects any plan that touches "protected".
set -euo pipefail
. "$(dirname "$0")/lib.sh"

sc_need_jq
sc_require stars.json rules.md
sc_classify_to "$SC_DIR/stars.json" "$SC_DIR/classification.json.tmp"
mv "$SC_DIR/classification.json.tmp" "$SC_DIR/classification.json"

jq -r --arg dir "$SC_DIR" '
  "Wrote \($dir)/classification.json (stale cutoff \(.stale_cutoff[0:10]), protected since \(.protect_since[0:10])).",
  "Flagged: \(.flagged | length) (\([.flagged[] | select(.newly_flagged)] | length) newly flagged, \([.flagged[] | select(.new)] | length) among new stars)",
  "  archived: \([.flagged[] | select(.reasons | index(["archived"]))] | length)",
  "  stale or never pushed: \([.flagged[] | select(any(.reasons[]; test("^(no push since|never pushed)")))] | length)",
  "  deprecated wording: \([.flagged[] | select(any(.reasons[]; startswith("description mentions")))] | length)",
  "Protected: \(.protected | length) (\([.protected[] | select(.reason == "keep-always pattern")] | length) keep-always, \([.protected[] | select(.reason != "keep-always pattern")] | length) recent)"
' "$SC_DIR/classification.json"
