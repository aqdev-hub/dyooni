import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/drive/drive_backup_datasource.dart';
import '../../data/repositories/drive_backup/drive_backup_repository.dart';
import '../../data/repositories/drive_backup/drive_backup_repository_impl.dart';
import '../auth/auth_provider.dart';
import '../backup/backup_provider.dart';

final driveBackupDataSourceProvider = Provider<DriveBackupDataSource>(
  (ref) => DriveBackupDataSource(ref.watch(googleSignInProvider)),
);

final driveBackupRepositoryProvider = Provider<DriveBackupRepository>(
  (ref) => DriveBackupRepositoryImpl(
    ref.watch(driveBackupDataSourceProvider),
    ref.watch(backupRepositoryProvider),
    FirebaseAuth.instance.currentUser?.uid,
  ),
);
