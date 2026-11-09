# diff.jq: summarize what changed between two plans.
#
#   jq -n -r -L scripts/jq --slurpfile a old.json --slurpfile b new.json -f diff.jq
#
# Matches Lists to create, renames and deletions by List name, merges by
# their source Lists, assignments and unstars by repo, all ignoring case.
# A change to a reason alone is not reported.
include "common";

def merge_key: (.lists // []) | map(ascii_downcase) | sort | join(",");

($a[0].lists_to_create // [] | sc_index_by(.name)) as $la
| ($b[0].lists_to_create // [] | sc_index_by(.name)) as $lb
| ($a[0].renames // [] | sc_index_by(.list)) as $ra
| ($b[0].renames // [] | sc_index_by(.list)) as $rb
| ($a[0].merges // [] | map({key: merge_key, value: .}) | from_entries) as $ma
| ($b[0].merges // [] | map({key: merge_key, value: .}) | from_entries) as $mb
| ($a[0].deletions // [] | sc_index_by(.list)) as $da
| ($b[0].deletions // [] | sc_index_by(.list)) as $db
| ($a[0].assignments // [] | sc_index_by(.repo)) as $aa
| ($b[0].assignments // [] | sc_index_by(.repo)) as $ab
| ($a[0].unstar // [] | sc_index_by(.repo)) as $ua
| ($b[0].unstar // [] | sc_index_by(.repo)) as $ub
| [
    ($lb | keys[] | select($la[.] == null) | "+ create List \"\($lb[.].name)\""),
    ($la | keys[] | select($lb[.] == null) | "- create List \"\($la[.].name)\""),
    ($la | keys[] | select($lb[.] != null and ($la[.] | del(.reason)) != ($lb[.] | del(.reason)))
      | "~ List \"\($lb[.].name)\": description or privacy changed"),
    ($rb | keys[] | select($ra[.] == null) | "+ rename \"\($rb[.].list)\" -> \($rb[.].to)"),
    ($ra | keys[] | select($rb[.] == null) | "- rename \"\($ra[.].list)\""),
    ($ra | keys[] | select($rb[.] != null and ($ra[.] | del(.reason)) != ($rb[.] | del(.reason)))
      | "~ rename \"\($rb[.].list)\": \($ra[.].to) -> \($rb[.].to)"),
    ($mb | keys[] | select($ma[.] == null) | "+ merge \($mb[.].lists | join(", ")) into \($mb[.].into)"),
    ($ma | keys[] | select($mb[.] == null) | "- merge \($ma[.].lists | join(", ")) into \($ma[.].into)"),
    ($ma | keys[] | select($mb[.] != null and $ma[.].into != $mb[.].into)
      | "~ merge \($mb[.].lists | join(", ")): into \($ma[.].into) -> \($mb[.].into)"),
    ($db | keys[] | select($da[.] == null) | "+ delete List \"\($db[.].list)\""),
    ($da | keys[] | select($db[.] == null) | "- delete List \"\($da[.].list)\""),
    ($ab | keys[] | select($aa[.] == null) | "+ assign \($ab[.].repo) -> \($ab[.].lists | join(", "))"),
    ($aa | keys[] | select($ab[.] == null) | "- assign \($aa[.].repo)"),
    ($aa | keys[] | select($ab[.] != null and $aa[.].lists != $ab[.].lists)
      | "~ assign \($ab[.].repo): \($aa[.].lists | join(", ")) -> \($ab[.].lists | join(", "))"),
    ($ub | keys[] | select($ua[.] == null) | "+ unstar \($ub[.].repo)"),
    ($ua | keys[] | select($ub[.] == null) | "- unstar \($ua[.].repo)")
  ]
| if length == 0 then "Plan changes: none"
  else
    "Plan changes: \(map(select(startswith("+"))) | length) added, \(map(select(startswith("-"))) | length) removed, \(map(select(startswith("~"))) | length) changed",
    .[]
  end
