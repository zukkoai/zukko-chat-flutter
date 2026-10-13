# Login form (end-to-end)

## Field-to-field navigation

Wire `textInputAction` + `onFieldSubmitted` to jump focus, and submit on the last field.

```dart
TextFormField(
  controller: _emailCtrl,
  focusNode: _emailFocus,
  textInputAction: TextInputAction.next,
  keyboardType: TextInputType.emailAddress,
  autofillHints: const [AutofillHints.email],
  decoration: const InputDecoration(labelText: 'Email'),
  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
  validator: (v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required';
    if (!value.contains('@')) return 'Enter a valid email';
    return null;
  },
),
TextFormField(
  controller: _passwordCtrl,
  focusNode: _passwordFocus,
  obscureText: true,
  textInputAction: TextInputAction.done,
  autofillHints: const [AutofillHints.password],
  decoration: const InputDecoration(labelText: 'Password'),
  onFieldSubmitted: (_) => _submit(),
  validator: (v) =>
      (v == null || v.length < 8) ? 'Min 8 characters' : null,
),
```

## Submit flow: validate -> save -> submit

Disable the button while loading; never fire twice.

```dart
bool _loading = false;

Future<void> _submit() async {
  final form = _formKey.currentState!;
  if (!form.validate()) return;
  form.save(); // triggers each onSaved
  setState(() => _loading = true);
  try {
    await ref.read(authProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
  } on AuthException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

// Button
FilledButton(
  onPressed: _loading ? null : _submit,
  child: _loading
      ? const SizedBox(
          height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2))
      : const Text('Sign in'),
)
```

Always guard `context`/`setState` with `if (mounted)` after `await`.
