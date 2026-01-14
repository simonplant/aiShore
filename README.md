# aiShore

**Language-agnostic AI development process orchestrator** for Claude Code.

## What is aiShore?

aiShore is a **backlog management framework**, not a code generator. It orchestrates AI agents through quality gates to systematically work through your project backlog, regardless of your tech stack.

### Clear Boundaries

**What aiShore Does** (backlog orchestration):
- ✅ Manages prioritized backlogs (MVP, Growth, Polish, Future)
- ✅ Orchestrates 3 AI agents through quality gates (START → IMPLEMENT → REVIEW → VALIDATE → CLOSE)
- ✅ Enforces Definition of Ready and Definition of Done
- ✅ Tracks metrics (cycle time, velocity, pass rates)
- ✅ Adapts workflow complexity based on item size (XS/S/M/L/XL)

**What aiShore Doesn't Do** (your project's responsibility):
- ❌ Dictate your tech stack or architecture
- ❌ Provide project-specific code patterns
- ❌ Define your testing strategy
- ❌ Make implementation decisions

**The Framework-Project Boundary**: aiShore focuses purely on HOW to manage development work, not WHAT you're building or HOW to implement it.

## Language Support

aiShore works with **any language or framework**. Configure your validation commands in `.aishore.config`:

| Language/Stack | Type Check | Linter | Tests |
|---------------|------------|---------|--------|
| **TypeScript** | `tsc --noEmit` | `eslint` | `jest` |
| **Python** | `mypy src/` | `ruff check` | `pytest` |
| **Ruby** | `ruby -c **/*.rb` | `rubocop` | `rspec` |
| **Go** | `go vet ./...` | `golangci-lint run` | `go test ./...` |
| **Rust** | `cargo check` | `cargo clippy` | `cargo test` |
| **Java** | `mvn compile` | `mvn checkstyle:check` | `mvn test` |
| **PHP** | `php -l **/*.php` | `phpcs` | `phpunit` |

See `.aishore.config.example` for complete configuration examples.

## Quick Start

### 1. Configuration

```bash
# Copy configuration example
cp .aishore.config.example .aishore.config

# Edit .aishore.config with your project's commands
VALIDATION_TYPE_CHECK="mypy src/"  # Python example
VALIDATION_LINT="ruff check ."
VALIDATION_TEST="pytest"
```

### 2. Customize Project Guide

Edit `CLAUDE.md` with your project's architecture, patterns, and conventions. This is where you define YOUR project's implementation details.

### 3. Set Up Backlog

Customize backlog files in `plan/` with your features:
- `backlog-mvp.json` - Must-have items
- `backlog-growth.json` - Post-launch features
- `backlog-polish.json` - Nice-to-have improvements
- `backlog-future.json` - Long-term roadmap

### 4. Run Your First Sprint

```bash
# Option A: Direct script invocation (works for any language)
./scripts/aishore.sh              # Run 1 sprint (adaptive complexity)
./scripts/aishore.sh --batch      # Run 5 sprints automatically
./scripts/metrics.sh              # View cycle time and velocity

# Option B: Via npm (if your project has package.json)
npm run aishore                   # Run 1 sprint
npm run aishore:batch             # Run 5 sprints
npm run metrics                   # View metrics
```

## Architecture

### Three Agents, Four Gates

```
START (Tech Lead)
  ↓
IMPLEMENT (Developer)
  ↓
CODE REVIEW (Tech Lead) ← skipped for XS/S items
  ↓
VALIDATE (Validator)
  ↓
CLOSE (Tech Lead)
```

### Adaptive Complexity

| Size | Flow | Use Case |
|------|------|----------|
| XS/S | Start → Implement → Validate → Close | Bug fixes, small tweaks |
| M | Start → Implement → Review → Validate → Close | Standard features |
| L/XL | Start → Design → Review → Implement → Review → Validate → Close | Complex features |

## Documentation

### Framework Documentation (aiShore itself)
- `plan/definitions.md` - DoR/DoD, sizing guide, quality gates
- `plan/backlog-schema.json` - JSON schema for backlog items
- `.aishore.config.example` - Configuration examples for all languages

### Project Documentation (your codebase)
- `CLAUDE.md` - Your project's architecture and patterns
- `plan/backlog-*.json` - Your feature backlog
- `plan/progress.txt` - Sprint history and retrospectives

