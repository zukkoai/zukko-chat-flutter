import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show Locale;

/// Every user-visible string of the native chat UI.
///
/// Built-in translations: [ZukkoChatL10n.new] (English), [ZukkoChatL10n.ru],
/// [ZukkoChatL10n.uzLatn], [ZukkoChatL10n.uzCyrl], [ZukkoChatL10n.tr] and
/// [ZukkoChatL10n.kaa]. [ZukkoChatL10n.forLocale] picks one for a locale; the
/// chat does that with the ambient locale when `ZukkoChatOptions.l10n` is
/// null.
class ZukkoChatL10n {
  /// Placeholder for the text field
  final String inputPlaceholder;

  /// Title of the chat header when the host does not give one
  final String headerTitle;

  /// Status text when the conversation is online
  final String onlineText;

  /// Status text when the conversation is offline
  final String offlineText;

  /// Status text when the agent is typing
  final String typingText;

  /// Message when agent resolves conversation
  final String conversationResolvedMessage;

  /// Name of the system author of [conversationResolvedMessage]
  final String botName;

  /// Name shown for the user's own messages (styles that show names)
  final String youLabel;

  /// Footer text before the brand link
  final String poweredByText;

  /// Tooltip / semantics label of the back button
  final String backLabel;

  /// Tooltip / semantics label of the header menu button
  final String moreLabel;

  /// Tooltip / semantics label of the send button
  final String sendLabel;

  /// Tooltip / semantics label of the attachment button
  final String attachLabel;

  /// Semantics label of the microphone button
  final String voiceRecordLabel;

  /// Shown while recording: how to cancel
  final String voiceCancelHint;

  /// Shown while recording when releasing would cancel
  final String voiceReleaseToCancel;

  /// Semantics label of a voice message
  final String voiceMessageLabel;

  /// Attachment sheet: pick a photo
  final String attachImageLabel;

  /// Attachment sheet: pick a file
  final String attachFileLabel;

  /// Semantics label of the voice message play button
  final String playLabel;

  /// Semantics label of the voice message pause button
  final String pauseLabel;

  /// Shown when the microphone permission is refused
  final String microphoneDeniedText;

  /// Shown when recording a voice message failed
  final String voiceRecordFailedText;

  /// Shown when a picked file is over the size limit; `{maxMb}` is replaced
  /// by the limit, see [fileTooLarge]
  final String fileTooLargeText;

  /// Shown when the message text is over the server limit; `{maxChars}` is
  /// replaced by the limit, see [messageTooLong]
  final String messageTooLongText;

  /// Shown when more files than the server accepts per message were picked;
  /// `{maxFiles}` is replaced by the limit, see [tooManyFiles]
  final String tooManyFilesText;

  /// Shown when a picked file is of a type the server rejects
  final String fileTypeNotSupportedText;

  /// Text of a message that only has attachments
  final String attachmentLabel;

  /// Semantics label of an image
  final String imageLabel;

  /// Semantics label of image `{i}` of `{n}` (full-screen viewer), see
  /// [imageIndex]
  final String imageIndexLabel;

  /// Screen reader announcement while a voice message is being recorded
  final String voiceRecordingLabel;

  /// Tooltip / semantics label of the full-screen image viewer's close button
  final String closeLabel;

  /// Screen reader hint on a message that failed to send
  final String messageFailedHint;

  /// Screen reader label on a message that is still being sent
  final String messageSendingLabel;

  /// Shown instead of a message of a kind this SDK version cannot display
  final String unsupportedMessageText;

  /// File size units `B, KB, MB, GB`, comma separated, see [sizeUnits]
  final String fileSizeUnits;

  /// Shown when the chat could not be started
  final String connectionErrorText;

  /// Shown when the server rejected the user's identity (identifier hash)
  final String identityRejectedText;

  /// Shown when the chat session could not be kept alive
  final String sessionExpiredText;

  /// Label of the button that tries to start the chat again
  final String retryLabel;

  /// Banner while the device has no connection to the chat server
  final String noInternetText;

  /// Banner while the device is online but the chat is reconnecting
  final String connectingText;

