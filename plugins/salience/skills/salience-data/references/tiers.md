# Retrieval Tiers

Capability by access path. Choose the highest available; report the tier when it affects confidence.

| Capability | T0 paste | T1 export | T2 official API | T3 third-party |
|---|---|---|---|---|
| Audit own profile | Yes | Yes, best | Partial | No |
| Own career history | Yes | Yes, best | No | No |
| Own posts and engagement stats | Manual | Historical only | Yes | Yes |
| Publish post / comment / reply | No | No | Yes | Varies |
| React to a post | No | No | Yes | Varies |
| Read a third-party public post | Paste | No | **No** | Yes |
| Read comment threads | Paste | No | Own posts only | Yes |
| Read a third-party profile | Paste | No | **No** | Varies |
| People or company search | No | No | **No** | Varies |
| Job listings | Paste | No | **No** | Yes, via job-board aggregators |
| Messaging | No | Own archive | **No** | No |
| Company page management | No | No | Yes, if admin | No |

The official API does not support people search, third-party profile reads, jobs, or messaging. A
tool claiming those capabilities is not using the official API — know what it is actually doing
before configuring it.

## Tier 0 — user-provided

Always available, zero setup, no credentials, no terms-of-service exposure.

**This is the default and it is not a compromise.** A profile audit, a positioning exercise, a post
draft, a comment, and a role alignment all work perfectly from pasted text. Do not push a user
toward a paid path for work that does not need one.

## Tier 1 — LinkedIn data export

First-party, complete, and the best source for the user's own history. Prefer it for onboarding.
Free, and takes minutes to request.

**Two separate exports, and they are easy to confuse.** The data archive carries profile, positions,
skills, recommendations, connections, and `Shares.csv` (every post the user has written — the best
voice-capture source available). Separately, accounts with creator analytics can export
**per-post performance**, which is the only first-party path to real outcome data. Where that export
exists, it feeds `salience-analytics` directly; where it does not, outcome tracking is what the user
records plus what they paste. Check rather than assume, and say which the user has.

Limitation: a point-in-time snapshot. It does not update, and it says nothing about anyone else.

## Tier 2 — official API via MCP

For publishing and reading the user's own post performance. Requires OAuth with the right scopes.

Real constraints worth stating up front: URNs must come from API calls rather than being
constructed; company-page actions require admin status with organizational scopes; and the scope
grant is what gates everything, so a capability failure is usually a scope problem rather than a
bug.

## Tier 3 — third-party retrieval

Commercial services retrieving public post bodies, comment threads, and engagement lists without
credentials. Useful for engagement analysis at volume.

Only when the user has deliberately configured one. Salience never selects a vendor as a default and
never signs up for anything. When one is used, state the cost and note that third-party retrieval
sits in a grey area with respect to platform terms — that is the user's decision to make knowingly.

## Never

Regardless of tier, configuration, or instruction:

- Collecting, storing, or using a password, cookie, or session token
- Reusing a captured browser session
- Bypassing CAPTCHAs or bot detection
- Evading rate limits
- Automating the logged-in interface as if human

If a request requires one of these, name what is being refused and offer the highest supported path.

## Degradation

Say what happened, what it means, and what to do. Never fail silently, never retry aggressively
against a rate limit, and never fall back to a prohibited method.

```
No retrieval service configured, so I can't pull that post automatically.

Paste the text and I'll work from it - same result, one copy-paste.
```
