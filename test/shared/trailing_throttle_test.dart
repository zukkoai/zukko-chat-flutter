import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/trailing_throttle.dart';

void main() {
  test('runs now, collapses calls inside the window into one trailing run', () {
    fakeAsync((async) {
      var runs = 0;
      final throttle = TrailingThrottle(const Duration(seconds: 2), () async {
        runs++;
      });

      throttle();
      throttle();
      throttle();
      expect(runs, 1);

      async.elapse(const Duration(seconds: 2));
      expect(runs, 2); // the trailing one

      async.elapse(const Duration(seconds: 2));
      expect(runs, 2); // nothing pending any more

      throttle();
      expect(runs, 3);
      throttle.dispose();
    });
  });

  test('dispose cancels a pending trailing run', () {
    fakeAsync((async) {
      var runs = 0;
      final throttle = TrailingThrottle(const Duration(seconds: 2), () async {
        runs++;
      });
      throttle();
      throttle();

      throttle.dispose();
      async.elapse(const Duration(seconds: 5));

      expect(runs, 1);
      throttle(); // ignored once disposed
      expect(runs, 1);
    });
  });
}
