import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/logic/transactions/transfer_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateTransfer', () {
    test('rejects missing accounts, same account and bad amounts', () {
      expect(validateTransfer(fromAccountId: null, toAccountId: 'b', amount: 5), TransferProblem.missingAccount);
      expect(validateTransfer(fromAccountId: 'a', toAccountId: 'a', amount: 5), TransferProblem.sameAccount);
      expect(validateTransfer(fromAccountId: 'a', toAccountId: 'b', amount: 0), TransferProblem.invalidAmount);
      expect(validateTransfer(fromAccountId: 'a', toAccountId: 'b', amount: null), TransferProblem.invalidAmount);
      expect(validateTransfer(fromAccountId: 'a', toAccountId: 'b', amount: double.nan), TransferProblem.invalidAmount);
    });
    test('accepts a valid transfer', () {
      expect(validateTransfer(fromAccountId: 'a', toAccountId: 'b', amount: 10), isNull);
    });
  });

  test('buildTransferLegs: sender debited, receiver credited, linked by transferId', () {
    final legs = buildTransferLegs(
      transferId: 't1',
      debitEntryId: 'd1',
      creditEntryId: 'c1',
      fromAccountId: 'a',
      toAccountId: 'b',
      amount: 100,
      currency: 'YER',
      date: DateTime(2026, 1, 1),
      detailsForFrom: 'to b',
      detailsForTo: 'from a',
    );
    expect(legs.debit.accountId, 'a');
    expect(legs.debit.direction, AccountDirection.debit);
    expect(legs.credit.accountId, 'b');
    expect(legs.credit.direction, AccountDirection.credit);
    expect(legs.debit.transferId, 't1');
    expect(legs.credit.transferId, 't1');
    expect(legs.debit.isTransfer, isTrue);
    expect(legs.both.length, 2);
  });
}
