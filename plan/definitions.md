# aiShore Definitions

Standard definitions for the aiShore agent team workflow.

---

## Definition of Ready (DoR)

A backlog item is **ready for sprint** when it meets ALL of the following criteria:

### Required Criteria

| #   | Criterion                  | How to Check                                                                        |
| --- | -------------------------- | ----------------------------------------------------------------------------------- |
| 1   | **Clear Value**            | The "why" is understood - ties to a user outcome or product principle |
| 2   | **Acceptance Criteria**    | At least 3 specific, testable criteria that define "done"                           |
| 3   | **Implementation Steps**   | Clear steps that a developer can follow                                             |
| 4   | **Dependencies Satisfied** | All items in `dependencies` array have `passes: true`                               |
| 5   | **Appropriately Sized**    | Can be completed in one sprint (not an epic needing breakdown)                      |
| 6   | **Testable**               | Can be verified by automated tests                                                  |

### Item Fields When Ready

```json
{
  "readyForSprint": true,
  "groomedAt": "2026-01-09"
}
```

### INVEST Criteria (Quality Check)

Good user stories are:

- **I**ndependent: Can be developed without depending on other in-progress items
- **N**egotiable: Details can be refined during development
- **V**aluable: Delivers user or business value
- **E**stimable: Team can estimate the effort
- **S**mall: Fits in a single sprint
- **T**estable: Has clear pass/fail criteria

---

## Definition of Done (DoD)

A backlog item is **done** when it meets ALL of the following criteria:

### Required Criteria

| #   | Criterion                   | Verified By                        |
| --- | --------------------------- | ---------------------------------- |
| 1   | **Code Complete**           | All implementation steps completed |
| 2   | **Tests Passing**           | Test suite passes                  |
| 3   | **Static Analysis Passing** | Type check/static analysis passes  |
| 4   | **Lint Passing**            | Code style check passes            |
| 5   | **Code Reviewed**           | Tech Lead approved changes         |
| 6   | **Acceptance Criteria Met** | All AC verified                    |
| 7   | **No Regressions**          | Existing tests still pass          |

**Note**: Validation commands are configured in `.aishore.config` and vary by project (e.g., TypeScript/MyPy for type checking, ESLint/Ruff for linting, Jest/Pytest for testing).

### Item Fields When Done

```json
{
  "passes": true,
  "status": "done"
}
```

---

## Priority Levels

| Priority | Label    | Meaning                                       | Selection Order |
| -------- | -------- | --------------------------------------------- | --------------- |
| P0       | `must`   | Required for current phase, blocks other work | 1st             |
| P1       | `should` | Important for current phase, not blocking     | 2nd             |
| P2       | `could`  | Nice to have, can defer                       | 3rd             |
| P3       | `future` | Future consideration                          | 4th             |

---

## Story States

| State         | Meaning                       | Next States       |
| ------------- | ----------------------------- | ----------------- |
| `icebox`      | Idea, not refined             | → backlog         |
| `backlog`     | Refined, not ready for sprint | → ready, archived |
| `ready`       | Meets DoR, can be pulled      | → in_progress     |
| `in_progress` | Currently being worked        | → done, rejected  |
| `done`        | Meets DoD, completed          | (terminal)        |
| `archived`    | No longer relevant            | (terminal)        |

---

## Acceptance Criteria Guidelines

### Good Acceptance Criteria

- **Specific**: Exact behavior described
- **Measurable**: Can be objectively verified
- **Testable**: Can be checked by automated test
- **User-focused**: Describes outcome, not implementation

### Examples

**Bad:**

- "Search works"
- "User can add items"
- "Performance is good"

**Good:**

- "User can search items by name with results appearing in <1 second"
- "Search supports fuzzy matching (typo 'laptpo' returns 'laptop')"
- "Empty search shows helpful prompt, not error state"
- "User can add item with just a photo (no other fields required)"
- "Added item appears in inventory list within 2 seconds"

### Format

Use testable statements:

```
Given [context]
When [action]
Then [expected outcome]
```

Or simple declarative statements:

```
[Actor] can [action] with [outcome]
```

---

## Sprint Composition Guidelines

**Focused sprints**: Select exactly 1 item per sprint for deep team collaboration.

| Approach          | Items | Purpose                                                  |
| ----------------- | ----- | -------------------------------------------------------- |
| Focused (default) | 1     | Full team works together dynamically based on item needs |

### Anti-Patterns

- **Over-commitment**: More than 1 item in focused mode
- **Unclear items**: Vague acceptance criteria
- **Epics**: Items that are too large (should be broken down)

---

## Adaptive Complexity (aiShore v0.1)

Flow adapts based on item size. Smaller items skip code review for faster iteration.

### Flow by Size

