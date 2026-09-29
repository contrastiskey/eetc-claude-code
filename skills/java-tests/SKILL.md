---
name: java-tests
description: >
  Java testing conventions: JUnit 5, AssertJ, Mockito, naming, Arrange-Act-Assert,
  parameterized tests, Testcontainers integration tests, soft assertions,
  assumptions, @TestInstance and @Nested naming.
  TRIGGER when: writing, editing, or reviewing Java test code.
  DO NOT TRIGGER when: working in a non-Java language, or only on production
  code.
---

# Java Test Conventions

## Project setup

- Tests live in `src/test/java/` (standard Maven layout).
- Run all tests: `mvn test`
- Run a single class: `mvn -Dtest=ClassName test`
- Run a single method: `mvn -Dtest=ClassName#methodName test`
- Common dependencies (add to `pom.xml` when needed):
  - `junit-jupiter-api` + `junit-jupiter-engine` — core JUnit 5
  - `junit-jupiter-params` — parameterized tests
  - `mockito-core` + `mockito-junit-jupiter` — mocking
  - `assertj-core` — fluent assertions (preferred over plain `Assertions.*`)

## Naming and structure

- Test class name: `<Subject>Test` (e.g., `UserServiceTest` for `UserService`).
- Test method name: `methodName_should_expectedBehavior_when_condition` (snake_case throughout).
  - Examples: `save_should_persistRecord`, `parse_should_throwException_when_inputEmpty`
- Follow Arrange–Act–Assert (AAA) inside every test. Use a blank line to separate each section.
- One behaviour per test. Never assert two independent behaviours in a single `@Test`.
- Use `@DisplayName` when the method name alone isn't self-explanatory to a human skimming results.

```java
@Test
@DisplayName("Resource is closed before the worker thread exits")
void close_should_flushAndRelease_when_threadShutdown() {
    // Arrange
    var resource = mock(Resource.class);
    var worker = new Worker(resource);

    // Act
    worker.close();

    // Assert
    verify(resource).flush();
}
```

## JUnit 5 annotations

| Annotation | When to use |
|---|---|
| `@Test` | Single-scenario test |
| `@ParameterizedTest` | Same logic, multiple inputs |
| `@BeforeEach` / `@AfterEach` | Per-test setup / teardown |
| `@BeforeAll` / `@AfterAll` | Expensive shared state (must be `static`) |
| `@Nested` | Group related scenarios inside one test class |
| `@Tag` | Categorise: `"unit"`, `"integration"`, `"slow"` |
| `@Disabled("reason")` | Skip temporarily — always include a reason |
| `@TestMethodOrder` + `@Order` | Only when order genuinely matters (rare) |

## Assertions

Prefer **AssertJ** over bare `Assertions.*` — it produces better failure messages and reads like prose:

```java
// Preferred (AssertJ)
assertThat(result).isEqualTo(expected);
assertThat(items).hasSize(3).extracting(Item::name).containsOnly("foo");
assertThatThrownBy(() -> service.process(null)).isInstanceOf(NullPointerException.class);

// Acceptable for trivial checks
assertEquals(expected, actual, "descriptive failure message");
assertNotNull(result);
```

Use `assertAll` to group independent assertions so all failures are reported at once:

```java
assertAll(
    () -> assertThat(record.id()).isEqualTo(42),
    () -> assertThat(record.name()).isEqualTo("example")
);
```

## Mocking (Mockito)

- Use `@ExtendWith(MockitoExtension.class)` on the test class.
- Declare mocks with `@Mock`; inject into the subject with `@InjectMocks`.
- Stub only what the test needs — don't over-specify.
- Verify interactions when the behaviour *is* the interaction (e.g., verifying a collaborator was called). Don't verify purely internal calls.

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock Repository repository;
    @InjectMocks OrderService service;

    @Test
    void submit_should_persist_when_orderValid() {
        var order = new Order("item-1", 2);

        service.submit(order);

        verify(repository).save(order);
    }
}
```

## Parameterized tests

Use `@MethodSource` for anything non-trivial (objects, computed values); use `@CsvSource` for simple tabular data:

```java
@ParameterizedTest
@CsvSource({"0, true", "-1, false", "9999999, true"})
void isValidQuantity_should_returnExpected(int quantity, boolean expected) {
    assertThat(Order.isValidQuantity(quantity)).isEqualTo(expected);
}

