#!/usr/bin/env bash
# lib.sh: helpers shared by the star-chart scripts. Sourced, never run.
#
# Holds the data-directory layout, the rules and classification steps every
# script repeats, and the two pieces that talk to GitHub on behalf of the
# writers: sc_call (one API call with rate-limit backoff) and
# sc_check_list_scope (does the active token look able to manage Lists).
# Works with bash 3.2 (macOS) and later.

SC_SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SC_JQ="$SC_SCRIPTS/jq"
SC_SKILL=$(dirname "$SC_SCRIPTS")
# Working files live outside the repo and the installed skill, so a skill
# update never overwrites the rules and nothing here can be committed.
SC_DIR="${STAR_CHART_DIR:-$HOME/.star-chart}"

sc_die() { echo "star-chart: $*" >&2; exit 1; }
sc_note() { echo "star-chart: $*" >&2; }

# The current time as ISO 8601 UTC. STAR_CHART_NOW pins it for tests.
sc_now() {
  if [ -n "${STAR_CHART_NOW:-}" ]; then echo "$STAR_CHART_NOW"
  else date -u +%Y-%m-%dT%H:%M:%SZ; fi
}

sc_sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}

sc_need_jq() { command -v jq >/dev/null 2>&1 || sc_die "jq is required (https://jqlang.org)."; }

sc_need_gh() {
  command -v gh >/dev/null 2>&1 || sc_die "gh is required (https://cli.github.com)."
  gh auth status >/dev/null 2>&1 || sc_die "gh is not logged in. Run: gh auth login"
}

# Create the data directory, private to the user, and seed rules.md from the
# shipped example the first time.
sc_init_dir() {
  mkdir -p "$SC_DIR"
  chmod 700 "$SC_DIR"
  if [ ! -f "$SC_DIR/rules.md" ]; then
    cp "$SC_SKILL/rules.example.md" "$SC_DIR/rules.md"
    sc_note "created $SC_DIR/rules.md with the default rules; edit it to change them."
  fi
}

# sc_require <file name>... : stop unless each file exists in the data directory.
sc_require() {
  local f
  for f in "$@"; do
    [ -f "$SC_DIR/$f" ] || sc_die "$SC_DIR/$f not found. $(sc_hint "$f")"
  done
}

sc_hint() {
  case $1 in
    stars.json|rules.md) echo "Run export.sh first." ;;
    plan.json) echo "Write the plan first (see SKILL.md, step 2)." ;;
    plan.md) echo "Run plan.sh render first." ;;
    *) echo "" ;;
  esac
}

sc_rules_json() { jq -R -s -L "$SC_JQ" -f "$SC_JQ/rules.jq" "$SC_DIR/rules.md"; }

# sc_classify_to <stars.json> <output file>
# Applies rules.md at the current time. Flags already raised at the previous
# export (classification.prev.json) are marked as not new.
sc_classify_to() {
  local rules prev="$SC_DIR/classification.prev.json"
  rules=$(sc_rules_json) || return 1
  if [ -f "$prev" ]; then
    jq -L "$SC_JQ" --argjson rules "$rules" --arg now "$(sc_now)" \
      --slurpfile prev "$prev" -f "$SC_JQ/classify.jq" "$1" >"$2"
  else
    jq -L "$SC_JQ" --argjson rules "$rules" --arg now "$(sc_now)" \
      --argjson prev '[]' -f "$SC_JQ/classify.jq" "$1" >"$2"
  fi
}

# sc_validate <plan.json> <stars.json> <classification> : print each error to
# stderr and return 1 if there are any.
sc_validate() {
  local errors
  errors=$(jq -r -L "$SC_JQ" --slurpfile stars "$2" --slurpfile cls "$3" \
    -f "$SC_JQ/validate.jq" "$1" | jq -r '.[]') || return 1
  if [ -n "$errors" ]; then
    echo "star-chart: the plan has errors:" >&2
    printf '%s\n' "$errors" | sed 's/^/  - /' >&2
    return 1
  fi
}

# Prefix for commands the user runs: clears GH_TOKEN and GITHUB_TOKEN when
# set, so gh uses the stored login (which can carry the "user" scope).
sc_run_prefix() {
  if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
    printf 'env -u GH_TOKEN -u GITHUB_TOKEN '
  fi
}

# sc_same_account <a> <b> : GitHub logins compare ignoring case.
sc_same_account() {
  [ "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$2" | tr 'A-Z' 'a-z')" ]
}

