---
name: java-docs
description: >
  Javadoc conventions: structure, tag order, null contracts, thread-safety
  phrasing, records, sealed types, enums, package-info.java, @apiNote and
  @implNote.
  TRIGGER when: writing or reviewing Javadoc on Java code, or asked to
  "document" / "add javadoc".
  DO NOT TRIGGER when: working in a non-Java language.
---

# Java Documentation (Javadoc) Best Practices

## Scope

- **Public and protected members** must have Javadoc comments.
- **Package-private and private members** should also be documented when they are complex or not self-explanatory.

## Structure

The first sentence is the summary description. It must:
- Concisely state what the method/type does.
- End with a period.
- Be written in third-person singular present tense for methods (e.g., "Returns the current value.", "Flushes all pending rows.").

Subsequent paragraphs (separated by `<p>`) can elaborate on behaviour, constraints, or edge cases.

## Tags

Use tags in this order when applicable:

| Tag | Usage |
|-----|-------|
| `@param <name>` | One per parameter. Description starts lowercase, no trailing period. |
| `@param <T>` | For type parameters in generic types or methods. |
| `@return` | Describes the return value. Omit for `void`. Starts lowercase, no trailing period. |
| `@throws` / `@exception` | One per checked or notable unchecked exception. Describes when it is thrown. |
| `@see` | Reference to a related type or member (e.g., `@see Writer#flush()`). |
| `@since` | Version or milestone when this member was introduced (e.g., `@since 1.0`). |
| `@version` | Version of the member, if tracked separately from the class. |
| `@author` | Author of the code. Use on type-level Javadoc; omit on individual methods. |
| `@deprecated` | Marks a member as deprecated. Always include an alternative in the description. |

## Inline tags

- `{@code someValue}` — for inline code references (type names, method names, literals).
- `{@link SomeClass#method()}` — for hyperlinked references.
- `{@inheritDoc}` — inherit documentation from the supertype. Add extra prose only when this implementation differs meaningfully from the contract.

## Code blocks

Use `<pre>{@code ... }</pre>` for multi-line code examples:

```java
/**
 * Writes a row to the store via the provided connection.
 *
 * <p>The connection is not thread-safe; callers must ensure external synchronisation
 * or use one connection per thread.
 *
 * <pre>{@code
 * try (var conn = store.connect()) {
 *     writer.write(record, conn);
 * }
 * }</pre>
 *
 * @param record the record to write; must not be {@code null}
 * @param conn   the connection for the current thread
 * @throws IllegalArgumentException if {@code record} is missing a required field
 */
void write(Record record, Connection conn);
```

## Deprecation

When deprecating, always provide a replacement:

```java
/**
 * @deprecated Use {@link #newMethod()} instead.
 */
@Deprecated
void oldMethod();
```

## Null contracts

State nullability explicitly in `@param` and `@return` descriptions — don't assume the reader will check the implementation:

```java
/**
 * @param symbol the instrument symbol; must not be {@code null}
 * @return the matching contract, or {@code null} if none exists
 */
```

If the method uses `Objects.requireNonNull` at entry, the `@param` must say "must not be {@code null}". If a method never returns null, say so or document the empty-collection / `Optional.empty()` alternative instead.

## Thread-safety

Document thread-safety at the class level. Pick one of these standard phrasings and add it as a `<p>` in the type-level Javadoc:

```java
/**
 * Writer that batches order rows into the database.
 *
 * <p>This class is not thread-safe. Each thread must use its own instance.
 */
```

```java
/**
 * Registry of open positions shared across writer threads.
 *
 * <p>This class is thread-safe.
 */
```

Do not leave thread-safety implied — the `eetc:java-code-style` skill requires explicit documentation on any class shared across threads.

## Records

Document the record at the type level (what it represents, any invariants). Components are documented with `@param` tags on the canonical constructor — use the compact constructor form when adding validation:

```java
/**
 * A single market data tick received from the exchange.
 *
 * @param symbol     the instrument symbol; must not be {@code null}
 * @param exchangeTs exchange timestamp in epoch microseconds
 * @param price      last trade price in integer ticks
 */
record Tick(String symbol, long exchangeTs, long price) {
    Tick {
        Objects.requireNonNull(symbol, "symbol");
    }
}
```

Do not add separate field-level Javadoc on record components — the canonical constructor `@param` tags are the authoritative documentation.

## Sealed classes and interfaces

Document the sealed type with a `@param <T>` or a prose description of the permitted subtypes. Each permitted subtype gets its own full Javadoc:

```java
/**
 * A lifecycle event emitted during a recording session.
 *
 * <p>Permitted subtypes: {@link TickReceived}, {@link SessionEnded}, {@link DumpCompleted}.
 */
sealed interface SessionEvent permits TickReceived, SessionEnded, DumpCompleted {}

/**
 * Emitted when a tick arrives from the exchange.
 *
 * @param tick the received tick; must not be {@code null}
 */
record TickReceived(Tick tick) implements SessionEvent {}
```

## Enum constants

Each enum constant can have its own Javadoc. Document constants that are not self-explanatory:

```java
enum SessionPhase {

    /** Market is open; ticks are being consumed and written. */
    RECORDING,

    /** Session end time reached; draining remaining queued ticks. */
    DRAINING,

    /** Queue is empty; flushing the write buffer. */
    FLUSHING,

    /** Flush complete; exporting the session to long-term storage. */
    DUMPING;
}
```

## `@apiNote` and `@implNote`

Use these standard JDK-style tags for important asides that don't fit in the main description:

- `@apiNote` — guidance for callers (design intent, usage warnings, trade-offs):
  ```java
  /**
   * Writes a row through the given connection.
   *
   * @apiNote This method is not thread-safe. The caller must ensure that a single
   *          {@code Connection} instance is used by at most one thread at a time.
   */
  ```
- `@implNote` — notes about the current implementation that callers should be aware of but that may change:
  ```java
  /**
   * @implNote Rows are buffered in memory until {@link #flush()} is called. Calling
   *           this method does not guarantee the row is durable.
   */
  ```

These tags are rendered by standard Javadoc tooling — they do not need `<p>` wrapping.

## `package-info.java`

Every package should have a `package-info.java` with a package-level Javadoc comment. Place it at the root of the package:

```java
/**
 * Order routing and execution tracking.
 *
 * <p>The main entry point is {@link com.eetc.orders.OrderRouter}.
 * See the project ADR for the overall lifecycle and threading model.
 */
package com.eetc.orders;
```

Package Javadoc does not use `@author` or `@version`. Use it to orient a new reader, reference the ADR, and point to the key entry-point class.

## What to avoid

- Restating the method name as the summary ("This method does X" where X is already the name).
- Leaving `@param` or `@return` descriptions empty or with a single word that adds no value.
- Documenting implementation details that belong in inline comments, not Javadoc.
- Using `@author` on individual methods — apply it at the class/interface level only.
- Omitting `@throws` for checked exceptions.