# Folder structure and file-placement rules

## Feature-first: group by feature, not by type

Each feature is a vertical slice with its own three layers. Cross-cutting code lives in `core/`; reusable widgets/services in `shared/`.

```
lib/
├── app/                      # entry point & wiring
│   ├── main.dart             # runApp + bootstrap
│   ├── bootstrap.dart        # init DI, error handlers, hydrated storage
│   └── router.dart           # GoRouter / app routes
├── core/                     # cross-cutting, no feature knowledge
│   ├── theme/                # ThemeData, ColorScheme, TextTheme, ThemeExtensions
│   ├── constants/
│   ├── errors/               # Failure types, Result<T> (see error-handling skill)
│   └── utils/                # extensions, formatters
├── shared/                   # reusable widgets & services
│   ├── widgets/              # PrimaryButton, AppScaffold, LoadingView
│   └── services/             # ApiClient, SecureStorage
└── features/
    └── auth/
        ├── data/
        │   ├── models/           # UserDto (JSON)
        │   ├── services/         # AuthApiService
        │   └── repositories/     # AuthRepositoryImpl
        ├── domain/
        │   ├── entities/         # User
        │   ├── repositories/     # AuthRepository (abstract)
        │   └── usecases/         # SignIn, SignOut
        └── presentation/
            ├── viewmodels/       # SignInViewModel
            ├── widgets/          # SignInForm
            └── pages/            # SignInPage
```

## File-placement rules (where each kind of file goes)

| Kind of file | Folder | Example |
|--------------|--------|---------|
| Entity (domain value object) | `features/<f>/domain/entities/` | `user.dart` → `User` |
| Model / DTO (wire format) | `features/<f>/data/models/` | `user_dto.dart` → `UserDto` |
| Repository interface (abstract) | `features/<f>/domain/repositories/` | `auth_repository.dart` → `AuthRepository` |
| Repository implementation | `features/<f>/data/repositories/` | `auth_repository_impl.dart` → `AuthRepositoryImpl` |
| Use case | `features/<f>/domain/usecases/` | `sign_in.dart` → `SignIn` |
| Service (external API client) | `features/<f>/data/services/` | `auth_api_service.dart` → `AuthApiService` |
| ViewModel / notifier / bloc | `features/<f>/presentation/viewmodels/` | `sign_in_view_model.dart` |
| Page (full screen) | `features/<f>/presentation/pages/` | `sign_in_page.dart` → `SignInPage` |
| Feature widget (subtree) | `features/<f>/presentation/widgets/` | `sign_in_form.dart` → `SignInForm` |
| Shared/reusable widget | `lib/shared/widgets/` | `primary_button.dart` |
| Shared service | `lib/shared/services/` | `api_client.dart` |
| Theme / design tokens | `lib/core/theme/` | `app_theme.dart` (see **theming** skill) |
| Constants | `lib/core/constants/` | `api_endpoints.dart` |
| Errors / Result type | `lib/core/errors/` | `failure.dart`, `result.dart` |
| Utils / extensions | `lib/core/utils/` | `date_extensions.dart` |
| App entry / DI / routing | `lib/app/` | `main.dart`, `bootstrap.dart`, `router.dart` |

## Single-responsibility at the file level

- **One public class per file.** A file declaring two top-level public classes is a smell — split it.
- **File name = `snake_case` of the class.** `SignInViewModel` → `sign_in_view_model.dart`; `UserDto` → `user_dto.dart`.
- Private helpers (`_Header`, `_Row`) may share the file with the public class they support.
- A file's location reflects its layer and role — never put a DTO under `domain/` or an entity under `data/`.

## Why feature-first beats layer-first

- Adding/removing a feature touches **one** folder, not five (`models/`, `repositories/`, `pages/`… scattered app-wide).
- Each feature can be reasoned about, tested, and even extracted into a package in isolation.
- The three sub-layers inside each feature keep the dependency rule (presentation → domain ← data) visible and local.
