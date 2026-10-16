/// `m:ss`, e.g. `0:09`, `12:30`.
String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// `512 B`, `1.4 KB`, `12 MB`; [units] are the four unit names, localized.
String formatBytes(
  int bytes, [
  List<String> units = const ['B', 'KB', 'MB', 'GB'],
]) {
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
