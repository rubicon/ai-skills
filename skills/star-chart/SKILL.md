---
name: star-chart
version: 0.1.0  # x-release-please-version
description: >-
  Use when the user wants to organize or clean up their GitHub stars: consolidate their GitHub
  Lists into a tight set of categories (rename, merge, delete), sort starred repos into Lists,
  find stale, archived or deprecated stars to unstar, export their stars, review stars added
  since the last run, or undo an earlier run. Claude analyzes and proposes, the user approves or
  rejects each part in pop-up questions, and Claude runs every step; every change is logged and
  can be undone. Triggers on "organize my GitHub stars", "clean up my stars", "consolidate my
  star lists", "too many GitHub lists", "sort my starred repos into lists", "unstar old repos",
  "undo the star cleanup".
---

# star-chart

Organize and prune a user's GitHub stars with `gh` and `jq` only. It is meant to be run again and
again: each run proposes changes for the stars and Lists as they are now, the user decides in
pop-up questions, and you run every script. The user never types a command or opens a file to
take part, and nothing on GitHub changes without their answer.

`<skill>` below is this skill's base directory, shown when the skill loads. Every script has a
header comment saying what it does and whether it touches GitHub.

## Hard rules

- **You run everything.** Never ask the user to run a command or to go read a file. Show results
  in the conversation, and offer the full plan table in the app's file view when the harness has
  one (in Claude Code, send the file for inline viewing), as an option, never a requirement.
- **Every decision is a pop-up.** Use the harness's structured question tool (`AskUserQuestion` in
  Claude Code; numbered options in chat where there is none). Follow the conventions below. No
  answer, a dismissal, or a timeout means no.
- **Nothing changes on GitHub except through `apply.sh`, `delete-lists.sh` and `undo.sh`**, and
  only after the user's answer in the matching pop-up. No ad-hoc `gh api -X DELETE`, no
  hand-written mutations.
- **Private categorization is never published quietly.** Any change that makes a private List's
  repos visible in a public List is asked about separately, item by item, even when the user
  chose "approve all", and the default is to keep it private.
- **Never request a token scope yourself.** If the scope check fails, the user has to sign in
  in their browser; tell them the one command it prints and wait for them to say it is done.
- **Run the writing scripts with the prefix they print.** When `GH_TOKEN` or `GITHUB_TOKEN` is set,
  the printed commands start with `env -u GH_TOKEN -u GITHUB_TOKEN`, so `gh` uses the stored login
  that carries the `user` scope. Use the command exactly as printed.
- **Working files stay in the data directory** (`$STAR_CHART_DIR`, default `~/.star-chart`).
  Never copy `stars.json`, plans, rules or logs into a repository.

## Pop-up conventions

- One decision per question, up to 4 questions per pop-up and up to 4 options per question. The
  label is a short action; the description says what happens and whether it can be undone.
- Mark options the way the right-stuff skill does: `(Recommended)` on what you would advise, and
  `(Right Thing)` on the careful choice; one option can carry both.
- **Three-way gate** (categories, assignments, unstars): "Approve all", "Review individually",
  "Reject all". Recommend "Approve all" only when the set is small and you would stand behind every
  item; otherwise recommend "Review individually". "Review individually" is the `(Right Thing)`.
- **Individual review** uses checkbox questions (`multiSelect`): up to 4 items per question, 4
  questions per pop-up, so 16 items per pop-up; continue with the next pop-up until every item has
  been seen. Ask "Which of these do you approve?": checked means approved, unchecked means
  rejected. Labels come from `plan.sh items` (`label`), descriptions from `detail` and `reason`.
  The user can add notes or type under "Other"; follow them.
- After a review, drop the rejected items with `plan.sh drop <id>...` and tell the user in one line
  what else was dropped because it depended on them (the script prints it).

## Before you start

Run `gh auth status`; it must pass. Reading stars needs no special scope. The writing steps need
the classic `user` scope and refuse without it; when they do, show the user the command they
print (`gh auth refresh -s user`, with the token prefix when needed) and wait. Every writing step
also checks that `gh` is signed in as the account the data belongs to, and refuses otherwise.
star-chart has not verified whether a fine-grained token can change Lists, so it does not guess.

## A run, step by step

### 1. Export (read-only)

Run `bash <skill>/scripts/export.sh` and tell the user the counts it prints. `stars.json` holds
every star with its description, language, topics, stars, archived flag, last push, when it was
starred, its Lists, and `new`: starred after the export of the last **fully applied** plan, so
cleanup left unfinished last time comes up again.

### 2. Rules

