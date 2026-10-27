---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

Write unit tests for this Go function. Reply with the test file.

```go
package text

import "strings"

// WordCount reports the number of whitespace-separated words in s.
func WordCount(s string) int {
	return len(strings.Fields(s))
}
```
