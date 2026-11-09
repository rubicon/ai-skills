# apply-step.jq: decide one approved call against the Lists as they are now.
#
#   jq -n -L scripts/jq --argjson op <one op from ops.jq>
#      --slurpfile approved <the approved ops.jq output>
#      --slurpfile now <Lists with items, read just before this attempt>
#      --argjson created <{op key: List id} for Lists this plan created>
#      --argjson attempted <[create op keys whose attempt in this very call may have landed]>
#      --argjson preflight <true when checking every call before the first one>
#      -f apply-step.jq
#
# Result: {action: "call", variables, ...} to make the call; {action: "done"}
# when GitHub is already as the call would leave it; or {action: "refuse",
# reason} when the call's contract (ops.jq: "requires") does not hold. Every
# check is contract.jq's: Lists by id, every List the call names in exactly
# the state the approval requires. Membership applies only the approved
# change to the repo's Lists as they are now.
#
# A create is made only when no List has the name. A same-name List is taken
# up only in the re-check right after this run's own attempt that may have
# landed, if it did not exist at approval and has the approved visibility;
# found at any other time (a resumed run), it could be anyone's and is refused.
# Unstars pass through: apply.sh checks protection itself, right before each.
include "contract";

($approved[0].snapshot | map({key: .id, value: .}) | from_entries) as $was
| ($approved[0].ops | map(select(.op == "rename_list") | {key: .list_id, value: .requires}) | from_entries) as $pending
| ($now[0] | map({key: .id, value: .}) | from_entries) as $is
| def unmet($r): sc_unmet($r; $is; $created; $preflight; (if $preflight then $pending else {} end));
  if $op.op == "rename_list" then
    if unmet({id: $op.list_id} + $op.expects) == null then {action: "done"}
    else
      unmet({id: $op.list_id} + $op.requires) as $why
      | if $why == null then
          {action: "call", variables: ({listId: $op.list_id} + $op.expects | {listId, name, description, isPrivate})}
        else {action: "refuse", reason: $why} end
    end

  elif $op.op == "set_lists" then
    [$op.requires[] | unmet(.) // empty] as $why
    | if ($why | length) > 0 then {action: "refuse", reason: ($why | join("; "))}
      else
        [$op.requires[] | select(.may_be_gone | not)
          | if .create != null then $created[.create] else .id end | select(. != null)] as $targets
        | [$op.requires[] | select(.may_be_gone) | .id] as $removals
        | [$now[0][] | select(any(.items[]; .id == $op.item_id)) | .id] as $current
        | sc_membership($current; $targets - $op.before_ids; $removals) as $next
        # Privacy, judged on the repo's Lists right now: a repo only in
        # private Lists goes into a public one only as the approval
        # acknowledged (the same rule validate.jq applies to the plan).
        | [$op.requires[] | select((.may_be_gone | not) and (.isPrivate | not))
            | if .create != null then $created[.create] else .id end | select(. != null)
            | . as $id | select(($current | index([$id])) == null)] as $going_public
        | [$current[] | . as $id | select(($op.publishes_ids // []) | index([$id]) | not)] as $unacknowledged
        | if ($current | length) > 0 and all($current[]; $is[.].isPrivate) and ($going_public | length) > 0
             and ($unacknowledged | length) > 0 and ($op.allow_public | not) then
            {action: "refuse", reason: "\($op.repo) is only in private Lists now (\([$unacknowledged[] | $is[.].name | @json] | join(", "))); adding it to a public List needs the user's yes (plan.sh allow-public)"}
          elif ($next | sort) == ($current | sort) then {action: "done", before_ids: $current}
          else {action: "call", before_ids: $current, after_ids: $next,
                variables: {itemId: $op.item_id, listIds: $next}} end
      end

  elif $op.op == "create_list" then
    [$now[0][] | select((.name | ascii_downcase) == ($op.name | ascii_downcase))] as $same
    | if $created[$op.key] != null then {action: "done", list_id: $created[$op.key]}
      elif ($same | length) == 0 then
        {action: "call", variables: {name: $op.name, description: $op.description, isPrivate: $op.private}}
      elif ($attempted | index([$op.key])) != null and $was[$same[0].id] == null and $same[0].isPrivate == $op.private
        then {action: "done", list_id: $same[0].id, adopted: true}
      else {action: "refuse", reason: "a List named \($op.name | @json) already exists that this plan did not create (if an interrupted run made it, export again and plan again: it will be used as an existing List)"} end

  else {action: "call"} end
