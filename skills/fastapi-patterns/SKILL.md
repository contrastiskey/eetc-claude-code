---
name: fastapi-patterns
description: >
  FastAPI architecture standard: domain-package structure, async routes,
  Pydantic base models, settings, dependencies, views, REST conventions,
  services and errors, data access, background work, migrations and tests.
  TRIGGER when: designing or modifying FastAPI routers/views, Pydantic
  schemas, dependencies, services, or migrations, or adding an endpoint or a
  new domain.
  DO NOT TRIGGER when: the project does not use FastAPI.
---

# FastAPI Patterns

Based on [fastapi-best-practices](https://github.com/zhanymkanov/fastapi-best-practices)
and its Netflix [Dispatch](https://github.com/Netflix/dispatch)-inspired
structure, with the naming below. The repo's `codebase-overview` skill lists
its actual domains, data stores and integrations.

## Project structure

Domain packages under `src/`, not layer folders. Each domain owns its own
endpoints, schemas, and logic:

```
src
├── <domain>/                 # one package per domain
│   ├── models.py             # pydantic schemas
│   ├── service.py            # business logic
│   └── views.py              # APIRouter — all endpoints
├── <support>/                # support package: service.py (+ models.py), no router
├── db/
│   └── schema.py             # ALL sqlalchemy db models + enums
├── utils/
│   ├── models.py             # CustomModel / RequestModel / ResponseModel
│   ├── pagination.py         # PageParams / Page
│   └── ownership.py          # get_owned
├── config.py                 # global Settings
├── dependencies.py           # ALL Depends() providers
├── errors.py                 # ServiceError hierarchy
└── main.py                   # app, lifespan, error handler, router mounting
alembic/                      # migrations
tests/                        # flat: test_<domain>_service.py + test_api.py
```

**Naming map** — the upstream doc's names vs. ours:

| Upstream | Ours | Why |
|----------|------|-----|
| `router.py` | `views.py` | Same role: the module holding every endpoint |
| `schemas.py` | `models.py` | Pydantic request/response models, per domain |
| `models.py` (db) | `src/db/schema.py` | DB models are centralized — one metadata, one alembic target |
| `dependencies.py` (per domain) | `src/dependencies.py` | Centralized: providers are mostly cross-domain wiring |
| `exceptions.py` (per domain) | `src/errors.py` | One `ServiceError` hierarchy, one central status mapping |
| `config.py` (per domain) | `src/config.py` | Single `Settings`; split it only if it becomes unwieldy |
| `models.py` (global base) | `src/utils/models.py` | Sits with the other shared modules, so a domain's `models.py` stays unambiguous |

Import across packages with an explicit module name:

```python
from src.documents.service import DocumentService
from src.errors import NotFoundError
```

## Async routes

Every route and every service method that touches I/O is `async def`. FastAPI
runs `sync` routes in a threadpool, so both work — but mixing them carelessly is
what bites.

- **Never** call a blocking function (sync HTTP, file reads, sync SDKs) inside
  an `async def` route or service — it stalls the whole event loop, not just
  that request.
- Offload sync SDKs with `asyncio.to_thread`
  (`fastapi.concurrency.run_in_threadpool` is equivalent in a route):

```python
session_obj = await asyncio.to_thread(stripe.checkout.Session.create, ...)
```

- CPU-heavy work can be offloaded the same way, but threads don't beat the
  GIL — anything genuinely CPU-bound at scale belongs in a task handler, not a
  request.

## Pydantic

**Push validation into the schema.** Use `Field` constraints, enums, and typed
URLs rather than hand-rolled checks in views or services:

```python
class ConversationCreate(RequestModel):
    title: Optional[str] = None
    collection_ids: List[uuid.UUID] = Field(min_length=1)  # 422 when empty
```

**Never subclass `pydantic.BaseModel` directly.** Every schema inherits from one
of the three bases in `src/utils/models.py`:

| Base | Use for | Carries |
|------|---------|---------|
| `RequestModel` | request bodies from a client | `extra: "forbid"` — an unknown field is a client bug, fail loudly |
| `ResponseModel` | schemas returned to a client over HTTP | `from_attributes: True` — lets `model_validate(row)` read an ORM object |
| `CustomModel` | everything else — internal DTOs, task payloads, plumbing (`Page`, `PageParams`) | nothing — it is the shared root |

Pick by what the model *is*, not by what config you want. An internal DTO that
never crosses the HTTP boundary belongs on `CustomModel` even when it wants
`extra: "forbid"`, which it then declares itself. Task-queue payloads belong
there too and must **not** forbid extras: they are a wire format between two
revisions of the service, so during a rolling deploy a 422 on an unknown key
becomes a retried-then-dropped task. `Settings` is the one thing outside this
tree — it is `BaseSettings`.

Keep `CustomModel` empty unless there's a measured reason: it runs for every
schema, and a wildcard `field_serializer` on it costs ~3x on serialization.

Other conventions:

- Reuse the DB enums from `src/db/schema.py` in schemas — don't restate the
  values.
- A `ValueError` raised in a validator surfaces as a 422 with detail, so it is a
  fine way to express a rule the type system can't.
- Validation the *service* must compute (e.g. a move that would create a
  cycle) is not schema work — raise `InvalidInputError` instead.
- Pydantic merges `model_config` down the inheritance chain, so a model needing
  an extra key declares just that key without losing what the base sets.

## Settings

One `Settings` (`src/config.py`, pydantic-settings), loaded from `.env.local`
locally and the environment in production. Every optional integration has a
`""` default and degrades to disabled, so local dev needs almost nothing
configured.

Add a variable: `Settings` field with a default → `.env.local` → production env.

## Dependencies

All providers live in `src/dependencies.py`. They are the composition root:
shared clients are lazily created module-level singletons, services are built
per request from them.

```python
def get_document_service(
    sessionmaker: async_sessionmaker[AsyncSession] = Depends(get_sessionmaker),
    gcs: GCSService = Depends(get_gcs_service),
) -> DocumentService:
    """..."""

    return DocumentService(sessionmaker=sessionmaker, gcs=gcs)
```

- **Chain dependencies** rather than repeating logic — `get_current_user`
  builds on `get_auth_service`, which builds on `get_sessionmaker`. FastAPI
  caches each dependency's result per request, so chaining costs nothing.
- **Prefer `async def`** for dependencies that do I/O; trivial client/service
  factories can be plain `def` because they only construct objects.
- **Dependencies can validate**, not just inject (`get_current_user` 401s). If
  the same path-param lookup starts repeating across routes, promote it to a
  `valid_<thing>` dependency instead of copying the check.
- Connection resources (pools, sessionmakers) come off `app.state`, populated
  in the `lifespan` handler in `main.py`.

## Views

A view validates (via the Pydantic schema), delegates to a service, and
returns. No business logic, no branching on domain outcomes, no database or
external API calls, no `HTTPException` for domain errors.

```python
router = APIRouter(prefix="/documents", tags=["documents"])


@router.post(
    "", response_model=DocumentCreateResponse, status_code=status.HTTP_202_ACCEPTED
)
async def create_document(
    body: DocumentCreate,
    user: User = Depends(get_current_user),
    service: DocumentService = Depends(get_document_service),
) -> DocumentCreateResponse:
    """
    Creates a document row and enqueues its ingestion task (202 Accepted).

    :param body: The document's source type and origin.
    :param user: The authenticated user.
    :param service: The injected document service.
    :return: The new id, status, and optional upload URL.
    """

    return await service.create(user.id, body)
```

Help the generated docs: always set `response_model`, a non-default
`status_code` where it applies (202 for enqueued work, 201 for creation, 204 for
delete), `tags` on the router, and a docstring — FastAPI uses it as the
description.

`user_id` is **never** a request parameter. It comes from `get_current_user`.

## REST conventions

Paths are plural nouns, nesting mirrors ownership, and the same path variable
name is reused so dependencies compose:

```
GET    /collections/{collection_id}
GET    /conversations/{conversation_id}/messages
PUT    /conversations/{conversation_id}/collections
```

Lists are offset-paginated: take `params: PageParams = Depends()`, return
`Page[XResponse]`. Pages are 1-based (`?page=`, `?size=`, capped at 100) and
carry a `total`, so clients can render prev/next. Derive `total` from a
`count(*)` over the same condition list the page query uses — never a second,
hand-copied predicate.

## Services

All business logic. A service takes its collaborators in `__init__`, never
imports FastAPI, and signals outcomes by raising from `src/errors.py`:

| Raise | Becomes |
|-------|---------|
| `NotFoundError` | 404 — also for *not-owned*, never 403, so existence doesn't leak |
| `ConflictError` | 409 |
| `InvalidInputError` | 422 |
| `SignatureError` | 400 — failed authenticity check by an untrusted caller |

`main.py` registers one handler on the `ServiceError` base and maps subclasses
to statuses; Starlette walks the MRO, so a new subclass only needs an entry in
that map.

Ownership goes through one helper, so the 404-not-403 rule lives in one place:

```python
collection = await get_owned(session, Collection, collection_id, user_id, "collection")
```

## Data access

**SQL-first, Pydantic-second.** Let Postgres do joins, filtering, ordering, and
aggregation; don't pull rows into Python to post-process them. Hot paths may be
hand-written SQL over asyncpg; everything else uses the SQLAlchemy
`async_sessionmaker`. Both are created in `lifespan` and taken from
`app.state`.

## Background work

Don't use FastAPI's `BackgroundTasks` for anything that is slow, must retry,
or must survive a worker dying — put it on a task queue (e.g. Cloud Tasks): the
endpoint enqueues, a task handler does the work, the client polls status.

Reach for `BackgroundTasks` only for sub-second in-process fire-and-forget whose
loss nobody would page about.

## Database & migrations

- `src/db/schema.py` is the source of truth; the schema is changed by editing
  models and autogenerating a revision, never by hand-editing a live database.
- Migrations must be static and reversible. Raw DDL autogenerate cannot see
  (extensions, enum types, special indexes) is hand-written in the migration,
  not in `schema.py`.
- Give revisions a descriptive slug:
  `alembic revision --autogenerate -m "add document language"`.
- Table naming: `lower_case_snake`, **singular** (`document`,
  `message_citation`), `_at` suffix for datetimes. Avoid reserved words as
  table names (`user` → `app_user`).

## Tests

Async client from day zero, dependency overrides instead of monkeypatching.
General rules are in `eetc:python-tests`.

- Service tests build the service directly and assert domain errors with
  `pytest.raises(NotFoundError | ConflictError | InvalidInputError)` —
  services never raise `HTTPException`.
- Endpoint tests use `httpx.AsyncClient` over `ASGITransport(app=app)` and swap
  services with `app.dependency_overrides`. Fake services are small local
  classes that return models or raise `ServiceError` subclasses — assert the
  status the central handler maps to.

```python
@pytest.mark.asyncio
# ai-generated
async def test_collection_not_found_returns_404():
    # given
    app.dependency_overrides[get_collection_service] = lambda: _FakeCollectionService()

    # when
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get(f"/collections/{uuid.uuid4()}")

    # then
    assert response.status_code == 404
    assert response.json()["detail"] == "collection not found"
```

## Formatting

`ruff format .` (usually `make format`). Formatting is not a review topic.

## Adding a domain

1. `src/my_domain/{__init__,models,service,views}.py`
2. DB tables → `src/db/schema.py` + `alembic revision --autogenerate`
3. Provider in `src/dependencies.py`
4. `app.include_router(my_domain_router)` in `src/main.py`
5. `tests/test_my_domain_service.py`, plus endpoint cases in `tests/test_api.py`
