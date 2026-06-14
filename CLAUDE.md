# Flutter Clean Architecture — Claude Instructions

You are a senior Flutter engineer. Write production-grade code with strict clean architecture: dumb UI, Cubit-owned behavior, data-source-owned persistence.

All reusable components live in `corereusablepackage`. Always read `corereusablepackage/lib/corereusablepackage.dart` to discover available widgets, services, helpers, extensions, and base classes before creating custom ones.

```yaml
dependencies:
  corereusablepackage:
    path: ../corereusablepackage
```

> **Testing is a separate, opt-in pass.** A feature is "done" per the pre-delivery checklist below **without** tests by default. When tests are requested, follow the rules in `CLAUDETESTING.md`.

---

## Workflow

1. Inspect project structure, identify violations.
2. List affected files before changing.
3. Refactor one feature at a time — preserve behavior unless told otherwise.
4. Use `corereusablepackage` components wherever applicable.
5. Add missing localization keys.
6. Keep code compile-safe — no placeholders.
7. State `build_runner` need and `flutter analyze` result.

---

## Architecture

```
lib/features/<feature>/
  data/
    data_source/       # backend/local persistence
    models/            # fromJson/toJson
    repos/             # OPTIONAL — only when coordinating >1 data source
  presentation/
    cubit/             # state management
    refactor/          # body sections, view data, form helpers
    screens/           # short — creates Cubit, renders body
    widgets/           # small dumb components
```

**Forbidden:** `domain/`, `entities/`, `use_cases/`, `repo_interface/`, `repo_impl/`, `presentations/`.

---

## Project Setup

When creating a new project, derive names from project name (e.g., `guard_sync` → `GuardSyncApp`, `guard_sync_app.dart`).

```
lib/
  main.dart                       # initialization only
  <project_name>_app.dart         # app widget — separate file
  core/
    di/service_locator.dart
    routing/app_router.dart
    routing/app_routes.dart
    localization/lang_keys.dart    # static key constants
  features/ ...
assets/
  translations/
    ar.json                       # Arabic (primary)
    en.json                       # English
```

**main.dart:** `WidgetsFlutterBinding` → `Bloc.observer = AppBlocObserver()` → `EasyLocalization.ensureInitialized()` → Firebase if needed → `setupServiceLocator()` → `runApp(EasyLocalization(child: <ProjectName>App()))`.

**App file:** `BlocProvider.value(value: getIt<AppPreferencesCubit>())` → `BlocBuilder` → `MaterialApp.router` with `AppTheme.light()/dark()`, `themeMode` from state, `locale`, `routerConfig: AppRouter.router`. Never plain `MaterialApp(home:)`.

**After scaffolding, ALWAYS set up localization (mandatory for every new project):**
1. Localization: `assets/translations/ar.json`, `assets/translations/en.json`, and `lib/core/localization/lang_keys.dart`

See the **Localization** section below for exact templates.

> **Flavors + Fastlane + GitHub Actions is a separate, opt-in pass** — not part of scaffolding. A new project is "done" without it. When requested, follow `CLAUDEMAKEFLAVORSANDFASLANEWITHGITHUBACTIONS.md` (standard: `dev`/`prod` flavors, service-account Firebase auth).

---

## Localization

Create on every new project. Arabic is the primary language.

### Translation files — `assets/translations/`

Create `ar.json` and `en.json` with at least the base keys:

```json
{
  "app_name": "<ProjectTitle>"
}
```

Register in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/translations/
```

### LangKeys — `lib/core/localization/lang_keys.dart`

All localization keys must be defined as static constants. Never use raw strings for translation keys.

```dart
class LangKeys {
  LangKeys._();

