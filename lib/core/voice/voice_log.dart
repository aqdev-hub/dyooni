import 'package:flutter/foundation.dart' show debugPrint;

/// One place for EVERY voice diagnostic line (both recognizers, the dialogue, the wake word).
///
/// Lines are printed as `[voice 14:03:22.417] [tag] message` — the millisecond clock is what lets
/// a delay ("it started listening late") be measured from a pasted log — and the last [_max] are
/// also kept in memory so the voice screen can copy them (long-press its title) when the phone is
/// not attached to a computer. Printing is not limited to debug builds.
abstract class VoiceLog {
  static const _max = 600;
  static final List<String> _lines = [];

  static void d(String tag, String message) {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
    final line = '[voice $stamp] [$tag] $message';
    _lines.add(line);
    if (_lines.length > _max) _lines.removeRange(0, _lines.length - _max);
    debugPrint(line);
  }

  /// Everything kept so far, oldest first.
  static String dump() => _lines.join('\n');

  static void clear() => _lines.clear();
}
