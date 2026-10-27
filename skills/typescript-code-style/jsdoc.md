# Comments and JSDoc

Comment and JSDoc rules from the Google TypeScript Style Guide. The rest
of the style is in [SKILL.md](SKILL.md). Rules marked *(TS)* don't apply
to `.js` files.

- `/** JSDoc */` for documentation a caller reads; `//` for implementation
  notes. Multi-line implementation comments are several `//` lines, not
  `/* */`. No boxes drawn with `*`.
- Document every exported symbol (except ones exported only for tooling,
  e.g. `@NgModule` classes), plus any member whose purpose its name doesn't
  make obvious. Don't restate the name and type:
  `@param fooBarService The Bar service for the Foo application.` adds
  nothing.
- Class docs say how and when to use the class. Method docs start with a
  third-person verb phrase (`Returns ...`, `Sends ...`). `@param` and
  `@return` only when they add information.
- JSDoc is Markdown: write lists with `-`, or the lines run together.
- Short docs fit on one line: `/** Returns the nicest element. */`. Longer
  ones put `/**` and `*/` on their own lines. Each tag on its own line;
  wrapped tag text indented 4 spaces.

  ```ts
  /**
   * POSTs the request to start brewing.
   * @param amountLitres The amount to brew. Must fit the pot size!
   */
  brew(amountLitres: number, logger: Logger) {}
  ```

- *(TS)* Document parameter properties with `@param` in the constructor's
  JSDoc.
- *(TS)* No types in JSDoc (`@param {string} name`), and no tags that repeat
  a keyword (`@private`, `@override`, `@implements`, `@enum`). In `.js`
  files the JSDoc types are the type information, so write them.
- An unclear literal argument gets a name comment before it:
  `render(node, /* shouldAnimate= */ true)`. Several of them → take an
  options object instead.
- JSDoc goes above decorators, never between a decorator and its target.
- `@deprecated` with directions for fixing call sites.
- An optional `@fileoverview` JSDoc at the top of a file has unindented
  wrapped lines.
