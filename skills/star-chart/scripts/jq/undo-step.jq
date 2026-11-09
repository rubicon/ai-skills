# undo-step.jq: decide one reversal from undo.jq against the Lists as they are now.
#
#   jq -n -L scripts/jq --argjson step <one step from undo.jq>
#      --slurpfile now <Lists with items, read just before this attempt>
#      --argjson remap <{old List id: new id} for Lists undo recreated>
#      --argjson attempted <["undoes" ids whose recreate attempt in this very step may have landed]>
#      --argjson restored <{List id: state} that completed renames back restored>
#      -f undo-step.jq
#
# Result: {action: "call", variables}, {action: "done"} when GitHub is already
# as the reversal would leave it, or {action: "refuse", reason}. Every check
# is contract.jq's, the same one apply-step.jq uses: a List the repo goes back
# into must have the name and visibility the log recorded at the run; a List
# is renamed back only while it is as the run left it. A recreated List is
# followed by id through every recreation, never looked up by name. A
# membership reversal undoes only the run's own change (adds back the Lists it
# removed, removes the Lists it added); edits made since are kept.
#
# A deleted List is recreated only when no List has its name. A same-name List
# is taken up only in the re-check right after this step's own attempt that
# may have landed, with the recorded visibility; otherwise it is refused.
include "contract";

($now[0] | map({key: .id, value: .}) | from_entries) as $is
| def live: [limit(100; recurse(if $remap[.] != null then $remap[.] else empty end))] | last;
  # A List an undo already renamed back is in the state the run found it in:
  # that also holds, so an undo resumed after a failure can finish.
  ($restored | with_entries(.key |= live)) as $also
  | def unmet($r): sc_unmet($r; $is; {}; false; $also);
  if $step.op == "set_lists" then
    ($step.add | map(.id |= live)) as $add
    # A List the repo comes out of must also be as the run left it, or gone;
    # one whose state the log does not record is not checked (removing a repo
    # from a List cannot make anything public).
    | [$step.remove[] | select(.name != null) | .id |= live | . + {may_be_gone: true}] as $leave
    | [$add[], $leave[] | unmet(.) // empty] as $why
    | if ($why | length) > 0 then {action: "refuse", reason: ($why | join("; "))}
      else
        [$now[0][] | select(any(.items[]; .id == $step.item_id)) | .id] as $current
        | sc_membership($current; [$add[].id]; [$step.remove[].id | live]) as $next
        | if ($next | sort) == ($current | sort) then {action: "done"}
          else {action: "call", before_ids: $current, after_ids: $next,
                variables: {itemId: $step.item_id, listIds: $next}} end
      end

  elif $step.op == "rename_back" then
    ($step.list_id | live) as $id
    | if unmet({id: $id} + $step.expects) == null then {action: "done"}
      else
        unmet({id: $id} + $step.requires) as $why
        | if $why == null then
            {action: "call", variables: ({listId: $id} + $step.expects | {listId, name, description, isPrivate})}
          else {action: "refuse", reason: $why} end
      end

  elif $step.op == "recreate_list" then
    ($step.old_id | live) as $id
    | [$now[0][] | select((.name | ascii_downcase) == ($step.name | ascii_downcase))] as $same
    | if $id != $step.old_id and $is[$id] != null then {action: "done", new_id: $id}
      elif ($same | length) == 0 then
        {action: "call", variables: {name: $step.name, description: $step.description, isPrivate: $step.private}}
      elif ($attempted | index([$step.undoes])) != null and $same[0].isPrivate == $step.private then
        {action: "done", new_id: $same[0].id, adopted: true}
      else {action: "refuse", reason: "a List named \($step.name | @json) already exists; not reusing it"} end

  else {action: "call"} end
