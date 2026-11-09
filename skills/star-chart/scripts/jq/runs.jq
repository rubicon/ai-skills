# runs.jq: the runs recorded in the change logs, newest first, for choosing
# what to undo.
#
#   cat changes-*.jsonl | jq -s -L scripts/jq -f runs.jq
#
# For each run: when it started, the account, how many changes of each kind
# finished, and how many were interrupted with no recorded outcome. Undo runs
# and runs that changed nothing are left out.
def counted: IN("create_list", "rename_list", "set_lists", "unstar", "delete_list");

[
  group_by(.run_id)[]
  | . as $recs
  | {
      run_id: .[0].run_id,
      started: (map(.ts) | min),
      login: (map(.login // empty) | first // null),
      changed: ([.[] | select(.status == "ok" and (.op | counted)) | .op] | group_by(.) | map({key: .[0], value: length}) | from_entries),
      uncertain: ([.[] | select(.status == "started" and (.op | counted)) | . as $s
                  | select([$recs[] | select(.op_key == $s.op_key and .status != "started" and .status != "unknown")] | length == 0)] | length)
    }
  | select((.changed | length) > 0 or .uncertain > 0)
]
| sort_by(.started) | reverse
