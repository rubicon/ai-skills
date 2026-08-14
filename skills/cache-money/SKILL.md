---
name: cache-money
version: 1.1.0  # x-release-please-version
description: >-
  Use when a Claude Code session is burning through tokens fast, hitting
  usage limits, degrading in quality after a long conversation, or someone
  wants to cut context/token spend. Covers session hygiene (/clear,
  /compact, /context, /cost, /mcp, /statusline), CLAUDE.md and
  file-reference discipline, model selection (Sonnet/Haiku/Opus), subagent
  cost, prompt-cache timing, and peak-hour scheduling — specific to Claude
  Code.
---

# Cache Money

Practices that keep Claude Code sessions cheap and sharp by controlling what gets re-sent every turn — because bloated context doesn't just cost more, it produces worse output.

## When to Use

- A session feels slow, expensive, or is close to a usage limit
- Someone asks how to reduce token/context spend, extend session life, or "why did my usage spike"
- Reviewing or writing a project's `CLAUDE.md`, MCP server setup, or subagent workflow
- Starting a long or multi-part task and deciding how to structure it
- Or just run `/cache-money` directly — once installed, this skill is a manual command too, no need to wait for Claude to decide it's relevant

## How Tokens Actually Work

- A token ≈ one word. Every message re-sends the **entire conversation from the beginning** — message 1, its reply, message 2, its reply... every single time. Cost compounds, it doesn't add: message 1 might cost 500 tokens, message 30 can cost 15,000+ because it re-reads everything before it. In one tracked 100+ message session, 98.5% of tokens went to re-reading old history — only 1.5% was new output.
- On top of message history, Claude Code reloads `CLAUDE.md`, every connected MCP server's tool definitions, system prompts, and referenced files on **every turn**. This overhead is invisible but constant.
- Bloated context also degrades quality, not just cost: "lost in the middle" research shows models pay less attention to content buried in long contexts. Keeping context tight is a quality move, not just a cost move.

## Tier 1 — Do These Every Session

| Hack | Do this |
|---|---|
| Start fresh conversations | Run `/clear` between unrelated tasks. Never carry topic-A context into a topic-B conversation — every message in a long chat costs exponentially more than the same message in a fresh one. This single habit extends session life more than anything else. |
| Disconnect unused MCP servers | Run `/mcp` at the start of each session and disconnect anything you won't use. Tool definitions are deferred by default (Tool Search), so an idle server only costs a name-listing entry — but the moment Claude actually uses one of its tools, that server's full definitions land in context for the rest of the session. Prefer a CLI over an MCP server when both exist — a CLI tool adds no listing overhead at all. |
| Batch prompts into one message | Three separate messages cost ~3x one combined message. Send "summarize, extract issues, suggest a fix" as one prompt, not three. If Claude gets something slightly wrong, edit your original message and regenerate — a follow-up correction stacks onto history permanently, an edit replaces the bad exchange entirely. |
| Use Plan Mode before real tasks | Let Claude map its approach and get your approval before writing a line. This prevents the single biggest source of waste: going down the wrong path, writing code, then undoing and redoing it. Consider adding to `CLAUDE.md`: "Do not make changes until you have 95% confidence in what you need to build. Ask follow-up questions until you reach that confidence." |
| Run `/context` and `/cost` | `/context` shows exactly what's eating tokens right now (history, MCP overhead, loaded files). `/cost` shows actual usage and spend for the session. Most people have no idea where their tokens go — you can't fix what you can't see. |
| Set up a status line | `/statusline` keeps model, context %, and token count visible in the terminal at all times, so you don't burn through everything and hit a wall without noticing. |
| Keep the usage dashboard open | Track current-session and weekly limits plus reset times so you know your real budget, not a guess. |
| Be smart with pasting | Before dropping a document, file, or error log into chat, ask: does Claude need the whole thing, or one section? Bug in one function → paste that function. Error in the last 10 log lines → paste those 10 lines. |
| Watch Claude work | Don't fire a prompt and walk away, especially on longer tasks. If it's stuck re-reading the same files, retrying the same approach, or exploring a dead end, hit Escape early. In a bad loop, 80%+ of tokens burned produce zero value — a few seconds of attention saves thousands of tokens. |

## Tier 2 — Project-Level Hygiene

