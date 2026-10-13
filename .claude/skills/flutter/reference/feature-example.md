# A complete small feature across all layers

A minimal `auth` sign-in feature, file by file, showing the full presentation → domain ← data flow.

## Domain (pure Dart)

```dart
// features/auth/domain/entities/user.dart
class User {
  const User({required this.id, required this.email, required this.name});
  final String id;
  final String email;
  final String name;
}

// features/auth/domain/repositories/auth_repository.dart
abstract interface class AuthRepository {
  Future<Result<User>> signIn({required String email, required String password});
  Future<Result<void>> signOut();
}

// features/auth/domain/usecases/sign_in.dart
class SignIn {
  const SignIn(this._repo);
  final AuthRepository _repo;

  Future<Result<User>> call({required String email, required String password}) {
    if (!email.contains('@')) return Future.value(const Failure(InvalidEmail()));
    return _repo.signIn(email: email, password: password);
  }
}
```

## Data (DTOs, service, repository impl)

```dart
// features/auth/data/models/user_dto.dart
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

  User toDomain() => User(id: id, email: email, name: fullName);
}

// features/auth/data/services/auth_api_service.dart
class AuthApiService {
  AuthApiService(this._client);
  final ApiClient _client;

  Future<UserDto> signIn(String email, String password) async {
    final json = await _client.post('/auth/login', {'email': email, 'password': password});
    return UserDto.fromJson(json);
  }
}

// features/auth/data/repositories/auth_repository_impl.dart
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._cache);
  final AuthApiService _api;
  final SecureStorage _cache;

  @override
  Future<Result<User>> signIn({required String email, required String password}) async {
    try {
      final dto = await _api.signIn(email, password);
      await _cache.saveToken(dto.id);
      return Success(dto.toDomain()); // DTO -> entity at the boundary
    } on ApiException catch (e) {
      return Failure(ServerFailure(e.message));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    await _cache.clear();
    return const Success(null);
  }
}
```

## Presentation (ViewModel + View)

The ViewModel holds UI state, invokes the use case, and exposes a command. Detailed reactive mechanics live in the **riverpod** and **bloc** skills — this is the structural role with a plain `ChangeNotifier`.

```dart
// features/auth/presentation/viewmodels/sign_in_view_model.dart
class SignInViewModel extends ChangeNotifier {
  SignInViewModel(this._signIn);
  final SignIn _signIn;

  bool isLoading = false;
  String? error;
  User? user;

  Future<void> submit(String email, String password) async {
    isLoading = true; error = null; notifyListeners();
    final result = await _signIn(email: email, password: password);
    result.when(
      success: (u) => user = u,
      failure: (f) => error = f.message,
    );
    isLoading = false; notifyListeners();
  }
}
```

The View renders state and forwards intents only — no business logic, no HTTP, no parsing.

```dart
// features/auth/presentation/pages/sign_in_page.dart
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignInViewModel>();
    return Scaffold(
      body: SignInForm(
        isLoading: vm.isLoading,
        error: vm.error,
        onSubmit: vm.submit,
      ),
    );
  }
}
```

## Composition root

Wire interfaces to implementations once, at `bootstrap.dart`:

```dart
// app/bootstrap.dart
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

## Composed, const-friendly View tree

Extract widgets (not methods) so each is its own rebuild boundary and `const` where possible:

```dart
class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ProfileHeader(name: user.name),   // own rebuild boundary
          const Divider(),                    // const
          ProfileDetails(email: user.email),
        ],
      );
}
```
