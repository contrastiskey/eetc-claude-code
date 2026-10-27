---
name: go-tests
description: >
  Go testing conventions that follow established industry standards: the Go
  wiki's Test Comments, the test sections of the Google Go Style Guide, and
  the testing package. Covers where tests live, naming, useful failure
  messages (got before want, function and input named), cmp diffs, t.Error
  vs t.Fatal, table-driven tests and subtests, test helpers, fakes and real
  transports, examples, benchmarks, fuzz tests, and what to avoid
  (assertion libraries, sleeps, shared global state).
  TRIGGER when: writing, editing, or reviewing Go test code (_test.go files).
  DO NOT TRIGGER when: working in a non-Go language, or only on production
  code.
---

# Go Test Conventions

Sources: [Go Test Comments](https://go.dev/wiki/TestComments), the test
sections of the Google Go Style Guide
([decisions](https://google.github.io/styleguide/go/decisions#useful-test-failures),
[best practices](https://google.github.io/styleguide/go/best-practices#tests)),
and the [`testing`](https://pkg.go.dev/testing) package.

General Go style (naming, errors, docs) lives in `eetc:go-code-style`.
Project-specific test commands, fixtures and fakes live in the repo's
CLAUDE.md or `codebase-overview` skill.

## Where tests live

| Kind | File | Package |
|------|------|---------|
| Unit | `foo_test.go` next to `foo.go` | `package foo`: can reach unexported names |
| Black box | `foo_test.go` next to `foo.go` | `package foo_test`: only the public API; also breaks import cycles |
| Example | `example_test.go` | `package foo_test`, so examples show the `foo.` qualifier users write |
| Fixtures | `testdata/` | ignored by the go tool |

- Test doubles that other packages' tests need go in a `footest` package
  next to `foo` (`creditcardtest.Stub`), never in `foo` itself.
- Tests that need real infrastructure skip under `-short`
  (`if testing.Short() { t.Skip("needs postgres") }`), or use the build tag
  the repo already has.

## Running

| Command | What it runs |
|---------|-------------|
| `go test ./...` | Every package in the module |
| `go test ./internal/orders` | One package |
| `go test -run 'TestParse$' ./parser` | Tests matching the regexp |
| `go test -run 'TestParse/empty_input' ./parser` | One subtest |
| `go test -race ./...` | With the race detector; always for concurrent code |
| `go test -count=1 ./...` | Without the test result cache |
| `go test -short ./...` | Skips long tests |
| `go test -bench=. -benchmem -run='^$' ./...` | Benchmarks only |
| `go test -fuzz=FuzzParse -fuzztime=30s ./parser` | One fuzz target |

`go test` runs a subset of `go vet` first; a vet finding fails the run.

## Naming

- `func TestXxx(t *testing.T)` names what it tests: `TestParse`,
  `TestClient_Do` for a method. A suffix splits a function's tests by kind:
  `TestParse_Errors`.
- Subtest names are short identifiers, readable in the output and easy to
  pass to `-run`. No spaces (they become `_`) and no slashes (they split
  the `-run` pattern): `t.Run("empty_input", ...)`, not
  `t.Run("returns an error when the input is empty", ...)`. A longer
  description goes in a separate field and the failure message.
- `got` holds the result, `want` the expectation.

## Failure messages

A failure must be diagnosable without reading the test.

- Name the function and its input, then got before want:

  ```go
  if got != want {
  	t.Errorf("Parse(%q) = %v, want %v", in, got, want)
  }
  ```

  Not `t.Errorf("got %v, want %v", got, want)`, and never "expected X,
  got Y".
- `%q` for strings, `%+v` for small structs. If the input is large, name
  the case and print the name instead.
- Large values: print a diff, say which direction it goes, and start it on
  a new line:

  ```go
  if diff := cmp.Diff(want, got); diff != "" {
  	t.Errorf("Parse(%q) mismatch (-want +got):\n%s", in, diff)
  }
  ```
- Setup failures need less detail: `t.Fatalf("setup: create table: %v", err)`.
- Never identify a table row by its index. Print the input or the case
  name.

## Comparisons

- `==` / `!=` for comparable values. For slices, maps and structs use
  `cmp.Diff` / `cmp.Equal` from `github.com/google/go-cmp/cmp`, which the Go
  team maintains; add it to `go.mod` if it's missing.
- Compare whole values: build the expected struct, slice or map and compare
  once, not field by field. Shape the comparison with `cmpopts`
  (`IgnoreFields`, `EquateEmpty`, `EquateApprox` for floats, `SortSlices`)
  and `protocmp.Transform()` for protobuf messages.
- Several return values: compare each one; don't wrap them in a struct.
- Not `reflect.DeepEqual`: it depends on unexported fields and other
  implementation details.
- Compare stable, meaningful results. Unmarshal JSON and compare the data;
  don't compare the bytes of `json.Marshal` or other output you don't own.
- Errors: check what they mean, never their text. `errors.Is(err,
  ErrNotFound)`, `errors.As`, or `cmpopts.EquateErrors()`. When the test only
  cares that it failed, a `wantErr bool` and `(err != nil) != tt.wantErr`
  are enough. Text checks are fine only for properties of your own
  package's messages (it names the bad field).

## t.Error vs t.Fatal

- Keep going: report mismatches with `t.Error`, so one run shows every
  failure.
- `t.Fatal` when nothing after it makes sense: setup failed, an unexpected
  error leaves no result to check, or the next check depends on this one.
- In a table loop without subtests: `t.Error`, then `continue`. Inside
  `t.Run`: `t.Fatal`, which ends only that subtest.
- Never call `t.Fatal`, `t.FailNow` or `t.SkipNow` from a goroutine the test
  started; call `t.Error` and return.

## Table-driven tests

Use a table when many cases run the same logic:

```go
func TestParseDuration(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want time.Duration
	}{
		{name: "seconds", in: "90s", want: 90 * time.Second},
		{name: "hours", in: "2h", want: 2 * time.Hour},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ParseDuration(tt.in)
			if err != nil {
				t.Fatalf("ParseDuration(%q) returned unexpected error: %v", tt.in, err)
			}
			if got != tt.want {
				t.Errorf("ParseDuration(%q) = %v, want %v", tt.in, got, tt.want)
			}
		})
	}
}
```

- Field names in the case literals; leave out zero-value fields that don't
  matter to a case.
- Cases that need different checks get their own test: a table for valid
  input and one for errors (`TestParse`, `TestParse_Errors`), not `if`
  branches on row fields. No row field that picks the setup (fake or real);
  write two tests.
- Subtests don't depend on each other: each one runs alone under `-run`.
- Before Go 1.22 (the `go` line in `go.mod`), copy the loop variable
  (`tt := tt`) before `t.Run` with `t.Parallel()`; from 1.22 on, don't.
- `t.Parallel()` only when cases share no mutable state.

## Test helpers

- A helper sets up or cleans up. It takes `t` (after `ctx`, if any), calls
  `t.Helper()` first, and calls `t.Fatalf` with a description when setup
  fails. `mustXxx` suits a helper that returns a value or stops the test:

  ```go
  func mustReadFile(t *testing.T, name string) []byte {
  	t.Helper()
  	data, err := os.ReadFile(filepath.Join("testdata", name))
  	if err != nil {
  		t.Fatalf("read fixture %s: %v", name, err)
  	}
  	return data
  }
  ```
- No assertion helpers (`assertEqual(t, got, want)`) and no assertion
  libraries (testify's `assert` / `require`, gomega). The check and the
  failure stay in the `Test` function. Shared validation returns an `error`
  or a `cmp.Option`, and the test decides how to fail. The Google guide
  rejects "the package already uses them" as a reason; only a project rule
  in CLAUDE.md overrides this.
- Use the `testing` built-ins: `t.Cleanup`, `t.TempDir()`, `t.Setenv` (not
  with `t.Parallel`), `t.Context()` and `t.Chdir` (Go 1.24).
- Set up only what each test needs, in that test. No shared setup in
  `init`. `TestMain` only when every test in the package needs an expensive
  resource that must be torn down; a `sync.Once` helper for expensive setup
  without teardown that only some tests use.

## Test doubles and external services

- Never call a real external service from a unit test.
- Hand-written fakes over generated mocks. Implement the small interface
  the consumer defines (see `eetc:go-code-style` → Interfaces) and name
  the double by its behavior: `AlwaysCharges`, `AlwaysDeclines`, or `Stub`,
  `Fake`, `Spy` inside a `footest` package. Use gomock or mockery only if
  the repo already does.
- Use the real transport: test an HTTP client against `httptest.NewServer`
  and a gRPC client against a test server (`bufconn`), not a hand-written
  fake client.
- Don't add exported interfaces, hooks or setters to production code just
  for tests.
- Time: pass a clock or `now func() time.Time` in, or run the test inside
  `testing/synctest` (Go 1.25) so sleeps and timers use fake time. Random
  input: pass a seeded source in.
- Files: `t.TempDir()`; fixtures under `testdata/`.

## Other test types

- **Examples** (`func ExampleParse()`, `func ExampleClient_Do()`) with an
  `// Output:` comment are documentation that runs. Each new package gets
  one for its main API.
- **Benchmarks**: `for b.Loop() { Parse(input) }` (Go 1.24); before that,
  `b.ResetTimer()` after setup and `for range b.N`.
- **Fuzz tests** (`func FuzzParse(f *testing.F)`, seeded with `f.Add`) for
  parsers and round-trips like `Decode(Encode(x)) == x`. A failing input
  is saved under `testdata/fuzz/`; commit it so it runs as a regular case.
- **Golden files**: large expected output in `testdata/*.golden`,
  regenerated with an `-update` flag, only if the repo already has that
  pattern. Review every golden diff.
- **Acceptance tests** for an interface other packages implement: a
  `footest` function that exercises an implementation and returns an
  `error`, like `fstest.TestFS`.

## What to avoid

- Assertion libraries and assertion helpers.
- `time.Sleep` to wait for something; tests that pass only with the right
  timing.
- Global state shared between tests, and tests that depend on running
  order.
- `reflect.DeepEqual`; comparing error text or serialized bytes.
- `t.Fatal` from a goroutine the test started.
- Table rows identified by index.
- Testing the standard library or third-party packages instead of your own
  code.
