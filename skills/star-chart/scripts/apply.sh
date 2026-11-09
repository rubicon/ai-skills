#!/usr/bin/env bash
# apply.sh: carry out an approved plan. With delete-lists.sh and undo.sh, the
# only star-chart scripts that change GitHub.
#
# Usage: bash apply.sh --approved <Approval SHA-256 printed by dry-run.sh>
#
# Runs exactly the calls the dry run listed and the user approved: the hash
# covers the plan, every call, and every List as the approval saw it. Before
# any change it refuses unless the hash matches, the category changes match
# their approval, the plan validates (no unstar of a keep-always repo or a
# recent star), nothing private would go public unacknowledged, and gh is
# signed in as the exported account.
#
# Each call carries a contract (ops.jq "requires"), and is held to it by
# apply-step.jq and contract.jq, the same check undo uses:
#   - Lists are identified by id, never looked up by name, so a List that took
#     an approved List's name is never written to.
#   - A List a repo ends up in must be in its final approved state (name and
#     visibility after this plan's renames; a created List as approved); a List
#     a repo leaves must be as approved, or gone; a rename's List must have the
#     name, description and visibility approved.
#   - A membership change applies only the approved change to the repo's Lists
#     as they are right before the call; a List added or removed since, on
#     another device, is kept as it is.
#   - A List this plan creates is known only from this plan's own log.
#   - Protection is re-read right before every unstar: current rules.md and
#     the stars starred inside the window right now.
# All of it is checked once against a fresh read before the first call (any
# problem stops the run with nothing changed), then again against a fresh
# read before every attempt of every call, retries after a rate limit or a
# server error included (sc_checked_call); a call that no longer holds is
# refused, and the run continues. After a server error the re-read also shows
# whether the call landed. Every attempt is logged with the state of the
# Lists it touches, which undo checks against. See tests/write-paths.md for
# every write path, these rules, and the test for each. Between the read and
# the call, about a second, a change made elsewhere can still be overwritten:
# GitHub has no "only if unchanged".
#
# Order: rename Lists, set membership for repos whose target Lists exist,
# unstar, create Lists, set membership for repos that need a created List. It
# never deletes a List (delete-lists.sh does).
#
# Every change is logged in changes-YYYY-MM-DD.jsonl twice: "started", with
# the state before it, then its outcome. A call that would change nothing is
# logged "exists". Re-running with the same hash skips finished calls, so an
# interrupted or partly failed run can be resumed. An unanswered call is
# logged "unknown", repeated by a re-run and reversed by undo; a List creation
# is never retried blindly. Waits 300 ms between calls, backs off on rate
# limits, continues past a failed or refused call.
# Exit: 0 all done; 1 refused before any change; 2 some calls failed, were
# refused, or have an unknown outcome (the plan is not fully applied).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

approved=""
while [ $# -gt 0 ]; do
  case $1 in
    --approved) approved=${2:-}; shift 2 || shift ;;
    -h|--help) sed -n '2,43p' "$0"; exit 0 ;;
    *) sc_die "unknown argument: $1" ;;
  esac
done

# Everything up to sc_need_gh is local, so a refused apply never touches GitHub.
sc_need_jq
[ -n "$approved" ] || sc_die "missing --approved <hash>. Run dry-run.sh, show it to the user, and use the hash it prints only after an explicit yes."
sc_require stars.json rules.md plan.json
actual=$(sc_approval_hash "$SC_DIR/plan.json" "$SC_DIR/stars.json")
[ "$actual" = "$approved" ] || sc_die "the plan and its calls (SHA-256 $actual) do not match the approved hash $approved. The plan or the export changed after the dry run; run dry-run.sh again and get a new approval."

work=$(mktemp -d "${TMPDIR:-/tmp}/star-chart.XXXXXX")
trap 'rm -rf "$work"' EXIT

sc_classify_to "$SC_DIR/stars.json" "$work/classification.json"
sc_validate "$SC_DIR/plan.json" "$SC_DIR/stars.json" "$work/classification.json" \
  || sc_die "nothing was changed."
sc_check_categories "$SC_DIR/plan.json" || sc_die "nothing was changed."
sc_check_exposure "$SC_DIR/plan.json" "$SC_DIR/stars.json" || sc_die "nothing was changed."
jq -L "$SC_JQ" --slurpfile stars "$SC_DIR/stars.json" -f "$SC_JQ/ops.jq" "$SC_DIR/plan.json" >"$work/ops.json"

sc_need_gh
SC_LOGIN=$(jq -r .login "$SC_DIR/stars.json")
export SC_LOGIN
sc_check_account "$SC_LOGIN" || exit 1
if jq -e '[.ops[] | select(.op != "unstar")] | length > 0' "$work/ops.json" >/dev/null; then
  sc_check_list_scope || sc_die "nothing was changed."