  /// English.
  const ZukkoChatL10n({
    this.inputPlaceholder = 'Type your message',
    this.headerTitle = 'Support',
    this.onlineText = 'Online',
    this.offlineText = "We're away at the moment",
    this.typingText = 'typing…',
    this.conversationResolvedMessage =
        'Conversation closed. You can write again anytime',
    this.botName = 'Bot',
    this.youLabel = 'You',
    this.poweredByText = 'Powered by',
    this.backLabel = 'Back',
    this.moreLabel = 'More options',
    this.sendLabel = 'Send',
    this.attachLabel = 'Attach a file or image',
    this.voiceRecordLabel = 'Hold to record a voice message',
    this.voiceCancelHint = 'Slide to cancel',
    this.voiceReleaseToCancel = 'Release to cancel',
    this.voiceMessageLabel = 'Voice message',
    this.attachImageLabel = 'Photo',
    this.attachFileLabel = 'File',
    this.playLabel = 'Play',
    this.pauseLabel = 'Pause',
    this.microphoneDeniedText =
        'Allow microphone access to send voice messages',
    this.voiceRecordFailedText = 'Could not record the voice message',
    this.fileTooLargeText = 'The file is larger than {maxMb} MB',
    this.messageTooLongText =
        'The message is too long (max {maxChars} characters)',
    this.tooManyFilesText = 'You can send up to {maxFiles} files at once',
    this.fileTypeNotSupportedText = 'This file type is not supported',
    this.attachmentLabel = 'Attachment',
    this.imageLabel = 'Image',
    this.imageIndexLabel = 'Image {i} / {n}',
    this.voiceRecordingLabel = 'Recording voice message',
    this.closeLabel = 'Close',
    this.messageFailedHint = 'Not sent. Tap to retry',
    this.messageSendingLabel = 'Sending',
    this.unsupportedMessageText =
        'This message is not supported. Please update the app',
    this.fileSizeUnits = 'B, KB, MB, GB',
    this.connectionErrorText = 'Could not connect to the chat',
    this.identityRejectedText = 'Your account could not be verified',
    this.sessionExpiredText = 'The chat session has expired',
    this.retryLabel = 'Retry',
    this.noInternetText = 'No internet connection',
    this.connectingText = 'Connecting…',
  });

  /// Russian.
  static const ru = ZukkoChatL10n(
    inputPlaceholder: 'Напишите сообщение',
    headerTitle: 'Поддержка',
    onlineText: 'В сети',
    offlineText: 'Сейчас нас нет на месте',
    typingText: 'печатает…',
    conversationResolvedMessage:
        'Диалог закрыт. Вы можете написать снова в любое время',
    botName: 'Бот',
    youLabel: 'Вы',
    poweredByText: 'Работает на',
    backLabel: 'Назад',
    moreLabel: 'Ещё',
    sendLabel: 'Отправить',
    attachLabel: 'Прикрепить файл или изображение',
    voiceRecordLabel: 'Удерживайте, чтобы записать голосовое сообщение',
    voiceCancelHint: 'Проведите для отмены',
    voiceReleaseToCancel: 'Отпустите для отмены',
    voiceMessageLabel: 'Голосовое сообщение',
    attachImageLabel: 'Фото',
    attachFileLabel: 'Файл',
    playLabel: 'Воспроизвести',
    pauseLabel: 'Пауза',
    microphoneDeniedText:
        'Разрешите доступ к микрофону, чтобы отправлять голосовые сообщения',
    voiceRecordFailedText: 'Не удалось записать голосовое сообщение',
    fileTooLargeText: 'Файл больше {maxMb} МБ',
    messageTooLongText:
        'Сообщение слишком длинное (максимум {maxChars} символов)',
    tooManyFilesText: 'Можно отправить не более {maxFiles} файлов за раз',
    fileTypeNotSupportedText: 'Этот тип файла не поддерживается',
    attachmentLabel: 'Вложение',
    imageLabel: 'Изображение',
    imageIndexLabel: 'Изображение {i} / {n}',
    voiceRecordingLabel: 'Идёт запись голосового сообщения',
    closeLabel: 'Закрыть',
    messageFailedHint: 'Не отправлено. Нажмите, чтобы повторить',
    messageSendingLabel: 'Отправляется',
    unsupportedMessageText:
        'Это сообщение не поддерживается. Обновите приложение',
    fileSizeUnits: 'Б, КБ, МБ, ГБ',
    connectionErrorText: 'Не удалось подключиться к чату',
    identityRejectedText: 'Не удалось подтвердить ваш аккаунт',
    sessionExpiredText: 'Сессия чата истекла',
    retryLabel: 'Повторить',
    noInternetText: 'Нет подключения к интернету',
    connectingText: 'Подключение…',
  );

