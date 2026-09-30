# eetc-claude-code

Shared Claude Code config for EETC projects, packaged as the `eetc` plugin.
This repo is also its own marketplace (`eetc-claude-code`).

## Contents

| Component | Name | Applies to |
|-----------|------|------------|
| skill | `eetc:git-conventions` | every repo |
| skill | `eetc:python-code-style`, `eetc:python-tests` | Python |
| skill | `eetc:fastapi-patterns` | FastAPI projects |
| skill | `eetc:django-patterns` | Django / DRF projects |
| skill | `eetc:java-code-style`, `eetc:java-tests`, `eetc:java-docs` | Java |
| skill | `eetc:rust-code-style`, `eetc:rust-tests` | Rust |
| skill | `/eetc:claude-code-setup` (user-invoked) | any repo: creates or re-standardizes `.claude/settings.json`, `CLAUDE.md` and the `codebase-overview` skill from the templates in `skills/claude-code-setup/templates/` |
| agent | `eetc:code-reviewer` | every repo; loads the matching skills |
| hook | `hooks/filter-test-output.sh` | trims `pytest`, `python manage.py test` and `mvn test/verify` output |

The hook only rewrites (and auto-approves) a *plain* test command, optionally
prefixed with `source .venv/bin/activate &&` / `uv run` / `poetry run`.
Anything chained, substituted or redirected passes through to the normal
permission flow.

Project-specific knowledge (architecture, fixtures, clients to mock, tooling
commands, permissions, statusline) stays in each project's CLAUDE.md,
`codebase-overview` skill and `.claude/settings.json`. Plugins can't ship
permissions or a statusline.

## Set up a new project

Run `/eetc:claude-code-setup` in the project (optionally with notes, e.g.
`/eetc:claude-code-setup branching: commit on master`). It detects the stack,
explores the codebase, proposes the files and waits for your OK, then writes
them. It never reads secrets files and never commits. To try it before the
plugin is enabled in that repo, start the session with
`claude --plugin-dir ~/IdeaProjects/eetc-claude-code`.

## Install

Per project — commit this to the project's `.claude/settings.json` so everyone
who trusts the repo is prompted to install it:

```json
{
  "extraKnownMarketplaces": {
    "eetc-claude-code": {
      "source": { "source": "github", "repo": "contrastiskey/eetc-claude-code" }
    }
  },
  "enabledPlugins": { "eetc@eetc-claude-code": true }
}
```

Or manually, inside Claude Code:

```
/plugin marketplace add contrastiskey/eetc-claude-code
/plugin install eetc@eetc-claude-code
```

## Update

1. Change skills/agents/hooks here, bump `version` in `.claude-plugin/plugin.json`.
2. Commit and push to `master`.
3. In Claude Code: `/plugin marketplace update eetc-claude-code`, then restart
   (or run `claude plugin update eetc@eetc-claude-code`).

## Local testing

```bash
claude plugin validate .
cd ~/PycharmProjects/eetc_data_hub
claude --plugin-dir ~/IdeaProjects/eetc-claude-code   # eetc:* skills appear next to the project's own
```

Hook check:

```bash
echo '{"tool_input":{"command":"pytest -q"}}' | bash hooks/filter-test-output.sh
echo '{"tool_input":{"command":"pytest; rm x"}}' | bash hooks/filter-test-output.sh   # {}
```
