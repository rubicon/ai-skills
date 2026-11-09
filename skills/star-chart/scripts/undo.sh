#!/usr/bin/env bash
# undo.sh: reverse the changes recorded in a changes-YYYY-MM-DD.jsonl log.
#
# Usage:
#   bash undo.sh --list-runs                                 the recorded runs, newest first
#   bash undo.sh [<log>] [--run <run_id>]                    list the calls, change nothing
#   bash undo.sh [<log>] [--run <run_id>] --approved <sha>   make them
# Without <log>, --run looks the run up in every change log in the data directory.
#
# Re-stars unstarred repos, reverses each membership change the run made (on
# the repo's Lists as they are now, so edits made since are kept), renames
# Lists back, and recreates deleted Lists, newest change first. Lists a run
# created are left in place and reported. Each step is checked against a
# fresh read right before it (undo-step.jq): a List renamed again or gone
# since the run refuses that step, and a List is never recreated over, or
# taken from, another List with its name. A change whose outcome was never
# logged (the run was interrupted mid-call) is listed as uncertain and
# reversed too; each reversal is safe to repeat.
# Exit: 0 all done; 2 some steps failed, were refused, or have an unknown outcome.
#
# Reads every change log in the data directory: steps an earlier undo already
# finished are left out (an interrupted undo resumes), and Lists an earlier
# undo recreated are referred to by their new ids. GitHub sets a new
# starred_at on a re-star, so a re-starred repo counts as new in later runs.
# The listing ends with a SHA-256 of exactly the listed calls (so it changes
# with --run); --approved must match it. Refuses unless gh is signed in as the
# account the log belongs to.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

log="" run="" approved="" list_runs=0
while [ $# -gt 0 ]; do
  case $1 in
    --list-runs) list_runs=1; shift ;;
    --run) run=${2:-}; shift 2 || shift ;;
    --approved) approved=${2:-}; shift 2 || shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    -*) sc_die "unknown argument: $1" ;;
    *) log=$1; shift ;;
  esac
done

sc_need_jq
work=$(mktemp -d "${TMPDIR:-/tmp}/star-chart.XXXXXX")
trap 'rm -rf "$work"' EXIT

if [ "$list_runs" -eq 1 ]; then
  sc_all_logs | jq -L "$SC_JQ" -f "$SC_JQ/runs.jq" \
    | jq -r 'if length == 0 then "No runs recorded." else .[] |
        "\(.run_id)  \(.started)  \(.login // "?")  \(.changed | to_entries | map("\(.value) \(.key)") | join(", "))\(if .uncertain > 0 then ", \(.uncertain) uncertain" else "" end)" end'
  exit 0
fi
if [ -z "$log" ]; then
  [ -n "$run" ] || sc_die "usage: undo.sh --list-runs | undo.sh [<changes log>] --run <run_id> [--approved <sha>]"
  log="$work/all-runs.jsonl"
  sc_all_logs | jq -c '.[]' >"$log"
fi
[ -f "$log" ] || sc_die "$log not found."
{ sc_all_logs; jq -s . "$log"; } | jq -s 'add | unique_by([.run_id, .op_key, .status, .ts])' >"$work/all.json"
jq -s -L "$SC_JQ" --arg run "$run" --slurpfile all "$work/all.json" -f "$SC_JQ/undo.jq" "$log" >"$work/undo.json"
sha=$(sc_sha256 "$work/undo.json")
here=$(cd "$(dirname "$0")" && pwd)

if [ -z "$approved" ]; then
  if [ -n "$run" ]; then target="run $run"; else target=$log; fi
  echo "Calls that would reverse $target, newest first:"
  echo
  jq -r -f "$SC_JQ/undo-listing.jq" "$work/undo.json"
  echo
  echo "Write calls: $(jq '[.[] | select(.op != "keep_list")] | length' "$work/undo.json")"
  echo "Undo SHA-256: $sha"
  echo "Nothing was changed. After an explicit yes, run:"
  if [ "$log" = "$work/all-runs.jsonl" ]; then
    echo "  $(sc_run_prefix)bash $here/undo.sh --run $run --approved $sha"
  else
    echo "  $(sc_run_prefix)bash $here/undo.sh $log ${run:+--run $run }--approved $sha"
  fi
  exit 0
fi

