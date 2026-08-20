import 'account.dart' show AccountDirection;

/// One ledger entry belonging to an account. An account's balance and its "N عملية" badge count
/// (see the reference screenshots) are both DERIVED from its transactions — never stored
/// directly on the account — see logic/transactions/transactions_provider.dart.
class Transaction {
  const Transaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.date,
    this.details,
  });

  final String id;
  final String accountId;
  final double amount;
  final String currency;
  final AccountDirection direction;
  final DateTime date;
  final String? details;

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'amount': amount,
        'currency': currency,
        'direction': direction.name,
        'date': date.toIso8601String(),
        'details': details,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        direction: AccountDirection.values.byName(json['direction'] as String),
        date: DateTime.parse(json['date'] as String),
        details: json['details'] as String?,
      );
}
