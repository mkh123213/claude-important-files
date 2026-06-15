# Flutter Local Storage & Database — Claude Instructions

You are a senior Flutter engineer integrating local persistence into a strict clean-architecture codebase (dumb UI, Cubit-owned behavior, **data-source-owned persistence**). This is an **opt-in, per-project pass** — invoked only when a project needs local storage. There is **no single default**; pick per project using the decision table. The main `CLAUDE.md` governs architecture; this file governs how the chosen store plugs into it.

> **Maintenance reality (as of June 2026 — re-verify before adopting).** The Flutter local-DB landscape is fragmented. Originals of **Hive** and **Isar** were left largely unmaintained; the community forked both. Use **`hive_ce`** (Hive Community Edition), not original `hive`. For Isar, official development has slowed — use a community fork (**`isar_community`** or **`isar_plus`**), not the stalled original. **sqflite** remains actively maintained. Always check pub.dev for current versions and activity before committing.

---

## First: do you even need a database?

Most apps do not. Decide the storage *need* before picking a library.

| Need | Use |
|------|-----|
| A handful of settings/flags (theme, locale, onboarding done, token) | `shared_preferences` / `flutter_secure_storage` — **no database** |
| Cache of remote data + simple objects (most Firebase/Supabase apps) | **`hive_ce`** |
| Real local query engine (filter/sort/paginate locally), reactive, offline-first | **Isar** (community fork) |
| Strongly relational data (joins, foreign keys), or you want SQL | **sqflite** (or **Drift** for typed SQL) |

> For your typical app (Firebase/Supabase backend), the backend **is** the database — local storage is just **cache + settings**. Default to `shared_preferences` for settings and `hive_ce` for cache. Reach for Isar/sqflite only for genuine offline-first local querying.

---

## Architecture — the DB is a core service

The database **connection/instance** is shared infrastructure → it lives as a service in **`core/services/database/`**, registered once in the service locator and initialized in `bootstrap()`. Feature data sources do **not** open the DB — they depend on the injected service and run their feature operations on its native handle.

**Split of responsibility:**

| Concern | Lives in |
|---------|----------|
| Opening/closing the DB, holding the single instance, init in `bootstrap()` | **`DatabaseService`** (core/services) |
| Feature queries, writes, watch streams, DTO ↔ model mapping | **Feature local data source** (depends on the service) |
| Turning store errors into `AppException(key)` | Feature data source via `ErrorMapper` (per Error Contract) |
| Pure `Equatable` models, DB-annotation-free | `models/` (per Models rules) |

```
lib/
  core/
    services/
      database/
        database_service.dart        # abstract — lifecycle only
        <db>_database_service.dart    # impl per DB, exposes native handle
  features/<feature>/data/
    data_source/
      local/
        <feature>_local_data_source.dart   # uses the injected service
        <feature>_entity.dart              # annotated storage DTO (Hive/Isar)
    models/
      <feature>_model.dart                 # pure Equatable model
```

### The generic interface — lifecycle only

