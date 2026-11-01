import 'package:share_plus/share_plus.dart';

import '../constants/app_links.dart';
import '../l10n/generated/app_localizations.dart';

/// Opens the system share sheet with the app's invitation text and link. One function so the
/// drawer, the account menu and the rating sheet always share exactly the same thing.
Future<void> shareApp(String languageCode, AppLocalizations l10n) => SharePlus.instance.share(
      ShareParams(text: l10n.shareAppMessage(AppLinks.shareUrl(languageCode)), subject: l10n.shareAppSubject),
    );
