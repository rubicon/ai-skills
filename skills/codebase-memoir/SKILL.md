---
name: codebase-memoir
version: 1.0.0  # x-release-please-version
description: >-
  Judgment and practices for a codebase-memory-mcp knowledge graph. Load it alongside the
  codebase-memory tool reference whenever the task is more than tool syntax. Triggers on:
  write or update an ADR or architecture decision record for an indexed repo, should I
  reindex, pulled new commits into an indexed repo, detect_changes vs full reindex,
  worktrees doubling the graph, rename an indexed project, prove nothing calls a function,
  is this really dead code, are there other implementations, index coverage gaps,
  complexity and hot paths, cross-repo calls between services.
---

# Codebase Memoir

The `codebase-memory-mcp` server holds a queryable knowledge graph of indexed repos.
Indexing is **setup**. Querying is the point. The default failure mode is reindexing
often and querying never.

## Core rule: query the graph before reaching for grep

| Goal | Use | Not |
|---|---|---|
| Find a definition / implementation | `search_graph` | grep, glob |
| Find callers of X | `trace_path` (direction inbound; see the dead-code check below) | grep |
| Find what X calls | `trace_path` (direction outbound) | reading files |
| Read a symbol's source | `search_graph` → `get_code_snippet` | Read on the whole file |
| Text/literal search in indexed files | `search_code` | plain grep |
| Text in files the index skips or never saw (ignored, unsupported, or oversized files) | filesystem grep (`search_code` sees indexed files only) | `search_code` |
| "What is this repo?" orientation | `get_architecture` | reading README + poking around |
| Impact of a change already made (committed, uncommitted, or untracked) | `detect_changes` | manual tracing |
| Impact of a change you are planning | `trace_path` (direction inbound, widened as in the dead-code check below) | `detect_changes` |
| Complex multi-hop or aggregate questions | `query_graph` (Cypher) | many small searches |

`search_graph` search modes, and how they combine:
- `query="update settings"` — BM25 full-text, camelCase-aware. Best for natural-language discovery.
  When `query` is set, every filter except `file_pattern` is ignored through v0.11.0
  (`name_pattern`, `label`, `qn_pattern`, `min_degree`, `relationship`), with no error (unless
  the query reduces to no search terms, when the filters apply again). Later
  development builds honour `label`, `kind` and `namespace` too.
- `name_pattern=".*regex.*"` — exact pattern matching. Narrow it with `label` and `file_pattern`.
- `semantic_query=["..."]` — vector search that finds code named with different words (for example
  `publish` when you searched for `send`). Use it instead of `query`, not with it (v0.10.8
  quietly drops it and runs `query`; v0.11.0 rejects the two together), and only on a project
  indexed in moderate or full mode.

Reach for `semantic_query` when the first search comes back empty — the codebase may
simply use a different word than the one in the request.

## Maintenance

**Only some projects are watched.** The server refreshes in the background a project that is a
live session's working directory, and only while `auto_watch` is on (the default). Do not
full-reindex such a project for ordinary code changes. Any other indexed project (a cross-repo
target, a project indexed under a `name` override, a repo no open session is in) is not
refreshed: run `index_repository` on it after its code changes, for example after pulling new
commits. If `auto_watch` is off, treat every project this way.

`index_status` reports project health (counts, status, coverage). Through v0.10.8 it has no
freshness; v0.11.0 adds a project-level `indexed_at`. For freshness on specific files, call
`check_index_coverage` with `paths` (not only `scopes`): each path entry carries a `freshness`
field, such as `metadata_match`, `metadata_changed` or `missing`, from comparing the file's
size and modified time with what was indexed. Also run `index_repository` for a first index,
or after a codebase-memory upgrade that adds extraction features.

`detect_changes` does not update the graph: it is a read-only analysis that maps a git diff
(committed, uncommitted and untracked changes) to the changed symbols and their impact (two
hops by default). It only sees changes already made, so confirm the index is fresh before
trusting it.

