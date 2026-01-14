#!/bin/bash
set -e

# aiShore v0.1 - AI Engineering Team Orchestrator
# Your onshore AI development team: 3 agents, 4 gates, adaptive complexity
#
# Flow:
#   START (Tech Lead) → IMPLEMENT (Developer) → [REVIEW (Tech Lead)] → VALIDATE → CLOSE (Tech Lead)
#
# Adaptive routing based on item size:
#   XS/S  → Skip code review (fast path)
#   M+    → Include code review
#   L/XL  → Include design proposal
#
# Usage: ./scripts/aishore.sh [options]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$SCRIPT_DIR/agents"
PLAN_DIR="$PROJECT_ROOT/plan"
LOG_DIR="$PLAN_DIR/.logs"

mkdir -p "$LOG_DIR"

# Global: last agent output file
LAST_AGENT_OUTPUT=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Model
MODEL_OPUS="claude-opus-4-5-20251101"

# Flags
QUICK_MODE=false
FORCE_REVIEW=false
FULL_CEREMONY=false
GROOM_ONLY=false
SKIP_PREFLIGHT=false
BATCH_MODE=false
BATCH_COUNT=5
AUTO_COMMIT=false

# Batch tracking
BATCH_RESULTS=()
BATCH_START_TIME=""

# === Logging ===

log_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

log_subheader() {
    echo ""
    echo -e "${CYAN}--- $1 ---${NC}"
    echo ""
}

log_agent() {
    echo -e "${MAGENTA}[$1]${NC} $2"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_warning() {
    echo -e "${YELLOW}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}"
}

# === Dependencies ===

check_deps() {
    if ! command -v jq &> /dev/null; then
        log_error "Error: jq is required but not installed."
        exit 1
    fi
    if ! command -v claude &> /dev/null; then
        log_error "Error: claude CLI is required but not installed."
        exit 1
    fi
    if [[ ! -f "$PLAN_DIR/backlog-mvp.json" ]]; then
        log_error "Error: $PLAN_DIR/backlog-mvp.json not found."
        exit 1
    fi
}

# === JSON Helpers ===

atomic_json_update() {
    local file="$1"
    local jq_filter="$2"
    shift 2
    local jq_args=("$@")

    local tmp_file="${file}.tmp.$$"
    local backup_file="${file}.bak"

    cp "$file" "$backup_file" 2>/dev/null || true

    if jq "${jq_args[@]}" "$jq_filter" "$file" > "$tmp_file" 2>/dev/null; then
        if jq empty "$tmp_file" 2>/dev/null; then
            mv "$tmp_file" "$file"
            rm -f "$backup_file"
            return 0
        fi
    fi
    rm -f "$tmp_file"
    return 1
}

# === Checkpoint System ===

save_checkpoint() {
    local phase="$1"
    local item_id="$2"
    local attempt="${3:-1}"

    cat > "$LOG_DIR/checkpoint.json" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "phase": "$phase",
    "itemId": "$item_id",
    "attempt": $attempt,
    "sprintId": "$(jq -r '.sprintId // "unknown"' "$PLAN_DIR/sprint-current.json" 2>/dev/null)"
}
EOF
    log_agent "checkpoint" "Saved: $phase for $item_id (attempt $attempt)"
}

clear_checkpoint() {
    rm -f "$LOG_DIR/checkpoint.json" 2>/dev/null || true
}

check_checkpoint() {
    local checkpoint_file="$LOG_DIR/checkpoint.json"
    if [[ -f "$checkpoint_file" ]]; then
        local phase item_id attempt
        phase=$(jq -r '.phase' "$checkpoint_file")
        item_id=$(jq -r '.itemId' "$checkpoint_file")
        attempt=$(jq -r '.attempt' "$checkpoint_file")
        log_warning "Found checkpoint: $phase for $item_id (attempt $attempt)"
        return 0
    fi
    return 1
}

# === Agent Runner ===

