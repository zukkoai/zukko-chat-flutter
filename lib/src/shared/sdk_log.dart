import 'package:flutter/foundation.dart';

/// Severity of an [sdkLog] line.
enum SdkLogLevel {
  /// A failure the integrating developer has to fix.
  error('ERROR: '),

  /// Recoverable or odd: the SDK carries on.
  warning('WARNING: '),

  /// Flow information.
  info('');

  const SdkLogLevel(this.prefix);
  final String prefix;
}

/// Debug-only logger. Release builds stay silent. Never pass secrets
/// (tokens, JWT, hashes) as [message].
void sdkLog(String message, {SdkLogLevel level = SdkLogLevel.info}) {
  if (kDebugMode) debugPrint('[zukko_chat] ${level.prefix}$message');
}
