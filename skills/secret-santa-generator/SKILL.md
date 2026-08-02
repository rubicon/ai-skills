---
name: secret-santa-generator
version: 4.0.0
description: >-
  Generate Secret Santa assignment lists from participant names and optional
  exclusion pairs. Use when the user asks to organize a Secret Santa, assign
  recipients, resolve duplicate names, or validate exclusion constraints.
---

# Secret Santa Generator

Generate a randomized Secret Santa assignment list from participant names and optional exclusion rules.

## When To Use

Use this skill when the user:
- Wants to organize or run a Secret Santa
- Needs a randomized giver-to-recipient assignment list
- Has exclusion pairs that must not be matched
- Wants duplicate names resolved before assignments are generated
- Wants results as plain text, CSV, or JSON

## Inputs

Accept participant names in any mix of these formats:
- One name per line
- Comma-separated
- Semicolon-separated
- Pipe-separated
- Tab-separated
- Space-separated

Accept exclusions in any of these formats:
- `EXCLUDE: Mum & Dad, Alice & Bob`
- `EXCLUDE:` followed by one pair per line
- Flexible spacing around delimiters

Within an exclusion pair, the names may be separated by:
- `&`
- `|`
- `+`
- `/`
- `and`
- `vs`
- `-`
- `,`

Trim leading and trailing whitespace from every name.

## Rules

- Every person gives to exactly one other person.
- Every person receives from exactly one other person.
- No one is assigned to themselves.
- Exclusions are symmetric. If `A` cannot give to `B`, then `B` cannot give to `A`.
- Ignore blank entries.
- Never silently remove duplicate names.
- If fewer than two valid participants remain after cleanup, explain why and ask the user to revise.
- If exclusions make a valid assignment impossible, explain why and suggest removing one or more exclusion pairs.

## Duplicate Names

If a name appears more than once:
- Stop before generating assignments.
- Tell the user which name is duplicated and how many times it appears.
- Ask whether the duplicate is accidental or refers to different people.
- If it is intentional, ask for a designator so the names can be distinguished.
- Confirm the resolved names before continuing.

## Assignment Workflow

1. Normalize and deduplicate the input.
2. Parse exclusions.
3. Validate that at least two participants remain.
4. Randomly shuffle the participant list.
5. Assign each person the next person in the shuffled list, wrapping around at the end.
6. Verify that no self-assignments or exclusion violations exist.
7. If the assignment is invalid, retry with a different shuffle.
8. If repeated retries fail, explain that the constraints are impossible and ask the user to revise the exclusions or participants.

## Output Format

Present results clearly and consistently.

Recommended plain-text format:
- `Alice -> Charlie`
- `Bob -> Diana`
- `Charlie -> Alice`
- `Diana -> Bob`

Then include a short summary:
- Participant count
- Pairing count
- Exclusion count
- Validation status

If the user wants it, also provide the results as:
- CSV
- JSON

## Safety And Validation

Before presenting results, confirm:
- Every participant appears exactly once as a giver
- Every participant appears exactly once as a recipient
- No one is assigned to themselves
- No exclusion rule is violated

If validation fails, do not present the result as final.

## Examples

User: "Set up a Secret Santa for Alice, Bob, Carol, and Dave. Bob and Carol are married, so don't pair them."
Result: A valid randomized assignment that respects the exclusion rule.

User: "Run a Secret Santa for our 12-person team, list attached."
Result: Parse the names, validate the set, and generate assignments.
