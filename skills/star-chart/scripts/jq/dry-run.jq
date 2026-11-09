# dry-run.jq: print the calls from ops.jq, with counts, a time estimate, and
# every move of private categorization into public view.
#
#   jq -r --arg target <rules target or ""> -f dry-run.jq ops.json
def count($op): [.ops[] | select(.op == $op)] | length;

"Write calls apply.sh would make, in order:",
"",
(.ops[]
  | if .op == "create_list" then
      "  graphql createUserList  name=\(.name | @json) private=\(.private)"
    elif .op == "rename_list" then
      "  graphql updateUserList  \(.from | @json) -> \(.to | @json)\(if .before.isPrivate and (.private | not) then "  (private -> public)" else "" end)"
    elif .op == "set_lists" then
      "  graphql updateUserListsForItem  \(.repo)  [\(.before_names | join(", "))] -> [\([.after[].name] | join(", "))]\(
        if (.publishes | length) > 0 then "  (private -> public: \(.publishes | join(", ")))" else "" end)"
    else
      "  REST DELETE /user/starred/\(.repo)"
    end),
"",
"Write calls: \(.ops | length) (\(count("create_list")) createUserList, \(count("rename_list")) updateUserList, \(count("set_lists")) updateUserListsForItem, \(count("unstar")) unstar)",
"Already in place, no call: \(.unchanged | length)",
(([.ops[] | select((.publishes // []) | length > 0)] | length) as $pub
  | if $pub > 0 then "Moves of private List membership into public Lists: \($pub)" else empty end),
(([.ops[] | select(.op != "unstar")] | length) as $listcalls
  | ((((.ops | length) * 0.8 + $listcalls * 1.0) / 60) | ceil | if . < 1 then 1 else . end) as $min
  | "Time: at least about \($min) minute\(if $min == 1 then "" else "s" end) (\(.ops | length) calls, a 0.3 s pause each plus GitHub's response time, assumed 0.5 s; each of the \($listcalls) List calls also re-reads your Lists first, assumed 1 s; none of it measured). Rate limits can add much more."),
(if count("create_list") > 0 then
   "",
   "New Lists are created last, after the moves into existing Lists. GitHub may limit how many Lists",
   "you can have (the limit is not verified). If a creation fails, run delete-lists.sh to delete the",
   "emptied Lists, then re-run apply.sh with the same hash; finished calls are skipped."
 else empty end),
(if (.deletions | length) > 0 then
   "",
   "Deletions run later with delete-lists.sh, after the moves, and need their own confirmation.",
   "It deletes a List only if a fresh read shows it empty:",
   (.deletions[] | "  graphql deleteUserList  \(.name | @json)")
 else empty end),
"",
"Lists after this plan: \(.lists_after) (now \(.lists_now); target in rules.md: \(if $target == "" then "none" else $target end))"
