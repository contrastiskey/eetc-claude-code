---
name: java-simplify
description: >
  Post-write review of Java code for over-engineering: YAGNI, premature
  abstraction, unnecessary indirection, Optional/stream misuse, dead code and
  complexity red flags.
  TRIGGER when: after writing or modifying Java code, or asked to "simplify",
  "reduce bloat", or "is this too complex?" about Java code.
  DO NOT TRIGGER when: working in a non-Java language.
---

# Java Simplify

Run this review after writing code. For each item below, ask: "does the code I just wrote do this?" If yes, simplify before moving on.

## The core question

> Could a new team member understand this code in under 60 seconds without asking questions?

If no, it needs simplifying — not more comments.

## YAGNI — You Ain't Gonna Need It

Delete anything that exists for a hypothetical future requirement:

- Plugin systems, registries, or factories when there is exactly one implementation.
- Configuration knobs that have one valid value right now.
- Abstract base classes with one subclass.
- Generic type parameters (`<T>`) when the code only ever uses one concrete type.
- Extension points ("we might want to swap this out later") with no concrete swap planned.

The test: **is there a current, concrete use case for this?** If not, delete it. Adding it later takes minutes; carrying it forever wastes everyone's time.

## Premature abstraction

An abstraction earns its existence when it removes real duplication or hides a real complexity boundary. Red flags:

- An interface with one implementation and no test fake — just use the class directly.
- A helper method called exactly once — inline it, unless its name communicates *why* something is done in a way the body does not make obvious (e.g. `validateSessionNotExpired()` as a guard). When in doubt, inline.
- A helper method whose name is longer or harder to parse than the one-line expression it wraps — inline it.
- A helper that exists only to give a name to something the language already expresses clearly (`isNotNull(x)` instead of `x != null`, `isEmpty(list)` instead of `list.isEmpty()`).
- A wrapper class that adds no behaviour, only delegation:
  ```java
  // unnecessary — just use HttpClient directly
  class HttpClientWrapper {
      private final HttpClient delegate;
      void send() { delegate.send(...); }
  }
  ```
- A `Builder` for a class with two or three fields — use a constructor or record.
- A `Manager`, `Handler`, `Processor`, `Helper`, or `Util` class that is really just a bag of loosely related methods — split by cohesion or inline.

## Java-specific bloat

### `Optional` misuse

`Optional` exists for return types where absence is a meaningful outcome. Remove it when:

- Used as a field type — use a nullable field and document the null contract.
- Used as a method parameter — use overloads or a nullable parameter instead.
- Wrapping a value you know is non-null — just return the value.
- Chained into `.map().flatMap().orElse()` when a null check would be shorter and clearer.

### Stream overuse

Prefer a `for` loop when:

- The operation is a single pass with no transformation (e.g. summing, finding first match).
- The stream chain is longer than one line and has no parallelism need.
- The loop body mutates external state — streams and side-effects mix badly.

A three-line `for` loop is not "old-fashioned" — it is often just easier to read.

### Unnecessary checked exception wrapping

Remove exception layers that add no context:

```java
// unnecessary — the caller gains nothing from WrappedException here
try { ... } catch (IOException e) { throw new WrappedException(e); }
```

If you catch and rethrow, add a message. If you have nothing to add, let the exception propagate or convert it once at the boundary.

## Unnecessary indirection

Every layer of indirection must justify itself. Remove a layer if:

- It adds no logic — it only passes calls through.
- The only reason it exists is "separation of concerns" with no actual concern being separated.
- Tracing a single operation requires jumping through more than three classes.

Flat is better than nested. A 40-line class is better than four 10-line classes wired together.

## Dead code

Delete it. Do not comment it out. If it matters, git history has it.

- Unused methods, fields, imports, and parameters.
- Code behind a condition that is always true or always false.
- `TODO`s and `FIXME`s that describe work outside the current task — file an issue instead.
- Overrides that only call `super` with the same arguments.

## Complexity red flags

These patterns are a signal to stop and reconsider the design:

| Pattern | Question to ask |
|---------|----------------|
| Class with >5 dependencies injected | Is this class doing too many things? |
| Method longer than ~30 lines | Can it be split into named steps? |
| Nesting deeper than 3 levels (`if` inside `for` inside `if`) | Can early returns or extracted methods flatten this? |
| More than 2 levels of inheritance | Can composition replace inheritance here? |
| `instanceof` chains or long `switch` on type | Should this be a sealed type with pattern matching? |
| `static` mutable state | Is this actually global state? Does it need to be? |
| More than one responsibility per class | Split it. |

## What simple code looks like

- A record or plain class with a clear name that says what it is.
- Methods that do one thing and are named for that thing.
- No surprises: the implementation matches what the name implies.
- Dependencies passed in explicitly — no hidden global state.
- The shortest path from input to output that is still correct.

## What to avoid

- Defending complexity with "it's more flexible" — flexibility has a maintenance cost; charge it only when the flexibility is needed now.
- Defending indirection with "it's more testable" — if the only reason for an interface is testability, use a package-private class and a real or in-process fake instead.
- Adding abstractions "to follow patterns" — patterns are solutions to problems; apply them when you have the problem, not before.
- Leaving complexity in place because it was hard to write — difficulty writing it is a symptom, not a reason to keep it.