import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dyooni/core/l10n/generated/app_localizations.dart';
import 'package:dyooni/data/models/general_settings.dart';
import 'package:dyooni/logic/settings/direction_labels.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  test('resolveCreditLabel falls back to the l10n default when nothing is customized', () {
    expect(resolveCreditLabel(l10n, null), l10n.directionCredit);
    expect(resolveCreditLabel(l10n, const GeneralSettings()), l10n.directionCredit);
  });

  test('resolveDebitLabel falls back to the l10n default when nothing is customized', () {
    expect(resolveDebitLabel(l10n, null), l10n.directionDebit);
    expect(resolveDebitLabel(l10n, const GeneralSettings()), l10n.directionDebit);
  });

  test('resolveCreditLabel/resolveDebitLabel return the customized عبارات when set', () {
    const settings = GeneralSettings(customCreditLabel: 'دائن مخصص', customDebitLabel: 'مدين مخصص');

    expect(resolveCreditLabel(l10n, settings), 'دائن مخصص');
    expect(resolveDebitLabel(l10n, settings), 'مدين مخصص');
  });

  test('a blank/whitespace-only custom label is treated as unset', () {
    const settings = GeneralSettings(customCreditLabel: '   ', customDebitLabel: '');

    expect(resolveCreditLabel(l10n, settings), l10n.directionCredit);
    expect(resolveDebitLabel(l10n, settings), l10n.directionDebit);
  });
}
