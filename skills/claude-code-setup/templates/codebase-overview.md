---
name: codebase-overview
description: >
  Architecture, data flows, directory structure, and project-specific
  conventions for <repo-name>. Use when exploring the codebase, planning
  a new feature, onboarding to a module, or trying to understand how the
  system fits together — instead of reading multiple files to discover it.
---

# <Project Name> — Codebase Overview

<One paragraph: what the system does end to end, its main inputs and outputs,
and where it runs.>

## Architecture

```
<ASCII diagram of the main flow: entry point → layers → stores / external services>
```

### Layers

| Layer | Location | Responsibility |
|-------|----------|----------------|
| <name> | `<path>` | <what lives here, and what must NOT live here> |

## Data Flow

<One numbered list per main flow (e.g. Ingestion, Retrieval, a scheduled job).>

1. <step>
2. <step>

## External Dependencies

| Client / Service | Source | Purpose |
|------------------|--------|---------|
| `<ClassName>` | `<module or package>` | <what it talks to> |

## <Project-specific sections>

<Optional, in this position: domain concepts that need more than a table row —
e.g. Authentication, Errors, Billing, Database Strategy, Frontend. One `##`
section each. Omit when there are none.>

## Environment & Configuration

| Variable | Purpose |
|----------|---------|
| `<NAME>` | <purpose — never a value> |

To add a new variable: <the repo's steps, e.g. settings class → .env.local →
production env / secret manager>.

## Deployment

| Component | Detail |
|-----------|--------|
| <Platform / Image / Build / Job> | <detail> |

## Adding a New <Thing>

<The repo's most common extension — a domain, endpoint, strategy, data source.>

1. <step>
2. <step>

## Testing

General rules: `eetc:<language>-tests`<; framework patterns:
`eetc:<framework>-patterns`>.

- Layout: <where tests live and how they're organised>
- Fixtures / fakes: <names and what they give you>
- Mock: <every external client this repo must never call from tests>
- Run:

```bash
<run all tests>
<run a single file>
```

## Review Checklist (project-specific)

<Bullets the `eetc:code-reviewer` agent checks in addition to the eetc skills:
architecture rules, invariants, and pitfalls specific to this codebase.>

- <rule>
