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

  test('defaults to the LOCAL currency code (never a raw Arabic word) when nothing is said', () {
    // FIX: this used to assert the literal string 'محلي' — which never matched the 'LOCAL' code
    // every manually-created transaction uses (see core/constants/currencies.dart), so a
    // voice-created entry with no stated currency displayed/behaved inconsistently with one
    // created through the manual Add Transaction form. See VoiceCommandParser's class doc
    // comment, point 6.
    final now = DateTime(2026, 8, 22);
    final draft = parser.parse('أضف 100 له حساب علي', now: now);

    expect(draft.amount, 100);
    expect(draft.currency, 'LOCAL');
    expect(draft.currencyUnsupported, isFalse);
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

  group('production-hardening fixes (the reported "عبدالقدوس محمد عليه ألف ريال حق ماء" bug)', () {
    test('strips stray Latin-letter noise fused onto Arabic words by the recognizer', () {
      final draft = parser.parse('عبدالقدوسuoo محمد عليه الف ريال حق ماء');

      expect(draft.accountName, 'عبدالقدوس محمد');
      expect(draft.amount, 1000);
      expect(draft.direction, AccountDirection.debit);
      expect(draft.currency, 'YER');
      expect(draft.details, 'ماء');
    });

    test('"حق" is recognized as a details/purpose anchor, alongside "علشان" and "عشان"', () {
      expect(parser.parse('سجل على أحمد محمد 500 ريال حق كهرباء').details, 'كهرباء');
      expect(parser.parse('سجل على أحمد محمد 500 ريال علشان مشتريات').details, 'مشتريات');
      expect(parser.parse('سجل على أحمد محمد 500 ريال عشان غداء').details, 'غداء');
    });

    test('"حق" never false-matches a substring buried inside an unrelated word', () {
      // "المستحق" contains the letters ح-ق-ـ but is not the standalone anchor word "حق" — must
      // not be mistaken for one and swallow the rest of the sentence as "details".
      final draft = parser.parse('سجل على أحمد محمد 500 ريال المستحق دفعه اليوم');

      expect(draft.details, isNot('دفعه اليوم'));
    });

    test('recognizes compound Arabic hundred-words and "الفين"/"ألفين" as literal amounts', () {
      expect(parser.parse('سجل خمسمائة ريال لحساب سالم أحمد').amount, 500);
      expect(parser.parse('سجل تسعمية ريال لحساب سالم أحمد').amount, 900);
      expect(parser.parse('سجل الفين ريال لحساب سالم أحمد').amount, 2000);
      expect(parser.parse('سجل ألفين ريال لحساب سالم أحمد').amount, 2000);
    });

    test('a stated date never gets mistaken for the amount when it appears before the amount', () {
      final draft = parser.parse('سجل بتاريخ 2026-08-14 مبلغ 3200 ريال لحساب سالم أحمد');

      expect(draft.amount, 3200);
      expect(draft.date, DateTime(2026, 8, 14));
    });

    group('expanded Yemeni-colloquial direction markers', () {
      test('debit side: دين / عنده / تسلف / استلف / مديون', () {
        // Deliberately anchored with "حساب" (not "على"/"عليه") so the base sentence itself
        // carries no OTHER debit marker — this isolates each new colloquial word as the true
        // cause of the debit result, rather than the pre-existing formal marker doing the work.
        for (final word in ['دين', 'عنده', 'تسلف', 'استلف', 'مديون']) {
          final draft = parser.parse('سجل حساب أحمد محمد 500 ريال $word');
          expect(draft.direction, AccountDirection.debit, reason: 'word: $word');
        }
      });

      test('credit side: سدد / سلم / وصل / رجع', () {
        for (final word in ['سدد', 'سلم', 'وصل', 'رجع']) {
          final draft = parser.parse('سجل لحساب أحمد محمد 500 ريال $word');
          expect(draft.direction, AccountDirection.credit, reason: 'word: $word');
        }
      });
    });

    group('currency support-checking', () {
      test('recognizes every currency this app actually supports', () {
        const expectations = {
          'سعودي': 'SAR',
          'درهم': 'AED',
          'إماراتي': 'AED',
          'جنيه مصري': 'EGP',
          'دينار كويتي': 'KWD',
          'دولار': 'USD',
          'ريال يمني': 'YER',
        };
        for (final entry in expectations.entries) {
          final draft = parser.parse('سجل لحساب أحمد محمد 500 ${entry.key}');
          expect(draft.currency, entry.value, reason: 'spoken: ${entry.key}');
          expect(draft.currencyUnsupported, isFalse, reason: 'spoken: ${entry.key}');
        }
      });

      test('flags a real but unsupported currency instead of silently defaulting', () {
        final draft = parser.parse('سجل لحساب أحمد محمد 500 يورو');

        expect(draft.currencyUnsupported, isTrue);
      });

      test('"ريال قطري" is flagged unsupported, never mistaken for the Yemeni Rial', () {
        final draft = parser.parse('سجل لحساب أحمد محمد 500 ريال قطري');

        expect(draft.currencyUnsupported, isTrue);
      });
    });

    group('VoiceCommandParser.hasFullName', () {
      test('a single word is not a full name', () {
        expect(VoiceCommandParser.hasFullName('عبدالقدوس'), isFalse);
      });

      test('two or more words is a full name', () {
        expect(VoiceCommandParser.hasFullName('عبدالقدوس محمد'), isTrue);
        expect(VoiceCommandParser.hasFullName('  إبراهيم   سعيد  علي '), isTrue);
      });
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

    test('replaces currency and currencyUnsupported independently of every other field', () {
      final draft = parser.parse('سجل لحساب أحمد محمد 500 يورو');
      expect(draft.currencyUnsupported, isTrue);

      final resolved = draft.copyWith(currency: 'USD', currencyUnsupported: false);

      expect(resolved.currency, 'USD');
      expect(resolved.currencyUnsupported, isFalse);
      expect(resolved.amount, draft.amount);
      expect(resolved.accountName, draft.accountName);
    });
  });
}
