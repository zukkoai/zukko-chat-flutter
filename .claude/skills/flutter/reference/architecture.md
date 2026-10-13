# Architecture: layers, dependencies, mapping, DI

## Core principle: separate UI from data

Flutter's official guidance splits an app into a **UI layer** and a **Data layer**. Most production teams insert a **Domain layer** between them ("Clean Architecture"). Dependencies always point **inward** toward the domain. The domain has **no Flutter imports** and no knowledge of how data is fetched or rendered.

```
┌─────────────────────────────────────────────────────────┐
│  PRESENTATION (UI layer)                                  │
│  Widgets (View)  ──1:1──>  ViewModel / Notifier / Bloc    │
│        holds UI state, exposes Commands, formats data     │
└───────────────────────────┬───────────────────────────────┘
                            │ depends on
                            ▼
┌─────────────────────────────────────────────────────────┐
│  DOMAIN (pure Dart, no Flutter)                            │
│  Entities  +  UseCases  +  Repository interfaces (abstract)│
└───────────────────────────▲───────────────────────────────┘
                            │ implements
┌───────────────────────────┴───────────────────────────────┐
│  DATA                                                       │
│  Repository impls (single source of truth for domain)      │
│  Services (REST/GraphQL/Firebase/platform)  +  DTOs/models  │
└─────────────────────────────────────────────────────────────┘
```

Rule of thumb: **presentation → domain ← data**. The domain layer is depended upon by both but depends on nothing.

## Layer responsibilities

| Layer | Contains | Knows about | MUST NOT |
|-------|----------|-------------|----------|
| Presentation | Widgets, ViewModels, routing | Domain | Touch DTOs, do HTTP, parse JSON |
| Domain | Entities, use cases, repo interfaces | Nothing external | Import `package:flutter`, `dart:io`, JSON |
| Data | Repo impls, services, DTOs | Domain (implements its interfaces) | Expose DTOs to presentation |

## Domain: entities vs use cases

Entities are immutable pure-Dart value objects. Use cases encapsulate one business action and are callable.

```dart
// domain/entities/user.dart  — pure Dart, no Flutter
class User {
  const User({required this.id, required this.email, required this.name});
  final String id;
  final String email;
  final String name;
}

// domain/repositories/auth_repository.dart — interface only
abstract interface class AuthRepository {
  Future<Result<User>> signIn({required String email, required String password});
  Future<Result<void>> signOut();
}

// domain/usecases/sign_in.dart
class SignIn {
  const SignIn(this._repo);
  final AuthRepository _repo;

  Future<Result<User>> call({required String email, required String password}) {
    if (!email.contains('@')) return Future.value(const Failure(InvalidEmail()));
    return _repo.signIn(email: email, password: password);
  }
}
```

`Result<T>` is the error-handling type — see the **error-handling** skill for `Result`, `Failure`, and `when`/`fold`. Repositories and use cases return `Result` instead of throwing across layers.

## Data: DTOs, services, and the repository as source of truth

DTOs (data models) mirror the wire format and live in the data layer only. Map them to domain entities at the repository boundary so JSON shapes never leak upward.

```dart
// data/models/user_dto.dart
class UserDto {
  const UserDto({required this.id, required this.email, required this.fullName});
  final String id;
  final String email;
  final String fullName;

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
      );

  User toDomain() => User(id: id, email: email, name: fullName); // mapping
}

// data/services/auth_api_service.dart — talks to the outside world
class AuthApiService {
  AuthApiService(this._client);
  final ApiClient _client;

  Future<UserDto> signIn(String email, String password) async {
    final json = await _client.post('/auth/login', {'email': email, 'password': password});
    return UserDto.fromJson(json);
  }
}

// data/repositories/auth_repository_impl.dart — single source of truth
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._cache);
  final AuthApiService _api;
  final SecureStorage _cache;

  @override
  Future<Result<User>> signIn({required String email, required String password}) async {
    try {
      final dto = await _api.signIn(email, password);
      await _cache.saveToken(dto.id);
      return Success(dto.toDomain()); // DTO -> entity here, not above
    } on ApiException catch (e) {
      return Failure(ServerFailure(e.message));
    }
  }

  @override
  Future<Result<void>> signOut() async { /* ... */ return const Success(null); }
}
```

The repository decides cache vs network, merges sources, and is the **one place** the rest of the app reads domain models.

## Dependency injection

Wire concrete implementations to interfaces at the composition root (`bootstrap.dart`), so the domain depends only on abstractions.

| Option | When | Notes |
|--------|------|-------|
| `provider` | Official recommendation; simple apps | `ChangeNotifierProvider`, `Provider`, `context.read/watch` |
| `riverpod` | Compile-safe DI + state; most modern apps | Providers double as the DI graph; see `state-management` |
| `get_it` (+ `injectable`) | Service-locator style, large apps | Decouples DI from the widget tree |

```dart
// app/bootstrap.dart (provider example)
MultiProvider(
  providers: [
    Provider<ApiClient>(create: (_) => ApiClient()),
    Provider<AuthRepository>(
      create: (c) => AuthRepositoryImpl(AuthApiService(c.read()), SecureStorage()),
    ),
    ChangeNotifierProvider(create: (c) => SignInViewModel(SignIn(c.read()))),
  ],
  child: const MyApp(),
);
```

## Widget composition rules

- **Prefer many small widgets** over one giant `build`. Each widget is a rebuild boundary — see the **optimization** skill.
- **Extract widgets, not methods.** A `_buildHeader()` method rebuilds with the parent; a `const HeaderWidget()` does not. Use methods only for trivial, non-`const` fragments.
- **`const` constructors everywhere possible.** They skip rebuilds and enable the const cache.
- **Use `Key`s** for stateful items in lists/reorderable collections so state follows the right element.
- **Push state down, lift events up.** Stateless leaves take values + callbacks; state lives in the ViewModel.

## Architecture checklist

- [ ] Feature folders with `data/ domain/ presentation/`; shared code in `core/`/`shared/`.
- [ ] Domain has zero Flutter/IO/JSON imports; entities are immutable.
- [ ] Repositories implement domain interfaces and map DTOs → entities.
- [ ] ViewModels hold UI state and call use cases; views are dumb.
- [ ] Errors flow through `Result<T>` (error-handling skill), not exceptions across layers.
- [ ] DI wired at one composition root; presentation depends on abstractions.
- [ ] State management handled per the **riverpod** / **bloc** skills.
