#!/bin/bash
# .aishore/lib/common.sh - Shared utilities for aishore
# Version: 1.0.0 (refactored for .aishore structure)

# ============================================================================
# COLORS
# ============================================================================
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_CYAN='\033[0;36m'
export COLOR_MAGENTA='\033[0;35m'
export COLOR_NC='\033[0m'

# ============================================================================
# LOGGING
# ============================================================================

log_header() {
    local color="${2:-$COLOR_BLUE}"
    echo ""
    echo -e "${color}════════════════════════════════════════${COLOR_NC}"
    echo -e "${color}  $1${COLOR_NC}"
    echo -e "${color}════════════════════════════════════════${COLOR_NC}"
}

log_subheader() {
    echo ""
    echo -e "${COLOR_CYAN}─── $1 ───${COLOR_NC}"
}

log_agent() {
    echo -e "${COLOR_MAGENTA}[$1]${COLOR_NC} $2"
}

log_success() {
    echo -e "${COLOR_GREEN}✓ $1${COLOR_NC}"
}

log_warning() {
    echo -e "${COLOR_YELLOW}⚠ $1${COLOR_NC}"
}

log_error() {
    echo -e "${COLOR_RED}✗ $1${COLOR_NC}"
}

log_info() {
    echo -e "${COLOR_CYAN}$1${COLOR_NC}"
}

# ============================================================================
# CONFIGURATION (can be overridden by config.yaml via main script)
# ============================================================================

export MODEL_OPUS="${MODEL_OPUS:-claude-opus-4-5-20251101}"
export MODEL_SONNET="${MODEL_SONNET:-claude-sonnet-4-20250514}"
export AISHORE_AGENT_TIMEOUT="${AISHORE_AGENT_TIMEOUT:-600}"
export AISHORE_VALIDATE_CMD="${AISHORE_VALIDATE_CMD:-echo 'No validation configured'}"
export AISHORE_TEST_TIMEOUT="${AISHORE_TEST_TIMEOUT:-120}"

# ============================================================================
# GLOBAL STATE
# ============================================================================

declare -g AISHORE_LAST_OUTPUT=""
declare -g AISHORE_LAST_EXIT=0
declare -g AISHORE_LAST_DURATION=0
declare -g AISHORE_AGENT_TIMED_OUT=false
declare -g AISHORE_TEMP_FILES=()
declare -g AISHORE_COMMON_AGENT_PIDS=()

# ============================================================================
# TEMP FILE MANAGEMENT
# ============================================================================

_aishore_cleanup() {
    for f in "${AISHORE_TEMP_FILES[@]}"; do
        [[ -f "$f" ]] && rm -f "$f" 2>/dev/null
    done
    AISHORE_TEMP_FILES=()
}

trap _aishore_cleanup EXIT

create_temp_file() {
    local tmp
    tmp=$(mktemp)
    AISHORE_TEMP_FILES+=("$tmp")
    echo "$tmp"
}

cleanup_agent_output() {
    if [[ -n "$AISHORE_LAST_OUTPUT" && -f "$AISHORE_LAST_OUTPUT" ]]; then
        rm -f "$AISHORE_LAST_OUTPUT" 2>/dev/null || true
    fi
    AISHORE_LAST_OUTPUT=""
}

# ============================================================================
# SIGNAL DETECTION
# ============================================================================

check_signal() {
    local signal_name="$1"
    local output_file="${2:-$AISHORE_LAST_OUTPUT}"

    [[ ! -s "$output_file" ]] && return 1

    local pattern="<<[[:space:]]*SIGNAL[[:space:]]*:[[:space:]]*${signal_name}[[:space:]]*>>"

    if grep -qE "$pattern" "$output_file" 2>/dev/null; then
        return 0
    fi

    if sed 's/`//g' "$output_file" 2>/dev/null | grep -qE "$pattern"; then
        log_warning "Signal found inside markdown - agents should emit signals outside code blocks"
        return 0
    fi

    return 1
}

show_detected_signals() {
    local output_file="${1:-$AISHORE_LAST_OUTPUT}"
    [[ ! -s "$output_file" ]] && { log_warning "No output to analyze"; return 1; }

    echo ""
    echo "Signal analysis:"
    echo "────────────────"

    local signals
    signals=$(grep -oE "<<[[:space:]]*SIGNAL[[:space:]]*:[[:space:]]*[A-Z_]+[[:space:]]*>>" "$output_file" 2>/dev/null | sort -u)

    if [[ -n "$signals" ]]; then
        echo "Found signals:"
        echo "$signals" | while read -r s; do echo "  ✓ $s"; done
    else
        echo "No valid signals found"
        echo "Expected format: <<SIGNAL:NAME>>"
    fi
    echo "────────────────"
}

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

require_command() {
    local cmd="$1"
    local hint="${2:-}"

    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required: $cmd"
        [[ -n "$hint" ]] && echo "  Install: $hint"
        return 1
    fi
    return 0
}

