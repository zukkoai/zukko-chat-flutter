/// Null-tolerant JSON converters shared by the models.
///
/// The server is inconsistent about types (ids as numbers or strings, nullable
/// fields on anonymous contacts) and its input is untrusted, so parsing never
/// throws on missing, huge or non-finite values: it falls back instead.
library;

/// Largest integer a double represents exactly; anything beyond is garbage.
const _maxSafeInt = 9007199254740992;

/// Latest unix second `DateTime` can represent (8.64e15 ms).
const _maxEpochSeconds = 8640000000000;

/// Parses an int from an int, num or numeric string; `null` for anything else
/// (including non-finite or out-of-range numbers).
int? intFromJson(Object? value) => switch (value) {
  int v => v,
  num v when v.isFinite && v.abs() <= _maxSafeInt => v.toInt(),
  String v => int.tryParse(v),
  _ => null,
};

/// Like [intFromJson] but for required ids; falls back to 0.
int idFromJson(Object? value) => intFromJson(value) ?? 0;

/// Normalises `created_at` to an ISO-8601 UTC string.
///
/// Accepts unix seconds, a numeric string, or any string `DateTime.parse`
/// accepts (including the local-time strings older SDK versions stored).
/// Missing, malformed or out-of-range values fall back to "now".
String createdAtFromJson(Object? value) {
  final seconds = switch (value) {
    num v => v,
    String v => num.tryParse(v),
    _ => null,
  };
  if (seconds != null) {
    return seconds.isFinite && seconds >= 0 && seconds <= _maxEpochSeconds
        ? DateTime.fromMillisecondsSinceEpoch(
            (seconds * 1000).round(),
            isUtc: true,
          ).toIso8601String()
        : _now();
  }
  final parsed = value is String ? DateTime.tryParse(value) : null;
  return parsed?.toUtc().toIso8601String() ?? _now();
}

String _now() => DateTime.now().toUtc().toIso8601String();

/// Parses every element of [data] with [parse], skipping the ones that are
/// malformed, so one poisoned item never blocks the rest. [data] itself must
/// be a list.
List<T> parseList<T>(Object? data, T Function(Map<String, dynamic>) parse) {
  if (data is! List) {
    throw FormatException('expected a list, got ${data.runtimeType}');
  }
  final result = <T>[];
  for (final item in data) {
    try {
      result.add(parse(item as Map<String, dynamic>));
    } catch (_) {
      // skip the bad item
    }
  }
  return result;
}
