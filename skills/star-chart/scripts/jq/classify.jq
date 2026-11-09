# classify.jq: apply the rules to every star, and describe every List.
#
#   jq -L scripts/jq --argjson rules <rules> --arg now <ISO>
#      (--slurpfile prev <classification.prev.json> | --argjson prev '[]')
#      -f classify.jq stars.json
#
# "flagged" lists unstar candidates with their reasons. "protected" lists the
# stars that may never be unstarred (keep-always pattern, or starred inside the
# protection window) along with whatever flags they would otherwise carry.
# newly_flagged is false only for repos the previous classification flagged.
# "lists" gives each List's size, flagged members, top languages and overlap
# with other Lists, which is what a consolidation proposal starts from.
include "common";

. as $doc
| ($now | sc_months_before($rules.stale_months)) as $cutoff
| ($now | sc_days_before($rules.protect_days)) as $since
| (($prev[0] // null) | if . == null then null else [.flagged[].repo] end) as $before
| [
    $doc.stars[]
    | ((.description // "") | ascii_downcase) as $desc
    | {
        repo: .full_name,
        new,
        reasons: [
          (if $rules.flag_archived and .archived then "archived" else empty end),
          (if .pushed_at == null then "never pushed"
           elif .pushed_at < $cutoff then "no push since \(.pushed_at[0:10])"
           else empty end),
          ($rules.deprecated_terms[] | select(. as $t | $desc | contains($t))
           | "description mentions \"\(.)\"")
        ],
        protected: (
          if (.full_name | sc_matches_any($rules.keep_always)) then "keep-always pattern"
          elif .starred_at >= $since then "starred within the last \($rules.protect_days) days"
          else null end
        )
      }
  ]
| [.[] | select(.protected == null and (.reasons | length) > 0)] as $flagged
| ($flagged | map(.repo)) as $flagged_repos
| {
    now: $now,
    stale_cutoff: $cutoff,
    protect_since: $since,
    flagged: [
      $flagged[] | .repo as $r
      | {repo, new, reasons, newly_flagged: ($before == null or ($before | any(.[]; . == $r) | not))}
    ],
    protected: [.[] | select(.protected != null) | {repo, reason: .protected, reasons}],
    lists: [
      $doc.lists[] | .id as $id
      | [$doc.stars[] | select(.list_ids | index([$id]))] as $members
      | {
          name,
          repos: ($members | length),
          flagged: ([$members[] | select(.full_name as $r | $flagged_repos | index([$r]))] | length),
          top_languages: ($members | map(.language // "none") | group_by(.)
                          | map({language: .[0], n: length}) | sort_by(-.n) | .[:3] | map(.language)),
          overlaps: ([
            $doc.lists[] | select(.id != $id) | .id as $other
            | {list: .name, shared: ([$members[] | select(.list_ids | index([$other]))] | length)}
            | select(.shared > 0)
          ] | sort_by(-.shared))
        }
    ],
    unlisted: ([$doc.stars[] | select(.list_ids == [])] | length)
  }
