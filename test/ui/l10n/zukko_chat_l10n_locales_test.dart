import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/format.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import '../chat/chat_fakes.dart';

const _english = ZukkoChatL10n();
const _uzCyrlLocale = Locale.fromSubtags(
  languageCode: 'uz',
  scriptCode: 'Cyrl',
);

final _locales = <Locale, ZukkoChatL10n>{
  const Locale('en'): _english,
  const Locale('ru'): ZukkoChatL10n.ru,
  const Locale('uz'): ZukkoChatL10n.uzLatn,
  _uzCyrlLocale: ZukkoChatL10n.uzCyrl,
  const Locale('tr'): ZukkoChatL10n.tr,
  const Locale('kaa'): ZukkoChatL10n.kaa,
};

final _translations = {
  'ru': ZukkoChatL10n.ru,
  'uzLatn': ZukkoChatL10n.uzLatn,
  'uzCyrl': ZukkoChatL10n.uzCyrl,
  'tr': ZukkoChatL10n.tr,
  'kaa': ZukkoChatL10n.kaa,
};

String _noPlaceholders(String s) => s.replaceAll(RegExp(r'\{\w+\}'), '');

void main() {
  group('forLocale', () {
    test('maps every supported locale', () {
      for (final e in _locales.entries) {
        expect(ZukkoChatL10n.forLocale(e.key), e.value, reason: '${e.key}');
      }
    });

    test('regional variants follow the language, uz script decides', () {
      expect(
        ZukkoChatL10n.forLocale(const Locale('ru', 'RU')),
        ZukkoChatL10n.ru,
      );
      expect(
        ZukkoChatL10n.forLocale(const Locale('tr', 'TR')),
        ZukkoChatL10n.tr,
      );
      expect(
        ZukkoChatL10n.forLocale(const Locale('uz', 'UZ')),
        ZukkoChatL10n.uzLatn,
      );
      expect(
        ZukkoChatL10n.forLocale(
          const Locale.fromSubtags(
            languageCode: 'uz',
            scriptCode: 'Latn',
            countryCode: 'UZ',
          ),
        ),
        ZukkoChatL10n.uzLatn,
      );
      expect(
        ZukkoChatL10n.forLocale(
          const Locale.fromSubtags(
            languageCode: 'uz',
            scriptCode: 'Cyrl',
            countryCode: 'UZ',
          ),
        ),
        ZukkoChatL10n.uzCyrl,
      );
    });

    test('unknown or missing locale is English', () {
      expect(ZukkoChatL10n.forLocale(const Locale('de')), _english);
      expect(ZukkoChatL10n.forLocale(const Locale('kk')), _english);
      expect(ZukkoChatL10n.forLocale(null), _english);
    });
  });

  group('completeness', () {
    test('every field is non-empty in every locale', () {
      for (final e in _locales.entries) {
        final strings = e.value.allStrings;
        expect(strings, isNotEmpty);
        for (var i = 0; i < strings.length; i++) {
          expect(
            strings[i].trim(),
            isNotEmpty,
            reason: 'field #$i of ${e.key}',
          );
        }
      }
    });

    test('every locale has the same placeholders as English', () {
      final base = _english.allStrings;
      for (final e in _translations.entries) {
        final strings = e.value.allStrings;
        for (var i = 0; i < base.length; i++) {
          final p = RegExp(r'\{\w+\}');
          expect(
            p.allMatches(strings[i]).map((m) => m[0]).toSet(),
            p.allMatches(base[i]).map((m) => m[0]).toSet(),
            reason: '${e.key}: "${strings[i]}"',
          );
        }
      }
    });

    test('no script mixing', () {
      final latin = RegExp(r'[A-Za-z]');
      final cyrillic = RegExp(r'[Ѐ-ӿ]');
      // "PDF" is the file format's name in every script (no native form).
      String all(ZukkoChatL10n l) =>
          _noPlaceholders(l.allStrings.join(' ')).replaceAll('PDF', '');
      expect(all(ZukkoChatL10n.ru), isNot(contains(latin)));
      expect(all(ZukkoChatL10n.uzCyrl), isNot(contains(latin)));
      for (final l in [
        _english,
        ZukkoChatL10n.uzLatn,
        ZukkoChatL10n.tr,
        ZukkoChatL10n.kaa,
      ]) {
        expect(all(l), isNot(contains(cyrillic)));
      }
    });

    test('one ellipsis style, no three dots', () {
      for (final e in _locales.entries) {
        expect(e.value.allStrings.join(' '), isNot(contains('...')));
      }
    });

    test('owner-given texts are exact', () {
      expect(
        ZukkoChatL10n.uzLatn.conversationResolvedMessage,
        'Suhbat yopildi. Istalgan vaqtda yana yozishingiz mumkin',
      );
    });

    test('file size units: four per locale, used by formatBytes', () {
      for (final e in _locales.entries) {
        expect(e.value.sizeUnits, hasLength(4), reason: '${e.key}');
      }
      expect(
        formatBytes(12 * 1024 * 1024, ZukkoChatL10n.ru.sizeUnits),
        '12 МБ',
      );
      expect(formatBytes(1536, ZukkoChatL10n.uzCyrl.sizeUnits), '1.5 КБ');
      // a host override with too few units falls back to English
      expect(const ZukkoChatL10n(fileSizeUnits: 'x').sizeUnits, [
        'B',
        'KB',
        'MB',
        'GB',
      ]);
    });
  });

  group('chat UI follows the locale (no English left)', () {
    for (final style in ZukkoChatStyle.values) {
      for (final e in _locales.entries) {
        if (e.value == _english) continue;
        testWidgets('${style.name} / ${e.key}', (tester) async {
          FakeFactory();
          await tester.pumpWidget(
            MaterialApp(
              locale: e.key,
              supportedLocales: [e.key],
              localizationsDelegates: const [
                _FallbackDelegate(),
                DefaultWidgetsLocalizations.delegate,
                _FallbackCupertinoDelegate(),
              ],
              home: ZukkoChat(
                options: ZukkoChatOptions(
                  baseUrl: 'https://x.test',
                  websiteToken: 'in',
                  style: style,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));

          final l = e.value;
          expect(find.text(l.inputPlaceholder), findsOneWidget);
          expect(find.byTooltip(l.attachLabel), findsOneWidget);

          await tester.enterText(find.byType(TextField), 'x');
          await tester.pump();
          expect(find.byTooltip(l.sendLabel), findsOneWidget);

          // none of the English UI strings is on screen
          for (final s in [
            _english.inputPlaceholder,
            _english.headerTitle,
            _english.attachLabel,
            _english.sendLabel,
            _english.noInternetText,
            _english.connectingText,
          ]) {
            expect(find.text(s), findsNothing, reason: s);
            expect(find.byTooltip(s), findsNothing, reason: s);
          }
          expect(
            find.bySemanticsLabel(RegExp('Send|Attach|Support')),
            findsNothing,
          );
        });
      }
    }
  });
}

/// English material strings for any locale (the test app has no
/// flutter_localizations).
class _FallbackDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(_FallbackDelegate old) => false;
}

class _FallbackCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(_FallbackCupertinoDelegate old) => false;
}
