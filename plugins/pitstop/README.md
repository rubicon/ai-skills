# pitstop

Save what a `/compact` or `/clear` would destroy, then rebuild status after it.

A long Claude Code session ends in a compact or a clear, and both throw context away. Text that lived only in the conversation, such as a reply you drafted and had not posted yet, goes with it. pitstop writes those drafts to files, writes a handoff that names them, checks the handoff mechanically, and writes a journal entry. After the stop, it rebuilds status from the handoff and from git.

## Commands

- `/pitstop:park`: before a compact or clear. Saves drafts, writes and verifies the handoff, writes the journal entry, and tells you whether to clear or compact. If another session already parked a handoff in this folder, park leaves it in place and writes its own beside it as `remember-<session>.md`, and sitrep reads them all. So handoffs do not pile up, park also deletes any handoff nobody has touched for 30 days, including another session's, and says which it deleted.
- `/pitstop:sitrep`: at the start of a session. Reports what needs you, what is done, and what is outstanding. Read-only.
- `/pitstop:catch-up`: coming back after time away. Two or three sentences on where the current branch stands and the next real piece of work. Read-only. Use `sitrep` for everything else in flight.
- `/pitstop:checkpoint`: the journal entry on its own, plus fact updates when Facts is configured.
- `/pitstop:setup`: route the handoff, journal, decision records, status checks, or facts to tools you already use.

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install pitstop@rubicon
```

Requires `python3` on your PATH. `git` and `gh` are used when present.

## Configuration

None is required. With no configuration, the handoff goes to `.remember/remember.md` in the project, drafts to `.remember/drafts/`, and the journal to `.remember/journal.md`. Run `/pitstop:setup` to change that, or to turn on Facts: an optional section that points checkpoint at a fact store you already use (any tool that looks up, adds, and replaces a subject, predicate, and value). With Facts on, checkpoint looks up each fact this session confirmed, replaces a changed value instead of adding a second one, adds new ones, and skips anything unconfirmed, multi-valued, or in conflict. It stops at the first store error. setup writes one file in the plugin's data directory, which is removed if you uninstall the plugin.

## What the verifier checks

`scripts/handoff-verify.py` checks backticked paths that contain a slash and end in an extension, line anchors on them (`path:12` or `path:12-20`), and commit hashes. It fails a handoff that says something is drafted or unposted without naming a saved file, and one that leaves a saved draft unnamed. Bare filenames and unbackticked text are not checked. Mark a line `(unverified)` to carry an identifier from somewhere the verifier cannot see.

## Limits

- Nothing can prove a draft file holds exactly the text you were shown. The verifier proves a non-empty file exists in the right place.
- The wording that marks a draft claim is English: drafted, unposted, unsent, not posted, not sent, awaiting approval. The unlisted-draft check does not depend on wording.
- Facts are only as good as what the session confirmed. checkpoint does not re-check a fact against its source before writing it.
- Custom instructions in the configuration are read by the model. pitstop ignores anything in them beyond writing that one record, but that is a rule the model follows, not a mechanism.
- Configuration is per user, not per project.
- pitstop does not commit the files it writes. Whether the handoff directory is in version control is your choice; drafts may hold text you have not published.
- Nothing can stop `/clear`. Run park first.

## Credits

`catch-up` is adapted from the `/catch-up` magic prompt in [OpenChamber](https://github.com/openchamber/openchamber) (MIT, Copyright (c) 2025 Bohdan Triapitsyn). The wording here is pitstop's own.

See [CHANGELOG.md](CHANGELOG.md).
