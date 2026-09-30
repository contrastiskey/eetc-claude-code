---
name: rust-tests
description: >
  Rust testing conventions: unit vs integration vs doc tests, naming,
  Arrange-Act-Assert, assertions on whole values, table-driven and snapshot
  tests, fakes over mocks, async tests, and what to avoid (should_panic,
  ignore, sleeps, shared global state).
  TRIGGER when: writing, editing, or reviewing Rust test code.
  DO NOT TRIGGER when: working in a non-Rust language, or only on production
  code.
---

# Rust Test Conventions

General Rust style (naming, errors, docs) lives in `eetc:rust-code-style`.
Project-specific test commands, fixtures and fakes live in the repo's CLAUDE.md
or `codebase-overview` skill.

## Where tests live

| Kind | Location | Tests |
|------|----------|-------|
| Unit | `#[cfg(test)] mod tests` at the bottom of the file under test | Module internals, including private functions |
| Integration | `tests/*.rs` — each file is its own crate | Only the crate's public API |
| Doc | ```` ``` ```` blocks in `///` / `//!` comments | Public API examples, run by `cargo test` |

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_returns_tick_when_input_valid() {
        // ...
    }
}
```

- Shared integration-test helpers go in `tests/common/mod.rs` (not
  `tests/common.rs`, which cargo would run as its own test crate).
- Test-only dependencies go in `[dev-dependencies]`.

## Running

| Command | What it runs |
|---------|-------------|
| `cargo test` | Everything: unit, integration, doc |
| `cargo test parse_` | Tests whose path contains `parse_` |
| `cargo test --lib` | Unit tests only |
| `cargo test --test orders` | One integration test file (`tests/orders.rs`) |
| `cargo test --doc` | Doc tests only |
| `cargo test -- --nocapture` | Show `println!` output of passing tests |

Add `--workspace` in a workspace and `--all-features` if the crate has feature
gated code. If the repo uses `cargo nextest run`, use that instead (it doesn't
run doc tests — follow with `cargo test --doc`).

## Naming and structure

- Test function name: `<subject>_<behavior>_when_<condition>`, snake_case, no
  `test_` prefix — the `#[test]` attribute and `tests` module already say it.
  Examples: `parse_returns_err_when_input_empty`,
  `flush_writes_all_rows_when_buffer_full`.
- Arrange–Act–Assert, with a blank line between the three blocks.
- One behavior per test.

```rust
#[test]
fn apply_fill_reduces_open_quantity_when_partial() {
    let mut order = Order::new(Side::Buy, 10);

    order.apply_fill(4);

    assert_eq!(order.open_quantity(), 6);
    assert_eq!(order.status(), Status::PartiallyFilled);
}
```

## Minimal tests

From the rust-analyzer style guide:

- Keep fixtures minimal — strip everything the test doesn't need.
- Multi-line input goes in an unindented raw string literal:

  ```rust
  let input = r#"
  symbol,price
  SPY,500.25
  "#;
  ```
- When many tests exercise the same function, write one `check` helper and
  make every test a single call with data. The helper is the only place that
  knows how to run the code:

  ```rust
  fn check(input: &str, expected: &[Tick]) {
      let ticks = parse(input).unwrap();
      assert_eq!(ticks, expected);
  }

  #[test]
  fn parse_skips_header_when_present() {
      check("symbol,price\nSPY,500\n", &[Tick::new("SPY", 500)]);
  }
  ```

## Assertions

- `assert_eq!(actual, expected)` / `assert_ne!` over `assert!(a == b)` — they
  print both values on failure.
- Compare **whole values**, not one field at a time: derive `PartialEq` and
  `Debug` on the type (the code-style skill already asks for them) and assert
  on the full struct or `Vec`. Checking `result.len() > 0` and `result[0]` is
  not enough.
- Match error variants with `matches!`, not string comparison:

  ```rust
  assert!(matches!(res, Err(ParseError::Empty)), "got {res:?}");
  ```
