class Formatters {
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 2)} ${units[unitIndex]}';
  }

  static String formatCurrency(int cents) {
    if (cents == 0) return '0';
    final value = cents / 100.0;
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  }

  static String formatEpoch(int seconds) {
    if (seconds <= 0) return '—';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return '${date.year}-${_two(date.month)}-${_two(date.day)}';
  }

  static String formatDate(DateTime date) {
    return '${date.year}-${_two(date.month)}-${_two(date.day)} ${_two(date.hour)}:${_two(date.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
