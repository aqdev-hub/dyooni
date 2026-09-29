import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/logic/accounts/ceiling_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('checkAccountCeiling', () {
    test('allows entries when no ceiling is set', () {
      final result = checkAccountCeiling(
        currentBalance: -1000,
        direction: AccountDirection.debit,
        amount: 50000,
        ceiling: null,
      );
      expect(result, isA<CeilingOk>());
    });

    test('allows a resulting credit balance regardless of ceiling', () {
      final result = checkAccountCeiling(
        currentBalance: 0,
        direction: AccountDirection.credit,
        amount: 1000000,
        ceiling: 500,
      );
      expect(result, isA<CeilingOk>());
    });

    test('allows a debit balance exactly at the ceiling', () {
      final result = checkAccountCeiling(
        currentBalance: -400,
        direction: AccountDirection.debit,
        amount: 100,
        ceiling: 500,
      );
      expect(result, isA<CeilingOk>());
    });

    test('rejects a debit balance beyond the ceiling', () {
      final result = checkAccountCeiling(
        currentBalance: -42000,
        direction: AccountDirection.debit,
        amount: 700,
        ceiling: 42500,
      );
      expect(result, isA<CeilingExceeded>());
      final exceeded = result as CeilingExceeded;
      expect(exceeded.projectedDebitBalance, 42700);
      expect(exceeded.ceiling, 42500);
    });

    test('checks the first transaction of a new account', () {
      final result = checkAccountCeiling(
        currentBalance: 0,
        direction: AccountDirection.debit,
        amount: 1000,
        ceiling: 500,
      );
      expect(result, isA<CeilingExceeded>());
      expect((result as CeilingExceeded).projectedDebitBalance, 1000);
    });

    test('allows a credit entry that reduces an existing debit balance', () {
      final result = checkAccountCeiling(
        currentBalance: -600,
        direction: AccountDirection.credit,
        amount: 200,
        ceiling: 500,
      );
      expect(result, isA<CeilingOk>());
    });
  });
}
