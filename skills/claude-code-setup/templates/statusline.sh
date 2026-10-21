#!/bin/bash
# reads JSON session data from stdin (provided by Claude Code)
input=$(cat)

# extract session fields
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // ""')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
SESSION_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
SESSION_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# colors
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
BLUE='\033[34m'
MAGENTA='\033[35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# --- line 1: model | directory | git branch ---

DIRNAME="${DIR##*/}"

GIT_PART=""
if git -C "${DIR:-.}" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "${DIR:-.}" branch --show-current 2>/dev/null)
    STAGED=$(git -C "${DIR:-.}" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git -C "${DIR:-.}" diff --numstat 2>/dev/null | wc -l | tr -d ' ')

    STAGED_STR=""
    MODIFIED_STR=""
    [ "$STAGED" -gt 0 ] && STAGED_STR="${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && MODIFIED_STR="${YELLOW}~${MODIFIED}${RESET}"

    GIT_PART=" ${DIM}|${RESET} 🌿 ${CYAN}${BRANCH}${RESET}"
    [ -n "$STAGED_STR" ] && GIT_PART="${GIT_PART} ${STAGED_STR}"
    [ -n "$MODIFIED_STR" ] && GIT_PART="${GIT_PART} ${MODIFIED_STR}"
fi

printf '%b\n' "${BOLD}${MAGENTA}[${MODEL}]${RESET} 📁 ${DIRNAME}${GIT_PART}"

# --- line 2: context bar | cost | lines changed | duration ---

# color-coded progress bar (20 chars wide)
BAR_WIDTH=20
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))

if [ "$PCT" -ge 90 ]; then
    BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then
    BAR_COLOR="$YELLOW"
else
    BAR_COLOR="$GREEN"
fi

BAR=""
for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
for ((i=0; i<EMPTY; i++)); do BAR="${BAR}░"; done

# show cost only on pay-per-use plans (subscription plans always show $0)
COST_PART=""
if [ "$(echo "$COST > 0.0001" | bc -l 2>/dev/null)" = "1" ]; then
    COST_FMT=$(printf '$%.3f' "$COST")
    COST_PART=" ${DIM}|${RESET} ${YELLOW}${COST_FMT}${RESET}"
else
    # subscription plan: show token counts instead
    IN_K=$(echo "$INPUT_TOKENS" | awk '{printf "%.0fK", $1/1000}')
    OUT_K=$(echo "$OUTPUT_TOKENS" | awk '{printf "%.0fK", $1/1000}')
    COST_PART=" ${DIM}|${RESET} ${DIM}in:${RESET}${IN_K} ${DIM}out:${RESET}${OUT_K}"
fi

# format duration
DURATION_SEC=$((DURATION_MS / 1000))
MINS=$((DURATION_SEC / 60))
SECS=$((DURATION_SEC % 60))

# lines changed indicator
LINES_PART=""
if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
    LINES_PART=" ${DIM}|${RESET} ${GREEN}+${LINES_ADDED}${RESET}${DIM}/${RESET}${RED}-${LINES_REMOVED}${RESET} lines"
fi

# 5-hour session usage (subscription plans only)
SESSION_PART=""
if [ -n "$SESSION_PCT" ]; then
    if [ "$SESSION_PCT" -ge 90 ]; then
        SESSION_COLOR="$RED"
    elif [ "$SESSION_PCT" -ge 70 ]; then
        SESSION_COLOR="$YELLOW"
    else
        SESSION_COLOR="$GREEN"
    fi
    SESSION_PART=" ${DIM}|${RESET} ${DIM}session:${RESET}${SESSION_COLOR}${SESSION_PCT}%${RESET}"
    # epoch → HH:MM: BSD/macOS `date -r`, then GNU/Linux `date -d @`; neither → no reset time
    RESET_AT=""
    [ -n "$SESSION_RESET" ] && RESET_AT=$(date -r "${SESSION_RESET%.*}" +%H:%M 2>/dev/null || date -d "@${SESSION_RESET%.*}" +%H:%M 2>/dev/null)
    [ -n "$RESET_AT" ] && SESSION_PART="${SESSION_PART} ${DIM}↻ ${RESET_AT}${RESET}"
fi

printf '%b\n' "${BAR_COLOR}${BAR}${RESET} ${PCT}%${COST_PART}${SESSION_PART}${LINES_PART} ${DIM}|${RESET} ⏱️  ${MINS}m ${SECS}s"