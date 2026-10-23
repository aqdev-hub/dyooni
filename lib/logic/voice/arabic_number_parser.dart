/// Spoken-Arabic number engine (pure Dart, no plugin/UI dependency).
///
/// WHY THIS FILE EXISTS (root cause of the "خمسة ألف → 1000" bug):
/// the old parser (a) summed EVERY number word in the whole sentence, (b) lacked many ordinary
/// forms (مئتين، 11–19، خمس/ست without ة، ...), and (c) — the real killer — when the recognizer
/// garbled the number into noise (e.g. "أuأ ألف") the noise was silently deleted and the lone
/// word "ألف" was read as exactly 1000. A wrong amount that looks plausible is the worst failure
/// a finance app can have, so this engine follows three rules:
///   1. Only ONE contiguous number phrase is evaluated (the one next to a currency word if any).
///   2. If a number phrase contains a corrupted token (Latin letters fused with alef/hamza, a bare
///      alef…) the result is "uncertain" — [AmountExtraction.value] is `null` and
///      [AmountExtraction.uncertain] is `true`, so the dialogue asks for the amount again instead
///      of guessing.
///   3. Evaluation follows Arabic grammar (units/tens/hundreds accumulate; ألف/مليون multiply the
///      accumulated group), including colloquial Yemeni forms ("خمسة ألف", "ميتين", "ونص").
class AmountExtraction {
  const AmountExtraction({
    required this.value,
    required this.uncertain,
    required this.startToken,
    required this.endToken,
    this.bare = false,
  });

  const AmountExtraction.none()
      : value = null,
        uncertain = false,
        startToken = -1,
        endToken = -1;

  /// The amount, or `null` when none was found OR when it was heard but is untrustworthy.
  final double? value;

  /// `true` when a number phrase WAS spoken but contains recognizer noise — never guess it.
  final bool uncertain;

  /// Inclusive token range of the number phrase inside the token list given to [extract].
  final int startToken;
  final int endToken;

  /// `true` when the phrase is ONLY a multiplier ("ألف" alone → 1000). That is also exactly what
  /// a recognizer leaves behind when it drops or garbles the number word in front of it
  /// ("خمسة ألف" → "ألف"), so it is weaker evidence than a full phrase.
  final bool bare;

  bool get found => startToken >= 0;
}

enum _Kind { value, multiplier, hundredMultiplier, half, connector, corrupt, other }

class _Tok {
  const _Tok(this.kind, [this.value = 0]);
  final _Kind kind;
  final double value;
}

class ArabicNumberParser {
  const ArabicNumberParser._();

  /// Diacritics + tatweel removed, alef variants unified, ة→ه, ى→ي, lower-case. (ئ is kept on
  /// purpose: "مئة" (100) and "مية" (colloquial "water") must stay distinguishable.)
  static String normalizeWord(String token) {
    final b = StringBuffer();
    for (final unit in token.runes) {
      final ch = String.fromCharCode(unit);
      if ((unit >= 0x064B && unit <= 0x0652) || unit == 0x0670 || unit == 0x0640) {
        continue;
      }
      switch (ch) {
        case 'أ':
        case 'إ':
        case 'آ':
          b.write('ا');
        case 'ة':
          b.write('ه');
        case 'ى':
          b.write('ي');
        default:
          b.write(ch.toLowerCase());
      }
    }
    return b.toString();
  }

