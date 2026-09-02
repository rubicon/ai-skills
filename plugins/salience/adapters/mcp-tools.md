# MCP Publishing Tools

Optional. Lets Salience publish approved drafts and read your own post statistics without leaving
the session.

**Approval is unchanged by this adapter.** Every publish still requires an explicit per-item yes.
The adapter removes the copy-paste, not the gate.

## What the official API supports

| Capability | Available |
|---|---|
| Publish a post (text, image, video, document) | Yes |
| Comment on and react to posts | Yes |
| Read your own posts and engagement statistics | Yes |
| Manage pages you administer | Yes, with organizational scopes |
| Read third-party profiles | **No** |
| People or company search | **No** |
| Job listings | **No** |
| Messaging | **No** |

A tool advertising the bottom four is not using the official API. Know what it is actually doing
before you configure it — several use browser automation or session reuse, which Salience refuses
regardless of how the tool wraps it.

## Configuring

Any MCP server exposing LinkedIn's official API over OAuth works. Salience discovers available tools
at runtime rather than requiring a specific vendor.

Expect to grant scopes for posting, reading your own content, and — only if you manage a company
page — organizational access. Grant the narrowest set that covers what you actually want.

## Two things that go wrong

**Confirm the target before every publish.** Posting as the person and posting as a company page
the user administers are different audiences, different voices, and different consequences. The
tools make them one parameter apart. The approval card must name which one, every time.

**Deletion is not an undo.** A published post may already have impressions, notifications, and
screenshots before it is removed, and removal is the only cleanup available. This is the whole
reason approval is per item and never batched — there is no meaningful way to take something back.

## Operating notes

These are real constraints, and a failure is usually one of them rather than a bug:

- **URNs come from API calls.** Member and organization URNs are returned by the API; they are never
  constructed from a profile URL. A tool that builds them will fail unpredictably.
- **Scopes gate everything.** A capability that "does not work" is usually a missing scope.
- **Company-page actions need admin status** on that page, plus organizational scopes.
- **Rate limits are real.** Salience does not retry aggressively against one. It reports and waits.
- **Media uploads first.** An image, video, or document is uploaded and referenced; a local file
  path passed straight to a post call fails.
- **One post per request** unless the user explicitly asked for several.

## Without it

Every draft is delivered as a copy-paste block with the destination link. That is the default path
and it costs one paste per publish. For most executives publishing a few times a week, this adapter
is convenience rather than capability.
