import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/logic/accounts/home_arrangement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Account acc(String id, String name) => Account(id: id, name: name, category: AccountCategory.client, createdDate: DateTime(2026));
  final a = acc('a', 'أحمد');
  final b = acc('b', 'بكر');
  final c = acc('c', 'جمال');
  final d = acc('d', 'داود');
  // creation order a, b, c, d
  final balances = {'a': 100.0, 'b': -50.0, 'c': 0.0, 'd': 300.0};
  final last = {'a': DateTime(2026, 1, 5), 'b': DateTime(2026, 3, 1), 'c': null, 'd': DateTime(2026, 2, 1)};

  List<String> ids(HomeSort sort, [HomeStatusFilter status = HomeStatusFilter.all]) => arrangeAccounts(
        accounts: [a, b, c, d],
        sort: sort,
        status: status,
        balanceOf: (x) => balances[x.id]!,
        lastActivityOf: (x) => last[x.id],
      ).map((x) => x.id).toList();

  test('newest is the old behaviour: reverse of creation order', () {
    expect(ids(HomeSort.newest), ['d', 'c', 'b', 'a']);
    expect(ids(HomeSort.oldest), ['a', 'b', 'c', 'd']);
  });

  test('name and balance sorts', () {
    expect(ids(HomeSort.nameAsc), ['a', 'b', 'c', 'd']);
    expect(ids(HomeSort.nameDesc), ['d', 'c', 'b', 'a']);
    expect(ids(HomeSort.balanceDesc), ['d', 'a', 'c', 'b']);
    expect(ids(HomeSort.balanceAsc), ['b', 'c', 'a', 'd']);
  });

  test('recent activity puts accounts without entries last', () {
    expect(ids(HomeSort.recentActivity), ['b', 'd', 'a', 'c']);
  });

  test('status filter by balance', () {
    expect(ids(HomeSort.oldest, HomeStatusFilter.credit), ['a', 'd']);
    expect(ids(HomeSort.oldest, HomeStatusFilter.debit), ['b']);
    expect(ids(HomeSort.oldest, HomeStatusFilter.settled), ['c']);
  });

  test('activity flag', () {
    expect(isHomeArrangementActive(HomeSort.newest, HomeStatusFilter.all), isFalse);
    expect(isHomeArrangementActive(HomeSort.nameAsc, HomeStatusFilter.all), isTrue);
    expect(isHomeArrangementActive(HomeSort.newest, HomeStatusFilter.debit), isTrue);
  });
}
