# Rust library public API

The Rust API Guidelines rules that apply to the public API of a library
crate. The general rules, and how they differ for application code, are in
[SKILL.md](SKILL.md).

## Contents

- Iterators (C-ITER)
- Cargo features (C-FEATURE)
- Interoperability (C-COMMON-TRAITS, C-CONV-TRAITS, C-COLLECT, C-SERDE,
  C-SEND-SYNC, C-NUM-FMT, C-RW-VALUE)
- Generics and object safety (C-GENERIC, C-OBJECT)
- Future proofing (C-SEALED, C-STRUCT-PRIVATE, C-NEWTYPE-HIDE,
  C-STRUCT-BOUNDS)
- Macros
- Publishing crates

## Iterators (C-ITER, C-ITER-TY)

Homogeneous collections provide `iter(&self)`, `iter_mut(&mut self)` and
`into_iter(self)`, returning types named `Iter`, `IterMut`, `IntoIter`. Other
iterator methods follow the same rule: `keys()` → `Keys`, `values()` → `Values`.

## Cargo features (C-FEATURE)

- Cargo features have no placeholder words: `std`, not `use-std` / `with-std`.
  No negative features (`no-std`) — features are additive.

  ```toml
  [features]
  default = ["std"]
  std = []
  ```

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

### Number formatting (C-NUM-FMT)

Types you'd use with `|` / `&` implement `UpperHex`, `LowerHex`, `Octal`,
`Binary`. Quantity newtypes (`Nanoseconds(u64)`) don't need them.

### Readers and writers (C-RW-VALUE)

Generic I/O functions take `R: Read` / `W: Write` **by value**; `&mut R` works
through std's blanket impls. Say so in the docs.

## Generics and object safety

- **Generics** (C-GENERIC): library APIs accept the widest reasonable input
  (`fn foo<I: IntoIterator<Item = i64>>(iter: I)`, `impl AsRef<Path>`). See
  [Library API vs application code](SKILL.md#library-api-vs-application-code) for when
  to prefer concrete types.
- **Object safety** (C-OBJECT): decide up front whether a trait is meant for
  `dyn` use. If so, keep it object-safe and exclude generic methods with
  `where Self: Sized`:

  ```rust
  fn visit<T>(&self, t: T) where Self: Sized;
  ```

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
