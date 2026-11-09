# normalize.jq: build stars.json from a raw export.
#
#   jq -n -L scripts/jq --slurpfile starred <raw> --slurpfile lists <lists>
#      --arg exported_at <ISO> --arg login <login> --arg previous <ISO or "">
#      -f normalize.jq
#
# $starred[0] is the array from GET /user/starred with the star+json media
# type ({starred_at, repo}). $previous is the exported_at of the last export,
# or "" on the first one; a star is "new" when it was starred after it.
include "common";

{
  exported_at: $exported_at,
  login: $login,
  previous_export_at: (if $previous == "" then null else $previous end),
  lists: [],
  stars: [
    $starred[0][]
    | .starred_at as $at
    | .repo
    | {
        full_name,
        node_id,
        description,
        url: .html_url,
        language,
        topics: (.topics // []),
        stargazers_count,
        archived,
        pushed_at,
        starred_at: $at,
        new: ($previous == "" or $at > $previous)
      }
  ]
}
| sc_apply_membership($lists[0])
