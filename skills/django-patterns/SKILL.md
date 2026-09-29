---
name: django-patterns
description: >
  Django / DRF architecture standard: layers, permission classes, ViewSets,
  serializers, service layer, environment variables, local vs production
  async work, ORM performance, migrations and tests.
  TRIGGER when: designing or modifying Django models, DRF serializers, views,
  permissions, or the service layer, or integrating a new data source.
  DO NOT TRIGGER when: the project does not use Django.
---

# Django Patterns

The repo's `codebase-overview` skill names its actual service class, data
stores, permission classes and data sources.

## Layers

```
Client → Permission → View → Serializer → Service → ORM / external stores
```

- **Views** (DRF ViewSets): validate via a serializer, call the service, return
  `Response`. No business logic, no direct external API calls.
- **Service layer**: all business logic, with its clients and data sources
  injected in `__init__`.
- **Data sources / clients**: one module per external API.

## Authentication

Every view declares a custom permission class (API key in a request header):

```python
class SomeViewSet(viewsets.ViewSet):
    permission_classes = [CheckAPIKeyAuth]
```

## DRF Patterns

### ViewSet

```python
class SomeViewSet(viewsets.ViewSet):
    """ViewSet for ..."""

    permission_classes = [CheckAPIKeyAuth]

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.data_service = DataService(...)

    def list(self, request: Request) -> Response:
        """..."""

        serializer = SomeQuerySerializer(data=request.query_params)
        if not serializer.is_valid():
            return Response(serializer.errors, status=400)

        result = self.data_service.get_something(
            **serializer.validated_data
        )

        return Response(result)
```

### Serializer

Query parameter serializers use `serializers.Serializer` (not ModelSerializer):

```python
class SomeQuerySerializer(serializers.Serializer):
    """..."""

    symbol = serializers.CharField()
    from_date = serializers.DateField(required=False)
    to_date = serializers.DateField(required=False)
```

Use `ModelSerializer` only for Django ORM models:

```python
class CompanySerializer(serializers.ModelSerializer):
    """..."""

    class Meta:
        model = Company
        fields = ["id", "symbol", "name", "sector"]
        read_only_fields = ["id"]
```

## Service Layer

One service orchestrates the operations; collaborators are injected:

```python
class DataService:
    """..."""

    def __init__(
        self,
        big_query_client: BigQueryClient,
        yahoo_finance: YahooFinance,
        # inject all data sources here
    ):
        self.big_query_client = big_query_client
        self.yahoo_finance = yahoo_finance
```

## Async Work (local vs production)

Use a task queue (Cloud Tasks) in production and a thread pool locally,
branching on `settings.IS_LOCAL`:

```python
if settings.IS_LOCAL:
    with ThreadPoolExecutor() as executor:
        executor.map(self._update_symbol, symbols)
else:
    self._create_cloud_tasks(symbols)
```

## Environment Variables

1. Add to Secret Manager in GCP
2. Add to `.env.local` for local development
3. Add to `env = environ.Env(...)` in `settings.py`
4. Load via `env("VAR_NAME")`
5. Add to the deploy manifest (e.g. `service.yaml`)

## ORM Best Practices

### N+1 Prevention

```python
# foreign keys
queryset = Model.objects.select_related("related_model")

# many-to-many
queryset = Model.objects.prefetch_related("tags")
```

### Bulk Operations

```python
# bulk create
Model.objects.bulk_create([Model(field=val) for val in values])

# bulk update
Model.objects.filter(...).update(field=value)
```

## Migrations

- `python manage.py makemigrations` after changing models; commit the
  migration with the model change.
- Test migrations locally before running them against production.

## Tests

General rules are in `eetc:python-tests`.

- Use Django's `TestCase` for database-dependent tests.
- Test serializers independently from views.
- Mock every external API and data store client (rate limits, cost, flakiness).
- Run with `python manage.py test`.

```python
# ai-generated
def test_update_price_data_returns_success_status(self):
    # given
    symbols = ["AAPL", "GOOGL"]

    # when
    result = self.data_service.update_price_data(symbols)

    # then
    self.assertEqual(result["status"], "success")
    self.assertEqual(result["count"], 2)
```