@ParameterizedTest
@MethodSource("malformedInputProvider")
void process_should_reject_when_inputMalformed(Input input) {
    assertThatThrownBy(() -> service.process(input)).isInstanceOf(IllegalArgumentException.class);
}

static Stream<Input> malformedInputProvider() {
    return Stream.of(Input.withNullId(), Input.withNegativeAmount());
}
```

## Integration tests

- Tag integration tests with `@Tag("integration")` and run them separately from unit tests.
- Do not spin up real external systems (databases, brokers, cloud services) in unit tests — use mocks or in-process fakes.
- Use `@TempDir` for tests that need filesystem access so they don't touch real paths:

```java
@Test
void export_should_writeFile_when_dataAvailable(@TempDir Path outputDir) {
    var exporter = new Exporter(outputDir);
    exporter.run();
    assertThat(outputDir.resolve("output.json")).exists();
}
```

- Inject `java.time.Clock` into components that depend on the current time — never call `Instant.now()` or `LocalDate.now()` directly inside logic under test:

```java
var fixedClock = Clock.fixed(Instant.parse("2026-01-15T10:00:00Z"), ZoneOffset.UTC);
var scheduler = new Scheduler(fixedClock);
assertThat(scheduler.isDue()).isTrue();
```

## Test organisation

- Tag every test class with at least one of: `@Tag("unit")`, `@Tag("integration")`, `@Tag("slow")`.
- Keep unit tests fast (<100 ms each). Anything that hits a network, disk, or real external system is an integration test.
- Place shared test fixtures and builders in `src/test/java/<package>/fixtures/`.
- Do not share mutable state between tests via static fields — prefer `@BeforeEach` re-initialisation.

## Testcontainers

Use **Testcontainers** for integration tests that need real infrastructure (brokers, databases, cloud emulators). The repo's CLAUDE.md lists which containers it uses. Never mock these at the network level in integration tests; the whole point is to verify real wire behaviour.

Add the dependency to `pom.xml`:
```xml
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>testcontainers</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>postgresql</artifactId>
    <scope>test</scope>
</dependency>
```

Declare containers as `static` fields with `@Container` and annotate the class with `@Testcontainers`:

```java
@Testcontainers
@Tag("integration")
class OrderRepositoryIT {

    @Container
    static final PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>(DockerImageName.parse("postgres:16"));

    @Test
    void save_should_persistOrder_when_orderValid() {
        // use postgres.getJdbcUrl() to wire up the repository
    }
}
```

- Always `static` containers when shared across tests in the class — start/stop is expensive.
- Tag integration tests `@Tag("integration")` and wire Maven Failsafe or a profile to run them separately from unit tests.
- Guard tests that require Docker with `assumeTrue(isDockerAvailable())` so the build doesn't hard-fail in environments without Docker.

## Soft assertions

Use `SoftAssertions` when checking multiple fields on the same object — all failures are collected and reported at once instead of stopping at the first:

```java
@Test
void tick_should_haveCorrectFields_when_parsed() {
    var tick = TickParser.parse(rawBytes);

    SoftAssertions.assertSoftly(soft -> {
        soft.assertThat(tick.symbol()).isEqualTo("SPY");
        soft.assertThat(tick.exchangeTs()).isPositive();
        soft.assertThat(tick.price()).isGreaterThan(0L);
    });
}
```

Prefer `SoftAssertions` over `assertAll` when using AssertJ — the failure messages are richer.

## `ArgumentCaptor`

Use `ArgumentCaptor` to inspect arguments passed to a mock when the argument itself is the thing under test:

```java
@Test
void write_should_sendCorrectSymbol_when_tickReceived() {
    var captor = ArgumentCaptor.forClass(Tick.class);

    service.onMessage(rawRecord);

    verify(writer).write(captor.capture());
    assertThat(captor.getValue().symbol()).isEqualTo("SPY");
}
```

Only use captors when you can't express the assertion via `verify(mock).method(argThat(...))` — captors are more verbose.

## Spy vs mock

| Use | When |
|-----|------|
| `@Mock` | Full replacement — you control all behaviour. Use for collaborators. |
| `@Spy` | Partial replacement — real methods run unless explicitly stubbed. Use to test one overridden method while keeping others real. |

```java
@Spy
TickFormatter formatter; // real implementation, but can stub individual methods

