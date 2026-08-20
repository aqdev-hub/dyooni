import '../../models/account.dart';

/// `logic/` imports this interface only — never the DataSource directly (see repository-di.md).
abstract class AccountsRepository {
  Future<List<Account>> getAccounts();
  Future<void> addAccount(Account account);
  Future<void> deleteAccount(String id);
}
