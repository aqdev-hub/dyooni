import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/utils/app_exception.dart';
import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/backup_snapshot.dart';
import 'package:dyooni/data/models/drive_backup_metadata.dart';
import 'package:dyooni/data/models/personal_data.dart';
import 'package:dyooni/data/remote/drive/drive_backup_datasource.dart';
import 'package:dyooni/data/repositories/backup/backup_repository.dart';
import 'package:dyooni/data/repositories/drive_backup/drive_backup_repository_impl.dart';

class MockDriveBackupDataSource extends Mock implements DriveBackupDataSource {}

class MockBackupRepository extends Mock implements BackupRepository {}

/// Mirrors DriveBackupRepositoryImpl's own private `_checksum` computation exactly (same
/// id-sorted accounts/transactions, same JSON shape, same SHA-256-hex encoding), so tests can
/// construct an "unchanged since last backup" scenario without reaching into private members.
String _checksumOf(BackupSnapshot snapshot) {
  final sortedAccounts = [...snapshot.accounts]..sort((a, b) => a.id.compareTo(b.id));
  final sortedTransactions = [...snapshot.transactions]..sort((a, b) => a.id.compareTo(b.id));
  final canonical = jsonEncode({
    'accounts': sortedAccounts.map((a) => a.toJson()).toList(),
    'transactions': sortedTransactions.map((t) => t.toJson()).toList(),
    'personalData': snapshot.personalData.toJson(),
  });
  return sha256.convert(utf8.encode(canonical)).toString();
}

