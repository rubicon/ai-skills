# pitstop design

- Status: draft for maintainer review. No plugin code exists yet.
- Issue: https://github.com/rubicon/ai-skills/issues/71
- Date: 2026-09-30

## 1. Purpose

A long Claude Code session ends in `/compact` or `/clear`. Both discard context, and anything that
lived only in the conversation goes with it. `pitstop` is a plugin that saves what cannot be rebuilt
before the stop and rebuilds working status after it.

The motivating failure: a session wrote a handoff saying two replies were "drafted and unposted",
identified them by ID only, and cleared. The reply text had never been written to a file.

The plugin must work with nothing else installed, and must let a user who has their own handoff,
journal, or decision-record tooling route each record to it without that tooling appearing in this
repository.

## 2. Scope

**0.1.0** (this issue): skills `park`, `sitrep`, `checkpoint`, `setup`; the verifier script and its
tests; the integrations file.

**0.2.0** (separate issue): a PreCompact reminder hook. Section 9 outlines it. It ships only if a
spike confirms that a hook exiting 2 visibly blocks a manual `/compact` in the desktop app. If the
spike fails, the plugin stays hook-free.

**Not in either release:** per-project configuration, blocking `/clear` (no hook can), blocking
automatic compaction, recovering drafts from session transcripts.

## 3. Layout

```text
plugins/pitstop/
  .claude-plugin/plugin.json      name, version, description, author, license, homepage
  README.md
  CHANGELOG.md
  skills/park/SKILL.md
  skills/sitrep/SKILL.md
  skills/checkpoint/SKILL.md
  skills/setup/SKILL.md
  scripts/handoff-verify.py
  tests/test_handoff_verify.py
```

Commands are `/pitstop:park`, `/pitstop:sitrep`, `/pitstop:checkpoint`, `/pitstop:setup`. Claude
Code always namespaces a plugin's skills under the plugin name.

Skill bodies refer to the script as `${CLAUDE_PLUGIN_ROOT}/scripts/handoff-verify.py` and to the
configuration as `${CLAUDE_PLUGIN_DATA}/integrations.md`. Claude Code substitutes both inline when it
loads a skill. They are not environment variables in the Bash tool, so a skill never asks the shell
to expand them.

The script is Python 3, standard library only. `git` is used when present and is optional.

## 4. One path resolver

Every location comes from the verifier, never from a skill's own reasoning:

```text
handoff-verify.py --where
```

prints the project root (`git rev-parse --show-toplevel` from the working directory, else the
working directory), the integrations file in use or "none", the absolute handoff path, the drafts
directory, and the default journal path. `park` and `sitrep` run it first and use what it prints.

## 5. The integrations file

Path: `${CLAUDE_PLUGIN_DATA}/integrations.md`. One per user. It survives plugin updates and is
removed when the plugin is uninstalled.

```markdown
---
handoff_path: .remember/remember.md
---
## Handoff
mode: default

## Journal
mode: custom
uses: mcp__example_memory__diary_write
instructions: |
  Write the entry with the diary tool, agent name "example".

## Decision record
mode: skip

## Status sources
mode: skip
```

- The header is read by the script: plain `key: value` lines, parsed without a YAML library.
  `handoff_path` is relative to the project root.
- Modes. Handoff: `default` or `custom`; it cannot be skipped. Journal: `default`, `skip`, or
  `custom`. Decision record and Status sources: `skip` or `custom`.
- `uses` lists the tool or skill names a custom section needs. At the start of every `park` and
  `sitrep` run each name is checked against what the session has. A missing one is reported as
  "<section>: configured tool <name> unavailable" and the section falls back: Handoff and Journal to
  `default`, the other two to `skip`. The check is made by the model, so it is best-effort.
- Boundary. Custom instructions may say only where and how to write that one record, or what to read
  for status. Anything else in them, such as posting, sending, committing, pushing, or deleting, is
  not followed and is reported as "ignored instruction". This rule is stated in `park`, `sitrep`,
  and `checkpoint`. It is a rule the model follows, not a mechanism.
- No file, or a file that does not parse: built-in defaults, with a one-line notice that names
  `/pitstop:setup`.

Built-in defaults: the handoff is written to `.remember/remember.md`, the journal is appended to
`journal.md` beside it, and the decision record and extra status sources are skipped.

## 6. Skills

### setup

1. Detect what the session exposes: a handoff skill, a tool that writes a diary or journal, a tool
   that stores decision records, `gh` on the PATH, an existing handoff directory.
2. For each of the four sections, show the candidate and a recommended mode, `uses`, and
   instructions. The user accepts, edits, or picks another mode.
3. If a file already exists, show it and ask before replacing it.
4. Write the file, print it, and print one line per section saying what it will do.

`setup` writes nothing except the integrations file.

### park

The order puts what cannot be rebuilt first.