  static const _units = <String, double>{
    'واحد': 1, 'واحده': 1,
    'اثنين': 2, 'اثنان': 2, 'اثنتين': 2, 'اثنتان': 2, 'ثنتين': 2, 'ثنين': 2,
    'ثلاثه': 3, 'ثلاث': 3, 'تلاته': 3, 'تلات': 3,
    'اربعه': 4, 'اربع': 4,
    'خمسه': 5, 'خمس': 5,
    'سته': 6, 'ست': 6,
    'سبعه': 7, 'سبع': 7,
    'ثمانيه': 8, 'ثماني': 8, 'ثمان': 8, 'ثمنيه': 8, 'تمانيه': 8,
    'تسعه': 9, 'تسع': 9,
    'عشره': 10, 'عشر': 10,
    'احدعشر': 11, 'احداشر': 11, 'حداشر': 11,
    'اثناعشر': 12, 'اطناشر': 12, 'اثنعش': 12,
    'ثلاثهعشر': 13, 'ثلطاشر': 13, 'ثلاثطاشر': 13,
    'اربعطاشر': 14, 'خمسطاشر': 15, 'ستطاشر': 16, 'سبعطاشر': 17, 'ثمانطاشر': 18, 'تسعطاشر': 19,
    'عشرين': 20, 'عشرون': 20,
    'ثلاثين': 30, 'ثلاثون': 30,
    'اربعين': 40, 'اربعون': 40,
    'خمسين': 50, 'خمسون': 50,
    'ستين': 60, 'ستون': 60,
    'سبعين': 70, 'سبعون': 70,
    'ثمانين': 80, 'ثمانون': 80,
    'تسعين': 90, 'تسعون': 90,
    // Standalone 100 / 200 (formal spelling only — bare "مية/ميه" is intentionally absent: in
    // Yemeni speech it usually means "ماء").
    'مائه': 100, 'مئه': 100,
    'مائتان': 200, 'مئتان': 200, 'مائتين': 200, 'مئتين': 200, 'ميتين': 200, 'ميتان': 200,
    'مايتين': 200,
    // Dual thousands / millions behave as plain values ("ألفين وخمسمائة" = 2500).
    'الفين': 2000, 'الفان': 2000,
    'مليونين': 2000000, 'مليونان': 2000000,
  };

  static const _multipliers = <String, double>{
    'الف': 1000,
    'الاف': 1000,
    'مليون': 1000000,
    'ملايين': 1000000,
  };

  /// Prefix words of the compound hundreds (300–900) × their suffix spellings, generated so every
  /// combination ("ثلاثمائة", "ثلاثمية", "تلتميه", "خمسمئة", ...) is covered without hand-typing.
  static final Map<String, double> _hundreds = () {
    const prefixes = <String, double>{
      'ثلاث': 300, 'ثلث': 300, 'تلت': 300, 'تلات': 300,
      'اربع': 400, 'ربع': 400,
      'خمس': 500,
      'ست': 600,
      'سبع': 700,
      'ثمان': 800, 'ثمن': 800, 'تمن': 800, 'ثماني': 800,
      'تسع': 900,
    };
    const suffixes = ['مائه', 'مئه', 'ميه', 'مايه'];
    final out = <String, double>{};
    prefixes.forEach((p, v) {
      for (final s in suffixes) {
        out['$p$s'] = v;
      }
    });
    return out;
  }();

  static const _currencyWords = <String>{
    'ريال', 'ريالا', 'ريالات', 'دولار', 'دولارا', 'درهم', 'دراهم', 'جنيه', 'دينار',
    'سعودي', 'يمني', 'محلي', 'usd', 'sar', 'yer', 'aed', 'egp', 'kwd',
  };

  /// REAL-DEVICE FINDING (Vosk mgb2, local mode): the model does not emit garbage for number
  /// words — it emits the most frequent short Arabic WORD that sounds similar. "خمسة"/"ألف"/
  /// "ومئتين" come out as "إلا" / "ألأ" / "ولا". These are perfectly valid Arabic, so the
  /// Latin/alef-only check in [isCorruptCandidate] can never see them, and the amount silently
  /// disappeared (or leaked into the account name). Normalised forms (alef variants unified).
  static const _numberNoiseWords = <String>{'الا', 'ولا', 'والا'};

  static final RegExp _digitsToken = RegExp(r'^\d+(\.\d+)?$');
  static final RegExp _latin = RegExp('[a-zA-Z]');

