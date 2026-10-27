---
name: go-code-style
description: >
  Go coding conventions that follow established industry standards: Effective
  Go, the Go wiki's Code Review Comments, the Go Doc Comments guide, and the
  Google Go Style Guide (guide, decisions and best practices). Covers tooling,
  formatting, naming, packages and imports, errors, panics, declarations,
  control flow, functions, receivers, interfaces, generics, contexts,
  concurrency, global state, logging and doc comments.
  TRIGGER when: writing, editing, formatting, or reviewing Go code (.go
  files), or asked to "fix style" / "check code quality" in a Go project.
  DO NOT TRIGGER when: working in a non-Go language, or only reading code
  without making changes.
---

# Go Code Style

Sources. Earlier ones win a disagreement:

1. The Go team's guides: [Effective Go](https://go.dev/doc/effective_go),
   [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments) and
   [Go Doc Comments](https://go.dev/doc/comment). Effective Go dates from
   2009: it predates modules, generics and error wrapping, and its
   `interface{}` is `any` today.
2. The [Google Go Style Guide](https://google.github.io/styleguide/go/):
   its [guide](https://google.github.io/styleguide/go/guide),
   [decisions](https://google.github.io/styleguide/go/decisions) and
   [best practices](https://google.github.io/styleguide/go/best-practices).
   Its Google-internal parts (Bazel, glog, the internal flag package) are
   left out.
3. The [Go release notes](https://go.dev/doc/devel/release), for language
   features and the versions that introduced them.

Test rules live in `eetc:go-tests`. Project-specific commands live in the
repo's CLAUDE.md.

## Principles

In order of importance: **clarity** (the reader sees what the code does and
why), **simplicity**, **concision** (a high signal-to-noise ratio),
**maintainability**, **consistency**. Code is read far more often than it is
written.

- **Least mechanism.** Use a core language construct (slice, map, struct,
  channel, loop) when it's enough, then the standard library, then a
  dependency the repo already has. A `map[string]bool` is a set; don't add a
  set library.
- **Local consistency.** A question this skill doesn't settle: do what the
  surrounding file or package does. It never justifies breaking a rule here,
  or spreading an existing violation to new files or APIs.

## Tooling

- Every file is `gofmt`-formatted, generated code included. `goimports`
  (gofmt plus import fixing) is fine. Don't hand-format against it.
- `go vet ./...` passes, and so does the repo's linter (`golangci-lint run`,
  `staticcheck`) when it has one. Never loosen the linter config to get a
  change through. A suppression is on the narrowest line, names the check
  and says why: `//nolint:gosec // fixed path, not user input`.
- Check the `go` line in `go.mod` before using newer features:

  | Feature | Go |
  |---------|----|
  | Generics, `any` | 1.18 |
  | `errors.Join`, several `%w` in one `fmt.Errorf` | 1.20 |
  | `min` / `max` / `clear`; `slices`, `maps`, `cmp`, `log/slog`; `context.WithoutCancel` | 1.21 |
  | A new loop variable per iteration; `for i := range n` | 1.22 |
  | Range-over-func iterators (`iter.Seq`) | 1.23 |
  | Generic type aliases; `t.Context()`, `b.Loop()`; `omitzero`; `strings.Lines`, `strings.SplitSeq`; `crypto/rand.Text` | 1.24 |
  | `sync.WaitGroup.Go`, `testing/synctest` | 1.25 |
  | `new(expr)`, `errors.AsType` | 1.26 |
  | Generic methods, `encoding/json/v2` | 1.27 |

- Before 1.22, a closure or goroutine in a loop shares one loop variable
  across iterations; copy it (`v := v`) in those modules only.
- After changing imports, run `go mod tidy` and keep `go.mod` and `go.sum`
  in sync.

## Formatting beyond gofmt

- No fixed line length. If a line feels too long, refactor it (extract a
  local, shorten names) instead of wrapping it. Never split a long string or
  URL to fit.
- Don't break a line so the rest lines up with the indented block below it.
  Keep `func` signatures, `if`, `for`, `switch` and `case` lines on one
  line; extract operands into named locals instead:

  ```go
  // Good
  inTransaction := db.CurrentStatusIs(db.InTransaction)
  keysMatch := db.ValuesEqual(db.TransactionKey(), row.Key())
  if inTransaction && keysMatch {
  	// ...
  }

  // Bad
  if db.CurrentStatusIs(db.InTransaction) &&
  	db.ValuesEqual(db.TransactionKey(), row.Key()) {
  	// ...
  }
  ```
- Don't wrap call arguments for length alone. Break them only to group them
  by meaning. Don't label arguments with inline comments (`42, // port`);
  use an option struct.
- A multi-line composite literal ends each line with a comma and puts the
  closing brace on its own line, indented like the opening line. Omit
  repeated type names in slice and map literals: `[]*T{{A: 1}}`, not
  `[]*T{&T{A: 1}}`.
- Variable on the left of a comparison: `if result == "foo"`, not
  `if "foo" == result`.

## Naming

- `MixedCaps` / `mixedCaps`, never underscores, constants included:
  `MaxLength` / `maxLength`, not `MAX_LENGTH` or `kMaxLength`. Exceptions:
  `Test`, `Benchmark` and `Example` function names in `_test.go` files, and
  identifiers mirroring OS or cgo names. File names may use underscores.
- Initialisms keep one case: `ServeHTTP`, `userID`, `parseURL`,
  `xmlHTTPRequest`; never `ServeHttp`, `userId`, `Url`. Initialisms with a
  lowercase letter keep their prose form unless exportedness forces the
  first letter: `gRPC` → `GRPC` / `gRPC`, `iOS` → `IOS` / `iOS`.
- Name length grows with scope and shrinks with use: `i`, `n`, `r`, `w` in
  a few lines, descriptive names for package-level identifiers. Don't drop
  letters to save typing: `Sandbox`, not `Sbx`.
- No types in names: `users`, not `userSlice`; `userCount`, not `numUsers`.
  Qualify only when two forms of a value are in scope: `limitRaw` and
  `limit`.
- Don't repeat context. Callers see the package name, so `widget.New`, not
  `widget.NewWidget`; `chubby.File`, not `chubby.ChubbyFile`; in package
  `sqldb`, `Connection`, not `DBConnection`. Methods don't repeat the
  receiver (`c.WriteTo`, not `c.WriteConfigTo`), and functions don't repeat
  their parameters or results (`Override(dst, src)`, not
  `OverrideFirstWithSecond`).
- Functions that return something get noun names; functions that do
  something get verb names. No `Get` prefix: `Owner()`, `Counts()`, with a
  setter `SetOwner()`. Use `Fetch` or `Compute` when the call is slow or
  remote. Type variants go at the end: `ParseInt`, `ParseInt64`.
- One-method interfaces are the method name plus *-er*: `Reader`,
  `Stringer`, `Notifier`. Don't reuse well-known method names (`Read`,
  `Write`, `String`, `Close`) with a different signature or meaning.
- Receivers are one or two letters abbreviating the type (`c` for
  `Client`), the same in every method. Never `this`, `self` or `me`. Omit an
  unused receiver name rather than writing `_`.
- Constants are named for their role, not their value: `MaxPacketSize`, not
  `Twelve`. A value with no role needs no constant.
- Don't shadow a package with a variable outside a tiny scope: `url := ...`
  hides `net/url`.
- `MustXxx` functions panic on failure. Call them only at program start or
  package initialization (`var re = regexp.MustCompile(...)`), never on user
  input.

## Packages and imports

- Package names are short, lowercase and one word, with no underscores or
  capitals (`tabwriter`, `oauth2`), and not a word callers want for a local
  variable (`usercount`, not `count`). Name a package for what it provides:
  no `util`, `common`, `helper`, `misc`, `types`, `models` or `interfaces`.
- Keep types that callers use together, or whose implementations are tightly
  coupled, in one package; give conceptually distinct parts their own small
  package. There is no one-type-per-file rule. A file should be focused
  enough that a maintainer can guess what's in it.
- Imports come in groups separated by blank lines: standard library first,
  then everything else. goimports maintains this. Keep extra groups the
  repo already uses (its own module, then renamed proto imports, then `_`
  imports last).
- Rename an import only to avoid a collision (rename the most local import)
  or to replace an uninformative name (`core "k8s.io/api/core/v1"`). The
  local name follows the package-name rules; add `pkg` to free a common
  variable name (`urlpkg`). Proto packages get a `pb` suffix (`foopb`).
- `import _ "pkg"` only in `package main` or in tests, except
  `import _ "embed"` next to a `//go:embed`.
- No `import .`.

## Errors

- `error` is the last result. Return `nil` on success. When the error is
  non-nil, callers treat the other results as unspecified unless documented.
- Exported functions return the `error` interface, not a concrete error
  type: a nil `*MyError` stored in an `error` is not `nil`.
- Every error is handled, returned or, in `main`, ends the program. Never
  discard one without a comment saying why it can't fail:
  `n, _ := b.Write(p) // bytes.Buffer.Write never fails`. `defer f.Close()`
  is fine after reading; after writing, check the `Close` error.
- Indent the error path, not the happy path. No `else` after a block that
  returns. Declare the value on its own line when it's used after the `if`:

  ```go
  cfg, err := load(path)
  if err != nil {
  	return fmt.Errorf("load config: %w", err)
  }
  // use cfg
  ```
- No in-band errors (`-1`, `""` or `nil` meaning "missing"). Return an extra
  `ok bool` or `error` last: `value, ok := Lookup(key)`.
- Error strings are lowercase (unless they start with a proper noun,
  acronym or exported name) with no trailing punctuation, because they get
  wrapped into other messages: `errors.New("connection refused")`. Log and
  user-facing messages are ordinary sentences.
- Add context the caller doesn't have. Don't repeat what the cause already
  says (`os.Open` errors already name the file), and don't wrap with a bare
  `"failed: %v"`; return `err` instead.
- `%w` or `%v`:
  - `%w` when callers may need `errors.Is` / `errors.As` on the cause and
    that's part of your API. Put it at the end (`"fetch prices: %w"`) so the
    text reads newest to oldest.
  - `%v` to annotate without exposing the cause, especially at system
    boundaries (RPC, storage, HTTP responses) where you translate errors
    into your own error space.
  - A sentinel that categorizes the failure goes first:
    `fmt.Errorf("%w: invalid header: %v", ErrParse, err)`.
- When callers must tell errors apart, give them structure: a sentinel
  (`var ErrNotFound = errors.New("not found")`) or an error type with fields
  (`*fs.PathError`). Name them `ErrXxx` and `XxxError`. Callers use
  `errors.Is`, `errors.As` or `errors.AsType`; never match on `err.Error()`.
- Log an error or return it, not both.

## Panics

- Don't panic for ordinary errors; return an `error`. Libraries return
  errors rather than end the program.
- Panic only for a broken invariant or API misuse that tests should catch
  (like an out-of-range index), in `Must` helpers at initialization, or to
  mark code the compiler can't see is unreachable.
- A package may panic internally (a deeply recursive parser) only if it
  recovers at its API boundary and returns an error. Panics never cross a
  package boundary.
- Don't `recover` to carry on after an unexpected panic; the state may be
  corrupt. Fix the bug.
- Startup errors (bad flags or config) return up to `main`, which prints an
  actionable message and exits non-zero (`log.Fatal(err)`). `log.Fatal` and
  `os.Exit` skip deferred calls.

## Declarations and literals

- `:=` for a new variable with a value; `var x T` for a zero value that is
  ready to use (`var buf bytes.Buffer`, `var p Point` before
  `json.Unmarshal(data, &p)`). `var i int` and `i := 0`, or `&T{}` and
  `new(T)`, are equivalent; follow the file.
- Build values with composite literals, not field by field. Types from
  other packages always get field names. Omit zero-value fields unless the
  zero is the point.
- Empty slices: `var s []T` (nil), not `s := []T{}`, unless it's encoded to
  JSON (`nil` becomes `null`). APIs don't distinguish a nil slice from an
  empty one: check `len(s) == 0`, not `s == nil`.
- A map must be made (`make` or a literal) before writing to it; reading a
  nil map is fine. Add size hints (`make([]T, 0, n)`) only when the size is
  known or a benchmark asks for it.
- `any`, not `interface{}`. A type definition (`type ID string`) for a new
  type; an alias (`type T = U`) only for migrating code between packages.
- Raw strings (backticks) for multi-line constants. Strings: `+` for a few
  pieces, `fmt.Sprintf` for formatting, `strings.Builder` for building in a
  loop, `fmt.Fprintf(w, ...)` straight to an `io.Writer`.
- `%q` for strings in messages, so empty and odd values stay visible.
- Give channel parameters a direction: `func sum(values <-chan int) int`.

## Control flow

- Return early and keep the normal path unindented.
- `if v, err := f(); err != nil` only when `v` and `err` aren't needed after
  the `if`.
- `switch` with no condition instead of a long `if`/`else if` chain. Cases
  don't fall through: no `break` at the end of a case (comment an empty
  case instead), and use a labeled `break` to leave a loop from inside a
  `switch` or `select`.
- `:=` in an inner scope declares a new variable. To change an outer
  variable there, use `=`:

  ```go
  if shorten {
  	var cancel context.CancelFunc
  	ctx, cancel = context.WithTimeout(ctx, 3*time.Second) // =, not :=
  	defer cancel()
  }
  ```
- Mark a condition that looks like a common one but isn't:
  `if err := f(); err == nil { // if NO error`.

## Functions

- Name results only when the names document something (two results of the
  same type, or one the caller must act on, like `cancel func()`) or a
  deferred closure changes them. Not to skip a `var`, not to enable naked
  returns. Naked returns only in a function of a few lines.
- Many parameters: split the function, or take an option struct as the last
  parameter (`server.New(ctx, server.Options{Port: 42})`). Variadic options
  (`opts ...Option`) only when most callers pass none and there are many.
  Options take values (`FailFast(enabled bool)`, not `EnableFailFast()`).
  A context never goes in an option struct.
- Pass small fixed-size values directly: no `*string`, no `*io.Reader`.
  Large structs, structs that may grow, and protobuf messages go by pointer.
- Prefer synchronous functions that return their results. The caller can add
  concurrency; it can't take it away.
- `defer` the cleanup right after acquiring the resource and checking the
  error.

## Types, receivers and interfaces

### Receivers

Correctness first:

- Pointer receiver when the method mutates the receiver, the struct has a
  field that must not be copied (`sync.Mutex`, `bytes.Buffer`), or the
  struct is large. When in doubt, pointer.
- Value receiver for maps, funcs, channels, slices the method doesn't
  reslice, and small immutable value types (`time.Time`, `type UserID
  string`).
- One kind per type: all pointer receivers or all value receivers.
- Don't copy a value whose methods are on `*T`, or one holding a
  `sync.Mutex`: pass and return `*T`.

### Interfaces

- Accept interfaces, return concrete types. The consumer defines a small
  interface with only the methods it calls; the producer returns a concrete
  type. The producer exports the interface only when the interface is the
  product (`io.Writer`, `hash.Hash`).
- Don't create an interface until a real need exists: two implementations
  handled by the same code, a consumer that needs only a slice of a large
  API, or a package cycle to break. A "service" or "repository" doesn't need
  one by default.
- Don't export interfaces or test doubles "for mocking", and don't wrap a
  generated RPC client in a hand-written interface. Tests use the real
  type's public API, a consumer-side interface, or a real transport (see
  `eetc:go-tests`).
- Keep interfaces small, unexported when only the package uses them, and
  document their contract, edge cases and errors.
- A compile-time check (`var _ json.Marshaler = (*RawMessage)(nil)`) only
  when nothing else in the code already proves the type implements it.

### Generics

- Use generics when the same code would otherwise be written for several
  types, or instead of `any` plus type switches. If the types share a
  useful interface, use the interface.
- Not for a single type in practice: write it for that type first. Not for
  DSLs, error-handling frameworks or assertion helpers.
- Exported generic APIs get documentation and a runnable example.

## Contexts

- `ctx context.Context` is the first parameter of anything that does I/O,
  blocks or calls something that does, test helpers included. Such
  functions usually return an `error`, so callers see a cancellation.
- Take the context from the caller: `r.Context()` in HTTP handlers, the
  stream in streaming RPCs, `cmd.Context()` in cobra commands, `t.Context()`
  in tests. `context.Background()` only in `main`, `init` and similar entry
  points.
- Never store a context in a struct field (except to satisfy an interface
  you don't own), and never define a custom context type.
- Context values carry only request-scoped data that crosses API
  boundaries (trace IDs, credentials). Everything else is a parameter.
- Work that must outlive the request uses `context.WithoutCancel(ctx)`, not
  a fresh `context.Background()`.
- `defer cancel()` right after `context.WithTimeout` / `WithCancel`.

## Concurrency

- Every goroutine has an obvious end. Tie it to a context and wait for it
  (`sync.WaitGroup`, `errgroup.Group`) before the function that started it
  returns. If the lifetime isn't obvious from the code, document when and
  why it exits.

  ```go
  var wg sync.WaitGroup
  for item := range items {
  	wg.Go(func() { process(ctx, item) }) // before 1.25: wg.Add(1); go func() { defer wg.Done(); ... }()
  }
  wg.Wait() // no goroutine outlives Run
  ```
- `errgroup` when the first error should cancel the rest.
- Share memory by communicating: channels to pass ownership of data. A
  mutex is fine for simple shared state; keep it next to the fields it
  guards.
- Sending on a closed channel panics; the sender closes, and only once.
- By default a top-level function is safe for concurrent use and a type's
  methods are for one goroutine at a time. A type that is safe for
  concurrent use says so in its doc comment.

## Global state

- Libraries don't expose package-level state that changes behavior for
  every caller: registries, lazily created singleton clients, exported
  config variables. Let callers create instances and pass them in:
  `reg := sidecar.New()`.
- Package-level variables are fine when they are logically constant,
  invisible to callers (a private cache), or have no expectation of
  predictable behavior (`math/rand`). A default instance
  (`http.DefaultServeMux`) is only a thin wrapper over the instance API.
- Flags are defined only in `package main`. Libraries take configuration
  through parameters or option structs.

## Logging and security

- Use the repo's logger; without one, `log/slog`. No `fmt.Println` for
  diagnostics.
- Messages say what went wrong, with what's needed to diagnose it. Never log
  secrets or personal data.
- Error level is for something someone must act on. Don't build expensive
  log arguments when the level is off:
  `if logger.Enabled(ctx, slog.LevelDebug) { ... }`.
- Keys, tokens and passwords come from `crypto/rand` (`rand.Text()`, or
  `rand.Read` plus hex or base64), never `math/rand`.

## Documentation

### Doc comments

- Every exported name has a doc comment, and so does unexported code whose
  behavior isn't obvious. Doc comments are full sentences that start with
  the name, optionally after an article:

  ```go
  // A Request represents a request to run a command.
  type Request struct{ /* ... */ }

  // Encode writes the JSON encoding of req to w.
  func Encode(w io.Writer, req *Request) error
  ```
- One package comment per package, directly above `package` with no blank
  line: `// Package math provides basic constants and mathematical
  functions.` A long one goes in `doc.go`. For commands: `// Seedgen
  generates ...` or `// The seedgen command ...`.
- Functions say what they return or, for side effects, what they do.
  Booleans "report whether". Refer to parameters by name, without markup.
  Document special cases, the errors callers can check (`At end of file,
  Read returns 0, io.EOF.`, "the error is of type *PathError"), cleanup the
  caller owns (`Call Stop to release the Ticker's resources.`), and unusual
  context or concurrency behavior.
- Don't restate what's implied: that cancellation returns `ctx.Err()`, that
  a top-level function is safe for concurrent use, that a method needs one
  goroutine at a time, or which algorithm the implementation uses. Document
  only the parameters that are error-prone or non-obvious, and say why.
- Types say what each value represents, what a useful zero value means, and
  any concurrency guarantee beyond one goroutine at a time.
- Syntax: a blank `//` line between paragraphs; `# Heading` lines;
  `[Name]` and `[pkg.Name]` doc links; lists as indented `-` or `1.` items;
  code blocks indented one extra level. Don't indent a wrapped line of
  prose: it becomes a code block. No nested lists.
- A paragraph starting with `Deprecated: ` marks deprecation and names the
  replacement.
- Runnable examples in `_test.go` files (`func ExampleConfig_WriteTo()`
  with an `// Output:` comment) beat code in comments. A new package gets
  at least one.
- Wrap comment lines at a consistent width (80 to 100 columns), but keep
  long URLs whole.

### Comments

- Comments explain why, not what. Complete sentences are capitalized and
  punctuated; an end-of-line comment on a struct field may be a phrase.
- Explain the non-obvious: a closure capturing a variable defined far away,
  a business rule, complexity added for performance.
- Directives (`//go:build`, `//go:embed`, `//nolint`) have no space after
  `//`.

## What to avoid

- `panic`, `log.Fatal` or `os.Exit` in library code for ordinary errors.
- Discarded errors without a comment; matching on `err.Error()`.
- Interfaces next to their only implementation or exported "for mocking".
- `util`, `common` and `helpers` packages; package names repeated in
  exported names.
- Goroutines without a clear end; `time.Sleep` to synchronize.
- `this` / `self` receivers, `Get` prefixes, `MAX_SIZE` constants, `Url` /
  `Id`.
- Copying a struct that holds a `sync.Mutex`.
- A context in a struct field; `context.Background()` in the middle of a
  call chain.
- `interface{}` in new code (write `any`), `io/ioutil` (use `io` and `os`),
  `math/rand` for secrets.
- `import .`; `import _` outside `main` and tests.
