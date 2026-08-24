import '../../local/accounts/accounts_local_datasource.dart';
import '../../models/account.dart';
import 'accounts_repository.dart';

class AccountsRepositoryImpl implements AccountsRepository {
  const AccountsRepositoryImpl(this._local);
  final AccountsLocalDataSource _local;

  @override
  Future<List<Account>> getAccounts() => _local.getAll();

  @override
  Stream<List<Account>> watchAccounts() async* {
    yield await getAccounts();
  }

  @override
  Future<void> addAccount(Account account) async {
    final current = await _local.getAll();
    await _local.saveAll([...current, account]);
  }

  @override
  Future<void> deleteAccount(String id) async {
    final current = await _local.getAll();
    await _local.saveAll(current.where((a) => a.id != id).toList());
  }
}
