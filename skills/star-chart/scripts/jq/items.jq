# items.jq: every proposed change as a reviewable item, for the approval
# pop-ups. Each item has a stable id that plan.sh drop accepts.
#
#   jq -L scripts/jq --slurpfile stars stars.json -f items.jq plan.json
#
# categories: one item per List creation, rename, merge source and deletion,
#   with a short label, the detail (size, visibility, what moves), the reason,
#   and "publishes" when approving it makes private categorization public.
# assignment_groups: the repos the plan adds to each List, one group per List.
# unstars: one item per repo to unstar, with its reason.
include "common";

def vis: if . then "private" else "public" end;
def repos: "\(.) repo\(if . == 1 then "" else "s" end)";

($stars[0]) as $S
| ($S.lists | sc_index_by(.name)) as $by
| sc_final_lists($S) as $final
| ([sc_exposure($S)[] | "\(.kind):\(.list | ascii_downcase)"]) as $pub
| def members($id): [$S.stars[] | select(.list_ids | index([$id]))];
  def published($id): $pub | index([$id]) != null;
  {
    categories: [
      ((.lists_to_create // [])[]
        | {id: "create:\(.name | ascii_downcase)", kind: "create",
           label: "Create List \(.name | @json) (\(.private // false | vis))",
           detail: (.description // ""), reason: (.reason // ""), publishes: false}),
      ((.renames // [])[] | $by[.list | ascii_downcase] as $l
        | "rename:\(.list | ascii_downcase)" as $id
        | {id: $id, kind: "rename", label: "Rename \(.list | @json) to \(.to | @json)",
           detail: "\($l.item_count | repos), \(if .private == null or .private == $l.isPrivate
                    then "stays \($l.isPrivate | vis)" else "\($l.isPrivate | vis) -> \(.private | vis)" end)",
           reason: (.reason // ""), publishes: published($id)}),
      ((.merges // [])[] | . as $m | sc_final_list($final; .into) as $t
        | .lists[] | $by[ascii_downcase] as $l | members($l.id) as $mem
        | ([$mem[] | select($t.id != null and (.list_ids | index([$t.id])))] | length) as $there
        | (($mem | length) - $there) as $moves
        | "merge:\($l.name | ascii_downcase)" as $id
        | {id: $id, kind: "merge", label: "Merge \($l.name | @json) into \($t.name | @json)",
           detail: "\($l.item_count | repos), \($l.isPrivate | vis) into \($t.private | vis): \($there) already there, \($moves) \(if $moves == 1 then "moves" else "move" end)",
           reason: ($m.reason // ""), publishes: published($id)}),
      ((.deletions // [])[] | $by[.list | ascii_downcase] as $l
        | {id: "delete:\(.list | ascii_downcase)", kind: "delete", label: "Delete List \(.list | @json) once empty",
           detail: "\($l.item_count | repos) now, \($l.isPrivate | vis)", reason: (.reason // ""), publishes: false})
    ],
    assignment_groups: (
      sc_assignment_exposure($S) as $ax
      | [(.assignments // [])[] as $a | $a.lists[] | {list: ., repo: $a.repo}]
      | group_by(.list | ascii_downcase)
      | map((.[0].list) as $l | [.[].repo] as $r
            | {id: "assign-list:\($l | ascii_downcase)", list: $l, repos: $r}
            + ([$ax[] | select(any(.lists[]; ascii_downcase == ($l | ascii_downcase))) | .repo
                | select(. as $x | $r | index([$x]))] as $p
               | if ($p | length) > 0 then {private_repos: $p} else {} end))
    ),
    unstars: [(.unstar // [])[] | {id: "unstar:\(.repo | ascii_downcase)", repo, reason}]
  }
