# rules.jq: read rules.md into JSON.
#
#   jq -R -s -L scripts/jq -f rules.jq rules.md
#
# Only bullet lines ("- ...") under a "## " heading count; prose is ignored.
# Under "## Settings" each bullet is "Label: value". A missing setting takes
# its default; an unreadable number stops with an error naming the setting.
include "common";

def setting($items; $label):
  [$items[] | select(ascii_downcase | startswith($label))] | first
  | if . == null then null else (split(":")[1:] | join(":") | sc_trim) end;

def whole_number($value; $default; $label):
  if $value == null or $value == "" then $default
  else ($value | tonumber? // null) as $n
    | if $n != null and $n == ($n | floor) and $n >= 0 then $n
      else error("rules.md: \"\($label)\" must be a whole number, got \"\($value)\"")
      end
  end;

split("\n")
| reduce .[] as $line ({section: null, items: {}};
    if ($line | test("^##\\s")) then
      .section = ($line | sub("^##\\s+"; "") | sc_trim | ascii_downcase)
    elif .section != null and ($line | test("^\\s*[-*]\\s+")) then
      .items[.section] += [$line | sub("^\\s*[-*]\\s+"; "") | gsub("`"; "") | sc_trim]
    else . end)
| .items as $i
| ($i["settings"] // []) as $s
| {
    stale_months: whole_number(setting($s; "stale cutoff"); 24; "Stale cutoff"),
    protect_days: whole_number(setting($s; "protect recent stars"); 90; "Protect recent stars"),
    flag_archived: ((setting($s; "flag archived") // "yes") | ascii_downcase | test("^(yes|true|on)$")),
    deprecated_terms: (
      (setting($s; "flag descriptions containing") // "deprecated, unmaintained")
      | split(",") | map(sc_trim | ascii_downcase) | map(select(. != ""))
    ),
    target_lists: (
      setting($s; "target number of lists") as $t
      | if $t == null or $t == "" then null else whole_number($t; null; "Target number of Lists") end
    ),
    keep_always: ($i["keep always"] // []),
    categories_use: ($i["categories to use"] // []),
    categories_avoid: ($i["categories to avoid"] // [])
  }
