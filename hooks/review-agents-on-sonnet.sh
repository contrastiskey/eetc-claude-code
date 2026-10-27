#!/bin/bash
# PreToolUse (Agent): runs /simplify's review agents (reuse, simplification,
# efficiency, altitude) on Sonnet instead of inheriting the session's model.
# Leaves every other agent, and any call that already picks a model, alone.
in=$(cat)
jq -c 'select(.tool_input.model == null)
  | select(.tool_input.description // "" | test("(reuse|simplif|efficiency|altitude).*review|review.*(reuse|simplif|efficiency|altitude)"; "i"))
  | {hookSpecificOutput: {hookEventName: "PreToolUse", updatedInput: (.tool_input + {model: "sonnet"})}}' <<<"$in"
