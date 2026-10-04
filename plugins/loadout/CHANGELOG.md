# Changelog

All notable changes to this plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions use [Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

### Added

- `audit` skill: per-project plugin and skill recommendation, approval stop, apply to `.claude/settings.local.json`, and verification from fresh sessions.
- `loadout.py` with `capture`, `inventory`, and `verify`. `verify` compares expected and loaded plugins in the project and an empty directory, and classifies each skill override as hidden, still loaded, no effect on a plugin skill or command, covered by a plugin disable, unverifiable while its plugin is off, or not found.
