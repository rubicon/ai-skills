# Changelog

All notable changes to this plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.2.0](https://github.com/rubicon/ai-skills/compare/loadout-v0.1.0...loadout-v0.2.0) (2026-10-09)


### Features

* add loadout plugin for per-project plugin and skill audits ([#93](https://github.com/rubicon/ai-skills/issues/93)) ([7283d53](https://github.com/rubicon/ai-skills/commit/7283d53cd8ae2e768df80dcf945f8581fbd0d9e9)), closes [#78](https://github.com/rubicon/ai-skills/issues/78)

## [0.1.0] - Unreleased

### Added

- `audit` skill: per-project plugin and skill recommendation, approval stop, apply to `.claude/settings.local.json`, and verification from fresh sessions.
- `loadout.py` with `capture`, `inventory`, and `verify`. `verify` compares expected and loaded plugins in the project and an empty directory, and classifies each skill override as hidden, still loaded, no effect on a plugin skill or command, covered by a plugin disable, unverifiable while its plugin is off, or not found.
