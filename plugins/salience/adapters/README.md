# Adapters

Salience works fully with no adapter configured. Everything here is optional.

The design rule: **no capability depends on a single access path.** Each adapter raises a ceiling;
none is required, and Tier 0 (you paste the content) is not a degraded mode — for profile work,
positioning, drafting, and role alignment it is exactly equivalent.

| Adapter | Adds | Cost | Required for |
|---|---|---|---|
| `linkedin-import.md` | Your own complete career history | Free | Nothing — but it is the best onboarding path |
| `mcp-tools.md` | Publishing, own-post statistics | Free, OAuth setup | Publishing from inside Salience |
| `external-services.md` | Third-party post and engagement retrieval at volume | Paid per call | Engagement analysis at scale |

## What no adapter ever provides

Regardless of what any tool offers or claims:

- Credential, cookie, or session-token collection or reuse
- CAPTCHA or bot-detection bypass
- Rate-limit evasion
- Automation of the logged-in interface as if human

If an adapter's documentation offers these, it is not a supported adapter. Salience will refuse the
capability and say which supported path to use instead.

## Choosing

Start with none. Add `linkedin-import` when onboarding — it is free and it is the single highest-value
input. Add an MCP publishing tool only if copy-pasting approved drafts genuinely annoys you. Add a
retrieval service only if you are doing engagement analysis at a volume that makes pasting
impractical.

Most executives never need the third one.
