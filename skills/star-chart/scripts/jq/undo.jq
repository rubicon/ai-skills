# undo.jq: turn a change log into the calls that reverse it.
#
#   jq -s -L scripts/jq --arg run <run_id or ""> --slurpfile all <every record
#      from every change log in the data directory> -f undo.jq <log>
#
# Every change is logged twice: "started" (with the state before it) just
# before the call, then its outcome. A change with an "ok" outcome is
# reversed. A change with no outcome, interrupted mid-call, is "uncertain"
# and reversed too, since each reversal is safe to repeat (undo.sh skips
# recreating a List whose name already exists). Failed, refused and
# already-existing changes are not reversed. Newest first:
#   unstar      -> re-star, then add the repo back to the Lists it was in
#   set_lists   -> add back the Lists the run removed, remove the ones it added
#   rename_list -> rename back (the recreated List, if it was deleted since)
# Each step carries its contract, built from the state the log recorded at
# the run: a List the repo goes back into must still have the name and
# visibility it had then; a List is renamed back only while it has the name,
# description and visibility the run gave it. undo-step.jq checks it.
#   delete_list -> recreate
#   create_list -> reported, never deleted
# List ids are shown through every recreation an earlier undo recorded
# (UL_3 -> UL_30 -> UL_31); undo-step.jq decides each step against a fresh
# read when it runs.
# Steps a previous undo already finished are left out, so an interrupted undo
# can be resumed.
($all[0] | map(select((.op | startswith("undo_")) and .status == "ok") | .undoes)) as $undone
| ($all[0] | map(select(.op == "undo_recreate_list" and .status == "ok") | {key: .old_id, value: .new_id})
   | from_entries) as $remap
| def live: [limit(100; recurse(if $remap[.] != null then $remap[.] else empty end))] | last;
  def remap: map(live);
  # facts(ids): each List with the state the log recorded for it at the run.
  def facts($ids): (.lists // {}) as $f
    | [$ids[] | {id: live} + ($f[.] // {unrecorded: true} | {name, isPrivate, unrecorded} | with_entries(select(.value != null)))];
  [.[] | select(($run == "" or .run_id == $run)
                and (.op | IN("create_list", "rename_list", "set_lists", "unstar", "delete_list")))] as $recs
# A call can be attempted more than once (a rate limit, a server error), each
# attempt logged "started". Only the last can have changed GitHub: another
# attempt is made only after a fresh read shows the one before did not land
# (sc_checked_call). So each call is reversed from its last attempt alone.
| ([$recs | to_entries[] | select(.value.status == "started") | {i: .key, k: "\(.value.run_id)/\(.value.op_key)"}]
   | group_by(.k) | map(max_by(.i).i)) as $last_attempts
| [
    $recs | to_entries[] | .key as $i | select(.value.status == "started" and ($last_attempts | index([$i])) != null) | .value
    | . as $s
    | ([$recs[] | select(.run_id == $s.run_id and .op_key == $s.op_key and .status != "started")] | last) as $out
    | (if $out == null or $out.status == "unknown" then "uncertain" else $out.status end) as $state
    | select($state == "ok" or $state == "uncertain")
    | $s + (($out // {}) | del(.status, .ts)) + {state: $state, id: "\($s.run_id)/\($s.op_key)"}
  ]
| reverse
| [
    .[] | (if .state == "uncertain" then {uncertain: true} else {} end) as $u
    | if .op == "unstar" then
        ({op: "restar", repo, undoes: .id} + $u),
        (if (.list_ids // []) | length > 0
         then {op: "set_lists", repo, item_id, add: facts(.list_ids), remove: [], undoes: "\(.id)#lists"} + $u
         else empty end)
      elif .op == "set_lists" then
        {op: "set_lists", repo, item_id, add: facts(.before_ids - .after_ids),
         remove: facts(.after_ids - .before_ids) | map(del(.unrecorded)), undoes: .id} + $u
      elif .op == "rename_list" then
        {op: "rename_back", list_id: (.list_id | live),
         requires: {name: .to, description: .description,
                    isPrivate: (if .private == null then .before.isPrivate else .private end)},
         expects: .before, undoes: .id} + $u
      elif .op == "delete_list" then
        {op: "recreate_list", old_id: .list_id, name, description, private, undoes: .id} + $u
      else
        {op: "keep_list", name, list_id, run_id}
      end
    | select(.undoes == null or (.undoes as $id | $undone | index([$id]) | not))
  ]
