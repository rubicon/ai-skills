# Security Policy

## Reporting a vulnerability

Please report security issues privately, not in a public issue.

Use GitHub's [private vulnerability reporting](https://github.com/rubicon/ai-skills/security/advisories/new)
("Report a vulnerability" under the Security tab). We aim to acknowledge within
a few business days.

## Scope

This repository contains AI skill prompt templates, Claude Code plugins, and
small validation scripts (shell and Python, standard library only). The most
relevant concerns are:

- Scripts that could be coerced into unsafe behavior.
- Skill instructions that could induce an agent to take unsafe actions.
- Secrets accidentally committed (none should ever be — report if you find one).

Prompt content that is merely offensive or off-brand is a content issue, not a
security vulnerability; open a normal issue for that.
