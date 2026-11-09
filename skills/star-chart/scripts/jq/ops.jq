# ops.jq: turn a validated plan into the ordered write calls.
#
#   jq -L scripts/jq --slurpfile stars stars.json -f ops.jq plan.json
#
# "ops" runs in apply.sh, in this order: rename Lists, set the membership of
# repos whose target Lists already exist, unstar, create Lists, then set the
# membership of repos that need a created List. Creating last means a limit
# on the number of Lists can be met by deleting the emptied Lists first and
# re-running. Merges and assignments fold into one updateUserListsForItem per
# repo, because that call replaces a repo's whole membership: after = current
# Lists, minus merged-away Lists, plus each merge target, plus assigned
# Lists, without duplicates. An "after" entry with an id is an existing List;
# one without is created by this plan and resolved by name at apply time. A
# repo whose membership would not change gets no call. "publishes" names the
# private Lists whose membership a call moves into a public List. Every op has
# a "key" that stays the same across runs, so a re-run can skip finished ones.
# "deletions" is not run by apply.sh; delete-lists.sh runs it after the moves,
# with its own approval. Names match ignoring case. "snapshot" is every List
# as the approval saw it.
#
# Each call carries its contract, which apply-step.jq checks right before
# every attempt. A membership call "requires" each List the repo ends up in
# to be in its final approved state (name and visibility after this plan's
# renames; a List this plan creates, as created), and each List it leaves to
# be as approved, or gone. A rename "requires" the List's name, description
# and visibility as approved and "expects" the ones it gives it. An unstar
# carries the state of the Lists the repo was in, for undo. "publishes_ids"
# names the private Lists whose move into public view the approval
# acknowledged for that repo, and "allow_public" the user's plan.sh
# allow-public for it; apply-step.jq refuses any other at the call.
include "common";

($stars[0]) as $S
| ($S.lists | sc_index_by(.name)) as $byname
| ((.renames // []) | sc_index_by(.list)) as $ren
| (reduce ((.merges // [])[] | .into as $into | .lists[] | {k: ascii_downcase, into: $into}) as $p
    ({}; .[$p.k] = $p.into)) as $merge_into
| ($S.lists | map({key: .id, value: ($ren[.name | ascii_downcase].to // .name)}) | from_entries) as $final_name
| ($S.lists | map({key: .id, value: ($ren[.name | ascii_downcase].private as $p | if $p == null then .isPrivate else $p end)})
   | from_entries) as $final_private
| ($S.lists | map({key: .id, value: .}) | from_entries) as $byid
| ((.lists_to_create // []) | map({key: (.name | ascii_downcase), value: (.private // false)}) | from_entries) as $create_private
| (($S.lists | map(select($merge_into[.name | ascii_downcase] == null))
    | map({key: ($final_name[.id] | ascii_downcase), value: {id, name: $final_name[.id]}}) | from_entries)
   + ((.lists_to_create // []) | map({key: (.name | ascii_downcase), value: {name}}) | from_entries)) as $target
| ((.assignments // []) | map({key: (.repo | ascii_downcase), value: [.lists[] | $target[ascii_downcase]]})
   | from_entries) as $assign
| ([sc_exposure($S)[] | select(.kind == "merge") | .list]) as $exposed
| (sc_assignment_exposure($S) | map({key: (.repo | ascii_downcase), value: .private}) | from_entries) as $exposed_by_assign
| ((.publish_private // []) | map(ascii_downcase)) as $ack
| def key: .id // ("new:" + .name);
  [
    $S.stars[] as $s
    | [
        ($s.list_ids[] as $id | $S.lists[] | select(.id == $id)
          | if $merge_into[.name | ascii_downcase] != null
            then $target[$merge_into[.name | ascii_downcase] | ascii_downcase]
            else {id, name: $final_name[.id]} end),
        ($assign[$s.full_name | ascii_downcase] // [])[]
      ]
    | reduce .[] as $t ([]; if any(.[]; key == ($t | key)) then . else . + [$t] end)
    | select((map(key) | sort) != ($s.list_ids | sort))
    | . as $after
    | {op: "set_lists", key: "set:\($s.node_id)", repo: $s.full_name, item_id: $s.node_id,
       before_ids: $s.list_ids, before_names: $s.lists, after: .,
       requires: ([$after[] | if .id != null then {id, name, isPrivate: $final_private[.id]}
                   else {create: "create:\(.name | ascii_downcase)", name, isPrivate: $create_private[.name | ascii_downcase]} end]
                  + [($s.list_ids - [$after[] | .id // empty])[] as $id | $byid[$id]
                     | {id, name, isPrivate, may_be_gone: true}]),
       publishes: ([$s.lists[] | select(. as $n | $exposed | index([$n]))]
                   + ($exposed_by_assign[$s.full_name | ascii_downcase] // []) | unique),
       publishes_ids: ([$s.list_ids[] as $id | $byid[$id] | select(.name as $n | $exposed | index([$n])) | .id]
                       + (if $exposed_by_assign[$s.full_name | ascii_downcase] != null then $s.list_ids else [] end)
                       | unique),
       allow_public: (($ack | index([$s.full_name | ascii_downcase])) != null)}
  ] as $sets
| ($S.stars | sc_index_by(.full_name)) as $repos
| {
    ops: (
      [(.renames // [])[] | $byname[.list | ascii_downcase] as $l
        | {op: "rename_list", key: "rename:\($l.id)", list_id: $l.id, from: $l.name, to,
           description: (if .description == null then $l.description else .description end),
           private: (if .private == null then $l.isPrivate else .private end),
           before: {name: $l.name, description: $l.description, isPrivate: $l.isPrivate}}
        | . + {requires: .before,
               expects: {name: .to, description: .description, isPrivate: .private}}]
      + [$sets[] | select(all(.after[]; .id != null))]
      + [(.unstar // [])[] | $repos[.repo | ascii_downcase]
        | {op: "unstar", key: "unstar:\(.node_id)", repo: .full_name, item_id: .node_id, starred_at,
           list_ids, list_names: .lists,
           lists: ([.list_ids[] | $byid[.] | {key: .id, value: {name, isPrivate}}] | from_entries)}]
      + [(.lists_to_create // [])[]
        | {op: "create_list", key: "create:\(.name | ascii_downcase)", name,
           description: (.description // ""), private: (.private // false)}]
      + [$sets[] | select(any(.after[]; .id == null))]
    ),
    deletions: [(.deletions // [])[] | $byname[.list | ascii_downcase]
      | {op: "delete_list", list_id: .id, name, description, private: .isPrivate}],
    unchanged: [(.assignments // [])[] | $repos[.repo | ascii_downcase].full_name as $r
      | select(all($sets[]; .repo != $r)) | $r],
    snapshot: [$S.lists[] | {id, name, isPrivate}],
    lists_now: ($S.lists | length),
    lists_after: (($S.lists | length) - ((.deletions // []) | length) + ((.lists_to_create // []) | length))
  }