  /// Uzbek, Latin script.
  static const uzLatn = ZukkoChatL10n(
    inputPlaceholder: 'Xabar yozing',
    headerTitle: 'Yordam',
    onlineText: 'Onlayn',
    offlineText: 'Hozir aloqada emasmiz',
    typingText: 'yozmoqda…',
    conversationResolvedMessage:
        'Suhbat yopildi. Istalgan vaqtda yana yozishingiz mumkin',
    botName: 'Bot',
    youLabel: 'Siz',
    poweredByText: 'Taqdim etuvchi',
    backLabel: 'Orqaga',
    moreLabel: 'Boshqa amallar',
    sendLabel: 'Yuborish',
    attachLabel: 'Fayl yoki rasm biriktirish',
    voiceRecordLabel: 'Ovozli xabar yozish uchun bosib turing',
    voiceCancelHint: 'Bekor qilish uchun suring',
    voiceReleaseToCancel: 'Bekor qilish uchun qoʻyib yuboring',
    voiceMessageLabel: 'Ovozli xabar',
    attachImageLabel: 'Rasm',
    attachFileLabel: 'Fayl',
    playLabel: 'Tinglash',
    pauseLabel: 'Pauza',
    microphoneDeniedText:
        'Ovozli xabar yuborish uchun mikrofonga ruxsat bering',
    voiceRecordFailedText: 'Ovozli xabarni yozib boʻlmadi',
    fileTooLargeText: 'Fayl hajmi {maxMb} MB dan katta',
    messageTooLongText: 'Xabar juda uzun (eng koʻpi bilan {maxChars} belgi)',
    tooManyFilesText:
        'Bir vaqtda koʻpi bilan {maxFiles} ta fayl yuborish mumkin',
    fileTypeNotSupportedText: 'Bu fayl turi qoʻllab-quvvatlanmaydi',
    attachmentLabel: 'Biriktirma',
    imageLabel: 'Rasm',
    imageIndexLabel: 'Rasm {i} / {n}',
    voiceRecordingLabel: 'Ovozli xabar yozilmoqda',
    closeLabel: 'Yopish',
    messageFailedHint: 'Yuborilmadi. Qayta yuborish uchun bosing',
    messageSendingLabel: 'Yuborilmoqda',
    unsupportedMessageText:
        'Bu xabar qoʻllab-quvvatlanmaydi. Ilovani yangilang',
    fileSizeUnits: 'B, KB, MB, GB',
    connectionErrorText: 'Chatga ulanib boʻlmadi',
    identityRejectedText: 'Hisobingizni tasdiqlab boʻlmadi',
    sessionExpiredText: 'Chat seansi muddati tugadi',
    retryLabel: 'Qayta urinish',
    noInternetText: 'Internet aloqasi yoʻq',
    connectingText: 'Ulanmoqda…',
  );

  /// Uzbek, Cyrillic script.
  static const uzCyrl = ZukkoChatL10n(
    inputPlaceholder: 'Хабар ёзинг',
    headerTitle: 'Ёрдам',
    onlineText: 'Онлайн',
    offlineText: 'Ҳозир алоқада эмасмиз',
    typingText: 'ёзмоқда…',
    conversationResolvedMessage:
        'Суҳбат ёпилди. Исталган вақтда яна ёзишингиз мумкин',
    botName: 'Бот',
    youLabel: 'Сиз',
    poweredByText: 'Тақдим этувчи',
    backLabel: 'Орқага',
    moreLabel: 'Бошқа амаллар',
    sendLabel: 'Юбориш',
    attachLabel: 'Файл ёки расм бириктириш',
    voiceRecordLabel: 'Овозли хабар ёзиш учун босиб туринг',
    voiceCancelHint: 'Бекор қилиш учун суринг',
    voiceReleaseToCancel: 'Бекор қилиш учун қўйиб юборинг',
    voiceMessageLabel: 'Овозли хабар',
    attachImageLabel: 'Расм',
    attachFileLabel: 'Файл',
    playLabel: 'Тинглаш',
    pauseLabel: 'Пауза',
    microphoneDeniedText: 'Овозли хабар юбориш учун микрофонга рухсат беринг',
    voiceRecordFailedText: 'Овозли хабарни ёзиб бўлмади',
    fileTooLargeText: 'Файл ҳажми {maxMb} МБ дан катта',
    messageTooLongText: 'Хабар жуда узун (энг кўпи билан {maxChars} белги)',
    tooManyFilesText: 'Бир вақтда кўпи билан {maxFiles} та файл юбориш мумкин',
    fileTypeNotSupportedText: 'Бу файл тури қўллаб-қувватланмайди',
    attachmentLabel: 'Бириктирма',
    imageLabel: 'Расм',
    imageIndexLabel: 'Расм {i} / {n}',
    voiceRecordingLabel: 'Овозли хабар ёзилмоқда',
    closeLabel: 'Ёпиш',
    messageFailedHint: 'Юборилмади. Қайта юбориш учун босинг',
    messageSendingLabel: 'Юборилмоқда',
    unsupportedMessageText: 'Бу хабар қўллаб-қувватланмайди. Иловани янгиланг',
    fileSizeUnits: 'Б, КБ, МБ, ГБ',
    connectionErrorText: 'Чатга уланиб бўлмади',
    identityRejectedText: 'Ҳисобингизни тасдиқлаб бўлмади',
    sessionExpiredText: 'Чат сеанси муддати тугади',
    retryLabel: 'Қайта уриниш',
    noInternetText: 'Интернет алоқаси йўқ',
    connectingText: 'Уланмоқда…',
  );

