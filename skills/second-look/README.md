# Second Look

An intent-first review by an agent that did not write the code: does the change do what you asked, all of it and only that, and does it have bugs. The working session writes a structured packet of your original ask, later changes, final requirements, and what you deferred, so the reviewer judges against what you settled on, not against the diff. See [SKILL.md](SKILL.md) for the packet and report shape.

## Install

```bash
skillshare install github.com/rubicon/ai-skills -s second-look
```

## Credits

Adapted from the `/handoff-review` and `/workspace-review` magic prompts in [OpenChamber](https://github.com/openchamber/openchamber) (MIT, Copyright (c) 2025 Bohdan Triapitsyn). The wording here is this skill's own.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
