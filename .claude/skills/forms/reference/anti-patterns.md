# Forms anti-patterns: do / avoid

The two bugs that show up in almost every hand-rolled form: leaked controllers
and using a stale `BuildContext` after an async submit. (Flutter 3.44 /
Dart 3.12.)

## 5. Controllers/focus nodes created in `build` (or never disposed)
A `TextEditingController` or `FocusNode` allocated inside `build` is recreated on
every rebuild — losing text/selection and leaking the previous instance.
Allocate once in `initState` and release in `dispose`.

```dart
// Avoid: new controller every rebuild → lost input, leaked instances.
class LoginForm extends StatelessWidget {
  const LoginForm({super.key});
  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();   // recreated each build
    final focus = FocusNode();               // never disposed → leak
    return TextField(controller: email, focusNode: focus);
  }
}

// Do: create in initState, dispose in dispose (StatefulWidget).
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late final TextEditingController _email;
  late final FocusNode _emailFocus;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _emailFocus = FocusNode();
  }

  @override
  void dispose() {
    _email.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(controller: _email, focusNode: _emailFocus);
}
```

Same rule for every controller/node on the form: each one needs its own
`dispose()` call.

## 2. Using `BuildContext` after `await` in a submit handler
After an `await`, the widget may have been removed from the tree. Touching
`context` (Navigator, `ScaffoldMessenger`, `Theme.of`) on an unmounted widget
throws or silently misbehaves. Guard with `context.mounted` after every await,
before using the context.

```dart
// Avoid: context used after await — may be unmounted.
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  await api.login(_email.text, _password.text);
  Navigator.of(context).pushReplacementNamed('/home');     // unsafe
  ScaffoldMessenger.of(context).showSnackBar(               // unsafe
    const SnackBar(content: Text('Welcome')),
  );
}

// Do: re-check context.mounted after each await before touching context.
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _loading = true);
  try {
    await api.login(_email.text, _password.text);
    if (!context.mounted) return;          // bail if widget is gone
    Navigator.of(context).pushReplacementNamed('/home');
  } on AuthException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

Notes:
- In a `State`, `context.mounted` and `State.mounted` are equivalent; either
  guard works. Outside a `State`, use `context.mounted`.
- Capture context-derived objects (e.g. `final messenger = ScaffoldMessenger.of(context);`)
  *before* the await if you prefer — then no post-await context access is needed.
