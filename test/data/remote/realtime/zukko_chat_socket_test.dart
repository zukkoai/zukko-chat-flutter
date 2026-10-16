import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_connection_state.dart';
import 'package:zukko_chat_flutter/src/shared/backoff.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/zukko_chat_action_data.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/zukko_chat_event.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/zukko_chat_socket.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/zukko_chat_socket_events.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fakes.dart';

const _s = Duration(seconds: 1);

/// Drives a real [ZukkoChatSocket] against [FakeChannel]s under fake time.
class _Rig {
  _Rig(this.async, {Duration Function(int)? backoff}) {
    socket = ZukkoChatSocket(
      url: Uri.parse('wss://h/cable'),
      tokenProvider: () => token,
      connect: hub.connect,
      backoff: backoff ?? (n) => _s * (1 << n), // 1, 2, 4, 8 ...
    );
    sub = socket.events.listen(events.add);
  }

  final FakeAsync async;
  String? token = 'tok';
  final hub = FakeSocketHub();
  final events = <SocketEvent>[];
  late final ZukkoChatSocket socket;
  late final StreamSubscription<SocketEvent> sub;

  List<ZukkoChatConnectionState> get states => [
    for (final e in events)
      if (e is SocketStateChanged) e.state,
  ];
  List<SocketFailure> get failures =>
      events.whereType<SocketFailure>().toList();
  List<SocketMessage> get messages =>
      events.whereType<SocketMessage>().toList();

  void elapse(Duration d) => async.elapse(d);

  /// Connect + welcome + confirm on the newest channel.
  void subscribe() {
    socket.connect();
    hub.last.welcome();
    hub.last.confirm();
    async.flushMicrotasks();
  }
}

// ignore: library_private_types_in_public_api (test-local helper type)
void run(void Function(_Rig rig) body, {Duration Function(int)? backoff}) =>
    fakeAsync((async) {
      final rig = _Rig(async, backoff: backoff);
      body(rig);
      rig.socket.dispose();
      async.flushMicrotasks();
    });

