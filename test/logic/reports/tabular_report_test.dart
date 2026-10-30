import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/report_options.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/logic/reports/tabular_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = ReportLabels(
    date: 'التاريخ',
    details: 'التفاصيل',
    account: 'الحساب',
    category: 'التصنيف',
    currency: 'العملة',
    month: 'الشهر',
    entries: 'العمليات',
    accountsCount: 'الحسابات',
    credit: 'له',
    debit: 'عليه',
    net: 'الصافي',
    balance: 'الرصيد',
    openingBalance: 'رصيد سابق',
    closingBalance: 'رصيد الشهر',
    monthTotal: 'إجمالي الشهر',
    total: 'الإجمالي',
    categoryNames: {'client': 'عملاء', 'supplier': 'موردين'},
    currencyNames: {},
  );

  final a = Account(id: 'a', name: 'أحمد', category: AccountCategory.client, createdDate: DateTime(2026, 1, 1));
  final b = Account(id: 'b', name: 'بكر', category: AccountCategory.supplier, createdDate: DateTime(2026, 1, 1));

  Transaction tx(String id, String account, double amount, String currency, AccountDirection d, DateTime date) =>
      Transaction(id: id, accountId: account, amount: amount, currency: currency, direction: d, date: date);

  final transactions = [
    tx('1', 'a', 1000, 'YER', AccountDirection.credit, DateTime(2026, 1, 10)),
    tx('2', 'a', 300, 'YER', AccountDirection.debit, DateTime(2026, 1, 20)),
    tx('3', 'a', 500, 'YER', AccountDirection.credit, DateTime(2026, 2, 5)),
    tx('4', 'a', 50, 'USD', AccountDirection.credit, DateTime(2026, 1, 15)),
    tx('5', 'b', 200, 'YER', AccountDirection.debit, DateTime(2026, 2, 10)),
  ];

  group('formatting', () {
    test('amounts are grouped and keep decimals only when needed', () {
      expect(ReportBuilders.formatAmount(25000), '25,000');
      expect(ReportBuilders.formatAmount(1234567.5), '1,234,567.50');
      expect(ReportBuilders.formatAmount(0), '0');
    });
    test('net reads له for positive and عليه for negative', () {
      expect(ReportBuilders.formatNet(700, labels), '700 له');
      expect(ReportBuilders.formatNet(-1500, labels), '1,500 عليه');
      expect(ReportBuilders.formatNet(0, labels), '0');
    });
    test('a date range includes the whole last day', () {
      final lateOnLastDay = DateTime(2026, 1, 10, 15, 30);
      expect(ReportBuilders.inRange(lateOnLastDay, DateTime(2026, 1, 1), DateTime(2026, 1, 10)), isTrue);
      expect(ReportBuilders.inRange(DateTime(2026, 1, 11), DateTime(2026, 1, 1), DateTime(2026, 1, 10)), isFalse);
      expect(ReportBuilders.inRange(DateTime(2025, 12, 31, 23), DateTime(2026, 1, 1), null), isFalse);
    });
  });

  group('monthlyTotals', () {
    final report = ReportBuilders.monthlyTotals(title: 't', accounts: [a, b], transactions: transactions, labels: labels);

    test('one table per currency — currencies are never added together', () {
      expect(report.tables.map((t) => t.heading), ['YER', 'USD']);
    });
    test('months and grand total of the first currency', () {
      final yer = report.tables.first.lines;
      expect(yer[0].cells, ['2026-01', '2', '1,000', '300', '700 له']);
      expect(yer[1].cells, ['2026-02', '2', '500', '200', '300 له']);
      expect(yer.last.cells, ['الإجمالي', '4', '1,500', '500', '1,000 له']);
      expect(yer.last.style, ReportLineStyle.total);
    });
  });

  group('allAmountsDetails', () {
    final report = ReportBuilders.allAmountsDetails(title: 't', accounts: [a, b], transactions: transactions, labels: labels);

    test('a table per account with entries, running balance kept per currency', () {
      expect(report.tables.length, 2);
      final lines = report.tables.first.lines;
      expect(lines[0].cells.last, '1,000 له'); // 2026-01-10 YER
      expect(lines[1].cells.last, '50 له'); // USD starts its own balance
      expect(lines[2].cells.last, '700 له'); // YER continues
    });
    test('one total line per currency of the account', () {
      final totals = report.tables.first.lines.where((l) => l.style == ReportLineStyle.total).toList();
      expect(totals.length, 2);
    });
  });

  group('categoryAndCurrencyTotals', () {
    test('groups by category and currency, then totals each currency', () {
      final report = ReportBuilders.categoryAndCurrencyTotals(title: 't', accounts: [a, b], transactions: transactions, labels: labels);
      final lines = report.tables.single.lines;
      // عملاء/YER, عملاء/USD, موردين/YER then YER total and USD total.
      expect(lines.where((l) => l.style == ReportLineStyle.normal).length, 3);
      final yerTotal = lines.firstWhere((l) => l.style == ReportLineStyle.total && l.cells[1] == 'YER');
      expect(yerTotal.cells.last, '1,000 له');
      expect(yerTotal.cells[2], '2'); // two accounts have YER entries
    });
  });

  group('monthlyDetails', () {
    test('only the given accounts, grouped by month', () {
      final report = ReportBuilders.monthlyDetails(title: 't', accounts: [b], transactions: transactions, labels: labels);
      expect(report.tables.length, 1);
      expect(report.tables.single.heading, '2026-02');
    });
  });

  group('accountMonthlyStatement', () {
    final own = transactions.where((t) => t.accountId == 'a').toList();
    final report = ReportBuilders.accountMonthlyStatement(title: 't', transactions: own, labels: labels);

    test('each month opens with the previous closing balance', () {
      expect(report.tables.map((t) => t.heading), ['2026-01', '2026-02']);
      final feb = report.tables[1].lines;
      expect(feb.first.cells[1], 'رصيد سابق');
      expect(feb.first.cells.last, '700 له');
      expect(feb.last.cells.last, '1,200 له');
    });
    test('a date range keeps earlier entries in the opening balance', () {
      final febOnly = ReportBuilders.accountMonthlyStatement(
        title: 't',
        transactions: own,
        labels: labels,
        from: DateTime(2026, 2, 1),
      );
      expect(febOnly.tables.single.lines.first.cells.last, '700 له');
    });
  });

  test('a report with nothing in range is empty', () {
    final report = ReportBuilders.monthlyTotals(
      title: 't',
      accounts: [a],
      transactions: transactions,
      labels: labels,
      from: DateTime(2030, 1, 1),
    );
    expect(report.isEmpty, isTrue);
  });
}
