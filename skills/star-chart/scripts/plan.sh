#!/usr/bin/env bash
# plan.sh: move the plan between plan.json and the editable plan.md. Local only.
#
# Usage:
#   bash plan.sh render          plan.json -> plan.md, and snapshot what the user sees
#   bash plan.sh parse           edited plan.md -> plan.json, print what changed
#   bash plan.sh diff <a> <b>    summarize the changes between two plan files
#   bash plan.sh validate        check plan.json against the export and rules.md
#   bash plan.sh items           every proposed change as JSON, with stable ids, for
#                                the approval pop-ups
#   bash plan.sh drop <id>...    remove rejected items and what depended on them
#   bash plan.sh allow-public <owner/repo>...
#                                record the user's yes to adding a repo that is
#                                only in private Lists to a public List
#   bash plan.sh categories      list the plan's category changes and their hash
#   bash plan.sh approve-categories <hash> [--publishes-private]
#                                record those changes as approved (only after
#                                the user's explicit yes to the listing); a
#                                change that makes a private List public needs
#                                --publishes-private as well
#
# Category changes (Lists to create, renames, merges, deletions) are approved
# on their own, before assignments are built on them. dry-run.sh, apply.sh and
# delete-lists.sh refuse a plan whose category changes differ from the
# approved set; a reworded reason does not count as a difference.
#
# plan.rendered.json is the plan exactly as last shown in plan.md, so parse
# (and Claude, after editing plan.json from chat directions) can diff the
# user's changes against it.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

sc_need_jq

validate_quietly() {
  local cls
  cls=$(mktemp "${TMPDIR:-/tmp}/star-chart.XXXXXX")
  sc_classify_to "$SC_DIR/stars.json" "$cls"
  if sc_validate "$SC_DIR/plan.json" "$SC_DIR/stars.json" "$cls"; then
    echo "The plan is valid."
  else
    rm -f "$cls"; return 1
  fi
  rm -f "$cls"
}

render() {
  sc_require plan.json
  jq -r -L "$SC_JQ" -f "$SC_JQ/render.jq" "$SC_DIR/plan.json" >"$SC_DIR/plan.md.tmp"
  mv "$SC_DIR/plan.md.tmp" "$SC_DIR/plan.md"
  cp "$SC_DIR/plan.json" "$SC_DIR/plan.rendered.json"
  jq -r --arg dir "$SC_DIR" '"Wrote \($dir)/plan.md: \(.lists_to_create // [] | length) Lists to create, \(.renames // [] | length) renames, \(.merges // [] | length) merges, \(.deletions // [] | length) deletions, \(.assignments // [] | length) assignments, \(.unstar // [] | length) unstars."' "$SC_DIR/plan.json"
}

