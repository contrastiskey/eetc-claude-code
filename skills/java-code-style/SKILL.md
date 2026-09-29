---
name: java-code-style
description: >
  Java coding conventions: Google Java Style, SpotBugs patterns, SLF4J
  logging, immutability, null safety, exception handling, modern language
  features and concurrency.
  TRIGGER when: writing, editing, formatting, or reviewing Java code, or
  asked to "fix style" / "check code quality" in a Java project.
  DO NOT TRIGGER when: working in a non-Java language, or only reading code
  without making changes.
---

# Java Code Style

Check the repo's `pom.xml` for its Java version and for which of Checkstyle,
SpotBugs and Spotless it wires in. When they are wired to `verify`,
`mvn verify` must pass. When Spotless is present, run `mvn spotless:apply`
before committing. Don't hand-format anything it controls. Project-specific
tooling and commands live in the repo's CLAUDE.md.

## Google Java Style — key rules

### Naming

| Construct | Convention | Example |
|-----------|-----------|---------|
| Class / interface / enum | `UpperCamelCase` | `OrderWriter`, `SessionState` |
| Method | `lowerCamelCase` | `writeRow()`, `flushBuffer()` |
| Variable / parameter | `lowerCamelCase` | `exchangeTs`, `contractId` |
| Constant (`static final`) | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| Package | all lowercase, no underscores | `com.eetc.orders` |
| Type parameter | single uppercase letter or `UpperCamelCase` + `T` | `T`, `KeyT` |

### Braces

Always use braces for `if`, `else`, `for`, `while`, `do` — even single-line bodies:

```java
// correct
if (value == null) {
    throw new NullPointerException("value");
}

// violation
if (value == null)
    throw new NullPointerException("value");
```

Opening brace on the same line (K&R style). `else`/`catch`/`finally` on the same line as the closing brace.

### Indentation and line length

- 2-space indentation (Spotless enforces this).
- Line length limit: **100 characters**.
- Continuation lines: indented +4 spaces relative to the statement they continue.

### Imports

- No wildcard imports (`import java.util.*` is a violation).
- No unused imports — Spotless removes them automatically.
- Import order: static imports first, then `java.*`, `javax.*`, then third-party, then project packages.

### Whitespace

- One blank line between methods.
- No trailing whitespace — Spotless enforces this.
- File must end with a single newline — Spotless enforces this.
- Space after keywords (`if (`, `for (`, `while (`), not after method names (`write(`).

### Javadoc

Checkstyle validates Javadoc structure. See the `eetc:java-docs` skill for the full Javadoc rules. Short summary:
- Public and protected members must have Javadoc.
- `@param`, `@return`, `@throws` must be present where applicable.
- Summary sentence ends with a period.

## SpotBugs — patterns to avoid

| Bug pattern | What to do instead |
|-------------|-------------------|
| `RCN_REDUNDANT_NULLCHECK_OF_NONNULL_VALUE` | Don't null-check values that can't be null |
| `OBL_UNSATISFIED_OBLIGATION` | Close resources in `try-with-resources`, not manually in `finally` |
| `EQ_COMPARETO_USE_OBJECT_EQUALS` | If you implement `Comparable`, also override `equals` consistently |
| `RV_RETURN_VALUE_IGNORED` | Don't ignore return values of methods annotated `@CheckReturnValue` |
| `IS2_INCONSISTENT_SYNC` | If a field is accessed under a lock anywhere, access it under the lock everywhere |
| `NP_NULL_ON_SOME_PATH` | Add null checks or use `Objects.requireNonNull` at method entry |

## Immutability

Prefer immutable design by default — mutability should be a deliberate choice, not a habit.

- Declare fields `final` unless mutation is genuinely required.
- Use **records** for pure data carriers (no behaviour, no mutation):
  ```java
  record Tick(String symbol, long exchangeTs, long price) {}
  ```
- Do not add setters unless the object's lifecycle requires state change after construction.
- Return defensive copies of mutable fields (`List`, arrays) rather than exposing internal state:
  ```java
  public List<String> tags() {
      return List.copyOf(tags); // not return tags;
  }
  ```
- Prefer `List.of`, `Map.of`, `Set.of` for collections that won't change.

## Null safety

- Call `Objects.requireNonNull(param, "param")` at the top of every public method that must not receive null. Do this at the boundary, not deep inside.
  ```java
  public void write(Tick tick, Connection conn) {
      Objects.requireNonNull(tick, "tick");
      Objects.requireNonNull(conn, "conn");
      // ...
  }
  ```
