import '../../data/models/account.dart';

/// Pure, deterministic command parser. It has no plugin/UI dependency, which
/// makes it safe to test and replace only the STT service later.
///
/// EXTENSIBILITY: account-name and details extraction each try an ORDERED LIST of strategies
/// (see [_accountName] / [_details]) rather than a single rigid pattern. To recognize a new
/// phrasing, add a new anchor word/regex to the relevant strategy — the rest of the pipeline
/// (amount/currency/date/direction extraction, and every call site) never needs to change.
///
/// [direction] is intentionally nullable: if the speaker never said an explicit marker, the
/// caller must ask ("هل هذا له أم عليه؟") instead of silently guessing — silently defaulting to
/// "credit" here would produce a wrong transaction with no indication anything was assumed.
///
/// PRODUCTION-HARDENING PASS (this batch) — this parser previously failed on very ordinary,
/// clearly-spoken sentences. Concretely fixed here:
///
/// 1. [_stripMixedScriptNoise] — the offline recognizer occasionally fuses a couple of stray
///    Latin letters onto an otherwise-Arabic word (recognizer noise, e.g. "قدوسuoo"). Any token
///    mixing Arabic and Latin letters now has just the Latin letters removed before extraction
///    runs. A token that is PURELY Latin is left untouched (a possible future English command).
/// 2. Details anchors expanded with common Yemeni colloquial purpose-markers: "حق"/"علشان"/
///    "عشان"/"من اجل" — "حق ماء" ("for water") was previously not recognized at all and the
///    whole clause was silently dropped instead of being captured as the entry's details.
/// 3. The Arabic number-word dictionary now also covers the hundred-words 300–900 and
///    "ألفين"/"الفين" (2000). DELIBERATELY NOT added: a bare "مية"/"ميه" for 100 — in this app's
///    Yemeni-dialect context that word overwhelmingly means "ماء" (water) in casual speech
///    (exactly the word in the "حق ماء" example above); treating it as a number would silently
///    misfire on precisely the sentence this fix is meant to correct. The compound hundred-words
///    ("ثلاثمية", "خمسمية", ...) are unambiguous as whole tokens and are covered.
/// 4. A stated date (e.g. "2026-08-14") is excluded from the text handed to amount extraction —
///    otherwise a command that mentions the date BEFORE the amount could let the date's own
///    digits win the "first number in the sentence" race and get mistaken for the amount.
/// 5. Direction markers now cover common Yemeni colloquial phrasing on top of the formal له/عليه:
///    عليه side — "دين"، "عنده"، "تسلف"، "استلف"، "مديون"؛ له side — "سدد"، "سلّم"/"سلم"، "وصل"،
///    "رجع"/"ارجع" (see [_direction]'s own doc comment for why this stays exact-token matching).
/// 6. Currency recognition now covers all currencies this app actually supports (see
///    core/constants/currencies.dart: محلي/يمني/سعودي/إماراتي/مصري/كويتي/دولار), and explicitly
///    tells the two "nothing was said" and "something was said but we don't support it" cases
///    apart via [VoiceCommandDraft.currencyUnsupported] — previously an unsupported currency
///    (e.g. "يورو") silently fell back to the local default with no indication anything was
///    wrong, instead of asking the person to repeat a supported one. The silent default itself
///    is also fixed to store the app-wide `'LOCAL'` code (matching every manually-created
///    transaction) rather than the earlier literal Arabic word `'محلي'`, which never matched any
///    real currency code anywhere else in the app.
class VoiceCommandParser {
  const VoiceCommandParser();

