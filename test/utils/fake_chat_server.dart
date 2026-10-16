import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload.dart';

/// One request the [FakeChatServer] received.
class ServerCall {
  ServerCall(
    this.method,
    this.path,
    this.query,
    this.headers,
    this.body, [
    this.parts = const [],
  ]);

  final String method;
  final String path;
  final Map<String, String> query;

  /// Header names are lower case.
  final Map<String, String> headers;

  /// Decoded JSON, or the raw text for anything else.
  final Object? body;

  /// The parts of a `multipart/form-data` body, in order.
  final List<FormPart> parts;

  String get jwt => headers['x-auth-token'] ?? '';
  @override
  String toString() => '$method $path';
}

/// One part of a multipart body.
class FormPart {
  FormPart(this.name, this.filename, this.contentType, this.bytes);

  final String name;
  final String? filename;
  final String? contentType;
  final List<int> bytes;

  String get text => utf8.decode(bytes, allowMalformed: true);
}

/// A tiny real HTTP server speaking the Zukko Widget API, with the server's
/// auth rules: `/config` mints (or recognises) a contact by its JWT, every
/// other route answers 404 for an unknown website token or JWT.
///
/// The contact has no pubsub token by default, so clients never open a
/// websocket; set [pubsubToken] and `/cable` speaks ActionCable.
class FakeChatServer {
  FakeChatServer._(this._server) {
    _server.listen(_handle);
  }

  static const websiteToken = 'site-token';

  final HttpServer _server;

  /// Every request received, in order.
  final calls = <ServerCall>[];

  /// `METHOD path` of every request received.
  List<String> get requests => [for (final c in calls) c.toString()];

  /// Answer every request with this status instead (e.g. 500).
  int? forceStatus;

  /// The inbox's HMAC secret and `hmac_mandatory` setting
  /// (widget/contacts_controller.rb:46-61): `set_user` checks
  /// `identifier_hash` when given, or always when mandatory.
  static const hmacToken = 'hmac-secret';
  bool hmacMandatory = false;

  /// The `identifier_hash` the server accepts for [identifier].
  static String hashFor(String identifier) => Hmac(
    sha256,
    utf8.encode(hmacToken),
  ).convert(utf8.encode(identifier)).toString();

  /// When set, `set_user` answers this status (e.g. 500) instead.
  int? setUserStatus;

  /// `set_user` merges the JWT's contact into a new one without handing out a
  /// new JWT: `GET /contact` and `/config` then name the new contact.
  bool mergeOnSetUser = false;
  final _mergedInto = <int, int>{};

  /// What `/config` hands out as `contact.pubsub_token`.
  String? pubsubToken;

  /// Whether the (single) conversation exists yet; `POST /messages` creates it.
  bool hasConversation = false;

  /// The id `POST /messages` answers with; with [createdJoinsList] it is
  /// also added to [messageIds] (the server now has that message).
  int createdId = 100;
  bool createdJoinsList = false;

  /// Open `/cable` websockets (an ActionCable peer: welcome, a `ping` every
  /// [pingEvery], confirms a subscription only for the current [pubsubToken],
  /// answers `update_presence` with a `presence.update` broadcast) and the
  /// subscribe frames seen. [subscriptions] maps the sockets that were
  /// confirmed to their identifier.
  final sockets = <WebSocket>[];
  final subscribeIdentifiers = <String>[];
  final subscriptions = <WebSocket, String>{};
  Duration pingEvery = const Duration(seconds: 3);

  /// When set, `/cable` only knows this token (not [pubsubToken]): a client
  /// handed a dead token gets no confirm.
  String? cableToken;
  int presenceUpdates = 0;
  int pingsSent = 0;

  /// The messages `GET /messages` serves (ascending), minus the ids in
  /// [privateIds] and [activityIds], which the server filters out.
  var messageIds = <int>[1, 2];
  final privateIds = <int>{};
  final activityIds = <int>{};

  /// `typing_status` values of accepted `toggle_typing` calls.
  final typing = <String>[];

  /// Contact id -> identifier. A JWT is `jwt-<id>` and is valid while its
  /// contact is here.
  final contacts = <int, String?>{};
  var _nextContactId = 1;

  /// Registers a contact on the server and returns its id (its JWT is
  /// `jwt-<id>`).
  int addContact([String? identifier]) => _newContact(identifier);

