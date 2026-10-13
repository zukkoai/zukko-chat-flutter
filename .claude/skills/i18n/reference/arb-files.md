# ARB file features

`app_en.arb` (template — descriptions live here):

```json
{
  "@@locale": "en",
  "welcome": "Welcome",
  "greeting": "Hello, {name}!",
  "@greeting": {
    "description": "Greeting with the user's name",
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "itemsInCart": "{count, plural, =0{Cart is empty} =1{1 item} other{{count} items}}",
  "@itemsInCart": {
    "description": "Number of items in cart",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "pronoun": "{gender, select, male{He} female{She} other{They}} replied",
  "@pronoun": {
    "placeholders": { "gender": { "type": "String" } }
  }
}
```

`app_uz.arb` (translation — no `@` metadata needed):

```json
{
  "@@locale": "uz",
  "welcome": "Xush kelibsiz",
  "greeting": "Salom, {name}!",
  "itemsInCart": "{count, plural, =0{Savat bo'sh} other{{count} ta mahsulot}}",
  "pronoun": "{gender, select, male{U} female{U} other{Ular}} javob berdi"
}
```

Generated usage:

```dart
Text(l10n.itemsInCart(count));     // "Cart is empty" / "1 item" / "3 items"
Text(l10n.pronoun(user.gender));   // select/gender
```

## Notes
- Put `@`-descriptions and placeholder types in the **template** ARB only; translations just supply the values.
- Use `plural` / `select` rather than concatenating sentence fragments — different languages order and inflect differently.
- Re-run `flutter gen-l10n` after adding or renaming keys.