Show the settings in `rules.md` (stale cutoff, protection window, flags, target number of Lists,
keep-always patterns, categories to use and avoid). Pop-up: "Use these rules" or "Change some"
(on the first run, recommend reviewing them). Make any change they ask for in `rules.md` and show
it back. Then run `bash <skill>/scripts/classify.sh`: `flagged` holds unstar candidates and why,
`protected` the stars that may never be unstarred, `lists` each List's size, flags, languages and
overlap, `unlisted` the stars in no List.

### 3. Categories

Propose a tight set of categories from `lists`, the rules, and the target: rename unclear Lists,
merge Lists that overlap or are too small, delete Lists that are empty or emptied by a merge, and
create a List only for a theme nothing covers. Do not move a private List's repos into a public
List unless the rules or the user ask for it. Write `plan.json` with only `lists_to_create`,
`renames`, `merges` and `deletions` (format below), run `plan.sh render`, then
`plan.sh items` and `plan.sh categories`.

Summarize in chat (how many creations, renames, merges, deletions; the List count against the
target), then the three-way gate. Items with `"publishes": true` are never part of "approve all":
ask about them in their own question, defaulting to keep private. Deletions are ordinary items
here: decided now, carried out after the moves, and only for Lists that are empty by then.

When the user has decided, drop what they rejected, run `plan.sh categories` again, and record
the approval: `plan.sh approve-categories <hash>`, adding `--publishes-private` only if they
approved every private-to-public item still listed. "Reject all" drops every category item. If
nothing is left, say so and move on.

### 4. Assignments and unstars

Add `assignments` (for this run's stars, using the approved category names) and `unstar` (only
from `flagged`, never `protected`) to `plan.json`, each with a reason the user can check. On later
runs, propose assignments only for stars with `"new": true`, and unstars only from `flagged`
entries that are `newly_flagged` or `new`; say how many older flags you left alone. Run
`plan.sh render` and `plan.sh items`.

- **Assignments:** summarize per List (how many repos, a few examples), offer the full table in the
  file view, then the three-way gate. "Review individually" is one checkbox per List
  (`assignment_groups`); to leave out single repos, the user names them in their notes, and you
  drop those with `assign:<owner/repo>`. A group's `private_repos` are repos that are only in
  private Lists today: ask about them separately, and run `plan.sh allow-public <owner/repo>...`
  only for the ones the user approves (drop the rest).
- **Unstars:** summarize with the reasons, then the three-way gate. "Review individually" is one
  checkbox per repo.

### 5. Dry run

Run `bash <skill>/scripts/dry-run.sh`. It changes nothing and prints every call in order (renames,
moves into existing Lists, unstars, List creations, moves that need a created List), the counts,
every move of private categorization into public view, a time estimate, the deletions to come,
the List count against the target, and `Approval SHA-256` with the apply command. Summarize it:
the counts, the time estimate, every rename, creation, unstar and private-to-public move. Pop-up:
"Apply now", "Show every call first", "Cancel".

### 6. Apply

Run the apply command the dry run printed, in the background (it can take many minutes), and
report progress. It makes exactly the calls the user approved, and holds each one to what the
approval showed:

- Lists are identified by id, never looked up by name, so a List that took an approved List's
  name is never written to.
- Every List a call names must still have the name and visibility the dry run showed.
- A membership change applies only the approved change to the repo's Lists as they are right
  before the call, so a List added or removed on another device in the meantime is kept.
- Before every unstar it re-reads `rules.md` and the stars starred inside the protection window.

It checks every call against a fresh read before the first one; if your Lists changed since the dry
run, it stops with nothing changed, and you go back to the export and the dry run. During the run it
checks each call again right before every attempt, a retry after a rate limit or a server error
included, refuses any that no longer fits (with the reason), and continues with the rest. Every change is logged before it is sent and again with its outcome:
`ok`, `failed` (GitHub refused; nothing changed), `unknown` (no answer; it may have happened),
`refused` (no longer fits; not sent), or `exists` (already in place).

When it finishes, report the counts and every refusal with its reason. If anything failed or is
unknown, pop-up: "Retry now" (re-running the same command skips what finished and repeats the rest
safely), "Undo this run", "Leave it". Do not export again before a retry: a new export changes the
approval hash. Refused calls need a new export and plan once retries are done.

If a List creation failed, GitHub may limit how many Lists a user can have (the limit is not
verified). New Lists are created last for this reason: run step 7 to free slots, then retry.

### 7. Delete the emptied Lists

Only when approved deletions remain. Run `bash <skill>/scripts/delete-lists.sh --run` (with the
prefix it uses). It deletes only Lists the category approval names, only if they still exist and
are empty, only the same List (by id) the approval was based on, never another List that has taken
its name, and checks each one again right before deleting it. Report what it deleted and what it
skipped and why. A repo added from another device in the second between that check and the
delete would be lost from that List: GitHub has no "delete only if empty".

