---
title: WidgetSync
version: 2.3.1
---

# WidgetSync

![Build](https://img.shields.io/badge/build-passing-green)

Welcome to WidgetSync! This tool automatically synchronizes your configuration
files across multiple machines. We think you'll really enjoy using it.

See [Install](#install) to get started, or read the [usage guide](docs/usage.md#basics).

<!-- keep this comment for CI tooling -->

## Install

Run the installer:

```bash
curl -fsSL https://widgetsync.io/install.sh | sh
widgetsync init --config ~/.widgetsync.yaml
```

Then verify with `widgetsync --version`.

    # indented code block
    widgetsync sync --dry-run

## Usage

| Command | Purpose |
| --- | --- |
| `sync` | Synchronize now |
| `status` | Show sync state |

- [x] Install the tool
- [ ] Configure [remotes][remotes-def]

> "WidgetSync saved our team hours every week." — Jane Doe, CTO of Example Corp

> Note: this is a decorative callout, not a quotation.

## Troubleshooting

If sync fails, check connectivity.

## Troubleshooting

This duplicate heading tests slug suffixes. See [Troubleshooting](#troubleshooting-1).

[remotes-def]: https://widgetsync.io/docs/remotes
