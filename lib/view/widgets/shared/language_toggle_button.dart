import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../logic/settings/locale_provider.dart';

/// A single reusable toggle so the login screen and the drawer never drift into two different
/// implementations of "switch language."
class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({this.color = Colors.white70, super.key});
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode == 'ar';

    return TextButton.icon(
      onPressed: () => ref.read(localeProvider.notifier).toggle(),
      icon: Icon(Icons.language, size: 16, color: color),
      label: Text(
        isArabic ? 'English' : 'العربية',
        style: TextStyle(color: color, fontSize: 13),
      ),
    );
  }
}