- Use `Optional<T>` as a return type when a method legitimately may produce no value. Never use it as a field type or parameter type.
- Never return `null` from a method that returns a `Collection` — return an empty collection instead.
- Do not return `null` from a method that returns `Optional` — return `Optional.empty()`.
- Avoid `@Nullable` / `@NonNull` annotations unless the project already uses a null-analysis framework consistently.

## Exception handling

- Don't catch `Exception` or `Throwable` broadly unless you are at a top-level boundary (main loop, framework callback) and re-throw or log-and-exit.
- Never swallow exceptions silently:
  ```java
  // violation
  catch (IOException e) { }

  // correct
  catch (IOException e) {
      throw new UncheckedIOException(e);
  }
  ```
- Wrap checked exceptions at layer boundaries with an unchecked exception that belongs to that layer. Don't let `SQLException` or `IOException` leak through a public API that has no business exposing them.
- Include the original exception as the cause when wrapping — never discard it.
- Use specific exception types. Throw `IllegalArgumentException` for bad inputs, `IllegalStateException` for invalid object state, `UnsupportedOperationException` for unimplemented optional operations.
- Add a message to every exception you throw. An exception with no message is useless in a log.

## Logging

Use **SLF4J** as the logging facade and **Logback** as the implementation. Declare one logger per class:

```java
private static final Logger log = LoggerFactory.getLogger(OrderWriter.class);
```

### Parameterized messages

Use SLF4J placeholders, never string concatenation. Concatenation builds the
string even when the level is disabled:

```java
// correct
log.info("tick written: symbol={} exchange_ts={}", tick.symbol(), tick.exchangeTs());

// violation — string concatenation defeats parameterization and is slower
log.info("Wrote tick for " + tick.symbol());
```

If the repo emits structured (JSON) logs, its CLAUDE.md describes the encoder
and field conventions.

### MDC (Mapped Diagnostic Context)

Use MDC to attach context that repeats across many log lines — session date, partition, contract ID. The log layout attaches MDC entries to every event:

```java
MDC.put("session.date", sessionDate.toString());
try {
    // every log line inside here carries "session.date"
} finally {
    MDC.remove("session.date"); // always clean up, especially on virtual threads
}
```

### Log levels

| Level | When to use |
|-------|-------------|
| `ERROR` | Unrecoverable — process must stop or a session is lost |
| `WARN` | Recoverable anomaly — late tick, retry, skipped record |
| `INFO` | Lifecycle events — session start/end, phase transitions, counts |
| `DEBUG` | Per-tick / per-record detail — disabled in production |
| `TRACE` | Internal loop tracing — disabled unless actively debugging |

- Never log passwords, API keys, or PII.
- Guard `DEBUG`/`TRACE` calls inside hot paths: `if (log.isDebugEnabled())`.

## `equals` and `hashCode`

- Overriding one obligates overriding the other — the contract requires both.
- Use `Objects.equals` and `Objects.hash` to handle nulls safely:
  ```java
  @Override
  public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof MyClass that)) return false;
      return Objects.equals(id, that.id);
  }

  @Override
  public int hashCode() {
      return Objects.hash(id);
  }
  ```
- Records generate correct `equals`/`hashCode` automatically — don't override them without a specific reason.
- If a class is used as a `Map` key or `Set` element, its `equals`/`hashCode` must be consistent and stable for the object's lifetime.

## Modern Java

Prefer modern language features over legacy equivalents, within the Java
version the repo targets (`maven.compiler.release`/`source` or `java.version`
in `pom.xml`). Minimum versions: records and `instanceof` patterns 16, sealed
types 17, pattern matching for `switch` and virtual threads 21, `ScopedValue` 25.

### Pattern matching for `instanceof`

```java
// correct
if (event instanceof TickEvent e) {
    process(e.tick());
}

// legacy — avoid
if (event instanceof TickEvent) {
    process(((TickEvent) event).tick());
}
```

### Switch expressions

Use switch expressions (with `->` arms or `yield`) instead of switch statements for value-producing switches:

```java
String label = switch (phase) {
    case RECORDING -> "rec";
    case DRAINING  -> "drain";
    case DUMPING   -> "dump";
};
```

### Sealed classes

Use `sealed` + `permits` to model a closed set of types (e.g. session phases, command variants). Pair with exhaustive `switch` so the compiler enforces completeness:

