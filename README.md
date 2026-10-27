# eetc-claude-code

Shared Claude Code config for EETC projects, packaged as the `eetc` plugin.
This repo is also its own marketplace (`eetc-claude-code`).

## Summary

**The ultimate bootstrap, bang-for-your-buck Claude Code setup.** One install
and one command give any project a safe, consistent setup that cuts token usage
without cutting code quality. Claude writes simple code to the same high
standards in every repo, reads only what matters, and spends your budget on the
work instead of on noise.

- **Fewer tokens, same quality.** Test runs are cut to failures and the
  summary; installs, builds and lockfile diffs to the lines that matter.
  Skills load only when a task needs them and review agents run on Sonnet.
  Errors still reach Claude in full, and the style skills, formatter and
  conventions keep the code to standard.
- **Simple code, no over-engineering.** The bundled `ponytail` plugin pushes
  Claude to the simplest solution that works: reuse what's there, standard
  library before new dependencies, no speculative abstractions. Less code to
  review and maintain, and fewer tokens spent writing it.
- **A map of the codebase.** Setup writes a `codebase-overview` skill with the
  architecture, data flows, external services and conventions, so Claude reads
  one file instead of re-exploring dozens.
- **Same standards everywhere.** Industry-standard style for Python, Java, Rust,
  Go and TypeScript (PEP 8, Google style guides, Effective Java, Rust API
  Guidelines, Effective Go), plus FastAPI, Django and git conventions. Change
  them here once and every project gets the update.
- **One-command, safe setup.** `/eetc:claude-code-setup` writes a sandboxed
  `.claude/settings.json`, `CLAUDE.md`, the overview and a status line once you
  approve them. Secrets stay out of reach, and safe commands skip the prompt.
- **Auto-formatting.** Every file Claude edits goes through the project's own
  formatter (`ruff`, `rustfmt`, `google-java-format`, `gofmt`).
- **No context wall.** Before a long session fills its context, Claude offers
  to write a handoff note and carry on in a fresh session.
- **Tested.** Hook tests and skill-trigger evals check that each hook touches
  only what it should and each skill loads only for its language.

## Contents

| Component | Name | Applies to |
|-----------|------|------------|
| skill | `eetc:git-conventions` | every repo |
| skill | `eetc:python-code-style`, `eetc:python-tests` | Python |
| skill | `eetc:fastapi-patterns` | FastAPI projects |
| skill | `eetc:django-patterns` | Django / DRF projects |
| skill | `eetc:java-code-style`, `eetc:java-tests`, `eetc:java-docs` | Java |
| skill | `eetc:rust-code-style`, `eetc:rust-tests` | Rust |
| skill | `eetc:go-code-style`, `eetc:go-tests` | Go |
| skill | `eetc:typescript-code-style` | TypeScript / JavaScript |
| skill | `/eetc:claude-code-setup` (user-invoked) | any repo: creates or re-standardizes `.claude/settings.json`, `CLAUDE.md` and the `codebase-overview` skill from the templates in `skills/claude-code-setup/templates/` |
| hook | `hooks/filter-test-output.sh` | trims `pytest`, `python manage.py test`, `mvn test` / `mvn verify` and `cargo test` / `cargo nextest run` output to failures and the summary |
| hook | `hooks/format-on-edit.sh` | formats each file Claude edits with the project's configured formatter: `ruff format` (`[tool.ruff]` / `ruff.toml`), `rustfmt` (Cargo projects), `google-java-format` (when the build file configures it, AOSP detected), `gofmt` (Go modules, except `testdata/` and `vendor/`) |
| hook | `hooks/trim-output.sh` | shrinks what Claude sees from *successful* noisy commands: installs (`pip`, `uv`, `poetry`, `npm`, `pnpm`, `yarn`) and `docker build` keep their first/last lines plus warnings and summaries; `cargo build/check/clippy/doc` drop crate progress lines; `mvn` lifecycle builds keep only warnings, errors and the summary; git diffs/logs replace each lockfile's diff with one line |
| hook | `hooks/review-agents-on-sonnet.sh` | runs `/simplify`'s review agents (reuse, simplification, efficiency, altitude) on Sonnet instead of the session's model; other agents, and calls that already pick a model, are untouched |
| hook | `hooks/context-handoff.sh` | `Stop`: once a session's current context reaches 444,000 tokens, Claude asks whether to write a handoff note and `/clear`, or continue (once per session) |
| hook | `hooks/load-handoff.sh` | `SessionStart` after `/clear`: loads that handoff note into the new session |

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

The handoff hooks keep a long session from running into the limits of a 1M
context window. When the current context reaches 444,000 tokens (an absolute
count, so it only ever fires on 1M-context models), Claude asks you to pick
**Write handoff and clear** or **Continue**. On wrap-up it writes
`.claude/handoff.md` (what is done, next steps, decisions, open questions, key
files) and asks you to run `/clear`; the new session starts with that note,
which is then renamed to `handoff.md.used` so it loads only once. It asks once
per session; on **Continue**, or in a headless run, nothing is written. Set
`EETC_HANDOFF_TOKENS` to change the threshold. Hooks don't receive context
usage, so the project's `.claude/statusline.sh` writes it to
`${TMPDIR:-/tmp}/claude-ctx-<session_id>`: without the current status line
the hook never fires. Projects set up before plugin 0.11.0 need
`/eetc:claude-code-setup` re-run to get it. The status line refreshes on its
own schedule, so the question can come one turn late.

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
tokens, 5-hour usage with its reset time), which also feeds the handoff
hook, and adds `.claude/handoff.md*` to `.gitignore`. It works on macOS and
Linux and needs `jq`. Status lines are copied per project, so re-run
`/eetc:claude-code-setup` in existing projects to pick up template changes.

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

1. Change skills/hooks here, bump `version` in `.claude-plugin/plugin.json`.
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
hook cuts or leaves alone, that the format hook is a no-op without a
formatter config, and when the handoff hooks ask, stay quiet or load the note. Run them after every hook change.

Skill trigger evals (`evals/`, run with `claude plugin eval`):

```bash
evals/run.sh                                   # all 11 cases × 3 runs
evals/run.sh --case rust-code-style --runs 1   # one case, one run
```

Each language skill has a case that must load it and must not load the other
languages' skills (e.g. a Rust task never loads `python-code-style`). Another
case, an unrelated question, must load no eetc skill. Every run is a real
Claude session on your account: one case-run costs about $0.05 to $0.20, so a
full run is roughly $2 to $7. The script evaluates a temp copy of the plugin
without `dependencies`, because the isolated eval session can't install
ponytail or typesafe and would silently skip the plugin. Reports go to
`evals/results/` (git-ignored).
