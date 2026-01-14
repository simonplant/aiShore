# aiShore

A reusable framework for Claude Code orchestration using backlog and sprints.

## Overview

aiShore provides a structured system for managing product development backlogs and running automated sprints using AI agents. It includes:

- **Backlog Management**: JSON-based backlog structure with schema validation
- **Sprint Orchestration**: Automated sprint workflows using AI agents
- **Agent System**: Configurable agents for different roles (Tech Lead, Developer, Validator, etc.)
- **Progress Tracking**: Built-in tracking and reporting

## Quick Start

1. Customize the backlog files in `plan/` for your project
2. Configure agent prompts in `scripts/agents/` (if needed)
3. Customize definitions in `plan/definitions.md` (if needed)
4. Run sprints using the provided scripts

## Documentation

- `plan/definitions.md` - Team definitions, DoR/DoD, workflows
- `plan/backlog-schema.json` - JSON schema for backlog structure
- `plan/backlog-*.json` - Backlog files (customize for your project)
- `docs/` - Template documentation files for your project

## License

MIT