# sc_check_account <expected login> : stop unless gh is signed in as that
# account, so a write never lands on a different account than the export.
sc_check_account() {
  local active
  active=$(gh api user --jq .login 2>/dev/null) || { sc_note "could not read the signed-in GitHub account."; return 1; }
  if ! sc_same_account "$active" "$1"; then
    sc_note "gh is signed in as \"$active\", but this data belongs to \"$1\". Nothing was changed."
    return 1
  fi
}

# The export a fully applied plan was based on: stars starred after it count
# as new. Empty until a plan has been applied in full, so unfinished cleanup
# is never treated as reviewed.
sc_previous_export() {
  if [ -f "$SC_DIR/state.json" ]; then jq -r '.applied_export_at // ""' "$SC_DIR/state.json"; fi
}

# sc_approval_hash <plan.json> <stars.json> : SHA-256 of the plan together
# with the exact calls it produces from that export. The dry run prints it;
# apply.sh requires it, so an approval covers the calls, not just the plan.
sc_approval_hash() {
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/star-chart.XXXXXX")
  {
    jq -cS . "$1"
    jq -cS -L "$SC_JQ" --slurpfile stars "$2" -f "$SC_JQ/ops.jq" "$1"
  } >"$tmp"
  sc_sha256 "$tmp"
  rm -f "$tmp"
}

# sc_all_logs : every change-log record in the data directory, as one array.
sc_all_logs() {
  local f found=0
  for f in "$SC_DIR"/changes-*.jsonl; do
    [ -f "$f" ] && found=1
  done
  if [ "$found" -eq 1 ]; then cat "$SC_DIR"/changes-*.jsonl | jq -s .; else echo '[]'; fi
}

# sc_fetch_recent_stars <ISO since> : JSON array of repos starred at or after
# that time, newest first, read fresh (GitHub lists stars newest first).
sc_fetch_recent_stars() {
  local page=1 rows out='[]' more=1
  while [ "$more" -eq 1 ]; do
    rows=$(gh api -H 'Accept: application/vnd.github.star+json' \
      "user/starred?per_page=100&page=$page&sort=created&direction=desc" \
      --jq '[.[] | {starred_at, repo: .repo.full_name}]') || return 1
    out=$(printf '%s' "$out" | jq -c --argjson rows "$rows" --arg since "$1" \
      '. + [$rows[] | select(.starred_at >= $since) | .repo]')
    if [ "$(printf '%s' "$rows" | jq length)" -lt 100 ] \
       || printf '%s' "$rows" | jq -e --arg since "$1" 'any(.[]; .starred_at < $since)' >/dev/null; then
      more=0
    fi
    page=$((page + 1))
  done
  printf '%s\n' "$out"
}


# sc_categories_to <plan.json> <output file> : the plan's category changes in
# canonical form (sorted keys, no reasons), as hashed and approved.
sc_categories_to() {
  jq -cS -L "$SC_JQ" 'include "common"; sc_categories' "$1" >"$2"
}

