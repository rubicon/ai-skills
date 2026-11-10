# session-id-mod

A Claude Code mod that draws a pill above the prompt reading `Session ID: <id>`. Click it to copy the current session's ID to your clipboard. It makes it quick to hand a session's ID to another session, for example for cross-session messaging.

The ID is read each time the band draws, so it follows `/clear` and resume. A toast confirms the copy, or gives the reason when the clipboard call fails.

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install session-id-mod@rubicon
```

Requires a Claude Code release that runs mods (2.1.294 or later). Start a new session after installing so the mod loads.

## Behavior and limits

- The pill sits above the prompt and reads `Session ID:` in a semibold weight, then the full session ID. Clicking it copies the ID alone, without the label.
- On the desktop app the pill is inset from the left edge with space above and below it, matching Token Weather Usage's pills. The ID is italic in a monospaced face and a copy icon ends the pill. A desktop Button cannot hold an icon or keep its text styling, so those are plain elements and one Button lies over the whole pill to take the click.
- On the terminal the label and the ID sit inside a single Button, with no icon and no italics.
- Hovering over the pill shows a small "Click to copy" hint above it. The hint floats, so showing it moves nothing else. Mods have no native tooltip, so it is a hover-revealed box, and on a terminal the hover works only where the terminal reports mouse movement.
- The mod reads the session ID and writes to the clipboard through the mod API. It reads no files, runs no programs and uses no network.

## Tests

```bash
claude plugin test plugins/session-id-mod
```
