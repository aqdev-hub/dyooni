import 'package:flutter/material.dart';

import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/voice_palette.dart';

/// The app's ONE back arrow (`assets/icons/modal_back_arrow.png`, the gold curved arrow). It is a
/// fixed part of the design: nobody passes it in. The picture points toward the start side of a
/// right-to-left screen, so in a left-to-right language it is mirrored to keep meaning "back".
///
/// [size] is the arrow's height; the width follows the picture's proportions.
class AppBackArrow extends StatelessWidget {
  const AppBackArrow({this.size = 24, super.key});
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/icons/modal_back_arrow.png',
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(Icons.arrow_forward_ios_rounded, size: size, color: context.voicePalette.headerGold),
    );
    return Directionality.of(context) == TextDirection.ltr
        ? Transform.flip(flipX: true, child: image)
        : image;
  }
}

/// A tappable [AppBackArrow] with a comfortable touch target. [onPressed] defaults to closing the
/// current popup / route (`Navigator.maybePop`).
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.onPressed, super.key});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const AppBackArrow(),
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// The single header of every popup (dialog, sheet, "add …" form): a navy rounded bar with
/// the gold back arrow at the start, the centred gold [title], and a gold [icon] at the end.
///
/// Dynamic parts: [title] and [icon] (what this popup is about). Fixed part: the arrow.
/// [onClose] defaults to popping the popup; [onIconTap] makes the icon tappable (e.g. to hide the
/// keyboard). Reused by [AppPopup] and by any popup that lays out its own body.
class ModalHeaderBar extends StatelessWidget {
  const ModalHeaderBar({required this.title, required this.icon, this.onClose, this.onIconTap, super.key});

  final String title;
  final IconData icon;
  final VoidCallback? onClose;
  final VoidCallback? onIconTap;

  @override
  Widget build(BuildContext context) {
    final gold = context.voicePalette.headerGold;
    final iconWidget = Icon(icon, size: 30, color: gold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: context.shellColors.headerBottom,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          AppBackButton(onPressed: onClose),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.button(context).copyWith(color: gold, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: onIconTap == null
                ? Center(child: iconWidget)
                : IconButton(icon: iconWidget, onPressed: onIconTap),
          ),
        ],
      ),
    );
  }
}
