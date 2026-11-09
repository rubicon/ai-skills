#!/usr/bin/env bash
# delete-lists.sh: delete the Lists plan.json marks for deletion, once they
# are empty. Run after apply.sh has moved their repos.
#
# Usage:
#   bash delete-lists.sh        re-read the Lists, list what can go now, change nothing
#   bash delete-lists.sh --run  delete them
#
# Deletions are approved with the other category changes (plan.sh
# approve-categories), so this runs only when the plan's category changes
# match that approval, and deletes only Lists the approval names. A List is
# deleted only if it still exists and a fresh read shows it empty; anything
# else is skipped with the reason. Each List is checked again right before
# every attempt at its deletion, a retry included (another device can add a
# repo at any moment), and skipped if it is no longer the approved, empty List. The small gap
# between that check and the delete call cannot be closed: GitHub has no
# "delete only if empty". Each deletion is logged with the List's name,
# description and privacy, before and after the call, so undo.sh can recreate
# it. Refuses unless gh is signed in as the exported account.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

run=0
while [ $# -gt 0 ]; do
  case $1 in
    --run) run=1; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) sc_die "unknown argument: $1" ;;
  esac
done

sc_need_jq
sc_require plan.json stars.json
jq -e '(.deletions // []) | length > 0' "$SC_DIR/plan.json" >/dev/null \
  || { echo "plan.json marks no Lists for deletion."; exit 0; }
sc_check_categories "$SC_DIR/plan.json" || sc_die "nothing was deleted."

sc_need_gh
SC_LOGIN=$(jq -r .login "$SC_DIR/stars.json")
export SC_LOGIN
sc_check_account "$SC_LOGIN" || exit 1
work=$(mktemp -d "${TMPDIR:-/tmp}/star-chart.XXXXXX")
trap 'rm -rf "$work"' EXIT

echo "Re-reading your Lists (read-only)..."
sc_fetch_lists >"$work/lists.json"
jq -L "$SC_JQ" --slurpfile lists "$work/lists.json" --slurpfile stars "$SC_DIR/stars.json" \
  -f "$SC_JQ/deletable.jq" "$SC_DIR/plan.json" >"$work/deletable.json"
jq -c '.delete' "$work/deletable.json" >"$work/set.json"
count=$(jq length "$work/set.json")
# Approved deletions that cannot happen now, and why; shown in both modes.
skipped_listing() {
  jq -r 'if (.skipped | length) > 0 then "", "Skipped:", (.skipped[] | "  \(.list | @json): \(.why)") else empty end' \
    "$work/deletable.json"
}

if [ "$run" -eq 0 ]; then
  jq -r '
    (if (.delete | length) > 0 then "Empty now, can be deleted:", (.delete[] | "  graphql deleteUserList  \(.name | @json)  (\(if .private then "private" else "public" end), \(.list_id))")
     else "No List in the plan is empty yet." end)
  ' "$work/deletable.json"
  skipped_listing
  echo
  echo "Nothing was changed. These deletions were approved with the category changes; to run them:"
  echo "  $(sc_run_prefix)bash $(cd "$(dirname "$0")" && pwd)/delete-lists.sh --run"
  exit 0
fi

sc_check_list_scope || sc_die "nothing was changed."

log="$SC_DIR/changes-$(date +%F).jsonl"
run_id="delete-$(date -u +%Y%m%dT%H%M%SZ)"
failed_n=0 done_n=0 skipped_n=0 unknown_n=0 i=0
# check_delete: before every attempt, a fresh read: the same List (by id), as
# approved, and empty. Gone means done (an earlier attempt, answered with a
# server error, did delete it).
check_delete() {
  # Runs where bash ignores set -e: every step fails closed explicitly.
  SC_DECISION=""
  sc_fetch_lists >"$work/lists.json" || return 1
  SC_DECISION=$(jq -n -c -L "$SC_JQ" --argjson item "$item" --slurpfile now "$work/lists.json" '
    include "contract";
    ($now[0] | map({key: .id, value: .}) | from_entries) as $is
    | $is[$item.list_id] as $l
    | if $l == null then {action: "done"}
      else sc_unmet({id: $item.list_id, name: $item.name, isPrivate: $item.private}; $is; {}; false; {}) as $why
        | if $why != null then {action: "refuse", reason: $why}
          elif ($l.items | length) > 0 then {action: "refuse", reason: "it holds \($l.items | length) repos now"}
          else {action: "call", variables: {listId: $item.list_id}} end
      end') || return 1
}
# send_delete: log the attempt, then make it once.
# Sent only once the attempt is logged (SC_RC stays 1: failed, nothing sent).
send_delete() {
  local rec
  # The List as this attempt's fresh read found it: what undo recreates.
  rec=$(jq -c --argjson item "$item" --arg k "$key" '
    first(.[] | select(.id == $item.list_id)) as $l
    | {op: "delete_list", op_key: $k, status: "started"}
      + $item + {name: $l.name, description: $l.description, private: $l.isPrivate}' "$work/lists.json") || return 0
  sc_log "$log" "$run_id" "$rec" || return 0
  printf '%s' "$SC_DECISION" | jq '{query: "mutation($listId: ID!) { deleteUserList(input: {listId: $listId}) { user { login } } }", variables}' >"$work/body.json" || return 0
  # shellcheck disable=SC2034 # SC_RC is read by sc_checked_call (lib.sh).
  SC_RC=0
  # shellcheck disable=SC2034
  sc_call graphql --input "$work/body.json" >/dev/null 2>"$work/err" || SC_RC=$?
}
while [ "$i" -lt "$count" ]; do
  item=$(jq -c ".[$i]" "$work/set.json")
  i=$((i + 1))
  name=$(printf '%s' "$item" | jq -r .name)
  key="delete:$(printf '%s' "$item" | jq -r .list_id)"
  : >"$work/err"
  sc_checked_call check_delete send_delete
  case $SC_OUTCOME in
    ok|exists)
      sc_log "$log" "$run_id" "$(jq -c -n --arg k "$key" '{op: "delete_list", op_key: $k, status: "ok"}')"
      done_n=$((done_n + 1))
      echo "  [$i/$count] ok: delete List \"$name\"" ;;
    refused)
      sc_log "$log" "$run_id" "$(printf '%s' "$item" | jq -c --arg k "$key" --arg e "$(printf '%s' "$SC_DECISION" | jq -r .reason)" \
        '{op: "delete_list", op_key: $k, status: "skipped", error: $e} + .')"
      skipped_n=$((skipped_n + 1))
      echo "  [$i/$count] SKIPPED \"$name\": $(printf '%s' "$SC_DECISION" | jq -r .reason)" ;;
    *)
      sc_log "$log" "$run_id" "$(jq -c -n --arg k "$key" --arg s "$SC_OUTCOME" --arg e "$(head -c 500 "$work/err" | tr '\n' ' ')" \
        '{op: "delete_list", op_key: $k, status: $s, error: $e}')"
      if [ "$SC_OUTCOME" = unknown ]; then unknown_n=$((unknown_n + 1)); else failed_n=$((failed_n + 1)); fi
      echo "  [$i/$count] $SC_OUTCOME: delete List \"$name\"" ;;
  esac
  sc_throttle
done

echo
skipped_listing
echo "Deleted $done_n, skipped $skipped_n, failed $failed_n, unknown $unknown_n. Log: $log (run $run_id)."
echo "To recreate them: $(sc_run_prefix)bash $(cd "$(dirname "$0")" && pwd)/undo.sh $log --run $run_id"
[ "$failed_n" -eq 0 ] && [ "$unknown_n" -eq 0 ] || exit 2