@Test
void format_should_delegate_when_symbolAbsent() {
    doReturn("UNKNOWN").when(formatter).resolveSymbol(any());
    assertThat(formatter.format(tick)).startsWith("UNKNOWN");
}
```

Avoid `@Spy` on classes with heavy constructors or external dependencies — use `@Mock` and be explicit.

## Additional parameterized sources

Beyond `@CsvSource` and `@MethodSource`:

```java
// Simple single-argument cases
@ParameterizedTest
@ValueSource(strings = {"", "  ", "\t"})
void parse_should_throw_when_symbolBlank(String symbol) {
    assertThatThrownBy(() -> Tick.of(symbol, 0L, 0L))
        .isInstanceOf(IllegalArgumentException.class);
}

// Explicitly include null as an input
@ParameterizedTest
@NullSource
void parse_should_throw_when_symbolNull(String symbol) {
    assertThatThrownBy(() -> Tick.of(symbol, 0L, 0L))
        .isInstanceOf(NullPointerException.class);
}

// Null + blank in one go
@ParameterizedTest
@NullAndEmptySource
void parse_should_throw_when_symbolNullOrEmpty(String symbol) { ... }
```

## `@TestInstance` and non-static `@BeforeAll`

By default, JUnit 5 creates a new test instance per method, so `@BeforeAll` methods must be `static`. Use `@TestInstance(Lifecycle.PER_CLASS)` when you need a non-static `@BeforeAll` — useful for expensive shared state (e.g. a Testcontainers container reference held as an instance field):

```java
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class OrderRepositoryIT {

    PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>(...);

    @BeforeAll
    void startContainer() {
        postgres.start(); // non-static, allowed under PER_CLASS
    }
}
```

Only use `PER_CLASS` when you have a concrete reason — it means test methods share instance state, which can cause unexpected coupling.

## Assumptions

Use `assumeTrue` / `assumeFalse` to skip a test when a precondition isn't met, rather than failing it:

```java
@Test
void upload_should_succeed_when_dockerAvailable() {
    assumeTrue(isDockerAvailable(), "skipped: Docker not available");
    // test body runs only when Docker is present
}
```

Assumptions cause the test to be reported as aborted (skipped), not failed — correct for environment-dependent tests.

## `@Nested` class naming

Name `@Nested` classes as noun phrases or `when_<condition>` clauses that complete the sentence formed by the outer class name:

```java
class TickParserTest {

    @Nested
    class WhenInputIsValid { ... }

    @Nested
    class WhenSymbolIsBlank { ... }

    @Nested
    class WhenTimestampOverflows { ... }
}
```

This reads as "TickParserTest > WhenInputIsValid > ..." in test reports, which is self-explanatory without opening the code.

## What to avoid

- `Thread.sleep` for timing — inject a `Clock` instead.
- Asserting on log output — test behaviour, not log side-effects.
- Testing private methods directly — if you feel the need, the class likely needs splitting.
- Opening real network or external service connections in unit tests.
- `@Disabled` without a reason or a linked issue.