- Add a message with context when the assertion alone won't explain the
  failure (loop iteration, input): `assert_eq!(got, want, "input: {input:?}");`
- Floats: compare with a tolerance, never `==`.
- `unwrap()` / `expect()` are fine in tests — a panic reports the exact line,
  a `-> Result` test only prints the error. Use `expect("what should have
  worked")` when the reason isn't obvious.

### No `#[should_panic]`, no `#[ignore]`

- Don't use `#[should_panic]`. Return and assert on the `Err` / `None`
  instead; if the code panics on purpose, prefer changing it to return an error.
- Don't `#[ignore]` a test for wrong behavior. Assert the **current** behavior
  and add a `// FIXME:` — when someone fixes the bug, the test change makes it
  visible.
- The one allowed `#[ignore]` is for tests that need real infrastructure, with
  a reason: `#[ignore = "needs postgres"]`, run via
  `cargo test -- --ignored`. The repo's CLAUDE.md says how to start it.

## Table-driven tests

For many inputs with the same assertion, loop over a table and put the case in
the failure message:

```rust
#[test]
fn is_valid_quantity_matches_table() {
    let cases = [(0, true), (-1, false), (9_999_999, true)];

    for (quantity, expected) in cases {
        assert_eq!(is_valid_quantity(quantity), expected, "quantity: {quantity}");
    }
}
```

Use `rstest` `#[case]`s instead only if the repo already depends on it.

## Snapshot tests

For large or structured output (rendered text, JSON, debug dumps), use the
snapshot crate the repo already has — `expect-test` (`expect![[...]]`, update
with `UPDATE_EXPECT=1 cargo test`) or `insta` (`assert_snapshot!`, review with
`cargo insta review`). Review every snapshot change; never bulk-accept.

## External dependencies

- **Never call a real external API or service** in unit tests.
- Put a trait at the boundary (HTTP client, broker, clock, repository) and
  write a small hand-written fake for tests. Reach for `mockall` only if the
  repo already uses it.

  ```rust
  trait PriceSource {
      fn latest(&self, symbol: &str) -> Result<Price>;
  }

  struct FakePrices(HashMap<String, Price>);

  impl PriceSource for FakePrices {
      fn latest(&self, symbol: &str) -> Result<Price> {
          self.0.get(symbol).copied().context("no price")
      }
  }
  ```
- HTTP clients: test against a local mock server (`wiremock`, `mockito`,
  `httpmock` — whichever the repo uses), not the real endpoint.
- Time: pass `now` (or a clock trait) into the code under test; never call
  `SystemTime::now()` / `Utc::now()` inside logic you test.
- Filesystem: `tempfile::tempdir()`; never write to fixed paths.

## Async tests

- `#[tokio::test]` (or the runtime the repo uses) for async code.
- Time-dependent async code: `#[tokio::test(start_paused = true)]` and
  `tokio::time::advance` instead of real sleeps (needs tokio's `test-util`
  feature in `[dev-dependencies]`).

## Other test types

- **Doc tests** follow `eetc:rust-code-style` → Documentation (`?`, hidden
  `main`). Mark examples that need network or disk `no_run`, and API-misuse
  examples `compile_fail`. Avoid `ignore`.
- **Trait-bound checks**: compile-time assertions such as `Send + Sync`
  (see `eetc:rust-code-style` → C-SEND-SYNC) go in the unit `tests` module.
- **Property tests**: `proptest` / `quickcheck` if the repo has one, for
  parsers and round-trips (`decode(encode(x)) == x`).

## What to avoid

- `std::thread::sleep` / real-time waits — inject time or pause the runtime.
- Global mutable state between tests: tests run in parallel threads. Don't
  set env vars (`std::env::set_var` is `unsafe` since edition 2024), don't
  share fixed file paths or ports — use temp dirs and port `0`.
- Asserting on log output — test behavior.
- Testing third-party crates or std — test your own logic.
- `#[allow(dead_code)]` on test helpers — delete unused helpers.
