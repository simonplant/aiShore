#!/bin/bash
# migrate.sh - Upgrade legacy aishore installations to .aishore/ structure
#
# Usage: ./migrate.sh [project-path]
#
# This script:
#   1. Detects old aishore/ structure
#   2. Creates new .aishore/ structure
#   3. Migrates backlog data, agents, and archives
#   4. Creates config.yaml
#   5. Updates .gitignore
#   6. Optionally removes old aishore/ directory

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[migrate]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; }

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

OLD_DIR="$PROJECT_ROOT/aishore"
NEW_DIR="$PROJECT_ROOT/.aishore"

# ============================================================================
# DETECTION
# ============================================================================

detect_old_structure() {
    local found=0

    # Check for old aishore/ directory
    if [[ -d "$OLD_DIR" ]]; then
        if [[ -d "$OLD_DIR/bin" ]] || [[ -f "$OLD_DIR/bin/aishore.sh" ]]; then
            found=1
        fi
        if [[ -d "$OLD_DIR/plan" ]] && [[ -f "$OLD_DIR/plan/backlog.json" ]]; then
            found=1
        fi
    fi

    return $((1 - found))
}

detect_validation_command() {
    # Try to extract from old common.sh
    if [[ -f "$OLD_DIR/lib/common.sh" ]]; then
        local cmd
        cmd=$(grep -E 'AISHORE_VALIDATE_CMD.*=' "$OLD_DIR/lib/common.sh" 2>/dev/null | \
              sed 's/.*AISHORE_VALIDATE_CMD.*:-//' | sed 's/}".*//' | tr -d '"' || true)
        if [[ -n "$cmd" ]]; then
            echo "$cmd"
            return 0
        fi
    fi

    # Check package.json for common patterns
    if [[ -f "$PROJECT_ROOT/package.json" ]]; then
        if grep -q '"type-check"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            echo "npm run type-check && npm run lint && npm test"
            return 0
        fi
        if grep -q '"test"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            echo "npm test"
            return 0
        fi
    fi

    # Check for Python
    if [[ -f "$PROJECT_ROOT/pyproject.toml" ]] || [[ -f "$PROJECT_ROOT/setup.py" ]]; then
        echo "pytest"
        return 0
    fi

    # Check for Go
    if [[ -f "$PROJECT_ROOT/go.mod" ]]; then
        echo "go test ./..."
        return 0
    fi

    # Default
    echo "echo 'Configure validation in .aishore/config.yaml'"
}

# ============================================================================
# MIGRATION
# ============================================================================

create_new_structure() {
    log "Creating new .aishore/ structure..."

    mkdir -p "$NEW_DIR"/{agents,context,data/{archive,logs,status},lib,plan/archive}

    success "Directory structure created"
}

copy_new_cli() {
    log "Installing new CLI..."

    if [[ -f "$SCRIPT_DIR/.aishore/aishore" ]]; then
        cp "$SCRIPT_DIR/.aishore/aishore" "$NEW_DIR/aishore"
        chmod +x "$NEW_DIR/aishore"
        success "CLI installed"
    else
        warn "CLI not found in source - you'll need to copy it manually"
    fi
}

copy_new_lib() {
    log "Installing library..."

    if [[ -f "$SCRIPT_DIR/.aishore/lib/common.sh" ]]; then
        cp "$SCRIPT_DIR/.aishore/lib/common.sh" "$NEW_DIR/lib/common.sh"
        success "Library installed"
    else
        warn "Library not found in source - you'll need to copy it manually"
    fi
}

migrate_agents() {
    log "Migrating agent prompts..."

    local migrated=0

    # Copy new agents (preferred - they have updated paths)
    if [[ -d "$SCRIPT_DIR/.aishore/agents" ]]; then
        cp "$SCRIPT_DIR/.aishore/agents/"*.md "$NEW_DIR/agents/" 2>/dev/null || true
        migrated=1
        success "Installed updated agent prompts"
    fi

    # If no source agents, try to copy old ones (will need manual path updates)
    if [[ $migrated -eq 0 ]] && [[ -d "$OLD_DIR/agents" ]]; then
        cp "$OLD_DIR/agents/"*.md "$NEW_DIR/agents/" 2>/dev/null || true
        warn "Copied old agents - they reference old paths and need manual updates"
        warn "  Update references from 'aishore/plan/' to '.aishore/plan/'"
        warn "  Update references from '@CLAUDE.md' to '@.aishore/context/project.md'"
    fi
}

migrate_backlog() {
    log "Migrating backlog data..."

    # Migrate plan files (backlog.json, bugs.json, etc.)
    for file in backlog.json bugs.json icebox.json sprint.json definitions.md; do
        if [[ -f "$OLD_DIR/plan/$file" ]]; then
            cp "$OLD_DIR/plan/$file" "$NEW_DIR/plan/$file"
            success "Migrated $file"
        fi
    done

    # Migrate archives
    for file in done.jsonl sprints.jsonl failed.jsonl; do
        if [[ -f "$OLD_DIR/plan/archive/$file" ]]; then
            cp "$OLD_DIR/plan/archive/$file" "$NEW_DIR/data/archive/$file"
            success "Migrated archive/$file"
        elif [[ -f "$OLD_DIR/plan/.archive/$file" ]]; then
            cp "$OLD_DIR/plan/.archive/$file" "$NEW_DIR/data/archive/$file"
            success "Migrated .archive/$file"
        fi
    done

    # Migrate logs
    if [[ -f "$OLD_DIR/plan/.logs/agent-runs.log" ]]; then
        cp "$OLD_DIR/plan/.logs/agent-runs.log" "$NEW_DIR/data/logs/"
        success "Migrated agent-runs.log"
    fi

    # Create empty files if they don't exist
    touch "$NEW_DIR/data/archive/done.jsonl"
    touch "$NEW_DIR/data/archive/sprints.jsonl"
    touch "$NEW_DIR/data/archive/failed.jsonl"
    touch "$NEW_DIR/data/archive/.gitkeep"
    touch "$NEW_DIR/data/logs/.gitkeep"
    touch "$NEW_DIR/data/status/.gitkeep"
    touch "$NEW_DIR/plan/archive/.gitkeep"
}

