---
name: secret-santa-generator
version: 4.1.0  # x-release-please-version
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

Accept participant names in any of these formats:
- One name per line
- Comma-separated
- Semicolon-separated
- Pipe-separated
- Tab-separated
- Space-separated, only when every name is a single word and no other separator is present

Names may contain spaces and hyphens ("Mary Ann", "Mary-Kate"). If it is unclear where one name ends and the next begins, show the list you parsed and ask before drawing.

Accept exclusions in any of these formats:
- `EXCLUDE: Mum & Dad, Alice & Bob` (commas or semicolons separate pairs)
- `EXCLUDE:` followed by one pair per line
- Flexible spacing around delimiters

Within an exclusion pair, the two names may be separated by:
- `&`
- `|`
- `+`
- `/`
- the whole word `and`
- the whole word `vs`

Never treat `-` or `,` as the separator inside a pair: hyphens belong to names, and commas separate pairs.

Trim leading and trailing whitespace from every name and collapse internal runs of spaces.

## Options

- **No mutual pairs** (off by default). When the user asks that no two people draw each other, forbid A giving to B while B gives to A. Larger loops (A to B to C to A) are still allowed. With exactly two participants this option makes a draw impossible; say so.

## Rules

- Every person gives to exactly one other person.
- Every person receives from exactly one other person.
- No one is assigned to themselves.
- Exclusions are symmetric. If `A` cannot give to `B`, then `B` cannot give to `A`.
- Ignore blank entries.
- Never silently remove duplicate names.
- Every name in an exclusion must match a participant (ignoring case and extra spaces). If one does not, stop and ask; never ignore it.
- If fewer than two valid participants remain after cleanup, explain why and ask the user to revise.
- If exclusions make a valid assignment impossible, explain why and suggest removing one or more exclusion pairs.

## Duplicate Names

Compare names ignoring case and extra spaces, so `alice` and `Alice ` are duplicates. If a name appears more than once:
- Stop before generating assignments.
- Tell the user which name is duplicated and how many times it appears.
- Ask whether the duplicate is accidental or refers to different people.
- If it is intentional, ask for a designator so the names can be distinguished.
- Confirm the resolved names before continuing.

## Assignment Workflow

Do not shuffle or pick recipients yourself. The draw script does it with real randomness and checks every rule.

1. Parse the participants and exclusions, apply the rules above, and resolve any duplicates or unknown exclusion names with the user.
2. Run `scripts/draw.py` from this skill's directory, passing one JSON object on stdin:

   ```bash
   python3 <skill-dir>/scripts/draw.py <<'JSON'
   {"participants": ["Alice", "Bob", "Carol", "Dave"],
    "exclusions": [["Bob", "Carol"]],
    "no_mutual_pairs": false}
   JSON
   ```

   Never pass a `seed` field; it exists only for the script's tests and makes the draw predictable.
3. Read the `status` in the JSON output:
   - `ok` (exit 0): present `assignments` and `summary`.
   - `impossible` (exit 2): no valid assignment exists. Explain the `reason` and suggest which exclusion or option to drop.
   - `too_constrained` (exit 2): a valid assignment may exist, but the rules are too tight for a fair random draw. Explain and ask the user to loosen an exclusion.
   - `error` (exit 1): fix the input (the `error` names the problem) or ask the user.

Every valid assignment is equally likely, including ones made of several small loops.

If Python cannot run in this environment, say so, draw by hand, check the result against Safety And Validation below, and tell the user the draw was not made or verified by the script.

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
- Whether "no mutual pairs" was on
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

If validation fails, do not present the result as final. The script performs these checks itself; still confirm them for any draw made by hand.

## Examples

User: "Set up a Secret Santa for Alice, Bob, Carol, and Dave. Bob and Carol are married, so don't pair them."
Result: A valid randomized assignment that respects the exclusion rule.

User: "Draw names for Alice, Bob, Carol, Dave, and Erin, and nobody should get the person who has them."
Result: Run the script with `no_mutual_pairs` set to true.

User: "Run a Secret Santa for our 12-person team, list attached."
Result: Parse the names, validate the set, and generate assignments.