void main() {
  group('handshake', () {
    test('connect -> welcome subscribes -> confirm sends presence at once', () {
      run((r) {
        r.socket.connect();
        expect(r.hub.urls.single.toString(), 'wss://h/cable');
        expect(r.socket.state, ZukkoChatConnectionState.connecting);

        r.hub.last.welcome();
        r.async.flushMicrotasks();
        final subscribe = r.hub.last.sent.single;
        expect(subscribe['command'], 'subscribe');
        expect(jsonDecode(subscribe['identifier'] as String), {
          'channel': 'RoomChannel',
          'pubsub_token': 'tok',
        });
        expect(r.socket.state, ZukkoChatConnectionState.connected);

        r.hub.last.confirm();
        r.async.flushMicrotasks();
        expect(r.socket.state, ZukkoChatConnectionState.subscribed);
        expect(r.hub.last.presenceFrames, 1);
        expect(r.states, [
          ZukkoChatConnectionState.connecting,
          ZukkoChatConnectionState.connected,
          ZukkoChatConnectionState.subscribed,
        ]);
      });
    });

    test('presence frame is a JSON-string `data` as ActionCable requires', () {
      run((r) {
        r.subscribe();

        final presence = r.hub.last.sent.last;
        expect(presence['command'], 'message');
        expect(presence['data'], isA<String>());
        expect(jsonDecode(presence['data'] as String), {
          'action': 'update_presence',
        });
      });
    });

    test('server events are forwarded typed', () {
      run((r) {
        r.subscribe();

        r.hub.last.event('message.created', {'id': 1, 'content': 'hi'});
        r.async.flushMicrotasks();

        expect(
          r.messages.single.message.event,
          ZukkoChatEventMessageType.messageCreated,
        );
        expect(r.messages.single.message.data!.id, 1);
      });
    });

    test('ping is forwarded', () {
      run((r) {
        r.subscribe();
        r.hub.last.ping();
        r.async.flushMicrotasks();

        expect(r.events.whereType<SocketPing>(), hasLength(1));
      });
    });
  });

  group('presence heartbeat (S7)', () {
    test('every 15 s: frames at t=0, 15, 30, 45, 60', () {
      run((r) {
        r.subscribe();
        // keep the connection alive: pings are not what is tested here
        for (var i = 0; i < 20; i++) {
          r.elapse(const Duration(seconds: 3));
          r.hub.last.ping();
        }

        expect(r.hub.channels, hasLength(1));
        expect(r.hub.last.presenceFrames, 5); // 61 s elapsed
      });
    });

    test('a repeated confirm does not stack timers', () {
      run((r) {
        r.subscribe();
        r.hub.last.confirm(); // 2nd confirm at t=0
        r.async.flushMicrotasks();
        for (var i = 0; i < 20; i++) {
          r.elapse(const Duration(seconds: 3));
          r.hub.last.ping();
        }

        // 2 immediate + 4 ticks (15, 30, 45, 60). Stacked timers would add 4.
        expect(r.hub.last.presenceFrames, 6);
      });
    });

    test('presence stops when the connection is lost', () {
      run((r) {
        r.subscribe();
        r.hub.last.serverClose();
        r.async.flushMicrotasks();
        final lost = r.hub.channels.first;
        final before = lost.presenceFrames;

        r.elapse(
          const Duration(seconds: 19),
        ); // the reconnected channel is a new one
        expect(lost.presenceFrames, before);
      });
    });
  });

  group('reconnect (S1)', () {
    test('backoff doubles: 1 s, 2 s, 4 s ...', () {
      run((r) {
        r.socket.connect(); // never welcomed, server closes at once
        for (final delay in [1, 2, 4, 8]) {
          final calls = r.hub.channels.length;
          r.hub.last.serverClose();
          r.async.flushMicrotasks();
          r.elapse(_s * delay - const Duration(milliseconds: 1));
          expect(r.hub.channels, hasLength(calls), reason: 'too early: $delay');
          r.elapse(const Duration(milliseconds: 1));
          expect(r.hub.channels, hasLength(calls + 1), reason: 'at $delay');
        }
      });
    });

    test('retryNow reconnects at once during a backoff, else does nothing', () {
      run((r) {
        r.socket.connect();
        r.socket.retryNow(); // connecting: no-op
        expect(r.hub.channels, hasLength(1));
        r.hub.last.serverClose();
        r.async.flushMicrotasks();
        expect(r.socket.state, ZukkoChatConnectionState.backoff);
        r.socket.retryNow();
        expect(r.hub.channels, hasLength(2));
        expect(r.socket.state, ZukkoChatConnectionState.connecting);
      });
    });

    test('a confirmed subscription resets the backoff', () {
      run((r) {
        r.socket.connect();
        r.hub.last.serverClose(); // attempt 0 -> 1 s
        r.async.flushMicrotasks();
        r.elapse(_s);
        r.hub.last.serverClose(); // attempt 1 -> 2 s
        r.async.flushMicrotasks();
        r.elapse(_s * 2);
        expect(r.hub.channels, hasLength(3));

        r.hub.last.welcome();
        r.hub.last.confirm();
        r.async.flushMicrotasks();
        r.hub.last.serverClose();
        r.async.flushMicrotasks();
        r.elapse(_s); // back to 1 s

        expect(r.hub.channels, hasLength(4));
      });
    });

    test('a reconnect subscribes again and reports it', () {
      run((r) {
        r.subscribe();
        r.hub.last.serverClose();
        r.async.flushMicrotasks();
        r.elapse(_s);
        r.hub.last.welcome();
        r.hub.last.confirm();
        r.async.flushMicrotasks();

        final subscribed = r.events.whereType<SocketStateChanged>().where(
          (e) => e.state == ZukkoChatConnectionState.subscribed,
        );
        expect(subscribed, hasLength(2));
      });
    });

    test('a stream error and the following done schedule one retry only', () {
      run((r) {
        r.socket.connect();
        r.hub.last.serverError();
        r.hub.last.serverClose();
        r.async.flushMicrotasks();
        r.elapse(_s * 10);

        expect(r.hub.channels, hasLength(2));
      });
    });

    test('a throwing channel factory is retried with backoff', () {
      run((r) {
        r.hub.failWith = StateError('no network');
        r.socket.connect();
        expect(r.socket.state, ZukkoChatConnectionState.backoff);

        r.hub.failWith = null;
        r.elapse(_s);

        expect(r.hub.channels, hasLength(1));
        expect(r.socket.state, ZukkoChatConnectionState.connecting);
      });
    });

    test('disconnect{reconnect:true} reconnects, {reconnect:false} stops', () {
      run((r) {
        r.subscribe();
        r.hub.last.emit({'type': 'disconnect', 'reconnect': true});
        r.async.flushMicrotasks();
        r.elapse(_s);
        expect(r.hub.channels, hasLength(2));

        r.hub.last.emit({
          'type': 'disconnect',
          'reason': 'unauthorized',
          'reconnect': false,
        });
        r.async.flushMicrotasks();
        r.elapse(const Duration(minutes: 5));

        expect(r.hub.channels, hasLength(2));
        expect(r.socket.state, ZukkoChatConnectionState.closed);
        expect(
          r.failures.single.error.type,
          ZukkoChatExceptionType.socketDisconnected,
        );
      });
    });

    test('defaultSocketBackoff doubles with jitter and caps at 30 s', () {
      final random = Random(1);
      for (var attempt = 0; attempt < 12; attempt++) {
        final base = 1000 * (1 << min(attempt, 5));
        final ms = defaultSocketBackoff(attempt, random).inMilliseconds;
        expect(
          ms,
          inInclusiveRange(min(30000, base), min(30000, base * 1.25)),
          reason: 'attempt $attempt',
        );
      }
      expect(defaultSocketBackoff(50).inMilliseconds, 30000);
    });
  });

  group('stale connection', () {
    test('no frame for 6 s after the last one reconnects', () {
      run((r) {
        r.subscribe();
        r.elapse(const Duration(seconds: 3));
        r.hub.last.ping();
        final first = r.hub.last;

        r.elapse(const Duration(seconds: 5, milliseconds: 999));
        expect(r.hub.channels, hasLength(1));
        r.elapse(const Duration(milliseconds: 1));

        expect(first.isClosedByClient, isTrue);
        expect(r.socket.state, ZukkoChatConnectionState.backoff);
        r.elapse(_s);
        expect(r.hub.channels, hasLength(2));
      });
    });

    test('regular pings keep the connection', () {
      run((r) {
        r.subscribe();
        for (var i = 0; i < 100; i++) {
          r.elapse(const Duration(seconds: 3));
          r.hub.last.ping();
        }

        expect(r.hub.channels, hasLength(1));
        expect(r.socket.state, ZukkoChatConnectionState.subscribed);
      });
    });

    test('a connection that never welcomes is abandoned after 15 s', () {
      run((r) {
        r.socket.connect();
        r.elapse(const Duration(seconds: 14, milliseconds: 999));
        expect(r.hub.channels, hasLength(1));

        r.elapse(const Duration(milliseconds: 1));
        r.elapse(_s);

        expect(r.hub.channels, hasLength(2));
      });
    });
  });

  // F3
  group('token provider', () {
    test('every reconnect after a drop reads the current token', () {
      run((r) {
        r.subscribe();
        expect(r.hub.last.sent.first['identifier'], contains('"tok"'));

        r.token = 'tok-B'; // session was reset in between
        r.hub.last.serverClose();
        r.async.flushMicrotasks();
        r.elapse(const Duration(seconds: 1));
        r.hub.last.welcome();
        r.async.flushMicrotasks();

        expect(r.hub.channels, hasLength(2));
        expect(jsonDecode(r.hub.last.sent.first['identifier'] as String), {
          'channel': 'RoomChannel',
          'pubsub_token': 'tok-B',
        });
      });
    });

    test('reconnectIfTokenChanged reconnects only for a different token', () {
      run((r) {
        r.subscribe();

        r.socket.reconnectIfTokenChanged();
        expect(r.hub.channels, hasLength(1));

        r.token = 'tok-B';
        r.socket.reconnectIfTokenChanged();
        expect(r.hub.channels, hasLength(2));
        r.socket.reconnectIfTokenChanged(); // already on tok-B
        expect(r.hub.channels, hasLength(2));
      });
    });

    test('without a token nothing is opened', () {
      run((r) {
        r.token = null;

        r.socket.connect();

        expect(r.hub.channels, isEmpty);
        expect(r.socket.state, ZukkoChatConnectionState.closed);
      });
    });
  });

  group('connect is idempotent (S2)', () {
    test('a 2nd connect with the same token while live is a no-op', () {
      run((r) {
        r.subscribe();
        final first = r.hub.last;
        r.socket.connect();

        expect(first.isClosedByClient, isFalse);
        expect(r.hub.channels, hasLength(1));
        r.socket.connect(); // also while only connecting
        r.hub.last.event('message.created', {'id': 1});
        r.async.flushMicrotasks();
        expect(r.messages, hasLength(1));
      });
    });

    test('a 2nd connect with another token closes the old channel; events '
        'arrive once', () {
      run((r) {
        r.socket.connect();
        final old = r.hub.last;
        r.token = 'tok-2';
        r.socket.connect();

        expect(old.closeCodeByClient, 1000);
        expect(r.hub.channels, hasLength(2));

        r.hub.last.welcome();
        r.hub.last.confirm();
        r.hub.last.event('message.created', {'id': 1});
        old.event('message.created', {'id': 99}); // late frame of the old one
        r.async.flushMicrotasks();

        expect(r.messages.map((m) => m.message.data!.id), [1]);
      });
    });

    test('connect after a fatal stop starts over', () {
      run((r) {
        r.socket.connect();
        r.hub.last.emit({'type': 'reject_subscription'});
        r.async.flushMicrotasks();
        expect(r.socket.state, ZukkoChatConnectionState.closed);

        r.token = 'fresh';
        r.socket.connect();

        expect(r.hub.channels, hasLength(2));
        expect(r.socket.state, ZukkoChatConnectionState.connecting);
      });
    });
  });

  group('rejected subscription (S5)', () {
    test('reports a typed failure, sends no presence and does not retry', () {
      run((r) {
        r.socket.connect();
        r.hub.last.welcome();
        final channel = r.hub.last;
        channel.emit({'type': 'reject_subscription'});
        r.async.flushMicrotasks();
        r.elapse(const Duration(minutes: 2));

        expect(
          r.failures.single.error.type,
          ZukkoChatExceptionType.socketSubscriptionRejected,
        );
        expect(r.socket.state, ZukkoChatConnectionState.closed);
        expect(channel.presenceFrames, 0);
        expect(channel.closeCodeByClient, 1000);
        expect(r.hub.channels, hasLength(1)); // no blind retry
      });
    });
  });

  group('subscribe timeout', () {
    // the server pings every 3 s (here 1 s); keep the stale watchdog quiet meanwhile
    void silence(_Rig r, Duration d) {
      for (var t = 0; t < d.inSeconds; t++) {
        r.hub.last.ping();
        r.elapse(_s);
      }
    }

    test('2 timeouts in a row: one failure, no third attempt', () {
      run((r) {
        r.socket.connect();
        r.hub.last.welcome();
        r.async.flushMicrotasks();
        silence(r, const Duration(seconds: 10)); // 1st timeout at 10 s
        expect(r.socket.state, ZukkoChatConnectionState.backoff);
        r.elapse(_s); // retry
        expect(r.hub.channels, hasLength(2));
        r.hub.last.welcome();
        r.async.flushMicrotasks();
        silence(r, const Duration(seconds: 10));
        r.elapse(const Duration(minutes: 2));

        expect(
          r.failures.single.error.type,
          ZukkoChatExceptionType.socketSubscriptionRejected,
        );
        expect(r.socket.state, ZukkoChatConnectionState.closed);
        expect(r.hub.channels, hasLength(2));
      });
    });

    test('a timeout then confirm subscribes and resets the counter', () {
      run((r) {
        r.socket.connect();
        r.hub.last.welcome();
        r.async.flushMicrotasks();
        silence(r, const Duration(seconds: 10));
        r.elapse(_s);
        r.hub.last.welcome();
        r.hub.last.confirm();
        r.async.flushMicrotasks();
        expect(r.socket.state, ZukkoChatConnectionState.subscribed);

        // lose the connection; the next attempt may time out once again
        r.hub.last.serverClose();
        r.async.flushMicrotasks();
        r.elapse(const Duration(seconds: 2));
        r.hub.last.welcome();
        r.async.flushMicrotasks();
        silence(r, const Duration(seconds: 10));
        expect(r.failures, isEmpty);
        expect(r.socket.state, ZukkoChatConnectionState.backoff);
      });
    });

    test('a confirm in time never times out', () {
      run((r) {
        r.subscribe();
        r.elapse(const Duration(minutes: 1));
        expect(r.failures, isEmpty);
      });
    });

    test('connect() after the failure re-reads the token', () {
      run((r) {
        r.socket.connect();
        r.hub.last.welcome();
        r.async.flushMicrotasks();
        silence(r, const Duration(seconds: 10));
        r.elapse(_s);
        r.hub.last.welcome();
        r.async.flushMicrotasks();
        silence(r, const Duration(seconds: 10));
        expect(r.socket.state, ZukkoChatConnectionState.closed);

        r.token = 'fresh';
        r.socket.connect();
        r.hub.last.welcome();
        r.async.flushMicrotasks();
        expect(r.hub.channels, hasLength(3));
        expect(
          jsonEncode(r.hub.last.sent.single['identifier']),
          contains('fresh'),
        );
        r.hub.last.confirm();
        r.async.flushMicrotasks();
        expect(r.socket.state, ZukkoChatConnectionState.subscribed);
      });
    });
  });

  group('conversation events', () {
    test('conversation.created / updated parse with the server payload', () {
      run((r) {
        r.subscribe();
        // keys of Conversations::EventDataPresenter#push_data
        final payload = {
          'id': 7,
          'inbox_id': 3,
          'status': 'open',
          'contact_last_seen_at': 1700000000,
          'messages': <Object?>[],
          'meta': {'sender': <String, Object?>{}},
          'updated_at': 1.5,
        };
        r.hub.last.event('conversation.created', payload);
        r.hub.last.event('conversation.updated', payload);
        r.async.flushMicrotasks();

        final msgs = r.messages.map((m) => m.message).toList();
        expect(msgs.map((m) => m.event), [
          ZukkoChatEventMessageType.conversationCreated,
          ZukkoChatEventMessageType.conversationUpdated,
        ]);
        final d = msgs.first.data!;
        expect([d.id, d.inboxId, d.status], [7, 3, 'open']);
      });
    });

    test('message attachments are kept; garbage fields do not throw', () {
      run((r) {
        r.subscribe();
        r.hub.last.event('message.created', {
          'id': 1,
          'attachments': [
            {'id': 2, 'file_type': 'image', 'data_url': 'https://h/a.png'},
          ],
        });
        r.hub.last.event('conversation.updated', {
          'inbox_id': 'x',
          'contact_last_seen_at': 'soon',
        });
        r.hub.last.event('message.created', {'attachments': 'nope'});
        r.async.flushMicrotasks();

        final first = r.messages.first.message.data!;
        expect((first.raw['attachments'] as List).single['file_type'], 'image');
        // every frame is delivered; a non-list attachments value is dropped
        // when the payload becomes a message
        expect(r.messages, hasLength(3));
        expect(r.messages.last.message.data!.toMessage().attachments, isNull);
        expect(r.messages[1].message.data!.inboxId, isNull);
        expect(r.socket.state, ZukkoChatConnectionState.subscribed);
      });
    });

    // B3: a string / float id used to throw in fromJson and drop the whole event
    test('ids sent as strings or numbers do not drop the event', () {
      run((r) {
        r.subscribe();
        r.hub.last.event('message.created', {
          'id': '42',
          'conversation_id': '7',
          'message_type': '1',
          'created_at': 1700000000,
        });
        r.async.flushMicrotasks();

        final data = r.messages.single.message.data!;
        expect(data.id, 42);
        expect(data.messageType, 1);
        final message = data.toMessage();
        expect([message.id, message.conversationId], [42, 7]);
      });
    });

    test('a malformed sender is dropped, the message is kept', () {
      run((r) {
        r.subscribe();
        r.hub.last.event('message.created', {'id': 1, 'sender': 'nobody'});
        r.async.flushMicrotasks();

        final message = r.messages.single.message.data!.toMessage();
        expect(message.id, 1);
        expect(message.sender, isNull);
      });
    });
  });

  group('garbage frames (S3)', () {
    test('never throw and the next valid frame is still delivered', () {
      final errors = <Object>[];
      runZonedGuarded(() {
        run((r) {
          r.subscribe();
          final garbage = <Object>[
            'garbage',
            '[1]',
            '{"type":"x","message":[]}',
            '{"message":{"data":"not a map"}}',
            '{"message":{"event":5,"data":[]}}',
            '{"message":{"event":"message.created","data":{"id":"abc"}}}',
            Uint8List.fromList([1, 2, 3]),
            42,
            '',
          ];
          for (final frame in garbage) {
            r.hub.last.emit(frame);
          }
          r.hub.last.event('message.created', {'id': 7});
          r.async.flushMicrotasks();

          expect(r.socket.state, ZukkoChatConnectionState.subscribed);
          expect(r.hub.channels, hasLength(1));
          // the valid frame arrives (undecodable-data ones may arrive typed, but
          // as events the app can ignore - nothing may throw)
          expect(r.messages.last.message.data!.id, 7);
        });
      }, (e, s) => errors.add(e));

      expect(errors, isEmpty);
    });
  });

  group('send (S17)', () {
    test('returns false before connect, while connecting and in backoff', () {
      run((r) {
        expect(r.socket.send(ZukkoChatActionType.updatePresence), isFalse);
        r.socket.connect();
        expect(r.socket.send(ZukkoChatActionType.updatePresence), isFalse);
        r.hub.last.serverClose();
        r.async.flushMicrotasks();

        expect(r.socket.state, ZukkoChatConnectionState.backoff);
        expect(r.socket.send(ZukkoChatActionType.updatePresence), isFalse);
      });
    });

    test('returns true when subscribed and writes the frame', () {
      run((r) {
        r.subscribe();
        final before = r.hub.last.sent.length;

        expect(r.socket.send(ZukkoChatActionType.updatePresence), isTrue);
        expect(r.hub.last.sent.length, before + 1);
      });
    });

    test('a closed sink makes send return false instead of throwing', () {
      run((r) {
        r.subscribe();
        r.hub.last.failOnAdd = true;

        expect(r.socket.send(ZukkoChatActionType.updatePresence), isFalse);
      });
    });
  });

  group('dispose (S8)', () {
    test(
      'closes the sink with 1000, stops everything, ignores late frames',
      () {
        fakeAsync((async) {
          final r = _Rig(async);
          r.subscribe();
          final channel = r.hub.last;
          final seen = r.events.length;

          r.socket.dispose();
          async.flushMicrotasks();
          channel.event('message.created', {'id': 1});
          async.elapse(const Duration(minutes: 5));

          expect(channel.closeCodeByClient, 1000);
          expect(r.events.length, seen);
          expect(channel.presenceFrames, 1); // no heartbeat after dispose
          expect(r.hub.channels, hasLength(1)); // no reconnect
          expect(r.socket.state, ZukkoChatConnectionState.closed);
        });
      },
    );

    test('a pending backoff retry is cancelled', () {
      fakeAsync((async) {
        final r = _Rig(async);
        r.socket.connect();
        r.hub.last.serverClose();
        async.flushMicrotasks();

        r.socket.dispose();
        async.elapse(const Duration(minutes: 5));

        expect(r.hub.channels, hasLength(1));
      });
    });

    test('connect after dispose does nothing; dispose twice is fine', () async {
      final hub = FakeSocketHub();
      final socket = ZukkoChatSocket(
        url: Uri.parse('wss://h/cable'),
        tokenProvider: () => 'tok',
        connect: hub.connect,
      );

      await socket.dispose();
      await socket.dispose();
      socket.connect();

      expect(hub.channels, isEmpty);
      expect(socket.send(ZukkoChatActionType.updatePresence), isFalse);
    });

    test('the event stream completes', () async {
      final socket = ZukkoChatSocket(
        url: Uri.parse('wss://h/cable'),
        tokenProvider: () => 'tok',
        connect: FakeSocketHub().connect,
      );
      final done = socket.events.toList();

      await socket.dispose();

      expect(await done, isEmpty);
    });
  });
}
