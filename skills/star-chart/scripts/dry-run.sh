#!/usr/bin/env bash
# dry-run.sh: print every write call apply.sh would make, with counts.
#
# Usage: bash dry-run.sh
#
# Makes no API calls and changes no file: everything it computes goes to a
# temporary directory. Ends with an approval hash over the plan and these
# exact calls, which apply.sh requires as --approved.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

sc_need_jq
sc_require stars.json rules.md plan.json

work=$(mktemp -d "${TMPDIR:-/tmp}/star-chart.XXXXXX")
trap 'rm -rf "$work"' EXIT

sc_classify_to "$SC_DIR/stars.json" "$work/classification.json"
sc_validate "$SC_DIR/plan.json" "$SC_DIR/stars.json" "$work/classification.json" || exit 1
sc_check_categories "$SC_DIR/plan.json" || exit 1
sc_check_exposure "$SC_DIR/plan.json" "$SC_DIR/stars.json" || exit 1

plan_export=$(jq -r '.based_on_export // ""' "$SC_DIR/plan.json")
star_export=$(jq -r '.exported_at' "$SC_DIR/stars.json")
if [ -n "$plan_export" ] && [ "$plan_export" != "$star_export" ]; then
  sc_note "note: the plan was written from the export of $plan_export, but stars.json is from $star_export."
fi

jq -L "$SC_JQ" --slurpfile stars "$SC_DIR/stars.json" -f "$SC_JQ/ops.jq" "$SC_DIR/plan.json" >"$work/ops.json"
target=$(sc_rules_json | jq -r '.target_lists // ""')
jq -r --arg target "$target" -f "$SC_JQ/dry-run.jq" "$work/ops.json"

sha=$(sc_approval_hash "$SC_DIR/plan.json" "$SC_DIR/stars.json")
cat <<MSG

Before writing, apply.sh checks the signed-in account, re-reads your Lists (read-only),
and refuses if any repo would now leave a List in a way this listing does not show.

Plan: $SC_DIR/plan.json
Approval SHA-256: $sha
Nothing was changed. After an explicit yes, run:
  $(sc_run_prefix)bash $(cd "$(dirname "$0")" && pwd)/apply.sh --approved $sha
MSG
