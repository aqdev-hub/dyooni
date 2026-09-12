import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// - [goldOutline]: primary action (onboarding "Next", login/signup submit) — dark fill, gold
///   border, gold leading icon, WHITE label text.
/// - [whiteOutline]: secondary action (onboarding "Previous") — dark fill, white/neutral border,
///   white leading icon, WHITE label text. Distinguished from [goldOutline] by border+icon color
///   only, matching the reference exactly (both buttons' text reads white there).
/// - [goldFill]: final CTA (onboarding "ابدأ الآن") — solid gold fill, dark navy text.
enum ButtonVariant { goldOutline, whiteOutline, goldFill }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.goldOutline,
    this.leadingIcon,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? leadingIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color textColor, Color accentColor, Color? borderColor) = switch (variant) {
      ButtonVariant.goldOutline => (AppColors.surface, AppColors.white, AppColors.gold, AppColors.gold),
      ButtonVariant.whiteOutline => (AppColors.surface, AppColors.white, AppColors.white, AppColors.surfaceBorder),
      ButtonVariant.goldFill => (AppColors.gold, AppColors.backgroundTop, AppColors.backgroundTop, null),
    };

    return ElevatedButton(
      onPressed: isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed?.call();
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: textColor,
        disabledBackgroundColor: background.withValues(alpha: 0.6),
        minimumSize: const Size.fromHeight(56),
        animationDuration: const Duration(milliseconds: 150),
        shape: StadiumBorder(
          side: borderColor != null ? BorderSide(color: borderColor, width: 1.4) : BorderSide.none,
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: textColor),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 18, color: accentColor),
                  const SizedBox(width: 8),
                ],
                Text(label, style: AppTextStyles.button(context).copyWith(color: textColor)),
              ],
            ),
    );
  }
}
