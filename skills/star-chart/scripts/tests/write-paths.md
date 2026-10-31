# star-chart write paths and the rules they keep

Every call that changes GitHub, the approvals those calls rest on, the rules
each must keep, and the test in `test-star-chart.sh` that shows it does. A new
write path, approval, or rule gets a row or a column here and a test for each
cell before it ships. The suite fails if any test named in a table cell did
not pass in the same run.

## Scope

star-chart changes one person's GitHub stars and Lists, on request, after
approvals, with a log and an undo. What it defends against, and what it
accepts, decides what a review finding is.

**Defended.** Each of these is a bug, and every rule below serves one of them.

1. Private categorization becoming public without the user's yes.
2. Unstarring, deleting, renaming or writing to anything the user did not
   approve, including a List that has since taken an approved List's name.
3. Losing what undo needs, or recording an outcome that is not known, after
   the failures a normal run meets: rate limits, server errors, dropped
   connections and truncated answers, an interrupted run or undo, a retry,
   and a run or undo resumed later.
4. A safety check that fails open: a check that cannot be completed must
   refuse the call.

**Accepted.** Documented, not engineered around. None of them loses data
silently: the worst result is a refused or `unknown` step the user sees, or
the one-second race below.

1. An edit made elsewhere in the about one second between a fresh read and
   the call that follows it. GitHub has no "change only if unchanged".
   Likewise, after a create or recreate whose answer was lost, the re-check
   that follows takes up a List of that name and visibility as the one just
   made: one created elsewhere with the same name in that interval would be
   taken for it. A same-name List found at any other time is refused.
2. Undo after the user has also changed the same Lists by hand in ways that
   conflict with the run: the conflicting steps are refused, with the reason,
   and the user decides.
3. GitHub behaving outside its documented API (wrong status codes, writes
   that report success and did not happen).
4. Two star-chart runs, or a run and an undo, at the same time on the same
   account.

**Exit rule for reviews.** A finding is fixed before release when it is a P1,
or a P2 in a defended class. Anything else is filed as a GitHub issue for a
later release. A finding that shows an accepted item does lose data silently
moves to defended.

## Rules

