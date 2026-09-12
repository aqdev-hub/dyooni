import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/drive_backup_metadata.dart';
import '../../data/repositories/backup/backup_repository.dart' show RestoreMode;
import '../drive_backup/drive_backup_provider.dart';

/// What DriveBackupScreen shows: whether a Google account is connected, when the last backup of
/// ANY kind succeeded, and whether today already has a daily snapshot.
class DriveBackupState {
  const DriveBackupState({
    required this.hasGoogleAccess,
    this.lastBackupAt,
    this.hasTodayBackup = false,
  });

  final bool hasGoogleAccess;
  final DateTime? lastBackupAt;
  final bool hasTodayBackup;
}

/// Drives the "حفظ/استرجاع البيانات من جوجل" and "مزامنة البيانات على جوجل درايف" drawer items —
/// both point at the same real feature now (see app_drawer.dart's doc comment on why: the design
/// brief this was built from explicitly rules out a separate live "sync" concept, so a second
/// menu entry for it would just be a confusing dead end pointing at nothing real).
///
/// [build] itself IS the "opportunistic daily-backup check" — see DriveBackupRepositoryImpl's
/// class doc comment for the exact decision table. It runs once whenever this provider is first
/// read (Home screen's initState reads it once per app session; DriveBackupScreen forces a fresh
/// re-check every time it's opened via [refresh]) and NEVER throws or shows an error for a
/// failure here — a failed silent check just means "today's status couldn't be confirmed right
/// now", exactly per the "never show annoying errors for a background Drive failure" requirement.
///
/// STATED SCOPE LIMIT: this is opportunistic-on-app-activity, not a persistent background
/// service — Flutter has no reliable, low-risk way to run authenticated network work while the
/// app is fully closed without OS-specific background-task plugins (WorkManager on Android,
/// BackgroundTasks on iOS), which is a materially bigger, riskier addition than the rest of this
/// feature and was deliberately left out rather than half-implemented. In practice this means:
/// the daily snapshot catches up the moment the person next opens the app with internet
/// available, not necessarily the instant a new day starts or internet reconnects while the app
/// is backgrounded.
final driveBackupControllerProvider = AsyncNotifierProvider<DriveBackupController, DriveBackupState>(
  DriveBackupController.new,
);

class DriveBackupController extends AsyncNotifier<DriveBackupState> {
  @override
  Future<DriveBackupState> build() async {
    final repository = ref.read(driveBackupRepositoryProvider);
    final hasAccess = await repository.hasGoogleAccess();
    if (!hasAccess) return const DriveBackupState(hasGoogleAccess: false);

    try {
      await repository.ensureTodayBackup(); // null return just means "already up to date"
      final backups = await repository.listBackups();
      final lastBackupAt = backups.isEmpty
          ? null
          : backups.map((b) => b.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
      return DriveBackupState(hasGoogleAccess: true, lastBackupAt: lastBackupAt, hasTodayBackup: true);
    } catch (_) {
      // Deliberately swallowed — see this class's doc comment. The screen still shows
      // "حساب جوجل متصل" honestly; it just can't confirm today's backup status right now.
      return const DriveBackupState(hasGoogleAccess: true);
    }
  }

  /// The ONLY path that may show an interactive Google account picker — always a direct response
  /// to the person tapping "ربط حساب جوجل".
  Future<void> connectGoogleAccount() async {
    await ref.read(driveBackupRepositoryProvider).connectGoogleAccount();
    await refresh();
  }

  /// Explicit user action — errors here ARE surfaced to the person (see DriveBackupScreen),
  /// unlike the silent opportunistic check in [build].
  Future<void> saveNow() async {
    await ref.read(driveBackupRepositoryProvider).createManualBackup();
    await refresh();
  }

  Future<void> restore(String fileId, RestoreMode mode) =>
      ref.read(driveBackupRepositoryProvider).restoreBackup(fileId, mode: mode);

  Future<List<DriveBackupMetadata>> fetchBackupsList() =>
      ref.read(driveBackupRepositoryProvider).listBackups();

  /// Forces a fresh opportunistic check — called every time DriveBackupScreen opens, so the
  /// status shown is never more than one screen-visit stale.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