[ "$sha" = "$approved" ] || sc_die "these undo calls (SHA-256 $sha) do not match the approved hash $approved. List the undo again (with the same --run) and get a new approval."
sc_need_gh
SC_LOGIN=$(jq -r --arg run "$run" '[.[] | select($run == "" or .run_id == $run) | .login // empty] | unique | if length == 1 then .[0] else "" end' "$work/all.json")
[ -n "$SC_LOGIN" ] || sc_die "the selected runs do not name exactly one account; nothing was changed."
export SC_LOGIN
sc_check_account "$SC_LOGIN" || exit 1
if jq -e 'any(.[]; .op != "restar" and .op != "keep_list")' "$work/undo.json" >/dev/null; then
  sc_check_list_scope || sc_die "nothing was changed."
fi
# Lists recreated by earlier undo runs, old id -> new id; this run adds its own.
remap=$(jq -c '[.[] | select(.op == "undo_recreate_list" and .status == "ok" and .new_id != null)
  | {key: .old_id, value: .new_id}] | from_entries' "$work/all.json")
# Lists an earlier attempt at this same undo renamed back, with the state that
# restored. Only renames of the runs being undone count: a state some other,
# older undo restored says nothing about these runs (it may since have been
# superseded).
these_renames=$(jq -s -c --arg run "$run" '[.[] | select(($run == "" or .run_id == $run)
  and .op == "rename_list" and .status == "started") | "\(.run_id)/\(.op_key)"] | unique' "$log")
restored=$(jq -c --argjson these "$these_renames" '[.[] | select(.op == "undo_rename_back"
    and (.undoes as $u | $these | index([$u])) != null)] | group_by(.op_key)
  | map(select(any(.[]; .status == "ok")) | map(select(.status == "started")) | last | select(. != null)
        | {key: .list_id, value: .expects}) | from_entries' "$work/all.json")
# A recreate whose attempt in this step may have landed: a same-name List
# found by the re-check right after it is taken up, and only then.
attempted='[]' 

out_log="$SC_DIR/changes-$(date +%F).jsonl"
mkdir -p "$SC_DIR"
run_id="undo-$(date -u +%Y%m%dT%H%M%SZ)"
done_n=0 failed_n=0 refused_n=0 unknown_n=0 already_n=0

# log_undo <status> <extra JSON> : one record for the current step.
log_undo() {
  sc_log "$out_log" "$run_id" "$(jq -c -n --arg k "$key" --arg op "undo_$kind" --arg s "$1" --arg u "$undoes" \
    --argjson x "$2" '{op: $op, op_key: $k, undoes: $u, status: $s} + $x')"
}
# check_step: before every attempt, the step's contract against a fresh read
# (undo-step.jq). A re-star needs no check: starring is safe to repeat.
# Like apply.sh's check_op, it runs where bash ignores set -e: every step
# fails closed explicitly.
check_step() {
  local starred
  SC_DECISION=""
  if [ "$kind" = restar ]; then
    # Done when the repo is starred again (by an earlier attempt, or elsewhere).
    starred=$(sc_is_starred "$label") || return 1
    if [ "$starred" = yes ]; then SC_DECISION='{"action":"done"}'; else SC_DECISION='{"action":"call"}'; fi
    return 0
  fi
  sc_fetch_lists >"$work/lists.json" || return 1
  SC_DECISION=$(jq -n -c -L "$SC_JQ" --argjson step "$step" --slurpfile now "$work/lists.json" \
    --argjson remap "$remap" --argjson attempted "$attempted" --argjson restored "$restored" \
    -f "$SC_JQ/undo-step.jq") || return 1
}
# send_step: log the attempt, then make it once.
# A step is sent only once its attempt is logged (SC_RC stays 1: failed,
# nothing sent).
send_step() {
  local rec
  rec=$(printf '%s' "$step" | jq -c --argjson d "$SC_DECISION" \
    'del(.op, .undoes) + ($d | {before_ids, after_ids} | with_entries(select(.value != null)))') || return 0
  log_undo started "$rec" || return 0
  SC_RC=0
  if [ "$kind" = restar ]; then
    sc_call -X PUT "user/starred/$label" >/dev/null 2>"$work/err" || SC_RC=$?
    return 0
  fi
  if ! printf '%s' "$SC_DECISION" | jq --arg q "$query" '{query: $q, variables}' >"$work/body.json"; then
    SC_RC=1
    return 0
  fi
  sc_call graphql --input "$work/body.json" >"$work/out.json" 2>"$work/err" || SC_RC=$?
  # A recreate that may have happened is taken up by the next check, if so.
  if [ "$kind" = recreate_list ] && [ "$SC_RC" != 0 ]; then
    attempted=$(printf '%s' "$attempted" | jq -c --arg u "$undoes" '. + [$u] | unique')
  fi
}

