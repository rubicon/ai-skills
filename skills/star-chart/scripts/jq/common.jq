# common.jq: definitions shared by the star-chart jq programs.
# Loaded with `jq -L <scripts/jq> ...` and `include "common";`.

# Strip leading and trailing whitespace.
def sc_trim: sub("^\\s+"; "") | sub("\\s+$"; "");

# Turn a keep-always pattern (owner/repo, * matches anything) into an anchored
# regex. Every other regex metacharacter is taken literally.
def sc_glob_re:
  "^" + (gsub("(?<c>[.+?^$(){}|\\[\\]\\\\])"; "\\\(.c)") | gsub("\\*"; ".*")) + "$";

# True when the input string matches any of the patterns, ignoring case
# (GitHub owner and repo names are case-insensitive).
def sc_matches_any($patterns):
  . as $name | any($patterns[]; . as $p | $name | test($p | sc_glob_re; "i"));

# ISO 8601 timestamp $n calendar months before the input timestamp.
# A day past the end of the target month rolls into the next month (timegm).
def sc_months_before($n):
  fromdateiso8601 | gmtime | . as $t
  | (($t[0] * 12 + $t[1]) - $n) as $m
  | [($m / 12 | floor), ($m % 12), $t[2], $t[3], $t[4], ($t[5] | floor), 0, 0]
  | mktime | todate;

# ISO 8601 timestamp $n days before the input timestamp.
def sc_days_before($n): fromdateiso8601 - ($n * 86400) | todate;

# Attach List membership to a stars document. $lists is the array that
# lib.sh sc_fetch_lists returns: each List with its items (repo node IDs).
def sc_apply_membership($lists):
  (reduce ($lists[] as $l | $l.items[]? | {repo: .id, list: $l.id}) as $p
     ({}; .[$p.repo] += [$p.list])) as $member
  | ($lists | map({key: .id, value: .name}) | from_entries) as $names
  | .lists = ($lists | map({id, name, description, isPrivate, item_count: (.items // [] | length)}))
  | .stars |= map(
      ($member[.node_id] // []) as $ids
      | .list_ids = $ids
      | .lists = [$ids[] | $names[.]]
    );

# Index an array of objects by a case-insensitive string key.
def sc_index_by(f): map({key: (f | ascii_downcase), value: .}) | from_entries;

# The plan's category changes (Lists to create, renames, merges, deletions)
# without their reasons: what the user approves at the category gate. A
# reworded reason therefore needs no new approval; any other edit does.
def sc_categories:
  {
    lists_to_create: [(.lists_to_create // [])[] | del(.reason)],
    renames: [(.renames // [])[] | del(.reason)],
    merges: [(.merges // [])[] | del(.reason)],
    deletions: [(.deletions // [])[] | del(.reason)]
  };

# List names in one plan.md cell: commas separate names, and a comma inside a
# name is written "\,".
def sc_join_names: map(gsub(","; "\\,")) | join(", ");
def sc_split_names:
  gsub("\\\\,"; "\u001e") | split(",") | map(sc_trim | gsub("\u001e"; ",")) | map(select(. != ""));

# Every List that exists after the plan, by its final name, with the id of
# the existing List it continues (none for a List the plan creates) and its
# final visibility. Input: the plan. $S: stars.json.
def sc_final_lists($S):
  ((.renames // []) | sc_index_by(.list)) as $ren
  | ([(.merges // [])[].lists[] | ascii_downcase]) as $merged
  | ((.deletions // []) | map(.list | ascii_downcase)) as $deleted
  | [
      $S.lists[]
      | (.name | ascii_downcase) as $k
      | select(($merged | index([$k])) == null and ($deleted | index([$k])) == null)
      | $ren[$k] as $r
      | {id, name: ($r.to // .name),
         private: (if $r != null and $r.private != null then $r.private else .isPrivate end)}
    ]
    + [(.lists_to_create // [])[] | {name, private: (.private // false)}];

def sc_final_list($final; $name):
  first($final[] | select((.name | ascii_downcase) == ($name | ascii_downcase))) // null;

# Category changes that make private categorization visible to anyone: a
# private List renamed to public, or a private List merged into a public one.
# Input: the plan. $S: stars.json.
def sc_exposure($S):
  sc_final_lists($S) as $final
  | ($S.lists | sc_index_by(.name)) as $by
  | [
      ((.renames // [])[] | $by[.list | ascii_downcase] as $l
        | select($l != null and $l.isPrivate and .private == false)
        | {kind: "rename", list: $l.name, repos: $l.item_count}),
      ((.merges // [])[] | sc_final_list($final; .into) as $t
        | .lists[] | $by[ascii_downcase] as $l
        | select($l != null and $l.isPrivate and $t != null and ($t.private | not))
        | {kind: "merge", list: $l.name, into: $t.name, repos: $l.item_count})
    ];

# What the user acknowledged when approving an exposure: its kind and Lists,
# without the repo count, which changes as repos come and go. Input: one
# sc_exposure entry.
def sc_exposure_key:
  {kind, list: (.list | ascii_downcase), into: ((.into // "") | ascii_downcase)};

# The exposures in sc_exposure($S) that $ack (sc_exposure_key values) does not
# cover, one line each. Input: the plan.
def sc_unacknowledged_exposure($S; $ack):
  sc_exposure($S)[]
  | select((sc_exposure_key) as $k | $ack | index([$k]) | not)
  | "\(.repos) repo\(if .repos == 1 then "" else "s" end)" as $n
  | if .kind == "rename" then "  ! \(.list | @json) (\($n)) would become public"
    else "  ! \(.list | @json) is private; its \($n) would join public \(.into | @json)" end;

# Why a repo may not be unstarred right now, or null. Input: owner/repo.
# $rules: the current rules.md as JSON. $recent: repos starred inside the
# protection window, read fresh from GitHub.
def sc_protection_reason($rules; $recent):
  . as $r
  | if ($r | sc_matches_any($rules.keep_always)) then "keep-always pattern"
    elif ($recent | map(ascii_downcase) | index([$r | ascii_downcase])) != null then
      "starred within the last \($rules.protect_days) days"
    else null end;

# Op keys that already finished for this approval, so a re-run skips them.
# A change a later undo reversed does not count, and neither does one whose
# outcome is unknown. Input: every change-log record.
def sc_done_keys($plan_hash):
  ([.[] | select((.op | startswith("undo_")) and .status == "ok") | .undoes]) as $undone
  | [.[] | select(.plan_hash == $plan_hash and (.status == "ok" or .status == "exists"))
         | select(("\(.run_id)/\(.op_key)") as $id | $undone | index([$id]) | not)
         | .op_key] | unique;

# Repos the plan assigns into a public List while every List they are in now
# is private: the assignment would make private categorization public.
# Input: the plan. $S: stars.json. Result: [{repo, lists: [public targets],
# private: [their current private Lists]}].
def sc_assignment_exposure($S):
  sc_final_lists($S) as $final
  | ($S.stars | sc_index_by(.full_name)) as $repos
  | ($S.lists | map({key: .id, value: .}) | from_entries) as $byid
  | [
      (.assignments // [])[] | $repos[.repo | ascii_downcase] as $s
      | select($s != null and ($s.list_ids | length) > 0 and all($s.list_ids[]; $byid[.].isPrivate))
      | [.lists[] | sc_final_list($final; .) | select(. != null and (.private | not)) | .name] as $public
      | select($public | length > 0)
      | {repo: $s.full_name, lists: $public, private: $s.lists}
    ];
