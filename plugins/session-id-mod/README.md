# session-id-mod

A Claude Code mod that draws a small copy icon above the prompt. Click it to copy the current session's ID to your clipboard. Hover over it to read the ID first. It makes it quick to hand a session's ID to another session, for example for cross-session messaging.

The ID is read each time the band draws, so it follows `/clear` and resume. A toast confirms the copy, or gives the reason when the clipboard call fails.

## Install

```bash
/plugin marketplace add rubicon/ai-skills
/plugin install session-id-mod@rubicon
```

Requires a Claude Code release that runs mods (2.1.294 or later). Start a new session after installing so the mod loads.

## Behavior and limits

- The icon sits in a rounded pill above the prompt. Hovering over the pill shows a card above it with the session ID. The card floats, so showing it moves nothing else.
- Mods have no native tooltip, so the card is a hover-revealed box. On a terminal the hover works only where the terminal reports mouse movement.
- The icon is a text glyph drawn at the surface's largest text step. The terminal has a single text size, so it draws the icon at normal size there.
- The mod reads the session ID and writes to the clipboard through the mod API. It reads no files, runs no programs and uses no network.

## Tests

```bash
claude plugin test plugins/session-id-mod
```
