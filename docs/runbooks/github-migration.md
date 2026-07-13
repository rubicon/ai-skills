# Runbook: Migrate ai-skills to GitHub as primary host (#49)

**Decision (2026-07-12, Dax):** Establish GitHub's public history with a **fresh
initial public commit** — the current allowlisted public tree only. Forgejo is
retained as the private archive with full granular history. No history rewrite,
no broken commit signatures, zero exposure risk. The pre-migration public commit
history is intentionally not carried to GitHub (it is interleaved with private
commits and lives on the Forgejo archive).

**Approach rejected:** filter-repo history rewrite (breaks every commit
signature, error-prone, must be verified commit-by-commit). Deferral was also
considered and declined — Dax wants native GitHub PRs.

## Ordering (hard dependency)

1. **PR #51 (identity-theft) must merge to Forgejo `main` first.** The fresh
   public commit is built from the post-merge tree, so it must contain the
   identity-theft skill. Do not execute this runbook before #51 lands.
2. Then execute the migration below.
3. Then #50 (contribution infrastructure) on the new GitHub setup.

## What is public vs private

The public allowlist is already defined by `scripts/sync-github-mirror.sh`:
tracked `README.md`, `CHANGELOG.md`, `LICENSE*`, `skills/`, `plugins/`, and
`.claude-plugin/marketplace.json`. Everything else is private-only and must not
reach GitHub: `docs/`, `scripts/`, `CLAUDE.md`, `AGENTS.md`, `.forgejo/`, and
any local config. History scan (2026-07-12) confirmed **no credentials** in
Forgejo history — the private content is operational docs, specs, repo-process
overlay, and personal tooling notes. This is a privacy-hygiene migration, not a
secret-leak remediation.

## Migration steps

### Phase A — Build the clean public tree

1. From an up-to-date Forgejo `main` (post-#51), produce the allowlisted export
   exactly as the mirror script does (reuse its `git ls-files` allowlist so the
   public set stays identical to what already ships):
   - `README.md`, `CHANGELOG.md`, `LICENSE*`, `skills/`, `plugins/`,
     `.claude-plugin/marketplace.json`.
2. **Public-facing docs GitHub now needs that the private tree kept in `docs/`:**
   the fresh public repo should carry a public `ARCHITECTURE.md` (policy
   requires it) and — after #50 — `CONTRIBUTING.md`, `SECURITY.md`,
   `CODE_OF_CONDUCT.md`, `SUPPORT.md`. Decide per the policy's public/collaborative
   overlay. The private `docs/` tree itself does NOT migrate.
3. Verify the export contains zero private paths:
   `grep -rIl` sweep for private markers; confirm no `docs/`, `scripts/`,
   `CLAUDE.md`, `AGENTS.md` present.

### Phase B — Establish GitHub history

4. Initialize a fresh git history from the clean tree (new repo or orphan
   branch), single **signed** initial commit:
   `chore: initial public release of ai-skills` (or a dated release commit).
5. Force-push to `github.com/rubicon/ai-skills` `main`, replacing the current
   snapshot. This is the last force-push to that repo — after this, `main` is
   protected and append-only.

### Phase C — Harden GitHub `main` (Repository Provisioning Baseline)

6. Apply the provisioning baseline from the general repository process policy via
   `gh api` (do not hand-walk the UI): metadata (description, topics), merge
   hygiene (squash-only, auto-delete head branches, linear history), branch
   protection on `main` (require PR, passing checks, signed commits, linear
   history, block force/direct push/deletion), and security features
   (Dependabot alerts + security updates, secret scanning + push protection;
   CodeQL default setup — free on this public repo).
7. Install the shared `rubicon-release-please` GitHub App (the one manual OAuth
   step) and set the `OP_SERVICE_ACCOUNT_TOKEN` repo secret from 1Password, per
   the policy's canonical shared-automation section.

### Phase D — Move CI to GitHub Actions

8. Port `.forgejo/workflows/ci.yaml` (validate-skills + PR/branch/commit policy)
   to `.github/workflows/` as a GitHub Actions workflow. Add `dependabot.yml`.
   Pin the required status-check job names into branch protection.
   **Note:** the identity-theft skill ships `scripts/validate_output.py` and
   `scripts/validate_dossier.py` with a 34-test suite — wire these into CI so
   the gate stays enforced on contributed dossiers (feeds #50).

### Phase E — Re-point canonical host

9. Update the repo overlay (`docs/process/ai-skills-repo-overlay.md`) and
   `CLAUDE.md`: GitHub is now canonical; `origin` → GitHub; Forgejo becomes the
   private archive/backup remote. Per policy, the overlay is the approved place
   to declare the canonical-host change.
10. Retire `scripts/sync-github-mirror.sh` (or repurpose as a Forgejo-archive
    push). Update the Git Hosting section of `CLAUDE.md` and the repo README's
    source-of-truth language.
11. Disposition of `docs/` going forward (Dax decision, deferred to execution):
    keep private-only on the Forgejo archive, or relocate to `ai-skills-private`.
    Default: stays on the Forgejo archive; not published.

## Acceptance criteria

- GitHub `main` contains only allowlisted public content + required public docs;
  a fresh reviewer sees no private paths anywhere in the (new, single-commit)
  history.
- Branch protection, signed commits, and CI (GitHub Actions) green on `main`.
- Overlay + `CLAUDE.md` declare GitHub canonical; `origin` re-pointed; Forgejo
  archive remote configured.
- release-please App installed; first release PR proposes correctly.
- #50 can proceed: contributors fork → branch → PR natively on GitHub.

## Rollback

Forgejo retains the full private history untouched throughout; if the GitHub
cutover is aborted, revert `origin` and continue on Forgejo. The GitHub force-push
in Phase B only touches the already-disposable snapshot.
