import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/chat_message_store.dart';

TextMessage _m(String id, String at, {MessageStatus? status}) => TextMessage(
  id: id,
  authorId: 'a',
  text: id,
  createdAt: DateTime.parse(at),
  status: status,
);

void main() {
  late InMemoryChatController chat;
  late ChatMessageStore store;

  setUp(() {
    chat = InMemoryChatController();
    store = ChatMessageStore(chat);
  });

  List<String> ids() => [for (final m in chat.messages) m.id];

  test('upsertLocal inserts by time, scanning from the end', () async {
    store.upsertLocal(_m('b', '2024-01-01T10:00:02Z'));
    store.upsertLocal(_m('d', '2024-01-01T10:00:04Z'));
    store.upsertLocal(_m('c', '2024-01-01T10:00:03Z'));
    store.upsertLocal(_m('a', '2024-01-01T10:00:01Z'));
    await Future<void>.delayed(Duration.zero);
    expect(ids(), ['a', 'b', 'c', 'd']);
  });

  test('bulkUpsert: equal dates keep arrival order, one setMessages', () async {
    store.upsertLocal(_m('local', '2024-01-01T10:00:05Z'));
    store.bulkUpsert([
      _m('1', '2024-01-01T10:00:05Z'),
      _m('2', '2024-01-01T10:00:01Z'),
      _m('3', '2024-01-01T10:00:05Z'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(ids(), ['2', 'local', '1', '3']);
  });

  test(
    'alias: the socket echo that came first is removed (one bubble)',
    () async {
      store.upsertLocal(
        _m('echo', '2024-01-01T10:00:01Z', status: MessageStatus.sending),
      );
      store.upsertLocal(_m('77', '2024-01-01T10:00:02Z'));
      store.alias(77, 'echo');
      await Future<void>.delayed(Duration.zero);
      expect(ids(), ['echo']);
      expect(store.keyOfServer(77), 'echo');
      expect(store.keyOfServer(5), '5');
    },
  );

  test('merge keeps the better delivery state and the local position', () {
    final merged = ChatMessageStore.merge(
      _m('x', '2024-01-01T10:00:01Z', status: MessageStatus.seen),
      _m('x', '2024-01-01T10:00:09Z', status: MessageStatus.delivered),
    );
    expect(merged.status, MessageStatus.seen);
    expect(merged.createdAt, DateTime.parse('2024-01-01T10:00:01Z'));
  });

  test('keepOnly drops the rest and forgets the aliases', () async {
    store.upsertLocal(_m('keep', '2024-01-01T10:00:01Z'));
    store.upsertLocal(_m('drop', '2024-01-01T10:00:02Z'));
    store.alias(9, 'drop');
    store.keepOnly((k) => k == 'keep');
    await Future<void>.delayed(Duration.zero);
    expect(ids(), ['keep']);
    expect(store['drop'], isNull);
    expect(store.keyOfServer(9), '9');
  });

  test('markFailed sets the error status; unknown key is ignored', () async {
    store.upsertLocal(
      _m('a', '2024-01-01T10:00:01Z', status: MessageStatus.sending),
    );
    store.markFailed('a');
    store.markFailed('nope');
    expect(store['a']!.status, MessageStatus.error);
  });
}
