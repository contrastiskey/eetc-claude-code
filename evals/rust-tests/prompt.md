---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

Write unit tests for this Rust function. Reply with the test module.

```rust
pub fn word_count(s: &str) -> usize {
    s.split_whitespace().count()
}
```
