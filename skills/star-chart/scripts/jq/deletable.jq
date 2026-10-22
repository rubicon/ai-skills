# deletable.jq: which of the plan's deletions are safe right now.
#
#   jq -L scripts/jq --slurpfile lists <fresh Lists with items>
#      --slurpfile stars <stars.json> -f deletable.jq plan.json
#
# The approval names Lists; the export says which List each name meant. A
# List may be deleted only if that same List (by id) still exists under the
# approved name and a fresh read shows it empty. A different List that took
# the name since is never deleted. Anything else is skipped with the reason.
include "common";

($stars[0].lists | sc_index_by(.name)) as $E
| ($lists[0] | sc_index_by(.name)) as $byname
| ($lists[0] | map({key: .id, value: .}) | from_entries) as $byid
| [
    (.deletions // [])[] | .list as $n
    | $E[$n | ascii_downcase] as $e
    | (if $e == null then null else $byid[$e.id] end) as $l
    | if $e == null then {list: $n, why: "not in the export the approval was based on"}
      elif $l == null and $byname[$n | ascii_downcase] != null then {list: $n, why: "a different List has this name now"}
      elif $l == null then {list: $n, why: "no longer exists"}
      elif ($l.name | ascii_downcase) != ($n | ascii_downcase) then {list: $n, why: "renamed to \($l.name | @json) since the approval"}
      elif (($l.items // []) | length) > 0 then {list: $n, why: "still has \($l.items | length) repos"}
      else {delete: {list_id: $l.id, name: $l.name, description: $l.description, private: $l.isPrivate}} end
  ] as $all
| {delete: [$all[] | .delete // empty], skipped: [$all[] | select(.delete == null)]}
