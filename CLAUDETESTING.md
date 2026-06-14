# Flutter Testing — Claude Instructions

You are a senior Flutter engineer writing tests for a strict clean-architecture codebase (dumb UI, Cubit-owned behavior, data-source-owned persistence). This file is invoked **only when tests are requested** — it is a separate pass from feature work. The main `CLAUDE.md` governs architecture; this file governs how that architecture is verified.

> Read `corereusablepackage/lib/corereusablepackage.dart` before writing tests — reuse its test helpers, fakes, and fixtures if any exist. Do not duplicate them.

---

## Philosophy

Test the two layers that own logic: **Cubit** and **Data Source**. Everything else is covered indirectly or is dumb by design.

| Layer | Test? | Why |
|-------|-------|-----|
| **Cubit** | **Yes — required** | Owns loading, filters, selected values, error keys, UI-ready data. Pure state transitions. Highest bug density. |
| **Data Source** | **Yes — required** | Owns backend calls, validation, normalization, duplicates, status transitions, error mapping. Real logic. |
| **Repo** | Only if coordinating | Pass-through repos don't exist (forbidden). A repo that coordinates multiple sources (cache-then-network, fallback) **is** tested: mock its data sources, assert the coordination logic. |
| **Models** | No (indirect) | `fromJson/toJson` exercised through data-source tests. Test directly only for non-trivial parsing (Timestamp, nested, nullable). |
| **Screen / Widgets** | No | Dumb by design. Render state, forward actions. No logic to test. |

**Rule:** a feature's tests are done when its Cubit and Data Source tests pass. No widget tests unless explicitly requested.

---

## Scope — when tests are mandatory vs optional

Tests cost generation time and tokens. Spend them where bugs hurt.

| Feature type | Cubit test | Data source test |
|--------------|-----------|------------------|
| Auth, cart, payments, booking, status transitions, anything with money/state machines | **Mandatory** | **Mandatory** |
| Filters, search, pagination, favorites, multi-step forms | **Mandatory** | Recommended |
| Trivial read-only CRUD list/detail | Recommended | Optional |
| Pure static/info screens | Skip | Skip |

When in doubt, test the Cubit (cheaper, catches the most) and skip the trivial data source.

---

## Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  bloc_test: ^9.1.0
  mocktail: ^1.0.0
```

**Use `mocktail`, never `mockito`.** No codegen, no `@GenerateMocks`, no `build_runner` for mocks — cleaner and faster, consistent with the project style.

---

## Test Structure

Mirror the feature structure under `test/`:

```
test/
  features/<feature>/
    cubit/
      <feature>_cubit_test.dart
    data_source/
      <feature>_data_source_test.dart
  helpers/
    fixtures.dart        # shared fake models / json samples
    mocks.dart           # shared mock class declarations
```

Keep mocks and fixtures shared in `test/helpers/` — never redeclare the same mock in five files.

---

## Cubit Tests

### Rules

Every Cubit test group **must** cover:

1. **Initial state** — assert the cubit starts in the documented initial state.
2. **Success path** — mock the data source to return data; assert the correct sequence of emitted states (e.g. `Loading → Loaded`).
3. **Error path** — mock the data source to throw; assert the cubit emits the correct **error key** (the stable key from `ErrorMapper`, never a raw message).
4. **Behavior logic** — any filter, refresh, search, selection, or pagination the cubit owns gets its own `blocTest`.

### Conventions

- Mock the data source (or repo) — **never** hit a real backend.
- Use `setUp` to build a fresh cubit + mock per test. Never share cubit instances across tests.
- Assert emitted states with `expect:` in `blocTest`. Prefer asserting concrete states (`Equatable`/`freezed`) over `isA<>()` where state equality is defined.
- `verify()` that the data source method was called when the interaction matters (e.g. refresh actually re-fetches).
- Use `seed:` to start from a non-initial state when testing transitions like "filter an already-loaded list".

### Pattern

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockProductsDataSource dataSource;
  late ProductsCubit cubit;

  setUp(() {
    dataSource = MockProductsDataSource();
    cubit = ProductsCubit(dataSource);
  });

  tearDown(() => cubit.close());

  test('initial state is ProductsInitial', () {
    expect(cubit.state, const ProductsState());
  });

  group('loadProducts', () {
    blocTest<ProductsCubit, ProductsState>(
      'emits [Loading, Loaded] on success',
      build: () {
        when(() => dataSource.fetchProducts())
            .thenAnswer((_) async => tProductList);
        return cubit;
      },
      act: (c) => c.loadProducts(),
      expect: () => [
        const ProductsState(status: ProductsStatus.loading),
        ProductsState(status: ProductsStatus.loaded, items: tProductList),
      ],
      verify: (_) => verify(() => dataSource.fetchProducts()).called(1),
    );

    blocTest<ProductsCubit, ProductsState>(
      'emits [Loading, Error] with mapped key on failure',
      build: () {
        when(() => dataSource.fetchProducts())
            .thenThrow(AppException(LangKeys.errorNetwork));
        return cubit;
      },
      act: (c) => c.loadProducts(),
      expect: () => [
        const ProductsState(status: ProductsStatus.loading),
        const ProductsState(
          status: ProductsStatus.error,
          errorKey: LangKeys.errorNetwork,
        ),
      ],
    );
  });

  group('filterByCategory', () {
    blocTest<ProductsCubit, ProductsState>(
      'filters an already-loaded list without re-fetching',
      build: () => cubit,
      seed: () => ProductsState(
        status: ProductsStatus.loaded,
        items: tProductList,
      ),
      act: (c) => c.filterByCategory('burgers'),
      expect: () => [
        ProductsState(
          status: ProductsStatus.loaded,
          items: tProductList,
          selectedCategory: 'burgers',
        ),
      ],
      verify: (_) => verifyNever(() => dataSource.fetchProducts()),
    );
  });
}
```