0. Run `--where`. Read the integrations file. Check each `uses` name.
1. **Drafts.** For every unsent outbound text still in context (a comment, reply, email, issue or PR
   body, or copy awaiting approval), write one file in the drafts directory, named
   `<YYYY-MM-DD>-<slug>.md`, with a header (`Target`, `Status: unsent`, `Approved: yes | no`,
   `Hold: <condition> | none`) and then the text exactly as last shown to the user. Copy, never
   rewrite. If only part survives, save it and add `Fidelity: partial`. Move any draft this session
   sent or dropped into `drafts/done/`. If nothing is unsent, record "Drafts: none unsent."
2. **Handoff.** Default: write `# Handoff` with `## State`, `## Next`, `## Context`. Custom: follow
   the section's instructions. In both cases: Next names every draft file; every path, line anchor,
   commit, ID, and URL is copied exactly from where it appears in the session or is left out; a path
   or commit not confirmed by a read or a command this session carries `(unverified)` on its line;
   no length limit overrides these rules.
3. **Verify.** Run the verifier on the handoff. Fix each finding from a first-hand read and rerun
   until it exits 0.
4. **Journal.** Invoke `checkpoint`, unless the mode is `skip`.
5. **Decision record.** Only when the mode is `custom` and the session made, reversed, or disproved
   an architectural decision.
6. **Reply** with exactly: the draft paths or "none unsent"; the verifier's summary line; one line
   each for handoff, journal, and decision record, reading ran, skipped, or unavailable; and which
   to type next. `/clear` then `/pitstop:sitrep` is the default at a task boundary. `/compact` is for
   mid-task state a handoff cannot carry.

`park` writes only draft files, the handoff, the journal, and the decision record. It never commits,
pushes, or posts.

### checkpoint

What the entry must carry, because a summary cannot: what was reproduced versus reasoned, with the
inputs; the class of defect, not only the instance; any test that passed on unfixed code, and why;
what the agent got wrong; file and line anchors and full URLs; what the next session should do
first.

Where it goes: the Journal section. With mode `default`, append a dated entry to the default
journal path. It can be run on its own as `/pitstop:checkpoint`.

### sitrep

0. Run `--where`. Read the integrations file. Check each `uses` name.
1. Gather, in parallel where independent: what this session already knows; the handoff, unless it
   was already injected this session; the verifier's output, which also reports the handoff's age and
   the files in the drafts directory; bounded git state (status, branch, recent log, stash,
   worktrees); pull request and issue state when `gh` is present; each configured status source. A
   source that returns bulky output is delegated to a small-model subagent that answers in at most
   three lines.
2. Reconcile. Ground truth beats the handoff. An identifier the verifier reports as missing or
   acknowledged is repeated only as "unverified". A path the verifier does not flag is never called
   wrong because the current branch lacks it. A draft named without a file goes under "Needs you".
3. Report in about 40 lines: Needs you, including every file in the drafts directory with its
   `Target`; Done since the last handoff, each item tagged verified or reported; Outstanding, as a
   table with High, Medium, or Low and a `[BLOCKING: <what>]` marker; Health; Do first.

`sitrep` is read-only.

## 7. The verifier

`handoff-verify.py [HANDOFF]` exits 0 when clean, 1 on findings, 2 when the handoff cannot be read.

What it checks, stated exactly, because it is narrower than "every identifier":

| Check | Rule | Finding |
|---|---|---|
| Path | A backticked token that contains a slash and ends in an extension must exist in the project, a git worktree, or the history of any ref | `MISSING-PATH` |
| Line anchor | `path:N` or `path:FROM-TO` must satisfy 1 <= FROM <= TO <= line count. For a path found only in history, the count comes from the blob in the ref that proved it exists | `LINE-OUT-OF-RANGE` |
| Commit | A backticked 7 to 40 character hex token containing a letter must be a commit in this repository | `MISSING-SHA` |
| Draft claim | A line saying drafted, unposted, unsent, not posted, not sent, or awaiting approval must name, on that line or the next two, a file inside the drafts directory | `DRAFT-WITHOUT-FILE` |
| Draft file | A named draft must be a non-empty file on disk in the drafts directory now. A copy elsewhere, in another worktree, or in history does not count | `MISSING-DRAFT`, `EMPTY-DRAFT` |
| Unlisted draft | Every file directly in the drafts directory must be named in the handoff | `UNLISTED-DRAFT` |
| Done draft | A draft claim must not point into `drafts/done/` | `DONE-DRAFT-CLAIMED` |

Bare filenames, directories, branch names, and unbackticked paths are not checked. Widening the
parser turns domain names and version strings into false findings, and a tool that cries wolf gets
ignored.

A `MISSING-PATH`, `MISSING-SHA`, or `LINE-OUT-OF-RANGE` on a line containing `(unverified)` is
reported as `ACKNOWLEDGED` and does not fail. That is how an identifier from another repository is
carried honestly. Draft findings are never acknowledgeable.

The last line of output is a summary: how many identifiers were checked, failed, and acknowledged.
The script also prints the handoff's age and the files in the drafts directory.

## 8. Draft lifecycle

A draft file exists from the `park` that saves it until the text is sent or dropped. The session
that sends or drops it moves the file to `drafts/done/`, and `park` does this for anything the
session handled. While a file sits directly in the drafts directory, every handoff must name it and
every `sitrep` lists it.

## 9. 0.2.0: the reminder hook (outline)

