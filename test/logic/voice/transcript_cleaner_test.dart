import 'package:dyooni/logic/voice/transcript_cleaner.dart';
import 'package:dyooni/logic/voice/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const prompt = 'دين لفلان عليه خمسة آلاف ريال. سدد ثلاثة آلاف وخمسمائة ريال. نعم، حفظ، تعديل، إلغاء.';
  String clean(String raw) => TranscriptCleaner.clean(raw, prompt: prompt);

  group('punctuation and formatting', () {
    test('sentence punctuation is removed', () {
      expect(clean('دفعت خمسة آلاف ريال لأحمد.'), 'دفعت خمسة آلاف ريال لأحمد');
      expect(clean('عليه، خمسة آلاف ريال!'), 'عليه خمسة آلاف ريال');
    });

    test('Arabic-Indic digits become ASCII and number separators survive', () {
      expect(clean('عليه ٥,٠٠٠ ريال، لمحمد!'), 'عليه 5,000 ريال لمحمد');
      expect(clean('بتاريخ 2026-08-14 عليه 2.5 دولار'), 'بتاريخ 2026-08-14 عليه 2.5 دولار');
    });

    test('bracketed annotations and bidi marks are removed', () {
      expect(clean('[موسيقى] نعم'), 'نعم');
      expect(clean('‏نعم‏'), 'نعم');
    });

    test('empty and whitespace-only input yields empty', () {
      expect(clean(''), '');
      expect(clean('   '), '');
      expect(clean('...'), '');
    });
  });

  group('hallucination defence', () {
    test('known stock phrases on silence are dropped', () {
      expect(clean('اشتركوا في القناة.'), '');
      expect(clean('ترجمة نانسي قنقر'), '');
      expect(clean('شكرا للمشاهدة'), '');
    });

    test('a real sentence that merely contains such words is kept', () {
      expect(clean('شكرا للمشاهدة. ريال خمسة'), 'شكرا للمشاهدة ريال خمسة');
    });

    test('an echo of the prompt is dropped', () {
      expect(clean('نعم، حفظ، تعديل، إلغاء.'), '');
    });

    test('one-word answers that also occur in the prompt are kept', () {
      expect(clean('حفظ.'), 'حفظ');
      expect(clean('نعم'), 'نعم');
    });

    test('runaway repetition collapses; a genuine double is kept', () {
      expect(clean('شكرا شكرا شكرا شكرا شكرا شكرا'), 'شكرا');
      expect(clean('لا لا'), 'لا لا');
    });
  });

  group('cleaned Whisper output reaches the amount parser correctly', () {
    const parser = VoiceCommandParser();
    double? amountOf(String raw) => parser.parseAmount(clean(raw)).value;

    test('spelled-out amounts with punctuation', () {
      expect(amountOf('عبدالقدوس عليه خمسة آلاف ومئتين ريال.'), 5200);
      expect(amountOf('له ثلاثة آلاف وخمسمائة ريال،'), 3500);
    });

    test('digit amounts, with and without thousands separators', () {
      expect(amountOf('عليه 5000 ريال.'), 5000);
      expect(amountOf('عليه ٥,٠٠٠ ريال'), 5000);
      expect(amountOf('عليه 5 آلاف ريال'), 5000);
    });
  });

  group('known confusions after an amount', () {
    test('خيال right after a number becomes ريال', () {
      expect(clean('احمد عليه خمسة الاف خيال'), 'احمد عليه خمسة الاف ريال');
      expect(clean('عليه 3000 خيال'), 'عليه 3000 ريال');
    });
    test('خيال in an ordinary sentence is untouched', () {
      expect(clean('هذا خيال علمي'), 'هذا خيال علمي');
    });
  });
}