fi

log="$SC_DIR/changes-$(date +%F).jsonl"
run_id=$(date -u +%Y%m%dT%H%M%SZ)
sc_all_logs >"$work/logs.json"
jq -c -L "$SC_JQ" --arg h "$approved" 'include "common"; sc_done_keys($h)' "$work/logs.json" >"$work/done.json"
# Lists this plan created, by op key, from its own log.
created=$(jq -c --arg h "$approved" '[.[] | select(.plan_hash == $h and .op == "create_list"
  and (.status == "ok" or .status == "exists") and .list_id != null) | {key: .op_key, value: .list_id}] | from_entries' "$work/logs.json")
# Creates whose attempt in this call may have landed: a same-name List found
# by the re-check right after it is taken up. Only then: a List found later
# (a resumed run) could be anyone's, so it is refused, not adopted.
attempted='[]' 
done_n=0 failed_n=0 refused_n=0 skipped_n=0 unknown_n=0 create_failed=0
# The default for an omitted extra-JSON argument. Bash 3.2 (macOS) expands
# "${2:-{\}}" to "{\}", so the default is spelled through a variable.
none='{}'

# decide <op JSON> <true|false preflight> : apply-step.jq against $work/lists.json.
decide() {
  jq -n -c -L "$SC_JQ" --argjson op "$1" --slurpfile approved "$work/ops.json" --slurpfile now "$work/lists.json" \
    --argjson created "$created" --argjson attempted "$attempted" --argjson preflight "$2" -f "$SC_JQ/apply-step.jq"
}
log_started() { # <op JSON> [extra JSON]
  sc_log "$log" "$run_id" "$(jq -c -n --argjson op "$1" --arg h "$approved" --argjson x "${2:-$none}" \
    '$op | del(.key) + {op_key: $op.key, plan_hash: $h, status: "started"} + $x')"
}
log_outcome() { # <status> <op JSON> [extra JSON]
  sc_log "$log" "$run_id" "$(jq -c -n --arg s "$1" --argjson op "$2" --arg h "$approved" --argjson x "${3:-$none}" \
    '{op: $op.op, op_key: $op.key, plan_hash: $h, status: $s} + $x')"
  case $1 in
    ok) done_n=$((done_n + 1)) ;;
    failed) failed_n=$((failed_n + 1)) ;;
    refused) refused_n=$((refused_n + 1)) ;;
    unknown) unknown_n=$((unknown_n + 1)) ;;
    *) skipped_n=$((skipped_n + 1)) ;;
  esac
}
error_json() { jq -c -n --arg e "$(head -c 500 "$work/err" | tr '\n' ' ')" '{error: $e}'; }

# Preflight: every call still to make, against one fresh read, before any change.
echo "Re-reading your Lists (read-only)..."
sc_fetch_lists >"$work/lists.json" || sc_die "could not read your Lists; nothing was changed."
total=$(jq '.ops | length' "$work/ops.json")
: >"$work/preflight.txt"
i=0
while [ "$i" -lt "$total" ]; do
  op=$(jq -c ".ops[$i]" "$work/ops.json")
  i=$((i + 1))
  key=$(printf '%s' "$op" | jq -r .key)
  jq -e --arg k "$key" 'index([$k]) != null' "$work/done.json" >/dev/null && continue
  decide "$op" true | jq -r --argjson op "$op" \
    'select(.action == "refuse") | "  - \($op.repo // $op.name // $op.from): \(.reason)"' >>"$work/preflight.txt"
done
if [ -s "$work/preflight.txt" ]; then
  echo "star-chart: your Lists changed since the dry run, so these approved calls no longer fit them:" >&2
  cat "$work/preflight.txt" >&2
  sc_die "export again, run the dry run again, and get a new approval; nothing was changed."
fi