**A plain `worktrees/` directory doubles the graph.** A `worktrees/` directory inside a repo
root gets indexed as real code: duplicate symbols, inflated degree counts, corrupted search
ranking. The convention is a `worktrees/` line in `.gitignore` (the indexer honors gitignore;
`.cbmignore` also works and is useful when a gitignore fix is stuck on an unmerged branch).
After adding the rule, reindex to purge symbols already in the graph. `.worktrees/` and
`.claude-worktrees/` are always skipped. `.claude/` is skipped by default (a `.cbmignore`
negation can bring it back), so Claude Code's `.claude/worktrees/` is normally not the cause.

Audit any project for this with:
```cypher
MATCH (f:File) WHERE f.file_path CONTAINS 'worktrees/' RETURN count(f)
```

**Renaming a project** means indexing under the new name (which creates a *new* project) then
`delete_project` on the old one. Before deleting, check for an ADR with
`manage_adr(mode='get', project='<OLD name>')`. `adr_present` on the new project does not tell
you whether the old one had an ADR: it reflects the new project's store, or a legacy
`.codebase-memory/adr.md` file in the repo root.

A renamed project is no longer the watched session project, because the watcher keys on the name
derived from the working directory. Reindex it by hand after code changes. With auto-indexing
on, the server can also index the repo again under its old derived name.

## Architecture Decision Records

An ADR is the memory half of codebase-memory: structure without intent is only half a graph.
Check with `manage_adr(mode='get')`. Write with `manage_adr(mode='update', content=...)`, which
replaces the whole ADR, so pass every section, not only the one you changed. From v0.11.0,
`mode='set_sections'` with a `section_updates` object (section name to new text) rewrites only
the named sections.

Sections: `PURPOSE`, `STACK`, `ARCHITECTURE`, `PATTERNS`, `TRADEOFFS`, `PHILOSOPHY`.

ADRs survive a full reindex. `delete_project` removes the project's stored ADR; only a legacy
`.codebase-memory/adr.md` file in the repo root outlives it.

### Generating an ADR for a repo

Draw on four sources, in this order — each answers something the others cannot:

1. **The graph** — `get_architecture(aspects=['all'])`. Gives structure, entry points,
   packages, routes, layers, and `clusters` (Leiden community detection over the call/import
   graph). Clusters reveal de-facto modules that often cut across the folder layout — if three
   clusters share one package name, that package is three modules wearing one coat.
2. **Git history** — `git log --oneline`, and especially merge commits and reverts. Reverts
   and re-reverts are where the real tradeoffs are recorded.
3. **Session notes** — if the repo keeps handoff notes between sessions (for example a
   directory of dated handoff files recording state, next steps and context), read them.
   This is decisional narrative that never reaches code comments: what was tried, what
   failed, what convention was adopted and why.
4. **Cross-session memory** — if a memory MCP server is connected, search it for the repo
   name and its major subsystems. Cross-session memory often holds the "why" behind a
   choice that no artifact in the repo records.

Then write the ADR from what those four agree on. Prefer recording **decisions and their
tradeoffs** over describing structure — structure is already in the graph and is regenerated
on every index; the reasoning is not, and is lost when the person who made it moves on.

Never invent a rationale. If a decision's motivation cannot be found in history, session notes,
or cross-session memory, record it as observed-but-unexplained rather than guessing at intent.

## Performance and code health

Every `Function` and `Method` node carries queryable complexity properties. This is a whole
audit surface reachable in one query:

- `complexity` (cyclomatic), `cognitive`, `loop_count`, `loop_depth`
- `transitive_loop_depth` — worst-case nested-loop degree propagated along CALLS edges
- `linear_scan_in_loop` — find/contains/indexOf inside a loop; the hidden O(n²) that
  `loop_depth` alone misses
- `alloc_in_loop`, `recursion_in_loop`, `unguarded_recursion`, `recursive`
- `param_count`, `max_access_depth` — structure smells

```cypher
MATCH (f:Function)
WHERE f.transitive_loop_depth >= 3 OR f.linear_scan_in_loop >= 1
RETURN f.qualified_name, f.transitive_loop_depth, f.linear_scan_in_loop
ORDER BY f.transitive_loop_depth DESC
```

Filter test files out of results before drawing conclusions — benchmarks and fixtures
dominate these rankings and are rarely the real hot path.

## Coverage is best-effort — never claim completeness

