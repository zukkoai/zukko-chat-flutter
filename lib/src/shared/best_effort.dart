import 'sdk_log.dart';

/// Runs [action]; a failure is only logged. For work that must never break the
/// live flow (persisting, typing / last-seen calls). Never throws.
Future<void> bestEffort(Future<void> Function() action, String what) async {
  try {
    await action();
  } catch (e) {
    sdkLog('$what failed: ${e.runtimeType}', level: SdkLogLevel.warning);
  }
}