# check_op: before every attempt, the call's contract against a fresh read
# (apply-step.jq), or, for an unstar, its protection right now.
# It runs inside sc_checked_call's "if", where bash ignores set -e, so every
# step fails closed explicitly: any step that fails makes the check fail, and
# a failed check refuses the call.
check_op() {
  local rules since recent reason item starred
  SC_DECISION=""
  if [ "$kind" = unstar ]; then
    # Done when the repo is no longer starred: unstarred elsewhere, or by an
    # earlier attempt whose answer was lost.
    starred=$(sc_is_starred "$repo") || return 1
    if [ "$starred" = no ]; then
      SC_DECISION='{"action":"done"}'
      return 0
    fi
    rules=$(sc_rules_json) || return 1
    printf '%s' "$rules" | jq -e '(.protect_days | type) == "number" and (.keep_always | type) == "array"' >/dev/null || return 1
    since=$(jq -n -r -L "$SC_JQ" --arg now "$(sc_now)" --argjson r "$rules" 'include "common"; $now | sc_days_before($r.protect_days)') || return 1
    recent=$(sc_fetch_recent_stars "$since") || return 1
    reason=$(jq -n -r -L "$SC_JQ" --arg r "$repo" --argjson rules "$rules" --argjson recent "$recent" \
      'include "common"; $r | sc_protection_reason($rules; $recent) // empty') || return 1
    if [ -z "$reason" ]; then
      reason=$(jq -r --arg r "$repo" \
        '[.protected[] | select((.repo | ascii_downcase) == ($r | ascii_downcase)) | .reason] | first // empty' \
        "$work/classification.json") || return 1
    fi
    if [ -n "$reason" ]; then
      SC_DECISION=$(jq -c -n --arg r "$reason" '{action: "refuse", reason: $r}') || return 1
      return 0
    fi
    # The Lists the repo is in right now, logged with the attempt for undo.
    sc_fetch_lists >"$work/lists.json" || return 1
    item=$(printf '%s' "$op" | jq -r .item_id) || return 1
    SC_DECISION=$(jq -c --arg id "$item" \
      '{action: "call", list_ids: [.[] | select(any(.items[]; .id == $id)) | .id]}' "$work/lists.json") || return 1
    return 0
  fi
  sc_fetch_lists >"$work/lists.json" || return 1
  SC_DECISION=$(decide "$op" false) || return 1
}
# send_op: log the attempt with the state it acts on, then make it once.
send_op() {
  local extra
  # A call is sent only once its attempt is logged (SC_RC stays 1: failed,
  # nothing sent).
  if [ "$kind" = unstar ]; then
    extra=$(jq -c -n --argjson d "$SC_DECISION" --slurpfile now "$work/lists.json" '
      {list_ids: $d.list_ids,
       lists: ([$now[0][] | select(.id as $i | $d.list_ids | index([$i])) | {key: .id, value: {name, description, isPrivate}}]
               | from_entries)}') || return 0
    log_started "$op" "$extra" || return 0
    SC_RC=0
    sc_call -X DELETE "user/starred/$repo" >/dev/null 2>"$work/err" || SC_RC=$?
    return 0
  fi
  # Every List the call touches, as it is right now: undo checks against it.
  extra=$(jq -c -n --argjson d "$SC_DECISION" --argjson op "$op" --slurpfile now "$work/lists.json" '
    ([$d.before_ids // [], $d.after_ids // [], [$op.list_id // empty]] | add | unique) as $ids
    | {lists: ([$now[0][] | select(.id as $i | $ids | index([$i])) | {key: .id, value: {name, description, isPrivate}}]
               | from_entries)}
      + ($d | {before_ids, after_ids} | with_entries(select(.value != null)))') || return 0
  printf '%s' "$SC_DECISION" | jq --arg q "$query" '{query: $q, variables}' >"$work/body.json" || return 0
  log_started "$op" "$extra" || return 0
  SC_RC=0
  sc_call graphql --input "$work/body.json" >"$work/out.json" 2>"$work/err" || SC_RC=$?
  # A create that may have happened is taken up by the next check, if so.
  if [ "$kind" = create_list ] && [ "$SC_RC" != 0 ]; then
    attempted=$(printf '%s' "$attempted" | jq -c --arg k "$key" '. + [$k] | unique')
  fi
}

echo "Applying $total write calls as $SC_LOGIN. Log: $log (run $run_id)"
i=0
while [ "$i" -lt "$total" ]; do
  op=$(jq -c ".ops[$i]" "$work/ops.json")
  i=$((i + 1))
  kind=$(printf '%s' "$op" | jq -r .op)
  key=$(printf '%s' "$op" | jq -r .key)
  repo=$(printf '%s' "$op" | jq -r '.repo // ""')
  label=$(printf '%s' "$op" | jq -r 'if .op == "rename_list" then "rename \(.from | @json) to \(.to | @json)"
    elif .op == "create_list" then "create List \(.name | @json)"
    elif .op == "unstar" then "unstar \(.repo)"
    else "\(.repo) -> \([.after[].name] | join(", "))" end')
  case $kind in
    rename_list)
      query='mutation($listId: ID!, $name: String, $description: String, $isPrivate: Boolean) { updateUserList(input: {listId: $listId, name: $name, description: $description, isPrivate: $isPrivate}) { list { id name } } }' ;;
    set_lists)
      query='mutation($itemId: ID!, $listIds: [ID!]!) { updateUserListsForItem(input: {itemId: $itemId, listIds: $listIds}) { user { login } } }' ;;
    create_list)
      query='mutation($name: String!, $description: String, $isPrivate: Boolean) { createUserList(input: {name: $name, description: $description, isPrivate: $isPrivate}) { list { id name } } }' ;;
    *) query="" ;;
  esac

  if jq -e --arg k "$key" 'index([$k]) != null' "$work/done.json" >/dev/null; then
    echo "  [$i/$total] already done in an earlier run: $label"
    continue
  fi

  : >"$work/err"
  attempted='[]'
  sc_checked_call check_op send_op
  case $SC_OUTCOME in
    ok)
      if [ "$kind" = create_list ]; then
        # Made now, or (after a server error) found on the re-check.
        id=$(jq -r '.data.createUserList.list.id // empty' "$work/out.json" 2>/dev/null || true)
        [ -n "$id" ] || id=$(printf '%s' "$SC_DECISION" | jq -r '.list_id // empty')
        created=$(printf '%s' "$created" | jq -c --arg k "$key" --arg id "$id" '. + {($k): $id}')
        log_outcome ok "$op" "$(jq -c -n --arg id "$id" '{list_id: $id}')"
      else
        log_outcome ok "$op"
      fi ;;
    exists)
      log_outcome exists "$op" "$(printf '%s' "$SC_DECISION" | jq -c '{list_id, before_ids, adopted} | with_entries(select(.value != null))')"
      if [ "$kind" = create_list ]; then
        created=$(printf '%s' "$created" | jq -c --arg k "$key" --arg id "$(printf '%s' "$SC_DECISION" | jq -r .list_id)" '. + {($k): $id}')
      fi ;;
    refused)
      log_outcome refused "$op" "$(printf '%s' "$SC_DECISION" | jq -c '{error: .reason}')" ;;
    *)
      [ "$kind" = create_list ] && create_failed=$((create_failed + 1))
      log_outcome "$SC_OUTCOME" "$op" "$(error_json)" ;;
  esac
  case $SC_OUTCOME in
    exists) echo "  [$i/$total] already in place: $label" ;;
    refused) echo "  [$i/$total] REFUSED $label: $(printf '%s' "$SC_DECISION" | jq -r .reason)" ;;
    *) echo "  [$i/$total] $SC_OUTCOME: $label" ;;
  esac
  sc_throttle
