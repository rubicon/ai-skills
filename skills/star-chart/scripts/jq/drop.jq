# drop.jq: remove the items the user rejected, and whatever depended on them.
#
#   jq -L scripts/jq --argjson ids '["merge:plex", ...]' -f drop.jq plan.json
#
# Ids come from items.jq, plus "assign:<owner/repo>" for one repo's
# assignment. Rejecting:
#   create:<name>       drops the new List, its name from assignments (an
#                       assignment left with no List goes too), and merges into it
#   rename:<list>       points everything that used the new name back at the old one
#   merge:<list>        drops that source from its merge, and its deletion
#                       (the List keeps its repos, so it will not be empty)
#   delete:<list>       keeps the List
#   assign-list:<name>  drops the plan's additions to that List
#   assign:<repo>       drops that repo's assignment
#   unstar:<repo>       keeps the star
# Prints {plan, dropped, cascaded}; an unknown id is an error.
include "common";

def low: ascii_downcase;
def ids($prefix): [$ids[] | select(startswith($prefix + ":")) | sub("^[^:]+:"; "")];

. as $p
| ([((.lists_to_create // [])[] | "create:\(.name | low)"), ((.renames // [])[] | "rename:\(.list | low)"),
    ((.merges // [])[].lists[] | "merge:\(low)"), ((.deletions // [])[] | "delete:\(.list | low)"),
    ((.assignments // [])[] | "assign:\(.repo | low)"), ((.assignments // [])[].lists[] | "assign-list:\(low)"),
    ((.unstar // [])[] | "unstar:\(.repo | low)")] | unique) as $valid
| ([$ids[] | select(. as $i | $valid | index([$i]) | not)]) as $unknown
| if ($unknown | length) > 0 then error("unknown item ids: \($unknown | join(", "))") else . end
| ids("create") as $c | ids("rename") as $r | ids("merge") as $m | ids("delete") as $d
| ids("assign") as $a | ids("assign-list") as $al | ids("unstar") as $u
| ([(.renames // [])[] | select((.list | low) as $n | $r | index([$n])) | {key: (.to | low), value: .list}]
   | from_entries) as $back
| def fix: (low) as $k | ($back[$k] // .);
  # Merges whose target is a rejected new List go entirely.
  ([(.merges // [])[] | select((.into | low) as $i | $c | index([$i])) | .lists[] | low]) as $orphaned
| (($m + $orphaned) | unique) as $unmerged
| .lists_to_create = [(.lists_to_create // [])[] | select((.name | low) as $n | $c | index([$n]) | not)]
| .renames = [(.renames // [])[] | select((.list | low) as $n | $r | index([$n]) | not)]
| .merges = [(.merges // [])[] | .into |= fix
             | .lists = [.lists[] | select((low) as $n | $unmerged | index([$n]) | not)]
             | select(.lists | length > 0)]
| .deletions = [(.deletions // [])[] | select((.list | low) as $n | ($d + $unmerged) | index([$n]) | not)]
| .assignments = [(.assignments // [])[]
                  | select((.repo | low) as $n | $a | index([$n]) | not)
                  | .lists = [.lists[] | select((low) as $n | ($c + $al) | index([$n]) | not) | fix]]
| ([.assignments[] | select(.lists == []) | "assign:\(.repo | low)"]) as $emptied
| .assignments = [.assignments[] | select(.lists != [])]
| .unstar = [(.unstar // [])[] | select((.repo | low) as $n | $u | index([$n]) | not)]
| {
    plan: .,
    dropped: $ids,
    cascaded: (
      [($orphaned[] | "merge:\(.)"),
       ($unmerged[] | . as $n | select($p.deletions // [] | any(.[]; (.list | low) == $n)) | "delete:\($n)"),
       $emptied[]]
      | map(select(. as $i | $ids | index([$i]) | not)) | unique
    )
  }
