import '../../data/models/account.dart';
import '../../data/models/report_options.dart';
import '../../data/models/transaction.dart';

/// How a line of a [ReportTable] is drawn: ordinary entry, soft carry-over line (opening
/// balance), or highlighted total.
enum ReportLineStyle { normal, subtle, total }

class ReportLine {
  const ReportLine(this.cells, {this.style = ReportLineStyle.normal});
  final List<String> cells;
  final ReportLineStyle style;
}

/// One table of a report: an optional heading (an account, a month…), the column headers and
/// the lines. Cells are already-formatted strings, so the PDF and Excel writers stay dumb and
/// every number is formatted in ONE place — the two files can never disagree.
class ReportTable {
  const ReportTable({this.heading, required this.headers, required this.lines});
  final String? heading;
  final List<String> headers;
  final List<ReportLine> lines;
}

class TabularReport {
  const TabularReport({required this.title, required this.tables});
  final String title;
  final List<ReportTable> tables;

  /// `true` when nothing at all matched (no entries in the chosen range/category) — the screen
  /// tells the person instead of exporting an empty file.
  bool get isEmpty => tables.every((t) => t.lines.isEmpty);
}

/// Every text a report needs, supplied by the caller (so this file has no Flutter/l10n
/// dependency and is fully unit-testable).
class ReportLabels {
  const ReportLabels({
    required this.date,
    required this.details,
    required this.account,
    required this.category,
    required this.currency,
    required this.month,
    required this.entries,
    required this.accountsCount,
    required this.credit,
    required this.debit,
    required this.net,
    required this.balance,
    required this.openingBalance,
    required this.closingBalance,
    required this.monthTotal,
    required this.total,
    required this.categoryNames,
    required this.currencyNames,
  });

  final String date, details, account, category, currency, month, entries, accountsCount;

  /// The person's own words for "له" / "عليه" (settings can rename them).
  final String credit, debit;
  final String net, balance, openingBalance, closingBalance, monthTotal, total;

  /// id → display name. A missing id falls back to the id itself.
  final Map<String, String> categoryNames;
  final Map<String, String> currencyNames;

  String categoryName(String id) => categoryNames[id] ?? id;
  String currencyName(String id) => currencyNames[id] ?? id;
}

/// Pure functions that turn accounts + transactions into [TabularReport]s.
///
/// Rules shared by all of them (the reasons the old "إجمالي المبالغ" is NOT reused for these):
///  * Amounts of different currencies are NEVER added together — every total is per currency.
///  * "له" (credit) minus "عليه" (debit) is the net; a positive net reads as له.
///  * A date range includes its whole last day.
class ReportBuilders {
  const ReportBuilders._();

  // ───────────── helpers ─────────────

  static String formatAmount(double value) {
    final a = value.abs();
    final fixed = a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(2);
    final parts = fixed.split('.');
    final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  }

  /// "1,000 له" / "500 عليه" / "0".
  static String formatNet(double net, ReportLabels l) {
    if (net.abs() < 0.005) return '0';
    return '${formatAmount(net)} ${net > 0 ? l.credit : l.debit}';
  }

  static double signed(Transaction t) => t.direction == AccountDirection.credit ? t.amount : -t.amount;

  static String formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static bool inRange(DateTime date, DateTime? from, DateTime? to) {
    if (from != null && date.isBefore(DateTime(from.year, from.month, from.day))) return false;
    if (to != null && !date.isBefore(DateTime(to.year, to.month, to.day).add(const Duration(days: 1)))) return false;
    return true;
  }

  static List<Transaction> _chrono(Iterable<Transaction> list) =>
      list.toList()..sort((a, b) => a.date.compareTo(b.date));

  static Map<String, List<Transaction>> _byAccount(List<Transaction> all) {
    final out = <String, List<Transaction>>{};
    for (final t in all) {
      (out[t.accountId] ??= []).add(t);
    }
    return out;
  }

  static double _sum(Iterable<Transaction> list) => list.fold(0.0, (s, t) => s + signed(t));

