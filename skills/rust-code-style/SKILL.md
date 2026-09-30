---
name: rust-code-style
description: >
  Rust coding conventions: the Rust API Guidelines (naming, interoperability,
  predictability, flexibility, type safety, dependability, debuggability,
  future proofing, macros, documentation) and the rust-analyzer style guide
  (control flow, allocations, imports).
  TRIGGER when: writing, editing, formatting, or reviewing Rust code, or
  asked to "fix style" / "check code quality" in a Rust project.
  DO NOT TRIGGER when: working in a non-Rust language, or only reading code
  without making changes.
---

# Rust Code Style

Sources: [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
(rule IDs like `C-GETTER` below) and the
[rust-analyzer style guide](https://rust-analyzer.github.io/book/contributing/style.html)
(marked *r-a*).

## Tooling

- `cargo fmt` and `cargo clippy --all-targets -- -D warnings` must pass. Don't
  hand-format anything rustfmt controls.
- Allow noisy clippy lints once in `[lints.clippy]` / `[workspace.lints.clippy]`
  in `Cargo.toml`, not with scattered `#[allow]` (*r-a*).
- Check `edition` and `rust-version` in `Cargo.toml` before using newer
  language features.
- Project-specific commands live in the repo's CLAUDE.md.

## Library API vs application code

The two sources disagree in a few places. The **public API of a library crate**
follows the API Guidelines; **application code and crate-internal code** follow
rust-analyzer.

| Topic | Library public API | Application / internal |
|-------|--------------------|------------------------|
| Parameters | Generic: `impl AsRef<Path>`, `impl IntoIterator<Item = T>` (C-GENERIC) | Concrete: `&Path`, `&[T]` — avoids monomorphization cost |
| Fields | Private, with accessors (C-STRUCT-PRIVATE) | `pub` when the struct has no invariants |
| Errors | Own error type (C-GOOD-ERR) | `anyhow::Result` + `.context(...)` |
| Zero-arg constructor | Both `new()` and `Default`, identical behavior (C-COMMON-TRAITS, C-CTOR) | `Default` instead of `new()` |

## Naming

### Casing (C-CASE)

| Item | Convention | Example |
|------|-----------|---------|
| Crate | `snake_case`, no `-rs` / `-rust` affix | `order_book` |
| Module | `snake_case` | `tick_writer` |
| Type / trait / enum variant | `UpperCamelCase` | `OrderWriter`, `SessionPhase::Draining` |
| Function / method / local | `snake_case` | `flush_buffer` |
| General constructor | `new` or `with_more_details` | `Vec::with_capacity` |
| Conversion constructor | `from_some_other_type` | `u64::from_str_radix` |
| Macro | `snake_case!` | `hash_map!` |
| `const` / `static` | `SCREAMING_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| Type parameter | concise `UpperCamelCase`, usually one letter | `T`, `K`, `V` |
| Lifetime | short lowercase | `'a`, `'de`, `'src` |

- Acronyms are one word in `UpperCamelCase` (`Uuid`, `Stdin`, not `UUID`,
  `StdIn`) and lowercase in `snake_case` (`is_xid_start`).
- No single-letter words in `snake_case` except the last: `btree_map`, not
  `b_tree_map`; but `PI_2`.

### Conversions (C-CONV)

| Prefix | Cost | Ownership |
|--------|------|-----------|
| `as_` | Free | borrowed → borrowed |
| `to_` | Expensive | borrowed → borrowed, borrowed → owned (non-`Copy`), owned → owned (`Copy`) |
| `into_` | Variable | owned → owned (non-`Copy`) |

- `as_` and `into_` lower the abstraction (view the representation / take it
  apart); `to_` stays at the same level. Examples: `str::as_bytes`,
  `str::to_lowercase`, `String::into_bytes`, `f64::to_radians`.
- A wrapper around a single value exposes it with `into_inner()`.
- `mut` goes where it would in the return type: `as_mut_slice`, not
  `as_slice_mut`.

### Getters (C-GETTER)

No `get_` prefix. Use `get` only when there is one obvious thing to get
(`Cell::get`) or for bounds-checked access:

```rust
pub fn first(&self) -> &First { &self.first }
pub fn first_mut(&mut self) -> &mut First { &mut self.first }

fn get(&self, index: K) -> Option<&V>;
fn get_mut(&mut self, index: K) -> Option<&mut V>;
unsafe fn get_unchecked(&self, index: K) -> &V;
```

### Iterators (C-ITER, C-ITER-TY)

Homogeneous collections provide `iter(&self)`, `iter_mut(&mut self)` and
`into_iter(self)`, returning types named `Iter`, `IterMut`, `IntoIter`. Other
iterator methods follow the same rule: `keys()` → `Keys`, `values()` → `Values`.

### Features and word order (C-FEATURE, C-WORD-ORDER)

- Cargo features have no placeholder words: `std`, not `use-std` / `with-std`.
  No negative features (`no-std`) — features are additive.

  ```toml
  [features]
  default = ["std"]
  std = []
  ```
- Keep word order consistent with std: verb-object-error — `ParseIntError`,
  `RecvTimeoutError`, not `IntParseError`.

### Local names (*r-a*)

Boring, long names. Defaults: `res` for the result being built, `it` for an
item you don't care about, `n_foos` for a count, `foo_idx` for an index.
Mangle keywords as `krate`, `enum_`, `type_` — not `r#crate`.

## Types and signatures

### Prefer the more general borrowed type (*r-a*)

| Use | Not |
|-----|-----|
| `&[T]` | `&Vec<T>` |
| `&str` | `&String` |
| `Option<&T>` | `&Option<T>` |
| `&Path` | `&PathBuf` |

### Newtypes (C-NEWTYPE)

Wrap primitives that carry meaning so they can't be mixed up:

```rust
struct Miles(pub f64);
struct Kilometers(pub f64);

impl Miles {
    fn to_kilometers(self) -> Kilometers { /* ... */ }
}
```

### Meaningful arguments (C-CUSTOM-TYPE)

No bare `bool` / `Option` / small-int flags in signatures. Use an enum:

```rust
// GOOD
let w = Widget::new(Size::Small, Shape::Round);

// BAD
let w = Widget::new(true, false);
```

If callers always pass a literal, split the function instead (*r-a*):

```rust
// GOOD
fn foo() { /* ... */ }
fn foo_with_bar(bar: Bar) { /* ... */ }

// BAD
fn foo(bar: Option<Bar>) { /* ... */ }
```

### Flags (C-BITFLAG)

A set of independent flags is a `bitflags!` type, not an enum.

### Many parameters: `Config` struct (*r-a*)

Replace long lists of optional/boolean parameters with a `Config` struct passed
by the caller. Don't implement `Default` for it and don't store it as state —
the caller spells out every value.

### Builders (C-BUILDER)

For a complex `T`, add `TBuilder`: its constructor takes only required data,
config methods chain, terminal methods build `T`.

- **Non-consuming (preferred)**: config methods take and return `&mut self`,
  terminal method takes `&self`. Works for both one-liners and conditional setup.

  ```rust
  impl Command {
      pub fn new(program: String) -> Command { /* ... */ }
      pub fn arg(&mut self, arg: String) -> &mut Command {
          self.args.push(arg);
          self
      }
      pub fn spawn(&self) -> io::Result<Child> { /* ... */ }
  }

  let mut cmd = Command::new("/bin/ls".to_string());
  if size_sorted {
      cmd.arg("-S".to_string());
  }
  cmd.spawn()?;
  ```
- **Consuming**: only when the terminal method must take ownership. Then every
  method takes and returns `self`, and conditional setup re-assigns
  (`task = task.named(...)`).

## Interoperability

### Common traits (C-COMMON-TRAITS, C-DEBUG, C-DEBUG-NONEMPTY)

Because of the orphan rule, downstream crates can't add these for you. Derive
every one that makes sense: `Debug`, `Clone`, `Copy`, `PartialEq`, `Eq`,
`PartialOrd`, `Ord`, `Hash`, `Default`, plus `Display` for user-facing types.

- **Every public type implements `Debug`.** Exceptions need strong justification.
- A hand-written `Debug` never prints an empty string — empty values still show
  delimiters (`""`, `[]`, `Foo { }`).

### Conversion traits (C-CONV-TRAITS, C-CONV-SPECIFIC)

- Implement `From`, `TryFrom`, `AsRef`, `AsMut`. Never implement `Into` /
  `TryInto` — the blanket impls cover them.
- Put ad-hoc conversions on the more specific type: `str::as_bytes` and
  `str::from_utf8` live on `str`, not `[u8]`. Prefer `to_` / `as_` / `into_`
  methods over `from_` for chaining.

### Collections (C-COLLECT)

Collection types implement `FromIterator` (enables `collect`, `partition`,
`unzip`) and `Extend`.

### Serde (C-SERDE)

Data-structure types implement `Serialize` / `Deserialize`, in a library behind
an optional feature named exactly `serde`:

```toml
[dependencies]
serde = { version = "1.0", optional = true, features = ["derive"] }
```

### `Send` and `Sync` (C-SEND-SYNC)

Types are `Send + Sync` where possible. Types holding raw pointers must get
this right deliberately; lock it in with a test:

```rust
#[test]
fn test_send_sync() {
    fn assert_send_sync<T: Send + Sync>() {}
    assert_send_sync::<MyType>();
}
```

### Error types (C-GOOD-ERR)

- Implement `std::error::Error` (and therefore `Display` and `Debug`) and be
  `Send + Sync + 'static`. Boxed errors are `Box<dyn Error + Send + Sync>`.
- **Never use `()` as an error type.**
- `Display` messages are lowercase, concise, no trailing punctuation:
  `"unexpected end of file"`, `"invalid IP address syntax"`. Same for
  `anyhow!` / `.context()` messages (*r-a*).
- Don't implement the deprecated `Error::description`.

### Number formatting (C-NUM-FMT)

Types you'd use with `|` / `&` implement `UpperHex`, `LowerHex`, `Octal`,
`Binary`. Quantity newtypes (`Nanoseconds(u64)`) don't need them.

### Readers and writers (C-RW-VALUE)

Generic I/O functions take `R: Read` / `W: Write` **by value**; `&mut R` works
through std's blanket impls. Say so in the docs.

## Predictability

- **Methods over free functions** when there is an obvious receiver (C-METHOD):
  `impl Foo { pub fn frob(&self, w: Widget) }`, not `pub fn frob(foo: &Foo, w: Widget)`.
- **No out-parameters** (C-NO-OUT): return a tuple or struct. The exception is
  a caller-owned buffer that is reused: `fn read(&mut self, buf: &mut [u8])`.
- **Operator overloads are unsurprising** (C-OVERLOAD): implement `std::ops`
  traits only for operations that behave like the operator (e.g. `Mul` is
  multiplication-like).
- **Only smart pointers implement `Deref` / `DerefMut`** (C-DEREF). Never use
  `Deref` to fake inheritance.
- **Smart pointers have no inherent methods** (C-SMART-PTR): use associated
  functions so they can't be confused with the pointee's methods —
  `Box::into_raw(b)`, not `b.into_raw()`.
- **Constructors are static inherent methods** (C-CTOR):
  - `new` for the primary constructor; domain names for resources
    (`File::open`, `TcpStream::connect`, `UdpSocket::bind`); `_with_foo` suffix
    for variants, or a builder.
  - `from_` for conversion constructors that need to be `unsafe` or take extra
    arguments (`Box::from_raw`, `u64::from_str_radix`); otherwise implement `From`.
  - When both `new()` and `Default` exist, they behave identically.
- **Functions, not single-action objects** (*r-a*): `do_thing(a, b)`, not
  `ThingDoer::new(a, b).do_it()`.

## Flexibility

- **Expose intermediate results** (C-INTERMEDIATE): if you computed something
  useful, return it — `binary_search` returns the insertion point on `Err`,
  `String::from_utf8` returns the valid prefix length and the original bytes,
  `HashMap::insert` returns the old value.
- **Caller controls copies** (C-CALLER-CONTROL): take ownership when you'll
  store the value; borrow when you won't. Don't borrow and then `.clone()` /
  `.to_string()` inside (*r-a*: push allocations to the call site):

  ```rust
  // GOOD
  fn register(name: String) { /* stores name */ }

  // BAD
  fn register(name: &str) { let name = name.to_string(); /* ... */ }
  ```
- Use `Copy` as a bound only when you actually need copies.
- **Generics** (C-GENERIC): library APIs accept the widest reasonable input
  (`fn foo<I: IntoIterator<Item = i64>>(iter: I)`, `impl AsRef<Path>`). See
  [Library API vs application code](#library-api-vs-application-code) for when
  to prefer concrete types.
- **Object safety** (C-OBJECT): decide up front whether a trait is meant for
  `dyn` use. If so, keep it object-safe and exclude generic methods with
  `where Self: Sized`:

  ```rust
  fn visit<T>(&self, t: T) where Self: Sized;
  ```

## Dependability

### Validate arguments (C-VALIDATE)

Reject invalid input rather than guessing. In order of preference:

1. **Static** — a type that can't hold invalid values (`fn foo(a: Ascii)`, not
   `fn foo(a: u8)`).
2. **Dynamic** — check and return `Result` / `Option` (or panic on a documented
   precondition).
3. **`debug_assert!`** — for checks too expensive for release builds.
4. **Opt-out** — an `_unchecked` variant (or a `raw` module) for hot paths
   where the caller guarantees validity.

Express preconditions in types and make the caller supply them (*r-a*):

```rust
// GOOD
fn frobnicate(walrus: Walrus) { /* ... */ }

// BAD
fn frobnicate(walrus: Option<Walrus>) {
    let Some(walrus) = walrus else { return };
    /* ... */
}
```

Assert invariants liberally (*r-a*).

### Destructors (C-DTOR-FAIL, C-DTOR-BLOCK)

`Drop` runs during unwinding, so it must never fail and never block. Offer an
explicit `close(self) -> Result<()>` (or a non-blocking shutdown method) for
teardown that can fail or wait; `Drop` does the infallible best effort and
logs or ignores errors.

## Future proofing

### Sealed traits (C-SEALED)

A trait only your crate should implement gets a private supertrait. You can
then add methods without a breaking change. Say in the docs that it's sealed.

```rust
pub trait TheTrait: private::Sealed {
    fn method(&self);
}

impl TheTrait for usize { /* ... */ }

mod private {
    pub trait Sealed {}
    impl Sealed for usize {}
}
```

### Private fields (C-STRUCT-PRIVATE)

In a library's public API, public fields lock in the representation and rule
out invariants. Reserve them for passive C-style data. Inside an application,
*r-a* applies: make fields `pub` when there are no invariants; when there are,
keep fields private, document the invariant, enforce it in the constructor,
return borrows from getters, and add no setters:

```rust
// GOOD
fn first_name(&self) -> &str { &self.first_name }

// BAD
fn first_name(&self) -> String { self.first_name.clone() }
```

### Hide implementation types (C-NEWTYPE-HIDE)

Don't leak iterator-adapter chains or other internal types in signatures. Wrap
them in a newtype, or return `impl Trait`:

```rust
pub struct MyTransformResult<I>(Enumerate<Skip<I>>);

pub fn my_transform<I: Iterator>(input: I) -> MyTransformResult<I> {
    MyTransformResult(input.skip(3).enumerate())
}
```

### No duplicated derive bounds (C-STRUCT-BOUNDS)

Don't put `Clone`, `PartialEq`, `PartialOrd`, `Debug`, `Display`, `Default`,
`Error`, `Serialize`, `Deserialize` or `DeserializeOwned` bounds on a struct
definition — `#[derive]` adds them per impl, and adding a bound later is a
breaking change.

```rust
// GOOD
#[derive(Clone, Debug, PartialEq)]
struct Good<T> { /* ... */ }

// BAD
#[derive(Clone, Debug, PartialEq)]
struct Bad<T: Clone + Debug + PartialEq> { /* ... */ }
```

Bounds on the struct are fine when it names an associated type of the trait,
for `?Sized`, or when a `Drop` impl needs them.

## Macros

- Input syntax looks like the output (C-EVOCATIVE): use the `struct` keyword to
  declare structs, `;` after constants, Rust-like punctuation.
- Item macros accept attributes on every generated item, including `#[derive]`
  and `#[cfg]` (C-MACRO-ATTR).
- Item macros work at module scope and inside functions; test both
  (C-ANYWHERE).
- Item macros accept a visibility: private by default, `pub` if given
  (C-MACRO-VIS).
- `$t:ty` fragments work with primitives, relative/absolute/`super::` paths and
  generics (C-MACRO-TY).

## Documentation

### Doc comments

- **Crate-level `//!` docs** are thorough and include examples (C-CRATE-DOC).
- **Every public item has `///` docs with an `# Examples` section**
  (C-EXAMPLE) — module, trait, struct, enum, function, method, macro, type
  alias. Show *why* you'd use the item, not just that it can be called. Linking
  to a shared example elsewhere is fine when it's the natural place.
- **Examples use `?`**, never `unwrap()` (C-QUESTION-MARK) — people copy them.
  Hide the boilerplate with `#` lines:

  ```rust
  /// ```
  /// # use std::error::Error;
  /// # fn main() -> Result<(), Box<dyn Error>> {
  /// let config = Config::load("app.toml")?;
  /// # Ok(())
  /// # }
  /// ```
  ```
- **Failure sections** (C-FAILURE), as Markdown headers:
  - `# Errors` — every condition that returns `Err` (also on trait methods).
  - `# Panics` — every condition that panics.
  - `# Safety` — every invariant the caller of an `unsafe fn` must uphold.
- **Link liberally** (C-LINK) with intra-doc links: `` [`Deserialize`] ``,
  `` [`Self::serialize_struct`] ``.
- **Hide implementation details** (C-HIDDEN): `#[doc(hidden)]` on impls or
  items users shouldn't see; `pub(crate)` for items that shouldn't be public.

### Comments

Comments are full sentences: capital letter, ending period (*r-a*). This
differs from `eetc:python-code-style` on purpose — follow the language's own
convention. Comment only non-obvious logic. Every `unsafe` block gets a
`// SAFETY:` comment explaining why it's sound.

## Publishing crates

Only for crates published to crates.io:

- `Cargo.toml` `[package]` has `description`, `license`, `repository`,
  `keywords`, `categories` (and `authors` if the project uses it);
  `documentation` only if not on docs.rs, `homepage` only if distinct
  (C-METADATA).
- Release notes list every significant change and flag breaking ones; tag each
  release with an annotated tag (C-RELNOTES).
- A crate at 1.0+ only exposes types from stable (1.0+) dependencies in its
  public API — including via `From<dep::Error>` impls (C-STABLE).
- The crate and its dependencies use permissive licenses; default is
  `"MIT OR Apache-2.0"` with both license files, unless the repo already
  chose one (C-PERMISSIVE).

## Code (*r-a*)

### Control flow

- **Early returns** to keep nesting shallow; `return Err(e)` for errors.

  ```rust
  // GOOD
  if !condition() {
      return None;
  }
  Some(compute())

  // BAD
  if condition() { Some(compute()) } else { None }
  ```
- **Push control flow to the caller**: `if cond { f() }`, not an `f` that
  starts with `if !cond { return }`.
- **`match` over `if let … else`**, and spell out `None` instead of `_`:

  ```rust
  match ctx.expected_type {
      Some(t) => t == expected_type,
      None => false,
  }
  ```
- Empty match arms are `=> ()`, not `=> {}`.
- No `ref` in patterns — match ergonomics handle it.
- Range checks read left to right, smallest first: `lo <= x && x <= hi`, not
  `x >= lo && x <= hi`.
- Name complex conditions with a helper variable instead of inlining them into
  an `if` or match guard.
- Use combinators where they read naturally, but don't contort code into them;
  avoid `bool::then` and `Option::filter`, prefer plain `if`.

### Type annotations

Annotate the binding with a full type instead of `_` or turbofish:

```rust
// GOOD
let names: Vec<String> = users.iter().map(|u| u.name.clone()).collect();

// BAD
let names: Vec<_> = users.iter().map(|u| u.name.clone()).collect();
let names = users.iter().map(|u| u.name.clone()).collect::<Vec<_>>();
```

### Allocations

- Don't `collect` into a `Vec` just to iterate or destructure once — use the
  iterator directly (`itertools::collect_tuple` if needed).
- Recursive functions that build a collection take an accumulator as their
  **first** parameter instead of returning and merging sub-collections:

  ```rust
  pub fn reachable_nodes(node: Node) -> HashSet<Node> {
      let mut res = HashSet::new();
      go(&mut res, node);
      return res;

      fn go(acc: &mut HashSet<Node>, node: Node) { /* ... */ }
  }
  ```
- `Vec::new()`, not `vec![]`.

### Functions

- Context parameters come first. Several of them → group into a `Ctx` struct
  and make the functions methods on it.
- No single-use helper functions — use a block — unless the helper needs its
  own `?` or `return`.
- Nested helpers go at the **end** of the enclosing function, after a `return`
  (see above). One level of nesting at most.

### Modules, imports and item order

- Import groups, separated by blank lines: `std` → external crates → current
  crate (`crate::`) → parent/child modules (`super::`, `self::`); re-exports
  (`pub use`) last. One `use` per crate.
- `use crate::` over `super::`, except in `#[cfg(test)] mod tests`.
- No local `use MyEnum::*`. No glob imports except preludes and
  `use super::*` in tests.
- For trait impls, import the module: `use std::fmt;` then `impl fmt::Display`.
- Item order: public before private, types (structs/enums) before impls and
  functions, top-down — the reader sees the API first.

### Dependencies

Don't add small helper crates for a few lines of code. Established crates
(`serde`, `thiserror`, `anyhow`, `itertools`, `tokio`, …) are fine.

### Tests

See `eetc:rust-tests`.

## What to avoid

- `unwrap()` outside tests — use `?`, or `expect("why this can't fail")` for a
  true invariant.
- `println!` / `eprintln!` for diagnostics — use the project's logger
  (`tracing` or `log`).
- `#[allow(...)]` without a comment saying why.
- `.clone()` just to satisfy the borrow checker without checking whether a
  borrow or move works.
- `unsafe` without a `// SAFETY:` comment.
- `Deref` for anything that isn't a smart pointer.
- `()` as an error type; panicking in `Drop`.
