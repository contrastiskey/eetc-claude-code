---
name: python-code-style
description: >
  Python coding conventions: type hints, Sphinx docstrings, comments, import
  order, error handling, formatting and return values.
  TRIGGER when: writing, editing, or generating any Python code.
  DO NOT TRIGGER when: only reading or analyzing code without making changes,
  or working in a non-Python language.
user-invocable: false
---

# Python Code Style

Framework rules live in `eetc:fastapi-patterns` / `eetc:django-patterns`.
Project-specific rules (formatter, logging, clients) live in the repo's
CLAUDE.md or `codebase-overview` skill.

## Type Hints

- Always use type hints for all function parameters and return values
- Use `Optional[Type]` for parameters that can be `None`
- Prefer specific types: `Dict[str, Any]`, `List[Dict]` over `dict`, `list`
- Boolean parameters explicitly typed as `bool`
- Conditional returns use `Union`: `Union[pd.DataFrame, List[Dict]]`

```python
def get_price_data(
    symbol: str,
    start_date: Optional[str] = None,
    as_json: bool = False,
) -> Union[pd.DataFrame, List[Dict]]:
```

## Docstrings

- **Classes**: always require a docstring — explain what the class is, what it
  does, and what it's for. Include an `Example:` block.
- **Functions/methods**: required unless the signature is very simple and
  completely self-explanatory (e.g., a trivial one-liner with an obvious name
  and no parameters beyond `self`). When in doubt, add a docstring. No
  `Example:` blocks on functions — the signature and description suffice.
- Sphinx-style: `:param:`, `:return:`, `:raises:` sections
- Max line length: 80 characters (wrap manually)
- Always add a blank line after the closing `"""` of every docstring
- Document both options when the return type depends on a parameter

```python
class DataClient:
    """
    Client for fetching market data from the data API.

    Wraps authentication and response parsing so callers get DataFrames
    (or raw JSON) back instead of HTTP responses.

    :param api_key: API key sent with every request.
    :raises ValueError: If ``api_key`` is empty.

    Example:
        >>> client = DataClient(api_key="key")
        >>> df = client.get_price_data("AAPL")
    """

    def get_price_data(
        self, symbol: str, as_json: bool = False
    ) -> Union[pd.DataFrame, List[Dict]]:
        """
        Fetches daily OHLCV price data for a symbol.

        :param symbol: Ticker symbol (e.g., "AAPL").
        :param as_json: If True, returns raw JSON; if False (default),
            returns a pandas DataFrame.
        :return: Price rows as a DataFrame, or a list of dicts if
            ``as_json`` is True.
        :raises requests.HTTPError: If the API request fails.
        """

        # implementation
```

## Comments

- Start with **lowercase letters** (except proper names, acronyms, technical
  terms)
- Only add comments for non-obvious logic; never comment obvious code
- Applies to inline, block and TODO comments

✅ Explains non-obvious logic:
```python
# Kelly Criterion: f* = μ / σ²
optimal_leverage = annualized_return / annualized_variance

# for SHORT positions, invert the returns
if position_type == "SHORT":
    df["log_return"] = -df["log_return"]

# TODO: add support for intraday data
```

❌ States the obvious, or starts uppercase:
```python
# convert date column to datetime
df["date"] = pd.to_datetime(df["date"])

# Calculate daily log returns
```

## Imports

Order: standard library → third-party → framework (FastAPI/Pydantic, Django/DRF)
→ local. Use explicit imports; import types even if only used in annotations.

```python
from typing import Union, List, Dict, Any, Optional

import pandas as pd
import requests
from requests import Response

from myapp.services import PriceService
```

## Error Handling

- Always validate and handle errors from external APIs
- Use `response.raise_for_status()` for outbound HTTP requests
- Acceptable status codes: POST `[200, 201]`, GET `[200]`
- Document all exceptions with `:raises:` in docstrings

```python
response = requests.post(url, json=data, headers=headers)

if response.status_code not in [200, 201]:
    response.raise_for_status()

return response.json()
```

## Formatting

- Use the repo's formatter (black or ruff — see CLAUDE.md); don't hand-format
  what it controls
- Double quotes for strings
- Blank line before `return` statements
- Blank line after docstring
- Blank line at end of file

## Return Values

- Return data (not `None`) unless it's a pure side-effect operation
- Document return type accurately, especially for conditional returns
