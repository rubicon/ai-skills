#!/usr/bin/env bash
# export.sh: read every star and every List into stars.json. Read-only.
#
# Usage: bash export.sh
#
# Writes $STAR_CHART_DIR/stars.json (default ~/.star-chart). Each star carries
# full_name, description, url, language, topics, stargazers_count, archived,
# pushed_at, starred_at, the Lists it is in, and "new": true when it was
# starred after the export the last fully applied plan was built from. Makes only GET and GraphQL query calls;
# nothing on GitHub changes.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

sc_need_jq
sc_need_gh
sc_init_dir

work=$(mktemp -d "${TMPDIR:-/tmp}/star-chart.XXXXXX")
trap 'rm -rf "$work"' EXIT

# Stars count as new since the export the last fully applied plan was built
# from, not since the last export, so unfinished cleanup is proposed again.
previous=$(sc_previous_export)

login=$(gh api user --jq .login)
expected=$(gh api graphql -f query='{ viewer { starredRepositories { totalCount } } }' \
  --jq '.data.viewer.starredRepositories.totalCount')

# The export's time, taken before anything is read: a star added while the
# export runs is then newer than it, and the next export proposes it. One
# second earlier still, so a star from the same second is proposed again
# rather than missed.
exported_at=$(jq -n -r --arg t "$(sc_now)" '$t | fromdateiso8601 - 1 | todateiso8601')

echo "Reading $expected stars for $login..." >&2
# The star+json media type wraps each repo as {starred_at, repo}.
gh api --paginate -H 'Accept: application/vnd.github.star+json' 'user/starred?per_page=100' \
  --jq '.[]' | jq -s . >"$work/starred.json"

echo "Reading Lists..." >&2
sc_fetch_lists >"$work/lists.json"

jq -n -L "$SC_JQ" \
  --slurpfile starred "$work/starred.json" --slurpfile lists "$work/lists.json" \
  --arg exported_at "$exported_at" --arg login "$login" --arg previous "$previous" \
  -f "$SC_JQ/normalize.jq" >"$work/stars.json"

count=$(jq '.stars | length' "$work/stars.json")
if [ "$count" -ne "$expected" ]; then
  sc_note "warning: GitHub reports $expected stars but the export holds $count (stars added or removed during the export can cause this)."
fi

mv "$work/stars.json" "$SC_DIR/stars.json"

jq -r --arg dir "$SC_DIR" '
  "Exported \(.stars | length) stars and \(.lists | length) Lists for \(.login) to \($dir)/stars.json.",
  (if .previous_export_at == null then "No plan has been fully applied yet, so every star counts as new."
   else "\([.stars[] | select(.new)] | length) starred since the last fully applied plan'"'"'s export (\(.previous_export_at))." end),
  "\([.stars[] | select(.list_ids == [])] | length) stars are in no List.",
  "Nothing on GitHub was changed."' "$SC_DIR/stars.json"
