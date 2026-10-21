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
| hook | `hooks/filter-test-output.sh` | trims `pytest`, `python manage.py test`, `mvn test` / `mvn verify` and `cargo test` / `cargo nextest run` output to failures and the summary |
| hook | `hooks/format-on-edit.sh` | formats each file Claude edits with the project's configured formatter: `ruff format` (`[tool.ruff]` / `ruff.toml`), `rustfmt` (Cargo projects), `google-java-format` (when the build file configures it, AOSP detected) |
| hook | `hooks/trim-output.sh` | shrinks what Claude sees from *successful* noisy commands: installs (`pip`, `uv`, `poetry`, `npm`, `pnpm`, `yarn`) and `docker build` keep their first/last lines plus warnings and summaries; `cargo build/check/clippy/doc` drop crate progress lines; `mvn` lifecycle builds keep only warnings, errors and the summary; git diffs/logs replace each lockfile's diff with one line |

The trim hook runs after the command (`PostToolUse`), so commands run
unchanged under the normal permission rules. Failed commands aren't trimmed,
so errors always reach Claude in full. It only trims a single command
(optionally after `cd <dir> &&`), never a chain like `uv sync && pytest`, and
it leaves a lockfile diff alone when the command names the lockfile.

The format hook never reformats a project that isn't already set up for that
formatter, and it skips silently when the formatter isn't installed (it checks
`.venv/bin` first, then `PATH`).

The test hook auto-approves the commands it rewrites, so it fails closed. It
only touches a *plain* test command, optionally prefixed with
`source .venv/bin/activate &&` / `uv run` / `poetry run`, whose every argument
is on its allowlist: known side-effect-free flags (e.g. `-q`, `-x`, `-k EXPR`,
`--lf`, `-p <crate>`, `-pl <module>`, `-Dtest=...`) and test paths inside the
project. Maven must run only `test` and/or `verify`: no other phase (`clean`,
`package`, `install`, `deploy`...), no `plugin:goal`, no `-P` profile. Anything
else (chained, substituted, redirected, an unknown flag such as
`--basetemp` or `--config`, an absolute or `..` path) passes through unchanged
to the normal permission flow. Your deny and ask rules still apply to the
commands it approves.

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

The generated `.claude/settings.json` turns on Claude Code's sandbox: every
Bash command runs with no read access to `.env*`, `secrets/` or `~/.ssh` /
`~/.aws`-style credentials, writes only inside the project, and network access
only to package registries and GitHub (other hosts prompt). Permission rules
still decide what runs without asking: read-only commands and `git add` /
`git commit`, plus the stack's build/test subcommands. `git push`, `reset`,
`rebase`, `clean`, `checkout`, `find`, `sed`, `awk` and anything else prompt.
On Linux the sandbox needs `bubblewrap` and `socat`.

It also installs `.claude/statusline.sh` (model, branch, context bar, cost or
tokens, 5-hour usage with its reset time). It works on macOS and Linux and
needs `jq`.

## Install

Per project — commit this to the project's `.claude/settings.json` so everyone
who trusts the repo is prompted to install it:

```json
{
  "extraKnownMarketplaces": {
    "eetc-claude-code": {
      "source": { "source": "github", "repo": "contrastiskey/eetc-claude-code" }
    },
    "ponytail": {
      "source": { "source": "github", "repo": "DietrichGebert/ponytail" }
    },
    "typesafe-ai": {
      "source": { "source": "github", "repo": "typesafe-ai/skills" }
    }
  },
  "enabledPlugins": { "eetc@eetc-claude-code": true }
}
```

Or manually, inside Claude Code:

```
/plugin marketplace add DietrichGebert/ponytail
/plugin marketplace add typesafe-ai/skills
/plugin marketplace add contrastiskey/eetc-claude-code
/plugin install eetc@eetc-claude-code
```

`eetc` depends on `ponytail@ponytail` and `typesafe@typesafe-ai`; installing it
installs and enables both. Disabling either one disables `eetc`.

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

Hook tests (Python 3 stdlib, plus `bash` and `jq` like the hooks themselves):

```bash
python3 tests/test_hooks.py
```

They feed JSON to each hook and check what it prints: which test commands the
test hook rewrites and approves (and which must pass through), what the trim
hook cuts or leaves alone, and that the format hook is a no-op without a
formatter config. Run them after every hook change.