  /// Forget every contact and restart the ids at 1.
  void reset() {
    contacts.clear();
    _mergedInto.clear();
    _nextContactId = 1;
  }

  /// Forget every contact, like a server that no longer knows our JWTs.
  void forgetContacts() => contacts.clear();

  static Future<FakeChatServer> start() async =>
      FakeChatServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  int count(String method, bool Function(String path) where) =>
      calls.where((c) => c.method == method && where(c.path)).length;

  /// Calls to `path` (suffix match), in order.
  List<ServerCall> to(String suffix) =>
      calls.where((c) => c.path.endsWith(suffix)).toList();

  Future<void> close() async {
    for (final s in sockets) {
      await s.close();
    }
    await _server.close(force: true);
  }

  /// Pushes an ActionCable broadcast to every subscribed socket, under the
  /// identifier it subscribed with.
  void broadcast(String event, Map<String, Object?> data) {
    subscriptions.forEach((socket, identifier) {
      socket.add(
        jsonEncode({
          'identifier': identifier,
          'message': {'event': event, 'data': data},
        }),
      );
    });
  }

  // app/channels/room_channel.rb:2-13: `subscribed` looks the contact up by
  // pubsub_token (find_by! raises: no confirm, no reject frame, just silence)
  // and broadcasts presence; `update_presence` broadcasts it again.
  Future<void> _cable(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    sockets.add(socket);
    socket.add(jsonEncode({'type': 'welcome'}));
    // ActionCable pings every 3 s: {"type":"ping","message":<epoch seconds>}
    final pinger = Timer.periodic(pingEvery, (_) {
      pingsSent++;
      socket.add(
        jsonEncode({
          'type': 'ping',
          'message': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        }),
      );
    });
    void presence() {
      presenceUpdates++;
      broadcast('presence.update', {
        'account_id': 1,
        'users': <String, Object?>{},
      });
    }

    socket.listen(
      (frame) {
        final decoded = jsonDecode(frame as String) as Map;
        final identifier = decoded['identifier'] as String?;
        if (decoded['command'] == 'subscribe' && identifier != null) {
          subscribeIdentifiers.add(identifier);
          final token = (jsonDecode(identifier) as Map)['pubsub_token'];
          if (token == null || token != (cableToken ?? pubsubToken)) return;
          subscriptions[socket] = identifier;
          socket.add(
            jsonEncode({
              'type': 'confirm_subscription',
              'identifier': identifier,
            }),
          );
          presence();
        } else if (decoded['command'] == 'message' &&
            subscriptions.containsKey(socket) &&
            jsonDecode(decoded['data'] as String)['action'] ==
                'update_presence') {
          presence();
        }
      },
      onDone: () {
        pinger.cancel();
        subscriptions.remove(socket);
        sockets.remove(socket);
      },
    );
  }

  int _newContact(String? identifier) {
    final id = _nextContactId++;
    contacts[id] = identifier;
    return id;
  }

  int? _contactOf(String jwt) {
    if (!jwt.startsWith('jwt-')) return null;
    final id = int.tryParse(jwt.substring(4));
    return id != null && contacts.containsKey(id) ? id : null;
  }

