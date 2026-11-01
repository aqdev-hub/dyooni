import '../../core/l10n/generated/app_localizations.dart';
import '../../data/models/account.dart';
import '../../data/models/auto_message_settings.dart';
import '../../data/models/transaction.dart';
import '../reports/tabular_report.dart' show ReportBuilders;

/// The wording of the automatic message after the person's own edits are applied: each field is
/// the person's text, or — when they left it empty — the built-in text of the current language.
/// Kept as a plain value so [buildAutoMessage] stays pure and testable without localisation.
class AutoMessageTexts {
  const AutoMessageTexts({
    required this.intro,
    required this.businessName,
    required this.holderOwes,
    required this.owedToHolder,
    required this.totalHolderOwes,
    required this.totalOwedToHolder,
    required this.holderOwesNote,
    required this.settledNote,
    required this.detailsPrefix,
    required this.footer,
    required this.dateLabel,
    required this.recentHeader,
    required this.shortHolderOwes,
    required this.shortOwedToHolder,
  });

  final String intro;
  final String businessName;
  final String holderOwes;
  final String owedToHolder;
  final String totalHolderOwes;
  final String totalOwedToHolder;
  final String holderOwesNote;
  final String settledNote;
  final String detailsPrefix;
  final String footer;
  final String dateLabel;
  final String recentHeader;
  final String shortHolderOwes;
  final String shortOwedToHolder;

  factory AutoMessageTexts.resolve(AutoMessageSettings s, AppLocalizations l10n) {
    String pick(String custom, String fallback) => custom.trim().isEmpty ? fallback : custom.trim();
    return AutoMessageTexts(
      intro: pick(s.intro, l10n.autoDefaultIntro),
      businessName: s.businessName.trim(),
      holderOwes: pick(s.holderOwesText, l10n.autoDefaultHolderOwes),
      owedToHolder: pick(s.owedToHolderText, l10n.autoDefaultOwedToHolder),
      totalHolderOwes: pick(s.totalHolderOwesText, l10n.autoDefaultTotalHolderOwes),
      totalOwedToHolder: pick(s.totalOwedToHolderText, l10n.autoDefaultTotalOwedToHolder),
      holderOwesNote: s.holderOwesNote.trim(),
      settledNote: pick(s.settledNote, l10n.autoDefaultSettled),
      detailsPrefix: pick(s.detailsPrefix, l10n.autoDefaultDetailsPrefix),
      footer: s.footer.trim(),
      dateLabel: l10n.autoDateLabel,
      recentHeader: l10n.autoRecentHeader,
      shortHolderOwes: l10n.autoShortHolderOwes,
      shortOwedToHolder: l10n.autoShortOwedToHolder,
    );
  }
}

/// Net per currency id: positive = the holder owes the user (له), negative = the user owes the
/// holder (عليه). Currencies that net to zero are kept (value 0) so "settled" can be reported.
Map<String, double> netByCurrency(List<Transaction> transactions) {
  final out = <String, double>{};
  for (final t in transactions) {
    out[t.currency] = (out[t.currency] ?? 0) + (t.direction == AccountDirection.credit ? t.amount : -t.amount);
  }
  return out;
}

bool _isZero(double v) => v.abs() < 0.005;

/// Whether saving [entry] should offer a message at all (the entry is big enough).
bool passesMinAmount(AutoMessageSettings s, Transaction entry) => entry.amount >= s.minAmount;

/// The message sent to the account holder after [entry] was saved.
///
/// Perspective: the message is written TO the holder. An entry recorded as له (the user is
/// owed) means the holder owes — "عليك مبلغ وقدره"; an entry recorded as عليه means the user owes
/// the holder — "لك مبلغ وقدره". The same logic picks the wording of the totals.
///
/// [accountTransactions] must already include [entry] (the balance is AFTER it).
/// [currencyNames] maps currency id → the name to print.
String buildAutoMessage({
  required AutoMessageSettings settings,
  required AutoMessageTexts texts,
  required AutoMessageContent content,
  required Account account,
  required Transaction entry,
  required List<Transaction> accountTransactions,
  required Map<String, String> currencyNames,
  int recentCount = 5,
}) {
  String nameOf(String id) => currencyNames[id] ?? id;
  final lines = <String>[];

  final header = [texts.intro, texts.businessName].where((e) => e.isNotEmpty).join(' ');
  if (header.isNotEmpty) lines.add(header);
  lines.add(account.name);

  final holderOwesEntry = entry.direction == AccountDirection.credit;
  lines.add('${holderOwesEntry ? texts.holderOwes : texts.owedToHolder} '
      '${ReportBuilders.formatAmount(entry.amount)} ${nameOf(entry.currency)}');

  final details = entry.details?.trim() ?? '';
  if (content == AutoMessageContent.detailed && details.isNotEmpty) {
    lines.add('${texts.detailsPrefix} $details');
  }
  if (settings.showDate) {
    lines.add('${texts.dateLabel}: ${ReportBuilders.formatDate(entry.date)}');
  }

  final nets = netByCurrency(accountTransactions);
  final shown = <String>[
    entry.currency,
    if (settings.showAllCurrencies) ...nets.keys.where((c) => c != entry.currency && !_isZero(nets[c]!)),
  ];
  lines.add('');
  var anyHolderOwes = false;
  for (final c in shown) {
    final net = nets[c] ?? 0;
    if (_isZero(net)) {
      lines.add('${texts.settledNote} (${nameOf(c)})');
    } else {
      if (net > 0) anyHolderOwes = true;
      lines.add('${net > 0 ? texts.totalHolderOwes : texts.totalOwedToHolder} '
          '${ReportBuilders.formatAmount(net)} ${nameOf(c)}');
    }
  }
  if (anyHolderOwes && texts.holderOwesNote.isNotEmpty) lines.add(texts.holderOwesNote);

  if (content == AutoMessageContent.detailed) {
    final sorted = [...accountTransactions]..sort((a, b) => b.date.compareTo(a.date));
    final recent = sorted.where((t) => t.id != entry.id).take(recentCount).toList();
    if (recent.isNotEmpty) {
      lines
        ..add('')
        ..add('${texts.recentHeader}:');
      for (final t in recent) {
        final who = t.direction == AccountDirection.credit ? texts.shortHolderOwes : texts.shortOwedToHolder;
        final d = t.details?.trim() ?? '';
        lines.add('• ${ReportBuilders.formatDate(t.date)}  $who ${ReportBuilders.formatAmount(t.amount)} '
            '${nameOf(t.currency)}${d.isEmpty ? '' : ' — $d'}');
      }
    }
  }

  if (texts.footer.isNotEmpty) {
    lines
      ..add('')
      ..add(texts.footer);
  }
  return lines.join('\n');
}