  /// Turkish.
  static const tr = ZukkoChatL10n(
    inputPlaceholder: 'Mesajınızı yazın',
    headerTitle: 'Destek',
    onlineText: 'Çevrimiçi',
    offlineText: 'Şu anda müsait değiliz',
    typingText: 'yazıyor…',
    conversationResolvedMessage:
        'Sohbet kapatıldı. İstediğiniz zaman yeniden yazabilirsiniz',
    botName: 'Bot',
    youLabel: 'Siz',
    poweredByText: 'Sağlayan',
    backLabel: 'Geri',
    moreLabel: 'Diğer seçenekler',
    sendLabel: 'Gönder',
    attachLabel: 'Dosya veya görsel ekle',
    voiceRecordLabel: 'Sesli mesaj kaydetmek için basılı tutun',
    voiceCancelHint: 'İptal için kaydırın',
    voiceReleaseToCancel: 'İptal için bırakın',
    voiceMessageLabel: 'Sesli mesaj',
    attachImageLabel: 'Fotoğraf',
    attachFileLabel: 'Dosya',
    playLabel: 'Oynat',
    pauseLabel: 'Duraklat',
    microphoneDeniedText: 'Sesli mesaj göndermek için mikrofon izni verin',
    voiceRecordFailedText: 'Sesli mesaj kaydedilemedi',
    fileTooLargeText: "Dosya {maxMb} MB'tan büyük",
    messageTooLongText: 'Mesaj çok uzun (en fazla {maxChars} karakter)',
    tooManyFilesText: 'Tek seferde en fazla {maxFiles} dosya gönderebilirsiniz',
    fileTypeNotSupportedText: 'Bu dosya türü desteklenmiyor',
    attachmentLabel: 'Ek',
    imageLabel: 'Görsel',
    imageIndexLabel: 'Görsel {i} / {n}',
    voiceRecordingLabel: 'Sesli mesaj kaydediliyor',
    closeLabel: 'Kapat',
    messageFailedHint: 'Gönderilemedi. Tekrar denemek için dokunun',
    messageSendingLabel: 'Gönderiliyor',
    unsupportedMessageText:
        'Bu mesaj desteklenmiyor. Lütfen uygulamayı güncelleyin',
    fileSizeUnits: 'B, KB, MB, GB',
    connectionErrorText: 'Sohbete bağlanılamadı',
    identityRejectedText: 'Hesabınız doğrulanamadı',
    sessionExpiredText: 'Sohbet oturumunun süresi doldu',
    retryLabel: 'Tekrar dene',
    noInternetText: 'İnternet bağlantısı yok',
    connectingText: 'Bağlanıyor…',
  );