void main() {
  late MockDriveBackupDataSource dataSource;
  late MockBackupRepository backupRepository;
  late DriveBackupRepositoryImpl repository;

  const userId = 'user-1';
  final account = Account(id: 'a1', name: 'أحمد محمد', category: AccountCategory.client, createdDate: DateTime(2026, 1, 1));
  final snapshot = BackupSnapshot(
    schemaVersion: BackupSnapshot.currentSchemaVersion,
    createdAt: DateTime(2026, 8, 31),
    accounts: [account],
    transactions: const [],
    personalData: PersonalData.dyooniDefault,
  );

  setUpAll(() {
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    dataSource = MockDriveBackupDataSource();
    backupRepository = MockBackupRepository();
    repository = DriveBackupRepositoryImpl(dataSource, backupRepository, userId);
    when(() => backupRepository.buildSnapshot()).thenAnswer((_) async => snapshot);
  });

  group('ensureTodayBackup', () {
    test('uploads a brand-new daily backup when none exists for today yet', () async {
      when(() => dataSource.findBackup(userId: userId, type: 'daily', backupDate: any(named: 'backupDate')))
          .thenAnswer((_) async => null);
      when(() => dataSource.uploadOrUpdate(
            fileId: any(named: 'fileId'),
            fileName: any(named: 'fileName'),
            content: any(named: 'content'),
            appProperties: any(named: 'appProperties'),
          )).thenAnswer((_) async => const DriveRemoteFile(id: 'file-1', appProperties: {}));
      when(() => dataSource.listBackups(userId: userId, type: 'daily')).thenAnswer((_) async => const []);

      final result = await repository.ensureTodayBackup();

      expect(result, isNotNull);
      expect(result!.type, DriveBackupType.daily);
      verify(() => dataSource.uploadOrUpdate(
            fileId: null, // a brand-new file, never an update
            fileName: any(named: 'fileName'),
            content: any(named: 'content'),
            appProperties: any(named: 'appProperties'),
          )).called(1);
    });

    test('uploads NOTHING when a checksum-matching daily backup already exists', () async {
      final unchangedChecksum = _checksumOf(snapshot);
      when(() => dataSource.findBackup(userId: userId, type: 'daily', backupDate: any(named: 'backupDate'))).thenAnswer(
        (_) async => DriveRemoteFile(id: 'file-1', appProperties: {'dataChecksum': unchangedChecksum}),
      );

      final result = await repository.ensureTodayBackup();

      expect(result, isNull);
      verifyNever(() => dataSource.uploadOrUpdate(
            fileId: any(named: 'fileId'),
            fileName: any(named: 'fileName'),
            content: any(named: 'content'),
            appProperties: any(named: 'appProperties'),
          ));
    });

    test("overwrites the SAME file (never a second one) when today's data changed", () async {
      when(() => dataSource.findBackup(userId: userId, type: 'daily', backupDate: any(named: 'backupDate'))).thenAnswer(
        (_) async => const DriveRemoteFile(id: 'file-1', appProperties: {'dataChecksum': 'stale-checksum-from-this-morning'}),
      );
      when(() => dataSource.uploadOrUpdate(
            fileId: any(named: 'fileId'),
            fileName: any(named: 'fileName'),
            content: any(named: 'content'),
            appProperties: any(named: 'appProperties'),
          )).thenAnswer((_) async => const DriveRemoteFile(id: 'file-1', appProperties: {}));

      final result = await repository.ensureTodayBackup();

      expect(result, isNotNull);
      verify(() => dataSource.uploadOrUpdate(
            fileId: 'file-1', // SAME file id — an update, not a new file
            fileName: any(named: 'fileName'),
            content: any(named: 'content'),
            appProperties: any(named: 'appProperties'),
          )).called(1);
      // Updating today's own file never changes how many daily files exist, so pruning must
      // never run here.
      verifyNever(() => dataSource.listBackups(userId: userId, type: 'daily'));
    });

    test('prunes only the oldest daily backup, and ONLY after the new one is confirmed uploaded', () async {
      when(() => dataSource.findBackup(userId: userId, type: 'daily', backupDate: any(named: 'backupDate')))
          .thenAnswer((_) async => null);
      when(() => dataSource.uploadOrUpdate(
            fileId: any(named: 'fileId'),
            fileName: any(named: 'fileName'),
            content: any(named: 'content'),
            appProperties: any(named: 'appProperties'),
          )).thenAnswer((_) async => const DriveRemoteFile(id: 'file-new', appProperties: {}));
      final eightDailyBackups = List.generate(
        8,
        (i) => DriveRemoteFile(id: 'file-$i', appProperties: {'backupDate': '2026-08-${(i + 20).toString().padLeft(2, '0')}'}),
      );
      when(() => dataSource.listBackups(userId: userId, type: 'daily')).thenAnswer((_) async => eightDailyBackups);
      when(() => dataSource.delete(any())).thenAnswer((_) async {});

      await repository.ensureTodayBackup();

      // Only the single oldest (by backupDate) of the 8 existing files should be deleted, once.
      verify(() => dataSource.delete('file-0')).called(1);
    });

    test('a single failed delete during pruning never throws — the new backup already succeeded', () async {
      when(() => dataSource.findBackup(userId: userId, type: 'daily', backupDate: any(named: 'backupDate')))
          .thenAnswer((_) async => null);
      when(() => dataSource.uploadOrUpdate(
            fileId: any(named: 'fileId'),
            fileName: any(named: 'fileName'),
            content: any(named: 'content'),
            appProperties: any(named: 'appProperties'),
          )).thenAnswer((_) async => const DriveRemoteFile(id: 'file-new', appProperties: {}));
      final eightDailyBackups = List.generate(
        8,
        (i) => DriveRemoteFile(id: 'file-$i', appProperties: {'backupDate': '2026-08-${(i + 20).toString().padLeft(2, '0')}'}),
      );
      when(() => dataSource.listBackups(userId: userId, type: 'daily')).thenAnswer((_) async => eightDailyBackups);
      when(() => dataSource.delete(any())).thenThrow(Exception('network blip'));

      await expectLater(repository.ensureTodayBackup(), completes);
    });
  });

  group('createManualBackup', () {
    test('always uploads a brand-new file, tagged manual, never checked against today\'s daily backup', () async {
      when(() => dataSource.uploadOrUpdate(
            fileId: any(named: 'fileId'),
            fileName: any(named: 'fileName'),
            content: any(named: 'content'),
            appProperties: any(named: 'appProperties'),
          )).thenAnswer((_) async => const DriveRemoteFile(id: 'manual-1', appProperties: {}));

      final result = await repository.createManualBackup();

      expect(result.type, DriveBackupType.manual);
      verifyNever(() => dataSource.findBackup(
            userId: any(named: 'userId'),
            type: any(named: 'type'),
            backupDate: any(named: 'backupDate'),
          ));
      verify(() => dataSource.uploadOrUpdate(
            fileId: null,
            fileName: any(named: 'fileName'),
            content: any(named: 'content'),
            appProperties: any(named: 'appProperties'),
          )).called(1);
    });
  });

  group('restoreBackup', () {
    test('downloads the file, parses the embedded snapshot, and restores via the local BackupRepository', () async {
      final envelope = jsonEncode({'schemaVersion': 1, 'snapshot': snapshot.toJson()});
      when(() => dataSource.downloadContent('file-1')).thenAnswer((_) async => envelope);
      when(() => backupRepository.restoreSnapshot(any(), mode: RestoreMode.merge)).thenAnswer((_) async {});

      await repository.restoreBackup('file-1', mode: RestoreMode.merge);

      final captured = verify(() => backupRepository.restoreSnapshot(captureAny(), mode: RestoreMode.merge)).captured;
      expect((captured.single as BackupSnapshot).accounts.single.id, account.id);
    });

    test('throws a ValidationException(backupFileInvalid) for content with no embedded snapshot', () async {
      when(() => dataSource.downloadContent('file-1')).thenAnswer((_) async => jsonEncode({'notABackup': true}));

      await expectLater(
        repository.restoreBackup('file-1', mode: RestoreMode.merge),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