run_agent() {
    local agent_name="$1"
    local mode="$2"
    local extra_context="$3"

    LAST_AGENT_OUTPUT=$(mktemp)
    local start_time=$(date +%s)

    local prompt_file="$AGENTS_DIR/${agent_name}.md"

    if [[ ! -f "$prompt_file" ]]; then
        log_error "Agent prompt not found: $prompt_file"
        return 1
    fi

    local full_prompt="$(cat "$prompt_file")"
    if [[ -n "$mode" ]]; then
        full_prompt="$full_prompt

## Mode
$mode"
    fi
    if [[ -n "$extra_context" ]]; then
        full_prompt="$full_prompt

## Additional Context
$extra_context"
    fi

    log_agent "$agent_name" "Starting (mode: $mode)"

    env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT \
        claude --model "$MODEL_OPUS" \
        --permission-mode acceptEdits \
        --allowedTools "Bash(git:*),Edit,Write" \
        --output-format text \
        -p "@plan/backlog-mvp.json @plan/backlog-growth.json @plan/backlog-polish.json @plan/backlog-future.json @plan/sprint-current.json @plan/progress.txt @CLAUDE.md
$full_prompt" 2>&1 | tee "$LAST_AGENT_OUTPUT"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "$(date -Iseconds) | $agent_name | ${duration}s | $MODEL_OPUS" >> "$LOG_DIR/agent-runs.log"

    log_agent "$agent_name" "Completed in ${duration}s"
}

check_signal() {
    local signal_name="$1"

    # Ensure file is fully written
    sync 2>/dev/null || true
    sleep 0.1

    # Check if file exists and has content
    if [[ ! -s "$LAST_AGENT_OUTPUT" ]]; then
        log_warning "Output file empty or missing: $LAST_AGENT_OUTPUT"
        return 1
    fi

    # Primary check: exact signal format (flexible whitespace, may be in code block)
    if grep -qE "(<<\s*SIGNAL\s*:\s*${signal_name}\s*>>|<signal>\s*${signal_name}\s*</signal>)" "$LAST_AGENT_OUTPUT" 2>/dev/null; then
        return 0
    fi

    # Secondary check: signal may have backticks or be in markdown
    if grep -qE "SIGNAL.*:.*${signal_name}" "$LAST_AGENT_OUTPUT" 2>/dev/null; then
        log_warning "Found signal with non-standard format: ${signal_name}"
        return 0
    fi

    # Tertiary check: look for the signal name as a standalone word in common output patterns
    case "$signal_name" in
        START_COMPLETE)
            grep -qiE "(sprint.*started|start.*complete|selected.*item)" "$LAST_AGENT_OUTPUT" 2>/dev/null && return 0
            ;;
        IMPL_COMPLETE)
            grep -qiE "(implementation.*complete|impl.*complete|changes.*staged)" "$LAST_AGENT_OUTPUT" 2>/dev/null && return 0
            ;;
        CODE_APPROVED)
            grep -qiE "(code.*review.*approved|review.*approved|code.*approved)" "$LAST_AGENT_OUTPUT" 2>/dev/null && return 0
            ;;
        VALIDATION_PASS)
            grep -qiE "(validation.*pass|all.*tests.*pass|validation.*complete)" "$LAST_AGENT_OUTPUT" 2>/dev/null && return 0
            ;;
        SPRINT_CLOSED)
            grep -qiE "(sprint.*closed|sprint.*complete)" "$LAST_AGENT_OUTPUT" 2>/dev/null && return 0
            ;;
        GROOM_COMPLETE)
            grep -qiE "(grooming.*complete|groom.*complete|backlog.*ready)" "$LAST_AGENT_OUTPUT" 2>/dev/null && return 0
            ;;
    esac

    return 1
}

# Debug helper to show what signals are in output
show_signals_in_output() {
    if [[ -s "$LAST_AGENT_OUTPUT" ]]; then
        local signals=$(grep -oE "(<<SIGNAL:[^>]+>>|<signal>[^<]+</signal>)" "$LAST_AGENT_OUTPUT" 2>/dev/null | head -5)
        if [[ -n "$signals" ]]; then
            log_warning "Signals found in output: $signals"
        fi
    fi
}

cleanup_output() {
    rm -f "$LAST_AGENT_OUTPUT" 2>/dev/null || true
}

# === Gate Functions ===

run_groom() {
    log_header "BACKLOG GROOMING"

    run_agent "tech-lead" "groom" ""

    if check_signal "GROOM_COMPLETE"; then
        log_success "Grooming complete"
        cleanup_output
        return 0
    else
        log_error "Grooming did not complete successfully"
        show_signals_in_output
        cleanup_output
        return 1
    fi
}