  static List<Account> _orderAccounts(List<Account> accounts, Map<String, List<Transaction>> byAccount, ReportSortOption? sort) {
    final list = [...accounts];
    DateTime last(Account a) {
      final tx = byAccount[a.id];
      if (tx == null || tx.isEmpty) return DateTime(1970);
      return tx.map((t) => t.date).reduce((x, y) => x.isAfter(y) ? x : y);
    }

    double bal(Account a) => _sum(byAccount[a.id] ?? const []);
    switch (sort) {
      case null:
        break;
      case ReportSortOption.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
      case ReportSortOption.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
      case ReportSortOption.balanceAsc:
        list.sort((a, b) => bal(a).compareTo(bal(b)));
      case ReportSortOption.balanceDesc:
        list.sort((a, b) => bal(b).compareTo(bal(a)));
      case ReportSortOption.dateAsc:
        list.sort((a, b) => last(a).compareTo(last(b)));
      case ReportSortOption.dateDesc:
        list.sort((a, b) => last(b).compareTo(last(a)));
    }
    return list;
  }

  static bool _newestFirst(ReportSortOption? sort) => sort == ReportSortOption.dateDesc;

  /// Currency ids that appear in [tx], in order of first use.
  static List<String> _currencies(Iterable<Transaction> tx) {
    final seen = <String>[];
    for (final t in tx) {
      if (!seen.contains(t.currency)) seen.add(t.currency);
    }
    return seen;
  }

  // ───────────── 1. تفاصيل جميع المبالغ ─────────────

  /// Every entry of every account, one table per account: date, details, currency, له, عليه and
  /// the running balance (computed per currency, oldest first), then one total line per currency.
  static TabularReport allAmountsDetails({
    required String title,
    required List<Account> accounts,
    required List<Transaction> transactions,
    required ReportLabels labels,
    DateTime? from,
    DateTime? to,
    ReportSortOption? sort,
  }) {
    final l = labels;
    final ranged = transactions.where((t) => inRange(t.date, from, to)).toList();
    final byAccount = _byAccount(ranged);
    final tables = <ReportTable>[];
    for (final account in _orderAccounts(accounts, byAccount, sort)) {
      final tx = _chrono(byAccount[account.id] ?? const []);
      if (tx.isEmpty) continue;
      final running = <String, double>{};
      final lines = <ReportLine>[];
      for (final t in tx) {
        final bal = (running[t.currency] ?? 0) + signed(t);
        running[t.currency] = bal;
        final isCredit = t.direction == AccountDirection.credit;
        lines.add(ReportLine([
          formatDate(t.date),
          t.details?.trim().isNotEmpty == true ? t.details!.trim() : '—',
          l.currencyName(t.currency),
          isCredit ? formatAmount(t.amount) : '0',
          isCredit ? '0' : formatAmount(t.amount),
          formatNet(bal, l),
        ]));
      }
      if (_newestFirst(sort)) {
        final reversed = lines.reversed.toList();
        lines
          ..clear()
          ..addAll(reversed);
      }
      for (final currency in _currencies(tx)) {
        final own = tx.where((t) => t.currency == currency);
        final credit = own.where((t) => t.direction == AccountDirection.credit).fold(0.0, (s, t) => s + t.amount);
        final debit = own.where((t) => t.direction == AccountDirection.debit).fold(0.0, (s, t) => s + t.amount);
        lines.add(ReportLine(
          ['', l.total, l.currencyName(currency), formatAmount(credit), formatAmount(debit), formatNet(credit - debit, l)],
          style: ReportLineStyle.total,
        ));
      }
      tables.add(ReportTable(
        heading: '${account.name} — ${l.categoryName(account.category.id)}',
        headers: [l.date, l.details, l.currency, l.credit, l.debit, l.balance],
        lines: lines,
      ));
    }
    return TabularReport(title: title, tables: tables);
  }

  // ───────────── 2. إجمالي المبالغ شهرياً ─────────────

