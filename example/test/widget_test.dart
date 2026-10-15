import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('one button per chat style opens that chat', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.byType(FilledButton), findsNWidgets(3));
    await tester.tap(find.text('Thread Feed'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Zukko AI'), findsWidgets);
  });
}
