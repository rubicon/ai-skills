---
name: grand-tour
version: 0.1.0  # x-release-please-version
description: >-
  Use when the user is new to a codebase, coming back to one after months, or
  asks for a tour, an orientation, "how does this repo fit together", "walk me
  through this codebase", "where do I start", or "explain the architecture",
  optionally focused on one area. Read-only.
---

# Grand tour

Onboard the user the way a senior teammate would on their first day: the mental model first, then just enough of the map to find their way, then where to start. Read-only.

## 1. Investigate

- If a code-graph index covers this repo, start there. Examples: a codebase-memory MCP server (`list_projects`, then `get_architecture`), or a `graphify-out/` directory. Use it for structure, entry points, and call paths, then confirm what matters in the source.
- With no index, and in a large repo, fan out with the Explore agent, one area per search. In a small repo, read directly.
- Find the entry points, how the project is built and run, the main modules and how they talk to each other, and where shared code, types, and config live. Read enough real code to be accurate. Never describe a part from its name alone.
- Choose one representative flow, such as a request, a command, an install, or a build, and follow it through the actual code from where it starts to where it ends.

If the user named an area, do all of this for that area and keep the rest to one sentence of context.

## 2. Answer in this shape

Five sections, in this order, with these headings:

**What this is**: two or three sentences: what the project does, for whom, and its overall shape.

**The main parts**: one table, at most eight rows, one row per area of responsibility, with these columns: Part, Responsible for, Lives in. Group related directories into one row. A row is an area, not a file, and not one row per skill, plugin, or package of the same kind.

**How it fits together**: the flow you chose, as a numbered walk of four to eight steps. Each step names the file or module where it happens and what it hands to the next step.

**Conventions and traps**: up to five bullets. Each is a rule or pattern a newcomer would break or trip over, with where it is enforced or written down.

**Where to start**: two or three concrete pointers for a first read or a first change, each with the path to open first.

The tour describes the codebase as it is on disk. It does not report session state (branches, open PRs, CI runs, local tool versions). When you notice defects or drift while investigating, add an "Also noticed" list after the tour: at most three items, one line each. Do not offer to fix them inside the tour.

## Example (abridged)

> **What this is**: a recipe-sharing web app. A React front end talks to a REST API over a Postgres database, and a worker resizes uploaded photos.
>
> **How it fits together**: uploading a photo:
> 1. `web/src/pages/RecipeEdit.tsx` posts the file to `/api/recipes/:id/photo`.
> 2. `api/routes/photos.ts` stores the original in object storage and enqueues `resize-photo`.
> 3. `worker/jobs/resizePhoto.ts` writes three sizes and updates `recipes.photo_urls`.
> 4. `web/src/components/RecipeCard.tsx` reads `photo_urls` and picks a size per screen.
