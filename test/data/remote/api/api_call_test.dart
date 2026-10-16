import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/api_call.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Response<dynamic>> ok() async =>
      Response(requestOptions: RequestOptions(), data: 'body');

  const type = ZukkoChatExceptionType.getConfigFailed;

  // SEC6: apiCall used to catch only DioException / FormatException / TypeError
  for (final error in <Object>[
    RangeError('huge'),
    UnsupportedError('infinity'),
    StateError('x'),
    ArgumentError('y'),
    'a thrown string',
  ]) {
    test(
      'a parser throwing ${error.runtimeType} becomes a typed exception',
      () async {
        await expectLater(
          apiCall(type, ok, (_) => throw error),
          throwsA(
            isA<ZukkoChatException>().having((e) => e.type, 'type', type),
          ),
        );
      },
    );
  }

  test('a typed exception from the request is passed on unchanged', () async {
    final original = ZukkoChatException(
      'cause',
      ZukkoChatExceptionType.getConversationFailed,
    );

    await expectLater(
      apiCall(type, () => throw original, (_) => 1),
      throwsA(same(original)),
    );
  });

  test('success returns the parsed value', () async {
    expect(await apiCall(type, ok, (d) => '$d!'), 'body!');
  });

  test(
    'the message never echoes the parser error text, the cause is kept',
    () async {
      final boom = StateError('secret response fragment');

      await expectLater(
        apiCall(type, ok, (_) => throw boom),
        throwsA(
          isA<ZukkoChatException>()
              .having((e) => e.cause, 'cause', isNot(contains('secret')))
              .having((e) => e.error, 'error', same(boom))
              .having((e) => e.stackTrace, 'stackTrace', isNotNull),
        ),
      );
    },
  );
}