done

here=$(cd "$(dirname "$0")" && pwd)
complete=1
[ "$failed_n" -eq 0 ] && [ "$refused_n" -eq 0 ] && [ "$unknown_n" -eq 0 ] || complete=0
echo
echo "Done: $done_n changed, $failed_n failed, $unknown_n unknown, $refused_n refused, $skipped_n already in place."
if [ "$unknown_n" -gt 0 ]; then
  echo "\"unknown\" means GitHub did not answer, so the change may or may not have happened. Re-running"
  echo "this command repeats those calls safely; undo also reverses them."
fi
echo "Log: $log (run $run_id)"
if [ "$complete" -eq 1 ]; then
  # Fully applied: later exports count stars as new from this plan's export,
  # and later classifications treat today's flags as already seen.
  jq -n --arg at "$(jq -r .exported_at "$SC_DIR/stars.json")" --arg h "$approved" \
    '{applied_export_at: $at, plan_hash: $h}' >"$SC_DIR/state.json"
  cp "$work/classification.json" "$SC_DIR/classification.prev.json"
fi
if [ "$create_failed" -gt 0 ]; then
  echo "Some Lists could not be created; GitHub may limit how many Lists you can have. Delete the"
  echo "emptied Lists first, then re-run this same command (finished calls are skipped):"
  echo "  $(sc_run_prefix)bash $here/delete-lists.sh"
fi
echo "Next:"
if [ "$failed_n" -gt 0 ] || [ "$unknown_n" -gt 0 ]; then
  echo "  - Retry the failed calls with this same command; finished calls are skipped. Do not export"
  echo "    again until that is done: a new export changes the approval hash."
fi
if [ "$refused_n" -gt 0 ]; then
  echo "  - Refused calls were not made because something changed since the approval (reasons above)."
  echo "    After any retry, export again and plan again to deal with them."
fi
if jq -e '(.deletions // []) | length > 0' "$SC_DIR/plan.json" >/dev/null; then
  echo "  - Delete the emptied Lists (asks for its own approval): $(sc_run_prefix)bash $here/delete-lists.sh"
fi
if [ "$complete" -eq 1 ]; then
  echo "  - Then export again, so stars.json matches GitHub: $(sc_run_prefix)bash $here/export.sh"
fi
echo "  - To reverse this run: $(sc_run_prefix)bash $here/undo.sh $log --run $run_id"
[ "$complete" -eq 1 ] || exit 2
