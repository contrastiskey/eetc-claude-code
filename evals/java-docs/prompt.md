---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

Add Javadoc to this class. Reply with the documented class.

```java
public final class RateLimiter {
    private final int permitsPerSecond;

    public RateLimiter(int permitsPerSecond) {
        this.permitsPerSecond = permitsPerSecond;
    }

    public boolean tryAcquire() {
        return true;
    }
}
```
