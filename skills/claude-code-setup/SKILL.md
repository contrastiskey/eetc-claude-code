---
name: claude-code-setup
description: >
  Set up or re-standardize a project's Claude Code config: .claude/settings.json,
  CLAUDE.md and the codebase-overview skill, in the standard EETC format, with
  the eetc plugin enabled. Detects the stack, fills contents from the actual
  codebase, and migrates legacy per-repo copies of eetc skills.
disable-model-invocation: true
argument-hint: "[notes for the config, e.g. 'branching: commit on master']"
---

# Claude Code Setup

Set up the current project's Claude Code config in the standard EETC format.
Works on a project with no config and on one with existing config. An existing
setup is only restructured after the user has been warned and has explicitly
agreed (Step 4b), and every project fact is preserved.

User notes for the generated config: $ARGUMENTS

These notes describe what the config should say (e.g. the branching policy to
write into CLAUDE.md). They are never instructions to commit, push or run
anything.

Templates (read all three before writing anything):

- `${CLAUDE_SKILL_DIR}/templates/settings.json` — base `.claude/settings.json`
- `${CLAUDE_SKILL_DIR}/templates/CLAUDE.md` — CLAUDE.md structure
- `${CLAUDE_SKILL_DIR}/templates/codebase-overview.md` — `.claude/skills/codebase-overview/SKILL.md` structure

## Hard rules

- **Never read secrets.** Do not open `.env*`, `local_settings.py`, anything
  under `secrets/`, `*.pem`, `*.key`, service-account or credentials JSON, or
  any file whose name suggests secrets. Listing their *names* is fine;
  document them in Key Files as "secrets — DO NOT READ".
- Environment variable tables list names and purposes, never values.
- Touch only `CLAUDE.md`, `.claude/` and, when the user asks for a backup,
  `.claude-setup-backup/` in the project. Never touch `~/.claude/`, and never
  `.claude/settings.local.json` (personal).
- **Never alter an existing setup without explicit consent.** Any change to
  an existing `CLAUDE.md` or to anything already under `.claude/` (edit,
  restructure, merge or delete) needs the user's yes from Step 4b. No answer,
  an unclear answer, or a session where you can't ask means no change.
- Don't commit. The user reviews and commits (with `eetc:git-conventions`).
- Writes under `.claude/` ask for the user's approval. If one is denied,
  stop and report; don't route around it with Bash.
- Structure is fixed by the templates; content comes from the codebase. Never
  leave `<placeholder>` text or template comments in the written files — fill
  a section from what you found, or drop an optional section.

## Step 1 — Detect the stack

Check the repo root (and one level down for monorepos):

| Signal | Stack |
|--------|-------|
| `pyproject.toml`, `requirements*.txt`, `setup.py` | Python — package manager from `uv.lock` (uv), `poetry.lock` (poetry), `requirements*.in` (pip-tools), else pip |
| `manage.py`, `django` in deps | Django |
| `fastapi` in deps | FastAPI |
| `pom.xml` / `build.gradle*` | Java (Maven / Gradle) — version from `maven.compiler.release`/`source` or `java.version` |
| `Cargo.toml` | Rust |
| `package.json` | Node / frontend (can coexist with the above) |

Also note: test runner and layout, formatter (black / ruff / Spotless), the
`Makefile` targets, a `.venv/`, deploy manifests (Dockerfile, `cloudbuild.yaml`,
`*.yaml` jobs), and secrets files present (names only).

## Step 2 — Inventory existing config

