import 'arabic_number_parser.dart';

/// Cleans the raw text a Whisper model returns BEFORE it reaches the command parser.
///
/// Why this file exists: Vosk emitted bare, unpunctuated words, which is the only shape the
/// parsers were ever tested against. Whisper writes like a person: sentence punctuation
/// ("ريال." / "أحمد،"), bracketed sound annotations ("[موسيقى]"), digits instead of words, and —
/// its best-known failure — it INVENTS stock phrases on silence or near-silence ("اشتركوا في
/// القناة", "ترجمة نانسي قنقر", or an echo of the prompt it was given). In a finance app an invented
/// sentence must become "nothing was heard", never a parsed entry.
///
/// Pure Dart, no plugin dependency, so every rule here is unit-testable without a device.
class TranscriptCleaner {
  const TranscriptCleaner._();

  /// Normalised (see [_norm]) fragments Whisper is known to hallucinate on silence/noise. A text
  /// is dropped only when it is essentially JUST one of these (see [_maxExtraChars]) — a real
  /// sentence that happens to contain such words is left alone.
  static const _hallucinations = <String>[
    'اشتركوا في القناه',
    'اشترك في القناه',
    'لا تنسوا الاشتراك',
    'لا تنسو الاشتراك',
    'ترجمه نانسي قنقر',
    'شكرا للمشاهده',
    'شكرا لمشاهدتكم',
    'شكرا على المشاهده',
    'شكرا لكم على المشاهده',
    'نهايه الفيديو',
    'الي اللقاء في الفيديو القادم',
    'subtitles by',
    'amara.org',
    'thank you for watching',
    'thanks for watching',
  ];

  /// How many characters beyond the hallucinated phrase itself a text may have and still be
  /// treated as that hallucination (covers a stray leftover word or two).
  static const _maxExtraChars = 6;

  /// Characters that are protected while punctuation is stripped when they sit BETWEEN two digits:
  /// "5,000" / "2.5" / "2026-08-14" must survive, a sentence-final "." must not.
  static const _protected = <String, String>{
    '.': '',
    '٫': '',
    ',': '',
    '٬': '',
    '-': '',
    '/': '',
  };

  static const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const _easternIndic = '۰۱۲۳۴۵۶۷۸۹';

  static final RegExp _invisible = RegExp('[\\u200B-\\u200F\\u202A-\\u202E\\u2066-\\u2069\\uFEFF]');
  static final RegExp _bracketed = RegExp(r'[\[\(\{][^\]\)\}]*[\]\)\}]');
  static final RegExp _digitSeparator = RegExp(r'(?<=\d)([.,٫٬\-/])(?=\d)');
  static final RegExp _punctuation = RegExp(r'[.,٫٬،؛;:؟?!"«»“”‘’\x27…*_\-–—/\\|~`^<>=+(){}\[\]]');

  /// Returns the cleaned transcript, or `''` when the text is empty, a known hallucination, or an
  /// echo of [prompt] (the `initial_prompt` the recognizer was biased with).
  static String clean(String raw, {String prompt = ''}) {
    final text = _strip(raw);
    if (text.isEmpty) return '';

    final collapsed = _collapseLoops(text);
    final norm = _norm(collapsed);
    if (norm.isEmpty) return '';

    for (final phrase in _hallucinations) {
      if (norm.contains(phrase) && norm.length <= phrase.length + _maxExtraChars) return '';
    }

    final promptNorm = _norm(_strip(prompt));
    // Whisper echoes its prompt on silence. Only multi-word texts are compared: a genuine one-word
    // answer ("نعم", "حفظ") is also a substring of the prompt and must be kept.
    if (promptNorm.isNotEmpty && norm.split(' ').length >= 4 && promptNorm.contains(norm)) return '';

    return _fixKnownConfusions(collapsed);
  }

  /// Words the local model is known to produce INSTEAD of "ريال" right after an amount
  /// (real-device finding: "ألف ريال" heard as "ألف خيال"). Applied ONLY directly after a number
  /// word/digit, so an ordinary sentence containing "خيال" is never touched.
  static const _riyalLookalikes = {'خيال', 'ريا', 'ريل', 'ريان', 'رجال', 'ريالي'};

  static String _fixKnownConfusions(String text) {
    final tokens = text.split(' ');
    for (var i = 1; i < tokens.length; i++) {
      final n = _norm(tokens[i]);
      if (_riyalLookalikes.contains(n) && ArabicNumberParser.looksLikeNumberWord(tokens[i - 1])) {
        tokens[i] = 'ريال';
      }
    }
    return tokens.join(' ');
  }

  /// Digits → ASCII, annotations/punctuation/bidi marks removed (separators inside numbers kept),
  /// whitespace collapsed.
  static String _strip(String raw) {
    var s = raw.replaceAll(_invisible, '').replaceAll(_bracketed, ' ');
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(_arabicIndic[i], '$i').replaceAll(_easternIndic[i], '$i');
    }
    s = s.replaceAllMapped(_digitSeparator, (m) => _protected[m[1]!]!);
    s = s.replaceAll(_punctuation, ' ');
    _protected.forEach((original, placeholder) {
      // Both "." and "٫" map to one placeholder; restore it as the ASCII form the parser expects.
      if (original == '.' || original == ',' || original == '-' || original == '/') {
        s = s.replaceAll(placeholder, original);
      }
    });
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// A runaway loop ("نعم نعم نعم نعم نعم …") is Whisper repeating itself; four or more identical
  /// tokens in a row collapse to one. Two or three (a real "لا لا") are kept.
  static String _collapseLoops(String text) {
    final tokens = text.split(' ').where((t) => t.isNotEmpty).toList();
    final out = <String>[];
    var i = 0;
    while (i < tokens.length) {
      var j = i;
      while (j + 1 < tokens.length && tokens[j + 1] == tokens[i]) {
        j++;
      }
      final count = j - i + 1;
      if (count >= 4) {
        out.add(tokens[i]);
      } else {
        for (var k = 0; k < count; k++) {
          out.add(tokens[i]);
        }
      }
      i = j + 1;
    }
    return out.join(' ');
  }

  /// Comparison form: diacritics removed, alef variants unified, ة→ه, ى→ي, lower-case.
  static String _norm(String text) => ArabicNumberParser.normalizeWord(text).replaceAll(RegExp(r'\s+'), ' ').trim();
}
