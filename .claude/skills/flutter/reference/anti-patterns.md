# Architecture anti-patterns

Do/avoid examples for the architecture mistakes that break layering, testability, and SRP. Cross-refs: **riverpod** / **bloc** for state, **error-handling** for `Result`, **networking** for repositories.

## 1. Logic / API calls / computation in `build()`

`build` runs on every rebuild. Network calls, parsing, and heavy loops there fire repeatedly, leak, and make the widget impossible to test in isolation.

```dart
// avoid: fetch + sort + compute on every rebuild, no caching, no error handling
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: http                                   // new request every rebuild
          .get(Uri.parse('https://api.example.com/products'))
          .then((r) => (jsonDecode(r.body) as List)  // parsing in the widget
              .map(Product.fromJson)
              .toList()
            ..sort((a, b) => b.rating.compareTo(a.rating))), // business rule in UI
      builder: (context, snap) => ListView(/* ... */),
    );
  }
}
```

```dart
// do: build only describes UI; the ViewModel owns fetching, sorting, and state
class ProductsViewModel extends ChangeNotifier {
  ProductsViewModel(this._getTopProducts);
  final GetTopProducts _getTopProducts;

  AsyncValue<List<Product>> state = const AsyncValue.loading();

  Future<void> load() async {
    state = const AsyncValue.loading();
    notifyListeners();
    final result = await _getTopProducts();          // use case does fetch + sort
    state = result.fold(AsyncValue.error, AsyncValue.data);
    notifyListeners();
  }
}

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key, required this.viewModel});
  final ProductsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // build() reads state and renders — nothing else.
    return switch (viewModel.state) {
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError(:final error) => ErrorView(error),
      AsyncData(:final value) => ProductList(products: value),
    };
  }
}
```

## 2. Deep nesting, no modularization

One enormous `build` with a 10-deep widget tree can't be `const`, can't be reused, and rebuilds wholesale.

```dart
// avoid: a single giant tree, nothing extracted, nothing const
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(child: Text(user.initials)),
            Column(children: [
              Text(user.name),
              Text(user.email),
              Row(children: [Icon(Icons.star), Text('${user.points} pts')]),
            ]),
          ]),
        ),
        // ...300 more lines...
      ],
    ),
  );
}
```

```dart
// do: extract const components, one responsibility each
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        UserHeader(user: user),
        const Divider(),
        OrderSummary(orders: orders),
      ],
    ),
  );
}

class UserHeader extends StatelessWidget {
  const UserHeader({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(child: Text(user.initials)),
          const SizedBox(width: 12),
          UserIdentity(name: user.name, email: user.email, points: user.points),
        ],
      ),
    );
  }
}
```

Smaller `const` subtrees skip rebuilds — see the **optimization** skill.

## 3. Wrong / no state management

`setState` is fine for one ephemeral widget. Threading shared state through dozens of widgets via `setState` and constructor params creates a tangle and rebuilds entire screens.

```dart
// avoid: app-wide cart held in a StatefulWidget, passed down by hand
class _HomeState extends State<Home> {
  final List<Item> _cart = [];          // shared state stranded in the UI layer

  void _add(Item i) => setState(() => _cart.add(i)); // rebuilds the whole screen

  @override
  Widget build(BuildContext context) =>
      ProductGrid(cart: _cart, onAdd: _add); // prop-drilling everywhere
}
```

```dart
// do: a dedicated notifier; widgets watch only what they need (riverpod)
@riverpod
class Cart extends _$Cart {
  @override
  List<Item> build() => const [];

  void add(Item item) => state = [...state, item];
}

class ProductTile extends ConsumerWidget {
  const ProductTile({super.key, required this.item});
  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AddButton(onTap: () => ref.read(cartProvider.notifier).add(item));
  }
}
```

Pick **riverpod** or **bloc** for anything beyond a single screen's local state.

## 4. Hardcoding URLs / API keys / secrets / config

Literals scattered through code can't change per environment, leak secrets into version control, and can't be stubbed in tests.

```dart
// avoid: base URL + secret baked into the source, committed to git
class ApiClient {
  final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.prod.example.com',          // can't switch to staging
    headers: {'x-api-key': 'sk_live_8a4f...c12'},     // secret in the repo
  ));
}
```