## Commands

**Direct Script Invocation** (language-agnostic):
```bash
# Sprint execution
./scripts/aishore.sh                # Adaptive sprint (1 item)
./scripts/aishore.sh --quick        # Fast mode (validation only)
./scripts/aishore.sh --review       # Force code review
./scripts/aishore.sh --full         # Full ceremony (design + review)
./scripts/aishore.sh --batch        # Run 5 sprints automatically
./scripts/aishore.sh --batch 10     # Run 10 sprints

# Backlog management
./scripts/aishore.sh --groom        # Groom backlog items

# Analytics
./scripts/metrics.sh                # Cycle time, velocity, backlog health
```

**Via npm** (optional, if your project uses Node.js):
```bash
npm run aishore              # Adaptive sprint
npm run aishore:quick        # Fast mode
npm run aishore:review       # Force code review
npm run aishore:full         # Full ceremony
npm run aishore:batch        # Run 5 sprints
npm run aishore:batch:10     # Run 10 sprints
npm run aishore:groom        # Groom backlog
npm run metrics              # View metrics
```

## Requirements

- **Claude CLI**: `claude` command must be available
- **jq**: JSON processor for backlog manipulation
- **git**: Version control (for commit tracking)

No language-specific dependencies! Configure your project's tools in `.aishore.config`.

## Example Workflows

### TypeScript/Node.js Project
```bash
# .aishore.config
VALIDATION_TYPE_CHECK="npm run type-check"
VALIDATION_LINT="npm run lint"
VALIDATION_TEST="npm test"

# Run sprints (option 1: via npm)
npm run aishore
npm run aishore:batch

# Run sprints (option 2: direct)
./scripts/aishore.sh
./scripts/aishore.sh --batch
```

### Python Project
```bash
# .aishore.config
VALIDATION_TYPE_CHECK="mypy src/"
VALIDATION_LINT="ruff check ."
VALIDATION_TEST="pytest"

# Run sprints (direct invocation)
./scripts/aishore.sh
./scripts/aishore.sh --batch

# Or add convenience wrappers to your Makefile/justfile
make aishore        # calls ./scripts/aishore.sh
poetry run aishore  # calls ./scripts/aishore.sh
```

### Ruby Project
```bash
# .aishore.config
VALIDATION_TYPE_CHECK="ruby -c **/*.rb"
VALIDATION_LINT="rubocop"
VALIDATION_TEST="rspec"

# Run sprints (direct invocation)
./scripts/aishore.sh
./scripts/aishore.sh --batch

# Or add to Rakefile
rake aishore        # calls ./scripts/aishore.sh
bundle exec aishore # calls ./scripts/aishore.sh
```

### Go Project
```bash
# .aishore.config
VALIDATION_TYPE_CHECK="go vet ./..."
VALIDATION_LINT="golangci-lint run"
VALIDATION_TEST="go test ./..."

# Run sprints (direct invocation)
./scripts/aishore.sh
./scripts/aishore.sh --batch

# Or add to Makefile
make aishore        # calls ./scripts/aishore.sh
```

### Java/Maven Project
```bash
# .aishore.config
VALIDATION_TYPE_CHECK="mvn compile"
VALIDATION_LINT="mvn checkstyle:check"
VALIDATION_TEST="mvn test"

# Run sprints (direct invocation)
./scripts/aishore.sh
./scripts/aishore.sh --batch

# Or add to pom.xml exec plugin
mvn exec:exec -Dexec.executable="./scripts/aishore.sh"
```

### Rust Project
```bash
# .aishore.config
VALIDATION_TYPE_CHECK="cargo check"
VALIDATION_LINT="cargo clippy"
VALIDATION_TEST="cargo test"

# Run sprints (direct invocation)
./scripts/aishore.sh
./scripts/aishore.sh --batch

# Or add to Makefile
make aishore        # calls ./scripts/aishore.sh
```

## Philosophy

aiShore is built on a simple principle: **AI agents should manage the development PROCESS, not dictate the technical IMPLEMENTATION**.

- The framework enforces quality gates and workflow
- Your `CLAUDE.md` defines implementation patterns
- Your `.aishore.config` specifies validation tools
- The backlog drives what gets built

This separation allows aiShore to work with any tech stack while maintaining consistent quality standards.

## License

MIT
