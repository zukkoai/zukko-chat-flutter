# Validation

## autovalidateMode strategy

- `disabled` — validate only on submit. Good default for short forms.
- `onUserInteraction` — start showing errors per-field after the user touches it. Best UX for signup; avoids yelling at an empty form on first paint.
- `always` — re-validate on every rebuild; use sparingly.

Set it on the `Form` (applies to children) or per field.

```dart
Form(
  key: _formKey,
  autovalidateMode: AutovalidateMode.onUserInteraction,
  child: ...,
)
```

## Async / server-side validation

`validator` is synchronous. For server checks (e.g. "email taken"), validate on submit, catch the server error, and surface it. Two patterns:

- Map the server error to a field by holding an error string in state and feeding it into that field's `validator`, then call `form.validate()`.
- Or show a `SnackBar` / banner for non-field-specific errors.

```dart
String? _serverEmailError;
// in validator:
validator: (v) {
  if (_serverEmailError != null) return _serverEmailError;
  /* sync rules */
},
// after a 409 response:
setState(() => _serverEmailError = 'Email already registered');
_formKey.currentState!.validate();
```

Clear `_serverEmailError` when the user edits the field, so the stale error doesn't stick.

## Validate in the domain layer too

UI validation is for UX, not safety. Re-validate (or use value objects / `freezed` models with factory guards) in the domain/data layer so invalid data cannot reach your backend even if the form is bypassed.

```dart
final class Email {
  final String value;
  Email._(this.value);
  static Email parse(String raw) {
    final v = raw.trim();
    if (!v.contains('@')) throw FormatException('Invalid email');
    return Email._(v);
  }
}
```

## Complex forms

- **`flutter_form_builder` + `form_builder_validators`** — declarative fields (`FormBuilderTextField`, `FormBuilderDropdown`) and composable validators (`FormBuilderValidators.compose([required(), email()])`). Reach for it on large multi-section forms.
- **State management** — for forms tied to app state, drive validation/submit from a Riverpod `Notifier` or a Bloc instead of local `setState`. Keep the `TextEditingController`s in the widget; keep submit/validation rules in the notifier.
