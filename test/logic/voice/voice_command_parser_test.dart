import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/logic/voice/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = VoiceCommandParser();

  test('extracts an Arabic command into a transaction draft', () {
    final draft = parser.parse('سجل ٣٢٠٠ ريال يمني عليه حساب محمد تفاصيل دجاج في 2026-08-14');

    expect(draft.amount, 3200);
    expect(draft.currency, 'YER');
    expect(draft.direction, AccountDirection.debit);
    expect(draft.accountName, 'محمد');
    expect(draft.date, DateTime(2026, 8, 14));
  });

  test('defaults unknown currency and today date safely', () {
    final now = DateTime(2026, 8, 22);
    final draft = parser.parse('أضف 100 له حساب علي', now: now);

    expect(draft.amount, 100);
    expect(draft.currency, 'محلي');
    expect(draft.direction, AccountDirection.credit);
    expect(draft.date, now);
  });

  test('recognizes common Arabic amount words', () {
    final draft = parser.parse('سجل ثلاثة آلاف ومائتان عليه حساب علي');

    expect(draft.amount, 3200);
  });
}
