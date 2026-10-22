# validate.jq: check plan.json against the export and the rules.
#
#   jq -L scripts/jq --slurpfile stars stars.json --slurpfile cls <classification>
#      -f validate.jq plan.json
#
# Prints an array of error strings; [] means the plan may go to a dry run.
# The protection check here is what keeps apply.sh from unstarring a recent or
# keep-always repo, whatever the plan says.
#
# Naming: renames[].list, merges[].lists and deletions[].list use a List's
# current name. Every other List name (merges[].into, assignments[].lists)
# uses the name the List will have after the plan.
include "common";

def dupes(f): map(f | ascii_downcase) | group_by(.) | map(select(length > 1) | .[0]);
def blank: (. // "") | sc_trim == "";
# True when the input array of lower-cased names contains $k.
def names_include($k): index([$k]) != null;

($stars[0].stars | sc_index_by(.full_name)) as $repos
| ($stars[0].lists) as $lists
| ($lists | sc_index_by(.name)) as $byname
| ($cls[0].protected | sc_index_by(.repo)) as $protected
| (.lists_to_create // []) as $L
| (.renames // []) as $R
| (.merges // []) as $M
| (.deletions // []) as $D
| (.assignments // []) as $A
| (.unstar // []) as $U
| ($lists | map(.name | ascii_downcase)) as $existing
| ($R | map(.list // "" | ascii_downcase)) as $renamed
| ($M | map((.lists // [])[] | ascii_downcase)) as $merged
| ($D | map(.list // "" | ascii_downcase)) as $deleted
| ($L | map(.name // "" | ascii_downcase)) as $created
| ($R | map(.to // "" | ascii_downcase)) as $renamed_to
| ($A | map(.repo // "" | ascii_downcase)) as $assigned
# Lowercased names of every List that exists after the plan.
| ([$existing[] | select(. as $k | ($renamed | names_include($k)) or ($merged | names_include($k)) or ($deleted | names_include($k)) | not)]
   + $renamed_to + $created) as $final
| [
    ($L[] | .name as $n
      | if ($n | blank) then "lists_to_create: a List has no name"
        elif ($existing | names_include($n | ascii_downcase)) then
          "lists_to_create: List \"\($n)\" already exists; assign repos to it instead"
        elif ($renamed_to | names_include($n | ascii_downcase)) then
          "lists_to_create: List \"\($n)\" would collide with a rename"
        elif (.reason | blank) then "lists_to_create: List \"\($n)\" has no reason"
        else empty end),
    ($L | dupes(.name // "")[] | "lists_to_create: List \"\(.)\" appears more than once"),

    ($R[] | .list as $n | (.to // "") as $to
      | if ($n | blank) then "renames: a row has no List"
        elif ($existing | names_include($n | ascii_downcase)) | not then "renames: List \"\($n)\" does not exist"
        elif ($merged | names_include($n | ascii_downcase)) or ($deleted | names_include($n | ascii_downcase)) then
          "renames: List \"\($n)\" is merged or deleted; do one or the other"
        elif ($to | blank) then "renames: List \"\($n)\" has no new name"
        elif (($existing - [$n | ascii_downcase]) + $created | names_include($to | ascii_downcase))
             or ([$renamed_to[] | select(. == ($to | ascii_downcase))] | length) > 1 then
          "renames: renaming \"\($n)\" to \"\($to)\" would collide with another List"
        elif (.reason | blank) then "renames: List \"\($n)\" has no reason"
        else empty end),
    ($R | dupes(.list // "")[] | "renames: List \"\(.)\" is renamed more than once"),

    ($M[] | (.lists // []) as $src | (.into // "") as $into
      | if ($src | length) == 0 then "merges: a row names no List to merge"
        else
          ($src[] | . as $s | select(($existing | names_include($s | ascii_downcase)) | not) | "merges: List \"\($s)\" does not exist"),
          (if ($final | names_include($into | ascii_downcase)) | not then
             "merges: \($src | join(", ")) merges into \"\($into)\", which will not exist after the plan"
           else empty end),
          (if (.reason | blank) then "merges: \($src | join(", ")) has no reason" else empty end)
        end),
    ($merged | group_by(.) | map(select(length > 1) | .[0])[] as $k
      | "merges: List \"\($byname[$k].name // $k)\" is merged more than once"),

    ($D[] | .list as $n | ($n | ascii_downcase) as $k
      | if ($n | blank) then "deletions: a row has no List"
        elif ($existing | names_include($k)) | not then "deletions: List \"\($n)\" does not exist"
        elif $renamed | names_include($k) then "deletions: List \"\($n)\" is renamed and deleted; do one or the other"
        elif ($merged | names_include($k) | not) and ($byname[$k].item_count // 0) > 0 then
          "deletions: List \"\($n)\" still has \($byname[$k].item_count) repos; merge it into another List first"
        elif (.reason | blank) then "deletions: List \"\($n)\" has no reason"
        else empty end),
    ($D | dupes(.list // "")[] | "deletions: List \"\(.)\" appears more than once"),

    ($A[] | .repo as $r
      | if ($r | blank) then "assignments: a row has no repo"
        elif $repos[$r | ascii_downcase] == null then "assignments: \($r) is not in your stars"
        elif ((.lists // []) | length) == 0 then "assignments: \($r) names no List"
        elif (.reason | blank) then "assignments: \($r) has no reason"
        else (.lists[] | . as $l | select(($final | names_include($l | ascii_downcase)) | not)
              | "assignments: \($r) names List \"\(.)\", which will not exist after the plan")
        end),
    ($A | dupes(.repo // "")[] | "assignments: \(.) appears more than once"),
    ((.publish_private // []) | map(ascii_downcase)) as $ack
    | (sc_assignment_exposure($stars[0])[] | select((.repo | ascii_downcase) as $r | $ack | index([$r]) | not)
       | "assignments: \(.repo) is only in private Lists (\(.private | join(", "))); adding it to public \(.lists | join(", ")) makes that public. Acknowledge with plan.sh allow-public \(.repo), or drop it"),

    ($U[] | .repo as $r | ($r | ascii_downcase) as $k
      | if ($r | blank) then "unstar: a row has no repo"
        elif $repos[$k] == null then "unstar: \($r) is not in your stars"
        elif $protected[$k] != null then "unstar: \($r) is protected (\($protected[$k].reason)) and cannot be unstarred"
        elif ($assigned | names_include($k)) then "unstar: \($r) is both assigned to Lists and marked for unstar"
        elif (.reason | blank) then "unstar: \($r) has no reason"
        else empty end),
    ($U | dupes(.repo // "")[] | "unstar: \(.) appears more than once")
  ]
