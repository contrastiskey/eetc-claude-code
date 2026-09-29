---
name: python-tests
description: >
  Python testing conventions: ai-generated marker, given/when/then sections,
  comprehensive assertions, mocking external APIs.
  TRIGGER when: writing, editing, or generating Python test code.
  DO NOT TRIGGER when: only reading tests, working on non-test files, or
  working in a non-Python language.
user-invocable: false
---

# Python Test Conventions

The test framework (pytest functions vs Django `TestCase`), fixtures, fakes,
which clients to mock and the run commands are project-specific — see the
repo's CLAUDE.md or `codebase-overview` skill. Framework test patterns live in
`eetc:fastapi-patterns` / `eetc:django-patterns`.

## Rules

- `# ai-generated` comment above each test function (below any decorator)
- Three sections, separated by comments: `# given` (setup), `# when` (execute
  the code under test), `# then` (assertions)
- No docstrings on test functions — the name and body explain the test
- Never call a real external API — mock or fake every external client
- Test essential functionality: custom code and core business logic, not
  third-party libraries or framework behaviour
- Comprehensive assertions (below)

```python
# ai-generated
def test_get_price_data_returns_dataframe(mock_client):
    # given
    symbol = "AAPL"

    # when
    result = mock_client.get_price_data(symbol)

    # then
    assert isinstance(result, pd.DataFrame)
    assert list(result.columns) == ["open", "high", "low", "close"]
    assert result.iloc[0]["close"] == 150.0
    assert result.iloc[1]["close"] == 151.0
    assert result.iloc[2]["close"] == 152.0
```

## Comprehensive Assertions

Verify all relevant items, not just the first:

- **DataFrames**: check shape, columns, and multiple rows
- **JSON/dicts**: verify structure and multiple entries
- **Mock calls**: check every expected call, not just `called` / `call_count`

❌ Incomplete:
```python
# then
assert len(result) > 0
assert result[0]["symbol"] == "AAPL"
assert mock_request.called
```

✅ Comprehensive:
```python
# then
assert len(result) == 2
assert result[0]["symbol"] == "AAPL"
assert result[0]["price"] == 150.0
assert result[1]["symbol"] == "GOOGL"
assert result[1]["price"] == 2800.0
assert mock_request.call_count == 2
mock_request.assert_any_call("/api/prices", params={"symbol": "AAPL"})
mock_request.assert_any_call("/api/prices", params={"symbol": "GOOGL"})
```
