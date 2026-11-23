import 'package:dyooni/logic/voice/wake_word_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WakeWordMatcher', () {
    test('accepts the wake word and its usual slips', () {
      for (final heard in ['ديوني', 'ديوني.', 'يا ديوني', 'ديني', 'دوني', 'ديون', 'دي وني', 'ديونى']) {
        expect(WakeWordMatcher.matches(heard), isTrue, reason: heard);
      }
    });

    test('hears it inside a sentence, glued, or after a wrong word', () {
      for (final heard in [
        'ياديوني سجل لي',
        'عيوني ديوني',
        'نعم لا ديوني احمد',
        'ديوني اضف عملية',
        'اه ديوني',
        'دي وني احمد',
        'قل ديوني الان',
        'ديونيي',
      ]) {
        expect(WakeWordMatcher.matches(heard), isTrue, reason: heard);
      }
    });

    test('rejects ordinary speech', () {
      for (final heard in ['', 'نعم', 'احمد عليه الف ريال', 'مرحبا', 'حفظ', 'ديوان', 'محمد عليه خمسة الاف ريال يمني']) {
        expect(WakeWordMatcher.matches(heard), isFalse, reason: heard);
      }
    });
  });
}
