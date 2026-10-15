import 'package:zukko_chat_flutter/src/core/chatwoot_client_exception.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/api_call.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Response<dynamic>> ok() async =>
      Response(requestOptions: RequestOptions(), data: 'body');

  const type = ZukkoChatExceptionType.GET_CONFIG_FAILED;

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
      ZukkoChatExceptionType.GET_CONVERSATION_FAILED,
    );

    await expectLater(
      apiCall(type, () => throw original, (_) => 1),
      throwsA(same(original)),
    );
  });

  test('success returns the parsed value', () async {
    expect(await apiCall(type, ok, (d) => '$d!'), 'body!');
  });
}