### 8. Finish

Run `export.sh` again so `stars.json` matches GitHub. Then pop-up: update "Categories to use" in
`rules.md` to the final List names, so the next run keeps to the same set, or leave it.

## Undo

When the user wants to reverse a run (or after a failed apply, from step 6):

1. Run `bash <skill>/scripts/undo.sh --list-runs` and offer the most recent runs as pop-up options
   (run id, when, what it changed, how many outcomes are unknown).
2. Run `bash <skill>/scripts/undo.sh --run <run_id>` and summarize the calls it lists. Pop-up:
   "Undo this run", "Cancel".
3. On yes, run the command it printed (with `--approved <hash>`) and report the result.

Undo re-stars repos, reverses each membership change the run made (adds back the Lists it removed,
removes the Lists it added, and keeps edits made since), renames Lists back, and recreates deleted
Lists with their name, description and privacy. It checks each step right before every attempt
against the state the run left, which apply logged, and refuses one whose List changed since
(renamed, made public or private, or gone), with the reason. Changes
with an unknown outcome are reversed too; every reversal is safe to repeat, and an interrupted undo
resumes where it stopped. Undo a deletion run (`delete-...`) before the apply run it followed, so the Lists exist
when membership is restored. What it cannot restore: the original `starred_at` (a re-starred repo
counts as new next time), a deleted List's id and URL, the visibility of anything that was public
for a while, and Lists a run created (they are listed, not deleted).

## plan.json

```json
{
  "version": 1,
  "generated_at": "<now, ISO 8601 UTC>",
  "based_on_export": "<stars.json exported_at>",
  "lists_to_create": [
    {"name": "Static Site Tools", "description": "Generators and themes", "private": false,
     "reason": "Eleven generator repos have no List"}
  ],
  "renames": [
    {"list": "misc js", "to": "JavaScript Libraries", "description": null, "private": null,
     "reason": "Match the naming of the other Lists"}
  ],
  "merges": [
    {"lists": ["Hugo Themes", "Jekyll"], "into": "Static Site Tools",
     "reason": "Both under five repos, same theme"}
  ],
  "deletions": [
    {"list": "Hugo Themes", "reason": "Empty after the merge"}
  ],
  "assignments": [
    {"repo": "owner/repo", "lists": ["Static Site Tools"], "reason": "A Markdown site generator"}
  ],
  "unstar": [
    {"repo": "owner/other", "reason": "Archived; no push since 2022-03-01"}
  ]
}
```

- `renames[].list`, `merges[].lists` and `deletions[].list` use a List's **current** name;
  `merges[].into` and `assignments[].lists` use its name **after** the plan. In a rename, `null`
  keeps the current description or visibility.
- `assignments[].lists` names Lists to **add**; a repo keeps the Lists it is in. A merge moves every
  repo of the merged Lists into the target. A deletion is allowed only for a List that is empty
  after the plan.
- `publish_private` is written only by `plan.sh allow-public`.
- `plan.sh` validates on every change and prints any error; fix it before the dry run.

## Scripts

| Script | Changes GitHub | Use |
|---|---|---|
| `export.sh` | no | read every star and List into `stars.json` |
| `classify.sh` | no | apply `rules.md`: flags, protection, List statistics |
| `plan.sh render`, `parse`, `diff`, `validate` | no | keep `plan.json` and `plan.md` in step, and check the plan |
| `plan.sh items`, `drop`, `allow-public` | no | build the pop-ups; apply the user's answers |
| `plan.sh categories`, `approve-categories` | no | list and record the category approval |
| `dry-run.sh` | no | every call, counts, the approval hash |
| `apply.sh --approved <hash>` | yes | carry out the plan; re-run to resume |
| `delete-lists.sh --run` | yes | delete approved Lists that are empty now |
| `undo.sh --list-runs`, `--run <id> [--approved <hash>]` | only with `--approved` | reverse a run |

## Files in the data directory

| File | Written by | Holds |
|---|---|---|
| `rules.md` | the user, or you on their request | standing rules |
| `stars.json` | `export.sh` | the latest export |
| `classification.json` | `classify.sh` | flags, protection and List statistics now |
| `classification.prev.json`, `state.json` | `apply.sh` | flags and export at the last fully applied plan |
| `plan.json` | you, `plan.sh` | the plan |
| `plan.md`, `plan.rendered.json` | `plan.sh render` | the readable table and what it showed |
| `categories.approved.json` | `plan.sh approve-categories` | the category changes the user approved, the id of every List they name, and which private-to-public changes they acknowledged |
| `changes-YYYY-MM-DD.jsonl` | `apply.sh`, `delete-lists.sh`, `undo.sh` | every change, before and after, append-only |
