---
name: java-docs
description: >
  Javadoc conventions that follow established industry standards: the Google
  Java Style Guide, Oracle's "How to Write Doc Comments", and Effective Java.
  Covers where Javadoc is required, its form, the summary fragment, block
  tags and their order, exceptions, null contracts, thread safety, docs for
  inheritance, generics, records, enums, sealed types, packages and
  deprecation.
  TRIGGER when: writing or reviewing Javadoc on Java code, or asked to
  "document" / "add javadoc".
  DO NOT TRIGGER when: working in a non-Java language.
---

# Javadoc

Sources. Earlier ones win a disagreement:

1. [Google Java Style Guide §7](https://google.github.io/styleguide/javaguide.html#s7-javadoc).
2. Oracle's *How to Write Doc Comments for the Javadoc Tool*, linked from
   the [Javadoc Tool page](https://www.oracle.com/java/technologies/javase/javadoc-tool.html).
3. *Effective Java*, 3rd edition: items 19 (inheritance), 56 (doc
   comments), 74 (exceptions) and 82 (thread safety), cited as EJ n.

## Where Javadoc is required

- Every visible class, member and record component. That means every
  `public` class, and every `public` or `protected` member of one (§7.3,
  EJ 56).
- Optional on a simple, obvious member such as `getFoo()`, when there is
  truly nothing to say beyond "the foo". This is never a reason to leave out
  something a reader needs, such as what a domain term means (§7.3.1).
- Optional on an override that doesn't change the contract (§7.3.2).
- Anywhere else, a comment that states a class's or method's purpose is
  written as Javadoc, not as a `//` comment (§7.3.4).

## Form

- Traditional `/** ... */` or Markdown `///` (JDK 23+) are both fine (§7.1).
  Match the file and the project, and use Markdown only when the build's JDK
  supports it.
- The single-line form `/** Returns the customer ID. */` is for docs that
  fit on one line and have no block tags.
- Traditional paragraphs are separated by a ` *` line. Every paragraph after
  the first starts with `<p>` directly before its first word, but not before
  `<ul>` or `<table>`. Markdown paragraphs are separated by a blank `///`
  line, with no `<p>` (§7.1.2).
- Inline code is `{@code ...}` (backticks in Markdown). Code blocks are
  `<pre>{@code ... }</pre>` (fenced blocks in Markdown). Link a type or
  member with `{@link Type#method(Param)}`, on its first mention only.
- Write for both readers: the source must read well, not only the HTML.

## The summary fragment

- The first sentence is the summary, and indexes show it alone. It's a
  fragment, capitalized and punctuated like a sentence (§7.2):
  - Methods and constructors: a third-person verb phrase. "Returns the
    customer ID.", "Creates a reader for the given file."
  - Classes and fields: a noun phrase. "An immutable money amount."
  - Never "This method returns ...", "A {@code Foo} is a ...", or an
    imperative ("Save the record.").
- A getter whose summary would only repeat `@return` uses
  `/** {@return the customer ID} */` (JDK 16+). A bare `@return` with no
  summary is wrong.
- No two members share a summary; overloads say how they differ (EJ 56).
- In traditional Javadoc, the summary ends at the first period followed by
  a space. "e.g. " ends it early, so write "for example".

## Method contracts

Document what the method does, not how: preconditions, postconditions and
side effects (EJ 56).

- Block tags appear in this order, and the first four never have an empty
  description (§7.1.3): `@param` (type parameters as `@param <T>`),
  `@return`, `@throws`, `@deprecated`, then `@see` and `@since`.
- `@param` and `@return` descriptions are noun phrases: lowercase, with no
  period unless more sentences follow. A continuation line is indented 4
  spaces from the `@` (2 in Markdown).
- `@return` is omitted for `void` and when the summary uses `{@return}`.
- `@throws` for every checked exception, and for each unchecked exception
  that's part of the contract, such as a violated precondition. Phrase it as
  a condition: "if {@code count} is negative". Unchecked exceptions never go
  in the `throws` clause (EJ 74).
- Skip `@author` and `@version`; version control records both.

```java
/**
 * Writes a record to the store, replacing any record with the same key.
 *
 * <p>The write is durable once this method returns.
 *
 * <pre>{@code
 * try (var conn = store.connect()) {
 *   writer.write(record, conn);
 * }
 * }</pre>
 *
 * @param record the record to write
 * @param conn an open connection, used by one thread at a time
 * @return the record's new version number
 * @throws IllegalArgumentException if {@code record} has no key
 * @throws StorageException if the store rejects the write
 */
long write(Record record, Connection conn) throws StorageException;
```

## Null contracts

- With nullness annotations (JSpecify `@NullMarked`, NullAway), the
  signature carries nullability (`@Nullable String`). The Javadoc only says
  what `null` means: "or {@code null} if the user has no email".
- Without annotations, state it in prose. Either say per parameter and
  return value which may be `null`, or set a default once at the package or
  class level: "Unless otherwise noted, passing {@code null} to any method
  throws {@link NullPointerException}."
- A method that returns a collection, array or `Optional` never returns
  `null`; don't document it as if it might.

## Thread safety

Every class states its thread safety in its class-level Javadoc, using one
of these levels (EJ 82):

| Level | Wording |
|-------|---------|
| Immutable | "Instances of this class are immutable." |
| Unconditionally thread-safe | "This class is thread-safe." |
| Conditionally thread-safe | "This class is thread-safe, except that ..." plus which call sequences need external synchronization and on which lock |
| Not thread-safe | "This class is not thread-safe. Each thread must use its own instance, or synchronize externally." |

- The `synchronized` modifier is not documentation; it doesn't appear in the
  generated docs and isn't part of the contract.
- Document a conditionally thread-safe class's lock, for example "Callers
  must synchronize on the returned map while iterating."

## Classes designed for inheritance

- A class meant to be subclassed documents its self-use: which overridable
  methods each method calls, and when (EJ 19). Write this under `@implSpec`.
- `@implSpec` (implementation requirements), `@apiNote` (guidance for
  callers) and `@implNote` (notes on this implementation only) are JDK
  custom tags. The `javadoc` tool rejects them unless the build registers
  them, e.g. `-tag implSpec:a:"Implementation Requirements:"` via the
  maven-javadoc-plugin's `<tags>`. Without that, write the note as a normal
  paragraph.

## Generics, records, enums and sealed types

- Document every type parameter: `@param <K> the type of keys`.
- A record is documented in its declaration's Javadoc, with one `@param` per
  component. Those become the docs for the components and their accessors:

  ```java
  /**
   * A money amount in one currency.
   *
   * @param amount the amount, at the currency's minor-unit scale
   * @param currency the currency of {@code amount}
   */
  public record Money(BigDecimal amount, Currency currency) {}
  ```

- Document each enum constant whose meaning isn't obvious from its name:

  ```java
  enum PaymentStatus {
    /** Authorized; funds are held but not yet captured. */
    AUTHORIZED,

    /** Captured; funds will settle to the merchant. */
    CAPTURED,
  }
  ```

- A sealed type's Javadoc says what the hierarchy models. Its `permits`
  list appears in the generated signature, so don't repeat it in prose. Each
  permitted subtype documents itself.
- Document every member of an annotation type (EJ 56).

## Packages and modules

- Each exported package has a `package-info.java` whose Javadoc says what
  the package holds, names its main entry points, and states package-wide
  conventions such as the nullness default. Annotations go after the
  Javadoc, before `package`.
- A module's `module-info.java` Javadoc describes the module.

## Deprecation

`@deprecated` says what to use instead, and when the old API goes if a
removal is planned. Pair it with the `@Deprecated` annotation:

```java
/**
 * Returns the user's display name.
 *
 * @deprecated Use {@link #displayName()} instead. Removed in 3.0.
 */
@Deprecated(since = "2.4", forRemoval = true)
public String getName() {
  return displayName();
}
```

## What to avoid

- A summary that only restates the name (`/** Gets the name. */`). Say what
  the value means, or use the self-explanatory exception.
- Implementation details in Javadoc. They belong in `//` comments.
- Empty or one-word tag descriptions.
- Duplicating what annotations or the signature already say: types,
  `@Nullable`, `throws` clauses for unchecked exceptions.
