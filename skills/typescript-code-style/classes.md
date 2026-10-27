# TypeScript classes

Class rules from the Google TypeScript Style Guide. The rest of the style
is in [SKILL.md](SKILL.md). Rules marked *(TS)* don't apply to `.js`
files.

## Classes

- No `;` after a class declaration or between methods. A statement that
  assigns a class expression does end in `;`.
- One blank line around each method and the constructor.
- `new Foo()` always has parentheses.
- Drop a constructor that is empty or only passes its arguments to
  `super(...)`. Keep one that has parameter properties, visibility modifiers
  or parameter decorators, even when its body is empty.
- *(TS)* Parameter properties instead of copying a constructor argument into
  a field: `constructor(private readonly barService: BarService) {}` (not
  under `erasableSyntaxOnly`).
- Initialize fields where they're declared
  (`private readonly users: string[] = [];`). Never add or delete properties
  after the constructor; a field filled in later starts as `undefined`.
- *(TS)* `readonly` on every property not reassigned outside the constructor.
- *(TS)* `private` / `protected`, not `#private` fields.
- *(TS)* Keep visibility as narrow as possible. Prefer a non-exported
  function in the same file over a private method. Never write `public`,
  except on a non-readonly parameter property (`constructor(public baz: Baz)`).
  Members read outside the class body (Angular templates) are `protected`
  (`public` for Polymer), never `private`. Never reach a private member
  through `obj['foo']`.
- Getters are pure: no side effects, same result every call. No getter/setter
  pairs that only pass a field through; make the field public or `readonly`
  instead. A field behind a real accessor gets a whole-word affix
  (`wrappedBar`, `barInternal`). No `Object.defineProperty` accessors.
- Computed class members only for symbols. Give a logically iterable class a
  `[Symbol.iterator]()`.
- Statics: prefer a module function to a private static method. No `this` in
  a static context. Call a static only on the class that defines it, never
  through a subclass or a `typeof Base` variable.
- `toString()` always succeeds and has no side effects.
- No direct `prototype` manipulation, mixins, or changes to builtin
  prototypes (framework code excepted).

## Decorators

- Don't define new decorators. Use the framework's (`@Component`, `@Input`).
- A decorator goes directly above its target (or on the same line, for a
  field), with no blank line between. JSDoc goes above the decorator.