| Rule | Meaning |
|---|---|
| R1 Approved only | Only calls the user approved run. The approval hash covers the plan, every call, and every List as the approval saw it. |
| R2 By id | Lists are identified by id, in the approvals as in the calls. Nothing is looked up by name when writing, so a List that took an approved List's name is never written to. |
| R3 Contract | Every List a call names is in the state its contract requires (`requires`, checked by `jq/contract.jq`): a List a repo ends up in, in its final approved state; a List a repo leaves, as approved or gone; a rename's List, with the name, description and visibility approved. A repo only in private Lists at the call goes into a public List only as the approval acknowledged. Undo's contracts come from the state the log recorded at the run. |
| R4 Approved change only | A membership call applies only the approved change to the repo's Lists as they are right before it; edits made elsewhere are kept. |
| R5 Every attempt checked | The contract is checked against a fresh read before every attempt, a retry included (`sc_checked_call`). `sc_call` never resends. A check that cannot be completed, or gives no clear answer, refuses the call: the check functions fail closed explicitly, since bash ignores `set -e` inside them. |
| R6 Honest outcome | A call that may have happened (a server error, no answer, an answer cut off) stays `unknown` unless a fresh read shows it did; success needs a complete answer. Anything other than `ok` or `exists` leaves the run unfinished: exit 2, and apply keeps the baseline. Undo reverses a call from its last attempt only: an attempt is retried only after a fresh read shows it did not land. That holds only because every write path can tell from a fresh read that it already happened (a rename's expected state, a membership already as approved, a created or recreated List found, a deleted List gone, a repo no longer or again starred); a new write path must have that check too. |
| R7 Logged | Every attempt is logged before it is sent, with the state of the Lists it touches as they are at that moment, and again with its outcome. |
| R8 Protection | An unstar is checked against current `rules.md` and the stars starred inside the protection window, before every attempt. |

## Approvals

| Approval | R1 | R2 |
|---|---|---|
| categories: plan.sh approve-categories | approving with the wrong hash refuses; a changed merge needs a new approval; apply refuses category changes that differ from the approval | the category approval records the id of every List it names; the dry run refuses a replaced List; delete-lists refuses it too; and deletes nothing |
| calls: dry-run.sh approval hash | apply with the wrong hash refuses; and says the plan changed | the approval records every List as it was |

## Paths

Tests are named by the text of their `ok` line. "Unit" tests run one decision
(`apply-step.jq`, `undo-step.jq`, `sc_checked_call`); "e2e" tests run the
script against `tests/bin/gh`, a stand-in GitHub that keeps state.

| Path | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 |
|---|---|---|---|---|---|---|---|---|
| apply: rename | apply with the wrong hash refuses | rename: List deleted, refused | rename: renamed by someone else, refused; rename: List made public, refused; rename: description edited elsewhere, refused; rename: a description-only change is made | n/a | a rate limit is retried after a new check; a retry the new check refuses is refused, not sent; a check with no clear answer is a refusal; and nothing is sent | rename: already renamed, nothing to do | every call is logged as started, then ok | n/a |
| apply: membership | apply with the wrong hash refuses | membership: a List replaced by another of the same name, refused; e2e: and nothing is written to the replacement | membership: a private target made public, refused; membership: a target whose rename has not happened, refused; membership: a created List made private since, refused; membership: a repo only in private Lists now does not go public unacknowledged | membership: a List added since is kept; membership: a List removed since stays removed; e2e: and keeps that edit | e2e: and rebuilt from a fresh read, keeping an edit made meanwhile | e2e: a List replaced mid-run leaves the plan unfinished; is seen on the re-read, not sent again | a membership call logs the state of the Lists it touches | n/a |
| apply: create | apply with the wrong hash refuses | create: someone else's List has the name, refused | create: not if its visibility differs; create: not if it existed at approval | n/a | e2e: the re-check finds it, so it is not created twice | e2e: a create that landed despite a server error completes; a re-run does not take up a same-name List an interrupted run may have made; and changes nothing; e2e: a create whose answer was cut off completes; its outcome comes from the re-check, with the List it found; and it is not created twice | every call is logged as started, then ok | n/a |
| apply: unstar | apply refuses a protected unstar even with a matching hash | n/a (by repo) | n/a | n/a | e2e: an unstar retry re-checks protection first | e2e: a refused unstar leaves the plan unfinished; e2e: an unstar that landed despite a server error completes; the re-check sees it is no longer starred, so it is not sent again; one attempt is logged, with the repo's Lists; an unstar of a repo no longer starred is already in place | e2e: an unstar logs the repo's Lists as they are at the call; and undoing it completes | e2e: a refused unstar leaves the plan unfinished; an unstar retry re-checks protection first; e2e: a run whose protection check breaks is unfinished; the unstar is refused; and not sent |
| delete-lists: delete | delete-lists refuses too | a different List that took an approved List's name is not deleted | a List that still holds repos is not | n/a | a rate-limited deletion is not resent once the List holds a repo | the re-check finds it gone, so it is not sent again | a deletion is logged first with what undo needs to recreate the List; a retried deletion logs the List as the attempt found it | n/a |
| undo: re-star | a hash approved for one run does not undo every run | n/a (by repo) | n/a | n/a | e2e: a re-star that landed despite a server error completes; the re-check sees it is starred again, so it is not sent again | undo reverses successful and uncertain changes, newest first | an undo step is logged before each attempt, then with its outcome | n/a |
| undo: membership | undo with the wrong hash refuses | undo membership: a recreated List is used, following every recreation | undo membership: a List to restore made private since, refused; undo membership: a List to restore is gone, refused; undo membership: a List with no recorded state, refused; undo membership: a List to remove the repo from changed since, refused; undo membership: a List to remove the repo from that is gone is fine; undo membership: a List an undo already renamed back is accepted as it left it; undo membership: but not a state no undo restored; e2e: undo does not use a state an unrelated undo restored; and does not put the repo into the now-public List | undo membership: the run's change is reversed; e2e: every List is back as it was, plus the user's own edit | a rate limit is retried after a new check; a retry the new check refuses is refused, not sent; a check with no clear answer is a refusal; and nothing is sent | undo membership: already as before, nothing to do; undo reverses only the attempt that was made; e2e: an undo with a failed step is unfinished; run again, it finishes; and boundary/at-cutoff is out of the List again | an undo step is logged before each attempt, then with its outcome | n/a |
| undo: rename back | undo with the wrong hash refuses | undo rename: a recreated List is renamed under its new id | undo rename: renamed again since, refused; undo rename: description edited since, refused | n/a | a rate limit is retried after a new check; a retry the new check refuses is refused, not sent; a check with no clear answer is a refusal; and nothing is sent | e2e: an undo with a refused step leaves it unfinished | an undo step is logged before each attempt, then with its outcome | n/a |
| undo: recreate | undo with the wrong hash refuses | undo deletion: another List has the name, refused | n/a (no List to check) | n/a | e2e: the re-check finds it, so it is not recreated twice | undo deletion: already recreated, nothing to do; undo deletion: right after the undo's own uncertain attempt, the List is taken up | and the new id is recorded for later steps | n/a |

## What no rule can close

GitHub has no "change only if unchanged". Between the fresh read and the call,
about a second, a change made elsewhere can still be overwritten (membership)
or lost (a repo added to a List in the second before it is deleted).
