import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the SDK never installs a Dio LogInterceptor (it prints tokens)', () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('LogInterceptor'))
          f.path,
    ];

    expect(offenders, isEmpty);
  });
}
