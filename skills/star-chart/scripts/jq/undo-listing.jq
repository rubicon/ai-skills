# undo-listing.jq: print the calls from undo.jq for the user to approve.
#
#   jq -r -f undo-listing.jq undo.json
[.[] | select(.op == "recreate_list") | .old_id] as $recreated
| def idtext: . as $id | if $recreated | index([$id]) then "recreated \($id)" else $id end;
  def ids: map(if .name != null then "\(.name | @json) (\(.id | idtext))" else (.id | idtext) end) | join(", ");
  .[]
| (if .uncertain then "  (outcome unknown; repeating it is harmless)" else "" end) as $u
| if .op == "restar" then "  REST PUT /user/starred/\(.repo)\($u)"
  elif .op == "set_lists" then
    "  graphql updateUserListsForItem  \(.repo)  \([(if (.add | length) > 0 then "add [\(.add | ids)]" else empty end),
      (if (.remove | length) > 0 then "remove [\(.remove | ids)]" else empty end)] | join(", "))\($u)"
  elif .op == "rename_back" then
    "  graphql updateUserList  \(.list_id | idtext)  name=\(.expects.name | @json) private=\(.expects.isPrivate)\($u)"
  elif .op == "recreate_list" then
    "  graphql createUserList  name=\(.name | @json) private=\(.private)  (recreates deleted List \(.old_id)\(if .uncertain then "; skipped if a List with that name exists" else "" end))"
  else "  kept: List \"\(.name)\" (\(.list_id)), created by run \(.run_id)" end