  /// Karakalpak, Latin script.
  static const kaa = ZukkoChatL10n(
    inputPlaceholder: 'Xabar jazıń',
    headerTitle: 'Járdem',
    onlineText: 'Onlayn',
    offlineText: 'Házir baylanısta emespiz',
    typingText: 'jazıp atır…',
    conversationResolvedMessage:
        'Sáwbet jabıldı. Qálegen waqıtta qayta jaza alasız',
    botName: 'Bot',
    youLabel: 'Siz',
    poweredByText: 'Usınıwshı',
    backLabel: 'Artqa',
    moreLabel: 'Basqa ámeller',
    sendLabel: 'Jiberiw',
    attachLabel: 'Fayl yamasa súwret biriktiriw',
    voiceRecordLabel: 'Dawıslı xabar jazıw ushın basıp turıń',
    voiceCancelHint: 'Biykar etiw ushın súyreń',
    voiceReleaseToCancel: 'Biykar etiw ushın qoyıp jiberiń',
    voiceMessageLabel: 'Dawıslı xabar',
    attachImageLabel: 'Súwret',
    attachFileLabel: 'Fayl',
    playLabel: 'Tıńlaw',
    pauseLabel: 'Pauza',
    microphoneDeniedText: 'Dawıslı xabar jiberiw ushın mikrofonǵa ruqsat beriń',
    voiceRecordFailedText: 'Dawıslı xabardı jazıp bolmadı',
    fileTooLargeText: 'Fayl kólemi {maxMb} MB dan úlken',
    messageTooLongText: 'Xabar júdá uzın (eń kóbi menen {maxChars} belgi)',
    tooManyFilesText:
        'Bir waqıtta eń kóbi menen {maxFiles} fayl jiberiw múmkin',
    fileTypeNotSupportedText: 'Bul fayl túri qollap-quwatlanbaydı',
    attachmentLabel: 'Biriktirme',
    imageLabel: 'Súwret',
    imageIndexLabel: 'Súwret {i} / {n}',
    voiceRecordingLabel: 'Dawıslı xabar jazılmaqta',
    closeLabel: 'Jabıw',
    messageFailedHint: 'Jiberilmedi. Qayta jiberiw ushın basıń',
    messageSendingLabel: 'Jiberilmekte',
    unsupportedMessageText:
        'Bul xabar qollap-quwatlanbaydı. Qosımshanı jańalań',
    fileSizeUnits: 'B, KB, MB, GB',
    connectionErrorText: 'Chatqa jalǵanıw múmkin bolmadı',
    identityRejectedText: 'Akkauntıńızdı tastıyıqlaw múmkin bolmadı',
    sessionExpiredText: 'Chat seansınıń waqtı pitti',
    retryLabel: 'Qayta urınıw',
    noInternetText: 'Internet baylanısı joq',
    connectingText: 'Jalǵanıp atır…',
  );

  /// The built-in translation for [locale]; English when there is none.
  /// Uzbek is Latin unless the locale asks for Cyrillic (`uz_Cyrl`).
  static ZukkoChatL10n forLocale(Locale? locale) =>
      switch (locale?.languageCode) {
        'ru' => ru,
        'tr' => tr,
        'kaa' => kaa,
        'uz' when locale?.scriptCode == 'Cyrl' => uzCyrl,
        'uz' => uzLatn,
        _ => const ZukkoChatL10n(),
      };

  /// [fileTooLargeText] for a limit of [maxMb] megabytes.
  String fileTooLarge(int maxMb) =>
      fileTooLargeText.replaceAll('{maxMb}', '$maxMb');

  /// [messageTooLongText] for a limit of [maxChars] characters.
  String messageTooLong(int maxChars) =>
      messageTooLongText.replaceAll('{maxChars}', '$maxChars');

  /// [tooManyFilesText] for a limit of [maxFiles] files.
  String tooManyFiles(int maxFiles) =>
      tooManyFilesText.replaceAll('{maxFiles}', '$maxFiles');

  /// [imageIndexLabel] for image [i] (1-based) of [n].
  String imageIndex(int i, int n) =>
      imageIndexLabel.replaceAll('{i}', '$i').replaceAll('{n}', '$n');

  /// [fileSizeUnits] as a list; English units when the host gave fewer than 4.
  List<String> get sizeUnits {
    final u = fileSizeUnits.split(',').map((e) => e.trim()).toList();
    return u.length >= 4 ? u : const ['B', 'KB', 'MB', 'GB'];
  }

  /// Every string, for the translation completeness test.
  @visibleForTesting
  List<String> get allStrings => _fields;

  List<String> get _fields => [
    inputPlaceholder,
    headerTitle,
    onlineText,
    offlineText,
    typingText,
    conversationResolvedMessage,
    botName,
    youLabel,
    poweredByText,
    backLabel,
    moreLabel,
    sendLabel,
    attachLabel,
    voiceRecordLabel,
    voiceCancelHint,
    voiceReleaseToCancel,
    voiceMessageLabel,
    attachImageLabel,
    attachFileLabel,
    playLabel,
    pauseLabel,
    microphoneDeniedText,
    voiceRecordFailedText,
    fileTooLargeText,
    messageTooLongText,
    tooManyFilesText,
    fileTypeNotSupportedText,
    attachmentLabel,
    imageLabel,
    imageIndexLabel,
    voiceRecordingLabel,
    closeLabel,
    messageFailedHint,
    messageSendingLabel,
    unsupportedMessageText,
    fileSizeUnits,
    connectionErrorText,
    identityRejectedText,
    sessionExpiredText,
    retryLabel,
    noInternetText,
    connectingText,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ZukkoChatL10n) return false;
    final a = _fields;
    final b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);
}
