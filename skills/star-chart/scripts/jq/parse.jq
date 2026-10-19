# parse.jq: read an edited plan.md back into plan.json.
#
#   jq -R -s -L scripts/jq -f parse.jq plan.md > plan.json
#
# Reads only the tables render.jq writes. The first row under each heading is
# the column header and is skipped, as is the |---| separator. A row with the
# wrong number of cells stops with an error quoting the row.
include "common";

def cells:
  sc_trim | gsub("\\\\\\|"; "\u001f") | split("|") | .[1:-1]
  | map(sc_trim | gsub("\u001f"; "|"));

def need($c; $n; $section; $line):
  if ($c | length) != $n then
    error("plan.md: a row under \"\($section)\" needs \($n) cells: \($line)")
  else . end;

def names: sc_split_names;
def yes: ascii_downcase | test("^(yes|y|true)$");

split("\n") as $lines
| ([$lines[] | select(startswith("<!-- star-chart plan"))] | first // "") as $meta
| def meta($k): [$meta | capture("\($k)=(?<v>[^;]*?)\\s*(;|-->)") | .v] | first // "";
  reduce $lines[] as $line ({section: null, header: false,
      out: {lists_to_create: [], renames: [], merges: [], deletions: [], assignments: [], unstar: []}};
    if ($line | test("^##\\s")) then
      .section = ($line | sub("^##\\s+"; "") | sc_trim | ascii_downcase) | .header = false
    elif .section == null or ($line | test("^\\s*\\|") | not) then .
    elif ($line | test("^\\s*\\|[\\s:|-]+$")) then .
    elif .header | not then .header = true
    else
      ($line | cells) as $c
      | if .section == "lists to create" then
          need($c; 4; "Lists to create"; $line)
          | .out.lists_to_create += [{name: $c[0], description: $c[1], private: ($c[2] | yes), reason: $c[3]}]
        elif .section == "list renames" then
          need($c; 5; "List renames"; $line)
          | .out.renames += [{list: $c[0], to: $c[1],
              description: (if $c[2] == "" then null else $c[2] end),
              private: (if $c[3] == "" then null else ($c[3] | yes) end), reason: $c[4]}]
        elif .section == "list merges" then
          need($c; 3; "List merges"; $line)
          | .out.merges += [{lists: ($c[0] | names), into: $c[1], reason: $c[2]}]
        elif .section == "list deletions" then
          need($c; 2; "List deletions"; $line)
          | .out.deletions += [{list: $c[0], reason: $c[1]}]
        elif .section == "assignments" then
          need($c; 3; "Assignments"; $line)
          | .out.assignments += [{repo: $c[0], lists: ($c[1] | names), reason: $c[2]}]
        elif .section == "unstar" then
          need($c; 2; "Unstar"; $line)
          | .out.unstar += [{repo: $c[0], reason: $c[1]}]
        else . end
    end)
| {version: 1, generated_at: meta("generated_at"), based_on_export: meta("based_on_export")} + .out
