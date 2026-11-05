import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';

/// How Home orders its accounts. [newest] is what Home always did (the most recently added
/// account first), so nothing changes until the person picks something else.
enum HomeSort { newest, oldest, nameAsc, nameDesc, balanceDesc, balanceAsc, recentActivity }

/// Which accounts Home shows, by the state of their balance in the CURRENT currency page.
enum HomeStatusFilter { all, credit, debit, settled }

final homeSortProvider = StateProvider<HomeSort>((ref) => HomeSort.newest);
final homeStatusFilterProvider = StateProvider<HomeStatusFilter>((ref) => HomeStatusFilter.all);

/// `true` when anything differs from the defaults (drives the little "active" dot).
bool isHomeArrangementActive(HomeSort sort, HomeStatusFilter status) =>
    sort != HomeSort.newest || status != HomeStatusFilter.all;

const _epsilon = 0.005;

bool matchesStatus(HomeStatusFilter filter, double balance) => switch (filter) {
      HomeStatusFilter.all => true,
      HomeStatusFilter.credit => balance > _epsilon,
      HomeStatusFilter.debit => balance < -_epsilon,
      HomeStatusFilter.settled => balance.abs() <= _epsilon,
    };

/// Filters and orders [accounts] for display.
///
/// [accounts] arrive in creation order (oldest first), the way the repository keeps them.
/// [balanceOf] is the account's net in the selected currency (positive = له). [lastActivityOf] is
/// the date of its latest entry, or `null` when it has none (those go last for "recent activity").
/// Ties always fall back to the name, so the order is stable and predictable.
List<Account> arrangeAccounts({
  required List<Account> accounts,
  required HomeSort sort,
  required HomeStatusFilter status,
  required double Function(Account) balanceOf,
  required DateTime? Function(Account) lastActivityOf,
}) {
  final list = [for (final a in accounts) if (matchesStatus(status, balanceOf(a))) a];
  int byName(Account a, Account b) => a.name.compareTo(b.name);
  switch (sort) {
    case HomeSort.newest:
      return list.reversed.toList();
    case HomeSort.oldest:
      return list;
    case HomeSort.nameAsc:
      list.sort(byName);
    case HomeSort.nameDesc:
      list.sort((a, b) => byName(b, a));
    case HomeSort.balanceDesc:
      list.sort((a, b) {
        final c = balanceOf(b).compareTo(balanceOf(a));
        return c != 0 ? c : byName(a, b);
      });
    case HomeSort.balanceAsc:
      list.sort((a, b) {
        final c = balanceOf(a).compareTo(balanceOf(b));
        return c != 0 ? c : byName(a, b);
      });
    case HomeSort.recentActivity:
      list.sort((a, b) {
        final da = lastActivityOf(a);
        final db = lastActivityOf(b);
        if (da == null && db == null) return byName(a, b);
        if (da == null) return 1;
        if (db == null) return -1;
        final c = db.compareTo(da);
        return c != 0 ? c : byName(a, b);
      });
  }
  return list;
}