run_start() {
    log_header "GATE 1: START"
    save_checkpoint "start" "sprint"

    local preflight_flag=""
    if [[ "$SKIP_PREFLIGHT" == "true" ]]; then
        preflight_flag="Skip pre-flight: Environment check is skipped."
    fi

    run_agent "tech-lead" "start" "$preflight_flag"

    if check_signal "START_COMPLETE"; then
        log_success "Sprint started"
        cleanup_output
        return 0
    elif check_signal "PREFLIGHT_FAIL"; then
        log_error "Pre-flight failed"
        cleanup_output
        return 1
    elif check_signal "BACKLOG_EMPTY"; then
        log_warning "Backlog empty - nothing to do"
        cleanup_output
        return 1
    else
        log_error "SIGNAL MISSING: Expected START_COMPLETE, PREFLIGHT_FAIL, or BACKLOG_EMPTY"
        show_signals_in_output
        cleanup_output
        return 1
    fi
}

run_implement() {
    local item_id="$1"
    local size="$2"
    local attempts="$3"

    log_header "GATE 2: IMPLEMENT"
    save_checkpoint "implement" "$item_id" "$attempts"

    # Record start time
    atomic_json_update "$PLAN_DIR/sprint-current.json" \
        '.item.startedAt = $ts' --arg ts "$(date -Iseconds)" || true

    local extra=""
    if [[ "$size" == "L" || "$size" == "XL" || "$FULL_CEREMONY" == "true" ]]; then
        extra="Design mode: This is a large item. Propose your approach before implementing.
Output <<SIGNAL:DESIGN_PROPOSED>> after your design proposal, then wait for approval."
    fi

    if [[ $attempts -gt 1 ]]; then
        extra="$extra

IMPORTANT: This is retry attempt $attempts. Check rejectionNotes in sprint-current.json for feedback."
    fi

    run_agent "developer" "implement" "Item ID: $item_id
$extra"

    if check_signal "IMPL_COMPLETE"; then
        log_success "Implementation complete"
        cleanup_output
        return 0
    elif check_signal "DESIGN_PROPOSED"; then
        log_success "Design proposal submitted"
        # Keep output for review
        return 2  # Special code for design mode
    else
        log_error "SIGNAL MISSING: Expected IMPL_COMPLETE or DESIGN_PROPOSED"
        show_signals_in_output
        cleanup_output
        return 1
    fi
}

run_code_review() {
    local item_id="$1"

    log_header "GATE 3: CODE REVIEW"
    save_checkpoint "review" "$item_id"

    run_agent "tech-lead" "review" "Item ID: $item_id
Review the staged changes (git diff --cached)."

    if check_signal "CODE_APPROVED"; then
        log_success "Code review: APPROVED"
        cleanup_output
        return 0
    elif check_signal "CODE_NEEDS_WORK"; then
        log_warning "Code review: NEEDS WORK"
        cleanup_output
        return 1
    else
        log_error "SIGNAL MISSING: Expected CODE_APPROVED or CODE_NEEDS_WORK"
        show_signals_in_output
        cleanup_output
        return 1
    fi
}

run_design_review() {
    local item_id="$1"
    local design_output="$2"

    log_subheader "Design Review: $item_id"

    local design_content=""
    if [[ -f "$design_output" ]]; then
        design_content=$(cat "$design_output")
    fi

    run_agent "tech-lead" "design-review" "Item ID: $item_id

## Developer's Design Proposal
$design_content"

    if check_signal "DESIGN_APPROVED"; then
        log_success "Design review: APPROVED"
        cleanup_output
        return 0
    elif check_signal "DESIGN_NEEDS_REVISION"; then
        log_warning "Design review: NEEDS REVISION"
        cleanup_output
        return 1
    elif check_signal "DESIGN_REJECTED"; then
        log_error "Design review: REJECTED"
        cleanup_output
        return 2
    else
        log_error "SIGNAL MISSING: Expected design review signal"
        show_signals_in_output
        cleanup_output
        return 1
    fi
}