  /// Matches an ISO-ish date like `2026-08-14` or `2026/08/14`, used in two places: extracting
  /// the actual date (see [_date]) and excluding that same substring before amount extraction
  /// runs (see class doc comment point 4) — kept as one shared pattern so the two can never
  /// silently drift out of sync with each other.
  static final RegExp _isoDatePattern = RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}');

  VoiceCommandDraft parse(String transcript, {DateTime? now}) {
    final normalized = _normalize(transcript);
    final words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    // See class doc comment point 4 — a stated date must never compete with the real amount for
    // "first number found in the sentence".
    final amountSearchText = normalized.replaceAll(_isoDatePattern, ' ');
    final amount = _amount(amountSearchText);
    final lower = normalized.toLowerCase();
    final direction = _direction(words);
    final (currencyCode, currencyUnsupported) = _currency(lower);
    final date = _date(lower, now ?? DateTime.now());
    final accountName = _accountName(normalized);
    final details = _details(normalized);
    return VoiceCommandDraft(
      transcript: transcript.trim(),
      accountName: accountName,
      amount: amount,
      currency: currencyCode,
      currencyUnsupported: currencyUnsupported,
      details: details,
      direction: direction,
      date: date,
      // Only one transaction type is modeled today — kept as an explicit field (not a bool)
      // so a future voice-created type (e.g. a standalone account with no first transaction)
      // has somewhere to go without changing every call site's shape.
      type: 'transaction',
    );
  }

  static String _normalize(String value) {
    final cleaned = value
        .replaceAll('،', ' ')
        .replaceAll('ـ', '') // tatweel/kashida — a purely cosmetic elongation glyph that
            // sometimes leaks into recognizer output and would otherwise split one word in two.
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .trim();
    return _stripMixedScriptNoise(cleaned);
  }

  /// See class doc comment point 1. Only tokens that mix Arabic AND Latin letters get their
  /// Latin letters stripped — a token that is entirely Latin is left exactly as-is.
  static String _stripMixedScriptNoise(String value) {
    final arabicPattern = RegExp(r'[\u0600-\u06FF]');
    final latinLetterPattern = RegExp('[a-zA-Z]');
    final cleanedTokens = <String>[];
    for (final token in value.split(' ')) {
      if (token.isEmpty) continue;
      final isMixedScript = arabicPattern.hasMatch(token) && latinLetterPattern.hasMatch(token);
      final cleaned = isMixedScript ? token.replaceAll(latinLetterPattern, '') : token;
      if (cleaned.isNotEmpty) cleanedTokens.add(cleaned);
    }
    return cleanedTokens.join(' ');
  }

  static double? _amount(String value) {
    final match = RegExp(r'(?<![\w.])(\d+(?:[.,]\d+)?)').firstMatch(value);
    if (match != null) return double.tryParse(match.group(1)!.replaceAll(',', '.'));
    return _arabicWordsAmount(value);
  }

  static double? _arabicWordsAmount(String value) {
    const units = <String, int>{
      'واحد': 1,
      'واحدة': 1,
      'اثنان': 2,
      'اثنين': 2,
      'اثنتان': 2,
      'ثلاثة': 3,
      'ثلاث': 3,
      'اربعة': 4,
      'أربعة': 4,
      'خمسة': 5,
      'ستة': 6,
      'سبعة': 7,
      'ثمانية': 8,
      'تسعة': 9,
      'عشرة': 10,
      'عشرين': 20,
      'ثلاثين': 30,
      'اربعين': 40,
      'أربعين': 40,
      'خمسين': 50,
      'ستين': 60,
      'سبعين': 70,
      'ثمانين': 80,
      'تسعين': 90,
      'مئة': 100,
      'مائة': 100,
      'مئتان': 200,
      'مائتان': 200,
      // Hundred-words 300–900 — previously missing entirely, silently dropping the amount for
      // any command that used one of these (see class doc comment point 3).
      'ثلاثمائة': 300,
      'ثلاثمية': 300,
      'اربعمائة': 400,
      'أربعمائة': 400,
      'اربعمية': 400,
      'أربعمية': 400,
      'خمسمائة': 500,
      'خمسمية': 500,
      'ستمائة': 600,
      'ستمية': 600,
      'سبعمائة': 700,
      'سبعمية': 700,
      'ثمانمائة': 800,
      'ثمانمية': 800,
      'تسعمائة': 900,
      'تسعمية': 900,
      // Deliberately NOT included: a bare 'مية'/'ميه' for 100 — see class doc comment point 3.
      'الفين': 2000,
      'ألفين': 2000,
    };
    var total = 0;
    var current = 0;
    var found = false;
    for (final raw in value.split(' ')) {
      final word = raw.replaceFirst(RegExp(r'^و'), '');
      if (word == 'الف' || word == 'ألف' || word == 'الاف' || word == 'آلاف') {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
        found = true;
      } else if (units.containsKey(word)) {
        current += units[word]!;
        found = true;
      }
    }
    return found ? (total + current).toDouble() : null;
  }

  /// Exact-word matching only — deliberately NOT `.contains()` on the raw string. A substring
  /// check would let "على" (on/against — a real debit marker) false-match inside completely
  /// unrelated words (e.g. "الأعلى"), and would also risk colliding with the NAME "علي" (a
  /// different word — ends with ي, not ى) if the two were ever compared as substrings instead of
  /// whole tokens. Returns `null` (never a silent default) when no explicit marker is present.
  ///
  /// Both sets now also cover common Yemeni colloquial phrasing for the same two ideas — see
  /// class doc comment point 5 — on top of the formal له/عليه pair.
  static AccountDirection? _direction(List<String> words) {
    const debitWords = {
      'عليه', 'على', 'مدين', 'debit', 'owe',
      'دين', 'عنده', 'تسلف', 'استلف', 'مديون',
    };
    const creditWords = {
      'له', 'دائن', 'credit',
      'سدد', 'سلم', 'سلّم', 'وصل', 'رجع', 'ارجع',
    };
    final tokens = words.map((w) => w.toLowerCase()).toSet();
    if (tokens.any(debitWords.contains)) return AccountDirection.debit;
    if (tokens.any(creditWords.contains)) return AccountDirection.credit;
    return null;
  }

  /// Resolves the spoken currency against the exact set this app supports (see
  /// core/constants/currencies.dart): محلي (LOCAL, the silent default) / يمني (YER) / سعودي
  /// (SAR) / إماراتي (AED) / مصري (EGP) / كويتي (KWD) / دولار (USD). Returns `(code,
  /// unsupported)` — `unsupported` is `true` only when the speaker clearly named a REAL currency
  /// that isn't one of these (see class doc comment point 6), so the caller can ask them to
  /// repeat a supported one instead of silently mis-recording the entry's currency.
  static (String code, bool unsupported) _currency(String value) {
    // Checked BEFORE the supported-currency checks below, since some of these share a substring
    // with a supported currency's own keyword (e.g. "ريال قطري" contains "ريال", which alone
    // would otherwise match the Yemeni Rial).
    const unsupportedMarkers = [
      'يورو', 'استرليني', 'جنيه استرليني', 'ين ياباني', 'روبية',
      'ريال قطري', 'ريال عماني', 'ريال بحريني', 'دولار كندي', 'دولار استرالي',
      'يوان', 'وون', 'ليرة',
    ];
    if (_containsAny(value, unsupportedMarkers)) return ('LOCAL', true);

    if (_containsAny(value, ['سعودي', 'sar'])) return ('SAR', false);
    if (_containsAny(value, ['درهم', 'اماراتي', 'إماراتي', 'aed'])) return ('AED', false);
    if (_containsAny(value, ['جنيه', 'مصري', 'egp'])) return ('EGP', false);
    if (_containsAny(value, ['دينار', 'كويتي', 'kwd'])) return ('KWD', false);
    if (_containsAny(value, ['دولار', 'usd', 'dollar'])) return ('USD', false);
    if (_containsAny(value, ['يمني', 'yer', 'ريال'])) return ('YER', false);
    // Nothing currency-related was said at all — the silent default, stored as the same
    // `'LOCAL'` code every manually-created transaction uses (see class doc comment point 6).
    return ('LOCAL', false);
  }

  static DateTime _date(String value, DateTime now) {
    if (_containsAny(value, ['غدا', 'tomorrow'])) return now.add(const Duration(days: 1));
    if (_containsAny(value, ['امس', 'أمس', 'yesterday'])) return now.subtract(const Duration(days: 1));
    final match = _isoDatePattern.firstMatch(value);
    if (match != null) {
      final parts = match.group(0)!.split(RegExp(r'[-/]'));
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      return DateTime(year, month, day);
    }
    return DateTime(now.year, now.month, now.day);
  }

  /// Words that legitimately end a name span wherever they appear next — either because they
  /// introduce the transaction's details, or because they're the amount that always follows the
  /// name directly in phrasings like "أضف على إبراهيم سعيد 3200 ريال" (no word separates the name
  /// from the number that follows it, so the digit itself must be a stop point). "حق"/"علشان"/
  /// "عشان" were added alongside the details anchors below — see class doc comment point 2.
  static const _nameBoundaryWords = 'تفاصيل|details|في|قيمة|مقابل|بخصوص|حق|علشان|عشان|عليه|له|مدين|دائن';

  /// Ordered strategies — the first one that produces a non-empty name wins. Add a new anchor
  /// word to strategy A, or a new leading-verb to strategy B, to recognize another phrasing.
  static String? _accountName(String value) {
    // Strategy A: an explicit anchor word sits right before the name, e.g. "...حساب محمد...",
    // "...على إبراهيم سعيد...". The name ends at the next boundary word OR the next digit
    // (whichever comes first) OR the end of the sentence.
    final anchored = RegExp(
      r'(?:حساب|account|الى|إلى|لـ|على|عن)\s+(.+?)(?=\s+\d|\s+(?:' + _nameBoundaryWords + r')|$)',
      caseSensitive: false,
    ).firstMatch(value);
    final anchoredName = _cleanName(anchored?.group(1));
    if (anchoredName != null) return anchoredName;

    // Strategy B: no anchor word at all — the name sits directly before the direction marker
    // itself, e.g. "إبراهيم سعيد عليه 3200 ريال". An optional leading command verb ("أضف"/"سجل")
    // is skipped so it's never swallowed into the captured name.
    final beforeDirection = RegExp(
      r'^(?:أضف|سجل|اضافة|أضافة|add|record)?\s*(.+?)\s+(?:عليه|له|مدين|دائن|debit|credit)\b',
      caseSensitive: false,
    ).firstMatch(value);
    return _cleanName(beforeDirection?.group(1));
  }

  static String? _cleanName(String? raw) {
    final name = raw?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  /// Whether [name] has at least two words (a first name and a last name) — the same rule the
  /// manual Add Account form enforces (see accountNameMustBeTwoWords / add_account_screen.dart's
  /// `_validateName`), applied here so a voice-created account can never end up with just a bare
  /// first name either. Exposed as a public static helper so voice_provider.dart's clarification
  /// loop can re-check it after every attempt without duplicating the word-splitting logic.
  static bool hasFullName(String name) =>
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 2;

  /// "حق"/"علشان"/"عشان"/"من اجل" now join "تفاصيل"/"مقابل"/etc. as recognized reason/purpose
  /// anchors — see class doc comment point 2. Each anchor is required to start at a real word
  /// boundary (string start or preceding whitespace) so e.g. "المستحق" or "حقيبة" can never
  /// false-match on the "حق" substring buried inside a longer, unrelated word.
  static String? _details(String value) {
    final match = RegExp(
      r'(?:^|\s)(?:تفاصيل|details|قيمة|بخصوص|حق|علشان|عشان|من\s+اجل|من\s+أجل|لـ?مقابل|مقابل)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(value);
    final details = match?.group(1)?.trim();
    return details == null || details.isEmpty ? null : details;
  }

  static bool _containsAny(String value, List<String> terms) => terms.any(value.contains);
}

class VoiceCommandDraft {
  const VoiceCommandDraft({
    required this.transcript,
    required this.accountName,
    required this.amount,
    required this.currency,
    required this.details,
    required this.direction,
    required this.date,
    required this.type,
    this.currencyUnsupported = false,
  });

  final String transcript;
  final String? accountName;
  final double? amount;

  /// A resolved currency CODE (e.g. `'LOCAL'`, `'YER'`, `'USD'`...) — matches the codes in
  /// core/constants/currencies.dart exactly, so this can be stored on a Transaction and
  /// displayed/looked-up identically to one created through the manual Add Transaction form.
  final String currency;

  /// `true` when the speaker named a real currency this app doesn't support (see
  /// VoiceCommandParser._currency's doc comment) — the caller must ask them to repeat a
  /// supported one rather than silently saving [currency]'s placeholder value.
  final bool currencyUnsupported;

  final String? details;

  /// `null` means the speaker never gave an explicit له/عليه (or equivalent) marker — the voice
  /// flow must ask for clarification rather than guessing (see VoiceController.selectDirection).
  final AccountDirection? direction;
  final DateTime date;
  final String type;

  /// Extended to cover every field the voice-confirmation "قل تعديلك" flow (and the amount/
  /// account/direction/currency clarification loop) can change — see
  /// VoiceController._tryParseEdit and VoiceController._finishClarificationListening, which
  /// build a new draft via this constructor whenever the person edits or clarifies a field by
  /// voice instead of confirming or cancelling outright.
  VoiceCommandDraft copyWith({
    AccountDirection? direction,
    double? amount,
    String? details,
    String? accountName,
    String? currency,
    bool? currencyUnsupported,
  }) =>
      VoiceCommandDraft(
        transcript: transcript,
        accountName: accountName ?? this.accountName,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        currencyUnsupported: currencyUnsupported ?? this.currencyUnsupported,
        details: details ?? this.details,
        direction: direction ?? this.direction,
        date: date,
        type: type,
      );
}