```dart
// do: read config from a typed Env layer fed by --dart-define
class Env {
  static const apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');
  static const apiKey = String.fromEnvironment('API_KEY'); // injected, never committed
}

class ApiClient {
  ApiClient({String? baseUrl}) // overridable in tests
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? Env.apiBaseUrl,
          headers: {'x-api-key': Env.apiKey},
        ));
  final Dio _dio;
}
// flutter run --dart-define=API_BASE_URL=https://api.staging.example.com --dart-define=API_KEY=...
```

Keep secrets in a `--dart-define-from-file` JSON that is git-ignored, or a secret manager — never in source.

## 5. God class / god object

One class that fetches, parses, caches, validates, and renders is untestable and changes for every reason.

```dart
// avoid: a single class doing UI + business + data + persistence
class ProfileScreen extends StatefulWidget { /* ... */ }

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>> fetchProfile() async { /* HTTP + JSON */ }
  bool isValidEmail(String e) => e.contains('@');     // domain rule
  Future<void> saveToDisk(Map<String, dynamic> j) async { /* persistence */ }

  @override
  Widget build(BuildContext context) { /* + all the UI */ }
}
```

```dart
// do: one responsibility per class across the layers
// domain: pure rule
class ValidateEmail {
  bool call(String email) => RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
}

// data: source of truth, maps DTO -> entity
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._service);
  final ProfileService _service;

  @override
  Future<Result<Profile>> getProfile() async {
    final dto = await _service.fetch();
    return Result.ok(dto.toEntity());
  }
}

// presentation: state + intent only
class ProfileViewModel extends ChangeNotifier { /* calls use cases */ }

// presentation: renders state
class ProfileScreen extends StatelessWidget { /* build() only */ }
```

## 6. Tight coupling, no abstraction

When a widget constructs a concrete service, you can't swap implementations or inject a fake — the UI is welded to the network.

```dart
// avoid: widget instantiates a concrete service directly
class LoginButton extends StatelessWidget {
  const LoginButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => FirebaseAuthService().signIn(), // hard dependency, untestable
      child: const Text('Sign in'),
    );
  }
}
```

```dart
// do: depend on an interface, inject the impl via DI
abstract interface class AuthRepository {
  Future<Result<User>> signIn(Credentials creds);
}

class LoginButton extends ConsumerWidget {
  const LoginButton({super.key, required this.creds});
  final Credentials creds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => ref.read(authRepositoryProvider).signIn(creds),
      child: const Text('Sign in'),
    );
  }
}

// bootstrap.dart wires the concrete impl once
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.read(firebaseAuthServiceProvider)),
);
```

Tests override `authRepositoryProvider` with a fake — no Firebase needed. Works the same with `get_it`.

## 7. Mixing UI and business logic

Validation, domain rules, and API calls embedded in `onPressed` callbacks can't be reused or unit-tested.

```dart
// avoid: validation + domain math + HTTP inside the widget
ElevatedButton(
  onPressed: () async {
    if (amountController.text.isEmpty ||
        double.parse(amountController.text) <= 0) return;   // validation in UI
    final fee = double.parse(amountController.text) * 0.029 + 0.30; // business rule
    await http.post(Uri.parse('$base/charge'),               // API call in UI
        body: jsonEncode({'total': fee}));
  },
  child: const Text('Pay'),
);
```

```dart
// do: rules in the domain, I/O in the repository, widget only forwards intent
// domain
class CalculateFee {
  Money call(Money amount) => amount * 0.029 + const Money(0.30);
}

// presentation
ElevatedButton(
  onPressed: viewModel.canPay ? viewModel.pay : null, // command exposes validity
  child: const Text('Pay'),
);

// view model
class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel(this._charge, this._calculateFee);
  final ChargePayment _charge;
  final CalculateFee _calculateFee;

  bool get canPay => amount != null && amount! > Money.zero;

  Future<void> pay() async {
    final total = amount! + _calculateFee(amount!);
    await _charge(total); // repository handles HTTP and returns Result
  }
}
```