run_validate() {
    local item_id="$1"

    log_header "GATE 4: VALIDATE"
    save_checkpoint "validate" "$item_id"

    run_agent "validator" "validate" "Item ID: $item_id"

    if check_signal "VALIDATION_PASS"; then
        log_success "Validation: PASSED"
        cleanup_output
        return 0
    elif check_signal "VALIDATION_REJECT"; then
        log_warning "Validation: REJECTED"
        cleanup_output
        return 1
    else
        log_error "SIGNAL MISSING: Expected VALIDATION_PASS or VALIDATION_REJECT"
        show_signals_in_output
        cleanup_output
        return 1
    fi
}

run_close() {
    log_header "GATE 5: CLOSE"
    save_checkpoint "close" "sprint"

    run_agent "tech-lead" "close" ""

    if check_signal "SPRINT_CLOSED"; then
        log_success "Sprint closed"
        clear_checkpoint
        cleanup_output
        return 0
    else
        log_warning "Sprint close signal missing, but proceeding"
        clear_checkpoint
        cleanup_output
        return 0
    fi
}

# === Main Flow ===

determine_flow() {
    local size="$1"

    if [[ "$FULL_CEREMONY" == "true" ]]; then
        echo "full"  # Design + code review
    elif [[ "$QUICK_MODE" == "true" ]]; then
        echo "quick"  # No code review, minimal validation
    elif [[ "$FORCE_REVIEW" == "true" ]]; then
        echo "review"  # Force code review
    elif [[ "$size" == "L" || "$size" == "XL" ]]; then
        echo "full"  # Large items get design + review
    elif [[ "$size" == "M" ]]; then
        echo "review"  # Medium items get code review
    else
        echo "fast"  # XS/S skip code review
    fi
}

run_sprint() {
    # Start gate
    if ! run_start; then
        return 1
    fi

    # Get item info
    local item_id size
    item_id=$(jq -r '.item.id' "$PLAN_DIR/sprint-current.json")
    size=$(jq -r '.item.size' "$PLAN_DIR/sprint-current.json")

    if [[ -z "$item_id" || "$item_id" == "null" ]]; then
        log_error "No item in sprint"
        return 1
    fi

    local flow=$(determine_flow "$size")
    log_success "Item: $item_id | Size: $size | Flow: $flow"

    local max_attempts=2
    local attempts=0
    local item_passed=false

    while [[ $attempts -lt $max_attempts ]] && [[ "$item_passed" != "true" ]]; do
        attempts=$((attempts + 1))
        log_subheader "Attempt $attempts of $max_attempts"

        # Implementation
        run_implement "$item_id" "$size" "$attempts"
        local impl_result=$?

        if [[ $impl_result -eq 2 ]]; then
            # Design mode - need review
            local design_output="$LAST_AGENT_OUTPUT"
            if ! run_design_review "$item_id" "$design_output"; then
                rm -f "$design_output" 2>/dev/null
                continue
            fi
            rm -f "$design_output" 2>/dev/null

            # Now implement for real
            run_agent "developer" "implement" "Item ID: $item_id
Design approved. Proceed with implementation."
            if ! check_signal "IMPL_COMPLETE"; then
                cleanup_output
                continue
            fi
            cleanup_output
        elif [[ $impl_result -ne 0 ]]; then
            continue
        fi

        # Code review (if flow requires it)
        if [[ "$flow" == "full" || "$flow" == "review" ]]; then
            if ! run_code_review "$item_id"; then
                # Update rejection notes
                atomic_json_update "$PLAN_DIR/sprint-current.json" \
                    '.item.rejectionNotes = "Code review failed" | .item.attempts = $a' \
                    --argjson a "$attempts" || true
                continue
            fi
        fi

        # Validation
        if run_validate "$item_id"; then
            item_passed=true
        else
            atomic_json_update "$PLAN_DIR/sprint-current.json" \
                '.item.attempts = $a' --argjson a "$attempts" || true
        fi
    done

    if [[ "$item_passed" != "true" ]]; then
        log_error "Item failed after $max_attempts attempts"
        atomic_json_update "$PLAN_DIR/sprint-current.json" \
            '.item.status = "failed"' || true
        git reset HEAD 2>/dev/null || true
        return 1
    fi

    # Close sprint
    run_close

    return 0
}

# === Batch Functions ===

record_batch_result() {
    local item_id="$1"
    local status="$2"
    local duration="$3"
    BATCH_RESULTS+=("$item_id:$status:$duration")
}