case ${1:-} in
  render)
    sc_require stars.json rules.md
    render
    validate_quietly || sc_note "fix the errors above before the dry run."
    ;;
  parse)
    sc_require plan.md stars.json rules.md
    base="$SC_DIR/plan.rendered.json"
    [ -f "$base" ] || base="$SC_DIR/plan.json"
    jq -R -s -L "$SC_JQ" -f "$SC_JQ/parse.jq" "$SC_DIR/plan.md" >"$SC_DIR/plan.json.tmp" \
      || { rm -f "$SC_DIR/plan.json.tmp"; sc_die "plan.md could not be read; nothing changed."; }
    if [ -f "$base" ]; then
      jq -n -r -L "$SC_JQ" --slurpfile a "$base" --slurpfile b "$SC_DIR/plan.json.tmp" -f "$SC_JQ/diff.jq"
    fi
    # plan.md does not carry the allow-public acknowledgments; keep them.
    if [ -f "$SC_DIR/plan.json" ]; then
      jq --slurpfile old "$SC_DIR/plan.json" '. + (if ($old[0].publish_private // []) | length > 0
        then {publish_private: $old[0].publish_private} else {} end)' "$SC_DIR/plan.json.tmp" >"$SC_DIR/plan.json.tmp2"
      mv "$SC_DIR/plan.json.tmp2" "$SC_DIR/plan.json.tmp"
    fi
    mv "$SC_DIR/plan.json.tmp" "$SC_DIR/plan.json"
    render
    validate_quietly || sc_note "fix the errors above before the dry run."
    ;;
  diff)
    [ $# -eq 3 ] || sc_die "usage: plan.sh diff <old plan.json> <new plan.json>"
    jq -n -r -L "$SC_JQ" --slurpfile a "$2" --slurpfile b "$3" -f "$SC_JQ/diff.jq"
    ;;
  validate)
    sc_require plan.json stars.json rules.md
    validate_quietly
    ;;
  items)
    sc_require plan.json stars.json
    jq -L "$SC_JQ" --slurpfile stars "$SC_DIR/stars.json" -f "$SC_JQ/items.jq" "$SC_DIR/plan.json"
    ;;
  drop)
    [ $# -ge 2 ] || sc_die "usage: plan.sh drop <item id>... (ids from plan.sh items)"
    sc_require plan.json stars.json rules.md
    shift
    ids=$(printf '%s\n' "$@" | jq -R . | jq -s -c .)
    jq -L "$SC_JQ" --argjson ids "$ids" -f "$SC_JQ/drop.jq" "$SC_DIR/plan.json" >"$SC_DIR/drop.tmp" \
      || { rm -f "$SC_DIR/drop.tmp"; sc_die "nothing was dropped."; }
    jq -r '"Dropped: \(.dropped | join(", "))",
           (if (.cascaded | length) > 0 then "Also dropped, because it depended on that: \(.cascaded | join(", "))" else empty end)' \
      "$SC_DIR/drop.tmp"
    jq '.plan' "$SC_DIR/drop.tmp" >"$SC_DIR/plan.json.tmp" && mv "$SC_DIR/plan.json.tmp" "$SC_DIR/plan.json"
    rm -f "$SC_DIR/drop.tmp"
    render
    validate_quietly || sc_note "fix the errors above before the dry run."
    ;;
  allow-public)
    [ $# -ge 2 ] || sc_die "usage: plan.sh allow-public <owner/repo>..."
    sc_require plan.json stars.json rules.md
    shift
    repos=$(printf '%s\n' "$@" | jq -R . | jq -s -c .)
    jq --argjson r "$repos" '.publish_private = ((.publish_private // []) + $r | unique)' "$SC_DIR/plan.json" >"$SC_DIR/plan.json.tmp"
    mv "$SC_DIR/plan.json.tmp" "$SC_DIR/plan.json"
    echo "Recorded: $* may be added to public Lists."
    render
    validate_quietly || sc_note "fix the errors above before the dry run."
    ;;
  categories)
    sc_require plan.json stars.json
    jq -r -L "$SC_JQ" --slurpfile stars "$SC_DIR/stars.json" -f "$SC_JQ/categories-listing.jq" "$SC_DIR/plan.json"
    tmp=$(mktemp "${TMPDIR:-/tmp}/star-chart.XXXXXX")
    sc_categories_to "$SC_DIR/plan.json" "$tmp"
    if ! jq -e '[.[] | length] | add == 0' "$tmp" >/dev/null; then
      echo
      if [ -f "$SC_DIR/categories.approved.json" ] \
         && [ "$(jq -cS 'del(.acknowledged_exposure, .list_ids)' "$SC_DIR/categories.approved.json")" = "$(cat "$tmp")" ]; then
        echo "Approved."
      else
        echo "Not approved yet."
      fi
      echo "Categories SHA-256: $(sc_sha256 "$tmp")"
    fi
    rm -f "$tmp"
    ;;
  approve-categories)
    [ $# -ge 2 ] || sc_die "usage: plan.sh approve-categories <hash from plan.sh categories> [--publishes-private]"
    sc_require plan.json stars.json
    exposure=$(jq -c -L "$SC_JQ" --slurpfile stars "$SC_DIR/stars.json" \
      'include "common"; sc_exposure($stars[0])' "$SC_DIR/plan.json")
    if [ "$exposure" != "[]" ] && [ "${3:-}" != "--publishes-private" ]; then
      sc_die "these category changes make private Lists public (see the warning in plan.sh categories). Approve them only with: plan.sh approve-categories $2 --publishes-private"
    fi
    tmp=$(mktemp "${TMPDIR:-/tmp}/star-chart.XXXXXX")
    sc_categories_to "$SC_DIR/plan.json" "$tmp"
    sha=$(sc_sha256 "$tmp")
    if [ "$sha" != "$2" ]; then
      rm -f "$tmp"
      sc_die "the category changes (SHA-256 $sha) do not match $2. List them again with plan.sh categories and get a new approval."
    fi
    # Record which private-to-public changes the user acknowledged, so a List
    # that turns private later is caught by dry-run.sh and apply.sh.
    # And which List each name meant: an approval is of these Lists by id, so
    # a List that later takes one of these names is never taken for it.
    jq -cS -L "$SC_JQ" --argjson exp "$exposure" --slurpfile plan "$SC_DIR/plan.json" --slurpfile stars "$SC_DIR/stars.json" \
      'include "common"; ($stars[0].lists | sc_index_by(.name)) as $L
       | . + {acknowledged_exposure: ($exp | map(sc_exposure_key)),
              list_ids: ([(($plan[0].renames // [])[].list), (($plan[0].merges // [])[] | (.lists[], .into)),
                          (($plan[0].deletions // [])[].list)]
                         | map(ascii_downcase) | unique | map(select($L[.] != null) | {key: ., value: $L[.].id}) | from_entries)}' "$tmp" \
      >"$SC_DIR/categories.approved.json"
    rm -f "$tmp"
    echo "Recorded the approved category changes in $SC_DIR/categories.approved.json."
    ;;
  *)
    sc_die "usage: plan.sh render | parse | diff <a> <b> | validate | items | drop <id>... | categories | approve-categories <hash> [--publishes-private]"
    ;;
esac
