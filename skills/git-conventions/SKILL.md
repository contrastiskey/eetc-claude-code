---
name: git-conventions
description: >
  Git commit message conventions, PR title and description format, and
  branch naming.
  TRIGGER when: writing a commit message, running git commit, creating a PR
  or PR title, naming a branch, or reviewing/suggesting a commit message —
  including small or fixup commits.
  DO NOT TRIGGER when: only reading git history or diffs.
---

# Git Conventions

Whether to commit on the default branch or on a branch + PR is set per repo in
its CLAUDE.md. When it says nothing, only create a branch or PR when the user
asks.

## Commit Messages

Format: `<type>(<scope>): <description>`

- **scope** is optional. Use it when the change is clearly scoped to one area
  (a module, layer, or subsystem). Omit it for cross-cutting changes.
- **description**: lowercase, imperative mood, no trailing period. Think "what
  does this commit do?", not "what did I do?".
- Keep the subject line under 72 characters
- Add a body (blank line after subject) only when the *why* isn't obvious from
  the code or docs

### Types

| Type | When to use |
|------|-------------|
| `feat` | new behaviour: feature, endpoint, strategy, class, config option |
| `fix` | bug fix |
| `refactor` | code restructure with no behaviour change |
| `test` | adding or updating tests only |
| `docs` | documentation, ADRs, comments only |
| `chore` | build, deps, CI, config, tooling — nothing that ships |
| `perf` | performance improvement |

When in doubt between `feat` and `refactor`: if it changes *what* the system
does, it's `feat`; if it only changes *how*, it's `refactor`.

### Examples

```
feat: add price history endpoint
feat(orders): add bracket order support
fix(parser): handle empty input without raising
refactor: extract commission calculation into helper
test: add tests for position size calculator
docs: add ADR-002 for retry strategy
chore: bump pandas to 2.2.3
```

### With body (when context is needed)

```
fix: correct P&L calculation for partial fills

Partial fills arrive as separate rows with the same order ID. The
matcher treated them as independent orders, doubling the commission.
Now groups by order ID before matching.
```

### What to avoid

- Vague subjects: `fix bug`, `update code`, `changes`, `WIP`
- Past tense: `added`, `fixed`, `updated`
- Capitalised first word after the colon
- Trailing period on the subject line
- Multiple unrelated changes in one commit — split them

## Pull Request Titles

Same format as commit messages: `<type>(<scope>): <description>`

## Branch Naming

```
<type>/<short-description>
```

```
feat/price-history-endpoint
fix/trade-matcher-partial-fills
refactor/order-fetching-service
```

## PR Description Template

```markdown
## What
<one sentence: what does this PR do>

## Why
<one sentence: why is this change needed>

## Changes
- <key change 1>
- <key change 2>
```

Keep it short. If the PR title + diff are self-explanatory, a one-liner suffices.