| Size | Flow                                                                 | Skip        |
| ---- | -------------------------------------------------------------------- | ----------- |
| XS/S | Start → Implement → Validate → Close                                 | Code review |
| M    | Start → Implement → Code Review → Validate → Close                   | -           |
| L/XL | Start → Design → Review → Implement → Code Review → Validate → Close | -           |

### Team (3 Agents)

| Agent     | Responsibility                                        |
| --------- | ----------------------------------------------------- |
| Tech Lead | Pre-flight, item selection, code review, sprint close |
| Developer | Feature implementation                                |
| Validator | Validation, acceptance criteria, backlog updates      |

### Sprint JSON Structure

```json
{
  "sprintId": "sprint-011",
  "status": "in_progress",
  "goal": "Outcome-focused goal",
  "item": {
    "id": "ITEM-001",
    "title": "Item title",
    "size": "M",
    "status": "pending",
    "attempts": 0,
    "maxAttempts": 2,
    "selectedAt": "ISO timestamp",
    "startedAt": null,
    "completedAt": null,
    "cycleTimeMinutes": null
  },
  "flow": ["start", "implement", "review", "validate", "close"]
}
```

---

## Size Estimation (T-Shirt Sizing)

Estimate item size during planning:

| Size | Time     | Indicators                                |
| ---- | -------- | ----------------------------------------- |
| XS   | ~15 min  | Trivial fix, 1-2 steps, single file       |
| S    | ~30 min  | Small feature, 2-3 steps, few files       |
| M    | ~60 min  | Medium feature, 3-5 steps, multiple files |
| L    | ~120 min | Complex feature, 5-7 steps, cross-cutting |
| XL   | ~240 min | Should be split into smaller items        |

### Estimation Basis

- Number of implementation steps
- Complexity of acceptance criteria
- Dependencies and integration points
- Similar completed items (check progress.txt)

### Tracking

Sprint items include:

- `size`: Estimated size (XS, S, M, L, XL)
- `cycleTimeMinutes`: Actual time from start to completion

Compare estimated vs actual to improve future estimates.

---

## Ready Buffer Guidelines

Maintain a healthy buffer of ready items:

| Buffer Level | Count     | Action                     |
| ------------ | --------- | -------------------------- |
| Healthy      | 3+ items  | Ready to sprint            |
| Low          | 1-2 items | Warning: run grooming soon |
| Empty        | 0 items   | Blocked: must run grooming |

The aishore.sh script checks buffer during START and warns if low.

---

## Grooming Cadence

| Activity              | Frequency                          | Owner     |
| --------------------- | ---------------------------------- | --------- |
| Quick readiness check | Before each sprint (in START gate) | Tech Lead |
| Quick-groom           | On-demand via `--groom` flag       | Tech Lead |
| Architecture review   | Every 3-5 sprints                  | Architect |

---

## Rejection Criteria

Items are **rejected** if:

1. **Tests fail** - Must pass before review
2. **Type-check fails** - TypeScript errors not allowed
3. **Lint fails** - Code style must be consistent
4. **2+ acceptance criteria not met** - Core functionality missing
5. **Critical criterion missing** - Key behavior not implemented
6. **Security vulnerability** - Unsafe code patterns
7. **Pattern violation** - Contradicts project conventions

### Retry Process

1. Rejection notes added to `rejectionNotes` field
2. Developer addresses feedback
3. Re-submitted for review
4. Maximum 2 attempts before item fails
5. Failed items are rolled back

---

## Quality Gates Summary (aiShore v0.1)

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. START (Tech Lead)                                               │
│  ✓ Pre-flight: validation checks, clean tree                       │
│  ✓ Item selection: highest priority ready item                      │
│  ✓ Size estimation: XS/S/M/L/XL                                     │
│  ✓ Quick-groom if no ready items (with --groom flag)                │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  2. IMPLEMENT (Developer)                                           │
│  ✓ Follow acceptance criteria                                       │
│  ✓ Write tests                                                      │
│  ✓ Stage changes                                                    │
│  (L/XL items: design proposal first, then implementation)           │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  3. CODE REVIEW (Tech Lead) - M/L/XL items only                     │
│  ✓ Pattern compliance                                               │
│  ✓ Security review                                                  │
│  ✓ Integration check                                                │
│  (XS/S items skip this gate)                                        │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  4. VALIDATE (Validator)                                            │
│  ✓ Run type check/static analysis                                   │
│  ✓ Run linter/code style check                                     │
│  ✓ Run test suite                                                   │
│  ✓ All acceptance criteria met                                      │
│  ✓ Update backlog on pass                                           │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  5. CLOSE (Tech Lead)                                               │
│  ✓ Integration check                                                │
│  ✓ Cycle time recorded                                              │
│  ✓ Update progress.txt                                              │
│  ✓ Mini retrospective                                               │
└─────────────────────────────────────────────────────────────────────┘
```
