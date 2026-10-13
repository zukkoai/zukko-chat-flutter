# Focus & controllers

## Lifecycle: always dispose controllers & nodes

Use a `StatefulWidget`. Leaking controllers/nodes is a common, real bug.

```dart
final _formKey = GlobalKey<FormState>();
final _emailCtrl = TextEditingController();
final _passwordCtrl = TextEditingController();
final _emailFocus = FocusNode();
final _passwordFocus = FocusNode();

@override
void dispose() {
  _emailCtrl.dispose();
  _passwordCtrl.dispose();
  _emailFocus.dispose();
  _passwordFocus.dispose();
  super.dispose();
}
```

## Input formatters & keyboard types

```dart
TextFormField(
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(11),
  ],
)
```

Pick the right `keyboardType`: `emailAddress`, `phone`, `number`,
`TextInputType.numberWithOptions(decimal: true)`, `visiblePassword`.

## Do / avoid

- Do trim and normalize input before validating and before sending.
- Do disable submit while loading and guard against double taps.
- Do dispose every controller and `FocusNode`.
- Do set `autofillHints` so password managers / OS autofill work.
- Avoid `autovalidateMode.always` on long forms (noisy, janky).
- Avoid trusting only UI validation — enforce rules in the domain layer.
