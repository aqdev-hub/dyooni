import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dyooni/core/utils/interrupted_form_recovery.dart';

void main() {
  test('returns null when nothing was left mid-entry (the normal case)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(findInterruptedFormDraft(prefs), isNull);
  });

  test('detects an interrupted "add account" draft', () async {
    SharedPreferences.setMockInitialValues({'draft_add_account': '{}'});
    final prefs = await SharedPreferences.getInstance();

    expect(findInterruptedFormDraft(prefs), isA<ResumeAddAccount>());
  });

  test('detects an interrupted "add transaction" draft and extracts its account id from the key', () async {
    SharedPreferences.setMockInitialValues({'draft_add_transaction_a123': '{}'});
    final prefs = await SharedPreferences.getInstance();

    final result = findInterruptedFormDraft(prefs);

    expect(result, isA<ResumeAddTransaction>());
    expect((result as ResumeAddTransaction).accountId, 'a123');
  });

  test('an account draft takes priority over a transaction draft when both somehow exist', () async {
    SharedPreferences.setMockInitialValues({
      'draft_add_account': '{}',
      'draft_add_transaction_a123': '{}',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(findInterruptedFormDraft(prefs), isA<ResumeAddAccount>());
  });

  test('unrelated SharedPreferences keys are never mistaken for a draft', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'locale_code': 'ar',
      'onboarding_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();

    expect(findInterruptedFormDraft(prefs), isNull);
  });
}
