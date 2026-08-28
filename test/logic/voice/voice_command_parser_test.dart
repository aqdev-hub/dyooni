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

  group('flexible phrasing (regression coverage for the official spec examples)', () {
    test('"على" is an explicit debit marker, distinct from the name "علي"', () {
      final draft = parser.parse('أضف على إبراهيم سعيد 3200 ريال قيمة دجاجة');

      expect(draft.amount, 3200);
      expect(draft.currency, 'YER');
      expect(draft.direction, AccountDirection.debit);
      expect(draft.accountName, 'إبراهيم سعيد');
      expect(draft.details, 'دجاجة');
    });

    test('the account name stops at the amount digit when no boundary word follows it', () {
      final draft = parser.parse('سجل على إبراهيم سعيد 3200 ريال دجاج');

      expect(draft.accountName, 'إبراهيم سعيد');
      expect(draft.direction, AccountDirection.debit);
      // Honest limitation: "دجاج" has no recognized details anchor word before it here (no
      // "تفاصيل"/"قيمة"/"مقابل"), so it is correctly left unextracted rather than guessed at.
      expect(draft.details, isNull);
    });

    test('the account name is captured BEFORE the direction word when there is no anchor at all', () {
      final draft = parser.parse('إبراهيم سعيد عليه 3200 ريال دجاج');

      expect(draft.accountName, 'إبراهيم سعيد');
      expect(draft.direction, AccountDirection.debit);
      expect(draft.amount, 3200);
    });

    test('a bare "مقابل" (not just "لمقابل") is recognized as a details anchor', () {
      final draft = parser.parse('أضف له 3200 ريال مقابل دجاج');

      expect(draft.amount, 3200);
      expect(draft.direction, AccountDirection.credit);
      expect(draft.details, 'دجاج');
      // The sentence genuinely never names an account — correctly surfaces as unresolved so the
      // caller can prompt for clarification instead of guessing one.
      expect(draft.accountName, isNull);
    });

    test('direction is null (never silently defaulted) when no له/عليه marker is spoken at all', () {
      final draft = parser.parse('سجل 500 ريال لحساب أحمد تفاصيل غداء');

      expect(draft.direction, isNull);
      expect(draft.accountName, 'أحمد');
      expect(draft.amount, 500);
    });
  });

  group('VoiceCommandDraft.copyWith', () {
    test('replaces only the direction, leaving every other field untouched', () {
      final draft = parser.parse('سجل 500 ريال لحساب أحمد تفاصيل غداء');
      final resolved = draft.copyWith(direction: AccountDirection.debit);

      expect(resolved.direction, AccountDirection.debit);
      expect(resolved.amount, draft.amount);
      expect(resolved.accountName, draft.accountName);
      expect(resolved.details, draft.details);
      expect(resolved.transcript, draft.transcript);
    });
  });
}
