import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/voice_palette.dart';

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
    this.prominent = true,
    super.key,
  });

  final MainNavTab activeTab;
  final VoidCallback onHome;
  final VoidCallback onVoice;
  final VoidCallback onReports;

  /// A long press on the voice tab enters Bluetooth-headset mode: from Home/Reports it opens the
  /// voice screen in that mode (see HomeScreen._openVoiceScreen); on the voice screen it starts it
  /// directly.
  final VoidCallback? onVoiceLongPress;

  /// The voice screen's bar (bigger icons/labels, navy background) — now the one bar every main
  /// screen shows. `false` keeps the old compact variant.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;

    return Container(
      decoration: BoxDecoration(
        color: prominent ? context.voicePalette.navBackground : shell.headerBottom,
        border: Border(top: BorderSide(color: shell.border)),
      ),
      padding: EdgeInsets.symmetric(vertical: prominent ? 8 : 6),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              prominent: prominent,
              label: l10n.navHome,
              active: activeTab == MainNavTab.home,
              onTap: onHome,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: prominent && activeTab == MainNavTab.voice ? Icons.mic_rounded : Icons.mic_none_rounded,
              assetIcon: 'assets/icons/voice_mic.png',
              prominent: prominent,
              label: l10n.navVoice,
              active: activeTab == MainNavTab.voice,
              onTap: onVoice,
              onLongPress: onVoiceLongPress,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: prominent ? Icons.description_outlined : Icons.picture_as_pdf_outlined,
              prominent: prominent,
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
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onLongPress,
    this.prominent = true,
    this.assetIcon,
  });
  final bool prominent;
  final IconData icon;

  /// When set, this image is drawn instead of [icon] ([icon] stays as the fallback if the file
  /// is missing).
  final String? assetIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellColors;
    final palette = context.voicePalette;
    final color = prominent
        ? (active ? palette.headerGold : Colors.white)
        : (active ? shell.accent : Colors.white70);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: prominent ? 2 : 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetIcon != null)
              Opacity(
                opacity: active ? 1 : 0.75,
                child: Image.asset(
                  assetIcon!,
                  height: prominent ? 30 : 24,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(icon, size: prominent ? 28 : 22, color: color),
                ),
              )
            else
              Icon(icon, size: prominent ? 28 : 22, color: color),
            SizedBox(height: prominent ? 3 : 2),
            Text(
              label,
              style: AppTextStyles.bodySecondary(context).copyWith(
                color: color,
                fontSize: prominent ? 15 : 11,
                fontWeight: prominent ? FontWeight.w700 : FontWeight.w400,
                height: 1.2,
              ),
            ),
            if (prominent) ...[
              const SizedBox(height: 4),
              Container(
                width: 84,
                height: 3,
                decoration: BoxDecoration(
                  color: active ? palette.headerGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
