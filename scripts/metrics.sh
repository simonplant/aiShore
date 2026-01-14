#!/bin/bash
set -e

# Sprint Metrics Analyzer
# Analyzes cycle time, velocity, and agent performance

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLAN_DIR="$PROJECT_ROOT/plan"
LOG_DIR="$PLAN_DIR/.logs"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

header() {
    echo ""
    echo -e "${CYAN}=== $1 ===${NC}"
    echo ""
}

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    exit 1
fi

header "SPRINT METRICS REPORT"
echo "Generated: $(date)"
echo "Project: $PROJECT_ROOT"

# Current sprint metrics
header "CURRENT SPRINT"
if [[ -f "$PLAN_DIR/sprint-current.json" ]]; then
    sprint_id=$(jq -r '.sprintId' "$PLAN_DIR/sprint-current.json")
    status=$(jq -r '.status' "$PLAN_DIR/sprint-current.json")
    goal=$(jq -r '.goal' "$PLAN_DIR/sprint-current.json")

    echo "Sprint: $sprint_id"
    echo "Status: $status"
    echo "Goal: $goal"
    echo ""

    # Item details with cycle time
    echo "Items:"
    jq -r '.items[] | "  \(.id) | \(.status) | Size: \(.size // "N/A") | Cycle: \(.cycleTimeMinutes // "N/A") min"' \
        "$PLAN_DIR/sprint-current.json"
else
    echo "No active sprint"
fi

# Backlog health
header "BACKLOG HEALTH"
if [[ -f "$PLAN_DIR/backlog-mvp.json" ]]; then
    total=$(jq '[.items[]] | length' "$PLAN_DIR/backlog-mvp.json")
    done=$(jq '[.items[] | select(.passes == true)] | length' "$PLAN_DIR/backlog-mvp.json")
    ready=$(jq '[.items[] | select(.readyForSprint == true and .passes != true)] | length' "$PLAN_DIR/backlog-mvp.json")

    echo "Total MVP items: $total"
    echo "Completed: $done ($(( done * 100 / total ))%)"
    echo -e "Ready for sprint: ${GREEN}$ready${NC}"

    if [[ $ready -lt 3 ]]; then
        echo -e "${YELLOW}WARNING: Ready buffer low (<3). Consider running grooming.${NC}"
    fi
fi

# Agent performance
header "AGENT PERFORMANCE (Last 20 runs)"
if [[ -f "$LOG_DIR/agent-runs.log" && -s "$LOG_DIR/agent-runs.log" ]]; then
    echo "Agent         | Avg Time | Runs"
    echo "--------------|----------|-----"
    tail -100 "$LOG_DIR/agent-runs.log" | \
        awk -F'|' '
        {
            gsub(/^ +| +$/, "", $2)
            gsub(/s$/, "", $3)
            count[$2]++
            time[$2]+=$3
        }
        END {
            for (a in count) {
                if (count[a] > 0) {
                    avg = time[a]/count[a]
                    printf "%-13s | %5ds   | %d\n", a, avg, count[a]
                }
            }
        }' | sort -t'|' -k2 -rn
else
    echo "No agent logs found or file empty"
fi

# Cycle time trends (from completed sprints)
header "CYCLE TIME TRENDS"
echo "Analyzing completed items from sprint history..."

# Extract cycle times from recent sprints if they exist
if [[ -f "$PLAN_DIR/sprint-current.json" ]]; then
    completed_items=$(jq '[.items[] | select(.cycleTimeMinutes != null)]' "$PLAN_DIR/sprint-current.json")
    count=$(echo "$completed_items" | jq 'length')

    if [[ $count -gt 0 ]]; then
        avg=$(echo "$completed_items" | jq '[.[].cycleTimeMinutes] | add / length | floor')
        min=$(echo "$completed_items" | jq '[.[].cycleTimeMinutes] | min')
        max=$(echo "$completed_items" | jq '[.[].cycleTimeMinutes] | max')

        echo "Items with cycle time: $count"
        echo "Average: ${avg} min"
        echo "Min: ${min} min | Max: ${max} min"
    else
        echo "No cycle time data yet (sprints need to complete)"
    fi
fi

# Size estimation accuracy (future enhancement)
header "SIZE ESTIMATION"
echo "Size distribution in current sprint:"
if [[ -f "$PLAN_DIR/sprint-current.json" ]]; then
    jq -r '.items[] | "\(.size // "unestimated"): \(.id)"' "$PLAN_DIR/sprint-current.json"
fi

# Summary recommendations
header "RECOMMENDATIONS"
if [[ -f "$PLAN_DIR/backlog-mvp.json" ]]; then
    ready=$(jq '[.items[] | select(.readyForSprint == true and .passes != true)] | length' "$PLAN_DIR/backlog-mvp.json")

    if [[ $ready -lt 3 ]]; then
        echo "- Run backlog grooming: npm run aishore:groom"
    fi

    if [[ $ready -ge 3 ]]; then
        echo -e "- Ready buffer healthy (${GREEN}$ready items${NC})"
    fi
fi

echo ""
echo "Run 'npm run aishore' to start next sprint"