```java
sealed interface SessionEvent permits TickReceived, SessionEnded, DumpCompleted {}
```

### Pattern matching for `switch`

Combine sealed types and switch for safe, exhaustive dispatch:

```java
String describe(SessionEvent e) {
    return switch (e) {
        case TickReceived t  -> "tick " + t.symbol();
        case SessionEnded s  -> "ended at " + s.endTime();
        case DumpCompleted d -> "dumped " + d.rowCount() + " rows";
    };
}
```

### Text blocks

Use text blocks for inline SQL, JSON, or multi-line strings in tests:

```java
String query = """
    SELECT symbol, count()
    FROM ticks
    WHERE exchange_ts > dateadd('h', -1, now())
    ORDER BY exchange_ts DESC;
    """;
```

### Virtual threads

Prefer virtual threads for I/O-bound work (broker polling, database writes, uploads). Platform threads are for CPU-bound work only.

```java
Thread.ofVirtual().name("order-writer").start(writerTask);

// or via ExecutorService
ExecutorService exec = Executors.newVirtualThreadPerTaskExecutor();
```

### Structured Concurrency (still preview in Java 25)

`StructuredTaskScope` is a preview API through Java 25 and its shape changed
between previews (`ShutdownOnFailure` is gone). Don't use it unless the build
enables `--enable-preview`; use an `ExecutorService` in try-with-resources
(Java 19+) instead.

### Scoped Values (Java 25+)

Prefer `ScopedValue` over `ThreadLocal` for immutable per-scope context (session date, request ID). `ScopedValue` is safe with virtual threads and cannot leak across unrelated tasks:

```java
static final ScopedValue<LocalDate> SESSION_DATE = ScopedValue.newInstance();

ScopedValue.where(SESSION_DATE, today).run(() -> {
    // SESSION_DATE.get() returns today for all code within this scope
});
```

On Java 25+, do not use `ThreadLocal` for new code. Migrate existing `ThreadLocal` usage to `ScopedValue` where the value is immutable within a logical scope.

## Concurrency

- Prefer `java.util.concurrent` types over raw `synchronized`/`wait`/`notify`.
- Use `volatile` only for a single-variable visibility guarantee with no compound check-then-act. For compound operations use a lock or atomic.
- Thread-safe collections: `ConcurrentHashMap`, `CopyOnWriteArrayList`, `LinkedBlockingQueue`. Plain `HashMap`/`ArrayList` are not safe for concurrent access.
- Document thread-safety on every class that is shared across threads via a Javadoc sentence: `This class is thread-safe.` or `Instances of this class are not thread-safe; each thread must use its own instance.`

## Enums

- Prefer `enum` over `int` or `String` constants for bounded sets of values.
- Enums can carry fields and methods — use them to co-locate behaviour with the constant:
  ```java
  enum SessionPhase {
      RECORDING, DRAINING, FLUSHING, DUMPING;

      public boolean isPostRecord() {
          return this != RECORDING;
      }
  }
  ```
- Never compare enums with `.equals()` — use `==`.

## Streams

- Use streams for transformations and reductions on collections. Use loops when order of execution or external mutation matters.
- No side effects inside stream operations (`map`, `filter` lambdas must not modify external state).
- Prefer method references over equivalent lambdas: `String::toLowerCase` over `s -> s.toLowerCase()`.
- Don't chain more than ~4 operations without extracting a named method — readability degrades fast.
- Avoid `Stream.forEach` when a plain enhanced-for loop is clearer.

## Autoboxing

- Declare fields and locals as primitives (`int`, `long`, `double`) unless nullability is required.
- Never use boxed types in arithmetic — keep everything primitive or unbox explicitly.
- `Long l = null` as a sentinel is a design smell — use `OptionalLong` or a boolean flag instead.

## Static utility classes

A class containing only static helper methods must be `final` with a private constructor:

```java
public final class TimeUtils {
    private TimeUtils() {}

    public static long toEpochMicros(Instant instant) { ... }
}
```

## What to avoid

- Wildcard imports.
- `System.out.println` / `System.err.println` — use a logger.
- Raw types (`List` instead of `List<String>`).
- Mutable `public` fields — use accessors or records.
- Suppressing SpotBugs with `@SuppressFBWarnings` without a comment explaining why.
- Suppressing Checkstyle with `// CHECKSTYLE:OFF` — fix the root cause instead.