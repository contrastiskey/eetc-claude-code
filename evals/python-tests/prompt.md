---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

Write pytest tests for this function. Reply with the test code.

```python
def parse_price(text: str) -> float:
    return float(text.replace("$", "").replace(",", ""))
```
