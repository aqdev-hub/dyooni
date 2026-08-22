import '../../data/models/account.dart';

/// Pure, deterministic command parser. It has no plugin/UI dependency, which
/// makes it safe to test and replace only the STT service later.
class VoiceCommandParser {
  const VoiceCommandParser();

  VoiceCommandDraft parse(String transcript, {DateTime? now}) {
    final normalized = _normalize(transcript);
    final amount = _amount(normalized);
    final lower = normalized.toLowerCase();
    final direction = _containsAny(lower, ['عليه', 'مدين', 'debit', 'owe'])
        ? AccountDirection.debit
        : AccountDirection.credit;
    final currency = _currency(lower);
    final date = _date(lower, now ?? DateTime.now());
    final accountName = _accountName(normalized);
    final details = _details(normalized);
    final type = _containsAny(lower, ['عملية', 'دفعة', 'سداد', 'payment', 'entry']) ? 'transaction' : 'transaction';
    return VoiceCommandDraft(
      transcript: transcript.trim(),
      accountName: accountName,
      amount: amount,
      currency: currency,
      details: details,
      direction: direction,
      date: date,
      type: type,
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
      .replaceAll('٩', '9');

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

  static String? _accountName(String value) {
    final match = RegExp(
      r'(?:حساب|account|الى|إلى|لـ)\s+(.+?)(?=\s+(?:تفاصيل|details|في)|$)',
      caseSensitive: false,
    ).firstMatch(value);
    final name = match?.group(1)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  static String? _details(String value) {
    final match = RegExp(r'(?:تفاصيل|لـ?مقابل|details)\s+(.+)', caseSensitive: false).firstMatch(value);
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
  final AccountDirection direction;
  final DateTime date;
  final String type;
}
