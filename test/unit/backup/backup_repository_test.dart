import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dyooni/core/utils/app_exception.dart';
import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/backup_snapshot.dart';
import 'package:dyooni/data/models/personal_data.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/data/repositories/accounts/accounts_repository.dart';
import 'package:dyooni/data/repositories/backup/backup_repository.dart';
import 'package:dyooni/data/repositories/backup/backup_repository_impl.dart';
import 'package:dyooni/data/repositories/settings/personal_data_repository.dart';
import 'package:dyooni/data/repositories/transactions/transactions_repository.dart';

class MockAccountsRepository extends Mock implements AccountsRepository {}

class MockTransactionsRepository extends Mock implements TransactionsRepository {}

class MockPersonalDataRepository extends Mock implements PersonalDataRepository {}

void main() {
  late MockAccountsRepository accountsRepo;
  late MockTransactionsRepository transactionsRepo;
  late MockPersonalDataRepository personalDataRepo;
  late BackupRepositoryImpl repository;

  final account = Account(
    id: 'a1',
    name: 'أحمد محمد',
    category: AccountCategory.client,
    createdDate: DateTime(2026, 1, 1),
  );
  final existingAccount = Account(
    id: 'existing1',
    name: 'حساب قديم',
    category: AccountCategory.supplier,
    createdDate: DateTime(2025, 1, 1),
  );
  final transaction = Transaction(
    id: 't1',
    accountId: 'a1',
    amount: 500,
    currency: 'SAR',
    direction: AccountDirection.credit,
    date: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(account);
    registerFallbackValue(transaction);
    registerFallbackValue(PersonalData.dyooniDefault);
  });

  setUp(() {
    accountsRepo = MockAccountsRepository();
    transactionsRepo = MockTransactionsRepository();
    personalDataRepo = MockPersonalDataRepository();
    repository = BackupRepositoryImpl(accountsRepo, transactionsRepo, personalDataRepo);
  });

  test('buildSnapshot bundles every account, transaction, and the personal-data record', () async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [account]);
    when(() => transactionsRepo.getTransactions()).thenAnswer((_) async => [transaction]);
    when(() => personalDataRepo.getPersonalData()).thenAnswer((_) async => PersonalData.dyooniDefault);

    final snapshot = await repository.buildSnapshot();

    expect(snapshot.accounts, [account]);
    expect(snapshot.transactions, [transaction]);
    expect(snapshot.personalData, PersonalData.dyooniDefault);
    expect(snapshot.schemaVersion, BackupSnapshot.currentSchemaVersion);
  });

  test('a snapshot survives a toJson/fromJson round trip unchanged', () {
    final snapshot = BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      createdAt: DateTime(2026, 1, 1),
      accounts: [account],
      transactions: [transaction],
      personalData: PersonalData.dyooniDefault,
    );

    final restored = BackupSnapshot.fromJson(snapshot.toJson());

    expect(restored.accounts.single.id, account.id);
    expect(restored.accounts.single.name, account.name);
    expect(restored.transactions.single.id, transaction.id);
    expect(restored.transactions.single.amount, transaction.amount);
    expect(restored.personalData.nameAr, PersonalData.dyooniDefault.nameAr);
  });

  test('RestoreMode.merge upserts every account/transaction and NEVER deletes existing ones', () async {
    when(() => accountsRepo.addAccount(any())).thenAnswer((_) async {});
    when(() => transactionsRepo.addTransaction(any())).thenAnswer((_) async {});
    when(() => personalDataRepo.savePersonalData(any())).thenAnswer((_) async {});

    final snapshot = BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      createdAt: DateTime(2026, 1, 1),
      accounts: [account],
      transactions: [transaction],
      personalData: PersonalData.dyooniDefault,
    );

    await repository.restoreSnapshot(snapshot, mode: RestoreMode.merge);

    verify(() => accountsRepo.addAccount(account)).called(1);
    verify(() => transactionsRepo.addTransaction(transaction)).called(1);
    verify(() => personalDataRepo.savePersonalData(PersonalData.dyooniDefault)).called(1);
    verifyNever(() => accountsRepo.deleteAccount(any()));
    verifyNever(() => transactionsRepo.deleteTransactionsForAccount(any()));
  });

  test('RestoreMode.replace deletes every EXISTING account (cascading its transactions) before inserting the backup', () async {
    when(() => accountsRepo.getAccounts()).thenAnswer((_) async => [existingAccount]);
    when(() => accountsRepo.deleteAccount(any())).thenAnswer((_) async {});
    when(() => transactionsRepo.deleteTransactionsForAccount(any())).thenAnswer((_) async {});
    when(() => accountsRepo.addAccount(any())).thenAnswer((_) async {});
    when(() => transactionsRepo.addTransaction(any())).thenAnswer((_) async {});
    when(() => personalDataRepo.savePersonalData(any())).thenAnswer((_) async {});

    final snapshot = BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      createdAt: DateTime(2026, 1, 1),
      accounts: [account],
      transactions: [transaction],
      personalData: PersonalData.dyooniDefault,
    );

    await repository.restoreSnapshot(snapshot, mode: RestoreMode.replace);

    verify(() => transactionsRepo.deleteTransactionsForAccount('existing1')).called(1);
    verify(() => accountsRepo.deleteAccount('existing1')).called(1);
    verify(() => accountsRepo.addAccount(account)).called(1);
    verify(() => transactionsRepo.addTransaction(transaction)).called(1);
  });

  test('restoreSnapshot refuses a backup made by a NEWER, incompatible schema version', () async {
    final futureSnapshot = BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion + 1,
      createdAt: DateTime(2026, 1, 1),
      accounts: const [],
      transactions: const [],
      personalData: PersonalData.dyooniDefault,
    );

    await expectLater(
      repository.restoreSnapshot(futureSnapshot, mode: RestoreMode.merge),
      throwsA(isA<ValidationException>()),
    );
    verifyNever(() => accountsRepo.addAccount(any()));
    verifyNever(() => transactionsRepo.addTransaction(any()));
    verifyNever(() => personalDataRepo.savePersonalData(any()));
  });
}