total=$(jq length "$work/undo.json")
i=0
while [ "$i" -lt "$total" ]; do
  step=$(jq -c ".[$i]" "$work/undo.json")
  i=$((i + 1))
  kind=$(printf '%s' "$step" | jq -r .op)
  label=$(printf '%s' "$step" | jq -r '.repo // .name // .expects.name // .list_id // ""')
  if [ "$kind" = keep_list ]; then
    echo "  [$i/$total] kept List $label"
    continue
  fi
  key="undo:$(printf '%s' "$step" | jq -r .undoes)"
  undoes=$(printf '%s' "$step" | jq -r .undoes)
  case $kind in
    set_lists)
      query='mutation($itemId: ID!, $listIds: [ID!]!) { updateUserListsForItem(input: {itemId: $itemId, listIds: $listIds}) { user { login } } }' ;;
    rename_back)
      query='mutation($listId: ID!, $name: String, $description: String, $isPrivate: Boolean) { updateUserList(input: {listId: $listId, name: $name, description: $description, isPrivate: $isPrivate}) { list { id } } }' ;;
    recreate_list)
      query='mutation($name: String!, $description: String, $isPrivate: Boolean) { createUserList(input: {name: $name, description: $description, isPrivate: $isPrivate}) { list { id } } }' ;;
    *) query="" ;;
  esac

  : >"$work/err"
  : >"$work/out.json"
  attempted='[]'
  sc_checked_call check_step send_step
  extra='{}'
  if [ "$kind" = recreate_list ] && { [ "$SC_OUTCOME" = ok ] || [ "$SC_OUTCOME" = exists ]; }; then
    # Made now, or found on the re-check (recreated earlier, or after a server error).
    old_id=$(printf '%s' "$step" | jq -r .old_id)
    new_id=$(jq -r '.data.createUserList.list.id // empty' "$work/out.json" 2>/dev/null || true)
    [ -n "$new_id" ] || new_id=$(printf '%s' "$SC_DECISION" | jq -r '.new_id // empty')
    remap=$(printf '%s' "$remap" | jq -c --arg o "$old_id" --arg n "$new_id" '. + {($o): $n}')
    extra=$(jq -c -n --arg o "$old_id" --arg n "$new_id" '{old_id: $o, new_id: $n}')
  fi
  case $SC_OUTCOME in
    ok)
      log_undo ok "$extra"
      if [ "$kind" = rename_back ]; then
        restored=$(printf '%s' "$restored" | jq -c --argjson s "$step" '. + {($s.list_id): $s.expects}')
      fi
      done_n=$((done_n + 1))
      echo "  [$i/$total] ok: $kind $label" ;;
    exists)
      # Already as the reversal would leave it: recorded as done, so it is not
      # listed again.
      log_undo ok "$(printf '%s' "$extra" | jq -c --argjson d "$SC_DECISION" '. + {already: true} + ($d | {adopted} | with_entries(select(.value != null)))')"
      already_n=$((already_n + 1))
      echo "  [$i/$total] already in place: $kind $label" ;;
    refused)
      log_undo refused "$(printf '%s' "$SC_DECISION" | jq -c '{error: .reason}')"
      refused_n=$((refused_n + 1))
      echo "  [$i/$total] REFUSED $kind $label: $(printf '%s' "$SC_DECISION" | jq -r .reason)" ;;
    *)
      log_undo "$SC_OUTCOME" "$(jq -c -n --arg e "$(head -c 500 "$work/err" | tr '\n' ' ')" '{error: $e}')"
      if [ "$SC_OUTCOME" = unknown ]; then unknown_n=$((unknown_n + 1)); else failed_n=$((failed_n + 1)); fi
      echo "  [$i/$total] $SC_OUTCOME: $kind $label" ;;
  esac
  sc_throttle
done

echo
echo "Undo done: $done_n changed, $failed_n failed, $unknown_n unknown, $refused_n refused, $already_n already in place. Log: $out_log (run $run_id)"
if [ "$failed_n" -gt 0 ] || [ "$unknown_n" -gt 0 ]; then
  echo "List the undo again to retry; finished steps are skipped."
fi
if [ "$refused_n" -gt 0 ]; then
  echo "Refused steps were not made because the List changed since the run (reasons above)."
fi
[ "$failed_n" -eq 0 ] && [ "$unknown_n" -eq 0 ] && [ "$refused_n" -eq 0 ] || exit 2
