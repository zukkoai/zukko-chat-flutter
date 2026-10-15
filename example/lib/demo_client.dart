import 'dart:async';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';

/// Offline stand-in for [ChatwootClient], so the chat styles can be checked
/// without a server: it loads a fixed conversation (text, link, images,
/// file, voice) and answers every sent message after a short "typing".
class DemoChatwootClient implements ChatwootClient {
  DemoChatwootClient(this._callbacks);

  /// Same signature as [ChatwootClient.create].
  static Future<ChatwootClient> create({
    required String baseUrl,
    required String websiteToken,
    ChatwootUser? user,
    bool enablePersistence = true,
    bool allowInsecure = false,
    ChatwootCallbacks? callbacks,
  }) async => DemoChatwootClient(callbacks);

  final ChatwootCallbacks? _callbacks;
  final _timers = <Timer>[];
  var _nextId = 100;
  var _disposed = false;

  static const _agent = ChatwootEventMessageUser(id: 1, name: 'Zukko AI');

  @override
  Future<void> loadMessages() async {
    _callbacks?.onMessagesRetrieved?.call(_conversation());
    _callbacks?.onConversationIsOnline?.call();
  }

  @override
  Future<void> sendMessage({
    required String content,
    required String echoId,
    List<ChatwootUpload> attachments = const [],
    int? replyTo,
  }) async {
    // Stands in for the server's stored copies of the uploaded files.
    final sent = _message(
      _nextId++,
      content: content.isEmpty ? null : content,
      mine: true,
      attachments: [for (final a in attachments) _hosted(a)],
    );
    _after(400, () => _callbacks?.onMessageSent?.call(sent, echoId));
    _after(900, () => _callbacks?.onConversationStartedTyping?.call());
    _after(2600, () {
      _callbacks?.onConversationStoppedTyping?.call();
      _callbacks?.onMessageReceived?.call(
        _message(
          _nextId++,
          content: content.isEmpty
              ? 'Faylingizni oldim, rahmat.'
              : 'Qabul qildim: "$content". Tez orada javob beraman.',
        ),
      );
    });
  }

  @override
  Future<void> markSeen() async {}

  @override
  Future<void> setTyping(bool on) async {}

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
  }

  // Members the chat UI never calls.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void _after(int ms, void Function() action) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (!_disposed) action();
    }),
  );

  static const _sampleAudio =
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

  Map<String, dynamic> _hosted(ChatwootUpload file) => {
    'file_type': file.isImage
        ? 'image'
        : file.isAudio
        ? 'audio'
        : 'file',
    'data_url': file.isImage
        ? 'https://picsum.photos/seed/${file.name.hashCode}/600/450'
        : file.isAudio
        ? _sampleAudio
        : 'https://example.com/files/${Uri.encodeComponent(file.name)}',
    'file_size': file.size,
  };

  List<ChatwootMessage> _conversation() {
    Map<String, dynamic> image(String seed) => {
      'file_type': 'image',
      'data_url': 'https://picsum.photos/seed/$seed/600/450',
      'file_size': 120000,
    };
    var id = 1;
    return [
      _message(
        id++,
        minutesAgo: 30,
        content:
            'Assalomu alaykum! Men AI yordamchiman. Buyurtma, toʻlov yoki '
            'yetkazib berish haqida soʻrashingiz mumkin.',
      ),
      _message(
        id++,
        minutesAgo: 28,
        mine: true,
        content: 'Shu mahsulotni olgandim: https://zukko.ai',
      ),
      _message(
        id++,
        minutesAgo: 27,
        content: 'Koʻrdim. Mahsulotda qanday muammo bor?',
      ),
      _message(
        id++,
        minutesAgo: 25,
        mine: true,
        content: 'Qadoq yirtilgan holda keldi.',
        attachments: [
          for (final seed in ['box1', 'box2', 'box3', 'box4', 'box5'])
            image(seed),
        ],
      ),
      _message(
        id++,
        minutesAgo: 24,
        content: 'Shu rasmdagi kabi qadoqmi?',
        attachments: [image('package')],
      ),
      _message(id++, minutesAgo: 23, mine: true, content: 'Ha, xuddi shunday.'),
      _message(
        id++,
        minutesAgo: 22,
        content: null,
        attachments: [
          {
            'file_type': 'file',
            'data_url': 'https://example.com/files/ariza-4821.pdf',
            'file_size': 184320,
          },
        ],
      ),
      _message(
        id++,
        minutesAgo: 20,
        mine: true,
        content: null,
        attachments: [
          {'file_type': 'audio', 'data_url': _sampleAudio, 'file_size': 40960},
        ],
      ),
      _message(
        id++,
        minutesAgo: 19,
        content:
            'Uzr soʻraymiz. Almashtirish uchun ariza ochdim — kuryer ertaga '
            '10:00–13:00 oraligʻida olib ketadi.',
      ),
    ];
  }

  ChatwootMessage _message(
    int id, {
    required String? content,
    bool mine = false,
    int minutesAgo = 0,
    List<dynamic>? attachments,
  }) => ChatwootMessage(
    id: id,
    content: content,
    messageType: mine ? 0 : 1,
    contentType: 'text',
    contentAttributes: null,
    createdAt: DateTime.now()
        .toUtc()
        .subtract(Duration(minutes: minutesAgo))
        .toIso8601String(),
    conversationId: 1,
    attachments: attachments,
    sender: mine ? null : _agent,
  );
}
