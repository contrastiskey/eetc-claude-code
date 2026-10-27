---
name: python-code-style
description: >
  Python coding conventions that follow established industry standards:
  PEP 8, PEP 257, the Google Python Style Guide, and the Python typing team's
  best practices. Covers tooling, imports, naming, language features,
  exceptions, resources, strings, logging, type annotations, docstrings and
  comments.
  TRIGGER when: writing, editing, or generating any Python code.
  DO NOT TRIGGER when: only reading or analyzing code without making changes,
  or working in a non-Python language.
user-invocable: false
---

# Python Code Style

Sources. Earlier ones win a disagreement:

1. [PEP 8](https://peps.python.org/pep-0008/) and
   [PEP 257](https://peps.python.org/pep-0257/): Python's own style and
   docstring conventions.
2. [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html).
3. [Typing best practices](https://typing.python.org/en/latest/reference/best_practices.html)
   from the Python typing team.

Framework rules live in `eetc:fastapi-patterns` / `eetc:django-patterns`.
Project-specific commands live in the repo's CLAUDE.md.

## Tooling

- The repo's linter (ruff, pylint, flake8) and type checker (mypy, pyright,
  pyrefly) pass. Never loosen their config to get a change through.
- A suppression is line-level, names the rule, and says why when the rule
  name doesn't:
  `x = lookup()  # type: ignore[no-untyped-call]  # vendored, no stubs`.
- The formatter (ruff format, black, pyink) owns line length, quotes,
  wrapping and trailing commas. Run it on the files you touch and don't
  hand-format against it. With no formatter: 4-space indents, 80 columns,
  one quote character per file, and no backslash line continuations (wrap
  inside parentheses instead).
- Check `requires-python` in `pyproject.toml` before using newer syntax:

  | Feature | Python |
  |---------|--------|
  | `list[int]`, `dict[str, int]` in annotations | 3.9 |
  | `X \| None`, `match` | 3.10 |
  | `typing.Self`, `except*` | 3.11 |
  | `typing.override`, `type Alias = ...`, `def f[T](...)` | 3.12 |

  `from __future__ import annotations` lets annotations use newer syntax on
  older versions, but not for libraries that evaluate annotations at runtime
  (Pydantic, FastAPI, attrs converters). There the running Python must
  support the syntax.

### Consistency

- A question this skill doesn't settle: do what the surrounding code does.
- Within a file, keep one choice: quote character, docstring format,
  docstring mood. A package that documents in Sphinx (`:param x:`) or NumPy
  style keeps it; new packages use the Google format below.
- Consistency doesn't justify old style in new code (`Optional[X]`,
  `typing.List`). New code uses the current forms.
- Leave unrelated code alone, and keep style-only changes out of feature
  commits.

## Imports

- At the top of the file, after the module docstring. Groups in this order,
  separated by a blank line, each sorted alphabetically by module path:
  `__future__`, standard library, third party, then the project's own
  packages.
- Absolute imports with the full package path
  (`from myproject.billing import invoices`), not relative ones.
- One module per `import` line: `import os` and `import sys`, never
  `import os, sys`. `from x import a, b` is fine.
- No wildcard imports (`from x import *`).
- Import the module when a bare name wouldn't say where it comes from:
  `json.loads(...)`, not `loads(...)`. Importing classes directly is fine
  (`from pathlib import Path`). Names from `typing` and `collections.abc` are
  always imported directly.
- `import x as y` only for a standard abbreviation (`import numpy as np`,
  `import pandas as pd`) or to resolve a collision.
- `if TYPE_CHECKING:` imports only for names needed solely in annotations,
  to break an import cycle or avoid a costly runtime import. Prefer
  restructuring the modules.

## Naming

| Kind | Public | Internal |
|------|--------|----------|
| Package, module | `lower_with_under` | `_lower_with_under` |
| Class, exception | `CapWords` | `_CapWords` |
| Function, method | `lower_with_under()` | `_lower_with_under()` |
| Variable, parameter, attribute | `lower_with_under` | `_lower_with_under` |
| Module or class constant | `CAPS_WITH_UNDER` | `_CAPS_WITH_UNDER` |
| Type alias | `CapWords` | `_CapWords` |

- Module files are `.py`, with no dashes in the name.
- Acronyms in `CapWords` keep all capitals: `HTTPServerError`, not
  `HttpServerError` (PEP 8).
- Exceptions end in `Error` when they signal errors, without repeating the
  module name (`billing.InvoiceError`, not `billing.BillingInvoiceError`).
- One leading `_` marks internal names. Avoid `__name` mangling.
- Descriptive names in proportion to their scope. Single letters only for
  loop counters (`i`, `j`), `e` for a caught exception, `f` for a file in a
  `with`, and established math notation (cite the source). No abbreviations
  that drop letters, and no type in the name (`id_to_name_dict`).
- `TypeVar`s: `_T` / `_P` only when private and unconstrained, otherwise
  descriptive (`AddableType = TypeVar('AddableType', int, float, str)`).
- An argument a signature requires but the body doesn't use:
  `del unused_arg  # Unused.` at the top of the body.

## Language features

### Truth tests and comparisons

- `x is None` / `x is not None`, never `== None`. Write `if x is not None:`
  when `0`, `''` or `[]` are valid values.
- Empty sequences are false: `if not users:`, not `if len(users) == 0:`.
- Never compare booleans to `True` / `False`, with `==` or `is`.
- Compare a value known to be an integer explicitly (`if count == 0:`), so
  a `None` isn't mistaken for zero.
- `x is not y`, not `not x is y`. `isinstance(x, int)`, not
  `type(x) == int`. `s.startswith('a')` / `s.endswith('z')`, not slicing.
- A NumPy array has no truth value; test `arr.size`.

### Functions

- No mutable or import-time-evaluated defaults:

  ```python
  def add_tags(item: Item, tags: Sequence[str] = ()) -> None: ...

  def schedule(job: Job, at: datetime.datetime | None = None) -> None:
      if at is None:
          at = datetime.datetime.now(tz=datetime.timezone.utc)
  ```

  Not `tags: list[str] = []` or `at=datetime.datetime.now()`.
- Returns are consistent: if any `return` gives a value, every exit does,
  with an explicit `return None`.
- `def`, never `name = lambda ...`. Lambdas only for one-line expressions.
  `operator.mul` over `lambda x, y: x * y`, and a comprehension over
  `map` / `filter` with a lambda.
- Prefer small, focused functions. Past about 40 lines, look for a split.
- Nest a function only to close over a local value. To hide a helper, make
  it a module-level `_private` function, so tests can still reach it.
- No `@staticmethod`; write a module-level function. `@classmethod` only for
  named constructors (`User.from_row(row)`).
- Decorators only with a clear payoff. A decorator does no I/O when applied,
  since that happens at import time.

### Comprehensions and iteration

- Comprehensions and generator expressions for simple cases: one `for`, at
  most one `if`. Anything more is a loop.
- Use the default iterators and operators: `for key in mapping`,
  `for key, value in mapping.items()`, `for line in file`, `if x in items`.
  Not `.keys()` or `.readlines()`.
- Never mutate a container while iterating over it.
- Conditional expressions only when the condition and both branches each
  fit on one line.

### Classes and state

- Properties only for cheap, unsurprising computed access. No property that
  just gets and sets a private attribute; make the attribute public.
  Explicit `get_foo()` / `set_foo()` methods only when access is costly or
  has side effects.
- Implementing ordering: define all six comparisons, or use
  `functools.total_ordering`.
- Avoid power features: custom metaclasses, `__del__`, bytecode access,
  import hooks, reflection tricks. Standard library classes built on them
  (`dataclasses`, `enum`, `abc`) are fine.
- Avoid mutable global state. If it's truly needed, keep it `_private` at
  module level, expose it through functions, and say why in a comment.
  Module-level constants are encouraged.
- Threads: don't rely on built-in types being atomic. Pass data through
  `queue.Queue`; otherwise use `threading` locks or `threading.Condition`.
- A runnable module keeps its logic in `main()` behind
  `if __name__ == '__main__':`. Importing a module does no work beyond
  definitions.

### Exceptions

- Raise built-in exceptions where they fit (`ValueError` for a bad
  argument, `TypeError`, `KeyError`). Custom exceptions inherit from
  `Exception`, never `BaseException`. Shape the hierarchy around what
  callers need to tell apart.
- Never `assert` to validate input or control flow; `python -O` strips
  asserts. Asserts are for tests and for internal invariants the code
  doesn't depend on.
- Never a bare `except:`. Catch `Exception` only to re-raise, or at an
  isolation boundary (a thread's top level, a request handler) that logs
  it.
- Catch the specific exception, around the smallest possible `try` body.
  Put the success path in `else:`:

  ```python
  try:
      value = cache[key]
  except KeyError:
      return load(key)
  else:
      return render(value)
  ```

- Translate an exception with `raise NewError(...) from err` so the cause
  stays in the traceback. Use `from None` only after copying the relevant
  details into the new exception.
- No `return`, `break` or `continue` inside `finally`; they discard an
  in-flight exception.
- Error messages match the actual condition, mark interpolated values, and
  stay greppable: `raise ValueError(f'Not a probability: {p=}')`.

### Resources

- `with` for files, sockets, connections and locks. `contextlib.closing()`
  for objects without context-manager support. Never rely on `__del__` or
  garbage collection to clean up.
- A context manager that does more than acquire and release is entered
  through a named method: `with conn.begin_transaction():`, not
  `with conn:`.
- Every network call sets a timeout (`requests` has none by default) and
  checks the status: `response.raise_for_status()`.

### Strings

- Format with f-strings, `%` or `str.format`, not by `+`-joining pieces
  (a single `a + b` is fine). To build a string in a loop, collect parts in
  a list and `''.join()` them.
- Within a file, one quote character; use the other only to avoid escaping.
  Multi-line strings use `"""`; `textwrap.dedent()` keeps indented literals
  clean.
- No string literal that relies on trailing whitespace.

### Logging

- One module-level logger: `logger = logging.getLogger(__name__)`. Use
  logging, not `print`, for diagnostics.
- Pass a constant pattern with `%` placeholders and the values as arguments,
  never an f-string, so disabled levels cost nothing and the pattern stays
  searchable:

  ```python
  logger.info('Loaded %d rows from %s', count, path)
  ```

- Inside `except`, `logger.exception(...)` records the traceback.

## Type annotations

- Annotate every function signature in new or changed code, public APIs
  first. Skip `self`, `cls` and `__init__`'s `-> None`.
- `X | None`, not `Optional[X]` or `Union[X, None]`, with `None` last. Never
  an implicit optional: `name: str = None` is `name: str | None = None`.
- Built-in generics (`list[int]`, `dict[str, int]`, `tuple[int, ...]`,
  `type[User]`). Abstract types come from `collections.abc`
  (`Sequence`, `Mapping`, `Iterable`, `Callable`), never from `typing`
  (`List`, `Dict`, `Iterable`).
- Parameters take abstract types (`Sequence[str]`, `Mapping[str, int]`,
  `Iterable[Row]`); return values are concrete (`list[str]`,
  `dict[str, int]`).
- One return type per function. Never return a union the caller must
  `isinstance()`-check, and never let a flag switch the return type. Write
  two functions instead:

  ```python
  def fetch_rows(table: str) -> pd.DataFrame: ...
  def fetch_rows_as_dicts(table: str) -> list[dict[str, object]]: ...
  ```

- `object` for a parameter that accepts anything and for a callback whose
  return is ignored (`Callable[[int], object]`). `Any` only where the type
  system can't express the type. Always give generics their parameters:
  `Sequence[int]`, not bare `Sequence`.
- `float`, not `int | float`.
- Type aliases are `CapWords` and declared as aliases:
  `Headers: TypeAlias = Mapping[str, str]`, or `type Headers = ...` on 3.12+.
- `Self` for methods that return their own class; `@override` on
  overriding methods (`typing.override` on 3.12+, `typing_extensions`
  before).
- Forward references: `from __future__ import annotations`, or a quoted
  name.
- No `# type: <type>` comments; use annotated assignments
  (`rows: list[Row] = []`).

## Docstrings

- Always `"""`. The summary line sits on the opening line, fits in one line,
  and ends with a period. More detail follows after one blank line.
- Required on every module, every public class, function and method, and on
  any function that is long or not obvious. Not needed on test methods or on
  `@override` methods that don't change the base contract.
- Summary mood: imperative (`"""Return the active users."""`, PEP 257).
  A file that consistently uses the descriptive form (`Returns ...`) keeps
  it. A `@property` reads like an attribute: `"""The table path."""`.
- A docstring says how to call the function and what it does, not how it
  works. Note side effects such as mutating an argument.
- Sections, each with a 4-space hanging indent:
  - `Args:`, one entry per parameter (`*args` and `**kwargs` included), no
    types when the signature is annotated.
  - `Returns:` (`Yields:` for generators), omitted when the summary already
    starts with "Return" and says it all, or when the function returns
    `None`.
  - `Raises:`, the exceptions that are part of the interface. Not the ones
    raised for API misuse.
  - On classes, `Attributes:` for public attributes.

  ```python
  def fetch_rows(
      table: Table,
      keys: Sequence[str],
      require_all_keys: bool = False,
  ) -> dict[str, Row]:
      """Fetch rows by key.

      Args:
          table: An open table handle.
          keys: Keys of the rows to fetch.
          require_all_keys: If true, only return rows that have a value for
              every key.

      Returns:
          A dict mapping each found key to its row. Missing keys are absent.

      Raises:
          TableError: If the table can't be read.
      """
  ```

- A class docstring says what an instance represents, not "Class that ...".
  An exception's docstring says what it represents, not when it's raised.
- A decorated function's docstring describes the behavior after
  decoration.
- No blank line after a function docstring. One blank line after a class
  docstring, before the first method.

## Comments

- Comment why, and anything a reviewer would ask about. Never restate the
  code.
- Comments are sentences: capitalized and punctuated, unless the first word
  is a lowercase identifier. A short inline comment may be less formal.
- Block comments are indented with the code, `# ` followed by text. Inline
  comments sit at least two spaces after the code, and sparingly.
- `TODO` links to an issue, not a person:
  `# TODO(github.com/org/repo/issues/123): Drop once clients send v2.`
  A deferred task names a specific date or event.
