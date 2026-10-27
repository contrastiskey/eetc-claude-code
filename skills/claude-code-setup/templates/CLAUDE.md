# CLAUDE.md

<Project name>: <one or two sentences — what the project is, what it does,
and who or what uses it.>

<Optional: link to external docs, e.g. API documentation.>

## MANDATORY WORKFLOW RULES

YOU MUST follow these rules without exception:

**1. Plan before acting on complex tasks**
For any non-trivial task involving multiple steps, multiple files, or
architectural decisions: YOU MUST enter Plan Mode first. Load the
`codebase-overview` skill to understand the architecture before exploring
files. Form a plan and confirm the approach before writing any code. Do NOT
jump straight to implementation.

<!-- LANGUAGE RULES: keep the block for the repo's language, delete the rest.
     Python → python-code-style + python-tests. Java → java-code-style +
     java-docs + java-tests. Rust → rust-code-style + rust-tests.
     TypeScript / JavaScript → typescript-code-style. Several languages
     (e.g. a Python API with a TS frontend) → keep each one's blocks,
     numbered in sequence. No eetc skill for the language (e.g. Go) → drop
     these rules. -->

**2. YOU MUST load and apply the python-code-style skill before writing any Python code**
Skill: `eetc:python-code-style`

**3. YOU MUST load and apply the python-tests skill before writing, editing, or generating tests**
Skill: `eetc:python-tests`

**2. YOU MUST load and apply the java-code-style skill before writing or modifying any Java class or method**
Skill: `eetc:java-code-style`

**3. YOU MUST load and apply the java-docs skill before adding or updating Javadoc on any public/protected member, record, sealed type, enum, or package**
Skill: `eetc:java-docs`

**4. YOU MUST load and apply the java-tests skill before writing or modifying any test class**
Skill: `eetc:java-tests`

**2. YOU MUST load and apply the rust-code-style skill before writing or modifying any Rust code**
Skill: `eetc:rust-code-style`

**3. YOU MUST load and apply the rust-tests skill before writing or modifying any Rust test**
Skill: `eetc:rust-tests`

**2. YOU MUST load and apply the typescript-code-style skill before writing or modifying any TypeScript or JavaScript code**
Skill: `eetc:typescript-code-style`

<!-- FRAMEWORK RULE: only for FastAPI or Django projects. -->

**N. YOU MUST load and apply the fastapi-patterns skill before designing or
modifying routers, schemas, dependencies, or services**
Skill: `eetc:fastapi-patterns`

**N. YOU MUST load and apply the django-patterns skill before designing or
modifying models, serializers, views, or services**
Skill: `eetc:django-patterns`

<!-- ALWAYS: the last three rules, renumbered to follow the ones above. -->

**N. YOU MUST run /simplify after changes of 100+ lines and before running tests**
When an implementation adds or changes 100 or more lines in total (check with
`git diff --stat`), invoke the `/simplify` skill to review the changed code
for reuse, quality, and efficiency — and fix any issues found — before
proceeding to run tests. Skip it for smaller changes.

**N. YOU MUST check and update the codebase-overview skill if needed after any major code change**
Once you finish editing code in a way that adds, removes, or reshapes a layer,
module, data flow, external dependency, environment variable, or test setup,
check `.claude/skills/codebase-overview/SKILL.md`. If it now gets
something wrong or leaves something out, update it; if it is still accurate,
leave it as is.

**N. YOU MUST load and apply the git-conventions skill before creating commits or PRs**
Skill: `eetc:git-conventions`
<Optional branching policy, e.g. "Small project — work and commit directly on
`master`. Only branch or open a PR when the user explicitly asks.">

<Optional: further project rules as extra numbered items, e.g. "load the
Stripe skills before touching billing code".>


## Key Files

| File | Purpose |
|------|---------|
| `<path>` | <what it is and why you'd open it> |
| `<secrets file, e.g. .env.local>` | <what it holds> (secrets — DO NOT READ) |

## Project-Specific Commands

```bash
<command>        # <what it does>
```