show_batch_summary() {
    local total_time=$(($(date +%s) - BATCH_START_TIME))
    local passed=0
    local failed=0
    local skipped=0

    log_header "BATCH SUMMARY"

    echo "Results:"
    for result in "${BATCH_RESULTS[@]}"; do
        local item_id status duration
        IFS=':' read -r item_id status duration <<< "$result"
        case "$status" in
            pass)
                echo -e "  ${GREEN}✓${NC} $item_id (${duration}s)"
                passed=$((passed + 1))
                ;;
            fail)
                echo -e "  ${RED}✗${NC} $item_id (${duration}s)"
                failed=$((failed + 1))
                ;;
            skip)
                echo -e "  ${YELLOW}○${NC} $item_id (skipped)"
                skipped=$((skipped + 1))
                ;;
        esac
    done

    echo ""
    echo "Statistics:"
    echo "  Total sprints: ${#BATCH_RESULTS[@]}"
    echo "  Passed: $passed"
    echo "  Failed: $failed"
    echo "  Skipped: $skipped"
    echo "  Total time: $((total_time / 60))m $((total_time % 60))s"

    if [[ $passed -gt 0 ]]; then
        echo ""
        log_success "Batch complete: $passed items shipped!"
    fi
}

auto_commit_sprint() {
    local item_id="$1"
    local desc="$2"

    if [[ -z "$(git diff --cached --name-only)" ]]; then
        log_warning "No staged changes to commit"
        return 0
    fi

    git commit -m "$(cat <<EOF
feat: implement $item_id - $desc

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
    log_success "Committed: $item_id"
}

