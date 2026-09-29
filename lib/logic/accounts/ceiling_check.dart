import '../../data/models/account.dart';

sealed class CeilingCheckResult {
  const CeilingCheckResult();
}

class CeilingOk extends CeilingCheckResult {
  const CeilingOk();
}

/// A new transaction would make the account's debit balance exceed its ceiling.
class CeilingExceeded extends CeilingCheckResult {
  const CeilingExceeded({required this.projectedDebitBalance, required this.ceiling});

  final double projectedDebitBalance;
  final double ceiling;
}

/// Applies an optional account ceiling to the debit (عليه) side only.  Balances use the same
/// convention as [accountBalanceProvider]: credit is positive and debit is negative.
CeilingCheckResult checkAccountCeiling({
  required double currentBalance,
  required AccountDirection direction,
  required double amount,
  required double? ceiling,
}) {
  if (ceiling == null) return const CeilingOk();
  final signedAmount = direction == AccountDirection.credit ? amount : -amount;
  final projectedBalance = currentBalance + signedAmount;
  if (projectedBalance >= 0) return const CeilingOk();
  final projectedDebitBalance = -projectedBalance;
  if (projectedDebitBalance <= ceiling) return const CeilingOk();
  return CeilingExceeded(projectedDebitBalance: projectedDebitBalance, ceiling: ceiling);
}
