import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/logic/voice/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = VoiceCommandParser();

  double? amountOf(String text) => parser.parseAmount(text).value;

  group('spoken Arabic amounts', () {
    test('the reported sentence: خمسة ألف ومئتين = 5200 (not 1000)', () {
      final draft = parser.parse('عبدالقدوس محمد عليه خمسة ألف ومئتين ريال');

      expect(draft.amount, 5200);
      expect(draft.accountName, 'عبدالقدوس محمد');
      expect(draft.direction, AccountDirection.debit);
    });

    test('thousands, hundreds and tens combine by Arabic grammar', () {
      expect(amountOf('خمسة آلاف وخمسين ريال'), 5050);
      expect(amountOf('ثلاثة آلاف وخمسمائة'), 3500);
      expect(amountOf('ألفين وخمسمائة ريال'), 2500);
      expect(amountOf('عشرين ألف'), 20000);
      expect(amountOf('مئتين وخمسين'), 250);
      expect(amountOf('ثلاث مية ألف'), 300000);
      expect(amountOf('خمس مئة'), 500);
      expect(amountOf('احد عشر ألف'), 11000);
      expect(amountOf('خمسة عشر ريال'), 15);
    });

    test('colloquial halves and millions', () {
      expect(amountOf('ألف ونصف'), 1500);
      expect(amountOf('خمسة ألف ونص'), 5500);
      expect(amountOf('مليون ونصف'), 1500000);
    });

    test('a plain "ألف" is 1000, and bare "مية" (water) is never a number', () {
      expect(amountOf('ألف ريال'), 1000);
      expect(amountOf('حق مية'), isNull);
    });

    test('digits: thousands commas, Arabic-Indic digits and digits fused to a word', () {
      expect(amountOf('3,200 ريال'), 3200);
      expect(amountOf('٣٢٠٠ ريال'), 3200);
      expect(amountOf('3200ريال'), 3200);
      expect(amountOf('5 ألف'), 5000);
    });

    test('only ONE number phrase is evaluated — the one next to the currency', () {
      final draft = parser.parse('أضف على أحمد سالم خمسة ألف ريال حق ثلاثة كيلو');

      expect(draft.amount, 5000);
    });
  });

  group('garbled numbers are NEVER guessed (root cause of the 1000 bug)', () {
    test('"أuأ ألف وأu ريال" → amount unknown + flagged, not 1000', () {
      final draft = parser.parse('عبدالقدوس محمد عليه أuأ ألف وأu ريال');

      expect(draft.amount, isNull);
      expect(draft.amountUncertain, isTrue);
      expect(draft.accountName, 'عبدالقدوس محمد');
      expect(draft.direction, AccountDirection.debit);
    });

    test('a bare alef before "ألف" is treated as garbage too', () {
      expect(parser.parse('سالم أحمد له أأ ألف').amountUncertain, isTrue);
    });

    test('Latin noise fused onto a NAME is still just stripped', () {
      final draft = parser.parse('عبدالقدوسuoo محمد عليه الف ريال حق ماء');

      expect(draft.accountName, 'عبدالقدوس محمد');
      expect(draft.amount, 1000);
      expect(draft.amountUncertain, isFalse);
      expect(draft.details, 'ماء');
    });

    test('copyWith(amount) clears the uncertain flag', () {
      final draft = parser.parse('محمد علي عليه أuأ ألف');

      expect(draft.copyWith(amount: 5200).amountUncertain, isFalse);
    });
  });

  group('name extraction never swallows numbers or filler', () {
    test('filler "يعني" and a garbled number end the name', () {
      final draft = parser.parse('القدوس محمد يعني أuأ ألف');

      expect(draft.accountName, 'القدوس محمد');
      expect(draft.amount, isNull);
      expect(draft.direction, isNull);
    });

    test('spoken-number words end the name', () {
      expect(parser.parse('أحمد علي على خمسة ألف').accountName, 'أحمد علي');
    });

    test('polite opening words are skipped', () {
      expect(parser.parse('لو سمحت سجل عبدالقدوس محمد عليه خمسة ألف').accountName, 'عبدالقدوس محمد');
    });

    test('name after the direction marker', () {
      expect(parser.parse('عليه عبدالقدوس محمد خمسة ألف').accountName, 'عبدالقدوس محمد');
    });

    test('the NAME "علي" is never confused with the word "على"', () {
      final draft = parser.parse('أضف 100 له حساب علي');

      expect(draft.accountName, 'علي');
      expect(draft.direction, AccountDirection.credit);
    });
  });

  group('parseDirection', () {
    test('له / عليه and colloquial equivalents', () {
      expect(parser.parseDirection('عليه'), AccountDirection.debit);
      expect(parser.parseDirection('له'), AccountDirection.credit);
      expect(parser.parseDirection('خله عليه'), AccountDirection.debit);
      expect(parser.parseDirection('علي'), isNull);
    });
  });

  group('number words mis-heard as ordinary Arabic words (Vosk mgb2)', () {
    test('"إلا" right before the currency is an uncertain amount, never ignored', () {
      final draft = parser.parse('أحمد عليه إلأ ريال');

      expect(draft.amount, isNull);
      expect(draft.amountUncertain, isTrue);
      expect(draft.accountName, 'أحمد');
    });

    test('noise next to a multiplier makes the whole phrase uncertain (no silent 1000)', () {
      final draft = parser.parse('عبدالقدوس محمد عليه إلا ألف ريال');

      expect(draft.amount, isNull);
      expect(draft.amountUncertain, isTrue);
    });

    test('an ordinary "إلا" away from numbers is left alone', () {
      final draft = parser.parse('أحمد علي عليه ألف ريال إلا شيئا');

      expect(draft.amount, 1000);
      expect(draft.amountUncertain, isFalse);
    });
  });

  group('bare multiplier', () {
    test('"ألف" alone is flagged bare; a full phrase is not', () {
      expect(parser.parseAmount('أحمد عليه ألف ريال').bare, isTrue);
      expect(parser.parseAmount('أحمد عليه خمسة ألف ريال').bare, isFalse);
    });

    test('withUncertainAmount clears the amount and asks for it again', () {
      final draft = parser.parse('أحمد عليه ألف ريال').withUncertainAmount();

      expect(draft.amount, isNull);
      expect(draft.amountUncertain, isTrue);
      expect(draft.accountName, 'أحمد');
    });
  });
}
