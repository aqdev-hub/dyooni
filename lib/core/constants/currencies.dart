import '../l10n/generated/app_localizations.dart';

/// Currency codes shown in every amount-entry form — matches the reference's list plus a
/// "local/unspecified" default option. Centralized here so Add Account and Add Transaction never
/// drift out of sync with each other.
class Currency {
  const Currency(this.code, this.label);
  final String code;
  final String Function(AppLocalizations) label;
}

const currencies = [
  Currency('LOCAL', _localLabel),
  Currency('YER', _yerLabel),
  Currency('USD', _usdLabel),
  Currency('SAR', _sarLabel),
  Currency('AED', _aedLabel),
  Currency('EGP', _egpLabel),
  Currency('KWD', _kwdLabel),
];

String _localLabel(AppLocalizations l10n) => l10n.currencyLocal;
String _yerLabel(AppLocalizations l10n) => l10n.currencyYER;
String _usdLabel(AppLocalizations l10n) => l10n.currencyUSD;
String _sarLabel(AppLocalizations l10n) => l10n.currencySAR;
String _aedLabel(AppLocalizations l10n) => l10n.currencyAED;
String _egpLabel(AppLocalizations l10n) => l10n.currencyEGP;
String _kwdLabel(AppLocalizations l10n) => l10n.currencyKWD;
