import 'package:dyooni/data/models/account.dart';
import 'package:dyooni/data/models/auto_message_settings.dart';
import 'package:dyooni/data/models/transaction.dart';
import 'package:dyooni/logic/messages/auto_message_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const _texts = AutoMessageTexts(
  intro: 'إشعار من',
  businessName: 'متجري',
  holderOwes: 'عليك مبلغ وقدره',
  owedToHolder: 'لك مبلغ وقدره',
  totalHolderOwes: 'الإجمالي عليك',
  totalOwedToHolder: 'الإجمالي لك',
  holderOwesNote: '',
  settledNote: 'مسدّد',
  detailsPrefix: 'مقابل',
  footer: '',
  dateLabel: 'التاريخ',
  recentHeader: 'آخر العمليات',
  shortHolderOwes: 'عليك',
  shortOwedToHolder: 'لك',
);

Transaction _t(String id, double amount, AccountDirection d, {String currency = 'YER', String? details, int day = 1}) =>
    Transaction(id: id, accountId: 'a', amount: amount, currency: currency, direction: d, date: DateTime(2026, 1, day), details: details);

final _account = Account(id: 'a', name: 'علي', category: AccountCategory.client, createdDate: DateTime(2026));

void main() {
  test('credit entry says the holder owes, with total after the entry', () {
    final entry = _t('2', 300, AccountDirection.credit, details: 'بضاعة', day: 2);
    final msg = buildAutoMessage(
      settings: const AutoMessageSettings(),
      texts: _texts,
      content: AutoMessageContent.detailed,
      account: _account,
      entry: entry,
      accountTransactions: [_t('1', 200, AccountDirection.credit), entry],
      currencyNames: const {'YER': 'ريال'},
    );
    expect(msg, contains('إشعار من متجري'));
    expect(msg, contains('عليك مبلغ وقدره 300 ريال'));
    expect(msg, contains('مقابل بضاعة'));
    expect(msg, contains('الإجمالي عليك 500 ريال'));
    expect(msg, contains('آخر العمليات'));
  });

  test('balance-only hides details and recent entries; debit entry says owed to holder', () {
    final entry = _t('2', 100, AccountDirection.debit, details: 'سرّي');
    final msg = buildAutoMessage(
      settings: const AutoMessageSettings(showDate: false),
      texts: _texts,
      content: AutoMessageContent.balanceOnly,
      account: _account,
      entry: entry,
      accountTransactions: [_t('1', 50, AccountDirection.credit), entry],
      currencyNames: const {'YER': 'ريال'},
    );
    expect(msg, contains('لك مبلغ وقدره 100 ريال'));
    expect(msg, contains('الإجمالي لك 50 ريال'));
    expect(msg, isNot(contains('سرّي')));
    expect(msg, isNot(contains('التاريخ')));
    expect(msg, isNot(contains('آخر العمليات')));
  });

  test('settled balance reports settled; other non-zero currencies are appended', () {
    final entry = _t('2', 100, AccountDirection.debit);
    final msg = buildAutoMessage(
      settings: const AutoMessageSettings(showDate: false),
      texts: _texts,
      content: AutoMessageContent.balanceOnly,
      account: _account,
      entry: entry,
      accountTransactions: [_t('1', 100, AccountDirection.credit), entry, _t('3', 20, AccountDirection.credit, currency: 'USD')],
      currencyNames: const {'YER': 'ريال', 'USD': 'دولار'},
    );
    expect(msg, contains('مسدّد (ريال)'));
    expect(msg, contains('الإجمالي عليك 20 دولار'));
  });

  group('resolveAutoMessage', () {
    test('account override beats global; off silences; explicit mode is active even if global off', () {
      const global = AutoMessageSettings(enabled: false, channel: AutoMessageChannel.sms);
      expect(resolveAutoMessage(global, null).active, isFalse);
      expect(resolveAutoMessage(global, const AccountAutoMessage(mode: AccountAutoMode.detailed)).active, isTrue);
      expect(resolveAutoMessage(global.copyWith(enabled: true), const AccountAutoMessage(mode: AccountAutoMode.off)).active, isFalse);
      expect(resolveAutoMessage(global, const AccountAutoMessage(channel: AccountAutoChannel.whatsapp)).channel, AutoMessageChannel.whatsapp);
      expect(resolveAutoMessage(global, null).channel, AutoMessageChannel.sms);
    });
  });

  test('settings JSON round-trips and tolerates garbage', () {
    final s = const AutoMessageSettings(enabled: true, footer: 'شكرا', minAmount: 5).toJson();
    final back = AutoMessageSettings.fromJson(s);
    expect(back.enabled, isTrue);
    expect(back.footer, 'شكرا');
    expect(back.minAmount, 5);
    expect(AutoMessageSettings.fromJson({'channel': 'zzz', 'minAmount': -3}).minAmount, 0);
  });
}