  Map<String, Object?> _contactJson(int id) => {
    'id': id,
    'identifier': contacts[id],
    'name': 'name $id',
    'email': null,
    'phone_number': null,
    'pubsub_token': pubsubToken,
  };

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path == '/cable') return _cable(request);
    final bytes = await request.fold<List<int>>([], (all, c) => all..addAll(c));
    final raw = utf8.decode(bytes, allowMalformed: true);
    Object? body = raw;
    var parts = <FormPart>[];
    final type = request.headers.contentType;
    if (type?.mimeType == 'application/json' && raw.isNotEmpty) {
      body = jsonDecode(raw);
    } else if (type?.mimeType == 'multipart/form-data') {
      parts = _parseMultipart(bytes, type!.parameters['boundary']!);
    }
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));
    final call = ServerCall(
      request.method,
      request.uri.path,
      request.uri.queryParameters,
      headers,
      body,
      parts,
    );
    calls.add(call);

    var (status, payload) = forceStatus != null
        ? (forceStatus!, <String, Object?>{})
        : _route(call);
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    await request.response.close();
  }

  /// Splits a multipart body on its boundary. Latin-1 keeps bytes 1:1.
  List<FormPart> _parseMultipart(List<int> bytes, String boundary) {
    final parts = <FormPart>[];
    for (final chunk in latin1.decode(bytes).split('--$boundary').skip(1)) {
      if (chunk.startsWith('--')) break;
      final cut = chunk.indexOf('\r\n\r\n');
      final head = chunk.substring(0, cut);
      var body = chunk.substring(cut + 4);
      if (body.endsWith('\r\n')) body = body.substring(0, body.length - 2);
      String? header(String name) =>
          RegExp('$name="([^"]*)"').firstMatch(head)?.group(1);
      parts.add(
        FormPart(
          utf8.decode(latin1.encode(header('name') ?? '')),
          header('filename'),
          RegExp(
            r'content-type: *([^\r\n]+)',
            caseSensitive: false,
          ).firstMatch(head)?.group(1)?.split(';').first.trim(),
          latin1.encode(body),
        ),
      );
    }
    return parts;
  }

  static const _acceptable = {
    'text/csv',
    'text/plain',
    'text/rtf',
    'application/json',
    'application/pdf',
    'application/zip',
    'application/x-7z-compressed',
    'application/vnd.rar',
    'application/x-tar',
    'application/msword',
    'application/vnd.ms-excel',
    'application/vnd.ms-powerpoint',
    'application/rtf',
    'application/vnd.oasis.opendocument.text',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  /// Unix seconds, like the server's `created_at.to_i`; ascending with id.
  static int _createdAt(int id) => 1700000000 + id;

  Map<String, Object?> _sender(int contactId) => {
    'id': contactId,
    'name': 'name $contactId',
    'type': 'contact',
  };

  // views/api/v1/widget/messages/index.json.jbuilder: created_at is an int,
  // no private/source_id.
  Map<String, Object?> _indexJson(int id) => {
    'id': id,
    'content': 'hello',
    'message_type': 0,
    'content_type': 'text',
    'content_attributes': <String, Object?>{},
    'created_at': _createdAt(id),
    'conversation_id': 7,
  };

  // messages/create.json.jbuilder: has inbox_id, private, source_id; no
  // content_type, no echo_id.
  Map<String, Object?> _createJson(int id, String? content, int contactId) => {
    'id': id,
    'content': content,
    'inbox_id': 1,
    'conversation_id': 7,
    'message_type': 0,
    'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'private': false,
    'source_id': null,
    'content_attributes': <String, Object?>{},
    'sender': _sender(contactId),
  };

  // app/finders/message_finder.rb:32-48
  List<int> _page(int? before, int? after) {
    final ids = [
      for (final m in messageIds)
        if (!privateIds.contains(m) && !activityIds.contains(m)) m,
    ]..sort();
    List<int> take(Iterable<int> from, int n) => from.take(n).toList();
    if (before != null && after != null) {
      return take(ids.where((m) => m >= after && m < before), 1000);
    }
    if (before != null) {
      return take(
        ids.where((m) => m < before).toList().reversed,
        20,
      ).reversed.toList();
    }
    if (after != null) return take(ids.where((m) => m > after), 100);
    return take(ids.reversed, 20).reversed.toList();
  }

  (int, Object?) _createMessage(ServerCall call, int contactId) {
    // params[:message] is nil without a `message` hash: NoMethodError -> 500
    final String? content;
    final List<FormPart> files;
    final body = call.body;
    if (call.parts.isNotEmpty) {
      final fields = {
        for (final p in call.parts)
          if (p.filename == null) p.name: p.text,
      };
      if (!call.parts.any((p) => p.name.startsWith('message['))) {
        return (500, {'error': 'undefined method [] for nil'});
      }
      content = fields['message[content]'];
      files = [
        for (final p in call.parts)
          if (p.filename != null && p.name == 'message[attachments][]') p,
      ];
    } else if (body is Map && body['message'] is Map) {
      content = (body['message'] as Map)['content'] as String?;
      files = const [];
    } else {
      return (500, {'error': 'undefined method [] for nil'});
    }

    hasConversation = true; // set_conversation runs before the save
    if ((content ?? '').isEmpty && files.isEmpty) {
      return (422, {'message': 'Content can\'t be blank'});
    }
    for (final f in files) {
      final t = f.contentType ?? 'application/octet-stream';
      final media =
          t.startsWith('image/') ||
          t.startsWith('video/') ||
          t.startsWith('audio/');
      if (!media && !_acceptable.contains(t)) {
        return (422, {'message': 'File type not supported'});
      }
      if (f.bytes.length > ZukkoChatUpload.maxSize) {
        return (422, {'message': 'File size is too big'});
      }
    }
    if (createdJoinsList) messageIds.add(createdId);
    return (200, _createJson(createdId, content, contactId));
  }

  (int, Object?) _route(ServerCall call) {
    final path = call.path.replaceFirst('/api/v1/widget', '');
    if (call.query['website_token'] != websiteToken) {
      return (404, {'error': 'Resource could not be found'});
    }

    if (path == '/config') {
      final known = _contactOf(call.jwt);
      final id = known == null
          ? _newContact(null)
          : _mergedInto[known] ?? known;
      return (
        200,
        {
          'website_channel_config': {
            'auth_token': 'jwt-$id',
            'website_name': 'Zukko',
            'welcome_title': 'Hi',
            'widget_color': '#1f93ff',
            'allow_messages_after_resolved': true,
          },
          'contact': _contactJson(id),
          'global_config': {'BRAND_NAME': 'Zukko'},
        },
      );
    }

    final id = _contactOf(call.jwt);
    if (id == null) return (404, {'error': 'Resource could not be found'});

    switch ('${call.method} $path') {
      case 'PATCH /contact/set_user':
        final params = call.body as Map;
        final identifier = params['identifier'] as String?;
        final hash = params['identifier_hash'] as String?;
        final customOnly =
            params['custom_attributes'] != null && (identifier ?? '').isEmpty;
        // contacts_controller.rb:46-61
        final verify = !((hash ?? '').isEmpty && !hmacMandatory) && !customOnly;
        if (verify && hash != hashFor(identifier ?? '')) {
          return (
            401,
            {'error': 'HMAC failed: Invalid Identifier Hash Provided'},
          );
        }
        if (setUserStatus != null) return (setUserStatus!, {'error': 'x'});
        if (mergeOnSetUser) {
          final other = _mergedInto[id] = _newContact(identifier);
          return (
            200,
            {
              'id': other,
              'has_email': false,
              'has_name': true,
              'has_phone_number': false,
            },
          );
        }
        final current = contacts[id];
        if (current != null && current != identifier) {
          final other = _newContact(identifier);
          return (
            200,
            {
              'id': other,
              'has_email': false,
              'has_name': true,
              'has_phone_number': false,
              'widget_auth_token': 'jwt-$other',
            },
          );
        }
        contacts[id] = identifier;
        return (
          200,
          {
            'id': id,
            'has_email': false,
            'has_name': true,
            'has_phone_number': false,
          },
        );
      case 'GET /contact':
        final now = _mergedInto[id] ?? id;
        return (200, {'id': now, 'identifier': contacts[now]});
      case 'GET /conversations':
        return (
          200,
          hasConversation
              ? {
                  'id': 7,
                  'inbox_id': 1,
                  'contact_last_seen_at': 0,
                  'status': 'open',
                }
              : <String, Object?>{},
        );
      case 'GET /messages':
        // meta is {} without a conversation (index.json.jbuilder:15)
        final page = hasConversation
            ? _page(
                int.tryParse(call.query['before'] ?? ''),
                int.tryParse(call.query['after'] ?? ''),
              )
            : <int>[];
        return (
          200,
          {
            'payload': [for (final m in page) _indexJson(m)],
            'meta': hasConversation
                ? {'contact_last_seen_at': 0}
                : <String, Object?>{},
          },
        );
      case 'POST /messages':
        return _createMessage(call, id);
      case 'POST /conversations/toggle_typing':
        if (!hasConversation) {
          return (404, {'error': 'Resource could not be found'});
        }
        // only 'on' / 'off' dispatch an event; anything else is a no-op 200
        final status =
            call.query['typing_status'] ??
            (call.body is Map ? (call.body as Map)['typing_status'] : null);
        if (status == 'on' || status == 'off') typing.add(status as String);
        return (200, <String, Object?>{});
      case 'POST /conversations/update_last_seen':
        return (200, <String, Object?>{});
    }
    return (404, {'error': 'Resource could not be found'});
  }
}
