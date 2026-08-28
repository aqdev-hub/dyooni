import '../../data/models/account.dart';

/// Pure, deterministic command parser. It has no plugin/UI dependency, which
/// makes it safe to test and replace only the STT service later.
///
/// EXTENSIBILITY: account-name and details extraction each try an ORDERED LIST of strategies
/// (see [_accountName] / [_details]) rather than a single rigid pattern. To recognize a new
/// phrasing, add a new anchor word/regex to the relevant strategy — the rest of the pipeline
/// (amount/currency/date/direction extraction, and every call site) never needs to change.
///
/// [direction] is intentionally nullable: if the speaker never said an explicit marker (له /
/// عليه / على / مدين / دائن / credit / debit), the caller must ask ("هل هذا له أم عليه؟") instead
/// of silently guessing — silently defaulting to "credit" here would produce a wrong transaction
/// with no indication anything was assumed.
class VoiceCommandParser {
  const VoiceCommandParser();

  VoiceCommandDraft parse(String transcript, {DateTime? now}) {
    final normalized = _normalize(transcript);
    final words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final amount = _amount(normalized);
    final lower = normalized.toLowerCase();
    final direction = _direction(words);
    final currency = _currency(lower);
    final date = _date(lower, now ?? DateTime.now());
    final accountName = _accountName(normalized);
    final details = _details(normalized);
    return VoiceCommandDraft(
      transcript: transcript.trim(),
      accountName: accountName,
      amount: amount,
      currency: currency,
      details: details,
      direction: direction,
      date: date,
      // Only one transaction type is modeled today — kept as an explicit field (not a bool)
      // so a future voice-created type (e.g. a standalone account with no first transaction)
      // has somewhere to go without changing every call site's shape.
      type: 'transaction',
    );
  }

  static String _normalize(String value) => value
      .replaceAll('،', ' ')
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
  static AccountDirection? _direction(List<String> words) {
    const debitWords = {'عليه', 'على', 'مدين', 'debit', 'owe'};
    const creditWords = {'له', 'دائن', 'credit'};
    final tokens = words.map((w) => w.toLowerCase()).toSet();
    if (tokens.any(debitWords.contains)) return AccountDirection.debit;
    if (tokens.any(creditWords.contains)) return AccountDirection.credit;
    return null;
  }

  static String _currency(String value) {
    if (_containsAny(value, ['دولار', 'usd', 'dollar'])) return 'USD';
    if (_containsAny(value, ['سعودي', 'sar'])) return 'SAR';
    if (_containsAny(value, ['درهم', 'aed'])) return 'AED';
    if (_containsAny(value, ['يمني', 'yer', 'ريال'])) return 'YER';
    return 'محلي';
  }

  static DateTime _date(String value, DateTime now) {
    if (_containsAny(value, ['غدا', 'tomorrow'])) return now.add(const Duration(days: 1));
    if (_containsAny(value, ['امس', 'أمس', 'yesterday'])) return now.subtract(const Duration(days: 1));
    final match = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(value);
    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    }
    return DateTime(now.year, now.month, now.day);
  }

  /// Words that legitimately end a name span wherever they appear next — either because they
  /// introduce the transaction's details, or because they're the amount that always follows the
  /// name directly in phrasings like "أضف على إبراهيم سعيد 3200 ريال" (no word separates the name
  /// from the number that follows it, so the digit itself must be a stop point).
  static const _nameBoundaryWords = 'تفاصيل|details|في|قيمة|مقابل|بخصوص|عليه|له|مدين|دائن';

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

  static String? _details(String value) {
    final match = RegExp(
      r'(?:تفاصيل|details|قيمة|بخصوص|لـ?مقابل|مقابل)\s+(.+)',
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
  });

  final String transcript;
  final String? accountName;
  final double? amount;
  final String currency;
  final String? details;

  /// `null` means the speaker never gave an explicit له/عليه (or equivalent) marker — the voice
  /// flow must ask for clarification rather than guessing (see VoiceController.selectDirection).
  final AccountDirection? direction;
  final DateTime date;
  final String type;

  VoiceCommandDraft copyWith({AccountDirection? direction}) => VoiceCommandDraft(
        transcript: transcript,
        accountName: accountName,
        amount: amount,
        currency: currency,
        details: details,
        direction: direction ?? this.direction,
        date: date,
        type: type,
      );
}
