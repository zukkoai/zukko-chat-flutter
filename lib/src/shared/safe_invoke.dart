import 'sdk_log.dart';

/// Runs the host callback [call]; a throw is logged (debug only) and swallowed
/// so a faulty app callback can never break the SDK.
void safeInvoke(void Function() call, String label) {
  try {
    call();
  } catch (e) {
    sdkLog('$label callback threw: ${e.runtimeType}');
  }
}
