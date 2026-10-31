# star-chart

Organize and clean up your GitHub stars with `gh` and `jq`, whenever you like: Claude consolidates your GitHub Lists into a tight set of categories, proposes List assignments and unstar candidates, and asks you about each part in pop-up questions; it runs everything itself, and every change is logged and can be undone. See [SKILL.md](SKILL.md) for the workflow and the guardrails.

## Install

```bash
skillshare install github.com/rubicon/ai-skills -s star-chart
```

Requires `gh` (logged in) and `jq`. Working files live in `~/.star-chart` (override with `STAR_CHART_DIR`), never in the skill folder or a repository.

## Tests

```bash
bash skills/star-chart/scripts/tests/test-star-chart.sh
```

Network-free: every transform, rule and guard runs against invented fixtures.

## Credits

Informed by the [github-star-manager skill](https://github.com/modbender/skill-library-mcp/blob/613e443422aa995c562ac5d8053f8504db66fa2f/data/github-star-manager-skill/SKILL.md) in modbender/skill-library-mcp.

- **Shared with the original:** exporting stars with `gh api user/starred --paginate`; reading Lists through `viewer.lists`; creating Lists with `createUserList`; passing `listIds` to `updateUserListsForItem` with `gh api graphql --input`; unstarring with `DELETE user/starred/OWNER/REPO`; the 300 ms delay between calls; the `user` scope and `gh auth refresh -s user`; the archived, two-years-stale and deprecated cleanup criteria; and confirming before unstarring.
- **New here:** `starred_at` through the star media type; per-List membership; keeping a repo's existing Lists when assigning (`updateUserListsForItem` replaces the whole set); List consolidation (rename, merge, and deleting only Lists that are empty, behind a separate approval); the rules file with keep-always patterns, a protection window and a target List count; the pop-up approvals (approve all, review individually, reject all) and the readable `plan.md`; the dry run and the hash-gated apply; rate-limit backoff; the change log and `undo.sh`; incremental runs; and detecting a `GH_TOKEN` that overrides the refreshed login.

The original is licensed as follows:

```text
MIT License

Copyright (c) 2025 skill-library-mcp contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