show_help() {
    echo "aiShore v0.1 - Agentic AI Engineering Orchestrator"
    echo "Your agentic AI development team"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --quick          Skip code review and AC check (validation only)"
    echo "  --review         Force code review (even for XS/S items)"
    echo "  --full           Full ceremony (design + code review)"
    echo "  --groom          Standalone backlog grooming (no sprint)"
    echo "  --skip-preflight Skip environment pre-flight check"
    echo "  --batch [N]      Run N sprints in sequence (default: 5), auto-commit each"
    echo "  --auto-commit    Auto-commit after successful sprint (no prompt)"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Flow by size (default):"
    echo "  XS/S  → Start → Implement → Validate → Close (fast)"
    echo "  M     → Start → Implement → Code Review → Validate → Close"
    echo "  L/XL  → Start → Design → Review → Implement → Code Review → Validate → Close"
    echo ""
    echo "Examples:"
    echo "  $0               # Run adaptive sprint"
    echo "  $0 --groom       # Groom backlog only"
    echo "  $0 --quick       # Fast validation only"
    echo "  $0 --full        # Full ceremony for any size"
    echo "  $0 --batch       # Run 5 sprints, auto-commit each"
    echo "  $0 --batch 10    # Run 10 sprints, auto-commit each"
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --review)
                FORCE_REVIEW=true
                shift
                ;;
            --full)
                FULL_CEREMONY=true
                shift
                ;;
            --groom)
                GROOM_ONLY=true
                shift
                ;;
            --skip-preflight)
                SKIP_PREFLIGHT=true
                shift
                ;;
            --batch)
                BATCH_MODE=true
                AUTO_COMMIT=true
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    BATCH_COUNT="$2"
                    shift
                fi
                shift
                ;;
            --auto-commit)
                AUTO_COMMIT=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    check_deps
    cd "$PROJECT_ROOT"

    # Check for crashed run - auto-clear in batch mode
    if check_checkpoint; then
        if [[ "$BATCH_MODE" == "true" ]]; then
            clear_checkpoint
            log_success "Checkpoint auto-cleared (batch mode)"
        else
            read -p "Clear checkpoint and start fresh? [y/N] " clear_ckpt
            if [[ $clear_ckpt == [yY] ]]; then
                clear_checkpoint
                log_success "Checkpoint cleared"
            fi
        fi
    fi

    log_header "aiShore v0.1 - AI Engineering Team"
    echo "Project: $PROJECT_ROOT"
    echo ""

    # Handle groom-only mode
    if [[ "$GROOM_ONLY" == "true" ]]; then
        echo -e "Mode: ${MAGENTA}GROOM (backlog grooming only)${NC}"
        echo ""
        if run_groom; then
            log_success "Backlog grooming complete"
            exit 0
        else
            log_error "Grooming failed"
            exit 1
        fi
    fi

    echo "Team: Tech Lead, Developer, Validator"
    echo "Flow: Start → Implement → [Review] → Validate → Close"
    echo ""

    # Show mode
    if [[ "$BATCH_MODE" == "true" ]]; then
        echo -e "Mode: ${MAGENTA}BATCH ($BATCH_COUNT sprints, auto-commit)${NC}"
    elif [[ "$QUICK_MODE" == "true" ]]; then
        echo -e "Mode: ${YELLOW}QUICK (validation only)${NC}"
    elif [[ "$FULL_CEREMONY" == "true" ]]; then
        echo -e "Mode: ${CYAN}FULL (design + review)${NC}"
    elif [[ "$FORCE_REVIEW" == "true" ]]; then
        echo -e "Mode: ${CYAN}REVIEW (forced code review)${NC}"
    else
        echo -e "Mode: ${GREEN}ADAPTIVE (based on item size)${NC}"
    fi
    echo ""

    # === BATCH MODE ===
    if [[ "$BATCH_MODE" == "true" ]]; then
        BATCH_START_TIME=$(date +%s)
        local sprint_num=0
        local consecutive_failures=0
        local max_consecutive_failures=3

        while [[ $sprint_num -lt $BATCH_COUNT ]]; do
            sprint_num=$((sprint_num + 1))
            log_header "BATCH SPRINT $sprint_num of $BATCH_COUNT"

            local sprint_start=$(date +%s)
            local item_id=""
            local item_desc=""

            if run_sprint; then
                local sprint_end=$(date +%s)
                local sprint_duration=$((sprint_end - sprint_start))

                item_id=$(jq -r '.item.id' "$PLAN_DIR/sprint-current.json" 2>/dev/null || echo "unknown")
                item_desc=$(jq -r '.item.description // .item.id' "$PLAN_DIR/sprint-current.json" 2>/dev/null || echo "")

                # Auto-commit
                auto_commit_sprint "$item_id" "$item_desc"

                record_batch_result "$item_id" "pass" "$sprint_duration"
                consecutive_failures=0

                log_success "Sprint $sprint_num complete: $item_id"
            else
                local sprint_end=$(date +%s)
                local sprint_duration=$((sprint_end - sprint_start))

                item_id=$(jq -r '.item.id' "$PLAN_DIR/sprint-current.json" 2>/dev/null || echo "unknown")

                # Reset any staged changes on failure
                git reset HEAD 2>/dev/null || true

                record_batch_result "$item_id" "fail" "$sprint_duration"
                consecutive_failures=$((consecutive_failures + 1))

                log_error "Sprint $sprint_num failed: $item_id"

                # Check if backlog is empty
                if [[ "$item_id" == "unknown" || "$item_id" == "null" ]]; then
                    log_warning "Backlog appears empty, stopping batch"
                    break
                fi

                # Stop if too many consecutive failures
                if [[ $consecutive_failures -ge $max_consecutive_failures ]]; then
                    log_error "Too many consecutive failures ($max_consecutive_failures), stopping batch"
                    break
                fi
            fi

            # Clear checkpoint between sprints
            clear_checkpoint
        done

        show_batch_summary
        exit 0
    fi

    # === SINGLE SPRINT MODE ===
    if run_sprint; then
        log_header "SPRINT COMPLETE"

        local item_id item_desc
        item_id=$(jq -r '.item.id' "$PLAN_DIR/sprint-current.json" 2>/dev/null || echo "item")
        item_desc=$(jq -r '.item.description // .item.id' "$PLAN_DIR/sprint-current.json" 2>/dev/null || echo "")

        echo ""
        echo "Staged changes:"
        git status --short
        echo ""
        git diff --cached --stat 2>/dev/null || true
        echo ""

        if [[ "$AUTO_COMMIT" == "true" ]]; then
            auto_commit_sprint "$item_id" "$item_desc"
        else
            read -p "Commit? [y/N] " confirm
            if [[ $confirm == [yY] ]]; then
                auto_commit_sprint "$item_id" "$item_desc"
            else
                log_warning "Changes remain staged. Review with: git diff --cached"
            fi
        fi
    else
        log_error "Sprint failed"
        exit 1
    fi
}

main "$@"