# sc_check_categories <plan.json> : return 0 when the plan has no category
# changes or they match categories.approved.json exactly; otherwise explain
# and return 1. Run before anything reaches GitHub.
sc_check_categories() {
  local tmp replaced
  tmp=$(mktemp "${TMPDIR:-/tmp}/star-chart.XXXXXX")
  sc_categories_to "$1" "$tmp"
  if jq -e '[.[] | length] | add == 0' "$tmp" >/dev/null; then
    rm -f "$tmp"; return 0
  fi
  if [ ! -f "$SC_DIR/categories.approved.json" ]; then
    rm -f "$tmp"
    sc_note "the plan's category changes have not been approved. Run plan.sh categories, show the user the list, and run plan.sh approve-categories <hash> only after an explicit yes."
    return 1
  fi
  if [ "$(jq -cS 'del(.acknowledged_exposure, .list_ids)' "$SC_DIR/categories.approved.json")" != "$(cat "$tmp")" ]; then
    rm -f "$tmp"
    sc_note "the plan's category changes differ from the ones approved. Run plan.sh categories, show the user the list, and get a new approval."
    return 1
  fi
  rm -f "$tmp"
  # The approval is of particular Lists: a List that now has one of their
  # names but another id was put in place since, and is not the approved one.
  # (A name no List has any more was renamed or deleted, by this plan or not;
  # the steps that use it find that out by id.)
  replaced=$(jq -r --slurpfile stars "$SC_DIR/stars.json" '
    ($stars[0].lists | map({key: (.name | ascii_downcase), value: .}) | from_entries) as $L
    | (.list_ids // {}) | to_entries[] | $L[.key] as $l
    | select($l != null and $l.id != .value) | "  ! \($l.name | @json) is not the List the approval named"' \
    "$SC_DIR/categories.approved.json") || { sc_note "could not check the approved Lists."; return 1; }
  if [ -n "$replaced" ]; then
    sc_note "since the category approval, a List it named was replaced by another with the same name:"
    printf '%s\n' "$replaced" >&2
    sc_note "run plan.sh categories, show the user the list, and get a new approval."
    return 1
  fi
}

# sc_check_exposure <plan.json> <stars.json> : return 0 unless the plan's
# category changes, measured against those Lists, would make private
# categorization public in a way the category approval did not acknowledge.
# A List can turn private after the approval, so the dry run checks this
# against the export and apply checks it again against a fresh read.
sc_check_exposure() {
  local ack='[]' lines
  if [ -f "$SC_DIR/categories.approved.json" ]; then
    ack=$(jq -c '.acknowledged_exposure // []' "$SC_DIR/categories.approved.json")
  fi
  lines=$(jq -r -L "$SC_JQ" --slurpfile stars "$2" --argjson ack "$ack" \
    'include "common"; sc_unacknowledged_exposure($stars[0]; $ack)' "$1") \
    || { sc_note "could not check the plan for private Lists made public."; return 1; }
  [ -z "$lines" ] && return 0
  sc_note "these category changes would make private categorization public, and the approval did not include that:"
  printf '%s\n' "$lines" >&2
  sc_note "a List may have turned private since the approval. Run plan.sh categories, show the user the list, and get a new approval."
  return 1
}

# sc_response_body <file> : the body of a saved `gh api -i` response
# (everything after the first blank line; header lines end in CRLF).
sc_response_body() {
  awk 'in_body { print; next } { sub(/\r$/, "") } NR > 1 && $0 == "" { in_body = 1 }' "$1"
}

# sc_header <name> <file> : the value of one response header, any case.
sc_header() {
  awk -v want="$(printf '%s' "$1" | tr 'A-Z' 'a-z')" '
    NR == 1 { next }
    { sub(/\r$/, "") }
    $0 == "" { exit }
    {
      name = tolower(substr($0, 1, index($0, ":") - 1))
      if (name == want) { value = substr($0, index($0, ":") + 1); sub(/^[ \t]+/, "", value); print value; exit }
    }' "$2"
}

# sc_response_verdict <file> <now, epoch seconds>
# Decides what to do with a saved `gh api -i` response. Prints one of:
#   ok             2xx with an empty body or complete JSON, and no GraphQL errors
#   retry <secs>   rate limited, or a transient 5xx: wait <secs>, try again
#   unknown        no response, or a 2xx whose body is cut off or not JSON: the
#                  change may or may not have happened
#   fail           anything else: GitHub answered and refused
sc_response_verdict() {
  local status body retry remaining reset wait
  status=$(head -n 1 "$1" 2>/dev/null | tr -d '\r' | awk '/^HTTP\// { print $2 }')
  [ -n "$status" ] || { echo unknown; return; }
  body=$(sc_response_body "$1")
  case $status in
    2??)
      # Success needs a complete answer: an empty body (a REST 204), or one
      # that parses as JSON. A cut-off or garbled body (a connection dropped
      # mid-answer) says nothing about whether the change happened.
      if [ -n "$body" ] && ! printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
        echo unknown
      elif printf '%s' "$body" | jq -e 'type == "object" and any(.errors[]?; .type == "RATE_LIMITED")' >/dev/null 2>&1; then
        echo "retry 60"
      elif printf '%s' "$body" | jq -e 'type == "object" and ((.errors // []) | length > 0)' >/dev/null 2>&1; then
        echo fail
      else
        echo ok
      fi ;;
    403|429)
      retry=$(sc_header retry-after "$1")
      remaining=$(sc_header x-ratelimit-remaining "$1")
      reset=$(sc_header x-ratelimit-reset "$1")
      if printf '%s' "$retry" | grep -qE '^[0-9]+$'; then
        echo "retry $retry"
      elif [ "$remaining" = 0 ] && printf '%s' "$reset" | grep -qE '^[0-9]+$'; then
        wait=$((reset - $2))
        [ "$wait" -lt 1 ] && wait=1
        echo "retry $wait"
      elif printf '%s' "$body" | grep -qi 'rate limit' || [ "$status" = 429 ]; then
        # Secondary rate limits name no wait; GitHub asks for at least a minute.
        echo "retry 60"
      else
        echo fail
      fi ;;
    5??) echo "retry 5" ;;
    *) echo fail ;;
  esac
}

