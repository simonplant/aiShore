# Contributing Guide

## Solo Developer Workflow

This project is optimized for solo development with automated quality checks and CI/CD.

## Development Setup

### 1. Initial Setup

```bash
# Clone and install
git clone <your-repo-url>
cd possessions-app
npm install

# Setup environment
cp .env.example .env.local
# Add your ANTHROPIC_API_KEY to .env.local

# Start services
npm run docker:up

# Initialize database
npm run db:push
```

### 2. Development Workflow

```bash
# Start development
npm run dev              # Start Next.js dev server (http://localhost:3000)
npm run workers          # Start background workers (separate terminal)
npm run db:studio        # Open database viewer (http://localhost:4983)
```

## Git Workflow

### Branch Strategy

- `main` - Production-ready code, protected
- Feature branches - `feature/description` or `feat/description`
- Bug fixes - `fix/description`
- Chores - `chore/description`

### Making Changes

1. **Create a branch**

   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make your changes**
   - Write code following CLEAN_CODE_POLICY.md
   - Add tests for new functionality
   - Update documentation if needed

3. **Commit changes**

   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

   **Automatic checks on commit:**
   - ✅ ESLint fixes and checks staged files
   - ✅ Prettier formats staged files
   - ✅ TypeScript type checking

4. **Push changes**

   ```bash
   git push origin feature/my-feature
   ```

   **Automatic checks on push:**
   - ✅ Unit tests run
   - ✅ Integration tests run
   - ⚠️ Push is blocked if tests fail!

5. **Create Pull Request**
   - GitHub will automatically use the PR template
   - CI will run full test suite
   - Review your own code before merging

## Testing

### Running Tests

```bash
# Run all tests
npm test

# Watch mode for development
npm run test:watch

# CI mode with coverage (used by GitHub Actions)
npm run test:ci
```

Tests run in ~2 seconds without database dependencies.

### Writing Tests

Tests are co-located with their source files in `__tests__/` directories:

- `src/app/(app)/__tests__/` - Page component tests
- `src/app/api/**/__tests__/` - API route tests
- `src/components/__tests__/` - Component tests
- `src/services/**/__tests__/` - Service tests
- `src/lib/__tests__/` - Library/utility tests

**Test file naming:**

- Component: `src/components/__tests__/ComponentName.test.tsx`
- Service: `src/services/service-name/__tests__/index.test.ts`
- API: `src/app/api/resource/__tests__/route.test.ts`

**Example test structure:**

```typescript
import { InventoryService } from '@/services/inventory';
import { getTestDb, cleanDatabase, closeTestDb, createTestUser } from '@/lib/test-utils/database';

describe('MyService', () => {
  let service: MyService;

  beforeAll(async () => {
    const db = getTestDb();
    service = new MyService(db);
  });

  beforeEach(async () => {
    await cleanDatabase();
  });

  afterAll(async () => {
    await closeTestDb();
  });

  it('should do something', async () => {
    // Test implementation
  });
});
```

## Code Quality

### Automated Checks

All commits and pushes trigger automated checks:

**Pre-commit (fast):**

- Lint staged files
- Format staged files
- Type check entire project

**Pre-push (comprehensive):**

- Run full test suite
- Blocks push if tests fail

**CI (on PR/push to main):**

- Type checking
- Linting
- Format checking
- Full test suite
- Build verification
- Coverage reporting

### Manual Checks

```bash
# Run all quality checks manually
npm run validate           # Type check + lint + format check

# Individual checks
npm run type-check         # TypeScript
npm run lint               # ESLint
npm run lint:fix           # ESLint with auto-fix
npm run format             # Format all files
npm run format:check       # Check formatting only
```

## Database

### Schema Changes

When modifying database schema:

1. Edit schema files in `src/db/schema/`
2. Push changes to development database:
   ```bash
   npm run db:push
   ```
3. Run tests to ensure no breakage:
   ```bash
   npm test
   ```

### Viewing Data

```bash
npm run db:studio          # Opens Drizzle Studio on http://localhost:4983
```

## Commit Message Convention

Use conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

**Examples:**

```bash
git commit -m "feat: add container sealing functionality"
git commit -m "fix: resolve item state transition bug"
git commit -m "test: add integration tests for moving workflow"
git commit -m "docs: update API documentation"
```

## Troubleshooting

### Git Hooks Not Running

```bash
# Reinstall hooks
npm run prepare
```

### Tests Failing

```bash
# Check if Docker services are running (for local dev)
npm run docker:up
docker ps

# Run tests with verbose output
npm test -- --verbose
```

### Type Errors After Schema Changes

```bash
# Regenerate types
npm run db:push

# Clean build
rm -rf .next
npm run build
```

## CI/CD

### GitHub Actions

The project uses a single GitHub Actions workflow:

**On PR and Push to Main:**

- Validates code (type-check, lint, format)
- Runs test suite
- Builds the project

Stale runs are automatically cancelled when new commits are pushed.

### Required Secrets

No secrets required for CI - tests use mock API keys.

## aiShore Sprint Orchestrator

The project includes an automated backlog implementation system using AI agents.

### Running Sprints

