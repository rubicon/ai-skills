# render.jq: write plan.json as the human-editable plan.md.
#
#   jq -r -L scripts/jq -f render.jq plan.json > plan.md
#
# parse.jq reads this layout back, so the headings, column order and the
# metadata comment are a contract between the two files. Assignments are
# listed by their first List, so each category's repos sit together.
include "common";

def cell: tostring | gsub("[\r\n]+"; " ") | gsub("\\|"; "\\|");
def yes_no: if . then "yes" else "no" end;
def keep_or(f): if . == null then "" else f end;

"# star-chart plan",
"",
"<!-- star-chart plan v1; generated_at=\(.generated_at // ""); based_on_export=\(.based_on_export // "") -->",
"",
"Edit the tables, then tell Claude you are done. Delete a row to drop it, change a cell to change it,",
"add a row to add one. Keep the columns. Separate several Lists with commas, and write a literal pipe",
"inside a cell as `\\|`. List names in Merges \"Into\" and in Assignments are the names after this plan.",
"",
"## Lists to create",
"",
"| Name | Description | Private | Reason |",
"|---|---|---|---|",
((.lists_to_create // [])[]
  | "| \(.name | cell) | \(.description // "" | cell) | \(.private // false | yes_no) | \(.reason // "" | cell) |"),
"",
"## List renames",
"",
"Leave New description or Private empty to keep the current value.",
"",
"| List | New name | New description | Private | Reason |",
"|---|---|---|---|---|",
((.renames // [])[]
  | "| \(.list | cell) | \(.to | cell) | \(.description | keep_or(cell)) | \(.private | keep_or(yes_no)) | \(.reason // "" | cell) |"),
"",
"## List merges",
"",
"| Merge these Lists | Into | Reason |",
"|---|---|---|",
((.merges // [])[] | "| \(.lists | sc_join_names | cell) | \(.into | cell) | \(.reason // "" | cell) |"),
"",
"## List deletions",
"",
"Only Lists that are empty after the plan. These run in a separate step that asks again.",
"",
"| List | Reason |",
"|---|---|",
((.deletions // [])[] | "| \(.list | cell) | \(.reason // "" | cell) |"),
"",
"## Assignments",
"",
"| Repo | Lists | Reason |",
"|---|---|---|",
((.assignments // []) | sort_by((.lists[0] // "" | ascii_downcase), (.repo | ascii_downcase)) | .[]
  | "| \(.repo | cell) | \(.lists | sc_join_names | cell) | \(.reason // "" | cell) |"),
"",
"## Unstar",
"",
"| Repo | Reason |",
"|---|---|",
((.unstar // [])[] | "| \(.repo | cell) | \(.reason // "" | cell) |")