  static const appName = 'app_name';
  // Add all keys here as the app grows
}
```

**Usage:** `context.translate(LangKeys.appName)` or `LangKeys.appName.tr()`. Never `'app_name'.tr()`.

When adding new UI text: add the key to both JSON files, add the constant to `LangKeys`, then use it in the UI.

---

## Layer Rules

| Layer | Owns | Must Not |
|-------|------|----------|
| **Screen** | Create Cubit, render body (30-70 lines) | Contain `_build...` methods or layout logic |
| **UI/Widgets** | Display state, forward actions to Cubit | Call Firebase/Supabase/SharedPreferences, filter lists, calculate, map errors |
| **Cubit** | Loading, refresh, filters, selected values, error keys, UI-ready data | Use BuildContext, call navigation |
| **Data Source** | Backend calls, transactions, validation, normalization, duplicates, status transitions | Depend on presentation |
| **Repo** | *(Optional)* Coordinate multiple data sources only | Exist as pure pass-through; contain single-source logic |
| **Models** | fromJson/toJson, handle Timestamp, strip id/created_at before writes, **value equality (`Equatable`)** | Hold behavior/logic; compare by reference |

---

## Repo Layer — Conditional

A repo exists **only** when a feature draws from more than one data source. A repo that just forwards calls is forbidden — delete it and let the cubit call the data source directly.

### When to create a repo

| Situation | Repo? |
|-----------|-------|
| Single data source (one backend, or one local store) | **No** — cubit → data source directly |
| Remote + local cache (cache-then-network, offline-first) | **Yes** |
| Combining two+ backends / sources into one result | **Yes** |
| Fallback (try source A, fall back to source B) | **Yes** |

### What a repo owns (when it exists)

Coordination only: cache-then-network strategy, source-combining, fallback ordering, deciding *which* source answers. It does **not** contain single-source logic (validation, normalization, error mapping) — that stays in each data source.

```dart
// Repo earns its place: coordinates remote + local cache.
class ArticlesRepo {
  final ArticlesRemoteDataSource _remote;
  final ArticlesLocalDataSource _local;
  ArticlesRepo(this._remote, this._local);

  Future<List<ArticleModel>> getArticles({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _local.getCached();
      if (cached.isNotEmpty) return cached; // cache-first
    }
    final fresh = await _remote.fetch();   // each source maps its own errors
    await _local.save(fresh);
    return fresh;
  }
}
```

For a single-source feature, there is no repo — the cubit holds the data source directly:

```dart
class ProductsCubit extends Cubit<ProductsState> {
  final ProductsDataSource _dataSource; // no repo in between
  ProductsCubit(this._dataSource) : super(const ProductsState());
}
```

---

## State Modeling

Every Cubit emits **one immutable state class** — a status enum plus data and UI-selection fields. No sealed/union states, no `freezed` for states, no booleans like `isLoading`/`hasError`. This keeps **compound state** (loaded **and** filtering **and** paginating) in a single object and needs no codegen.

### Rules

| Rule | Requirement |
|------|-------------|
| **Status** | A `status` enum: `initial / loading / loaded / error`. UI branches on `state.status`. |
| **Data fields** | The feature's data lives as typed fields on the state (e.g. `items`, `selected`, `page`). |
| **Error** | A nullable `errorKey` (stable `LangKeys` key, never a raw message). |
| **UI selection** | Filters, selected values, search terms live on the state (e.g. `selectedCategory`). |
| **Equality** | State extends `Equatable`; **all** fields in `props`. |
| **Updates** | Always via `copyWith`. Never construct a partial state that drops existing data. |
| **No booleans** | No `isLoading`/`hasError`/`isEmpty` flags — derive from `status` or expose getters. |
| **Derived data** | Computed views (e.g. filtered list, cart total) are **getters on the state**, not stored fields — so they can't drift out of sync. |

### State template

```dart
import 'package:equatable/equatable.dart';

enum ProductsStatus { initial, loading, loaded, error }

class ProductsState extends Equatable {
  final ProductsStatus status;
  final List<ProductModel> items;
  final String? selectedCategory;
  final String? errorKey;

  const ProductsState({
    this.status = ProductsStatus.initial,
    this.items = const [],
    this.selectedCategory,
    this.errorKey,
  });

  /// Derived view — never stored, always in sync.
  List<ProductModel> get visibleItems => selectedCategory == null
      ? items
      : items.where((p) => p.category == selectedCategory).toList();

  ProductsState copyWith({
    ProductsStatus? status,
    List<ProductModel>? items,
    String? selectedCategory,
    String? errorKey,
  }) {
    return ProductsState(
      status: status ?? this.status,
      items: items ?? this.items,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      errorKey: errorKey ?? this.errorKey,
    );
  }

  @override
  List<Object?> get props => [status, items, selectedCategory, errorKey];
}
```

### Cubit pattern

Emit deliberate `status` transitions via `copyWith`. On reload/refresh, set `loading` **without dropping** the existing `items` — so the UI can keep showing data while a spinner overlays. On error, set `status: error` + `errorKey` and keep prior data if appropriate.

```dart
class ProductsCubit extends Cubit<ProductsState> {
  final ProductsDataSource _dataSource;
  ProductsCubit(this._dataSource) : super(const ProductsState());

  Future<void> loadProducts() async {
    emit(state.copyWith(status: ProductsStatus.loading, errorKey: null));
    try {
      final items = await _dataSource.fetchProducts();
      emit(state.copyWith(status: ProductsStatus.loaded, items: items));
    } on AppException catch (e) {
      emit(state.copyWith(status: ProductsStatus.error, errorKey: e.key));
    }
  }

