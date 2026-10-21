#!/bin/bash
# Stop hook: once the session's current context reaches EETC_HANDOFF_TOKENS
# (default 444000), asks Claude to offer a handoff note and /clear. Hooks don't
# get context usage, so it reads the count the project's statusline.sh writes.
# Blocks at most once per session, so it can't loop.
sid=$(jq -r '.session_id // ""')
case $sid in '' | *[!A-Za-z0-9_-]*) exit 0 ;; esac

dir=${TMPDIR:-/tmp}
dir=${dir%/}
tokens=$(cat "$dir/claude-ctx-$sid" 2>/dev/null)
[[ $tokens =~ ^[0-9]+$ ]] || tokens=0
limit=${EETC_HANDOFF_TOKENS:-444000}
[[ $limit =~ ^[0-9]+$ ]] || limit=444000
flag="$dir/claude-handoff-asked-$sid"
((tokens >= limit)) && [[ ! -e $flag ]] || exit 0
touch "$flag" || exit 0

note="${CLAUDE_PROJECT_DIR:-.}/.claude/handoff.md"
jq -n --arg reason "The context has reached $tokens tokens. Use AskUserQuestion to ask the user whether to wrap up, with the options \"Write handoff and clear\" and \"Continue\". On \"Write handoff and clear\": write a handoff note to $note covering what is done, next steps, decisions made, open questions and key files, then tell the user to run /clear (the note loads into the new session automatically). On \"Continue\", or if you cannot ask (e.g. a headless run): carry on without writing anything." \
  '{decision: "block", reason: $reason}'