  /// One table per currency: a line per calendar month (entries, total له, total عليه, net),
  /// plus the grand total of that currency.
  static TabularReport monthlyTotals({
    required String title,
    required List<Account> accounts,
    required List<Transaction> transactions,
    required ReportLabels labels,
    DateTime? from,
    DateTime? to,
    ReportSortOption? sort,
  }) {
    final l = labels;
    final ids = accounts.map((a) => a.id).toSet();
    final tx = transactions.where((t) => ids.contains(t.accountId) && inRange(t.date, from, to)).toList();
    final tables = <ReportTable>[];
    for (final currency in _currencies(_chrono(tx))) {
      final own = tx.where((t) => t.currency == currency);
      final months = <String, List<Transaction>>{};
      for (final t in _chrono(own)) {
        (months[monthKey(t.date)] ??= []).add(t);
      }
      var keys = months.keys.toList()..sort();
      if (sort == ReportSortOption.dateDesc) keys = keys.reversed.toList();
      if (sort == ReportSortOption.balanceAsc) keys.sort((a, b) => _sum(months[a]!).compareTo(_sum(months[b]!)));
      if (sort == ReportSortOption.balanceDesc) keys.sort((a, b) => _sum(months[b]!).compareTo(_sum(months[a]!)));
      final lines = <ReportLine>[];
      var credit = 0.0, debit = 0.0, count = 0;
      for (final key in keys) {
        final list = months[key]!;
        final c = list.where((t) => t.direction == AccountDirection.credit).fold(0.0, (s, t) => s + t.amount);
        final d = list.where((t) => t.direction == AccountDirection.debit).fold(0.0, (s, t) => s + t.amount);
        credit += c;
        debit += d;
        count += list.length;
        lines.add(ReportLine([key, '${list.length}', formatAmount(c), formatAmount(d), formatNet(c - d, l)]));
      }
      lines.add(ReportLine([l.total, '$count', formatAmount(credit), formatAmount(debit), formatNet(credit - debit, l)], style: ReportLineStyle.total));
      tables.add(ReportTable(
        heading: l.currencyName(currency),
        headers: [l.month, l.entries, l.credit, l.debit, l.net],
        lines: lines,
      ));
    }
    return TabularReport(title: title, tables: tables);
  }

  // ───────────── 3. إجمالي التصنيفات والعملات ─────────────

  /// A line per (category, currency): number of accounts that have entries, entries, له, عليه,
  /// net — then the grand total of each currency across all categories.
  static TabularReport categoryAndCurrencyTotals({
    required String title,
    required List<Account> accounts,
    required List<Transaction> transactions,
    required ReportLabels labels,
    DateTime? from,
    DateTime? to,
    ReportSortOption? sort,
  }) {
    final l = labels;
    final accountById = {for (final a in accounts) a.id: a};
    final tx = transactions.where((t) => accountById.containsKey(t.accountId) && inRange(t.date, from, to)).toList();

    final groups = <(String, String), List<Transaction>>{};
    for (final t in tx) {
      (groups[(accountById[t.accountId]!.category.id, t.currency)] ??= []).add(t);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final byCategory = l.categoryName(a.$1).compareTo(l.categoryName(b.$1));
        return byCategory != 0 ? byCategory : l.currencyName(a.$2).compareTo(l.currencyName(b.$2));
      });
    if (sort == ReportSortOption.nameDesc) {
      keys.sort((a, b) => l.categoryName(b.$1).compareTo(l.categoryName(a.$1)));
    }
    if (sort == ReportSortOption.balanceAsc) keys.sort((a, b) => _sum(groups[a]!).compareTo(_sum(groups[b]!)));
    if (sort == ReportSortOption.balanceDesc) keys.sort((a, b) => _sum(groups[b]!).compareTo(_sum(groups[a]!)));