  // Filter is pure UI selection — no re-fetch, data preserved.
  void filterByCategory(String category) {
    emit(state.copyWith(selectedCategory: category));
  }
}
```

### UI reads state — no logic

```dart
BlocBuilder<ProductsCubit, ProductsState>(
  builder: (context, state) {
    switch (state.status) {
      case ProductsStatus.initial:
      case ProductsStatus.loading:
        return const AppLoader();
      case ProductsStatus.error:
        return AppError(message: context.translate(state.errorKey!));
      case ProductsStatus.loaded:
        return ProductsList(items: state.visibleItems); // derived getter
    }
  },
)
```

### Discipline note

Because one class *can* technically hold an inconsistent combo (`status: error` with full `items`), the contract is: **set `status` deliberately on every `emit`, always go through `copyWith`, and never store derived data — expose it as a getter.** That single habit removes the only downside of this approach.

---

## Models

Models are **immutable, value-comparable data holders** — `fromJson`/`toJson` and nothing else. They extend `Equatable` so the state that contains them compares by value. Without this, a `List<ProductModel>` in state compares by reference, and `BlocBuilder` either rebuilds when nothing changed or misses real changes — the same bug `Equatable` on states prevents (see State Modeling). Equatable on models is what makes Equatable on states actually work.

### Rules

| Rule | Requirement |
|------|-------------|
| **Equality** | Extends `Equatable`; **all** persisted fields in `props`. |
| **Immutable** | All fields `final`. Updates produce a new instance via `copyWith`. |
| **No behavior** | No logic, no network, no formatting-for-UI. Pure data + (de)serialization. |
| **Serialization** | `fromJson`/`toJson`; handle `Timestamp` → `DateTime`; strip `id`/`created_at` before writes via a `toJsonForWrite()` (or equivalent). |
| **Nullable-safe** | Tolerate missing/null backend fields with defaults — never throw in `fromJson`. |

### Template

```dart
import 'package:equatable/equatable.dart';

class ProductModel extends Equatable {
  final String id;
  final String name;
  final String category;
  final double price;
  final String? imageUrl;

  const ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.imageUrl,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        imageUrl: json['image_url'] as String?, // nullable — UI shows fallback
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'image_url': imageUrl,
      };

  /// Strip server-owned fields before writes.
  Map<String, dynamic> toJsonForWrite() =>
      toJson()..removeWhere((k, _) => k == 'id' || k == 'created_at');

  ProductModel copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    String? imageUrl,
  }) =>
      ProductModel(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        imageUrl: imageUrl ?? this.imageUrl,
      );

  @override
  List<Object?> get props => [id, name, category, price, imageUrl];
}
```

> If you adopt `freezed` for a model, it provides equality, immutability, and `copyWith` for free — but then `build_runner` is required. Plain `Equatable` (above) needs no codegen and is the default.

---

## Networking — REST Features Only

**Conditional, like the repo.** Applies **only** to features that call a raw REST API (custom backends, third-party REST services). Features on Firebase/Supabase use those SDKs directly — **no Dio, no base client.** Do not add this layer to a project that has no REST calls.

When a project does hit REST, all data sources share **one configured Dio client** — never hand-roll `http`/headers per data source.

### Rules

| Concern | Owned by |
|---------|----------|
| Base URL, timeouts, default headers | The shared client (built once, injected) |
| Auth token injection, logging, retry | Interceptors on that client |
| Turning HTTP/Dio errors into `AppException(key)` | `ErrorMapper` in the data source (per the Error Contract) |
| Parsing JSON → models | The data source |

### Base client

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';

class ApiClient {
  final Dio dio;

  ApiClient({required String baseUrl, TokenProvider? tokenProvider})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));
    // Add LogInterceptor in dev only (gate on FlavorConfig.isDev).
  }
}

typedef TokenProvider = String? Function();
```

Register it in the service locator with the flavor's base URL (`FlavorConfig.apiBaseUrl`), and inject it into REST data sources. Error mapping stays in the data source via `ErrorMapper` (Dio errors are already handled there per the Error Contract) — the client does **not** map errors itself.

---

## File Size

| Type | Target | Max |
|------|--------|-----|
| Screen | 30-70 | — |
| Body/Refactor/Widget | 80-120 | 150 |
| Cubit | No limit | — |

Split large files into `refactor/` or `widgets/`.

---

## Rules

**Imports:** Relative inside `lib/`. Never `package:project_name/...`. Package imports fine for dependencies.

**Localization:** `context.translate(LangKeys.key)` or `LangKeys.key.tr()`. Never raw strings like `'key'.tr()`. No hardcoded UI text. Add missing keys to both JSON files and `LangKeys`.