  static bool _isNumberLike(String w) {
    bool known(String x) => _units.containsKey(x) || _hundreds.containsKey(x) || _multipliers.containsKey(x);
    if (_digitsToken.hasMatch(w) || known(w) || _currencyWords.contains(w)) {
      return true;
    }
    return w.length > 1 && w.startsWith('و') && known(w.substring(1));
  }

  /// A noise word only counts when it sits RIGHT NEXT TO a number/currency word (or to another
  /// number token) — an ordinary "إلا"/"ولا" elsewhere in a sentence is left alone.
  static bool _touchesNumberContext(List<String> tokens, int i, _Tok? prev) {
    if (prev != null &&
        (prev.kind == _Kind.value ||
            prev.kind == _Kind.multiplier ||
            prev.kind == _Kind.hundredMultiplier ||
            prev.kind == _Kind.half ||
            prev.kind == _Kind.corrupt)) {
      return true;
    }
    return i + 1 < tokens.length && _isNumberLike(normalizeWord(tokens[i + 1]));
  }

  /// A token that is "number-shaped noise": Latin letters fused with alef/hamza ("أuأ", "وأu"),
  /// or just 1–3 bare alef/hamza letters ("أأ", "ا"). It is only ever treated as corrupt when it
  /// sits INSIDE a number phrase (see [extract]) — a name like "عبدالقدوسuoo" has real letters
  /// left after removing the Latin ones, so it never qualifies.
  static bool isCorruptCandidate(String raw) {
    var s = raw;
    if (s.length > 1 && s.startsWith('و')) {
      s = s.substring(1);
    }
    final stripped = s.replaceAll(_latin, '');
    if (stripped.isEmpty) return false; // pure Latin (e.g. "usd") or empty — not our business
    return RegExp(r'^[أإآاءؤئ]{1,3}$').hasMatch(stripped);
  }

  static _Tok _classify(List<String> tokens, int i, _Tok? prev) {
    final raw = tokens[i];
    final t = normalizeWord(raw);
    if (_digitsToken.hasMatch(t)) {
      return _Tok(_Kind.value, double.parse(t));
    }
    if (t == 'و') {
      return const _Tok(_Kind.connector);
    }

    _Tok? lookup(String w) {
      final u = _units[w];
      if (u != null) {
        return _Tok(_Kind.value, u);
      }
      final h = _hundreds[w];
      if (h != null) {
        return _Tok(_Kind.value, h);
      }
      final m = _multipliers[w];
      if (m != null) {
        return _Tok(_Kind.multiplier, m);
      }
      if (w == 'نصف' || w == 'نص') {
        return const _Tok(_Kind.half);
      }
      return null;
    }

    // "احد/اثنا/اثني" are numbers ONLY when followed by "عشر" (11, 12) — alone they are ordinary
    // words ("أحد").
    if (t == 'احد' || t == 'اثنا' || t == 'اثني') {
      final next = i + 1 < tokens.length ? normalizeWord(tokens[i + 1]) : '';
      if (next == 'عشر' || next == 'عشره') {
        return _Tok(_Kind.value, t == 'احد' ? 1 : 2);
      }
    }

    // Separate hundred word: a multiplier ONLY directly after a unit 3–9 ("ثلاث مية",
    // "خمس مئة"). Formal "مئة/مائة" alone is 100; bare colloquial "مية/ميه" alone is NOT a number
    // (it usually means "ماء").
    final afterUnit =
        prev != null && prev.kind == _Kind.value && prev.value >= 3 && prev.value <= 9;
    final formalHundred = t == 'مائه' || t == 'مئه';
    final bareHundred = t == 'ميه' || t == 'مايه' || t == 'وميه' || t == 'ومايه';
    if (afterUnit && (formalHundred || bareHundred)) {
      return const _Tok(_Kind.hundredMultiplier);
    }
    if (bareHundred) {
      return const _Tok(_Kind.other);
    }

    final direct = lookup(t);
    if (direct != null) {
      return direct;
    }
    if (t.length > 1 && t.startsWith('و')) {
      final stripped = lookup(t.substring(1));
      if (stripped != null) {
        return stripped;
      }
    }
    if (isCorruptCandidate(raw)) {
      return const _Tok(_Kind.corrupt);
    }
    if (_numberNoiseWords.contains(t) && _touchesNumberContext(tokens, i, prev)) {
      return const _Tok(_Kind.corrupt);
    }
    return const _Tok(_Kind.other);
  }

