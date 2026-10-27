---
name: typescript-code-style
description: >
  TypeScript and JavaScript coding conventions that follow established
  industry standards: the Google TypeScript Style Guide, Google's tsetse and
  tsec conformance checks, typescript-eslint's strict rule sets, and the
  TypeScript team's recommended compiler options. Covers imports and exports,
  language features, classes, functions, async code, errors, DOM security,
  naming, the type system, and JSDoc.
  TRIGGER when: writing, editing, formatting, or reviewing TypeScript or
  JavaScript code (.ts, .tsx, .mts, .cts, .js, .jsx, .mjs, .cjs), or asked to
  "fix style" / "check code quality" in a TS/JS project.
  DO NOT TRIGGER when: working in another language, or only reading code
  without making changes.
---

# TypeScript Code Style

Sources. The first is the base and wins any disagreement:

1. [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html).
2. Google's TypeScript conformance checks, which the guide requires:
   [tsetse](https://github.com/bazelbuild/rules_typescript/tree/master/internal/tsetse/rules)
   (correctness) and [tsec](https://github.com/google/tsec) (XSS, Trusted
   Types).
3. [typescript-eslint](https://typescript-eslint.io/users/configs)
   `strict-type-checked` and `stylistic-type-checked`.
4. The TypeScript team's recommended compiler options
   ([`tsc --init`, TS 5.9](https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/)).

It applies to `.js` / `.jsx` too, except the rules marked *(TS)* and the Type
system section.

## Tooling

- Code type-checks with zero errors and passes the repo's linter. Never
  loosen `tsconfig.json` or the lint config, and never add a suppression, to
  get a change through.
- Write code that passes `strict`, even where the repo hasn't enabled it: no
  implicit `any`, and `null` / `undefined` handled.
- The formatter owns quotes, semicolons, indentation, wrapping and trailing
  commas. Run the repo's formatter on the files you touch, and don't
  hand-format against it. With no formatter, write what
  [gts](https://github.com/google/gts) (Google's config) produces: 2-space
  indent, 80 columns, single quotes, `{a, b}` without inner spaces, trailing
  commas everywhere, `x => x` without parentheses.
- Setting up a project: start from the TypeScript team's recommended options
  (`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`,
  `verbatimModuleSyntax`, `isolatedModules`, `noUncheckedSideEffectImports`,
  `moduleDetection: "force"`, `skipLibCheck`). Lint with gts, or with
  typescript-eslint `strict-type-checked` plus `stylistic-type-checked`.

### Compiler options that change the rules

| Option | Rule |
|--------|------|
| `erasableSyntaxOnly`, or `.ts` run with no compile step (Node's built-in type stripping, ts-blank-space) | No `enum`, parameter properties, `namespace` with runtime code, or `import x =` / `export =`. Use a string-literal union or an `as const` object instead of an enum, and assign fields in the constructor body |
| `verbatimModuleSyntax` | `import type` / `{type Foo}` is required for type-only imports |
| `isolatedModules` | `export type` is required to re-export a type |
| `noUncheckedIndexedAccess` | `xs[i]` and `record[key]` are `T \| undefined`. Check them; don't `!` them |
| `noUnusedParameters` | Drop unused trailing parameters. One that must stay for its position takes a `_` prefix, the only form the compiler exempts |
| `module: "nodenext"` | Relative imports name the output file: `./foo.js` |

### Consistency

From the guide's policy section:

- A question this skill doesn't settle: do what the file already does, then
  what the directory does.
- New files follow this skill even when older files don't.
- Bring a file into style when you change it substantially. Otherwise leave
  unrelated code alone, and keep style-only changes out of feature commits.
- Generated code is exempt, but generated names that hand-written code uses
  follow the naming rules.

## Source files

- File names are `snake_case.ts`. Where a directory already names the same
  kind of file another way (`PascalCase.tsx` components), match it. Names a
  framework requires (Next.js `page.tsx`, `layout.tsx`, `route.ts`) are
  exempt.
- UTF-8. The only whitespace character is the ASCII space; escape any other
  in strings. Use `\n`, `\t`, `\'`, `\\` over numeric escapes (`\x0a`);
  never octal escapes.
- Write printable non-ASCII characters as themselves (`'μs'`). Escape
  non-printable ones and say what they are:
  `'﻿' + content;  // byte order mark`.
- File order, one blank line between the parts present: license JSDoc,
  `@fileoverview` JSDoc, imports, code.

## Imports and exports

| Form | Example | Use for |
|------|---------|---------|
| Named | `import {Foo, bar} from './foo';` | Symbols used often, or with clear names |
| Namespace | `import * as tableview from './tableview';` | Many symbols from a large API, or generic names (`tableview.Model`) |
| Default | `import Button from 'button';` | Only when the external module requires it |
| Side effect | `import './polyfills';` | Only for a library's load-time side effects |

- Relative paths (`./foo`) within the same project. Keep `../../..` chains
  short.
- Rename an import (`import {from as observableFrom} from 'rxjs';`) only for
  a collision, a generated name or an unclear name. For collisions a
  namespace import is often better.
- *(TS)* `import type {Foo}` or `import {type Foo, Bar}` for symbols used only
  as types. Re-export types with `export type {Foo} from './foo';`.
- ES modules only. No `namespace Foo {}`, `/// <reference>` or
  `import x = require()` *(TS)*, and no `require()` outside `.cjs` files.
- Named exports only, no `export default`. A default export has no canonical
  name: `import Foo from './bar'` and `import Bar from './bar'` both compile,
  and a misspelled name silently gets the default instead of failing. The
  exception is a file whose default export a framework or tool loads
  (Next.js pages and layouts, `React.lazy` targets, Storybook stories,
  `vite.config.ts` and other tool configs).
- Export only what other modules use.
- No `export let`. Expose mutable state through a getter
  (`export function getFoo() { return foo; }`). For a conditional export,
  compute first, then `export const SomeApi = pickApi();`.
- No classes of statics used as namespaces. Export the functions and
  constants; the file is the namespace.

## Language features

### Variables

- `const` by default, `let` only when reassigned, never `var`.
- One variable per declaration: no `let a = 1, b = 2;`.
- Never use a variable before its declaration.

### Arrays

- No `Array()` / `new Array()`. Use literals, or
  `Array.from<number>({length: 5}).fill(0)` for a sized array.
- No non-index properties on arrays. Use a `Map` or an object.
- Spread only iterables into arrays and only plain objects into objects.
  Never spread `null`, `undefined`, primitives, arrays into objects, or class
  instances (only own enumerable properties copy):

  ```ts
  const bar = [5, ...(shouldUseFoo && foo)];  // bad: throws when shouldUseFoo is false
  const bar = [5, ...(shouldUseFoo ? foo : [])];
  ```

- Skip unused elements with commas (`const [a, , c] = xs;`). No space after
  `...`.
- An optional destructured parameter defaults to `[]` or `{}`, with element
  defaults on the left: `function f([a = 4, b = 2] = [])`, not
  `function f([a, b] = [4, 2])`.
- To pass or return several values, an object (named, typed fields) beats an
  array.
- Use the result of non-mutating methods. `xs.map()`, `xs.filter()`,
  `xs.slice()`, `xs.concat()`, `s.trim()`, `s.toLowerCase()` and
  `s.replace()` on a line of their own do nothing. To loop for side effects,
  use `for...of`, not `map`.
- `xs.includes(x)` over `xs.indexOf(x) !== -1`, `xs.find(f)` over
  `xs.filter(f)[0]`, and `s.startsWith()` / `s.endsWith()` over index math or
  a regex.

### Objects

- No `Object()` constructor. Use literals.
- Iterate with `for (const [key, value] of Object.entries(obj))`, or
  `Object.keys` / `Object.values`. `for...in` only on dict-style objects,
  filtered with `hasOwnProperty`, and never on arrays (it yields the indices,
  as strings).
- Don't mix quoted (or computed) keys with unquoted keys in one object. A
  computed key counts as quoted unless it's a symbol (`[Symbol.iterator]`).
- A dict-style object (one typed with an index signature) is read with
  brackets, `counts['apples']`. Dotted access is for declared properties.
- No `delete obj[key]` with a computed key. Use a `Map` for keys that come
  and go.
- Destructured parameters: one level of unquoted shorthand, defaults on the
  left, and `= {}` when the whole object is optional:

  ```ts
  function render({num, str = 'default'}: Options = {}) {}
  ```

  Not nested (`{x: {num}}`), and not `{num, str}: Options = {num: 42, str: 'x'}`.
- `new Set([name])`, never `new Set(name)` for a string: a string is
  iterable, so that's a set of its characters.

### Classes

Writing or reviewing a class: read [classes.md](classes.md) first. It covers
declarations, constructors, fields, visibility, accessors, statics,
prototypes and decorators.

### Functions

- Named functions are declarations: `function foo() {}`, not
  `const foo = () => {}`. Use an arrow when the variable needs a type
  annotation: `const search: SearchFn = (source, sub) => {...};`. Nested
  functions may be either; inside methods prefer arrows, which keep `this`.
- No function expressions (`function () {}` as a value). Use arrows, except
  for generators and code that must rebind `this`.
- A concise arrow body only when its value is used:

  ```ts
  promise.then(v => console.log(v));  // bad: leaks console.log's return value
  promise.then(v => {
    console.log(v);
  });
  ```

- Pass an arrow that forwards arguments explicitly, not a bare named
  function, unless the function was written as that callback:
  `['11', '5', '10'].map(parseInt)` is `[11, NaN, 2]`.
- No arrow-function properties on classes. Call methods through an arrow:
  `setTimeout(() => { this.tick(); }, 5000)`, never
  `setTimeout(this.tick, 5000)`, which loses `this`. Exception: an event
  handler you must later remove is an arrow property, which gives a stable
  reference. Never `.bind(this)` inside `addEventListener`; the bound copy
  can't be removed.
- `this` only in constructors, methods, functions with an explicit `this:`
  parameter type, and arrows inside those. Never the global object or an event
  target. Arrows instead of `.bind(this)` or `const self = this`.
- Default parameter values are simple and side-effect free (`index = 0`,
  `paths: string[] = []`). More than a few optional parameters → one options
  object, destructured.
- Rest parameters, not `arguments`; spread, not `.apply()`. Never name
  anything `arguments`.
- No blank line at the start or end of a function body. `function* gen()` and
  `yield* iter`.

### Async code

- Every promise is awaited, returned, or given a rejection handler. A
  deliberate fire-and-forget handles its own failure and says so with `void`:
  `void save().catch(reportError);`.
- A promise is always truthy, so never use one as a condition, in `&&` /
  `||`, or in `expect(...).toBeTruthy()`. Await it first:
  `if (await isReady())`.
- Don't pass an async function where the caller ignores the promise it
  returns. `xs.forEach(async x => {...})` doesn't wait, and a rejection in an
  async event listener goes unhandled. Use `for (const x of xs) await f(x);`
  in sequence, or `await Promise.all(xs.map(f));` concurrently.
- `await` only promises. Mark a function `async` only if it awaits.
- Inside `try`, write `return await promise;`, so `catch` and `finally` see
  the rejection.
- A `.catch(e => ...)` parameter is `unknown`, exactly like
  `catch (e: unknown)`.

### Strings and numbers

- Single quotes, unless the formatter config says otherwise. A string that
  contains `'` can be a template literal.
- No `\` line continuations inside strings; concatenate with `+`. Template
  literals over complex concatenation.
- Number prefixes are lowercase `0x`, `0o`, `0b`. No other leading zeros.
- Never turn an object without a meaningful `toString()` into a string (in
  a template, with `+` or `String()`); it prints `[object Object]`.
- Coerce with `String(x)`, `Boolean(x)`, `!!x` or a template literal, not
  `'' + x`. Never `new String()`, `new Boolean()` or `new Number()`.
- Parse numbers with `Number()` and check the result:

  ```ts
  const n = Number(input);
  if (!Number.isFinite(n)) throw new Error(`not a number: ${input}`);
  ```

  Not unary `+input`, and not `parseInt` / `parseFloat`, which accept
  `'12 dwarves'` as `12`. `parseInt(s, 16)` only for non-decimal radixes,
  after checking the digits. For integers, `Math.trunc(Number(s))` after the
  check. Note that `Number('')` and `Number(' ')` are `0`.
- `Number.isNaN(x)`, never `x === NaN`, which is always false.
- No `!!` in `if` / `while` / `for` conditions; they already coerce.
- Never coerce an enum to a boolean (the first member is `0`, falsy).
  Compare: `level !== SupportLevel.NONE`.
- `??` for defaults, not `||`, when `0`, `''` or `false` are valid values:
  `const pageSize = options.pageSize ?? 20;`. `a?.b` over `a && a.b`.

### Control flow

- Braces around every `if` / `else` / `for` / `while` / `do` body, with the
  first statement on its own line. Only exception: an `if` that fits on one
  line (`if (x) x.doFoo();`).
- No assignment inside a condition. If it's truly clearer, double the
  parentheses: `while ((x = next()))`.
- Arrays: `for (const x of xs)`, or `for (const [i, x] of xs.entries())` when
  the index matters. `forEach` and indexed `for` are allowed.
- Every `switch` has a `default` group, last, even if empty. A non-empty
  `case` ends in `break`, `return` or `throw`, never falls through. Over a
  union, the `default` proves every case is handled (see Unions below).
- `===` / `!==` only. Exception: `x == null` matches both `null` and
  `undefined`.
- No condition the types make pointless: `if (user)` on a non-nullable
  `User`, or `?.` on a value that can't be nullish.
- Add grouping parentheses whenever precedence isn't obvious. None around
  the whole operand of `return`, `throw`, `typeof`, `delete`, `void`,
  `case`, `in`, `of` or `yield`.

### Errors

- Throw only `Error` or a subclass, always with `new` and a message:
  `throw new Error('...')`. Reject promises the same way:
  `Promise.reject(new Error('...'))`. A thrown string has no stack trace.
- Subclass `Error` when callers need more than a message. Throw rather than
  return error objects or fill in error containers.
- `catch (e: unknown)` and assume an `Error`: narrow with `instanceof Error`
  and rethrow anything else. Handle non-`Error` values only from an API known
  to throw them, with a comment naming it.
- An empty `catch` has a comment saying why doing nothing is right.
- Keep `try` blocks to the calls that throw and move the rest after. Wrapping
  a whole loop is fine.
- In tests, never `try { f(); fail(); } catch {}`, because the `catch`
  swallows `fail` too. Use the framework's throws assertion.

### Type and non-null assertions *(TS)*

- `x as Foo` and `y!` only silence the compiler; nothing checks them at
  runtime. Prefer a real check (`if (x instanceof Foo)`, `if (y)`). When an
  assertion is safe for a reason that isn't obvious, give it in a comment.
  Never `!` after `?.` or `??`, and never an assertion that doesn't change
  the type.
- `as` syntax, never `<Foo>x`. A double cast goes through `unknown`, not
  `any`: `x as unknown as Foo`.
- Type an object literal with an annotation, not an assertion:
  `const foo: Foo = {...}` reports misspelled or removed fields,
  `{...} as Foo` doesn't. For a returned literal, annotate the return type.

### Never

- Rely on automatic semicolon insertion. End statements with `;` unless the
  formatter config strips them.
- `const enum` *(TS)*. Use `enum`, or a union under `erasableSyntaxOnly`.
- `debugger` in committed code, or `with`.
- Language features outside the current ECMAScript spec (proposals,
  transpiler-only extensions). Runtime-specific APIs (Node, Chrome) only in
  code that targets that runtime.
- Modify builtin objects or their prototypes. Add globals unless a
  third-party API requires them.
- Call APIs marked `@deprecated` in new code.

## DOM and security

Never pass a string built from data to an API that parses it as HTML or
runs it as code (`innerHTML`, `outerHTML`, `insertAdjacentHTML`,
`document.write`, `eval`, `new Function`, `setTimeout('code')`, React
`dangerouslySetInnerHTML`, Vue `v-html`), and check the scheme of any URL
built from data. Before writing code that renders HTML, sets URLs or loads
scripts, read [dom-security.md](dom-security.md) for the full list of
sinks and the safe alternatives.

## Naming

| Style | For |
|-------|-----|
| `UpperCamelCase` | class, interface, type, enum, decorator, type parameter, TSX component function |
| `lowerCamelCase` | variable, parameter, function, method, property, namespace import (`import * as fooBar from './foo_bar';`) |
| `CONSTANT_CASE` | module-level constants, `static readonly` class constants, enum members |

- ASCII letters and digits only. `_` only inside `CONSTANT_CASE` and
  structured test names (`testX_whenY_doesZ`). `$` only where a library
  requires it (jQuery's `$`), or as an Observable suffix (`user$`) if the
  project already does that.
- `CONSTANT_CASE` only for values created once per program (module level,
  static fields, enum members) and never meant to change. A `const` inside a
  function is `lowerCamelCase`.
- No `_` prefix or suffix, not even on private members or unused parameters
  (see `noUnusedParameters` above). Skip unused destructured elements with
  commas.
- Don't repeat the type in the name: no `IUser` / `UserInterface`, no `opt_`
  prefix, no Hungarian (`kSecondsPerDay`). Name an interface after why it
  exists (`TodoItemStorage` for the stored form of `TodoItem`).
- Acronyms are words: `loadHttpUrl`, `customerId`, not `loadHTTPURL`,
  `customerID`, unless a platform name says otherwise (`XMLHttpRequest`).
- Descriptive names. No ambiguous abbreviations (`nErr`, `pcReader`), no
  dropped letters (`cstmrId`). Single letters only for variables whose scope
  is 10 lines or fewer and that aren't part of an exported API.
- A local alias keeps the source's name and casing:
  `const {BrewStateEnum} = SomeType;`.
- Type parameters: `T` or `UpperCamelCase`.

## Type system *(TS)*

### Inference and annotations

- Leave out annotations the initializer makes obvious: `const x = 15;`,
  `const ids = new Set<string>();` (type argument on the constructor, not
  `const ids: Set<string> = new Set();`).
- Annotate when inference would give `unknown` or `never` (an empty `[]`,
  `{}` or `new Map()` with no type argument), or when a complex expression's
  type isn't readable: `const value: string[] = await rpc.fetch().transform();`.
- Return type annotations are optional unless the repo requires them. Add
  one when the return type is complex.

### null and undefined

- Either is fine; match the API at hand (`Map.get` gives `undefined`, the
  DOM gives `null`).
- Type aliases never include `|null` or `|undefined`. Add it where the type
  is used, `getLatte(): Coffee|undefined`, and handle absence close to where
  it arises.
- Optional `?` over `|undefined` for fields and parameters (`milk?: Milk`,
  `pour(volume?: number)`). On classes, prefer initializing the field
  (`name = ''`).

### Object types

- `interface` for object shapes, not `type Foo = {...}`. `type` is for
  unions, tuples, functions and other non-object types.
- Annotate a value that implements an interface where it's declared,
  `const dog: Animal = {...}`, so a mismatch is reported there and not at a
  distant call site.
- Interfaces, not classes, for structural types.
- A tuple (`[string, string]`) beats a `Pair` interface, but named fields
  (`{host: string, port: number}`) are usually clearer.

### Unions

- Model values whose fields depend on their state as a discriminated union,
  not as optional fields plus flags:

  ```ts
  type Load =
    | {status: 'loading'}
    | {status: 'ready'; report: Report}
    | {status: 'failed'; error: Error};
  ```

- Switch on the tag. The `default` that every `switch` needs assigns to
  `never`, so adding a variant breaks the build until it's handled:

  ```ts
  switch (load.status) {
    case 'loading':
      return renderSpinner();
    case 'ready':
      return renderReport(load.report);
    case 'failed':
      return renderError(load.error);
    default: {
      const unhandled: never = load;
      throw new Error(`unhandled status: ${JSON.stringify(unhandled)}`);
    }
  }
  ```

- When a fixed set of values is needed both at runtime and as a type, derive
  the type from one `as const` array so the two can't drift apart:
  `const SIZES = ['s', 'm', 'l'] as const; type Size = (typeof SIZES)[number];`.

### Arrays and dictionaries

- `T[]` / `readonly T[]` when `T` is simple (letters, digits, dots:
  `string[]`, `ns.Item[]`, `string[][]`). Otherwise `Array<T>` /
  `ReadonlyArray<T>`: `Array<string|number>`, `Array<{n: number}>`,
  `ReadonlyArray<string[]>`.
- Prefer `Map` and `Set` to index signatures. When you do use an index
  signature, name the key: `{[userName: string]: number}`. Use
  `Record<K, V>` when the keys are known in advance.

### Data from outside the program

- Everything from outside (`fetch` responses, `JSON.parse`, storage,
  `postMessage`, URL parameters, form input) is `unknown` until a type guard
  or schema validator narrows it. Validate once, at the boundary, and pass
  typed values inward.
- Never let `JSON.parse`'s `any` spread. For data the program wrote itself,
  assert the type on the spot (`JSON.parse(text) as Settings`); for anything
  else, validate.

### Keep types simple

- Use the simplest construct that works. Some repetition beats a clever
  mapped or conditional type: `interface User extends FoodPreferences` over
  `Pick<User, 'a'|'b'>`, which IDE rename and find-references can't follow.
- No `any`. Use a precise type, an interface, a generic, or `unknown`
  narrowed with a type guard. When `any` is legitimate (a partial test mock),
  suppress the lint warning on that line with a comment saying why.
- No `{}` type: `unknown` for opaque values, `Record<string, T>` for
  dictionaries, `object` for any non-primitive.
- Never `String`, `Number`, `Boolean`, `Object` or `Function` as types. Use
  `string`, `number`, `boolean`, `object`, or a function signature
  (`(id: string) => void`).
- A type parameter relates at least two things: two parameters, or a
  parameter and the return type. One that appears once is the concrete type
  or `unknown`, and one that appears only in the return type
  (`function get<T>(): T`) is a hidden cast. When calling an existing
  return-only generic, pass the type argument explicitly.
- No `@ts-ignore`, `@ts-expect-error` or `@ts-nocheck`; fix the type error.
  In tests, prefer a cast with a comment over `@ts-expect-error`. A lint
  suppression names the rule and says why:
  `// eslint-disable-next-line @typescript-eslint/no-explicit-any -- partial mock`.

## Comments and JSDoc

- `/** JSDoc */` for documentation a caller reads; `//` for implementation
  notes. Multi-line implementation comments are several `//` lines, not
  `/* */`.
- Document every exported symbol, plus any member whose purpose its name
  doesn't make obvious, without restating the name and type.
- An unclear literal argument gets a name comment before it:
  `render(node, /* shouldAnimate= */ true)`.
- Writing or reviewing JSDoc: read [jsdoc.md](jsdoc.md) for its form, tags
  and wording.