```bash
# Run an adaptive sprint (flow based on item size)
npm run aishore

# Fast mode - validation only, no code review
npm run aishore:quick

# Force code review even for small items
npm run aishore:review

# Full ceremony - design proposal + code review
npm run aishore:full

# Standalone backlog grooming (no sprint)
npm run aishore:groom
```

### How It Works

aiShore v0.1 uses 3 agents with adaptive complexity:

| Agent         | Responsibility                                        |
| ------------- | ----------------------------------------------------- |
| **Tech Lead** | Pre-flight, item selection, code review, sprint close |
| **Developer** | Feature implementation                                |
| **Validator** | Validation, acceptance criteria, backlog updates      |

**Flow adapts based on item size:**

- **XS/S**: Start → Implement → Validate → Close (skip code review)
- **M**: Start → Implement → Code Review → Validate → Close
- **L/XL**: Start → Design → Review → Implement → Code Review → Validate → Close

### Backlog Structure

- `plan/backlog-mvp.json` - Must-have items for MVP
- `plan/backlog-growth.json` - Post-launch features
- `plan/backlog-polish.json` - Nice-to-have improvements
- `plan/backlog-future.json` - Long-term roadmap
- `plan/backlog-meta.json` - Summary statistics

### Sprint Recovery

If a sprint is interrupted, the orchestrator will detect it on next run and offer to resume.

### Logs

Agent run durations are logged to `plan/.logs/agent-runs.log`.

## Best Practices

1. **Write tests first** - TDD when possible
2. **Keep commits small** - One logical change per commit
3. **Run tests locally** - Don't rely only on CI
4. **Follow CLEAN_CODE_POLICY.md** - No backwards compatibility unless needed
5. **Update tests** - When changing functionality, update related tests
6. **Document complex logic** - Add comments for non-obvious code
7. **Review your own PRs** - Read through changes before merging

## UI Guidelines

### Component Library

Use shadcn/ui components from `src/components/ui/`:

- **Button** - For all clickable actions
- **Card** - For content sections (CardHeader, CardContent, CardTitle)
- **Badge** - For status indicators
- **Input/Label** - For form fields

### Styling Conventions

- Use theme variables: `bg-background`, `text-muted-foreground`, `border`
- Page sections: `space-y-6` for consistent spacing
- Headings: Add `tracking-tight` class
- Hover states: `hover:bg-accent/50`
- Icons: Lucide React with consistent sizing (`h-4 w-4`, `h-5 w-5`)

## API Guidelines

### Response Format

All API endpoints must use the standardized response envelope:

```typescript
// Success - return data in 'data' field
return NextResponse.json({ data: resource });           // Single resource
return NextResponse.json({ data: resources });          // Collection
return NextResponse.json({ data: results, meta: {} });  // With metadata

// Action confirmations
return NextResponse.json({ success: true });
return NextResponse.json({ success: true, message: 'Done' });

// Errors
return NextResponse.json({ error: 'Message' }, { status: 400 });
return NextResponse.json({ error: 'Message', code: 'CODE' }, { status: 400 });
```

**Do NOT** return data with custom keys like `{ items }`, `{ policy }`, etc. Always use `{ data }`.

### Error Handling

Use the `ApiError` class for consistent error responses:

```typescript
import { ApiError } from '@/lib/api/middleware';

return ApiError.badRequest('Invalid input');
return ApiError.notFound('Item');
return ApiError.internal('Something went wrong');
```

### Error Logging

**All errors must use centralized logging** — never use bare `console.error()`.

```typescript
import { logError, logWarning } from '@/lib/error-logger';

// In catch blocks - always log with context
try {
  await riskyOperation();
} catch (error) {
  logError(error, {
    route: '/api/items',
    userId,
    userAction: 'createItem',
  });
  return ApiError.internal('Operation failed');
}

// For non-critical issues
logWarning('Fallback to default', { route: '/api/search' });
```

**Required context fields:**
- `route` - The API route or page path
- `userAction` - What the user was trying to do
- `userId` - When available from session

See [CLAUDE.md](./CLAUDE.md#-error-handling) for complete error logging documentation.

## Clean Code Policy

This is a **new prototype application** - not a legacy system migration.

### Core Principles

1. **NO backwards compatibility** unless explicitly requested
2. **Clean, minimal code only** - no "just in case" code
3. **Single source of truth** - one schema, one way to do things
4. **Delete unused code immediately** - no deprecated methods kept "for compatibility"

### What NOT to Do

- Don't add backwards compatibility layers or migration scripts
- Don't keep commented-out code or unused implementations
- Don't assume legacy requirements - this is a NEW app

### What TO Do

- Implement clean, modern solutions with latest best practices
- Ask before adding complexity ("Do you need backwards compatibility?")
- Keep it simple: one schema, one implementation, one source of truth

### Applied to This Project

- No existing users or data to migrate
- Clean schema from day one (properties → locations → containers → items)
- Build clean, simple, production-ready features

---

## Need Help?

- Check CLAUDE.md for project architecture
- Review existing tests for examples
- Create an issue using the templates in `.github/ISSUE_TEMPLATE/`
