#!/bin/bash
# PreToolUse hook for Bash: trims pytest / Django / Maven test output to
# failures + summary to save context. Only a plain test command is rewritten
# and auto-approved; anything chained, substituted or redirected passes through.
cmd=$(jq -r '.tool_input.command // ""')
safe=$'[^;&|`$<>\n\\\\]*'
venv='(source \.venv/bin/activate && )?'
pytest_re="^${venv}((uv|poetry) run )?(python -m )?pytest${safe}\$"
django_re="^${venv}(poetry run )?python manage\\.py test${safe}\$"
mvn_re="^mvn ${safe}(test|verify)${safe}\$"

if [[ "$cmd" =~ $pytest_re ]]; then
  out=$(mktemp /tmp/claude-test-out.XXXXXX)
  new="$cmd 2>&1 | tee $out | grep -A 20 -E '^(FAILED|ERROR)' | head -200; tail -6 $out"
elif [[ "$cmd" =~ $django_re ]]; then
  out=$(mktemp /tmp/claude-test-out.XXXXXX)
  new="$cmd 2>&1 | tee $out | grep -A 15 -E '^(FAIL|ERROR):' | head -200; tail -4 $out"
elif [[ "$cmd" =~ $mvn_re && "$cmd" != *no-transfer-progress* ]]; then
  new="mvn --no-transfer-progress ${cmd#mvn }"
else
  echo '{}'
  exit 0
fi
jq -n --arg c "$new" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: {command: $c}}}'
