import 'account.dart';
import 'personal_data.dart';
import 'transaction.dart';

/// A full local export of every user-owned record the app currently manages, used by the
/// device backup/restore flow (see BackupRepository).
///
/// KNOWN, STATED LIMITATION: this deliberately excludes voice-recording AUDIO FILES themselves —
/// only their metadata (see Transaction.voiceRecording, which still round-trips: path, duration,
/// transcript). The actual .m4a files live under the device's own documents directory and are
/// not portable inside a single JSON blob; a restored voice-tagged entry keeps its transcript
/// text but its "play" button will show voiceAudioUnavailable until/unless a dedicated audio-file
/// backup is built later. Stated here explicitly rather than silently dropped.
class BackupSnapshot {
  const BackupSnapshot({
    required this.schemaVersion,
    required this.createdAt,
    required this.accounts,
    required this.transactions,
    required this.personalData,
  });

  /// Bumped only when a future change would make an OLDER export unsafe to import as-is — lets
  /// BackupRepositoryImpl.restoreSnapshot refuse (rather than silently corrupt data from) a
  /// backup file made by an incompatible NEWER version of the app.
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime createdAt;
  final List<Account> accounts;
  final List<Transaction> transactions;
  final PersonalData personalData;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toIso8601String(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'personalData': personalData.toJson(),
      };

  factory BackupSnapshot.fromJson(Map<String, dynamic> json) => BackupSnapshot(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        accounts: (json['accounts'] as List<dynamic>? ?? const [])
            .map((e) => Account.fromJson(e as Map<String, dynamic>))
            .toList(),
        transactions: (json['transactions'] as List<dynamic>? ?? const [])
            .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        personalData: json['personalData'] is Map<String, dynamic>
            ? PersonalData.fromJson(json['personalData'] as Map<String, dynamic>)
            : PersonalData.dyooniDefault,
      );
}
