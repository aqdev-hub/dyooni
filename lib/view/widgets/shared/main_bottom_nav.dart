import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Which of the three persistent destinations is currently on screen.
enum MainNavTab { home, voice, reports }

/// The app-shell's persistent bottom navigation (الرئيسية / التسجيل الصوتي / التقارير), shown
/// under [BottomSummaryBar] on Home and under the voice recording sheet on the voice screen —
/// same three destinations, same icons/labels, everywhere it appears. Originally private to
/// `home_screen.dart`; pulled out here once the voice screen needed the identical bar (see
/// `widgets/shared/` — the same "actually used by more than one screen" rule that put
/// `direction_choice.dart` and `modal_header_bar.dart` here).
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    required this.activeTab,
    required this.onHome,
    required this.onVoice,
    required this.onReports,
    this.onVoiceLongPress,
    super.key,
  });

  final MainNavTab activeTab;
  final VoidCallback onHome;
  final VoidCallback onVoice;
  final VoidCallback onReports;

  /// Only meaningful from Home, where a long press on the voice tab jumps straight into
  /// Bluetooth mode (see HomeScreen._openVoiceScreen). `null` on the voice screen itself — you
  /// can't long-press your way into Bluetooth mode from a screen you're already on.
  final VoidCallback? onVoiceLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return Container(
      decoration: BoxDecoration(
        color: shell.headerBottom,
        border: Border(top: BorderSide(color: shell.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              label: l10n.navHome,
              active: activeTab == MainNavTab.home,
              onTap: onHome,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.mic_none_rounded,
              label: l10n.navVoice,
              active: activeTab == MainNavTab.voice,
              onTap: onVoice,
              onLongPress: onVoiceLongPress,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.picture_as_pdf_outlined,
              label: l10n.reportsTitle,
              active: activeTab == MainNavTab.reports,
              onTap: onReports,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap, this.onLongPress});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final color = active ? shell.accent : Colors.white70;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.bodySecondary(context).copyWith(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
