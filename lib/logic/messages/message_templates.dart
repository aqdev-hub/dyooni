import '../../core/l10n/generated/app_localizations.dart';
import '../../data/models/account.dart';
import '../../data/models/transaction.dart';
import '../reports/tabular_report.dart' show ReportBuilders;

/// The ready-made messages that can be sent to an account holder.
enum MessageTemplate { friendly, demand, thanks, statement, confirm }

/// Net balance in the page's currency: positive = له (the person owes us), negative = عليه.
double netOf(List<Transaction> transactions) {
  var net = 0.0;
  for (final t in transactions) {
    net += t.direction == AccountDirection.credit ? t.amount : -t.amount;
  }
  return net;
}

/// Which templates make sense for [net]:
///  * the holder owes us (له) → a friendly reminder or a firm request;
///  * we owe the holder (عليه) → a balance confirmation, never a payment request;
///  * settled → a thank-you.
/// The statement is always available.
List<MessageTemplate> templatesFor(double net) {
  if (net > 0.005) return [MessageTemplate.friendly, MessageTemplate.demand, MessageTemplate.statement];
  if (net < -0.005) return [MessageTemplate.confirm, MessageTemplate.statement];
  return [MessageTemplate.thanks, MessageTemplate.statement];
}

String templateTitle(AppLocalizations l10n, MessageTemplate t) => switch (t) {
      MessageTemplate.friendly => l10n.messageTemplateFriendly,
      MessageTemplate.demand => l10n.messageTemplateDemand,
      MessageTemplate.thanks => l10n.messageTemplateThanks,
      MessageTemplate.statement => l10n.messageTemplateStatement,
      MessageTemplate.confirm => l10n.messageTemplateConfirm,
    };

/// The text of [template] for [account]. [transactions] are the account's entries in the
/// currency being shown ([currencyName]); the statement lists the latest [statementLines] of
/// them. [creditLabel]/[debitLabel] are the person's own words for له/عليه.
String buildMessage({
  required AppLocalizations l10n,
  required MessageTemplate template,
  required Account account,
  required List<Transaction> transactions,
  required String currencyName,
  required String creditLabel,
  required String debitLabel,
  int statementLines = 8,
}) {
  final net = netOf(transactions);
  final balance = '${ReportBuilders.formatAmount(net)} $currencyName';
  final name = account.name;
  switch (template) {
    case MessageTemplate.friendly:
      return l10n.messageBodyFriendly(name, balance);
    case MessageTemplate.demand:
      return l10n.messageBodyDemand(name, balance);
    case MessageTemplate.thanks:
      return l10n.messageBodyThanks(name, balance);
    case MessageTemplate.confirm:
      return l10n.messageBodyConfirm(name, balance);
    case MessageTemplate.statement:
      final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
      final latest = sorted.length > statementLines ? sorted.sublist(sorted.length - statementLines) : sorted;
      final lines = [
        for (final t in latest)
          l10n.messageStatementLine(
            ReportBuilders.formatDate(t.date),
            '${ReportBuilders.formatAmount(t.amount)} $currencyName',
            t.direction == AccountDirection.credit ? creditLabel : debitLabel,
            t.details?.trim() ?? '',
          ).trimRight(),
      ].join('\n');
      final suffix = net == 0
          ? '0 $currencyName'
          : '$balance ${net > 0 ? creditLabel : debitLabel}';
      return l10n.messageBodyStatement(name, lines, suffix);
  }
}
