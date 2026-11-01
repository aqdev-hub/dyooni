import '../../data/models/account.dart';
import '../../data/models/transaction.dart';

/// The two entries of one transfer, ready to save.
class TransferLegs {
  const TransferLegs({required this.debit, required this.credit});

  /// On the SENDING account: عليه — its balance goes down by the amount.
  final Transaction debit;

  /// On the RECEIVING account: له — its balance goes up by the amount.
  final Transaction credit;

  List<Transaction> get both => [debit, credit];
}

/// Why a transfer cannot be made, or `null` when it can. Kept pure so the screen and the tests
/// share one definition of "valid".
enum TransferProblem { sameAccount, invalidAmount, missingAccount }

TransferProblem? validateTransfer({
  required String? fromAccountId,
  required String? toAccountId,
  required double? amount,
}) {
  if (fromAccountId == null || toAccountId == null) return TransferProblem.missingAccount;
  if (fromAccountId == toAccountId) return TransferProblem.sameAccount;
  if (amount == null || amount.isNaN || amount.isInfinite || amount <= 0) return TransferProblem.invalidAmount;
  return null;
}

/// Builds the two linked entries of "move [amount] from [fromAccountId] to [toAccountId]".
///
/// Accounting meaning (the one the person confirmed): the sender gets a debit (عليه) so its
/// balance is reduced, the receiver gets a credit (له) so its balance is increased — the total
/// across both accounts does not change. Both entries share one [transferId], one date and one
/// currency, which is what lets them be shown together and deleted together.
///
/// [detailsForFrom]/[detailsForTo] are the already-translated texts of each side (e.g. "تحويل إلى
/// علي" / "تحويل من أحمد"), with the person's own note appended by the caller.
TransferLegs buildTransferLegs({
  required String transferId,
  required String debitEntryId,
  required String creditEntryId,
  required String fromAccountId,
  required String toAccountId,
  required double amount,
  required String currency,
  required DateTime date,
  required String detailsForFrom,
  required String detailsForTo,
}) {
  return TransferLegs(
    debit: Transaction(
      id: debitEntryId,
      accountId: fromAccountId,
      amount: amount,
      currency: currency,
      direction: AccountDirection.debit,
      date: date,
      details: detailsForFrom,
      transferId: transferId,
    ),
    credit: Transaction(
      id: creditEntryId,
      accountId: toAccountId,
      amount: amount,
      currency: currency,
      direction: AccountDirection.credit,
      date: date,
      details: detailsForTo,
      transferId: transferId,
    ),
  );
}

/// Balance of [accountId] in [currency] AFTER the transfer, for the preview card.
double balanceAfter({
  required List<Transaction> transactions,
  required String accountId,
  required String currency,
  required double delta,
}) {
  var net = 0.0;
  for (final t in transactions) {
    if (t.accountId != accountId || t.currency != currency) continue;
    net += t.direction == AccountDirection.credit ? t.amount : -t.amount;
  }
  return net + delta;
}
