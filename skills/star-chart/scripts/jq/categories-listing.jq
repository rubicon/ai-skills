# categories-listing.jq: print a plan's category changes for approval, with
# each change's size, visibility and reason, and a separate warning for any
# change that makes private categorization public.
#
#   jq -r -L scripts/jq --slurpfile stars stars.json -f categories-listing.jq plan.json
include "common";

def vis: if . then "private" else "public" end;
def why: "      Why: \(.reason // "")";
def repos: "\(.) repo\(if . == 1 then "" else "s" end)";

($stars[0]) as $S
| ($S.lists | sc_index_by(.name)) as $by
| sc_final_lists($S) as $final
| sc_exposure($S) as $exposure
| def members($id): [$S.stars[] | select(.list_ids | index([$id]))];
  if (sc_categories | [.[] | length] | add) == 0 then "No category changes in this plan."
  else
    "Category changes in this plan:",
    "",
    ((.lists_to_create // [])[]
      | "  + create List \(.name | @json) (\(.private // false | vis)): \(.description // "")", why),
    ((.renames // [])[] | $by[.list | ascii_downcase] as $l
      | "  ~ rename \(.list | @json) -> \(.to | @json) (\($l.item_count | repos), \(
          if .private == null or .private == $l.isPrivate then "\($l.isPrivate | vis), stays \($l.isPrivate | vis)"
          else "\($l.isPrivate | vis) -> \(.private | vis)" end))\(
          if .description != null and .description != $l.description then "; new description: \(.description | @json)" else "" end)",
        why),
    ((.merges // [])[] | . as $m | sc_final_list($final; .into) as $t
      | (.lists[] | $by[ascii_downcase] as $l | members($l.id) as $mem
          | ([$mem[] | select($t.id != null and (.list_ids | index([$t.id])))] | length) as $there
          | "  > merge \($l.name | @json) (\($l.item_count | repos), \($l.isPrivate | vis)) into \($t.name | @json) (\($t.private | vis)): \($there) already there, \((($mem | length) - $there) as $n | "\($n) \(if $n == 1 then "moves" else "move" end)")"),
        ($m | why)),
    ((.deletions // [])[] | $by[.list | ascii_downcase] as $l
      | "  - delete List \(.list | @json) (\($l.item_count | repos) now, \($l.isPrivate | vis)); runs later, with its own approval",
        why),
    (if ($exposure | length) > 0 then
       "",
       "Private to public: approving this makes these visible to anyone:",
       ($exposure[]
         | if .kind == "rename" then "  ! \(.list | @json) (\(.repos | repos)) becomes public"
           else "  ! \(.list | @json) is private; its \(.repos | repos) \(if .repos == 1 then "joins" else "join" end) public \(.into | @json)" end),
       "Approve only with: plan.sh approve-categories <hash> --publishes-private"
     else empty end)
  end