`skipped` files were not indexed at all. `parse_partial` files *were* indexed, but constructs
inside the flagged line ranges may be missing. From v0.11.0, `parse_unusable` files were indexed
but one error range covers most of the file, so treat them as barely indexed. Absence from
these lists is **not** a completeness guarantee.

Before any negative or exhaustive claim ("nothing calls this", "there are no other
implementations"), call `check_index_coverage` on the paths or scopes involved, and grep
inside flagged ranges. Query the miss graph structurally with:
```cypher
// query_graph(graph="missed")
MATCH (f:File) WHERE f.kind = "parse_partial" OR f.kind = "parse_unusable"
RETURN f.file_path, f.kind, f.detail
```

`not_indexed` is a separate, by-design class (gitignore/.cbmignore rules) — deliberate, not a
failure.

**Before calling anything dead code**, widen the caller check. `trace_path` follows only CALLS
edges by default and leaves test files out. A function passed as a callback or handler is
reached through CALL_REFERENCE or USAGE edges instead, so also trace inbound with
`edge_types=["CALLS", "CALL_REFERENCE", "USAGE"]`, and with `include_tests=true` if a
test-only caller matters to the claim.

Even that misses two common kinds of live function, because the graph links them through edges
that point away from them, not toward them:
- **Route handlers** (for example a decorator-registered `@app.get`) have an outbound `HANDLES`
  edge to a Route node and no inbound edge at all. Check with `trace_path` outbound and
  `edge_types=["HANDLES"]`.
- **Interface or override implementations** have an outbound `OVERRIDE` edge to the base
  method, and callers go through the base method. Check outbound with `edge_types=["OVERRIDE"]`,
  then trace the base method's callers.

Entry points are flagged by an `is_entry_point` property on the node, not by an edge, so read
it before calling a function dead. Treat a function as dead only when none of these links
exist and its source shows no dynamic use such as reflection or string dispatch.

## Engine quirks worth knowing

- **Zero rows ≠ error.** A `count()` query that matches nothing returns *no rows* rather than a
  row containing `0`. Confirm the label is populated before reporting "none" — otherwise
  "no matches" and "no such label" look identical.
- **`file_path` is project-relative**, not absolute. A `CONTAINS` filter on a path fragment
  won't catch directories that live outside the repo root.
- **`query_graph` has a hard 100k-row ceiling** through v0.11.0: a result that reaches it fails
  with an error, so add `LIMIT` to broad Cypher. From v0.11.0 it also pages what it returns
  (200 rows by default, `next_cursor` to continue, `max_rows` to raise the page size), but
  paging does not lift the ceiling.
- **`search_graph` in/out degrees are not caller/callee counts** — they are selected-edge
  degree across CALLS, USAGE, CALL_REFERENCE, INHERITS, IMPLEMENTS. Use `trace_path` for
  actual callers.
- **Paginate deliberately.** `search_graph` returns `total` and `has_more`; `trace_path`
  returns `truncated` + `next`. Narrow before paging through large sets: with `name_pattern`,
  use `label` / `file_pattern` / `min_degree`; with `query`, only `file_pattern` applies.

## Cross-repo intelligence

`index_repository(mode="cross-repo-intelligence")` matches Routes and Channels across projects
and creates six edge types: `CROSS_HTTP_CALLS`, `CROSS_ASYNC_CALLS`, `CROSS_CHANNEL`,
`CROSS_GRPC_CALLS`, `CROSS_GRAPHQL_CALLS` and `CROSS_TRPC_CALLS`. Query all six before
reporting zero cross edges.

Call it with `repo_path` **and** `name` for the source project, so the source resolves to
the indexed project, and `target_projects` listing the others. A source listed among its own
targets is skipped. The error "cross-repo source or target project is missing, invalid, or not
indexed" means a named source or target does not resolve to an indexed project.

It only finds **network** calls between services. Repos that share code via packages,
filesystem, or a monorepo layout produce zero cross edges no matter how related they are.
Before running it, check that the candidates actually have Route or Channel nodes, and
sanity-check what those routes are — connection strings scraped from compose files register as
Routes but carry no cross-repo signal. A zero result is a finding about the architecture, not a
failure.

## Runtime data

`ingest_traces` currently counts the traces it receives and creates no graph edges (true
through v0.11.0), so it adds nothing to caller analysis yet.