check_aishore_deps() {
    local missing=0
    require_command "jq" "brew install jq / apt install jq" || ((missing++))
    require_command "claude" "https://docs.anthropic.com/claude-code" || ((missing++))
    require_command "git" "brew install git / apt install git" || ((missing++))

    [[ $missing -gt 0 ]] && return 1
    return 0
}

# ============================================================================
# UTILITIES
# ============================================================================

append_log() {
    local file="$1"
    local msg="$2"
    mkdir -p "$(dirname "$file")" 2>/dev/null || true
    echo "$msg" >> "$file"
}

iso_timestamp() {
    date -Iseconds
}

json_get() {
    local file="$1"
    local path="$2"
    local default="${3:-}"

    if [[ -f "$file" ]]; then
        local val
        val=$(jq -r "$path // empty" "$file" 2>/dev/null)
        [[ -n "$val" ]] && { echo "$val"; return 0; }
    fi
    echo "$default"
}

json_count() {
    local file="$1"
    local path="${2:-.}"
    [[ -f "$file" ]] && jq -r "[$path] | length" "$file" 2>/dev/null || echo "0"
}

# ============================================================================
# GIT UTILITIES
# ============================================================================

git_short_hash() {
    git rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

git_is_clean() {
    [[ -z "$(git status --porcelain 2>/dev/null)" ]]
}

git_current_branch() {
    git branch --show-current 2>/dev/null || echo "unknown"
}

# ============================================================================
# TIMEOUT WRAPPER
# ============================================================================

run_with_timeout() {
    local timeout_secs="$1"
    shift

    # Linux: timeout, macOS: gtimeout (from coreutils)
    local timeout_cmd=""
    if command -v timeout &> /dev/null; then
        timeout_cmd="timeout"
    elif command -v gtimeout &> /dev/null; then
        timeout_cmd="gtimeout"
    fi

    if [[ -n "$timeout_cmd" ]]; then
        "$timeout_cmd" --signal=TERM --kill-after=30 "$timeout_secs" "$@"
        return $?
    fi

    log_warning "timeout command not available (install coreutils on macOS: brew install coreutils)"
    "$@"
}

# ============================================================================
# CLAUDE AGENT RUNNER
# ============================================================================

_kill_agent_tree() {
    local pid="$1"
    local signal="${2:-TERM}"
    kill -"$signal" -"$pid" 2>/dev/null && return 0
    kill -"$signal" "$pid" 2>/dev/null
}

cleanup_orphaned_agents() {
    for pid in "${AISHORE_COMMON_AGENT_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Killing orphaned agent process $pid"
            _kill_agent_tree "$pid" TERM
            sleep 1
            _kill_agent_tree "$pid" KILL
        fi
    done
    AISHORE_COMMON_AGENT_PIDS=()
}

run_claude_agent() {
    local agent_name="$1"
    local model="$2"
    local allowed_tools="$3"
    local prompt="$4"
    local context_files="$5"
    local timeout_secs="${6:-$AISHORE_AGENT_TIMEOUT}"

    AISHORE_LAST_OUTPUT=""
    AISHORE_LAST_EXIT=0
    AISHORE_LAST_DURATION=0
    AISHORE_AGENT_TIMED_OUT=false

    local output_file
    output_file=$(create_temp_file)
    AISHORE_LAST_OUTPUT="$output_file"

    local cmd="claude --model $model --allowedTools '$allowed_tools' --print"

    if [[ -n "$context_files" ]]; then
        for ctx in $context_files; do
            cmd="$cmd \"$ctx\""
        done
    fi

    log_agent "$agent_name" "Starting (model: $model, timeout: ${timeout_secs}s)"

    local start_time
    start_time=$(date +%s)

    setsid bash -c "$cmd" <<< "$prompt" > "$output_file" 2>&1 &

    local agent_pid=$!
    AISHORE_COMMON_AGENT_PIDS+=("$agent_pid")

    local elapsed=0
    local check_interval=5
    while kill -0 "$agent_pid" 2>/dev/null; do
        sleep "$check_interval"
        elapsed=$((elapsed + check_interval))

        if [[ $elapsed -ge $timeout_secs ]]; then
            AISHORE_AGENT_TIMED_OUT=true
            log_warning "Agent $agent_name timed out after ${timeout_secs}s"
            _kill_agent_tree "$agent_pid" TERM
            sleep 2
            kill -0 "$agent_pid" 2>/dev/null && _kill_agent_tree "$agent_pid" KILL
            break
        fi
    done

    wait "$agent_pid" 2>/dev/null
    AISHORE_LAST_EXIT=$?
    AISHORE_COMMON_AGENT_PIDS=("${AISHORE_COMMON_AGENT_PIDS[@]/$agent_pid}")

    local end_time
    end_time=$(date +%s)
    AISHORE_LAST_DURATION=$((end_time - start_time))

    log_agent "$agent_name" "Completed in ${AISHORE_LAST_DURATION}s (exit: $AISHORE_LAST_EXIT)"

    return $AISHORE_LAST_EXIT
}