# sc_call <gh api arguments...>
# One attempt at one API call through `gh api -i`. It never resends: a write
# must be checked against GitHub again before every attempt, and only the
# caller knows what to check (sc_checked_call). Prints the body on success
# and returns 0. Otherwise prints the response to stderr and returns:
#   1  GitHub refused; nothing changed
#   4  rate limited; nothing changed. It has already waited: check, then try again
#   5  a server error, or no response: the change may have happened. It has
#      already waited: check whether it did, then try again if not
#   3  as 5, on the last attempt: the outcome is unknown
# SC_ATTEMPT (1-5, default 1) is the attempt number; on 5, a rate limit
# returns 1 and a server error 3. Each wait is what GitHub asked for, at least
# 5, 10, 20, 40 s on successive attempts, at most STAR_CHART_MAX_WAIT (default
# 900) seconds. Pass request bodies with --input <file>, never stdin.
sc_call() {
  local tmp verdict wait floor cap attempt=${SC_ATTEMPT:-1} rc ghrc=0
  tmp=$(mktemp "${TMPDIR:-/tmp}/star-chart.XXXXXX")
  gh api -i "$@" >"$tmp" 2>"$tmp.err" || ghrc=$?
  verdict=$(sc_response_verdict "$tmp" "$(date +%s)")
  # gh failing after a 2xx means the answer did not arrive whole.
  if [ "$verdict" = ok ] && [ "$ghrc" != 0 ]; then verdict=unknown; fi
  case $verdict in
    ok)
      sc_response_body "$tmp"
      rm -f "$tmp" "$tmp.err"
      return 0 ;;
    unknown) rc=5 wait=0 ;;
    retry\ *)
      wait=${verdict#retry }
      if head -n 1 "$tmp" | grep -qE '^HTTP/[0-9.]+ 5'; then rc=5; else rc=4; fi ;;
    *) rc=1 ;;
  esac
  { head -n 1 "$tmp"; sc_response_body "$tmp"; cat "$tmp.err"; } >&2
  rm -f "$tmp" "$tmp.err"
  [ "$rc" = 1 ] && return 1
  if [ "$attempt" -ge 5 ]; then
    [ "$rc" = 5 ] && return 3
    return 1
  fi
  cap=${STAR_CHART_MAX_WAIT:-900}
  floor=$((5 << (attempt - 1)))
  [ "$wait" -lt "$floor" ] && wait=$floor
  [ "$wait" -gt "$cap" ] && wait=$cap
  sc_note "rate limited or server error; waiting ${wait}s, then checking again (attempt $attempt of 5)"
  sleep "$wait"
  return "$rc"
}

# sc_is_starred <owner/repo> : read-only. Prints "yes" when the signed-in
# account stars the repo now, "no" when it does not (GET /user/starred/OWNER/
# REPO answers 204 or 404), and returns 1 when GitHub gave neither answer.
# The completion check for an unstar and a re-star.
sc_is_starred() {
  local status
  status=$(gh api -i "user/starred/$1" 2>/dev/null | head -n 1 | tr -d '\r' | awk '/^HTTP\// { print $2 }') || true
  case $status in
    204) echo yes ;;
    404) echo no ;;
    *) return 1 ;;
  esac
}

# sc_checked_call <check function> <send function>
# The one way star-chart makes a write. Before every attempt, <check> reads
# GitHub afresh and sets SC_DECISION to apply-step.jq / undo-step.jq output
# (it returns non-zero if it could not read). "refuse" or "done" ends it.
# Otherwise <send> makes the call with sc_call, with SC_ATTEMPT set, and sets
# SC_RC to sc_call's status. A rate limit or a server error leads to another
# attempt, checked again first, up to 5; after a server error, "done" means
# the earlier attempt landed. Sets SC_OUTCOME: ok, exists (already in place,
# nothing sent), refused, failed (GitHub refused; nothing changed) or unknown
# (it may have happened). Call it directly, never inside $(...).
# shellcheck disable=SC2034 # SC_OUTCOME is the result its callers read.
sc_checked_call() {
  local attempt=1 uncertain=0 action
  while :; do
    if ! "$1"; then
      SC_DECISION='{"action":"refuse","reason":"could not read GitHub to check this call"}'
    fi
    action=$(printf '%s' "$SC_DECISION" | jq -r '.action // empty' 2>/dev/null) || action=""
    # Anything but a clear "call", "done" or "refuse" is a refusal.
    case $action in
      call|done|refuse) ;;
      *) SC_DECISION='{"action":"refuse","reason":"the check gave no clear answer"}'; action=refuse ;;
    esac
    if [ "$action" = refuse ]; then
      if [ "$uncertain" = 1 ]; then SC_OUTCOME=unknown; else SC_OUTCOME=refused; fi
      return 0
    fi
    if [ "$action" = "done" ]; then
      if [ "$uncertain" = 1 ]; then SC_OUTCOME=ok; else SC_OUTCOME=exists; fi
      return 0
    fi
    SC_RC=1
    SC_ATTEMPT=$attempt
    export SC_ATTEMPT
    "$2"
    case $SC_RC in
      0) SC_OUTCOME=ok; return 0 ;;
      4) ;;
      5) uncertain=1 ;;
      3) SC_OUTCOME=unknown; return 0 ;;
      *) if [ "$uncertain" = 1 ]; then SC_OUTCOME=unknown; else SC_OUTCOME=failed; fi; return 0 ;;
    esac
    attempt=$((attempt + 1))
  done
}