| Hack | Do this |
|---|---|
| Keep `CLAUDE.md` lean | It auto-loads on every single turn, so a bloated file defeats its own purpose. Target under ~200 lines: tech stack, coding conventions, build commands, confidence rules — not your project's full history or docs Claude can read from source when needed. Treat it as an index that routes to where more detail lives, not an archive. |
| Be surgical with file references | Don't: "here's my whole repo, find the bug." Do: "check the `verifyUser` function inside `auth.js`." Use `@filename` to point at specific files instead of letting Claude explore freely. |
| Compact at ~60% capacity | Auto-compact triggers at ~95%, by which point context is already degraded. Check capacity with `/context`; at ~60%, run `/compact` with specific instructions on what to preserve. After 3–4 compacts in a row, quality starts to degrade further — at that point, have Claude write a session summary and `/clear` instead. |
| Move auto-compact earlier instead of watching manually | The ~95% default is a setting, not a fixed rule. `/autocompact 500k` (or `/autocompact auto` to reset) sets the auto-compact window directly — Claude Code v2.1.221+. `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` triggers compaction at a lower percentage of that window without needing to watch `/context` yourself. `CLAUDE_CODE_AUTO_COMPACT_WINDOW` sets the raw token window instead of a percentage. |
| Give compaction default instructions | Add a `# Compact instructions` section to the project's root `CLAUDE.md` (e.g., "preserve open task state, key file paths, and recent decisions; drop resolved tool output") so it applies automatically to every compaction — manual `/compact` or the automatic one — not just the one time you remember to type `/compact <instructions>`. |
| Mind the 5-minute cache timeout | Claude Code uses prompt caching to avoid re-processing unchanged context, but the cache expires after 5 minutes idle. Stepping away longer than that means your next message reprocesses everything from scratch at full cost — this is why usage can seem to spike "randomly" after a pause. Run `/compact` or `/clear` before a longer break. |
| Watch command-output bloat | When Claude runs shell commands, the full output enters context and gets re-sent every turn after — a 200-commit `git log`, a verbose test suite, a noisy build log, all of it. It scrolls by and feels free; it isn't. Pipe long output through `head`/`tail`, or ask Claude to limit output before running a command. |

## Tier 3 — Advanced Cost Control

| Hack | Do this |
|---|---|
| Pick the right model | Sonnet is the default for most coding work. Haiku for subagents, formatting, and simple tasks (~3x cheaper than Sonnet). Opus only for deep architectural planning, when Sonnet genuinely wasn't enough — keep it under ~20% of total usage. |
| Know the cost of subagents | Agent workflows run roughly 7–10x more tokens than a single-agent session, because each subagent runs its own full context window as a separate Claude instance. Delegate one-off tasks that can use Haiku; agent *teams* are very expensive — reserve them deliberately. |
| Understand peak hours | Anthropic adjusts how fast a 5-hour session window drains based on demand. Peak (drains faster): 8 AM–2 PM ET on weekdays. Off-peak (lasts longer): afternoons, evenings, weekends. Run big refactors, multi-agent sessions, and codebase rewrites off-peak. |
| Play the clock | Near a reset with budget left over: go heavy, run the big refactor, get your money's worth before it resets anyway. Near your limit with only 30–45 minutes to reset: step away instead of burning the last 5% on something small and getting stuck mid-task. |
| Make `CLAUDE.md` your system's constitution | Store stable decisions, architecture rules, and applied learnings there — not conversations. Every architectural call saved is a paragraph never retyped. Add explicit context-routing rules directly, e.g. "use subagents for any exploration or research; if a task needs 3+ files or multi-file analysis, spawn a subagent and return only summarized insights." When something fails repeatedly or a workaround is found for a platform/tool limitation, add a one-line bullet under an "Applied Learning" section — under 15 words, no explanation, only things that save time in future sessions. |

## Quick Reference — Action Checklist

- [ ] Run `/context` and `/cost`
- [ ] Status line showing model, context %, and token count
- [ ] Usage dashboard open (remaining allocation + reset time)
- [ ] Disconnect unused MCP servers via `/mcp`
- [ ] Start complex tasks in Plan Mode before writing code
- [ ] `/clear` when switching to an unrelated task
- [ ] Manually `/compact` at ~60% context capacity
- [ ] `CLAUDE.md` has a `# Compact instructions` section
- [ ] Batch multi-step instructions into single messages
- [ ] Schedule heavy sessions for off-peak hours

## Common Mistakes

| Mistake | Why it hurts |
|---|---|
| Treating pasted logs/docs or command output as "free" because it scrolls by | It's re-sent in full on every subsequent turn — one paste can cost more than the rest of the session |
| Relying on auto-compact | It triggers at ~95% capacity, after quality has already degraded from a bloated context |
| Sending follow-up corrections instead of editing | Follow-ups stack onto history permanently; an edited-and-regenerated message replaces the bad exchange entirely |
| Spinning up subagents or agent teams for trivial one-off work | Each subagent is a full separate context window — 7–10x the token cost of doing it directly |
| Leaving MCP servers connected "just in case" | Tool Search defers definitions until first use, but once Claude touches one tool on a server, that server's full definitions stay in context for the rest of the session — an idle server you never end up using is the only truly free case |

## Bottom Line

Most sessions don't need a bigger plan — they need to stop re-sending the entire conversation history 30 times when 5 would do. It's not a limits problem, it's a context-hygiene problem. The Tier 1 habits alone typically make a subscription feel like it doubled.
