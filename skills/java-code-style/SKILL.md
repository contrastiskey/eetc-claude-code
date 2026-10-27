---
name: java-code-style
description: >
  Java coding conventions that follow established industry standards: the
  Google Java Style Guide and Effective Java (3rd edition). Covers tooling,
  source files, formatting, naming, programming practices, class design, null
  handling, exceptions, logging, generics, enums, lambdas and streams, modern
  language features and concurrency.
  TRIGGER when: writing, editing, formatting, or reviewing Java code, or
  asked to "fix style" / "check code quality" in a Java project.
  DO NOT TRIGGER when: working in a non-Java language, or only reading code
  without making changes.
---

# Java Code Style

Sources. Earlier ones win a disagreement:

1. [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
   (cited as §n).
2. *Effective Java*, 3rd edition, Joshua Bloch (cited as EJ n, the item
   number).
3. The JDK documentation and JEPs, for language features and the versions
   that introduced them, plus the OpenJDK
   [`var` style guidelines](https://openjdk.org/projects/amber/guides/lvti-style-guide).

Javadoc rules live in `eetc:java-docs`, test rules in `eetc:java-tests`.

## Tooling

- Read the build file (`pom.xml`, `build.gradle(.kts)`) for the Java release
  (`maven.compiler.release`, `java.toolchain.languageVersion`) and the checks
  it runs: Spotless / google-java-format, Checkstyle, Error Prone, SpotBugs,
  NullAway. The full build (`mvn verify`, `./gradlew check`) passes.
- google-java-format owns formatting. Run it (`mvn spotless:apply`,
  `./gradlew spotlessApply`) and don't hand-format against it. If the build
  sets the AOSP variant, indents are 4 spaces, not 2.
- New code compiles without warnings. Eliminate unchecked warnings. When a
  cast is provably safe, put `@SuppressWarnings("unchecked")` on the smallest
  declaration possible, with a comment saying why it's safe (EJ 27).
- Never loosen a check's configuration to get a change through. A
  suppression (`@SuppressWarnings`, `// NOPMD`, a SpotBugs exclusion) has the
  narrowest scope and a comment saying why.

## Source files

- One top-level class per file, named after it (§2.1, §3.4.1). UTF-8.
  Spaces only, never tabs. Special escapes (`\n`, `\t`, `\"`) over octal or
  Unicode escapes. Real Unicode characters over escapes, except for
  non-printable ones, which get a comment (§2.3).
- Order, one blank line between: license, `package`, imports, the class (§3).
- Imports (§3.3):
  - No wildcard imports, static or not, and no module imports
    (`import module java.base;`).
  - Two groups: every static import, a blank line, every non-static import.
    No other blank lines. Each group in ASCII order of the imported name.
    There are no separate `java.*` / `javax.*` / third-party groups.
  - Never line-wrapped. Nested classes are imported normally, never
    statically.
- Members follow a logical order you could explain; don't just append new
  methods at the end. Overloads, and constructors, stay together with nothing
  in between (§3.4.2).

## Formatting

The formatter handles most of §4. What it can't fix:

- Braces on every `if`, `else`, `for`, `do` and `while`, even around a single
  statement or an empty body (§4.1.1):

  ```java
  if (value == null) {
    throw new NullPointerException("value");
  }
  ```

- Indent blocks 2 spaces, continuation lines at least 4. The column limit is
  100 (§4.2–4.5).
- One statement per line. One variable per declaration (`int a, b;` is out,
  except in a `for` header). Declare locals where they're first needed,
  with an initializer (§4.3, §4.8.2).
- `String[] args`, not `String args[]` (§4.8.3.2). `long` literals end in
  uppercase `L` (§4.8.8).
- Modifiers in this order (§4.8.7):
  `public protected private abstract default static final sealed non-sealed transient volatile synchronized native strictfp`.
- Class and method annotations go one per line after the Javadoc. A single
  annotation with no arguments may share the signature's line
  (`@Override public int hashCode()`). Type-use annotations sit right before
  the type: `@Nullable String name` (§4.8.5).
- Every `switch` is exhaustive, so add an empty `default` if needed. Switch
  expressions use the arrow form (`case X ->`). In an old-style switch, a
  statement group that falls through says `// fall through` (§4.8.4).
- Add grouping parentheses whenever precedence isn't obvious (§4.7).
- Text blocks: the opening `"""` ends its line, and the closing `"""` lines up
  with it (§4.8.9).
- Block comments never sit in boxes. TODOs link to an issue:
  `// TODO: github.com/org/repo/issues/123 - Remove after the v2 migration.`
  (§4.8.6).

## Naming

| Kind | Style | Example |
|------|-------|---------|
| Package | lowercase words run together, no underscores | `com.example.deepspace` |
| Class, interface, record, enum | `UpperCamelCase` noun (interfaces may be adjectives) | `OrderWriter`, `Readable` |
| Test class | class under test + `Test` | `OrderWriterTest` |
| Method | `lowerCamelCase` verb | `sendMessage` |
| Test method | `lowerCamelCase`, `_` between logical parts allowed | `transfer_deductsFromSource` |
| Constant | `UPPER_SNAKE_CASE` | `MAX_RETRIES` |
| Other field, parameter, local | `lowerCamelCase` | `retryCount` |
| Type variable | one capital (+ digit) or class name + `T` | `T`, `T2`, `RequestT` |

- A constant is a `static final` field whose value is deeply immutable:
  primitives, strings, immutable collections of immutable values. A
  `static final` logger, mutable collection or array is not a constant, so
  it's `lowerCamelCase`. Locals are never constants, even when final (§5.2.4).
- No prefixes or suffixes: not `mName`, `name_`, `sName`, `kName` (§5.1).
- Acronyms are words: `XmlHttpRequest`, `newCustomerId`, `supportsIpv6OnIos`
  (§5.3).
- One-letter parameter names stay out of public methods. Use `_` for unused
  variables and parameters on Java 22+ (§5.2.9).

## Programming practices

- `@Override` whenever it's legal, including interface methods and explicit
  record accessors (§6.1, EJ 40).
- Never ignore a caught exception. If doing nothing is truly right, say why
  in a comment (§6.2, EJ 77).
- Qualify static members with the class name, never with an instance (§6.3).
- No finalizers or `Cleaner`s for cleanup. Implement `AutoCloseable` and use
  try-with-resources (§6.4, EJ 8, EJ 9).
- `var` only when the initializer makes the type obvious:
  `var users = new ArrayList<User>();`, not `var result = service.process();`.
- `java.time` for dates and times, never `Date`, `Calendar` or
  `SimpleDateFormat`.

## Class design

- Minimize accessibility: private fields; package-private classes and
  members unless other packages need them (EJ 15). No public mutable fields
  (EJ 16).
- Immutable by default (EJ 17). Fields are `final`, the class is `final` (or
  has only private constructors), and there are no setters. Use records for
  plain data carriers (Java 16+).
- Defensive copies of mutable inputs and outputs. Copy *before* validating,
  so the caller can't change the value between the check and the copy
  (EJ 50):

  ```java
  Team(String name, List<Player> players) {
    this.name = name;
    this.players = List.copyOf(players);
    if (this.players.isEmpty()) {
      throw new IllegalArgumentException("team " + name + " has no players");
    }
  }
  ```
- Consider a static factory instead of a constructor when a name helps or
  instances can be cached (EJ 1). Use a builder when there are many optional
  parameters (EJ 2).
- Pass dependencies in through the constructor; don't reach for singletons
  or static state (EJ 5).
- Composition over inheritance (EJ 18). Either design a class for
  inheritance and document its self-use, or make it `final` (EJ 19).
- Interfaces over abstract classes (EJ 20). No constant interfaces (EJ 22).
- A sealed interface with record implementations, not a tagged class with a
  `type` field (EJ 23). Nested classes are `static` unless they need the
  outer instance (EJ 24).
- A class of static helpers is `final`, with a private constructor (EJ 4).
- Declare fields, parameters and return types by interface: `List<String>`,
  not `ArrayList<String>` (EJ 64). A `var` local is exempt.
- `equals` and `hashCode` are always overridden together and agree. A value
  class overrides `toString`. `compareTo` is consistent with `equals`
  (EJ 10–12, EJ 14). Records generate all three; don't override them without
  a reason.

  ```java
  @Override
  public boolean equals(Object o) {
    return o instanceof PhoneNumber other
        && areaCode == other.areaCode
        && lineNumber == other.lineNumber;
  }

  @Override
  public int hashCode() {
    return Objects.hash(areaCode, lineNumber);
  }
  ```

## Null handling

- Return empty collections, arrays and strings, never `null` (EJ 54).
- `Optional<T>` only as the return type of a method that may have no result.
  Never a field, parameter, or collection element, never `Optional<List<T>>`,
  and never `null` itself (EJ 55).
- Validate parameters at the public boundary, first thing in the method:
  `Objects.requireNonNull(order, "order")`, or an
  `IllegalArgumentException` naming the bad value (EJ 49).
- When the project uses nullness annotations (JSpecify `@NullMarked`,
  NullAway, the Checker Framework), annotate every nullable type with the
  type-use `@Nullable` (`@Nullable String`). Without them, state nullability
  in the Javadoc.

## Exceptions

- Exceptions are for exceptional conditions, never for control flow (EJ 69).
- Checked exceptions for conditions the caller can recover from, runtime
  exceptions for programming errors (EJ 70). Don't add checked exceptions a
  caller can't act on (EJ 71).
- Prefer the standard ones: `IllegalArgumentException` (bad argument),
  `IllegalStateException` (wrong object state), `NullPointerException`,
  `IndexOutOfBoundsException`, `UnsupportedOperationException` (EJ 72).
- At a layer boundary, translate low-level exceptions into the layer's own,
  keeping the cause: `throw new StorageException("write failed: " + key, e);`
  (EJ 73).
- Detail messages include the values that caused the failure, never secrets
  (EJ 75).
- A failed method call leaves the object as it was (EJ 76).
- try-with-resources for every `AutoCloseable` (EJ 9).
- Catch `Exception` only at a top-level boundary (a request handler, a
  worker loop) that logs it. Never catch `Throwable` or `Error`.
- On `InterruptedException`, restore the flag
  (`Thread.currentThread().interrupt()`) or rethrow; never swallow it.

## Logging

- Use the repo's logging facade; in new code without one, SLF4J. One logger
  per class, named `logger` because it isn't a constant:

  ```java
  private static final Logger logger = LoggerFactory.getLogger(OrderWriter.class);
  ```

- Placeholders, never string concatenation, which builds the message even
  when the level is off. A throwable goes last, without a placeholder, so the
  stack trace is kept:

  ```java
  logger.info("Wrote {} rows to {}", count, table);
  logger.warn("Retrying order {}", orderId, e);
  ```

- Wrap a log call in `if (logger.isDebugEnabled())` only when computing an
  argument is itself expensive.
- MDC entries for context shared by many lines (a request ID). Remove them in
  `finally`.
- Levels: `ERROR` needs attention, `WARN` is a recovered anomaly, `INFO` is a
  lifecycle event, `DEBUG` / `TRACE` are off in production.
- Never log secrets or personal data. No `System.out`, `System.err` or
  `printStackTrace()`.

## Generics

- No raw types: `List<String>`, never `List` (EJ 26). Prefer lists to arrays
  (EJ 28).
- Bounded wildcards for flexibility. A producer is `extends`, a consumer is
  `super`: `void pushAll(Iterable<? extends E> src)`,
  `void popAll(Collection<? super E> dst)`. Never a wildcard in a return type
  (EJ 31).
- Make types and methods generic rather than casting at call sites (EJ 29,
  EJ 30).

## Enums

- Enums, not `int` or `String` constants (EJ 34). Store data in fields, never
  derive it from `ordinal()` (EJ 35).
- `EnumSet` instead of bit flags, `EnumMap` instead of ordinal-indexed arrays
  (EJ 36, EJ 37).
- Compare enums with `==`.

## Lambdas and streams

- Lambdas over anonymous classes. Method references when they're shorter and
  clearer (EJ 42, EJ 43). Use `java.util.function` types over custom
  functional interfaces (EJ 44).
- Streams for transformations. Use a loop when the code mutates local state,
  throws checked exceptions, or needs `break` / `continue` (EJ 45). Stream
  lambdas have no side effects; build results with collectors, not
  `forEach` (EJ 46).
- Return `Collection` / `List` from APIs rather than `Stream` (EJ 47).
  Parallel streams only with a measured speedup (EJ 48).
- Enhanced `for` over an indexed loop (EJ 58).

## General practices

- Keep variable scope minimal (EJ 57). Know and use the standard library
  before writing helpers (EJ 59).
- Never `float` or `double` for exact values such as money. Use `BigDecimal`
  (compared with `compareTo`, not `equals`, which also compares scale) or a
  `long` of minor units (EJ 60).
- Primitives over boxed types. Never compare boxed values with `==` (EJ 61).
- Don't use strings for data that has a better type (EJ 62). Use
  `StringBuilder` to build strings in loops (EJ 63). Compare string contents
  with `equals`, never `==`.
- Interfaces over reflection (EJ 65).
- Avoid Java serialization; use JSON, protobuf or another explicit format
  (EJ 85).

## Modern Java

Use the modern form the target release allows:

| Feature | Since |
|---------|-------|
| Text blocks | 15 |
| Records, pattern matching for `instanceof` | 16 |
| Sealed classes | 17 |
| Pattern matching for `switch`, record patterns, virtual threads, `getFirst()` / `getLast()` on lists | 21 |
| `_` for unnamed variables | 22 |
| Markdown Javadoc (`///`) | 23 |
| `synchronized` no longer pins virtual threads | 24 |
| `ScopedValue` | 25 |

- `if (event instanceof OrderPlaced placed)`, not a test plus a cast.
- Model a closed set of variants as a sealed interface with records, and
  dispatch with an exhaustive `switch`. The compiler then flags every switch
  that misses a new variant:

  ```java
  sealed interface Shape permits Circle, Square {}
  record Circle(double radius) implements Shape {}
  record Square(double side) implements Shape {}

  static double area(Shape shape) {
    return switch (shape) {
      case Circle c -> Math.PI * c.radius() * c.radius();
      case Square s -> s.side() * s.side();
    };
  }
  ```

- Virtual threads for blocking I/O: one per task, never pooled.
  `Executors.newVirtualThreadPerTaskExecutor()` in try-with-resources.
  Before Java 24, guard blocking calls with `ReentrantLock`, not
  `synchronized`, which pins the carrier thread.
- On 25+, `ScopedValue` instead of `ThreadLocal` for immutable per-task
  context.
- Structured concurrency (`StructuredTaskScope`) is still a preview API
  (seventh preview in Java 27) and its shape keeps changing. Don't use it
  unless the build enables `--enable-preview`.

## Concurrency

- Synchronize every access to shared mutable data, reads included (EJ 78).
  Keep synchronized regions short, and never call unknown code inside one
  (EJ 79).
- Executors and tasks, not hand-made threads (EJ 80). `java.util.concurrent`
  (`ConcurrentHashMap`, `BlockingQueue`, `CountDownLatch`) instead of
  `wait` / `notify` (EJ 81). An `ExecutorService` is closed with
  try-with-resources (Java 19+) or shut down explicitly.
- `volatile` only for single-variable visibility, never for check-then-act.
  Use a lock or an atomic for compound operations.
- Document the thread safety of every class (EJ 82); `eetc:java-docs` has
  the wording.
- Lazy initialization only when measurements call for it; use the holder
  class idiom for statics (EJ 83).
- Never depend on the thread scheduler: no busy-waiting, no `Thread.yield`
  for correctness (EJ 84).
