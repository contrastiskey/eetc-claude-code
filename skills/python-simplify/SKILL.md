---
name: python-simplify
description: >
  Post-write review of Python code for over-engineering: YAGNI, premature
  abstraction, unnecessary indirection, reinvented stdlib, dead code and
  complexity red flags.
  TRIGGER when: after writing or modifying Python code, or asked to
  "simplify", "reduce bloat", or "is this too complex?" about Python code.
  DO NOT TRIGGER when: working in a non-Python language.
---

# Python Simplify

Run this review after writing code. For each item below, ask: "does the code I just wrote do this?" If yes, simplify before moving on.

## The core question

> Could a new team member understand this code in under 60 seconds without asking questions?

If no, it needs simplifying — not more comments.

## YAGNI — You Ain't Gonna Need It

Delete anything that exists for a hypothetical future requirement:

- Plugin systems, registries, or factories when there is exactly one implementation.
- Configuration knobs that have one valid value right now.
- Abstract base classes (`ABC`, `Protocol`) with one implementation.
- `**kwargs` pass-throughs "for flexibility" that no caller uses.
- Extension points ("we might want to swap this out later") with no concrete swap planned.

The test: **is there a current, concrete use case for this?** If not, delete it. Adding it later takes minutes; carrying it forever wastes everyone's time.

## Premature abstraction

An abstraction earns its existence when it removes real duplication or hides a real complexity boundary. Red flags:

- A helper function called exactly once — inline it, unless its name communicates *why* something is done in a way the body does not make obvious. When in doubt, inline.
- A helper whose name is longer or harder to parse than the one-line expression it wraps (`is_not_none(x)` instead of `x is not None`, `is_empty(df)` instead of `df.empty`).
- A wrapper class that adds no behaviour, only delegation:
  ```python
  # unnecessary — just use requests.Session directly
  class HttpClient:
      def __init__(self):
          self._session = requests.Session()

      def get(self, url: str, **kwargs) -> Response:
          return self._session.get(url, **kwargs)
  ```
- A `Manager`, `Handler`, `Processor`, `Helper`, or `Utils` class that is really just a bag of loosely related functions — use module-level functions, split by cohesion.

## Python-specific bloat

- **A class with one method** (or only `__init__` plus one method) — make it a function. Pass state as arguments.
- **Hand-written data classes** with `__init__`, `__repr__`, `__eq__` — use `@dataclass` or `NamedTuple`.
- **Trivial getters/setters** — use plain attributes; reach for `@property` only when access needs logic.
- **Reinvented stdlib** — `itertools` (`chain`, `groupby`, `pairwise`, `batched`), `collections` (`Counter`, `defaultdict`, `deque`), `functools.cache`, `pathlib`, `statistics`. For DataFrames, prefer vectorized pandas/numpy ops over row loops and `apply`.
- **Nested comprehensions** deeper than two levels, or with side effects — write a loop.
- **`try/except` that re-raises unchanged** or wraps without adding context — delete it and let the exception propagate:
  ```python
  # unnecessary
  try:
      df = fetch(symbol)
  except requests.HTTPError as e:
      raise e
  ```
- **`isinstance` chains** — use a dict dispatch or `match` (3.10+).
- **Mutable default arguments** (`def f(items=[])`) — a bug, not just bloat; use `None` and create inside.
- **`Optional` parameters that are never `None`** at any call site — tighten the type and drop the `None` handling.

## Unnecessary indirection

Every layer of indirection must justify itself. Remove a layer if:

- It adds no logic — it only passes calls through.
- The only reason it exists is "separation of concerns" with no actual concern being separated.
- Tracing a single operation requires jumping through more than three modules.

Flat is better than nested. A 40-line module is better than four 10-line classes wired together.

## Dead code

Delete it. Do not comment it out. If it matters, git history has it.

- Unused functions, classes, imports, parameters and variables.
- Code behind a condition that is always true or always false.
- `TODO`s and `FIXME`s that describe work outside the current task — file an issue instead.
- Overrides that only call `super()` with the same arguments.

## Complexity red flags

| Pattern | Question to ask |
|---------|----------------|
| Class with >5 injected dependencies | Is this class doing too many things? |
| Function longer than ~30 lines | Can it be split into named steps? |
| Nesting deeper than 3 levels | Can early returns or extracted functions flatten this? |
| More than 2 levels of inheritance | Can composition replace inheritance here? |
| Module-level mutable state | Is this actually global state? Does it need to be? |
| More than one responsibility per class | Split it. |

## What to avoid

- Defending complexity with "it's more flexible" — flexibility has a maintenance cost; charge it only when the flexibility is needed now.
- Defending indirection with "it's more testable" — `unittest.mock.patch` and small fakes test concrete classes fine.
- Adding abstractions "to follow patterns" — patterns are solutions to problems; apply them when you have the problem, not before.
- Leaving complexity in place because it was hard to write — difficulty writing it is a symptom, not a reason to keep it.
