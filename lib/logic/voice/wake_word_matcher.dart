import 'arabic_number_parser.dart';

/// Decides whether a short transcript is the wake word «ديوني».
///
/// Why fuzzy: the local model writes a one-word utterance with only a few characters and often a
/// letter off ("ديني", "دوني", "ديون"). A strict `contains('ديوني')` would miss most real calls,
/// while a loose match would wake on ordinary speech — so the rule is: some token (or the whole
/// utterance with spaces removed, for "دي وني") must be within ONE edit of the wake word.
/// Pure Dart so it is fully unit-testable.
class WakeWordMatcher {
  const WakeWordMatcher._();

  static const wakeWord = 'ديوني';

  static bool matches(String transcript, {String word = wakeWord}) {
    final target = _norm(word);
    final tokens = [
      for (final t in transcript.trim().split(RegExp(r'\s+')))
        if (t.isNotEmpty) _norm(t),
    ];
    if (tokens.isEmpty) return false;
    // Leading "يا" ("يا ديوني") is just an address particle.
    final joined = tokens.join();
    if (joined.length <= target.length + 3 && _distance(joined, target) <= 1) return true;
    if (joined.startsWith('يا') && _distance(joined.substring(2), target) <= 1) return true;
    for (final t in tokens) {
      if (t.length >= 4 && _distance(t, target) <= 1) return true;
    }
    return false;
  }

  /// Lower-case, diacritics removed, alef/ya/ta-marbuta unified.
  static String _norm(String text) => ArabicNumberParser.normalizeWord(text).replaceAll(RegExp(r'[^ء-يa-z0-9]'), '');

  /// Levenshtein distance (insert/delete/substitute).
  static int _distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }
}