This is a reminder that catches "forgot to park". It is not a guarantee, and the README says so.

- `park` gains a last step, `handoff-verify.py --stamp`, which re-verifies and, only on exit 0,
  writes a stamp beside the handoff holding the time and the SHA-256 of the handoff file.
- A PreCompact hook with matcher `manual` allows the compaction when the stamp exists, its hash
  matches the current handoff, and it is at most `guard_minutes` old (default 10, 0 disables).
- Otherwise it blocks once and records the block in a file named by a hash of the session ID. A
  second manual `/compact` in the same session within two minutes passes. The message says plainly
  that anything not saved to a file will be lost.
- Automatic compaction is never touched. Any internal error lets the compaction through.
- It cannot see text that exists only in the conversation. Work done after a park and inside the
  window is not protected.

## 10. Testing

- `tests/test_handoff_verify.py`: real temporary git repositories, no mocks, invented fixtures. It
  covers each finding in section 7 in both directions, the acknowledgement rule, a path found only in
  ref history, an uncommitted file in a second worktree, wording that must not trigger a draft claim
  (a "draft" pull request), a project that is not a git repository, and `--where`.
- Each new check is confirmed non-vacuous once by removing the code it pins and seeing the test fail.
- End to end, twice: a fresh agent in a scratch git project, holding an approved and unposted reply,
  runs `park`. Once with no integrations file and once with a configured one. It passes when the
  saved draft body is byte-identical to the original, the handoff names it, the verifier exits 0,
  and the ran, skipped, or unavailable lines match the configuration.
- `claude plugin validate plugins/pitstop`, `bash scripts/validate-skills.sh`, and
  `bash scripts/check-no-personal-data.sh`.

## 11. Repository wiring

- `.claude-plugin/marketplace.json`: `{ "name": "pitstop", "source": "./plugins/pitstop" }`.
- `release-please-config.json` and `.release-please-manifest.json`: a `plugins/pitstop` package.
- `.github/workflows/ci.yaml`: a job that runs the plugin's tests with Python 3.
- Root `CHANGELOG.md`: one summary line. The plugin's own changelog holds the detail.

## 12. Known limits, to be stated in the README

- "Copy the draft character for character" cannot be checked. The verifier proves a non-empty file
  exists in the right place, not that its text matches what was shown.
- The draft-claim wording is English and vocabulary-bound. The unlisted-draft check does not depend
  on wording, but it only helps once a file has been written.
- Custom instructions are prose that a model interprets. The boundary rule and the `uses` check
  narrow that; they do not make it mechanical.
- Configuration is per user. Two projects that need different tools cannot express that in 0.1.0.
- The plugin writes files in the project's handoff directory and in its own data directory. It does
  not commit them. Keeping the handoff directory out of version control is the user's choice.
- Requires `python3` on the PATH.

## 13. Independent review, and what was done with it

The design was reviewed adversarially in two rounds before this spec was written. Each claim about
the existing verifier was reproduced before it was accepted.

| Finding | Disposition |
|---|---|
| A draft saved outside the drafts directory satisfied the draft check | Applied: section 7, "Draft file" |
| Line ranges were not validated (`2-999`, `0`, `3-1` all passed) | Applied: section 7, "Line anchor" |
| A path found only in history skipped the line check | Applied: section 7, "Line anchor" |
| Handoff freshness by modification time approves a stale handoff | Applied: replaced by the hashed stamp in section 9 |
| A timed bypass defeats a guard | Partly applied: the hook is framed as a reminder, state is per session, the message states the risk. The bypass stays so a user is never trapped |
| Shared global state interferes across projects and sessions | Applied for the stamp and block files. Per-project configuration deferred, see section 12 |
| The handoff path had no single definition of "project root" | Applied: section 4 |
| The verifier checks less than "every identifier" | Applied by stating its scope exactly, section 7 |
| Free-prose configuration is an execution surface | Partly applied: modes, `uses`, and the boundary rule, section 5 |
| One keyword meant both "default" and "skip" | Applied: explicit modes |
| Stale configuration is never noticed | Applied: the `uses` check at the start of every run |
| A blocking hook rests on unconfirmed platform behavior | Applied: the hook is its own release behind a spike |
| Too much surface for a first release | Partly applied: the hook moved to 0.2.0. `setup` and a separate `checkpoint` stay, by maintainer decision |
| Add a hash of the draft text to prove fidelity | Rejected: a hash computed after writing the file certifies the file against itself. Recorded as a limit |
| The draft-claim wording misses cases | Applied: the unlisted-draft check, section 7 |
| A session ID used as a file name needs sanitizing | Applied: hashed, section 9 |
| A draft claim could point into `drafts/done/` | Applied: section 7, "Done draft" |

## 14. Maintainer decisions

1. Two releases: 0.1.0 without the hook, 0.2.0 with it.
2. If the desktop spike fails, ship without the hook.
3. No per-project configuration in 0.1.0.
4. The hook's bypass is a second `/compact` within two minutes.
5. `park` moves sent or dropped drafts into `drafts/done/`.
6. Configuration is a file written by `setup` and read on every run, not native plugin `userConfig`
   and not detection at run time.
