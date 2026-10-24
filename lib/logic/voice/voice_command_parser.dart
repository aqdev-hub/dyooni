import '../../data/models/account.dart';
import 'arabic_number_parser.dart';

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

  /// Public so the dialogue (amount clarification / amount edit) can parse a bare amount phrase
  /// such as "خمسة ألف وخمسمائة" with the exact same engine used for full commands.
  AmountExtraction parseAmount(String text) {
    final prepared = _prepare(text).replaceAll(_isoDatePattern, ' ');
    return ArabicNumberParser.extract(_tokens(prepared));
  }

  VoiceCommandDraft parse(String transcript, {DateTime? now}) {
    final prepared = _prepare(transcript);
    // A stated date must never compete with the real amount (class doc point 4), nor leak into
    // the name/details — so it is cut out of the text before tokenizing.
    final withoutDate = prepared.replaceAll(_isoDatePattern, ' ');
    final rawTokens = _tokens(withoutDate);
    final extraction = ArabicNumberParser.extract(rawTokens);

    // Latin-noise stripping happens only AFTER the number phrase was located, so the engine can
    // still see (and refuse to trust) a garbled number such as "أuأ ألف".
    final cleanTokens = [for (final t in rawTokens) _stripMixedScriptNoise(t)];
    final cleanedText = cleanTokens.where((t) => t.isNotEmpty).join(' ');

    final lower = cleanedText.toLowerCase();
    final direction = _direction(cleanTokens.where((t) => t.isNotEmpty).toList());
    final (currencyCode, currencyUnsupported) = _currency(lower);
    final date = _date(prepared.toLowerCase(), now ?? DateTime.now());
    final accountName = _accountName(cleanTokens, extraction);
    final details = _details(cleanedText);
    return VoiceCommandDraft(
      transcript: transcript.trim(),
      accountName: accountName,
      amount: extraction.value,
      amountUncertain: extraction.uncertain,
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

  /// Direction (له/عليه and colloquial equivalents) found in a short spoken answer, or `null`.
  /// Exact-token matching — see [_direction].
  AccountDirection? parseDirection(String text) =>
      _direction(_tokens(_prepare(text)).map(_stripMixedScriptNoise).where((t) => t.isNotEmpty).toList());

  static List<String> _tokens(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Cosmetic clean-up that must happen BEFORE tokenizing: Arabic-Indic digits → ASCII, Arabic
  /// decimal/thousands marks, thousands commas ("3,200" is 3200, not 3.2), and a space between
  /// digits and letters ("3200ريال" → "3200 ريال").
  static String _prepare(String value) {
    var s = value
        .replaceAll('،', ' ')
        .replaceAll('ـ', '') // tatweel — would otherwise split one word in two.
        .replaceAll('٫', '.')
        .replaceAll('٬', ',');
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < arabicIndic.length; i++) {
      s = s.replaceAll(arabicIndic[i], '$i');
    }
    s = s
        .replaceAllMapped(RegExp(r'(?<=\d),(?=\d{3}(?!\d))'), (_) => '')
        .replaceAllMapped(RegExp(r'(?<=\d),(?=\d)'), (_) => '.')
        .replaceAllMapped(RegExp(r'(\d)([\u0600-\u06FF])'), (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'([\u0600-\u06FF])(\d)'), (m) => '${m[1]} ${m[2]}');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Only tokens that mix Arabic AND Latin letters get their Latin letters stripped — a token
  /// that is entirely Latin is left exactly as-is. Returns '' when nothing is left.
  static String _stripMixedScriptNoise(String token) {
    final arabicPattern = RegExp(r'[\u0600-\u06FF]');
    final latinLetterPattern = RegExp('[a-zA-Z]');
    final isMixedScript = arabicPattern.hasMatch(token) && latinLetterPattern.hasMatch(token);
    return isMixedScript ? token.replaceAll(latinLetterPattern, '') : token;
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

  /// Comparison key for structural words: diacritics/tatweel removed and alef variants unified —
  /// but NOT ى→ي and NOT ة→ه, because "على" (against) and "علي" (a very common NAME) must never
  /// collapse into one word.
  static String _key(String token) {
    final b = StringBuffer();
    for (final unit in token.runes) {
      if ((unit >= 0x064B && unit <= 0x0652) || unit == 0x0670 || unit == 0x0640) continue;
      final ch = String.fromCharCode(unit);
      b.write(const {'أ': 'ا', 'إ': 'ا', 'آ': 'ا'}[ch] ?? ch.toLowerCase());
    }
    return b.toString();
  }

  /// Words that can sit right before a name as an "anchor" ("على إبراهيم سعيد", "لحساب سالم").
  static const _anchorWords = {
    'حساب', 'لحساب', 'الحساب', 'للحساب', 'account', 'الى', 'ل', 'على', 'عن',
  };

  /// Command verbs / polite filler that may open a sentence and must never become part of a name.
  static const _leadingSkipWords = {
    'سجل', 'اضف', 'ضيف', 'اضافه', 'قيد', 'اكتب', 'add', 'record', 'لو', 'سمحت', 'لي', 'من',
    'فضلك', 'ممكن', 'اريد', 'ابغى', 'ابي', 'عايز', 'بدي', 'يا', 'هل', 'حساب', 'لحساب', 'الحساب',
    'للحساب', 'account', 'الى', 'ل',
  };

  /// Words that END a name wherever they appear — fillers the speaker (or recognizer) inserts
  /// ("يعني"), details anchors, direction markers, currency words, date words. Spoken-number
  /// words end it too (handled separately via the amount phrase marker).
  static const _nameStopWords = {
    'يعني', 'هو', 'اللي', 'الذي', 'وهو', 'هذا', 'ده', 'كذا', 'فقط', 'بس', 'مبلغ', 'مبلغا',
    'بمبلغ', 'وقدره', 'قدره', 'بقيمه', 'بقيمة', 'بتاريخ', 'امس', 'غدا', 'اليوم',
    'تفاصيل', 'details', 'في', 'قيمة', 'قيمه', 'مقابل', 'بخصوص', 'حق', 'علشان', 'عشان',
    'عليه', 'له', 'مدين', 'دائن', 'على', 'debit', 'credit', 'owe', 'دين', 'عنده', 'تسلف',
    'استلف', 'مديون', 'سدد', 'سلم', 'وصل', 'رجع', 'ارجع',
    'ريال', 'ريالا', 'ريالات', 'دولار', 'درهم', 'جنيه', 'دينار', 'سعودي', 'يمني', 'محلي',
    'اماراتي', 'مصري', 'كويتي',
  };

  static const _maxNameWords = 4;

  /// Token-based name extraction. The tokens that belong to the amount phrase are replaced by a
  /// stop marker first, so a spoken number can NEVER be swallowed into the name (the old regex
  /// `.+?` happily absorbed "خمسة" / "ألف" / "يعني" into it).
  ///
  /// Ordered strategies — the first that yields a non-empty name wins:
  ///   A. explicit anchor word before the name ("على إبراهيم سعيد", "لحساب سالم");
  ///   B1. the leading words of the sentence, up to the first stop word
  ///       ("عبدالقدوس محمد عليه خمسة ألف");
  ///   B2. the words right after the direction marker ("عليه عبدالقدوس محمد خمسة ألف").
  static String? _accountName(List<String> tokens, AmountExtraction amount) {
    final keys = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final inAmount = amount.found && i >= amount.startToken && i <= amount.endToken;
      keys.add(inAmount || tokens[i].isEmpty ? '§' : _key(tokens[i]));
    }
    bool isStop(String k) =>
        k == '§' || _nameStopWords.contains(k) || RegExp(r'\d').hasMatch(k);

    String? collect(int from) {
      var i = from;
      while (i < keys.length && _leadingSkipWords.contains(keys[i]) && !isStop(keys[i])) {
        i++;
      }
      final words = <String>[];
      while (i < keys.length && !isStop(keys[i]) && words.length < _maxNameWords) {
        words.add(tokens[i]);
        i++;
      }
      return words.isEmpty ? null : words.join(' ');
    }

    for (var i = 0; i < keys.length; i++) {
      if (_anchorWords.contains(keys[i])) {
        final name = collect(i + 1);
        if (name != null) return name;
      }
    }
    final leading = collect(0);
    if (leading != null) return leading;

    const directionKeys = {
      'عليه', 'له', 'مدين', 'دائن', 'على', 'debit', 'credit', 'دين', 'عنده', 'تسلف', 'استلف',
      'مديون', 'سدد', 'سلم', 'وصل', 'رجع', 'ارجع',
    };
    for (var i = 0; i < keys.length; i++) {
      if (directionKeys.contains(keys[i])) return collect(i + 1);
    }
    return null;
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
    final details = match?.group(1)?.trim().replaceFirst(RegExp(r'\s+(?:في|بتاريخ)$'), '').trim();
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
    this.amountUncertain = false,
  });

  final String transcript;
  final String? accountName;
  final double? amount;

  /// `true` when an amount WAS spoken but the recognizer garbled it (e.g. "أuأ ألف"), so
  /// [amount] is deliberately `null` and the dialogue must ask for it again — never guess.
  final bool amountUncertain;

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

  /// Same draft with the amount cleared and flagged uncertain (the dialogue then asks for it).
  VoiceCommandDraft withUncertainAmount() => VoiceCommandDraft(
        transcript: transcript,
        accountName: accountName,
        amount: null,
        amountUncertain: true,
        currency: currency,
        currencyUnsupported: currencyUnsupported,
        details: details,
        direction: direction,
        date: date,
        type: type,
      );

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
    bool? amountUncertain,
    DateTime? date,
  }) =>
      VoiceCommandDraft(
        transcript: transcript,
        accountName: accountName ?? this.accountName,
        amount: amount ?? this.amount,
        amountUncertain: amount != null ? false : (amountUncertain ?? this.amountUncertain),
        currency: currency ?? this.currency,
        currencyUnsupported: currencyUnsupported ?? this.currencyUnsupported,
        details: details ?? this.details,
        direction: direction ?? this.direction,
        date: date ?? this.date,
        type: type,
      );
}
