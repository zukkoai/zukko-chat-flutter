import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';

Widget _host(Widget child, {double dpr = 2}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(devicePixelRatio: dpr),
    child: Center(child: child),
  ),
);

ImageProvider _provider(WidgetTester tester) =>
    tester.widget<Image>(find.byType(Image)).image;

void main() {
  testWidgets('a network image is decoded at its drawn size (U18)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatImage(
          url: 'https://c.test/big.jpg',
          width: 100,
          height: 60,
          placeholderColor: Color(0xFF000000),
          iconColor: Color(0xFFFFFFFF),
        ),
      ),
    );
    final provider = _provider(tester);
    expect(provider, isA<ResizeImage>());
    // longer drawn side (100) x device pixel ratio (2)
    expect((provider as ResizeImage).width, 200);
  });

  testWidgets('an avatar-sized image is decoded small', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox.square(
          dimension: 28,
          child: ChatAvatar(
            name: 'A',
            size: 28,
            imageUrl: 'https://c.test/a.png',
            background: Color(0xFF000000),
            initialStyle: TextStyle(color: Color(0xFFFFFFFF)),
          ),
        ),
        dpr: 3,
      ),
    );
    expect((_provider(tester) as ResizeImage).width, 84);
  });

  testWidgets('a width-less image uses its parent width', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 150,
          child: ChatImage(
            url: 'https://c.test/big.jpg',
            height: 40,
            placeholderColor: Color(0xFF000000),
            iconColor: Color(0xFFFFFFFF),
          ),
        ),
        dpr: 1,
      ),
    );
    expect((_provider(tester) as ResizeImage).width, 150);
  });

  testWidgets('a non-http url shows the placeholder, no image', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChatImage(
          url: 'ftp://x/y.png',
          width: 10,
          height: 10,
          placeholderColor: Color(0xFF000000),
          iconColor: Color(0xFFFFFFFF),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
  });
}
