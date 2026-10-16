import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

void main() {
  const english = ZukkoChatL10n();
  final translations = {
    'ru': ZukkoChatL10n.ru,
    'uzLatn': ZukkoChatL10n.uzLatn,
    'uzCyrl': ZukkoChatL10n.uzCyrl,
    'tr': ZukkoChatL10n.tr,
    'kaa': ZukkoChatL10n.kaa,
  };
  // the same word in these languages
  const sameAsEnglish = {'botName', 'Bot', 'B, KB, MB, GB'};

  test('every language translates every string', () {
    final base = english.allStrings;
    for (final entry in translations.entries) {
      final strings = entry.value.allStrings;
      for (var i = 0; i < base.length; i++) {
        if (sameAsEnglish.contains(base[i])) continue;
        expect(
          strings[i],
          isNot(base[i]),
          reason: '${entry.key} still has the English "${base[i]}"',
        );
      }
    }
  });

  test('placeholders survive in every language', () {
    for (final l in [english, ...translations.values]) {
      expect(l.fileTooLargeText, contains('{maxMb}'));
      expect(l.imageIndexLabel, allOf(contains('{i}'), contains('{n}')));
    }
  });

  test('the size limit text follows the upload limit', () {
    expect(
      english.fileTooLarge(ZukkoChatUpload.maxSizeMb),
      'The file is larger than ${ZukkoChatUpload.maxSizeMb} MB',
    );
    expect(ZukkoChatL10n.ru.fileTooLarge(7), 'Файл больше 7 МБ');
  });

  test('imageIndex fills the numbers', () {
    expect(english.imageIndex(2, 5), 'Image 2 / 5');
    expect(ZukkoChatL10n.tr.imageIndex(1, 3), 'Görsel 1 / 3');
  });

  test(
    'Uzbek Latin uses the modifier letter okina, Cyrillic its own letters',
    () {
      final latin = ZukkoChatL10n.uzLatn.allStrings.join();
      expect(latin, contains('ʻ'));
      expect(latin, isNot(contains("'")));
      expect(latin, isNot(contains('‘')));
      expect(ZukkoChatL10n.uzCyrl.allStrings.join(), contains('ў'));
    },
  );
}