  /// Finds the amount phrase in [tokens] (raw recognizer tokens — Latin noise NOT yet removed).
  static AmountExtraction extract(List<String> tokens) {
    final toks = <_Tok>[];
    for (var i = 0; i < tokens.length; i++) {
      toks.add(_classify(tokens, i, toks.isEmpty ? null : toks.last));
    }

    bool inRun(_Kind k) => k != _Kind.other;
    final runs = <(int, int)>[];
    var i = 0;
    while (i < toks.length) {
      if (!inRun(toks[i].kind)) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < toks.length && inRun(toks[j + 1].kind)) {
        j++;
      }
      var s = i;
      var e = j;
      while (s <= e && toks[s].kind == _Kind.connector) {
        s++;
      }
      while (e >= s && toks[e].kind == _Kind.connector) {
        e--;
      }
      final kinds = [for (var k = s; k <= e; k++) toks[k].kind];
      final hasNumber = kinds.any((k) => k == _Kind.value || k == _Kind.multiplier);
      // A run made ONLY of noise still counts when it stands directly before a currency word
      // ("… عليه إلا ريال"): a number WAS spoken there, we just can't read it → uncertain.
      final nextWord = e + 1 < tokens.length ? normalizeWord(tokens[e + 1]) : '';
      final noiseBeforeCurrency = kinds.contains(_Kind.corrupt) && _currencyWords.contains(nextWord);
      if (s <= e && (hasNumber || noiseBeforeCurrency)) {
        runs.add((s, e));
      }
      i = j + 1;
    }
    if (runs.isEmpty) {
      return const AmountExtraction.none();
    }

    var chosen = runs.first;
    for (final r in runs) {
      final next = r.$2 + 1 < tokens.length ? normalizeWord(tokens[r.$2 + 1]) : '';
      if (_currencyWords.contains(next)) {
        chosen = r;
        break;
      }
    }

    var total = 0.0;
    var cur = 0.0;
    var lastUnit = 0.0;
    double? lastMultiplier;
    var uncertain = false;
    for (var k = chosen.$1; k <= chosen.$2; k++) {
      final t = toks[k];
      switch (t.kind) {
        case _Kind.corrupt:
          uncertain = true;
        case _Kind.value:
          cur += t.value;
          lastUnit = t.value;
        case _Kind.hundredMultiplier:
          cur += lastUnit * 99;
          lastUnit = 0;
        case _Kind.multiplier:
          total += (cur == 0 ? 1 : cur) * t.value;
          cur = 0;
          lastUnit = 0;
          lastMultiplier = t.value;
        case _Kind.half:
          if (cur == 0 && lastMultiplier != null) {
            total += lastMultiplier / 2;
          } else {
            cur += 0.5;
          }
        case _Kind.connector:
        case _Kind.other:
          break;
      }
    }
    if (uncertain) {
      return AmountExtraction(value: null, uncertain: true, startToken: chosen.$1, endToken: chosen.$2);
    }
    final value = total + cur;
    if (value <= 0) {
      return AmountExtraction(value: null, uncertain: false, startToken: chosen.$1, endToken: chosen.$2);
    }
    final bare = chosen.$1 == chosen.$2 && toks[chosen.$1].kind == _Kind.multiplier;
    return AmountExtraction(value: value, uncertain: false, startToken: chosen.$1, endToken: chosen.$2, bare: bare);
  }
}
