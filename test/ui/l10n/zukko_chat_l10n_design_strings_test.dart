import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload.dart';
import 'package:zukko_chat_flutter/src/ui/l10n/zukko_chat_l10n.dart';

final _all = {
  'en': const ZukkoChatL10n(),
  'ru': ZukkoChatL10n.ru,
  'uzLatn': ZukkoChatL10n.uzLatn,
  'uzCyrl': ZukkoChatL10n.uzCyrl,
  'tr': ZukkoChatL10n.tr,
  'kaa': ZukkoChatL10n.kaa,
};

void main() {
  test('attachment sheet and recording strings exist in every locale', () {
    for (final e in _all.entries) {
      final l = e.value;
      final strings = {
        'attachSheetTitle': l.attachSheetTitle,
        'attachSheetTitleWithLimitText': l.attachSheetTitleWithLimitText,
        'attachImageHint': l.attachImageHint,
        'attachImageHintLong': l.attachImageHintLong,
        'attachImageHintShort': l.attachImageHintShort,
        'attachFileHint': l.attachFileHint,
        'attachFileHintShort': l.attachFileHintShort,
        'attachLimitNoteText': l.attachLimitNoteText,
        'cancelLabel': l.cancelLabel,
        'voiceSlideLeftToCancel': l.voiceSlideLeftToCancel,
        'voiceRecordingButtonLabel': l.voiceRecordingButtonLabel,
      };
      strings.forEach((k, v) {
        expect(v.trim(), isNotEmpty, reason: '${e.key}.$k');
      });
      expect(
        l.attachSheetTitleWithLimitText,
        contains('{maxMb}'),
        reason: e.key,
      );
      expect(l.attachLimitNoteText, contains('{maxMb}'), reason: e.key);
      expect(
        l.attachLimitNote(ZukkoChatUpload.maxSizeMb),
        contains('${ZukkoChatUpload.maxSizeMb}'),
        reason: e.key,
      );
    }
  });

  test('Uzbek Latin matches the design', () {
    const l = ZukkoChatL10n.uzLatn;
    expect(
      l.attachSheetTitleWithLimit(40),
      'Biriktirish · har bir fayl 40 MB gacha',
    );
    expect(l.attachLimitNote(40), 'Har bir fayl 40 MB gacha');
    expect(l.cancelLabel, 'Bekor qilish');
    expect(l.voiceSlideLeftToCancel, 'Bekor qilish uchun chapga suring');
    expect(l.voiceCancelHint, 'Bekor qilish uchun suring');
    expect(l.voiceRecordingButtonLabel, 'Ovoz yozilmoqda');
  });
}