**Navigation:** `push` for drill-down (back returns). `go` for branch replacement. Parse route params in route/screen.

**Forms:** Use `TextFormField` with `AppRegex` validators and `inputFormatters` as default. Use `ReactiveFormsFlutter` only for complex/dynamic/multi-step forms. UI validation for immediate checks. Complex validation in helpers or data source.

**Errors:** Data sources throw mapped `AppException`s; cubits emit the key; UI translates + `showToast()`. Full contract in the **Error Contract** section below.

**Responsive:** `SingleChildScrollView`, `Wrap`, `Flexible`/`Expanded` only in constrained parents, `maxLines` + `overflow` on text, `SafeArea`. Never `Expanded` in unconstrained scrollable.

**Bug fixes:** Fix root cause. Rebuild UI from Cubit state — never stale data.

---

## Error Contract

Failures travel one way only: **data source throws → cubit catches → UI translates.** Each layer has exactly one job, and error mapping happens in exactly one place.

### Rules

| Layer | Responsibility |
|-------|----------------|
| **Data Source** | The ONLY layer that maps errors. Catches raw SDK errors (`FirebaseException`, `PostgrestException`, `DioException`, …) and throws a typed `AppException` carrying a stable `LangKeys` key. Throws `ValidationException` for invalid input **before** any backend call. |
| **Repo** | Pass-through. Does not catch, map, or wrap errors. |
| **Cubit** | Catches `AppException`, emits `copyWith(status: error, errorKey: e.key)`. Performs **no** mapping and never catches raw SDK types. |
| **UI** | Translates `state.errorKey` via `context.translate()` and shows `showToast()` or an error widget. Never sees a raw error. |

### Exception types

```dart
/// Base app error — always carries a stable LangKeys key, never a raw message.
class AppException implements Exception {
  final String key;
  const AppException(this.key);
}

/// Input rejected before any backend call.
class ValidationException extends AppException {
  const ValidationException(super.key);
}
```

### ErrorMapper — single source of mapping

Lives in the data layer. Converts every known SDK/backend error into a stable key, and maps anything unrecognized to a generic key so a raw error can **never** leak to the UI.

```dart
class ErrorMapper {
  ErrorMapper._();

  static AppException map(Object error) {
    if (error is AppException) return error; // already mapped
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return const AppException(LangKeys.errorPermission);
        case 'unavailable':
          return const AppException(LangKeys.errorNetwork);
      }
    }
    if (error is DioException) {
      return const AppException(LangKeys.errorNetwork);
    }
    return const AppException(LangKeys.errorUnknown); // nothing leaks raw
  }
}
```

### Data source usage

```dart
Future<List<ProductModel>> fetchProducts() async {
  try {
    final res = await _client.get('/products');
    return (res.data as List).map(ProductModel.fromJson).toList();
  } catch (e) {
    throw ErrorMapper.map(e); // raw SDK error → AppException(key)
  }
}

Future<void> createProduct(ProductModel product) async {
  if (!product.isValid) {
    throw const ValidationException(LangKeys.errorInvalidProduct); // pre-backend
  }
  try {
    await _client.post('/products', product.toJsonForWrite());
  } catch (e) {
    throw ErrorMapper.map(e);
  }
}
```

### Required base keys

Add to both JSON files and `LangKeys` on every project: `errorNetwork`, `errorPermission`, `errorUnknown`, plus feature-specific validation keys as needed.

---


**Cart:** Rebuilds from cubit state (not stale GetIt), empty state widget, image fallback.
**Profile Image:** ImagePickerService → upload via data source → update cached data → cubit emits state → UI shows toast via BlocListener.

---

## Pre-Delivery

- [ ] No `package:project_name/...` imports inside `lib/`
- [ ] No backend calls in presentation/common widgets
- [ ] No UI file over 150 lines without justification
- [ ] Valid localization JSON, no missing keys
- [ ] No missing `part` files
- [ ] State follows the State Modeling standard (status enum, Equatable, copyWith, derived getters)
- [ ] Errors mapped only in data sources via `ErrorMapper`; cubits emit keys; no raw errors in presentation
- [ ] No pass-through repos — a repo exists only if it coordinates >1 data source
- [ ] Models extend `Equatable` (all fields in `props`), immutable, no behavior
- [ ] REST features share one configured Dio client; Firebase/Supabase features use no Dio
- [ ] `build_runner` requirement stated
- [ ] `flutter analyze` result stated

> Tests are **not** part of this checklist by default. When requested, run the separate testing pass per `CLAUDETESTING.md`.
