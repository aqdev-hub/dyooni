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
    this.voiceRecording,
  });

  final String id;
  final String accountId;
  final double amount;
  final String currency;
  final AccountDirection direction;
  final DateTime date;
  final String? details;
  final VoiceRecording? voiceRecording;

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'amount': amount,
        'currency': currency,
        'direction': direction.name,
        'date': date.toIso8601String(),
        'details': details,
        'voiceRecording': voiceRecording?.toJson(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        direction: AccountDirection.values.byName(json['direction'] as String),
        date: DateTime.parse(json['date'] as String),
        details: json['details'] as String?,
        voiceRecording: json['voiceRecording'] is Map<String, dynamic>
            ? VoiceRecording.fromJson(json['voiceRecording'] as Map<String, dynamic>)
            : null,
      );
}

/// Metadata only — the actual audio remains a local app-document file for now.
/// Keeping this as a nullable child preserves every transaction written before voice input.
class VoiceRecording {
  const VoiceRecording({
    required this.path,
    required this.durationMs,
    required this.transcript,
    required this.transactionId,
  });

  final String path;
  final int durationMs;
  final String transcript;
  final String transactionId;

  Map<String, dynamic> toJson() => {
        'path': path,
        'durationMs': durationMs,
        'transcript': transcript,
        'transactionId': transactionId,
      };

  factory VoiceRecording.fromJson(Map<String, dynamic> json) => VoiceRecording(
        path: json['path'] as String,
        durationMs: (json['durationMs'] as num).toInt(),
        transcript: json['transcript'] as String,
        transactionId: json['transactionId'] as String,
      );
}
