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

  /// Footer text before the brand link, see `ZukkoChatOptions.showBranding`
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

  /// Shown when a picked file is over the size limit
  final String fileTooLargeText;

  /// Text of a message that only has attachments
  final String attachmentLabel;

  /// Semantics label of an image
  final String imageLabel;

  /// Tooltip / semantics label of the full-screen image viewer's close button
  final String closeLabel;

  /// Screen reader hint on a message that failed to send
  final String messageFailedHint;

  /// Shown when the chat could not be started
  final String connectionErrorText;

  /// Shown when the server rejected the user's identity (identifier hash)
  final String identityRejectedText;

  /// Shown when the chat session could not be kept alive
  final String sessionExpiredText;

  /// Label of the button that tries to start the chat again
  final String retryLabel;

  /// English.
  const ZukkoChatL10n({
    this.inputPlaceholder = 'Type your message',
    this.headerTitle = 'Support',
    this.onlineText = 'Online',
    this.offlineText = "We're away at the moment",
    this.typingText = 'typing...',
    this.conversationResolvedMessage =
        'Your ticket has been marked as resolved',
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
    this.fileTooLargeText = 'The file is larger than 40 MB',
    this.attachmentLabel = 'Attachment',
    this.imageLabel = 'Image',
    this.closeLabel = 'Close',
    this.messageFailedHint = 'Failed to send. Tap to retry',
    this.connectionErrorText = 'Could not connect to the chat',
    this.identityRejectedText = 'Your account could not be verified',
    this.sessionExpiredText = 'The chat session has expired',
    this.retryLabel = 'Retry',
  });

  /// Russian.
  static const ru = ZukkoChatL10n(
    inputPlaceholder: 'Напишите сообщение',
    headerTitle: 'Поддержка',
    onlineText: 'В сети',
    offlineText: 'Сейчас нас нет на месте',
    typingText: 'печатает...',
    conversationResolvedMessage: 'Ваше обращение отмечено как решённое',
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
    fileTooLargeText: 'Файл больше 40 МБ',
    attachmentLabel: 'Вложение',
    imageLabel: 'Изображение',
    closeLabel: 'Закрыть',
    messageFailedHint: 'Не отправлено. Нажмите, чтобы повторить',
    connectionErrorText: 'Не удалось подключиться к чату',
    identityRejectedText: 'Не удалось подтвердить ваш аккаунт',
    sessionExpiredText: 'Сессия чата истекла',
    retryLabel: 'Повторить',
  );

  /// Uzbek, Latin script.
  static const uzLatn = ZukkoChatL10n(
    inputPlaceholder: 'Xabar yozing',
    headerTitle: 'Yordam',
    onlineText: 'Onlayn',
    offlineText: 'Hozir aloqada emasmiz',
    typingText: 'yozmoqda...',
    conversationResolvedMessage: 'Murojaatingiz hal qilingan deb belgilandi',
    botName: 'Bot',
    youLabel: 'Siz',
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
    fileTooLargeText: 'Fayl hajmi 40 MB dan katta',
    attachmentLabel: 'Biriktirma',
    imageLabel: 'Rasm',
    closeLabel: 'Yopish',
    messageFailedHint: 'Yuborilmadi. Qayta yuborish uchun bosing',
    connectionErrorText: 'Chatga ulanib boʻlmadi',
    identityRejectedText: 'Hisobingizni tasdiqlab boʻlmadi',
    sessionExpiredText: 'Chat seansi muddati tugadi',
    retryLabel: 'Qayta urinish',
  );

  /// Uzbek, Cyrillic script.
  static const uzCyrl = ZukkoChatL10n(
    inputPlaceholder: 'Хабар ёзинг',
    headerTitle: 'Ёрдам',
    onlineText: 'Онлайн',
    offlineText: 'Ҳозир алоқада эмасмиз',
    typingText: 'ёзмоқда...',
    conversationResolvedMessage: 'Мурожаатингиз ҳал қилинган деб белгиланди',
    botName: 'Бот',
    youLabel: 'Сиз',
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
    fileTooLargeText: 'Файл ҳажми 40 MB дан катта',
    attachmentLabel: 'Бириктирма',
    imageLabel: 'Расм',
    closeLabel: 'Ёпиш',
    messageFailedHint: 'Юборилмади. Қайта юбориш учун босинг',
    connectionErrorText: 'Чатга уланиб бўлмади',
    identityRejectedText: 'Ҳисобингизни тасдиқлаб бўлмади',
    sessionExpiredText: 'Чат сеанси муддати тугади',
    retryLabel: 'Қайта уриниш',
  );

  /// Turkish.
  static const tr = ZukkoChatL10n(
    inputPlaceholder: 'Mesajınızı yazın',
    headerTitle: 'Destek',
    onlineText: 'Çevrimiçi',
    offlineText: 'Şu anda müsait değiliz',
    typingText: 'yazıyor...',
    conversationResolvedMessage: 'Talebiniz çözüldü olarak işaretlendi',
    botName: 'Bot',
    youLabel: 'Siz',
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
    fileTooLargeText: "Dosya 40 MB'tan büyük",
    attachmentLabel: 'Ek',
    imageLabel: 'Görsel',
    closeLabel: 'Kapat',
    messageFailedHint: 'Gönderilemedi. Tekrar denemek için dokunun',
    connectionErrorText: 'Sohbete bağlanılamadı',
    identityRejectedText: 'Hesabınız doğrulanamadı',
    sessionExpiredText: 'Sohbet oturumunun süresi doldu',
    retryLabel: 'Tekrar dene',
  );

  /// Karakalpak, Latin script.
  static const kaa = ZukkoChatL10n(
    inputPlaceholder: 'Xabar jazıń',
    headerTitle: 'Járdem',
    onlineText: 'Onlayn',
    offlineText: 'Házir baylanısta emespiz',
    typingText: 'jazıp atır...',
    conversationResolvedMessage: 'Múrájatıńız sheshildi dep belgilendi',
    botName: 'Bot',
    youLabel: 'Siz',
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
    fileTooLargeText: 'Fayl kólemi 40 MB dan úlken',
    attachmentLabel: 'Biriktirme',
    imageLabel: 'Súwret',
    closeLabel: 'Jabıw',
    messageFailedHint: 'Jiberilmedi. Qayta jiberiw ushın basıń',
    connectionErrorText: 'Chatqa jalǵanıw múmkin bolmadı',
    identityRejectedText: 'Akkauntıńızdı tastıyıqlaw múmkin bolmadı',
    sessionExpiredText: 'Chat seansınıń waqtı pitti',
    retryLabel: 'Qayta urınıw',
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
    attachmentLabel,
    imageLabel,
    closeLabel,
    messageFailedHint,
    connectionErrorText,
    identityRejectedText,
    sessionExpiredText,
    retryLabel,
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
