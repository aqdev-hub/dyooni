import '../../data/models/currency_type.dart';
import 'arabic_number_parser.dart';

/// Matches what the person SAID against the currencies THEY manage (drawer → العملات).
///
/// Why this exists: currencies are person-defined ("محلي", "أجنبي", "دولار", "ريال سعودي" …) and a
/// transaction stores the currency's id. The old voice parser only knew a fixed list of codes
/// (USD, YER, SAR …) that usually do not exist in the person's list, so whatever they said ended
/// up as the default «محلي». Matching against the real list fixes that for any name they chose.
///
/// Pure Dart (no Flutter) so it is unit-tested.
class SpokenCurrency {
  const SpokenCurrency._();

  /// Words that name a currency family but do not identify one on their own ("ريال" is both the
  /// Yemeni and the Saudi currency), so they never select a currency by themselves.
  static const _generic = {'ريال', 'ريالات', 'ريالا', 'عمله', 'عملات', 'العمله'};

  /// Older fixed codes → extra spoken keywords, so a list that still holds `USD`, `SAR` … matches
  /// natural speech even if the person renamed the currency.
  static const _legacyKeywords = <String, List<String>>{
    'USD': ['دولار', 'usd', 'dollar'],
    'SAR': ['سعودي', 'sar'],
    'YER': ['يمني', 'yer'],
    'AED': ['درهم', 'اماراتي', 'aed'],
    'EGP': ['جنيه', 'مصري', 'egp'],
    'KWD': ['دينار', 'كويتي', 'kwd'],
  };

  /// Currency words that, when spoken but matching nothing in the list, mean "a currency the
  /// person has not added" rather than "no currency was said".
  static const _currencyWords = {
    'دولار', 'دولارات', 'درهم', 'دراهم', 'جنيه', 'جنيهات', 'دينار', 'دنانير', 'يورو', 'ريال',
    'ريالات', 'استرليني', 'روبيه', 'يوان', 'ين', 'ليره', 'فرنك', 'تومان', 'شيكل',
  };

  static List<String> _tokens(String text) => [
        for (final raw in text.split(RegExp(r'\s+')))
          if (_clean(raw).isNotEmpty) _clean(raw),
      ];

  /// Normalised word: no diacritics, unified alef/ya/ta-marbuta, no leading "ال".
  static String _clean(String raw) {
    var w = ArabicNumberParser.normalizeWord(raw).replaceAll(RegExp(r'[^ء-يa-z0-9]'), '');
    if (w.length > 3 && w.startsWith('ال')) w = w.substring(2);
    return w;
  }

  static bool _sameWord(String spoken, String wanted) {
    if (spoken == wanted) return true;
    if (wanted.length >= 4 && spoken.length >= 4) {
      // "دولارات" ↔ "دولار", "سعوديه" ↔ "سعودي": one is the start of the other.
      if (spoken.startsWith(wanted) || wanted.startsWith(spoken)) return true;
      // One wrong/missing letter from the recognizer.
      if ((spoken.length - wanted.length).abs() <= 1 && _distance(spoken, wanted) <= 1) return true;
    }
    return false;
  }

  static int _distance(String a, String b) {
    if (a == b) return 0;
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

  /// The id of the currency the speaker named, or `null` when none was named / none matches.
  /// Longer, more specific names win ("ريال سعودي" beats "ريال").
  static String? match(String spoken, List<CurrencyType> currencies) {
    final said = _tokens(spoken);
    if (said.isEmpty) return null;
    bool has(String wanted) => said.any((s) => _sameWord(s, wanted));

    String? bestId;
    var bestScore = 0;
    for (final c in currencies) {
      final nameTokens = _tokens(c.name);
      final significant = [for (final t in nameTokens) if (!_generic.contains(t)) t];
      var score = 0;
      if (significant.isNotEmpty && significant.every(has)) {
        score = significant.length * 10 + significant.fold<int>(0, (n, t) => n + t.length);
      } else if (significant.isEmpty && nameTokens.isNotEmpty && nameTokens.every(has) && nameTokens.length >= 2) {
        score = 1; // a name made only of generic words matches only when all of them were said
      }
      final keywords = _legacyKeywords[c.id];
      if (score == 0 && keywords != null && keywords.any((k) => has(_clean(k)))) score = 5;
      if (score > bestScore) {
        bestScore = score;
        bestId = c.id;
      }
    }
    return bestId;
  }

  /// `true` when the speaker said a currency word that matches nothing in [currencies] (and is not
  /// the bare, ambiguous "ريال") — the dialogue then asks which of THEIR currencies they mean.
  static bool namesUnknownCurrency(String spoken, List<CurrencyType> currencies) {
    if (match(spoken, currencies) != null) return false;
    for (final t in _tokens(spoken)) {
      if (t == 'ريال' || t == 'ريالات' || t == 'ريالا') continue;
      if (_currencyWords.contains(t)) return true;
    }
    return false;
  }
}
