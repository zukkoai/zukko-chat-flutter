import 'package:flutter/foundation.dart';

/// Debug-only logger. Release builds stay silent.
void sdkLog(String message) {
  if (kDebugMode) debugPrint('[zukko_chat] $message');
}