    final lines = <ReportLine>[];
    for (final key in keys) {
      final list = groups[key]!;
      final c = list.where((t) => t.direction == AccountDirection.credit).fold(0.0, (s, t) => s + t.amount);
      final d = list.where((t) => t.direction == AccountDirection.debit).fold(0.0, (s, t) => s + t.amount);
      lines.add(ReportLine([
        l.categoryName(key.$1),
        l.currencyName(key.$2),
        '${list.map((t) => t.accountId).toSet().length}',
        '${list.length}',
        formatAmount(c),
        formatAmount(d),
        formatNet(c - d, l),
      ]));
    }
    for (final currency in _currencies(tx)) {
      final own = tx.where((t) => t.currency == currency).toList();
      final c = own.where((t) => t.direction == AccountDirection.credit).fold(0.0, (s, t) => s + t.amount);
      final d = own.where((t) => t.direction == AccountDirection.debit).fold(0.0, (s, t) => s + t.amount);
      lines.add(ReportLine([
        l.total,
        l.currencyName(currency),
        '${own.map((t) => t.accountId).toSet().length}',
        '${own.length}',
        formatAmount(c),
        formatAmount(d),
        formatNet(c - d, l),
      ], style: ReportLineStyle.total));
    }
    return TabularReport(
      title: title,
      tables: [
        ReportTable(
          headers: [l.category, l.currency, l.accountsCount, l.entries, l.credit, l.debit, l.net],
          lines: lines,
        ),
      ],
    );
  }

  // ───────────── 4. تفصيلي المبالغ شهرياً للتصنيف الحالي ─────────────

  /// [accounts] is ALREADY the current category's accounts (the caller filters). One table per
  /// month with every entry of those accounts, then that month's total per currency.
  static TabularReport monthlyDetails({
    required String title,
    required List<Account> accounts,
    required List<Transaction> transactions,
    required ReportLabels labels,
    DateTime? from,
    DateTime? to,
    ReportSortOption? sort,
  }) {
    final l = labels;
    final accountById = {for (final a in accounts) a.id: a};
    final tx = _chrono(transactions.where((t) => accountById.containsKey(t.accountId) && inRange(t.date, from, to)));
    final months = <String, List<Transaction>>{};
    for (final t in tx) {
      (months[monthKey(t.date)] ??= []).add(t);
    }
    var keys = months.keys.toList()..sort();
    if (_newestFirst(sort)) keys = keys.reversed.toList();
    final tables = <ReportTable>[];
    for (final key in keys) {
      var list = months[key]!;
      if (sort == ReportSortOption.nameAsc) {
        list = [...list]..sort((a, b) => accountById[a.accountId]!.name.compareTo(accountById[b.accountId]!.name));
      } else if (sort == ReportSortOption.nameDesc) {
        list = [...list]..sort((a, b) => accountById[b.accountId]!.name.compareTo(accountById[a.accountId]!.name));
      } else if (_newestFirst(sort)) {
        list = list.reversed.toList();
      }
      final lines = <ReportLine>[
        for (final t in list)
          ReportLine([
            formatDate(t.date),
            accountById[t.accountId]!.name,
            t.details?.trim().isNotEmpty == true ? t.details!.trim() : '—',
            l.currencyName(t.currency),
            t.direction == AccountDirection.credit ? formatAmount(t.amount) : '0',
            t.direction == AccountDirection.debit ? formatAmount(t.amount) : '0',
          ]),
      ];
      for (final currency in _currencies(list)) {
        final own = list.where((t) => t.currency == currency);
        final c = own.where((t) => t.direction == AccountDirection.credit).fold(0.0, (s, t) => s + t.amount);
        final d = own.where((t) => t.direction == AccountDirection.debit).fold(0.0, (s, t) => s + t.amount);
        lines.add(ReportLine(['', l.monthTotal, formatNet(c - d, l), l.currencyName(currency), formatAmount(c), formatAmount(d)], style: ReportLineStyle.total));
      }
      tables.add(ReportTable(
        heading: key,
        headers: [l.date, l.account, l.details, l.currency, l.credit, l.debit],
        lines: lines,
      ));
    }
    return TabularReport(title: title, tables: tables);
  }

  // ───────────── 5. كشف حساب شهري (حساب واحد) ─────────────

  /// One account, one table per month: opening balance carried from earlier months, the month's
  /// entries with a running balance, then the closing balance. Balances are kept per currency.
  /// [transactions] must be ONLY this account's entries; the date range hides months outside it
  /// but earlier entries still count toward the first opening balance.
  static TabularReport accountMonthlyStatement({
    required String title,
    required List<Transaction> transactions,
    required ReportLabels labels,
    DateTime? from,
    DateTime? to,
    ReportSortOption? sort,
  }) {
    final l = labels;
    final all = _chrono(transactions);
    final shown = all.where((t) => inRange(t.date, from, to)).toList();
    final months = <String, List<Transaction>>{};
    for (final t in shown) {
      (months[monthKey(t.date)] ??= []).add(t);
    }
    final keys = months.keys.toList()..sort();

    // Balance before the first shown entry (entries older than the range still count).
    final running = <String, double>{};
    if (shown.isNotEmpty) {
      final firstShown = shown.first.date;
      for (final t in all.where((t) => t.date.isBefore(firstShown))) {
        running[t.currency] = (running[t.currency] ?? 0) + signed(t);
      }
    }

    final tables = <ReportTable>[];
    for (final key in keys) {
      final list = months[key]!;
      final lines = <ReportLine>[];
      for (final currency in _currencies(list)) {
        lines.add(ReportLine(['', l.openingBalance, l.currencyName(currency), '', '', formatNet(running[currency] ?? 0, l)], style: ReportLineStyle.subtle));
      }
      for (final t in list) {
        final bal = (running[t.currency] ?? 0) + signed(t);
        running[t.currency] = bal;
        lines.add(ReportLine([
          formatDate(t.date),
          t.details?.trim().isNotEmpty == true ? t.details!.trim() : '—',
          l.currencyName(t.currency),
          t.direction == AccountDirection.credit ? formatAmount(t.amount) : '0',
          t.direction == AccountDirection.debit ? formatAmount(t.amount) : '0',
          formatNet(bal, l),
        ]));
      }
      for (final currency in _currencies(list)) {
        lines.add(ReportLine(['', l.closingBalance, l.currencyName(currency), '', '', formatNet(running[currency] ?? 0, l)], style: ReportLineStyle.total));
      }
      tables.add(ReportTable(
        heading: key,
        headers: [l.date, l.details, l.currency, l.credit, l.debit, l.balance],
        lines: lines,
      ));
    }
    if (_newestFirst(sort)) {
      return TabularReport(title: title, tables: tables.reversed.toList());
    }
    return TabularReport(title: title, tables: tables);
  }

  // ───────────── تصدير كل البيانات ─────────────

  /// Two tables for the "export all data" file: every account, then every entry.
  static TabularReport fullExport({
    required String title,
    required String accountsHeading,
    required String entriesHeading,
    required List<Account> accounts,
    required List<Transaction> transactions,
    required ReportLabels labels,
    required String phoneHeader,
    required String createdHeader,
  }) {
    final l = labels;
    final accountById = {for (final a in accounts) a.id: a};
    final byAccount = _byAccount(transactions);
    final accountLines = <ReportLine>[
      for (final a in accounts)
        ReportLine([
          a.name,
          l.categoryName(a.category.id),
          a.phone ?? '',
          formatDate(a.createdDate),
          '${(byAccount[a.id] ?? const []).length}',
          [
            for (final c in _currencies(byAccount[a.id] ?? const []))
              '${l.currencyName(c)}: ${formatNet(_sum((byAccount[a.id] ?? const []).where((t) => t.currency == c)), l)}',
          ].join(' | '),
        ]),
    ];
    final entryLines = <ReportLine>[
      for (final t in _chrono(transactions))
        ReportLine([
          formatDate(t.date),
          accountById[t.accountId]?.name ?? '—',
          t.details?.trim().isNotEmpty == true ? t.details!.trim() : '—',
          l.currencyName(t.currency),
          t.direction == AccountDirection.credit ? formatAmount(t.amount) : '0',
          t.direction == AccountDirection.debit ? formatAmount(t.amount) : '0',
        ]),
    ];
    return TabularReport(title: title, tables: [
      ReportTable(
        heading: accountsHeading,
        headers: [l.account, l.category, phoneHeader, createdHeader, l.entries, l.balance],
        lines: accountLines,
      ),
      ReportTable(
        heading: entriesHeading,
        headers: [l.date, l.account, l.details, l.currency, l.credit, l.debit],
        lines: entryLines,
      ),
    ]);
  }
}
