#!/bin/bash
# SessionStart hook (after /clear): loads the handoff note context-handoff.sh
# asked for into the new session, then renames it so it loads only once.
note="${CLAUDE_PROJECT_DIR:-.}/.claude/handoff.md"
[[ -f $note ]] || exit 0
echo "Handoff from the previous session:"
cat "$note"
mv -f "$note" "$note.used"