# Pause between write calls (300 ms unless STAR_CHART_THROTTLE says otherwise).
sc_throttle() { sleep "${STAR_CHART_THROTTLE:-0.3}"; }

# sc_check_list_scope : return 0 when the active token reports the classic
# "user" OAuth scope, which List changes need. Otherwise explain what to run
# and return 1. Never changes the token itself.
sc_check_list_scope() {
  local tmp scopes env_note=""
  if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
    env_note="The active token comes from GH_TOKEN or GITHUB_TOKEN, which overrides your gh login, so 'gh auth refresh' does not change it. After refreshing, run this step with those unset, for example: env -u GH_TOKEN -u GITHUB_TOKEN bash $0 ..."
  fi
  tmp=$(mktemp "${TMPDIR:-/tmp}/star-chart.XXXXXX")
  gh api -i user >"$tmp" 2>/dev/null || true
  scopes=$(sc_header x-oauth-scopes "$tmp")
  if [ -z "$(head -n 1 "$tmp")" ]; then
    rm -f "$tmp"
    sc_note "could not reach GitHub to check the token's scopes."
    return 1
  fi
  if ! grep -qi '^x-oauth-scopes:' "$tmp"; then
    rm -f "$tmp"
    sc_note "the active token reports no OAuth scopes (fine-grained tokens and app tokens do not), so star-chart cannot confirm it may change Lists."
    sc_note "To use your gh login with the user scope, run: gh auth refresh -s user"
    [ -n "$env_note" ] && sc_note "$env_note"
    return 1
  fi
  rm -f "$tmp"
  if printf '%s' "$scopes" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -qx user; then
    return 0
  fi
  sc_note "the active token lacks the \"user\" scope, which changing Lists needs. Run: gh auth refresh -s user"
  [ -n "$env_note" ] && sc_note "$env_note"
  return 1
}

# sc_fetch_lists : print every List with its items (repo node IDs) as JSON.
# Read-only. One query returns every List with its first 100 repos (about one
# rate-limit point), so apply.sh can afford it before each write; only a List
# holding more than 100 repos is read again in full. Fails if any List could
# not be read in full.
sc_fetch_lists() {
  local all id items big
  all=$(gh api graphql --paginate -f query='
    query($endCursor: String) {
      viewer { lists(first: 100, after: $endCursor) {
        nodes { id name description isPrivate
          items(first: 100) { nodes { ... on Repository { id nameWithOwner } } pageInfo { hasNextPage } } }
        pageInfo { hasNextPage endCursor }
      } }
    }' --jq '.data.viewer.lists.nodes[]' | jq -s .) || return 1
  big=$(printf '%s' "$all" | jq -r '.[] | select(.items.pageInfo.hasNextPage) | .id')
  all=$(printf '%s' "$all" | jq -c 'map(.items = [.items.nodes[] | select(.id != null)])')
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    items=$(gh api graphql --paginate -f id="$id" -f query='
      query($id: ID!, $endCursor: String) {
        node(id: $id) { ... on UserList { items(first: 100, after: $endCursor) {
          nodes { ... on Repository { id nameWithOwner } }
          pageInfo { hasNextPage endCursor }
        } } }
      }' --jq '.data.node.items.nodes[] | select(.id != null)' | jq -s .) || return 1
    all=$(printf '%s' "$all" | jq -c --arg id "$id" --argjson items "$items" 'map(if .id == $id then .items = $items else . end)')
  done <<EOF
$big
EOF
  printf '%s\n' "$all"
}

# sc_log <log file> <run id> <record JSON> : append one change record,
# stamped with the time, the run, and the account (SC_LOGIN) it applies to.
sc_log() {
  jq -c -n --arg ts "$(sc_now)" --arg run "$2" --arg login "${SC_LOGIN:-}" --argjson rec "$3" \
    '{ts: $ts, run_id: $run, login: $login} + $rec' >>"$1"
}
