import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/backup/backup_repository.dart';
import '../../data/repositories/backup/backup_repository_impl.dart';
import '../accounts/accounts_provider.dart';
import '../settings/personal_data_provider.dart';
import '../transactions/transactions_provider.dart';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepositoryImpl(
    ref.watch(accountsRepositoryProvider),
    ref.watch(transactionsRepositoryProvider),
    ref.watch(personalDataRepositoryProvider),
  ),
);
