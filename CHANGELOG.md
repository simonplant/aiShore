# Changelog

All notable changes to aishore will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-24

### Added

- Initial release of aishore as a standalone tool
- Single CLI entry point with subcommands: `run`, `groom`, `review`, `metrics`, `init`, `version`, `help`
- Configuration via `config.yaml`
- Support for custom validation commands (any language/framework)
- Agent prompts for: developer, validator, tech-lead, architect, product-owner
- Completion contract via `result.json`
- Sprint archive in JSONL format
- macOS compatibility (gtimeout support)
- GitHub Actions CI with shellcheck

### Structure

- `.aishore/` self-contained directory
- `context/` for project-specific documentation
- `plan/` for backlogs (backlog.json, bugs.json, icebox.json)
- `data/` for runtime files (logs, status, archive)

### Documentation

- README with quick start guide
- CONTRIBUTING guide
- MIT License
