# Claude Code Guide - Your Project

**Framework**: aiShore v0.1 - Development Process Orchestrator
**Purpose**: AI-driven sprint management and quality automation
**Architecture**: Agent-based orchestration with adaptive complexity

---

## 📊 About This File

This `CLAUDE.md` file is the **project convention guide** for your codebase.

### Clear Boundaries

**aiShore's Responsibility** (the framework):
- Manages backlog and sprint workflow
- Orchestrates AI agents through quality gates
- Tracks metrics and progress
- Enforces Definition of Ready/Done

**This File's Responsibility** (your project):
- Architecture patterns and coding conventions
- Tech stack and development workflows
- Testing strategies and quality standards
- Project-specific rules and context

**Customize this file for your project!** aiShore agents read this to understand YOUR codebase conventions, not to receive instructions about backlog management (that's in `plan/definitions.md`).

---

## 🗄️ Your Project Architecture

### Tech Stack

Replace this with your actual stack:

- **Framework**: (e.g., Next.js, Django, Rails, Express)
- **Language**: (e.g., TypeScript, Python, Ruby)
- **Database**: (e.g., PostgreSQL, MongoDB, MySQL)
- **Testing**: (e.g., Jest, Pytest, RSpec)
- **Styling**: (e.g., Tailwind CSS, styled-components, SCSS)

### Project Structure

```
your-project/
├── plan/                    # aiShore backlog and sprint management
│   ├── backlog-mvp.json
│   ├── backlog-growth.json
│   ├── sprint-current.json
│   └── progress.txt
├── scripts/                 # aiShore orchestration scripts
│   ├── aishore.sh
│   ├── agents/
│   └── metrics.sh
└── src/                     # Your source code
    └── (your structure here)
```

---

## 💻 Development Commands

### Setup Commands

```bash
# Add your project setup commands here
npm install                 # or: pip install -r requirements.txt
cp .env.example .env        # Configure environment
```

### Development Commands

```bash
# Add your development commands
npm run dev                 # Start dev server
npm run test                # Run tests
```

### Quality Commands

**REQUIRED**: Configure these in `.aishore.config` file (copy from `.aishore.config.example`):

```bash
# Example for TypeScript project
VALIDATION_TYPE_CHECK="npm run type-check"
VALIDATION_LINT="npm run lint"
VALIDATION_TEST="npm test"

# Example for Python project
VALIDATION_TYPE_CHECK="mypy src/"
VALIDATION_LINT="ruff check ."
VALIDATION_TEST="pytest"
```

See `.aishore.config.example` for more language examples (Ruby, Go, Rust, Java, PHP, etc.).

---

## 🚀 aiShore Commands

aiShore orchestrates your development workflow with AI agents.

**Direct script invocation** (works for any language):
```bash
./scripts/aishore.sh              # Run 1 adaptive sprint
./scripts/aishore.sh --quick      # Fast mode: validation only
./scripts/aishore.sh --review     # Force code review (even for XS/S)
./scripts/aishore.sh --full       # Full ceremony: design + review
./scripts/aishore.sh --groom      # Standalone backlog grooming
./scripts/aishore.sh --batch      # Run 5 sprints, auto-commit each
./scripts/aishore.sh --batch 10   # Run 10 sprints, auto-commit each
./scripts/metrics.sh              # View sprint metrics
```

**Via npm** (if your project has package.json):
```bash
npm run aishore              # Same as ./scripts/aishore.sh
npm run aishore:quick        # Same as ./scripts/aishore.sh --quick
npm run aishore:review       # Same as ./scripts/aishore.sh --review
npm run aishore:full         # Same as ./scripts/aishore.sh --full
npm run aishore:groom        # Same as ./scripts/aishore.sh --groom
npm run aishore:batch        # Same as ./scripts/aishore.sh --batch
npm run aishore:batch:10     # Same as ./scripts/aishore.sh --batch 10
npm run metrics              # Same as ./scripts/metrics.sh
```

### aiShore v0.1 - AI Engineering Team

Agent-based sprint orchestrator: 3 agents, 4 gates, adaptive complexity.

**Team (3 agents):**

| Agent     | Responsibility                                        |
| --------- | ----------------------------------------------------- |
| Tech Lead | Pre-flight, item selection, code review, sprint close |
| Developer | Feature implementation                                |
| Validator | Validation, acceptance criteria, backlog updates      |

**Flow (4 gates):**

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

**Adaptive Complexity (by item size):**

| Size | Flow                                                                 |
| ---- | -------------------------------------------------------------------- |
| XS/S | Start → Implement → Validate → Close (fast path)                    |
| M    | Start → Implement → Code Review → Validate → Close                  |
| L/XL | Start → Design → Review → Implement → Code Review → Validate → Close |

---

## 📋 Backlog System

The `plan/` directory contains your prioritized backlog:

| File                  | Purpose                              |
| --------------------- | ------------------------------------ |
| `backlog-mvp.json`    | Must-have items for MVP              |
| `backlog-growth.json` | Post-launch features                 |
| `backlog-polish.json` | Nice-to-have improvements            |
| `backlog-future.json` | Long-term roadmap                    |
| `sprint-current.json` | Active sprint state with metrics     |
| `progress.txt`        | Sprint history log                   |
| `definitions.md`      | DoR, DoD, sizing guide, team standards |

**Backlog Item Structure:**

```json
{
  "id": "FEAT-001",
  "category": "feature",
  "description": "User authentication system",
  "priority": "must",
  "steps": [
    "Implement login endpoint",
    "Add session management",
    "Create login UI"
  ],
  "acceptanceCriteria": [
    "User can log in with email and password",
    "Session persists across page refreshes",
    "Invalid credentials show error message"
  ],
  "dependencies": [],
  "status": "todo",
  "passes": false,
  "readyForSprint": true
}
```

---

## 🔑 Your Project Patterns

### Coding Conventions

Add your project's coding conventions here:

- File naming conventions
- Function/class naming patterns
- Import ordering rules
- Comment style guidelines

### Architecture Patterns

Add your architecture patterns:

- How to structure new features
- Service layer patterns
- API endpoint conventions
- Database access patterns

### Testing Conventions

Add your testing requirements:

- Test file locations and naming
- What needs to be tested
- Mock/stub conventions
- Test data patterns

---

## 🚫 Important Rules

### Clean Code Policy

Customize these rules for your project:

1. **Code Style**: Follow project linter rules
2. **Testing**: All new features need tests
3. **Documentation**: Update docs for API changes
4. **Security**: Validate all user input

---

## 📂 Key File Locations

Update these to match your project structure:

- Configuration: `(location of config files)`
- Tests: `(location of test files)`
- API/Routes: `(location of API endpoints)`
- Components/Views: `(location of UI components)`

---

## 📝 Additional Notes

Add any additional project-specific information:

- Environment variable requirements
- External service dependencies
- Deployment considerations
- Team conventions

---

## 📞 Getting Started with aiShore

1. **Customize this file** with your project details
2. **Set up your backlog** in `plan/backlog-*.json` files
3. **Configure quality commands** in `.aishore.config`
4. **Run your first sprint**: `./scripts/aishore.sh` (or `npm run aishore` if using Node.js)

The AI agents will reference this file to understand your project conventions and build features that match your architecture.

---

## Need Help?

- Check `plan/definitions.md` for DoR/DoD and team standards
- Review `scripts/agents/*.md` to understand agent behavior
- Read the aiShore README for framework documentation