---

## Data Source Tests

### Rules

Every Data Source test group **must** cover:

1. **Normalization** — raw backend response is correctly mapped into models (field mapping, defaults, nullable handling, Timestamp conversion).
2. **Validation** — invalid input is rejected before any backend write.
3. **Error mapping** — backend/SDK errors are caught and converted to **stable error keys** via `ErrorMapper`. Assert the thrown exception carries the expected key, not a raw SDK message.
4. **Status transitions / duplicates** — if the source enforces a state machine or dedup, test the allowed and forbidden transitions.

### Conventions

- Mock the backend client (Firebase/Supabase/Dio) — never touch a live backend or network.
- Register fallback values with `registerFallbackValue` in `setUpAll` for any custom type passed to a mock matcher (`any()`).
- Assert thrown exceptions with `expect(() => ..., throwsA(isA<AppException>()))` and check the carried key.
- Test the **write-strip** behavior: `id`/`created_at` are removed before writes (per model rules).

### Pattern

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockApiClient client;
  late ProductsDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(FakeProductModel());
  });

  setUp(() {
    client = MockApiClient();
    dataSource = ProductsDataSource(client);
  });

  group('fetchProducts', () {
    test('normalizes raw response into models', () async {
      when(() => client.get(any()))
          .thenAnswer((_) async => tRawProductsJson);

      final result = await dataSource.fetchProducts();

      expect(result, isA<List<ProductModel>>());
      expect(result.first.id, tRawProductsJson['data'][0]['id']);
      expect(result.first.imageUrl, isNotNull);
    });

    test('maps network failure to stable error key', () async {
      when(() => client.get(any())).thenThrow(DioException(/* ... */));

      expect(
        () => dataSource.fetchProducts(),
        throwsA(
          isA<AppException>()
              .having((e) => e.key, 'key', LangKeys.errorNetwork),
        ),
      );
    });
  });

  group('createProduct', () {
    test('rejects invalid input before calling backend', () async {
      expect(
        () => dataSource.createProduct(tInvalidProduct),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(() => client.post(any(), any()));
    });

    test('strips id and created_at before write', () async {
      when(() => client.post(any(), any()))
          .thenAnswer((_) async => tCreatedResponse);

      await dataSource.createProduct(tValidProduct);

      final captured =
          verify(() => client.post(any(), captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured.containsKey('id'), isFalse);
      expect(captured.containsKey('created_at'), isFalse);
    });
  });
}
```

---

## Shared Mocks & Fixtures

`test/helpers/mocks.dart` — declare every mock once:

```dart
import 'package:mocktail/mocktail.dart';

class MockProductsDataSource extends Mock implements ProductsDataSource {}
class MockApiClient extends Mock implements ApiClient {}

// Fallback fakes for registerFallbackValue
class FakeProductModel extends Fake implements ProductModel {}
```

`test/helpers/fixtures.dart` — sample data, one source of truth:

```dart
final tProductList = [
  ProductModel(id: '1', name: 'Classic Burger', category: 'burgers', price: 25),
  ProductModel(id: '2', name: 'Margherita',     category: 'pizza',   price: 40),
];

final tBurgersOnly =
    tProductList.where((p) => p.category == 'burgers').toList();

const tRawProductsJson = {
  'data': [
    {'id': '1', 'name': 'Classic Burger', 'category': 'burgers', 'price': 25},
  ],
};
```

---

## Common Feature Patterns

**Favorites** — test: toggle adds/removes from state, icon-driving state flips, persistence call fires once. Seed a loaded state, act toggle, assert state + `verify` data source called.

**Cart** — test: add increments quantity (not duplicates), remove clears line, totals recompute from state, empty state emitted when last item removed. Totals must be asserted from emitted state, never recomputed in the test.

**Auth** — mandatory both layers: success emits authenticated state, wrong credentials emit the mapped error key, validation rejects malformed email/password before the backend call.

**Profile image** — data source: upload returns URL, cached data updated; cubit: emits success state that the `BlocListener` turns into a toast. Mock the picker + uploader.

**Pagination** — test: first page loads, next page appends (not replaces), `nextPage`/cursor exhaustion emits an "end reached" flag.

---

## Forbidden in Tests

- **No real backend / network calls.** Every external dependency is mocked.
- **No `mockito`.** Mocktail only.
- **No logic duplicated from production** (e.g. recomputing cart totals in the test). Assert the state the cubit produced.
- **No shared mutable cubit** across tests. Fresh instance per `setUp`.
- **No asserting raw error strings.** Assert the stable `LangKeys` error key.
- **No widget tests** unless explicitly requested.
- **No `Future.delayed` / real timers** to "wait" — use `bloc_test`'s `wait:` or pump as needed.

---

## Pre-Delivery — Testing Checklist

- [ ] Cubit test covers initial / success / error / behavior paths
- [ ] Data source test covers normalization / validation / error-key mapping
- [ ] All external dependencies mocked (no live backend or network)
- [ ] Mocktail used; fallback values registered for custom matcher types
- [ ] Mocks & fixtures shared from `test/helpers/`, not redeclared
- [ ] Error assertions check stable `LangKeys` keys, not raw messages
- [ ] Fresh cubit/mock per test; no shared mutable state
- [ ] `flutter test` passes; result stated
- [ ] `build_runner` need stated (if `freezed`/`json_serializable` states are involved)
