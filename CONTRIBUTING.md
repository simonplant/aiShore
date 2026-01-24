# Contributing to aishore

Thanks for your interest in contributing to aishore!

## Development Setup

```bash
# Clone the repo
git clone https://github.com/yourusername/aishore.git
cd aishore

# The tool is ready to use - no build step needed
.aishore/aishore help
```

## Requirements

- Bash 4.4+
- jq
- shellcheck (for linting)
- On macOS: `brew install coreutils` (for gtimeout)

## Code Style

### Bash Scripts

- Use `set -euo pipefail` at the start
- Quote all variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals, not `[ ]`
- Use `$(command)` not backticks
- Use `${var:-default}` for optional variables

### Naming

- Functions: `snake_case`
- Local variables: `snake_case`
- Constants/exports: `UPPER_SNAKE_CASE`

## Testing

Before submitting a PR:

```bash
# Run shellcheck
shellcheck .aishore/aishore .aishore/lib/common.sh

# Test basic commands
.aishore/aishore help
.aishore/aishore version
.aishore/aishore metrics

# Validate JSON
jq empty .aishore/plan/*.json
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes
4. Run shellcheck and tests
5. Commit with conventional commits: `feat:`, `fix:`, `docs:`, etc.
6. Push and create a PR

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Tests
- `chore:` - Maintenance

## Architecture

```
.aishore/
├── aishore           # Main CLI entry point
├── config.yaml       # User configuration
├── lib/common.sh     # Shared utilities
├── agents/*.md       # Agent prompts
├── plan/*.json       # Backlog data
└── data/             # Runtime data
```

Key design decisions:

- **Single CLI**: All commands through one entry point
- **Config-driven**: All settings in config.yaml
- **Self-contained**: Everything in `.aishore/` directory
- **Completion contract**: Agents write to result.json

## Questions?

Open an issue for questions or suggestions.