create_config() {
    log "Creating config.yaml..."

    local validate_cmd
    validate_cmd=$(detect_validation_command)

    cat > "$NEW_DIR/config.yaml" << EOF
# aishore configuration
# Migrated from legacy aishore/ structure

project:
  name: "$(basename "$PROJECT_ROOT")"

validation:
  command: "$validate_cmd"
  timeout: 120

models:
  primary: "claude-opus-4-5-20251101"
  fast: "claude-sonnet-4-20250514"

agent:
  timeout: 600

context:
  project: "context/project.md"
EOF

    success "Created config.yaml with validation: $validate_cmd"
}

create_context() {
    log "Setting up context..."

    # Check for existing CLAUDE.md
    if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
        # Create symlink
        ln -sf "../../CLAUDE.md" "$NEW_DIR/context/project.md"
        success "Linked context/project.md -> CLAUDE.md"
    else
        # Create placeholder
        cat > "$NEW_DIR/context/project.md" << 'EOF'
# Project Context

Add your project conventions here, or symlink to an existing file:

```bash
ln -sf ../../CLAUDE.md .aishore/context/project.md
```
EOF
        warn "Created placeholder context/project.md - add your project conventions"
    fi
}

update_gitignore() {
    log "Updating .gitignore..."

    local gitignore="$PROJECT_ROOT/.gitignore"
    local needs_update=0

    if [[ -f "$gitignore" ]]; then
        # Check if old entries exist
        if grep -q "aishore/plan/\.logs" "$gitignore" 2>/dev/null; then
            needs_update=1
        fi

        # Add new entries if not present
        if ! grep -q ".aishore/data/logs/" "$gitignore" 2>/dev/null; then
            echo "" >> "$gitignore"
            echo "# aishore runtime files (new structure)" >> "$gitignore"
            echo ".aishore/data/logs/" >> "$gitignore"
            echo ".aishore/data/status/result.json" >> "$gitignore"
            echo ".aishore/data/status/.item_source" >> "$gitignore"
            success "Added new .aishore entries to .gitignore"
        fi
    else
        cat > "$gitignore" << 'EOF'
# aishore runtime files
.aishore/data/logs/
.aishore/data/status/result.json
.aishore/data/status/.item_source
EOF
        success "Created .gitignore"
    fi
}

update_package_json() {
    log "Checking package.json scripts..."

    local pkg="$PROJECT_ROOT/package.json"

    if [[ -f "$pkg" ]]; then
        if grep -q '"aishore"' "$pkg" 2>/dev/null; then
            warn "package.json has aishore scripts - update manually:"
            echo ""
            echo '  "aishore": "./.aishore/aishore run",'
            echo '  "aishore:groom": "./.aishore/aishore groom",'
            echo '  "aishore:metrics": "./.aishore/aishore metrics",'
            echo '  "aishore:review": "./.aishore/aishore review"'
            echo ""
        fi
    fi
}

show_summary() {
    echo ""
    log "Migration complete!"
    echo ""
    echo "New structure:"
    echo "  $NEW_DIR/"
    echo "  ├── aishore           # CLI"
    echo "  ├── config.yaml       # Settings"
    echo "  ├── context/          # Project docs"
    echo "  ├── agents/           # Agent prompts"
    echo "  ├── plan/             # Backlogs"
    echo "  ├── data/             # Runtime (logs, archive)"
    echo "  └── lib/              # Utilities"
    echo ""
    echo "Usage:"
    echo "  .aishore/aishore run        # Run sprint"
    echo "  .aishore/aishore groom      # Groom backlog"
    echo "  .aishore/aishore metrics    # Show metrics"
    echo "  .aishore/aishore help       # Show help"
    echo ""

    if [[ -d "$OLD_DIR" ]]; then
        warn "Old aishore/ directory still exists"
        echo ""
        read -p "Delete old aishore/ directory? [y/N] " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$OLD_DIR"
            success "Deleted old aishore/ directory"
        else
            echo "You can delete it later: rm -rf $OLD_DIR"
        fi
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  aishore Migration Tool${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    echo "Project: $PROJECT_ROOT"
    echo ""

    # Check for existing new structure
    if [[ -d "$NEW_DIR" ]] && [[ -f "$NEW_DIR/aishore" ]]; then
        error "New .aishore/ structure already exists"
        echo "If you want to re-migrate, remove it first: rm -rf $NEW_DIR"
        exit 1
    fi

    # Detect old structure
    if ! detect_old_structure; then
        error "No legacy aishore/ structure found in $PROJECT_ROOT"
        echo ""
        echo "Expected to find:"
        echo "  $OLD_DIR/bin/aishore.sh"
        echo "  $OLD_DIR/plan/backlog.json"
        echo ""
        echo "For fresh install, use: .aishore/aishore init"
        exit 1
    fi

    success "Found legacy aishore/ structure"
    echo ""

    # Confirm migration
    read -p "Migrate to new .aishore/ structure? [Y/n] " response
    if [[ "$response" =~ ^[Nn]$ ]]; then
        echo "Aborted"
        exit 0
    fi
    echo ""

    # Run migration
    create_new_structure
    copy_new_cli
    copy_new_lib
    migrate_agents
    migrate_backlog
    create_config
    create_context
    update_gitignore
    update_package_json
    show_summary
}

main "$@"