A single shared interface can only generalize **lifecycle**, not data access (Hive boxes, Isar collections, and SQL tables have nothing in common at the access level — forcing a shared access API would be a leaky abstraction and would kill Isar's watch streams). So the interface owns init/close/ready; each implementation exposes its **own** native handle.

```dart
// core/services/database/database_service.dart
abstract class DatabaseService {
  Future<void> init();
  Future<void> close();
  bool get isReady;
}
```

Feature data sources depend on the **concrete** service they need (a feature using Isar needs the Isar instance specifically), retrieved from the service locator. Registration in `bootstrap()`:

```dart
// inside bootstrap(), before runApp
final dbService = IsarDatabaseService(); // or Hive / Sqflite impl
await dbService.init();
getIt.registerSingleton<DatabaseService>(dbService);
getIt.registerSingleton<IsarDatabaseService>(dbService); // concrete, for data sources
```

---

## Option A — hive_ce (key-value / cache)

**Pick when:** caching remote data or key-value storage. Common for Firebase/Supabase apps.

```yaml
dependencies:
  hive_ce: ^latest
  hive_ce_flutter: ^latest
dev_dependencies:
  hive_ce_generator: ^latest
  build_runner: any
```

```dart
// core/services/database/hive_database_service.dart
class HiveDatabaseService implements DatabaseService {
  bool _ready = false;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ProductEntityAdapter()); // generated adapters
    _ready = true;
  }

  Future<Box<T>> box<T>(String name) => Hive.openBox<T>(name);

  @override
  Future<void> close() => Hive.close();

  @override
  bool get isReady => _ready;
}
```

```dart
// feature local data source — depends on the service, owns the feature ops
class ProductsLocalDataSource {
  final HiveDatabaseService _db;
  ProductsLocalDataSource(this._db);

  Future<void> cache(List<ProductModel> products) async {
    try {
      final box = await _db.box<ProductEntity>('products');
      await box.clear();
      await box.addAll(products.map(ProductEntity.fromModel));
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<ProductModel>> getCached() async {
    final box = await _db.box<ProductEntity>('products');
    return box.values.map((e) => e.toModel()).toList();
  }
}
```

---

## Option B — Isar (reactive local query engine)

**Pick when:** real local queries, large datasets, or offline-first with **reactive watch streams** (pairs perfectly with Cubit). Use a community fork.

```yaml
dependencies:
  isar_community: ^latest
  isar_community_flutter_libs: ^latest
dev_dependencies:
  isar_community_generator: ^latest
  build_runner: any
```

```dart
// core/services/database/isar_database_service.dart
class IsarDatabaseService implements DatabaseService {
  late final Isar _isar;
  bool _ready = false;

  @override
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([ProductEntitySchema], directory: dir.path);
    _ready = true;
  }

  Isar get instance => _isar; // native handle for data sources

  @override
  Future<void> close() => _isar.close();

  @override
  bool get isReady => _ready;
}
```

```dart
// feature local data source — owns queries + watch, uses the injected instance
class ProductsLocalDataSource {
  final IsarDatabaseService _db;
  ProductsLocalDataSource(this._db);

  Stream<List<ProductModel>> watchProducts() {
    return _db.instance.productEntitys
        .where()
        .watch(fireImmediately: true)
        .map((rows) => rows.map((e) => e.toModel()).toList());
  }

  Future<void> save(List<ProductModel> products) async {
    try {
      await _db.instance.writeTxn(() async {
        await _db.instance.productEntitys
            .putAll(products.map(ProductEntity.fromModel).toList());
      });
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
```

Cubit subscribes to the stream and emits `copyWith` — UI stays dumb:

```dart
class ProductsCubit extends Cubit<ProductsState> {
  final ProductsLocalDataSource _local;
  StreamSubscription? _sub;

  ProductsCubit(this._local) : super(const ProductsState()) {
    _sub = _local.watchProducts().listen(
      (items) => emit(state.copyWith(status: ProductsStatus.loaded, items: items)),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
```

---

## Option C — sqflite (relational / SQL)

**Pick when:** relational data (joins, foreign keys) or you want explicit SQL. For typed SQL with less boilerplate, consider **Drift**.

```yaml
dependencies:
  sqflite: ^latest
  path: ^latest
```

```dart
// core/services/database/sqflite_database_service.dart
class SqfliteDatabaseService implements DatabaseService {
  late final Database _db;
  bool _ready = false;

  @override
  Future<void> init() async {
    _db = await openDatabase(
      join(await getDatabasesPath(), 'app.db'),
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE products(id TEXT PRIMARY KEY, name TEXT, category TEXT, price REAL, image_url TEXT)',
      ),
    );
    _ready = true;
  }

  Database get db => _db; // native handle for data sources

  @override
  Future<void> close() => _db.close();

  @override
  bool get isReady => _ready;
}
```

```dart
// feature local data source — owns SQL + row↔model mapping
class ProductsLocalDataSource {
  final SqfliteDatabaseService _db;
  ProductsLocalDataSource(this._db);

  Future<List<ProductModel>> getByCategory(String category) async {
    try {
      final rows = await _db.db.query('products',
          where: 'category = ?', whereArgs: [category]);
      return rows.map(ProductModel.fromJson).toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
```

---

## Quick comparison

| | hive_ce | Isar (fork) | sqflite |
|--|---------|-------------|---------|
| **Model** | Key-value / objects | NoSQL collections | Relational SQL |
| **Queries** | In-Dart filtering | Indexed, type-safe | SQL |
| **Reactive** | Watch keys | **Watch queries (streams)** | No (manual) |
| **Codegen** | Yes (adapters) | Yes | No |
| **Best for** | Cache + settings | Offline-first + querying | Relational data |
| **Maintenance (Jun 2026)** | Community (`hive_ce`) | Forked; verify | Actively maintained |

---

## Pre-Delivery Checklist

- [ ] Storage need confirmed — not using a DB where `shared_preferences` suffices
- [ ] DB connection lives as a `DatabaseService` in `core/services/database/`, init in `bootstrap()`, registered in the service locator
- [ ] `DatabaseService` interface exposes lifecycle only (`init`/`close`/`isReady`); native handle on the concrete impl
- [ ] Feature local data sources depend on the injected service — they do **not** open the DB themselves
- [ ] Pure `Equatable` models kept DB-annotation-free; storage DTO maps ↔ model
- [ ] Errors mapped via `ErrorMapper` in the data source — no raw store exceptions leak
- [ ] Reactivity (Isar/hive_ce watch) exposed as a stream the cubit subscribes to; subscription cancelled in `close()`
- [ ] Chosen package version checked on pub.dev (fork status confirmed current)
- [ ] `build_runner` need stated (hive_ce / Isar) or noted as not needed (sqflite)
