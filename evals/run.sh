#!/bin/bash
# Runs the skill trigger evals. `claude plugin eval` runs in isolation, where
# our declared dependencies (ponytail, typesafe) aren't installed, and a plugin
# with missing dependencies silently doesn't load. So it evaluates a temp copy
# of this plugin without the `dependencies` field.
# Extra args go to `claude plugin eval`, e.g. --case rust-tests --runs 1
set -eo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/eetc"
cp -R "$root"/{.claude-plugin,agents,hooks,skills,evals} "$tmp/eetc/"
rm -rf "$tmp/eetc/evals/results"
jq 'del(.dependencies)' "$root/.claude-plugin/plugin.json" >"$tmp/eetc/.claude-plugin/plugin.json"

# --ablation none: Skill graders only count toward the score without the
# no-plugin baseline arm. --trust-plugin: the copy is this repo's own code.
claude plugin eval "$tmp/eetc" --ablation none --trust-plugin \
  --output-dir "$root/evals/results/$(date +%Y%m%d-%H%M%S)" "$@"
