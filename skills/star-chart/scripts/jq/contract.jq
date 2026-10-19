# contract.jq: the one check every star-chart write is held to. Included by
# apply-step.jq and undo-step.jq.
#
# A requirement names one List and the state it must be in now:
#   {id, name, isPrivate}                 by id, never looked up by name
#   {create: <op key>, name, isPrivate}   a List this plan created, found
#                                         only through this plan's own log
#   ... description                       compared too when present
#   ... may_be_gone: true                 the List may no longer exist
#   ... unrecorded: true                  the log has no state for it: unmet
#
# sc_unmet($r; $is; $created; $preflight; $also): null when $r holds, else
# why not. $is: Lists now, by id. $created: {op key: List id}. In a preflight
# (every call checked before the first is made), a List another call of this
# plan creates is not there yet. $also: {List id: another state that also
# holds}, the state another step of the same run or undo legitimately leaves
# it in: before apply's renames run (preflight), the state a rename requires;
# during an undo, the state a completed rename back restored.

def sc_vis: if . then "private" else "public" end;

def sc_state_text: "\(.name | @json), \(.isPrivate | sc_vis)";

def sc_matches($r): .name == $r.name and .isPrivate == $r.isPrivate
  and ($r.description == null or .description == $r.description);

def sc_unmet($r; $is; $created; $preflight; $also):
  (if $r.create != null then ($created[$r.create] // null) else $r.id end) as $id
  | (if $id == null then null else $is[$id] end) as $l
  | if $r.unrecorded then "the log does not record the state of List \($r.id); it cannot be checked"
    elif $r.create != null and $id == null then
      (if $preflight then null else "List \($r.name | @json) was not created" end)
    elif $l == null then (if $r.may_be_gone then null else "List \($r.name | @json) no longer exists" end)
    elif ($l | sc_matches($r)) then null
    elif $also[$id] != null and ($l | sc_matches($also[$id] + {description: null})) then null
    else "\($l.name | @json) is \($l.isPrivate | sc_vis)"
         + (if $r.description != null and $l.description != $r.description
            then " and its description has changed" else "" end)
         + "; it must be \($r | sc_state_text)" end;

# sc_membership($current; $additions; $removals): the approved change applied
# to the Lists the repo is in now ($current): drop $removals, add the
# $additions it is not in yet, and leave every other List as it is, so a List
# added or removed elsewhere since the approval stays that way.
def sc_membership($current; $additions; $removals):
  [$current[] | . as $id | select(($removals | index([$id])) == null)]
  + [$additions[] | . as $id | select(($current | index([$id])) == null)];