The project has an **existing setup** if `CLAUDE.md` exists, or `.claude/`
holds anything other than `settings.local.json`. If so, also run
`git status --porcelain -- CLAUDE.md .claude` and `git ls-files -- CLAUDE.md .claude`
(or note that the project isn't a git repo): uncommitted or untracked config
can't be restored with git after it's changed.

Read `CLAUDE.md`, `.claude/settings.json`, `.claude/skills/*`,
`.claude/agents/*`, `.claude/commands/*`, `.claude/hooks/*` and any
`.claude/*.sh`. Classify each item:

- **Superseded by the eetc plugin** — per-repo copies of `code-style`,
  `tests`, `git-conventions`, `fastapi-patterns`, `django-patterns`,
  `java-docs`, `simplify`, a `code-reviewer` agent, a test-output filter hook
  (`filter-test-output.sh` + its `PreToolUse` entry). Propose deleting them;
  anything project-specific inside (class names, fixtures, fakes, clients to
  mock, framework specifics, run commands) moves into `codebase-overview`.
- **Keep** — other project skills (e.g. `implement-research-paper`),
  `statusLine`, `model`, `effortLevel`, other plugins/marketplaces, existing
  permissions.
- **Stale** — references to files, classes or skills that no longer exist.
  Verify with grep before calling something stale; fix or drop it.

## Step 3 — Explore the codebase

Read-only. Gather what the templates need: entry points, layers and their
directories, main data flows, external clients, env var *names* (from settings
modules, `Settings` classes, deploy manifests — not from `.env` files),
deployment, the common "add a new X" path, test layout / fixtures / fakes /
what gets mocked, and the everyday commands (Makefile, README). For a large
repo, use an Explore subagent. Prefer what the code says over what the README
says; note disagreements.

## Step 4 — Propose, then wait

### 4a. Proposal

Show the user:

1. Detected stack.
2. Files to create / change / delete, one line each.
3. The permissions to add (below) and the numbered CLAUDE.md rules.
4. Anything ambiguous: branching policy (commit on `master` vs branch + PR —
   honour `$ARGUMENTS`), extra project rules to keep, stale items.

With no existing setup, confirm the proposal with AskUserQuestion and continue
to Step 5 only on a yes.

### 4b. Existing setup: warn and get consent

When Step 2 found an existing setup, start with a clearly marked warning, e.g.
**⚠️ This project already has a Claude Code setup. Matching it to the EETC
standard will change the files below.** Then, for every existing file:

| File | What happens | What is kept |
|------|--------------|--------------|
| `CLAUDE.md` | restructured into the standard sections | every rule, key file and command (rules the template lacks become extra numbered rules; architecture moves to `codebase-overview`) |
| `.claude/settings.json` | merged | every existing key, permission, hook, plugin and marketplace; only superseded hook entries are removed |
| `.claude/skills/codebase-overview/SKILL.md` | reordered into the standard sections | all content, plus leftovers from deleted skills |
| superseded skills / agent / hook script | **deleted** | their project-specific content, moved into `codebase-overview` |

List deletions separately and by path — they are the destructive part. Add a
second warning when git can't restore the originals: files with uncommitted
changes or untracked, or a project that isn't a git repo. Suggest committing
or stashing first, and offer to copy the originals to
`.claude-setup-backup/` before writing.

Then ask with AskUserQuestion:

- **Apply all changes** — everything listed.
- **Choose per file** — then ask once per existing file (apply / leave as is);
  ask about each deletion individually.
- **Only add what's missing** — create files that don't exist yet; leave every
  existing file exactly as it is.
- **Cancel** — change nothing.

Only an explicit choice counts. If AskUserQuestion isn't available (e.g. a
headless run), print the proposal and warnings, make no changes to existing
files, and stop.

## Step 5 — Write

Write only what the user agreed to in Step 4. With **Only add what's missing**,
skip every file below that already exists. Make the backup first if the user
asked for one.

### `.claude/settings.json`

Start from the template. When the file exists, **merge**: keep every existing
key and permission, add missing template entries, and add the `eetc-claude-code`
marketplace and `eetc@eetc-claude-code` plugin next to any existing ones.
Remove only superseded hook entries. Then add stack permissions:

| Stack | Add to `allow` |
|-------|----------------|
| Python | `Bash(pytest *)`, `Bash(pytest)`, `Bash(python -m pytest *)`, plus the package manager: `Bash(uv *)` / `Bash(poetry *)` / `Bash(pip *)` + `Bash(pip-compile *)` |
| Django | `Bash(python manage.py test *)`, `Bash(python manage.py test)`, `Bash(python manage.py makemigrations *)` |
| Maven / Gradle | `Bash(mvn *)` / `Bash(./gradlew *)`, `Bash(java *)` |
| Rust | `Bash(cargo *)` |
| Makefile | `Bash(make <target>)` for each local-only target (format, test, coverage, install, run). **Never** deploy, publish, release or anything touching production |

| Secrets present | Add to `deny` |
|-----------------|---------------|
| `local_settings.py` | `Read(./local_settings.py)`, `Edit(./local_settings.py)` |
| other secrets files | `Read(./<path>)` and `Edit(./<path>)` |

Validate with `jq . .claude/settings.json`.

### `CLAUDE.md`

Follow the template's section order exactly: title line, project summary,
`## MANDATORY WORKFLOW RULES` (numbered, only the rules that apply to this
stack, renumbered consecutively), `## Key Files`, `## Project-Specific
Commands`. Existing project facts are preserved: rules the template doesn't
cover become extra numbered rules; architecture detail moves to
`codebase-overview` instead of staying in CLAUDE.md. Replace skill paths like
`.claude/skills/code-style/SKILL.md` with namespaced names (`eetc:python-code-style`).
Python commands in the file are prefixed with `source .venv/bin/activate &&`
when the repo has a `.venv`.

### `.claude/skills/codebase-overview/SKILL.md`

Follow the template's section order. Required sections: Architecture (with
Layers), Data Flow, External Dependencies, Environment & Configuration,
Testing, Review Checklist. Optional (omit if empty): project-specific
sections, Deployment, Adding a New <Thing>. When the skill exists, restructure
it into this order without dropping content, and merge in the project-specific
leftovers from superseded skills (Step 2).

## Step 6 — Verify and report

- `jq . .claude/settings.json` succeeds.
- `grep -rn '<[A-Za-z]' CLAUDE.md .claude/skills/codebase-overview/SKILL.md`
  shows no leftover template placeholders (real generics like `List<String>`
  are fine).
- Every `eetc:*` skill named in CLAUDE.md exists in the plugin
  (`python-code-style`, `python-tests`, `java-code-style`, `java-docs`,
  `java-tests`, `rust-code-style`, `rust-tests`, `fastapi-patterns`,
  `django-patterns`, `git-conventions`).
- No secrets file was read, and no value from one appears in any written file.

Finish with a short summary: files created / changed / deleted, existing
files left as they were at the user's choice, the backup location if one was
made, and that a new
session is needed for the settings and skills to load (the user is prompted to
install the eetc plugin on first trust of the repo).
